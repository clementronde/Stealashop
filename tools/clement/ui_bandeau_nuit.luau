--!nonstrict
-- ui_bandeau_nuit.luau (Clément, 2026-11-24 : « l'overlay "Night in 4 minutes 28" est dans le mauvais sens, ou alors il
-- doit être collé au bord de l'écran à droite, parce que là on voit la séparation nette ») : à lancer en Edit.
-- UI_HUD.NightCountdown.Band (le bandeau sombre derrière le texte) s'arrêtait ~10 px avant le bord droit de l'écran :
-- il est allongé vers la droite pour dépasser le bord sur PC (de −0,21 à +1,45 de la largeur du texte), avec un fondu
-- aux deux bouts. Sur téléphone, le code centre le compteur en bas (attributs PhonePosition et PhoneAnchorPoint) : le
-- bandeau s'y efface des deux côtés. Aucun nom changé, aucun script.
-- Sauvegarde : ServerStorage/MapBackups/2026-11-24_BandeauNuit.

local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")
local label = game:GetService("StarterGui").UI_HUD.NightCountdown

local rec = CHS:TryBeginRecording("UI : bandeau du compte à rebours de la nuit jusqu'au bord de l'écran")
local ok, err = pcall(function()
	local backups = SS.MapBackups:FindFirstChild("2026-11-24_BandeauNuit")
	if not backups then
		backups = Instance.new("Folder")
		backups.Name = "2026-11-24_BandeauNuit"
		backups.Parent = SS.MapBackups
	end
	if not backups:FindFirstChild("NightCountdown") then
		label:Clone().Parent = backups
	end
	local band = label.Band
	band.Position = UDim2.new(-0.21, 0, band.Position.Y.Scale, band.Position.Y.Offset)
	band.Size = UDim2.new(1.66, 0, band.Size.Y.Scale, band.Size.Y.Offset)
	local fade = band:FindFirstChildOfClass("UIGradient")
	assert(fade, "pas de UIGradient sur NightCountdown.Band")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.65),
		NumberSequenceKeypoint.new(0.79, 0.65), -- au-delà du bord de l'écran sur PC
		NumberSequenceKeypoint.new(1, 1),
	})
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "NightCountdown.Band jusqu'au bord de l'écran"
