--[[
	Écran admin en version grise (2026-11-12, demande de Clément) : StarterGui/UI_Admin et le bouton
	UI_HUD.AdminButton (caché ; le code le montre aux admins seulement). Aucun script. À lancer en Edit.
	Relancer le script refait l'écran (l'ancien est remplacé).
	Toutes les actions s'appliquent au joueur choisi dans TargetSection (soi-même par défaut).
	Listes : un Template caché que le code clone (joueurs, objets, mutations, colis, auras, trails,
	potions, gamepasses, événements, zones).
]]

local CH = game:GetService("ChangeHistoryService")
local SG = game.StarterGui
local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold)
local BG, PANEL, BTN, BTN_RED, TXT = Color3.fromHex("2a2d36"), Color3.fromHex("3a3e4a"), Color3.fromHex("5b6378"), Color3.fromHex("a8323a"), Color3.new(1, 1, 1)
local ROW = 44 -- hauteur d'une ligne, en px (au moins 44 px sur téléphone)

local function make(class, parent, props)
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	o.Parent = parent
	return o
end
local function corner(o, px) make("UICorner", o, { CornerRadius = UDim.new(0, px or 8) }) end
local function text(o, maxSize)
	o.FontFace = FONT; o.TextColor3 = TXT; o.TextScaled = true; o.TextWrapped = true
	make("UITextSizeConstraint", o, { MaxTextSize = maxSize or 20, MinTextSize = 8 })
end
local function label(parent, name, t, width, props)
	local l = make("TextLabel", parent, { Name = name, Text = t, BackgroundTransparency = 1, Size = UDim2.new(width or 1, 0, 0, ROW), TextXAlignment = Enum.TextXAlignment.Left })
	text(l)
	for k, v in props or {} do l[k] = v end
	return l
end
local function button(parent, name, t, width, color)
	local b = make("TextButton", parent, { Name = name, Text = "", AutoButtonColor = true, BackgroundColor3 = color or BTN, Size = UDim2.new(width, -6, 0, ROW) })
	corner(b)
	local l = make("TextLabel", b, { Name = "Label", Text = t, BackgroundTransparency = 1, Size = UDim2.new(1, -12, 1, -8), Position = UDim2.fromOffset(6, 4) })
	text(l, 18)
	make("Frame", b, { Name = "Shade", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 3 })
	return b
end
local function box(parent, name, placeholder, width)
	local b = make("TextBox", parent, { Name = name, Text = "", PlaceholderText = placeholder, ClearTextOnFocus = false, BackgroundColor3 = Color3.fromHex("1d2027"), Size = UDim2.new(width, -6, 0, ROW), PlaceholderColor3 = Color3.fromHex("8a93a6") })
	corner(b)
	text(b, 18)
	return b
end
local function row(parent, name, order)
	local r = make("Frame", parent, { Name = name, LayoutOrder = order, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, ROW) })
	make("UIListLayout", r, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center })
	return r
end
local function section(parent, name, title, order)
	local s = make("Frame", parent, { Name = name, LayoutOrder = order, BackgroundColor3 = PANEL, Size = UDim2.new(1, -12, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	corner(s, 10)
	make("UIPadding", s, { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10) })
	make("UIListLayout", s, { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
	label(s, "SectionTitle", title, 1, { LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 30), TextColor3 = Color3.fromHex("ffd84a") })
	return s
end
-- liste horizontale qui défile, avec un Template caché (TextButton qui contient EntryName et Selected)
local function list(parent, name, order, example)
	local l = make("ScrollingFrame", parent, { Name = name, LayoutOrder = order, BackgroundColor3 = Color3.fromHex("1d2027"), Size = UDim2.new(1, 0, 0, ROW + 12), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollingDirection = Enum.ScrollingDirection.X, ScrollBarThickness = 6 })
	corner(l)
	make("UIPadding", l, { PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 4) })
	make("UIListLayout", l, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
	local t = make("TextButton", l, { Name = "Template", Visible = false, Text = "", AutoButtonColor = true, BackgroundColor3 = BTN, Size = UDim2.fromOffset(150, ROW) })
	corner(t)
	local n = make("TextLabel", t, { Name = "EntryName", Text = example, BackgroundTransparency = 1, Size = UDim2.new(1, -12, 1, -8), Position = UDim2.fromOffset(6, 4) })
	text(n, 18)
	local sel = make("Frame", t, { Name = "Selected", Visible = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3 })
	corner(sel)
	make("UIStroke", sel, { Thickness = 3, Color = Color3.fromHex("ffd84a"), ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	return l
end

local rec = CH:TryBeginRecording("UI_Admin (version grise) et AdminButton")
local old = SG:FindFirstChild("UI_Admin")
if old then old:Destroy() end

local gui = make("ScreenGui", nil, { Name = "UI_Admin", Enabled = false, ResetOnSpawn = false, DisplayOrder = 50, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
gui:SetAttribute("ScreenGroup", "Menu")
local root = make("Frame", gui, { Name = "Root", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.86), BackgroundColor3 = BG })
corner(root, 14)
make("UISizeConstraint", root, { MinSize = Vector2.new(560, 300), MaxSize = Vector2.new(1100, 1000) })
make("UIStroke", root, { Thickness = 3, Color = Color3.new(0, 0, 0) })
local header = make("Frame", root, { Name = "Header", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52) })
label(header, "Title", "ADMIN", 0.5, { Position = UDim2.fromOffset(16, 4), TextColor3 = Color3.fromHex("ffd84a") })
local close = button(header, "CloseButton", "X", 0, BTN_RED)
close.Size = UDim2.fromOffset(ROW, ROW); close.AnchorPoint = Vector2.new(1, 0); close.Position = UDim2.new(1, -8, 0, 4)
local body = make("ScrollingFrame", root, { Name = "Body", BackgroundTransparency = 1, Position = UDim2.fromOffset(6, 56), Size = UDim2.new(1, -12, 1, -100), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 8 })
make("UIListLayout", body, { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center })
make("UIPadding", body, { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 10) })
label(root, "StatusLabel", "Ready.", 1, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -4), Size = UDim2.new(1, -32, 0, 36), TextColor3 = Color3.fromHex("91f630") })

-- 1. joueur visé (soi-même par défaut)
local s = section(body, "TargetSection", "TARGET PLAYER", 1)
label(s, "TargetLabel", "Target: you", 1, { LayoutOrder = 1 })
list(s, "PlayerList", 2, "Player")

-- 2. argent, vitesse, force
s = section(body, "StatsSection", "CASH, SPEED, STRENGTH", 2)
for i, d in { { "Cash", "Give cash" }, { "Speed", "Give speed" }, { "Strength", "Give strength" } } do
	local r = row(s, d[1] .. "Row", i)
	box(r, d[1] .. "Box", "Amount", 0.6).LayoutOrder = 1
	button(r, "Give" .. d[1] .. "Button", d[2], 0.4).LayoutOrder = 2
end

-- 3. machines et boutique
s = section(body, "BaseSection", "MACHINES AND SHOP", 3)
for i, d in { { "Treadmill", "Set treadmill tier" }, { "Bench", "Set bench tier" }, { "ShopLevel", "Set shop level" }, { "Rayons", "Set aisle count" } } do
	local r = row(s, d[1] .. "Row", i)
	box(r, d[1] .. "Box", "Level", 0.6).LayoutOrder = 1
	button(r, "Set" .. d[1] .. "Button", d[2], 0.4).LayoutOrder = 2
end

-- 4. donner : objet, mutation, colis, aura, trail, potion, VIP ou gamepass
s = section(body, "GiveSection", "GIVE", 4)
local kinds = row(s, "KindRow", 1)
kinds.Size = UDim2.new(1, 0, 0, ROW)
local kindNames = { "Item", "Box", "Aura", "Trail", "Potion", "Gamepass" }
for i, k in kindNames do
	local b = button(kinds, k .. "KindButton", k, 1 / #kindNames)
	b.LayoutOrder = i
	local sel = make("Frame", b, { Name = "Selected", Visible = i == 1, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3 })
	corner(sel)
	make("UIStroke", sel, { Thickness = 3, Color = Color3.fromHex("ffd84a"), ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end
local sr = row(s, "SearchRow", 2)
box(sr, "SearchBox", "Search…", 1).LayoutOrder = 1
list(s, "ChoiceList", 3, "Giant TV")
label(s, "MutationTitle", "Mutation (items only)", 1, { LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 26) })
list(s, "MutationList", 5, "None")
local gr = row(s, "GiveRow", 6)
button(gr, "GiveButton", "Give to target", 1, Color3.fromHex("2f8f3a")).LayoutOrder = 1

-- 5. événements (camion, nuit, jour, pluie et les suivants : une entrée par événement)
s = section(body, "EventsSection", "EVENTS", 5)
list(s, "EventList", 1, "Truck")

-- 6. téléportation
s = section(body, "TeleportSection", "TELEPORT", 6)
list(s, "ZoneList", 1, "Zone 1")

-- 7. remise à zéro (deux clics : le code change le texte du bouton au premier)
s = section(body, "DangerSection", "DANGER", 7)
local dr = row(s, "ResetRow", 1)
button(dr, "ResetProfileButton", "Reset my profile", 1, BTN_RED).LayoutOrder = 1

gui.Parent = SG

-- bouton du HUD, caché (le code le montre aux admins), à droite, sous le milieu
local hud = SG.UI_HUD
local oldBtn = hud:FindFirstChild("AdminButton")
if oldBtn then oldBtn:Destroy() end
local ab = make("TextButton", hud, { Name = "AdminButton", Visible = false, Text = "", AutoButtonColor = true, BackgroundColor3 = Color3.fromHex("3a3e4a"), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(0.979, 0.4), Size = UDim2.fromScale(0.06, 0.06) })
make("UIAspectRatioConstraint", ab, { AspectRatio = 1 })
make("UISizeConstraint", ab, { MinSize = Vector2.new(44, 44) })
corner(ab, 10)
make("UIStroke", ab, { Thickness = 2.5, Color = Color3.new(0, 0, 0), ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
local al = make("TextLabel", ab, { Name = "AdminLabel", Text = "ADMIN", BackgroundTransparency = 1, Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4) })
text(al, 16)
make("Frame", ab, { Name = "Shade", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 3 })

if rec then CH:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
return "UI_Admin et UI_HUD.AdminButton construits"
