--!strict
-- Format court des nombres du HUD (DEV-021) : 1.4K, 5.2M, 11.1B.
-- ReplicatedStorage/Shared/Format, commun au serveur et au client.
--
--   Format.short(1450)     -> "1.4K"
--   Format.money(11.1e9)   -> "$11.1B"
--   Format.income(1200)    -> "+$1.2K/s"
--
-- Règles :
--   - sous 1 000 : le nombre entier, avec une décimale sous 100 s'il n'est pas rond (dégâts 1.3) ;
--   - au-delà : une lettre par palier de 1 000 (K, M, B, T, Qa, Qi, Sx, Sp, Oc, No, Dc) et une
--     décimale tant que le nombre fait moins de 100 de son palier (12.4K, puis 124K) ;
--   - toujours arrondi vers le bas : on n'affiche jamais plus que ce qu'on a ; « .0 » est retiré.
-- C'est l'écriture des maquettes du HUD de Clément (point décimal, lettres anglaises). Les
-- billboards gardent la leur (« 12,4 K$/s », DisplayService et CarryService).

local Format = {}

-- Paliers, du plus grand au plus petit (valeurs écrites en littéraux : exactes à l'arrondi près).
local UNITS: { { Value: number, Suffix: string } } = {
	{ Value = 1e33, Suffix = "Dc" },
	{ Value = 1e30, Suffix = "No" },
	{ Value = 1e27, Suffix = "Oc" },
	{ Value = 1e24, Suffix = "Sp" },
	{ Value = 1e21, Suffix = "Sx" },
	{ Value = 1e18, Suffix = "Qi" },
	{ Value = 1e15, Suffix = "Qa" },
	{ Value = 1e12, Suffix = "T" },
	{ Value = 1e9, Suffix = "B" },
	{ Value = 1e6, Suffix = "M" },
	{ Value = 1e3, Suffix = "K" },
}

-- Au-delà, écriture scientifique (« 1.50e+36 ») : jamais atteint en jeu, mais le HUD reste lisible.
local SCIENTIFIC_FROM = 1e36

-- Marge contre les erreurs d'arrondi des nombres à virgule (1.4 × 10 = 13,999…).
local EPSILON = 1e-9

-- 124 dixièmes → « 12.4 », 120 → « 12 ».
local function fromTenths(tenths: number): string
	local whole, decimal = tenths // 10, tenths % 10
	if decimal == 0 then
		return string.format("%.0f", whole)
	end
	return string.format("%.0f.%d", whole, decimal)
end

function Format.short(value: number): string
	if value ~= value then
		value = 0 -- NaN
	end
	if value < 0 then
		return "-" .. Format.short(-value)
	end
	if value == math.huge then
		return "∞"
	end
	if value >= SCIENTIFIC_FROM then
		return string.format("%.2e", value)
	end
	for _, unit in UNITS do
		if value >= unit.Value then
			local tenths = math.floor(value * 10 / unit.Value + EPSILON)
			local text = if tenths < 1000 then fromTenths(tenths) else string.format("%.0f", tenths // 10)
			return text .. unit.Suffix
		end
	end
	if value < 100 then
		return fromTenths(math.floor(value * 10 + EPSILON))
	end
	return string.format("%.0f", math.floor(value + EPSILON))
end

-- Argent : « $11.1B ».
function Format.money(value: number): string
	if value < 0 then
		return "-$" .. Format.short(-value)
	end
	return "$" .. Format.short(value)
end

-- Revenu par seconde : « +$1.2K/s ».
function Format.income(value: number): string
	if value < 0 then
		return "-$" .. Format.short(-value) .. "/s"
	end
	return "+$" .. Format.short(value) .. "/s"
end

return Format
