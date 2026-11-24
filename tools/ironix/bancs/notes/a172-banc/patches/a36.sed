# a172 (vague 53), banc a36 (anti-triche) : section C4 retirée. Elle vérifiait l ancien déroulé (Features.ShelfOpen forcé à
# false par ancien-deroule.luau) : à la fin du chrono le magasin fermait et sortait Bob, resté au fond sans colis, tout de
# suite. L interrupteur parti, c est la règle L-118 : un vigile vient pour l intrus, l attrape, et Bob n est sorti qu après le
# coup (stepLocks) ; le faux Roblox de ce banc n a ni OverlapParams (CatchReach) ni sol au fond du magasin (détection « en
# l air » pendant l attente). La sortie autorisée (moveOut, AntiCheatService.Allow) reste vérifiée par C5 (vitrine
# reconstruite) ; la sortie après capture par les bancs a110 et a118.
/^section\("C4 Magasin fermé avec Bob dedans/,/^section\("C5 /{/^section\("C5 /!d}
