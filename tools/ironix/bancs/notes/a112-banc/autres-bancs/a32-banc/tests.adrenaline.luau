--!nocheck
-- Scénario « adrenaline » (serveur, vrai StatsService : WalkSpeed appliqué) : +25 % de vitesse pour
-- la victime du début à la fin du vol (6.2). Deux victimes, cinq joueurs. Ada : un vol (dépôt), mort
-- de la victime pendant le vol, deux vols en même temps (pas de cumul, pas de retrait trop tôt,
-- réannonce de l'alerte), mort du dernier voleur. Dan : départ du voleur, puis départ de la victime
-- (rien n'est renvoyé, aucune erreur). Le voleur et les témoins n'ont jamais l'Adrénaline.

startServer()

local adaData = victimProfile()
local ada = join("Ada", adaData)
local bob = join("Bob", newProfile())
local cy = join("Cy", newProfile())
local danData = victimProfile()
local dan = join("Dan", danData)
local eve = join("Eve", newProfile())
startClient(ada)
advance(1.2)
local adaShop, danShop = shopOf(ada), shopOf(dan)

section("au repos")
check(near(walkSpeed(ada), 16) and near(walkSpeed(bob), 16), "tout le monde à 16 (formule 7.1, Vitesse 0)")

section("un vol : Adrénaline du début à la fin")
check(breakDoor(bob, adaShop), "porte d'Ada cassée par Bob")
check(near(walkSpeed(ada), 16), "porte cassée, rien de volé : pas encore d'Adrénaline")
check(steal(bob, adaShop, 1), "Bob prend la Canette de soda")
check(near(walkSpeed(ada), 20), `Ada : 16 × 1,25 = 20 (trouvé {walkSpeed(ada)})`)
check(near(walkSpeed(bob), 16), `Bob porte l'objet volé : vitesse fixe 16 (2026-11-13), pas d'Adrénaline pour le voleur (trouvé {walkSpeed(bob)})`)
check(near(walkSpeed(cy), 16) and near(walkSpeed(dan), 16), "les témoins restent à 16")
check(logHas("Ada : Adrénaline (vitesse × 1.25)", "PRINT", "server"), "sortie : Adrénaline posée")

section("mort de la victime pendant le vol")
kill(ada)
flush()
spawnCharacter(ada, refsOfShop(adaShop).center)
flush()
check(PvPService.IsThiefOf(bob, ada), "le vol continue")
check(near(walkSpeed(ada), 20), `Ada réapparue : l'Adrénaline reste jusqu'à la fin de la poursuite (trouvé {walkSpeed(ada)})`)

section("deux vols en même temps chez Ada")
check(steal(cy, adaShop, 2), "Cy prend aussi le Paquet de chips")
check(near(walkSpeed(ada), 20), `deux vols : un seul bonus, pas de cumul (20, pas 25 ; trouvé {walkSpeed(ada)})`)
local before = #theftAlerts(ada)
runHome(bob, adaShop)
check(PvPService.GetTheft(bob) == nil and PvPService.IsThiefOf(cy, ada), "Bob a déposé, Cy court encore")
check(near(walkSpeed(ada), 20), `un vol fini, l'autre pas : l'Adrénaline reste (trouvé {walkSpeed(ada)})`)
local list = theftAlerts(ada)
check(#list == before + 2, `dépôt de Bob : deux messages à Ada (trouvé {#list - before})`)
local off, again = list[before + 1], list[before + 2]
check(off and off.args[1] == false, "TheftAlert(false) de PvPService d'abord")
check(again and again.args[1] == true and again.args[2] == cy and again.args[3] == "Z1_PaquetDeChips", "puis la réannonce : TheftAlert(true, Cy, Z1_PaquetDeChips)")
check(logHas("Ada : 1 vol(s) encore en cours, alerte réannoncée", "PRINT", "server"), "sortie : réannonce")
check(adaData.Lifetime.Defenses == 0, "pas de défense comptée pour un dépôt")
before = #theftAlerts(ada)
kill(cy)
flush()
check(near(walkSpeed(ada), 16), `mort du dernier voleur : Adrénaline retirée (trouvé {walkSpeed(ada)})`)
list = theftAlerts(ada)
check(#list == before + 1 and list[#list].args[1] == false, "plus aucun vol : TheftAlert(false), rien de réannoncé")
check(logHas("Ada : fin de l'Adrénaline", "PRINT", "server"), "sortie : Adrénaline retirée")
spawnCharacter(cy, SHOPS[3].S.center)
advance(0.3)

section("départ du voleur")
check(breakDoor(eve, danShop), "porte de Dan cassée par Eve")
check(steal(eve, danShop, 1), "Eve prend la Canette de soda de Dan")
check(near(walkSpeed(dan), 20), "Dan : Adrénaline")
walkTo(eve, refsOfShop(danShop).outside)
leave(eve)
flush()
check(near(walkSpeed(dan), 16), `Eve quitte le jeu : le vol échoue, Adrénaline retirée (trouvé {walkSpeed(dan)})`)
check(danData.Display["1"] == "v-soda", "l'objet est revenu sur son présentoir")

section("départ de la victime")
check(steal(cy, danShop, 2), "porte encore cassée : Cy prend le Paquet de chips de Dan")
check(near(walkSpeed(dan), 20), "Dan : Adrénaline de nouveau")
before = #theftAlerts(dan)
clearLog()
leave(dan)
flush()
check(not CarryService.IsCarrying(cy) and PvPService.GetTheft(cy) == nil, "Dan part : le vol de Cy échoue (VictimLeft)")
check(#theftAlerts(dan) == before, "rien n'est envoyé à une victime qui part")
check(not logHas("[TheftAlertService]", "WARN") and not logHas("[StatsService]", "WARN"), "aucune erreur au départ de la victime")
check(near(walkSpeed(cy), 16), "Cy n'a plus de malus de portage, et jamais l'Adrénaline")

section("bilan")
check(near(walkSpeed(ada), 16) and near(walkSpeed(bob), 16), "plus personne n'a l'Adrénaline")
check(not logHas("mal formé", "WARN"), "aucun envoi de remote mal formé (Net, en Studio)")
check(not logHas("tick :", "WARN"), "aucune erreur dans les boucles des services")
check(not logHas("hors de StatsService", "WARN"), "WalkSpeed jamais écrit hors de StatsService")

if VERBOSE then
	dumpLog()
end
summary("scénario adrenaline")
