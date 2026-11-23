--!strict
-- PlayerCollisionService (vague GC3, a400 ; audit sécurité a272, faille M1, option (a), décision de Cantin du 23/11) :
-- les joueurs se traversent, pour qu'un tricheur qui se fait tourner très vite (« fling ») ne puisse plus projeter un
-- autre joueur (l'anti-triche punissait la victime et lui reprenait ce qu'elle portait).
--
-- Interrupteur : Config/Features.PlayerCollision. false (défaut) = ce service agit ; true = rien n'est posé, le contact
-- entre joueurs d'avant.
--
-- Groupe de collision PLAYERS_GROUP (« Players »), qui ne se touche pas lui-même. Il est posé sur chaque BasePart de
-- chaque personnage à son apparition, puis sur chaque pièce ajoutée ensuite (outil équipé, objet porté de
-- CarryService, accessoires chargés après coup, auras soudées) ; une pièce qui quitte le personnage (outil rangé dans
-- le sac, objet retiré) revient à « Default ». Seules les pièces en « Default » sont prises : un groupe posé par un
-- autre service n'est jamais écrasé.
-- « Players » touche tous les autres groupes (règle par défaut de Roblox) : décor, vigiles (GuardService), bot
-- (BotService), témoins et PNJ (NpcAvoid), mur de nuit (NightCycleService), vitrines et portes. Les règles de ces
-- services ne changent pas, sauf une : le passage du mur de nuit (NIGHT_PASS_GROUP, même nom que PASS_GROUP de
-- NightCycleService, posé seulement sur des personnages de joueurs) ne touche ni « Players » ni lui-même ; sans cela,
-- à la tombée de la nuit, tous les joueurs du couloir (porteurs compris) se toucheraient de nouveau.

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Features = require(ReplicatedStorage.Shared.Config.Features)

local PLAYERS_GROUP = "Players"
local DEFAULT_GROUP = "Default"
local NIGHT_PASS_GROUP = "NightPass" -- PASS_GROUP de NightCycleService (même nom)

local PlayerCollisionService = {}

local watched: { [Player]: { RBXScriptConnection } } = {} -- connexions du personnage en cours

local function setupGroups(): boolean
	local ok, err = pcall(function()
		for _, name in { PLAYERS_GROUP, NIGHT_PASS_GROUP } do
			if not PhysicsService:IsCollisionGroupRegistered(name) then
				PhysicsService:RegisterCollisionGroup(name)
			end
		end
		PhysicsService:CollisionGroupSetCollidable(PLAYERS_GROUP, PLAYERS_GROUP, false)
		PhysicsService:CollisionGroupSetCollidable(PLAYERS_GROUP, NIGHT_PASS_GROUP, false)
		PhysicsService:CollisionGroupSetCollidable(NIGHT_PASS_GROUP, NIGHT_PASS_GROUP, false)
	end)
	if not ok then
		warn(`[PlayerCollisionService] groupe de collision {PLAYERS_GROUP} indisponible ({err}) : les joueurs se touchent encore`)
	end
	return ok
end

local function take(instance: Instance)
	if instance:IsA("BasePart") and instance.CollisionGroup == DEFAULT_GROUP then
		instance.CollisionGroup = PLAYERS_GROUP
	end
end

local function release(instance: Instance)
	if instance:IsA("BasePart") and instance.CollisionGroup == PLAYERS_GROUP then
		instance.CollisionGroup = DEFAULT_GROUP
	end
end

local function unwatch(player: Player)
	local list = watched[player]
	if list then
		for _, connection in list do
			connection:Disconnect()
		end
		watched[player] = nil
	end
end

local function onCharacter(player: Player, character: Model)
	unwatch(player)
	watched[player] = {
		character.DescendantAdded:Connect(take),
		character.DescendantRemoving:Connect(release),
	}
	for _, descendant in character:GetDescendants() do
		take(descendant)
	end
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(function(character: Model)
		onCharacter(player, character)
	end)
	local character = player.Character
	if character then
		onCharacter(player, character)
	end
end

function PlayerCollisionService.Start()
	if Features.PlayerCollision ~= false then
		return
	end
	if not setupGroups() then
		return
	end
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(unwatch)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return PlayerCollisionService
