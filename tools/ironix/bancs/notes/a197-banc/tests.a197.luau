-- Banc a197 (vague 60, 2026-11-15 ; Cantin après T-083 à T-098 : « je savais pas qu'est-ce qu'il fallait qu'on fasse, où
-- on en était et pourquoi », la flèche « ne doit pas mener jusqu'à la vitrine », Passer saute une étape).
-- Lu après la mise en place de la copie a169 du banc a28 (jusqu'à « == A. ») et le faux BotService du banc a121 + bot-extra d'a124.
--   A. Config/Tutorial : Todos et Tasks (chaque étape a son but, sa raison, ce qu'il faut faire), interrupteurs ;
--   B. Shared/TutorialTasks : lignes, progression, liste, version courte ;
--   C. serveur : progression envoyée avec l'étape (tapis, argent, Speed, bouclier) ;
--   D. flèche sur la cible exacte (plus de détour par la porte de sa boutique) ;
--   E. Passer une étape à la fois (5 → 13, poursuite, sans bot, avant l'étape 5, reprise) ;
--   F. client : repli V0 avec son panneau Tasks, écran de Clément sans et avec Tasks, fin du tuto.

local TutorialTasks = requireModule(SharedFolder.TutorialTasks, "client")

-- Boutique du bot (comme le banc a169).
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
-- Parcelle avec murs (Bounds) et porte (PlotDoor/Window, au milieu de l'avant, z - 40) : la boutique du hub.
function walledPlot(x, z)
	NEXT_PLOT += 1
	local plot, P = makePlot(NEXT_PLOT, x, z)
	part("Bounds", Vector3.new(x, 7, z), Vector3.new(64, 14, 80), plot, { CanCollide = false, Transparency = 1 })
	local door = new("Model", { Name = "PlotDoor" }, plot)
	part("Window", Vector3.new(x, 5, z - 40), Vector3.new(10, 8, 0.5), door)
	P.door = Vector3.new(x, 5, z - 40)
	return plot, P
end
-- Joueur qui reprend à l'étape `stepIndex` dans une boutique murée ; `fill(data)` remplit le profil avant l'arrivée.
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
-- Progression du dernier TutorialStep : (have, need).
function progress(player)
	local last = lastStep(player)
	if last == nil then
		return nil, nil
	end
	return last[4], last[5]
end
function skip(player)
	step(1.1) -- TutorialSkip : 1 par seconde (Net)
	fireAsClient(player, "TutorialSkip")
	step(0.1)
end

botArrive(BOT_SHOP)
step(0.1)

print("== A197-A. Config/Tutorial : chaque étape a son but, sa raison et ce qu'il faut faire")
do
	local missing = {}
	local owner: { [number]: number } = {}
	for index, task in Tutorial.Tasks do
		if type(task.Goal) ~= "string" or task.Goal == "" or type(task.Why) ~= "string" or task.Why == "" then
			table.insert(missing, `tâche {index}`)
		end
		for _, s in task.Steps do
			if owner[s] then
				table.insert(missing, `étape {s} dans deux tâches`)
			end
			owner[s] = index
		end
	end
	for s = 1, #Tutorial.Steps do
		local todo = Tutorial.Todos[s]
		if owner[s] == nil then
			table.insert(missing, `étape {s} sans tâche`)
		end
		if todo == nil or type(todo.Do) ~= "string" or todo.Do == "" then
			table.insert(missing, `étape {s} sans Do`)
		end
		if todo and todo.Need then
			local rest = string.gsub(todo.Need, "{have}", ""):gsub("{need}", ""):gsub("{left}", "")
			if string.find(rest, "[{}]") or todo.NeedFormat == nil then
				table.insert(missing, `étape {s} : Need mal formé`)
			end
		end
	end
	check(#missing == 0, "14 étapes, chacune dans une seule tâche, avec Do ; chaque tâche a Goal et Why " .. table.concat(missing, ", "))
	-- Ordre du jeu : l'étape 14 (le bot poursuit) se joue entre 12 et 13.
	local order = {}
	for _, task in Tutorial.Tasks do
		for _, s in task.Steps do
			table.insert(order, s)
		end
	end
	check(table.concat(order, ",") == "1,2,3,4,5,6,7,8,9,10,11,12,14,13", "tâches dans l'ordre du jeu (14 entre 12 et 13) : " .. table.concat(order, ","))
	check(Tutorial.Tasks[5].Goal == "Buy the " .. Tools.ById[Tutorial.ToolToBuy].DisplayName, "tâche 5 : « Buy the Wrench » (nom de ToolToBuy)")
	check(string.find(Tutorial.Todos[7].Need :: string, "to buy the Wrench", 1, true) ~= nil and string.find(Tutorial.Todos[8].Need :: string, "to buy an Aura", 1, true) ~= nil, "l'argent dit à quoi il sert (« to buy the Wrench », « to buy an Aura »)")
	check(Tutorial.SkipOneStep == true and Tutorial.ArrowViaDoor == false and Tutorial.TaskList == true, "interrupteurs V0 : SkipOneStep, ArrowViaDoor = false, TaskList")
end

print("== A197-B. Shared/TutorialTasks")
do
	check(TutorialTasks.Line(7, 100, 300) == "Earn cash: $100 / $300 to buy the Wrench", "étape 7, 100 $ : « " .. tostring(TutorialTasks.Line(7, 100, 300)) .. " »")
	check(TutorialTasks.Line(7, 300, 300) == Tutorial.Todos[7].Do and TutorialTasks.Line(7, 450, 300) == Tutorial.Todos[7].Do, "étape 7, assez d'argent : « Go to the Weapon Shop and buy it »")
	check(TutorialTasks.Line(8, 120.7, 500) == "Earn cash: $120 / $500 to buy an Aura", "étape 8 : « " .. tostring(TutorialTasks.Line(8, 120.7, 500)) .. " »")
	check(TutorialTasks.Line(6, 12, 30) == "Train: 12s / 30s to get faster", "étape 6 : « " .. tostring(TutorialTasks.Line(6, 12, 30)) .. " »")
	check(TutorialTasks.Line(9, 1250, 3000) == "Speed: 1.2K / 3K to outrun Zone 2 guards", "étape 9 : « " .. tostring(TutorialTasks.Line(9, 1250, 3000)) .. " »")
	check(TutorialTasks.Line(10, 359.5, 600) == "Beginner protection ends in 4:01" and TutorialTasks.Line(10, 0, 600) == "Beginner protection ends in 10:00", "étape 10 : « " .. tostring(TutorialTasks.Line(10, 359.5, 600)) .. " »")
	check(TutorialTasks.Line(5) == Tutorial.Todos[5].Do and TutorialTasks.Line(7) == Tutorial.Todos[7].Do and TutorialTasks.Line(7, 0 / 0, 300) == Tutorial.Todos[7].Do, "sans progression (ou NaN) : le texte Do")
	check(TutorialTasks.Line(0) == nil and TutorialTasks.Line(99) == nil and TutorialTasks.TaskIndex(0) == nil, "étape 0 ou inconnue : rien")
	local rows = TutorialTasks.Rows(7, 100, 300)
	local ids = {}
	for _, r in rows do
		table.insert(ids, `{r.Index}{if r.Done then "x" elseif r.Current then "*" else ""}`)
	end
	check(table.concat(ids, ",") == "2x,3x,4x,5*,6", "étape 7 : 5 lignes au plus, faites cochées, en cours, une à venir : " .. table.concat(ids, ","))
	local current = rows[4]
	check(current.Goal == "Buy the Wrench" and current.Line == "Earn cash: $100 / $300 to buy the Wrench" and current.Why ~= "" and rows[5].Line == nil and rows[1].Line == nil, "ligne en cours : but, progression, raison ; les autres sans ligne")
	local first = TutorialTasks.Rows(1)
	check(#first == 2 and first[1].Current and not first[1].Done and first[2].Index == 2 and not first[2].Done, "étape 1 : la tâche en cours et la suivante")
	local r14, r13 = TutorialTasks.Rows(14), TutorialTasks.Rows(13)
	check(r14[#r14 - 1].Id == "RobBot" and r14[#r14 - 1].Current and r14[#r14].Id == "BringStolen", "étape 14 : « Rob another shop » en cours, puis « Bring the stolen item home »")
	check(r13[#r13].Id == "BringStolen" and r13[#r13].Current and r13[#r13 - 1].Done, "étape 13 : la dernière tâche en cours, le vol coché")
	check(#TutorialTasks.Rows(0) == 0 and TutorialTasks.Compact(0) == nil, "tuto fini : liste vide")
	check(TutorialTasks.Compact(7, 100, 300) == "Buy the Wrench (5/10): Earn cash: $100 / $300 to buy the Wrench", "version courte : « " .. tostring(TutorialTasks.Compact(7, 100, 300)) .. " »")
end

print("== A197-C. Serveur : progression envoyée avec l'étape")
do
	local p6, d6 = resumeAt("Pro6", 601, 6)
	check(TutorialService.GetStep(p6) == 6 and select(1, progress(p6)) == 0 and select(2, progress(p6)) == 30, "étape 6 : 0 / 30 s " .. describe(p6))
	p6:SetAttribute("TrainingMachine", "Treadmill")
	step(12.2)
	local have6, need6 = progress(p6)
	check(have6 ~= nil and have6 >= 11 and have6 <= 13 and need6 == 30 and math.floor(have6) == have6, `12 s de tapis : {tostring(have6)} / {tostring(need6)} (entier)`)
	p6:SetAttribute("TrainingMachine", nil)
	local p7, d7 = resumeAt("Pro7", 602, 7, function(d)
		d.Cash = 100
	end)
	check(stateOk(p7, 7, "CollectCash", nil) == false and select(1, progress(p7)) == 100 and select(2, progress(p7)) == 300, "étape 7, 100 $ : 100 / 300 " .. describe(p7))
	d7.Cash = 250.6
	step(0.6)
	check(select(1, progress(p7)) == 250, "l'argent monte : 250 / 300 (arrondi vers le bas)")
	d7.Cash = 300
	step(0.6)
	local h7, n7 = progress(p7)
	check(h7 == 300 and n7 == 300 and lastStep(p7)[2] == nil and TutorialTasks.Line(7, h7, n7) == Tutorial.Todos[7].Do, "300 $ : flèche vers la boutique d'armes, « Go to the Weapon Shop » " .. describe(p7))
	table.insert(d7.Tools.Owned, "Wrench")
	step(0.6)
	local h8, n8 = progress(p7)
	check(TutorialService.GetStep(p7) == 8 and h8 == 300 and n8 == 500, `clé achetée : étape 8, cochée, 300 / 500 pour l'aura ({tostring(h8)} / {tostring(n8)})`)
	local p9 = resumeAt("Pro9", 603, 9)
	p9:SetAttribute("ShownSpeed", 1250)
	step(0.6)
	local h9, n9 = progress(p9)
	check(h9 == 1250 and n9 == Zones[2].SpeedRequired, `étape 9 : Speed 1250 / {Zones[2].SpeedRequired} ({tostring(h9)} / {tostring(n9)})`)
	local p10 = resumeAt("Pro10", 604, 10)
	check(progress(p10) == nil, "étape 10 sans NightCycleService.GetShieldPlayed (faux service d'avant) : pas de progression, sans erreur")
	FakeNight.GetShieldPlayed = function(_player)
		return 240.4
	end
	step(0.6)
	local h10, n10 = progress(p10)
	check(h10 == 240 and n10 == 600, `étape 10 : 240 / 600 s de bouclier ({tostring(h10)} / {tostring(n10)})`)
	FakeNight.GetShieldPlayed = nil
	local p5 = resumeAt("Pro5", 605, 5)
	check(lastStep(p5)[4] == nil and lastStep(p5)[5] == nil, "étape 5 : pas de progression " .. describe(p5))
	local _ = d6
end

print("== A197-D. Flèche sur la cible exacte, jamais la porte de sa boutique")
do
	-- Dans sa boutique (murée, porte à l'avant), cible dehors : avant a197, la flèche allait d'abord à la porte.
	local d1p, _, D1 = resumeAt("Door1", 611, 1, function(d)
		d.Items = {}
		d.Lifetime.Heists = 0
	end)
	check(stateOk(d1p, 1, nil, SUPERETTE_WINDOW) and not stateOk(d1p, 1, nil, D1.door), "étape 1, dans sa boutique : flèche sur la vitrine de la Supérette " .. describe(d1p))
	local p5, d5, P5 = resumeAt("Door5", 612, 5)
	d5.Display["1"] = "pot"
	moveTo(p5, P5.door - Vector3.new(0, 0, 20)) -- dehors, devant sa porte
	step(0.6)
	check(stateOk(p5, 5, "CollectCash", P5.cashPad), "étape 5, dehors : flèche sur la plaque d'encaissement, pas sur la porte " .. describe(p5))
	local p7, d7, P7 = resumeAt("Door7", 613, 7)
	d7.Cash = 300
	step(0.6)
	check(stateOk(p7, 7, nil, WEAPON_SHOP), "étape 7, dans sa boutique, 300 $ : flèche sur la boutique d'armes " .. describe(p7))
	d7.Cash = 10
	moveTo(p7, P7.door - Vector3.new(0, 0, 20))
	step(0.6)
	check(stateOk(p7, 7, "CollectCash", P7.cashPad), "étape 7, dehors, 10 $ : flèche sur la plaque " .. describe(p7))
	local p13, _, P13 = resumeAt("Door13", 614, 12)
	moveTo(p13, BOT_DOOR)
	step(0.1)
	botGrab(p13, 1)
	step(0.6)
	check(stateOk(p13, 13, nil, P13.spawn), "étape 13, dehors avec l'objet du bot : flèche dans sa boutique (SpawnPoint) " .. describe(p13))
	NIGHT_PHASE = "Warning"
	moveTo(p13, Vector3.new(60, 3, 0)) -- couloir
	step(0.6)
	check(stateOk(p13, 13, "Night", P13.spawn), "alerte de nuit dans le couloir : flèche dans sa boutique " .. describe(p13))
	NIGHT_PHASE = "Day"
	step(0.1)
end

print("== A197-E. Passer : une étape à la fois")
do
	local sam, data, S = resumeAt("Sam", 621, 5)
	check(TutorialService.GetStep(sam) == 5, "Sam à l'étape 5")
	local cash, items = data.Cash, 0
	for _ in data.Items do
		items += 1
	end
	skip(sam)
	check(TutorialService.GetStep(sam) == 6 and data.Tutorial.Step == 6 and data.Tutorial.Done == false and stateOk(sam, 6, "StandOnTreadmill", S.treadmill), "Passer à 5 : étape 6, avec sa flèche vers le tapis " .. describe(sam))
	skip(sam)
	check(TutorialService.GetStep(sam) == 7 and data.Tutorial.Step == 7, "Passer à 6 : étape 7 " .. describe(sam))
	skip(sam)
	local owned = table.concat(data.Tools.Owned, ",")
	check(TutorialService.GetStep(sam) == 8 and owned == "Fists" and data.Cash == cash, `Passer à 7 : étape 8, sans clé à molette donnée ni argent pris ({owned}, {data.Cash} $)`)
	skip(sam)
	check(TutorialService.GetStep(sam) == 9 and #data.Cosmetics.Auras == 0, "Passer à 8 : étape 9, sans aura donnée")
	skip(sam)
	check(TutorialService.GetStep(sam) == 10, "Passer à 9 : étape 10 (bouclier encore actif : elle attend)")
	skip(sam)
	check(TutorialService.GetStep(sam) == 11 and data.Tutorial.Step == 11 and stateOk(sam, 11, nil, BOT_DOOR), "Passer à 10, bot présent : étape 11, flèche vers sa porte " .. describe(sam))
	skip(sam)
	check(TutorialService.GetStep(sam) == 12 and data.Tutorial.Step == 12, "Passer à 11 : étape 12 " .. describe(sam))
	skip(sam)
	check(data.Tutorial.Done == true and data.Tutorial.Step == 12 and stateOk(sam, 12, "ProtectShop", nil), "Passer à 12 (13 demande l'objet du bot) : fin du tuto, ProtectShop " .. describe(sam))
	local n = 0
	for _ in data.Items do
		n += 1
	end
	check(n == items, "Passer ne donne aucun objet")
	skip(sam)
	check(stateOk(sam, 0, nil, nil) and not TutorialService.IsActive(sam), "Passer pendant ProtectShop : tout caché " .. describe(sam))

	-- Étape 14 : le bot poursuit ; Passer → 13, et la poursuite ne ramène pas à 14.
	local zoe, dz = resumeAt("Zoe", 622, 12)
	moveTo(zoe, BOT_DOOR)
	BOT_CHASING[zoe] = true
	botGrab(zoe, 2)
	step(0.6)
	check(TutorialService.GetStep(zoe) == 14, "Zoe : objet du bot pris pendant la poursuite : étape 14")
	skip(zoe)
	step(0.6)
	check(TutorialService.GetStep(zoe) == 13 and dz.Tutorial.Step == 13 and dz.Tutorial.Done == false, "Passer à 14 : étape 13, même poursuivie " .. describe(zoe))
	botFail(zoe, "Bat")
	step(0.6)
	check(TutorialService.GetStep(zoe) == 12, "objet perdu : retour à 12")
	botGrab(zoe, 3)
	step(0.6)
	check(TutorialService.GetStep(zoe) == 14, "repris pendant la poursuite : de nouveau 14 (Passer ne compte que pour une étape)")
	BOT_CHASING[zoe] = nil
	step(0.6)
	check(TutorialService.GetStep(zoe) == 13, "semé : 13")
	skip(zoe)
	check(dz.Tutorial.Done == true and stateOk(zoe, 13, "ProtectShop", nil), "Passer à 13 (dernière étape) : fin du tuto " .. describe(zoe))

	-- Sans bot : Passer à 10 finit le tuto.
	botLeave()
	step(0.1)
	local lea, dl = resumeAt("Lea", 623, 10)
	step(0.1)
	skip(lea)
	check(dl.Tutorial.Done == true and dl.Tutorial.Step == 10 and stateOk(lea, 10, "ProtectShop", nil), "sans bot, Passer à 10 : fin du tuto " .. describe(lea))
	botArrive(BOT_SHOP)
	step(0.1)

	-- Avant l'étape 5 : refusé.
	local max, dm = resumeAt("Max", 624, 1, function(d)
		d.Items = {}
		d.Lifetime.Heists = 0
	end)
	skip(max)
	check(TutorialService.GetStep(max) == 1 and dm.Tutorial.Step == 1 and dm.Tutorial.Done == false, "Passer à l'étape 1 : refusé")

	-- Reprise : l'étape passée compte comme faite.
	local saved = DEEPCOPY(data)
	local ben, db = resumeAt("Ben", 625, 6)
	skip(ben)
	local copy = DEEPCOPY(db)
	local back = makePlayer("Ben2", 626, Vector3.new(0, 3, 0))
	local plot = walledPlot(-900, -150)
	PROFILES[back] = copy
	SHIELD[back] = true
	assignPlot(back, plot)
	step(0.6)
	check(TutorialService.GetStep(back) == 7 and copy.Tutorial.Done == false, "reprise après Passer à 6 : étape 7 " .. describe(back))
	local _ = saved
end

print("== A197-F. Client : liste des tâches")
do
	local function state()
		return Controller.GetState()
	end
	-- Repli V0 (pas d'UI_Tutorial) : panneau Tasks gris aux noms proposés.
	REMOTES.TutorialStep:FireClient(ALICE, 7, "CollectCash", A_PAD or Vector3.new(0, 1, 0), 100, 300)
	step(0.3)
	local st = state()
	local v0 = PLAYER_GUI:FindFirstChild("TutorialV0")
	local tasks = v0 and v0:FindFirstChild("Tasks", true)
	local t5 = tasks and tasks:FindFirstChild("Task_5")
	check(st.Shown and st.Fallback and st.Text == Tutorial.Hints.CollectCash and #st.Tasks == 5, "repli V0, étape 7 : la bulle CollectCash et 5 lignes " .. tostring(st.Text))
	check(t5 ~= nil and t5.Visible and t5:FindFirstChild("Goal").Text == "Buy the Wrench" and t5:FindFirstChild("Progress").Text == "Earn cash: $100 / $300 to buy the Wrench" and t5:FindFirstChild("Progress").Visible and t5:FindFirstChild("Why").Visible and not t5:FindFirstChild("Check").Visible, "Task_5 : but, progression, raison, pas cochée")
	local t2 = tasks and tasks:FindFirstChild("Task_2")
	local t6 = tasks and tasks:FindFirstChild("Task_6")
	check(t2 ~= nil and t2:FindFirstChild("Check").Visible and not t2:FindFirstChild("Progress").Visible and t6 ~= nil and not t6:FindFirstChild("Check").Visible and not t6:FindFirstChild("Why").Visible, "Task_2 cochée, Task_6 à venir sans raison ni progression")
	local template = tasks and tasks:FindFirstChild("Template")
	check(template ~= nil and template.Visible == false, "Template du repli invisible")
	REMOTES.TutorialStep:FireClient(ALICE, 7, "CollectCash", Vector3.new(0, 1, 0), 250, 300)
	step(0.3)
	check(t5.Parent == nil and tasks:FindFirstChild("Task_5"):FindFirstChild("Progress").Text == "Earn cash: $250 / $300 to buy the Wrench", "l'argent monte : 250 / 300")
	-- Étape 10 : pas de bulle, la liste dit ce qu'il reste.
	REMOTES.TutorialStep:FireClient(ALICE, 10, nil, nil, 360, 600)
	step(0.3)
	check(state().Shown and state().Text == "Beginner protection ends in 4:00", "étape 10 sans bulle : « " .. tostring(state().Text) .. " »")

	-- Écran de Clément sans Tasks : la tâche et sa progression sous la bulle.
	local screen = new("ScreenGui", { Name = "UI_Tutorial", Enabled = false })
	local bubble = new("Frame", { Name = "Bubble" }, screen)
	local label = new("TextLabel", { Name = "Label", Text = "" }, bubble)
	new("TextButton", { Name = "NextButton", Visible = true, Text = "Next" }, screen)
	screen.Parent = PLAYER_GUI
	REMOTES.TutorialStep:FireClient(ALICE, 7, "CollectCash", Vector3.new(0, 1, 0), 100, 300)
	step(0.3)
	check(PLAYER_GUI:FindFirstChild("TutorialV0") == nil and label.Text == Tutorial.Hints.CollectCash .. "\nBuy the Wrench (5/10): Earn cash: $100 / $300 to buy the Wrench", "Clément sans Tasks : « " .. label.Text .. " »")
	REMOTES.TutorialStep:FireClient(ALICE, 10, nil, nil, 360, 600)
	step(0.3)
	check(screen.Enabled and label.Text == "Get ready for PvP (8/10): Beginner protection ends in 4:00", "Clément sans Tasks, étape 10 : « " .. label.Text .. " »")

	-- Écran de Clément avec Tasks.Template : une copie par ligne (LayoutOrder = numéro de la tâche).
	do
		local base = PROPS.Frame
		PROPS.Frame = function(...)
			local t = base(...)
			if t.LayoutOrder == nil then
				t.LayoutOrder = 0 -- ajout pur : le faux Frame n'avait pas LayoutOrder
			end
			return t
		end
	end
	local list = new("Frame", { Name = "Tasks" }, screen)
	local row = new("Frame", { Name = "Template", Visible = false }, list)
	new("TextLabel", { Name = "Goal", Text = "Goal" }, row)
	new("Frame", { Name = "Check", Visible = false }, row)
	new("TextLabel", { Name = "Progress", Text = "" }, row)
	new("TextLabel", { Name = "Why", Text = "" }, row)
	REMOTES.TutorialStep:FireClient(ALICE, 7, "CollectCash", Vector3.new(0, 1, 0), 100, 300)
	step(0.3)
	local c5 = list:FindFirstChild("Task_5")
	local count = 0
	for _, child in list:GetChildren() do
		if child.Name ~= "Template" then
			count += 1
		end
	end
	check(count == 5 and c5 ~= nil and c5.LayoutOrder == 5 and c5.Visible and c5:FindFirstChild("Progress").Text == "Earn cash: $100 / $300 to buy the Wrench", "Clément avec Tasks : 5 copies, Task_5 LayoutOrder 5 et sa progression")
	check(label.Text == Tutorial.Hints.CollectCash and row.Visible == false, "avec Tasks : la bulle garde son texte seul, Template intact (invisible)")
	REMOTES.TutorialStep:FireClient(ALICE, 13, "ProtectShop", nil)
	step(0.3)
	local allDone = true
	for _, child in list:GetChildren() do
		if child.Name ~= "Template" and not child:FindFirstChild("Check").Visible then
			allDone = false
		end
	end
	check(allDone and label.Text == Tutorial.Hints.ProtectShop, "fin du tuto (ProtectShop) : toutes les tâches cochées")
	REMOTES.TutorialStep:FireClient(ALICE, 0)
	step(0.3)
	check(screen.Enabled == false and #state().Tasks == 0, "tuto fini : écran et liste cachés")
end

print("== A197-L. Sortie")
check(not logHas("mal formé", "WARN"), "aucun envoi de remote mal formé")
check(not logHas("contrôle :", "WARN", "server"), "aucune erreur dans le contrôle régulier")
summary()
