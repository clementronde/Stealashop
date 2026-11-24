--!nocheck
---------------------------------------------------------------- a85 : écrans de Clément (relevé du 2026-11-11)
-- UI_SkillTree et UI_HUD comme dans agents/wave27-studio.md (« Écran de l'arbre »). NEW(class, props, parent)
-- est le constructeur du faux Roblox du scénario ; RICH = true pose aussi tailles, positions et images (faux
-- Roblox d'a60) ; RICH = false : noms, classes, Visible et Text seulement (faux Roblox d'a39, contrat).
-- Tuiles : hexagones de 150 px (pointe en haut) dans un Tree de 800 × 648 px sur un écran de 1280 × 720 ;
-- un pas de 150 px entre deux colonnes, de 112,5 px entre deux rangées (x = 150·(q + r/2), y = 112,5·r).
TILE_QR = {
	RootTile = { 0, 0 },
	Tile_Glass = { -1, 0 },
	Tile_ShopLevel = { 0, -1 },
	Tile_Cameras = { 1, -1 },
	Tile_Guards = { 1, 0 },
	Tile_PotionLuck = { 0, 1 },
	Tile_GlassRegen = { -1, 1 },
	Tile_Curtain = { -2, 0 },
	Tile_DoorGuard = { 2, 0 },
	Tile_Next1 = { 0, -2 },
	Tile_Next2 = { 2, -2 },
	Tile_PotionTime = { 0, 2 },
	Tile_Next4 = { -2, 2 },
}
TILE_ICONS = {
	Tile_Glass = "rbxassetid://101463818389249",
	Tile_ShopLevel = "rbxassetid://89598496809365",
	Tile_Cameras = "rbxassetid://130895616275969",
	Tile_Guards = "rbxassetid://133701105676131",
	Tile_PotionLuck = "rbxassetid://82423065290603",
	Tile_GlassRegen = "rbxassetid://126487278824716",
	Tile_Curtain = "rbxassetid://135129985966759",
	Tile_DoorGuard = "rbxassetid://133701105676131",
	Tile_PotionTime = "rbxassetid://102799696275335",
	Tile_Next1 = "",
	Tile_Next2 = "",
	Tile_Next4 = "",
}
TREE_W, TREE_H, TILE_PX = 800, 648, 150

local function p(props, rich)
	if RICH then
		for k, v in rich do
			props[k] = v
		end
	end
	return props
end

local function hexImages(parent)
	for _, name in { "Rim", "Body", "Gloss" } do
		NEW("ImageLabel", p({ Name = name }, { Image = "rbxassetid://74256328267451", Size = UDim2.fromScale(1, 1), ZIndex = if name == "Gloss" then 4 else (if name == "Body" then 3 else 2) }), parent)
	end
end

local function buildTile(tree, name)
	local qr = TILE_QR[name]
	local q, r = qr[1], qr[2]
	local x, y = TILE_PX * (q + r / 2), TILE_PX * 0.75 * r
	local tile = NEW("TextButton", p({ Name = name, Text = "" }, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5 + x / TREE_W, 0.5 + y / TREE_H),
		Size = UDim2.fromScale(TILE_PX / TREE_W, TILE_PX / TREE_H),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
	}), tree)
	tile:SetAttribute("Q", q)
	tile:SetAttribute("R", r)
	NEW("ImageLabel", p({ Name = "Shadow" }, { Size = UDim2.fromScale(1, 1), Image = "rbxassetid://74256328267451" }), tile)
	if name == "RootTile" then
		local root = NEW("Frame", p({ Name = "Root" }, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }), tile)
		hexImages(root)
		NEW("ImageLabel", p({ Name = "Icon" }, { Image = "rbxassetid://107276625389501" }), tile)
		NEW("TextLabel", { Name = "TileName", Text = "UPGRADES" }, tile)
		return tile
	end
	for _, layer in { "Bought", "Available", "Locked" } do
		local frame = NEW("Frame", p({ Name = layer, Visible = layer == "Bought" }, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }), tile)
		hexImages(frame)
		if layer == "Locked" then
			NEW("TextLabel", { Name = "Mystery", Text = "?" }, frame)
			NEW("TextLabel", { Name = "LockedName", Text = "???" }, frame)
			NEW("TextLabel", { Name = "LockedLabel", Text = "LOCKED" }, frame)
		end
	end
	local info = NEW("Frame", p({ Name = "Info" }, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }), tile)
	NEW("TextLabel", { Name = "Level", Text = "Lv 2/5" }, info)
	NEW("ImageLabel", p({ Name = "Icon" }, { Image = TILE_ICONS[name] }), info)
	NEW("TextLabel", { Name = "TileName", Text = "Glass ×2" }, info)
	local row = NEW("Frame", { Name = "PriceRow" }, info)
	NEW("ImageLabel", p({ Name = "CashIcon" }, { Image = "rbxassetid://cash" }), row)
	NEW("TextLabel", { Name = "Price", Text = "$4M", Visible = false }, row)
	NEW("TextLabel", { Name = "PriceNeed", Text = "$4M" }, row)
	return tile
end

function buildSkillTree(parent)
	local gui = NEW("ScreenGui", p({ Name = "UI_SkillTree", Enabled = false }, { IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 5 }), nil)
	gui:SetAttribute("ScreenGroup", "Menu")
	local backdrop = NEW("Frame", p({ Name = "Backdrop" }, { Size = UDim2.fromScale(1, 1) }), gui)
	NEW("Frame", p({ Name = "Light" }, { Size = UDim2.fromScale(1, 1) }), backdrop)
	NEW("ImageLabel", p({ Name = "Studs" }, { Size = UDim2.fromScale(1, 1) }), backdrop)
	local tree = NEW("Frame", p({ Name = "Tree" }, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.6, 0.5),
		Size = UDim2.fromScale(TREE_W / 1280, TREE_H / 720),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}), gui)
	local glow = NEW("Frame", p({ Name = "SelectionGlow" }, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(TILE_PX * 1.2 / TREE_W, TILE_PX * 1.2 / TREE_H),
		BackgroundTransparency = 1,
	}), tree)
	NEW("ImageLabel", p({ Name = "Glow" }, { ImageTransparency = 0.35, Image = "rbxassetid://glow" }), glow)
	NEW("ImageLabel", p({ Name = "Ring" }, { ImageTransparency = 0.1, Image = "rbxassetid://ring" }), glow)
	for name in TILE_QR do
		buildTile(tree, name)
	end
	local pill = NEW("Frame", p({ Name = "CashPill" }, { Position = UDim2.fromScale(0.42, 0.03), Size = UDim2.fromScale(0.16, 0.08), ZIndex = 20 }), gui)
	NEW("ImageLabel", p({ Name = "CashIcon" }, { Image = "rbxassetid://cash" }), pill)
	NEW("TextLabel", { Name = "Cash", Text = "$1.4M" }, pill)
	NEW("TextLabel", { Name = "Hint", Text = "Buy upgrades to open new tiles!" }, gui)
	NEW("TextLabel", { Name = "HelpLabel", Text = "Drag to move, scroll to zoom" }, gui)
	local panel = NEW("Frame", p({ Name = "InfoPanel" }, { Position = UDim2.fromScale(0.02, 0.2), Size = UDim2.fromScale(0.24, 0.55), ZIndex = 20 }), gui)
	NEW("ImageLabel", p({ Name = "Shadow" }, { Size = UDim2.fromScale(1, 1) }), panel)
	NEW("ImageLabel", p({ Name = "Studs" }, { Size = UDim2.fromScale(1, 1) }), panel)
	local header = NEW("Frame", { Name = "Header" }, panel)
	NEW("TextLabel", { Name = "NodeName", Text = "SHOP LEVEL" }, header)
	NEW("ImageLabel", p({ Name = "NodeIcon" }, { Image = "rbxassetid://89598496809365" }), panel)
	NEW("TextLabel", { Name = "NodeLevel", Text = "Level 1 / 4" }, panel)
	local stat = NEW("Frame", { Name = "StatBox" }, panel)
	NEW("TextLabel", { Name = "NodeStat", Text = "Shop size" }, stat)
	NEW("TextLabel", { Name = "NodeEffect", Text = "Shop  ▶  Store" }, stat)
	local priceRow = NEW("Frame", { Name = "PriceRow" }, panel)
	NEW("ImageLabel", p({ Name = "CashIcon" }, { Image = "rbxassetid://cash" }), priceRow)
	NEW("TextLabel", { Name = "NodePrice", Text = "$250K" }, priceRow)
	local buy = NEW("TextButton", p({ Name = "BuyButton", Text = "" }, { Position = UDim2.fromScale(0.1, 0.8), Size = UDim2.fromScale(0.8, 0.15) }), panel)
	NEW("ImageLabel", p({ Name = "Shadow" }, { Size = UDim2.fromScale(1, 1) }), buy)
	NEW("TextLabel", { Name = "BuyLabel", Text = "BUY" }, buy)
	NEW("Frame", p({ Name = "Shade" }, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }), buy)
	local need = NEW("TextButton", p({ Name = "NeedButton", Text = "", Visible = false }, { Position = UDim2.fromScale(0.1, 0.8), Size = UDim2.fromScale(0.8, 0.15) }), panel)
	NEW("ImageLabel", p({ Name = "Shadow" }, { Size = UDim2.fromScale(1, 1) }), need)
	NEW("TextLabel", { Name = "NeedLabel", Text = "Need $4M" }, need)
	NEW("Frame", p({ Name = "Shade" }, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }), need)
	local close = NEW("TextButton", p({ Name = "CloseButton", Text = "" }, { Position = UDim2.fromScale(0.85, 0.88), Size = UDim2.fromScale(0.13, 0.09), ZIndex = 20 }), gui)
	NEW("ImageLabel", p({ Name = "Shadow" }, { Size = UDim2.fromScale(1, 1) }), close)
	NEW("TextLabel", { Name = "CloseLabel", Text = "Close" }, close)
	NEW("Frame", p({ Name = "Shade" }, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }), close)
	gui.Parent = parent
	return gui
end

-- UI_HUD : colonne LeftRail (PC) et LeftRailTouch (téléphone, cachée), les 5 boutons dans chacune ;
-- SkillTreeButton caché dans les deux (relevé).
RAIL_BUTTONS = { "RobuxShopButton", "IndexButton", "RebirthButton", "InventoryButton", "SkillTreeButton" }
function buildHud85(parent)
	local gui = NEW("ScreenGui", p({ Name = "UI_HUD" }, { ResetOnSpawn = false }), nil)
	for _, railName in { "LeftRail", "LeftRailTouch" } do
		local rail = NEW("Frame", p({ Name = railName, Visible = railName == "LeftRail" }, { Size = UDim2.fromScale(0.1, 0.5) }), gui)
		for _, name in RAIL_BUTTONS do
			local button = NEW("TextButton", p({ Name = name, Text = "", Visible = name ~= "SkillTreeButton" }, { Size = UDim2.fromScale(1, 0.18) }), rail)
			local icon = NEW("Frame", { Name = "Icon" }, button)
			NEW("ImageLabel", { Name = "IconImage" }, icon)
			NEW("TextLabel", { Name = "Label", Text = if name == "SkillTreeButton" then "Upgrades" else name }, button)
			if railName == "LeftRail" then
				NEW("Frame", p({ Name = "Shade" }, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }), button)
			end
		end
	end
	gui.Parent = parent
	return gui
end
