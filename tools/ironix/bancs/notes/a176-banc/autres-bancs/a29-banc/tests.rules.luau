--!nocheck
-- Copie d'a99 (2026-11-12, décision de Cantin) : règles 1, 3 et 4 retournées : plus de bouclier débutant
-- sur la boutique, plus d'immunité après un vol subi, plus d'anti-racket ; tout le monde vole tout le monde.
-- Scénario « rules » : les 7 règles anti-frustration de la section 6.4, une par une.
--   1. bouclier débutant ; 2. pas d'acharnement (3 s, a30 : rien ici) ; 3. immunité de 120 s après un
--   vol subi ; 4. pas de racket ; 5. coffre-fort ; 6. l'argent n'est jamais volé ; 7. transfert sûr.

startServer()

local adaData = newProfile()
addItem(adaData, "ada-soda", "Z1_CanetteDeSoda", 1)
addItem(adaData, "ada-chips", "Z1_PaquetDeChips", 2)
addItem(adaData, "ada-noodles", "Z1_PotDeNouilles", 3) -- Rare : le meilleur
addItem(adaData, "ada-donut", "Z1_Donut", 4)
local ada = join("Ada", adaData)
local bobData = newProfile()
local bob = join("Bob", bobData)
local cyData = newProfile()
local cy = join("Cy", cyData)
startClient(bob)
advance(1.2)
local adaShop, bobShop = shopOf(ada), shopOf(bob)
local adaDoor = windowIdOf(adaShop)
local TOTAL = 4

-- PV de la porte d'Ada (sans attendre la régénération).
local function doorFull()
	return not WindowService.IsBroken(adaDoor) and adaShop:FindFirstChild("Window", true):GetAttribute("MaxHP") == 500
end
-- Route courte de la boutique d'Ada à celle de Bob (devant les portes, à `speed` studs/s).
local function fastHome(thief, speed)
	local V, H = SHOPS[1].S, refsOfShop(shopOf(thief))
	walkTo(thief, Vector3.new(V.door.X, 3, V.door.Z) + V.front * 1, speed)
	walkTo(thief, V.outside, speed)
	walkTo(thief, H.outside, speed)
	walkTo(thief, Vector3.new(H.door.X, 3, H.door.Z) - H.front * 3, speed)
	walkTo(thief, H.center, speed)
	advance(0.2)
end

section("règle 1 (a99) : plus de bouclier débutant sur la boutique")
SHIELDED[ada] = true
advance(0.6)
check(adaShop:GetAttribute("Protection") == nil, "a99 : pas d'attribut Protection sur la boutique d'Ada (débutante)")
moveTo(bob, SHOPS[1].S.outside + Vector3.new(0, 0, -6))
advance(0.5)
local panel = PvPController.GetPanelText(adaShop)
check(panel and panel.Status == nil, `a99 : panneau sans statut, porte intacte (trouvé {panel and panel.Status})`)
check(breakDoor(bob, adaShop), "a99 : Bob casse la porte d'une débutante")
check(#notifies(bob, "This shop is protected") == 0, "a99 : aucun message de protection")
check(steal(bob, adaShop, 1), "a99 : Bob prend chez une débutante")
CarryService.Fail(bob, "Bat")
flush()
check(adaData.Display["1"] == "ada-soda", "vol raté : l'objet revient à Ada")
SHIELD_ERROR = true
check(steal(cy, adaShop, 1), "a99 : IsShielded en panne ne protège plus rien")
CarryService.Fail(cy, "Bat")
flush()
SHIELD_ERROR = nil
SHIELDED[ada] = false
WindowService.Rebuild(adaDoor)
advance(0.3)

section("règle 2 : pas d'acharnement (3 s d'immunité aux coups de batte)")
-- Écrite par a30 (BatService) : PvPService lui donne IsThiefOf et GetTheft, rien d'autre à tester ici.
check(type(PvPService.IsThiefOf) == "function" and type(PvPService.GetTheft) == "function", "accroches pour la batte : IsThiefOf, GetTheft")

section("règle 3 (a99) : plus d'immunité après un vol subi")
check(breakDoor(bob, adaShop), "Bob casse la porte d'Ada")
moveTo(cy, SHOPS[1].S.center) -- Cy attend dans la boutique cassée
check(steal(bob, adaShop, 1), "Bob prend la Canette de soda")
fastHome(bob, 16) -- a146 : vitesse fixe du voleur (16), plus 40
check(bobData.Items["ada-soda"] ~= nil, "vol réussi : la Canette est à Bob")
check(adaShop:GetAttribute("StealOpen") == true, "la fenêtre de vol est encore ouverte")
check(adaShop:GetAttribute("Protection") == nil and adaShop:GetAttribute("ProtectedUntil") == nil, "a99 : ni Protection ni ProtectedUntil après le vol")
check(steal(cy, adaShop, 2), "a99 : Cy prend aussitôt le Paquet de chips")
check(#notifies(cy, "This shop was just robbed") == 0, "a99 : aucun message d'immunité")
CarryService.Fail(cy, "Bat")
flush()
check(adaData.Display["2"] == "ada-chips", "vol raté de Cy : le Paquet de chips revient à Ada")
moveTo(cy, SHOPS[3].S.center)
advance(25) -- la porte se reconstruit (30 s après la casse)
check(not WindowService.IsBroken(adaDoor), "porte d'Ada refaite")
local alarm = #notifies(ada, "smashed your shop door")
check(breakDoor(cy, adaShop), "a99 : la porte se casse de nouveau tout de suite")
check(#notifies(ada, "smashed your shop door") == alarm + 1, "alarme de base de nouveau")
WindowService.Rebuild(adaDoor)
advance(0.3)
invariants("immunité", TOTAL)

section("règle 4 (a99) : plus d'anti-racket")
local rich = newProfile()
addItem(rich, "dan-robot", "Z2_RobotJouet", 1) -- Épique de la zone 2 : 120 $/s
leave(cy)
local dan = join("Dan", rich)
advance(1.2)
check(dan:GetAttribute("Income") == 120 and ada:GetAttribute("Income") == 7, `revenus : Dan 120 $/s, Ada 7 $/s (trouvé {dan:GetAttribute("Income")} et {ada:GetAttribute("Income")})`)
check(breakDoor(dan, adaShop), "a99 : Dan (120 $/s) casse la porte d'Ada (7 $/s)")
check(#notifies(dan, "too small") == 0, "a99 : aucun message « too small »")
check(steal(dan, adaShop, 2), "a99 : Dan prend chez Ada")
CarryService.Fail(dan, "Bat")
flush()
-- Bob devient riche : la boutique d'Ada reste volable, vue de son client.
bobData.Items["bob-plush"] = { Id = "Z2_PelucheGeante", Source = "NPC", At = 0, Zone = 2 }
DisplayService.PlaceAuto(bob, "bob-plush")
advance(0.6)
moveTo(bob, SHOPS[1].S.outside + Vector3.new(0, 0, -6))
advance(0.5)
local panel4 = PvPController.GetPanelText(adaShop)
check(panel4 and panel4.Status ~= "TOO SMALL TO ROB" and string.find(panel4.Status or "", "OPEN", 1, true) == 1, `a99 : panneau de Bob « OPEN » (trouvé {panel4 and panel4.Status})`)
standBy(bob, adaShop, 2)
advance(0.5)
local prompt = PvPController.GetPrompt(displayModel(adaShop, 2))
check(prompt ~= nil and prompt.Enabled, "a99 : invite active pour le riche")
for key, uid in table.clone(bobData.Display) do
	if uid == "bob-plush" then
		bobData.Display[key] = nil
	end
end
bobData.Items["bob-plush"] = nil
advance(1.2)
WindowService.Rebuild(adaDoor)
advance(0.3)
invariants("racket", 5) -- 4 objets du départ + le robot de Dan

section("règle 5 (copie a176) : plus de coffre-fort, le plus rentable se vole")
check(adaShop:GetAttribute("SafeSlots") == nil, "aucun SafeSlots sur la boutique d'Ada")
check(breakDoor(bob, adaShop), "porte cassée")
standBy(bob, adaShop, 3)
advance(0.5)
local safePrompt = PvPController.GetPrompt(displayModel(adaShop, 3))
check(safePrompt and safePrompt.Enabled, "invite active sur le Pot de nouilles")
check(bob.PlayerGui:FindFirstChild("SafeTag") == nil, "aucune étiquette SAFE")
check(steal(bob, adaShop, 3), "le Pot de nouilles (le plus rentable) se vole")
check(#notifies(bob, "This item is in the safe: nobody can steal it.") == 0, "aucun refus « Safe »")
CarryService.Fail(bob, "Bat")
flush()
check(adaData.Display["3"] == "ada-noodles", "vol raté : il revient sur son présentoir")
-- Un colis d'un établi n'est jamais sur un présentoir : rien à prendre là où il n'y a pas d'objet.
adaData.Boxes["1"] = { Tier = "Standard", Zone = 1, ItemId = "Z1_Donut", Rarity = "Common", ReadyAt = 0 }
check(not steal(bob, adaShop, 5), "présentoir 5 (verrouillé, vide) : rien à prendre ; les colis des établis non plus")
-- Un objet rangé dans le champ Vault du profil n'est plus exposé, donc jamais volable.
adaData.Vault["1"] = "ada-donut"
advance(1.2)
check(adaData.Display["4"] == nil and displayModel(adaShop, 4) == nil, "objet du champ Vault : retiré du présentoir par DisplayService")
check(not steal(bob, adaShop, 4), "objet du champ Vault : rien à voler")
adaData.Vault["1"] = nil
adaData.Display["4"] = "ada-donut"
adaData.Boxes["1"] = nil
advance(1.2)
-- Un seul objet exposé : il est à l'abri, la boutique est intouchable.
WindowService.Rebuild(adaDoor)
advance(0.3)
local eveData = newProfile()
addItem(eveData, "eve-soda", "Z1_CanetteDeSoda", 2)
leave(dan)
local eve = join("Eve", eveData)
advance(1.2)
local eveShop = shopOf(eve)
check(eveShop == SHOPS[3].model, "Eve reçoit la boutique 3 (tournée de 90°)")
check(eveShop:GetAttribute("SafeSlots") == nil, "(copie a176) Eve n'expose qu'un objet : pas d'abri")
check(breakDoor(bob, eveShop), "porte d'Eve cassée")
check(steal(bob, eveShop, 2), "(copie a176) Eve, un seul objet : il se vole")
CarryService.Fail(bob, "Bat")
flush()
-- À revenu égal, le plus petit numéro de présentoir est à l'abri.
addItem(eveData, "eve-chips", "Z1_PaquetDeChips", 3)
advance(1.2)
check(eveShop:GetAttribute("SafeSlots") == nil, "(copie a176) deux Communs : aucun à l'abri")
WindowService.Rebuild(windowIdOf(eveShop))
advance(0.3)
invariants("coffre-fort", 7) -- + 2 objets d'Eve

section("règle 6 : l'argent n'est jamais volé")
advance(5)
local adaCash, bobCash = adaData.Cash, bobData.Cash
local registerBefore = DisplayService.GetRegister(ada)
check(registerBefore > 0, `la caisse d'Ada s'est remplie ({registerBefore} $)`)
check(breakDoor(bob, adaShop), "porte cassée")
check(steal(bob, adaShop, 4), "Bob prend le Donut")
fastHome(bob, 16) -- a146 : vitesse fixe du voleur (16), plus 40
check(bobData.Items["ada-donut"] ~= nil, "vol réussi")
check(adaData.Cash == adaCash and bobData.Cash == bobCash, "Cash d'Ada et de Bob inchangés par le vol")
check(DisplayService.GetRegister(ada) >= registerBefore, `caisse d'Ada jamais vidée par le vol ({registerBefore} → {DisplayService.GetRegister(ada)} $)`)
invariants("argent", 7)
advance(125, 0.5) -- fin de l'immunité d'Ada

section("règle 7 : transfert sûr (les deux connectés, profils chargés)")
-- a) Profil de la victime fermé (session reprise ailleurs) avant le dépôt : le voleur garde l'objet,
--    rien n'est transféré tant que le profil n'est pas actif.
check(breakDoor(bob, adaShop), "porte cassée")
check(steal(bob, adaShop, 2), "Bob prend le Paquet de chips")
local realGet = DataService.Get
DataService.Get = function(player)
	if player == ada then
		return nil
	end
	return realGet(player)
end
fastHome(bob, 16) -- a146 : vitesse fixe du voleur (16), plus 40
check(CarryService.IsCarrying(bob), "a) profil de la victime fermé : pas de dépôt, le voleur porte toujours")
check(bobData.Items["ada-chips"] == nil and adaData.Items["ada-chips"] ~= nil, "a) rien n'est transféré")
DataService.Get = realGet
advance(0.3)
check(bobData.Items["ada-chips"] ~= nil and adaData.Items["ada-chips"] == nil and not CarryService.IsCarrying(bob), "a) profil de nouveau actif : dépôt au tick suivant")
invariants("transfert a", 7)
advance(125, 0.5)

-- b) La victime part dans la même image où le voleur entre dans sa DepositZone, avant le tick : le vol
--    est annulé, l'objet reste chez elle (sa sauvegarde l'a), le voleur n'a rien.
addItem(adaData, "ada-milk", "Z1_BriqueDeLait", 1)
addItem(adaData, "ada-corn", "Z1_EpiDeMais", 2)
advance(1.2)
check(breakDoor(bob, adaShop), "porte cassée")
check(steal(bob, adaShop, 1), "Bob prend la Brique de lait")
local B = refsOfShop(bobShop)
walkTo(bob, SHOPS[1].S.outside, 16) -- a146 : vitesse fixe du voleur
walkTo(bob, B.outside, 16) -- a146 : vitesse fixe du voleur
walkTo(bob, Vector3.new(B.door.X, 3, B.door.Z) + B.front * 1, 16) -- a146 : vitesse fixe du voleur
moveTo(bob, Vector3.new(B.door.X, 3, B.door.Z) - B.front * 3) -- dans sa DepositZone…
local adaId = ada.UserId
leave(ada) -- … et la victime part avant le tick du serveur
advance(0.3)
check(not CarryService.IsCarrying(bob) and bobData.Items["ada-milk"] == nil, "b) départ de la victime avant le dépôt : rien chez le voleur")
check(STORE[adaId].Items["ada-milk"] ~= nil and STORE[adaId].Display["1"] == "ada-milk", "b) la sauvegarde de la victime garde l'objet, sur son présentoir")
invariants("transfert b", 9)

-- c) Le voleur part juste après le dépôt : l'objet est déjà à lui, sa sauvegarde l'a ; la victime
--    ne l'a plus.
check(breakDoor(bob, eveShop), "porte d'Eve cassée")
check(steal(bob, eveShop, 3), "Bob prend le Paquet de chips d'Eve")
local E = SHOPS[3].S
walkTo(bob, Vector3.new(E.door.X, 3, E.door.Z) + E.front * 1, 16) -- a146 : vitesse fixe du voleur
walkTo(bob, E.outside, 16) -- a146 : vitesse fixe du voleur
walkTo(bob, HUB_CENTER, 16) -- a146 : vitesse fixe du voleur
walkTo(bob, B.outside, 16) -- a146 : vitesse fixe du voleur
walkTo(bob, Vector3.new(B.door.X, 3, B.door.Z) + B.front * 1, 16) -- a146 : vitesse fixe du voleur
moveTo(bob, Vector3.new(B.door.X, 3, B.door.Z) - B.front * 3)
local waited = 0
while bobData.Items["eve-chips"] == nil and waited < 1 do
	advance(1 / 30)
	waited += 1 / 30
end
check(bobData.Items["eve-chips"] ~= nil, "c) dépôt fait")
local bobId = bob.UserId
leave(bob) -- dans la même image
advance(0.3)
check(STORE[bobId].Items["eve-chips"] ~= nil and STORE[bobId].Items["eve-chips"].Source == "PvP", "c) la sauvegarde du voleur a l'objet (Source = PvP)")
check(eveData.Items["eve-chips"] == nil and eveData.Display["3"] == nil, "c) la victime ne l'a plus")
invariants("transfert c", 9)

section("sortie")
check(not logHas("mal formé", "WARN"), "aucun envoi de remote mal formé (Net, en Studio)")
check(not logHas("tick :", "WARN"), "aucune erreur dans les boucles des services")
if VERBOSE then
	dumpLog()
end
summary("scénario rules")
