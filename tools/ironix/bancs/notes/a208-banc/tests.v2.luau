--!nocheck
-- Scénario « v2 » : la Config du dépôt (vitrine : RobuxShop = false, RobuxShopPreview = true, RobuxCrate =
-- false). UI_RobuxShop_v2 et l'ancien UI_RobuxShop sont dans PlayerGui : la v2 passe avant. Sections remplies
-- depuis leur Template (Preview_* retirées), 6 packs d'argent triés, boosts du HUD dans l'onglet Boosts,
-- couleurs des cartes, hauteur des grilles, Featured et son minuteur, défilement par onglet, caisse cachée.

local HUD = buildHud(PLAYER_GUI)
local OLD = buildRobuxShopGui(PLAYER_GUI)
local V2 = buildRobuxShopV2(PLAYER_GUI)
P1:SetAttribute("Income", 100)
addGlow()
startClient()
local Boosts = sharedModule("Config/Boosts")

section("Config : packs, boosts, caisse")
check(Features.RobuxCrate == false, "Features.RobuxCrate = false (caisse cachée)")
local cashKeys, lastOrder, sorted = {}, 0, true
for _, product in Monetization.Products do
	if product.Tab == "Cash" then
		table.insert(cashKeys, product.Key)
		sorted = sorted and product.Order > lastOrder
		lastOrder = product.Order
	end
end
check(#cashKeys == 6 and sorted, `6 packs d'argent, du plus petit au plus gros ({table.concat(cashKeys, ",")})`)
local iconsOk, minutesUp, pricesUp = true, true, true
local previous = nil
for index, key in cashKeys do
	local product
	for _, p in Monetization.Products do
		if p.Key == key then
			product = p
		end
	end
	iconsOk = iconsOk and product.Icon == `UI_Icon_DP_Cash_{index}` and product.CardColor ~= nil
	if previous then
		minutesUp = minutesUp and product.Minutes > previous.Minutes
		pricesUp = pricesUp and product.Price > previous.Price
	end
	previous = product
end
check(iconsOk, "icônes UI_Icon_DP_Cash_1 à _6 dans l'ordre, une CardColor chacun")
check(minutesUp and pricesUp, "minutes et prix croissants")
local sameProduct = #Monetization.ShopBoosts == 2
for _, shopBoost in Monetization.ShopBoosts do
	local hud
	for _, b in Boosts.List do
		if b.Key == shopBoost.Key then
			hud = b
		end
	end
	sameProduct = sameProduct and hud ~= nil and shopBoost.Boost == hud and shopBoost.Boost.Id == hud.Id and shopBoost.Boost.Price == hud.Price
end
check(sameProduct, "×2 Speed et zZz : la même entrée de Config/Boosts que les boutons du HUD (Id, prix)")
check(Monetization.ShopBoosts[1].Key == "SpeedBoost" and Monetization.ShopBoosts[1].Boost.Price == 29 and Monetization.ShopBoosts[1].Icon == "UI_Icon_SpeedBoost", "×2 Speed : 29 R$, UI_Icon_SpeedBoost")
check(Monetization.ShopBoosts[2].Key == "SleepGuards" and Monetization.ShopBoosts[2].Boost.Price == 79 and Monetization.ShopBoosts[2].Icon == "UI_Icon_Sleep", "zZz : 79 R$, UI_Icon_Sleep")
local crate = Monetization.Crate
check(crate.UnitPrice == 99 and crate.Packs[1].Price == 99 and crate.Packs[2].Price == 249 and crate.Packs[3].Price == 799
	and crate.Packs[1].Count == 1 and crate.Packs[2].Count == 3 and crate.Packs[3].Count == 10, "caisse : 99 / 249 / 799 R$ pour 1 / 3 / 10")

section("la v2 passe avant l'ancien écran")
check(OLD.Enabled == false and V2.Enabled == false, "les deux écrans fermés au départ")
check(previewsLeft(V2) == 0, `cartes Preview_* retirées des Grid ({previewsLeft(V2)} restantes)`)
check(POLICY.calls == 0, "caisse coupée : PolicyService jamais appelé")
click(hudButton(HUD, "RobuxShopButton"))
advance(0.5)
check(V2.Enabled == true and OLD.Enabled == false, "bouton Shop du HUD : UI_RobuxShop_v2 ouvert, l'ancien reste fermé")
check(#cardsOf(OLD) == 0, "aucune carte clonée dans l'ancien écran")

section("sections remplies depuis leur Template")
local passKeys = {}
for _, pass in Monetization.Passes do
	if pass.Ready then
		table.insert(passKeys, pass.Key)
	end
end
check(v2Keys(V2, "GamepassesSection") == table.concat(passKeys, ","), `gamepasses : {v2Keys(V2, "GamepassesSection")}`)
check(v2Card(V2, "VIP") == nil, "VIP caché (Ready = false)")
check(v2Keys(V2, "CashSection") == "Cash10,Cash30,Cash60,Cash180,Cash300,Cash720", `argent : {v2Keys(V2, "CashSection")}`)
check(v2Keys(V2, "BoostsSection") == "SpeedBoost,SleepGuards,OpenNow", `boosts : {v2Keys(V2, "BoostsSection")}`)
check(v2El(V2, "GamepassesSection.Grid.Template").Visible == false, "Template reste caché")
local speed = v2Card(V2, "SpeedBoost")
check(textOf(speed, "ItemName") == "×2 Speed" and textOf(speed, "Price") == "29", `×2 Speed : nom et prix ({textOf(speed, "ItemName")}, {textOf(speed, "Price")})`)
check(textOf(v2Card(V2, "SleepGuards"), "Price") == "79", "zZz : 79")
check(textOf(v2Card(V2, "Cash720"), "Price") == "1599" and textOf(v2Card(V2, "Cash720"), "ItemName") == "12 Hours of Cash", "pack 12 h : nom et prix")
check(textOf(v2Card(V2, "Cash10"), "Effect") == "SAMPLE EFFECT" and textOf(speed, "Effect") == "SAMPLE EFFECT", "Effect jamais écrit dans la v2")

section("couleurs des cartes (CardColor)")
local doubleCash = v2Card(V2, "DoubleCash")
local wanted = Color3.fromHex("45D63A")
local gradient = doubleCash:FindFirstChild("UIGradient")
check(gradient.Color.Keypoints[1].Value == wanted, `×2 Cash : dégradé repeint ({tostring(gradient.Color.Keypoints[1].Value)})`)
check(gradient.Color.Keypoints[2].Value == wanted:Lerp(Color3.new(1, 1, 1), 0.4), `ton clair gardé ({tostring(gradient.Color.Keypoints[2].Value)})`)
check(doubleCash:FindFirstChild("Studs").ImageColor3 == wanted and doubleCash:GetAttribute("CardColor") == wanted, "Studs et attribut CardColor à la couleur de l'offre")
check(v2Card(V2, "SpeedBoost"):FindFirstChild("Studs").ImageColor3 == Color3.fromHex("F2553A"), "×2 Speed : F2553A")
local template = v2El(V2, "GamepassesSection.Grid.Template")
check(template:FindFirstChild("UIGradient").Color.Keypoints[1].Value == TEMPLATE_COLOR and template:GetAttribute("CardColor") == TEMPLATE_COLOR, "Template de Clément pas touché")

section("hauteur des grilles")
local cashSection = v2El(V2, "CashSection")
local ratio = cashSection:FindFirstChildOfClass("UIAspectRatioConstraint")
-- maquette : section 0,5, grille 0,3 (une rangée de 0,3, écart 0,03) ; 6 cartes en 3 colonnes = 2 rangées.
check(near(1 / ratio.AspectRatio, 0.83), `CashSection : 2 rangées, hauteur 0,83 largeur ({1 / ratio.AspectRatio})`)
local grid = v2El(V2, "CashSection.Grid")
local layout = grid:FindFirstChildOfClass("UIGridLayout")
check(near(layout.CellSize.Y.Scale * grid.Size.Y.Scale / ratio.AspectRatio, 0.3), "hauteur d'une carte gardée")
check(near(v2El(V2, "CashSection.Header").Size.Y.Scale / ratio.AspectRatio, 0.15), "en-tête : même hauteur qu'avant")
check(near(1 / v2El(V2, "BoostsSection"):FindFirstChildOfClass("UIAspectRatioConstraint").AspectRatio, 0.5), "BoostsSection : 3 cartes, une rangée, hauteur inchangée")

section("Featured : pack de départ et minuteur")
check(v2El(V2, "Featured").Visible == false and v2El(V2, "Crate").Visible == false, "sans pack de départ : Featured et Crate cachés")
local contentRatio = v2El(V2, "List.Content"):FindFirstChildOfClass("UIAspectRatioConstraint")
local heightWithout = 1 / contentRatio.AspectRatio
check(clickTab(V2, "OffersTab") == V2_OFFSETS.GamepassesSection, "onglet Offers sans pack ni caisse : les gamepasses")
P1:SetAttribute("StarterPackEndsAt", serverTime() + 3599.5)
flush()
check(v2El(V2, "Featured").Visible == true, "pack de départ en cours : Featured visible")
check(textOf(v2El(V2, "Featured"), "Label") == "Ends in 60:00", `minuteur : {textOf(v2El(V2, "Featured"), "Label")}`)
check(textOf(v2El(V2, "Featured"), "Perk1") == "×2 Cash 1h" and textOf(v2El(V2, "Featured"), "Perk2") == "Hammer" and textOf(v2El(V2, "Featured"), "Perk3") == Format.money(50000),
	`avantages : {textOf(v2El(V2, "Featured"), "Perk1")} / {textOf(v2El(V2, "Featured"), "Perk2")} / {textOf(v2El(V2, "Featured"), "Perk3")}`)
check(textOf(v2El(V2, "Featured.BuyButton"), "Price") == "99", "prix du pack de départ : 99")
check(v2Card(V2, "StarterPack") == nil, "pas de carte StarterPack clonée ailleurs")
check(1 / contentRatio.AspectRatio > heightWithout, "List.Content plus haut avec Featured")
advance(60)
check(textOf(v2El(V2, "Featured"), "Label") == "Ends in 59:00", `minuteur une minute après : {textOf(v2El(V2, "Featured"), "Label")}`)

section("défilement par onglet")
check(clickTab(V2, "CashTab") == V2_OFFSETS.CashSection, `CashTab : List jusqu'à CashSection ({v2El(V2, "List").CanvasPosition.Y})`)
check(clickTab(V2, "BoostsTab") == V2_OFFSETS.BoostsSection, `BoostsTab : BoostsSection ({v2El(V2, "List").CanvasPosition.Y})`)
check(clickTab(V2, "GamepassesTab") == V2_OFFSETS.GamepassesSection, `GamepassesTab : GamepassesSection ({v2El(V2, "List").CanvasPosition.Y})`)
check(clickTab(V2, "OffersTab") == V2_OFFSETS.Featured, `OffersTab sans caisse : Featured ({v2El(V2, "List").CanvasPosition.Y})`)
check(v2Keys(V2, "CashSection") == "Cash10,Cash30,Cash60,Cash180,Cash300,Cash720", "les onglets ne refont pas les cartes")

section("vitrine : « Soon », aucun achat")
click(v2Card(V2, "SpeedBoost"):FindFirstChild("BuyButton"))
check(textOf(v2Card(V2, "SpeedBoost"), "Price") == "Soon", "×2 Speed : « Soon »")
click(v2El(V2, "Featured.BuyButton"))
check(textOf(v2El(V2, "Featured.BuyButton"), "Price") == "Soon", "pack de départ : « Soon »")
check(#MARKET.prompts == 0 and #MARKET.infoCalls == 0 and GLOW.calls == 0, "aucune fenêtre d'achat, aucun prix demandé, pas de lueur")
advance(2.5)
check(textOf(v2Card(V2, "SpeedBoost"), "Price") == "29", "le prix revient")

section("fin du pack de départ")
P1:SetAttribute("StarterPackEndsAt", serverTime() + 3)
flush()
check(v2El(V2, "Featured").Visible == true, "encore 3 s : visible")
advance(4)
check(v2El(V2, "Featured").Visible == false, "minuteur fini : Featured caché")
check(near(1 / contentRatio.AspectRatio, heightWithout), "List.Content reprend sa hauteur")
check(clickTab(V2, "OffersTab") == V2_OFFSETS.GamepassesSection, "OffersTab : de nouveau les gamepasses")

section("fermeture, réouverture, ancien écran ajouté plus tard")
click(v2El(V2, "CloseButton"))
advance(1)
check(V2.Enabled == false, "CloseButton ferme la v2")
check(v2Keys(V2, "CashSection") == "", "cartes clonées retirées à la fermeture")
local late = buildRobuxShopGui(PLAYER_GUI)
flush()
check(late.Enabled == false, "un UI_RobuxShop ajouté après la v2 reste éteint")
click(hudButton(HUD, "RobuxShopButton"))
advance(0.5)
check(V2.Enabled == true and late.Enabled == false and #cardsOf(late) == 0, "réouverture : la v2 seule")
check(v2El(V2, "List").CanvasPosition.Y == 0, "la liste s'ouvre en haut")
check(v2Keys(V2, "CashSection") == "Cash10,Cash30,Cash60,Cash180,Cash300,Cash720", "cartes refaites")

section("sortie")
check(not logHas("[Loader", "WARN", "client"), "aucun contrôleur en échec au chargement")
check(not logHas("[RobuxShop]", "WARN", "client"), "aucun avertissement de RobuxShop")
check(not logHas("introuvable", nil, "client"), "aucun élément de la v2 introuvable")
summary("scénario v2")
