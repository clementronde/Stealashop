--!nonstrict
-- ui_arbre_nodedesc.luau (L-332, demande de Cantin du 2026-11-24, validée par Clément) : à lancer en Edit.
-- UI_SkillTree.InfoPanel reçoit un TextLabel NodeDesc sous Header : la phrase qui dit à quoi sert la compétence
-- (écrite par le code depuis Config/SkillTree), sur 2 à 3 lignes, TextWrapped, taille en Scale, au style des autres
-- textes du panneau (Montserrat, contour noir), plafonnée à 20 px pour qu'une phrase courte ne devienne pas énorme.
-- Pour lui faire de la place, l'icône rapetisse (0,25 → 0,15 de la hauteur du panneau) et NodeLevel et StatBox
-- remontent un peu ; PriceRow et les boutons ne bougent pas. Aucun nom existant changé, aucun script.
-- PREVIEW = true : rien ne change ; une copie de l'écran avec une phrase longue d'exemple est posée dans StarterGui
-- (_PREVIEW_CLAUDE_Tree, non archivable, à détruire). PREVIEW = false : l'écran change (sauvegarde
-- ServerStorage/MapBackups/2026-11-24_NodeDesc).

local PREVIEW = false
local SAMPLE = "Installs a camera that warns you when a thief walks into your shop, even when you are away."

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")

local function apply(gui, sample)
	local panel = gui.InfoPanel
	local desc = panel:FindFirstChild("NodeDesc")
	if not desc then
		desc = Instance.new("TextLabel")
		desc.Name = "NodeDesc"
		desc.Parent = panel
	end
	desc.AnchorPoint = Vector2.new(0.5, 0)
	desc.Position = UDim2.fromScale(0.5, 0.168)
	desc.Size = UDim2.fromScale(0.86, 0.14)
	desc.BackgroundTransparency = 1
	desc.FontFace = panel.StatBox.NodeStat.FontFace
	desc.Text = sample or "What this skill does, in one short sentence."
	desc.TextColor3 = Color3.fromHex("#E4E8FF")
	desc.TextXAlignment = Enum.TextXAlignment.Center
	desc.TextYAlignment = Enum.TextYAlignment.Center
	desc.LineHeight = 1
	desc.TextScaled = false
	desc.TextWrapped = true
	desc.TextScaled = true
	desc.ZIndex = 22
	local cap = desc:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = 20
	cap.MinTextSize = 1
	cap.Parent = desc
	local s = desc:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	s.Color = Color3.new(0, 0, 0)
	s.Thickness = 0.1
	s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = desc
	-- place pour la phrase : icône plus petite, niveau et bloc d'effet un peu plus haut
	panel.NodeIcon.Position = UDim2.fromScale(0.5, 0.385)
	panel.NodeIcon.Size = UDim2.fromScale(1, 0.15)
	panel.NodeLevel.Position = UDim2.fromScale(0.5, 0.487)
	panel.NodeLevel.Size = UDim2.fromScale(0.8, 0.055)
	panel.StatBox.Position = UDim2.fromScale(0.5, 0.522)
	panel.StatBox.Size = UDim2.fromScale(0.88, 0.175)
end

if PREVIEW then
	local old = SG:FindFirstChild("_PREVIEW_CLAUDE_Tree")
	if old then
		old:Destroy()
	end
	local src = SG.UI_SkillTree
	local was = src.Archivable
	src.Archivable = true
	local copy = src:Clone()
	src.Archivable = was
	copy.Name = "_PREVIEW_CLAUDE_Tree"
	copy.Archivable = false
	copy.Enabled = true
	copy.DisplayOrder = 200
	apply(copy, SAMPLE)
	copy.Parent = SG
	return "aperçu posé"
end

local rec = CHS:TryBeginRecording("UI : NodeDesc dans l'InfoPanel de l'arbre de compétences (L-332)")
local ok, err = pcall(function()
	local backups = SS.MapBackups:FindFirstChild("2026-11-24_NodeDesc")
	if not backups then
		backups = Instance.new("Folder")
		backups.Name = "2026-11-24_NodeDesc"
		backups.Parent = SS.MapBackups
	end
	if not backups:FindFirstChild("UI_SkillTree") then
		SG.UI_SkillTree:Clone().Parent = backups
	end
	apply(SG.UI_SkillTree, nil)
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "UI_SkillTree.InfoPanel.NodeDesc posé"
