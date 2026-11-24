--!nocheck
-- Banc a293 (copie de a286-banc/tests-complice.luau), partie « complice » (harnais d'a202, ouverture d'avant) : Features.HeistPartnerBonus allumé dans Config (a293, pas forcé). Alice prend
-- un objet et le range (Consume) ; Bob, son ami entré dans le magasin pendant la même ouverture, reçoit
-- Balance.Heist.PartnerBonusSeconds s du revenu de l'objet ; Cy, entré aussi mais pas ami : rien ; Dan, ami mais
-- pas entré : rien. Un objet perdu (Fail) ne paie personne.
moduleScript(SERVICES, "HubService", "stub/HubService")
startAll(true)
local DS = serverModule("DataService")
CASH = {}
DS.AddCash = function(p, amount)
	CASH[p] = (CASH[p] or 0) + amount
	return CASH[p]
end
local Balance = sharedModule("Config/Balance")
local A = player("Alice", Vector3.new(60, 3, 10))
local B = player("Bob", Vector3.new(66, 3, 10))
local C = player("Cy", Vector3.new(70, 3, 10))
local Dn = player("Dan", Vector3.new(-300, 3, -300)) -- loin des deux magasins
flush()
FRIENDS["Alice+Bob"] = true
FRIENDS["Alice+Dan"] = true
local LMIN = luckValues()[1]
-- Prise de l'objet du rayon (a202 head) avec le temps de prise de la rareté de la caisse (vague 76 : plus d'attribut Tier).
local Rarities = sharedModule("Config/Rarities")
function openHoldTime(slotId) -- vague 76 : temps de maintien de la rareté de la caisse (BoxRarity), plus de Tier
	for _, m in CollectionService:GetTagged("ShelfBox") do
		if m:GetAttribute("SlotId") == slotId then
			return Rarities.GrabTime(m:GetAttribute("BoxRarity")) + 0.05
		end
	end
	return 0
end
function takeItem(p, store, n)
	standAt(p, store, n)
	local item = itemAt(store, n)
	if item == nil then
		return false
	end
	local rarity = item:GetAttribute("BoxRarity") or item:GetAttribute("Rarity")
	local grabTime = if Rarities.GrabTime then Rarities.GrabTime(rarity) else 1
	local slotId = item:GetAttribute("SlotId")
	fireAs(p, "GrabItem", slotId, "Begin")
	advance(grabTime + 0.05)
	fireAs(p, "GrabItem", slotId, "End")
	flush()
	return Carry.IsCarrying(p)
end

section("prime au complice")
check(sharedModule("Config/Features").HeistPartnerBonus == true, "Features.HeistPartnerBonus = true (validé par Cantin, 21/11)")
check(Balance.Heist.PartnerBonusSeconds == 60, "PartnerBonusSeconds = 60 (validé par Cantin, 21/11)")
reopen(A, STORE_A)
local item = openAndReveal(A, STORE_A, 1, LMIN, { 0 })
standAt(B, STORE_A, 3)
standAt(C, STORE_A, 4)
advance(0.3)
check(item ~= nil, "objet posé sur le rayon")
check(takeItem(A, STORE_A, 1), "Alice prend l'objet")
local before = #remotes("Notify", function(e) return e.to == B end)
Carry.Consume(A)
flush()
local paid = nil
for _, line in LOG do
	local who, n = string.match(line.text, "prime au complice : (%a+) reçoit (%d+)")
	if who == "Bob" then paid = tonumber(n) end
end
check(paid ~= nil and paid > 0 and CASH[B] == paid, `Bob payé ({CASH[B]} ; journal {paid})`)
check(CASH[C] == nil, "Cy (pas ami) : rien")
check(not logHas("Dan entre dans", nil), "(banc) Dan jamais entré")
check(CASH[Dn] == nil, "Dan (ami, pas entré) : rien")
check(CASH[A] == nil, "Alice (porteuse) : pas de prime")
local notes = remotes("Notify", function(e) return e.to == B and string.find(e.args[1], "Partner bonus!", 1, true) ~= nil end)
check(#notes == 1 and notes[1].args[2] == "Success", "Notify « Partner bonus! » à Bob")
check(#remotes("Notify", function(e) return e.to == B end) == before + 1, "un seul Notify à Bob")

section("objet perdu : personne")
local cashB = CASH[B]
local item2 = openAndReveal(A, STORE_A, 2, LMIN, { 0 })
if item2 and takeItem(A, STORE_A, 2) then
	Carry.Fail(A, "Test")
	flush()
	check(CASH[B] == cashB, "Fail : Bob pas payé")
else
	check(false, "second objet pris (préparation)")
end
summary("scénario a293 complice")
