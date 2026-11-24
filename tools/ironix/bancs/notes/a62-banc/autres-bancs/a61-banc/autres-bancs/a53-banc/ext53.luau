--!nocheck
---------------------------------------------------------------- a53 : compléments du faux Roblox d'a51 (DEV-101)
-- Collé après stubs.luau dans le même fichier (il voit ses variables locales SUPER et CLASS_EVENTS) :
--   - ScrollingFrame et UIListLayout, des GuiObject comme les autres (List de UI_Rewards) ;
--   - InputBegan, un signal comme les autres (jamais déclenché : les boutons du banc sont des TextButton).
SUPER.ScrollingFrame = { "GuiObject", "GuiBase2d" }
SUPER.UIListLayout = { "UIGridStyleLayout", "UILayout", "UIComponent" }
CLASS_EVENTS.InputBegan = true
