--!nonstrict
-- ui_roue_parts.luau (Clément, 2026-11-24 : « on doit refaire l'UI de la roue », puis, devant des cases posées sur un
-- disque bleu : « la roue horrible », avec en exemple une roue en parts de couleurs vives) : à lancer en Edit.
-- UI_Wheel garde tous ses noms ; la roue devient un camembert de 8 parts :
--   - Wheel.Sectors : 4 CanvasGroup Q1 à Q4 (un quart de roue chacun, qui découpe), avec dans chacun un disque
--     Disc partagé en deux couleurs le long de la diagonale (UIGradient à saut net) : 8 parts de 45°, une couleur
--     par lot (Config/Wheel.Sectors, même ordre), nettes même quand la roue tourne. Aucune image nouvelle.
--     Un CanvasGroup ne découpe qu'en ZIndexBehavior Sibling : l'écran passe de Global à Sibling (vérifié : le
--     reste de la fenêtre s'affiche pareil).
--   - Divider_1 à _4 : traits sombres entre les parts ; Studs : tenons par-dessus ; jante (Rim, qui ne tourne
--     pas) sombre ; moyeu (Hub) doré avec une étoile (HubStar, HubIcon caché) et un anneau sombre (HubRing).
--   - Wheel.Segment_NN (même centre qu'avant, donc mêmes angles pour le code) ne dessine plus de case : il porte
--     le texte du lot au bord (Amount, deux lignes), une grande icône au milieu (Icon) et la chance près du centre
--     (Chance, « 30% », écrite par le code) ; WinGlow, un halo caché derrière l'icône, que le code allume sur la
--     part gagnante. Les parts du bas (Segment_03 à _06) sont retournées pour se lire à l'endroit, roue à l'arrêt.
--   - Pointer : un petit triangle rouge à contour sombre, en haut au centre (toujours au-dessus du centre).
-- Icônes livrées (L-268) : Decals ICON_WHEEL_Cash, _Box, _Boost, _PotionMoney, _BoxRare, _BoxEpic, _Jackpot
-- dans ReplicatedStorage/Assets/Icons, sur des images déjà dans le jeu.
-- Le code (WheelController) ne touche que les textes, Icon.Image, Result.Visible et Wheel.Rotation : rien ne casse.
-- Textes des lots (Config/Wheel.Sectors.Label, code d'Ironix) : proposés sur deux lignes (« 5 MIN\nCASH ») pour
-- que toutes les parts aient la même taille de texte ; l'aperçu les montre ainsi.
-- PREVIEW = true : rien ne change ; une copie de l'écran avec ces textes est posée dans StarterGui
-- (_PREVIEW_CLAUDE_Wheel, non archivable, à détruire). PREVIEW = false : l'écran change (sauvegarde
-- ServerStorage/MapBackups/2026-11-24_Roue).

local PREVIEW = false

local CHS = game:GetService("ChangeHistoryService")
local RS = game:GetService("ReplicatedStorage")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")

local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromHex("#15151D")

local CASH = "rbxassetid://138179722277427"
-- lot de chaque part, dans l'ordre de Config/Wheel.Sectors (Segment_01 en haut à droite, puis sens horaire).
-- Clément (24/11) : « mets une epic box 2 % » à la place de STRENGTH POTION (« la potion de force n'existe pas ») ;
-- les boîtes prennent la couleur de leur rareté (Config/Rarities : Rare #2F9BFF, Epic #A855F7).
local PRIZES = {
	{ label = "5 MIN\nCASH", color = "#35C94A", icon = "WHEEL_Cash", image = CASH },
	{ label = "MYSTERY\nBOX", color = "#FF8A1F", icon = "WHEEL_Box", image = "rbxassetid://123386984775846" },
	{ label = "×2 CASH\n10 MIN", color = "#EC2F3B", icon = "WHEEL_Boost", image = "rbxassetid://90748953656553" },
	{ label = "MONEY\nPOTION", color = "#E340D6", icon = "WHEEL_PotionMoney", image = "rbxassetid://82423065290603" },
	{ label = "15 MIN\nCASH", color = "#14C2A3", icon = "WHEEL_Cash", image = CASH },
	{ label = "RARE\nBOX", color = "#2F9BFF", icon = "WHEEL_BoxRare", image = "rbxassetid://97801885378809" },
	{ label = "EPIC\nBOX", color = "#A855F7", icon = "WHEEL_BoxEpic", image = "rbxassetid://115708294705724" },
	{ label = "60 MIN\nCASH", color = "#FFC21A", icon = "WHEEL_Jackpot", image = "rbxassetid://86676020914512" },
}
-- chances de l'aperçu : EPIC BOX 2 % (Clément) ; les 3 % de l'ancienne potion de force vont à 5 MIN CASH (proposé)
local CHANCES = { "33%", "20%", "15%", "5%", "15%", "7%", "2%", "3%" }

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

local function gradient(o, keys, rot)
	local g = child(o, "UIGradient", "UIGradient")
	local seq = {}
	for _, k in keys do
		table.insert(seq, ColorSequenceKeypoint.new(k[1], Color3.fromHex(k[2])))
	end
	g.Color = ColorSequence.new(seq)
	g.Rotation = rot or 90
	return g
end

local function frame(parent, name, pos, size, z, color)
	local f = child(parent, "Frame", name)
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = pos
	f.Size = size
	f.ZIndex = z
	f.Rotation = 0
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color or WHITE
	f.BackgroundTransparency = 0
	return f
end

local function text(label, value, z)
	label.BackgroundTransparency = 1
	label.Text = value
	label.TextColor3 = WHITE
	label.TextScaled = false
	label.TextWrapped = true
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = z
	stroke(label, 0.13, BLACK, Enum.ApplyStrokeMode.Contextual)
end

-- 8 parts : 4 quarts de roue (CanvasGroup qui découpe) ; dans chacun, un disque de la taille de la roue, centré
-- sur son centre, aux deux couleurs des parts du quart, séparées le long de la diagonale du quart.
local QUADS = { { 0.5, 0 }, { 0.5, 0.5 }, { 0, 0.5 }, { 0, 0 } } -- haut droit, bas droit, bas gauche, haut gauche
local function sectors(wheel)
	local holder = child(wheel, "Frame", "Sectors")
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.AnchorPoint = Vector2.new(0, 0)
	holder.Position = UDim2.fromScale(0, 0)
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = 1
	for q = 1, 4 do
		local cg = child(holder, "CanvasGroup", "Q" .. q)
		cg.BackgroundTransparency = 1
		cg.BorderSizePixel = 0
		cg.Position = UDim2.fromScale(QUADS[q][1], QUADS[q][2])
		cg.Size = UDim2.fromScale(0.5, 0.5)
		cg.ZIndex = 1
		local disc = child(cg, "Frame", "Disc")
		disc.BorderSizePixel = 0
		disc.BackgroundColor3 = WHITE
		disc.BackgroundTransparency = 0
		disc.AnchorPoint = Vector2.new(0.5, 0.5)
		disc.Position = UDim2.fromScale(if QUADS[q][1] == 0.5 then 0 else 1, if QUADS[q][2] == 0.5 then 0 else 1)
		disc.Size = UDim2.fromScale(2, 2)
		corner(disc, 0.5)
		local a, b = PRIZES[2 * q - 1].color, PRIZES[2 * q].color
		gradient(disc, { { 0, a }, { 0.4999, a }, { 0.5001, b }, { 1, b } }, 45 + 90 * (q - 1))
	end
end

-- Contenu d'une part. Dans le cadre (tourné vers le bord), y = 0 au bord de la roue ; les parts du bas sont
-- retournées de 180° et leur contenu est placé en miroir.
local function place(o, flip, top, h, w)
	o.AnchorPoint = Vector2.new(0.5, 0)
	o.Position = UDim2.fromScale(0.5, if flip then 1 - top - h else top)
	o.Size = UDim2.fromScale(w, h)
	o.Rotation = 0
end

local function part(seg, n, prize, preview)
	for _, name in { "Lip", "Face", "Studs", "Gloss", "WinGlow", "ChanceTag", "Rays" } do
		local c = seg:FindFirstChild(name)
		if c then
			c:Destroy()
		end
	end
	for _, c in seg:GetChildren() do
		if c:IsA("UIGradient") or c:IsA("UIStroke") or c:IsA("UICorner") then
			c:Destroy()
		end
	end
	local flip = n >= 3 and n <= 6
	seg.BackgroundTransparency = 1
	seg.Size = UDim2.fromScale(0.32, 0.38) -- du moyeu au bord ; le centre ne bouge pas (angles du code)
	seg.Rotation = 22.5 + 45 * (n - 1) + (if flip then 180 else 0)
	seg.ZIndex = 6

	local glow = child(seg, "Frame", "WinGlow")
	place(glow, flip, 0.27, 0.44, 0.78)
	glow.BackgroundColor3 = Color3.fromHex("#FFF6C8")
	glow.BackgroundTransparency = 0.25
	glow.BorderSizePixel = 0
	glow.ZIndex = 1
	corner(glow, 0.5)
	glow.Visible = false -- le code l'allume sur la part gagnante

	local icon = seg:FindFirstChild("Icon")
	place(icon, flip, 0.31, 0.36, 0.62)
	icon.BackgroundTransparency = 1
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = 2
	if preview then
		icon.Image = prize.image
	end

	local amount = seg:FindFirstChild("Amount")
	place(amount, flip, 0.03, 0.27, 0.92)
	text(amount, if preview then prize.label else amount.Text, 3)
	amount.LineHeight = 0.9

	local chance = child(seg, "TextLabel", "Chance")
	chance.FontFace = amount.FontFace
	place(chance, flip, 0.7, 0.13, 0.44)
	text(chance, if preview then CHANCES[n] else "0%", 3)
end

local function face(wheel)
	local g = wheel:FindFirstChildOfClass("UIGradient")
	if g then
		g:Destroy()
	end
	wheel.BackgroundColor3 = INK
	stroke(wheel, 0.012, BLACK)
	for _, name in { "Pegs", "HubRing" } do
		local c = wheel:FindFirstChild(name)
		if c then
			c:Destroy()
		end
	end
	local studs = wheel:FindFirstChild("Studs")
	if studs then
		studs.ZIndex = 2
		studs.ImageTransparency = 0.8
	end
	for _, d in wheel:GetChildren() do
		if d.Name:match("^Divider_%d") then
			d.BackgroundColor3 = INK
			d.Size = UDim2.fromScale(0.011, 1)
			d.ZIndex = 3
			local ds = d:FindFirstChildOfClass("UIStroke")
			if ds then
				ds:Destroy()
			end
		end
	end
	-- moyeu : anneau sombre, disque doré, reflet, étoile
	local ring = frame(wheel, "HubRing", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.25, 0.25), 4, INK)
	corner(ring, 0.5)
	local hub = wheel.Hub
	hub.ZIndex = 5
	hub.Size = UDim2.fromScale(0.21, 0.21)
	gradient(hub, { { 0, "#FFF09A" }, { 0.5, "#FFC727" }, { 1, "#D9860C" } }, 90)
	stroke(hub, 0.05, Color3.fromHex("#3A2200"))
	local gloss = frame(hub, "Gloss", UDim2.fromScale(0.5, 0.3), UDim2.fromScale(0.66, 0.34), 1, WHITE)
	corner(gloss, 0.5)
	local gt = child(gloss, "UIGradient", "UIGradient")
	gt.Rotation = 90
	gt.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	-- l'icône d'argent du moyeu laisse la place à une étoile dorée à contour sombre (texte « ★ »)
	hub.HubIcon.Visible = false
	local star = child(hub, "TextLabel", "HubStar")
	star.BackgroundTransparency = 1
	star.Text = "★"
	star.TextColor3 = WHITE
	star.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
	star.TextScaled = false
	star.TextWrapped = true
	star.TextScaled = true
	star.AnchorPoint = Vector2.new(0.5, 0.5)
	star.Position = UDim2.fromScale(0.5, 0.437) -- le glyphe est dessiné bas dans sa boîte : remonté pour être centré (mesuré à ±1 px)
	star.Size = UDim2.fromScale(0.8, 0.8)
	star.ZIndex = 3
	gradient(star, { { 0, "#FFF6B0" }, { 1, "#FFB81A" } }, 90)
	stroke(star, 0.07, Color3.fromHex("#3A2200"), Enum.ApplyStrokeMode.Contextual)
end

-- jante sombre (ne tourne pas) ; roue, jante et Result centrés à 0,51 de WheelArea
local function rim(area)
	area.Wheel.Position = UDim2.fromScale(0.5, 0.51)
	area.Result.Position = UDim2.fromScale(0.5, 0.51)
	local r = area.Rim
	for _, name in { "Bulbs", "InnerEdge" } do
		local c = r:FindFirstChild(name)
		if c then
			c:Destroy()
		end
	end
	r.Position = UDim2.fromScale(0.5, 0.51)
	r.Size = UDim2.fromScale(1, 1)
	gradient(r, { { 0, "#3A3A52" }, { 1, "#14141C" } }, 90)
	stroke(r, 0.014, BLACK)
end

-- aiguille : un triangle rouge pointe en bas, fait d'un carré tourné de 45° dont la moitié haute est transparente
-- (UIGradient) ; un triangle sombre un peu plus grand dessous fait le contour.
local function pointer(area)
	local p = area.Pointer
	for _, c in p:GetChildren() do
		if not c:IsA("UIAspectRatioConstraint") then
			c:Destroy()
		end
	end
	p.BackgroundTransparency = 1
	p.Rotation = 45
	p.Size = UDim2.fromScale(0.07, 0.07)
	p.Position = UDim2.fromScale(0.5, 0.035)
	p.ZIndex = 10
	local half = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.4999, 1),
		NumberSequenceKeypoint.new(0.5001, 0),
		NumberSequenceKeypoint.new(1, 0),
	})
	local edge = frame(p, "Edge", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1.3, 1.3), 1, INK)
	local eg = gradient(edge, { { 0, "#15151D" }, { 1, "#15151D" } }, 45)
	eg.Transparency = half
	local fill = frame(p, "Fill", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1), 2)
	local fg = gradient(fill, { { 0, "#FF6A5E" }, { 1, "#D3141F" } }, 45)
	fg.Transparency = half
end

local function apply(gui, preview)
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local area = gui.Root.Window.WheelArea
	local wheel = area.Wheel
	sectors(wheel)
	face(wheel)
	for n, prize in PRIZES do
		part(wheel[string.format("Segment_%02d", n)], n, prize, preview)
	end
	rim(area)
	pointer(area)
end

local function icons()
	local folder = RS.Assets.Icons
	local made = {}
	for _, prize in PRIZES do
		local name = "ICON_" .. prize.icon
		if not folder:FindFirstChild(name) then
			local d = Instance.new("Decal")
			d.Name = name
			d.Texture = prize.image
			d.Parent = folder
			table.insert(made, name)
		end
	end
	return made
end

if PREVIEW then
	local old = SG:FindFirstChild("_PREVIEW_CLAUDE_Wheel")
	if old then
		old:Destroy()
	end
	local src = SG.UI_Wheel
	local was = src.Archivable
	src.Archivable = true
	local copy = src:Clone()
	src.Archivable = was
	copy.Name = "_PREVIEW_CLAUDE_Wheel"
	copy.Archivable = false
	copy.Enabled = true
	copy.DisplayOrder = 200
	apply(copy, true)
	copy.Parent = SG
	return "aperçu posé"
end

local rec = CHS:TryBeginRecording("UI : roue en 8 parts de couleur (CanvasGroup), aiguille, moyeu, icônes")
local made
local ok, err = pcall(function()
	local backups = SS.MapBackups:FindFirstChild("2026-11-24_Roue")
	if not backups then
		backups = Instance.new("Folder")
		backups.Name = "2026-11-24_Roue"
		backups.Parent = SS.MapBackups
	end
	if not backups:FindFirstChild("UI_Wheel") then
		SG.UI_Wheel:Clone().Parent = backups
	end
	apply(SG.UI_Wheel, true) -- textes, chances et icônes d'exemple = les lots proposés ; le code les réécrit en jeu
	made = icons()
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "UI_Wheel en parts ; icônes ajoutées : " .. table.concat(made, ", ")
