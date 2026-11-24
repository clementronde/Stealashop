--!nocheck
---------------------------------------------------------------- a53 : compléments du faux Roblox d'a51 (DEV-101)
-- Collé après stubs.luau dans le même fichier (il voit ses variables locales SUPER et CLASS_EVENTS) :
--   - ScrollingFrame et UIListLayout, des GuiObject comme les autres (List de UI_Rewards) ;
--   - InputBegan, un signal comme les autres (jamais déclenché : les boutons du banc sont des TextButton).
SUPER.ScrollingFrame = { "GuiObject", "GuiBase2d" }
SUPER.UIListLayout = { "UIGridStyleLayout", "UILayout", "UIComponent" }
CLASS_EVENTS.InputBegan = true
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
