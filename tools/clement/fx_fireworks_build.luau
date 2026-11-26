--!strict
-- FX_Fireworks (L-371) : reconstruit le prototype dans ServerStorage/_PROTO_FEUX/FX_Fireworks.
-- À coller dans la barre de commande de Studio, en Edit. Valeurs relevées sur le prototype réglé le 2026-11-25
-- et montré à Clément aux deux piliers de la sortie de la safe zone, de jour et de nuit.
--
-- Aucun script dans l'effet. Ce que fait le code (client, pour tous les joueurs) à chaque objet ramené :
--   1. cloner FX_Fireworks sur le CFrame de chaque FireworksPoint (l'effet tire le long de +Y) ;
--   2. teinter à la couleur de la rareté tout objet qui porte l'attribut RarityTint (émetteurs et lumière) ;
--   3. Emit(EmitCount) sur les émetteurs de Root/Launch ;
--   4. après RiseTime : Emit(EmitCount) sur ceux de Root/Burst (sauf Crackle sous MinRarity) et de
--      Root/Confetti ; allumer Burst/Light pendant LightTime ; jouer le son Fireworks_Confetti au point ;
--   5. détruire la copie après Duration.
-- Textures : les nôtres (groupe RoundStone Studio) et celles livrées avec Roblox (rbxasset://) : rien à importer.

local GLOW = "rbxassetid://77605049065513" -- FX_Eclair_GlowSoft (groupe)
local STREAK = "rbxassetid://109836870688610" -- FX_Eclair_RainFine (groupe), trait couché
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

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

local function emitter(parent: Instance, name: string, emitCount: number, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Rate = 0
	e.LightInfluence = 0
	for k, v in props do
		(e :: any)[k] = v
	end
	e:SetAttribute("EmitCount", emitCount)
	e.Parent = parent
	return e
end

local model = Instance.new("Model")
model.Name = "FX_Fireworks"
model:SetAttribute("RiseTime", 1.1) -- montée de la fusée, puis la gerbe
model:SetAttribute("LightTime", 0.2)
model:SetAttribute("Duration", 5)

local root = Instance.new("Part")
root.Name = "Root"
root.Size = Vector3.new(1, 1, 1)
root.Anchored = true
root.CanCollide = false
root.CanQuery = false
root.CanTouch = false
root.CastShadow = false
root.Transparency = 1
root.Parent = model
model.PrimaryPart = root

-- Montée : tout part en même temps vers +Y ; le freinage étale les étincelles et la fumée le long de la montée,
-- la plus rapide (Head) arrive à la gerbe (90 studs) en RiseTime.
local launch = Instance.new("Attachment")
launch.Name = "Launch"
launch.Parent = root

emitter(launch, "Head", 1, {
	Texture = GLOW, Color = rgb(255, 140, 40), ZOffset = 1,
	Size = ns({ { 0, 6 }, { 0.85, 5 }, { 1, 1.5 } }), Transparency = ns({ { 0, 0 }, { 0.85, 0 }, { 1, 1 } }),
	Lifetime = NumberRange.new(1.1), Speed = NumberRange.new(140), Drag = 1.5,
	SpreadAngle = Vector2.new(0, 0), LightEmission = 0.2, Brightness = 3,
})
emitter(launch, "Trail", 70, {
	Texture = STREAK, Color = rgb(255, 150, 50), Orientation = Enum.ParticleOrientation.VelocityParallel,
	Size = ns({ { 0, 4 }, { 0.4, 2.6 }, { 1, 0 } }), Transparency = ns({ { 0, 0 }, { 0.6, 0.3 }, { 1, 1 } }),
	Lifetime = NumberRange.new(0.8, 1.5), Speed = NumberRange.new(11.2, 135.8), Drag = 1.5,
	SpreadAngle = Vector2.new(1.5, 1.5), Acceleration = Vector3.new(0, -4, 0), LightEmission = 0.2, Brightness = 2.5,
})
emitter(launch, "LaunchFlash", 1, {
	Texture = GLOW, Color = rgb(255, 220, 160),
	Size = ns({ { 0, 1 }, { 0.3, 4 }, { 1, 2 } }), Transparency = ns({ { 0, 0.1 }, { 1, 1 } }),
	Lifetime = NumberRange.new(0.25), Speed = NumberRange.new(0), LightEmission = 1, Brightness = 3,
})
emitter(launch, "TrailSmoke", 60, {
	Texture = SMOKE, Color = rgb(140, 140, 152), LightInfluence = 0.6,
	Size = ns({ { 0, 3 }, { 1, 9 } }), Transparency = ns({ { 0, 0.1 }, { 0.5, 0.5 }, { 1, 1 } }),
	Lifetime = NumberRange.new(1.6, 2.6), Speed = NumberRange.new(7, 133), Drag = 1.5,
	SpreadAngle = Vector2.new(1, 1), Acceleration = Vector3.new(1.5, 1, 0),
	Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-30, 30), LightEmission = 0,
})

-- Gerbe : flash, sphère d'étoiles qui retombe, traits qui jaillissent, fumée colorée (lisible de jour),
-- crépitement doré à partir de Légendaire.
local burst = Instance.new("Attachment")
burst.Name = "Burst"
burst.Position = Vector3.new(0, 90, 0)
burst.Parent = root

local function tinted<T>(x: T): T
	(x :: any):SetAttribute("RarityTint", true)
	return x
end
local GOLD = rgb(255, 194, 26) -- couleur d'aperçu (Légendaire) ; le code la remplace par celle de la rareté

tinted(emitter(burst, "Flash", 2, {
	Texture = GLOW, Color = GOLD, ZOffset = -1,
	Size = ns({ { 0, 8 }, { 0.25, 34 }, { 1, 26 } }), Transparency = ns({ { 0, 0.05 }, { 0.4, 0.5 }, { 1, 1 } }),
	Lifetime = NumberRange.new(0.22), Speed = NumberRange.new(0), LightEmission = 1, Brightness = 3,
}))
tinted(emitter(burst, "Stars", 140, {
	Texture = GLOW, Color = GOLD,
	Size = ns({ { 0, 4 }, { 0.6, 3.4 }, { 1, 0 } }), Transparency = ns({ { 0, 0 }, { 0.7, 0.1 }, { 1, 1 } }),
	Lifetime = NumberRange.new(1.8, 2.6), Speed = NumberRange.new(57.04, 62), Drag = 1.6,
	SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, -9, 0), LightEmission = 0.15, Brightness = 2.5,
}))
tinted(emitter(burst, "Streaks", 80, {
	Texture = STREAK, Color = GOLD, Orientation = Enum.ParticleOrientation.VelocityParallel,
	Size = ns({ { 0, 5.5 }, { 0.5, 4 }, { 1, 0 } }), Transparency = ns({ { 0, 0 }, { 0.6, 0.2 }, { 1, 1 } }),
	Lifetime = NumberRange.new(0.8, 1.2), Speed = NumberRange.new(52.7, 62), Drag = 1.6,
	SpreadAngle = Vector2.new(180, 180), LightEmission = 0.5, Brightness = 4,
}))
local crackle = emitter(burst, "Crackle", 140, {
	Texture = SPARKLE, Color = rgb(255, 226, 150),
	Size = ns({ { 0, 1.8 }, { 1, 1.1 } }),
	-- invisible pendant l'ouverture de la gerbe, puis scintille et s'éteint
	Transparency = ns({ { 0, 1 }, { 0.42, 1 }, { 0.46, 0 }, { 0.52, 0.9 }, { 0.57, 0 }, { 0.64, 0.85 }, { 0.7, 0.05 }, { 0.78, 0.9 }, { 0.84, 0.2 }, { 0.92, 0.95 }, { 1, 1 } }),
	Lifetime = NumberRange.new(2, 2.8), Speed = NumberRange.new(12.4, 58.9), Drag = 1.6,
	SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, -7, 0),
	Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-200, 200), LightEmission = 1, Brightness = 5,
})
crackle:SetAttribute("MinRarity", "Legendary")
tinted(emitter(burst, "Smoke", 16, {
	Texture = SMOKE, Color = GOLD, LightInfluence = 0.3, ZOffset = -2,
	Size = ns({ { 0, 6 }, { 0.3, 14 }, { 1, 20 } }), Transparency = ns({ { 0, 0.5 }, { 0.4, 0.65 }, { 1, 1 } }),
	Lifetime = NumberRange.new(2.5, 3.5), Speed = NumberRange.new(15.5, 34.1), Drag = 1.6,
	SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(1.5, 0.5, 0),
	Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-20, 20), LightEmission = 0,
}))

-- Confettis plus bas (Clément, 2026-11-25 : « ajouter des confettis plus bas ») : une pluie de papiers de
-- 4 couleurs à 35 studs, émise en même temps que la gerbe ; le premier lot prend la couleur de la rareté.
-- Papier rectangulaire : texture carrée livrée avec le client + Squash.
local CONFETTI_TEX = "rbxasset://textures/particles/SquareParticle.png"
local confetti = Instance.new("Attachment")
confetti.Name = "Confetti"
confetti.Position = Vector3.new(0, 35, 0)
confetti.Parent = root

local function paper(name: string, color: ColorSequence, count: number): ParticleEmitter
	return emitter(confetti, name, count, {
		Texture = CONFETTI_TEX, Color = color,
		Size = ns({ { 0, 0.7 }, { 1, 0.7 } }), Squash = ns({ { 0, -0.6 }, { 0.5, 0.6 }, { 1, -0.6 } }),
		Transparency = ns({ { 0, 0 }, { 0.85, 0 }, { 1, 1 } }),
		Lifetime = NumberRange.new(3, 4.5), Speed = NumberRange.new(22, 42), Drag = 1.8,
		SpreadAngle = Vector2.new(70, 70), Acceleration = Vector3.new(0, -9, 0),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-320, 320),
		Orientation = Enum.ParticleOrientation.FacingCamera, LightEmission = 0, Brightness = 1.6,
	})
end
tinted(paper("Confetti_Rarity", GOLD, 40))
paper("Confetti_Red", rgb(235, 60, 70), 30)
paper("Confetti_Blue", rgb(60, 140, 255), 30)
paper("Confetti_White", rgb(250, 250, 250), 30)

-- Code de Cantin (VfxController.burst, L-420) : un émetteur avec l'attribut Delay (s) n'émet qu'après ce délai ;
-- la gerbe et les confettis partent à RiseTime. Les lumières s'allument au départ et s'éteignent en FadeTime :
-- FadeTime 0 = lumière coupée (sinon elle éclairerait le haut avant l'arrivée de la fusée).
for _, a in { burst, confetti } do
	for _, e in a:GetChildren() do
		if e:IsA("ParticleEmitter") then
			e:SetAttribute("Delay", 1.1)
		end
	end
end

local light = tinted(Instance.new("PointLight"))
light.Name = "Light"
light.Enabled = false
light.Brightness = 3
light.Range = 60
light.Shadows = false
light.Color = Color3.fromRGB(255, 194, 26)
light:SetAttribute("FadeTime", 0)
light.Parent = burst

local folder = game:GetService("ServerStorage"):FindFirstChild("_PROTO_FEUX") or Instance.new("Folder")
folder.Name = "_PROTO_FEUX"
folder.Parent = game:GetService("ServerStorage")
local old = folder:FindFirstChild("FX_Fireworks")
if old then
	old:Destroy()
end
model.Parent = folder
print("FX_Fireworks reconstruit dans ServerStorage/_PROTO_FEUX")
