--!nocheck
-- Socle de l'objet exclusif géant de la zone safe (idée 7 du paquet H, validée par Clément le 26/11).
-- Modèle du chef 3D : ServerStorage/Previews/ENV_Hub_ExclusiveShowcase (Root avec ItemPoint et LabelPoint,
-- PromptPart sans collision devant, aucun script).
-- Pose une copie dans Workspace/Map/Hub/Zones, au sol en (12 ; 0 ; -38), face avant vers +z (vers le milieu du
-- passage entre l'apparition et la sortie vers le couloir), en face du noob d'invitation (14 ; 6 ; 38).
-- Place libre mesurée le 25/11 : x 2..26, z -56..-20 jusqu'à y = 60, colonne de 12 × 12 libre jusqu'à y = 200.
-- Avant : l'ancien socle posé (s'il existe) part dans ServerStorage/MapBackups/<date>_ExclusiveShowcase.
-- Le tag ExclusiveShowcase n'est posé qu'une fois au contrat (src/shared/Contract/Tags.luau, côté Cantin) :
-- passer TAG = true à ce moment-là et relancer.
-- À lancer dans Studio (MCP execute_luau, Edit). Relançable.

local CS = game:GetService("CollectionService")
local CHS = game:GetService("ChangeHistoryService")

local TAG = false
local DATE = os.date("%Y-%m-%d")
local PIVOT = CFrame.lookAt(Vector3.new(12, 0, -38), Vector3.new(12, 0, -37)) -- face avant vers +z

local src = game.ServerStorage:FindFirstChild("Previews")
src = src and src:FindFirstChild("ENV_Hub_ExclusiveShowcase")
assert(src, "ServerStorage/Previews/ENV_Hub_ExclusiveShowcase introuvable")
local zones = workspace.Map.Hub:FindFirstChild("Zones")
assert(zones, "Workspace/Map/Hub/Zones introuvable")

local rec = CHS:TryBeginRecording("Socle de l'objet exclusif", { allowNoUndo = true })

-- Sauvegarde de l'ancien socle posé
local backups = game.ServerStorage:FindFirstChild("MapBackups")
if not backups then
	backups = Instance.new("Folder")
	backups.Name = "MapBackups"
	backups.Parent = game.ServerStorage
end
local old = zones:FindFirstChild("ENV_Hub_ExclusiveShowcase")
local backupName = DATE .. "_ExclusiveShowcase"
if old then
	local b = backups:FindFirstChild(backupName) or Instance.new("Folder")
	b.Name = backupName
	b:SetAttribute("Note", "Ancien socle de l'objet exclusif retiré par hub_exclusive_showcase.luau. Pour revenir : le remettre dans Map/Hub/Zones.")
	b.Parent = backups
	old.Parent = b
end

local m = src:Clone()
for _, d in m:GetDescendants() do
	if d:IsA("LuaSourceContainer") then d:Destroy() end
	if d:IsA("BasePart") then d.Anchored = true end
end
m:PivotTo(PIVOT)
if TAG then CS:AddTag(m, "ExclusiveShowcase") end
m.Parent = zones

if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end

local root = m:FindFirstChild("Root")
local item = root and root:FindFirstChild("ItemPoint")
local label = root and root:FindFirstChild("LabelPoint")
return ("Posé : %s, pivot %s, ItemPoint %s, LabelPoint %s, tag %s, sauvegarde %s"):format(
	m:GetFullName(), tostring(m:GetPivot().Position),
	item and tostring(item.WorldPosition) or "?", label and tostring(label.WorldPosition) or "?",
	tostring(TAG), old and ("MapBackups/" .. backupName) or "aucune (premier posé)")
