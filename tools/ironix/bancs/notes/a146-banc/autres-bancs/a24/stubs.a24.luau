---------------------------------------------------------------- ajouts a24
-- Collé après stubs.luau (copie de celui de a21-banc/night), dans le même bloc : ses locales
-- (Methods, ISA, PROPS, NONE, cf, isA, PathfindingService…) sont visibles ici.
-- Pour les vigiles de Clément (vague 7) :
--   - classes Accessory et Hat (Accoutrement) ;
--   - Model:GetScale(), échelle posée par Model:ScaleTo, gardée par Clone (propriété cachée _Scale) ;
--   - Model:GetBoundingBox() orientée comme la PrimaryPart (comme Roblox), et non plus alignée
--     sur le monde ;
--   - pistes d'animation : Speed suivie (Play(fondu, poids, vitesse) et AdjustSpeed), toutes
--     gardées dans ALL_TRACKS, changements dans SPEED_LOG ;
--   - PathfindingService:CreatePath : paramètres de chaque chemin créé dans PATH_PARAMS.

ISA.Accessory = { "Accoutrement" }
ISA.Hat = { "Accoutrement" }

PROPS.Model._Scale = 1
function Methods.GetScale(self)
	return rawget(self, "_props")._Scale or 1
end
function setScale(model, scale)
	rawget(model, "_props")._Scale = scale
end

function Methods.GetBoundingBox(self)
	local primary = self.PrimaryPart
	local frame = if primary then primary.CFrame else self.WorldPivot
	local rot = frame.Rotation
	local lo, hi
	for _, d in Methods.GetDescendants(self) do
		if isA(d, "BasePart") then
			local h = d.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local p = rot:PointToObjectSpace(d.CFrame * Vector3.new(sx * h.X, sy * h.Y, sz * h.Z))
						lo = if lo then Vector3.new(math.min(lo.X, p.X), math.min(lo.Y, p.Y), math.min(lo.Z, p.Z)) else p
						hi = if hi then Vector3.new(math.max(hi.X, p.X), math.max(hi.Y, p.Y), math.max(hi.Z, p.Z)) else p
					end
				end
			end
		end
	end
	if lo == nil then
		return frame, Vector3.zero
	end
	return cf(rot * ((lo + hi) / 2), frame.r), hi - lo
end

ALL_TRACKS = {}
SPEED_LOG = {} -- { t, track, speed, via = "Play" | "AdjustSpeed" }
local baseLoadAnimation = Methods.LoadAnimation
function Methods.LoadAnimation(self, animation)
	local track = baseLoadAnimation(self, animation)
	track.Speed = 1
	local basePlay = track.Play
	function track.Play(t, _fadeTime, _weight, speed)
		t.Speed = speed or 1
		table.insert(SPEED_LOG, { t = now(), track = t, speed = t.Speed, via = "Play" })
		basePlay(t)
	end
	function track.AdjustSpeed(t, speed)
		t.Speed = speed or 1
		table.insert(SPEED_LOG, { t = now(), track = t, speed = t.Speed, via = "AdjustSpeed" })
	end
	table.insert(ALL_TRACKS, track)
	return track
end

PATH_PARAMS = {}
local baseCreatePath = PathfindingService.CreatePath
PathfindingService.CreatePath = function(service, params)
	table.insert(PATH_PARAMS, params)
	return baseCreatePath(service, params)
end
