--!strict
-- DisguiseService (a411, vague GC6 ; liaison L-113, mécanique principale vue par Clément le 2026-11-12 ; feuille de
-- route MAJ 4) : la cabine d'essayage. Derrière Features.FittingRoom (false : rien n'est branché). Valeurs et textes :
-- Config/Disguise. Tout est décidé ici ; le client (DisguiseController) ne fait que demander.
--
-- Règle (L-113, points 1 à 5 ; les propositions a à f encore ouvertes sont codées en V0, Config/Disguise) :
--   1. Remote Disguise(zone) : le joueur a la compétence FittingRoom (Config/SkillTree), il est à la cabine de SA
--      boutique (modèle FittingRoom de la parcelle, sinon dans le volume Bounds de sa boutique), la zone est ouverte
--      (zone n avec n − 1 renaissances, attribut Rebirths du Player), la recharge (a) est finie, personne d'autre n'est
--      déguisé dans cette zone (b), il fait jour, il ne porte rien, n'est ni poursuivi ni étourdi. Refus honnête :
--      Notify « Warning ».
--   2. Accepté : il apparaît sur un point du circuit des témoins de la zone (WitnessService.GetZone ; sans circuit,
--      devant la vitrine d'un magasin de la zone), avec l'apparence d'un témoin de la zone (voir « Apparence »), sans
--      nom (Humanoid.DisplayDistanceType = None ; DisguiseController éteint chez chaque client ses billboards et ses
--      effets d'aura et de trail). Attributs du Player : Disguised = zone, DisguiseUntil = fin (heure serveur),
--      DisguiseCanCall. Il redevient joueur au bout de Disguise.Duration s, s'il quitte la zone (magasin PNJ le plus
--      proche d'une autre zone, ou zone safe, pendant LeaveGrace s), s'il meurt, part, est attrapé, ou à la tombée
--      de la nuit. La recharge (a) court alors (attribut DisguiseReadyAt). Il reste où il est.
--   3. Dénoncer : remote Denounce(storeName, phase), maintien de DenounceTime s (d) sur l'invite du magasin, à
--      DenounceRange studs au plus de sa vitrine et tourné vers elle. Pendant le maintien, le « ? » des témoins monte
--      au-dessus de lui (tag et attributs de Shared/WitnessGauge posés sur son personnage : WitnessController
--      l'affiche comme pour un témoin), puis le « ! » CallShowTime s. À la fin : la police (WitnessService.Denounce,
--      NPC_Police, mêmes règles que l'appel d'un témoin) part sur les voleurs du magasin (voir thievesOf). Personne :
--      rien ne se passe et la dénonciation est dépensée quand même (f). CallsPerDisguise dénonciation(s).
--   4. Voler : rien n'est changé aux règles du vol. Le voleur attrapé par la police hors du magasin lâche son objet
--      au sol (CarryService, « Caught »), que le faux passant ramasse comme tout le monde (GrabDropped) ; attrapé
--      dans le magasin, l'objet revole sur son rayon (règle de Cantin du 2026-11-13), et le faux passant peut ouvrir
--      un colis du magasin cassé. Dès qu'il porte quelque chose (CarryService.OnCarryStarted), il redevient joueur ;
--      si aucun vigile ne le poursuit encore après CHASE_DELAY s, un vigile du magasin de l'objet sort pour lui
--      (GuardService.ChaseIntruder).
--   5. Démasquer : un coup de batte sur lui (BatService.IsDisguised, usage « Unmask », hors zone safe) le démasque.
--   (c) Déguisé : aucun outil en main (rangé aussitôt), aucun coup de vitrine compté (WindowService.AddHitGate).
--
-- Apparence (rien de Clément n'est modifié ; seul le personnage du joueur change, et revient) : la description
-- appliquée au Humanoid du joueur est gardée, puis une copie en est appliquée sans ses accessoires ni ses vêtements,
-- avec ceux d'un témoin de la zone : son HumanoidDescription s'il en a un, sinon ses couleurs de peau, puis des copies
-- de ses Shirt, Pants, ShirtGraphic et Accessory (attribut Disguise.ExtraAttribute, retirées à la fin). Le corps et la
-- tête du joueur ne sont pas remplacés (le portage est soudé à la tête, les auras aux membres). Zone sans témoin :
-- couleurs de repli. À la fin : la description gardée est réappliquée. ApplyDescription attend : les changements d'un
-- personnage se suivent dans une seule file.
--
-- API (serveur) :
--   DisguiseService.IsDisguised(player) -> boolean
--   DisguiseService.GetZone(player) -> number?            zone du déguisement en cours
--   DisguiseService.Unmask(player, reason?) -> boolean    fin du déguisement (false s'il n'était pas déguisé)
--   DisguiseService.GetCooldown(player) -> number         s avant le prochain déguisement (0 : prêt)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Disguise = require(Shared.Config.Disguise)
local Features = require(Shared.Config.Features)
local SkillTree = require(Shared.Config.SkillTree)
local Zones = require(Shared.Config.Zones)
local Find = require(Shared.Contract.Find)
local Net = require(Shared.Net.Net)
local WitnessGauge = require(Shared.WitnessGauge)

local AntiCheatService = require(script.Parent.AntiCheatService)
local BatService = require(script.Parent.BatService)
local CarryService = require(script.Parent.CarryService)
local GuardService = require(script.Parent.GuardService)
local NightCycleService = require(script.Parent.NightCycleService)
local PlotService = require(script.Parent.PlotService)
local SkillTreeService = require(script.Parent.SkillTreeService)
local StoreHeistService = require(script.Parent.StoreHeistService)
local WindowService = require(script.Parent.WindowService)
local WitnessService = require(script.Parent.WitnessService)

type Hold = { store: Model, at: number }

type Session = {
	player: Player,
	zone: number,
	character: Model,
	humanoid: Humanoid,
	endsAt: number, -- os.clock
	calls: number, -- dénonciations restantes
	outSince: number?, -- os.clock depuis lequel il est hors de sa zone
	hold: Hold?, -- maintien de dénonciation ouvert
	gaugeToken: number,
	display: Enum.HumanoidDisplayDistanceType,
	denounced: Model?, -- dernier magasin dénoncé
	toolWatch: RBXScriptConnection?,
}

local STORE_TAG = "NPCStore"
local ZONE_ATTRIBUTE = "Zone"
local BOUNDS_NAME = "Bounds"
local WINDOW_NAME = "Window"
local INBOX_NAME = "_INBOX_CLEMENT"
local SPAWN_LIFT = 0.5 -- studs au-dessus du sol à l'apparition (V0, comme PlotService)
local SPAWN_OUT = 12 -- repli sans circuit : studs devant la vitrine (V0)
local CHASE_DELAY = 0.5 -- s laissées au vol normal pour sortir son vigile avant d'en demander un (V0)
local NOTICE_INTERVAL = 3 -- s entre deux « No tools while undercover. »
local ACCESSORY_FIELDS = { "BackAccessory", "FaceAccessory", "FrontAccessory", "HairAccessory", "HatAccessory", "NeckAccessory", "ShouldersAccessory", "WaistAccessory" }
local COLOR_FIELDS = { "HeadColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor", "TorsoColor" }
-- Sans HumanoidDescription ni BodyColors : la pièce R15 du témoin qui donne chaque couleur.
local COLOR_PARTS = { HeadColor = "Head", LeftArmColor = "LeftUpperArm", RightArmColor = "RightUpperArm", LeftLegColor = "LeftUpperLeg", RightLegColor = "RightUpperLeg", TorsoColor = "UpperTorso" }
local EXTRA_CLASSES = { "Shirt", "Pants", "ShirtGraphic", "Accessory" }

local IS_STUDIO = RunService:IsStudio()
local ATTR = Disguise.Attributes
local MESSAGES = Disguise.Messages

local DisguiseService = {}

local sessions: { [Player]: Session } = {}
local readyAt: { [Player]: number } = {} -- os.clock de la fin de la recharge (a)
local noticeAt: { [Player]: number } = {}
local storeHits: { [Model]: { [Player]: number } } = {} -- derniers coups comptés sur la vitrine de chaque magasin PNJ
local savedLooks: { [Model]: HumanoidDescription } = {} -- description d'avant, par personnage déguisé
local lookJobs: { [Model]: { () -> () } } = {} -- file des changements d'apparence d'un personnage
local rng = Random.new()

local function log(message: string)
	if IS_STUDIO then
		print(`[DisguiseService] {message}`)
	end
end

local function notify(player: Player, message: string, kind: string)
	if player.Parent == Players then
		Net.Server.Notify:Fire(player, message, kind)
	end
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function insideBox(cframe: CFrame, size: Vector3, position: Vector3, margin: number): boolean
	local p = cframe:PointToObjectSpace(position)
	return math.abs(p.X) <= size.X / 2 + margin and math.abs(p.Y) <= size.Y / 2 + margin and math.abs(p.Z) <= size.Z / 2 + margin
end

-- Personnage vivant du joueur : sa racine et son Humanoid.
local function bodyOf(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if player.Parent ~= Players or character == nil or not character:IsDescendantOf(Workspace) then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil, nil
	end
	return root :: BasePart, humanoid
end

------------------------------------------------------------------------------
-- Magasins et zones
------------------------------------------------------------------------------

-- Les magasins PNJ de la map (hors _INBOX_CLEMENT) et leur zone.
local function stores(): { [Model]: number }
	local list: { [Model]: number } = {}
	local inbox = Workspace:FindFirstChild(INBOX_NAME)
	for _, store in CollectionService:GetTagged(STORE_TAG) do
		local zone = store:GetAttribute(ZONE_ATTRIBUTE)
		if store:IsA("Model") and type(zone) == "number" and Zones[zone] ~= nil and store:IsDescendantOf(Workspace) and not (inbox and store:IsDescendantOf(inbox)) then
			list[store :: Model] = zone
		end
	end
	return list
end

-- Zone du magasin PNJ le plus proche de `position`, à plat ; nil sans magasin (même règle qu'ItemRainService).
local function zoneAt(position: Vector3): number?
	local best: number? = nil
	local bestDistance = math.huge
	for store, zone in stores() do
		local distance = flat(store:GetPivot().Position - position).Magnitude
		if distance < bestDistance then
			best, bestDistance = zone, distance
		end
	end
	return best
end

-- Le centre de la vitrine du magasin (son pivot), sinon le pivot du magasin (comme WitnessService).
local function windowPosition(store: Model): Vector3
	local window = Find.path(store, WINDOW_NAME)
	if window and window:IsA("PVInstance") then
		return (window :: PVInstance):GetPivot().Position
	end
	return store:GetPivot().Position
end

local function boundsOf(model: Instance): BasePart?
	local bounds = Find.path(model, BOUNDS_NAME)
	return if bounds and bounds:IsA("BasePart") then bounds :: BasePart else nil
end

local function storeIdOf(store: Model): string
	local ok, id = pcall(StoreHeistService.GetStoreId, store)
	return if ok and type(id) == "string" then id else store.Name
end

-- Point du sol où le faux passant apparaît dans `zone` : un point du circuit des témoins hors zone safe et dans la zone, sinon
-- SPAWN_OUT studs devant la vitrine d'un magasin de la zone, au niveau du sol de son volume Bounds ; nil sinon.
local function spotFor(zone: number): Vector3?
	local _, points = WitnessService.GetZone(zone)
	local free: { Vector3 } = {}
	for _, point in points do
		if not GuardService.IsInSafeZone(point) and zoneAt(point) == zone then
			table.insert(free, point)
		end
	end
	if #free > 0 then
		return free[rng:NextInteger(1, #free)]
	end
	for store, storeZone in stores() do
		local bounds = boundsOf(store)
		if storeZone == zone and bounds then
			local window = windowPosition(store)
			local out = flat(window - bounds.Position)
			if out.Magnitude > 1e-3 then
				local spot = window + out.Unit * SPAWN_OUT
				return Vector3.new(spot.X, bounds.Position.Y - bounds.Size.Y / 2, spot.Z)
			end
		end
	end
	return nil
end

-- Le joueur est-il à la cabine de sa boutique (Config/Disguise.Cabin) ?
local function atCabin(player: Player, position: Vector3): boolean
	local plot = PlotService.GetPlot(player)
	if plot == nil then
		return false
	end
	local cabin = plot:FindFirstChild(Disguise.Cabin.ModelName, true)
	if cabin and cabin:IsA("PVInstance") then
		return ((cabin :: PVInstance):GetPivot().Position - position).Magnitude <= Disguise.Cabin.Range
	end
	local bounds = boundsOf(plot)
	if bounds then
		return insideBox(bounds.CFrame, bounds.Size, position, Disguise.Cabin.BoundsMargin)
	end
	return (plot:GetPivot().Position - position).Magnitude <= Disguise.Cabin.FallbackRange
end

------------------------------------------------------------------------------
-- Apparence
------------------------------------------------------------------------------

-- Les changements d'apparence d'un personnage se suivent (ApplyDescription attend) : file, un seul fil par personnage.
local function queueLook(character: Model, job: () -> ())
	local pending = lookJobs[character]
	if pending then
		table.insert(pending, job)
		return
	end
	local list = { job }
	lookJobs[character] = list
	task.spawn(function()
		while #list > 0 do
			local ok, err = pcall(table.remove(list, 1) :: any)
			if not ok then
				warn(`[DisguiseService] apparence de {character.Name} : {err}`)
			end
		end
		lookJobs[character] = nil
	end)
end

local function removeExtras(character: Model)
	for _, child in character:GetChildren() do
		if child:GetAttribute(Disguise.ExtraAttribute) == true then
			child:Destroy()
		end
	end
end

-- Couleur de peau du témoin pour le champ `field` : BodyColors, sinon la pièce R15, sinon le repli.
local function witnessColor(witness: Model?, field: string): Color3
	if witness then
		local colors = witness:FindFirstChildOfClass("BodyColors")
		if colors then
			return (colors :: any)[field .. "3"]
		end
		local part = witness:FindFirstChild(COLOR_PARTS[field])
		if part and part:IsA("BasePart") then
			return (part :: BasePart).Color
		end
	end
	if field == "TorsoColor" then
		return Disguise.FallbackTorso
	elseif field == "LeftLegColor" or field == "RightLegColor" then
		return Disguise.FallbackLegs
	end
	return Disguise.FallbackSkin
end

-- Habille le personnage en témoin (dans la file du personnage ; peut attendre).
local function dress(character: Model, humanoid: Humanoid, witness: Model?)
	if humanoid.Parent == nil then
		return
	end
	local saved = humanoid:GetAppliedDescription()
	savedLooks[character] = saved
	local look = saved:Clone()
	local witnessHumanoid = if witness then witness:FindFirstChildOfClass("Humanoid") else nil
	local source = if witnessHumanoid then witnessHumanoid:FindFirstChildOfClass("HumanoidDescription") else nil
	for _, field in ACCESSORY_FIELDS do
		(look :: any)[field] = if source then (source :: any)[field] else ""
	end
	look:SetAccessories(if source then source:GetAccessories(true) else {}, true)
	look.Shirt = if source then source.Shirt else 0
	look.Pants = if source then source.Pants else 0
	look.GraphicTShirt = if source then source.GraphicTShirt else 0
	if source then
		look.Face = source.Face
	end
	for _, field in COLOR_FIELDS do
		(look :: any)[field] = if source then (source :: any)[field] else witnessColor(witness, field)
	end
	humanoid:ApplyDescription(look)
	if source == nil and witness and humanoid:IsDescendantOf(Workspace) then
		for _, child in witness:GetChildren() do
			if table.find(EXTRA_CLASSES, child.ClassName) then
				local copy = child:Clone()
				copy:SetAttribute(Disguise.ExtraAttribute, true)
				if copy:IsA("Accessory") then
					humanoid:AddAccessory(copy)
				else
					copy.Parent = character
				end
			end
		end
	end
end

-- Rend son apparence au personnage (dans la file du personnage ; peut attendre).
local function undress(character: Model, humanoid: Humanoid)
	local saved: HumanoidDescription? = savedLooks[character]
	savedLooks[character] = nil
	if saved == nil or humanoid.Parent == nil then
		return
	end
	removeExtras(character)
	humanoid:ApplyDescription(saved)
end

------------------------------------------------------------------------------
-- Jauge « ? » du faux passant (Shared/WitnessGauge, affichée par WitnessController)
------------------------------------------------------------------------------

local function setGauge(session: Session, state: WitnessGauge.State?, rate: number)
	session.gaugeToken += 1
	local character = session.character
	if character.Parent == nil then
		return
	end
	if state == nil then
		character:RemoveTag(WitnessGauge.Tag)
		for _, name in { WitnessGauge.StateAttribute, WitnessGauge.FillAttribute, WitnessGauge.RateAttribute, WitnessGauge.AtAttribute } do
			character:SetAttribute(name, nil)
		end
		return
	end
	character:SetAttribute(WitnessGauge.StateAttribute, state)
	character:SetAttribute(WitnessGauge.FillAttribute, if state == "Call" then 1 else 0)
	character:SetAttribute(WitnessGauge.RateAttribute, rate)
	character:SetAttribute(WitnessGauge.AtAttribute, Workspace:GetServerTimeNow())
	character:AddTag(WitnessGauge.Tag)
end

------------------------------------------------------------------------------
-- Début et fin du déguisement
------------------------------------------------------------------------------

local function zoneHolder(zone: number): Player?
	for player, session in sessions do
		if session.zone == zone then
			return player
		end
	end
	return nil
end

local function stowTools(session: Session)
	if session.humanoid.Parent ~= nil and session.character:FindFirstChildOfClass("Tool") then
		session.humanoid:UnequipTools()
		local now = os.clock()
		if now - (noticeAt[session.player] or -math.huge) >= NOTICE_INTERVAL then
			noticeAt[session.player] = now
			notify(session.player, MESSAGES.NoTools, "Warning")
		end
	end
end

local END_MESSAGES: { [string]: string } = {
	Timeout = MESSAGES.Ended,
	LeftZone = MESSAGES.LeftZone,
	Bat = MESSAGES.Unmasked,
	Caught = MESSAGES.Unmasked,
	Took = MESSAGES.Took,
	Night = MESSAGES.Night,
}

-- Fin du déguisement : il redevient joueur là où il est, la recharge (a) court.
local function finish(session: Session, reason: string)
	local player = session.player
	if sessions[player] ~= session then
		return
	end
	sessions[player] = nil
	local now = os.clock()
	readyAt[player] = now + Disguise.Cooldown
	local watch = session.toolWatch
	if watch then
		watch:Disconnect()
	end
	session.hold = nil
	setGauge(session, nil, 0)
	if session.humanoid.Parent ~= nil then
		session.humanoid.DisplayDistanceType = session.display
	end
	queueLook(session.character, function()
		undress(session.character, session.humanoid)
	end)
	if player.Parent == Players then
		player:SetAttribute(ATTR.Zone, nil)
		player:SetAttribute(ATTR.Until, nil)
		player:SetAttribute(ATTR.CanCall, nil)
		player:SetAttribute(ATTR.ReadyAt, Workspace:GetServerTimeNow() + Disguise.Cooldown)
	end
	local message = END_MESSAGES[reason]
	if message then
		notify(player, message, if reason == "Timeout" then "Info" else "Alert")
	end
	log(`{player.Name} redevient joueur ({reason}), zone {session.zone}`)
end

local function start(player: Player, zone: number, root: BasePart, humanoid: Humanoid, spot: Vector3)
	local character = root.Parent :: Model
	local now = os.clock()
	local session: Session = {
		player = player,
		zone = zone,
		character = character,
		humanoid = humanoid,
		endsAt = now + Disguise.Duration,
		calls = Disguise.CallsPerDisguise,
		outSince = nil,
		hold = nil,
		gaugeToken = 0,
		display = humanoid.DisplayDistanceType,
		denounced = nil,
		toolWatch = nil,
	}
	sessions[player] = session
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	if Disguise.NoTools then
		humanoid:UnequipTools()
		session.toolWatch = character.ChildAdded:Connect(function(child: Instance)
			if child:IsA("Tool") then
				task.defer(stowTools, session)
			end
		end)
	end
	local witnesses = WitnessService.GetZone(zone)
	local witness: Model? = if #witnesses > 0 then witnesses[rng:NextInteger(1, #witnesses)] else nil
	queueLook(character, function()
		dress(character, humanoid, witness)
	end)
	-- Déplacement du code (DEV-060) : pieds sur le point choisi, cap gardé.
	local position = spot + Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2 + SPAWN_LIFT, 0)
	AntiCheatService.Allow(player, 0, "DisguiseService")
	character:PivotTo(CFrame.new(position) * root.CFrame.Rotation)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	local serverNow = Workspace:GetServerTimeNow()
	player:SetAttribute(ATTR.Zone, zone)
	player:SetAttribute(ATTR.Until, serverNow + Disguise.Duration)
	player:SetAttribute(ATTR.CanCall, session.calls > 0)
	notify(player, string.format(MESSAGES.Started, Disguise.Duration), "Success")
	log(`{player.Name} déguisé en passant de la zone {zone} pour {Disguise.Duration} s{if witness then ` ({witness.Name})` else " (sans témoin : couleurs de repli)"}`)
end

local function onDisguise(player: Player, zone: number)
	if sessions[player] ~= nil or Zones[zone] == nil then
		return
	end
	if SkillTreeService.GetLevel(player, Disguise.SkillId) < 1 then
		notify(player, MESSAGES.NeedSkill, "Warning")
		return
	end
	local rebirths = SkillTree.RebirthsOf(player:GetAttribute(SkillTree.RebirthsAttribute)) or 0
	local needed = zone - Disguise.ZoneRebirthOffset
	if rebirths < needed then
		notify(player, string.format(MESSAGES.ZoneLocked, zone, needed), "Warning")
		return
	end
	local now = os.clock()
	local left = (readyAt[player] or -math.huge) - now
	if left > 0 then
		local seconds = math.ceil(left)
		notify(player, string.format(MESSAGES.Cooldown, seconds // 60, seconds % 60), "Warning")
		return
	end
	if NightCycleService.IsNight() then
		notify(player, MESSAGES.Night, "Warning")
		return
	end
	local root, humanoid = bodyOf(player)
	if
		root == nil
		or humanoid == nil
		or CarryService.IsCarrying(player)
		or GuardService.IsChased(player)
		or GuardService.IsStunned(player)
		or BatService.IsStunned(player)
		or player:GetAttribute("RevealProtected") == true
	then
		notify(player, MESSAGES.Busy, "Warning")
		return
	end
	if not atCabin(player, root.Position) then
		notify(player, MESSAGES.NotAtCabin, "Warning")
		return
	end
	if Disguise.OnePerZone and zoneHolder(zone) ~= nil then
		notify(player, MESSAGES.ZoneTaken, "Warning")
		return
	end
	local spot = spotFor(zone)
	if spot == nil then
		notify(player, MESSAGES.NoSpot, "Warning")
		return
	end
	start(player, zone, root, humanoid, spot)
end

------------------------------------------------------------------------------
-- Dénonciation
------------------------------------------------------------------------------

local function storeNamed(name: string, zone: number): Model?
	for store, storeZone in stores() do
		if storeZone == zone and store.Name == name then
			return store
		end
	end
	return nil
end

-- Refus de portée : trop loin de la vitrine, ou pas tourné vers elle ; nil si la dénonciation est possible d'ici.
local function reachRefusal(root: BasePart, store: Model): string?
	local toWindow = flat(windowPosition(store) - root.Position)
	if toWindow.Magnitude > Disguise.DenounceRange then
		return MESSAGES.TooFar
	end
	local look = flat(root.CFrame.LookVector)
	if toWindow.Magnitude > 1e-3 and look.Magnitude > 1e-3 and toWindow.Unit:Dot(look.Unit) < Disguise.DenounceFacing then
		return MESSAGES.NotFacing
	end
	return nil
end

-- Les voleurs du magasin (Config/Disguise, « un voleur dans ce magasin »), porteurs d'un objet du magasin d'abord.
local function thievesOf(store: Model, snitch: Player): { Player }
	local carriers: { Player } = {}
	local others: { Player } = {}
	local bounds = boundsOf(store)
	local window = windowPosition(store)
	local storeId = storeIdOf(store)
	local hits = storeHits[store]
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local root = bodyOf(player)
		if player == snitch or sessions[player] ~= nil or root == nil or GuardService.IsInSafeZone(root.Position) then
			continue
		end
		local payload = CarryService.GetPayload(player)
		if payload and payload.Kind == "NPCItem" and payload.StoreId == storeId and flat(root.Position - window).Magnitude <= Disguise.ThiefCarryRange then
			table.insert(carriers, player)
		elseif
			(bounds and insideBox(bounds.CFrame, bounds.Size, root.Position, Disguise.ThiefMargin))
			or (hits and now - (hits[player] or -math.huge) <= Disguise.ThiefMemory)
		then
			table.insert(others, player)
		end
	end
	table.move(others, 1, #others, #carriers + 1, carriers)
	return carriers
end

local function denounce(session: Session, store: Model)
	local player = session.player
	session.calls -= 1
	session.denounced = store
	player:SetAttribute(ATTR.CanCall, session.calls > 0)
	setGauge(session, "Call", 0)
	local token = session.gaugeToken
	task.delay(Disguise.CallShowTime, function()
		if sessions[player] == session and session.gaugeToken == token then
			setGauge(session, nil, 0)
		end
	end)
	local thieves = thievesOf(store, player)
	if #thieves == 0 then
		notify(player, MESSAGES.NobodyThere, "Warning")
		log(`{player.Name} dénonce {store.Name} : personne ne le braque`)
		return
	end
	local ok, launched = pcall(WitnessService.Denounce, store, thieves)
	local count = 0
	if ok and type(launched) == "table" then
		for _, entry in launched :: { WitnessService.PoliceChase } do
			count += 1
			notify(entry.Player, MESSAGES.Denounced, "Alert")
		end
	elseif not ok then
		warn(`[DisguiseService] WitnessService.Denounce({store.Name}) : {launched}`)
	end
	notify(player, if count > 0 then string.format(MESSAGES.Called, count) else MESSAGES.AlreadyChased, if count > 0 then "Success" else "Warning")
	log(`{player.Name} dénonce {store.Name} : {#thieves} voleur(s), {count} policier(s) lancé(s)`)
end

local function onDenounce(player: Player, storeName: string, phase: string)
	local session = sessions[player]
	if session == nil or (phase ~= "Begin" and phase ~= "End" and phase ~= "Cancel") then
		return
	end
	if phase == "Cancel" then
		if session.hold then
			session.hold = nil
			setGauge(session, nil, 0)
		end
		return
	end
	local root = bodyOf(player)
	local store = storeNamed(storeName, session.zone)
	if root == nil or store == nil then
		return
	end
	local now = os.clock()
	if phase == "Begin" then
		if session.calls <= 0 then
			notify(player, MESSAGES.NoCall, "Warning")
			return
		end
		local refusal = reachRefusal(root, store)
		if refusal then
			notify(player, refusal, "Warning")
			return
		end
		session.hold = { store = store, at = now } -- un « Begin » rouvre toujours le maintien à zéro
		setGauge(session, "Watch", 1 / Disguise.DenounceTime)
		return
	end
	local hold = session.hold
	session.hold = nil
	if hold == nil then
		return -- un « End » ne conclut qu'un maintien ouvert
	end
	local held = now - hold.at
	local refusal = reachRefusal(root, store)
	if hold.store ~= store or session.calls <= 0 then
		setGauge(session, nil, 0)
		return
	end
	if held + Disguise.HoldTolerance < Disguise.DenounceTime or held > Disguise.DenounceTime + Disguise.HoldExpiry or refusal then
		setGauge(session, nil, 0)
		if refusal then
			notify(player, refusal, "Warning")
		end
		return
	end
	denounce(session, store)
end

------------------------------------------------------------------------------
-- Contrôle régulier et crochets
------------------------------------------------------------------------------

local function step()
	local now = os.clock()
	local night = NightCycleService.IsNight()
	for player, session in table.clone(sessions) do
		local root, humanoid = bodyOf(player)
		if root == nil or humanoid ~= session.humanoid then
			finish(session, "Gone")
		elseif night then
			finish(session, "Night")
		elseif now >= session.endsAt then
			finish(session, "Timeout")
		else
			local position = root.Position
			if GuardService.IsInSafeZone(position) or zoneAt(position) ~= session.zone then
				local since = session.outSince or now
				session.outSince = since
				if now - since >= Disguise.LeaveGrace then
					finish(session, "LeftZone")
					continue
				end
			else
				session.outSince = nil
			end
			local hold = session.hold
			if hold and now - hold.at > Disguise.DenounceTime + Disguise.HoldExpiry then
				session.hold = nil
				setGauge(session, nil, 0)
			end
			if Disguise.NoTools then
				stowTools(session)
			end
		end
	end
end

-- Il porte quelque chose : il redevient joueur ; sans vigile à ses trousses, un vigile du magasin de l'objet sort.
local function onCarryStarted(player: Player, payload: any)
	local session = sessions[player]
	if session == nil then
		return
	end
	finish(session, "Took")
	if type(payload) ~= "table" or payload.Kind ~= "NPCItem" then
		return
	end
	task.delay(CHASE_DELAY, function()
		if player.Parent ~= Players or not CarryService.IsCarrying(player) or GuardService.IsChased(player) then
			return
		end
		local ok, model = pcall(StoreHeistService.GetStoreModel, payload.StoreId)
		local store: Model? = if ok and typeof(model) == "Instance" then model :: Model else session.denounced
		if store then
			local sent = GuardService.ChaseIntruder(player, store)
			log(`{player.Name} a pris un objet déguisé : vigile de {store.Name} {if sent then "lancé" else "refusé"}`)
		end
	end)
end

function DisguiseService.IsDisguised(player: Player): boolean
	return sessions[player] ~= nil
end

function DisguiseService.GetZone(player: Player): number?
	local session = sessions[player]
	return if session then session.zone else nil
end

function DisguiseService.Unmask(player: Player, reason: string?): boolean
	local session = sessions[player]
	if session == nil then
		return false
	end
	finish(session, reason or "Unmask")
	return true
end

function DisguiseService.GetCooldown(player: Player): number
	return math.max((readyAt[player] or -math.huge) - os.clock(), 0)
end

function DisguiseService.Init()
	if not Features.FittingRoom then
		return
	end
	Net.Server.Disguise:Connect(onDisguise)
	Net.Server.Denounce:Connect(onDenounce)
	BatService.IsDisguised = function(target: Player): boolean
		return sessions[target] ~= nil
	end
	BatService.OnHit(function(hitter: Player, target: Player, _usage: BatService.Usage, _payload: any)
		local session = sessions[target]
		if session then
			finish(session, "Bat")
			notify(hitter, string.format(MESSAGES.UnmaskedBy, target.DisplayName), "Success")
		end
	end)
	WindowService.AddHitGate(function(player: Player, _windowId: string, _kind: WindowService.WindowKind, _model: Model): boolean
		return not (Disguise.NoTools and sessions[player] ~= nil)
	end)
	WindowService.OnHit(function(player: Player, _windowId: string, kind: WindowService.WindowKind, model: Model, _damage: number)
		if kind == "NPC" then
			local hits = storeHits[model]
			if hits == nil then
				hits = {}
				storeHits[model] = hits
			end
			hits[player] = os.clock()
		end
	end)
	CarryService.OnCarryStarted(onCarryStarted)
	GuardService.OnCatch(function(player: Player, _zone: number, _night: boolean, _carrying: boolean)
		local session = sessions[player]
		if session then
			finish(session, "Caught")
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		local session = sessions[player]
		if session then
			finish(session, "Gone")
		end
		readyAt[player] = nil
		noticeAt[player] = nil
		for _, hits in storeHits do
			hits[player] = nil
		end
	end)
end

function DisguiseService.Start()
	if not Features.FittingRoom then
		return
	end
	task.spawn(function()
		while true do
			task.wait(Disguise.Step)
			local ok, err = pcall(step :: any)
			if not ok then
				warn(`[DisguiseService] {err}`)
			end
		end
	end)
	log(`cabine d'essayage : {Disguise.Duration} s, recharge {Disguise.Cooldown} s, une dénonciation de {Disguise.DenounceTime} s`)
end

return DisguiseService
