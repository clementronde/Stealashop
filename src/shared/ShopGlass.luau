--!strict
-- ShopGlass (a315, L-291) : les vitres d'une boutique de joueur et le choix de celle que traverse l'intrus projeté
-- (GlassThrowService), plus les points du trou pour GeometryService:FragmentAsync (GlassThrowController). Calcul pur,
-- sans état ni service : tout se fait dans le repère de la boutique (son volume Bounds) et de chaque vitre, jamais
-- dans les axes du monde (boutiques tournées de −10° à −170°, L-293).
--
-- Vitres (contrat voulu, L-291) : BasePart taguée ShopGlass, attribut GlassSide (Front, Left, Right, Back). Tant
-- qu'aucune vitre de la boutique n'est taguée, repli par nom : toute BasePart « Pane_* » de la boutique
-- (plot_shop_builder : Pane_L, Pane_R, Pane_FL, Pane_FR, Pane_B). Une vitre cachée (Transparency 1, niveau pas
-- encore atteint : ShopStageService) ne compte pas. Côté sans GlassSide : lettre du nom (Pane_L… = Left, Pane_R… =
-- Right, Pane_F… = Front, Pane_B… = Back), sinon sa position dans Bounds (avant de la boutique vers −Z, gauche vers
-- −X, comme le gabarit de Clément).
--
-- Choix (Choose) : la vitre que coupe en premier le rayon du coup (du frappeur vers l'intrus, à plat) ; sinon la plus
-- proche de l'intrus. Seulement une vitre verticale, que l'intrus voit de l'intérieur, et qui donne dehors : de
-- l'autre côté, le bord de Bounds est à MaxExitDistance au plus.

-- Noms du contrat (Contract/Models.ShopGlass, Contract/Tags, Contract/Attributes.GlassSide), jamais recopiés.
local Contract = require(script.Parent:WaitForChild("Contract"):WaitForChild("Models")).ShopGlass

local ShopGlass = {}

ShopGlass.Tag = Contract.Tag :: string
ShopGlass.SideAttribute = Contract.SideAttribute :: string
ShopGlass.Sides = Contract.Sides :: { string }
ShopGlass.NamePrefix = Contract.NamePrefix :: string

local LETTER_SIDE: { [string]: string } = { F = "Front", L = "Left", R = "Right", B = "Back" }

-- Repère d'une vitre : Center au milieu, U = largeur (à plat), V = hauteur, N = normale vers l'extérieur de la
-- boutique ; demi-largeur, demi-hauteur et épaisseur.
export type Frame = {
	Center: Vector3,
	U: Vector3,
	V: Vector3,
	N: Vector3,
	HalfWidth: number,
	HalfHeight: number,
	Thickness: number,
}

export type Choice = {
	Pane: BasePart,
	Side: string,
	Frame: Frame,
	Point: Vector3, -- centre du trou, dans le plan de la vitre
	Direction: Vector3, -- sens du vol, à plat (unité)
	ByRay: boolean, -- true : dans le sens du coup ; false : la plus proche
	Distance: number,
	HoleHalfWidth: number,
	HoleHalfHeight: number,
}

export type Settings = {
	RayTolerance: number,
	MaxExitDistance: number,
	HoleHalfWidth: number,
	HoleHalfHeight: number,
	HoleLift: number,
	EdgeMargin: number,
}

export type SiteSettings = {
	InnerPoints: number,
	RingPoints: number,
	RingScaleMin: number,
	RingScaleMax: number,
	FarPoints: number,
}

local function isSide(value: any): boolean
	return type(value) == "string" and table.find(ShopGlass.Sides, value) ~= nil
end
ShopGlass.IsSide = isSide

local function shown(part: BasePart): boolean
	return part.Transparency < 1
end

-- Les vitres de `plot` : celles de `tagged` (CollectionService:GetTagged(ShopGlass)) qui sont dans la boutique, ou,
-- s'il n'y en a aucune, ses BasePart « Pane_* ». Renvoie aussi true si la liste vient du tag.
function ShopGlass.Collect(plot: Instance, tagged: { Instance }): ({ BasePart }, boolean)
	local panes: { BasePart } = {}
	for _, instance in tagged do
		if instance:IsA("BasePart") and instance:IsDescendantOf(plot) and shown(instance :: BasePart) then
			table.insert(panes, instance :: BasePart)
		end
	end
	if #panes > 0 then
		return panes, true
	end
	local prefix = ShopGlass.NamePrefix
	for _, instance in plot:GetDescendants() do
		if instance:IsA("BasePart") and string.sub(instance.Name, 1, #prefix) == prefix and shown(instance :: BasePart) then
			table.insert(panes, instance :: BasePart)
		end
	end
	return panes, false
end

-- Repère de `pane` (voir Frame), ou nil si la vitre n'est pas verticale dans la boutique.
function ShopGlass.FrameOf(bounds: BasePart, pane: BasePart): Frame?
	-- Vers l'extérieur : à l'opposé du centre de Bounds.
	return ShopGlass.FrameAlong(pane, bounds.CFrame.UpVector, pane.CFrame.Position - bounds.CFrame.Position)
end

-- Repère de `pane` avec `up` pour le haut et la normale tournée du côté de `outward` (client : le sens du vol).
function ShopGlass.FrameAlong(pane: BasePart, up: Vector3, outward: Vector3): Frame?
	local cf = pane.CFrame
	local size = pane.Size
	local axes = { cf.XVector, cf.YVector, cf.ZVector }
	local sizes = { size.X, size.Y, size.Z }
	local thin = 1
	for index = 2, 3 do
		if sizes[index] < sizes[thin] then
			thin = index
		end
	end
	local normal = axes[thin]
	if math.abs(normal:Dot(up)) > 0.5 then
		return nil -- vitre couchée (verrière) : on ne la traverse pas
	end
	local others: { number } = {}
	for index = 1, 3 do
		if index ~= thin then
			table.insert(others, index)
		end
	end
	local a, b = others[1], others[2]
	local vertical, lateral = a, b
	if math.abs(axes[b]:Dot(up)) > math.abs(axes[a]:Dot(up)) then
		vertical, lateral = b, a
	end
	local center = cf.Position
	local away = outward - up * outward:Dot(up)
	if normal:Dot(away) < 0 then
		normal = -normal
	end
	local v = axes[vertical]
	if v:Dot(up) < 0 then
		v = -v
	end
	return {
		Center = center,
		U = v:Cross(normal),
		V = v,
		N = normal,
		HalfWidth = sizes[lateral] / 2,
		HalfHeight = sizes[vertical] / 2,
		Thickness = sizes[thin],
	}
end

-- Distance, le long de la normale, du plan de la vitre au bord de Bounds (repère de Bounds, à plat).
function ShopGlass.ExitDistance(bounds: BasePart, frame: Frame): number
	local c = bounds.CFrame:PointToObjectSpace(frame.Center)
	local n = bounds.CFrame:VectorToObjectSpace(frame.N)
	local h = bounds.Size / 2
	local best = math.huge
	if math.abs(n.X) > 1e-3 then
		best = math.min(best, ((if n.X > 0 then h.X else -h.X) - c.X) / n.X)
	end
	if math.abs(n.Z) > 1e-3 then
		best = math.min(best, ((if n.Z > 0 then h.Z else -h.Z) - c.Z) / n.Z)
	end
	return math.max(best, 0)
end

-- Côté de la vitre : attribut GlassSide, sinon lettre du nom (Pane_L…), sinon position dans Bounds.
function ShopGlass.SideOf(bounds: BasePart, pane: BasePart, frame: Frame?): string
	local attribute = pane:GetAttribute(ShopGlass.SideAttribute)
	if isSide(attribute) then
		return attribute :: string
	end
	local prefix = ShopGlass.NamePrefix
	if string.sub(pane.Name, 1, #prefix) == prefix then
		local side = LETTER_SIDE[string.sub(pane.Name, #prefix + 1, #prefix + 1)]
		if side then
			return side
		end
	end
	local f = frame or ShopGlass.FrameOf(bounds, pane)
	local n = bounds.CFrame:VectorToObjectSpace(if f then f.N else pane.CFrame.Position - bounds.CFrame.Position)
	if math.abs(n.X) > math.abs(n.Z) then
		return if n.X < 0 then "Left" else "Right"
	end
	return if n.Z < 0 then "Front" else "Back"
end

-- Dans la boutique : le point est-il dans Bounds (même règle que PvPService) ?
function ShopGlass.Inside(bounds: BasePart, point: Vector3): boolean
	local p = bounds.CFrame:PointToObjectSpace(point)
	local h = bounds.Size / 2
	return math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z
end

-- De combien `point` est sorti de Bounds à plat (négatif : encore dedans).
function ShopGlass.OutsideBy(bounds: BasePart, point: Vector3): number
	local p = bounds.CFrame:PointToObjectSpace(point)
	local h = bounds.Size / 2
	return math.max(math.abs(p.X) - h.X, math.abs(p.Z) - h.Z)
end

local function clampCentered(value: number, limit: number): number
	if limit <= 0 then
		return 0
	end
	return math.clamp(value, -limit, limit)
end

-- La vitre traversée par l'intrus en `from` frappé dans le sens `direction`, parmi `panes`, et le trou. `holes`
-- (facultatif) : centre du trou déjà ouvert de certaines vitres, visé tel quel. nil si aucune vitre ne convient.
function ShopGlass.Choose(
	bounds: BasePart,
	panes: { BasePart },
	from: Vector3,
	direction: Vector3,
	settings: Settings,
	holes: { [BasePart]: Vector3 }?
): Choice?
	local up = bounds.CFrame.UpVector
	local d = direction - up * direction:Dot(up)
	local hasRay = d.Magnitude > 1e-3
	if hasRay then
		d = d.Unit
	end
	local rayPane: BasePart?, rayFrame: Frame?, rayT, rayLat = nil, nil, math.huge, 0
	local nearPane: BasePart?, nearFrame: Frame?, nearDist, nearLat = nil, nil, math.huge, 0
	for _, pane in panes do
		local frame = ShopGlass.FrameOf(bounds, pane)
		if frame == nil or ShopGlass.ExitDistance(bounds, frame) > settings.MaxExitDistance then
			continue
		end
		local rel = from - frame.Center
		local s = rel:Dot(frame.N)
		if s >= 0 then
			continue -- déjà de l'autre côté de cette vitre
		end
		local lat = rel:Dot(frame.U)
		if hasRay then
			local dn = d:Dot(frame.N)
			if dn > 1e-3 then
				local t = -s / dn
				local hit = lat + t * d:Dot(frame.U)
				if math.abs(hit) <= frame.HalfWidth + settings.RayTolerance and t < rayT then
					rayPane, rayFrame, rayT, rayLat = pane, frame, t, hit
				end
			end
		end
		local side = math.max(math.abs(lat) - frame.HalfWidth, 0)
		local dist = math.sqrt(side * side + s * s)
		if dist < nearDist then
			nearPane, nearFrame, nearDist, nearLat = pane, frame, dist, lat
		end
	end
	local pane, frame, lat, distance, byRay
	if rayPane and rayFrame then
		pane, frame, lat, distance, byRay = rayPane, rayFrame, rayLat, rayT, true
	elseif nearPane and nearFrame then
		pane, frame, lat, distance, byRay = nearPane, nearFrame, nearLat, nearDist, false
	else
		return nil
	end
	local edge = settings.EdgeMargin
	local hw = math.max(math.min(settings.HoleHalfWidth, frame.HalfWidth - edge), 0.1)
	local hh = math.max(math.min(settings.HoleHalfHeight, frame.HalfHeight - edge), 0.1)
	local point: Vector3
	local open = if holes then holes[pane] else nil
	if open then
		point = open
	else
		local rel = from - frame.Center
		local x = clampCentered(lat, frame.HalfWidth - hw - edge)
		local y = clampCentered(rel:Dot(frame.V) + settings.HoleLift, frame.HalfHeight - hh - edge)
		point = frame.Center + frame.U * x + frame.V * y
	end
	local flight = point - from
	flight -= up * flight:Dot(up)
	local dir = if flight.Magnitude > 0.5 then flight.Unit else frame.N
	return {
		Pane = pane,
		Side = ShopGlass.SideOf(bounds, pane, frame),
		Frame = frame,
		Point = point,
		Direction = dir,
		ByRay = byRay,
		Distance = distance,
		HoleHalfWidth = hw,
		HoleHalfHeight = hh,
	}
end

-- Points de FragmentAsync pour un trou de demi-taille (hw, hh) centré en `point` sur la vitre `frame` : le point 1
-- est un groupe (anneau juste hors de l'ellipse et points loin dehors) = le reste de la vitre, d'un seul morceau ;
-- les suivants, dans l'ellipse, deviennent les éclats. `random` : nombre au hasard dans [0, 1[.
function ShopGlass.Sites(
	frame: Frame,
	point: Vector3,
	hw: number,
	hh: number,
	settings: SiteSettings,
	random: () -> number
): { any }
	local rel = point - frame.Center
	local x, y = rel:Dot(frame.U), rel:Dot(frame.V)
	local depth = frame.Thickness * 0.25
	local function at(px: number, py: number, pz: number): Vector3
		return frame.Center + frame.U * px + frame.V * py + frame.N * pz
	end
	local outer: { Vector3 } = {}
	local sites: { any } = { outer }
	for _ = 1, math.max(settings.InnerPoints, 1) do
		local angle = random() * math.pi * 2
		local r = math.sqrt(random()) * 0.95
		table.insert(sites, at(x + hw * r * math.cos(angle), y + hh * r * math.sin(angle), (random() * 2 - 1) * depth))
	end
	local ring = math.max(settings.RingPoints, 3)
	local turn = random() * math.pi * 2
	for index = 1, ring do
		local angle = turn + (index + (random() - 0.5) * 0.6) / ring * math.pi * 2
		local scale = settings.RingScaleMin + (settings.RingScaleMax - settings.RingScaleMin) * random()
		table.insert(outer, at(x + hw * scale * math.cos(angle), y + hh * scale * math.sin(angle), 0))
	end
	local far = math.max(settings.FarPoints, 0)
	local reach = 2 * math.max(frame.HalfWidth, frame.HalfHeight) + math.max(hw, hh)
	for index = 1, far do
		local angle = index / far * math.pi * 2
		table.insert(outer, at(x + reach * math.cos(angle), y + reach * math.sin(angle), 0))
	end
	return sites
end

return ShopGlass
