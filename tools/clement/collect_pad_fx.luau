--[[
	collect_pad_fx.luau (Clément, MOD-015 / L-082) : case de ramassage « satisfaisante ».
	À envoyer d'un bloc à execute_luau en Edit. Relançable : une case déjà faite est sautée.

	1. Chaque CollectPad_xx (gabarit PLOT_Shop, PLOT_Shop_Rayons et parcelles PlayerPlot du Workspace)
	   devient un seul rectangle au sol : la pièce CollectPad_xx, invisible, est le volume que le code
	   détecte ; sa plaque Plate (néon vert, même taille), que le code peut enfoncer de SinkDepth, est
	   le seul rectangle visible. Sur Plate : SurfaceGui AmountGui (dessus) > TextLabel
	   Amount (« $0 »), où le code écrit le montant de l'objet. Dans Plate : l'Attachment BurstPoint avec
	   3 ParticleEmitter éteints (Sparkles, Ring, Coins, attribut EmitCount) et une PointLight Glow
	   éteinte. Aucun script.
	2. Modèles volants dans ReplicatedStorage/Assets/FX : FX_Collect_Bill (billet) et
	   FX_Collect_Coin (pièce), chacun avec sa Trail, que le code clone.
	Le code (Ironix) anime tout : voir la note partagée « case-ramassage ».
]]

local CS = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")

local rgb = Color3.fromRGB
local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
local TEX_SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local TEX_RING = "rbxasset://textures/particles/explosion01_shockwave_main.dds"
local TEX_SQUARE = "rbxasset://textures/particles/SquareParticle.png"

local GREEN = rgb(53, 201, 59)
local GOLD = rgb(255, 196, 40)
local PLATE_THICK = 0.12

local function ns(...) return NumberSequence.new(...) end
local function nsk(t) local k = {} for _, p in t do table.insert(k, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0)) end return NumberSequence.new(k) end
local function cs(a, b) return ColorSequence.new(a, b) end

local function quiet(p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
end

-- montant de l'objet sur le dessus de la plaque (Clément, 2026-11-10) : SurfaceGui AmountGui >
-- TextLabel Amount, que le code remplit (« $1.2K »)
local function dollarGui(parent: Instance, face: Enum.NormalId, ppS: number, color: Color3, stroke: Color3)
	local g = Instance.new("SurfaceGui")
	g.Name = "AmountGui"
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = ppS
	g.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.Name = "Amount"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Text = "$0"
	t.TextScaled = true
	t.TextWrapped = true
	t.TextColor3 = color
	t.FontFace = FONT
	local s = Instance.new("UIStroke")
	s.Color = stroke
	s.Thickness = 3
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = t
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.2, 0); pad.PaddingBottom = UDim.new(0.2, 0)
	pad.PaddingLeft = UDim.new(0.06, 0); pad.PaddingRight = UDim.new(0.06, 0)
	pad.Parent = t
	t.Parent = g
	g.Parent = parent
	return g
end

local function emitter(parent: Instance, name: string, props: { [string]: any }, emitCount: number)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Enabled = false -- le code appelle Emit(EmitCount)
	e.Rate = 0
	for k, v in props do
		(e :: any)[k] = v
	end
	e:SetAttribute("EmitCount", emitCount)
	e.Parent = parent
	return e
end

-- 1. Case : une seule plaque au sol -----------------------------------------------------------------
-- (Clément, 2026-11-10 : un seul rectangle par objet, plus de cadre doré.) CollectPad_xx devient le
-- volume invisible que le code détecte ; Plate, de la même taille, est le seul rectangle visible.

local PLATE_SINK = 0.1 -- de combien le code peut enfoncer la plaque, vers le bas du monde (studs)

-- Plaque carrée couchée (Clément, 2026-11-11) : face Front (-Z local) vers le ciel, haut (+Y local) vers la
-- porte de la boutique, pour que le montant se lise à l'endroit en marchant vers la sortie. CollectPad_xx
-- (posé ainsi par plot_shop_builder.luau) donne l'orientation ; Plate prend le même volume.
local function shapePlate(pad: BasePart, plate: BasePart)
	pad.Transparency = 1
	pad.CastShadow = false
	pad.CanTouch = true
	plate.Size = pad.Size
	plate.CFrame = pad.CFrame
	plate:SetAttribute("SinkDepth", PLATE_SINK)
	for _, g in plate:GetChildren() do
		if g:IsA("SurfaceGui") then g:Destroy() end
	end
	dollarGui(plate, Enum.NormalId.Front, 40, Color3.new(1, 1, 1), rgb(20, 90, 30))
	local burst = plate:FindFirstChild("BurstPoint")
	-- axes du monde : les émetteurs (EmissionDirection Top) tirent vers le ciel
	if burst then burst.WorldCFrame = CFrame.new(pad.Position + Vector3.new(0, PLATE_THICK / 2, 0)) end
end

local function upgradePad(pad: BasePart): boolean
	for _, g in pad:GetChildren() do
		if g:IsA("SurfaceGui") then g:Destroy() end
	end
	local done = pad:FindFirstChild("Plate")
	if done then
		-- case déjà faite (ancien cadre doré + plaque) : passe à la plaque unique
		shapePlate(pad, done :: BasePart)
		return true
	end

	local plate = Instance.new("Part")
	plate.Name = "Plate"
	quiet(plate)
	plate.Material = Enum.Material.Neon
	plate.Color = GREEN
	shapePlate(pad, plate)

	local burst = Instance.new("Attachment")
	burst.Name = "BurstPoint"
	burst.Parent = plate
	burst.WorldCFrame = CFrame.new(pad.Position + Vector3.new(0, PLATE_THICK / 2, 0))

	emitter(burst, "Sparkles", {
		Texture = TEX_SPARK,
		Color = cs(rgb(255, 245, 170), rgb(140, 255, 120)),
		LightEmission = 1,
		LightInfluence = 0,
		Size = nsk({ { 0, 0.55 }, { 0.6, 0.35 }, { 1, 0 } }),
		Transparency = nsk({ { 0, 0 }, { 0.7, 0.1 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.45, 0.8),
		Speed = NumberRange.new(9, 16),
		SpreadAngle = Vector2.new(40, 40),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, -22, 0),
		Drag = 2.5,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-180, 180),
		ZOffset = 1,
	}, 22)

	emitter(burst, "Ring", {
		Texture = TEX_RING,
		Color = cs(rgb(200, 255, 190), rgb(90, 230, 90)),
		LightEmission = 1,
		LightInfluence = 0,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top,
		Speed = NumberRange.new(0.01),
		SpreadAngle = Vector2.new(0, 0),
		Size = nsk({ { 0, 0.6 }, { 1, 4.2 } }),
		Transparency = nsk({ { 0, 0.1 }, { 0.5, 0.35 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.35),
		Rotation = NumberRange.new(0, 360),
	}, 1)

	emitter(burst, "Coins", {
		Texture = TEX_SQUARE,
		Color = cs(rgb(255, 214, 60), rgb(255, 170, 30)),
		LightEmission = 0.4,
		Size = nsk({ { 0, 0.22 }, { 0.8, 0.2 }, { 1, 0 } }),
		Transparency = ns(0),
		Lifetime = NumberRange.new(0.6, 0.9),
		Speed = NumberRange.new(12, 18),
		SpreadAngle = Vector2.new(30, 30),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, -45, 0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-400, 400),
	}, 10)

	local glow = Instance.new("PointLight")
	glow.Name = "Glow"
	glow.Enabled = false -- le code l'allume un instant à l'encaissement
	glow.Color = rgb(120, 255, 120)
	glow.Brightness = 0.8 -- L-087 : la zone safe était trop lumineuse de jour
	glow.Range = 6
	glow.Shadows = false
	glow.Parent = plate

	plate.Parent = pad
	return true
end

local function upgradeAll(root: Instance): number
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and d.Name:match("^CollectPad_%d%d$") then
			if upgradePad(d) then n += 1 end
		end
	end
	return n
end

-- 2. Billet et pièce volants ---------------------------------------------------------------------

local function trailOn(part: BasePart, halfWidth: number, axis: Vector3, colorA: Color3, colorB: Color3)
	local a0 = Instance.new("Attachment"); a0.Name = "TrailA"; a0.Position = axis * halfWidth; a0.Parent = part
	local a1 = Instance.new("Attachment"); a1.Name = "TrailB"; a1.Position = -axis * halfWidth; a1.Parent = part
	local t = Instance.new("Trail")
	t.Name = "Trail"
	t.Attachment0 = a0
	t.Attachment1 = a1
	t.Lifetime = 0.3
	t.MinLength = 0.02
	t.FaceCamera = true
	t.LightEmission = 0.7
	t.LightInfluence = 0
	t.Color = cs(colorA, colorB)
	t.Transparency = nsk({ { 0, 0.15 }, { 0.6, 0.55 }, { 1, 1 } })
	t.WidthScale = nsk({ { 0, 1 }, { 1, 0 } })
	t.Enabled = true -- ne dessine que pendant le vol
	t.Parent = part
	return t
end

local function makeTemplates(fx: Instance)
	for _, name in { "FX_Collect_Bill", "FX_Collect_Coin" } do
		local old = fx:FindFirstChild(name)
		if old and old:GetAttribute("BuiltBy") == "collect_pad_fx" then old:Destroy() end
	end
	if not fx:FindFirstChild("FX_Collect_Bill") then
		local m = Instance.new("Model")
		m.Name = "FX_Collect_Bill"
		m:SetAttribute("BuiltBy", "collect_pad_fx")
		local bill = Instance.new("Part")
		bill.Name = "Bill"
		quiet(bill)
		bill.Material = Enum.Material.SmoothPlastic
		bill.Color = rgb(118, 205, 98)
		bill.Size = Vector3.new(1.4, 0.05, 0.7)
		bill.CFrame = CFrame.new()
		for _, face in { Enum.NormalId.Top, Enum.NormalId.Bottom } do
			local g = Instance.new("SurfaceGui")
			g.Name = "Print_" .. face.Name
			g.Face = face
			g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			g.PixelsPerStud = 100
			g.LightInfluence = 0.6
			local f = Instance.new("Frame")
			f.Name = "Border"
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.Position = UDim2.fromScale(0.5, 0.5)
			f.Size = UDim2.fromScale(0.88, 0.8)
			f.BackgroundTransparency = 1
			local st = Instance.new("UIStroke"); st.Color = rgb(40, 120, 45); st.Thickness = 4; st.Parent = f
			local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.15, 0); c.Parent = f
			local o = Instance.new("Frame")
			o.Name = "Seal"
			o.AnchorPoint = Vector2.new(0.5, 0.5)
			o.Position = UDim2.fromScale(0.5, 0.5)
			o.Size = UDim2.fromScale(0.42, 0.84)
			o.BackgroundColor3 = rgb(225, 250, 210)
			local oc = Instance.new("UICorner"); oc.CornerRadius = UDim.new(0.5, 0); oc.Parent = o
			local t = Instance.new("TextLabel")
			t.Name = "Label"
			t.BackgroundTransparency = 1
			t.Size = UDim2.fromScale(1, 1)
			t.Text = "$"
			t.TextScaled = true
			t.TextColor3 = rgb(30, 110, 40)
			t.FontFace = FONT
			t.Parent = o
			o.Parent = f
			f.Parent = g
			g.Parent = bill
		end
		trailOn(bill, 0.3, Vector3.new(0, 0, 1), rgb(170, 255, 150), rgb(255, 240, 150))
		bill.Parent = m
		m.PrimaryPart = bill
		m.Parent = fx
	end
	if not fx:FindFirstChild("FX_Collect_Coin") then
		local m = Instance.new("Model")
		m.Name = "FX_Collect_Coin"
		m:SetAttribute("BuiltBy", "collect_pad_fx")
		local coin = Instance.new("Part")
		coin.Name = "Coin"
		coin.Shape = Enum.PartType.Cylinder
		quiet(coin)
		coin.Material = Enum.Material.SmoothPlastic
		coin.Reflectance = 0.15
		coin.Color = GOLD
		coin.Size = Vector3.new(0.12, 0.75, 0.75) -- axe du cylindre = X
		coin.CFrame = CFrame.new()
		local face = Instance.new("Part")
		face.Name = "Face"
		face.Shape = Enum.PartType.Cylinder
		quiet(face)
		face.Material = Enum.Material.SmoothPlastic
		face.Color = rgb(255, 228, 110)
		face.Size = Vector3.new(0.14, 0.52, 0.52)
		face.CFrame = CFrame.new()
		face.Parent = coin
		trailOn(coin, 0.25, Vector3.new(0, 1, 0), rgb(255, 235, 120), rgb(255, 170, 40))
		coin.Parent = m
		m.PrimaryPart = coin
		m.Parent = fx
	end
end

-- Lancement --------------------------------------------------------------------------------------

local report = {}
local fx = RS:FindFirstChild("Assets") and RS.Assets:FindFirstChild("FX")
if fx then
	makeTemplates(fx)
	table.insert(report, "FX_Collect_Bill et FX_Collect_Coin dans Assets/FX")
end
local gabarit = RS:FindFirstChild("Assets") and RS.Assets:FindFirstChild("Plots") and RS.Assets.Plots:FindFirstChild("PLOT_Shop")
if gabarit then
	table.insert(report, "gabarit PLOT_Shop : " .. upgradeAll(gabarit) .. " case(s)")
end
-- visuels des rangées 2 à 5 (L-082), que le code copie dans la boutique avec leurs cases
local rayons = RS:FindFirstChild("Assets") and RS.Assets:FindFirstChild("Plots") and RS.Assets.Plots:FindFirstChild("PLOT_Shop_Rayons")
if rayons then
	table.insert(report, "PLOT_Shop_Rayons : " .. upgradeAll(rayons) .. " case(s)")
end
for _, plot in CS:GetTagged("PlayerPlot") do
	if plot:IsDescendantOf(workspace) then
		table.insert(report, plot:GetFullName() .. " : " .. upgradeAll(plot) .. " case(s)")
	end
end
return table.concat(report, "\n")
