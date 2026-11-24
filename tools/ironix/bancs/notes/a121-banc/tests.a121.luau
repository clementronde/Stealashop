-- Banc a121 (vague 36, 2026-11-13, L-085 point 4) : étapes 11 à 13 du tuto, le vol sur la boutique du bot.
-- Lu après la mise en place du banc a28 (copie a121) et le faux BotService (bot.luau).

-- Boutique du bot : parcelle du banc a28, plus une porte PlotDoor/Window à l'avant et un volume Bounds.
BOT_SHOP, BS = makePlot(20, -150, 100)
do
	part("Bounds", Vector3.new(-150, 7, 100), Vector3.new(64, 14, 80), BOT_SHOP, { CanCollide = false, Transparency = 1 })
	local door = new("Model", { Name = "PlotDoor" }, BOT_SHOP)
	part("Window", Vector3.new(-150, 5, 60), Vector3.new(10, 8, 0.5), door)
end
BOT_DOOR = Vector3.new(-150, 5, 60)
NEAR_DOOR = Vector3.new(-150, 3, 50) -- 10 studs de la porte, dehors
INSIDE = Vector3.new(-150, 3, 110)
-- Présentoirs du bot (makePlot) : DisplaySlot_0n en (x - 24 + 4n, 3.5, z + 20).
function botSlot(n)
	return Vector3.new(-150 - 24 + 4 * n, 3.5, 120)
end
for n = 1, 4 do
	BOT_EXPOSED[n] = { Uid = "bot-" .. n, ItemId = "Z1_Donut", Income = 1 }
end

-- Joueur qui reprend à l'étape `stepIndex` (Done = false), sur sa propre parcelle.
NEXT_PLOT = 30
function resumeAt(name, userId, stepIndex, shield)
	NEXT_PLOT += 1
	local plot, P = makePlot(NEXT_PLOT, -300 - 10 * NEXT_PLOT, -150)
	local player = makePlayer(name, userId, P.spawn)
	local data = newProfile()
	data.Tutorial.Step = stepIndex
	data.Items["x" .. userId] = { Id = "Z1_PotDeNouilles", Source = "NPC", At = 0, Zone = 1 }
	PROFILES[player] = data
	SHIELD[player] = shield
	assignPlot(player, plot)
	step(0.1)
	return player, data, P
end

print("== A121-A. Config/Tutorial : 3 étapes à la fin")
do
	check(#Tutorial.Steps == 13 and #Tutorial.FunnelSteps == 13, "13 étapes, 13 étapes de funnel")
	local ids = {}
	for i, s in Tutorial.Steps do
		ids[i] = s.Id
		check(s.Index == i, `étape {i} : Index = {i}`)
	end
	check(ids[1] == "ArriveAtPlot" and ids[9] == "GoToZone2" and ids[10] == "ShieldEnd", "10 premières étapes inchangées")
	check(ids[11] == "GoToBotShop" and ids[12] == "StealFromBot" and ids[13] == "BringStolenHome", "11 GoToBotShop, 12 StealFromBot, 13 BringStolenHome")
	for i = 11, 13 do
		local bubble = Tutorial.Steps[i].Bubble
		check(bubble ~= nil and words(bubble) <= Tutorial.BubbleMaxWords, `bulle de l'étape {i} : 8 mots au plus (« {tostring(bubble)} »)`)
	end
	check(Tutorial.Steps[11].Bubble == "Steal from another shop!", "bulle 11 : « Steal from another shop! » (brief)")
	for i = 11, 13 do
		check(not string.find(Tutorial.FunnelSteps[i], "[,\"']"), `funnel {i} sans virgule, guillemet ni apostrophe`)
	end
	check(Tutorial.BotShopRadius == 15 and Tutorial.BotWait == 8, "V0 : BotShopRadius 15 studs, BotWait 8 s")
end

print("== A121-B. Bot présent : 10 → 11 → 12 → 13 → fin, avec un vol raté")
botArrive(BOT_SHOP)
step(0.1)
do
	local zoe, data, Z = resumeAt("Zoe", 101, 10, false)
	check(stateOk(zoe, 10, "ShieldEnd", nil), "étape 10, bouclier fini : ShieldEndMessage d'abord " .. describe(zoe))
	step(8.6)
	check(data.Tutorial.Done == false and TutorialService.GetStep(zoe) == 11 and data.Tutorial.Step == 11, "message fini, bot présent : étape 11 (profil à 11), pas fini")
	check(stateOk(zoe, 11, nil, BOT_DOOR), "étape 11 : flèche vers la porte du bot " .. describe(zoe))
	check(zoe:GetAttribute("TutorialStep") == 11, "attribut TutorialStep = 11")
	moveTo(zoe, Vector3.new(-150, 3, 30)) -- 30 studs de la porte
	step(0.6)
	check(TutorialService.GetStep(zoe) == 11, "à 30 studs de la porte : toujours l'étape 11")
	moveTo(zoe, NEAR_DOOR)
	step(0.6)
	check(TutorialService.GetStep(zoe) == 12 and data.Tutorial.Step == 12, "à 10 studs de la porte : étape 12")
	check(stateOk(zoe, 12, nil, BOT_DOOR), "étape 12, porte fermée : flèche vers la porte " .. describe(zoe))
	check(funnelCount(zoe, 11) == 1, "funnel 11 « Boutique du bot atteinte » envoyé")
	BOT_SHOP:SetAttribute("StealOpen", true)
	BOT_SHOP:SetAttribute("SafeSlots", "4")
	step(0.6)
	check(stateOk(zoe, 12, nil, botSlot(3)), "porte cassée : flèche vers l'objet volable le plus proche (présentoir 4 à l'abri exclu) " .. describe(zoe))
	moveTo(zoe, INSIDE)
	BOT_SHOP:SetAttribute("StealOpen", nil)
	step(0.6)
	check(stateOk(zoe, 12, nil, botSlot(3)), "dans la boutique du bot (porte refaite) : flèche vers l'objet " .. describe(zoe))
	botGrab(zoe, 3)
	step(0.1)
	check(TutorialService.GetStep(zoe) == 13 and data.Tutorial.Step == 13, "objet du bot pris : étape 13")
	check(stateOk(zoe, 13, nil, Z.spawn), "étape 13 : flèche vers sa boutique " .. describe(zoe))
	check(funnelCount(zoe, 12) == 1, "funnel 12 « Premier objet pris au bot » envoyé")
	botFail(zoe, "Bat")
	step(0.1)
	check(TutorialService.GetStep(zoe) == 12 and data.Tutorial.Step == 13 and data.Tutorial.Done == false, "coup de batte : objet perdu, retour à l'étape 12 (profil garde 13)")
	check(stateOk(zoe, 12, nil, botSlot(3)), "retour à 12 : flèche vers l'objet " .. describe(zoe))
	botGrab(zoe, 2)
	step(0.1)
	check(TutorialService.GetStep(zoe) == 13, "objet repris : étape 13")
	check(funnelCount(zoe, 11) == 1 and funnelCount(zoe, 12) == 1, "funnel 11 et 12 pas renvoyés")
	botDeposit(zoe)
	step(0.1)
	check(data.Tutorial.Done == true and data.Tutorial.Step == 13 and stateOk(zoe, 0, nil, nil), "objet déposé chez lui : tuto fini (Step 13, Done) " .. describe(zoe))
	check(TutorialService.IsActive(zoe) == false and zoe:GetAttribute("TutorialStep") == 0, "plus de tuto en cours")
	check(funnelCount(zoe, 13) == 1, "funnel 13 « Objet du bot ramené chez soi » envoyé")
	-- Un autre vol après la fin : rien.
	local before = #stepsTo(zoe)
	botGrab(zoe, 1)
	step(0.6)
	botDeposit(zoe)
	step(0.6)
	check(#stepsTo(zoe) == before and funnelCount(zoe, 13) == 1, "après la fin : aucun envoi, aucun funnel")
end

print("== A121-C. Bot absent à la fin de l'étape 10 : le tuto finit comme avant")
botLeave()
step(0.1)
do
	local amy, data = resumeAt("Amy", 102, 10, false)
	check(stateOk(amy, 10, "ShieldEnd", nil), "étape 10 : ShieldEndMessage " .. describe(amy))
	step(8.6)
	check(data.Tutorial.Done == true and data.Tutorial.Step == 10 and stateOk(amy, 0, nil, nil), "sans bot : fini à l'étape 10 (Step 10, Done) " .. describe(amy))
	check(funnelCount(amy, 11) == 0, "aucun funnel 11")
end

print("== A121-D. Le bot part pendant l'étape 12 : tuto fini")
botArrive(BOT_SHOP)
step(0.1)
do
	local ben, data = resumeAt("Ben", 103, 10, false)
	step(8.6)
	moveTo(ben, NEAR_DOOR)
	step(0.6)
	check(TutorialService.GetStep(ben) == 12, "étape 12")
	botLeave()
	step(0.1)
	check(data.Tutorial.Done == true and data.Tutorial.Step == 12 and stateOk(ben, 0, nil, nil), "bot parti : tuto fini, Step garde 12 " .. describe(ben))
	botArrive(BOT_SHOP)
	step(0.6)
	check(TutorialService.IsActive(ben) == false, "le bot revient : le tuto ne reprend pas")
end

print("== A121-E. Le bot part pendant l'étape 13 (objet tenu) : tuto fini")
do
	local cid, data = resumeAt("Cid", 104, 10, false)
	step(8.6)
	botGrab(cid, 1)
	step(0.1)
	check(TutorialService.GetStep(cid) == 13, "objet pris dès l'étape 11 : 11 → 12 → 13 d'un coup")
	check(funnelCount(cid, 11) == 1 and funnelCount(cid, 12) == 1, "funnel 11 et 12 envoyés")
	-- PvPService : le vol échoue (« VictimLeft »), BotService.Release ne renvoie rien (le bot est parti).
	carryEnd(cid, "Failed", "VictimLeft")
	botLeave()
	step(0.1)
	check(data.Tutorial.Done == true and data.Tutorial.Step == 13 and stateOk(cid, 0, nil, nil), "bot parti : fini, Step 13 " .. describe(cid))
	check(funnelCount(cid, 13) == 0, "funnel 13 pas envoyé (rien déposé)")
end

print("== A121-F. Profil déjà fini : rien ne reprend, même avec un bot")
botArrive(BOT_SHOP)
step(0.1)
do
	NEXT_PLOT += 1
	local plot, P = makePlot(NEXT_PLOT, -300 - 10 * NEXT_PLOT, -150)
	local dee = makePlayer("Dee", 105, P.spawn)
	local data = newProfile()
	data.Tutorial.Step = 10
	data.Tutorial.Done = true
	data.Items["d1"] = { Id = "Z1_PotDeNouilles", Source = "NPC", At = 0, Zone = 1 }
	PROFILES[dee] = data
	SHIELD[dee] = false
	assignPlot(dee, plot)
	step(9)
	check(TutorialService.IsActive(dee) == false and #stepsTo(dee) == 0 and data.Tutorial.Step == 10, "Done = true, Step 10 : aucun envoi, Step inchangé")
	moveTo(dee, NEAR_DOOR)
	botGrab(dee, 1)
	step(0.6)
	botDeposit(dee)
	step(0.6)
	check(#stepsTo(dee) == 0 and #funnelOf(dee) == 0 and data.Tutorial.Done == true, "vol au bot d'un joueur fini : rien")
	-- Ancien joueur (Step 0, objets) : marqué fini sans tuto, comme avant.
	NEXT_PLOT += 1
	local plot2, P2 = makePlot(NEXT_PLOT, -300 - 10 * NEXT_PLOT, -150)
	local old = makePlayer("Old", 106, P2.spawn)
	local dataO = newProfile()
	dataO.Items["o1"] = { Id = "Z1_Donut", Source = "NPC", At = 0, Zone = 1 }
	PROFILES[old] = dataO
	assignPlot(old, plot2)
	step(0.6)
	check(dataO.Tutorial.Done == true and dataO.Tutorial.Step == 0 and #stepsTo(old) == 0, "ancien joueur : fini sans tuto (Step 0)")
end

print("== A121-G. Reprises aux étapes 11 à 13")
do
	local eve, dataE = resumeAt("Eve", 107, 12, true)
	check(TutorialService.GetStep(eve) == 12 and stateOk(eve, 12, nil, BOT_DOOR), "reprise à 12 : flèche vers la porte " .. describe(eve))
	local fox, dataF = resumeAt("Fox", 108, 13, true)
	check(TutorialService.GetStep(fox) == 12 and dataF.Tutorial.Step == 13 and dataF.Tutorial.Done == false, "reprise à 13 sans objet tenu (vol raté au départ) : étape 12, profil garde 13")
	local gus, dataG = resumeAt("Gus", 109, 11, true)
	check(TutorialService.GetStep(gus) == 11 and stateOk(gus, 11, nil, BOT_DOOR), "reprise à 11 : étape 11 " .. describe(gus))
	-- Un vol fait AVANT l'étape 11 ne termine pas le tuto.
	local hip, dataH = resumeAt("Hip", 110, 10, true) -- bouclier encore actif
	moveTo(hip, INSIDE)
	botGrab(hip, 1)
	step(0.6)
	botDeposit(hip)
	step(0.6)
	check(TutorialService.GetStep(hip) == 10 and dataH.Tutorial.Done == false, "vol au bot à l'étape 10 : rien ne bouge")
	moveTo(hip, Vector3.new(-150, 3, -20))
	SHIELD[hip] = false
	step(0.6)
	check(stateOk(hip, 10, "ShieldEnd", nil), "bouclier fini : message " .. describe(hip))
	step(8.6)
	check(TutorialService.GetStep(hip) == 11 and dataH.Tutorial.Done == false, "étape 11 : le vol d'avant ne compte pas")
	check(funnelCount(hip, 13) == 0, "funnel 13 pas envoyé pour le vol d'avant")
end

print("== A121-H. Reprise sans bot : attente BotWait, puis fin ; bot arrivé à temps : on continue")
botLeave()
step(0.1)
do
	local ian, dataI = resumeAt("Ian", 111, 11, true)
	check(TutorialService.IsActive(ian) and TutorialService.GetStep(ian) == 11, "reprise à 11 sans bot : attente du bot")
	check(stateOk(ian, 11, nil, nil), "pendant l'attente : bulle de l'étape, pas de flèche " .. describe(ian))
	local jo, dataJ = resumeAt("Jo", 112, 12, true)
	step(3)
	botArrive(BOT_SHOP)
	step(0.1)
	check(TutorialService.GetStep(ian) == 11 and stateOk(ian, 11, nil, BOT_DOOR), "bot arrivé 3 s plus tard : étape 11, flèche vers sa porte " .. describe(ian))
	step(6)
	check(TutorialService.IsActive(ian) and dataI.Tutorial.Done == false, "après BotWait, bot là : le tuto continue")
	botLeave()
	step(0.1)
	check(dataI.Tutorial.Done == true and dataJ.Tutorial.Done == true, "bot parti après l'attente : les deux finissent")
	-- Personne de bot du tout : fin après BotWait s.
	local kat, dataK = resumeAt("Kat", 113, 13, true)
	step(5)
	check(TutorialService.IsActive(kat) and dataK.Tutorial.Done == false, "5 s sans bot : attente encore")
	step(3.6)
	check(dataK.Tutorial.Done == true and dataK.Tutorial.Step == 13 and stateOk(kat, 0, nil, nil), "8 s sans bot : tuto fini, Step 13 gardé " .. describe(kat))
end

print("== A121-I. Passer et vol d'un vrai joueur")
botArrive(BOT_SHOP)
step(0.1)
do
	local lea, dataL = resumeAt("Lea", 114, 12, true)
	-- Portage d'un objet volé à un vrai joueur (VictimUserId ≠ 0) : ne compte pas.
	carryStart(lea, { Kind = "PlayerItem", ItemUid = "p1", ItemId = "Z1_Donut", Rarity = "Common", Income = 1, VictimUserId = 999, SlotIndex = 1 })
	step(0.6)
	check(TutorialService.GetStep(lea) == 12, "objet volé à un vrai joueur : toujours l'étape 12")
	carryEnd(lea, "Consumed", "Deposited")
	step(0.1)
	fireAsClient(lea, "TutorialSkip")
	step(0.1)
	check(dataL.Tutorial.Done == true and dataL.Tutorial.Step == 12 and stateOk(lea, 0, nil, nil), "Passer à l'étape 12 : accepté " .. describe(lea))
end

print("== A121-J. Client : bulles des étapes 11 à 13")
do
	local data = newProfile()
	data.Tutorial.Step = 11
	data.Items["al"] = { Id = "Z1_PotDeNouilles", Source = "NPC", At = 0, Zone = 1 }
	PROFILES[ALICE] = data
	SHIELD[ALICE] = true
	local plot = makePlot(60, -700, -150)
	assignPlot(ALICE, plot)
	step(0.6)
	check(Controller.GetState().Text == "Steal from another shop!", "étape 11 : « Steal from another shop! » (" .. tostring(Controller.GetState().Text) .. ")")
	moveTo(ALICE, NEAR_DOOR)
	step(0.6)
	check(Controller.GetState().Text == Tutorial.Steps[12].Bubble, "étape 12 : " .. tostring(Controller.GetState().Text))
	botGrab(ALICE, 1)
	step(0.6)
	check(Controller.GetState().Text == Tutorial.Steps[13].Bubble, "étape 13 : " .. tostring(Controller.GetState().Text))
	botDeposit(ALICE)
	step(0.6)
	check(Controller.GetState().Shown == false and data.Tutorial.Done == true, "fin : bulle cachée")
end

print("== A121-L. Sortie")
check(not logHas("mal formé", "WARN"), "aucun envoi de remote mal formé")
check(not logHas("contrôle :", "WARN", "server"), "aucune erreur dans le contrôle régulier")
check(not logHas("accroche", "WARN"), "aucune accroche refusée")
if VERBOSE then
	dumpLog()
end
summary()
