--!nocheck
-- a158 : ajouts au faux Roblox du banc a17-carry (ici seulement) : rayon vers le sol de CarryService.groundBelow (sol à Y = 0).
RaycastParams = { new = function() return {} end }
rawset(Workspace, "Raycast", function(_, origin) return { Position = Vector3.new(origin.X, 0, origin.Z) } end)
