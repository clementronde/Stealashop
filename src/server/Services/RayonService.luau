--!strict
-- RayonService (DEV-020, MOD-015) : les rayons de présentoirs de la boutique du joueur apparaissent
-- avec les achats (liaison L-082 point 2, L-086 point 3 ; Partie 1, sections 5.8 et 7.5).
--
-- Rôle : les 20 présentoirs d'une parcelle sont rangés par Clément en 5 rayons de 4 : le Model
-- `Rayon_0k` contient `DisplayStand_(4k-3)` à `DisplayStand_4k`, chacun avec son Attachment
-- `DisplaySlot_xx`, plus son décor. Un rayon est montré dès que son premier présentoir est débloqué,
-- et caché tant qu'aucun de ses présentoirs ne l'est, pour tous les joueurs (le serveur change les
-- propriétés, elles se répliquent). Présentoirs débloqués = Balance.Display.StartSlots (4) + niveau
-- Upgrades.DisplaySlots du profil du propriétaire, au plus Balance.Display.MaxSlots (20), comme
-- DisplayService ; une parcelle libre compte StartSlots, donc ne montre que `Rayon_01`. Les
-- présentoirs bonus du gamepass (`DisplaySlot_21` et suivants, L-066) ne comptent pas : ils ne sont
-- dans aucun rayon et ce service n'y touche pas.
--
-- Le premier présentoir d'un rayon est le plus petit numéro de `DisplaySlot_01` à `_20` trouvé dans
-- ses descendants ; un rayon sans présentoir (décor seul) prend 4 × (k − 1) + 1 d'après son nom.
--
-- Quand : à l'attribution d'une parcelle et au départ du joueur (PlotService), à chaque achat de
-- présentoir (attribut DisplaySlotsLevel du Player, écrit par ShopService), et une fois par seconde
-- par sécurité (un niveau changé sans passer par la boutique, renaissance en Partie 2).
--
-- Comment un rayon est caché (V0 proposé, absent du doc) : il reste à sa place, dans la parcelle,
-- pour que `DisplaySlot_xx` reste trouvable par Find.path (DisplayService, PvPService, TutorialService,
-- UpgradeController, ContractChecker). Ce service mémorise puis change, sur le rayon et chacun de
-- ses descendants :
--   - BasePart : Transparency = 1, CanCollide, CanTouch et CanQuery = false ;
--   - Decal et Texture : Transparency = 1 ;
--   - SurfaceGui, BillboardGui, lumières (Light), ParticleEmitter, Beam, Trail, Fire, Smoke,
--     Sparkles, Highlight : Enabled = false.
-- Ce qui est ajouté au rayon pendant qu'il est caché est caché aussi. Quand le rayon réapparaît,
-- chaque propriété reprend exactement la valeur mémorisée. Les ProximityPrompt et ClickDetector ne
-- sont pas touchés : ce sont ceux du code, qui décide lui-même où les poser (l'invite « Unlock
-- stand » d'UpgradeController reste ainsi sur le prochain présentoir verrouillé, même dans un rayon
-- caché : une ProximityPrompt s'affiche quelle que soit la transparence de sa pièce). Rien n'est
-- déplacé, détruit, renommé ni sauvegardé : le modèle de Clément reste intact dans Studio.
--
-- Aucun remote, aucun attribut posé. API (serveur) :
--   RayonService.Refresh(plot)
--       Remet tout de suite les rayons de `plot` d'accord avec son propriétaire. Sans yield.
--   RayonService.IsShown(plot, rayonIndex) -> boolean?
--       Le rayon `Rayon_<rayonIndex>` de la parcelle est-il montré ? nil s'il n'existe pas.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

-- Noms convenus (L-082 point 2, contrat 10.4) et attribut de ShopService.
local RAYON_PATTERN = "^Rayon_(%d+)$"
local SLOT_PATTERN = "^DisplaySlot_(%d+)$"
local LEVEL_ATTRIBUTE = "DisplaySlotsLevel"

-- V0 proposé, absent du doc : 4 présentoirs par rayon (L-082 : « 5 rayons de 4 »), pour un rayon
-- sans présentoir ; contrôle de sécurité une fois par seconde.
local SLOTS_PER_RAYON = 4
local RECONCILE_PERIOD = 1

-- Propriétés changées pour cacher, par famille de classes.
local PART_HIDDEN: { [string]: any } = { Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false }
local DECAL_HIDDEN: { [string]: any } = { Transparency = 1 }
local ENABLED_HIDDEN: { [string]: any } = { Enabled = false }
local ENABLED_CLASSES = { "SurfaceGui", "BillboardGui", "Light", "ParticleEmitter", "Beam", "Trail", "Fire", "Smoke", "Sparkles", "Highlight" }

type Rayon = { model: Instance, index: number, first: number }
type Hidden = { saved: { [Instance]: { [string]: any } }, connection: RBXScriptConnection }

local IS_STUDIO = RunService:IsStudio()

local RayonService = {}
RayonService.Priority = 120 -- après PlotService (10), DataService (1) et ShopService (100)

local rayonsOf: { [Model]: { Rayon } } = {}
local countOf: { [Model]: number } = {} -- présentoirs débloqués lors de la dernière mise à jour
local hiddenOf: { [Instance]: Hidden } = {}
local levelConnections: { [Player]: RBXScriptConnection } = {}

local function hiddenValues(inst: Instance): { [string]: any }?
	if inst:IsA("BasePart") then
		return PART_HIDDEN
	elseif inst:IsA("Decal") then -- Texture compris
		return DECAL_HIDDEN
	end
	for _, class in ENABLED_CLASSES do
		if inst:IsA(class) then
			return ENABLED_HIDDEN
		end
	end
	return nil
end

-- Cache une instance en mémorisant ses valeurs (une seule fois).
local function hideOne(inst: Instance, saved: { [Instance]: { [string]: any } })
	if saved[inst] then
		return
	end
	local values = hiddenValues(inst)
	if values == nil then
		return
	end
	local before: { [string]: any } = {}
	local target = inst :: any
	for property, value in values do
		before[property] = target[property]
		target[property] = value
	end
	saved[inst] = before
end

local function hideRayon(model: Instance)
	if hiddenOf[model] then
		return
	end
	local saved: { [Instance]: { [string]: any } } = {}
	hideOne(model, saved)
	for _, descendant in model:GetDescendants() do
		hideOne(descendant, saved)
	end
	hiddenOf[model] = {
		saved = saved,
		connection = model.DescendantAdded:Connect(function(descendant: Instance)
			hideOne(descendant, saved)
		end),
	}
end

local function showRayon(model: Instance)
	local hidden = hiddenOf[model]
	if hidden == nil then
		return
	end
	hiddenOf[model] = nil
	hidden.connection:Disconnect()
	for inst, before in hidden.saved do
		local target = inst :: any
		for property, value in before do
			target[property] = value
		end
	end
end

-- Rayons de la parcelle, triés par numéro. Cherchés une fois, avant que le code y pose quoi que ce soit.
local function rayonsFor(plot: Model): { Rayon }
	local cached = rayonsOf[plot]
	if cached then
		return cached
	end
	local max = Balance.Display.MaxSlots
	local list: { Rayon } = {}
	for _, inst in plot:GetDescendants() do
		local digits = string.match(inst.Name, RAYON_PATTERN)
		if digits then
			local index = tonumber(digits) :: number
			local first = SLOTS_PER_RAYON * (index - 1) + 1
			local found = math.huge
			for _, descendant in inst:GetDescendants() do
				local slotDigits = string.match(descendant.Name, SLOT_PATTERN)
				local slot = if slotDigits and descendant:IsA("Attachment") then tonumber(slotDigits) else nil
				if slot and slot > max then
					warn(
						`[RayonService] {plot:GetFullName()} : {descendant.Name} (présentoir bonus) est dans {inst.Name} : il sera caché avec ce rayon`
					)
				elseif slot and slot < found then
					found = slot
				end
			end
			if found ~= math.huge then
				first = found
			end
			table.insert(list, { model = inst, index = index, first = first })
		end
	end
	table.sort(list, function(a: Rayon, b: Rayon): boolean
		return a.index < b.index
	end)
	if #list == 0 then
		warn(`[RayonService] {plot:GetFullName()} : aucun Rayon_0k (L-082) : tous les présentoirs restent visibles`)
	end
	rayonsOf[plot] = list
	return list
end

-- Présentoirs de base débloqués pour la parcelle : StartSlots sans propriétaire ou sans profil.
local function unlockedFor(plot: Model): number
	local display = Balance.Display
	local owner = PlotService.GetOwner(plot)
	local data = if owner then DataService.Get(owner) else nil
	local level = if data then data.Upgrades.DisplaySlots else 0
	if type(level) ~= "number" or level ~= level or level < 0 then
		level = 0
	end
	return math.clamp(display.StartSlots + math.floor(level), 0, display.MaxSlots)
end

local function apply(plot: Model)
	local count = unlockedFor(plot)
	local shown = 0
	for _, rayon in rayonsFor(plot) do
		if rayon.first <= count then
			showRayon(rayon.model)
			shown += 1
		else
			hideRayon(rayon.model)
		end
	end
	if countOf[plot] ~= count then
		countOf[plot] = count
		if IS_STUDIO then
			print(`[RayonService] {plot.Name} : {shown} rayon(s) visible(s) pour {count} présentoir(s) débloqué(s)`)
		end
	end
end

local function onAssigned(player: Player, plot: Model)
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
	apply(plot)
end

local function onReleased(player: Player, plot: Model)
	local connection = levelConnections[player]
	if connection then
		connection:Disconnect()
		levelConnections[player] = nil
	end
	apply(plot) -- plus de propriétaire : Rayon_01 seul
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------

function RayonService.Refresh(plot: Model)
	apply(plot)
end

function RayonService.IsShown(plot: Model, rayonIndex: number): boolean?
	for _, rayon in rayonsFor(plot) do
		if rayon.index == rayonIndex then
			return hiddenOf[rayon.model] == nil
		end
	end
	return nil
end

function RayonService.Start()
	for _, plot in PlotService.GetPlots() do
		apply(plot)
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
			if countOf[plot] ~= unlockedFor(plot) then
				apply(plot)
			end
		end
	end
end

return RayonService
