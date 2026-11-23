--!strict
-- VfxController (client, vague 26, liaison L-097 points 6 et 7) : branche les effets livrés par Clément
-- (ReplicatedStorage/Assets/FX et Assets/UI ; valeurs : Config/Vfx). Tout est visuel et local : rien
-- n'est envoyé au serveur, aucun modèle ni écran de Clément n'est modifié (on pose des copies).
--
--   1. FX_ChaseHighlight : une copie dans le vigile qui poursuit le joueur local (ChaseController.GetGuard),
--      vue de lui seul, retirée à la fin de la poursuite (et reposée si le vigile revient par le streaming).
--      Roblox n'affiche que 31 Highlight : tant qu'elle est là, ShelfBoxController garde Vfx.Chase.Reserve
--      contour(s) de colis en moins (ShelfBoxController.Reserve), pour qu'elle passe toujours.
--   2. FX_Collect_Bill et FX_Collect_Coin : à chaque ramassage du joueur local sur une de ses plaques
--      (DisplayController.OnCollect, remote CashCollect), de MinCount à MaxCount billets et pièces selon
--      le montant (case-ramassage.md) jaillissent de la plaque (PopTime, vers le haut, au hasard), puis
--      filent l'un après l'autre (Stagger) vers le compteur UI_HUD.Cash (point à TargetDepth studs devant
--      la caméra), en FlyTime (Quad In), en rapetissant ; détruits à l'arrivée. Sans compteur à l'écran :
--      ils montent de RiseHeight et s'effacent.
--   3. FX_Escape : à l'arrivée en zone safe avec un colis (VfxController.Escape, appelé par
--      UiFeelController.Escape, remote BoxSecured) : une copie aux pieds du joueur, Emit(EmitCount) de
--      chaque émetteur, chaque lumière allumée puis éteinte en FadeTime ; détruite après Duration.
--   4. FX_TruckDust : à l'arrivée du camion de l'événement (tag EventTruck, attribut SpawnedAt de
--      TruckEventService récent ; a97 : à l'impact au sol, attribut ArriveEndsAt, s'il arrive en
--      roulant) et à son départ sans explosion (attribut LeftAt posé avant sa destruction) : une copie posée au pivot du camion, Emit de la poussière aux 4 roues ; détruite
--      après Duration.
--   5. BB_Rarest : sur l'Attachment RarestPedestal/TopPlate/RarestLabelPoint de chaque boutique (tag
--      PlayerPlot), une copie qui montre l'objet exposé le plus rare (attributs Rarity, ItemId, Income des
--      DisplayItem posés par DisplayService ; même rareté : le plus gros revenu) : Rarity (DisplayNameUpper,
--      couleur de la rareté), ItemName (Items.DisplayName). Odds caché : la chance du tirage n'est pas
--      gardée avec l'objet. Title est le texte de Clément. Rays tourne, CrownIcon se balance (V0). Chaque
--      client la pose : tous les joueurs la voient. Aucun objet exposé : pas de billboard. L-118 point 6 :
--      l'objet lui-même aussi, une copie (RarestItem) posée sur l'Attachment RarestSlot du socle.
--      Vague 50 (a161, L-165 point 5) : si la parcelle a le grand socle RarestDisplay (Vfx.RarestDisplay), il
--      remplace RarestPedestal : BB_RarestDisplay (sinon BB_Rarest) sur LabelPoint, avec Rarity, ItemName,
--      Mutation (« BIG · GOLD », caché sans mutation) et Odds (« 1 in 5,300,000,000 », chance de référence de
--      Shared/ItemOdds) ; l'objet sur ItemPoint, à sa taille réelle, tourné comme ItemPoint. Sans RarestDisplay :
--      l'ancien socle, comme avant (Odds caché).
--      Vague 60 (a196, Cantin, T-096) : « BEST ITEM » : le socle montre l'objet exposé au plus gros revenu (attribut
--      Income de DisplayService ; Vfx.Rarest.Pick), titre Vfx.Rarest.Title dans Header / Title, revenu/s dans Income
--      (sinon dans Odds, à la place de la chance). Pick = "Rarity" : le plus rare, comme avant.
-- VISUAL EFFECTS sur OFF (Settings.VfxReduced) : billets et pièces coupés, particules et lumière de la
-- victoire et du camion × Vfx.OffEmitFactor (0 : rien). Le contour du vigile et BB_Rarest restent.
-- Un modèle de Clément absent : rien (une ligne en Studio, une fois).
--
-- API (client) :
--   VfxController.Escape()                          victoire en zone safe aux pieds du joueur local
--   VfxController.Collect(amount, position, onLanded?) -> number   billets et pièces depuis `position` (leur nombre)
--   VfxController.OnCollectLanded(fn(amount)) -> déconnexion   a317 (L-299) : une fois par Collect, à l'arrivée du
--       premier billet au compteur (ou en finissant de monter si le compteur a quitté l'écran), ou à la fin de l'image
--       s'il n'en vole aucun (VISUAL EFFECTS sur OFF, modèles absents, compteur hors écran) ; `onLanded` aussi.
--   VfxController.TruckDust(model)                  poussière au pivot du camion
--   VfxController.CollectCount(amount) -> number    billets et pièces pour ce montant (0 si effets coupés)
--   VfxController.OnCollectStart(fn(total, wave)) -> déconnexion
--   VfxController.OnCollectArrive(fn(rank, total, wave)) -> déconnexion
--       a401 (vague GC4, vidéo de Cantin) : départ des `total` billets d'un ramassage (`wave` : numéro de la vague),
--       puis chaque billet arrivé au compteur (ou fini de monter sans compteur) : rang 1 à `total`, dans l'ordre
--       d'arrivée. Billets en fontaine (Vfx.Collect.Fountain) : un par Stagger s, dérive, vol presque fixe.
--   VfxController.GetState() -> { Flyers, Bursts, ChaseGuard, Rarest }   (banc, barre de commande)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Vfx = require(Config:WaitForChild("Vfx"))
local Settings = require(Config:WaitForChild("Settings"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Items = require(Config:WaitForChild("Items"))
local Mutations = require(Config:WaitForChild("Mutations"))
local ItemOdds = require(Shared:WaitForChild("ItemOdds"))
local WeightConfig = require(Config:WaitForChild("Weight"))
local ItemWeight = require(Shared:WaitForChild("ItemWeight"))
local Format = require(Shared:WaitForChild("Format"))

local IS_STUDIO = RunService:IsStudio()
local PLOT_TAG = "PlayerPlot" -- contrat 2.1 (Contract/Tags)

type Flyer = {
	Model: Model,
	Parts: { BasePart },
	Start: Vector3,
	Pop: Vector3,
	Delay: number,
	Fly: number,
	Age: number,
	Spin: Vector3,
	Rise: boolean,
	-- a401 : vague de billets (un ramassage) et fontaine (Vfx.Collect.Fountain) : sortie à Delay s, dérive Drift.
	Wave: number,
	Fountain: boolean,
	Shown: boolean,
	Drift: Vector3,
	Group: LandGroup?, -- a317 : billets d'un même Collect (premier arrivé)
}

-- a401 : billets d'un ramassage encore en vol (rang de la prochaine arrivée).
type Wave = { total: number, arrived: number }

-- a317 (L-299) : un appel de Collect ; `done` dès que son premier billet est arrivé.
type LandGroup = { amount: number, done: boolean, onLanded: (() -> ())? }

type RarestEntry = {
	Gui: BillboardGui,
	Point: Attachment,
	Key: string?,
	Rays: GuiObject?,
	RaysBase: number,
	Crown: GuiObject?,
	CrownBase: number,
	Item: Model?, -- copie de l'objet le plus rare sur RarestSlot (L-118 point 6)
	ItemUid: string?,
	Slot: Attachment?, -- RarestSlot, ou ItemPoint du grand socle (a161)
	Holder: Instance, -- où ranger la copie de l'objet : RarestPedestal ou RarestDisplay
	Large: boolean, -- a161 : grand socle RarestDisplay (L-165 point 5)
}

export type State = {
	Flyers: number,
	Bursts: number,
	ChaseGuard: Model?,
	Rarest: number,
}

local VfxController = {}

local localPlayer = Players.LocalPlayer
local rng = Random.new()
local said: { [string]: boolean } = {}
local flyers: { Flyer } = {}
local bursts = 0 -- copies de FX_Escape et FX_TruckDust encore là
local chase: any = nil
local shelf: any = nil
local mutationFx: any = nil -- a178 : ClonePristine (copie de l'objet du socle)
local itemIdle: any = nil -- a317 : WithRest (copie de l'objet du socle sans son flottement)
local landedListeners: { (amount: number) -> () } = {} -- a317 : OnCollectLanded
local chaseGuard: Model? = nil
local chaseCopy: Highlight? = nil
local rarest: { [Instance]: RarestEntry } = {} -- [parcelle] = billboard posé
local sinceRarest = math.huge
local clock = 0
-- a401 : vagues de billets en vol et écouteurs du départ et de chaque arrivée.
local waves: { [number]: Wave } = {}
local waveCount = 0
type StartListener = (total: number, wave: number) -> ()
type ArriveListener = (rank: number, total: number, wave: number) -> ()
local startListeners: { StartListener } = {}
local arriveListeners: { ArriveListener } = {}

local function sayOnce(key: string, message: string)
	if IS_STUDIO and not said[key] then
		said[key] = true
		print(`[VfxController] {message}`)
	end
end

local function reduced(): boolean
	local ok, result = pcall(Settings.VfxReduced, localPlayer)
	return ok and result == true
end

local function folderOf(path: { string }): Instance?
	local current: Instance? = ReplicatedStorage
	for _, name in path do
		current = if current then current:FindFirstChild(name) else nil
	end
	return current
end

-- Le modèle de Clément `name` (sous-dossiers permis) de la classe voulue, ou nil (une ligne en Studio).
local function template(path: { string }, name: string, class: string): Instance?
	local folder = folderOf(path)
	local found = if folder then folder:FindFirstChild(name, true) else nil
	if found == nil or not found:IsA(class) then
		sayOnce(name, `{table.concat(path, "/")}/{name} ({class}) introuvable : effet coupé`)
		return nil
	end
	return found
end

local function numberAttribute(instance: Instance, name: string, default: number): number
	local value = instance:GetAttribute(name)
	if type(value) == "number" and value == value and value >= 0 then
		return value
	end
	return default
end

-- Pièces d'une copie : ancrées, sans collision ni requête (ne gênent ni les rayons ni les pas).
local function prepare(root: Instance): { BasePart }
	local parts: { BasePart } = {}
	local list = root:GetDescendants()
	table.insert(list, 1, root)
	for _, descendant in list do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			table.insert(parts, part)
		elseif descendant:IsA("LuaSourceContainer") then
			descendant:Destroy() -- jamais de script dans une copie (CLAUDE.md)
		end
	end
	return parts
end

------------------------------------------------------------------------------
-- Gerbes : FX_Escape, FX_TruckDust
------------------------------------------------------------------------------

-- Copie de `name` posée à `frame` : Emit(EmitCount × facteur) de chaque émetteur, lumières allumées
-- puis éteintes en FadeTime, détruite après Duration. Renvoie la copie, ou nil.
local function burst(name: string, frame: CFrame): Model?
	local source = template(Vfx.FxFolder, name, "Model")
	if source == nil then
		return nil
	end
	local factor = if reduced() then Vfx.OffEmitFactor else 1
	local copy = (source :: Model):Clone()
	prepare(copy)
	local emitters: { ParticleEmitter } = {}
	local lights: { Light } = {}
	for _, descendant in copy:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			local emitter = descendant :: ParticleEmitter
			emitter.Enabled = false
			table.insert(emitters, emitter)
		elseif descendant:IsA("Light") then
			local light = descendant :: Light
			light.Enabled = false
			table.insert(lights, light)
		end
	end
	copy:PivotTo(frame)
	copy.Parent = Workspace
	bursts += 1
	for _, emitter in emitters do
		local count = math.floor(numberAttribute(emitter, Vfx.EmitCountAttribute, Vfx.DefaultEmitCount) * factor)
		if count > 0 then
			emitter:Emit(count)
		end
	end
	if factor > 0 then
		for _, light in lights do
			local fade = numberAttribute(light, Vfx.FadeTimeAttribute, 0)
			light.Enabled = true
			if fade > 0 then
				TweenService:Create(light, TweenInfo.new(fade, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
			else
				light.Enabled = false
			end
		end
	end
	task.delay(numberAttribute(copy, Vfx.DurationAttribute, Vfx.DefaultDuration), function()
		bursts -= 1
		copy:Destroy()
	end)
	return copy
end

function VfxController.Escape(): Model?
	local character = localPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	local position = (root :: BasePart).Position - Vector3.new(0, Vfx.Escape.FootOffset, 0)
	return burst(Vfx.Escape.Model, CFrame.new(position))
end

function VfxController.TruckDust(model: Model): Model?
	return burst(Vfx.TruckDust.Model, model:GetPivot())
end

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local watchedTrucks: { [Instance]: boolean } = {}

local function watchTruck(instance: Instance)
	if not instance:IsA("Model") or watchedTrucks[instance] then
		return
	end
	local model = instance :: Model
	local spec = Vfx.TruckDust
	watchedTrucks[model] = true
	local pivot = model:GetPivot()
	local spawnedAt = model:GetAttribute(spec.SpawnedAtAttribute)
	-- a97 : un camion qui arrive en roulant (ArriveEndsAt) soulève sa poussière à l'impact au sol.
	local landsAt = model:GetAttribute(spec.ArriveEndsAtAttribute)
	local dustAt = if type(landsAt) == "number" then landsAt elseif type(spawnedAt) == "number" then spawnedAt else nil
	if dustAt and serverNow() < dustAt then
		task.delay(dustAt - serverNow(), function()
			if model:IsDescendantOf(Workspace) and model:GetAttribute(spec.ExplodedAtAttribute) == nil then
				VfxController.TruckDust(model)
			end
		end)
	elseif dustAt and serverNow() - dustAt <= spec.ArriveWindow then
		VfxController.TruckDust(model)
	end
	local connection: RBXScriptConnection? = nil
	connection = model.AncestryChanged:Connect(function()
		if model:IsDescendantOf(Workspace) then
			return
		end
		watchedTrucks[model] = nil
		if connection then
			connection:Disconnect()
		end
		-- Départ sans explosion (LeftAt posé par le serveur juste avant) ; une sortie du streaming : rien.
		if model:GetAttribute(spec.LeftAtAttribute) ~= nil and model:GetAttribute(spec.ExplodedAtAttribute) == nil then
			burst(spec.Model, pivot)
		end
	end)
end

------------------------------------------------------------------------------
-- Billets et pièces du ramassage
------------------------------------------------------------------------------

function VfxController.CollectCount(amount: number): number
	if reduced() then
		return 0
	end
	local spec = Vfx.Collect
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return 0
	end
	local extra = math.max(0, math.floor(math.log10(math.max(amount, 1) / spec.CountBase)))
	return math.clamp(spec.MinCount + extra, spec.MinCount, spec.MaxCount)
end

-- Point visé : à TargetDepth studs devant la caméra, sous le centre du compteur UI_HUD.Cash ; nil si le
-- compteur n'est pas à l'écran.
local function cashTarget(): Vector3?
	local camera = Workspace.CurrentCamera
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local hud = if playerGui then playerGui:FindFirstChild(Vfx.Collect.HudScreen) else nil
	if camera == nil or hud == nil or not hud:IsA("ScreenGui") or not (hud :: ScreenGui).Enabled then
		return nil
	end
	local cash = hud:FindFirstChild(Vfx.Collect.CashLabel, true)
	if cash == nil or not cash:IsA("GuiObject") or not (cash :: GuiObject).Visible then
		return nil
	end
	local label = cash :: GuiObject
	local center = label.AbsolutePosition + label.AbsoluteSize / 2
	local ok, ray = pcall(function(): Ray
		if (hud :: ScreenGui).IgnoreGuiInset then
			return camera:ViewportPointToRay(center.X, center.Y)
		end
		return camera:ScreenPointToRay(center.X, center.Y)
	end)
	if not ok then
		return nil
	end
	return ray.Origin + ray.Direction.Unit * Vfx.Collect.TargetDepth
end

-- a317 (L-299) : premier billet d'un Collect arrivé (une seule fois par groupe).
local function land(group: LandGroup)
	if group.done then
		return
	end
	group.done = true
	local callback = group.onLanded
	if callback then
		task.spawn(callback)
	end
	for _, listener in table.clone(landedListeners) do
		task.spawn(listener, group.amount)
	end
end

function VfxController.OnCollectLanded(listener: (amount: number) -> ()): () -> ()
	table.insert(landedListeners, listener)
	return function()
		local index = table.find(landedListeners, listener)
		if index then
			table.remove(landedListeners, index)
		end
	end
end

function VfxController.Collect(amount: number, position: Vector3, onLanded: (() -> ())?): number
	local spec = Vfx.Collect
	local group: LandGroup = { amount = if type(amount) == "number" then amount else 0, done = false, onLanded = onLanded }
	local count = VfxController.CollectCount(amount)
	if count == 0 then
		task.defer(land, group) -- a317 : aucun billet : le compteur part tout de suite
		return 0
	end
	local bill = template(Vfx.FxFolder, spec.Bill, "Model")
	local coin = template(Vfx.FxFolder, spec.Coin, "Model")
	if bill == nil and coin == nil then
		task.defer(land, group)
		return 0
	end
	local rise = cashTarget() == nil
	local fountain = spec.Fountain.Enabled
	waveCount += 1
	local wave = waveCount
	local made = 0
	if rise then
		task.defer(land, group) -- a317 : compteur hors écran : les billets montent sur place, le compteur part tout de suite
	end
	for index = 1, count do
		local isCoin = (index % 2 == 0 and spec.CoinShare > 0) or bill == nil
		local source = if isCoin and coin then coin else bill
		if source == nil then
			continue
		end
		local copy = (source :: Model):Clone()
		local parts = prepare(copy)
		local angle = rng:NextNumber(0, 2 * math.pi)
		local spread = rng:NextNumber(0, spec.PopSpread)
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local pop = position + outward * spread + Vector3.new(0, rng:NextNumber(spec.PopHeight[1], spec.PopHeight[2]), 0)
		local drift = Vector3.new(0, 0, 0)
		local fly = rng:NextNumber(spec.FlyTime[1], spec.FlyTime[2])
		if fountain then
			-- a401 : dérive vers le haut et l'extérieur, vol presque fixe (arrivées dans l'ordre)
			local f = spec.Fountain
			drift = (outward + Vector3.new(0, 1, 0)).Unit * rng:NextNumber(f.Drift[1], f.Drift[2])
			fly = f.FlyTime + rng:NextNumber(-f.FlyJitter, f.FlyJitter)
		end
		copy:PivotTo(CFrame.new(position))
		if not fountain then
			copy.Parent = Workspace -- fontaine : posé à sa sortie (stepFlyer), un par Stagger s
		end
		made += 1
		table.insert(flyers, {
			Model = copy,
			Parts = parts,
			Start = position,
			Pop = pop,
			Delay = (index - 1) * spec.Stagger,
			Fly = fly,
			Age = 0,
			Spin = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)),
			Rise = rise,
			Wave = wave,
			Fountain = fountain,
			Shown = not fountain,
			Drift = drift,
			Group = group,
		})
	end
	if made > 0 then
		waves[wave] = { total = made, arrived = 0 }
		for _, listener in table.clone(startListeners) do
			task.spawn(listener, made, wave)
		end
	end
	return made
end

function VfxController.OnCollectStart(listener: StartListener): () -> ()
	table.insert(startListeners, listener)
	return function()
		local index = table.find(startListeners, listener)
		if index then
			table.remove(startListeners, index)
		end
	end
end

function VfxController.OnCollectArrive(listener: ArriveListener): () -> ()
	table.insert(arriveListeners, listener)
	return function()
		local index = table.find(arriveListeners, listener)
		if index then
			table.remove(arriveListeners, index)
		end
	end
end

-- a401 : un billet de la vague `id` est arrivé (ou a disparu) : rang dans l'ordre d'arrivée, signalé aux écouteurs.
local function arrived(id: number)
	local wave = waves[id]
	if wave == nil then
		return
	end
	wave.arrived += 1
	local rank, total = wave.arrived, wave.total
	if rank >= total then
		waves[id] = nil
	end
	for _, listener in table.clone(arriveListeners) do
		task.spawn(listener, rank, total, id)
	end
end

local function sineOut(t: number): number
	return math.sin(t * math.pi / 2)
end

local function quadOut(t: number): number
	return 1 - (1 - t) * (1 - t)
end

-- Avance un billet ; false quand il est arrivé (détruit).
local function stepFlyer(flyer: Flyer, dt: number): boolean
	local spec = Vfx.Collect
	flyer.Age += dt
	local t = flyer.Age
	if flyer.Fountain then
		-- a401 : fontaine, le billet sort à son tour (Delay) ; ensuite le temps part de sa sortie.
		t -= flyer.Delay
		if t < 0 then
			return true
		end
		if not flyer.Shown then
			flyer.Shown = true
			flyer.Model.Parent = Workspace
		end
	end
	if flyer.Model.Parent == nil then
		arrived(flyer.Wave) -- détruit ailleurs : compté quand même (le HUD n'attend pas un billet perdu)
		local group = flyer.Group
		if group then
			land(group) -- a317 : billet retiré en route : le compteur n'attend pas
		end
		return false
	end
	local spin = math.rad(spec.Spin) * t
	local rotation = CFrame.Angles(flyer.Spin.X * spin, flyer.Spin.Y * spin, flyer.Spin.Z * spin)
	local popTime = if flyer.Fountain then spec.Fountain.PopTime else spec.PopTime
	if t < popTime then
		local p = flyer.Start:Lerp(flyer.Pop, quadOut(t / popTime))
		flyer.Model:PivotTo(CFrame.new(p) * rotation)
		return true
	end
	-- Attente au point haut : fontaine, HoverTime s en dérivant ; sinon immobile, Delay s (départs décalés).
	local wait = if flyer.Fountain then spec.Fountain.HoverTime else flyer.Delay
	if t < popTime + wait then
		local p = flyer.Pop + flyer.Drift * sineOut((t - popTime) / math.max(wait, 1e-3))
		flyer.Model:PivotTo(CFrame.new(p) * rotation)
		return true
	end
	local from = flyer.Pop + flyer.Drift
	local f = (t - popTime - wait) / flyer.Fly
	if f >= 1 then
		flyer.Model:Destroy()
		arrived(flyer.Wave)
		local group = flyer.Group
		if group then
			land(group) -- a317 (L-299) : le premier billet arrivé relâche le compteur
		end
		return false
	end
	local eased = f * f -- Quad In
	local target = if flyer.Rise then nil else cashTarget()
	if target == nil then
		target = from + Vector3.new(0, spec.RiseHeight, 0)
		for _, part in flyer.Parts do
			part.LocalTransparencyModifier = eased
		end
	end
	flyer.Model:PivotTo(CFrame.new(from:Lerp(target :: Vector3, eased)) * rotation)
	pcall(function()
		flyer.Model:ScaleTo(1 + (spec.EndScale - 1) * eased)
	end)
	return true
end

------------------------------------------------------------------------------
-- Contour du vigile en poursuite
------------------------------------------------------------------------------

local function reserve(count: number)
	if shelf and type(shelf.Reserve) == "function" then
		(shelf.Reserve :: any)(Vfx.Chase.ReserveKey, count)
	end
end

local function clearChase()
	local copy = chaseCopy
	chaseCopy = nil
	chaseGuard = nil
	if copy then
		copy:Destroy()
		reserve(0)
	end
end

local function stepChase()
	local guard: Model? = nil
	if chase and type(chase.GetGuard) == "function" then
		local found: Instance? = (chase.GetGuard :: any)()
		if found ~= nil and found:IsA("Model") and found:IsDescendantOf(Workspace) then
			guard = found :: Model
		end
	end
	if guard == nil then
		clearChase()
		return
	end
	local copy = chaseCopy
	if guard == chaseGuard and copy ~= nil and copy.Parent == guard then
		return
	end
	clearChase()
	local source = template(Vfx.FxFolder, Vfx.Chase.Highlight, "Highlight")
	if source == nil then
		return
	end
	local highlight = source:Clone() :: Highlight
	highlight.Name = Vfx.Chase.CopyName
	highlight.Adornee = guard
	highlight.Enabled = true
	highlight.Parent = guard
	chaseCopy = highlight
	chaseGuard = guard
	reserve(Vfx.Chase.Reserve)
end

------------------------------------------------------------------------------
-- BB_Rarest
------------------------------------------------------------------------------

type Spot = { Point: Attachment, Slot: Attachment?, Holder: Instance, Large: boolean }

local function attachment(root: Instance, name: string): Attachment?
	local found = root:FindFirstChild(name, true)
	return if found and found:IsA("Attachment") then found else nil
end

-- Où poser billboard et objet : le grand socle RarestDisplay s'il a son LabelPoint (a161, L-165 point 5),
-- sinon l'ancien socle RarestPedestal (TopPlate/RarestLabelPoint, RarestSlot), sinon nil.
local function rarestSpot(plot: Instance): Spot?
	local large = Vfx.RarestDisplay
	local display = plot:FindFirstChild(large.Model, true)
	if display then
		local point = attachment(display, large.LabelPoint)
		if point then
			return { Point = point, Slot = attachment(display, large.ItemPoint), Holder = display, Large = true }
		end
	end
	local spec = Vfx.Rarest
	local pedestal = plot:FindFirstChild(spec.Pedestal, true)
	local plate = if pedestal then pedestal:FindFirstChild(spec.Plate, true) else nil
	local point = if plate then attachment(plate, spec.Point) else nil
	if pedestal and point then
		return { Point = point, Slot = attachment(pedestal, spec.Slot), Holder = pedestal, Large = false }
	end
	return nil
end

type Best = { ItemId: string, Rarity: any, Income: number, Uid: string, Source: Instance }

-- a196 : vrai si `entry` passe avant `current`. Pick = "Income" : le plus gros revenu, puis le plus rare ;
-- "Rarity" (avant a196) : le plus rare, puis le plus gros revenu. Égalité : le plus petit ItemUid.
local function better(entry: Best, current: Best): boolean
	local byIncome = Vfx.Rarest.Pick ~= "Rarity"
	if byIncome and entry.Income ~= current.Income then
		return entry.Income > current.Income
	end
	if entry.Rarity.Order ~= current.Rarity.Order then
		return entry.Rarity.Order > current.Rarity.Order
	end
	if entry.Income ~= current.Income then
		return entry.Income > current.Income
	end
	return entry.Uid < current.Uid
end

-- L'objet exposé de la parcelle à montrer sur le socle (`better`), ou nil.
local function bestOf(plot: Instance): Best?
	local folder = plot:FindFirstChild(Vfx.Rarest.ItemsFolder, true)
	if folder == nil then
		return nil
	end
	local best: Best? = nil
	for _, child in folder:GetChildren() do
		local itemId = child:GetAttribute("ItemId")
		local rarity = Rarities.ById[child:GetAttribute("Rarity") :: any]
		if type(itemId) ~= "string" or rarity == nil or Items.ById[itemId] == nil then
			continue
		end
		local income = child:GetAttribute("Income")
		local uid = child:GetAttribute("ItemUid")
		local entry: Best = {
			ItemId = itemId,
			Rarity = rarity,
			Income = if type(income) == "number" then income else 0,
			Uid = if type(uid) == "string" then uid else child.Name,
			Source = child,
		}
		local current = best
		if current == nil or better(entry, current) then
			best = entry
		end
	end
	return best
end

local function removeRarest(plot: Instance)
	local entry = rarest[plot]
	if entry then
		rarest[plot] = nil
		entry.Gui:Destroy()
		if entry.Item then
			entry.Item:Destroy()
		end
	end
end

-- L-118 point 6 (Clément) : une copie de l'objet exposé le plus rare, pivot (bas au centre) sur l'Attachment
-- RarestSlot du socle, tournée comme sur son présentoir. Copie locale, comme BB_Rarest : sans billboard,
-- invite, script ni tag (les autres contrôleurs ne la prennent pas pour un objet exposé), ancrée, sans
-- collision. Refaite quand l'objet le plus rare change ; pas de RarestSlot : rien.
-- Grand socle (a161, L-165 point 5) : sur ItemPoint, à sa taille réelle (copie de l'objet exposé, mutation de
-- taille comprise, jamais réduite), tournée comme ItemPoint (face avant posée par Clément).
local function placeRarestItem(entry: RarestEntry, best: Best)
	if entry.Item then
		entry.Item:Destroy()
		entry.Item = nil
	end
	entry.ItemUid = best.Uid
	local spec = Vfx.Rarest
	local slot = entry.Slot
	local source = best.Source
	if slot == nil or slot.Parent == nil or not source:IsA("Model") then
		return
	end
	-- a178 : copie aux couleurs d'origine (MutationFxController.ClonePristine, sans l'effet déjà posé sur
	-- l'objet exposé), taggée CopyTag : MutationFxController y pose l'effet de la mutation et
	-- DisplayController anime son halo de rareté (RarityHalo, copié avec l'objet), comme sur un présentoir.
	-- a317 (L-304 point 3) : copiée à sa place de repos (ItemIdleController.WithRest), sans son flottement ni son tour.
	local function cloneSource(): Model
		return if mutationFx and type(mutationFx.ClonePristine) == "function"
			then (mutationFx.ClonePristine :: any)(source)
			else source:Clone()
	end
	local copy: Model
	if itemIdle and type(itemIdle.WithRest) == "function" then
		local made: Model? = nil
		(itemIdle.WithRest :: any)(source, function()
			made = cloneSource()
		end)
		copy = made or cloneSource()
	else
		copy = cloneSource()
	end
	for _, inst in copy:GetDescendants() do
		if inst:IsA("BillboardGui") or inst:IsA("ProximityPrompt") or inst:IsA("LuaSourceContainer") or inst:IsA("ClickDetector") then
			inst:Destroy()
			continue
		end
		for _, tag in inst:GetTags() do
			inst:RemoveTag(tag)
		end
		if inst:IsA("BasePart") then
			inst.Anchored = true
			inst.CanCollide = false
			inst.CanQuery = false
			inst.CanTouch = false
		end
	end
	for _, tag in copy:GetTags() do
		copy:RemoveTag(tag)
	end
	copy.Name = spec.ItemName
	copy:AddTag(spec.CopyTag)
	-- Vague 62 (a203) : un objet très lourd est plafonné à Weight.RarestMaxScale sur le socle (V0).
	-- a234 (L-220) : vraie taille sur le socle : la réduction FitSize de son présentoir (attribut FitScale) est retirée.
	local shown = copy:GetScale()
	local fit = source:GetAttribute(WeightConfig.FitScaleAttribute)
	local wanted = if type(fit) == "number" and fit > 0 and fit < 1 then shown / fit else shown
	if ItemWeight.Enabled() then
		wanted = math.min(wanted, WeightConfig.RarestMaxScale)
	end
	if math.abs(wanted - shown) > 1e-3 then
		pcall(copy.ScaleTo, copy, wanted)
	end
	local rotation = if entry.Large then slot.WorldCFrame.Rotation else source:GetPivot().Rotation
	copy:PivotTo(CFrame.new(slot.WorldPosition) * rotation)
	copy.Parent = entry.Holder
	entry.Item = copy
end

-- Mutation d'un objet exposé (attributs MutationSize et MutationEffect de DisplayService), ou nil.
local function mutationOf(source: Instance): Mutations.Mutation?
	return Mutations.Sanitize({ Size = source:GetAttribute("MutationSize"), Effect = source:GetAttribute("MutationEffect") })
end

local function textOf(gui: Instance, name: string): TextLabel?
	local found = gui:FindFirstChild(name, true)
	if found and found:IsA("TextLabel") then
		return found
	end
	return nil
end

local function guiObject(gui: Instance, name: string): GuiObject?
	local found = gui:FindFirstChild(name, true)
	if found and found:IsA("GuiObject") then
		return found
	end
	return nil
end

local function refreshRarest()
	local seen: { [Instance]: boolean } = {}
	for _, plot in CollectionService:GetTagged(PLOT_TAG) do
		seen[plot] = true
		local spot = rarestSpot(plot)
		local best = if spot then bestOf(plot) else nil
		if spot == nil or best == nil then
			removeRarest(plot)
			continue
		end
		local point = spot.Point
		local entry: RarestEntry? = rarest[plot]
		if entry and (entry.Point ~= point or entry.Gui.Parent ~= point or entry.Large ~= spot.Large or entry.Slot ~= spot.Slot) then
			removeRarest(plot)
			entry = nil
		end
		if entry == nil then
			-- Grand socle : BB_RarestDisplay, sinon BB_Rarest (mêmes noms Rarity, ItemName, Odds).
			local ui = if spot.Large then folderOf(Vfx.UiFolder) else nil
			local found = if ui then ui:FindFirstChild(Vfx.RarestDisplay.Billboard, true) else nil
			local source = if found and found:IsA("BillboardGui")
				then found
				else template(Vfx.UiFolder, Vfx.Rarest.Billboard, "BillboardGui")
			if spot.Large and source ~= found then
				sayOnce("rarestDisplay", `{Vfx.RarestDisplay.Billboard} pas encore livré : {Vfx.Rarest.Billboard} sur le grand socle`)
			end
			if source == nil then
				return
			end
			local gui = source:Clone() :: BillboardGui
			gui.Name = Vfx.Rarest.CopyName
			gui.Adornee = point
			gui.Parent = point
			local rays = guiObject(gui, "Rays")
			local crown = guiObject(gui, "CrownIcon")
			entry = {
				Gui = gui,
				Point = point :: Attachment,
				Key = nil,
				Rays = rays,
				RaysBase = if rays then rays.Rotation else 0,
				Crown = crown,
				CrownBase = if crown then crown.Rotation else 0,
				Slot = spot.Slot,
				Holder = spot.Holder,
				Large = spot.Large,
			}
			rarest[plot] = entry :: RarestEntry
		end
		local current = entry :: RarestEntry
		local chosen = best :: Best
		local mutation = mutationOf(chosen.Source)
		local key = `{chosen.ItemId}|{chosen.Rarity.Id}|{Mutations.Label(mutation) or ""}|{chosen.Income}|{tostring(chosen.Source:GetAttribute(WeightConfig.Attribute))}`
		if current.Key ~= key then
			current.Key = key
			-- a196 (Cantin, T-096) : « BEST ITEM » dans le titre de Clément, et le revenu/s de l'objet dans Income
			-- (sinon dans IncomeFallback, à la place de la chance).
			local spec = Vfx.Rarest
			if spec.Title then
				for _, field in spec.TitleFields do
					local title = textOf(current.Gui, field)
					if title then
						title.Text = spec.Title
					end
				end
			end
			local byIncome = spec.Pick ~= "Rarity"
			local incomeLabel = if byIncome then textOf(current.Gui, spec.IncomeField) else nil
			local incomeInOdds = byIncome and incomeLabel == nil and spec.IncomeFallback == "Odds"
			if incomeLabel then
				incomeLabel.Text = Format.income(chosen.Income)
				incomeLabel.Visible = true
			end
			local rarityLabel = textOf(current.Gui, "Rarity")
			if rarityLabel then
				rarityLabel.Text = chosen.Rarity.DisplayNameUpper
				rarityLabel.TextColor3 = chosen.Rarity.Color
			end
			local nameLabel = textOf(current.Gui, "ItemName")
			if nameLabel then
				nameLabel.Text = Items.ById[chosen.ItemId].DisplayName
			end
			-- Ancien socle : la chance du tirage n'est pas gardée avec l'objet exposé, Odds caché. Grand socle
			-- (a161) : chance de référence (Shared/ItemOdds), cachée si elle est inconnue ; Mutation
			-- (« BIG · GOLD »), cachée sans mutation. Header : Vfx.Rarest.Title (a196).
			local odds = textOf(current.Gui, "Odds")
			if odds and incomeInOdds then
				odds.Text = Format.income(chosen.Income)
				odds.Visible = true
			elseif odds then
				local oneIn = if current.Large then ItemOdds.OneIn(chosen.ItemId, mutation) else nil
				odds.Visible = oneIn ~= nil
				if oneIn then
					odds.Text = ItemOdds.Format(oneIn)
				end
			end
			-- Vague 62 (a203) : poids de l'objet (« 1,250 kg ») dans l'élément facultatif Weight, caché sans poids.
			local weightLabel = textOf(current.Gui, WeightConfig.Field)
			if weightLabel then
				local kg = if ItemWeight.Enabled() then ItemWeight.Sanitize(chosen.Source:GetAttribute(WeightConfig.Attribute)) else nil
				weightLabel.Text = if kg then ItemWeight.Format(kg) else ""
				weightLabel.Visible = kg ~= nil
			end
			local mutationLabel = if current.Large then textOf(current.Gui, "Mutation") else nil
			if mutationLabel then
				local text = Mutations.Label(mutation)
				mutationLabel.Text = text or ""
				mutationLabel.Visible = text ~= nil
			end
		end
		local item = current.Item
		if current.ItemUid ~= chosen.Uid or (item ~= nil and item.Parent == nil) then
			placeRarestItem(current, chosen)
		end
	end
	for plot in rarest do
		if not seen[plot] then
			removeRarest(plot)
		end
	end
end

local function animateRarest()
	local spec = Vfx.Rarest
	local camera = Workspace.CurrentCamera
	local cameraPosition = if camera then camera.CFrame.Position else nil
	for _, entry in rarest do
		if cameraPosition and (entry.Point.WorldPosition - cameraPosition).Magnitude > spec.MaxDistance then
			continue
		end
		local rays = entry.Rays
		if rays then
			rays.Rotation = (entry.RaysBase + clock * spec.RaysSpeed) % 360
		end
		local crown = entry.Crown
		if crown then
			crown.Rotation = entry.CrownBase + spec.CrownSwing * math.sin(2 * math.pi * clock / spec.CrownPeriod)
		end
	end
end

------------------------------------------------------------------------------

local function step(dt: number)
	clock += dt
	for index = #flyers, 1, -1 do
		if not stepFlyer(flyers[index], dt) then
			table.remove(flyers, index)
		end
	end
	stepChase()
	sinceRarest += dt
	if sinceRarest >= Vfx.Rarest.Refresh then
		sinceRarest = 0
		refreshRarest()
	end
	animateRarest()
end

function VfxController.GetState(): State
	local count = 0
	for _ in rarest do
		count += 1
	end
	return { Flyers = #flyers, Bursts = bursts, ChaseGuard = chaseGuard, Rarest = count }
end

local function sibling(name: string): any
	local module = script.Parent:FindFirstChild(name)
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, module)
	local value: any = result
	return if ok and type(value) == "table" then value else nil
end

function VfxController.Start()
	chase = sibling("ChaseController")
	shelf = sibling("ShelfBoxController")
	mutationFx = sibling("MutationFxController")
	itemIdle = sibling("ItemIdleController")
	local display = sibling("DisplayController")
	if display and type(display.OnCollect) == "function" then
		(display.OnCollect :: any)(function(amount: number, _slotIndex: number, position: Vector3)
			VfxController.Collect(amount, position)
		end)
	else
		sayOnce("display", "DisplayController.OnCollect absent : pas de billets au ramassage")
	end
	local truckTag = Vfx.TruckDust.TruckTag
	CollectionService:GetInstanceAddedSignal(truckTag):Connect(watchTruck)
	for _, truck in CollectionService:GetTagged(truckTag) do
		watchTruck(truck)
	end
	local function onError(err: any) -- a283 (audit a271 point 12) : définie une fois, pas une fermeture par image
		sayOnce(`error:{err}`, tostring(err))
	end
	RunService.Heartbeat:Connect(function(dt: number)
		xpcall(step, onError, dt)
	end)
end

return VfxController
