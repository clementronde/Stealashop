--!nonstrict
-- ui_hud_display_centre.luau (Clément, 2026-11-24, relayé par le chef UI : « remettre » le bouton Display centré
-- verticalement, à la hauteur des boutons de la barre de gauche) : à lancer en Edit.
-- UI_HUD.RightRail devient le miroir de LeftRail : même taille et même rapport (UIAspectRatioConstraint copié), à la
-- même distance du bord droit que LeftRail du bord gauche, centré verticalement sur l'écran. DisplayedButton est au
-- centre de RightRail, donc de l'écran : carré, 1,565 fois la hauteur d'un bouton de LeftRail (sa taille d'origine). SpeedBoostButton et
-- SleepButton (cachés, montrés en situation par le code) passent juste dessous, à la taille des boutons de LeftRail.
-- Sur téléphone, le code montre LeftRailTouch à la place de LeftRail : nouveau cadre RightRailTouch (caché), miroir
-- de LeftRailTouch, avec les mêmes trois boutons à la taille de ceux de LeftRailTouch. Il faut que le code le montre
-- et cache RightRail sur téléphone, comme pour LeftRail (liaison). Aucun nom existant changé, aucun script.
-- PREVIEW = true : rien ne change ; une copie du HUD est posée dans StarterGui (_PREVIEW_CLAUDE_Hud, non archivable,
-- à détruire). PREVIEW = false : le HUD change (sauvegarde ServerStorage/MapBackups/2026-11-24_HudDisplay).

local PREVIEW = false

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")

local BOOSTS = { "SpeedBoostButton", "SleepButton" }
local GAP = 0.05 -- écart entre Display et le bouton de situation, en part de la hauteur du cadre
-- Clément (25/11) : « le display doit être carré », puis « plus gros bouton » : sur PC, le carré reprend sa taille
-- d'origine, 1,565 fois la hauteur d'un bouton de LeftRail (139 px en 1920 × 1022) ; sur téléphone, la hauteur exacte
-- d'un bouton de LeftRailTouch (rien ne change)
local PC_SCALE = 1.565

local function ratio(frame)
	local ar = frame:FindFirstChildOfClass("UIAspectRatioConstraint")
	assert(ar, frame.Name .. " sans UIAspectRatioConstraint")
	return ar
end

-- même taille, même rapport, à la même distance du bord que la colonne de gauche, centré verticalement
local function mirror(rail, left)
	rail.Size = left.Size
	rail.AnchorPoint = Vector2.new(1, 0.5)
	rail.Position = UDim2.new(1 - left.Position.X.Scale, -left.Position.X.Offset, 0.5, 0)
	local src = ratio(left)
	local ar = rail:FindFirstChildOfClass("UIAspectRatioConstraint") or Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = src.AspectRatio
	ar.DominantAxis = src.DominantAxis
	ar.AspectType = src.AspectType
	ar.Parent = rail
	local sc = rail:FindFirstChildOfClass("UISizeConstraint")
	if sc and not left:FindFirstChildOfClass("UISizeConstraint") then
		sc:Destroy()
	end
end

-- Display au centre du cadre, haut comme le bouton de référence de la colonne de gauche ; les boutons de situation
-- dessous, à la taille du bouton de référence
local function place(rail, ref, scale)
	local railRatio = ratio(rail).AspectRatio -- largeur / hauteur du cadre
	local refRatio = ratio(ref).AspectRatio -- largeur / hauteur du bouton de référence
	-- hauteur du bouton de référence en part de la hauteur du cadre : sa boîte (1 × Size.Y) réduite par son rapport
	local refH = math.min(ref.Size.Y.Scale, railRatio / refRatio)
	local h = refH * (scale or 1)
	local display = rail.DisplayedButton
	display.AnchorPoint = Vector2.new(1, 0.5)
	display.Position = UDim2.fromScale(1, 0.5)
	-- sa boîte fait toute la largeur et refH de haut : son rapport (0,92, plus étroit) le borne par la hauteur
	display.Size = UDim2.fromScale(1, h)
	for _, name in BOOSTS do
		local b = rail:FindFirstChild(name)
		if b then
			b.AnchorPoint = Vector2.new(1, 0)
			b.Position = UDim2.fromScale(1, 0.5 + h / 2 + GAP)
			b.Size = UDim2.fromScale(1, ref.Size.Y.Scale)
		end
	end
	return refH
end

local function apply(hud)
	local right = hud.RightRail
	mirror(right, hud.LeftRail)
	local hPc = place(right, hud.LeftRail.RobuxShopButton, PC_SCALE)
	-- téléphone : copie miroir de LeftRailTouch
	local touch = hud:FindFirstChild("RightRailTouch")
	if touch then
		touch:Destroy()
	end
	local was = right.Archivable
	right.Archivable = true
	touch = right:Clone()
	right.Archivable = was
	touch.Name = "RightRailTouch"
	touch.Visible = false -- le code le montre sur téléphone, à la place de RightRail
	touch.Parent = hud
	mirror(touch, hud.LeftRailTouch)
	local hTouch = place(touch, hud.LeftRailTouch.RobuxShopButton)
	return hPc, hTouch
end

if PREVIEW then
	local old = SG:FindFirstChild("_PREVIEW_CLAUDE_Hud")
	if old then
		old:Destroy()
	end
	local src = SG.UI_HUD
	local was = src.Archivable
	src.Archivable = true
	local copy = src:Clone()
	src.Archivable = was
	copy.Name = "_PREVIEW_CLAUDE_Hud"
	copy.Archivable = false
	copy.DisplayOrder = 200
	local a, b = apply(copy)
	copy.Parent = SG
	return string.format("aperçu posé (hauteur de Display en part du cadre : PC %.4f, téléphone %.4f)", a, b)
end

local rec = CHS:TryBeginRecording("UI : bouton Display centré, à la hauteur des boutons de gauche (RightRail miroir de LeftRail)")
local ok, err = pcall(function()
	local backups = SS.MapBackups:FindFirstChild("2026-11-24_HudDisplay")
	if not backups then
		backups = Instance.new("Folder")
		backups.Name = "2026-11-24_HudDisplay"
		backups.Parent = SS.MapBackups
	end
	if not backups:FindFirstChild("UI_HUD") then
		SG.UI_HUD:Clone().Parent = backups
	end
	apply(SG.UI_HUD)
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "UI_HUD : RightRail miroir de LeftRail, RightRailTouch miroir de LeftRailTouch, Display centré"
