--!nocheck
-- Scénario « flow » : un vol complet à 3 joueurs (6.1). Repérage (panneau du voleur), casse de la
-- porte, prise en 1 s par l'invite, fuite à −25 %, dépôt chez soi, objet au voleur, exposé et
-- rentable tout de suite ; compteurs, alertes, messages, sauvegardes, argent intact.
-- Copie d'a99 (2026-11-12) : plus d'immunité après un vol subi (décision de Cantin).

startServer()

-- Ada (boutique 1) : 3 objets exposés ; Bob (boutique 2) : le voleur ; Cy (boutique 3, tournée) : témoin.
local adaData = newProfile()
addItem(adaData, "ada-soda", "Z1_CanetteDeSoda", 1) -- Commun, 1 $/s
addItem(adaData, "ada-chips", "Z1_PaquetDeChips", 2) -- Commun, 1 $/s
addItem(adaData, "ada-noodles", "Z1_PotDeNouilles", 3) -- Rare, 5 $/s : le meilleur, à l'abri
local ada = join("Ada", adaData)
local bobData = newProfile()
addItem(bobData, "bob-banana", "Z1_Banane", 1)
local bob = join("Bob", bobData)
local cy = join("Cy", newProfile())
startClient(bob)
advance(1.2)

local adaShop, bobShop = shopOf(ada), shopOf(bob)
section("installation")
check(adaShop == SHOPS[1].model and bobShop == SHOPS[2].model and shopOf(cy) == SHOPS[3].model, "boutiques 1, 2 et 3 données dans l'ordre d'arrivée")
check(insideBox(boundsOf(adaShop), rootOf(ada).Position), "Ada apparaît dans sa boutique (SpawnPoint)")
check(ada:GetAttribute("Income") == 7, `revenu d'Ada : 7 $/s (trouvé {ada:GetAttribute("Income")})`)
check(adaShop:GetAttribute("SafeSlots") == "3", `objet à l'abri chez Ada : le présentoir 3, le Pot de nouilles (trouvé {adaShop:GetAttribute("SafeSlots")})`)
check(adaShop:GetAttribute("Protection") == nil, "boutique d'Ada pas protégée (bouclier fini, aucun vol subi)")
check(logHas("3 boutique(s) suivie(s)", "PRINT", "server"), "PvPService suit les 3 boutiques")

section("repérage (6.1, point 1)")
moveTo(bob, SHOPS[1].S.outside + Vector3.new(0, 0, -30)) -- loin : 36 studs devant la porte
advance(0.5)
check(PvPController.GetPanelText(adaShop) == nil, "loin de la boutique : pas de panneau")
moveTo(bob, SHOPS[1].S.outside + Vector3.new(0, 0, -6)) -- 12,5 studs de Bounds
advance(0.5)
local panel = PvPController.GetPanelText(adaShop)
check(panel ~= nil, "à moins de 15 studs : le panneau de la boutique d'Ada apparaît")
if panel then
	check(panel.OwnerName == "Ada's Shop", `panneau : propriétaire « Ada's Shop » (trouvé {panel.OwnerName})`)
	check(panel.Income == "+$7/s", `panneau : valeur exposée « +$7/s » (trouvé {panel.Income})`)
	check(panel.HP == "HP 50", `panneau : PV de la porte « HP 50 » (base du niveau de boutique 1 : 50 × 1, copie a93 ; trouvé {panel.HP})`)
	check(panel.Status == nil, `panneau : aucune ligne d'état (trouvé {panel.Status})`)
end
local gui = bob.PlayerGui:FindFirstChild("ShopInfo_" .. adaShop.Name)
check(gui ~= nil and gui:IsA("BillboardGui"), "panneau V0 rangé dans le PlayerGui du voleur (BB_ShopInfo pas livré)")
if gui then
	check(gui:FindFirstChild("OwnerName").Text == "Ada's Shop" and gui:FindFirstChild("Income").Text == "+$7/s", "textes écrits dans les éléments OwnerName et Income")
	check(gui:FindFirstChild("Status").Visible == false, "élément Status caché quand rien à dire")
	local point = gui.Adornee
	check(point ~= nil and point.Name == "ShopInfoPoint" and (point.WorldPosition - SHOPS[1].S.door).Magnitude < 12, "panneau accroché au-dessus de la porte")
end
check(PvPController.GetPanelText(bobShop) == nil, "pas de panneau sur sa propre boutique")

section("frappe et casse (6.1, point 2)")
local broken, hits = breakDoor(bob, adaShop)
check(broken, `porte d'Ada cassée en {hits} coups`)
check(adaShop:GetAttribute("StealOpen") == true, "boutique ouverte au vol (StealOpen)")
check(adaShop:GetAttribute("StealEndsAt") == nil, "a112 : plus de chrono chez un joueur (pas de StealEndsAt)")
check(#notifies(ada, "Bob smashed your shop door!") == 1, "alarme de base : Ada prévenue que Bob a cassé sa porte")
check(#remotes("HeistTimer", function(e) return e.args[1] == "Plot_1" end) == 0, "a112 : aucun chrono HeistTimer pour une boutique de joueur")
check(#remotes("HeistTimer", function(e) return e.to == ada end) == 0, "pas de chrono pour la victime")
advance(0.3)
check(PvPController.GetPanelText(adaShop) and PvPController.GetPanelText(adaShop).HP == "HP 0", "panneau : HP 0 une fois la porte cassée")
check(PvPController.GetPanelText(adaShop) and PvPController.GetPanelText(adaShop).Status == "OPEN", "panneau : « OPEN » pendant la fenêtre de vol (a112 : sans chrono)")

section("invites de vol")
standBy(bob, adaShop, 1)
advance(0.4)
local soda = displayModel(adaShop, 1)
local prompt1 = soda and PvPController.GetPrompt(soda)
check(prompt1 ~= nil and prompt1.Enabled, "dans la boutique cassée : invite « Steal » active sur la Canette de soda")
if prompt1 then
	check(prompt1.ActionText == "Steal" and prompt1.ObjectText == "Soda Can", `textes de l'invite : Steal / Soda Can (trouvé {prompt1.ActionText} / {prompt1.ObjectText})`)
	check(prompt1.HoldDuration == 1 and prompt1.MaxActivationDistance == 7.5, "maintien 1 s, portée 7,5 studs")
end
local noodles = displayModel(adaShop, 3)
local prompt3 = noodles and PvPController.GetPrompt(noodles)
check(prompt3 ~= nil and not prompt3.Enabled, "pas d'invite active sur l'objet à l'abri (coffre-fort)")
check(bob.PlayerGui:FindFirstChild("SafeTag") ~= nil, "étiquette « SAFE » au pied de l'objet à l'abri")

section("prise en 1 s (6.1, point 3)")
local startedCalls, endedCalls = {}, {}
PvPService.OnTheftStarted(function(thief, victim, itemId) table.insert(startedCalls, { thief, victim, itemId }) end)
PvPService.OnTheftEnded(function(thief, victim, itemId, result, reason) table.insert(endedCalls, { thief, victim, itemId, result, reason }) end)
local adaCashBefore, bobCashBefore = adaData.Cash, bobData.Cash
prompt1.PromptButtonHoldBegan:Fire(bob)
advance(1.0)
prompt1.Triggered:Fire(bob)
flush()
check(CarryService.IsCarrying(bob), "l'invite déclenchée après 1 s : Bob porte l'objet")
local payload = CarryService.GetPayload(bob)
check(payload and payload.Kind == "PlayerItem" and payload.ItemUid == "ada-soda" and payload.VictimUserId == ada.UserId and payload.SlotIndex == 1, "payload PlayerItem : uid, victime et présentoir d'origine")
check(payload and payload.Income == 1 and payload.Rarity == "Common", "payload : revenu 1 $/s, rareté Common")
check(#serverCalls("StealItem") == 2, "deux appels StealItem (début et fin du maintien)")
check(table.find(ClientAnimation.played, "Grab") ~= nil, "animation Grab jouée par le client")
check(adaData.Items["ada-soda"] ~= nil and adaData.Display["1"] == "ada-soda", "fuite : le profil d'Ada ne change pas avant le dépôt")
check(displayModel(adaShop, 1) == nil, "fuite : le présentoir d'Ada se vide")
check(ada:GetAttribute("Income") == 6, `fuite : l'objet ne rapporte plus à Ada (6 $/s ; trouvé {ada:GetAttribute("Income")})`)
local alertOn = theftAlerts(ada)
check(#alertOn == 2 and alertOn[1].args[1] == true and alertOn[1].args[2] == bob and alertOn[1].args[3] == nil, "a112 : à la casse, TheftAlert(true, Bob, nil) à Ada (intrusion)")
check(#alertOn == 2 and alertOn[2].args[1] == true and alertOn[2].args[2] == bob and alertOn[2].args[3] == "Z1_CanetteDeSoda", "TheftAlert(true, Bob, Z1_CanetteDeSoda) à Ada")
check(#notifies(ada, "Bob is stealing your Soda Can! Hit them with your bat!") == 1, "Notify à Ada : Bob vole sa Canette")
check(#notifies(bob, "You grabbed the Soda Can: run back to your shop!") == 1, "Notify au voleur : cours chez toi")
check(#remotes("HeistTimer", function(e) return e.to == bob end) == 0, "a112 : toujours aucun chrono pour le voleur après la prise")

section("fuite à vitesse fixe (6.1, point 4 ; Cantin 2026-11-13)")
check(SPEED_MODIFIERS[bob] and SPEED_MODIFIERS[bob].Fixed == 16 and SPEED_MODIFIERS[bob].Carry == nil, "vitesse fixe 16 (StatsService.SetFixedSpeed), sans malus Carry")
local visual = bob.Character:FindFirstChild("CarryVisual")
check(visual ~= nil and visual:FindFirstChild("StolenOutline") ~= nil, "objet au-dessus de la tête avec son contour rouge (StolenOutline)")
check(visual ~= nil and visual:FindFirstChild("BB_Carry", true) ~= nil, "étiquette BB_Carry (V0) sur l'objet porté")
check(bob:GetAttribute("Carrying") == "Common", "attribut Carrying = Common")
advance(0.3)
check(prompt1.Parent == nil or not prompt1.Enabled, "plus d'invite pour lui pendant la fuite")
-- un autre voleur, dans la boutique, ne peut pas prendre le même objet (il n'est plus sur le présentoir)
clearLog()
check(not steal(cy, adaShop, 1), "le présentoir vide ne se vole pas deux fois")
check(logHas("présentoir vide", "WARN", "server"), "refus du serveur : présentoir vide")
moveTo(cy, SHOPS[3].S.center)

section("dépôt chez soi (6.1, point 5)")
runHome(bob, adaShop)
check(not CarryService.IsCarrying(bob), "Bob entré dans sa DepositZone : plus rien sur la tête")
check(adaData.Items["ada-soda"] == nil and adaData.Display["1"] == nil, "l'objet a quitté le profil d'Ada")
local entry = bobData.Items["ada-soda"]
check(entry ~= nil and entry.Id == "Z1_CanetteDeSoda" and entry.Source == "PvP", "l'objet est à Bob, même uid, Source = PvP")
local bobSlot
for key, uid in bobData.Display do
	if uid == "ada-soda" then
		bobSlot = tonumber(key)
	end
end
check(bobSlot ~= nil, "exposé tout de suite sur un présentoir libre de Bob")
check(bob:GetAttribute("Income") == 2, `il rapporte aussitôt : 2 $/s chez Bob (trouvé {bob:GetAttribute("Income")})`)
check(bobData.Lifetime.Steals == 1 and adaData.Lifetime.Steals == 0, "Lifetime.Steals + 1 pour le voleur seulement")
advance(0.6)
check(adaShop:GetAttribute("Protection") == nil and adaShop:GetAttribute("ProtectedUntil") == nil, "a99 : victime pas immunisée (ni Protection ni ProtectedUntil)")
check(logHas("Bob a volé", "PRINT", "server") and not logHas("immunité de", "PRINT", "server"), "a99 : dépôt écrit dans la sortie, sans immunité")
local alerts = theftAlerts(ada)
check(#alerts >= 3 and alerts[#alerts].args[1] == false, "TheftAlert(false) à Ada à la fin du vol (le dernier envoyé)")
check(#notifies(bob, "You stole the Soda Can: +$1/s!") == 1, "Notify au voleur : objet volé, +$1/s")
check(#notifies(ada, "Bob stole your Soda Can!") == 1 and #notifies(ada, "protected") == 0, "Notify à la victime : volé (a99 : plus de « protected »)")
local saves = DataService.saves
check(#saves == 2 and saves[1].player == ada and saves[2].player == bob, "sauvegarde immédiate : la victime d'abord, puis le voleur")
check(saves[1].snapshot.Items["ada-soda"] == nil and saves[2].snapshot.Items["ada-soda"] ~= nil, "les deux sauvegardes portent déjà le transfert")
check(adaData.Cash == adaCashBefore and bobData.Cash == bobCashBefore, "l'argent n'est jamais volé : Cash d'Ada et de Bob inchangés")
invariants("après le vol", 4)
check(#startedCalls == 1 and startedCalls[1][1] == bob and startedCalls[1][2] == ada and startedCalls[1][3] == "Z1_CanetteDeSoda", "OnTheftStarted(voleur, victime, ItemId) : une fois, à la prise (pour DEV-042)")
check(#endedCalls == 1 and endedCalls[1][4] == "Stolen" and endedCalls[1][5] == "Deposited", "OnTheftEnded(…, \"Stolen\", \"Deposited\") : une fois, au dépôt")

section("après le vol")
moveTo(bob, SHOPS[1].S.outside + Vector3.new(0, 0, -6))
advance(0.5)
local after = PvPController.GetPanelText(adaShop)
check(after and string.find(after.Status or "", "PROTECTED", 1, true) == nil, `a99 : panneau sans « PROTECTED » (trouvé {after and after.Status})`)
check(after and after.Income == "+$6/s", "panneau : la valeur exposée d'Ada a baissé (+$6/s)")
check(not logHas("mal formé", "WARN"), "aucun envoi de remote mal formé (Net, en Studio)")
check(not logHas("tick :", "WARN"), "aucune erreur dans les boucles des services")

if VERBOSE then
	dumpLog()
end
summary("scénario flow")
