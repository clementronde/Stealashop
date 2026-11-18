--!nonstrict
-- ui_grande_hud.luau (Clément, 2026-11-18 : « UI plus grande », d'après la vidéo de référence E, fiches
-- StealAShop-Art/References/Videos_Jeux/2026-11-18_Reference_E_analyse_*) : à lancer en Edit.
--   - LeftRail (colonne de gauche sur PC) : boutons carrés de 9,9 % de la hauteur de l'écran (leur mesure), au lieu
--     des pilules de 8,8 %, au moins 44 px sur un petit écran. Écart de 3,5 % (Clément, 18/11 : « plus écartés » ;
--     la référence en a 1,6 %, mais notre mot posé sur le contour du bas mange déjà 1,3 % de l'écart).
--   - LeftRailTouch (colonne du téléphone) : même écart, en proportion du bouton.
--   - LeftRail et LeftRailTouch : icône centrée sur le bouton, mot à cheval sur le contour noir du bas (retour de
--     Clément du 18/11). RightRail.DisplayedButton : l'icône grandit et dépasse un peu du haut.
--   - Rien d'autre : l'argent, la vitesse, la force, le minuteur de nuit et la barre du bas sont déjà aussi grands
--     ou plus grands que chez eux (mesuré, voir la liaison).
-- Aucun nom changé, aucun script. Sauvegarde : ServerStorage/MapBackups/2026-11-18_UIGrande/UI_HUD. Annulable.

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")

local BTN = 0.099 -- hauteur d'un bouton, en fraction de la hauteur de l'écran
local GAP = 0.035 -- écart entre deux boutons (le mot du bouton du dessus en déborde de 1,3 %)
local MIN_PX = 44 -- règle du téléphone

local ICON_SIZE, ICON_POS = UDim2.fromScale(0.8, 0.8), UDim2.fromScale(0.1, -0.1)
local LABEL_SIZE, LABEL_POS = UDim2.fromScale(0.94, 0.24), UDim2.fromScale(0.03, 0.69)
local ALERT_SIZE, ALERT_POS = UDim2.fromScale(0.39, 0.39), UDim2.fromScale(0.946, 0.054)
-- Boutons de gauche (retour de Clément, 2026-11-18) : icône centrée sur le bouton, mot posé à cheval sur le contour
-- noir du bas (son milieu sur le bord), jamais plus large que le bouton.
local LEFT_ICON_SIZE, LEFT_ICON_POS = UDim2.fromScale(0.82, 0.82), UDim2.fromScale(0.09, 0.09)
local LEFT_LABEL_SIZE, LEFT_LABEL_POS = UDim2.fromScale(0.94, 0.26), UDim2.fromScale(0.5, 1)

local function child(o, class)
	for _, c in o:GetChildren() do
		if c:IsA(class) then
			return c
		end
	end
	return nil
end

-- Dessin carré : icône qui dépasse en haut et mot dessous (DisplayedButton), ou icône centrée et mot sur le contour
-- du bas (boutons de gauche) ; pastille en débord sur le coin haut droit.
local function squareInside(button, left)
	local icon, label = button:FindFirstChild("Icon"), button:FindFirstChild("Label")
	if icon then
		icon.AnchorPoint = Vector2.zero
		icon.Size, icon.Position = if left then LEFT_ICON_SIZE else ICON_SIZE, if left then LEFT_ICON_POS else ICON_POS
	end
	if label then
		label.AnchorPoint = if left then Vector2.new(0.5, 0.5) else Vector2.zero
		label.Size, label.Position = if left then LEFT_LABEL_SIZE else LABEL_SIZE, if left then LEFT_LABEL_POS else LABEL_POS
		label.TextXAlignment = Enum.TextXAlignment.Center -- les pilules de LeftRail étaient alignées à gauche
	end
	for _, c in button:GetChildren() do
		if c:IsA("Frame") and c.Name:match("Alert$") then
			c.Size, c.Position = ALERT_SIZE, ALERT_POS
		end
	end
end

local rec = CHS:TryBeginRecording("UI : HUD plus grand (boutons carrés de 9,9 %)")
local report = {}
local ok, err = pcall(function()
	local hud = SG.UI_HUD
	local backups = SS.MapBackups:FindFirstChild("2026-11-18_UIGrande")
	if not backups then
		backups = Instance.new("Folder")
		backups.Name = "2026-11-18_UIGrande"
		backups.Parent = SS.MapBackups
	end
	if not backups:FindFirstChild("UI_HUD") then
		hud:Clone().Parent = backups
	end

	-- 1. LeftRail en colonne de carrés.
	local rail = hud.LeftRail
	local buttons = {}
	for _, c in rail:GetChildren() do
		if c:IsA("GuiButton") then
			table.insert(buttons, c)
		end
	end
	local n = #buttons
	local railH = n * BTN + (n - 1) * GAP
	local ratio = BTN / railH
	rail.Size = UDim2.fromScale(0.3, railH) -- la largeur suit la hauteur (rapport ci-dessous)
	local ar = child(rail, "UIAspectRatioConstraint")
	ar.AspectRatio = ratio
	ar.AspectType = Enum.AspectType.FitWithinMaxSize
	child(rail, "UIListLayout").Padding = UDim.new(GAP / railH, 0)
	local sc = child(rail, "UISizeConstraint") or Instance.new("UISizeConstraint")
	sc.MinSize = Vector2.new(MIN_PX, MIN_PX / ratio)
	sc.Parent = rail
	for _, b in buttons do
		b.Size = UDim2.fromScale(1, BTN / railH)
		child(b, "UIAspectRatioConstraint").AspectRatio = 1
		squareInside(b, true)
	end
	table.insert(report, string.format("LeftRail : %d carrés, colonne de %.1f %% de haut", n, railH * 100))

	-- 2. Même dessin et même écart (en proportion du bouton) dans la colonne du téléphone ; sa taille de cadre ne
	-- change pas : sur un téléphone de 332 px de haut, les boutons passent de 55 à 50 px pour rester au-dessus des stats.
	local touch = hud.LeftRailTouch
	local tButtons = {}
	for _, c in touch:GetChildren() do
		if c:IsA("GuiButton") then
			table.insert(tButtons, c)
		end
	end
	local gapB = GAP / BTN -- écart en hauteur de bouton
	local units = #tButtons + (#tButtons - 1) * gapB
	child(touch, "UIAspectRatioConstraint").AspectRatio = 1 / units
	child(touch, "UIListLayout").Padding = UDim.new(gapB / units, 0)
	for _, c in tButtons do
		c.Size = UDim2.fromScale(1, 1 / units)
		squareInside(c, true)
	end
	squareInside(hud.RightRail.DisplayedButton, false)
	table.insert(report, "LeftRailTouch pareil ; DisplayedButton : icône qui dépasse")
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return table.concat(report, " ; ")
