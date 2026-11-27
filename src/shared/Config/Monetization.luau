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
-- Vengeance, Rideau instantané et Chance ×3 attendent des modèles, des règles ou la MAJ 2 (liste dans
-- l'en-tête de MonetizationService ; a485 : le Bouclier 30 min est retiré, L-351). Un reçu d'une offre pas codée n'est jamais
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
-- a485 (25/11 ; L-351, réponse de Clément « bloque pas l'ouverture » : les 7 V0 gardés ; prix décidés par Cantin le 25/11,
-- encore à valider par Clément en L-401) :
--   - PRIX DE SECOURS : le prix affiché est celui de Roblox (Creator Hub) dès que l'Id existe ; Price ne sert que si Roblox
--     ne répond pas, et pour le bouton x2 SPEED du HUD. Une valeur par offre, sur sa ligne : facile à changer ;
--   - ×2 Training devient « ×4 Training » avec Features.TrainingX4 (TrainingX4Dev en DEV) : ×4, et le plus fort de
--     ×2 Speed et ×4 Training compte (TrainingLadder, TrainingMultiplier plus bas) ; coupé : ×2 et ×2 qui se multiplient ;
--   - Fast Open s'appelle « Quick Lock » (texte : la clé FastOpen, l'attribut PassFastOpen et l'icône ne changent pas) ;
--   - Hydraulic Gloves (pas codé) : 1,5 × le meilleur outil, jamais plus que l'Angle Grinder (PowerFactor, PowerCap) ;
--   - VIP (pas codé) : verrou de la boutique +10 s au lieu de +30 s (CurtainBonus) ;
--   - Shield30 (bouclier 30 min) retiré pour de bon : jamais créé (Id 0 en DEV et en PROD), à ne jamais créer ;
--   - Open Now : 2 paliers en vente (19 et 39 R$ ; l'antivol le plus long fait 180 s, ShelfOpen.AntiTheft) ; les paliers
--     3 et 4 sont coupés (RetiredTiers : plus jamais proposés, mais un reçu en attente reste livré) ;
--   - Starter Pack : plus de fausse remise (OldPrice = nil : ni ancien prix ni « 75% OFF ») ;
--   - +4 Displays : carte montrée seulement si la boutique a ses présentoirs bonus, avec Features.ExtraStandsGate
--     (ExtraStands.Gate, MonetizationService et RobuxShopController).

local DeepFreeze = require(script.Parent.DeepFreeze)
local Boosts = require(script.Parent.Boosts)
local Features = require(script.Parent.Features)
-- a285 : Config/ProductIds chargé s'il est là (bancs d'essai à liste de modules fixe) ; sans lui, les Ids de PROD.
-- a294 : IsDev lu aussi (sans le module : faux, comme en PROD).
local ProductIds: { Pick: (key: string, prodId: number) -> number, IsDev: boolean?, PurchasesDisabled: boolean? } = (function(): any
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
-- a476 (L-375) : allumé partout avec Features.ServerLuck, ou dans le jeu DEV seulement avec ServerLuckDev (règle C2).
local SERVER_LUCK = Features.ServerLuck == true or (Features.ServerLuckDev == true and ProductIds.IsDev == true)
-- a499 (L-401) : la dose ×3 Luck (Luck3) ne se vend que si le modèle de chance R2 la lit (sinon reçu NotProcessedYet).
local LUCK_V2 = Features.LuckModelV2 == true or (Features.LuckModelV2Dev == true and ProductIds.IsDev == true)

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
	-- a485 (L-351 question 4, V0 gardé ; pas encore codé) : Gants hydrauliques, puissance = PowerFactor × le meilleur outil
	-- acheté, jamais plus que l'outil PowerCap (Config/Tools), pour que la zone 6 reste à deux joueurs.
	PowerFactor: number?,
	PowerCap: string?,
	-- a485 (L-351 question 7, V0 gardé ; pas encore codé) : VIP, secondes ajoutées au verrou de la boutique (tuile Curtain).
	CurtainBonus: number?,
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
	-- a485 (25/11, Cantin) : paliers coupés, par leur numéro d'origine (clé OpenNow<n> de Config/ProductIds) : jamais
	-- proposés ni choisis par OpenNowTier, mais un reçu en attente de l'un d'eux est encore livré (MonetizationService).
	RetiredTiers: { [number]: OpenNowTier }?,
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

-- a485 (L-351) : interrupteurs de ce jeu, posés avant le gel comme Crate.Live (X partout, ou XDev dans le jeu DEV).
local function switchOn(name: string): boolean
	local raw = Features :: any
	return raw[name] == true or (raw[name .. "Dev"] == true and ProductIds.IsDev == true)
end
-- a485 : ×2 Training devient ×4 Training, et le plus fort de ×2 Speed et ×4 Training compte (Features.TrainingX4).
local TRAINING_X4 = switchOn("TrainingX4")

-- Gamepasses (4.1), dans l'ordre de la maquette (×2 CASH, ×2 TRAINING, VIP, AUTO COLLECT, FAST OPEN,
-- +4 DISPLAYS), puis les Gants hydrauliques. a319 (L-303) : ×2 Speed en 3e, juste après ×2 Training (même famille,
-- gains du tapis), les suivants décalés d'un rang.
-- a485 (25/11) : Price = prix de secours (Cantin, 25/11 ; à valider par Clément, L-401), voir l'en-tête.
local Passes: { Pass } = {
	{ Key = "DoubleCash", Id = 2098559046, Order = 1, Price = 299, Ready = true, CardColor = Color3.fromHex("45D63A"), Multiplier = 2, DisplayName = "×2 Cash", Effect = "Doubles all your income", Icon = "UI_Icon_GP_x2Cash" },
	-- a485 (L-351 question 2) : « ×4 Training » à ×4 avec Features.TrainingX4 ; coupé : « ×2 Training » à ×2, comme avant.
	-- Icône inchangée (UI_Icon_GP_x2Training, Clément).
	{ Key = "DoubleTraining", Id = 2099849032, Order = 2, Price = 149, Ready = true, CardColor = Color3.fromHex("FF9A2E"), Multiplier = if TRAINING_X4 then 4 else 2, DisplayName = if TRAINING_X4 then "×4 Training" else "×2 Training", Effect = if TRAINING_X4 then "×4 treadmill gains" else "×2 treadmill gains", Icon = "UI_Icon_GP_x2Training" },
	-- a319 (23/11, L-303, décision de Cantin) : « x2 SPEED » du HUD, gamepass permanent (prix : a485 plus bas), à la place
	-- du boost de 10 min à 29 R$ (Config/Boosts, retiré). Même effet que ce boost : × 2 sur les gains du tapis, multiplié par
	-- ×2 Training (× 4 avec les deux ; a485 : avec Features.TrainingX4, le plus fort des deux compte) et par les
	-- événements ; les trails n'y changent rien (ils multiplient la Speed affichée, pas le gain).
	-- Nom, effet, icône et couleur : ceux de l'ancienne carte « ×2 Speed » de l'onglet Boosts (L-204).
	-- a485 : 49 R$ (avant 149), aussi écrit par le bouton x2 SPEED du HUD (HudButton).
	{ Key = "DoubleSpeed", Id = 2101984255, Order = 3, Price = 49, Ready = true, CardColor = Color3.fromHex("F2553A"), Multiplier = 2, DisplayName = "×2 Speed", Effect = "×2 speed on the treadmill", Icon = "UI_Icon_SpeedBoost", HudButton = "SpeedBoostButton" },
	-- a485 (L-351 question 7) : verrou +10 s (avant +30 s) ; effet pas encore codé (Ready = false).
	{ Key = "VIP", Id = 0, Order = 4, Price = 249, Ready = false, CardColor = Color3.fromHex("8A5CF0"), CurtainBonus = 10, DisplayName = "VIP", Effect = "+10% income, aura, chat tag, +10s lock", Icon = "UI_Icon_GP_VIP" },
	{ Key = "AutoCollect", Id = 2099027027, Order = 5, Price = 99, Ready = true, CardColor = Color3.fromHex("FFC928"), DisplayName = "Auto Collect", Effect = "Cash collects itself, anywhere", Icon = "UI_Icon_GP_AutoCollect" },
	-- a485 (L-351 question 3) : « Quick Lock » (avant « Fast Open ») ; clé, attribut PassFastOpen et icône inchangés.
	{ Key = "FastOpen", Id = 2099039016, Order = 6, Price = 99, Ready = true, CardColor = Color3.fromHex("2FA8F0"), DelayFactor = 0.5, DisplayName = "Quick Lock", Effect = "Anti-theft 2× shorter", Icon = "UI_Icon_GP_FastOpen" },
	{ Key = "ExtraStands", Id = 2099033063, Order = 7, Price = 349, Ready = true, CardColor = Color3.fromHex("E05AD8"), Stands = 4, DisplayName = "+4 Displays", Effect = "4 extra displays", Icon = "UI_Icon_GP_Displays" },
	-- Texte V0 proposé, absent de la maquette. a485 (L-351 question 4) : 1,5 × le meilleur outil (avant 2,5 ×), jamais
	-- plus que l'Angle Grinder ; effet pas encore codé (Ready = false).
	{ Key = "HydraulicGloves", Id = 0, Order = 8, Price = 499, Ready = false, PowerFactor = 1.5, PowerCap = "AngleGrinder", DisplayName = "Hydraulic Gloves", Effect = "Exclusive tool: 1.5× your best tool, max Angle Grinder", Icon = "UI_Icon_GP_HydraulicGloves" },
}

-- Produits développeur (4.2). Noms et lignes d'effet : V0 proposés, absents de la maquette.
local Products: { Product } = {
	{ Key = "StarterPack", Id = 3735788614, Tab = "Offers", Order = 1, Price = 99, Ready = true, DisplayName = "Starter Pack", Effect = "×2 Cash 1h + Hammer + $2.6K", Icon = "UI_Icon_DP_StarterPack" },
	-- 6 packs d'argent (L-196 point 1), du plus petit au plus gros. 10 min, 1 h et 5 h : doc 4.2 ; 30 min,
	-- 3 h et 12 h : V0 proposé, absent du doc. Couleurs du vert à l'or (L-204 ; 2, 4 et 6 : V0 entre celles de Clément).
	-- a485 (25/11, Cantin ; à valider par Clément, L-401) : 29, 69, 119, 249, 349 et 699 R$ (avant 49 à 1 599) : de 2,9 à
	-- 0,97 R$ la minute (rapport monetisation-2026-11-24, section 3.1).
	{ Key = "Cash10", Id = 3735788763, Tab = "Cash", Order = 1, Price = 29, Ready = true, CardColor = Color3.fromHex("5BCB3A"), Minutes = 10, DisplayName = "10 Minutes of Cash", Effect = "10 min of income", Icon = "UI_Icon_DP_Cash_1" },
	{ Key = "Cash30", Id = 3735788830, Tab = "Cash", Order = 2, Price = 69, Ready = true, CardColor = Color3.fromHex("3EBA4A"), Minutes = 30, DisplayName = "30 Minutes of Cash", Effect = "30 min of income", Icon = "UI_Icon_DP_Cash_2" },
	{ Key = "Cash60", Id = 3735788938, Tab = "Cash", Order = 3, Price = 119, Ready = true, CardColor = Color3.fromHex("22A85A"), Minutes = 60, DisplayName = "1 Hour of Cash", Effect = "1 hour of income", Icon = "UI_Icon_DP_Cash_3" },
	{ Key = "Cash180", Id = 3735789144, Tab = "Cash", Order = 4, Price = 249, Ready = true, CardColor = Color3.fromHex("85A739"), Minutes = 180, DisplayName = "3 Hours of Cash", Effect = "3 hours of income", Icon = "UI_Icon_DP_Cash_4" },
	{ Key = "Cash300", Id = 3735789195, Tab = "Cash", Order = 5, Price = 349, Ready = true, CardColor = Color3.fromHex("E8A618"), Minutes = 300, DisplayName = "5 Hours of Cash", Effect = "5 hours of income", Icon = "UI_Icon_DP_Cash_5" },
	{ Key = "Cash720", Id = 3735789566, Tab = "Cash", Order = 6, Price = 699, Ready = true, CardColor = Color3.fromHex("FFC21A"), Minutes = 720, DisplayName = "12 Hours of Cash", Effect = "12 hours of income", Icon = "UI_Icon_DP_Cash_6" },
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
		-- a485 (25/11, Cantin : 2 paliers seulement ; l'antivol le plus long fait 180 s, ShelfOpen.AntiTheft) : les paliers
		-- 1 et 2 restent en vente (19 et 39 R$).
		Tiers = {
			{ Id = 3735789930, Price = 19, Skip = 60 }, -- jusqu'à 1 min (Commun à Rare)
			{ Id = 3735790062, Price = 39, Skip = 180 }, -- jusqu'à 3 min (Épique, Légendaire)
		},
		-- a485 (25/11, Cantin) : paliers 3 et 4 COUPÉS (vente coupée sur le Creator Hub), JAMAIS RÉUTILISER NI SUPPRIMER
		-- leurs Ids (PROD 3735790266 et 3735790374 ; DEV : OpenNow3 et OpenNow4 de Config/ProductIds). Plus jamais proposés ;
		-- un reçu en attente de l'un d'eux est encore livré (même don, Skip s retirées), jamais perdu.
		RetiredTiers = {
			[3] = { Id = 3735790266, Price = 59, Skip = 480 }, -- coupé, ne jamais réutiliser ni supprimer
			[4] = { Id = 3735790374, Price = 99, Skip = 900 }, -- coupé, ne jamais réutiliser ni supprimer
		},
	},
	-- Pas codés (Ready = false) : voir l'en-tête de MonetizationService.
	{ Key = "Revenge", Id = 0, Tab = "Boosts", Order = 4, Price = 25, Ready = false, DisplayName = "Revenge", Effect = "Teleport behind your thief", Icon = "UI_Icon_DP_Revenge" },
	{ Key = "InstantShutter", Id = 0, Tab = "Boosts", Order = 5, Price = 29, Ready = false, DisplayName = "Instant Shutter", Effect = "Close your shop right now", Icon = "UI_Icon_DP_InstantShutter" },
	-- a486 (Cantin, 25/11 ; note d'a479 : dose personnelle ×3 pendant 30 min ; prix inchangé, à valider par Clément, L-401) :
	-- 30 min au lieu de 15. Facteur et durée : Config/ShelfOpen.LuckV2 (PersonalFactor, PersonalMinutes), lus par le modèle
	-- de chance R2 ; le don à l'achat (attributs PersonalLuck et PersonalLuckEndsAt) reste à brancher avec le produit.
	{ Key = "Luck3", Id = 3736589743, Tab = "Boosts", Order = 6, Price = 79, Ready = LUCK_V2, DisplayName = "×3 Luck", Effect = "Rarer boxes for 30 min", Icon = "UI_Icon_DP_Luck3" },
	-- a485 (L-351 question 5, V0 gardé) : Shield30 (« 30 Min Shield », boutique inviolable 30 min) retiré pour de bon. Il
	-- n'a jamais été créé (Id 0 en DEV et en PROD) : aucun reçu possible. Ne jamais le créer sur le Creator Hub.
	-- Vague 72 (a247, L-216 point 8) : chance du serveur (comme le ×2, ×4, ×8 de Steal a Brainrot). V0 proposé,
	-- absent du doc : 15 min chacune ; 149, 399 et 999 R$ (le plus cher du jeu après le pack de 12 h) ; couleurs,
	-- et textes. Vague 73 (a253, L-240 point 2) : icône UI_Icon_DP_Luck3, celle de la carte SERVER LUCK de Clément
	-- (Luck3 n'est pas en vente, Ready = false : pas deux offres à la même icône tant qu'il le reste).
	-- a476 (L-375, Clément 25/11 : « les chances durent 30 minutes ») : 30 min au lieu de 15 (LuckMinutes et Effect).
	{ Key = "ServerLuck2", Id = 0, Tab = "Boosts", Order = 8, Price = 149, Ready = SERVER_LUCK, CardColor = Color3.fromHex("3FC1FF"), Luck = 2, LuckMinutes = 30, DisplayName = "×2 Server Luck", Effect = "×2 luck for the whole server, 30 min", Icon = "UI_Icon_DP_Luck3" },
	{ Key = "ServerLuck4", Id = 0, Tab = "Boosts", Order = 9, Price = 399, Ready = SERVER_LUCK, CardColor = Color3.fromHex("B15CFF"), Luck = 4, LuckMinutes = 30, DisplayName = "×4 Server Luck", Effect = "×4 luck for the whole server, 30 min", Icon = "UI_Icon_DP_Luck3" },
	{ Key = "ServerLuck8", Id = 0, Tab = "Boosts", Order = 10, Price = 999, Ready = SERVER_LUCK, CardColor = Color3.fromHex("FFB21A"), Luck = 8, LuckMinutes = 30, DisplayName = "×8 Server Luck", Effect = "×8 luck for the whole server, 30 min", Icon = "UI_Icon_DP_Luck3" },
}

-- Vague 63 (L-196 point 3, L-204) : les boutons en situation du HUD (Config/Boosts) aussi dans l'onglet Boosts.
-- Noms, effets, icônes (UI_Icon_Sleep) et couleurs : maquette de Clément (L-204). a319 (L-303) : la carte « ×2 Speed »
-- quitte l'onglet Boosts (le boost de 10 min est retiré) : c'est le gamepass DoubleSpeed de l'onglet Gamepasses.
local ShopBoosts: { ShopBoost } = {}
for _, entry in
	{
		-- Vague 71 (a238, L-213 point 1d) : nom de la carte V0 proposé (Clément voulait un texte, pas « zZz ») ;
		-- le bouton du HUD garde « zZz ».
		{ Key = "SleepGuards", Order = 2, DisplayName = "Sleeping Guards 60s", Effect = "Guards & police sleep 60s", Icon = "UI_Icon_Sleep", CardColor = Color3.fromHex("5B4BE0") },
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
	-- a500 (26/11, Cantin) : achats Robux coupés sur ce serveur (jeu TEST, Config/ProductIds.PurchasesDisabled) : tous les
	-- Ids y valent 0 ; la boutique reste visible, chaque carte dit « Not available in test » et ne lance rien.
	PurchasesDisabled = ProductIds.PurchasesDisabled == true,
	-- a485 (L-351 question 2) : true (Features.TrainingX4 dans ce jeu) = les gains du tapis prennent le plus fort de
	-- ×2 Speed et ×4 Training, sans les cumuler ; false = leur produit, comme avant (TrainingMultiplier plus bas).
	TrainingLadder = TRAINING_X4,
	-- a485 (brief L-351 point 5) : +4 Displays proposé seulement si la boutique du joueur a ses présentoirs bonus.
	-- Gate (Features.ExtraStandsGate dans ce jeu) : MonetizationService pose l'attribut Attribute du Player (true = les
	-- présentoirs DisplaySlot_21 à 20 + Stands sont utilisables : posés dans la parcelle, ou dans le Floor_2 une fois
	-- l'étage acheté, Cantin le 25/11 ; absent sinon) et RobuxShopController cache la carte sans lui (sauf gamepass
	-- possédé) ; son achat passe par le serveur (remote PromptExtraStands), qui le refuse sans lui. Gate à false : carte
	-- toujours montrée, attribut jamais posé, fenêtre d'achat ouverte par le client, comme avant.
	ExtraStands = {
		Gate = switchOn("ExtraStandsGate"),
		Attribute = "ExtraStandsReady",
	},

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
		-- a485 (L-351, V0 de Cantin du 25/11 en attendant Clément, L-415) : nom affiché de la caisse, en anglais, la seule
		-- valeur à changer : produit de la caisse et message de l'objet reçu (MonetizationService, « <nom>: you got … »).
		-- Le titre de la carte (Crate.Title de UI_RobuxShop_v2) est le texte de Clément, pas écrit par le code.
		DisplayName = "Exclusive Crate",
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
		-- a485 (L-351, rapport monetisation 6.3) : nil (avant 399, « 75% OFF ») : le pack n'a jamais été vendu 399 et Roblox
		-- interdit les remises qui ne sont pas réelles. Ne remettre un ancien prix que pour une vraie baisse de prix.
		OldPrice = nil :: number?,
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
	-- temps : un ×2 acheté pendant un ×8 commence à la fin du ×8 ; deux ×4 font 1 h de ×4 (a476 : 30 min chacun). Rien n'est sauvegardé :
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
			Queued = "%s gave the server %s LUCK for %s! Starts after the current one.",
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
	if product.RetiredTiers then -- a485 : par leur numéro d'origine (OpenNow3, OpenNow4)
		for index, tier in product.RetiredTiers do
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

-- a520 (L-410) : E sur son objet encore sous antivol propose-t-il Open Now ? Features.OpenNowOnLocked (partout) ou
-- OpenNowOnLockedDev (jeu DEV et TEST), lus à chaque appel (surcharges sans republier, Shared/LiveFeatures).
function Monetization.OpenNowOnLocked(): boolean
	local features = Features :: any
	return features.OpenNowOnLocked == true or (features.OpenNowOnLockedDev == true and ProductIds.IsDev == true)
end

-- a520 (L-410) : le palier d'Open Now que E propose pour un objet qui attend encore `remaining` s, ou nil (rien de
-- proposé) : boutique Robux allumée (Features.RobuxShop), OpenNowOnLocked, achats permis sur ce serveur (pas le jeu
-- TEST), Open Now codé (Ready) et un palier créé (Id ≠ 0) au-delà de OpenNow.MinRemaining. Même règle côté client
-- (invite) et serveur (fenêtre d'achat, MonetizationService), qui seul décide.
function Monetization.LockedSkipTier(remaining: number): OpenNowTier?
	if (Features :: any).RobuxShop ~= true or not Monetization.OpenNowOnLocked() or Monetization.PurchasesDisabled then
		return nil
	end
	local product = ProductByKey.OpenNow
	if product == nil or not product.Ready then
		return nil
	end
	local tier = Monetization.OpenNowTier(remaining)
	return if tier and tier.Id ~= 0 then tier else nil
end

-- a485 (L-351 question 2) : multiplicateur des gains du tapis venu des gamepasses ×2 Training (×4 Training) et ×2 Speed,
-- `owns(clé)` disant s'il est possédé. TrainingLadder : le plus fort des deux (×4 avec ×4 Training, ×2 avec ×2 Speed
-- seul) ; sinon leur produit, comme avant (×4 avec les deux). 1 sans gamepass. Même calcul côté serveur
-- (MonetizationService, TrainingService.GetGainMultiplier) et client (HudMenuController, pastille TrainingBoost).
local TRAINING_PASSES = { "DoubleTraining", "DoubleSpeed" }
function Monetization.TrainingMultiplier(owns: (key: string) -> boolean): number
	local result = 1
	for _, key in TRAINING_PASSES do
		if owns(key) then
			local pass = PassByKey[key]
			local value = if pass then pass.Multiplier else nil
			local factor = if type(value) == "number" and value == value and value > 0 and value < math.huge then value else 1
			result = if Monetization.TrainingLadder then math.max(result, factor) else result * factor
		end
	end
	return result
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
