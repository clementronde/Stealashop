--!nocheck
-- Scénario « v2 » (a56, 2026-11-10, L-083 points 5 et 6) : IndexController sur une copie de UI_Index_v2
-- (une liste, 7 sections avec leur Cards, plus d'onglets), l'ancien UI_Index présent à côté (éteint par
-- le code), ScrollTrack animé selon la liste, puis repli sur UI_Index quand la v2 disparaît et retour à
-- la v2 quand elle revient.

advance(1000)
startServer()
local Zones = sharedModule("Config/Zones")
local data = newProfile()
local found1 = { "Z1_CanetteDeSoda", "Z1_BoissonEnergisante", "Z1_BriqueDeLait", "Z1_PaquetDeChips", "Z1_Donut", "Z1_HotDog", "Z1_Banane", "Z1_Ananas", "Z1_Pasteque" }
for index, id in found1 do
	addItem(data, `c-{index}`, id, if index <= 4 then index else nil, 1, 500)
end
addItem(data, "c-z2", "Z2_YoYo", nil, 2, 500)
local ada = join("Ada", data)
local playerGui = ada:FindFirstChild("PlayerGui")
local legacy = buildIndexGui(playerGui)
legacy.Enabled = true -- l'ancien écran laissé allumé dans StarterGui : le code doit l'éteindre
local gui = buildIndexV2Gui(playerGui, { emptyName = 6 })
local hud = buildHud(playerGui)
advance(1.5)
startClient(ada)

local window = gui.Root.Window
local list = window.List
local track = window.ScrollTrack
local SILHOUETTE = Color3.fromRGB(17, 19, 24)

section("branchement")
check(logHas("[Loader Client] 1 module(s) démarré(s)", "PRINT", "client") and not logHas("[Loader Client]", "WARN"), "IndexController démarré sans erreur")
check(gui.Enabled == false and legacy.Enabled == false, "UI_Index_v2 fermé, ancien UI_Index éteint")
check(list.Template.Visible == false and v2AllCards(gui) == 0, "Template gardé caché, aucune carte avant l'ouverture")

section("ouverture par le bouton du HUD : toutes les sections")
click(hud.LeftRail.IndexButton)
check(gui.Enabled == true and legacy.Enabled == false, "IndexButton ouvre UI_Index_v2, pas l'ancien")
check(#cardsOf(legacy) == 0, "aucune carte dans l'ancien écran")
local expectedCounts = { 13, 16, 14, 15 }
for zone = 1, Index.ZoneCount do
	local cards = v2Cards(gui, `Zone{zone}Section`)
	local names, expected = {}, {}
	for index, card in cards do
		names[index] = string.match(card.Name, "^Item_%d+_(.+)$")
	end
	for index, item in Index.ByZone[zone] do
		expected[index] = item.Id
	end
	check(#cards == #Index.ByZone[zone] and table.concat(names, ",") == table.concat(expected, ","), `zone {zone} : {#cards} cartes dans Zone{zone}Section.Cards, ordre du catalogue`)
	if expectedCounts[zone] then
		check(#cards == expectedCounts[zone], `zone {zone} : {expectedCounts[zone]} objets ({#cards})`)
	end
end
local secrets = v2Cards(gui, "SecretsSection")
check(#secrets == #Index.Secrets and secrets[1].Name == "Item_01_Secret_ChatPorteBonheurDore", "SecretsSection : le Chat porte-bonheur doré")
check(v2AllCards(gui) == Index.Total, `{Index.Total} cartes en tout, toutes dans un Cards ({v2AllCards(gui)})`)
local soda = v2CardOf(gui, "Zone1Section", "Z1_CanetteDeSoda")
check(soda.Visible == true and soda.LayoutOrder == 1 and soda.Name == "Item_01_Z1_CanetteDeSoda", "carte nommée, LayoutOrder = rang, visible")
check(soda.Icon.Image == ICON_TEXTURE.Z1_CanetteDeSoda and sameColor(soda.Icon.ImageColor3, FOUND_SAMPLE), "découvert : icône en couleurs")
check(soda.Lock.Visible == false and textOf(soda, "ItemName") == "SODA CAN", "découvert : cadenas caché, « SODA CAN »")
local carrot = v2CardOf(gui, "Zone1Section", "Z1_Carotte")
check(sameColor(carrot.Icon.ImageColor3, SILHOUETTE) and carrot.Lock.Visible == true and textOf(carrot, "ItemName") == "???", "pas découvert : silhouette (teinte par défaut, pas de Preview_*), cadenas, « ??? »")
local noodles = v2CardOf(gui, "Zone1Section", "Z1_PotDeNouilles")
check(sameColor(noodles.Clip.Rays.ImageColor3, Rarities.ById.Rare.Color) and noodles.RarityBar.Rarity.Text == "RARE", "Pot de nouilles : rayons et texte Rare")
check(textOf(v2CardOf(gui, "Zone2Section", "Z2_YoYo"), "ItemName") == "YO-YO", "zone 2 : le Yo-yo découvert")
check(textOf(window.CounterPill, "Counter") == "10 / 83 discovered", `compteur : {textOf(window.CounterPill, "Counter")}`)

section("en-têtes des sections")
local z1 = list.Zone1Section
local fill1 = z1.SectionHeader.ZoneBar.Fill
check(textOf(z1, "ZoneName") == "MINI MART" and textOf(z1, "ZoneCount") == "9 / 13", "zone 1 : « MINI MART » de Clément gardé, « 9 / 13 »")
check(near(fill1.Size.X.Scale, 9 / 13) and fill1.Size.Y.Scale == 1 and fill1.Size.X.Offset == 0, `Fill zone 1 : 9/13 ({tostring(fill1.Size)})`)
check(textOf(z1, "RewardLabel") == (if Index.ZoneRewardText then Index.ZoneRewardText(1) else "+5% INCOME") and z1.SectionHeader.Reward.Visible == true, "zone 1 : « +5% INCOME »")
local z2 = list.Zone2Section
check(textOf(z2, "ZoneName") == "LONDON" and textOf(z2, "ZoneCount") == "1 / 16" and near(z2.SectionHeader.ZoneBar.Fill.Size.X.Scale, 1 / 16), "zone 2 : « LONDON », « 1 / 16 »")
local z3 = list.Zone3Section
check(textOf(z3, "ZoneCount") == "0 / 14" and near(z3.SectionHeader.ZoneBar.Fill.Size.X.Scale, 0), "zone 3 : « 0 / 14 », barre vide")
local z6 = list.Zone6Section
check(z6.SectionHeader.ZoneName.Text == string.upper(Zones[6].Theme), `ZoneName vide : le Theme de Config/Zones en capitales ({z6.SectionHeader.ZoneName.Text})`)
local sec = list.SecretsSection
check(textOf(sec, "ZoneName") == "SECRETS" and textOf(sec, "ZoneCount") == "0 / 1" and sec.SectionHeader.Reward.Visible == false, "Secrets : « 0 / 1 », Reward reste caché")

section("ScrollTrack : le curseur suit la liste")
check(list.CanvasPosition.Y == 0, "liste remise en haut à l'ouverture")
local function trackIs(share, progress, label)
	local size, pos = track.Size, track.Position
	local wantedH = 0.69 * share
	local wantedY = 0.1667 + 0.69 * (1 - share) * progress
	check(
		near(size.Y.Scale, wantedH, 1e-6) and near(pos.Y.Scale, wantedY, 1e-6) and size.X.Offset == 10 and size.X.Scale == 0
			and pos.X.Scale == 0.9816 and pos.X.Offset == 0 and size.Y.Offset == 0 and pos.Y.Offset == 0,
		`{label} (taille {tostring(size)}, place {tostring(pos)} ; attendu hauteur {wantedH}, haut {wantedY})`
	)
end
trackIs(0.2, 0, "en haut : 1/5 de la piste (400 visibles sur 2000), en haut de la piste")
list.CanvasPosition = Vector2.new(0, 800)
trackIs(0.2, 0.5, "à mi-course : au milieu")
list.CanvasPosition = Vector2.new(0, 1600)
trackIs(0.2, 1, "en bas : en bas de la piste")
list.CanvasPosition = Vector2.new(0, 5000)
trackIs(0.2, 1, "au-delà : reste en bas")
list.AbsoluteCanvasSize = Vector2.new(600, 100000)
trackIs(0.1, 5000 / 99600, "liste très longue : hauteur minimale (10 % de la piste)")
list.AbsoluteCanvasSize = Vector2.new(600, 1200)
list.CanvasPosition = Vector2.new(0, 400)
trackIs(1 / 3, 0.5, "canvas 1200 : tiers de la piste, au milieu")
list.AbsoluteWindowSize = Vector2.new(600, 600)
trackIs(0.5, 400 / 600, "fenêtre agrandie (600) : moitié de la piste")
list.AbsoluteCanvasSize = Vector2.new(600, 300)
trackIs(1, 0, "rien à défiler : le curseur remplit la piste")
list.AbsoluteCanvasSize = Vector2.new(600, 2000)
list.AbsoluteWindowSize = Vector2.new(600, 400)

section("découverte pendant que l'écran est ouvert")
for _, id in { "Z1_Carotte", "Z1_PotDeNouilles", "Z1_Brocoli", "Z1_EpiDeMais" } do
	IndexService.Discover(ada, id)
end
flush()
check(textOf(v2CardOf(gui, "Zone1Section", "Z1_Carotte"), "ItemName") == "CARROT", "la Carotte passe en découverte")
check(textOf(z1, "ZoneCount") == "13 / 13" and near(fill1.Size.X.Scale, 1) and textOf(z1, "RewardLabel") == (if Index.ZoneRewardText then Index.ZoneRewardText(1) .. " EARNED" else "+5% INCOME EARNED"), "zone 1 complète : « 13 / 13 », « +5% INCOME EARNED »")
check(textOf(z2, "RewardLabel") == (if Index.ZoneRewardText then Index.ZoneRewardText(2) else "+5% INCOME") and textOf(window.CounterPill, "Counter") == "14 / 83 discovered", "zone 2 inchangée, compteur à jour")
check(countKeys(SERVER_CALLS) == 0, "rien n'est envoyé au serveur")

section("fermeture et réouverture")
click(window.Header.CloseButton)
check(gui.Enabled == false and v2AllCards(gui) == 0, "CloseButton ferme l'écran (cartes retirées)")
list.CanvasPosition = Vector2.new(0, 900)
click(hud.LeftRail.IndexButton)
check(gui.Enabled == true and v2AllCards(gui) == Index.Total and list.CanvasPosition.Y == 0, "réouverture : toutes les cartes, liste en haut")
trackIs(0.2, 0, "curseur remonté en haut")
click(hud.LeftRail.IndexButton)
check(gui.Enabled == false and v2AllCards(gui) == 0, "un 2e appui referme")

section("repli : sans UI_Index_v2, l'ancien UI_Index (onglets)")
gui:Destroy()
flush()
click(hud.LeftRail.IndexButton)
check(legacy.Enabled == true and #cardsOf(legacy) == 13 and textOf(legacy.Root.Window.ZoneReward, "ZoneName") == "MINI MART", "l'ancien écran s'ouvre, zone 1 (13 cartes)")
click(legacy.Root.Tabs.Zone2Tab)
check(#cardsOf(legacy) == 16 and textOf(legacy.Root.Window.ZoneReward, "ZoneName") == "LONDON", "ses onglets marchent (London, 16)")
click(legacy.Root.Window.CloseButton)
check(legacy.Enabled == false and #cardsOf(legacy) == 0, "son CloseButton le ferme")

section("UI_Index_v2 revient (ResetOnSpawn) : rebranché, l'ancien éteint")
legacy.Enabled = true
local gui2 = buildIndexV2Gui(playerGui)
flush()
check(gui2.Enabled == false and legacy.Enabled == false, "nouvel écran v2 branché fermé, ancien éteint")
click(hud.LeftRail.IndexButton)
check(gui2.Enabled == true and v2AllCards(gui2) == Index.Total and legacy.Enabled == false and #cardsOf(legacy) == 0, "le bouton ouvre la v2")
gui2.Root.Window.List.CanvasPosition = Vector2.new(0, 1600)
check(near(gui2.Root.Window.ScrollTrack.Position.Y.Scale, 0.1667 + 0.69 * 0.8, 1e-6), "son ScrollTrack suit sa liste")
click(gui2.Root.Window.Header.CloseButton)
check(gui2.Enabled == false, "son CloseButton le ferme")
-- L'ancien écran recréé après la v2 (ordre de ResetOnSpawn) reste éteint et pas branché.
local legacy2 = buildIndexGui(nil)
legacy2.Enabled = true -- allumé dans StarterGui
legacy2.Parent = playerGui
flush()
check(legacy2.Enabled == false, "un UI_Index recréé après la v2 est éteint")
click(hud.LeftRail.IndexButton)
check(gui2.Enabled == true and legacy2.Enabled == false, "le bouton ouvre toujours la v2")

summary("scénario v2")
