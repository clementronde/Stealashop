--!nocheck
---------------------------------------------------------------- a118 : compléments du faux Roblox (vague 34, L-127)
-- Collé après ext74.luau dans le même fichier (voit les variables locales de stubs.luau) ; ajouts purs :
--   - CFrame.fromMatrix(pos, x, y, z) (colonnes : droite, haut, arrière, comme Roblox) ;
--   - Model:ScaleTo(k) : tailles et positions des pièces × k autour du pivot (cadenas du kit).
if CFrame.fromMatrix == nil then
	function CFrame.fromMatrix(pos, x, y, z)
		z = z or x:Cross(y).Unit
		return setmetatable({ p = pos, r = { x.X, y.X, z.X, x.Y, y.Y, z.Y, x.Z, y.Z, z.Z } }, getmetatable(CFrame.identity))
	end
end
if Methods.ScaleTo == nil then
	function Methods.ScaleTo(self, k)
		local pivot = Methods.GetPivot(self)
		for _, d in Methods.GetDescendants(self) do
			if isA(d, "BasePart") then
				local rel = pivot:ToObjectSpace(d.CFrame)
				d.Size = d.Size * k
				d.CFrame = pivot * (CFrame.new(rel.Position * k) * rel.Rotation)
			end
		end
	end
end
