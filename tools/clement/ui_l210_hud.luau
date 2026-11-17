--!nonstrict
-- ui_l210_hud.luau (retours du test de Clément du 2026-11-16, L-210) : UI_HUD.
--   - Argent, vitesse et force en bas à gauche plus grands (référence : 4 à 4,5 % de la hauteur d'écran pour l'argent et
--     la vitesse). BottomLeft 0,32 × 0,36 de l'écran (au lieu de 0,32 × 0,30), StatsPanel 66 % de BottomLeft, au moins
--     200 × 92 px (téléphone) ; lignes Strength 26 %, Speed 31 %, Cash 36 % ; boîtes de texte plus larges (Cash 38 %,
--     Speed 50 %, Strength 22 % de la ligne). Sur PC (1920 × 1022) : argent 64 px, vitesse 61, force 49 (avant 57, 43,
--     29) ; téléphone (844 × 332) : 27, 23, 18 (avant 25, 19, 13).
--   - Bouton « Displays » (RightRail.DisplayedButton) : l'icône du diamant rouge sur son présentoir, celle de la carte
--     « +4 Displays » de la boutique (UI_Icon_GP_Displays).
--   - MenuButton, MenuAlert, MenuArea et MenuPanel : déjà retirés (refonte_ui_hud_v3.luau, L-189).
-- Aucun nom ne change. Sauvegarde dans ServerStorage/MapBackups/2026-11-16_L210/UI_HUD. Annulable. Aucun script.

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")
local Icons = game:GetService("ReplicatedStorage").Assets.Icons

local hud = SG.UI_HUD

local function backup(screen)
	local folder = SS.MapBackups:FindFirstChild("2026-11-16_L210")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "2026-11-16_L210"
		folder.Parent = SS.MapBackups
	end
	if not folder:FindFirstChild(screen.Name) then
		local copy = screen:Clone()
		copy.Enabled = false
		copy.Parent = folder
	end
end

local rec = CHS:TryBeginRecording("UI : HUD, chiffres plus grands et icône Displays (L-210)")
local ok, err = pcall(function()
	backup(hud)

	local bl = hud.BottomLeft
	bl.Size = UDim2.fromScale(0.32, 0.36)
	local sp = bl.StatsPanel
	sp.Size = UDim2.fromScale(1, 0.66)
	local limits = sp:FindFirstChildOfClass("UISizeConstraint")
	if limits then
		limits.MinSize = Vector2.new(200, 92)
	end
	bl.BottomRow.Size = UDim2.fromScale(1, 0.11)
	sp.StrengthDamageRow.Size = UDim2.fromScale(1, 0.26)
	sp.SpeedRow.Size = UDim2.fromScale(1, 0.31)
	sp.CashRow.Size = UDim2.fromScale(1, 0.36)
	local function width(label, x)
		label.Size = UDim2.fromScale(x, label.Size.Y.Scale)
	end
	width(sp.CashRow.Cash, 0.38)
	width(sp.CashRow.Income, 0.25)
	width(sp.SpeedRow.Speed, 0.5)
	width(sp.StrengthDamageRow.Strength, 0.22)

	local icon = hud.RightRail.DisplayedButton.Icon
	icon.Image = Icons.UI_Icon_GP_Displays.Texture
	icon:SetAttribute("IconAsset", "UI_Icon_GP_Displays")
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "UI_HUD : chiffres plus grands, icône Displays"
