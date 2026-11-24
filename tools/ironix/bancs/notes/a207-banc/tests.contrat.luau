--!nocheck
-- Scénario « contrat » (a207, vague 63, L-201) : Contract/UI de UI_Index_v3 (nouveaux éléments facultatifs, éléments
-- retirés hors contrat) et le vrai ContractChecker sur l'écran refait puis sur l'écran d'avant.
moduleScript(SERVICES, "ContractChecker", "server/Services/ContractChecker.luau")
local gui = refaireIndexV3(buildIndexV3Gui(StarterGui))
startServer()
local UI = sharedModule("Contract/UI")
local Checker = serverModule("ContractChecker")

local function spec(name)
	for _, screen in UI.Screens do
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
-- Lignes du serveur qui citent `p`, sauf les « (facultatif) ».
local function hardLines(p)
	local out = {}
	for _, entry in LOG do
		if entry.side == "server" and string.find(entry.text, p, 1, true) and not string.find(entry.text, "(facultatif)", 1, true) then
			table.insert(out, entry.text)
		end
	end
	return out
end

section("Contract/UI")
local v3 = spec("UI_Index_v3")
local p = {}
for _, element in v3.Elements do
	p[element.Path] = element
end
local wanted = { "Zone1Section.ZoneTheme", "Zone6Section.ZoneTheme", "Zone1Section.ZoneBar.RewardIcon", "Zone6Section.ZoneBar.RewardIcon", "Rewards.ItemReward.RewardIcon", "Rewards.ItemReward.RewardCaption", "Rewards.ClaimButton.ReadyGradient", "Categories.LimitedButton" }
local bad = {}
for _, path in wanted do
	if p[path] == nil or p[path].Optional ~= true then
		table.insert(bad, path)
	end
end
check(#bad == 0, `nouveaux éléments au contrat, facultatifs (en défaut : {table.concat(bad, ", ")})`)
local gone = {}
for path in p do
	if string.find(path, "MutationTabs", 1, true) or path == "MutationCaption" or path == "Categories.SecretsButton" or string.find(path, "ZoneBar.ZoneItem", 1, true) or string.find(path, "ClaimAllButton", 1, true) then
		table.insert(gone, path)
	end
end
check(#gone == 0, `éléments retirés par L-201 hors contrat (encore là : {table.concat(gone, ", ")})`)
check(p["Rewards.ClaimButton.ClaimLabel"] ~= nil and p["Categories.NormalButton.Selected"] ~= nil and p["Zone6Section.ZoneName"] ~= nil, "ClaimLabel, NormalButton, ZoneName toujours au contrat")

section("ContractChecker : écran refait")
rerun()
check(logHas("[Contrat] Contrat :", nil, "server") and not logHas("ContractChecker.Start", nil, "server"), "le vérificateur tourne jusqu'au bout")
local lines = {}
for _, entry in LOG do
	if entry.side == "server" and string.find(entry.text, "UI_Index_v3", 1, true) then
		table.insert(lines, entry.text)
	end
end
check(#lines == 0, `UI_Index_v3 refait : aucune ligne ({table.concat(lines, " | ")})`)

section("ContractChecker : écran d'avant")
gui:Destroy()
local old = buildIndexV3Gui(StarterGui)
rerun()
local hard = hardLines("UI_Index_v3")
check(#hard == 0, `écran d'avant : aucun problème (lignes : {table.concat(hard, " | ")})`)
check(logHas("UI_Index_v3.Rewards.ItemReward.RewardIcon absent (facultatif)", nil, "server"), "écran d'avant : ItemReward signalé facultatif")
old:Destroy()
summary("scénario contrat")
