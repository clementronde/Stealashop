--!nocheck
-- H. a148 (vague 42, demande de Cantin) : colis du camion ouverts sur place comme sur un rayon (rayon d'événement
-- de StoreHeistService, vrai service) : caisses en vol du BoxSpawn à leur point, maintien, chance tirée par le
-- serveur, sortie, objet et mutation, prise de l'objet (NPCItem, Truck_<n>), conducteurs, durée de vie.

moduleScript(SERVICES, "StoreHeistService", "server/Services/StoreHeistService.luau")
moduleScript(CONTROLLERS, "HeistController", "client/Controllers/HeistController.luau")
setFeature("FortuneTower", false)
local Tool = serverModule("ToolService")
local Carry = serverModule("CarryService")
local TruckEvent = sharedModule("Config/TruckEvent")
local ShelfOpen = sharedModule("Config/ShelfOpen")
local Mutations = sharedModule("Config/Mutations")
local Items = sharedModule("Config/Items")
startServer()
local A = newPlayer("Alice")
local B = newPlayer("Bob")
spawnCharacter(A, Vector3.new(140, 3, 10), Vector3.new(0, 0, -1))
spawnCharacter(B, Vector3.new(140, 3, -14))
giveTool(A, "Crowbar")
Tool.damage[A] = 1e12
startClient(A)

local function shelfChildren(tag)
	local out = {}
	local model = Workspace:FindFirstChild("EventShelf_Truck_1")
	local folder = model and model:FindFirstChild("ShelfBoxes")
	for _, child in if folder then folder:GetChildren() else {} do
		if hasTag(child, tag) then
			table.insert(out, child)
		end
	end
	table.sort(out, function(a, b)
		return a.Name < b.Name
	end)
	return out
end
local function hold(player, remote, slotId, spot)
	moveTo(player, spot)
	fireAs(player, remote, slotId)
	advance(1.05, 0.05)
	fireAs(player, remote, slotId)
	flush()
end

section("H1. Explosion : caisses sur un rayon d'événement, en vol")
Workspace:SetAttribute("TruckSpawnNow", 2)
flush()
advance(4)
local truck = currentTruck()
fireAs(A, "HitWindow", truck:GetAttribute("WindowId"))
advance(0.1)
local boxes = shelfChildren("ShelfBox")
check(#boxes == 12, `H1a 12 caisses sur le rayon d'événement Truck_1 ({#boxes})`)
check(#truckDrops() == 0, "H1b plus aucun colis du camion au sol à prendre fermé")
local flying = 0
for _, box in boxes do
	if box:GetAttribute("Landed") == false then
		flying += 1
	end
end
check(flying == 12, `H1c les caisses volent du camion à leur point ({flying} en vol)`)
advance(2, 0.1)
local landed, okTier = 0, true
for _, box in boxes do
	if box:GetAttribute("Landed") == true then
		landed += 1
	end
	if box:GetAttribute("BoxRarity") == nil or box:GetAttribute("Tier") == nil then
		okTier = false
	end
end
check(landed == 12, `H1d posées au bout du vol ({landed})`)
check(okTier, "H1e chaque caisse a son type (Tier) et sa rareté de caisse (BoxRarity)")

section("H2. Ouverture sur place, prise de l'objet")
local first = boxes[1]
local slotId = first:GetAttribute("SlotId")
local spot = first:GetPivot().Position + Vector3.new(0, 3, 2)
hold(B, "OpenShelfBox", slotId, spot + Vector3.new(40, 0, 0))
check(first:GetAttribute("ShelfOpenState") == nil, "H2a trop loin : pas d'ouverture")
moveTo(A, spot)
fireAs(A, "OpenShelfBox", slotId)
advance(0.3)
fireAs(A, "OpenShelfBox", slotId)
flush()
check(first:GetAttribute("ShelfOpenState") == nil, "H2b maintien trop court : pas d'ouverture")
advance(1.5)
hold(A, "OpenShelfBox", slotId, spot)
local luck = first:GetAttribute("ShelfLuck")
local inTable = false
for _, entry in ShelfOpen.LuckTable do
	if entry.Luck == luck then
		inTable = true
	end
end
check(first:GetAttribute("ShelfOpenState") == "Opening", "H2c maintien complet : ouverture lancée")
check(inTable, `H2d chance tirée par le serveur (×{luck})`)
advance(4, 0.1)
local items = shelfChildren("ShelfItem")
local item = items[1]
local def = item and Items.ById[item:GetAttribute("ItemId")]
check(#items == 1 and def ~= nil and def.Rarity == item:GetAttribute("Rarity"), "H2e l'objet sort, du catalogue")
local size = item and item:GetAttribute("MutationSize")
local effect = item and item:GetAttribute("MutationEffect")
check((size == nil or Mutations.SizeById[size] ~= nil) and (effect == nil or type(effect) == "string"), `H2f mutation et taille tirées comme en magasin ({size}, {effect})`)
hold(A, "GrabItem", slotId, spot)
local payload = Carry.GetPayload(A)
check(payload and payload.Kind == "NPCItem" and payload.StoreId == "Truck_1" and payload.Luck == luck, "H2g Alice porte l'objet (NPCItem, Truck_1, sa chance)")

section("H3. Mutations sur plusieurs caisses")
-- Bob ouvre les 11 autres : objets sortis, mutation tirée à la sortie (une au moins sur 11, très probable).
local mutated, revealed = 0, 0
for index = 2, #boxes do
	local box = boxes[index]
	hold(B, "OpenShelfBox", box:GetAttribute("SlotId"), box:GetPivot().Position + Vector3.new(0, 3, 0))
end
advance(4, 0.1)
for _, it in shelfChildren("ShelfItem") do
	revealed += 1
	if it:GetAttribute("MutationSize") ~= nil or it:GetAttribute("MutationEffect") ~= nil then
		mutated += 1
	end
end
check(revealed == 11, `H3a 11 objets sortis ({revealed})`)
print(`    (information) {mutated} objet(s) muté(s) sur {revealed}`)

section("H4. Durée de vie")
advance(TruckEvent.FlightTime + TruckEvent.BoxLifetime, 0.5)
check(Workspace:FindFirstChild("EventShelf_Truck_1") == nil, "H4a rayon retiré à FlightTime + BoxLifetime s (objets non pris compris)")
check(Carry.IsCarrying(A), "H4b l'objet porté reste porté")
summary("scénario camion, ouverture sur place")
