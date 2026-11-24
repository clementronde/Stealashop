--!nocheck
-- F. Sons de pas de Roblox retirés (FootstepController, L-056) : le Running de tous les personnages,
-- le sien et ceux des autres, à l'arrivée et à la réapparition ; saut, chute et le reste gardés.

local KEPT = { "Climbing", "Died", "FreeFalling", "GettingUp", "Jumping", "Landing", "Splash", "Swimming" }

local function inGame(instance)
	local current = instance
	while current do
		if current == DataModel then
			return true
		end
		current = current.Parent
	end
	return false
end

-- Running retiré du personnage, les autres sons là, intacts.
local function checkCharacter(character, sounds, label)
	local root = character:FindFirstChild("HumanoidRootPart")
	check(root:FindFirstChild("Running") == nil, `{label} : plus de Running dans le HumanoidRootPart`)
	check(sounds.Running.Parent == nil and isDestroyed(sounds.Running), `{label} : le Running de Roblox est détruit`)
	local keptOk = true
	for _, name in KEPT do
		local sound = sounds[name]
		if sound.Parent ~= root or isDestroyed(sound) or sound.Volume ~= 0.65 then
			keptOk = false
		end
	end
	check(keptOk, `{label} : les 8 autres sons de Roblox restent (saut, chute…), volume 0,65`)
end

section("F. Joueurs et personnages déjà là au démarrage")
local alice = newPlayer("Alice")
local bob = newPlayer("Bob")
local aliceCharacter, aliceSounds = spawnCharacter(alice, Vector3.new(-113, 3, 0))
local bobCharacter, bobSounds = spawnCharacter(bob, Vector3.new(-100, 3, 10))
check(aliceCharacter.HumanoidRootPart:FindFirstChild("Running") ~= nil, "F0 avant le démarrage, le Running de Roblox est là")
startClient(alice)
local Footsteps = clientModule("FootstepController")
checkCharacter(aliceCharacter, aliceSounds, "F1 son personnage")
checkCharacter(bobCharacter, bobSounds, "F2 un autre joueur déjà là")
check(Footsteps.GetRemovedCount() == 2, `F3 deux sons de pas retirés ({Footsteps.GetRemovedCount()})`)

section("F'. Le script de Roblox continue de régler ses sons")
local ok, err = pcall(function()
	-- Ce que fait RbxCharacterSounds quand le personnage court, puis saute.
	aliceSounds.Running.Playing = true
	aliceSounds.Running.Playing = false
	aliceSounds.Jumping.TimePosition = 0
	aliceSounds.Jumping.Playing = true
end)
check(ok, `F4 régler Playing sur le Running détruit ne lève pas d'erreur ({err})`)
check(not inGame(aliceSounds.Running), "F5 … et ce son reste hors du jeu : silence")
check(aliceSounds.Jumping.Playing == true and aliceSounds.Jumping.Parent == aliceCharacter.HumanoidRootPart, "F6 le saut joue toujours")
advance(1)
check(aliceCharacter.HumanoidRootPart:FindFirstChild("Running") == nil, "F7 une seconde plus tard, rien n'est revenu")

section("F''. Réapparition et joueur qui arrive")
local respawned, respawnSounds = spawnCharacter(alice, Vector3.new(-120, 3, 0))
flush()
checkCharacter(respawned, respawnSounds, "F8 réapparition (sons créés après CharacterAdded)")
local carol = newPlayer("Carol")
flush()
local carolCharacter, carolSounds = spawnCharacter(carol, Vector3.new(-90, 3, -10))
flush()
checkCharacter(carolCharacter, carolSounds, "F9 un joueur qui arrive après le démarrage")
local bobAgain, bobAgainSounds = spawnCharacter(bob, Vector3.new(-80, 3, 0))
flush()
checkCharacter(bobAgain, bobAgainSounds, "F10 réapparition d'un autre joueur")
check(Footsteps.GetRemovedCount() == 5, `F11 cinq sons de pas retirés en tout ({Footsteps.GetRemovedCount()})`)

section("F'''. HumanoidRootPart qui arrive après le personnage (streaming)")
local dave = newPlayer("Dave")
local daveCharacter = make("Model", { Name = "Dave" })
make("Humanoid", { Name = "Humanoid" }, daveCharacter)
daveCharacter.Parent = Workspace
dave.Character = daveCharacter
dave.CharacterAdded:Fire(daveCharacter)
flush()
-- Le HumanoidRootPart arrive déjà garni de ses sons (pièce reçue d'un bloc).
local lateRoot = newInstance("Part")
lateRoot.Name = "HumanoidRootPart"
local lateRunning = newInstance("Sound")
lateRunning.Name = "Running"
lateRunning.Parent = lateRoot
local lateJump = newInstance("Sound")
lateJump.Name = "Jumping"
lateJump.Parent = lateRoot
lateRoot.Parent = daveCharacter
flush()
check(lateRoot:FindFirstChild("Running") == nil and isDestroyed(lateRunning), "F12 Running arrivé avec sa pièce : retiré")
check(lateJump.Parent == lateRoot, "F13 Jumping arrivé avec elle : gardé")

section("F''''. Ce qui n'est pas un son de pas de Roblox")
local decor = make("Sound", { Name = "Running" }, MAP) -- un décor nommé Running
local toolSound = make("Sound", { Name = "Running" }, respawned:FindFirstChild("Head")) -- ailleurs que dans le HumanoidRootPart
local notSound = make("Folder", { Name = "Running" }, respawned:FindFirstChild("HumanoidRootPart"))
flush()
check(decor.Parent == MAP, "F14 un Sound Running du décor : gardé")
check(toolSound.Parent ~= nil and not isDestroyed(toolSound), "F15 un Sound Running hors du HumanoidRootPart : gardé")
check(notSound.Parent ~= nil, "F16 un objet Running qui n'est pas un Sound : gardé")
local npc = make("Model", { Name = "Guard" }, Workspace)
local npcRoot = make("Part", { Name = "HumanoidRootPart" }, npc)
local npcRunning = make("Sound", { Name = "Running" }, npcRoot)
flush()
check(npcRunning.Parent == npcRoot, "F17 un PNJ (pas un personnage de joueur) n'est pas touché")

section("F'''''. Joueur qui part")
local ok2, err2 = pcall(function()
	removePlayer(carol)
	flush()
end)
check(ok2, `F18 départ d'un joueur sans erreur ({err2})`)
local count = Footsteps.GetRemovedCount()
-- Un personnage de Carol qui réapparaîtrait après son départ n'est plus suivi (connexions coupées).
local ghost = make("Model", { Name = "CarolGhost" })
make("Part", { Name = "HumanoidRootPart" }, ghost)
ghost.Parent = Workspace
carol.CharacterAdded:Fire(ghost)
flush()
robloxSounds(ghost)
flush()
check(Footsteps.GetRemovedCount() == count, "F19 plus rien n'est suivi pour un joueur parti")
check(not logHas("FootstepController", "WARN", "client"), "F20 aucun avertissement du contrôleur")

summary("scénario pas")
