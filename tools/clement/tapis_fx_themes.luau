-- Effets des 25 tapis, thème par thème (chef VFX et son, 26/11 ; méthode du Gold v3 validé par Clément le 26/11).
-- À coller dans la barre de commande de Studio, en Edit. Aucun script n'est laissé dans les modèles : on pose des
-- ParticleEmitter natifs sur les points d'accroche du chef 3D, avec les attributs que lira le code de Cantin
-- (RunOnly, RunRate, StepEmit). Plan et budgets : side-session-notes/tapis-25-effets-plan.md.
--   _G.TFX.apply(model, "Cardboard")  pose les effets du thème sur ce modèle (une copie, ou le modèle livré par le chef 3D)
--   _G.TFX.cost(model)                 particules vivantes au repos et en course (6 gains par seconde)
-- Points d'accroche : Belt/RunBurstPoint (toujours), Frame/PostTop_L et _R, Frame/ArchTop, Frame/FloorCenter (étages 2+).
-- Règles : un signe propre à chaque thème, plus fort à chaque palier sans jamais couvrir le coureur ; textures du groupe
-- ou intégrées au client (rbxasset), jamais un PNG plat ; budget en course 8 / 20 / 35 / 50 / 70 selon l'étage.

local TFX = {}
_G.TFX = TFX

local GAINS = 6
-- Textures du groupe RoundStone Studio (ID d'image) ; à compléter quand Clément publie celles d'un lot.
local TEX = {
	Sparkle = "rbxassetid://138001567239074", -- FX_Treadmill_Gold_Sparkle (étincelle à 4 branches)
	RunBurst = "rbxassetid://131021212965898", -- FX_Treadmill_Gold_RunBurst (éclat à plat)
	Smoke = "rbxasset://textures/particles/smoke_main.dds", -- intégrée au client
	Tape = "rbxassetid://79385881195043", -- FX_Treadmill_Tape (Decal 119123100321910) : 4 morceaux de scotch brun
	PriceTag = "rbxassetid://111084901059855", -- FX_Treadmill_PriceTag (Decal 93203592230897) : 4 étiquettes de prix jaunes
	-- Lot 1 refait (tableau des 25 validé le 26/11) : StealAShop-Art/FX/Treadmill_Lot1b, à publier par Clément.
	-- Publiées le 27/11 (fx_ids.csv) ; ID d image lus par LoadAsset et chargés (PreloadAsync : Success).
	CardboardChip = "rbxassetid://97075049319662", -- Decal 103892364900170 : FX_Treadmill_CardboardChip : 4 copeaux de carton ondulé
	MedalConfetti = "rbxassetid://71720738624202", -- Decal 74057603463902 : FX_Treadmill_MedalConfetti : 4 rondelles de bronze bombées, dont une frappée d'une étoile
	SilverStar = "rbxassetid://94567734679728", -- Decal 94242272418215 : FX_Treadmill_SilverStar : étoile d'argent à 5 branches, 4 états de scintillement
	ScanLaser = "rbxassetid://94219368277841", -- Decal 105966249396287 : FX_Treadmill_ScanLaser : trait rouge du scanner (64 × 512)
}
TFX.TEX = TEX

local function seq(points: { { number } }): NumberSequence
	local kps = {}
	for _, p in points do table.insert(kps, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0)) end
	return NumberSequence.new(kps)
end
local function col(r: number, g: number, b: number): ColorSequence return ColorSequence.new(Color3.fromRGB(r, g, b)) end
local SHEET = { FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2, FlipbookMode = Enum.ParticleFlipbookMode.Loop,
	FlipbookFramerate = NumberRange.new(0.5), FlipbookStartRandom = true }
local TOSS = { Lifetime = NumberRange.new(0.7, 0.9), Speed = NumberRange.new(8, 11), SpreadAngle = Vector2.new(40, 30),
	EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, -30, 0), Drag = 0.5,
	Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-180, 180) }

-- Un thème = une liste d'effets :
--   { at = point d'accroche (ou liste : le premier trouvé sert), name, tex = clé de TEX, props = réglages,
--     sheet = planche 2 × 2, toss = gerbe qui saute, beam = { down = studs } pour un trait fixe (Beam) sous le point }
-- Les points Fx_<Élément> sont les Attachments que le chef 3D pose sur l'élément qui bouge ; les anciens points
-- (CardboardBits, MedalCenter, StarCenter, ScannerLight) servent de repli tant que le lot refait n'est pas livré.
-- Flottement en feuille morte : une particule plate qui se retourne (Squash qui va et vient) et tourne lentement.
local FLUTTER = seq({ { 0, 0 }, { 0.12, 0.7 }, { 0.25, -0.5 }, { 0.38, 0.7 }, { 0.5, -0.5 }, { 0.62, 0.7 }, { 0.75, -0.5 },
	{ 0.88, 0.7 }, { 1, 0 } })
local FLIP = seq({ { 0, 0 }, { 0.15, 1.2 }, { 0.3, -1 }, { 0.45, 1.2 }, { 0.6, -1 }, { 0.75, 1.2 }, { 0.9, -1 }, { 1, 0 } })
local THEMES = {
	-- RunBurstPoint est tourné d'un demi-tour : son « Front » pointe vers l'arrière du tapis (+Z du modèle), là où
	-- part la bande ; la poussière part donc en Front. Mesuré sur les v4 le 27/11.
	-- Étage 1 (niveaux 1 à 5) : un signe par thème, qui sort de l'élément qui bouge ; au plus 8 particules en course
	Base = { -- petites bouffées de poussière grise au ras de la bande, poussées vers l'arrière par les pas
		{ at = "Belt/RunBurstPoint", name = "RunStep", tex = "Smoke", props = {
			["@StepEmit"] = 1, Lifetime = NumberRange.new(0.45, 0.55), Speed = NumberRange.new(2.5, 3.5),
			SpreadAngle = Vector2.new(35, 8), EmissionDirection = Enum.NormalId.Front, Acceleration = Vector3.new(0, 0.6, 0),
			Drag = 3.5, Size = seq({ { 0, 0.5 }, { 1, 1.5 } }), Transparency = seq({ { 0, 0.4 }, { 0.5, 0.6 }, { 1, 1 } }),
			Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-40, 40),
			Color = col(170, 165, 155), LightEmission = 0, LightInfluence = 1 } },
	},
	Cardboard = { -- copeaux de carton qui tombent du tunnel en feuille morte, et poussière brune sous les pieds
		{ at = { "Fx_Tunnel", "Frame/CardboardBits" }, name = "ChipFall", tex = "CardboardChip", props = {
			Rate = 0.3, ["@RunRate"] = 3, Lifetime = NumberRange.new(1.4, 1.8), Speed = NumberRange.new(0.8, 1.6),
			SpreadAngle = Vector2.new(80, 80), EmissionDirection = Enum.NormalId.Bottom, Acceleration = Vector3.new(0, -3, 0),
			Drag = 1.5, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-120, 120), Squash = FLUTTER,
			Size = seq({ { 0, 0 }, { 0.08, 0.42 }, { 0.85, 0.4 }, { 1, 0 } }), LightEmission = 0, LightInfluence = 0.9 }, sheet = true },
		{ at = "Belt/RunBurstPoint", name = "RunStep", tex = "Smoke", props = {
			["@StepEmit"] = 1, Lifetime = NumberRange.new(0.35), Speed = NumberRange.new(2, 3), SpreadAngle = Vector2.new(40, 10),
			EmissionDirection = Enum.NormalId.Front, Drag = 3.5, Size = seq({ { 0, 0.4 }, { 1, 1.1 } }),
			Transparency = seq({ { 0, 0.45 }, { 1, 1 } }), Color = col(160, 120, 75), LightEmission = 0, LightInfluence = 1 } },
	},
	Bronze = { -- confettis de médaille : des rondelles de bronze qui jaillissent de la médaille et retombent en tournoyant
		{ at = { "Fx_Medal", "Frame/MedalCenter" }, name = "MedalConfetti", tex = "MedalConfetti", props = {
			["@StepEmit"] = 1, Lifetime = NumberRange.new(0.8, 1), Speed = NumberRange.new(5, 8), SpreadAngle = Vector2.new(55, 55),
			EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, -18, 0), Drag = 0.6,
			Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-200, 200), Squash = FLIP,
			Size = seq({ { 0, 0.2 }, { 0.1, 0.38 }, { 0.85, 0.36 }, { 1, 0 } }), LightEmission = 0.15, LightInfluence = 0.7,
			Brightness = 1.3 }, sheet = true },
		-- la médaille lance un reflet en croix de temps en temps, au repos
		{ at = { "Fx_Medal", "Frame/MedalCenter" }, name = "MedalGlint", tex = "Sparkle", props = {
			Rate = 0.4, Lifetime = NumberRange.new(1.2), Speed = NumberRange.new(0), LockedToPart = true,
			Size = seq({ { 0, 0 }, { 0.2, 1 }, { 0.5, 0.4 }, { 1, 0 } }), Rotation = NumberRange.new(0, 45), RotSpeed = NumberRange.new(40),
			Color = col(255, 190, 120), LightEmission = 0.5, LightInfluence = 0, Brightness = 2, ZOffset = 0.3 } },
	},
	Silver = { -- poussière d'étoile qui descend de l'étoile en spirale autour du coureur, jamais devant lui
		-- La spirale vient de l'étoile qui tourne (FxMotion = Spin sur la pièce qui porte Fx_Star) : chaque grain part vers
		-- la droite de l'étoile à l'instant où il naît, donc dans une direction qui tourne avec elle, puis il descend.
		{ at = { "Fx_Star", "Frame/StarCenter" }, name = "StarDust", tex = "SilverStar", props = {
			Rate = 4, ["@RunOnly"] = true, Lifetime = NumberRange.new(1.3, 1.5), Speed = NumberRange.new(2.2, 2.8),
			SpreadAngle = Vector2.new(8, 8), EmissionDirection = Enum.NormalId.Right, Acceleration = Vector3.new(0, -3.2, 0),
			Drag = 0.7, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-90, 90),
			Size = seq({ { 0, 0.35 }, { 0.7, 0.25 }, { 1, 0 } }), Transparency = seq({ { 0, 0 }, { 0.7, 0.2 }, { 1, 1 } }),
			LightEmission = 0.45, LightInfluence = 0.2, Brightness = 1.8 }, sheet = true },
		-- l'étoile scintille, même au repos (1 particule)
		{ at = { "Fx_Star", "Frame/StarCenter" }, name = "StarTwinkle", tex = "Sparkle", props = {
			Rate = 0.5, Lifetime = NumberRange.new(2), Speed = NumberRange.new(0), LockedToPart = true,
			Size = seq({ { 0, 0 }, { 0.15, 1.1 }, { 0.3, 0.6 }, { 0.45, 1 }, { 0.6, 0.55 }, { 0.75, 0.9 }, { 1, 0 } }),
			Rotation = NumberRange.new(0, 45), RotSpeed = NumberRange.new(20), Color = col(235, 242, 255),
			LightEmission = 0.5, LightInfluence = 0, Brightness = 2 } },
	},
	Supermarket = { -- le laser rouge du scanner balaie à chaque gain, et des étiquettes de prix s'envolent du scanner
		-- trait fixe et pâle sous la vitre du scanner (un Beam : pas une particule)
		{ at = { "Fx_Scanner", "Frame/ScannerLight" }, name = "ScanBeam", tex = "ScanLaser", beam = { down = 1.6 }, props = {
			Width0 = 0.08, Width1 = 0.08, Color = col(255, 45, 40), LightEmission = 1, LightInfluence = 0, Brightness = 2,
			Transparency = NumberSequence.new(0.45), FaceCamera = true, TextureMode = Enum.TextureMode.Stretch } },
		-- le balayage : un trait rouge étiré qui file le long de la bande en 0,25 s, à chaque gain
		{ at = { "Fx_Scanner", "Frame/ScannerLight" }, name = "ScanSweep", tex = "ScanLaser", props = {
			["@StepEmit"] = 1, Lifetime = NumberRange.new(0.25), Speed = NumberRange.new(24), SpreadAngle = Vector2.new(0, 0),
			EmissionDirection = Enum.NormalId.Back, Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
			Size = NumberSequence.new(1.8), Squash = NumberSequence.new(2.5), Transparency = seq({ { 0, 0.1 }, { 0.8, 0.3 }, { 1, 1 } }),
			Color = col(255, 45, 40), LightEmission = 1, LightInfluence = 0, Brightness = 2.5 } },
		{ at = { "Fx_Scanner", "Frame/ScannerLight" }, name = "TagFly", tex = "PriceTag", props = {
			["@StepEmit"] = 1, Lifetime = NumberRange.new(0.7, 0.8), Speed = NumberRange.new(6, 8), SpreadAngle = Vector2.new(35, 25),
			EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, -14, 0), Drag = 0.8,
			Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-160, 160), Squash = FLUTTER,
			Size = seq({ { 0, 0.3 }, { 0.12, 0.7 }, { 0.8, 0.65 }, { 1, 0 } }), Transparency = seq({ { 0, 0 }, { 0.8, 0 }, { 1, 1 } }),
			LightEmission = 0, LightInfluence = 0.8 }, sheet = true },
		-- le bip rouge qui clignote 2 fois par seconde, sans script (particule fixe allumée sur ses 40 premiers %)
		{ at = { "Fx_Scanner", "Frame/ScannerLight" }, name = "ScannerBlink", tex = "RunBurst", props = {
			Rate = 2, Lifetime = NumberRange.new(0.5), Speed = NumberRange.new(0), LockedToPart = true,
			Size = NumberSequence.new(0.7), Transparency = seq({ { 0, 0 }, { 0.4, 0 }, { 0.42, 1 }, { 1, 1 } }),
			Color = col(255, 50, 40), LightEmission = 0.8, LightInfluence = 0, Brightness = 2.5, ZOffset = 0.3 } },
	},
	-- Gold (niveau 6) : voir tools/clement/tapis_gold_proto.luau (validé). Les étages 2 à 5 suivent lot par lot.
}
TFX.THEMES = THEMES

-- Gerbe existante (Belt/RunBurstPoint/RunBurst, allumée par le code en course) et néons qui pulsent à chaque gain.
-- La teinte monte avec le palier (le Gold, validé, est à 0,45).
local EXTRA = {
	-- burst 0 : la gerbe commune s'efface, l'effet du thème suffit (lot 1 refait, 26/11)
	Base = { burst = 1, tint = 0.15, glow = { "RailGlow", "Button_1", "Button_2", "Button_3", "Button_4", "PostGlow", "Screen", "HoodGlow" } },
	Cardboard = { burst = 0, tint = 0.2, glow = { "RailGlow", "Button_1", "Button_2", "Button_3", "Button_4" } },
	Bronze = { burst = 0, tint = 0.25, glow = { "RailGlow", "Button_1", "Button_2", "Button_3", "Button_4", "PillarGlow", "MedalRing", "ScoreBoard" } },
	Silver = { burst = 1.5, tint = 0.3, glow = { "RailGlow", "Button_1", "Button_2", "Button_3", "Button_4", "Rune", "LintelGlow", "ArchEdge", "StarRing", "RearOrb", "HandleGem" } },
	Supermarket = { burst = 0, tint = 0.35, glow = { "RailGlow", "Button_1", "Button_2", "Button_3", "Button_4", "LaneNumber", "LaneTop", "Open", "ScannerLaser" } },
}
TFX.EXTRA = EXTRA

-- Un nom seul (« Fx_Medal ») se cherche dans tout le modèle : les points Fx_ sont sur la pièce qui bouge (Moving/…),
-- pour que l'effet suive sa rotation. Un chemin (« Belt/RunBurstPoint ») se suit pas à pas.
local function find(root: Instance, path: string): Instance?
	if not path:find("/") then return root:FindFirstChild(path, true) end
	local node: Instance? = root
	for name in path:gmatch("[^/]+") do node = node and node:FindFirstChild(name) end
	return node
end

-- Noms posés par ce script (anciennes versions comprises) : retirés avant de reposer un thème, pour ne rien empiler.
local OURS = { RunStep = true, BitsFall = true, MedalGlint = true, StepGlint = true, StarTwinkle = true, ScannerBlink = true,
	ChipFall = true, MedalConfetti = true, StarDust = true, ScanSweep = true, TagFly = true, ScanBeam = true, ScanBeamEnd = true }

local function anchor(model: Model, at: string | { string }): (Instance?, string)
	local paths = if type(at) == "table" then at else { at }
	for _, p in paths do
		local node = find(model, p)
		if node then return node, p end
	end
	return nil, table.concat(paths, " ou ")
end

-- Trait fixe : Beam entre le point et un Attachment posé « down » studs plus bas, dans le repère du point.
local function makeBeam(at: Instance, spec: any, texId: string)
	local part: Instance? = if at:IsA("Attachment") then at.Parent else at
	assert(part and part:IsA("BasePart"), "le point d'un Beam doit être un Attachment ou une pièce")
	local a0: Attachment
	if at:IsA("Attachment") then
		a0 = at
	else
		a0 = Instance.new("Attachment")
		a0.Name = spec.name .. "Start"
		a0.Parent = part
	end
	local a1 = Instance.new("Attachment")
	a1.Name = "ScanBeamEnd"
	a1.CFrame = a0.CFrame * CFrame.new(0, -spec.beam.down, 0)
	a1.Parent = part
	local b = Instance.new("Beam")
	b.Name = spec.name
	b.Texture = texId
	b.Attachment0, b.Attachment1 = a0, a1
	b.Segments = 1
	for k, v in spec.props do (b :: any)[k] = v end
	b.Parent = part
end

function TFX.apply(model: Model, theme: string): { string }
	local list = THEMES[theme]
	assert(list, "thème inconnu : " .. tostring(theme))
	local report = {}
	for _, d in model:GetDescendants() do
		if OURS[d.Name] and (d:IsA("ParticleEmitter") or d:IsA("Beam") or (d:IsA("Attachment") and d.Name == "ScanBeamEnd")) then
			d:Destroy()
		end
	end
	for _, spec in list do
		local at, where = anchor(model, spec.at)
		local texId = TEX[spec.tex]
		if not at then
			table.insert(report, "ABSENT " .. where .. " (" .. spec.name .. " sauté)")
		elseif texId == nil or texId == "" then
			table.insert(report, "texture pas encore publiée : " .. spec.tex .. " (" .. spec.name .. " sauté)")
		elseif spec.beam then
			makeBeam(at, spec, texId)
			table.insert(report, spec.name .. " (Beam) sous " .. where)
		else
			local e = Instance.new("ParticleEmitter")
			e.Name = spec.name
			e.Texture = texId
			e.Rate = 0
			if spec.toss then for k, v in TOSS do (e :: any)[k] = v end end
			if spec.sheet then for k, v in SHEET do (e :: any)[k] = v end end
			for k, v in spec.props do
				if k:sub(1, 1) == "@" then e:SetAttribute(k:sub(2), v) else (e :: any)[k] = v end
			end
			if e:GetAttribute("RunOnly") then e.Enabled = false end -- le code l'allume en course
			e.Parent = at
			table.insert(report, spec.name .. " sur " .. where)
		end
	end
	local extra = EXTRA[theme]
	if extra then
		local burst = find(model, "Belt/RunBurstPoint/RunBurst")
		if burst and burst:IsA("ParticleEmitter") then
			burst.Rate = extra.burst
			burst:SetAttribute("RunOnly", true)
			table.insert(report, "RunBurst à " .. extra.burst)
		end
		local n = 0
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				for _, prefix in extra.glow do
					if d.Name:sub(1, #prefix) == prefix then
						d:SetAttribute("PulseOnStep", true)
						d:SetAttribute("PulseTint", extra.tint)
						d:SetAttribute("PulseTime", 0.15)
						n += 1
						break
					end
				end
			end
		end
		table.insert(report, n .. " néons qui pulsent (teinte " .. extra.tint .. ")")
	end
	return report
end

function TFX.cost(model: Model): (number, number)
	local idle, run = 0, 0
	for _, d in model:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			local life = (d.Lifetime.Min + d.Lifetime.Max) / 2
			local runOnly = d:GetAttribute("RunOnly") == true
			local rate = d:GetAttribute("RunRate") or d.Rate
			if not runOnly and d.Enabled then idle += d.Rate * life end
			run += rate * life + (d:GetAttribute("StepEmit") or 0) * GAINS * life
		end
	end
	return idle, run
end

return TFX
