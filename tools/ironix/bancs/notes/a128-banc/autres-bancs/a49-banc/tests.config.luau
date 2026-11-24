--!nocheck
-- Scénario « config » (a49, DEV-131, L-084 point 3) : Config/Mutations seul. Valeurs de Clément,
-- tirage (fréquences sur 400 000 tirages, une mutation par famille au plus, familles indépendantes),
-- lecture tolérante (Sanitize, IsValid), multiplicateurs, étiquettes et noms.

advance(1000)
startServer()
local Mutations = sharedModule("Config/Mutations")

section("valeurs de Clément (L-084)")
local wantSizes = { { "Tiny", 0.6, 0.5, 10 }, { "Big", 1.5, 2, 10 }, { "Huge", 2, 5, 4 }, { "Colossal", 3, 10, 1 } }
local wantEffects = {
	{ "Shiny", 1.5, 6 },
	{ "Gold", 2, 3 },
	{ "Neon", 2.5, 2 },
	{ "Diamond", 3, 1.5 },
	{ "Glitch", 4, 1 },
	{ "Hacked", 6, 0.5 },
	{ "Rainbow", 10, 0.2 },
}
check(#Mutations.Sizes == 4 and #Mutations.Effects == 7, "4 tailles, 7 effets")
for i, w in wantSizes do
	local e = Mutations.Sizes[i]
	check(e.Id == w[1] and e.Scale == w[2] and e.IncomeMultiplier == w[3] and e.Chance == w[4] and Mutations.SizeById[w[1]] == e, `taille {w[1]} : ×{w[2]} en taille, ×{w[3]} en revenu, {w[4]} %`)
	check(e.DisplayName == w[1] and e.DisplayNameUpper == string.upper(w[1]), `taille {w[1]} : texte anglais`)
end
for i, w in wantEffects do
	local e = Mutations.Effects[i]
	check(e.Id == w[1] and e.IncomeMultiplier == w[2] and e.Chance == w[3] and e.Scale == 1 and Mutations.EffectById[w[1]] == e, `effet {w[1]} : ×{w[2]} en revenu, {w[3]} %, aucune échelle`)
end
check(table.isfrozen(Mutations) and table.isfrozen(Mutations.Sizes) and table.isfrozen(Mutations.Sizes[1]), "Config/Mutations gelé")
check(not pcall(function()
	Mutations.Sizes[1].Chance = 50
end), "écriture refusée")

section("tirage : fréquences, une par famille, indépendance")
local rng = Random.new(4949)
local N = 400000
local sizeCount, effectCount, both, none = {}, {}, 0, 0
local bigGold = 0
local badShape = 0
for _ = 1, N do
	local m = Mutations.Roll(rng)
	if m == nil then
		none += 1
	else
		local keys = 0
		for k in m do
			keys += 1
			if k ~= "Size" and k ~= "Effect" then
				badShape += 1
			end
		end
		if keys == 0 or not Mutations.IsValid(m) then
			badShape += 1
		end
		if m.Size then
			sizeCount[m.Size] = (sizeCount[m.Size] or 0) + 1
		end
		if m.Effect then
			effectCount[m.Effect] = (effectCount[m.Effect] or 0) + 1
		end
		if m.Size and m.Effect then
			both += 1
		end
		if m.Size == "Big" and m.Effect == "Gold" then
			bigGold += 1
		end
	end
end
check(badShape == 0, "chaque tirage : nil ou une table { Size?, Effect? } valide, jamais vide (une mutation par famille au plus)")
-- Écart toléré : 4,5 écarts-types (binomiale).
local function within(count, p, label)
	local mean = N * p
	local sd = math.sqrt(N * p * (1 - p))
	local ok = math.abs(count - mean) <= 4.5 * sd
	check(ok, `{label} : {count} sur {N} (attendu {math.round(mean)} ± {math.round(4.5 * sd)})`)
end
for _, w in wantSizes do
	within(sizeCount[w[1]] or 0, w[4] / 100, `taille {w[1]}`)
end
for _, w in wantEffects do
	within(effectCount[w[1]] or 0, w[3] / 100, `effet {w[1]}`)
end
local pSize, pEffect = 0.25, 0.142
within(none, (1 - pSize) * (1 - pEffect), "aucune mutation")
within(both, pSize * pEffect, "taille et effet ensemble (familles indépendantes)")
within(bigGold, 0.10 * 0.03, "Big et Gold ensemble")

section("lecture tolérante")
check(Mutations.Sanitize(nil) == nil and Mutations.Sanitize({}) == nil and Mutations.Sanitize("Big") == nil, "Sanitize : nil, {} et texte → nil")
local s = Mutations.Sanitize({ Size = "Big", Effect = "Gold", Extra = 1 })
check(s ~= nil and s.Size == "Big" and s.Effect == "Gold" and s.Extra == nil, "Sanitize : champs inconnus retirés")
local s2 = Mutations.Sanitize({ Size = "Mega", Effect = "Neon" })
check(s2 ~= nil and s2.Size == nil and s2.Effect == "Neon", "Sanitize : Id inconnu retiré, l'autre famille gardée")
check(Mutations.Sanitize({ Size = "Mega" }) == nil, "Sanitize : rien de connu → nil")
check(Mutations.IsValid(nil) and Mutations.IsValid({}) and Mutations.IsValid({ Size = "Tiny" }) and Mutations.IsValid({ Effect = "Rainbow" }), "IsValid : nil, {}, une famille")
check(not Mutations.IsValid({ Size = "Mega" }) and not Mutations.IsValid({ Effect = 3 }) and not Mutations.IsValid({ Size = "Big", Other = true }) and not Mutations.IsValid(5), "IsValid : refuse Id inconnu, mauvais type, champ en trop")

section("multiplicateurs, échelle, textes")
check(Mutations.IncomeMultiplier(nil) == 1 and Mutations.IncomeMultiplier({}) == 1 and Mutations.IncomeMultiplier({ Size = "Mega" }) == 1, "sans mutation (ou inconnue) : ×1")
check(Mutations.IncomeMultiplier({ Size = "Tiny" }) == 0.5 and Mutations.IncomeMultiplier({ Effect = "Hacked" }) == 6, "une famille : Tiny ×0,5, Hacked ×6")
check(near(Mutations.IncomeMultiplier({ Size = "Colossal", Effect = "Rainbow" }), 100) and near(Mutations.IncomeMultiplier({ Size = "Big", Effect = "Gold" }), 4) and near(Mutations.IncomeMultiplier({ Size = "Tiny", Effect = "Shiny" }), 0.75), "cumul : Colossal Rainbow ×100, Big Gold ×4, Tiny Shiny ×0,75")
check(Mutations.Scale(nil) == 1 and Mutations.Scale({ Effect = "Gold" }) == 1 and Mutations.Scale({ Size = "Huge" }) == 2 and Mutations.Scale({ Size = "Tiny", Effect = "Neon" }) == 0.6, "échelle : 1 sans taille, Huge 2, Tiny 0,6")
check(Mutations.Label(nil) == nil and Mutations.Label({ Size = "Mega" }) == nil, "étiquette : nil sans mutation")
check(Mutations.Label({ Size = "Big", Effect = "Gold" }) == "BIG · GOLD" and Mutations.Label({ Effect = "Rainbow" }) == "RAINBOW" and Mutations.Label({ Size = "Huge" }) == "HUGE", `étiquette : « BIG · GOLD », « RAINBOW », « HUGE » ({tostring(Mutations.Label({ Size = "Big", Effect = "Gold" }))})`)
check(Mutations.ItemName("Soda Can", nil) == "Soda Can" and Mutations.ItemName("Soda Can", { Size = "Big", Effect = "Gold" }) == "Big Gold Soda Can" and Mutations.ItemName("Soda Can", { Effect = "Neon" }) == "Neon Soda Can", "nom : « Big Gold Soda Can », « Neon Soda Can », nom seul sans mutation")
local Formulas = sharedModule("Config/Formulas")
check(near(Formulas.ItemIncome(2, "Rare") * Mutations.IncomeMultiplier({ Size = "Huge", Effect = "Diamond" }), Formulas.ItemIncome(2, "Rare") * 15), "revenu d'un objet × taille × effet (Huge Diamond ×15)")

summary("scénario config")
