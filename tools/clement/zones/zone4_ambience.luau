--!nocheck
-- Zone 4 — Los Angeles : ambiance propre de la ville (retour de Clément du 2026-11-17 : « du sound design, des
-- effets dans les villes, des différenciations de zones »). Londres a la pluie, Tokyo les pétales, Paris les
-- feuilles, New York la neige ; Los Angeles a la chaleur :
--  - FX_Z4_HeatHaze : air qui tremble au ras du bitume (voiles chauds très pâles qui montent lentement) ;
--  - FX_Z4_PalmLeaves_<palmier> : brins de palme secs qui tombent de chaque palmier des trottoirs, en vrillant
--    (les palmiers restent en pièces : trees_replace.luau n'y touche pas) ;
--  - SND_Z4_Ambience : deux boucles d'ambiance enregistrées à Los Angeles (ProSoundEffects, partenaire sous
--    licence Roblox) : autoroute lointaine, rumeur de la ville, oiseaux et vent (9112784967, 92 s) ; parking de
--    Toluca Lake, voix, oiseaux, voitures qui passent (9112841159, 36 s). Son 3D dans une pièce au centre de la
--    zone, atténué en Linear de 70 à 125 studs : on l'entend dans la zone 4, plus chez les voisins.
-- Garde la poussière dorée (FX_Z4_GoldenDust) et les reflets de l'entrée (FX_Z4_EntryGlints) du script de zone.
-- Objets natifs seulement (ParticleEmitter, Sound), aucun script. Budget téléphone : 3 émetteurs ajoutés, environ
-- 40 particules à l'écran, 2 sons.
-- À lancer dans Studio (MCP execute_luau, mode Edit), après zone4_losangeles.luau et corridor_widen.luau
-- (couloir de 120 : chaussée |z| < 46.5, trottoirs |z| 46.5..60). Relançable : remplace ses propres objets.
-- Chaque pièce porte CorridorWiden = 30 : corridor_widen.luau ne la redéplace pas.

local rgb = Color3.fromRGB
local Z = workspace.Map.Zone_4
local amb = Z.Street_LosAngeles:FindFirstChild("Ambience")
assert(amb, "Map/Zone_4/Street_LosAngeles/Ambience introuvable : lancer d'abord zone4_losangeles.luau")
for _, c in amb:GetChildren() do
	if c.Name == "FX_Z4_HeatHaze" or c.Name:match("^FX_Z4_PalmLeaves_") or c.Name == "SND_Z4_Ambience" then c:Destroy() end
end
-- les volumes d'effets du script de zone ne doivent arrêter aucun rayon (coups, caméra, clics) : repassés en
-- CanQuery = true une fois (2026-11-17), on les recoupe ici
for _, n in { "FX_Z4_GoldenDust", "FX_Z4_EntryGlints" } do
	local p = amb:FindFirstChild(n)
	if p then p.CanQuery = false; p.CanTouch = false; p.CanCollide = false end
end

local function box(name, cf, size)
	local p = Instance.new("Part")
	p.Name = name; p.Anchored = true; p.CFrame = cf; p.Size = size
	p.Transparency = 1; p.CanCollide = false; p.CanTouch = false; p.CanQuery = false; p.CastShadow = false
	p.Locked = true
	p:SetAttribute("CorridorWiden", 30)
	p.Parent = amb
	return p
end
local function ns(points)
	local kp = {}
	for _, v in points do table.insert(kp, NumberSequenceKeypoint.new(v[1], v[2])) end
	return NumberSequence.new(kp)
end
local function emitter(part, name, o)
	local pe = Instance.new("ParticleEmitter"); pe.Name = name
	pe.Texture = o.texture
	pe.Color = o.color; pe.LightEmission = o.emission or 0; pe.LightInfluence = o.influence or 1
	pe.Size = o.size; pe.Transparency = o.transp; pe.Lifetime = o.life; pe.Rate = o.rate
	pe.Speed = o.speed; pe.SpreadAngle = o.spread or Vector2.new(0, 0); pe.Acceleration = o.accel; pe.Drag = o.drag or 0
	pe.Rotation = NumberRange.new(0, 360); pe.RotSpeed = o.rot
	if o.squash then pe.Squash = o.squash end
	pe.EmissionDirection = o.dir or Enum.NormalId.Top
	pe.Shape = Enum.ParticleEmitterShape.Box; pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	pe.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	pe.Parent = part
	return pe
end

-- 1) Chaleur au ras du bitume : grands voiles chauds, presque transparents, qui montent et s'étalent
local haze = box("FX_Z4_HeatHaze", CFrame.new(449, 1.2, 0), Vector3.new(156, 1.6, 88))
emitter(haze, "HeatShimmer", {
	texture = "rbxasset://textures/particles/smoke_main.dds",
	color = ColorSequence.new(rgb(255, 236, 205), rgb(255, 214, 170)), emission = 0.15, influence = 0.6,
	size = ns({ { 0, 4 }, { 1, 9 } }),
	transp = ns({ { 0, 1 }, { 0.3, 0.93 }, { 0.7, 0.95 }, { 1, 1 } }),
	life = NumberRange.new(2.5, 4), rate = 8, speed = NumberRange.new(0.6, 1.2),
	accel = Vector3.new(0, 0.4, 0), drag = 0.3, rot = NumberRange.new(-8, 8),
	squash = ns({ { 0, -0.5 }, { 1, -0.3 } }), -- plus larges que hautes : une nappe, pas une fumée
})

-- 2) Brins de palme secs qui tombent de chaque palmier des trottoirs (sous sa couronne)
for _, palmModel in Z.Street_LosAngeles.Palms:GetChildren() do
	local crown = palmModel:IsA("Model") and palmModel:FindFirstChild("Crown")
	if not crown then continue end
	local leaves = box("FX_Z4_PalmLeaves_" .. palmModel.Name:gsub("^Palm_", ""), CFrame.new(crown.Position - Vector3.new(0, 2.5, 0)), Vector3.new(9, 2, 9))
	emitter(leaves, "PalmFronds", {
		texture = "rbxasset://textures/particles/SquareParticle.png",
		color = ColorSequence.new({ ColorSequenceKeypoint.new(0, rgb(120, 150, 70)), ColorSequenceKeypoint.new(0.5, rgb(176, 168, 92)),
			ColorSequenceKeypoint.new(1, rgb(196, 170, 110)) }),
		size = ns({ { 0, 0.55 }, { 1, 0.5 } }),
		transp = ns({ { 0, 1 }, { 0.08, 0 }, { 0.85, 0 }, { 1, 1 } }),
		life = NumberRange.new(9, 12), rate = 0.45, speed = NumberRange.new(0.5, 1.5), spread = Vector2.new(180, 180),
		accel = Vector3.new(0.6, -1.6, 0), drag = 0.8, rot = NumberRange.new(-140, 140),
		squash = ns({ { 0, 1.4 }, { 1, 1.4 } }), -- longs et fins, comme un bout de palme
	})
end

-- 3) Son d'ambiance localisé
local snd = box("SND_Z4_Ambience", CFrame.new(449, 8, 0), Vector3.new(2, 2, 2))
-- Convention commune des zones (2026-11-17) : attribut PlayAt = "Day" ou "Night" ; jour livré en lecture, nuit
-- arrêté ; le code les échange à la nuit et à l'aube (volume par le groupe SFX, côté code).
for _, d in { { "Amb_FreewayHum", 9112784967, 0.32, "Day" }, { "Amb_StreetLife", 9112841159, 0.24, "Day" },
	{ "Amb_NightCrickets", 9112772108, 0.3, "Night" } } do -- nuit : autoroute lointaine et grillons (36 s)
	local s = Instance.new("Sound"); s.Name = d[1]
	s.SoundId = "rbxassetid://" .. d[2]; s.Volume = d[3]; s.Looped = true; s.Playing = d[4] == "Day"
	s:SetAttribute("PlayAt", d[4])
	s.RollOffMode = Enum.RollOffMode.Linear; s.RollOffMinDistance = 70; s.RollOffMaxDistance = 125
	s.Parent = snd
end

-- Compte rendu
local n, rate, sounds, scripts = 0, 0, 0, 0
for _, d in Z:GetDescendants() do
	if d:IsA("ParticleEmitter") then n += 1; rate += d.Rate end
	if d:IsA("Sound") then sounds += 1 end
	if d:IsA("LuaSourceContainer") then scripts += 1 end
end
return string.format("Ambiance de Los Angeles posée : %d émetteurs dans la zone 4 (%.1f particules/s), %d sons, %d script", n, rate, sounds, scripts)
