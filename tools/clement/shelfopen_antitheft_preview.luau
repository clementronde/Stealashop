--[[
	Aperçu en Edit (L-112, 2026-11-12) : ouverture du colis dans le magasin PNJ et antivol en base.
	Rien n'est encore dans Assets/UI : c'est la maquette à valider par Clément, dans la vraie scène.
	- BB_ShelfOpen au-dessus d'un colis Rare posé sur ShelfSlot_01 de STORE_Z1_Superette : la jauge
	  monte pendant 5 s (on reste appuyé), la rareté change avec un pop (Common → … → Divine), le
	  rouleau d'icônes défile, puis l'objet obtenu (icône, nom, rareté, mutation).
	- HoldButton (proposé pour UI_HUD, téléphone) : rond en bas à droite, se remplit avec la jauge.
	- BB_AntiTheft au-dessus d'une Giant TV posée sur DisplaySlot_01 de PLOT_Shop_01 : cadenas,
	  anneau de 12 segments qui se vide (12 s ici), temps restant ; à la fin, le cadenas saute.
	Copies : CoreGui (_PROTO_*) et Workspace/_PREVIEW_ShelfOpen (le colis et l'objet posés pour
	l'aperçu). Aucun script laissé. Arrêt : _G.ShelfProto.Stop().
	Caméra : _G.ShelfProto.LookShelf() et _G.ShelfProto.LookDisplay().
]]

local CG = game:GetService("CoreGui")
local TS = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")

if _G.ShelfProto then pcall(_G.ShelfProto.Stop) end

local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
local BLACK, WHITE = Color3.new(0, 0, 0), Color3.new(1, 1, 1)
local RARITIES = {
	{ "COMMON", "B0B7C3" }, { "UNCOMMON", "2FE08F" }, { "RARE", "2F9BFF" }, { "EPIC", "A855F7" },
	{ "LEGENDARY", "FFC21A" }, { "MYTHIC", "FF3B5C" }, { "SECRET", "FF3B3B" }, { "DIVINE", "FFE9A8" },
}
local function make(class, parent, props)
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	o.Parent = parent
	return o
end
local function corner(o, r) make("UICorner", o, { CornerRadius = r or UDim.new(0, 10) }) end
local function stroke(o, th) make("UIStroke", o, { Thickness = th or 3, Color = BLACK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) end
local function label(p, name, text, color, maxSize, props)
	local t = make("TextLabel", p, { Name = name, Text = text, FontFace = FONT, TextColor3 = color, BackgroundTransparency = 1, TextScaled = true, TextWrapped = true })
	make("UITextSizeConstraint", t, { MaxTextSize = maxSize, MinTextSize = 8 })
	make("UIStroke", t, { Thickness = 2.4, Color = BLACK, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
	for k, v in props or {} do t[k] = v end
	return t
end
local function scaleOf(o)
	local s = o:FindFirstChild("ProtoScale")
	if not s then s = Instance.new("UIScale"); s.Name = "ProtoScale"; s.Parent = o end
	return s
end
local function pop(o, from, t)
	local s = scaleOf(o)
	s.Scale = from
	TS:Create(s, TweenInfo.new(t or 0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end
local ICONS = RS.Assets:FindFirstChild("Icons")
local iconList = {}
if ICONS then
	for _, d in ICONS:GetDescendants() do
		if d:IsA("Decal") and d.Name:match("^ICON_Z%d_") then table.insert(iconList, d.Texture) end
	end
end
local function icon(name)
	local d = ICONS and ICONS:FindFirstChild(name, true)
	return d and d.Texture or ""
end

-- objets d'aperçu dans la scène -----------------------------------------------------------------
local folder = workspace:FindFirstChild("_PREVIEW_ShelfOpen") or make("Folder", workspace, { Name = "_PREVIEW_ShelfOpen" })
folder:ClearAllChildren()
local store = workspace.Map.Zone_1.STORE_Z1_Superette
local slot = store:FindFirstChild("ShelfSlot_01", true)
local box = RS.Assets.Boxes.BOX_Rare:Clone()
box:PivotTo(CFrame.new(slot.WorldPosition))
for _, p in box:GetDescendants() do if p:IsA("BasePart") then p.Anchored = true end end
box.Parent = folder
local shop = workspace.Map.Hub.Shops.PLOT_Shop_01
local dslot = shop:FindFirstChild("DisplaySlot_01", true)
local item = RS.Assets.Items.ITM_Z3_TeleGeante:Clone()
item:PivotTo(CFrame.new(dslot.WorldPosition) * CFrame.Angles(0, math.rad(90), 0))
for _, p in item:GetDescendants() do if p:IsA("BasePart") then p.Anchored = true end end
item.Parent = folder

-- BB_ShelfOpen ------------------------------------------------------------------------------------
local so = make("BillboardGui", CG, { Name = "_PROTO_ShelfOpen", Adornee = box.PrimaryPart or box:FindFirstChildWhichIsA("BasePart"), Size = UDim2.fromOffset(300, 210), StudsOffset = Vector3.new(0, 3.2, 0), AlwaysOnTop = true, MaxDistance = 60, LightInfluence = 0 })
local panel = make("Frame", so, { Name = "Panel", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromHex("1b1f27"), BackgroundTransparency = 0.15 })
corner(panel, UDim.new(0, 16)); stroke(panel, 3)
local rarity = label(so, "Rarity", "COMMON", Color3.fromHex("B0B7C3"), 34, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.new(1, -24, 0, 38), ZIndex = 3 })
local reel = make("Frame", so, { Name = "Reel", Position = UDim2.fromOffset(12, 52), Size = UDim2.new(1, -24, 0, 72), BackgroundColor3 = Color3.fromHex("0e1118"), ClipsDescendants = true, ZIndex = 2 })
corner(reel)
local strip = make("Frame", reel, { Name = "Strip", Size = UDim2.new(0, 2000, 1, 0), BackgroundTransparency = 1, ZIndex = 2 })
make("UIListLayout", strip, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder })
local tpl = make("ImageLabel", strip, { Name = "Template", Visible = false, BackgroundTransparency = 1, Size = UDim2.fromOffset(60, 60), ScaleType = Enum.ScaleType.Fit, ZIndex = 2 })
for i = 1, 24 do
	local c = tpl:Clone(); c.Name = "Icon" .. i; c.Visible = true; c.LayoutOrder = i
	c.Image = #iconList > 0 and iconList[(i * 7) % #iconList + 1] or ""
	c.Parent = strip
end
make("Frame", reel, { Name = "Marker", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = Color3.fromHex("ffd84a"), ZIndex = 4 })
local meter = make("Frame", so, { Name = "Meter", Position = UDim2.fromOffset(12, 134), Size = UDim2.new(1, -24, 0, 24), BackgroundColor3 = Color3.fromHex("0e1118"), ZIndex = 2 })
corner(meter, UDim.new(1, 0)); stroke(meter, 2.5)
local fill = make("Frame", meter, { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromHex("B0B7C3"), ZIndex = 3 })
corner(fill, UDim.new(1, 0))
local hint = label(so, "Hint", "Hold E to open", WHITE, 24, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 166), Size = UDim2.new(1, -24, 0, 34), ZIndex = 3 })
local result = make("Frame", so, { Name = "Result", Visible = false, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5 })
make("ImageLabel", result, { Name = "ResultIcon", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(104, 104), BackgroundTransparency = 1, Image = icon("ICON_Z3_TeleGeante"), ScaleType = Enum.ScaleType.Fit, ZIndex = 5 })
label(result, "ResultName", "GIANT TV", WHITE, 30, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 114), Size = UDim2.new(1, -24, 0, 34), ZIndex = 5 })
label(result, "ResultRarity", "EPIC", Color3.fromHex("A855F7"), 26, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 148), Size = UDim2.new(0.6, 0, 0, 28), ZIndex = 5 })
local mut = make("Frame", result, { Name = "ResultMutation", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 178), Size = UDim2.fromOffset(96, 24), BackgroundColor3 = Color3.fromHex("ffc21a"), ZIndex = 5 })
corner(mut, UDim.new(1, 0)); stroke(mut, 2)
label(mut, "MutationLabel", "GOLD", WHITE, 18, { Size = UDim2.fromScale(1, 1), ZIndex = 6 })

-- HoldButton (téléphone, proposé dans UI_HUD) --------------------------------------------------------
local hg = make("ScreenGui", CG, { Name = "_PROTO_HoldButton", DisplayOrder = 30 })
local hold = make("TextButton", hg, { Name = "HoldButton", Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -150), Size = UDim2.fromScale(0.13, 0.13), BackgroundColor3 = Color3.fromHex("1b1f27"), BackgroundTransparency = 0.1, ClipsDescendants = true })
make("UIAspectRatioConstraint", hold, { AspectRatio = 1 })
make("UISizeConstraint", hold, { MinSize = Vector2.new(84, 84), MaxSize = Vector2.new(130, 130) })
corner(hold, UDim.new(1, 0)); stroke(hold, 4)
local hfill = make("Frame", hold, { Name = "HoldFill", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), BackgroundColor3 = Color3.fromHex("31dd22"), ZIndex = 2 })
label(hold, "HoldLabel", "HOLD TO OPEN", WHITE, 22, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.78, 0.5), ZIndex = 3 })

-- BB_AntiTheft ---------------------------------------------------------------------------------------
local at = make("BillboardGui", CG, { Name = "_PROTO_AntiTheft", Adornee = item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart"), Size = UDim2.fromOffset(124, 162), StudsOffset = Vector3.new(0, 4.2, 0), AlwaysOnTop = true, MaxDistance = 220, LightInfluence = 0 })
local tag = label(at, "TagLabel", "STEALABLE", Color3.fromHex("ff5a4a"), 20, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(1, 0, 0, 24) })
local ring = make("Frame", at, { Name = "Ring", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 26), Size = UDim2.fromOffset(104, 104), BackgroundTransparency = 1 })
local segs = {}
for i = 1, 12 do
	local a = math.rad((i - 1) * 30)
	local s = make("Frame", ring, { Name = string.format("Seg_%02d", i), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, math.sin(a) * 42, 0.5, -math.cos(a) * 42), Size = UDim2.fromOffset(11, 22), Rotation = (i - 1) * 30, BackgroundColor3 = Color3.fromHex("ff8c1a") })
	corner(s, UDim.new(1, 0)); stroke(s, 2)
	segs[i] = s
end
local lock = make("TextLabel", ring, { Name = "Lock", Text = "🔒", BackgroundTransparency = 1, TextScaled = true, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(56, 56), ZIndex = 3 })
lock:SetAttribute("IconAsset", "UI_Icon_Lock")
local timeL = label(at, "TimeLabel", "2:00", WHITE, 28, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 132), Size = UDim2.new(1, 0, 0, 30) })

-- démos en boucle -----------------------------------------------------------------------------------
local running = true
task.spawn(function()
	while running and so.Parent do
		result.Visible = false
		for _, o in { rarity, reel, meter, hint } do o.Visible = true end
		local step = 0
		local t0 = os.clock()
		local HOLD = 5
		local x = 0
		while running and os.clock() - t0 < HOLD do
			local p = (os.clock() - t0) / HOLD
			fill.Size = UDim2.fromScale(p, 1)
			hfill.Size = UDim2.fromScale(1, p)
			local k = math.min(#RARITIES, 1 + math.floor(p * #RARITIES))
			if k ~= step then
				step = k
				rarity.Text = RARITIES[k][1]
				local c = Color3.fromHex(RARITIES[k][2])
				rarity.TextColor3 = c; fill.BackgroundColor3 = c
				pop(rarity, 1.35, 0.25)
			end
			x -= 6 + p * 10
			if x < -68 * 12 then x += 68 * 12 end
			strip.Position = UDim2.fromOffset(x, 0)
			task.wait()
		end
		if not running then break end
		for _, o in { rarity, reel, meter, hint } do o.Visible = false end
		result.Visible = true
		pop(result, 0, 0.3)
		hfill.Size = UDim2.fromScale(1, 0)
		task.wait(2.6)
		fill.Size = UDim2.fromScale(0, 1)
	end
end)
task.spawn(function()
	local TOTAL = 12
	while running and at.Parent do
		tag.Text = "STEALABLE"; tag.TextColor3 = Color3.fromHex("ff5a4a")
		lock.Visible = true; lock.Position = UDim2.fromScale(0.5, 0.5); lock.Rotation = 0; lock.TextTransparency = 0
		scaleOf(lock).Scale = 1
		for _, s in segs do s.Visible = true; s.BackgroundTransparency = 0 end
		for left = TOTAL, 1, -1 do
			if not running then return end
			timeL.Text = string.format("0:%02d", left)
			task.wait(1)
			local s = segs[TOTAL - left + 1]
			TS:Create(s, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
		end
		timeL.Text = "0:00"
		-- le cadenas saute
		local sc = scaleOf(lock)
		TS:Create(sc, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.4 }):Play()
		TS:Create(lock, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 26, 0.5, -46), Rotation = 35, TextTransparency = 1 }):Play()
		tag.Text = "SAFE"; tag.TextColor3 = Color3.fromHex("5cff4a")
		pop(tag, 1.4, 0.25)
		task.wait(2.2)
	end
end)

local cam = workspace.CurrentCamera
local function lookAt(pos, target)
	cam.CFrame = CFrame.lookAt(pos, target)
	cam.Focus = CFrame.new(target)
end
_G.ShelfProto = {
	Stop = function()
		running = false
		for _, o in { so, hg, at } do if o.Parent then o:Destroy() end end
		if folder.Parent then folder:Destroy() end
		_G.ShelfProto = nil
	end,
	LookShelf = function() lookAt(slot.WorldPosition + Vector3.new(0, 4.5, -11), slot.WorldPosition + Vector3.new(0, 2.5, 0)) end,
	LookDisplay = function() lookAt(dslot.WorldPosition + Vector3.new(13, 6, 0), dslot.WorldPosition + Vector3.new(0, 3, 0)) end,
}
_G.ShelfProto.LookShelf()
return "aperçu posé : colis Rare sur ShelfSlot_01 de la supérette, Giant TV sur DisplaySlot_01 de la boutique 1"
