--!strict
-- Paquet H (idées 1 et 6 de la vidéo « pousser un œuf », validées par Clément le 26/11) : FX_DisplayPlace et
-- FX_Unbox_SuperLuck. À coller en Edit. Sans DEST (par défaut), construit dans ServerStorage/_PROTO_PaquetH ;
-- avec DEST = "Assets", range dans ReplicatedStorage/Assets/FX (seulement quand les textures sont publiées).
-- Aucun script dans les effets. Comme FX_Escape : une Part Root invisible, des Attachments, émetteurs à Rate 0
-- avec un attribut EmitCount, attribut Duration sur le modèle. Le code clone, place, Emit(EmitCount), détruit après Duration.

local DEST = "Proto" -- "Proto" ou "Assets"
-- Textures : nos FX_UI_Star (étoile 4 branches blanche à liseré foncé) et FX_UI_Rays (rayons réguliers).
-- Publiées au nom du groupe le 26/11 (ID d'image ; Decals et images dans StealAShop-Art/FX/UI/fx_ids.csv).
local TEX_STAR = "rbxassetid://128771679117306" -- FX_UI_Star (Decal 133515599327591)
local TEX_RAYS = "rbxassetid://70682642272028" -- FX_UI_Rays (Decal 80682903274148)
local TEX_RING = "rbxasset://textures/particles/explosion01_shockwave_main.dds" -- livré avec Roblox (déjà dans FX_Unbox_Tier)
local TEX_GLOW = "rbxassetid://77605049065513" -- FX_Eclair_GlowSoft (groupe)

local function ns(t: { { number } }): NumberSequence
	local k = {}
	for _, p in t do
		table.insert(k, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(k)
end
local function rgb(r: number, g: number, b: number): ColorSequence
	return ColorSequence.new(Color3.fromRGB(r, g, b))
end
local function emitter(parent: Instance, name: string, count: number, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Rate = 0
	e.LightInfluence = 0
	for k, v in props do
		(e :: any)[k] = v
	end
	e:SetAttribute("EmitCount", count)
	e.Parent = parent
	return e
end
local function base(name: string, duration: number): (Model, BasePart)
	local m = Instance.new("Model")
	m.Name = name
	m:SetAttribute("Duration", duration)
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 1, 1)
	root.Anchored = true
	root.CanCollide, root.CanQuery, root.CanTouch = false, false, false
	root.CastShadow = false
	root.Transparency = 1
	root.Parent = m
	m.PrimaryPart = root
	return m, root
end

-- 1. FX_DisplayPlace : petites étoiles blanches qui jaillissent de l'objet posé (lancées à +0,5 s par le code)
local place, pRoot = base("FX_DisplayPlace", 1.2)
local pBurst = Instance.new("Attachment")
pBurst.Name = "Burst"
pBurst.Parent = pRoot
emitter(pBurst, "Stars", 10, {
	Texture = TEX_STAR, Color = rgb(255, 255, 255),
	Size = ns({ { 0, 0 }, { 0.2, 0.5 }, { 1, 0 } }), Lifetime = NumberRange.new(0.5, 0.8),
	Speed = NumberRange.new(7, 12), SpreadAngle = Vector2.new(80, 80), Drag = 3, Acceleration = Vector3.new(0, 2, 0),
	Rotation = NumberRange.new(-20, 20), RotSpeed = NumberRange.new(-90, 90), LightEmission = 0.2, Brightness = 2,
})
emitter(pBurst, "Glint", 1, {
	Texture = TEX_STAR, Color = rgb(255, 255, 255), ZOffset = 0.5,
	Size = ns({ { 0, 0 }, { 0.3, 1.3 }, { 1, 0 } }), Lifetime = NumberRange.new(0.35), Speed = NumberRange.new(0),
	Rotation = NumberRange.new(0), RotSpeed = NumberRange.new(120), LightEmission = 0.4, Brightness = 2.5,
})

-- 2. FX_Unbox_SuperLuck : éclat court et doré autour du colis (« SUPER LUCK! »). Les paliers gardent FX_Unbox_Tier.
local luck, lRoot = base("FX_Unbox_SuperLuck", 1.4)
local lBurst = Instance.new("Attachment")
lBurst.Name = "Burst"
lBurst.Parent = lRoot
local GOLD = rgb(255, 200, 40)
emitter(lBurst, "Rays", 1, {
	Texture = TEX_RAYS, Color = GOLD, ZOffset = -1,
	Size = ns({ { 0, 1 }, { 0.2, 7 }, { 1, 8.5 } }), Transparency = ns({ { 0, 0.1 }, { 0.6, 0.3 }, { 1, 1 } }),
	Lifetime = NumberRange.new(0.7), Speed = NumberRange.new(0), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(60),
	LightEmission = 0.5, Brightness = 3,
})
emitter(lBurst, "Flash", 1, {
	Texture = TEX_GLOW, Color = rgb(255, 235, 170), ZOffset = 1,
	Size = ns({ { 0, 2 }, { 0.3, 6 }, { 1, 5 } }), Transparency = ns({ { 0, 0 }, { 1, 1 } }),
	Lifetime = NumberRange.new(0.2), Speed = NumberRange.new(0), LightEmission = 1, Brightness = 3,
})
emitter(lBurst, "Ring", 1, {
	Texture = TEX_RING, Color = GOLD, Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
	EmissionDirection = Enum.NormalId.Top, Size = ns({ { 0, 1 }, { 1, 9 } }), Transparency = ns({ { 0, 0.1 }, { 1, 1 } }),
	Lifetime = NumberRange.new(0.45), Speed = NumberRange.new(0.01), LightEmission = 0.6, Brightness = 2.5,
})
emitter(lBurst, "Stars", 24, {
	Texture = TEX_STAR, Color = GOLD,
	Size = ns({ { 0, 0 }, { 0.15, 0.55 }, { 1, 0 } }), Lifetime = NumberRange.new(0.6, 1.1),
	Speed = NumberRange.new(16, 26), SpreadAngle = Vector2.new(180, 180), Drag = 3.5, Acceleration = Vector3.new(0, -6, 0),
	Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-180, 180), LightEmission = 0.2, Brightness = 2.5,
})

if DEST == "Assets" then
	local fx = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("FX")
	for _, m in { place, luck } do
		local old = fx:FindFirstChild(m.Name)
		if old then
			old:Destroy()
		end
		m.Parent = fx
	end
else
	local ss = game:GetService("ServerStorage")
	local folder = ss:FindFirstChild("_PROTO_PaquetH") or Instance.new("Folder")
	folder.Name = "_PROTO_PaquetH"
	folder.Parent = ss
	for _, m in { place, luck } do
		local old = folder:FindFirstChild(m.Name)
		if old then
			old:Destroy()
		end
		m.Parent = folder
	end
end
print("FX_DisplayPlace et FX_Unbox_SuperLuck construits (" .. DEST .. ")")
