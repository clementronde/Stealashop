--!nocheck
-- Scénario « truck » (a49, DEV-131) : mise en place du banc a27 (copie d'a46), vrais TruckEventService
-- et CarryService. Cinq camions cassés : chaque colis lâché a une mutation valide (ou aucune), tirée par
-- les mêmes règles que les rayons, et son étiquette BB_Box au sol la montre.

local Tool = serverModule("ToolService")
local Carry = serverModule("CarryService")
local Mutations = sharedModule("Config/Mutations")
local TruckEvent = sharedModule("Config/TruckEvent")
-- BB_Box de Clément (L-031) : Lines/Category, Lines/Rarity, Lines/Mutation.
do
	local assets = ReplicatedStorage:FindFirstChild("Assets") or make("Folder", { Name = "Assets" }, ReplicatedStorage)
	local ui = assets:FindFirstChild("UI") or make("Folder", { Name = "UI" }, assets)
	if ui:FindFirstChild("BB_Box") == nil then
		local bb = make("BillboardGui", { Name = "BB_Box", MaxDistance = 32 }, ui)
		local lines = make("Frame", { Name = "Lines" }, bb)
		for _, n in { "Category", "Rarity", "Mutation" } do
			make("TextLabel", { Name = n, Text = "" }, lines)
		end
	end
end
startServer()
local A = newPlayer("Alice")
spawnCharacter(A, Vector3.new(240, 3, 10), Vector3.new(0, 0, -1))
giveTool(A, "Hammer")
Tool.damage[A] = 600

section("colis du camion : mutation tirée")
local total, mutated, valid, labelsOk, fields = 0, 0, true, true, 0
for round = 1, 5 do
	Workspace:SetAttribute("TruckSpawnNow", 3)
	flush()
	advance(4) -- fusion vague 29 (2026-11-12) : le serveur refuse les coups pendant l'arrivée du camion (~3,9 s) ; sans effet sans ce refus
	local truck = currentTruck()
	if truck == nil then
		check(false, `camion n° {round} apparu`)
		break
	end
	local id = truck:GetAttribute("WindowId")
	for _ = 1, 4 do
		if truck:GetAttribute("Broken") then
			break
		end
		fireAs(A, "HitWindow", id)
		advance(0.15)
	end
	flush()
	for _, model in truckDrops() do
		local payload = Carry.GetDrop(model:GetAttribute("DropId"))
		if payload then
			total += 1
			if payload.Mutation ~= nil then
				mutated += 1
			end
			if not Mutations.IsValid(payload.Mutation) or (payload.Mutation ~= nil and payload.Mutation.Size == nil and payload.Mutation.Effect == nil) then
				valid = false
			end
			local label = model:FindFirstChild("BB_Box", true)
			local field = label and label:FindFirstChild("Mutation", true)
			local want = Mutations.Label(payload.Mutation)
			if field ~= nil then
				fields += 1
				if (want == nil and field.Visible) or (want ~= nil and (field.Text ~= want or not field.Visible)) then
					labelsOk = false
				end
			end
		end
	end
	advance(TruckEvent.BoxLifetime + TruckEvent.FlightTime + 60)
end
check(total == 60, `60 colis lâchés par 5 camions ({total})`)
check(valid, "chaque mutation : une taille et un effet au plus, Id connus")
check(mutated > 0 and mutated < total, `des colis mutés, pas tous ({mutated} sur {total})`)
check(labelsOk and fields == total, "étiquette BB_Box au sol : la mutation du payload (cachée sans mutation)")

summary("scénario truck")
