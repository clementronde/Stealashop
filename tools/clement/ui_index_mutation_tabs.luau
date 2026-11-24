--!nonstrict
-- ui_index_mutation_tabs.luau (Clément, 2026-11-24 : « dans l'onglet MUTATIONS doivent s'ouvrir d'autres onglets avec
-- l'index de toutes les mutations ») : à lancer en Edit.
-- Remet dans UI_Index_v3 les deux éléments que le code d'Ironix sait déjà lire (IndexController, Features.IndexMutations)
-- et qui avaient disparu avec la refonte v4 (L-201) :
--   - Root.MutationTabs : un onglet par effet de Config/Mutations (ShinyTab, GoldTab, NeonTab, DiamondTab, GlitchTab,
--     HackedTab, RainbowTab), en colonne à gauche de la fenêtre, symétrique des catégories (choix de Clément, version
--     B : lisible sur téléphone, 85 × 44 px et texte de 15 px en 844 × 390 ; dans le bandeau, le texte tombait à 8 px).
--     Chaque onglet = la recette des boutons de
--     catégorie (copie de Categories.MutationsButton) à la couleur de l'effet, avec TabLabel (nom) et Selected
--     (contour blanc). Le code montre MutationTabs seulement en MUTATIONS et allume Selected sur l'onglet choisi ;
--     à l'ouverture, l'onglet choisi est celui dont Selected est visible (ShinyTab).
--   - Window.MutationCaption : « Collect every item in SHINY! », écrit par le code, à la place de Rewards (que le
--     code cache hors de NORMAL).
-- Aucun nom existant changé, aucun script. Sauvegarde : ServerStorage/MapBackups/2026-11-24_OngletsMutations.
-- PREVIEW = true : rien ne change ; une copie de l'écran en MUTATIONS est posée dans StarterGui
-- (_PREVIEW_CLAUDE_IndexMut, non archivable, à détruire).

local PREVIEW = false

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")

-- couleurs des effets (face claire en haut, face, lèvre plus sombre)
local EFFECTS = {
	{ Id = "Shiny", Label = "SHINY", Top = "#FFF7C2", Face = "#F2DE6B", Lip = "#A8902A" },
	{ Id = "Gold", Label = "GOLD", Top = "#FFE07A", Face = "#F5B21B", Lip = "#A0700A" },
	{ Id = "Neon", Label = "NEON", Top = "#FF8BEA", Face = "#F03BD0", Lip = "#94187F" },
	{ Id = "Diamond", Label = "DIAMOND", Top = "#B8F6FF", Face = "#4FD6F2", Lip = "#1F8499" },
	{ Id = "Glitch", Label = "GLITCH", Top = "#B48CFF", Face = "#7A42F0", Lip = "#43208F" },
	{ Id = "Hacked", Label = "HACKED", Top = "#8DF59B", Face = "#2FCB45", Lip = "#167A25" },
	{ Id = "Rainbow", Label = "RAINBOW", Rainbow = true, Lip = "#8A2BB8" },
}
local RAINBOW = { "#FF4D4D", "#FFA53A", "#FFE14D", "#4DE06B", "#4DB8FF", "#9B5CFF" }

local function hex(h)
	return Color3.fromHex(h)
end

local function gradient(parent, colors, rotation)
	local g = parent:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient")
	local keys = {}
	for i, c in colors do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / math.max(#colors - 1, 1), hex(c)))
	end
	g.Color = ColorSequence.new(keys)
	g.Rotation = rotation
	g.Parent = parent
	return g
end

local function makeTab(model, effect, index)
	local tab = model:Clone()
	tab.Name = effect.Id .. "Tab"
	tab.LayoutOrder = index
	tab.Position = UDim2.fromScale(0, 0)
	tab.Size = UDim2.new(1, 0, 1 / #EFFECTS, -3)
	for _, n in { "CategoryAlert", "StarIcon", "LimitedAlert" } do
		local c = tab:FindFirstChild(n)
		if c then
			c:Destroy()
		end
	end
	local label = tab:FindFirstChild("Label")
	label.Name = "TabLabel"
	label.Text = effect.Label
	local shadow = tab:FindFirstChild("LabelShadow")
	if shadow then
		shadow.Text = effect.Label
	end
	tab.Face.BackgroundColor3 = hex(effect.Face or "#FFFFFF")
	if effect.Rainbow then
		gradient(tab.Face, RAINBOW, 0)
	else
		gradient(tab.Face, { effect.Top, effect.Face }, 90)
	end
	tab.Lip.BackgroundColor3 = hex(effect.Lip)
	tab:FindFirstChild("Selected").Visible = index == 1 -- « Selected » est aussi une propriété des boutons : passer par FindFirstChild
	-- au-dessus des autres éléments de la fenêtre
	for _, d in tab:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex += 10
		end
	end
	tab.ZIndex += 10
	return tab
end

local function apply(gui)
	local window = gui.Root.Window
	local model = gui.Root.Categories.MutationsButton
	for _, parent in { window, gui.Root } do
		local old = parent:FindFirstChild("MutationTabs")
		if old then
			old:Destroy()
		end
	end
	-- colonne à gauche de la fenêtre (Root est ancré au milieu de Window : la colonne dépasse à gauche)
	local tabs = Instance.new("Frame")
	tabs.Name = "MutationTabs"
	tabs.BackgroundTransparency = 1
	tabs.AnchorPoint = Vector2.new(1, 0)
	tabs.Position = UDim2.fromScale(-0.012, 0.03)
	tabs.Size = UDim2.fromScale(0.13, 0.94)
	tabs.Visible = false -- le code le montre en MUTATIONS
	tabs.ZIndex = 20
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Top
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 3)
	list.Parent = tabs
	for i, effect in EFFECTS do
		makeTab(model, effect, i).Parent = tabs
	end
	tabs.Parent = gui.Root

	local rewards = window.Rewards
	local caption = window:FindFirstChild("MutationCaption") or Instance.new("TextLabel")
	caption.Name = "MutationCaption"
	caption.AnchorPoint = rewards.AnchorPoint
	caption.Position = rewards.Position
	caption.Size = rewards.Size
	caption.BackgroundColor3 = rewards.BackgroundColor3
	caption.BackgroundTransparency = rewards.BackgroundTransparency
	caption.BorderSizePixel = 0
	caption.ZIndex = rewards.ZIndex + 2
	caption.Text = "Collect every item in SHINY!"
	caption.TextColor3 = Color3.new(1, 1, 1)
	caption.FontFace = window.Rewards.RewardsTitle.FontFace
	caption.TextScaled = false
	caption.TextWrapped = true
	caption.TextScaled = true
	caption.Visible = false -- le code la montre en MUTATIONS
	for _, c in caption:GetChildren() do
		c:Destroy()
	end
	local corner = rewards:FindFirstChildOfClass("UICorner")
	if corner then
		corner:Clone().Parent = caption
	end
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	stroke.Thickness = 0.12
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = caption
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.1, 0)
	pad.PaddingRight = UDim.new(0.1, 0)
	pad.PaddingTop = UDim.new(0.18, 0)
	pad.PaddingBottom = UDim.new(0.18, 0)
	pad.Parent = caption
	caption.Parent = window
end

if PREVIEW then
	local old = SG:FindFirstChild("_PREVIEW_CLAUDE_IndexMut")
	if old then
		old:Destroy()
	end
	local copy = SG.UI_Index_v3:Clone()
	copy.Name = "_PREVIEW_CLAUDE_IndexMut"
	copy.Archivable = false
	copy.Enabled = true
	apply(copy)
	local window = copy.Root.Window
	-- état MUTATIONS, comme le code le montrerait
	copy.Root.MutationTabs.Visible = true
	window.MutationCaption.Visible = true
	window.Rewards.Visible = false
	for _, b in copy.Root.Categories:GetChildren() do
		local sel = b:FindFirstChild("Selected")
		if sel then
			sel.Visible = b.Name == "MutationsButton"
		end
	end
	copy.Parent = SG
	return "aperçu posé"
end

local rec = CHS:TryBeginRecording("UI : onglets de mutation de l'index")
local ok, err = pcall(function()
	local backups = SS.MapBackups:FindFirstChild("2026-11-24_OngletsMutations")
	if not backups then
		backups = Instance.new("Folder")
		backups.Name = "2026-11-24_OngletsMutations"
		backups.Parent = SS.MapBackups
	end
	if not backups:FindFirstChild("UI_Index_v3") then
		SG.UI_Index_v3:Clone().Parent = backups
	end
	apply(SG.UI_Index_v3)
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "UI_Index_v3 : MutationTabs et MutationCaption"
