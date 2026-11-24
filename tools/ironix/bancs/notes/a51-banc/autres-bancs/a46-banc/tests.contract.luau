--!nocheck
-- Scénario « contract » (L-086) : UnboxBench_01 à _04 et VaultSlot_01 à _03 sont facultatifs et muets
-- au contrat de la parcelle (Contract/Models, Silent) : absents, en tout ou en partie, rien n'est écrit ;
-- présents, ils restent contrôlés (doublon, classe). Les présentoirs DisplaySlot_01 à _20 restent
-- obligatoires.

moduleScript(SERVICES, "ContractChecker", "server/Services/ContractChecker.luau")
startServer()
local Models = sharedModule("Contract/Models")
local Checker = serverModule("ContractChecker")
local function rerun()
	clearLog()
	Checker.Start()
	flush()
end
local function lines(pattern)
	return logCount(pattern, nil, "server")
end

section("Contract/Models : la parcelle")
local plotSpec = Models.Plot
check(plotSpec ~= nil, "spec Plot trouvée")
local byName = {}
for _, part in plotSpec.Parts do
	byName[part.Name] = part
end
check(byName["UnboxBench_%02d"] and byName["UnboxBench_%02d"].Silent == true, "UnboxBench_%02d : Silent")
check(byName["VaultSlot_%02d"] and byName["VaultSlot_%02d"].Silent == true, "VaultSlot_%02d : Silent")
check(byName["DisplaySlot_%02d"] and not byName["DisplaySlot_%02d"].Silent and not byName["DisplaySlot_%02d"].Optional, "DisplaySlot_%02d : toujours obligatoire")

section("ContractChecker : établis présents, coffre absent")
rerun()
check(logHas("[Contrat] Contrat :", nil, "server"), "le vérificateur tourne jusqu'au bout")
check(lines("UnboxBench") == 0, "rien sur UnboxBench (présents)")
check(lines("VaultSlot") == 0, "rien sur VaultSlot (absents des boutiques du banc)")
check(lines("ContractChecker.Start") == 0, "sans erreur")

section("établis retirés en partie, puis en tout")
local plot = SHOPS[1].model
plot:FindFirstChild("UnboxBench_02", true):Destroy()
rerun()
check(lines("UnboxBench") == 0, "UnboxBench_02 retiré : rien d'écrit")
for _, entry in SHOPS do
	for i = 1, 4 do
		local att = entry.model:FindFirstChild(string.format("UnboxBench_%02d", i), true)
		if att then
			att:Destroy()
		end
	end
end
rerun()
check(lines("UnboxBench") == 0 and lines("VaultSlot") == 0, "tous retirés : rien d'écrit")

section("présent, il reste contrôlé")
local floor = plot:FindFirstChild("PlotFloor")
make("Attachment", { Name = "VaultSlot_01" }, floor)
make("Attachment", { Name = "VaultSlot_01" }, floor)
rerun()
check(lines("2 éléments nommés VaultSlot_01") >= 1, "VaultSlot_01 en double : signalé")
local slot = plot:FindFirstChild("DisplaySlot_07", true)
slot.Name = "DisplaySlot_7"
rerun()
check(lines("DisplaySlot_07") >= 1, "un présentoir manquant reste signalé")

summary("scénario contract")
