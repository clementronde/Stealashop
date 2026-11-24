--!nocheck
-- D. Règle de la vague 32 (Cantin, 2026-11-13), LuckBoost = "AboveBox" (valeur de Config/ShelfOpen) : rareté
-- de la caisse sur le rayon, contenu tiré à la sortie dans la table de la caisse avec la chance.

STORE_C = buildStore("STORE_Z2_Bazar", 2, 140, 1)
startAll()
local A = player("Alice", Vector3.new(60, 3, 10)) -- zone 1 (STORE_A)
local B = player("Bob", Vector3.new(135, 3, 10)) -- zone 2 (STORE_C)
flush()
local lucks = luckValues()
local LMAX = lucks[#lucks]
local MODE = "AboveBox"

section("D0 Config/ShelfOpen")
check(SO.LuckBoost == MODE, "D0a LuckBoost par défaut : AboveBox (" .. tostring(SO.LuckBoost) .. ")")
check(SO.UpgradeMax == nil and SO.UpgradeChance == nil and SO.UpgradeChanceCap == nil and SO.UpgradeDecay == nil and SO.UpgradeTop == nil, "D0b crans retirés")
local tables = 0
for _, r in Rarities.List do
	local t = SO.BoxRarityOdds[r.Id]
	if t then
		tables += 1
		local sum = 0
		for _, w in t do
			sum += w
		end
		check(near(sum, 100, 1e-6), `D0c table {r.Id} : 100 ({sum})`)
		check((t.Secret or 0) > 0, `D0d table {r.Id} : un Secret possible`)
	end
end
check(tables == 8, "D0e 8 tables, Commun à Divine")

section("D1 mise en rayon : rareté de la caisse seulement")
-- Motif par magasin (Luxe, Premium ×3, Standard ×6) : en zone 2 (Rarities.BoxOdds) → Secret, Mythic,
-- Legendary, Epic, puis Common, Common, Uncommon, Rare, Epic, Common.
refillWith({ 0.999, 0.999, 0.99, 0.95, 0.2, 0.5, 0.8, 0.95, 0.995, 0.3 })
local count = {}
local leak, badLabel, noBox = nil, nil, 0
for _, store in { STORE_A, STORE_C } do
	for _, b in shelfBoxes(store) do
		local rid = b:GetAttribute("BoxRarity")
		if rid == nil then
			noBox += 1
		end
		if store == STORE_C and rid then
			count[rid] = (count[rid] or 0) + 1
		end
		for name in b:GetAttributes() do
			if name == "ItemId" or name == "Rarity" or string.find(name, "Mutation", 1, true) then
				leak = name
			end
		end
		local l = labelOf(b)
		if l == nil or l.Rarity ~= (Rarities.ById[rid] and Rarities.ById[rid].DisplayNameUpper) or l.Category or l.Mutation then
			badLabel = b:GetFullName()
		end
	end
end
check(noBox == 0, "D1a chaque caisse porte BoxRarity")
check(leak == nil, "D1b aucun attribut du contenu (ItemId, Rarity, Mutation*) sur une caisse (" .. tostring(leak) .. ")")
check(badLabel == nil, "D1c BB_Box : la rareté de la caisse seule, Category et Mutation cachées (" .. tostring(badLabel) .. ")")
local zoneOne = true
for _, b in shelfBoxes(STORE_A) do
	zoneOne = zoneOne and b:GetAttribute("BoxRarity") == "Common"
end
check(zoneOne, "D1d zone 1 (ShelfBoxes.ZoneOdds) : caisses Communes")
local wantCount = { Secret = 1, Mythic = 1, Legendary = 1, Epic = 2, Rare = 1, Uncommon = 1, Common = 3 }
local same = true
for id, n in wantCount do
	same = same and count[id] == n
end
check(same, "D1e (banc) tirage forcé de la mise en rayon : caisses Secret à Commun en zone 2")

section("D2 rareté de l'objet tirée dans la table de la caisse (×1)")
for _, rid in { "Common", "Uncommon", "Rare", "Legendary", "Secret" } do
	local n = slotOfRarity(STORE_C, rid)
	if n then
		local list = bands(rid, 1, MODE)
		local item, boxRarity = openSlot(B, STORE_C, n, 1, { midOf(list, rid) })
		check(boxRarity == rid, `D2 (banc) caisse {rid}`)
		checkItem(`D2 caisse {rid}, ×1, milieu de sa bande`, item, STORE_C, rid)
	else
		check(false, `D2 (banc) pas de caisse {rid} en zone 2`)
	end
end
check(logHas("caisse Rare → objet Rare (", nil, "server"), "D2 log « caisse <rareté> → objet <rareté> (<ItemId>) »")
check(logHas("chance ×1, caisse Secret → objet Secret (", nil, "server"), "D2 log avec la chance")

section("D3 rien n'est garanti : une caisse Mythique peut donner un Commun")
local nM = slotOfRarity(STORE_C, "Mythic")
local itemM = openSlot(B, STORE_C, nM, 2, { 0 })
checkItem("D3a caisse Mythique, ×2, tirage tout en bas", itemM, STORE_C, "Common")

section("D4 la chance (AboveBox) et la normalisation")
local nE1 = slotOfRarity(STORE_C, "Epic")
local nE2 = slotOfRarity(STORE_C, "Epic", { [nE1] = true })
local b1, b3 = bands("Epic", 1, MODE), bands("Epic", 3, MODE)
local epic1, epic3 = bandOf(b1, "Epic"), bandOf(b3, "Epic")
-- À ×3, seules les raretés au-dessus d'Épique sont ×3 : la bande Épique se termine plus tôt.
local v = (epic3.To + epic1.To) / 2
check(expectedAt(b1, v) == "Epic" and expectedAt(b3, v) ~= "Epic", "D4 (banc) un tirage Épique à ×1 qui ne l'est plus à ×3")
local itemE = openSlot(B, STORE_C, nE1, 3, { v })
checkItem(`D4a caisse Épique, ×3, tirage {v}`, itemE, STORE_C, expectedAt(b3, v))
local itemE2 = openSlot(B, STORE_C, nE2, 3, { epic3.To - 1e-6 })
checkItem("D4b juste sous la fin de la bande Épique normalisée (×3)", itemE2, STORE_C, "Epic")
-- Sous la caisse et à sa rareté, les poids ne bougent pas, mais leur part baisse (normalisation).
check(bandOf(b3, "Common").To < bandOf(b1, "Common").To, "D4c (banc) à ×3, la part du Commun baisse (normalisation)")

section("D5 zone 1 : objet de la zone la plus proche ; Secret toutes zones ; mutation tirée à la sortie")
local c1 = bands("Common", 1, MODE)
local c10 = bands("Common", LMAX, MODE)
local nA = slotOfRarity(STORE_A, "Common")
local itemU = openSlot(A, STORE_A, nA, 1, { midOf(c1, "Uncommon"), 0, 1 })
checkItem("D5a caisse Commune de zone 1, tirage Peu commun", itemU, STORE_A, "Uncommon")
check(itemU ~= nil and itemU:GetAttribute("MutationSize") == "Tiny" and itemU:GetAttribute("MutationEffect") == nil, "D5b taille tirée à la sortie (tirage forcé : Tiny, sans effet)")
nA = slotOfRarity(STORE_A, "Common")
local itemMy = openSlot(A, STORE_A, nA, 1, { midOf(c1, "Mythic"), 1, 0 })
checkItem("D5c caisse Commune de zone 1, tirage Mythique", itemMy, STORE_A, "Mythic")
check(itemMy ~= nil and itemMy:GetAttribute("MutationSize") == nil and itemMy:GetAttribute("MutationEffect") == "Shiny", "D5d effet tiré à la sortie (tirage forcé : Shiny, sans taille)")
nA = slotOfRarity(STORE_A, "Common")
local itemS = openSlot(A, STORE_A, nA, 1, { 1 - 1e-9 })
checkItem("D5e tirage tout en haut : Secret, toutes zones", itemS, STORE_A, "Secret")
-- Effet de la chance sur une caisse Commune : un tirage Commun à ×1 ne l'est plus à ×LMAX.
local vC = bandOf(c1, "Common").To - 0.01
check(expectedAt(c1, vC) == "Common" and expectedAt(c10, vC) ~= "Common", `D5 (banc) tirage {vC} : Commun à ×1, pas à ×{LMAX}`)
nA = slotOfRarity(STORE_A, "Common")
local itemC1 = openSlot(A, STORE_A, nA, 1, { vC })
checkItem(`D5f ×1, tirage {vC}`, itemC1, STORE_A, "Common")
nA = slotOfRarity(STORE_A, "Common")
local itemC10 = openSlot(A, STORE_A, nA, LMAX, { vC })
checkItem(`D5g ×{LMAX}, même tirage`, itemC10, STORE_A, expectedAt(c10, vC))
check(logHas(`chance ×{LMAX}, caisse Common → objet {expectedAt(c10, vC)} (`, nil, "server"), "D5h log de la sortie")

section("D6 caisse portée (ancien colis) : rareté seule sur BB_Box")
local common1 = Items.ByZone[1].Common[1]
advance(20)
moveTo(A, Vector3.new(20, 3, 10))
flush()
local started = Carry.StartCarry(A, { Kind = "NPCBox", Tier = "Standard", Zone = 1, Rarity = "Common", ItemId = common1.Id, StoreId = "STORE_Z1_Superette", SlotId = "STORE_Z1_Superette/01", Mutation = { Size = "Big", Effect = "Gold" } })
flush()
local visual = A.Character and A.Character:FindFirstChild("CarryVisual")
local l = visual and labelOf(visual)
check(started == true and l ~= nil, "D6 (banc) colis porté, avec son BB_Box")
check(l ~= nil and l.Rarity == "COMMON" and not l.Category and not l.Mutation, "D6a porté : la rareté seule, ni catégorie ni mutation (BIG · GOLD cachée)")
Carry.Consume(A)
flush()
check(logCount("tick :", "WARN", "server") == 0, "D7 aucune erreur du tick")

summary("scénario draw")
