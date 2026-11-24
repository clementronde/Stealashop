--!nocheck
-- Scénario « funnel » : le funnel d'onboarding de TutorialService (DEV-046, 14.2), laissé où il est,
-- passe par le même faux AnalyticsService : seulement pour un nouveau joueur, une fois par étape, des
-- noms acceptés par Roblox. Les gains et dépenses du même joueur partent en économie à côté.

startServer()

local kim = join("Kim", tutorialProfile())
local kimData = DataService.Get(kim)
local ada = join("Ada", richProfile())
advance(1)

local function steps(player)
	local out = {}
	for _, e in funnelOf(player) do
		out[e.step] = (out[e.step] or 0) + 1
	end
	return out
end

section("arrivée d'un nouveau joueur")
local list = funnelOf(kim)
check(#list == 1 and list[1].step == 1, `étape 1 envoyée à l'arrivée sur sa parcelle (trouvé {#list} étape(s))`)
check(list[1] and list[1].name == Tutorial.FunnelSteps[1], `nom : « {Tutorial.FunnelSteps[1]} »`)
check(#funnelOf(ada) == 0, "ancien joueur : aucun funnel")

section("objet exposé, premier encaissement, premier outil")
kimData.Items["k-phone"] = { Id = "Z3_Smartphone", Source = "NPC", At = 0, Zone = 3 }
kimData.Display["1"] = "k-phone"
advance(3)
check(steps(kim)[8] == 1, `étape 8 « {Tutorial.FunnelSteps[8]} »`)
local got = cashOut(kim)
check(got >= 300, `Kim encaisse {got} $`)
advance(1)
check(steps(kim)[9] == 1, `étape 9 « {Tutorial.FunnelSteps[9]} »`)
goWeaponShop(kim)
buy(kim, "Wrench")
check(table.find(kimData.Tools.Owned, "Wrench") ~= nil, "Kim achète la Clé à molette")
advance(1)
check(steps(kim)[10] == 1, `étape 10 « {Tutorial.FunnelSteps[10]} »`)
local economy = economyOf(kim)
check(#economy == 2 and economy[1].sku == "Income" and economy[1].amount == got and economy[2].sku == "Wrench", "économie : le cumul de son encaissement, puis l'achat")

section("une seule fois par étape")
goHome(kim)
advance(1)
cashOut(kim)
goWeaponShop(kim)
buy(kim, "Crowbar")
advance(3)
local counts = steps(kim)
local once = true
for step, count in counts do
	if count ~= 1 then
		once = false
		check(false, `étape {step} envoyée {count} fois`)
	end
end
check(once, "chaque étape envoyée une seule fois")

section("noms du funnel")
for _, e in ANALYTICS.funnel do
	check(e.name == Tutorial.FunnelSteps[e.step] and analyticsSafe(e.name), `étape {e.step} : « {e.name} », sans virgule, guillemet ni apostrophe`)
end
check(noRefusal(), "aucun envoi refusé par le faux AnalyticsService")
check(not logHas("ERREUR"), "aucune erreur dans les tâches")
summary("scénario funnel")
