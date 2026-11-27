--!nonstrict
-- ui_cantin_l418_l419_l421.luau (26/11) : demandes de Cantin, à lancer en Edit.
--   L-421 : UI_HUD n'a plus qu'un Income (StatsPanel.CashRow.Income, lu par HudController) ; les deux Income de
--           FeaturedOffer (RightRail et RightRailTouch, aucun code ne les lit) deviennent OfferIncome.
--   L-418 : UI_Inventory
--     (1) ItemsSection.Cards.Template : HoldButton (carré bleu d'Index, « Hold ») et SellButton (carré vert du Shop,
--         « Sell », sans soleil) côte à côte en bas de la carte, au-dessus de la zone d'appui PlaceButton ; HeldPill
--         (« IN HAND », cachée) en haut ; la carte est plus haute (rapport 0,7 au lieu de 0,86) ;
--     (2) Root.Window.Confirm (caché), copie de UI_Displayed.Dock.Confirm (ItemIcon, ItemRarity, ItemName, SellPrice,
--         YesButton, NoButton rouge), sans CloseButton, centré sur la fenêtre ;
--     (3) PotionsSection.Cards.Template (caché), copie du Template des outils : Icon, PotionName, PotionStat, Count
--         (« x3 »), UseButton (toute la carte), ActivePill.TimerLabel (cachée).
--   L-419 : UI_SkillTree.Tree : Tile_OfflineTime1 (place de Tile_Next4), Tile_OfflineTime2 et Tile_BoxLuck, copies de
--           Tile_PotionTime sans RebirthLocked ; icônes à dessiner (Info.Icon vide en attendant).
-- Aucun bouton inventé : clones des carrés validés de UI_HUD.LeftRailTouch. Sauvegarde : ServerStorage/MapBackups/
-- 2026-11-26_Cantin_L418_L419_L421.

local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")
local CHS = game:GetService("ChangeHistoryService")

local function must(parent, name, recursive)
	local found = parent and parent:FindFirstChild(name, recursive)
	assert(found, `{name} introuvable`)
	return found
end

local hud = SG.UI_HUD
local touch = must(hud, "LeftRailTouch", true)
local SQ_BLUE = must(touch, "IndexButton")
local SQ_GREEN = must(touch, "RobuxShopButton")

local function place(o, ap, pos, size, z)
	o.AnchorPoint = ap
	o.Position = pos
	o.Size = size
	if z then
		o.ZIndex = z
	end
end

-- carré validé : texte de Label et LabelShadow, Icon gardée ou remplacée, soleil caché, alertes retirées
local function square(src, name, label, icon)
	local b = src:Clone()
	b.Name = name
	for _, d in b:GetChildren() do
		if d.Name:match("Alert$") then
			d:Destroy()
		end
	end
	for _, n in { "Label", "LabelShadow" } do
		local l = b:FindFirstChild(n)
		if l then
			l.Text = label
			l.TextScaled = true
			l.TextWrapped = true
		end
	end
	local ic = b:FindFirstChild("Icon", true)
	if ic and icon then
		ic.Image = icon
	end
	for _, d in b:GetDescendants() do
		if d.Name == "Sunburst" and d:IsA("GuiObject") then
			d.Visible = false
		end
	end
	return b
end

local function text(parent, name, value, color, ap, pos, size, z)
	local l = parent:FindFirstChild(name)
	if not (l and l:IsA("TextLabel")) then
		l = Instance.new("TextLabel")
		l.Name = name
		l.Parent = parent
	end
	l.BackgroundTransparency = 1
	l.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy, Enum.FontStyle.Normal)
	l.Text = value
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.TextScaled = true
	l.TextWrapped = true
	place(l, ap, pos, size, z)
	local s = l:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	s.Thickness = 0.12
	s.Color = Color3.fromHex("0D0D14")
	s.Parent = l
	local c = l:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
	c.MaxTextSize = 22
	c.MinTextSize = 8
	c.Parent = l
	return l
end

local function apply()
	-- L-421
	for _, railName in { "RightRail", "RightRailTouch" } do
		local rail = hud:FindFirstChild(railName, true)
		local offer = rail and rail:FindFirstChild("FeaturedOffer", true)
		local inc = offer and offer:FindFirstChild("Income")
		if inc then
			inc.Name = "OfferIncome"
		end
	end

	-- L-418
	local inv = SG.UI_Inventory
	local w = inv.Root.Window
	local list = w.List
	-- (1) carte d'objet plus haute, avec Hold et Sell en bas
	local ig = must(list.ItemsSection, "Cards"):FindFirstChildOfClass("UIGridLayout")
	local igar = ig and ig:FindFirstChildOfClass("UIAspectRatioConstraint")
	assert(igar, "rapport de la grille des objets introuvable")
	igar.AspectRatio = 0.7
	ig.CellSize = UDim2.new(0.08, 64, 0, 10000) -- cartes plus larges : Hold et Sell à 40 px sur 844 × 390
	local t = list.ItemsSection.Cards.Template
	-- le contenu remonte dans les 72 % du haut
	place(t.Income, Vector2.zero, UDim2.fromScale(0.07, 0.03), UDim2.fromScale(0.6, 0.09), 6)
	place(t.MutationTag, Vector2.zero, UDim2.fromScale(0.07, 0.13), UDim2.fromScale(0.46, 0.07), 7)
	place(t.DisplayedBadge, Vector2.new(1, 0), UDim2.fromScale(0.95, 0.03), UDim2.fromScale(0.42, 0.08), 7)
	local clip, icon = t:FindFirstChild("Clip"), t:FindFirstChild("Icon")
	if clip then
		place(clip, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.36), UDim2.new(1, -10, 0.44, 0), 2)
	end
	if icon then
		place(icon, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.36), UDim2.fromScale(0.72, 0.42), 3)
	end
	place(t.ItemName, Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.58), UDim2.fromScale(0.92, 0.12), 6)
	place(t.RarityBar, Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.7), UDim2.fromScale(0.9, 0.05), 6)
	for _, n in { "HoldButton", "SellButton", "HeldPill" } do
		local old = t:FindFirstChild(n)
		if old then
			old:Destroy()
		end
	end
	local hold = square(SQ_BLUE, "HoldButton", "Hold")
	local hi = hold:FindFirstChild("Icon", true)
	if hi then
		hi.Visible = false -- pas encore d'icône « main » (à dessiner)
	end
	place(hold, Vector2.new(0, 1), UDim2.fromScale(0.06, 0.975), UDim2.fromScale(0.42, 0.26), 13)
	hold.Parent = t
	local sell = square(SQ_GREEN, "SellButton", "Sell", "rbxassetid://137831162447641") -- UI_Icon_DP_Cash_1
	place(sell, Vector2.new(1, 1), UDim2.fromScale(0.94, 0.975), UDim2.fromScale(0.42, 0.26), 13)
	sell.Parent = t
	local pill = Instance.new("Frame")
	pill.Name = "HeldPill"
	pill.BackgroundColor3 = Color3.fromHex("1F8CF0")
	pill.Visible = false
	place(pill, Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.13), UDim2.fromScale(0.62, 0.08), 8)
	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0.3, 0)
	pc.Parent = pill
	text(pill, "HeldLabel", "IN HAND", nil, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.9, 0.8), 9)
	pill.Parent = t
	-- (2) Confirm, copié de UI_Displayed
	local old = w:FindFirstChild("Confirm")
	if old then
		old:Destroy()
	end
	local conf = must(SG.UI_Displayed, "Confirm", true):Clone()
	for _, d in conf:GetDescendants() do
		if d.Name == "CloseButton" then
			d:Destroy()
		end
	end
	place(conf, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.55), UDim2.fromScale(0.42, 0.42), 30)
	local car = conf:FindFirstChildOfClass("UIAspectRatioConstraint")
	if not car then
		car = Instance.new("UIAspectRatioConstraint")
		car.Parent = conf
	end
	car.AspectRatio = 1.5
	conf.Visible = false
	conf.Parent = w
	-- (3) Template des potions
	local ps = list.PotionsSection
	local pcards = ps.Cards
	local oldT = pcards:FindFirstChild("Template")
	if oldT then
		oldT:Destroy()
	end
	local tg = list.ToolsSection.Cards:FindFirstChildOfClass("UIGridLayout")
	local pg = pcards:FindFirstChildOfClass("UIGridLayout")
	if pg then
		pg:Destroy()
	end
	tg:Clone().Parent = pcards
	pcards.AutomaticSize = Enum.AutomaticSize.Y
	pcards.Size = UDim2.fromScale(1, 0)
	local title = ps:FindFirstChild("TitleRow")
	if title then
		title.Visible = false
	end
	local pt = list.ToolsSection.Cards.Template:Clone()
	pt.Name = "Template"
	pt.Visible = false
	pt.ToolName.Name = "PotionName"
	pt.ToolStat.Name = "PotionStat"
	local eq = pt:FindFirstChild("EquipButton")
	if eq then
		eq.Name = "UseButton"
	end
	local ep = pt:FindFirstChild("EquippedPill")
	if ep then
		ep:Destroy()
	end
	text(pt, "Count", "x3", nil, Vector2.new(1, 0), UDim2.fromScale(0.95, 0.03), UDim2.fromScale(0.3, 0.1), 7)
	local ap = Instance.new("Frame")
	ap.Name = "ActivePill"
	ap.BackgroundColor3 = Color3.fromHex("1F8CF0")
	ap.Visible = false
	place(ap, Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.15), UDim2.fromScale(0.62, 0.09), 8)
	local apc = Instance.new("UICorner")
	apc.CornerRadius = UDim.new(0.3, 0)
	apc.Parent = ap
	text(ap, "TimerLabel", "1:42", nil, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.9, 0.8), 9)
	ap.Parent = pt
	pt.Parent = pcards

	-- L-419
	local tree = SG.UI_SkillTree.Tree
	local src = must(tree, "Tile_PotionTime")
	local places = {
		Tile_OfflineTime1 = UDim2.fromScale(0.3, 0.872),
		Tile_OfflineTime2 = UDim2.fromScale(0.2, 0.686),
		Tile_BoxLuck = UDim2.fromScale(0.8, 0.686), -- à côté de Potion Luck (0,6 ; 0,686), qui l'ouvre
	}
	local next4 = tree:FindFirstChild("Tile_Next4")
	if next4 then
		next4:Destroy() -- le code le cache ; sa place va à Tile_OfflineTime1 (L-419)
	end
	for n, pos in places do
		local o = tree:FindFirstChild(n)
		if o then
			o:Destroy()
		end
		local c = src:Clone()
		c.Name = n
		c.Position = pos
		local rl = c:FindFirstChild("RebirthLocked", true)
		if rl then
			rl:Destroy()
		end
		local ic = c:FindFirstChild("Info") and c.Info:FindFirstChild("Icon")
		if ic then
			ic.Image = "" -- icône à dessiner (UI_Icon_Skill_*)
		end
		c.Parent = tree
	end
end

local backups = SS:FindFirstChild("MapBackups")
if backups and not backups:FindFirstChild("2026-11-26_Cantin_L418_L419_L421") then
	local f = Instance.new("Folder")
	f.Name = "2026-11-26_Cantin_L418_L419_L421"
	for _, n in { "UI_HUD", "UI_Inventory", "UI_SkillTree" } do
		SG[n]:Clone().Parent = f
	end
	f.Parent = backups
end
local rec = CHS:TryBeginRecording("UI : demandes de Cantin L-418, L-419, L-421")
local ok, err = pcall(apply)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "L-421, L-418 et L-419 posés"
