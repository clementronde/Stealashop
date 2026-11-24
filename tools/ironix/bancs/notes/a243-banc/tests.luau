--!nocheck
-- Banc a243 (vague 72) : pièges de boutique. Voir run.sh.
moduleScript(SERVICES, "TrapService", "server/Services/TrapService.luau")
moduleScript(CONTROLLERS, "TrapController", "client/Controllers/TrapController.luau")

-- Emplacements TrapSlot_01 à _04 (Attachments de PlotFloor, comme L-218) dans chaque boutique, 6 studs l'un de l'autre.
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
local SkillTree = sharedModule("Config/SkillTree")
local TrapService = serverModule("TrapService")

local function cmd(text)
	Workspace:SetAttribute("SkillTest", text)
	Workspace:SetAttribute("SkillTest", nil)
	advance(0.1)
end
local function placedOf(plot)
	local folder = plot:FindFirstChild("PlacedTraps")
	return if folder then folder:GetChildren() else {}
end
local function trapAt(plot, i)
	local folder = plot:FindFirstChild("PlacedTraps")
	return if folder then folder:FindFirstChild(string.format("Trap_%02d", i)) else nil
end
local function slotWorld(plot, i)
	local S = refsOfShop(plot)
	return S.origin * SLOT_LOCAL[i]
end
local function speedOf(player)
	return (SPEED_MODIFIERS[player] or {}).Trap
end

local bob = join("Bob", newProfile())
local eve = join("Eve", newProfile())
local shop = shopOf(bob)
check(shop ~= nil, "Bob a une boutique")
bob:SetAttribute("Rebirths", 4)

if SCENARIO == "off" then
	section("Features.Traps = false")
	local traps = SkillTree.ById.Traps
	check(traps.Coded == 0 and traps.MaxLevel == 4, `tuile Traps : Coded 0 (« Soon »), MaxLevel 4 (Coded {traps.Coded})`)
	check(TrapService.IsEnabled() == false, "TrapService coupé")
	cmd("Bob cash 5000000")
	cmd("Bob Walls 2")
	buy(bob, "Traps")
	check(bob:GetAttribute("Skill_Traps") == 0, "achat refusé")
	check(#notifies(bob, "coming soon") >= 1, "Notify « coming soon »")
	cmd("Bob Traps 4")
	advance(2.5)
	check(#placedOf(shop) == 0 and shop:FindFirstChild("PlacedTraps") == nil, "niveau 4 par SkillTest : aucun piège posé")
	moveTo(eve, slotWorld(shop, 1) + Vector3.new(0, 2.7, 0))
	advance(0.5)
	check(eve:GetAttribute("TrapEffect") == nil and speedOf(eve) == nil, "Eve sur l'emplacement : rien")
	summary("scénario off")
	return
end

section("achat")
check(SkillTree.ById.Traps.Coded == 4, "Features.Traps = true : tuile Traps achetable (Coded 4)")
check(TrapService.IsEnabled(), "TrapService allumé")
cmd("Bob cash 5000000")
cmd("Bob Walls 2")
buy(bob, "Traps")
check(bob:GetAttribute("Skill_Traps") == 1, "Bob achète Traps 1")
advance(0.1)
local t1 = trapAt(shop, 1)
check(#placedOf(shop) == 1 and t1 ~= nil, `un piège posé (Trap_01) : {#placedOf(shop)}`)
check(t1 and t1:GetAttribute("TrapId") == "GlueMat" and t1:GetAttribute("TrapState") == "Armed", "Trap_01 : GlueMat, Armed")
check(t1 and hasTag(t1, Traps.Tag), "tag PlotTrap")
check(t1 and (t1:GetPivot().Position - slotWorld(shop, 1)).Magnitude < 0.01, "pivot sur TrapSlot_01")
check(t1 and t1:FindFirstChild("Armed") and t1:FindFirstChild("Triggered") and t1:FindFirstChild("TriggerZone"), "repli : Armed, Triggered, TriggerZone")

section("client")
startClient(eve)
local burst = t1:FindFirstChild("Burst", true)
local plate = t1:FindFirstChild("Plate", true)
check(burst.Transparency == 1 and plate.LocalTransparencyModifier == 0, "armé : Triggered caché, Armed visible")

section("propriétaire épargné")
moveTo(bob, slotWorld(shop, 1) + Vector3.new(0, 2.7, 0))
advance(0.5)
check(t1:GetAttribute("TrapState") == "Armed" and bob:GetAttribute("TrapEffect") == nil, "Bob sur son piège : rien")
moveTo(bob, refsOfShop(shop).center + Vector3.new(0, 0, 25))

section("colle")
breakDoor(eve, shop)
advance(0.2)
moveTo(eve, slotWorld(shop, 1) + Vector3.new(0.5, 2.7, 0.5))
advance(0.25)
check(t1:GetAttribute("TrapState") == "Triggered", "Eve déclenche Trap_01")
check(eve:GetAttribute("TrapEffect") == "GlueMat", "Eve : TrapEffect = GlueMat")
check(speedOf(eve) == 0, "Eve immobile")
check(#notifies(eve, "Glue Trap") == 1, "Notify au voleur")
check(#notifies(bob, "Eve walked into your Glue Trap") == 1, "Notify au propriétaire")
check(burst.Transparency == 0.4 and plate.LocalTransparencyModifier == 1, "client : Triggered montré (ShownTransparency), Armed caché")
local played = ClientAnimation.played
check(played[#played] == "Stunned", `client : Stunned à la place de TrapStuck absente ({played[#played]})`)
advance(1)
check(speedOf(eve) == 0.5, `après StopTime : ralenti × 0,5 ({speedOf(eve)})`)
advance(4.1)
check(speedOf(eve) == nil and eve:GetAttribute("TrapEffect") == nil, "après SlowTime : effet retiré")
check(t1:GetAttribute("TrapState") == "Triggered", "toujours en recharge")
moveTo(eve, slotWorld(shop, 1) + Vector3.new(0, 2.7, 8)) -- hors de la zone : sinon repris dès le réarmement
advance(10)
check(t1:GetAttribute("TrapState") == "Armed", "réarmé après Recharge")
check(burst.Transparency == 1 and plate.LocalTransparencyModifier == 0, "client : réarmé")

section("immunité et filet")
cmd("Bob Traps 4")
advance(0.1)
check(#placedOf(shop) == 4, `niveau 4 : 4 pièges ({#placedOf(shop)})`)
check(trapAt(shop, 2):GetAttribute("TrapId") == "NetBox" and trapAt(shop, 3):GetAttribute("TrapId") == "AlarmGate", "genres de SlotLayout")
check(trapAt(shop, 1) == t1, "Trap_01 gardé")
moveTo(eve, slotWorld(shop, 1) + Vector3.new(0, 2.7, 0))
advance(0.25)
check(eve:GetAttribute("TrapEffect") == "GlueMat", "colle de nouveau")
moveTo(eve, slotWorld(shop, 2) + Vector3.new(0, 2.7, 0))
advance(3)
check(trapAt(shop, 2):GetAttribute("TrapState") == "Armed", "immunité : le filet ne prend pas Eve tout de suite")
advance(5.5)
check(trapAt(shop, 2):GetAttribute("TrapState") == "Triggered" and eve:GetAttribute("TrapEffect") == "NetBox", "après Immunity : filet")
check(speedOf(eve) == 0, "filet : immobile")
advance(3.1)
check(speedOf(eve) == nil, "filet : libre après StopTime")

section("portique")
advance(8.1)
moveTo(eve, slotWorld(shop, 3) + Vector3.new(0, 2.7, 0))
advance(0.25)
check(trapAt(shop, 3):GetAttribute("TrapState") == "Triggered", "portique déclenché")
local spots = remotes("CameraSpotted", function(e) return e.to == bob and e.args[1] == eve end)
check(#spots == 1, "CameraSpotted au propriétaire")
advance(2)
check(speedOf(eve) == nil, "portique : libre")

section("réapparition")
advance(8.1)
moveTo(eve, slotWorld(shop, 4) + Vector3.new(0, 2.7, 0))
advance(0.25)
check(eve:GetAttribute("TrapEffect") == "GlueMat", "Trap_04 : colle")
spawnCharacter(eve, Vector3.new(0, 3, 0))
advance(0.1)
check(eve:GetAttribute("TrapEffect") == nil and speedOf(eve) == nil, "réapparition : effet retiré")

section("modèle de Clément")
local assets = ReplicatedStorage:FindFirstChild("Assets")
if assets == nil then
	assets = newInstance("Folder")
	assets.Name = "Assets"
	assets.Parent = ReplicatedStorage
end
local trapsFolder = newInstance("Folder")
trapsFolder.Name = "Traps"
trapsFolder.Parent = assets
local tpl = newInstance("Model")
tpl.Name = "TRAP_NetBox"
local base = newInstance("Part")
base.Name = "Base"
base.Size = Vector3.new(3, 0.2, 3)
base.CFrame = CFrame.new(0, 0.1, 0)
base.Parent = tpl
tpl.PrimaryPart = base
local zone = newInstance("Part")
zone.Name = "TriggerZone"
zone.Size = Vector3.new(3.4, 5, 3.4)
zone.CFrame = CFrame.new(0, 2.5, 0)
zone.CanCollide = true
zone.CanQuery = true
zone.Parent = tpl
local armed = newInstance("Model")
armed.Name = "Armed"
armed.Parent = tpl
local trig = newInstance("Model")
trig.Name = "Triggered"
trig.Parent = tpl
local sneaky = newInstance("Script")
sneaky.Name = "Sneaky"
sneaky.Parent = armed
tpl:SetAttribute("TrapId", "NetBox")
tpl.Parent = trapsFolder
cmd("Bob Traps 1")
advance(0.1)
check(#placedOf(shop) == 1, "niveau 1 : 3 pièges retirés")
cmd("Bob Traps 2")
advance(0.1)
local t2 = trapAt(shop, 2)
check(t2 ~= nil and t2:FindFirstChild("Sneaky", true) == nil, "copie de TRAP_NetBox sans script")
local z2 = if t2 then t2:FindFirstChild("TriggerZone") else nil
check(z2 ~= nil and z2.CanCollide == false and z2.CanQuery == false and z2.Anchored == true, "TriggerZone sans collision ni requête, ancrée")
check(tpl:FindFirstChild("Sneaky", true) ~= nil, "le gabarit n'est pas modifié")

section("emplacement manquant, retrait")
local slot2 = shop:FindFirstChild("TrapSlot_02", true)
local floor = slot2.Parent
slot2.Parent = nil
advance(2.1)
check(trapAt(shop, 2) == nil, "TrapSlot_02 retiré : piège retiré à la remise à jour")
slot2.Parent = floor
advance(2.1)
check(trapAt(shop, 2) ~= nil, "remis : piège reposé")
cmd("Bob reset")
advance(2.1)
check(shop:FindFirstChild("PlacedTraps") == nil, "arbre remis à 0 : tout retiré")
cmd("Bob Traps 4")
advance(0.1)
check(#placedOf(shop) == 4, "4 pièges")
leave(bob)
advance(0.5)
check(shop:FindFirstChild("PlacedTraps") == nil, "Bob part : pièges retirés")

section("sortie")
check(logCount("[TrapService]", "WARN") == 0, "aucun avertissement de TrapService")
check(logCount("TrapController", "WARN") == 0, "aucun avertissement de TrapController")
summary("scénario on")
