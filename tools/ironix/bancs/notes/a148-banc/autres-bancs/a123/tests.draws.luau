--!nocheck
-- I. a148 (vague 42, 3e commit, L-145 (a)) : sur beaucoup d'ouvertures sur place, la rareté de la caisse est un
-- minimum (aucun Commun d'une caisse Mythique, coffre et camion) et les tailles du coffre suivent SizeOdds
-- (Huge 80 %, Colossal 20 %). Vrai StoreHeistService.

moduleScript(SERVICES, "StoreHeistService", "server/Services/StoreHeistService.luau")
local Tool = serverModule("ToolService")
local FortuneTower = sharedModule("Config/FortuneTower")
local TruckEvent = sharedModule("Config/TruckEvent")
local Rarities = sharedModule("Config/Rarities")
startServer()
local A = newPlayer("Alice")
local B = newPlayer("Bob")
spawnCharacter(A, Vector3.new(670, 3, 0))
spawnCharacter(B, Vector3.new(670, 3, 6))
giveTool(A, "Hammer")
Tool.damage[A] = 1e12

local function folderOf(id)
	local model = Workspace:FindFirstChild(`EventShelf_{id}`)
	return model and model:FindFirstChild("ShelfBoxes")
end
-- Ouvre toutes les caisses du rayon `id`, puis renvoie { caisse, objet, taille } pour chaque objet sorti.
local function openAll(id)
	local folder = folderOf(id)
	local boxRarity = {}
	for _, box in if folder then folder:GetChildren() else {} do
		if hasTag(box, "ShelfBox") then
			local slotId = box:GetAttribute("SlotId")
			boxRarity[slotId] = box:GetAttribute("BoxRarity")
			moveTo(A, box:GetPivot().Position + Vector3.new(0, 3, 0))
			fireAs(A, "OpenShelfBox", slotId)
			advance(1.05, 0.05)
			fireAs(A, "OpenShelfBox", slotId)
			flush()
		end
	end
	advance(4, 0.1)
	local out = {}
	for _, item in if folder then folder:GetChildren() else {} do
		if hasTag(item, "ShelfItem") then
			table.insert(out, { box = boxRarity[item:GetAttribute("SlotId")], rarity = item:GetAttribute("Rarity"), size = item:GetAttribute("MutationSize") })
		end
	end
	return out
end
local function below(entry)
	local box, got = Rarities.ById[entry.box], Rarities.ById[entry.rarity]
	return box == nil or got == nil or got.Order < box.Order
end

section("I1. Coffre : 25 vitrines, 200 caisses")
local draws, lower, commons, huge, colossal, other = 0, 0, 0, 0, 0, 0
for _ = 1, 25 do
	Workspace:SetAttribute("FortuneTest", true)
	flush()
	local vault = currentVault()
	moveTo(A, Vector3.new(678, 3, 0))
	if A.Character:FindFirstChildWhichIsA("Tool") == nil then
		giveTool(A, "Hammer")
	end
	fireAs(A, "HitWindow", vault:GetAttribute("WindowId"))
	advance(0.3)
	for _, entry in openAll(`Truck_Fortune_{vault:GetAttribute("VaultNumber")}`) do
		draws += 1
		if below(entry) then
			lower += 1
		end
		if entry.rarity == "Common" then
			commons += 1
		end
		if entry.size == "Huge" then
			huge += 1
		elseif entry.size == "Colossal" then
			colossal += 1
		else
			other += 1
		end
	end
end
check(draws == 200, `I1a 200 objets sortis ({draws})`)
check(lower == 0 and commons == 0, `I1b jamais sous la rareté de la caisse (Mythique ou Secret) : {lower} en dessous, {commons} Commun(s)`)
check(other == 0, `I1c toujours Huge ou Colossal ({other} autre(s))`)
local share = huge / math.max(draws, 1)
check(share > 0.68 and share < 0.9, `I1d Huge ≈ 80 % ({huge} Huge, {colossal} Colossal)`)

section("I2. Camion : la rareté de chaque caisse est un minimum")
Workspace:SetAttribute("FortuneTest", "Seal")
flush()
local truckDraws, truckLower = 0, 0
for n = 1, 4 do
	Workspace:SetAttribute("TruckSpawnNow", 2)
	flush()
	advance(4)
	local truck = currentTruck()
	if truck then
		local root = truck:GetPivot().Position
		moveTo(A, root + Vector3.new(0, 3, 10))
		if A.Character:FindFirstChildWhichIsA("Tool") == nil then
			giveTool(A, "Hammer")
		end
		fireAs(A, "HitWindow", truck:GetAttribute("WindowId"))
		advance(2.5, 0.1) -- caisses en vol
		for _, entry in openAll(`Truck_{truck:GetAttribute("TruckNumber")}`) do
			truckDraws += 1
			if below(entry) then
				truckLower += 1
			end
		end
		advance(TruckEvent.RemoveDelay + TruckEvent.FlightTime + TruckEvent.BoxLifetime, 1)
	end
end
check(truckDraws >= 36, `I2a au moins 36 objets sortis des camions ({truckDraws})`)
check(truckLower == 0, `I2b jamais sous la rareté de la caisse ({truckLower} en dessous)`)
summary("scénario tirages des événements")
