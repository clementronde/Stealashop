--!nocheck
-- Banc a314, partie « vente » : SellButton de chaque ligne d'UI_Displayed, confirmation Confirm (YES / NO), remotes
-- DisplayedSellAsk / DisplayedSellPrice / DisplayedSell / DisplayedSold (PawnShopService : prix et vente du receleur).
advance(1000)
startServer()
local PawnShopService = serverModule("PawnShopService")
local Format = sharedModule("Format")
local Displayed_cfg = sharedModule("Config/Displayed")

local function pick(zone, rarity)
	for _, item in Items.List do
		if item.Zone == zone and item.Rarity == rarity and not item.TutorialOnly then
			return item.Id
		end
	end
	return nil
end
local C1, U1, R3, E3 = pick(1, "Common"), pick(2, "Uncommon"), pick(3, "Rare"), pick(4, "Epic")
check(C1 and U1 and R3 and E3, `objets de test trouvés ({C1}, {U1}, {R3}, {E3})`)

local bobData = newProfile()
addItem(bobData, "b1", E3, 1, 4, 1)
addItem(bobData, "b2", R3, nil, 3, 2)
local bob = join("Bob", bobData)

local data = newProfile()
addItem(data, "c1", C1, 1, 1, 1) -- exposé
addItem(data, "u1", U1, 2, 2, 2) -- exposé
addItem(data, "h1", R3, 3, 3, 3) -- exposé, sera tenu par un voleur
addItem(data, "r3", R3, nil, 3, 4) -- réserve
addItem(data, "e3", E3, nil, 4, 5) -- réserve
addItem(data, "at", U1, nil, 2, 6) -- sous antivol, pas encore posé au sol
data.Items.at.AntiTheft = true
data.Items.at.UnlockAt = 1e12
addItem(data, "x1", C1, nil, 1, 7) -- objet inconnu du catalogue
data.Items.x1.Id = "Z9_NoSuchItem"
local ada = join("Ada", data)
advance(1.5)
local playerGui = ada:FindFirstChildOfClass("PlayerGui")
local gui = buildGui(playerGui)
startClient(ada)
advance(0.6)
local Displayed = clientModule("DisplayedController")
local confirm = gui.Dock.Confirm
local list = gui.Dock.Panel.List

local function cash(player)
	return dataOf(player).Cash
end
local function exposedSlot(player, uid)
	for key, stored in dataOf(player).Display do
		if stored == uid then
			return key
		end
	end
	return nil
end
local function lastSold()
	local list = remotes("DisplayedSold", function(e) return e.to == ada end)
	return list[#list]
end
local function lastPrice()
	local list = remotes("DisplayedSellPrice", function(e) return e.to == ada end)
	return list[#list]
end

section("boutons : SellButton sur chaque ligne, Confirm caché")
check(not logHas("[Loader", "WARN"), "aucun module en échec au chargement")
check(confirm.Visible == false, "Confirm caché à l'arrivée")
Displayed.Toggle()
flush()
local rows = rowsIn(list, nil)
local exposedRows, reserveRows = rowsIn(list, "Row_"), rowsIn(list, "Reserve_")
check(#exposedRows >= 2 and #reserveRows >= 3, `lignes exposées et réserve ({#exposedRows}, {#reserveRows})`)
local allSell = #rows > 0
for _, r in rows do
	if r.Buttons.SellButton.Visible ~= true then
		allSell = false
	end
end
check(allSell, "SellButton montré sur chaque ligne (exposés et réserve)")
check(rowOf(list, "at") ~= nil and rowOf(list, "at").Buttons.SellButton.Visible == true, "objet sous antivol : SellButton montré aussi")
check(rowOf(list, "u1").Buttons.RemoveButton.Visible == true and rowOf(list, "r3").Buttons.DisplayButton.Visible == true, "RemoveButton et DisplayButton trouvés dans Buttons")
check(list.Template.Buttons.SellButton.Visible == false, "SellButton du gabarit pas touché")

section("objet exposé : prix du receleur, YES vend")
local priceU1 = PawnShopService.PriceOf(ada, "u1")
check(type(priceU1) == "number" and priceU1 > 0, `prix du receleur de u1 ({priceU1})`)
local cash0 = cash(ada)
local asks = #serverCalls("DisplayedSellAsk")
click(rowOf(list, "u1").Buttons.SellButton)
check(#serverCalls("DisplayedSellAsk") == asks + 1 and serverCalls("DisplayedSellAsk")[asks + 1].args[1] == "u1", "DisplayedSellAsk(u1) envoyé")
check(confirm.Visible == true, "Confirm montré")
local itemU1 = Items.ById[U1]
local rarU1 = Rarities.ById[itemU1.Rarity]
check(confirm.ItemName.Text == itemU1.DisplayName, `ItemName « {confirm.ItemName.Text} »`)
check(confirm.ItemRarity.Text == rarU1.DisplayNameUpper, `ItemRarity « {confirm.ItemRarity.Text} »`)
local rowU1Info = rowOf(list, "u1").Info
check(sameColor(confirm.ItemName.TextColor3, rowU1Info.ItemName.TextColor3) and sameColor(confirm.ItemRarity.TextColor3, rowU1Info.RarityChip.RarityLabel.TextColor3), `nom et rareté à la couleur de la ligne ({confirm.ItemName.TextColor3} / {rowU1Info.ItemName.TextColor3})`)
check(confirm.ItemSlot.ItemIcon.Image == ICON_TEXTURE[U1], "ItemIcon = icône de l'objet")
local shown = confirm.SellPrice.Text
check(shown == string.format(Displayed_cfg.Sell.PriceText, Format.money(priceU1)), `SellPrice « {shown} » = prix du receleur ({Format.money(priceU1)})`)
check(lastPrice() and lastPrice().args[1] == "u1" and lastPrice().args[2] == priceU1 and lastPrice().args[3] == true, "DisplayedSellPrice(u1, prix, true)")
check(dataOf(ada).Items.u1 ~= nil and cash(ada) == cash0, "rien de vendu avant YES")
local sells = #serverCalls("DisplayedSell")
click(confirm.YesButton)
check(#serverCalls("DisplayedSell") == sells + 1, "DisplayedSell envoyé")
check(dataOf(ada).Items.u1 == nil, "u1 retiré des objets")
check(exposedSlot(ada, "u1") == nil, "u1 retiré de son présentoir")
check(cash(ada) == cash0 + priceU1, `argent versé = prix affiché ({cash(ada) - cash0} / {priceU1})`)
check(lastSold() and lastSold().args[1] == "u1" and lastSold().args[2] == priceU1 and lastSold().args[3] == true, "DisplayedSold(u1, prix, true)")
check(confirm.Visible == false, "Confirm caché à la réponse")
local rowU1 = rowOf(list, "u1")
check(rowU1 == nil or rowU1.Visible == false, "la ligne de u1 a disparu")
check(#notifies(ada, "sold for") == 1, "Notify « … sold for … »")
advance(1.2)
check(rowOf(list, "u1") == nil, "plus de ligne pour u1 après la mise à jour")
check(#DisplayService.GetExposed(ada) >= 0 and (function()
	for _, e in DisplayService.GetExposed(ada) do
		if e.Uid == "u1" then return false end
	end
	return true
end)(), "u1 n'est plus exposé (DisplayService)")

section("objet de la réserve")
local priceR3 = PawnShopService.PriceOf(ada, "r3")
cash0 = cash(ada)
click(rowOf(list, "r3").Buttons.SellButton)
check(confirm.Visible == true and confirm.SellPrice.Text == string.format(Displayed_cfg.Sell.PriceText, Format.money(priceR3)), `prix affiché de r3 « {confirm.SellPrice.Text} »`)
click(confirm.YesButton)
check(dataOf(ada).Items.r3 == nil and cash(ada) == cash0 + priceR3, "r3 vendu au prix du receleur")
advance(1.2)
check(table.find(DisplayService.GetReserve(ada), "r3") == nil, "r3 sorti de la réserve")
check(rowOf(list, "r3") == nil, "plus de ligne pour r3")

section("NO, CloseButton, fermeture : rien ne change")
cash0 = cash(ada)
sells = #serverCalls("DisplayedSell")
click(rowOf(list, "e3").Buttons.SellButton)
check(confirm.Visible == true, "Confirm montré pour e3")
click(confirm.NoButton)
check(confirm.Visible == false and dataOf(ada).Items.e3 ~= nil and #serverCalls("DisplayedSell") == sells, "NO : Confirm caché, rien de vendu")
click(rowOf(list, "e3").Buttons.SellButton)
click(gui.Dock.Panel.Header.CloseButton)
check(confirm.Visible == false and gui.Enabled == false, "CloseButton : écran fermé, Confirm caché")
Displayed.ConfirmSell()
check(#serverCalls("DisplayedSell") == sells, "YES après la fermeture : rien n'est envoyé")
Displayed.Open()
flush()
click(rowOf(list, "e3").Buttons.SellButton)
Displayed.Close()
check(confirm.Visible == false, "fermeture de l'écran : Confirm caché")
Displayed.Open()
flush()
check(confirm.Visible == false, "réouverture : Confirm toujours caché")
check(dataOf(ada).Items.e3 ~= nil and cash(ada) == cash0 and #serverCalls("DisplayedSell") == sells, "e3 toujours là, argent inchangé")

section("double demande : une seule vente")
local priceC1 = PawnShopService.PriceOf(ada, "c1")
cash0 = cash(ada)
click(rowOf(list, "c1").Buttons.SellButton)
local yes = confirm.YesButton
Displayed.ConfirmSell()
Displayed.ConfirmSell()
check(#serverCalls("DisplayedSell") == sells + 1, "deux YES côté client : une seule demande")
check(cash(ada) == cash0 + priceC1 and dataOf(ada).Items.c1 == nil, "c1 vendu une fois")
local warnings = #notifies(ada, "can't be sold")
fireAs(ada, "DisplayedSell", "c1")
check(cash(ada) == cash0 + priceC1, "seconde demande au serveur : pas d'argent en plus")
check(lastSold().args[1] == "c1" and lastSold().args[3] == false, "seconde demande : DisplayedSold(c1, 0, false)")
check(#notifies(ada, "can't be sold") == warnings, "seconde demande : aucun message")
local priceE3 = PawnShopService.PriceOf(ada, "e3")
cash0 = cash(ada)
fireAs(ada, "DisplayedSell", "e3")
fireAs(ada, "DisplayedSell", "e3")
check(cash(ada) == cash0 + priceE3, `deux demandes serveur pour e3 : vendu une fois ({cash(ada) - cash0} / {priceE3})`)

section("objet d'un autre joueur, objet inconnu : refusés")
advance(1.1) -- débit de Net (4 demandes par seconde et par remote)
cash0 = cash(ada)
local bobCash = cash(bob)
fireAs(ada, "DisplayedSellAsk", "b2")
check(lastPrice().args[1] == "b2" and lastPrice().args[3] == false, "prix refusé pour l'objet de Bob")
fireAs(ada, "DisplayedSell", "b1")
fireAs(ada, "DisplayedSell", "b2")
check(dataOf(bob).Items.b1 ~= nil and dataOf(bob).Items.b2 ~= nil and exposedSlot(bob, "b1") ~= nil, "objets de Bob intacts (b1 toujours exposé)")
check(cash(ada) == cash0 and cash(bob) == bobCash, "aucun argent versé")
check(lastSold().args[3] == false, "DisplayedSold refusé")
advance(1.1)
fireAs(ada, "DisplayedSell", "nope")
check(cash(ada) == cash0 and lastSold().args[1] == "nope" and lastSold().args[3] == false, "uid inconnu refusé")
fireAs(ada, "DisplayedSell", "x1")
check(dataOf(ada).Items.x1 ~= nil and cash(ada) == cash0 and lastSold().args[3] == false, "objet inconnu du catalogue refusé, gardé dans le profil")
check(PawnShopService.SellPrice(ada, "x1") == nil, "SellPrice(x1) = nil")

section("objet sous antivol pas encore posé : règle du receleur")
advance(1.1)
local offer = PawnShopService.GetOffer(ada)
local atAtPawn = table.find(offer.AllUids, "at") ~= nil
local priceAt = PawnShopService.PriceOf(ada, "at")
cash0 = cash(ada)
click(rowOf(list, "at").Buttons.SellButton)
check(confirm.Visible == atAtPawn, "Confirm montré si et seulement si le receleur le prend")
check(not atAtPawn or confirm.SellPrice.Text == string.format(Displayed_cfg.Sell.PriceText, Format.money(priceAt)), `prix affiché de l'objet sous antivol « {confirm.SellPrice.Text} »`)
click(confirm.YesButton)
if atAtPawn then
	check(dataOf(ada).Items.at == nil and cash(ada) == cash0 + priceAt, "le receleur le prend : vendu au même prix depuis l'écran")
else
	check(dataOf(ada).Items.at ~= nil and cash(ada) == cash0, "le receleur le refuse : refusé ici aussi")
end
check(atAtPawn, "règle actuelle du receleur : un objet sous antivol pas encore posé se vend")

section("objet tenu par un voleur : refusé")
advance(1.1)
local slotH = DisplayService.Hold(ada, "h1")
check(slotH ~= nil, `h1 tenu par un voleur (présentoir {slotH})`)
cash0 = cash(ada)
fireAs(ada, "DisplayedSell", "h1")
check(dataOf(ada).Items.h1 ~= nil and cash(ada) == cash0, "h1 pas vendu")
check(#notifies(ada, "being stolen") == 1, "Notify « being stolen »")
DisplayService.Release(ada, "h1")
local priceH = PawnShopService.PriceOf(ada, "h1")
fireAs(ada, "DisplayedSell", "h1")
check(dataOf(ada).Items.h1 == nil and cash(ada) == cash0 + priceH and exposedSlot(ada, "h1") == nil, "rendu à son présentoir, il se vend")

section("contrat UI : noms facultatifs, UI_Displayed une seule fois")
local UI = sharedModule("Contract/UI")
local screens = 0
local byPath = {}
for _, s in UI.Screens do
	if s.Name == "UI_Displayed" then
		screens += 1
		for _, e in s.Elements do
			byPath[e.Path] = e
		end
	end
end
check(screens == 1, `UI_Displayed défini une fois ({screens})`)
local wanted = { "List.Template.SellButton", "List.Template.SellButton.SellLabel", "Confirm", "Confirm.Header.Title", "Confirm.ItemIcon", "Confirm.ItemRarity", "Confirm.ItemName", "Confirm.SellPrice", "Confirm.YesButton", "Confirm.YesButton.YesLabel", "Confirm.NoButton", "Confirm.NoButton.NoLabel" }
local okContract = true
for _, path in wanted do
	if byPath[path] == nil or byPath[path].Optional ~= true then
		okContract = false
		print("    manque ou pas facultatif : " .. path)
	end
end
check(okContract, "les 12 noms de L-292 au contrat, facultatifs")
check(not logHas("Confirm introuvable", ""), "aucune ligne « Confirm introuvable »")

summary("scénario a314 vente")
