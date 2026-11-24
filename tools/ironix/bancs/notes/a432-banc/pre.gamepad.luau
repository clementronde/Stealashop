--!nocheck
---------------------------------------------------------------- banc a432, scénario gamepad (collé après les sources)
-- Le faux Roblox n'a pas d'EnumItem (Enum.X.Y y est un texte) : Shared/Gamepad (a419) est remplacé par une copie qui
-- lit la même Config/Gamepad et Features.Gamepad, mais dit « à la manette » quand A432_PAD est vrai. La fausse caméra
-- reçoit ViewportSize et ViewportPointToRay (visée au centre de l'écran, même rayon que ScreenPointToRay : AIM_RAY).
A432_PAD = false
SOURCES["shared/Gamepad.luau"] = [==[
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Gamepad = {}
function Gamepad.Config()
	local config = ReplicatedStorage:FindFirstChild("Shared"):FindFirstChild("Config")
	local features = require(config:FindFirstChild("Features"))
	local module = config:FindFirstChild("Gamepad")
	if features.Gamepad ~= true or module == nil then
		return nil
	end
	return require(module)
end
function Gamepad.IsActive()
	return A432_PAD == true and Gamepad.Config() ~= nil
end
function Gamepad.OnChanged(_listener)
	return function() end
end
function Gamepad.KeyText(key)
	return (string.gsub(tostring(key), "^Enum%.KeyCode%.Button", ""))
end
return Gamepad
]==]
CAMERA.ViewportSize = Vector2.new(800, 600)
CAMERA.ViewportPointToRay = function(self, x, y)
	A432_VIEWPORT_RAYS = (A432_VIEWPORT_RAYS or 0) + 1
	return CAMERA.ScreenPointToRay(self, x, y)
end
