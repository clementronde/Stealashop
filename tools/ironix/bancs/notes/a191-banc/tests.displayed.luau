--!nocheck
-- Scénario « displayed » (a191, L-182 point 6, L-183) : panneau UI_Displayed (DisplayedController) avec le vrai
-- serveur : liste des objets exposés, « Exposer les meilleurs » (EquipBest), RemoveButton (UnplaceItem).
advance(1000)
startServer()
local Format = sharedModule("Format")

local function pick(zone, rarity)
	for _, item in Items.List do
		if item.Zone == zone and item.Rarity == rarity and not item.TutorialOnly then
			return item.Id
		end
	end
	return nil
end
local C1, U1, R3, E3 = pick(1, "Common"), pick(2, "Uncommon"), pick(3, "Rare"), pick(3, "Epic")
check(C1 and U1 and R3 and E3, `objets de test trouvés ({C1}, {U1}, {R3}, {E3})`)
local function displayed(player)
	local out = {}
	for key, uid in dataOf(player).Display do
		out[uid] = tonumber(key)
	end
	return out
end

-- Écran de la maquette Figma (page « 20 Index et Exposés »), sans OpenButton (le HUD l'ouvre).
local function buildDisplayed(playerGui, withOpenButton)
	local gui = make("ScreenGui", { Name = "UI_Displayed", Enabled = true, ResetOnSpawn = false })
	if withOpenButton then
		local open = make("TextButton", { Name = "OpenButton", Text = "" }, gui)
		make("ImageLabel", { Name = "OpenIcon" }, open)
		make("TextLabel", { Name = "OpenLabel", Text = "DISPLAYS" }, open)
		local count = make("Frame", { Name = "OpenCount" }, open)
		make("TextLabel", { Name = "OpenCountLabel", Text = "0" }, count)
	end
	local panel = make("Frame", { Name = "Panel" }, gui)
	local header = make("Frame", { Name = "Header" }, panel)
	make("TextLabel", { Name = "Title", Text = "MY DISPLAYS" }, header)
	local close = make("TextButton", { Name = "CloseButton", Text = "X" }, panel)
	local count = make("Frame", { Name = "DisplayCount" }, panel)
	make("ImageLabel", { Name = "CountIcon" }, count)
	make("TextLabel", { Name = "CountLabel", Text = "0/0" }, count)
	local list = make("ScrollingFrame", { Name = "List" }, panel)
	make("UIListLayout", { Name = "UIListLayout" }, list)
	local row = make("Frame", { Name = "Template", Visible = false }, list)
	make("Frame", { Name = "IconBack" }, row)
	make("ImageLabel", { Name = "Icon", Image = "" }, row)
	local chip = make("Frame", { Name = "RarityChip" }, row)
	make("TextLabel", { Name = "RarityLabel", Text = "COMMON" }, chip)
	make("TextLabel", { Name = "ItemName", Text = "Item" }, row)
	make("TextLabel", { Name = "Income", Text = "$0/s" }, row)
	local remove = make("TextButton", { Name = "RemoveButton", Text = "" }, row)
	make("TextLabel", { Name = "RemoveLabel", Text = "REMOVE" }, remove)
	local best = make("TextButton", { Name = "DisplayBestButton", Text = "" }, panel)
	make("TextLabel", { Name = "DisplayBestLabel", Text = "DISPLAY BEST" }, best)
	gui.Parent = playerGui
	flush()
	return gui
end
local function rowsOf(gui)
	local out = {}
	for _, child in gui.Panel.List:GetChildren() do
		if string.sub(child.Name, 1, 4) == "Row_" then
			table.insert(out, child)
		end
	end
	table.sort(out, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	return out
end

local data = newProfile()
addItem(data, "c1", C1, 1, 1, 1) -- exposé, le moins bon
addItem(data, "u1", U1, 2, 2, 2) -- exposé
addItem(data, "r3", R3, nil, 3, 3) -- stock
addItem(data, "e3", E3, nil, 3, 4) -- stock
local ada = join("Ada", data)
advance(1.5)
local playerGui = ada:FindFirstChildOfClass("PlayerGui")
local gui = buildDisplayed(playerGui, false)
startClient(ada)
advance(0.6)
local Displayed = clientModule("DisplayedController")

section("branché, fermé")
check(not logHas("[Loader", "WARN"), "aucun module en échec au chargement")
check(gui.Enabled == false and not Displayed.IsOpen(), "sans OpenButton : écran éteint jusqu'au HUD")
check(gui.Panel.List.Template.Visible == false, "Template caché")

section("ouvert : les objets exposés, du meilleur au moins bon")
Displayed.Toggle()
flush()
check(gui.Enabled == true and Displayed.IsOpen(), "Toggle : écran allumé")
local rows = rowsOf(gui)
check(#rows == 2, `2 lignes (trouvé {#rows})`)
local uDef, cDef = Items.ById[U1], Items.ById[C1]
check(rows[1] and rows[1].Name == "Row_01_u1" and rows[2].Name == "Row_02_c1", "Peu commun d'abord, puis Commun")
check(rows[1] and rows[1].ItemName.Text == uDef.DisplayName and rows[1].Income.Text == Format.income(Formulas.ItemIncome(2, "Uncommon")), `nom et revenu (« {rows[1] and rows[1].Income.Text} »)`)
check(rows[1] and rows[1].RarityChip.RarityLabel.Text == Rarities.ById.Uncommon.DisplayNameUpper and sameColor(rows[1].RarityChip.BackgroundColor3, Rarities.ById.Uncommon.Color), "rareté écrite, puce à sa couleur")
check(rows[1] and sameColor(rows[1].IconBack.BackgroundColor3, Rarities.ById.Uncommon.Color) and rows[1]:GetAttribute("Rarity") == "Uncommon", "IconBack à la couleur de la rareté, attribut Rarity")
check(rows[1] and rows[1].Icon.Image == ICON_TEXTURE[U1] and rows[1].Visible == true, "icône ICON_<ItemId>")
check(gui.Panel.DisplayCount.CountLabel.Text == "2/4", `compte « {gui.Panel.DisplayCount.CountLabel.Text} »`)
check(gui.Panel.Header.Title.Text == "MY DISPLAYS", "titre de Clément gardé")

section("Exposer les meilleurs : le serveur remplit les présentoirs")
local calls = #serverCalls("EquipBest")
click(gui.Panel.DisplayBestButton)
check(#serverCalls("EquipBest") == calls + 1, "DisplayBestButton envoie EquipBest")
advance(0.8)
local shown = displayed(ada)
check(shown.e3 ~= nil and shown.r3 ~= nil and shown.u1 == 2 and shown.c1 == 1, "4 présentoirs : Épique et Rare posés, les exposés gardent leur place")
check(#notifies(ada, "Your best items are now on display!") == 1, "Notify du serveur")
rows = rowsOf(gui)
check(#rows == 4 and rows[1].Name == "Row_01_e3", `panneau à jour : 4 lignes, l'Épique en tête ({#rows})`)
check(gui.Panel.DisplayCount.CountLabel.Text == "4/4", "compte « 4/4 »")

section("appels répétés : un par seconde")
click(gui.Panel.DisplayBestButton)
click(gui.Panel.DisplayBestButton)
check(#serverCalls("EquipBest") == calls + 1, "deux clics dans la seconde : rien d'envoyé")
local before = #notifies(ada)
fireAs(ada, "EquipBest")
fireAs(ada, "EquipBest")
flush()
check(#notifies(ada) <= before + 1, "côté serveur aussi : Net en garde un par seconde")
advance(1.2)

section("présentoirs pleins, objet moins bon : rien ne bouge")
addItem(dataOf(ada), "c1b", C1, nil, 1, 5)
local same = #notifies(ada, "already on display")
click(gui.Panel.DisplayBestButton)
advance(0.8)
shown = displayed(ada)
check(shown.c1b == nil and shown.e3 ~= nil and shown.r3 ~= nil and shown.u1 == 2 and shown.c1 == 1, "le 2e Commun reste dans le stock")
check(#notifies(ada, "already on display") == same + 1, "Notify « already on display »")

section("un meilleur objet remplace le moins bon, qui retourne dans le stock")
addItem(dataOf(ada), "e3b", E3, nil, 3, 6)
advance(1.2)
click(gui.Panel.DisplayBestButton)
advance(0.8)
shown = displayed(ada)
check(shown.e3b == 1 and shown.c1 == nil and dataOf(ada).Items.c1 ~= nil, "l'Épique prend le présentoir 1 ; le Commun reste au joueur, hors présentoir")

section("RemoveButton : l'objet quitte son présentoir")
rows = rowsOf(gui)
local last = rows[#rows]
local uid = string.match(last.Name, "^Row_%d+_(.+)$")
click(last.RemoveButton)
check(#serverCalls("UnplaceItem") == 1 and serverCalls("UnplaceItem")[1].args[1] == uid, `UnplaceItem({uid}) envoyé`)
advance(0.8)
check(displayed(ada)[uid] == nil and dataOf(ada).Items[uid] ~= nil, "retiré du présentoir, gardé dans le stock")
check(#rowsOf(gui) == 3 and gui.Panel.DisplayCount.CountLabel.Text == "3/4", "panneau : 3 lignes, « 3/4 »")

section("rien possédé : rien")
local bob = join("Bob", newProfile())
advance(1.5)
fireAs(bob, "EquipBest")
flush()
check(next(dataOf(bob).Display) == nil and #notifies(bob, "already on display") == 1, "Bob sans objet : rien d'exposé, « already on display »")

section("fermé")
click(gui.Panel.CloseButton)
check(gui.Enabled == false and not Displayed.IsOpen() and #rowsOf(gui) == 0, "CloseButton : éteint, lignes retirées")

section("avec OpenButton : l'écran reste allumé, seul Panel se montre")
gui:Destroy()
local gui2 = buildDisplayed(playerGui, true)
advance(0.3)
check(gui2.Enabled == true and gui2.Panel.Visible == false, "branché : écran allumé, Panel caché")
check(gui2.OpenButton.OpenCount.OpenCountLabel.Text == "3", "OpenCountLabel = 3 objets exposés")
click(gui2.OpenButton)
check(gui2.Panel.Visible == true and #rowsOf(gui2) == 3, "OpenButton : Panel montré, 3 lignes")
click(gui2.OpenButton)
check(gui2.Panel.Visible == false and gui2.Enabled == true, "2e appui : Panel caché")

summary("scénario displayed")
