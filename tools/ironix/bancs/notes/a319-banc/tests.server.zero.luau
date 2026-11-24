--!nocheck
-- Scénario a319 « zero » (à la place de « receipts » d'a38) : DoubleSpeed garde l'Id 0, boutique ouverte.
startServer()
section("a319 : Id 0")
MARKET.owns[1] = { [0] = true }
local ada = join("Ada", newProfile())
advance(2)
local zero = 0
for _, call in MARKET.ownsCalls do
	if call.passId == 0 then
		zero += 1
	end
end
check(zero == 0, "Z1a Id 0 jamais demandé à Roblox")
check(ada:GetAttribute("PassDoubleSpeed") == nil and ada:GetAttribute("PassKnownDoubleSpeed") == nil, "Z1b ni Pass ni PassKnown")
check(TrainingService.GetGainMultiplier(ada, "Treadmill") == 1, "Z1c aucun effet")
finishPassPurchase(ada, 0, true)
advance(3)
check(ada:GetAttribute("PassDoubleSpeed") == nil, "Z1d fin d'achat à l'Id 0 : rien")
check(ada:GetAttribute("PassKnownDoubleCash") == true, "Z1e les autres gamepasses sont lus")
check(not logHas("ERREUR"), "Z9 aucune erreur")
summary("scénario receipts")
