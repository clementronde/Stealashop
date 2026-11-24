--!nocheck
-- V. Rareté tirée sans aucun objet dans tout le catalogue (Divine aujourd'hui) : l'objet est de la rareté la
-- plus proche en dessous qui en a (Secret), avec un avertissement (pre.divine.luau : caisses Communes
-- { Common = 1, Divine = 1 }).

startAll()
local A = player("Alice", Vector3.new(60, 3, 10))
flush()
check(#Items.Divines == 0, "V0 (banc) aucun objet Divine au catalogue")
check(SO.BoxRarityOdds.Common.Divine == 1 and SO.BoxRarityOdds.Common.Common == 1, "V0 (banc) table Commune modifiée")
local list = bands("Common", 1, SO.LuckBoost)
local n = slotOfRarity(STORE_A, "Common")
local item = openSlot(A, STORE_A, n, 1, { midOf(list, "Divine") })
checkItem("V1 tirage Divine : un Secret à la place", item, STORE_A, "Secret")
check(logHas("aucun objet Divine tirable dans aucune zone", nil, "server"), "V2 avertissement du garde-fou")
check(logHas("caisse Common → objet Secret (", nil, "server") and logHas("(tirée : Divine, aucun objet nulle part)", nil, "server"), "V3 log : rareté tirée et rareté sortie")
n = slotOfRarity(STORE_A, "Common")
local item2 = openSlot(A, STORE_A, n, 1, { midOf(list, "Common") })
checkItem("V4 tirage Commun", item2, STORE_A, "Common")
check(logCount("tick :", "WARN", "server") == 0, "V5 aucune erreur du tick")

summary("scénario divine")
