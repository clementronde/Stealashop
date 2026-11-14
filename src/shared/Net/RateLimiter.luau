--!strict
-- Limite de débit d'un remote pour un joueur (ReplicatedStorage/Shared/Net/RateLimiter).
--
-- Fenêtre glissante : au plus `limit` appels acceptés sur toute période d'une
-- seconde, ce qui colle au texte du doc (« ≤ 10 coups/s »). On garde l'heure
-- des `limit` derniers appels acceptés dans un anneau : un appel passe si le
-- plus ancien date d'au moins une seconde. Coût constant par appel.
-- Une limite de 0 refuse tout (sert aux remotes serveur → client appelés par un client).
--
-- Débit régulier (RateLimiter.new(limit, jitter), vague 40) : pour un remote que le client envoie EXACTEMENT
-- au débit permis (HitWindow : 5 coups/s, un envoi toutes les 0,2 s). Avec la fenêtre glissante, le moindre
-- écart du réseau fait arriver le 6e appel 0,99 s après le 1er : il est refusé, et un coup est perdu (mesuré
-- au banc a134 : 46 coups sur 50 à 5 envois par seconde réguliers). Ici, un seau à jetons : `limit` jetons
-- par seconde, 1 + `jitter` jetons au plus en réserve, un jeton par appel. Sur la durée, jamais plus de
-- `limit` appels par seconde (limit × t + 1 + jitter appels en t secondes) ; un appel peut seulement arriver
-- jusqu'à jitter / limit secondes en avance sur le rythme sans être perdu.

export type Window = {
	limit: number,
	times: { number }, -- heures (os.clock) des derniers appels acceptés
	cursor: number, -- case du plus ancien
	dropped: number, -- appels refusés pas encore signalés (utilisé par Net)
	lastReport: number, -- heure du dernier signalement (utilisé par Net)
	-- Débit régulier seulement (nil : fenêtre glissante) :
	capacity: number?, -- jetons au plus en réserve (1 + jitter)
	tokens: number?, -- jetons en réserve
	refilledAt: number?, -- heure du dernier remplissage
}

local WINDOW_SECONDS = 1

local RateLimiter = {}

function RateLimiter.new(limit: number, jitter: number?): Window
	local window: Window = {
		limit = limit,
		times = table.create(limit, -math.huge),
		cursor = 1,
		dropped = 0,
		lastReport = -math.huge,
	}
	if jitter ~= nil and limit > 0 then
		local capacity = 1 + math.max(jitter, 0)
		window.capacity = capacity
		window.tokens = capacity
	end
	return window
end

-- Renvoie true et compte l'appel s'il respecte la limite, false sinon.
function RateLimiter.allow(window: Window, now: number): boolean
	if window.limit <= 0 then
		return false
	end
	local capacity = window.capacity
	if capacity ~= nil then
		-- Débit régulier : seau à jetons (voir l'en-tête).
		local last = window.refilledAt
		local tokens = window.tokens or capacity
		if last ~= nil then
			tokens = math.min(capacity, tokens + math.max(now - last, 0) * window.limit)
		end
		window.refilledAt = now
		if tokens < 1 then
			window.tokens = tokens
			return false
		end
		window.tokens = tokens - 1
		return true
	end
	local cursor = window.cursor
	if now - window.times[cursor] < WINDOW_SECONDS then
		return false
	end
	window.times[cursor] = now
	window.cursor = cursor % window.limit + 1
	return true
end

return RateLimiter
