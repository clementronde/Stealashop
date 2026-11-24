--!nocheck
-- Scénario « passes » : possession des gamepasses. Lue à l'arrivée (UserOwnsGamePassAsync, dans un
-- pcall, avec nouvel essai), à la fin d'un achat (PromptGamePassPurchaseFinished), cache du profil
-- tant que Roblox n'a pas répondu, gamepass remboursé retiré, acheté pendant la session jamais retiré ;
-- attribut Pass<Clé> pour l'écran ; Id à 0 jamais lu ; HasPass.

startServer()

section("arrivée : possession lue chez Roblox")
-- Possession chez Roblox posée avant l'arrivée (UserId 1 à 5 dans l'ordre des arrivées).
MARKET.owns[1] = { [PASS_IDS.DoubleCash] = true, [PASS_IDS.ExtraStands] = true }
MARKET.owns[2] = { [PASS_IDS.AutoCollect] = true }
MARKET.owns[3] = { [PASS_IDS.FastOpen] = true }
MARKET.owns[4] = { [PASS_IDS.DoubleCash] = true } -- Dan : +4 présentoirs remboursé
local ada = join("Ada", newProfile())
advance(2)
local calls = {}
for _, call in MARKET.ownsCalls do
	if call.userId == ada.UserId then
		calls[call.passId] = (calls[call.passId] or 0) + 1
	end
end
local read = 0
for _ in calls do
	read += 1
end
check(read == 6, `6 gamepasses lus (ceux qui ont un Id), trouvé {read}`)
check(calls[0] == nil, "Id à 0 (Gants hydrauliques) jamais lu")
check(ada:GetAttribute("PassDoubleCash") == true and ada:GetAttribute("PassExtraStands") == true, "attributs PassDoubleCash et PassExtraStands")
check(ada:GetAttribute("PassAutoCollect") == nil and ada:GetAttribute("PassVIP") == nil, "pas d'attribut pour un gamepass pas possédé")
check(MonetizationService.HasPass(ada, "DoubleCash") and MonetizationService.HasPass(ada, "ExtraStands"), "HasPass : possédés")
check(not MonetizationService.HasPass(ada, "AutoCollect") and not MonetizationService.HasPass(ada, "HydraulicGloves"), "HasPass : pas possédés")
check(dataOf(ada).Monetization.Passes.DoubleCash == true and dataOf(ada).Monetization.Passes.AutoCollect == nil, "possession gardée dans le profil (cache de la prochaine arrivée)")

section("panne de Roblox : nouvel essai")
MARKET.ownsFails[PASS_IDS.AutoCollect] = 2
local bob = join("Bob", newProfile())
advance(1)
check(bob:GetAttribute("PassAutoCollect") == nil, "pas encore de réponse pour l'Encaissement auto")
advance(5)
local tries = 0
for _, call in MARKET.ownsCalls do
	if call.userId == bob.UserId and call.passId == PASS_IDS.AutoCollect then
		tries += 1
	end
end
check(tries == 3 and bob:GetAttribute("PassAutoCollect") == true, `3e essai réussi ({tries} appels), gamepass reconnu`)
check(not logHas("Roblox ne répond pas pour", "WARN", "server"), "pas d'avertissement : réussi avant la fin des essais")
MARKET.ownsFails[PASS_IDS.FastOpen] = 4
local cid = join("Cid", newProfile())
advance(8)
check(logHas("Cid : Roblox ne répond pas pour FastOpen", "WARN", "server"), "3 essais ratés : un avertissement")
check(cid:GetAttribute("PassFastOpen") == nil, "toujours inconnu : pas possédé (aucun cache)")
advance(Monetization.PassCheck.SlowRetry + 1)
check(cid:GetAttribute("PassFastOpen") == nil, "4e essai (60 s plus tard) raté")
advance(Monetization.PassCheck.SlowRetry + 1)
check(cid:GetAttribute("PassFastOpen") == true, "5e essai réussi : reconnu")

section("cache du profil tant que Roblox n'a pas répondu")
MARKET.ownsDelay = 3
local data = newProfile()
data.Monetization.Passes = { ExtraStands = true, DoubleCash = true }
addItem(data, "d-1", "Z1_CanetteDeSoda", 1)
addItem(data, "d-21", "Z1_Donut", 21)
addItem(data, "d-22", "Z1_Banane", 22)
local dan = join("Dan", data) -- boutique 4 (Ada 1, Bob 2, Cid 3) : sans présentoir bonus posé
advance(1)
check(dan:GetAttribute("PassExtraStands") == true and dan:GetAttribute("PassDoubleCash") == true, "attributs du cache posés à l'arrivée")
check(dan:GetAttribute("Income") == 2 * dan:GetAttribute("ExposedIncome"), "×2 Argent actif dès l'arrivée (cache)")
-- Boutique 4 sans présentoir bonus posé : les objets 21 et 22 retournent à l'inventaire. Le cache
-- avec des présentoirs bonus posés est vérifié dans le scénario « effects ».
check(dataOf(dan).Display["1"] == "d-1", "objet du présentoir 1 exposé")
advance(25)
check(dan:GetAttribute("PassExtraStands") == nil and not MonetizationService.HasPass(dan, "ExtraStands"), "Roblox répond « pas possédé » (remboursé) : retiré")
check(dataOf(dan).Monetization.Passes.ExtraStands == nil and dataOf(dan).Monetization.Passes.DoubleCash == true, "cache mis à jour")
MARKET.ownsDelay = 0.1

section("fin d'achat d'un gamepass")
clearRemotes = function()
	table.clear(REMOTE_LOG)
end
clearRemotes()
local bobIncome = bob:GetAttribute("ExposedIncome")
finishPassPurchase(bob, PASS_IDS.DoubleTraining, false)
check(bob:GetAttribute("PassDoubleTraining") == nil and #notifies(bob) == 0, "fenêtre fermée sans achat : rien")
finishPassPurchase(bob, 123456, true)
check(#notifies(bob) == 0, "gamepass inconnu : rien")
finishPassPurchase(bob, PASS_IDS.DoubleTraining, true)
check(bob:GetAttribute("PassDoubleTraining") == true and MonetizationService.HasPass(bob, "DoubleTraining"), "acheté : possédé tout de suite")
check(#notifies(bob, "×2 Training unlocked!") == 1, "Notify « ×2 Training unlocked! »")
check(dataOf(bob).Monetization.Passes.DoubleTraining == true, "gardé dans le cache du profil")
finishPassPurchase(bob, PASS_IDS.DoubleTraining, true)
check(#notifies(bob, "unlocked") == 1, "2e fin d'achat du même gamepass : pas de 2e message")

section("acheté pendant la session : une réponse plus ancienne ne le retire pas")
MARKET.ownsDelay = 2
local eve = join("Eve", newProfile())
advance(0.5)
finishPassPurchase(eve, PASS_IDS.DoubleCash, true) -- Roblox répondra « pas possédé » (cache de Roblox)
advance(15)
check(eve:GetAttribute("PassDoubleCash") == true and MonetizationService.HasPass(eve, "DoubleCash"), "toujours possédé après la réponse d'arrivée")
MARKET.ownsDelay = 0.1

section("départ et retour")
leave(ada)
local ada2 = join("Ada", nil, ada.UserId)
check(ada2:GetAttribute("PassDoubleCash") == true, "retour : possession du cache affichée tout de suite")
advance(2)
check(ada2:GetAttribute("PassDoubleCash") == true and ada2:GetAttribute("PassExtraStands") == true, "puis confirmée par Roblox")

summary("scénario passes")
