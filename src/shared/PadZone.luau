--!strict
-- PadZone (a472, liaison L-365) : le volume d'une plaque CollectPad_xx où l'on ramasse, et la règle d'arrivée sur une
-- plaque, partagés par le serveur (DisplayService, seul juge de l'argent) et le client (GainController, qui prévoit le
-- ramassage pour jouer le son et le voile sans attendre le serveur, L-365 point 5). Les valeurs sont celles que
-- DisplayService avait en dur avant a472 (V0 proposés, absents du doc ; vague 24, L-106 point 12) : rien ne change
-- côté serveur.
--
-- API :
--   PadZone.Margin, Below, Above              volume d'arrivée : l'emprise de la plaque élargie de Margin sur les côtés,
--                                             de Below sous son dessus à Above au-dessus (studs)
--   PadZone.ExitMargin, ExitAbove, ExitDelay  zone de sortie, plus large, et temps passé hors d'elle avant de pouvoir
--                                             ramasser de nouveau la même plaque (studs, s)
--   PadZone.Cooldown                          délai d'une même plaque entre deux ramassages (s, L-106 point 12)
--   PadZone.isOnPad(position, pad, margin?, above?) -> boolean
--   PadZone.isNearPad(position, pad) -> boolean
--   PadZone.newTracker() -> Tracker           côté client : l'état « sur quelle plaque suis-je » du joueur local
--   PadZone.step(tracker, now, position, pads, shown) -> number?
--       Une image : la plaque où le joueur vient d'arriver et que le serveur va vider tout de suite (même règle que
--       DisplayService.checkPads : arrivée, délai de la plaque écoulé, plaque affichée), sinon nil.
--   PadZone.touched(tracker, now, position, pads, slot, shown) -> number?
--       Contact d'une partie du personnage avec la plaque `slot` (même règle que DisplayService.onPadTouched).
--   PadZone.confirm(tracker, slot, now)       le serveur a vidé la plaque `slot` (remote CashCollect) : son délai repart.

local PadZone = {
	Margin = 0.5,
	Below = 1,
	Above = 6, -- le HumanoidRootPart d'un R15 debout est à environ 3 studs du sol
	ExitMargin = 2,
	ExitAbove = 12, -- un saut monte d'environ 7 studs
	ExitDelay = 0.3,
	Cooldown = 1,
}

-- `position` dans le volume de la plaque élargi de `margin` sur les côtés, jusqu'à `above` au-dessus.
-- La hauteur se lit sur l'axe de la plaque le plus tourné vers le ciel : Clément pose ses plaques à plat avec
-- l'épaisseur sur Y ou sur Z (plaques carrées tournées vers la porte, L-091), dans un sens ou dans l'autre.
function PadZone.isOnPad(position: Vector3, pad: BasePart, margin: number?, above: number?): boolean
	local side = margin or PadZone.Margin
	local cf = pad.CFrame
	local p = cf:PointToObjectSpace(position)
	local half = pad.Size / 2
	-- Le haut du monde vu dans le repère de la plaque : composante verticale de ses axes X, Y et Z.
	local up = cf:PointToObjectSpace(cf.Position + Vector3.new(0, 1, 0))
	local ups = { up.X, up.Y, up.Z }
	local coords = { p.X, p.Y, p.Z }
	local halves = { half.X, half.Y, half.Z }
	local axis = 1
	for i = 2, 3 do
		if math.abs(ups[i]) > math.abs(ups[axis]) then
			axis = i
		end
	end
	for i = 1, 3 do
		if i ~= axis and math.abs(coords[i]) > halves[i] + side then
			return false
		end
	end
	local height = if ups[axis] >= 0 then coords[axis] else -coords[axis]
	return height >= halves[axis] - PadZone.Below and height <= halves[axis] + (above or PadZone.Above)
end

-- `position` encore dans la zone de sortie de la plaque.
function PadZone.isNearPad(position: Vector3, pad: BasePart): boolean
	return PadZone.isOnPad(position, pad, PadZone.ExitMargin, PadZone.ExitAbove)
end

------------------------------------------------------------------------------
-- Côté client : arrivée prévue sur une plaque (L-365 point 5)
------------------------------------------------------------------------------

export type Tracker = {
	onSlot: number?, -- plaque où se tient le joueur (comme Account.onSlot du serveur)
	seenAt: number, -- dernier signe de présence sur onSlot
	lastAt: { [number]: number }, -- dernier ramassage connu ou prévu de chaque plaque (Cooldown)
}

function PadZone.newTracker(): Tracker
	return { onSlot = nil, seenAt = -math.huge, lastAt = {} }
end

-- Arrivée sur `slot` : prévue si le délai de la plaque est écoulé et si elle est affichée (au moins 1 $). Sinon le
-- serveur attendra la fin du délai, ou n'aura rien à donner : rien n'est prévu, le remote fera tout comme avant.
local function arrive(tracker: Tracker, now: number, slot: number, shown: (slot: number) -> boolean): number?
	tracker.onSlot = slot
	tracker.seenAt = now
	local last = tracker.lastAt[slot]
	if last and now - last < PadZone.Cooldown then
		return nil
	end
	if not shown(slot) then
		return nil
	end
	tracker.lastAt[slot] = now
	return slot
end

-- Plaques dans l'ordre de leur numéro (le serveur prend la première qu'il trouve ; deux plaques ne se chevauchent pas).
local function sortedSlots(pads: { [number]: BasePart }): { number }
	local slots: { number } = {}
	for slot in pads do
		table.insert(slots, slot)
	end
	table.sort(slots)
	return slots
end

function PadZone.step(tracker: Tracker, now: number, position: Vector3?, pads: { [number]: BasePart }, shown: (slot: number) -> boolean): number?
	local onSlot = tracker.onSlot
	local current = if onSlot then pads[onSlot] else nil
	if position and current and PadZone.isOnPad(position, current) then
		tracker.seenAt = now -- encore sur sa plaque : elle garde la priorité sur une voisine
		return nil
	end
	local found: number? = nil
	if position then
		for _, slot in sortedSlots(pads) do
			if PadZone.isOnPad(position, pads[slot]) then
				found = slot
				break
			end
		end
	end
	if found and found ~= onSlot then
		return arrive(tracker, now, found, shown)
	elseif onSlot then
		if position and current and PadZone.isNearPad(position, current) then
			tracker.seenAt = now
		elseif now - tracker.seenAt >= PadZone.ExitDelay then
			tracker.onSlot = nil -- vraiment sorti : la prochaine arrivée compte de nouveau
		end
	end
	return nil
end

function PadZone.touched(tracker: Tracker, now: number, position: Vector3, pads: { [number]: BasePart }, slot: number, shown: (slot: number) -> boolean): number?
	local pad = pads[slot]
	if not pad then
		return nil
	end
	if tracker.onSlot == slot then
		tracker.seenAt = now -- toujours dessus
		return nil
	end
	-- Un pied ou une main qui touche la plaque loin du corps ne compte pas, ni le bord d'une plaque voisine tant que le
	-- joueur se tient encore sur la sienne.
	if not PadZone.isNearPad(position, pad) then
		return nil
	end
	local onSlot = tracker.onSlot
	local current = if onSlot then pads[onSlot] else nil
	if current and PadZone.isOnPad(position, current) then
		return nil
	end
	return arrive(tracker, now, slot, shown)
end

function PadZone.confirm(tracker: Tracker, slot: number, now: number)
	local last = tracker.lastAt[slot]
	if last == nil or now > last then
		tracker.lastAt[slot] = now
	end
end

return PadZone
