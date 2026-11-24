--!nocheck
-- Scénario « open » d'a216 (vague 65) : la boutique Robux v2 (Config du dépôt : vitrine) ouverte plusieurs fois.
-- Mesures par ouverture : cartes copiées depuis un Template, instances de ReplicatedStorage/Assets parcourues
-- (Assets garni de FILLER pièces, comme un vrai Assets plein de modèles), temps du clic (os.clock, faux Roblox).
-- Contrôles (après a216) : 2e ouverture sans carte neuve ni passe sur Assets ; contenu juste après un achat (Pass…),
-- une attente d'Ouvrir maintenant, un onglet, le début et la fin du pack de départ ; cascade (Appear) à chaque
-- ouverture ; icônes des Decal toujours posées.

local FILLER = 20000
local HUD = buildHud(PLAYER_GUI)
local V2 = buildRobuxShopV2(PLAYER_GUI)
P1:SetAttribute("Income", 100)

-- Assets : des pièces de décor, et l'icône d'un pack d'argent en Decal (passe avant l'image de la maquette).
local filler = folder(ASSETS, "Models")
for index = 1, FILLER do
	make("Part", { Name = `Part_{index}` }, filler)
end
CASH1_DECAL = "rbxassetid://216001"
make("Decal", { Name = "UI_Icon_DP_Cash_1", Texture = CASH1_DECAL }, folder(ASSETS, "Icons216"))

-- Cascade : la vraie Appear, posée par Clément sur la Grid des packs d'argent.
local UIFOLDER = CONTROLLERS:FindFirstChild("UI")
local appearModule = moduleScript(UIFOLDER, "Appear", "client/Controllers/UI/Appear.luau")
v2El(V2, "CashSection.Grid"):SetAttribute("Appear", "Cascade")

-- Compteurs : copies d'un Template (une carte) et instances d'Assets parcourues.
local COUNT = { clones = 0, assets = 0 }
local baseClone = Methods.Clone
Methods.Clone = function(self)
	if rawget(self, "_props").Name == "Template" then
		COUNT.clones += 1
	end
	return baseClone(self)
end
local baseDescendants = Methods.GetDescendants
Methods.GetDescendants = function(self)
	local out = baseDescendants(self)
	if self == ASSETS then
		COUNT.assets += #out
	end
	return out
end

startClient()
local Appear = requireModule(appearModule, "client")
local UiMotion = sharedModule("Config/UiMotion")
local SCALE_NAME = UiMotion.Appear.ScaleName
local FROM = UiMotion.Appear.Cascade.From
-- Comme UiMotionController : l'écran qui s'allume lance ses apparitions.
V2:GetPropertyChangedSignal("Enabled"):Connect(function()
	if V2.Enabled then
		Appear.Open(V2)
	end
end)

local function cashCards()
	local out = {}
	for _, child in v2El(V2, "CashSection.Grid"):GetChildren() do
		if string.sub(child.Name, 1, 6) == "Offer_" then
			table.insert(out, child)
		end
	end
	return out
end
-- Cartes de la Grid en attente d'entrer (UIScale de la cascade à From), juste après l'ouverture.
local function cascading()
	local n = 0
	for _, card in cashCards() do
		local scale = card:FindFirstChild(SCALE_NAME)
		if scale and scale:IsA("UIScale") and near(scale.Scale, FROM) then
			n += 1
		end
	end
	return n
end
local opening = 0
local function open()
	opening += 1
	COUNT.clones, COUNT.assets = 0, 0
	local t0 = os.clock()
	click(hudButton(HUD, "RobuxShopButton"))
	local spent = os.clock() - t0
	local seen = { clones = COUNT.clones, assets = COUNT.assets, ms = spent * 1000, cascade = cascading() }
	print(string.format("  MESURE ouverture %d : %d carte(s) copiée(s), %d instance(s) d'Assets parcourue(s), %.1f ms (faux Roblox), cascade sur %d carte(s)",
		opening, seen.clones, seen.assets, seen.ms, seen.cascade))
	advance(1)
	return seen
end
local function close()
	click(v2El(V2, "CloseButton"))
	advance(1)
end

if not A216_AFTER and MESURE ~= true then
	-- Avant a216 : mesures seules (deux ouvertures), pour le temps avant / après.
	open()
	close()
	open()
	summary("scénario open (mesure avant a216)")
	return
end

section("1re ouverture : cartes construites une fois")
local first = open()
check(V2.Enabled, "la v2 s'ouvre")
check(first.clones == 14, `14 cartes copiées (5 gamepasses, 3 boosts, 6 packs) : {first.clones}`)
check(first.assets <= FILLER + 10, `Assets parcouru une seule fois ({first.assets} instances)`)
check(first.cascade == 6, `cascade : les 6 packs attendent leur entrée ({first.cascade})`)
check(v2Keys(V2, "CashSection") == "Cash10,Cash30,Cash60,Cash180,Cash300,Cash720", "packs d'argent dans l'ordre")
check(v2Card(V2, "Cash10"):FindFirstChild("Icon").Image == CASH1_DECAL, "icône du Decal de Clément posée")
check(v2Card(V2, "Cash30"):FindFirstChild("Icon").Image == "rbxassetid://1", "sans Decal : l'image de la maquette")
local keptCash10 = v2Card(V2, "Cash10")

section("fermeture puis 2e ouverture : aucune carte neuve")
close()
check(V2.Enabled == false, "CloseButton ferme la v2")
check(#cashCards() == 6, "cartes gardées écran fermé")
local second = open()
check(second.clones == 0, `2e ouverture : aucune carte copiée ({second.clones})`)
check(second.assets == 0, `2e ouverture : Assets pas parcouru ({second.assets})`)
check(second.cascade == 6, `cascade jouée de nouveau ({second.cascade})`)
check(v2Card(V2, "Cash10") == keptCash10, "les mêmes cartes")
check(v2Keys(V2, "CashSection") == "Cash10,Cash30,Cash60,Cash180,Cash300,Cash720", "même contenu")
check(v2El(V2, "List").CanvasPosition.Y == 0, "la liste s'ouvre en haut")

section("achat : gamepass reçu")
P1:SetAttribute("PassDoubleCash", true)
flush()
local doubleCash = v2Card(V2, "DoubleCash")
check(doubleCash:FindFirstChild("Owned").Visible == true and doubleCash:FindFirstChild("BuyButton").Visible == false, "écran ouvert : Owned visible, BuyButton caché")
close()
P1:SetAttribute("PassAutoCollect", true)
flush()
local third = open()
local autoCollect = v2Card(V2, "AutoCollect")
check(autoCollect:FindFirstChild("Owned").Visible == true and autoCollect:FindFirstChild("BuyButton").Visible == false, "reçu écran fermé : Owned à la réouverture")
check(third.clones == 0, `sans nouvelle carte ({third.clones})`)

section("prix : Ouvrir maintenant")
local openNow = v2Card(V2, "OpenNow")
check(openNow:FindFirstChild("BuyButton").Visible == false, "sans objet qui attend : BuyButton caché")
close()
P1:SetAttribute("OpenNowReadyAt", serverTime() + 3600)
flush()
open()
local remaining = P1:GetAttribute("OpenNowReadyAt") - serverTime()
local tier = Monetization.OpenNowTier(remaining)
check(openNow:FindFirstChild("BuyButton").Visible == true, "objet qui attend : BuyButton visible à la réouverture")
check(tier ~= nil and textOf(openNow, "Price") == tostring(math.floor(tier.Price)), `prix du palier ({textOf(openNow, "Price")})`)

section("onglet")
local y = clickTab(V2, "CashTab")
check(y == V2_OFFSETS.CashSection, `CashTab : défile jusqu'aux packs ({y})`)
close()
local fourth = open()
check(fourth.clones == 0 and v2Card(V2, "Cash10") == keptCash10, "onglet changé puis réouverture : mêmes cartes")
check(v2El(V2, "List").CanvasPosition.Y == 0, "la liste se rouvre en haut")

section("pack de départ")
local contentRatio = v2El(V2, "List.Content"):FindFirstChildOfClass("UIAspectRatioConstraint")
local heightWithout = 1 / contentRatio.AspectRatio
close()
P1:SetAttribute("StarterPackEndsAt", serverTime() + 30)
flush()
local fifth = open()
check(v2El(V2, "Featured").Visible == true, "proposé écran fermé : Featured visible à la réouverture")
check(1 / contentRatio.AspectRatio > heightWithout, "List.Content plus haut")
check(fifth.cascade == 6, `offres changées : cartes refaites, cascade jouée ({fifth.cascade})`)
close()
advance(40)
local sixth = open()
check(v2El(V2, "Featured").Visible == false, "fini écran fermé : Featured caché à la réouverture")
check(near(1 / contentRatio.AspectRatio, heightWithout), "List.Content reprend sa hauteur")
check(v2Keys(V2, "CashSection") == "Cash10,Cash30,Cash60,Cash180,Cash300,Cash720", "packs toujours là")
check(sixth.cascade == 6, `cascade jouée ({sixth.cascade})`)
close()
local seventh = open()
check(seventh.clones == 0, `puis de nouveau aucune carte neuve ({seventh.clones})`)

section("sortie")
check(not logHas("[Loader", "WARN", "client"), "aucun contrôleur en échec au chargement")
check(not logHas("[RobuxShop]", "WARN", "client"), "aucun avertissement de RobuxShop")
summary("scénario open")
