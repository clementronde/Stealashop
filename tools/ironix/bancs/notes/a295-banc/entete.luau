--!nocheck
-- Banc a295 : en-tête de la partie « Tirage » du vrai TruckEventService, extraite par run.sh. Mêmes noms locaux que
-- le service (Items, Mutations, Rarities, ShelfBoxes, TruckEvent, random, warnOnce, log).
local Shared = script.Parent
local Items = require(Shared.Config.Items)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local ShelfBoxes = require(Shared.Config.ShelfBoxes)
local TruckEvent = require(Shared.Config.TruckEvent)
local random = Random.new()
local function warnOnce(key: string, message: string)
	WARN295[key] = message
end
local function log(_message: string) end
