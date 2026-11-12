--!strict
-- BatService (DEV-043, DEV-048) : le coup de batte et les colis qu'il fait tomber (Partie 1,
-- sections 5.6, 6.1, 6.2, 6.4 et 9.4 ; valeurs : Config/Bat). La batte elle-même (Tool en slot 2,
-- attribut BatTool) est donnée par ToolService ; le client (BatController) joue SwingBat et envoie
-- le coup. Rien de ce qui compte ne vient du client : SwingBat n'a aucun argument, le serveur
-- choisit la cible.
--
-- SwingBat (9.4), vérifié ici dans cet ordre :
--   1. recharge : Bat.Cooldown (0,8 s) depuis le dernier SwingBat accepté, à COOLDOWN_TOLERANCE près
--      (réseau). Un coup refusé par la recharge ne la relance pas ; un coup dans le vide, si ;
--   2. le frappeur : vivant, la batte en main (ToolService.IsHoldingBat), mains vides (pas de
--      portage), pas étourdi par la batte ;
--   3. la cible, choisie par le serveur parmi les autres joueurs vivants :
--      - à Bat.Range (7) studs au plus, entre les deux HumanoidRootPart ;
--      - devant le frappeur : à Bat.FrontHalfAngle (60°) au plus de son regard, à l'horizontale,
--        sauf plus près que Bat.PointBlankRange (3) studs (corps contre corps) ;
--      - sans mur entre eux (rayon qui ignore personnages, vigiles, colis au sol, et tout ce qui
--        ne bloque pas : RespectCanCollide) ;
--      - qui porte quelque chose (CarryService.GetPayload) :
--          usage 1 : un objet volé AU FRAPPEUR (PlayerItem, VictimUserId = frappeur) : partout,
--                    même en zone safe ;
--          usage 2 : un colis PNJ (NPCBox, colis du camion compris) : ni le frappeur ni la cible en
--                    zone safe (tag SafeZone), et la cible pas sous bouclier débutant (6.4 :
--                    « les autres ne peuvent pas faire tomber son colis »,
--                    NightCycleService.IsShielded) ;
--          intrus (Cantin, 2026-11-12) : la cible est dans le volume Bounds de la boutique du
--                    frappeur, qu'elle porte quelque chose ou non : partout, même en zone safe (les
--                    boutiques sont dans le hub). Décidé par BatService.IsIntruder, point d'accroche
--                    remplacé par PvPService (false par défaut). Seul le propriétaire est concerné :
--                    les coups d'un autre joueur gardent les règles ci-dessus ;
--          tiers : un objet volé à quelqu'un d'autre (PlayerItem) : ni l'un ni l'autre en zone safe.
--          Le bouclier débutant ne protège pas un voleur ni un intrus (usage 1, intrus et tiers) : 6.4
--          ne parle que de « son colis », et sinon un débutant qui vole serait intouchable ;
--      - pas frappée il y a moins de Bat.HitImmunity (3) s (6.4, pas d'acharnement).
--      Plusieurs cibles possibles : le voleur du frappeur d'abord (usage 1), sinon la plus proche.
--      Un seul coup réussi suffit, une seule cible par coup. Personne : coup dans le vide (rien ;
--      en Studio, une ligne avec la raison du refus de chaque joueur à REFUSAL_LOG_RANGE fois la
--      portée au plus). Coup dans le vide alors qu'une cible à portée a été refusée pour son
--      bouclier : Notify au frappeur (Bat.Messages.TargetShielded), au plus toutes les
--      SHIELD_NOTICE_INTERVAL s.
--
-- L'effet, dans cet ordre (aucune attente entre le choix de la cible et le Drop) :
--   - immunité de la cible pour Bat.HitImmunity s ;
--   - colis PNJ (usage 2) : CarryService.Drop au point du sol sous la cible (rayon vers le bas,
--     sinon ses pieds) : le colis tombe là avec sa couleur, son halo et son étiquette, et le vigile
--     qui la poursuivait le suit (GuardService). Puis knockback : LinearVelocity posée dans son
--     HumanoidRootPart (Attachment KNOCKBACK_NAME), Bat.KnockbackHorizontalSpeed dans le sens du
--     coup + Bat.KnockbackVerticalSpeed vers le haut, pendant Bat.KnockbackDuration s (son client la
--     simule, il possède son personnage) ; Notify Bat.Messages.BoxKnockedDown à la cible ;
--   - objet volé (usage 1 et tiers) : CarryService.Drop, qui fait échouer le portage
--     (Fail(…, "Bat")) : l'objet ne tombe pas, PvPService le rend à son présentoir (6.1, 6.2) en
--     écoutant OnCarryEnded. Pas de knockback ;
--   - intrus : rien ne tombe (ce qu'il porte d'une autre boutique reste sur sa tête), pas de knockback ;
--     PvPService le sort de la boutique (OnHit) ;
--   - étourdissement de Bat.StunDuration s : vitesse à 0 (StatsService, clé STUN_KEY), attribut
--     STUN_ATTRIBUTE du Player = "Knockback" (usage 2) ou "Stun" (sinon), retiré à la fin : son
--     client joue Knockback puis Stunned, ou Stunned seule (BatController). Étourdi, il ne frappe
--     pas et ne ramasse rien ;
--   - OnHit(hitter, target, usage, payload) pour les autres services (PvPService : défense réussie).
--
-- Colis tombé au sol (6.2) : GrabDropped(dropId) (9.4), pour les colis posés par un coup de batte
-- seulement (ceux du camion restent à TruckEventService, qui ignore les autres). En deux appels,
-- comme GrabItem : le client l'envoie au début du maintien de l'invite, puis quand elle se
-- déclenche. Vérifié : colis encore au sol (CarryService.GetDrop), mains vides, joueur vivant, pas
-- étourdi, hors zone safe, à Bat.DroppedGrabMaxDistance (8) studs au plus du colis, maintien de
-- Bat.DroppedGrabTime (0,5 s, quel que soit le type) à GRAB_TIME_TOLERANCE près ; tout revérifié
-- 10 fois par seconde pendant le maintien, qui expire HOLD_EXPIRY s après sa durée. N'importe qui
-- peut le prendre, le frappeur n'a aucune priorité. Alors CarryService.PickUpDrop : même payload,
-- même contenu ; le vigile qui suivait le colis poursuit le nouveau porteur (GuardService). Pas
-- ramassé en Bat.DroppedLifetime (15) s : CarryService le retire et StoreHeistService le renvoie
-- sur son rayon (OnDropExpired).
--
-- Posé par ce service (mêmes noms dans BatController) : attribut STUN_ATTRIBUTE du Player,
-- Attachment KNOCKBACK_NAME dans le HumanoidRootPart pendant la poussée. Les colis au sol portent
-- DropId, Tier et BatDrop (CarryService).
--
-- API (serveur) :
--   BatService.IsStunned(player) -> boolean     étourdi par un coup de batte
--   BatService.OnHit(listener) -> déconnexion
--       listener(hitter, target, usage, payload?) après chaque coup réussi, l'effet déjà appliqué
--       (portage de la cible fini). usage = "Defend" (usage 1), "Box" (usage 2), "Intruder" (intrus
--       dans la boutique du frappeur ; payload nil s'il ne porte rien) ou "Thief" (tiers).
--   BatService.IsIntruder(hitter, target) -> boolean
--       Point d'accroche (comme WindowService.CanBeHit) : `target` est-il un intrus que `hitter` peut
--       frapper chez lui ? false par défaut ; PvPService le remplace (target dans Bounds de la boutique
--       de hitter). Appelé à chaque coup, sans yield.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Bat = require(Shared.Config.Bat)
local Net = require(Shared.Net.Net)
local CarryTypes = require(Shared.Types.Carry)

local AntiCheatService = require(script.Parent.AntiCheatService)
local CarryService = require(script.Parent.CarryService)
local NightCycleService = require(script.Parent.NightCycleService)
local StatsService = require(script.Parent.StatsService)
local ToolService = require(script.Parent.ToolService)

type Payload = CarryTypes.Payload

export type Usage = "Defend" | "Box" | "Intruder" | "Thief"
export type HitListener = (hitter: Player, target: Player, usage: Usage, payload: Payload?) -> ()

-- Une cible possible d'un coup.
type Candidate = {
	player: Player,
	root: BasePart,
	humanoid: Humanoid,
	payload: Payload?, -- nil : un intrus qui ne porte rien
	usage: Usage,
	distance: number,
}

type Hold = { DropId: string, StartedAt: number }

-- Noms du contrat (2.1) lus ici.
local SAFE_ZONE_TAG = "SafeZone"
local BOUNDS_NAME = "Bounds"
local INBOX_NAME = "_INBOX_CLEMENT" -- livraisons de Clément : pas encore dans la map
-- Dossiers posés par d'autres services, ignorés par les rayons.
local ACTIVE_GUARDS = "ActiveGuards" -- GuardService
local DROPS_FOLDER = "CarryDrops" -- CarryService

-- Posés par ce service, lus par BatController (mêmes noms là-bas).
local STUN_ATTRIBUTE = "BatStun"
local KNOCKBACK_NAME = "BatKnockback"
-- Modificateur de vitesse de StatsService pendant l'étourdissement.
local STUN_KEY = "BatStun"

-- V0 proposé, absent du doc : écarts du réseau tolérés sur la recharge et sur le maintien.
local COOLDOWN_TOLERANCE = 0.1
local GRAB_TIME_TOLERANCE = 0.1
-- V0 proposé, absent du doc : un maintien non conclu expire 1 s après sa durée (comme GrabItem).
local HOLD_EXPIRY = 1
-- V0 proposé, absent du doc : maintiens revérifiés 10 fois par seconde.
local TICK = 0.1
-- V0 proposé, absent du doc : sol cherché jusqu'à 50 studs sous le HumanoidRootPart de la cible.
local GROUND_RAY_DOWN = 50
-- V0 proposé, absent du doc : au plus un Notify « bouclier » toutes les 3 s par frappeur.
local SHIELD_NOTICE_INTERVAL = 3
local SHIELD_REFUSAL = "bouclier débutant"
-- V0 proposé, absent du doc : un coup dans le vide note dans la sortie (Studio) les joueurs à deux
-- fois la portée au plus, avec la raison du refus.
local REFUSAL_LOG_RANGE = 2

local FRONT_MIN_DOT = math.cos(math.rad(Bat.FrontHalfAngle))

local IS_STUDIO = RunService:IsStudio()

local BatService = {}

local lastSwingAt: { [Player]: number } = {}
local immuneUntil: { [Player]: number } = {}
local stunTokens: { [Player]: number } = {}
local batDrops: { [string]: boolean } = {} -- colis posés au sol par un coup de batte, encore au sol
local holds: { [Player]: Hold } = {}
local lastRefusal: { [Player]: number } = {}
local lastShieldNotice: { [Player]: number } = {}
local hitListeners: { HitListener } = {}
local boxCache: { [Instance]: { cframe: CFrame, size: Vector3 } } = setmetatable({}, { __mode = "k" }) :: any

-- Outils ----------------------------------------------------------------------------------------

local function log(message: string)
	if IS_STUDIO then
		print(`[BatService] {message}`)
	end
end

-- Refus signalé en Studio seulement (aide au test), une ligne par seconde et par joueur.
local function refuse(player: Player, message: string)
	if not IS_STUDIO then
		return
	end
	local now = os.clock()
	if now - (lastRefusal[player] or -math.huge) < 1 then
		return
	end
	lastRefusal[player] = now
	warn(`[BatService] {player.Name} : {message}`)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- HumanoidRootPart et Humanoid vivant d'un joueur, sinon nil.
local function bodyOf(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if character == nil or not character:IsDescendantOf(Workspace) then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil, nil
	end
	return root :: BasePart, humanoid
end

local function inMap(instance: Instance): boolean
	if not instance:IsDescendantOf(Workspace) then
		return false
	end
	local inbox = Workspace:FindFirstChild(INBOX_NAME)
	return inbox == nil or not instance:IsDescendantOf(inbox)
end

local function insideBox(cframe: CFrame, size: Vector3, position: Vector3): boolean
	local p = cframe:PointToObjectSpace(position)
	return math.abs(p.X) <= size.X / 2 and math.abs(p.Y) <= size.Y / 2 and math.abs(p.Z) <= size.Z / 2
end

-- Dans un volume taggé SafeZone : la pièce elle-même, sinon son enfant direct Bounds, sinon la boîte
-- englobante du modèle (même règle que GuardService et TruckEventService).
local function isInSafeZone(position: Vector3): boolean
	for _, instance in CollectionService:GetTagged(SAFE_ZONE_TAG) do
		if not inMap(instance) then
			continue
		end
		local part: Instance? = if instance:IsA("BasePart") then instance else instance:FindFirstChild(BOUNDS_NAME)
		if part and part:IsA("BasePart") then
			local box = part :: BasePart
			if insideBox(box.CFrame, box.Size, position) then
				return true
			end
		elseif instance:IsA("Model") then
			local cached = boxCache[instance]
			if cached == nil then
				local cframe, size = (instance :: Model):GetBoundingBox()
				cached = { cframe = cframe, size = size }
				boxCache[instance] = cached
			end
			if insideBox(cached.cframe, cached.size, position) then
				return true
			end
		end
	end
	return false
end

-- Rayons du coup : ni les personnages, ni les vigiles, ni les colis au sol ; ce qui ne bloque pas
-- (volumes Bounds et SafeZone, vitre cassée, colis porté) ne cache rien.
local function rayParams(): RaycastParams
	local exclude: { Instance } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			table.insert(exclude, character)
		end
	end
	for _, name in { ACTIVE_GUARDS, DROPS_FOLDER } do
		local folder = Workspace:FindFirstChild(name)
		if folder then
			table.insert(exclude, folder)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true
	params.IgnoreWater = true
	return params
end

local function shielded(player: Player): boolean
	local ok, value = pcall(NightCycleService.IsShielded, player)
	if not ok then
		warn(`[BatService] IsShielded({player.Name}) : {value} (joueur considéré comme protégé)`)
		return true
	end
	return value == true
end

-- Point d'accroche (voir l'en-tête), remplacé par PvPService.
function BatService.IsIntruder(_hitter: Player, _target: Player): boolean
	return false
end

local function isIntruder(hitter: Player, target: Player): boolean
	local ok, value = pcall(BatService.IsIntruder, hitter, target)
	if not ok then
		warn(`[BatService] IsIntruder({hitter.Name}, {target.Name}) : {value}`)
		return false
	end
	return value == true
end

function BatService.IsStunned(player: Player): boolean
	return stunTokens[player] ~= nil
end

function BatService.OnHit(listener: HitListener): () -> ()
	table.insert(hitListeners, listener)
	return function()
		local index = table.find(hitListeners, listener)
		if index then
			table.remove(hitListeners, index)
		end
	end
end

-- Le coup ----------------------------------------------------------------------------------------

-- `other` peut-il recevoir le coup de `hitter` ? Renvoie la cible, ou la raison du refus.
local function candidateFor(
	hitter: Player,
	hitterRoot: BasePart,
	hitterSafe: boolean,
	other: Player,
	now: number
): (Candidate?, string)
	local root, humanoid = bodyOf(other)
	if root == nil or humanoid == nil then
		return nil, "pas de personnage vivant"
	end
	local offset = root.Position - hitterRoot.Position
	local distance = offset.Magnitude
	if distance > Bat.Range then
		return nil, `trop loin ({math.round(distance * 10) / 10} studs)`
	end
	local flatOffset = flat(offset)
	local look = flat(hitterRoot.CFrame.LookVector)
	if flatOffset.Magnitude >= Bat.PointBlankRange and look.Magnitude > 1e-3 then
		if flatOffset.Unit:Dot(look.Unit) < FRONT_MIN_DOT then
			return nil, "pas devant le frappeur"
		end
	end
	local payload = CarryService.GetPayload(other)
	local usage: Usage
	if payload and payload.Kind == "PlayerItem" and payload.VictimUserId == hitter.UserId then
		usage = "Defend" -- usage 1 : même en zone safe
	elseif isIntruder(hitter, other) then
		usage = "Intruder" -- dans la boutique du frappeur : même en zone safe, même mains vides
	elseif payload == nil then
		return nil, "ne porte rien"
	elseif hitterSafe or isInSafeZone(root.Position) then
		return nil, "zone safe"
	elseif payload.Kind == "NPCBox" or payload.Kind == "NPCItem" then
		-- L-112 : l'objet sorti d'un colis ouvert sur le rayon tombe au sol comme un colis (bouclier compris).
		if shielded(other) then
			return nil, SHIELD_REFUSAL
		end
		usage = "Box"
	else
		usage = "Thief"
	end
	if (immuneUntil[other] or -math.huge) > now then
		return nil, `immunité de {Bat.HitImmunity} s`
	end
	if distance > 1e-3 and Workspace:Raycast(hitterRoot.Position, offset, rayParams()) ~= nil then
		return nil, "un mur entre eux"
	end
	return {
		player = other,
		root = root,
		humanoid = humanoid,
		payload = payload,
		usage = usage,
		distance = distance,
	},
		""
end

-- Point du sol sous la cible (là où son colis tombe), sinon ses pieds.
local function groundBelow(root: BasePart, humanoid: Humanoid): Vector3
	local origin = root.Position
	local result = Workspace:Raycast(origin, Vector3.new(0, -GROUND_RAY_DOWN, 0), rayParams())
	if result then
		return result.Position
	end
	return origin - Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)
end

-- Poussée dans le sens du coup : une LinearVelocity posée par le serveur, que le client de la cible
-- simule (il possède son personnage), retirée après Bat.KnockbackDuration s.
local function knockback(root: BasePart, direction: Vector3)
	local attachment = Instance.new("Attachment")
	attachment.Name = KNOCKBACK_NAME
	local mover = Instance.new("LinearVelocity")
	mover.Name = KNOCKBACK_NAME
	mover.Attachment0 = attachment
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	mover.MaxForce = math.huge
	mover.VectorVelocity = direction * Bat.KnockbackHorizontalSpeed + Vector3.new(0, Bat.KnockbackVerticalSpeed, 0)
	mover.Parent = attachment
	attachment.Parent = root
	Debris:AddItem(attachment, Bat.KnockbackDuration)
end

-- Étourdi Bat.StunDuration s : vitesse à 0, attribut pour son client ; un nouvel appel remplace le
-- précédent.
local function stun(player: Player, kind: string)
	local token = (stunTokens[player] or 0) + 1
	stunTokens[player] = token
	StatsService.SetSpeedModifier(player, STUN_KEY, 0)
	player:SetAttribute(STUN_ATTRIBUTE, kind)
	task.delay(Bat.StunDuration, function()
		if stunTokens[player] ~= token then
			return
		end
		stunTokens[player] = nil
		StatsService.SetSpeedModifier(player, STUN_KEY, nil)
		if player.Parent == Players then
			player:SetAttribute(STUN_ATTRIBUTE, nil)
		end
	end)
end

local function applyHit(hitter: Player, hitterRoot: BasePart, target: Candidate, now: number)
	local player = target.player
	immuneUntil[player] = now + Bat.HitImmunity
	local direction = flat(target.root.Position - hitterRoot.Position)
	if direction.Magnitude < 1e-3 then
		direction = flat(hitterRoot.CFrame.LookVector)
	end
	direction = if direction.Magnitude > 1e-3 then direction.Unit else Vector3.new(0, 0, -1)
	local payload = target.payload
	if target.usage == "Box" and payload then
		local dropId = CarryService.Drop(player, groundBelow(target.root, target.humanoid))
		if dropId then
			batDrops[dropId] = true
		end
		AntiCheatService.Allow(player, Bat.KnockbackDuration, "BatService (knockback)") -- poussée du code (DEV-060)
		knockback(target.root, direction)
		stun(player, "Knockback")
		Net.Server.Notify:Fire(player, Bat.Messages.BoxKnockedDown, "Alert") -- avertissement, pas un refus : sans UI_Deny (L-106 point 6)
		log(`{hitter.Name} frappe {player.Name} : colis {payload.Rarity} au sol ({dropId or "?"})`)
	elseif target.usage == "Intruder" then
		-- Rien ne tombe : PvPService le sort de la boutique (OnHit).
		stun(player, "Stun")
		log(`{hitter.Name} frappe l'intrus {player.Name} dans sa boutique`)
	else
		local ground = groundBelow(target.root, target.humanoid)
		-- Objet volé : il ne tombe pas, PvPService le rend à son présentoir (OnCarryEnded « Bat »).
		CarryService.Drop(player, ground)
		stun(player, "Stun")
		log(`{hitter.Name} frappe {player.Name} ({target.usage}) : l'objet volé retourne chez son propriétaire`)
	end
	for _, listener in table.clone(hitListeners) do
		task.spawn(listener, hitter, player, target.usage, target.payload)
	end
end

local function onSwingBat(player: Player)
	local now = os.clock()
	if now - (lastSwingAt[player] or -math.huge) + COOLDOWN_TOLERANCE < Bat.Cooldown then
		refuse(player, "SwingBat refusé : recharge")
		return
	end
	local root, humanoid = bodyOf(player)
	if root == nil or humanoid == nil then
		return
	end
	if not AntiCheatService.Verify(player) then
		refuse(player, "SwingBat refusé : déplacement sanctionné par l'anti-triche (audit 9.8)")
		return -- téléporté juste avant le coup : vu avant d'agir, pas 0,25 s après
	end
	if not ToolService.IsHoldingBat(player) then
		refuse(player, "SwingBat refusé : batte pas en main")
		return
	end
	if CarryService.IsCarrying(player) then
		refuse(player, "SwingBat refusé : porte quelque chose")
		return
	end
	if stunTokens[player] ~= nil then
		refuse(player, "SwingBat refusé : étourdi")
		return
	end
	lastSwingAt[player] = now

	local hitterSafe = isInSafeZone(root.Position)
	local best: Candidate? = nil
	local refusals: { string } = {} -- joueurs à portée refusés, pour la sortie
	local shieldRefused = false
	for _, other in Players:GetPlayers() do
		if other == player then
			continue
		end
		local candidate, reason = candidateFor(player, root, hitterSafe, other, now)
		if candidate then
			local current = best
			if
				current == nil
				or (candidate.usage == "Defend" and current.usage ~= "Defend")
				or (
					(candidate.usage == "Defend") == (current.usage == "Defend")
					and candidate.distance < current.distance
				)
			then
				best = candidate
			end
		else
			local otherRoot = bodyOf(other)
			if otherRoot and (otherRoot.Position - root.Position).Magnitude <= Bat.Range * REFUSAL_LOG_RANGE then
				table.insert(refusals, `{other.Name} : {reason}`)
				shieldRefused = shieldRefused or reason == SHIELD_REFUSAL
			end
		end
	end
	local target = best
	if target == nil then
		if #refusals > 0 then
			log(`{player.Name} frappe dans le vide ({table.concat(refusals, " ; ")})`)
		end
		if shieldRefused and now - (lastShieldNotice[player] or -math.huge) >= SHIELD_NOTICE_INTERVAL then
			lastShieldNotice[player] = now
			Net.Server.Notify:Fire(player, Bat.Messages.TargetShielded, "Info")
		end
		return
	end
	applyHit(player, root, target, now)
end

-- Colis tombé au sol ---------------------------------------------------------------------------------

-- Raison du refus d'une prise du colis `dropId` par `player`, ou nil si elle est permise maintenant.
local function grabRefusal(player: Player, dropId: string): string?
	local payload, position = CarryService.GetDrop(dropId)
	if payload == nil or position == nil then
		return "colis plus au sol"
	end
	if CarryService.IsCarrying(player) then
		return "mains pleines"
	end
	local root = bodyOf(player)
	if root == nil then
		return "pas de personnage vivant"
	end
	if stunTokens[player] ~= nil then
		return "étourdi"
	end
	if isInSafeZone(root.Position) then
		return "en zone safe"
	end
	local distance = (root.Position - position).Magnitude
	if distance > Bat.DroppedGrabMaxDistance then
		return `trop loin ({math.round(distance * 10) / 10} studs)`
	end
	return nil
end

local function grant(player: Player, dropId: string)
	if not CarryService.PickUpDrop(player, dropId) then
		refuse(player, `GrabDropped sur « {dropId} » refusé : CarryService a refusé le ramassage`)
		return
	end
	batDrops[dropId] = nil
	log(`{player.Name} ramasse le colis tombé {dropId}`)
end

-- GrabDropped(dropId) : premier appel = début du maintien, second = fin (comme GrabItem).
local function onGrabDropped(player: Player, dropId: string)
	-- L-112 : l'objet lâché par un joueur attrapé (CarryService.Fail « Caught ») se ramasse comme un colis
	-- tombé d'un coup de batte, par les mêmes règles.
	if not batDrops[dropId] and not CarryService.IsFallenDrop(dropId) then
		return -- pas un colis tombé des mains d'un porteur : laissé au service qui l'a posé (camion)
	end
	if not AntiCheatService.Verify(player) then
		refuse(player, `GrabDropped sur « {dropId} » refusé : déplacement sanctionné par l'anti-triche (audit 9.8)`)
		return
	end
	local hold = holds[player]
	local reason = grabRefusal(player, dropId)
	if reason then
		if hold and hold.DropId == dropId then
			holds[player] = nil
		end
		refuse(player, `GrabDropped sur « {dropId} » refusé : {reason}`)
		return
	end
	local now = os.clock()
	if hold and hold.DropId == dropId then
		local elapsed = now - hold.StartedAt
		if elapsed + GRAB_TIME_TOLERANCE >= Bat.DroppedGrabTime then
			holds[player] = nil
			grant(player, dropId)
		else
			refuse(player, `GrabDropped sur « {dropId} » refusé : maintien trop court ({math.round(elapsed * 100) / 100} s sur {Bat.DroppedGrabTime} s)`)
		end
		return
	end
	if Bat.DroppedGrabTime <= 0 then
		holds[player] = nil
		grant(player, dropId)
		return
	end
	holds[player] = { DropId = dropId, StartedAt = now }
end

local function onDropExpired(dropId: string, _payload: any, _position: Vector3)
	if batDrops[dropId] then
		batDrops[dropId] = nil
		log(`colis tombé {dropId} jamais ramassé : retiré du sol (StoreHeistService le renvoie sur son rayon)`)
	end
end

local function step()
	local now = os.clock()
	for player, hold in holds do
		if now - hold.StartedAt > Bat.DroppedGrabTime + HOLD_EXPIRY or grabRefusal(player, hold.DropId) ~= nil then
			holds[player] = nil
		end
	end
	for dropId in batDrops do
		if CarryService.GetDrop(dropId) == nil then
			batDrops[dropId] = nil -- ramassé ou retiré ailleurs
		end
	end
end

-- Démarrage --------------------------------------------------------------------------------------

function BatService.Init()
	Net.Server.SwingBat:Connect(onSwingBat)
	Net.Server.GrabDropped:Connect(onGrabDropped)
	CarryService.OnDropExpired(onDropExpired)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastSwingAt[player] = nil
		immuneUntil[player] = nil
		stunTokens[player] = nil
		holds[player] = nil
		lastRefusal[player] = nil
		lastShieldNotice[player] = nil
	end)
end

function BatService.Start()
	print(
		`[BatService] batte : portée {Bat.Range} studs, recharge {Bat.Cooldown} s, étourdissement {Bat.StunDuration} s, colis au sol {Bat.DroppedLifetime} s`
	)
	while true do
		task.wait(TICK)
		xpcall(step, function(err: any)
			warn(`[BatService] tick : {err}\n{debug.traceback()}`)
		end)
	end
end

return BatService
