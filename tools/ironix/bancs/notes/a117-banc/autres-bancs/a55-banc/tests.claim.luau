--!nocheck
-- Scénario « claim » d'a117 (vague 34, 2026-11-13, L-127 point 2), sur la copie a117 du banc a55 : la prime d'une
-- zone complète de l'Index attend d'être réclamée. Remote ClaimIndexReward(zone) : la zone seule ; sans zone :
-- toutes les zones complètes pas encore réclamées, en une demande. Revérifié par le serveur, jamais deux fois
-- (deux demandes d'affilée, retour du joueur), refus (zone pas complète, déjà réclamée, hors de l'index, type
-- faux), attribut IndexClaimed, télémétrie, primes déjà versées gardées.

advance(1000)
startServer()

local function telemetryOf(player)
	local list = {}
	for _, e in TELEMETRY do
		if e.player == player and e.kind == "IndexReward" then
			table.insert(list, e)
		end
	end
	return list
end
local function profileWith(zones, missing)
	local data = newProfile()
	local n = 0
	for _, zone in zones do
		for _, item in Index.ByZone[zone] do
			if item.Id ~= missing then
				n += 1
				addItem(data, `it-{n}`, item.Id, nil, zone, 500)
			end
		end
	end
	return data
end
local Z1, Z2, Z3 = Index.ZoneCash(1), Index.ZoneCash(2), Index.ZoneCash(3)

section("Config/Index : zones réclamées")
check(Index.ClaimedAttribute == "IndexClaimed", "attribut IndexClaimed")
check(Index.EncodeZones({ ["3"] = 1, ["1"] = 2 }) == "1,3" and Index.EncodeZones({ [2] = true }) == "2" and Index.EncodeZones({}) == "", "EncodeZones : « 1,3 », « 2 », « »")
local decoded = Index.DecodeZones("1,3,9,0,x,2.5")
check(decoded[1] and decoded[3] and not decoded[9] and not decoded[0] and countKeys(decoded) == 2, "DecodeZones : 9, 0, x et 2.5 ignorés")
check(countKeys(Index.DecodeZones(nil)) == 0, "DecodeZones(nil) : vide")

section("rien versé tout seul : ni à la complétion, ni au chargement")
local ada = join("Ada", profileWith({ 1, 2, 3 }, "Z1_Carotte"))
advance(1.5)
local d = dataOf(ada)
check(d.Cash == 1000 and d.IndexRewards == nil and ada:GetAttribute("IndexClaimed") == "", "zones 2 et 3 complètes : rien versé, IndexClaimed vide")
local claimable = IndexService.GetClaimableZones(ada)
check(#claimable == 2 and claimable[1] == 2 and claimable[2] == 3, "GetClaimableZones : 2 et 3")
IndexService.Discover(ada, "Z1_Carotte")
flush()
check(d.Cash == 1000 and #notifies(ada, "Index: Zone 1 complete! +3% speed and +5% income forever. Claim your $10.2K in the Index!") == 1, "zone 1 complétée : un message, rien versé")
check(#IndexService.GetClaimableZones(ada) == 3, "3 zones à réclamer")

section("une zone : ClaimIndexReward(zone)")
advance(1.1) -- débit de Net : 2 appels par seconde
fireAs(ada, "ClaimIndexReward", 2)
flush()
check(d.Cash == 1000 + Z2, `zone 2 seule : +{Z2} $`)
check(type(d.IndexRewards) == "table" and type(d.IndexRewards["2"]) == "number" and d.IndexRewards["1"] == nil and d.IndexRewards["3"] == nil, "IndexRewards : la 2 seule")
check(ada:GetAttribute("IndexClaimed") == "2", "IndexClaimed « 2 »")
local tel = telemetryOf(ada)
check(#tel == 1 and tel[1].amount == Z2 and tel[1].sku == "IndexZone2", "télémétrie IndexReward, SKU IndexZone2")

section("jamais deux fois")
advance(1.1) -- débit de Net : 2 appels par seconde
fireAs(ada, "ClaimIndexReward", 2)
fireAs(ada, "ClaimIndexReward", 2)
flush()
check(d.Cash == 1000 + Z2 and #telemetryOf(ada) == 1, "zone 2 redemandée deux fois : rien")
advance(1.1) -- débit de Net : 2 appels par seconde
fireAs(ada, "ClaimIndexReward", 1)
fireAs(ada, "ClaimIndexReward", 1)
flush()
check(d.Cash == 1000 + Z2 + Z1 and #telemetryOf(ada) == 2, "zone 1 demandée deux fois d'affilée : versée une fois")
check(ada:GetAttribute("IndexClaimed") == "1,2", "IndexClaimed « 1,2 »")

section("refus")
local before = d.Cash
advance(1.1) -- débit de Net : 2 appels par seconde
fireAs(ada, "ClaimIndexReward", 4)
flush()
check(d.Cash == before and d.IndexRewards["4"] == nil, "zone 4 pas complète : rien")
advance(1.1) -- débit de Net : 2 appels par seconde
fireAs(ada, "ClaimIndexReward", 7)
fireAs(ada, "ClaimIndexReward", 99)
flush()
check(d.Cash == before and countKeys(d.IndexRewards) == 2, "zones 7 et 99 (hors de l'index) : rien")
advance(1.1) -- débit de Net : 2 appels par seconde
fireAs(ada, "ClaimIndexReward", 0)
fireAs(ada, "ClaimIndexReward", 2.5)
advance(1.1)
fireAs(ada, "ClaimIndexReward", "3")
flush()
check(d.Cash == before and d.IndexRewards["3"] == nil, "0, 2.5 et « 3 » refusés (Net) : la zone 3 attend toujours")

section("toutes : ClaimIndexReward()")
advance(1.1) -- débit de Net : 2 appels par seconde
fireAs(ada, "ClaimIndexReward")
fireAs(ada, "ClaimIndexReward")
flush()
check(d.Cash == before + Z3 and #telemetryOf(ada) == 3, `Claim All : la zone 3 seule (+{Z3} $), une fois`)
check(ada:GetAttribute("IndexClaimed") == "1,2,3" and #IndexService.GetClaimableZones(ada) == 0, "IndexClaimed « 1,2,3 », plus rien à réclamer")
advance(1.1) -- débit de Net : 2 appels par seconde
fireAs(ada, "ClaimIndexReward")
flush()
check(d.Cash == before + Z3, "rien à réclamer : rien")
local paid = table.clone(d.IndexRewards)
leave(ada)
local saved = SAVED["Player_1"]
check(saved and saved.IndexRewards and saved.IndexRewards["1"] == paid["1"] and saved.IndexRewards["3"] == paid["3"], "sauvegardé avec IndexRewards")
local back = join("Ada", nil, 1)
advance(1.5)
check(back:GetAttribute("IndexClaimed") == "1,2,3" and dataOf(back).Cash == saved.Cash, "retour : IndexClaimed « 1,2,3 », rien de plus")
advance(1.1) -- débit de Net : 2 appels par seconde
fireAs(back, "ClaimIndexReward")
flush()
check(dataOf(back).Cash == saved.Cash and #telemetryOf(back) == 0, "retour : Claim All ne verse rien")
leave(back)

section("Claim All de plusieurs zones en une demande ; primes d'avant gardées")
local old = profileWith({ 1, 2, 3 })
old.IndexRewards = { ["1"] = 123 } -- versée par l'ancien code (tout seul)
local bob = join("Bob", old)
advance(1.5)
check(bob:GetAttribute("IndexClaimed") == "1" and dataOf(bob).Cash == 1000, "prime 1 déjà versée : IndexClaimed « 1 », rien de plus au chargement")
advance(1.1) -- débit de Net : 2 appels par seconde
fireAs(bob, "ClaimIndexReward")
flush()
check(dataOf(bob).Cash == 1000 + Z2 + Z3 and #telemetryOf(bob) == 2, `une demande : zones 2 et 3 (+{Z2 + Z3} $)`)
check(dataOf(bob).IndexRewards["1"] == 123 and bob:GetAttribute("IndexClaimed") == "1,2,3", "la date de la prime 1 est gardée ; « 1,2,3 »")
leave(bob)

summary("scénario claim")
