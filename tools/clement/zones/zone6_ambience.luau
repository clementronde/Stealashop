--!nocheck
-- Zone 6 — New York : ambiance (retour de Clément du 2026-11-17 : « effets et sons pour chaque ville »).
-- À lancer dans Studio (MCP execute_luau, mode Edit), après zone6_newyork.luau. Relançable : remplace Map/Zone_6/Ambience_NewYork.
-- Objets natifs seulement, aucun script :
--  1) Neige : flocons légers (ParticleEmitter) au-dessus du couloir seulement, jamais au-dessus des magasins
--     (|z| < 58, les façades sont à |z| = 60) ni de l'emprise du coffre de la Fortune Tower (x 843..869, |z| < 20).
--     Les flocons ne traversent donc aucun toit : pas de neige à l'intérieur, sans code.
--  2) Neige posée : bandes de neige au pied des façades sur les trottoirs, et sur le haut des murets.
--  3) Son de ville localisé : circulation de New York (sirènes, klaxons) au milieu du couloir, sirènes lointaines
--     derrière le fond de ville. Sons ProSoundEffects (partenaire de Roblox), en boucle, avec RollOff.
--  La vapeur des bouches d'égout existe déjà (4 bouches et une cheminée, bloc C de zone6_newyork.luau).
local rgb = Color3.fromRGB
local zone = workspace.Map.Zone_6
local street = workspace.Greybox.Corridor.Zone_6.Ground.Street
local X0, X1 = street.Position.X - street.Size.X / 2, street.Position.X + street.Size.X / 2   -- 718..868
local ZF = 60      -- façades et murets à |z| = 60
local old = zone:FindFirstChild("Ambience_NewYork"); if old then old:Destroy() end
local A = Instance.new("Folder"); A.Name = "Ambience_NewYork"

local function part(parent, name, x0, y0, z0, x1, y1, z1, o)
	o = o or {}
	local p = Instance.new("Part"); p.Name = name; p.Anchored = true
	p.Size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
	p.CFrame = CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
	p.CanCollide = false; p.CanTouch = false; p.CanQuery = false; p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	if o.hidden then p.Transparency = 1 end
	p.Material = o.mat or Enum.Material.SmoothPlastic
	p.Color = o.color or rgb(240, 244, 250)
	p.Parent = parent
	return p
end

-- 1) Neige qui tombe : 3 zones d'émission à 55 studs de haut (débit total modéré pour le téléphone, ~45 flocons/s)
local snow = Instance.new("Folder"); snow.Name = "Snowfall"; snow.Parent = A
local function snowEmitter(name, x0, z0, x1, z1)
	local p = part(snow, name, x0, 54.5, z0, x1, 55.5, z1, { hidden = true })
	local area = (x1 - x0) * (z1 - z0)
	local e = Instance.new("ParticleEmitter"); e.Name = "Snow"
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"   -- tache ronde et douce, livrée avec le client
	e.Shape = Enum.ParticleEmitterShape.Box; e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.EmissionDirection = Enum.NormalId.Bottom
	e.Color = ColorSequence.new(rgb(255, 255, 255)); e.LightEmission = 0.25; e.LightInfluence = 0.6
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.32, 0.12), NumberSequenceKeypoint.new(1, 0.32, 0.12) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.08, 0.15), NumberSequenceKeypoint.new(0.9, 0.15), NumberSequenceKeypoint.new(1, 1) })
	e.Speed = NumberRange.new(4, 5.5)
	e.Lifetime = NumberRange.new(11, 13)                  -- 55 studs de chute à ~4,7 studs/s : il touche le sol
	e.Acceleration = Vector3.new(0.35, 0, 0)               -- petit vent le long du couloir, jamais vers les magasins
	e.SpreadAngle = Vector2.new(4, 4)
	e.RotSpeed = NumberRange.new(-40, 40); e.Rotation = NumberRange.new(0, 360)
	e.Rate = math.floor(area * 0.0026 + 0.5)              -- même densité partout
	e.Parent = p
	return e
end
-- Les magasins avancent jusqu'à |z| = 54 (façade) et occupent x 778,4..857,6 depuis leur agrandissement du 2026-11-17 :
-- au-dessus d'eux, la neige s'arrête à |z| = 52. Emprise du coffre de la Fortune Tower (x 845..867, |z| <= 18) exclue.
local SX0, SX1, SZ = 778, 858, 52
local VX0, VZ = 843, 20
snowEmitter("SnowArea_West", X0, -(ZF - 2), SX0, ZF - 2)
snowEmitter("SnowArea_Stores", SX0, -SZ, VX0, SZ)
snowEmitter("SnowArea_StoresEndN", VX0, VZ, SX1, SZ)
snowEmitter("SnowArea_StoresEndS", VX0, -SZ, SX1, -VZ)
snowEmitter("SnowArea_EndN", SX1, VZ, X1, ZF - 2)
snowEmitter("SnowArea_EndS", SX1, -(ZF - 2), X1, -VZ)

-- 2) Neige posée : au pied des façades (trottoirs, z 56..59.8, sur 0,15) et sur le haut des murets
local laid = Instance.new("Folder"); laid.Name = "SnowCover"; laid.Parent = A
local snowMat = { mat = Enum.Material.Snow, color = rgb(236, 241, 248) }
for _, s in { 1, -1 } do
	local t = s > 0 and "N" or "S"
	-- trottoir au pied des immeubles, avant et après les magasins (jamais sous leur façade, qui avance à |z| = 54)
	for k, xr in { { X0 + 1, SX0 }, { SX1, X1 } } do
		part(laid, string.format("Sidewalk_%s%d", t, k), xr[1], 0.4, s * 56.2, xr[2], 0.55, s * 59.8, snowMat)
		part(laid, string.format("SidewalkDrift_%s%d", t, k), xr[1], 0.4, s * 54.6, xr[2], 0.5, s * 56.2, snowMat)
	end
	part(laid, "SidewalkStore_" .. t, SX0, 0.4, s * 50.6, SX1, 0.5, s * 52.2, snowMat)   -- devant les magasins
	part(laid, "WallTop_" .. t .. "1", X0, 18, s * 59.9, SX0, 18.35, s * 61.6, snowMat)
	part(laid, "WallTop_" .. t .. "2", SX1, 18, s * 59.9, X1, 18.35, s * 61.6, snowMat)
end

-- 3) Son de ville localisé (ne déborde pas sur la zone 5, arche à x = X0)
local sounds = Instance.new("Folder"); sounds.Name = "CitySounds"; sounds.Parent = A
local function loop(name, pos, id, volume, minD, maxD)
	local p = part(sounds, name, pos.X - 1, pos.Y - 1, pos.Z - 1, pos.X + 1, pos.Y + 1, pos.Z + 1, { hidden = true })
	local s = Instance.new("Sound"); s.Name = "Loop"
	s.SoundId = "rbxassetid://" .. id; s.Looped = true; s.Playing = true; s.Volume = volume
	s.RollOffMode = Enum.RollOffMode.InverseTapered; s.RollOffMinDistance = minD; s.RollOffMaxDistance = maxD
	s:SetAttribute("PlayAt", "Day")   -- convention commune des zones : livré en lecture de jour, le code l'échange à la nuit
	s.Parent = p
	return s
end
-- « Urban Traffic 2 (SFX) », New York vu d'en haut : circulation, sirène, klaxons (46 s, boucle)
loop("CityTraffic", Vector3.new((X0 + X1) / 2 + 8, 14, 0), 9112891352, 0.4, 35, 82)
-- « Siren Composite 2 (SFX) » : sirènes de police au loin (61 s, boucle), derrière le fond de ville
loop("DistantSirens", Vector3.new(X1 + 30, 50, 0), 9112871933, 0.12, 40, 150)

A.Parent = zone
local rate = 0
for _, d in A:GetDescendants() do if d:IsA("ParticleEmitter") then rate += d.Rate end end
return string.format("Ambience_NewYork : neige %d flocons/s (6 zones), %d bandes de neige posée, 2 sons en boucle", rate, #laid:GetChildren())
