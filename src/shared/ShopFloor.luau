--!strict
-- 2e étage de la boutique, Model `Floor_2` de Clément (a280, vague GC2, lot C de l'audit a270 ; L-217, L-231, L-277 ;
-- valeurs dans Config/ShopGrowth.Floor2, interrupteur Features.ShopFloor2). Règles communes au serveur
-- (ShopStageService, RayonService, DisplayService, ShopService) et au client (UpgradeController).
--
-- Les places de l'étage (DisplaySlot_31 à _40) se débloquent une à une « comme la boutique du bas » (L-231 Q4), dans la
-- suite de l'amélioration Display Stands (Config/Upgrades, DisplaySlots) : ses niveaux 1 à MaxLevel (16) débloquent les
-- présentoirs du bas (5 à 20), les niveaux MaxLevel + 1 à MaxLevel + n les places de l'étage, n = places ouvertes au
-- joueur (`stands` : 0 tant que l'étage n'est pas à lui). La renaissance remet le niveau à 0 (RebirthService) : l'étage
-- se rachète avec le bas. L'étage se montre d'un coup quand des places sont ouvertes et que les 20 du bas sont débloquées
-- (avant, la boutique du bas est coupée et sans toit : l'étage flotterait). Le niveau enregistré n'est jamais borné à
-- MaxLevel ailleurs (ShopService.levelOf) : un joueur qui perd ses places (renaissance) repart de 0 de toute façon.
--
-- API (sans yield) :
--   ShopFloor.Stands(capacity, rebirths, showFrom) -> number
--       Places ouvertes : `capacity` (places posées dans Floor_2, au plus Floor2.Slots) si Features.ShopFloor2 et
--       rebirths ≥ showFrom, sinon 0.
--   ShopFloor.Unlocked(level, stands) -> number          places de l'étage débloquées (0 à stands)
--   ShopFloor.IsShown(level, stands) -> boolean          étage montré
--   ShopFloor.Slot(n) -> number                          numéro du présentoir de la n-ième place (31, 32…)
--   ShopFloor.NextSlot(level, stands) -> number?         numéro du prochain présentoir à débloquer (bas ou étage)
--   ShopFloor.StandCost(level, stands) -> number?        prix du prochain présentoir ; nil : tout est débloqué
--   ShopFloor.Total(level, stands) -> (number, number)   présentoirs débloqués et maximum, bas et étage (bonus non compris)

local Config = script.Parent.Config
local Balance = require(Config.Balance)
local Features = require(Config.Features)
local Formulas = require(Config.Formulas)
local ShopGrowth = require(Config.ShopGrowth)
local Upgrades = require(Config.Upgrades)

local FLOOR = ShopGrowth.Floor2
local UPGRADE_ID = "DisplaySlots"
local BASE_MAX = Upgrades.ById[UPGRADE_ID].MaxLevel -- 16 : 4 + 16 = 20 présentoirs du bas
assert(#FLOOR.Costs >= FLOOR.Slots, "Config.ShopGrowth.Floor2 : Costs doit avoir un prix par place (Slots)")

local ShopFloor = {}

-- Niveau enregistré, entier ≥ 0 (une valeur douteuse compte pour 0).
local function stored(level: number): number
	return if type(level) == "number" and level == level and level < math.huge then math.max(0, math.floor(level)) else 0
end

local function clampStands(stands: number): number
	return if type(stands) == "number" and stands == stands then math.clamp(math.floor(stands), 0, FLOOR.Slots) else 0
end

function ShopFloor.Stands(capacity: number, rebirths: number, showFrom: number): number
	if not Features.ShopFloor2 or type(rebirths) ~= "number" or rebirths ~= rebirths or rebirths < showFrom then
		return 0
	end
	return clampStands(capacity)
end

function ShopFloor.Unlocked(level: number, stands: number): number
	return math.clamp(stored(level) - BASE_MAX, 0, clampStands(stands))
end

function ShopFloor.IsShown(level: number, stands: number): boolean
	return clampStands(stands) > 0 and stored(level) >= BASE_MAX
end

function ShopFloor.Slot(n: number): number
	return FLOOR.FirstSlot + n - 1
end

function ShopFloor.NextSlot(level: number, stands: number): number?
	local bought = stored(level)
	if bought < BASE_MAX then
		local index = Balance.Display.StartSlots + bought + 1
		return if index <= Balance.Display.MaxSlots then index else nil
	end
	local n = bought - BASE_MAX + 1
	return if n <= clampStands(stands) then ShopFloor.Slot(n) else nil
end

function ShopFloor.StandCost(level: number, stands: number): number?
	local bought = stored(level)
	if bought < BASE_MAX then
		return Formulas.UpgradeCost(UPGRADE_ID, bought)
	end
	local n = bought - BASE_MAX + 1
	return if n <= clampStands(stands) then FLOOR.Costs[n] else nil
end

function ShopFloor.Total(level: number, stands: number): (number, number)
	local display = Balance.Display
	local base = math.min(display.StartSlots + math.min(stored(level), BASE_MAX), display.MaxSlots)
	local open = clampStands(stands)
	return base + ShopFloor.Unlocked(level, stands), display.MaxSlots + open
end

return ShopFloor
