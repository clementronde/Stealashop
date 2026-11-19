--!nocheck
-- Zone 3 — Tokyo : ambiance propre à la ville (retour de Clément du 2026-11-17 : effets et son par ville).
-- À lancer dans Studio (MCP execute_luau, mode Edit), APRÈS la rue (Street_Tokyo) et trees_replace.luau :
-- les pétales se calent sur les feuillages des cerisiers en place. Relançable : Ambience_Tokyo est refait.
-- Tout est natif : ParticleEmitter et Sound, plus un seul FX_NeonFlicker (Script client, visuel seulement)
-- dans l'enseigne KARAOKE de la tour Tower_S5, décor unique (règle FX_ de la liaison 3.3).
-- Budget téléphone : 18 émetteurs, environ 45 particules par seconde dans toute la zone, un seul son.
do
	local rgb = Color3.fromRGB
	local Z = workspace.Map:FindFirstChild("Zone_3")
	assert(Z and Z:FindFirstChild("Street_Tokyo"), "poser d'abord la rue de la zone 3")
	local S = Z.Street_Tokyo
	local street = workspace.Greybox.Corridor.Zone_3.Ground.Street
	local X0, X1 = street.Position.X - street.Size.X / 2, street.Position.X + street.Size.X / 2   -- 230..368
	local ZR = street.Size.Z / 2                                                                     -- chaussée |z| < ZR
	local old = Z:FindFirstChild("Ambience_Tokyo"); if old then old:Destroy() end
	local A = Instance.new("Folder"); A.Name = "Ambience_Tokyo"
	local function holder(name, cf, size)   -- pièce invisible qui porte un effet
		local p = Instance.new("Part"); p.Name = name; p.CFrame = cf; p.Size = size
		p.Anchored = true; p.CanCollide = false; p.CanTouch = false; p.CanQuery = false; p.CastShadow = false
		p.Transparency = 1; p.Parent = A
		return p
	end
	local function seq(t) local k = {}; for _, v in t do table.insert(k, NumberSequenceKeypoint.new(v[1], v[2], v[3] or 0)) end; return NumberSequence.new(k) end

	-- 1) Pétales : chaque cerisier en lâche quelques-uns, et un voile de pétales traverse la rue, poussé par le vent
	local function petals(part, rate, wind, life)
		local e = Instance.new("ParticleEmitter"); e.Name = "Petals"
		e.Texture = "rbxasset://textures/particles/SquareParticle.png"
		e.Color = ColorSequence.new(rgb(255, 200, 222), rgb(246, 150, 192))
		e.LightInfluence = 0.6
		e.Size = seq({ { 0, 0.32, 0.08 }, { 1, 0.24, 0.06 } })
		e.Squash = seq({ { 0, 0 }, { 0.25, 0.7 }, { 0.5, -0.5 }, { 0.75, 0.7 }, { 1, 0 } })
		e.Transparency = seq({ { 0, 1 }, { 0.1, 0 }, { 0.85, 0 }, { 1, 1 } })
		e.Lifetime = life or NumberRange.new(6, 9)
		e.Rate = rate
		e.Speed = NumberRange.new(0.4, 1.2)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Acceleration = wind or Vector3.new(0.5, -1.4, 0.3)
		e.Drag = 0.5
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-140, 140)
		e.Shape = Enum.ParticleEmitterShape.Box
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		e.Parent = part
	end
	local trees = 0
	for _, t in S.Trees:GetChildren() do
		local canopy = t:FindFirstChild("Canopy", true)
		if canopy and canopy:IsA("BasePart") and t.Name:match("^Sakura") then
			trees += 1
			local big = canopy.Size.Magnitude > 15
			petals(holder("PetalsTree_" .. t.Name, canopy.CFrame, canopy.Size * 0.8), big and 2 or 1.5)
		end
	end
	petals(holder("PetalDrift", CFrame.new((X0 + X1) / 2, 26, 0), Vector3.new(X1 - X0 - 4, 4, 2 * ZR - 10)), 5,
		Vector3.new(2.2, -1.1, 0.5), NumberRange.new(9, 12))

	-- 2) Vapeur du stand de ramen (House_N3), sous son auvent : nuage blanc qui monte et s'efface
	local ramen = S.Houses:FindFirstChild("House_N3")
	local noren = ramen and ramen:FindFirstChild("Noren")
	if noren then
		local up = noren.Position + Vector3.new(0, noren.Size.Y / 2 + 1.5, 0) + noren.CFrame.LookVector * 1.2
		local v = holder("RamenSteam", CFrame.new(up), Vector3.new(3, 0.5, 1.5))
		local e = Instance.new("ParticleEmitter"); e.Name = "Steam"
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Color = ColorSequence.new(rgb(255, 255, 255))
		e.LightInfluence = 0.8
		e.Size = seq({ { 0, 1.2, 0.3 }, { 1, 4.5, 0.8 } })
		e.Transparency = seq({ { 0, 1 }, { 0.15, 0.55 }, { 1, 1 } })
		e.Lifetime = NumberRange.new(2.5, 4)
		e.Rate = 4
		e.Speed = NumberRange.new(1.5, 2.5)
		e.SpreadAngle = Vector2.new(15, 15)
		e.EmissionDirection = Enum.NormalId.Top
		e.Acceleration = Vector3.new(0.3, 0.6, 0)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-30, 30)
		e.Shape = Enum.ParticleEmitterShape.Box
		e.Parent = v
	end

	-- 3) Son d'ambiance : rue de Tokyo (circulation lointaine, train qui passe), en boucle au milieu de la zone.
	-- « Japanese Traffic 3 (SFX) », ProSoundEffects (partenaire de Roblox), gratuit. S'éteint au-delà de la zone.
	local spk = holder("AmbienceSpeaker", CFrame.new((X0 + X1) / 2, 10, 0), Vector3.new(1, 1, 1))
	local snd = Instance.new("Sound"); snd.Name = "AMB_TokyoStreet"
	snd.SoundId = "rbxassetid://9112798079"
	snd.Looped = true; snd.Playing = true; snd.Volume = 0.35
	snd:SetAttribute("PlayAt", "Day")   -- convention des zones : son de jour livré en lecture, le code l'arrête la nuit
	snd.RollOffMode = Enum.RollOffMode.InverseTapered
	snd.RollOffMinDistance = 35; snd.RollOffMaxDistance = 85
	snd.Parent = spk

	A.Parent = Z

	-- 4) Néon qui grésille : un seul FX_ client, dans l'enseigne KARAOKE (décor unique), visuel seulement
	local tower = S.City:FindFirstChild("Tower_S5")
	if tower then
		local oldFx = tower:FindFirstChild("FX_NeonFlicker"); if oldFx then oldFx:Destroy() end
		local fx = Instance.new("Script"); fx.Name = "FX_NeonFlicker"; fx.RunContext = Enum.RunContext.Client
		fx.Source = [[
-- FX_NeonFlicker : l'enseigne KARAOKE grésille de temps en temps. Visuel seulement, côté client
-- (aucune valeur de jeu, aucun remote). Posé par tools/clement/zones/zone3_tokyo_ambience.luau.
local sign = script.Parent
local rng = Random.new()
while true do
	task.wait(rng:NextNumber(2.5, 6))
	local tubes = {}
	for _, d in sign:GetDescendants() do
		if d:IsA("BasePart") and d.Name:match("^BladeNeon") then table.insert(tubes, d) end
	end
	for _ = 1, rng:NextInteger(2, 4) do
		for _, p in tubes do p.Transparency = 0.85 end
		task.wait(rng:NextNumber(0.04, 0.12))
		for _, p in tubes do p.Transparency = 0 end
		task.wait(rng:NextNumber(0.05, 0.15))
	end
end
]]
		fx.Parent = tower
	end

	local n = 0
	for _, d in A:GetDescendants() do if d:IsA("ParticleEmitter") then n += 1 end end
	print(string.format("Zone 3 Tokyo : ambiance posée, %d cerisiers, %d émetteurs, son %s, FX_NeonFlicker %s", trees, n, snd.SoundId, tower and "oui" or "non"))
end
