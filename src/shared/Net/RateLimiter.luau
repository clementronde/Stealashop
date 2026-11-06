--!strict
-- Limite de débit d'un remote pour un joueur (ReplicatedStorage/Shared/Net/RateLimiter).
--
-- Fenêtre glissante : au plus `limit` appels acceptés sur toute période d'une
-- seconde, ce qui colle au texte du doc (« ≤ 10 coups/s »). On garde l'heure
-- des `limit` derniers appels acceptés dans un anneau : un appel passe si le
-- plus ancien date d'au moins une seconde. Coût constant par appel.
-- Une limite de 0 refuse tout (sert aux remotes serveur → client appelés par un client).

export type Window = {
	limit: number,
	times: { number }, -- heures (os.clock) des derniers appels acceptés
	cursor: number, -- case du plus ancien
	dropped: number, -- appels refusés pas encore signalés (utilisé par Net)
	lastReport: number, -- heure du dernier signalement (utilisé par Net)
}

local WINDOW_SECONDS = 1

local RateLimiter = {}

function RateLimiter.new(limit: number): Window
	return {
		limit = limit,
		times = table.create(limit, -math.huge),
		cursor = 1,
		dropped = 0,
		lastReport = -math.huge,
	}
end

-- Renvoie true et compte l'appel s'il respecte la limite, false sinon.
function RateLimiter.allow(window: Window, now: number): boolean
	if window.limit <= 0 then
		return false
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
