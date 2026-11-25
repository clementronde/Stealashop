-- Lot D (L-380) : nouvel écran d'inventaire, VERSION GRISE (bons noms, aucun style), à valider par Clément.
-- Construction reprise de la référence E (e2_inventaire_67s.jpg) : fenêtre posée juste au-dessus de la barre du bas,
-- colonne d'onglets carrés à gauche, titre et compteur en haut, recherche en haut à droite, croix sur le coin, grille
-- de cartes. Contenu de notre jeu : onglets ITEMS, WEAPONS, POTIONS ; bouton EQUIP BEST ; « 4 / 6 displays ».
-- Noms : ceux que lit déjà InventoryController (Contract/UI, écran UI_Inventory). L'écran est construit sous le nom
-- provisoire UI_Inventory_Gris, que le code ne lit pas : il prendra le nom UI_Inventory une fois habillé et validé.
-- À lancer dans Studio en Edit. Refait l'écran à chaque lancement (l'ancien UI_Inventory_Gris est remplacé).
--
-- Tailles : Root 0,46 × 0,55 de l'écran (au moins 560 × 300 px, au plus 980 × 620), centré un peu sous le milieu
-- (la barre du bas est cachée pendant les fenêtres, Config/UiMotion.HudHide) ; 4 colonnes et 2 rangées entières de
-- cartes visibles, jamais une rangée coupée : chaque <Section>.Cards est un ScrollingFrame dont la grille a CellSize
-- Y = 0,5 de sa hauteur visible ; en-tête d'au moins 46 px.

local StarterGui = game:GetService("StarterGui")

local NAME = "UI_Inventory_Gris"
local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold)
local G = {
	Window = Color3.fromRGB(59, 62, 70),
	Panel = Color3.fromRGB(74, 78, 87),
	Tab = Color3.fromRGB(90, 94, 104),
	Button = Color3.fromRGB(122, 128, 140),
	Slot = Color3.fromRGB(138, 143, 153),
	Text = Color3.new(1, 1, 1),
}

local old = StarterGui:FindFirstChild(NAME)
if old then
	old:Destroy()
end

local function new(class: string, props: { [string]: any }, parent: Instance?): any
	local o = Instance.new(class)
	for k, v in props do
		(o :: any)[k] = v
	end
	if parent then
		o.Parent = parent
	end
	return o
end

local function frame(name: string, parent: Instance, pos: UDim2, size: UDim2, color: Color3?, props: { [string]: any }?)
	local f = new("Frame", {
		Name = name,
		Position = pos,
		Size = size,
		BackgroundColor3 = color or G.Panel,
		BackgroundTransparency = if color then 0 else 1,
		BorderSizePixel = 0,
	}, parent)
	if props then
		for k, v in props do
			(f :: any)[k] = v
		end
	end
	return f
end

local function label(name: string, parent: Instance, text: string, pos: UDim2, size: UDim2, props: { [string]: any }?)
	local t = new("TextLabel", {
		Name = name,
		Text = text,
		Position = pos,
		Size = size,
		BackgroundTransparency = 1,
		FontFace = FONT,
		TextColor3 = G.Text,
		TextScaled = true,
		TextWrapped = true,
		BorderSizePixel = 0,
	}, parent)
	if props then
		for k, v in props do
			(t :: any)[k] = v
		end
	end
	return t
end

local function button(name: string, parent: Instance, labelName: string, text: string, pos: UDim2, size: UDim2, props: { [string]: any }?)
	local b = new("TextButton", {
		Name = name,
		Text = "",
		AutoButtonColor = false,
		Position = pos,
		Size = size,
		BackgroundColor3 = G.Button,
		BorderSizePixel = 0,
	}, parent)
	if props then
		for k, v in props do
			(b :: any)[k] = v
		end
	end
	label(labelName, b, text, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.86, 0.72), { AnchorPoint = Vector2.new(0.5, 0.5) })
	return b
end

local function stroke(parent: Instance, thickness: number, color: Color3?)
	return new("UIStroke", { Thickness = thickness, Color = color or Color3.new(1, 1, 1), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, parent)
end

local gui = new("ScreenGui", {
	Name = NAME,
	Enabled = false,
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	DisplayOrder = 5,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
})
gui:SetAttribute("ScreenGroup", "Menu")

-- Fenêtre : centrée un peu sous le milieu de l'écran, sous la barre de Roblox sur téléphone (haut à 60 px au moins).
local root = frame("Root", gui, UDim2.fromScale(0.5, 0.56), UDim2.fromScale(0.46, 0.55), nil, { AnchorPoint = Vector2.new(0.5, 0.5) })
new("UISizeConstraint", { MinSize = Vector2.new(560, 300), MaxSize = Vector2.new(980, 620) }, root)
local window = frame("Window", root, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), G.Window)

-- Croix sur le coin haut droit, à cheval sur le bord (comme la référence)
local close = button("CloseButton", root, "XLabel", "X", UDim2.new(1, -6, 0, 6), UDim2.fromScale(0, 0.13), { AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 5 })
new("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height }, close)
new("UISizeConstraint", { MinSize = Vector2.new(44, 44) }, close)

-- Onglets à gauche
local tabs = frame("Tabs", root, UDim2.fromOffset(8, 8), UDim2.new(0.11, 0, 1, -16))
new("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, tabs)
for i, t in { { "ItemsTab", "ITEMS" }, { "ToolsTab", "WEAPONS" }, { "PotionsTab", "POTIONS" } } do
	local tab = new("TextButton", { Name = t[1], Text = "", AutoButtonColor = false, LayoutOrder = i, Size = UDim2.fromScale(1, 0.31), BackgroundColor3 = G.Tab, BorderSizePixel = 0 }, tabs)
	new("UIAspectRatioConstraint", { AspectRatio = 1 }, tab)
	label("TabLabel", tab, t[2], UDim2.fromScale(0.5, 0.04), UDim2.fromScale(0.92, 0.26), { AnchorPoint = Vector2.new(0.5, 0) })
	frame("TabIcon", tab, UDim2.fromScale(0.5, 0.62), UDim2.fromScale(0.56, 0.56), G.Slot, { AnchorPoint = Vector2.new(0.5, 0.5) })
	local sel = frame("Selected", tab, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), nil, { Visible = i == 1 })
	stroke(sel, 3)
end

-- Contenu à droite des onglets
local content = frame("Content", root, UDim2.new(0.11, 16, 0, 8), UDim2.new(0.89, -24, 1, -16))
local header = frame("Header", content, UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.16))
new("UISizeConstraint", { MinSize = Vector2.new(0, 46) }, header)
label("Title", header, "INVENTORY", UDim2.fromScale(0, 0), UDim2.fromScale(0.3, 0.56), { TextXAlignment = Enum.TextXAlignment.Left })
local counterPill = frame("CounterPill", header, UDim2.fromScale(0, 0.6), UDim2.fromScale(0.2, 0.4))
label("Counter", counterPill, "9 / 30 items", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), { TextXAlignment = Enum.TextXAlignment.Left })
local displayPill = frame("DisplayPill", header, UDim2.fromScale(0.21, 0.6), UDim2.fromScale(0.2, 0.4))
label("Displays", displayPill, "4 / 6 displays", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), { TextXAlignment = Enum.TextXAlignment.Left })
local search = new("TextBox", {
	Name = "SearchBox",
	Text = "",
	PlaceholderText = "Search...",
	ClearTextOnFocus = false,
	Position = UDim2.new(0.41, 0, 0.5, 0),
	AnchorPoint = Vector2.new(0, 0.5),
	Size = UDim2.fromScale(0.27, 0.8),
	BackgroundColor3 = G.Panel,
	BorderSizePixel = 0,
	FontFace = FONT,
	TextColor3 = G.Text,
	PlaceholderColor3 = Color3.fromRGB(200, 200, 200),
	TextScaled = true,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
}, header)
new("UIPadding", { PaddingLeft = UDim.new(0.06, 0), PaddingTop = UDim.new(0.2, 0), PaddingBottom = UDim.new(0.2, 0) }, search)
local best = button("EquipBestButton", header, "EquipBestLabel", "EQUIP BEST", UDim2.new(0.94, -4, 0.5, 0), UDim2.fromScale(0.24, 0.9), { AnchorPoint = Vector2.new(1, 0.5) })
(best:FindFirstChild("EquipBestLabel") :: TextLabel).Size = UDim2.fromScale(0.86, 0.5)

-- Liste : une section visible à la fois ; 4 colonnes, 2 rangées entières par hauteur de liste
local list = new("ScrollingFrame", {
	Name = "List",
	Position = UDim2.new(0, 0, 0.16, 16),
	Size = UDim2.new(1, -14, 0.84, -16),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 0,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.fromScale(0, 0),
}, content)
new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, list)
frame("ScrollTrack", content, UDim2.new(1, -6, 0.16, 16), UDim2.new(0, 6, 0.84, -16), G.Slot)
label("EmptyLabel", content, "No items here.", UDim2.fromScale(0.5, 0.58), UDim2.fromScale(0.6, 0.1), { AnchorPoint = Vector2.new(0.5, 0.5), Visible = false })

local function section(name: string, order: number, visible: boolean)
	local s = frame(name, list, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), nil, { LayoutOrder = order, Visible = visible })
	local count = frame("SectionCount", s, UDim2.fromScale(0, 0), UDim2.fromOffset(0, 0), nil, { Visible = false })
	label("CountLabel", count, "0", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1))
	-- ScrollingFrame : la hauteur des cases (0,5) suit sa hauteur visible (2 rangées entières) et il défile.
	local cards = new("ScrollingFrame", {
		Name = "Cards",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.fromScale(0, 0),
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
	}, s)
	new("UIGridLayout", {
		CellSize = UDim2.new(0.2425, 0, 0.5, -4),
		CellPadding = UDim2.new(0.01, 0, 0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirectionMaxCells = 4,
	}, cards)
	return cards
end

local function cardBase(parent: Instance)
	local t = new("TextButton", { Name = "Template", Text = "", AutoButtonColor = false, Visible = false, BackgroundColor3 = G.Panel, BorderSizePixel = 0 }, parent)
	local clip = frame("Clip", t, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), nil, { ClipsDescendants = true })
	new("ImageLabel", { Name = "Rays", BackgroundTransparency = 1, ImageTransparency = 1, Size = UDim2.fromScale(1, 0.6), BorderSizePixel = 0 }, clip)
	new("ImageLabel", { Name = "Glow", BackgroundTransparency = 1, ImageTransparency = 1, Size = UDim2.fromScale(1, 0.6), BorderSizePixel = 0 }, clip)
	local icon = new("ImageLabel", { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.03), Size = UDim2.fromScale(0.8, 0.42), BackgroundColor3 = G.Slot, BorderSizePixel = 0 }, t)
	new("UIAspectRatioConstraint", { AspectRatio = 1 }, icon)
	local hover = frame("HoverOutline", t, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), nil, { Visible = false, ZIndex = 4 })
	stroke(hover, 3)
	return t
end

-- Objets
local itemCards = section("ItemsSection", 1, true)
local item = cardBase(itemCards)
local mut = frame("MutationTag", item, UDim2.fromScale(0.5, 0.41), UDim2.fromScale(0.8, 0.09), G.Button, { AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 2 })
label("MutationLabel", mut, "BIG · GOLD", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.9, 0.8), { AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 2 })
local badge = frame("DisplayedBadge", item, UDim2.fromScale(0.5, 0.03), UDim2.fromScale(0.86, 0.1), G.Button, { AnchorPoint = Vector2.new(0.5, 0), Visible = false, ZIndex = 2 })
label("DisplayedLabel", badge, "ON DISPLAY", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.9, 0.8), { AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 2 })
label("ItemName", item, "ITEM NAME", UDim2.fromScale(0.5, 0.46), UDim2.fromScale(0.94, 0.13), { AnchorPoint = Vector2.new(0.5, 0) })
local rarityBar = frame("RarityBar", item, UDim2.fromScale(0, 0.595), UDim2.fromScale(1, 0.11), G.Tab)
label("Rarity", rarityBar, "COMMON", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.9, 0.8), { AnchorPoint = Vector2.new(0.5, 0.5) })
label("Income", item, "+$12K/s", UDim2.fromScale(0.5, 0.71), UDim2.fromScale(0.94, 0.12), { AnchorPoint = Vector2.new(0.5, 0) })
button("PlaceButton", item, "PlaceLabel", "PLACE", UDim2.fromScale(0.5, 0.98), UDim2.fromScale(0.9, 0.15), { AnchorPoint = Vector2.new(0.5, 1) })
button("UnequipButton", item, "UnequipLabel", "UNEQUIP", UDim2.fromScale(0.5, 0.98), UDim2.fromScale(0.9, 0.15), { AnchorPoint = Vector2.new(0.5, 1), Visible = false })
local alert = frame("CardAlert", item, UDim2.fromScale(0.88, 0.08), UDim2.fromScale(0.22, 0.22), G.Button, { AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, ZIndex = 3 })
new("UIAspectRatioConstraint", { AspectRatio = 1 }, alert)
new("UIScale", { Name = "Pulse", Scale = 1 }, alert)
label("AlertLabel", alert, "!", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.6, 0.72), { AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 3 })
local anti = frame("AntiTheft", item, UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.5), Color3.new(0, 0, 0), { BackgroundTransparency = 0.45, Visible = false, ZIndex = 3 })
label("LockLabel", anti, "LOCKED", UDim2.fromScale(0.5, 0.9), UDim2.fromScale(0.8, 0.18), { AnchorPoint = Vector2.new(0.5, 1), ZIndex = 3 })

-- Armes et outils
local toolCards = section("ToolsSection", 2, false)
local tool = cardBase(toolCards)
label("ToolName", tool, "HAMMER", UDim2.fromScale(0.5, 0.51), UDim2.fromScale(0.94, 0.14), { AnchorPoint = Vector2.new(0.5, 0) })
label("ToolStat", tool, "Power 20", UDim2.fromScale(0.5, 0.66), UDim2.fromScale(0.94, 0.12), { AnchorPoint = Vector2.new(0.5, 0) })
button("EquipButton", tool, "EquipLabel", "EQUIP", UDim2.fromScale(0.5, 0.98), UDim2.fromScale(0.9, 0.15), { AnchorPoint = Vector2.new(0.5, 1) })
local pill = frame("EquippedPill", tool, UDim2.fromScale(0.5, 0.98), UDim2.fromScale(0.9, 0.15), G.Tab, { AnchorPoint = Vector2.new(0.5, 1), Visible = false })
label("EquippedLabel", pill, "EQUIPPED", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.86, 0.6), { AnchorPoint = Vector2.new(0.5, 0.5) })

-- Potions : pas de Template (le code copie celui des outils, Contract/UI)
section("PotionsSection", 3, false)

gui.Parent = StarterGui
print(`[ui_inventaire_gris] {NAME} construit`)
