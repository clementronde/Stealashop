--!nonstrict
-- ui_l210_displayed.luau (retours du test de Clément du 2026-11-16, L-210) : UI_Displayed (« On Display »).
--   - Panel.List et Panel.Reserve.ReserveList passent d'un UIListLayout à un UIGridLayout dont la hauteur des cases est
--     une part de la hauteur visible de la liste (List : 2 lignes, ReserveList : 1 ligne). Les lignes ne dépendent plus
--     d'un UIAspectRatioConstraint : le défilement (AutomaticCanvasSize) suit maintenant leur vraie hauteur, la dernière
--     ligne n'est plus coupée en bas, et à l'ouverture on ne voit que des lignes entières. Le code clone toujours Template
--     dans la liste, rien ne change pour lui.
--   - Textes 18 % plus petits (noms, rareté, revenu, REMOVE, DISPLAY, titres, DISPLAY BEST).
--   - Reserve.ReserveEmpty (nouveau, décor) : « Items replaced by DISPLAY BEST go here », sous la liste de la réserve :
--     visible quand la réserve est vide, recouvert par la première ligne sinon. La réserve reste toujours affichée : le
--     code ne doit plus la cacher (liaison).
-- Sauvegarde dans ServerStorage/MapBackups/2026-11-16_L210/UI_Displayed. Annulable. Aucun script.

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")

local gui = SG.UI_Displayed
local panel = gui.Dock.Panel
local TEXT = 0.82

local function backup(screen)
	local folder = SS.MapBackups:FindFirstChild("2026-11-16_L210")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "2026-11-16_L210"
		folder.Parent = SS.MapBackups
	end
	if not folder:FindFirstChild(screen.Name) then
		local copy = screen:Clone()
		copy.Enabled = false
		copy.Parent = folder
	end
end
-- Grille d'une ligne par case, `rows` lignes visibles, 6 px entre deux.
local function grid(list, width, rows)
	local old = list:FindFirstChildOfClass("UIListLayout")
	if old then
		old:Destroy()
	end
	if not list:FindFirstChildOfClass("UIGridLayout") then
		local layout = Instance.new("UIGridLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.FillDirectionMaxCells = 1
		layout.CellSize = UDim2.new(width, 0, 1 / rows, -6 * (rows - 1) / rows)
		layout.CellPadding = UDim2.fromOffset(0, 6)
		layout.Parent = list
	end
	local ratio = list.Template:FindFirstChildOfClass("UIAspectRatioConstraint")
	if ratio then
		ratio:Destroy()
	end
end
-- Texte plus petit, même centre vertical.
local function shrink(label)
	local p, s = label.Position, label.Size
	local h = s.Y.Scale * TEXT
	label.Position = UDim2.new(p.X.Scale, p.X.Offset, p.Y.Scale + (s.Y.Scale - h) * (1 - label.AnchorPoint.Y), p.Y.Offset)
	label.Size = UDim2.new(s.X.Scale, s.X.Offset, h, s.Y.Offset)
end

local rec = CHS:TryBeginRecording("UI : On Display, listes en grille, textes plus petits, réserve vide (L-210)")
local ok, err = pcall(function()
	backup(gui)

	local list = panel.List
	local reserve = panel.Reserve
	grid(list, 0.974, 2)
	grid(reserve.ReserveList, 0.968, 1)

	local t = list.Template
	shrink(t.ItemName)
	shrink(t.RarityChip)
	shrink(t.Income)
	shrink(t.RemoveButton.RemoveLabel)
	local q = reserve.ReserveList.Template
	shrink(q.ItemName)
	shrink(q.Income)
	shrink(q.DisplayButton.DisplayLabel)
	shrink(panel.Header.Title)
	shrink(panel.Header.DisplayCount.CountLabel)
	shrink(reserve.ReserveTitle)
	shrink(gui.Dock.DisplayBestButton.DisplayBestLabel)

	if not reserve:FindFirstChild("ReserveEmpty") then
		local empty = Instance.new("TextLabel")
		empty.Name = "ReserveEmpty"
		empty.Text = "Items replaced by DISPLAY BEST go here"
		empty.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold)
		empty.TextColor3 = Color3.fromHex("9aa0ab")
		empty.TextScaled = true
		empty.TextWrapped = true
		empty.BackgroundTransparency = 1
		empty.AnchorPoint = Vector2.new(0.5, 0.5)
		empty.Position = UDim2.fromScale(0.5, 0.654)
		empty.Size = UDim2.fromScale(0.86, 0.26)
		empty.ZIndex = 1
		empty.Parent = reserve
	end
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "UI_Displayed : listes en grille, textes plus petits"
