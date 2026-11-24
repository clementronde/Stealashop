--!nocheck
-- a174 (2026-11-15, vague 54) : distance gardée Chase.HoldDistance (14) ± 0,5 ; nuit et police touchés (HoldDistance − 4) / 4 = 2,5 s ± 0,2.
-- a173 (2026-11-15) : rappel vers la distance prévue en poursuite à distance (Chase.HoldRecallGain, HoldRecallMax).
-- À 14, 25 et 60 images/s (scénario jitter : images de durée variable et élan du Humanoid, comme en Play) :
--   vigile de magasin (zone 1, minimum 100K, pre.*.luau), r = 1 et 2 : distance gardée 14 ± 0,5 de +2 s à +4 s après la fin de ruée (le rappel, k = 2 /s,
--   rattrape en environ 1,5 s l élan de fin de ruée, jusqu à 4 studs avec l élan simulé) ;
--   r = 0,5 et 0,1 : touché à (HoldDistance − CatchDistance) / rapprochement ± 0,25 s (1,5 s et 0,83 s) ;
--   vigile de nuit et policier : touchés 1,5 s ± 0,2 après la fin de la ruée.
startBanc()
local tag = if A173_JITTER then "J" else "F"
if A173_JITTER then
	JITTER = { 0.5, 1.5, 0.7, 1.3, 1.8, 0.6, 0.9, 0.7 }
	DECEL = 300
end
check(ChaseCfg.HoldRecallGain == 2 and ChaseCfg.HoldRecallMax == 4, tag .. "0 Config/Chase : HoldRecallGain 2, HoldRecallMax 4")
local stores = { STORE_A, STORE_B }
local turn = 0
local function nextStore()
	turn += 1
	if turn > 2 then
		advance(25)
	end
	return stores[(turn - 1) % 2 + 1]
end

local template = make("Model", { Name = "Chaser_Test" }, ReplicatedStorage)
local troot = make("Part", { Name = "HumanoidRootPart", Size = Vector3.new(2, 2, 1), CFrame = CFrame.new(0, 3, 0) }, template)
template.PrimaryPart = troot
local thum = make("Humanoid", { Name = "Humanoid", RootPart = troot, HipHeight = 2 }, template)
make("Animator", { Name = "Animator" }, thum)

local function after(rec)
	return if rec.caughtT and rec.switchT then rec.caughtT - rec.switchT else nil
end

local function nightRun(label)
	local N = thief(100000)
	Guard.StartNightPatrol({
		InCorridor = function(position)
			return position.X > 25
		end,
		Ignores = function()
			return false
		end,
		SendHome = function()
			return true
		end,
	})
	advance(1)
	local spotted = false
	for _ = 1, 20 do
		local folder = Workspace:FindFirstChild("ActiveGuards")
		local night
		for _, model in (if folder then folder:GetChildren() else {}) do
			if string.find(model.Name, "NightGuard", 1, true) and model:FindFirstChild("HumanoidRootPart") then
				night = model
				break
			end
		end
		if night then
			local root = night.HumanoidRootPart
			local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
			local at = Vector3.new(root.Position.X, 3, root.Position.Z) + (if look.Magnitude > 0.1 then look.Unit else Vector3.new(1, 0, 0)) * 20
			place(N, at)
			advance(0.2)
			if Guard.IsNightChased(N) then
				spotted = true
				break
			end
		end
		advance(0.3)
	end
	check(spotted, label .. "n repéré par un vigile de nuit")
	walk(N, FAR)
	local rn = watch(N, 8)
	report(label .. " nuit", rn)
	check(after(rn) ~= nil and near(after(rn), (ChaseCfg.HoldDistance - 4) / 4, 0.2) and rn.lastD ~= nil and rn.lastD < 5,
		label .. "n nuit : touché 2,5 s ± 0,2 après la ruée, par lui (" .. fmt(after(rn)) .. " s, dernière distance " .. fmt(rn.lastD) .. ")")
	Guard.StopNightPatrol()
	advance(4)
end

local function policeRun(label)
	local P = thief(100000)
	place(P, OUT)
	walk(P, FAR)
	local model = Guard.StartDriverChase({
		Template = template,
		Name = "Police_Test",
		Target = P,
		Spawn = CFrame.new(100, 0, 20),
		Zone = 1,
		SpeedMultiplier = 0,
		MinSpeed = 20,
		Keeps = function()
			return true
		end,
		Label = "policier",
		Tired = true,
		GiveUpReason = "test",
	})
	check(model ~= nil, label .. "p policier lancé")
	local rp = watch(P, 8)
	report(label .. " police", rp)
	check(after(rp) ~= nil and near(after(rp), (ChaseCfg.HoldDistance - 4) / 4, 0.2), label .. "p police : touché 2,5 s ± 0,2 après la ruée (" .. fmt(after(rp)) .. ")")
	stop(P)
	advance(5)
end

for _, fps in A173_FPS do
	FRAME = 1 / fps
	local label = tag .. fps
	section(label .. " " .. fps .. " images/s" .. (if A173_JITTER then ", images variables et élan" else ""))
	for _, r in { 0.1, 0.5, 1, 2 } do
		local P = thief(r * 100000)
		check(heistAndRun(P, nextStore()), label .. " r = " .. r .. " : le vigile poursuit")
		local rec = watch(P, if r >= 1 then 7 else 5)
		report(label .. ", r = " .. r, rec)
		if r >= 1 then
			local lo, hi, count = math.huge, -math.huge, 0
			if rec.switchT then
				lo, hi, count = rangeIn(rec, rec.switchT + 2, rec.switchT + 4)
			end
			check(count > 0 and lo >= ChaseCfg.HoldDistance - 0.5 and hi <= ChaseCfg.HoldDistance + 0.5,
				label .. " r = " .. r .. " : distance gardée 14 ± 0,5 de +2 à +4 s (" .. fmt(lo) .. " à " .. fmt(hi) .. ")")
		else
			local expected = (ChaseCfg.HoldDistance - 4) / (ChaseCfg.ClosingSpeedMax * (1 - r))
			check(after(rec) ~= nil and near(after(rec), expected, 0.25),
				label .. " r = " .. r .. " : touché vers " .. fmt(expected) .. " s ± 0,25 (" .. fmt(after(rec)) .. ")")
		end
		if rec.caughtT then
			stop(P)
			advance(4)
		else
			endChase(P)
		end
	end
	nightRun(label)
	policeRun(label)
end
FRAME = 1 / 30
JITTER = nil
DECEL = nil
summary("scénario " .. (if A173_JITTER then "jitter" else "frames"))
