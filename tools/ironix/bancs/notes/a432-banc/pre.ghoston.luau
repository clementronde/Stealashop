--!nocheck
---------------------------------------------------------------- banc a432, scénario ghoston (collé après les sources)
-- Config/Unbox.PlaceGhost remis à true dans le texte de la config (arbre sans l'interrupteur : rien à changer, l'aperçu
-- y est toujours montré).
do
	local key = "shared/Config/Unbox.luau"
	local source = SOURCES[key]
	local first, last = string.find(source, "PlaceGhost = false", 1, true)
	A432_GHOST_SWITCH = first ~= nil
	if first then
		SOURCES[key] = string.sub(source, 1, first - 1) .. "PlaceGhost = true" .. string.sub(source, last + 1)
	end
end
