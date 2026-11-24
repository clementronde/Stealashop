--!nocheck
-- pc-reach : colis à GrabTime 0 (un seul appel, ni début ni fin de maintien) : contrôle strict.
startAll()
local A = player("Alice", Vector3.new(60, 3, 10))
flush()
rawget(humanoidOf(A), "_props").WalkSpeed = 22
PING[A] = 0.15
check(Balance.Heist.BoxTiers.Standard.GrabTime == 0, "Z0 (banc) GrabTime 0 dans le faux arbre")
local function at(n, d)
	local pos = slotAttachment(STORE_A, n).WorldPosition
	moveTo(A, Vector3.new(pos.X, pos.Y, pos.Z - d), Vector3.new(0, 0, 1))
end
breakStore(A, STORE_A)
local box = boxAt(STORE_A, 1)
at(1, 12.6)
fireAs(A, "OpenShelfBox", box:GetAttribute("SlotId"))
flush()
check(not isOpening(box), "Z1 un appel à 12,6 studs en courant : refusé (strict)")
advance(0.3)
at(1, 7.9)
fireAs(A, "OpenShelfBox", box:GetAttribute("SlotId"))
flush()
check(isOpening(box), "Z2 un appel à 7,9 studs : ouverture lancée")
local maxLuck = 1
for _, e in SO.LuckTable do
	maxLuck = math.max(maxLuck, e.Luck)
end
advance(SOS.revealDelay(maxLuck) + 0.5)
local item = itemAt(STORE_A, 1)
check(item ~= nil, "Z3 (banc) l'objet est sorti")
if item then
	at(1, 12.6)
	fireAs(A, "GrabItem", item:GetAttribute("SlotId"))
	flush()
	check(not Carry.IsCarrying(A), "Z4 GrabItem en un appel à 12,6 studs : refusé (strict)")
	advance(0.3)
	at(1, 7.9)
	fireAs(A, "GrabItem", item:GetAttribute("SlotId"))
	flush()
	check(Carry.IsCarrying(A), "Z5 GrabItem en un appel à 7,9 studs : pris")
end
summary("scénario zero")
