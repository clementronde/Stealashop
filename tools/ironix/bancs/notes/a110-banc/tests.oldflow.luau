--!nocheck
-- F. Features.ShelfOpen = false (pre.oldflow.luau) : l'ancien déroulé ne change pas. Entrer puis sortir sans
-- rien n'a pas de règle à part : pas de note « sans objet », le magasin se ferme à la fin du chrono de
-- Balance.Heist.Duration, aucun vigile pour celui qui n'a rien pris.

startAll(true)
local Features = sharedModule("Config/Features")
check(Features.ShelfOpen == false, "F0 (banc) Features.ShelfOpen = false")
local A = player("Alice", Vector3.new(60, 3, 10))
flush()
breakStore(A, STORE_A)
check(STORE_A:GetAttribute("HeistOpen") == true, "F1 (banc) magasin ouvert")
local endsAt = STORE_A:GetAttribute("HeistEndsAt") - SERVER_TIME_OFFSET
check(near(endsAt - now(), Balance.Heist.Duration, 0.2), "F2 chrono de Balance.Heist.Duration (" .. math.round((endsAt - now()) * 10) / 10 .. " s)")
standAt(A, STORE_A, 1)
advance(0.3)
moveTo(A, Vector3.new(60, 3, 12))
advance(0.3)
check(logCount("sans objet", "PRINT", "server") == 0, "F3 aucune règle « sorti sans objet »")
check(logCount("entre dans", "PRINT", "server") == 0, "F4 pas d'intrus compté (règle L-118 absente)")
local list = remotes("HeistTimer", function(e) return e.to == A and e.args[1] == STORE_A.Name end)
check(#list > 0 and list[#list].args[2] > 0, "F5 chrono toujours affiché dehors, près du magasin (ancien déroulé)")
advance(endsAt - now() + 0.3)
check(STORE_A:GetAttribute("HeistOpen") == false, "F6 fin du chrono : magasin fermé")
check(#guards() == 0, "F7 aucun vigile (rien pris)")
check(grabShelf ~= nil and logCount("tick :", "WARN", "server") == 0, "F8 aucune erreur du tick")

summary("scénario oldflow")
