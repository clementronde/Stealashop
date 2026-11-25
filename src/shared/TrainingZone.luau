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
--     sol de la bande élargie de Training.Treadmill.SideEntryMargin au-delà de chaque bord de
--     Training.Treadmill.EntryEdges (tapis : côtés depuis a310, arrière depuis a454), ou
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

-- a454 (Cantin, 25/11 : « tu acceptes aussi qu'on puisse monter par derrière ») : emprise d'entrée d'un tapis,
-- dans le repère de course de sa bande. Bords de la bande : ses deux côtés (« Side », le long de la course),
-- son avant (« Front », vers où regarde le coureur : le LookVector du UsePoint, lu du modèle) et son arrière
-- (« Back », à l'opposé). Chaque bord de Training.Treadmill.EntryEdges s'élargit vers l'extérieur de
-- Training.Treadmill.SideEntryMargin, sur la seule longueur de ce bord (a310 pour les côtés) ; les autres
-- restent stricts. L'emprise est donc la bande et un bras par bord compté, sans les coins (un coin n'est pas
-- un bord). Chaque bras est rogné à la zone d'entrée (UseZone, sinon zone de secours) : un bras qui en
-- sortirait cacherait l'entrée (le contrôle d'avant l'entrée, hors de la zone, serait déjà dans le bras).
-- L'axe de course est celui des deux axes horizontaux de la bande le plus proche du LookVector du UsePoint.
type Entry = {
	cframe: CFrame, -- boîte de la bande
	alongZ: boolean, -- la course suit l'axe Z de la bande (côtés en ±X)
	backSign: number, -- signe, sur cet axe, du côté de l'arrière
	halfAcross: number, -- demi-largeur de la bande (en travers)
	halfAlong: number, -- demi-longueur de la bande (le long de la course)
	side: number, -- distance du centre de la bande au bord de l'emprise, en travers…
	back: number, -- … vers l'arrière…
	front: number, -- … vers l'avant
}

-- Distance du centre de la bande (dans la zone) au bord de l'emprise au sol de la zone, dans la direction
-- `localDir` (vecteur unité dans le repère de la bande).
local function reach(zoneCFrame: CFrame, zoneSize: Vector3, beltCFrame: CFrame, localDir: Vector3): number
	local o = zoneCFrame:PointToObjectSpace(beltCFrame.Position)
	local d = zoneCFrame:PointToObjectSpace(beltCFrame * localDir) - o
	local t = math.huge
	if math.abs(d.X) > 1e-6 then
		t = math.min(t, ((if d.X > 0 then zoneSize.X / 2 else -zoneSize.X / 2) - o.X) / d.X)
	end
	if math.abs(d.Z) > 1e-6 then
		t = math.min(t, ((if d.Z > 0 then zoneSize.Z / 2 else -zoneSize.Z / 2) - o.Z) / d.Z)
	end
	return t
end

local function entry(zone: Zone): Entry
	local cframe, size = TrainingZone.beltBox(zone)
	local point = zone.usePoint.WorldCFrame
	local axis = cframe:PointToObjectSpace(point.Position + point.LookVector) - cframe:PointToObjectSpace(point.Position)
	local alongZ = math.abs(axis.Z) >= math.abs(axis.X)
	local forward = if alongZ then axis.Z else axis.X
	local backSign = if forward > 0 then -1 else 1
	local halfAcross = if alongZ then size.X / 2 else size.Z / 2
	local halfAlong = if alongZ then size.Z / 2 else size.X / 2
	local margin = math.max(0, Training.Treadmill.SideEntryMargin)
	local side, back, front = halfAcross, halfAlong, halfAlong
	for _, edge in Training.Treadmill.EntryEdges do
		if edge == "Side" then
			side = halfAcross + margin
		elseif edge == "Back" then
			back = halfAlong + margin
		elseif edge == "Front" then
			front = halfAlong + margin
		end
	end
	local zoneCFrame, zoneSize = TrainingZone.zoneBox(zone)
	local acrossDir = if alongZ then Vector3.new(1, 0, 0) else Vector3.new(0, 0, 1)
	local backDir = if alongZ then Vector3.new(0, 0, backSign) else Vector3.new(backSign, 0, 0)
	side = math.max(
		halfAcross,
		math.min(side, reach(zoneCFrame, zoneSize, cframe, acrossDir), reach(zoneCFrame, zoneSize, cframe, -acrossDir))
	)
	back = math.max(halfAlong, math.min(back, reach(zoneCFrame, zoneSize, cframe, backDir)))
	front = math.max(halfAlong, math.min(front, reach(zoneCFrame, zoneSize, cframe, -backDir)))
	return {
		cframe = cframe,
		alongZ = alongZ,
		backSign = backSign,
		halfAcross = halfAcross,
		halfAlong = halfAlong,
		side = side,
		back = back,
		front = front,
	}
end

-- `position` dans le repère de course : distance au milieu en travers (≥ 0), et position le long de la
-- course (positive vers l'arrière).
local function runCoords(e: Entry, position: Vector3): (number, number)
	local p = e.cframe:PointToObjectSpace(position)
	if e.alongZ then
		return math.abs(p.X), p.Z * e.backSign
	end
	return math.abs(p.Z), p.X * e.backSign
end

local function inEntry(e: Entry, across: number, along: number): boolean
	return (across <= e.side and math.abs(along) <= e.halfAlong)
		or (across <= e.halfAcross and along <= e.back and along >= -e.front)
end

-- `position` est-elle au-dessus du cœur de la machine (à l'horizontale, à n'importe quelle hauteur) :
-- l'emprise d'entrée du tapis (a310, a454), ou REENTRY_RADIUS autour du UsePoint (banc) ?
function TrainingZone.inCore(zone: Zone, position: Vector3): boolean
	if zone.kind == "Treadmill" then
		local e = entry(zone)
		return inEntry(e, runCoords(e, position))
	end
	local offset = position - zone.usePoint.WorldPosition
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= TrainingZone.REENTRY_RADIUS
end

-- a454 : bord de l'emprise d'entrée que `position` (hors de l'emprise) a franchi pour y entrer : « Side »,
-- « Back » ou « Front » ; nil si `position` est déjà dans l'emprise, ou dans un coin de sa boîte (à côté d'un
-- bras, hors de tout bras). Hors de la boîte, on compare de combien `position` en déborde en travers et en
-- long (règle d'a310) : le plus grand débord dit le bord franchi.
function TrainingZone.entryEdge(zone: Zone, position: Vector3): string?
	local e = entry(zone)
	local across, along = runCoords(e, position)
	if inEntry(e, across, along) then
		return nil
	end
	local outAcross = across - e.side
	local outAlong = if along >= 0 then along - e.back else -along - e.front
	if outAcross <= 0 and outAlong <= 0 then
		return nil -- coin
	end
	if outAcross > outAlong then
		return "Side"
	end
	return if along >= 0 then "Back" else "Front"
end

-- a180 (Cantin, 2026-11-15 : « seulement quand tu vas sur le côté du tapis et pas quand tu passes
-- devant ») : on ne monte sur un tapis que le HumanoidRootPart au-dessus de sa bande ET arrivé sur elle
-- par un de ses deux grands côtés. Entrée par un bout (avant ou arrière) : rien, même en restant sur la
-- bande, tant qu'on n'en est pas ressorti. a310 (Cantin, 22/11) : « la bande » est ici son emprise d'entrée
-- (TrainingZone.inCore), élargie en travers : arriver contre un grand côté suffit, le jeu place le joueur
-- sur la bande. a454 (Cantin, 25/11) : « un grand côté » se lit désormais « un bord de
-- Training.Treadmill.EntryEdges » (les côtés et l'arrière ; { "Side" } = la règle d'a310). Le serveur et le
-- client tiennent chacun un Approach par joueur et l'avancent à chaque contrôle (TrainingZone.track) : mêmes
-- positions, même décision.
export type Approach = {
	lastPosition: Vector3?, -- position au contrôle précédent (nil : aucune, ex. nouveau perso)
	zone: Zone?, -- tapis dont la bande contenait lastPosition (nil : hors de toute bande)
	fromSide: boolean, -- l'entrée sur la bande de `zone` s'est faite par un bord permis (EntryEdges, a454)
}

-- V0 proposé, absent du doc (a180) : hauteur (studs) au-dessus du dessus de la bande jusqu'à laquelle
-- le HumanoidRootPart compte comme sur la bande pour monter (debout, il est à environ 3 studs).
TrainingZone.ENTRY_ABOVE = 4

function TrainingZone.newApproach(): Approach
	return { lastPosition = nil, zone = nil, fromSide = false }
end

-- `position`, hors de l'emprise d'entrée, en a-t-elle franchi un bord permis (Training.Treadmill.EntryEdges,
-- a454 ; un grand côté avant a454) ? Voir TrainingZone.entryEdge.
function TrainingZone.fromSide(zone: Zone, position: Vector3): boolean
	local edge = TrainingZone.entryEdge(zone, position)
	return edge ~= nil and table.find(Training.Treadmill.EntryEdges, edge) ~= nil
end

-- Avance `approach` avec la position `position` du HumanoidRootPart et la machine `zone` choisie à cet
-- endroit (nil : aucune) ; true si l'on peut y monter : banc toujours (règle inchangée), tapis
-- seulement sur sa bande (son emprise d'entrée, a310), entré par un bord permis (a454). L'entrée se décide au
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
