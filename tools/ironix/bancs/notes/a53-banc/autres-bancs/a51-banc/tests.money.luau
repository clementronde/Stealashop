--!nocheck
-- Scénario « money » (DEV-100 avec L-089) : la boutique Robux suit les colis posés au sol, rangés par uid :
-- GetWaiting(player) = { [boxUid] = ReadyAt }, attribut OpenNowReadyAt = le colis qui attend le plus,
-- « Ouvrir maintenant » (reçu) raccourcit ce colis (SkipWait(player, boxUid, s)) ; sans colis posé, le
-- crédit est gardé et retiré du prochain colis posé (OnBoxPlaced(player, boxUid, box)). Un colis de
-- l'inventaire n'attend pas : il ne compte pas.
-- Le palier 1 d'« Ouvrir maintenant » reçoit un Id (8101) dans le texte de Config/Monetization.

do
	local key = "shared/Config/Monetization.luau"
	local source = SOURCES[key]
	local from = "{ Id = 0, Price = 19, Skip = 60 }"
	local first, last = string.find(source, from, 1, true)
	assert(first, `remplacement introuvable dans {key} : {from}`)
	SOURCES[key] = string.sub(source, 1, first - 1) .. "{ Id = 8101, Price = 19, Skip = 60 }" .. string.sub(source, last + 1)
end

advance(1000)
startServer()

section("colis posés : GetWaiting par uid, OpenNowReadyAt")
local ada = join("Ada", nil)
advance(1.5)
local stored = bringBox(ada, "Epic", "Z3_TeleGeante", "Premium", 3)
check(next(UnboxService.GetWaiting(ada)) == nil and ada:GetAttribute("OpenNowReadyAt") == nil, "colis dans l'inventaire : rien n'attend")
local u1 = bringBox(ada, "Uncommon", "Z2_YoYo", "Standard", 2)
local b1 = placeAt(ada, u1, 6, 20)
local b2 = placeAt(ada, stored, 12, 20)
local waiting = UnboxService.GetWaiting(ada)
check(waiting[u1] ~= nil and waiting[stored] ~= nil and near(waiting[stored], b2.ReadyAt, 1e-6), "GetWaiting : [uid] = ReadyAt des deux colis posés")
advance(1.2)
check(near(ada:GetAttribute("OpenNowReadyAt") or 0, b2.ReadyAt, 1e-6), "OpenNowReadyAt = l'Épique, celui qui attend le plus")

section("« Ouvrir maintenant » : 60 s de moins sur le colis qui attend le plus")
local before = b2.ReadyAt
local entry = receipt(ada, 8101)
check(settle(entry) == Enum.ProductPurchaseDecision.PurchaseGranted, "reçu accordé")
check(near(dataOf(ada).Boxes[stored].ReadyAt, before - 60, 1e-6), "ReadyAt de l'Épique avancé de 60 s (profil)")
local model = floorBoxOf(ada, stored)
check(model and near(model:GetAttribute("ReadyAt"), before - 60, 1e-6), "et au sol (attribut ReadyAt du FloorBox)")
check(#notifies(ada, "shorter") == 1, "Notify « Your box wait is 1:00 shorter! »")
check(UnboxService.SkipWait(ada, stored, 1e6) == 0 and #remotes("BoxReady", function(e) return e.to == ada and e.args[1] == stored end) == 1, "SkipWait jusqu'à maintenant : prêt, BoxReady(boxUid)")
check(UnboxService.SkipWait(ada, "pas-un-colis", 10) == nil, "SkipWait d'un colis inconnu : nil")

section("sans colis qui attend : crédit, retiré du prochain colis posé")
-- Le Peu commun posé est peut-être encore en attente : on ouvre les deux.
openPlaced(ada, u1)
openPlaced(ada, stored)
check(next(UnboxService.GetWaiting(ada)) == nil, "plus rien n'attend")
local entry2 = receipt(ada, 8101)
check(settle(entry2) == Enum.ProductPurchaseDecision.PurchaseGranted and dataOf(ada).Monetization.OpenNowCredit == 60, "reçu : 60 s de crédit")
local u3 = bringBox(ada, "Epic", "Z3_TeleGeante", "Premium", 3)
check(dataOf(ada).Monetization.OpenNowCredit == 60, "rangé dans l'inventaire : crédit pas encore utilisé")
local t0 = serverTime()
local b3 = placeAt(ada, u3, 18, 20)
flush()
local epicDelay = Rarities.ById.Epic.OpenDelay
check(b3 and b3.ReadyAt <= t0 + 0.5 + epicDelay - 60 + 1e-6, `posé : attente de l'Épique moins 60 s ({b3 and string.format("%.1f", b3.ReadyAt - t0)} s)`)
check(dataOf(ada).Monetization.OpenNowCredit == 0 and #notifies(ada, "new box wait is") == 1, "crédit utilisé, Notify « Open Now: your new box wait is 1:00 shorter! »")

summary("scénario money")
