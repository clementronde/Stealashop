--!nonstrict
-- ui_tas_robuxshop.luau (demande de Clément du 2026-11-17, d'après Throw a Seed, note section 4) : UI_RobuxShop_v2.
--   - Onglets dans la fenêtre, à droite (comme chez eux) : Window.List passe de 96,8 % à 83 % de la largeur,
--     ScrollTrack suit, Root.Tabs se pose dans la colonne libre (86,5 % → 98,5 %). Noms inchangés.
--   - Coffre et pack de départ en 3D : Crate.Preview et Featured.Preview (ViewportFrame vides, transparents, posés sur
--     leur Icon) : le code y met un modèle et fait balancer la caméra ; vides, l'Icon se voit dessous.
--   - Réduction du pack de départ (Featured) : OldPrice (ancien prix, petit, crème à contour brun, pas barré, au coin du
--     bouton), BuyButton.OfferLabel « ONE TIME OFFER » sous le prix (BuyButton.Content remonte), DiscountTag (étiquette
--     jaune penchée de 5°, DiscountLabel « ??% OFF ») au coin haut droit du bouton, entièrement dans la carte. Prix,
--     ancien prix et pourcentage : à poser par le code (« ??? » ici, rien d'inventé). Timer existe déjà.
--   - Rayons derrière les offres : déjà là (Crate.Backdrop.Rays, Clip.Rays de chaque carte) ; leur rotation est au code.
-- Sauvegarde dans ServerStorage/MapBackups/2026-11-17_ThrowASeed/UI_RobuxShop_v2 (faite par ui_tas_boutons.luau, sinon
-- ici). À lancer en Edit après ui_tas_boutons.luau. Annulable. Aucun script.

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")

local gui = SG.UI_RobuxShop_v2
local root = gui.Root
local window = root.Window
local content = window.List.Content

local HEAVY = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)

local function label(name, parent, text, color, strokeColor, z)
	local t = Instance.new("TextLabel")
	t.Name = name
	t.Text = text
	t.FontFace = HEAVY
	t.TextScaled = true
	t.TextWrapped = true
	t.TextColor3 = color
	t.BackgroundTransparency = 1
	t.ZIndex = z
	local s = Instance.new("UIStroke")
	s.Thickness = 0.14
	s.Color = strokeColor
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = t
	t.Parent = parent
	return t
end
local function viewport(over)
	local v = over.Parent:FindFirstChild("Preview") or Instance.new("ViewportFrame")
	v.Name = "Preview"
	v.BackgroundTransparency = 1
	v.AnchorPoint = over.AnchorPoint
	v.Position = over.Position
	v.Size = over.Size
	v.ZIndex = over.ZIndex
	v.LightDirection = Vector3.new(-1, -1, -1)
	v.Ambient = Color3.fromRGB(200, 200, 200)
	v.Parent = over.Parent
	return v
end

local rec = CHS:TryBeginRecording("UI : boutique Robux façon Throw a Seed (onglets dedans, réduction, 3D)")
local ok, err = pcall(function()
	local folder = SS.MapBackups:FindFirstChild("2026-11-17_ThrowASeed")
	if folder and not folder:FindFirstChild("UI_RobuxShop_v2") then
		local copy = gui:Clone()
		copy.Enabled = false
		copy.Parent = folder
	end

	-- Onglets dans la fenêtre.
	local list = window.List
	list.Size = UDim2.fromScale(0.83, list.Size.Y.Scale)
	local track = window:FindFirstChild("ScrollTrack")
	if track then
		track.Position = UDim2.new(0.852, 0, track.Position.Y.Scale, 0)
	end
	local tabs = root.Tabs
	tabs.AnchorPoint = Vector2.new(0, 0)
	tabs.Position = UDim2.fromScale(0.865, 0.17)
	tabs.Size = UDim2.fromScale(0.12, 0.8)

	-- 3D.
	viewport(content.Crate.Icon)
	local featured = content.Featured
	viewport(featured.Icon)

	-- Réduction du pack de départ.
	local buy = featured.BuyButton
	local z = buy.ZIndex
	local box = buy:FindFirstChild("Content")
	if box then
		box.Position = UDim2.fromScale(0, 0.1)
		box.Size = UDim2.fromScale(1, 0.5)
	end
	if not buy:FindFirstChild("OfferLabel") then
		local offer = label("OfferLabel", buy, "ONE TIME OFFER", Color3.new(1, 1, 1), Color3.fromHex("113909"), z + 6)
		offer.Position = UDim2.fromScale(0.06, 0.6)
		offer.Size = UDim2.fromScale(0.88, 0.25)
	end
	if not featured:FindFirstChild("OldPrice") then
		local old = label("OldPrice", featured, "???", Color3.fromHex("fff1d6"), Color3.fromHex("5a2d00"), z + 8)
		old.AnchorPoint = Vector2.new(0, 1)
		old.Position = UDim2.fromScale(0.724, 0.43)
		old.Size = UDim2.fromScale(0.09, 0.14)
		old.TextXAlignment = Enum.TextXAlignment.Left
	end
	if not featured:FindFirstChild("DiscountTag") then
		local tag = Instance.new("Frame")
		tag.Name = "DiscountTag"
		tag.AnchorPoint = Vector2.new(1, 0.5)
		tag.Position = UDim2.fromScale(0.985, 0.37)
		tag.Size = UDim2.fromScale(0.105, 0.17)
		tag.Rotation = 5
		tag.BackgroundColor3 = Color3.new(1, 1, 1)
		tag.BorderSizePixel = 0
		tag.ZIndex = z + 8
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Color = ColorSequence.new(Color3.fromHex("ffe766"), Color3.fromHex("ffb81f"))
		g.Parent = tag
		local s = Instance.new("UIStroke")
		s.Thickness = 0.08
		s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Color = Color3.fromHex("5a2d00")
		s.Parent = tag
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.06, 0)
		c.Parent = tag
		local t = label("DiscountLabel", tag, "??% OFF", Color3.new(1, 1, 1), Color3.fromHex("5a2d00"), z + 9)
		t.Position = UDim2.fromScale(0.06, 0.12)
		t.Size = UDim2.fromScale(0.88, 0.76)
		tag.Parent = featured
	end
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "boutique Robux : onglets dedans, réduction, 3D"
