--!strict
-- GuardView (a433 ; Cantin, 2026-11-24 : « freiner l'image du vigile côté client ») : où le joueur poursuivi VOIT son
-- vigile. Calcul pur (des nombres, aucun service Roblox) : lu par client/Controllers/GuardViewController, joué hors
-- Studio par le banc a433. Valeurs et règle complète : Config/Chase.ClientView.Display (interrupteur Enabled).
--
-- Ce n'est que de l'affichage : le serveur ne reçoit rien et reste seul juge de la capture et des distances.
--
-- Le serveur n'apprend qu'un retard plus tard que le joueur a pilé : pendant ce temps son vigile continue, et à l'écran
-- du joueur il le traversait (vitesse × retard − 14 studs : ≈ 29 studs à 126 studs/s). Ici, l'image du vigile suit sa
-- vraie place (celle que Roblox réplique), sauf qu'elle n'entre jamais, par son propre mouvement, dans le cercle de
-- MinGap studs autour du joueur (à plat) :
--   1. libre : image = vraie place (aucun écart, rien ne change par rapport à a420) ;
--   2. son trajet couperait le cercle : elle s'arrête au bord (arrêt net, à MinGap studs), du côté d'où elle vient ;
--   3. bloquée, elle contourne le joueur le long du cercle (SlideSpeed studs/s) vers le côté où est le vrai vigile,
--      mais seulement après SlideDelay s de blocage et si le vrai vigile est à SlideRange studs au plus du joueur (il
--      est revenu près de lui), ou après HoldMax s, ou tout de suite quand la poursuite est finie (`releasing`) ;
--   4. redevenue libre, elle rejoint la vraie place en douceur : l'écart fond de max(ReturnSpeed, écart × ReturnRate)
--      studs par seconde, sans saut ;
--   5. un joueur qui entre lui-même dans le cercle (il fonce sur le vigile) n'est pas repoussé et ne repousse pas
--      l'image : elle ne s'approche plus (rayon du cercle = sa distance du moment) et repart dès qu'elle s'éloigne.
--
--   local state = GuardView.new()
--   local x, z, blocked = GuardView.Step(state, cfg, guardX, guardZ, playerX, playerZ, dt, constrained, releasing)
--       guardX/Z : vraie place du vigile (répliquée) ; playerX/Z : le joueur local ; dt : durée de l'image (s) ;
--       constrained : false = pas de cercle (joueur absent, autre étage) ; releasing : poursuite finie, retour sans
--       attendre. Rend la place affichée, et si l'image est bloquée au bord du cercle.
--   GuardView.Offset(state) -> (number, number)   écart affiché − vrai (0, 0 : rien à déplacer)
--   GuardView.Reset(state)

local GuardView = {}

export type Config = {
	Enabled: boolean,
	MinGap: number,
	SlideDelay: number,
	SlideRange: number,
	HoldMax: number,
	SlideSpeed: number,
	ReturnSpeed: number,
	ReturnRate: number,
}

export type State = {
	started: boolean,
	lastX: number, -- vraie place à l'image d'avant
	lastZ: number,
	offX: number, -- écart affiché − vrai
	offZ: number,
	blocked: number, -- temps passé bloqué au bord du cercle (s)
	side: number, -- sens du contournement en cours (1, −1 ; 0 : aucun)
}

local EPSILON = 1e-4 -- tolérance du test « le trajet coupe le cercle » (studs)
local MIN_RADIUS = 0.5 -- rayon minimal pour convertir une vitesse le long du cercle en angle (studs)

local function positive(value: any): boolean
	return type(value) == "number" and value > 0 and value < math.huge
end

function GuardView.new(): State
	return { started = false, lastX = 0, lastZ = 0, offX = 0, offZ = 0, blocked = 0, side = 0 }
end

function GuardView.Reset(state: State)
	state.started = false
	state.offX = 0
	state.offZ = 0
	state.blocked = 0
	state.side = 0
end

function GuardView.Offset(state: State): (number, number)
	return state.offX, state.offZ
end

function GuardView.Step(
	state: State,
	cfg: Config,
	guardX: number,
	guardZ: number,
	playerX: number,
	playerZ: number,
	dt: number,
	constrained: boolean,
	releasing: boolean
): (number, number, boolean)
	if cfg.Enabled ~= true or not positive(cfg.MinGap) then
		GuardView.Reset(state)
		return guardX, guardZ, false -- interrupteur coupé : l'état d'a420
	end
	if not state.started then
		state.started = true
		state.lastX, state.lastZ = guardX, guardZ
	end
	local step = if positive(dt) then dt else 0
	-- Place affichée à l'image d'avant.
	local fromX, fromZ = state.lastX + state.offX, state.lastZ + state.offZ
	state.lastX, state.lastZ = guardX, guardZ

	-- Place visée : la vraie place + l'écart, qui fond (retour en douceur).
	local offX, offZ = state.offX, state.offZ
	local gap = math.sqrt(offX * offX + offZ * offZ)
	if gap > 0 then
		local speed = if positive(cfg.ReturnSpeed) then cfg.ReturnSpeed else math.huge
		local rate = if positive(cfg.ReturnRate) then cfg.ReturnRate else 0
		local melt = math.max(speed, gap * rate) * step
		if melt >= gap then
			offX, offZ = 0, 0
		else
			local keep = (gap - melt) / gap
			offX, offZ = offX * keep, offZ * keep
		end
	end
	local toX, toZ = guardX + offX, guardZ + offZ

	local blocked = false
	if constrained then
		-- Cercle autour du joueur : MinGap, ou la distance du moment si le joueur est entré dedans.
		local ax, az = fromX - playerX, fromZ - playerZ
		local distance = math.sqrt(ax * ax + az * az)
		local radius = math.min(cfg.MinGap, distance)
		local mx, mz = toX - fromX, toZ - fromZ
		local length2 = mx * mx + mz * mz
		if length2 > 1e-12 then
			local along = ax * mx + az * mz
			local nearest = math.clamp(-along / length2, 0, 1)
			local nx, nz = ax + mx * nearest, az + mz * nearest
			if math.sqrt(nx * nx + nz * nz) < radius - EPSILON then
				-- Le trajet coupe le cercle : arrêt à l'entrée.
				blocked = true
				local inside = along * along - length2 * (distance * distance - radius * radius)
				local entry = if inside > 0 then math.clamp((-along - math.sqrt(inside)) / length2, 0, 1) else 0
				toX, toZ = fromX + mx * entry, fromZ + mz * entry
			end
		end
		if blocked then
			state.blocked += step
			local gx, gz = guardX - playerX, guardZ - playerZ
			local near = positive(cfg.SlideRange) and math.sqrt(gx * gx + gz * gz) <= cfg.SlideRange
			local delay = if positive(cfg.SlideDelay) then cfg.SlideDelay else 0
			local slide = releasing
				or (near and state.blocked >= delay)
				or (positive(cfg.HoldMax) and state.blocked >= cfg.HoldMax)
			local bx, bz = toX - playerX, toZ - playerZ
			local reach = math.sqrt(bx * bx + bz * bz)
			if slide and positive(cfg.SlideSpeed) and reach > 1e-6 and (gx ~= 0 or gz ~= 0) then
				-- Contournement : le long du cercle, vers le côté du vrai vigile, toujours dans le même sens.
				local from = math.atan2(bz, bx)
				local turn = (math.atan2(gz, gx) - from + math.pi) % (2 * math.pi) - math.pi
				if state.side == 0 or math.abs(turn) < math.pi / 2 then
					state.side = if turn < 0 then -1 else 1
				end
				local left = if (turn < 0) == (state.side < 0) then math.abs(turn) else 2 * math.pi - math.abs(turn)
				local angle = from + state.side * math.min(left, cfg.SlideSpeed * step / math.max(reach, MIN_RADIUS))
				toX, toZ = playerX + math.cos(angle) * reach, playerZ + math.sin(angle) * reach
			end
		else
			state.blocked = 0
			state.side = 0
		end
	else
		state.blocked = 0
		state.side = 0
	end

	state.offX, state.offZ = toX - guardX, toZ - guardZ
	if math.abs(state.offX) < 1e-6 and math.abs(state.offZ) < 1e-6 then
		state.offX, state.offZ = 0, 0
	end
	return toX, toZ, blocked
end

return GuardView
