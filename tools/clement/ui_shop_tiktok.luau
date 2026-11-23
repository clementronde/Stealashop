--!nonstrict
-- ui_shop_tiktok.luau (Clément, 2026-11-21) : UI_RobuxShop_v2 prête pour les effets de la vidéo TikTok « shop qui
-- vit » (fiche docs/claude/notes/ui-reference-shop-tiktok-2026-11-21.md, maquette Figma « Boutique clément — effets
-- (TikTok 2026-11-21) », node 199:4143). Ne pose que des attributs et une couche invisible : rien ne bouge en jeu tant
-- qu'Ironix n'a pas codé les effets (fiche, section 5). Aucun nom lu par le code ne change, rien n'est déplacé ni
-- supprimé, aucun script.
--   Cartes (Template et Preview_* des trois sections) : IconHover = "Jump" (l'Icon saute au survol) et, sur leur
--     ItemName, Gleam = "Hover" (un reflet au survol).
--   Caisse : IconHover = "Spring" sur Crate (la caméra de la caisse 3D suit la souris) ; Gleam = "Loop" sur
--     Crate.ItemName et Featured.ItemName (reflet en boucle).
--   Décor : Idle = "Wiggle" sur Featured.Icon.Hammer et Decor.Hang1 à Hang4 (balancement).
--   Cartes de Cash (Template et Preview_*) : nouveau cadre FallLayer (Idle = "Fall", découpe, même place que Clip,
--     entre les rayons et l'icône) avec une image invisible FallItem (le billet de la carte, transparence 0,75), que le
--     code clonera. Pas le nom Template ni l'attribut IconAsset : le code s'en sert déjà pour autre chose.
--   Rayons des cartes : rien à poser, RobuxShopController les fait déjà tourner (Monetization.Shop.RaysTurn).
-- Sauvegarde : ServerStorage/MapBackups/2026-11-21_Shop/UI_RobuxShop_v2 (faite une seule fois). Peut se relancer, en
-- Edit. Annulable (une seule étape d'annulation).

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")

local BACKUP = "2026-11-21_Shop"
local SECTIONS = { "GamepassesSection", "BoostsSection", "CashSection" }

local function cards(grid)
	local list = {}
	for _, c in grid:GetChildren() do
		if c:IsA("Frame") and (c.Name == "Template" or c.Name:find("^Preview_")) then
			table.insert(list, c)
		end
	end
	return list
end

-- Couche des billets qui tombent, à la place de Clip (mêmes taille, position et découpe), au-dessus des rayons et
-- sous l'icône (l'écran est en ZIndexBehavior Global : on se place entre leurs ZIndex).
local function fallLayer(card)
	local clip = card:FindFirstChild("Clip")
	local icon = card:FindFirstChild("Icon")
	if not (clip and icon) then
		return nil
	end
	local layer = card:FindFirstChild("FallLayer")
	if not layer then
		layer = Instance.new("Frame")
		layer.Name = "FallLayer"
		layer.Parent = card
	end
	layer.BackgroundTransparency = 1
	layer.BorderSizePixel = 0
	layer.ClipsDescendants = true
	layer.AnchorPoint = clip.AnchorPoint
	layer.Position = clip.Position
	layer.Size = clip.Size
	layer.ZIndex = math.min(clip.ZIndex + 1, icon.ZIndex - 1)
	layer:SetAttribute("Idle", "Fall")

	local item = layer:FindFirstChild("FallItem")
	if not item then
		item = Instance.new("ImageLabel")
		item.Name = "FallItem"
		item.Parent = layer
	end
	item.Visible = false -- le code le clone ; lui-même ne s'affiche jamais
	item.BackgroundTransparency = 1
	item.BorderSizePixel = 0
	item.Image = icon.Image
	item.ImageTransparency = 0.75
	item.ScaleType = Enum.ScaleType.Fit
	item.AnchorPoint = Vector2.new(0.5, 0.5)
	item.Position = UDim2.fromScale(0.5, -0.15) -- au-dessus de la carte : point de départ de la chute
	item.Size = UDim2.fromScale(0.16, 0.2)
	item.ZIndex = layer.ZIndex + 1
	if not item:FindFirstChildOfClass("UIAspectRatioConstraint") then
		Instance.new("UIAspectRatioConstraint").Parent = item
	end
	return layer
end

local rec = CHS:TryBeginRecording("UI : boutique Robux prête pour les effets du TikTok du 2026-11-21")
local count = { attributes = 0, layers = 0 }
local ok, err = pcall(function()
	local gui = SG.UI_RobuxShop_v2
	local backups = SS:FindFirstChild("MapBackups")
	if not backups then
		backups = Instance.new("Folder")
		backups.Name = "MapBackups"
		backups.Parent = SS
	end
	local folder = backups:FindFirstChild(BACKUP)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = BACKUP
		folder.Parent = backups
	end
	if not folder:FindFirstChild(gui.Name) then
		local copy = gui:Clone()
		copy.Enabled = false
		copy.Parent = folder
	end

	local function mark(object, name, value)
		if object then
			object:SetAttribute(name, value)
			count.attributes += 1
		end
	end

	local root = gui.Root
	local content = root.Window.List.Content

	-- Caisse et pack de départ
	mark(content.Crate, "IconHover", "Spring")
	mark(content.Crate:FindFirstChild("ItemName"), "Gleam", "Loop")
	mark(content.Featured:FindFirstChild("ItemName"), "Gleam", "Loop")
	mark(content.Featured.Icon:FindFirstChild("Hammer"), "Idle", "Wiggle")
	for i = 1, 4 do
		mark(root.Decor:FindFirstChild("Hang" .. i), "Idle", "Wiggle")
	end

	-- Cartes des trois sections
	for _, sectionName in SECTIONS do
		for _, card in cards(content[sectionName].Grid) do
			mark(card, "IconHover", "Jump")
			mark(card:FindFirstChild("ItemName"), "Gleam", "Hover")
			if sectionName == "CashSection" and fallLayer(card) then
				count.layers += 1
			end
		end
	end
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return ("boutique Robux prête pour les effets du TikTok : %d attributs, %d couches FallLayer"):format(count.attributes, count.layers)
