-- Prototypes du chef VFX et son (27/11), à coller en Edit. Rien n'est posé dans Assets : tout va dans
-- ServerStorage/_PROTO_VFX_2026-11-27 (dossier de travail, jamais lu par le jeu). Relançable.
--   FX_AfkZzz : les « Z » du joueur AFK qui somnole (demande de Clément : « pour que les gens voient qu'ils peuvent le
--     braquer »). Le code pose le modèle sur la tête et fait Emit(EmitCount) de chaque émetteur au marqueur Snore de
--     l'animation Sleep (chef animation) : à chaque ronflement, un grand Z et un petit Z montent en grossissant, se
--     décalent un peu et s'effacent. Lisible de loin : jusqu'à 2 studs, contour bleu nuit, LightInfluence 0 (se lit la nuit).
--     Texture : StealAShop-Art/FX/AfkZzz/FX_AfkZzz.png, en aperçu local (dossier content de Studio) tant qu'elle n'est
--     pas publiée ; remplacer ZTEX par l'ID d'image du groupe ensuite.
--   FX_Escape_v3 : l'arrivée en zone safe avec l'objet volé, plus festive (Clément, vidéo B : « plus sympa »). Base :
--     FX_Escape (v2 validé) ; en plus, deux canons à confettis de part et d'autre du héros qui tirent vers le haut et
--     un peu vers l'intérieur, des confettis qui retombent en papillonnant autour de lui (jamais devant sa tête au
--     départ), et la gerbe d'étoiles et les rayons aux couleurs de la rareté de l'objet (attribut RarityColor, comme
--     FX_ShelfReveal : le code teinte les émetteurs qui le portent).

local ZTEX = "rbxasset://textures/StealAShopFX/FX_AfkZzz.png" -- aperçu local ; ID du groupe après publication
local SHARD = "rbxassetid://116795364510621" -- FX_Unbox_Shard (planche 2 × 2, groupe)
local SQUARE = "rbxasset://textures/particles/SquareParticle.png"

local SS = game:GetService("ServerStorage")
local folder = SS:FindFirstChild("_PROTO_VFX_2026-11-27") or Instance.new("Folder")
folder.Name = "_PROTO_VFX_2026-11-27"
folder.Parent = SS

local function seq(points: { { number } }): NumberSequence
	local kps = {}
	for _, p in points do table.insert(kps, NumberSequenceKeypoint.new(p[1], p[2])) end
	return NumberSequence.new(kps)
end
local function emitter(parent: Instance, name: string, tex: string, count: number, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Texture = tex
	e.Rate = 0
	e.Enabled = false
	for k, v in props do (e :: any)[k] = v end
	e:SetAttribute("EmitCount", count)
	e.Parent = parent
	return e
end
local function rootModel(name: string): (Model, Part)
	local old = folder:FindFirstChild(name)
	if old then old:Destroy() end
	local m = Instance.new("Model")
	m.Name = name
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 1, 1)
	root.Transparency = 1
	root.Anchored, root.CanCollide, root.CanTouch, root.CanQuery, root.CastShadow = true, false, false, false, false
	root.Parent = m
	m.PrimaryPart = root
	return m, root
end

-- FX_AfkZzz -----------------------------------------------------------------------------------------------------
do
	local m, root = rootModel("FX_AfkZzz")
	m:SetAttribute("EmitOn", "Snore") -- pour mémoire : émis au marqueur Snore de l'animation Sleep
	local at = Instance.new("Attachment")
	at.Name = "Zzz"
	at.Position = Vector3.new(0.6, 1.1, 0) -- au-dessus de la tête, un peu sur le côté (le pivot est le haut de la tête)
	at.Parent = root
	local Z = { FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2, FlipbookMode = Enum.ParticleFlipbookMode.Loop,
		FlipbookFramerate = NumberRange.new(0), FlipbookStartRandom = true, LightEmission = 0, LightInfluence = 0,
		EmissionDirection = Enum.NormalId.Top, Orientation = Enum.ParticleOrientation.FacingCameraWorldUp }
	local big = emitter(at, "Z", ZTEX, 1, Z)
	big.Lifetime = NumberRange.new(2.2, 2.4)
	big.Speed = NumberRange.new(1.7, 2)
	big.SpreadAngle = Vector2.new(10, 10)
	big.Acceleration = Vector3.new(0.35, 0.2, 0)
	big.Drag = 0.25
	big.Rotation = NumberRange.new(-14, 14)
	big.RotSpeed = NumberRange.new(-12, 12)
	big.Size = seq({ { 0, 0 }, { 0.12, 0.9 }, { 0.7, 1.8 }, { 1, 2 } })
	big.Transparency = seq({ { 0, 0 }, { 0.65, 0 }, { 1, 1 } })
	local small = emitter(at, "ZSmall", ZTEX, 1, Z) -- le petit z qui suit, plus lent : la file « zZ » se forme seule
	small.Lifetime = NumberRange.new(2, 2.2)
	small.Speed = NumberRange.new(0.9, 1.1)
	small.SpreadAngle = Vector2.new(12, 12)
	small.Acceleration = Vector3.new(0.25, 0.15, 0)
	small.Drag = 0.25
	small.Rotation = NumberRange.new(-18, 18)
	small.RotSpeed = NumberRange.new(-15, 15)
	small.Size = seq({ { 0, 0 }, { 0.15, 0.55 }, { 0.7, 1 }, { 1, 1.1 } })
	small.Transparency = seq({ { 0, 0 }, { 0.6, 0 }, { 1, 1 } })
	m.Parent = folder
end

-- FX_Escape_v3 --------------------------------------------------------------------------------------------------
do
	local old = folder:FindFirstChild("FX_Escape_v3")
	if old then old:Destroy() end
	local source = game.ReplicatedStorage.Assets.FX:FindFirstChild("FX_Escape")
	assert(source, "Assets/FX/FX_Escape absent")
	local m = source:Clone()
	m.Name = "FX_Escape_v3"
	m:SetAttribute("Duration", 2.6)
	local root = m:FindFirstChild("Root") :: BasePart
	local burst = root:FindFirstChild("Burst")
	-- la gerbe et les rayons prennent la couleur de la rareté (le code teinte les émetteurs marqués RarityColor)
	for _, n in { "Stars", "Rays" } do
		local e = burst and burst:FindFirstChild(n)
		if e then e:SetAttribute("RarityColor", true) end
	end
	-- deux canons à confettis aux pieds, à 2,6 studs de chaque côté, penchés de 22° vers le héros
	local FLUTTER = seq({ { 0, 0 }, { 0.15, 0.8 }, { 0.3, -0.6 }, { 0.45, 0.8 }, { 0.6, -0.6 }, { 0.75, 0.8 }, { 0.9, -0.6 }, { 1, 0 } })
	for _, side in { -1, 1 } do
		local at = Instance.new("Attachment")
		at.Name = if side < 0 then "CannonL" else "CannonR"
		at.CFrame = CFrame.new(2.6 * side, 0.3, 0) * CFrame.Angles(0, 0, math.rad(22) * side)
		at.Parent = root
		local common = {
			Lifetime = NumberRange.new(1.8, 2.4), Speed = NumberRange.new(24, 32), SpreadAngle = Vector2.new(14, 14),
			EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, -20, 0), Drag = 1.8,
			Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-240, 240), Squash = FLUTTER,
			Transparency = seq({ { 0, 0 }, { 0.85, 0 }, { 1, 1 } }), LightEmission = 0.1, LightInfluence = 0.6 }
		-- confettis à la couleur de la rareté (l'éclat du colis, en planche)
		local c1 = emitter(at, "ConfettiRarity", SHARD, 16, common)
		c1.Size = seq({ { 0, 0.3 }, { 0.1, 0.5 }, { 1, 0.45 } })
		c1.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
		c1.FlipbookFramerate = NumberRange.new(0.5)
		c1.FlipbookStartRandom = true
		c1.Color = ColorSequence.new(Color3.fromHex("#FFC21A"))
		c1:SetAttribute("RarityColor", true)
		-- confettis de fête, de toutes les couleurs (la couleur change en vol : chaque confetti passe par la palette)
		local c2 = emitter(at, "ConfettiParty", SQUARE, 14, common)
		c2.Size = seq({ { 0, 0.22 }, { 0.1, 0.36 }, { 1, 0.32 } })
		c2.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHex("#FF3B5C")), ColorSequenceKeypoint.new(0.25, Color3.fromHex("#FFC21A")),
			ColorSequenceKeypoint.new(0.5, Color3.fromHex("#2FE08F")), ColorSequenceKeypoint.new(0.75, Color3.fromHex("#2F9BFF")),
			ColorSequenceKeypoint.new(1, Color3.fromHex("#A855F7")) })
		-- la bouffée du canon
		local puff = emitter(at, "CannonPuff", "rbxasset://textures/particles/smoke_main.dds", 3, {
			Lifetime = NumberRange.new(0.4, 0.6), Speed = NumberRange.new(6, 9), SpreadAngle = Vector2.new(18, 18),
			EmissionDirection = Enum.NormalId.Top, Drag = 6, Size = seq({ { 0, 0.6 }, { 1, 2 } }),
			Transparency = seq({ { 0, 0.3 }, { 1, 1 } }), Color = ColorSequence.new(Color3.fromRGB(255, 250, 235)),
			LightEmission = 0.2, LightInfluence = 0.5 })
		puff.Name = "CannonPuff"
	end
	m.Parent = folder
end

-- compte
local out = {}
for _, m in folder:GetChildren() do
	local n, e = 0, 0
	for _, d in m:GetDescendants() do
		if d:IsA("ParticleEmitter") then e += 1; n += d:GetAttribute("EmitCount") or 0 end
		assert(not d:IsA("LuaSourceContainer"), "script trouvé")
	end
	table.insert(out, string.format("%s : %d émetteurs, %d particules par coup", m.Name, e, n))
end
return table.concat(out, "\n")
