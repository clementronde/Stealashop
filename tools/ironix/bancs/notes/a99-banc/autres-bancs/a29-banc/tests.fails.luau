--!nocheck
-- Scénario « fails » : chaque échec du vol (6.1, point 6) rend l'objet à son présentoir d'origine,
-- sans doublon ni perte : coup de batte (CarryService.Fail(voleur, "Bat"), appelé par a30), mort du
-- voleur, départ du voleur, départ de la victime, anomalie anti-triche.

startServer()

local adaData = newProfile()
addItem(adaData, "ada-soda", "Z1_CanetteDeSoda", 1)
addItem(adaData, "ada-chips", "Z1_PaquetDeChips", 2)
addItem(adaData, "ada-donut", "Z1_Donut", 4)
addItem(adaData, "ada-noodles", "Z1_PotDeNouilles", 3) -- le meilleur : à l'abri
local ada = join("Ada", adaData)
local bobData = newProfile()
local bob = join("Bob", bobData)
local cy = join("Cy", newProfile())
advance(1.2)
local adaShop = shopOf(ada)
local TOTAL = 4

-- Le présentoir `slot` d'Ada montre-t-il de nouveau son objet, qui rapporte ?
local function backOnStand(slot, uid, label)
	local model = displayModel(adaShop, slot)
	check(adaData.Display[tostring(slot)] == uid and adaData.Items[uid] ~= nil, `{label} : l'objet est toujours dans le profil d'Ada, présentoir {slot}`)
	check(model ~= nil and model:GetAttribute("ItemUid") == uid, `{label} : il est revenu sur son présentoir d'origine`)
	check(ada:GetAttribute("Income") == 8, `{label} : il rapporte de nouveau (8 $/s ; trouvé {ada:GetAttribute("Income")})`)
end
local function cleanThief(thief, label)
	check(not CarryService.IsCarrying(thief), `{label} : le voleur ne porte plus rien`)
	check(PvPService.GetTheft(thief) == nil, `{label} : plus de vol en cours`)
	check(SPEED_MODIFIERS[thief] == nil or SPEED_MODIFIERS[thief].Carry == nil, `{label} : malus de vitesse retiré`)
end
local function lastAlertOff(victim)
	local list = theftAlerts(victim)
	return #list >= 2 and list[#list].args[1] == false
end

section("coup de batte (CarryService.Fail(voleur, \"Bat\"), a30)")
check(breakDoor(bob, adaShop), "porte d'Ada cassée")
check(steal(bob, adaShop, 1), "Bob prend la Canette de soda")
check(ada:GetAttribute("Income") == 7, "pendant la fuite : 7 $/s chez Ada")
check(PvPService.IsThiefOf(bob, ada) and not PvPService.IsThiefOf(bob, cy), "IsThiefOf : Bob vole Ada (pour la batte d'a30)")
local info = PvPService.GetTheft(bob)
check(info and info.Victim == ada and info.ItemUid == "ada-soda" and info.SlotIndex == 1, "GetTheft : victime, uid et présentoir")
walkTo(bob, SHOPS[1].S.outside)
CarryService.Fail(bob, "Bat")
flush()
cleanThief(bob, "batte")
backOnStand(1, "ada-soda", "batte")
check(lastAlertOff(ada), "batte : TheftAlert(false) à Ada")
check(#notifies(ada, "Your Soda Can is back on its stand!") == 1, "batte : Notify à Ada, objet revenu")
check(#notifies(bob, "The Soda Can went back to its owner.") == 1, "batte : Notify au voleur, objet rendu")
check(adaShop:GetAttribute("Protection") == nil and PvPService.GetProtection == nil, "batte : plus aucune protection (a99 : GetProtection retiré)")
check(bobData.Lifetime.Steals == 0, "batte : aucun vol compté")
invariants("batte", TOTAL)

section("mort du voleur")
check(steal(bob, adaShop, 2), "toujours dans les 10 s : Bob prend le Paquet de chips")
kill(bob)
flush()
cleanThief(bob, "mort")
backOnStand(2, "ada-chips", "mort")
check(lastAlertOff(ada), "mort : TheftAlert(false) à Ada")
invariants("mort", TOTAL)
spawnCharacter(bob, SHOPS[2].S.center)
advance(0.3)
-- a99 (Cantin, 2026-11-12) : mort dans la boutique d'Ada, Bob ne peut plus la voler pendant 60 s.
check(PvPService.GetRobCooldown(bob, adaShop) > 55, `mort dans la boutique d'Ada : interdit de la voler (reste {PvPService.GetRobCooldown(bob, adaShop)} s)`)
check(#notifies(bob, "Eliminated! You can rob this shop again in 60s.") == 1, "mort : Notify Eliminated")
advance(60.5, 0.5)
check(PvPService.GetRobCooldown(bob, adaShop) == 0, "60 s plus tard : interdiction finie")

section("départ du voleur")
WindowService.Rebuild(windowIdOf(adaShop))
advance(0.2)
check(breakDoor(bob, adaShop), "porte d'Ada recassée")
check(steal(bob, adaShop, 4), "Bob prend le Donut")
walkTo(bob, SHOPS[1].S.outside)
leave(bob)
flush()
backOnStand(4, "ada-donut", "départ du voleur")
check(lastAlertOff(ada), "départ du voleur : TheftAlert(false) à Ada")
check(STORE[bob.UserId] and next(STORE[bob.UserId].Items) == nil, "départ du voleur : son profil sauvegardé n'a pas l'objet")
check(#notifies(bob, "The Donut went back to its owner.") == 0, "départ du voleur : pas de message envoyé à un joueur parti")
invariants("départ du voleur", TOTAL)

section("départ de la victime")
local danData = newProfile()
local dan = join("Dan", danData)
advance(0.5)
check(shopOf(dan) == SHOPS[2].model, "Dan reçoit la boutique libérée par Bob")
check(steal(dan, adaShop, 1), "la porte est encore cassée et la fenêtre ouverte : Dan prend la Canette")
walkTo(dan, SHOPS[1].S.outside)
walkTo(dan, HUB_CENTER)
local adaId = ada.UserId
leave(ada)
flush()
cleanThief(dan, "départ de la victime")
check(STORE[adaId].Items["ada-soda"] ~= nil and STORE[adaId].Display["1"] == "ada-soda", "départ de la victime : sa sauvegarde garde l'objet, sur son présentoir")
check(next(danData.Items) == nil, "départ de la victime : rien chez le voleur")
check(#notifies(dan, "The Soda Can went back to its owner.") == 1, "départ de la victime : Notify au voleur")
check(shopOf(ada) == nil and SHOPS[1].model:GetAttribute("OwnerUserId") == 0, "la boutique d'Ada est libérée")
check(not WindowService.IsBroken(windowIdOf(SHOPS[1].model)), "sa porte est refaite (parcelle libre)")
check(SHOPS[1].model:GetAttribute("StealOpen") == nil, "fenêtre de vol fermée")
invariants("départ de la victime", TOTAL)

section("retour de la victime sur le serveur")
local saved = STORE[adaId]
STORE[adaId] = nil -- la sauvegarde passe à la nouvelle session
local ada2 = join("Ada2", DataService.deepCopy(saved))
advance(1.2)
check(shopOf(ada2) == SHOPS[1].model, "la sauvegarde d'Ada revient avec ses 4 objets")
check(ada2:GetAttribute("Income") == 8, `ses 4 objets rapportent (8 $/s ; trouvé {ada2:GetAttribute("Income")})`)

section("anomalie anti-triche (ReportAnomaly)")
check(breakDoor(dan, SHOPS[1].model), "Dan casse la porte")
check(steal(dan, SHOPS[1].model, 2), "Dan prend le Paquet de chips")
CarryService.ReportAnomaly(dan, "test du banc")
flush()
cleanThief(dan, "anomalie")
check(STORE[ada2.UserId].Display["2"] == "ada-chips" and displayModel(SHOPS[1].model, 2) ~= nil, "anomalie : l'objet revient sur son présentoir")
invariants("anomalie", TOTAL)

section("téléport jusqu'au dépôt (contrôle du dépôt, V0)")
check(steal(dan, SHOPS[1].model, 4), "Dan prend le Donut")
moveTo(dan, SHOPS[2].S.center) -- d'un coup jusque chez lui
advance(0.3)
cleanThief(dan, "téléport")
check(logHas("anomalie anti-triche de Dan (objet volé déposé à", "WARN", "server"), "téléport : anomalie écrite dans la sortie")
check(next(danData.Items) == nil and STORE[ada2.UserId].Items["ada-donut"] ~= nil, "téléport : rien n'est transféré")
check(displayModel(SHOPS[1].model, 4) ~= nil, "téléport : l'objet revient sur son présentoir")
invariants("téléport", TOTAL)

section("sortie")
check(not logHas("mal formé", "WARN"), "aucun envoi de remote mal formé (Net, en Studio)")
check(not logHas("tick :", "WARN"), "aucune erreur dans les boucles des services")
if VERBOSE then
	dumpLog()
end
summary("scénario fails")
