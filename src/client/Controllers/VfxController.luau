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
-- VISUAL EFFECTS sur OFF (Settings.VfxReduced) : billets et pièces coupés, particules et lumière de la
-- victoire et du camion × Vfx.OffEmitFactor (0 : rien). Le contour du vigile et BB_Rarest restent.
-- Un modèle de Clément absent : rien (une ligne en Studio, une fois).
--
-- API (client) :
--   VfxController.Escape()                          victoire en zone safe aux pieds du joueur local
--   VfxController.Collect(amount, position)         billets et pièces depuis `position`
--   VfxController.TruckDust(model)                  poussière au pivot du camion
--   VfxController.CollectCount(amount) -> number    billets et pièces pour ce montant (0 si effets coupés)
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
}

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
local chaseGuard: Model? = nil
local chaseCopy: Highlight? = nil
local rarest: { [Instance]: RarestEntry } = {} -- [parcelle] = billboard posé
local sinceRarest = math.huge
local clock = 0

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

function VfxController.Collect(amount: number, position: Vector3): number
	local spec = Vfx.Collect
	local count = VfxController.CollectCount(amount)
	if count == 0 then
		return 0
	end
	local bill = template(Vfx.FxFolder, spec.Bill, "Model")
	local coin = template(Vfx.FxFolder, spec.Coin, "Model")
	if bill == nil and coin == nil then
		return 0
	end
	local rise = cashTarget() == nil
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
		local pop = position
			+ Vector3.new(math.cos(angle) * spread, rng:NextNumber(spec.PopHeight[1], spec.PopHeight[2]), math.sin(angle) * spread)
		copy:PivotTo(CFrame.new(position))
		copy.Parent = Workspace
		table.insert(flyers, {
			Model = copy,
			Parts = parts,
			Start = position,
			Pop = pop,
			Delay = (index - 1) * spec.Stagger,
			Fly = rng:NextNumber(spec.FlyTime[1], spec.FlyTime[2]),
			Age = 0,
			Spin = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)),
			Rise = rise,
		})
	end
	return count
end

local function quadOut(t: number): number
	return 1 - (1 - t) * (1 - t)
end

-- Avance un billet ; false quand il est arrivé (détruit).
local function stepFlyer(flyer: Flyer, dt: number): boolean
	local spec = Vfx.Collect
	flyer.Age += dt
	local t = flyer.Age
	if flyer.Model.Parent == nil then
		return false
	end
	local spin = math.rad(spec.Spin) * t
	local rotation = CFrame.Angles(flyer.Spin.X * spin, flyer.Spin.Y * spin, flyer.Spin.Z * spin)
	if t < spec.PopTime then
		local p = flyer.Start:Lerp(flyer.Pop, quadOut(t / spec.PopTime))
		flyer.Model:PivotTo(CFrame.new(p) * rotation)
		return true
	end
	if t < spec.PopTime + flyer.Delay then
		flyer.Model:PivotTo(CFrame.new(flyer.Pop) * rotation)
		return true
	end
	local f = (t - spec.PopTime - flyer.Delay) / flyer.Fly
	if f >= 1 then
		flyer.Model:Destroy()
		return false
	end
	local eased = f * f -- Quad In
	local target = if flyer.Rise then nil else cashTarget()
	if target == nil then
		target = flyer.Pop + Vector3.new(0, spec.RiseHeight, 0)
		for _, part in flyer.Parts do
			part.LocalTransparencyModifier = eased
		end
	end
	flyer.Model:PivotTo(CFrame.new(flyer.Pop:Lerp(target :: Vector3, eased)) * rotation)
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

local function labelPoint(plot: Instance): Attachment?
	local spec = Vfx.Rarest
	local pedestal = plot:FindFirstChild(spec.Pedestal, true)
	local plate = if pedestal then pedestal:FindFirstChild(spec.Plate, true) else nil
	local point = if plate then plate:FindFirstChild(spec.Point, true) else nil
	if point and point:IsA("Attachment") then
		return point
	end
	return nil
end

type Best = { ItemId: string, Rarity: any, Income: number, Uid: string, Source: Instance }

-- L'objet exposé le plus rare de la parcelle (même rareté : le plus gros revenu), ou nil.
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
		if
			current == nil
			or rarity.Order > current.Rarity.Order
			or (rarity.Order == current.Rarity.Order and (entry.Income > current.Income or (entry.Income == current.Income and entry.Uid < current.Uid)))
		then
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
local function placeRarestItem(plot: Instance, entry: RarestEntry, best: Best)
	if entry.Item then
		entry.Item:Destroy()
		entry.Item = nil
	end
	entry.ItemUid = best.Uid
	local spec = Vfx.Rarest
	local pedestal = plot:FindFirstChild(spec.Pedestal, true)
	local slot = if pedestal then pedestal:FindFirstChild(spec.Slot, true) else nil
	local source = best.Source
	if pedestal == nil or slot == nil or not slot:IsA("Attachment") or not source:IsA("Model") then
		return
	end
	local copy = source:Clone()
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
	copy:PivotTo(CFrame.new((slot :: Attachment).WorldPosition) * source:GetPivot().Rotation)
	copy.Parent = pedestal
	entry.Item = copy
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
		local point = labelPoint(plot)
		local best = if point then bestOf(plot) else nil
		if point == nil or best == nil then
			removeRarest(plot)
			continue
		end
		local entry: RarestEntry? = rarest[plot]
		if entry and (entry.Point ~= point or entry.Gui.Parent ~= point) then
			removeRarest(plot)
			entry = nil
		end
		if entry == nil then
			local source = template(Vfx.UiFolder, Vfx.Rarest.Billboard, "BillboardGui")
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
			}
			rarest[plot] = entry :: RarestEntry
		end
		local current = entry :: RarestEntry
		local chosen = best :: Best
		local key = `{chosen.ItemId}|{chosen.Rarity.Id}`
		if current.Key ~= key then
			current.Key = key
			local rarityLabel = textOf(current.Gui, "Rarity")
			if rarityLabel then
				rarityLabel.Text = chosen.Rarity.DisplayNameUpper
				rarityLabel.TextColor3 = chosen.Rarity.Color
			end
			local nameLabel = textOf(current.Gui, "ItemName")
			if nameLabel then
				nameLabel.Text = Items.ById[chosen.ItemId].DisplayName
			end
			-- La chance du tirage n'est pas gardée avec l'objet exposé : Odds caché.
			local odds = textOf(current.Gui, "Odds")
			if odds then
				odds.Visible = false
			end
		end
		local item = current.Item
		if current.ItemUid ~= chosen.Uid or (item ~= nil and item.Parent == nil) then
			placeRarestItem(plot, current, chosen)
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
	RunService.Heartbeat:Connect(function(dt: number)
		xpcall(step, function(err: any)
			sayOnce(`error:{err}`, tostring(err))
		end, dt)
	end)
end

return VfxController
