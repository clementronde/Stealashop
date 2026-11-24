-- Scénario « tuto » (a124, vague 37) : vrai TutorialService sur la mise en place du banc a121 (faux BotService
-- d'a121 complété par bot-extra.luau). TutorialService remplace BotService.IsGentle (tuto en cours) et affiche
-- la bulle BotChase aux étapes 12 et 13 pendant que le bot poursuit le joueur ; la flèche ne change pas.

-- Boutique du bot et reprise à une étape : comme le banc a121 (tests.a121.luau).
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

print("== A124-A. Bulle BotChase (Config/Tutorial)")
do
	local text = Tutorial.Hints.BotChase
	check(text == "The bot is chasing you: run!", `Hints.BotChase = « The bot is chasing you: run! » (trouvé {tostring(text)})`)
	check(text ~= nil and words(text) <= Tutorial.BubbleMaxWords, "8 mots au plus")
end

print("== A124-B. IsGentle remplacé par TutorialService")
botArrive(BOT_SHOP)
step(0.1)
do
	check(type(FakeBot.IsGentle) == "function", "TutorialService pose BotService.IsGentle")
	local zoe, data, Z = resumeAt("Zoe", 201, 12, false)
	local nina = makePlayer("Nina", 202, Vector3.new(-400, 3, 300)) -- sans tuto
	step(0.1)
	check(FakeBot.IsGentle(zoe) == true, "Zoe fait son tuto : poursuite douce")
	check(FakeBot.IsGentle(nina) == false, "Nina, sans tuto : poursuite normale")

	print("== A124-C. Étape 12 : bulle pendant la poursuite")
	check(stateOk(zoe, 12, "AnyoneCanRob", BOT_DOOR), "étape 12, pas poursuivie, porte fermée : indice AnyoneCanRob (a169) " .. describe(zoe))
	BOT_CHASING[zoe] = true
	step(0.6)
	check(stateOk(zoe, 12, "BotChase", BOT_DOOR), "poursuivie (casse de la porte) : bulle BotChase, flèche inchangée " .. describe(zoe))
	check(zoe:GetAttribute("TutorialHint") == "BotChase", "attribut TutorialHint = BotChase")

	-- a126 (vague 38) : poursuivie avec l'objet, étape 14 « le bot défend » (sa bulle) au lieu de 13 + BotChase.
	print("== A124-D. Objet pris pendant la poursuite : étape 14, puis 13 quand le bot lâche")
	botGrab(zoe, 2)
	step(0.1)
	check(stateOk(zoe, 14, nil, Z.spawn), "objet pris, poursuivie : étape 14, bulle de l'étape, flèche vers sa boutique " .. describe(zoe))
	BOT_CHASING[zoe] = nil
	step(0.6)
	check(stateOk(zoe, 13, nil, Z.spawn), "lâchée par le bot : étape 13, sa bulle " .. describe(zoe))
	BOT_CHASING[zoe] = true
	botFail(zoe, "Bat")
	step(0.1)
	check(stateOk(zoe, 12, "BotChase", nil) or TutorialService.GetStep(zoe) == 12, "frappée : retour à l'étape 12 " .. describe(zoe))
	BOT_CHASING[zoe] = nil
	botGrab(zoe, 3)
	step(0.1)
	botDeposit(zoe)
	step(0.1)
	check(data.Tutorial.Done == true and stateOk(zoe, 13, "ProtectShop", nil), "objet ramené : tuto fini, indice ProtectShop (a169) " .. describe(zoe))
	step(Tutorial.MessageDuration + 0.6) -- a169 : message de fin, puis plus de tuto
	check(TutorialService.IsActive(zoe) == false, "puis plus de tuto en cours")
	check(FakeBot.IsGentle(zoe) == false, "tuto fini : poursuite normale")
end

print("== A124-E. Sans IsChasing (ancien BotService) : aucune bulle")
do
	FakeBot.IsChasing = nil
	local yan, _, Y = resumeAt("Yan", 203, 13, false)
	botGrab(yan, 1)
	step(0.6)
	check(stateOk(yan, 13, nil, Y.spawn), "étape 13 sans IsChasing : bulle de l'étape " .. describe(yan))
end
check(not logHas("contrôle :", "WARN"), "aucune erreur dans le contrôle du tuto")
summary()
