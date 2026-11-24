# a262 (vague 76, 2026-11-19) : banc a109 (rareté de la caisse, contenu à la sortie). Vague 76 : la rareté du colis du rayon
# est tirée par zone (Rarities.ZoneOdds) et le contenu dans ShelfOpen.BoxRarityOdds limité aux raretés de la zone
# (ShelfBoxes.ContentWeights). Le magasin de zone 2 du banc n'a plus que des Communs et des Peu communs : les scénarios
# draw et lowest passent sur un magasin de zone 6 (Rare à Secret) ; en zone 1, tout objet est Commun (Divine, Mythique et
# Secret écartés par la zone, la chance n'y change rien) ; outil bands(…, zone) limité à la zone comme le serveur.
# Formulas.ItemIncome prend l'objet (outil checkItem).
lit(q{		local income = Formulas.ItemIncome(def.Zone or zone, def.Rarity)}, q{		local income = Formulas.ItemIncome(def.Id)}, 'checkItem') if has(q{		local income = Formulas.ItemIncome(def.Zone or zone, def.Rarity)});
if (has(q{function bands(boxRarity, luck, mode)
	local odds = SO.BoxRarityOdds[boxRarity]})) {
	lit(q{function bands(boxRarity, luck, mode)
	local odds = SO.BoxRarityOdds[boxRarity]}, q{function bands(boxRarity, luck, mode, zone)
	local odds = SO.BoxRarityOdds[boxRarity]
	if zone ~= nil then
		local kept = {}
		for id, w in odds do
			if Rarities.Allows(zone, id) then
				kept[id] = w
			end
		end
		odds = kept
	end}, 'bands');
}
# Scénario divine (caisses Communes de zone 1 { Common = 1, Divine = 1 }) : la Divine est écartée par la zone 1.
if (has(q{checkItem("V1 tirage Divine : un Secret à la place", item, STORE_A, "Secret")})) {
	lit(q{checkItem("V1 tirage Divine : un Secret à la place", item, STORE_A, "Secret")}, q{checkItem("V1 tirage Divine : un Commun (a262 : Divine écartée par la zone 1)", item, STORE_A, "Common")}, 'V1');
	lit(q{check(logHas("aucun objet Divine tirable dans aucune zone", nil, "server"), "V2 avertissement du garde-fou")}, q{check(not logHas("aucun objet Divine tirable dans aucune zone", nil, "server"), "V2 (a262) Divine écartée par la zone : pas d'avertissement du garde-fou")}, 'V2');
	rep(q{check\(logHas\("caisse Common → objet Secret \(", nil, "server"\)[^\n]*\n}, qq{check(logHas("caisse Common → objet Common (", nil, "server"), "V3 (a262) log : caisse Commune, objet Commun")\n}, 'V3');
}
# Scénario tuto : une Rarity imposée seule doit exister dans la zone (Peu commun en zone 2).
if (has(q{checkItem("T3a Rare imposé en zone 2", item3, STORE_C, "Rare")})) {
	lit(q{	if p == B and drawn.Zone == 2 then
		return { Rarity = "Rare" }}, q{	if p == B and drawn.Zone == 2 then
		return { Rarity = "Uncommon" }}, 'T3 override');
	lit(q{check(left3 == 1, "T3b aucun tirage de rareté ni de mutation")}, q{check(left3 == 0, "T3b aucun tirage de rareté ni de mutation (a262 : le tirage forcé choisit l'objet, pondéré par DrawWeight)")}, 'T3b');
	lit(q{checkItem("T3a Rare imposé en zone 2", item3, STORE_C, "Rare")}, q{checkItem("T3a Peu commun imposé en zone 2 (a262)", item3, STORE_C, "Uncommon")}, 'T3a');
}
# Scénario draw : magasin de zone 6.
if (has(q{section("D1 mise en rayon : rareté de la caisse seulement")})) {
	lit(q{STORE_C = buildStore("STORE_Z2_Bazar", 2, 140, 1)}, q{STORE_C = buildStore("STORE_Z2_Bazar", 6, 140, 1) -- a262 : magasin de zone 6}, 'store draw');
	lit(q{local wantCount = { Secret = 1, Mythic = 1, Legendary = 1, Epic = 2, Rare = 1, Uncommon = 1, Common = 3 }}, q{-- a262 : Rarities.ZoneOdds[6] (Rare 55, Épique 30, Légendaire 14,47, Mythique 0,5, Secret 0,03)
local wantCount = { Mythic = 3, Legendary = 3, Rare = 3, Epic = 1 }}, 'D1e');
	lit(q{"D1e (banc) tirage forcé de la mise en rayon : caisses Secret à Commun en zone 2"}, q{"D1e (banc) tirage forcé de la mise en rayon : 3 Mythiques, 3 Légendaires, 3 Rares, 1 Épique en zone 6 (a262)"}, 'D1e msg');
	rep(q{section\("D2 rareté de l'objet tirée.*?(?=section\("D5 )}, q{section("D2 rareté de l'objet tirée dans la table de la caisse (×1), limitée à la zone 6 (a262)")
for _, rid in { "Rare", "Legendary", "Mythic" } do
	local n = slotOfRarity(STORE_C, rid)
	if n then
		local list = bands(rid, 1, MODE, 6)
		local item, boxRarity = openSlot(B, STORE_C, n, 1, { midOf(list, rid) })
		check(boxRarity == rid, `D2 (banc) caisse {rid}`)
		checkItem(`D2 caisse {rid}, ×1, milieu de sa bande`, item, STORE_C, rid)
	else
		check(false, `D2 (banc) pas de caisse {rid} en zone 6`)
	end
end
check(logHas("caisse Rare → objet Rare (", nil, "server"), "D2 log « caisse <rareté> → objet <rareté> (<ItemId>) »")
check(logHas("chance ×1, caisse Mythic → objet Mythic (", nil, "server"), "D2 log avec la chance")

section("D3 rien n'est garanti : une caisse Mythique peut donner la plus basse de la zone (Rare en zone 6, a262)")
local nM = slotOfRarity(STORE_C, "Mythic")
local itemM = openSlot(B, STORE_C, nM, 2, { 0 })
checkItem("D3a caisse Mythique, ×2, tirage tout en bas", itemM, STORE_C, "Rare")

section("D4 la chance (AboveBox) et la normalisation (caisses Légendaires, a262)")
local nE1 = slotOfRarity(STORE_C, "Legendary")
local nE2 = slotOfRarity(STORE_C, "Legendary", { [nE1] = true })
local b1, b3 = bands("Legendary", 1, MODE, 6), bands("Legendary", 3, MODE, 6)
local epic1, epic3 = bandOf(b1, "Legendary"), bandOf(b3, "Legendary")
local v = (epic3.To + epic1.To) / 2
check(expectedAt(b1, v) == "Legendary" and expectedAt(b3, v) ~= "Legendary", "D4 (banc) un tirage Légendaire à ×1 qui ne l'est plus à ×3")
local itemE = openSlot(B, STORE_C, nE1, 3, { v })
checkItem(`D4a caisse Légendaire, ×3, tirage {v}`, itemE, STORE_C, expectedAt(b3, v))
local itemE2 = openSlot(B, STORE_C, nE2, 3, { epic3.To - 1e-6 })
checkItem("D4b juste sous la fin de la bande Légendaire normalisée (×3)", itemE2, STORE_C, "Legendary")
check(bandOf(b3, "Rare").To < bandOf(b1, "Rare").To, "D4c (banc) à ×3, la part du Rare (plus basse de la zone) baisse (normalisation)")

}, 'D2-D4');
	lit(q{local c1 = bands("Common", 1, MODE)
local c10 = bands("Common", LMAX, MODE)}, q{local c1 = bands("Common", 1, MODE, 1)
local c10 = bands("Common", LMAX, MODE, 1)}, 'c1');
	lit(q{local itemU = openSlot(A, STORE_A, nA, 1, { midOf(c1, "Uncommon"), 0, 1 })
checkItem("D5a caisse Commune de zone 1, tirage Peu commun", itemU, STORE_A, "Uncommon")}, q{local itemU = openSlot(A, STORE_A, nA, 1, { 0.95, 0.5, 0, 1 })
checkItem("D5a caisse Commune de zone 1, tirage 0,95 : Commun (a262 : seule rareté de la zone 1 ; 2e tirage : l'objet, pondéré par DrawWeight)", itemU, STORE_A, "Common")}, 'D5a');
	lit(q{local itemMy = openSlot(A, STORE_A, nA, 1, { midOf(c1, "Mythic"), 1, 0 })
checkItem("D5c caisse Commune de zone 1, tirage Mythique", itemMy, STORE_A, "Mythic")}, q{local itemMy = openSlot(A, STORE_A, nA, 1, { 0.9999, 0.5, 1, 0 })
checkItem("D5c caisse Commune de zone 1, tirage 0,9999 : Commun (a262)", itemMy, STORE_A, "Common")}, 'D5c');
	lit(q{checkItem("D5e tirage tout en haut : Secret, toutes zones", itemS, STORE_A, "Secret")}, q{checkItem("D5e tirage tout en haut : Commun (a262 : Secret en zone 6 seulement)", itemS, STORE_A, "Common")}, 'D5e');
	lit(q{check(expectedAt(c1, vC) == "Common" and expectedAt(c10, vC) ~= "Common", `D5 (banc) tirage {vC} : Commun à ×1, pas à ×{LMAX}`)}, q{check(expectedAt(c1, vC) == "Common" and expectedAt(c10, vC) == "Common", `D5 (banc) tirage {vC} : Commun à ×1 et à ×{LMAX} (a262 : la chance ne change rien en zone 1)`)}, 'D5 chance');
}
# Scénario lowest (LuckBoost = AboveLowest) : magasin de zone 6, la plus basse de la zone est le Rare.
if (has(q{section("L1 caisse Mythique, ×3 : le Commun (plus basse) perd sa part, toutes les autres ×3")})) {
	lit(q{STORE_C = buildStore("STORE_Z2_Bazar", 2, 140, 1)}, q{STORE_C = buildStore("STORE_Z2_Bazar", 6, 140, 1) -- a262 : magasin de zone 6}, 'store lowest');
	lit(q{	local low, box = bands(rid, luck, "AboveLowest"), bands(rid, luck, "AboveBox")}, q{	local low, box = bands(rid, luck, "AboveLowest", 6), bands(rid, luck, "AboveBox", 6)}, 'differing');
	lit(q{section("L1 caisse Mythique, ×3 : le Commun (plus basse) perd sa part, toutes les autres ×3")}, q{section("L1 caisse Mythique, ×3 : le Rare (plus basse de la zone 6, a262) perd sa part, toutes les autres ×3")}, 'L1');
	lit(q{local low3 = bands("Mythic", 3, "AboveLowest")
local low1 = bands("Mythic", 1, "AboveLowest")
check(bandOf(low3, "Common").To < bandOf(low1, "Common").To, "L1b (banc) la plus basse perd sa part")}, q{local low3 = bands("Mythic", 3, "AboveLowest", 6)
local low1 = bands("Mythic", 1, "AboveLowest", 6)
check(bandOf(low3, "Rare").To < bandOf(low1, "Rare").To, "L1b (banc) la plus basse perd sa part")}, 'L1b');
	rep(q{section\("L2 caisse Rare.*?(?=check\(logCount\("tick :")}, q{section("L2 caisse Légendaire, ×2 : un Épique (au-dessus de la plus basse) monte aussi (a262)")
local nR = slotOfRarity(STORE_C, "Legendary")
local r2 = bands("Legendary", 2, "AboveLowest", 6)
local item2 = openSlot(B, STORE_C, nR, 2, { midOf(r2, "Epic") })
checkItem("L2a milieu de la bande Épique à ×2", item2, STORE_C, "Epic")
local nC = slotOfRarity(STORE_C, "Rare")
local cb = bands("Rare", 2, "AboveLowest", 6)
local item3 = openSlot(B, STORE_C, nC, 2, { bandOf(cb, "Rare").To - 1e-6 })
checkItem("L2b caisse Rare, juste sous la fin de la bande Rare normalisée", item3, STORE_C, "Rare")
}, 'L2');
}
# Magasin de zone 6 : la vitrine a les PV de la zone 6 ; le banc la casse en quelques coups (multiplicateur de dégâts
# remplacé pendant la casse seulement, comme une potion de force).
if (has(q{-- a262 : magasin de zone 6}) && has(q{	for _ = 1, 60 do
		if store:GetAttribute("HeistOpen") == true then
			return true
		end})) {
	lit(q{	for _ = 1, 60 do
		if store:GetAttribute("HeistOpen") == true then
			return true
		end
		fireAs(p, "HitWindow", window:GetAttribute("WindowId"))
		advance(0.4)
	end
	return store:GetAttribute("HeistOpen") == true}, q{	local a262Mul = WindowS.GetHitDamageMultiplier
	WindowS.GetHitDamageMultiplier = function()
		return 1e6
	end
	for _ = 1, 60 do
		if store:GetAttribute("HeistOpen") == true then
			WindowS.GetHitDamageMultiplier = a262Mul
			return true
		end
		fireAs(p, "HitWindow", window:GetAttribute("WindowId"))
		advance(0.4)
	end
	WindowS.GetHitDamageMultiplier = a262Mul
	return store:GetAttribute("HeistOpen") == true}, 'breakHard');
}
