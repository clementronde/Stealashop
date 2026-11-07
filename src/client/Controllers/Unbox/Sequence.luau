--!strict
-- Déroulé de l'ouverture des colis v2 (DEV-050, DEV-052 ; spec ouverture-colis, étapes 0 à 7),
-- module d'aide d'UnboxController (client). Il ne montre rien : il dit à la vue (Unbox/Screen)
-- quoi faire et quand, avec les durées de Config.Unbox.
--
--   Sequence.plan(reveal, rng) -> (Plan?, raison?)
--       Ce que la séquence montrera : rareté finale (celle de l'objet), version complète (Rare et
--       plus) ou courte, raretés des crans d'amélioration, revenu, composition du rouleau.
--   Sequence.times(plan) -> Times
--       Les moments prévus quand rien ne les déplace (ouverture au secours de 0,45 s, sans
--       SkipButton ni ralenti) : objet révélé (Reveal) à 4,9 s et boutons à 6,72 s en version
--       complète, 3,0 s et 4,37 s en courte, +0,9 s par cran.
--   Sequence.new(plan, view) -> Runner
--       runner:Update(dt)     à chaque image (dt réel, en secondes) ;
--       runner:OpenMarker()   l'animation Unbox passe son marqueur Open ;
--       runner:Skip()         SkipButton : pendant le rouleau, le gagnant arrive au centre en 0,4 s ;
--                             après, tout s'affiche d'un coup ;
--       runner:SinceButtons() temps depuis l'apparition des boutons (nil avant).
--
-- Temps de la séquence : il part de 0 à UnboxReveal et avance comme l'horloge, sauf pendant le
-- ralenti du Secret (×0,3 pendant 0,5 s réelles à l'éclat). Les étapes, dans l'ordre (événements
-- de la vue, appelés une fois chacun) :
--   Begin ; pour chaque cran k : Charge (charge de 0,5 s) puis Pop (le cran) ; PlayUnbox (l'animation
--   Unbox) ; Open (au marqueur Open, sinon 0,45 s plus tard ; si l'animation joue sans jamais
--   passer le marqueur : OpenMarkerTimeout) ; ScrollStart (après la sortie du colis) ; LastNotch
--   (dernier cran) ; ReelDone (gagnant au centre) ; ColorStart (après la pause) ; Reveal (couleurs
--   prises : l'éclat) ; RarityText ; ItemNameText ; IncomeStart ; IncomeDone ; Buttons.
-- Entre les événements, view:Frame(info) à chaque image, pour tout ce qui bouge.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Formulas = require(Config:WaitForChild("Formulas"))
local Items = require(Config:WaitForChild("Items"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Unbox = require(Config:WaitForChild("Unbox"))
local Zones = require(Config:WaitForChild("Zones"))
local Reel = require(script.Parent:WaitForChild("Reel"))

type Item = Items.Item
type Rarity = Rarities.Rarity

-- Ce qu'UnboxReveal apporte (Net/Definitions), déjà contrôlé par UnboxController.
export type Reveal = {
	BenchIndex: number,
	ItemUid: string,
	ItemId: string, -- objet final, après l'amélioration
	Zone: number, -- zone du colis
	Tier: string, -- type du colis
	StartRarity: string, -- rareté du colis avant l'amélioration
	Upgrades: number, -- crans réussis
}

export type Plan = {
	Reveal: Reveal,
	Item: Item,
	Rarity: Rarity, -- rareté finale : celle de l'objet
	Full: boolean, -- version complète (Rarity.FullReveal : Rare et plus), sinon courte
	Steps: { Rarity }, -- rareté atteinte à chaque cran, dans l'ordre
	Mismatch: boolean, -- StartRarity + crans ne tombe pas sur la rareté de l'objet (catalogues différents ?)
	Income: number?, -- $/s de l'objet (Formulas.ItemIncome, zone du colis) ; nil si la zone est inconnue
	Reel: Reel.Composition,
	ReelTime: number, -- durée du défilement (T de rollPos)
	CountTime: number, -- durée du comptage du revenu
}

export type Times = {
	Charges: { number },
	Pops: { number },
	Unbox: number,
	Open: number,
	ScrollStart: number,
	ScrollEnd: number,
	ReelDone: number,
	ColorStart: number,
	Reveal: number,
	Rarity: number,
	ItemName: number,
	Income: number,
	CountEnd: number,
	Buttons: number,
}

-- Ce que la vue reçoit à chaque image.
export type FrameInfo = {
	T: number, -- temps de la séquence
	Dt: number, -- avance de cette image, en temps de séquence
	At: { [string]: number }, -- moments déjà connus (clés de Times, sans Charges ni Pops)
	Charge: number?, -- 0 à 1 pendant la charge d'un cran, sinon nil
	ChargeStep: number?, -- numéro du cran en charge
	ReelPos: number?, -- index (fractionnaire) de l'objet au centre ; nil avant l'ouverture
	ReelDrop: number, -- décalage vers le bas (en cases) pendant la sortie du colis, de 1 à 0
	ReelSpeed: number, -- objets/s
}

export type View = {
	Begin: (self: any, plan: Plan) -> (),
	Charge: (self: any, step: number, rarity: Rarity, at: number) -> (),
	Pop: (self: any, step: number, rarity: Rarity, at: number) -> (),
	PlayUnbox: (self: any) -> boolean, -- true si l'animation Unbox joue (on attend son marqueur)
	Open: (self: any, fromMarker: boolean, at: number) -> (),
	ScrollStart: (self: any, at: number) -> (),
	LastNotch: (self: any, at: number) -> (),
	ReelDone: (self: any, at: number) -> (),
	ColorStart: (self: any, at: number) -> (),
	Reveal: (self: any, at: number) -> (),
	RarityText: (self: any, at: number) -> (),
	ItemNameText: (self: any, at: number) -> (),
	IncomeStart: (self: any, at: number) -> (),
	IncomeDone: (self: any, at: number) -> (),
	Buttons: (self: any, at: number) -> (),
	Frame: (self: any, info: FrameInfo) -> (),
}

local Sequence = {}

------------------------------------------------------------------------------
-- Courbes
------------------------------------------------------------------------------

local function clamp01(u: number): number
	return if u ~= u then 0 else math.clamp(u, 0, 1)
end
Sequence.clamp01 = clamp01

function Sequence.quadOut(u: number): number
	u = clamp01(u)
	return 1 - (1 - u) * (1 - u)
end

-- Back Out : dépasse un peu la cible, puis s'y pose.
function Sequence.backOut(u: number): number
	u = clamp01(u)
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (u - 1) ^ 3 + c1 * (u - 1) ^ 2
end

function Sequence.inOutCubic(u: number): number
	u = clamp01(u)
	return if u < 0.5 then 4 * u * u * u else 1 - (-2 * u + 2) ^ 3 / 2
end

-- Part du revenu affichée pendant le comptage (spec : 1 − (1 − u)³).
function Sequence.countCurve(u: number): number
	u = clamp01(u)
	return 1 - (1 - u) ^ 3
end

------------------------------------------------------------------------------
-- Plan
------------------------------------------------------------------------------

function Sequence.plan(reveal: Reveal, rng: Random): (Plan?, string?)
	local item = Items.ById[reveal.ItemId]
	if item == nil then
		return nil, `objet inconnu du catalogue client : {reveal.ItemId}`
	end
	local rarity = Rarities.ById[item.Rarity]
	if rarity == nil then
		return nil, `rareté inconnue : {item.Rarity}`
	end
	-- Chaque cran monte d'une rareté : les crans sont les n raretés qui mènent à celle de l'objet.
	local upgrades = if reveal.Upgrades == reveal.Upgrades then math.floor(reveal.Upgrades) else 0
	local n = math.clamp(upgrades, 0, rarity.Order - 1)
	local steps: { Rarity } = {}
	for k = 1, n do
		steps[k] = Rarities.List[rarity.Order - n + k]
	end
	local start = Rarities.ById[reveal.StartRarity]
	local mismatch = start == nil or start.Order + upgrades ~= rarity.Order
	-- Même zone que DisplayService : celle du catalogue, sinon celle du colis (Secret).
	local zone = item.Zone or reveal.Zone
	local income = if Zones[zone] ~= nil then Formulas.ItemIncome(zone, rarity.Id) else nil
	local full = rarity.FullReveal
	return {
		Reveal = reveal,
		Item = item,
		Rarity = rarity,
		Full = full,
		Steps = steps,
		Mismatch = mismatch,
		Income = income,
		Reel = Reel.compose(reveal.Zone, reveal.Tier, item, full, rng),
		ReelTime = if full then Unbox.ReelDuration.Full else Unbox.ReelDuration.Short,
		CountTime = if full then Unbox.IncomeCount.Full else Unbox.IncomeCount.Short,
	},
		nil
end

-- Moments qui suivent la fin du rouleau (`reelDone`) : mêmes calculs dans times et dans le déroulé.
local function afterReel(at: { [string]: number }, reelDone: number, countTime: number)
	at.ReelDone = reelDone
	at.ColorStart = reelDone + Unbox.StopPause
	at.Reveal = at.ColorStart + Unbox.ColorIn
	at.Rarity = at.Reveal + Unbox.TextsAt
	at.ItemName = at.Rarity + Unbox.ItemNameAfter
	at.Income = at.ItemName + Unbox.IncomeAfter
	at.CountEnd = at.Income + countTime
	at.Buttons = at.CountEnd + Unbox.ButtonsAfter
end

-- Moments qui suivent l'ouverture (`open`).
local function afterOpen(at: { [string]: number }, open: number, plan: Plan)
	at.Open = open
	at.ScrollStart = open + Unbox.ReelExit
	at.ScrollEnd = at.ScrollStart + plan.ReelTime
	afterReel(at, at.ScrollEnd + Unbox.LastNotch, plan.CountTime)
end

function Sequence.times(plan: Plan): Times
	local charges: { number } = {}
	local pops: { number } = {}
	for k = 1, #plan.Steps do
		charges[k] = (k - 1) * Unbox.UpgradeStep
		pops[k] = charges[k] + Unbox.UpgradeCharge
	end
	local at: { [string]: number } = {}
	at.Unbox = #plan.Steps * Unbox.UpgradeStep
	afterOpen(at, at.Unbox + Unbox.OpenFallback, plan)
	return {
		Charges = charges,
		Pops = pops,
		Unbox = at.Unbox,
		Open = at.Open,
		ScrollStart = at.ScrollStart,
		ScrollEnd = at.ScrollEnd,
		ReelDone = at.ReelDone,
		ColorStart = at.ColorStart,
		Reveal = at.Reveal,
		Rarity = at.Rarity,
		ItemName = at.ItemName,
		Income = at.Income,
		CountEnd = at.CountEnd,
		Buttons = at.Buttons,
	}
end

------------------------------------------------------------------------------
-- Déroulé
------------------------------------------------------------------------------

type Glide = { from: number, start: number }

type RunnerFields = {
	plan: Plan,
	view: View,
	T: number,
	At: { [string]: number },
	fired: { [string]: boolean },
	firedAt: { [string]: number }, -- moment prévu de chaque événement passé (bancs d'essai)
	charges: { number },
	pops: { number },
	waitingMarker: boolean, -- Unbox joue, on attend son marqueur Open
	openedByMarker: boolean,
	markerDeadline: number,
	glide: Glide?,
	slowLeft: number, -- ralenti restant (secondes réelles)
	lastPos: number?,
}

local Runner = {}
Runner.__index = Runner

export type Runner = typeof(setmetatable({} :: RunnerFields, Runner))

function Sequence.new(plan: Plan, view: View): Runner
	local charges: { number } = {}
	local pops: { number } = {}
	for k = 1, #plan.Steps do
		charges[k] = (k - 1) * Unbox.UpgradeStep
		pops[k] = charges[k] + Unbox.UpgradeCharge
	end
	local fields: RunnerFields = {
		plan = plan,
		view = view,
		T = 0,
		At = { Unbox = #plan.Steps * Unbox.UpgradeStep },
		fired = {},
		firedAt = {},
		charges = charges,
		pops = pops,
		waitingMarker = false,
		openedByMarker = false,
		markerDeadline = math.huge,
		glide = nil,
		slowLeft = 0,
		lastPos = nil,
	}
	return setmetatable(fields, Runner)
end

-- Position du rouleau au temps `t` (nil avant l'ouverture).
local function reelPos(self: Runner, t: number): number?
	local at = self.At
	local open = at.Open
	if open == nil or t < open then
		return nil
	end
	local comp = self.plan.Reel
	local glide = self.glide
	if glide then
		local u = (t - glide.start) / Unbox.SkipGlide
		return glide.from + (comp.Winner - glide.from) * Sequence.quadOut(u)
	end
	if t < at.ScrollStart then
		return comp.Start
	end
	if t < at.ScrollEnd then
		local L = comp.Stop - comp.Start
		return comp.Start
			+ Reel.rollPos(t - at.ScrollStart, self.plan.ReelTime, Unbox.ReelAccel, Unbox.ReelBrake, L)
	end
	if t < at.ReelDone then
		local u = (t - at.ScrollEnd) / Unbox.LastNotch
		return comp.Stop + (comp.Winner - comp.Stop) * Sequence.backOut(u)
	end
	return comp.Winner
end

-- Prochain événement pas encore passé : nom, moment (nil s'il n'est pas encore connu), argument.
local function nextEvent(self: Runner): (string?, number?, number?)
	local fired = self.fired
	for k = 1, #self.charges do
		if not fired[`Charge{k}`] then
			return `Charge{k}`, self.charges[k], k
		end
		if not fired[`Pop{k}`] then
			return `Pop{k}`, self.pops[k], k
		end
	end
	for _, name in { "Unbox", "Open", "ScrollStart", "LastNotch", "ReelDone", "ColorStart", "Reveal", "Rarity", "ItemName", "Income", "CountEnd", "Buttons" } do
		if not fired[name] then
			local key = if name == "LastNotch" then "ScrollEnd" else name
			return name, self.At[key], nil
		end
	end
	return nil, nil, nil
end

local function fire(self: Runner, name: string, at: number, arg: number?)
	self.fired[name] = true
	self.firedAt[name] = at
	local view = self.view
	local plan = self.plan
	if arg ~= nil and string.sub(name, 1, 6) == "Charge" then
		view:Charge(arg, plan.Steps[arg], at)
	elseif arg ~= nil and string.sub(name, 1, 3) == "Pop" then
		view:Pop(arg, plan.Steps[arg], at)
	elseif name == "Unbox" then
		if view:PlayUnbox() then
			self.waitingMarker = true
			self.markerDeadline = at + Unbox.OpenMarkerTimeout
		else
			afterOpen(self.At, at + Unbox.OpenFallback, plan)
		end
	elseif name == "Open" then
		-- fromMarker = false : ouverture au secours (sans animation, ou marqueur jamais passé) ;
		-- la vue joue alors elle-même le son du marqueur.
		self.waitingMarker = false
		view:Open(self.openedByMarker, at)
	elseif name == "ScrollStart" then
		view:ScrollStart(at)
	elseif name == "LastNotch" then
		view:LastNotch(at)
	elseif name == "ReelDone" then
		view:ReelDone(at)
	elseif name == "ColorStart" then
		view:ColorStart(at)
	elseif name == "Reveal" then
		if plan.Rarity.SlowMotion then
			self.slowLeft = Unbox.SlowMotionTime
		end
		view:Reveal(at)
	elseif name == "Rarity" then
		view:RarityText(at)
	elseif name == "ItemName" then
		view:ItemNameText(at)
	elseif name == "Income" then
		view:IncomeStart(at)
	elseif name == "CountEnd" then
		view:IncomeDone(at)
	elseif name == "Buttons" then
		view:Buttons(at)
	end
end

-- Passe tous les événements dont le moment est atteint, dans l'ordre.
local function process(self: Runner)
	if not self.fired.Begin then
		self.fired.Begin = true
		self.firedAt.Begin = 0
		self.view:Begin(self.plan)
	end
	while true do
		if self.waitingMarker and self.At.Open == nil and self.T >= self.markerDeadline then
			-- Animation Unbox livrée, mais son marqueur Open n'est jamais venu : on ouvre quand même.
			afterOpen(self.At, self.markerDeadline, self.plan)
		end
		local name, at, arg = nextEvent(self)
		if name == nil or at == nil or at > self.T then
			return
		end
		fire(self, name, at, arg)
	end
end

local function frame(self: Runner, dt: number)
	local t = self.T
	local charge: number? = nil
	local chargeStep: number? = nil
	for k = 1, #self.charges do
		if t >= self.charges[k] and t < self.pops[k] then
			charge = (t - self.charges[k]) / Unbox.UpgradeCharge
			chargeStep = k
		end
	end
	local pos = reelPos(self, t)
	local speed = 0
	local last = self.lastPos
	if pos ~= nil and last ~= nil and dt > 0 then
		speed = math.abs(pos - last) / dt
	end
	self.lastPos = pos
	local drop = 0
	local open = self.At.Open
	if open ~= nil and t >= open and t < self.At.ScrollStart and self.glide == nil then
		drop = 1 - Sequence.quadOut((t - open) / Unbox.ReelExit)
	end
	self.view:Frame({
		T = t,
		Dt = dt,
		At = self.At,
		Charge = charge,
		ChargeStep = chargeStep,
		ReelPos = pos,
		ReelDrop = drop,
		ReelSpeed = speed,
	})
end

function Runner.Update(self: Runner, dt: number)
	local step = math.max(dt, 0)
	if self.slowLeft > 0 then
		local slow = math.min(step, self.slowLeft)
		self.slowLeft -= slow
		step = slow * Unbox.SlowMotionScale + (step - slow)
	end
	self.T += step
	process(self)
	frame(self, step)
end

function Runner.OpenMarker(self: Runner)
	if self.waitingMarker and self.At.Open == nil then
		self.openedByMarker = true
		afterOpen(self.At, self.T, self.plan)
		process(self)
	end
end

function Runner.Skip(self: Runner)
	if self.fired.Buttons or not self.fired.Open then
		return -- rien à passer avant le rouleau (crans, ouverture) ni après les boutons
	end
	if not self.fired.ReelDone then
		if self.glide ~= nil then
			return
		end
		-- Pendant le rouleau : le gagnant arrive au centre en SkipGlide (0,4 s).
		local from = reelPos(self, self.T) or self.plan.Reel.Start
		self.glide = { from = from, start = self.T }
		self.fired.ScrollStart = true
		self.firedAt.ScrollStart = self.firedAt.ScrollStart or self.T
		if not self.fired.LastNotch then
			fire(self, "LastNotch", self.T, nil)
		end
		afterReel(self.At, self.T + Unbox.SkipGlide, self.plan.CountTime)
		return
	end
	-- Après le rouleau : tout s'affiche d'un coup (éclat, textes, revenu, boutons), sans ralenti.
	self.T = math.max(self.T, self.At.Buttons)
	process(self)
	self.slowLeft = 0
	frame(self, 0)
end

function Runner.SinceButtons(self: Runner): number?
	if not self.fired.Buttons then
		return nil
	end
	return self.T - self.At.Buttons
end

function Runner.IsFired(self: Runner, name: string): boolean
	return self.fired[name] == true
end

-- Moment prévu d'un événement passé (nil s'il n'est pas encore passé).
function Runner.FiredAt(self: Runner, name: string): number?
	return self.firedAt[name]
end

return Sequence
