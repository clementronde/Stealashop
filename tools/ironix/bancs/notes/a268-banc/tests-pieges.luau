--!nocheck
-- Banc a268 (vague 81), partie « pièges » (harnais d'a243, Features.Traps = true) : un piège traversé entre deux
-- contrôles (0,1 s) est pris, à 40 et à 80 studs/s, pour les trois genres ; à côté de la zone ou par une
-- téléportation plus longue que Traps.SweepMax : rien.
moduleScript(SERVICES, "TrapService", "server/Services/TrapService.luau")
moduleScript(CONTROLLERS, "TrapController", "client/Controllers/TrapController.luau")

local SLOT_LOCAL = {}
for i = 1, 4 do
	SLOT_LOCAL[i] = Vector3.new(-9 + 6 * (i - 1), 0.3, -20)
end
for _, entry in SHOPS do
	local floor = entry.model:FindFirstChild("PlotFloor")
	for i = 1, 4 do
		local a = newInstance("Attachment")
		a.Name = string.format("TrapSlot_%02d", i)
		a.CFrame = CFrame.new(SLOT_LOCAL[i] - Vector3.new(0, 0.15, 0))
		a.Parent = floor
	end
end

startSkills()
local Traps = sharedModule("Config/Traps")
local TrapService = serverModule("TrapService")

local function cmd(text)
	Workspace:SetAttribute("SkillTest", text)
	Workspace:SetAttribute("SkillTest", nil)
	advance(0.1)
end
local function trapAt(plot, i)
	local folder = plot:FindFirstChild("PlacedTraps")
	return if folder then folder:FindFirstChild(string.format("Trap_%02d", i)) else nil
end

local bob = join("Bob", newProfile())
local eve = join("Eve", newProfile())
local shop = shopOf(bob)
bob:SetAttribute("Rebirths", 4)
cmd("Bob cash 5000000")
cmd("Bob Walls 2")
cmd("Bob Traps 4")
advance(0.1)
local far = refsOfShop(shop).center + Vector3.new(0, 3, 40)
moveTo(bob, far + Vector3.new(10, 0, 0))
moveTo(eve, far)
advance(0.3)

-- Deux contrôles de suite (TrapService.Step), le premier à `from`, le second à `to`, en coordonnées de la zone du
-- piège i (Z = profondeur). Rend le TriggerZone et l'état du piège après.
local function sweep(i, from, to)
	local zone = trapAt(shop, i):FindFirstChild("TriggerZone", true)
	moveTo(eve, (zone.CFrame * CFrame.new(from)).Position)
	TrapService.Step()
	local between = trapAt(shop, i):GetAttribute("TrapState")
	moveTo(eve, (zone.CFrame * CFrame.new(to)).Position)
	TrapService.Step()
	return zone, between, trapAt(shop, i):GetAttribute("TrapState")
end
local function park()
	moveTo(eve, far)
	TrapService.Step()
end

section("à côté, téléportation")
check(Traps.SweepMax ~= nil and Traps.SweepMax >= 8, `Traps.SweepMax ≥ 8 studs, un trajet à 80 studs/s ({Traps.SweepMax})`)
local zone1 = trapAt(shop, 1):FindFirstChild("TriggerZone", true)
local side = zone1.Size.X / 2 + 0.5
local _, _, state = sweep(1, Vector3.new(side, 0, -4), Vector3.new(side, 0, 4))
check(state == "Armed" and eve:GetAttribute("TrapEffect") == nil, "à 80 studs/s, à côté de la zone : rien")
park()
local jump = (Traps.SweepMax or 30) / 2 + 1 -- 30 : arbre sans SweepMax (avant a268)
_, _, state = sweep(1, Vector3.new(0, 0, -jump), Vector3.new(0, 0, jump))
check(state == "Armed", `téléportation de {2 * jump} studs à travers la zone : rien (au-delà de SweepMax)`)
park()

local cases = {
	{ slot = 1, speed = 40, id = "GlueMat" },
	{ slot = 2, speed = 80, id = "NetBox" },
	{ slot = 3, speed = 80, id = "AlarmGate" },
	{ slot = 4, speed = 80, id = "GlueMat" },
}
for _, case in cases do
	section(`traversée à {case.speed} studs/s ({case.id}, Trap_0{case.slot})`)
	check(trapAt(shop, case.slot):GetAttribute("TrapId") == case.id, `Trap_0{case.slot} : {case.id}`)
	local half = case.speed * Traps.CheckInterval / 2 -- trajet d'un contrôle, centré sur la zone
	local zone, between, after = sweep(case.slot, Vector3.new(0, 0, -half), Vector3.new(0, 0, half))
	check(half > zone.Size.Z / 2, `les deux positions sont hors de la zone ({2 * half} studs de trajet, {zone.Size.Z} de profondeur)`)
	check(between == "Armed", "premier contrôle, avant la zone : rien")
	check(after == "Triggered" and eve:GetAttribute("TrapEffect") == case.id, `traversée prise ({after}, {eve:GetAttribute("TrapEffect")})`)
	-- Immunité de la boutique (Traps.Immunity) puis fin de l'effet, loin des pièges.
	park()
	advance(Traps.Immunity + 0.5)
	park()
end

section("sortie")
check(logCount("[TrapService]", "WARN") == 0, "aucun avertissement de TrapService")
summary("scénario a268 pièges")
