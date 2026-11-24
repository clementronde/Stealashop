--!nocheck
---------------------------------------------------------------- a74 : compléments du faux Roblox (L-095 point 6)
-- Collé après ext61.luau dans le même fichier (voit les variables locales de stubs.luau) ; ajouts purs :
--   - UDim2 + UDim2 (Roblox l'a ; Motion.HoverCard décale l'Icon d'une case) ;
--   - TWEENS : chaque tween joué est noté ({ inst, parent, props, from }) avant de s'appliquer d'un coup
--     comme avant (les sursauts de Motion.Pop se voient ainsi, leur UIScale étant retiré aussitôt).
if UD2MT.__add == nil then
	UD2MT.__add = function(a, b)
		return UDim2.new(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset)
	end
end
TWEENS = {}
do
	local baseCreate = TweenService.Create
	TweenService.Create = function(self, inst, info, props)
		local tween = baseCreate(self, inst, info, props)
		local basePlay = tween.Play
		function tween.Play(t)
			local ok, from = pcall(function()
				return inst.Scale
			end)
			table.insert(TWEENS, { inst = inst, parent = inst.Parent, props = props, from = if ok then from else nil })
			return basePlay(t)
		end
		return tween
	end
end
-- Sursauts (Motion.Pop, UIScale PopScale) joués sur `object` depuis le rang `since` de TWEENS : leurs
-- échelles de départ.
function popsOn(object, since)
	local out = {}
	for i = (since or 0) + 1, #TWEENS do
		local entry = TWEENS[i]
		if entry.parent == object and entry.inst.Name == "PopScale" and entry.props.Scale == 1 then
			table.insert(out, entry.from)
		end
	end
	return out
end
