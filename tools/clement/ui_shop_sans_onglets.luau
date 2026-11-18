--!nonstrict
-- ui_shop_sans_onglets.luau (Clément, 2026-11-18 : « retire les onglets offers, gamepasses etc., ils ne servent à
-- rien ») : dans UI_RobuxShop_v2, Root.Tabs est caché (Visible = false, gardé avec ses noms : le code d'Ironix y
-- cherche Tabs.*Tab pour faire défiler la liste) et la liste reprend toute la largeur de la fenêtre, comme avant le
-- 17/11 (Window.List 96,8 %, ScrollTrack au bord droit). Peut se relancer, en Edit. Annulable. Aucun script.

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")

local rec = CHS:TryBeginRecording("UI : boutique Robux sans onglets")
local ok, err = pcall(function()
	local root = SG.UI_RobuxShop_v2.Root
	local tabs = root:FindFirstChild("Tabs")
	if tabs then
		tabs.Visible = false
	end
	local window = root.Window
	local list = window.List
	list.Size = UDim2.new((1176 - 24) / 1190, 0, list.Size.Y.Scale, 0)
	local track = window:FindFirstChild("ScrollTrack")
	if track then
		track.AnchorPoint = Vector2.new(1, 0)
		track.Position = UDim2.new(1176 / 1190, 0, track.Position.Y.Scale, 0)
	end
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "boutique Robux sans onglets"
