--!nonstrict
-- refonte_ui_hotbar_v2.luau (2026-11-15) : UI_Hotbar d'après la page Figma « 30 HUD, tapis, poursuite » (état 8, 106:10453),
-- validée par Clément. La barre de refonte_ui_hotbar.luau (L-180) est gardée ; ce qui change : attributs d'animation de
-- L-182 sur Bar.Template (Hover = Pop, Press = Squash) et cases de 46 px au moins sur téléphone (maquette 844 × 390).
-- À lancer en Edit après refonte_ui_hotbar.luau. Annulable. Aucun script.

local CHS = game:GetService("ChangeHistoryService")
local bar = game:GetService("StarterGui").UI_Hotbar.Bar

local rec = CHS:TryBeginRecording("Refonte UI : UI_Hotbar v2 (animations, 46 px sur téléphone)")
bar.Template:SetAttribute("Hover", "Pop")
bar.Template:SetAttribute("Press", "Squash")
bar.UISizeConstraint.MinSize = Vector2.new(0, 46)
bar.Template.TouchMin.MinSize = Vector2.new(46, 46)
if rec then
	CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
end
return "UI_Hotbar v2"
