--!strict
-- ShopWallsService (vague 29, liaison L-105 point 3 et L-106 point 2) : le mur visible de la boutique selon le
-- niveau de sa tuile Walls (arbre de compétences), et depuis le 2026-11-13 tous les visuels de la boutique liés à
-- une compétence (caméras…), cachés jusqu'à son déblocage (paragraphe « Autres compétences »). Les PV de la
-- porte, eux, sont dans WindowService (GetPlotHPMultiplier, remplacé par SkillTreeService : Glass × Walls).
--
-- Niveau : chaque parcelle taggée `PlayerPlot` (dans le Workspace) reçoit l'attribut `WallsLevel` (nombre) =
-- l'attribut `Skill_Walls` de son propriétaire (posé par SkillTreeService ; 0 s'il manque), revu quand
-- `OwnerUserId` change (PlotService) ou que `Skill_Walls` change (achat, chargement du profil). Parcelle libre :
-- 0. Propriétaire absent du serveur (ex. bot joueur) : l'attribut n'est pas touché, celui qui gère la parcelle
-- peut le poser lui-même.
--
-- Visuel (Clément livre un mur par niveau ; rien n'est encore posé) : toute pièce de la parcelle (BasePart, Model
-- ou Folder, avec ses descendants) qui porte l'attribut `ShowFromWalls` = n et/ou `HideFromWalls` = m est montrée
-- si n ≤ WallsLevel < m (attribut absent : pas de borne), cachée sinon. Un mur qui remplace le précédent :
-- Walls_1 { HideFromWalls = 2 }, Walls_2 { ShowFromWalls = 2, HideFromWalls = 3 }… ; un renfort qui s'ajoute :
-- { ShowFromWalls = 2 } seul. Cacher, comme ShopStageService : BasePart Transparency = 1, CanCollide, CanTouch
-- et CanQuery coupés ; Decal et Texture Transparency = 1 ; GUI, lumières et effets Enabled = false. Les
-- valeurs d'origine sont rendues quand la pièce revient. Pièces revues quand le niveau change et quand une
-- pièce arrive (copies Stage_j de ShopStageService comprises). À ne pas combiner avec `HideFromStage` sur la
-- même pièce. Aucune pièce : rien à faire, aucun message.
--
-- Autres compétences (règle de Cantin du 2026-11-13 : un visuel de compétence n'apparaît qu'à son déblocage,
-- quel que soit le niveau de la boutique) : une pièce reconnue par Config/SkillTree.PlotVisuals (son nom, ex.
-- Stage_5/Cameras) ou par son attribut `ShowFromSkill` ("Cameras", "Cameras 2") est montrée si le niveau de la
-- compétence ≥ le niveau demandé (1 par défaut), cachée sinon, de la même façon que les murs. Niveau : l'attribut
-- `Skill_<Id>` du propriétaire ; sans propriétaire joueur sur le serveur (parcelle libre, bot), l'attribut
-- `Skill_<Id>` de la parcelle (0 s'il manque). Revu quand le propriétaire change, quand un de ces attributs
-- change et quand une pièce arrive. Id inconnu dans `ShowFromSkill` : une ligne, la pièce n'est pas touchée.
--
-- API (serveur) :
--   ShopWallsService.GetLevel(plot) -> number   WallsLevel de la parcelle (0 s'il manque)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SkillTree = require(ReplicatedStorage.Shared.Config.SkillTree)

local PLOT_TAG = "PlayerPlot"
local OWNER_ATTRIBUTE = "OwnerUserId" -- posé par PlotService
local SKILL_ID = "Walls"
local SKILL_ATTRIBUTE = SkillTree.AttributePrefix .. SKILL_ID
local LEVEL_ATTRIBUTE = SkillTree.WallsLevelAttribute
local SHOW_FROM = SkillTree.ShowFromWalls
local HIDE_FROM = SkillTree.HideFromWalls
local SHOW_FROM_SKILL = SkillTree.ShowFromSkill
local SKILL_PREFIX = SkillTree.AttributePrefix

-- Propriétés changées pour cacher, par famille de classes (les mêmes que ShopStageService).
local PART_HIDDEN: { [string]: any } = { Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false }
local DECAL_HIDDEN: { [string]: any } = { Transparency = 1 }
local ENABLED_HIDDEN: { [string]: any } = { Enabled = false }
local ENABLED_CLASSES = { "SurfaceGui", "BillboardGui", "Light", "ParticleEmitter", "Beam", "Trail", "Fire", "Smoke", "Sparkles", "Highlight" }

type Saved = { [Instance]: { [string]: any } }

local ShopWallsService = {}

local hidden: { [Instance]: Saved } = {} -- pièce cachée -> valeurs d'origine (elle et ses descendants)
local plotConnections: { [Instance]: { RBXScriptConnection } } = {}
local warned: { [string]: boolean } = {}

local function hiddenProps(instance: Instance): { [string]: any }?
	if instance:IsA("BasePart") then
		return PART_HIDDEN
	end
	if instance:IsA("Decal") or instance:IsA("Texture") then
		return DECAL_HIDDEN
	end
	for _, class in ENABLED_CLASSES do
		if instance:IsA(class) then
			return ENABLED_HIDDEN
		end
	end
	return nil
end

local function hideOne(instance: Instance, saved: Saved)
	local props = hiddenProps(instance)
	if props == nil then
		return
	end
	local original: { [string]: any } = {}
	for prop, value in props do
		original[prop] = (instance :: any)[prop]
		;(instance :: any)[prop] = value
	end
	saved[instance] = original
end

local function setVisible(piece: Instance, visible: boolean)
	local saved = hidden[piece]
	if visible then
		if saved == nil then
			return
		end
		hidden[piece] = nil
		for instance, original in saved do
			if instance.Parent ~= nil then
				for prop, value in original do
					(instance :: any)[prop] = value
				end
			end
		end
		return
	end
	if saved ~= nil then
		return -- déjà cachée
	end
	local newSaved: Saved = {}
	hideOne(piece, newSaved)
	for _, descendant in piece:GetDescendants() do
		hideOne(descendant, newSaved)
	end
	hidden[piece] = newSaved
end

local function isWallPiece(instance: Instance): boolean
	return instance:GetAttribute(SHOW_FROM) ~= nil or instance:GetAttribute(HIDE_FROM) ~= nil
end

local function bound(instance: Instance, name: string, default: number): number
	local value = instance:GetAttribute(name)
	return if type(value) == "number" and value == value then value else default
end

function ShopWallsService.GetLevel(plot: Instance): number
	local value = plot:GetAttribute(LEVEL_ATTRIBUTE)
	return if type(value) == "number" and value == value then value else 0
end

-- Règle « compétence » d'une pièce (voir l'en-tête) : attribut ShowFromSkill, sinon son nom dans PlotVisuals.
local function skillRuleOf(instance: Instance): SkillTree.PlotVisual?
	local value = instance:GetAttribute(SHOW_FROM_SKILL)
	if value == nil then
		return SkillTree.PlotVisuals[instance.Name]
	end
	local id, digits = string.match(if type(value) == "string" then value else "", "^%s*(%w+)%s*(%d*)%s*$")
	local skill = if id then SkillTree.ById[id] else nil
	if skill == nil then
		local key = instance:GetFullName()
		if not warned[key] then
			warned[key] = true
			warn(`[ShopWallsService] {key} : {SHOW_FROM_SKILL} = « {tostring(value)} » ne nomme aucune compétence de Config/SkillTree : pièce laissée telle quelle`)
		end
		return nil
	end
	return { Id = skill.Id, Level = if digits and digits ~= "" then tonumber(digits) :: number else 1 }
end

-- Niveau de la compétence `id` pour la parcelle : Walls = WallsLevel ; les autres, l'attribut Skill_<Id> du
-- propriétaire, ou de la parcelle sans propriétaire joueur sur le serveur (0 s'il manque).
local function skillLevel(plot: Instance, id: string): number
	if id == SKILL_ID then
		return ShopWallsService.GetLevel(plot)
	end
	local ownerId = plot:GetAttribute(OWNER_ATTRIBUTE)
	local owner = if type(ownerId) == "number" and ownerId ~= 0 then Players:GetPlayerByUserId(ownerId) else nil
	local source: Instance = if owner then owner else plot
	local value = source:GetAttribute(SKILL_PREFIX .. id)
	return if type(value) == "number" and value == value then value else 0
end

local function applyPiece(plot: Instance, piece: Instance)
	if isWallPiece(piece) then
		local level = ShopWallsService.GetLevel(plot)
		setVisible(piece, level >= bound(piece, SHOW_FROM, -math.huge) and level < bound(piece, HIDE_FROM, math.huge))
		return
	end
	local rule = skillRuleOf(piece)
	if rule then
		setVisible(piece, skillLevel(plot, rule.Id) >= rule.Level)
	end
end

local function applyAll(plot: Instance)
	for _, descendant in plot:GetDescendants() do
		applyPiece(plot, descendant)
	end
end

-- WallsLevel de la parcelle d'après son propriétaire (voir l'en-tête).
local function refreshLevel(plot: Instance)
	local ownerId = plot:GetAttribute(OWNER_ATTRIBUTE)
	local level: number
	if type(ownerId) ~= "number" or ownerId == 0 then
		level = 0
	else
		local owner = Players:GetPlayerByUserId(ownerId)
		if owner == nil then
			return -- pas un joueur du serveur (bot) : on laisse l'attribut à celui qui gère la parcelle
		end
		local skill = owner:GetAttribute(SKILL_ATTRIBUTE)
		level = if type(skill) == "number" and skill == skill then skill else 0
	end
	if plot:GetAttribute(LEVEL_ATTRIBUTE) ~= level then
		plot:SetAttribute(LEVEL_ATTRIBUTE, level)
	end
end

local function untrack(plot: Instance)
	local connections = plotConnections[plot]
	if connections == nil then
		return
	end
	plotConnections[plot] = nil
	for _, connection in connections do
		connection:Disconnect()
	end
end

local function track(plot: Instance)
	if plotConnections[plot] or not plot:IsDescendantOf(Workspace) then
		return
	end
	local connections = {
		plot:GetAttributeChangedSignal(OWNER_ATTRIBUTE):Connect(function()
			refreshLevel(plot)
			applyAll(plot) -- les autres compétences suivent le nouveau propriétaire
		end),
		plot:GetAttributeChangedSignal(LEVEL_ATTRIBUTE):Connect(function()
			applyAll(plot)
		end),
		plot.DescendantAdded:Connect(function(descendant: Instance)
			applyPiece(plot, descendant)
		end),
	}
	for _, skill in SkillTree.List do
		if skill.Id ~= SKILL_ID then -- Skill_<Id> posé à la main sur la parcelle (bot, Studio)
			table.insert(
				connections,
				plot:GetAttributeChangedSignal(SKILL_PREFIX .. skill.Id):Connect(function()
					applyAll(plot)
				end)
			)
		end
	end
	plotConnections[plot] = connections
	refreshLevel(plot)
	applyAll(plot)
end

-- Parcelles suivies dont `player` est le propriétaire : Walls revoit WallsLevel, les autres revoient les pièces.
local function refreshOwnedBy(player: Player, id: string)
	for _, plot in CollectionService:GetTagged(PLOT_TAG) do
		if plotConnections[plot] and plot:GetAttribute(OWNER_ATTRIBUTE) == player.UserId then
			if id == SKILL_ID then
				refreshLevel(plot)
			else
				applyAll(plot)
			end
		end
	end
end

local function watchPlayer(player: Player)
	for _, skill in SkillTree.List do
		player:GetAttributeChangedSignal(SKILL_PREFIX .. skill.Id):Connect(function()
			refreshOwnedBy(player, skill.Id)
		end)
	end
	refreshOwnedBy(player, SKILL_ID)
end

function ShopWallsService.Init()
	CollectionService:GetInstanceAddedSignal(PLOT_TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(PLOT_TAG):Connect(untrack)
	for _, plot in CollectionService:GetTagged(PLOT_TAG) do
		track(plot)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
end

return ShopWallsService
