--!nocheck
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

section("règle 1 : bouclier débutant")
SHIELDED[ada] = true
advance(0.6)
check(adaShop:GetAttribute("Protection") == "Shield", "Protection = Shield sur la boutique d'Ada")
local _, hits = breakDoor(bob, adaShop, 30)
check(not WindowService.IsBroken(adaDoor), `porte inviolable : {hits} coups refusés`)
check(#notifies(bob, "This shop is protected: its owner just started playing.") >= 1, "le frappeur est prévenu")
check(#notifies(bob, "This shop is protected") <= 2, `message limité (au plus un toutes les 3 s : {#notifies(bob, "This shop is protected")})`)
moveTo(bob, SHOPS[1].S.outside + Vector3.new(0, 0, -6))
advance(0.5)
local panel = PvPController.GetPanelText(adaShop)
check(panel and panel.Status == "NEW PLAYER: PROTECTED", `panneau : « NEW PLAYER: PROTECTED » (trouvé {panel and panel.Status})`)
-- Porte cassée avant le bouclier (cas d'école) : la prise est refusée aussi.
SHIELDED[ada] = false
advance(0.6)
check(breakDoor(cy, adaShop), "sans bouclier, Cy casse la porte")
SHIELDED[ada] = true
check(not steal(bob, adaShop, 1), "bouclier : prise refusée même porte cassée")
check(adaData.Display["1"] == "ada-soda", "bouclier : l'objet reste à Ada")
SHIELD_ERROR = true
check(not steal(bob, adaShop, 1), "IsShielded en panne : la boutique compte comme protégée")
SHIELD_ERROR = nil
SHIELDED[ada] = false
WindowService.Rebuild(adaDoor)
advance(0.3)

section("règle 2 : pas d'acharnement (3 s d'immunité aux coups de batte)")
-- Écrite par a30 (BatService) : PvPService lui donne IsThiefOf et GetTheft, rien d'autre à tester ici.
check(type(PvPService.IsThiefOf) == "function" and type(PvPService.GetTheft) == "function", "accroches pour la batte : IsThiefOf, GetTheft")

section("règle 3 : immunité de 120 s après un vol subi")
check(breakDoor(bob, adaShop), "Bob casse la porte d'Ada")
moveTo(cy, SHOPS[1].S.center) -- Cy attend dans la boutique cassée
check(steal(bob, adaShop, 1), "Bob prend la Canette de soda")
fastHome(bob, 40)
check(bobData.Items["ada-soda"] ~= nil, "vol réussi : la Canette est à Bob")
check(adaShop:GetAttribute("StealOpen") == true, "la fenêtre de vol est encore ouverte")
local before = adaData.Display["2"]
check(not steal(cy, adaShop, 2), "immunité : Cy ne peut plus rien prendre, même porte cassée")
check(#notifies(cy, "This shop was just robbed: protected for 11") == 1, `message à Cy : protégée encore 11xs ({#notifies(cy, "This shop was just robbed")})`)
check(adaData.Display["2"] == before, "immunité : le Paquet de chips reste à Ada")
moveTo(cy, SHOPS[3].S.center)
advance(25) -- la porte se reconstruit (30 s après la casse)
check(not WindowService.IsBroken(adaDoor), "porte d'Ada refaite")
local _, refused = breakDoor(cy, adaShop, 20)
check(not WindowService.IsBroken(adaDoor), `immunité : {refused} coups refusés sur la porte`)
check(#notifies(cy, "This shop was just robbed: protected for") >= 2, "immunité : le frappeur est prévenu")
local alarm = #notifies(ada, "smashed your shop door")
advance(95, 0.5)
check(PvPService.GetProtection(ada) == nil and adaShop:GetAttribute("Protection") == nil, "après 120 s : plus d'immunité")
check(breakDoor(cy, adaShop), "après 120 s : la porte se casse de nouveau")
check(#notifies(ada, "smashed your shop door") == alarm + 1, "alarme de base de nouveau")
WindowService.Rebuild(adaDoor)
advance(0.3)
invariants("immunité", TOTAL)

section("règle 4 : pas de racket")
local rich = newProfile()
addItem(rich, "dan-robot", "Z2_RobotJouet", 1) -- Épique de la zone 2 : 120 $/s
leave(cy)
local dan = join("Dan", rich)
advance(1.2)
check(dan:GetAttribute("Income") == 120 and ada:GetAttribute("Income") == 7, `revenus : Dan 120 $/s, Ada 7 $/s (trouvé {dan:GetAttribute("Income")} et {ada:GetAttribute("Income")})`)
local _, tries = breakDoor(dan, adaShop, 20)
check(not WindowService.IsBroken(adaDoor), `Ada (7 $/s) vaut moins de 10 % de Dan (12 $/s) : {tries} coups refusés`)
check(#notifies(dan, "This shop is too small for you to rob.") >= 1, "le riche est prévenu")
check(breakDoor(bob, adaShop), "Bob (1 $/s) casse la porte d'Ada")
check(not steal(dan, adaShop, 2), "anti-racket : Dan ne peut pas prendre non plus, porte cassée")
check(steal(bob, adaShop, 2), "Bob, lui, peut prendre (Ada vaut plus de 10 % de lui)")
CarryService.Fail(bob, "Bat")
flush()
-- Bob devient riche : la boutique d'Ada est trop petite pour lui aussi, vu de son client.
bobData.Items["bob-plush"] = { Id = "Z2_PelucheGeante", Source = "NPC", At = 0, Zone = 2 }
DisplayService.PlaceAuto(bob, "bob-plush")
advance(0.6)
moveTo(bob, SHOPS[1].S.outside + Vector3.new(0, 0, -6))
advance(0.5)
local panel4 = PvPController.GetPanelText(adaShop)
check(panel4 and panel4.Status == "TOO SMALL TO ROB", `panneau de Bob : « TOO SMALL TO ROB » (trouvé {panel4 and panel4.Status})`)
standBy(bob, adaShop, 2)
advance(0.5)
local prompt = PvPController.GetPrompt(displayModel(adaShop, 2))
check(prompt ~= nil and not prompt.Enabled, "anti-racket : pas d'invite active chez lui")
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

section("règle 5 : coffre-fort (au moins 1 objet toujours à l'abri)")
check(adaShop:GetAttribute("SafeSlots") == "3", "le Pot de nouilles (le plus rentable) est à l'abri")
check(breakDoor(bob, adaShop), "porte cassée")
check(not steal(bob, adaShop, 3), "l'objet à l'abri ne se vole pas")
check(#notifies(bob, "This item is in the safe: nobody can steal it.") == 1, "message : objet au coffre-fort")
check(adaData.Display["3"] == "ada-noodles", "il reste sur son présentoir")
standBy(bob, adaShop, 3)
advance(0.5)
local safePrompt = PvPController.GetPrompt(displayModel(adaShop, 3))
check(safePrompt and not safePrompt.Enabled, "pas d'invite active sur lui")
local tag = bob.PlayerGui:FindFirstChild("SafeTag")
check(tag and tag.Adornee and tag.Adornee.Parent and tag.Adornee.Parent:IsDescendantOf(displayModel(adaShop, 3)), "étiquette SAFE sur cet objet")
check(steal(bob, adaShop, 2), "les autres objets se volent")
CarryService.Fail(bob, "Bat")
flush()
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
check(eveShop:GetAttribute("SafeSlots") == "2", "Eve n'expose qu'un objet : il est à l'abri")
check(breakDoor(bob, eveShop), "porte d'Eve cassée")
check(not steal(bob, eveShop, 2), "Eve, un seul objet : rien à voler")
-- À revenu égal, le plus petit numéro de présentoir est à l'abri.
addItem(eveData, "eve-chips", "Z1_PaquetDeChips", 3)
advance(1.2)
check(eveShop:GetAttribute("SafeSlots") == "2", "deux Communs : le présentoir 2 (le plus petit numéro) est à l'abri")
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
fastHome(bob, 40)
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
fastHome(bob, 40)
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
walkTo(bob, SHOPS[1].S.outside, 40)
walkTo(bob, B.outside, 40)
walkTo(bob, Vector3.new(B.door.X, 3, B.door.Z) + B.front * 1, 40)
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
walkTo(bob, Vector3.new(E.door.X, 3, E.door.Z) + E.front * 1, 40)
walkTo(bob, E.outside, 40)
walkTo(bob, HUB_CENTER, 40)
walkTo(bob, B.outside, 40)
walkTo(bob, Vector3.new(B.door.X, 3, B.door.Z) + B.front * 1, 40)
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
