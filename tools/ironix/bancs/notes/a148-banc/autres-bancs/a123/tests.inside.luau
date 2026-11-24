--!nocheck
-- F. a148 (vague 42, L-145 (b) (c), demande de Cantin) : Studio, Features.FortuneTower = true (livré), avec le vrai
-- StoreHeistService et HeistController. Colis du coffre ouverts sur place comme sur un rayon (rayon d'événement) :
-- maintien, chance tirée par le serveur, sortie, prise de l'objet ; sur LootSpawn_NN, posés sur le sol du coffre ;
-- sans LootSpawn (bloc V0) : rangée devant ; Mythiques des zones 2 à 6 ; joueur jamais enfermé.

moduleScript(SERVICES, "StoreHeistService", "server/Services/StoreHeistService.luau")
moduleScript(CONTROLLERS, "HeistController", "client/Controllers/HeistController.luau")
setFeature("TruckEvent", false)
local Tool = serverModule("ToolService")
local Carry = serverModule("CarryService")
local FortuneTower = sharedModule("Config/FortuneTower")
local ShelfOpen = sharedModule("Config/ShelfOpen")
local Mutations = sharedModule("Config/Mutations")
local Items = sharedModule("Config/Items")
startServer()
local A = newPlayer("Alice")
local B = newPlayer("Bob")
local C = newPlayer("Carol")
spawnCharacter(A, Vector3.new(670, 3, 0))
spawnCharacter(B, Vector3.new(670, 3, 6))
spawnCharacter(C, Vector3.new(670, 3, -6))
giveTool(A, "Hammer")
startClient(A)

local function shelf(n)
	return Workspace:FindFirstChild(`EventShelf_Truck_Fortune_{n}`)
end
local function shelfBoxes(n)
	local out = {}
	local model = shelf(n)
	local folder = model and model:FindFirstChild("ShelfBoxes")
	for _, child in if folder then folder:GetChildren() else {} do
		if hasTag(child, "ShelfBox") then
			table.insert(out, child)
		end
	end
	table.sort(out, function(a, b)
		return a.Name < b.Name
	end)
	return out
end
local function shelfItems(n)
	local out = {}
	local model = shelf(n)
	local folder = model and model:FindFirstChild("ShelfBoxes")
	for _, child in if folder then folder:GetChildren() else {} do
		if hasTag(child, "ShelfItem") then
			table.insert(out, child)
		end
	end
	return out
end
local function breakVault()
	local vault = currentVault()
	moveTo(A, Vector3.new(678, 3, 0))
	Tool.damage[A] = FortuneTower.MaxHP
	if A.Character:FindFirstChildWhichIsA("Tool") == nil then
		giveTool(A, "Hammer") -- rangé par le portage
	end
	fireAs(A, "HitWindow", vault:GetAttribute("WindowId"))
	advance(0.3)
	return vault
end
-- Maintien complet (deux appels) sur `remote` pour l'emplacement `slotId`, debout à `spot`.
local function hold(player, remote, slotId, spot)
	moveTo(player, spot)
	fireAs(player, remote, slotId)
	advance(1.05, 0.05)
	fireAs(player, remote, slotId)
	flush()
end

section("F1. Bloc V0 (sans LootSpawn) : rangée devant, à ouvrir sur place")
Workspace:SetAttribute("FortuneTest", true)
flush()
breakVault()
local boxes = shelfBoxes(1)
check(#boxes == 8, `F1a 8 caisses sur un rayon d'événement ({#boxes})`)
check(#fortuneDrops() == 0, "F1b plus aucun colis au sol à prendre fermé")
local okRow = #boxes == 8
for _, box in boxes do
	local p = box:GetPivot().Position
	if p.X > 686 or math.abs(p.Y) > 1e-3 then
		okRow = false
	end
end
check(okRow, "F1c sans LootSpawn : rangée devant la face avant, sur le sol de la rue")
local okRarity = #boxes == 8
for _, box in boxes do
	local rarity = box:GetAttribute("BoxRarity")
	if box:GetAttribute("Tier") ~= "Luxe" or (rarity ~= "Mythic" and rarity ~= "Secret") then
		okRarity = false
	end
end
check(okRarity, "F1d caisses Luxe, rareté de caisse Mythique ou Secret (RarityOdds)")
local model = shelf(1)
check(model and hasTag(model, "EventShelf") and model:GetAttribute("HeistOpen") == true and model:GetAttribute("StoreId") == "Truck_Fortune_1", "F1e rayon d'événement : tag EventShelf, HeistOpen, StoreId Truck_Fortune_1")

section("F2. Ouverture sur place : maintien, chance du serveur, sortie, prise")
local first = boxes[1]
local slotId = first:GetAttribute("SlotId")
local spot = first:GetPivot().Position + Vector3.new(0, 3, 2)
-- Invite côté client (HeistController) : « Open » sur la caisse, sans volume Bounds.
moveTo(A, spot)
advance(0.5, 0.1)
local prompt = nil
for _, d in model:GetDescendants() do
	if d:IsA("ProximityPrompt") and d.Parent and d.Parent.Name == first:GetAttribute("Slot") then
		prompt = d
	end
end
check(prompt ~= nil and prompt.ActionText == "Open" and prompt.HoldDuration == 1, `F2a invite « Open », maintien 1 s ({prompt and prompt.ActionText})`)
check(prompt and prompt.Enabled == true, "F2b invite active sans volume Bounds, mains vides")
-- Maintien trop court : rien.
moveTo(A, spot)
fireAs(A, "OpenShelfBox", slotId)
advance(0.3)
fireAs(A, "OpenShelfBox", slotId)
flush()
check(first:GetAttribute("ShelfOpenState") == nil, "F2c maintien trop court : pas d'ouverture")
advance(1.5)
-- Trop loin : rien.
hold(B, "OpenShelfBox", slotId, spot + Vector3.new(30, 0, 0))
check(first:GetAttribute("ShelfOpenState") == nil, "F2d trop loin : pas d'ouverture")
-- Maintien complet.
hold(A, "OpenShelfBox", slotId, spot)
local luck = first:GetAttribute("ShelfLuck")
local inTable = false
for _, entry in ShelfOpen.LuckTable do
	if entry.Luck == luck then
		inTable = true
	end
end
check(first:GetAttribute("ShelfOpenState") == "Opening" and first:GetAttribute("ShelfOpenBy") == A.UserId, "F2e maintien de 1 s : ouverture lancée par Alice")
check(inTable, `F2f chance tirée par le serveur dans ShelfOpen.LuckTable (×{luck})`)
advance(4, 0.1)
local items = shelfItems(1)
check(#items == 1 and first.Parent == nil, `F2g la caisse disparaît, l'objet sort ({#items})`)
local item = items[1]
local def = item and Items.ById[item:GetAttribute("ItemId")]
check(def ~= nil and def.Rarity == item:GetAttribute("Rarity"), "F2h objet du catalogue, de la rareté annoncée")
local size = item and item:GetAttribute("MutationSize")
check(size == nil or Mutations.SizeById[size] ~= nil, `F2i taille tirée comme en magasin ({size})`)
-- Réservé à l'ouvreur.
hold(B, "GrabItem", slotId, spot)
check(not Carry.IsCarrying(B), "F2j réservé à l'ouvreur : Bob ne le prend pas")
hold(A, "GrabItem", slotId, spot)
local payload = Carry.GetPayload(A)
check(payload and payload.Kind == "NPCItem" and payload.StoreId == "Truck_Fortune_1" and payload.ItemId == item:GetAttribute("ItemId"), "F2k Alice porte l'objet (NPCItem, Truck_Fortune_1)")
check(payload and payload.Luck == luck, "F2l le portage garde la chance de l'ouverture")

section("F3. Coffre de Clément : colis sur le sol du coffre, à l'intérieur")
Carry.Fail(A, "test")
flush()
local template = make("Model", { Name = "ENV_Event_FortuneVault" })
local floor = make("Part", { Name = "Floor", Anchored = true, Size = Vector3.new(20, 2, 12), CFrame = CFrame.new(0, 1, 0), PivotOffset = CFrame.new(0, -1, 0) }, template)
template.PrimaryPart = floor
make("Part", { Name = "Back", Anchored = true, Size = Vector3.new(20, 10, 1), CFrame = CFrame.new(0, 7, 5.5) }, template)
make("Part", { Name = "Roof", Anchored = true, Size = Vector3.new(20, 1, 12), CFrame = CFrame.new(0, 12.5, 0) }, template)
make("Part", { Name = "Window", Anchored = true, Size = Vector3.new(20, 10, 0.5), CFrame = CFrame.new(0, 7, -5.75) }, template)
for i = 1, 7 do
	make("Attachment", { Name = string.format("LootSpawn_%02d", i), CFrame = CFrame.new(-8.75 + (i - 1) * 2.5, 1, 2) }, floor)
end
-- Le 8e en pièce solide (CanCollide) : le rayon l'ignore et trouve le sol sous lui.
make("Part", { Name = "LootSpawn_08", Anchored = true, CanCollide = true, Transparency = 1, Size = Vector3.new(1, 2, 1), CFrame = CFrame.new(8.75, 3, 2) }, template)
template.Parent = ASSETS:FindFirstChild("Events")
Workspace:SetAttribute("FortuneTest", true) -- remplace la vitrine ouverte : son rayon part avec elle
flush()
check(shelf(1) == nil, "F3a la vitrine remplacée emporte son rayon d'événement")
local vault = breakVault()
local window = vault:FindFirstChild("Window")
check(window.Transparency == 1 and window.CanCollide == false and window.CanQuery == false, "F3b vitre cachée : rien n'empêche d'entrer")
boxes = shelfBoxes(2)
local okInside = #boxes == 8
local pivot = vault:GetPivot()
for _, box in boxes do
	local p = pivot:PointToObjectSpace(box:GetPivot().Position)
	if math.abs(p.Y - 2) > 1e-3 or math.abs(p.Z - 2) > 1e-3 or math.abs(p.X) > 9 then
		okInside = false
	end
end
check(okInside, "F3c 8 colis sur les LootSpawn, posés sur le sol du coffre (2 studs), à l'intérieur")

section("F4. Mythiques des zones 2 à 6")
-- Une vitrine de plus pour avoir 16 caisses ouvertes en tout.
local opened = 0
local zones, zoneSeen, okZones = {}, 0, true
local function openAll(n)
	for _, box in shelfBoxes(n) do
		local id = box:GetAttribute("SlotId")
		hold(A, "OpenShelfBox", id, box:GetPivot().Position + Vector3.new(0, 3, 0))
		if box:GetAttribute("ShelfOpenState") == "Opening" then
			opened += 1
		end
	end
	advance(4, 0.1)
	for _, it in shelfItems(n) do
		local d = Items.ById[it:GetAttribute("ItemId")]
		if d and d.Zone ~= nil then
			if d.Zone < 2 or d.Zone > 6 then
				okZones = false
			end
			if d.Rarity == "Mythic" and not zones[d.Zone] then
				zones[d.Zone] = true
				zoneSeen += 1
			end
		elseif d == nil then
			okZones = false
		end
	end
end
openAll(2)
for n = 3, 6 do
	Workspace:SetAttribute("FortuneTest", true)
	flush()
	breakVault()
	openAll(n)
end
check(opened == 40, `F4a 40 caisses ouvertes sur place, une à la suite de l'autre ({opened})`)
check(okZones, "F4b tout objet rangé par zone vient des zones 2 à 6")
check(zoneSeen >= 2, `F4c Mythiques de plusieurs zones (pas seulement la 6) : {zoneSeen} zone(s)`)

section("F5. Jamais enfermé")
-- Retrait après l'ouverture : Carol dedans est posée devant.
local v = currentVault()
moveTo(C, v:GetPivot() * Vector3.new(0, 3, 2))
advance(FortuneTower.RemoveDelay + 1, 0.5)
check(v.Parent == nil and shelf(6) == nil, "F5a vitrine ouverte et son rayon retirés au bout de RemoveDelay s")
local cx = C.Character.HumanoidRootPart.Position.X
check(cx < 684 and cx > 670, `F5b Carol, dedans au retrait, posée 3 studs devant (x = {cx})`)
-- Refermée (Seal) avec quelqu'un dedans.
Workspace:SetAttribute("FortuneTest", true)
flush()
local v2 = currentVault()
moveTo(C, v2:GetPivot() * Vector3.new(0, 3, 2))
Workspace:SetAttribute("FortuneTest", "Seal")
flush()
cx = C.Character.HumanoidRootPart.Position.X
check(v2.Parent == nil and cx < 684 and cx > 670, `F5c refermée avec Carol dedans : posée devant (x = {cx})`)
check(logHas("quand elle s'est refermée", "PRINT", "server"), "F5d ligne en Studio")

section("F6. Colis jamais ouvert : disparaît au bout de BoxLifetime s")
Workspace:SetAttribute("FortuneTest", true)
flush()
breakVault()
local n7 = currentVault():GetAttribute("VaultNumber")
check(#shelfBoxes(n7) == 8, "F6a 8 caisses")
advance(FortuneTower.BoxLifetime - 1, 0.5)
check(#shelfBoxes(n7) == 8, "F6b encore là juste avant la fin")
advance(2, 0.5)
check(shelf(n7) == nil, "F6c disparues à la fin de leur durée de vie (avec le rayon)")
summary("scénario coffre à intérieur, ouverture sur place")
