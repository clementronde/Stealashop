-- Éclats du compteur « ×N LUCK » au-dessus du colis qu'on ouvre (chef VFX et son, 27/11 ; demande de Clément relayée par
-- le Chef de projet et le chef UI). À coller dans la barre de commande de Studio, en Edit. Relançable : remplace les 6.
-- ReplicatedStorage/Assets/FX/FX_LuckTier_1 à FX_LuckTier_6 : FX_LuckTier_N se joue quand le compteur passe un palier dont
-- BurstLevel = N (Assets/UI/LuckTiers, chef UI). Même forme que FX_Unbox_Reveal : pièce Root invisible, Attachment Center,
-- émetteurs à Rate 0 avec EmitCount, PointLight Flash avec FadeTime, Duration sur le modèle (lus par VfxController.burst).
-- Aucun script. Chaque niveau monte d'un cran : plus de particules, plus grand, plus lumineux ; au niveau 6 (Secret, arc-en-ciel) le sommet.
--   1 Rare bleu : étoile, anneau, étincelles
--   2 Épique violet : + éclats qui retombent
--   3 Légendaire or : + second anneau
--   4 Mythique rouge : + rayons qui tournent derrière
--   5 Divin or pâle : rayons plus grands, plus d'étincelles
--   6 Secret arc-en-ciel : le sommet (Clément, 27/11 : l'arc-en-ciel est plus rare que l'or) ; tout aux couleurs de
--     l'arc-en-ciel, + colonne de paillettes qui monte
-- Paliers v2 du chef UI (13 paliers, un par ordre de grandeur) : 1 = ×10 et ×100, 2 = ×1K et ×10K, 3 = ×100K et ×1M,
-- 4 = ×10M et ×100M, 5 = ×1B et ×10B, 6 = ×100B et ×1T.
-- Court : tout est fini en 1,1 s, deux paliers peuvent se suivre dans la même ouverture.

local FX = game.ReplicatedStorage.Assets.FX

local TEX = {
	Star = "rbxassetid://138001567239074", -- FX_Treadmill_Gold_Sparkle (étincelle à 4 branches, groupe)
	Ring = "rbxasset://textures/particles/explosion01_shockwave_main.dds", -- intégrée au client (comme FX_Unbox_Reveal)
	Shard = "rbxassetid://116795364510621", -- FX_Unbox_Shard (planche 2 × 2, groupe)
	Rays = "rbxassetid://96610322911997", -- rayons du trèfle de BB_ShelfOpen (chef UI)
}

local function hex(h: string): Color3 return Color3.fromHex(h) end
local RAINBOW = { hex("#FF3B3B"), hex("#FFC21A"), hex("#3BE15A"), hex("#2F9BFF"), hex("#A855F7") } -- Config/Rarities, Secret
local LEVELS = {
	{ color = hex("#2F9BFF") }, -- Rare
	{ color = hex("#A855F7") }, -- Épique
	{ color = hex("#FFC21A") }, -- Légendaire
	{ color = hex("#FF3B5C") }, -- Mythique
	{ color = hex("#FFE9A8") }, -- Divin
	{ rainbow = true, color = hex("#FF3B3B") }, -- Secret, le sommet
}

local function seq(points: { { number } }): NumberSequence
	local kps = {}
	for _, p in points do table.insert(kps, NumberSequenceKeypoint.new(p[1], p[2])) end
	return NumberSequence.new(kps)
end
local function colorOf(level: any, whiten: number?): ColorSequence
	if level.rainbow then
		local kps = {}
		for i, c in RAINBOW do table.insert(kps, ColorSequenceKeypoint.new((i - 1) / (#RAINBOW - 1), c)) end
		return ColorSequence.new(kps)
	end
	local c = level.color
	if whiten then c = c:Lerp(Color3.new(1, 1, 1), whiten) end
	return ColorSequence.new(c)
end

local function emitter(parent: Instance, name: string, tex: string, count: number, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Texture = tex
	e.Rate = 0
	e.Enabled = false
	e.LightInfluence = 0
	for k, v in props do (e :: any)[k] = v end
	e:SetAttribute("EmitCount", count)
	e.Parent = parent
	return e
end

local function build(n: number): Model
	local level = LEVELS[n]
	local s = 1 + 0.18 * (n - 1) -- taille : ×1 au niveau 1, ×1,9 au niveau 6
	local m = Instance.new("Model")
	m.Name = "FX_LuckTier_" .. n
	m:SetAttribute("Duration", 1.2)
	m:SetAttribute("BurstLevel", n)
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 1, 1)
	root.Transparency = 1
	root.Anchored, root.CanCollide, root.CanTouch, root.CanQuery, root.CastShadow = true, false, false, false, false
	root.Parent = m
	m.PrimaryPart = root
	local center = Instance.new("Attachment")
	center.Name = "Center"
	center.Parent = root

	-- l'étoile du cœur : un éclat net qui s'ouvre et se referme
	emitter(center, "Star", TEX.Star, 1, {
		Lifetime = NumberRange.new(0.3), Speed = NumberRange.new(0), Rotation = NumberRange.new(0, 45), RotSpeed = NumberRange.new(90),
		Size = seq({ { 0, 0 }, { 0.25, 2.6 * s }, { 1, 0 } }), Color = colorOf(level, 0.45),
		LightEmission = 1, Brightness = 2 + 0.3 * n, ZOffset = 0.6 })
	-- l'anneau qui s'ouvre autour du colis, face à la caméra
	emitter(center, "Ring", TEX.Ring, 1, {
		Lifetime = NumberRange.new(0.35), Speed = NumberRange.new(0),
		Size = seq({ { 0, 0.6 }, { 1, 3.2 * s } }), Transparency = seq({ { 0, 0.05 }, { 0.6, 0.35 }, { 1, 1 } }),
		Color = colorOf(level), LightEmission = 1, Brightness = 1.5 + 0.2 * n, ZOffset = 0.3 })
	-- les étincelles qui jaillissent dans tous les sens, freinées
	emitter(center, "Sparks", TEX.Star, 6 + 3 * n, {
		Lifetime = NumberRange.new(0.45, 0.7), Speed = NumberRange.new(8 * s, 14 * s), SpreadAngle = Vector2.new(180, 180),
		Drag = 5, Rotation = NumberRange.new(0, 45), RotSpeed = NumberRange.new(-120, 120),
		Size = seq({ { 0, 0.55 * s }, { 0.6, 0.4 * s }, { 1, 0 } }), Color = colorOf(level, 0.2),
		LightEmission = 0.8, Brightness = 1.8 + 0.2 * n, ZOffset = 0.4 })
	if n >= 2 then -- éclats qui sautent et retombent en tournoyant
		emitter(center, "Shards", TEX.Shard, 2 * n, {
			Lifetime = NumberRange.new(0.7, 1), Speed = NumberRange.new(7, 11), SpreadAngle = Vector2.new(70, 70),
			EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, -26, 0), Drag = 1,
			Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-260, 260),
			Squash = seq({ { 0, 0 }, { 0.2, 1 }, { 0.4, -0.8 }, { 0.6, 1 }, { 0.8, -0.8 }, { 1, 0 } }),
			Size = seq({ { 0, 0.3 }, { 0.1, 0.45 * s }, { 0.85, 0.4 * s }, { 1, 0 } }), Color = colorOf(level, 0.1),
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2, FlipbookMode = Enum.ParticleFlipbookMode.Loop,
			FlipbookFramerate = NumberRange.new(0.5), FlipbookStartRandom = true,
			LightEmission = 0.3, Brightness = 1.4, LightInfluence = 0.3 })
	end
	if n >= 3 then -- second anneau, plus large et un peu plus tard (il naît petit et rattrape le premier)
		emitter(center, "Ring2", TEX.Ring, 1, {
			Lifetime = NumberRange.new(0.55), Speed = NumberRange.new(0),
			Size = seq({ { 0, 0 }, { 0.3, 0.4 }, { 1, 4.4 * s } }), Transparency = seq({ { 0, 1 }, { 0.3, 0.2 }, { 1, 1 } }),
			Color = colorOf(level, 0.3), LightEmission = 1, Brightness = 1.4, ZOffset = 0.2 })
	end
	if n >= 4 then -- rayons qui tournent derrière le colis
		emitter(center, "Rays", TEX.Rays, 1, {
			Lifetime = NumberRange.new(0.8), Speed = NumberRange.new(0), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(60),
			Size = seq({ { 0, 0 }, { 0.2, 4.2 * s }, { 1, 5 * s } }), Transparency = seq({ { 0, 1 }, { 0.15, 0.35 }, { 0.6, 0.5 }, { 1, 1 } }),
			Color = colorOf(level, 0.25), LightEmission = 1, Brightness = 1.2, ZOffset = -1 })
	end
	if n >= 6 then -- Secret, le sommet : une colonne de paillettes arc-en-ciel qui monte
		emitter(center, "Rise", TEX.Star, 14, {
			Lifetime = NumberRange.new(0.8, 1.1), Speed = NumberRange.new(6, 11), SpreadAngle = Vector2.new(18, 18),
			EmissionDirection = Enum.NormalId.Top, Drag = 2, Rotation = NumberRange.new(0, 45), RotSpeed = NumberRange.new(-90, 90),
			Size = seq({ { 0, 0.5 }, { 0.5, 0.4 }, { 1, 0 } }), Color = colorOf(level),
			LightEmission = 1, Brightness = 2.4, ZOffset = 0.5 })
	end
	local light = Instance.new("PointLight")
	light.Name = "Flash"
	light.Color = level.color
	light.Range = 6 + 2 * n
	light.Brightness = 1 + 0.6 * n
	light.Shadows = false
	light.Enabled = false
	light:SetAttribute("FadeTime", 0.35)
	light.Parent = root
	return m
end

local out = {}
for n = 1, 6 do
	local old = FX:FindFirstChild("FX_LuckTier_" .. n)
	if old then old:Destroy() end
	local m = build(n)
	m.Parent = FX
	local count, emitters = 0, 0
	for _, d in m:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			emitters += 1
			count += d:GetAttribute("EmitCount")
		end
	end
	table.insert(out, string.format("%s : %d émetteurs, %d particules", m.Name, emitters, count))
end
return table.concat(out, "\n")
