-- Banc a301 : scénarios de ShopSpyController (Features.ShopSpy, Config/ShopSpy).

local Spy = requireModule(ReplicatedStorage.Shared.Config.ShopSpy)
check("C1 Config/ShopSpy.Range = 40 (V0)", Spy.Range == 40, Spy.Range)
check("C2 Config/ShopSpy.Interval = 0.25 (V0)", Spy.Interval == 0.25, Spy.Interval)
local Features = requireModule(ReplicatedStorage.Shared.Config.Features)
check("C3 Features.ShopSpy = true (V0)", Features.ShopSpy == true)

-- Boutique d'un autre joueur (UserId 2) : façade x = -66, z de 5,5 à 53,5.
local other = makePlot("PLOT_Shop_03", 2, 29.5)
local a = addItem(other, "DisplayItem_01")
local b = addItem(other, "DisplayItem_02")
local noBoard = addItem(other, "DisplayItem_03", false)
-- Objet posé au sol dans la même boutique (FloorItem, hors de DisplayItems) avec un billboard.
local floor = new("Model", "FloorItem_01", other)
addTag(floor, "FloorItem")
local floorGui = new("BillboardGui", "BB_Item", floor)
floorGui.AlwaysOnTop = false
-- Modèle sans tag DisplayItem dans DisplayItems (pas un objet exposé).
local stray = new("Model", "Autre", other:FindFirstChild("DisplayItems"))
local strayGui = new("BillboardGui", "BB_Item", stray)
strayGui.AlwaysOnTop = false
-- Ma boutique (UserId 1) et celle d'un bot (OwnerUserId 0).
local mine = makePlot("PLOT_Shop_04", 1, -60)
local m1 = addItem(mine, "DisplayItem_01")
local bot = makePlot("PLOT_Shop_02", 0, 120)
local b1 = addItem(bot, "DisplayItem_01")

local ctrl = loadController()

-- Loin de la façade (milieu de la place, 66 studs) : rien.
placeMe(0, 3, 29.5)
step(0.3)
check("L1 loin (66 studs) : pas d'espionnage", not ctrl.IsSpying(other))
check("L2 loin : BB_Item pas par-dessus", board(a).AlwaysOnTop == false and board(b).AlwaysOnTop == false)

-- Dans la rue, 26 studs de la façade : pas encore revu avant Interval.
placeMe(-40, 3, 29.5)
step(0.1)
check("R0 revue seulement toutes les Interval s", board(a).AlwaysOnTop == false)
step(0.2)
check("R1 rue (26 studs) : boutique espionnée", ctrl.IsSpying(other))
check("R2 rue : BB_Item des objets exposés par-dessus la façade", board(a).AlwaysOnTop == true and board(b).AlwaysOnTop == true)
check("R3 rue : MaxDistance de Clément pas touchée", board(a).MaxDistance == 160)
check("R4 objet posé au sol pas touché", floorGui.AlwaysOnTop == false)
check("R5 modèle sans tag DisplayItem pas touché", strayGui.AlwaysOnTop == false)
check("R6 objet sans BB_Item : pas d'erreur", noBoard:FindFirstChild("BB_Item") == nil)
check("R7 ma boutique jamais espionnée", not ctrl.IsSpying(mine) and board(m1).AlwaysOnTop == false)
check("R8 boutique du bot loin (66 studs en z) : rien", not ctrl.IsSpying(bot) and board(b1).AlwaysOnTop == false)

-- Objet posé pendant qu'on regarde : allumé au passage suivant.
local c = addItem(other, "DisplayItem_04")
step(0.3)
check("N1 objet posé pendant l'espionnage : allumé", board(c).AlwaysOnTop == true)
-- Objet repris (sorti de DisplayItems) : rendu à sa valeur.
local cGui = board(c)
c:Remove()
step(0.3)
check("N2 objet sorti de la boutique : rendu", cGui.AlwaysOnTop == false)

-- Portée : 39,5 studs → oui ; 40,5 → non (rendu).
placeMe(-66 + 39.5, 3, 29.5)
step(0.3)
check("P1 39,5 studs : espionnée", ctrl.IsSpying(other) and board(a).AlwaysOnTop == true)
placeMe(-66 + 40.5, 3, 29.5)
step(0.3)
check("P2 40,5 studs : plus rien, valeur rendue", not ctrl.IsSpying(other) and board(a).AlwaysOnTop == false and board(b).AlwaysOnTop == false)

-- Sur le côté de la boutique, dehors, 10 studs : oui.
placeMe(-100, 3, 29.5 + 24 + 10)
step(0.3)
check("S1 côté de la boutique, dehors (10 studs) : espionnée", ctrl.IsSpying(other) and board(a).AlwaysOnTop == true)

-- On entre : comme avant (rien par-dessus).
placeMe(-80, 3, 29.5)
step(0.3)
check("D1 dans la boutique : comme avant", not ctrl.IsSpying(other) and board(a).AlwaysOnTop == false)

-- Devant ma propre boutique : rien ne change chez le propriétaire.
placeMe(-40, 3, -60)
step(0.3)
check("O1 devant ma boutique : rien", not ctrl.IsSpying(mine) and board(m1).AlwaysOnTop == false)

-- Plus de personnage : rendu.
placeMe(-40, 3, 29.5)
step(0.3)
check("V1 (re)espionnée", ctrl.IsSpying(other))
LocalPlayer.Character = nil
step(0.3)
check("V2 sans personnage : rendu", not ctrl.IsSpying(other) and board(a).AlwaysOnTop == false)

-- Billboard déjà AlwaysOnTop chez Clément : laissé à true en partant.
placeMe(-40, 3, 29.5)
board(b).AlwaysOnTop = true
step(0.3)
placeMe(0, 3, 29.5)
step(0.3)
check("T1 valeur d'origine true gardée", board(b).AlwaysOnTop == true and board(a).AlwaysOnTop == false)
board(b).AlwaysOnTop = false

-- La boutique devient la mienne pendant l'espionnage : rendu.
placeMe(-40, 3, 29.5)
step(0.3)
other:SetAttribute("OwnerUserId", 1)
step(0.3)
check("M1 boutique devenue la mienne : rendu", not ctrl.IsSpying(other) and board(a).AlwaysOnTop == false)
other:SetAttribute("OwnerUserId", 2)

-- Tag PlayerPlot retiré (streaming, nettoyage) pendant l'espionnage : rendu.
step(0.3)
check("U0 (re)espionnée", ctrl.IsSpying(other))
removeTag(other, "PlayerPlot")
step(0.3)
check("U1 boutique sans tag : rendu", not ctrl.IsSpying(other) and board(a).AlwaysOnTop == false)
addTag(other, "PlayerPlot")

-- Bot : même règle qu'un autre joueur (OwnerUserId 0).
placeMe(-40, 3, 120)
step(0.3)
check("B1 devant la boutique du bot : espionnée", ctrl.IsSpying(bot) and board(b1).AlwaysOnTop == true)
placeMe(0, 3, 120)
step(0.3)

-- Interrupteur coupé : comme avant, aucun Heartbeat branché.
OVERRIDES["Config/Features"] = table.freeze({ ShopSpy = false })
local off = loadController()
placeMe(-40, 3, 29.5)
step(0.3)
off.Refresh()
check("F1 Features.ShopSpy = false : rien, aucun Heartbeat", beatCount() == 0 and not off.IsSpying(other) and board(a).AlwaysOnTop == false and board(b).AlwaysOnTop == false)

print(`banc a301 (espionner la vitrine depuis la rue) : {CHECKS} vérification(s), {FAILS} échec(s)`)
