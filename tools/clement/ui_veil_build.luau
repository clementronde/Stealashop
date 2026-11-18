--!nonstrict
-- ui_veil_build.luau (Clément, 2026-11-19 : « (a) et (b) », d'après la vidéo de référence E) : à lancer en Edit.
-- Crée l'écran UI_Veil : le voile noir que le code allume derrière une fenêtre centrale ouverte (boutiques, index,
-- arbre de compétences, réglages…). Le monde et le HUD passent à 62 % de luminosité, comme chez eux.
--   - UI_Veil (ScreenGui, éteint) > Veil (Frame plein écran, noir, transparence 0,62 = 38 % d'opacité).
--   - Le code l'allume, fait passer Veil.BackgroundTransparency de 1 à 0,62 en 0,2 s, et pose le DisplayOrder de
--     UI_Veil juste sous celui de la fenêtre ouverte (liaison L-257).
--   - Les fenêtres centrales passent au-dessus de UI_Hotbar (DisplayOrder 5) pour que le voile couvre aussi la
--     barre du bas : ici la boutique Robux (6 → 7) ; les autres à mesure qu'on les refait.
-- Aucun script. Annulable.

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")

local VEIL_TRANSPARENCY = 0.62 -- 38 % de noir : × 0,62 de luminosité (mesuré sur la vidéo E)

local rec = CHS:TryBeginRecording("UI : voile UI_Veil derrière les fenêtres")
local ok, err = pcall(function()
	local gui = SG:FindFirstChild("UI_Veil") or Instance.new("ScreenGui")
	gui.Name = "UI_Veil"
	gui.Enabled = false
	gui.IgnoreGuiInset = true -- couvre aussi la bande des boutons Roblox
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 6 -- valeur de départ ; le code la recalcule pour chaque fenêtre
	local veil = gui:FindFirstChild("Veil") or Instance.new("Frame")
	veil.Name = "Veil"
	veil.Size = UDim2.fromScale(1, 1)
	veil.Position = UDim2.fromScale(0, 0)
	veil.BackgroundColor3 = Color3.new(0, 0, 0)
	veil.BackgroundTransparency = VEIL_TRANSPARENCY
	veil.BorderSizePixel = 0
	veil.Active = true -- prend les clics : on ne clique pas le HUD à travers le voile
	veil.Parent = gui
	gui.Parent = SG

	SG.UI_RobuxShop_v2.DisplayOrder = 7 -- au-dessus du voile (6) et de UI_Hotbar (5)
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "UI_Veil créé (éteint), boutique Robux à DisplayOrder 7"
