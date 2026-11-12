--[[
	Aperçu en Edit du receleur v2 (DEV-034, 2026-11-12) : la réplique du vendeur au-dessus de
	Vendor_Pawn et les 3 choix à l'écran, d'après la référence de Clément : texte blanc sans fond,
	contour noir. Copies dans CoreGui (_PROTO_Pawn*) : rien n'est changé dans StarterGui ni dans la
	map, aucun script laissé.
	- 1 « Sell the item in my hand » (Giant TV, Épique, $216K) → confirmation Deal / No way.
	- 2 « Sell my whole inventory » (9 objets, $2.1M) → confirmation.
	- 3 « Nevermind » → « Come back anytime! », puis le dialogue revient 1,5 s après pour retester.
	Survol : le texte grossit (× 1,06) et passe en jaune. Appui × 0,95, relâché en 0,2, Success à la
	vente, pop de la réplique. Pas de son en Edit. Arrêt : _G.PawnProto.Stop().
]]

local CG = game:GetService("CoreGui")
local TS = game:GetService("TweenService")

if _G.PawnProto then pcall(_G.PawnProto.Stop) end
for _, n in { "_PROTO_PawnTalk", "_PROTO_PawnDialog" } do
	local o = CG:FindFirstChild(n)
	if o then o:Destroy() end
end

local conns = {}
local function on(sig, f) table.insert(conns, sig:Connect(f)) end
local function tween(o, t, props, style)
	local tw = TS:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local function scaleOf(o)
	local s = o:FindFirstChild("ProtoScale")
	if not s then s = Instance.new("UIScale"); s.Name = "ProtoScale"; s.Parent = o end
	return s
end
local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
local WHITE, YELLOW, GREEN, GREY = Color3.new(1, 1, 1), Color3.fromHex("fff36b"), Color3.fromHex("5cff4a"), Color3.fromHex("9aa3b5")
local function make(class, parent, props)
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	o.Parent = parent
	return o
end
local function label(p, name, text, color, maxSize, props)
	local t = make("TextLabel", p, { Name = name, Text = text, FontFace = FONT, TextColor3 = color, BackgroundTransparency = 1, TextScaled = true, TextWrapped = true })
	make("UITextSizeConstraint", t, { MaxTextSize = maxSize, MinTextSize = 8 })
	make("UIStroke", t, { Thickness = 2.2, Color = Color3.new(0, 0, 0), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
	for k, v in props or {} do t[k] = v end
	return t
end

-- réplique du vendeur (BB_PawnTalk) : texte blanc, sans fond ---------------------------------------
local vendor = workspace.Map.Hub.Stalls.ENV_Hub_PawnStall.Vendor_Pawn
local bb = make("BillboardGui", CG, { Name = "_PROTO_PawnTalk", Adornee = vendor.Head, Size = UDim2.fromOffset(420, 70), StudsOffset = Vector3.new(0, 2.8, 0), AlwaysOnTop = true, MaxDistance = 80, LightInfluence = 0 })
local line = label(bb, "Line", "Got anything to sell?", WHITE, 30, { Size = UDim2.fromScale(1, 1) })
local lineScale = scaleOf(line)
local function say(text)
	line.Text = text
	lineScale.Scale = 0.6
	tween(lineScale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- choix (UI_PawnShop.Dialog.Choices) : texte blanc, sans fond --------------------------------------
local gui = make("ScreenGui", CG, { Name = "_PROTO_PawnDialog", DisplayOrder = 40, IgnoreGuiInset = false })
local dialog = make("Frame", gui, { Name = "Dialog", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.58, 0.56), Size = UDim2.fromScale(0.3, 0.21), BackgroundTransparency = 1 })
make("UISizeConstraint", dialog, { MinSize = Vector2.new(384, 152) })
local choices = make("Frame", dialog, { Name = "Choices", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
make("UIListLayout", choices, { Padding = UDim.new(0.045, 0), SortOrder = Enum.SortOrder.LayoutOrder })

local rows = {}
local function setColor(r, c)
	r.key.TextColor3 = c
	r.label.TextColor3 = c
end
local function row(name, order, key, text, price)
	local b = make("TextButton", choices, { Name = name, LayoutOrder = order, Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 0.3), BackgroundTransparency = 1 })
	local k = label(b, "KeyLabel", key .. ".", WHITE, 26, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromScale(0.09, 0.6), TextXAlignment = Enum.TextXAlignment.Left })
	local cl = label(b, "ChoiceLabel", text, WHITE, 26, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.09, 0, 0.5, 0), Size = UDim2.fromScale(price and 0.68 or 0.9, 0.6), TextXAlignment = Enum.TextXAlignment.Left })
	local pl
	if price then
		pl = label(b, "Price", price, GREEN, 26, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromScale(0.22, 0.6), TextXAlignment = Enum.TextXAlignment.Right })
	end
	local r = { button = b, key = k, label = cl, price = pl, grey = false }
	local sc = scaleOf(b)
	local over = false
	on(b.MouseEnter, function() over = true; tween(sc, 0.08, { Scale = 1.06 }); if not r.grey then setColor(r, YELLOW) end end)
	on(b.MouseLeave, function() over = false; tween(sc, 0.08, { Scale = 1 }); setColor(r, r.grey and GREY or WHITE) end)
	on(b.MouseButton1Down, function() tween(sc, 0.05, { Scale = 0.95 }) end)
	on(b.MouseButton1Up, function() tween(sc, 0.2, { Scale = over and 1.06 or 1 }, Enum.EasingStyle.Back) end)
	rows[name] = r
	return r
end
row("SellHeldButton", 1, "1", "Sell the item in my hand", "$216K")
row("SellAllButton", 2, "2", "Sell my whole inventory", "$2.1M")
row("LeaveButton", 3, "3", "Nevermind", nil)
row("DealButton", 4, "1", "Deal!", "$216K")
row("NoDealButton", 5, "2", "No way", nil)

-- états du dialogue -------------------------------------------------------------------------------
local held, inv, pending
local function reset()
	held = { rarity = "An Epic", price = "$216K" }
	inv = { count = 9, price = "$2.1M" }
	for _, n in { "SellHeldButton", "SellAllButton" } do rows[n].grey = false; setColor(rows[n], WHITE) end
	rows.SellHeldButton.price.Text = held.price
	rows.SellAllButton.price.Text = inv.price
end
local function grey(name)
	local r = rows[name]
	r.grey = true
	setColor(r, GREY)
end
local function show(names)
	for n, r in rows do r.button.Visible = table.find(names, n) ~= nil end
	for i, n in names do
		local s = scaleOf(rows[n].button)
		s.Scale = 0
		task.delay(0.08 + (i - 1) * 0.035, function() tween(s, 0.14, { Scale = 1 }, Enum.EasingStyle.Back) end)
	end
end
local function main()
	pending = nil
	show({ "SellHeldButton", "SellAllButton", "LeaveButton" })
end
local function success(b)
	local s = scaleOf(b)
	s.Scale = 1.22
	tween(s, 0.28, { Scale = 1 }, Enum.EasingStyle.Back)
end
on(rows.SellHeldButton.button.Activated, function()
	if not held then say("You're holding nothing, pal."); return end
	pending = "held"
	rows.DealButton.price.Text = held.price
	say(held.rarity .. "? I'll give you " .. held.price .. ". Deal?")
	show({ "DealButton", "NoDealButton" })
end)
on(rows.SellAllButton.button.Activated, function()
	if inv.count == 0 then say("Your bag is empty, buddy."); return end
	pending = "all"
	rows.DealButton.price.Text = inv.price
	say(inv.count .. " items for " .. inv.price .. ". Deal?")
	show({ "DealButton", "NoDealButton" })
end)
on(rows.DealButton.button.Activated, function()
	success(rows.DealButton.button)
	if pending == "held" then
		held = nil
		inv.count -= 1
		rows.SellHeldButton.price.Text = "—"; grey("SellHeldButton")
	elseif pending == "all" then
		held = nil; inv.count = 0
		rows.SellHeldButton.price.Text = "—"; grey("SellHeldButton")
		rows.SellAllButton.price.Text = "$0"; grey("SellAllButton")
	end
	say("Pleasure doing business!")
	task.delay(0.35, main)
end)
on(rows.NoDealButton.button.Activated, function()
	say("Suit yourself.")
	main()
end)
on(rows.LeaveButton.button.Activated, function()
	say("Come back anytime!")
	tween(scaleOf(dialog), 0.09, { Scale = 0 })
	task.delay(1.5, function()
		if not gui.Parent then return end
		reset()
		scaleOf(dialog).Scale = 1
		say("Got anything to sell?")
		main()
	end)
end)
reset()
main()

-- caméra devant le stand, comme un joueur sur le ShopPad
local head = vendor.Head.Position
local cam = workspace.CurrentCamera
cam.CFrame = CFrame.lookAt(head + Vector3.new(-17, 3, -2.5), head + Vector3.new(0, 0.6, -2.5))

_G.PawnProto = {
	Stop = function()
		for _, c in conns do c:Disconnect() end
		if bb.Parent then bb:Destroy() end
		if gui.Parent then gui:Destroy() end
		_G.PawnProto = nil
	end,
}

task.wait(0.4)
local r = rows.SellHeldButton.button
local overflow = {}
for n, x in rows do if x.button.Visible and not x.label.TextFits then table.insert(overflow, n) end end
return string.format("vue %s ; choix %dx%d ; dialogue x %d..%d y %d..%d ; textes qui débordent : %s", tostring(cam.ViewportSize), r.AbsoluteSize.X, r.AbsoluteSize.Y,
	dialog.AbsolutePosition.X, dialog.AbsolutePosition.X + dialog.AbsoluteSize.X, dialog.AbsolutePosition.Y, dialog.AbsolutePosition.Y + dialog.AbsoluteSize.Y, #overflow > 0 and table.concat(overflow, ", ") or "aucun")
