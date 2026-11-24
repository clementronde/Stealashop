--!nocheck
-- Interrupteurs de Config/Features posés en texte avant le chargement (comme pre.on d'a38). Tolérant :
-- l'agent a39 passe Features.Index à true dans main (vague 14) ; une valeur déjà bonne est laissée.
function setFeature(name, value)
	local key = "shared/Config/Features.luau"
	local source = SOURCES[key]
	assert(source, "Config/Features absent des sources")
	local wanted = `{name} = {tostring(value)}`
	if string.find(source, wanted, 1, true) then
		return
	end
	local from = `{name} = {tostring(not value)}`
	local first, last = string.find(source, from, 1, true)
	assert(first, `interrupteur introuvable dans Config/Features : {from}`)
	SOURCES[key] = string.sub(source, 1, first - 1) .. wanted .. string.sub(source, last + 1)
end
