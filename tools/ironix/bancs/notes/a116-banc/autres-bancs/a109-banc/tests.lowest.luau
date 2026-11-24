--!nocheck
-- L. LuckBoost = "AboveLowest" (pre.lowest.luau) : la chance multiplie toutes les raretés au-dessus de la plus
-- basse de la table de la caisse, puis normalisation.

STORE_C = buildStore("STORE_Z2_Bazar", 2, 140, 1)
startAll()
local B = player("Bob", Vector3.new(135, 3, 10))
flush()
check(SO.LuckBoost == "AboveLowest", "L0 (banc) LuckBoost = AboveLowest")
refillWith({ 0.999, 0.999, 0.99, 0.95, 0.2, 0.5, 0.8, 0.95, 0.995, 0.3 })

-- Un tirage dont la rareté change entre les deux modes, à ×3, sur une caisse `rid` : AboveLowest le donne.
local function differing(rid, luck)
	local low, box = bands(rid, luck, "AboveLowest"), bands(rid, luck, "AboveBox")
	for i = 1, 999 do
		local v = i / 1000
		if expectedAt(low, v) ~= expectedAt(box, v) then
			return v, expectedAt(low, v), expectedAt(box, v)
		end
	end
	return nil
end

section("L1 caisse Mythique, ×3 : le Commun (plus basse) perd sa part, toutes les autres ×3")
local nM = slotOfRarity(STORE_C, "Mythic")
local v, wantLow, wantBox = differing("Mythic", 3)
check(v ~= nil, `L1 (banc) un tirage où les deux modes diffèrent : {tostring(v)} → {tostring(wantLow)} (AboveBox : {tostring(wantBox)})`)
local item = openSlot(B, STORE_C, nM, 3, { v })
checkItem(`L1a tirage {v}, AboveLowest`, item, STORE_C, wantLow)
local low3 = bands("Mythic", 3, "AboveLowest")
local low1 = bands("Mythic", 1, "AboveLowest")
check(bandOf(low3, "Common").To < bandOf(low1, "Common").To, "L1b (banc) la plus basse perd sa part")

section("L2 caisse Rare, ×2 : un Peu commun (au-dessus de la plus basse) monte aussi")
local nR = slotOfRarity(STORE_C, "Rare")
local r2 = bands("Rare", 2, "AboveLowest")
local item2 = openSlot(B, STORE_C, nR, 2, { midOf(r2, "Uncommon") })
checkItem("L2a milieu de la bande Peu commun à ×2", item2, STORE_C, "Uncommon")
local nC = slotOfRarity(STORE_C, "Common")
local cb = bands("Common", 2, "AboveLowest")
local item3 = openSlot(B, STORE_C, nC, 2, { bandOf(cb, "Common").To - 1e-6 })
checkItem("L2b caisse Commune, juste sous la fin de la bande Commune normalisée", item3, STORE_C, "Common")
check(logCount("tick :", "WARN", "server") == 0 and logCount("LuckBoost", nil, "server") == 0, "L3 aucune erreur, aucun avertissement LuckBoost")

summary("scénario lowest")
