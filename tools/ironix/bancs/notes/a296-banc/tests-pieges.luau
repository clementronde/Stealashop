--!nocheck
-- Banc a296, partie « pièges » (copie de a293-banc/tests-pieges.luau ; harnais d'a243/a268, Features.Traps = true).
-- Config telle quelle : Features.NewTraps = false (PROD), NewTrapsDev = true (jeu DEV seulement). MODE (pre-a296.luau) :
--   dev     ProductIds Environment = "Dev" (IsDev vrai)       -> Traps.SlotLayoutNew (colle, banane, portique, trappe) ;
--   prod    ProductIds Environment = "Prod" (IsDev faux)      -> Traps.SlotLayout (colle, filet, portique, colle) ;
--   absent  pas de module Config/ProductIds                   -> Traps.SlotLayout ;
--   studio  IsDev faux, attribut NewTrapsTest = true (Studio) -> Traps.SlotLayoutNew.
-- NEW_TRAPS = disposition nouvelle attendue (dev, studio) : effets des quatre pièges vérifiés comme dans a293.
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

if MODE == "studio" then
	Workspace:SetAttribute("NewTrapsTest", true) -- a296 : avant la pose des pièges
end
startSkills()
local Traps = sharedModule("Config/Traps")
local Features = sharedModule("Config/Features")
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
local function rest()
	park()
	advance(Traps.Immunity + 0.5)
	park()
end

section(`Config (a296, {MODE})`)
check(Features.NewTraps == false, "Features.NewTraps = false : coupé en PROD (validé par Cantin, 21/11)")
check(Features.NewTrapsDev == true, "Features.NewTrapsDev = true : allumé dans le jeu DEV (validé par Cantin, 21/11)")
local productIds = SHARED:FindFirstChild("Config"):FindFirstChild("ProductIds")
if MODE == "absent" then
	check(productIds == nil, "(banc) pas de module Config/ProductIds")
else
	check(productIds ~= nil, "(banc) module Config/ProductIds présent")
	local ids = sharedModule("Config/ProductIds")
	check(ids.IsDev == (MODE == "dev"), `ProductIds.IsDev = {tostring(MODE == "dev")} ({tostring(ids.IsDev)})`)
end
check(TrapService.IsEnabled(), "pièges allumés (Traps = true)")
if NEW_TRAPS then
	local layout = Traps.SlotLayoutNew
	check(#layout == 4 and #layout == #Traps.SlotLayout, `4 emplacements, comme SlotLayout ({#layout})`)
	check(layout[1] == "GlueMat" and layout[2] == "BananaPeel" and layout[3] == "AlarmGate" and layout[4] == "TrapDoor",
		`colle, banane, portique, trappe ({table.concat(layout, ", ")})`)
	check(table.find(layout, "GlueMat") ~= nil, "la colle est gardée")
	check(layout[1] == Traps.SlotLayout[1] and layout[3] == Traps.SlotLayout[3], "1er et 3e emplacements inchangés (colle, portique)")
	for _, id in layout do
		check(Traps.ById[id] ~= nil, `{id} connu de Config/Traps`)
	end
end

local expected = if NEW_TRAPS then Traps.SlotLayoutNew else Traps.SlotLayout
section(`disposition ({MODE} : {if NEW_TRAPS then "nouvelle" else "ancienne"})`)
for i = 1, 4 do
	local trap = trapAt(shop, i)
	check(trap ~= nil and trap:GetAttribute("TrapId") == expected[i], `Trap_0{i} : {expected[i]} ({trap and trap:GetAttribute("TrapId")})`)
	check(trap ~= nil and trap:FindFirstChild("TriggerZone", true) ~= nil, `Trap_0{i} : modèle de repli avec TriggerZone`)
end

if NEW_TRAPS then
	section("colle (1er) : arrêt 1 s puis ralenti 4 s")
	local glue = Traps.ById.GlueMat
	local state = sweep(1)
	check(state == "Triggered" and eve:GetAttribute("TrapEffect") == "GlueMat", `colle prise ({state}, {eve:GetAttribute("TrapEffect")})`)
	check(insideBox(boundsOf(shop), rootOf(eve).Position), "colle : le voleur reste dans la boutique")
	advance(glue.StopTime + glue.SlowTime - 0.3)
	check(eve:GetAttribute("TrapEffect") == "GlueMat", "colle : effet encore là juste avant la fin du ralenti")
	advance(0.6)
	check(eve:GetAttribute("TrapEffect") == nil, "colle : libre après arrêt + ralenti")
	rest()

	section("banane (2e) : arrêt 1,5 s")
	check(Traps.ById.BananaPeel.Animation == "TrapSlip" and Traps.ById.BananaPeel.StopTime == 1.5, "banane : TrapSlip, arrêt 1,5 s")
	state = sweep(2)
	check(state == "Triggered" and eve:GetAttribute("TrapEffect") == "BananaPeel", `banane prise ({state}, {eve:GetAttribute("TrapEffect")})`)
	check(insideBox(boundsOf(shop), rootOf(eve).Position), "banane : le voleur reste dans la boutique")
	advance(1.2)
	check(eve:GetAttribute("TrapEffect") == "BananaPeel", "encore arrêté à 1,2 s")
	advance(0.5)
	check(eve:GetAttribute("TrapEffect") == nil, "libre à 1,7 s")
	rest()

	section("portique (3e)")
	state = sweep(3)
	check(state == "Triggered" and eve:GetAttribute("TrapEffect") == "AlarmGate", `portique pris ({state}, {eve:GetAttribute("TrapEffect")})`)
	rest()

	section("trappe (4e) sans objet : sortie devant la porte")
	check(Traps.ById.TrapDoor.Eject == true and Traps.ById.GlueMat.Eject == false, "Eject : trappe seulement")
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
	standBy(eve, shop, 1)
	local index = shop:GetAttribute("PlotIndex")
	fireAs(eve, "StealItem", index, 1, "Begin")
	flush()
	advance(sharedModule("Config/PvP").StealGrabTime + 0.05)
	fireAs(eve, "StealItem", index, 1, "End")
	flush()
	check(CarryService.IsCarrying(eve), "Eve porte l'objet de Bob")
	check(displayModel(shop, 1) == nil, "présentoir 1 vide pendant la fuite")
	check(trapAt(shop, 4):GetAttribute("TrapState") == "Armed", "trappe réarmée")
	state = sweep(4)
	check(state == "Triggered", `trappe prise en portant ({state})`)
	advance(0.2)
	check(not CarryService.IsCarrying(eve), "Eve ne porte plus rien")
	check(DataService.Get(bob).Display["1"] == "bob-soda" and DataService.Get(bob).Items["bob-soda"] ~= nil, "l'objet est de nouveau exposé chez Bob")
	check(DataService.Get(eve).Items["bob-soda"] == nil, "rien chez Eve")
	check(displayModel(shop, 1) ~= nil, "modèle de nouveau sur le présentoir 1")
	check(not insideBox(boundsOf(shop), rootOf(eve).Position), "Eve sortie de Bounds")
end

section("sortie")
check(logCount("[TrapService]", "WARN") == 0, "aucun avertissement de TrapService")
summary(`scénario a296 pièges {MODE} ({if NEW_TRAPS then "nouvelle disposition" else "ancienne disposition"})`)
