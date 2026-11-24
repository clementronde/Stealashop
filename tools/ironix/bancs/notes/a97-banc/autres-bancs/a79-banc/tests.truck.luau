--!nocheck
-- a79, scénario « truck » (L-097 point 3) sur le faux Roblox et la mise en place du banc a27 (copie d'a51) :
--   T. camion ENV_Event_Truck_<rareté la plus haute de son chargement>, conducteurs repris du camion de
--      base, contenu tiré à l'apparition (le chargement lâché est celui qui a choisi le modèle) ;
--   L. colis lâchés : BOX_<Rareté>, sinon BOX_<Tier> ; teinte seulement sur le repli ;
--   H. halo du colis au sol sans doublon des effets du modèle ; P. colis porté (CarryService) ;
--   F. replis du camion : modèle par rareté absent (ligne dans la sortie), incomplet (avertissement).

local Tool = serverModule("ToolService")
local Carry = serverModule("CarryService")
local Items = sharedModule("Config/Items")
local Rarities = sharedModule("Config/Rarities")
local EVENTS = ASSETS:FindFirstChild("Events")
local BOXES = make("Folder", { Name = "Boxes" }, ASSETS)

-- Colis de Clément : Tint (PrimaryPart, d'une couleur à lui), pièce Mark_<nom>, effets éventuels.
local MODEL_COLOR = Color3.new(0.11, 0.22, 0.33)
local function boxModel(name, mark, light, particles)
	local m = make("Model", { Name = name })
	local tint = make("Part", {
		Name = "Tint",
		Anchored = true,
		Size = Vector3.new(1.8, 1.2, 1.8),
		CFrame = CFrame.new(0, 0.6, 0),
		PivotOffset = CFrame.new(0, -0.6, 0),
		Color = MODEL_COLOR,
	}, m)
	m.PrimaryPart = tint
	make("Part", { Name = "Mark_" .. mark, Anchored = true, Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(0, 1.3, 0) }, m)
	if light then
		make("PointLight", { Name = "Glow" }, tint)
	end
	if particles then
		make("ParticleEmitter", { Name = "Sparkles" }, tint)
	end
	m.Parent = BOXES
	return m
end
for _, tier in { "Standard", "Premium", "Luxe" } do
	boxModel("BOX_" .. tier, "Tier_" .. tier, false, false)
end
-- Pas de BOX_Common ni de BOX_Mythic : ces colis-là prennent BOX_<Tier>.
local DELIVERED = { Uncommon = true, Rare = true, Epic = true, Legendary = true, Secret = true }
boxModel("BOX_Uncommon", "Uncommon", false, false)
boxModel("BOX_Rare", "Rare", false, false)
boxModel("BOX_Epic", "Epic", true, false)
boxModel("BOX_Legendary", "Legendary", true, true)
boxModel("BOX_Secret", "Secret", true, true)

-- Un conducteur dans le camion de base (les camions par rareté n'en ont pas, relevé du 2026-11-11).
local rig = make("Model", { Name = "TruckDriver_01" })
local hrp = make("Part", { Name = "HumanoidRootPart", Anchored = true, Size = Vector3.new(2, 2, 1), CFrame = CFrame.new(-16, 3, 0) }, rig)
make("Humanoid", { Name = "Humanoid" }, rig)
rig.PrimaryPart = hrp
rig.Parent = TRUCK_ASSET

local function rarityTrucks(complete)
	local list = {}
	for _, rarity in Rarities.List do
		local t = buildTruck(EVENTS)
		t.Name = "ENV_Event_Truck_" .. rarity.Id
		make("Part", { Name = "Mark_" .. rarity.Id, Anchored = true, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(0, 20, 0) }, t)
		if not complete then
			t:FindFirstChild("HealthBarPoint", true):Destroy()
		end
		table.insert(list, t)
	end
	return list
end
local function markOf(model)
	for _, child in model:GetChildren() do
		if string.sub(child.Name, 1, 5) == "Mark_" then
			return string.sub(child.Name, 6)
		end
	end
	return nil
end
local function haloOf(model)
	for _, d in model:GetDescendants() do
		if d.Name == "HaloPoint" then
			return d
		end
	end
	return nil
end
local function count(root, class, name)
	local n = 0
	if root == nil then
		return 0
	end
	for _, d in root:GetDescendants() do
		if d:IsA(class) and (name == nil or string.sub(d.Name, 1, #name) == name) then
			n += 1
		end
	end
	return n
end
local function itemOf(rarityId)
	for _, item in Items.List do
		if item.Rarity == rarityId and not item.TutorialOnly then
			return item
		end
	end
	return nil
end
local payloads = 0
local function payload(rarityId, tier)
	local item = itemOf(rarityId)
	payloads += 1
	return {
		Kind = "NPCBox",
		Tier = tier,
		Zone = item.Zone or 1,
		Rarity = rarityId,
		ItemId = item.Id,
		StoreId = "Test",
		SlotId = `Test/{payloads}`,
	}
end

local trucksByRarity = rarityTrucks(true)
startServer()
local A = newPlayer("Alice")
spawnCharacter(A, Vector3.new(240, 3, 10), Vector3.new(0, 0, -1))
giveTool(A, "Hammer")
Tool.damage[A] = 600
startClient(A)

section("T. Camion au modèle de la rareté la plus haute de son chargement")
check(logHas("camions par rareté (le plus rare du chargement) : Common, Uncommon, Rare, Epic, Legendary, Mythic, Secret"), "T1 Start : les 7 camions par rareté annoncés")
clearLog()
Workspace:SetAttribute("TruckSpawnNow", 3)
flush()
local truck = currentTruck()
local truckMark = markOf(truck)
local driver = truck:FindFirstChild("TruckDriver_01")
local rootFrame = truck.PrimaryPart.CFrame
check(truck ~= nil and truckMark ~= nil, `T2 copie d'un ENV_Event_Truck_<Rareté> ({truckMark})`)
check(logHas(`modèle ENV_Event_Truck_{truckMark}, 1 conducteur(s) repris de ENV_Event_Truck`), "T3 la sortie dit le modèle et les conducteurs repris")
check(driver ~= nil and driver:FindFirstChildOfClass("Humanoid") ~= nil, "T4 conducteur du camion de base copié dans le camion par rareté")
-- Copie a97 : le camion livré debout est couché à sa place (toutes ses pièces sauf Root) : le conducteur repris
-- garde sa place par rapport à la caisse (Pieces/Piece_01), celle qu'il avait par rapport à Root dans le modèle.
local template = EVENTS:FindFirstChild("ENV_Event_Truck_" .. tostring(truckMark))
local templateRoot = template and template:FindFirstChild("Root")
local templatePiece = template and template:FindFirstChild("Piece_01", true)
local templateBody = templatePiece and templatePiece:FindFirstChild("Body")
local piece = truck:FindFirstChild("Piece_01", true)
local body = piece and piece:FindFirstChild("Body") -- sa pièce (le pivot d'un Model imbriqué ne suit pas toujours le faux Roblox)
local rel = nil
if driver and templateRoot and templateBody and body then
	local expected = templateRoot.CFrame:ToObjectSpace(templateBody.CFrame):Inverse() * Vector3.new(-16, 2.5, 0)
	rel = body.CFrame:PointToObjectSpace(driver:GetPivot().Position) - expected
end
check(rel ~= nil and rel.Magnitude < 1e-3, `T5 (a97) à la même place par rapport à la caisse (écart {rel})`)
check(TRUCK_ASSET:FindFirstChild("TruckDriver_01") ~= nil and trucksByRarity[1]:FindFirstChild("TruckDriver_01") == nil, "T6 modèles de Clément intacts (rien ajouté aux assets)")

Workspace:SetAttribute("TruckSpawnNow", "Explode")
flush()
advance(3)
local drops = truckDrops()
local top, wrong, byRarity, byTier, painted, unpainted = nil, {}, 0, 0, 0, 0
for _, model in drops do
	local p = Carry.GetDrop(model:GetAttribute("DropId"))
	local r = Rarities.ById[p.Rarity]
	if top == nil or r.Order > top.Order then
		top = r
	end
	local mark = markOf(model)
	local tint = model:FindFirstChild("Tint", true)
	if DELIVERED[p.Rarity] then
		if mark == p.Rarity then
			byRarity += 1
			if tint.Color ~= MODEL_COLOR then
				painted += 1
			end
		else
			table.insert(wrong, `{p.Rarity} {p.Tier} : {mark}`)
		end
	else
		if mark == "Tier_" .. p.Tier then
			byTier += 1
			if tint.Color ~= r.Color then
				unpainted += 1
			end
		else
			table.insert(wrong, `{p.Rarity} {p.Tier} : {mark}`)
		end
	end
end
check(#drops == 12, `T7 12 colis lâchés ({#drops})`)
check(top ~= nil and truckMark == top.Id, `T8 camion {truckMark} = rareté la plus haute des colis lâchés ({top and top.Id})`)

section("L. Colis lâchés au modèle de leur rareté")
check(#wrong == 0, `L1 BOX_<Rareté> livré, sinon BOX_<Tier> ({table.concat(wrong, " ; ")})`)
check(byRarity >= 1 and byTier >= 1, `L2 les deux cas vus (rareté {byRarity}, type {byTier})`)
check(painted == 0, "L3 BOX_<Rareté> garde la couleur de Clément")
check(unpainted == 0, "L4 repli BOX_<Tier> teint à la couleur de la rareté, comme avant")

section("H. Halo du colis au sol, sans doublon des effets du modèle")
local function placed(rarityId, tier)
	local id = Carry.PlaceDrop(payload(rarityId, tier), Vector3.new(200, 0, 0), 60)
	flush()
	return Workspace.CarryDrops:FindFirstChild(id)
end
local unc = placed("Uncommon", "Standard")
local uh = haloOf(unc)
check(markOf(unc) == "Uncommon" and uh ~= nil and count(uh, "Light") == 1 and count(uh, "ParticleEmitter", "HaloSparkles") == 1 and count(uh, "Beam") == 0, "H1 Peu commun (modèle sans effet) : lumière et étincelles du halo")
local epic = placed("Epic", "Premium")
local eh = haloOf(epic)
check(markOf(epic) == "Epic" and eh ~= nil and count(eh, "Light") == 0 and count(eh, "ParticleEmitter", "HaloSparkles") == 1, "H2 Épique (Glow dans le modèle) : pas de 2e lumière, étincelles du halo")
check(count(epic, "Light") == 1, "H3 Épique : une seule lumière en tout (celle de Clément)")
local leg = placed("Legendary", "Luxe")
local lh = haloOf(leg)
check(markOf(leg) == "Legendary" and lh ~= nil and count(lh, "Light") == 0 and count(lh, "ParticleEmitter") == 0 and count(lh, "Beam", "HaloRay_") == 8, "H4 Légendaire (Sparkles et Glow) : seulement les 8 rayons du halo")
check(count(leg, "Light") == 1 and count(leg, "ParticleEmitter") == 1, "H5 Légendaire : une lumière et un émetteur en tout (ceux de Clément)")
local myth = placed("Mythic", "Luxe")
local mh = haloOf(myth)
check(markOf(myth) == "Tier_Luxe" and mh ~= nil and count(mh, "Light") == 1 and count(mh, "ParticleEmitter", "HaloSparkles") == 1 and count(mh, "Beam", "HaloRay_") == 8, "H6 Mythique sans BOX_Mythic : BOX_Luxe et tout le halo du code")
check(myth:FindFirstChild("Tint", true).Color == Rarities.ById.Mythic.Color, "H7 repli BOX_Luxe teint en Mythique")
local sec = placed("Secret", "Luxe")
check(markOf(sec) == "Secret" and sec:HasTag("CarryRainbow"), "H8 Secret : BOX_Secret, arc-en-ciel animé gardé (tag CarryRainbow)")

section("P. Colis porté")
local carried = payload("Rare", "Premium")
check(Carry.StartCarry(A, carried) == true, "P1 StartCarry d'un Rare (Premium)")
flush()
local visual = A.Character:FindFirstChild("CarryVisual")
check(visual ~= nil and markOf(visual) == "Rare", `P2 porté : BOX_Rare ({visual and markOf(visual)})`)
check(visual and visual:FindFirstChild("Tint", true).Color == MODEL_COLOR, "P3 porté : pas reteint")
Carry.Fail(A, "Test")
flush()
local carried2 = payload("Common", "Premium")
Carry.StartCarry(A, carried2)
flush()
local visual2 = A.Character:FindFirstChild("CarryVisual")
check(visual2 ~= nil and markOf(visual2) == "Tier_Premium" and visual2:FindFirstChild("Tint", true).Color == Rarities.ById.Common.Color, "P4 Commun sans BOX_Common : BOX_Premium teint en Commun")
Carry.Fail(A, "Test")
flush()

section("F. Replis du camion")
for _, t in trucksByRarity do
	t:Destroy()
end
clearLog()
Workspace:SetAttribute("TruckSpawnNow", 2)
flush()
local fallback = currentTruck()
check(fallback ~= nil and markOf(fallback) == nil and fallback:FindFirstChild("TruckDriver_01") ~= nil, "F1 aucun camion par rareté : ENV_Event_Truck, avec son conducteur")
check(logHas("pas rangé dans Assets : camion ENV_Event_Truck à la place") and logCount("pas rangé dans Assets", "WARN") == 0, "F2 une ligne dans la sortie, pas un avertissement")
check(logHas("modèle ENV_Event_Truck,"), "F3 la sortie dit le modèle de base")
rarityTrucks(false)
clearLog()
Workspace:SetAttribute("TruckSpawnNow", 4)
flush()
local broken = currentTruck()
check(broken ~= nil and markOf(broken) == nil, "F4 camion par rareté sans HealthBarPoint : ENV_Event_Truck à la place")
check(logHas("il manque HealthBarPoint (Contract/Models) : camion ENV_Event_Truck à la place", "WARN"), "F5 avertissement : ce qui manque")

summary("scénario truck")
