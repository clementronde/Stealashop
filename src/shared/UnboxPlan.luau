--!strict
-- Plan de la nouvelle ouverture du colis (vague 73, a251 ; liaison L-236 ; valeurs : Config/Unbox.New), commun au
-- serveur et au client, sans Roblox :
--   - le serveur (StoreHeistService.startReveal) tire le plan avec UnboxPlan.draw, une fois la rareté gagnée tirée
--     par les règles de la caisse, et l'envoie à tous dans RevealStarted (argument plan) ; rien ne vient du client ;
--   - le client (RevealController, Controllers/Reveal/Unbox) le relit avec UnboxPlan.parse et le joue ;
--   - les deux calculent les mêmes durées (plafond du serveur, plafond du client).
-- Texte du plan : « Saw:Common,Kick:Uncommon,Drill:Uncommon,Search:Rare,Hammer:Rare|37 » = une action et la rareté
-- montrée sur le colis après son moment fort, dans l'ordre, puis la cote finale « 1 IN 37 ».

local Config = script.Parent:WaitForChild("Config")
local Unbox = require(Config:WaitForChild("Unbox"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Reveal = require(Config:WaitForChild("Reveal"))

local New = Unbox.New

local UnboxPlan = {}

export type Action = Unbox.Action
export type Step = { Action: Action, Rarity: string }
export type Plan = { Steps: { Step }, Odds: number }

UnboxPlan.MaxSteps = 12
UnboxPlan.MaxLength = 256 -- longueur du texte (Net/Definitions, RevealStarted.plan)

local actionsById: { [string]: Action } = {}
for _, action in New.Actions do
	actionsById[action.Id] = action
end

local function orderOf(rarity: string): number
	local info = Rarities.ById[rarity]
	return if info then info.Order else 0
end

local function rangeOf(rarity: string): (number, number)
	local range = New.OddsRanges[rarity]
	local lo = if range and type(range[1]) == "number" then range[1] else 2
	local hi = if range and type(range[2]) == "number" then range[2] else lo
	lo = math.max(lo, 1)
	return lo, math.max(hi, lo)
end

local function speed(): number
	return math.max(New.ActionSpeed, 0.1)
end

function UnboxPlan.action(id: string): Action?
	return actionsById[id]
end

-- Nombre d'actions du plan (Config : 2 à MaxSteps).
function UnboxPlan.count(): number
	return math.clamp(math.floor(New.ActionCount), 2, UnboxPlan.MaxSteps)
end

-- Tire le plan d'un colis dont l'objet est de rareté `finalRarity`. `pick(n)` rend un entier de 1 à n (le Random du
-- serveur). nil si la Config ne permet aucun plan (FinalAction inconnue, rareté inconnue, aucune autre action).
function UnboxPlan.draw(finalRarity: string, pick: (n: number) -> number): string?
	local final = Rarities.ById[finalRarity]
	local finalAction = actionsById[New.FinalAction]
	if final == nil or finalAction == nil then
		return nil
	end
	local pool: { Action } = {}
	for _, action in New.Actions do
		if action ~= finalAction then
			table.insert(pool, action)
		end
	end
	if #pool == 0 then
		return nil
	end
	local function choose(n: number): number
		return math.clamp(math.floor(pick(n)), 1, n)
	end
	-- Actions : au hasard, jamais deux fois la même de suite, la dernière imposée.
	local count = UnboxPlan.count()
	local ids: { string } = {}
	local previous: Action? = nil
	for index = 1, count - 1 do
		local candidates: { Action } = {}
		for _, action in pool do
			if action ~= previous or #pool == 1 then
				table.insert(candidates, action)
			end
		end
		local chosen = candidates[choose(#candidates)]
		ids[index] = chosen.Id
		previous = chosen
	end
	ids[count] = finalAction.Id
	-- Améliorations : aux moments forts des actions 2 à count − 1, de StartRarity jusqu'à la rareté gagnée.
	local startOrder = math.clamp(orderOf(New.StartRarity), 1, final.Order)
	local slots: { number } = {}
	for index = 2, count - 1 do
		table.insert(slots, index)
	end
	local upgrades = math.min(#slots, final.Order - startOrder)
	while #slots > upgrades do
		table.remove(slots, choose(#slots))
	end
	local parts: { string } = {}
	local done = 0
	local current = startOrder
	for index = 1, count do
		if slots[done + 1] == index then
			done += 1
			current = startOrder + math.floor(done * (final.Order - startOrder) / upgrades + 0.5)
		end
		parts[index] = `{ids[index]}:{Rarities.List[current].Id}`
	end
	local lo, hi = rangeOf(finalRarity)
	lo, hi = math.floor(lo), math.floor(hi)
	local odds = lo + choose(hi - lo + 1) - 1
	return `{table.concat(parts, ",")}|{odds}`
end

-- Relit le texte d'un plan. nil s'il est inutilisable (action ou rareté inconnue, rareté qui redescend, trop long).
function UnboxPlan.parse(text: any): Plan?
	if type(text) ~= "string" or #text == 0 or #text > UnboxPlan.MaxLength then
		return nil
	end
	local body, oddsText = string.match(text, "^([^|]+)|(%d+)$")
	local odds = if oddsText then tonumber(oddsText) else nil
	if body == nil or odds == nil or odds < 1 or odds >= math.huge then
		return nil
	end
	local steps: { Step } = {}
	local lastOrder = 0
	for part in string.gmatch(body, "[^,]+") do
		local id, rarity = string.match(part, "^(%w+):(%w+)$")
		local action = if id then actionsById[id] else nil
		local order = if rarity then orderOf(rarity) else 0
		if action == nil or rarity == nil or order < 1 or order < lastOrder or #steps >= UnboxPlan.MaxSteps then
			return nil
		end
		lastOrder = order
		table.insert(steps, { Action = action, Rarity = rarity })
	end
	if #steps == 0 then
		return nil
	end
	return { Steps = steps, Odds = odds }
end

-- Cote montrée avant la première action (index 0), puis au moment fort de l'action `index` : un nombre de la plage
-- de la rareté montrée, toujours plus haut d'une action à l'autre ; dans la dernière rareté, il reste sous la cote
-- finale du plan (affichée à la révélation).
function UnboxPlan.oddsAt(plan: Plan, index: number): number
	local steps = plan.Steps
	if index <= 0 then
		return (rangeOf(steps[1].Rarity))
	end
	index = math.min(index, #steps)
	local rarity = steps[index].Rarity
	local first, last = index, index
	while first > 1 and steps[first - 1].Rarity == rarity do
		first -= 1
	end
	while last < #steps and steps[last + 1].Rarity == rarity do
		last += 1
	end
	local size = last - first + 1
	local rank = index - first + 1
	local lo, hi = rangeOf(rarity)
	if last == #steps and plan.Odds >= lo and plan.Odds <= hi then
		return lo * (plan.Odds / lo) ^ (rank / (size + 1))
	end
	return lo * (hi / lo) ^ ((rank - 0.5) / size)
end

local function trim(text: string): string
	return (string.gsub(text, "%.0$", ""))
end

-- « 2.4 », « 37 », « 1.2K », « 60K », « 1.5M ».
function UnboxPlan.formatOdds(value: number): string
	if value >= 999_500 then
		return trim(string.format("%.1f", value / 1_000_000)) .. "M"
	elseif value >= 9_950 then
		return string.format("%d", math.floor(value / 1000 + 0.5)) .. "K"
	elseif value >= 999.5 then
		return trim(string.format("%.1f", value / 1000)) .. "K"
	elseif value >= 9.95 then
		return string.format("%d", math.floor(value + 0.5))
	end
	return trim(string.format("%.1f", value))
end

-- Texte de BB_UnboxOdds.Odds : « 1 IN 37 ».
function UnboxPlan.oddsText(value: number): string
	return string.format(New.OddsText, UnboxPlan.formatOdds(value))
end

-- Durée d'une action en repli codé, et la pause entre deux actions.
function UnboxPlan.actionTime(action: Action): number
	return action.Duration / speed()
end

function UnboxPlan.actionLimit(action: Action): number
	return action.Duration * New.ActionMaxFactor / speed()
end

function UnboxPlan.gap(): number
	return New.ActionGap / speed()
end

-- Du coup final à la révélation : éclat, une silhouette par rareté jusqu'à `rarity`, suspense, surexposition.
local function afterBurst(rarity: string): number
	local silhouettes = math.max(orderOf(rarity), 1)
	return New.BurstHold + (silhouettes - 1) * New.SilhouetteStep + New.Suspense + New.Overexpose
end

-- Instant de la révélation (s depuis RevealStarted) d'un plan joué aux durées de repli.
function UnboxPlan.revealAt(plan: Plan, rarity: string): number
	local t = New.Intro
	for index, step in plan.Steps do
		local duration = UnboxPlan.actionTime(step.Action)
		if index < #plan.Steps then
			t += duration + UnboxPlan.gap()
		else
			local impacts = step.Action.Impacts
			t += duration * (impacts[#impacts] or 1)
		end
	end
	return t + afterBurst(rarity)
end

-- De la révélation à la fin (Land), en repli codé : croissance et tenue de Config/Reveal.
function UnboxPlan.tailTime(sizeClass: string): number
	local fallback: any = Reveal.Fallback
	local grow: number = fallback.GrowTime[sizeClass] or fallback.GrowTime.Small
	local land: number = fallback.LandHold[sizeClass] or fallback.LandHold.Small
	return New.AfterReveal + grow + land
end

-- Durée la plus longue possible d'une scène, sans marge : les actions les plus longues, chacune coupée à
-- ActionMaxFactor, puis la fin au budget qu'avait déjà la croissance (Reveal.MaxSeconds − Fallback.OpenEnd : une
-- animation Grow<Classe> du rig de Clément peut durer plus que le repli).
function UnboxPlan.longest(rarity: string, sizeClass: string): number
	local finalAction = actionsById[New.FinalAction]
	local first, second = 0, 0
	for _, action in New.Actions do
		if action ~= finalAction then
			local limit = UnboxPlan.actionLimit(action)
			if limit > first then
				first, second = limit, first
			elseif limit > second then
				second = limit
			end
		end
	end
	if second == 0 then
		second = first
	end
	local count = UnboxPlan.count() - 1
	local actions = math.ceil(count / 2) * first + math.floor(count / 2) * second + count * UnboxPlan.gap()
	local final = if finalAction then UnboxPlan.actionLimit(finalAction) else 0
	local maxSeconds: any = Reveal.MaxSeconds
	local budget: number = (maxSeconds[sizeClass] or maxSeconds.Small) - Reveal.Fallback.OpenEnd
	local tail = New.AfterReveal + math.max(budget, UnboxPlan.tailTime(sizeClass) - New.AfterReveal)
	return New.Intro + actions + final + afterBurst(rarity) + tail
end

-- Plafond du serveur (fin de la phase sans RevealDone) et plafond du client (la scène saute à sa fin).
function UnboxPlan.serverMaxSeconds(rarity: string, sizeClass: string): number
	return UnboxPlan.longest(rarity, sizeClass) + New.ServerMargin
end

function UnboxPlan.clientMaxSeconds(rarity: string, sizeClass: string): number
	return UnboxPlan.longest(rarity, sizeClass) + New.ClientMargin
end

-- Durées typiques (actions de durée moyenne, repli codé) : instant de la révélation, puis durée totale jusqu'à Land.
function UnboxPlan.typical(rarity: string, sizeClass: string): (number, number)
	local finalAction = actionsById[New.FinalAction]
	local sum, n = 0, 0
	for _, action in New.Actions do
		if action ~= finalAction then
			sum += UnboxPlan.actionTime(action)
			n += 1
		end
	end
	local count = UnboxPlan.count() - 1
	local t = New.Intro + count * ((if n > 0 then sum / n else 0) + UnboxPlan.gap())
	if finalAction then
		local impacts = finalAction.Impacts
		t += UnboxPlan.actionTime(finalAction) * (impacts[#impacts] or 1)
	end
	local reveal = t + afterBurst(rarity)
	return reveal, reveal + UnboxPlan.tailTime(sizeClass)
end

return UnboxPlan
