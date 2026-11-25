--!nonstrict
-- ui_admin_v2_gris.luau (Clément, 2026-11-25 : « on doit faire l'admin panel comme joint et dans les références » ;
-- « panneau admin seulement moi et Cantin ») : UI_Admin en onglets, VERSION GRISE, à lancer en Edit.
-- Référence (construction seulement, jamais l'art ni le nom de l'autre jeu) : capture TikTok relayée par le chef de
-- projet, rangée dans StealAShop-Art/References/UI/Admin/ : bandeau « ADMIN PANEL » avec couronne et pastille
-- « ADMIN », colonne de gros onglets à gauche (icône qui dépasse), panneau de contenu à droite.
--
-- Ce qui ne change pas : tous les noms lus par AdminController et par le contrat (Contract/UI.luau). Le code les
-- cherche par nom à n'importe quelle profondeur (Find.path) : les sections peuvent donc changer de parent.
--   Root, Root.Header, CloseButton, StatusLabel, TargetSection (TargetLabel, PlayerList.Template), StatsSection
--   (CashRow, SpeedRow), BaseSection (TreadmillRow, ShopLevelRow, RayonsRow), GiveSection (KindRow, SearchRow,
--   ChoiceList, MutationTitle, MutationList, GiveRow), EventsSection.EventList, TeleportSection.ZoneList,
--   DangerSection.ResetRow.ResetProfileButton.
-- Ce qui change :
--   - Root : fenêtre centrée, rapport fixe 1,75, 560 × 320 au moins, 1200 × 686 au plus.
--   - Header : CrownIcon à gauche, Title « ADMIN PANEL », AdminBadge (BadgeLabel « ADMIN ») avant CloseButton.
--   - TargetSection sort du défilement : barre fixe sous le bandeau (la cible vaut pour toutes les actions).
--   - Tabs (nouveau, ScrollingFrame) : un onglet par section, StatsTab, BaseTab, GiveTab, EventsTab, TeleportTab,
--     ResetTab, chacun avec TabIcon, TabLabel et TabSelected (caché) et l'attribut Page = nom de la section.
--     56 px de haut : tout tient sur PC ; sur téléphone la colonne défile.
--   - Body : le panneau de contenu à droite. Sans le code des onglets, toutes les sections restent visibles et
--     défilent, comme avant : rien ne casse en attendant Ironix.
--   - StrengthRow et BenchRow cachés (retirés du code et du contrat).
-- Gris : aucun style (couleurs neutres, coins 6 % sur les boutons, cadres droits) ; l'habillage vient après la
-- validation de Clément, sans changer les noms. Sauvegarde : ServerStorage/MapBackups/2026-11-25_UI_Admin_v1.

local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")
local CHS = game:GetService("ChangeHistoryService")

local GREY_BG = Color3.fromHex("2B2B33")
local GREY_HEAD = Color3.fromHex("45454F")
local GREY_TAB = Color3.fromHex("5A5A66")
local GREY_PANEL = Color3.fromHex("22222A")
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy, Enum.FontStyle.Normal)

local TABS = {
	{ "StatsTab", "STATS", "StatsSection" },
	{ "BaseTab", "BASE", "BaseSection" },
	{ "GiveTab", "GIVE", "GiveSection" },
	{ "EventsTab", "EVENTS", "EventsSection" },
	{ "TeleportTab", "TELEPORT", "TeleportSection" },
	{ "ResetTab", "RESET", "DangerSection" },
}

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

local function label(o, text, xAlign)
	o.BackgroundTransparency = 1
	o.FontFace = FONT
	o.Text = text
	o.TextColor3 = WHITE
	o.TextScaled = true
	o.TextWrapped = true
	o.TextXAlignment = xAlign or Enum.TextXAlignment.Center
	local s = child(o, "UIStroke", "UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	s.Thickness = 0.12
	s.Color = BLACK
end

local function build(gui)
	local root = gui.Root
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromScale(0.9, 0.92)
	root.BackgroundColor3 = GREY_BG
	root.BackgroundTransparency = 0
	local size = child(root, "UISizeConstraint", "UISizeConstraint")
	size.MinSize = Vector2.new(560, 320)
	size.MaxSize = Vector2.new(1200, 686)
	child(root, "UIAspectRatioConstraint", "UIAspectRatioConstraint").AspectRatio = 1.75
	corner(root, 0.02)

	-- bandeau
	local header = root.Header
	header.Position = UDim2.fromOffset(0, 0)
	header.Size = UDim2.new(1, 0, 0, 56)
	header.BackgroundColor3 = GREY_HEAD
	header.BackgroundTransparency = 0
	local crown = child(header, "ImageLabel", "CrownIcon")
	crown.BackgroundColor3 = GREY_TAB
	crown.BackgroundTransparency = 0
	crown.AnchorPoint = Vector2.new(0, 0.5)
	crown.Position = UDim2.new(0, 10, 0.5, 0)
	crown.Size = UDim2.fromOffset(44, 44)
	corner(crown, 0.06)
	local title = header.Title
	title.AnchorPoint = Vector2.new(0, 0.5)
	title.Position = UDim2.new(0, 64, 0.5, 0)
	title.Size = UDim2.new(0.5, 0, 0, 40)
	label(title, "ADMIN PANEL", Enum.TextXAlignment.Left)
	local badge = child(header, "Frame", "AdminBadge")
	badge.BackgroundColor3 = GREY_TAB
	badge.AnchorPoint = Vector2.new(1, 0.5)
	badge.Position = UDim2.new(1, -64, 0.5, 0)
	badge.Size = UDim2.fromOffset(110, 36)
	corner(badge, 0.06)
	local badgeLabel = child(badge, "TextLabel", "BadgeLabel")
	badgeLabel.Size = UDim2.fromScale(0.86, 0.7)
	badgeLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	badgeLabel.Position = UDim2.fromScale(0.5, 0.5)
	label(badgeLabel, "ADMIN")
	local close = header.CloseButton
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Position = UDim2.new(1, -10, 0.5, 0)
	close.Size = UDim2.fromOffset(44, 44)
	corner(close, 0.06)

	-- barre de la cible, fixe sous le bandeau
	local body = root.Body
	local target = body:FindFirstChild("TargetSection") or root:FindFirstChild("TargetSection")
	target.Parent = root
	target.AutomaticSize = Enum.AutomaticSize.None
	target.Position = UDim2.new(0, 8, 0, 62)
	target.Size = UDim2.new(1, -16, 0, 56)
	target.BackgroundColor3 = GREY_PANEL
	target.BackgroundTransparency = 0
	local tl = target:FindFirstChildOfClass("UIListLayout")
	if tl then
		tl.FillDirection = Enum.FillDirection.Horizontal
		tl.VerticalAlignment = Enum.VerticalAlignment.Center
		tl.Padding = UDim.new(0, 8)
	end
	local st = target:FindFirstChild("SectionTitle")
	if st then
		st.Visible = false
	end
	target.TargetLabel.Size = UDim2.new(0.24, 0, 0, 40)
	target.TargetLabel.TextXAlignment = Enum.TextXAlignment.Left
	target.PlayerList.Size = UDim2.new(0.76, -24, 0, 48)

	-- colonne des onglets
	local TOP, BOTTOM = 126, 48
	local tabs = child(root, "ScrollingFrame", "Tabs")
	tabs.BackgroundTransparency = 1
	tabs.BorderSizePixel = 0
	tabs.Position = UDim2.new(0, 8, 0, TOP)
	tabs.Size = UDim2.new(0.24, 0, 1, -(TOP + BOTTOM))
	tabs.CanvasSize = UDim2.new(0, 0, 0, 0)
	tabs.AutomaticCanvasSize = Enum.AutomaticSize.Y
	tabs.ScrollingDirection = Enum.ScrollingDirection.Y
	tabs.ScrollBarThickness = 4
	local list = child(tabs, "UIListLayout", "UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 6)
	for i, t in TABS do
		local name, text, page = t[1], t[2], t[3]
		local b = child(tabs, "TextButton", name)
		b.LayoutOrder = i
		b.Text = ""
		b.AutoButtonColor = false
		b.BackgroundColor3 = GREY_TAB
		b.BackgroundTransparency = 0
		b.Size = UDim2.new(1, -8, 0, 56)
		b:SetAttribute("Page", page)
		b:SetAttribute("Press", "Squash")
		b:SetAttribute("Hover", "Pop")
		corner(b, 0.06)
		local icon = child(b, "ImageLabel", "TabIcon")
		icon.BackgroundColor3 = GREY_HEAD
		icon.BackgroundTransparency = 0
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Position = UDim2.new(0, 6, 0.5, 0)
		icon.Size = UDim2.fromOffset(40, 40)
		corner(icon, 0.06)
		local tlab = child(b, "TextLabel", "TabLabel")
		tlab.AnchorPoint = Vector2.new(0, 0.5)
		tlab.Position = UDim2.new(0, 54, 0.5, 0)
		tlab.Size = UDim2.new(1, -62, 0, 30)
		label(tlab, text, Enum.TextXAlignment.Left)
		local sel = child(b, "Frame", "TabSelected")
		sel.BackgroundTransparency = 1
		sel.Size = UDim2.fromScale(1, 1)
		sel.Visible = i == 1
		corner(sel, 0.06)
		local s = child(sel, "UIStroke", "UIStroke")
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Thickness = 3
		s.Color = WHITE
	end

	-- panneau de contenu
	body.Position = UDim2.new(0.24, 16, 0, TOP)
	body.Size = UDim2.new(0.76, -24, 1, -(TOP + BOTTOM))
	body.BackgroundColor3 = GREY_PANEL
	body.BackgroundTransparency = 0
	corner(body, 0.02)

	-- lignes retirées du code et du contrat
	for _, n in { "StrengthRow", "BenchRow" } do
		local r = body:FindFirstChild(n, true)
		if r then
			r.Visible = false
		end
	end

	local status = root.StatusLabel
	status.AnchorPoint = Vector2.new(0, 1)
	status.Position = UDim2.new(0, 16, 1, -6)
	status.Size = UDim2.new(1, -32, 0, 34)
end

local gui = SG.UI_Admin
local backups = SS:FindFirstChild("MapBackups")
if backups and not backups:FindFirstChild("2026-11-25_UI_Admin_v1") then
	local f = Instance.new("Folder")
	f.Name = "2026-11-25_UI_Admin_v1"
	gui:Clone().Parent = f
	f.Parent = backups
end
local rec = CHS:TryBeginRecording("UI : UI_Admin en onglets, version grise")
local ok, err = pcall(build, gui)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "UI_Admin v2 grise : 6 onglets, cible en barre fixe, contenu à droite"
