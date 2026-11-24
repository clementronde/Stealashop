--!nocheck
-- Scénario « v3contract » (a67, 2026-11-11, L-095 points 1 et 2) : UI_Index_v3 et UI_Settings au contrat
-- 2.2 (Contract/UI), UI_HUD.SettingsButton, lus par le vrai ContractChecker ; les copies des écrans de
-- Clément sont conformes ; UI_Index_v2 devient facultatif.

moduleScript(SERVICES, "ContractChecker", "server/Services/ContractChecker.luau")
local gui = buildIndexV3Gui(StarterGui)
local settings = buildSettingsGui(StarterGui)
startServer()
local UI = sharedModule("Contract/UI")
local Checker = serverModule("ContractChecker")
local Mutations = sharedModule("Config/Mutations")

local function spec(name)
	for _, screen in UI.Screens do
		if screen.Name == name then
			return screen
		end
	end
	return nil
end
local function paths(screen)
	local out = {}
	for _, element in screen.Elements do
		out[element.Path] = element
	end
	return out
end
local function rerun()
	clearLog()
	Checker.Start()
	flush()
end

section("Contract/UI")
local v3 = spec("UI_Index_v3")
check(v3 ~= nil and v3.Class == "ScreenGui" and not v3.Optional, "UI_Index_v3 au contrat, obligatoire")
check(spec("UI_Index_v2").Optional == true and spec("UI_Index").Optional == true, "UI_Index_v2 et UI_Index facultatifs")
local p = paths(v3)
local wanted = { "CloseButton", "Counter", "List", "List.Template", "List.Template.Clip", "List.Template.Icon", "List.Template.ItemName", "Detail.DetailIcon", "Detail.DetailName", "Detail.DetailRarity", "Detail.DetailIncome", "Rewards.SpeedReward.Amount", "Rewards.CashReward.Amount", "Rewards.ClaimButton.ClaimLabel", "Categories.NormalButton.Selected", "Categories.SecretsButton", "Categories.MutationsButton", "MutationCaption", "Zone1Section.ZoneBar.ZoneItem", "SecretsSection.Cards", "Zone6Section.ZoneName" }
for _, effect in Mutations.Effects do
	table.insert(wanted, `MutationTabs.{effect.Id}Tab.Selected`)
end
local missing = {}
for _, path in wanted do
	if p[path] == nil then
		table.insert(missing, path)
	end
end
check(#missing == 0, `noms de ui-index-v3.md au contrat (manquants : {table.concat(missing, ", ")})`)
check(p["List.Template"].Template == true and p["List.Template"].Class == "GuiButton", "Template : cloné, un bouton (fiche au clic)")
local s = spec("UI_Settings")
local sp = paths(s)
local wantedSettings = { "CloseButton", "MusicRow.Slider.Track", "MusicRow.Slider.Track.Fill", "MusicRow.Slider.Knob", "MusicRow.ValueLabel", "SoundRow.Slider.Knob", "SoundRow.ValueLabel", "VfxRow.Toggle", "VfxRow.Toggle.OnFill", "VfxRow.Toggle.OffFill", "VfxRow.Toggle.ToggleKnob", "VfxRow.Toggle.ToggleLabel", "ClickRow.PrevButton", "ClickRow.NextButton", "ClickRow.ChoiceLabel" }
local missingSettings = {}
for _, path in wantedSettings do
	if sp[path] == nil then
		table.insert(missingSettings, path)
	end
end
check(s ~= nil and not s.Optional and #missingSettings == 0, `UI_Settings au contrat (manquants : {table.concat(missingSettings, ", ")})`)
check(paths(spec("UI_HUD")).SettingsButton ~= nil and paths(spec("UI_HUD")).SettingsButton.Class == "GuiButton", "UI_HUD.SettingsButton au contrat, un bouton")
local reserved = {}
for _, name in UI.ReservedNames do
	reserved[name] = true
end
local bad = {}
for _, screen in { v3, s } do
	for _, element in screen.Elements do
		for segment in string.gmatch(element.Path, "[^%.]+") do
			if reserved[segment] then
				table.insert(bad, element.Path)
			end
		end
	end
end
check(#bad == 0, "aucun nom qui est aussi une propriété Roblox")

section("ContractChecker : copies conformes")
rerun()
check(logHas("[Contrat] Contrat :", nil, "server") and not logHas("ContractChecker.Start", nil, "server"), "le vérificateur tourne jusqu'au bout, sans erreur")
check(not logHas("UI_Index_v3", nil, "server"), "UI_Index_v3 conforme : aucune ligne")
check(not logHas("UI_Settings", nil, "server"), "UI_Settings conforme : aucune ligne")
check(not logHas("UI_Index_v2", nil, "server") and not logHas("UI · UI_Index.", nil, "server"), "UI_Index_v2 et UI_Index absents : aucune ligne (facultatifs)")

section("ContractChecker : mal livré")
gui.Root.Window.Detail.DetailIncome.Name = "Income"
rerun()
check(logHas("UI_Index_v3.Detail.DetailIncome introuvable", "WARN", "server"), "DetailIncome mal nommé : problème")
gui.Root.Window.Detail.Income.Name = "DetailIncome"
gui.Root.Window.ListPanel.List.Template.Visible = true
rerun()
check(logHas("UI_Index_v3.List.Template doit être caché (Visible = false)", "WARN", "server"), "Template visible : problème")
gui.Root.Window.ListPanel.List.Template.Visible = false
settings.Root.Window.Rows.ClickRow.NextButton.Name = "Next"
rerun()
check(logHas("UI_Settings.ClickRow.NextButton introuvable", "WARN", "server"), "NextButton mal nommé : problème")
settings.Root.Window.Rows.ClickRow.Next.Name = "NextButton"
rerun()
check(not logHas("UI_Index_v3", nil, "server") and not logHas("UI_Settings", nil, "server"), "remis en état : plus rien à dire")
gui:Destroy()
settings:Destroy()
rerun()
check(logHas("[Contrat] UI · UI_Index_v3 absent : écran pas encore livré", "PRINT", "server") and logHas("[Contrat] UI · UI_Settings absent : écran pas encore livré", "PRINT", "server"), "absents : « pas encore livré »")

summary("scénario v3contract")
