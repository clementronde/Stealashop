--!nonstrict
-- held_income_build.luau (demande de Clément du 2026-11-15) : « retire l'argent par seconde [des cases], on doit voir
-- l'argent par seconde au-dessus de l'item quand on le prend dans nos mains ».
--   1. UI_Hotbar : Bar.Template.Income reste (le code le lit), mais son texte et son contour sont transparents : même
--      montré par le code, il ne se voit plus.
--   2. ReplicatedStorage/Assets/UI/BB_HeldIncome (nouveau) : billboard « $1.2K/s » au-dessus de l'objet tenu en main,
--      même style que l'Income de BB_Carry (dégradé vert de l'argent, contour noir). Un seul texte lu : Income. Le code
--      d'Ironix le clone sur le Tool HeldItem (liaison L-189).
-- À lancer en Edit, après refonte_ui_hotbar_v3.luau. Annulable. Aucun script.

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local UI = game:GetService("ReplicatedStorage").Assets.UI

local HEAVY = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)

local rec = CHS:TryBeginRecording("Revenu : caché dans la barre, BB_HeldIncome au-dessus de l'objet en main")
local ok, err = pcall(function()
	local income = SG.UI_Hotbar.Bar.Template.Income
	income.TextTransparency = 1
	local s = income:FindFirstChildOfClass("UIStroke")
	if s then
		s.Transparency = 1
	end

	if not UI:FindFirstChild("BB_HeldIncome") then
		local bb = Instance.new("BillboardGui")
		bb.Name = "BB_HeldIncome"
		bb.Size = UDim2.new(2.4, 30, 0.6, 10)
		bb.StudsOffset = Vector3.new(0, 0.6, 0)
		bb.MaxDistance = 80
		bb.LightInfluence = 0
		bb.AlwaysOnTop = false
		bb.ResetOnSpawn = false
		bb.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		local label = Instance.new("TextLabel")
		label.Name = "Income"
		label.Text = "$1.2K/s"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.FontFace = HEAVY
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextScaled = true
		label.TextWrapped = true
		label.Parent = bb
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 0.12
		stroke.Color = Color3.new(0, 0, 0)
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		stroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
		stroke.LineJoinMode = Enum.LineJoinMode.Round
		stroke.Parent = label
		local grad = Instance.new("UIGradient")
		grad.Color = ColorSequence.new(Color3.fromHex("d4ff5c"), Color3.fromHex("2fcb1f"))
		grad.Rotation = 90
		grad.Parent = label
		bb.Parent = UI
	end
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "revenu : fait"
