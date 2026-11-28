--!strict
-- HitVariants (a538, L-505, Clément 27/11) : coups variés, côté client, sur le joueur local.
-- Allumé par Features.HitVariants partout, ou Features.HitVariantsDev dans le jeu DEV (Config/ProductIds.IsDev), lu à
-- chaque appel. Les séries sont dans Config/Tools (HitAnimations de chaque arme), les noms dans Contract/Animations.Player.
--
--   HitVariants.on() -> boolean
--   HitVariants.StopFade : number                      Config/AnimFeel.VariantStopFade
--   HitVariants.pick(series, last, roll?) -> string?   un coup de `series` tiré au hasard, jamais `last` si la série en a
--                                                       plusieurs ; nil si la série est vide. `roll(n)` rend un entier de
--                                                       1 à n (défaut : Random).

local Shared = script.Parent.Parent
local ConfigFolder = Shared:WaitForChild("Config")
local Features = require(ConfigFolder:WaitForChild("Features")) :: any
local AnimFeel = require(ConfigFolder:WaitForChild("AnimFeel"))

local HitVariants = {
	-- Fondu (s) d'arrêt du coup d'avant quand le suivant est un autre (Config/AnimFeel.VariantStopFade).
	StopFade = AnimFeel.VariantStopFade :: number,
}

local isDev = (function(): boolean
	local module = ConfigFolder:FindFirstChild("ProductIds")
	if module == nil or not module:IsA("ModuleScript") then
		return false
	end
	local ok, result = pcall(require, module :: any)
	return ok and type(result) == "table" and (result :: any).IsDev == true
end)()

local rng = Random.new()

local function defaultRoll(n: number): number
	return rng:NextInteger(1, n)
end

function HitVariants.on(): boolean
	return Features.HitVariants == true or (Features.HitVariantsDev == true and isDev)
end

function HitVariants.pick(series: { string }, last: string?, roll: ((number) -> number)?): string?
	local count = #series
	if count == 0 then
		return nil
	end
	local draw = roll or defaultRoll
	if count == 1 then
		return series[1]
	end
	local skip = table.find(series, last :: any)
	if skip == nil then
		return series[draw(count)]
	end
	-- Tirage parmi les autres : un rang de 1 à count - 1, décalé d'un cran à partir du coup d'avant.
	local index = draw(count - 1)
	if index >= skip then
		index += 1
	end
	return series[index]
end

return HitVariants
