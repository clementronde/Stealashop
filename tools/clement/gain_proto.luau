--[[
	Prototype jouable en Edit (sans Play) des gains qui s'affichent puis volent vers le total
	(liaison L-091). Tout est copié dans CoreGui : rien n'est gardé dans la place.
	- Un panneau de 5 boutons, en bas à droite : TREADMILL, BENCH, CASH PAD, OFFLINE, REWARD.
	- TREADMILL et BENCH : BB_Gain au-dessus du tapis ou du banc de la boutique 1 (regarde-la dans la
	  vue 3D), « +2 Speed/s » ou « +5 Power », 5 fois de suite.
	- CASH PAD : « +$1.2K » au-dessus du premier présentoir, puis la case UI_HUD.CashFly.Template part
	  de là et vole jusqu'à l'argent du HUD, qui sursaute, avec « +$1.2K » vert à côté.
	- OFFLINE et REWARD : la même case part du centre de l'écran.
	Montants d'exemple. En Edit, Studio ne joue pas les sons. Arrêt : _G.GainProto.Stop().
]]

local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local CS = game:GetService("CollectionService")
local SG = game:GetService("StarterGui")
local RS = game:GetService("ReplicatedStorage")

if _G.GainProto then pcall(_G.GainProto.Stop) end

local M = {
	GainPopFrom = 0.4, GainPopTime = 0.16, GainRise = 2.2, GainTime = 1, GainFadeAt = 0.55, GainSpreadX = 1, GainBurstGap = 0.25,
	FlyPopTo = 1.1, FlyPopTime = 0.22, FlyHold = 0.23, FlyTime = 0.4, FlyEndScale = 0.3,
	BumpTo = 1.15, BumpTime = 0.3, PlusPopFrom = 0.4, PlusPopTime = 0.22, PlusHold = 1.6, PlusRise = 24, PlusFade = 0.4,
}
local made, conns = {}, {}
local function tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local function scaleOf(o)
	local s = o:FindFirstChildOfClass("UIScale")
	if not s then s = Instance.new("UIScale"); s.Name = "ProtoScale"; s.Parent = o end
	return s
end

-- HUD copié (pour voir l'argent en bas à gauche) et calque des cases qui volent
for _, n in { "_PROTO_Gain_HUD", "_PROTO_Gain_Fly", "_PROTO_Gain_Panel" } do
	local o = CoreGui:FindFirstChild(n)
	if o then o:Destroy() end
end
local hud = SG.UI_HUD:Clone()
hud.Name = "_PROTO_Gain_HUD"
hud.Parent = CoreGui
table.insert(made, hud)
local flyGui = Instance.new("ScreenGui")
flyGui.Name = "_PROTO_Gain_Fly"
flyGui.DisplayOrder = 70
flyGui.IgnoreGuiInset = hud.IgnoreGuiInset
flyGui.Parent = CoreGui
table.insert(made, flyGui)
local flyTpl = hud.CashFly.Template
local plusTpl = hud.CashFly.CounterPop
local cashLabel
for _, d in hud:GetDescendants() do
	if d:IsA("TextLabel") and d.Text:match("^%$") and d:FindFirstAncestor("CashRow") then cashLabel = d end
end
local cashRow = cashLabel and cashLabel:FindFirstAncestor("CashRow")
local cash = 21800

local function setCash(n)
	cash = n
	if not cashLabel then return end
	if n >= 1e6 then cashLabel.Text = string.format("$%.1fM", n / 1e6) elseif n >= 1e3 then cashLabel.Text = string.format("$%.1fK", n / 1e3) else cashLabel.Text = "$" .. n end
end
local function bumpCounter(text, amount)
	if cashRow then
		local s = scaleOf(cashRow)
		s.Scale = M.BumpTo
		tween(s, M.BumpTime, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	local v = Instance.new("NumberValue")
	v.Value = cash
	v.Changed:Connect(function(x) setCash(math.floor(x)) end)
	tween(v, 0.6, { Value = cash + amount }, Enum.EasingStyle.Cubic)
	task.delay(0.65, function() v:Destroy() end)
	if not cashLabel then return end
	local p = plusTpl:Clone()
	p.Text = "+" .. text
	p.Visible = true
	p.Position = UDim2.fromOffset(cashLabel.AbsolutePosition.X + cashLabel.TextBounds.X + 14, cashLabel.AbsolutePosition.Y + cashLabel.AbsoluteSize.Y / 2)
	p.Parent = flyGui
	local s = scaleOf(p)
	s.Scale = M.PlusPopFrom
	tween(s, M.PlusPopTime, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(M.PlusHold, function()
		tween(p, M.PlusFade, { TextTransparency = 1, Position = p.Position - UDim2.fromOffset(0, M.PlusRise) })
		local st = p:FindFirstChildOfClass("UIStroke")
		if st then tween(st, M.PlusFade, { Transparency = 1 }) end
		task.delay(M.PlusFade + 0.02, function() p:Destroy() end)
	end)
end
local function cashFly(text, amount, fromPos)
	local fl = flyTpl:Clone()
	fl.FlyerAmount.Text = text
	fl.Position = fromPos or UDim2.fromScale(0.5, 0.55)
	fl.Visible = true
	fl.Parent = flyGui
	local fs = scaleOf(fl)
	fs.Scale = 0
	tween(fs, M.FlyPopTime, { Scale = M.FlyPopTo }, Enum.EasingStyle.Back)
	task.delay(M.FlyPopTime + M.FlyHold, function()
		local target = cashLabel and UDim2.fromOffset(cashLabel.AbsolutePosition.X + 20, cashLabel.AbsolutePosition.Y + cashLabel.AbsoluteSize.Y / 2) or UDim2.fromScale(0.08, 0.94)
		tween(fl, M.FlyTime, { Position = target }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween(fs, M.FlyTime, { Scale = M.FlyEndScale }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(M.FlyTime, function()
			fl:Destroy()
			bumpCounter(text, amount)
		end)
	end)
end

-- gains au-dessus d'un point du monde (en Edit : le tapis, le banc ou un présentoir de la boutique 1)
local function firstTagged(tag)
	for _, m in CS:GetTagged(tag) do
		if m:IsDescendantOf(workspace) and m:FindFirstAncestor("PLOT_Shop_01") then return m end
	end
	return CS:GetTagged(tag)[1]
end
local function partOf(m)
	if not m then return nil end
	if m:IsA("BasePart") then return m end
	return m:IsA("Model") and (m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)) or nil
end
local function floatGain(adornee, text, color, icon)
	local bb = RS.Assets.UI.BB_Gain:Clone()
	bb.Adornee = adornee
	bb.Row.Amount.Text = text
	bb.Row.Amount.TextColor3 = color
	bb.Row.Icon.Image = icon
	local x = (math.random() - 0.5) * 2 * M.GainSpreadX
	bb.StudsOffset = Vector3.new(x, 3.2, 0)
	bb.Parent = CoreGui
	table.insert(made, bb)
	local s = scaleOf(bb.Row)
	s.Scale = M.GainPopFrom
	tween(s, M.GainPopTime, { Scale = 1 }, Enum.EasingStyle.Back)
	local v = Instance.new("NumberValue")
	v.Changed:Connect(function(a)
		bb.StudsOffset = Vector3.new(x, 3.2 + M.GainRise * a, 0)
		local fade = math.clamp((a - M.GainFadeAt) / (1 - M.GainFadeAt), 0, 1)
		bb.Row.Amount.TextTransparency = fade
		bb.Row.Icon.ImageTransparency = fade
		local st = bb.Row.Amount:FindFirstChildOfClass("UIStroke")
		if st then st.Transparency = fade end
	end)
	tween(v, M.GainTime, { Value = 1 }, Enum.EasingStyle.Quad)
	task.delay(M.GainTime + 0.05, function() bb:Destroy(); v:Destroy() end)
end
local SPEED = { Color3.fromHex("4fd2ff"), "rbxassetid://80577187405028" }
local POWER = { Color3.fromHex("ff7a3a"), "rbxassetid://90840823209764" }
local CASH = { Color3.fromHex("5cff4a"), "rbxassetid://138179722277427" }

-- panneau de démo
local panel = Instance.new("ScreenGui")
panel.Name = "_PROTO_Gain_Panel"
panel.DisplayOrder = 71
panel.Parent = CoreGui
table.insert(made, panel)
local holder = Instance.new("Frame")
holder.BackgroundTransparency = 1
holder.AnchorPoint = Vector2.new(1, 1)
holder.Position = UDim2.new(1, -16, 1, -16)
holder.Size = UDim2.fromOffset(190, 5 * 52)
holder.Parent = panel
local lay = Instance.new("UIListLayout")
lay.Padding = UDim.new(0, 8)
lay.Parent = holder
local buy = SG.UI_WeaponShop:FindFirstChild("BuyButton", true)
local function demoButton(label, order, fn)
	local b = buy:Clone()
	b.Name = label
	b.LayoutOrder = order
	b.Size = UDim2.fromOffset(190, 44)
	b.Position = UDim2.new()
	b.AnchorPoint = Vector2.new()
	local price = b:FindFirstChild("Price", true)
	if price then price.Text = label end
	local icon = b:FindFirstChild("CashIcon", true)
	if icon then icon:Destroy() end
	b.Parent = holder
	table.insert(conns, b.Activated:Connect(fn))
end
demoButton("TREADMILL", 1, function()
	local p = partOf(firstTagged("Treadmill"))
	for i = 0, 4 do task.delay(i * M.GainBurstGap, function() if p then floatGain(p, "+2 Speed/s", SPEED[1], SPEED[2]) end end) end
end)
demoButton("BENCH", 2, function()
	local p = partOf(firstTagged("Bench"))
	for i = 0, 4 do task.delay(i * M.GainBurstGap, function() if p then floatGain(p, "+5 Power", POWER[1], POWER[2]) end end) end
end)
demoButton("CASH PAD", 3, function()
	local slot
	local plot = workspace:FindFirstChild("PLOT_Shop_01", true)
	if plot then slot = plot:FindFirstChild("CollectPad", true) or plot:FindFirstChild("DisplaySlot_01", true) end
	local p = partOf(slot)
	if p then floatGain(p, "+$1.2K", CASH[1], CASH[2]) end
	local from
	if p then
		local v, on = workspace.CurrentCamera:WorldToViewportPoint(p.Position + Vector3.new(0, 3, 0))
		if on then from = UDim2.fromOffset(v.X, v.Y) end
	end
	cashFly("$1.2K", 1200, from)
end)
demoButton("OFFLINE", 4, function() cashFly("$4.8K", 4800) end)
demoButton("REWARD", 5, function() cashFly("$1K", 1000) end)

_G.GainProto = {
	Stop = function()
		for _, c in conns do c:Disconnect() end
		for _, o in made do if o.Parent then o:Destroy() end end
		_G.GainProto = nil
	end,
	Values = M,
}
return "prototype des gains pret : 5 boutons en bas a droite"
