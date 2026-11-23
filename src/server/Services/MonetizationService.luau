--!strict
-- MonetizationService (DEV-100) : boutique Robux, gamepasses et produits développeur (Partie 2,
-- sections 3.1 et 4 ; Partie 1, sections 7.1, 9.5 et 9.6 ; offres, prix et valeurs :
-- Config/Monetization ; écran : RobuxShopController, côté client). MAJ 1, derrière
-- Features.RobuxShop : à false (jusqu'à la MAJ 1), ce service ne branche rien (ni ProcessReceipt, ni
-- accroche, ni attribut, ni bonus Premium) et l'écrit une fois dans la sortie.
--
-- Offre active : Features.RobuxShop, Id ≠ 0 (créée sur le Creator Hub au nom du groupe du studio) et
-- Ready (effet codé). Un Id à 0 désactive l'offre sans erreur.
--
-- Produits développeur (MarketplaceService.ProcessReceipt, 9.6), achats idempotents :
--   - produit inconnu de Config/Monetization, ou pas codé (Ready = false) : NotProcessedYet, avec un
--     avertissement (on ne garde pas des Robux pour un effet qui n'existe pas) ;
--   - joueur absent du serveur, ou profil pas chargé au bout de Receipts.ProfileWait s : NotProcessedYet
--     (Roblox rappelle le reçu plus tard, au retour du joueur) ;
--   - PurchaseId déjà dans Purchases du profil : rien n'est redonné ;
--   - sinon l'achat est donné, puis le PurchaseId noté dans Purchases (= os.time()), dans la même
--     exécution, sans yield. Une erreur pendant le don est écrite dans la sortie (avec le PurchaseId,
--     pour compenser à la main) et le PurchaseId est noté quand même : jamais deux fois le même don ;
--   - dans ces deux derniers cas, PurchaseGranted seulement quand la sauvegarde contient le
--     PurchaseId (DataService.SaveAsync, Profile.LastSavedData : la façon de faire de ProfileStore) ;
--     profil fermé avant (joueur parti) : NotProcessedYet, et le reçu rappelé au retour trouvera le
--     PurchaseId dans la sauvegarde de fin de session.
--   Purchases garde au plus Receipts.History (V0 : 500) achats : les plus anciens partent.
--
-- Gamepasses : possession lue à l'arrivée (UserOwnsGamePassAsync, dans un pcall : PassCheck.Attempts
-- essais espacés de PassCheck.RetryDelay s, puis un essai toutes les PassCheck.SlowRetry s tant que
-- Roblox ne répond pas) et à la fin d'un achat (PromptGamePassPurchaseFinished, wasPurchased = true : donné
-- seulement si UserOwnsGamePassAsync le confirme, a274 / H1 ; le signal seul ne donne rien).
-- Tant que Roblox n'a pas répondu, la possession vue à la dernière session compte
-- (Monetization.Passes du profil, mis à jour à chaque réponse) : les objets des présentoirs bonus ne
-- retournent pas dans l'inventaire pendant les premières secondes. Un gamepass remboursé s'arrête à la
-- réponse suivante de Roblox ; un gamepass acheté pendant la session n'est jamais retiré.
--
-- Effets codés, par les points d'accroche des services (chacun garde l'accroche d'avant) :
--   ×2 Argent          DisplayService.GetIncomeMultiplier × 2
--   ×2 Entraînement    TrainingService.GetGainMultiplier × 2 (tapis et banc)
--   Encaissement auto  DisplayService.HasAutoCollect : la caisse se vide chaque seconde, où que soit
--                      le joueur
--   Ouverture rapide   vague 52 (a170) : plus de colis posé (a158) ; Fast Open ne raccourcit plus que
--                      l'antivol d'un objet posé au sol (voir vague 31 plus bas)
--   +4 présentoirs     DisplayService.GetExtraSlots = 4 : DisplaySlot_21 à _24, au-delà du maximum de
--                      20, s'ils sont posés dans la boutique (Clément)
--   Roblox Premium     +10 % de revenus (Player.MembershipType, relu chaque seconde) :
--                      DisplayService.GetIncomeBonus + 0,1, additionné aux autres bonus en pour cent
--                      (zones complètes de l'index, IndexService)
--   Packs d'argent     Minutes des revenus actuels, ceux du HUD, bonus compris (6 packs, de 10 min à
--                      12 h, vague 63), au moins CashPacks.MinPerMinute $ par minute (Monetization.CashPackAmount)
--   Ouvrir maintenant  un produit par palier de prix (Monetization.OpenNowTier, que l'écran choisit
--                      selon l'attente du colis qui attend le plus) ; le reçu retire jusqu'à Skip s à
--                      ce colis. Aucun colis en attente : les secondes payées vont dans
--                      Monetization.OpenNowCredit du profil, retirées des prochains colis posés
--   Vague 31 (L-112 ; décision de Cantin du 2026-11-12) : les deux mêmes achats valent pour
--                      l'antivol d'un objet posé au sol, par le même chemin : UnboxService.GetWaiting et
--                      SkipWait le comptent comme un colis en attente (Ouvrir maintenant, crédit, Fast Open à
--                      l'achat) ; Fast Open multiplie aussi UnboxService.GetAntiTheftDelay par DelayFactor
--   Pack de départ     offre unique de la 1re heure de jeu (Lifetime.PlaySeconds + la session) : boost
--                      ×2 argent 1 h (Boosts.Cash, compté seulement en jeu ; un 2e boost prolonge),
--                      Marteau (équipé s'il est plus fort que l'outil équipé), 50 000 $ ;
--                      Monetization.StarterPack = true. Racheté malgré tout (fenêtre d'achat ouverte
--                      sans l'écran) : il est redonné, avec un avertissement (le joueur a payé)
--   Chance du serveur  vague 72 (a247, L-216 point 8) : ServerLuck2, 4 et 8 : une tranche (facteur, durée) en
--                      file pour tout le serveur, annoncée à tous (Notify ServerLuck.AnnounceKind, nom de
--                      l'acheteur) ; seule la tranche au plus fort facteur tourne (la plus ancienne à égalité),
--                      les autres attendent ; attributs du Workspace ServerLuck, ServerLuckEndsAt, ServerLuckBy,
--                      lus par StoreHeistService (chance des colis) et le client. File perdue si le serveur s'arrête
-- M global des revenus (7.1) : (1 + Premium + les autres bonus en %) × ×2 Argent × boost ×2 argent.
-- V0 : les bonus en % s'additionnent entre eux (DisplayService.GetIncomeBonus : Premium ici, l'index
-- dans IndexService ; amis, groupe et VIP viendront de la même façon), les ×2 se multiplient
-- (DisplayService.GetIncomeMultiplier).
-- Télémétrie : l'argent acheté (packs, pack de départ) part en économie « Robux »
-- (TelemetryService.LogEconomy, SKU = clé du produit).
--
-- Pas codés, juste listés (Ready = false : ni affichés ni vendus) :
--   VIP                tag de chat, aura VIP, +10 % de revenus, rideau +30 s (plus de coffre-fort, vague 54) : attend
--                      l'aura VIP (Clément) et les défenses de la MAJ 2
--   Gants hydrauliques outil exclusif, puissance = 2,5 × le meilleur outil acheté : attend son modèle
--                      TOOL_ et sa règle de puissance dans ToolService
--   Vengeance          téléport derrière le voleur pendant une poursuite : règle à écrire (PvP)
--   Rideau instantané  rideau de sa boutique sans attendre la recharge : MAJ 2 (DefenseService)
--   Chance ×3          raretés boostées 15 min : cotes affichées, et offre cachée si
--                      PolicyService:GetPolicyInfoForPlayerAsync dit ArePaidRandomItemsRestricted
--   Bouclier 30 min    boutique inviolable, une fois par session : règle à écrire (PvP)
--
-- Attributs du Player, lus par l'écran (heures serveur = Workspace:GetServerTimeNow()) :
--   Pass<Clé>          true si le gamepass est possédé (PassDoubleCash…), absent sinon
--   StarterPackEndsAt  fin de l'offre du pack de départ ; absent : pas proposée (achetée, 1re heure passée)
--   CashBoostEndsAt    fin du boost ×2 argent en cours ; absent : pas de boost
--   OpenNowReadyAt     heure où le colis qui attend le plus sera prêt ; absent : aucun colis en attente
-- Le serveur ne lit jamais ces attributs : il passe par HasPass et le profil.
--
-- API (côté serveur) :
--   MonetizationService.IsEnabled() -> boolean           Features.RobuxShop
--   MonetizationService.HasPass(player, key) -> boolean  gamepass possédé (clé de Config/Monetization)
--   MonetizationService.GetIncomeMultiplier(player) -> number
--       Part de la boutique Robux dans le M global (Premium, ×2 Argent, boost) ; boutique coupée : le
--       boost seul.
--   MonetizationService.GetTemporaryIncomeMultiplier(player) -> number
--       Part temporaire de ce M global : le boost ×2 argent s'il est en cours, sinon 1. Pour les gains
--       hors ligne (DEV-102, OfflineService), qui ne comptent pas les boosts.
--   MonetizationService.AddCashBoost(player, seconds) -> boolean
--       Boost ×2 argent : prolonge celui en cours de `seconds` (pour les récompenses, DEV-101) ; false
--       si le profil n'est pas chargé ou la durée invalide. Sans yield.
--   MonetizationService.StartGiftReveal(player, itemId, startRarity?, chance?, effect?) -> boolean
--       a309 (Cantin, 22/11) : la scène d'ouverture de la caisse exclusive (Crate.Reveal, mêmes règles) pour un
--       colis offert déjà donné (paliers de temps de jeu, RewardService) ; true si elle est lancée. Sans yield.
--
-- Boutique coupée (Features.RobuxShop = false) : ni reçu, ni gamepass, ni bonus Premium, ni pack de
-- départ, ni Ouvrir maintenant, ni crochet de test. Seul le boost ×2 argent reste branché (DEV-101, les
-- récompenses quotidiennes et de temps de jeu le donnent, Partie 2, 3.3) : temps restant gardé dans
-- Boosts.Cash, compté seulement en jeu, attribut CashBoostEndsAt, ×2 dans DisplayService.GetIncomeMultiplier.
--
-- Crochet de test, STUDIO SEULEMENT (Ids encore à 0 : aucun achat réel possible) :
-- workspace:SetAttribute("MonetizationTest", "<joueur> <Clé>") (barre de commande serveur ; joueur =
-- nom ou UserId). Une clé de gamepass le donne pour la session, comme un achat ; une clé de produit
-- (OpenNow1 à OpenNow4 pour un palier d'Ouvrir maintenant) passe par le même don qu'un reçu, avec un
-- faux PurchaseId « STUDIO-<GUID du Play>-n » (a297 : unique d'un Play à l'autre, le profil DEV garde ses
-- Purchases). Hors de Studio, l'attribut n'est pas écouté.
-- a285 (21/11) : Crate1, Crate3 et Crate10 pour un lot de la caisse exclusive, avec Features.RobuxCrate, même
-- quand la boutique est coupée (seules ces clés sont alors acceptées).
--
-- Caisse exclusive (a285, L-247, L-252) : un produit par lot (Monetization.Crate.Packs, x1, x3, x10), vendu avec
-- Crate.Ready et Features.RobuxCrate. Le reçu fait Count tirages selon Crate.Odds parmi Crate.Items (objets
-- Exclusive_* de Config/Items, hors colis et hors index) ; chaque objet entre dans l'inventaire (Items du profil,
-- même au-delà de sa place : Crate.IgnoreInventoryMax) et un message le nomme. Même chemin idempotent que les
-- autres produits (PurchaseId noté avec le don, sauvegarde attendue).
-- a294 (21/11, Cantin) : vendue quand Monetization.Crate.Live et Ready (Features.RobuxCrate partout, ou RobuxCrateDev
-- dans le jeu DEV), même boutique coupée : ProcessReceipt est alors branché pour les seuls lots de la caisse (tout
-- autre reçu : NotProcessedYet). Ouverture (Crate.Reveal, V0 de Cantin) : après le don, RevealStarted à tous avec un
-- plan tiré ici (Shared/UnboxPlan : nombre de coups de la rareté tirée, cote finale = 100 / sa chance), pour l'objet le
-- plus rare du lot, colis posé devant l'acheteur (ShopId Crate.Reveal.ShopId : aucun magasin) ; acheteur immobilisé
-- (StatsService, clé CrateReveal) et protégé (attribut RevealProtected) jusqu'à son RevealDone, sa mort, son départ
-- ou le plafond UnboxPlan.serverMaxSeconds, puis RevealEnded à tous. Hors zone safe (Crate.Reveal.SafeZoneOnly), ou
-- pendant une autre cinématique : objets donnés sans ouverture.
-- a297 (21/11) : avec une ouverture, les messages « you got … » partent à sa fin (avec RevealEnded, quelle qu'en soit la
-- cause ; joueur parti : aucun), sans celui de l'objet montré ; sans ouverture, tous tout de suite. Le don ne bouge pas.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage.Shared
local Features = require(Shared.Config.Features)
local Items = require(Shared.Config.Items)
local Monetization = require(Shared.Config.Monetization)
local Rarities = require(Shared.Config.Rarities)
local Tools = require(Shared.Config.Tools)
local Format = require(Shared.Format)
local Net = require(Shared.Net.Net)
local Announce = require(Shared.Announce) -- a254 (L-240 point 3)
local ProfileTypes = require(Shared.Types.Profile)

local DataService = require(script.Parent.DataService)
local DisplayService = require(script.Parent.DisplayService)
local ShopService = require(script.Parent.ShopService)
local TelemetryService = require(script.Parent.TelemetryService)
local ToolService = require(script.Parent.ToolService)
local TrainingService = require(script.Parent.TrainingService)
local UnboxService = require(script.Parent.UnboxService)

type Data = ProfileTypes.Data
type MonetizationData = ProfileTypes.Monetization
type Pass = Monetization.Pass
type Product = Monetization.Product
type Tier = Monetization.OpenNowTier
type CratePack = Monetization.CratePack

-- Un produit développeur en vente : le produit, et son palier pour Ouvrir maintenant ; a285 : le lot de la
-- caisse exclusive (product = CRATE_PRODUCT).
type Sale = { product: Product, tier: Tier?, pack: CratePack? }

-- Ce que ce service sait d'un joueur présent.
type State = {
	known: { [string]: boolean }, -- [clé] = true : Roblox a répondu (ou achat pendant la session)
	owned: { [string]: boolean }, -- [clé] = true : possédé, d'après cette réponse
	bought: { [string]: boolean }, -- [clé] = true : acheté pendant la session (jamais retiré)
	sessionStart: number?, -- os.time() du chargement du profil
	boostUntil: number?, -- os.clock() de fin du boost ×2 argent
	boostEndsAt: number?, -- heure serveur de fin du boost (attribut CashBoostEndsAt)
	starterEndsAt: number?, -- heure serveur de fin de l'offre (attribut StarterPackEndsAt)
}

local IS_STUDIO = RunService:IsStudio()

-- Attributs du Player (voir l'en-tête ; mêmes noms dans RobuxShopController).
local PASS_ATTRIBUTE_PREFIX = "Pass"
local STARTER_ATTRIBUTE = "StarterPackEndsAt"
local BOOST_ATTRIBUTE = "CashBoostEndsAt"
local OPEN_NOW_ATTRIBUTE = "OpenNowReadyAt"
-- Attribut du Workspace du crochet de test (Studio seulement).
local TEST_ATTRIBUTE = "MonetizationTest"
-- V0 proposé, absent du doc : cadence (s) du suivi des boosts, de l'offre et des attributs.
local TICK = 1

-- Messages lus par le joueur (Notify « Info »), en anglais (L-036). V0 proposés, absents du doc.
local MESSAGES = {
	PassUnlocked = "%s unlocked!",
	FastOpen = "Fast Open: anti-theft 2× shorter!",
	CashPack = "+%s added to your cash!",
	-- Vague 53 : plus de colis en base, ces textes parlent aussi de l'antivol d'un objet (V0, anglais).
	OpenNowReady = "Your item is UNLOCKED!",
	OpenNowShorter = "Your item's anti-theft is %s shorter!",
	OpenNowCredit = "No item is waiting: Open Now will speed up your next anti-theft.",
	OpenNowCreditUsed = "Open Now: your new item's anti-theft is %s shorter!",
	-- Vague 31 (L-112, Cantin 2026-11-12) : les mêmes achats sur l'antivol d'un objet posé au sol.
	OpenNowUnlocked = "Anti-theft removed: your item is UNLOCKED!",
	OpenNowShorterItem = "Your item's anti-theft is %s shorter!",
	OpenNowCreditUsedItem = "Open Now: your new item's anti-theft is %s shorter!",
	StarterPack = "Starter Pack: +%s, a Hammer and ×2 Cash for 1 hour!",
	-- a285 (21/11) : un message par objet sorti de la caisse exclusive (rareté, nom). V0 proposé, absent du doc.
	CrateItem = "Exclusive Crate: you got a %s %s!",
}

local MonetizationService = {}
-- Après les services dont il remplace les accroches (100) ; avant TutorialService (200) et
-- TelemetryService (210).
MonetizationService.Priority = 150

local enabled = false
local states: { [Player]: State } = {}
local passesById: { [number]: Pass } = {}
local salesById: { [number]: Sale } = {}
local testCount = 0
-- a297 (21/11) : un GUID par Play pour le faux PurchaseId du crochet de test (« STUDIO-<GUID>-n ») : le profil DEV garde
-- ses Purchases d'un Play à l'autre, un compteur seul retombait sur un ancien reçu (déjà donné, rien de plus).
local testSession: string? = nil

-- a285 (21/11) : la caisse exclusive, vendue comme un produit (un Id par lot, Monetization.Crate.Packs). En vente
-- seulement si son don est codé (Crate.Ready) et Features.RobuxCrate. a294 : et Crate.Live (DEV : RobuxCrateDev).
local CRATE = Monetization.Crate
local CRATE_PRODUCT: Product = {
	Key = "Crate",
	Tab = "Offers",
	Order = 0,
	DisplayName = "Exclusive Crate",
	Effect = "",
	Icon = "",
	Price = CRATE.UnitPrice,
	Id = 0, -- inutilisé : un Id par lot
	Ready = CRATE.Ready == true and CRATE.Live == true, -- a294 : don codé et caisse allumée dans ce jeu
}
local crateRandom = Random.new()
-- Vague 72 (a247) : file des tranches de chance du serveur (voir Monetization.ServerLuck).
type LuckSlice = { multiplier: number, remaining: number, by: string }
local luckQueue: { LuckSlice } = {}
local luckClock: number? = nil -- os.clock() du dernier décompte ; nil file vide

------------------------------------------------------------------------------
-- Outils
------------------------------------------------------------------------------

local function log(message: string)
	if IS_STUDIO then
		print(`[MonetizationService] {message}`)
	end
end

local function notify(player: Player, message: string)
	local ok, err = pcall(function()
		Net.Server.Notify:Fire(player, message, "Info")
	end)
	if not ok then
		warn(`[MonetizationService] Notify vers {player.Name} : {err}`)
	end
end

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

-- « 1:00 », « 7:30 » : une durée d'attente, comme le minuteur des colis.
local function duration(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function setAttribute(player: Player, name: string, value: any)
	if player.Parent == Players and player:GetAttribute(name) ~= value then
		player:SetAttribute(name, value)
	end
end

-- Tables v3 du profil (DataService) ; nil si le profil est absent ou abîmé.
local function monetizationOf(data: Data?): MonetizationData?
	local value = if data then (data :: any).Monetization else nil
	return if type(value) == "table" then value else nil
end

local function boostsOf(data: Data?): ProfileTypes.Boosts?
	local value = if data then (data :: any).Boosts else nil
	return if type(value) == "table" then value else nil
end

local function finite(value: any): number
	return if type(value) == "number" and value == value and math.abs(value) < math.huge then value else 0
end

------------------------------------------------------------------------------
-- Gamepasses
------------------------------------------------------------------------------

local function hasPass(player: Player, key: string): boolean
	if not enabled then
		return false
	end
	local state = states[player]
	if state and state.known[key] then
		return state.owned[key] == true
	end
	-- Roblox n'a pas encore répondu : la possession vue à la dernière session.
	local monetization = monetizationOf(DataService.Get(player))
	local cache = if monetization then (monetization :: any).Passes else nil
	return type(cache) == "table" and cache[key] == true
end

local function passValue(key: string, field: "Multiplier" | "DelayFactor" | "Stands", default: number): number
	local pass = Monetization.PassByKey[key]
	local value = if pass then (pass :: any)[field] else nil
	return if type(value) == "number" then value else default
end

-- Garde la possession dans le profil (cache de la prochaine arrivée).
local function writeCache(player: Player, key: string, owned: boolean)
	local monetization = monetizationOf(DataService.Get(player))
	if monetization == nil then
		return
	end
	local raw = monetization :: any
	if type(raw.Passes) ~= "table" then
		raw.Passes = {}
	end
	raw.Passes[key] = if owned then true else nil
end

local function publishPass(player: Player, key: string)
	setAttribute(player, PASS_ATTRIBUTE_PREFIX .. key, if hasPass(player, key) then true else nil)
end

-- Note la réponse de Roblox (ou un achat) pour `pass`.
local function setOwned(player: Player, pass: Pass, owned: boolean, why: string)
	local state = states[player]
	if state == nil or (not owned and state.bought[pass.Key]) then
		return -- acheté pendant la session : une réponse plus ancienne ne le retire pas
	end
	local before = hasPass(player, pass.Key)
	state.known[pass.Key] = true
	state.owned[pass.Key] = owned
	writeCache(player, pass.Key, owned)
	publishPass(player, pass.Key)
	if before ~= owned then
		log(`{player.Name} : gamepass {pass.Key} {if owned then "possédé" else "pas possédé"} ({why})`)
	end
end

-- Lit la possession de chaque gamepass créé (Id ≠ 0), avec nouvel essai (voir l'en-tête). Yield.
local function checkPasses(player: Player)
	if player.UserId <= 0 then
		log(`{player.Name} : joueur de test local de Studio (UserId {player.UserId}) : gamepasses pas lus`)
		return
	end
	local pending: { Pass } = {}
	for _, pass in Monetization.Passes do
		if pass.Id ~= 0 then
			table.insert(pending, pass)
		end
	end
	local check = Monetization.PassCheck
	local attempt = 0
	while #pending > 0 and player.Parent == Players do
		attempt += 1
		for index = #pending, 1, -1 do
			local pass = pending[index]
			local ok, owns = pcall(function(): boolean
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
			end)
			if player.Parent ~= Players then
				return
			end
			if ok then
				table.remove(pending, index)
				setOwned(player, pass, owns == true, "réponse de Roblox à l'arrivée")
			end
		end
		if #pending > 0 then
			if attempt == check.Attempts then
				local names: { string } = {}
				for _, pass in pending do
					table.insert(names, pass.Key)
				end
				warn(
					`[MonetizationService] {player.Name} : Roblox ne répond pas pour {table.concat(names, ", ")} : possession de la dernière session gardée, nouvel essai toutes les {check.SlowRetry} s`
				)
			end
			task.wait(if attempt < check.Attempts then check.RetryDelay else check.SlowRetry)
		end
	end
end

------------------------------------------------------------------------------
-- Revenus, boost et offre du pack de départ
------------------------------------------------------------------------------

local function boostActive(player: Player): boolean
	local state = states[player]
	local untilClock = if state then state.boostUntil else nil
	return untilClock ~= nil and untilClock > os.clock()
end

-- Bonus en pour cent de la boutique Robux (fraction) : Roblox Premium. Additionné aux autres bonus en %
-- (DisplayService.GetIncomeBonus), pas multiplié.
local function incomeBonus(player: Player): number
	if enabled and player.MembershipType == Enum.MembershipType.Premium then
		return Monetization.Premium.IncomeBonus
	end
	return 0
end

-- Multiplicateurs de la boutique Robux : ×2 Argent, boost ×2 argent (DisplayService.GetIncomeMultiplier).
-- Boutique coupée : hasPass répond toujours non, seul le boost compte (DEV-101).
local function incomeMultiplier(player: Player): number
	local multiplier = 1
	if hasPass(player, "DoubleCash") then
		multiplier *= passValue("DoubleCash", "Multiplier", 1)
	end
	if boostActive(player) then
		multiplier *= Monetization.CashBoost.Multiplier
	end
	return multiplier
end

-- Prolonge le boost ×2 argent de `seconds` : état, profil (Boosts.Cash) et attribut. Sans yield.
local function addBoost(player: Player, seconds: number): boolean
	local state = states[player]
	local boosts = boostsOf(DataService.Get(player))
	if state == nil or boosts == nil or finite(seconds) <= 0 then
		return false
	end
	local now = os.clock()
	local from = state.boostUntil
	state.boostUntil = (if from and from > now then from else now) + seconds
	local left = (state.boostUntil :: number) - now
	boosts.Cash = left
	state.boostEndsAt = serverNow() + left
	setAttribute(player, BOOST_ATTRIBUTE, state.boostEndsAt)
	return true
end

local function playSeconds(data: Data, state: State): number
	local lifetime = (data :: any).Lifetime
	local before = if type(lifetime) == "table" then finite(lifetime.PlaySeconds) else 0
	local started = state.sessionStart
	return before + (if started then math.max(0, os.time() - started) else 0)
end

-- Secondes restantes de l'offre du pack de départ (0 : pas proposée).
local function starterLeft(data: Data, state: State): number
	local monetization = monetizationOf(data)
	if monetization == nil or monetization.StarterPack == true then
		return 0
	end
	return math.max(0, Monetization.StarterPack.Window - playSeconds(data, state))
end

local function clearStarterOffer(player: Player, state: State)
	state.starterEndsAt = nil
	setAttribute(player, STARTER_ATTRIBUTE, nil)
end

-- Colis qui attend le plus : uid du colis posé au sol (L-089) et heure serveur où il sera prêt.
local function longestWait(player: Player): (string?, number?)
	local bench: string?, latest: number? = nil, nil
	for boxUid, readyAt in UnboxService.GetWaiting(player) do
		if latest == nil or readyAt > latest or (readyAt == latest and boxUid < (bench :: string)) then
			bench, latest = boxUid, readyAt
		end
	end
	return bench, latest
end

-- Une fois par seconde : boost (profil et attribut), fin de l'offre, colis qui attend le plus.
local function tickPlayer(player: Player, state: State)
	local data = DataService.Get(player)
	if data == nil then
		return
	end
	local untilClock = state.boostUntil
	if untilClock then
		local left = math.max(0, untilClock - os.clock())
		local boosts = boostsOf(data)
		if boosts then
			boosts.Cash = left
		end
		if left <= 0 then
			state.boostUntil = nil
			state.boostEndsAt = nil
			setAttribute(player, BOOST_ATTRIBUTE, nil)
			log(`{player.Name} : boost ×2 argent fini`)
		end
	end
	if not enabled then
		return -- boutique coupée : le boost seul (voir l'en-tête)
	end
	local endsAt = state.starterEndsAt
	if endsAt and (serverNow() >= endsAt or starterLeft(data, state) <= 0) then
		clearStarterOffer(player, state)
	end
	local _, latest = longestWait(player)
	setAttribute(player, OPEN_NOW_ATTRIBUTE, latest)
end

------------------------------------------------------------------------------
-- Dons des produits (reçus)
------------------------------------------------------------------------------

-- a285 (21/11) : caisse exclusive --------------------------------------------------------------------

-- Ce qui empêche de tirer la caisse (Config mal réglée), ou nil.
local function crateProblem(): string?
	if #CRATE.Items == 0 or #CRATE.Items ~= #CRATE.Odds then
		return `caisse exclusive mal réglée ({#CRATE.Items} objet(s) pour {#CRATE.Odds} chance(s))`
	end
	local total = 0
	for index, id in CRATE.Items do
		if Items.ById[id] == nil then
			return `objet {id} de la caisse exclusive inconnu de Config/Items`
		end
		local odds = finite(CRATE.Odds[index])
		if odds < 0 then
			return `chance négative pour {id}`
		end
		total += odds
	end
	if total <= 0 then
		return "caisse exclusive sans chance"
	end
	return nil
end

-- Un tirage de la caisse : un ItemId, chacun avec sa chance (Odds, en %, total quelconque).
local function drawCrate(): string
	local total = 0
	for index in CRATE.Items do
		total += math.max(finite(CRATE.Odds[index]), 0)
	end
	local roll = crateRandom:NextNumber() * total
	for index, id in CRATE.Items do
		local odds = math.max(finite(CRATE.Odds[index]), 0)
		if roll < odds then
			return id
		end
		roll -= odds
	end
	return CRATE.Items[#CRATE.Items] -- arrondi des nombres à virgule
end

-- a285 : barre d'inventaire remise à jour tout de suite après la caisse, si InventoryService est là (chargé au
-- premier don, comme DisplayService le fait : pas de require croisé au chargement ; sans lui, sa boucle suit).
type InventoryApi = { Refresh: (player: Player) -> () }
local inventoryApi: InventoryApi? = nil
local inventoryTried = false
local function refreshInventory(player: Player)
	if not inventoryTried then
		inventoryTried = true
		local inventoryModule = script.Parent:FindFirstChild("InventoryService")
		if inventoryModule and inventoryModule:IsA("ModuleScript") then
			local ok, result = pcall(require, inventoryModule)
			if ok and type(result) == "table" then
				inventoryApi = result :: any
			end
		end
	end
	local api = inventoryApi
	if api then
		local ok, err = pcall(api.Refresh :: any, player) -- :: any : comme DisplayService (ancien solveur et pcall)
		if not ok then
			warn(`[MonetizationService] {player.Name} : inventaire pas rafraîchi après la caisse ({err})`)
		end
	end
end

-- a294 (21/11, V0 de Cantin) : ouverture de la caisse (Crate.Reveal ; voir l'en-tête) ---------------------------

-- a297 : pending = objets du lot sans l'objet montré, dont les messages partent à la fin de l'ouverture (avec RevealEnded) ;
-- got = la liste du don (pour savoir, après une erreur, si l'ouverture a bien démarré).
type CrateReveal = {
	id: string,
	player: Player,
	ended: boolean,
	died: RBXScriptConnection?,
	pending: { string },
	got: { string },
	of: string, -- a309 : « de la caisse » ou « du colis offert » (sortie)
}
local crateReveals: { [string]: CrateReveal } = {} -- [RevealId]
local crateRevealOf: { [Player]: CrateReveal } = {}
local crateRevealCount = 0
local CRATE_SPEED_KEY = "CrateReveal" -- clé de StatsService.SetSpeedModifier (StoreHeistService : « Reveal »)
-- Shared/ShelfOpenState.ProtectedAttribute, lu sans require comme GuardService et BatService (vigiles figés, ni batte ni
-- capture pour lui).
local PROTECTED_ATTRIBUTE = "RevealProtected"

-- Module chargé à la première ouverture (pas de require croisé au chargement ; absent d'un arbre de banc : nil).
local lazyModules: { [string]: any } = {}
local function lazy(key: string, parent: Instance?, name: string): any
	if lazyModules[key] == nil then
		local module = if parent then parent:FindFirstChild(name) else nil
		local loaded: any = false
		if module and module:IsA("ModuleScript") then
			local ok, result = pcall(require, module)
			if ok and type(result) == "table" then
				loaded = result
			end
		end
		lazyModules[key] = loaded
	end
	local value = lazyModules[key]
	return if value == false then nil else value
end

local function fireRevealRemote(name: string, ...: any)
	local ok, err = pcall(function(...: any)
		(Net.Server :: any)[name]:FireAll(...)
	end, ...)
	if not ok then
		warn(`[MonetizationService] Net.Server.{name}:FireAll : {err}`)
	end
end

local function setRevealHold(player: Player, on: boolean)
	pcall(function()
		player:SetAttribute(PROTECTED_ATTRIBUTE, if on then true else nil)
	end)
	local stats = lazy("StatsService", script.Parent, "StatsService")
	if stats and type(stats.SetSpeedModifier) == "function" then
		local ok, err = pcall(stats.SetSpeedModifier, player, CRATE_SPEED_KEY, if on then 0 else nil)
		if not ok then
			warn(`[MonetizationService] StatsService.SetSpeedModifier({player.Name}, {CRATE_SPEED_KEY}) : {err}`)
		end
	end
end

-- a297 : un message « you got … » par objet de `ids`, seulement si le joueur est encore là.
local function notifyCrateItems(player: Player, ids: { string })
	if player.Parent ~= Players then
		return
	end
	for _, id in ids do
		local def = Items.ById[id]
		local rarity = if def then Rarities.ById[def.Rarity] else nil
		notify(player, string.format(MESSAGES.CrateItem, if rarity then rarity.DisplayNameUpper else "?", if def then def.DisplayName else id))
	end
end

local function finishCrateReveal(reveal: CrateReveal, why: string)
	if reveal.ended then
		return
	end
	reveal.ended = true
	crateReveals[reveal.id] = nil
	if crateRevealOf[reveal.player] == reveal then
		crateRevealOf[reveal.player] = nil
	end
	local died = reveal.died
	if died then
		died:Disconnect()
	end
	setRevealHold(reveal.player, false)
	fireRevealRemote("RevealEnded", reveal.id)
	-- a297 : les messages des objets non montrés, au même moment (joueur parti : aucun, voir notifyCrateItems).
	local pending = reveal.pending
	reveal.pending = {}
	notifyCrateItems(reveal.player, pending)
	log(`{reveal.player.Name} : ouverture {reveal.id} {reveal.of} finie ({why}), {#pending} message(s)`)
end

-- L'objet joué d'un lot : le plus rare (le premier à rareté égale) ; et sa case (index dans Crate.Items).
local function crateRevealPick(got: { string }): (string?, number?)
	local best: string? = nil
	local bestOrder = -1
	for _, id in got do
		local def = Items.ById[id]
		local rarity = if def then Rarities.ById[def.Rarity] else nil
		local order = if rarity then rarity.Order else 0
		if order > bestOrder then
			best, bestOrder = id, order
		end
	end
	return best, if best then table.find(CRATE.Items, best) else nil
end

-- Cote finale « 1 IN N » de la case `index` : 1 / sa chance (Odds sur leur total), arrondie comme celle d'un colis.
local function crateOdds(index: number): number?
	local total = 0
	for slot in CRATE.Items do
		total += math.max(finite(CRATE.Odds[slot]), 0)
	end
	local odds = math.max(finite(CRATE.Odds[index]), 0)
	if total <= 0 or odds <= 0 then
		return nil
	end
	local formulas = lazy("Formulas", Shared.Config, "Formulas")
	if formulas and type(formulas.UnboxOdds) == "function" then
		return (formulas.UnboxOdds :: any)(odds / total)
	end
	return math.max(math.floor(total / odds + 0.5), 1)
end

-- Ouverture de l'objet `itemId` devant `player` (règles de Crate.Reveal) : `got` = les objets du don (messages des
-- autres à la fin, a297), `startRarity` = rareté montrée sur le colis au départ, `odds` = cote finale « 1 IN N » (nil :
-- tirée dans la plage de la rareté), `effect` = l'effet de l'objet (mutation), `kind` = « Crate » (la caisse) ou « Gift »
-- (a309 : colis offert), début du RevealId. Rend la raison pour laquelle rien n'est joué, ou nil quand elle est lancée.
local function startReveal(
	player: Player,
	got: { string },
	itemId: string,
	startRarity: string?,
	odds: number?,
	effect: string?,
	kind: string -- "Crate" ou "Gift"
): string?
	local config = CRATE.Reveal
	if config.Enabled ~= true or Features.SingleBoxReveal ~= true then
		return "ouverture coupée"
	end
	if player.Parent ~= Players then
		return "joueur parti"
	end
	local def = Items.ById[itemId]
	if def == nil then
		return "objet inconnu"
	end
	local why: string? = nil
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid == nil or humanoid.Health <= 0 then
		why = "personnage absent ou mort"
	elseif player:GetAttribute(PROTECTED_ATTRIBUTE) == true and crateRevealOf[player] == nil then
		why = "autre cinématique en cours"
	elseif config.SafeZoneOnly == true then
		local safeZone = lazy("SafeZone", Shared, "SafeZone")
		if safeZone == nil or not safeZone.ContainsPlayer(player) then
			why = "hors zone safe"
		end
	end
	local plans = lazy("UnboxPlan", Shared, "UnboxPlan")
	if why == nil and plans == nil then
		why = "Shared/UnboxPlan absent"
	end
	local plan: string? = nil
	local maxSeconds = 0
	if why == nil then
		plan = plans.draw(def.Rarity, function(n: number): number
			return 1 + math.floor(crateRandom:NextNumber() * n)
		end, startRarity or config.StartRarity, 0, odds)
		local parsed = plans.parse(plan)
		if parsed == nil then
			why = "plan impossible"
		else
			maxSeconds = plans.serverMaxSeconds(def.Rarity, "Small", #parsed.Steps)
		end
	end
	if why then
		log(`{player.Name} : {if kind == "Crate" then "caisse" else "colis offert"} sans ouverture ({why}) : {itemId}`)
		return why
	end
	local previous = crateRevealOf[player]
	if previous then
		finishCrateReveal(previous, if kind == "Crate" then "nouvelle caisse" else "nouveau colis offert")
	end
	local weightModule = lazy("ItemWeight", Shared, "ItemWeight")
	local weight = if weightModule then weightModule.Effective(nil, nil) else 10
	local scale = if weightModule then weightModule.ScaleFor(weight) else 1
	crateRevealCount += 1
	-- a297 : l'objet montré n'a pas de message (une seule occurrence retirée : un doublon du lot garde le sien).
	local pending = table.clone(got)
	local shownAt = table.find(pending, itemId)
	if shownAt then
		table.remove(pending, shownAt)
	end
	local reveal: CrateReveal = {
		id = `{kind}{crateRevealCount}`,
		player = player,
		ended = false,
		died = nil,
		pending = pending,
		got = got,
		of = if kind == "Crate" then "de la caisse" else "du colis offert",
	}
	crateReveals[reveal.id] = reveal
	crateRevealOf[player] = reveal
	setRevealHold(player, true)
	if humanoid then
		reveal.died = humanoid.Died:Connect(function()
			finishCrateReveal(reveal, "mort")
		end)
		-- L'outil de l'action va dans la main droite (comme pour un colis de rayon).
		pcall(function()
			(humanoid :: Humanoid):UnequipTools()
		end)
	end
	fireRevealRemote(
		"RevealStarted",
		player,
		config.ShopId,
		config.SlotName,
		itemId,
		def.Rarity,
		string.sub(effect or "", 1, 32),
		math.clamp(weight, 0, 1_000_000),
		math.clamp(scale, 0, 100),
		"Small",
		reveal.id,
		plan
	)
	task.delay(maxSeconds, function()
		finishCrateReveal(reveal, "plafond de temps")
	end)
	log(`{player.Name} : ouverture {reveal.id} : {itemId} ({def.Rarity}), plan {plan}, {maxSeconds} s au plus`)
	return nil
end

-- L'ouverture d'un lot de la caisse : l'objet le plus rare, sa cote dans la caisse, la rareté de départ de Crate.Reveal.
local function startCrateReveal(player: Player, got: { string }): string?
	local config = CRATE.Reveal
	if config.Enabled ~= true or Features.SingleBoxReveal ~= true then
		return "ouverture coupée"
	end
	if player.Parent ~= Players then
		return "joueur parti"
	end
	local itemId, index = crateRevealPick(got)
	if itemId == nil or index == nil or Items.ById[itemId] == nil then
		return "aucun objet de la caisse"
	end
	return startReveal(player, got, itemId, config.StartRarity, crateOdds(index), nil, "Crate")
end

-- RevealDone(revealId) de l'acheteur : la fin de son ouverture (celles des colis de rayon : StoreHeistService).
local function onCrateRevealDone(player: Player, revealId: any)
	local reveal = if type(revealId) == "string" then crateReveals[revealId] else nil
	if reveal and reveal.player == player then
		finishCrateReveal(reveal, "RevealDone")
	end
end

local function newItemUid(list: { [string]: any }): string
	local uid = HttpService:GenerateGUID(false)
	while list[uid] ~= nil do
		uid = HttpService:GenerateGUID(false)
	end
	return uid
end

-- Count tirages, un objet par tirage dans l'inventaire (sans mutation ni zone ; poids rempli au chargement par
-- DataService, comme un objet ancien). Sans yield. Au-delà de la place de l'inventaire : donnés quand même (le
-- joueur a payé, Crate.IgnoreInventoryMax ; la ligne « donné » de processSale liste les objets).
local function grantCrate(player: Player, data: Data, pack: CratePack): string
	local items = (data :: any).Items :: { [string]: any }
	local now = os.time()
	local got: { string } = {}
	for _ = 1, pack.Count do
		local id = drawCrate()
		items[newItemUid(items)] = { Id = id, Source = "NPC", At = now }
		table.insert(got, id)
	end
	refreshInventory(player)
	-- a294 : l'ouverture, après le don (hors de son exécution sans yield ; une erreur n'enlève rien au don).
	-- a297 : avec une ouverture, les messages attendent sa fin (finishCrateReveal), sans celui de l'objet montré ; sans
	-- ouverture (hors zone safe, coupée, erreur), tous les messages tout de suite.
	task.defer(function()
		local ok, result = pcall(startCrateReveal, player, got)
		if not ok then
			warn(`[MonetizationService] {player.Name} : ouverture de la caisse impossible ({result}), objets donnés quand même`)
		end
		local current = crateRevealOf[player]
		local started = current ~= nil and current.got == got
		if not started then
			notifyCrateItems(player, got)
		end
	end)
	return `caisse ×{pack.Count} : {table.concat(got, ", ")}`
end

-- Raison pour laquelle le profil ne peut pas recevoir ce produit maintenant (rien n'est alors noté),
-- ou nil.
local function cannotGrant(player: Player, data: Data, sale: Sale): string?
	local key = sale.product.Key
	if key == "StarterPack" then
		if monetizationOf(data) == nil or boostsOf(data) == nil then
			return "profil sans Monetization ou Boosts"
		end
		if Tools.ById[Monetization.StarterPack.Tool] == nil then
			return `outil {Monetization.StarterPack.Tool} inconnu de Config/Tools`
		end
	elseif key == "OpenNow" then
		if sale.tier == nil then
			return "palier d'Ouvrir maintenant inconnu"
		end
		if monetizationOf(data) == nil then
			return "profil sans Monetization"
		end
	elseif key == "Crate" then
		local pack = sale.pack
		if pack == nil or type(pack.Count) ~= "number" or pack.Count < 1 or pack.Count ~= math.floor(pack.Count) then
			return "lot de la caisse exclusive inconnu"
		end
		if type((data :: any).Items) ~= "table" then
			return "profil sans Items"
		end
		local problem = crateProblem()
		if problem then
			return problem
		end
		if not CRATE.IgnoreInventoryMax and not DisplayService.HasInventoryRoom(player) then
			return "inventaire plein"
		end
	elseif sale.product.Luck ~= nil then
		local minutes = finite(sale.product.LuckMinutes)
		if finite(sale.product.Luck) < 1 or minutes <= 0 then
			return "chance du serveur mal réglée (Luck ≥ 1, LuckMinutes > 0)"
		end
	elseif sale.product.Minutes == nil then
		return `pas de don codé pour {key}`
	end
	return nil
end

-- Vague 72 (a247) : chance du serveur ------------------------------------------------------------------

-- Tranche qui tourne : le plus fort facteur, la plus ancienne à égalité.
local function activeLuck(): number?
	local best: number? = nil
	for index, slice in luckQueue do
		if best == nil or slice.multiplier > luckQueue[best].multiplier then
			best = index
		end
	end
	return best
end

-- Décompte le temps écoulé sur la tranche qui tourne (puis la suivante, si elle finit).
local function advanceLuck()
	local now = os.clock()
	local elapsed = if luckClock then now - luckClock else 0
	luckClock = if #luckQueue > 0 then now else nil
	while elapsed > 0 do
		local index = activeLuck()
		if index == nil then
			break
		end
		local slice = luckQueue[index]
		local used = math.min(elapsed, slice.remaining)
		slice.remaining -= used
		elapsed -= used
		if slice.remaining <= 1e-6 then
			table.remove(luckQueue, index)
			log(`chance du serveur ×{slice.multiplier} de {slice.by} finie ({#luckQueue} tranche(s) en attente)`)
		end
	end
	if #luckQueue == 0 then
		luckClock = nil
	end
end

-- Attributs du Workspace (Monetization.ServerLuck) ; la fin n'est réécrite que si elle bouge de plus d'1/2 s.
local function publishLuck()
	local config = Monetization.ServerLuck
	local index = activeLuck()
	local slice = if index then luckQueue[index] else nil
	if slice == nil then
		Workspace:SetAttribute(config.Attribute, nil)
		Workspace:SetAttribute(config.EndsAtAttribute, nil)
		Workspace:SetAttribute(config.ByAttribute, nil)
		return
	end
	local left = 0
	for _, other in luckQueue do
		if other.multiplier == slice.multiplier then
			left += other.remaining
		end
	end
	local endsAt = serverNow() + left
	local shown = Workspace:GetAttribute(config.EndsAtAttribute)
	if Workspace:GetAttribute(config.Attribute) ~= slice.multiplier or type(shown) ~= "number" or math.abs(shown - endsAt) > 0.5 then
		Workspace:SetAttribute(config.EndsAtAttribute, endsAt)
	end
	Workspace:SetAttribute(config.Attribute, slice.multiplier)
	Workspace:SetAttribute(config.ByAttribute, slice.by)
end

local function grantServerLuck(player: Player, product: Product): string
	local config = Monetization.ServerLuck
	local multiplier = product.Luck :: number
	local minutes = product.LuckMinutes :: number
	advanceLuck()
	local index = activeLuck()
	local running = if index then luckQueue[index].multiplier else nil
	table.insert(luckQueue, { multiplier = multiplier, remaining = minutes * 60, by = player.DisplayName })
	luckClock = luckClock or os.clock()
	publishLuck()
	local label, length = `×{multiplier}`, `{minutes} min`
	local message = if running and running > multiplier
		then string.format(config.Messages.Queued, player.DisplayName, label, length, `×{running}`)
		else string.format(config.Messages.Started, player.DisplayName, label, length)
	local queued = if running and running > multiplier then running else nil
	Announce.serverLuck(player, multiplier, minutes, queued, product.Icon, message) -- a254 : UI_Announce (Notify si coupé)
	return `chance du serveur {label} {length}{if running and running > multiplier then ` en attente derrière ×{running}` else ""} ({#luckQueue} tranche(s))`
end

-- Donne l'outil et l'équipe s'il est plus fort que l'outil équipé (même règle que la boutique d'armes).
local function giveTool(player: Player, toolId: string): string
	if not ToolService.Grant(player, toolId) then
		return `{toolId} refusé par ToolService`
	end
	local tool = Tools.ById[toolId]
	local equippedId = ToolService.GetEquippedId(player)
	local equipped = if equippedId then Tools.ById[equippedId] else nil
	local equip = tool ~= nil and (equipped == nil or tool.Power > equipped.Power)
	if equip then
		ToolService.Equip(player, toolId)
	end
	ShopService.RefreshPlayer(player)
	return if equip then `{toolId} donné et équipé` else `{toolId} donné`
end

local function grantCashPack(player: Player, product: Product): string
	-- Revenu actuel, tous les bonus compris (les % de Premium et de l'index, puis les ×2), comme le HUD.
	local income = DisplayService.GetIncome(player) * DisplayService.GetGlobalMultiplier(player)
	local minutes = product.Minutes :: number
	local amount = Monetization.CashPackAmount(income, minutes)
	if DataService.AddCash(player, amount) == nil then
		error(`DataService.AddCash({amount}) refusé`)
	end
	TelemetryService.LogEconomy(player, "Robux", amount, product.Key)
	notify(player, string.format(MESSAGES.CashPack, Format.money(amount)))
	return `{Format.money(amount)} ({minutes} min à {Format.money(income)}/s)`
end

-- Vague 31 (L-112) : `uid` est-il un objet sous antivol posé au sol (UnboxService.GetFloorItem) ?
local function isFloorItem(player: Player, uid: string): boolean
	-- pcall : GetFloorItem absent d'un UnboxService de banc → false.
	local ok, item = pcall((UnboxService :: any).GetFloorItem, player, uid)
	return ok and item ~= nil
end

local function grantOpenNow(player: Player, data: Data, tier: Tier): string
	local bench = longestWait(player)
	if bench then
		local isItem = isFloorItem(player, bench) -- vague 31 : l'antivol d'un objet au sol, même chemin
		local left = UnboxService.SkipWait(player, bench, tier.Skip)
		if left then
			if left <= 0 then
				notify(player, if isItem then MESSAGES.OpenNowUnlocked else MESSAGES.OpenNowReady)
			else
				notify(player, string.format(if isItem then MESSAGES.OpenNowShorterItem else MESSAGES.OpenNowShorter, duration(tier.Skip)))
			end
			return `{if isItem then "objet" else "colis"} {bench} : {if left <= 0 then "prêt" else `reste {duration(left)}`}`
		end
	end
	local monetization = monetizationOf(data) :: MonetizationData
	monetization.OpenNowCredit = finite(monetization.OpenNowCredit) + tier.Skip
	notify(player, MESSAGES.OpenNowCredit)
	return `aucun colis en attente : {tier.Skip} s gardées pour les prochains (crédit {monetization.OpenNowCredit} s)`
end

local function grantStarterPack(player: Player, data: Data): string
	local pack = Monetization.StarterPack
	local monetization = monetizationOf(data) :: MonetizationData
	local again = monetization.StarterPack == true
	monetization.StarterPack = true
	local state = states[player]
	if state then
		clearStarterOffer(player, state)
	end
	if DataService.AddCash(player, pack.Cash) == nil then
		error(`DataService.AddCash({pack.Cash}) refusé`)
	end
	TelemetryService.LogEconomy(player, "Robux", pack.Cash, "StarterPack")
	local toolText = giveTool(player, pack.Tool)
	local boosted = addBoost(player, pack.BoostSeconds)
	notify(player, string.format(MESSAGES.StarterPack, Format.money(pack.Cash)))
	if again then
		warn(`[MonetizationService] {player.Name} : pack de départ acheté une 2e fois (fenêtre d'achat ouverte sans l'écran) : redonné, il a payé`)
	end
	return `{Format.money(pack.Cash)}, {toolText}, boost {if boosted then "prolongé" else "refusé"}`
end

-- Le don lui-même (sans yield). Renvoie le détail pour la sortie.
local function grant(player: Player, data: Data, sale: Sale): string
	local key = sale.product.Key
	if key == "StarterPack" then
		return grantStarterPack(player, data)
	elseif key == "OpenNow" then
		return grantOpenNow(player, data, sale.tier :: Tier)
	elseif key == "Crate" then
		return grantCrate(player, data, sale.pack :: CratePack)
	elseif sale.product.Luck ~= nil then
		return grantServerLuck(player, sale.product)
	end
	return grantCashPack(player, sale.product)
end

-- Garde au plus Receipts.History achats dans Purchases : les plus anciens partent (jamais `keep`).
local function prune(purchases: { [string]: any }, keep: string)
	type Entry = { id: string, at: number }
	local list: { Entry } = {}
	for id, at in purchases do
		if id ~= keep then
			table.insert(list, { id = id, at = finite(at) })
		end
	end
	local excess = #list + 1 - Monetization.Receipts.History
	if excess <= 0 then
		return
	end
	table.sort(list, function(a: Entry, b: Entry): boolean
		if a.at ~= b.at then
			return a.at < b.at
		end
		return a.id < b.id
	end)
	for index = 1, math.min(excess, #list) do
		purchases[list[index].id] = nil
	end
end

-- Un achat de `sale` par `player` (profil chargé), identifié par `purchaseId` : idempotent (voir
-- l'en-tête). Yield (attente de la sauvegarde).
local function processSale(player: Player, data: Data, sale: Sale, purchaseId: string): Enum.ProductPurchaseDecision
	local purchases = (data :: any).Purchases
	if type(purchases) ~= "table" then
		warn(`[MonetizationService] {player.Name} : Purchases illisible dans le profil, reçu {purchaseId} pas traité`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local key = sale.product.Key
	if purchases[purchaseId] == nil then
		local problem = cannotGrant(player, data, sale)
		if problem then
			warn(`[MonetizationService] {player.Name} : {key} pas donné ({problem}), reçu {purchaseId} laissé pour plus tard`)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		-- D'un seul tenant, sans yield : le don et le PurchaseId sont sauvegardés ensemble.
		local ok, detail = pcall(grant, player, data, sale)
		purchases[purchaseId] = os.time()
		prune(purchases, purchaseId)
		if ok then
			log(`{player.Name} : {key} donné, reçu {purchaseId} : {detail}`)
		else
			warn(`[MonetizationService] {player.Name} : don de {key} en erreur ({detail}) ; reçu {purchaseId} noté quand même, à compenser à la main`)
		end
	else
		log(`{player.Name} : reçu {purchaseId} ({key}) déjà donné, rien de plus`)
	end
	local saved = DataService.SaveAsync(player, function(last: any): boolean
		local list = last.Purchases
		return type(list) == "table" and list[purchaseId] ~= nil
	end)
	if saved then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	log(`{player.Name} : reçu {purchaseId} pas encore sauvegardé (profil fermé) : NotProcessedYet, rappelé au retour`)
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

local function handleReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local productId, purchaseId, userId = receipt.ProductId, receipt.PurchaseId, receipt.PlayerId
	if type(productId) ~= "number" or type(purchaseId) ~= "string" or purchaseId == "" or type(userId) ~= "number" then
		warn(`[MonetizationService] reçu mal formé (ProductId {tostring(productId)}, PurchaseId {tostring(purchaseId)})`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local sale = salesById[productId]
	if sale == nil then
		warn(`[MonetizationService] reçu {purchaseId} : produit {productId} absent de Config/Monetization, pas traité`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not sale.product.Ready then
		warn(`[MonetizationService] reçu {purchaseId} : {sale.product.Key} pas encore codé, pas traité`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(userId)
	if player == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = DataService.WaitFor(player, Monetization.Receipts.ProfileWait)
	if data == nil or player.Parent ~= Players then
		log(`{player.Name} : reçu {purchaseId} ({sale.product.Key}) : profil pas chargé, NotProcessedYet`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return processSale(player, data, sale, purchaseId)
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local ok, decision = pcall(handleReceipt, receipt)
	if ok then
		return decision
	end
	warn(`[MonetizationService] ProcessReceipt : {decision}`)
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

------------------------------------------------------------------------------
-- Événements
------------------------------------------------------------------------------

-- Effets à l'achat d'un gamepass pendant la session.
local function onPassAcquired(player: Player, pass: Pass)
	notify(player, string.format(MESSAGES.PassUnlocked, pass.DisplayName))
	if pass.Key == "FastOpen" then
		local factor = passValue("FastOpen", "DelayFactor", 1)
		local now = serverNow()
		local count = 0
		for bench, readyAt in UnboxService.GetWaiting(player) do
			local remaining = readyAt - now
			if remaining > 0 and UnboxService.SkipWait(player, bench, remaining * (1 - factor)) ~= nil then
				count += 1
			end
		end
		if count > 0 then
			notify(player, MESSAGES.FastOpen)
		end
	end
end

local function acquirePass(player: Player, pass: Pass, why: string)
	local state = states[player]
	if state == nil then
		return
	end
	local had = hasPass(player, pass.Key)
	state.bought[pass.Key] = true
	setOwned(player, pass, true, why)
	if not had then
		onPassAcquired(player, pass)
	end
end

-- a274 (audit a272, H1) : PromptGamePassPurchaseFinished peut être déclenché par un client tricheur sans payer.
-- Le pass n'est donné que si Roblox confirme la possession (UserOwnsGamePassAsync, PassCheck.Attempts essais
-- espacés de PassCheck.RetryDelay s) ; sans réponse vraie, rien n'est donné ni écrit dans le cache du profil (la
-- vérification de l'arrivée suivante le donnera s'il a vraiment été acheté). Yield.
local verifying: { [Player]: { [number]: boolean } } = {}

local function verifyPurchase(player: Player, pass: Pass)
	local mine = verifying[player]
	if mine == nil then
		mine = {}
		verifying[player] = mine
	end
	if mine[pass.Id] then
		return -- une vérification est déjà en cours pour ce pass
	end
	mine[pass.Id] = true
	local check = Monetization.PassCheck
	for attempt = 1, check.Attempts do
		local ok, owns = pcall(function(): boolean
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
		end)
		if player.Parent ~= Players then
			break
		end
		if ok then
			if owns == true then
				acquirePass(player, pass, "acheté, confirmé par Roblox")
			else
				warn(`[MonetizationService] {player.Name} : fin d'achat du gamepass {pass.Key} sans possession confirmée par Roblox : rien donné`)
			end
			break
		end
		if attempt == check.Attempts then
			warn(`[MonetizationService] {player.Name} : Roblox ne répond pas pour le gamepass {pass.Key} acheté : donné à la prochaine arrivée s'il est possédé`)
		else
			task.wait(check.RetryDelay)
		end
	end
	mine[pass.Id] = nil
	if next(mine) == nil and verifying[player] == mine then
		verifying[player] = nil
	end
end

local function onGamePassPurchaseFinished(player: Player, passId: number, wasPurchased: boolean)
	local pass = passesById[passId]
	if not wasPurchased or pass == nil or states[player] == nil then
		return
	end
	task.spawn(verifyPurchase, player, pass)
end

local function onPlayerAdded(player: Player)
	if states[player] then
		return
	end
	states[player] = { known = {}, owned = {}, bought = {}, sessionStart = nil, boostUntil = nil, boostEndsAt = nil, starterEndsAt = nil }
	if enabled then
		task.spawn(checkPasses, player)
	end
end

local function onProfileLoaded(player: Player)
	if states[player] == nil then
		onPlayerAdded(player)
	end
	local state = states[player]
	local data = DataService.Get(player)
	if state == nil or data == nil then
		return
	end
	state.sessionStart = os.time()
	-- Réponses de Roblox arrivées avant le profil : elles l'emportent sur le cache.
	for key in state.known do
		writeCache(player, key, state.owned[key] == true)
	end
	if enabled then
		for _, pass in Monetization.Passes do
			publishPass(player, pass.Key)
		end
	end
	local boosts = boostsOf(data)
	local saved = if boosts then finite(boosts.Cash) else 0
	if saved > 0 then
		state.boostUntil = os.clock() + saved
		state.boostEndsAt = serverNow() + saved
		setAttribute(player, BOOST_ATTRIBUTE, state.boostEndsAt)
	end
	local left = if enabled then starterLeft(data, state) else 0
	if left > 0 then
		state.starterEndsAt = serverNow() + left
		setAttribute(player, STARTER_ATTRIBUTE, state.starterEndsAt)
	end
	if saved > 0 or left > 0 then
		log(`{player.Name} : boost ×2 argent {duration(saved)}, pack de départ {if left > 0 then `proposé encore {duration(left)}` else "pas proposé"}`)
	end
end

-- Départ : dernier moment pour écrire le temps de boost restant.
local function onProfileReleasing(player: Player)
	local state = states[player]
	local boosts = boostsOf(DataService.Get(player))
	local untilClock = if state then state.boostUntil else nil
	if boosts and untilClock then
		boosts.Cash = math.max(0, untilClock - os.clock())
	end
end

-- Un colis vient d'être posé : le crédit d'« Ouvrir maintenant » raccourcit son attente.
local function onBoxPlaced(player: Player, boxUid: string, _box: any)
	local monetization = monetizationOf(DataService.Get(player))
	local credit = if monetization then finite(monetization.OpenNowCredit) else 0
	if monetization == nil or credit <= 0 then
		return
	end
	local readyAt = UnboxService.GetWaiting(player)[boxUid]
	local skip = if readyAt then math.min(credit, readyAt - serverNow()) else 0
	if skip <= 0 or UnboxService.SkipWait(player, boxUid, skip) == nil then
		return
	end
	monetization.OpenNowCredit = credit - skip
	local message = if isFloorItem(player, boxUid) then MESSAGES.OpenNowCreditUsedItem else MESSAGES.OpenNowCreditUsed
	notify(player, string.format(message, duration(skip)))
	log(`{player.Name} : crédit d'Ouvrir maintenant : {duration(skip)} retirées au colis {boxUid}, reste {monetization.OpenNowCredit} s`)
end

------------------------------------------------------------------------------
-- Crochet de test (Studio seulement)
------------------------------------------------------------------------------

local function findPlayer(who: string): Player?
	local userId = tonumber(who)
	for _, player in Players:GetPlayers() do
		if player.Name == who or (userId ~= nil and player.UserId == userId) then
			return player
		end
	end
	return nil
end

local function onTestAttribute()
	local value = Workspace:GetAttribute(TEST_ATTRIBUTE)
	if value == nil then
		return
	end
	Workspace:SetAttribute(TEST_ATTRIBUTE, nil)
	local who, key = string.match(tostring(value), "^%s*(%S+)%s+(%S+)%s*$")
	local player = if who then findPlayer(who) else nil
	if player == nil or key == nil then
		warn(`[MonetizationService] test : « {tostring(value)} » : attendu « <joueur> <Clé> » avec un joueur présent`)
		return
	end
	local crateDigits: string? = string.match(key, `^{CRATE.KeyPrefix}(%d+)$`)
	local crateCount = if crateDigits then tonumber(crateDigits) else nil
	if not enabled and crateCount == nil then
		warn(`[MonetizationService] test : boutique coupée (Features.RobuxShop = false) : seule la caisse exclusive se teste (Crate1, Crate3, Crate10)`)
		return
	end
	local pass = Monetization.PassByKey[key]
	if pass then
		acquirePass(player, pass, "test Studio")
		print(`[MonetizationService] test : gamepass {key} donné à {player.Name} pour la session`)
		return
	end
	local sale: Sale? = nil
	local tierIndex = tonumber(string.match(key, "^OpenNow(%d)$"))
	if crateCount then
		-- a285 : un lot de la caisse exclusive (Crate1, Crate3, Crate10), même don qu'un reçu.
		for _, pack in CRATE.Packs do
			if pack.Count == crateCount then
				sale = { product = CRATE_PRODUCT, tier = nil, pack = pack }
			end
		end
	elseif tierIndex then
		local openNow = Monetization.ProductByKey.OpenNow
		local tier = if openNow.Tiers then openNow.Tiers[tierIndex] else nil
		if tier then
			sale = { product = openNow, tier = tier }
		end
	else
		local product = Monetization.ProductByKey[key]
		if product and product.Tiers == nil then
			sale = { product = product, tier = nil }
		end
	end
	if sale == nil or not sale.product.Ready then
		warn(`[MonetizationService] test : « {key} » n'est ni un gamepass ni un produit codé (OpenNow1 à OpenNow4 pour Ouvrir maintenant ; Crate1, Crate3, Crate10 avec Monetization.Crate.Live : Features.RobuxCrate, ou RobuxCrateDev dans le jeu DEV)`)
		return
	end
	local data = DataService.Get(player)
	if data == nil then
		warn(`[MonetizationService] test : profil de {player.Name} pas chargé`)
		return
	end
	testCount += 1
	if testSession == nil then
		testSession = HttpService:GenerateGUID(false) -- a297 : tiré au premier essai de ce Play
	end
	local purchaseId = `STUDIO-{testSession}-{testCount}`
	local testSale = sale :: Sale
	task.spawn(function()
		local decision = processSale(player, data, testSale, purchaseId)
		print(`[MonetizationService] test : {key} pour {player.Name} (reçu {purchaseId}) → {decision.Name}`)
	end)
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------

function MonetizationService.IsEnabled(): boolean
	return enabled
end

function MonetizationService.HasPass(player: Player, key: string): boolean
	return hasPass(player, key)
end

function MonetizationService.GetIncomeMultiplier(player: Player): number
	return (1 + incomeBonus(player)) * incomeMultiplier(player)
end

function MonetizationService.GetTemporaryIncomeMultiplier(player: Player): number
	if boostActive(player) then
		return Monetization.CashBoost.Multiplier
	end
	return 1
end

function MonetizationService.AddCashBoost(player: Player, seconds: number): boolean
	return addBoost(player, seconds) -- boutique coupée comprise (DEV-101, voir l'en-tête)
end

-- a309 (Cantin, 22/11) : ouverture d'un colis offert (paliers de temps de jeu, RewardService), objet déjà donné. Mêmes
-- règles que la caisse exclusive (Crate.Reveal : coupée, zone safe seulement, autre cinématique, personnage mort ;
-- boutique coupée comprise) ; colis montré en `startRarity`, cote finale 1 / `chance` (pour cent, Formulas.UnboxOdds).
-- true si l'ouverture est lancée (l'objet montré n'a alors pas de message), false sinon (rien n'est joué). Sans yield.
function MonetizationService.StartGiftReveal(player: Player, itemId: string, startRarity: string?, chance: number?, effect: string?): boolean
	local odds: number? = nil
	local formulas = lazy("Formulas", Shared.Config, "Formulas")
	local value = finite(chance)
	if formulas and type(formulas.UnboxOdds) == "function" and value > 0 then
		odds = (formulas.UnboxOdds :: any)(math.min(value / 100, 1))
	end
	local ok, why = pcall(startReveal, player, { itemId }, itemId, startRarity, odds, effect, "Gift")
	if not ok then
		warn(`[MonetizationService] {player.Name} : ouverture du colis offert impossible ({why}), objet donné quand même`)
		return false
	end
	return why == nil
end

------------------------------------------------------------------------------
-- Démarrage
------------------------------------------------------------------------------

-- Offres créées (Id ≠ 0) : gamepasses et produits par Id Roblox. Un Id en double est ignoré. a294 : crateOnly =
-- les seuls lots de la caisse exclusive (boutique coupée, caisse allumée : Monetization.Crate.Live).
local function buildSales(crateOnly: boolean?): (number, number)
	local passes, products = 0, 0
	for _, pass in (if crateOnly then {} else Monetization.Passes) :: { Pass } do
		if pass.Id ~= 0 then
			if passesById[pass.Id] then
				warn(`[MonetizationService] gamepass {pass.Id} en double dans Config/Monetization ({passesById[pass.Id].Key} et {pass.Key}) : {pass.Key} ignoré`)
			else
				passesById[pass.Id] = pass
				passes += 1
			end
		end
	end
	local function add(id: number, sale: Sale)
		if id == 0 then
			return
		end
		if salesById[id] then
			warn(`[MonetizationService] produit {id} en double dans Config/Monetization ({salesById[id].product.Key} et {sale.product.Key}) : le 2e ignoré`)
			return
		end
		salesById[id] = sale
		products += 1
	end
	for _, product in (if crateOnly then {} else Monetization.Products) :: { any } do
		local tiers = product.Tiers
		if tiers then
			for _, tier in tiers do
				add(tier.Id, { product = product, tier = tier })
			end
		else
			add(product.Id, { product = product, tier = nil })
		end
	end
	-- a285 : un produit par lot de la caisse exclusive (vendu seulement avec CRATE_PRODUCT.Ready).
	for _, pack in CRATE.Packs do
		add(pack.Id, { product = CRATE_PRODUCT, tier = nil, pack = pack })
	end
	return passes, products
end

-- Accroches des services (voir l'en-tête) : chacune garde et rappelle celle d'avant.
local function installHooks()
	local baseBonus = DisplayService.GetIncomeBonus
	DisplayService.GetIncomeBonus = function(player: Player): number
		return baseBonus(player) + incomeBonus(player)
	end
	local baseIncome = DisplayService.GetIncomeMultiplier
	DisplayService.GetIncomeMultiplier = function(player: Player): number
		return baseIncome(player) * incomeMultiplier(player)
	end
	local baseExtra = DisplayService.GetExtraSlots
	DisplayService.GetExtraSlots = function(player: Player): number
		local extra = if hasPass(player, "ExtraStands") then passValue("ExtraStands", "Stands", 0) else 0
		return baseExtra(player) + extra
	end
	local baseAuto = DisplayService.HasAutoCollect
	DisplayService.HasAutoCollect = function(player: Player): boolean
		return hasPass(player, "AutoCollect") or baseAuto(player)
	end
	local baseGain = TrainingService.GetGainMultiplier
	TrainingService.GetGainMultiplier = function(player: Player, kind: any): number
		local multiplier = if hasPass(player, "DoubleTraining") then passValue("DoubleTraining", "Multiplier", 1) else 1
		return baseGain(player, kind) * multiplier
	end
	-- Vague 31 (L-112, Cantin 2026-11-12) : Fast Open raccourcit l'antivol d'un objet posé au sol. Vague 52 (a170) :
	-- son seul effet (l'accroche UnboxService.GetOpenDelay des colis posés, inerte depuis a158, est retirée).
	local baseAntiTheft = UnboxService.GetAntiTheftDelay
	if (baseAntiTheft :: any) ~= nil then -- absent d'un UnboxService de banc
		UnboxService.GetAntiTheftDelay = function(player: Player, itemId: string): number
			local factor = if hasPass(player, "FastOpen") then passValue("FastOpen", "DelayFactor", 1) else 1
			return baseAntiTheft(player, itemId) * factor
		end
	end
end

function MonetizationService.Init()
	enabled = Features.RobuxShop == true
	if enabled then
		installHooks()
	else
		-- Boutique coupée : seul le boost ×2 argent des récompenses reste (DEV-101, voir l'en-tête).
		local baseIncome = DisplayService.GetIncomeMultiplier
		DisplayService.GetIncomeMultiplier = function(player: Player): number
			return baseIncome(player) * incomeMultiplier(player)
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player: Player)
		-- Après DataService (OnProfileReleasing a déjà écrit le boost) : l'état part au tour suivant.
		task.defer(function()
			states[player] = nil
		end)
		local reveal = crateRevealOf[player] -- a294 : son ouverture de caisse en cours, finie (RevealEnded pour les autres)
		if reveal then
			reveal.pending = {} -- a297 : joueur parti, aucun message (Parent vaut encore Players pendant PlayerRemoving)
			finishCrateReveal(reveal, "joueur parti")
		end
	end)
	-- a294 : RevealDone de l'acheteur d'une caisse (Net garde plusieurs gestionnaires : celui de StoreHeistService reste).
	local revealOk, revealErr = pcall(function()
		(Net.Server :: any).RevealDone:Connect(onCrateRevealDone)
	end)
	if not revealOk then
		warn(`[MonetizationService] Net.Server.RevealDone : {revealErr}`)
	end
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	DataService.OnProfileLoaded(onProfileLoaded)
	DataService.OnProfileReleasing(onProfileReleasing)
	if enabled then
		-- Vague 31 : le crédit d'« Ouvrir maintenant » raccourcit l'antivol d'un objet posé au sol (vague 52 : plus
		-- l'attente d'un colis posé, UnboxService.OnBoxPlaced inerte depuis a158 n'est plus écouté).
		-- pcall : OnItemPlaced absent d'un UnboxService de banc → rien.
		pcall((UnboxService :: any).OnItemPlaced, function(player: Player, itemUid: string, _itemId: string)
			onBoxPlaced(player, itemUid, nil)
		end)
	end

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed < TICK then
			return
		end
		elapsed = 0
		if luckClock ~= nil then -- vague 72 : chance du serveur en cours
			local ok, err = pcall(function()
				advanceLuck()
				publishLuck()
			end)
			if not ok then
				warn(`[MonetizationService] chance du serveur : {err}`)
			end
		end
		for player, state in states do
			local ok, err = pcall(tickPlayer :: any, player, state) -- :: any : sans lui, l'ancien solveur croit que pcall ne renvoie qu'une valeur
			if not ok then
				warn(`[MonetizationService] suivi de {player.Name} : {err}`)
			end
		end
	end)

	if not enabled then
		print("[MonetizationService] Features.RobuxShop = false : boutique Robux coupée (ni reçu, ni gamepass, ni bonus de revenus) ; seul le boost ×2 argent des récompenses reste")
		if CRATE_PRODUCT.Ready then
			-- a294 : caisse allumée (Monetization.Crate.Live : jeu DEV avec Features.RobuxCrateDev, ou Features.RobuxCrate)
			-- et boutique coupée : ProcessReceipt branché pour ses seuls lots (reçus idempotents comme les autres).
			local _, crateProducts = buildSales(true)
			MarketplaceService.ProcessReceipt = processReceipt
			print(`[MonetizationService] caisse exclusive allumée sans la boutique : {crateProducts} lot(s) en vente (Ids à 0 = « Soon »)`)
		end
		if IS_STUDIO and CRATE_PRODUCT.Ready then
			-- a285 : la caisse exclusive se teste en Studio sans la boutique (aucun achat réel, aucun reçu).
			Workspace:GetAttributeChangedSignal(TEST_ATTRIBUTE):Connect(onTestAttribute)
			print("[MonetizationService] Studio : caisse exclusive testable (MonetizationTest « <joueur> Crate1|Crate3|Crate10 »)")
		end
		return
	end
	local passes, products = buildSales()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(onGamePassPurchaseFinished)
	if IS_STUDIO then
		Workspace:GetAttributeChangedSignal(TEST_ATTRIBUTE):Connect(onTestAttribute)
	end
	local sold = if passes + products == 0 then "aucune offre créée (Ids à 0 dans Config/Monetization) : rien n'est vendu" else `{passes} gamepass(es) et {products} produit(s) en vente`
	print(`[MonetizationService] boutique Robux branchée : {sold}`)
end

return MonetizationService
