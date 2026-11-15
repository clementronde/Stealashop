--!nonstrict
-- hub_ui_build.luau (L-165, demande de Clément du 2026-11-14) : UI du hub façon « Steal a … ».
-- À lancer en Edit (barre de commande ou execute_luau). Annulable (ChangeHistoryService). N'écrase rien :
-- un élément déjà présent est sauté. Aucun script n'est posé.
--   1. ReplicatedStorage/Assets/UI/BB_ZoneLabel      : nom d'un stand ou d'une zone (Label, SubLabel facultatif)
--   2. ReplicatedStorage/Assets/UI/BB_RarestDisplay  : au-dessus de l'objet le plus rare (Header, Rarity, ItemName, Mutation, Odds)
--   3. ReplicatedStorage/Assets/UI/LeaderboardBoards/{Income,Speed}/Board : SurfaceGui des leaderboards
--   4. StarterGui/UI_Wheel (version grise)           : Wheel (Segment_01 à _08), SpinButton, CloseButton, Timer, Result

local CHS = game:GetService("ChangeHistoryService")
local RS = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local UIA = RS.Assets.UI
local HEAVY = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
local ROUND = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular)
local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)
local STUDS = "rbxassetid://3014551673"
local ICON_CASH = "rbxassetid://138179722277427"
local ICON_SPEED = "rbxassetid://80577187405028"

local report = {}

local function new(class: string, props: { [string]: any }, parent: Instance?): any
	local i = Instance.new(class)
	for k, v in props do
		(i :: any)[k] = v
	end
	if parent then
		i.Parent = parent
	end
	return i
end

local function stroke(parent: Instance, thickness: number, color: Color3?, mode: Enum.ApplyStrokeMode?)
	return new("UIStroke", {
		Thickness = thickness,
		Color = color or BLACK,
		ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Contextual,
		StrokeSizingMode = if mode == Enum.ApplyStrokeMode.Border then Enum.StrokeSizingMode.FixedSize else Enum.StrokeSizingMode.ScaledSize,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, parent)
end

local function corner(parent: Instance, scale: number?, offset: number?)
	return new("UICorner", { CornerRadius = UDim.new(scale or 0, offset or 0) }, parent)
end

local function gradient(parent: Instance, a: Color3, b: Color3, rotation: number?)
	return new("UIGradient", { Color = ColorSequence.new(a, b), Rotation = rotation or 90 }, parent)
end

-- Texte : TextScaled exige TextWrapped quand il est posé par script (mémoire ui-responsive-mobile).
local function text(name: string, value: string, parent: Instance, props: { [string]: any }?)
	local l = new("TextLabel", {
		Name = name,
		Text = value,
		BackgroundTransparency = 1,
		FontFace = HEAVY,
		TextColor3 = WHITE,
		TextScaled = true,
		TextWrapped = true,
		Size = UDim2.fromScale(1, 1),
	}, parent)
	for k, v in props or {} do
		(l :: any)[k] = v
	end
	return l
end

local function skip(parent: Instance, name: string): boolean
	if parent:FindFirstChild(name) then
		table.insert(report, `{name} : déjà là, sauté`)
		return true
	end
	return false
end

------------------------------------------------------------------------------
-- 1. BB_ZoneLabel : gros texte arrondi à contour épais (« SELL », « FREE! »), lisible de loin et la nuit.
-- Le code écrit Label (texte traduit, clé dans l'attribut LabelKey du LabelPoint) ; couleur facultative :
-- attribut LabelColor (Color3) du LabelPoint, posée sur Label.TextColor3 (le dégradé blanc → gris
-- garde l'ombré quelle que soit la couleur). SubLabel : 2e ligne facultative (« +15% MONEY PER FRIEND »).
------------------------------------------------------------------------------
local function buildZoneLabel()
	if skip(UIA, "BB_ZoneLabel") then
		return
	end
	local bb = new("BillboardGui", {
		Name = "BB_ZoneLabel",
		Size = UDim2.new(26, 0, 7, 0),
		SizeOffset = Vector2.new(0, 0.5), -- le bas du billboard au point
		MaxDistance = 300,
		LightInfluence = 0,
		AlwaysOnTop = false,
		ClipsDescendants = false,
		ResetOnSpawn = false,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, bb)
	local label = text("Label", "FREE!", bb, {
		FontFace = ROUND,
		TextColor3 = Color3.fromHex("ffd23a"),
		Size = UDim2.fromScale(1, 0.68),
		LayoutOrder = 1,
	})
	gradient(label, WHITE, Color3.fromHex("c9c9c9"), 90)
	stroke(label, 0.12, Color3.fromHex("140a26"))
	local sub = text("SubLabel", "+15% MONEY PER FRIEND", bb, {
		FontFace = ROUND,
		Size = UDim2.fromScale(1, 0.32),
		LayoutOrder = 2,
		Visible = false,
	})
	stroke(sub, 0.12, Color3.fromHex("140a26"))
	bb.Parent = UIA
	table.insert(report, "BB_ZoneLabel : construit")
end

------------------------------------------------------------------------------
-- 2. BB_RarestDisplay : texte flottant au-dessus du grand socle (pas de plaque : l'objet est à taille réelle).
------------------------------------------------------------------------------
local function buildRarestDisplay()
	if skip(UIA, "BB_RarestDisplay") then
		return
	end
	local bb = new("BillboardGui", {
		Name = "BB_RarestDisplay",
		Size = UDim2.new(16, 0, 7.5, 0),
		SizeOffset = Vector2.new(0, 0.5),
		MaxDistance = 200,
		LightInfluence = 0,
		AlwaysOnTop = false,
		ClipsDescendants = false,
		ResetOnSpawn = false,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, bb)
	local rows = {
		{ "Header", "RAREST PULL", 0.15, "ffd23a" },
		{ "Rarity", "SECRET", 0.19, "ffffff" },
		{ "ItemName", "Magma Rhino", 0.30, "ffffff" },
		{ "Mutation", "BIG GOLD", 0.16, "ffc21a" },
		{ "Odds", "1 in 5,300,000,000", 0.20, "ffe08a" },
	}
	for i, r in rows do
		local l = text(r[1], r[2], bb, {
			Size = UDim2.fromScale(1, r[3]),
			TextColor3 = Color3.fromHex(r[4]),
			LayoutOrder = i,
			Visible = r[1] ~= "Mutation", -- caché sans mutation, comme dans BB_Item
		})
		stroke(l, 0.1)
	end
	bb.Parent = UIA
	table.insert(report, "BB_RarestDisplay : construit")
end

------------------------------------------------------------------------------
-- 3. Leaderboards : SurfaceGui Board (FixedSize 800 × 1000, s'adapte à la pièce), vert (Income) et violet (Speed).
------------------------------------------------------------------------------
local PALETTES = {
	Income = {
		Title = "MOST MONEY/S", Subtitle = "Best of all time", Icon = ICON_CASH,
		Back = "e9f7e6", HeadA = "6fe36a", HeadB = "2fae46", PillA = "62d65c", PillB = "2a9a3c", Value = "$787.6M/s",
	},
	Speed = {
		Title = "FASTEST", Subtitle = "Base speed", Icon = ICON_SPEED,
		Back = "f0eafc", HeadA = "b48cff", HeadB = "7446dc", PillA = "a88af6", PillB = "6640d2", Value = "2.42M",
	},
}

local function buildBoard(stat: string, folder: Folder)
	local holder = folder:FindFirstChild(stat) or new("Folder", { Name = stat }, folder)
	if skip(holder, "Board") then
		return
	end
	local p = PALETTES[stat]
	local board = new("SurfaceGui", {
		Name = "Board",
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
		CanvasSize = Vector2.new(800, 1000),
		LightInfluence = 0,
		MaxDistance = 150,
		AlwaysOnTop = false,
		ResetOnSpawn = false,
		ClipsDescendants = true,
	})
	board:SetAttribute("Stat", stat)
	-- Couleurs des pastilles de rang, proposées au code (rangs 1 à 3, puis les autres).
	board:SetAttribute("Rank1Color", Color3.fromHex("ffc93a"))
	board:SetAttribute("Rank2Color", Color3.fromHex("cfd5df"))
	board:SetAttribute("Rank3Color", Color3.fromHex("e39a5a"))
	board:SetAttribute("RankColor", Color3.fromHex("8f98a8"))

	local back = new("Frame", {
		Name = "Background", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromHex(p.Back), BorderSizePixel = 0,
	}, board)
	corner(back, 0.03)
	stroke(back, 10, Color3.fromHex("1b1f27"), Enum.ApplyStrokeMode.Border)

	local header = new("Frame", {
		Name = "Header", Position = UDim2.fromScale(0.03, 0.025), Size = UDim2.fromScale(0.94, 0.17),
		BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 2,
	}, board)
	corner(header, 0.12)
	gradient(header, Color3.fromHex(p.HeadA), Color3.fromHex(p.HeadB), 90)
	stroke(header, 6, Color3.fromHex("1b1f27"), Enum.ApplyStrokeMode.Border)
	local studs = new("ImageLabel", {
		Name = "Studs", Image = STUDS, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		ImageTransparency = 0.8, ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(48, 48), ZIndex = 3,
	}, header)
	corner(studs, 0.12)
	for _, side in { { "LeftIcon", 0.02, 0 }, { "RightIcon", 0.98, 1 } } do
		local icon = new("ImageLabel", {
			Name = side[1], Image = p.Icon, BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit,
			AnchorPoint = Vector2.new(side[3], 0.5), Position = UDim2.fromScale(side[2], 0.5), Size = UDim2.fromScale(0.17, 0.82), ZIndex = 5,
		}, header)
		new("UIAspectRatioConstraint", { AspectRatio = 1 }, icon)
	end
	stroke(text("Title", p.Title, header, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.08), Size = UDim2.fromScale(0.6, 0.52), ZIndex = 5,
	}), 0.1)
	stroke(text("Subtitle", p.Subtitle, header, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromScale(0.6, 0.28), ZIndex = 5,
	}), 0.1)

	local list = new("Frame", {
		Name = "List", Position = UDim2.fromScale(0.03, 0.215), Size = UDim2.fromScale(0.94, 0.765),
		BackgroundTransparency = 1, ZIndex = 2,
	}, board)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0.012, 0),
	}, list)
	local row = new("Frame", {
		Name = "Template", Size = UDim2.fromScale(1, 0.0892), BackgroundColor3 = WHITE, BorderSizePixel = 0,
		Visible = false, ZIndex = 3,
	}, list)
	corner(row, 0.22)
	stroke(row, 4, Color3.fromHex("1b1f27"), Enum.ApplyStrokeMode.Border)
	-- Rang : TextLabel avec son fond (la couleur des rangs 1 à 3 : attributs Rank1Color… de Board).
	local rank = text("Rank", "1", row, {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.012, 0.5), Size = UDim2.fromScale(0.1, 0.78),
		BackgroundTransparency = 0, BackgroundColor3 = board:GetAttribute("Rank1Color"), TextColor3 = Color3.fromHex("1b1f27"), ZIndex = 4,
	})
	new("UIAspectRatioConstraint", { AspectRatio = 1 }, rank)
	corner(rank, 0.22)
	new("UIStroke", {
		Thickness = 3, Color = Color3.fromHex("1b1f27"), ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Round,
	}, rank)
	new("UIPadding", { PaddingTop = UDim.new(0.14, 0), PaddingBottom = UDim.new(0.14, 0) }, rank)
	local avatar = new("ImageLabel", {
		Name = "Avatar", Image = "", BackgroundColor3 = Color3.fromHex("c9ced6"), BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.125, 0.5), Size = UDim2.fromScale(0.1, 0.78),
		ScaleType = Enum.ScaleType.Crop, ZIndex = 4,
	}, row)
	new("UIAspectRatioConstraint", { AspectRatio = 1 }, avatar)
	corner(avatar, 0.5)
	stroke(avatar, 3, Color3.fromHex("1b1f27"), Enum.ApplyStrokeMode.Border)
	text("PlayerName", "PlayerName123", row, {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.245, 0.5), Size = UDim2.fromScale(0.39, 0.56),
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromHex("1b1f27"), ZIndex = 4,
	})
	-- Pastille de la valeur : un Frame à part (un UIGradient sur un TextLabel teinterait aussi le texte).
	local pill = new("Frame", {
		Name = "ValuePill", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(0.985, 0.5), Size = UDim2.fromScale(0.34, 0.76),
		BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 4,
	}, row)
	corner(pill, 0.25)
	gradient(pill, Color3.fromHex(p.PillA), Color3.fromHex(p.PillB), 90)
	stroke(pill, 3, Color3.fromHex("1b1f27"), Enum.ApplyStrokeMode.Border)
	local value = text("Value", p.Value, row, {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(0.965, 0.5), Size = UDim2.fromScale(0.31, 0.6), ZIndex = 5,
	})
	stroke(value, 0.1)
	board.Parent = holder
	table.insert(report, `LeaderboardBoards/{stat}/Board : construit`)
end

local function buildBoards()
	local folder = UIA:FindFirstChild("LeaderboardBoards") or new("Folder", { Name = "LeaderboardBoards" }, UIA)
	buildBoard("Income", folder)
	buildBoard("Speed", folder)
end

------------------------------------------------------------------------------
-- 4. UI_Wheel, version grise : bons noms, aucun style. La roue à gauche (carrée, à la hauteur de la
-- fenêtre : le téléphone en paysage est limité en hauteur), la colonne des boutons à droite.
------------------------------------------------------------------------------
local GRAY_DARK, GRAY, GRAY_LIGHT = Color3.fromHex("4a4a4a"), Color3.fromHex("7a7a7a"), Color3.fromHex("a8a8a8")

local function grayButton(name: string, labelName: string, value: string, parent: Instance, props: { [string]: any })
	local b = new("TextButton", {
		Name = name, Text = "", AutoButtonColor = true, BackgroundColor3 = GRAY_LIGHT, BorderSizePixel = 0,
	}, parent)
	for k, v in props do
		(b :: any)[k] = v
	end
	text(labelName, value, b, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.82, 0.62),
		TextColor3 = Color3.fromHex("1b1f27"), ZIndex = b.ZIndex + 1,
	})
	return b
end

local function buildWheel()
	if skip(StarterGui, "UI_Wheel") then
		return
	end
	local model = StarterGui:FindFirstChild("UI_Rebirth")
	local gui = new("ScreenGui", {
		Name = "UI_Wheel", Enabled = false, DisplayOrder = 5, ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	if model then
		gui.ScreenInsets = model.ScreenInsets
		gui.IgnoreGuiInset = model.IgnoreGuiInset
		gui.ZIndexBehavior = model.ZIndexBehavior
		gui.ResetOnSpawn = model.ResetOnSpawn
		gui.DisplayOrder = model.DisplayOrder
		for k, v in model:GetAttributes() do
			gui:SetAttribute(k, v) -- ScreenGroup = Menu
		end
	end
	local root = new("Frame", {
		Name = "Root", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 0.92), BackgroundTransparency = 1,
	}, gui)
	new("UIAspectRatioConstraint", { AspectRatio = 1.5, AspectType = Enum.AspectType.FitWithinMaxSize, DominantAxis = Enum.DominantAxis.Width }, root)
	new("UISizeConstraint", { MaxSize = Vector2.new(900, 600) }, root)
	local window = new("Frame", {
		Name = "Window", Size = UDim2.fromScale(1, 1), BackgroundColor3 = GRAY_DARK, BorderSizePixel = 0,
	}, root)
	corner(window, 0.03)
	text("Title", "Spin the Wheel", window, {
		Position = UDim2.fromScale(0.03, 0.03), Size = UDim2.fromScale(0.5, 0.11), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2,
	})
	local close = grayButton("CloseButton", "XLabel", "X", window, {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(0.985, 0.025), Size = UDim2.fromScale(0.08, 0.12), ZIndex = 3,
	})
	new("UIAspectRatioConstraint", { AspectRatio = 1 }, close)
	new("UISizeConstraint", { MinSize = Vector2.new(44, 44) }, close)

	-- La roue : Wheel tourne (Rotation), ses segments tournent avec elle. Pointer reste fixe.
	local area = new("Frame", {
		Name = "WheelArea", Position = UDim2.fromScale(0.03, 0.16), Size = UDim2.fromScale(0.54, 0.8), BackgroundTransparency = 1,
	}, window)
	local wheel = new("ImageLabel", {
		Name = "Wheel", Image = "", BackgroundColor3 = GRAY, BorderSizePixel = 0, ScaleType = Enum.ScaleType.Fit,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(0.94, 0.94), ZIndex = 2,
	}, area)
	new("UIAspectRatioConstraint", { AspectRatio = 1 }, wheel)
	corner(wheel, 0.5)
	for k = 0, 3 do
		new("Frame", {
			Name = `Divider_{k + 1}`, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.008, 1), Rotation = k * 45, BackgroundColor3 = GRAY_DARK, BorderSizePixel = 0, ZIndex = 3,
		}, wheel)
	end
	for n = 1, 8 do
		local angle = math.rad((n - 1) * 45 + 22.5) -- milieu du segment, depuis le haut, sens horaire
		local seg = new("Frame", {
			Name = string.format("Segment_%02d", n), BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + 0.31 * math.sin(angle), 0.5 - 0.31 * math.cos(angle)),
			Size = UDim2.fromScale(0.2, 0.2), Rotation = (n - 1) * 45 + 22.5, ZIndex = 4,
		}, wheel)
		new("ImageLabel", {
			Name = "Icon", Image = "", BackgroundColor3 = GRAY_LIGHT, BorderSizePixel = 0, ScaleType = Enum.ScaleType.Fit,
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.6, 0.6), ZIndex = 5,
		}, seg)
		text("Amount", "$10K", seg, { Position = UDim2.fromScale(0, 0.62), Size = UDim2.fromScale(1, 0.36), ZIndex = 5 })
	end
	local hub = new("Frame", {
		Name = "Hub", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.16, 0.16),
		BackgroundColor3 = GRAY_DARK, BorderSizePixel = 0, ZIndex = 6,
	}, wheel)
	corner(hub, 0.5)
	new("Frame", {
		Name = "Pointer", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.07, 0.11),
		BackgroundColor3 = Color3.fromHex("d9d9d9"), BorderSizePixel = 0, ZIndex = 7,
	}, area)
	local result = text("Result", "You won $50K!", area, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(0.9, 0.18),
		BackgroundTransparency = 0.25, BackgroundColor3 = Color3.fromHex("2a2a2a"), Visible = false, ZIndex = 8,
	})
	corner(result, 0.2)

	-- Colonne de droite : bouton et chrono du prochain tour gratuit.
	local side = new("Frame", {
		Name = "Side", Position = UDim2.fromScale(0.6, 0.16), Size = UDim2.fromScale(0.37, 0.8), BackgroundTransparency = 1,
	}, window)
	text("Info", "1 free spin every 24h", side, { Position = UDim2.fromScale(0, 0.1), Size = UDim2.fromScale(1, 0.17) })
	local spin = grayButton("SpinButton", "SpinLabel", "SPIN", side, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromScale(0.86, 0.22), ZIndex = 2,
	})
	new("UISizeConstraint", { MinSize = Vector2.new(120, 44) }, spin)
	text("Timer", "Free spin in 23:59:59", side, { Position = UDim2.fromScale(0, 0.62), Size = UDim2.fromScale(1, 0.17) })

	gui.Parent = StarterGui
	table.insert(report, "UI_Wheel : construit (version grise, Enabled = false)")
end

local rec = CHS:TryBeginRecording("UI du hub (L-165) : BB_ZoneLabel, BB_RarestDisplay, leaderboards, UI_Wheel")
local ok, err = pcall(function()
	buildZoneLabel()
	buildRarestDisplay()
	buildBoards()
	buildWheel()
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return table.concat(report, "\n")
