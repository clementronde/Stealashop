--!nocheck
-- Scénario « reveal » (a294, serveur) : jeu DEV (caisse allumée), une zone safe taggée SafeZone autour du hub. Après le
-- don d'un lot, RevealStarted à tous pour l'objet exclusif tiré : ShopId ExclusiveCrate, SlotName Crate, rareté de
-- l'objet, plan de Shared/UnboxPlan tiré par le serveur (coups = Unbox.New.ActionsByRarity de la rareté, colis montré
-- Épique, cote finale = Formulas.UnboxOdds(chance)) ; acheteur protégé et immobilisé jusqu'à son RevealDone (pas celui
-- d'un autre), ou au plafond du plan, ou à sa mort, ou à son départ ; un lot joue l'objet le plus rare ; hors zone
-- safe : objets donnés, pas d'ouverture. Net limite RevealDone à 2 par seconde : le banc attend entre deux envois.
SET_ENVIRONMENT("Dev")
local zone = make("Part", { Name = "SafeZone_Banc", Anchored = true, CanCollide = false, Size = Vector3.new(800, 200, 800), CFrame = CFrame.new(0, 50, 0) }, MAP)
CollectionService:AddTag(zone, "SafeZone")
startServer()
local Crate = Monetization.Crate
local Plan = sharedModule("UnboxPlan")
local Unbox = sharedModule("Config/Unbox")
local SafeZone = sharedModule("SafeZone")
local ACTIONS = Unbox.New.ActionsByRarity
local EXPECTED_ODDS = { 3, 3, 4, 10, 25, 100 }

local ada = join("Ada", newProfile())
local bob = join("Bob", newProfile())
advance(1.5)
local function humanoidOf(player)
	return player.Character and player.Character:FindFirstChildOfClass("Humanoid")
end
local function started()
	return remotes("RevealStarted")
end
local function ended(id)
	return remotes("RevealEnded", function(e)
		return e.args[1] == id
	end)
end
local function held(player)
	return player:GetAttribute("RevealProtected") == true
end
local function exclusivesOf(player)
	local list = {}
	for _, entry in dataOf(player).Items do
		if string.find(entry.Id, "^Exclusive_") then
			table.insert(list, entry.Id)
		end
	end
	return list
end
local function chanceOf(itemId)
	local index = table.find(Crate.Items, itemId)
	return index, if index then Crate.Odds[index] else nil
end
-- Vérifie un RevealStarted de la caisse (e) pour `player` et l'objet `itemId` ; rend son id.
local function checkStart(e, player, itemId, label)
	local a = e.args
	local def = Items.ById[itemId]
	local index = chanceOf(itemId)
	check(a[1] == player and a[2] == Crate.Reveal.ShopId and a[3] == Crate.Reveal.SlotName, `{label} : ouvreur {player.Name}, ShopId {a[2]}, SlotName {a[3]}`)
	check(a[4] == itemId and a[5] == def.Rarity and a[6] == "" and a[9] == "Small", `{label} : objet {a[4]} ({a[5]}), sans mutation, Small`)
	check(type(a[7]) == "number" and a[7] > 0 and type(a[8]) == "number" and a[8] > 0, `{label} : poids {a[7]} et échelle {a[8]}`)
	local plan = Plan.parse(a[11])
	check(plan ~= nil, `{label} : plan lisible ({a[11]})`)
	if plan then
		check(#plan.Steps == ACTIONS[def.Rarity], `{label} : {#plan.Steps} coups pour un {def.Rarity} (attendu {ACTIONS[def.Rarity]})`)
		check(plan.Odds == EXPECTED_ODDS[index], `{label} : cote finale 1 IN {plan.Odds} (attendu {EXPECTED_ODDS[index]})`)
		local allEpic = true
		for _, step in plan.Steps do
			allEpic = allEpic and step.Rarity == Crate.Reveal.StartRarity
		end
		check(allEpic and plan.Steps[#plan.Steps].Action.Id == Unbox.New.FinalAction, `{label} : colis montré {Crate.Reveal.StartRarity}, dernier coup {Unbox.New.FinalAction}`)
	end
	return a[10]
end

section("R1 x1 dans la zone safe : l'ouverture se joue")
check(SafeZone.ContainsPlayer(ada), "Ada dans la zone safe")
local speed = humanoidOf(ada).WalkSpeed
check(speed > 0, `Ada marche ({speed})`)
check(settle(receipt(ada, 8401, "RV-1")) == GRANTED, "x1 : PurchaseGranted")
advance(0.2)
local got = exclusivesOf(ada)
check(#got == 1 and #started() == 1, `un objet, une ouverture ({#got}, {#started()})`)
local id1 = started()[1] and checkStart(started()[1], ada, got[1], "R1")
check(type(id1) == "string" and string.find(id1, "^Crate") ~= nil, `id de la cinématique : {id1}`)
check(held(ada) and humanoidOf(ada).WalkSpeed == 0, `Ada protégée (RevealProtected) et immobilisée ({humanoidOf(ada).WalkSpeed})`)
check(not held(bob), "Bob pas touché")
fireAs(bob, "RevealDone", id1)
advance(0.1)
check(held(ada) and #ended(id1) == 0, "RevealDone de Bob : ignoré")
fireAs(ada, "RevealDone", "Crate999")
fireAs(ada, "RevealDone", 42)
advance(0.1)
check(held(ada) and #ended(id1) == 0, "RevealDone d'un id inconnu ou illisible : ignoré")
advance(1.1) -- Net : RevealDone 2 fois par seconde au plus (Definitions.RatePerSecond)
fireAs(ada, "RevealDone", id1)
advance(0.1)
check(#ended(id1) == 1, "RevealDone d'Ada : RevealEnded à tous")
check(not held(ada) and humanoidOf(ada).WalkSpeed == speed, `Ada libérée, vitesse rendue ({humanoidOf(ada).WalkSpeed})`)
fireAs(ada, "RevealDone", id1)
advance(0.1)
check(#ended(id1) == 1, "RevealDone rejoué : rien de plus")

section("R2 chaque objet exclusif : coups et cote selon sa rareté")
for index, itemId in Crate.Items do
	clearLog()
	local before = #started()
	local why = MonetizationService.BancStartCrateReveal(ada, { itemId })
	local list = started()
	check(why == nil and #list == before + 1, `{itemId} : ouverture lancée ({why})`)
	local e = list[#list]
	if e and why == nil then
		advance(1.1) -- Net : 2 RevealDone par seconde au plus
		local id = checkStart(e, ada, itemId, `R2.{index}`)
		fireAs(ada, "RevealDone", id)
		advance(0.1)
		check(#ended(id) == 1 and not held(ada), `{itemId} : finie au RevealDone`)
	end
end

section("R3 lot de 10 : l'objet le plus rare est joué")
local before = #exclusivesOf(bob)
check(settle(receipt(bob, 8403, "RV-10")) == GRANTED, "x10 : PurchaseGranted")
advance(0.2)
local items10 = exclusivesOf(bob)
check(#items10 == before + 10, "10 objets donnés")
local best = -1
for _, itemId in items10 do
	best = math.max(best, Rarities.ById[Items.ById[itemId].Rarity].Order)
end
local e10 = started()[#started()]
check(e10 ~= nil and e10.args[1] == bob, "une ouverture pour Bob")
local id10 = e10 and e10.args[10]
check(e10 ~= nil and Rarities.ById[e10.args[5]].Order == best and table.find(items10, e10.args[4]) ~= nil, `objet joué : {e10 and e10.args[4]} ({e10 and e10.args[5]}), le plus rare du lot`)

section("R4 plafond du plan sans RevealDone")
local parsed = e10 and Plan.parse(e10.args[11])
local limit = parsed and Plan.serverMaxSeconds(e10.args[5], "Small", #parsed.Steps) or 60
advance(limit - 1)
check(held(bob) and #ended(id10) == 0, string.format("encore en cours 1 s avant le plafond (%.1f s)", limit))
advance(1.5)
check(not held(bob) and #ended(id10) == 1 and logHas("plafond de temps"), "au plafond : RevealEnded, Bob libéré")

section("R5 mort et départ pendant l'ouverture")
MonetizationService.BancStartCrateReveal(bob, { Crate.Items[3] })
local idDeath = started()[#started()].args[10]
humanoidOf(bob).Died:Fire()
advance(0.1)
check(#ended(idDeath) == 1 and not held(bob), "mort : RevealEnded, Bob libéré")
MonetizationService.BancStartCrateReveal(bob, { Crate.Items[4] })
local idLeave = started()[#started()].args[10]
leave(bob)
check(#ended(idLeave) == 1, "départ : RevealEnded pour les autres")

section("R6 hors zone safe : donné, pas d'ouverture")
moveTo(ada, Vector3.new(5000, 3, 5000))
advance(0.2)
check(not SafeZone.ContainsPlayer(ada), "Ada hors de la zone safe")
local count = #started()
local owned = #exclusivesOf(ada)
clearLog()
check(settle(receipt(ada, 8402, "RV-OUT")) == GRANTED, "x3 : PurchaseGranted")
advance(0.2)
check(#exclusivesOf(ada) == owned + 3, "3 objets donnés")
check(#started() == count and not held(ada), "aucune ouverture, Ada libre")
check(logHas("caisse sans ouverture (hors zone safe)"), "la sortie dit pourquoi")
summary("scénario reveal")
