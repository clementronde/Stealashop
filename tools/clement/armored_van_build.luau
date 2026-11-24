-- armored_van_build.luau : fourgon blindé de la Casse du siècle, ENV_Event_ArmoredVan (L-313, L-318).
-- À lancer en Edit (barre de commande ou MCP execute_luau). Construit le modèle en pièces Roblox, dans le style du
-- camion ENV_Event_Truck (Plastic à studs pour les grandes faces, SmoothPlastic pour les détails, contour noir).
--
-- Contrat (Contract/Models.ArmoredVan + même découpage que le camion, pour que le code puisse reprendre son explosion) :
--   Root (Part invisible, PrimaryPart, pivot en bas au centre, avant vers −Z)
--     Attachments : HealthBarPoint (barre de vie), BlastPoint (centre de l'explosion, à l'arrière du coffre),
--                   CashPoint (centre de la porte du coffre, pour un jet de billets ; proposé)
--   Pieces (Model) : Piece_01 à Piece_20 (ce qui vole à la casse ; Piece_12 = la porte ronde du coffre)
--   Cargo (Model) : lingots, liasses et sacs dans le coffre, visibles une fois les murs partis
--   OutlineHighlight (Highlight du contour)
-- Aucun script. Taille : 15,5 × 15,9 × 32,2 studs avec rétroviseurs et antenne ; caisse 13 × 13 (perso R15 ≈ 5,5 studs).
--
-- MODE = "Showroom" : copie Show_ENV_Event_ArmoredVan dans _SHOWROOM_CLEMENT/ÉVÉNEMENT ET NUIT (validation).
-- MODE = "Asset"    : en plus, ReplicatedStorage/Assets/Events/ENV_Event_ArmoredVan (remplace l'ancien).

local MODE = "Asset" -- validé par Clément le 2026-11-24

local SHOW_PIVOT = CFrame.new(-90, -53, 549) -- vitrine des événements, entre le camion en pièces et FX_BoxTrail
local PED_POS = Vector3.new(-90, -52.5, 530)

-- Couleurs ------------------------------------------------------------------------------------------------------
local C = {
	Steel = Color3.fromHex("5E6B7D"), -- caisse et cabine
	Plate = Color3.fromHex("465263"), -- plaques de blindage, portes
	Dark = Color3.fromHex("2C2F36"), -- toits, mur arrière
	Black = Color3.fromHex("1E1E22"),
	Gold = Color3.fromHex("FFC52E"),
	Light = Color3.fromHex("C9CFD8"), -- rivets, grille, réservoir
	Glass = Color3.fromHex("2B3A55"),
	Amber = Color3.fromHex("FF8C1A"),
	Red = Color3.fromHex("E8413C"),
	Head = Color3.fromHex("FFF3C4"),
	Hazard = Color3.fromHex("FFC21A"),
	Navy = Color3.fromHex("1B1B24"),
	Cash = Color3.fromHex("3BAA4A"),
	Band = Color3.fromHex("F6EED6"),
	Bag = Color3.fromHex("D4A266"),
	Tie = Color3.fromHex("A0663B"),
}
local PLASTIC = Enum.Material.Plastic
local SMOOTH = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon
local DIAMOND = Enum.Material.DiamondPlate

local RAD = math.rad
local ALONG_Z = CFrame.Angles(0, RAD(90), 0) -- cylindre couché dans l'axe Z
local UPRIGHT = CFrame.Angles(0, 0, RAD(90)) -- cylindre debout

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or SMOOTH
	if shape then
		p.Shape = shape
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function cyl(parent, name, size, cf, color, mat)
	return part(parent, name, size, cf, color, mat, Enum.PartType.Cylinder)
end

local function group(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

-- « $ » sur un disque (face extérieure).
local function dollar(disc: BasePart, face: Enum.NormalId)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "DollarGui"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.6
	gui.Parent = disc
	local label = Instance.new("TextLabel")
	label.Name = "Symbol"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "$"
	label.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	label.TextColor3 = C.Gold
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.Black
	stroke.Thickness = 8
	stroke.Parent = label
end

local function build(): Model
	local model = Instance.new("Model")
	model.Name = "ENV_Event_ArmoredVan"

	local root = part(model, "Root", Vector3.new(13, 0.2, 30), at(0, 0.1, 0), C.Black)
	root.Transparency = 1
	root.CanQuery = false
	model.PrimaryPart = root

	local function point(name: string, pos: Vector3, axis: Vector3?)
		local a = Instance.new("Attachment")
		a.Name = name
		a.Position = pos - root.Position
		if axis then
			a.Axis = axis
			a.SecondaryAxis = Vector3.new(0, 1, 0)
		end
		a.Parent = root
	end
	point("HealthBarPoint", Vector3.new(0, 16.5, 2))
	point("BlastPoint", Vector3.new(0, 7.5, 9))
	point("CashPoint", Vector3.new(0, 8.65, 15.7), Vector3.new(0, 0, 1))

	local pieces = group(model, "Pieces")
	local P = {}
	for i = 1, 20 do
		P[i] = group(pieces, string.format("Piece_%02d", i))
	end

	-- 01 Cabine : caisse, capot, grille, phares, pare-brise grillagé -------------------------------------------------
	local cab = P[1]
	part(cab, "CabBody", Vector3.new(13, 6.1, 7), at(0, 7.95, -7), C.Steel, PLASTIC)
	part(cab, "Hood", Vector3.new(13, 3.3, 4.5), at(0, 6.55, -12.75), C.Steel, PLASTIC)
	part(cab, "HoodPlate", Vector3.new(12, 0.25, 4), at(0, 8.32, -12.75), C.Plate)
	part(cab, "Grille", Vector3.new(8, 2.4, 0.3), at(0, 6.3, -15.1), C.Black)
	for i, y in { 5.7, 6.3, 6.9 } do
		part(cab, `GrilleSlat_{i}`, Vector3.new(7.4, 0.3, 0.2), at(0, y, -15.3), C.Light)
	end
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "L" else "R"
		part(cab, `HeadlightFrame_{tag}`, Vector3.new(2.4, 1.6, 0.3), at(side * 5.1, 6.9, -15.1), C.Black)
		part(cab, `Headlight_{tag}`, Vector3.new(1.8, 1.1, 0.2), at(side * 5.1, 6.9, -15.3), C.Head, NEON)
		part(cab, `Indicator_{tag}`, Vector3.new(1, 0.5, 0.2), at(side * 5.1, 5.6, -15.25), C.Amber, NEON)
	end
	local glass = part(cab, "Windshield", Vector3.new(11, 2.3, 0.3), at(0, 9.55, -10.6), C.Glass)
	glass.Reflectance = 0.15
	for i, x in { -3.3, -1.1, 1.1, 3.3 } do
		part(cab, `WindshieldBar_{i}`, Vector3.new(0.35, 2.5, 0.25), at(x, 9.55, -10.82), C.Black)
	end

	-- 02 / 03 Portes de la cabine ---------------------------------------------------------------------------------------
	for index, side in { -1, 1 } do
		local tag = if side < 0 then "L" else "R"
		local door = P[1 + index]
		part(door, `DoorPanel_{tag}`, Vector3.new(0.25, 5.4, 4.6), at(side * 6.625, 7.75, -6.9), C.Plate, PLASTIC)
		local window = part(door, `DoorWindow_{tag}`, Vector3.new(0.2, 1.4, 3.2), at(side * 6.85, 9.5, -6.9), C.Glass)
		window.Reflectance = 0.15
		for i, z in { -7.7, -6.1 } do
			part(door, `DoorBar_{tag}_{i}`, Vector3.new(0.25, 1.4, 0.25), at(side * 6.97, 9.5, z), C.Black)
		end
		part(door, `DoorHandle_{tag}`, Vector3.new(0.3, 0.3, 0.9), at(side * 6.85, 7.8, -5.4), C.Black)
		part(door, `MirrorArm_{tag}`, Vector3.new(0.9, 0.2, 0.2), at(side * 7.05, 9.9, -10.1), C.Black)
		part(door, `Mirror_{tag}`, Vector3.new(0.35, 1.5, 1), at(side * 7.6, 9.9, -10.1), C.Black)
	end

	-- 04 Châssis : longerons, plancher du coffre, marchepieds, réservoir, coffre à outils ----------------------------------
	local chassis = P[4]
	part(chassis, "Frame", Vector3.new(9, 1.6, 29), at(0, 3.6, -0.5), C.Black)
	part(chassis, "Floor", Vector3.new(13, 0.5, 18), at(0, 4.65, 5.5), C.Dark)
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "L" else "R"
		part(chassis, `Step_{tag}`, Vector3.new(1.3, 0.3, 2.4), at(side * 6.3, 4.3, -5.9), C.Light, DIAMOND)
	end
	cyl(chassis, "FuelTank", Vector3.new(4.5, 1.7, 1.7), at(-5, 3.2, -1) * ALONG_Z, C.Light)
	part(chassis, "ToolBox", Vector3.new(1.6, 1.7, 4), at(5, 3.2, -1), C.Black)
	part(chassis, "ToolBoxLatch", Vector3.new(0.15, 0.4, 0.8), at(5.85, 3.4, -1), C.Gold)

	-- 05 Pare-chocs avant, pare-buffle, chevrons ------------------------------------------------------------------------
	local bumper = P[5]
	part(bumper, "FrontBumper", Vector3.new(14, 1.8, 1.4), at(0, 3.9, -15.65), C.Black)
	for i, x in { -6, -2, 2, 6 } do
		part(bumper, `Chevron_F{i}`, Vector3.new(2, 1.2, 0.15), at(x, 3.9, -16.42), C.Hazard)
	end
	for _, side in { -1, 1 } do
		part(bumper, if side < 0 then "BullBarPost_L" else "BullBarPost_R", Vector3.new(0.6, 3.4, 0.6), at(side * 3.2, 6.4, -15.9), C.Black)
	end
	part(bumper, "BullBarTop", Vector3.new(7, 0.5, 0.6), at(0, 8.1, -15.9), C.Black)

	-- 06 à 09 Murs du coffre : mur, plaques de blindage, rivets, bande dorée ; écusson « $ » sur la moitié avant -----------
	local EMBLEM = Vector2.new(5.5, 8.2) -- (z, y) du centre de l'écusson
	local function wall(model: Model, side: number, zCenter: number, withEmblem: boolean)
		local tag = (if side < 0 then "L" else "R") .. (if zCenter < 5.5 then "1" else "2")
		part(model, `Wall_{tag}`, Vector3.new(0.6, 7.5, 9), at(side * 6.2, 8.65, zCenter), C.Steel, PLASTIC)
		part(model, `PlateTop_{tag}`, Vector3.new(0.2, 2.7, 8), at(side * 6.6, 10.6, zCenter), C.Plate)
		part(model, `PlateLow_{tag}`, Vector3.new(0.2, 1.8, 8), at(side * 6.6, 6.3, zCenter), C.Plate)
		part(model, `GoldBand_{tag}`, Vector3.new(0.35, 1.4, 9), at(side * 6.675, 8.2, zCenter), C.Gold)
		local n = 0
		for _, y in { 9.55, 11.65, 5.7, 6.9 } do
			for _, dz in { -3.7, 3.7 } do
				local z = zCenter + dz
				if (Vector2.new(z, y) - EMBLEM).Magnitude > 3.1 then
					n += 1
					part(model, `Rivet_{tag}_{n}`, Vector3.new(0.35, 0.35, 0.35), at(side * 6.8, y, z), C.Light)
				end
			end
		end
		if withEmblem then
			local etag = if side < 0 then "L" else "R"
			cyl(model, `EmblemRing_{etag}`, Vector3.new(0.25, 6.2, 6.2), at(side * 6.95, EMBLEM.Y, EMBLEM.X), C.Gold)
			local disc = cyl(model, `EmblemDisc_{etag}`, Vector3.new(0.25, 5.4, 5.4), at(side * 7.1, EMBLEM.Y, EMBLEM.X), C.Navy)
			dollar(disc, if side < 0 then Enum.NormalId.Left else Enum.NormalId.Right)
		end
	end
	wall(P[6], -1, 1, true)
	wall(P[7], -1, 10, false)
	wall(P[8], 1, 1, true)
	wall(P[9], 1, 10, false)

	-- 10 Toit du coffre : rebord, trappe, antenne, gyrophares arrière -------------------------------------------------------
	local roof = P[10]
	part(roof, "BoxRoof", Vector3.new(13, 0.5, 18), at(0, 12.65, 5.5), C.Dark, PLASTIC)
	part(roof, "RoofRail_F", Vector3.new(13.2, 0.4, 0.4), at(0, 13.1, -3.3), C.Black)
	part(roof, "RoofRail_B", Vector3.new(13.2, 0.4, 0.4), at(0, 13.1, 14.3), C.Black)
	part(roof, "RoofRail_L", Vector3.new(0.4, 0.4, 18), at(-6.4, 13.1, 5.5), C.Black)
	part(roof, "RoofRail_R", Vector3.new(0.4, 0.4, 18), at(6.4, 13.1, 5.5), C.Black)
	cyl(roof, "Hatch", Vector3.new(0.4, 3.2, 3.2), at(-2.5, 13.1, 7.5) * UPRIGHT, C.Steel)
	part(roof, "HatchHandle", Vector3.new(1.4, 0.3, 0.3), at(-2.5, 13.45, 7.5), C.Gold)
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "L" else "R"
		cyl(roof, `BeaconBase_{tag}`, Vector3.new(0.3, 1.5, 1.5), at(side * 5.2, 13.05, 13.2) * UPRIGHT, C.Black)
		cyl(roof, `Beacon_{tag}`, Vector3.new(1, 1.1, 1.1), at(side * 5.2, 13.7, 13.2) * UPRIGHT, C.Amber, NEON)
	end
	cyl(roof, "Antenna", Vector3.new(3, 0.2, 0.2), at(5.3, 14.4, -2) * UPRIGHT, C.Black)

	-- 11 Toit de la cabine et rampe de feux -------------------------------------------------------------------------------
	local cabRoof = P[11]
	part(cabRoof, "CabRoof", Vector3.new(13.2, 0.5, 7.4), at(0, 11.25, -7), C.Dark)
	part(cabRoof, "LightBarBase", Vector3.new(9, 0.45, 1.4), at(0, 11.72, -9.4), C.Black)
	part(cabRoof, "LightBar_L", Vector3.new(3.6, 0.7, 1.2), at(-2.4, 12.3, -9.4), C.Amber, NEON)
	part(cabRoof, "LightBar_R", Vector3.new(3.6, 0.7, 1.2), at(2.4, 12.3, -9.4), C.Amber, NEON)
	part(cabRoof, "LightBar_Mid", Vector3.new(1, 0.7, 1.2), at(0, 12.3, -9.4), C.Black)

	-- 12 Porte ronde du coffre : anneau doré, disque, volant à 6 poignées, boulons, charnières ----------------------------------
	local vault = P[12]
	local VY = 8.65
	cyl(vault, "VaultRing", Vector3.new(0.5, 7.2, 7.2), at(0, VY, 14.75) * ALONG_Z, C.Gold)
	cyl(vault, "VaultDoor", Vector3.new(0.5, 6.2, 6.2), at(0, VY, 15) * ALONG_Z, C.Steel)
	cyl(vault, "VaultHub", Vector3.new(0.5, 1.6, 1.6), at(0, VY, 15.4) * ALONG_Z, C.Gold)
	for i, deg in { 0, 60, 120 } do
		part(vault, `VaultSpoke_{i}`, Vector3.new(5.2, 0.45, 0.35), at(0, VY, 15.45) * CFrame.Angles(0, 0, RAD(deg)), C.Gold)
	end
	for i = 0, 5 do
		local a = RAD(i * 60)
		part(vault, `VaultKnob_{i + 1}`, Vector3.new(0.7, 0.7, 0.5), at(math.cos(a) * 2.6, VY + math.sin(a) * 2.6, 15.5) * CFrame.Angles(0, 0, a), C.Gold)
	end
	for i = 0, 7 do
		local a = RAD(22.5 + i * 45)
		part(vault, `VaultBolt_{i + 1}`, Vector3.new(0.4, 0.4, 0.3), at(math.cos(a) * 3.35, VY + math.sin(a) * 3.35, 15.1), C.Dark)
	end
	part(vault, "VaultHinge_1", Vector3.new(0.8, 1.2, 0.8), at(-3.7, VY + 1.8, 14.85), C.Black)
	part(vault, "VaultHinge_2", Vector3.new(0.8, 1.2, 0.8), at(-3.7, VY - 1.8, 14.85), C.Black)

	-- 13 Murs avant et arrière du coffre, feux arrière ----------------------------------------------------------------------
	local ends = P[13]
	part(ends, "RearWall", Vector3.new(11.8, 7.5, 0.4), at(0, 8.65, 14.3), C.Dark, PLASTIC)
	part(ends, "FrontWall", Vector3.new(11.8, 7.5, 0.4), at(0, 8.65, -3.3), C.Steel, PLASTIC)
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "L" else "R"
		part(ends, `TailLight_{tag}`, Vector3.new(1, 1.4, 0.2), at(side * 5.6, 6, 14.6), C.Red, NEON)
		part(ends, `TailAmber_{tag}`, Vector3.new(1, 0.6, 0.2), at(side * 5.6, 7.2, 14.6), C.Amber, NEON)
	end

	-- 14 Pare-chocs arrière, chevrons, bavettes -------------------------------------------------------------------------------
	local rear = P[14]
	part(rear, "RearBumper", Vector3.new(13, 1.2, 1), at(0, 4, 15), C.Black)
	for i, x in { -5, -1.7, 1.7, 5 } do
		part(rear, `Chevron_R{i}`, Vector3.new(1.8, 0.8, 0.15), at(x, 4, 15.57), C.Hazard)
	end
	part(rear, "MudFlap_L", Vector3.new(1.8, 2, 0.15), at(-5.9, 2.2, 13.4), C.Black)
	part(rear, "MudFlap_R", Vector3.new(1.8, 2, 0.15), at(5.9, 2.2, 13.4), C.Black)

	-- 15 à 20 Roues : pneu, jante dorée, cache noir -----------------------------------------------------------------------
	local wheels = {
		{ "FL", -1, -9.5 }, { "FR", 1, -9.5 },
		{ "ML", -1, 5.6 }, { "MR", 1, 5.6 },
		{ "RL", -1, 10.8 }, { "RR", 1, 10.8 },
	}
	for i, w in wheels do
		local m = P[14 + i]
		local x, z = w[2] * 5.9, w[3]
		cyl(m, `Tire_{w[1]}`, Vector3.new(1.8, 4.6, 4.6), at(x, 2.3, z), C.Black)
		cyl(m, `Hub_{w[1]}`, Vector3.new(1.9, 2.4, 2.4), at(x, 2.3, z), C.Gold)
		cyl(m, `HubCap_{w[1]}`, Vector3.new(2, 0.9, 0.9), at(x, 2.3, z), C.Black)
	end

	-- Cargo : le trésor du coffre (hors de Pieces : il reste sur place quand les murs partent) -----------------------------
	local cargo = group(model, "Cargo")
	for s, z in { 2.5, 10 } do
		local n = 0
		for layer, count in { 3, 2, 1 } do
			for k = 1, count do
				n += 1
				local x = -3.2 + (k - (count + 1) / 2) * 1.9
				local bar = part(cargo, `GoldBar_{s}_{n}`, Vector3.new(1.8, 0.7, 0.9), at(x, 4.9 + 0.35 + (layer - 1) * 0.7, z), C.Gold)
				bar.Reflectance = 0.1
			end
		end
	end
	for i, pos in { Vector3.new(3, 5.4, 3), Vector3.new(3, 6.4, 3), Vector3.new(3, 5.4, 9.5), Vector3.new(0.6, 5.4, 9.5) } do
		part(cargo, `CashBrick_{i}`, Vector3.new(2.2, 1, 1.4), CFrame.new(pos), C.Cash)
		part(cargo, `CashBand_{i}`, Vector3.new(2.25, 1.05, 0.4), CFrame.new(pos), C.Band)
	end
	for i, pos in { Vector3.new(0, 6.2, 5.5), Vector3.new(3.4, 6.2, 12.5) } do
		cyl(cargo, `MoneyBag_{i}`, Vector3.new(2.6, 2.4, 2.4), CFrame.new(pos) * UPRIGHT, C.Bag)
		cyl(cargo, `MoneyBagTie_{i}`, Vector3.new(0.6, 1, 1), CFrame.new(pos + Vector3.new(0, 1.6, 0)) * UPRIGHT, C.Tie)
	end

	local hl = Instance.new("Highlight")
	hl.Name = "OutlineHighlight"
	hl.FillTransparency = 1
	hl.OutlineColor = Color3.new(0, 0, 0)
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = model

	root.PivotOffset = CFrame.new(0, -root.Size.Y / 2, 0) -- pivot au sol, au centre (avec un PrimaryPart, WorldPivot est ignoré)
	return model
end

-- Pose -----------------------------------------------------------------------------------------------------------------
local function replace(parent: Instance, model: Model)
	local old = parent:FindFirstChild(model.Name)
	if old then
		old:Destroy()
	end
	model.Parent = parent
end

local report = {}
local van = build()
for _, d in van:GetDescendants() do
	assert(not d:IsA("LuaSourceContainer"), "script dans le modèle")
end

local showroom = workspace:FindFirstChild("_SHOWROOM_CLEMENT")
local events = showroom and showroom:FindFirstChild("ÉVÉNEMENT ET NUIT")
if events then
	local show = van:Clone()
	show.Name = "Show_ENV_Event_ArmoredVan"
	show:PivotTo(SHOW_PIVOT)
	replace(events, show)
	local pedName = "Ped_ENV_Event_ArmoredVan"
	local template = events:FindFirstChild("Ped_ENV_Event_Truck")
	if template and not events:FindFirstChild(pedName) then
		local ped = template:Clone()
		ped.Name = pedName
		ped.Position = PED_POS
		ped.Parent = events
	end
	local ped = events:FindFirstChild(pedName)
	if ped then
		local title = ped:FindFirstChild("Title", true)
		local status = ped:FindFirstChild("Status", true)
		if title then
			title.Text = "ENV_Event_ArmoredVan"
		end
		if status then
			status.Text = if MODE == "Asset" then "LIVRÉ · L-324" else "À VALIDER · L-313"
		end
	end
	table.insert(report, "vitrine : " .. show:GetFullName())
end

if MODE == "Asset" then
	local assets = game:GetService("ReplicatedStorage"):FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Events")
	assert(folder, "ReplicatedStorage/Assets/Events introuvable")
	replace(folder, van)
	table.insert(report, "asset : " .. van:GetFullName())
end

local count = 0
for _, d in van:GetDescendants() do
	if d:IsA("BasePart") then
		count += 1
	end
end
local _, size = van:GetBoundingBox()
table.insert(report, string.format("%d pièces, %.1f × %.1f × %.1f studs", count, size.X, size.Y, size.Z))
return table.concat(report, "\n")
