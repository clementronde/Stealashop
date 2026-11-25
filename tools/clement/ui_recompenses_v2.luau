--!nonstrict
-- ui_recompenses_v2.luau (Clément, 2026-11-24 : « on doit refaire l'UI de la roue, et des récompenses quotidienne et
-- de temps », puis « la récompense jour 7 doit être un carré sur toute la hauteur, la récompense jour 2 doit être une
-- boîte épique avec minimum de montant, récompense d'horaire dans le même style que récompense quotidienne : 7 cases et
-- dernière case énorme ») : à lancer en Edit. UI_Rewards garde sa fenêtre, ses onglets et tous les noms lus par
-- RewardsController ; seul le contenu des deux pages change.
--   - Daily : Streak.Day1 à Day6 en grille de 3 × 2 à gauche, Day7 en carré sur toute la hauteur à droite. Cartes à
--     plat (« retire l'effet 3D des cases ») : dégradé (bleu, Day7 doré), contour noir, tenons ; DayShadow (l'ombre
--     décalée) caché ; « DAY n » en haut, grande icône, nom du lot en bas. Icônes du jeu (les anciennes
--     des colis, 93766507411897, ne montraient rien) : liasses, colis Épique (jour 2, « Epic box »), Premium, Luxe,
--     ×2 cash. Today : contour blanc épais, étiquette TODAY au-dessus de la carte. DailyClaimButton ancré par le bas.
--   - Playtime : la même grille, 7 cases dont la dernière en grand carré doré. Les cases sont Preview_1 à _7 (posées à
--     leur place, sans UIGridLayout) ; dans chaque carte : le temps (RewardName), l'icône, le gain (RewardDesc, écrit
--     par le code), le minuteur (Timer) en pastille au bas de la carte ; ClaimButton à sa place quand le cadeau est
--     prêt ; Claimed devient un voile sombre sur toute la carte avec la coche, comme les jours. Une phrase en bas
--     (PlaytimeHint, texte de l'écran). ATTENTION : il faut que le code d'Ironix place chaque palier sur la case
--     Preview_<rang> (et qu'il y ait 7 paliers) ; avant ça, PLAYTIME_SLOTS = false garde la page Playtime telle quelle.
-- Aucun nom existant changé, aucun script. RewardDesc est un nom déjà prévu par le code (a303, facultatif).
-- PREVIEW = true : rien ne change ; deux copies de l'écran (page Daily, page Playtime) sont posées dans StarterGui
-- (_PREVIEW_CLAUDE_RewardsD et _PREVIEW_CLAUDE_RewardsP, non archivables, à détruire). PREVIEW = false : l'écran
-- change (sauvegarde ServerStorage/MapBackups/2026-11-24_Recompenses).

local PREVIEW = false
local PLAYTIME_SLOTS = false -- true quand le code des 7 paliers est prêt ; false : la page Playtime n'est pas touchée (en attendant le code des 7 paliers)

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")

local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)
local GOLD_TEXT = Color3.fromHex("#FFD23F")

local IMG = {
	cash1 = "rbxassetid://137831162447641", -- UI_Icon_DP_Cash_1
	cash3 = "rbxassetid://101929982691500", -- UI_Icon_DP_Cash_3
	cash5 = "rbxassetid://103564967498534", -- UI_Icon_DP_Cash_5
	boost = "rbxassetid://90748953656553", -- UI_Icon_GP_x2Cash
	boxStandard = "rbxassetid://123386984775846", -- ICON_BOX_Standard
	boxPremium = "rbxassetid://132916962886674", -- ICON_BOX_Premium
	boxEpic = "rbxassetid://115708294705724", -- ICON_BOX_Epic
	boxRare = "rbxassetid://97801885378809", -- ICON_BOX_Rare
	boxLuxe = "rbxassetid://130066925017879", -- ICON_BOX_Luxe
}
-- icône de chaque jour : 5 min, colis Épique (Clément, 24/11), 15 min, Premium, ×2, 30 min, Luxe
local DAY_ICONS = { IMG.cash1, IMG.boxEpic, IMG.cash3, IMG.boxPremium, IMG.boost, IMG.cash5, IMG.boxLuxe }
local DAY_NAMES = { [2] = "Epic box" } -- les autres noms restent ceux de Clément
-- 7 paliers d'exemple (temps et lots proposés, à valider ; le code écrira les vrais)
local TIERS = {
	{ title = "5 MIN", icon = IMG.cash1, desc = "$1.2K cash", timer = "CLAIMED", state = "claimed" },
	{ title = "10 MIN", icon = IMG.cash3, desc = "$3K cash", timer = "Ready!", state = "ready" },
	{ title = "15 MIN", icon = IMG.boxStandard, desc = "Zone box", timer = "2:34", state = "wait" },
	{ title = "20 MIN", icon = IMG.boost, desc = "×2 cash 10 min", timer = "7:34", state = "wait" },
	{ title = "30 MIN", icon = IMG.cash5, desc = "$15K cash", timer = "17:34", state = "wait" },
	{ title = "45 MIN", icon = IMG.boxRare, desc = "Rare box", timer = "32:34", state = "wait" },
	{ title = "1 HOUR", icon = IMG.boxEpic, desc = "Epic box", timer = "47:34", state = "wait" },
}
local BLUE = { hi = "#7AD8FF", base = "#2A80E8" }
local GOLD = { hi = "#FFEB85", base = "#FFA91A" }

-- la page (DailyPage, PlaytimePage) garde toujours ce rapport largeur / hauteur (Root a un rapport fixe)
local PAGE_RATIO = 1.922
local GRID_POS, GRID_SIZE = UDim2.fromScale(0.03, 0.03), UDim2.fromScale(0.94, 0.73)
local GAP, LIP = 0.04, 1 -- écart entre cartes (part de la hauteur de la grille) ; cartes à plat (Clément : « retire l'effet 3D des cases »)

local function child(parent, class, name)
	local c = parent:FindFirstChild(name)
	if c and not c:IsA(class) then
		c:Destroy()
		c = nil
	end
	if not c then
		c = Instance.new(class)
		c.Name = name
		c.Parent = parent
	end
	return c
end

local function corner(o, r)
	child(o, "UICorner", "UICorner").CornerRadius = UDim.new(r, 0)
end

local function stroke(o, th, color, mode)
	local s = child(o, "UIStroke", "UIStroke")
	s.Thickness = th
	s.Color = color or BLACK
	s.Transparency = 0
	s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	s.ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border
	s.LineJoinMode = Enum.LineJoinMode.Round
	return s
end

local function gradient(o, hi, base)
	local g = child(o, "UIGradient", "UIGradient")
	g.Color = ColorSequence.new(Color3.fromHex(hi), Color3.fromHex(base))
	g.Rotation = 90
	return g
end

local function box(o, anchor, pos, size, z)
	o.AnchorPoint = anchor
	o.Position = pos
	o.Size = size
	o.ZIndex = z
end

local function text(label, value, color, z)
	label.BackgroundTransparency = 1
	if value then
		label.Text = value
	end
	label.TextColor3 = color
	label.TextScaled = false
	label.TextWrapped = true
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = z
	stroke(label, 0.13, BLACK, Enum.ApplyStrokeMode.Contextual)
end

local function studs(card, window, z)
	local s = card:FindFirstChild("Studs")
	if not s then
		s = window.Studs:Clone()
		s.Name = "Studs"
		s.Parent = card
	end
	s.AnchorPoint = Vector2.new(0, 0)
	s.Position = UDim2.fromScale(0, 0)
	s.Size = UDim2.fromScale(1, 1)
	s.ImageTransparency = 0.82
	s.ZIndex = z
	corner(s, 0.06)
end

-- carte à plat (Clément : « retire l'effet 3D des cases ») : dégradé, contour noir, tenons ; pas de lèvre dessous.
-- lipName : l'ombre décalée d'origine de la carte (DayShadow des jours), cachée, ou la lèvre d'un essai précédent, retirée
local function card(c, lipName, colors, window)
	c.BackgroundColor3 = WHITE
	c.BackgroundTransparency = 0
	gradient(c, colors.hi, colors.base)
	stroke(c, 0.022, BLACK)
	corner(c, 0.06)
	local lip = c:FindFirstChild(lipName)
	if lip and lipName == "DayShadow" then
		lip.Visible = false
	elseif lip then
		lip:Destroy()
	end
	studs(c, window, 5)
end

-- grille : cases 1 à 6 en 3 × 2 à gauche, la 7e en carré sur toute la hauteur à droite ; ratio = largeur / hauteur
-- jackpot = true (page Playtime, Clément le 25/11 : « oui » aux deux gros lots de 20 min et de 1 h) : la rangée du bas
-- devient [case 4, gros lot de 20 min, large] [case 5] [case 6] ; la lecture reste dans l'ordre du temps
-- (5, 10, 15 en haut ; 20, 30, 45 en bas ; 1 h en grand carré à droite).
local JACKPOT_SHARE = 0.4667 -- part de la rangée du bas prise par la case 4 (les cases 5 et 6 se partagent le reste)
local function grid(ratio, jackpot)
	local h7 = 1 / LIP
	local x7 = ratio - h7
	local colW = (x7 - 3 * GAP) / 3
	local rowH = (1 - GAP) / (2 * LIP)
	local slots = {}
	for i = 1, 6 do
		local col, row = (i - 1) % 3, (i - 1) // 3
		slots[i] = { x = col * (colW + GAP) / ratio, y = row * (rowH * LIP + GAP), w = colW / ratio, h = rowH }
	end
	if jackpot then
		local y = rowH * LIP + GAP
		local s = 3 * colW
		local w4 = s * JACKPOT_SHARE
		local w56 = (s - w4) / 2
		slots[4] = { x = 0, y = y, w = w4 / ratio, h = rowH }
		slots[5] = { x = (w4 + GAP) / ratio, y = y, w = w56 / ratio, h = rowH }
		slots[6] = { x = (w4 + GAP + w56 + GAP) / ratio, y = y, w = w56 / ratio, h = rowH }
	end
	slots[7] = { x = x7 / ratio, y = 0, w = h7 / ratio, h = h7 }
	return slots
end

local function slot(o, s)
	o.AnchorPoint = Vector2.new(0, 0)
	o.Position = UDim2.fromScale(s.x, s.y)
	o.Size = UDim2.fromScale(s.w, s.h)
end

local function daily(page, window)
	local st = page.Streak
	st.Position = GRID_POS
	st.Size = GRID_SIZE
	local slots = grid(GRID_SIZE.X.Scale * PAGE_RATIO / GRID_SIZE.Y.Scale)
	for i = 1, 7 do
		local d = st["Day" .. i]
		local big = i == 7
		slot(d, slots[i])
		d.ZIndex = 5
		card(d, "DayShadow", if big then GOLD else BLUE, window)
		box(d.DayLabel, Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.045), UDim2.fromScale(0.9, if big then 0.11 else 0.15), 8)
		text(d.DayLabel, "DAY " .. i, WHITE, 8)
		d.Icon.Image = DAY_ICONS[i]
		d.Icon.ScaleType = Enum.ScaleType.Fit
		d.Icon.BackgroundTransparency = 1
		local glow = d:FindFirstChild("Glow")
		if big then
			box(d.Icon, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.78, 0.56), 7)
			box(d.RewardName, Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.79), UDim2.fromScale(0.9, 0.17), 8)
			if glow then
				box(glow, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 0.8), 6)
			end
		else
			box(d.Icon, Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.2), UDim2.fromScale(0.8, 0.44), 7)
			box(d.RewardName, Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.65), UDim2.fromScale(0.9, 0.3), 8)
			if glow then
				box(glow, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.45), UDim2.fromScale(1, 0.7), 6)
			end
		end
		if glow then
			glow.ImageColor3 = if big then Color3.fromHex("#FFF3B0") else Color3.fromHex("#BFEAFF")
			glow.ImageTransparency = 0.35
		end
		text(d.RewardName, DAY_NAMES[i], WHITE, 8)
		local today = d.Today
		today.ZIndex = 9
		today.BackgroundTransparency = 1
		corner(today, 0.06)
		stroke(today, 0.05, WHITE)
		local claimed = d.Claimed
		claimed.ZIndex = 10
		corner(claimed, 0.06)
		claimed.CheckIcon.ZIndex = 11
		local tag = today:FindFirstChild("TodayTag")
		if tag then
			tag.AnchorPoint = Vector2.new(0.5, 0.75) -- au-dessus de la carte (elle cachait « DAY n »)
			tag.Position = UDim2.fromScale(0.5, 0)
			tag.ZIndex = 12
			for _, c in tag:GetDescendants() do
				if c:IsA("GuiObject") then
					c.ZIndex = 13
				end
			end
		end
	end
	-- ancré par le bas : son minimum de 44 px (téléphone) le fait grandir vers le haut, pas hors de la fenêtre
	local claim = page.DailyClaimButton
	claim.AnchorPoint = Vector2.new(0.5, 1)
	claim.Position = UDim2.fromScale(0.5, 0.975)
end

-- contenu d'une carte de temps de jeu, comme une carte de jour ; big = la 7e case
local function playtimeCard(t, window, big)
	t.BackgroundTransparency = 0
	t.ZIndex = 5
	card(t, "Lip", if big then GOLD else BLUE, window)
	box(t.RewardName, Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.045), UDim2.fromScale(0.9, if big then 0.093 else 0.15), 8)
	text(t.RewardName, nil, WHITE, 8)
	box(t.Icon, Vector2.new(0.5, 0), UDim2.fromScale(0.5, if big then 0.16 else 0.2), UDim2.fromScale(0.8, if big then 0.5 else 0.36), 7)
	t.Icon.ScaleType = Enum.ScaleType.Fit
	t.Icon.BackgroundTransparency = 1
	local desc = child(t, "TextLabel", "RewardDesc")
	desc.FontFace = t.RewardName.FontFace
	box(desc, Vector2.new(0.5, 0), UDim2.fromScale(0.5, if big then 0.67 else 0.57), UDim2.fromScale(0.9, if big then 0.12 else 0.17), 8)
	text(desc, "Reward", WHITE, 8)
	-- minuteur : pastille sombre à cheval sur le bas de la carte
	local timer = t.Timer
	box(timer, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.92), UDim2.fromScale(if big then 0.5 else 0.74, if big then 0.11 else 0.2), 9)
	text(timer, nil, GOLD_TEXT, 9)
	timer.BackgroundTransparency = 0
	timer.BackgroundColor3 = Color3.fromHex("#141833")
	corner(timer, 0.5)
	local pad = child(timer, "UIPadding", "UIPadding")
	pad.PaddingTop = UDim.new(0.08, 0)
	pad.PaddingBottom = UDim.new(0.08, 0)
	-- bouton CLAIM (correctif du 25/11, vu par Habiller l'UI : sur téléphone la case fait 89 px de haut, et un
	-- bouton de 44 px au minimum débordait de la case et cachait le gain). Le bouton couvre maintenant TOUTE la
	-- case, transparent : la zone à toucher dépasse toujours 44 px, et c'est toute la case prête qu'on touche. Seule
	-- sa pastille visible (Lip, Face, Shade, ClaimLabel, mêmes noms, mêmes parents) est dessinée en bas, à la
	-- place du minuteur : le nom, l'icône et le gain restent visibles au-dessus.
	local claimBtn = t.ClaimButton
	box(claimBtn, Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 10)
	claimBtn.BackgroundTransparency = 1
	local pillW, pillH = if big then 0.6 else 0.86, if big then 0.13 else 0.22
	local pillX, pillY = (1 - pillW) / 2, 0.97 - pillH
	for _, c in claimBtn:GetChildren() do
		if c:IsA("GuiObject") then
			if c.Name == "Face" then
				box(c, Vector2.new(0, 0), UDim2.fromScale(pillX, pillY), UDim2.fromScale(pillW, pillH * 0.86), 11)
			elseif c.Name == "ClaimLabel" then
				box(c, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, pillY + pillH * 0.43), UDim2.fromScale(pillW * 0.86, pillH * 0.62), 12)
			else
				box(c, Vector2.new(0, 0), UDim2.fromScale(pillX, pillY), UDim2.fromScale(pillW, pillH), if c.Name == "Shade" then 11 else 10)
			end
		end
	end
	for _, c in claimBtn:GetDescendants() do
		if c:IsA("GuiObject") and c.Parent ~= claimBtn then
			c.ZIndex = 11
		end
	end
	-- réclamé : voile sombre sur toute la carte, coche et « CLAIMED » au centre, comme les jours
	local cl = t.Claimed
	box(cl, Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 13)
	cl.BackgroundColor3 = BLACK
	cl.BackgroundTransparency = 0.45
	corner(cl, 0.06)
	for _, c in cl:GetChildren() do
		if c:IsA("UIStroke") or c:IsA("UIGradient") then
			c:Destroy()
		end
	end
	local content = cl.Content
	box(content, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.9, if big then 0.14 else 0.24), 14)
	for _, c in content:GetChildren() do
		if c:IsA("GuiObject") then
			c.ZIndex = 14
		end
	end
	local lay = content:FindFirstChildOfClass("UIListLayout")
	if lay then
		lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
		lay.VerticalAlignment = Enum.VerticalAlignment.Center
	end
	local hover = t:FindFirstChild("HoverOutline")
	if hover then
		box(hover, Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 20)
		corner(hover, 0.06)
	end
end

local function playtime(page, window)
	local list = page.List
	list.Position = GRID_POS
	list.Size = GRID_SIZE
	list.AutomaticCanvasSize = Enum.AutomaticSize.None
	-- l'échelle de CanvasSize se lit sur le parent du ScrollingFrame : canevas = cadre, sans défilement
	list.CanvasSize = UDim2.new(GRID_SIZE.X.Scale, 0, GRID_SIZE.Y.Scale, 0)
	list.ScrollingEnabled = false
	list.ScrollBarThickness = 0
	local layout = list:FindFirstChildOfClass("UIGridLayout")
	if layout then
		layout:Destroy() -- les cases sont posées à leur place
	end
	local slots = grid(GRID_SIZE.X.Scale * PAGE_RATIO / GRID_SIZE.Y.Scale, true)
	local template = list.Template
	slot(template, slots[1])
	playtimeCard(template, window, false)
	template.RewardName.Text = "5 MIN"
	for _, c in list:GetChildren() do
		if c.Name:match("^Preview_") then
			c:Destroy()
		end
	end
	for i, tier in TIERS do
		local was = template.Archivable
		template.Archivable = true
		local p = template:Clone()
		template.Archivable = was
		p.Name = "Preview_" .. i
		p.LayoutOrder = i
		p.Visible = true
		slot(p, slots[i])
		if i == 7 then
			playtimeCard(p, window, true)
		end
		p.RewardName.Text = tier.title
		p.Icon.Image = tier.icon
		p.RewardDesc.Text = tier.desc
		p.Timer.Text = tier.timer
		p.ClaimButton.Visible = tier.state == "ready"
		p.Claimed.Visible = tier.state == "claimed"
		p.Parent = list
	end
	-- phrase en bas, à la place du bouton CLAIM de la page des jours (texte de l'écran, pas lu par le code)
	local hint = child(page, "TextLabel", "PlaytimeHint")
	box(hint, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.885), UDim2.fromScale(0.8, 0.1), 8)
	hint.FontFace = template.RewardName.FontFace
	text(hint, "Keep playing to unlock every gift!", WHITE, 8)
end

-- Finitions (Clément, 24/11 : « mets le fond de l'épic box en violet, avec un gleam, mets un gleam sur le jour 7 et
-- mets un sun burst en fond qui tourne ») : les effets sont joués par le code sans script dans l'UI (UiAttrFx :
-- attribut Gleam = "Loop", reflet en boucle ; FramewispFx : attribut FigmaSpin, l'image tourne de SpinSpeed degrés
-- par seconde). Et contre l'aspect « générique » : grandes icônes, noms courts en capitales.
local PURPLE = { hi = "#D9A6FF", base = "#8A3BE6" }
local RAYS = "rbxassetid://110553518823718" -- UI_Tex_Rays (rayons des cartes de boutique)
local DAY_TITLES = { "5 MIN CASH", "EPIC BOX", "15 MIN CASH", "PREMIUM BOX", "×2 CASH 15 MIN", "30 MIN CASH", "LUXURY BOX · EPIC+" }

-- rayons qui tournent derrière l'icône, découpés à la carte
local function sunburst(c, iconY, size, color)
	local clip = child(c, "Frame", "RaysClip")
	clip.BackgroundTransparency = 1
	clip.BorderSizePixel = 0
	clip.ClipsDescendants = true
	box(clip, Vector2.new(0, 0), UDim2.fromScale(0.012, 0.012), UDim2.fromScale(0.976, 0.976), 5) -- juste dans le contour
	local rays = child(clip, "ImageLabel", "Sunburst")
	rays.BackgroundTransparency = 1
	rays.Image = RAYS
	rays.ImageColor3 = Color3.fromHex(color)
	rays.ImageTransparency = 0.5
	rays.ScaleType = Enum.ScaleType.Fit
	box(rays, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, iconY), UDim2.fromScale(size, size), 6)
	child(rays, "UIAspectRatioConstraint", "UIAspectRatioConstraint").AspectRatio = 1
	rays:SetAttribute("FigmaSpin", 1)
	rays:SetAttribute("SpinSpeed", 18)
end

local function finish(gui, window)
	local st = window.DailyPage.Streak
	for i = 1, 7 do
		local d = st["Day" .. i]
		text(d.RewardName, DAY_TITLES[i], WHITE, 8)
		if i < 7 then
			box(d.Icon, Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.18), UDim2.fromScale(0.86, 0.5), 7)
			box(d.RewardName, Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.69), UDim2.fromScale(0.92, 0.27), 8)
		else
			box(d.Icon, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.8, 0.6), 7)
			box(d.RewardName, Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.82), UDim2.fromScale(0.92, 0.14), 8)
		end
	end
	-- jour 2 : boîte Épique, fond violet (la couleur Épique du jeu) et reflet
	local d2 = st.Day2
	card(d2, "DayShadow", PURPLE, window)
	d2:SetAttribute("Gleam", "Loop")
	local g2 = d2:FindFirstChild("Glow")
	if g2 then
		g2.ImageColor3 = Color3.fromHex("#F0D9FF")
	end
	-- jour 7 : reflet et rayons qui tournent derrière la grande boîte
	local d7 = st.Day7
	d7:SetAttribute("Gleam", "Loop")
	sunburst(d7, 0.5, 1.15, "#FFFBE6")
	if PLAYTIME_SLOTS then
		-- 7e cadeau (la boîte Épique) : comme le jour 2, violet, reflet et rayons
		local p7 = window.PlaytimePage.List:FindFirstChild("Preview_7")
		-- Gros lots (Clément, 25/11 : « oui » à « cases de 20 min et de 1 h plus grandes, dorées, avec des rayons ») :
		-- case 4 (20 min, large) et case 7 (1 h, grand carré) dorées, reflet en boucle et rayons qui tournent.
		-- Le code d'Ironix doit mettre ses deux lots exceptionnels sur les rangs 4 et 7.
		local list = window.PlaytimePage.List
		for _, n in { 4, 7 } do
			local p = list:FindFirstChild("Preview_" .. n)
			if p then
				card(p, "Lip", GOLD, window)
				p:SetAttribute("Gleam", "Loop")
				p:SetAttribute("Jackpot", true)
				sunburst(p, if n == 7 then 0.41 else 0.38, if n == 7 then 1.1 else 1.25, "#FFFBE6")
			end
		end
	end
end

local function apply(gui)
	local window = gui.Root.Window
	daily(window.DailyPage, window)
	if PLAYTIME_SLOTS then
		playtime(window.PlaytimePage, window)
	end
	finish(gui, window)
end

if PREVIEW then
	for _, n in { "_PREVIEW_CLAUDE_RewardsD", "_PREVIEW_CLAUDE_RewardsP" } do
		local old = SG:FindFirstChild(n)
		if old then
			old:Destroy()
		end
	end
	local src = SG.UI_Rewards
	local was = src.Archivable
	src.Archivable = true
	local d = src:Clone()
	local p = src:Clone()
	src.Archivable = was
	for _, c in { d, p } do
		c.Archivable = false
		c.Enabled = false
		c.DisplayOrder = 200
		apply(c)
		-- jour 2 = aujourd'hui (la boîte Épique), jour 1 réclamé
		for i = 1, 7 do
			local day = c.Root.Window.DailyPage.Streak["Day" .. i]
			day.Today.Visible = i == 2
			day.Claimed.Visible = i < 2
		end
	end
	d.Name = "_PREVIEW_CLAUDE_RewardsD"
	p.Name = "_PREVIEW_CLAUDE_RewardsP"
	p.Root.Window.DailyPage.Visible = false
	p.Root.Window.PlaytimePage.Visible = true
	-- « Selected » est aussi une propriété des boutons : on passe par FindFirstChild
	for tab, on in { [p.Root.Tabs.DailyTab] = false, [p.Root.Tabs.PlaytimeTab] = true } do
		local sel = tab:FindFirstChild("Selected")
		if sel then
			sel.Visible = on
		end
	end
	d.Parent = SG
	p.Parent = SG
	return "aperçus posés (Enabled = false : en allumer un à la fois)"
end

local rec = CHS:TryBeginRecording("UI : récompenses refaites (jour 7 en carré, temps de jeu en 7 cases)")
local ok, err = pcall(function()
	local backups = SS.MapBackups:FindFirstChild("2026-11-24_Recompenses")
	if not backups then
		backups = Instance.new("Folder")
		backups.Name = "2026-11-24_Recompenses"
		backups.Parent = SS.MapBackups
	end
	if not backups:FindFirstChild("UI_Rewards") then
		SG.UI_Rewards:Clone().Parent = backups
	end
	apply(SG.UI_Rewards)
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "UI_Rewards : Daily refaite" .. (if PLAYTIME_SLOTS then ", Playtime en 7 cases" else "")
