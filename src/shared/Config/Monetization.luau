--!strict
-- Boutique Robux (DEV-100, MAJ 1 ; Partie 2, sections 3.1 et 4) : gamepasses, produits développeur,
-- prix en Robux et paramètres de leurs effets. Lu par MonetizationService (serveur) et
-- RobuxShopController (client, écran UI_RobuxShop). Tout reste coupé tant que Features.RobuxShop est
-- false.
--
-- Id : identifiant Roblox de l'offre, créé sur le Creator Hub AU NOM DU GROUPE du studio (le jeu et
-- ses produits appartiennent au groupe, liaison L-001). 0 = pas encore créé : offre désactivée, sans
-- erreur (le bouton d'achat ne fait rien, aucun reçu n'est attendu, la carte montre le prix de la
-- Config). Une fois un Id écrit ici, ne jamais supprimer ni recréer le produit sur le Creator Hub
-- (liaison 3.5, règle 9).
-- Ready : l'effet est codé. false = ni affichée ni vendue, même avec un Id : VIP, Gants hydrauliques,
-- Vengeance, Rideau instantané, Chance ×3 et Bouclier 30 min attendent des modèles, des règles ou la
-- MAJ 2 (liste dans l'en-tête de MonetizationService). Un reçu d'une offre pas codée n'est jamais
-- accepté (NotProcessedYet) : on ne garde pas des Robux pour rien.
-- Prix : ceux du doc (4.1, 4.2), en Robux ; l'écran affiche celui de Roblox quand l'Id existe.
-- Textes : en anglais (L-036) ; noms et lignes d'effet des gamepasses repris de la maquette de Clément
-- (UI_RobuxShop, L-047). Icon : nom de l'icône de l'offre, celui de l'attribut IconAsset des cartes de
-- la maquette pour les gamepasses (UI_Icon_GP_…), un nom proposé pour les produits (UI_Icon_DP_…,
-- V0 proposé, absent du doc : à confirmer par Clément avec les rendus MOD-100).
-- Valeurs absentes du doc : marquées « V0 proposé, absent du doc ».
-- Vague 63 (a208 ; L-196, L-200, L-204) : 6 packs d'argent au lieu de 3 (icônes UI_Icon_DP_Cash_1 à _6),
-- CardColor par offre (couleur de la carte de UI_RobuxShop_v2, proposition de Clément en L-204), boosts du
-- HUD aussi dans l'onglet Boosts (ShopBoosts : même produit que les boutons du HUD, Config/Boosts), caisse
-- exclusive (Crate, derrière Features.RobuxCrate) et défilement de la v2 (Shop).
-- Vague 72 (a247 ; L-216 point 8, décision de Clément) : chance du serveur en Robux, 3 produits (×2, ×4, ×8)
-- dans l'onglet Boosts, derrière ServerLuck.Enabled (réglages et règle du cumul : ServerLuck plus bas). Prix,
-- durées, couleurs, icônes et textes : V0 proposés, absents du doc, à valider par Clément.
-- a285 (21/11, L-067) : les Id écrits ici sont ceux de PROD ; dans le jeu DEV, Config/ProductIds les remplace par
-- ceux de DEV (tous à 0 tant que les offres n'y sont pas créées) avant le gel du module. Caisse exclusive : contenu
-- (Crate.Items, objets Exclusive_* de Config/Items) et don codés (MonetizationService), toujours derrière
-- Features.RobuxCrate.
-- a294 (21/11, Cantin ; L-276) : chances validées (Épique au moins), caisse allumée dans le jeu DEV seulement
-- (Features.RobuxCrateDev et Config/ProductIds.IsDev : Crate.Live), toujours coupée en PROD (Features.RobuxCrate) ;
-- ouverture des colis réutilisée (Crate.Reveal, MonetizationService).

local DeepFreeze = require(script.Parent.DeepFreeze)
local Boosts = require(script.Parent.Boosts)
local Features = require(script.Parent.Features)
-- a285 : Config/ProductIds chargé s'il est là (bancs d'essai à liste de modules fixe) ; sans lui, les Ids de PROD.
-- a294 : IsDev lu aussi (sans le module : faux, comme en PROD).
local ProductIds: { Pick: (key: string, prodId: number) -> number, IsDev: boolean? } = (function(): any
	local module = script.Parent:FindFirstChild("ProductIds")
	if module ~= nil then
		local ok, result = pcall(require, module :: any)
		if ok and type(result) == "table" then
			return result
		end
	end
	return {
		Pick = function(_: string, prodId: number): number
			return prodId
		end,
	}
end)()

-- Vague 72 (a247) : interrupteur de la chance du serveur (Ready des 3 produits ServerLuck*). false = cartes
-- cachées et reçus refusés (NotProcessedYet), comme toute offre pas codée. Éteint en V0 tant que Clément n'a pas
-- validé prix, durées et cumul ; true = 3 cartes de plus dans Boosts (une 2e rangée, comme l'onglet Argent).
local SERVER_LUCK = false

-- Onglets de l'écran (3.1 : Offres, Gamepasses, Argent, Boosts ; Tabs.OffersTab… de L-047).
export type Tab = "Offers" | "Gamepasses" | "Cash" | "Boosts"

export type PassKey = "DoubleCash" | "DoubleTraining" | "DoubleSpeed" | "VIP" | "AutoCollect" | "FastOpen" | "ExtraStands" | "HydraulicGloves"
export type ProductKey =
	"OpenNow"
	| "Cash10"
	| "Cash30"
	| "Cash60"
	| "Cash180"
	| "Cash300"
	| "Cash720"
	| "Revenge"
	| "InstantShutter"
	| "StarterPack"
	| "Luck3"
	| "Shield30"
	| "ServerLuck2"
	| "ServerLuck4"
	| "ServerLuck8"
	| "Crate" -- a285 : la caisse exclusive (Crate plus bas, pas dans Products : un produit par lot, Crate.Packs)

-- Un gamepass (achat unique, 4.1).
export type Pass = {
	Key: PassKey, -- clé du code et de l'attribut Pass<Key> du Player
	Order: number, -- rang de la carte dans l'onglet Gamepasses
	DisplayName: string,
	Effect: string, -- ligne d'effet de la carte
	Icon: string,
	Price: number, -- Robux (doc 4.1)
	Id: number, -- gamepass du Creator Hub ; 0 = pas encore créé
	Ready: boolean,
	CardColor: Color3?, -- couleur de sa carte dans UI_RobuxShop_v2 (L-204) ; nil = celle du Template
	Multiplier: number?, -- ×2 Argent (revenus), ×2 Entraînement et ×2 Vitesse (gains du tapis ; plus de banc, v2)
	DelayFactor: number?, -- Ouverture rapide : facteur des attentes d'ouverture des colis PNJ
	Stands: number?, -- +4 présentoirs : présentoirs au-delà du maximum
	-- a319 (L-303) : bouton de UI_HUD qui vend aussi ce gamepass (HudMenuController) : Price.Amount = Price ; caché
	-- s'il est possédé, si l'Id vaut 0, si la boutique est coupée ou tant que le serveur n'a pas eu la réponse de
	-- Roblox (attribut PassKnown<Key>).
	HudButton: string?,
}

-- Un palier de prix d'« Ouvrir maintenant » : un produit développeur par palier (un produit Roblox a
-- un prix fixe). V0 proposé, absent du doc : le doc dit seulement « 19 à 99 selon le temps restant ».
export type OpenNowTier = {
	Id: number, -- produit développeur de ce palier ; 0 = pas encore créé
	Price: number, -- Robux
	Skip: number, -- secondes d'attente retirées au colis, au plus ; palier choisi : le plus petit Skip ≥ attente restante
}

-- Un produit développeur (achat répétable, 4.2).
export type Product = {
	Key: ProductKey,
	Tab: Tab,
	Order: number, -- rang de la carte dans son onglet
	DisplayName: string,
	Effect: string,
	Icon: string,
	Price: number, -- Robux (doc 4.2) ; Ouvrir maintenant : le premier palier
	Id: number, -- produit du Creator Hub ; 0 = pas encore créé ; Ouvrir maintenant : un Id par palier (Tiers)
	Ready: boolean,
	CardColor: Color3?, -- couleur de sa carte dans UI_RobuxShop_v2 (L-204) ; nil = celle du Template
	Minutes: number?, -- pack d'argent : minutes des revenus actuels (doc 4.2 : 10, 60, 300 ; 30, 180 et 720 : V0, L-196)
	Tiers: { OpenNowTier }?, -- Ouvrir maintenant
	Luck: number?, -- vague 72 (a247) : chance du serveur, facteur de la chance des colis pour tout le serveur
	LuckMinutes: number?, -- vague 72 (a247) : sa durée (min)
}

-- Vague 63 (L-196 point 3, L-204) : un boost du HUD (Config/Boosts) montré aussi dans l'onglet Boosts de la
-- boutique. Prix, Id et Ready sont ceux de Config/Boosts (Boost) : la carte et le bouton du HUD achètent le
-- même produit. Ready à false : la carte montre le prix et « Soon » au clic, rien n'est vendu.
export type ShopBoost = {
	Key: string, -- clé de Config/Boosts.List
	Order: number, -- rang de la carte dans l'onglet Boosts (avant Ouvrir maintenant, comme la maquette de Clément)
	DisplayName: string,
	Effect: string,
	Icon: string,
	CardColor: Color3?,
	Boost: Boosts.Boost,
}

-- Vague 63 (L-200, L-204) : un lot de la caisse exclusive (Crate.BuyRow.BuyButton1 à 3).
export type CratePack = {
	Count: number, -- caisses du lot
	Price: number, -- Robux
	Id: number, -- produit développeur ; 0 = pas encore créé
}

-- Gamepasses (4.1), dans l'ordre de la maquette (×2 CASH, ×2 TRAINING, VIP, AUTO COLLECT, FAST OPEN,
-- +4 DISPLAYS), puis les Gants hydrauliques. a319 (L-303) : ×2 Speed en 3e, juste après ×2 Training (même famille,
-- gains du tapis), les suivants décalés d'un rang.
local Passes: { Pass } = {
	{ Key = "DoubleCash", Id = 0, Order = 1, Price = 449, Ready = true, CardColor = Color3.fromHex("45D63A"), Multiplier = 2, DisplayName = "×2 Cash", Effect = "Doubles all your income", Icon = "UI_Icon_GP_x2Cash" },
	{ Key = "DoubleTraining", Id = 0, Order = 2, Price = 299, Ready = true, CardColor = Color3.fromHex("FF9A2E"), Multiplier = 2, DisplayName = "×2 Training", Effect = "×2 treadmill gains", Icon = "UI_Icon_GP_x2Training" },
	-- a319 (23/11, L-303, décision de Cantin) : « x2 SPEED » du HUD, gamepass permanent à 149 R$ (prix V0 validé par
	-- Cantin), à la place du boost de 10 min à 29 R$ (Config/Boosts, retiré). Même effet que ce boost : × 2 sur les
	-- gains du tapis, multiplié par ×2 Training (× 4 avec les deux) et par les événements ; les trails n'y changent
	-- rien (ils multiplient la Speed affichée, pas le gain). Id à créer par Cantin au nom du groupe (0 = rien en vente).
	-- Nom, effet, icône et couleur : ceux de l'ancienne carte « ×2 Speed » de l'onglet Boosts (L-204).
	{ Key = "DoubleSpeed", Id = 0, Order = 3, Price = 149, Ready = true, CardColor = Color3.fromHex("F2553A"), Multiplier = 2, DisplayName = "×2 Speed", Effect = "×2 speed on the treadmill", Icon = "UI_Icon_SpeedBoost", HudButton = "SpeedBoostButton" },
	{ Key = "VIP", Id = 0, Order = 4, Price = 249, Ready = false, CardColor = Color3.fromHex("8A5CF0"), DisplayName = "VIP", Effect = "+10% income, aura, chat tag", Icon = "UI_Icon_GP_VIP" },
	{ Key = "AutoCollect", Id = 0, Order = 5, Price = 199, Ready = true, CardColor = Color3.fromHex("FFC928"), DisplayName = "Auto Collect", Effect = "Cash collects itself, anywhere", Icon = "UI_Icon_GP_AutoCollect" },
	{ Key = "FastOpen", Id = 0, Order = 6, Price = 299, Ready = true, CardColor = Color3.fromHex("2FA8F0"), DelayFactor = 0.5, DisplayName = "Fast Open", Effect = "Anti-theft 2× shorter", Icon = "UI_Icon_GP_FastOpen" },
	{ Key = "ExtraStands", Id = 0, Order = 7, Price = 349, Ready = true, CardColor = Color3.fromHex("E05AD8"), Stands = 4, DisplayName = "+4 Displays", Effect = "4 extra display stands", Icon = "UI_Icon_GP_Displays" },
	-- Texte V0 proposé, absent de la maquette.
	{ Key = "HydraulicGloves", Id = 0, Order = 8, Price = 499, Ready = false, DisplayName = "Hydraulic Gloves", Effect = "Exclusive tool: 2.5× your best tool", Icon = "UI_Icon_GP_HydraulicGloves" },
}

-- Produits développeur (4.2). Noms et lignes d'effet : V0 proposés, absents de la maquette.
local Products: { Product } = {
	{ Key = "StarterPack", Id = 0, Tab = "Offers", Order = 1, Price = 99, Ready = true, DisplayName = "Starter Pack", Effect = "×2 Cash 1h + Hammer + $2.6K", Icon = "UI_Icon_DP_StarterPack" },
	-- 6 packs d'argent (L-196 point 1), du plus petit au plus gros. 10 min, 1 h et 5 h : doc 4.2 ; 30 min,
	-- 3 h et 12 h : V0 proposé, absent du doc (prix par minute qui baisse avec la taille du pack : 4,9 ; 4,3 ;
	-- 3,3 ; 2,8 ; 2,7 ; 2,2 R$). Couleurs du vert à l'or (L-204 ; 2, 4 et 6 : V0 entre celles de Clément).
	{ Key = "Cash10", Id = 0, Tab = "Cash", Order = 1, Price = 49, Ready = true, CardColor = Color3.fromHex("5BCB3A"), Minutes = 10, DisplayName = "10 Minutes of Cash", Effect = "10 min of income", Icon = "UI_Icon_DP_Cash_1" },
	{ Key = "Cash30", Id = 0, Tab = "Cash", Order = 2, Price = 129, Ready = true, CardColor = Color3.fromHex("3EBA4A"), Minutes = 30, DisplayName = "30 Minutes of Cash", Effect = "30 min of income", Icon = "UI_Icon_DP_Cash_2" },
	{ Key = "Cash60", Id = 0, Tab = "Cash", Order = 3, Price = 199, Ready = true, CardColor = Color3.fromHex("22A85A"), Minutes = 60, DisplayName = "1 Hour of Cash", Effect = "1 hour of income", Icon = "UI_Icon_DP_Cash_3" },
	{ Key = "Cash180", Id = 0, Tab = "Cash", Order = 4, Price = 499, Ready = true, CardColor = Color3.fromHex("85A739"), Minutes = 180, DisplayName = "3 Hours of Cash", Effect = "3 hours of income", Icon = "UI_Icon_DP_Cash_4" },
	{ Key = "Cash300", Id = 0, Tab = "Cash", Order = 5, Price = 799, Ready = true, CardColor = Color3.fromHex("E8A618"), Minutes = 300, DisplayName = "5 Hours of Cash", Effect = "5 hours of income", Icon = "UI_Icon_DP_Cash_5" },
	{ Key = "Cash720", Id = 0, Tab = "Cash", Order = 6, Price = 1599, Ready = true, CardColor = Color3.fromHex("FFC21A"), Minutes = 720, DisplayName = "12 Hours of Cash", Effect = "12 hours of income", Icon = "UI_Icon_DP_Cash_6" },
	{
		Key = "OpenNow",
		Id = 0, -- inutilisé : un Id par palier, plus bas
		Tab = "Boosts",
		Order = 3, -- après zZz (ShopBoosts), comme la maquette de Clément (a319 : ×2 Speed est devenu un gamepass)
		CardColor = Color3.fromHex("18B894"),
		Price = 19,
		Ready = true,
		DisplayName = "Open Now",
		Effect = "Unlock now",
		Icon = "UI_Icon_DP_OpenNow",
		-- V0 proposé, absent du doc : 4 paliers, de l'attente d'un Rare (45 s) à celle d'un Secret
		-- (15 min, table 7.3), au prix du doc (19 à 99).
		Tiers = {
			{ Id = 0, Price = 19, Skip = 60 }, -- jusqu'à 1 min (Commun à Rare)
			{ Id = 0, Price = 39, Skip = 180 }, -- jusqu'à 3 min (Épique, Légendaire)
			{ Id = 0, Price = 59, Skip = 480 }, -- jusqu'à 8 min (Mythique)
			{ Id = 0, Price = 99, Skip = 900 }, -- jusqu'à 15 min (Secret)
		},
	},
	-- Pas codés (Ready = false) : voir l'en-tête de MonetizationService.
	{ Key = "Revenge", Id = 0, Tab = "Boosts", Order = 4, Price = 25, Ready = false, DisplayName = "Revenge", Effect = "Teleport behind your thief", Icon = "UI_Icon_DP_Revenge" },
	{ Key = "InstantShutter", Id = 0, Tab = "Boosts", Order = 5, Price = 29, Ready = false, DisplayName = "Instant Shutter", Effect = "Close your shop right now", Icon = "UI_Icon_DP_InstantShutter" },
	{ Key = "Luck3", Id = 0, Tab = "Boosts", Order = 6, Price = 79, Ready = false, DisplayName = "×3 Luck", Effect = "Rarer boxes for 15 min", Icon = "UI_Icon_DP_Luck3" },
	{ Key = "Shield30", Id = 0, Tab = "Boosts", Order = 7, Price = 99, Ready = false, DisplayName = "30 Min Shield", Effect = "Nobody can rob your shop", Icon = "UI_Icon_DP_Shield30" },
	-- Vague 72 (a247, L-216 point 8) : chance du serveur (comme le ×2, ×4, ×8 de Steal a Brainrot). V0 proposé,
	-- absent du doc : 15 min chacune ; 149, 399 et 999 R$ (le plus cher du jeu après le pack de 12 h) ; couleurs,
	-- et textes. Vague 73 (a253, L-240 point 2) : icône UI_Icon_DP_Luck3, celle de la carte SERVER LUCK de Clément
	-- (Luck3 n'est pas en vente, Ready = false : pas deux offres à la même icône tant qu'il le reste).
	{ Key = "ServerLuck2", Id = 0, Tab = "Boosts", Order = 8, Price = 149, Ready = SERVER_LUCK, CardColor = Color3.fromHex("3FC1FF"), Luck = 2, LuckMinutes = 15, DisplayName = "×2 Server Luck", Effect = "×2 luck for the whole server, 15 min", Icon = "UI_Icon_DP_Luck3" },
	{ Key = "ServerLuck4", Id = 0, Tab = "Boosts", Order = 9, Price = 399, Ready = SERVER_LUCK, CardColor = Color3.fromHex("B15CFF"), Luck = 4, LuckMinutes = 15, DisplayName = "×4 Server Luck", Effect = "×4 luck for the whole server, 15 min", Icon = "UI_Icon_DP_Luck3" },
	{ Key = "ServerLuck8", Id = 0, Tab = "Boosts", Order = 10, Price = 999, Ready = SERVER_LUCK, CardColor = Color3.fromHex("FFB21A"), Luck = 8, LuckMinutes = 15, DisplayName = "×8 Server Luck", Effect = "×8 luck for the whole server, 15 min", Icon = "UI_Icon_DP_Luck3" },
}

-- Vague 63 (L-196 point 3, L-204) : les boutons en situation du HUD (Config/Boosts) aussi dans l'onglet Boosts.
-- Noms, effets, icônes (UI_Icon_Sleep) et couleurs : maquette de Clément (L-204). a319 (L-303) : la carte « ×2 Speed »
-- quitte l'onglet Boosts (le boost de 10 min est retiré) : c'est le gamepass DoubleSpeed de l'onglet Gamepasses.
local ShopBoosts: { ShopBoost } = {}
for _, entry in
	{
		-- Vague 71 (a238, L-213 point 1d) : nom de la carte V0 proposé (Clément voulait un texte, pas « zZz ») ;
		-- le bouton du HUD garde « zZz ».
		{ Key = "SleepGuards", Order = 2, DisplayName = "Sleeping Guards 60s", Effect = "Guards & police sleep 60 s", Icon = "UI_Icon_Sleep", CardColor = Color3.fromHex("5B4BE0") },
	}
do
	for _, boost in Boosts.List do
		if boost.Key == entry.Key then
			table.insert(ShopBoosts, {
				Key = entry.Key,
				Order = entry.Order,
				DisplayName = entry.DisplayName,
				Effect = entry.Effect,
				Icon = entry.Icon,
				CardColor = entry.CardColor,
				Boost = boost,
			})
		end
	end
end

local PassByKey: { [string]: Pass } = {}
for _, pass in Passes do
	PassByKey[pass.Key] = pass
end
local ProductByKey: { [string]: Product } = {}
for _, product in Products do
	ProductByKey[product.Key] = product
end

local Monetization = {
	Passes = Passes,
	Products = Products,
	PassByKey = PassByKey, -- clé = PassKey ; une clé inconnue renvoie nil
	ProductByKey = ProductByKey, -- clé = ProductKey
	ShopBoosts = ShopBoosts, -- vague 63 : boosts du HUD dans l'onglet Boosts (même produit, Config/Boosts)

	-- Vague 63 (L-200, L-204) : caisse exclusive de UI_RobuxShop_v2 (section Crate). Montrée seulement avec
	-- Features.RobuxCrate, des chances pour chaque case (Odds) et là où Roblox permet les objets payants au
	-- hasard (PolicyService : ArePaidRandomItemsRestricted faux) ; sinon la section est cachée. Sans Ready, ses
	-- boutons montrent « Soon » (rien n'est vendu).
	-- Prix : décision de Clément du 2026-11-16 (repris de Steal an Egg).
	-- a285 (21/11) : contenu (Items) et don codés (MonetizationService : Count tirages selon Odds, un objet par
	-- tirage dans l'inventaire, achat idempotent).
	-- a294 (21/11, Cantin) : montrée seulement si Live (calculé plus bas, avant le gel) :
	-- Features.RobuxCrate (partout, PROD comprise : false) ou Features.RobuxCrateDev dans le jeu DEV
	-- (Config/ProductIds.IsDev) ; vendue si Live et Ready, même boutique coupée (Features.RobuxShop = false) ; sans Ready, ou sans Id (0) dans ce jeu,
	-- ses boutons restent « Soon ».
	Crate = {
		Ready = true, -- a285 : contenu et don codés (vendue seulement avec Live : Features.RobuxCrate, RobuxCrateDev en DEV)
		Live = false, -- a294 : posé plus bas (l'interrupteur de ce jeu), ne pas l'écrire ici
		UnitPrice = 99, -- prix d'une caisse seule : OldPrice d'un lot = UnitPrice × Count (caché sans remise)
		Packs = {
			{ Count = 1, Price = 99, Id = 0 },
			{ Count = 3, Price = 249, Id = 0 },
			{ Count = 10, Price = 799, Id = 0 },
		} :: { CratePack },
		-- Chances (en %) des cases Odd_1 à Odd_6, de la plus commune à la plus rare ; vide = pas décidées
		-- (caisse cachée : règle Roblox, chances affichées avant l'achat). Écrites telles quelles dans Odd_n.Chance.
		-- a294 (L-276) : jamais sous Épique, total 100. Cases de UI_RobuxShop_v2 : Disco Ball (Épique) 30, Golden
		-- Gramophone (Épique) 30, Golden Rocket (Légendaire) 25, Crystal Skull (Mythique) 10, Neon Jukebox (Secret) 4,
		-- Golden Planet (Divine) 1.
		Odds = { 30, 30, 25, 10, 4, 1 } :: { number }, -- validé par Cantin, 21/11
		-- a285 (21/11) : ItemId de chaque case, dans l'ordre d'Odds (Odd_1 à Odd_6 ; noms des icônes ICON_Exclusive_*
		-- de Clément, L-247 et L-252). Objets de Config/Items.Exclusives, jamais tirés d'un colis.
		Items = {
			"Exclusive_DiscoBall",
			"Exclusive_GoldenGramophone",
			"Exclusive_GoldenRocket",
			"Exclusive_CrystalSkull",
			"Exclusive_NeonJukebox",
			"Exclusive_GoldenPlanet",
		} :: { string },
		-- a285 : objets reçus même au-delà de la place de l'inventaire (Balance.Display.InventoryMax) : le joueur a
		-- payé. V0 proposé le 2026-11-21, absent du doc.
		IgnoreInventoryMax = true,
		-- a285 : clé du crochet de Studio et préfixe des clés de Config/ProductIds (Crate1, Crate3, Crate10).
		KeyPrefix = "Crate",
		-- a294 (21/11, V0 de Cantin « en attendant mieux ») : après le don, l'ouverture des colis (RevealStarted avec un
		-- plan Shared/UnboxPlan, RevealController et Reveal/Unbox chez le client) se joue devant l'acheteur pour l'objet
		-- tiré : nombre de coups (Unbox.New.ActionsByRarity) et cote finale (« 1 IN N », N = 100 / sa chance) selon sa
		-- rareté ; tout est tiré par le serveur. Un lot de plusieurs caisses joue l'objet le plus rare du lot (les
		-- autres sont nommés par leur message). L'acheteur est immobilisé et protégé (comme l'ouvreur d'un colis) jusqu'à
		-- RevealDone, ou au plus la durée la plus longue du plan (UnboxPlan.serverMaxSeconds).
		Reveal = {
			Enabled = true, -- V0 de Cantin, 21/11 ; false = objets donnés sans ouverture (comme a285)
			SafeZoneOnly = true, -- validé par Cantin, 21/11 (V0 d'a294) : hors zone safe (braquage, poursuite), pas d'ouverture
			ShopId = "ExclusiveCrate", -- V0 (a294) : ShopId du remote, aucun magasin : le colis sort devant l'acheteur
			SlotName = "Crate", -- V0 (a294)
			StartRarity = "Epic", -- V0 proposé le 2026-11-21 (a294) : rareté montrée sur le colis, la plus basse de la caisse
		},
	},

	-- Vague 63 (L-200) : UI_RobuxShop_v2. V0 proposé, absent du doc : durée (s) du défilement de List jusqu'à la
	-- section d'un onglet.
	Shop = {
		ScrollTime = 0.35,
		-- Vague 73 (a253, L-242 point 3, L-243) : rayons des cartes, des cases de la caisse et du pack de départ (tout
		-- Rays de l'écran hors Crate.Backdrop, que tourne CrateLoop) : RaysTurn degrés toutes les RaysPeriod s, leur
		-- UIGradient Fade à l'inverse. V0 proposé, absent du doc : comme les rayons de la caisse (Config/ShopFx.Crate).
		RaysTurn = -45,
		RaysPeriod = 4,
		-- Vague 73 (a253, L-247 point 1b) : la caméra de Crate.Icon.Preview (caisse 3D) se balance de ± PreviewSway
		-- degrés autour de la caisse, un aller-retour en PreviewSwayPeriod s (fiche Throw a Seed reprise par Clément).
		PreviewSway = 12,
		PreviewSwayPeriod = 3.5,
	},

	-- Achats de produits (9.6).
	Receipts = {
		-- V0 proposé, absent du doc : PurchaseId gardés dans Purchases du profil (les plus anciens
		-- partent au-delà) ; 100 comme l'exemple de ProfileStore. Roblox ne rappelle un reçu que tant
		-- qu'il n'est pas accepté : seuls les derniers comptent. a275 (audit a272 F5, V0 proposé, Cantin, 23/11) :
		-- 500 (avant 100), pour qu'un reçu rappelé tard ne soit jamais redonné si des produits bon marché arrivent ;
		-- une entrée pèse environ 50 octets : 25 Ko au plus, et seulement après 500 achats Robux.
		History = 500,
		-- V0 proposé, absent du doc : attente (s) du profil d'un joueur qui vient d'arriver avant de
		-- répondre NotProcessedYet (Roblox rappelle le reçu plus tard).
		ProfileWait = 30,
	},

	-- V0 proposé, absent du doc : lecture de la possession des gamepasses à l'arrivée
	-- (UserOwnsGamePassAsync) : Attempts essais espacés de RetryDelay s, puis un nouvel essai toutes
	-- les SlowRetry s tant que Roblox ne répond pas.
	PassCheck = {
		Attempts = 3,
		RetryDelay = 2,
		SlowRetry = 60,
	},

	-- Bonus des abonnés Roblox Premium (règles Roblox de 4.2) : +10 % de revenus.
	Premium = {
		IncomeBonus = 0.1,
	},

	-- Boost ×2 argent (pack de départ ; plus tard les récompenses, 3.3) : double les revenus, compté
	-- seulement pendant le jeu ; un 2e boost prolonge le premier au lieu de le doubler (proposition V0
	-- de la section 3.3, reprise telle quelle).
	CashBoost = {
		Multiplier = 2,
	},

	-- Pack de départ (4.2) : « Offre unique la 1re heure : ×2 argent 1 h + Marteau + 50 000 $ ».
	StarterPack = {
		Window = 3600, -- 1re heure, comptée en temps de jeu (Lifetime.PlaySeconds + session : V0, le doc ne précise pas)
		BoostSeconds = 3600, -- ×2 argent 1 h
		Tool = "Hammer", -- Config/Tools
		Cash = 2_600, -- V0 proposé (Cantin, 20/11), avant : 50_000 (vague 76 : revenus remis à l'échelle ; texte Effect du produit suivi)
		-- Vague 73 (a253, L-242 point 3) : ancien prix (Robux) écrit dans Featured.OldPrice ; la remise de
		-- Featured.DiscountTag.DiscountLabel (« 75% OFF ») en est tirée avec le prix affiché. V0 proposé, absent du doc,
		-- à valider par Clément ; nil (ou pas plus cher que le prix) = ni ancien prix ni étiquette.
		OldPrice = 399 :: number?,
	},

	-- Packs d'argent (4.2) : V0 proposé, absent du doc : au moins 50 $ par minute, la proposition V0
	-- des récompenses « X min de revenus » (3.3), pour qu'un joueur sans revenu reçoive quelque chose.
	CashPacks = {
		MinPerMinute = 50,
	},

	-- Ouvrir maintenant (4.2) : V0 proposé, absent du doc : pas proposé sous 10 s d'attente restante
	-- (le colis serait prêt avant la fin de l'achat).
	OpenNow = {
		MinRemaining = 10,
	},

	-- Vague 72 (a247, L-216 point 8) : chance du serveur (produits ServerLuck2, 4 et 8 ; MonetizationService).
	-- Effet : la chance tirée à l'ouverture de chaque colis de rayon, pour tous les joueurs du serveur, est
	-- multipliée par Luck (StoreHeistService lit l'attribut Attribute du Workspace ; absent = 1), en plus des
	-- événements live. Cumul (V0 proposé) : chaque achat est une tranche (facteur, durée) mise en file ; seule la
	-- tranche au plus fort facteur tourne (la plus ancienne à facteur égal), les autres attendent sans perdre de
	-- temps : un ×2 acheté pendant un ×8 commence à la fin du ×8 ; deux ×4 font 30 min de ×4. Rien n'est sauvegardé :
	-- un serveur qui s'arrête perd la file (l'achat reste noté, comme tout produit).
	-- Attributs du Workspace (lus par le client) : Attribute (facteur en cours, absent sans chance), EndsAtAttribute
	-- (heure du serveur où ce facteur finit, tranches de même facteur comprises), ByAttribute (nom de l'acheteur).
	ServerLuck = {
		Enabled = SERVER_LUCK,
		Attribute = "ServerLuck",
		EndsAtAttribute = "ServerLuckEndsAt",
		ByAttribute = "ServerLuckBy",
		AnnounceKind = "Announce", -- Notify à tous, comme l'annonce d'un objet Légendaire (Config/Unbox.AnnounceKind)
		-- Textes V0 (anglais) : acheteur, « ×8 », durée ; Queued ajoute le facteur en cours.
		Messages = {
			Started = "%s gave the whole server %s LUCK for %s!",
			Queued = "%s gave the whole server %s LUCK for %s! It starts after the current %s.",
		},
		-- a285 (21/11, L-240 point 3) : la chance en cours dans UI_EventBanner (Banner.Card.Title, Effect, Timer),
		-- quand aucun événement live n'y est déjà (EventBannerController). Textes de L-240 (« SERVER LUCK ×2 »,
		-- « Rarer boxes for everyone », « 14:59 ») ; %s = le facteur (« ×2 »).
		Banner = {
			Title = "SERVER LUCK %s",
			Effect = "Rarer boxes for everyone",
		},
	},
}

-- a285 (21/11, L-067) : Ids du jeu en cours (DEV ou PROD, Config/ProductIds), posés avant le gel.
for _, pass in Passes do
	pass.Id = ProductIds.Pick(pass.Key, pass.Id)
end
for _, product in Products do
	product.Id = ProductIds.Pick(product.Key, product.Id)
	if product.Tiers then
		for index, tier in product.Tiers do
			tier.Id = ProductIds.Pick(`{product.Key}{index}`, tier.Id)
		end
	end
end
for _, pack in Monetization.Crate.Packs do
	pack.Id = ProductIds.Pick(`{Monetization.Crate.KeyPrefix}{pack.Count}`, pack.Id)
end
-- a294 (21/11, Cantin) : caisse allumée partout avec Features.RobuxCrate, sinon dans le jeu DEV seulement avec
-- Features.RobuxCrateDev (montrée ; vendue avec Ready aussi : don codé).
Monetization.Crate.Live = Features.RobuxCrate == true
	or ((Features :: any).RobuxCrateDev == true and ProductIds.IsDev == true)

-- Palier d'« Ouvrir maintenant » pour un colis qui attend encore `remaining` secondes : le plus petit
-- palier dont Skip couvre l'attente (le dernier au-delà) ; nil sous OpenNow.MinRemaining (pas proposé).
function Monetization.OpenNowTier(remaining: number): OpenNowTier?
	local tiers = ProductByKey.OpenNow.Tiers
	if tiers == nil or type(remaining) ~= "number" or remaining ~= remaining or remaining <= Monetization.OpenNow.MinRemaining then
		return nil
	end
	for _, tier in tiers do
		if tier.Skip >= remaining then
			return tier
		end
	end
	return tiers[#tiers]
end

-- Argent d'un pack de `minutes` minutes pour un revenu de `incomePerSecond` $/s (celui du HUD, bonus
-- compris) : au moins CashPacks.MinPerMinute $ par minute, en dollars entiers.
function Monetization.CashPackAmount(incomePerSecond: number, minutes: number): number
	local income = if type(incomePerSecond) == "number" and incomePerSecond == incomePerSecond and incomePerSecond > 0 and incomePerSecond < math.huge
		then incomePerSecond
		else 0
	return math.floor(math.max(income * 60 * minutes, Monetization.CashPacks.MinPerMinute * minutes))
end

export type Monetization = typeof(Monetization)

return DeepFreeze(Monetization)
