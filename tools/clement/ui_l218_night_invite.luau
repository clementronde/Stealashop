--!nonstrict
-- ui_l218_night_invite.luau (retours du test de Clément du 2026-11-17) :
--   1. UI_HUD.NightCountdown : « le night en bas à droite n'est plus comme avant, style Break and Steal an Egg ».
--      Band redevient la bande noire en dégradé de l'écran d'avant la refonte (MapBackups/2026-11-15_RefonteUI/UI_HUD) et
--      de la référence (a2_boutique_pleine_58s.jpg, « Dans : 24:09 ») : transparente à gauche, sombre (0,65) à partir
--      du tiers, sans contour ni coins ; le texte reste blanc, gras, en italique, avec son contour sombre plus épais.
--   2. Workspace/Map/Hub/Zones/ENV_Hub_InviteNoob/Zone/LabelPoint/BB_ZoneLabel : 9 × 2,4 → 6 × 1,6 studs.
-- Aucun nom ne change. Sauvegardes dans ServerStorage/MapBackups/2026-11-17_Benchmark. Annulable. Aucun script.

local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")

local hud = game:GetService("StarterGui").UI_HUD
local night = hud:FindFirstChild("NightCountdown", true)
local invite = workspace.Map.Hub.Zones.ENV_Hub_InviteNoob.Zone.LabelPoint.BB_ZoneLabel

local function backup(object, name)
	local folder = SS.MapBackups:FindFirstChild("2026-11-17_Benchmark")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "2026-11-17_Benchmark"
		folder.Parent = SS.MapBackups
	end
	if not folder:FindFirstChild(name) then
		local copy = object:Clone()
		copy.Name = name
		if copy:IsA("ScreenGui") then
			copy.Enabled = false
		end
		copy.Parent = folder
	end
end

local rec = CHS:TryBeginRecording("UI : nuit en dégradé, étiquette Invite plus petite")
local ok, err = pcall(function()
	backup(hud, "UI_HUD")
	backup(invite, "BB_ZoneLabel_InviteNoob")

	local band = night.Band
	for _, c in band:GetChildren() do
		if c:IsA("UIStroke") or c:IsA("UICorner") or c:IsA("UIGradient") then
			c:Destroy()
		end
	end
	band.BackgroundColor3 = Color3.new(0, 0, 0)
	band.BackgroundTransparency = 0
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.35, 0.65),
		NumberSequenceKeypoint.new(1, 0.65),
	})
	fade.Parent = band
	night.FontFace = Font.new(night.FontFace.Family, Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
	night.TextColor3 = Color3.new(1, 1, 1)
	local stroke = night:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = Color3.fromHex("15151d")
		stroke.Thickness = 0.14
	end

	invite.Size = UDim2.fromScale(6, 1.6)
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "nuit en dégradé, Invite 6 × 1,6"
