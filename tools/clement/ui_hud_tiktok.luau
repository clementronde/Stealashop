-- ui_hud_tiktok.luau — effets d'après la vidéo TikTok du 2026-11-21 (Clément)
-- Fiche : docs/claude/notes/ui-reference-tiktok-2026-11-21.md (sections 5, 7 et 8).
-- À exécuter dans Studio (barre de commande ou MCP execute_luau), en mode Edit.
-- Rejouable : la sauvegarde n'est faite qu'une fois ; les couches déjà posées sont remises à jour.
--
-- Rien n'est renommé, rien ne change à l'image tant que le code d'Ironix ne joue pas les effets :
-- 1. Copie de UI_HUD dans ServerStorage/MapBackups/2026-11-21_HUD_TikTok (une seule fois).
-- 2. Pour chaque bouton de LeftRail, LeftRailTouch et RightRail/DisplayedButton :
--    - Label/UIStroke passe en blanc et reçoit un UIGradient « Gleam » qui porte l'ancienne couleur du
--      contour partout, sauf une bande blanche au milieu. Au repos (Offset -0,7), la bande est hors du
--      texte : le contour garde exactement sa couleur. Le code fera défiler Offset.X de -0,7 à 0,7
--      en 0,8 s, puis 1,9 s de pause, en boucle (fiche, demande 4).
--      Pour changer ensuite la couleur d'un contour : changer les couleurs de Gleam, pas UIStroke.Color.
--    - Attribut IconHover = "Jump" sur le bouton (fiche, demande 2) : l'icône saute au survol quand le
--      code le lira. Mettre "Lean" à la main pour une icône qui s'incline au lieu de sauter.
--
-- REVERT = true : enlève les Gleam, remet la couleur d'origine des contours et enlève IconHover.

local REVERT = false

local ServerStorage = game:GetService("ServerStorage")
local StarterGui = game:GetService("StarterGui")

local BACKUP_NAME = "2026-11-21_HUD_TikTok"
local GLEAM = "Gleam"
local ICON_HOVER = "IconHover"
local ICON_EFFECT = "Jump"
local REST_OFFSET = Vector2.new(-0.7, 0) -- bande hors du texte (fiche, section 5)
local HALF_WIDTH = 0.06 -- demi-largeur de la bande : ≈ 12 % du label en tout
local ROTATION = 15 -- bande légèrement penchée
local WHITE = Color3.new(1, 1, 1)

local BUTTONS = {
	{ "LeftRail", "RobuxShopButton" },
	{ "LeftRail", "IndexButton" },
	{ "LeftRail", "SkillTreeButton" },
	{ "LeftRailTouch", "RobuxShopButton" },
	{ "LeftRailTouch", "IndexButton" },
	{ "LeftRailTouch", "SkillTreeButton" },
	{ "RightRail", "DisplayedButton" },
}

local hud = StarterGui:FindFirstChild("UI_HUD")
assert(hud, "UI_HUD introuvable dans StarterGui")
local backups = ServerStorage:FindFirstChild("MapBackups")
assert(backups, "ServerStorage/MapBackups introuvable")

-- 1. Sauvegarde (une seule fois, avant le premier changement)
if not backups:FindFirstChild(BACKUP_NAME) then
	local folder = Instance.new("Folder")
	folder.Name = BACKUP_NAME
	hud:Clone().Parent = folder
	folder.Parent = backups
end

local function gleamColors(base: Color3): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, base),
		ColorSequenceKeypoint.new(0.5 - HALF_WIDTH, base),
		ColorSequenceKeypoint.new(0.5, WHITE),
		ColorSequenceKeypoint.new(0.5 + HALF_WIDTH, base),
		ColorSequenceKeypoint.new(1, base),
	})
end

local report = {}

for _, path in BUTTONS do
	local rail = hud:FindFirstChild(path[1])
	local button = rail and rail:FindFirstChild(path[2])
	local label = button and button:FindFirstChild("Label")
	local stroke = label and label:FindFirstChildOfClass("UIStroke")
	if not stroke then
		table.insert(report, path[1] .. "/" .. path[2] .. " : pas de Label/UIStroke, ignoré")
		continue
	end
	local gleam = stroke:FindFirstChild(GLEAM)
	-- Couleur d'origine du contour : celle que porte Gleam s'il existe déjà (le contour est alors blanc)
	local base = if gleam and gleam:IsA("UIGradient") then gleam.Color.Keypoints[1].Value else stroke.Color

	if REVERT then
		stroke.Color = base
		if gleam then
			gleam:Destroy()
		end
		button:SetAttribute(ICON_HOVER, nil)
		table.insert(report, path[1] .. "/" .. path[2] .. " : remis comme avant")
		continue
	end

	if not (gleam and gleam:IsA("UIGradient")) then
		if gleam then
			gleam:Destroy()
		end
		gleam = Instance.new("UIGradient")
		gleam.Name = GLEAM
	end
	gleam.Color = gleamColors(base)
	gleam.Transparency = NumberSequence.new(0)
	gleam.Rotation = ROTATION
	gleam.Offset = REST_OFFSET
	gleam.Enabled = true
	gleam.Parent = stroke
	stroke.Color = WHITE
	button:SetAttribute(ICON_HOVER, ICON_EFFECT)
	table.insert(report, string.format("%s/%s : Gleam posé (contour %s), IconHover = %s",
		path[1], path[2], tostring(base), ICON_EFFECT))
end

return table.concat(report, "\n")
