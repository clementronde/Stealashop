--!strict
-- ZoneGateController (client) : les arches de zone et la zone où se trouve le joueur local (liaison
-- L-110 ; avant : L-071, point 9).
--
-- Depuis L-110 (Clément, 2026-11-12), les arches n'ont plus de panneau : BB_ZoneGate est sorti de
-- ReplicatedStorage/Assets/UI, SignPart est gardé mais transparent, SignLeft et SignRight sont éteints
-- par Clément. Ce contrôleur n'affiche donc plus rien et ne touche plus à aucune arche. Il garde son
-- autre rôle : suivre les arches de la map (Model taggé ZoneGate, dans le Workspace hors
-- _INBOX_CLEMENT, attribut Zone de 1 à 6) et dire quand le joueur local en passe une. C'est
-- ZoneBannerController qui allume alors le bandeau UI_ZoneBanner. Rien n'est envoyé au serveur.
--
-- Zone du joueur local :
--   - chaque arche donne un point (son pivot, en bas au centre : contrat des modèles), gardé en
--     mémoire même quand l'arche sort du streaming ;
--   - l'axe du couloir va de l'arche connue de la plus petite zone à celle de la plus grande (à plat,
--     sans la hauteur) ; avec une seule arche connue, de la zone safe (tag SafeZone) vers cette arche,
--     comme TutorialService pour l'étape « passer l'arche » ; sans axe, la zone ne change pas ;
--   - le joueur est dans la zone n s'il a dépassé l'arche n le long de cet axe (la plus grande zone
--     dépassée) ; 0 avant la première arche (hub) ;
--   - un changement n'est pris qu'à GATE_MARGIN studs au-delà de la ligne de l'arche, dans un sens
--     comme dans l'autre : rester debout sous l'arche ne fait pas clignoter la zone ;
--   - la première zone lue (arrivée dans le jeu), et celle relue quand une arche jusque-là inconnue
--     arrive par le streaming, sont prises sans prévenir personne : pas de bandeau sans passage.
-- Une réapparition ou un retour à la base ramène à la zone 0 (prévenu, mais ZoneBannerController
-- n'affiche rien pour le hub).
--
-- API (client) :
--   ZoneGateController.GetZone() -> number
--       Zone du joueur local, de 0 (hub, ou pas encore connue) à 6.
--   ZoneGateController.OnZoneChanged(callback) -> () -> ()
--       callback(zone, previous) à chaque passage d'arche, dans les deux sens. Renvoie la fonction
--       qui retire l'écoute.
--   ZoneGateController.GetGates() -> { GateInfo }
--       Arches suivies, triées par zone, pour un test dans Studio : { Gate, Zone }.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Zones = require(Shared:WaitForChild("Config"):WaitForChild("Zones"))
local Attributes = require(Shared:WaitForChild("Contract"):WaitForChild("Attributes"))

export type GateInfo = {
	Gate: string,
	Zone: number,
}

type Listener = (zone: number, previous: number) -> ()

local GATE_TAG = "ZoneGate" -- contrat 2.1
local SAFE_ZONE_TAG = "SafeZone" -- contrat 2.1
local INBOX_NAME = "_INBOX_CLEMENT" -- livraisons pas encore posées : ignorées

-- V0 proposés, absents du doc :
local CHECK_INTERVAL = 0.1 -- s entre deux lectures de la position du joueur
local GATE_MARGIN = 2 -- studs au-delà de la ligne d'une arche pour changer de zone (aller et retour)

local IS_STUDIO = RunService:IsStudio()

local localPlayer = Players.LocalPlayer

local ZoneGateController = {}

local gates: { [Instance]: number } = {} -- arche suivie → sa zone
local positions: { [number]: Vector3 } = {} -- zone → point de son arche (gardé hors streaming)
local currentZone: number? = nil -- nil : à relire sans prévenir
local listeners: { Listener } = {}
local said: { [string]: boolean } = {}

local function sayOnce(key: string, message: string)
	if not IS_STUDIO or said[key] then
		return
	end
	said[key] = true
	warn(`[ZoneGateController] {message}`)
end

local function inMap(instance: Instance): boolean
	if not instance:IsDescendantOf(Workspace) then
		return false
	end
	local inbox = Workspace:FindFirstChild(INBOX_NAME)
	return inbox == nil or not instance:IsDescendantOf(inbox)
end

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function safeZonePosition(): Vector3?
	for _, instance in CollectionService:GetTagged(SAFE_ZONE_TAG) do
		if inMap(instance) then
			if instance:IsA("BasePart") then
				return instance.Position
			elseif instance:IsA("Model") then
				return instance:GetPivot().Position
			end
		end
	end
	return nil
end

-- Axe du couloir, à plat, dans le sens des zones croissantes ; nil tant qu'on ne peut pas le dire.
local function corridorAxis(): Vector3?
	local low, high = math.huge, 0
	for zone in positions do
		low = math.min(low, zone)
		high = math.max(high, zone)
	end
	if high == 0 then
		return nil
	end
	local from: Vector3? = positions[low]
	if low == high then
		from = safeZonePosition()
	end
	if not from then
		return nil
	end
	local axis = flat(positions[high] - from)
	if axis.Magnitude < 1 then
		return nil
	end
	return axis.Unit
end

-- Plus grande zone dont l'arche est dépassée d'au moins `margin` studs le long de l'axe ; 0 sinon.
local function zoneAt(position: Vector3, axis: Vector3, margin: number): number
	local best = 0
	for zone, at in positions do
		if zone > best and flat(position - at):Dot(axis) >= margin then
			best = zone
		end
	end
	return best
end

local function rootPosition(): Vector3?
	local character = localPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end

local function update()
	local position = rootPosition()
	if not position then
		return
	end
	local axis = corridorAxis()
	if not axis then
		return
	end
	local previous = currentZone
	if previous == nil then
		currentZone = zoneAt(position, axis, 0)
		return
	end
	local now = previous
	local entered = zoneAt(position, axis, GATE_MARGIN)
	if entered > previous then
		now = entered
	else
		local kept = zoneAt(position, axis, -GATE_MARGIN)
		if kept < previous then
			now = kept
		end
	end
	if now == previous then
		return
	end
	currentZone = now
	for _, listener in table.clone(listeners) do
		task.spawn(listener, now, previous)
	end
end

local function track(instance: Instance)
	if gates[instance] ~= nil or not instance:IsA("Model") or not inMap(instance) then
		return
	end
	local zone = instance:GetAttribute(Attributes.Zone.Name)
	if type(zone) ~= "number" or Zones[zone] == nil then
		sayOnce(`zone:{instance:GetFullName()}`, `{instance:GetFullName()} : attribut {Attributes.Zone.Name} invalide ({zone}), arche ignorée`)
		return
	end
	gates[instance] = zone
	if not positions[zone] then
		currentZone = nil -- une arche de plus est connue : la zone est relue sans prévenir
	end
	positions[zone] = instance:GetPivot().Position
end

local function untrack(instance: Instance)
	gates[instance] = nil -- son point reste en mémoire (streaming)
end

-- API -----------------------------------------------------------------------------------------------

function ZoneGateController.GetZone(): number
	return currentZone or 0
end

function ZoneGateController.OnZoneChanged(callback: Listener): () -> ()
	table.insert(listeners, callback)
	return function()
		local index = table.find(listeners, callback)
		if index then
			table.remove(listeners, index)
		end
	end
end

function ZoneGateController.GetGates(): { GateInfo }
	local list: { GateInfo } = {}
	for gate, zone in gates do
		table.insert(list, { Gate = gate.Name, Zone = zone })
	end
	table.sort(list, function(a: GateInfo, b: GateInfo): boolean
		if a.Zone ~= b.Zone then
			return a.Zone < b.Zone
		end
		return a.Gate < b.Gate
	end)
	return list
end

function ZoneGateController.Start()
	-- Avec StreamingEnabled, les arches arrivent et repartent avec la zone autour du joueur.
	CollectionService:GetInstanceAddedSignal(GATE_TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(GATE_TAG):Connect(untrack)
	for _, gate in CollectionService:GetTagged(GATE_TAG) do
		track(gate)
	end
	local waited = 0
	RunService.Heartbeat:Connect(function(dt: number)
		waited += dt
		if waited >= CHECK_INTERVAL then
			waited = 0
			update()
		end
	end)
end

return ZoneGateController
