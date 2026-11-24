--!nocheck
-- Banc a286, partie « pièges » (harnais d'a243/a268, Features.Traps = true) : NEW_TRAPS = true donne la disposition
-- Traps.SlotLayoutNew (banane, filet, portique, trappe) ; la banane arrête 1,5 s ; la trappe sort le voleur de
-- Bounds devant la porte et rend l'objet volé à son présentoir. NEW_TRAPS = false : l'ancienne disposition.
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

local bobData = newProfile()
addItem(bobData, "bob-soda", "Z1_CanetteDeSoda", 1)
local bob = join("Bob", bobData)
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

local function sweep(i)
	local zone = trapAt(shop, i):FindFirstChild("TriggerZone", true)
	moveTo(eve, (zone.CFrame * CFrame.new(0, 0, -zone.Size.Z)).Position)
	TrapService.Step()
	moveTo(eve, zone.Position)
	TrapService.Step()
	return trapAt(shop, i):GetAttribute("TrapState")
end
local function park()
	moveTo(eve, far)
	TrapService.Step()
end

local expected = if NEW_TRAPS then Traps.SlotLayoutNew else Traps.SlotLayout
section(`disposition ({if NEW_TRAPS then "NewTraps" else "ancienne"})`)
for i = 1, 4 do
	local trap = trapAt(shop, i)
	check(trap ~= nil and trap:GetAttribute("TrapId") == expected[i], `Trap_0{i} : {expected[i]} ({trap and trap:GetAttribute("TrapId")})`)
	check(trap ~= nil and trap:FindFirstChild("TriggerZone", true) ~= nil, `Trap_0{i} : modèle de repli avec TriggerZone`)
end

if NEW_TRAPS then
	check(Traps.ById.BananaPeel.Animation == "TrapSlip" and Traps.ById.BananaPeel.StopTime == 1.5, "banane : TrapSlip, arrêt 1,5 s")
	check(Traps.ById.TrapDoor.Eject == true and Traps.ById.GlueMat.Eject == false, "Eject : trappe seulement")

	section("banane : arrêt 1,5 s")
	local state = sweep(1)
	check(state == "Triggered" and eve:GetAttribute("TrapEffect") == "BananaPeel", `banane prise ({state}, {eve:GetAttribute("TrapEffect")})`)
	check(insideBox(boundsOf(shop), rootOf(eve).Position), "banane : le voleur reste dans la boutique")
	advance(1.2)
	check(eve:GetAttribute("TrapEffect") == "BananaPeel", "encore arrêté à 1,2 s")
	advance(0.5)
	check(eve:GetAttribute("TrapEffect") == nil, "libre à 1,7 s")
	park()
	advance(Traps.Immunity + 0.5)
	park()

	section("trappe sans objet : sortie devant la porte")
	check(insideBox(boundsOf(shop), trapAt(shop, 4):FindFirstChild("TriggerZone", true).Position), "la trappe est dans Bounds")
	state = sweep(4)
	check(state == "Triggered" and eve:GetAttribute("TrapEffect") == "TrapDoor", `trappe prise ({state}, {eve:GetAttribute("TrapEffect")})`)
	check(not insideBox(boundsOf(shop), rootOf(eve).Position), "sortie de Bounds (PlotService.PutOutside)")
	park()
	advance(Traps.Immunity + Traps.Recharge + 0.5)
	park()

	section("trappe avec l'objet volé : rendu à son présentoir")
	local broken = breakDoor(eve, shop)
	check(broken, "porte de Bob cassée")
	-- Prise en deux appels avec l'étape de maintien (a265 : « Begin » puis « End »).
	standBy(eve, shop, 1)
	local index = shop:GetAttribute("PlotIndex")
	fireAs(eve, "StealItem", index, 1, "Begin")
	flush()
	advance(sharedModule("Config/PvP").StealGrabTime + 0.05)
	fireAs(eve, "StealItem", index, 1, "End")
	flush()
	local carrying = CarryService.IsCarrying(eve)
	check(carrying, "Eve porte l'objet de Bob")
	check(displayModel(shop, 1) == nil, "présentoir 1 vide pendant la fuite")
	check(trapAt(shop, 4):GetAttribute("TrapState") == "Armed", "trappe réarmée")
	state = sweep(4)
	check(state == "Triggered", `trappe prise en portant ({state})`)
	advance(0.2)
	check(not CarryService.IsCarrying(eve), "Eve ne porte plus rien")
	check(DataService.Get(bob).Display["1"] == "bob-soda" and DataService.Get(bob).Items["bob-soda"] ~= nil, "l'objet est de nouveau exposé chez Bob")
	check(DataService.Get(eve).Items["bob-soda"] == nil, "rien chez Eve")
	check(displayModel(shop, 1) ~= nil, "modèle de nouveau sur le présentoir 1")
	check(trapAt(shop, 4):GetAttribute("TrapState") == "Triggered" and eve:GetAttribute("TrapEffect") == "TrapDoor", "Eve sonnée devant la porte (TrapDoor)")
	check(not insideBox(boundsOf(shop), rootOf(eve).Position), "Eve sortie de Bounds")
end

section("sortie")
check(logCount("[TrapService]", "WARN") == 0, "aucun avertissement de TrapService")
summary(`scénario a286 pièges {if NEW_TRAPS then "NewTraps" else "ancienne disposition"}`)
