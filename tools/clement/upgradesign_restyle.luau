--[[
	UpgradeSign plus petit et plus propre (retour de Clément, L-092) : à lancer en Edit.
	Mêmes noms, même pivot (en bas au centre, PrimaryPart = Foot), même SurfaceGui.
	- Board : 4,6 × 3 × 0,3 studs (au lieu de 7 × 4,5 × 0,45), le bas à 1 stud du sol.
	- Foot : un pied fin de 0,36 stud ; FootBase : un petit socle de 1,4 × 0,16 × 0,9.
	- SignGui à 100 px par stud (460 × 300) ; bord du panneau à 4 px ; reflets (Gloss) des
	  boutons retirés ; titre en haut, niveau en vert, bouton prix vert, bouton Robux violet.
	S'applique au modèle ReplicatedStorage/Assets/UI/UpgradeSign et aux aperçus de
	Workspace/_PREVIEW_UpgradeSigns (leurs textes sont gardés).
]]

local CH = game:GetService("ChangeHistoryService")
local rec = CH:TryBeginRecording("UpgradeSign plus petit et plus propre")

local function restyle(model)
	local board, foot, base = model:FindFirstChild("Board"), model:FindFirstChild("Foot"), model:FindFirstChild("FootBase")
	if not (board and foot and base) then return false end
	local pivot = model:GetPivot()
	board.Size = Vector3.new(4.6, 3.0, 0.3)
	board.CFrame = pivot * CFrame.new(0, 2.5, 0)
	base.Size = Vector3.new(1.4, 0.16, 0.9)
	base.CFrame = pivot * CFrame.new(0, 0.08, 0)
	foot.Size = Vector3.new(0.36, 0.95, 0.36)
	foot.CFrame = pivot * CFrame.new(0, 0.16 + 0.475, 0)
	foot.PivotOffset = CFrame.new(0, -(0.16 + 0.475), 0)
	model.PrimaryPart = foot
	local gui = board:FindFirstChild("SignGui")
	if gui then
		gui.PixelsPerStud = 100
		local panel = gui:FindFirstChild("Panel")
		local st = panel and panel:FindFirstChildOfClass("UIStroke")
		if st then st.Thickness = 4 end
		for _, b in { "BuyButton", "RobuxButton" } do
			local btn = gui:FindFirstChild(b)
			local gloss = btn and btn:FindFirstChild("Gloss")
			if gloss then gloss:Destroy() end
		end
		local title = gui:FindFirstChild("Title")
		if title then title.Position = UDim2.fromScale(0.5, 0.2); title.Size = UDim2.fromScale(0.8, 0.24) end
		local level = gui:FindFirstChild("Level")
		if level then
			level.Position = UDim2.fromScale(0.5, 0.43)
			level.Size = UDim2.fromScale(0.86, 0.15)
			level.TextColor3 = Color3.fromHex("5cff4a")
		end
	end
	return true
end

local n = 0
if restyle(game.ReplicatedStorage.Assets.UI.UpgradeSign) then n += 1 end
local prev = workspace:FindFirstChild("_PREVIEW_UpgradeSigns")
if prev then
	for _, m in prev:GetDescendants() do
		if m:IsA("Model") and m.Name:match("^Preview") and restyle(m) then n += 1 end
	end
end
if rec then CH:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
return "panneaux retouches : " .. n
