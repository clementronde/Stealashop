--!nocheck
---------------------------------------------------------------- a67 : compléments du faux Roblox (L-095 points 1 et 2)
-- Pour IndexController sur UI_Index_v3 et pour SettingsController / SettingsService :
--   - signaux InputBegan, InputChanged, InputEnded (curseurs) et Ended (sons de MarkerSounds) ;
--   - UserInputService (faux) côté client et serveur : InputBegan, InputChanged, InputEnded ;
--     inputObject(kind, x) fabrique un InputObject (UserInputType « Enum.UserInputType.<kind> »,
--     Position.X = x) ;
--   - Sound:Play() note le son dans PLAYED ({ t, name, group = nom de son SoundGroup }) ;
--   - Methods.Stop, sans effet ; ScrollingFrame:IsA("GuiObject") vrai.

CLASS_EVENTS.InputBegan = true
CLASS_EVENTS.InputChanged = true
CLASS_EVENTS.InputEnded = true
CLASS_EVENTS.Ended = true

PLAYED = {}
function Methods.Play(self)
	local group = self.SoundGroup
	table.insert(PLAYED, { t = now(), name = self.Name, group = if group then group.Name else nil, volume = self.Volume })
end
function Methods.Stop(_self) end

USER_INPUT = {
	InputBegan = newSignal(),
	InputChanged = newSignal(),
	InputEnded = newSignal(),
	TouchEnabled = false,
	KeyboardEnabled = true,
}

function inputObject(kind, x)
	return { UserInputType = `Enum.UserInputType.{kind}`, Position = Vector3.new(x or 0, 0, 0) }
end

-- Derniers sons joués dont le nom commence par `prefix`.
function playedNames(prefix)
	local out = {}
	for _, entry in PLAYED do
		if prefix == nil or string.sub(entry.name, 1, #prefix) == prefix then
			table.insert(out, entry.name)
		end
	end
	return out
end

do
	local function wrap(base)
		return {
			GetService = function(_self, name)
				if name == "UserInputService" then
					return USER_INPUT
				end
				return base:GetService(name)
			end,
			IsLoaded = function()
				return true
			end,
			Loaded = base.Loaded,
		}
	end
	games.server = wrap(games.server)
	games.client = wrap(games.client)
	games.prod = wrap(games.prod)
end

-- ScrollingFrame est un GuiObject (comme dans Roblox) ; SoundGroup, Sound : classes simples.
SUPER.ScrollingFrame = { "GuiObject", "GuiBase2d" }
-- Ajout d'a75 (2026-11-11, vague 24, L-094) : AbsolutePosition des objets d'UI (Motion.Open range les
-- cartes dans l'ordre de lecture avant de les faire entrer une à une). Ajout pur : (0, 0) si jamais posée.
do
	local indexBeforeA75 = InstanceMT.__index
	InstanceMT.__index = function(self, key)
		if key == "AbsolutePosition" and isA(self, "GuiObject") then
			local stored = rawget(self, "_props").AbsolutePosition
			return stored or Vector2.new(0, 0)
		end
		return indexBeforeA75(self, key)
	end
end
