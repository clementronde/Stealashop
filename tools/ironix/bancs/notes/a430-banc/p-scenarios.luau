
---------------------------------------------------------------- P (a430, L-325 (3)) : la récompense attend le joueur
-- (inséré dans autres-bancs/a409/tests.luau après S5a ; gardé ici pour la relecture)
table.clear(playerList)
now += 14 * 86400 -- trois semaines après la semaine récompensée
local SP = freshWeekly(true)
SP.Init()
local fen = newPlayer("Fen", 1119) -- 2e du revenu de la semaine `week`, absent depuis
loadProfile(fen, { Items = {}, Lifetime = { Heists = 0, Steals = 0 }, WeeklyBoard = { Week = week, BestIncome = 2000, StealsAt = 0, Rewarded = {}, Pending = {} } })
local fb = profiles[fen].WeeklyBoard
check(#giftsOf(fen) == 0 and #fb.Pending == 1 and fb.Pending[1] == week and fb.Week == W.WeekOf(now), "P1a absent 3 semaines : la semaine jouée attend dans Pending (top pas encore lu)")
SP.Step(0)
check(#giftsOf(fen) == 1 and giftsOf(fen)[1].rule.TopCount == 2 and #fb.Pending == 0 and fb.Rewarded.WeeklyIncome == week and fb.Rewarded.WeeklySteals == week, "P1b récompense donnée des semaines plus tard, semaine retirée de Pending")
SP.Step(5 * W.ReadInterval)
check(#giftsOf(fen) == 1, "P1c pas de deuxième récompense")
local gus = newPlayer("Gus", 1118) -- 3e du revenu de la semaine `week`
full[gus] = true
loadProfile(gus, { Items = {}, Lifetime = { Heists = 0, Steals = 0 }, WeeklyBoard = { Week = week, BestIncome = 1, StealsAt = 0, Rewarded = {}, Pending = {} } })
SP.Step(10 * W.ReadInterval)
local gub = profiles[gus].WeeklyBoard
check(#giftsOf(gus) == 0 and gub.Pending[1] == week and gub.Rewarded.WeeklyIncome == nil and gub.Rewarded.WeeklySteals == week, "P2a inventaire plein : la semaine reste dans Pending (vols réglés : hors du top)")
for _, fn in releasing do
	fn(gus)
end
table.remove(playerList, table.find(playerList, gus))
now += 7 * 86400 -- il revient la semaine d'après, place faite
full[gus] = nil
-- tops lus une fois par serveur : les données de Hal (plus bas) sont là avant la première lecture de SQ
orderedData[W.StoreName("WeeklyIncome", false, week)]["4242"] = W.Encode("WeeklyIncome", 1110.5) -- 11e du revenu de `week` (sous Fen et Gus : leurs rangs ne bougent pas)
local sw1 = W.StoreName("WeeklySteals", false, week + 1)
orderedData[sw1] = orderedData[sw1] or {}
orderedData[sw1]["4242"] = 99 -- 1er des vols de la semaine d après
local SQ = freshWeekly(true)
SQ.Init()
loadProfile(gus, profiles[gus])
SQ.Step(0)
check(#giftsOf(gus) == 1 and giftsOf(gus)[1].rule.TopCount == 2 and #gub.Pending == 0 and gub.Rewarded.WeeklyIncome == week, "P2b retour une semaine plus tard, place faite : récompense donnée")
-- deux semaines qui attendent : réglées dans l'ordre
local hal = newPlayer("Hal", 4242)
loadProfile(hal, { Items = {}, Lifetime = { Heists = 0, Steals = 99 }, WeeklyBoard = { Week = week + 1, BestIncome = 0, StealsAt = 0, Rewarded = {}, Pending = { week } } })
local hb = profiles[hal].WeeklyBoard
check(#giftsOf(hal) == 1 and giftsOf(hal)[1].rule.TopBoost == 1.5 and #hb.Pending == 1 and hb.Pending[1] == week + 1, "P3a deux semaines attendent : la plus ancienne (top déjà lu) réglée tout de suite, la suivante attend sa lecture")
SQ.Step(5 * W.ReadInterval)
check(#giftsOf(hal) == 2 and #hb.Pending == 0 and hb.Rewarded.WeeklyIncome == week + 1 and hb.Rewarded.WeeklySteals == week + 1, `P3b deux récompenses, une par semaine ({#giftsOf(hal)})`)
SQ.Step(9 * W.ReadInterval)
check(#giftsOf(hal) == 2, "P3c rien de plus")
local ivy = newPlayer("Ivy", 5151)
loadProfile(ivy, { Items = {}, Lifetime = { Heists = 40, Steals = 0 }, WeeklyBoard = { Week = 0, BestIncome = 0, StealsAt = 0, Rewarded = {}, Pending = {} } })
check(#profiles[ivy].WeeklyBoard.Pending == 0 and profiles[ivy].WeeklyBoard.StealsAt == 0 and SQ.ValueOf(ivy, "WeeklySteals") == 0, "P4 gabarit (Week = 0) : rien en attente, compteurs posés")
profiles[ivy].Lifetime.Heists = 90
check(SQ.ValueOf(ivy, "WeeklySteals") == 0, "P5 braquages seuls : 0 vol de la semaine")
table.clear(playerList)
