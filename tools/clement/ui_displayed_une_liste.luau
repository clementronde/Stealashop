--!nonstrict
-- ui_displayed_une_liste.luau (Clément, 2026-11-19 : « on fait tout à la ligne, on ne fait pas de différenciation ;
-- d'abord tout ce qui est en plot, déjà équipé, et en dessous ce qu'on a dans l'inventaire ») : à lancer en Edit.
-- UI_Displayed n'a plus qu'une liste : Panel.List prend la place des deux blocs (objets exposés + réserve INVENTORY).
--   - Panel.List descend jusqu'au bas de l'ancienne réserve ; 3 lignes entières visibles (CellSize 1/3 moins l'écart).
--   - List.Template sert aux deux : RemoveButton (objet exposé) et DisplayButton (objet de la réserve, repris de
--     l'ancien ReserveList.Template, avec DisplayLabel), au même endroit ; le code montre l'un ou l'autre.
--   - Panel.Reserve disparaît (ReserveTitle, ReserveCount, ReserveList, ReserveEmpty) ; son texte vide devient
--     Panel.ListEmpty, au milieu de la liste, montré par le code quand il n'y a aucun objet.
--   - ScrollTrack suit la nouvelle hauteur de la liste.
-- Aucun script. Sauvegarde : ServerStorage/MapBackups/2026-11-19_L260/UI_Displayed (avant L-260). Annulable.

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")

local ROWS = 3 -- lignes entières visibles au repos (téléphone : environ 60 px chacune)
local EMPTY_TEXT = "Your items show up here"

local function apply(gui)
	local panel = gui.Dock.Panel
	local list, reserve = panel.List, panel:FindFirstChild("Reserve")
	assert(reserve, "Panel.Reserve déjà retiré")
	local bottom = reserve.Position.Y.Scale + reserve.Size.Y.Scale -- bas de l'ancienne réserve
	local top = list.Position.Y.Scale
	list.Size = UDim2.new(list.Size.X.Scale, list.Size.X.Offset, bottom - top, 0)
	local track = panel:FindFirstChild("ScrollTrack")
	if track then
		local inset = track.Position.Y.Scale - top -- même retrait en haut et en bas qu'avant
		track.Size = UDim2.new(track.Size.X.Scale, track.Size.X.Offset, bottom - top - 2 * inset, 0)
	end
	local grid = list:FindFirstChildOfClass("UIGridLayout")
	local gap = grid.CellPadding.Y.Offset
	grid.CellSize = UDim2.new(grid.CellSize.X.Scale, grid.CellSize.X.Offset, 1 / ROWS, -math.ceil(gap * (ROWS - 1) / ROWS))

	-- un seul gabarit : le bouton DISPLAY de la réserve rejoint REMOVE, au même rang
	local tpl = list.Template
	local display = reserve.ReserveList.Template.DisplayButton:Clone()
	display.LayoutOrder = tpl.RemoveButton.LayoutOrder
	display.Visible = false -- le code montre RemoveButton ou DisplayButton selon l'objet
	display.Parent = tpl

	-- texte de la liste vide
	local empty = reserve:FindFirstChild("ReserveEmpty")
	if empty then
		empty.Name = "ListEmpty"
		empty.Text = EMPTY_TEXT
		empty.AnchorPoint = Vector2.new(0.5, 0.5)
		empty.Position = UDim2.fromScale(0.5, top + (bottom - top) / 2)
		empty.Size = UDim2.fromScale(0.86, 0.08)
		empty.Visible = false
		empty.Parent = panel
	end
	reserve:Destroy()
end

local rec = CHS:TryBeginRecording("UI : UI_Displayed en une seule liste")
local ok, err = pcall(function()
	local backups = SS.MapBackups:FindFirstChild("2026-11-19_L260")
	assert(backups and backups:FindFirstChild("UI_Displayed"), "sauvegarde 2026-11-19_L260/UI_Displayed absente")
	apply(SG.UI_Displayed)
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "UI_Displayed : une seule liste"
