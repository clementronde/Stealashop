--!nocheck
-- Zone 5 — Paris : ambiance propre à la ville (retour de Clément du 2026-11-17 : sons et effets par ville).
-- À lancer dans Studio (MCP execute_luau, mode Edit). Relançable : refait Map/Zone_5/Ambience_Paris à l'identique.
-- La neige qui tombe (Street_Paris/Weather) reste la marque de la zone ; on y ajoute :
-- - un accordéon musette devant le café, en boucle, entendu dans la rue seulement (Sound localisé, RollOff) ;
-- - des pigeons sur les trottoirs, avec leur roucoulement près du groupe du sud ;
-- - un marchand de marrons chauds à l'entrée, braises qui rougeoient et fumée légère (ParticleEmitter) ;
-- - une guirlande d'ampoules sous l'auvent du café (Beam et petites ampoules néon).
-- Objets natifs seulement, aucun script ; décor sans collision. Coordonnées du couloir à 120 (façades à |z| 60,
-- trottoirs |z| 47,2..60, chaussée |z| < 46,5) et de la zone x 530..718 ; la chaussée reste libre.
-- Sons : « Petite Musette » (APM Music, compte APMOfficial vérifié, 102 s) ; « Pigeon Cooing Sound Effect »
-- (audio public, chargement vérifié par PreloadAsync, 9 s).

local rgb = Color3.fromRGB
local Z = workspace.Map.Zone_5
local old = Z:FindFirstChild("Ambience_Paris"); if old then old:Destroy() end
local A = Instance.new("Folder"); A.Name = "Ambience_Paris"

local function part(parent, name, cf, size, color, opt)
	opt = opt or {}
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color; p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = opt.mat or Enum.Material.SmoothPlastic
	if opt.shape then p.Shape = opt.shape end
	p.CanCollide = false; p.CanTouch = false; p.CanQuery = false
	if opt.noShadow then p.CastShadow = false end
	if opt.T then p.Transparency = opt.T end
	p.Parent = parent
	return p
end
local function vcyl(parent, name, x, y0, y1, z, dia, color, opt)
	opt = opt or {}; opt.shape = Enum.PartType.Cylinder
	return part(parent, name, CFrame.new(x, (y0 + y1) / 2, z) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(y1 - y0, dia, dia), color, opt)
end
local function speaker(parent, name, pos, id, volume, rmin, rmax)
	local p = part(parent, name, CFrame.new(pos), Vector3.new(1, 1, 1), rgb(255, 255, 255), { T = 1, noShadow = true })
	local s = Instance.new("Sound"); s.Name = "Loop"
	s.SoundId = "rbxassetid://" .. id; s.Looped = true; s.Volume = volume
	s.RollOffMode = Enum.RollOffMode.InverseTapered; s.RollOffMinDistance = rmin; s.RollOffMaxDistance = rmax
	s.Playing = true
	s:SetAttribute("PlayAt", "Day")   -- convention commune des zones : livré en lecture le jour, le code le coupe la nuit
	s.Parent = p
	return p
end

-- 1) Accordéon musette devant le café (façade x 670,7..693,7 au nord)
speaker(A, "MusetteSpeaker", Vector3.new(682, 8, 57), 1845009018, 0.45, 18, 85)

-- 2) Pigeons sur les trottoirs (3 pièces chacun), roucoulement près du groupe du sud
local P = Instance.new("Model"); P.Name = "Pigeons"; P.Parent = A
local SIDEWALK = 0.45
local plumage = { rgb(122, 126, 140), rgb(108, 112, 126), rgb(138, 140, 150), rgb(96, 98, 110) }
local flock = {
	{ 590.5, -50.2, 20 }, { 592.2, -51.6, 140 }, { 593.8, -49.6, 75 }, { 595.1, -52.3, 210 }, { 596.9, -50.8, 300 },
	{ 598.4, -52.9, 160 }, { 591.4, -53.6, 255 }, { 697, 52, 40 }, { 698.6, 53.4, 190 }, { 700.1, 51.6, 310 },
}
for i, b in flock do
	local m = Instance.new("Model"); m.Name = "Pigeon_" .. i; m.Parent = P
	local base = CFrame.new(b[1], SIDEWALK, b[2]) * CFrame.Angles(0, math.rad(b[3]), 0)
	local o = { noShadow = true }
	part(m, "Body", base * CFrame.new(0, 0.36, 0), Vector3.new(0.62, 0.56, 1.05), plumage[(i - 1) % #plumage + 1], o)
	local neck = { shape = Enum.PartType.Ball, noShadow = true }
	part(m, "Head", base * CFrame.new(0, 0.78, -0.48), Vector3.new(0.42, 0.42, 0.42), rgb(78, 82, 96), neck)
	part(m, "Tail", base * CFrame.new(0, 0.42, 0.66) * CFrame.Angles(math.rad(12), 0, 0), Vector3.new(0.46, 0.1, 0.5), rgb(70, 72, 84), o)
end
speaker(A, "PigeonSpeaker", Vector3.new(594, 1.5, -51.5), 7616212411, 0.3, 5, 26)

-- 3) Marchand de marrons chauds, trottoir sud à l'entrée (devant la librairie, sous la hauteur de l'auvent)
do
	local m = Instance.new("Model"); m.Name = "ChestnutCart"; m.Parent = A
	local x, z = 560, -53.25
	local green, iron = rgb(40, 70, 52), rgb(34, 34, 38)
	part(m, "Body", CFrame.new(x, 2.85, z), Vector3.new(5, 2.0, 2.5), green)
	part(m, "Trim", CFrame.new(x, 3.9, z), Vector3.new(5.2, 0.12, 2.7), rgb(212, 176, 90), { noShadow = true })
	for k, wz in { z - 1.4, z + 1.4 } do
		part(m, "Wheel_" .. k, CFrame.new(x, SIDEWALK + 1.2, wz) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(0.3, 2.4, 2.4), iron, { shape = Enum.PartType.Cylinder })
	end
	part(m, "Handle", CFrame.new(x - 3.1, 3.4, z), Vector3.new(1.4, 0.18, 2.2), iron, { noShadow = true })
	vcyl(m, "Brazier", x - 0.9, 3.96, 5.1, z, 1.8, iron)
	local coals = vcyl(m, "Coals", x - 0.9, 5.1, 5.2, z, 1.5, rgb(255, 120, 40), { mat = Enum.Material.Neon, noShadow = true })
	local glow = Instance.new("PointLight"); glow.Color = rgb(255, 140, 60); glow.Range = 10; glow.Brightness = 1; glow.Shadows = false; glow.Parent = coals
	vcyl(m, "Chimney", x + 1.4, 3.96, 7.4, z - 0.6, 0.35, iron)
	local sign = part(m, "Sign", CFrame.new(x, 2.85, z + 1.3), Vector3.new(4.6, 1.3, 0.1), rgb(244, 236, 214), { noShadow = true })
	local g = Instance.new("SurfaceGui"); g.Name = "LabelGui"; g.Face = Enum.NormalId.Back
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = 40; g.LightInfluence = 0
	local t = Instance.new("TextLabel"); t.Name = "Label"; t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(1, 1)
	t.Text = "HOT CHESTNUTS"; t.TextScaled = true; t.TextWrapped = true; t.TextColor3 = rgb(120, 28, 36)
	t.FontFace = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)
	t.Parent = g; g.Parent = sign
	local top = Instance.new("Attachment"); top.Name = "SmokeOut"; top.Position = Vector3.new(1.75, 0, 0)
	local chim = m.Chimney; top.Parent = chim   -- haut du tuyau (axe local x du cylindre vertical)
	local e = Instance.new("ParticleEmitter"); e.Name = "Smoke"
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Rate = 6; e.Lifetime = NumberRange.new(2.5, 3.5); e.Speed = NumberRange.new(1.5, 2.5)
	e.EmissionDirection = Enum.NormalId.Right   -- local +x du cylindre = vers le haut
	e.SpreadAngle = Vector2.new(12, 12); e.Acceleration = Vector3.new(0.4, 0.6, 0)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 2.4) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	e.Color = ColorSequence.new(rgb(214, 214, 218)); e.LightEmission = 0; e.LightInfluence = 1
	e.Parent = top
end

-- 4) Guirlande d'ampoules sous l'auvent du café : 4 festons (Beam) et 8 ampoules
do
	local m = Instance.new("Model"); m.Name = "CafeGarland"; m.Parent = A
	local y, z, x0, span = 9.3, 56.4, 672.5, 4.75
	local anchor = part(m, "Anchor", CFrame.new(x0, y, z), Vector3.new(0.2, 0.2, 0.2), rgb(40, 40, 44), { T = 1, noShadow = true })
	local warm = rgb(255, 214, 150)
	for k = 0, 3 do
		local a0 = Instance.new("Attachment"); a0.Parent = anchor; a0.WorldPosition = Vector3.new(x0 + k * span, y, z)
		local a1 = Instance.new("Attachment"); a1.Parent = anchor; a1.WorldPosition = Vector3.new(x0 + (k + 1) * span, y, z)
		local b = Instance.new("Beam"); b.Name = "Wire_" .. (k + 1)
		b.Attachment0 = a0; b.Attachment1 = a1; b.Width0 = 0.06; b.Width1 = 0.06; b.FaceCamera = true
		b.CurveSize0 = -0.8; b.CurveSize1 = 0.8; b.Segments = 10
		b.Color = ColorSequence.new(rgb(30, 30, 32)); b.LightInfluence = 1
		b.Parent = anchor
		for j, f in { 0.3, 0.7 } do
			local bx = x0 + (k + f) * span
			local sag = 0.6 * 4 * f * (1 - f)
			part(m, "Bulb_" .. (k * 2 + j), CFrame.new(bx, y - sag - 0.15, z), Vector3.new(0.32, 0.32, 0.32), warm, { shape = Enum.PartType.Ball, mat = Enum.Material.Neon, noShadow = true })
		end
	end
	local pl = Instance.new("PointLight"); pl.Color = warm; pl.Range = 14; pl.Brightness = 0.6; pl.Shadows = false; pl.Parent = m.Bulb_4
end

A.Parent = Z
local nParts, nSounds = 0, 0
for _, d in A:GetDescendants() do
	if d:IsA("BasePart") then nParts += 1 elseif d:IsA("Sound") then nSounds += 1 end
end
return string.format("Ambience_Paris : %d pièces, %d sons en boucle, 1 émetteur de fumée", nParts, nSounds)
