--!nonstrict
-- ui_tas_displayed.luau (demande de Clément du 2026-11-17, d'après Throw a Seed, note section 5) : UI_Displayed devient
-- le grand panneau collé à droite de leur « Mes plantes ».
--   - Dock : 36 % × 64 % de l'écran (le panneau seul fait 31 % × 63 % sur PC, comme chez eux), au moins 340 × 300 px
--     (téléphone), au plus 720 × 820. Plus de rapport fixe : le panneau s'allonge selon l'écran ; ce qui doit rester
--     carré (onglet de fermeture, vignettes, icône du compteur) a son propre UIAspectRatioConstraint.
--   - Onglet de fermeture (CloseButton, flèche « > ») : carré, collé au bord gauche du panneau, en haut.
--   - Toujours des lignes entières (jamais une ligne coupée) : 2 objets exposés visibles, 1 ligne d'inventaire, le reste
--     défile. Une ligne fait 12 % de l'écran sur PC, 53 px sur téléphone.
--   - Une ligne = vignette carrée (IconSlot, qui contient IconBack et Icon), textes (Info : ItemName, RarityChip,
--     Income), bouton à droite (REMOVE ou DISPLAY, au moins 44 px de haut sur téléphone, 68 au plus), rangés par un
--     UIListLayout horizontal : Info prend la place restante (UIFlexItem), rien ne se chevauche, même sur tablette.
--     Pas de deuxième bouton empilé : nous n'avons pas de « vendre » depuis ce panneau (rien d'inventé).
--   - DisplayBestButton pleine largeur dans le bas du panneau, 45 px sur téléphone, 72 au plus (centré dans sa place).
--   - Inventaire (Panel.Reserve) sous la liste des objets exposés, comme décidé par Clément le 2026-11-17.
--   - Tenons du panneau : tuiles de 30 px (le panneau change de forme selon l'écran, des tuiles en Scale s'étireraient).
-- Mêmes noms pour le code (Dock, Panel, List.Template, Reserve.ReserveList.Template, IconBack, Icon, ItemName,
-- RarityChip.RarityLabel, Income, RemoveButton, DisplayButton, CloseButton, DisplayBestButton, DisplayCount.CountLabel…) :
-- le code les cherche parmi les descendants (Contract/Find), les cadres IconSlot et Info ne gênent pas.
-- Le glissement (Appear = SlideRight) reste sur Dock : l'onglet est dans Dock, il part avec.
-- Sauvegarde : ServerStorage/MapBackups/2026-11-17_ThrowASeed/UI_Displayed_avantPanneau. Peut se relancer (valeurs
-- absolues), en Edit. Annulable. Aucun script.

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")

local TAB = 0.145 -- colonne de l'onglet, en fraction de la largeur de Dock
local PANEL_H = 0.985 -- hauteur du panneau (l'ombre dépasse de 1,5 % dessous)

local function ensure(parent, class, name)
	local x = parent:FindFirstChild(name)
	if x == nil or not x:IsA(class) then
		x = Instance.new(class)
		x.Name = name
		x.Parent = parent
	end
	return x
end
local function drop(parent, class)
	local x = parent:FindFirstChildOfClass(class)
	if x then
		x:Destroy()
	end
end
local function square(object)
	local ar = ensure(object, "UIAspectRatioConstraint", "UIAspectRatioConstraint")
	ar.AspectRatio = 1
	ar.AspectType = Enum.AspectType.FitWithinMaxSize
	ar.DominantAxis = Enum.DominantAxis.Width
end
local function capHeight(object, maxHeight)
	local c = ensure(object, "UISizeConstraint", "UISizeConstraint")
	c.MinSize = Vector2.new(0, 0)
	c.MaxSize = Vector2.new(10000, maxHeight)
end
local function place(object, ax, ay, px, py, sx, sy)
	object.AnchorPoint = Vector2.new(ax, ay)
	object.Position = UDim2.fromScale(px, py)
	object.Size = UDim2.fromScale(sx, sy)
end
local function holder(parent, name, z)
	local f = ensure(parent, "Frame", name)
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.ZIndex = z
	return f
end

-- Une ligne (List.Template ou ReserveList.Template).
local function row(template, buttonName)
	local layout = ensure(template, "UIListLayout", "UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.02, 0)
	local pad = ensure(template, "UIPadding", "UIPadding")
	pad.PaddingLeft = UDim.new(0.012, 0)
	pad.PaddingRight = UDim.new(0.015, 0)

	local z = template.ZIndex
	local slot = holder(template, "IconSlot", z + 1)
	slot.LayoutOrder = 1
	slot.Size = UDim2.fromScale(1, 0.88)
	square(slot)
	local back = template:FindFirstChild("IconBack", true)
	back.Parent = slot
	drop(back, "UIAspectRatioConstraint")
	place(back, 0.5, 0.5, 0.5, 0.54, 0.94, 0.94)
	local icon = template:FindFirstChild("Icon", true)
	icon.Parent = slot
	drop(icon, "UIAspectRatioConstraint")
	place(icon, 0.5, 0.5, 0.5, 0.47, 1.02, 1.02)

	local info = holder(template, "Info", z + 1)
	info.LayoutOrder = 2
	info.Size = UDim2.fromScale(0.45, 1)
	local flex = ensure(info, "UIFlexItem", "UIFlexItem")
	flex.FlexMode = Enum.UIFlexMode.Fill
	local name = template:FindFirstChild("ItemName", true)
	name.Parent = info
	local income = template:FindFirstChild("Income", true)
	income.Parent = info
	local chip = template:FindFirstChild("RarityChip", true)
	if chip then
		chip.Parent = info
		place(name, 0, 0, 0, 0.08, 1, 0.3)
		place(chip, 0, 0, 0, 0.42, 0.62, 0.2)
		place(income, 0, 0, 0, 0.66, 1, 0.27)
	else
		place(name, 0, 0, 0, 0.16, 1, 0.32)
		place(income, 0, 0, 0, 0.56, 1, 0.28)
	end

	local button = template:FindFirstChild(buttonName, true)
	button.LayoutOrder = 3
	place(button, 0, 0, 0, 0, 0.27, 0.86)
	capHeight(button, 68)
	local label = button:FindFirstChildOfClass("TextLabel")
	if label then
		place(label, 0, 0, 0.08, 0.25, 0.84, 0.42)
	end
end

local rec = CHS:TryBeginRecording("UI : panneau des objets exposés façon Throw a Seed")
local ok, err = pcall(function()
	local gui = SG.UI_Displayed
	local folder = SS.MapBackups["2026-11-17_ThrowASeed"]
	if not folder:FindFirstChild("UI_Displayed_avantPanneau") then
		local copy = gui:Clone()
		copy.Name = "UI_Displayed_avantPanneau"
		copy.Enabled = false
		copy.Parent = folder
	end

	local dock = gui.Dock
	drop(dock, "UIAspectRatioConstraint")
	dock.AnchorPoint = Vector2.new(1, 0.5)
	dock.Position = UDim2.new(1, -16, 0.5, 0)
	dock.Size = UDim2.fromScale(0.36, 0.64)
	local limits = ensure(dock, "UISizeConstraint", "UISizeConstraint")
	limits.MinSize = Vector2.new(340, 300)
	limits.MaxSize = Vector2.new(720, 820)

	-- Onglet de fermeture : carré, collé au panneau.
	local close = dock.CloseButton
	place(close, 1, 0, TAB - 0.008, 0, TAB - 0.008, 0.15)
	square(close)
	capHeight(close, 72)

	local panel = dock.Panel
	place(panel, 0, 0, TAB, 0, 1 - TAB, PANEL_H)
	local shadow = dock:FindFirstChild("PanelShadow")
	if shadow then
		place(shadow, 0, 0, TAB, 0.015, 1 - TAB, PANEL_H)
	end
	local studs = panel:FindFirstChild("Studs")
	if studs and studs:IsA("ImageLabel") then
		studs.TileSize = UDim2.fromOffset(30, 30)
	end

	-- Dans le panneau (fractions de sa hauteur) : en-tête 0-11 %, objets exposés 12,5-50,5 %, inventaire 52-78 %,
	-- place du bouton « Display best » 79-97,5 %.
	place(panel.Header, 0, 0, 0, 0, 1, 0.11)
	local countIcon = panel.Header:FindFirstChild("CountIcon", true)
	if countIcon then
		square(countIcon)
	end

	local list = panel.List
	place(list, 0, 0, 0.02, 0.125, 0.966, 0.38)
	drop(list.UIGridLayout, "UIAspectRatioConstraint")
	list.UIGridLayout.CellSize = UDim2.new(0.974, 0, 0.5, -3)
	row(list.Template, "RemoveButton")
	local track = panel:FindFirstChild("ScrollTrack")
	if track then
		place(track, 0, 0, 0.972, 0.135, 0.014, 0.36)
	end

	local reserve = panel.Reserve
	place(reserve, 0, 0, 0.02, 0.52, 0.96, 0.26)
	place(reserve.ReserveTitle, 0, 0, 0.018, 0.02, 0.3, 0.21)
	local count = reserve:FindFirstChild("ReserveCount")
	if count then
		place(count, 0, 0, 0.32, 0.02, 0.09, 0.21)
	end
	local reserveList = reserve.ReserveList
	place(reserveList, 0, 0, 0, 0.25, 1, 0.75)
	drop(reserveList.UIGridLayout, "UIAspectRatioConstraint")
	reserveList.UIGridLayout.CellSize = UDim2.new(0.968, 0, 1, 0)
	row(reserveList.Template, "DisplayButton")
	local empty = reserve:FindFirstChild("ReserveEmpty")
	if empty then
		place(empty, 0.5, 0.5, 0.5, 0.625, 0.86, 0.3)
	end

	-- « Display best » : centré dans sa place, en bas du panneau.
	local best = dock.DisplayBestButton
	local slotTop, slotBottom = 0.79 * PANEL_H, 0.975 * PANEL_H
	place(best, 0, 0.5, TAB + 0.02 * (1 - TAB), (slotTop + slotBottom) / 2, 0.96 * (1 - TAB), 0.152)
	capHeight(best, 72)
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "panneau des objets exposés façon Throw a Seed"
