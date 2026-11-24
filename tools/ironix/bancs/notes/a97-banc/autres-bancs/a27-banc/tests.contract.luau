--!nocheck
-- A. Contrat : ENV_Event_Truck et FX_BoxTrail dans Contract/Models, vérifiés par le ContractChecker.

local Models = sharedModule("Contract/Models")
local Checker = serverModule("ContractChecker")

-- Lignes du rapport d'une catégorie, du dernier passage du vérificateur.
local function reportLines(category, kind)
	local out = {}
	for _, line in LOG do
		if (kind == nil or line.kind == kind) and string.find(line.text, `[Contrat] {category} ·`, 1, true) then
			table.insert(out, line.text)
		end
	end
	return out
end
local function rerun()
	clearLog()
	Checker.Start()
	flush()
end
local function anyLine(lines, pattern)
	for _, text in lines do
		if string.find(text, pattern, 1, true) then
			return true
		end
	end
	return false
end

section("A. Contrat du camion et de sa traînée")
check(Models.Truck ~= nil and Models.BoxTrail ~= nil, "A1 Contract/Models a Truck et BoxTrail")
check(table.find(Models.List, Models.Truck) ~= nil and table.find(Models.List, Models.BoxTrail) ~= nil, "A2 tous deux dans Models.List (rapport)")
check(Models.Truck.PrimaryPart == "Root" and table.find(Models.Truck.Names, "ENV_Event_Truck") ~= nil, "A3 camion : nom exact ENV_Event_Truck, PrimaryPart Root")

-- Un décor ENV_ qui n'est pas le camion : jamais vérifié comme un camion.
local lamp = make("Model", { Name = "ENV_Z1_Lamp_01" }, MAP)
make("Part", { Name = "Pole", Anchored = true }, lamp)

startServer() -- le ContractChecker tourne au Start, en Studio
local problems = reportLines("Événements", "WARN")
check(#problems == 0, `A4 camion et traînée livrés conformes : aucun problème ({#problems})`)
if #problems > 0 then
	for _, text in problems do
		print("    " .. text)
	end
end
check(not logHas("pas encore livrés : ENV_Event_Truck") and not logHas("pas encore livrés : FX_BoxTrail"), "A5 rien d'annoncé « pas encore livré »")
check(not logHas("ENV_Z1_Lamp_01"), "A6 un autre modèle ENV_ n'est pas pris pour le camion")
check(logHas("[Contrat] Contrat :"), "A7 rapport complet (dernière ligne écrite)")
check(not logHas("ContractChecker.Start"), "A8 le vérificateur tourne sans erreur")

section("A'. Camion et traînée mal livrés")
local truck = TRUCK_ASSET
truck:FindFirstChild("BoxSpawn_07", true):Destroy()
truck:FindFirstChild("Piece_13", true).Name = "Piece_13b"
truck.Root.Transparency = 0
make("Script", { Name = "FX_Smoke" }, truck)
TRAIL_ASSET:FindFirstChild("TrailBottom", true).Name = "Trailbottom"
rerun()
problems = reportLines("Événements", "WARN")
check(anyLine(problems, "BoxSpawn_07"), "A9 BoxSpawn_07 manquant signalé")
check(anyLine(problems, "Piece_13"), "A10 Piece_13 manquant signalé")
check(anyLine(problems, "Root doit être invisible"), "A11 Root visible signalé")
check(anyLine(problems, "le renommer en TrailBottom"), "A12 TrailBottom mal écrit : nom proposé")
check(anyLine(reportLines("Scripts", "WARN"), "aucun script dans ENV_Event_Truck"), "A13 script dans le camion signalé (catégorie Scripts)")

section("A''. Pas encore livrés")
truck:Destroy()
TRAIL_ASSET:Destroy()
rerun()
local pendings = reportLines("Événements", "PRINT")
check(anyLine(pendings, "pas encore livrés : ENV_Event_Truck"), "A14 camion absent : « pas encore livré »")
check(anyLine(pendings, "pas encore livrés : FX_BoxTrail"), "A15 traînée absente : « pas encore livré »")
check(#reportLines("Événements", "WARN") == 0, "A16 absent n'est pas un problème")

summary("scénario contrat")
