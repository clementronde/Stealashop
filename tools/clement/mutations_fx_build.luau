-- Effets des 7 mutations sur les objets (Config/Mutations), v2 après le retour de Clément (2026-11-13) :
-- Rainbow change de couleur en boucle avec un arc-en-ciel derrière, Glitch a l'air « bugé », Shiny a
-- de grosses étoiles, Diamond rend l'objet bleu diamant. À lancer en Edit. Relançable. Aucun script.
--
-- ReplicatedStorage/Assets/FX/Mutations (attribut ReferenceSize = 2 : les tailles de particules sont
-- faites pour un objet de 2 studs ; le code les multiplie par plus grand côté de l'objet / 2).
--   FX_Mutation_<Id> (Folder), attributs :
--     ColorMode  "Keep" (couleurs gardées), "Shade" (TintColor × la clarté de chaque pièce, entre
--                ShadeMin et 1 : l'objet prend la couleur et garde son dessin), "Saturate" (couleurs
--                de l'objet poussées : saturation >= 0,85, valeur >= 0,95) ;
--     TintColor, ShadeMin ; Material (nom d'Enum.Material, vide = gardé) ; Reflectance (-1 = gardé) ;
--     Motion     "None", "Pulse" (valeur des couleurs entre 0,75 et 1), "Glitch", "Rainbow" ;
--     MotionPeriod (s) ; EmitterBoxScale (taille de la pièce des particules, en part de la boîte :
--     < 1 = particules plus près de l'objet) ; LightBrightness et LightRange (PointLight de la couleur
--     moyenne de l'objet dans MutationFX, portée × k ; 0 = pas de lumière) ; GlitchJump (saut de
--     l'objet, en part du plus grand côté) et GlitchSpread (écart des doubles pendant un saut).
--   Enfants :
--     Emitters (Folder) : ParticleEmitter en Shape Box / Surface, à cloner dans une pièce invisible
--                de la taille de la boîte de l'objet ;
--     Ghosts (Folder, Neon, Glitch, Hacked, Rainbow) : Configuration Ghost_NN ou Glow_NN, une copie
--                de l'objet par entrée, attributs Color, KeepColor (true = chaque pièce garde la
--                couleur de la pièce de l'objet : coque de lueur), Material, Transparency, Offset
--                (Vector3, en part de la taille de la boîte, repère de l'objet), Scale, Jitter (part
--                du plus grand côté) ;
--     Extras (Folder, Rainbow) : Model RainbowArc (attribut FitHeight), posé derrière l'objet.
-- Le mouvement (Pulse, Glitch, Rainbow) est joué par le code ; tools/clement/mutations_proto.luau
-- le montre en Edit et sert de modèle.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GLINT = "rbxassetid://116430793597850" -- étoile à 4 branches blanche (FX_Treadmill_Ice_Sparkle)
local GOLD_GLINT = "rbxassetid://127314074011197" -- étoile dorée (FX_Treadmill_Gold_Sparkle)
local SQUARE = "rbxasset://textures/particles/SquareParticle.png" -- livrée avec le client

local recording = ChangeHistoryService:TryBeginRecording("Effets des mutations v3")

local function hex(h: string): Color3
	return Color3.fromHex(h)
end

local function pop(peak: number): NumberSequence
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.35, peak),
		NumberSequenceKeypoint.new(1, 0),
	})
end

local function rainbowSeq(): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, hex("FF4D4D")),
		ColorSequenceKeypoint.new(0.2, hex("FFA63D")),
		ColorSequenceKeypoint.new(0.4, hex("FFE94D")),
		ColorSequenceKeypoint.new(0.6, hex("5CFF6B")),
		ColorSequenceKeypoint.new(0.8, hex("4DC3FF")),
		ColorSequenceKeypoint.new(1, hex("B56BFF")),
	})
end

-- Réglages communs des émetteurs, puis ceux de chaque effet.
local function emitter(props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	e.Speed = NumberRange.new(0)
	e.LightInfluence = 0
	e.Rotation = NumberRange.new(-15, 15)
	e.RotSpeed = NumberRange.new(0)
	e.ZOffset = 0.6
	for k, v in props do
		(e :: any)[k] = v
	end
	return e
end

local function ghost(name: string, props: { [string]: any }): Configuration
	local c = Instance.new("Configuration")
	c.Name = name
	for k, v in props do
		c:SetAttribute(k, v)
	end
	return c
end

type Style = {
	ColorMode: string,
	TintColor: string,
	ShadeMin: number,
	Material: string,
	Reflectance: number,
	Motion: string,
	Period: number,
	Emitters: { ParticleEmitter },
	Ghosts: { Configuration }?,
	Extra: { [string]: any }?, -- attributs en plus (EmitterBoxScale, LightBrightness, …)
}

local STYLES: { [string]: Style } = {
	-- Shiny : l'objet garde ses couleurs, de grosses étoiles blanches scintillent autour.
	Shiny = {
		ColorMode = "Keep", TintColor = "FFFFFF", ShadeMin = 1, Material = "", Reflectance = 0.1,
		Motion = "None", Period = 0,
		Emitters = {
			emitter({ Name = "Glints", Texture = GLINT, Color = ColorSequence.new(hex("FFFFFF")), Size = pop(1.1),
				Lifetime = NumberRange.new(0.5, 0.8), Rate = 2.5, LightEmission = 0.6, Brightness = 1.6 }),
			emitter({ Name = "Twinkles", Texture = GLINT, Color = ColorSequence.new(hex("FFFFFF")), Size = pop(0.35),
				Lifetime = NumberRange.new(0.3, 0.6), Rate = 7, LightEmission = 0.4 }),
		},
	},
	-- Gold : objet tout en or (son dessin reste lisible), paillettes dorées.
	Gold = {
		ColorMode = "Shade", TintColor = "FFC531", ShadeMin = 0.5, Material = "Foil", Reflectance = 0.05,
		Motion = "None", Period = 0,
		Emitters = {
			emitter({ Name = "Sparkles", Texture = GOLD_GLINT, Color = ColorSequence.new(hex("FFFFFF")), Size = pop(0.6),
				Lifetime = NumberRange.new(0.4, 0.8), Rate = 4, LightEmission = 0.4 }),
		},
	},
	-- Neon : les couleurs de l'objet en néon vif, avec une vraie lueur : deux coques de néon
	-- translucides autour de lui et une lumière de sa couleur, qui respirent ensemble.
	Neon = {
		ColorMode = "Saturate", TintColor = "FFFFFF", ShadeMin = 1, Material = "Neon", Reflectance = -1,
		Motion = "Pulse", Period = 1.6,
		Emitters = {},
		Ghosts = {
			ghost("Glow_01", { Color = hex("FFFFFF"), KeepColor = true, Material = "Neon", Transparency = 0.7, Offset = Vector3.zero, Scale = 1.06, Jitter = 0 }),
			ghost("Glow_02", { Color = hex("FFFFFF"), KeepColor = true, Material = "Neon", Transparency = 0.86, Scale = 1.14, Offset = Vector3.zero, Jitter = 0 }),
		},
		Extra = { LightBrightness = 1.2, LightRange = 6 },
	},
	-- Diamond : objet tout bleu diamant, en cristal, éclats blancs et bleus.
	Diamond = {
		ColorMode = "Shade", TintColor = "6FDCFF", ShadeMin = 0.6, Material = "Glass", Reflectance = 0.3,
		Motion = "None", Period = 0,
		Emitters = {
			emitter({ Name = "Glints", Texture = GLINT, Color = ColorSequence.new(hex("E6FBFF")), Size = pop(0.85),
				Lifetime = NumberRange.new(0.4, 0.7), Rate = 3, LightEmission = 0.5, Brightness = 1.4 }),
			emitter({ Name = "Twinkles", Texture = GLINT, Color = ColorSequence.new(hex("7FDBFF")), Size = pop(0.3),
				Lifetime = NumberRange.new(0.3, 0.6), Rate = 6, LightEmission = 0.4 }),
		},
	},
	-- Glitch : l'objet « bugue » : deux doubles magenta et cyan collés à lui qui tremblent, de petits
	-- sauts, et des pixels carrés qui clignotent sur lui.
	Glitch = {
		ColorMode = "Keep", TintColor = "FFFFFF", ShadeMin = 1, Material = "", Reflectance = -1,
		Motion = "Glitch", Period = 0.9,
		Emitters = {
			emitter({ Name = "PixelsMagenta", Texture = SQUARE, Color = ColorSequence.new(hex("FF2E88")),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12, 0.05), NumberSequenceKeypoint.new(1, 0.12, 0.05) }),
				Lifetime = NumberRange.new(0.08, 0.2), Rate = 8, LightEmission = 0.2, Rotation = NumberRange.new(0), ZOffset = 0.2 }),
			emitter({ Name = "PixelsCyan", Texture = SQUARE, Color = ColorSequence.new(hex("2EFFF0")),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12, 0.05), NumberSequenceKeypoint.new(1, 0.12, 0.05) }),
				Lifetime = NumberRange.new(0.08, 0.2), Rate = 8, LightEmission = 0.2, Rotation = NumberRange.new(0), ZOffset = 0.2 }),
			emitter({ Name = "PixelsDark", Texture = SQUARE, Color = ColorSequence.new(hex("14141F")),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.14, 0.06), NumberSequenceKeypoint.new(1, 0.14, 0.06) }),
				Lifetime = NumberRange.new(0.06, 0.15), Rate = 6, LightEmission = 0, Rotation = NumberRange.new(0), ZOffset = 0.2 }),
		},
		Ghosts = {
			ghost("Ghost_01", { Color = hex("FF2E88"), KeepColor = false, Material = "ForceField", Transparency = 0, Offset = Vector3.new(-0.025, 0.01, 0), Scale = 1, Jitter = 0.015 }),
			ghost("Ghost_02", { Color = hex("2EFFF0"), KeepColor = false, Material = "ForceField", Transparency = 0, Offset = Vector3.new(0.025, -0.01, 0), Scale = 1, Jitter = 0.015 }),
		},
		Extra = { EmitterBoxScale = 0.8, GlitchJump = 0.03, GlitchSpread = 1.8 },
	},
	-- Hacked : objet vert « code » sous une coque d'hologramme collée à lui, des bits qui montent
	-- tout près de sa surface.
	Hacked = {
		ColorMode = "Shade", TintColor = "39FF5A", ShadeMin = 0.25, Material = "SmoothPlastic", Reflectance = 0,
		Motion = "Glitch", Period = 1.6,
		Emitters = {
			emitter({ Name = "Bits", Texture = SQUARE, Color = ColorSequence.new(hex("7CFF6B")),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.07, 0.03), NumberSequenceKeypoint.new(1, 0.07, 0.03) }),
				Lifetime = NumberRange.new(0.4, 0.7), Rate = 12, LightEmission = 0.3, Rotation = NumberRange.new(0),
				Speed = NumberRange.new(0.12, 0.25), Acceleration = Vector3.new(0, 0.5, 0), ZOffset = 0.2 }),
		},
		Ghosts = {
			ghost("Ghost_01", { Color = hex("39FF5A"), KeepColor = false, Material = "ForceField", Transparency = 0, Offset = Vector3.zero, Scale = 1.03, Jitter = 0.008 }),
		},
		Extra = { EmitterBoxScale = 0.85, GlitchJump = 0.015, GlitchSpread = 1.5 },
	},
	-- Rainbow : tout l'objet change de couleur en boucle (rouge, orange, jaune, vert, bleu, violet),
	-- lumineux, avec un arc-en-ciel derrière et des étoiles de toutes les couleurs.
	Rainbow = {
		ColorMode = "Shade", TintColor = "FF4D4D", ShadeMin = 0.65, Material = "Neon", Reflectance = -1,
		Motion = "Rainbow", Period = 3,
		Emitters = {
			emitter({ Name = "Sparkles", Texture = GLINT, Color = rainbowSeq(), Size = pop(0.6),
				Lifetime = NumberRange.new(0.5, 0.9), Rate = 4, LightEmission = 0.5 }),
		},
		Ghosts = {
			ghost("Glow_01", { Color = hex("FFFFFF"), KeepColor = true, Material = "Neon", Transparency = 0.78, Offset = Vector3.zero, Scale = 1.08, Jitter = 0 }),
		},
		Extra = { LightBrightness = 1, LightRange = 6 },
	},
}

-- Arc-en-ciel : 7 rubans concentriques (Beam, face à la caméra) en demi-cercle, faits pour un objet
-- de FitHeight studs. Pivot au centre de l'arc ; l'arc s'ouvre vers +Y, dans le plan XY.
local function rainbowArc(): Model
	local FIT = 2
	local model = Instance.new("Model")
	model.Name = "RainbowArc"
	model:SetAttribute("FitHeight", FIT)
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CastShadow = false
	root.Transparency = 1
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.CFrame = CFrame.new()
	root.Parent = model
	local colors = { "FF4D4D", "FFA63D", "FFE94D", "5CFF6B", "4DC3FF", "6B7BFF", "B56BFF" }
	local width = 0.13
	for i, c in colors do
		local r = 1.55 - (i - 1) * width
		local a0 = Instance.new("Attachment")
		a0.Name = "A0_" .. i
		-- l'axe (X local) de l'attache pointe vers le haut : la courbe part vers +Y
		a0.CFrame = CFrame.fromMatrix(Vector3.new(-r, 0, 0), Vector3.yAxis, -Vector3.xAxis)
		a0.Parent = root
		local a1 = Instance.new("Attachment")
		a1.Name = "A1_" .. i
		a1.CFrame = CFrame.fromMatrix(Vector3.new(r, 0, 0), -Vector3.yAxis, Vector3.xAxis)
		a1.Parent = root
		local beam = Instance.new("Beam")
		beam.Name = "Band_" .. i
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.CurveSize0 = r * 4 / 3
		beam.CurveSize1 = r * 4 / 3
		beam.Width0 = width
		beam.Width1 = width
		beam.Segments = 30
		beam.FaceCamera = true
		beam.Color = ColorSequence.new(hex(c))
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.18, 0.45),
			NumberSequenceKeypoint.new(0.82, 0.45),
			NumberSequenceKeypoint.new(1, 1),
		})
		beam.LightEmission = 0.3
		beam.LightInfluence = 0
		beam.Parent = root
	end
	model.PrimaryPart = root
	return model
end

local fxAssets = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("FX")
assert(fxAssets, "ReplicatedStorage/Assets/FX introuvable")
local old = fxAssets:FindFirstChild("Mutations")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "Mutations"
root:SetAttribute("ReferenceSize", 2)
for id, style in STYLES do
	local folder = Instance.new("Folder")
	folder.Name = "FX_Mutation_" .. id
	folder:SetAttribute("ColorMode", style.ColorMode)
	folder:SetAttribute("TintColor", hex(style.TintColor))
	folder:SetAttribute("ShadeMin", style.ShadeMin)
	folder:SetAttribute("Material", style.Material)
	folder:SetAttribute("Reflectance", style.Reflectance)
	folder:SetAttribute("Motion", style.Motion)
	folder:SetAttribute("MotionPeriod", style.Period)
	local extra = style.Extra or {}
	folder:SetAttribute("EmitterBoxScale", extra.EmitterBoxScale or 1)
	folder:SetAttribute("LightBrightness", extra.LightBrightness or 0)
	folder:SetAttribute("LightRange", extra.LightRange or 0)
	folder:SetAttribute("GlitchJump", extra.GlitchJump or 0)
	folder:SetAttribute("GlitchSpread", extra.GlitchSpread or 1)
	local emitters = Instance.new("Folder")
	emitters.Name = "Emitters"
	for _, e in style.Emitters do
		e.Parent = emitters
	end
	emitters.Parent = folder
	if style.Ghosts then
		local ghosts = Instance.new("Folder")
		ghosts.Name = "Ghosts"
		for _, g in style.Ghosts do
			g.Parent = ghosts
		end
		ghosts.Parent = folder
	end
	if id == "Rainbow" then
		local extras = Instance.new("Folder")
		extras.Name = "Extras"
		rainbowArc().Parent = extras
		extras.Parent = folder
	end
	folder.Parent = root
end
root.Parent = fxAssets

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
print("Assets/FX/Mutations v3 construit")
