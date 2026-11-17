--!strict
-- TrapService (vague 72, a243 ; liaison L-218, L-216 point 11) : pièges de la boutique d'un joueur, côté serveur.
-- Contrat et valeurs (toutes V0, à valider par Clément) : Config/Traps ; interrupteur Features.Traps (false : aucun
-- piège posé, la tuile Traps de l'arbre reste « Soon »).
--
-- Achat : la tuile Traps de l'arbre (Config/SkillTree, SkillTreeService : prix, renaissance, OpensWhen). Son
-- Effects[niveau] = nombre de pièges posés. Rien d'autre ne s'achète ici, aucun remote : le client ne demande rien.
-- Pose : pour la boutique de chaque joueur, un piège par emplacement TrapSlot_01 à _0n (n = ce nombre, et
-- seulement les emplacements présents dans la boutique), du genre Traps.SlotLayout[i] : copie de
-- ReplicatedStorage/Assets/Traps/TRAP_<Id> (sans script, pièces ancrées, TriggerZone sans collision ni requête),
-- sinon un modèle de repli construit ici ; pivot posé sur l'emplacement (WorldCFrame d'un Attachment, bas d'une
-- pièce). Copie nommée Trap_0i, dans le dossier Traps.Folder de la boutique, tag Traps.Tag, attributs TrapId et
-- TrapState (« Armed »). Remise à jour à l'achat (SkillTreeService.OnChanged), à l'attribution de la boutique, au
-- chargement du profil et toutes les Traps.SyncInterval s (étages de la boutique reconstruits, emplacement
-- déplacé) ; tout est retiré quand la boutique est libérée. Pas de piège dans la boutique du bot.
-- Déclenchement, Traps.CheckInterval fois par seconde : un piège armé se déclenche quand le HumanoidRootPart d'un
-- joueur vivant est dans son TriggerZone (boîte orientée), sauf le propriétaire (Traps.SpareFriends : aucune règle
-- d'amis au vol, les amis sont pris), et sauf un joueur pris par un piège de cette boutique il y a moins de
-- Traps.Immunity s. Le piège passe en « Triggered » (le client montre Triggered, son 3D) pendant Traps.Recharge s,
-- puis se réarme. Effet sur le joueur (StatsService, clé « Trap ») : vitesse 0 pendant StopTime s, puis
-- × SlowMultiplier pendant SlowTime s ; attribut TrapEffect = Id du piège tant que l'effet dure (animation chez
-- son client) ; un nouveau piège remplace l'effet en cours. Notify au voleur (« Warning ») et au propriétaire
-- (« Alert ») ; Spot > 0 (portique) : CameraSpotted au propriétaire, le voleur est surligné Spot s
-- (CameraAlertController). Effet retiré à la réapparition et au départ.
--
-- API (serveur, pour les tests) :
--   TrapService.Sync(plot)               remet à jour les pièges posés de cette boutique
--   TrapService.Step()                   un contrôle des volumes, tout de suite
--   TrapService.GetTraps(plot) -> { { Slot, Id, State, Model } }
--   TrapService.IsEnabled() -> boolean
--
-- Tester dans Studio (barre de commande serveur, en Play) :
--   workspace:SetAttribute("TrapsTest", true)     allume les pièges sans toucher Features.Traps
--   workspace:SetAttribute("TrapsTest", "self")   pareil, et le propriétaire est pris par ses propres pièges
--   workspace:SetAttribute("SkillTest", "<joueur> Traps 4")   4 pièges posés dans sa boutique (SkillTreeService)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Features = require(Shared.Config.Features)
local Traps = require(Shared.Config.Traps)
local Net = require(Shared.Net.Net)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local SkillTreeService = require(script.Parent.SkillTreeService)
local StatsService = require(script.Parent.StatsService)

type Trap = Traps.Trap

type Placed = {
	Slot: number,
	Id: string,
	SlotInstance: Instance,
	Model: Model,
	Zone: BasePart?,
	State: string,
	Token: number,
}

local SKILL_ID = "Traps"
local SPEED_KEY = "Trap"
local TEST_ATTRIBUTE = "TrapsTest"
local IS_STUDIO = RunService:IsStudio()

local TrapService = {}

local placed: { [Model]: { [number]: Placed } } = {}
local immuneUntil: { [Player]: { [Model]: number } } = {}
local effectTokens: { [Player]: number } = {}
local tokenCounter = 0

local function log(message: string)
	if IS_STUDIO then
		print(`[TrapService] {message}`)
	end
end

local function notify(player: Player, message: string, kind: string)
	local ok, err = pcall(function()
		Net.Server.Notify:Fire(player, message, kind)
	end)
	if not ok then
		warn(`[TrapService] Notify vers {player.Name} : {err}`)
	end
end

function TrapService.IsEnabled(): boolean
	return Features.Traps == true or (IS_STUDIO and Workspace:GetAttribute(TEST_ATTRIBUTE) ~= nil)
end

local function ownerCanTrigger(): boolean
	return IS_STUDIO and Workspace:GetAttribute(TEST_ATTRIBUTE) == "self"
end

------------------------------------------------------------------------------
-- Pose
------------------------------------------------------------------------------

local function assetsFolder(): Instance?
	local current: Instance? = ReplicatedStorage
	for _, segment in Traps.AssetsFolder do
		current = if current then current:FindFirstChild(segment) else nil
	end
	return current
end

-- Nombre de pièges posés pour ce propriétaire (Effects[niveau] de la tuile Traps), borné aux emplacements prévus.
local function trapCount(owner: Player): number
	local effect = SkillTreeService.GetEffect(owner, SKILL_ID)
	if type(effect) ~= "number" or effect ~= effect then
		return 0
	end
	return math.clamp(math.floor(effect), 0, #Traps.SlotLayout)
end

local function slotCFrame(slot: Instance): CFrame?
	if slot:IsA("Attachment") then
		return slot.WorldCFrame
	elseif slot:IsA("BasePart") then
		return slot.CFrame * CFrame.new(0, -slot.Size.Y / 2, 0)
	elseif slot:IsA("PVInstance") then
		return slot:GetPivot()
	end
	return nil
end

local function findSlot(plot: Model, index: number): Instance?
	local name = string.format(Traps.SlotName, index)
	local folder = plot:FindFirstChild(Traps.Folder)
	for _, inst in plot:GetDescendants() do
		if inst.Name == name and not (folder and inst:IsDescendantOf(folder)) then
			return inst
		end
	end
	return nil
end

local function makePart(name: string, size: Vector3, cf: CFrame, color: Color3, transparency: number): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Transparency = transparency
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- Repli quand TRAP_<Id> manque : une plaque de la couleur du piège (Armed) et un éclat néon (Triggered, caché).
local function buildFallback(trap: Trap): Model
	local model = Instance.new("Model")
	model.Name = trap.Model
	local base = makePart("Base", Vector3.new(3.4, 0.2, 3.4), CFrame.new(0, 0.1, 0), trap.FallbackColor, 1)
	base.Parent = model
	local zone = makePart("TriggerZone", Vector3.new(3.4, 5, 3.4), CFrame.new(0, 2.5, 0), Color3.new(1, 1, 1), 1)
	zone.CanQuery = false
	zone.Parent = model
	local armed = Instance.new("Model")
	armed.Name = "Armed"
	makePart("Plate", Vector3.new(3.2, 0.15, 3.2), CFrame.new(0, 0.1, 0), trap.FallbackColor, 0).Parent = armed
	armed.Parent = model
	local triggered = Instance.new("Model")
	triggered.Name = "Triggered"
	local burst = makePart("Burst", Vector3.new(3.4, 1.2, 3.4), CFrame.new(0, 0.6, 0), trap.FallbackColor, 1)
	burst.Material = Enum.Material.Neon
	burst:SetAttribute("ShownTransparency", 0.4)
	burst.Parent = triggered
	triggered.Parent = model
	model.PrimaryPart = base
	model:SetAttribute(Traps.TrapIdAttribute, trap.Id)
	return model
end

local function makeTrapModel(trap: Trap): Model
	local folder = assetsFolder()
	local template = if folder then folder:FindFirstChild(trap.Model) else nil
	local model: Model
	if template and template:IsA("Model") then
		model = template:Clone()
	else
		model = buildFallback(trap)
	end
	for _, inst in model:GetDescendants() do
		if inst:IsA("LuaSourceContainer") then
			inst:Destroy()
		elseif inst:IsA("BasePart") then
			inst.Anchored = true
			if inst.Name == "TriggerZone" then
				inst.CanCollide = false
				inst.CanQuery = false
				inst.CanTouch = false
			end
		end
	end
	return model
end

local function destroyPlaced(entry: Placed)
	entry.Token += 1
	entry.Model:Destroy()
end

local function place(plot: Model, index: number, trap: Trap, slot: Instance): Placed?
	local cf = slotCFrame(slot)
	if cf == nil then
		return nil
	end
	local folder = plot:FindFirstChild(Traps.Folder)
	if folder == nil then
		local created = Instance.new("Folder")
		created.Name = Traps.Folder
		created.Parent = plot
		folder = created
	end
	local model = makeTrapModel(trap)
	model.Name = string.format(Traps.PlacedName, index)
	model:PivotTo(cf)
	model:SetAttribute(Traps.TrapIdAttribute, trap.Id)
	model:SetAttribute(Traps.StateAttribute, Traps.Armed)
	CollectionService:AddTag(model, Traps.Tag)
	model.Parent = folder
	local zone = model:FindFirstChild("TriggerZone", true)
	return {
		Slot = index,
		Id = trap.Id :: string,
		SlotInstance = slot,
		Model = model,
		Zone = if zone and zone:IsA("BasePart") then zone else nil,
		State = Traps.Armed,
		Token = 0,
	}
end

local function clearPlot(plot: Model)
	local list = placed[plot]
	if list then
		for _, entry in list do
			destroyPlaced(entry)
		end
	end
	placed[plot] = nil
	local folder = plot:FindFirstChild(Traps.Folder)
	if folder then
		folder:Destroy()
	end
	for _, byPlot in immuneUntil do
		byPlot[plot] = nil
	end
end

function TrapService.Sync(plot: Model)
	local owner = PlotService.GetOwner(plot)
	local count = if owner and TrapService.IsEnabled() and not PlotService.IsBotPlot(plot) then trapCount(owner) else 0
	if count == 0 then
		if placed[plot] or plot:FindFirstChild(Traps.Folder) then
			clearPlot(plot)
		end
		return
	end
	local list = placed[plot] or {}
	placed[plot] = list
	for index = 1, #Traps.SlotLayout do
		local entry = list[index]
		local trap = if index <= count then Traps.ById[Traps.SlotLayout[index]] else nil
		local slot = if trap then findSlot(plot, index) else nil
		local keep = entry ~= nil
			and trap ~= nil
			and entry.Id == trap.Id
			and slot == entry.SlotInstance
			and entry.Model.Parent ~= nil
			and entry.Model:IsDescendantOf(plot)
		if entry and not keep then
			destroyPlaced(entry)
			list[index] = nil
		end
		if trap and slot and not keep then
			local created = place(plot, index, trap, slot)
			list[index] = created
			if created then
				log(`{plot.Name} : {trap.Id} posé sur {slot.Name}`)
			end
		end
	end
end

local function syncPlayer(player: Player)
	local plot = PlotService.GetPlot(player)
	if plot then
		TrapService.Sync(plot)
	end
end

function TrapService.GetTraps(plot: Model): { { Slot: number, Id: string, State: string, Model: Model } }
	local result: { { Slot: number, Id: string, State: string, Model: Model } } = {}
	local list = placed[plot]
	for index = 1, #Traps.SlotLayout do
		local entry: Placed? = if list then list[index] else nil
		if entry then
			table.insert(result, { Slot = entry.Slot, Id = entry.Id, State = entry.State, Model = entry.Model })
		end
	end
	return result
end

------------------------------------------------------------------------------
-- Effet sur le joueur pris
------------------------------------------------------------------------------

local function clearEffect(player: Player)
	effectTokens[player] = nil
	StatsService.SetSpeedModifier(player, SPEED_KEY, nil)
	if player:GetAttribute(Traps.EffectAttribute) ~= nil then
		player:SetAttribute(Traps.EffectAttribute, nil)
	end
end

local function applyEffect(player: Player, trap: Trap)
	tokenCounter += 1
	local token = tokenCounter
	effectTokens[player] = token
	player:SetAttribute(Traps.EffectAttribute, trap.Id)
	StatsService.SetSpeedModifier(player, SPEED_KEY, 0)
	task.delay(trap.StopTime, function()
		if effectTokens[player] ~= token then
			return
		end
		if trap.SlowTime <= 0 then
			clearEffect(player)
			return
		end
		StatsService.SetSpeedModifier(player, SPEED_KEY, trap.SlowMultiplier)
		task.delay(trap.SlowTime, function()
			if effectTokens[player] == token then
				clearEffect(player)
			end
		end)
	end)
end

------------------------------------------------------------------------------
-- Déclenchement
------------------------------------------------------------------------------

local function rearm(entry: Placed, token: number)
	if entry.Token ~= token or entry.Model.Parent == nil then
		return
	end
	entry.State = Traps.Armed
	entry.Model:SetAttribute(Traps.StateAttribute, Traps.Armed)
end

local function trigger(plot: Model, entry: Placed, thief: Player, owner: Player?)
	local trap = Traps.ById[entry.Id]
	if trap == nil then
		return
	end
	entry.Token += 1
	local token = entry.Token
	entry.State = Traps.Triggered
	entry.Model:SetAttribute(Traps.StateAttribute, Traps.Triggered)
	task.delay(Traps.Recharge, rearm, entry, token)

	local byPlot = immuneUntil[thief] or {}
	immuneUntil[thief] = byPlot
	byPlot[plot] = os.clock() + Traps.Immunity
	applyEffect(thief, trap)

	notify(thief, string.format(Traps.Messages.Thief, trap.DisplayName), "Warning")
	if owner and owner ~= thief then
		notify(owner, string.format(Traps.Messages.Owner, thief.DisplayName, trap.DisplayName), "Alert")
		if trap.Spot > 0 then
			local ok, err = pcall(function()
				Net.Server.CameraSpotted:Fire(owner, thief, Workspace:GetServerTimeNow() + trap.Spot)
			end)
			if not ok then
				warn(`[TrapService] CameraSpotted vers {owner.Name} : {err}`)
			end
		end
	end
	log(`{thief.Name} pris par {trap.Id} ({entry.Model.Name}) dans {plot.Name}`)
end

local function isInside(zone: BasePart, position: Vector3): boolean
	local localPos = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(localPos.X) <= half.X and math.abs(localPos.Y) <= half.Y and math.abs(localPos.Z) <= half.Z
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

function TrapService.Step()
	if next(placed) == nil then
		return
	end
	local now = os.clock()
	local selfTest = ownerCanTrigger()
	local candidates: { { Player: Player, Root: BasePart } } = {}
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root then
			table.insert(candidates, { Player = player, Root = root })
		end
	end
	for plot, list in placed do
		local owner = PlotService.GetOwner(plot)
		for index = 1, #Traps.SlotLayout do
			local entry = list[index]
			local zone = if entry then entry.Zone else nil
			if entry == nil or zone == nil or entry.State ~= Traps.Armed then
				continue
			end
			for _, candidate in candidates do
				local player = candidate.Player
				if player == owner and not selfTest then
					continue
				end
				local byPlot = immuneUntil[player]
				if byPlot and (byPlot[plot] or 0) > now then
					continue
				end
				if isInside(zone, candidate.Root.Position) then
					trigger(plot, entry, player, owner)
					break
				end
			end
		end
	end
end

------------------------------------------------------------------------------
-- Démarrage
------------------------------------------------------------------------------

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function()
		if effectTokens[player] ~= nil then
			clearEffect(player)
		end
	end)
end

function TrapService.Init()
	SkillTreeService.OnChanged(function(player: Player, id: string, _level: number)
		if id == SKILL_ID then
			syncPlayer(player)
		end
	end)
	PlotService.OnPlotAssigned(function(_player: Player, plot: Model)
		TrapService.Sync(plot)
	end)
	PlotService.OnPlotReleased(function(_player: Player, plot: Model)
		clearPlot(plot)
	end)
	DataService.OnProfileLoaded(syncPlayer)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		effectTokens[player] = nil
		immuneUntil[player] = nil
	end)
	if IS_STUDIO then
		Workspace:GetAttributeChangedSignal(TEST_ATTRIBUTE):Connect(function()
			for _, plot in PlotService.GetPlots() do
				TrapService.Sync(plot)
			end
		end)
	end
	local sinceCheck = 0
	local sinceSync = 0
	RunService.Heartbeat:Connect(function(dt: number)
		sinceCheck += dt
		sinceSync += dt
		if sinceSync >= Traps.SyncInterval then
			sinceSync = 0
			for _, plot in PlotService.GetPlots() do
				TrapService.Sync(plot)
			end
		end
		if sinceCheck >= Traps.CheckInterval then
			sinceCheck = 0
			TrapService.Step()
		end
	end)
	log(`pièges {if TrapService.IsEnabled() then "allumés" else "coupés (Features.Traps)"}, {#Traps.List} genres`)
end

return TrapService
