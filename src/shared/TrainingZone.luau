--!strict
-- TrainingZone (a115, retours de Cantin du 2026-11-13) : géométrie des machines d'entraînement (tapis et
-- banc), commune au serveur (TrainingService, seul juge) et au client (TrainingController, qui se met en
-- place tout de suite, sans attendre l'aller-retour du réseau). Mêmes calculs des deux côtés : le client
-- prédit exactement ce que le serveur va décider.
--
--   - zone d'entrée : la pièce UseZone de Clément si le modèle en a une (lue telle quelle), sinon la
--     boîte englobante du modèle (calculée une fois, à la découverte : la barre du banc bouge pendant
--     l'usage) élargie de ZONE_MARGIN sur les côtés ; en hauteur, de ZONE_BELOW sous son bas à
--     ZONE_ABOVE au-dessus de son haut ;
--   - bande du tapis : la pièce ou le modèle Belt (contrat 10.4), sinon FALLBACK_BELT_SIZE posée sur le
--     UsePoint ;
--   - cœur de la machine (pour monter, et remonter après une séance sans sortir de la zone) : l'emprise au
--     sol de la bande élargie en travers de Training.Treadmill.SideEntryMargin (tapis, a310), ou
--     REENTRY_RADIUS studs autour du UsePoint, à l'horizontale (banc) ;
--   - place du joueur : debout, pieds sur le UsePoint, tourné vers son axe −Z.

local Training = require(script.Parent.Config.Training)

local TrainingZone = {}

export type Kind = "Treadmill" | "Bench"
export type Zone = {
	kind: Kind,
	usePoint: Attachment,
	useZone: BasePart?, -- pièce UseZone de Clément (facultative), lue telle quelle
	zoneCFrame: CFrame, -- zone calculée à la découverte (sans UseZone) : centre…
	zoneSize: Vector3, -- … et taille, ZONE_MARGIN comprise
	belt: Instance?, -- tapis : sa bande (pièce ou modèle Belt) ; nil : zone posée sur le UsePoint
}

-- Contrat (10.4) : point d'usage, bande, zone d'entrée facultative.
TrainingZone.USE_POINT = "UsePoint"
TrainingZone.BELT = "Belt"
TrainingZone.USE_ZONE = "UseZone"

-- V0 proposés, absents du doc (repris de TrainingService, vague 22) :
-- marge (studs) autour de la boîte du modèle, sur les côtés ; hauteur sous son bas et au-dessus de son
-- haut (le HumanoidRootPart d'un R15 debout est à environ 3 studs du sol) ;
local ZONE_MARGIN = 1
local ZONE_BELOW = 1
local ZONE_ABOVE = 4
-- zone d'un modèle sans boîte (ni Model ni BasePart) : posée sur le UsePoint ;
local FALLBACK_ZONE_SIZE = Vector3.new(6, 4, 6)
-- bande d'un tapis sans Belt : posée sur le UsePoint (centre du dessus) ; vague 63 (a205, L-207) : celle des tapis
-- élargis de Clément, 5,16 studs de large (X) sur 6,08 de long (Z, axe de course), au lieu de 3 × 3 ;
TrainingZone.FALLBACK_BELT_SIZE = Vector3.new(5.16, 0.2, 6.08)
-- tolérance (studs) sous le dessus de la bande ;
local BELT_BELOW = 1
-- V0 proposé, absent du doc (a115) : rayon (studs, à l'horizontale) du cœur du banc autour de son
-- UsePoint, sous LEAVE_DISTANCE (3) de TrainingService : revenir à sa place remonte, rester à côté non.
TrainingZone.REENTRY_RADIUS = 2.5

-- Zone de `model` (taggé Treadmill ou Bench), ou nil s'il n'a pas d'Attachment UsePoint.
function TrainingZone.describe(model: Instance, kind: Kind): Zone?
	local usePoint = model:FindFirstChild(TrainingZone.USE_POINT, true)
	if usePoint == nil or not usePoint:IsA("Attachment") then
		return nil
	end
	local found = model:FindFirstChild(TrainingZone.USE_ZONE, true)
	local useZone: BasePart? = if found and found:IsA("BasePart") then found :: BasePart else nil
	local zoneCFrame: CFrame, zoneSize: Vector3
	if model:IsA("Model") then
		zoneCFrame, zoneSize = model:GetBoundingBox()
		zoneSize += Vector3.new(2 * ZONE_MARGIN, 0, 2 * ZONE_MARGIN)
	elseif model:IsA("BasePart") then
		zoneCFrame, zoneSize = model.CFrame, model.Size + Vector3.new(2 * ZONE_MARGIN, 0, 2 * ZONE_MARGIN)
	else
		zoneCFrame, zoneSize = usePoint.WorldCFrame, FALLBACK_ZONE_SIZE
	end
	local belt: Instance? = nil
	if kind == "Treadmill" then
		local b = model:FindFirstChild(TrainingZone.BELT, true)
		if b and (b:IsA("BasePart") or b:IsA("Model")) then
			belt = b
		end
	end
	return {
		kind = kind,
		usePoint = usePoint,
		useZone = useZone,
		zoneCFrame = zoneCFrame,
		zoneSize = zoneSize,
		belt = belt,
	}
end

-- Boîte de la zone d'entrée (CFrame du centre, taille) : la pièce UseZone, sinon la zone calculée.
function TrainingZone.zoneBox(zone: Zone): (CFrame, Vector3)
	local given = zone.useZone
	if given and given.Parent ~= nil then
		return given.CFrame, given.Size
	end
	return zone.zoneCFrame, zone.zoneSize
end

-- `position` (celle d'un HumanoidRootPart) est-elle dans la zone d'entrée ?
function TrainingZone.inZone(zone: Zone, position: Vector3): boolean
	local cframe, size = TrainingZone.zoneBox(zone)
	local p = cframe:PointToObjectSpace(position)
	local half = size / 2
	return math.abs(p.X) <= half.X
		and math.abs(p.Z) <= half.Z
		and p.Y >= -half.Y - ZONE_BELOW
		and p.Y <= half.Y + ZONE_ABOVE
end

-- `position` est-elle au-dessus de l'emprise au sol de la zone, à n'importe quelle hauteur ?
function TrainingZone.overZone(zone: Zone, position: Vector3): boolean
	local cframe, size = TrainingZone.zoneBox(zone)
	local p = cframe:PointToObjectSpace(position)
	return math.abs(p.X) <= size.X / 2 and math.abs(p.Z) <= size.Z / 2
end

-- Boîte de la bande d'un tapis (CFrame du centre, taille).
function TrainingZone.beltBox(zone: Zone): (CFrame, Vector3)
	local belt = zone.belt
	if belt and belt.Parent ~= nil then
		if belt:IsA("BasePart") then
			return belt.CFrame, belt.Size
		elseif belt:IsA("Model") then
			return belt:GetBoundingBox()
		end
	end
	local size = TrainingZone.FALLBACK_BELT_SIZE
	return zone.usePoint.WorldCFrame * CFrame.new(0, -size.Y / 2, 0), size
end

-- `position` est-elle au-dessus de la bande : dans son emprise élargie de `margin`, de BELT_BELOW sous
-- son dessus à `above` au-dessus ?
function TrainingZone.overBelt(zone: Zone, position: Vector3, margin: number, above: number): boolean
	local cframe, size = TrainingZone.beltBox(zone)
	local p = cframe:PointToObjectSpace(position)
	local half = size / 2
	return math.abs(p.X) <= half.X + margin
		and math.abs(p.Z) <= half.Z + margin
		and p.Y >= half.Y - BELT_BELOW
		and p.Y <= half.Y + above
end

-- a310 (Cantin, 22/11 : « il suffit d'arriver contre un grand côté ») : emprise d'entrée d'un tapis, dans le
-- repère de sa bande : la bande élargie de Training.Treadmill.SideEntryMargin en travers seulement (ses deux
-- grands côtés), stricte aux deux bouts. Renvoie la boîte de la bande, les demi-largeurs de l'emprise en X
-- et en Z, et true si le tapis court le long de Z (grands côtés en ±X). L'axe du tapis est celui des deux
-- axes horizontaux de la bande le plus proche du −Z du UsePoint.
function TrainingZone.entryBox(zone: Zone): (CFrame, Vector3, number, number, boolean)
	local cframe, size = TrainingZone.beltBox(zone)
	local point = zone.usePoint.WorldCFrame
	local axis = cframe:PointToObjectSpace(point.Position + point.LookVector) - cframe:PointToObjectSpace(point.Position)
	local margin = math.max(0, Training.Treadmill.SideEntryMargin)
	if math.abs(axis.Z) >= math.abs(axis.X) then
		return cframe, size, size.X / 2 + margin, size.Z / 2, true
	end
	return cframe, size, size.X / 2, size.Z / 2 + margin, false
end

-- `position` est-elle au-dessus du cœur de la machine (à l'horizontale, à n'importe quelle hauteur) :
-- l'emprise d'entrée du tapis (TrainingZone.entryBox, a310), ou REENTRY_RADIUS autour du UsePoint (banc) ?
function TrainingZone.inCore(zone: Zone, position: Vector3): boolean
	if zone.kind == "Treadmill" then
		local cframe, _, halfX, halfZ = TrainingZone.entryBox(zone)
		local p = cframe:PointToObjectSpace(position)
		return math.abs(p.X) <= halfX and math.abs(p.Z) <= halfZ
	end
	local offset = position - zone.usePoint.WorldPosition
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= TrainingZone.REENTRY_RADIUS
end

-- a180 (Cantin, 2026-11-15 : « seulement quand tu vas sur le côté du tapis et pas quand tu passes
-- devant ») : on ne monte sur un tapis que le HumanoidRootPart au-dessus de sa bande ET arrivé sur elle
-- par un de ses deux grands côtés. Entrée par un bout (avant ou arrière) : rien, même en restant sur la
-- bande, tant qu'on n'en est pas ressorti. a310 (Cantin, 22/11) : « la bande » est ici son emprise d'entrée
-- (TrainingZone.entryBox), élargie en travers : arriver contre un grand côté suffit, le jeu place le joueur
-- sur la bande. Le serveur et le client tiennent chacun un Approach par
-- joueur et l'avancent à chaque contrôle (TrainingZone.track) : mêmes positions, même décision.
export type Approach = {
	lastPosition: Vector3?, -- position au contrôle précédent (nil : aucune, ex. nouveau perso)
	zone: Zone?, -- tapis dont la bande contenait lastPosition (nil : hors de toute bande)
	fromSide: boolean, -- l'entrée sur la bande de `zone` s'est faite par un grand côté
}

-- V0 proposé, absent du doc (a180) : hauteur (studs) au-dessus du dessus de la bande jusqu'à laquelle
-- le HumanoidRootPart compte comme sur la bande pour monter (debout, il est à environ 3 studs).
TrainingZone.ENTRY_ABOVE = 4

function TrainingZone.newApproach(): Approach
	return { lastPosition = nil, zone = nil, fromSide = false }
end

-- `position`, hors de l'emprise d'entrée (TrainingZone.entryBox), en a-t-elle franchi un grand côté plutôt
-- qu'un bout ? On compare de combien `position` déborde de l'emprise (élargie en travers, a310) en travers et
-- en long : dans un coin (dans la marge en travers mais au-delà d'un bout), seul le bout déborde.
function TrainingZone.fromSide(zone: Zone, position: Vector3): boolean
	local cframe, _, halfX, halfZ, alongZ = TrainingZone.entryBox(zone)
	local p = cframe:PointToObjectSpace(position)
	local outX = math.abs(p.X) - halfX
	local outZ = math.abs(p.Z) - halfZ
	if outX <= 0 and outZ <= 0 then
		return false -- déjà dans l'emprise (pas de bord franchi)
	end
	if alongZ then
		return outX > outZ -- tapis le long de Z : les grands côtés sont en ±X
	end
	return outZ > outX
end

-- Avance `approach` avec la position `position` du HumanoidRootPart et la machine `zone` choisie à cet
-- endroit (nil : aucune) ; true si l'on peut y monter : banc toujours (règle inchangée), tapis
-- seulement sur sa bande (son emprise d'entrée, a310), entré par un grand côté. L'entrée se décide au
-- premier contrôle dans l'emprise (TrainingZone.inCore), d'après la position du contrôle précédent, hors de
-- l'emprise.
function TrainingZone.track(approach: Approach, zone: Zone?, position: Vector3): boolean
	local onBelt: Zone? = nil
	if zone and zone.kind == "Treadmill" and TrainingZone.inCore(zone, position) then
		onBelt = zone
	end
	if onBelt and approach.zone ~= onBelt then
		local last = approach.lastPosition
		approach.fromSide = last ~= nil and TrainingZone.fromSide(onBelt, last)
	end
	approach.zone = onBelt
	approach.lastPosition = position
	if zone == nil then
		return false
	end
	if zone.kind ~= "Treadmill" then
		return true
	end
	if onBelt == nil or not approach.fromSide then
		return false
	end
	-- a310 : à l'horizontale, l'emprise d'entrée (inCore) ; en hauteur, de BELT_BELOW sous le dessus de la
	-- bande à ENTRY_ABOVE au-dessus (comme avant).
	local cframe, size = TrainingZone.beltBox(zone)
	local y = cframe:PointToObjectSpace(position).Y
	return y >= size.Y / 2 - BELT_BELOW and y <= size.Y / 2 + TrainingZone.ENTRY_ABOVE
end

-- a200 : le tapis où le joueur est en séance vient d'être remplacé par une variante (MachineVariantService) :
-- son suivi passe sur la bande du nouveau tapis, comme s'il y était monté par le côté (il l'avait fait sur
-- l'ancien). Sans cela, la nouvelle bande compterait pour une arrivée par le bout après la séance.
function TrainingZone.adopt(approach: Approach, zone: Zone)
	approach.zone = zone
	approach.fromSide = true
end

-- Place du HumanoidRootPart : debout, pieds sur le UsePoint, tourné vers l'avant du UsePoint (son axe
-- −Z, LookVector) ramené à l'horizontale.
function TrainingZone.standingCFrame(usePoint: Attachment, humanoid: Humanoid, root: BasePart): CFrame
	local point = usePoint.WorldCFrame
	local look = point.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 1e-3 then
		look = Vector3.new(0, 0, -1)
	end
	-- R15 : le centre du HumanoidRootPart est à HipHeight + la moitié de sa hauteur au-dessus du sol.
	-- R6 : HipHeight vaut 0 et les jambes font 2 studs.
	local height = humanoid.HipHeight + root.Size.Y / 2
	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		height += 2
	end
	local position = point.Position + Vector3.new(0, height, 0)
	return CFrame.lookAt(position, position + look.Unit)
end

return TrainingZone
