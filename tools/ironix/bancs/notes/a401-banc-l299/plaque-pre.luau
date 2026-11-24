---------------------------------------------------------------- a401 (vague GC4, 23/11) : 2e partie du banc, la plaque
-- Collé avant stubs.luau du banc a14 (copie a141) : son faux game:GetService n'a pas TweenService ; run.sh l'ajoute à la
-- liste des services (TweenService = A401_TWEEN_PROXY) et ext-plaque.luau le remplit (appelé après le chargement).
A401_TWEEN_SERVICE = {}
A401_TWEEN_PROXY = setmetatable({}, {
	__index = function(_, key)
		return A401_TWEEN_SERVICE[key]
	end,
})
