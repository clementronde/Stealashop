--!nonstrict
-- bb_shopinfo_v3_build.luau (Clément, 2026-11-23 : « lui au-dessus des boutiques est top ! », référence d'un autre
-- jeu du genre) : à lancer en Edit. Le panneau de repérage BB_ShopInfo perd son fond et passe en trois colonnes
-- posées dans le vide, contour noir épais :
--   - au milieu, la tête du propriétaire dans un rond (fond bleu, anneau doré, bord noir), son nom à cheval sur le bas
--     du rond, puis le revenu en grand et en vert ;
--   - à gauche, la porte : HPIcon en grand (logo de vitre), « DOOR », puis HP (« 7/40 ») ;
--   - à droite, le meilleur objet : BestIcon (nouveau, caché tant que le code ne le remplit pas), « BEST ITEM », puis
--     BestItem (nom à la couleur de la rareté, écrit par le code). Icône et légende sont des enfants de BestItem :
--     elles se cachent avec lui quand la boutique n'a aucun objet exposé ;
--   - Status (« LOCKED 23s », « OPEN »…) : pastille orange au-dessus du rond.
-- Noms lus par le code gardés : OwnerName, Income, HP, Status, OwnerAvatar, BestItem (Contract/UI, cherchés parmi
-- les descendants). Panel reste le cadre de tout, InnerLine disparaît. Aucun script.
-- PREVIEW = true : rien ne change dans Assets ; une copie remplie d'exemples est posée au-dessus de la porte de
-- PLOT_Shop_02 (_PREVIEW_CLAUDE_ShopInfo, non archivable, à détruire). PREVIEW = false : le gabarit change
-- (sauvegarde ServerStorage/MapBackups/2026-11-23_ShopInfo, annulable).

local PREVIEW = false

local CHS = game:GetService("ChangeHistoryService")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

local W, H = 19, 7.5 -- studs
local AR = W / H
local GREEN = Color3.fromHex("#4BE04F")
local SKY = Color3.fromHex("#2FA8EE")
local BLACK = Color3.new(0, 0, 0)
local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)

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

local function stroke(gui, thickness, mode)
	for _, s in gui:GetChildren() do
		if s:IsA("UIStroke") then
			s:Destroy()
		end
	end
	local s = Instance.new("UIStroke")
	s.Color = BLACK
	s.Thickness = thickness
	s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	s.ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Contextual
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = gui
	return s
end

local function text(label, color, thickness)
	label.BackgroundTransparency = 1
	label.FontFace = FONT
	label.TextColor3 = color
	-- par script, TextScaled ne prend que si TextWrapped est vrai avant lui (sinon le texte reste à 8 px)
	label.TextScaled = false
	label.TextWrapped = true
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	stroke(label, thickness)
end

local function place(gui, anchorX, x, y, w, h)
	gui.AnchorPoint = Vector2.new(anchorX, 0)
	gui.Position = UDim2.fromScale(x, y)
	gui.Size = UDim2.fromScale(w, h)
end

local function square(gui)
	local ar = gui:FindFirstChildOfClass("UIAspectRatioConstraint") or Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 1
	ar.DominantAxis = Enum.DominantAxis.Height
	ar.Parent = gui
end

-- Logo de vitre (Clément, 2026-11-23 : d'abord un cœur au lieu du marteau, puis « mets le logo de vitre ») fait de
-- formes d'UI, sans image : un carreau bleu clair aux coins un peu arrondis, contour noir, et deux reflets blancs en
-- diagonale tracés par un dégradé à arêtes vives (pas d'enfant tourné : ClipsDescendants ne les couperait pas).
-- HPIcon garde son nom ; son image est vidée.
local GLASS = {
	{ 0, "#C9F4FF" }, { 0.2, "#A6EBFF" }, { 0.21, "#FFFFFF" }, { 0.33, "#FFFFFF" }, { 0.34, "#8EDFFC" },
	{ 0.42, "#86DBFB" }, { 0.43, "#FFFFFF" }, { 0.48, "#FFFFFF" }, { 0.49, "#73D2F8" }, { 1, "#2FA3E4" },
}
local function glass(icon)
	icon.Image = ""
	for _, old in { "Heart", "HeartEdge", "HeartShine" } do
		if icon:FindFirstChild(old) then
			icon[old]:Destroy()
		end
	end
	local pane = child(icon, "Frame", "Glass")
	pane.AnchorPoint = Vector2.new(0.5, 0.5)
	pane.Position = UDim2.fromScale(0.5, 0.5)
	pane.Size = UDim2.fromScale(0.84, 0.84)
	pane.BackgroundColor3 = Color3.new(1, 1, 1)
	pane.BackgroundTransparency = 0
	pane.BorderSizePixel = 0
	pane.ZIndex = 4
	child(pane, "UICorner", "UICorner").CornerRadius = UDim.new(0.12, 0)
	stroke(pane, 0.07, Enum.ApplyStrokeMode.Border)
	local keys = {}
	for _, k in GLASS do
		table.insert(keys, ColorSequenceKeypoint.new(k[1], Color3.fromHex(k[2])))
	end
	local grad = child(pane, "UIGradient", "UIGradient")
	grad.Color = ColorSequence.new(keys)
	grad.Rotation = 45
end

local function apply(bb)
	bb.Size = UDim2.fromScale(W, H)
	bb.SizeOffset = Vector2.new(0, 0.5)
	local panel = bb.Panel
	panel.BackgroundTransparency = 1
	panel.Position = UDim2.fromScale(0, 0)
	panel.Size = UDim2.fromScale(1, 1)
	for _, s in panel:GetChildren() do
		if s:IsA("UIStroke") then
			s:Destroy()
		end
	end
	if panel:FindFirstChild("InnerLine") then
		panel.InnerLine:Destroy()
	end

	-- au milieu : la tête du propriétaire, son nom, le revenu
	local avatar = panel.OwnerAvatar
	place(avatar, 0.5, 0.5, 0.15, 0.5 / AR, 0.5)
	square(avatar)
	avatar.BackgroundTransparency = 0
	avatar.BackgroundColor3 = SKY
	avatar.ZIndex = 3
	avatar.ScaleType = Enum.ScaleType.Crop
	child(avatar, "UICorner", "UICorner").CornerRadius = UDim.new(0.5, 0)
	-- Clément, 2026-11-23 : « retire les ronds jaunes autour » : un simple contour noir, comme les textes
	stroke(avatar, 0.04, Enum.ApplyStrokeMode.Border)
	if avatar:FindFirstChild("AvatarEdge") then
		avatar.AvatarEdge:Destroy()
	end

	local name = panel.OwnerName
	place(name, 0.5, 0.5, 0.6, 0.36, 0.16)
	text(name, Color3.new(1, 1, 1), 0.13)
	name.ZIndex = 5

	local income = panel.Income
	place(income, 0.5, 0.5, 0.75, 0.36, 0.24)
	text(income, GREEN, 0.13)
	income.ZIndex = 5

	-- à gauche : la porte
	local hpLine = panel.HPLine
	local list = hpLine:FindFirstChildOfClass("UIListLayout")
	if list then
		list:Destroy()
	end
	place(hpLine, 0.5, 0.15, 0.24, 0.3, 0.74)
	hpLine.BackgroundTransparency = 1
	local hpIcon = hpLine.HPIcon
	place(hpIcon, 0.5, 0.5, 0, 0.6, 0.56)
	square(hpIcon)
	hpIcon.BackgroundTransparency = 1
	hpIcon.ZIndex = 3
	glass(hpIcon)
	local doorLabel = child(hpLine, "TextLabel", "DoorLabel")
	doorLabel.Text = "DOOR"
	place(doorLabel, 0.5, 0.5, 0.56, 1, 0.17)
	text(doorLabel, Color3.new(1, 1, 1), 0.12)
	doorLabel.ZIndex = 4
	local hp = hpLine.HP
	place(hp, 0.5, 0.5, 0.73, 1, 0.25)
	text(hp, Color3.new(1, 1, 1), 0.13)
	hp.ZIndex = 4

	-- à droite : le meilleur objet (icône et légende dans BestItem, cachées avec lui)
	local best = panel.BestItem
	local rowH = 0.74 * 0.2 -- un peu plus bas que HP : un nom long reste sur une ligne
	local rowY = 0.24 + 0.74 * 0.73
	place(best, 0.5, 0.85, rowY, 0.3, rowH)
	text(best, best.TextColor3, 0.13)
	best.ZIndex = 4
	local caption = child(best, "TextLabel", "BestLabel")
	caption.Text = "BEST ITEM"
	local capH = 0.74 * 0.17
	place(caption, 0.5, 0.5, (0.24 + 0.74 * 0.56 - rowY) / rowH, 1, capH / rowH)
	text(caption, Color3.new(1, 1, 1), 0.12)
	caption.ZIndex = 4
	local icon = child(best, "ImageLabel", "BestIcon")
	local iconH = 0.74 * 0.56
	place(icon, 0.5, 0.5, (0.24 - rowY) / rowH, 1, iconH / rowH)
	square(icon)
	icon.BackgroundTransparency = 1
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = 3
	icon.Visible = false -- le code la remplit (image ICON_ de l'objet) et la montre

	-- en haut : la pastille d'état
	local status = bb.Status
	place(status, 0.5, 0.5, 0, 0.3, 0.13)
	status.ZIndex = 6
end

if PREVIEW then
	local old = workspace:FindFirstChild("_PREVIEW_CLAUDE_ShopInfo")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "_PREVIEW_CLAUDE_ShopInfo"
	folder.Archivable = false
	local door = workspace.Map.Hub.Shops.PLOT_Shop_02.PlotDoor
	local cf, size = door:GetBoundingBox()
	local normal = if size.X < size.Z then cf.RightVector else cf.LookVector
	normal = Vector3.new(normal.X, 0, normal.Z).Unit
	local plotPos = door.Parent:GetPivot().Position
	if (plotPos - cf.Position):Dot(normal) > 0 then
		normal = -normal
	end
	local point = Instance.new("Part")
	point.Name = "Point"
	point.Anchored = true
	point.CanCollide = false
	point.CanQuery = false
	point.Transparency = 1
	point.Size = Vector3.one * 0.2
	point.Position = cf.Position + Vector3.new(0, size.Y / 2 + 3.6, 0) + normal * 3
	point.Parent = folder
	local bb = RS.Assets.UI.BB_ShopInfo:Clone()
	apply(bb)
	bb.Adornee = point
	bb.Parent = folder
	-- exemples
	local secret = nil
	local ok, Rarities = pcall(require, RS.Shared.Config.Rarities)
	if ok and type(Rarities) == "table" then
		for _, r in Rarities.List or Rarities do
			if type(r) == "table" and (r.Id == "Secret" or r.Name == "Secret") then
				secret = r
			end
		end
	end
	bb.Panel.OwnerName.Text = "Alice's Shop"
	bb.Panel.Income.Text = "+$132.6K/s"
	bb.Panel.HPLine.HP.Text = "40/40"
	bb.Panel.OwnerAvatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. game:GetService("StudioService"):GetUserId() .. "&w=150&h=150"
	bb.Panel.BestItem.Text = "Golden Lucky Cat"
	if secret and secret.Color then
		bb.Panel.BestItem.TextColor3 = secret.Color
	end
	local icon = bb.Panel.BestItem.BestIcon
	icon.Image = RS.Assets.Icons.ICON_Secret_ChatPorteBonheurDore.Texture
	icon.Visible = true
	bb.Status.Visible = false
	folder.Parent = workspace
	return "aperçu posé : " .. tostring(point.Position) .. " normale " .. tostring(normal)
end

local rec = CHS:TryBeginRecording("UI : BB_ShopInfo en trois colonnes, sans fond")
local ok, err = pcall(function()
	local backups = SS.MapBackups:FindFirstChild("2026-11-23_ShopInfo")
	if not backups then
		backups = Instance.new("Folder")
		backups.Name = "2026-11-23_ShopInfo"
		backups.Parent = SS.MapBackups
	end
	if not backups:FindFirstChild("BB_ShopInfo") then
		RS.Assets.UI.BB_ShopInfo:Clone().Parent = backups
	end
	apply(RS.Assets.UI.BB_ShopInfo)
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "BB_ShopInfo : trois colonnes, sans fond"
