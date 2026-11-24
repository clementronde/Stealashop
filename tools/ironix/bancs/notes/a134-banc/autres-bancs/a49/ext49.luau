--!nocheck
-- Ajout d'a49 (DEV-131, mutations) au faux Roblox d'a46 : Model:ScaleTo et GetScale, comme Roblox : les
-- pièces grandissent autour du pivot du modèle (tailles, positions et PivotOffset multipliés, rotations
-- gardées), le pivot ne bouge pas. SCALE_CALLS note chaque appel (modèle, échelle).
SCALE_CALLS = {}
function Methods.ScaleTo(self, scale)
	assert(type(scale) == "number" and scale > 0, "ScaleTo : échelle invalide")
	local old = rawget(self, "_scale") or 1
	local factor = scale / old
	local pivot = Methods.GetPivot(self).Position
	for _, d in Methods.GetDescendants(self) do
		if isA(d, "BasePart") then
			local cf = d.CFrame
			d.Size = d.Size * factor
			d.CFrame = cf.Rotation + (pivot + (cf.Position - pivot) * factor)
			local offset = d.PivotOffset
			d.PivotOffset = offset.Rotation + offset.Position * factor
		end
	end
	rawset(self, "_scale", scale)
	table.insert(SCALE_CALLS, { model = self, scale = scale })
end
function Methods.GetScale(self)
	return rawget(self, "_scale") or 1
end
