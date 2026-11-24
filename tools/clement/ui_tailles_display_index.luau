--!nonstrict
-- ui_tailles_display_index.luau (Clément, 2026-11-24, après une session de jeu : « le display est énorme, faire comme
-- sur Figma, que tout soit moins gros ; l'index fait beaucoup trop petit, il n'est pas centré ; le shop est de la
-- bonne taille ») : à lancer en Edit.
--   - UI_Displayed.Dock reprend les proportions de la maquette Figma (page « 20 Index et Exposés », frames 106:1279
--     et 106:2677) : Panel de 402 × 620 sur 1920 × 1080 (Dock = Panel / 0,9 en largeur), bord droit à 20 px, haut à
--     180 px ; sur téléphone 844 × 390, Dock de 393 × 245 au moins (3 lignes entières).
--   - UI_Index_v3.Root grandit comme la boutique Robux (80 % de la hauteur) et sa fenêtre est centrée sur l'écran :
--     l'ancre tombe au milieu de Window (les onglets Categories dépassent à droite), au lieu du milieu du bloc.
-- Aucun nom changé, aucun script. Sauvegarde : ServerStorage/MapBackups/2026-11-24_Tailles. Annulable.

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")

local function constraint(gui, class)
	local c = gui:FindFirstChildOfClass(class) or Instance.new(class)
	c.Parent = gui
	return c
end

-- Lignes de la liste (Figma : 6 lignes sur PC, 3 sur téléphone) : hauteur 1/6 de la liste, au moins 46 px (boutons de
-- 44 px). La liste commence sous l'en-tête (44 px au moins) et finit au-dessus de DISPLAY BEST (44 px au moins) ; le
-- bas du Dock sur téléphone est réglé pour 3 lignes entières (3 × 46 + 2 × 4 = 146 px de liste). Vérifié : 6 lignes
-- entières en 1920 × 1080, 1920 × 1022 et 1366 × 768, 3 sur téléphone (844 × 390).
local ROWS, GAP, ROW_MIN = 6, 4, 46
local LIST_Y, LIST_TOP, LIST_H, LIST_OFF = 0.085, 26, 0.765, -41

local function applyDisplayed(dock, scale)
	scale = scale or 1 -- aperçu réduit seulement : les tailles en pixels suivent l'écran d'aperçu
	dock.AnchorPoint = Vector2.new(1, 0.5)
	dock.Size = UDim2.fromScale(447 / 1920, 620 / 1080)
	dock.Position = UDim2.new(1, -20 * scale, (180 + 310) / 1080, 0)
	local sc = constraint(dock, "UISizeConstraint")
	local listMin = ROWS / 2 * ROW_MIN + (ROWS / 2 - 1) * GAP -- 3 lignes entières sur téléphone
	sc.MinSize = Vector2.new(math.floor(354 / 0.9), math.ceil((listMin - LIST_OFF) / LIST_H)) * scale
	sc.MaxSize = Vector2.new(620, 860)

	-- en-tête : le compteur ne passe plus sous la croix
	local header = dock.Panel.Header
	header.Title.Position = UDim2.fromScale(0.17, 0.5)
	header.Title.Size = UDim2.fromScale(0.45, 0.62)
	header.DisplayCount.AnchorPoint = Vector2.new(1, 0.5)
	header.DisplayCount.Position = UDim2.fromScale(0.86, 0.5)
	header.DisplayCount.Size = UDim2.fromScale(0.21, 0.6)

	-- la liste entre l'en-tête et DISPLAY BEST, la barre de défilement à côté
	local list = dock.Panel.List
	list.Position = UDim2.new(list.Position.X.Scale, list.Position.X.Offset, LIST_Y, LIST_TOP)
	list.Size = UDim2.new(list.Size.X.Scale, list.Size.X.Offset, LIST_H, LIST_OFF)
	local track = dock.Panel:FindFirstChild("ScrollTrack")
	if track then
		track.Position = UDim2.new(track.Position.X.Scale, track.Position.X.Offset, LIST_Y, LIST_TOP + 4)
		track.Size = UDim2.new(track.Size.X.Scale, track.Size.X.Offset, LIST_H, LIST_OFF - 8)
	end

	-- lignes basses : vignette carrée, textes qui prennent la place libre, deux boutons côte à côte
	constraint(list, "UIListLayout").Padding = UDim.new(0, GAP)
	local tpl = list.Template
	tpl.Size = UDim2.new(0.96, 0, 1 / ROWS, -math.ceil(GAP * (ROWS - 1) / ROWS))
	local min = tpl:FindFirstChild("PhoneMin")
	if min then
		min.MinSize = Vector2.new(0, ROW_MIN * scale)
	end
	local row = constraint(tpl, "UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Padding = UDim.new(0.02, 0)
	local pad = constraint(tpl, "UIPadding")
	pad.PaddingLeft = UDim.new(0.015, 0)
	pad.PaddingRight = UDim.new(0.015, 0)
	tpl.IconSlot.LayoutOrder = 1
	tpl.IconSlot.Size = UDim2.fromScale(0.2, 0.84)
	local info = tpl.Info
	info.LayoutOrder = 2
	info.Size = UDim2.fromScale(0.3, 0.9)
	constraint(info, "UIFlexItem").FlexMode = Enum.UIFlexMode.Fill
	-- textes plus hauts dans la ligne basse : rareté, nom, revenu
	info.RarityChip.Position = UDim2.fromScale(0, 0.06)
	info.RarityChip.Size = UDim2.fromScale(1, 0.22)
	info.ItemName.Position = UDim2.fromScale(0, 0.3)
	info.ItemName.Size = UDim2.fromScale(1, 0.34)
	info.Income.Position = UDim2.fromScale(0, 0.66)
	info.Income.Size = UDim2.fromScale(1, 0.28)
	local buttons = tpl.Buttons
	buttons.LayoutOrder = 3
	buttons.Size = UDim2.fromScale(0.37, 0.86)
	for _, n in { "RemoveButton", "DisplayButton" } do
		buttons[n].Position = UDim2.fromScale(0, 0)
		buttons[n].Size = UDim2.fromScale(0.485, 1)
	end
	buttons.SellButton.Position = UDim2.fromScale(0.515, 0)
	buttons.SellButton.Size = UDim2.fromScale(0.485, 1)
end

local function applyIndex(root)
	local window = root.Window
	local centre = window.Position.X.Scale + window.Size.X.Scale / 2 -- milieu de la fenêtre dans Root
	root.AnchorPoint = Vector2.new(centre, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromScale(0.84, 0.8)
	local ar = constraint(root, "UIAspectRatioConstraint")
	ar.AspectType = Enum.AspectType.FitWithinMaxSize
	local sc = constraint(root, "UISizeConstraint")
	sc.MaxSize = Vector2.new(1640, 805)
end

local rec = CHS:TryBeginRecording("UI : tailles du Display (Figma) et de l'Index (comme le Shop, centré)")
local ok, err = pcall(function()
	local backups = SS.MapBackups:FindFirstChild("2026-11-24_Tailles")
	if not backups then
		backups = Instance.new("Folder")
		backups.Name = "2026-11-24_Tailles"
		backups.Parent = SS.MapBackups
	end
	for _, n in { "UI_Displayed", "UI_Index_v3" } do
		if not backups:FindFirstChild(n) then
			SG[n]:Clone().Parent = backups
		end
	end
	applyDisplayed(SG.UI_Displayed.Dock)
	applyIndex(SG.UI_Index_v3.Root)
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "UI_Displayed et UI_Index_v3 : nouvelles tailles"
