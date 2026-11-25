--!nonstrict
-- ui_displayed_sans_pop.luau (L-281, question 1 ; Clément, 2026-11-24 : on retire l'effet Pop) : à lancer en Edit.
-- Sur UI_Displayed, l'attribut Hover = "Pop" (posé par le plugin Figma) passait avant les tailles prévues par le code
-- (Config/UiMotion.Hover : croix CloseTo 1,07, cartes CardTo 1,03 ; au Play, la croix montait à 1,10 et les cartes ne
-- grossissaient pas). Il est retiré de la croix (Dock.Panel.Header.CloseButton, son Press = Squash reste) et des
-- cartes (Dock.Panel.List.Template). Les autres boutons gardent Pop. Aucun nom changé, aucun script.

local CHS = game:GetService("ChangeHistoryService")
local panel = game:GetService("StarterGui").UI_Displayed.Dock.Panel

local rec = CHS:TryBeginRecording("UI : retire Hover = Pop de la croix et des cartes de UI_Displayed (L-281 Q1)")
for _, o in { panel.Header.CloseButton, panel.List.Template } do
	o:SetAttribute("Hover", nil)
end
if rec then
	CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
end
return "Hover retiré de CloseButton et de List.Template"
