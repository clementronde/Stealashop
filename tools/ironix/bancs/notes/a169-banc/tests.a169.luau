-- Banc a169 (vague 52, 2026-11-15, lot C de la vague 48 : le tuto sans colis ; L-163 : bulles AnyoneCanRob et ProtectShop).
-- Lu après la mise en place de la copie a169 du banc a28 (jusqu'à « == A. » : objet porté NPCItem, stowBox, placeBox,
-- openBox = « Take ») et le faux BotService du banc a121 (bot.luau) + bot-extra.luau d'a124.
--   A. Config/Tutorial : mêmes 14 étapes et mêmes Id, bulles 3 et 4 du rayon, indices du colis retirés, indices nouveaux ;
--   B. un profil neuf fait tout le tuto avec un objet, de l'étape 1 à la fin (bot volé, ProtectShop, tout caché) ;
--   C. profils sauvegardés à chaque étape 1 à 14 (et deux anciens à 4 avec un colis) : une étape valable, un indice connu ;
--   D. client : chaque indice envoyé par le serveur a son texte.

-- Boutique du bot (comme le banc a121) : parcelle, porte PlotDoor/Window à l'avant et volume Bounds.
BOT_SHOP, BS = makePlot(20, -150, 100)
do
	part("Bounds", Vector3.new(-150, 7, 100), Vector3.new(64, 14, 80), BOT_SHOP, { CanCollide = false, Transparency = 1 })
	local door = new("Model", { Name = "PlotDoor" }, BOT_SHOP)
	part("Window", Vector3.new(-150, 5, 60), Vector3.new(10, 8, 0.5), door)
end
BOT_DOOR = Vector3.new(-150, 5, 60)
NEAR_DOOR = Vector3.new(-150, 3, 50)
INSIDE = Vector3.new(-150, 3, 110)
function botSlot(n)
	return Vector3.new(-150 - 24 + 4 * n, 3.5, 120)
end
for n = 1, 4 do
	BOT_EXPOSED[n] = { Uid = "bot-" .. n, ItemId = "Z1_Donut", Income = 1 }
end
NEXT_PLOT = 30
-- Joueur qui reprend à l'étape `stepIndex` (Done = false) ; `fill(data)` remplit le profil avant l'arrivée.
function resumeWith(name, userId, stepIndex, fill)
	NEXT_PLOT += 1
	local plot, P = makePlot(NEXT_PLOT, -300 - 10 * NEXT_PLOT, -150)
	local player = makePlayer(name, userId, P.spawn)
	local data = newProfile()
	data.Tutorial.Step = stepIndex
	if fill then
		fill(data)
	end
	PROFILES[player] = data
	SHIELD[player] = true
	assignPlot(player, plot)
	step(0.1)
	return player, data, P
end
SENT_HINTS = {}
function noteHint(player)
	local last = lastStep(player)
	if last and last[2] then
		SENT_HINTS[last[2]] = true
	end
end

botArrive(BOT_SHOP)
step(0.1)

print("== A169-A. Config/Tutorial")
do
	local ids = {}
	local noShelf = true
	for i, s in Tutorial.Steps do
		ids[i] = s.Id
		if (s :: any).ShelfBubble ~= nil then
			noShelf = false
		end
	end
	check(#Tutorial.Steps == 14 and table.concat(ids, ",") == "ArriveAtPlot,HitWindow,GrabBox,PlaceBox,DisplayItem,Train,BuyTool,BuyAura,GoToZone2,ShieldEnd,GoToBotShop,StealFromBot,BringStolenHome,EscapeBot", "14 étapes, mêmes numéros et mêmes Id (GrabBox, PlaceBox gardés)")
	check(noShelf, "plus de champ ShelfBubble")
	check(Tutorial.Steps[3].Bubble == "Open a box on the shelf!" and Tutorial.Steps[4].Bubble == "Bring the item back to your shop!", "bulles 3 et 4 : celles du rayon")
	check(Tutorial.Hints.PlaceBox == nil and Tutorial.Hints.WaitBox == nil and Tutorial.Hints.OpenBox == nil, "indices PlaceBox, WaitBox, OpenBox retirés")
	check((Tutorial :: any).OpenDelay == nil and (Tutorial :: any).GuaranteedRarity == nil, "OpenDelay et GuaranteedRarity retirés")
	check(Tutorial.FirstBoxTier == "Premium" and Tutorial.GuaranteedItemId == "Z1_PotDeNouilles" and Tutorial.AntiTheftDelay == 5, "gardés : FirstBoxTier, GuaranteedItemId, AntiTheftDelay 5 s")
	check(Tutorial.Hints.DisplayUnlocked == "Put it on a display!" and Tutorial.Hints.TakeUnlocked ~= nil and words(Tutorial.Hints.TakeUnlocked) <= Tutorial.BubbleMaxWords, "DisplayUnlocked « Put it on a display! », TakeUnlocked 8 mots au plus")
	check(Tutorial.Hints.AnyoneCanRob == "Anyone can rob anyone: every shop door breaks in 40 hits!" and Tutorial.Hints.ProtectShop == "Protect your shop: Reinforced Door, Lock, Cameras!", "L-163 : AnyoneCanRob et ProtectShop (V0)")
	check(Tutorial.FunnelSteps[4] == "Premier colis volé" and Tutorial.FunnelSteps[6] == "Colis posé sur un établi", "noms du funnel gardés (Creator Dashboard)")
end

print("== A169-B. Profil neuf : tout le tuto avec un objet")
do
	NEXT_PLOT += 1
	local plot, N = makePlot(NEXT_PLOT, -300 - 10 * NEXT_PLOT, -150)
	local nea = makePlayer("Nea", 301, N.spawn)
	local data = newProfile()
	PROFILES[nea] = data
	SHIELD[nea] = true
	assignPlot(nea, plot)
	step(0.1)
	check(data.Tutorial.Step == 1 and lastStep(nea) ~= nil and lastStep(nea)[1] == 1, "profil neuf : étape 1 " .. describe(nea))
	moveTo(nea, Vector3.new(65, 3, 26))
	holdTool(nea, true)
	step(0.3)
	fireAsClient(nea, "HitWindow", "STORE_Z1_Superette")
	check(data.Tutorial.Step == 2, "premier coup : étape 2")
	breakWindow("STORE_Z1_Superette", nea)
	check(data.Tutorial.Step == 3, "vitrine cassée : étape 3")
	holdTool(nea, false)
	local payload = grab(nea, "STORE_Z1_Superette", "Standard", "Z1_Banane")
	check(payload.Kind == "NPCItem" and payload.ItemId == "Z1_PotDeNouilles", "l'objet sorti du colis est le Pot de nouilles, porté (NPCItem)")
	check(data.Tutorial.Step == 4 and stateOk(nea, 4, nil, N.spawn), "objet sur la tête : étape 4, flèche vers sa boutique " .. describe(nea))
	check(next(data.Boxes) == nil, "aucun colis dans le profil")
	moveTo(nea, Vector3.new(0, 3, 0))
	local uid = stowBox(nea)
	step(0.6)
	check(data.Items[uid].AntiTheft == true and stateOk(nea, 4, "PlaceFloorItem", N.spawn), "rangé sous antivol : PlaceFloorItem " .. describe(nea))
	noteHint(nea)
	moveTo(nea, N.spawn)
	check(placeBox(nea, 1) == 5, "posé au sol : antivol de 5 s (objet du tuto)")
	step(0.1)
	check(data.Tutorial.Step == 5 and stateOk(nea, 5, "WaitUnlock", N.slot1), "étape 5 : WaitUnlock, flèche sur l'objet " .. describe(nea))
	noteHint(nea)
	step(5.6)
	check(stateOk(nea, 5, "TakeUnlocked", N.slot1), "UNLOCKED! : TakeUnlocked, flèche sur l'objet " .. describe(nea))
	noteHint(nea)
	openBox(nea, 1)
	nea:SetAttribute("HeldItem", uid)
	step(0.6)
	check(stateOk(nea, 5, "DisplayUnlocked", N.slot1), "repris, en main : DisplayUnlocked, flèche vers le présentoir libre " .. describe(nea))
	noteHint(nea)
	nea:SetAttribute("HeldItem", "inconnu")
	step(0.6)
	check(stateOk(nea, 5, "PlaceItem", N.slot1), "en main un uid inconnu du profil : pas DisplayUnlocked (PlaceItem) " .. describe(nea))
	nea:SetAttribute("HeldItem", nil)
	data.Display["1"] = uid
	step(0.6)
	check(stateOk(nea, 5, "CollectCash", N.cashPad), "exposé : CollectCash " .. describe(nea))
	cashOut(nea, 10, "Pad")
	check(data.Tutorial.Step == 6, "encaissé : étape 6")
	nea:SetAttribute("TrainingMachine", "Treadmill")
	step(31)
	nea:SetAttribute("TrainingMachine", nil)
	check(data.Tutorial.Step == 7, "30 s de tapis : étape 7")
	table.insert(data.Tools.Owned, "Wrench")
	step(0.6)
	table.insert(data.Cosmetics.Auras, "Spark")
	step(0.6)
	check(data.Tutorial.Step == 9, "outil et aura : étape 9")
	moveTo(nea, Vector3.new(101, 3, 5))
	step(0.6)
	check(data.Tutorial.Step == 10, "zone 2 : étape 10")
	SHIELD[nea] = false
	step(0.6)
	check(stateOk(nea, 10, "ShieldEnd", nil), "fin du bouclier : ShieldEnd " .. describe(nea))
	step(8.6)
	check(TutorialService.GetStep(nea) == 11 and data.Tutorial.Done == false, "bot présent : étape 11")
	moveTo(nea, NEAR_DOOR)
	step(0.6)
	check(stateOk(nea, 12, "AnyoneCanRob", BOT_DOOR), "étape 12, porte du bot fermée : AnyoneCanRob, flèche vers la porte " .. describe(nea))
	noteHint(nea)
	BOT_SHOP:SetAttribute("StealOpen", true)
	step(0.6)
	check(stateOk(nea, 12, nil, botSlot(4)), "porte cassée : bulle de l'étape, flèche vers l'objet du bot " .. describe(nea))
	BOT_SHOP:SetAttribute("StealOpen", nil)
	botGrab(nea, 1)
	step(0.1)
	check(TutorialService.GetStep(nea) == 13, "objet du bot pris : étape 13")
	botDeposit(nea)
	step(0.1)
	check(data.Tutorial.Done == true and data.Tutorial.Step == 13 and stateOk(nea, 13, "ProtectShop", nil), "déposé : Done sauvegardé tout de suite, ProtectShop sans flèche " .. describe(nea))
	noteHint(nea)
	step(0.3)
	check(Controller.GetState and true, "client chargé")
	step(Tutorial.MessageDuration - 1)
	check(stateOk(nea, 13, "ProtectShop", nil) and TutorialService.IsActive(nea), "encore affiché avant MessageDuration s")
	step(1.6)
	check(stateOk(nea, 0, nil, nil) and not TutorialService.IsActive(nea) and nea:GetAttribute("TutorialStep") == 0, "puis tout caché, plus de tuto " .. describe(nea))
	local all = true
	for i = 1, 13 do
		if funnelCount(nea, i) ~= 1 then
			all = false
			print(`    funnel {i} : {funnelCount(nea, i)} fois`)
		end
	end
	check(all and funnelCount(nea, 14) == 0, "funnel 1 à 13 une fois chacun (14 : jamais poursuivi)")
	-- Départ pendant le message de fin : rien ne se rejoue (Done déjà sauvegardé).
	local saved = DEEPCOPY(data)
	check(saved.Tutorial.Done == true, "profil sauvegardé fini")
	-- Passer pendant le message de fin : tout caché tout de suite.
	local pia, dataP = resumeWith("Pia", 302, 13, function(d)
		d.Items["p1"] = { Id = "Z1_PotDeNouilles", Source = "NPC", At = 0, Zone = 1 }
	end)
	botGrab(pia, 2)
	step(0.1)
	botDeposit(pia)
	step(0.1)
	check(stateOk(pia, 13, "ProtectShop", nil), "Pia : message de fin " .. describe(pia))
	step(1.1)
	fireAsClient(pia, "TutorialSkip")
	step(0.1)
	check(stateOk(pia, 0, nil, nil) and dataP.Tutorial.Done == true, "Passer pendant le message de fin : tout caché tout de suite " .. describe(pia))
end

print("== A169-C. Profils sauvegardés à chaque étape : une étape valable")
do
	local pot = function(d)
		d.Items["r1"] = { Id = "Z1_PotDeNouilles", Source = "NPC", At = 0, Zone = 1 }
		d.Lifetime.Heists = 1
	end
	-- Étape sauvegardée → étape jouée à la reprise (magasins fermés, rien porté, bot présent, bouclier actif).
	local expected = { [1] = 1, [2] = 2, [3] = 2, [4] = 5, [5] = 5, [6] = 6, [7] = 7, [8] = 8, [9] = 9, [10] = 10, [11] = 11, [12] = 12, [13] = 12, [14] = 12 }
	for stepIndex = 1, 14 do
		local player, data = resumeWith(`Re{stepIndex}`, 400 + stepIndex, stepIndex, pot)
		step(0.6)
		local got = TutorialService.GetStep(player)
		local last = lastStep(player)
		local hint = last and last[2]
		noteHint(player)
		check(got == expected[stepIndex] and data.Tutorial.Done == false and (hint == nil or Tutorial.Hints[hint] ~= nil), `profil à l'étape {stepIndex} : reprise à {expected[stepIndex]} (reçu {got}, indice {tostring(hint)})`)
		check(data.Tutorial.Step == math.max(stepIndex, expected[stepIndex]), `profil à l'étape {stepIndex} : Step garde l'étape la plus avancée ({data.Tutorial.Step})`)
	end
	-- Ancien profil à 4 avec un colis : DataService.convertBoxes en a fait un objet libre au chargement → étape 5, PlaceItem.
	local old4, data4, O = resumeWith("Old4", 420, 4, function(d)
		d.Items["conv"] = { Id = "Z1_PotDeNouilles", Source = "NPC", At = 0, Zone = 1 }
	end)
	step(0.6)
	check(TutorialService.GetStep(old4) == 5 and stateOk(old4, 5, "PlaceItem", O.slot1), "ancien profil à 4, colis converti en objet : étape 5, PlaceItem " .. describe(old4))
	-- Même profil si le colis était encore dans Boxes (sans conversion) : aucune erreur, retour au braquage (étape 2).
	local raw4, dataR = resumeWith("Raw4", 421, 4, function(d)
		d.Boxes["b1"] = { Tier = "Premium", Zone = 1, ItemId = "Z1_PotDeNouilles", Rarity = "Rare", ReadyAt = 0 }
	end)
	step(0.6)
	check(TutorialService.GetStep(raw4) == 2 and dataR.Tutorial.Step == 4 and dataR.Tutorial.Done == false, "colis resté dans Boxes : étape 2 (profil garde 4), sans erreur " .. describe(raw4))
	-- Ancien profil à 5 avec l'objet du tuto encore sous antivol au sol : WaitUnlock.
	local old5, _, O5 = resumeWith("Old5", 422, 5, function(d)
		d.Items["f1"] = { Id = "Z1_PotDeNouilles", Source = "NPC", At = 0, Zone = 1, AntiTheft = true, UnlockAt = Workspace:GetServerTimeNow() + 60, Spot = { X = 1, Y = 0, Z = 0 } }
	end)
	BOX_POS["f1"] = O5.slot1
	step(0.6)
	check(stateOk(old5, 5, "WaitUnlock", O5.slot1), "profil à 5, objet au sol sous antivol : WaitUnlock " .. describe(old5))
	-- Profil à 4 avec l'objet sous antivol dans l'inventaire : PlaceFloorItem.
	local inv4, _, I4 = resumeWith("Inv4", 423, 4, function(d)
		d.Items["s1"] = { Id = "Z1_PotDeNouilles", Source = "NPC", At = 0, Zone = 1, AntiTheft = true }
	end)
	step(0.6)
	check(stateOk(inv4, 4, "PlaceFloorItem", I4.spawn), "profil à 4, objet sous antivol rangé : PlaceFloorItem " .. describe(inv4))
	-- Ancien joueur (colis dans Boxes, tuto pas commencé) : toujours marqué fini sans tuto (hasPlayed).
	local oldie, dataO = resumeWith("Oldie", 424, 0, function(d)
		d.Boxes["b2"] = { Tier = "Standard", Zone = 1, ItemId = "Z1_Donut", Rarity = "Common", ReadyAt = 0 }
	end)
	check(dataO.Tutorial.Done == true and dataO.Tutorial.Step == 0 and #stepsTo(oldie) == 0, "Boxes d'un ancien profil : ancien joueur, pas de tuto")
end

print("== A169-D. Client : chaque indice envoyé a son texte")
do
	local missing = {}
	for hint in SENT_HINTS do
		if type(Tutorial.Hints[hint]) ~= "string" then
			table.insert(missing, hint)
		end
	end
	check(#missing == 0 and SENT_HINTS.AnyoneCanRob and SENT_HINTS.ProtectShop and SENT_HINTS.TakeUnlocked and SENT_HINTS.DisplayUnlocked, "indices envoyés pendant ce banc, tous dans Config/Tutorial.Hints " .. table.concat(missing, ","))
	-- Alice (le client) : étape 12, porte fermée, puis le message de fin.
	local data = newProfile()
	data.Tutorial.Step = 12
	data.Items["al"] = { Id = "Z1_PotDeNouilles", Source = "NPC", At = 0, Zone = 1 }
	PROFILES[ALICE] = data
	SHIELD[ALICE] = true
	local plot = makePlot(70, -800, -150)
	assignPlot(ALICE, plot)
	moveTo(ALICE, NEAR_DOOR)
	step(0.6)
	check(Controller.GetState().Text == Tutorial.Hints.AnyoneCanRob, "client, étape 12 : « " .. tostring(Controller.GetState().Text) .. " »")
	botGrab(ALICE, 3)
	step(0.6)
	botDeposit(ALICE)
	step(0.6)
	check(Controller.GetState().Text == Tutorial.Hints.ProtectShop and Controller.GetState().Arrow == false, "client, fin : « " .. tostring(Controller.GetState().Text) .. " », sans flèche")
	step(Tutorial.MessageDuration + 0.6)
	check(Controller.GetState().Shown == false, "client : puis tout caché")
end

print("== A169-L. Sortie")
check(not logHas("mal formé", "WARN"), "aucun envoi de remote mal formé")
check(not logHas("contrôle :", "WARN", "server"), "aucune erreur dans le contrôle régulier")
summary()
