--!nocheck
-- Scénarios du banc DEV-017 : CarryService (serveur) et CarryController (client).
-- Copie d'a11, adaptée par a17 (L-031) : BB_Box sur le colis PNJ porté, BB_Carry pour l'objet
-- volé seulement, revenu en Format.income, CarryService.AttachBoxLabel (colis du rayon).

-- a22 : catalogue v2, chaque objet a sa catégorie anglaise (plus de catégorie d'essai injectée).

---------------------------------------------------------------- bouchons
SOURCES["stub/StatsService"] = [[
local StatsService = { calls = {}, modifiers = {} }
function StatsService.SetSpeedModifier(player, key, multiplier)
	table.insert(StatsService.calls, { player = player, key = key, multiplier = multiplier })
	StatsService.modifiers[player] = StatsService.modifiers[player] or {}
	StatsService.modifiers[player][key] = multiplier
end
function StatsService.SetFixedSpeed(player, walkSpeed) -- vitesse fixe (objet volé, Cantin 2026-11-13)
	table.insert(StatsService.calls, { player = player, key = "Fixed", multiplier = walkSpeed })
	StatsService.modifiers[player] = StatsService.modifiers[player] or {}
	StatsService.modifiers[player].Fixed = walkSpeed
end
return StatsService
]]
SOURCES["stub/AnimationController"] = [[
local AnimationController = { calls = {} }
function AnimationController.SetCarrying(on)
	table.insert(AnimationController.calls, on)
end
return AnimationController
]]

---------------------------------------------------------------- arbre du jeu
local shared = make("Folder", { Name = "Shared" }, ReplicatedStorage)
for key in SOURCES do
	local rel = string.match(key, "^shared/(.+)%.luau$")
	if rel then
		local parent = shared
		local segments = string.split(rel, "/")
		for i = 1, #segments - 1 do
			parent = parent:FindFirstChild(segments[i]) or make("Folder", { Name = segments[i] }, parent)
		end
		moduleScript(parent, segments[#segments], key)
	end
end
local server = make("Folder", { Name = "Server" }, ServerScriptService)
local services = make("Folder", { Name = "Services" }, server)
local carryModule = moduleScript(services, "CarryService", "server/Services/CarryService.luau")
local statsModule = moduleScript(services, "StatsService", "stub/StatsService")
local sps = make("StarterPlayerScripts", { Name = "StarterPlayerScripts" }, StarterPlayer)
local clientFolder = make("Folder", { Name = "Client" }, sps)
local controllers = make("Folder", { Name = "Controllers" }, clientFolder)
local controllerModule = moduleScript(controllers, "CarryController", "client/Controllers/CarryController.luau")
local animModule = moduleScript(controllers, "AnimationController", "stub/AnimationController")

local Carry = requireModule(carryModule, "server")
local Stats = requireModule(statsModule, "server")
local Rarities = requireModule(shared.Config.Rarities, "server")
local Balance = requireModule(shared.Config.Balance, "server")
local Bat = requireModule(shared.Config.Bat, "server")
Carry.Init()

---------------------------------------------------------------- aides
local userIds = 0
local function newPlayer(name)
	userIds += 1
	local player = make("Player", { Name = name, UserId = userIds }, Players)
	make("Backpack", { Name = "Backpack" }, player)
	return player
end
local function spawnCharacter(player, x)
	x = x or 0
	local character = make("Model", { Name = player.Name })
	local root = make("Part", { Name = "HumanoidRootPart", Size = Vector3.new(2, 2, 1), CFrame = CFrame.new(x, 3, 0) }, character)
	local head = make("Part", { Name = "Head", Size = Vector3.new(1.2, 1.2, 1.2), CFrame = CFrame.new(x, 4.6, 0) }, character)
	local humanoid = make("Humanoid", { Name = "Humanoid" }, character)
	character.PrimaryPart = root
	character.Parent = Workspace
	player.Character = character
	player.CharacterAdded:Fire(character)
	return character, humanoid, head
end
local function npc(overrides)
	local payload = {
		Kind = "NPCItem", -- a158 (vague 50) : plus de colis porté (NPCBox), on porte l'objet sorti du colis
		Zone = 1,
		Rarity = "Rare",
		ItemId = "Z1_PotDeNouilles",
		StoreId = "STORE_Z1_Superette",
		SlotId = "ShelfSlot_07",
		Luck = 1,
	}
	for k, v in overrides or {} do
		payload[k] = v
	end
	return payload
end
local started, ended, expired = {}, {}, {}
Carry.OnCarryStarted(function(player, payload)
	table.insert(started, { player = player, payload = payload })
end)
Carry.OnCarryEnded(function(player, payload, result, reason)
	table.insert(ended, { player = player, payload = payload, result = result, reason = reason })
end)
Carry.OnDropExpired(function(dropId, payload)
	table.insert(expired, { dropId = dropId, payload = payload })
end)
local function lastEnded()
	return ended[#ended]
end
local function visualOf(character)
	return character:FindFirstChild("CarryVisual")
end
local function count(root, class)
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA(class) then
			n += 1
		end
	end
	return n
end
local function section(name)
	print("--- " .. name)
end

local A = newPlayer("Alice")
local charA, humA, headA = spawnCharacter(A, 0)
local B = newPlayer("Bob")
local charB, humB, headB = spawnCharacter(B, 20)

