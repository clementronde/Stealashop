--!strict
-- GuardView (a433 ; Cantin, 2026-11-24 : « freiner l'image du vigile côté client ») : où le joueur poursuivi VOIT son
-- vigile. Calcul pur (des nombres, aucun service Roblox) : lu par client/Controllers/GuardViewController, joué hors
-- Studio par le banc a433. Valeurs et règle complète : Config/Chase.ClientView.Display (interrupteur Enabled).
--
-- Ce n'est que de l'affichage : le serveur ne reçoit rien et reste seul juge de la capture et des distances.
--
-- Le serveur n'apprend qu'un retard plus tard que le joueur a pilé : pendant ce temps son vigile continue, et à l'écran
-- du joueur il le traversait (vitesse × retard − 14 studs : ≈ 29 studs à 126 studs/s). Ici, l'image du vigile suit sa
-- vraie place (celle que Roblox réplique), mais elle reste derrière le joueur (Cantin, 24/11 : jamais de contournement,
-- « il doit rester bien derrière lui ») :
--   « derrière » = le côté du joueur où se trouve l'image. Ce côté est relevé tant que l'image est à SideRange studs ou
--   plus du joueur, et gardé de plus près ; il ne change de plus près que si le joueur traverse lui-même l'image.
--   1. libre : image = vraie place (aucun écart, rien ne change par rapport à a420) ;
--   2. elle n'entre jamais, par son propre mouvement, à moins de MinGap studs du joueur (à plat) : elle s'arrête au
--      bord du cercle ; et à moins de SideRange studs du joueur, elle reste MinGap studs derrière lui au moins (le
--      long de son côté) : ni à travers, ni à côté, ni devant ;
--   3. retenue (écart non nul) pendant que le vrai vigile est devant le joueur : elle se tient à MinGap studs derrière
--      lui, et s'il repart elle le suit, toujours derrière (au plus max(ReturnSpeed, distance × ReturnRate) studs/s) ;
--   4. elle ne rejoint la vraie place que quand le vrai vigile est revenu derrière le joueur (ou que le joueur, poussé
--      par la capture ou de lui-même, a traversé l'image) : l'écart fond alors de max(ReturnSpeed, écart × ReturnRate)
--      studs par seconde, sans saut, en ligne droite du côté « derrière » ;
--   5. un joueur qui entre lui-même dans le cercle (il fonce sur le vigile) n'est pas repoussé et ne repousse pas
--      l'image : elle ne s'approche plus (rayon du cercle = sa distance du moment).
--
--   local state = GuardView.new()
--   local x, z, held = GuardView.Step(state, cfg, guardX, guardZ, playerX, playerZ, dt, constrained)
--       guardX/Z : vraie place du vigile (répliquée) ; playerX/Z : le joueur local ; dt : durée de l'image (s) ;
--       constrained : false = pas de règle (joueur absent ; autre étage ou loin, sans écart en cours) : retour direct.
--       Rend la place affichée, et si l'image est retenue (arrêtée au bord, à la ligne, ou en train de suivre).
--   GuardView.Offset(state) -> (number, number)   écart affiché − vrai (0, 0 : rien à déplacer)
--   GuardView.Reset(state)

local GuardView = {}

export type Config = {
	Enabled: boolean,
	MinGap: number,
	SideRange: number,
	ReturnSpeed: number,
	ReturnRate: number,
}

export type State = {
	started: boolean,
	lastX: number, -- vraie place à l'image d'avant
	lastZ: number,
	offX: number, -- écart affiché − vrai
	offZ: number,
	sided: boolean, -- le côté « derrière » est connu
	sideX: number, -- du joueur vers « derrière » (unitaire)
	sideZ: number,
}

local EPSILON = 1e-4 -- tolérance du test « le trajet coupe le cercle » (studs)
local PASSED = 0.5 -- le joueur a traversé l'image quand elle est de plus que ceci devant lui (studs)

local function positive(value: any): boolean
	return type(value) == "number" and value > 0 and value < math.huge
end

function GuardView.new(): State
	return { started = false, lastX = 0, lastZ = 0, offX = 0, offZ = 0, sided = false, sideX = 0, sideZ = 0 }
end

function GuardView.Reset(state: State)
	state.started = false
	state.offX = 0
	state.offZ = 0
	state.sided = false
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
	constrained: boolean
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
	local speed = if positive(cfg.ReturnSpeed) then cfg.ReturnSpeed else math.huge
	local rate = if positive(cfg.ReturnRate) then cfg.ReturnRate else 0
	-- Place affichée à l'image d'avant.
	local fromX, fromZ = state.lastX + state.offX, state.lastZ + state.offZ
	state.lastX, state.lastZ = guardX, guardZ

	-- Place visée : la vraie place + l'écart, qui fond (retour en douceur).
	local offX, offZ = state.offX, state.offZ
	local gap = math.sqrt(offX * offX + offZ * offZ)
	local held = gap > 0
	if held then
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
		local ax, az = fromX - playerX, fromZ - playerZ
		local distance = math.sqrt(ax * ax + az * az)
		local range = if positive(cfg.SideRange) then cfg.SideRange else 0
		-- Le côté « derrière » : relevé de loin, gardé de près ; de près, il ne tourne que si le joueur a traversé l'image.
		if distance > 1e-6 then
			if not state.sided or distance >= range or ax * state.sideX + az * state.sideZ < -PASSED then
				state.sided = true
				state.sideX, state.sideZ = ax / distance, az / distance
			end
		end
		local sx, sz = state.sideX, state.sideZ
		local radius = math.min(cfg.MinGap, distance)
		-- « Derrière » se mesure le long du côté : `before` studs derrière le joueur pour l'image. À moins de SideRange
		-- studs du joueur, une place n'est permise qu'à `margin` studs derrière lui au moins (MinGap, ou moins si le
		-- joueur s'est lui-même rapproché) ; plus loin, il suffit d'être derrière.
		local before = ax * sx + az * sz
		local margin = math.min(cfg.MinGap, math.max(before, 0))
		local gx, gz = guardX - playerX, guardZ - playerZ
		local guardBehind = gx * sx + gz * sz
		local allowed = if gx * gx + gz * gz < range * range then guardBehind >= margin - EPSILON else guardBehind >= 0
		if held and state.sided and not allowed then
			-- Le vrai vigile n'est pas derrière le joueur : l'image se tient à MinGap derrière lui et le suit s'il repart.
			blocked = true
			toX, toZ = fromX, fromZ
			if distance >= cfg.MinGap then
				local tx, tz = playerX + sx * cfg.MinGap - fromX, playerZ + sz * cfg.MinGap - fromZ
				local far = math.sqrt(tx * tx + tz * tz)
				if far > 1e-9 then
					local move = math.min(far, math.max(speed, far * rate) * step)
					toX, toZ = fromX + tx / far * move, fromZ + tz / far * move
				end
			end
		end
		-- Le trajet ne coupe pas le cercle du joueur et, à moins de SideRange studs de lui, reste `margin` studs derrière.
		local mx, mz = toX - fromX, toZ - fromZ
		local length2 = mx * mx + mz * mz
		if length2 > 1e-12 then
			local share = 1
			local along = ax * mx + az * mz
			local nearest = math.clamp(-along / length2, 0, 1)
			local nx, nz = ax + mx * nearest, az + mz * nearest
			if math.sqrt(nx * nx + nz * nz) < radius - EPSILON then
				local inside = along * along - length2 * (distance * distance - radius * radius)
				share = if inside > 0 then math.clamp((-along - math.sqrt(inside)) / length2, 0, 1) else 0
			end
			if state.sided then
				local ex, ez = toX - playerX, toZ - playerZ
				local after = ex * sx + ez * sz
				if after < margin - EPSILON and ex * ex + ez * ez < range * range then
					share = math.min(share, if before > after then math.clamp((before - margin) / (before - after), 0, 1) else 0)
				end
			end
			if share < 1 then
				blocked = true
				toX, toZ = fromX + mx * share, fromZ + mz * share
			end
		end
	end

	state.offX, state.offZ = toX - guardX, toZ - guardZ
	if math.abs(state.offX) < 1e-6 and math.abs(state.offZ) < 1e-6 then
		state.offX, state.offZ = 0, 0
	end
	return toX, toZ, blocked
end

return GuardView
