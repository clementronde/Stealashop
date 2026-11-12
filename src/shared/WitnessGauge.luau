--!strict
-- Jauge d'un témoin (L-111) : ce que le serveur pose sur le modèle du témoin et la façon de le lire,
-- commune à WitnessService (serveur) et WitnessController (client). Aucun remote : le serveur écrit
-- quatre attributs à chaque changement de pente, le client calcule le remplissage entre deux écritures
-- (Workspace:GetServerTimeNow des deux côtés), donc sans flux réseau pendant que le « ? » monte.
--
-- Posé par le code sur chaque témoin en jeu (hors du contrat de la section 2.1, jamais enregistré dans
-- la place) :
--   tag WitnessGauge.Tag            le client retrouve les témoins par ce tag ;
--   WitnessState (texte)            "Stroll" (balade), "Watch" (regarde, le « ? » bouge), "Call" (« ! ») ;
--   WitnessFill (nombre, 0 à 1)     remplissage à l'instant WitnessAt ;
--   WitnessRate (nombre, par s)     pente : > 0 il monte, < 0 il se vide, 0 il est figé ;
--   WitnessAt (nombre)              heure du serveur de cette écriture.

local Witness = require(script.Parent:WaitForChild("Config"):WaitForChild("Witness"))

export type State = "Stroll" | "Watch" | "Call"

local WitnessGauge = {}

WitnessGauge.Tag = "WitnessNpc"
WitnessGauge.StateAttribute = "WitnessState"
WitnessGauge.FillAttribute = "WitnessFill"
WitnessGauge.RateAttribute = "WitnessRate"
WitnessGauge.AtAttribute = "WitnessAt"

local function finite(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

-- Remplissage à l'instant `now`, d'après la dernière écriture (fill à l'instant at, pente rate), de 0 à 1.
function WitnessGauge.valueAt(fill: number, rate: number, at: number, now: number): number
	return math.clamp(fill + rate * math.max(now - at, 0), 0, 1)
end

-- Temps qu'il reste avant que la jauge atteigne 1 (rate > 0) ou 0 (rate < 0) ; math.huge si elle est figée.
function WitnessGauge.timeLeft(fill: number, rate: number): number
	if rate > 0 then
		return math.max(1 - fill, 0) / rate
	elseif rate < 0 then
		return math.max(fill, 0) / -rate
	end
	return math.huge
end

-- Rang de la couleur du « ? » pour ce remplissage (1 = jaune, 2 = orange dès 50 %, 3 = rouge dès 80 %).
function WitnessGauge.stage(value: number): number
	local stage = 1
	for index, entry in Witness.Colors do
		if value >= entry.From then
			stage = index
		end
	end
	return stage
end

function WitnessGauge.color(value: number): Color3
	return Witness.Colors[WitnessGauge.stage(value)].Color
end

-- L'état et le remplissage d'un témoin à l'instant `now`, lus sur ses attributs. Attributs absents ou
-- faux : "Stroll", 0.
function WitnessGauge.read(model: Instance, now: number): (State, number)
	local state = model:GetAttribute(WitnessGauge.StateAttribute)
	local fill = model:GetAttribute(WitnessGauge.FillAttribute)
	local rate = model:GetAttribute(WitnessGauge.RateAttribute)
	local at = model:GetAttribute(WitnessGauge.AtAttribute)
	if (state ~= "Watch" and state ~= "Call") or not finite(fill) or not finite(rate) or not finite(at) then
		return "Stroll", 0
	end
	return state :: State, WitnessGauge.valueAt(fill :: number, rate :: number, at :: number, now)
end

return WitnessGauge
