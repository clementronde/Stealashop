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
-- Potions.PickupMaxDistance studs au plus de la potion. Sinon rien (une ligne en Studio). Accepté :
-- PotionRemoved, effet appliqué, Notify « Success » au joueur (« Speed ×2 for 2:00! », durée qui reste en
-- tout), télémétrie (événement PotionPicked, champ « Potion - <Id> »).
--
-- Effets : attribut du Player Potions.AttributePrefix .. Id (« Potion_Speed ») = heure serveur de fin
-- (Workspace:GetServerTimeNow()), retiré à la fin. Durée = Potion.Duration × l'effet de PotionTime (1 sans
-- achat) ; même type déjà actif : la durée s'ajoute à ce qui reste. Mort (Humanoid.Died) ou départ : tous les
-- effets sont retirés (les potions posées restent pour un mort). Branchés sur les points d'accroche, chacun
-- gardé et rappelé (jamais écrasé), relus à chaque usage :
--   Speed         StatsService.SetSpeedModifier(player, "Potion", Multiplier) : × la WalkSpeed, toujours
--                 plafonnée à Balance.Stats.MaxWalkSpeed (70) par StatsService. L'anti-triche suit la
--                 Humanoid.WalkSpeed appliquée (AntiCheatService, vitesse autorisée) : rien à lui dire.
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
--
-- Tester dans Studio (barre de commande serveur ; hors de Studio, l'attribut n'est pas écouté) :
--   workspace:SetAttribute("PotionTest", "<joueur> spawn Speed")   une potion de ce type à TEST_SPAWN_DISTANCE
--                                                                   studs devant lui (hors plafond)
--   workspace:SetAttribute("PotionTest", "<joueur> give Money")    l'effet tout de suite, sans potion
--   workspace:SetAttribute("PotionTest", "<joueur> clear")         retire ses potions et ses effets
-- (joueur = nom ou UserId).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Potions = require(Shared.Config.Potions)
local Net = require(Shared.Net.Net)

local DataService = require(script.Parent.DataService)
local DisplayService = require(script.Parent.DisplayService)
local GuardService = require(script.Parent.GuardService)
local NightCycleService = require(script.Parent.NightCycleService)
local SkillTreeService = require(script.Parent.SkillTreeService)
local StatsService = require(script.Parent.StatsService)
local TelemetryService = require(script.Parent.TelemetryService)
local WindowService = require(script.Parent.WindowService)

type Potion = Potions.Potion

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
		StatsService.SetSpeedModifier(player, SPEED_KEY, potion.Multiplier or 1)
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

local function notify(player: Player, message: string)
	local ok, err = pcall(function()
		Net.Server.Notify:Fire(player, message, NOTIFY_KIND)
	end)
	if not ok then
		warn(`[PotionService] Notify vers {player.Name} : {err}`)
	end
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
	removePotion(player, state, uid)
	if potion == nil then
		return
	end
	local remaining = applyEffect(player, state, potion)
	notify(player, effectMessage(potion, remaining))
	TelemetryService.LogEvent(player, TELEMETRY_EVENT, { `Potion - {potion.Id}` })
	log(`{player.Name} ramasse {potion.Id} ({uid}) : {math.round(remaining)} s`)
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
	states[player] = { Potions = {}, Count = 0, TimerStart = now(), Effects = {}, Died = nil }
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
	elseif command == "clear" then
		for uid in table.clone(state.Potions) do
			removePotion(player, state, uid)
		end
		clearEffects(player, state)
		print(`[PotionService] test : potions et effets de {player.Name} retirés`)
	else
		warn(`[PotionService] test « {value} » : commande inconnue (spawn <Id>, give <Id>, clear)`)
	end
end

------------------------------------------------------------------------------
-- Démarrage
------------------------------------------------------------------------------

function PotionService.Init()
	installHooks()
	Net.Server.PickPotion:Connect(onPickPotion)
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
