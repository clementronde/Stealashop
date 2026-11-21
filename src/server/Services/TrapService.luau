--!strict
-- TrapService (vague 72, a243 ; liaison L-218, L-216 point 11) : pièges de la boutique d'un joueur, côté serveur.
-- Contrat et valeurs (toutes V0, à valider par Clément) : Config/Traps ; interrupteur Features.Traps (false : aucun
-- piège posé, la tuile Traps de l'arbre reste « Soon »).
--
-- Achat : la tuile Traps de l'arbre (Config/SkillTree, SkillTreeService : prix, renaissance, OpensWhen). Son
-- Effects[niveau] = nombre de pièges posés. Rien d'autre ne s'achète ici, aucun remote : le client ne demande rien.
-- Pose : pour la boutique de chaque joueur, un piège par emplacement TrapSlot_01 à _0n (n = ce nombre, et
-- seulement les emplacements présents dans la boutique), du genre Traps.SlotLayout[i] (a286 : Traps.SlotLayoutNew si Features.NewTraps ; a296 : ou
-- Features.NewTrapsDev dans le jeu DEV, Config/ProductIds.IsDev ; donc allumée en DEV, coupée en PROD) : copie de
-- ReplicatedStorage/Assets/Traps/TRAP_<Id> (sans script, pièces ancrées, TriggerZone sans collision ni requête),
-- sinon un modèle de repli construit ici ; pivot posé sur l'emplacement (WorldCFrame d'un Attachment, bas d'une
-- pièce). Copie nommée Trap_0i, dans le dossier Traps.Folder de la boutique, tag Traps.Tag, attributs TrapId et
-- TrapState (« Armed »). Remise à jour à l'achat (SkillTreeService.OnChanged), à l'attribution de la boutique, au
-- chargement du profil et toutes les Traps.SyncInterval s (étages de la boutique reconstruits, emplacement
-- déplacé) ; tout est retiré quand la boutique est libérée. Pas de piège dans la boutique du bot.
-- Déclenchement, Traps.CheckInterval fois par seconde : un piège armé se déclenche quand le HumanoidRootPart d'un
-- joueur vivant est dans son TriggerZone (boîte orientée) ou l'a traversé depuis le contrôle d'avant (vague 81 :
-- trajet testé, au plus Traps.SweepMax studs), sauf le propriétaire (Traps.SpareFriends : aucune règle
-- d'amis au vol, les amis sont pris), et sauf un joueur pris par un piège de cette boutique il y a moins de
-- Traps.Immunity s. Le piège passe en « Triggered » (le client montre Triggered, son 3D) pendant Traps.Recharge s,
-- puis se réarme. Effet sur le joueur (StatsService, clé « Trap ») : vitesse 0 pendant StopTime s, puis
-- × SlowMultiplier pendant SlowTime s ; attribut TrapEffect = Id du piège tant que l'effet dure (animation chez
-- son client) ; un nouveau piège remplace l'effet en cours. Notify au voleur (« Warning ») et au propriétaire
-- (« Alert ») ; Spot > 0 (portique) : CameraSpotted au propriétaire, le voleur est surligné Spot s
-- (CameraAlertController). Effet retiré à la réapparition et au départ.
-- a286 : Eject (trappe) : le voleur sort devant la porte (PlotService.PutOutside) avant l'arrêt ; l'objet qu'il volait à
-- cette boutique revient sur son présentoir (CarryService.FailNoDrop, raison « Trap »). Sans repère de sortie : il reste
-- sur place, sonné, une ligne dans la sortie.
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
--   workspace:SetAttribute("NewTrapsTest", true)  a286 : disposition Traps.SlotLayoutNew (a293 : colle, banane, portique, trappe ; sert à tester sans Features.NewTraps ni le jeu DEV)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Features = require(Shared.Config.Features)
local Traps = require(Shared.Config.Traps)
local Net = require(Shared.Net.Net)
-- a296 : Config/ProductIds chargé s'il est là, comme dans Config/Monetization (a294) ; sans lui, IsDev faux (PROD).
local ProductIds: { IsDev: boolean? } = (function(): any
	local module = Shared.Config:FindFirstChild("ProductIds")
	if module ~= nil then
		local ok, result = pcall(require, module :: any)
		if ok and type(result) == "table" then
			return result
		end
	end
	return {}
end)()

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
local NEW_TEST_ATTRIBUTE = "NewTrapsTest" -- a286 : disposition Traps.SlotLayoutNew en Studio sans toucher Features.NewTraps
local IS_STUDIO = RunService:IsStudio()

local TrapService = {}

local placed: { [Model]: { [number]: Placed } } = {}
local immuneUntil: { [Player]: { [Model]: number } } = {}
local effectTokens: { [Player]: number } = {}
local tokenCounter = 0
-- Vague 81 (a268) : position du HumanoidRootPart au contrôle d'avant (trajet testé contre les TriggerZone).
local lastPositions: { [Player]: { Root: BasePart, Position: Vector3 } } = {}

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

-- a286 : genre de piège de chaque emplacement (Traps.SlotLayoutNew avec les deux pièges de plus, ou la disposition
-- d'avant). Les deux ont #Traps.SlotLayout emplacements. a296 : la nouvelle partout si Features.NewTraps, dans le jeu
-- DEV si Features.NewTrapsDev (Config/ProductIds.IsDev), en Studio avec l'attribut NewTrapsTest.
local function slotLayout(): { Traps.TrapId }
	local new = Features.NewTraps == true
		or (Features.NewTrapsDev == true and ProductIds.IsDev == true)
		or (IS_STUDIO and Workspace:GetAttribute(NEW_TEST_ATTRIBUTE) == true)
	return if new then Traps.SlotLayoutNew else Traps.SlotLayout
end

-- a286 : CarryService chargé à la demande (trappe : l'objet volé à cette boutique revient). Absent : rien.
local function carryApi(): any
	local module = script.Parent:FindFirstChild("CarryService")
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, api = pcall(require, module)
	return if ok then api else nil
end

-- a286 (trappe, Traps.Eject) : `thief` sort devant la porte de `plot` (PlotService.PutOutside) ; s'il portait un
-- objet volé à cette boutique, l'objet revient sur son présentoir d'abord (FailNoDrop « Trap », PvPService le rend).
local function eject(plot: Model, thief: Player, owner: Player?)
	local carry = carryApi()
	if carry then
		local ok, payload = pcall(carry.GetPayload, thief)
		local victim = if ok and type(payload) == "table" and payload.Kind == "PlayerItem" then payload.VictimUserId else nil
		if victim ~= nil and (owner == nil or victim == owner.UserId) then
			pcall(carry.FailNoDrop, thief, "Trap")
		end
	end
	local ok, out = pcall(PlotService.PutOutside, thief, plot)
	if not ok or out ~= true then
		log(`{thief.Name} : trappe de {plot.Name} sans sortie ({if ok then "personnage absent ou boutique sans repère" else out})`)
	end
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
		local trap = if index <= count then Traps.ById[slotLayout()[index]] else nil
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
	if trap.Eject then
		eject(plot, thief, owner) -- a286 : trappe, sortie devant la porte avant l'arrêt
	end
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

-- Vague 81 (a268) : le segment from → to touche-t-il la boîte orientée `zone` ? (méthode des tranches, dans le
-- repère de la boîte). Sans `from` : la position `to` seule.
local function crosses(zone: BasePart, from: Vector3?, to: Vector3): boolean
	if from == nil then
		return isInside(zone, to)
	end
	local a = zone.CFrame:PointToObjectSpace(from)
	local b = zone.CFrame:PointToObjectSpace(to)
	local half = zone.Size / 2
	local tMin, tMax = 0, 1
	for _, slab in { { a.X, b.X - a.X, half.X }, { a.Y, b.Y - a.Y, half.Y }, { a.Z, b.Z - a.Z, half.Z } } do
		local start, delta, h = slab[1], slab[2], slab[3]
		if math.abs(delta) < 1e-9 then
			if math.abs(start) > h then
				return false
			end
		else
			local t1 = (-h - start) / delta
			local t2 = (h - start) / delta
			if t1 > t2 then
				t1, t2 = t2, t1
			end
			tMin = math.max(tMin, t1)
			tMax = math.min(tMax, t2)
			if tMin > tMax then
				return false
			end
		end
	end
	return true
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
		table.clear(lastPositions)
		return
	end
	local now = os.clock()
	local selfTest = ownerCanTrigger()
	local candidates: { { Player: Player, Root: BasePart, From: Vector3?, To: Vector3 } } = {}
	local seen: { [Player]: boolean } = {}
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root then
			-- Trajet depuis le contrôle d'avant, du même HumanoidRootPart et pas plus long que SweepMax.
			local to = root.Position
			local last = lastPositions[player]
			local from = if last and last.Root == root and (to - last.Position).Magnitude <= Traps.SweepMax
				then last.Position
				else nil
			table.insert(candidates, { Player = player, Root = root, From = from, To = to })
			lastPositions[player] = { Root = root, Position = to }
			seen[player] = true
		end
	end
	for player in lastPositions do
		if not seen[player] then
			lastPositions[player] = nil
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
				if crosses(zone, candidate.From, candidate.To) then
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
		local function syncAll()
			for _, plot in PlotService.GetPlots() do
				TrapService.Sync(plot)
			end
		end
		Workspace:GetAttributeChangedSignal(TEST_ATTRIBUTE):Connect(syncAll)
		Workspace:GetAttributeChangedSignal(NEW_TEST_ATTRIBUTE):Connect(syncAll) -- a286
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
	log(`pièges {if TrapService.IsEnabled() then "allumés" else "coupés (Features.Traps)"}, {#Traps.List} genres, disposition {table.concat(slotLayout(), ", ")}`)
end

return TrapService
