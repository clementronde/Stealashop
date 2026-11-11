--!strict
-- MachineVariantService (DEV-020, liaison L-082 et L-093 point 3) : le tapis de la parcelle change de
-- modèle avec le niveau de son amélioration (Partie 1, sections 5.1 et 7.5).
--
-- Rôle : toutes les parcelles commencent avec le même tapis (`Treadmill`, posé par Clément). Selon le
-- niveau Upgrades.Treadmill du profil du propriétaire, ce service le remplace par une copie de
-- ReplicatedStorage/Assets/Plots/PLOT_Treadmill_<Variante> (paliers : Config/Upgrades,
-- TreadmillVariants et TreadmillTierEvery ; ordre validé par Clément en L-097). Chaque variante a sa
-- Belt, ses effets et sa pièce UseZone, que TrainingService lit comme zone de montée. Pas de variante de
-- banc pour l'instant. Les effets des tapis animés par le code (défilement de BeltTexture, RunBurst…,
-- notes/boutique-joueur-MOD-015-016.md) ne sont pas branchés ici.
--
-- Remplacement (côté serveur, répliqué à tous) :
--   - la copie prend le pivot du tapis de la parcelle (les variantes ont le même pivot, L-082), le nom
--     `Treadmill`, le tag `Treadmill` et les attributs du tapis de la parcelle qu'elle n'a pas ; elle est
--     rangée au même endroit (même parent). Le tapis de la parcelle est mis de côté (Parent = nil, gardé
--     en mémoire, jamais détruit) et revient tel quel au palier « Base » ;
--   - une variante absente des Assets, qui n'est pas un Model ou qui n'a pas d'Attachment UsePoint
--     (contrat 10.4) : le tapis actuel reste, une ligne dans la sortie (une fois par variante). Une
--     variante sans Belt ou sans UpgradePoint est posée quand même, avec une ligne : TrainingService
--     et UpgradeController ont leurs replis ;
--   - le reste suit tout seul, par le tag et les noms : TrainingService retire l'ancien tapis (le
--     joueur dessus en descend) et enregistre le nouveau (il y est remis s'il est dans sa zone),
--     UpgradeController (client) repose le panneau UpgradeSign sur le nouvel UpgradePoint (il suit
--     les descendants de la parcelle), ShopService et TutorialService cherchent le tapis à chaque fois.
--
-- Quand : à l'attribution d'une parcelle (profil chargé, PlotService), à chaque changement de
-- l'attribut TreadmillLevel du propriétaire (ShopService, après un achat), une fois par seconde par
-- sécurité (niveau changé sans passer par la boutique), et au départ du joueur : la parcelle libérée
-- retrouve le tapis de base (OnPlotReleased) avant de servir au joueur suivant.
--
-- Aucun remote, aucun attribut posé. API (serveur) :
--   MachineVariantService.Refresh(plot)
--       Remet tout de suite le tapis de `plot` d'accord avec son propriétaire. Sans yield.
--   MachineVariantService.GetVariant(plot) -> string?
--       Variante posée (« Base », « Silver »…), nil si la parcelle n'a pas de tapis suivi.
--   MachineVariantService.VariantFor(level) -> string
--       Variante du palier de `level` (Config/Upgrades).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Upgrades = require(ReplicatedStorage.Shared.Config.Upgrades)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

-- Contrat (2.1, 10.3 et 10.4) et attribut de ShopService.
local TREADMILL_TAG = "Treadmill"
local TREADMILL_NAME = "Treadmill"
local ASSET_FORMAT = "PLOT_Treadmill_%s"
local BASE = "Base"
local USE_POINT = "UsePoint"
local BELT = "Belt"
local UPGRADE_POINT = "UpgradePoint"
local LEVEL_ATTRIBUTE = "TreadmillLevel"

-- V0 proposé, absent du doc : contrôle de sécurité une fois par seconde (comme RayonService).
local RECONCILE_PERIOD = 1

type PlotState = {
	base: Instance, -- tapis posé par Clément dans la parcelle (mis de côté pendant une variante)
	parent: Instance, -- son parent d'origine
	pivot: CFrame, -- son pivot d'origine
	current: Instance, -- tapis en place : `base` ou une copie
	variant: string, -- « Base » ou la variante en place
}

local IS_STUDIO = RunService:IsStudio()

local MachineVariantService = {}
MachineVariantService.Priority = 125 -- après PlotService (10), DataService (1), ShopService (100)

local states: { [Model]: PlotState } = {}
local levelConnections: { [Player]: RBXScriptConnection } = {}
local warned: { [string]: boolean } = {}

local function warnOnce(key: string, message: string)
	if not warned[key] then
		warned[key] = true
		warn(`[MachineVariantService] {message}`)
	end
end

local function log(message: string)
	if IS_STUDIO then
		print(`[MachineVariantService] {message}`)
	end
end

-- Palier du niveau (Config/Upgrades : liste ordonnée, un palier toutes les TreadmillTierEvery
-- améliorations, le dernier au-delà).
local function variantFor(level: number): string
	local list = Upgrades.TreadmillVariants
	local every = math.max(1, Upgrades.TreadmillTierEvery)
	local index = math.clamp(math.floor(math.max(level, 0) / every) + 1, 1, math.max(#list, 1))
	return list[index] or BASE
end

-- Niveau du tapis du propriétaire de la parcelle : 0 sans propriétaire ou sans profil.
-- Crochet de test, STUDIO SEULEMENT (comme TruckSpawnNow) : workspace:SetAttribute("TreadmillLevelTest", 8)
-- montre sur chaque parcelle occupée le tapis de ce niveau (8 : Police), sans toucher au profil ;
-- workspace:SetAttribute("TreadmillLevelTest", nil) rend le tapis du profil (au plus 1 s après).
local function levelFor(plot: Model): number
	local owner = PlotService.GetOwner(plot)
	local test = if IS_STUDIO and owner then workspace:GetAttribute("TreadmillLevelTest") else nil
	if type(test) == "number" then
		return math.max(0, math.floor(test))
	end
	local data = if owner then DataService.Get(owner) else nil
	local level = if data then data.Upgrades.Treadmill else 0
	if type(level) ~= "number" or level ~= level or level < 0 then
		return 0
	end
	return math.floor(level)
end

-- Modèle de la variante, ou nil (avec une ligne dans la sortie) s'il manque ou n'est pas utilisable.
local function templateOf(variant: string): Model?
	local name = string.format(ASSET_FORMAT, variant)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local plots = if assets then assets:FindFirstChild("Plots") else nil
	local found = if plots then plots:FindFirstChild(name) else nil
	if found == nil then
		warnOnce(name, `{name} absent de ReplicatedStorage.Assets.Plots : le tapis actuel reste (L-093)`)
		return nil
	end
	if not found:IsA("Model") then
		warnOnce(name, `{name} n'est pas un Model : le tapis actuel reste`)
		return nil
	end
	local usePoint = found:FindFirstChild(USE_POINT, true)
	if usePoint == nil or not usePoint:IsA("Attachment") then
		warnOnce(name, `{name} : pas d'Attachment {USE_POINT} (contrat 10.4) : le tapis actuel reste`)
		return nil
	end
	if found:FindFirstChild(BELT, true) == nil then
		warnOnce(name .. BELT, `{name} : pas de {BELT} (contrat 10.4) : TrainingService prend sa zone de repli`)
	end
	if found:FindFirstChild(UPGRADE_POINT, true) == nil then
		warnOnce(name .. UPGRADE_POINT, `{name} : pas d'{UPGRADE_POINT} : le panneau d'amélioration se pose au-dessus du tapis`)
	end
	return found :: Model
end

-- Tapis de la parcelle au démarrage : le premier modèle taggé Treadmill dedans.
local function track(plot: Model)
	if states[plot] then
		return
	end
	for _, inst in CollectionService:GetTagged(TREADMILL_TAG) do
		if inst:IsA("Model") and inst:IsDescendantOf(plot) and inst.Parent ~= nil then
			local model = inst :: Model
			states[plot] = {
				base = model,
				parent = model.Parent :: Instance,
				pivot = model:GetPivot(),
				current = model,
				variant = BASE,
			}
			return
		end
	end
	warnOnce(plot:GetFullName(), `{plot:GetFullName()} : pas de tapis (Model taggé {TREADMILL_TAG}) : pas de variante`)
end

-- Pose la copie de `template` à la place du tapis en place.
local function swap(state: PlotState, template: Model, variant: string)
	local copy = template:Clone()
	copy.Name = TREADMILL_NAME
	for key, value in state.base:GetAttributes() do
		if copy:GetAttribute(key) == nil then
			copy:SetAttribute(key, value)
		end
	end
	if not CollectionService:HasTag(copy, TREADMILL_TAG) then
		CollectionService:AddTag(copy, TREADMILL_TAG)
	end
	copy:PivotTo(state.pivot)
	local old = state.current
	copy.Parent = state.parent
	if old == state.base then
		old.Parent = nil -- gardé pour le retour au palier Base
	else
		old:Destroy()
	end
	state.current, state.variant = copy, variant
end

-- Remet le tapis posé par Clément.
local function restore(state: PlotState)
	local old = state.current
	if old ~= state.base then
		old:Destroy()
	end
	local base = state.base
	if base.Parent ~= state.parent then
		base.Parent = state.parent
	end
	if base:IsA("PVInstance") then
		(base :: PVInstance):PivotTo(state.pivot)
	end
	state.current, state.variant = base, BASE
end

local function apply(plot: Model)
	local state = states[plot]
	if state == nil then
		return
	end
	local level = levelFor(plot)
	local wanted = variantFor(level)
	if wanted == state.variant then
		return
	end
	local before = state.variant
	if wanted == BASE then
		restore(state)
	else
		local template = templateOf(wanted)
		if template == nil then
			return -- absente : le tapis actuel reste (ligne déjà écrite)
		end
		swap(state, template, wanted)
	end
	log(`{plot.Name} : tapis {before} → {wanted} (niveau {level})`)
end

local function watchLevel(player: Player)
	local old = levelConnections[player]
	if old then
		old:Disconnect()
	end
	levelConnections[player] = player:GetAttributeChangedSignal(LEVEL_ATTRIBUTE):Connect(function()
		local current = PlotService.GetPlot(player)
		if current then
			apply(current)
		end
	end)
end

local function onAssigned(player: Player, plot: Model)
	watchLevel(player)
	apply(plot)
end

local function onReleased(player: Player, plot: Model)
	local connection = levelConnections[player]
	if connection then
		connection:Disconnect()
		levelConnections[player] = nil
	end
	local state = states[plot]
	if state and state.variant ~= BASE then
		log(`{plot.Name} libérée : tapis {state.variant} → {BASE}`)
		restore(state)
	end
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------

function MachineVariantService.Refresh(plot: Model)
	apply(plot)
end

function MachineVariantService.GetVariant(plot: Model): string?
	local state = states[plot]
	return if state then state.variant else nil
end

function MachineVariantService.VariantFor(level: number): string
	return variantFor(level)
end

function MachineVariantService.Start()
	for _, plot in PlotService.GetPlots() do
		track(plot)
	end
	PlotService.OnPlotAssigned(onAssigned)
	PlotService.OnPlotReleased(onReleased)
	Players.PlayerRemoving:Connect(function(player: Player)
		local connection = levelConnections[player]
		if connection then
			connection:Disconnect()
			levelConnections[player] = nil
		end
	end)
	while true do
		task.wait(RECONCILE_PERIOD)
		for _, plot in PlotService.GetPlots() do
			apply(plot)
		end
	end
end

return MachineVariantService
