--!nocheck
-- a174 (2026-11-15, vague 54) : distance gardée Chase.HoldDistance (14) ± 0,5, ruée max(RushMinSpeed, RushWalkFactor × la marche), touché vers 2,5 s.
-- a168 (2026-11-15) : fin de ruée anticipée. À 15, 30 et 60 images/s, la distance gardée vaut 10 studs ± 0,5 :
-- vigile de magasin (zone 1, minimum 100K, pre.frames.luau) pour r = 0,1 ; 0,5 ; 1 ; 2, vigile de nuit, policier.
startBanc()
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

local function nightRun(fps)
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
	check(spotted, "F" .. fps .. "n repéré par un vigile de nuit")
	walk(N, FAR)
	local rn = watch(N, 8)
	report("nuit " .. fps .. " images/s", rn)
	check(rn.switchD ~= nil and near(rn.switchD, ChaseCfg.HoldDistance, 0.5), "F" .. fps .. "n nuit : distance gardée 14 ± 0,5 (" .. fmt(rn.switchD) .. ")")
	-- capture : affichée seulement (ici souvent vers 0,6 s, un autre vigile de nuit peut être plus près)
	check(rn.caughtT ~= nil, "F" .. fps .. "n nuit : touché (" .. fmt(rn.caughtT and rn.switchT and rn.caughtT - rn.switchT) .. " s après la ruée)")
	Guard.StopNightPatrol()
	advance(4)
end

local function policeRun(fps)
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
	check(model ~= nil, "F" .. fps .. "p policier lancé")
	local rp = watch(P, 8)
	report("police " .. fps .. " images/s", rp)
	check(rp.switchD ~= nil and near(rp.switchD, ChaseCfg.HoldDistance, 0.5), "F" .. fps .. "p police : distance gardée 14 ± 0,5 (" .. fmt(rp.switchD) .. ")")
	check(rp.caughtT ~= nil and rp.switchT ~= nil and rp.caughtT - rp.switchT > 2.2 and rp.caughtT - rp.switchT < 2.9,
		"F" .. fps .. "p police : touché vers 2,5 s après la ruée (" .. fmt(rp.caughtT and rp.switchT and rp.caughtT - rp.switchT) .. ")")
	stop(P)
	advance(5)
end

for _, fps in { 15, 30, 60 } do
	FRAME = 1 / fps
	section("F" .. fps .. " " .. fps .. " images/s")
	for _, r in { 0.1, 0.5, 1, 2 } do
		local P = thief(r * 100000)
		check(heistAndRun(P, nextStore()), "F" .. fps .. " r = " .. r .. " : le vigile poursuit")
		local rec = watch(P, 3)
		report(fps .. " images/s, r = " .. r, rec)
		check(rec.switchD ~= nil and near(rec.switchD, ChaseCfg.HoldDistance, 0.5),
			"F" .. fps .. " r = " .. r .. " : distance gardée 14 ± 0,5 (" .. fmt(rec.switchD) .. ")")
		if rec.caughtT then
			stop(P)
			advance(4)
		else
			endChase(P)
		end
	end
	nightRun(fps)
	policeRun(fps)
end
FRAME = 1 / 30
summary("scénario frames")
