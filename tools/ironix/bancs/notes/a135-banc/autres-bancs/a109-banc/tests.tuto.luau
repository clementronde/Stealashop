--!nocheck
-- T. Accroches du tuto (SetContentOverride, SetLuckOverride) avec la règle de la vague 32 : appelées avec la
-- rareté de la caisse et ItemId = "" (contenu pas encore tiré) ; un contenu imposé sort tel quel, sans
-- tirage de rareté ni de mutation.

STORE_C = buildStore("STORE_Z2_Bazar", 2, 140, 1)
startAll()
local Tutorial = sharedModule("Config/Tutorial")
local A = player("Alice", Vector3.new(60, 3, 10))
local B = player("Bob", Vector3.new(135, 3, 10))
flush()

local contentCalls, luckCalls = {}, {}
Heist.SetLuckOverride(function(p, drawn)
	table.insert(luckCalls, { player = p, drawn = drawn })
	if p == A and drawn.Zone == Tutorial.TutorialZone then
		return Tutorial.ShelfLuck
	end
	return nil
end)
Heist.SetContentOverride(function(p, drawn)
	table.insert(contentCalls, { player = p, drawn = drawn })
	if p == A and drawn.Zone == Tutorial.TutorialZone then
		return { Tier = Tutorial.FirstBoxTier, ItemId = Tutorial.GuaranteedItemId }
	end
	if p == B and drawn.Zone == 2 then
		return { Rarity = "Rare" }
	end
	return nil
end)

section("T1 objet garanti du tuto : imposé, sans tirage")
reopen(A, STORE_A)
OPENED_AT[STORE_A] = now()
local box = boxAt(STORE_A, 1)
local boxRarity = box:GetAttribute("BoxRarity")
standAt(A, STORE_A, 1)
fireOpen(A, box:GetAttribute("SlotId"))
check(isOpening(box) and box:GetAttribute("ShelfLuck") == Tutorial.ShelfLuck, "T1a chance imposée par SetLuckOverride (×" .. tostring(box:GetAttribute("ShelfLuck")) .. ")")
check(#luckCalls == 1 and luckCalls[1].drawn.Rarity == boxRarity and luckCalls[1].drawn.ItemId == "", "T1b SetLuckOverride : drawn.Rarity = rareté de la caisse, ItemId = \"\"")
check(#contentCalls == 0, "T1c SetContentOverride pas appelée au lancement")
advance(SOS.revealDelay(Tutorial.ShelfLuck) - 0.05)
for _ = 1, 3 do
	table.insert(HEIST_FORCED, 0.99)
end
advance(0.1)
local left = #HEIST_FORCED
table.clear(HEIST_FORCED)
local item = itemAt(STORE_A, 1)
check(#contentCalls == 1 and contentCalls[1].player == A and contentCalls[1].drawn.Rarity == boxRarity and contentCalls[1].drawn.ItemId == "", "T1d SetContentOverride à la sortie : drawn.Rarity = rareté de la caisse, ItemId = \"\"")
check(item ~= nil and item:GetAttribute("ItemId") == Tutorial.GuaranteedItemId, "T1e l'objet sorti est l'objet garanti (" .. describe(item) .. ")")
check(item ~= nil and item:GetAttribute("Rarity") == Items.ById[Tutorial.GuaranteedItemId].Rarity, "T1f à sa rareté")
check(left == 3, "T1g aucun tirage (ni rareté ni mutation) pour un contenu imposé (" .. left .. " sur 3 non lus)")
check(item ~= nil and item:GetAttribute("MutationSize") == nil and item:GetAttribute("MutationEffect") == nil, "T1h jamais de mutation pour l'objet du tuto")
check(logHas("contenu imposé par le tuto, sans tirage", nil, "server"), "T1i log du contenu imposé")

section("T2 accroche qui ne remplace rien : tirage normal")
local p2 = player("Chloe", Vector3.new(62, 3, 10))
flush()
advance(1.2)
local n2 = slotOfRarity(STORE_A, "Common")
local item2, _, left2 = openSlot(p2, STORE_A, n2, 1, { 0 })
checkItem("T2a tirage normal (tout en bas)", item2, STORE_A, "Common")
check(left2 == 0, "T2b la valeur forcée a servi au tirage de la rareté")

section("T3 Rarity seule imposée : un objet de cette rareté de la zone, sans tirage de rareté")
local nC = 1
local item3, _, left3 = openSlot(B, STORE_C, nC, 1, { 0.999 })
checkItem("T3a Rare imposé en zone 2", item3, STORE_C, "Rare")
check(left3 == 1, "T3b aucun tirage de rareté ni de mutation")
check(item3 ~= nil and item3:GetAttribute("MutationSize") == nil and item3:GetAttribute("MutationEffect") == nil, "T3c aucune mutation")
Heist.SetContentOverride(nil)
Heist.SetLuckOverride(nil)
check(logCount("tick :", "WARN", "server") == 0, "T4 aucune erreur du tick")

summary("scénario tuto")
