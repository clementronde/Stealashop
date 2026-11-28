--!strict
-- LuckTiers (a523, liaison L-442 ; Clément 27/11) : texte et palier du compteur « ×N LUCK », communs à
-- BB_ShelfOpen.Row.Luck (ShelfOpenController) et BB_UnboxOdds.Odds (Controllers/Reveal/Unbox), sans Roblox :
--   - format : ×9.99, ×99.9, ×999 sous 1 000, puis K, M, B, T avec une décimale sous 100 (×1.5K, ×250M, ×3.2T) ;
--   - palier : le dernier Tier_n de Clément (Assets/UI/LuckTiers, trié par MinLuck) dont MinLuck ≤ la chance affichée.
-- Interrupteur Features.LuckTiers (partout) ou LuckTiersDev (jeu DEV seulement, Config/ProductIds.IsDev). Coupé : le
-- texte d'avant (« ×%.2f LUCK »), aucun palier. Le style des paliers est posé par Controllers/ShelfOpen/LuckTierStyle.

local LuckTiers = {}

LuckTiers.Suffixes = { "K", "M", "B", "T" }
LuckTiers.Text = "×%s LUCK" -- dossier LuckTiers, attribut NumberFormat (Clément)
local MAX = 1e18 -- au-delà, plafonné (« ×1000000T »), jamais une erreur de format

local function featureOn(name: string): boolean
	local ok, on = pcall(function(): boolean
		local Config = script.Parent:WaitForChild("Config")
		local Features = require(Config:WaitForChild("Features")) :: any
		if Features[name] == true then
			return true
		end
		if Features[name .. "Dev"] ~= true then
			return false
		end
		local ProductIds = require(Config:WaitForChild("ProductIds")) :: any
		return ProductIds.IsDev == true
	end)
	return ok and on == true
end

function LuckTiers.on(): boolean
	return featureOn("LuckTiers")
end

-- Nombre seul : « 1.00 », « 9.99 », « 12.5 », « 999 », « 1.5K », « 250M », « 3.2T ». Arrondi au plus proche, et un
-- arrondi qui déborde passe au cran suivant (999,6 → « 1.0K », jamais « 1000 »).
function LuckTiers.format(value: number): string
	local v = if value == value then math.clamp(value, 0, MAX) else 0
	if v < 9.995 then
		return string.format("%.2f", v)
	elseif v < 99.95 then
		return string.format("%.1f", v)
	elseif v < 999.5 then
		return string.format("%d", math.floor(v + 0.5))
	end
	local scaled, suffix = v, ""
	for index, name in LuckTiers.Suffixes do
		scaled = v / 1000 ^ index
		suffix = name
		if scaled < 999.5 then
			break
		end
	end
	if scaled < 99.95 then
		return string.format("%.1f%s", scaled, suffix)
	end
	return string.format("%d%s", math.floor(scaled + 0.5), suffix)
end

-- « ×1.5K LUCK ».
function LuckTiers.text(value: number): string
	return string.format(LuckTiers.Text, LuckTiers.format(value))
end

-- Rang du palier de `value` dans `mins` (les MinLuck triés du plus petit au plus grand) : le dernier dont MinLuck ≤
-- value ; 0 sous le premier.
function LuckTiers.pick(mins: { number }, value: number): number
	local found = 0
	for index, min in mins do
		if min <= value + 1e-9 then
			found = index
		else
			break
		end
	end
	return found
end

return LuckTiers
