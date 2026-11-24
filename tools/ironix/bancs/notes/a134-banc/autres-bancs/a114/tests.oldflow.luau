--!nocheck
-- a114 F. Features.ShelfOpen = false (pre.oldflow.luau) : l'ancien déroulé ne change pas. Colis fermé (NPCBox)
-- jamais lié ; attrapé, il retourne sur son rayon ; tombé à la batte, le vigile qui le suit poursuit qui le
-- ramasse (comme avant) ; aucun demi-tour d'un vigile qui rentre.

startAll(true)
local Guard = serverModule("GuardService")
local Features = sharedModule("Config/Features")
check(Features.ShelfOpen == false, "F0 (banc) Features.ShelfOpen = false")
local A = player("Alice", Vector3.new(60, 3, 10))
local B = player("Bob", Vector3.new(65, 3, 10))
flush()
local function waitFor(fn, maxSeconds)
	local t = 0
	while not fn() and t < maxSeconds do
		advance(0.1)
		t += 0.1
	end
	return fn()
end
breakStore(A, STORE_A)
check(grabShelf(A, STORE_A, 1), "F1 (banc) Alice prend le colis fermé")
local payload = Carry.GetPayload(A)
advance(0.1)
local g = guardFor(A)
check(payload.Kind == "NPCBox" and g ~= nil, "F1a un vigile à la prise (ancien déroulé)")
check(Guard.GetLinkedGuard(payload) == nil, "F1b colis fermé : jamais lié")
moveTo(A, Vector3.new(65, 3, 12))
check(waitFor(function()
	return not Carry.IsCarrying(A)
end, 30), "F2 (banc) attrapée")
check(#batDrops() == 0 and Guard.GetLinkedGuard(payload) == nil, "F2a rien au sol, pas de lien")
advance(3)
check(boxAt(STORE_A, 1) ~= nil, "F2b le colis est retourné sur son rayon")
check(logCount("fait demi-tour", "PRINT", "server") == 0 and logCount("ressort", "PRINT", "server") == 0, "F2c aucun demi-tour, aucun vigile qui ressort")
check(logCount("tick :", "WARN", "server") == 0, "F3 aucune erreur du tick")

summary("scénario oldflow")
