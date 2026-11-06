--!strict
--[[
	tools/greybox.luau : greybox jouable de la map (DEV-003)

	À exécuter dans Studio en mode Edit (MCP execute_luau ou barre de commande).
	Rejouable : détruit puis reconstruit Workspace/Greybox, par petits lots
	(task.wait() entre les lots). Ne touche à rien d'autre dans la place, sauf la
	Baseplate et la SpawnLocation par défaut (voir SUPPRIMER_DEFAUTS).
	Aucun script n'est créé dans la greybox. À la fin, il mesure ce qu'il a
	construit (par les tags, pas par ses propres variables) et renvoie le rapport.

	Sources (Partie 1) : section 4 (carte, tableau des zones), 2.1 (tags),
	5.3 (rayons), 5.5 (vigile), 5.12 (nuit), 10.1 (vitrines, porte),
	10.4 (enfants nommés). Ce qui n'est pas dans le doc est marqué « V0 ».

	Repère :
	  X = axe de la rue. Limite safe en X = 0, zone safe en X < 0, couloir en
	      X > 0 : la coordonnée X de la vitrine d'un magasin PNJ est sa distance
	      de retour.
	  Y = haut, sol à Y = 0.
	  Z = travers de la rue. Côté « N » en Z > 0, côté « S » en Z < 0.
	  Chaque modèle a son pivot en bas au centre, face avant (−Z local) tournée
	  vers la rue ou l'allée (10.1).
]]

local CollectionService = game:GetService("CollectionService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Workspace = game:GetService("Workspace")

-- Supprime Workspace.Baseplate et Workspace.SpawnLocation (place par défaut)
local SUPPRIMER_DEFAUTS = true

------------------------------------------------------------------------------
-- Valeurs du doc
------------------------------------------------------------------------------

-- Section 4
local SAFE_SIZE = 240 -- zone safe : carré de 240 × 240
local PLOT_W = 64 -- parcelle : 64 le long de l'allée…
local PLOT_D = 80 -- … et 80 de profondeur
local ALLEY_W = 60 -- allée centrale
local STREET_W = 40 -- boulevard

-- Section 10.1
local DOOR_W, DOOR_H = 4, 7.5
local WINDOW_T = 0.4
local WINDOWS: { [string]: Vector2 } = {
	S = Vector2.new(8, 6),
	M = Vector2.new(12, 7),
	L = Vector2.new(16, 8),
}

type StoreDef = { Id: string, Label: string }
type ZoneDef = {
	Distance: number, -- distance de retour depuis la limite safe (section 4)
	Speed: number, -- vitesse conseillée (section 4)
	Damage: string, -- dégâts/coup conseillés, affichés sur l'arche (section 4)
	Stores: { StoreDef }, -- les 2 magasins PNJ (section 4), Id selon 10.3
	Window: string, -- V0 : taille de vitrine (S, M, L)
	Color: Color3, -- V0 : teinte de repérage de la zone
}

local ZONES: { ZoneDef } = {
	{
		Distance = 60,
		Speed = 16,
		Damage = "1",
		Window = "S",
		Color = Color3.fromRGB(90, 190, 90),
		Stores = { { Id = "Superette", Label = "Supérette" }, { Id = "Kiosque", Label = "Kiosque" } },
	},
	{
		Distance = 140,
		Speed = 22,
		Damage = "10",
		Window = "S",
		Color = Color3.fromRGB(230, 200, 60),
		Stores = { { Id = "MagasinDeJouets", Label = "Magasin de jouets" }, { Id = "Confiserie", Label = "Confiserie" } },
	},
	{
		Distance = 240,
		Speed = 28,
		Damage = "80",
		Window = "M",
		Color = Color3.fromRGB(70, 140, 230),
		Stores = { { Id = "Electronique", Label = "Électronique" }, { Id = "JeuxVideo", Label = "Jeux vidéo" } },
	},
	{
		Distance = 360,
		Speed = 34,
		Damage = "600",
		Window = "M",
		Color = Color3.fromRGB(170, 90, 220),
		Stores = { { Id = "Bijouterie", Label = "Bijouterie" }, { Id = "Horlogerie", Label = "Horlogerie" } },
	},
	{
		Distance = 500,
		Speed = 40,
		Damage = "5 000",
		Window = "L",
		Color = Color3.fromRGB(240, 130, 50),
		Stores = { { Id = "GalerieDArt", Label = "Galerie d'art" }, { Id = "Antiquaire", Label = "Antiquaire" } },
	},
	{
		Distance = 660,
		Speed = 48,
		Damage = "40 000",
		Window = "L",
		Color = Color3.fromRGB(220, 60, 60),
		Stores = { { Id = "Banque", Label = "Banque" }, { Id = "SalleDesCoffres", Label = "Salle des coffres" } },
	},
}

------------------------------------------------------------------------------
-- Choix V0 (pas dans le doc, à valider)
------------------------------------------------------------------------------

-- Trottoir entre l'allée et l'avant des parcelles : 60 + 2 × 10 = 80 de porte
-- à porte en face à face, comme demandé en section 4.
local SIDEWALK = 10
-- Pas entre centres de parcelles : diagonale porte à porte √(160² + 80²) ≈ 179
-- (« environ 180 » en section 4).
local PLOT_PITCH = 80
local SPAWN_X = -SAFE_SIZE / 2 -- centre de l'allée
local WALL_H = 12 -- enceinte de la zone safe et façades du couloir
local FLOOR_TOP = 0.2 -- dessus des sols des bâtiments
local PLOT_FLOOR_TOP = 0.1 -- dessus du sol des parcelles
local SILL = 0.5 -- allège des vitrines
local STORE_D = 28 -- profondeur d'un magasin PNJ
local STORE_W: { [string]: number } = { S = 24, M = 28, L = 32 } -- largeur selon la vitrine
local STORE_H: { [string]: number } = { S = 14, M = 16, L = 18 } -- le rideau ouvert tient sous le toit
local PLOT_SHOP_W, PLOT_SHOP_D, PLOT_SHOP_H = 32, 28, 16 -- boutique de la parcelle, vitrine M
local SHOP_X_NEAR, SHOP_X_FAR, SHOP_Z = -14, -34, 24 -- comptoirs à l'entrée de l'allée
local NIGHTWALL_X, NIGHTWALL_H = 12, 24 -- mur de nuit, à l'entrée du couloir
local CORRIDOR_END = 700 -- fond du couloir, 40 studs après le magasin de zone 6

------------------------------------------------------------------------------
-- Outils
------------------------------------------------------------------------------

local V = Vector3.new

type Props = { [string]: any }

local GREY = Color3.fromRGB(160, 160, 165)
local function tint(c: Color3, k: number): Color3
	return GREY:Lerp(c, k)
end

local C = {
	SafeGround = Color3.fromRGB(196, 196, 196),
	Alley = Color3.fromRGB(150, 150, 155),
	Sidewalk = Color3.fromRGB(180, 180, 180),
	PlotFloor = Color3.fromRGB(205, 195, 170),
	PlotWall = Color3.fromRGB(175, 170, 160),
	Wall = Color3.fromRGB(120, 120, 125),
	Glass = Color3.fromRGB(160, 210, 235),
	Door = Color3.fromRGB(110, 80, 60),
	Shutter = Color3.fromRGB(110, 110, 115),
	Shelf = Color3.fromRGB(140, 110, 80),
	Luxe = Color3.fromRGB(230, 190, 60),
	SignBg = Color3.fromRGB(40, 40, 45),
	Volume = Color3.fromRGB(255, 0, 255),
	Cash = Color3.fromRGB(60, 200, 90),
	Machine = Color3.fromRGB(70, 70, 75),
	Patrol = Color3.fromRGB(40, 60, 160),
	NightWall = Color3.fromRGB(110, 35, 35),
	Gold = Color3.fromRGB(240, 200, 60),
	Spawn = Color3.fromRGB(90, 160, 255),
	SafeLine = Color3.fromRGB(255, 220, 60),
	Button = Color3.fromRGB(200, 40, 40),
}

-- Volume invisible lu par le code (Bounds) : ne bloque ni les joueurs ni les rayons
local VOLUME: Props = { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }
-- Marquage au sol, sans collision
local MARK: Props = { CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }
-- Éclat de vitrine fracturée : caché tant que la vitrine n'est pas cassée
local SHARD: Props = {
	Material = Enum.Material.Glass,
	Transparency = 1,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
	CastShadow = false,
}

local function apply(inst: Instance, props: Props?)
	if props then
		for k, v in props do
			(inst :: any)[k] = v
		end
	end
end

-- Bloc ancré défini par deux coins opposés dans le repère `frame`
local function box(parent: Instance, name: string, frame: CFrame, a: Vector3, b: Vector3, color: Color3, props: Props?): Part
	local lo, hi = a:Min(b), a:Max(b)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = hi - lo
	p.CFrame = frame * CFrame.new((lo + hi) / 2)
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	apply(p, props)
	p.Parent = parent
	return p
end

-- Attachment placé à `world`, porté par la pièce `p`
local function attach(p: BasePart, name: string, world: CFrame, attrs: Props?): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.CFrame = p.CFrame:ToObjectSpace(world)
	if attrs then
		for k, v in attrs do
			a:SetAttribute(k, v)
		end
	end
	a.Parent = p
	return a
end

-- Panneau de texte sur une face de la pièce
local function label(p: BasePart, face: Enum.NormalId, text: string, color: Color3?)
	local g = Instance.new("SurfaceGui")
	g.Name = "Sign" .. face.Name
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 40
	g.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.Name = "Label"
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.TextScaled = true
	t.Font = Enum.Font.GothamBold
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.Text = text
	t.Parent = g
	g.Parent = p
end

-- side = 1 : côté N (Z > 0), la face avant (−Z local) regarde vers −Z, la rue.
-- side = −1 : côté S, tourné de 180°.
local function facing(side: number): CFrame
	return if side > 0 then CFrame.identity else CFrame.Angles(0, math.pi, 0)
end

-- Arche de la zone zi : à mi-chemin entre le magasin précédent (ou la limite
-- safe) et ceux de la zone (V0).
local function gateX(zi: number): number
	local prev = if zi == 1 then 0 else ZONES[zi - 1].Distance
	return (prev + ZONES[zi].Distance) / 2
end

------------------------------------------------------------------------------
-- Bâtiment à vitrine (magasin PNJ ou boutique de parcelle)
------------------------------------------------------------------------------

type Opening = { x0: number, x1: number, y0: number, y1: number }

type BuildingSpec = {
	W: number,
	D: number,
	H: number,
	Window: Vector2,
	DoorX: number?,
	Color: Color3,
	FloorColor: Color3,
	SignName: string,
	SignText: string,
}

-- Repère `frame` : origine en bas au centre de l'emprise, façade en −Z local.
-- Crée Floor, murs, Roof, Window, WindowFractured (Shard_01 à _40), Shutter en
-- position ouverte (il tombe de sa hauteur pour fermer), Door si DoorX, et le
-- panneau du toit (SignName). Renvoie le sol.
local function building(model: Model, frame: CFrame, s: BuildingSpec): Part
	local W, D, H = s.W, s.D, s.H
	local top = H - 1 -- haut des murs ; le toit va de top à H
	local zf = -D / 2 -- façade
	local zw = zf + 0.5 -- plan de la vitre, au milieu du mur
	local ww, wh = s.Window.X, s.Window.Y

	local floor =
		box(model, "Floor", frame, V(-W / 2 + 0.5, -1, -D / 2 + 0.5), V(W / 2 - 0.5, FLOOR_TOP, D / 2 - 0.5), s.FloorColor)

	-- Façade percée : vitrine centrée, porte éventuelle
	local openings: { Opening } = { { x0 = -ww / 2, x1 = ww / 2, y0 = SILL, y1 = SILL + wh } }
	local doorX = s.DoorX
	if doorX then
		table.insert(openings, { x0 = doorX - DOOR_W / 2, x1 = doorX + DOOR_W / 2, y0 = 0, y1 = DOOR_H })
	end
	table.sort(openings, function(a: Opening, b: Opening)
		return a.x0 < b.x0
	end)
	local n = 0
	local function seg(x0: number, x1: number, y0: number, y1: number)
		if x1 - x0 > 0.01 and y1 - y0 > 0.01 then
			n += 1
			box(model, "FrontWall_" .. n, frame, V(x0, y0, zf), V(x1, y1, zf + 1), s.Color)
		end
	end
	local cursor = -W / 2
	for _, o in openings do
		seg(cursor, o.x0, 0, top)
		seg(o.x0, o.x1, 0, o.y0)
		seg(o.x0, o.x1, o.y1, top)
		cursor = o.x1
	end
	seg(cursor, W / 2, 0, top)

	box(model, "BackWall", frame, V(-W / 2, 0, D / 2 - 1), V(W / 2, top, D / 2), s.Color)
	box(model, "SideWall_L", frame, V(-W / 2, 0, zf + 1), V(-W / 2 + 1, top, D / 2 - 1), s.Color)
	box(model, "SideWall_R", frame, V(W / 2 - 1, 0, zf + 1), V(W / 2, top, D / 2 - 1), s.Color)
	box(model, "Roof", frame, V(-W / 2, top, -D / 2), V(W / 2, H, D / 2), s.Color:Lerp(Color3.new(0, 0, 0), 0.2))

	box(
		model,
		"Window",
		frame,
		V(-ww / 2, SILL, zw - WINDOW_T / 2),
		V(ww / 2, SILL + wh, zw + WINDOW_T / 2),
		C.Glass,
		{ Material = Enum.Material.Glass, Transparency = 0.5 }
	)

	local fractured = Instance.new("Model")
	fractured.Name = "WindowFractured"
	local cols, rows = 8, 5 -- 40 éclats (10.4)
	local sw, sh = ww / cols, wh / rows
	for r = 0, rows - 1 do
		for c = 0, cols - 1 do
			local x0, y0 = -ww / 2 + c * sw, SILL + r * sh
			box(
				fractured,
				string.format("Shard_%02d", r * cols + c + 1),
				frame,
				V(x0, y0, zw - WINDOW_T / 2),
				V(x0 + sw, y0 + sh, zw + WINDOW_T / 2),
				C.Glass,
				SHARD
			)
		end
	end
	fractured.WorldPivot = frame * CFrame.new(0, SILL + wh / 2, zw)
	fractured.Parent = model

	-- Rideau ouvert, devant la façade au-dessus de la vitrine : baissé de sa
	-- hauteur (wh + 0,5), il touche le sol.
	box(
		model,
		"Shutter",
		frame,
		V(-ww / 2 - 0.5, SILL + wh, zf - 0.35),
		V(ww / 2 + 0.5, SILL + 2 * wh + 0.5, zf - 0.05),
		C.Shutter,
		{ Material = Enum.Material.DiamondPlate }
	)

	if doorX then
		box(model, "Door", frame, V(doorX - DOOR_W / 2, 0, zf + 0.3), V(doorX + DOOR_W / 2, DOOR_H, zf + 0.7), C.Door)
	end

	local sign = box(model, s.SignName, frame, V(-W / 2 + 2, H, zf), V(W / 2 - 2, H + 4, zf + 0.6), C.SignBg)
	label(sign, Enum.NormalId.Front, s.SignText)
	return floor
end

------------------------------------------------------------------------------
-- Magasin PNJ (10.4)
------------------------------------------------------------------------------

local function buildStore(parent: Instance, zi: number, zone: ZoneDef, def: StoreDef, side: number)
	local size = zone.Window
	local win = WINDOWS[size]
	local W, H, D = STORE_W[size], STORE_H[size], STORE_D
	local top = H - 1
	local inner = W / 2 - 1
	local frame = CFrame.new(zone.Distance, 0, side * (STREET_W / 2 + D / 2)) * facing(side)
	local wallColor = tint(zone.Color, 0.45)

	local model = Instance.new("Model")
	model.Name = string.format("STORE_Z%d_%s", zi, def.Id)

	local floor = building(model, frame, {
		W = W,
		D = D,
		H = H,
		Window = win,
		DoorX = -side * (win.X / 2 + 2 + DOOR_W / 2), -- V0 : porte côté zone safe
		Color = wallColor,
		FloorColor = tint(zone.Color, 0.15),
		SignName = "SignPart",
		SignText = def.Label,
	})

	-- 5.3 : 6 Standard sur les rayons avant, 3 Premium au milieu, 1 Luxe dans la
	-- réserve du fond. Rayons de 2 de profondeur (10.1), colis posés à 3 de haut.
	local slot = 0
	local function addSlot(p: BasePart, x: number, y: number, z: number, tier: string)
		slot += 1
		attach(p, string.format("ShelfSlot_%02d", slot), frame * CFrame.new(x, y, z), { Tier = tier })
	end
	local shelfL = box(model, "Shelf_Front_L", frame, V(-inner, 0, -10.5), V(-inner + 2, 3, -1.5), C.Shelf)
	local shelfR = box(model, "Shelf_Front_R", frame, V(inner - 2, 0, -10.5), V(inner, 3, -1.5), C.Shelf)
	for _, z in { -9, -6, -3 } do
		addSlot(shelfL, -inner + 1, 3, z, "Standard")
	end
	for _, z in { -9, -6, -3 } do
		addSlot(shelfR, inner - 1, 3, z, "Standard")
	end
	local middle = box(model, "Shelf_Middle", frame, V(-4.5, 0, 0.5), V(4.5, 3, 2.5), C.Shelf)
	for _, x in { -3, 0, 3 } do
		addSlot(middle, x, 3, 1.5, "Premium")
	end

	-- Réserve : cloison avec un passage de 5 de large, socle du colis Luxe
	box(model, "ReserveWall_L", frame, V(-inner, 0, 6.5), V(-2.5, top, 7.5), wallColor)
	box(model, "ReserveWall_R", frame, V(2.5, 0, 6.5), V(inner, top, 7.5), wallColor)
	box(model, "ReserveWall_Top", frame, V(-2.5, 8, 6.5), V(2.5, top, 7.5), wallColor)
	local reserve = box(model, "Shelf_Reserve", frame, V(-1, 0, 9.5), V(1, 3, 11.5), C.Luxe)
	addSlot(reserve, 0, 3, 10.5, "Luxe")

	-- 5.5 : le vigile apparaît à la porte de la réserve, tourné vers la vitrine
	attach(floor, "GuardSpawn", frame * CFrame.new(0, FLOOR_TOP, 7))

	box(model, "Bounds", frame, V(-inner, FLOOR_TOP, -D / 2 + 1), V(inner, top, D / 2 - 1), C.Volume, VOLUME)

	model.WorldPivot = frame
	model:SetAttribute("Zone", zi)
	CollectionService:AddTag(model, "NPCStore")
	model.Parent = parent
end

------------------------------------------------------------------------------
-- Parcelle de joueur (10.4)
------------------------------------------------------------------------------

local function buildPlot(parent: Instance, index: number, x: number, side: number)
	local hw, hd = PLOT_W / 2, PLOT_D / 2
	local frame = CFrame.new(x, 0, side * (ALLEY_W / 2 + SIDEWALK + hd)) * facing(side)

	local model = Instance.new("Model")
	model.Name = string.format("PLOT_Greybox_%02d", index)

	local plotFloor = box(model, "PlotFloor", frame, V(-hw, -1, -hd), V(hw, PLOT_FLOOR_TOP, hd), C.PlotFloor)

	-- Boutique collée à l'avant de la parcelle : sa vitrine est la « porte »
	-- de la section 4 (80 en face à face, ≈ 180 en diagonale).
	local bframe = frame * CFrame.new(0, 0, -hd + PLOT_SHOP_D / 2)
	building(model, bframe, {
		W = PLOT_SHOP_W,
		D = PLOT_SHOP_D,
		H = PLOT_SHOP_H,
		Window = WINDOWS.M,
		DoorX = nil,
		Color = C.PlotWall,
		FloorColor = C.PlotFloor:Lerp(Color3.new(1, 1, 1), 0.3),
		SignName = "NameSign",
		SignText = string.format("PARCELLE %d", index),
	})

	-- 20 présentoirs (5.8 : 20 max en V1), grille 5 × 4 dans la boutique
	local i = 0
	for _, z in { -8, -4, 0, 4 } do
		for _, xx in { -10, -5, 0, 5, 10 } do
			i += 1
			local stand =
				box(model, string.format("DisplayStand_%02d", i), bframe, V(xx - 1, 0, z - 1), V(xx + 1, 2.5, z + 1), C.Shelf)
			attach(stand, string.format("DisplaySlot_%02d", i), bframe * CFrame.new(xx, 2.5, z))
		end
	end

	-- Coffre-fort au fond de la boutique (VaultSlot_02 et _03 : Partie 2)
	local vault = box(model, "VaultBlock", bframe, V(-9, 0, 10.5), V(9, 3, 12.5), C.Machine)
	for k, xx in { -6, 0, 6 } do
		attach(vault, string.format("VaultSlot_%02d", k), bframe * CFrame.new(xx, 3, 11.5))
	end
	-- Bouton du rideau (Partie 2), sur le mur de façade côté intérieur
	box(model, "ShutterButton", bframe, V(9, 3.5, -13), V(10, 4.5, -12.7), C.Button)

	-- Cour derrière la boutique (z > −12) : établis d'ouverture, tapis, banc
	for k, xx in { -9, -3, 3, 9 } do
		local t = box(model, string.format("UnboxTable_%02d", k), frame, V(xx - 1.75, 0, -6.5), V(xx + 1.75, 3, -3.5), C.Shelf)
		attach(t, string.format("UnboxBench_%02d", k), frame * CFrame.new(xx, 3, -5))
	end

	local treadmill = Instance.new("Model")
	treadmill.Name = "Treadmill"
	local tf = frame * CFrame.new(-22, 0, 6)
	box(treadmill, "Base", tf, V(-2, 0, -4), V(2, 1, 4), C.Machine)
	local belt = box(treadmill, "Belt", tf, V(-1.5, 1, -3.5), V(1.5, 1.2, 3.5), Color3.fromRGB(30, 30, 30))
	box(treadmill, "Console", tf, V(-2, 1, -4.5), V(2, 4.5, -4), C.Machine)
	attach(belt, "UsePoint", tf * CFrame.new(0, 1.2, 0))
	treadmill.WorldPivot = tf
	CollectionService:AddTag(treadmill, "Treadmill")
	treadmill.Parent = model

	local bench = Instance.new("Model")
	bench.Name = "Bench"
	local bf = frame * CFrame.new(22, 0, 6)
	local seat = box(bench, "Base", bf, V(-1, 0, -3), V(1, 1.5, 3), C.Machine)
	box(bench, "Rack_L", bf, V(-2.5, 0, -3), V(-2, 4, -2.5), C.Machine)
	box(bench, "Rack_R", bf, V(2, 0, -3), V(2.5, 4, -2.5), C.Machine)
	box(bench, "Bar", bf, V(-3.5, 4, -2.9), V(3.5, 4.3, -2.6), Color3.fromRGB(200, 200, 200))
	attach(seat, "UsePoint", bf * CFrame.new(0, 1.5, 0))
	bench.WorldPivot = bf
	CollectionService:AddTag(bench, "Bench")
	bench.Parent = model

	-- Tapis de caisse dans l'allée latérale, près de l'avant (5.8)
	local cash = box(
		model,
		"CashPad",
		frame,
		V(21, 0, -33),
		V(27, 0.3, -27),
		C.Cash,
		{ Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CanTouch = true }
	)
	label(cash, Enum.NormalId.Top, "CAISSE", Color3.new(0, 0, 0))
	CollectionService:AddTag(cash, "CashPad")

	-- Pièges (Partie 2) : devant la vitrine et à l'entrée de la cour
	for k, p in { V(-24, PLOT_FLOOR_TOP, -37), V(24, PLOT_FLOOR_TOP, -37), V(-24, PLOT_FLOOR_TOP, -16), V(24, PLOT_FLOOR_TOP, -16) } do
		attach(plotFloor, string.format("TrapSlot_%02d", k), frame * CFrame.new(p))
	end

	-- Zone de dépôt = la cour (on y entre par les allées latérales)
	box(
		model,
		"DepositZone",
		frame,
		V(-hw, PLOT_FLOOR_TOP, -hd + PLOT_SHOP_D),
		V(hw, 12, hd),
		C.Cash,
		{ Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = true, CastShadow = false }
	)
	box(model, "Bounds", frame, V(-hw, PLOT_FLOOR_TOP, -hd), V(hw, 24, hd), C.Volume, VOLUME)

	model.WorldPivot = frame
	model:SetAttribute("PlotIndex", index) -- V0 : nom d'attribut à ajouter au contrat 10.4
	CollectionService:AddTag(model, "PlayerPlot")
	model.Parent = parent
end

------------------------------------------------------------------------------
-- Comptoirs de la zone safe (5.9)
------------------------------------------------------------------------------

local function buildCounter(parent: Instance, name: string, tag: string?, text: string, x: number, side: number, color: Color3)
	local frame = CFrame.new(x, 0, side * SHOP_Z) * facing(side)
	local model = Instance.new("Model")
	model.Name = name
	local counter = box(model, "Counter", frame, V(-6, 0, -1.5), V(6, 4, 1.5), color)
	box(model, "Post_L", frame, V(-6, 0, 3.5), V(-5, 7, 4.5), C.Machine)
	box(model, "Post_R", frame, V(5, 0, 3.5), V(6, 7, 4.5), C.Machine)
	local sign = box(model, "SignPart", frame, V(-6, 7, 3.5), V(6, 11, 4.5), C.SignBg)
	label(sign, Enum.NormalId.Front, text)
	model.PrimaryPart = counter
	model.WorldPivot = frame
	if tag then
		CollectionService:AddTag(model, tag)
	end
	model.Parent = parent
end

------------------------------------------------------------------------------
-- Zone safe
------------------------------------------------------------------------------

local function buildSafe(root: Instance)
	local S, A, hs = SAFE_SIZE, ALLEY_W / 2, STREET_W / 2
	local front = A + SIDEWALK -- avant des parcelles
	local folder = Instance.new("Folder")
	folder.Name = "Safe"
	folder.Parent = root

	local ground = Instance.new("Folder")
	ground.Name = "Ground"
	local I = CFrame.identity
	box(ground, "Ground_Alley", I, V(-S, -2, -A), V(0, 0, A), C.Alley)
	box(ground, "Ground_Sidewalk_N", I, V(-S, -2, A), V(0, 0, front), C.Sidewalk)
	box(ground, "Ground_Sidewalk_S", I, V(-S, -2, -front), V(0, 0, -A), C.Sidewalk)
	box(ground, "Ground_Plots_N", I, V(-S, -2, front), V(0, 0, S / 2), C.SafeGround)
	box(ground, "Ground_Plots_S", I, V(-S, -2, -S / 2), V(0, 0, -front), C.SafeGround)
	-- Enceinte : une seule sortie, large comme le boulevard, centrée en X = 0
	box(ground, "Wall_West", I, V(-S - 2, 0, -S / 2 - 2), V(-S, WALL_H, S / 2 + 2), C.Wall)
	box(ground, "Wall_North", I, V(-S, 0, S / 2), V(1, WALL_H, S / 2 + 2), C.Wall)
	box(ground, "Wall_South", I, V(-S, 0, -S / 2 - 2), V(1, WALL_H, -S / 2), C.Wall)
	box(ground, "Wall_East_N", I, V(-1, 0, hs), V(1, WALL_H, S / 2), C.Wall)
	box(ground, "Wall_East_S", I, V(-1, 0, -S / 2), V(1, WALL_H, -hs), C.Wall)
	ground.Parent = folder
	task.wait()

	-- Limite safe : arche « ZONE SAFE » + ligne au sol + volume de la zone
	local safe = Instance.new("Model")
	safe.Name = "SafeZone"
	box(safe, "ArchPillar_N", I, V(-1.5, 0, hs), V(1.5, 22, hs + 3), C.Gold)
	box(safe, "ArchPillar_S", I, V(-1.5, 0, -hs - 3), V(1.5, 22, -hs), C.Gold)
	local arch = box(safe, "ArchSign", I, V(-1.5, 22, -hs - 3), V(1.5, 28, hs + 3), C.SignBg)
	label(arch, Enum.NormalId.Left, "ZONE SAFE", C.SafeLine)
	label(arch, Enum.NormalId.Right, "ZONE SAFE", C.SafeLine)
	box(safe, "SafeLine", I, V(-0.75, -0.1, -hs), V(0.75, 0.06, hs), C.SafeLine, MARK)
	box(safe, "Bounds", I, V(-S, 0, -S / 2), V(0, 40, S / 2), C.Volume, VOLUME)
	safe.WorldPivot = CFrame.new(-S / 2, 0, 0)
	CollectionService:AddTag(safe, "SafeZone")
	safe.Parent = folder

	-- Spawn au centre de l'allée, tourné vers la sortie
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = V(8, 1, 8)
	spawn.CFrame = CFrame.lookAt(V(SPAWN_X, -0.4, 0), V(SPAWN_X + 1, -0.4, 0))
	spawn.Neutral = true
	spawn.AllowTeamChangeOnTouch = false
	spawn.Color = C.Spawn
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.BottomSurface = Enum.SurfaceType.Smooth
	spawn.Parent = folder
	task.wait()

	-- Entrée de l'allée (côté sortie). V0 : « gauche » et « droite » vus en
	-- entrant dans l'allée depuis l'arche.
	local shops = Instance.new("Folder")
	shops.Name = "Shops"
	shops.Parent = folder
	buildCounter(shops, "WeaponShop", "WeaponShop", "BOUTIQUE D'ARMES", SHOP_X_NEAR, 1, tint(C.Button, 0.4))
	buildCounter(shops, "AuraShop", "AuraShop", "BOUTIQUE D'AURAS", SHOP_X_NEAR, -1, tint(Color3.fromRGB(150, 80, 230), 0.4))
	buildCounter(shops, "RobuxShop", "RobuxShop", "BOUTIQUE ROBUX", SHOP_X_FAR, 1, C.Gold)
	buildCounter(shops, "Receleur", nil, "RECELEUR", SHOP_X_FAR, -1, tint(C.Door, 0.6)) -- pas de tag au contrat
	task.wait()

	-- 6 parcelles : 1 à 3 côté N, 4 à 6 côté S, de la sortie vers le fond
	local plots = Instance.new("Folder")
	plots.Name = "Plots"
	plots.Parent = folder
	for k = 1, 3 do
		local x = -S / 2 + (2 - k) * PLOT_PITCH
		buildPlot(plots, k, x, 1)
		task.wait()
		buildPlot(plots, k + 3, x, -1)
		task.wait()
	end
end

------------------------------------------------------------------------------
-- Couloir
------------------------------------------------------------------------------

local function buildCorridor(root: Instance)
	local hs = STREET_W / 2
	local sideOuter = hs + STORE_D + 4
	local I = CFrame.identity
	local folder = Instance.new("Folder")
	folder.Name = "Corridor"
	folder.Parent = root

	-- Tronçons : entrée [0, arche 1], puis zone zi de son arche à la suivante
	local cuts = { 0 }
	for zi = 1, #ZONES do
		table.insert(cuts, gateX(zi))
	end
	table.insert(cuts, CORRIDOR_END)

	for seg = 1, #cuts - 1 do
		local x0, x1 = cuts[seg], cuts[seg + 1]
		local zi = seg - 1 -- 0 = entrée du couloir
		local zone = ZONES[zi]
		local color = if zone then zone.Color else GREY

		local zf = Instance.new("Folder")
		zf.Name = if zone then "Zone_" .. zi else "Entry"
		local geo = Instance.new("Folder")
		geo.Name = "Ground"
		box(geo, "Street", I, V(x0, -2, -hs), V(x1, 0, hs), Color3.fromRGB(80, 80, 85):Lerp(color, 0.15))
		box(geo, "Side_N", I, V(x0, -2, hs), V(x1, 0, sideOuter), tint(color, 0.25))
		box(geo, "Side_S", I, V(x0, -2, -sideOuter), V(x1, 0, -hs), tint(color, 0.25))
		-- Façades de remplissage entre les magasins : le couloir est fermé sur les côtés
		local gaps = { { x0, x1 } }
		if zone then
			local w = STORE_W[zone.Window]
			gaps = { { x0, zone.Distance - w / 2 }, { zone.Distance + w / 2, x1 } }
		end
		for j, g in gaps do
			box(geo, "SideWall_N" .. j, I, V(g[1], 0, hs), V(g[2], WALL_H, hs + 1), tint(color, 0.35))
			box(geo, "SideWall_S" .. j, I, V(g[1], 0, -hs - 1), V(g[2], WALL_H, -hs), tint(color, 0.35))
		end
		geo.Parent = zf
		zf.Parent = folder
		task.wait()

		if not zone then
			-- Mur de nuit (5.12), livré baissé (état jour) : le haut affleure
			-- sous le sol, le code le monte de sa hauteur la nuit.
			local nw = Instance.new("Model")
			nw.Name = "NightWall"
			local wall = box(nw, "Wall", I, V(NIGHTWALL_X - 1, -NIGHTWALL_H - 0.2, -hs - 1), V(NIGHTWALL_X + 1, -0.2, hs + 1), C.NightWall)
			nw.PrimaryPart = wall
			CollectionService:AddTag(nw, "NightWall")
			nw.Parent = zf
			box(zf, "NightWallLine", I, V(NIGHTWALL_X - 1, -0.1, -hs), V(NIGHTWALL_X + 1, 0.06, hs), C.NightWall, MARK)
			task.wait()
		else
			-- Arche d'entrée de zone
			local gx = x0
			local gate = Instance.new("Model")
			gate.Name = string.format("ZoneGate_%d", zi)
			box(gate, "Pillar_N", I, V(gx - 1, 0, hs), V(gx + 1, 18, hs + 3), tint(color, 0.7))
			box(gate, "Pillar_S", I, V(gx - 1, 0, -hs - 3), V(gx + 1, 18, -hs), tint(color, 0.7))
			local sign = box(gate, "SignPart", I, V(gx - 1, 18, -hs - 3), V(gx + 1, 24, hs + 3), C.SignBg)
			local text = string.format("ZONE %d\nVitesse conseillée %d · Dégâts conseillés %s", zi, zone.Speed, zone.Damage)
			label(sign, Enum.NormalId.Left, text, color)
			label(sign, Enum.NormalId.Right, text, color)
			gate.WorldPivot = CFrame.new(gx, 0, 0)
			gate:SetAttribute("Zone", zi)
			CollectionService:AddTag(gate, "ZoneGate")
			gate.Parent = zf
			task.wait()

			-- Un magasin de chaque côté : le premier du tableau côté N
			buildStore(zf, zi, zone, zone.Stores[1], 1)
			task.wait()
			buildStore(zf, zi, zone, zone.Stores[2], -1)
			task.wait()

			-- 2 points de ronde de nuit, au quart et aux trois quarts du tronçon
			for k, f in { 0.25, 0.75 } do
				local px = x0 + (x1 - x0) * f
				local p = box(
					zf,
					string.format("NightPatrol_Z%d_%s", zi, if k == 1 then "A" else "B"),
					I,
					V(px - 1.5, -0.05, -1.5),
					V(px + 1.5, 0.08, 1.5),
					C.Patrol,
					MARK
				)
				p:SetAttribute("Zone", zi)
				CollectionService:AddTag(p, "NightPatrol")
			end
		end
	end

	box(folder, "EndWall", I, V(CORRIDOR_END, 0, -hs - 1), V(CORRIDOR_END + 2, 16, hs + 1), C.Wall)
end

------------------------------------------------------------------------------
-- Mesures et contrôle (lus sur ce qui est construit, par les tags)
------------------------------------------------------------------------------

local TAGS = {
	"SafeZone",
	"PlayerPlot",
	"NPCStore",
	"ZoneGate",
	"NightWall",
	"NightPatrol",
	"WeaponShop",
	"AuraShop",
	"RobuxShop",
	"CashPad",
	"Treadmill",
	"Bench",
}

local function numbered(list: { string }, prefix: string, count: number)
	for i = 1, count do
		table.insert(list, string.format("%s_%02d", prefix, i))
	end
end

local STORE_CHILDREN = { "Window", "WindowFractured", "Shutter", "Door", "Bounds", "GuardSpawn", "SignPart" }
numbered(STORE_CHILDREN, "Shard", 40)
numbered(STORE_CHILDREN, "ShelfSlot", 10)
local PLOT_CHILDREN = {
	"Window",
	"WindowFractured",
	"Shutter",
	"ShutterButton",
	"CashPad",
	"DepositZone",
	"Treadmill",
	"Bench",
	"NameSign",
	"Bounds",
}
numbered(PLOT_CHILDREN, "Shard", 40)
numbered(PLOT_CHILDREN, "DisplaySlot", 20)
numbered(PLOT_CHILDREN, "VaultSlot", 3)
numbered(PLOT_CHILDREN, "UnboxBench", 4)
numbered(PLOT_CHILDREN, "TrapSlot", 4)

local function tagged(root: Instance, tag: string): { Instance }
	local found = {}
	for _, inst in CollectionService:GetTagged(tag) do
		if inst:IsDescendantOf(root) then
			table.insert(found, inst)
		end
	end
	table.sort(found, function(a: Instance, b: Instance)
		return a.Name < b.Name
	end)
	return found
end

local function missing(model: Instance, names: { string }): { string }
	local out = {}
	for _, n in names do
		if not model:FindFirstChild(n, true) then
			table.insert(out, n)
		end
	end
	return out
end

local function report(root: Instance): string
	local lines = {}
	local function out(s: string)
		table.insert(lines, s)
	end

	out("== Éléments taggés (Workspace/Greybox)")
	for _, tag in TAGS do
		out(string.format("  %-12s %d", tag, #tagged(root, tag)))
	end

	local safe = tagged(root, "SafeZone")[1]
	local line = safe and safe:FindFirstChild("SafeLine") :: BasePart?
	local spawn = root:FindFirstChildWhichIsA("SpawnLocation", true)
	if not (line and spawn) then
		out("ERREUR : SafeLine ou SpawnLocation introuvable")
		return table.concat(lines, "\n")
	end
	local lx = line.Position.X

	out("== Distances (studs, le long de la rue)")
	out(string.format("  Spawn → limite safe : %.1f", lx - spawn.Position.X))
	local okCount, total = 0, 0
	for _, store in tagged(root, "NPCStore") do
		local zi = store:GetAttribute("Zone")
		local zone = if typeof(zi) == "number" then ZONES[zi] else nil
		local window = store:FindFirstChild("Window") :: BasePart?
		if zone and window then
			total += 1
			local d = window.Position.X - lx
			local ok = math.abs(d - zone.Distance) < 0.5
			if ok then
				okCount += 1
			end
			out(string.format("  %-26s zone %d : %.1f (doc %d) %s", store.Name, zi, d, zone.Distance, if ok then "OK" else "ÉCART"))
		else
			out("  " .. store.Name .. " : attribut Zone ou Window manquant")
		end
	end
	out(string.format("  Magasins conformes : %d / %d", okCount, total))
	for _, gate in tagged(root, "ZoneGate") do
		out(string.format("  Arche %s : %.1f", gate.Name, (gate :: Model):GetPivot().X - lx))
	end
	for _, nw in tagged(root, "NightWall") do
		out(string.format("  Mur de nuit : %.1f", (nw :: Model):GetPivot().X - lx))
	end

	out("== Contrat 10.4")
	for _, tag in { "NPCStore", "PlayerPlot" } do
		local names = if tag == "NPCStore" then STORE_CHILDREN else PLOT_CHILDREN
		local bad = 0
		for _, m in tagged(root, tag) do
			local miss = missing(m, names)
			if #miss > 0 then
				bad += 1
				out("  " .. m.Name .. " : manque " .. table.concat(miss, ", "))
			end
		end
		out(string.format("  %s : %d modèle(s) incomplet(s)", tag, bad))
	end
	for _, store in tagged(root, "NPCStore") do
		local tiers: { [string]: number } = { Standard = 0, Premium = 0, Luxe = 0 }
		for _, d in store:GetDescendants() do
			if d:IsA("Attachment") and string.sub(d.Name, 1, 10) == "ShelfSlot_" then
				local t = d:GetAttribute("Tier")
				if typeof(t) == "string" and tiers[t] then
					tiers[t] += 1
				end
			end
		end
		if tiers.Standard ~= 6 or tiers.Premium ~= 3 or tiers.Luxe ~= 1 then
			out(string.format("  %s : Tier %d/%d/%d au lieu de 6/3/1", store.Name, tiers.Standard, tiers.Premium, tiers.Luxe))
		end
	end

	local scripts = 0
	for _, d in root:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			scripts += 1
		end
	end
	out(string.format("  Scripts dans la greybox : %d", scripts))
	out(string.format("  Instances dans la greybox : %d", #root:GetDescendants()))
	return table.concat(lines, "\n")
end

------------------------------------------------------------------------------
-- Construction
------------------------------------------------------------------------------

local function main(): string
	local removed = {}
	local old = Workspace:FindFirstChild("Greybox")
	if old then
		old:Destroy()
	end
	if SUPPRIMER_DEFAUTS then
		local bp = Workspace:FindFirstChild("Baseplate")
		if bp and bp:IsA("BasePart") then
			bp:Destroy()
			table.insert(removed, "Workspace.Baseplate")
		end
		local sl = Workspace:FindFirstChild("SpawnLocation")
		if sl and sl:IsA("SpawnLocation") then
			sl:Destroy()
			table.insert(removed, "Workspace.SpawnLocation")
		end
	end
	task.wait()

	local root = Instance.new("Folder")
	root.Name = "Greybox"
	root.Parent = Workspace
	buildSafe(root)
	buildCorridor(root)

	local text = report(root)
	if #removed > 0 then
		text ..= "\n== Supprimé : " .. table.concat(removed, ", ")
	end
	print(text)
	return text
end

local okRec, recording = pcall(function()
	return ChangeHistoryService:TryBeginRecording("Greybox DEV-003")
end)
local ok, result = pcall(main)
if okRec and recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
if not ok then
	error(result, 0)
end
return result
