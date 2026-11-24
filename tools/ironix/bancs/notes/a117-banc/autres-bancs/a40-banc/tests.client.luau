--!nocheck
-- Scénario « client » : IndexController sur une copie de l'écran UI_Index de Clément (relevé de Studio du
-- 2026-11-08 : Template, 13 cartes d'exemple Preview_*, Clip avec Rays et Glow, Lock, RarityBar ;
-- ZoneReward ; 7 onglets avec TabLabel). Bouton du HUD, cartes d'exemple retirées, une carte par objet
-- de l'onglet dans l'ordre du catalogue, découvert / pas découvert (icône, teinte, cadenas, nom),
-- couleur de rareté sur Rays et Glow, compteur, récompense de zone, onglet Secrets, mise à jour pendant
-- que l'écran est ouvert, fermeture, dernier onglet, écran recréé (teintes lues sur ses exemples).

advance(1000)
startServer()
local data = newProfile()
-- Zone 1 : 9 objets sur 13 (ni le Brocoli, dont l'icône manque, ni le Pot de nouilles, ni la Carotte,
-- ni l'Épi de maïs) ; zone 2 : le Yo-yo.
local found1 = { "Z1_CanetteDeSoda", "Z1_BoissonEnergisante", "Z1_BriqueDeLait", "Z1_PaquetDeChips", "Z1_Donut", "Z1_HotDog", "Z1_Banane", "Z1_Ananas", "Z1_Pasteque" }
for index, id in found1 do
	addItem(data, `c-{index}`, id, if index <= 4 then index else nil, 1, 500)
end
addItem(data, "c-z2", "Z2_YoYo", nil, 2, 500)
local ada = join("Ada", data)
local playerGui = ada:FindFirstChild("PlayerGui")
local gui = buildIndexGui(playerGui)
local hud = buildHud(playerGui)
advance(1.5)
startClient(ada)

section("branchement")
check(logHas("[Loader Client] 1 module(s) démarré(s)", "PRINT", "client") and not logHas("[Loader Client]", "WARN"), "IndexController démarré sans erreur")
local list = gui.Root.Window.List
check(list:FindFirstChild("Preview_1") == nil and list:FindFirstChild("Preview_13") == nil, "cartes d'exemple Preview_* retirées")
check(list:FindFirstChild("Template") ~= nil and list.Template.Visible == false, "Template gardé, invisible")
check(gui.Enabled == false and #cardsOf(gui) == 0, "écran fermé, aucune carte avant l'ouverture")

section("ouverture par le bouton du HUD : zone 1")
click(hud.LeftRail.IndexButton)
check(gui.Enabled == true, "IndexButton ouvre l'écran")
local cards = cardsOf(gui)
local names, expected = {}, {}
for index, card in cards do
	names[index] = string.match(card.Name, "^Item_%d+_(.+)$")
end
for index, item in Index.ByZone[1] do
	expected[index] = item.Id
end
check(#cards == 13 and table.concat(names, ",") == table.concat(expected, ","), `13 cartes, dans l'ordre du catalogue ({#cards})`)
check(cards[1].Name == "Item_01_Z1_CanetteDeSoda" and cards[1].LayoutOrder == 1 and cards[13].LayoutOrder == 13 and cards[1].Visible == true, "cartes nommées Item_<nn>_<ItemId>, LayoutOrder = rang, visibles")
local soda = cardOf(gui, "Z1_CanetteDeSoda")
check(soda.Icon.Image == ICON_TEXTURE.Z1_CanetteDeSoda, "découvert : l'icône ICON_Z1_CanetteDeSoda")
check(sameColor(soda.Icon.ImageColor3, FOUND_SAMPLE), "découvert : icône en couleurs (blanc, comme Preview_1)")
check(soda.Lock.Visible == false and textOf(soda, "ItemName") == "SODA CAN", "découvert : cadenas caché, nom en capitales « SODA CAN »")
local carrot = cardOf(gui, "Z1_Carotte")
check(carrot.Icon.Image == ICON_TEXTURE.Z1_Carotte and sameColor(carrot.Icon.ImageColor3, SILHOUETTE_SAMPLE), "pas découvert : silhouette de son icône (teinte de Preview_3)")
check(carrot.Lock.Visible == true and textOf(carrot, "ItemName") == "???", "pas découvert : cadenas visible, « ??? »")
local broccoli = cardOf(gui, "Z1_Brocoli")
check(broccoli.Icon.Image == "" and textOf(broccoli, "ItemName") == "???", "icône pas livrée : image vide (pas celle du Template)")
check(logHas("[Index] icône ICON_Z1_Brocoli pas livrée : carte sans image", "PRINT", "client"), "une ligne dans la sortie (Studio)")
local common = Rarities.ById.Common.Color
check(sameColor(soda.Clip.Rays.ImageColor3, common) and sameColor(soda.Clip.Glow.ImageColor3, common), "Rays et Glow à la couleur des Communs")
check(sameColor(carrot.Clip.Rays.ImageColor3, common), "pas découvert : la couleur de sa rareté aussi (doc 3.4)")
local noodles = cardOf(gui, "Z1_PotDeNouilles")
check(sameColor(noodles.Clip.Rays.ImageColor3, Rarities.ById.Rare.Color) and sameColor(noodles.Clip.Glow.ImageColor3, Rarities.ById.Rare.Color), "Pot de nouilles : rayons bleus (Rare)")
check(sameColor(soda.RarityBar.BackgroundColor3, BAR_SAMPLE) and sameColor(noodles.RarityBar.BackgroundColor3, BAR_SAMPLE), "RarityBar pas touchée")
check(soda.RarityBar.Rarity.Text == "COMMON" and noodles.RarityBar.Rarity.Text == "RARE" and carrot.RarityBar.Rarity.Text == "COMMON", `nom de la rareté dans RarityBar.Rarity : {noodles.RarityBar.Rarity.Text} (vu en Play le 2026-11-08 : toujours COMMON)`)
check(textOf(gui.Root.Window.CounterPill, "Counter") == "10 / 83 discovered", `compteur : {textOf(gui.Root.Window.CounterPill, "Counter")}`)
local zoneReward = gui.Root.Window.ZoneReward
local fill = zoneReward.ZoneBar.Fill
check(textOf(zoneReward, "ZoneName") == "MINI MART" and textOf(zoneReward, "ZoneCount") == "9 / 13", "ZoneReward : « MINI MART », « 9 / 13 »")
check(near(fill.Size.X.Scale, 9 / 13) and fill.Size.X.Offset == 0 and fill.Size.Y.Scale == 1 and fill.Size.Y.Offset == -4, `Fill : largeur 9/13, hauteur de Clément gardée ({tostring(fill.Size)})`)
check(textOf(zoneReward, "RewardLabel") == (if Index.ZoneRewardText then Index.ZoneRewardText(1) else "+5% INCOME") and zoneReward.Reward.Visible == true, "récompense « +5% INCOME »")
check(list.CanvasPosition.Y == 0, "liste remise en haut à l'ouverture")

section("onglets")
click(gui.Root.Tabs.Zone2Tab)
cards = cardsOf(gui)
check(#cards == 16 and cards[1].Name == "Item_01_Z2_CanardEnPlastique", `London : les 16 objets de la zone 2 ({#cards})`)
check(textOf(zoneReward, "ZoneName") == "LONDON" and textOf(zoneReward, "ZoneCount") == "1 / 16" and near(fill.Size.X.Scale, 1 / 16), "ZoneReward : « LONDON », « 1 / 16 »")
check(textOf(cardOf(gui, "Z2_YoYo"), "ItemName") == "YO-YO" and cardOf(gui, "Z2_YoYo").Lock.Visible == false, "le Yo-yo découvert : « YO-YO »")
check(sameColor(cardOf(gui, "Z2_PelucheGeante").Clip.Glow.ImageColor3, Rarities.ById.Legendary.Color), "Peluche géante : rayons dorés (Légendaire)")
check(sameColor(cardOf(gui, "Z2_FigurineHolographique").Clip.Rays.ImageColor3, Rarities.ById.Mythic.Color), "Figurine holographique : rayons rouges (Mythique)")
list.CanvasPosition = Vector2.new(0, 400)
click(gui.Root.Tabs.Zone4Tab)
check(textOf(zoneReward, "ZoneName") == "L.A." and #cardsOf(gui) == 15 and list.CanvasPosition.Y == 0, "L.A. : 15 objets, liste remise en haut")
click(gui.Root.Tabs.SecretsTab)
cards = cardsOf(gui)
check(#cards == 1 and cards[1].Name == "Item_01_Secret_ChatPorteBonheurDore" and textOf(cards[1], "ItemName") == "???", "Secrets : le Chat porte-bonheur doré, pas découvert")
check(textOf(zoneReward, "ZoneName") == "SECRETS" and textOf(zoneReward, "ZoneCount") == "0 / 1" and near(fill.Size.X.Scale, 0), "ZoneReward : « SECRETS », « 0 / 1 », barre vide")
check(zoneReward.Reward.Visible == false, "Secrets : récompense cachée (l'aura « Collectionneur » n'existe pas encore)")
check(sameColor(cards[1].Clip.Rays.ImageColor3, Rarities.ById.Secret.Color), "Secret : sa couleur fixe")
check(textOf(gui.Root.Window.CounterPill, "Counter") == "10 / 83 discovered", "compteur global inchangé d'un onglet à l'autre")
click(gui.Root.Tabs.Zone1Tab)
check(zoneReward.Reward.Visible == true and #cardsOf(gui) == 13 and textOf(zoneReward, "ZoneName") == "MINI MART", "retour en zone 1 : récompense de nouveau visible")

section("découverte pendant que l'écran est ouvert")
IndexService.Discover(ada, "Z1_Carotte")
flush()
carrot = cardOf(gui, "Z1_Carotte")
check(textOf(carrot, "ItemName") == "CARROT" and carrot.Lock.Visible == false and sameColor(carrot.Icon.ImageColor3, FOUND_SAMPLE), "la carte de la Carotte passe en découverte")
check(textOf(gui.Root.Window.CounterPill, "Counter") == "11 / 83 discovered" and textOf(zoneReward, "ZoneCount") == "10 / 13", "compteur et zone à jour")
for _, id in { "Z1_PotDeNouilles", "Z1_Brocoli", "Z1_EpiDeMais" } do
	IndexService.Discover(ada, id)
end
flush()
check(textOf(zoneReward, "ZoneCount") == "13 / 13" and near(fill.Size.X.Scale, 1), "zone 1 complète : « 13 / 13 », barre pleine")
check(textOf(zoneReward, "RewardLabel") == (if Index.ZoneRewardText then Index.ZoneRewardText(1) .. " EARNED" else "+5% INCOME EARNED"), "récompense obtenue : « +5% INCOME EARNED »")
check(textOf(cardOf(gui, "Z1_Brocoli"), "ItemName") == "BROCCOLI" and cardOf(gui, "Z1_Brocoli").Icon.Image == "", "Brocoli découvert, toujours sans icône")
check(#serverCalls("Notify") == 0 and countKeys(SERVER_CALLS) == 0, "rien n'est envoyé au serveur")

section("fermeture et réouverture")
click(gui.Root.Window.CloseButton)
check(gui.Enabled == false and #cardsOf(gui) == 0, "CloseButton ferme l'écran (cartes retirées)")
click(gui.Root.Tabs.Zone3Tab) -- onglet choisi écran fermé
check(gui.Enabled == false and #cardsOf(gui) == 0, "un onglet ne rouvre pas l'écran")
click(hud.LeftRail.IndexButton)
check(gui.Enabled == true and #cardsOf(gui) == 14 and textOf(zoneReward, "ZoneName") == "TOKYO", "réouverture sur le dernier onglet choisi (Tokyo, 14 objets)")
click(hud.LeftRail.IndexButton)
check(gui.Enabled == false and #cardsOf(gui) == 0, "un 2e appui sur IndexButton referme l'écran")

section("écran recréé (ResetOnSpawn) : rebranché, teintes lues sur ses cartes d'exemple")
gui:Destroy()
flush()
local custom = Color3.new(0.2, 0.1, 0.3)
local gui2 = buildIndexGui(playerGui, custom)
flush()
check(gui2.Root.Window.List:FindFirstChild("Preview_3") == nil and gui2.Enabled == false, "nouvel écran branché : cartes d'exemple retirées, fermé")
click(hud.LeftRail.IndexButton)
check(gui2.Enabled == true and #cardsOf(gui2) == 14, "le bouton ouvre le nouvel écran, sur Tokyo")
check(sameColor(cardOf(gui2, "Z3_Smartphone").Icon.ImageColor3, custom), "silhouette : la teinte de la carte d'exemple pas découverte de ce nouvel écran")
click(gui2.Root.Window.CloseButton)
check(gui2.Enabled == false and #cardsOf(gui2) == 0, "CloseButton du nouvel écran branché")

summary("scénario client")
