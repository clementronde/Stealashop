-- Scénarios du banc d'essai a09 (après fake.luau).

local function marker(name, time, value)
	return { name = name, time = time, value = value or "" }
end

---------------------------------------------------------------------------------
section("AnimPlayer : dossier absent, noms absents, ID vides")
do
	local w = newWorld(true)
	local AnimPlayer = w.require("AnimPlayer")
	local Animations = w.require("Animations")
	local character, humanoid, animator = newCharacter()
	character.Parent = w.WS
	clearLog()
	local anims = AnimPlayer.new(animator, nil, Animations.Player, "Joueur")
	check(anims:Play("HitWindow") == nil, "dossier absent : Play renvoie nil")
	check(anims:Play("HitWindow") == nil, "dossier absent : 2e Play renvoie nil")
	check(countLog("« HitWindow » non jouée", "warn") == 1, "un seul avertissement pour HitWindow")
	check(anims:OnMarker("HitWindow", "Impact", function() end) ~= nil, "OnMarker sans dossier : pas d'erreur")
	anims:Stop("HitWindow")
	anims:StopAll()
	check(anims:IsPlaying("HitWindow") == false, "IsPlaying faux")

	local folder = newFolder(w.RS, "Animations")
	addAnimation(folder, "A", "rbxassetid://1", { length = 1, loop = false, markers = {} })
	addAnimation(folder, "Vide", "rbxassetid://", nil)
	addAnimation(folder, "Vide2", "http://www.roblox.com/asset/?id=", nil)
	addAnimation(folder, "Vide3", "", nil)
	newFolder(folder, "PasUneAnim")
	local p = AnimPlayer.new(animator, folder, nil, "Essai")
	clearLog()
	check(p:Play("Vide") == nil and p:Play("Vide2") == nil and p:Play("Vide3") == nil, "ID vides : rien")
	check(countLog("AnimationId vide", "warn") == 3, "3 avertissements ID vide")
	check(p:Play("PasUneAnim") == nil, "objet pas Animation : rien")
	check(countLog("pas un objet Animation", "warn") == 1, "avertissement mauvaise classe")
	check(p:Play("A") ~= nil, "A se joue")
	check(animator._loads == 1, "une seule piste chargée")
	p:Play("A")
	check(animator._loads == 1, "cache : pas de second chargement")
end

---------------------------------------------------------------------------------
section("AnimPlayer : boucle continue, sans boucle repart, marqueurs, Destroy")
do
	local w = newWorld(true)
	local AnimPlayer = w.require("AnimPlayer")
	local Animations = w.require("Animations")
	local character, humanoid, animator = newCharacter()
	character.Parent = w.WS
	local folder = newFolder(w.RS, "Animations")
	addAnimation(folder, "TreadmillRun", "rbxassetid://10", { length = 1, loop = true, markers = {} })
	addAnimation(folder, "BenchLift", "rbxassetid://11", { length = 1, loop = false, markers = { marker("Top", 0.5, "haut") } })
	local anims = AnimPlayer.new(animator, folder, Animations.Player, "Joueur")

	local hits, lastParam = 0, nil
	local off = anims:OnMarker("BenchLift", "Top", function(param)
		hits += 1
		lastParam = param
	end)
	check(animator._loads == 1, "OnMarker charge la piste")

	local tr = anims:Play("TreadmillRun")
	runFor(0.3)
	local pos = tr.TimePosition
	anims:Play("TreadmillRun")
	check(tr.TimePosition == pos and tr.IsPlaying, "boucle déjà en cours : continue")

	local bl = anims:Play("BenchLift")
	runFor(0.6)
	check(hits == 1 and lastParam == "haut", "marqueur Top reçu avec sa valeur")
	check(bl.IsPlaying and bl.TimePosition > 0.5, "BenchLift en cours")
	anims:Play("BenchLift")
	check(bl.TimePosition == 0, "sans boucle déjà en cours : repart du début")
	runFor(0.6)
	check(hits == 2, "marqueur repassé après le redémarrage")
	runFor(0.6)
	check(not bl.IsPlaying, "BenchLift finie")
	off()
	anims:Play("BenchLift")
	runFor(1.2)
	check(hits == 2, "débranché : plus d'appel")

	-- Branchement avant l'arrivée de l'animation.
	local late = 0
	anims:OnMarker("Unbox", "Open", function() late += 1 end)
	addAnimation(folder, "Unbox", "rbxassetid://12", { length = 0.5, loop = false, markers = { marker("Open", 0.2) } })
	local ub = anims:Play("Unbox")
	runFor(0.6)
	check(late == 1, `marqueur branché avant livraison : reçu au premier chargement (reçu {late}, piste {ub and ub._plays}, signaux {ub and ub._markerSignals.Open and ub._markerSignals.Open:count()})`)

	anims:StopAll()
	check(not tr.IsPlaying, "StopAll arrête la boucle")

	-- Destruction de l'Animator : Destroy automatique.
	local after = 0
	anims:OnMarker("BenchLift", "Top", function() after += 1 end)
	animator:Destroy()
	check(anims:Play("BenchLift") == nil, "Animator détruit : Play ne fait rien")
	anims:Destroy()
	check(true, "Destroy deux fois : sans erreur")
end

---------------------------------------------------------------------------------
section("AnimPlayer : préchargement et waitForAnimator")
do
	local w = newWorld(true)
	local AnimPlayer = w.require("AnimPlayer")
	local Animations = w.require("Animations")
	local folder = newFolder(w.RS, "Animations")
	addAnimation(folder, "HitWindow", "rbxassetid://20", { length = 1, loop = false, markers = {} })
	addAnimation(folder, "Grab", "rbxassetid://21", nil) -- ID illisible (compte perso)
	addAnimation(folder, "Place", "rbxassetid://", nil)
	clearLog()
	local n = AnimPlayer.preload(folder, { "HitWindow", "Grab", "Place", "Absente" })
	check(n == 1, `préchargées sans erreur : 1 (obtenu {n})`)
	check(countLog("chargement refusé pour Grab", "warn") == 1, "échec de préchargement signalé")
	check(#PRELOADED == 2, "Place (ID vide) et Absente ne sont pas envoyées")
	local all = AnimPlayer.preload(folder, nil)
	check(all == 1, "préchargement du dossier entier")

	local w2 = newWorld(false)
	local AnimPlayerServer = w2.require("AnimPlayer")
	check(AnimPlayerServer.preload(newFolder(w2.RS, "F"), nil) == 0, "serveur : pas de préchargement")

	local character, humanoid, animator = newCharacter()
	local got
	runTask(function()
		got = AnimPlayer.waitForAnimator(character, 1)
	end, 3)
	check(got == nil, "personnage hors du jeu : nil après le délai")
	character.Parent = w.WS
	runTask(function()
		got = AnimPlayer.waitForAnimator(character, 1)
	end, 3)
	check(got == animator, "personnage dans le jeu : Animator trouvé")

	local bare = Instance.new("Model")
	bare.Parent = w.WS
	local hum = Instance.new("Humanoid")
	hum.Name = "Humanoid"
	runTask(function()
		got = AnimPlayer.waitForAnimator(bare, 0.5)
	end, 3)
	check(got == nil, "sans Humanoid : nil")
	hum.Parent = bare
	runTask(function()
		got = AnimPlayer.waitForAnimator(bare, 0.5)
	end, 3)
	check(got == nil, "sans Animator : nil, jamais créé")
	check(hum:FindFirstChildOfClass("Animator") == nil, "aucun Animator créé")

	check(AnimPlayer.playerFolder() == nil, "dossier joueur absent : nil")
	local assets = newFolder(w.RS, "Assets")
	local anims = newFolder(assets, "Animations")
	local pf = newFolder(anims, "Player")
	check(AnimPlayer.playerFolder() == pf, "dossier joueur trouvé")
	local guard = Instance.new("Model")
	local gf = newFolder(guard, "Animations")
	check(AnimPlayer.modelFolder(guard) == gf, "dossier d'un modèle animé")
end

---------------------------------------------------------------------------------
section("MarkerSounds : registre, recherche, lecture")
do
	local w = newWorld(true)
	local MarkerSounds = w.require("MarkerSounds")
	local Animations = w.require("Animations")
	clearLog()
	check(MarkerSounds.check(MarkerSounds.Player, Animations.Player, "Player") == 0, "registre joueur conforme au contrat")
	check(MarkerSounds.check(MarkerSounds.Guard, Animations.Guard, "Guard") == 0, "registre vigile conforme au contrat")
	check(
		MarkerSounds.check({ { Anim = "HitWindow", Marker = "Impakt", Sound = "x" } }, Animations.Player, "Essai") == 1,
		"faute de frappe détectée"
	)
	local withMarker = 0
	for _, spec in Animations.Player do
		if spec.Marker then
			withMarker += 1
		end
	end
	check(#MarkerSounds.Player == withMarker, `registre : une entrée par marqueur du joueur ({withMarker})`)

	clearLog()
	check(MarkerSounds.play("Unbox_Open", nil) == nil, "son absent : rien")
	MarkerSounds.play("Unbox_Open", nil)
	check(countLog("son « Unbox_Open » absent", "warn") == 1, "un seul avertissement par son absent")

	local assets = newFolder(w.RS, "Assets")
	local sounds = newFolder(assets, "Sounds")
	local sub = newFolder(sounds, "Joueur")
	SOUND_LENGTH["rbxassetid://500"] = 0.3
	addSound(sub, "BenchLift_Top", "rbxassetid://500")
	local part = Instance.new("Part")
	part.Name = "HumanoidRootPart"
	part.Parent = w.WS
	local played = MarkerSounds.play("BenchLift_Top", part)
	check(played ~= nil and played.Parent == part and played.IsPlaying, "son trouvé en sous-dossier, joué sur la Part")
	runFor(0.6)
	check(played.Parent == nil, "copie supprimée à la fin du son")
	local flat = MarkerSounds.play("BenchLift_Top", nil)
	check(flat.Parent and flat.Parent.Name == "SoundService", "sans Part : SoundService")
end

---------------------------------------------------------------------------------
section("AnimationController : entraînement, marqueurs, portage, réapparition")
do
	local w = newWorld(true)
	local assets = newFolder(w.RS, "Assets")
	local animsFolder = newFolder(assets, "Animations")
	local pf = newFolder(animsFolder, "Player")
	addAnimation(pf, "TreadmillRun", "rbxassetid://30", { length = 1, loop = true, markers = {} })
	addAnimation(pf, "BenchLift", "rbxassetid://31", { length = 0.8, loop = false, markers = { marker("Top", 0.4) } })
	addAnimation(pf, "CarryIdle", "rbxassetid://32", { length = 1, loop = true, markers = {} })
	addAnimation(pf, "CarryRun", "rbxassetid://33", { length = 1, loop = true, markers = {} })
	local sounds = newFolder(assets, "Sounds")
	SOUND_LENGTH["rbxassetid://600"] = 0.2
	addSound(sounds, "BenchLift_Top", "rbxassetid://600")

	local character, humanoid, animator, hrp = newCharacter("Ironix")
	rawset(w.player, "Character", character)
	character.Parent = w.WS
	w.player:SetAttribute("BenchReps", 4)

	local AC = require(w.controllerModule)
	check(AC.PlayPlayer("TreadmillRun") == nil, "avant Start : PlayPlayer renvoie nil sans erreur")
	local early = 0
	AC.OnMarker("BenchLift", "Top", function() early += 1 end)

	clearLog()
	local done = runTask(function()
		AC.Start()
	end, 5)
	check(done, "Start se termine")
	runFor(0.2)
	check(countLog("4/14 animation(s) préchargée(s)", "print") == 1, "préchargement : 4/14 (BenchIdle ajoutée)")
	check(animator._loads == 4, `à l'apparition : les 4 animations livrées chargées tout de suite (obtenu {animator._loads})`)
	check(countLog("MarkerSounds", "warn") == 0, "registre sans faute")

	-- Tapis
	w.player:SetAttribute("TrainingMachine", "Treadmill")
	local tr = AC.PlayPlayer("TreadmillRun")
	check(tr and tr.IsPlaying, "TreadmillRun joue sur le tapis")
	runFor(0.3)
	w.player:SetAttribute("TrainingMachine", nil)
	check(tr and not tr.IsPlaying, "TreadmillRun s'arrête en quittant le tapis")

	-- Banc
	w.player:SetAttribute("TrainingMachine", "Bench")
	local before = #SOUND_LOG
	w.player:SetAttribute("BenchReps", 5)
	local bl = AC.PlayPlayer("BenchLift") -- renvoie la piste en cours (et la relance)
	runFor(0.5)
	check(bl and bl._plays == 1, "BenchLift jouée une fois à la hausse de BenchReps")
	check(early == 1, "branchement fait avant Start : reçu")
	check(#SOUND_LOG == before + 1 and SOUND_LOG[#SOUND_LOG].parent == "HumanoidRootPart", "son BenchLift_Top joué sur le personnage")
	w.player:SetAttribute("BenchReps", 0)
	runFor(1)
	check(bl._plays == 1, "BenchReps qui retombe à 0 : pas d'animation")

	-- Marqueur sans son livré
	clearLog()
	addAnimation(pf, "Unbox", "rbxassetid://34", { length = 0.5, loop = false, markers = { marker("Open", 0.2) } })
	AC.PlayPlayer("Unbox")
	runFor(0.4)
	check(countLog("son « Unbox_Open » absent", "warn") == 1, "son absent signalé au passage du marqueur")

	-- Animation non livrée
	clearLog()
	check(AC.PlayPlayer("HitWindow") == nil, "HitWindow non livrée : nil")
	AC.PlayPlayer("HitWindow")
	check(countLog("« HitWindow » non jouée", "warn") == 1, "un seul avertissement")

	-- Portage
	AC.SetCarrying(true)
	local idle = AC.PlayPlayer("CarryIdle")
	check(idle and idle.IsPlaying, "à l'arrêt : CarryIdle")
	humanoid.Running:Fire(12)
	local run = AC.PlayPlayer("CarryRun")
	check(run and run.IsPlaying and not idle.IsPlaying, "en mouvement : CarryRun à la place de CarryIdle")
	humanoid.Running:Fire(0)
	check(idle.IsPlaying and not run.IsPlaying, "arrêt : retour à CarryIdle")
	AC.SetCarrying(false)
	check(not idle.IsPlaying and not run.IsPlaying, "fin du portage : les deux arrêtées")
	humanoid.Running:Fire(12)
	check(not run.IsPlaying, "hors portage : Running ne joue rien")

	-- Réapparition : nouveau personnage, branchements suivis, portage rejoué
	local count = 0
	local off = AC.OnMarker("BenchLift", "Top", function() count += 1 end)
	AC.SetCarrying(true)
	local c2, h2, a2, hrp2 = spawnCharacter(w, "Ironix2")
	runFor(0.2)
	check(a2._loads > 0, "nouveau personnage : pistes chargées sur le nouvel Animator")
	local idle2 = AC.PlayPlayer("CarryIdle")
	check(idle2 and idle2.IsPlaying and idle2 ~= idle, "portage rejoué sur le nouveau personnage")
	w.player:SetAttribute("BenchReps", 1)
	runFor(0.6)
	check(count == 1 and early == 2, "branchements suivis d'une vie à l'autre")
	off()
	w.player:SetAttribute("BenchReps", 2)
	runFor(0.9)
	check(count == 1 and early == 3, "débranché : plus d'appel ; l'autre continue")
	local loadsOld = animator._loads
	check(character.Parent == nil, "ancien personnage parti")
	AC.SetCarrying(false)
end

---------------------------------------------------------------------------------
section("AnimTest : animation de remplacement (Test pas livrée)")
do
	local w = newWorld(true)
	local character, humanoid, animator = newCharacter("Ironix")
	rawset(w.player, "Character", character)
	character.Parent = w.WS
	w.WS:SetAttribute("AnimTest", true)
	local AC = require(w.controllerModule)
	clearLog()
	runTask(function()
		AC.Start()
	end, 5)
	runFor(12)
	check(countLog("animation « Test » : de remplacement", "print") == 1, "remplacement fabriqué en code")
	if countLog("marqueur « Test » atteint (valeur", "print") ~= 3 then dumpLog() end
	check(countLog("marqueur « Test » atteint (valeur", "print") == 3, `marqueur atteint 3 fois (obtenu {countLog("marqueur « Test » atteint (valeur", "print")})`)
	check(countLog("[Anim test] OK", "print") == 1, "verdict OK")
	if countLog("[Anim test] OK", "print") ~= 1 then
		dumpLog()
	end
	check(countLog("ÉCHEC", "warn") == 0, "aucun échec")
	w.WS:SetAttribute("AnimTest", nil)
	runFor(1)
end

section("AnimTest : animation Test livrée, sans puis avec marqueur ; refus du remplacement")
do
	local w = newWorld(true)
	local assets = newFolder(w.RS, "Assets")
	local animsFolder = newFolder(assets, "Animations")
	local pf = newFolder(animsFolder, "Player")
	addAnimation(pf, "Test", "rbxassetid://77", { length = 1, loop = false, markers = { marker("Test", 0.5, "clement") } })
	addAnimation(pf, "CarryIdle", "rbxassetid://78", { length = 1, loop = true, markers = {} })
	addAnimation(pf, "Grab", "rbxassetid://79", { length = 0.6, loop = false, markers = {} })
	local character = newCharacter("Ironix")
	rawset(w.player, "Character", character)
	character.Parent = w.WS
	local AC = require(w.controllerModule)
	runTask(function()
		AC.Start()
	end, 5)
	clearLog()
	w.WS:SetAttribute("AnimTest", true)
	runFor(10)
	check(countLog("livrée, ReplicatedStorage.Assets.Animations.Player.Test", "print") == 1, "Test livrée utilisée")
	check(countLog("valeur « clement »", "print") == 3, "marqueur de Clément atteint 3 fois")
	check(countLog("[Anim test] OK", "print") == 1, "verdict OK avec la vraie animation")

	clearLog()
	w.WS:SetAttribute("AnimTest", "CarryIdle")
	runFor(25)
	check(countLog("pas de marqueur au contrat", "print") == 1, "boucle sans marqueur : fini sans son")

	clearLog()
	w.WS:SetAttribute("AnimTest", "Grab")
	runFor(10)
	check(countLog("n'a jamais été atteint", "warn") == 1, "marqueur Grab absent de l'animation : ÉCHEC")

	clearLog()
	w.WS:SetAttribute("AnimTest", "HitWindow")
	runFor(2)
	check(countLog("« HitWindow » introuvable", "warn") == 1, "animation absente : ÉCHEC clair")

	-- Interruption : on change l'attribut pendant un test
	clearLog()
	w.WS:SetAttribute("AnimTest", true)
	runFor(1)
	w.WS:SetAttribute("AnimTest", nil)
	runFor(10)
	check(countLog("interrompu", "print") == 1, "test interrompu proprement")
	check(countLog("[Anim test] OK", "print") == 0, "pas de verdict après interruption")
end

section("AnimTest : Studio refuse RegisterKeyframeSequence")
do
	local w = newWorld(true)
	KSP_REFUSE = true
	local character = newCharacter("Ironix")
	rawset(w.player, "Character", character)
	character.Parent = w.WS
	w.WS:SetAttribute("AnimTest", true)
	local AC = require(w.controllerModule)
	clearLog()
	runTask(function()
		AC.Start()
	end, 5)
	runFor(2)
	check(countLog("Studio refuse l'animation de remplacement", "warn") == 1, "refus signalé avec la marche à suivre")
	KSP_REFUSE = false
end

section("AnimTest : en attente du personnage, puis réapparition")
do
	local w = newWorld(true)
	w.WS:SetAttribute("AnimTest", true)
	local AC = require(w.controllerModule)
	clearLog()
	runTask(function()
		AC.Start()
	end, 5)
	check(countLog("en attente du personnage", "print") == 1, "pas de personnage : attente")
	spawnCharacter(w, "Ironix")
	runFor(10)
	check(countLog("[Anim test] OK", "print") == 1, "test lancé à l'apparition")
end

section("AnimTest : animation Test illisible (publiée hors du groupe)")
do
	local w = newWorld(true)
	local assets = newFolder(w.RS, "Assets")
	local pf = newFolder(newFolder(assets, "Animations"), "Player")
	addAnimation(pf, "Test", "rbxassetid://404", nil)
	local character = newCharacter("Ironix")
	rawset(w.player, "Character", character)
	character.Parent = w.WS
	w.WS:SetAttribute("AnimTest", true)
	local AC = require(w.controllerModule)
	clearLog()
	runTask(function()
		AC.Start()
	end, 5)
	runFor(30)
	check(countLog("chargement refusé pour Test", "warn") == 1, "préchargement refusé signalé")
	check(countLog("jamais chargée (durée 0 s)", "warn") == 1, "verdict : animation jamais chargée")
	check(countLog("[Anim test] OK", "print") == 0, "pas de faux OK")
end

section("Hors Studio : aucun avertissement, aucun mode test")
do
	local w = newWorld(true)
	rawset(w.dm:GetService("RunService"), "IsStudio", function() return false end)
	local character = newCharacter("Ironix")
	rawset(w.player, "Character", character)
	character.Parent = w.WS
	w.WS:SetAttribute("AnimTest", true)
	local AC = require(w.controllerModule)
	clearLog()
	runTask(function()
		AC.Start()
	end, 5)
	runFor(3)
	check(AC.PlayPlayer("HitWindow") == nil, "animation absente : nil")
	check(#LOG == 0, `rien dans la sortie hors Studio (obtenu {#LOG} ligne(s))`)
end

report()
