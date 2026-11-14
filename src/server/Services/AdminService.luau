--!strict
-- AdminService (vague 29, liaison L-108 point 4) : le panel admin côté serveur. Écran UI_Admin et bouton
-- UI_HUD.AdminButton de Clément (docs/claude/notes/ui-admin.md), branchés par AdminController. Commandes et
-- admins : Config/Admin ; listes de choix : Shared/AdminLists. Le client n'envoie que des Id et des nombres : ce
-- service décide tout et revalide tout.
--
-- Qui est admin (Config/Admin) : tout le monde en Studio ; un UserId de Admin.UserIds ; un membre du groupe du
-- studio de rang Admin.MinGroupRank ou plus (rang lu une fois à l'arrivée, GetRankInGroup ; GroupId = 0 : le groupe
-- propriétaire du jeu). Attribut du Player posé ici : IsAdmin = true pour un admin (le client montre AdminButton ;
-- il n'en décide rien), absent sinon.
--
-- Remote AdminCommand(commandId, target?, value?, text?, text2?) (Net a contrôlé forme et débit). Dans l'ordre :
--   1. appelant pas admin : ignoré, une ligne dans la sortie, aucune réponse ;
--   2. commande inconnue de Config/Admin.ById : refusée ;
--   3. StudioOnly hors de Studio : refusée (« Studio only for now. ») ;
--   4. cible : `target` s'il est un joueur présent sur le serveur, sinon refusée ; absente = l'appelant ;
--   5. chaque argument revalidé (entier, bornes, Id connu de Config) ; un argument faux = refus, rien ne change ;
--   6. l'action, par les services existants (aucune logique recopiée) ;
--   7. réponse au seul admin : AdminResult(commandId, ok, message) ; journal dans la sortie (toujours) et
--      télémétrie (événement AdminCommand, champ « Command - <Id> ») pour une commande acceptée.
--
-- Commandes (value = nombre, text et text2 = Id) :
--   GiveCash, GiveSpeed, GiveStrength  value = montant (1 à Admin.MaxAmount) : DataService.AddCash,
--                                      StatsService.AddSpeed / AddStrength
--   SetTreadmill, SetBench             value = niveau (0 à MaxLevel de Config/Upgrades) : Upgrades du profil,
--                                      puis ShopService.RefreshPlayer (attributs), MachineVariantService.Refresh
--   SetShopLevel                       value = k (1 à 5) : présentoirs achetés = le minimum pour k rayons montrés
--                                      (ShopStageService suit RayonService)
--   SetRayons                          value = k (1 à 5) : k rayons pleins (4 × k présentoirs débloqués)
--   GiveItem                           text = ItemId, text2 = mutation (« Huge », « Gold », « Huge Gold » ;
--                                      "" = aucune), value = zone d'un objet sans zone (Secret ; 1 par défaut).
--                                      Refusé si l'inventaire est plein (DisplayService.HasInventoryRoom)
--   GiveBox                            text = rareté : un colis de cette rareté exactement (objet tiré dans
--                                      Config/Items, mutation tirée comme en rayon), value = zone facultative
--                                      (sinon la première zone qui a un objet de cette rareté) ; Tier V0 selon la
--                                      rareté (BOX_TIER_BY_ORDER) ; refusé au plafond Unbox.BoxInventoryMax
--   GiveAura, GiveTrail                text = Id de Config/Cosmetics : CosmeticService.Grant puis Equip
--   GivePotion (Studio)                text = Id de Config/Potions : crochet PotionTest « <UserId> give <Id> »
--   GiveGamepass (Studio)              text = clé de Config/Monetization.Passes : crochet MonetizationTest (drapeau
--                                      de la session ; jamais un produit, un achat ni un reçu). Refusé si la
--                                      boutique Robux est coupée (Features.RobuxShop)
--   SetSkill (Studio)                  text = Id de Config/SkillTree, value = niveau : crochet SkillTest
--   StartEvent (Studio)                text = Truck (value = zone, au hasard sinon : crochet TruckSpawnNow), Night
--                                      ou Day (value = durée en s, facultative : NightCycleService.SkipTo) ;
--                                      vague 39 : Fortune, FortuneOpen, FortuneSeal (FortuneTowerService.Force :
--                                      lancer, ouvrir, refermer la vitrine) ; Truck refusé pendant une vitrine
--   Teleport                           value = 0 (sa boutique, PlotService.TeleportHome) ou une zone de 1 à 6 :
--                                      au milieu des magasins PNJ de la zone (tag NPCStore, attribut Zone), posé
--                                      au sol ; AntiCheatService.Allow juste avant
--   ResetProfile                       text = Admin.ResetConfirm : la cible est renvoyée du serveur (Kick) et son
--                                      profil est remplacé par DataService.NewData() juste avant sa sauvegarde
--                                      (OnProfileReleasing, abonné en dernier), en gardant Purchases et
--                                      Monetization (achats Robux : idempotence, 9.6)
--
-- Crochets Studio : écouter des attributs du Workspace ne vaut qu'en Studio (en-têtes de ces services) ; les
-- commandes qui en dépendent sont StudioOnly. Les ouvrir en ligne : une ligne par service, à décider.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Admin = require(Shared.Config.Admin)
local Balance = require(Shared.Config.Balance)
local Cosmetics = require(Shared.Config.Cosmetics)
local Features = require(Shared.Config.Features)
local Items = require(Shared.Config.Items)
local Monetization = require(Shared.Config.Monetization)
local Mutations = require(Shared.Config.Mutations)
local Potions = require(Shared.Config.Potions)
local Rarities = require(Shared.Config.Rarities)
local SkillTree = require(Shared.Config.SkillTree)
local Unbox = require(Shared.Config.Unbox)
local Upgrades = require(Shared.Config.Upgrades)
local Zones = require(Shared.Config.Zones)
local Format = require(Shared.Format)
local Net = require(Shared.Net.Net)
local ProfileTypes = require(Shared.Types.Profile)

local AntiCheatService = require(script.Parent.AntiCheatService)
local CosmeticService = require(script.Parent.CosmeticService)
local DataService = require(script.Parent.DataService)
local DisplayService = require(script.Parent.DisplayService)
local FortuneTowerService = require(script.Parent.FortuneTowerService)
local IndexService = require(script.Parent.IndexService)
local InventoryService = require(script.Parent.InventoryService)
local MachineVariantService = require(script.Parent.MachineVariantService)
local MonetizationService = require(script.Parent.MonetizationService)
local NightCycleService = require(script.Parent.NightCycleService)
local PlotService = require(script.Parent.PlotService)
local RayonService = require(script.Parent.RayonService)
local ShopService = require(script.Parent.ShopService)
local StatsService = require(script.Parent.StatsService)
local TelemetryService = require(script.Parent.TelemetryService)
local UnboxService = require(script.Parent.UnboxService)

type Data = ProfileTypes.Data
type Box = ProfileTypes.Box

-- Ce qu'une commande reçoit, déjà résolu.
type Call = {
	admin: Player,
	target: Player,
	value: number?,
	text: string?,
	text2: string?,
}

-- Une commande renvoie ok et le message montré à l'admin (anglais, texte du jeu).
type Handler = (call: Call) -> (boolean, string)

-- V0 proposés, absents du doc.
local ADMIN_ATTRIBUTE = "IsAdmin"
local STORE_TAG = "NPCStore"
local SLOTS_PER_RAYON = 4 -- L-082 : 5 rayons de 4 présentoirs (comme RayonService)
local TELEPORT_RAY_HEIGHT = 60 -- studs au-dessus du milieu des magasins d'où part le rayon vers le sol
local TELEPORT_LIFT = 4 -- studs au-dessus du sol trouvé
local BOX_TIER_BY_ORDER: { [number]: string } = { "Standard", "Standard", "Premium", "Premium", "Luxe" } -- au-delà : Luxe
-- Crochets de test (en-têtes de PotionService, MonetizationService, SkillTreeService et TruckEventService).
local POTION_HOOK = "PotionTest"
local PASS_HOOK = "MonetizationTest"
local SKILL_HOOK = "SkillTest"
local TRUCK_HOOK = "TruckSpawnNow"
-- Vague 39 : événements de la Fortune Tower → action de FortuneTowerService.Force ; vitrine en jeu (tag).
local FORTUNE_ACTIONS: { [string]: string } = { Fortune = "Spawn", FortuneOpen = "Open", FortuneSeal = "Seal" }
local FORTUNE_VAULT_TAG = "FortuneVault"

local IS_STUDIO = RunService:IsStudio()

local AdminService = {}
AdminService.Priority = 1000 -- en dernier : son OnProfileReleasing passe après celui des autres services

local groupRanks: { [Player]: number } = {}
local pendingReset: { [Player]: boolean } = {}
local random = Random.new()

local function log(message: string)
	print(`[AdminService] {message}`)
end

------------------------------------------------------------------------------
-- Qui est admin
------------------------------------------------------------------------------

local function groupId(): number
	if Admin.GroupId ~= 0 then
		return Admin.GroupId
	end
	if game.CreatorType == Enum.CreatorType.Group then
		return game.CreatorId
	end
	return 0
end

function AdminService.IsAdmin(player: Player): boolean
	if IS_STUDIO and Admin.StudioEveryone then
		return true
	end
	if table.find(Admin.UserIds, player.UserId) ~= nil then
		return true
	end
	local rank = groupRanks[player]
	return rank ~= nil and rank >= Admin.MinGroupRank
end

local function publishAdmin(player: Player)
	player:SetAttribute(ADMIN_ATTRIBUTE, if AdminService.IsAdmin(player) then true else nil)
end

local function onPlayerAdded(player: Player)
	publishAdmin(player)
	local group = groupId()
	if group == 0 or (IS_STUDIO and Admin.StudioEveryone) then
		return
	end
	task.spawn(function()
		local ok, rank = pcall(player.GetRankInGroup, player, group)
		if player.Parent ~= Players then
			return
		end
		if ok and type(rank) == "number" then
			groupRanks[player] = rank
		else
			warn(`[AdminService] rang de {player.Name} dans le groupe {group} illisible : {rank}`)
		end
		publishAdmin(player)
	end)
end

------------------------------------------------------------------------------
-- Outils
------------------------------------------------------------------------------

local function isInt(value: number?, min: number, max: number): boolean
	return value ~= nil and value == math.floor(value) and value >= min and value <= max
end

local function nonEmpty(text: string?): string?
	return if text ~= nil and text ~= "" then text else nil
end

local function setHook(name: string, value: any)
	Workspace:SetAttribute(name, value)
end

local function refreshBase(player: Player)
	ShopService.RefreshPlayer(player)
	UnboxService.Refresh(player)
	local plot = PlotService.GetPlot(player)
	if plot then
		MachineVariantService.Refresh(plot)
		RayonService.Refresh(plot)
	end
end

local function setUpgrade(call: Call, key: string, level: number): (boolean, string)
	local data = DataService.Get(call.target)
	if data == nil then
		return false, "Profile not loaded."
	end
	local upgrades = data.Upgrades :: any
	upgrades[key] = level
	refreshBase(call.target)
	return true, if key == "DisplaySlots" then `{call.target.Name}: {level} display stands bought` else `{call.target.Name}: {key} level {level}`
end

local function upgradeLevel(call: Call, key: string): (boolean, string)
	local def = Upgrades.ById[key]
	local value = call.value
	if def == nil or not isInt(value, 0, def.MaxLevel) then
		return false, `Level must be 0 to {if def then def.MaxLevel else 0}.`
	end
	return setUpgrade(call, key, value :: number)
end

-- Présentoirs achetés pour que `slots` présentoirs soient débloqués, bornés à MaxLevel.
local function boughtFor(slots: number): number
	local max = Upgrades.ById.DisplaySlots.MaxLevel
	return math.clamp(slots - Balance.Display.StartSlots, 0, max)
end

local function maxRayons(): number
	return math.ceil((Balance.Display.StartSlots + Upgrades.ById.DisplaySlots.MaxLevel) / SLOTS_PER_RAYON)
end

-- Mutation lue dans « Huge Gold » : une taille et un effet au plus ; nil + false si un mot est inconnu.
local function parseMutation(text: string?): (Mutations.Mutation?, boolean)
	local value = nonEmpty(text)
	if value == nil then
		return nil, true
	end
	local mutation: Mutations.Mutation = {}
	for word in string.gmatch(value, "%S+") do
		if Mutations.SizeById[word] and mutation.Size == nil then
			mutation.Size = word
		elseif Mutations.EffectById[word] and mutation.Effect == nil then
			mutation.Effect = word
		else
			return nil, false
		end
	end
	return Mutations.Sanitize(mutation), true
end

local function newUid(list: { [string]: any }): string
	local uid = HttpService:GenerateGUID(false)
	while list[uid] ~= nil do
		uid = HttpService:GenerateGUID(false)
	end
	return uid
end

-- La carte jouée : dans le Workspace, hors des dossiers de travail (_INBOX_CLEMENT, _SHOWROOM_CLEMENT…).
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

-- Point de téléport d'une zone : milieu des magasins PNJ de la zone, posé au sol.
local function zonePoint(zone: number): Vector3?
	local sum = Vector3.zero
	local count = 0
	for _, store in CollectionService:GetTagged(STORE_TAG) do
		if store:GetAttribute("Zone") == zone and store:IsA("PVInstance") and inMap(store) then
			sum += (store :: any):GetPivot().Position
			count += 1
		end
	end
	if count == 0 then
		return nil
	end
	local middle = sum / count
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local characters: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(characters, player.Character)
		end
	end
	params.FilterDescendantsInstances = characters
	local origin = middle + Vector3.new(0, TELEPORT_RAY_HEIGHT, 0)
	local hit = Workspace:Raycast(origin, Vector3.new(0, -TELEPORT_RAY_HEIGHT * 2, 0), params)
	local ground = if hit then hit.Position else middle
	return ground + Vector3.new(0, TELEPORT_LIFT, 0)
end

------------------------------------------------------------------------------
-- Commandes
------------------------------------------------------------------------------

local handlers: { [string]: Handler } = {}

local function giveAmount(call: Call, add: (Player, number) -> number?, what: string): (boolean, string)
	local amount = call.value
	if amount == nil or amount < 1 or amount > Admin.MaxAmount then
		return false, `Amount must be 1 to {Format.short(Admin.MaxAmount)}.`
	end
	if add(call.target, amount) == nil then
		return false, "Profile not loaded."
	end
	return true, `Gave {what} {Format.short(amount)} to {call.target.Name}`
end

handlers.GiveCash = function(call: Call): (boolean, string)
	local amount = call.value
	if amount == nil or amount < 1 or amount > Admin.MaxAmount then
		return false, `Amount must be 1 to {Format.short(Admin.MaxAmount)}.`
	end
	if DataService.AddCash(call.target, amount) == nil then
		return false, "Profile not loaded."
	end
	return true, `Gave {Format.money(amount)} to {call.target.Name}`
end

handlers.GiveSpeed = function(call: Call): (boolean, string)
	return giveAmount(call, StatsService.AddSpeed, "Speed")
end

handlers.GiveStrength = function(call: Call): (boolean, string)
	return giveAmount(call, StatsService.AddStrength, "Strength")
end

handlers.SetTreadmill = function(call: Call): (boolean, string)
	return upgradeLevel(call, "Treadmill")
end

handlers.SetBench = function(call: Call): (boolean, string)
	return upgradeLevel(call, "Bench")
end

handlers.SetShopLevel = function(call: Call): (boolean, string)
	local value = call.value
	if not isInt(value, 1, maxRayons()) then
		return false, `Shop level must be 1 to {maxRayons()}.`
	end
	-- Niveau k = k rayons montrés : le premier présentoir du rayon k débloqué.
	local level = value :: number
	return setUpgrade(call, "DisplaySlots", boughtFor((level - 1) * SLOTS_PER_RAYON + 1))
end

handlers.SetRayons = function(call: Call): (boolean, string)
	local value = call.value
	if not isInt(value, 1, maxRayons()) then
		return false, `Rayons must be 1 to {maxRayons()}.`
	end
	return setUpgrade(call, "DisplaySlots", boughtFor((value :: number) * SLOTS_PER_RAYON))
end

handlers.GiveItem = function(call: Call): (boolean, string)
	local id = nonEmpty(call.text)
	local item = if id then Items.ById[id] else nil
	if item == nil then
		return false, "Unknown item."
	end
	local mutation, valid = parseMutation(call.text2)
	if not valid then
		return false, "Unknown mutation."
	end
	if call.value ~= nil and not isInt(call.value, 1, #Zones) then
		return false, `Zone must be 1 to {#Zones}.`
	end
	local data = DataService.Get(call.target)
	if data == nil then
		return false, "Profile not loaded."
	end
	if not DisplayService.HasInventoryRoom(call.target) then
		return false, `{call.target.Name}'s inventory is full.`
	end
	if item.TutorialOnly then
		mutation = nil
	end
	local uid = newUid(data.Items)
	data.Items[uid] = { Id = item.Id, Source = "NPC", At = os.time(), Zone = item.Zone or call.value or 1, Mutation = mutation }
	IndexService.Discover(call.target, item.Id)
	InventoryService.Refresh(call.target)
	return true, `Gave {Mutations.ItemName(item.DisplayName, mutation)} to {call.target.Name}`
end

handlers.GiveBox = function(call: Call): (boolean, string)
	local id = nonEmpty(call.text)
	local rarity = if id then Rarities.ById[id] else nil
	if rarity == nil then
		return false, "Unknown rarity."
	end
	if call.value ~= nil and not isInt(call.value, 1, #Zones) then
		return false, `Zone must be 1 to {#Zones}.`
	end
	local data = DataService.Get(call.target)
	if data == nil then
		return false, "Profile not loaded."
	end
	local stored = 0
	for _, box in data.Boxes do
		if type(box) == "table" and box.Spot == nil then
			stored += 1
		end
	end
	if stored >= Unbox.BoxInventoryMax then
		return false, `{call.target.Name} has too many boxes.`
	end
	-- La zone demandée d'abord, puis les autres dans l'ordre.
	local order: { number } = {}
	if call.value ~= nil then
		table.insert(order, call.value :: number)
	end
	for zone in Zones do
		if zone ~= call.value then
			table.insert(order, zone)
		end
	end
	local item, zone = nil, 0
	for _, candidate in order do
		local picked = Items.Pick(candidate, rarity.Id :: any, random)
		if picked ~= nil and not picked.TutorialOnly then
			item, zone = picked, candidate
			break
		end
	end
	if item == nil then
		return false, `No {rarity.DisplayName} item to put in a box.`
	end
	local box: Box = {
		Tier = (BOX_TIER_BY_ORDER[rarity.Order] or "Luxe") :: any,
		Zone = zone,
		ItemId = item.Id,
		Rarity = rarity.Id,
		ReadyAt = nil,
		Mutation = Mutations.Roll(random),
		Spot = nil,
		At = os.time(),
	}
	data.Boxes[newUid(data.Boxes)] = box
	InventoryService.Refresh(call.target)
	return true, `Gave {rarity.DisplayName} box to {call.target.Name}`
end

local function giveCosmetic(call: Call, kind: string): (boolean, string)
	local id = nonEmpty(call.text)
	local def = if id then Cosmetics.ById[id] else nil
	if def == nil or def.Kind ~= kind then
		return false, `Unknown {string.lower(kind)}.`
	end
	if not CosmeticService.Grant(call.target, def.Id) then
		return false, "Profile not loaded."
	end
	CosmeticService.Equip(call.target, def.Id)
	return true, `Gave {def.DisplayName} to {call.target.Name}`
end

handlers.GiveAura = function(call: Call): (boolean, string)
	return giveCosmetic(call, "Aura")
end

handlers.GiveTrail = function(call: Call): (boolean, string)
	return giveCosmetic(call, "Trail")
end

handlers.GivePotion = function(call: Call): (boolean, string)
	local id = nonEmpty(call.text)
	local potion = if id then Potions.ById[id] else nil
	if potion == nil then
		return false, "Unknown potion."
	end
	setHook(POTION_HOOK, `{call.target.UserId} give {potion.Id}`)
	return true, `Gave {potion.DisplayName} potion to {call.target.Name}`
end

handlers.GiveGamepass = function(call: Call): (boolean, string)
	local key = nonEmpty(call.text)
	local pass = if key then Monetization.PassByKey[key] else nil
	if pass == nil then
		return false, "Unknown game pass."
	end
	if not MonetizationService.IsEnabled() then
		return false, "Robux shop is off (Features.RobuxShop)."
	end
	setHook(PASS_HOOK, `{call.target.UserId} {pass.Key}`)
	return true, `Gave {pass.DisplayName} to {call.target.Name} (this session)`
end

handlers.SetSkill = function(call: Call): (boolean, string)
	local id = nonEmpty(call.text)
	local skill = if id then SkillTree.ById[id] else nil
	if skill == nil then
		return false, "Unknown skill."
	end
	if not isInt(call.value, 0, skill.MaxLevel) then
		return false, `Level must be 0 to {skill.MaxLevel}.`
	end
	setHook(SKILL_HOOK, `{call.target.UserId} {skill.Id} {call.value}`)
	return true, `{call.target.Name}: {skill.DisplayName} level {call.value}`
end

handlers.StartEvent = function(call: Call): (boolean, string)
	local event = nonEmpty(call.text)
	if event == "Truck" then
		if not Features.TruckEvent then
			return false, "Truck event is off (Features.TruckEvent)."
		end
		local zone = call.value or random:NextInteger(1, #Zones)
		if not isInt(zone, 1, #Zones) then
			return false, `Zone must be 1 to {#Zones}.`
		end
		for _, vault in CollectionService:GetTagged(FORTUNE_VAULT_TAG) do
			if vault:IsDescendantOf(Workspace) then
				return false, "A Fortune vault is in play: no truck now."
			end
		end
		setHook(TRUCK_HOOK, zone)
		return true, `Truck sent to zone {zone}`
	elseif event == "Night" or event == "Day" then
		local seconds = if call.value ~= nil and call.value > 0 then call.value else nil
		if not NightCycleService.SkipTo(event :: string, seconds) then
			return false, "Day/night cycle is off."
		end
		return true, `{event} started`
	end
	local action = if event then FORTUNE_ACTIONS[event] else nil
	if action ~= nil then
		return FortuneTowerService.Force(action)
	end
	return false, "Unknown event."
end

handlers.Teleport = function(call: Call): (boolean, string)
	local zone = call.value
	if not isInt(zone, 0, #Zones) then
		return false, `Zone must be 0 to {#Zones}.`
	end
	if zone == 0 then
		if not PlotService.TeleportHome(call.target) then
			return false, `{call.target.Name} can't go home right now.`
		end
		return true, `{call.target.Name} sent to the safe zone`
	end
	local character = call.target.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if character == nil or root == nil then
		return false, `{call.target.Name} has no character.`
	end
	local point = zonePoint(zone :: number)
	if point == nil then
		return false, `No store found in zone {zone}.`
	end
	AntiCheatService.Allow(call.target, 0, "AdminService (téléport)")
	character:PivotTo(CFrame.new(point))
	return true, `{call.target.Name} sent to zone {zone}`
end

handlers.ResetProfile = function(call: Call): (boolean, string)
	if call.text ~= Admin.ResetConfirm then
		return false, "Reset not confirmed."
	end
	if DataService.Get(call.target) == nil then
		return false, "Profile not loaded."
	end
	pendingReset[call.target] = true
	local name = call.target.Name
	-- Après la réponse : l'admin peut se viser lui-même.
	task.defer(function()
		if call.target.Parent == Players then
			call.target:Kick(Admin.Messages.Kicked)
		end
	end)
	return true, `{name}'s profile will be reset`
end

-- Juste avant la sauvegarde de départ : profil neuf, achats Robux gardés.
local function onProfileReleasing(player: Player)
	if not pendingReset[player] then
		return
	end
	pendingReset[player] = nil
	local data = DataService.Get(player)
	if data == nil then
		return
	end
	local fresh = DataService.NewData() :: any
	local old = data :: any
	local purchases, monetization = old.Purchases, old.Monetization
	for key in table.clone(old) do
		old[key] = nil
	end
	for key, value in fresh do
		old[key] = value
	end
	old.Purchases = purchases
	old.Monetization = monetization
	log(`profil de {player.Name} ({player.UserId}) remis à zéro (achats Robux gardés)`)
end

------------------------------------------------------------------------------
-- Remote
------------------------------------------------------------------------------

local function describe(value: number?, text: string?, text2: string?): string
	local parts: { string } = {}
	if value ~= nil then
		table.insert(parts, `value={value}`)
	end
	if text ~= nil then
		table.insert(parts, `text="{text}"`)
	end
	if text2 ~= nil then
		table.insert(parts, `text2="{text2}"`)
	end
	return table.concat(parts, " ")
end

local function reply(admin: Player, commandId: string, ok: boolean, message: string)
	Net.Server.AdminResult:Fire(admin, commandId, ok, string.sub(message, 1, 200))
end

function AdminService.Run(admin: Player, commandId: string, target: Player?, value: number?, text: string?, text2: string?): (boolean, string)
	local who = `{admin.Name} ({admin.UserId})`
	if not AdminService.IsAdmin(admin) then
		warn(`[AdminService] refusé : {who} n'est pas admin ({commandId})`)
		return false, "Not an admin."
	end
	local command = Admin.ById[commandId]
	local handler = handlers[commandId]
	local function finish(ok: boolean, message: string, targetName: string?): (boolean, string)
		local on = if targetName then ` → {targetName}` else ""
		log(`{who} {commandId}{on} {describe(value, text, text2)} : {if ok then "ok" else "refusé"}, {message}`)
		if ok then
			TelemetryService.LogEvent(admin, "AdminCommand", { `Command - {commandId}` })
		end
		reply(admin, commandId, ok, message)
		return ok, message
	end
	if command == nil or handler == nil then
		return finish(false, "Unknown command.")
	end
	if command.StudioOnly and not IS_STUDIO then
		return finish(false, Admin.Messages.StudioOnly)
	end
	local chosen = admin
	if command.Target and target ~= nil then
		if typeof(target) ~= "Instance" or not target:IsA("Player") or target.Parent ~= Players then
			return finish(false, "That player is not on this server.")
		end
		chosen = target
	end
	local call: Call = { admin = admin, target = chosen, value = value, text = text, text2 = text2 }
	local ok, okResult, message = pcall(handler, call)
	if not ok then
		warn(`[AdminService] erreur dans {commandId} : {okResult}`)
		return finish(false, "Server error.", if command.Target then chosen.Name else nil)
	end
	return finish(okResult == true, if type(message) == "string" then message else "", if command.Target then chosen.Name else nil)
end

------------------------------------------------------------------------------
-- Démarrage
------------------------------------------------------------------------------

function AdminService.Init()
	Net.Server.AdminCommand:Connect(function(player: Player, commandId: string, target: Player?, value: number?, text: string?, text2: string?)
		AdminService.Run(player, commandId, target, value, text, text2)
	end)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player: Player)
		groupRanks[player] = nil
		-- pendingReset est vidé par onProfileReleasing (avant ou après ce signal) ; sans profil, au tour suivant.
		task.defer(function()
			pendingReset[player] = nil
		end)
	end)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

function AdminService.Start()
	-- Dans Start, après tous les Init : son OnProfileReleasing passe après ceux des autres services.
	DataService.OnProfileReleasing(onProfileReleasing)
	local group = groupId()
	local where = if IS_STUDIO and Admin.StudioEveryone then "Studio : tout le monde est admin" else `{#Admin.UserIds} UserId(s), groupe {group} rang {Admin.MinGroupRank} ou plus`
	log(`{#Admin.Commands} commandes ; {where}`)
end

return AdminService
