--!strict
-- BoxZoneTagController (a517, demande de Cantin du 27/11 ; Features.BoxZoneTag / BoxZoneTagDev, lus par le serveur) :
-- étiquette « ZONE N » sur l'étiquette BB_Box de chaque colis d'un rayon (tag ShelfBox, StoreHeistService), d'après
-- l'attribut BoxZone que le serveur pose sur le Model du colis quand sa zone est plus haute que celle de l'endroit
-- (Shared/BoxZoneTag). Élément ZoneTag de Clément dans BB_Box, sinon le repli du code ; sans attribut, ZoneTag caché.
-- Rien d'autre : BB_Box reste à ShelfBoxController (distance, contour), l'ouverture à RevealController.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoxZoneTag = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BoxZoneTag"))

local SHELF_BOX_TAG = "ShelfBox" -- StoreHeistService.makeBoxModel (même nom là-bas)
local LABEL_NAME = "BB_Box" -- contrat 2.2 (L-031)

local BoxZoneTagController = {}

local watched: { [Instance]: { RBXScriptConnection } } = {}

local function apply(box: Instance)
	local zone = box:GetAttribute(BoxZoneTag.Attribute)
	for _, descendant in box:GetDescendants() do
		if descendant.Name == LABEL_NAME and descendant:IsA("BillboardGui") then
			BoxZoneTag.Apply(descendant, zone)
		end
	end
end

local function watch(box: Instance)
	if watched[box] then
		return
	end
	watched[box] = {
		box:GetAttributeChangedSignal(BoxZoneTag.Attribute):Connect(function()
			apply(box)
		end),
		box.DescendantAdded:Connect(function(descendant: Instance)
			if descendant.Name == LABEL_NAME and descendant:IsA("BillboardGui") then
				BoxZoneTag.Apply(descendant, box:GetAttribute(BoxZoneTag.Attribute))
			end
		end),
	}
	apply(box)
end

local function unwatch(box: Instance)
	local connections = watched[box]
	watched[box] = nil
	if connections == nil then
		return
	end
	for _, connection in connections do
		connection:Disconnect()
	end
end

function BoxZoneTagController.Start()
	CollectionService:GetInstanceAddedSignal(SHELF_BOX_TAG):Connect(watch)
	CollectionService:GetInstanceRemovedSignal(SHELF_BOX_TAG):Connect(unwatch)
	for _, box in CollectionService:GetTagged(SHELF_BOX_TAG) do
		watch(box)
	end
end

return BoxZoneTagController
