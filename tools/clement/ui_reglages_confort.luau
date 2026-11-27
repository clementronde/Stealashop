--!nonstrict
-- ui_reglages_confort.luau (26/11, maquette de Clément du 22/11, cadre Figma 301:4) : montre les rangées de confort et
-- de performance de UI_Settings, déjà construites et cachées. À lancer en Edit. Knob.Halo existe déjà (caché) : c'est le
-- code qui le montre pendant le glisser. Sauvegarde : ServerStorage/MapBackups/2026-11-26_UI_Settings_avant_confort.
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")
local CHS = game:GetService("ChangeHistoryService")
local s = SG.UI_Settings
local backups = SS:FindFirstChild("MapBackups")
if backups and not backups:FindFirstChild("2026-11-26_UI_Settings_avant_confort") then
	local f = Instance.new("Folder")
	f.Name = "2026-11-26_UI_Settings_avant_confort"
	s:Clone().Parent = f
	f.Parent = backups
end
local rec = CHS:TryBeginRecording("UI : réglages de confort et de performance visibles")
local rows = s.Root.Window.RowsScroll.Rows
for _, n in { "ComfortHeader", "PerfRow", "OthersFxRow", "ShakeRow", "FovRow", "FlashRow", "HudSizeRow" } do
	rows[n].Visible = true
end
if rec then
	CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
end
return "7 rangées montrées"

-- Suite (26/11, Chef de projet : « agrandis la fenêtre des réglages sur téléphone, comme l'inventaire ») : la fenêtre
-- prend 90 % de l'écran, plafonnée à la taille d'avant en 1920 × 1080 (748 × 680) ; chaque rangée a au moins 70 px de
-- haut (titres 24 px, aides 16 px en 844 × 390), les en-têtes 24 px, CodeRow 84 px ; une seule contrainte de taille par
-- rangée. Sauvegarde : ServerStorage/MapBackups/2026-11-26_UI_Settings_avant_telephone.
do
	local root = s.Root
	local ar = root:FindFirstChildOfClass("UIAspectRatioConstraint")
	if ar then
		ar:Destroy()
	end
	root.Size = UDim2.fromScale(0.9, 0.9)
	local sc = root:FindFirstChildOfClass("UISizeConstraint")
	sc.MinSize = Vector2.zero
	sc.MaxSize = Vector2.new(748, 680)
	for _, c in rows:GetChildren() do
		if c:IsA("GuiObject") then
			local want = if c.Name:match("Header$") then 24 elseif c.Name == "CodeRow" then 84 elseif c.Name:match("Row$") then 70 else nil
			if want then
				local keep = c:FindFirstChildOfClass("UISizeConstraint") or Instance.new("UISizeConstraint")
				keep.MinSize = Vector2.new(keep.MinSize.X, math.max(keep.MinSize.Y, want))
				keep.Parent = c
			end
		end
	end
end
