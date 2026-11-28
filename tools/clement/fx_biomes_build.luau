-- Effets d'ambiance des zones à venir (28/11, chef VFX et son ; biomes validés par Clément « Oui, sauf la nuit »).
-- Fiches du chef DA : da-fiche-z5-paris.md, da-fiche-z6-newyork.md, da-fiche-z1-banlieue.md.
-- À coller en Edit ; relançable (le dossier est refait à neuf). Construit dans ServerStorage/_PREVIEW_FX_BIOMES,
-- jamais dans la Map : c'est le chef Map qui pose. Aucun script : ParticleEmitter natifs seulement.
-- Chaque effet est une Part invisible (ou un petit modèle) déjà à sa place dans le monde ; l'attribut PoserA dit où
-- la mettre, l'attribut Remplace ce qu'elle remplace, l'attribut Vivantes le nombre de particules vivantes.
-- Textures : nos dessins toon (StealAShop-Art/FX/Biomes, générateur _src/biomes_textures.py). Une texture pas encore
-- publiée ne se voit que sur ce PC (rbxasset://textures/StealAShopFX/Biomes1/...) ; après publication, mettre son
-- ImageId (fx_ids.csv) dans TEX et relancer.
local SS = game:GetService("ServerStorage")

local TEX = { -- ImageId de StealAShop-Art/FX/Biomes/fx_ids.csv (publiés au nom du groupe le 28/11)
	Leaf = "rbxassetid://95517283363067",
	Snow = "rbxassetid://85391979284868",
	Steam = "rbxassetid://77661867661741",
	Butterfly = "rbxassetid://98111223308610",
	Drop = "rbxassetid://123152531271193",
	RainRing = "rbxassetid://86122272750656",
	RainStreak = "rbxasset://textures/StealAShopFX/Biomes2/FX_Biome_RainStreak.png", -- pluie non retenue : aperçu local seulement (Decal publié 88506082830925, pas utilisé)
}

local old = SS:FindFirstChild("_PREVIEW_FX_BIOMES")
if old then old:Destroy() end
local root = Instance.new("Folder")
root.Name = "_PREVIEW_FX_BIOMES"
root:SetAttribute("Auteur", "Chef VFX et son, 28/11")
root:SetAttribute("Note", "Effets d'ambiance à poser par le chef Map. Rien ici n'est lu par le jeu. Script : tools/clement/fx_biomes_build.luau")

local function folder(name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = root
	return f
end

local function anchor(name: string, size: Vector3, pos: Vector3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = CFrame.new(pos)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Transparency = 1
	p.Locked = false
	p.Parent = parent
	return p
end

local function seq(points: { { number } }): NumberSequence
	local kps = {}
	for _, v in points do table.insert(kps, NumberSequenceKeypoint.new(v[1], v[2], v[3] or 0)) end
	return NumberSequence.new(kps)
end

local function cseq(points: { { any } }): ColorSequence
	local kps = {}
	for _, v in points do table.insert(kps, ColorSequenceKeypoint.new(v[1], v[2])) end
	return ColorSequence.new(kps)
end

-- Squash qui ondule : la feuille ou le flocon se balance (recette des confettis du kit Top Donators, plus lente)
local function flutter(amp: number, n: number): NumberSequence
	local pts = {}
	for i = 0, n - 1 do
		local t = i / (n - 1)
		table.insert(pts, { t, (i % 2 == 0) and amp or -amp })
	end
	return seq(pts)
end

local function emitter(parent: Instance, name: string, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.LightInfluence = 1
	e.LightEmission = 0
	e.Brightness = 1
	e.ZOffset = 0
	for k, v in props do (e :: any)[k] = v end
	e.Parent = parent
	return e
end

local function alive(e: ParticleEmitter): number
	return e.Rate * (e.Lifetime.Min + e.Lifetime.Max) / 2
end

local report = {}
local function note(p: Instance, poserA: string, remplace: string?)
	local n = 0
	for _, d in p:GetDescendants() do if d:IsA("ParticleEmitter") then n += alive(d) end end
	p:SetAttribute("PoserA", poserA)
	if remplace then p:SetAttribute("Remplace", remplace) end
	p:SetAttribute("Vivantes", math.floor(n * 10 + 0.5) / 10)
	table.insert(report, string.format("%s : %.1f vivantes", p:GetFullName(), n))
end

---------------------------------------------------------------- Zone 5, Paris en automne
local z5 = folder("Z5_Paris")
local LEAF_COLOR = cseq({ { 0, Color3.fromRGB(224, 160, 48) }, { 0.5, Color3.fromRGB(224, 122, 47) }, { 1, Color3.fromRGB(178, 80, 42) } })
-- la couleur change avec l'âge : à l'écran, des feuilles or, orange et rouille en même temps, avec un seul émetteur
local function leafProps(extra: { [string]: any }): { [string]: any }
	local p = {
		Texture = TEX.Leaf,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2,
		FlipbookMode = Enum.ParticleFlipbookMode.PingPong, -- face, trois-quarts, tranche, revers, et retour : elle tourne
		FlipbookFramerate = NumberRange.new(5, 9),
		FlipbookStartRandom = true,
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Color = LEAF_COLOR,
		Size = seq({ { 0, 1.1, 0.2 }, { 1, 1.1, 0.2 } }), -- 1,1 stud : plus petites, elles ne se lisaient pas depuis la chaussée (vu le 28/11)
		Squash = flutter(0.35, 18),
		Transparency = seq({ { 0, 1 }, { 0.05, 0 }, { 0.9, 0 }, { 1, 1 } }),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-90, 90),
		LightInfluence = 0.85,
	}
	for k, v in extra do p[k] = v end
	return p
end

do -- feuilles qui tombent sur toute la rue (remplace la neige)
	local p = anchor("FX_Z5_FeuillesRue", Vector3.new(188, 1, 100), Vector3.new(624, 13, 0), z5)
	emitter(p, "Leaves", leafProps({
		Rate = 14, -- vu le 28/11 : à 4,5, une dizaine à l'écran ; à 14, environ 25
		Lifetime = NumberRange.new(7, 8),
		EmissionDirection = Enum.NormalId.Bottom,
		Speed = NumberRange.new(0.5, 1.5),
		SpreadAngle = Vector2.new(30, 30),
		Drag = 1.2,
		Acceleration = Vector3.new(0.6, -2, 0.3), -- un peu de vent vers l'est (la vitesse limite ≈ 1,7 stud/s)
	}))
	note(p, "Workspace/Map/Zone_5/Street_Paris/Weather, à la place de SnowCloud : x 530 à 718, |z| < 50, y 13 (sous le feuillage des marronniers)",
		"Street_Paris/Weather/SnowCloud (Snowfall + SnowGlitter : environ 1 400 particules vivantes)")
end

do -- quelques feuilles de plus sous un arbre isolé (jardin, cour) : gabarit à copier
	local p = anchor("FX_Z5_FeuillesArbre", Vector3.new(10, 1, 10), Vector3.new(538, 14, 151), z5)
	emitter(p, "Leaves", leafProps({
		Rate = 0.35,
		Lifetime = NumberRange.new(6, 8),
		EmissionDirection = Enum.NormalId.Bottom,
		Speed = NumberRange.new(0.5, 1.2),
		SpreadAngle = Vector2.new(30, 30),
		Drag = 1.2,
		Acceleration = Vector3.new(0.6, -2, 0.3),
	}))
	note(p, "Facultatif : une copie sous le feuillage de quelques arbres du jardin (Garden/Tree_*), 4 studs sous le haut de l'arbre ; 6 copies au plus")
end

do -- tas de feuilles qui frémissent : une feuille saute du tas de temps en temps et retombe
	local p = anchor("FX_Z5_TasFeuilles", Vector3.new(4, 0.2, 3), Vector3.new(560, 0.6, 52), z5)
	emitter(p, "Hop", leafProps({
		Rate = 0.6,
		Lifetime = NumberRange.new(0.9, 1.3),
		EmissionDirection = Enum.NormalId.Top,
		Speed = NumberRange.new(2.5, 4),
		SpreadAngle = Vector2.new(35, 35),
		Drag = 0.8,
		Acceleration = Vector3.new(0.4, -9, 0),
		FlipbookFramerate = NumberRange.new(10, 14),
		RotSpeed = NumberRange.new(-200, 200),
		Size = seq({ { 0, 0.8, 0.12 }, { 1, 0.8, 0.12 } }),
		Squash = seq({ { 0, 0 }, { 1, 0 } }),
		Transparency = seq({ { 0, 1 }, { 0.1, 0 }, { 0.85, 0 }, { 1, 1 } }),
	}))
	note(p, "Une copie sur le dessus de chaque tas de feuilles (Street_Paris/Ground, au pied des arbres et le long des trottoirs), à la taille du tas ; 12 copies au plus")
end

---------------------------------------------------------------- Zone 6, New York, neige au crépuscule
local z6 = folder("Z6_NewYork")
local SNOW_COLOR = cseq({ { 0, Color3.fromRGB(242, 247, 255) }, { 1, Color3.fromRGB(230, 238, 252) } })
local function snowProps(extra: { [string]: any }): { [string]: any }
	local p = {
		Texture = TEX.Snow,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2,
		FlipbookMode = Enum.ParticleFlipbookMode.Loop,
		FlipbookFramerate = NumberRange.new(0, 0), -- une image fixe tirée au hasard par flocon
		FlipbookStartRandom = true,
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Color = SNOW_COLOR,
		EmissionDirection = Enum.NormalId.Bottom,
		Rotation = NumberRange.new(-180, 180),
		RotSpeed = NumberRange.new(-40, 40),
		LightEmission = 0.15, -- lisible au crépuscule sans briller
		LightInfluence = 0.3, -- à 0,6, le ColorShift rose de la map les teintait
		Transparency = seq({ { 0, 1 }, { 0.08, 0 }, { 0.92, 0 }, { 1, 1 } }),
	}
	for k, v in extra do p[k] = v end
	return p
end

do -- neige plus épaisse au-dessus du couloir seulement
	-- « épaisse » par des flocons plus gros et une couche de gros flocons ; la neige d'aujourd'hui fait environ 480
	-- particules vivantes. Elle part de 30 studs (au lieu de 55) : même densité vue de la rue pour une durée de vie
	-- deux fois plus courte (environ 170 vivantes, environ 45 à l'écran depuis la chaussée, compté le 28/11).
	local p = anchor("FX_Z6_NeigeCouloir", Vector3.new(125, 1, 110), Vector3.new(780.5, 30, 0), z6)
	emitter(p, "Snow", snowProps({
		Rate = 15, -- vu le 28/11 : à 8, une quinzaine à l'écran ; à 15, environ 40 (18 avant les flocons qui se posent)
		Lifetime = NumberRange.new(7, 8),
		Speed = NumberRange.new(3.5, 4.5),
		SpreadAngle = Vector2.new(10, 10),
		Acceleration = Vector3.new(0.4, 0, 0.1),
		Size = seq({ { 0, 0.48, 0.12 }, { 1, 0.48, 0.12 } }),
		Squash = flutter(0.12, 12),
	}))
	emitter(p, "SnowBig", snowProps({
		Rate = 4,
		Lifetime = NumberRange.new(8, 9.5),
		Speed = NumberRange.new(3, 3.6),
		SpreadAngle = Vector2.new(10, 10),
		Acceleration = Vector3.new(0.3, 0, 0),
		Size = seq({ { 0, 0.95, 0.15 }, { 1, 0.95, 0.15 } }),
		Transparency = seq({ { 0, 1 }, { 0.1, 0.15 }, { 0.9, 0.15 }, { 1, 1 } }),
	}))
	note(p, "Workspace/Map/Zone_6/Ambience_NewYork/Snowfall, à la place des 6 SnowArea_* : x 718 à 843 (s'arrête avant le coffre, x 843), |z| < 55 (chaussée et trottoirs, pas les magasins), y 30",
		"Ambience_NewYork/Snowfall/SnowArea_* (6 parts, environ 480 particules vivantes)")
end

do -- gros flocons au loin, derrière le coffre, qui fondent avant les toits : ils bouchent un peu le fond
	local p = anchor("FX_Z6_NeigeFond", Vector3.new(12, 1, 120), Vector3.new(876, 70, 0), z6)
	emitter(p, "SnowFar", snowProps({
		Rate = 2,
		Lifetime = NumberRange.new(8, 9),
		Speed = NumberRange.new(3.5, 4.2),
		SpreadAngle = Vector2.new(8, 8),
		Size = seq({ { 0, 1.5, 0.3 }, { 1, 1.5, 0.3 } }),
		LightInfluence = 0.25,
		Transparency = seq({ { 0, 1 }, { 0.12, 0.2 }, { 0.75, 0.25 }, { 1, 1 } }), -- disparus vers y 35, jamais sur le coffre
	}))
	note(p, "Workspace/Map/Zone_6/Ambience_NewYork : x 870 à 882 (entre le coffre et la tour du fond, hors de l'emprise du coffre x 843 à 869), |z| < 60, y 70")
end

local STEAM_COLOR = cseq({ { 0, Color3.fromRGB(238, 242, 250) }, { 1, Color3.fromRGB(214, 222, 236) } })
local function steamProps(extra: { [string]: any }): { [string]: any }
	local p = {
		Texture = TEX.Steam,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot, -- la bouffée grossit puis se défait
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Color = STEAM_COLOR,
		EmissionDirection = Enum.NormalId.Top,
		Rotation = NumberRange.new(-180, 180),
		RotSpeed = NumberRange.new(-20, 20),
		LightEmission = 0.1,
		LightInfluence = 0.25, -- à 0,6, la vapeur sortait rose (ColorShift_Top de la map)
		Transparency = seq({ { 0, 1 }, { 0.08, 0.05 }, { 0.6, 0.2 }, { 1, 1 } }),
	}
	for k, v in extra do p[k] = v end
	return p
end

do -- cheminée rayée orange et blanc : la colonne de vapeur (5 copies)
	local m = Instance.new("Model")
	m.Name = "FX_Z6_VapeurCheminee"
	m.Parent = z6
	local p = anchor("Anchor", Vector3.new(1.5, 0.2, 1.5), Vector3.new(741.5, 8.2, -48.75), m)
	m.PrimaryPart = p
	local a = Instance.new("Attachment")
	a.Name = "Steam"
	a.Parent = p
	emitter(a, "Steam", steamProps({
		Rate = 3,
		Lifetime = NumberRange.new(2.2, 2.8),
		Speed = NumberRange.new(6, 8),
		SpreadAngle = Vector2.new(8, 8),
		Drag = 1.2,
		Acceleration = Vector3.new(0.8, 1.2, 0),
		Size = seq({ { 0, 0.6 }, { 0.5, 2 }, { 1, 3.2 } }),
	}))
	note(m, "Sur le haut de chacune des 5 cheminées rayées (Street_NewYork/Props/SteamStack et ses copies), au milieu de la chaussée : Anchor posé au ras du rebord (Rim). Ici, calé sur le SteamStack actuel",
		"le Steam (smoke_main) sous SteamStack/Rim")
end

do -- bouche d'égout au sol : vapeur plus basse et plus large (4 bouches actuelles)
	local p = anchor("FX_Z6_VapeurBouche", Vector3.new(3, 0.1, 3), Vector3.new(745, 0.1, -24.5), z6)
	emitter(p, "Steam", steamProps({
		Rate = 2.5,
		Lifetime = NumberRange.new(2, 2.6),
		Speed = NumberRange.new(3, 5),
		SpreadAngle = Vector2.new(20, 20),
		Drag = 1,
		Acceleration = Vector3.new(0.6, 1, 0),
		Size = seq({ { 0, 0.8 }, { 0.5, 2.4 }, { 1, 3.6 } }),
		Transparency = seq({ { 0, 1 }, { 0.1, 0.15 }, { 0.6, 0.35 }, { 1, 1 } }),
	}))
	note(p, "Sur chaque bouche Street_NewYork/Ground/SteamVent_1 à _4, à la place de leur Steam ; ici calé sur SteamVent_1",
		"le Steam (smoke_main) des 4 SteamVent_*")
end

---------------------------------------------------------------- Zone 1, banlieue d'été
local z1 = folder("Z1_Banlieue")

do -- papillons jaunes et blancs au-dessus d'une pelouse (4 copies, une dizaine en tout)
	local p = anchor("FX_Z1_Papillons", Vector3.new(12, 3, 6), Vector3.new(46, 2.9, 51), z1)
	local function butterfly(name: string, color: Color3)
		emitter(p, name, {
			Texture = TEX.Butterfly,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2,
			FlipbookMode = Enum.ParticleFlipbookMode.PingPong, -- les ailes battent
			FlipbookFramerate = NumberRange.new(14, 20),
			FlipbookStartRandom = true,
			Orientation = Enum.ParticleOrientation.FacingCamera,
			Color = cseq({ { 0, color }, { 1, color } }),
			Rate = 0.3,
			Lifetime = NumberRange.new(5, 7),
			Speed = NumberRange.new(0.6, 1.4),
			SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0, 0.05, 0),
			Size = seq({ { 0, 0.85, 0.12 }, { 1, 0.85, 0.12 } }),
			Rotation = NumberRange.new(-25, 25),
			Transparency = seq({ { 0, 1 }, { 0.1, 0 }, { 0.9, 0 }, { 1, 1 } }),
		})
	end
	butterfly("Yellow", Color3.fromRGB(255, 222, 80))
	butterfly("White", Color3.fromRGB(255, 255, 255))
	note(p, "Au-dessus des pelouses, 4 copies : x 46 et 104, z 51 et −51, à 1 à 4 studs du sol, aux bouts des magasins (pas devant la vitrine x 62 à 86)")
end

do -- arroseur de pelouse : petite tête grise et un jet d'eau tout autour (4 copies)
	local m = Instance.new("Model")
	m.Name = "FX_Z1_Arroseur"
	m.Parent = z1
	local base = Instance.new("Part")
	base.Name = "Head"
	base.Size = Vector3.new(0.6, 0.45, 0.6)
	base.Shape = Enum.PartType.Cylinder
	base.CFrame = CFrame.new(45, 0.4 + 0.275, 51) * CFrame.Angles(0, 0, math.rad(90)) -- trottoir à y 0,4
	base.Color = Color3.fromRGB(138, 141, 147)
	base.Material = Enum.Material.Plastic
	base.Anchored = true
	base.CanCollide = false
	base.CanTouch = false
	base.CastShadow = false
	base.Parent = m
	m.PrimaryPart = base
	local a = Instance.new("Attachment")
	a.Name = "Spray"
	a.Parent = base
	a.WorldCFrame = CFrame.new(45, 0.95, 51) -- axe Y vers le haut
	emitter(a, "Drops", {
		Texture = TEX.Drop,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Color = cseq({ { 0, Color3.fromRGB(205, 232, 255) }, { 1, Color3.fromRGB(205, 232, 255) } }),
		Rate = 12,
		Lifetime = NumberRange.new(0.7, 0.85),
		EmissionDirection = Enum.NormalId.Top,
		Speed = NumberRange.new(10.5, 12.5),
		SpreadAngle = Vector2.new(50, 50), -- un jet en gerbe tout autour, qui retombe à 2 à 4 studs
		Acceleration = Vector3.new(0, -28, 0),
		Size = seq({ { 0, 0.38 }, { 1, 0.3 } }),
		LightEmission = 0.1,
		LightInfluence = 0.4,
		Transparency = seq({ { 0, 0.2 }, { 0.85, 0.2 }, { 1, 1 } }),
	})
	emitter(a, "Mist", steamProps({
		Color = cseq({ { 0, Color3.fromRGB(222, 240, 255) }, { 1, Color3.fromRGB(222, 240, 255) } }),
		Rate = 2,
		Lifetime = NumberRange.new(0.7, 0.9),
		Speed = NumberRange.new(2, 3),
		SpreadAngle = Vector2.new(40, 40),
		Drag = 2,
		Acceleration = Vector3.new(0, -1, 0),
		Size = seq({ { 0, 0.7 }, { 1, 1.8 } }),
		LightInfluence = 1,
		Transparency = seq({ { 0, 1 }, { 0.15, 0.55 }, { 1, 1 } }),
	}))
	note(m, "Dans les pelouses, 4 copies : x 45 et 104, z 51 et −51, hors de la vitrine (x 62 à 86), des portes (x 90 à 98 au nord, 50 à 58 au sud) et des pots (x 40 et 108) ; façades à |z| 54,75. Head posé sur l'herbe. La tête ne tourne pas (il faudrait un script) : le jet part tout autour")
end

---------------------------------------------------------------- Zone 6 : la neige se pose, la poudre sous les pieds (28/11)
do -- quelques flocons qui finissent au sol et y restent un moment avant de fondre
	-- Sans script, une particule ne s'arrête pas sur une pièce : on la fait naître 0,7 stud au-dessus du sol avec une
	-- vitesse que le Drag éteint en 0,69 stud (distance = vitesse / (Drag × ln 2)). Elle se pose donc au ras du sol,
	-- reste 2 à 3 s et fond. Avec la neige qui tombe au-dessus, l'œil lit « des flocons qui se posent ».
	local m = Instance.new("Model")
	m.Name = "FX_Z6_NeigeSePose"
	m.Parent = z6
	local function landing(name: string, size: Vector3, pos: Vector3, rate: number)
		local p = anchor(name, size, pos, m)
		emitter(p, "Land", snowProps({
			Rate = rate,
			Lifetime = NumberRange.new(3, 4),
			Speed = NumberRange.new(1.2, 1.2),
			SpreadAngle = Vector2.new(0, 0),
			Drag = 2.5,
			Acceleration = Vector3.new(0, 0, 0),
			RotSpeed = NumberRange.new(0, 0),
			Size = seq({ { 0, 0.5, 0.1 }, { 0.8, 0.5, 0.1 }, { 1, 0.18 } }), -- fond en rapetissant
			Transparency = seq({ { 0, 1 }, { 0.06, 0 }, { 0.75, 0 }, { 1, 1 } }),
		}))
	end
	landing("Chaussee", Vector3.new(125, 0.1, 92), Vector3.new(780.5, 0.72, 0), 12) -- chaussée à y 0 ; vu le 28/11 : à 4, aucun flocon posé à l'écran
	landing("Trottoir_N", Vector3.new(125, 0.1, 2.5), Vector3.new(780.5, 0.62 + 0.72, 48.5), 1.5) -- trottoir nord sous la neige du chef Map, y 0,62
	landing("Trottoir_S", Vector3.new(125, 0.1, 2.5), Vector3.new(780.5, 0.62 + 0.72, -48.5), 1.5) -- trottoir sud sous la neige, y 0,62
	m.PrimaryPart = m.Chaussee
	note(m, "Workspace/Map/Zone_6/Ambience_NewYork, avec la neige du couloir : la chaussée (y 0) et les trottoirs sous la neige (y 0,62, NeigeSol du chef Map), x 718 à 843. Chaque Part est 0,72 stud au-dessus du sol qu'elle couvre : si le sol monte encore, remonter la Part d'autant")
end

do -- poudre de neige sous les pieds : gabarit pour le code (sans script, rien ne suit les pieds)
	local p = anchor("FX_Z6_PoudrePas", Vector3.new(1, 0.2, 1), Vector3.new(760, 0.1, 0), z6)
	local a = Instance.new("Attachment")
	a.Name = "Foot"
	a.Parent = p
	local puff = emitter(a, "Puff", steamProps({
		Rate = 0,
		Color = cseq({ { 0, Color3.fromRGB(246, 249, 255) }, { 1, Color3.fromRGB(236, 242, 252) } }),
		Lifetime = NumberRange.new(0.45, 0.65),
		Speed = NumberRange.new(1.5, 2.5),
		SpreadAngle = Vector2.new(60, 60),
		Drag = 3,
		Acceleration = Vector3.new(0, -2, 0),
		Size = seq({ { 0, 0.3 }, { 1, 1.1 } }),
		LightInfluence = 0.3,
		Transparency = seq({ { 0, 0.2 }, { 1, 1 } }),
	}))
	puff:SetAttribute("EmitCount", 2)
	local kick = emitter(a, "Kick", snowProps({
		Rate = 0,
		EmissionDirection = Enum.NormalId.Top,
		Lifetime = NumberRange.new(0.35, 0.5),
		Speed = NumberRange.new(3, 5),
		SpreadAngle = Vector2.new(35, 35),
		Acceleration = Vector3.new(0, -25, 0),
		Size = seq({ { 0, 0.25 }, { 1, 0.18 } }),
		Transparency = seq({ { 0, 0 }, { 0.7, 0 }, { 1, 1 } }),
	}))
	kick:SetAttribute("EmitCount", 3)
	p:SetAttribute("PoserA", "Pas dans la Map : gabarit pour le code de Cantin. Une fois validé, ranger l'Attachment Foot (et ses 2 émetteurs) dans ReplicatedStorage/Assets/FX/FX_SnowStep (texte de liaison dans le paquet du 28/11)")
	p:SetAttribute("Vivantes", "≈ 3 par pas (2 bouffées + 3 éclats, 0,5 s)")
	table.insert(report, p:GetFullName() .. " : gabarit, 5 particules par pas")
end

---------------------------------------------------------------- Zone 2, Londres : ronds de pluie dans les flaques (28/11)
local z2 = folder("Z2_Londres")
do -- un seul effet réutilisable : le chef Map en pose une copie dans chaque flaque
	local p = anchor("FX_Z2_RondsFlaque", Vector3.new(2.9, 0.05, 2.9), Vector3.new(132.5, 0.06, -28), z2)
	emitter(p, "Ring", {
		Texture = TEX.RainRing,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot, -- l'anneau s'ouvre, s'amincit et se casse
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular, -- à plat sur l'eau
		EmissionDirection = Enum.NormalId.Top,
		Speed = NumberRange.new(0.01, 0.01),
		Color = cseq({ { 0, Color3.fromRGB(215, 232, 250) }, { 1, Color3.fromRGB(215, 232, 250) } }),
		Rate = 3,
		Lifetime = NumberRange.new(0.55, 0.75),
		Size = seq({ { 0, 1.2, 0.25 }, { 1, 1.5, 0.25 } }), -- vu le 28/11 : à 0,9, à peine visible dans une flaque
		Rotation = NumberRange.new(0, 360),
		LightEmission = 0.5,
		Brightness = 1.5,
		LightInfluence = 0.5,
		Transparency = seq({ { 0, 0 }, { 0.6, 0.25 }, { 1, 1 } }),
		ZOffset = 0.2,
	})
	emitter(p, "Splash", {
		Texture = TEX.Drop,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		EmissionDirection = Enum.NormalId.Top,
		Color = cseq({ { 0, Color3.fromRGB(215, 232, 250) }, { 1, Color3.fromRGB(215, 232, 250) } }),
		Rate = 1.5,
		Lifetime = NumberRange.new(0.25, 0.35),
		Speed = NumberRange.new(3, 4.5),
		SpreadAngle = Vector2.new(30, 30),
		Acceleration = Vector3.new(0, -40, 0),
		Size = seq({ { 0, 0.2 }, { 1, 0.14 } }),
		LightEmission = 0.1,
		LightInfluence = 0.5,
		Transparency = seq({ { 0, 0.1 }, { 0.8, 0.1 }, { 1, 1 } }),
	})
	note(p, "Une copie dans chaque flaque, au ras de l'eau (+0,05 stud), Part carrée de côté = 0,55 × le diamètre de la flaque (les anneaux restent dans l'eau) ; ici calée sur Puddle_1_A (Ø 5,2). Pour une petite flaque (Ø < 3,5), Ring.Rate 1 et Splash.Rate 0,8",
		"les PuddleFX_1 à 6 de Street_Londres/Weather (Ripples à la texture Roblox explosion01_shockwave + Splash smoke_main, ≈ 5 vivantes chacun)")
end

do -- pluie plus légère pour le téléphone (demande du Chef, 28/11) : environ 100 vivantes au lieu de 310, même effet franc
	-- On la fait naître à 22 studs (au lieu de 42) : depuis la rue, on ne voit pas la pluie au-dessus des toits, et la
	-- durée de vie tombe à 0,4 s. Traits toon plus longs (2 à 2,8 studs) et plus épais qu'aujourd'hui. Le débit est
	-- partagé en 3 émetteurs de moins de 100 par seconde (plafond par émetteur sur téléphone, d'après les notes du vault).
	-- À ne pas poser à la place de la pluie de la map avant l'accord du Chef.
	-- NON RETENUE par Clément le 28/11 (« Garder l'actuelle ») : construite dans _non_retenu, à ne pas poser.
	-- Sa texture FX_Biome_RainStreak est rangée dans StealAShop-Art/FX/Biomes/_non_retenu (pas publiée).
	local nonRetenu = folder("_non_retenu")
	nonRetenu:SetAttribute("Note", "Propositions refusées par Clément : à ne pas poser. FX_Z2_Pluie : « Garder l'actuelle » (28/11)")
	local m = Instance.new("Model")
	m.Name = "FX_Z2_Pluie"
	m.Parent = nonRetenu
	local cloud = anchor("Cloud", Vector3.new(109, 1, 93), Vector3.new(174.5, 22, 0), m)
	m.PrimaryPart = cloud
	local function rain(name: string, rate: number, len: number)
		emitter(cloud, name, {
			Texture = TEX.RainStreak,
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			EmissionDirection = Enum.NormalId.Bottom,
			Color = cseq({ { 0, Color3.fromRGB(222, 232, 245) }, { 1, Color3.fromRGB(222, 232, 245) } }),
			Rate = rate,
			Lifetime = NumberRange.new(0.38, 0.42),
			Speed = NumberRange.new(54, 58),
			SpreadAngle = Vector2.new(2, 2),
			Acceleration = Vector3.new(1.2, 0, 0),
			Size = seq({ { 0, len, len * 0.1 }, { 1, len, len * 0.1 } }),
			LightEmission = 0.45,
			LightInfluence = 0.5,
			Transparency = seq({ { 0, 1 }, { 0.08, 0.15 }, { 1, 0.25 } }),
		})
	end
	rain("Rain_A", 90, 3.4) -- vu le 28/11 : trait v1 épais et effilé aux deux bouts = éclats de verre ; v2 fin et plus long
	rain("Rain_B", 90, 3)
	rain("Rain_C", 70, 2.6)
	local ground = anchor("Impacts", Vector3.new(109, 0.1, 91), Vector3.new(174.5, 0.05, 0), m)
	emitter(ground, "Splash", {
		Texture = TEX.Drop,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		EmissionDirection = Enum.NormalId.Top,
		Color = cseq({ { 0, Color3.fromRGB(222, 232, 245) }, { 1, Color3.fromRGB(222, 232, 245) } }),
		Rate = 40,
		Lifetime = NumberRange.new(0.2, 0.3),
		Speed = NumberRange.new(2.5, 4),
		SpreadAngle = Vector2.new(35, 35),
		Acceleration = Vector3.new(0, -35, 0),
		Size = seq({ { 0, 0.22 }, { 1, 0.12 } }),
		LightEmission = 0.2,
		LightInfluence = 0.5,
		Transparency = seq({ { 0, 0.2 }, { 1, 0.9 } }),
	})
	note(m, "Non retenue par Clément le 28/11 (« Garder l'actuelle ») : ne pas poser",
		"Street_Londres/Weather/RainCloud (Rate 360, ≈ 310 vivantes) et StreetSplashes (Rate 90, ≈ 22 vivantes)")
end

root.Parent = SS
local total = 0
for _, d in root:GetDescendants() do if d:IsA("ParticleEmitter") then total += 1 end end
table.insert(report, total .. " émetteurs")
return table.concat(report, "\n")
