--!strict
-- 2e étage de la boutique, Model `Floor_2` de Clément (a280, vague GC2, lot C de l'audit a270 ; L-217, L-231, L-277,
-- règle de L-294 décidée par Cantin le 2026-11-23 ; valeurs dans Config/ShopGrowth.Floor2, interrupteur
-- Features.ShopFloor2). Règles communes au serveur (DataService, ShopStageService, RayonService, DisplayService,
-- ShopService) et au client (UpgradeController).
--
-- Deux échelles pour l'amélioration Display Stands (Config/Upgrades, DisplaySlots), choisies par `stands`, les places de
-- l'étage ouvertes au joueur (ShopFloor.Stands) :
--   * stands = 0 (pas de Floor_2 livré, interrupteur coupé ou profil pas encore passé à la nouvelle boutique) : comme
--     avant, les niveaux 1 à MaxLevel (16) débloquent les présentoirs du bas 5 à 20 ;
--   * stands > 0 (L-294) : le bas s'arrête à Floor2.GroundSlots (8) présentoirs ; les niveaux 1 à 4 débloquent les
--     présentoirs 5 à 8, le niveau 5 achète l'étage (Floor2.Cost), les niveaux 6 à 5 + stands ses places
--     DisplaySlot_31, _32… une à une (Floor2.Costs). L'étage se montre d'un coup à son achat.
-- La renaissance remet le niveau à 0 (RebirthService) : l'étage se rachète avec le bas.
--
-- Profil (champ ShopLayout, DataService) : 0 = ancienne échelle, 1 = nouvelle. ShopFloor.Migrate fait passer un profil à
-- 1 au chargement dès que l'étage est là (même nombre de places au total, voir plus bas) ; jamais dans l'autre sens.
--
-- API (sans yield) :
--   ShopFloor.Layout                                     valeur de ShopLayout pour la nouvelle échelle (1)
--   ShopFloor.Stands(capacity, layout) -> number
--       Places de l'étage ouvertes : `capacity` (places posées dans Floor_2, au plus Floor2.Slots) si Features.ShopFloor2
--       et layout = ShopFloor.Layout, sinon 0.
--   ShopFloor.BaseSlots(level, stands) -> number         présentoirs du bas débloqués (4 à 8, ou 4 à 20 sans étage)
--   ShopFloor.Bought(level, stands) -> boolean           étage acheté (donc montré)
--   ShopFloor.IsFloorStep(level, stands) -> boolean      le prochain achat est l'étage lui-même
--   ShopFloor.Unlocked(level, stands) -> number          places de l'étage débloquées (0 à stands)
--   ShopFloor.Slot(n) -> number                          numéro du présentoir de la n-ième place (31, 32…)
--   ShopFloor.NextSlot(level, stands) -> number?         présentoir du prochain achat (pour l'étage : le dernier du bas)
--   ShopFloor.StandAt(level, stands) -> number?          a427 : présentoir débloqué en arrivant au niveau `level`
--                                                        (5 à 8, puis 31… avec l'étage) ; nil : l'étage lui-même, ou rien
--   ShopFloor.StandCost(level, stands) -> number?        prix du prochain achat ; nil : tout est acheté
--   ShopFloor.Total(level, stands) -> (number, number)   présentoirs débloqués et maximum, bas et étage (bonus non compris)
--   ShopFloor.Capacity(floor) -> number                  places DisplaySlot_31… posées à la suite dans `floor`
--   ShopFloor.TemplateFloor() -> Instance?               Floor_2 du gabarit Assets/Plots/PLOT_Shop, ou nil
--   ShopFloor.Migrate(data, capacity) -> string?         passe le profil à la nouvelle échelle (voir la fonction)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = script.Parent.Config
local Balance = require(Config.Balance)
local Features = require(Config.Features)
local Formulas = require(Config.Formulas)
local ShopGrowth = require(Config.ShopGrowth)
local Upgrades = require(Config.Upgrades)

local FLOOR = ShopGrowth.Floor2
local UPGRADE_ID = "DisplaySlots"
local TEMPLATE_NAME = "PLOT_Shop" -- gabarit de la boutique (ShopStageService)
local SLOT_FORMAT = "DisplaySlot_%02d"
local BASE_MAX = Upgrades.ById[UPGRADE_ID].MaxLevel -- 16 : 4 + 16 = 20 présentoirs du bas (ancienne échelle)
local START = Balance.Display.StartSlots -- 4
local GROUND_LEVELS = FLOOR.GroundSlots - START -- 4 : niveaux du bas (présentoirs 5 à 8)
local FLOOR_LEVEL = GROUND_LEVELS + 1 -- 5 : niveau qui suit l'achat de l'étage
assert(GROUND_LEVELS >= 0, "Config.ShopGrowth.Floor2 : GroundSlots doit être ≥ Balance.Display.StartSlots")
assert(#FLOOR.Costs >= FLOOR.Slots, "Config.ShopGrowth.Floor2 : Costs doit avoir un prix par place (Slots)")

local ShopFloor = {}

ShopFloor.Layout = 1

-- Niveau enregistré, entier ≥ 0 (une valeur douteuse compte pour 0).
local function stored(level: number): number
	return if type(level) == "number" and level == level and level < math.huge then math.max(0, math.floor(level)) else 0
end

local function clampStands(stands: number): number
	return if type(stands) == "number" and stands == stands then math.clamp(math.floor(stands), 0, FLOOR.Slots) else 0
end

function ShopFloor.Stands(capacity: number, layout: number?): number
	if not Features.ShopFloor2 or layout ~= ShopFloor.Layout then
		return 0
	end
	return clampStands(capacity)
end

function ShopFloor.BaseSlots(level: number, stands: number): number
	if clampStands(stands) > 0 then
		return START + math.min(stored(level), GROUND_LEVELS)
	end
	return math.min(START + math.min(stored(level), BASE_MAX), Balance.Display.MaxSlots)
end

function ShopFloor.Bought(level: number, stands: number): boolean
	return clampStands(stands) > 0 and stored(level) >= FLOOR_LEVEL
end

function ShopFloor.IsFloorStep(level: number, stands: number): boolean
	return clampStands(stands) > 0 and stored(level) == GROUND_LEVELS
end

function ShopFloor.Unlocked(level: number, stands: number): number
	local open = clampStands(stands)
	return if open > 0 then math.clamp(stored(level) - FLOOR_LEVEL, 0, open) else 0
end

function ShopFloor.Slot(n: number): number
	return FLOOR.FirstSlot + n - 1
end

function ShopFloor.NextSlot(level: number, stands: number): number?
	local bought = stored(level)
	local open = clampStands(stands)
	if open == 0 then
		local index = START + bought + 1
		return if bought < BASE_MAX and index <= Balance.Display.MaxSlots then index else nil
	end
	if bought < GROUND_LEVELS then
		return START + bought + 1
	elseif bought == GROUND_LEVELS then
		return FLOOR.GroundSlots -- achat de l'étage : panneau au dernier présentoir du bas
	end
	local n = bought - FLOOR_LEVEL + 1
	return if n <= open then ShopFloor.Slot(n) else nil
end

-- a427 (L-321, Floor_2 livré) : le présentoir que l'achat du niveau `level` vient de débloquer (ShopBuildController le
-- construit « en mode Lego ») : celui que NextSlot annonçait au niveau d'avant, sauf l'achat de l'étage (nil).
function ShopFloor.StandAt(level: number, stands: number): number?
	local bought = stored(level)
	if bought < 1 or ShopFloor.IsFloorStep(bought - 1, stands) then
		return nil
	end
	return ShopFloor.NextSlot(bought - 1, stands)
end

function ShopFloor.StandCost(level: number, stands: number): number?
	local bought = stored(level)
	local open = clampStands(stands)
	if open == 0 or bought < GROUND_LEVELS then
		return Formulas.UpgradeCost(UPGRADE_ID, bought)
	elseif bought == GROUND_LEVELS then
		return FLOOR.Cost
	end
	local n = bought - GROUND_LEVELS
	return if n <= open then FLOOR.Costs[n] else nil
end

function ShopFloor.Total(level: number, stands: number): (number, number)
	local open = clampStands(stands)
	local base = ShopFloor.BaseSlots(level, open)
	if open > 0 then
		return base + ShopFloor.Unlocked(level, open), FLOOR.GroundSlots + open
	end
	return base, Balance.Display.MaxSlots
end

function ShopFloor.Capacity(floor: Instance): number
	local count = 0
	for n = 1, FLOOR.Slots do
		local found = floor:FindFirstChild(string.format(SLOT_FORMAT, ShopFloor.Slot(n)), true)
		if found == nil or not found:IsA("Attachment") then
			break
		end
		count = n
	end
	return count
end

function ShopFloor.TemplateFloor(): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local plots = if assets then assets:FindFirstChild("Plots") else nil
	local template = if plots then plots:FindFirstChild(TEMPLATE_NAME) else nil
	return if template then template:FindFirstChild(FLOOR.ModelName) else nil
end

-- Passage d'un profil à la nouvelle échelle (L-294 point 4, Cantin le 2026-11-23), une seule fois, quand l'étage est là
-- (`capacity` places dans le Floor_2 du gabarit, ShopFloor.Stands > 0) ; sinon rien ne change. Un profil qui avait
-- 4 + L présentoirs (niveau L) garde le même nombre de places : L ≤ 4, rien ne bouge ; au-delà, l'étage est offert et
-- ses places aussi, n = min(L − 4, places de l'étage), niveau 5 + n. Les objets des présentoirs 9 à 8 + n passent sur
-- les places 31 à 30 + n, dans l'ordre ; ceux des présentoirs 9 à 20 qui n'ont plus de place sortent de Display et
-- restent dans Items (inventaire) : aucun objet perdu. Les présentoirs bonus (21 et plus) ne bougent pas. Renvoie une
-- ligne pour le journal, ou nil si le profil n'a pas changé de niveau ni d'objets.
function ShopFloor.Migrate(data: any, capacity: number): string?
	if data.ShopLayout == ShopFloor.Layout then
		return nil
	end
	local open = ShopFloor.Stands(capacity, ShopFloor.Layout)
	if open == 0 then
		return nil -- pas d'étage livré : ancienne échelle
	end
	local upgrades = data.Upgrades
	local level = stored(if type(upgrades) == "table" then upgrades.DisplaySlots else 0)
	data.ShopLayout = ShopFloor.Layout
	if level <= GROUND_LEVELS then
		return nil
	end
	local extra = math.min(level, BASE_MAX) - GROUND_LEVELS -- présentoirs au-delà du 8e (1 à 12)
	local n = math.min(extra, open)
	upgrades.DisplaySlots = FLOOR_LEVEL + n
	local display = if type(data.Display) == "table" then data.Display else nil
	local moved, freed = 0, 0
	if display then
		for i = 1, Balance.Display.MaxSlots - FLOOR.GroundSlots do
			local from = tostring(FLOOR.GroundSlots + i)
			local uid = display[from]
			if uid ~= nil then
				display[from] = nil
				local to = tostring(ShopFloor.Slot(i))
				if i <= n and display[to] == nil then
					display[to] = uid
					moved += 1
				else
					freed += 1
				end
			end
		end
	end
	return `boutique L-294 : niveau {level} → {FLOOR_LEVEL + n} (étage et {n} place(s) offerts), {moved} objet(s) montés à l'étage, {freed} rendu(s) à l'inventaire`
end

return ShopFloor
