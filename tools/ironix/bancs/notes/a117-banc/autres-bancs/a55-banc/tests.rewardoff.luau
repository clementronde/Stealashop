--!nocheck
-- Scénario « rewardoff » d'a55 : Features.Index = false (MAJ 2 pas ouverte). Une zone complète ne donne
-- ni prime, ni vitesse, ni message, et rien n'est noté dans IndexRewards : la prime sera versée au premier
-- chargement après l'ouverture (scénario « reward », section des zones déjà complètes). Copie a117 : à réclamer.

advance(1000)
startServer()

local function walk(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return if humanoid then humanoid.WalkSpeed else -1
end

section("index fermé")
check(not logHas("[Loader", "WARN"), "aucun module en échec au chargement")
check(Features.Index == false, "Features.Index = false (pre.off)")
local data = newProfile()
for n, item in Index.ByZone[1] do
	addItem(data, `z1-{n}`, item.Id, nil, 1, 500)
end
local ada = join("Ada", data)
advance(1.5)
check(#IndexService.GetCompletedZones(ada) == 1, "la zone 1 est complète dans l'index")
check(dataOf(ada).Cash == 1000 and dataOf(ada).IndexRewards == nil, "ni prime, ni IndexRewards")
check(math.abs(walk(ada) - 16) < 1e-3 and IndexService.GetSpeedMultiplier(ada) == 1, `ni vitesse ({walk(ada)})`)
check(#notifies(ada, "complete") == 0, "ni message")
check(IndexService.Claim(ada, nil) == 0 and dataOf(ada).Cash == 1000, "a117 : réclamation refusée, index fermé")
local tel = 0
for _, e in TELEMETRY do
	if e.kind == "IndexReward" then
		tel += 1
	end
end
check(tel == 0, "ni télémétrie")

summary("scénario rewardoff")
