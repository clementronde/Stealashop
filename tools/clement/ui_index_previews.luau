--!strict
-- UI_Index_v3 : cartes d'aperçu de tous les objets dans Studio (demande de Clément du 2026-11-16, « remets tous les
-- items »). Une carte Preview_<nn>_<ItemId> par objet du catalogue (Config/Items, hors tutoriel), dans
-- Zone<N>Section.Content.Cards de sa zone : clone de List.Template, fond à la couleur de la rareté, icône ICON_<ItemId>
-- (son contour noir est dans l'image), nom de l'objet, Lock caché.
-- Sans effet en jeu : IndexController lit la teinte de l'icône d'une carte Preview_* puis les retire toutes, et
-- remplit les grilles depuis List.Template. Relançable : les anciennes cartes Preview_* sont retirées d'abord.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Items = require(config:WaitForChild("Items")) :: any
local Rarities = require(config:WaitForChild("Rarities")) :: any
local icons = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Icons")

local gui = StarterGui:WaitForChild("UI_Index_v3")
local list = gui:WaitForChild("Root"):WaitForChild("Window"):WaitForChild("ListPanel"):WaitForChild("List")
local template = list:WaitForChild("Template")

for _, d in list:GetDescendants() do
	if string.find(d.Name, "^Preview_") then
		d:Destroy()
	end
end

local counts: { [number]: number } = {}
local missing: { string } = {}
for _, item in Items.List do
	local zone = item.Zone
	if not item.TutorialOnly and type(zone) == "number" and zone >= 1 and zone <= 6 then
		local section = list:FindFirstChild("Zone" .. zone .. "Section")
		local content = section and section:FindFirstChild("Content")
		local cards = content and content:FindFirstChild("Cards")
		if cards then
			counts[zone] = (counts[zone] or 0) + 1
			local card = template:Clone() :: any
			card.Name = string.format("Preview_%02d_%s", counts[zone], item.Id)
			card.Visible = true
			card.LayoutOrder = counts[zone]
			local rarity = Rarities.ById[item.Rarity]
			if rarity then
				card.Clip.BackgroundColor3 = rarity.Color
			end
			local decal = icons:FindFirstChild("ICON_" .. item.Id)
			if decal and decal:IsA("Decal") then
				card.Icon.Image = decal.Texture
			else
				table.insert(missing, item.Id)
			end
			card.Icon.ImageColor3 = Color3.new(1, 1, 1) -- teinte « trouvé », relue par IndexController
			card.ItemName.Text = item.DisplayName
			card.Lock.Visible = false
			card.Parent = cards
		end
	end
end

local summary = {}
for zone = 1, 6 do
	table.insert(summary, "Z" .. zone .. " = " .. (counts[zone] or 0))
end
print("[ui_index_previews] " .. table.concat(summary, ", ") .. (if #missing > 0 then " ; icônes manquantes : " .. table.concat(missing, ", ") else ""))
