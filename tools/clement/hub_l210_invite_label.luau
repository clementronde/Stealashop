--!nonstrict
-- hub_l210_invite_label.luau (retours du test de Clément du 2026-11-16, L-210) : l'étiquette « INVITE A FRIEND » du hub à
-- taille humaine, comme le panneau OPEN des boutiques. Workspace/Map/Hub/Zones/ENV_Hub_InviteNoob/Zone/LabelPoint/
-- BB_ZoneLabel : 26 × 7 studs → 9 × 2,4 studs (le texte garde ses proportions, Label 68 %, SubLabel 32 %).
-- Les étiquettes des stands (WEAPONS, AURAS, ROBUX SHOP, PAWN SHOP) et de la roue ne changent pas.
-- Sauvegarde dans ServerStorage/MapBackups/2026-11-16_L210/BB_ZoneLabel_InviteNoob. Annulable. Aucun script.

local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")

local bb = workspace.Map.Hub.Zones.ENV_Hub_InviteNoob.Zone.LabelPoint.BB_ZoneLabel

local rec = CHS:TryBeginRecording("Hub : étiquette Invite à taille humaine (L-210)")
local ok, err = pcall(function()
	local folder = SS.MapBackups:FindFirstChild("2026-11-16_L210")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "2026-11-16_L210"
		folder.Parent = SS.MapBackups
	end
	if not folder:FindFirstChild("BB_ZoneLabel_InviteNoob") then
		local copy = bb:Clone()
		copy.Name = "BB_ZoneLabel_InviteNoob"
		copy.Parent = folder
	end
	bb.Size = UDim2.fromScale(9, 2.4)
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "étiquette Invite : 9 × 2,4 studs"
