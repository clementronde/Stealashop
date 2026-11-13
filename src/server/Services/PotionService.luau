--!strict
-- PotionService (vague 28, liaison L-085 et L-097 point 4) : potions personnelles trouvées par terre dans le
-- couloir des zones, côté serveur. Contrat partagé avec le client (PotionController) : en-tête de
-- Config/Potions ; remotes PotionSpawned, PotionRemoved et PickPotion de Net/Definitions. Valeurs : Config/Potions
-- (toutes V0 proposées, absentes du doc) ; ce qui est propre à ce service est marqué V0 plus bas.
--
-- Apparition, pour chaque joueur dont le profil est chargé (le joueur voit les siennes, lui seul) :
--   - au plus Potions.MaxPerPlayer potions à lui en même temps ; une nouvelle quand il a attendu
--     Potions.SpawnEvery s × l'effet de PotionLuck (arbre de compétences, 1 sans achat). L'attente ne court
--     que sous le plafond et le jour : au plafond, la nuit (NightCycleService.IsNight) ou sans profil, elle
--     repart de zéro. Choix V0 pour la nuit : pas de nouvelle potion tant que le couloir est fermé ; celles
--     déjà posées restent et continuent de vieillir. Un achat de PotionLuck compte tout de suite ;
--   - type tiré selon Potion.Weight ; place tirée sur une rue du couloir : une BasePart nommée STREET_NAME
--     (« Street », relevé du 2026-11-11, pas encore au contrat 10.4), choisie selon sa surface, point au
--     hasard sur son dessus à EDGE_MARGIN studs au moins de ses bords (loin des vitrines, à z = ±60). Le
--     point est gardé si un rayon vers le bas (depuis RAY_HEIGHT studs au-dessus ; personnages et pièces
--     invisibles, Transparency 1, traversés) touche d'abord une rue, et
--     de même à CLEARANCE studs autour (pas sous un lampadaire, un arbre, une arche…), s'il est côté couloir
--     (NightCycleService.IsInCorridor) et à MIN_SPACING studs au moins de ses autres potions. Sinon un autre
--     tirage, SPAWN_TRIES au plus, puis nouvel essai RETRY_DELAY s plus tard ;
--   - disparition au bout de Potions.Lifetime s ;
--   - tout part au seul joueur : PotionSpawned(uid, Id, position au sol) et PotionRemoved(uid). À chaque
--     apparition de son personnage (arrivée comprise), il reçoit de nouveau toutes celles qui existent : le
--     client doit traiter un uid déjà connu comme un remplacement (même potion) ;
--   - départ du joueur : tout est oublié (potions et effets).
--
-- Ramassage, remote PickPotion(uid) (Net a déjà contrôlé la forme et le débit) : accepté seulement si la potion
-- est à lui, encore là (pas expirée, pas déjà prise) et s'il est vivant, son HumanoidRootPart à
-- Potions.PickupMaxDistance studs au plus de la potion, son profil chargé, et s'il a moins de
-- Potions.MaxStock potions de ce type. Sinon rien (une ligne en Studio) ; au plafond, la potion reste par terre
-- et un Notify « Warning » (« Your Speed potions are full (5/5). ») part une seule fois par potion. Accepté
-- (vague 33, demande de Cantin du 2026-11-13 : plus d'effet tout de suite) : PotionRemoved, +1 dans le champ
-- facultatif PotionStock du profil, attribut PotionStock_<Id> remis, Notify « Success » (« Speed potion added
-- to your inventory! »), télémétrie (événement PotionPicked, champ « Potion - <Id> »).
--
-- Inventaire des potions (vague 33) : au chargement du profil, PotionStock est nettoyé (Id inconnu retiré,
-- nombre entier borné à Potions.MaxStock, ≤ 0 retiré, table vide → nil) et chaque attribut du Player
-- Potions.StockAttributePrefix .. Id est posé (0 sans potion). Remote UsePotion(potionId) : accepté si l'Id est
-- connu, le profil chargé, le stock ≥ 1 et le personnage vivant ; sinon rien (une ligne en Studio). Accepté :
-- −1 dans le stock, attribut remis, effet appliqué comme avant (même durée, même cumul : un effet du même type
-- déjà actif reçoit la durée en plus, décision V0 d'Ironix, comme deux ramassages avant la vague 33), Notify
-- « Success » (« Speed ×2 for 2:00! », durée qui reste en tout).
--
-- Effets : attribut du Player Potions.AttributePrefix .. Id (« Potion_Speed ») = heure serveur de fin
-- (Workspace:GetServerTimeNow()), retiré à la fin. Durée = Potion.Duration × l'effet de PotionTime (1 sans
-- achat) ; même type déjà actif : la durée s'ajoute à ce qui reste. Mort (Humanoid.Died) ou départ : tous les
-- effets sont retirés (les potions posées restent pour un mort). Branchés sur les points d'accroche, chacun
-- gardé et rappelé (jamais écrasé), relus à chaque usage :
--   Speed         StatsService.SetSpeedModifier(player, "Potion", Multiplier, true) : × la WalkSpeed APRÈS le
--                 plafond de 70 (décision de Cantin du 2026-11-12 : la potion dépasse la limite, jusqu'à 140).
--                 L'anti-triche suit la Humanoid.WalkSpeed appliquée (vitesse autorisée). Sans effet en portant
--                 un objet volé à un joueur : vitesse fixe (Balance.Carry.StolenItemWalkSpeed, 2026-11-13).
--   Money         DisplayService.GetIncomeMultiplier × Multiplier (revenu des présentoirs).
--   Strength      WindowService.GetHitDamageMultiplier × Multiplier (dégâts d'un coup sur une vitrine, une
--                 parcelle ou une cible d'événement ; ni l'attribut Damage du HUD, ni les PV de sa boutique).
--   Invisibility  GuardService.IsHiddenFromNight : les vigiles de nuit ne le repèrent pas ; un vigile qui le
--                 poursuit déjà continue. L'effet visuel (presque transparent pour les autres) est côté client,
--                 lu dans l'attribut.
--
-- API (serveur) :
--   PotionService.IsActive(player, id) -> boolean      effet `id` en cours
--   PotionService.GetEndsAt(player, id) -> number?     heure serveur de fin de l'effet, nil sans effet
--   PotionService.GetStock(player, id) -> number       potions de ce type dans l'inventaire (0 sans profil)
--
-- Tester dans Studio (barre de commande serveur ; hors de Studio, l'attribut n'est pas écouté) :
--   workspace:SetAttribute("PotionTest", "<joueur> spawn Speed")   une potion de ce type à TEST_SPAWN_DISTANCE
--                                                                   studs devant lui (hors plafond)
--   workspace:SetAttribute("PotionTest", "<joueur> give Money")    l'effet tout de suite, sans potion
--   workspace:SetAttribute("PotionTest", "<joueur> stock Money")   une potion de plus dans son inventaire
--                                                                   (plafond MaxStock compris)
--   workspace:SetAttribute("PotionTest", "<joueur> clear")         retire ses potions posées et ses effets
--                                                                   (pas son inventaire)
-- (joueur = nom ou UserId).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Potions = require(Shared.Config.Potions)
local Net = require(Shared.Net.Net)
local ProfileTypes = require(Shared.Types.Profile)

local DataService = require(script.Parent.DataService)
local DisplayService = require(script.Parent.DisplayService)
local GuardService = require(script.Parent.GuardService)
local NightCycleService = require(script.Parent.NightCycleService)
local SkillTreeService = require(script.Parent.SkillTreeService)
local StatsService = require(script.Parent.StatsService)
local TelemetryService = require(script.Parent.TelemetryService)
local WindowService = require(script.Parent.WindowService)

type Potion = Potions.Potion
type Data = ProfileTypes.Data

-- Une potion posée pour un joueur.
type Spawned = {
	Uid: string,
	Id: string,
	Position: Vector3, -- au sol
	ExpiresAt: number, -- heure serveur
}

type State = {
	Potions: { [string]: Spawned },
	Count: number,
	TimerStart: number, -- heure serveur du début de l'attente de la prochaine apparition
	Effects: { [string]: number }, -- [Id] = heure serveur de fin
	Died: RBXScriptConnection?,
	FullWarned: { [string]: boolean }, -- vague 33 : uid des potions déjà signalées « plafond atteint »
}

-- V0 proposés, absents du doc.
local TICK = 0.25 -- s entre deux passes (fins d'effets, potions expirées, apparitions)
local STREET_NAME = "Street" -- sol des rues du couloir (relevé Studio du 2026-11-11)
local EDGE_MARGIN = 15 -- studs entre le point et les bords de la rue (vitrines à z = ±60, rue de -52,5 à 52,5)
local CLEARANCE = 4 -- studs : rayons de contrôle autour du point, qui doivent aussi toucher une rue
local RAY_HEIGHT = 40 -- studs au-dessus du dessus de la rue d'où partent les rayons
local RAY_LENGTH = 80 -- studs vers le bas
local INVISIBLE_SKIPS = 4 -- pièces invisibles (Transparency 1) traversées au plus par un rayon
local MIN_SPACING = 8 -- studs entre deux potions d'un même joueur
local SPAWN_TRIES = 12 -- tirages par apparition
local RETRY_DELAY = 5 -- s avant un nouvel essai si aucun point n'a été trouvé
local STREET_RESCAN = 10 -- s au moins entre deux recherches des rues
local HUMANOID_WAIT = 10 -- s d'attente du Humanoid d'un personnage qui apparaît
local SPEED_KEY = "Potion" -- clé du modificateur de vitesse (StatsService)
local NOTIFY_KIND = "Success"
local FULL_KIND = "Warning" -- vague 33 : plafond de l'inventaire atteint (refus, son UI_Deny)
local TELEMETRY_EVENT = "PotionPicked" -- clé de Config/Telemetry.Events
local TEST_ATTRIBUTE = "PotionTest"
local TEST_SPAWN_DISTANCE = 6

local IS_STUDIO = RunService:IsStudio()

local PotionService = {}

local states: { [Player]: State } = {}
local streets: { BasePart } = {}
local streetsScannedAt = -math.huge
local nextUid = 0
local accumulated = 0
local rng = Random.new()
local warned: { [string]: boolean } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function log(message: string)
	if IS_STUDIO then
		print(`[PotionService] {message}`)
	end
end

local function warnOnce(key: string, message: string)
	if not warned[key] then
		warned[key] = true
		warn(`[PotionService] {message}`)
	end
end

-- Refus d'un ramassage : rien pour le joueur, une ligne en Studio.
local function reject(player: Player, uid: string, reason: string)
	if IS_STUDIO then
		warn(`[PotionService] {player.Name} → PickPotion(« {uid} ») refusé : {reason}`)
	end
end

local function isPositiveFinite(value: any): boolean
	return type(value) == "number" and value == value and value > 0 and value < math.huge
end

local function bodyOf(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if character == nil then
		return nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if root == nil or not root:IsA("BasePart") or humanoid == nil then
		return nil, nil
	end
	return root, humanoid
end

------------------------------------------------------------------------------
-- Effets
------------------------------------------------------------------------------

function PotionService.GetEndsAt(player: Player, id: string): number?
	local state = states[player]
	local endsAt = if state then state.Effects[id] else nil
	if endsAt == nil or endsAt <= now() then
		return nil
	end
	return endsAt
end

function PotionService.IsActive(player: Player, id: string): boolean
	return PotionService.GetEndsAt(player, id) ~= nil
end

-- Multiplicateur de l'effet `id` s'il est actif, 1 sinon.
local function multiplierOf(player: Player, id: string): number
	local potion = Potions.ById[id]
	local multiplier = if potion then potion.Multiplier else nil
	if multiplier == nil or not PotionService.IsActive(player, id) then
		return 1
	end
	return multiplier
end

-- Effet d'une compétence (PotionLuck, PotionTime), 1 sans achat ou si la valeur est illisible.
local function skillFactor(player: Player, id: string): number
	local ok, value = pcall(SkillTreeService.GetEffect, player, id)
	if ok and isPositiveFinite(value) then
		return value :: number
	end
	return 1
end

local function endEffect(player: Player, state: State, id: string)
	state.Effects[id] = nil
	player:SetAttribute(Potions.AttributePrefix .. id, nil)
	if id == "Speed" then
		StatsService.SetSpeedModifier(player, SPEED_KEY, nil)
	end
end

local function clearEffects(player: Player, state: State)
	for id in table.clone(state.Effects) do
		endEffect(player, state, id)
	end
end

-- Applique l'effet de `potion` (durée ajoutée à ce qui reste) ; renvoie la durée qui reste en tout (s).
local function applyEffect(player: Player, state: State, potion: Potion): number
	local t = now()
	local duration = potion.Duration * skillFactor(player, "PotionTime")
	local current = state.Effects[potion.Id]
	local from = if current and current > t then current else t
	local endsAt = from + duration
	state.Effects[potion.Id] = endsAt
	player:SetAttribute(Potions.AttributePrefix .. potion.Id, endsAt)
	if potion.Id == "Speed" then
		StatsService.SetSpeedModifier(player, SPEED_KEY, potion.Multiplier or 1, true) -- au-dessus du plafond
	end
	return endsAt - t
end

local function clockText(seconds: number): string
	local s = math.max(0, math.floor(seconds + 0.5))
	return string.format("%d:%02d", s // 60, s % 60)
end

local function effectMessage(potion: Potion, remaining: number): string
	local multiplier = potion.Multiplier
	if multiplier then
		return `{potion.DisplayName} ×{string.format("%g", multiplier)} for {clockText(remaining)}!`
	end
	return `{potion.DisplayName} for {clockText(remaining)}!`
end

local function notify(player: Player, message: string, kind: string?)
	local ok, err = pcall(function()
		Net.Server.Notify:Fire(player, message, kind or NOTIFY_KIND)
	end)
	if not ok then
		warn(`[PotionService] Notify vers {player.Name} : {err}`)
	end
end

------------------------------------------------------------------------------
-- Inventaire des potions (vague 33)
------------------------------------------------------------------------------

local function stockOf(data: Data, id: string): number
	local stock = data.PotionStock
	local count = if stock then stock[id] else nil
	return if type(count) == "number" then count else 0
end

-- Pose l'attribut PotionStock_<Id> de chaque type (0 sans potion).
local function publishStock(player: Player, data: Data)
	for _, potion in Potions.List do
		local attribute = Potions.StockAttributePrefix .. potion.Id
		local count = stockOf(data, potion.Id)
		if player:GetAttribute(attribute) ~= count then
			player:SetAttribute(attribute, count)
		end
	end
end

-- Ajoute `delta` au stock du type `id` (borné de 0 à MaxStock) ; renvoie le nouveau nombre.
local function changeStock(player: Player, data: Data, id: string, delta: number): number
	local count = math.clamp(stockOf(data, id) + delta, 0, Potions.MaxStock)
	local stock = data.PotionStock or {}
	stock[id] = if count > 0 then count else nil
	data.PotionStock = if next(stock) ~= nil then stock else nil
	publishStock(player, data)
	return count
end

function PotionService.GetStock(player: Player, id: string): number
	local data = DataService.Get(player)
	return if data then stockOf(data, id) else 0
end

-- Chargement du profil : champ nettoyé (voir l'en-tête), attributs posés.
local function onProfileLoaded(player: Player)
	local data = DataService.Get(player)
	if data == nil or player.Parent == nil then
		return
	end
	local stored: any = data.PotionStock
	local clean: { [string]: number } = {}
	if type(stored) == "table" then
		for id, count in stored do
			if type(id) == "string" and Potions.ById[id] ~= nil and type(count) == "number" and count == count then
				local whole = math.clamp(math.floor(count), 0, Potions.MaxStock)
				if whole > 0 then
					clean[id] = whole
				end
			end
		end
	end
	data.PotionStock = if next(clean) ~= nil then clean else nil
	publishStock(player, data)
end

local function installHooks()
	local baseIncome = DisplayService.GetIncomeMultiplier
	DisplayService.GetIncomeMultiplier = function(player: Player): number
		return baseIncome(player) * multiplierOf(player, "Money")
	end
	local baseDamage = WindowService.GetHitDamageMultiplier
	WindowService.GetHitDamageMultiplier = function(player: Player): number
		return baseDamage(player) * multiplierOf(player, "Strength")
	end
	local baseHidden = GuardService.IsHiddenFromNight
	GuardService.IsHiddenFromNight = function(player: Player): boolean
		return baseHidden(player) or PotionService.IsActive(player, "Invisibility")
	end
	-- Gains hors ligne : la potion Money est un boost temporaire, exclu comme le boost ×2 argent (OfflineService
	-- divise le revenu relevé par GetTemporaryIncomeMultiplier). Vu en Play le 2026-11-11 : parti avec la potion
	-- active, le revenu hors ligne gardait son ×2. require protégé : sans MonetizationService (bancs), rien.
	local okMonetization, loaded = pcall(function(): any
		return require(script.Parent.MonetizationService) :: any
	end)
	local monetization: any = if okMonetization then loaded else nil
	local current: any = if type(monetization) == "table" then monetization.GetTemporaryIncomeMultiplier else nil
	if type(current) == "function" then
		local baseTemporary: (Player) -> number = current
		monetization.GetTemporaryIncomeMultiplier = function(player: Player): number
			return baseTemporary(player) * multiplierOf(player, "Money")
		end
	end
end

------------------------------------------------------------------------------
-- Potions posées
------------------------------------------------------------------------------

local function fire(remote: string, player: Player, ...: any)
	local args = table.pack(...)
	local ok, err = pcall(function()
		(Net.Server :: any)[remote]:Fire(player, table.unpack(args, 1, args.n))
	end)
	if not ok then
		warn(`[PotionService] {remote} vers {player.Name} : {err}`)
	end
end

local function addPotion(player: Player, state: State, id: string, position: Vector3, t: number): Spawned
	nextUid += 1
	local entry: Spawned = { Uid = `P{nextUid}`, Id = id, Position = position, ExpiresAt = t + Potions.Lifetime }
	state.Potions[entry.Uid] = entry
	state.Count += 1
	fire("PotionSpawned", player, entry.Uid, entry.Id, entry.Position)
	return entry
end

local function removePotion(player: Player, state: State, uid: string)
	if state.Potions[uid] == nil then
		return
	end
	state.Potions[uid] = nil
	state.Count -= 1
	state.FullWarned[uid] = nil
	fire("PotionRemoved", player, uid)
end

local function sendAll(player: Player, state: State)
	for _, entry in state.Potions do
		fire("PotionSpawned", player, entry.Uid, entry.Id, entry.Position)
	end
end

local function pickType(): Potion
	local total = 0
	for _, potion in Potions.List do
		total += math.max(0, potion.Weight)
	end
	local roll = rng:NextNumber() * total
	for _, potion in Potions.List do
		roll -= math.max(0, potion.Weight)
		if roll < 0 then
			return potion
		end
	end
	return Potions.List[#Potions.List]
end

-- Rues du couloir (voir l'en-tête), recherchées au plus toutes les STREET_RESCAN s si la liste est vide.
local function currentStreets(t: number): { BasePart }
	local alive: { BasePart } = {}
	for _, part in streets do
		if part.Parent ~= nil and part:IsDescendantOf(Workspace) then
			table.insert(alive, part)
		end
	end
	streets = alive
	if #streets == 0 and t - streetsScannedAt >= STREET_RESCAN then
		streetsScannedAt = t
		for _, descendant in Workspace:GetDescendants() do
			if descendant.Name == STREET_NAME and descendant:IsA("BasePart") then
				table.insert(streets, descendant)
			end
		end
		if #streets == 0 then
			warnOnce("streets", `aucune BasePart « {STREET_NAME} » dans le Workspace : pas de potion`)
		else
			log(`{#streets} rue(s) « {STREET_NAME} » trouvée(s)`)
		end
	end
	return streets
end

-- Rayons d'une recherche : personnages exclus, puis chaque pièce invisible touchée (volumes de zone,
-- déclencheurs), ajoutée au filtre au fil des tirs.
type Rays = { Params: RaycastParams, Exclude: { Instance } }

local function newRays(): Rays
	local exclude: { Instance } = {}
	for _, other in Players:GetPlayers() do
		local character = other.Character
		if character then
			table.insert(exclude, character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	return { Params = params, Exclude = exclude }
end

-- Première pièce visible sous le point (x, z), depuis la hauteur `top` + RAY_HEIGHT.
local function groundAt(x: number, z: number, top: number, rays: Rays): RaycastResult?
	local origin = Vector3.new(x, top + RAY_HEIGHT, z)
	local direction = Vector3.new(0, -RAY_LENGTH, 0)
	for _ = 1, INVISIBLE_SKIPS + 1 do
		local result = Workspace:Raycast(origin, direction, rays.Params)
		if result == nil or result.Instance.Transparency < 1 then
			return result
		end
		table.insert(rays.Exclude, result.Instance)
		rays.Params.FilterDescendantsInstances = rays.Exclude
	end
	return nil
end

local function isStreet(result: RaycastResult?): boolean
	return result ~= nil and result.Instance.Name == STREET_NAME
end

local CLEARANCE_OFFSETS = {
	Vector3.new(CLEARANCE, 0, 0),
	Vector3.new(-CLEARANCE, 0, 0),
	Vector3.new(0, 0, CLEARANCE),
	Vector3.new(0, 0, -CLEARANCE),
}

-- Un point au sol d'une rue du couloir pour une nouvelle potion de ce joueur, ou nil.
local function findSpot(state: State, t: number): Vector3?
	local list = currentStreets(t)
	local total = 0
	for _, part in list do
		total += part.Size.X * part.Size.Z
	end
	if total <= 0 then
		return nil
	end
	local rays = newRays()
	for _ = 1, SPAWN_TRIES do
		local roll = rng:NextNumber() * total
		local street = list[#list]
		for _, part in list do
			roll -= part.Size.X * part.Size.Z
			if roll < 0 then
				street = part
				break
			end
		end
		local size = street.Size
		local hx, hz = size.X / 2 - EDGE_MARGIN, size.Z / 2 - EDGE_MARGIN
		if hx > 0 and hz > 0 then
			local local_ = Vector3.new(rng:NextNumber(-hx, hx), size.Y / 2, rng:NextNumber(-hz, hz))
			local point: Vector3 = (street.CFrame:PointToWorldSpace(local_)) -- parenthèses : une seule valeur
			local hit = groundAt(point.X, point.Z, point.Y, rays)
			local ok = hit ~= nil and isStreet(hit)
			if ok then
				for _, offset in CLEARANCE_OFFSETS do
					if not isStreet(groundAt(point.X + offset.X, point.Z + offset.Z, point.Y, rays)) then
						ok = false
						break
					end
				end
			end
			local ground = if ok and hit then hit.Position else nil
			if ground and NightCycleService.IsInCorridor(ground) then
				local free = true
				for _, other in state.Potions do
					if (other.Position - ground).Magnitude < MIN_SPACING then
						free = false
						break
					end
				end
				if free then
					return ground
				end
			end
		end
	end
	return nil
end

local function spawnInterval(player: Player): number
	return Potions.SpawnEvery * skillFactor(player, "PotionLuck")
end

local function trySpawn(player: Player, state: State, t: number): boolean
	local spot = findSpot(state, t)
	if spot == nil then
		warnOnce("spot", "aucun point libre sur les rues du couloir (nouvel essai plus tard)")
		return false
	end
	local potion = pickType()
	local entry = addPotion(player, state, potion.Id, spot, t)
	log(`{player.Name} : potion {potion.Id} ({entry.Uid}) en {spot}`)
	return true
end

------------------------------------------------------------------------------
-- Boucle
------------------------------------------------------------------------------

local function stepPlayer(player: Player, state: State, t: number, night: boolean)
	for id, endsAt in table.clone(state.Effects) do
		if endsAt <= t then
			endEffect(player, state, id)
		end
	end
	for uid, entry in table.clone(state.Potions) do
		if entry.ExpiresAt <= t then
			removePotion(player, state, uid)
		end
	end
	if night or state.Count >= Potions.MaxPerPlayer or DataService.Get(player) == nil then
		state.TimerStart = t
		return
	end
	local interval = spawnInterval(player)
	if t - state.TimerStart >= interval then
		if trySpawn(player, state, t) then
			state.TimerStart = t
		else
			state.TimerStart = t - interval + RETRY_DELAY
		end
	end
end

local function step(dt: number)
	accumulated += dt
	if accumulated < TICK then
		return
	end
	accumulated = 0
	local t = now()
	local night = NightCycleService.IsNight()
	for player, state in states do
		local ok, err = pcall(stepPlayer :: any, player, state, t, night) -- :: any : l'ancien solveur croit que pcall ne renvoie qu'une valeur
		if not ok then
			warnOnce(`tick:{player.UserId}`, `tick : {err}`)
		end
	end
end

------------------------------------------------------------------------------
-- Ramassage
------------------------------------------------------------------------------

local function onPickPotion(player: Player, uid: string)
	local state = states[player]
	local entry = if state then state.Potions[uid] else nil
	if state == nil or entry == nil then
		reject(player, uid, "potion inconnue, pas à lui ou déjà prise")
		return
	end
	local t = now()
	if entry.ExpiresAt <= t then
		removePotion(player, state, uid)
		reject(player, uid, "expirée")
		return
	end
	local root, humanoid = bodyOf(player)
	if root == nil or humanoid == nil or humanoid.Health <= 0 then
		reject(player, uid, "pas de personnage vivant")
		return
	end
	local distance = (root.Position - entry.Position).Magnitude
	if distance > Potions.PickupMaxDistance then
		reject(player, uid, `trop loin ({math.round(distance * 10) / 10} studs)`)
		return
	end
	local potion = Potions.ById[entry.Id]
	if potion == nil then
		removePotion(player, state, uid)
		return
	end
	local data = DataService.Get(player)
	if data == nil then
		reject(player, uid, "profil pas chargé")
		return
	end
	if stockOf(data, potion.Id) >= Potions.MaxStock then
		-- Vague 33 : plafond de l'inventaire, la potion reste par terre ; un seul message par potion (le client
		-- redemande tant qu'il est dessus).
		if not state.FullWarned[uid] then
			state.FullWarned[uid] = true
			notify(player, `Your {potion.DisplayName} potions are full ({Potions.MaxStock}/{Potions.MaxStock}).`, FULL_KIND)
		end
		reject(player, uid, `plafond de l'inventaire ({Potions.MaxStock} {potion.Id})`)
		return
	end
	removePotion(player, state, uid)
	state.FullWarned[uid] = nil
	local count = changeStock(player, data, potion.Id, 1)
	notify(player, `{potion.DisplayName} potion added to your inventory!`)
	TelemetryService.LogEvent(player, TELEMETRY_EVENT, { `Potion - {potion.Id}` })
	log(`{player.Name} ramasse {potion.Id} ({uid}) : {count} dans l'inventaire`)
end

------------------------------------------------------------------------------
-- Utilisation (vague 33)
------------------------------------------------------------------------------

local function onUsePotion(player: Player, potionId: string)
	local function refuse(reason: string)
		if IS_STUDIO then
			warn(`[PotionService] {player.Name} → UsePotion(« {potionId} ») refusé : {reason}`)
		end
	end
	local potion = Potions.ById[potionId]
	if potion == nil then
		refuse("potion inconnue")
		return
	end
	local state = states[player]
	local data = DataService.Get(player)
	if state == nil or data == nil then
		refuse("profil pas chargé")
		return
	end
	if stockOf(data, potion.Id) < 1 then
		refuse("aucune dans l'inventaire")
		return
	end
	local _, humanoid = bodyOf(player)
	if humanoid == nil or humanoid.Health <= 0 then
		refuse("pas de personnage vivant")
		return
	end
	local count = changeStock(player, data, potion.Id, -1)
	local remaining = applyEffect(player, state, potion)
	notify(player, effectMessage(potion, remaining))
	log(`{player.Name} boit {potion.Id} : {math.round(remaining)} s, {count} restante(s)`)
end

------------------------------------------------------------------------------
-- Joueurs
------------------------------------------------------------------------------

local function watchCharacter(player: Player, character: Model)
	local state = states[player]
	if state == nil then
		return
	end
	sendAll(player, state)
	local found = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", HUMANOID_WAIT)
	if found == nil or not found:IsA("Humanoid") or states[player] ~= state or player.Character ~= character then
		return
	end
	local humanoid: Humanoid = found
	local old = state.Died
	if old then
		old:Disconnect()
	end
	state.Died = humanoid.Died:Connect(function()
		if states[player] == state then
			clearEffects(player, state)
		end
	end)
end

local function onPlayerAdded(player: Player)
	if states[player] then
		return
	end
	states[player] = { Potions = {}, Count = 0, TimerStart = now(), Effects = {}, Died = nil, FullWarned = {} }
	player.CharacterAdded:Connect(function(character: Model)
		watchCharacter(player, character)
	end)
	local character = player.Character
	if character then
		task.spawn(watchCharacter, player, character)
	end
end

local function onPlayerRemoving(player: Player)
	local state = states[player]
	if state == nil then
		return
	end
	states[player] = nil
	local died = state.Died
	if died then
		died:Disconnect()
	end
	StatsService.SetSpeedModifier(player, SPEED_KEY, nil)
end

------------------------------------------------------------------------------
-- Crochet de test (Studio)
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
	local words: { string } = {}
	for word in string.gmatch(tostring(value), "%S+") do
		table.insert(words, word)
	end
	local player = if words[1] then findPlayer(words[1]) else nil
	local state = if player then states[player] else nil
	if player == nil or state == nil then
		warn(`[PotionService] test « {value} » : joueur introuvable`)
		return
	end
	local command = words[2]
	local potion = if words[3] then Potions.ById[words[3]] else nil
	if command == "spawn" and potion then
		local root = bodyOf(player)
		if root == nil then
			warn(`[PotionService] test « {value} » : pas de personnage`)
			return
		end
		local ahead = root.Position + root.CFrame.LookVector * TEST_SPAWN_DISTANCE
		local hit = groundAt(ahead.X, ahead.Z, ahead.Y - RAY_HEIGHT, newRays())
		local ground = if hit then hit.Position else ahead - Vector3.new(0, 3, 0)
		local entry = addPotion(player, state, potion.Id, ground, now())
		print(`[PotionService] test : potion {potion.Id} ({entry.Uid}) devant {player.Name}`)
	elseif command == "give" and potion then
		local remaining = applyEffect(player, state, potion)
		notify(player, effectMessage(potion, remaining))
		print(`[PotionService] test : {player.Name} reçoit l'effet {potion.Id} ({math.round(remaining)} s)`)
	elseif command == "stock" and potion then
		local data = DataService.Get(player)
		if data == nil then
			warn(`[PotionService] test « {value} » : profil pas chargé`)
			return
		end
		local count = changeStock(player, data, potion.Id, 1)
		print(`[PotionService] test : {player.Name} a {count} potion(s) {potion.Id} dans son inventaire`)
	elseif command == "clear" then
		for uid in table.clone(state.Potions) do
			removePotion(player, state, uid)
		end
		clearEffects(player, state)
		print(`[PotionService] test : potions et effets de {player.Name} retirés`)
	else
		warn(`[PotionService] test « {value} » : commande inconnue (spawn <Id>, give <Id>, stock <Id>, clear)`)
	end
end

------------------------------------------------------------------------------
-- Démarrage
------------------------------------------------------------------------------

function PotionService.Init()
	installHooks()
	Net.Server.PickPotion:Connect(onPickPotion)
	Net.Server.UsePotion:Connect(onUsePotion)
	DataService.OnProfileLoaded(onProfileLoaded)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	RunService.Heartbeat:Connect(step)
	if IS_STUDIO then
		Workspace:GetAttributeChangedSignal(TEST_ATTRIBUTE):Connect(onTestAttribute)
	end
	log(`{#Potions.List} potions, {Potions.MaxPerPlayer} au plus par joueur, une toutes les {Potions.SpawnEvery} s`)
end

return PotionService
