-- Applique la DA de l'Exclusive Crate à un modèle importé (.glb de Claude Design).
-- Les matériaux se règlent d'après le nom des pièces (voir tour-01.md) :
--   Body*     -> Plastic + MaterialVariant STUDS (studs)
--   Frame*, Accent*, Face* -> SmoothPlastic
--   Neon*     -> Neon (Neon_Cracks ou NeonRed)
--   Crystal*  -> SmoothPlastic, transparence 0,1, reflet 0,15 (comme les cristaux du colis)
--   Root      -> invisible, sans collision, PrimaryPart
-- Ajoute aussi le contour OutlineHighlight noir, et ancre toutes les pièces.
-- Usage, dans la barre de commande de Studio, en Edit : sélectionner le modèle, puis lancer ce script.
-- Ne touche qu'au modèle sélectionné. Annuler avec Ctrl+Z.

local STUDS = "Studs" -- mettre "StudsSmall" si ce variant existe (studs 4 fois plus petits), voir README

local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local model = Selection:Get()[1]
assert(model and model:IsA("Model"), "Sélectionne un Model")

local recording = ChangeHistoryService:TryBeginRecording("Appliquer la DA")
local report = {}
local unknown = {}

for _, p in model:GetDescendants() do
	if p:IsA("BasePart") then
		p.Anchored = true
		local n = p.Name
		if n == "Root" then
			p.Transparency = 1
			p.CanCollide = false
			p.CastShadow = false
			model.PrimaryPart = p
		elseif n:match("^Body") then
			p.Material = Enum.Material.Plastic
			p.MaterialVariant = STUDS
		elseif n:match("^Frame") or n:match("^Accent") or n:match("^Face") then
			p.Material = Enum.Material.SmoothPlastic
			p.MaterialVariant = ""
		elseif n:match("^Neon") then
			p.Material = Enum.Material.Neon
			p.MaterialVariant = ""
		elseif n:match("^Crystal") then
			p.Material = Enum.Material.SmoothPlastic
			p.MaterialVariant = ""
			p.Transparency = 0.1
			p.Reflectance = 0.15
		else
			table.insert(unknown, n)
		end
		report[#report + 1] = n .. " -> " .. p.Material.Name .. (p.MaterialVariant ~= "" and ("/" .. p.MaterialVariant) or "")
	end
end

if not model:FindFirstChild("OutlineHighlight") then
	local hl = Instance.new("Highlight")
	hl.Name = "OutlineHighlight"
	hl.FillTransparency = 1
	hl.OutlineColor = Color3.new(0, 0, 0)
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = model
end

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end

print(table.concat(report, "\n"))
if #unknown > 0 then
	warn("Pièces au nom inconnu (laissées telles quelles) : " .. table.concat(unknown, ", "))
end
if not model.PrimaryPart then
	warn("Pas de pièce Root : le contrat 10.4 en demande une")
end
