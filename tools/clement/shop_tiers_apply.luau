--[[
	Paliers des boutiques (validés par Clément le 2026-11-13, prototype shop_tiers_proto.luau) : on comprend
	d'un coup d'œil que les premières cartes sont faibles et les dernières excellentes. À lancer en Edit,
	après shops_ref_build.luau. Annulable (Ctrl+Z). Aucun script.
	1. ReplicatedStorage/Assets/UI/ShopCardBg/<Rareté> : le fond ET le décor de chaque palier, pour le code.
	   Attributs : Rarity, RarityColor, Motion (Sheen, Rainbow, Sweep), Period ou Speed, BorderColor,
	   BorderThickness, IconScale (part de IconArea), IconGrey (0 à 1 : la teinte de l'objet tirée vers le gris),
	   StudsTransparency, RaysSpin (degrés par seconde), GlowPulse (amplitude de transparence).
	   Enfants : Colors (UIGradient du fond), Sheen ou Sweep (reflet animé), TextGradient et BorderGradient
	   (Secret, désactivés : à copier sur RarityLabel et sur le UIStroke de Card), IconDecor (Folder : Rays,
	   Glow, Star1…Star5, à poser dans IconArea autour de Icon).
	2. Template des deux boutiques : IconArea.IconShadow (ImageLabel noir, image vide : le code y met la même
	   image que Icon, avec la même Rotation), Icon au-dessus (ZIndex 7). Attribut TrailIconRotation = 90 sur
	   UI_AuraShop List.Template : les trails sont couchés.
	3. Cartes d'exemple Preview_* : habillées selon leur palier (statique : le code anime rayons, lueur,
	   étincelles et reflets).
]]

local CH = game:GetService("ChangeHistoryService")
local RS = game:GetService("ReplicatedStorage")
local SG = game:GetService("StarterGui")
local hex = Color3.fromHex
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local GLOW = "rbxassetid://130850617844067"
local RAYS = "rbxassetid://96610322911997" -- UI_Rays_Soft (groupe) : s'efface en cercle, pas de coupure en tournant
local STAR = "rbxassetid://98471192881940"
local RAINBOW = { hex("FF3B3B"), hex("FFC21A"), hex("3BE15A"), hex("2F9BFF"), hex("A855F7") }
local GREY = hex("8a8f99")

local TIERS = {
	{ Id = "Common", Top = hex("d3d6dc"), Bottom = hex("a9aeb8"), Text = hex("8d939e"), Edge = hex("1e1e1e"), EdgeT = 2.5, Studs = 0.94, Icon = 0.62, Grey = 0.55 },
	{ Id = "Uncommon", Top = hex("a8ffd0"), Bottom = hex("2fd884"), Text = hex("2fe08f"), Edge = hex("1e1e1e"), EdgeT = 2.5, Studs = 0.88, Icon = 0.7 },
	{ Id = "Rare", Top = hex("86e0ff"), Bottom = hex("2f9bff"), Text = hex("2f9bff"), Edge = hex("1e1e1e"), EdgeT = 2.5, Studs = 0.88, Icon = 0.78, Glow = 0.55 },
	{ Id = "Epic", Top = hex("e0a6ff"), Bottom = hex("a855f7"), Text = hex("c77dff"), Edge = hex("2c1245"), EdgeT = 3, Studs = 0.88, Icon = 0.86, Glow = 0.4, Rays = 0.4, Spin = 10 },
	{ Id = "Legendary", Top = hex("ffe98a"), Bottom = hex("ffb31a"), Text = hex("ffc21a"), Edge = hex("ffd84a"), EdgeT = 3.5, Studs = 0.88, Icon = 0.92, Glow = 0.3, Rays = 0.28, Spin = 14, Stars = 2 },
	{ Id = "Mythic", Top = hex("ff95a5"), Bottom = hex("ff3b5c"), Text = hex("ff3b5c"), Edge = hex("ffd84a"), EdgeT = 4, Studs = 0.88, Icon = 1, Glow = 0.2, Rays = 0.18, Spin = 18, Stars = 4, Motion = "Sheen", Period = 2.1 },
	{ Id = "Secret", Text = WHITE, Edge = WHITE, EdgeT = 4.5, Studs = 0.9, Icon = 1, Glow = 0.12, Rays = 0.1, Spin = 24, Stars = 5, Motion = "Rainbow", Speed = 0.36 },
	{ Id = "Divine", Top = hex("fff7d9"), Bottom = hex("e9c462"), Text = hex("ffe9a8"), Edge = hex("fff2c2"), EdgeT = 4.5, Studs = 0.9, Icon = 1, Glow = 0.1, Rays = 0.08, Spin = 24, Stars = 5, Motion = "Sweep", Period = 3 },
}
local STAR_SPOTS = { { 0.16, 0.18 }, { 0.84, 0.78 }, { 0.82, 0.16 }, { 0.18, 0.82 }, { 0.5, 0.04 } }

local function make(class, parent, props)
	local o = Instance.new(class)
	for k, v in props or {} do o[k] = v end
	o.Parent = parent
	return o
end
local function rainbowSeq(lighten)
	local kp = {}
	for i, col in RAINBOW do table.insert(kp, ColorSequenceKeypoint.new((i - 1) / (#RAINBOW - 1), lighten and col:Lerp(WHITE, lighten) or col)) end
	return ColorSequence.new(kp)
end

-- Fond + décor d'un palier, prêt à cloner.
local function tierFrame(parent, name, t)
	local f = make("Frame", parent, { Name = name, Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 4 })
	for k, v in {
		Rarity = t.Id, RarityColor = t.Text, BorderColor = t.Edge, BorderThickness = t.EdgeT, IconScale = t.Icon,
		IconGrey = t.Grey or 0, StudsTransparency = t.Studs, RaysSpin = t.Spin or 0, GlowPulse = t.Glow and 0.12 or 0,
	} do f:SetAttribute(k, v) end
	if t.Motion then f:SetAttribute("Motion", t.Motion) end
	if t.Period then f:SetAttribute("Period", t.Period) end
	if t.Speed then f:SetAttribute("Speed", t.Speed) end
	if t.Motion == "Rainbow" then
		f.Size = UDim2.fromScale(2, 1)
		local kp, n = {}, #RAINBOW
		for i = 0, 2 * n do table.insert(kp, ColorSequenceKeypoint.new(i / (2 * n), RAINBOW[i % n + 1]:Lerp(WHITE, 0.35))) end
		make("UIGradient", f, { Name = "Colors", Color = ColorSequence.new(kp) })
		make("UIGradient", f, { Name = "TextGradient", Color = rainbowSeq(), Enabled = false })
		make("UIGradient", f, { Name = "BorderGradient", Color = rainbowSeq(), Enabled = false })
	else
		make("UIGradient", f, { Name = "Colors", Color = ColorSequence.new(t.Top, t.Bottom), Rotation = 90 })
		if t.Motion == "Sheen" or t.Motion == "Sweep" then
			local s = make("Frame", f, { Name = t.Motion, Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 4 })
			local mid = t.Motion == "Sheen" and 0.45 or 0.35
			make("UIGradient", s, { Rotation = t.Motion == "Sheen" and 90 or 18, Offset = t.Motion == "Sheen" and Vector2.new(0, -0.9) or Vector2.new(-1.1, 0), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.36, 1), NumberSequenceKeypoint.new(0.5, mid), NumberSequenceKeypoint.new(0.64, 1), NumberSequenceKeypoint.new(1, 1) }) })
		end
	end
	return f
end

-- Décor autour du visuel (dans `parent` : IconDecor du modèle, ou IconArea d'une carte).
local function decor(parent, t)
	local glowColor = t.Text:Lerp(WHITE, 0.4)
	if t.Rays then
		local r = make("ImageLabel", parent, { Name = "Rays", Image = RAYS, ImageColor3 = (t.Text):Lerp(WHITE, 0.75), ImageTransparency = t.Rays, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.9, 1.9), ZIndex = 5 })
		make("UIAspectRatioConstraint", r, { AspectRatio = 1 })
	end
	if t.Glow then
		local g = make("ImageLabel", parent, { Name = "Glow", Image = GLOW, ImageColor3 = glowColor, ImageTransparency = t.Glow, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.15, 1.15), ZIndex = 5 })
		make("UIAspectRatioConstraint", g, { AspectRatio = 1 })
	end
	for i = 1, t.Stars or 0 do
		local p = STAR_SPOTS[i]
		local st = make("ImageLabel", parent, { Name = "Star" .. i, Image = STAR, ImageColor3 = t.Id == "Secret" and WHITE or hex("fff6c2"), ImageTransparency = 0.2, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(p[1], p[2]), Size = UDim2.fromScale(0.18, 0.18), ZIndex = 8 })
		make("UIAspectRatioConstraint", st, { AspectRatio = 1 })
	end
end

-- Ombre sous le visuel, dans le modèle de carte (image vide : le code la remplit).
local function addShadow(area)
	local icon = area:FindFirstChild("Icon")
	if not icon then return end
	local old = area:FindFirstChild("IconShadow")
	if old then old:Destroy() end
	icon.ZIndex = 7
	return make("ImageLabel", area, { Name = "IconShadow", Image = "", ImageColor3 = BLACK, ImageTransparency = 0.25, BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.515, 0.53), Size = UDim2.fromScale(icon.Size.X.Scale * 1.06, icon.Size.Y.Scale * 1.06), Rotation = icon.Rotation, ZIndex = 6 })
end

-- Habille une carte d'exemple selon son palier.
local function styleCard(card, t, tint)
	local fill = card:FindFirstChild("Fill")
	if fill then fill:Destroy() end
	local f = tierFrame(card, "Fill", t)
	local tg, bg = f:FindFirstChild("TextGradient"), f:FindFirstChild("BorderGradient")
	local studs = card:FindFirstChild("Studs")
	if studs then studs.ImageTransparency = t.Studs end
	local edge = card:FindFirstChildOfClass("UIStroke")
	if edge then
		edge.Color, edge.Thickness = t.Edge, t.EdgeT
		for _, g in edge:GetChildren() do g:Destroy() end
		if bg then local c = bg:Clone() c.Enabled = true c.Parent = edge end
	end
	local rl = card:FindFirstChild("RarityLabel", true)
	if rl then
		rl.Text, rl.TextColor3 = t.Id, t.Text
		for _, g in rl:GetChildren() do if g:IsA("UIGradient") then g:Destroy() end end
		if tg then local c = tg:Clone() c.Enabled = true c.Parent = rl end
	end
	if tg then tg:Destroy() end
	if bg then bg:Destroy() end
	local area = card:FindFirstChild("IconArea", true)
	local icon = area and area:FindFirstChild("Icon")
	if not icon then return end
	for _, k in area:GetChildren() do if k:IsA("GuiObject") and k ~= icon then k:Destroy() end end
	icon.Size = UDim2.fromScale(0.92 * t.Icon, t.Icon)
	if tint then icon.ImageColor3 = t.Grey and tint:Lerp(GREY, t.Grey) or tint end
	local sh = addShadow(area)
	if sh then sh.Image = icon.Image end
	decor(area, t)
end

local rec = CH:TryBeginRecording("Boutiques : paliers (fond, décor, visuel teinté)")

-- 1. Modèles de palier pour le code
local ui = RS.Assets:FindFirstChild("UI")
local bgs = ui:FindFirstChild("ShopCardBg")
if bgs then bgs:Destroy() end
bgs = make("Folder", ui, { Name = "ShopCardBg" })
for _, t in TIERS do
	local f = tierFrame(bgs, t.Id, t)
	decor(make("Folder", f, { Name = "IconDecor" }), t)
end

-- 2 et 3. Les deux boutiques
local AURA_TINT = { hex("FFD93B"), hex("FF6A1A"), hex("2FC4FF"), hex("FF3BD4"), hex("8B5CFF"), hex("FFC21A") } -- Config/Cosmetics (Clément)
local report = {}
for _, gname in { "UI_AuraShop", "UI_WeaponShop" } do
	local list = SG[gname].Root.List
	local template = list:FindFirstChild("Template")
	local tArea = template and template:FindFirstChild("IconArea", true)
	if tArea then
		local tIcon = tArea:FindFirstChild("Icon")
		if tIcon then tIcon.Size = UDim2.fromScale(0.92 * TIERS[1].Icon, TIERS[1].Icon) end
		addShadow(tArea) -- image vide : rien ne s'affiche tant que le code ne la remplit pas
	end
	-- fond Common (le palier par défaut tant que le code ne pose pas la rareté) ; RarityLabel reste vide
	local tCard = template and template:FindFirstChild("Card")
	if tCard then
		local old = tCard:FindFirstChild("Fill")
		if old then old:Destroy() end
		tierFrame(tCard, "Fill", TIERS[1])
		local studs = tCard:FindFirstChild("Studs")
		if studs then studs.ImageTransparency = TIERS[1].Studs end
		local edge = tCard:FindFirstChildOfClass("UIStroke")
		if edge then edge.Color, edge.Thickness = TIERS[1].Edge, TIERS[1].EdgeT end
		local rl = tCard:FindFirstChild("RarityLabel", true)
		if rl then rl.TextColor3 = TIERS[1].Text end
	end
	if gname == "UI_AuraShop" and template then template:SetAttribute("TrailIconRotation", 90) end
	local n = 0
	for _, cell in list:GetChildren() do
		local i = tonumber(cell.Name:match("^Preview_(%d+)$"))
		if i and TIERS[i] then
			styleCard(cell.Card, TIERS[i], gname == "UI_AuraShop" and AURA_TINT[i] or nil)
			n += 1
		end
	end
	table.insert(report, gname .. " : " .. n .. " cartes d'exemple")
end

if rec then CH:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
return table.concat(report, " ; ") .. " ; ShopCardBg : " .. #TIERS .. " paliers"
