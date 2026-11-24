--!nocheck
-- Scénario « edges » : les contrôles du serveur sur StealItem (9.4 à compléter) et les cas limites :
-- maintien trop court, un objet à la fois, sa propre boutique, boutique pleine, pas de boutique,
-- distance, volume Bounds, fenêtre fermée, objet déplacé pendant le maintien, arguments refusés par
-- Net, présentoir d'un objet tenu, plus de chrono (a112), distance du panneau.

startServer()

local adaData = newProfile()
addItem(adaData, "ada-soda", "Z1_CanetteDeSoda", 1)
addItem(adaData, "ada-chips", "Z1_PaquetDeChips", 2)
addItem(adaData, "ada-noodles", "Z1_PotDeNouilles", 3)
addItem(adaData, "ada-donut", "Z1_Donut", 4)
local ada = join("Ada", adaData)
local bobData = newProfile()
local bob = join("Bob", bobData)
local cyData = newProfile()
local cy = join("Cy", cyData)
startClient(bob)
advance(1.2)
local adaShop, bobShop, cyShop = shopOf(ada), shopOf(bob), shopOf(cy)
local adaDoor = windowIdOf(adaShop)

section("fenêtre de vol et chrono")
check(not steal(bob, adaShop, 1), "porte intacte : rien à prendre (et Bob est sorti de la boutique)")
moveTo(cy, SHOPS[1].S.outside + Vector3.new(0, 0, -5)) -- 11,5 studs devant la porte, 51,5 du centre : il voit le chrono
DAMAGE[bob] = 1000
check(breakDoor(bob, adaShop), "porte cassée d'un coup (1000 dégâts contre 500 PV)")
advance(0.2)
check(#remotes("HeistTimer", function(e) return e.to == cy end) == 0, "a112 : plus de chrono, même pour un voisin à moins de 60 studs")
moveTo(ada, SHOPS[1].S.center)
advance(0.2)
check(#remotes("HeistTimer", function(e) return e.to == ada end) == 0, "jamais la victime")

section("maintien de la prise")
standBy(bob, adaShop, 1)
fireAs(bob, "StealItem", 1, 1)
advance(0.5)
fireAs(bob, "StealItem", 1, 1)
flush()
check(not CarryService.IsCarrying(bob), "maintien de 0,5 s : trop court, refusé")
advance(0.45)
fireAs(bob, "StealItem", 1, 1)
flush()
check(CarryService.IsCarrying(bob), "le même maintien atteint 1 s (moins 0,1 s de tolérance) : prise acceptée")

section("un objet à la fois")
standBy(bob, adaShop, 2)
fireAs(bob, "StealItem", 1, 2)
advance(1)
fireAs(bob, "StealItem", 1, 2)
flush()
check(PvPService.GetTheft(bob).ItemUid == "ada-soda" and adaData.Display["2"] == "ada-chips", "les mains pleines : pas de 2e objet")
CarryService.Fail(bob, "Bat")
flush()

section("objet tenu : son propriétaire ne peut pas le déplacer")
check(steal(bob, adaShop, 1), "Bob reprend la Canette")
moveTo(ada, SHOPS[1].S.center)
fireAs(ada, "PlaceItem", "ada-soda", 4)
flush()
check(#notifies(ada, "This item is being stolen: hit the thief to get it back!") == 1, "PlaceItem d'un objet tenu : refusé (Held)")
fireAs(ada, "PlaceItem", "ada-chips", 1)
flush()
check(#notifies(ada, "This stand is already taken.") == 1, "PlaceItem sur le présentoir d'un objet tenu : refusé (Taken)")
check(DisplayService.Unplace(ada, "ada-soda") == nil and DisplayService.PlaceAuto(ada, "ada-soda") == nil, "Unplace et PlaceAuto refusent l'objet tenu")
check(adaData.Display["1"] == "ada-soda", "l'objet tenu reste à sa place dans le profil")
CarryService.Fail(bob, "Bat")
flush()

section("objet déplacé pendant le maintien")
standBy(bob, adaShop, 2)
fireAs(bob, "StealItem", 1, 2)
advance(0.4)
fireAs(ada, "PlaceItem", "ada-chips", 5) -- verrouillé : refusé
adaData.Display["2"] = nil -- le propriétaire range l'objet (inventaire)
adaData.Display["4"] = nil
adaData.Display["2"] = "ada-donut"
adaData.Display["4"] = "ada-chips"
advance(1.2)
fireAs(bob, "StealItem", 1, 2)
flush()
check(not CarryService.IsCarrying(bob), "l'objet du présentoir a changé pendant le maintien : prise refusée")

section("distance et volume")
local S = SHOPS[1].S
moveTo(bob, Vector3.new(S.slots[1].X, 3, S.slots[1].Z) + Vector3.new(0, 0, 9))
fireAs(bob, "StealItem", 1, 1)
advance(1)
fireAs(bob, "StealItem", 1, 1)
flush()
check(not CarryService.IsCarrying(bob) and logHas("trop loin", "WARN", "server"), "à 9 studs du présentoir : refusé (trop loin)")
moveTo(bob, S.outside)
fireAs(bob, "StealItem", 1, 1)
advance(1)
fireAs(bob, "StealItem", 1, 1)
flush()
check(not CarryService.IsCarrying(bob), "devant la porte, hors de Bounds : refusé")

section("sa propre boutique, boutique pleine, pas de boutique")
WindowService.Rebuild(adaDoor)
advance(0.3)
check(breakDoor(bob, adaShop), "porte recassée (nouvelle fenêtre de 10 s)")
moveTo(ada, SHOPS[1].S.center)
check(not steal(ada, adaShop, 2), "le propriétaire ne vole pas chez lui")
for i = 1, 34 do
	addItem(cyData, `cy-{i}`, "Z1_Banane", if i <= 4 then i else nil)
end
advance(1.2)
check(not steal(cy, adaShop, 2), "Cy : 4 présentoirs et 30 objets en inventaire, refusé")
check(#notifies(cy, "Your shop is full: make room before stealing.") == 1, "message : boutique pleine")
for i = 5, 34 do
	cyData.Items[`cy-{i}`] = nil
end
local dan = join("Dan", newProfile()) -- 4e joueur, 3 boutiques : il attend
advance(0.5)
check(shopOf(dan) == nil, "Dan n'a pas de boutique")
check(not steal(dan, adaShop, 2), "sans boutique : refusé")
check(#notifies(dan, "You need a shop to steal.") == 1, "message : il faut une boutique")

section("arguments refusés par Net")
clearLog()
fireAs(bob, "StealItem", "1", 1)
fireAs(bob, "StealItem", 1)
fireAs(bob, "StealItem", 1, 1.5)
fireAs(bob, "StealItem", 0, 1)
fireAs(bob, "StealItem", 1, 101)
flush()
check(not CarryService.IsCarrying(bob), "aucune prise sur des arguments mal formés")
check(not logHas("StealItem(", "WARN", "server") and logHas("→ StealItem refusé", "WARN", "server"), "Net les arrête avant PvPService")
advance(1.1) -- débit de Net : 5 appels par seconde
fireAs(bob, "StealItem", 9, 1)
flush()
check(logHas("boutique inconnue", "WARN", "server"), "boutique inconnue (plotIndex 9) : refusé par PvPService")

section("a112 : toujours ouverte après 10 s (plus de chrono)")
advance(10)
check(adaShop:GetAttribute("StealOpen") == true, "10 s plus tard : toujours ouverte au vol")
check(steal(bob, adaShop, 2), "après 10 s : la prise marche encore")
CarryService.Fail(bob, "Bat")
flush()

section("panneau : 15 studs du volume de la boutique")
WindowService.Rebuild(adaDoor)
advance(0.3)
local bounds = boundsOf(adaShop)
local edge = bounds.CFrame * Vector3.new(0, -12, -bounds.Size.Z / 2) -- milieu de la façade, à 3 studs du sol
moveTo(bob, edge + SHOPS[1].S.front * 16)
advance(0.5)
check(PvPController.GetPanelText(adaShop) == nil, "à 16 studs : pas de panneau")
moveTo(bob, edge + SHOPS[1].S.front * 14)
advance(0.5)
check(PvPController.GetPanelText(adaShop) ~= nil, "à 14 studs : le panneau apparaît")
check(PvPController.GetPanelText(adaShop).HP == "HP 50", "PV pleins après la reconstruction (base du niveau 1, copie a93)")
DAMAGE[bob] = 10
fireAs(bob, "HitWindow", adaDoor) -- trop loin : rien
moveTo(bob, SHOPS[1].S.outside + SHOPS[1].S.front * -3)
giveTool(bob)
fireAs(bob, "HitWindow", adaDoor)
advance(0.11)
fireAs(bob, "HitWindow", adaDoor)
advance(0.2)
advance(0.4)
local hp = PvPController.GetPanelText(adaShop)
local sent = ClientWindow.hp[adaDoor]
local shown = hp and tonumber(string.match(hp.HP, "^HP (%d+)$"))
check(sent ~= nil and shown ~= nil and shown < 495 and math.abs(shown - sent.hp) <= 4, `panneau : PV de WindowHP après 2 coups, au plus 0,2 s de retard ({sent and sent.hp} → {hp and hp.HP})`)
dropTools(bob)
leave(ada)
advance(0.5)
local reassigned = PvPController.GetPanelText(adaShop)
check(shopOf(dan) == adaShop and reassigned and reassigned.OwnerName == "Dan's Shop" and reassigned.HP == "HP 50", "(copie a93 : base du niveau 1) boutique libérée puis donnée à Dan (il attendait) : le panneau suit le nouveau propriétaire, porte refaite")

section("DepositZone plus haute que le sol (hauteur absente du relevé)")
local zone = bobShop:FindFirstChild("DepositZone")
zone.CFrame = SHOPS[2].S.origin * CFrame.new(0, 20, 0) -- de 14 à 26 studs : le joueur est en dessous
DAMAGE[bob] = 1000
check(breakDoor(bob, cyShop), "Bob casse la porte de Cy")
check(cyShop:GetAttribute("SafeSlots") == "1", "Cy : 4 Bananes, la 1re à l'abri")
check(steal(bob, cyShop, 2), "Bob prend la Banane du présentoir 2")
runHome(bob, cyShop)
check(bobData.Items["cy-2"] ~= nil and cyData.Items["cy-2"] == nil, "dépôt fait dans l'emprise au sol de la DepositZone, dans Bounds")
invariants("DepositZone haute", 8) -- 4 objets d'Ada + 4 Bananes de Cy

section("sortie")
check(not logHas("mal formé", "WARN"), "aucun envoi de remote mal formé (Net, en Studio)")
check(not logHas("tick :", "WARN"), "aucune erreur dans les boucles des services")
if VERBOSE then
	dumpLog()
end
summary("scénario edges")
