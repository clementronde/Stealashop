--!nocheck
-- Scénario « theft » (a96, L-105 point 1, L-085) : 3 boutiques. Bob (1) braque le bot (3) comme un joueur :
-- panneau, porte fermée, casse, coffre-fort, prise, fuite, dépôt chez lui ; rien ne part vers le bot ni vers
-- les écouteurs de PvPService (Adrénaline, télémétrie, index), pas de Lifetime.Steals ; immunité du bot,
-- régénération, vol raté, anti-racket ; enfin le bot part pendant un vol (boutique manquante pour Dan).

startBotServer()
local Items = sharedModule("Config/Items")

local bobData = newProfile()
local bob = join("Bob", bobData)
advance(6)
local plot = BotService.GetBotPlot()
section("installation")
check(plot == SHOPS[3].model, `le bot prend la boutique 3, la dernière libre (trouvé {plot and plot.Name})`)
local cyData = newProfile()
local cy = join("Cy", cyData)
check(shopOf(bob) == SHOPS[1].model and shopOf(cy) == SHOPS[2].model, "Bob et Cy reçoivent les boutiques 1 et 2, jamais celle du bot")
startClient(bob)
local theftEvents, changed = {}, {}
BotService.OnTheft(function(thief, itemId, stage)
	table.insert(theftEvents, { thief = thief, itemId = itemId, stage = stage })
end)
BotService.OnChanged(function(p)
	table.insert(changed, p or false)
end)
local startedCalls, endedCalls = {}, {}
PvPService.OnTheftStarted(function(...)
	table.insert(startedCalls, { ... })
end)
PvPService.OnTheftEnded(function(...)
	table.insert(endedCalls, { ... })
end)
advance(1)
local S = SHOPS[3].S
local windowId = windowIdOf(plot)

section("repérage : panneau de la boutique du bot")
moveTo(bob, S.outside + S.front * 6)
advance(0.5)
local panel = PvPController.GetPanelText(plot)
check(panel ~= nil, "à moins de 15 studs : panneau de la boutique du bot")
if panel then
	check(panel.OwnerName == "Bot's Shop", `panneau : « Bot's Shop » (trouvé {panel.OwnerName})`)
	check(panel.Income == "+$4/s", `panneau : valeur exposée « +$4/s » (trouvé {panel.Income})`)
	check(panel.HP == "HP 50", `panneau : porte « HP 50 » (trouvé {panel.HP})`)
	check(panel.Status == nil, `panneau : aucune ligne d'état (trouvé {panel.Status})`)
end

section("porte intacte : on ne rentre pas")
moveTo(bob, S.center)
advance(0.3)
check(not insideBox(boundsOf(plot), rootOf(bob).Position), "porte intacte : Bob est sorti de la boutique du bot")
check(#notifies(bob, "Only the owner can be inside this shop.") == 1, "message « Only the owner… »")

section("casse de la porte")
local broken, hits = breakDoor(bob, plot)
check(broken and hits <= 6, `porte du bot cassée en {hits} coups (50 PV, 10 dégâts)`)
check(plot:GetAttribute("StealOpen") == true, "boutique du bot ouverte au vol (StealOpen)")
check(#remotes("Notify", function(e)
	return string.find(e.args[1], "smashed your shop door", 1, true) ~= nil
end) == 0, "aucune alarme de base envoyée (le bot n'est pas un joueur)")
check(#remotes("HeistTimer", function(e)
	return e.to == bob and e.args[1] == windowId and e.args[2] > 0
end) == 1, "chrono de 10 s montré au voleur")

section("coffre-fort et invites")
standBy(bob, plot, 2)
advance(0.4)
local model2 = displayModel(plot, 2)
local prompt2 = model2 and PvPController.GetPrompt(model2)
check(prompt2 ~= nil and prompt2.Enabled, "invite « Steal » active sur un objet du bot")
local model1 = displayModel(plot, 1)
local prompt1 = model1 and PvPController.GetPrompt(model1)
check(prompt1 ~= nil and not prompt1.Enabled, "pas d'invite active sur l'objet à l'abri (présentoir 1)")
check(not steal(bob, plot, 1), "objet à l'abri : le serveur refuse la prise")
check(#notifies(bob, "This item is in the safe") >= 1, "message du coffre-fort")

section("prise")
local exposed = BotService.GetExposed(plot)
local uid2, item2 = exposed[2].Uid, exposed[2].ItemId
check(steal(bob, plot, 2), "Bob prend l'objet du présentoir 2 en 1 s")
local payload = CarryService.GetPayload(bob)
check(payload and payload.Kind == "PlayerItem" and payload.ItemUid == uid2 and payload.VictimUserId == 0 and payload.SlotIndex == 2, "payload PlayerItem, VictimUserId = 0 (le bot)")
check(PvPService.GetTheft(bob) == nil and not PvPService.IsThiefOf(bob, cy), "GetTheft : nil pour un vol au bot (Adrénaline et alertes : vrais joueurs seulement)")
check(#botModels(plot) == 3 and plot:GetAttribute("BotIncome") == 3, "le présentoir 2 du bot se vide, valeur exposée 3 $/s")
check(theftEvents[1] and theftEvents[1].thief == bob and theftEvents[1].itemId == item2 and theftEvents[1].stage == "Grabbed", "BotService.OnTheft(Bob, objet, Grabbed)")
check(#remotes("TheftAlert") == 0, "aucun TheftAlert (personne à prévenir)")
check(#notifies(bob, "You grabbed the") == 1, "Notify au voleur : cours chez toi")
check(#startedCalls == 0, "OnTheftStarted pas appelé (Adrénaline, télémétrie : vrais joueurs seulement)")

section("dépôt chez soi")
runHome(bob, plot)
check(not CarryService.IsCarrying(bob), "Bob dans sa DepositZone : plus rien sur la tête")
local entry = bobData.Items[uid2]
check(entry ~= nil and entry.Id == item2 and entry.Source == "PvP" and entry.Zone == 1 and entry.Mutation == nil, "l'objet est à Bob : même uid, Source = PvP, zone 1, sans mutation")
local placed = false
for _, uid in bobData.Display do
	if uid == uid2 then
		placed = true
	end
end
check(placed and bob:GetAttribute("Income") == 1, `exposé tout de suite chez Bob, 1 $/s (trouvé {bob:GetAttribute("Income")})`)
check(bobData.Lifetime.Steals == 0, "un vol au bot ne compte pas dans Lifetime.Steals (classements)")
check(#startedCalls == 0 and #endedCalls == 0, "ni OnTheftStarted ni OnTheftEnded")
check(#DataService.saves == 1 and DataService.saves[1].player == bob and DataService.saves[1].snapshot.Items[uid2] ~= nil, "une sauvegarde, celle du voleur, avec l'objet")
check(theftEvents[2] and theftEvents[2].stage == "Stolen" and theftEvents[2].itemId == item2, "BotService.OnTheft(Bob, objet, Stolen)")
check(#notifies(bob, "You stole the") == 1, "Notify au voleur : objet volé")
check(#remotes("TheftAlert") == 0, "toujours aucun TheftAlert")
check(BotService.GetExposed(plot)[2] == nil and BotService.GetImmunity(plot) > 20, `présentoir 2 vide, bot immunisé 30 s (reste {BotService.GetImmunity(plot)} s)`)
advance(0.6)
check(plot:GetAttribute("Protection") == "Immune", "PvPService publie l'immunité du bot (Protection = Immune)")
invariants("après le vol", 1)

section("immunité du bot")
local waited = 0
while WindowService.IsBroken(windowId) and waited < 40 do
	advance(0.5)
	waited += 0.5
end
check(not WindowService.IsBroken(windowId), "porte reconstruite 30 s après la casse")
check(BotService.GetImmunity(plot) > 0, "le bot est encore immunisé")
moveTo(bob, S.outside + S.front * -3)
local tool = giveTool(bob)
fireAs(bob, "HitWindow", windowId)
advance(0.2)
tool:Destroy()
check(#notifies(bob, "This shop was just robbed: protected for") >= 1, "coup refusé pendant l'immunité, message au frappeur")
check(#remotes("WindowHit", function(e)
	return e.args[1] == windowId and e.t > now() - 0.5
end) == 0, "aucun dégât sur la porte immunisée")

section("régénération")
advance(45)
local back = BotService.GetExposed(plot)[2]
check(back ~= nil and back.Uid ~= uid2, "60 s après le dépôt, un autre objet revient sur le présentoir 2 (uid neuf)")
check(back and Items.ById[back.ItemId].Rarity == "Common" and Items.ById[back.ItemId].Zone == 1, "un Commun de la zone 1")
check(#botModels(plot) == 4 and plot:GetAttribute("BotIncome") == 4, "4 objets exposés, 4 $/s")
check(BotService.GetImmunity(plot) == 0 and plot:GetAttribute("Protection") == nil, "immunité finie")

section("vol raté : l'objet revient au bot")
check(breakDoor(bob, plot), "porte du bot cassée de nouveau")
local uid3 = BotService.GetExposed(plot)[3].Uid
check(steal(bob, plot, 3), "Bob prend l'objet du présentoir 3")
walkTo(bob, S.outside)
CarryService.Fail(bob, "Bat")
flush()
check(not CarryService.IsCarrying(bob), "coup de batte : Bob ne porte plus rien")
check(BotService.GetExposed(plot)[3] and BotService.GetExposed(plot)[3].Uid == uid3 and displayModel(plot, 3) ~= nil, "l'objet est revenu sur le présentoir 3 du bot")
check(theftEvents[#theftEvents].stage == "Returned", "BotService.OnTheft(…, Returned)")
check(#notifies(bob, "went back to its owner") == 1, "Notify au voleur : objet rendu")
check(bobData.Items[uid3] == nil and BotService.GetImmunity(plot) == 0, "rien gagné, pas d'immunité après un vol raté")

section("anti-racket : un joueur trop riche ne pille pas le bot")
local mythic
for _, item in Items.List do
	if item.Rarity == "Mythic" and item.Zone then
		mythic = item
		break
	end
end
addItem(cyData, "cy-mythic", mythic.Id, 1)
cyData.Items["cy-mythic"].Zone = mythic.Zone
advance(1.2)
check(cy:GetAttribute("ExposedIncome") > 40, `Cy expose plus de 40 $/s (trouvé {cy:GetAttribute("ExposedIncome")})`)
local cyBroke = breakDoor(cy, plot, 12)
check(not cyBroke, "Cy ne peut pas frapper la porte du bot (anti-racket)")
check(#notifies(cy, "This shop is too small for you to rob.") >= 1, "message de l'anti-racket")

section("le bot part pendant un vol : boutique manquante pour Dan")
local waitedDoor = 0
while WindowService.IsBroken(windowId) and waitedDoor < 40 do
	advance(0.5)
	waitedDoor += 0.5
end
check(breakDoor(bob, plot), "porte du bot cassée")
local uid4 = BotService.GetExposed(plot)[4].Uid
check(steal(bob, plot, 4), "Bob prend l'objet du présentoir 4")
local danData = newProfile()
local dan = join("Dan", danData)
check(shopOf(dan) == plot, "3 vrais joueurs, 3 boutiques : Dan reçoit tout de suite celle du bot")
botLeftClean(plot, "départ pour Dan")
check(changed[#changed] == false, "BotService.OnChanged(nil) au départ")
advance(0.3)
check(not CarryService.IsCarrying(bob) and bobData.Items[uid4] == nil, "le vol en cours échoue (VictimLeft) : rien pour Bob")
check(plot:GetAttribute("StealOpen") == nil and not WindowService.IsBroken(windowId), "fenêtre de vol fermée, porte refaite")
check(doorMaxHP(plot) == 500 or doorMaxHP(plot) == 50, `porte de Dan : 50 × ses 10 dégâts avant a93, 50 (niveau 1) après (trouvé {doorMaxHP(plot)})`)
check(signText(plot) == "Dan's Shop", "panneau « Dan's Shop »")
check(#visualsOn(plot) == 0, "aucun objet du bot chez Dan")
check(not insideBox(boundsOf(plot), rootOf(bob).Position), "Bob est sorti de la boutique de Dan")
advance(10)
check(BotService.GetBotPlot() == nil, "plus aucune boutique libre : le bot ne revient pas")
invariants("fin", 2) -- l objet volé par Bob et le Mythique de Cy

check(not logHas("tick :", "WARN"), "aucune erreur dans les boucles des services")
check(not logHas("mal formé", "WARN"), "aucun envoi de remote mal formé (Net, en Studio)")
check(not logHas("n'est plus le même", "WARN"), "aucune anomalie de transfert")
check(not logHas("[BotService]", "WARN"), "aucun avertissement de BotService")

if VERBOSE then
	dumpLog()
end
summary("scénario theft")
