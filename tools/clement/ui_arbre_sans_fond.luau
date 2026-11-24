--!nonstrict
-- ui_arbre_sans_fond.luau (Clément, 2026-11-24 : « on retire le fond et on fait comme les autres UI : flouter derrière
-- et retirer tous les autres boutons ») : à lancer en Edit.
--   - UI_SkillTree perd son fond plein écran (Backdrop : bleu nuit, halo Light et studs) : on voit le jeu flouté et le
--     voile UI_Veil derrière l'arbre, comme derrière les autres grandes fenêtres (le code d'Ironix le fait déjà pour
--     UI_SkillTree : Config/UiMotion, listes Windows et Central).
--   - DisplayOrder 5 → 7, comme les autres fenêtres centrales : à 5, l'arbre était à égalité avec UI_Hotbar (ordre
--     indéfini, la barre pouvait passer devant) ; le voile se met à 6 (fenêtre − 1).
--   - Attributs Blur = true et HideHud = true sur l'écran (lus par UiMotionController) : flou et HUD caché, même si
--     l'écran sortait un jour des listes du code.
-- Aucun nom lu par le code changé, aucun script. Sauvegarde : ServerStorage/MapBackups/2026-11-24_ArbreSansFond.
-- Annulable.

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")

local rec = CHS:TryBeginRecording("UI : arbre de compétences sans fond, flou derrière")
local ok, err = pcall(function()
	local gui = SG.UI_SkillTree
	local backups = SS.MapBackups:FindFirstChild("2026-11-24_ArbreSansFond")
	if not backups then
		backups = Instance.new("Folder")
		backups.Name = "2026-11-24_ArbreSansFond"
		backups.Parent = SS.MapBackups
	end
	if not backups:FindFirstChild("UI_SkillTree") then
		gui:Clone().Parent = backups
	end
	local backdrop = gui:FindFirstChild("Backdrop")
	if backdrop then
		backdrop:Destroy()
	end
	gui.DisplayOrder = 7
	gui:SetAttribute("Blur", true)
	gui:SetAttribute("HideHud", true)
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "UI_SkillTree : sans fond, DisplayOrder 7, Blur et HideHud"
