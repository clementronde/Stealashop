--!nonstrict
-- ui_admin_v4_players.luau (Clément, 2026-11-25 : « on doit pouvoir sélectionner une personne du serveur ») :
-- à lancer en Edit APRÈS ui_admin_v2_gris.luau et ui_admin_v3_habille.luau.
--   - Nouvel onglet PLAYERS, en premier (orange) : sa page est TargetSection, rentrée dans Body comme les autres
--     sections. On y voit TargetLabel (« Target: you ») et PlayerList en grille de cartes (une carte par joueur du
--     serveur, Template cloné par le code ; un clic choisit la cible).
--   - La barre fixe de la cible disparaît (les onglets et le contenu remontent) ; à la place, une pastille
--     Header.TargetChip.TargetChipLabel rappelle la cible sur tous les onglets (le code d'Ironix y recopie le texte
--     de TargetLabel ; facultatif au contrat).
-- Aucun nom lu par AdminController ni par le contrat ne change : TargetSection garde TargetLabel et PlayerList, et
-- Template reste l'enfant direct de PlayerList (le code y pose ses copies).
-- Sauvegarde : ServerStorage/MapBackups/2026-11-25_UI_Admin_v3.

local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")
local CHS = game:GetService("ChangeHistoryService")
local Icons = game:GetService("ReplicatedStorage").Assets.Icons

local INK = Color3.fromHex("0D0D14")
local WHITE = Color3.new(1, 1, 1)
local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy, Enum.FontStyle.Normal)
local ORANGE = { hi = "FFC27A", base = "FF8A1A", lip = "B85A0B", line = "5C2A00" }

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

local function stroke(o, th, color, mode)
	local s = child(o, "UIStroke", "UIStroke")
	s.Thickness = th
	s.Color = color
	s.ApplyStrokeMode = mode
	s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	s.LineJoinMode = Enum.LineJoinMode.Round
	return s
end

local function text(l, value, z, xAlign)
	l.BackgroundTransparency = 1
	l.FontFace = FONT
	if value then
		l.Text = value
	end
	l.TextColor3 = WHITE
	l.TextScaled = true
	l.TextWrapped = true
	l.TextXAlignment = xAlign or Enum.TextXAlignment.Center
	l.ZIndex = z
	stroke(l, 0.14, INK, Enum.ApplyStrokeMode.Contextual)
end

-- recolore un onglet déjà habillé (copie d'un autre) avec la palette donnée
local function recolor(b, pal)
	b.Lip.BackgroundColor3 = Color3.fromHex(pal.lip)
	b.Face.UIGradient.Color = ColorSequence.new(Color3.fromHex(pal.hi), Color3.fromHex(pal.base))
	b.Face.FaceLine.UIStroke.Color = Color3.fromHex(pal.line)
end

local function apply(gui)
	local root = gui.Root
	local body = root.Body
	local tabs = root.Tabs
	local target = root:FindFirstChild("TargetSection") or body.TargetSection

	-- 1. TargetSection redevient une section de Body, en premier
	target.Parent = body
	target.LayoutOrder = -1
	target.Position = UDim2.new()
	target.Size = UDim2.new(1, -12, 0, 0)
	target.AutomaticSize = Enum.AutomaticSize.Y
	target.BackgroundColor3 = Color3.fromHex("1F1F2A")
	local tl = target:FindFirstChildOfClass("UIListLayout")
	if tl then
		tl.FillDirection = Enum.FillDirection.Vertical
		tl.HorizontalAlignment = Enum.HorizontalAlignment.Left
		tl.VerticalAlignment = Enum.VerticalAlignment.Top
		tl.Padding = UDim.new(0, 6)
	end
	local st = target:FindFirstChild("SectionTitle")
	if st then
		st.Visible = true
		st.LayoutOrder = 1
		text(st, "PLAYERS IN THIS SERVER", st.ZIndex, Enum.TextXAlignment.Left)
		st.TextColor3 = Color3.fromHex("FFD23F")
	end
	target.TargetLabel.LayoutOrder = 2
	target.TargetLabel.Size = UDim2.new(1, 0, 0, 36)
	local list = target.PlayerList
	list.LayoutOrder = 3
	list.Size = UDim2.new(1, 0, 0, 236)
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.ScrollBarThickness = 4
	list.BackgroundTransparency = 1
	local ll = list:FindFirstChildOfClass("UIListLayout")
	if ll then
		ll:Destroy()
	end
	local grid = child(list, "UIGridLayout", "UIGridLayout")
	grid.CellSize = UDim2.new(0.32, 0, 0, 56)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.FillDirectionMaxCells = 0
	local tpad = child(list, "UIPadding", "UIPadding")
	tpad.PaddingTop = UDim.new(0, 4)
	tpad.PaddingLeft = UDim.new(0, 4)
	tpad.PaddingRight = UDim.new(0, 8)
	local tpl = list.Template
	local entry = tpl:FindFirstChild("EntryName", true)
	if entry then
		entry.Position = UDim2.fromScale(0.5, 0.43)
		entry.Size = UDim2.fromScale(0.86, 0.5)
	end

	-- 2. la barre fixe disparaît : onglets et contenu remontent sous le bandeau
	local TOP, BOTTOM = 64, 48
	tabs.Position = UDim2.new(0, 8, 0, TOP)
	tabs.Size = UDim2.new(0.24, 0, 1, -(TOP + BOTTOM))
	body.Position = UDim2.new(0.24, 16, 0, TOP)
	body.Size = UDim2.new(0.76, -24, 1, -(TOP + BOTTOM))

	-- 3. onglet PLAYERS, orange, en premier (copie de StatsTab, déjà habillé)
	local players = tabs:FindFirstChild("PlayersTab")
	if players then
		players:Destroy()
	end
	players = tabs.StatsTab:Clone()
	players.Name = "PlayersTab"
	players.LayoutOrder = 0
	players:SetAttribute("Page", "TargetSection")
	recolor(players, ORANGE)
	players.TabLabel.Text = "PLAYERS"
	players.TabIcon.Image = Icons.ICON_Z4_Couronne.Texture
	local glyph = players.TabIcon:FindFirstChild("Glyph")
	if glyph then
		glyph:Destroy()
	end
	players.Parent = tabs
	for _, b in tabs:GetChildren() do
		local sel = b:IsA("GuiButton") and b:FindFirstChild("TabSelected")
		if sel then
			sel.Visible = b == players
		end
	end

	-- 4. pastille de la cible dans le bandeau, visible sur tous les onglets
	local header = root.Header
	local chip = child(header, "Frame", "TargetChip")
	chip.AnchorPoint = Vector2.new(1, 0.5)
	chip.Position = UDim2.new(1, -184, 0.5, 0)
	chip.Size = UDim2.new(0.26, 0, 0, 36)
	chip.BackgroundColor3 = Color3.fromHex("7A1010")
	chip.BackgroundTransparency = 0.2
	chip.ZIndex = 3
	local cs = child(chip, "UIStroke", "UIStroke")
	cs.Thickness = 2
	cs.Color = INK
	local cc = child(chip, "UICorner", "UICorner")
	cc.CornerRadius = UDim.new(0.2, 0)
	local cl = child(chip, "TextLabel", "TargetChipLabel")
	cl.AnchorPoint = Vector2.new(0.5, 0.5)
	cl.Position = UDim2.fromScale(0.5, 0.5)
	cl.Size = UDim2.fromScale(0.9, 0.62)
	text(cl, "Target: you", 4)
	-- le titre laisse la place à la pastille
	header.Title.Size = UDim2.new(0.42, 0, 0, 44)
end

local gui = SG.UI_Admin
local backups = SS:FindFirstChild("MapBackups")
if backups and not backups:FindFirstChild("2026-11-25_UI_Admin_v3") then
	local f = Instance.new("Folder")
	f.Name = "2026-11-25_UI_Admin_v3"
	gui:Clone().Parent = f
	f.Parent = backups
end
local rec = CHS:TryBeginRecording("UI : UI_Admin, onglet PLAYERS et pastille de la cible")
local ok, err = pcall(apply, gui)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "UI_Admin : onglet PLAYERS (TargetSection), pastille TargetChip"
