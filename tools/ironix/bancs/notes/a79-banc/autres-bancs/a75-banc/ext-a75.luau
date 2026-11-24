---------------------------------------------------------------- extensions a75 (vague 24)
-- Collé après stubs.luau, ext-motion.luau et ext-a60.luau (voit leurs variables locales) : la classe
-- Decal (icônes ICON_BOX_<Tier> de ReplicatedStorage/Assets/Icons, Contract/Icons).
ISA.Decal = ISA.Decal or { "FaceInstance" }
PROPS.Decal = PROPS.Decal or { Texture = "" }
-- LayoutOrder des objets d'UI (NotifyController range les messages par ordre d'arrivée).
for _, class in { "Frame", "TextLabel", "TextButton", "ImageLabel", "ImageButton" } do
	if PROPS[class] and PROPS[class].LayoutOrder == nil then
		PROPS[class].LayoutOrder = 0
	end
end
