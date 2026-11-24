---------------------------------------------------------------- scénario « contract » : Contract/UI (inventaire archivé, nouveaux noms)
local UI = requireModule(ReplicatedStorage.Shared.Contract.UI, "client")
local function screens(name)
	local out = {}
	for _, s in UI.Screens do
		if s.Name == name then
			table.insert(out, s)
		end
	end
	return out
end
local function findElement(name, path)
	for _, s in screens(name) do
		for _, e in s.Elements do
			if e.Path == path then
				return e, s
			end
		end
	end
	return nil, nil
end
print("\n== C1. Inventaire archivé")
local inv = screens("UI_Inventory")
check(#inv == 1 and inv[1].Optional == true, "C1a UI_Inventory facultatif (absent : rien à dire)")
check(findElement("UI_HUD", "InventoryButton") == nil, "C1b UI_HUD.InventoryButton n'est plus au contrat")
check(findElement("UI_HUD", "InventoryButton.InventoryAlert") == nil, "C1c ni sa pastille")
check(UI.Retired.Screens["UI_HUD.InventoryButton"] ~= nil, "C1d encore livré : une note (UI.Retired)")
print("\n== C2. Nouveaux noms du HUD, tous facultatifs")
local names = { "MenuButton", "MenuButton.MenuAlert", "MenuButton.MenuAlert.Pulse", "MenuPanel", "DisplayedButton", "SpeedBoostButton", "SpeedBoostButton.Price.Amount", "SleepButton", "SleepButton.Price.Amount", "SleepButton.Cooldown", "CashSpent" }
for _, path in names do
	local e, s = findElement("UI_HUD", path)
	check(e ~= nil and e.Optional == true and s.Optional == true, `C2 {path} facultatif`)
end
check(table.find(UI.Twins.UI_HUD.Names, "MenuButton") ~= nil, "C2z MenuButton accepté dans LeftRail et LeftRailTouch (UI.Twins)")
local main = screens("UI_HUD")[1].Elements
check(main[#main].Path == "SkillTreeButton", "C3 la liste principale du HUD finit toujours par SkillTreeButton")
print("\n== C4. Config/Boosts : rien n'achète")
for _, boost in BoostsC.List do
	check(boost.Ready == false and boost.Id == 0, `C4 {boost.Key} : Ready = false, Id = 0`)
end
summary()
