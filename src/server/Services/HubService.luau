--!strict
-- HubService (L-165 point 2, vague 50, a160) : bonus d'amis et noob « invite un ami » du hub. Valeurs :
-- Config/Hub (V0, noms de Clément proposés en L-165) ; calculs : Shared/HubZone.
--
-- Bonus d'amis (décision de Clément : +15 % d'argent par ami) : par ami Roblox du joueur présent dans le serveur,
-- au plus Hub.FriendBonus.MaxFriends amis (V0 : 4, +60 %). Ajouté à DisplayService.GetIncomeBonus (les bonus en
-- pour cent s'additionnent : Premium, index…), donc au revenu des objets exposés, relu chaque seconde. Amitié
-- lue une fois par paire de joueurs à l'arrivée (Player:IsFriendsWith, dans un pcall, tâche à part ; une erreur
-- = pas amis) ; un départ retire la paire. Attributs du Player pour le HUD : FriendsInServer (amis présents) et
-- FriendBonus (fraction, plafond compris). Il n'existait pas encore de bonus d'amis ni de bonus de groupe.
--
-- Noob : le Model Noob (Humanoid, Animator, dossier Animations avec Idle et Wave, livrés par Clément) du modèle
-- qui porte la pièce taggée InviteZone. Idle en boucle dès que le dossier et l'Animator sont là ; Wave quand un
-- joueur vivant entre dans la zone (HubZone.step), au plus une fois toutes les Hub.Noob.WaveCooldown s. Joué
-- côté serveur, comme les vendeurs (VendorService) : tout le monde voit le même salut. L'invitation elle-même
-- s'ouvre côté client (HubController). Sans noob ou sans animations : rien, aucune erreur. Hors des dossiers de
-- travail du Workspace (nom commençant par « _ »). Aucun remote.
--
-- API (serveur) :
--   HubService.GetFriendCount(player) -> number   amis présents (sans plafond)
--   HubService.GetFriendBonus(player) -> number   fraction du bonus (plafond compris)
--   HubService.AreFriends(a, b) -> boolean         a286 : amis Roblox, pour la prime au complice (StoreHeistService)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Hub = require(Shared.Config.Hub)
local HubZone = require(Shared.HubZone)
local Animations = require(Shared.Contract.Animations)
local AnimPlayer = require(Shared.Anim.AnimPlayer)

local DisplayService = require(script.Parent.DisplayService)

local IDLE = "Idle"
local WAVE = "Wave"

type Noob = {
	model: Model,
	anims: AnimPlayer.AnimPlayer?,
	lastWave: number, -- os.clock()
}

local HubService = {}
HubService.Priority = 235 -- V0 : après DisplayService et les autres accroches de revenus

-- Amitiés connues entre joueurs présents : friends[a][b] = true (symétrique).
local friends: { [Player]: { [Player]: boolean } } = {}
local counts: { [Player]: number } = {}
-- Zones InviteZone : joueurs dedans, par zone.
local inside: { [BasePart]: { [Player]: boolean } } = {}
local noobs: { [Model]: Noob } = {}

------------------------------------------------------------------------------
-- Bonus d'amis
------------------------------------------------------------------------------

local function refresh(player: Player)
	if player.Parent ~= Players then
		return
	end
	local count = 0
	local mine: { [Player]: boolean } = friends[player] or {}
	for other in mine do
		if other.Parent == Players then
			count += 1
		end
	end
	counts[player] = count
	player:SetAttribute(Hub.FriendBonus.CountAttribute, count)
	player:SetAttribute(Hub.FriendBonus.BonusAttribute, HubZone.friendBonus(count))
end

local function link(a: Player, b: Player)
	friends[a] = friends[a] or {}
	friends[b] = friends[b] or {}
	friends[a][b] = true
	friends[b][a] = true
end

local function isFriends(a: Player, b: Player): boolean
	return a:IsFriendsWith(b.UserId)
end

local function onPlayerAdded(player: Player)
	friends[player] = friends[player] or {}
	refresh(player)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			task.spawn(function()
				local ok, result = pcall(isFriends, player, other)
				if ok and result == true and player.Parent == Players and other.Parent == Players then
					link(player, other)
					refresh(player)
					refresh(other)
				end
			end)
		end
	end
end

local function onPlayerRemoving(player: Player)
	local mine = friends[player]
	friends[player] = nil
	counts[player] = nil
	for _, zone in inside do
		zone[player] = nil
	end
	if mine then
		for other in mine do
			local theirs = friends[other]
			if theirs then
				theirs[player] = nil
			end
			refresh(other)
		end
	end
end

function HubService.GetFriendCount(player: Player): number
	return counts[player] or 0
end

-- a286 (prime au complice, StoreHeistService) : `a` et `b` sont-ils amis Roblox (paires lues à l'arrivée) ?
function HubService.AreFriends(a: Player, b: Player): boolean
	local mine = friends[a]
	return mine ~= nil and mine[b] == true
end

function HubService.GetFriendBonus(player: Player): number
	return HubZone.friendBonus(counts[player] or 0)
end

------------------------------------------------------------------------------
-- Noob
------------------------------------------------------------------------------

-- Dans la map jouée : dans le Workspace, hors des dossiers de travail (nom commençant par « _ »).
local function inMap(instance: Instance): boolean
	if not instance:IsDescendantOf(Workspace) then
		return false
	end
	local node: Instance? = instance
	while node ~= nil and node.Parent ~= Workspace do
		node = node.Parent
	end
	return node ~= nil and string.sub(node.Name, 1, 1) ~= "_"
end

local function noobOf(zone: BasePart): Noob?
	local holder = zone:FindFirstAncestorOfClass("Model")
	local found = if holder then holder:FindFirstChild(Hub.NoobName, true) else nil
	if found == nil or not found:IsA("Model") then
		return nil
	end
	local model = found :: Model
	local noob = noobs[model]
	if noob == nil then
		local created: Noob = { model = model, anims = nil, lastWave = -math.huge }
		noobs[model] = created
		return created
	end
	return noob
end

-- Idle lancée dès que le dossier Animations et l'Animator sont là ; nil tant qu'il manque quelque chose.
local function animsOf(noob: Noob): AnimPlayer.AnimPlayer?
	local anims = noob.anims
	if anims then
		return anims
	end
	local folder = AnimPlayer.modelFolder(noob.model)
	local humanoid = noob.model:FindFirstChildOfClass("Humanoid")
	local animator = if humanoid then humanoid:FindFirstChildOfClass("Animator") else nil
	if folder == nil or animator == nil then
		return nil
	end
	local created = AnimPlayer.new(animator, folder, Animations.Vendor, `Noob {noob.model:GetFullName()}`)
	noob.anims = created
	created:Play(IDLE)
	return created
end

-- Position du HumanoidRootPart d'un joueur vivant, sinon nil.
local function playerPosition(player: Player): Vector3?
	local character = player.Character
	if character == nil then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil
	end
	return (root :: BasePart).Position
end

local function stepZone(zone: BasePart, now: number)
	local state = inside[zone]
	if state == nil then
		state = {}
		inside[zone] = state
	end
	local entered = false
	for _, player in Players:GetPlayers() do
		local isIn, came = HubZone.step(state[player] == true, zone.CFrame, zone.Size, playerPosition(player))
		if isIn then
			state[player] = true
		else
			state[player] = nil
		end
		entered = entered or came
	end
	local noob = noobOf(zone)
	local anims = if noob then animsOf(noob) else nil
	if noob and anims and entered and now - noob.lastWave >= Hub.Noob.WaveCooldown and not anims:IsPlaying(WAVE) then
		noob.lastWave = now
		anims:Play(WAVE)
	end
end

local function step()
	local now = os.clock()
	local seen: { [BasePart]: boolean } = {}
	for _, tagged in CollectionService:GetTagged(Hub.InviteZoneTag) do
		if tagged:IsA("BasePart") and inMap(tagged) then
			seen[tagged :: BasePart] = true
			stepZone(tagged :: BasePart, now)
		end
	end
	for zone in inside do
		if not seen[zone] then
			inside[zone] = nil
		end
	end
	for model, noob in noobs do
		if model.Parent == nil then
			local anims = noob.anims
			if anims then
				anims:Destroy()
			end
			noobs[model] = nil
		end
	end
end

function HubService.Init()
	-- Les bonus en pour cent s'additionnent (DisplayService : M global = (1 + bonus) × multiplicateurs).
	local baseBonus = DisplayService.GetIncomeBonus
	DisplayService.GetIncomeBonus = function(player: Player): number
		return baseBonus(player) + HubService.GetFriendBonus(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

function HubService.Start()
	for _, player in Players:GetPlayers() do
		if friends[player] == nil then
			onPlayerAdded(player)
		end
	end
	local zones = #CollectionService:GetTagged(Hub.InviteZoneTag)
	print(
		`[HubService] bonus d'amis +{math.round(Hub.FriendBonus.PerFriend * 100)} % par ami présent (au plus {Hub.FriendBonus.MaxFriends}) ; {zones} zone(s) {Hub.InviteZoneTag}`
	)
	while true do
		task.wait(Hub.Tick)
		xpcall(step, function(err: any)
			warn(`[HubService] tick : {err}\n{debug.traceback()}`)
		end)
	end
end

return HubService
