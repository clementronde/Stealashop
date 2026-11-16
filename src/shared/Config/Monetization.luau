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

local DeepFreeze = require(script.Parent.DeepFreeze)
local Boosts = require(script.Parent.Boosts)

-- Onglets de l'écran (3.1 : Offres, Gamepasses, Argent, Boosts ; Tabs.OffersTab… de L-047).
export type Tab = "Offers" | "Gamepasses" | "Cash" | "Boosts"

export type PassKey = "DoubleCash" | "DoubleTraining" | "VIP" | "AutoCollect" | "FastOpen" | "ExtraStands" | "HydraulicGloves"
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
	Multiplier: number?, -- ×2 Argent (revenus), ×2 Entraînement (gains du tapis ; plus de banc, v2)
	DelayFactor: number?, -- Ouverture rapide : facteur des attentes d'ouverture des colis PNJ
	Stands: number?, -- +4 présentoirs : présentoirs au-delà du maximum
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
-- +4 DISPLAYS), puis les Gants hydrauliques.
local Passes: { Pass } = {
	{ Key = "DoubleCash", Id = 0, Order = 1, Price = 449, Ready = true, CardColor = Color3.fromHex("45D63A"), Multiplier = 2, DisplayName = "×2 Cash", Effect = "Doubles all your income", Icon = "UI_Icon_GP_x2Cash" },
	{ Key = "DoubleTraining", Id = 0, Order = 2, Price = 299, Ready = true, CardColor = Color3.fromHex("FF9A2E"), Multiplier = 2, DisplayName = "×2 Training", Effect = "×2 treadmill gains", Icon = "UI_Icon_GP_x2Training" },
	{ Key = "VIP", Id = 0, Order = 3, Price = 249, Ready = false, CardColor = Color3.fromHex("8A5CF0"), DisplayName = "VIP", Effect = "+10% income, aura, chat tag", Icon = "UI_Icon_GP_VIP" },
	{ Key = "AutoCollect", Id = 0, Order = 4, Price = 199, Ready = true, CardColor = Color3.fromHex("FFC928"), DisplayName = "Auto Collect", Effect = "Cash collects itself, anywhere", Icon = "UI_Icon_GP_AutoCollect" },
	{ Key = "FastOpen", Id = 0, Order = 5, Price = 299, Ready = true, CardColor = Color3.fromHex("2FA8F0"), DelayFactor = 0.5, DisplayName = "Fast Open", Effect = "Anti-theft 2× shorter", Icon = "UI_Icon_GP_FastOpen" },
	{ Key = "ExtraStands", Id = 0, Order = 6, Price = 349, Ready = true, CardColor = Color3.fromHex("E05AD8"), Stands = 4, DisplayName = "+4 Displays", Effect = "4 extra display stands", Icon = "UI_Icon_GP_Displays" },
	-- Texte V0 proposé, absent de la maquette.
	{ Key = "HydraulicGloves", Id = 0, Order = 7, Price = 499, Ready = false, DisplayName = "Hydraulic Gloves", Effect = "Exclusive tool: 2.5× your best tool", Icon = "UI_Icon_GP_HydraulicGloves" },
}

-- Produits développeur (4.2). Noms et lignes d'effet : V0 proposés, absents de la maquette.
local Products: { Product } = {
	{ Key = "StarterPack", Id = 0, Tab = "Offers", Order = 1, Price = 99, Ready = true, DisplayName = "Starter Pack", Effect = "×2 Cash 1h + Hammer + $50K", Icon = "UI_Icon_DP_StarterPack" },
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
		Order = 3, -- après ×2 Speed et zZz (ShopBoosts), comme la maquette de Clément
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
}

-- Vague 63 (L-196 point 3, L-204) : les boutons en situation du HUD (Config/Boosts) aussi dans l'onglet Boosts.
-- Noms, effets, icônes (UI_Icon_SpeedBoost, UI_Icon_Sleep) et couleurs : maquette de Clément (L-204).
local ShopBoosts: { ShopBoost } = {}
for _, entry in
	{
		{ Key = "SpeedBoost", Order = 1, DisplayName = "×2 Speed", Effect = "×2 speed on the treadmill", Icon = "UI_Icon_SpeedBoost", CardColor = Color3.fromHex("F2553A") },
		{ Key = "SleepGuards", Order = 2, DisplayName = "zZz", Effect = "Guards & police sleep 60 s", Icon = "UI_Icon_Sleep", CardColor = Color3.fromHex("5B4BE0") },
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
	-- Prix : décision de Clément du 2026-11-16 (repris de Steal an Egg). Contenu et chances : pas décidés.
	Crate = {
		Ready = false, -- contenu et don pas codés : rien n'est vendu (un reçu serait refusé, NotProcessedYet)
		UnitPrice = 99, -- prix d'une caisse seule : OldPrice d'un lot = UnitPrice × Count (caché sans remise)
		Packs = {
			{ Count = 1, Price = 99, Id = 0 },
			{ Count = 3, Price = 249, Id = 0 },
			{ Count = 10, Price = 799, Id = 0 },
		} :: { CratePack },
		-- Chances (en %) des cases Odd_1 à Odd_6, de la plus commune à la plus rare ; vide = pas décidées
		-- (caisse cachée : règle Roblox, chances affichées avant l'achat).
		-- Vague 66 (a218, L-210 précision (b)) : V0 proposé, à valider par Clément (la caisse reste cachée :
		-- Features.RobuxCrate = false). Dans l'esprit de Break and Steal an Egg, le plus rare à 1 % ; total 100.
		-- Cases de UI_RobuxShop_v2 : Boule disco (Rare) 45, Gramophone doré (Épique) 28, Fusée en or (Légendaire) 15,
		-- Crâne de cristal (Mythique) 7, Jukebox néon (Secret) 4, Planète dorée (Divine) 1.
		Odds = { 45, 28, 15, 7, 4, 1 } :: { number },
	},

	-- Vague 63 (L-200) : UI_RobuxShop_v2. V0 proposé, absent du doc : durée (s) du défilement de List jusqu'à la
	-- section d'un onglet.
	Shop = {
		ScrollTime = 0.35,
	},

	-- Achats de produits (9.6).
	Receipts = {
		-- V0 proposé, absent du doc : PurchaseId gardés dans Purchases du profil (les plus anciens
		-- partent au-delà) ; 100 comme l'exemple de ProfileStore. Roblox ne rappelle un reçu que tant
		-- qu'il n'est pas accepté : seuls les derniers comptent.
		History = 100,
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
		Cash = 50_000,
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
}

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
