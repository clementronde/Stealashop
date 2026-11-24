--!strict
-- Guard/ChaseLaw (serveur, a443 ; Cantin, 2026-11-24, refonte de la poursuite : fiche docs/references/Poursuite.md) :
-- la loi de vitesse et de distance de la poursuite « V3 ». Calcul pur (des nombres, aucun service Roblox) : lu par
-- GuardService, joué hors Studio par le banc a443. Valeurs et règle complète : Config/Chase.V3.
--
--   ChaseLaw.Distance(cfg, walk) -> number
--       Distance de croisière D (studs) : max(HoldDistance, HoldSeconds × marche du voleur).
--   ChaseLaw.Flee(cfg, walk, away) -> number
--       À quel point le voleur fuit, de 0 (il ne fuit plus : arrêté, demi-tour, il ralentit) à 1 (il fuit) : `away` =
--       la part de sa vitesse reçue qui l'éloigne du vigile (studs/s) ; 0 sous FleeLow × marche, 1 au-dessus de
--       FleeHigh × marche, en ligne droite entre les deux.
--   ChaseLaw.Speed(cfg, base, walk, gap, away) -> (number, number)
--       Vitesse du poursuivant (studs/s) et D, pour sa vitesse propre `base`, la marche du voleur `walk` (donnée par le
--       serveur) et l'écart `gap` (studs, à plat, jusqu'à la position estimée du voleur) :
--         retour   = walk + ReturnGain × (gap − D)
--         plancher = base quand il fuit ; max(base, walk) quand il ne fuit plus ; entre les deux selon Flee
--         v        = clamp(max(plancher, retour), 0, max(base, walk × (1 + ReturnSurplusFactor)))
--       Ce que cela donne :
--         vigile plus lent (base < walk), voleur qui court droit : v = walk à gap = D, il se cale à D et y reste ; écart
--           en trop : il revient vite puis de moins en moins (l'écart en trop fond de moitié en ln 2 / ReturnGain s),
--           sans dépasser D ; écart perdu (gap < D) : il retombe vers base, l'écart revient à D ;
--         vigile plus rapide (base > walk) : v = base dès que le retour passe dessous : rapprochement constant
--           base − walk, sans ruée ni frein, jusqu'à la capture ;
--         voleur qui s'arrête ou ralentit : v ≥ walk (sa marche, pas sa vitesse du moment) : attrapé en D / walk s au plus.
--       Une marche nulle (voleur immobilisé) : v = base.

local ChaseLaw = {}

export type Config = {
	HoldDistance: number,
	HoldSeconds: number,
	ReturnGain: number,
	ReturnSurplusFactor: number,
	FleeLow: number,
	FleeHigh: number,
}

local function positive(value: any): boolean
	return type(value) == "number" and value > 0 and value < math.huge
end

function ChaseLaw.Distance(cfg: Config, walk: number): number
	local hold = if positive(cfg.HoldDistance) then cfg.HoldDistance else 0
	local seconds = if positive(cfg.HoldSeconds) then cfg.HoldSeconds else 0
	return math.max(hold, seconds * (if positive(walk) then walk else 0))
end

function ChaseLaw.Flee(cfg: Config, walk: number, away: number): number
	if not positive(walk) then
		return 0
	end
	local share = if away == away then away / walk else 0
	local low = if positive(cfg.FleeLow) then cfg.FleeLow else 0
	local high = if positive(cfg.FleeHigh) then cfg.FleeHigh else low
	if high <= low then
		return if share >= high then 1 else 0
	end
	return math.clamp((share - low) / (high - low), 0, 1)
end

function ChaseLaw.Speed(cfg: Config, base: number, walk: number, gap: number, away: number): (number, number)
	local own = if positive(base) then base else 0
	local theirs = if positive(walk) then walk else 0
	local distance = ChaseLaw.Distance(cfg, theirs)
	local gain = if positive(cfg.ReturnGain) then cfg.ReturnGain else 0
	local back = theirs + gain * (gap - distance)
	local floor = own
	if theirs > own then
		floor = theirs + (own - theirs) * ChaseLaw.Flee(cfg, theirs, away)
	end
	local surplus = if positive(cfg.ReturnSurplusFactor) then cfg.ReturnSurplusFactor else 0
	local top = math.max(own, theirs * (1 + surplus))
	local speed = math.clamp(math.max(floor, back), 0, top)
	return if speed == speed then speed else own, distance
end

return ChaseLaw
