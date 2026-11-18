--!nonstrict
-- ui_shop_contours_rarete.luau (Clément, 2026-11-18 : « mets un contour rainbow pour le 1 %, un contour rouge pour
-- celui d'avant et un contour violet pour celui d'avant ») : dans UI_RobuxShop_v2, Crate.Odds :
--   Odd_6 (1 %) contour arc-en-ciel (UIGradient sur son UIStroke), Odd_5 (4 %) rouge, Odd_4 (10 %) violet ;
--   ces trois contours un peu plus épais (4 % du côté de la case au lieu de 2,6 %) pour se lire, et leur RaysClip
--   recalé dessous (les rayons ne passent jamais sur le contour). Odd_1 à Odd_3 gardent le contour noir.
-- Peut se relancer, en Edit. Annulable. Aucun script.

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")

local THICK = 0.04
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromHex("ff3b3b")),
	ColorSequenceKeypoint.new(0.17, Color3.fromHex("ff9f1c")),
	ColorSequenceKeypoint.new(0.33, Color3.fromHex("ffe23b")),
	ColorSequenceKeypoint.new(0.5, Color3.fromHex("3be15a")),
	ColorSequenceKeypoint.new(0.67, Color3.fromHex("2fd4ff")),
	ColorSequenceKeypoint.new(0.83, Color3.fromHex("2f6bff")),
	ColorSequenceKeypoint.new(1, Color3.fromHex("a855f7")),
})
local COLORS = { [4] = Color3.fromHex("a855f7"), [5] = Color3.fromHex("ff2d3a"), [6] = Color3.new(1, 1, 1) }

local rec = CHS:TryBeginRecording("UI : contours de rareté sur les 3 cases les plus rares de la caisse")
local ok, err = pcall(function()
	local odds = SG.UI_RobuxShop_v2.Root.Window.List.Content.Crate.Odds
	for i = 4, 6 do
		local cell = odds["Odd_" .. i]
		local s = cell:FindFirstChildOfClass("UIStroke")
		s.Color = COLORS[i]
		s.Thickness = THICK
		s.Transparency = 0
		local g = s:FindFirstChildOfClass("UIGradient")
		if i == 6 then
			g = g or Instance.new("UIGradient")
			g.Name = "Rainbow"
			g.Color = RAINBOW
			g.Rotation = 45
			g.Parent = s
		elseif g then
			g:Destroy()
		end
		local clip = cell:FindFirstChild("RaysClip")
		if clip then
			clip.Position = UDim2.fromScale(THICK, THICK)
			clip.Size = UDim2.fromScale(1 - 2 * THICK, 1 - 2 * THICK)
			local rays = clip:FindFirstChild("Rays")
			if rays then
				local k = 1 / (1 - 2 * THICK)
				rays.Size = UDim2.fromScale(k, k)
				rays.Position = UDim2.fromScale(-0.026 * k - THICK * k, -THICK * k)
			end
		end
	end
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "contours de rareté posés"
