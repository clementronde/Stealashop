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
--   Purchases garde au plus Receipts.History (V0 : 100) achats : les plus anciens partent.
--
-- Gamepasses : possession lue à l'arrivée (UserOwnsGamePassAsync, dans un pcall : PassCheck.Attempts
-- essais espacés de PassCheck.RetryDelay s, puis un essai toutes les PassCheck.SlowRetry s tant que
-- Roblox ne répond pas) et à la fin d'un achat (PromptGamePassPurchaseFinished, wasPurchased = true).
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
--   Ouverture rapide   UnboxService.GetOpenDelay × 0,5 pour chaque colis posé ; à l'achat, l'attente
--                      restante des colis déjà posés est aussi divisée par 2 (UnboxService.SkipWait).
--                      Priority 150 : posé avant TutorialService (200), le colis garanti du tuto garde
--                      ses 5 s
--   +4 présentoirs     DisplayService.GetExtraSlots = 4 : DisplaySlot_21 à _24, au-delà du maximum de
--                      20, s'ils sont posés dans la boutique (Clément)
--   Roblox Premium     +10 % de revenus (Player.MembershipType, relu chaque seconde) :
--                      DisplayService.GetIncomeBonus + 0,1, additionné aux autres bonus en pour cent
--                      (zones complètes de l'index, IndexService)
--   Packs d'argent     10, 60 ou 300 min des revenus actuels (ceux du HUD, bonus compris), au moins
--                      CashPacks.MinPerMinute $ par minute (Monetization.CashPackAmount)
--   Ouvrir maintenant  un produit par palier de prix (Monetization.OpenNowTier, que l'écran choisit
--                      selon l'attente du colis qui attend le plus) ; le reçu retire jusqu'à Skip s à
--                      ce colis. Aucun colis en attente : les secondes payées vont dans
--                      Monetization.OpenNowCredit du profil, retirées des prochains colis posés
--   Pack de départ     offre unique de la 1re heure de jeu (Lifetime.PlaySeconds + la session) : boost
--                      ×2 argent 1 h (Boosts.Cash, compté seulement en jeu ; un 2e boost prolonge),
--                      Marteau (équipé s'il est plus fort que l'outil équipé), 50 000 $ ;
--                      Monetization.StarterPack = true. Racheté malgré tout (fenêtre d'achat ouverte
--                      sans l'écran) : il est redonné, avec un avertissement (le joueur a payé)
-- M global des revenus (7.1) : (1 + Premium + les autres bonus en %) × ×2 Argent × boost ×2 argent.
-- V0 : les bonus en % s'additionnent entre eux (DisplayService.GetIncomeBonus : Premium ici, l'index
-- dans IndexService ; amis, groupe et VIP viendront de la même façon), les ×2 se multiplient
-- (DisplayService.GetIncomeMultiplier).
-- Télémétrie : l'argent acheté (packs, pack de départ) part en économie « Robux »
-- (TelemetryService.LogEconomy, SKU = clé du produit).
--
-- Pas codés, juste listés (Ready = false : ni affichés ni vendus) :
--   VIP                tag de chat, aura VIP, +10 % de revenus, +1 coffre-fort, rideau +30 s : attend
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
--       Part de la boutique Robux dans le M global (Premium, ×2 Argent, boost) ; 1 si elle est coupée.
--   MonetizationService.AddCashBoost(player, seconds) -> boolean
--       Boost ×2 argent : prolonge celui en cours de `seconds` (pour les récompenses, DEV-101) ; false
--       si la boutique est coupée, le profil pas chargé ou la durée invalide. Sans yield.
--
-- Crochet de test, STUDIO SEULEMENT (Ids encore à 0 : aucun achat réel possible) :
-- workspace:SetAttribute("MonetizationTest", "<joueur> <Clé>") (barre de commande serveur ; joueur =
-- nom ou UserId). Une clé de gamepass le donne pour la session, comme un achat ; une clé de produit
-- (OpenNow1 à OpenNow4 pour un palier d'Ouvrir maintenant) passe par le même don qu'un reçu, avec un
-- faux PurchaseId « STUDIO-n ». Hors de Studio, l'attribut n'est pas écouté.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Features = require(Shared.Config.Features)
local Monetization = require(Shared.Config.Monetization)
local Tools = require(Shared.Config.Tools)
local Format = require(Shared.Format)
local Net = require(Shared.Net.Net)
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

-- Un produit développeur en vente : le produit, et son palier pour Ouvrir maintenant.
type Sale = { product: Product, tier: Tier? }

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
	FastOpen = "Fast Open: your boxes open 2× faster!",
	CashPack = "+%s added to your cash!",
	OpenNowReady = "Your box is ready to open!",
	OpenNowShorter = "Your box wait is %s shorter!",
	OpenNowCredit = "No box is waiting: Open Now will speed up your next boxes.",
	OpenNowCreditUsed = "Open Now: your new box wait is %s shorter!",
	StarterPack = "Starter Pack: +%s, a Hammer and ×2 Cash for 1 hour!",
}

local MonetizationService = {}
-- Après les services dont il remplace les accroches (100) ; avant TutorialService (200), qui pose la
-- sienne sur GetOpenDelay par-dessus (colis du tuto : 5 s exactes) ; avant TelemetryService (210).
MonetizationService.Priority = 150

local enabled = false
local states: { [Player]: State } = {}
local passesById: { [number]: Pass } = {}
local salesById: { [number]: Sale } = {}
local testCount = 0

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
local function incomeMultiplier(player: Player): number
	if not enabled then
		return 1
	end
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

-- Colis qui attend le plus : présentoir (L-086) et heure serveur où il sera prêt.
local function longestWait(player: Player): (number?, number?)
	local bench: number?, latest: number? = nil, nil
	for index, readyAt in UnboxService.GetWaiting(player) do
		if latest == nil or readyAt > latest or (readyAt == latest and index < (bench :: number)) then
			bench, latest = index, readyAt
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

-- Raison pour laquelle le profil ne peut pas recevoir ce produit maintenant (rien n'est alors noté),
-- ou nil.
local function cannotGrant(data: Data, sale: Sale): string?
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
	elseif sale.product.Minutes == nil then
		return `pas de don codé pour {key}`
	end
	return nil
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

local function grantOpenNow(player: Player, data: Data, tier: Tier): string
	local bench = longestWait(player)
	if bench then
		local left = UnboxService.SkipWait(player, bench, tier.Skip)
		if left then
			if left <= 0 then
				notify(player, MESSAGES.OpenNowReady)
			else
				notify(player, string.format(MESSAGES.OpenNowShorter, duration(tier.Skip)))
			end
			return `colis du présentoir {bench} : {if left <= 0 then "prêt" else `reste {duration(left)}`}`
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
		local problem = cannotGrant(data, sale)
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

local function onGamePassPurchaseFinished(player: Player, passId: number, wasPurchased: boolean)
	local pass = passesById[passId]
	if not wasPurchased or pass == nil then
		return
	end
	acquirePass(player, pass, "acheté")
end

local function onPlayerAdded(player: Player)
	if states[player] then
		return
	end
	states[player] = { known = {}, owned = {}, bought = {}, sessionStart = nil, boostUntil = nil, boostEndsAt = nil, starterEndsAt = nil }
	task.spawn(checkPasses, player)
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
	for _, pass in Monetization.Passes do
		publishPass(player, pass.Key)
	end
	local boosts = boostsOf(data)
	local saved = if boosts then finite(boosts.Cash) else 0
	if saved > 0 then
		state.boostUntil = os.clock() + saved
		state.boostEndsAt = serverNow() + saved
		setAttribute(player, BOOST_ATTRIBUTE, state.boostEndsAt)
	end
	local left = starterLeft(data, state)
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
local function onBoxPlaced(player: Player, slotIndex: number, _box: any)
	local monetization = monetizationOf(DataService.Get(player))
	local credit = if monetization then finite(monetization.OpenNowCredit) else 0
	if monetization == nil or credit <= 0 then
		return
	end
	local readyAt = UnboxService.GetWaiting(player)[slotIndex]
	local skip = if readyAt then math.min(credit, readyAt - serverNow()) else 0
	if skip <= 0 or UnboxService.SkipWait(player, slotIndex, skip) == nil then
		return
	end
	monetization.OpenNowCredit = credit - skip
	notify(player, string.format(MESSAGES.OpenNowCreditUsed, duration(skip)))
	log(`{player.Name} : crédit d'Ouvrir maintenant : {duration(skip)} retirées au colis du présentoir {slotIndex}, reste {monetization.OpenNowCredit} s`)
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
	local pass = Monetization.PassByKey[key]
	if pass then
		acquirePass(player, pass, "test Studio")
		print(`[MonetizationService] test : gamepass {key} donné à {player.Name} pour la session`)
		return
	end
	local sale: Sale? = nil
	local tierIndex = tonumber(string.match(key, "^OpenNow(%d)$"))
	if tierIndex then
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
		warn(`[MonetizationService] test : « {key} » n'est ni un gamepass ni un produit codé (OpenNow1 à OpenNow4 pour Ouvrir maintenant)`)
		return
	end
	local data = DataService.Get(player)
	if data == nil then
		warn(`[MonetizationService] test : profil de {player.Name} pas chargé`)
		return
	end
	testCount += 1
	local purchaseId = `STUDIO-{testCount}`
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

function MonetizationService.AddCashBoost(player: Player, seconds: number): boolean
	return enabled and addBoost(player, seconds)
end

------------------------------------------------------------------------------
-- Démarrage
------------------------------------------------------------------------------

-- Offres créées (Id ≠ 0) : gamepasses et produits par Id Roblox. Un Id en double est ignoré.
local function buildSales(): (number, number)
	local passes, products = 0, 0
	for _, pass in Monetization.Passes do
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
	for _, product in Monetization.Products do
		local tiers = product.Tiers
		if tiers then
			for _, tier in tiers do
				add(tier.Id, { product = product, tier = tier })
			end
		else
			add(product.Id, { product = product, tier = nil })
		end
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
	local baseDelay = UnboxService.GetOpenDelay
	UnboxService.GetOpenDelay = function(player: Player, box: any): number
		local factor = if hasPass(player, "FastOpen") then passValue("FastOpen", "DelayFactor", 1) else 1
		return baseDelay(player, box) * factor
	end
end

function MonetizationService.Init()
	enabled = Features.RobuxShop == true
	if not enabled then
		print("[MonetizationService] Features.RobuxShop = false : boutique Robux coupée (ni reçu, ni gamepass, ni bonus de revenus)")
		return
	end
	local passes, products = buildSales()
	installHooks()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(onGamePassPurchaseFinished)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player: Player)
		-- Après DataService (OnProfileReleasing a déjà écrit le boost) : l'état part au tour suivant.
		task.defer(function()
			states[player] = nil
		end)
	end)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	DataService.OnProfileLoaded(onProfileLoaded)
	DataService.OnProfileReleasing(onProfileReleasing)
	UnboxService.OnBoxPlaced(onBoxPlaced)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed < TICK then
			return
		end
		elapsed = 0
		for player, state in states do
			local ok, err = pcall(tickPlayer :: any, player, state) -- :: any : sans lui, l'ancien solveur croit que pcall ne renvoie qu'une valeur
			if not ok then
				warn(`[MonetizationService] suivi de {player.Name} : {err}`)
			end
		end
	end)

	if IS_STUDIO then
		Workspace:GetAttributeChangedSignal(TEST_ATTRIBUTE):Connect(onTestAttribute)
	end
	local sold = if passes + products == 0 then "aucune offre créée (Ids à 0 dans Config/Monetization) : rien n'est vendu" else `{passes} gamepass(es) et {products} produit(s) en vente`
	print(`[MonetizationService] boutique Robux branchée : {sold}`)
end

return MonetizationService
