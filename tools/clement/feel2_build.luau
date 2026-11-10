--[[
	Construit dans Studio (Edit), sans script, d'après la vidéo de Clément du 2026-11-10 (20h03) :
	- StarterGui/UI_Offline : « Offline Cash », « You earned: », billets + montant, Claim et ×2 Robux ;
	- StarterGui/UI_Toast : messages en bas au centre, texte seul (vert pour une réussite) ;
	- StarterGui/UI_Hotbar : barre du bas maison (survol, $/s au-dessus de chaque case, case équipée) ;
	- ReplicatedStorage/Assets/UI/BB_GuardShout : bulle du vigile (« STOP RIGHT THERE! ») et « ! » ;
	- UI_Escape.Flash : flash doré plein écran à l'arrivée en zone safe ;
	- UI_Inventory : « $/s » plus grand sur les cartes d'objets ;
	- sons de la poursuite, de l'argent hors ligne et de la zone safe dans Assets/Sounds.
	Relançable : chaque élément est refait à neuf.
]]

local SG = game:GetService("StarterGui")
local RS = game:GetService("ReplicatedStorage")
local CP = game:GetService("ContentProvider")
local C = Color3.fromHex
local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
local FONT_IT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
local INK = C("040435")

local function make(class, parent, props)
	local o = Instance.new(class)
	for k, v in props or {} do o[k] = v end
	o.Parent = parent
	return o
end
local function corner(o, s) return make("UICorner", o, { CornerRadius = UDim.new(s or 0.08, 0) }) end
local function stroke(o, th, col) return make("UIStroke", o, { Thickness = th or 2.5, Color = col or C("0b0b0b"), ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Round }) end
local function grad(o, a, b, rot) return make("UIGradient", o, { Color = ColorSequence.new(a, b), Rotation = rot or 90 }) end
local function frame(parent, name, props)
	local f = make("Frame", parent, { Name = name, BorderSizePixel = 0, BackgroundTransparency = 1 })
	for k, v in props or {} do f[k] = v end
	return f
end
local function label(parent, name, text, props, strokeColor)
	local t = make("TextLabel", parent, { Name = name, Text = text, FontFace = FONT, TextScaled = true, TextWrapped = true, TextColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5) })
	for k, v in props or {} do t[k] = v end
	make("UIStroke", t, { Thickness = 0.08, StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize, Color = strokeColor or C("0b0b0b"), LineJoinMode = Enum.LineJoinMode.Round })
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
	stroke(b, 3)
	make("UISizeConstraint", b, { MinSize = Vector2.new(0, 44) })
	return b
end
local function screen(name, order, group)
	local old = SG:FindFirstChild(name)
	if old then old:Destroy() end
	local g = make("ScreenGui", nil, { Name = name, Enabled = false, ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = order })
	if group then g:SetAttribute("ScreenGroup", group) end
	return g
end

local done = {}

-- UI_Offline : même fenêtre que les autres écrans (copie de UI_Settings), bandeau vert de la
-- boutique Robux, boutons d'achat de UI_WeaponShop (vert) et violet du RobuxButton des panneaux.
-- Boutons centrés sur leur point (AnchorPoint 0,5) : au survol (× 1,06), ils ne se touchent pas.
do
	local old = SG:FindFirstChild("UI_Offline")
	local flyerOld = old and old:FindFirstChild("Flyer") and old.Flyer:Clone()
	if old then old:Destroy() end
	local gui = SG.UI_Settings:Clone()
	gui.Name = "UI_Offline"
	gui.Enabled = false
	gui.DisplayOrder = 20
	gui:SetAttribute("ScreenGroup", "Menu")
	local win = gui.Root.Window
	win.Rows:Destroy()
	win.CloseButton:Destroy() -- on ne ferme qu'en encaissant (Claim ou ×2)
	local header = win.Header
	local function setGrad(g, a, b) local r = g.Rotation; g.Color = ColorSequence.new(C(a), C(b)); g.Rotation = r end
	setGrad(header.UIGradient, "8df03e", "46c41a")
	setGrad(header.HeaderFill.UIGradient, "6ada2c", "46c41a")
	header.Title.Text = "Offline Cash"
	local function text(name, txt, pos, size, color)
		local t = header.Title:Clone()
		t.Name = name; t.Text = txt; t.AnchorPoint = Vector2.new(0.5, 0.5); t.Position = pos; t.Size = size
		t.TextXAlignment = Enum.TextXAlignment.Center; t.ZIndex = 6
		if color then t.TextColor3 = color end
		t.Parent = win
		return t
	end
	text("EarnedLabel", "You earned:", UDim2.fromScale(0.5, 0.245), UDim2.fromScale(0.7, 0.1))
	make("ImageLabel", win, { Name = "CashIcon", Image = "rbxassetid://138179722277427", BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.fromScale(0.44, 0.36), Rotation = -4, ZIndex = 5 })
	text("Amount", "$0", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.7, 0.17), C("5cff4a"))
	local buy = SG.UI_WeaponShop:FindFirstChild("BuyButton", true)
	local function makeButton(name, centerX, a, b)
		local btn = buy:Clone()
		btn.Name = name; btn.AnchorPoint = Vector2.new(0.5, 0.5); btn.Position = UDim2.fromScale(centerX, 0.835)
		btn.Size = UDim2.fromScale(0.4, 0.16); btn.ZIndex = 8
		setGrad(btn.UIGradient, a, b)
		btn.Parent = win
		return btn
	end
	local claim = makeButton("ClaimButton", 0.27, "91f630", "31dd22")
	claim.Content.CashIcon:Destroy()
	local cl = claim.Content.Price
	cl.Name = "ClaimLabel"; cl.Text = "CLAIM"; cl.Size = UDim2.fromScale(0.8, 0.62)
	local dbl = makeButton("DoubleButton", 0.73, "c79bff", "7a3be0")
	local ri = dbl.Content.CashIcon
	ri.Name = "RobuxIcon"; ri.Image = "rbxassetid://139320447847280"
	local pl = dbl.Content.Price
	pl.Name = "PriceLabel"; pl.Text = "???"
	local tag = header.Title:Clone()
	tag.Name = "TwoXTag"; tag.Text = "2x"; tag.AnchorPoint = Vector2.new(0.5, 0.5); tag.Position = UDim2.fromScale(0.95, 0.02)
	tag.Size = UDim2.fromScale(0.3, 0.6); tag.Rotation = 14; tag.TextColor3 = C("ffe066"); tag.TextXAlignment = Enum.TextXAlignment.Center; tag.ZIndex = 12
	tag.Parent = dbl
	if flyerOld then
		flyerOld.Parent = gui
	else -- billets qui volent vers l'argent du HUD après Claim (le code les déplace)
		local flyer = frame(gui, "Flyer", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.86), Size = UDim2.fromScale(0.09, 0.09), SizeConstraint = Enum.SizeConstraint.RelativeYY, Visible = false, BackgroundTransparency = 0, BackgroundColor3 = C("3ec9e8"), ZIndex = 10 })
		corner(flyer, 0.1)
		stroke(flyer, 3, Color3.new(1, 1, 1))
		make("ImageLabel", flyer, { Name = "Icon", Image = "rbxassetid://138179722277427", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromScale(0.86, 0.72), ScaleType = Enum.ScaleType.Fit, ZIndex = 11 })
		label(flyer, "FlyerAmount", "$0", { Position = UDim2.fromScale(0.5, 0.84), Size = UDim2.fromScale(1.05, 0.3), ZIndex = 12 })
	end
	gui.Parent = SG
	table.insert(done, "UI_Offline")
end

-- UI_Toast ----------------------------------------------------------------------------------------
do
	local gui = screen("UI_Toast", 30)
	local stack = frame(gui, "Stack", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.86), Size = UDim2.fromScale(0.72, 0.2) })
	make("UIListLayout", stack, { VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder })
	local t = label(stack, "Template", "Crown equipped!", { Size = UDim2.fromScale(1, 0.24), TextColor3 = C("5dff3a"), Visible = false })
	make("UITextSizeConstraint", t, { MaxTextSize = 36, MinTextSize = 14 })
	gui.Parent = SG
	table.insert(done, "UI_Toast")
end

-- UI_Hotbar ---------------------------------------------------------------------------------------
do
	local gui = screen("UI_Hotbar", 5)
	local bar = frame(gui, "Bar", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.985), Size = UDim2.fromScale(0.62, 0.082) })
	make("UISizeConstraint", bar, { MinSize = Vector2.new(0, 50) })
	make("UIListLayout", bar, { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
	local slot = make("TextButton", bar, { Name = "Template", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 2 })
	make("UIAspectRatioConstraint", slot, { AspectRatio = 1 })
	local clip = frame(slot, "Clip", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0, BackgroundColor3 = C("2e3a2b"), ClipsDescendants = true, ZIndex = 2 })
	corner(clip, 0.1)
	stroke(clip, 2.5)
	grad(clip, Color3.new(1, 1, 1), C("9a9a9a"))
	make("ImageLabel", clip, { Name = "Glow", Image = "rbxassetid://130850617844067", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromScale(1.3, 1.3), ImageTransparency = 0.55, ZIndex = 3 })
	make("ImageLabel", slot, { Name = "Icon", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0.11, 0.86), Size = UDim2.fromScale(0.78, 0.72), ScaleType = Enum.ScaleType.Fit, ZIndex = 5 })
	label(slot, "KeyLabel", "1", { AnchorPoint = Vector2.new(0, 0), Position = UDim2.fromScale(0.06, 0.03), Size = UDim2.fromScale(0.3, 0.3), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6 })
	label(slot, "ItemName", "Item", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.98), Size = UDim2.fromScale(0.96, 0.24), ZIndex = 6 })
	label(slot, "Income", "$0/s", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, -0.03), Size = UDim2.fromScale(1.4, 0.32), TextColor3 = C("74ff3d"), ZIndex = 6 })
	local eq = frame(slot, "Equipped", { Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 7 })
	corner(eq, 0.1)
	make("UIStroke", eq, { Color = C("7dff4a"), Thickness = 3.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	local ho = frame(slot, "HoverOutline", { Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 8 })
	corner(ho, 0.1)
	make("UIStroke", ho, { Color = Color3.new(1, 1, 1), Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	gui.Parent = SG
	table.insert(done, "UI_Hotbar")
end

-- BB_GuardShout -----------------------------------------------------------------------------------
do
	local ui = RS.Assets.UI
	local old = ui:FindFirstChild("BB_GuardShout")
	if old then old:Destroy() end
	local bb = make("BillboardGui", nil, { Name = "BB_GuardShout", Size = UDim2.new(6, 90, 2.3, 32), -- studs + pixels : lisible de loin
		 StudsOffset = Vector3.new(0, 4.4, 0), AlwaysOnTop = true, MaxDistance = 150, LightInfluence = 0, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, ClipsDescendants = false })
	local bubble = frame(bb, "Bubble", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.45, 0), Size = UDim2.fromScale(0.8, 0.72), BackgroundTransparency = 0, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3 })
	corner(bubble, 0.4)
	stroke(bubble, 3, INK)
	local tail = frame(bb, "Tail", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.4, 0.72), Size = UDim2.fromScale(0.13, 0.13), SizeConstraint = Enum.SizeConstraint.RelativeXX, Rotation = 45, BackgroundTransparency = 0, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 2 })
	stroke(tail, 3, INK)
	label(bubble, "ShoutLabel", "STOP RIGHT THERE!", { Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.9, 0.7), TextColor3 = C("e3241b"), ZIndex = 4 }, INK)
	label(bb, "Bang", "!", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.94, 0.95), Size = UDim2.fromScale(0.22, 1), TextColor3 = C("ff2d55"), ZIndex = 5 }, INK)
	bb.Parent = ui
	table.insert(done, "BB_GuardShout")
end

-- UI_Escape : flash doré ---------------------------------------------------------------------------
do
	local esc = SG:FindFirstChild("UI_Escape")
	if esc then
		local old = esc:FindFirstChild("Flash")
		if old then old:Destroy() end
		frame(esc, "Flash", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C("ffd94a"), BackgroundTransparency = 1, ZIndex = 0 })
		table.insert(done, "UI_Escape.Flash")
	end
end

-- UI_Inventory : $/s plus grand ----------------------------------------------------------------------
do
	local section = SG.UI_Inventory:FindFirstChild("ItemsSection", true)
	local t = section and section.Cards:FindFirstChild("Template")
	if t then
		t.ItemName.Position = UDim2.fromScale(0.5, 0.483)
		t.ItemName.Size = UDim2.fromScale(0.94, 0.105)
		t.Income.Position = UDim2.fromScale(0.5, 0.588)
		t.Income.Size = UDim2.fromScale(0.94, 0.108)
		table.insert(done, "UI_Inventory Income")
	end
end

-- sons ----------------------------------------------------------------------------------------------
do
	local S = RS.Assets.Sounds
	local function folder(name) local f = S:FindFirstChild(name) or make("Folder", S, { Name = name }) return f end
	local list = {
		{ "Chase", "Chase_Music", 1842577591, 0.45, true }, -- APM « Police Chase »
		{ "Chase", "Chase_Siren", 9045196969, 0.3, true }, -- APM « Aerial Onslaught Synth Siren Blasts »
		{ "Chase", "Chase_Whistle", 9125775207, 0.6, false }, -- ProSoundEffects, sifflet de policier
		{ "Chase", "Guard_Radio", 9125773804, 0.5, false }, -- ProSoundEffects, voix de radio de police
		{ "Heist", "Heist_Grab", 9039709283, 0.6, false }, -- APM « Rush Rush Rush - Sting 2 », départ de la poursuite
		{ "Heist", "Heist_SafeFlash", 9126076030, 0.6, false }, -- ProSoundEffects, éclat brillant à l'entrée en zone safe
		{ "Cash", "Offline_Claim", 127645268874265, 0.7, false }, -- Roblox « CoinTransfer_01 »
		{ "UI", "UI_Equip", 10066947742, 0.45, false },
	}
	local sounds = {}
	for _, e in list do
		local f = folder(e[1])
		local s = S:FindFirstChild(e[2], true) or make("Sound", f, { Name = e[2] })
		s.SoundId = "rbxassetid://" .. e[3]
		s.Volume = e[4]
		s.Looped = e[5]
		table.insert(sounds, s)
	end
	CP:PreloadAsync(sounds)
	local bad = {}
	for _, s in sounds do if not s.IsLoaded then table.insert(bad, s.Name) end end
	table.insert(done, "sons (" .. #sounds .. ", non charges : " .. (#bad > 0 and table.concat(bad, ",") or "aucun") .. ")")
end

return "construit : " .. table.concat(done, " ; ")
