--!nonstrict
-- ui_boutons_retouches_motif_lisere.luau (Clément, 2026-11-22) : retouches de Clément sur les boutons au style Framewisp,
-- validées sur la maquette des Réglages (Figma 294:4 et 301:4) puis demandées pour tout le jeu (« Oui, applique ») :
--   1. motif en croix (Quilt, rbxassetid://87198718489515) deux fois plus léger : ImageTransparency 0,82 -> 0,91 ;
--   2. « rien de la face sur l'ombre » : le liseré blanc (Face.Rim, UIStroke intérieur) s'efface vers le bas, par un
--      UIGradient posé sous le UIStroke (transparence 0 jusqu'à 0,55, puis 1 à partir de 0,9). Le rebord du bas (Lip)
--      reste une ombre unie.
-- Seulement les faces des boutons et des plaques (Quilt enfant d'un cadre Face) dans les écrans UI_* de StarterGui. Les
-- panneaux d'enseigne (Panel, motif opaque) ne sont pas des boutons : pas touchés. Aucun nom changé, rien de déplacé ni
-- supprimé, aucun script. Rejouable : ne change que ce qui n'est pas encore retouché.
-- Sauvegarde : ServerStorage/MapBackups/2026-11-22_RetouchesBoutons/<écran>.
-- Fiche : docs/claude/notes/2026-11-22_video-reglages.md, section 4 (« Retouches de Clément »).

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")
local QUILT = "87198718489515"
local OLD, NEW = 0.82, 0.91

local function rimGradient(stroke)
	local g = stroke:FindFirstChild("RimFade")
	if g then return false end
	g = Instance.new("UIGradient") g.Name = "RimFade" g.Rotation = 90
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.55, 0),
		NumberSequenceKeypoint.new(0.9, 1), NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = stroke
	return true
end

-- écrans concernés
local targets = {}
for _, gui in SG:GetChildren() do
	if gui:IsA("ScreenGui") and gui.Name:match("^UI_") then
		for _, d in gui:GetDescendants() do
			if d.Name == "Quilt" and d:IsA("ImageLabel") and tostring(d.Image):find(QUILT) and d.Parent and d.Parent.Name == "Face" then
				targets[gui] = true
				break
			end
		end
	end
end

local mb = SS:FindFirstChild("MapBackups") or Instance.new("Folder") mb.Name = "MapBackups" mb.Parent = SS
local bf = mb:FindFirstChild("2026-11-22_RetouchesBoutons") or Instance.new("Folder") bf.Name = "2026-11-22_RetouchesBoutons" bf.Parent = mb
for gui in targets do
	if not bf:FindFirstChild(gui.Name) then local c = gui:Clone() c.Enabled = false c.Parent = bf end
end

local quilts, rims, screens = 0, 0, 0
local rec = CHS:TryBeginRecording("UI : boutons, motif plus léger et liseré sans ombre")
local ok, err = pcall(function()
	for gui in targets do
		screens += 1
		for _, d in gui:GetDescendants() do
			if d.Name == "Quilt" and d:IsA("ImageLabel") and tostring(d.Image):find(QUILT) and d.Parent and d.Parent.Name == "Face" then
				if math.abs(d.ImageTransparency - OLD) < 0.005 then d.ImageTransparency = NEW quilts += 1 end
				local rim = d.Parent:FindFirstChild("Rim")
				local st = rim and rim:FindFirstChildOfClass("UIStroke")
				if st and rimGradient(st) then rims += 1 end
			end
		end
	end
end)
if rec then CHS:FinishRecording(rec, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel) end
if not ok then error(err) end
return string.format("%d écrans : %d motifs allégés, %d liserés effacés vers le bas", screens, quilts, rims)
