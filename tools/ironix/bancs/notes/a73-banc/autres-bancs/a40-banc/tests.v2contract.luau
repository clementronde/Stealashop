--!nocheck
-- Copie d'a67 (2026-11-11) : avec UI_Index_v3 au contrat, UI_Index_v2 est facultatif (absent : aucune ligne).
-- Scénario « v2contract » (a56, 2026-11-10) : UI_Index_v2 au contrat 2.2 (Contract/UI), lu par le vrai
-- ContractChecker ; la copie de l'écran de Clément est conforme ; l'ancien UI_Index absent ne donne
-- aucune ligne (facultatif), présent il est toujours vérifié.

moduleScript(SERVICES, "ContractChecker", "server/Services/ContractChecker.luau")
local gui = buildIndexV2Gui(StarterGui)
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

section("Contract/UI : UI_Index_v2")
local screen = spec("UI_Index_v2")
-- a67 (2026-11-11) : depuis UI_Index_v3, UI_Index_v2 est un repli facultatif (Optional).
local V3 = spec("UI_Index_v3") ~= nil
check(screen ~= nil and screen.Class == "ScreenGui" and (screen.Optional == true) == V3, if V3 then "UI_Index_v2 est un écran du contrat, facultatif (a67 : UI_Index_v3 le remplace)" else "UI_Index_v2 est un écran du contrat, obligatoire")
local paths = {}
for _, element in screen.Elements do
	paths[element.Path] = element
end
local wanted = { "CloseButton", "Counter", "List", "List.Template", "List.Template.Icon", "List.Template.Lock", "List.Template.ItemName", "List.Template.Rays", "List.Template.Glow", "List.Template.RarityBar.Rarity", "ScrollTrack" }
for _, name in V2_SECTIONS do
	for _, sub in { "", ".ZoneName", ".ZoneBar", ".ZoneBar.Fill", ".ZoneCount", ".Cards" } do
		table.insert(wanted, name .. sub)
	end
	if name ~= "SecretsSection" then
		table.insert(wanted, name .. ".Reward")
		table.insert(wanted, name .. ".Reward.RewardLabel")
	end
end
local missing = {}
for _, path in wanted do
	if paths[path] == nil then
		table.insert(missing, path)
	end
end
check(#missing == 0 and #screen.Elements == #wanted, `les {#wanted} noms (manquants : {table.concat(missing, ", ")} ; au contrat : {#screen.Elements})`)
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
check(spec("UI_Index") ~= nil and spec("UI_Index").Optional == true, "UI_Index reste au contrat, facultatif")

section("ContractChecker : la copie de Clément est conforme")
rerun()
check(logHas("[Contrat] Contrat :", nil, "server") and not logHas("ContractChecker.Start", nil, "server"), "le vérificateur tourne jusqu'au bout, sans erreur")
check(not logHas("UI_Index_v2", nil, "server"), "UI_Index_v2 conforme : aucune ligne")
check(not logHas("UI · UI_Index.", nil, "server") and not logHas("UI_Index absent", nil, "server"), "UI_Index absent : aucune ligne (facultatif)")

section("ContractChecker : mal livré")
local list = gui.Root.Window.List
list.Zone3Section.Cards.Name = "Card"
rerun()
check(logHas("UI_Index_v2.Zone3Section.Cards introuvable", "WARN", "server"), "Cards manquant dans Zone3Section : problème")
list.Zone3Section.Card.Name = "Cards"
gui.Root.Window.ScrollTrack.Name = "ScrollBar"
rerun()
check(logHas("UI_Index_v2.ScrollTrack introuvable", "WARN", "server"), "ScrollTrack mal nommé : problème")
gui.Root.Window.ScrollBar.Name = "ScrollTrack"
list.Template.Visible = true
rerun()
check(logHas("UI_Index_v2.List.Template doit être caché (Visible = false)", "WARN", "server"), "Template visible : problème")
list.Template.Visible = false
rerun()
check(not logHas("UI_Index_v2", nil, "server"), "remis en état : plus rien à dire")
local old = buildIndexGui(StarterGui)
rerun()
check(not logHas("UI · UI_Index.", nil, "server") and not logHas("UI_Index_v2", nil, "server"), "l'ancien UI_Index encore présent et conforme : aucune ligne")
old.Root.Window.List.Template.Visible = true
rerun()
check(logHas("UI_Index.List.Template doit être caché", "WARN", "server"), "présent, il est toujours vérifié")
old:Destroy()
gui:Destroy()
rerun()
if V3 then
	check(not logHas("UI_Index_v2 absent", nil, "server") and not logHas("UI · UI_Index_v2.", nil, "server"), "a67 : UI_Index_v2 absent, aucune ligne (facultatif)")
else
	check(logHas("[Contrat] UI · UI_Index_v2 absent : écran pas encore livré", "PRINT", "server"), "UI_Index_v2 absent : « pas encore livré »")
end

summary("scénario v2contract")
