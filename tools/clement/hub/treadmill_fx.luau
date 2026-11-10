--!nocheck
--[[
	Effets des tapis texturés (MOD-016, 2026-11-08), sans script : seulement des ParticleEmitter natifs
	(un tapis est répété dans les 6 boutiques, la règle FX_ du CLAUDE.md interdit tout script dessus).
	À envoyer d'un bloc à execute_luau, en mode Edit, après treadmill_assets.luau. Relançable : les
	points d'effet d'un tapis sont refaits à chaque passage.

	Images de Clément (StealAShop-Art/Training/Treadmill/ToImport), importées au nom du groupe
	RoundStone Studio ; identifiants retrouvés par search_asset (scope group, Image).

	PLOT_Treadmill_Void :
	  - PortalPoint (dans le portique, face au coureur) : Portal (tourbillon qui tourne) et Ring
	    (anneau de runes, sens inverse), deux particules fixes qui se relaient en fondu ;
	  - FlamePoint_L et FlamePoint_R (haut des piliers arrière) : flammes violettes en flipbook 4x4 ;
	  - AuraPoint_L et AuraPoint_R (au pied des cristaux) : halos et étincelles qui montent.
	PLOT_Treadmill_Fire (version 2, sans script de FireTreadmill.lua) : dossier FireFX (Brazier1-2, Smoke1-2,
	  LavaWindow_*, CrackEmbers1-2, Fire_<contour> x 11 avec rideaux Beam, GroundGlow) et RunBurst éteint.
	PLOT_Treadmill_Gold (version sans script de GoldTreadmill.lua) : dossier GoldFX (Halo1 à 4, ColSparkle1 à 4
	  avec Beam et lumière, WingFX avec plumes et WingLight, GroundGlow) et RunBurstPoint/RunBurst éteint.
	PLOT_Treadmill_Ice (version sans script de IceTreadmill.lua, Clément) : dossier IceFX (Glint1 à 11,
	  Mist, Snow, FrostRing, FrostGlow, CrownLight, BeltLight), image de la bande, et RunBurstPoint/RunBurst
	  (éclats aux pieds, éteint : le code l'allume pendant la course).
	PLOT_Treadmill_CashRegister (sans script de CashRegisterTreadmill.lua) : dossier CashFX (PillarFX1-2 avec
	  Stream, Coins, Sparkle et lumière, DrawerFX, RegisterLight, GroundGlow), RunBurst et RunBurstCoins éteints.
	PLOT_Treadmill_Police (sans script de PoliceTreadmill.lua) : dossier PoliceFX (FlareR1-2 et FlareB1-2 à
	  Rate 0, Light_red/blue, Sweep_red/blue avec Spot et Beam, StarFX1-2, RunTrail), RunStreak éteint.
	PLOT_Treadmill_LaserVault (sans script de LaserVaultTreadmill.lua) : dossier LaserVaultFX (Laser1-9 et
	  ScanGate en Beam, CamScan1-2, Alarm1-3 à Rate 0, LaserLight), RunCoins éteint.
	PLOT_Treadmill_Toxic (sans script de ToxicGothicTreadmill.lua) : dossier ToxicFX (Lantern1-2, bulles,
	  Drip1-20, fumées, ToxicMist, Spores, GooGlow, BatsArch et BatsRoam, RunTrail), RunSplash éteint.
	PLOT_Treadmill_Candy (sans script de CandyTreadmill.lua) : dossier CandyFX (SprinkleArch, Sparkle1-4,
	  Cotton1-5, CandyRain1-2, Popper1-6 à Rate 0, CandyGlowGround, RunTrail), RunPops et RunPuff éteints.
	Tout le reste est allumé en permanence ; le code peut couper ou renforcer (Enabled, Rate) pendant la course.
]]

local RS = game:GetService("ReplicatedStorage")

local IDS = {
	Portal = "rbxassetid://84512886638305", -- FX_Treadmill_Void_Portal
	Ring = "rbxassetid://116768765895475", -- FX_Treadmill_Void_Ring
	Glow = "rbxassetid://111652023541007", -- FX_Treadmill_Void_Glow
	Sparkle = "rbxassetid://98038936938675", -- FX_Treadmill_Void_Sparkle
	FlameVoid = "rbxassetid://97499105576701", -- FX_Treadmill_Flame_Void
	FlameFire = "rbxassetid://115813684641761", -- FX_Treadmill_Flame_Fire (tapis Fire version 1, plus utilisé)
	FireRealFlame = "rbxassetid://81611598854766", -- FX_Treadmill_Fire_RealFlame (flipbook 8x8)
	FireFlame = "rbxassetid://126299566118869", -- FX_Treadmill_Fire_Flame (flipbook 4x4, style cartoon, en réserve)
	FireEmber = "rbxassetid://73699924686725", -- FX_Treadmill_Fire_Ember
	FireRealEmber = "rbxassetid://81375461750311", -- FX_Treadmill_Fire_RealEmber
	FireSmoke = "rbxassetid://89289805931242", -- FX_Treadmill_Fire_Smoke
	FireGlow = "rbxassetid://130394634481034", -- FX_Treadmill_Fire_Glow
	FireCurtain = "rbxassetid://93044099456044", -- FX_Treadmill_Fire_FlameCurtain
	FireHaze = "rbxassetid://124578869511011", -- FX_Treadmill_Fire_HeatHaze
	FireTongue = "rbxassetid://131510413731725", -- FX_Treadmill_Fire_FlameTongue
	IceBelt = "rbxassetid://77242952343811", -- PLOT_Treadmill_Ice_Belt
	IceMist = "rbxassetid://138558278142112", -- FX_Treadmill_Ice_Mist
	IceSparkle = "rbxassetid://116430793597850", -- FX_Treadmill_Ice_Sparkle
	IceFlake = "rbxassetid://139077482189563", -- FX_Treadmill_Ice_Snowflake
	IceRing = "rbxassetid://91532427078431", -- FX_Treadmill_Ice_Ring
	IceGlow = "rbxassetid://82986398234833", -- FX_Treadmill_Ice_Glow
	GoldSparkle = "rbxassetid://127314074011197", -- FX_Treadmill_Gold_Sparkle
	GoldFeather = "rbxassetid://78932040675192", -- FX_Treadmill_Gold_Feather
	GoldGlow = "rbxassetid://71001560516016", -- FX_Treadmill_Gold_Glow
	GoldRing = "rbxassetid://138539466696529", -- FX_Treadmill_Gold_Ring
	GoldBeam = "rbxassetid://136889032474760", -- FX_Treadmill_Gold_Beam
	CashBill = "rbxassetid://124877141136214", -- FX_Treadmill_CashRegister_Bill
	CashCoin = "rbxassetid://93580691646372", -- FX_Treadmill_CashRegister_Coin
	CashSparkle = "rbxassetid://91048606687733", -- FX_Treadmill_CashRegister_Sparkle
	CashStream = "rbxassetid://92032257547341", -- FX_Treadmill_CashRegister_BillStream
	CashGlow = "rbxassetid://73955247790912", -- FX_Treadmill_CashRegister_Glow
	CashBelt = "rbxassetid://90862200051580", -- PLOT_Treadmill_CashRegister_Belt (posée par treadmill_assets.luau)
	PoliceFlareRed = "rbxassetid://72368422683138", -- FX_Treadmill_Police_FlareRed
	PoliceFlareBlue = "rbxassetid://103897256070027", -- FX_Treadmill_Police_FlareBlue
	PoliceSweep = "rbxassetid://133819295634837", -- FX_Treadmill_Police_SirenSweep
	PoliceStar = "rbxassetid://139316542352508", -- FX_Treadmill_Police_StarSparkle
	PoliceStreak = "rbxassetid://108815534391966", -- FX_Treadmill_Police_SpeedStreak
	PoliceBelt = "rbxassetid://92650377809201", -- PLOT_Treadmill_Police_Belt (posée par treadmill_assets.luau)
	VaultLaser = "rbxassetid://93930729440891", -- FX_Treadmill_LaserVault_LaserBeam
	VaultSpark = "rbxassetid://116404199501488", -- FX_Treadmill_LaserVault_LaserSpark
	VaultAlarm = "rbxassetid://89331789019091", -- FX_Treadmill_LaserVault_AlarmFlash
	VaultScan = "rbxassetid://77452083507629", -- FX_Treadmill_LaserVault_ScanCone
	VaultBelt = "rbxassetid://88509301607993", -- PLOT_Treadmill_LaserVault_Belt (posée par treadmill_assets.luau)
	-- FX_Treadmill_LaserVault_GoldCoin est la même image que FX_Treadmill_CashRegister_Coin : on réutilise CashCoin
	ToxicBubble = "rbxassetid://110755074296243", -- FX_Treadmill_Toxic_Bubble
	ToxicDrip = "rbxassetid://139827032010850", -- FX_Treadmill_Toxic_Drip
	ToxicFume = "rbxassetid://116089739376535", -- FX_Treadmill_Toxic_Fume
	ToxicFlame = "rbxassetid://70745072724015", -- FX_Treadmill_Toxic_LanternFlame (flipbook 4x4)
	ToxicTrail = "rbxassetid://111399079580836", -- FX_Treadmill_Toxic_GooTrail
	ToxicGlow = "rbxassetid://115802013088902", -- FX_Treadmill_Toxic_Glow
	ToxicBat = "rbxassetid://128730099626508", -- FX_Treadmill_Toxic_Bat (flipbook 2x2)
	CandySprinkles = "rbxassetid://76742894076995", -- FX_Treadmill_Candy_Sprinkles (flipbook 2x2)
	CandyWrapped = "rbxassetid://100136350103323", -- FX_Treadmill_Candy_WrappedCandy
	CandySparkle = "rbxassetid://79014947649205", -- FX_Treadmill_Candy_Sparkle
	CandyPuff = "rbxassetid://138704282879365", -- FX_Treadmill_Candy_SugarPuff
	CandyTrail = "rbxassetid://75741623485457", -- FX_Treadmill_Candy_CaneStripeTrail
	CandyGlow = "rbxassetid://124738027794368", -- FX_Treadmill_Candy_Glow
	CandyBelt = "rbxassetid://96315500224842", -- PLOT_Treadmill_Candy_Belt
	CandyCotton = "rbxassetid://140347845830141", -- FX_Treadmill_Candy_CottonCandy
}

local function ns(t)
	local k = {}
	for _, p in t do table.insert(k, NumberSequenceKeypoint.new(p[1], p[2])) end
	return NumberSequence.new(k)
end

local function point(part, name, pos)
	local old = part.Parent:FindFirstChild(name, true)
	if old then old:Destroy() end
	local a = Instance.new("Attachment")
	a.Name = name
	a.Parent = part
	a.WorldCFrame = CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1)) -- avant de l'attache vers le coureur (+Z)
	return a
end

local function emitter(parent, name, props)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	for k, v in props do e[k] = v end
	e.Parent = parent
	return e
end

-- disque fixe face au coureur, qui tourne : deux particules qui se relaient en fondu
local function disc(parent, name, texture, size, rotSpeed, lightEmission, zOffset)
	return emitter(parent, name, {
		Texture = texture, Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Front, Speed = NumberRange.new(0.01), SpreadAngle = Vector2.new(0, 0),
		LockedToPart = true, Lifetime = NumberRange.new(4), Rate = 0.5,
		Size = ns({ { 0, size }, { 1, size } }), Transparency = ns({ { 0, 1 }, { 0.25, 0.05 }, { 0.75, 0.05 }, { 1, 1 } }),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(rotSpeed),
		LightEmission = lightEmission, LightInfluence = 0, ZOffset = zOffset, Brightness = 1.2,
	})
end

local function flames(parent, texture, color)
	return emitter(parent, "Flame", {
		Texture = texture, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.Loop, FlipbookFramerate = NumberRange.new(18, 22),
		FlipbookStartRandom = true, Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(1, 1.6), SpreadAngle = Vector2.new(6, 6),
		Acceleration = Vector3.new(0, 2, 0), Lifetime = NumberRange.new(0.6, 0.9), Rate = 7,
		Size = ns({ { 0, 1.5 }, { 0.6, 1.3 }, { 1, 0.7 } }), Transparency = ns({ { 0, 0.15 }, { 0.75, 0.25 }, { 1, 1 } }),
		Color = ColorSequence.new(color), LightEmission = 0.7, LightInfluence = 0, Brightness = 1.3,
	})
end

local function aura(parent)
	emitter(parent, "Glow", {
		Texture = IDS.Glow, EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(0.6, 1.2),
		SpreadAngle = Vector2.new(35, 35), Lifetime = NumberRange.new(2, 3), Rate = 3,
		Size = ns({ { 0, 0.2 }, { 0.3, 0.7 }, { 1, 0.3 } }), Transparency = ns({ { 0, 1 }, { 0.2, 0.3 }, { 1, 1 } }),
		LightEmission = 1, LightInfluence = 0,
	})
	emitter(parent, "Sparkle", {
		Texture = IDS.Sparkle, EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(0.5, 1.5),
		SpreadAngle = Vector2.new(45, 45), Lifetime = NumberRange.new(0.8, 1.4), Rate = 4,
		Size = ns({ { 0, 0 }, { 0.3, 0.45 }, { 1, 0 } }), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-90, 90),
		LightEmission = 1, LightInfluence = 0,
	})
end

local plots = RS.Assets.Plots
local report = {}

local void = plots:FindFirstChild("PLOT_Treadmill_Void")
if void then
	local host = void.VoidSteel
	-- portique : ouverture x ±1,76, y 1,52..5,52 ; plaque du fond à z -3,46 (repère du tapis, avant vers -Z)
	local portal = point(host, "PortalPoint", Vector3.new(0, 3.52, -3.38))
	disc(portal, "Portal", IDS.Portal, 3.4, 35, 0.15, 0)
	disc(portal, "Ring", IDS.Ring, 3.9, -20, 1, 0.2)
	for _, s in { { "L", -1 }, { "R", 1 } } do
		local f = point(host, "FlamePoint_" .. s[1], Vector3.new(s[2] * 2.08, 2.94, 3.66)) -- haut des piliers arrière
		flames(f, IDS.FlameVoid, Color3.new(1, 1, 1))
		local a = point(host, "AuraPoint_" .. s[1], Vector3.new(s[2] * 2.6, 0.6, 0.3)) -- pied des cristaux
		aura(a)
	end
	table.insert(report, "PLOT_Treadmill_Void : portail, anneau, 2 flammes, 2 auras")
end

-- Fire (version 2) : version sans script de FireTreadmill.lua (Clément), même repère (K = 1), réglage PC
-- (QUALITY = 1), braseros en flammes réalistes 8x8. Pour le code : défilement de BeltTexture, RunBurst
-- pendant la course, scintillement des deux FireFX.BrazierN.Light (2 ± 0,7, opposés) et de la couleur de
-- EmberGlow. Les rideaux de flammes (Beam) défilent seuls (TextureSpeed). Performance : environ 70 émetteurs
-- par tapis ; pour un téléphone, le code peut diviser les Rate par deux (QUALITY = 0,5 du script).
local fire = plots:FindFirstChild("PLOT_Treadmill_Fire")
if fire then
	local AMBER, EMBER = Color3.fromHex("FFC13D"), Color3.fromHex("FF5A17")
	local old = fire:FindFirstChild("FireFX")
	if old then old:Destroy() end
	local fx = Instance.new("Folder")
	fx.Name = "FireFX"
	fx.Parent = fire
	local function zone(name, sx, sy, sz, cf)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = Vector3.new(sx, sy, sz)
		p.CFrame = cf
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Transparency = 1
		p.Parent = fx
		return p
	end
	local function colors(t)
		local k = {}
		for _, c in t do table.insert(k, ColorSequenceKeypoint.new(c[1], c[2])) end
		return ColorSequence.new(k)
	end
	-- braseros arrière : flammes réalistes, braises, fumée, lumière
	for i, x in { -1.98, 1.98 } do
		local z = zone("Brazier" .. i, 0.4, 0.2, 0.4, CFrame.new(x, 1.75, 3.7))
		emitter(z, "Flame", {
			Texture = IDS.FireRealFlame, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8,
			FlipbookMode = Enum.ParticleFlipbookMode.Loop, FlipbookStartRandom = true, FlipbookFramerate = NumberRange.new(28),
			Orientation = Enum.ParticleOrientation.FacingCameraWorldUp, LightEmission = 0.5, LightInfluence = 0,
			Color = colors({ { 0, Color3.new(1, 1, 1) }, { 0.6, Color3.fromRGB(255, 210, 170) }, { 1, Color3.fromRGB(255, 120, 70) } }),
			Rate = 12, Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(0.6, 1),
			EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(6, 6),
			Size = ns({ { 0, 0.7 }, { 0.4, 0.9 }, { 1, 0.4 } }), Transparency = ns({ { 0, 0.1 }, { 0.75, 0.2 }, { 1, 1 } }),
			Shape = Enum.ParticleEmitterShape.Box,
		})
		emitter(z, "Ember", {
			Texture = IDS.FireEmber, LightEmission = 1, LightInfluence = 0, Color = ColorSequence.new(AMBER, EMBER),
			Rate = 8, Lifetime = NumberRange.new(0.8, 1.6), Speed = NumberRange.new(1.5, 3),
			EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(25, 25), Drag = 1, Size = ns({ { 0, 0.18 }, { 1, 0 } }),
		})
		emitter(zone("Smoke" .. i, 0.3, 0.1, 0.3, CFrame.new(x, 2.5, 3.7)), "Smoke", {
			Texture = IDS.FireSmoke, LightInfluence = 1, Color = ColorSequence.new(Color3.fromRGB(70, 60, 55)),
			Rate = 3, Lifetime = NumberRange.new(2, 3), Speed = NumberRange.new(0.8, 1.2),
			EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(10, 10),
			Size = ns({ { 0, 0.6 }, { 1, 2 } }), Transparency = ns({ { 0, 1 }, { 0.2, 0.55 }, { 1, 1 } }), RotSpeed = NumberRange.new(-20, 20),
		})
		local l = Instance.new("PointLight"); l.Name = "Light"; l.Color = Color3.fromRGB(255, 122, 32); l.Range = 10; l.Brightness = 2; l.Parent = z
	end
	-- fenêtres de lave : lumière douce sur les côtés
	for _, s in { -1, 1 } do
		for k, zc in { -0.9, 1.1 } do
			local z = zone(string.format("LavaWindow_%s%d", s < 0 and "L" or "R", k), 0.1, 0.5, 1.3, CFrame.new(s * 2.2, 0.67, zc))
			local sl = Instance.new("SurfaceLight"); sl.Name = "Light"; sl.Face = s > 0 and Enum.NormalId.Right or Enum.NormalId.Left
			sl.Color = EMBER; sl.Range = 6; sl.Brightness = 1.5; sl.Angle = 120; sl.Parent = z
		end
	end
	-- braises qui s'échappent des fissures (capot et plaque arrière)
	for i, c in { { 0, 1.3, -2.9, 2.2, 1 }, { 0, 0.6, 4.32, 2.2, 0.1 } } do
		emitter(zone("CrackEmbers" .. i, c[4], 0.1, c[5], CFrame.new(c[1], c[2], c[3])), "Ember", {
			Texture = IDS.FireEmber, LightEmission = 1, LightInfluence = 0, Color = ColorSequence.new(AMBER, EMBER),
			Rate = 4, Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(0.8, 1.6),
			EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(30, 30), Size = ns({ { 0, 0.14 }, { 1, 0 } }),
			Shape = Enum.ParticleEmitterShape.Box,
		})
	end
	-- flammes réalistes sur tout le contour { nom, début, fin, hauteur des flammes }
	local CONTOURS = {
		{ "RailLeft", Vector3.new(-2.2, 1.34, -4.1), Vector3.new(-2.2, 1.34, 4.1), 1.1 },
		{ "RailRight", Vector3.new(2.2, 1.34, -4.1), Vector3.new(2.2, 1.34, 4.1), 1.1 },
		{ "HoodFront", Vector3.new(-1.72, 1.3, -4.22), Vector3.new(1.72, 1.3, -4.22), 1.0 },
		{ "HoodRearLip", Vector3.new(-1.6, 1.3, -2.4), Vector3.new(1.6, 1.3, -2.4), 0.5 },
		{ "UprightLeft", Vector3.new(-1.25, 1.52, -3.48), Vector3.new(-1.25, 3.88, -3.48), 0.85 },
		{ "UprightRight", Vector3.new(1.25, 1.52, -3.48), Vector3.new(1.25, 3.88, -3.48), 0.85 },
		{ "ConsoleBack", Vector3.new(-1.6, 4.6, -4.2), Vector3.new(1.6, 4.6, -4.2), 0.8 },
		{ "ConsoleFront", Vector3.new(-1.6, 4.6, -3.3), Vector3.new(1.6, 4.6, -3.3), 0.8 },
		{ "ConsoleLeft", Vector3.new(-1.6, 4.6, -4.2), Vector3.new(-1.6, 4.6, -3.3), 0.8 },
		{ "ConsoleRight", Vector3.new(1.6, 4.6, -4.2), Vector3.new(1.6, 4.6, -3.3), 0.8 },
		{ "RearPlate", Vector3.new(-1.6, 1.0, 4.15), Vector3.new(1.6, 1.0, 4.15), 0.9 },
	}
	for _, c in CONTOURS do
		local name, a, b, h = c[1], c[2], c[3], c[4]
		local mid, len = (a + b) / 2, (b - a).Magnitude
		local vertical = math.abs(a.Y - b.Y) > 0.5
		local dir = (b - a).Unit
		local lcf = CFrame.lookAt(mid, mid + dir, vertical and Vector3.zAxis or Vector3.yAxis)
		local z = zone("Fire_" .. name, 0.15, 0.1, len, lcf)
		local up = vertical and Enum.NormalId.Front or Enum.NormalId.Top
		emitter(z, "Flame", {
			Texture = IDS.FireRealFlame, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8, FlipbookMode = Enum.ParticleFlipbookMode.Loop,
			FlipbookFramerate = NumberRange.new(26, 30), FlipbookStartRandom = true, Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
			LightEmission = 0.8, LightInfluence = 0,
			Color = colors({ { 0, Color3.new(1, 1, 1) }, { 0.55, Color3.fromRGB(255, 205, 160) }, { 1, Color3.fromRGB(255, 110, 60) } }),
			Rate = math.max(4, len * (vertical and 4.5 or 6)), Lifetime = NumberRange.new(0.55, 1.0),
			Speed = NumberRange.new(h * 0.3, h * 0.6), Acceleration = Vector3.new(0, h * 1.2, 0), Drag = 0.8, SpreadAngle = Vector2.new(0, 0),
			Size = ns({ { 0, h * 0.35 }, { 0.25, h * 0.6 }, { 0.7, h * 0.55 }, { 1, h * 0.25 } }), Squash = ns({ { 0, -0.15 }, { 1, -0.35 } }),
			Transparency = ns({ { 0, 1 }, { 0.12, 0.05 }, { 0.6, 0.15 }, { 1, 1 } }), Rotation = NumberRange.new(-5, 5), ZOffset = 0.2,
			Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, EmissionDirection = up,
		})
		emitter(z, "Core", {
			Texture = IDS.FireTongue, Orientation = Enum.ParticleOrientation.FacingCameraWorldUp, LightEmission = 1, LightInfluence = 0,
			Color = ColorSequence.new(Color3.fromRGB(255, 240, 190), Color3.fromRGB(255, 170, 60)),
			Rate = math.max(3, len * 3), Lifetime = NumberRange.new(0.3, 0.5), Speed = NumberRange.new(h * 0.4, h * 0.7), SpreadAngle = Vector2.new(0, 0),
			Size = ns({ { 0, h * 0.25 }, { 0.4, h * 0.32 }, { 1, 0 } }), Squash = ns({ { 0, -0.3 }, { 1, -0.5 } }),
			Transparency = ns({ { 0, 1 }, { 0.15, 0.1 }, { 1, 1 } }), ZOffset = 0.35, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = up,
		})
		emitter(z, "Ember", {
			Texture = IDS.FireRealEmber, LightEmission = 1, LightInfluence = 0,
			Rate = math.max(2, len * 1.5), Lifetime = NumberRange.new(0.8, 1.6), Speed = NumberRange.new(1.5, 3),
			Acceleration = Vector3.new(0, 1, 0), Drag = 1.2, SpreadAngle = Vector2.new(0, 0), Size = ns({ { 0, 0.12 }, { 1, 0 } }),
			Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = up,
		})
		emitter(z, "Haze", {
			Texture = IDS.FireHaze, LightInfluence = 0, Color = ColorSequence.new(Color3.new(1, 1, 1)),
			Rate = math.max(1, len * 0.6), Lifetime = NumberRange.new(1.2, 1.8), Speed = NumberRange.new(h * 0.8, h * 1.2),
			Size = ns({ { 0, h * 0.6 }, { 1, h * 1.2 } }), Transparency = ns({ { 0, 1 }, { 0.3, 0.6 }, { 1, 1 } }),
			Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = up,
		})
		emitter(z, "Smoke", {
			Texture = IDS.FireSmoke, LightInfluence = 1, Color = ColorSequence.new(Color3.fromRGB(60, 50, 46)),
			Rate = math.max(1, len * 0.5), Lifetime = NumberRange.new(1.8, 2.8), Speed = NumberRange.new(h * 1.2, h * 1.6),
			Size = ns({ { 0, h * 0.5 }, { 1, h * 1.6 } }), Transparency = ns({ { 0, 1 }, { 0.35, 0.7 }, { 1, 1 } }),
			RotSpeed = NumberRange.new(-25, 25), Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = up,
		})
		emitter(z, "Glow", {
			Texture = IDS.FireGlow, LightEmission = 1, LightInfluence = 0, Color = ColorSequence.new(Color3.fromRGB(255, 110, 30)),
			Rate = math.max(2, len * 1.5), Lifetime = NumberRange.new(0.4, 0.7), Speed = NumberRange.new(0),
			Size = ns({ { 0, h * 0.7 }, { 1, h * 0.9 } }), Transparency = ns({ { 0, 1 }, { 0.3, 0.65 }, { 1, 1 } }),
			Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = up,
		})
		-- rideau de flammes (Beam) pour les contours horizontaux ; il défile seul (TextureSpeed)
		if not vertical and h >= 0.8 then
			local rot = lcf - lcf.Position
			local function att(n, p)
				local at0 = Instance.new("Attachment"); at0.Name = n; at0.Parent = z
				at0.WorldCFrame = CFrame.new(p.X, p.Y + h * 0.27, p.Z) * rot
				return at0
			end
			local beam = Instance.new("Beam")
			beam.Name = "Curtain"; beam.Attachment0, beam.Attachment1 = att("CurtainA", a), att("CurtainB", b)
			beam.Texture = IDS.FireCurtain; beam.TextureMode = Enum.TextureMode.Static; beam.TextureLength = 2
			beam.TextureSpeed = 0.15; beam.FaceCamera = false; beam.Width0, beam.Width1 = h * 0.55, h * 0.55
			beam.LightEmission = 1; beam.LightInfluence = 0; beam.Color = ColorSequence.new(Color3.new(1, 1, 1))
			beam.Transparency = ns({ { 0, 0.15 }, { 0.5, 0.05 }, { 1, 0.15 } }); beam.Segments = 1; beam.Parent = z
		end
	end
	-- halo au sol
	local halo = zone("GroundGlow", 7, 0.05, 11, CFrame.new(0, 0.02, 0))
	local hd = Instance.new("Decal"); hd.Name = "Glow"; hd.Texture = IDS.FireGlow; hd.Face = Enum.NormalId.Top; hd.Transparency = 0.5; hd.Parent = halo
	-- braises aux pieds du coureur : éteintes, le code les allume pendant la course
	local burstPoint = point(fire.Belt, "RunBurstPoint", fire.Belt.UsePoint.WorldPosition + Vector3.new(0, 0.2, 0.3))
	emitter(burstPoint, "RunBurst", {
		Texture = IDS.FireEmber, Color = ColorSequence.new(AMBER, EMBER), LightEmission = 1,
		Rate = 24, Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(4, 7),
		EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(35, 15), Acceleration = Vector3.new(0, -10, 0),
		Size = ns({ { 0, 0.35 }, { 1, 0 } }), Enabled = false,
	})
	local count = 0
	for _, d in fx:GetDescendants() do if d:IsA("ParticleEmitter") then count += 1 end end
	table.insert(report, "PLOT_Treadmill_Fire : 2 braseros, 4 fenêtres de lave, 2 fissures, 11 contours en feu, halo au sol (" .. count .. " émetteurs), RunBurst éteint")
end

-- Ice : version sans script de IceTreadmill.lua (Clément) ; repère du tapis = repère du script (K = 1).
-- Ce qui bougeait dans le script revient au code d'Ironix : défilement de BeltTexture (3 studs/s à vide,
-- 9 en course), RunBurst allumé pendant la course, BeltArrows qui pulse, FrostRing qui tourne (0,12 rad/s).
local ice = plots:FindFirstChild("PLOT_Treadmill_Ice")
if ice then
	local CYAN, ICE = Color3.fromHex("5CF2FF"), Color3.fromHex("8FD8FF")
	local old = ice:FindFirstChild("IceFX")
	if old then old:Destroy() end
	local fx = Instance.new("Folder")
	fx.Name = "IceFX"
	fx.Parent = ice
	local function zone(name, sx, sy, sz, x, y, z)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = Vector3.new(sx, sy, sz)
		p.CFrame = CFrame.new(x, y, z)
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Transparency = 1
		p.Parent = fx
		return p
	end
	ice.Belt.BeltTexture.Texture = IDS.IceBelt
	-- reflets sur les grappes de cristaux { x, y, z, sx, sy, sz }
	local CLUSTERS = {
		{ 0, 6.0, -4.05, 2.6, 3.2, 0.8 },
		{ -1.98, 3.6, -3.5, 1, 5, 1.8 }, { 1.98, 3.6, -3.5, 1, 5, 1.8 },
		{ -1.98, 2.5, -1.55, 1, 3, 1.2 }, { 1.98, 2.5, -1.55, 1, 3, 1.2 },
		{ -1.98, 2.5, 0.45, 1, 3, 1.2 }, { 1.98, 2.5, 0.45, 1, 3, 1.2 },
		{ -1.98, 2.5, 2.35, 1, 3, 1.2 }, { 1.98, 2.5, 2.35, 1, 3, 1.2 },
		{ -1.98, 1.9, 3.95, 0.8, 1.6, 0.8 }, { 1.98, 1.9, 3.95, 0.8, 1.6, 0.8 },
	}
	for i, c in CLUSTERS do
		local z = zone("Glint" .. i, c[4], c[5], c[6], c[1], c[2], c[3])
		emitter(z, "Glint", {
			Texture = IDS.IceSparkle, LightEmission = 1, LightInfluence = 0, Color = ColorSequence.new(Color3.new(1, 1, 1), ICE),
			Rate = i == 1 and 6 or 3, Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(0),
			Size = ns({ { 0, 0 }, { 0.5, 0.7 }, { 1, 0 } }), Rotation = NumberRange.new(0, 90), RotSpeed = NumberRange.new(-120, 120),
			Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		})
	end
	-- brume froide au sol
	emitter(zone("Mist", 4.8, 0.2, 8.9, 0, 0.1, 0), "Mist", {
		Texture = IDS.IceMist, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = Enum.ParticleFlipbookMode.Loop,
		FlipbookFramerate = NumberRange.new(6), Color = ColorSequence.new(Color3.fromRGB(215, 240, 255)), LightEmission = 0.3,
		Rate = 10, Lifetime = NumberRange.new(2.5, 4), Speed = NumberRange.new(0.4, 0.9),
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(85, 85), Acceleration = Vector3.new(0, -0.4, 0), Drag = 1,
		Size = ns({ { 0, 1.5 }, { 1, 3.2 } }), Transparency = ns({ { 0, 1 }, { 0.3, 0.55 }, { 1, 1 } }), Shape = Enum.ParticleEmitterShape.Box,
		Enabled = IDS.IceMist ~= "rbxassetid://0", -- éteinte tant que son image manque
	})
	-- neige
	emitter(zone("Snow", 8, 0.2, 12, 0, 10, 0), "Snow", {
		Texture = IDS.IceFlake, Color = ColorSequence.new(Color3.new(1, 1, 1)), LightEmission = 0.4,
		Rate = 8, Lifetime = NumberRange.new(8, 12), Speed = NumberRange.new(0.6, 1.1),
		EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(15, 15),
		Size = ns({ { 0, 0.25 }, { 1, 0.2 } }), Transparency = ns({ { 0, 1 }, { 0.1, 0.1 }, { 0.9, 0.1 }, { 1, 1 } }),
		RotSpeed = NumberRange.new(-40, 40), Shape = Enum.ParticleEmitterShape.Box,
	})
	-- cercle de givre et halo au sol
	local ring = zone("FrostRing", 9.5, 0.05, 9.5, 0, 0.03, 0)
	local rd = Instance.new("Decal"); rd.Name = "Ring"; rd.Texture = IDS.IceRing; rd.Face = Enum.NormalId.Top; rd.Parent = ring
	local halo = zone("FrostGlow", 8, 0.05, 11, 0, 0.02, 0)
	local hd = Instance.new("Decal"); hd.Name = "Glow"; hd.Texture = IDS.IceGlow; hd.Face = Enum.NormalId.Top; hd.Transparency = 0.4; hd.Parent = halo
	-- lumières (luminosité moyenne de la pulsation du script)
	local crown = Instance.new("PointLight"); crown.Name = "CrownLight"; crown.Color = CYAN; crown.Range = 14; crown.Brightness = 2.1
	crown.Parent = zone("CrownLight", 0.2, 0.2, 0.2, 0, 6, -3.4)
	local bl = Instance.new("PointLight"); bl.Name = "BeltLight"; bl.Color = ICE; bl.Range = 10; bl.Brightness = 1.2
	bl.Parent = zone("BeltLight", 0.2, 0.2, 0.2, 0, 1.6, 0.5)
	-- éclats de givre aux pieds du coureur : éteint, le code l'allume pendant la course
	local burstPoint = point(ice.Belt, "RunBurstPoint", ice.Belt.UsePoint.WorldPosition + Vector3.new(0, 0.2, 0.3))
	emitter(burstPoint, "RunBurst", {
		Texture = IDS.IceSparkle, Color = ColorSequence.new(CYAN, Color3.new(1, 1, 1)), LightEmission = 1,
		Rate = 25, Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(4, 7),
		EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(35, 15), Acceleration = Vector3.new(0, -12, 0),
		Size = ns({ { 0, 0.35 }, { 1, 0 } }), Enabled = false,
	})
	table.insert(report, "PLOT_Treadmill_Ice : 11 reflets, brume, neige, cercle et halo au sol, 2 lumières, RunBurst éteint")
end

-- Gold (palier 1) : version sans script de GoldTreadmill.lua (Clément), même repère (K = 1).
-- Pour le code : défilement de BeltTexture, RunBurst pendant la course, pulsation de GoldGlow et de
-- GoldFX.WingFX.WingLight (1,2 à 2,2), rotation des GoldFX.Halo1 à 4 (1,1 rad/s, sens alternés).
local gold = plots:FindFirstChild("PLOT_Treadmill_Gold")
if gold then
	local GOLD, GLOW = Color3.fromHex("FFC21A"), Color3.fromHex("FFE45C")
	local old = gold:FindFirstChild("GoldFX")
	if old then old:Destroy() end
	local fx = Instance.new("Folder")
	fx.Name = "GoldFX"
	fx.Parent = gold
	local function zone(name, sx, sy, sz, x, y, z)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = Vector3.new(sx, sy, sz)
		p.CFrame = CFrame.new(x, y, z)
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Transparency = 1
		p.Parent = fx
		return p
	end
	local function sparkles(parent, rate, size)
		return emitter(parent, "Sparkle", {
			Texture = IDS.GoldSparkle, LightEmission = 1, LightInfluence = 0, Color = ColorSequence.new(Color3.new(1, 1, 1), GLOW),
			Rate = rate, Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(0),
			Size = ns({ { 0, 0 }, { 0.5, size }, { 1, 0 } }), RotSpeed = NumberRange.new(-120, 120),
			Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		})
	end
	-- colonnes : halo d'anneau, rayon de lumière vers le haut, scintillements, lumière
	local COLS = { { -1.97, 5.2, -3.85, 0.95 }, { 1.97, 5.2, -3.85, 0.95 }, { -1.97, 2.5, 3.85, 0.75 }, { 1.97, 2.5, 3.85, 0.75 } }
	for i, c in COLS do
		local h = zone("Halo" .. i, c[4], 0.05, c[4], c[1], c[2] + 0.35, c[3])
		for _, face in { Enum.NormalId.Top, Enum.NormalId.Bottom } do
			local d = Instance.new("Decal"); d.Name = "Ring_" .. face.Name; d.Texture = IDS.GoldRing; d.Face = face; d.Parent = h
		end
		local sz = zone("ColSparkle" .. i, 0.8, 1, 0.8, c[1], c[2] + 0.3, c[3])
		sparkles(sz, 3, 0.6)
		local l = Instance.new("PointLight"); l.Name = "Light"; l.Color = GLOW; l.Range = 7; l.Brightness = 1.2; l.Parent = sz
		local a0 = Instance.new("Attachment"); a0.Name = "BeamBottom"; a0.Parent = sz
		a0.WorldPosition = Vector3.new(c[1], c[2], c[3])
		local a1 = Instance.new("Attachment"); a1.Name = "BeamTop"; a1.Parent = sz
		a1.WorldPosition = Vector3.new(c[1], c[2] + (c[2] > 4 and 1.3 or 1.1), c[3])
		local beam = Instance.new("Beam")
		beam.Name = "Beam"; beam.Attachment0, beam.Attachment1 = a0, a1
		beam.Texture = IDS.GoldBeam; beam.TextureMode = Enum.TextureMode.Stretch
		beam.Width0, beam.Width1 = 0.55, 0.55; beam.FaceCamera = true
		beam.LightEmission = 1; beam.LightInfluence = 0; beam.Color = ColorSequence.new(GLOW)
		beam.Transparency = ns({ { 0, 0.3 }, { 1, 0.3 } }); beam.Parent = sz
	end
	-- ailes : scintillements et plumes qui tombent
	local wing = zone("WingFX", 3.8, 1.8, 0.8, 0, 5.6, -3.9)
	sparkles(wing, 7, 0.7)
	emitter(wing, "Feather", {
		Texture = IDS.GoldFeather, LightInfluence = 0.6, Color = ColorSequence.new(Color3.new(1, 1, 1)),
		Rate = 1.2, Lifetime = NumberRange.new(5, 7), Speed = NumberRange.new(0.2, 0.5),
		EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(40, 40), Drag = 0.6,
		Acceleration = Vector3.new(0, -0.35, 0), Rotation = NumberRange.new(-30, 30), RotSpeed = NumberRange.new(-35, 35),
		Size = ns({ { 0, 0.35 }, { 1, 0.35 } }), Transparency = ns({ { 0, 1 }, { 0.1, 0 }, { 0.85, 0 }, { 1, 1 } }),
		Shape = Enum.ParticleEmitterShape.Box,
	})
	local wl = Instance.new("PointLight"); wl.Name = "WingLight"; wl.Color = GLOW; wl.Range = 12; wl.Brightness = 1.7; wl.Parent = wing
	-- halo doré au sol
	local halo = zone("GroundGlow", 7.5, 0.05, 11, 0, 0.02, 0)
	local hd = Instance.new("Decal"); hd.Name = "Glow"; hd.Texture = IDS.GoldGlow; hd.Face = Enum.NormalId.Top; hd.Transparency = 0.45; hd.Parent = halo
	-- paillettes aux pieds du coureur : éteintes, le code les allume pendant la course
	local burstPoint = point(gold.Belt, "RunBurstPoint", gold.Belt.UsePoint.WorldPosition + Vector3.new(0, 0.2, 0.3))
	emitter(burstPoint, "RunBurst", {
		Texture = IDS.GoldSparkle, Color = ColorSequence.new(GLOW, GOLD), LightEmission = 1,
		Rate = 22, Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(4, 7),
		EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(35, 15), Acceleration = Vector3.new(0, -12, 0),
		Size = ns({ { 0, 0.4 }, { 1, 0 } }), Enabled = false,
	})
	table.insert(report, "PLOT_Treadmill_Gold : 4 colonnes (halo, rayon, scintillements, lumière), ailes, halo au sol, RunBurst éteint")
end

-- Cash Register : version sans script de CashRegisterTreadmill.lua (Clément), même repère (K = 1).
-- Pour le code : défilement de BeltTexture, RunBurst et RunBurstCoins pendant la course, DrawerFX.Bills.Rate
-- de 3 à 9 en course, TextureSpeed des CashFX.PillarFXn.Stream de 0,35 à 0,9 en course, pulsation de la
-- couleur de GlowMint et de CashFX.RegisterLight.Light (1,3 à 1,9, sinus 3 rad/s).
local cash = plots:FindFirstChild("PLOT_Treadmill_CashRegister")
if cash then
	local MINT, GOLD = Color3.fromHex("2FE08F"), Color3.fromHex("FFC21A")
	local old = cash:FindFirstChild("CashFX")
	if old then old:Destroy() end
	local fx = Instance.new("Folder")
	fx.Name = "CashFX"
	fx.Parent = cash
	local function zone(name, sx, sy, sz, x, y, z)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = Vector3.new(sx, sy, sz)
		p.CFrame = CFrame.new(x, y, z)
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Transparency = 1
		p.Parent = fx
		return p
	end
	local SPIN = ns({ { 0, 0 }, { 0.15, 1.6 }, { 0.3, 0 }, { 0.45, 1.6 }, { 0.6, 0 }, { 0.75, 1.6 }, { 0.9, 0 }, { 1, 1.6 } }) -- pièce qui tourne
	-- piliers de pièces : flux de billets (Beam), pièces qui jaillissent, scintillements, lumière
	for i, p in { Vector3.new(-1.99, 3.04, 3.75), Vector3.new(1.99, 3.04, 3.75) } do
		local z = zone("PillarFX" .. i, 0.5, 0.2, 0.5, p.X, p.Y + 0.1, p.Z)
		local a0 = Instance.new("Attachment"); a0.Name = "StreamBottom"; a0.Parent = z; a0.WorldPosition = p
		local a1 = Instance.new("Attachment"); a1.Name = "StreamTop"; a1.Parent = z; a1.WorldPosition = p + Vector3.new(0, 2.4, 0)
		local bm = Instance.new("Beam")
		bm.Name = "Stream"; bm.Attachment0, bm.Attachment1 = a0, a1
		bm.Texture = IDS.CashStream; bm.TextureMode = Enum.TextureMode.Static; bm.TextureLength = 2.4; bm.TextureSpeed = 0.35
		bm.Width0, bm.Width1 = 0.6, 0.75; bm.FaceCamera = true
		bm.LightInfluence = 0.3; bm.Transparency = ns({ { 0, 0.1 }, { 0.7, 0.2 }, { 1, 1 } }); bm.Parent = z
		emitter(z, "Coins", {
			Texture = IDS.CashCoin, LightInfluence = 0.5, Color = ColorSequence.new(Color3.new(1, 1, 1)),
			Rate = 3, Lifetime = NumberRange.new(1.2, 1.8), Speed = NumberRange.new(4, 6),
			EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(25, 25), Acceleration = Vector3.new(0, -14, 0),
			Size = ns({ { 0, 0.3 }, { 1, 0.3 } }), Squash = SPIN,
		})
		emitter(z, "Sparkle", {
			Texture = IDS.CashSparkle, LightEmission = 1, LightInfluence = 0, Color = ColorSequence.new(Color3.new(1, 1, 1), MINT),
			Rate = 3, Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(0),
			Size = ns({ { 0, 0 }, { 0.5, 0.5 }, { 1, 0 } }), RotSpeed = NumberRange.new(-120, 120),
			Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		})
		local l = Instance.new("PointLight"); l.Name = "Light"; l.Color = GOLD; l.Range = 7; l.Brightness = 1.2; l.Parent = z
	end
	-- tiroir-caisse : billets qui s'envolent
	emitter(zone("DrawerFX", 2.2, 0.2, 0.4, 0, 4.75, -2.75), "Bills", {
		Texture = IDS.CashBill, LightInfluence = 0.6, Color = ColorSequence.new(Color3.new(1, 1, 1)),
		Rate = 3, Lifetime = NumberRange.new(1.8, 2.6), Speed = NumberRange.new(3, 4.5),
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(30, 30), Acceleration = Vector3.new(0, -5, 0), Drag = 1.2,
		Size = ns({ { 0, 0.45 }, { 1, 0.45 } }), Rotation = NumberRange.new(-40, 40), RotSpeed = NumberRange.new(-120, 120),
		Squash = ns({ { 0, 0 }, { 0.25, -0.6 }, { 0.5, 0 }, { 0.75, -0.6 }, { 1, 0 } }),
		Transparency = ns({ { 0, 0 }, { 0.85, 0 }, { 1, 1 } }), Shape = Enum.ParticleEmitterShape.Box,
	})
	local rl = Instance.new("PointLight"); rl.Name = "Light"; rl.Color = MINT; rl.Range = 12; rl.Brightness = 1.6
	rl.Parent = zone("RegisterLight", 0.2, 0.2, 0.2, 0, 5.6, -2.6)
	-- halo menthe au sol
	local halo = zone("GroundGlow", 7, 0.05, 11, 0, 0.02, 0)
	local hd = Instance.new("Decal"); hd.Name = "Glow"; hd.Texture = IDS.CashGlow; hd.Face = Enum.NormalId.Top; hd.Transparency = 0.5; hd.Parent = halo
	-- billets et pièces qui volent derrière le coureur : éteints, le code les allume pendant la course
	local burstPoint = point(cash.Belt, "RunBurstPoint", cash.Belt.UsePoint.WorldPosition + Vector3.new(0, 0.4, 0.3))
	local burstProps = {
		Texture = IDS.CashBill, LightInfluence = 0.6, Rate = 8, Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(5, 8),
		EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(35, 25), Acceleration = Vector3.new(0, -8, 0),
		Size = ns({ { 0, 0.5 }, { 1, 0.35 } }), RotSpeed = NumberRange.new(-200, 200), Enabled = false,
	}
	emitter(burstPoint, "RunBurst", burstProps)
	burstProps.Texture = IDS.CashCoin; burstProps.Rate = 6; burstProps.Size = ns({ { 0, 0.35 }, { 1, 0.25 } })
	burstProps.Squash = ns({ { 0, 0 }, { 0.25, 1.6 }, { 0.5, 0 }, { 0.75, 1.6 }, { 1, 0 } })
	emitter(burstPoint, "RunBurstCoins", burstProps)
	table.insert(report, "PLOT_Treadmill_CashRegister : 2 piliers (flux de billets, pièces, scintillements, lumière), tiroir à billets, lumière de caisse, halo au sol, RunBurst et RunBurstCoins éteints")
end
-- Police : version sans script de PoliceTreadmill.lua (Clément), même repère (K = 1). Le script est surtout de
-- l'animation, qui revient au code : flashs rouge-rouge puis bleu-bleu (cycle 0,9 s : SirenRed/SirenBlue en
-- couleur pleine ou assombrie à 65 %, PoliceFX.Light_red/blue.Light à 6 ou 0, Emit(1) des FlareR1-2 / FlareB1-2
-- au début de chaque flash), rotation des PoliceFX.Sweep_red/blue autour de Y (4,5 rad/s, sens opposés),
-- défilement de BeltTexture, et pendant la course RunStreak allumé et PoliceFX.RunTrail copié sur le coureur.
local police = plots:FindFirstChild("PLOT_Treadmill_Police")
if police then
	local RED, BLUE = Color3.fromHex("FF2A3A"), Color3.fromHex("2F9BFF")
	local old = police:FindFirstChild("PoliceFX")
	if old then old:Destroy() end
	local fx = Instance.new("Folder")
	fx.Name = "PoliceFX"
	fx.Parent = police
	local function zone(name, sx, sy, sz, x, y, z)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = Vector3.new(sx, sy, sz)
		p.CFrame = CFrame.new(x, y, z)
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Transparency = 1
		p.Parent = fx
		return p
	end
	-- points de flash : Rate 0, le code appelle Emit(1) à chaque flash
	for _, f in { { "FlareR1", -0.83, 5.3, -3.7, IDS.PoliceFlareRed, 2.4 }, { "FlareR2", -1.95, 4.95, -3.63, IDS.PoliceFlareRed, 1.5 },
		{ "FlareB1", 0.83, 5.3, -3.7, IDS.PoliceFlareBlue, 2.4 }, { "FlareB2", 1.95, 4.95, -3.63, IDS.PoliceFlareBlue, 1.5 } } do
		emitter(zone(f[1], 0.2, 0.2, 0.2, f[2], f[3], f[4]), "Flare", {
			Texture = f[5], LightEmission = 1, LightInfluence = 0, Rate = 0, Lifetime = NumberRange.new(0.12), Speed = NumberRange.new(0),
			LockedToPart = true, Size = ns({ { 0, f[6] }, { 1, f[6] * 0.8 } }), Transparency = ns({ { 0, 0 }, { 1, 0.6 } }), ZOffset = 1,
		})
	end
	-- lumières des flashs : allumées doucement au repos ; le code les fait clignoter (6 / 0)
	for k, x in { red = -1.2, blue = 1.2 } do
		local l = Instance.new("PointLight"); l.Name = "Light"; l.Color = k == "red" and RED or BLUE; l.Range = 18; l.Brightness = 1.5; l.Shadows = false
		l.Parent = zone("Light_" .. k, 0.2, 0.2, 0.2, x, 5.6, -3.0)
	end
	-- gyrophares : SpotLight et faisceau (Beam) vers la rue ; le code fait tourner Sweep_red et Sweep_blue
	for k, x in { red = -0.83, blue = 0.83 } do
		local piv = zone("Sweep_" .. k, 0.2, 0.2, 0.2, x, 5.3, -3.7)
		local sl = Instance.new("SpotLight"); sl.Name = "Spot"; sl.Face = Enum.NormalId.Front; sl.Angle = 40; sl.Range = 24; sl.Brightness = 5
		sl.Color = k == "red" and RED or BLUE; sl.Parent = piv
		local a0 = Instance.new("Attachment"); a0.Name = "SweepStart"; a0.Parent = piv
		local a1 = Instance.new("Attachment"); a1.Name = "SweepEnd"; a1.Position = Vector3.new(0, 0, -4.5); a1.Parent = piv
		local bm = Instance.new("Beam"); bm.Name = "Sweep"; bm.Attachment0, bm.Attachment1 = a0, a1
		bm.Texture = IDS.PoliceSweep; bm.TextureMode = Enum.TextureMode.Stretch; bm.FaceCamera = true
		bm.Width0, bm.Width1 = 0.25, 1.4; bm.LightEmission = 1; bm.LightInfluence = 0
		bm.Color = ColorSequence.new(k == "red" and RED or BLUE); bm.Transparency = ns({ { 0, 0.25 }, { 1, 1 } }); bm.Parent = piv
	end
	-- étoiles dorées : badge et casquette
	for i, c in { { 0, 4.15, -4.25, 0.9, 0.8, 0.2 }, { -2.0, 2.95, 3.95, 0.6, 0.5, 0.6 } } do
		emitter(zone("StarFX" .. i, c[4], c[5], c[6], c[1], c[2], c[3]), "Star", {
			Texture = IDS.PoliceStar, LightEmission = 1, LightInfluence = 0, Color = ColorSequence.new(Color3.new(1, 1, 1)),
			Rate = 2.5, Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(0),
			Size = ns({ { 0, 0 }, { 0.5, 0.45 }, { 1, 0 } }), RotSpeed = NumberRange.new(-90, 90),
			Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		})
	end
	-- traînée rouge et bleue du coureur : modèle éteint, que le code copie sur le personnage avec ses attaches
	local tz = zone("RunTrail", 0.2, 0.2, 0.2, 0, 1.5, 0.4)
	local t0 = Instance.new("Attachment"); t0.Name = "RunTrail0"; t0.Position = Vector3.new(-0.9, 0, 0); t0.Parent = tz
	local t1 = Instance.new("Attachment"); t1.Name = "RunTrail1"; t1.Position = Vector3.new(0.9, 0, 0); t1.Parent = tz
	local trail = Instance.new("Trail"); trail.Name = "Trail"; trail.Attachment0, trail.Attachment1 = t0, t1
	trail.Texture = IDS.PoliceStreak; trail.TextureMode = Enum.TextureMode.Stretch; trail.Lifetime = 0.35; trail.MinLength = 0.05
	trail.LightEmission = 1; trail.LightInfluence = 0; trail.FaceCamera = true; trail.Enabled = false
	trail.Transparency = ns({ { 0, 0.1 }, { 1, 1 } }); trail.Parent = tz
	-- traits de vitesse aux pieds : éteints, le code les allume pendant la course
	local burstPoint = point(police.Belt, "RunBurstPoint", police.Belt.UsePoint.WorldPosition + Vector3.new(0, 0.2, 0.4))
	emitter(burstPoint, "RunStreak", {
		Texture = IDS.PoliceStreak, LightEmission = 1, Rate = 14, Lifetime = NumberRange.new(0.25, 0.4),
		Speed = NumberRange.new(10, 14), EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(10, 20),
		Orientation = Enum.ParticleOrientation.VelocityParallel, Size = ns({ { 0, 0.5 }, { 1, 0.2 } }), Enabled = false,
	})
	table.insert(report, "PLOT_Treadmill_Police : 4 flashs (Emit par le code), 2 lumières, 2 gyrophares (spot + faisceau), 2 étoiles, RunTrail et RunStreak éteints")
end
-- Laser Vault : version sans script de LaserVaultTreadmill.lua (Clément), même repère (K = 1). Les lasers
-- défilent seuls (TextureSpeed). Pour le code : alarme (AlarmGlow de 3A0A10 vers FF3B5C, LaserVaultFX.AlarmN.Light
-- de 0 à 3, Emit(1) des AlarmN.Flash au pic ; sinus au carré, 5,5 rad/s au repos, 9 en course), scintillement des
-- Beam et de LaserBeams, balayage de LaserVaultFX.ScanGate (y = 3,5 + 2,5 cos 0,8t), rotation des CamScan1-2
-- (lacet ± 0,45 sin(0,9t + 1,7 i)), défilement de BeltTexture et RunCoins allumé pendant la course.
local vault = plots:FindFirstChild("PLOT_Treadmill_LaserVault")
if vault then
	local RED, ALARM_RED = Color3.fromHex("FF2A3D"), Color3.fromHex("FF3B5C")
	local old = vault:FindFirstChild("LaserVaultFX")
	if old then old:Destroy() end
	local fx = Instance.new("Folder")
	fx.Name = "LaserVaultFX"
	fx.Parent = vault
	local function zone(name, sx, sy, sz, cf)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = Vector3.new(sx, sy, sz)
		p.CFrame = cf
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Transparency = 1
		p.Parent = fx
		return p
	end
	local function laser(name, a, b, w)
		local z = zone(name, 0.2, 0.2, 0.2, CFrame.new((a + b) / 2))
		local a0 = Instance.new("Attachment"); a0.Name = "A"; a0.Parent = z; a0.WorldPosition = a
		local a1 = Instance.new("Attachment"); a1.Name = "B"; a1.Parent = z; a1.WorldPosition = b
		local bm = Instance.new("Beam"); bm.Name = "Beam"; bm.Attachment0, bm.Attachment1 = a0, a1
		bm.Texture = IDS.VaultLaser; bm.TextureMode = Enum.TextureMode.Wrap; bm.TextureLength = 1.5; bm.TextureSpeed = 1.5
		bm.Width0, bm.Width1 = w, w; bm.FaceCamera = true; bm.LightEmission = 1; bm.LightInfluence = 0
		bm.Color = ColorSequence.new(RED); bm.Transparency = ns({ { 0, 0.05 }, { 1, 0.05 } }); bm.Parent = z
		return z
	end
	-- lasers en X sur les côtés et laser du haut du portique, avec étincelles aux émetteurs
	local LASERS = {}
	for _, s in { -1, 1 } do
		for _, o in { { -1.73, -0.07 }, { 0.67, 2.33 } } do
			table.insert(LASERS, { Vector3.new(s * 1.965, 0.47, o[1]), Vector3.new(s * 1.965, 1.23, o[2]) })
			table.insert(LASERS, { Vector3.new(s * 1.965, 1.23, o[1]), Vector3.new(s * 1.965, 0.47, o[2]) })
		end
	end
	table.insert(LASERS, { Vector3.new(-1.56, 6.235, 4.12), Vector3.new(1.56, 6.235, 4.12) })
	for i, l in LASERS do
		local z = laser("Laser" .. i, l[1], l[2], 0.55)
		for k, e in { l[1], l[2] } do
			local at = Instance.new("Attachment"); at.Name = "Spark" .. k; at.Parent = z; at.WorldPosition = e
			emitter(at, "Spark", {
				Texture = IDS.VaultSpark, LightEmission = 1, LightInfluence = 0, Color = ColorSequence.new(Color3.fromRGB(255, 220, 200), RED),
				Rate = 6, Lifetime = NumberRange.new(0.2, 0.45), Speed = NumberRange.new(1, 2.5), SpreadAngle = Vector2.new(180, 180),
				Acceleration = Vector3.new(0, -12, 0), Size = ns({ { 0, 0.18 }, { 1, 0 } }),
			})
		end
	end
	local ll = Instance.new("PointLight"); ll.Name = "Light"; ll.Color = RED; ll.Range = 10; ll.Brightness = 1.2
	ll.Parent = zone("LaserLight", 0.2, 0.2, 0.2, CFrame.new(0, 1.2, 0.3))
	-- laser horizontal de la porte arrière, au repos en haut ; le code le fait descendre et remonter
	laser("ScanGate", Vector3.new(-1.56, 6.0, 4.12), Vector3.new(1.56, 6.0, 4.12), 0.35)
	-- caméras : faisceau rouge et projecteur vers le tapis (pose de repos du script)
	for i, c in { { Vector3.new(0, 5.82, -3.68), 0, 0.38 }, { Vector3.new(-1.98, 5.42, 3.2), math.pi, 0.32 } } do
		local piv = zone("CamScan" .. i, 0.2, 0.2, 0.2, CFrame.new(c[1]) * CFrame.Angles(0, c[2] + math.pi, 0) * CFrame.Angles(-c[3] - 0.15, 0, 0))
		local a0 = Instance.new("Attachment"); a0.Name = "ScanStart"; a0.Parent = piv
		local a1 = Instance.new("Attachment"); a1.Name = "ScanEnd"; a1.Position = Vector3.new(0, 0, -5); a1.Parent = piv
		local bm = Instance.new("Beam"); bm.Name = "Scan"; bm.Attachment0, bm.Attachment1 = a0, a1
		bm.Texture = IDS.VaultScan; bm.TextureMode = Enum.TextureMode.Stretch; bm.FaceCamera = true
		bm.Width0, bm.Width1 = 0.15, 1.8; bm.LightEmission = 1; bm.LightInfluence = 0
		bm.Color = ColorSequence.new(ALARM_RED); bm.Transparency = ns({ { 0, 0.35 }, { 1, 1 } }); bm.Parent = piv
		local sl = Instance.new("SpotLight"); sl.Name = "Spot"; sl.Face = Enum.NormalId.Front; sl.Angle = 25; sl.Range = 10; sl.Brightness = 2
		sl.Color = ALARM_RED; sl.Parent = piv
	end
	-- alarme : flashs prêts (Rate 0, le code appelle Emit) et lumières douces au repos
	for i, p in { { 0, 5.6, -3.9, 2.2 }, { 0, 6.25, 4.25, 2.0 }, { 0, 3.0, -3.3, 3.2 } } do
		local z = zone("Alarm" .. i, 0.2, 0.2, 0.2, CFrame.new(p[1], p[2], p[3]))
		emitter(z, "Flash", {
			Texture = IDS.VaultAlarm, LightEmission = 1, LightInfluence = 0, Rate = 0, LockedToPart = true,
			Lifetime = NumberRange.new(0.45), Speed = NumberRange.new(0),
			Size = ns({ { 0, p[4] * 0.6 }, { 1, p[4] } }), Transparency = ns({ { 0, 0.2 }, { 1, 1 } }), ZOffset = 0.5,
		})
		local l = Instance.new("PointLight"); l.Name = "Light"; l.Color = RED; l.Range = 12; l.Brightness = 1; l.Parent = z
	end
	-- pièces d'or qui sautent pendant la course : éteintes
	local coinPoint = point(vault.Belt, "RunBurstPoint", vault.Belt.UsePoint.WorldPosition + Vector3.new(0, 0.2, 0.6))
	emitter(coinPoint, "RunCoins", {
		Texture = IDS.CashCoin, LightInfluence = 0.5, Rate = 7, Lifetime = NumberRange.new(0.9, 1.3),
		Speed = NumberRange.new(5, 7), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(30, 30),
		Acceleration = Vector3.new(0, -18, 0), Size = ns({ { 0, 0.35 }, { 1, 0.3 } }), Enabled = false,
		Squash = ns({ { 0, 0 }, { 0.15, 1.6 }, { 0.3, 0 }, { 0.45, 1.6 }, { 0.6, 0 }, { 0.75, 1.6 }, { 0.9, 0 }, { 1, 1.6 } }),
	})
	table.insert(report, "PLOT_Treadmill_LaserVault : 9 lasers avec étincelles, laser de porte, 2 caméras, 3 alarmes (Emit par le code), RunCoins éteint")
end
-- Toxic Gothic : version sans script de ToxicGothicTreadmill.lua (Clément), même repère (K = 1). Les chauves-souris
-- du script tournent en BillboardGui animé ; ici, ce sont des particules (flipbook 2x2) qui voltigent autour de
-- l'arche. Pour le code : pulsation de ToxicGoo (7CFF2E vers EAFFC8) et de ToxicFX.GooLight.Light (1,5 à 2,1),
-- clignotement de BeltArrows (plus rapide en course), vacillement des ToxicFX.LanternN.Light (1,3 ± 0,4),
-- défilement de BeltTexture, et pendant la course ToxicFX.RunTrail copié sur le coureur et RunSplash allumé.
local toxic = plots:FindFirstChild("PLOT_Treadmill_Toxic")
if toxic then
	local LIME, ACID = Color3.fromHex("7CFF2E"), Color3.fromHex("B6FF3B")
	local old = toxic:FindFirstChild("ToxicFX")
	if old then old:Destroy() end
	local fx = Instance.new("Folder")
	fx.Name = "ToxicFX"
	fx.Parent = toxic
	local function zone(name, sx, sy, sz, x, y, z)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = Vector3.new(sx, sy, sz)
		p.CFrame = CFrame.new(x, y, z)
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Transparency = 1
		p.Parent = fx
		return p
	end
	local function fumeProps(rate, s0, s1)
		return {
			Texture = IDS.ToxicFume, LightInfluence = 0.4, LightEmission = 0.2,
			Color = ColorSequence.new(Color3.fromRGB(160, 240, 110), Color3.fromRGB(70, 140, 50)),
			Rate = rate, Lifetime = NumberRange.new(2.5, 3.5), Speed = NumberRange.new(0.5, 0.9), EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(15, 15), RotSpeed = NumberRange.new(-20, 20),
			Size = ns({ { 0, s0 }, { 1, s1 } }), Transparency = ns({ { 0, 1 }, { 0.25, 0.45 }, { 1, 1 } }), Shape = Enum.ParticleEmitterShape.Box,
		}
	end
	-- lanternes : flamme verte et lumière
	for i, x in { -1.1, 1.1 } do
		local z = zone("Lantern" .. i, 0.2, 0.1, 0.2, x, 5.28, -4.0)
		emitter(z, "Flame", {
			Texture = IDS.ToxicFlame, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = Enum.ParticleFlipbookMode.Loop,
			FlipbookFramerate = NumberRange.new(16), FlipbookStartRandom = true, Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
			LightEmission = 0.6, LightInfluence = 0, Rate = 8, Lifetime = NumberRange.new(0.4, 0.6), Speed = NumberRange.new(0.2, 0.4),
			EmissionDirection = Enum.NormalId.Top, Size = ns({ { 0, 0.3 }, { 0.4, 0.4 }, { 1, 0.15 } }), Transparency = ns({ { 0, 0.1 }, { 0.8, 0.2 }, { 1, 1 } }),
		})
		local l = Instance.new("PointLight"); l.Name = "Light"; l.Color = ACID; l.Range = 9; l.Brightness = 1.6; l.Parent = z
	end
	-- bulles qui éclatent : flaque, bouche du baril, console, tombe
	for _, b in { { "PuddleBubbles", 1.1, 0.6, 1.34, 1.3, 3.85, 6 }, { "MouthBubbles", 0.25, 0.25, 1.12, 2.75, 3.85, 3 },
		{ "ConsoleBubbles", 0.4, 0.3, 0, 4.7, -3.42, 1.5 }, { "GraveBubbles", 0.5, 0.25, -1.6, 1.3, 3.6, 1.5 } } do
		emitter(zone(b[1], b[2], 0.1, b[3], b[4], b[5], b[6]), "Bubble", {
			Texture = IDS.ToxicBubble, LightEmission = 0.4, LightInfluence = 0.3, Rate = b[7],
			Lifetime = NumberRange.new(0.6, 1.2), Speed = NumberRange.new(0.05, 0.2), EmissionDirection = Enum.NormalId.Top,
			Size = ns({ { 0, 0 }, { 0.85, 0.3 }, { 0.9, 0.36 }, { 1, 0 } }), Shape = Enum.ParticleEmitterShape.Box,
		})
	end
	-- gouttes qui tombent : coulures des rails, barils, arche
	local DRIPS = {
		{ 2.21, 0.53, -2.6 }, { 2.21, 0.73, -1.6 }, { 2.21, 0.33, -0.6 }, { 2.21, 0.68, 0.6 }, { 2.21, 0.63, 1.4 }, { 2.21, 0.48, 2.7 },
		{ -2.21, 0.48, -2.0 }, { -2.21, 0.68, -1.0 }, { -2.21, 0.58, 0.2 }, { -2.21, 0.73, 1.1 }, { -2.21, 0.38, 2.0 }, { -2.21, 0.63, 3.0 },
		{ 0, 6.2, -4.01 }, { -0.83, 6.0, -4.01 }, { 1.86, 5.08, -3.67 }, { -1.86, 4.73, -3.67 }, { 0.08, 4.09, -3.15 },
		{ 0.97, 1.88, 4.02 }, { 0.92, 2.06, 3.59 }, { 1.17, 1.3, 3.85 },
	}
	for i, d in DRIPS do
		emitter(zone("Drip" .. i, 0.1, 0.05, 0.1, d[1], d[2], d[3]), "Drip", {
			Texture = IDS.ToxicDrip, LightEmission = 0.5, LightInfluence = 0.2, Rate = 0.8 + (i % 3) * 0.3,
			Lifetime = NumberRange.new(0.5, 0.7), Speed = NumberRange.new(0), Acceleration = Vector3.new(0, -30, 0),
			Size = ns({ { 0, 0.14 }, { 1, 0.14 } }), Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
		})
	end
	-- fumées toxiques au-dessus des barils, petites fumées, lumière du slime
	emitter(zone("Fumes", 1.6, 0.2, 0.6, 0.4, 3.55, 3.85), "Fume", fumeProps(4, 0.8, 2.4))
	for i, p in { { 0, 4.75, -3.42, 0.4 }, { 2.2, 1.25, -0.6, 0.3 }, { -2.2, 1.25, 2.0, 0.3 } } do
		emitter(zone("SmallFume" .. i, p[4], 0.1, p[4], p[1], p[2], p[3]), "Fume", fumeProps(1.2, 0.4, 1.4))
	end
	local gl = Instance.new("PointLight"); gl.Name = "Light"; gl.Color = LIME; gl.Range = 10; gl.Brightness = 1.8
	gl.Parent = zone("GooLight", 0.2, 0.2, 0.2, 0.9, 2.2, 3.2)
	-- brume toxique qui rampe au sol
	emitter(zone("ToxicMist", 4.6, 0.3, 8.7, 0, 0.2, 0), "Mist", {
		Texture = IDS.ToxicFume, LightInfluence = 0.3, LightEmission = 0.25,
		Color = ColorSequence.new(Color3.fromRGB(190, 255, 150), Color3.fromRGB(90, 170, 60)),
		Rate = 9, Lifetime = NumberRange.new(3, 4.5), Speed = NumberRange.new(0.3, 0.7), EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(85, 85), Acceleration = Vector3.new(0, -0.3, 0), Drag = 1,
		Size = ns({ { 0, 1.4 }, { 1, 3 } }), Transparency = ns({ { 0, 1 }, { 0.3, 0.6 }, { 1, 1 } }), Shape = Enum.ParticleEmitterShape.Box,
	})
	-- spores qui flottent sur tout le tapis
	emitter(zone("Spores", 4.4, 6, 8.4, 0, 3.3, 0), "Spore", {
		Texture = IDS.ToxicGlow, LightEmission = 1, LightInfluence = 0, Color = ColorSequence.new(LIME, ACID),
		Rate = 10, Lifetime = NumberRange.new(3, 5), Speed = NumberRange.new(0.2, 0.5), EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(25, 25), Size = ns({ { 0, 0 }, { 0.2, 0.12 }, { 1, 0 } }),
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	})
	-- lueur verte au sol
	local halo = zone("GooGlow", 7, 0.05, 11, 0, 0.02, 0)
	local hd = Instance.new("Decal"); hd.Name = "Glow"; hd.Texture = IDS.ToxicGlow; hd.Face = Enum.NormalId.Top; hd.Transparency = 0.5; hd.Parent = halo
	-- chauves-souris : particules qui battent des ailes et voltigent autour de l'arche et au-dessus du tapis
	local function bats(name, sx, sy, sz, x, y, z, rate)
		emitter(zone(name, sx, sy, sz, x, y, z), "Bat", {
			Texture = IDS.ToxicBat, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2, FlipbookMode = Enum.ParticleFlipbookMode.Loop,
			FlipbookFramerate = NumberRange.new(10, 14), FlipbookStartRandom = true, LightInfluence = 0.2,
			Rate = rate, Lifetime = NumberRange.new(5, 7), Speed = NumberRange.new(0.4, 0.9), SpreadAngle = Vector2.new(180, 180),
			Drag = 0.3, Rotation = NumberRange.new(-14, 14), RotSpeed = NumberRange.new(-10, 10),
			Size = ns({ { 0, 1.3 }, { 1, 1.3 } }), Transparency = ns({ { 0, 1 }, { 0.1, 0 }, { 0.9, 0 }, { 1, 1 } }),
			Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		})
	end
	bats("BatsArch", 3.5, 1.2, 1.5, 0, 6.9, -4, 0.7)
	bats("BatsRoam", 6, 2.5, 9, 0, 4.8, 0, 0.45)
	-- traînée de slime du coureur : modèle éteint, que le code copie sur le personnage avec ses attaches
	local tz = zone("RunTrail", 0.2, 0.2, 0.2, 0, 1.0, 0.3)
	local t0 = Instance.new("Attachment"); t0.Name = "GooTrail0"; t0.Position = Vector3.new(-0.6, 0, 0); t0.Parent = tz
	local t1 = Instance.new("Attachment"); t1.Name = "GooTrail1"; t1.Position = Vector3.new(0.6, 0, 0); t1.Parent = tz
	local trail = Instance.new("Trail"); trail.Name = "Trail"; trail.Attachment0, trail.Attachment1 = t0, t1
	trail.Texture = IDS.ToxicTrail; trail.TextureMode = Enum.TextureMode.Wrap; trail.TextureLength = 2; trail.Lifetime = 0.4
	trail.LightEmission = 0.6; trail.LightInfluence = 0.2; trail.FaceCamera = false; trail.Enabled = false
	trail.Transparency = ns({ { 0, 0.1 }, { 1, 1 } }); trail.WidthScale = ns({ { 0, 1 }, { 1, 0.3 } }); trail.Parent = tz
	-- éclaboussures aux pieds : éteintes, le code les allume pendant la course
	local burstPoint = point(toxic.Belt, "RunBurstPoint", toxic.Belt.UsePoint.WorldPosition + Vector3.new(0, 0.2, 0.3))
	emitter(burstPoint, "RunSplash", {
		Texture = IDS.ToxicDrip, LightEmission = 0.5, Rate = 14, Lifetime = NumberRange.new(0.3, 0.5),
		Speed = NumberRange.new(3, 5), EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(40, 25),
		Acceleration = Vector3.new(0, -20, 0), Size = ns({ { 0, 0.2 }, { 1, 0.1 } }), Enabled = false,
	})
	table.insert(report, "PLOT_Treadmill_Toxic : 2 lanternes, 4 bulles, 20 gouttes, fumées, brume, spores, chauves-souris, lueur au sol, RunTrail et RunSplash éteints")
end
-- Candy : version sans script de CandyTreadmill.lua (Clément), même repère (K = 1). Pour le code : rotation de
-- Peppermint et PeppermintSwirl autour de l'axe avant-arrière (centre (0, 2,45, -3,1), 0,6 rad/s au repos et
-- 2,5 en course, sens horaire), pulsation de CandyGlow (FF4FA3 vers blanc, 0,3·pulse, sinus 2,6 rad/s) et de
-- CandyFX.SprinkleArch.Light (1,2 à 1,8), clignotement de BeltArrows (FFD6EA vers FF4FA3, 6 rad/s au repos et 12 en
-- course), Emit des CandyFX.PopperN.Pop (18 au repos, 30 en course, un popper au hasard toutes les 0,9 à 1,5 s ;
-- 0,4 à 1 s en course), défilement de BeltTexture (sens inverse des autres tapis), et pendant la course RunPops et
-- RunPuff allumés et CandyFX.RunTrail copié sur le coureur.
local candy = plots:FindFirstChild("PLOT_Treadmill_Candy")
if candy then
	local PINK = Color3.fromHex("FF4FA3")
	local old = candy:FindFirstChild("CandyFX")
	if old then old:Destroy() end
	local fx = Instance.new("Folder")
	fx.Name = "CandyFX"
	fx.Parent = candy
	local function zone(name, sx, sy, sz, x, y, z)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = Vector3.new(sx, sy, sz)
		p.CFrame = CFrame.new(x, y, z)
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Transparency = 1
		p.Parent = fx
		return p
	end
	candy.Belt.BeltTexture.Texture = IDS.CandyBelt
	-- pluie de vermicelles depuis l'arche, et lumière rose
	local arch = zone("SprinkleArch", 2.6, 0.2, 0.8, 0, 7.4, 3.9)
	emitter(arch, "Sprinkles", {
		Texture = IDS.CandySprinkles, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2, FlipbookMode = Enum.ParticleFlipbookMode.Random,
		LightInfluence = 0.4, Rate = 6, Lifetime = NumberRange.new(3, 4), Speed = NumberRange.new(0.5, 1),
		EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(20, 20), Acceleration = Vector3.new(0, -1.5, 0),
		RotSpeed = NumberRange.new(-90, 90), Rotation = NumberRange.new(0, 360), Size = ns({ { 0, 0.5 }, { 1, 0.5 } }),
		Shape = Enum.ParticleEmitterShape.Box,
	})
	local al = Instance.new("PointLight"); al.Name = "Light"; al.Color = PINK; al.Range = 12; al.Brightness = 1.5; al.Parent = arch
	-- scintillements : arche, sucettes, menthe
	for i, c in { { 0, 7.3, 3.9, 2.8, 0.6, 0.6 }, { -1.05, 5.5, -3.5, 0.9, 0.9, 0.3 }, { 1.05, 5.5, -3.5, 0.9, 0.9, 0.3 }, { 0, 2.45, -2.95, 2.2, 2.2, 0.2 } } do
		emitter(zone("Sparkle" .. i, c[4], c[5], c[6], c[1], c[2], c[3]), "Sparkle", {
			Texture = IDS.CandySparkle, LightEmission = 1, LightInfluence = 0, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(255, 180, 220)),
			Rate = i == 1 and 5 or 2.5, Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(0),
			Size = ns({ { 0, 0 }, { 0.5, 0.5 }, { 1, 0 } }), RotSpeed = NumberRange.new(-120, 120),
			Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		})
	end
	-- barbe à papa autour des crosses et sur deux piliers
	for i, c in { { -1.25, 7.3, 3.9, 2.0 }, { 1.3, 7.35, 3.9, 1.9 }, { 0, 7.75, 3.95, 1.6 }, { -1.95, 3.2, -2.65, 1.2 }, { 1.95, 3.1, 3.95, 1.2 } } do
		emitter(zone("Cotton" .. i, 0.4, 0.3, 0.3, c[1], c[2], c[3]), "Cotton", {
			Texture = IDS.CandyCotton, LightInfluence = 0.3, LightEmission = 0.15, Rate = 1.5, Lifetime = NumberRange.new(2.5, 3.5),
			Speed = NumberRange.new(0.05, 0.15), SpreadAngle = Vector2.new(180, 180), RotSpeed = NumberRange.new(-10, 10),
			Size = ns({ { 0, c[4] * 0.7 }, { 0.5, c[4] }, { 1, c[4] * 0.8 } }), Transparency = ns({ { 0, 1 }, { 0.25, 0.2 }, { 0.75, 0.25 }, { 1, 1 } }),
		})
	end
	-- pluie de bonbons emballés le long des deux rails
	for i, x in { -1.95, 1.95 } do
		emitter(zone("CandyRain" .. i, 0.5, 0.2, 6.8, x, 6.5, 0.4), "Candy", {
			Texture = IDS.CandyWrapped, LightInfluence = 0.5, Rate = 2, Lifetime = NumberRange.new(4, 5),
			Speed = NumberRange.new(0.6, 1.1), EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(5, 5),
			RotSpeed = NumberRange.new(-150, 150), Rotation = NumberRange.new(0, 360), Size = ns({ { 0, 0.42 }, { 0.9, 0.42 }, { 1, 0 } }),
			Shape = Enum.ParticleEmitterShape.Box,
		})
	end
	-- poppers : explosions de vermicelles (Rate 0, le code appelle Emit)
	for i, p in { { -1.96, 2.8, -2.65 }, { 1.96, 2.8, -2.65 }, { -1.96, 2.8, 3.95 }, { 1.96, 2.8, 3.95 }, { -1.95, 2.6, 0.05 }, { 1.95, 2.6, 0.05 } } do
		emitter(zone("Popper" .. i, 0.2, 0.2, 0.2, p[1], p[2], p[3]), "Pop", {
			Texture = IDS.CandySprinkles, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2, FlipbookMode = Enum.ParticleFlipbookMode.Random,
			LightInfluence = 0.4, Rate = 0, Lifetime = NumberRange.new(0.8, 1.3), Speed = NumberRange.new(3, 5),
			EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(45, 45), Acceleration = Vector3.new(0, -12, 0),
			RotSpeed = NumberRange.new(-200, 200), Size = ns({ { 0, 0.4 }, { 1, 0.3 } }),
		})
	end
	-- halo rose au sol
	local halo = zone("CandyGlowGround", 7, 0.05, 11, 0, 0.02, 0)
	local hd = Instance.new("Decal"); hd.Name = "Glow"; hd.Texture = IDS.CandyGlow; hd.Face = Enum.NormalId.Top; hd.Transparency = 0.5; hd.Parent = halo
	-- traînée sucre d'orge du coureur : modèle éteint, que le code copie sur le personnage avec ses attaches
	local tz = zone("RunTrail", 0.2, 0.2, 0.2, 0, 2.0, 0.4)
	local t0 = Instance.new("Attachment"); t0.Name = "CandyTrail0"; t0.Position = Vector3.new(-0.8, 0, 0); t0.Parent = tz
	local t1 = Instance.new("Attachment"); t1.Name = "CandyTrail1"; t1.Position = Vector3.new(0.8, 0, 0); t1.Parent = tz
	local trail = Instance.new("Trail"); trail.Name = "Trail"; trail.Attachment0, trail.Attachment1 = t0, t1
	trail.Texture = IDS.CandyTrail; trail.TextureMode = Enum.TextureMode.Wrap; trail.TextureLength = 2; trail.Lifetime = 0.35
	trail.LightInfluence = 0.3; trail.FaceCamera = true; trail.Transparency = ns({ { 0, 0.1 }, { 1, 1 } }); trail.Enabled = false
	trail.Parent = tz
	-- bonbons qui sautent et nuage de sucre aux pieds : éteints, le code les allume pendant la course
	local feet = point(candy.Belt, "RunBurstPoint", candy.Belt.UsePoint.WorldPosition + Vector3.new(0, 0.2, 0.4))
	emitter(feet, "RunPops", {
		Texture = IDS.CandyWrapped, LightInfluence = 0.5, Rate = 5, Lifetime = NumberRange.new(0.9, 1.3),
		Speed = NumberRange.new(5, 7), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(35, 35),
		Acceleration = Vector3.new(0, -18, 0), RotSpeed = NumberRange.new(-200, 200), Size = ns({ { 0, 0.5 }, { 1, 0.45 } }), Enabled = false,
	})
	emitter(feet, "RunPuff", {
		Texture = IDS.CandyPuff, LightInfluence = 0.5, Rate = 10, Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(1, 2), EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(40, 20),
		Size = ns({ { 0, 0.6 }, { 1, 1.6 } }), Transparency = ns({ { 0, 0.3 }, { 1, 1 } }), Enabled = false,
	})
	table.insert(report, "PLOT_Treadmill_Candy : vermicelles de l'arche, 4 scintillements, 5 barbes à papa, 2 pluies de bonbons, 6 poppers (Emit par le code), halo, RunTrail/RunPops/RunPuff éteints")
end
local missing = {}
for k, v in IDS do if v == "rbxassetid://0" then table.insert(missing, k) end end
table.insert(report, #missing == 0 and "toutes les images sont branchées" or ("images manquantes : " .. table.concat(missing, ", ")))
return table.concat(report, "\n")
