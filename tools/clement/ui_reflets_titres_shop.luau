--!nonstrict
-- ui_reflets_titres_shop.luau (Clément, 2026-11-24 : « ajouter des glims sur les textes du style exclusive crate,
-- x2 cash, x2 training ; ajouter un peu des effets sympas ») : à lancer en Edit.
-- Boutique Robux UI_RobuxShop_v2 : les titres des cartes (ItemName des Template et Preview_* des sections Gamepasses,
-- Boosts et Cash) passent de l'attribut Gleam = "Hover" (reflet au survol) à Gleam = "Loop" (reflet en boucle),
-- comme Crate.ItemName (EXCLUSIVE CRATE) et Featured.ItemName (STARTER PACK), déjà en Loop.
-- Le reflet est joué par UiAttrFx (code d'Ironix), qui l'ignore sur les textes depuis a298 : liaison pour qu'il le
-- rejoue sur ces titres. Aucun nom changé, aucun script. Sauvegarde : ServerStorage/MapBackups/2026-11-24_Reflets.

local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")
local gui = game:GetService("StarterGui").UI_RobuxShop_v2

local rec = CHS:TryBeginRecording("UI : reflets en boucle sur les titres des cartes de la boutique Robux")
local changed = {}
local ok, err = pcall(function()
	local backups = SS.MapBackups:FindFirstChild("2026-11-24_Reflets")
	if not backups then
		backups = Instance.new("Folder")
		backups.Name = "2026-11-24_Reflets"
		backups.Parent = SS.MapBackups
	end
	if not backups:FindFirstChild("UI_RobuxShop_v2") then
		gui:Clone().Parent = backups
	end
	for _, d in gui:GetDescendants() do
		if d:IsA("TextLabel") and d.Name == "ItemName" and d:GetAttribute("Gleam") == "Hover" then
			d:SetAttribute("Gleam", "Loop")
			table.insert(changed, d.Text)
		end
	end
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return #changed .. " titres en Loop : " .. table.concat(changed, ", ")
