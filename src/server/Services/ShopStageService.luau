--!strict
-- ShopStageService (DEV-020, MOD-015 ; liaison L-096 point 1) : la boutique du joueur grandit avec ses
-- rayons (règle de Clément vérifiée le 2026-11-11, notes/retours-clement-poursuite-gains-boutique.md,
-- « La boutique grandit avec les rayons »).
--
-- Niveau de la boutique = k, nombre de rayons visibles (1 à 5) : c'est RayonService qui le calcule (un rayon
-- apparaît dès que son premier présentoir est débloqué) et qui appelle ShopStageService.Apply(plot, k) AVANT de
-- montrer ses rayons (les contours RayonSpot_0n arrivent avec Stage_2). Ce service n'écoute rien lui-même :
-- attribution, achat de présentoirs, contrôle d'une seconde et départ du joueur passent tous par RayonService.
--
-- Ce que fait Apply (côté serveur, répliqué à tous ; les clients reçoivent les copies par le streaming) :
--   1. retire de la boutique chaque `Stage_j` avec j > k (j ≥ 2 ; `Stage_1` n'est jamais touché) ;
--   2. pour j de 2 à k, si la boutique n'a pas d'enfant `Stage_j`, copie
--      ReplicatedStorage/Assets/Plots/PLOT_Shop/Stage_j, sans aucun script (Script, LocalScript, ModuleScript
--      retirés de la copie), posée comme les RayonVisuals : plot:GetPivot() * gabarit:GetPivot():Inverse() *
--      copie:GetPivot(), et rangée dans la boutique sous le nom `Stage_j`. Le gabarit n'est jamais modifié ;
--   3. dans la copie, les pièces et les lumières qui ont l'attribut `Accent` prennent la couleur de l'attribut
--      `AccentColor` (Color3) de la boutique ; sans AccentColor, elles gardent la couleur du gabarit (une ligne) ;
--   4. dans toute la boutique (copies, Stage_1 et PlotBarrier compris), tout ce qui porte `HideFromStage` ≤ k
--      est caché, avec ses descendants ; le reste est rendu. Cacher (comme RayonService) : BasePart
--      Transparency = 1, CanCollide, CanTouch et CanQuery coupés ; Decal et Texture Transparency = 1 ;
--      SurfaceGui, BillboardGui, lumières, ParticleEmitter, Beam, Trail, Fire, Smoke, Sparkles, Highlight
--      Enabled = false. Les valeurs d'origine sont mémorisées et rendues telles quelles quand k redescend
--      (parcelle libérée : retour au niveau 1 ; renaissance en Partie 2) ;
--   5. pose sur la boutique l'attribut `StageLevel` = k (nom V0 proposé, absent du doc) : UpgradeController
--      (client) y lit où planter le panneau du niveau suivant (StageUpgradePoint, puis StageUpgradePoint_2).
-- `Bounds` et `DepositZone` ne changent pas (grande taille dès le niveau 1, à décider avec Clément).
--
-- API (serveur) :
--   ShopStageService.Apply(plot, k) -> number
--       Met la boutique au niveau k (ramené à 1 au moins) ; renvoie le niveau posé. Sans yield.
--   ShopStageService.GetLevel(plot) -> number
--       Niveau posé par le dernier Apply (1 si aucun).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Noms de Clément (L-096, plot_shop_builder) ; StageLevel : V0 proposé, absent du doc.
local TEMPLATE_NAME = "PLOT_Shop"
local STAGE_PATTERN = "^Stage_(%d+)$"
local ACCENT = "Accent"
local ACCENT_COLOR = "AccentColor"
local HIDE_FROM = "HideFromStage"
local LEVEL_ATTRIBUTE = "StageLevel"

-- Propriétés changées pour cacher, par famille de classes (les mêmes que RayonService).
local PART_HIDDEN: { [string]: any } = { Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false }
local DECAL_HIDDEN: { [string]: any } = { Transparency = 1 }
local ENABLED_HIDDEN: { [string]: any } = { Enabled = false }
local ENABLED_CLASSES = { "SurfaceGui", "BillboardGui", "Light", "ParticleEmitter", "Beam", "Trail", "Fire", "Smoke", "Sparkles", "Highlight" }

type Saved = { [Instance]: { [string]: any } }
type PlotState = { level: number, saved: Saved }

local IS_STUDIO = RunService:IsStudio()

local ShopStageService = {}
ShopStageService.Priority = 119 -- appelé par RayonService (120) ; rien à démarrer

local states: { [Model]: PlotState } = {}
local warned: { [string]: boolean } = {}

local function warnOnce(key: string, message: string)
	if not warned[key] then
		warned[key] = true
		warn(`[ShopStageService] {message}`)
	end
end

-- Gabarit Assets/Plots/PLOT_Shop, ou nil (une ligne) : la boutique garde alors ses niveaux actuels.
local function templateOf(): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local plots = if assets then assets:FindFirstChild("Plots") else nil
	local found = if plots then plots:FindFirstChild(TEMPLATE_NAME) else nil
	if found == nil or not found:IsA("Model") then
		warnOnce(TEMPLATE_NAME, `{TEMPLATE_NAME} absent de ReplicatedStorage.Assets.Plots : la boutique ne grandit pas (L-096)`)
		return nil
	end
	return found :: Model
end

-- Enfants `Stage_j` d'un modèle, par numéro.
local function stagesOf(model: Instance): { [number]: Instance }
	local out: { [number]: Instance } = {}
	for _, child in model:GetChildren() do
		local digits = string.match(child.Name, STAGE_PATTERN)
		if digits then
			out[tonumber(digits) :: number] = child
		end
	end
	return out
end

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

local function hideOne(inst: Instance, saved: Saved)
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

local function restoreOne(inst: Instance, before: { [string]: any })
	local target = inst :: any
	for property, value in before do
		target[property] = value
	end
end

-- Copie de `source` (Stage_j du gabarit), recolorée, sans script, posée dans la boutique.
local function placeCopy(plot: Model, template: Model, source: Instance)
	local copy = source:Clone()
	local all = copy:GetDescendants()
	table.insert(all, copy)
	local color = plot:GetAttribute(ACCENT_COLOR)
	if typeof(color) ~= "Color3" then
		warnOnce(plot:GetFullName() .. ACCENT_COLOR, `{plot:GetFullName()} : pas d'attribut {ACCENT_COLOR} (Color3) : les copies gardent la couleur du gabarit`)
	end
	local transform = plot:GetPivot() * template:GetPivot():Inverse()
	for _, inst in all do
		if inst:IsA("LuaSourceContainer") then
			inst:Destroy() -- aucun script dans les copies (CLAUDE.md)
		elseif typeof(color) == "Color3" and inst:GetAttribute(ACCENT) and (inst:IsA("BasePart") or inst:IsA("Light")) then
			(inst :: any).Color = color
		end
	end
	if copy:IsA("Model") then
		local model = copy :: Model
		model:PivotTo(transform * model:GetPivot())
	else
		for _, inst in copy:GetDescendants() do -- Stage_j rangé dans un Folder : chaque pièce suit
			if inst:IsA("BasePart") then
				local part = inst :: BasePart
				part.CFrame = transform * part.CFrame
			end
		end
	end
	copy.Name = source.Name
	copy.Parent = plot
end

-- HideFromStage ≤ k caché (avec les descendants), le reste rendu à ses valeurs d'origine.
local function applyHide(plot: Model, state: PlotState, k: number)
	local wanted: { [Instance]: boolean } = {}
	for _, inst in plot:GetDescendants() do
		local from = inst:GetAttribute(HIDE_FROM)
		if type(from) == "number" and from <= k and not wanted[inst] then
			wanted[inst] = true
			for _, sub in inst:GetDescendants() do
				wanted[sub] = true
			end
		end
	end
	for inst, before in state.saved do
		if not wanted[inst] then
			state.saved[inst] = nil
			if inst:IsDescendantOf(plot) then
				restoreOne(inst, before)
			end
		end
	end
	for inst in wanted do
		hideOne(inst, state.saved)
	end
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------

function ShopStageService.Apply(plot: Model, level: number): number
	local k = if level == level then math.max(1, math.floor(level)) else 1
	local state = states[plot]
	if state == nil then
		state = { level = 1, saved = {} }
		states[plot] = state
	end
	local current = state :: PlotState
	for j, stage in stagesOf(plot) do
		if j >= 2 and j > k then
			stage:Destroy()
		end
	end
	local template = templateOf()
	if template then
		for j, source in stagesOf(template) do
			if j >= 2 and j <= k and plot:FindFirstChild(source.Name) == nil then
				placeCopy(plot, template, source)
			end
		end
	end
	applyHide(plot, current, k)
	if current.level ~= k and IS_STUDIO then
		print(`[ShopStageService] {plot.Name} : boutique niveau {current.level} → {k}`)
	end
	current.level = k
	plot:SetAttribute(LEVEL_ATTRIBUTE, k)
	return k
end

function ShopStageService.GetLevel(plot: Model): number
	local state = states[plot]
	return if state then state.level else 1
end

return ShopStageService
