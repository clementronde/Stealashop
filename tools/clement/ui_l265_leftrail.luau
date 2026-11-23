-- ui_l265_leftrail.luau — L-265 (Clément, 2026-11-20)
-- Barre de gauche : grands rectangles sur PC (LeftRail d'avant L-256), petits carrés
-- seulement sur téléphone (LeftRailTouch, inchangé). Le code montre déjà l'une ou l'autre.
-- À exécuter dans Studio (barre de commande ou MCP execute_luau), en mode Edit.
-- Rejouable : la copie de sauvegarde n'est faite qu'une fois.
--
-- 1. Copie de UI_HUD dans ServerStorage/MapBackups/2026-11-20_HUD_L265.
-- 2. Remplace StarterGui/UI_HUD/LeftRail par la copie de
--    ServerStorage/MapBackups/2026-11-18_UIGrande/UI_HUD/LeftRail
--    (mêmes noms : RobuxShopButton, SkillTreeButton, IndexButton, SkillTreeAlert, IndexAlert).

local ServerStorage = game:GetService("ServerStorage")
local StarterGui = game:GetService("StarterGui")

local hud = StarterGui:FindFirstChild("UI_HUD")
assert(hud, "UI_HUD introuvable dans StarterGui")
local backups = ServerStorage:FindFirstChild("MapBackups")
assert(backups, "ServerStorage/MapBackups introuvable")

-- 1. Sauvegarde (une seule fois)
local BACKUP_NAME = "2026-11-20_HUD_L265"
if not backups:FindFirstChild(BACKUP_NAME) then
	local folder = Instance.new("Folder")
	folder.Name = BACKUP_NAME
	local copy = hud:Clone()
	copy.Parent = folder
	folder.Parent = backups
end

-- 2. Remise du LeftRail d'avant L-256
local source = backups:FindFirstChild("2026-11-18_UIGrande")
source = source and source:FindFirstChild("UI_HUD")
source = source and source:FindFirstChild("LeftRail")
assert(source, "MapBackups/2026-11-18_UIGrande/UI_HUD/LeftRail introuvable")

-- Les noms lus par le code doivent être présents dans la copie
for _, name in { "RobuxShopButton", "SkillTreeButton", "IndexButton" } do
	assert(source:FindFirstChild(name), "Bouton manquant dans la copie : " .. name)
end
assert(source.SkillTreeButton:FindFirstChild("SkillTreeAlert"), "SkillTreeAlert manquant")
assert(source.IndexButton:FindFirstChild("IndexAlert"), "IndexAlert manquant")

local current = hud:FindFirstChild("LeftRail")
local fresh = source:Clone()
fresh.Name = "LeftRail"
if current then
	-- Garde l'ordre d'affichage actuel
	fresh.ZIndex = current.ZIndex
	fresh.LayoutOrder = current.LayoutOrder
	current:Destroy()
end
fresh.Parent = hud

-- 3. Icône du bouton Displays (RightRail.DisplayedButton) centrée sur le bouton,
--    comme les autres (avant : AnchorPoint 0,0 ; Position 0.1,-0.1, soit 12 px trop haut).
local displayed = hud:FindFirstChild("RightRail") and hud.RightRail:FindFirstChild("DisplayedButton")
local icon = displayed and displayed:FindFirstChild("Icon")
assert(icon, "UI_HUD/RightRail/DisplayedButton/Icon introuvable")
icon.AnchorPoint = Vector2.new(0.5, 0.5)
icon.Position = UDim2.fromScale(0.5, 0.5)

-- Contrôle : aucun script dans l'UI
for _, d in hud:GetDescendants() do
	assert(not d:IsA("LuaSourceContainer"), "Script trouvé dans UI_HUD : " .. d:GetFullName())
end

return "L-265 : LeftRail remis (" .. #fresh:GetChildren() .. " enfants), LeftRailTouch inchangé"
