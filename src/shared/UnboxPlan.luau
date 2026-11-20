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
local Formulas = require(Config:WaitForChild("Formulas"))

local New = Unbox.New

local UnboxPlan = {}

export type Action = Unbox.Action
export type Step = { Action: Action, Rarity: string }
export type Plan = { Steps: { Step }, Odds: number }
export type Move = { Action: Action, Place: string, Teleport: boolean } -- vague 74 (a257, L-258)

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

-- Vague 74 (a257, L-253) : nombre d'actions selon le résultat (la dernière comprise, 1 à MaxSteps) : ActionsByRarity
-- de la rareté gagnée, plus ActionsPerUpgrade par amélioration ; une amélioration tombe au moment fort d'une action
-- qui n'est ni la première ni la dernière, d'où 2 + améliorations au moins.
function UnboxPlan.count(finalRarity: string, upgrades: number?): number
	local u = math.max(math.floor(upgrades or 0), 0)
	local base = New.ActionsByRarity[finalRarity]
	if type(base) ~= "number" then
		base = math.max(orderOf(finalRarity), 1)
	end
	local n = math.floor(base) + u * math.max(New.ActionsPerUpgrade, 0)
	if u > 0 then
		n = math.max(n, u + 2)
	end
	return math.clamp(n, 1, UnboxPlan.MaxSteps)
end

-- Vague 74 (a257, L-253 point 2) : améliorations du colis, tirées à part de l'objet avec les probabilités de l'ouverture
-- v2 (Config/Unbox : UpgradeChance × `luck` par cran, UpgradeMax crans), depuis la rareté du colis `startRarity`,
-- jamais jusqu'à Secret (comme UnboxService). `roll()` rend un nombre de [0, 1[ (le Random du serveur).
-- Vague 76 : `maxRarity` (la plus haute rareté de la zone, ShelfBoxes.ZoneRarities) : jamais au-dessus.
local SECRET_ORDER = orderOf("Secret")
function UnboxPlan.upgrades(startRarity: string, luck: number, roll: () -> number, maxRarity: string?): number
	local cap = if maxRarity then orderOf(maxRarity) else 0
	local chance = Unbox.UpgradeChance * luck
	chance = if chance == chance then math.clamp(chance, 0, 1) else 0
	local order = orderOf(startRarity)
	if chance <= 0 or order < 1 then
		return 0
	end
	local done = 0
	for _ = 1, Unbox.UpgradeMax do
		local nextRarity = Rarities.List[order + done + 1]
		if nextRarity == nil or (SECRET_ORDER > 0 and nextRarity.Order >= SECRET_ORDER) or (cap > 0 and nextRarity.Order > cap) or roll() >= chance then
			break
		end
		done += 1
	end
	return done
end

-- Tire le plan d'un colis dont l'objet est de rareté `finalRarity`. `pick(n)` rend un entier de 1 à n (le Random du
-- serveur). Vague 74 : la rareté montrée part de `startRarity` (le colis du rayon ; StartRarity si absente ou
-- inconnue) et monte d'un cran par amélioration (`upgrades`, UnboxPlan.upgrades), sans lien avec `finalRarity`.
-- nil si la Config ne permet aucun plan (FinalAction inconnue, rareté inconnue, aucune autre action).
-- Vague 75 (a259, L-262 point 1) : `odds` (la vraie chance de l'objet, Formulas.UnboxOdds, calculée par le serveur) est
-- la cote finale ; absente ou illisible : tirée dans la plage de `finalRarity`, comme avant.
function UnboxPlan.draw(finalRarity: string, pick: (n: number) -> number, startRarity: string?, upgrades: number?, odds: number?): string?
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
	local startOrder = orderOf(startRarity or "")
	if startOrder < 1 then
		startOrder = math.max(orderOf(New.StartRarity), 1)
	end
	local u = math.clamp(math.floor(upgrades or 0), 0, #Rarities.List - startOrder)
	-- Actions : au hasard, jamais deux fois la même de suite, la dernière imposée.
	local count = UnboxPlan.count(finalRarity, u)
	u = math.min(u, math.max(count - 2, 0))
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
	-- Améliorations : aux moments forts de `u` actions tirées parmi 2 à count − 1, un cran chacune.
	local slots: { number } = {}
	for index = 2, count - 1 do
		table.insert(slots, index)
	end
	while #slots > u do
		table.remove(slots, choose(#slots))
	end
	local parts: { string } = {}
	local done = 0
	for index = 1, count do
		if slots[done + 1] == index then
			done += 1
		end
		parts[index] = `{ids[index]}:{Rarities.List[startOrder + done].Id}`
	end
	local cote: number
	if type(odds) == "number" and odds >= 1 and odds < 1e15 then -- vague 76 : 1e15 (au lieu de 1e9), cotes réelles des mutations rares
		cote = math.floor(odds)
	else
		local lo, hi = rangeOf(finalRarity)
		lo, hi = math.floor(lo), math.floor(hi)
		cote = lo + choose(hi - lo + 1) - 1
	end
	return `{table.concat(parts, ",")}|{cote}`
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

-- « 2.4 », « 37 », « 1.2K », « 60K », « 1.5M ». Vague 76 : « 23B » au-delà du milliard.
function UnboxPlan.formatOdds(value: number): string
	if value >= 999_500_000 then
		return trim(string.format("%.1f", value / 1_000_000_000)) .. "B"
	elseif value >= 999_500 then
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

-- Texte de BB_UnboxOdds.Odds : « 1 IN 37 ». Vague 77 (a263) : la cote qui défile passe par le même arrondi que la
-- cote finale (Formulas.UnboxOdds : entier sous 100, 2 chiffres significatifs au-delà), jamais « 1 IN 8.4 ».
function UnboxPlan.oddsText(value: number): string
	local rounded = if value >= 1 then Formulas.UnboxOdds(1 / value) else nil
	return string.format(New.OddsText, UnboxPlan.formatOdds(rounded or value))
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

-- Vague 74 (a257, L-258) : place de chaque action ("Side" = celle de L-236, "Other" = de l'autre côté du colis,
-- "Top" = debout sur le couvercle), d'après New.Places.Cycle, la dernière toujours sur le colis. `stomp`, `slam` :
-- les animations Unbox_Stomp et Unbox_Slam existent ; sans elles, le tour du dessus se fait à côté (Side ou Other
-- selon l'action). Places coupées : toujours Side.
function UnboxPlan.places(count: number, stomp: boolean, slam: boolean): { string }
	local config = New.Places
	local cycle = config.Cycle
	local out: { string } = {}
	for index = 1, count do
		local place = "Side"
		if config.Enabled == true and #cycle > 0 then
			place = if index == count then "Top" else cycle[(index - 1) % #cycle + 1]
			if place == "Top" and not (if index == count then slam else stomp) then
				place = if index % 2 == 1 then "Side" else "Other"
			end
		end
		out[index] = place
	end
	return out
end

-- Ce que le perso joue à chaque action : sa place, l'action (Stomp ou Slam sur le colis, sinon celle du plan) et s'il
-- se téléporte avant (place différente de la précédente ; le perso commence à la place Side).
function UnboxPlan.moves(plan: Plan, stomp: boolean, slam: boolean): { Move }
	local steps = plan.Steps
	local places = UnboxPlan.places(#steps, stomp, slam)
	local out: { Move } = {}
	local previous = "Side"
	for index, step in steps do
		local place = places[index]
		local action = step.Action
		if place == "Top" then
			action = if index == #steps then New.Places.Slam else New.Places.Stomp
		end
		out[index] = { Action = action, Place = place, Teleport = place ~= previous }
		previous = place
	end
	return out
end

-- Temps avant une action : téléportation (L-258) ou pause à la même place.
function UnboxPlan.transition(teleport: boolean): number
	return if teleport then New.Places.Teleport / speed() else UnboxPlan.gap()
end

-- De la fin de l'intro au moment fort de la dernière action, aux durées de repli.
local function actionsTime(moves: { Move }): number
	local t = 0
	for index, move in moves do
		if move.Teleport or index > 1 then
			t += UnboxPlan.transition(move.Teleport)
		end
		local duration = UnboxPlan.actionTime(move.Action)
		if index < #moves then
			t += duration
		else
			local impacts = move.Action.Impacts
			t += duration * (impacts[#impacts] or 1)
		end
	end
	return t
end

-- Instant de la révélation (s depuis RevealStarted) d'un plan joué aux durées de repli ; `top` : Unbox_Stomp et
-- Unbox_Slam livrées.
function UnboxPlan.revealAt(plan: Plan, rarity: string, top: boolean?): number
	return New.Intro + actionsTime(UnboxPlan.moves(plan, top == true, top == true)) + afterBurst(rarity)
end

-- De la révélation à la fin (Land), en repli codé : croissance et tenue de Config/Reveal.
function UnboxPlan.tailTime(sizeClass: string): number
	local fallback: any = Reveal.Fallback
	local grow: number = fallback.GrowTime[sizeClass] or fallback.GrowTime.Small
	local land: number = fallback.LandHold[sizeClass] or fallback.LandHold.Small
	return New.AfterReveal + grow + land
end

-- Durée la plus longue possible d'une scène de `count` actions (par défaut : la plus longue pour `rarity`, toutes
-- les améliorations comprises), sans marge : chaque action à la plus longue (Stomp compris), coupée à
-- ActionMaxFactor, chaque transition à la plus longue (téléportation comprise), puis la fin au budget qu'avait déjà la
-- croissance (Reveal.MaxSeconds − Fallback.OpenEnd : une animation Grow<Classe> du rig de Clément peut durer plus
-- que le repli).
function UnboxPlan.longest(rarity: string, sizeClass: string, count: number?): number
	local finalAction = actionsById[New.FinalAction]
	local places = New.Places.Enabled == true
	local step = if places then UnboxPlan.actionLimit(New.Places.Stomp) else 0
	for _, action in New.Actions do
		if action ~= finalAction then
			step = math.max(step, UnboxPlan.actionLimit(action))
		end
	end
	local move = math.max(UnboxPlan.gap(), if places then UnboxPlan.transition(true) else 0)
	local n = math.clamp(math.floor(count or UnboxPlan.count(rarity, Unbox.UpgradeMax)), 1, UnboxPlan.MaxSteps)
	local final = math.max(if finalAction then UnboxPlan.actionLimit(finalAction) else 0, if places then UnboxPlan.actionLimit(New.Places.Slam) else 0)
	local maxSeconds: any = Reveal.MaxSeconds
	local budget: number = (maxSeconds[sizeClass] or maxSeconds.Small) - Reveal.Fallback.OpenEnd
	local tail = New.AfterReveal + math.max(budget, UnboxPlan.tailTime(sizeClass) - New.AfterReveal)
	return New.Intro + (n - 1) * (step + move) + move + final + afterBurst(rarity) + tail
end

-- Plafond du serveur (fin de la phase sans RevealDone) et plafond du client (la scène saute à sa fin), pour une
-- scène de `count` actions (le plan tiré ; par défaut la plus longue possible pour `rarity`).
function UnboxPlan.serverMaxSeconds(rarity: string, sizeClass: string, count: number?): number
	return UnboxPlan.longest(rarity, sizeClass, count) + New.ServerMargin
end

function UnboxPlan.clientMaxSeconds(rarity: string, sizeClass: string, count: number?): number
	return UnboxPlan.longest(rarity, sizeClass, count) + New.ClientMargin
end

-- Durées typiques (actions de durée moyenne, repli codé) d'un objet `rarity` sorti d'un colis amélioré `upgrades`
-- fois (0 par défaut), `top` : Unbox_Stomp et Unbox_Slam livrées. Rend l'instant de la révélation, puis la durée
-- totale jusqu'à Land.
function UnboxPlan.typical(rarity: string, sizeClass: string, upgrades: number?, top: boolean?): (number, number)
	local finalAction = actionsById[New.FinalAction]
	local sum, n = 0, 0
	for _, action in New.Actions do
		if action ~= finalAction then
			sum += action.Duration
			n += 1
		end
	end
	local mean: Action = { Id = "Mean", Anim = "", React = "Jump", Duration = if n > 0 then sum / n else 0, Impacts = { 1 } }
	local count = UnboxPlan.count(rarity, upgrades)
	local steps: { Step } = {}
	for index = 1, count do
		steps[index] = { Action = if index == count and finalAction then finalAction else mean, Rarity = rarity }
	end
	local reveal = UnboxPlan.revealAt({ Steps = steps, Odds = 1 }, rarity, top)
	return reveal, reveal + UnboxPlan.tailTime(sizeClass)
end

return UnboxPlan
