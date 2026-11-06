--!strict
-- Mode test Studio de DEV-006. Fini quand (doc, 2.4) : « l'animation test se lance et son
-- marqueur déclenche un son ». Démarré par AnimationController ; ne fait rien hors de Studio.
--
-- Lancer, dans la barre de commande de Studio (en Edit avant Play, ou pendant le test côté
-- serveur) :
--   workspace:SetAttribute("AnimTest", true)         -- animation « Test », marqueur « Test »
--   workspace:SetAttribute("AnimTest", "BenchLift")  -- ou une animation livrée du joueur, avec
--                                                    -- le marqueur du contrat 2.4
-- Arrêter et nettoyer (en Edit, après le test) : workspace:SetAttribute("AnimTest", nil)
--
-- Déroulé : 3 lectures sur le personnage local ; à chaque passage du marqueur, un son de test est
-- joué sur le personnage. Tout s'écrit dans la sortie (filtre « [Anim test] ») et finit par une
-- ligne « OK » ou « ÉCHEC ». Relancer : changer l'attribut, ou réapparaître.
--
-- Animation : l'objet de ce nom dans ReplicatedStorage/Assets/Animations/Player. Pour « Test »,
-- c'est l'animation test de Clément (ANI-001 ; étape A1 de son parcours : publiée au nom du
-- groupe, avec un marqueur « Test »). Tant qu'elle n'est pas livrée, une animation de
-- remplacement est fabriquée en code : le bras droit se lève puis redescend en 0,8 s, marqueur
-- « Test » au sommet (KeyframeSequenceProvider:RegisterKeyframeSequence, Studio seulement).
-- Son : l'objet Sound « Test » du dossier des sons (Shared/Anim/MarkerSounds) s'il existe, sinon
-- un son livré avec Roblox (fichier local du client, aucun asset publié).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AnimPlayer = require(script.Parent:WaitForChild("AnimPlayer"))
local MarkerSounds = require(script.Parent:WaitForChild("MarkerSounds"))
local Animations = require(script.Parent.Parent:WaitForChild("Contract"):WaitForChild("Animations"))

local AnimTest = {}

local ATTRIBUTE = "AnimTest" -- attribut du Workspace qui lance le test
local TEST_NAME = "Test" -- animation test de Clément (ANI-001)
local TEST_MARKER = "Test" -- marqueur posé dans l'animation test
local PLAYS = 3 -- lectures par test
local PAUSE = 1 -- secondes entre deux lectures
local PLAY_TIMEOUT = 6 -- secondes d'attente au plus d'une lecture (une boucle ne finit jamais)
local SOUND_TIMEOUT = 3 -- secondes d'attente au plus du chargement d'un son
local FALLBACK_SOUND = "rbxasset://sounds/volume_slider.ogg" -- livré avec Roblox (content/sounds)

local generation = 0 -- change à chaque relance : le test en cours s'arrête

local function say(message: string)
	print(`[Anim test] {message}`)
end

-- Un échec s'écrit en orange, pour se voir dans la sortie.
local function fail(message: string)
	warn(`[Anim test] ÉCHEC : {message}`)
end

-- Une image clé de l'animation de remplacement : la chaîne de poses R15 jusqu'à l'épaule droite.
local function addKeyframe(sequence: KeyframeSequence, time: number, armDegrees: number): Keyframe
	local frame = Instance.new("Keyframe")
	frame.Time = time
	local root = Instance.new("Pose")
	root.Name = "HumanoidRootPart"
	local lower = Instance.new("Pose")
	lower.Name = "LowerTorso"
	lower.Parent = root
	local upper = Instance.new("Pose")
	upper.Name = "UpperTorso"
	upper.Parent = lower
	local arm = Instance.new("Pose")
	arm.Name = "RightUpperArm"
	arm.CFrame = CFrame.Angles(0, 0, math.rad(armDegrees))
	arm.Parent = upper
	root.Parent = frame
	frame.Parent = sequence
	return frame
end

-- Fabrique l'animation de remplacement « Test ». Renvoie un dossier hors de la place qui la
-- contient, ou nil et la raison.
local function buildStandIn(): (Instance?, string?)
	local ok, result = pcall(function(): Instance
		local sequence = Instance.new("KeyframeSequence")
		sequence.Name = TEST_NAME
		sequence.Loop = false
		sequence.Priority = Enum.AnimationPriority.Action
		addKeyframe(sequence, 0, 0)
		local top = addKeyframe(sequence, 0.4, 150)
		addKeyframe(sequence, 0.8, 0)
		local marker = Instance.new("KeyframeMarker")
		marker.Name = TEST_MARKER
		marker.Value = "remplacement"
		top:AddMarker(marker)

		local folder = Instance.new("Folder")
		folder.Name = Animations.FolderName
		local animation = Instance.new("Animation")
		animation.Name = TEST_NAME
		local provider = game:GetService("KeyframeSequenceProvider")
		animation.AnimationId = provider:RegisterKeyframeSequence(sequence)
		animation.Parent = folder
		return folder
	end)
	if not ok then
		return nil, tostring(result)
	end
	return result, nil
end

-- Le son de test : l'objet Sound « Test » du dossier des sons, sinon un son livré avec Roblox.
local function testSound(): (Sound, string)
	local found = MarkerSounds.find(TEST_NAME)
	if found then
		return found, found:GetFullName()
	end
	local sound = Instance.new("Sound")
	sound.Name = "AnimTestSound"
	sound.SoundId = FALLBACK_SOUND
	return sound, `son livré avec Roblox ({FALLBACK_SOUND})`
end

-- Vrai si le son se charge (durée connue) en SOUND_TIMEOUT secondes au plus.
local function waitLoaded(sound: Sound): boolean
	local deadline = os.clock() + SOUND_TIMEOUT
	while not sound.IsLoaded and os.clock() < deadline do
		task.wait(0.05)
	end
	return sound.IsLoaded and sound.TimeLength > 0
end

-- Le marqueur attendu : « Test » pour l'animation test, sinon celui du contrat 2.4 (ou aucun).
local function markerOf(animName: string): string?
	if animName == TEST_NAME then
		return TEST_MARKER
	end
	for _, spec in Animations.Player do
		if spec.Name == animName then
			return spec.Marker
		end
	end
	return nil
end

local function run(token: number, character: Model, animName: string)
	local animator = AnimPlayer.waitForAnimator(character)
	if token ~= generation then
		return
	end
	if animator == nil then
		fail("pas d'Animator dans le Humanoid du personnage")
		return
	end

	local folder = AnimPlayer.playerFolder()
	local animation, why = AnimPlayer.findAnimation(folder, animName)
	local source = ""
	if animation then
		source = `livrée, {animation:GetFullName()}`
		AnimPlayer.preload(folder, { animName })
	elseif animName == TEST_NAME then
		local standIn, err = buildStandIn()
		if standIn == nil then
			fail(
				`l'animation test n'est pas livrée ({why}) et Studio refuse l'animation de remplacement ({err}). Il faut l'animation « Test » de Clément (ANI-001), avec un marqueur « Test »`
			)
			return
		end
		folder = standIn
		source = "de remplacement, fabriquée en code (l'animation « Test » de Clément, ANI-001, n'est pas encore livrée)"
	else
		fail(`« {animName} » introuvable : {why}`)
		return
	end
	if token ~= generation then
		return
	end

	local marker = markerOf(animName)
	local template, soundSource = testSound()
	local anims = AnimPlayer.new(animator, folder, Animations.Player, "Test")
	local hits, loaded, pending = 0, 0, 0
	local soundLength = 0
	local off: (() -> ())? = nil
	if marker then
		local markerName: string = marker
		off = anims:OnMarker(animName, markerName, function(param: string)
			hits += 1
			local sound = MarkerSounds.playSound(template, character:FindFirstChild("HumanoidRootPart"))
			say(`marqueur « {markerName} » atteint (valeur « {param} ») : son de test lancé`)
			pending += 1
			task.spawn(function()
				if waitLoaded(sound) then
					loaded += 1
					soundLength = sound.TimeLength
				end
				pending -= 1
			end)
		end)
	end

	say(`animation « {animName} » : {source}`)
	say(`son : {soundSource}`)
	local played = 0
	local trackLength = 0
	for i = 1, PLAYS do
		if token ~= generation or not character:IsDescendantOf(Workspace) then
			break
		end
		local track = anims:Play(animName)
		if track == nil then
			break
		end
		played += 1
		local stopped = false
		local connection = track.Stopped:Once(function()
			stopped = true
		end)
		local deadline = os.clock() + PLAY_TIMEOUT
		while not stopped and os.clock() < deadline and token == generation do
			task.wait(0.1)
		end
		connection:Disconnect()
		trackLength = math.max(trackLength, track.Length)
		say(`lecture {i}/{PLAYS} finie (durée de la piste {string.format("%.2f", track.Length)} s)`)
		task.wait(PAUSE)
	end
	local deadline = os.clock() + SOUND_TIMEOUT
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
	if off then
		off()
	end
	anims:Destroy()

	if token ~= generation then
		say("interrompu (attribut changé ou personnage réapparu)")
	elseif played == 0 then
		fail(`« {animName} » ne se lance pas (voir la ligne [Anim] plus haut)`)
	elseif trackLength == 0 and hits == 0 then
		fail(
			`« {animName} » lancée mais jamais chargée (durée 0 s) : ID illisible ou animation publiée hors du groupe ; si c'est l'animation de remplacement, Studio ne la joue pas et il faut l'animation « Test » de Clément (ANI-001)`
		)
	elseif marker == nil then
		say(`fini : « {animName} » lancée {played} fois ; pas de marqueur au contrat 2.4, aucun son attendu`)
	elseif hits == 0 then
		fail(
			`« {animName} » lancée {played} fois, mais le marqueur « {marker} » n'a jamais été atteint (absent de l'animation, mal nommé, ou nom d'image clé au lieu d'un marqueur ?)`
		)
	elseif loaded == 0 then
		fail(`marqueur « {marker} » atteint {hits} fois, mais le son de test ne s'est pas chargé ({soundSource})`)
	else
		say(
			`OK : « {animName} » lancée {played} fois, marqueur « {marker} » atteint {hits} fois, son joué {loaded} fois (durée {string.format("%.2f", soundLength)} s)`
		)
	end
end

-- Écoute l'attribut AnimTest du Workspace et relance le test à chaque changement et à chaque
-- apparition du personnage. Client, Studio seulement.
function AnimTest.start()
	if not RunService:IsStudio() or not RunService:IsClient() then
		return
	end
	local player = Players.LocalPlayer
	local function relaunch()
		generation += 1
		local token = generation
		local value = Workspace:GetAttribute(ATTRIBUTE)
		local name: string? = nil
		if value == true then
			name = TEST_NAME
		elseif type(value) == "string" and value ~= "" then
			name = value
		end
		if name == nil then
			return
		end
		local character = player.Character
		if character == nil then
			say(`« {name} » : en attente du personnage`)
			return
		end
		say(`lancé pour « {name} » (attribut {ATTRIBUTE} du Workspace)`)
		task.spawn(run, token, character, name)
	end
	Workspace:GetAttributeChangedSignal(ATTRIBUTE):Connect(relaunch)
	player.CharacterAdded:Connect(relaunch)
	relaunch()
end

return AnimTest
