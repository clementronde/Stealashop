--!nocheck
---------------------------------------------------------------- scénario « contract » : Contract/UI et ContractChecker
-- Faux Roblox d'a39 (copie a62). Instance:FindFirstAncestor (le ContractChecker s'en sert pour les doublons voulus).
if Methods.FindFirstAncestor == nil then
	function Methods.FindFirstAncestor(self, name)
		local current = self.Parent
		while current ~= nil do
			if current.Name == name then
				return current
			end
			current = current.Parent
		end
		return nil
	end
end
NEW = make
RICH = false

local UI = sharedModule("Contract/UI", "server")
local SkillTree = sharedModule("Config/SkillTree", "server")

section("K1. Contract/UI : UI_SkillTree à la fin de la liste, noms lus par le code")
local screen, hud = nil, nil
for _, s in UI.Screens do
	if s.Name == "UI_SkillTree" then
		screen = s
	elseif s.Name == "UI_HUD" then
		hud = s
	end
end
check(screen ~= nil and screen.Class == "ScreenGui" and not screen.Optional, "K1a UI_SkillTree au contrat (ScreenGui, pas facultatif)")
check(UI.Screens[#UI.Screens] == screen, "K1b à la fin de UI.Screens")
local paths = {}
for _, element in (screen and screen.Elements or {}) do
	paths[element.Path] = element
end
local missingTiles = {}
for _, skill in SkillTree.List do
	for _, part in { "", ".Bought", ".Available", ".Locked", ".Info.Level", ".Info.TileName", ".Info.PriceRow.Price", ".Info.PriceRow.PriceNeed" } do
		if paths[`Tree.{skill.Tile}{part}`] == nil then
			table.insert(missingTiles, `{skill.Tile}{part}`)
		end
	end
end
check(#missingTiles == 0, `K1c chaque tuile de Config/SkillTree (champ Tile) et ses calques au contrat ({table.concat(missingTiles, ", ")})`)
check(paths["Tree.RootTile"] and paths["Tree.RootTile"].Class == "GuiButton" and paths["Tree." .. SkillTree.NeverTile], "K1d RootTile et Tile_Next2 (boutons)")
for _, path in { "Tree.SelectionGlow", "CashPill.Cash", "InfoPanel.Header.NodeName", "InfoPanel.NodeIcon", "InfoPanel.NodeLevel", "InfoPanel.StatBox.NodeStat", "InfoPanel.StatBox.NodeEffect", "InfoPanel.PriceRow.NodePrice", "InfoPanel.BuyButton", "InfoPanel.NeedButton", "InfoPanel.NeedButton.NeedLabel", "CloseButton" } do
	check(paths[path] ~= nil, `K1e {path}`)
end
local hudPaths = {}
for _, element in hud.Elements do
	hudPaths[element.Path] = element
end
check(hudPaths.SkillTreeButton and hudPaths.SkillTreeButton.Class == "GuiButton" and hud.Elements[#hud.Elements].Path == "SkillTreeButton", "K1f UI_HUD.SkillTreeButton (bouton, à la fin de la liste du HUD)")
check(table.find(UI.Twins.UI_HUD.Names, "SkillTreeButton") ~= nil, "K1g SkillTreeButton dans UI.Twins (LeftRail et LeftRailTouch)")

section("K2. ContractChecker sur l'écran relevé dans Studio : aucune ligne rouge")
local Checker = requireModule(CHECKER_MODULE, "server")
local function run()
	clearLog()
	Checker.Start()
	flush()
end
local gui = buildSkillTree(StarterGui)
local hudGui = buildHud85(StarterGui)
-- Ancienne version laissée dans StarterGui (relevé) : pas au contrat, rien à dire.
make("ScreenGui", { Name = "UI_SkillTree_v2_old", Enabled = false }, StarterGui)
run()
check(not logHas("UI_SkillTree", "WARN", "server"), "K2a UI_SkillTree complet : aucune ligne rouge")
check(not logHas("SkillTreeButton", "WARN", "server"), "K2b SkillTreeButton dans LeftRail et LeftRailTouch : aucune ligne rouge")
check(not logHas("UI_SkillTree absent", nil, "server"), "K2c UI_SkillTree trouvé")
for _, name in RAIL_BUTTONS do
	check(not logHas(`UI_HUD.{name} : 2 éléments`, nil, "server"), `K2d {name} en double voulu : rien`)
end

section("K3. Un élément manquant est signalé")
gui.Tree.Tile_Glass.Info.PriceRow.PriceNeed:Destroy()
run()
check(logHas("UI_SkillTree.Tree.Tile_Glass.Info.PriceRow.PriceNeed introuvable", "WARN", "server"), "K3a PriceNeed de Tile_Glass retiré : ligne rouge")
make("TextButton", { Name = "SkillTreeButton", Text = "" }, hudGui.LeftRail)
run()
check(logHas("UI_HUD.SkillTreeButton : 3 éléments portent ce nom", "WARN", "server"), "K3b SkillTreeButton deux fois dans LeftRail : signalé")

section("K4. Écran absent : « pas encore livré », pas rouge")
gui:Destroy()
run()
check(logHas("UI_SkillTree absent", "PRINT", "server") and not logHas("UI_SkillTree", "WARN", "server"), "K4a UI_SkillTree absent : ligne « pas encore livré », pas d'alerte")

summary("scénario contract")
