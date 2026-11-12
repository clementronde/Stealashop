--!strict
-- Listes de choix du panel admin (vague 29, L-108 point 4) : ReplicatedStorage/Shared/AdminLists, lu par le client
-- (AdminController remplit les Template de UI_Admin) et par le serveur (AdminService revalide chaque Id reçu). Tout
-- vient de Config : aucune liste n'est recopiée ici.
--
--   AdminLists.Entries(kind) -> { Entry }   dans l'ordre de Config ; kind :
--       "Items" (Config/Items), "Boxes" (raretés, Config/Rarities), "Auras" et "Trails" (Config/Cosmetics),
--       "Potions" (Config/Potions), "Gamepasses" (Config/Monetization.Passes), "Mutations" (« None » d'Id "",
--       puis tailles et effets de Config/Mutations), "Events" (Config/Admin.Events), "Zones" (Id "0" = zone safe,
--       puis "1" à "6")
--   AdminLists.Has(kind, id) -> boolean

local Config = script.Parent.Config
local Admin = require(Config.Admin)
local Cosmetics = require(Config.Cosmetics)
local Items = require(Config.Items)
local Monetization = require(Config.Monetization)
local Mutations = require(Config.Mutations)
local Potions = require(Config.Potions)
local Rarities = require(Config.Rarities)
local Zones = require(Config.Zones)

export type Entry = { Id: string, Label: string }

local AdminLists = {}

local cache: { [string]: { Entry } } = {}

local function build(kind: string): { Entry }
	local list: { Entry } = {}
	local function add(id: string, label: string)
		table.insert(list, { Id = id, Label = label })
	end
	if kind == "Items" then
		for _, item in Items.List do
			add(item.Id, item.DisplayName)
		end
	elseif kind == "Boxes" then
		for _, rarity in Rarities.List do
			add(rarity.Id, rarity.DisplayName)
		end
	elseif kind == "Auras" then
		for _, cosmetic in Cosmetics.Auras do
			add(cosmetic.Id, cosmetic.DisplayName)
		end
	elseif kind == "Trails" then
		for _, cosmetic in Cosmetics.Trails do
			add(cosmetic.Id, cosmetic.DisplayName)
		end
	elseif kind == "Potions" then
		for _, potion in Potions.List do
			add(potion.Id, potion.DisplayName)
		end
	elseif kind == "Gamepasses" then
		for _, pass in Monetization.Passes do
			add(pass.Key, pass.DisplayName)
		end
	elseif kind == "Mutations" then
		add("", "None")
		for _, entry in Mutations.Sizes do
			add(entry.Id, entry.DisplayName)
		end
		for _, entry in Mutations.Effects do
			add(entry.Id, entry.DisplayName)
		end
	elseif kind == "Events" then
		for _, id in Admin.Events do
			add(id, id)
		end
	elseif kind == "Zones" then
		add("0", "Safe zone")
		for index in Zones do
			add(tostring(index), `Zone {index}`)
		end
	end
	return list
end

function AdminLists.Entries(kind: string): { Entry }
	local list = cache[kind]
	if list == nil then
		list = build(kind)
		cache[kind] = list
	end
	return list
end

function AdminLists.Has(kind: string, id: string): boolean
	for _, entry in AdminLists.Entries(kind) do
		if entry.Id == id then
			return true
		end
	end
	return false
end

return AdminLists
