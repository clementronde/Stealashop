--!nocheck
-- Copie d'a48 (DEV-102) : version attendue PROFILE_V = 6 quand Types/Profile a Offline (gains hors ligne), 5 sinon.
PROFILE_V = if string.find(SOURCES["shared/Types/Profile.luau"] or "", "Offline: Offline", 1, true) then 6 else 5
-- Scénario « stand » (L-086) : on pose le colis sur un présentoir libre et débloqué de sa boutique, il
-- attend là (BB_OpenTimer V0), s'ouvre là, et l'objet reste exposé sur ce même présentoir (il rapporte
-- tout de suite). Refus : verrouillé, objet, colis, trop loin, tout plein (message). DisplayService
-- garde la règle (Boxed, PlaceAuto, HasRoom), le colis n'est pas volable (GetExposed). Cas d'erreur
-- (présentoir bonus perdu), file des colis à poser, plus d'amélioration « Workbenches », sauvegarde.

advance(1000)
startServer()

local function stateOf(player, slot)
	local plot = shopOf(player)
	local att = plot:FindFirstChild(string.format("DisplaySlot_%02d", slot), true)
	return if att then att:GetAttribute("UnboxState") else "absent"
end
local function standBox(player, slot)
	return shopOf(player):FindFirstChild(string.format("StandBox_%02d", slot))
end
local function exposedAt(player, slot)
	local e = DisplayService.GetExposed(player)[slot]
	return if e then e.Uid else nil
end

section("démarrage")
check(not logHas("[Loader", "WARN"), "aucun module en échec au chargement")
local UpgradesConfig = sharedModule("Config/Upgrades")
check(UpgradesConfig.ById.UnboxBenches == nil and #UpgradesConfig.List == 3, "Config/Upgrades : plus d'amélioration UnboxBenches (Workbenches), 3 améliorations")

section("profil neuf : v5, file vide, présentoirs Free / Locked")
local ada = join("Ada", nil)
advance(1.5)
local d = dataOf(ada)
check(d ~= nil and d.Version == PROFILE_V and type(d.BoxQueue) == "table" and #d.BoxQueue == 0 and next(d.Boxes) == nil, "profil neuf en v5, BoxQueue vide")
check(stateOf(ada, 1) == "Free" and stateOf(ada, 4) == "Free" and stateOf(ada, 5) == "Locked" and stateOf(ada, 20) == "Locked" and stateOf(ada, 21) == "Locked", `UnboxState sur les présentoirs : 1-4 Free, 5-20 et bonus 21 Locked ({tostring(stateOf(ada, 1))}, {tostring(stateOf(ada, 5))}, {tostring(stateOf(ada, 21))})`)
local bench = shopOf(ada):FindFirstChild("UnboxBench_01", true)
check(bench ~= nil and bench:GetAttribute("UnboxState") == nil, "UnboxBench_01 encore dans la boutique du banc, mais plus lu (aucun UnboxState)")
leave(ada)

section("pose sur un présentoir libre")
local data = newProfile()
data.Upgrades.UnboxBenches = 3 -- ancien niveau des établis : sans effet
addItem(data, "it2", "Z1_Donut", 2, 1, 500)
local bob = join("Bob", data)
advance(1.5)
check(dataOf(bob).Version == PROFILE_V and dataOf(bob).Upgrades.UnboxBenches == 3, "v4 → v5 sans colis ; Upgrades.UnboxBenches gardé (3), sans effet")
check(stateOf(bob, 2) == "Taken", "présentoir 2 avec un objet : Taken")
local heists = dataOf(bob).Lifetime.Heists
local box = placeBox(bob, 1, "Common", "Z1_Banane", "Standard", 1)
check(box ~= nil and box.ItemId == "Z1_Banane" and box.Rarity == "Common", "colis posé sur le présentoir 1 : Boxes[\"1\"]")
check(dataOf(bob).Lifetime.Heists == heists + 1, "braquage compté à la pose")
check(not CarryService.IsCarrying(bob), "le colis a quitté la tête")
local model = standBox(bob, 1)
check(model ~= nil and model:GetAttribute("Rarity") == "Common" and near(model:GetAttribute("ReadyAt"), box.ReadyAt, 1e-6), "StandBox_01 dans la boutique, attributs Rarity et ReadyAt")
local slotPos = standPos(bob, 1)
local pivot = model and model:GetPivot().Position
check(pivot ~= nil and (pivot - slotPos).Magnitude < 1.5, `posé sur le DisplaySlot_01 (écart {pivot and string.format("%.2f", (pivot - slotPos).Magnitude) or "?"} stud)`)
local timer = model and model:FindFirstChild("OpenTimer", true)
local label = timer and timer:FindFirstChild("Label", true)
check(label ~= nil and string.match(label.Text, "^%d+:%d%d$") ~= nil, `minuteur au-dessus du colis ({label and label.Text or "absent"})`)
advance(0.3)
check(stateOf(bob, 1) == "Waiting", "UnboxState du présentoir 1 : Waiting")
check(DisplayService.GetSlotStates(bob)[1] == "Boxed", "DisplayService : présentoir 1 Boxed")

section("refus : verrouillé, objet, colis, trop loin")
clearLog()
goToStand(bob, 5)
CarryService.Give(bob, npcBox("Common", "Z1_Banane"))
local before = #notifies(bob)
fireAs(bob, "PlaceBox", 5)
flush()
check(dataOf(bob).Boxes["5"] == nil and CarryService.IsCarrying(bob), "présentoir 5 verrouillé : refusé, colis toujours porté")
check(#notifies(bob, "This stand is locked") == 1, "message « stand is locked »")
goToStand(bob, 2)
fireAs(bob, "PlaceBox", 2)
flush()
check(dataOf(bob).Boxes["2"] == nil and #notifies(bob, "already in use") == 1, "présentoir 2 avec un objet : refusé, « already in use »")
goToStand(bob, 1)
fireAs(bob, "PlaceBox", 1)
flush()
check(dataOf(bob).Boxes["1"].ItemId == "Z1_Banane" and #notifies(bob, "already in use") == 2, "présentoir 1 avec un colis : refusé (le colis reste)")
moveTo(bob, standPos(bob, 3) + Vector3.new(0, 2, 40))
advance(0.3)
local n = #notifies(bob)
fireAs(bob, "PlaceBox", 3)
flush()
check(dataOf(bob).Boxes["3"] == nil and CarryService.IsCarrying(bob) and #notifies(bob) == n, "trop loin : refusé sans message")
check(logHas("PlaceBox(3) refusé : trop loin du présentoir", "PRINT", "server"), "ligne « trop loin » en Studio")
fireAs(bob, "PlaceBox", 99)
flush()
check(dataOf(bob).Boxes["99"] == nil, "présentoir inexistant : refusé")

section("DisplayService garde la règle : un colis occupe son présentoir")
local ok, why = DisplayService.PlaceItem(bob, "it2", 1)
check(ok == false and why == "Boxed", `PlaceItem sur le présentoir du colis : refusé (Boxed, {tostring(why)})`)
goToStand(bob, 1)
fireAs(bob, "PlaceItem", "it2", 1)
flush()
check(#notifies(bob, "A box is waiting on this stand") == 1 and dataOf(bob).Display["2"] == "it2", "remote PlaceItem : message, l'objet reste sur le 2")
dataOf(bob).Items.inv = { Id = "Z1_Donut", Source = "NPC", At = 0, Zone = 1 }
local auto = DisplayService.PlaceAuto(bob, "inv", standPos(bob, 1))
check(auto ~= 1 and auto ~= nil and dataOf(bob).Display[tostring(auto)] == "inv", `PlaceAuto près du colis : saute le présentoir 1 (posé sur le {tostring(auto)})`)
check(exposedAt(bob, 1) == nil, "rien d'exposé sur le présentoir du colis : rien à voler (GetExposed)")
DisplayService.Unplace(bob, "inv")

section("plein : aucun présentoir libre")
-- 1 : colis ; 2 : objet ; 3 et 4 : objets.
addItem(dataOf(bob), "it3", "Z1_Donut", nil, 1)
addItem(dataOf(bob), "it4", "Z1_Donut", nil, 1)
check(DisplayService.PlaceItem(bob, "it3", 3) and DisplayService.PlaceItem(bob, "it4", 4), "objets sur les présentoirs 3 et 4")
check(DisplayService.HasRoom(bob) == true, "HasRoom : l'inventaire a encore de la place")
advance(0.3)
check(stateOf(bob, 3) == "Taken" and stateOf(bob, 4) == "Taken", "3 et 4 : Taken")
goToStand(bob, 3)
local full0 = #notifies(bob, "All your stands are full")
fireAs(bob, "PlaceBox", 3)
flush()
check(dataOf(bob).Boxes["3"] == nil and #notifies(bob, "All your stands are full") == full0 + 1, "PlaceBox sur un présentoir pris, rien de libre : « All your stands are full »")
advance(4)
check(logCount("porte un colis, aucun présentoir libre", "PRINT", "server") == 1, "près de ses présentoirs avec un colis : le message part aussi tout seul, une seule fois par colis porté")
check(#notifies(bob, "All your stands are full") <= full0 + 2, "pas de message en boucle")
CarryService.Give(bob, nil)

section("minuteur, prêt, ouverture sur place")
goToStand(bob, 1)
fireAs(bob, "OpenBox", 1)
flush()
check(#notifies(bob, "isn't ready yet") == 1 and dataOf(bob).Boxes["1"] ~= nil, "pas prêt : refusé")
advance(math.max(0, dataOf(bob).Boxes["1"].ReadyAt - serverTime()) + 0.3)
local readies = remotes("BoxReady", function(e) return e.to == bob end)
check(#readies == 1 and readies[1].args[1] == 1, "BoxReady(1) au propriétaire")
check(stateOf(bob, 1) == "Ready" and label.Text == "Ready!", "UnboxState Ready, minuteur « Ready! »")
local income0 = bob:GetAttribute("Income")
local uid = openPlaced(bob, 1)
check(uid ~= nil, "OpenBox(1) : objet révélé")
local reveal = remotes("UnboxReveal", function(e) return e.to == bob end)
reveal = reveal[#reveal]
check(reveal.args[1] == 1 and reveal.args[3] == "Z1_Banane", "UnboxReveal(1, uid, Z1_Banane, …)")
local after = dataOf(bob)
check(after.Boxes["1"] == nil and after.Display["1"] == uid and after.Items[uid].Id == "Z1_Banane", "l'objet reste sur le présentoir 1 (Display[\"1\"])")
check(standBox(bob, 1) == nil and exposedAt(bob, 1) == uid, "le colis a disparu, l'objet est exposé sur le 1 (DisplayItem)")
check(bob:GetAttribute("Income") > income0, `il rapporte tout de suite (Income {income0} → {bob:GetAttribute("Income")})`)
advance(0.3)
check(stateOf(bob, 1) == "Taken", "UnboxState : Taken")
check(#notifies(bob, "went to your inventory") == 0, "pas de message d'inventaire")
local reg0 = DisplayService.GetRegister(bob)
advance(3)
check(DisplayService.GetRegister(bob) > reg0, "la caisse se remplit")

section("plus d'amélioration Workbenches ; un présentoir acheté reçoit un colis")
local cash0 = dataOf(bob).Cash
fireAs(bob, "BuyItem", "UnboxBenches")
flush()
check(dataOf(bob).Cash == cash0 and dataOf(bob).Upgrades.UnboxBenches == 3, "BuyItem(UnboxBenches) refusé : rien payé, niveau inchangé")
check(bob:GetAttribute("UnboxBenchesLevel") == nil, "plus d'attribut UnboxBenchesLevel")
dataOf(bob).Cash = 100000
moveTo(bob, shopOf(bob):GetPivot().Position + Vector3.new(0, 3, 0))
fireAs(bob, "BuyItem", "DisplaySlots")
flush()
check(dataOf(bob).Upgrades.DisplaySlots == 1, "présentoir 5 acheté")
check(stateOf(bob, 5) == "Free", `UnboxState du 5 : Free tout de suite ({tostring(stateOf(bob, 5))})`)
local box5 = placeBox(bob, 5, "Common", "Z1_Banane", "Standard", 1)
check(box5 ~= nil, "colis posé sur le présentoir 5 acheté")

section("cas d'erreur : présentoir bonus perdu avant l'ouverture")
DisplayService.GetExtraSlots = function()
	return 4
end
advance(1.2)
check(stateOf(bob, 21) == "Free", "gamepass +4 : présentoir bonus 21 Free")
local box21 = placeBox(bob, 21, "Common", "Z1_Banane", "Standard", 1)
check(box21 ~= nil, "colis posé sur le présentoir bonus 21")
DisplayService.GetExtraSlots = function()
	return 0
end
advance(1.2)
check(dataOf(bob).Boxes["21"] ~= nil and stateOf(bob, 21) == "Waiting", "gamepass perdu : le colis reste sur le 21 (Waiting), rien n'est perdu")
DisplayService.Unplace(bob, "it4") -- le 4 se libère
local uid21 = openPlaced(bob, 21)
local placed21 = nil
for key, value in dataOf(bob).Display do
	if value == uid21 then
		placed21 = key
	end
end
check(uid21 ~= nil and dataOf(bob).Boxes["21"] == nil and placed21 == "4", `ouvert : l'objet va sur le présentoir libre (le 4, trouvé {tostring(placed21)})`)
check(logHas("exposé sur le présentoir 4", "PRINT", "server") and #notifies(bob, "went to your inventory") == 0, "ligne « exposé sur le présentoir 4 », pas de message d'inventaire")

section("file des colis à poser")
local q = newProfile(4)
for i = 1, 4 do
	addItem(q, `q{i}`, "Z1_Donut", i, 1)
end
local cid = join("Cid", q)
advance(1.5)
local cdata = dataOf(cid)
local queuedAt = serverTime() + 100
cdata.BoxQueue[1] = { Tier = "Standard", Zone = 1, ItemId = "Z1_Banane", Rarity = "Common", ReadyAt = queuedAt }
cdata.BoxQueue[2] = { Tier = "Nope" }
advance(1.2)
check(#cdata.BoxQueue == 2 and next(cdata.Boxes) == nil, "tous les présentoirs pris : les colis attendent dans la file")
DisplayService.Unplace(cid, "q3")
advance(1.2)
check(cdata.Boxes["3"] ~= nil and cdata.Boxes["3"].ItemId == "Z1_Banane" and cdata.Boxes["3"].ReadyAt == queuedAt, "le 3 se libère : le colis de la file y est posé, ReadyAt d'origine")
check(#cdata.BoxQueue == 1 and cdata.BoxQueue[1].Tier == "Nope", "le colis illisible reste dans la file")
check(#notifies(cid, "Your waiting box is now on a free stand") == 1, "le joueur est prévenu")
check(standBox(cid, 3) ~= nil, "StandBox_03 affiché")
DisplayService.Unplace(cid, "q4")
advance(2.5)
check(logCount("colis n° 1 de la file illisible", "WARN", "server") == 1 and cdata.Boxes["4"] == nil and #cdata.BoxQueue == 1, "colis illisible signalé une seule fois, jamais posé, gardé")

section("colis sur un présentoir absent de la parcelle : dans la file, puis posé")
local p5 = newProfile(4)
local dan = join("Dan", p5)
advance(1.5)
leave(dan)
local saved = SAVED[`Player_{dan.UserId}`]
saved.Boxes["30"] = { Tier = "Standard", Zone = 1, ItemId = "Z1_Banane", Rarity = "Common", ReadyAt = 0 }
PRESET_PROFILES[`Player_{dan.UserId}`] = saved
local dan2 = join("Dan", saved, dan.UserId)
advance(1.5)
local dd = dataOf(dan2)
check(dd.Boxes["30"] == nil and dd.Boxes["1"] ~= nil and #dd.BoxQueue == 0, "présentoir 30 absent : le colis passe dans la file puis sur le présentoir 1")
check(logHas("absent de", "WARN", "server"), "avertissement")

section("sauvegarde et retour")
local boxBob = dataOf(bob).Boxes["5"]
leave(bob)
local savedBob = SAVED[`Player_{bob.UserId}`]
check(savedBob.Version == PROFILE_V and savedBob.Boxes["5"] ~= nil and savedBob.Display["1"] == uid, "sauvegardé en v5 : colis du 5, objet du 1")
local bob2 = join("Bob", nil, bob.UserId)
advance(1.5)
check(dataOf(bob2).Boxes["5"] ~= nil and near(dataOf(bob2).Boxes["5"].ReadyAt, boxBob.ReadyAt, 1e-6) and standBox(bob2, 5) ~= nil, "au retour : le colis revient sur le présentoir 5")
check(next(UnboxService.GetWaiting(bob2)) == nil or UnboxService.GetWaiting(bob2)[5] ~= nil, "GetWaiting par numéro de présentoir")

summary("scénario stand")
