--!strict
-- Chaînes et cadenas de l'antivol (vague 34, L-127 point 4 de Clément), module d'aide d'UnboxController
-- (client, visuel seulement) : sur un objet sous antivol posé au sol (Model FloorItem), deux boucles de
-- chaîne croisées en X sur la face avant (−Z) qui font le tour de l'objet par les côtés et la face arrière,
-- et le cadenas qui pend au croisement. Reprise de la fonction wrap(item) de Clément
-- (tools/clement/antitheft_proto.luau) avec son kit ReplicatedStorage/Assets/FX/FX_AntiTheft :
--   Link (un maillon : normale = X local, grand axe = Z local, à l'échelle 1), Padlock (Model, pivot en
--   haut de l'anse, face avant vers −Z), attributs FitSize, LinkPitch, LinkWidth, WrapAngle.
-- Chaque boucle est un rectangle arrondi collé à la boîte de l'objet, dans un plan qui contient l'axe Z,
-- tourné de ±WrapAngle × l'angle de la diagonale de la face avant ; maillons alternés (à plat, puis de
-- chant), taille et pas × k = √(largeur × hauteur) / FitSize × 1,1. Tout est ancré, sans collision ni
-- requête ni contact, rangé dans un Model AntiTheftChains sous l'objet. Posé une seule fois (jamais
-- refait à chaque image) ; seule l'animation de fin tourne image par image, et seulement pendant 0,37 s.
-- Boîte de l'objet : les pièces visibles (Transparency < 1) dans le repère de son pivot, sans le halo de
-- rareté ni les pièces invisibles (Root) ; aucune pièce visible : Model:GetBoundingBox.
--
-- API :
--   AntiTheftChains.Kit() -> Model?            FX_AntiTheft (Link, Padlock) s'il est livré, sinon nil
--   AntiTheftChains.Wrap(item, kit) -> Model?  pose les chaînes sur `item` (nil : kit incomplet, objet vide)
--   AntiTheftChains.Release(chains)            « UNLOCKED! » : le cadenas saute de 0,3 × k en 0,12 s, puis
--                                              tout passe en transparence 1 en 0,25 s et est détruit
--   AntiTheftChains.Step(dt)                   avance les animations de fin (à chaque image)
--   AntiTheftChains.IsReleasing(chains) -> boolean

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CHAINS_NAME = "AntiTheftChains"
local KIT_PATH = { "Assets", "FX", "FX_AntiTheft" }
-- L-127 (Clément) : fin de l'antivol.
local JUMP_HEIGHT = 0.3 -- × k
local JUMP_TIME = 0.12
local FADE_TIME = 0.25
-- Reprises de wrap(item) (Clément) : marge d'un demi-maillon, écart de la 2e boucle, rayon des coins,
-- au moins 8 maillons par boucle, k × 1,1, cadenas à 0,6 largeur de maillon devant la face avant.
local K_FACTOR = 1.1
local CORNER_SHARE = 0.35
local MIN_LINKS = 8
local PADLOCK_GAP = 0.6

type Releasing = {
	chains: Model,
	padlock: Model?,
	padlockFrom: CFrame?,
	lift: number,
	parts: { [BasePart]: number }, -- transparence de départ
	elapsed: number,
}

local AntiTheftChains = {}

local releasing: { [Model]: Releasing } = {}
local scales: { [Model]: number } = {} -- k de chaque pose

function AntiTheftChains.Kit(): Model?
	local current: Instance? = ReplicatedStorage
	for _, name in KIT_PATH do
		current = if current then current:FindFirstChild(name) else nil
	end
	if current == nil or not current:IsA("Model") then
		return nil
	end
	local link = current:FindFirstChild("Link")
	local padlock = current:FindFirstChild("Padlock")
	if link == nil or not link:IsA("BasePart") or padlock == nil or not padlock:IsA("Model") then
		return nil
	end
	return current :: Model
end

local function numberAttribute(kit: Instance, name: string, default: number): number
	local value = kit:GetAttribute(name)
	return if type(value) == "number" and value == value and value > 0 then value else default
end

-- Boîte des pièces visibles de `item` dans le repère de son pivot (centre, taille).
local function visibleBox(item: Model): (CFrame, Vector3)
	local frame = item:GetPivot()
	local minX: number, minY: number, minZ: number = math.huge, math.huge, math.huge
	local maxX: number, maxY: number, maxZ: number = -math.huge, -math.huge, -math.huge
	local any = false
	for _, inst in item:GetDescendants() do
		if inst:IsA("BasePart") then
			local part = inst :: BasePart
			if part.Transparency >= 1 then
				continue
			end
			any = true
			local half = part.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local world = part.CFrame:PointToWorldSpace(Vector3.new(sx * half.X, sy * half.Y, sz * half.Z))
						local p = frame:PointToObjectSpace(world)
						minX, minY, minZ = math.min(minX, p.X), math.min(minY, p.Y), math.min(minZ, p.Z)
						maxX, maxY, maxZ = math.max(maxX, p.X), math.max(maxY, p.Y), math.max(maxZ, p.Z)
					end
				end
			end
		end
	end
	if not any then
		return item:GetBoundingBox()
	end
	local x0: number, y0: number, z0: number = minX :: number, minY :: number, minZ :: number
	local x1: number, y1: number, z1: number = maxX :: number, maxY :: number, maxZ :: number
	local center = Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
	return frame * CFrame.new(center), Vector3.new(x1 - x0, y1 - y0, z1 - z0)
end

-- Point d'un rectangle arrondi (demi-côtés a, b, rayon r) à l'abscisse curviligne s, en partant du milieu
-- du côté avant (0, −b) vers +x : position (px, py), tangente (tx, ty), normale sortante (ox, oy).
local function roundedRect(a: number, b: number, r: number, s: number): (number, number, number, number, number, number)
	local sx, sy = a - r, b - r
	local quarter = math.pi * r / 2
	-- { longueur, genre, x0 ou centre x, y0 ou centre y, dx ou angle de départ, dy, ox, oy }
	local segments: { { number } } = {
		{ sx, 0, 0, -b, 1, 0, 0, -1 },
		{ quarter, 1, sx, -sy, -math.pi / 2 },
		{ 2 * sy, 0, a, -sy, 0, 1, 1, 0 },
		{ quarter, 1, sx, sy, 0 },
		{ 2 * sx, 0, sx, b, -1, 0, 0, 1 },
		{ quarter, 1, -sx, sy, math.pi / 2 },
		{ 2 * sy, 0, -a, sy, 0, -1, -1, 0 },
		{ quarter, 1, -sx, -sy, math.pi },
		{ sx, 0, -sx, -b, 1, 0, 0, -1 },
	}
	for index, seg in segments do
		if s <= seg[1] or index == #segments then
			if seg[2] == 0 then
				return seg[3] + seg[5] * s, seg[4] + seg[6] * s, seg[5], seg[6], seg[7], seg[8]
			end
			local angle = seg[5] + s / r
			local ox, oy = math.cos(angle), math.sin(angle)
			return seg[3] + ox * r, seg[4] + oy * r, -oy, ox, ox, oy
		end
		s -= seg[1]
	end
	return 0, -b, 1, 0, 0, -1
end

local function quiet(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

function AntiTheftChains.Wrap(item: Model, kit: Model): Model?
	local linkFound = kit:FindFirstChild("Link")
	local padlockFound = kit:FindFirstChild("Padlock")
	if linkFound == nil or not linkFound:IsA("BasePart") or padlockFound == nil or not padlockFound:IsA("Model") then
		return nil
	end
	local linkTemplate = linkFound :: BasePart
	local padlockTemplate = padlockFound :: Model
	local old = item:FindFirstChild(CHAINS_NAME)
	if old then
		old:Destroy() -- jamais deux poses (et jamais les anciennes chaînes dans la boîte de l'objet)
	end
	local cf, size = visibleBox(item)
	if size.X <= 0 or size.Y <= 0 then
		return nil
	end
	local fit = numberAttribute(kit, "FitSize", 2)
	local k = math.sqrt(size.X * size.Y) / fit * K_FACTOR
	local pitch0 = numberAttribute(kit, "LinkPitch", 0.225) * k
	local width = numberAttribute(kit, "LinkWidth", 0.2) * k
	local wrapAngle = numberAttribute(kit, "WrapAngle", 0.85)
	local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2

	local model = Instance.new("Model")
	model.Name = CHAINS_NAME
	local diagonal = math.atan2(hy, hx)
	for loop, sign in { 1, -1 } do
		local theta = sign * diagonal * wrapAngle
		local ux, uy = math.cos(theta), math.sin(theta)
		local u = Vector3.new(ux, uy, 0)
		-- distance du centre au bord de la face avant le long de u
		local reach = math.min(hx / math.max(math.abs(ux), 1e-3), hy / math.max(math.abs(uy), 1e-3))
		local margin = width * 0.5 + 0.01 + (loop - 1) * width * 0.15
		local a = reach + margin
		local b = hz + margin
		local r = math.min(a, b) * CORNER_SHARE
		local total = 4 * (a - r) + 4 * (b - r) + 2 * math.pi * r
		local count = math.max(MIN_LINKS, math.floor(total / pitch0 / 2) * 2) -- pair : l'alternance se referme
		local pitch = total / count
		local n = u:Cross(Vector3.zAxis).Unit -- normale du plan de la boucle
		for i = 0, count - 1 do
			local px, py, tx, ty, ox, oy = roundedRect(a, b, r, i * pitch)
			local pos = u * px + Vector3.zAxis * py
			local t = (u * tx + Vector3.zAxis * ty).Unit
			local o = (u * ox + Vector3.zAxis * oy).Unit
			local xAxis = if i % 2 == 0 then o else n
			local yAxis = t:Cross(xAxis)
			local link = linkTemplate:Clone()
			link.Name = string.format("Link_%d_%02d", loop, i + 1)
			link.Size = linkTemplate.Size * k
			link.CFrame = cf * CFrame.fromMatrix(pos, xAxis, yAxis, t)
			quiet(link)
			link.Parent = model
		end
	end

	local padlock = padlockTemplate:Clone()
	padlock:ScaleTo(k)
	padlock:PivotTo(cf * CFrame.new(0, 0, -(hz + width * PADLOCK_GAP)))
	for _, inst in padlock:GetDescendants() do
		if inst:IsA("BasePart") then
			quiet(inst :: BasePart)
		end
	end
	padlock.Parent = model
	model.Parent = item
	scales[model] = k
	return model
end

function AntiTheftChains.IsReleasing(chains: Model): boolean
	return releasing[chains] ~= nil
end

function AntiTheftChains.Release(chains: Model)
	if releasing[chains] or chains.Parent == nil then
		return
	end
	local k = scales[chains] or 1
	local found = chains:FindFirstChild("Padlock")
	local padlock: Model? = if found and found:IsA("Model") then found :: Model else nil
	local parts: { [BasePart]: number } = {}
	for _, inst in chains:GetDescendants() do
		if inst:IsA("BasePart") then
			parts[inst :: BasePart] = (inst :: BasePart).Transparency
		end
	end
	releasing[chains] = {
		chains = chains,
		padlock = padlock,
		padlockFrom = if padlock then padlock:GetPivot() else nil,
		lift = JUMP_HEIGHT * k,
		parts = parts,
		elapsed = 0,
	}
end

function AntiTheftChains.Step(dt: number)
	if next(releasing) == nil then
		return
	end
	for chains, entry in releasing do
		if chains.Parent == nil then
			releasing[chains] = nil
			scales[chains] = nil
			continue
		end
		entry.elapsed += dt
		local elapsed = entry.elapsed
		local padlock, from = entry.padlock, entry.padlockFrom
		if padlock and from then
			local alpha = math.clamp(elapsed / JUMP_TIME, 0, 1)
			local eased = 1 - (1 - alpha) * (1 - alpha) -- départ vif, arrivée douce
			padlock:PivotTo(from + Vector3.new(0, entry.lift * eased, 0))
		end
		if elapsed > JUMP_TIME then
			local fade = math.clamp((elapsed - JUMP_TIME) / FADE_TIME, 0, 1)
			for part, start in entry.parts do
				part.Transparency = start + (1 - start) * fade
			end
			if fade >= 1 then
				releasing[chains] = nil
				scales[chains] = nil
				chains:Destroy()
			end
		end
	end
end

return AntiTheftChains
