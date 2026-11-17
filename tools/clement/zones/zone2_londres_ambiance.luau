--!nocheck
-- Zone 2 — Londres : ambiance (retour de Clément du 2026-11-17 : « pas de pluie, pas grand-chose »).
-- Pluie légère mais visible, éclaboussures sur les pavés et dans les flaques, ronds dans l'eau, gouttes qui tombent des
-- auvents, brouillard bas, et sons en boucle localisés (pluie, rue, voitures, bus au ralenti au dépôt).
-- Objets natifs seulement (ParticleEmitter, Sound) : aucun script laissé dans la map.
-- À lancer dans Studio (MCP execute_luau, mode Edit) APRÈS zone2_londres.luau et corridor_widen.luau : il lit la
-- géométrie réelle de la zone (chaussée du greybox, façades, flaques, auvents, bus) et remplace Street_Londres/Weather.
-- Relançable. Tout ce qu'il pose porte l'attribut CorridorWiden = 30 : corridor_widen.luau n'y touche plus.
-- Pas de pluie dans les magasins : la pluie tombe sur la chaussée seulement (|z| ≤ bord du trottoir), loin des façades.

local rgb = Color3.fromRGB
local Z = workspace.Map.Zone_2
local S = Z.Street_Londres
local street = workspace.Greybox.Corridor.Zone_2.Ground.Street

local x0 = street.Position.X - street.Size.X / 2 + 2   -- après l'arche
local x1 = street.Position.X + street.Size.X / 2 - 1
local zr = street.Size.Z / 2                             -- demi-largeur de la chaussée (46,5 le 2026-11-17)
local xm = (x0 + x1) / 2

do local old = S:FindFirstChild("Weather"); if old then old:Destroy() end end
do local old = S:FindFirstChild("Sounds"); if old then old:Destroy() end end
local Wx = Instance.new("Model"); Wx.Name = "Weather"
local Sx = Instance.new("Model"); Sx.Name = "Sounds"

-- pièce invisible, sans collision ni requête, qui porte un émetteur ou un son
local function holder(parent, name, cx, cy, cz, sx, sy, sz)
	local p = Instance.new("Part")
	p.Name = name; p.Anchored = true; p.Size = Vector3.new(sx, sy, sz); p.CFrame = CFrame.new(cx, cy, cz)
	p.Transparency = 1; p.CanCollide = false; p.CanTouch = false; p.CanQuery = false; p.CastShadow = false
	p.Parent = parent
	return p
end
local TEX = {
	smoke = "rbxasset://textures/particles/smoke_main.dds",
	ring = "rbxasset://textures/particles/explosion01_shockwave_main.dds",
}
local function seq(...) local t = {}; local a = { ... }; for i = 1, #a, 2 do table.insert(t, NumberSequenceKeypoint.new(a[i], a[i + 1])) end; return NumberSequence.new(t) end

-- 1) Pluie : rideau au-dessus de la chaussée, gouttes étirées dans le sens de la chute
do
	local h = holder(Wx, "RainCloud", xm, 42, 0, x1 - x0, 1, 2 * zr)
	local e = Instance.new("ParticleEmitter"); e.Name = "Rain"
	e.Texture = TEX.smoke
	e.EmissionDirection = Enum.NormalId.Bottom
	e.Rate = 300
	e.Lifetime = NumberRange.new(0.82, 0.86)
	e.Speed = NumberRange.new(48, 52)
	e.SpreadAngle = Vector2.new(2, 2)
	e.Acceleration = Vector3.new(1.2, 0, 0)
	e.Size = NumberSequence.new(0.45)
	e.Squash = NumberSequence.new(3)
	e.Orientation = Enum.ParticleOrientation.VelocityParallel
	e.Transparency = seq(0, 1, 0.1, 0.3, 1, 0.4)
	e.Color = ColorSequence.new(rgb(222, 230, 242))
	e.LightEmission = 0.35
	e.LightInfluence = 0.6
	e.Parent = h
end

-- 2) Éclaboussures sur les pavés (émetteur enfoui juste sous la chaussée : rien ne dépasse du sol)
local function splash(parent, rate, size)
	local e = Instance.new("ParticleEmitter"); e.Name = "Splash"
	e.Texture = TEX.smoke
	e.EmissionDirection = Enum.NormalId.Top
	e.Rate = rate
	e.Lifetime = NumberRange.new(0.18, 0.3)
	e.Speed = NumberRange.new(2.5, 4.5)
	e.SpreadAngle = Vector2.new(35, 35)
	e.Acceleration = Vector3.new(0, -28, 0)
	e.Size = seq(0, size, 1, 0)
	e.Transparency = seq(0, 0.3, 1, 0.8)
	e.Color = ColorSequence.new(rgb(225, 232, 244))
	e.LightEmission = 0.3
	e.Parent = parent
	return e
end
splash(holder(Wx, "StreetSplashes", xm, -0.07, 0, x1 - x0, 0.1, 2 * zr - 2), 90, 0.22)

-- 3) Flaques : éclaboussures plus fortes et ronds dans l'eau, couchés à plat
local nPuddles = 0
for _, p in S.Ground:GetChildren() do
	if p:IsA("BasePart") and p.Name:match("^Puddle_%d+_A$") then
		nPuddles += 1
		local d = math.max(p.Size.Y, p.Size.Z) * 0.8
		local h = holder(Wx, "PuddleFX_" .. nPuddles, p.Position.X, p.Position.Y - 0.05, p.Position.Z, d, 0.1, d)
		splash(h, 10, 0.28)
		local r = Instance.new("ParticleEmitter"); r.Name = "Ripples"
		r.Texture = TEX.ring
		r.EmissionDirection = Enum.NormalId.Top
		r.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		r.Rate = 3
		r.Lifetime = NumberRange.new(0.5, 0.7)
		r.Speed = NumberRange.new(0.05, 0.05)
		r.Size = seq(0, 0.1, 1, 1.3)
		r.Transparency = seq(0, 0.45, 1, 1)
		r.Color = ColorSequence.new(rgb(215, 225, 240))
		r.LightEmission = 0.25
		r.Parent = h
	end
end

-- 4) Gouttes qui tombent du bord des auvents des deux magasins
local nDrips = 0
for _, store in { Z:FindFirstChild("STORE_Z2_MagasinDeJouets"), Z:FindFirstChild("STORE_Z2_Confiserie") } do
	if store then
		for _, pre in { "WinValance", "DoorValance" } do
			local mn, mx = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
			for _, v in store:GetDescendants() do
				if v:IsA("BasePart") and v.Name:match("^" .. pre) then mn = mn:Min(v.Position - v.Size / 2); mx = mx:Max(v.Position + v.Size / 2) end
			end
			if mn.X < 1e8 then
				nDrips += 1
				local h = holder(Wx, "AwningDrips_" .. nDrips, (mn.X + mx.X) / 2, mn.Y - 0.1, (mn.Z + mx.Z) / 2, mx.X - mn.X - 0.4, 0.1, 0.2)
				local e = Instance.new("ParticleEmitter"); e.Name = "Drips"
				e.Texture = TEX.smoke
				e.EmissionDirection = Enum.NormalId.Bottom
				e.Rate = 5
				e.Lifetime = NumberRange.new(0.55, 0.65)
				e.Speed = NumberRange.new(1, 2)
				e.Acceleration = Vector3.new(0, -40, 0)
				e.Size = NumberSequence.new(0.14)
				e.Squash = NumberSequence.new(1.5)
				e.Orientation = Enum.ParticleOrientation.VelocityParallel
				e.Transparency = NumberSequence.new(0.35)
				e.Color = ColorSequence.new(rgb(215, 225, 240))
				e.LightEmission = 0.3
				e.Parent = h
			end
		end
	end
end

-- 5) Brouillard bas au ras des pavés, plus épais sous l'arche (émetteurs enfouis sous la chaussée)
local function mist(parent, rate)
	local e = Instance.new("ParticleEmitter"); e.Name = "Mist"
	e.Texture = TEX.smoke
	e.EmissionDirection = Enum.NormalId.Top
	e.Rate = rate
	e.Lifetime = NumberRange.new(10, 14)
	e.Speed = NumberRange.new(0.3, 0.8)
	e.SpreadAngle = Vector2.new(60, 60)
	e.Acceleration = Vector3.new(0.12, -0.03, 0)
	e.Drag = 0.4
	e.Size = seq(0, 16, 1, 26)
	e.Transparency = seq(0, 1, 0.25, 0.82, 0.75, 0.84, 1, 1)
	e.Color = ColorSequence.new(rgb(214, 220, 230))
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-6, 6)
	e.LightInfluence = 1
	e.Parent = parent
end
mist(holder(Wx, "MistBank", xm, -0.7, 0, x1 - x0, 1, 2 * zr - 4), 5)
mist(holder(Wx, "GateMistBank", x0 + 5, -0.7, 0, 12, 1, 2 * zr - 4), 2)

-- 6) Sons en boucle, localisés (RollOff inverse adouci) : la pluie couvre la rue, la ville en fond, le bus au dépôt.
--    Convention commune des zones (2026-11-17) : attribut PlayAt = "Day" ou "Night" ; ceux de jour sont livrés en
--    lecture, ceux de nuit arrêtés, et le code d'Ironix les échange à la nuit et à l'aube. La nuit, il ne reste que la pluie.
local SOUNDS = {
	-- nom, id (vérifiés par PreloadAsync le 2026-11-17), volume, RollOff min, max, position, PlayAt
	{ "Rain_West", 6657181480, 0.45, 35, 85, Vector3.new(x0 + (x1 - x0) * 0.25, 8, 0), "Day" },   -- « Rain loop », 9,6 s
	{ "Rain_East", 6657181480, 0.45, 35, 85, Vector3.new(x0 + (x1 - x0) * 0.75, 8, 0), "Day" },
	{ "CityHum", 131711504982362, 0.22, 30, 90, Vector3.new(xm, 12, 0), "Day" },                    -- « Morning City ambience », 6,5 s
	{ "DistantTraffic", 9120239350, 0.12, 30, 90, Vector3.new(xm, 4, 0), "Day" },                   -- Pro Sound Effects, 9,3 s
	{ "RainNight_West", 6657181480, 0.5, 35, 85, Vector3.new(x0 + (x1 - x0) * 0.25, 8, 0), "Night" },
	{ "RainNight_East", 6657181480, 0.5, 35, 85, Vector3.new(x0 + (x1 - x0) * 0.75, 8, 0), "Night" },
}
local bus = S:FindFirstChild("DoubleDecker")
if bus then
	local cf = bus:GetBoundingBox()
	table.insert(SOUNDS, { "BusIdle", 93894279029996, 0.3, 8, 45, cf.Position - Vector3.new(0, 7, 0), "Day" })   -- « Bus engine idle », 5,1 s
end
for i, s in SOUNDS do
	local h = holder(Sx, "Speaker_" .. s[1], s[6].X, s[6].Y, s[6].Z, 1, 1, 1)
	local snd = Instance.new("Sound"); snd.Name = s[1]
	snd.SoundId = "rbxassetid://" .. s[2]
	snd.Volume = s[3]
	snd.Looped = true
	snd.Playing = (s[7] == "Day")
	snd:SetAttribute("PlayAt", s[7])
	snd.RollOffMode = Enum.RollOffMode.InverseTapered
	snd.RollOffMinDistance = s[4]
	snd.RollOffMaxDistance = s[5]
	snd.TimePosition = (i * 1.7) % 4   -- départs décalés : les boucles identiques ne tombent pas ensemble
	snd.Parent = h
end

-- marque « déjà élargi » pour corridor_widen.luau, puis rangement
for _, m in { Wx, Sx } do
	m:SetAttribute("CorridorWiden", 30)
	for _, d in m:GetDescendants() do if d:IsA("BasePart") then d:SetAttribute("CorridorWiden", 30) end end
	m.Parent = S
end

-- vérification
local nEmit, nSnd, alive = 0, 0, 0
for _, d in Wx:GetDescendants() do if d:IsA("ParticleEmitter") then nEmit += 1; alive += d.Rate * d.Lifetime.Max end end
for _, d in Sx:GetDescendants() do if d:IsA("Sound") then nSnd += 1 end end
local scripts = 0
for _, d in Z:GetDescendants() do if d:IsA("LuaSourceContainer") then scripts += 1 end end
local inside = 0   -- pluie au-dessus d'un magasin ?
local cloud = Wx.RainCloud
for _, nm in { "STORE_Z2_MagasinDeJouets", "STORE_Z2_Confiserie" } do
	local b = Z[nm]:FindFirstChild("Bounds")
	if b then
		local bz0, bz1 = b.Position.Z - b.Size.Z / 2, b.Position.Z + b.Size.Z / 2
		if bz1 > -zr - 2 and bz0 < zr + 2 then inside += 1 end
	end
end
return string.format("Londres, ambiance : chaussée x %.0f..%.0f z ±%.1f ; %d émetteurs (%d flaques, %d auvents), ~%d particules en vol ; %d sons ; magasins sous la pluie %d ; scripts %d",
	x0, x1, zr, nEmit, nPuddles, nDrips, alive, nSnd, inside, scripts)
