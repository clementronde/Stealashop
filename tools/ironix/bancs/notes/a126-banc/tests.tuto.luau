-- Scénario « tuto » du banc a126 (vague 38, 2026-11-14, L-085 point 4 et L-136 (a)) : étape 14 « EscapeBot »
-- (« le bot défend ») du vrai TutorialService, sur la mise en place du banc a121 (copie a121 du banc a28 jusqu'à
-- « == A. », faux BotService bot.luau) complétée par bot-extra.luau d'a124 (BOT_CHASING, IsChasing).
-- Ordre réel de BotService.Hold : « Grabbed » émis AVANT la poursuite (alert) ; joué ici par grabThenChase.

BOT_SHOP, BS = makePlot(20, -150, 100)
do
	part("Bounds", Vector3.new(-150, 7, 100), Vector3.new(64, 14, 80), BOT_SHOP, { CanCollide = false, Transparency = 1 })
	local door = new("Model", { Name = "PlotDoor" }, BOT_SHOP)
	part("Window", Vector3.new(-150, 5, 60), Vector3.new(10, 8, 0.5), door)
end
BOT_DOOR = Vector3.new(-150, 5, 60)
for n = 1, 4 do
	BOT_EXPOSED[n] = { Uid = "bot-" .. n, ItemId = "Z1_Donut", Income = 1 }
end
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
-- Comme BotService.Hold puis PvPService : « Grabbed », la poursuite (alert), puis le portage.
function grabThenChase(thief, slot)
	botTheft(thief, "Grabbed")
	BOT_CHASING[thief] = true
	carryStart(thief, { Kind = "PlayerItem", ItemUid = "bot-" .. tostring(slot), ItemId = "Z1_Donut", Rarity = "Common", Income = 1, VictimUserId = 0, SlotIndex = slot })
end
-- Étapes envoyées au client depuis l'envoi n° `from`.
function sentSince(player, from)
	local out = {}
	for i, args in stepsTo(player) do
		if i > from then
			table.insert(out, args[1])
		end
	end
	return out
end

print("== A126-T1. Config/Tutorial : étape 14 à la fin")
do
	check(#Tutorial.Steps == 14 and #Tutorial.FunnelSteps == 14, "14 étapes, 14 étapes de funnel")
	local s = Tutorial.Steps[14]
	check(s and s.Index == 14 and s.Id == "EscapeBot", "étape 14 : Index 14, Id EscapeBot")
	check(Tutorial.Steps[12].Id == "StealFromBot" and Tutorial.Steps[13].Id == "BringStolenHome", "étapes 12 et 13 inchangées")
	check(s and s.Bubble == "The bot fights back: escape with it!" and words(s.Bubble) <= Tutorial.BubbleMaxWords, "bulle V0 en anglais, 8 mots au plus")
	local f = Tutorial.FunnelSteps[14]
	check(f == "Bot semé avec son objet" and not string.find(f, "[,\"']"), "funnel 14 « Bot semé avec son objet », sans virgule ni guillemet")
end

botArrive(BOT_SHOP)
step(0.1)

print("== A126-T2. Objet pris, le bot poursuit : 12 → 14 sans passer par 13 chez le client")
do
	local zoe, data, Z = resumeAt("Zoe", 301, 12, false)
	check(TutorialService.GetStep(zoe) == 12, "reprise à l'étape 12")
	local before = #stepsTo(zoe)
	grabThenChase(zoe, 2)
	step(0.1)
	local sent = sentSince(zoe, before)
	check(TutorialService.GetStep(zoe) == 14 and stateOk(zoe, 14, nil, Z.spawn), "étape 14 : bulle de l'étape, flèche vers sa boutique " .. describe(zoe))
	check(#sent == 1 and sent[1] == 14, `un seul envoi, l'étape 14 (envois : {table.concat(sent, ", ")})`)
	check(data.Tutorial.Step == 14, `profil à 14 (rang 12,5 : plus avancé que 12) ; trouvé {data.Tutorial.Step}`)
	check(funnelCount(zoe, 12) == 1, "funnel 12 « Premier objet pris au bot » envoyé à l'étape 14")
	check(funnelCount(zoe, 14) == 0, "funnel 14 pas encore")
	check(FakeBot.IsGentle(zoe) == true, "poursuite douce pendant le tuto (IsGentle)")
	check(zoe:GetAttribute("TutorialStep") == 14, "attribut TutorialStep = 14")

	print("== A126-T3. Le bot lâche, objet en main : 14 → 13, funnel 14")
	BOT_CHASING[zoe] = nil
	step(0.6)
	check(TutorialService.GetStep(zoe) == 13 and stateOk(zoe, 13, nil, Z.spawn), "bot semé : étape 13, sa bulle " .. describe(zoe))
	check(data.Tutorial.Step == 13, "profil à 13")
	check(funnelCount(zoe, 14) == 1, "funnel 14 « Bot semé avec son objet » envoyé")

	print("== A126-T4. Le bot repart à sa poursuite : 13 → 14 (profil gardé à 13), puis frappé : 12")
	BOT_CHASING[zoe] = true
	step(0.6)
	check(TutorialService.GetStep(zoe) == 14 and data.Tutorial.Step == 13, "poursuivi de nouveau : étape 14, profil toujours à 13")
	botFail(zoe, "Bat")
	BOT_CHASING[zoe] = nil
	step(0.1)
	check(TutorialService.GetStep(zoe) == 12 and data.Tutorial.Done == false, "frappé, l'objet revole chez le bot : retour à l'étape 12 " .. describe(zoe))

	print("== A126-T5. Dépôt pendant la poursuite : fin du tuto à l'étape 13")
	grabThenChase(zoe, 3)
	step(0.1)
	check(TutorialService.GetStep(zoe) == 14, "objet repris, poursuivi : étape 14")
	botDeposit(zoe)
	step(0.1)
	check(data.Tutorial.Done == true and data.Tutorial.Step == 13 and TutorialService.IsActive(zoe) == false, `déposé chez lui : tuto fini, Step 13 (trouvé {data.Tutorial.Step})`)
	check(funnelCount(zoe, 13) == 1 and funnelCount(zoe, 14) == 1 and funnelCount(zoe, 12) == 1, "funnel 12, 13, 14 une fois chacun")
	check(FakeBot.IsGentle(zoe) == false, "tuto fini : poursuite normale")
	BOT_CHASING[zoe] = nil
end

print("== A126-T6. Objet pris sans poursuite : 12 → 13 directement (comme avant)")
do
	local yan, data, Y = resumeAt("Yan", 302, 12, false)
	botGrab(yan, 1)
	step(0.6)
	check(TutorialService.GetStep(yan) == 13 and stateOk(yan, 13, nil, Y.spawn) and data.Tutorial.Step == 13, "étape 13 sans étape 14 " .. describe(yan))
	check(funnelCount(yan, 14) == 0, "pas de funnel 14")
	botDeposit(yan)
	step(0.1)
	check(data.Tutorial.Done == true and data.Tutorial.Step == 13, "fin à 13")
end

print("== A126-T7. Reprise d'un profil sauvé à 14 : sans objet, retour à 12 ; 15 ramené à 14")
do
	local kim, data = resumeAt("Kim", 303, 14, false)
	check(TutorialService.GetStep(kim) == 12 and data.Done ~= true and data.Tutorial.Done == false, "Step 14, rien en main : étape 12 " .. describe(kim))
	local lou, dataL = resumeAt("Lou", 304, 15, false)
	check(dataL.Tutorial.Step == 14 and TutorialService.GetStep(lou) == 12, `Step 15 ramené à 14, puis étape 12 (profil {dataL.Tutorial.Step})`)
end

print("== A126-T8. Bulle du client à l'étape 14")
do
	local data = newProfile()
	data.Tutorial.Step = 12
	data.Items["al"] = { Id = "Z1_PotDeNouilles", Source = "NPC", At = 0, Zone = 1 }
	PROFILES[ALICE] = data
	SHIELD[ALICE] = false
	local plot = makePlot(61, -760, -150)
	assignPlot(ALICE, plot)
	step(0.6)
	grabThenChase(ALICE, 4)
	step(0.6)
	check(Controller.GetState().Text == Tutorial.Steps[14].Bubble, "étape 14 : " .. tostring(Controller.GetState().Text))
	BOT_CHASING[ALICE] = nil
	step(0.6)
	check(Controller.GetState().Text == Tutorial.Steps[13].Bubble, "étape 13 : " .. tostring(Controller.GetState().Text))
	botDeposit(ALICE)
	step(0.6)
end

check(not logHas("contrôle :", "WARN"), "aucune erreur dans le contrôle du tuto")
check(not logHas("mal formé", "WARN"), "aucun envoi de remote mal formé")
summary()
