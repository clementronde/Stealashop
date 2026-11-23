--!nocheck
-- Joueur projeté à travers une vitre de boutique (demande de Clément, 2026-11-23 ; choix « trou, réparé après »).
-- Claude de Clément. Effets et sons seulement : ragdoll, poussée, vitre touchée, trou (FragmentAsync) et réparation
-- sont le code d'Ironix. Mode Edit, annulable, relançable. Aucun script.
--
-- ReplicatedStorage/Assets/FX :
--   FX_ShopGlass_Burst   la vitre éclate là où le corps passe. Root invisible et ancré à poser au point d'impact,
--                        LookVector = sens du vol (−Z = vers l'extérieur). Attachments `Out` (éclats et poussière
--                        dehors, dans le sens du vol) et `In` (quelques éclats vers l'intérieur) ; émetteurs à Rate 0
--                        avec l'attribut EmitCount ; PointLight `Flash` (attribut FadeTime) ; Duration sur le modèle.
--   FX_ShopGlass_Reform  la vitre se reforme. Root = boîte du trou (le code lui donne la taille et la place du trou) ;
--                        émetteurs sur Root en forme de boîte (Glints, Haze), à lancer avec Emit(EmitCount) ou à
--                        allumer pendant la reformation ; PointLight `Glow`.
--   FX_ThrownTrail       traînée du joueur projeté, comme FX_BoxTrail : `Carrier` porte TrailTop, TrailBottom et
--                        `Trail` ; le code copie la traînée et ses deux Attachments sur UpperTorso de la victime.
-- ReplicatedStorage/Assets/Sounds/Throw : Throw_Hit, Throw_Whoosh, Throw_GlassBurst, Throw_GlassDebris,
--   Throw_GlassReform (sons Pro Sound Effects déjà vérifiés dans le jeu, repris sous des noms à eux).
--   L'atterrissage garde `Knockback_Land`.
local CHS = game:GetService("ChangeHistoryService")
local A = game:GetService("ReplicatedStorage"):WaitForChild("Assets")
local rec = CHS:TryBeginRecording("Vitre traversée : effets et sons")

local SQUARE = "rbxasset://textures/particles/SquareParticle.png"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local RING = "rbxasset://textures/particles/explosion01_shockwave_main.dds"
local GLASS = Color3.fromHex("#CFEFFF")
local GLASS_D = Color3.fromHex("#8FCBEA")
local function NS(...) local a = { ... } local k = {} for i = 1, #a, 2 do table.insert(k, NumberSequenceKeypoint.new(a[i], a[i + 1])) end return NumberSequence.new(k) end

local function root(m, size)
	local r = Instance.new("Part")
	r.Name = "Root"
	r.Size = size or Vector3.new(1, 1, 1)
	r.Transparency = 1
	r.Anchored = true
	r.CanCollide, r.CanTouch, r.CanQuery = false, false, false
	r.CastShadow = false
	r.Parent = m
	m.PrimaryPart = r
	return r
end
local function att(parent, name, pos)
	local a = Instance.new("Attachment") a.Name = name a.Position = pos or Vector3.zero a.Parent = parent return a
end
local function em(parent, name, props)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Rate = 0
	e.Enabled = true
	for k, v in props do if k ~= "EmitCount" then e[k] = v end end
	if props.EmitCount then e:SetAttribute("EmitCount", props.EmitCount) end
	e.Parent = parent
	return e
end
local function replace(folder, name)
	local old = folder:FindFirstChild(name)
	if old then old:Destroy() end
	local m = Instance.new("Model")
	m.Name = name
	return m
end

-- FX_ShopGlass_Burst ------------------------------------------------------------------------------------
do
	local m = replace(A.FX, "FX_ShopGlass_Burst")
	m:SetAttribute("Duration", 2.5)
	local r = root(m)
	local out = att(r, "Out", Vector3.new(0, 0, -0.2))
	local inn = att(r, "In", Vector3.new(0, 0, 0.2))
	em(out, "Shards", { Texture = SQUARE, Color = ColorSequence.new(GLASS, GLASS_D), LightEmission = 0.35, LightInfluence = 0.6,
		Lifetime = NumberRange.new(0.9, 1.6), Speed = NumberRange.new(22, 42), SpreadAngle = Vector2.new(38, 38),
		EmissionDirection = Enum.NormalId.Front, Acceleration = Vector3.new(0, -70, 0), Drag = 0.6,
		Size = NS(0, 0.55, 1, 0.3), Transparency = NS(0, 0.1, 0.8, 0.2, 1, 1), Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-420, 420), Squash = NS(0, 0.6, 1, -0.4), EmitCount = 46 })
	em(out, "Splinters", { Texture = SQUARE, Color = ColorSequence.new(Color3.new(1, 1, 1)), LightEmission = 0.6,
		Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(30, 55), SpreadAngle = Vector2.new(25, 25),
		EmissionDirection = Enum.NormalId.Front, Acceleration = Vector3.new(0, -50, 0), Size = NS(0, 0.18, 1, 0.08),
		Orientation = Enum.ParticleOrientation.VelocityParallel, Squash = NS(0, -2, 1, -2), EmitCount = 30 })
	em(out, "Glitter", { Texture = SPARK, Color = ColorSequence.new(Color3.fromHex("#E8F8FF")), LightEmission = 1,
		Lifetime = NumberRange.new(0.6, 1.2), Speed = NumberRange.new(6, 16), SpreadAngle = Vector2.new(70, 70),
		EmissionDirection = Enum.NormalId.Front, Acceleration = Vector3.new(0, -12, 0), Size = NS(0, 0.7, 1, 0), EmitCount = 26 })
	em(out, "GlassDust", { Texture = SMOKE, Color = ColorSequence.new(Color3.fromHex("#DDF3FF")), LightEmission = 0.2,
		Lifetime = NumberRange.new(0.8, 1.3), Speed = NumberRange.new(4, 9), SpreadAngle = Vector2.new(60, 60),
		EmissionDirection = Enum.NormalId.Front, Drag = 2, Size = NS(0, 2.5, 1, 6), Transparency = NS(0, 0.55, 1, 1),
		Rotation = NumberRange.new(0, 360), EmitCount = 7 })
	em(out, "Ring", { Texture = RING, Color = ColorSequence.new(Color3.fromHex("#EAF9FF")), LightEmission = 0.8,
		Lifetime = NumberRange.new(0.25, 0.25), Speed = NumberRange.new(0, 0), Size = NS(0, 1.5, 1, 9),
		Transparency = NS(0, 0.2, 1, 1), EmitCount = 1 })
	em(inn, "ShardsBack", { Texture = SQUARE, Color = ColorSequence.new(GLASS, GLASS_D), LightEmission = 0.35,
		Lifetime = NumberRange.new(0.6, 1.1), Speed = NumberRange.new(6, 14), SpreadAngle = Vector2.new(60, 60),
		EmissionDirection = Enum.NormalId.Back, Acceleration = Vector3.new(0, -70, 0), Size = NS(0, 0.4, 1, 0.25),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-300, 300), EmitCount = 12 })
	local flash = Instance.new("PointLight")
	flash.Name = "Flash"
	flash.Color = Color3.fromHex("#DFF6FF")
	flash.Brightness = 5
	flash.Range = 16
	flash.Enabled = false
	flash:SetAttribute("FadeTime", 0.3)
	flash.Parent = out
	m.Parent = A.FX
end

-- FX_ShopGlass_Reform -----------------------------------------------------------------------------------
do
	local m = replace(A.FX, "FX_ShopGlass_Reform")
	m:SetAttribute("Duration", 1.6)
	local r = root(m, Vector3.new(4, 6, 0.3)) -- taille d'un trou du corps ; le code la remplace par celle du trou
	em(r, "Glints", { Texture = SPARK, Color = ColorSequence.new(Color3.fromHex("#F2FBFF")), LightEmission = 1,
		Lifetime = NumberRange.new(0.5, 1.0), Speed = NumberRange.new(0.2, 0.8), SpreadAngle = Vector2.new(180, 180),
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Size = NS(0, 0, 0.3, 0.6, 1, 0), EmitCount = 40 })
	em(r, "Haze", { Texture = SMOKE, Color = ColorSequence.new(Color3.fromHex("#CDEFFF")), LightEmission = 0.5,
		Lifetime = NumberRange.new(0.6, 1.0), Speed = NumberRange.new(0, 0.3),
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Size = NS(0, 1, 1, 2.5), Transparency = NS(0, 1, 0.3, 0.75, 1, 1), EmitCount = 6 })
	local glow = Instance.new("PointLight")
	glow.Name = "Glow"
	glow.Color = Color3.fromHex("#CDEFFF")
	glow.Brightness = 1.5
	glow.Range = 10
	glow.Enabled = false
	glow:SetAttribute("FadeTime", 0.8)
	glow.Parent = r
	m.Parent = A.FX
end

-- FX_ThrownTrail ------------------------------------------------------------------------------------------
do
	local m = replace(A.FX, "FX_ThrownTrail")
	local c = Instance.new("Part")
	c.Name = "Carrier"
	c.Size = Vector3.new(1, 1, 1)
	c.Transparency = 1
	c.Anchored = true
	c.CanCollide, c.CanTouch, c.CanQuery = false, false, false
	c.Parent = m
	m.PrimaryPart = c
	local top = att(c, "TrailTop", Vector3.new(0, 0.9, 0))
	local bottom = att(c, "TrailBottom", Vector3.new(0, -0.9, 0))
	local t = Instance.new("Trail")
	t.Name = "Trail"
	t.Attachment0 = top
	t.Attachment1 = bottom
	t.Lifetime = 0.35
	t.MinLength = 0.05
	t.FaceCamera = true
	t.LightEmission = 0.6
	t.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHex("#CFEFFF"))
	t.Transparency = NS(0, 0.25, 1, 1)
	t.WidthScale = NS(0, 1, 1, 0.15)
	t.Parent = c
	m.Parent = A.FX
end

-- Sons ------------------------------------------------------------------------------------------------------
do
	local folder = A.Sounds:FindFirstChild("Throw") or Instance.new("Folder")
	folder.Name = "Throw"
	folder.Parent = A.Sounds
	local SOUNDS = {
		{ "Throw_Hit", 9120728815, 0.9, 0.9 },          -- même son que HitWindowHeavy_Impact, plus grave : le coup qui projette
		{ "Throw_Whoosh", 9120972457, 0.8, 0.85 },      -- même son qu'Unbox_KickWhoosh : le corps qui part
		{ "Throw_GlassBurst", 9114590265, 1.0, 1.05 },  -- même son que Glass_BreakShatter : la vitre qui éclate
		{ "Throw_GlassDebris", 9114601217, 0.6, 1.0 },  -- même son que Glass_BreakDebris : les éclats qui retombent
		{ "Throw_GlassReform", 9126073001, 0.5, 1.2 },  -- même son que Reveal_RarityLow, plus aigu : la vitre qui se reforme
	}
	for _, s in SOUNDS do
		local snd = folder:FindFirstChild(s[1]) or Instance.new("Sound")
		snd.Name = s[1]
		snd.SoundId = "rbxassetid://" .. s[2]
		snd.Volume = s[3]
		snd.PlaybackSpeed = s[4]
		snd.Parent = folder
	end
end

if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
local n = {}
for _, k in { "FX_ShopGlass_Burst", "FX_ShopGlass_Reform", "FX_ThrownTrail" } do
	local c = 0
	for _, d in A.FX[k]:GetDescendants() do if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Light") then c += 1 end end
	table.insert(n, k .. " (" .. c .. " effets)")
end
return table.concat(n, ", ") .. " ; sons : " .. #A.Sounds.Throw:GetChildren()
