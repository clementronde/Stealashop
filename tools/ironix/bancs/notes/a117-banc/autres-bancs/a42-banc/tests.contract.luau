--!nocheck
-- K. Contrat (lu par le vrai ContractChecker) : UI_Chase (écran, noms internes libres), BB_ZoneGate
-- (ZoneName, Speed, Damage), InfoPoint facultatif des arches (Contract/Models), conducteurs du camion
-- (Contract/Animations.Driver : Idle seulement, facultative).

local UI = sharedModule("Contract/UI")
local Models = sharedModule("Contract/Models")
local Animations = sharedModule("Contract/Animations")
local Checker = serverModule("ContractChecker")

local function spec(list, name)
	for _, screen in list do
		if screen.Name == name then
			return screen
		end
	end
	return nil
end
local function rerun()
	clearLog()
	Checker.Start()
	flush()
end
local function line(pattern, kind)
	return logHas(pattern, kind, "server")
end
local function problems()
	local n = 0
	for _, entry in LOG do
		if entry.side == "server" and entry.kind == "WARN" and string.find(entry.text, "[Contrat]", 1, true) and not string.find(entry.text, "avertissement", 1, true) then
			n += 1
		end
	end
	return n
end
CLIPS["rbxassetid://555001"] = { Loop = true, Priority = "Idle" }
-- Les magasins gris du banc (sans les enfants du contrat 10.4) ne servent pas ici.
for _, store in STORES do
	store.Parent = nil
end

section("K. Contract/UI, Contract/Models, Contract/Animations")
local chase = spec(UI.Screens, "UI_Chase")
check(chase ~= nil and chase.Class == "ScreenGui" and #chase.Elements == 0, "K1 UI_Chase : un ScreenGui, sans élément imposé")
local gate = spec(UI.Screens, "UI_ZoneBanner")
local names = {}
for _, element in gate and gate.Elements or {} do
	names[element.Path] = element.Class
end
check(gate ~= nil and gate.Class == "ScreenGui" and not gate.Optional and #gate.Elements == 4 and names["Banner.ZoneName"] == "TextLabel" and names["Advice.Speed"] == "TextLabel" and names["Advice.Damage"] == "TextLabel" and names.Difficulty == "TextLabel", "K2 UI_ZoneBanner (a101, L-110) : Banner.ZoneName, Advice.Speed, Advice.Damage, Difficulty (TextLabel)")
check(spec(UI.Billboards, "BB_ZoneGate") == nil, "K2b BB_ZoneGate retiré du contrat (L-110)")
-- Copie a117 (vague 34, L-127) : des entrées facultatives (pastilles « ! », Claim All) sont ajoutées après lui.
local gateRank = table.find(UI.Screens, gate)
local adminRank = nil
for rank, screen in UI.Screens do
	if screen.Name == "UI_Admin" then
		adminRank = rank
	end
end
check(gateRank ~= nil and adminRank ~= nil and gateRank > adminRank, "K2c UI_ZoneBanner ajouté en fin de liste (après UI_Admin ; copie a117 : entrées facultatives après lui)")
local arch = Models.ZoneGate
check(arch ~= nil and arch.Tag == "ZoneGate" and #arch.Parts == 1 and arch.Parts[1].Name == "InfoPoint" and arch.Parts[1].Optional and arch.Parts[1].Class == "Attachment", "K3 arches : InfoPoint facultatif (Attachment)")
-- Fusion vague 14 : a39 ajoute ensuite les comptoirs du hub ; l'arche reste juste après BoxTrail.
check(table.find(Models.List, arch) == (table.find(Models.List, Models.BoxTrail) or -1) + 1, "K4 ajouté après BoxTrail, à la suite de la liste du rapport (rien de réordonné)")
check(#Animations.Driver == 4 and Animations.Driver[1].Name == "Idle" and Animations.Driver[1].Loop and Animations.Driver[1].Priority == "Idle" and Animations.Driver[3].Name == "Run" and Animations.Driver[4].Name == "Catch", "K5 conducteurs : Idle (1re, en boucle), puis Walk, Run, Catch (2026-11-10, poursuite à venir)")

section("K'. Rien de livré : des points « pas encore livré », aucun problème")
rerun()
check(line("[Contrat] Contrat : OK", "PRINT"), "K6 Contrat : OK")
check(line("UI · UI_Chase absent : écran pas encore livré", "PRINT"), "K7 UI_Chase : pas encore livré")
check(line("UI · UI_ZoneBanner absent : écran pas encore livré", "PRINT") and not line("BB_ZoneGate", nil), "K8 UI_ZoneBanner : pas encore livré ; plus un mot sur BB_ZoneGate")
check(line("arches de zone sans aucun élément du contrat 10.4 (6, blocs de greybox ?)", "PRINT"), "K9 arches du greybox sans InfoPoint : pas encore livré, pas un problème")
check(line("Event_Truck.Drivers.Driver.Animations : pas encore livrée", nil) and line("Walk, Run, Catch", nil), "K10 conducteur avec Idle seul : Walk, Run et Catch demandés (2026-11-10)")
check(problems() == 0, `K11 aucun problème ({problems()})`)
check(not line("éléments nommés Root", nil) and not line("Root doit être", nil), "K11b le Motor6D « Root » des conducteurs R15 ne compte pas comme un 2e Root du camion")

section("K''. Livrés conformes")
buildChaseUi(false)
buildZoneBannerUi()
make("Attachment", { Name = "InfoPoint" }, GATES[3].SignPart)
rerun()
check(line("[Contrat] Contrat : OK", "PRINT"), "K12 Contrat : OK")
check(not line("UI_Chase", nil) and not line("UI_ZoneBanner", nil), "K13 UI_Chase et UI_ZoneBanner conformes : rien à dire")
check(line("(5, blocs de greybox ?)", "PRINT") and not line("ZoneGate_3", nil), "K14 l'arche 3 avec son InfoPoint passe ; les 5 autres restent « pas encore livré »")

section("K'''. Livrés de travers")
local bb = StarterGui.UI_ZoneBanner
local wrong = bb.Banner.Advice.Speed
wrong.Name = "SpeedOld"
make("Frame", { Name = "Speed" }, bb.Banner.Advice)
local badPoint = make("Part", { Name = "InfoPoint" }, GATES[4].SignPart)
StarterGui.UI_Chase.Parent = ReplicatedStorage
CLIPS["rbxassetid://555001"] = { Loop = false, Priority = "Action" }
rerun()
check(line("UI_ZoneBanner.Advice.Speed doit être un TextLabel (trouvé : Frame)", "WARN"), "K15 UI_ZoneBanner.Advice.Speed qui n'est pas un TextLabel : problème")
check(line("UI_Chase trouvé dans ReplicatedStorage, attendu dans StarterGui", "WARN"), "K16 UI_Chase rangé ailleurs : problème")
check(line("ZoneGate_4.InfoPoint doit être un Attachment (trouvé : Part)", "WARN"), "K17 InfoPoint qui n'est pas un Attachment : problème")
check(line("Drivers.Driver.Animations.Idle : sans boucle, attendu en boucle", "WARN") and line("Drivers.Driver.Animations.Idle : priorité Action, attendu Idle", "WARN"), "K18 Idle du conducteur vérifiée comme les autres (boucle, priorité)")
badPoint:Destroy()
ReplicatedStorage.UI_Chase.Parent = StarterGui
CLIPS["rbxassetid://555001"] = { Loop = true, Priority = "Idle" }

section("K''''. Conducteur sans Idle, vigile inchangé")
TRUCK_ASSET.Drivers.CoDriver.Animations:Destroy()
local guards = folder(ASSETS, "Guards")
local guardModel = make("Model", { Name = "Guard_Z1" }, guards)
local humanoid = make("Humanoid", { Name = "Humanoid" }, guardModel)
make("Animator", { Name = "Animator" }, humanoid)
make("Animation", { Name = "Idle", AnimationId = "rbxassetid://555001" }, folder(guardModel, "Animations"))
rerun()
check(line("Drivers.CoDriver.Animations absent : animations de conducteur pas encore livrées (Idle, Walk, Run, Catch)", "PRINT"), "K19 conducteur sans dossier Animations : « pas encore livrées (Idle, Walk, Run, Catch) »")
check(line("Guards.Guard_Z1.Animations : pas encore livrée(s) : Walk, Run, Catch, Tired", "PRINT"), "K20 un vigile reste vérifié comme un vigile")
check(line("Drivers.Driver.Animations : pas encore livrée", nil), "K21 le conducteur avec Idle seul : incomplet depuis le 2026-11-10")

summary("scénario contrat")
