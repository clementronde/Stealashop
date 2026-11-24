--!nocheck
-- Noms fautifs glissés dans la config (les modules sont gelés : on change leur source) : un nom
-- d'événement avec apostrophe, un SKU fixe avec virgule, un type de transaction avec guillemets
-- typographiques, une étape du funnel avec apostrophe (comme « Premier achat d'outil », refusé par
-- Roblox le 2026-11-07).
do
	local function patch(key, from, to)
		local source = SOURCES[key]
		local at = string.find(source, from, 1, true)
		assert(at ~= nil and string.find(source, from, at + 1, true) == nil, `pre.badnames : « {from} » introuvable ou en double dans {key}`)
		SOURCES[key] = string.sub(source, 1, at - 1) .. to .. string.sub(source, at + #from)
	end
	patch("shared/Config/Telemetry.luau", 'GuardCatch = "GuardCatch"', "GuardCatch = \"Guard'Catch\"")
	patch("shared/Config/Telemetry.luau", 'Sku = "Income"', 'Sku = "In,come"')
	patch("shared/Config/Telemetry.luau", 'Transaction = "Code"', 'Transaction = "“Code”"')
	patch("shared/Config/Tutorial.luau", '"Arrivée sur sa parcelle"', "\"Arrivée sur l'aire\"")
end
