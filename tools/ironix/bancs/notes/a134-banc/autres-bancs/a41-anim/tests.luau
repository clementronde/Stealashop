-- Banc a41 (2026-11-08, liaison L-071, points 3 et 4), partie animations :
--   AnimationController : Grab pose le colis, puis CarryIdle / CarryRun prennent sa suite (AfterGrab),
--   BenchLift pas relancé en pleine répétition, TreadmillRun suit TrainingMachine ;
--   CarryController : le colis du porteur reste caché jusqu'au geste de Grab (marqueur Grab).
-- Faux Roblox : fake.luau (copie de celui d'a09, complétée par a41).

local function marker(name, time, value)
	return { name = name, time = time, value = value }
end

-- Monde neuf, dossier des animations du joueur, et un personnage dont on suit les pistes chargées
-- (tracks[nom] = dernière piste chargée pour ce nom), sans rien jouer.
local function setup(animations)
	local w = newWorld(true)
	local assets = newFolder(w.RS, "Assets")
	local pf = newFolder(newFolder(assets, "Animations"), "Player")
	for name, spec in animations do
		addAnimation(pf, name, spec.id, spec)
	end
	w.tracks = {}
	return w
end
local function spawnTracked(w, name)
	local old = w.player.Character
	if old then
		w.player.CharacterRemoving:Fire(old)
		old:Destroy()
	end
	local character, humanoid, animator, hrp = newCharacter(name or "Ironix")
	local load = animator.LoadAnimation
	rawset(animator, "LoadAnimation", function(a, animation)
		local t = load(a, animation)
		w.tracks[animation.Name] = t
		return t
	end)
	rawset(w.player, "Character", character)
	character.Parent = w.WS
	w.player.CharacterAdded:Fire(character)
	return character, humanoid, animator, hrp
end
local function startAC(w)
	local AC = require(w.controllerModule)
	check(runTask(function()
		AC.Start()
	end, 5), "AnimationController.Start se termine")
	runFor(0.1)
	return AC
end
local function playing(w, name)
	local t = w.tracks[name]
	return t ~= nil and t.IsPlaying
end

local GRAB_MARKED = { id = "rbxassetid://40", length = 0.6, loop = false, markers = { marker("Grab", 0.3) } }
local CARRY_IDLE = { id = "rbxassetid://32", length = 1, loop = true, markers = {} }
local CARRY_RUN = { id = "rbxassetid://33", length = 1, loop = true, markers = {} }

---------------------------------------------------------------------------------
section("A1 Sans Grab en cours : AfterGrab tout de suite, portage comme avant")
do
	local w = setup({ CarryIdle = CARRY_IDLE, CarryRun = CARRY_RUN })
	local _, humanoid, _, hrp = spawnTracked(w)
	local AC = startAC(w)
	local called, from = 0, nil
	local deferred = AC.AfterGrab(function(f)
		called += 1
		from = f
	end)
	check(deferred == false and called == 1 and from == false, "AfterGrab sans Grab : appelé tout de suite, avec false, renvoie false")
	AC.SetCarrying(true)
	check(playing(w, "CarryIdle"), "SetCarrying(true) : CarryIdle tout de suite")
	rawset(hrp, "AssemblyLinearVelocity", Vector3.new(12, 0, 0))
	humanoid.Running:Fire(12)
	check(playing(w, "CarryRun") and not playing(w, "CarryIdle"), "en courant : CarryRun")
	AC.SetCarrying(false)
	check(not playing(w, "CarryRun") and not playing(w, "CarryIdle"), "SetCarrying(false) : tout s'arrête")
	-- Grab pas livrée : PlayPlayer rend nil, le portage n'attend rien.
	rawset(hrp, "AssemblyLinearVelocity", Vector3.new(0, 0, 0))
	check(AC.PlayPlayer("Grab") == nil, "Grab pas livrée : nil")
	AC.SetCarrying(true)
	check(playing(w, "CarryIdle"), "Grab pas livrée : CarryIdle tout de suite")
	AC.SetCarrying(false)
end

---------------------------------------------------------------------------------
section("A2 Grab avec marqueur Grab (0,3 s) : la boucle de portage attend le marqueur")
do
	local w = setup({ Grab = GRAB_MARKED, CarryIdle = CARRY_IDLE, CarryRun = CARRY_RUN })
	spawnTracked(w)
	local AC = startAC(w)
	local grab = AC.PlayPlayer("Grab")
	check(grab ~= nil and grab.IsPlaying, "Grab joue (lancé au ramassage)")
	runFor(0.05)
	local calls = {}
	local deferred = AC.AfterGrab(function(f)
		table.insert(calls, { t = os.clock(), from = f })
	end)
	check(deferred == true and #calls == 0, "AfterGrab pendant Grab : différé")
	AC.SetCarrying(true) -- l'attribut Carrying arrive (le serveur a accepté la prise)
	check(not playing(w, "CarryIdle"), "pendant Grab : pas encore de CarryIdle (pas de mélange de deux pistes Action)")
	local t0 = os.clock()
	runFor(0.15)
	check(not playing(w, "CarryIdle") and #calls == 0, "toujours en attente avant le marqueur")
	runFor(0.15)
	check(playing(w, "CarryIdle"), "au marqueur Grab : CarryIdle")
	check(not grab.IsPlaying, "Grab s'efface (fondu) quand la boucle prend sa suite")
	check(#calls == 1 and calls[1].from == true, "AfterGrab appelé une fois, au marqueur (fromGrab = true)")
	check(#calls == 1 and math.abs(calls[1].t - (t0 + 0.25)) <= 0.051, `au marqueur : 0,3 s après le lancement de Grab ({#calls > 0 and calls[1].t - t0 + 0.05})`)
	local again = 0
	check(AC.AfterGrab(function() again += 1 end) == false and again == 1, "après le marqueur : AfterGrab tout de suite")
	runFor(2)
	check(#calls == 1, "pas de second appel (fin de Grab, délai)")
	AC.SetCarrying(false)
	check(not playing(w, "CarryIdle"), "fin du portage")
end

---------------------------------------------------------------------------------
section("A3 Grab sans marqueur : la boucle part à la fin de Grab")
do
	local w = setup({ Grab = { id = "rbxassetid://41", length = 0.5, loop = false, markers = {} }, CarryIdle = CARRY_IDLE, CarryRun = CARRY_RUN })
	spawnTracked(w)
	local AC = startAC(w)
	AC.PlayPlayer("Grab")
	runFor(0.05)
	AC.SetCarrying(true)
	runFor(0.35)
	check(not playing(w, "CarryIdle"), "à 0,4 s : Grab joue encore, pas de CarryIdle")
	runFor(0.15)
	check(playing(w, "CarryIdle"), "à la fin de Grab (0,5 s) : CarryIdle")
	AC.SetCarrying(false)
end

---------------------------------------------------------------------------------
section("A4 Grab qui ne finit pas (durée inconnue) : délai de secours GRAB_MAX_WAIT (1,5 s)")
do
	-- Durée 0 et une piste qui ne s'arrête jamais : comme une animation pas encore chargée.
	local w = setup({ Grab = { id = "rbxassetid://42", length = 0, loop = true, markers = {} }, CarryIdle = CARRY_IDLE, CarryRun = CARRY_RUN })
	spawnTracked(w)
	local AC = startAC(w)
	AC.PlayPlayer("Grab")
	runFor(0.05)
	AC.SetCarrying(true)
	runFor(1.35)
	check(not playing(w, "CarryIdle"), "à 1,4 s : toujours en attente")
	runFor(0.15)
	check(playing(w, "CarryIdle") and not playing(w, "Grab"), "à 1,5 s : CarryIdle, Grab arrêtée")
	AC.SetCarrying(false)
end

---------------------------------------------------------------------------------
section("A4b Grab long (2,5 s), marqueur tardif (2 s) : pas devancé par GRAB_MAX_WAIT")
do
	local w = setup({ Grab = { id = "rbxassetid://43", length = 2.5, loop = false, markers = { marker("Grab", 2) } }, CarryIdle = CARRY_IDLE, CarryRun = CARRY_RUN })
	spawnTracked(w)
	local AC = startAC(w)
	AC.PlayPlayer("Grab")
	runFor(0.05)
	AC.SetCarrying(true)
	runFor(1.85)
	check(not playing(w, "CarryIdle"), "à 1,9 s : toujours en attente (le marqueur est à 2 s)")
	runFor(0.15)
	check(playing(w, "CarryIdle"), "au marqueur tardif : CarryIdle")
	AC.SetCarrying(false)
end

---------------------------------------------------------------------------------
section("A5 Portage fini pendant Grab, colis arrivé après Grab, course pendant l'attente")
do
	local w = setup({ Grab = GRAB_MARKED, CarryIdle = CARRY_IDLE, CarryRun = CARRY_RUN })
	local _, humanoid, _, hrp = spawnTracked(w)
	local AC = startAC(w)
	AC.PlayPlayer("Grab")
	runFor(0.05)
	AC.SetCarrying(true)
	runFor(0.05)
	AC.SetCarrying(false) -- rattrapé, colis perdu avant la fin du geste
	runFor(0.4)
	check(not playing(w, "CarryIdle") and not playing(w, "CarryRun"), "portage fini avant le marqueur : rien ne part au marqueur")
	runFor(0.5)
	-- Le colis arrive après Grab (latence) : tout de suite.
	AC.PlayPlayer("Grab")
	runFor(0.7)
	AC.SetCarrying(true)
	check(playing(w, "CarryIdle"), "attribut arrivé après la fin de Grab : CarryIdle tout de suite")
	AC.SetCarrying(false)
	-- Course pendant l'attente : CarryRun au marqueur, pas avant.
	AC.PlayPlayer("Grab")
	runFor(0.05)
	AC.SetCarrying(true)
	rawset(hrp, "AssemblyLinearVelocity", Vector3.new(14, 0, 0))
	humanoid.Running:Fire(14)
	check(not playing(w, "CarryRun") and not playing(w, "CarryIdle"), "il court pendant Grab : rien encore")
	runFor(0.3)
	check(playing(w, "CarryRun") and not playing(w, "CarryIdle"), "au marqueur, en courant : CarryRun")
	rawset(hrp, "AssemblyLinearVelocity", Vector3.new(0, 0, 0))
	humanoid.Running:Fire(0)
	check(playing(w, "CarryIdle") and not playing(w, "CarryRun"), "arrêté : CarryIdle")
	AC.SetCarrying(false)
	-- Deux Grab de suite : le second relance l'attente, le marqueur du second libère.
	AC.PlayPlayer("Grab")
	runFor(0.1)
	AC.PlayPlayer("Grab") -- relancé du début
	runFor(0.05)
	AC.SetCarrying(true)
	runFor(0.2)
	check(not playing(w, "CarryIdle"), "Grab relancé : on attend son marqueur à lui")
	runFor(0.1)
	check(playing(w, "CarryIdle"), "marqueur du Grab relancé : CarryIdle")
	AC.SetCarrying(false)
end

---------------------------------------------------------------------------------
section("A6 BenchLift : pas relancé en pleine répétition ; TreadmillRun suit TrainingMachine")
do
	local w = setup({
		BenchLift = { id = "rbxassetid://31", length = 0.8, loop = false, markers = { marker("Top", 0.4) } },
		BenchIdle = { id = "rbxassetid://35", length = 2, loop = true, markers = {} },
		TreadmillRun = { id = "rbxassetid://30", length = 1, loop = true, markers = {} },
	})
	spawnTracked(w)
	w.player:SetAttribute("BenchReps", 0)
	local AC = startAC(w)
	local tops = 0
	AC.OnMarker("BenchLift", "Top", function()
		tops += 1
	end)
	-- Copie a134 (rééquilibrage v2) : plus de banc. Ni TrainingMachine = "Bench" ni BenchReps ne jouent quoi que
	-- ce soit ; BenchLift et BenchIdle ne sont plus au contrat ni jouées par le contrôleur, même livrées.
	w.player:SetAttribute("TrainingMachine", "Bench")
	check(not playing(w, "BenchIdle"), "a134 : au banc : BenchIdle ne joue plus")
	w.player:SetAttribute("BenchReps", 1)
	runFor(0.9)
	w.player:SetAttribute("BenchReps", 2)
	runFor(1)
	check(tops == 0 and not playing(w, "BenchLift") and not playing(w, "BenchIdle"), `a134 : hausses de BenchReps : rien ne joue, aucun marqueur Top ({tops})`)
	w.player:SetAttribute("TrainingMachine", nil)
	w.player:SetAttribute("TrainingMachine", "Treadmill")
	check(playing(w, "TreadmillRun"), "sur le tapis (attribut posé par TrainingService) : TreadmillRun")
	spawnTracked(w, "Ironix2")
	runFor(0.1)
	check(playing(w, "TreadmillRun"), "nouveau personnage, toujours sur le tapis : TreadmillRun rejouée")
	w.player:SetAttribute("TrainingMachine", nil)
	check(not playing(w, "TreadmillRun"), "descendu du tapis : TreadmillRun arrêtée")
end

---------------------------------------------------------------------------------
section("A7 CarryController : colis du porteur caché jusqu'au marqueur Grab")
local function makeVisual(parent)
	local model = Instance.new("Model")
	model.Name = "CarryVisual"
	local box = Instance.new("Part")
	box.Name = "Box"
	box.Parent = model
	local tint = Instance.new("Part")
	tint.Name = "Tint"
	tint.Parent = model
	local decal = Instance.new("Decal")
	decal.Name = "Tape"
	decal.Parent = box
	local label = Instance.new("Attachment")
	label.Name = "LabelPoint"
	label.Parent = box
	local gui = Instance.new("BillboardGui")
	gui.Name = "BB_Box"
	gui.Parent = label
	local rarity = Instance.new("TextLabel")
	rarity.Name = "Rarity"
	rarity.Parent = gui
	local halo = Instance.new("Attachment")
	halo.Name = "HaloPoint"
	halo.Parent = box
	local light = Instance.new("PointLight")
	light.Parent = halo
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Parent = halo
	local ray = Instance.new("Beam")
	ray.Parent = halo
	local outline = Instance.new("Highlight")
	outline.Name = "OutlineHighlight"
	outline.Parent = model
	local edges = Instance.new("SelectionBox")
	edges.Name = "Edges"
	edges.Parent = model
	local off = Instance.new("Beam") -- éteint par Clément : doit le rester
	off.Name = "OffBeam"
	off.Enabled = false
	off.Parent = halo
	model.Parent = parent
	return { model = model, parts = { box, tint }, decal = decal, gui = gui, light = light, sparkles = sparkles, ray = ray, outline = outline, edges = edges, off = off }
end
local function isHidden(v)
	return v.parts[1].LocalTransparencyModifier == 1
		and v.parts[2].LocalTransparencyModifier == 1
		and v.decal.LocalTransparencyModifier == 1
		and v.gui.Enabled == false
		and v.light.Enabled == false
		and v.sparkles.Enabled == false
		and v.ray.Enabled == false
		and v.outline.Enabled == false
		and v.edges.Visible == false
end
local function isShown(v)
	return v.parts[1].LocalTransparencyModifier == 0
		and v.parts[2].LocalTransparencyModifier == 0
		and v.decal.LocalTransparencyModifier == 0
		and v.gui.Enabled
		and v.light.Enabled
		and v.sparkles.Enabled
		and v.ray.Enabled
		and v.outline.Enabled
		and v.edges.Visible
		and v.off.Enabled == false
end
do
	local w = setup({ Grab = GRAB_MARKED, CarryIdle = CARRY_IDLE, CarryRun = CARRY_RUN })
	local character = spawnTracked(w)
	local AC = startAC(w)
	local CC = require(w.carryModule)
	check(runTask(function()
		CC.Start()
	end, 5), "CarryController.Start se termine")

	-- 1. Le colis arrive dans le personnage, puis l'attribut Carrying (ordre du serveur).
	AC.PlayPlayer("Grab")
	runFor(0.05)
	local v = makeVisual(character)
	w.player:SetAttribute("Carrying", "Rare")
	check(CC.IsCarrying(), "CarryController : porte")
	check(isHidden(v), "pendant Grab : colis, étiquette, halo et contours cachés en local")
	check(v.off.Enabled == false, "un Beam déjà éteint reste éteint")
	-- Une pièce ajoutée au colis pendant l'attente est cachée aussi.
	local late = Instance.new("Part")
	late.Name = "Late"
	late.Parent = v.model
	check(late.LocalTransparencyModifier == 1, "pièce arrivée après coup : cachée aussi")
	runFor(0.3)
	check(isShown(v) and late.LocalTransparencyModifier == 0, "au marqueur Grab : tout réapparaît (et ce qui était éteint le reste)")
	check(playing(w, "CarryIdle"), "et CarryIdle tient le colis")
	w.player:SetAttribute("Carrying", nil)
	v.model:Destroy()
	runFor(0.2)

	-- 2. L'attribut d'abord, le colis ensuite (réplication dans l'autre ordre).
	AC.PlayPlayer("Grab")
	runFor(0.05)
	w.player:SetAttribute("Carrying", "Common")
	runFor(0.05)
	local v2 = makeVisual(character)
	check(isHidden(v2), "colis arrivé après l'attribut : caché à son arrivée")
	runFor(0.25)
	check(isShown(v2), "au marqueur : visible")
	w.player:SetAttribute("Carrying", nil)
	v2.model:Destroy()
	runFor(0.2)

	-- 3. Sans Grab en cours (colis du camion ramassé sans animation, Grab pas livrée…) : jamais caché.
	local v3 = makeVisual(character)
	w.player:SetAttribute("Carrying", "Epic")
	check(isShown(v3), "sans Grab en cours : le colis se voit tout de suite")
	w.player:SetAttribute("Carrying", nil)
	v3.model:Destroy()
	runFor(0.2)

	-- 4. Portage fini pendant l'attente (rattrapé) : rien ne reste caché, le suivant repart propre.
	clearLog()
	AC.PlayPlayer("Grab")
	runFor(0.05)
	local v4 = makeVisual(character)
	w.player:SetAttribute("Carrying", "Rare")
	check(isHidden(v4), "caché pendant Grab")
	runFor(0.05)
	w.player:SetAttribute("Carrying", nil)
	check(isShown(v4), "fin du portage pendant l'attente : tout est remis")
	v4.model:Destroy()
	runFor(0.5)
	check(countLog("ERREUR", nil) == 0, "aucune erreur (colis retiré)")
	local v5 = makeVisual(character)
	w.player:SetAttribute("Carrying", "Rare")
	check(isShown(v5), "portage suivant, sans Grab : visible")
	w.player:SetAttribute("Carrying", nil)
	v5.model:Destroy()
end

report()
