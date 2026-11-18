--!nonstrict
-- ui_shop_figma_1118.luau (Clément, 2026-11-18) : UI_RobuxShop_v2 recalée sur la nouvelle maquette Figma
-- « Steal a Shop — UI », cadre « Boutique clément » (node 191:2772, colonne PC de 1130 px). Les positions sont en px
-- de la maquette, converties en Scale du parent. Aucun nom lu par le code ne change (RobuxShopController, CrateLoop).
--   Caisse : titre en haut à gauche, « New ! » penché à côté, coffre penché de −5°, ombre recalée ; 6 cases de plus en
--     plus grandes, fond sombre (#0D0D14 à 72 %) avec des rayons (nouveau Rays dans chaque Odd_n), l'objet qui dépasse
--     en haut, la chance au-dessus de la case ; halos et étoiles aux places de la maquette. Boutons : le prix seul,
--     « Buy x1 / x3 / x10 » au-dessus (c'est Count, écrit par le code : à lui de passer « %d Crate » à « Buy x%d »).
--   Pack de départ : icône composée (marteau, billets, « ×2 ») dans Featured.Icon, textes, avantages, minuteur et bouton
--     aux places de la maquette ; l'ancien prix (OldPrice, ajouté le 17/11) passe à gauche du bouton.
--   Cartes (Template et Preview_* des trois sections) : rayons, filigrane penché de +12°, icône, titre, ligne d'effet
--     (Effect, de nouveau visible ; vide dans le Template, le code doit l'écrire) et bouton aux places de la maquette.
--   Survol : Hover = Pop sur les 6 cases (le code les fait pencher et grossir leur Icon) ; boutons et cartes l'avaient.
--   Apparition une à une : Appear = Cascade sur List.Content (caisse, pack, puis chaque section), en plus des cascades
--     de Odds et des Grid.
-- Sauvegarde : ServerStorage/MapBackups/2026-11-18_ShopFigma/UI_RobuxShop_v2. Peut se relancer (valeurs absolues), en
-- Edit. Annulable. Aucun script.

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")

local RAYS = "rbxassetid://96610322911997" -- rayons doux (s'effacent vers les bords), ceux de la maquette et de UI_WeaponShop
local HEAVY = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
local INK = Color3.fromHex("0d0d14")

local function put(o, pw, ph, x, y, w, h, ax, ay)
	ax, ay = ax or 0, ay or 0
	o.AnchorPoint = Vector2.new(ax, ay)
	o.Position = UDim2.fromScale((x + ax * w) / pw, (y + ay * h) / ph)
	o.Size = UDim2.fromScale(w / pw, h / ph)
end
local function child(parent, class, name)
	local x = parent:FindFirstChild(name)
	if x and not x:IsA(class) then
		x:Destroy()
		x = nil
	end
	if not x then
		x = Instance.new(class)
		x.Name = name
		x.Parent = parent
	end
	return x
end
local function stroke(label, thickness)
	local s = label:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	s.Thickness = thickness
	s.Color = INK
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = label
end

-- Rayons doux de la maquette (retour de Clément du 2026-11-18 : « regarde bien le ray de Exclusive crate ») : même
-- texture partout, blanche ; l'ancien fondu linéaire Fade (gardé, CrateLoop le fait tourner) ne coupe plus rien.
local function softRays(img, transparency)
	img.Image = RAYS
	img.ImageColor3 = Color3.new(1, 1, 1)
	img.ImageTransparency = transparency
	img.ScaleType = Enum.ScaleType.Stretch
	local fade = img:FindFirstChild("Fade")
	if fade and fade:IsA("UIGradient") then
		fade.Transparency = NumberSequence.new(0)
	end
end

local rec = CHS:TryBeginRecording("UI : boutique Robux d'après la maquette de Clément du 2026-11-18")
local ok, err = pcall(function()
	local gui = SG.UI_RobuxShop_v2
	local backups = SS.MapBackups
	local folder = backups:FindFirstChild("2026-11-18_ShopFigma")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "2026-11-18_ShopFigma"
		folder.Parent = backups
	end
	if not folder:FindFirstChild(gui.Name) then
		local copy = gui:Clone()
		copy.Enabled = false
		copy.Parent = folder
	end

	local content = gui.Root.Window.List.Content
	content:SetAttribute("Appear", "Cascade")

	-- 1. Caisse (1130 × 372) ------------------------------------------------------------------------------------
	local crate = content.Crate
	local CW, CH = 1130, 372
	local back = crate.Backdrop
	put(back.Rays, CW, CH, -116.5, -111.5, 595, 595)
	softRays(back.Rays, 0.3)
	put(back.Glow, CW, CH, 31, 36, 300, 300)
	put(back.Shadow, CW, CH, 48, 310, 240, 39)
	put(crate.Icon, CW, CH, 28.5, 39.5, 300, 300)
	crate.Icon.Rotation = -5
	local preview = crate:FindFirstChild("Preview")
	if preview then
		put(preview, CW, CH, 28.5, 39.5, 300, 300)
	end
	local badge = crate.NewBadge
	put(badge, CW, CH, 431.5, 14.5, 97, 43)
	badge.Rotation = -8
	badge.Label.Text = "New !"
	put(badge.Label, 97, 43, 10, 5, 77, 33)
	put(crate.ItemName, CW, CH, 20, 12, 365, 48)

	local odds = crate.Odds
	put(odds, CW, CH, 362, 103, 746, 114)
	local OW, OH = 746, 114
	local SIZES = { 95.6, 96, 96, 119.9, 130, 140.6 }
	local XS = { 0, 109, 218, 327, 460, 602.4 }
	for i = 1, 6 do
		local cell = odds["Odd_" .. i]
		local s = SIZES[i]
		put(cell, OW, OH, XS[i], OH - s, s, s)
		cell:SetAttribute("Hover", "Pop")
		cell.BackgroundColor3 = INK
		cell.BackgroundTransparency = 0.28
		for _, g in cell:GetChildren() do
			if g:IsA("UIGradient") then
				g:Destroy() -- l'ancien fond de couleur : la maquette garde un fond sombre
			end
		end
		local studs = cell:FindFirstChild("Studs")
		if studs then
			studs.Visible = false
		end
		-- Rayons sous le contour (retour de Clément du 2026-11-18) : dans un cadre RaysClip qui découpe juste à
		-- l'intérieur du contour de la case (2,6 % de chaque côté, l'épaisseur du UIStroke), teintés comme les grands
		-- rayons de la caisse (Backdrop.Rays : lilas, transparence 0,3).
		local clip = child(cell, "Frame", "RaysClip")
		clip.BackgroundTransparency = 1
		clip.BorderSizePixel = 0
		clip.ClipsDescendants = true
		clip.Position = UDim2.fromScale(0.026, 0.026)
		clip.Size = UDim2.fromScale(0.948, 0.948)
		clip.ZIndex = cell.ZIndex + 1
		local old = cell:FindFirstChild("Rays")
		if old and old.Parent == cell then
			old:Destroy()
		end
		local rays = child(clip, "ImageLabel", "Rays")
		rays.BackgroundTransparency = 1
		rays.Image = RAYS
		rays.ScaleType = Enum.ScaleType.Stretch
		softRays(rays, 0.3)
		rays.Position = UDim2.fromScale(-0.055, -0.0274)
		rays.Size = UDim2.fromScale(1.055, 1.055)
		rays.ZIndex = cell.ZIndex + 1
		local icon = cell.Icon
		icon.AnchorPoint = Vector2.zero
		icon.Position = UDim2.fromScale(-0.026, -0.123)
		icon.Size = UDim2.fromScale(1, 1)
		local chance = cell.Chance
		chance.AnchorPoint = Vector2.new(0.5, 0.5)
		chance.Position = UDim2.fromScale(0.49, -0.085)
		chance.Size = UDim2.fromScale(0.7, 0.27)
		chance.TextXAlignment = Enum.TextXAlignment.Center
		chance.FontFace = HEAVY
		stroke(chance, 0.12)
	end
	-- Halos (nouvelles tailles de la maquette, contour flou compris) et étoiles, dans l'ordre de l'arbre.
	local GLOWS = { { 326.6, -14.4, 146.9 }, { 451.8, -27.2, 162.3 }, { 562.2, -67.8, 214.2 } }
	local STARS = {
		{ 469.2, -9.1, 25.1 }, { 371.2, 34.2, 18.2 },
		{ 483.2, 24.1, 19 }, { 594.5, -26.1, 26.1 },
		{ 730, -2, 25.1 }, { 623.2, 34.2, 18.2 },
	}
	local g, s = 0, 0
	for _, o in odds:GetChildren() do
		if o.Name == "RarityGlow" and o:IsA("GuiObject") then
			g += 1
			local v = GLOWS[g]
			if v then
				put(o, OW, OH, v[1], v[2], v[3], v[3])
			end
		elseif o.Name == "Star" and o:IsA("GuiObject") then
			s += 1
			local v = STARS[s]
			if v then
				put(o, OW, OH, v[1], v[2], v[3], v[3])
			end
		end
	end

	local row = crate.BuyRow
	put(row, CW, CH, 360, 262, 746, 84)
	local COUNTS = { "Buy x1", "Buy x3", "Buy x10" }
	for i = 1, 3 do
		local b = row["BuyButton" .. i]
		put(b, 746, 84, (i - 1) * 254, 0, 236, 84)
		local count = b:FindFirstChild("Count")
		if count then
			count.Text = COUNTS[i]
			count.AnchorPoint = Vector2.new(0.5, 1)
			count.Position = UDim2.fromScale(0.5, -0.05)
			count.Size = UDim2.fromScale(0.9, 0.3)
			count.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)
			stroke(count, 0.1)
		end
		local priceBox = b:FindFirstChild("Content")
		if priceBox then
			priceBox.Position = UDim2.fromScale(0, 0.12)
			priceBox.Size = UDim2.fromScale(1, 0.64)
		end
	end

	-- 2. Pack de départ (1130 × 150) ---------------------------------------------------------------------------
	local featured = content.Featured
	local FW, FH = 1130, 150
	local fBackRays = featured:FindFirstChild("Rays", true)
	if fBackRays and fBackRays:IsA("ImageLabel") then
		softRays(fBackRays, 0.55)
	end
	local fIcon = featured.Icon
	put(fIcon, FW, FH, 24, 12, 118, 118)
	local fPreview = featured:FindFirstChild("Preview")
	if fPreview then
		put(fPreview, FW, FH, 24, 12, 118, 118)
	end
	local perks = featured.Perks
	local hammerImage = perks.Perk2.Icon.Image
	local cashImage = perks.Perk3.Icon.Image
	fIcon.Image = "" -- l'icône est composée de ses enfants, comme dans la maquette
	local hammer = child(fIcon, "ImageLabel", "Hammer")
	hammer.BackgroundTransparency = 1
	hammer.Image = hammerImage
	hammer.ScaleType = Enum.ScaleType.Fit
	put(hammer, 118, 118, 28.3, 0, 92, 92)
	hammer.ZIndex = fIcon.ZIndex
	local cash = child(fIcon, "ImageLabel", "Cash")
	cash.BackgroundTransparency = 1
	cash.Image = cashImage
	cash.ScaleType = Enum.ScaleType.Fit
	put(cash, 118, 118, 0, 40.1, 73.2, 73.2)
	cash.ZIndex = fIcon.ZIndex + 1
	local mult = child(fIcon, "TextLabel", "Multiplier")
	mult.BackgroundTransparency = 1
	mult.Text = "×2"
	mult.FontFace = HEAVY
	mult.TextScaled = true
	mult.TextWrapped = true
	mult.TextColor3 = Color3.new(1, 1, 1)
	put(mult, 118, 118, 44, 82, 52, 34)
	mult.ZIndex = fIcon.ZIndex + 1
	local mg = child(mult, "UIGradient", "UIGradient")
	mg.Rotation = 90
	mg.Color = ColorSequence.new(Color3.fromHex("c8ff7a"), Color3.fromHex("3fd62a"))
	stroke(mult, 0.12)

	put(featured.ItemName, FW, FH, 166, 12, 420, 52)
	put(featured.Subtitle, FW, FH, 166, 60, 330, 23)
	put(perks, FW, FH, 166, 92, 420, 40)
	put(featured.Timer, FW, FH, 847, 14, 240, 26)
	put(featured.BuyButton, FW, FH, 826, 52, 270, 74, 0, 0.5)
	local old = featured:FindFirstChild("OldPrice")
	if old then
		put(old, FW, FH, 712, 74, 104, 30, 1, 0.5)
		old.TextXAlignment = Enum.TextXAlignment.Right
	end

	-- 3. Cartes ------------------------------------------------------------------------------------------------
	local function wideCard(c)
		local W, H = 555, 206
		put(c.Clip.Rays, W, H, -43.5, -44.5, 289, 289)
		softRays(c.Clip.Rays, 0.5)
		put(c.Clip.Watermark, W, H, 372.7, 27.4, 216, 216)
		c.Clip.Watermark.Rotation = 12
		put(c.Icon, W, H, 25, 24, 152, 152)
		put(c.ItemName, W, H, 219, 25.5, 322, 46, 0, 0.5)
		local effect = c:FindFirstChild("Effect")
		if effect then
			effect.Visible = true
			put(effect, W, H, 219, 78.5, 322, 22, 0, 0.5)
		end
		for _, name in { "BuyButton", "Owned" } do
			local b = c:FindFirstChild(name)
			if b then
				put(b, W, H, 287, 126, 186, 58, 0, 1)
			end
		end
	end
	local function tallCard(c)
		local W, H = 363, 270
		put(c.Clip.Rays, W, H, 78.5, -39.5, 200, 200)
		softRays(c.Clip.Rays, 0.5)
		put(c.Clip.Watermark, W, H, 142.3, 34, 263, 263)
		c.Clip.Watermark.Rotation = 12
		put(c.Icon, W, H, 127, 9, 103, 103)
		put(c.ItemName, W, H, 14, 120.5, 335, 36, 0, 0.5)
		local effect = c:FindFirstChild("Effect")
		if effect then
			effect.Visible = true
			put(effect, W, H, 14, 156, 335, 18, 0, 0.5) -- 5 px plus haut que la maquette : le bouton de 30 px ne la touche pas sur téléphone
		end
		for _, name in { "BuyButton", "Owned" } do
			local b = c:FindFirstChild(name)
			if b then
				put(b, W, H, 19, 193, 319, 56, 0, 1)
			end
		end
	end
	-- Clément, 2026-11-18 : « réduis la taille du bouton ». Le bouton des cartes garde la taille de la maquette, avec
	-- un minimum de 30 px au lieu de 44 : sur un portable 1366 × 768, il ne recouvre plus la ligne d'effet.
	local function smallButtons(c)
		for _, name in { "BuyButton", "Owned" } do
			local b = c:FindFirstChild(name)
			local k = b and b:FindFirstChildOfClass("UISizeConstraint")
			if k then
				k.MinSize = Vector2.new(0, 30)
			end
		end
	end
	for _, sectionName in { "GamepassesSection", "BoostsSection", "CashSection" } do
		local grid = content[sectionName].Grid
		for _, c in grid:GetChildren() do
			if c:IsA("Frame") and (c.Name == "Template" or c.Name:find("^Preview_")) then
				if sectionName == "GamepassesSection" then
					wideCard(c)
				else
					tallCard(c)
				end
				c:SetAttribute("Hover", "Pop")
				smallButtons(c)
			end
		end
		local effect = grid.Template:FindFirstChild("Effect")
		if effect then
			effect.Text = "" -- le code écrit l'effet de chaque offre ; vide, une copie n'affiche pas celui du Template
		end
	end
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "boutique Robux recalée sur la maquette du 18/11"
