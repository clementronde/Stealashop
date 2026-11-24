--!nocheck
-- Scénario « contract » : UI_Index au contrat 2.2 (Contract/UI), lu par le vrai ContractChecker. La copie
-- de l'écran de Clément (relevé de Studio du 2026-11-08) est conforme : aucune ligne sur UI_Index ; un
-- nom manquant, un Template visible ou l'écran absent sont signalés comme pour les autres écrans.

moduleScript(SERVICES, "ContractChecker", "server/Services/ContractChecker.luau")
local gui = buildIndexGui(StarterGui)
startServer()
local UI = sharedModule("Contract/UI")
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

section("Contract/UI : UI_Index")
local screen = spec(UI.Screens, "UI_Index")
check(screen ~= nil and screen.Class == "ScreenGui", "UI_Index est un écran du contrat (ScreenGui)")
local paths = {}
for _, element in screen.Elements do
	paths[element.Path] = element
end
local wanted = {
	"CloseButton", "Counter", "Tabs.Zone1Tab", "Tabs.Zone2Tab", "Tabs.Zone3Tab", "Tabs.Zone4Tab", "Tabs.Zone5Tab", "Tabs.Zone6Tab", "Tabs.SecretsTab",
	"ZoneReward", "ZoneReward.ZoneName", "ZoneReward.ZoneBar", "ZoneReward.ZoneBar.Fill", "ZoneReward.ZoneCount", "ZoneReward.Reward", "ZoneReward.Reward.RewardLabel",
	"List", "List.Template", "List.Template.Icon", "List.Template.Lock", "List.Template.ItemName", "List.Template.Rays", "List.Template.Glow", "List.Template.RarityBar.Rarity",
}
local missing = {}
for _, path in wanted do
	if paths[path] == nil then
		table.insert(missing, path)
	end
end
check(#missing == 0 and #screen.Elements == #wanted, `les {#wanted} noms lus par IndexController (manquants : {table.concat(missing, ", ")} ; au contrat : {#screen.Elements})`)
check(paths.CloseButton.Class == "GuiButton" and paths.List.Class == "ScrollingFrame" and paths["List.Template"].Template == true, "CloseButton un bouton, List une ScrollingFrame, Template cloné")
local reserved = {}
for _, name in UI.ReservedNames do
	reserved[name] = true
end
local bad = {}
for _, element in screen.Elements do
	for segment in string.gmatch(element.Path, "[^%.]+") do
		if reserved[segment] then
			table.insert(bad, element.Path)
		end
	end
end
check(#bad == 0, "aucun nom qui est aussi une propriété Roblox")
check(spec(UI.Screens, "UI_RobuxShop") ~= nil and spec(UI.Screens, "UI_HUD") ~= nil, "les autres écrans du contrat restent")

section("ContractChecker : la copie de l'écran de Clément est conforme")
rerun()
check(logHas("[Contrat] Contrat :", nil, "server"), "le vérificateur tourne jusqu'au bout")
check(not logHas("UI · UI_Index", nil, "server"), "UI_Index conforme : aucune ligne")
check(not logHas("ContractChecker.Start", nil, "server"), "sans erreur")

section("ContractChecker : mal livré, pas livré")
local template = gui.Root.Window.List.Template
template.Clip.Rays.Name = "Ray"
rerun()
check(logHas("[Contrat] UI · UI_Index.List.Template.Rays introuvable", "WARN", "server"), "Rays absent du Template : problème")
template.Clip.Ray.Name = "Rays"
template.Visible = true
rerun()
check(logHas("UI_Index.List.Template doit être caché (Visible = false)", "WARN", "server"), "Template visible : problème")
template.Visible = false
gui.Root.Tabs.SecretsTab.Name = "SecretTab"
rerun()
check(logHas("UI_Index.Tabs.SecretsTab introuvable", "WARN", "server"), "SecretsTab mal nommé : problème")
gui.Root.Tabs.SecretTab.Name = "SecretsTab"
rerun()
check(not logHas("UI · UI_Index", nil, "server"), "remis en état : plus rien à dire")
gui:Destroy()
rerun()
check(logHas("[Contrat] UI · UI_Index absent : écran pas encore livré", "PRINT", "server"), "écran absent : « pas encore livré »")

summary("scénario contract")
