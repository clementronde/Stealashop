-- Banc a199 (vague 61, 2026-11-15 ; Cantin : « le tuto, il est trop long […] Quitte à leur donner l'argent […] maximum dans
-- son entièreté 2 à 3 minutes »). Lu après la mise en place de la copie a169 du banc a28 (jusqu'à « == A. »), le faux
-- BotService du banc a121 et bot-extra d'a124 (comme le banc a197).
--   A. Config/Tutorial : interrupteurs V0, dons = prix, indices de 8 mots, tâches sans l'étape 10, étape 9 sans Speed ;
--   B. durée calculée de chaque étape, avant et après (≤ 3 min au total, cible 2 min 30) ;
--   C. dons : versés une fois (étape 7, étape 8), indice, rien si l'argent suffit, reprise, Passer ;
--   D. étape 10 sans attente : zone 2 → bot (ou fin sans bot), reprise à l'étape 10 ;
--   E. 10 s de tapis ; liste des tâches et flèche d'a197 intactes.

local TutorialTasks = requireModule(SharedFolder.TutorialTasks, "client")
local Balance = requireModule(SharedFolder.Config.Balance, "server")
local PvP = requireModule(SharedFolder.Config.PvP, "server")

-- Faux DataService : AddCash, comme le vrai (ajout pur).
FakeData.AddCash = function(player, amount)
	local data = PROFILES[player]
	if data == nil or type(amount) ~= "number" or amount <= 0 then
		return nil
	end
	data.Cash += amount
	return data.Cash
end

-- Mêmes aides que le banc a197.
BOT_SHOP = makePlot(20, -150, 100)
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
function walledPlot(x, z)
	NEXT_PLOT += 1
	local plot, P = makePlot(NEXT_PLOT, x, z)
	part("Bounds", Vector3.new(x, 7, z), Vector3.new(64, 14, 80), plot, { CanCollide = false, Transparency = 1 })
	local door = new("Model", { Name = "PlotDoor" }, plot)
	part("Window", Vector3.new(x, 5, z - 40), Vector3.new(10, 8, 0.5), door)
	P.door = Vector3.new(x, 5, z - 40)
	return plot, P
end
function resumeAt(name, userId, stepIndex, fill)
	local plot, P = walledPlot(-300 - 10 * NEXT_PLOT, -150)
	local player = makePlayer(name, userId, P.spawn)
	local data = newProfile()
	data.Tutorial.Step = stepIndex
	data.Items["pot"] = { Id = "Z1_PotDeNouilles", Source = "NPC", At = 0, Zone = 1 }
	data.Lifetime.Heists = 1
	if fill then
		fill(data)
	end
	PROFILES[player] = data
	SHIELD[player] = true
	assignPlot(player, plot)
	step(0.1)
	return player, data, P
end
function skip(player)
	step(1.1) -- TutorialSkip : 1 par seconde (Net)
	fireAsClient(player, "TutorialSkip")
	step(0.1)
end
local function words(text)
	return #string.split(text, " ")
end

botArrive(BOT_SHOP)
step(0.1)

print("== A199-A. Config/Tutorial : tuto court")
do
	check(Tutorial.WaitShieldEnd == false and Tutorial.GiftCash == true and Tutorial.TrainDuration == 10, "V0 : WaitShieldEnd = false, GiftCash, TrainDuration = 10 s")
	local cheapest = math.huge
	for _, aura in Cosmetics.Auras do
		cheapest = math.min(cheapest, aura.Price)
	end
	check(Tutorial.ToolGift == Tools.ById[Tutorial.ToolToBuy].Price and Tutorial.ToolGift == 300, `don de l'étape 7 = prix de la clé à molette ({Tutorial.ToolGift} $)`)
	check(Tutorial.AuraGift == cheapest and Tutorial.AuraGift == 500, `don de l'étape 8 = prix de l'aura la moins chère ({Tutorial.AuraGift} $)`)
	check(Tutorial.Hints.ToolGift == "Here's $300 for the tutorial: buy the Wrench!" and Tutorial.Hints.AuraGift == "Here's $500 for the tutorial: buy an Aura!", `indices : « {Tutorial.Hints.ToolGift} », « {Tutorial.Hints.AuraGift} »`)
	check(words(Tutorial.Hints.ToolGift) <= Tutorial.BubbleMaxWords and words(Tutorial.Hints.AuraGift) <= Tutorial.BubbleMaxWords, "indices des dons : 8 mots au plus")
	local order = {}
	for _, task in Tutorial.Tasks do
		for _, s in task.Steps do
			table.insert(order, s)
		end
	end
	check(table.concat(order, ",") == "1,2,3,4,5,6,7,8,9,11,12,14,13", "tâches dans l'ordre du jeu, sans l'étape 10 : " .. table.concat(order, ","))
	check(TutorialTasks.TaskIndex(10) == nil and TutorialTasks.TaskIndex(11) == 8 and #Tutorial.Tasks == 9, "étape 10 hors liste, 9 tâches")
	check(Tutorial.Todos[9].Need == nil and TutorialTasks.Line(9, 12, 3000) == "Walk through the Zone 2 gate", "étape 9 : plus de « Speed: 12 / 3K » (l'arche ne bloque pas)")
	-- At : croissants dans l'ordre du jeu, le dernier sous 3 min.
	local last, ok = -1, true
	for _, s in order do
		local at = Tutorial.Steps[s].At
		if at < last then
			ok = false
		end
		last = at
	end
	check(ok and last <= 180, `At croissants dans l'ordre du jeu, dernière étape à {last} s`)
	check(Tutorial.SkipOneStep == true and Tutorial.ArrowViaDoor == false and Tutorial.TaskList == true, "interrupteurs d'a197 gardés : SkipOneStep, ArrowViaDoor = false, TaskList")
end

print("== A199-B. Durée calculée de chaque étape (avant / après)")
-- Trajets estimés (studs, V0, pas de relevé Studio dans cette vague) : parcelle → Supérette, aller-retour du rayon, stands
-- du hub, arche de la zone 2, retour au bot, bot → sa boutique. Actions estimées (s) : lecture de chaque bulle, ouverture
-- sur le rayon (rabats et chance ×1,5 : 2 s), prise, rangement, achat dans l'écran de la boutique.
local D = { Store = 150, Shelf = 10, Stand = 100, Gate = 250, Bot = 300, Home = 80 }
local A = { Read = 2, Open = 2, Grab = 1, Stow = 1, PlaceFloor = 3, Take = 1, Display = 3, Pad = 2, Collect = 1, Buy = 5, Mount = 3 }
local function simulate(p)
	local rows = {}
	local t = 0
	local cash = 0
	local income = Zones[1].BaseIncome * Rarities.ById.Rare.IncomeMultiplier -- Pot de nouilles, Rare de la zone 1 : 5 $/s
	local displayedAt = nil
	local function earned(now)
		return if displayedAt then (now - displayedAt) * income else 0
	end
	local function add(index, label, seconds, gift)
		seconds += A.Read
		table.insert(rows, { index = index, label = label, seconds = seconds, gift = gift or "" })
		t += seconds
	end
	local fists = Tools.ById.Fists.Power
	local regen = Balance.Window.RegenPerSecond * p.hp
	add(1, "Arrivée, vers la Supérette", D.Store / p.walk)
	add(2, "Vitrine (" .. p.hp .. " PV)", p.hp / (Balance.Hit.MaxHitsPerSecond * fists - regen))
	add(3, "Colis du rayon, l'objet", D.Shelf / p.walk + A.Open + A.Grab)
	add(4, "Retour en boutique", D.Store / (p.walk * Balance.Carry.NPCBoxSpeedMultiplier) + A.Stow)
	add(5, "Exposer, encaisser", A.PlaceFloor + Tutorial.AntiTheftDelay + A.Take + A.Display + A.Pad + A.Collect)
	displayedAt = t - A.Pad - A.Collect - A.Read
	add(6, "Tapis", A.Mount + p.train)
	local function buy(index, label, price, gift)
		local have = earned(t) - cash
		local wait = 0
		local given = ""
		if p.gifts and have < price then
			given = `{gift} $`
			cash -= gift
			have += gift
		end
		if have < price then
			wait = (price - have) / income + A.Pad + A.Collect
		end
		cash += price
		add(index, label, wait + D.Stand / p.walk + A.Buy, given)
	end
	buy(7, "Clé à molette", Tools.ById[Tutorial.ToolToBuy].Price, Tutorial.ToolGift)
	buy(8, "Aura", Tutorial.AuraGift, Tutorial.AuraGift)
	add(9, "Arche de la zone 2", D.Gate / p.walk)
	if p.shield then
		local wait = math.max(0, PvP.BeginnerShieldDuration - t) + Tutorial.MessageDuration
		add(10, "Fin du bouclier débutant", wait - A.Read)
	end
	add(11, "Vers la boutique du bot", D.Bot / p.walk)
	add(12, "Porte du bot, son objet", PvP.DoorHits / Balance.Hit.MaxHitsPerSecond + A.Grab)
	add(13, "Semer le bot, rentrer (14 puis 13)", D.Home / p.walk + A.Stow)
	add(0, "Message ProtectShop", Tutorial.MessageDuration - A.Read)
	return rows, t
end
local function show(title, rows, total)
	print(`  {title} : {string.format("%d min %02d s", total // 60, math.floor(total % 60))}`)
	for _, row in rows do
		print(string.format("    %2d %-36s %6.1f s %s", row.index, row.label, row.seconds, row.gift))
	end
end
do
	local beforeRows, before = simulate({ walk = 16, hp = Zones[1].WindowHP, train = 30, gifts = false, shield = true })
	local afterRows, after = simulate({ walk = 32, hp = 15, train = Tutorial.TrainDuration, gifts = Tutorial.GiftCash, shield = Tutorial.WaitShieldEnd })
	local slowRows, slow = simulate({ walk = 16, hp = 15, train = Tutorial.TrainDuration, gifts = Tutorial.GiftCash, shield = Tutorial.WaitShieldEnd })
	show(`avant (marche 16, {Zones[1].WindowHP} PV, 30 s de tapis, sans don, bouclier attendu)`, beforeRows, before)
	show("après (marche 32 d'a198, 15 PV, 10 s, dons, sans attente)", afterRows, after)
	show("après sans le ×2 d'a198 (marche 16)", slowRows, slow)
	check(before > 9 * 60, `avant : plus de 9 min ({math.floor(before)} s)`)
	check(after <= 150, `après : 2 min 30 au plus ({math.floor(after)} s)`)
	check(slow <= 180, `après, même sans le ×2 d'a198 : 3 min au plus ({math.floor(slow)} s)`)
	local waits = 0
	for _, row in afterRows do
		if row.seconds > 20 then
			waits += 1
		end
	end
	check(waits == 0, "après : aucune étape de plus de 20 s")
end

print("== A199-C. Dons d'argent, une seule fois")
do
	local p7, d7 = resumeAt("Gift7", 701, 7)
	check(d7.Cash == 300 and d7.Tutorial.Gifts and d7.Tutorial.Gifts.Tool == true, `étape 7 à 0 $ : don de 300 $ ({d7.Cash} $)`)
	check(stateOk(p7, 7, "ToolGift", WEAPON_SHOP), "indice ToolGift, flèche vers la boutique d'armes " .. describe(p7))
	local have, need = lastStep(p7)[4], lastStep(p7)[5]
	check(have == 300 and need == 300 and TutorialTasks.Line(7, have, need) == Tutorial.Todos[7].Do, "liste : « Go to the Weapon Shop and buy it »")
	step(1.1)
	check(d7.Cash == 300, "pas de second don au contrôle suivant")
	d7.Cash -= 300
	table.insert(d7.Tools.Owned, "Wrench")
	step(0.6)
	check(TutorialService.GetStep(p7) == 8 and d7.Cash == 500 and d7.Tutorial.Gifts.Aura == true, `clé achetée : étape 8, don de 500 $ ({d7.Cash} $)`)
	check(stateOk(p7, 8, "AuraGift", AURA_SHOP), "indice AuraGift, flèche vers la boutique d'auras " .. describe(p7))
	d7.Cash -= 500
	table.insert(d7.Cosmetics.Auras, "Spark")
	step(0.6)
	check(TutorialService.GetStep(p7) == 9 and d7.Cash == 0, "aura achetée : étape 9, plus rien de donné")

	-- Reprise : don versé, argent dépensé ailleurs → pas de second don (CollectCash).
	local copyGifts = { Tool = true }
	local p7b, d7b = resumeAt("Gift7b", 702, 7, function(d)
		d.Tutorial.Gifts = copyGifts
	end)
	check(d7b.Cash == 0 and stateOk(p7b, 7, "CollectCash", nil) == false and lastStep(p7b)[2] == "CollectCash", "reprise à l'étape 7, don déjà versé : rien de plus, CollectCash " .. describe(p7b))
	-- Profil sans le champ Gifts (avant a199) : le don arrive.
	local p7c, d7c = resumeAt("Gift7c", 703, 7, function(d)
		d.Tutorial.Gifts = nil
	end)
	check(d7c.Cash == 300 and d7c.Tutorial.Gifts.Tool == true, "profil sans Tutorial.Gifts : don versé, champ créé")
	-- Assez d'argent : pas de don, bulle de l'étape.
	local p7d, d7d = resumeAt("Gift7d", 704, 7, function(d)
		d.Cash = 450
	end)
	check(d7d.Cash == 450 and (d7d.Tutorial.Gifts == nil or d7d.Tutorial.Gifts.Tool == nil) and stateOk(p7d, 7, nil, WEAPON_SHOP), "450 $ : pas de don, bulle « Buy the Wrench! » " .. describe(p7d))

	-- Passer : 6 → 7 (don), 7 → 8 (don), 8 → 9 ; chaque don une fois, même après une reprise.
	local ps, ds = resumeAt("GiftSkip", 705, 6)
	skip(ps)
	check(TutorialService.GetStep(ps) == 7 and ds.Cash == 300, `Passer à 6 : étape 7 et son don ({ds.Cash} $)`)
	skip(ps)
	check(TutorialService.GetStep(ps) == 8 and ds.Cash == 800, `Passer à 7 : étape 8, don de l'aura, les 300 $ gardés ({ds.Cash} $)`)
	skip(ps)
	check(TutorialService.GetStep(ps) == 9 and ds.Cash == 800 and #ds.Tools.Owned == 1 and #ds.Cosmetics.Auras == 0, "Passer à 8 : étape 9, rien d'acheté ni de repris")
	local copy = DEEPCOPY(ds)
	copy.Tutorial.Step = 7
	copy.Cash = 0
	local back = makePlayer("GiftSkip2", 706, Vector3.new(0, 3, 0))
	local plot = walledPlot(-1000, -150)
	PROFILES[back] = copy
	SHIELD[back] = true
	assignPlot(back, plot)
	step(0.6)
	check(copy.Cash == 0 and TutorialService.GetStep(back) == 7, "reprise du même profil à l'étape 7 : aucun don de plus")
	skip(back)
	check(copy.Cash == 0 and TutorialService.GetStep(back) == 8, "puis Passer à 7 : étape 8, aucun don de plus")
end

print("== A199-D. Étape 10 : plus d'attente du bouclier")
do
	local p9, d9 = resumeAt("Shield9", 711, 9)
	check(SHIELD[p9] == true and TutorialService.GetStep(p9) == 9, "étape 9, bouclier actif")
	skip(p9)
	check(TutorialService.GetStep(p9) == 11 and d9.Tutorial.Step == 11 and stateOk(p9, 11, nil, BOT_DOOR), "Passer à 9, bot présent : étape 11 tout de suite, flèche vers sa porte " .. describe(p9))
	local p9g, d9g = resumeAt("Shield9g", 712, 9)
	moveTo(p9g, GATE_2 + Vector3.new(15, 3, 0))
	step(0.6)
	check(TutorialService.GetStep(p9g) == 11 and d9g.Tutorial.Step == 11, "arche de la zone 2 passée, bouclier actif : étape 11 " .. describe(p9g))
	local p10, d10 = resumeAt("Shield10", 713, 10)
	check(TutorialService.GetStep(p10) == 11 and d10.Tutorial.Step == 11, "reprise à l'étape 10 (ancien profil) : étape 11")
	botLeave()
	step(0.1)
	local pn, dn = resumeAt("Shield9n", 714, 9)
	moveTo(pn, GATE_2 + Vector3.new(15, 3, 0))
	step(0.6)
	check(dn.Tutorial.Done == true and dn.Tutorial.Step == 10 and stateOk(pn, 10, "ProtectShop", nil), "sans bot : arche passée, fin du tuto (Step 10), ProtectShop " .. describe(pn))
	step(Tutorial.MessageDuration + 0.6)
	check(stateOk(pn, 0, nil, nil) and not TutorialService.IsActive(pn), "puis tout caché")
	botArrive(BOT_SHOP)
	step(0.1)
end

print("== A199-E. Tapis de 10 s, liste et flèche d'a197")
do
	local p6, d6 = resumeAt("Train6", 721, 6)
	check(lastStep(p6)[4] == 0 and lastStep(p6)[5] == 10, "étape 6 : 0 / 10 s " .. describe(p6))
	p6:SetAttribute("TrainingMachine", "Treadmill")
	step(6.2)
	check(TutorialService.GetStep(p6) == 6, "6 s de tapis : encore l'étape 6")
	step(5)
	check(TutorialService.GetStep(p6) == 7 and d6.Cash == 300, "11 s de tapis : étape 7 et son don")
	p6:SetAttribute("TrainingMachine", nil)
	local rows = TutorialTasks.Rows(11)
	local ids = {}
	for _, row in rows do
		table.insert(ids, row.Id .. (if row.Current then "*" elseif row.Done then "+" else ""))
	end
	check(table.concat(ids, ",") == "BuyTool+,BuyAura+,Zone2+,RobBot*,BringStolen", "liste à l'étape 11 : " .. table.concat(ids, ","))
	check(TutorialTasks.Compact(7, 0, 300) == "Buy the Wrench (5/9): Earn cash: $0 / $300 to buy the Wrench", "version courte : " .. tostring(TutorialTasks.Compact(7, 0, 300)))
	local p1 = resumeAt("Arrow1", 722, 1, function(d)
		d.Items = {}
		d.Lifetime.Heists = 0
	end)
	check(stateOk(p1, 1, nil, SUPERETTE_WINDOW), "étape 1 : flèche sur la vitrine de la Supérette (a197) " .. describe(p1))
end

print("== A199. Sortie")
check(not logHas("mal formé", "WARN"), "aucun envoi de remote mal formé")
check(not logHas("contrôle :", "WARN", "server"), "aucune erreur dans le contrôle régulier")
summary()
