--!nocheck
-- Scénario a319 « on » (à la place de « passes » d'a38) : gamepass ×2 Speed (DoubleSpeed, Id 9007 du banc).
startServer()
local SPEED = 9007
local function gain(player)
	return TrainingService.GetGainMultiplier(player, "Treadmill")
end

section("a319 : possédé à l'arrivée")
MARKET.owns[1] = { [SPEED] = true }
MARKET.owns[2] = { [SPEED] = true, [PASS_IDS.DoubleTraining] = true }
local ada = join("Ada", newProfile())
local bob = join("Bob", newProfile())
local cid = join("Cid", newProfile())
advance(2)
local read = false
for _, call in MARKET.ownsCalls do
	if call.userId == ada.UserId and call.passId == SPEED then
		read = true
	end
end
check(read, "S1a possession de 9007 demandée à Roblox")
check(ada:GetAttribute("PassDoubleSpeed") == true and ada:GetAttribute("PassKnownDoubleSpeed") == true, "S1b PassDoubleSpeed et PassKnownDoubleSpeed")
check(MonetizationService.HasPass(ada, "DoubleSpeed"), "S1c HasPass")
check(gain(ada) == 2, `S1d gain du tapis × 2 ({gain(ada)})`)
check(gain(bob) == 4, `S1e avec ×2 Training : × 4 ({gain(bob)})`)
if TrainingService.GainPerSecond then
	check(math.abs(TrainingService.GainPerSecond(ada) - 2 * TrainingService.GainPerSecond(cid)) < 1e-9,
		`S1f gain d'une seconde de tapis doublé ({TrainingService.GainPerSecond(ada)} contre {TrainingService.GainPerSecond(cid)})`)
end
check(dataOf(ada).Monetization.Passes.DoubleSpeed == true, "S1g gardé dans le cache du profil")
advance(3600)
check(gain(ada) == 2 and ada:GetAttribute("PassDoubleSpeed") == true, "S1h permanent : toujours × 2 une heure plus tard")

section("a319 : pas possédé")
check(cid:GetAttribute("PassKnownDoubleSpeed") == true and cid:GetAttribute("PassDoubleSpeed") == nil, "S2a connu, pas possédé")
check(gain(cid) == 1 and not MonetizationService.HasPass(cid, "DoubleSpeed"), "S2b aucun effet")

section("a319 : achat en jeu, revérifié par le serveur (a274)")
finishPassPurchase(cid, SPEED, true) -- signal seul : Roblox dit « pas possédé »
advance(3)
check(cid:GetAttribute("PassDoubleSpeed") == nil and gain(cid) == 1, "S3a signal sans possession chez Roblox : rien")
MARKET.owns[cid.UserId] = { [SPEED] = true }
finishPassPurchase(cid, SPEED, true)
advance(3)
check(cid:GetAttribute("PassDoubleSpeed") == true and gain(cid) == 2, "S3b acheté et confirmé : × 2 tout de suite")
check(#notifies(cid, "×2 Speed unlocked!") == 1, "S3c Notify « ×2 Speed unlocked! »")

section("a319 : Roblox ne répond pas")
MARKET.ownsFails[SPEED] = 99
local dan = join("Dan", newProfile())
advance(8)
check(dan:GetAttribute("PassKnownDoubleSpeed") == nil and dan:GetAttribute("PassDoubleSpeed") == nil, "S4a pas de réponse : PassKnown absent (bouton caché)")
check(dan:GetAttribute("PassKnownDoubleCash") == true, "S4b les autres gamepasses ont leur réponse")
MARKET.ownsFails[SPEED] = 0

section("a319 : vieux reçus « x2 vitesse » (produit jamais créé : Id 0, ou inconnu)")
local cash = cashOf(ada)
local purchases = 0
for _ in dataOf(ada).Purchases do
	purchases += 1
end
check(settle(receipt(ada, 0, "OLD-SPEED-1")) == NOT_YET, "S5a reçu au produit 0 : NotProcessedYet")
check(settle(receipt(ada, 7777, "OLD-SPEED-2")) == NOT_YET, "S5b reçu d'un produit inconnu : NotProcessedYet")
check(settle(receipt(ada, 7777, "OLD-SPEED-2")) == NOT_YET, "S5c rejoué : toujours NotProcessedYet (jamais accepté sans don)")
local after = 0
for _ in dataOf(ada).Purchases do
	after += 1
end
check(cashOf(ada) == cash and after == purchases and gain(ada) == 2, "S5d rien donné, aucun PurchaseId noté")

section("a319 : vieux profil avec un temps de boost SpeedBoost (jamais vendu)")
local old = newProfile()
old.Boosts = { Cash = 120, SpeedBoost = 300 }
local eve = join("Eve", old)
advance(2)
check(eve:GetAttribute("CashBoostEndsAt") ~= nil, "S6a boost ×2 argent du profil repris")
check(gain(eve) == 1 and eve:GetAttribute("PassDoubleSpeed") == nil, "S6b le temps SpeedBoost n'a aucun effet")
advance(130)
check(eve:GetAttribute("CashBoostEndsAt") == nil, "S6c le ×2 argent va à son terme")
check(not logHas("ERREUR"), "S9 aucune erreur")

summary("scénario passes")
