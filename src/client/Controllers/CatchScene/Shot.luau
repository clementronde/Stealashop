--!strict
-- CatchScene/Shot (client, a252 ; liaison L-244, Clément 2026-11-18 : « actuellement on a la caméra au centre et on ne
-- voit plus rien de l'animation ») : le plan large de côté de la capture, module d'aide de CatchSceneController
-- (sous-dossier : le Loader ne le démarre pas). Valeurs : Config/Chase.CatchShot (V0). Tout est local.
--   - Frame(a, b, fov, aspect, current, cast, inside, cfg) -> (position, focus, kind) : PUR (bancs). a et b = les deux
--     HumanoidRootPart (joueur, celui qui attrape) ; fov = FieldOfView vertical (degrés) ; aspect = largeur / hauteur ;
--     current = position actuelle de la caméra (ou nil) ; cast(from, to) -> distance au premier obstacle entre les
--     deux (nil : libre) ; inside(position) -> la position est-elle dans une pièce ? Distance pour que les deux corps
--     (écart + 2 × Margin de large, BodyHeight + Margin de haut) tiennent dans l'image, bornée à MinDistance..
--     MaxDistance ; essais sur les deux côtés de l'axe a → b, à 0 et ± SideAngle°. Choix : un essai libre (le plus
--     proche de la caméra actuelle, le plein côté d'abord) ; sinon le moins bloqué, avancé devant le mur (WallPad) s'il
--     reste à MinDistance au moins ; sinon derrière le mur (jamais DANS une pièce : reculé jusqu'à 6 studs de plus),
--     les gêneurs cachés par Occluders. kind = "Free", "Wall" ou "Through".
--   - WorldCast(exclude) -> cast et WorldInside(exclude) -> inside : les vrais tests (Workspace), pièces transparentes
--     (Transparency ≥ 0,95) et sans collision ignorées.
--   - Occluders(from, targets, exclude, hidden, cfg) -> nombre caché : les pièces entre la caméra et chaque cible
--     prennent LocalTransparencyModifier = Fade (valeur d'avant gardée dans `hidden`, à remettre par Restore).
--   - Restore(hidden)

local Workspace = game:GetService("Workspace")

export type Config = {
	Margin: number,
	BodyHeight: number,
	FocusRise: number,
	Rise: number,
	MinDistance: number,
	MaxDistance: number,
	SideAngle: number,
	WallPad: number,
	Fade: number,
	MaxHidden: number,
}

export type Cast = (from: Vector3, to: Vector3) -> number?
export type Inside = (position: Vector3) -> boolean

local Shot = {}

local PUSH_STEP = 1.5
local PUSH_MAX = 6

local function flatUnit(v: Vector3): Vector3?
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 1e-3 then
		return nil
	end
	return f.Unit
end

local function rotateY(v: Vector3, degrees: number): Vector3
	return (CFrame.Angles(0, math.rad(degrees), 0) * CFrame.new(v)).Position
end

function Shot.Distance(a: Vector3, b: Vector3, fov: number, aspect: number, cfg: Config): number
	local span = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Magnitude
	local vfov = math.rad(math.clamp(fov, 1, 120))
	local hfov = 2 * math.atan(math.tan(vfov / 2) * math.max(aspect, 0.1))
	local width = span + 2 * cfg.Margin
	local height = cfg.BodyHeight + cfg.Margin
	local d = math.max((width / 2) / math.tan(hfov / 2), (height / 2) / math.tan(vfov / 2))
	return math.clamp(d, cfg.MinDistance, cfg.MaxDistance)
end

function Shot.Frame(
	a: Vector3,
	b: Vector3,
	fov: number,
	aspect: number,
	current: Vector3?,
	cast: Cast,
	inside: Inside,
	cfg: Config
): (Vector3, Vector3, string)
	local focus = (a + b) / 2 + Vector3.new(0, cfg.FocusRise, 0)
	local axis = flatUnit(b - a)
	local towardCamera = if current then flatUnit(current - focus) else nil
	local side: Vector3 = if axis then Vector3.new(-axis.Z, 0, axis.X) else (towardCamera or Vector3.new(1, 0, 0))
	local d = Shot.Distance(a, b, fov, aspect, cfg)
	local lift = Vector3.new(0, cfg.Rise, 0)

	local best: { score: number, position: Vector3, kind: string }? = nil
	for _, sign in { 1, -1 } do
		for index, angle in { 0, cfg.SideAngle, -cfg.SideAngle } do
			local dir = rotateY(side * sign, angle)
			local ray = (dir * d + lift)
			local wanted = focus + ray
			local facing = if towardCamera then dir:Dot(towardCamera) else 0
			local bonus = (if index == 1 then 0.5 else 0) + facing * 0.4
			local hit = cast(focus, wanted)
			local score: number
			local position: Vector3
			local kind: string
			if hit == nil then
				score, position, kind = 20 + bonus, wanted, "Free"
			elseif hit - cfg.WallPad >= cfg.MinDistance then
				score, position, kind = 10 + hit / d + bonus, focus + ray.Unit * (hit - cfg.WallPad), "Wall"
			else
				position = wanted
				local pushed = 0
				while inside(position) and pushed < PUSH_MAX do
					pushed += PUSH_STEP
					position = focus + ray.Unit * (ray.Magnitude + pushed)
				end
				score, kind = (if inside(position) then 0 else 2) + hit / d + bonus, "Through"
			end
			if best == nil or score > best.score then
				best = { score = score, position = position, kind = kind }
			end
		end
	end
	local chosen = best :: { score: number, position: Vector3, kind: string }
	return chosen.position, focus, chosen.kind
end

-- Vrais tests, dans Workspace ------------------------------------------------------------------------------

local function seeThrough(part: BasePart): boolean
	return part.Transparency >= 0.95 or not part.CanCollide
end

local function params(exclude: { Instance }): RaycastParams
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	p.FilterDescendantsInstances = exclude
	p.IgnoreWater = true
	return p
end

function Shot.WorldCast(exclude: { Instance }): Cast
	return function(from: Vector3, to: Vector3): number?
		local skip = table.clone(exclude)
		local offset = to - from
		for _ = 1, 8 do
			local result = Workspace:Raycast(from, offset, params(skip))
			if result == nil then
				return nil
			end
			local part = result.Instance
			if part:IsA("BasePart") and seeThrough(part) then
				table.insert(skip, part)
			else
				return (result.Position - from).Magnitude
			end
		end
		return nil
	end
end

function Shot.WorldInside(exclude: { Instance }): Inside
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = exclude
	return function(position: Vector3): boolean
		for _, part in Workspace:GetPartBoundsInRadius(position, 0.4, overlap) do
			if not seeThrough(part) then
				return true
			end
		end
		return false
	end
end

function Shot.Occluders(
	from: Vector3,
	targets: { Vector3 },
	exclude: { Instance },
	hidden: { [BasePart]: number },
	cfg: Config
): number
	local count = 0
	for _ in hidden do
		count += 1
	end
	for _, target in targets do
		local skip = table.clone(exclude)
		for _ = 1, 6 do
			if count >= cfg.MaxHidden then
				return count
			end
			local result = Workspace:Raycast(from, target - from, params(skip))
			if result == nil then
				break
			end
			local part = result.Instance
			table.insert(skip, part)
			if part:IsA("BasePart") and hidden[part] == nil and part.Transparency < 0.95 then
				hidden[part] = part.LocalTransparencyModifier
				part.LocalTransparencyModifier = math.max(part.LocalTransparencyModifier, cfg.Fade)
				count += 1
			end
		end
	end
	return count
end

function Shot.Restore(hidden: { [BasePart]: number })
	for part, value in hidden do
		if part.Parent ~= nil then
			part.LocalTransparencyModifier = value
		end
		hidden[part] = nil
	end
end

return Shot
