--!nocheck
-- Scénario « displayed » (copie a206 de celui d'a191, vague 63, L-202 point 4, L-192 Q2-Q4) : panneau UI_Displayed
-- (DisplayedController) avec le vrai serveur. Changements d'a206 : plus d'OpenButton (UI_HUD.RightRail.DisplayedButton
-- allume tout l'écran) ; ItemName et RarityChip.RarityLabel à la couleur de la rareté (RarityFx), fond de la puce
-- laissé à Clément ; un objet remplacé par « Exposer les meilleurs » va dans la réserve (Panel.Reserve) ; un objet
-- retiré à la main va dans la main, sinon dans la réserve (ce harnais n'a pas HeldItemService : la réserve).
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

-- Écran de Clément (Figma « 20 Index et Exposés », L-202) ; `withReserve` : Panel.Reserve (ReserveCount, ReserveList).
local CHIP_BACK = Color3.new(0.2, 0.2, 0.25)
local function buildDisplayed(playerGui, withReserve)
	local gui = make("ScreenGui", { Name = "UI_Displayed", Enabled = true, ResetOnSpawn = false })
	local panel = make("Frame", { Name = "Panel" }, gui)
	local header = make("Frame", { Name = "Header" }, panel)
	make("TextLabel", { Name = "Title", Text = "MY DISPLAYS" }, header)
	local close = make("TextButton", { Name = "CloseButton", Text = "X" }, panel)
	local count = make("Frame", { Name = "DisplayCount" }, panel)
	make("ImageLabel", { Name = "CountIcon" }, count)
	make("TextLabel", { Name = "CountLabel", Text = "0/0" }, count)
	local list = make("ScrollingFrame", { Name = "List" }, panel)
	make("UIListLayout", { Name = "UIListLayout" }, list)
	local row = make("Frame", { Name = "Template", Visible = false, Size = UDim2.new(1, 0, 0, 84) }, list)
	make("Frame", { Name = "IconBack" }, row)
	make("ImageLabel", { Name = "Icon", Image = "" }, row)
	local chip = make("Frame", { Name = "RarityChip", BackgroundColor3 = CHIP_BACK }, row)
	make("TextLabel", { Name = "RarityLabel", Text = "COMMON" }, chip)
	make("TextLabel", { Name = "ItemName", Text = "Item" }, row)
	make("TextLabel", { Name = "Income", Text = "$0/s" }, row)
	local remove = make("TextButton", { Name = "RemoveButton", Text = "" }, row)
	make("TextLabel", { Name = "RemoveLabel", Text = "REMOVE" }, remove)
	local best = make("TextButton", { Name = "DisplayBestButton", Text = "" }, panel)
	make("TextLabel", { Name = "DisplayBestLabel", Text = "DISPLAY BEST" }, best)
	if withReserve then
		local reserve = make("Frame", { Name = "Reserve" }, panel)
		local rc = make("Frame", { Name = "ReserveCount" }, reserve)
		make("TextLabel", { Name = "ReserveCountLabel", Text = "0" }, rc)
		local rlist = make("ScrollingFrame", { Name = "ReserveList" }, reserve)
		make("UIListLayout", { Name = "UIListLayout" }, rlist)
		local rrow = make("Frame", { Name = "Template", Visible = false, Size = UDim2.new(1, 0, 0, 64) }, rlist)
		make("Frame", { Name = "IconBack" }, rrow)
		make("ImageLabel", { Name = "Icon", Image = "" }, rrow)
		make("TextLabel", { Name = "ItemName", Text = "Item" }, rrow)
		make("TextLabel", { Name = "Income", Text = "$0/s" }, rrow)
		local db = make("TextButton", { Name = "DisplayButton", Text = "" }, rrow)
		make("TextLabel", { Name = "DisplayLabel", Text = "DISPLAY" }, db)
	end
	gui.Parent = playerGui
	flush()
	return gui
end
local function rowsIn(list, prefix)
	local out = {}
	for _, child in list:GetChildren() do
		if string.sub(child.Name, 1, #prefix) == prefix then
			table.insert(out, child)
		end
	end
	table.sort(out, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	return out
end
local function rowsOf(gui)
	return rowsIn(gui.Panel.List, "Row_")
end
local function reserveRows(gui)
	return rowsIn(gui.Panel.Reserve.ReserveList, "Reserve_")
end
-- Texte à la couleur de la rareté : couleur unie, ou blanc + UIGradient de RarityFx.
local function rarityText(label, rarityId)
	local gradient = label:FindFirstChildWhichIsA("UIGradient")
	if gradient then
		return true
	end
	return sameColor(label.TextColor3, Rarities.ById[rarityId].Color)
end
local function reserveOf(player)
	return table.concat(dataOf(player).Reserve or {}, ",")
end

local data = newProfile()
addItem(data, "c1", C1, 1, 1, 1) -- exposé, le moins bon
addItem(data, "u1", U1, 2, 2, 2) -- exposé
addItem(data, "r3", R3, nil, 3, 3) -- hors présentoir
addItem(data, "e3", E3, nil, 3, 4) -- hors présentoir
data.Items.c1.Mutation = { Size = "Big" }
check(data.Reserve == nil, "profil d'avant la vague 63 : pas de champ Reserve")
local ada = join("Ada", data)
advance(1.5)
local function itemText(item)
	local m = item.Mutation or {}
	return `{item.Id}|{item.Zone}|{item.At}|{m.Size}|{m.Effect}|{item.Weight}`
end
local c1Text = itemText(dataOf(ada).Items.c1)
local playerGui = ada:FindFirstChildOfClass("PlayerGui")
local gui = buildDisplayed(playerGui, true)
startClient(ada)
advance(0.6)
local Displayed = clientModule("DisplayedController")

section("branché, fermé ; profil migré")
check(not logHas("[Loader", "WARN"), "aucun module en échec au chargement")
check(gui.Enabled == false and not Displayed.IsOpen(), "écran éteint jusqu'au HUD")
check(gui.Panel.List.Template.Visible == false and gui.Panel.Reserve.ReserveList.Template.Visible == false, "les deux Template cachés")
check(reserveOf(ada) == "e3,r3", `migration : les objets hors présentoir en réserve, meilleur d'abord (« {reserveOf(ada)} »)`)
check(ada:GetAttribute("DisplayReserve") == "e3,r3", `attribut DisplayReserve (« {ada:GetAttribute("DisplayReserve")} »)`)

section("ouvert : exposés du meilleur au moins bon, puis la réserve")
Displayed.Toggle()
flush()
check(gui.Enabled == true and Displayed.IsOpen(), "Toggle : écran allumé")
local rows = rowsOf(gui)
check(#rows == 2, `2 lignes (trouvé {#rows})`)
local uDef = Items.ById[U1]
check(rows[1] and rows[1].Name == "Row_01_u1" and rows[2].Name == "Row_02_c1", "Peu commun d'abord, puis Commun")
check(rows[1] and rows[1].ItemName.Text == uDef.DisplayName and rows[1].Income.Text == Format.income(Formulas.ItemIncome(2, "Uncommon")), `nom et revenu (« {rows[1] and rows[1].Income.Text} »)`)
check(rows[1] and rows[1].RarityChip.RarityLabel.Text == Rarities.ById.Uncommon.DisplayNameUpper, "rareté écrite")
check(rows[1] and rarityText(rows[1].ItemName, "Uncommon") and rarityText(rows[1].RarityChip.RarityLabel, "Uncommon"), "ItemName et RarityLabel à la couleur de la rareté")
check(rows[1] and sameColor(rows[1].RarityChip.BackgroundColor3, CHIP_BACK), "fond de RarityChip laissé à Clément")
check(rows[1] and sameColor(rows[1].IconBack.BackgroundColor3, Rarities.ById.Uncommon.Color) and rows[1]:GetAttribute("Rarity") == "Uncommon", "IconBack à la couleur de la rareté, attribut Rarity")
check(rows[1] and rows[1].Icon.Image == ICON_TEXTURE[U1] and rows[1].Visible == true, "icône ICON_<ItemId>")
check(rows[1] and rows[1].Size == gui.Panel.List.Template.Size, "taille du Template gardée")
check(gui.Panel.DisplayCount.CountLabel.Text == "2/4", `compte « {gui.Panel.DisplayCount.CountLabel.Text} »`)
check(gui.Panel.Header.Title.Text == "MY DISPLAYS", "titre de Clément gardé")
local res = reserveRows(gui)
check(gui.Panel.Reserve.Visible == true and gui.Panel.Reserve.ReserveCount.ReserveCountLabel.Text == "2", `réserve montrée, « 2 » ({gui.Panel.Reserve.ReserveCount.ReserveCountLabel.Text})`)
check(#res == 2 and res[1].Name == "Reserve_01_e3" and res[2].Name == "Reserve_02_r3", `réserve : l'Épique puis le Rare ({#res})`)
check(res[1] and res[1].ItemName.Text == Items.ById[E3].DisplayName and rarityText(res[1].ItemName, "Epic") and res[1].Icon.Image == ICON_TEXTURE[E3], "ligne de réserve : nom coloré, icône")
check(res[1] and res[1].Income.Text == Format.income(Formulas.ItemIncome(3, "Epic")) and res[1].Size == gui.Panel.Reserve.ReserveList.Template.Size, "revenu, taille du Template")

section("Exposer les meilleurs : le serveur remplit les présentoirs, la réserve se vide")
local calls = #serverCalls("EquipBest")
click(gui.Panel.DisplayBestButton)
check(#serverCalls("EquipBest") == calls + 1, "DisplayBestButton envoie EquipBest")
advance(0.8)
local shown = displayed(ada)
check(shown.e3 ~= nil and shown.r3 ~= nil and shown.u1 == 2 and shown.c1 == 1, "4 présentoirs : Épique et Rare posés, les exposés gardent leur place")
check(#notifies(ada, "Your best items are now on display!") == 1, "Notify du serveur")
check(reserveOf(ada) == "" and ada:GetAttribute("DisplayReserve") == "", `réserve vide (« {reserveOf(ada)} »)`)
rows = rowsOf(gui)
check(#rows == 4 and rows[1].Name == "Row_01_e3", `panneau à jour : 4 lignes, l'Épique en tête ({#rows})`)
check(gui.Panel.DisplayCount.CountLabel.Text == "4/4", "compte « 4/4 »")
check(gui.Panel.Reserve.Visible == false and #reserveRows(gui) == 0, "réserve vide : cachée")

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
advance(1.2)
shown = displayed(ada)
check(shown.c1b == nil and shown.e3 ~= nil and shown.r3 ~= nil and shown.u1 == 2 and shown.c1 == 1, "le 2e Commun reste hors présentoir")
check(#notifies(ada, "already on display") == same + 1, "Notify « already on display »")
check(reserveOf(ada) == "", "rien de remplacé : réserve toujours vide")

section("un meilleur objet remplace le moins bon, qui va dans la réserve")
addItem(dataOf(ada), "e3b", E3, nil, 3, 6)
advance(1.2)
click(gui.Panel.DisplayBestButton)
advance(1.2)
shown = displayed(ada)
check(shown.e3b == 1 and shown.c1 == nil and dataOf(ada).Items.c1 ~= nil, "l'Épique prend le présentoir 1 ; le Commun reste au joueur")
check(reserveOf(ada) == "c1", `le Commun remplacé est dans la réserve (« {reserveOf(ada)} »)`)
check(itemText(dataOf(ada).Items.c1) == c1Text, `mutation et poids gardés ({c1Text})`)
res = reserveRows(gui)
check(gui.Panel.Reserve.Visible == true and #res == 1 and res[1].Name == "Reserve_01_c1", `panneau : la réserve montre le Commun ({#res})`)
check(gui.Panel.Reserve.ReserveCount.ReserveCountLabel.Text == "1", "ReserveCountLabel « 1 »")

section("DisplayButton sans présentoir libre : « No free display », rien ne bouge")
local free = #notifies(ada, "No free display")
click(res[1].DisplayButton)
check(#serverCalls("PlaceFromReserve") == 1 and serverCalls("PlaceFromReserve")[1].args[1] == "c1", "PlaceFromReserve(c1) envoyé")
advance(1.2)
check(#notifies(ada, "No free display") == free + 1, "Notify « No free display »")
check(displayed(ada).c1 == nil and reserveOf(ada) == "c1", "le Commun reste dans la réserve")

section("RemoveButton : l'objet quitte son présentoir ; mains absentes ici : dans la réserve")
rows = rowsOf(gui)
local last = rows[#rows]
local uid = string.match(last.Name, "^Row_%d+_(.+)$")
click(last.RemoveButton)
check(#serverCalls("UnplaceItem") == 1 and serverCalls("UnplaceItem")[1].args[1] == uid, `UnplaceItem({uid}) envoyé`)
advance(1.2)
check(displayed(ada)[uid] == nil and dataOf(ada).Items[uid] ~= nil, "retiré du présentoir, gardé au joueur")
check(string.find(reserveOf(ada), uid, 1, true) ~= nil, `{uid} dans la réserve (« {reserveOf(ada)} »)`)
check(#notifies(ada, "moved to your reserve") == 1, "Notify « moved to your reserve »")
check(#rowsOf(gui) == 3 and gui.Panel.DisplayCount.CountLabel.Text == "3/4", "panneau : 3 lignes, « 3/4 »")
check(#reserveRows(gui) == 2 and gui.Panel.Reserve.ReserveCount.ReserveCountLabel.Text == "2", "réserve : 2 lignes")

section("DisplayButton avec un présentoir libre : l'objet repart sur un présentoir")
res = reserveRows(gui)
local back
for _, r in res do
	if r.Name == "Reserve_02_c1" or r.Name == "Reserve_01_c1" then
		back = r
	end
end
advance(0.5)
click(back.DisplayButton)
advance(1.2)
check(displayed(ada).c1 ~= nil and string.find(reserveOf(ada), "c1", 1, true) == nil, `c1 exposé, sorti de la réserve (« {reserveOf(ada)} »)`)
check(#notifies(ada, "placed on a display!") >= 1, "Notify « placed on a display! »")
check(itemText(dataOf(ada).Items.c1) == c1Text, "mutation et poids gardés")
check(#rowsOf(gui) == 4 and #reserveRows(gui) == 1, "panneau : 4 exposés, 1 en réserve")

section("fermé")
click(gui.Panel.CloseButton)
check(gui.Enabled == false and not Displayed.IsOpen() and #rowsOf(gui) == 0 and #reserveRows(gui) == 0, "CloseButton : éteint, lignes retirées")

section("écran sans Reserve (celui d'avant) : sans erreur")
gui:Destroy()
local gui2 = buildDisplayed(playerGui, false)
advance(0.3)
check(gui2.Enabled == false, "branché : éteint")
Displayed.Toggle()
flush()
check(gui2.Enabled == true and #rowsOf(gui2) == 4, "ouvert : 4 lignes")
check(not logHas("Displayed", "ERR") and not logHas("attempt to", ""), "aucune erreur")
Displayed.Close()

section("rien possédé : rien")
local bob = join("Bob", newProfile())
advance(1.5)
fireAs(bob, "EquipBest")
flush()
check(next(dataOf(bob).Display) == nil and #notifies(bob, "already on display") == 1, "Bob sans objet : rien d'exposé, « already on display »")
check(dataOf(bob).Reserve ~= nil and #dataOf(bob).Reserve == 0, "Bob migré : réserve vide")

summary("scénario displayed")
