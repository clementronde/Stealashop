--!nocheck
---------------------------------------------------------------- a61 : compléments du faux Roblox d'a53 (L-079)
-- Collé après stubs.luau dans le même fichier (il voit ses variables locales SUPER et CLASS_EVENTS) :
--   - MouseEnter et MouseLeave, des signaux comme les autres (survol des cartes, Motion.Hover) ;
--   - UIGridLayout (cadre Cards des sections de UI_Inventory) ;
--   - StarterGui:SetCoreGuiEnabled, UserInputService.TouchTap, worldClick et pressKey : déjà dans l'ext51
--     de la copie d'a61 d'a51 (autres-bancs/a51-banc/ext51.luau), collé avant ce fichier.
CLASS_EVENTS.MouseEnter = true
CLASS_EVENTS.MouseLeave = true
CLASS_EVENTS.MouseButton1Down = true -- vague 21 : Motion.Button (a60) branche aussi l'appui
CLASS_EVENTS.MouseButton1Up = true
CLASS_EVENTS.InputBegan = true -- copie d'a62 (2026-11-11, L-092 3g) : Motion.Button suit la fin du toucher
CLASS_EVENTS.InputEnded = true
SUPER.UIGridLayout = { "UIGridStyleLayout", "UILayout", "UIComponent" }
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
