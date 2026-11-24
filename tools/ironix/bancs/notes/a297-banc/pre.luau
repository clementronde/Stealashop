--!nocheck
-- a297 : après le pre.luau d'a294 (Ids de banc, SET_ENVIRONMENT, BancStartCrateReveal). MonetizationService.BancNewPlay()
-- remet le crochet de test comme au chargement du module (compteur à 0, pas encore de GUID) : un nouveau Play, avec le
-- même profil (ses Purchases gardés).
REPLACE("server/Services/MonetizationService.luau", "local testSession: string? = nil\n", "local testSession: string? = nil\nMonetizationService.BancNewPlay = function() testCount = 0; testSession = nil end -- banc a297\n")
