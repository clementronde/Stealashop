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
SUPER.UIGridLayout = { "UIGridStyleLayout", "UILayout", "UIComponent" }

-- Fusion des vagues 22-23 (2026-11-11) : Motion.Button (a62) suit la fin d'un toucher.
CLASS_EVENTS.InputBegan = true
CLASS_EVENTS.InputEnded = true
