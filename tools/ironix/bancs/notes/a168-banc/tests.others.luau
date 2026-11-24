--!nocheck
-- a153 : vigile de nuit et policier (minimum = Speed effective × 2 : r = 0,5, rapprochement 4 studs/s) ;
-- conducteur du camion (marche du voleur × 1 + 2 %/s, au plus × 2).
startBanc()
check(ChaseCfg.Apply.NightGuard and ChaseCfg.Apply.Police and ChaseCfg.Apply.TruckDriver, "A0 règle active pour nuit, police et camion")

-- Le voleur court vers FAR ; relevé jusqu'à la capture.
local function runFrom(player, at)
	place(player, at)
	walk(player, FAR)
end

section("N1 Vigile de nuit : ruée, puis touché en moins de 2 s")
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
check(spotted, "N1a repéré par un vigile de nuit")
walk(N, FAR)
local rn = watch(N, 8)
report("nuit", rn)
local walkN = if rn.samples[1] then rn.samples[1].walk else 0 -- avant la capture (étourdi : 0)
check(rn.maxSpeed >= 60 and near(rn.maxSpeed, math.max(60, 3 * walkN), 0.1), "N1b ruée à max(60, 3 × la marche) (" .. fmt(rn.maxSpeed) .. ")")
check(rn.switchD ~= nil and near(rn.switchD, 10, 0.5), "N1c fin de la ruée vers 10 studs (" .. fmt(rn.switchD) .. ")")
check(rn.caughtT ~= nil and rn.switchT ~= nil and rn.caughtT - rn.switchT < 2, "N1d touché " .. fmt(rn.caughtT and rn.switchT and rn.caughtT - rn.switchT) .. " s après la ruée")
Guard.StopNightPatrol()
advance(4)

local template = make("Model", { Name = "Chaser_Test" }, ReplicatedStorage)
local troot = make("Part", { Name = "HumanoidRootPart", Size = Vector3.new(2, 2, 1), CFrame = CFrame.new(0, 3, 0) }, template)
template.PrimaryPart = troot
local thum = make("Humanoid", { Name = "Humanoid", RootPart = troot, HipHeight = 2 }, template)
make("Animator", { Name = "Animator" }, thum)

section("P1 Policier : ruée, puis touché en moins de 2 s")
local P = thief(100000)
runFrom(P, OUT)
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
check(model ~= nil, "P1a policier lancé")
local rp = watch(P, 8)
report("police", rp)
check(rp.maxSpeed >= 60, "P1b ruée (" .. fmt(rp.maxSpeed) .. ")")
check(rp.switchD ~= nil and near(rp.switchD, 10, 0.5), "P1c fin de la ruée vers 10 studs (" .. fmt(rp.switchD) .. ")")
check(rp.caughtT ~= nil and rp.switchT ~= nil and rp.caughtT - rp.switchT < 2, "P1d touché " .. fmt(rp.caughtT and rp.switchT and rp.caughtT - rp.switchT) .. " s après la ruée")
stop(P)
advance(5)

section("D1 Conducteur du camion : ruée, puis rattrape de plus en plus vite")
local T = thief(100000)
runFrom(T, OUT)
local driver = Guard.StartDriverChase({
	Template = template,
	Name = "Driver_Test",
	Target = T,
	Spawn = CFrame.new(100, 0, 20),
	Zone = 1,
	SpeedMultiplier = 1.1,
	MinSpeed = 20,
	Keeps = function()
		return true
	end,
})
check(driver ~= nil, "D1a conducteur lancé")
local rd = watch(T, 15)
report("conducteur", rd)
check(rd.maxSpeed >= 60, "D1b ruée (" .. fmt(rd.maxSpeed) .. ")")
check(rd.switchD ~= nil and near(rd.switchD, 10, 0.5), "D1c fin de la ruée vers 10 studs (" .. fmt(rd.switchD) .. ")")
if rd.switchT then
	local s1, s3 = sampleAt(rd, rd.switchT + 1), sampleAt(rd, rd.switchT + 3)
	print("  mesure conducteur : à +1 s " .. fmt(s1 and s1.ws / s1.walk) .. " × la marche, à +3 s " .. fmt(s3 and s3.ws / s3.walk))
	check(s1 and near(s1.ws / s1.walk, 1.02, 0.01), "D1d à +1 s : × 1,02 la marche (" .. fmt(s1 and s1.ws / s1.walk) .. ")")
	check(s3 and near(s3.ws / s3.walk, 1.06, 0.01), "D1e à +3 s : × 1,06 la marche (" .. fmt(s3 and s3.ws / s3.walk) .. ")")
	local d1, d2, d3 = distanceAt(rd, rd.switchT + 0.5), distanceAt(rd, rd.switchT + 2), distanceAt(rd, rd.switchT + 3.5)
	check(d1 and d2 and d3 and (d1 - d2) < (d2 - d3), "D1f il rattrape de plus en plus vite (" .. fmt(d1 and d2 and d1 - d2) .. " puis " .. fmt(d2 and d3 and d2 - d3) .. " studs par 1,5 s)")
end
check(rd.caughtT ~= nil and rd.switchT ~= nil and rd.caughtT - rd.switchT > 3 and rd.caughtT - rd.switchT < 8, "D1g touché entre 3 et 8 s après la ruée (" .. fmt(rd.caughtT and rd.switchT and rd.caughtT - rd.switchT) .. ")")
summary("scénario others")
