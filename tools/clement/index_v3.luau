--[[
	UI_Index_v3 : l'Index du jeu de référence (vidéo de Clément, 2026-11-10), sans script dans l'UI.
	- En Edit : construit StarterGui/UI_Index_v3 (caché, ScreenGroup = "Menu").
	- En Play, côté client : construit une copie _PROTO_UI_Index_v3 dans le PlayerGui, la remplit avec
	  les vrais objets de Config/Items (un tiers par zone marqué « découvert », pour l'aperçu) et la
	  branche sur le prototype _G.UiFeel (bouton Index du HUD copié), puis l'ouvre.
	Mise en page : fenêtre au bandeau rose ; à gauche, une liste qui défile, une zone par bloc (image
	de la zone, cartes 5 par ligne aux couleurs de rareté, barre « 4/13 » avec l'objet le plus rare) ;
	en bas, « Unlocked: 7/83 » ; à droite, la fiche de l'objet cliqué et les récompenses de la zone
	visible ; hors de la fenêtre, à droite, NORMAL, SECRETS et MUTATIONS ; à gauche, les 7 mutations.
	Noms lus par le code gardés : Template (Icon, ItemName, Lock, Glow, Rays), ZoneName, ZoneBar.Fill,
	ZoneCount, Counter, CloseButton.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local RS = game:GetService("ReplicatedStorage")

local C = Color3.fromHex
local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, C("ff4d4d")), ColorSequenceKeypoint.new(0.2, C("ffb84d")), ColorSequenceKeypoint.new(0.4, C("fff04d")),
	ColorSequenceKeypoint.new(0.6, C("5dff6a")), ColorSequenceKeypoint.new(0.8, C("4dc3ff")), ColorSequenceKeypoint.new(1, C("b45dff")),
})
local ZONES = {
	{ "Zone1Section", "MINI MART", "rbxassetid://78584459706458", C("58c23a") },
	{ "Zone2Section", "LONDON", "rbxassetid://131392980222651", C("4a7fd6") },
	{ "Zone3Section", "TOKYO", "rbxassetid://85356770291128", C("e8508a") },
	{ "Zone4Section", "L.A.", "rbxassetid://134466663843209", C("f29b2a") },
	{ "Zone5Section", "PARIS", "rbxassetid://128493730231973", C("9b6be0") },
	{ "Zone6Section", "NEW YORK", "rbxassetid://119166406273898", C("33bcd6") },
	{ "SecretsSection", "SECRETS", "rbxassetid://131210974391512", C("e83b3b") },
}
local MUTATIONS = {
	{ "Shiny", C("fffbe0"), C("ffd65c") }, { "Gold", C("ffe066"), C("e69a08") }, { "Neon", C("7dffaa"), C("10c95a") },
	{ "Diamond", C("bdf6ff"), C("38b6e8") }, { "Glitch", C("ff6fe6"), C("6a3bff") }, { "Hacked", C("5cff6e"), C("0a7a20") },
	{ "Rainbow", nil, nil },
}

local function make(class, parent, props)
	local o = Instance.new(class)
	for k, v in props or {} do o[k] = v end
	o.Parent = parent
	return o
end
local function corner(o, s) return make("UICorner", o, { CornerRadius = UDim.new(s or 0.08, 0) }) end
local function stroke(o, th) return make("UIStroke", o, { Thickness = th or 2.5, Color = C("0b1209"), ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Round }) end
local function grad(o, a, b, rot) return make("UIGradient", o, { Color = ColorSequence.new(a, b), Rotation = rot or 90 }) end
local function frame(parent, name, props)
	local f = make("Frame", parent, { Name = name, BorderSizePixel = 0, BackgroundTransparency = 1 })
	for k, v in props or {} do f[k] = v end
	return f
end
local function label(parent, name, text, props)
	local t = make("TextLabel", parent, { Name = name, Text = text, FontFace = FONT, TextScaled = true, TextWrapped = true, TextColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5) })
	for k, v in props or {} do t[k] = v end
	make("UIStroke", t, { Thickness = 0.075, StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize, Color = C("0b0b0b"), LineJoinMode = Enum.LineJoinMode.Round })
	return t
end
local function shade(parent, z, r)
	local s = frame(parent, "Shade", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = z })
	corner(s, r)
	return s
end
local function button(parent, name, props, r)
	local b = make("TextButton", parent, { Name = name, Text = "", AutoButtonColor = false, BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1) })
	for k, v in props or {} do b[k] = v end
	corner(b, r)
	stroke(b, 2.5)
	make("UISizeConstraint", b, { MinSize = Vector2.new(0, 44) })
	return b
end

local function build(parent, guiName)
	local old = parent:FindFirstChild(guiName)
	if old then old:Destroy() end
	local gui = make("ScreenGui", nil, { Name = guiName, Enabled = false, ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 10 })
	gui:SetAttribute("ScreenGroup", "Menu")
	local root = frame(gui, "Root", { AnchorPoint = Vector2.new(0.46, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 0.69) })
	make("UIAspectRatioConstraint", root, { AspectRatio = 1.868 })
	make("UISizeConstraint", root, { MinSize = Vector2.new(600, 321) })

	-- fenêtre
	local win = frame(root, "Window", { Size = UDim2.fromScale(0.857, 1), BackgroundTransparency = 0, BackgroundColor3 = C("1e3b19") })
	corner(win, 0.014)
	stroke(win, 3)
	local header = frame(win, "Header", { Size = UDim2.fromScale(1, 0.156), BackgroundTransparency = 0, BackgroundColor3 = Color3.new(1, 1, 1), ClipsDescendants = true, ZIndex = 2 })
	corner(header, 0.09)
	grad(header, C("b52fe6"), C("f774d6"), 0)
	for i, x in { 0.43, 0.5, 0.565 } do
		frame(header, "Stripe" .. i, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, 0.5), Size = UDim2.fromScale(i == 1 and 0.05 or 0.035, 2), Rotation = 28, BackgroundTransparency = 0.8, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3 })
	end
	frame(header, "Edge", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 3), BackgroundTransparency = 0, BackgroundColor3 = C("0b1209"), ZIndex = 3 })
	label(header, "Title", "Index", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.022, 0.5), Size = UDim2.fromScale(0.3, 0.7), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4 })
	local close = button(win, "CloseButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(0.988, 0.016), Size = UDim2.fromScale(0.084, 0.13), ZIndex = 5 }, 0.1)
	make("UIAspectRatioConstraint", close, { AspectRatio = 1 })
	grad(close, C("ff4b3e"), C("d0140e"))
	shade(close, 6, 0.1)
	label(close, "XLabel", "X", { Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.72), ZIndex = 7 })

	-- liste des zones
	local panel = frame(win, "ListPanel", { Position = UDim2.fromScale(0.015, 0.183), Size = UDim2.fromScale(0.69, 0.6), BackgroundTransparency = 0, BackgroundColor3 = C("2a3326"), ZIndex = 2 })
	corner(panel, 0.025)
	stroke(panel, 2.5)
	local list = make("ScrollingFrame", panel, { Name = "List", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromScale(0.02, 0.035), Size = UDim2.fromScale(0.97, 0.93), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 6, ScrollBarImageColor3 = C("9be36a"), ZIndex = 3 })
	make("UIListLayout", list, { Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder })
	make("UIPadding", list, { PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) })

	-- carte (le code la clone)
	-- TextButton : un clic ou un appui choisit l'objet montré dans la fiche de droite
	local tpl = make("TextButton", list, { Name = "Template", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, Size = UDim2.fromOffset(70, 70), ZIndex = 4 })
	local clip = frame(tpl, "Clip", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0, BackgroundColor3 = C("b0b7c3"), ClipsDescendants = true, ZIndex = 4 })
	corner(clip, 0.08)
	stroke(clip, 2)
	grad(clip, Color3.new(1, 1, 1), C("a8a8a8"))
	make("ImageLabel", clip, { Name = "Glow", Image = "rbxassetid://130850617844067", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.58), Size = UDim2.fromScale(1.3, 1.3), ImageTransparency = 0.5, ZIndex = 5 })
	make("ImageLabel", clip, { Name = "Rays", Image = "rbxassetid://110553518823718", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.58), Size = UDim2.fromScale(1.7, 1.7), ImageTransparency = 0.85, ZIndex = 5 })
	make("ImageLabel", tpl, { Name = "Icon", BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.97), Size = UDim2.fromScale(0.84, 0.74), ZIndex = 7 })
	label(tpl, "ItemName", "Item", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.05), Size = UDim2.fromScale(0.94, 0.22), ZIndex = 8 })
	frame(tpl, "Lock", { Visible = false }) -- le code l'allume pour un objet pas découvert : rien ne se voit (« ??? » et silhouette suffisent)
	local outline = frame(tpl, "HoverOutline", { Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 9 })
	corner(outline, 0.08)
	make("UIStroke", outline, { Color = Color3.new(1, 1, 1), Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })

	-- un bloc par zone
	for order, z in ZONES do
		local sec = frame(list, z[1], { Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, ZIndex = 3, Visible = z[1] ~= "SecretsSection" })
		make("UIListLayout", sec, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0.02, 0), SortOrder = Enum.SortOrder.LayoutOrder })
		local art = make("ImageLabel", sec, { Name = "ZoneArt", BackgroundTransparency = 0, BackgroundColor3 = z[4], BorderSizePixel = 0, Size = UDim2.new(0.235, 0, 0, 10000), ScaleType = Enum.ScaleType.Crop, LayoutOrder = 1, ZIndex = 4 })
		make("UIAspectRatioConstraint", art, { AspectRatio = 0.44 })
		corner(art, 0.06)
		stroke(art, 2.5)
		grad(art, Color3.new(1, 1, 1), C("5a5a5a"))
		make("ImageLabel", art, { Name = "ZoneIcon", Image = z[3], BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromScale(0.86, 0.86), SizeConstraint = Enum.SizeConstraint.RelativeXX, ScaleType = Enum.ScaleType.Fit, ZIndex = 5 })
		label(art, "ZoneName", z[2], { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.96), Size = UDim2.fromScale(0.94, 0.13), ZIndex = 6 })
		local content = frame(sec, "Content", { Size = UDim2.fromScale(0.745, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, ZIndex = 4 })
		make("UIListLayout", content, { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder })
		local cards = frame(content, "Cards", { Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, ZIndex = 4 })
		local grid = make("UIGridLayout", cards, { CellSize = UDim2.new(0.184, 0, 0, 10000), CellPadding = UDim2.new(0.02, 0, 0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
		make("UIAspectRatioConstraint", grid, { AspectRatio = 1 })
		local bar = frame(content, "ZoneBar", { Size = UDim2.new(1, 0, 0, 10000),BackgroundTransparency = 0, BackgroundColor3 = C("383d35"), LayoutOrder = 2, ZIndex = 4 })
		make("UIAspectRatioConstraint", bar, { AspectRatio = 5.6 })
		corner(bar, 0.12)
		stroke(bar, 2.5)
		local fill = frame(bar, "Fill", { Size = UDim2.fromScale(0, 1), BackgroundTransparency = 0, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 5 })
		corner(fill, 0.12)
		grad(fill, C("dcf70e"), C("5ed10a"), 0)
		label(bar, "ZoneCount", "0/0", { Position = UDim2.fromScale(0.44, 0.5), Size = UDim2.fromScale(0.5, 0.6), ZIndex = 7 })
		make("ImageLabel", bar, { Name = "ZoneItem", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(0.985, 0.42), Size = UDim2.fromScale(1.35, 1.35), SizeConstraint = Enum.SizeConstraint.RelativeYY, ScaleType = Enum.ScaleType.Fit, Rotation = -15, ZIndex = 6 })
	end

	-- compteur global
	local ub = frame(win, "UnlockedBar", { Position = UDim2.fromScale(0.015, 0.825), Size = UDim2.fromScale(0.69, 0.14), BackgroundTransparency = 0, BackgroundColor3 = C("2a3326"), ZIndex = 2 })
	corner(ub, 0.12)
	stroke(ub, 2.5)
	label(ub, "Counter", "Unlocked: 0/83", { Position = UDim2.fromScale(0.54, 0.5), Size = UDim2.fromScale(0.74, 0.58), ZIndex = 3 })
	local book = make("ImageLabel", win, { Name = "BookIcon", Image = "rbxassetid://90733951567919", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.07, 0.885), Size = UDim2.fromScale(0.2, 0.2), SizeConstraint = Enum.SizeConstraint.RelativeYY, ScaleType = Enum.ScaleType.Fit, Rotation = -8, ZIndex = 4 })
	make("UIAspectRatioConstraint", book, { AspectRatio = 1 })

	-- fiche de l'objet cliqué
	local det = frame(win, "Detail", { Position = UDim2.fromScale(0.723, 0.183), Size = UDim2.fromScale(0.262, 0.46), BackgroundTransparency = 0, BackgroundColor3 = C("b0b7c3"), ZIndex = 2 })
	corner(det, 0.04)
	stroke(det, 3)
	grad(det, Color3.new(1, 1, 1), C("808080"))
	local iconFrame = frame(det, "IconFrame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.045), Size = UDim2.fromScale(0.74, 0.43), BackgroundTransparency = 0, BackgroundColor3 = C("262626"), ZIndex = 3 })
	corner(iconFrame, 0.06)
	stroke(iconFrame, 2)
	make("ImageLabel", iconFrame, { Name = "DetailIcon", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(0.88, 0.9), ScaleType = Enum.ScaleType.Fit, ZIndex = 4 })
	label(det, "DetailName", "???", { Position = UDim2.fromScale(0.5, 0.58), Size = UDim2.fromScale(0.92, 0.15), ZIndex = 3 })
	label(det, "DetailRarity", "Common", { Position = UDim2.fromScale(0.5, 0.73), Size = UDim2.fromScale(0.92, 0.14), ZIndex = 3 })
	label(det, "DetailIncome", "???", { Position = UDim2.fromScale(0.5, 0.88), Size = UDim2.fromScale(0.92, 0.14), TextColor3 = C("62ff3c"), ZIndex = 3 })

	-- récompenses de la zone visible
	local rw = frame(win, "Rewards", { Position = UDim2.fromScale(0.723, 0.672), Size = UDim2.fromScale(0.262, 0.293), BackgroundTransparency = 0, BackgroundColor3 = C("204219"), ZIndex = 2 })
	corner(rw, 0.06)
	stroke(rw, 3)
	label(rw, "RewardsTitle", "Rewards:", { AnchorPoint = Vector2.new(0, 0), Position = UDim2.fromScale(0.06, 0.05), Size = UDim2.fromScale(0.6, 0.14), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 })
	local function tile(name, image, amount, x)
		local t = frame(rw, name, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(x, 0.21), Size = UDim2.fromScale(0.34, 0.4), BackgroundTransparency = 0, BackgroundColor3 = C("2b2b2b"), ZIndex = 3 })
		make("UIAspectRatioConstraint", t, { AspectRatio = 1 })
		corner(t, 0.1)
		stroke(t, 2)
		make("ImageLabel", t, { Name = "Icon", Image = image, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromScale(0.78, 0.78), ScaleType = Enum.ScaleType.Fit, ZIndex = 4 })
		label(t, "Amount", amount, { Position = UDim2.fromScale(0.5, 0.86), Size = UDim2.fromScale(1.05, 0.34), ZIndex = 5 })
	end
	tile("SpeedReward", "", "+Speed", 0.3)
	tile("CashReward", "rbxassetid://138179722277427", "+Cash", 0.7)
	local claim = button(rw, "ClaimButton", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.95), Size = UDim2.fromScale(0.86, 0.27), ZIndex = 3 }, 0.14)
	grad(claim, Color3.new(1, 1, 1), C("cfcfcf"))
	shade(claim, 4, 0.14)
	label(claim, "ClaimLabel", "Claim!", { Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.86, 0.72), ZIndex = 5 })

	-- catégories, hors de la fenêtre à droite
	local cats = frame(root, "Categories", { Position = UDim2.fromScale(0.87, 0.19), Size = UDim2.fromScale(0.13, 0.38), ZIndex = 2 })
	make("UIListLayout", cats, { Padding = UDim.new(0.06, 0), SortOrder = Enum.SortOrder.LayoutOrder })
	local function category(name, text, a, b, order)
		local btn = button(cats, name, { Size = UDim2.fromScale(1, 0.293), LayoutOrder = order, ZIndex = 3 }, 0.1)
		local g = make("UIGradient", btn, { Rotation = a and 90 or 0, Color = a and ColorSequence.new(a, b) or RAINBOW })
		local _ = g
		shade(btn, 4, 0.1)
		label(btn, "Label", text, { Position = UDim2.fromScale(name == "MutationsButton" and 0.56 or 0.5, 0.5), Size = UDim2.fromScale(name == "MutationsButton" and 0.78 or 0.9, 0.62), ZIndex = 6 })
		local sel = frame(btn, "Selected", { Size = UDim2.fromScale(1, 1), Visible = order == 1, ZIndex = 7 })
		corner(sel, 0.1)
		make("UIStroke", sel, { Color = Color3.new(1, 1, 1), Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
		return btn
	end
	category("NormalButton", "NORMAL", C("5ad8ff"), C("1c8de0"), 1)
	category("SecretsButton", "SECRETS", C("ffe066"), C("e29a0c"), 2)
	local mb = category("MutationsButton", "MUTATIONS", nil, nil, 3)
	make("ImageLabel", mb, { Name = "StarIcon", Image = "rbxassetid://130814257244832", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.1, 0.5), Size = UDim2.fromScale(1.25, 1.25), SizeConstraint = Enum.SizeConstraint.RelativeYY, ScaleType = Enum.ScaleType.Fit, ZIndex = 5 })

	-- onglets des mutations, hors de la fenêtre à gauche (catégorie MUTATIONS)
	local mt = frame(root, "MutationTabs", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(-0.006, 0.19), Size = UDim2.fromScale(0.15, 0.76), Visible = false, ZIndex = 2 })
	make("UIListLayout", mt, { Padding = UDim.new(0.02, 0), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right })
	for order, m in MUTATIONS do
		local tab = button(mt, m[1] .. "Tab", { Size = UDim2.fromScale(order == 1 and 1 or 0.9, 0.115), LayoutOrder = order, ZIndex = 3 }, 0.1)
		make("UIGradient", tab, { Rotation = m[2] and 90 or 0, Color = m[2] and ColorSequence.new(m[2], m[3]) or RAINBOW })
		shade(tab, 4, 0.1)
		label(tab, "TabLabel", string.upper(m[1]), { Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.86, 0.62), ZIndex = 6 })
		local sel = frame(tab, "Selected", { Size = UDim2.fromScale(1, 1), Visible = order == 1, ZIndex = 7 })
		corner(sel, 0.1)
		make("UIStroke", sel, { Color = Color3.new(1, 1, 1), Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	end
	label(root, "MutationCaption", "Collect every item in SHINY!", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.4285, 1.02), Size = UDim2.fromScale(0.8, 0.075), Visible = false, ZIndex = 2 })

	gui.Parent = parent
	return gui
end

local lp = Players.LocalPlayer
if not (RunService:IsRunning() and lp) then
	build(game:GetService("StarterGui"), "UI_Index_v3")
	return "UI_Index_v3 construit dans StarterGui (cache, sans script)"
end

-- aperçu en Play ---------------------------------------------------------------------------------
local PG = lp:WaitForChild("PlayerGui")
local gui = build(PG, "_PROTO_UI_Index_v3")
gui.DisplayOrder = 62
local Config = RS.Shared.Config
local Items = require(Config.Items)
local Rarities = require(Config.Rarities)
local Formulas = require(Config.Formulas)
local ICONS = RS.Assets.Icons
local rar = {}
for _, r in Rarities.List or Rarities do
	if type(r) == "table" and r.Id then rar[r.Id] = r end
end
local function money(n)
	for _, s in { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
		if n >= s[1] then return string.format("%.1f", n / s[1]):gsub("%.0$", "") .. s[2] end
	end
	return tostring(math.floor(n))
end

local snd = {}
local function play(name)
	if not snd[name] then
		local src = RS.Assets.Sounds:FindFirstChild(name, true)
		if not src then return end
		snd[name] = src:Clone()
		snd[name].Parent = gui
	end
	SoundService:PlayLocalSound(snd[name])
end
local function tween(o, t, props, style)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local function scaleOf(o)
	local s = o:FindFirstChildOfClass("UIScale") or make("UIScale", o, { Name = "ProtoScale" })
	if s:GetAttribute("ProtoBase") == nil then s:SetAttribute("ProtoBase", 1) end
	return s
end

local win = gui.Root.Window
local list = win.ListPanel.List
local tpl = list.Template
local det = win.Detail

-- objets par zone, rareté croissante ; un tiers « découvert » pour l'aperçu
local byZone = {}
for _, it in Items.List do
	local z = it.Zone or 0
	byZone[z] = byZone[z] or {}
	table.insert(byZone[z], it)
end
local total, found = 0, 0
local cardsOf = {}
local function paintCard(c, it, isFound)
	local r = rar[it.Rarity]
	local col = r and r.Color or Color3.new(0.7, 0.7, 0.7)
	c.Clip.BackgroundColor3 = isFound and col or col:Lerp(Color3.new(0, 0, 0), 0.55)
	if r and r.Rainbow then c.Clip.UIGradient.Color = RAINBOW end
	c.Clip.Glow.ImageColor3 = col
	c.Clip.Glow.ImageTransparency = isFound and 0.45 or 0.85
	c.Clip.Rays.ImageColor3 = col
	c.Clip.Rays.Visible = isFound and r ~= nil and r.Order >= 3
	local dec = ICONS:FindFirstChild("ICON_" .. it.Id)
	c.Icon.Image = dec and dec.Texture or ""
	c.Icon.ImageColor3 = isFound and Color3.new(1, 1, 1) or col:Lerp(Color3.new(0, 0, 0), 0.82)
	c.ItemName.Text = isFound and it.DisplayName or "???"
end
local function showDetail(it, isFound, zone)
	local r = rar[it.Rarity]
	local col = r and r.Color or Color3.new(0.7, 0.7, 0.7)
	det.BackgroundColor3 = col
	det.UIGradient.Color = (r and r.Rainbow) and RAINBOW or ColorSequence.new(Color3.new(1, 1, 1), C("808080"))
	local dec = ICONS:FindFirstChild("ICON_" .. it.Id)
	local icon = det.IconFrame.DetailIcon
	icon.Image = dec and dec.Texture or ""
	icon.ImageColor3 = isFound and Color3.new(1, 1, 1) or col:Lerp(Color3.new(0, 0, 0), 0.82)
	det.DetailName.Text = isFound and it.DisplayName or "???"
	det.DetailRarity.Text = r and r.DisplayName or it.Rarity
	det.DetailRarity.TextColor3 = col:Lerp(Color3.new(1, 1, 1), 0.3)
	local ok, inc = pcall(Formulas.ItemIncome, zone > 0 and zone or 6, it.Rarity)
	det.DetailIncome.Text = (isFound and ok and inc) and ("$" .. money(inc) .. "/s") or "???"
	local s = scaleOf(icon)
	s.Scale = 0.82
	tween(s, 0.16, { Scale = 1 }, Enum.EasingStyle.Back)
end

local mutationMode = false
local foundOf = {}
local function refresh()
	total, found = 0, 0
	for z, info in ZONES do
		local zone = z <= 6 and z or 0
		local sec = list:FindFirstChild(info[1])
		local items = byZone[zone] or {}
		local zf = 0
		for _, entry in cardsOf[zone] or {} do
			local isFound = foundOf[entry.it.Id] and not mutationMode
			paintCard(entry.card, entry.it, isFound)
			if isFound then zf += 1 end
		end
		total += #items
		found += zf
		local bar = sec.Content.ZoneBar
		bar.Fill.Size = UDim2.fromScale(#items > 0 and zf / #items or 0, 1)
		bar.ZoneCount.Text = zf .. "/" .. #items
		local rarest = items[#items]
		if rarest then
			local dec = ICONS:FindFirstChild("ICON_" .. rarest.Id)
			bar.ZoneItem.Image = dec and dec.Texture or ""
			local col = rar[rarest.Rarity] and rar[rarest.Rarity].Color or Color3.new(1, 1, 1)
			bar.ZoneItem.ImageColor3 = (foundOf[rarest.Id] and not mutationMode) and Color3.new(1, 1, 1) or col:Lerp(Color3.new(0, 0, 0), 0.8)
		end
	end
	win.UnlockedBar.Counter.Text = "Unlocked: " .. found .. "/" .. total
end

for z, info in ZONES do
	local zone = z <= 6 and z or 0
	local items = byZone[zone] or {}
	table.sort(items, function(a, b)
		local ra, rb = rar[a.Rarity] and rar[a.Rarity].Order or 0, rar[b.Rarity] and rar[b.Rarity].Order or 0
		if ra ~= rb then return ra < rb end
		return a.DisplayName < b.DisplayName
	end)
	cardsOf[zone] = {}
	local cards = list[info[1]].Content.Cards
	for i, it in items do
		foundOf[it.Id] = i <= math.ceil(#items / 3) and zone ~= 0
		local c = tpl:Clone()
		c.Name = it.Id
		c.Visible = true
		c.LayoutOrder = i
		c.Parent = cards
		table.insert(cardsOf[zone], { card = c, it = it })
		local icon = c.Icon
		local basePos, outline = icon.Position, c.HoverOutline
		c.MouseEnter:Connect(function()
			play("UI_Hover")
			outline.Visible = true
			tween(scaleOf(icon), 0.1, { Scale = 1.12 }, Enum.EasingStyle.Back)
			tween(icon, 0.1, { Rotation = -6, Position = basePos + UDim2.fromScale(0.03, -0.04) }, Enum.EasingStyle.Back)
		end)
		c.Activated:Connect(function() -- la fiche montre l'objet cliqué, pas l'objet survolé
			play("UI_Click_Classic")
			showDetail(it, foundOf[it.Id] and not mutationMode, zone)
		end)
		c.MouseLeave:Connect(function()
			outline.Visible = false
			tween(scaleOf(icon), 0.12, { Scale = 1 })
			tween(icon, 0.12, { Rotation = 0, Position = basePos })
		end)
	end
end
refresh()
showDetail(byZone[1][1], true, 1)

-- boutons : survol, appui, clic
local function wire(btn, onClick, silent)
	local s = scaleOf(btn)
	local sh = btn:FindFirstChild("Shade")
	local over = false
	btn.MouseEnter:Connect(function()
		over = true
		play("UI_Hover")
		tween(s, 0.08, { Scale = 1.06 })
		if sh then tween(sh, 0.08, { BackgroundTransparency = 0.78 }) end
	end)
	btn.MouseLeave:Connect(function()
		over = false
		tween(s, 0.08, { Scale = 1 })
		if sh then tween(sh, 0.08, { BackgroundTransparency = 1 }) end
	end)
	btn.MouseButton1Down:Connect(function()
		tween(s, 0.05, { Scale = 0.95 })
		if sh then tween(sh, 0.05, { BackgroundTransparency = 0.62 }) end
	end)
	btn.MouseButton1Up:Connect(function()
		tween(s, 0.2, { Scale = over and 1.06 or 1 }, Enum.EasingStyle.Back)
		if sh then tween(sh, 0.2, { BackgroundTransparency = over and 0.78 or 1 }) end
	end)
	btn.Activated:Connect(function()
		if not silent then play("UI_Click_Classic") end
		if onClick then onClick() end
	end)
end

-- défilement : récompenses de la zone visible
local currentZone = 1
local function zoneInView()
	local top = list.AbsolutePosition.Y + 30
	local best = 1
	for z, info in ZONES do
		local sec = list:FindFirstChild(info[1])
		if sec.Visible and sec.AbsolutePosition.Y <= top then best = z end
	end
	return best
end
list:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
	local z = zoneInView()
	if z ~= currentZone then
		currentZone = z
		local rw = win.Rewards
		local s = scaleOf(rw)
		s.Scale = 0.92
		tween(s, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	end
end)
wire(win.Rewards.ClaimButton, function()
	local zone = currentZone <= 6 and currentZone or 0
	local items = byZone[zone] or {}
	local n = 0
	for _, it in items do if foundOf[it.Id] then n += 1 end end
	if n < #items then
		play("UI_Deny")
		local b = win.Rewards.ClaimButton
		local x = b.Position
		for i, dx in { -0.03, 0.03, -0.02, 0.02, 0 } do
			task.delay(i * 0.04, function() b.Position = x + UDim2.fromScale(dx, 0) end)
		end
	else
		play("UI_Success")
	end
end, true)

-- catégories et mutations
local function select(container, name)
	for _, b in container:GetChildren() do
		if b:IsA("GuiButton") and b:FindFirstChild("Selected") then b.Selected.Visible = b.Name == name end
	end
end
local function swap(change)
	local items = {}
	for _, d in list:GetDescendants() do
		if d:IsA("GuiObject") and d:FindFirstChild("HoverOutline") and d.Name ~= "Template" and d.Parent.Parent.Parent.Visible then table.insert(items, d) end
	end
	for i, it in items do
		task.delay(math.min(i, 14) * 0.02, function() tween(scaleOf(it), 0.1, { Scale = 0 }) end)
	end
	task.delay(math.min(#items, 14) * 0.02 + 0.1, function()
		change()
		list.CanvasPosition = Vector2.zero
		local fresh = {}
		for _, d in list:GetDescendants() do
			if d:IsA("GuiObject") and d:FindFirstChild("HoverOutline") and d.Name ~= "Template" and d.Parent.Parent.Parent.Visible then table.insert(fresh, d) end
		end
		for i, it in fresh do
			scaleOf(it).Scale = 0
			task.delay(0.04 + math.min(i, 14) * 0.035, function() tween(scaleOf(it), 0.14, { Scale = 1 }, Enum.EasingStyle.Back) end)
		end
	end)
end
local cats = gui.Root.Categories
local mt = gui.Root.MutationTabs
local caption = gui.Root.MutationCaption
local function setCategory(name)
	select(cats, name)
	swap(function()
		mutationMode = name == "MutationsButton"
		for _, info in ZONES do
			list[info[1]].Visible = (name == "SecretsButton") == (info[1] == "SecretsSection")
		end
		refresh()
		mt.Visible = mutationMode
		caption.Visible = mutationMode
		if mutationMode then
			local i = 0
			for _, tab in mt:GetChildren() do
				if tab:IsA("GuiButton") then
					i += 1
					local s = scaleOf(tab)
					s.Scale = 0
					task.delay(i * 0.05, function() tween(s, 0.14, { Scale = 1 }, Enum.EasingStyle.Back) end)
				end
			end
		end
	end)
end
wire(cats.NormalButton, function() setCategory("NormalButton") end)
wire(cats.SecretsButton, function() setCategory("SecretsButton") end)
wire(cats.MutationsButton, function() setCategory("MutationsButton") end)
for _, tab in mt:GetChildren() do
	if tab:IsA("GuiButton") then
		wire(tab, function()
			select(mt, tab.Name)
			for _, t in mt:GetChildren() do
				if t:IsA("GuiButton") then t.Size = UDim2.fromScale(t == tab and 1 or 0.9, 0.115) end
			end
			caption.Text = "Collect every item in " .. tab.TabLabel.Text .. "!"
			swap(function() end)
		end)
	end
end

-- ouverture et fermeture par le prototype _G.UiFeel (bouton Index du HUD copié)
local state = { gui = gui, name = "UI_Index_v2", open = false, roots = { gui.Root } }
if _G.UiFeel and _G.UiFeel._screens then
	local old = _G.UiFeel._screens.UI_Index_v2
	if old and old.gui ~= gui and old.gui.Parent then old.gui:Destroy() end
	_G.UiFeel._screens.UI_Index_v2 = state
end
wire(win.CloseButton, function()
	play("UI_Close")
	state.open = false
	local s = scaleOf(gui.Root)
	tween(s, 0.09, { Scale = 0 })
	task.delay(0.09, function() if not state.open then gui.Enabled = false end end)
end, true)
if _G.UiFeel then
	_G.UiFeel.Open("UI_Index_v2")
else
	gui.Enabled = true
end
return ("Index v3 ouvert : %d objets, %d decouverts pour l'apercu"):format(total, found)
