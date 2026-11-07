--!strict
-- FootstepController (DEV-051, client) : retire les sons de pas de Roblox (liaison L-056, demande
-- de Clément du 2026-11-07 ; choix d'Ironix : saut et chute gardés).
--
-- Le script de sons par défaut de Roblox (RbxCharacterSounds, dans les PlayerScripts) crée chez
-- chaque client, pour le personnage de chaque joueur, des Sound locaux dans son HumanoidRootPart :
-- Running (les pas, en boucle quand le personnage marche), Jumping, FreeFalling, Landing, Climbing,
-- Swimming, Splash, GettingUp, Died. Ce contrôleur détruit le seul Running, dès qu'il apparaît :
-- pour tous les personnages, le sien comme ceux des autres joueurs, pour un joueur déjà là comme
-- pour un joueur qui arrive, et à chaque réapparition (le script de Roblox recrée ses sons sur
-- chaque nouveau personnage). Les autres sons restent ceux de Roblox. Le script de Roblox continue
-- de régler le Playing de son Running détruit, hors du jeu : sans bruit et sans erreur.
--
-- Suivi : chaque joueur (Players, PlayerAdded), chacun de ses personnages (Character,
-- CharacterAdded) et tout ce qui arrive dans le personnage (DescendantAdded) : un Sound nommé
-- Running, enfant d'une pièce HumanoidRootPart. Le script de Roblox ne fait des sons que pour ces
-- personnages-là ; un Running ailleurs (décor, outil, PNJ) n'est pas touché.
--
-- Pas de LocalScript RbxCharacterSounds de remplacement dans StarterPlayerScripts : il couperait
-- aussi le saut et la chute, et il serait hors des dossiers synchronisés (liaison 3.1). Rien n'est
-- envoyé au serveur.
--
-- API (client) :
--   FootstepController.GetRemovedCount() -> number
--       Nombre de sons de pas retirés depuis le démarrage, pour un test dans Studio (barre de
--       commande côté client).

local Players = game:GetService("Players")

-- Noms posés par le script de sons de Roblox (RbxCharacterSounds).
local STEP_SOUND = "Running"
local ROOT_PART = "HumanoidRootPart"
-- Climbing joue le même bruit de pas (sur une échelle ou un treillis) : à ajouter ici s'il faut le
-- couper aussi. La carte n'a rien à escalader (relevé Studio du 2026-11-08).

local FootstepController = {}

local removed = 0
local watched: { [Instance]: RBXScriptConnection } = setmetatable({}, { __mode = "k" }) :: any
local playerConnections: { [Player]: { RBXScriptConnection } } = {}

local function isStepSound(instance: Instance): boolean
	local parent = instance.Parent
	return instance.Name == STEP_SOUND and instance:IsA("Sound") and parent ~= nil and parent.Name == ROOT_PART and parent:IsA("BasePart")
end

local function mute(instance: Instance)
	if isStepSound(instance) then
		removed += 1
		instance:Destroy()
	end
end

local function watchCharacter(character: Model?)
	if character == nil or watched[character] then
		return
	end
	-- Les sons sont créés par le script de Roblox quand Humanoid et HumanoidRootPart sont là : avant
	-- ou après ce contrôleur.
	watched[character] = character.DescendantAdded:Connect(mute)
	for _, descendant in character:GetDescendants() do
		mute(descendant)
	end
end

local function watchPlayer(player: Player)
	if playerConnections[player] then
		return
	end
	playerConnections[player] = {
		player.CharacterAdded:Connect(watchCharacter),
	}
	watchCharacter(player.Character)
end

local function forgetPlayer(player: Player)
	local connections = playerConnections[player]
	playerConnections[player] = nil
	if connections then
		for _, connection in connections do
			connection:Disconnect()
		end
	end
	local character = player.Character
	local connection = if character then watched[character] else nil
	if character and connection then
		watched[character] = nil
		connection:Disconnect()
	end
end

function FootstepController.GetRemovedCount(): number
	return removed
end

function FootstepController.Start()
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(forgetPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
end

return FootstepController
