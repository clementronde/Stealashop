---------------------------------------------------------------- scénarios a186 (L-176 : fonds des cartes par palier)
-- Après setup.luau du banc a50 (serveur, Net, WeaponShopController démarré) ; AuraShopController monté ici.
local playerGui = P1.PlayerGui
local hex = Color3.fromHex
local WHITE = Color3.new(1, 1, 1)
local GREY = hex("8a8f99")
local function near3(a, b)
	return a ~= nil and b ~= nil and math.abs(a.R - b.R) < 1e-4 and math.abs(a.G - b.G) < 1e-4 and math.abs(a.B - b.B) < 1e-4
end
local function el(root, name)
	return root:FindFirstChild(name, true)
end

-- Modèles ShopCardBg comme ceux de tools/clement/shop_tiers_apply.luau (mêmes valeurs, images factices).
local TIERS = {
	{ Id = "Common", Text = hex("8d939e"), Edge = hex("1e1e1e"), EdgeT = 2.5, Studs = 0.94, Icon = 0.62, Grey = 0.55 },
	{ Id = "Uncommon", Text = hex("2fe08f"), Edge = hex("1e1e1e"), EdgeT = 2.5, Studs = 0.88, Icon = 0.7 },
	{ Id = "Rare", Text = hex("2f9bff"), Edge = hex("1e1e1e"), EdgeT = 2.5, Studs = 0.88, Icon = 0.78, Glow = 0.55 },
	{ Id = "Epic", Text = hex("c77dff"), Edge = hex("2c1245"), EdgeT = 3, Studs = 0.88, Icon = 0.86, Glow = 0.4, Rays = 0.4, Spin = 10 },
	{ Id = "Legendary", Text = hex("ffc21a"), Edge = hex("ffd84a"), EdgeT = 3.5, Studs = 0.88, Icon = 0.92, Glow = 0.3, Rays = 0.28, Spin = 14, Stars = 2 },
	{ Id = "Mythic", Text = hex("ff3b5c"), Edge = hex("ffd84a"), EdgeT = 4, Studs = 0.88, Icon = 1, Glow = 0.2, Rays = 0.18, Spin = 18, Stars = 4, Motion = "Sheen", Period = 2.1 },
	{ Id = "Secret", Text = WHITE, Edge = WHITE, EdgeT = 4.5, Studs = 0.9, Icon = 1, Glow = 0.12, Rays = 0.1, Spin = 24, Stars = 5, Motion = "Rainbow", Speed = 0.36 },
	{ Id = "Divine", Text = hex("ffe9a8"), Edge = hex("fff2c2"), EdgeT = 4.5, Studs = 0.9, Icon = 1, Glow = 0.1, Rays = 0.08, Spin = 24, Stars = 5, Motion = "Sweep", Period = 3 },
}
local assets = folder(ReplicatedStorage, "Assets")
local bgs = folder(folder(assets, "UI"), "ShopCardBg")
for _, t in TIERS do
	local f = new("Frame", { Name = t.Id, Size = UDim2.fromScale(if t.Motion == "Rainbow" then 2 else 1, 1) })
	for k, v in { Rarity = t.Id, RarityColor = t.Text, BorderColor = t.Edge, BorderThickness = t.EdgeT, IconScale = t.Icon, IconGrey = t.Grey or 0, StudsTransparency = t.Studs, RaysSpin = t.Spin or 0, GlowPulse = if t.Glow then 0.12 else 0 } do
		f:SetAttribute(k, v)
	end
	if t.Motion then f:SetAttribute("Motion", t.Motion) end
	if t.Period then f:SetAttribute("Period", t.Period) end
	if t.Speed then f:SetAttribute("Speed", t.Speed) end
	new("UIGradient", { Name = "Colors" }, f)
	if t.Motion == "Rainbow" then
		new("UIGradient", { Name = "TextGradient", Enabled = false }, f)
		new("UIGradient", { Name = "BorderGradient", Enabled = false }, f)
	elseif t.Motion then
		local s = new("Frame", { Name = t.Motion, Size = UDim2.fromScale(1, 1) }, f)
		new("UIGradient", { Offset = if t.Motion == "Sheen" then Vector2.new(0, -0.9) else Vector2.new(-1.1, 0) }, s)
	end
	local decor = folder(f, "IconDecor")
	if t.Rays then new("ImageLabel", { Name = "Rays", Image = "rbxassetid://rays", ImageTransparency = t.Rays, Size = UDim2.fromScale(1.9, 1.9) }, decor) end
	if t.Glow then new("ImageLabel", { Name = "Glow", Image = "rbxassetid://glow", ImageTransparency = t.Glow, Size = UDim2.fromScale(1.15, 1.15) }, decor) end
	for i = 1, t.Stars or 0 do new("ImageLabel", { Name = "Star" .. i, Image = "rbxassetid://star", ImageTransparency = 0.2, Size = UDim2.fromScale(0.18, 0.18) }, decor) end
	f.Parent = bgs
end
-- Textures d'effet (blanches) des auras et des trails, sauf Turbo : sa carte garde l'image du Template, comme une
-- icône ICON_ déjà en couleurs (pas de teinte).
local fx = folder(assets, "FX")
for i, name in { "FX_Aura_Etincelle", "FX_Aura_Flamme", "FX_Aura_Foudre", "FX_Aura_Plasma", "FX_Aura_Galaxie", "FX_Aura_Royale", "FX_Trail_Poussiere", "FX_Trail_Vent", "FX_Trail_Comete", "FX_Trail_Hyperespace" } do
	new("Decal", { Name = name, Texture = "rbxassetid://fx" .. i }, fx)
end

-- Carte grise comme celle de shops_ref_build.luau + shop_tiers_apply.luau (fond Common, ombre vide, Icon au-dessus).
local function makeTemplate(list, bandName)
	local template = new("Frame", { Name = "Template", Visible = false }, list)
	local card = new("Frame", { Name = "Card", ClipsDescendants = true }, template)
	new("UIStroke", { Color = hex("1e1e1e"), Thickness = 2.5 }, card)
	local fill = new("Frame", { Name = "Fill", Size = UDim2.fromScale(1, 1) }, card)
	new("UIGradient", { Name = "Colors" }, fill)
	new("ImageLabel", { Name = "Studs", Image = "rbxassetid://studs", ImageTransparency = 0.94 }, card)
	local content = new("Frame", { Name = "Content" }, card)
	new("TextLabel", { Name = "ItemName", Text = "Spark" }, content)
	new("TextLabel", { Name = "RarityLabel", Text = "", TextColor3 = hex("8d939e") }, content)
	local area = new("Frame", { Name = "IconArea" }, content)
	new("ImageLabel", { Name = "Icon", Image = "rbxassetid://template", Size = UDim2.fromScale(0.92 * 0.62, 0.62), ZIndex = 7 }, area)
	new("ImageLabel", { Name = "IconShadow", Image = "", ImageColor3 = Color3.new(0, 0, 0), Size = UDim2.fromScale(0.92 * 0.62 * 1.06, 0.62 * 1.06), ZIndex = 6 }, area)
	local band = new("Frame", { Name = "BonusBand" }, content)
	new("TextLabel", { Name = bandName, Text = "x2" }, band)
	local row = new("Frame", { Name = "ButtonRow" }, content)
	local buy = new("TextButton", { Name = "BuyButton", Text = "" }, row)
	new("TextLabel", { Name = "Price", Text = "$500" }, buy)
	new("TextButton", { Name = "EquipButton", Text = "Equip" }, row)
	-- Carte d'exemple de Clément, retirée en jeu.
	local preview = template:Clone()
	preview.Name = "Preview_1"
	preview.Visible = true
	preview.Parent = list
	return template
end

local function screenOf(name, bandName, withTabs)
	local screen = new("ScreenGui", { Name = name, Enabled = true })
	screen:SetAttribute("ScreenGroup", "Menu")
	local root = new("Frame", { Name = "Root" }, screen)
	new("TextButton", { Name = "CloseButton", Text = "X" }, root)
	if withTabs then
		local tabs = new("Frame", { Name = "Tabs" }, root)
		new("TextButton", { Name = "AurasTab", Text = "Auras" }, tabs)
		new("TextButton", { Name = "TrailsTab", Text = "Trails" }, tabs)
	end
	local list = new("ScrollingFrame", { Name = "List" }, root)
	local template = makeTemplate(list, bandName)
	return screen, list, template
end

local function rowOf(list, suffix)
	for _, child in list:GetChildren() do
		if string.sub(child.Name, -#suffix) == suffix and child.Name ~= "Template" then
			return child
		end
	end
	return nil
end
local function promptIn(model, name)
	for _, d in model:GetDescendants() do
		if d.ClassName == "ProximityPrompt" and d.Name == name then
			return d
		end
	end
	return nil
end

-- Une carte au palier `t` : fond, bordure, studs, texte, visuel, ombre, décor.
local function checkTier(row, t, label)
	if row == nil then
		check(false, label .. " : carte absente")
		return
	end
	local card = row.Card
	local fill = card:FindFirstChild("Fill")
	local fills = 0
	for _, c in card:GetChildren() do
		if c.Name == "Fill" then fills += 1 end
	end
	local stroke = card:FindFirstChildWhichIsA("UIStroke")
	local rl = el(row, "RarityLabel")
	local area = el(row, "IconArea")
	local icon, shadow = area.Icon, area.IconShadow
	local stars = 0
	for _, c in area:GetChildren() do
		if string.match(c.Name, "^Star%d$") then stars += 1 end
	end
	local ok = fills == 1 and fill:GetAttribute("Rarity") == t.Id and fill:FindFirstChild("IconDecor") == nil and fill:FindFirstChild("TextGradient") == nil
		and near3(stroke.Color, t.Edge) and stroke.Thickness == t.EdgeT
		and card.Studs.ImageTransparency == t.Studs
		and rl.Text == t.Id and near3(rl.TextColor3, t.Text)
		and math.abs(icon.Size.Y.Scale - t.Icon) < 1e-6 and math.abs(icon.Size.X.Scale - 0.92 * t.Icon) < 1e-6
		and math.abs(shadow.Size.Y.Scale - 1.06 * t.Icon) < 1e-6 and shadow.Image == icon.Image and shadow.Rotation == icon.Rotation
		and (area:FindFirstChild("Rays") ~= nil) == (t.Rays ~= nil) and (area:FindFirstChild("Glow") ~= nil) == (t.Glow ~= nil) and stars == (t.Stars or 0)
	local secret = t.Id == "Secret"
	local rlGrad = rl:FindFirstChildWhichIsA("UIGradient")
	local edgeGrad = stroke:FindFirstChildWhichIsA("UIGradient")
	ok = ok and ((rlGrad ~= nil and rlGrad.Enabled) == secret) and ((edgeGrad ~= nil and edgeGrad.Enabled) == secret)
		and (fill.Size.X.Scale == (if secret then 2 else 1))
		and ((fill:FindFirstChild("Sheen") ~= nil) == (t.Motion == "Sheen"))
	check(ok, label .. " : palier " .. t.Id .. " (fond, bordure " .. t.EdgeT .. ", studs, texte, visuel " .. t.Icon .. ", ombre, décor)")
end

print("\n== W. Boutique d'armes : un palier par rang")
local wscreen, wlist, wtemplate = screenOf("UI_WeaponShop", "Power", false)
wscreen.Parent = playerGui
step(0.05)
local Tools = requireModule(ReplicatedStorage.Shared.Config.Tools, "client")
for _, tool in Tools.List do
	checkTier(rowOf(wlist, "_" .. tool.Id), TIERS[tool.Order], "W" .. tool.Order .. " " .. tool.Id)
end
check(wlist:FindFirstChild("Preview_1") == nil, "W8 carte d'exemple Preview_1 retirée")
local fists = rowOf(wlist, "_Fists")
check(near3(el(fists, "Icon").ImageColor3, WHITE), "W9 arme : visuel jamais teinté (comme les Preview de Clément), IconGrey sans effet")
check(wtemplate.Card.Fill:GetAttribute("Rarity") == nil and el(wtemplate, "RarityLabel").Text == "", "W10 Template intact")
local Tier = requireModule(ReplicatedStorage.Shared.ShopCardTier, "client")
check(wscreen.Enabled == false and not Tier.IsRunning(), "W11 écran fermé : animations débranchées")

print("\n== A. Animations : écran ouvert, écran fermé")
local wprompt = promptIn(WEAPON_SHOP, "WeaponShopPrompt")
at(ROOT1, SHOP_SPOT)
wprompt.Triggered:Fire(P1)
step(0.5)
local grinder = rowOf(wlist, "_AngleGrinder")
local axe = rowOf(wlist, "_FireAxe")
local rays = el(axe, "IconArea").Rays
local r1 = rays.Rotation
local sheen = axe.Card.Fill.Sheen:FindFirstChildWhichIsA("UIGradient")
local o1 = sheen.Offset.Y
local rainbow = grinder.Card.Fill
local p1 = rainbow.Position.X.Scale
local edgeGrad = grinder.Card:FindFirstChildWhichIsA("UIStroke"):FindFirstChildWhichIsA("UIGradient")
local g1 = edgeGrad.Rotation
local glow = el(axe, "IconArea").Glow
step(0.5)
check(wscreen.Enabled and Tier.IsRunning(), "A1 écran ouvert : animations branchées")
check(math.abs(((rays.Rotation - r1) % 360) - 18 * 0.5) < 0.2, "A2 rayons Mythic : RaysSpin 18°/s (" .. (rays.Rotation - r1) .. "° en 0,5 s)")
check(sheen.Offset.Y ~= o1 and sheen.Offset.Y >= -0.9 and sheen.Offset.Y <= 0.9, "A3 reflet Sheen qui glisse de haut en bas")
check(rainbow.Position.X.Scale ~= p1 and rainbow.Position.X.Scale <= 0 and rainbow.Position.X.Scale > -1, "A4 arc-en-ciel Secret qui défile")
check(math.abs(((edgeGrad.Rotation - g1) % 360) - 45) < 0.5, "A5 dégradé de la bordure Secret qui tourne (90°/s)")
check(math.abs(glow.ImageTransparency - 0.2) <= 0.12 + 1e-6, "A6 lueur qui bat autour de sa transparence (±GlowPulse)")
local star = el(axe, "IconArea").Star1
check(star.Size.X.Scale > 0 and star.Size.X.Scale <= 0.18 * 1.1 + 1e-6, "A7 étoiles qui scintillent sans dépasser leur taille")
wscreen.Root.CloseButton.Activated:Fire()
step(1)
local frozen = rays.Rotation
step(1)
check(wscreen.Enabled == false and not Tier.IsRunning() and rays.Rotation == frozen, "A8 écran fermé : animations arrêtées, plus de Heartbeat")
local enabledSignal = rawget(wscreen, "_propSignals").Enabled
local handlers = #enabledSignal.handlers
for _ = 1, 3 do
	wprompt.Triggered:Fire(P1)
	step(0.5)
	wscreen.Root.CloseButton.Activated:Fire()
	step(1)
end
check(#enabledSignal.handlers == handlers and not Tier.IsRunning(), "A9 trois ouvertures de plus : aucune connexion de plus")

print("\n== U. Boutique d'auras : teinte, IconGrey, trails couchés")
local auraModule = moduleScript(StarterPlayerScripts.Client.Controllers, "AuraShopController", "client/Controllers/AuraShopController.luau")
local AuraShopController = requireModule(auraModule, "client")
local ascreen, alist, atemplate = screenOf("UI_AuraShop", "Bonus", true)
atemplate:SetAttribute("TrailIconRotation", 90)
ascreen.Parent = playerGui
taskLib.spawn(AuraShopController.Start)
step(0.1)
local aprompt = promptIn(AURA_SHOP, "AuraShopPrompt")
at(ROOT1, AURA_SPOT)
aprompt.Triggered:Fire(P1)
step(0.5)
local Cosmetics = requireModule(ReplicatedStorage.Shared.Config.Cosmetics, "client")
for _, def in Cosmetics.Auras do
	checkTier(rowOf(alist, "_" .. def.Id), TIERS[def.Order], "U" .. def.Order .. " " .. def.Id)
end
local spark = rowOf(alist, "_Spark")
local royal = rowOf(alist, "_Royal")
check(near3(el(spark, "Icon").ImageColor3, Cosmetics.Auras[1].Color:Lerp(GREY, 0.55)), "U7 Spark (Common) : couleur de l'aura tirée vers le gris de IconGrey 0,55")
check(near3(el(royal, "Icon").ImageColor3, Cosmetics.Auras[6].Color), "U8 Royal (Mythic) : couleur de l'aura, IconGrey 0")
check(el(spark, "Icon").Rotation == 0 and el(spark, "IconShadow").Rotation == 0, "U9 aura : visuel droit")
check(el(spark, "IconShadow").Image == "rbxassetid://fx1", "U10 ombre : même image que le visuel")
check(alist:FindFirstChild("Preview_1") == nil and ascreen.Enabled and Tier.IsRunning(), "U11 Preview retirée, écran ouvert, animations branchées")
ascreen.Root.Tabs.TrailsTab.Activated:Fire()
step(0.5)
local dust = rowOf(alist, "_Dust")
local turbo = rowOf(alist, "_Turbo")
check(dust ~= nil and spark.Parent == nil, "U12 onglet Trails : cartes refaites")
for _, def in Cosmetics.Trails do
	checkTier(rowOf(alist, "_" .. def.Id), TIERS[def.Order], "U" .. (12 + def.Order) .. " " .. def.Id)
end
check(el(dust, "Icon").Rotation == 90 and el(dust, "IconShadow").Rotation == 90, "U18 trail couché : TrailIconRotation 90 sur le visuel et son ombre")
check(near3(el(turbo, "Icon").ImageColor3, WHITE) and el(turbo, "Icon").Image == "rbxassetid://template", "U19 visuel qui n'est pas la texture FX_ (icône en couleurs) : pas teint")
ascreen.Root.CloseButton.Activated:Fire()
step(1)
check(ascreen.Enabled == false and not Tier.IsRunning() and rowOf(alist, "_Dust") ~= nil, "U20 écran fermé : cartes gardées (a217), animations arrêtées")
ascreen:Destroy()
step(0.1)
check(not Tier.IsRunning() and FAILS == 0, "U21 écran retiré : rien ne tourne, aucune erreur")
check(logCount("[AuraShop]", "WARN", "client") == 0 and logCount("[WeaponShop]", "WARN", "client") == 0, "U22 aucun avertissement des boutiques")

summary()
