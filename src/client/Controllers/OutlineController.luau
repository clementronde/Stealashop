--!strict
-- OutlineController (a446, client ; liaison L-305 et L-344, Clément 23/11 et 24/11) : contours « façon BD » sur ce qui
-- est interactif, et seulement là. Réglages : Config/Outlines. Interrupteurs : Features.BdOutlines (partout) et
-- Features.BdOutlinesDev (jeu DEV seulement) ; coupé, ce contrôleur ne fait rien et les colis gardent les contours de
-- ShelfBoxController, comme avant. Tout est local : rien n'est envoyé au serveur.
--
-- Réserve fixe. Au départ, Outlines.MaxOutlines Highlight sont créés une fois pour toutes (dossier local du Workspace,
-- OUTLINE_FOLDER), à l'aspect de ReplicatedStorage/Assets/FX/FX_Outline de Clément (OutlineColor, OutlineTransparency,
-- FillColor, FillTransparency, DepthMode) ; FX_OutlineFocus donne l'aspect « visé ». Modèle absent : l'aspect de secours
-- de Config/Outlines et une ligne dans la sortie. Ensuite, on ne change que Adornee, Enabled et ces propriétés d'aspect :
-- aucun Highlight créé ni détruit en jeu. Le nombre de places prises parmi les 255 de Roblox ne dépend donc plus du
-- nombre d'objets de la map (un Highlight éteint garde sa place, L-305 point 1).
--
-- Règle (L-305 point 4). Toutes les RefreshInterval s : les éléments de la liste à MaxDistance studs au plus de la
-- caméra, triés par distance, prennent un Highlight de la réserve, les MaxOutlines plus proches au plus. Un élément qui
-- garde sa place garde son Highlight (Adornee inchangé). L'élément dont une invite est affichée
-- (ProximityPromptService.PromptShown, jusqu'à PromptHidden) prend l'aspect FX_OutlineFocus et passe avant les autres :
-- c'est l'élément de la liste qui contient l'invite, sinon le plus proche de l'invite à FocusMatchDistance studs au plus
-- (l'invite d'un colis est sur le ShelfSlot_xx de son rayon, hors du colis). Sans contour :
--   - un élément caché : sa pièce témoin (PrimaryPart ou première pièce visible) à LocalTransparencyModifier 1 (colis
--     porté par le joueur local ou ouvert, ShelfOpenController et CarryController le cachent ainsi) ;
--   - un colis qui porte RevealId (cinématique d'ouverture, L-316) ou ShelfOpenState (ouverture d'avant) ;
--   - la Window d'un magasin PNJ cassée (attribut Broken de WindowService) ;
--   - un élément qui a déjà son propre Highlight allumé (enfant direct : contour rouge StolenOutline d'un objet volé,
--     L-305 : les contours rouges ne changent pas).
--
-- La liste (L-305 point 3), retrouvée par tags et noms du contrat, jamais par chemin :
--   - hub : ENV_Hub_FreeGift, ENV_Hub_InviteNoob, ENV_Hub_Wheel (Contract/Models : HubFreeGift, HubInviteNoob,
--     HubWheel) ; les comptoirs taggés WeaponShop, AuraShop, RobuxShop, PawnShop (Contract/Models) en entier ; à part,
--     chaque vendeur (Model nommé Config/Vendors.NamePrefix…, Vendor_Pawn…) ;
--   - boutique : PlotDoor d'une parcelle PlayerPlot, les tapis (tag Treadmill), les objets exposés (tag de code
--     DisplayItem), le présentoir à acheter du joueur local (UpgradeController.GetBuyableStand) et les panneaux
--     UpgradeSign posés par UpgradeController ;
--   - couloir : la Window de chaque magasin NPCStore tant qu'elle n'est pas cassée, les colis (tag ShelfBox), les objets
--     sortis (tag ShelfItem) et au sol (tag FloorItem) ;
--   - jamais : CollectPad_xx, classements, arches, décor ; ni rien sous un dossier dont le nom commence par « _ »
--     (dossiers de travail de Clément : _SHOWROOM_CLEMENT, _PREVIEW_…). Le camion (EventTruck) et le coffre
--     (FortuneVault) gardent leur propre contour (OutlineHighlight, rareté du camion, éteint à la casse par le serveur) :
--     ils ne prennent pas de place ici, leurs colis oui.
-- Colis (L-344) : leur Highlight `OutlineHighlight` (Config/ShelfBoxes.OutlineName) est retiré côté client à son
-- arrivée, pour qu'il n'y ait jamais deux contours sur un colis ; ShelfBoxController ne les suit plus (il suit encore
-- ceux du camion, du coffre et du fourgon, comme avant).
-- a451 (Play de fusion101) : un colis se reconnaît au tag ShelfBox que StoreHeistService pose sur chaque colis qu'il
-- crée (makeBoxModel : rayons des magasins, et rayons d'événement du camion et du coffre de la Fortune Tower), et pas
-- au nom : en jeu, le modèle BOX_<Rareté> de Clément est renommé ShelfBox_xx (« jamais BOX_… dans la map »). Depuis
-- la vague 50 (a158), il n'y a plus de colis porté ni posé au sol : ce qui se porte ou tombe est un objet (ITM_).
--
--
-- a473 (L-369, Clément 25/11) : contours toujours visibles (Outlines.PinnedEnabled : Features.BdOutlinesHub ou
-- BdOutlinesHubDev, en plus de BdOutlines ou BdOutlinesDev), à toute distance et hors des MaxOutlines de près :
--   - joueur local dans la zone safe (Shared/SafeZone.ContainsPlayer) : les comptoirs WeaponShop, AuraShop, RobuxShop,
--     PawnShop, ENV_Hub_FreeGift et ENV_Hub_Wheel (pas le noob « invite », pas les vendeurs à part) ; les éléments de
--     SA boutique : PlotDoor, tapis et objets exposés dont l'ancêtre le plus proche qui porte OwnerUserId (l'objet
--     exposé lui-même, sinon la parcelle) est à lui, présentoir à acheter et panneaux UpgradeSign (à lui par nature) ;
--   - partout : l'outil qu'il tient (Tool de son personnage) et l'objet porté sur sa tête (tag CarriedItem dans son
--     personnage, hors d'un Tool : l'outil le couvre déjà). Les objets portés ou lâchés des autres (CarriedItem) suivent
--     la règle de près. Un objet volé garde son contour rouge StolenOutline seul (règle « propre Highlight » ci-dessus).
-- Les boutiques des autres joueurs gardent la règle de près. La réserve compte MaxOutlines + MaxPinned Highlight, tous
-- créés au départ ; au plus MaxPinned contours « toujours » (outil et objet porté, puis stands, puis boutique par
-- distance), au plus MaxOutlines contours de près (blanc compris), jamais plus que la réserve.
--
-- API (client) :
--   OutlineController.GetStats() -> { Enabled, Pool, Candidates, Active, Focused, Pinned, Template }
--       Compteurs, pour un test dans Studio (barre de commande côté client) : Pool = Highlight de la réserve (fixe),
--       Candidates = éléments de la liste suivis, Active = contours allumés, Focused = contours blancs, Pinned = contours
--       « toujours » allumés (a473).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Outlines = require(Config:WaitForChild("Outlines"))

-- Noms et tags hors du contrat (posés par le code ou nom d'un enfant du contrat), mêmes noms que là-bas.
local DISPLAY_TAG = "DisplayItem" -- DisplayService
local SHELF_BOX_TAG = "ShelfBox" -- StoreHeistService.makeBoxModel, sur chaque colis (même nom là-bas)
local SHELF_ITEM_TAG = "ShelfItem" -- StoreHeistService (Shared/ShelfOpenState.ItemTag)
local FLOOR_ITEM_TAG = "FloorItem" -- UnboxService, DisplayService
local WINDOW_NAME = "Window" -- enfant d'un magasin PNJ (Contract/Models.Store)
local BROKEN_ATTRIBUTE = "Broken" -- WindowService, sur la Window
local PLOT_DOOR_NAME = "PlotDoor" -- enfant d'une parcelle (PlotDoorController, DisguiseController)
local SIGN_NAME = "UpgradeSign" -- copies posées par UpgradeController (Contract/UI.Billboards)
local REVEAL_ATTRIBUTE = "RevealId" -- Shared/ShelfOpenState.RevealIdAttribute (a421, L-316)
local OPEN_STATE_ATTRIBUTE = "ShelfOpenState" -- Shared/ShelfOpenState.StateAttribute
local OUTLINE_FOLDER = "BdOutlines" -- dossier local de la réserve, dans le Workspace
local POOL_NAME = "BdOutline_%02d"
local ERROR_INTERVAL = 10 -- une erreur écrite toutes les 10 s au plus (comme ShelfBoxController)

type Look = {
	OutlineColor: Color3,
	OutlineTransparency: number,
	FillColor: Color3,
	FillTransparency: number,
	DepthMode: Enum.HighlightDepthMode,
}

type Candidate = {
	Target: Instance, -- Model ou BasePart (Adornee) ; un Folder n'afficherait rien (L-305 point 1)
	Kind: string,
	Probe: BasePart?, -- pièce témoin : cachée = pas de contour
	Slot: Slot?,
	Distance: number,
	Focus: boolean,
	Pinned: boolean, -- a473 : contour toujours visible (voir l'en-tête)
	Rank: number, -- a473 : ordre des contours « toujours » (0 outil et objet porté, 1 stands, 2 boutique)
}

type Slot = {
	Highlight: Highlight,
	Candidate: Candidate?,
	Focus: boolean?, -- aspect appliqué (nil : jamais appliqué)
}

export type Stats = {
	Enabled: boolean,
	Pool: number,
	Candidates: number,
	Active: number,
	Focused: number,
	Pinned: number, -- a473
	Template: string, -- "Clément" ou "secours"
}

local OutlineController = {}

local started = false
local candidates: { [Instance]: Candidate } = {}
local slots: { Slot } = {}
local shownPrompts: { [ProximityPrompt]: boolean } = {}
local normalLook: Look = Outlines.Fallback.Outline :: any
local focusLook: Look = Outlines.Fallback.Focus :: any
local fromTemplate = false
local sinceRefresh = math.huge
local lastError = -math.huge
local standApi: any = nil
local standTarget: Instance? = nil
-- a473 (L-369) : contours toujours visibles.
local pinnedOn = false
local safeZoneApi: any = nil
local toolTarget: Instance? = nil
local CARRIED_TAG = "CarriedItem" -- CarryService, HeldItemService (Config/HeldItem.CarriedTag)
local OWNER_ATTRIBUTE = "OwnerUserId" -- PlotService (parcelle), DisplayService (objet exposé)
local PINNED_HUB_NAMES: { [string]: boolean } = {} -- ENV_Hub_FreeGift et ENV_Hub_Wheel (Contract/Models)
local OWN_KINDS: { [string]: boolean } = { PlotDoor = true, Treadmill = true, DisplayItem = true }

-- Noms et tags du contrat (Contract/Models), lus au départ.
local BOX_PREFIX = "BOX_" -- nom des modèles de Clément (pas celui d'un colis en jeu : ShelfBox_xx, a451)
local VENDOR_PREFIX = "Vendor_"
local STORE_TAG = "NPCStore"
local PLOT_TAG = "PlayerPlot"
local HUB_NAMES: { [string]: boolean } = {}
local TAGS: { [string]: string } = {} -- tag → genre
local BOX_OUTLINE_NAME = "OutlineHighlight"

local function loadNames()
	local contract = Shared:FindFirstChild("Contract")
	local module = if contract then contract:FindFirstChild("Models") else nil
	local ok, models = pcall(require, module :: any)
	local m: any = if ok and type(models) == "table" then models else {}
	local function tagOf(spec: any, fallback: string): string
		return if type(spec) == "table" and type(spec.Tag) == "string" then spec.Tag else fallback
	end
	BOX_PREFIX = if type(m.Box) == "table" and type(m.Box.Prefix) == "string" then m.Box.Prefix else BOX_PREFIX
	STORE_TAG = tagOf(m.Store, STORE_TAG)
	PLOT_TAG = tagOf(m.Plot, PLOT_TAG)
	for _, key in { "HubFreeGift", "HubInviteNoob", "HubWheel" } do
		local spec = m[key]
		local names = if type(spec) == "table" and type(spec.Names) == "table" then spec.Names else nil
		for _, name in names or {} do
			HUB_NAMES[name] = true
		end
	end
	if next(HUB_NAMES) == nil then
		HUB_NAMES = { ENV_Hub_FreeGift = true, ENV_Hub_InviteNoob = true, ENV_Hub_Wheel = true }
	end
	-- a473 : les deux stands du hub parmi les 6 de L-369 (le noob « invite » n'en est pas).
	for _, key in { "HubFreeGift", "HubWheel" } do
		local spec = m[key]
		local names = if type(spec) == "table" and type(spec.Names) == "table" then spec.Names else nil
		for _, name in names or {} do
			PINNED_HUB_NAMES[name] = true
		end
	end
	if next(PINNED_HUB_NAMES) == nil then
		PINNED_HUB_NAMES = { ENV_Hub_FreeGift = true, ENV_Hub_Wheel = true }
	end
	TAGS[tagOf(m.Treadmill, "Treadmill")] = "Treadmill"
	TAGS[tagOf(m.WeaponShopCounter, "WeaponShop")] = "Stall"
	TAGS[tagOf(m.AuraShopCounter, "AuraShop")] = "Stall"
	TAGS[tagOf(m.RobuxShopCounter, "RobuxShop")] = "Stall"
	TAGS[tagOf(m.PawnShopStall, "PawnShop")] = "Stall"
	TAGS[DISPLAY_TAG] = "DisplayItem"
	TAGS[SHELF_BOX_TAG] = "Box"
	TAGS[SHELF_ITEM_TAG] = "ShelfItem"
	TAGS[FLOOR_ITEM_TAG] = "FloorItem"
	local vendorsModule = Config:FindFirstChild("Vendors")
	local vok, vendors = pcall(require, vendorsModule :: any)
	if vok and type(vendors) == "table" and type((vendors :: any).NamePrefix) == "string" then
		VENDOR_PREFIX = (vendors :: any).NamePrefix
	end
	local boxesModule = Config:FindFirstChild("ShelfBoxes")
	local bok, boxes = pcall(require, boxesModule :: any)
	if bok and type(boxes) == "table" and type((boxes :: any).OutlineName) == "string" then
		BOX_OUTLINE_NAME = (boxes :: any).OutlineName
	end
end

local function startsWith(text: string, prefix: string): boolean
	return string.sub(text, 1, #prefix) == prefix
end

-- Aspect ---------------------------------------------------------------------------------------------

local function readLook(name: string, fallback: Look): (Look, boolean)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local fx = if assets then assets:FindFirstChild(Outlines.FxFolder) else nil
	local found = if fx then fx:FindFirstChild(name, true) else nil
	if found and found:IsA("Highlight") then
		local h = found :: Highlight
		return {
			OutlineColor = h.OutlineColor,
			OutlineTransparency = h.OutlineTransparency,
			FillColor = h.FillColor,
			FillTransparency = h.FillTransparency,
			DepthMode = h.DepthMode,
		},
			true
	end
	print(
		`[OutlineController] {name} absent de ReplicatedStorage.Assets.{Outlines.FxFolder} (ou pas un Highlight) : aspect de secours de Config/Outlines`
	)
	return fallback, false
end

local function applyLook(highlight: Highlight, look: Look)
	if highlight.OutlineColor ~= look.OutlineColor then
		highlight.OutlineColor = look.OutlineColor
	end
	if highlight.OutlineTransparency ~= look.OutlineTransparency then
		highlight.OutlineTransparency = look.OutlineTransparency
	end
	if highlight.FillColor ~= look.FillColor then
		highlight.FillColor = look.FillColor
	end
	if highlight.FillTransparency ~= look.FillTransparency then
		highlight.FillTransparency = look.FillTransparency
	end
	if highlight.DepthMode ~= look.DepthMode then
		highlight.DepthMode = look.DepthMode
	end
end

-- Liste ----------------------------------------------------------------------------------------------

-- Sous un dossier de travail (nom en « _ ») : jamais lu par le jeu.
local function inWorkFolder(inst: Instance): boolean
	local current = inst.Parent
	while current ~= nil and current ~= Workspace and current ~= game do
		if startsWith(current.Name, "_") then
			return true
		end
		current = current.Parent
	end
	return false
end

-- Un ancêtre porte `tag` ; avec `sameName`, aucun ancêtre plus proche ne porte déjà le nom de `inst` (une Window
-- Model qui contient une pièce Window : seul le Model prend le contour).
local function hasTaggedAncestor(inst: Instance, tag: string, sameName: boolean?): boolean
	local current = inst.Parent
	while current ~= nil and current ~= Workspace and current ~= game do
		if CollectionService:HasTag(current, tag) then
			return true
		end
		if sameName and current.Name == inst.Name then
			return false
		end
		current = current.Parent
	end
	return false
end

-- Colis : son OutlineHighlight est retiré en local (L-344 : un seul contour par colis).
local function dropBoxOutline(highlight: Instance)
	task.defer(function()
		if highlight.Parent ~= nil then
			highlight:Destroy()
		end
	end)
end

local function register(target: Instance, kind: string)
	if candidates[target] or not (target:IsA("Model") or target:IsA("BasePart")) then
		return
	end
	if inWorkFolder(target) then
		return
	end
	candidates[target] = {
		Target = target,
		Kind = kind,
		Probe = nil,
		Slot = nil,
		Distance = math.huge,
		Focus = false,
		Pinned = false,
		Rank = 0,
	}
	if kind == "Box" then
		-- a451 : aussi ici, que le tag soit vu avant ou après l'arrivée de son Highlight.
		for _, d in target:GetDescendants() do
			if d.Name == BOX_OUTLINE_NAME and d:IsA("Highlight") then
				dropBoxOutline(d)
			end
		end
	end
end

local function release(candidate: Candidate)
	local slot = candidate.Slot
	candidate.Slot = nil
	if slot then
		slot.Candidate = nil
		if slot.Highlight.Enabled then
			slot.Highlight.Enabled = false
		end
		if candidate.Target.Parent == nil then
			slot.Highlight.Adornee = nil -- élément détruit : ne pas le retenir
		end
	end
end

local function unregister(target: Instance)
	local candidate = candidates[target]
	if candidate then
		local slot = candidate.Slot
		release(candidate)
		if slot and slot.Highlight.Adornee == target then
			-- a451 : plus dans la liste (tag retiré, ou sorti du jeu avant que son Parent soit vidé) : ne pas le retenir
			slot.Highlight.Adornee = nil
		end
		candidates[target] = nil
	end
end

-- Le colis qui contient `inst`, ou nil. a451 : en jeu, par le tag ShelfBox (le colis s'appelle ShelfBox_xx) ; sinon
-- un modèle de Clément resté sous son nom BOX_* (copies d'un dossier de travail, comme _SHOWROOM_CLEMENT/COLIS).
local function boxOf(inst: Instance): Instance?
	local current = inst.Parent
	while current ~= nil and current ~= Workspace and current ~= game do
		if CollectionService:HasTag(current, SHELF_BOX_TAG) then
			return current
		elseif current:IsA("Model") and startsWith(current.Name, BOX_PREFIX) then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function consider(inst: Instance)
	local name = inst.Name
	if inst:IsA("Highlight") then
		if name == BOX_OUTLINE_NAME and boxOf(inst) ~= nil then
			dropBoxOutline(inst)
		end
		return
	end
	if inst:IsA("Model") then
		if HUB_NAMES[name] then
			register(inst, "Hub")
		elseif startsWith(name, VENDOR_PREFIX) then
			register(inst, "Vendor")
		elseif name == SIGN_NAME then
			register(inst, "UpgradeSign")
		elseif name == PLOT_DOOR_NAME and hasTaggedAncestor(inst, PLOT_TAG, true) then
			register(inst, "PlotDoor")
		elseif name == WINDOW_NAME and hasTaggedAncestor(inst, STORE_TAG, true) then
			register(inst, "Window")
		end
	elseif inst:IsA("BasePart") then
		if name == WINDOW_NAME and hasTaggedAncestor(inst, STORE_TAG, true) then
			register(inst, "Window")
		elseif name == PLOT_DOOR_NAME and hasTaggedAncestor(inst, PLOT_TAG, true) then
			register(inst, "PlotDoor")
		end
	end
end

-- Pièce témoin : la pièce elle-même, ou la PrimaryPart visible du modèle, ou sa première pièce visible.
local function probeOf(candidate: Candidate): BasePart?
	local probe = candidate.Probe
	local target = candidate.Target
	if probe and probe.Parent ~= nil and (probe == target or probe:IsDescendantOf(target)) then
		return probe
	end
	probe = nil
	if target:IsA("BasePart") then
		probe = target :: BasePart
	elseif target:IsA("Model") then
		local primary = (target :: Model).PrimaryPart
		if primary and primary.Transparency < 1 then
			probe = primary
		else
			for _, d in target:GetDescendants() do
				if d:IsA("BasePart") and (d :: BasePart).Transparency < 1 then
					probe = d :: BasePart
					break
				end
			end
		end
	end
	candidate.Probe = probe
	return probe
end

local function positionOf(target: Instance): Vector3?
	if target:IsA("BasePart") then
		return (target :: BasePart).Position
	elseif target:IsA("Model") then
		return (target :: Model):GetPivot().Position
	end
	return nil
end

-- Sans contour (voir l'en-tête).
local function isHidden(candidate: Candidate): boolean
	local target = candidate.Target
	if candidate.Kind == "Box" then
		if target:GetAttribute(REVEAL_ATTRIBUTE) ~= nil or target:GetAttribute(OPEN_STATE_ATTRIBUTE) ~= nil then
			return true
		end
	elseif candidate.Kind == "Window" then
		if target:GetAttribute(BROKEN_ATTRIBUTE) == true then
			return true
		end
	elseif candidate.Kind == "Carried" then
		-- a473 : objet tenu en main sous antivol (HeldItemService, dans le Tool) : le contour de l'outil le couvre.
		local current = target.Parent
		while current ~= nil and current ~= Workspace and current ~= game do
			if current:IsA("Tool") then
				return true
			end
			current = current.Parent
		end
	end
	local own = target:FindFirstChildOfClass("Highlight")
	if own and own.Enabled then
		return true -- son propre contour (rouge du vol…) reste seul
	end
	local probe = probeOf(candidate)
	if probe == nil then
		return true -- aucune pièce visible
	end
	return probe.LocalTransparencyModifier >= 1 or probe.Transparency >= 1
end

-- Invites -----------------------------------------------------------------------------------------------

local function promptPosition(prompt: ProximityPrompt): Vector3?
	local parent = prompt.Parent
	if parent == nil then
		return nil
	elseif parent:IsA("Attachment") then
		return (parent :: Attachment).WorldPosition
	end
	return positionOf(parent)
end

-- L'élément de la liste visé par une invite affichée, ou nil.
local function resolve(prompt: ProximityPrompt): Candidate?
	local current = prompt.Parent
	while current ~= nil and current ~= Workspace and current ~= game do
		local found = candidates[current]
		if found then
			return found
		end
		current = current.Parent
	end
	local at = promptPosition(prompt)
	if at == nil then
		return nil
	end
	local best: Candidate? = nil
	local bestDistance = Outlines.FocusMatchDistance
	for target, candidate in candidates do
		if target.Parent == nil then
			continue
		end
		local position = positionOf(target)
		if position then
			local distance = (position - at).Magnitude
			if distance <= bestDistance then
				best, bestDistance = candidate, distance
			end
		end
	end
	return best
end

-- Tri ----------------------------------------------------------------------------------------------

-- Blanc d'abord, puis les contours « toujours » (a473, par Rank), puis par distance.
local function sortByFocusThenDistance(a: Candidate, b: Candidate): boolean
	if a.Focus ~= b.Focus then
		return a.Focus
	end
	if a.Pinned ~= b.Pinned then
		return a.Pinned
	end
	if a.Pinned and a.Rank ~= b.Rank then
		return a.Rank < b.Rank
	end
	return a.Distance < b.Distance
end

-- a473 : l'outil tenu par le joueur local (Tool de son personnage), suivi comme le présentoir à acheter. Un Tool est un
-- Model chez Roblox (BackpackItem) : il prend le contour en entier.
local function refreshTool()
	local player = Players.LocalPlayer
	local character = if player then player.Character else nil
	local target: Instance? = if character then character:FindFirstChildOfClass("Tool") else nil
	if target ~= toolTarget then
		local old = toolTarget
		if old and candidates[old] and candidates[old].Kind == "Tool" then
			unregister(old)
		end
		toolTarget = target
		if target then
			register(target, "Tool")
		end
	end
end

-- a473 : la boutique de l'élément est-elle au joueur local ? L'ancêtre le plus proche (lui compris) qui porte
-- OwnerUserId décide (objet exposé, sinon sa parcelle).
local function ownedByMe(inst: Instance, userId: number): boolean
	local current: Instance? = inst
	while current ~= nil and current ~= Workspace and current ~= game do
		local owner = current:GetAttribute(OWNER_ATTRIBUTE)
		if type(owner) == "number" then
			return owner == userId and userId ~= 0
		end
		current = current.Parent
	end
	return false
end

-- a473 : rang du contour « toujours » de `candidate`, ou nil s'il suit la règle de près.
local function pinnedRank(candidate: Candidate, character: Instance?, inSafe: boolean, userId: number): number?
	local kind = candidate.Kind
	local target = candidate.Target
	if kind == "Tool" then
		return 0
	elseif kind == "Carried" then
		return if character ~= nil and target:IsDescendantOf(character) then 0 else nil
	elseif not inSafe then
		return nil
	elseif kind == "Stall" then
		return 1
	elseif kind == "Hub" then
		return if PINNED_HUB_NAMES[target.Name] then 1 else nil
	elseif kind == "Stand" or kind == "UpgradeSign" then
		return 2
	elseif OWN_KINDS[kind] then
		return if ownedByMe(target, userId) then 2 else nil
	end
	return nil
end

local function localInSafeZone(): boolean
	local api = safeZoneApi
	local player = Players.LocalPlayer
	if api == nil or player == nil then
		return false
	end
	local ok, inside = pcall(api.ContainsPlayer, player)
	return ok and inside == true
end

local function refreshStand()
	local api = standApi
	if api == nil then
		return
	end
	local ok, stand = pcall(api.GetBuyableStand)
	local target: Instance? = if ok and typeof(stand) == "Instance" then stand else nil
	if target ~= standTarget then
		local old = standTarget
		if old and candidates[old] and candidates[old].Kind == "Stand" then
			unregister(old)
		end
		standTarget = target
		if target then
			register(target, "Stand")
		end
	end
end

local function refresh(cameraPosition: Vector3)
	refreshStand()
	local character: Instance? = nil
	local inSafe = false
	local userId = 0
	if pinnedOn then
		refreshTool()
		local player = Players.LocalPlayer
		character = if player then player.Character else nil
		userId = if player and type(player.UserId) == "number" then player.UserId else 0
		inSafe = localInSafeZone()
	end
	for _, candidate in candidates do
		candidate.Focus = false
		candidate.Pinned = false
	end
	for prompt in shownPrompts do
		if prompt.Parent == nil then
			shownPrompts[prompt] = nil
			continue
		end
		local candidate = resolve(prompt)
		if candidate then
			candidate.Focus = true
		end
	end
	local list: { Candidate } = {}
	local maxDistance = Outlines.MaxDistance
	for target, candidate in candidates do
		if target.Parent == nil then
			unregister(target)
			continue
		end
		local wanted = false
		if target:IsDescendantOf(Workspace) then
			local position = positionOf(target)
			local distance = if position then (position - cameraPosition).Magnitude else math.huge
			candidate.Distance = distance
			local rank = if pinnedOn then pinnedRank(candidate, character, inSafe, userId) else nil
			if rank ~= nil then
				candidate.Pinned = true
				candidate.Rank = rank
			end
			wanted = (candidate.Focus or candidate.Pinned or distance <= maxDistance) and not isHidden(candidate)
		end
		if wanted then
			table.insert(list, candidate)
		elseif candidate.Slot then
			release(candidate)
		end
	end
	table.sort(list, sortByFocusThenDistance)
	-- a473 : au plus MaxPinned contours « toujours » et MaxOutlines de près (blanc compris) ; un élément « toujours »
	-- au-delà de MaxPinned suit la règle de près. Jamais plus que la réserve.
	local maxPinned = if pinnedOn then math.max(0, math.floor(Outlines.MaxPinned)) else 0
	local maxNear = math.max(0, math.floor(Outlines.MaxOutlines))
	local pinnedUsed, nearUsed = 0, 0
	local kept: { Candidate } = {}
	for _, candidate in list do
		local keep = false
		if #kept < #slots then
			if candidate.Pinned and pinnedUsed < maxPinned then
				pinnedUsed += 1
				keep = true
			elseif (candidate.Focus or candidate.Distance <= maxDistance) and nearUsed < maxNear then
				nearUsed += 1
				candidate.Pinned = false -- compté de près
				keep = true
			end
		end
		if keep then
			table.insert(kept, candidate)
		else
			candidate.Pinned = false
			if candidate.Slot then
				release(candidate)
			end
		end
	end
	list = kept
	local limit = #list
	-- Places libres de la réserve, puis les éléments retenus sans place la prennent.
	local free: { Slot } = {}
	for _, slot in slots do
		if slot.Candidate == nil then
			table.insert(free, slot)
		end
	end
	for index = 1, limit do
		local candidate = list[index]
		local slot = candidate.Slot
		if slot == nil then
			slot = table.remove(free)
			if slot == nil then
				break
			end
			candidate.Slot = slot
			slot.Candidate = candidate
		end
		local current = slot :: Slot
		local highlight = current.Highlight
		if highlight.Adornee ~= candidate.Target then
			highlight.Adornee = candidate.Target
		end
		if current.Focus ~= candidate.Focus then
			current.Focus = candidate.Focus
			applyLook(highlight, if candidate.Focus then focusLook else normalLook)
		end
		if not highlight.Enabled then
			highlight.Enabled = true
		end
	end
end

local function step(deltaTime: number)
	sinceRefresh += deltaTime
	if sinceRefresh < Outlines.RefreshInterval then
		return
	end
	sinceRefresh = 0
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	refresh(camera.CFrame.Position)
end

-- API -----------------------------------------------------------------------------------------------

function OutlineController.GetStats(): Stats
	local stats: Stats = {
		Enabled = started,
		Pool = #slots,
		Candidates = 0,
		Active = 0,
		Focused = 0,
		Pinned = 0,
		Template = if fromTemplate then "Clément" else "secours",
	}
	for _ in candidates do
		stats.Candidates += 1
	end
	for _, slot in slots do
		if slot.Highlight.Enabled then
			stats.Active += 1
			if slot.Focus then
				stats.Focused += 1
			end
			local candidate = slot.Candidate
			if candidate and candidate.Pinned then
				stats.Pinned += 1
			end
		end
	end
	return stats
end

function OutlineController.Start()
	if Outlines.Enabled ~= true then
		return -- Features.BdOutlines et BdOutlinesDev : coupé, rien ne change
	end
	started = true
	loadNames()
	local okNormal, okFocus
	normalLook, okNormal = readLook(Outlines.Template, Outlines.Fallback.Outline :: any)
	focusLook, okFocus = readLook(Outlines.FocusTemplate, Outlines.Fallback.Focus :: any)
	fromTemplate = okNormal and okFocus

	-- a473 (L-369) : contours toujours visibles ; la zone safe par Shared/SafeZone (absent : jamais dans la zone safe).
	pinnedOn = Outlines.PinnedEnabled == true
	if pinnedOn then
		local module = Shared:FindFirstChild("SafeZone")
		if module and module:IsA("ModuleScript") then
			local ok, result = pcall(require, module)
			if ok and type(result) == "table" and type((result :: any).ContainsPlayer) == "function" then
				safeZoneApi = result
			end
		end
		if safeZoneApi == nil then
			print("[OutlineController] Shared/SafeZone introuvable : stands et boutique sans contour « toujours »")
		end
		TAGS[CARRIED_TAG] = "Carried"
	end

	-- Réserve fixe : créée une fois, jamais agrandie ni détruite (a473 : MaxPinned places de plus).
	local folder = Instance.new("Folder")
	folder.Name = OUTLINE_FOLDER
	local poolSize = math.max(0, math.floor(Outlines.MaxOutlines))
		+ (if pinnedOn then math.max(0, math.floor(Outlines.MaxPinned)) else 0)
	for index = 1, poolSize do
		local highlight = Instance.new("Highlight")
		highlight.Name = string.format(POOL_NAME, index)
		highlight.Enabled = false
		applyLook(highlight, normalLook)
		highlight.Parent = folder
		table.insert(slots, { Highlight = highlight, Candidate = nil, Focus = false })
	end
	folder.Parent = Workspace

	local module = script.Parent:FindFirstChild("UpgradeController")
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok and type(result) == "table" and type((result :: any).GetBuyableStand) == "function" then
			standApi = result
		end
	end

	for tag, kind in TAGS do
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(inst: Instance)
			register(inst, kind)
		end)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(function(inst: Instance)
			local candidate = candidates[inst]
			if candidate and candidate.Kind == kind then
				unregister(inst)
			end
		end)
		for _, inst in CollectionService:GetTagged(tag) do
			register(inst, kind)
		end
	end
	Workspace.DescendantAdded:Connect(consider)
	for _, descendant in Workspace:GetDescendants() do
		consider(descendant)
	end

	local okService, service = pcall(function(): any
		return game:GetService("ProximityPromptService")
	end)
	if okService and service then
		local ProximityPromptService = service :: ProximityPromptService
		ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
			shownPrompts[prompt] = true
			sinceRefresh = math.huge -- blanc tout de suite, à l'image suivante
		end)
		ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
			shownPrompts[prompt] = nil
			sinceRefresh = math.huge
		end)
	end

	if RunService:IsStudio() then
		local stats = OutlineController.GetStats()
		print(
			`[OutlineController] contours « façon BD » : réserve de {stats.Pool} Highlight, {stats.Candidates} élément(s) suivi(s), portée {Outlines.MaxDistance} studs, aspect {stats.Template}`
		)
	end
	local function onError(err: any)
		if os.clock() - lastError >= ERROR_INTERVAL then
			lastError = os.clock()
			warn(`[OutlineController] {err}`)
		end
	end
	RunService.Heartbeat:Connect(function(deltaTime: number)
		xpcall(step, onError, deltaTime)
	end)
end

return OutlineController
