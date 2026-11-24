---------------------------------------------------------------- ajouts a401 (vague GC4, 23/11)
-- Collé après ext-motion.luau (et les autres ext) : ajout pur, la courbe Sine (comme ext-a189.luau) ; les autres
-- courbes passent par l'EASE d'avant.
do
	local oldEase = EASE
	function EASE(style, direction, u)
		if style ~= "Enum.EasingStyle.Sine" then
			return oldEase(style, direction, u)
		end
		local function f(x)
			return 1 - math.cos(x * math.pi / 2)
		end
		if direction == "Enum.EasingDirection.In" then
			return f(u)
		elseif direction == "Enum.EasingDirection.Out" then
			return 1 - f(1 - u)
		end
		if u < 0.5 then
			return f(2 * u) / 2
		end
		return 1 - f(2 * (1 - u)) / 2
	end
end
