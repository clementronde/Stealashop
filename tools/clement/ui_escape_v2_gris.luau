--!nonstrict
-- ui_escape_v2_gris.luau (L-404, Clément, 2026-11-25 : « revoir l'UI de secured mythic item, un truc un peu
-- spectaculaire », aussi pour les gros objets et pour un coup de chance) : VERSION GRISE, à lancer en Edit.
-- Fait avec le chef VFX (partage du 25/11) :
--   - UI (ici) : la carte et sa mise en scène ;
--   - VFX (chef VFX) : les images de SecuredFx (Rays, RaysBack, Burst, Rain.Template), la colonne de lumière sur le
--     joueur et les feux d'artifice ; les couleurs par rareté.
-- Ce qui ne change pas : Banner, Banner.Title, Banner.Subtitle, Banner.BoxIcon et Flash (lus par le code).
-- Ce qui s'ajoute (tous facultatifs au contrat, tous cachés ou neutres par défaut) :
--   Veil            Frame plein écran, noir, caché : le voile autour de la carte (palier grand et coup de chance)
--   SecuredFx       Frame plein écran, transparente, cachée, au-dessus du voile et sous la carte (noms du chef VFX) :
--     Rays          ImageLabel carrée, ≈ 1,6 × la largeur de la carte, centrée sur elle (tourne en continu)
--     RaysBack      la même, plus grande et plus transparente (tourne dans l'autre sens)
--     Burst         ImageLabel, éclat au centre (grossit puis s'efface à l'arrivée)
--     Rain          Frame plein écran avec un Template (ImageLabel caché) que le code clone pour la pluie
--   Card            la carte de l'objet, sous le bandeau (déjà au contrat, facultative, remplie par
--                   CatchSceneController) : ItemIcon, ItemName, Rarity, Income, NewBadge (NewLabel « NEW! », caché)
--     Card.TierScale   UIScale (1 = palier normal ; le code le monte pour le palier grand, par exemple 1,25)
--     Card.RarityTag   TextLabel penché au-dessus de la carte (« MYTHIC! », « LUCKY! »), caché, qui tremble (code)
--     Card.Preview     ViewportFrame, l'objet en 3D à la place d'ItemIcon (gros paliers), caché
--     Card.Value       TextLabel sous la carte, la valeur de l'objet (« $225.4B »), cachée
--     Card.Weight      TextLabel, son poids (« 85 KG »), caché
-- Ordre (ZIndex) : Veil 1 < SecuredFx 2-3 < Banner et Card 4-9 < Flash 10.
-- Sauvegarde : ServerStorage/MapBackups/2026-11-25_UI_Escape_v1.

local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")
local CHS = game:GetService("ChangeHistoryService")

local INK = Color3.fromHex("0D0D14")
local WHITE = Color3.new(1, 1, 1)
local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy, Enum.FontStyle.Normal)

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

local function full(o, z)
	o.AnchorPoint = Vector2.new(0, 0)
	o.Position = UDim2.new()
	o.Size = UDim2.fromScale(1, 1)
	o.BackgroundTransparency = 1
	o.ZIndex = z
end

local function square(o, scale, z)
	o.BackgroundTransparency = 1
	o.AnchorPoint = Vector2.new(0.5, 0.5)
	o.Size = UDim2.fromScale(scale, scale)
	o.ZIndex = z
	o.ScaleType = Enum.ScaleType.Fit
	child(o, "UIAspectRatioConstraint", "UIAspectRatioConstraint").AspectRatio = 1
end

local function text(l, value, z, color)
	l.BackgroundTransparency = 1
	l.FontFace = FONT
	l.Text = value
	l.TextColor3 = color or WHITE
	l.TextScaled = true
	l.TextWrapped = true
	l.ZIndex = z
	local s = child(l, "UIStroke", "UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	s.Thickness = 0.14
	s.Color = INK
end

local function apply(gui)
	local banner = gui.Banner
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- voile
	local veil = child(gui, "Frame", "Veil")
	full(veil, 1)
	veil.BackgroundColor3 = Color3.new(0, 0, 0)
	veil.BackgroundTransparency = 0.45
	veil.Visible = false

	-- effets 2D du chef VFX, centrés sur la carte
	local fx = child(gui, "Frame", "SecuredFx")
	full(fx, 2)
	fx.Visible = false
	-- centrés sur la carte (Card, au-dessus du bandeau)
	local rays = child(fx, "ImageLabel", "Rays")
	square(rays, 0.62, 3)
	rays.Position = UDim2.new(0.5, 0, banner.Position.Y.Scale - 0.15, banner.Position.Y.Offset - 10)
	rays.ImageTransparency = 0.2
	local back = child(fx, "ImageLabel", "RaysBack")
	square(back, 0.9, 2)
	back.Position = rays.Position
	back.ImageTransparency = 0.55
	local burst = child(fx, "ImageLabel", "Burst")
	square(burst, 0.4, 3)
	burst.Position = rays.Position
	local rain = child(fx, "Frame", "Rain")
	full(rain, 3)
	rain.ClipsDescendants = true
	local drop = child(rain, "ImageLabel", "Template")
	drop.BackgroundTransparency = 1
	drop.Size = UDim2.fromScale(0.04, 0.04)
	drop.ScaleType = Enum.ScaleType.Fit
	drop.ZIndex = 3
	drop.Visible = false
	child(drop, "UIAspectRatioConstraint", "UIAspectRatioConstraint").AspectRatio = 1

	-- La carte de l'objet : UI_Escape.Card, déjà prévue par le contrat (facultative) et remplie par
	-- CatchSceneController (Card.ItemIcon, Card.ItemName, Card.Rarity, Card.Income, Card.NewBadge). Elle se pose sous
	-- le bandeau « ITEM SECURED! » (Banner, inchangé). On y ajoute, pour les gros paliers (L-404) : TierScale,
	-- RarityTag, Preview (l'objet en 3D), Value et Weight.
	for _, n in { "RarityTag", "ValueLabel", "IncomeLabel", "Preview", "WeightLabel", "TierScale" } do
		local o = banner:FindFirstChild(n) -- ajouts d'un essai précédent dans Banner : retirés
		if o then
			o:Destroy()
		end
	end
	banner.ZIndex = 4
	for _, d in banner:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex = math.max(d.ZIndex, 5)
		end
	end
	local card = child(gui, "Frame", "Card")
	-- au-dessus du bandeau (sous lui, elle sortait de l'écran sur téléphone) ; mesuré aux 4 tailles : 178..502 px en
	-- 1920 × 1080, 70..217 px en 844 × 390 (sous la barre de Roblox), textes de 10 px au moins sur téléphone
	card.AnchorPoint = Vector2.new(0.5, 1)
	card.Position = UDim2.new(0.5, 0, banner.Position.Y.Scale, banner.Position.Y.Offset - 10)
	child(card, "UISizeConstraint", "UISizeConstraint").MinSize = Vector2.new(140, 147)
	card.Size = UDim2.fromScale(0.2, 0.3)
	card.BackgroundColor3 = Color3.fromHex("1F1F2A")
	card.BackgroundTransparency = 0
	card.ZIndex = 4
	child(card, "UIAspectRatioConstraint", "UIAspectRatioConstraint").AspectRatio = 0.95
	local cs = child(card, "UIStroke", "UIStroke")
	cs.Thickness = 4
	cs.Color = INK
	cs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	child(card, "UIScale", "TierScale").Scale = 1
	local icon = child(card, "ImageLabel", "ItemIcon")
	square(icon, 0.6, 6)
	icon.Position = UDim2.fromScale(0.5, 0.36)
	local preview = child(card, "ViewportFrame", "Preview")
	preview.BackgroundTransparency = 1
	preview.AnchorPoint = Vector2.new(0.5, 0.5)
	preview.Position = icon.Position
	preview.Size = UDim2.fromScale(0.7, 0.7)
	preview.ZIndex = 6
	preview.Visible = false
	child(preview, "UIAspectRatioConstraint", "UIAspectRatioConstraint").AspectRatio = 1
	local function line(name, y, h, value, color)
		local l = child(card, "TextLabel", name)
		l.AnchorPoint = Vector2.new(0.5, 0)
		l.Position = UDim2.fromScale(0.5, y)
		l.Size = UDim2.fromScale(0.9, h)
		text(l, value, 7, color)
		return l
	end
	line("ItemName", 0.66, 0.1, "Presidential Wig")
	line("Rarity", 0.76, 0.07, "MYTHIC")
	line("Income", 0.83, 0.07, "+$12.4K/s", Color3.fromHex("5CFF5C"))
	line("Weight", 0.9, 0.06, "85 KG").Visible = false
	local value = child(card, "TextLabel", "Value")
	value.AnchorPoint = Vector2.new(0.5, 0)
	value.Position = UDim2.fromScale(0.5, 1.03)
	value.Size = UDim2.fromScale(1.1, 0.16)
	text(value, "$225.4B", 7, Color3.fromHex("FFD23F"))
	value.Visible = false
	local tag = child(card, "TextLabel", "RarityTag")
	tag.AnchorPoint = Vector2.new(0.5, 0.5)
	tag.Position = UDim2.fromScale(0.5, 0.04)
	tag.Size = UDim2.fromScale(0.8, 0.14)
	tag.Rotation = -6
	text(tag, "MYTHIC!", 8)
	tag.Visible = false
	local badge = child(card, "Frame", "NewBadge")
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position = UDim2.fromScale(0.98, 0.02)
	badge.Size = UDim2.fromScale(0.3, 0.1)
	badge.BackgroundColor3 = Color3.fromHex("FF2E2E")
	badge.ZIndex = 8
	badge.Visible = false
	local bl = child(badge, "TextLabel", "NewLabel")
	bl.Size = UDim2.fromScale(1, 1)
	text(bl, "NEW!", 9)

	-- flash blanc au-dessus de tout (remarque du chef VFX : sous le voile, il paraîtrait gris) ; il ne dure que
	-- quelques dixièmes de seconde
	gui.Flash.ZIndex = 10
end

local gui = SG.UI_Escape
local backups = SS:FindFirstChild("MapBackups")
if backups and not backups:FindFirstChild("2026-11-25_UI_Escape_v1") then
	local f = Instance.new("Folder")
	f.Name = "2026-11-25_UI_Escape_v1"
	gui:Clone().Parent = f
	f.Parent = backups
end
local rec = CHS:TryBeginRecording("UI : UI_Escape spectaculaire, version grise (L-404)")
local ok, err = pcall(apply, gui)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "UI_Escape v2 grise : Veil, SecuredFx, Card (ItemIcon, ItemName, Rarity, Income, NewBadge, Preview, Value, Weight, RarityTag, TierScale)"
