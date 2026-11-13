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
--   - cœur de la machine (pour remonter après une séance, sans sortir de la zone) : l'emprise au sol de
--     la bande (tapis), ou REENTRY_RADIUS studs autour du UsePoint, à l'horizontale (banc) ;
--   - place du joueur : debout, pieds sur le UsePoint, tourné vers son axe −Z.

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
-- bande d'un tapis sans Belt : posée sur le UsePoint (centre du dessus) ;
TrainingZone.FALLBACK_BELT_SIZE = Vector3.new(3, 0.2, 3)
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

-- `position` est-elle au-dessus du cœur de la machine (à l'horizontale, à n'importe quelle hauteur) :
-- l'emprise de la bande (tapis), ou REENTRY_RADIUS autour du UsePoint (banc) ?
function TrainingZone.inCore(zone: Zone, position: Vector3): boolean
	if zone.kind == "Treadmill" then
		local cframe, size = TrainingZone.beltBox(zone)
		local p = cframe:PointToObjectSpace(position)
		return math.abs(p.X) <= size.X / 2 and math.abs(p.Z) <= size.Z / 2
	end
	local offset = position - zone.usePoint.WorldPosition
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= TrainingZone.REENTRY_RADIUS
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
