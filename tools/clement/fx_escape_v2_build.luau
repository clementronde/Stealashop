-- FX_Escape v2 : l'éclat de la ligne safe (repasse qualité du 26/11, chef VFX et son)
-- À coller dans la barre de commande de Studio, en Edit. Aucun script n'est créé.
-- Construit ServerStorage/Previews/FX/FX_Escape_v2 en partant d'une copie de Assets/FX/FX_Escape (mêmes Root,
-- Burst et Ground, que le code de Cantin connaît déjà). Rien n'est mis dans Assets : c'est un nouveau visuel,
-- que Clément valide en capture avant qu'on remplace FX_Escape.
--
-- Contenu (≈ 35 particules, budget ≈ 60 ; rythme d'un coup « cher » des tutos du 26/11) :
--   Burst/Flash   1    flash blanc très bref (0,1 s), comme le flash de UI_Escape
--   Burst/Rays    1    rayons qui s'ouvrent en 0,15 s puis tournent, 0,6 s
--   Burst/Stars   14   étoiles en gerbe qui scintillent (taille en dents de scie, kits du 26/11)
--   Burst/Flecks  8    éclats sombres opaques qui retombent : on lit l'éclat de jour
--   Ground/Ring   1    l'onde actuelle, au sol (gardée)
--   Ground/Dust   10   anneau de poussière éclairé (LightEmission 0) qui s'étale et freine : le vrai effet au sol
--   Burst/Light        PointLight ramenée à 2 (une lumière à 3 surexpose de jour), FadeTime 0,3
-- Attributs : EmitCount sur chaque émetteur, Delay 0,05 sur le sol, Duration 2 sur le modèle.
-- RarityTint = true sur Flash, Rays et Stars : teinte de la rareté, si le code la prend en charge (voir L-420).

local SRC = game.ReplicatedStorage.Assets.FX.FX_Escape
local TEX_STAR = "rbxassetid://128771679117306" -- FX_UI_Star (à nous, groupe)
local TEX_RAYS = "rbxassetid://70682642272028" -- FX_UI_Rays (à nous, groupe)
local TEX_GLOW = "rbxassetid://71001560516016" -- lueur dorée des tapis (FX_Treadmill_Gold_Glow)
local TEX_SMOKE = "rbxasset://textures/particles/smoke_main.dds" -- livrée avec le client
local TEX_SQUARE = "rbxasset://textures/particles/SquareParticle.png" -- livrée avec le client

local previews = game.ServerStorage:FindFirstChild("Previews") or Instance.new("Folder")
previews.Name = "Previews"
previews.Parent = game.ServerStorage
local folder = previews:FindFirstChild("FX") or Instance.new("Folder")
folder.Name = "FX"
folder.Parent = previews
local old = folder:FindFirstChild("FX_Escape_v2")
if old then old:Destroy() end

local m = SRC:Clone()
m.Name = "FX_Escape_v2"
m:SetAttribute("Duration", 2)
local root = m:FindFirstChild("Root")
assert(root, "FX_Escape : Root absent")
local burst = root:FindFirstChild("Burst")
local ground = root:FindFirstChild("Ground")
assert(burst and ground, "FX_Escape : Root/Burst ou Root/Ground absent")

local function seq(points: { { number } }): NumberSequence
	local kps = {}
	for _, p in points do
		table.insert(kps, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0))
	end
	return NumberSequence.new(kps)
end
local function emitter(parent: Instance, name: string, count: number, props: { [string]: any }): ParticleEmitter
	local e = parent:FindFirstChild(name) or Instance.new("ParticleEmitter")
	e.Name = name
	e.Rate = 0
	e.Enabled = true
	e:SetAttribute("EmitCount", count)
	for k, v in props do
		if k:sub(1, 1) == "@" then e:SetAttribute(k:sub(2), v) else (e :: any)[k] = v end
	end
	e.Parent = parent
	return e :: ParticleEmitter
end
local GOLD = ColorSequence.new(Color3.fromRGB(255, 236, 150), Color3.fromRGB(255, 196, 70))

emitter(burst, "Flash", 1, {
	Texture = TEX_GLOW, Lifetime = NumberRange.new(0.1), Speed = NumberRange.new(0),
	Size = seq({ { 0, 9 }, { 1, 11 } }), Transparency = seq({ { 0, 0 }, { 0.4, 0 }, { 1, 1 } }),
	Color = ColorSequence.new(Color3.new(1, 1, 1)), LightEmission = 1, LightInfluence = 0, Brightness = 3,
	ZOffset = 2, ["@RarityTint"] = true,
})
emitter(burst, "Rays", 1, {
	Texture = TEX_RAYS, Lifetime = NumberRange.new(0.6), Speed = NumberRange.new(0),
	Size = seq({ { 0, 1 }, { 0.25, 8 }, { 1, 9 } }), Transparency = seq({ { 0, 0.1 }, { 0.6, 0.2 }, { 1, 1 } }),
	Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(40), Color = GOLD,
	LightEmission = 0.6, LightInfluence = 0, Brightness = 1.5, ZOffset = 1, ["@RarityTint"] = true,
})
emitter(burst, "Stars", 14, {
	Texture = TEX_STAR, Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(14, 22),
	SpreadAngle = Vector2.new(180, 180), Drag = 3, Acceleration = Vector3.new(0, -15, 0),
	Size = seq({ { 0, 0 }, { 0.08, 0.7 }, { 0.2, 0.25 }, { 0.35, 0.62 }, { 0.5, 0.2 }, { 0.65, 0.5 }, { 0.8, 0.15 }, { 1, 0 } }),
	Rotation = NumberRange.new(0, 45), Color = GOLD, LightEmission = 0.5, LightInfluence = 0, Brightness = 2,
	ZOffset = 0.5, ["@RarityTint"] = true,
})
emitter(burst, "Flecks", 8, {
	Texture = TEX_SQUARE, Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(16, 24),
	SpreadAngle = Vector2.new(70, 70), EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, -40, 0),
	Size = seq({ { 0, 0.3 }, { 1, 0.2 } }), Transparency = seq({ { 0, 0 }, { 0.8, 0 }, { 1, 1 } }),
	Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-300, 300),
	Color = ColorSequence.new(Color3.fromRGB(95, 62, 20)), LightEmission = 0, LightInfluence = 1,
})
local ring = ground:FindFirstChild("Ring")
if ring and ring:IsA("ParticleEmitter") then ring:SetAttribute("Delay", 0.05) end
emitter(ground, "Dust", 10, {
	Texture = TEX_SMOKE, Lifetime = NumberRange.new(0.8, 1.1), Speed = NumberRange.new(14, 20),
	SpreadAngle = Vector2.new(80, 80), EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, -40, 0),
	Drag = 6, Size = seq({ { 0, 1.5 }, { 1, 4 } }), Transparency = seq({ { 0, 0.25 }, { 0.6, 0.5 }, { 1, 1 } }),
	Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-40, 40),
	Color = ColorSequence.new(Color3.fromRGB(225, 214, 192)), LightEmission = 0, LightInfluence = 1,
	["@Delay"] = 0.05,
})
local light = burst:FindFirstChild("Light")
if light and light:IsA("PointLight") then
	light.Brightness = 1.2 -- Clément, 26/11 : moins de vert de jour (2 → 1,2)
	light:SetAttribute("FadeTime", 0.3)
end

m.Parent = folder
local n = 0
for _, d in m:GetDescendants() do
	if d:IsA("ParticleEmitter") then n += d:GetAttribute("EmitCount") or 0 end
end
print("[FX_Escape_v2] " .. n .. " particules, dans ServerStorage/Previews/FX")
return n
