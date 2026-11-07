--!strict
-- DataService (DEV-004) : sauvegarde des joueurs avec ProfileStore (Partie 1, 9.1, 9.3, 9.5, 9.6).
--
-- Rôle : charge le profil d'un joueur à son arrivée (clé « Player_<UserId> »), le met à
-- la version courante du schéma (migrations), complète les champs manquants depuis le
-- modèle, puis le libère à son départ. ProfileStore pose un verrou de session : un profil
-- n'est actif que sur un seul serveur à la fois, ce qui empêche toute duplication.
-- Aucune donnée ne vient du client : ce service n'a aucun remote.
--
-- API (côté serveur uniquement) :
--   DataService.Get(player) -> Data?
--       Données du joueur si son profil est chargé et actif, sinon nil (toujours vérifier).
--       On lit et on modifie directement la table renvoyée ; ProfileStore la sauvegarde
--       (toutes les 5 min, au départ du joueur et à l'arrêt du serveur). Ne jamais garder
--       cette table après un yield sans rappeler Get : le profil a pu être libéré.
--   DataService.WaitFor(player, timeout?) -> Data?
--       Attend le chargement (yield) au plus `timeout` secondes (60 par défaut) ;
--       nil si le joueur part, si le chargement échoue ou si le délai est dépassé.
--   DataService.IsLoaded(player) -> boolean
--   DataService.OnProfileLoaded(listener) -> déconnexion
--       listener(player) est appelé pour chaque profil chargé, y compris ceux déjà
--       chargés au moment de l'abonnement (pas de course au démarrage). Il peut yield.
--   DataService.OnProfileReleasing(listener) -> déconnexion
--       listener(player) est appelé juste avant la libération du profil, quand le joueur
--       part : dernier moment pour écrire dans Get(player). Il ne doit pas yield.
--       À utiliser à la place de Players.PlayerRemoving pour toute écriture au départ.
--   DataService.AddCash(player, amount) -> number?
--       Ajoute `amount` (nombre fini ≥ 0) à l'argent ; renvoie le nouveau solde, ou nil
--       si le profil n'est pas chargé ou si le montant est invalide.
--   DataService.SpendCash(player, amount) -> boolean
--       Retire `amount` si le joueur l'a ; false sinon (rien n'est retiré).
--   DataService.OnCashChanged(listener) -> déconnexion
--       listener(player, cash) après chaque AddCash ou SpendCash (côté serveur).
--       L'argent ne se modifie que par AddCash et SpendCash.
--
-- Attribut du Player (écrit seulement ici) : Cash, l'argent du profil, posé au chargement puis à
-- chaque AddCash ou SpendCash. Le HUD l'affiche (HudController, DEV-021) ; il ne sert qu'à
-- l'affichage : le code serveur lit Get(player).Cash.
--
-- Exemple (dans un autre service) :
--   local DataService = require(script.Parent.DataService)
--   DataService.OnProfileLoaded(function(player)
--       local data = DataService.Get(player)
--       if data then
--           print(player.Name, "a", data.Cash, "$")
--       end
--   end)
--   if DataService.SpendCash(player, price) then
--       -- l'achat est payé : donner l'objet
--   end
--
-- Studio : sans « Accès Studio aux services d'API », ProfileStore passe tout seul en mode
-- mock (rien n'est sauvegardé) ; ce service l'écrit dans la sortie au démarrage.
--
-- Nouvelle version du schéma (ex. v2 de la Partie 2) :
--   1. ajouter les champs dans Types/Profile et dans TEMPLATE ci-dessous ;
--   2. ajouter MIGRATIONS[2] (transforme un profil v1 en v2 ; ce qui est seulement
--      nouveau est complété depuis TEMPLATE, inutile de le recopier) ;
--   3. passer CURRENT_VERSION à 2.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ProfileTypes = require(ReplicatedStorage.Shared.Types.Profile)

local Server = (script.Parent :: Instance).Parent :: Instance
local ProfileStore = require(Server:WaitForChild("Packages"):WaitForChild("ProfileStore") :: ModuleScript) :: any

type Data = ProfileTypes.Data
export type PlayerListener = (player: Player) -> ()
export type CashListener = (player: Player, cash: number) -> ()

-- Ce que ce service utilise d'un profil ProfileStore.
type StoreProfile = {
	Data: Data,
	Key: string,
	IsActive: (self: StoreProfile) -> boolean,
	Reconcile: (self: StoreProfile) -> (),
	EndSession: (self: StoreProfile) -> (),
	AddUserId: (self: StoreProfile, userId: number) -> (),
	OnSessionEnd: { Connect: (self: any, listener: () -> ()) -> any },
}

type Store = {
	StartSessionAsync: (self: Store, key: string, params: { Cancel: () -> boolean }) -> StoreProfile?,
}

-- Nom de la DataStore des joueurs. Ne jamais le changer : un autre nom = profils vides.
local STORE_NAME = "PlayerData"
-- Délai par défaut de WaitFor, en secondes. V0 proposé, absent du doc : ProfileStore
-- reprend une session bloquée sur un autre serveur au bout d'environ 40 s.
local DEFAULT_WAIT_TIMEOUT = 60

-- Version courante du schéma de sauvegarde (section 9.5).
local CURRENT_VERSION = 1

-- Attribut du Player lu par le HUD (même nom dans HudController).
local CASH_ATTRIBUTE = "Cash"

-- Modèle d'un nouveau profil, schéma v1 de la section 9.5. Il sert aussi à compléter
-- les champs manquants d'un profil existant (Profile:Reconcile de ProfileStore).
local TEMPLATE: Data = {
	Version = CURRENT_VERSION,
	Cash = 0,
	Stats = { Speed = 0, Strength = 0 },
	Upgrades = { Treadmill = 0, Bench = 0, DisplaySlots = 0, UnboxBenches = 0 },
	Tools = { Owned = { "Fists" }, Equipped = "Fists" },
	Cosmetics = { Auras = {}, Trails = {}, EquippedAura = nil, EquippedTrail = nil },
	Items = {},
	Display = {},
	Vault = {},
	Boxes = {},
	Tutorial = { Step = 0, Done = false },
	Lifetime = { Heists = 0, Steals = 0, Defenses = 0, PlaySeconds = 0 },
	Purchases = {},
}

-- MIGRATIONS[n] fait passer un profil de la version n - 1 à la version n, en place.
-- Un profil sans Version est traité comme une version 0. La v1 est la première :
-- rien à transformer, Reconcile complète tout depuis TEMPLATE.
-- Exemple pour la Partie 2 :
--   MIGRATIONS[2] = function(data)
--       -- renommer ou convertir un champ v1 ici ; les champs neufs viennent de TEMPLATE
--   end
local MIGRATIONS: { [number]: (data: any) -> () } = {
	[1] = function(_data: any) end,
}

-- Messages d'expulsion, lus par le joueur : en anglais (L-036).
local MESSAGES = {
	LoadFailed = "Your save couldn't be loaded. Please come back in a moment.",
	SessionEnded = "Your game was closed on this server, probably because it opened on another one. Rejoin to keep playing.",
	TooNew = "The game was just updated. Join a new server to get your progress back.",
	MigrationFailed = "Your save couldn't be updated. Please come back in a moment. If it keeps happening, let us know.",
}

local DataService = {}
DataService.Priority = 1 -- démarre avant les autres services

local store: Store? = nil
local profiles: { [Player]: StoreProfile } = {}
local loading: { [Player]: boolean } = {}
local joinedAt: { [Player]: number } = {}
local loadedListeners: { PlayerListener } = {}
local releasingListeners: { PlayerListener } = {}
local cashListeners: { CashListener } = {}

local function deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value :: any do
		copy[key] = deepCopy(child)
	end
	return (copy :: any) :: T
end

local function isSaving(): boolean
	return ProfileStore.DataStoreState == "Access"
end

local function kick(player: Player, message: string)
	if player.Parent == Players then
		player:Kick(message)
	end
end

-- Renvoie une fonction qui retire `listener` de `list`.
local function subscribe<T>(list: { T }, listener: T): () -> ()
	table.insert(list, listener)
	return function()
		local index = table.find(list, listener)
		if index then
			table.remove(list, index)
		end
	end
end

-- Met `data` à la version courante. "TooNew" : profil écrit par une version plus
-- récente du jeu (serveur pas encore à jour) ; on n'y touche pas.
local function migrate(data: any): "Ok" | "TooNew"
	local version = if type(data.Version) == "number" then data.Version else 0
	if version > CURRENT_VERSION then
		return "TooNew"
	end
	for target = version + 1, CURRENT_VERSION do
		local step = MIGRATIONS[target]
		if step == nil then
			error(`migration vers la v{target} absente`)
		end
		step(data)
		data.Version = target
	end
	return "Ok"
end

local function loadProfile(player: Player)
	if store == nil or loading[player] or profiles[player] then
		return
	end
	local activeStore = store :: Store
	loading[player] = true
	local key = `Player_{player.UserId}`

	local ok, result = pcall(function(): StoreProfile?
		return activeStore:StartSessionAsync(key, {
			-- Arrête d'essayer si le joueur est parti pendant le chargement.
			Cancel = function(): boolean
				return player.Parent ~= Players
			end,
		})
	end)
	loading[player] = nil

	if not ok then
		warn(`[DataService] {player.Name} ({key}) : erreur au chargement : {result}`)
		kick(player, MESSAGES.LoadFailed)
		return
	end
	local profile = result
	if profile == nil then
		-- Joueur parti, serveur en arrêt, ou session impossible à ouvrir (ProfileStore abandonne après 120 s).
		if player.Parent == Players then
			warn(`[DataService] {player.Name} ({key}) : session impossible à ouvrir`)
		end
		kick(player, MESSAGES.LoadFailed)
		return
	end
	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	-- Migration sur une copie : en cas d'erreur, la sauvegarde d'origine reste intacte.
	local migrated = deepCopy(profile.Data)
	local migrateOk, status = pcall(migrate, migrated)
	if not migrateOk then
		warn(`[DataService] {player.Name} ({key}) : échec de la migration : {status}`)
		profile:EndSession()
		kick(player, MESSAGES.MigrationFailed)
		return
	end
	if status == "TooNew" then
		warn(`[DataService] {player.Name} ({key}) : profil en v{profile.Data.Version}, ce serveur ne connaît que la v{CURRENT_VERSION}`)
		profile:EndSession()
		kick(player, MESSAGES.TooNew)
		return
	end
	profile.Data = migrated
	profile:Reconcile()
	profile:AddUserId(player.UserId)

	-- Fin de session sans départ du joueur : profil repris par un autre serveur.
	-- (À l'arrêt du serveur, Roblox expulse déjà tout le monde avec son propre message.)
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		joinedAt[player] = nil
		if not ProfileStore.IsClosing then
			kick(player, MESSAGES.SessionEnded)
		end
	end)

	profiles[player] = profile
	joinedAt[player] = os.time()
	player:SetAttribute(CASH_ATTRIBUTE, profile.Data.Cash)
	local mode = if isSaving() then "" else ", mode mock : non sauvegardé"
	print(`[DataService] {player.Name} : profil {key} chargé (v{profile.Data.Version}{mode})`)

	for _, listener in table.clone(loadedListeners) do
		task.spawn(listener, player)
	end
end

local function releaseProfile(player: Player)
	local profile = profiles[player]
	if profile == nil then
		return
	end
	for _, listener in table.clone(releasingListeners) do
		local ok, err = pcall(listener, player)
		if not ok then
			warn(`[DataService] OnProfileReleasing ({player.Name}) : {err}`)
		end
	end
	local started = joinedAt[player]
	if started and profile:IsActive() then
		profile.Data.Lifetime.PlaySeconds += math.max(0, os.time() - started)
	end
	profiles[player] = nil
	joinedAt[player] = nil
	profile:EndSession()
end

local function notifyCash(player: Player, cash: number)
	player:SetAttribute(CASH_ATTRIBUTE, cash)
	for _, listener in table.clone(cashListeners) do
		task.spawn(listener, player, cash)
	end
end

local function isValidAmount(amount: number): boolean
	return type(amount) == "number" and amount == amount and amount >= 0 and amount < math.huge
end

function DataService.Get(player: Player): Data?
	local profile = profiles[player]
	if profile ~= nil and profile:IsActive() then
		return profile.Data
	end
	return nil
end

function DataService.IsLoaded(player: Player): boolean
	return DataService.Get(player) ~= nil
end

function DataService.WaitFor(player: Player, timeout: number?): Data?
	local deadline = os.clock() + (timeout or DEFAULT_WAIT_TIMEOUT)
	while true do
		local data = DataService.Get(player)
		if data ~= nil then
			return data
		end
		-- Un chargement raté expulse le joueur : la boucle s'arrête alors aussi.
		if player.Parent ~= Players or os.clock() >= deadline then
			return nil
		end
		task.wait()
	end
end

function DataService.OnProfileLoaded(listener: PlayerListener): () -> ()
	local disconnect = subscribe(loadedListeners, listener)
	for player in table.clone(profiles) do
		if DataService.IsLoaded(player) then
			task.spawn(listener, player)
		end
	end
	return disconnect
end

function DataService.OnProfileReleasing(listener: PlayerListener): () -> ()
	return subscribe(releasingListeners, listener)
end

function DataService.OnCashChanged(listener: CashListener): () -> ()
	return subscribe(cashListeners, listener)
end

function DataService.AddCash(player: Player, amount: number): number?
	local data = DataService.Get(player)
	if data == nil or not isValidAmount(amount) then
		return nil
	end
	data.Cash += amount
	notifyCash(player, data.Cash)
	return data.Cash
end

function DataService.SpendCash(player: Player, amount: number): boolean
	local data = DataService.Get(player)
	if data == nil or not isValidAmount(amount) or data.Cash < amount then
		return false
	end
	data.Cash -= amount
	notifyCash(player, data.Cash)
	return true
end

function DataService.Init()
	for version = 1, CURRENT_VERSION do
		if MIGRATIONS[version] == nil then
			error(`[DataService] MIGRATIONS[{version}] manque pour CURRENT_VERSION = {CURRENT_VERSION}`)
		end
	end

	store = ProfileStore.New(STORE_NAME, TEMPLATE)

	Players.PlayerAdded:Connect(loadProfile)
	Players.PlayerRemoving:Connect(releaseProfile)
	-- Joueurs arrivés avant le démarrage du service (Studio, Play rapide).
	for _, player in Players:GetPlayers() do
		task.spawn(loadProfile, player)
	end
end

function DataService.Start()
	-- ProfileStore teste l'accès aux DataStores au lancement (en Studio, cela prend un instant).
	while ProfileStore.DataStoreState == "NotReady" do
		task.wait()
	end
	local state = ProfileStore.DataStoreState
	if state == "Access" then
		if RunService:IsStudio() then
			print(`[DataService] Studio avec accès aux services d'API : les profils sont réellement sauvegardés (DataStore « {STORE_NAME} » de cette expérience)`)
		else
			print(`[DataService] DataStore « {STORE_NAME} » actif`)
		end
	elseif state == "NoInternet" then
		warn("[DataService] pas d'accès Internet : mode mock de ProfileStore, aucune sauvegarde dans cette session")
	else
		warn("[DataService] Studio sans « Accès Studio aux services d'API » : mode mock de ProfileStore, aucune sauvegarde dans cette session. Pour tester la sauvegarde : Paramètres du jeu > Sécurité > Enable Studio Access to API Services.")
	end
end

return DataService
