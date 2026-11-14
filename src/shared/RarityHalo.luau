--!strict
-- RarityHalo (vague 37, a122 ; serveur) : le seul rendu du halo de rareté (5.6 du doc : « particules et
-- lumière de la couleur de la rareté, plus denses à chaque palier » ; Commun : aucun), en objets natifs
-- (lumière, particules, rayons), V0 en attendant les textures de halo de Clément (MOD-041). Avant la
-- vague 37, CarryService et DisplayService avaient chacun leur copie ; ce module les remplace sans rien
-- changer à ce qui se voit (mêmes instances, mêmes noms, mêmes valeurs). Il garde deux poses, parce que
-- les deux cas ne se ressemblent pas :
--   - porté ou au sol (CarryService) : un Attachment HaloPoint au centre du colis ou de l'objet, avec
--     sa lumière, ses étincelles HaloSparkles et, du Légendaire au Divine, 8 rayons HaloRay_<n> vers les
--     coins d'un cube ; sur un colis BOX_<Rareté> qui a déjà ses effets (L-097 point 3), seulement ce
--     qui manque ;
--   - exposé (DisplayService) : une pièce invisible RarityHalo autour de l'objet, avec HaloLight,
--     HaloSparkles qui partent de sa surface et, du Légendaire au Divine, des rayons RayBeam derrière
--     l'objet autour de l'Attachment RaysCenter (DisplayController les fait tourner et anime
--     l'arc-en-ciel du Secret, côté client).
-- VISUAL EFFECTS sur OFF : rien ici ; CosmeticController (client) éteint tout ce qui est sous HaloPoint ou
-- RarityHalo (noms lus aussi par DisplayController, ItemIdleController et MutationFxController).
--
-- API :
--   RarityHalo.CarryPoint, .DisplayPart, .RaysCenter    noms posés (HaloPoint, RarityHalo, RaysCenter)
--   RarityHalo.OwnEffects(model) -> OwnEffects           effets déjà présents dans un modèle BOX_<Rareté>
--   RarityHalo.NoEffects                                 aucun effet propre (objet volé, bloc V0)
--   RarityHalo.AddCarried(anchor, center, rarity, own)   halo d'un colis ou objet porté ou au sol
--   RarityHalo.AddDisplayed(model, rarity, boxCFrame, boxSize)   halo d'un objet exposé
--   RarityHalo.Colors(rarity) -> { Color3 }, RarityHalo.Sequence(colors) -> ColorSequence
--                                                        couleurs de la rareté (aussi pour RarityRainbow)

local Rarities = require(script.Parent:WaitForChild("Config"):WaitForChild("Rarities"))

type Rarity = Rarities.Rarity

local RarityHalo = {}

RarityHalo.CarryPoint = "HaloPoint"
RarityHalo.DisplayPart = "RarityHalo"
RarityHalo.RaysCenter = "RaysCenter"

---------------------------------------------------------------- porté ou au sol (CarryService)

-- V0 proposé, absent du doc : texture de particules livrée avec Roblox (aucun asset publié).
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

-- V0 proposé, absent du doc : intensité de chaque palier de halo (Rarities.Halo). Le doc dit
-- seulement « plus denses à chaque palier » ; Commun (None) n'a rien.
type CarrySpec = {
	LightRange: number, -- studs
	LightBrightness: number,
	ParticleRate: number, -- particules par seconde
	ParticleSize: number, -- studs
	Rays: boolean, -- rayons de lumière autour du colis
}
local CARRY_HALOS: { [string]: CarrySpec } = {
	Light = { LightRange = 6, LightBrightness = 1, ParticleRate = 4, ParticleSize = 0.25, Rays = false },
	Clear = { LightRange = 10, LightBrightness = 2, ParticleRate = 10, ParticleSize = 0.35, Rays = false },
	Rays = { LightRange = 14, LightBrightness = 3, ParticleRate = 14, ParticleSize = 0.4, Rays = true },
	Rainbow = { LightRange = 16, LightBrightness = 3, ParticleRate = 20, ParticleSize = 0.45, Rays = true },
	Divine = { LightRange = 18, LightBrightness = 3.5, ParticleRate = 24, ParticleSize = 0.5, Rays = true }, -- L-106
}
-- V0 proposé, absent du doc : 8 rayons vers les coins d'un cube ; longueur et largeur en studs.
local CARRY_RAY_LENGTH = 2.6
local CARRY_RAY_WIDTH = 0.35
local CARRY_RAY_DIRECTIONS: { Vector3 } = {}
for _, x in { -1, 1 } do
	for _, y in { -1, 1 } do
		for _, z in { -1, 1 } do
			table.insert(CARRY_RAY_DIRECTIONS, Vector3.new(x, y, z).Unit)
		end
	end
end

-- Couleurs du halo porté : l'arc-en-ciel à partir de 2 couleurs, sinon la couleur de la rareté.
local function carrySequence(rarity: Rarity): ColorSequence
	local colors = rarity.RainbowColors
	if rarity.Rainbow and colors and #colors >= 2 then
		local keypoints: { ColorSequenceKeypoint } = {}
		for index, color in colors do
			table.insert(keypoints, ColorSequenceKeypoint.new((index - 1) / (#colors - 1), color))
		end
		return ColorSequence.new(keypoints)
	end
	return ColorSequence.new(rarity.Color)
end

-- Effets déjà posés par Clément dans un modèle BOX_<Rareté> (L-097 point 3 : Épique, une lumière Glow ;
-- Légendaire et plus, des étincelles Sparkles et Glow dans Body) : le halo du code ne les double pas.
export type OwnEffects = { Light: boolean, Particles: boolean, Beams: boolean }
RarityHalo.NoEffects = { Light = false, Particles = false, Beams = false } :: OwnEffects

function RarityHalo.OwnEffects(model: Model): OwnEffects
	local found: OwnEffects = { Light = false, Particles = false, Beams = false }
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Light") then
			found.Light = true
		elseif descendant:IsA("ParticleEmitter") or descendant:IsA("Sparkles") then
			found.Particles = true
		elseif descendant:IsA("Beam") then
			found.Beams = true
		end
	end
	return found
end

-- Halo de rareté (5.6) autour de `center` (CFrame dans l'espace de anchor). `own` : effets que le modèle
-- a déjà (choix d'a79, L-097 point 3) : sa lumière remplace celle du halo, ses particules les
-- étincelles du halo, ses Beams les rayons ; le reste du halo est posé comme avant.
function RarityHalo.AddCarried(anchor: BasePart, center: CFrame, rarity: Rarity, own: OwnEffects)
	local spec = CARRY_HALOS[rarity.Halo]
	if spec == nil then
		return -- Commun : aucun halo
	end
	local wantsRays = spec.Rays and not own.Beams
	if own.Light and own.Particles and not wantsRays then
		return -- le modèle a déjà tout le halo
	end
	local colors = carrySequence(rarity)
	local point = Instance.new("Attachment")
	point.Name = RarityHalo.CarryPoint
	point.CFrame = center
	point.Parent = anchor

	if not own.Light then
		local light = Instance.new("PointLight")
		light.Color = rarity.Color
		light.Range = spec.LightRange
		light.Brightness = spec.LightBrightness
		light.Shadows = false
		light.Parent = point
	end

	if not own.Particles then
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Name = "HaloSparkles"
		sparkles.Texture = SPARKLE_TEXTURE
		sparkles.Color = colors
		sparkles.LightEmission = 1
		sparkles.LightInfluence = 0
		sparkles.Rate = spec.ParticleRate
		sparkles.Lifetime = NumberRange.new(0.8, 1.4)
		sparkles.Speed = NumberRange.new(1.5, 2.5)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Size = NumberSequence.new(spec.ParticleSize, 0)
		sparkles.Transparency = NumberSequence.new(0.1, 1)
		sparkles.LockedToPart = true -- un halo qui suit le colis, pas une traînée
		sparkles.Parent = point
	end

	if not wantsRays then
		return
	end
	for index, direction in CARRY_RAY_DIRECTIONS do
		local tip = Instance.new("Attachment")
		tip.Name = `HaloRayTip_{index}`
		tip.CFrame = center * CFrame.new(direction * CARRY_RAY_LENGTH)
		tip.Parent = anchor
		local ray = Instance.new("Beam")
		ray.Name = `HaloRay_{index}`
		ray.Attachment0 = point
		ray.Attachment1 = tip
		ray.FaceCamera = true
		ray.Color = colors
		ray.LightEmission = 1
		ray.LightInfluence = 0
		ray.Width0 = CARRY_RAY_WIDTH
		ray.Width1 = 0
		ray.Transparency = NumberSequence.new(0.15, 1)
		ray.Segments = 1
		ray.Parent = point
	end
end

---------------------------------------------------------------- exposé (DisplayService)

local RAY_FORMAT = "Ray_%02d"

-- V0 proposé, absent du doc : halo de rareté par palier. Texture de particule par défaut de Roblox
-- (étincelles) en attendant les textures de halo de Clément (MOD-041).
type DisplaySpec = {
	Brightness: number, -- PointLight
	Range: number,
	Rate: number, -- particules par seconde
	Size: number, -- taille d'une particule à sa naissance, en studs
	Rays: number, -- rayons de lumière derrière l'objet (0 = aucun)
}
-- L-142 (revue « trop lumineux » de Clément, docs/claude/notes/revue-lumiere.md, point 4) : lumière à environ un
-- tiers (0,3 / 0,5 / 0,8 / 1 / 1,2, valeurs de Clément), portée de 4 à 10 (Clément : les deux bouts ; 5, 7,5 et 9
-- entre les deux, V0 proposés, à l'échelle des anciennes 6 à 16), particules à Rate divisé par 2 (Clément).
local DISPLAY_HALOS: { [string]: DisplaySpec } = {
	Light = { Brightness = 0.3, Range = 4, Rate = 1.5, Size = 0.2, Rays = 0 }, -- Peu commun
	Clear = { Brightness = 0.5, Range = 5, Rate = 4, Size = 0.3, Rays = 0 }, -- Rare, Épique
	Rays = { Brightness = 0.8, Range = 7.5, Rate = 7, Size = 0.35, Rays = 8 }, -- Légendaire, Mythique
	Rainbow = { Brightness = 1, Range = 9, Rate = 10, Size = 0.4, Rays = 10 }, -- Secret
	Divine = { Brightness = 1.2, Range = 10, Rate = 12, Size = 0.45, Rays = 12 }, -- Divine (L-106)
}
-- L-142 (Clément) : particules et rayons moins émissifs, rayons plus transparents (0,35 avant).
local SPARKLE_EMISSION = 0.3
local RAY_EMISSION = 0.3
local RAY_TRANSPARENCY = 0.6
local HALO_MARGIN = 0.3 -- écart entre l'objet et le volume d'où partent les particules
local PARTICLE_LIFETIME = NumberRange.new(0.9, 1.5)
local PARTICLE_SPEED = NumberRange.new(0.3, 0.8)
local PARTICLE_RISE = Vector3.new(0, 0.6, 0)
local RAY_REACH = 1.2 -- les rayons dépassent l'objet de cette longueur
local RAY_START_WIDTH = 0.05
local RAY_END_WIDTH = 0.4 -- × longueur du rayon

-- Couleurs de la rareté : la liste arc-en-ciel du Secret, sinon sa couleur seule.
function RarityHalo.Colors(rarity: Rarity): { Color3 }
	local colors = rarity.RainbowColors
	if rarity.Rainbow and colors and #colors > 0 then
		return colors
	end
	return { rarity.Color }
end

function RarityHalo.Sequence(colors: { Color3 }): ColorSequence
	if #colors == 1 then
		return ColorSequence.new(colors[1])
	end
	local keypoints = {}
	for i, color in colors do
		table.insert(keypoints, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), color))
	end
	return ColorSequence.new(keypoints)
end

local function fade(from: number, to: number): NumberSequence
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, from), NumberSequenceKeypoint.new(1, to) })
end

-- Halo de rareté (5.6) : un volume invisible autour de l'objet, avec une lumière, des
-- particules qui en partent et, du Légendaire au Secret, des rayons derrière l'objet
-- (DisplayController les fait tourner et anime l'arc-en-ciel du Secret, côté client).
function RarityHalo.AddDisplayed(model: Model, rarity: Rarity, boxCFrame: CFrame, boxSize: Vector3)
	local spec = DISPLAY_HALOS[rarity.Halo]
	if spec == nil then
		return -- Commun : aucun halo
	end
	local colors = RarityHalo.Colors(rarity)

	local part = Instance.new("Part")
	part.Name = RarityHalo.DisplayPart
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = boxSize + Vector3.one * (2 * HALO_MARGIN)
	part.CFrame = boxCFrame

	local light = Instance.new("PointLight")
	light.Name = "HaloLight"
	light.Color = colors[1]
	light.Brightness = spec.Brightness
	light.Range = spec.Range
	light.Shadows = false
	light.Parent = part

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "HaloSparkles"
	sparkles.Color = RarityHalo.Sequence(colors)
	sparkles.LightEmission = SPARKLE_EMISSION
	sparkles.LightInfluence = 0
	sparkles.Rate = spec.Rate
	sparkles.Lifetime = PARTICLE_LIFETIME
	sparkles.Speed = PARTICLE_SPEED
	sparkles.Acceleration = PARTICLE_RISE
	sparkles.Size = fade(spec.Size, 0)
	sparkles.Transparency = fade(0.2, 1)
	sparkles.Rotation = NumberRange.new(0, 360)
	sparkles.RotSpeed = NumberRange.new(-90, 90)
	sparkles.Shape = Enum.ParticleEmitterShape.Box
	sparkles.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	sparkles.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	sparkles.Parent = part

	if spec.Rays > 0 then
		-- Dans le plan de la face avant, juste derrière l'objet (sa face avant regarde −Z, 10.1).
		local radius = math.max(boxSize.X, boxSize.Y) / 2 + RAY_REACH
		local center = Instance.new("Attachment")
		center.Name = RarityHalo.RaysCenter
		center.Position = Vector3.new(0, 0, boxSize.Z / 2 + HALO_MARGIN)
		center.Parent = part
		for i = 1, spec.Rays do
			local angle = (i - 1) * 2 * math.pi / spec.Rays
			local tip = Instance.new("Attachment")
			tip.Name = string.format(RAY_FORMAT, i)
			tip.Position = center.Position + Vector3.new(math.cos(angle) * radius, math.sin(angle) * radius, 0)
			tip.Parent = part

			local beam = Instance.new("Beam")
			beam.Name = "RayBeam"
			beam.Attachment0 = center
			beam.Attachment1 = tip
			beam.Color = ColorSequence.new(colors[(i - 1) % #colors + 1])
			beam.Width0 = RAY_START_WIDTH
			beam.Width1 = radius * RAY_END_WIDTH
			beam.Transparency = fade(RAY_TRANSPARENCY, 1)
			beam.LightEmission = RAY_EMISSION
			beam.LightInfluence = 0
			beam.FaceCamera = true
			beam.Segments = 1
			beam.Parent = tip
		end
	end

	part.Parent = model
end

return RarityHalo
