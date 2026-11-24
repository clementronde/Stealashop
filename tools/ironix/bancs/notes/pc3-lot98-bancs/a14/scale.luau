-- lot98 (petit chef 3) : Model:GetScale et Model:ScaleTo pour a418 (DisplayService met les objets à l'échelle de leur
-- poids ; 10 kg = ×2 depuis a418). Échelle gardée sur l'instance, pièces agrandies autour du pivot.
function Methods.GetScale(self)
	return rawget(self, "_pc3Scale") or 1
end
function Methods.ScaleTo(self, scale)
	local k = scale / Methods.GetScale(self)
	local pivot = Methods.GetPivot(self).Position
	for _, d in Methods.GetDescendants(self) do
		if isA(d, "BasePart") then
			local c = d.CFrame
			d.CFrame = CFrame.new((c.Position - pivot) * (k - 1)) * c
			d.Size = d.Size * k
		end
	end
	rawset(self, "_pc3Scale", scale)
end
