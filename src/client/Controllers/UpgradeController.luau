--!strict
-- UpgradeController (DEV-033, client ; liaison L-082 point 1) : achat des améliorations de base sur
-- sa propre parcelle (Partie 1, sections 5.1, 5.8, 7.5 et 9.4).
--
-- Améliorations vendues (Config/Upgrades) : tapis (Treadmill), banc (Bench), présentoirs
-- (DisplaySlots). Chacune s'achète par BuyItem(Id) ; le serveur (ShopService) revérifie tout (argent,
-- niveau, prix) et prévient le joueur (Notify). Le niveau est lu dans les attributs TreadmillLevel,
-- BenchLevel et DisplaySlotsLevel du Player (ShopService), le prix est Formulas.UpgradeCost(Id,
-- niveau) : pour l'affichage seulement.
--
-- Panneaux plantés (L-082, modèle UpgradeSign de Clément dans ReplicatedStorage/Assets/UI) :
--   - posés ici, côté client, sur chaque parcelle qui a un propriétaire présent : tous les joueurs
--     voient les panneaux d'une boutique (niveau et prix de son propriétaire), seul le propriétaire
--     peut acheter. Copie rangée dans un dossier local du Workspace (SIGN_FOLDER), hors des
--     parcelles : le streaming d'une parcelle ne la détruit pas, elle suit son point ;
--   - points de pose (Attachment) : UpgradePoint du tapis (tag Treadmill) et du banc (tag Bench), à
--     défaut un point créé ici au-dessus de la machine ; DisplayUpgradePoint de la parcelle pour les
--     présentoirs (le plus proche du prochain présentoir verrouillé s'il y en a plusieurs), à défaut
--     le prochain DisplaySlot_xx verrouillé (n° départ + niveau + 1, Balance.Display, comme côté
--     serveur). StageUpgradePoint : rien n'y est posé, aucune amélioration « Stage » n'existe ;
--   - pose : le bas de la boîte du panneau au point, la face de Board (SurfaceGui Face = Front, donc
--     son LookVector) tournée comme le LookVector de l'Attachment, mis à l'horizontale. Pour tourner
--     un panneau, Clément tourne son point. Aucune taille ni couleur changée ; pièces ancrées ;
--   - textes : Title = nom de l'amélioration (Config/Upgrades), Level = « Level 5 > Level 6 » (niveaux
--     achetés, comme MaxLevel), BuyButton.Price = prix (Shared/Format). Au niveau max : « Max level »,
--     BuyButton caché. RobuxButton toujours caché : aucun produit Robux pour ces améliorations ;
--   - chez le propriétaire, le SignGui de la copie est rangé dans son PlayerGui avec Adornee = Board
--     (sinon Roblox n'y envoie ni clic ni appui) et ResetOnSpawn = false ; chez les autres, il reste
--     sur Board (visible, pas cliquable). Un clic ou un appui sur BuyButton (Activated) envoie
--     BuyItem(Id). Garde anti double achat : un clic n'achète que le niveau dont le prix est affiché,
--     puis le bouton est muet jusqu'au nouveau niveau, ou PENDING_TIMEOUT s si le serveur refuse.
--   - les panneaux suivent : niveaux, présentoir suivant, streaming (point retiré : panneau retiré,
--     reposé à son retour), changement ou libération de parcelle, départ d'un joueur, réapparition.
--   - clic rattrapé (vu en Play le 2026-11-10 : le clic ne faisait rien) : Roblox n'envoie le clic au
--     SurfaceGui que si rien n'est devant le panneau, or les murs et le toit invisibles de la parcelle
--     (PlotBarrier, Transparency 1) le couvrent souvent. Un clic ou un appui que Roblox n'a pas pris
--     (gameProcessedEvent faux) est relancé ici par un rayon qui traverse les pièces presque
--     transparentes (SEE_THROUGH) ; s'il touche la face de Board d'un panneau du joueur, au droit de
--     BuyButton, c'est un achat (même garde). Un mur opaque bloque toujours le clic.
--   - les maquettes de Clément `Workspace/_PREVIEW_UpgradeSigns` (panneaux posés au même endroit pour
--     voir la pose en édition) sont retirées ici, en jeu, côté client seulement : sinon elles se
--     superposent aux vrais panneaux et prennent le clic. Rien n'est touché en édition.
--
-- Repli (UpgradeSign absent des Assets, ou sans Board, SignGui ou BuyButton) : une ligne dans la
-- sortie, et les invites d'avant, chez le propriétaire seulement (ProximityPrompt « UpgradePrompt »,
-- touche F ou bouton Y, maintien de HOLD_DURATION s) : « Upgrade ($380) » sur le tapis et le banc
-- (« Treadmill Lv 1/20 »), « Unlock stand ($500) » sur le prochain DisplaySlot_xx verrouillé
-- (« Stands 4/20 ») ; cachées au niveau max. Jamais sur le UsePoint (invites « Run » / « Lift »).
--
-- API (client) : aucune.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Balance = require(Config:WaitForChild("Balance"))
local Formulas = require(Config:WaitForChild("Formulas"))
local Upgrades = require(Config:WaitForChild("Upgrades"))
local Contract = Shared:WaitForChild("Contract")
local Find = require(Contract:WaitForChild("Find"))
local UI = require(Contract:WaitForChild("UI"))
local Format = require(Shared:WaitForChild("Format"))

type Kind = "Machine" | "Stand"

type Offer = {
	id: string, -- Id de Config/Upgrades
	kind: Kind,
	tag: string?, -- tag de la machine (Machine seulement)
	pendingLevel: number?, -- niveau au moment du dernier achat demandé (joueur local)
	pendingUntil: number,
}

-- Ce qui est montré pour une amélioration sur une parcelle.
type Entry = {
	owner: Player?,
	target: Attachment?, -- point du panneau ou de l'invite
	prompt: ProximityPrompt?, -- repli
	sign: Model?,
	gui: SurfaceGui?,
	shownLevel: number?, -- niveau dont le prix est affiché sur le panneau
	click: RBXScriptConnection?,
}

-- Contrat (2.1, 2.2 et 10.4) et attributs posés par les services serveur (lus sans require).
local PLOT_TAG = "PlayerPlot"
local OWNER_ATTRIBUTE = "OwnerUserId" -- PlotService
local LEVEL_FORMAT = "%sLevel" -- ShopService : TreadmillLevel, BenchLevel…
local SLOT_FORMAT = "DisplaySlot_%02d"
local POINT_NAME = "UpgradePoint" -- dans le tapis et le banc (L-082)
local DISPLAY_POINT_NAME = "DisplayUpgradePoint" -- dans la parcelle (L-082)
local MADE_POINT_NAME = "UpgradePointV0" -- point créé ici à défaut, côté client seulement
local PROMPT_NAME = "UpgradePrompt"
local SIGN_NAME = "UpgradeSign" -- modèle de Clément (ReplicatedStorage/Assets/UI)
local BOARD_NAME = "Board"
local GUI_NAME = "SignGui"
local TITLE_NAME = "Title"
local LEVEL_NAME = "Level"
local BUY_NAME = "BuyButton"
local ROBUX_NAME = "RobuxButton"
local PRICE_NAME = "Price"

-- V0 proposés, absents du doc : textes (en anglais, L-036), portée et maintien de l'invite de repli,
-- touches (pas E, celle des invites Run / Lift / Place Box), hauteur du point créé au-dessus d'une
-- machine, délai d'attente de la réponse du serveur après un achat, nom du dossier local des panneaux.
local TEXT = {
	Upgrade = "Upgrade (%s)",
	UnlockStand = "Unlock stand (%s)",
	MachineLevel = "%s Lv %d/%d",
	Stands = "Stands %d/%d",
	SignLevel = "Level %d > Level %d",
	SignMax = "Max level",
}
local PROMPT_DISTANCE = 8
local HOLD_DURATION = 0.5
local KEYBOARD_KEY = Enum.KeyCode.F
local GAMEPAD_KEY = Enum.KeyCode.ButtonY
local POINT_HEIGHT = 0.5 -- studs au-dessus du sommet du modèle
local PENDING_TIMEOUT = 1.5
local SIGN_FOLDER = "UpgradeSigns"
-- Clic rattrapé (voir l'en-tête), V0 : une pièce au moins aussi transparente ne bloque pas le clic,
-- portée du rayon (studs), pièces traversées au plus ; maquettes de Clément retirées en jeu.
local SEE_THROUGH = 0.5
local CLICK_RANGE = 250
local CLICK_PASSES = 16
local PREVIEW_FOLDER = "_PREVIEW_UpgradeSigns"
local HAND_CURSOR = "rbxasset://SystemCursors/PointingHand" -- curseur système de Roblox, celui des boutons

local UpgradeController = {}

local localPlayer = Players.LocalPlayer
local net: any = nil
local watchedPlots: { [Instance]: { RBXScriptConnection } } = {}
local entries: { [Instance]: { [string]: Entry } } = {} -- parcelle → Id → ce qui est montré
local plotOwners: { [Instance]: Player? } = {} -- propriétaire pris en compte au dernier passage
local madePoints: { [Instance]: Attachment } = {} -- machine → point créé ici
local signFolder: Folder? = nil
local boards: { [BasePart]: { offer: Offer, entry: Entry } } = {} -- Board d'un panneau → son achat
local refreshQueued = false
local fallbackSaid = false

local offers: { Offer } = {
	{ id = "Treadmill", kind = "Machine", tag = "Treadmill", pendingUntil = 0 },
	{ id = "Bench", kind = "Machine", tag = "Bench", pendingUntil = 0 },
	{ id = "DisplaySlots", kind = "Stand", pendingUntil = 0 },
}

local function levelOf(player: Player, id: string): number?
	local value = player:GetAttribute(string.format(LEVEL_FORMAT, id))
	return if type(value) == "number" then value else nil
end

local function isPending(offer: Offer, level: number): boolean
	return offer.pendingLevel == level and os.clock() < offer.pendingUntil
end

-- Modèle UpgradeSign de Clément, ou nil (repli sur les invites) avec la raison.
local function signTemplate(): (Model?, string?)
	local current: Instance? = ReplicatedStorage
	for _, segment in UI.BillboardFolder do
		current = if current then current:FindFirstChild(segment) else nil
	end
	local found = if current then current:FindFirstChild(SIGN_NAME, true) else nil
	if found == nil or not found:IsA("Model") then
		return nil, `{SIGN_NAME} absent de ReplicatedStorage.{table.concat(UI.BillboardFolder, ".")}`
	end
	local board = Find.path(found, BOARD_NAME)
	local gui = Find.path(found, GUI_NAME)
	local buy = if gui then Find.path(gui, BUY_NAME) else nil
	if board == nil or not board:IsA("BasePart") or gui == nil or not gui:IsA("SurfaceGui") or buy == nil or not buy:IsA("GuiButton") then
		return nil, `{SIGN_NAME} sans {BOARD_NAME} (BasePart), {GUI_NAME} (SurfaceGui) ou {BUY_NAME} (bouton)`
	end
	return found :: Model, nil
end

-- Points -----------------------------------------------------------------------------------------

-- Point d'une machine : son UpgradePoint, sinon un point créé ici au-dessus d'elle.
local function machinePoint(machine: Instance): Attachment?
	local given = Find.path(machine, POINT_NAME)
	if given and given:IsA("Attachment") then
		return given :: Attachment
	end
	local made = madePoints[machine]
	if made and made:IsDescendantOf(machine) then
		return made
	end
	local part: BasePart? = nil
	local primary = if machine:IsA("Model") then (machine :: Model).PrimaryPart else nil
	if primary and primary:IsDescendantOf(machine) then
		part = primary
	elseif machine:IsA("BasePart") then
		part = machine :: BasePart
	else
		local found = machine:FindFirstChildWhichIsA("BasePart", true)
		part = if found then found :: BasePart else nil
	end
	if part == nil then
		return nil -- pas encore chargée (streaming)
	end
	local carrier = part :: BasePart
	local top: Vector3
	if machine:IsA("Model") then
		local boxCFrame, boxSize = (machine :: Model):GetBoundingBox()
		top = boxCFrame.Position + Vector3.new(0, boxSize.Y / 2 + POINT_HEIGHT, 0)
	else
		top = carrier.Position + Vector3.new(0, carrier.Size.Y / 2 + POINT_HEIGHT, 0)
	end
	local offset: Vector3 = carrier.CFrame:PointToObjectSpace(top)
	local point = Instance.new("Attachment")
	point.Name = MADE_POINT_NAME
	point.CFrame = CFrame.new(offset)
	point.Parent = carrier
	madePoints[machine] = point
	return point
end

local function attachmentIn(root: Instance, name: string): Attachment?
	local found = Find.path(root, name)
	if found and found:IsA("Attachment") then
		return found :: Attachment
	end
	return nil
end

local function machineOf(offer: Offer, plotModel: Instance): Instance?
	for _, machine in CollectionService:GetTagged(offer.tag or "") do
		if machine:IsDescendantOf(plotModel) then
			return machine
		end
	end
	return nil
end

-- Prochain présentoir verrouillé, ou nil (tous débloqués, ou pas encore chargé).
local function nextSlot(plotModel: Instance, level: number): Attachment?
	local index = Balance.Display.StartSlots + level + 1
	return if index <= Balance.Display.MaxSlots then attachmentIn(plotModel, string.format(SLOT_FORMAT, index)) else nil
end

-- Point de l'invite de repli (comme avant L-082).
local function promptTarget(offer: Offer, plotModel: Instance, level: number): Attachment?
	if offer.kind == "Machine" then
		local machine = machineOf(offer, plotModel)
		return if machine then machinePoint(machine) else nil
	end
	return nextSlot(plotModel, level)
end

-- Point du panneau : celui de l'invite pour une machine ; pour les présentoirs, le DisplayUpgradePoint
-- (le plus proche du prochain présentoir verrouillé s'il y en a plusieurs), sinon ce présentoir.
local function signTarget(offer: Offer, plotModel: Instance, level: number): Attachment?
	if offer.kind == "Machine" then
		return promptTarget(offer, plotModel, level)
	end
	local slot = nextSlot(plotModel, level)
	local best: Attachment? = nil
	local bestDistance = math.huge
	for _, found in Find.all(plotModel, DISPLAY_POINT_NAME) do
		if found:IsA("Attachment") then
			local point = found :: Attachment
			local distance = if slot then (point.WorldCFrame.Position - slot.WorldCFrame.Position).Magnitude else 0
			if best == nil or distance < bestDistance then
				best, bestDistance = point, distance
			end
		end
	end
	return best or slot
end

-- Panneau --------------------------------------------------------------------------------------------

local function flat(vector: Vector3): Vector3?
	local horizontal = Vector3.new(vector.X, 0, vector.Z)
	return if horizontal.Magnitude > 1e-3 then horizontal.Unit else nil
end

local function folder(): Folder
	local current = signFolder
	if current and current.Parent == Workspace then
		return current
	end
	local created = Instance.new("Folder")
	created.Name = SIGN_FOLDER
	created.Parent = Workspace
	signFolder = created
	return created
end

-- Copie du modèle, debout au point, face de Board tournée comme le LookVector du point.
local function placeSign(template: Model, target: Attachment, plotModel: Instance): Model
	local sign = template:Clone()
	local board = Find.path(sign, BOARD_NAME) :: BasePart
	local pivot = sign:GetPivot()
	local boxCFrame, boxSize = sign:GetBoundingBox()
	local bottom = boxCFrame.Position - Vector3.new(0, boxSize.Y / 2, 0)
	local front = flat(board.CFrame.LookVector) or flat(pivot.LookVector) or Vector3.new(0, 0, -1)
	local from = CFrame.lookAt(bottom, bottom + front)
	local world = target.WorldCFrame
	local plotLook = if plotModel:IsA("PVInstance") then flat((plotModel :: PVInstance):GetPivot().LookVector) else nil
	local out = flat(world.LookVector) or plotLook or Vector3.new(0, 0, -1)
	local to = CFrame.lookAt(world.Position, world.Position + out)
	sign:PivotTo(to * from:Inverse() * pivot)
	for _, descendant in sign:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
	sign.Parent = folder()
	return sign
end

local function clearSign(entry: Entry)
	local click = entry.click
	if click then
		click:Disconnect()
		entry.click = nil
	end
	for board, link in boards do
		if link.entry == entry then
			boards[board] = nil
		end
	end
	local gui = entry.gui
	if gui then
		entry.gui = nil
		gui:Destroy()
	end
	local sign = entry.sign
	if sign then
		entry.sign = nil
		sign:Destroy()
	end
	entry.shownLevel = nil
end

local function clearPrompt(entry: Entry)
	local prompt = entry.prompt
	if prompt then
		entry.prompt = nil
		prompt:Destroy()
	end
end

local function clearEntry(entry: Entry)
	clearSign(entry)
	clearPrompt(entry)
	entry.target = nil
end

local function setText(root: Instance, name: string, text: string)
	local label = Find.path(root, name)
	if label and (label:IsA("TextLabel") or label:IsA("TextButton")) then
		(label :: any).Text = text
	end
end

local scheduleRefresh: () -> ()

-- Clic ou appui sur BuyButton, chez le propriétaire.
local function onBuy(offer: Offer, entry: Entry)
	if entry.owner ~= localPlayer or entry.sign == nil then
		return
	end
	local level = levelOf(localPlayer, offer.id)
	if level == nil or level ~= entry.shownLevel or isPending(offer, level) then
		return -- prix affiché périmé, ou achat déjà demandé à ce niveau
	end
	if Formulas.UpgradeCost(offer.id, level) == nil then
		return
	end
	offer.pendingLevel = level
	offer.pendingUntil = os.clock() + PENDING_TIMEOUT
	net.Client.BuyItem:Fire(offer.id)
	task.delay(PENDING_TIMEOUT, scheduleRefresh)
end

local function showSign(offer: Offer, entry: Entry, template: Model, plotModel: Instance, owner: Player, level: number, cost: number?)
	local target = signTarget(offer, plotModel, level)
	if target == nil then
		clearSign(entry)
		entry.target = nil
		return
	end
	local sign = entry.sign
	local gui = entry.gui
	if sign == nil or sign.Parent == nil or gui == nil or gui.Parent == nil or entry.target ~= target then
		-- Neuf, déplacé (présentoir suivant), ou perdu : un panneau neuf.
		clearSign(entry)
		local fresh = placeSign(template, target, plotModel)
		local freshGui = Find.path(fresh, GUI_NAME) :: SurfaceGui
		entry.sign, entry.gui, entry.target = fresh, freshGui, target
		local buy = Find.path(freshGui, BUY_NAME) :: GuiButton
		entry.click = buy.Activated:Connect(function()
			onBuy(offer, entry)
		end)
		boards[Find.path(fresh, BOARD_NAME) :: BasePart] = { offer = offer, entry = entry }
		sign, gui = fresh, freshGui
	end
	local currentSign = sign :: Model
	local currentGui = gui :: SurfaceGui
	-- SurfaceGui : dans le PlayerGui du propriétaire (cliquable), sinon sur Board.
	local board = Find.path(currentSign, BOARD_NAME) :: BasePart
	local playerGui = if owner == localPlayer then localPlayer:FindFirstChildOfClass("PlayerGui") else nil
	if playerGui then
		currentGui.ResetOnSpawn = false
		currentGui.Adornee = board
		currentGui.Parent = playerGui
	elseif currentGui.Parent ~= board then
		currentGui.Parent = board -- Adornee = Board laissé : même surface
	end

	local upgrade = Upgrades.ById[offer.id]
	setText(currentGui, TITLE_NAME, upgrade.DisplayName)
	setText(currentGui, LEVEL_NAME, if cost then string.format(TEXT.SignLevel, level, level + 1) else TEXT.SignMax)
	local buy = Find.path(currentGui, BUY_NAME) :: GuiButton
	buy.Visible = cost ~= nil
	if cost then
		setText(buy, PRICE_NAME, Format.money(cost))
	end
	local robux = Find.path(currentGui, ROBUX_NAME)
	if robux and robux:IsA("GuiObject") then
		robux.Visible = false -- aucun produit Robux pour ces améliorations (V0)
	end
	entry.shownLevel = level
end

-- Clic rattrapé (voir l'en-tête) : le point de l'écran `screen` (coordonnées d'un InputObject) touche-t-il
-- le BuyButton d'un panneau ? Le rayon traverse les pièces presque transparentes, jamais un mur opaque.
local function boardAt(screen: Vector3): (BasePart?, Vector3?)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return nil, nil
	end
	local ray = camera:ScreenPointToRay(screen.X, screen.Y)
	local ignored: { Instance } = {}
	local character = localPlayer.Character
	if character then
		table.insert(ignored, character)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	for _ = 1, CLICK_PASSES do
		params.FilterDescendantsInstances = ignored
		local hit = Workspace:Raycast(ray.Origin, ray.Direction * CLICK_RANGE, params)
		if hit == nil then
			return nil, nil
		end
		local part = hit.Instance
		if boards[part] then
			return part, hit.Position
		end
		if part.Transparency < SEE_THROUGH then
			return nil, nil -- mur opaque devant le panneau
		end
		table.insert(ignored, part)
	end
	return nil, nil
end

-- Le BuyButton actif d'un panneau du joueur sous ce point de l'écran, ou nil.
local function buyAt(screen: Vector3): { offer: Offer, entry: Entry }?
	local board, point = boardAt(screen)
	local link = if board then boards[board] else nil
	if board == nil or point == nil or link == nil then
		return nil
	end
	local gui = link.entry.gui
	local buy = if gui then Find.path(gui, BUY_NAME) else nil
	if gui == nil or buy == nil or not buy:IsA("GuiObject") or not (buy :: GuiObject).Visible or gui.Adornee ~= board then
		return nil -- panneau d'un autre joueur (pas dans le PlayerGui), ou niveau max
	end
	-- Face avant (Front, LookVector) : à gauche de l'écran le +X de la pièce, en haut le +Y.
	local localPoint = board.CFrame:PointToObjectSpace(point)
	if localPoint.Z > -board.Size.Z / 2 + 0.05 then
		return nil -- touché par le dos ou le côté
	end
	local canvas = gui.AbsoluteSize
	local x = (0.5 - localPoint.X / board.Size.X) * canvas.X
	local y = (0.5 - localPoint.Y / board.Size.Y) * canvas.Y
	local corner, size = (buy :: GuiObject).AbsolutePosition, (buy :: GuiObject).AbsoluteSize
	if x >= corner.X and x <= corner.X + size.X and y >= corner.Y and y <= corner.Y + size.Y then
		return link
	end
	return nil
end

local function onWorldClick(input: InputObject, processed: boolean)
	if processed then
		return -- Roblox l'a déjà donné à une interface (BuyButton.Activated compris)
	end
	local kind = input.UserInputType
	if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
		return
	end
	local link = buyAt(input.Position)
	if link then
		onBuy(link.offer, link.entry)
	end
end

-- Main au survol du bouton (demande de Cantin, 2026-11-10) : même quand une pièce invisible est
-- devant et que Roblox ne la montre pas lui-même. On ne remet l'icône que si c'est nous qui l'avons posée.
local handShown = false
local function onMouseMove(input: InputObject, processed: boolean)
	if input.UserInputType ~= Enum.UserInputType.MouseMovement then
		return
	end
	local over = not processed and buyAt(input.Position) ~= nil -- sur une interface : Roblox gère le curseur
	if over ~= handShown then
		handShown = over
		UserInputService.MouseIcon = if over then HAND_CURSOR else ""
	end
end

-- Maquettes de Clément au même endroit que les panneaux (voir l'en-tête) : retirées en jeu, ici seulement.
local function dropPreview(child: Instance)
	if child.Name == PREVIEW_FOLDER then
		child:Destroy()
	end
end

-- Invite de repli, chez le propriétaire (comportement d'avant L-082).
local function showPrompt(offer: Offer, entry: Entry, plotModel: Instance, level: number, cost: number?)
	local target = if cost then promptTarget(offer, plotModel, level) else nil
	if cost == nil or target == nil then
		clearPrompt(entry) -- niveau max, ou point pas encore chargé
		entry.target = nil
		return
	end
	local prompt = entry.prompt
	if prompt == nil or prompt.Parent ~= target then
		-- Déplacée (achat), ou détruite avec son point (streaming) : une invite neuve.
		clearPrompt(entry)
		local fresh = Instance.new("ProximityPrompt")
		fresh.Name = PROMPT_NAME
		fresh.MaxActivationDistance = PROMPT_DISTANCE
		fresh.HoldDuration = HOLD_DURATION
		fresh.KeyboardKeyCode = KEYBOARD_KEY
		fresh.GamepadKeyCode = GAMEPAD_KEY
		fresh.RequiresLineOfSight = false
		fresh.Triggered:Connect(function()
			local now = levelOf(localPlayer, offer.id)
			if now == nil or entry.prompt ~= fresh or not fresh.Enabled then
				return
			end
			offer.pendingLevel = now
			offer.pendingUntil = os.clock() + PENDING_TIMEOUT
			fresh.Enabled = false
			net.Client.BuyItem:Fire(offer.id)
			task.delay(PENDING_TIMEOUT, scheduleRefresh)
		end)
		fresh.Parent = target
		entry.prompt = fresh
		entry.target = target
		prompt = fresh
	end
	local current = prompt :: ProximityPrompt
	local price = Format.money(cost :: number)
	if offer.kind == "Machine" then
		local upgrade = Upgrades.ById[offer.id]
		current.ActionText = string.format(TEXT.Upgrade, price)
		current.ObjectText = string.format(TEXT.MachineLevel, upgrade.DisplayName, level, upgrade.MaxLevel)
	else
		local display = Balance.Display
		current.ActionText = string.format(TEXT.UnlockStand, price)
		current.ObjectText = string.format(TEXT.Stands, math.min(display.StartSlots + level, display.MaxSlots), display.MaxSlots)
	end
	current.Enabled = not isPending(offer, level)
end

-- Mise à jour ----------------------------------------------------------------------------------------

local function ownerOf(plotModel: Instance): Player?
	local id = plotModel:GetAttribute(OWNER_ATTRIBUTE)
	if type(id) ~= "number" or id <= 0 then
		return nil
	end
	return Players:GetPlayerByUserId(id)
end

-- Points créés ici sur les machines d'une parcelle (libérée, changée de propriétaire ou retirée).
local function dropMadePoints(plotModel: Instance)
	for machine, point in madePoints do
		if machine == plotModel or machine:IsDescendantOf(plotModel) then
			point:Destroy()
			madePoints[machine] = nil
		end
	end
end

local function refreshAll()
	refreshQueued = false
	local template, reason = signTemplate()
	if template == nil and not fallbackSaid then
		fallbackSaid = true
		print(`[UpgradeController] {reason} : invites d'achat à la place des panneaux (L-082)`)
	end
	for plotModel, byId in entries do
		local owner = ownerOf(plotModel)
		if plotOwners[plotModel] ~= owner then
			plotOwners[plotModel] = owner
			for _, entry in byId do
				clearEntry(entry) -- parcelle libérée ou changée de propriétaire
				entry.owner = owner
			end
			dropMadePoints(plotModel)
		end
		for _, offer in offers do
			local entry = byId[offer.id]
			local level = if owner then levelOf(owner, offer.id) else nil
			if owner == nil or level == nil then
				clearEntry(entry) -- profil pas encore chargé
			elseif template then
				clearPrompt(entry)
				showSign(offer, entry, template, plotModel, owner, level, Formulas.UpgradeCost(offer.id, level))
			else
				clearSign(entry)
				if owner == localPlayer then
					showPrompt(offer, entry, plotModel, level, Formulas.UpgradeCost(offer.id, level))
				else
					clearPrompt(entry)
				end
			end
		end
	end
end

-- Une seule mise à jour par image, quel que soit le nombre d'événements.
scheduleRefresh = function()
	if not refreshQueued then
		refreshQueued = true
		task.defer(refreshAll)
	end
end

local function watchPlot(inst: Instance)
	if watchedPlots[inst] then
		return
	end
	local function onChange(_inst: Instance?)
		scheduleRefresh()
	end
	watchedPlots[inst] = {
		inst:GetAttributeChangedSignal(OWNER_ATTRIBUTE):Connect(onChange),
		inst.DescendantAdded:Connect(onChange),
		inst.DescendantRemoving:Connect(onChange),
	}
	local byId: { [string]: Entry } = {}
	for _, offer in offers do
		byId[offer.id] = {}
	end
	entries[inst] = byId
	scheduleRefresh()
end

local function unwatchPlot(inst: Instance)
	local connections = watchedPlots[inst]
	if connections then
		for _, connection in connections do
			connection:Disconnect()
		end
		watchedPlots[inst] = nil
	end
	local byId = entries[inst]
	if byId then
		for _, entry in byId do
			clearEntry(entry)
		end
		entries[inst] = nil
	end
	plotOwners[inst] = nil
	dropMadePoints(inst)
	scheduleRefresh()
end

local function watchPlayer(player: Player)
	for _, offer in offers do
		player:GetAttributeChangedSignal(string.format(LEVEL_FORMAT, offer.id)):Connect(scheduleRefresh)
	end
	scheduleRefresh()
end

function UpgradeController.Start()
	-- Peut attendre que le serveur ait créé les remotes.
	net = require(Shared:WaitForChild("Net"):WaitForChild("Net") :: ModuleScript) :: any

	for _, child in Workspace:GetChildren() do
		dropPreview(child)
	end
	Workspace.ChildAdded:Connect(dropPreview)
	UserInputService.InputBegan:Connect(onWorldClick)
	UserInputService.InputChanged:Connect(onMouseMove)

	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function()
		scheduleRefresh()
	end)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	-- Réapparition : SignGui a ResetOnSpawn = false ; une vérification de plus ne coûte rien.
	localPlayer.CharacterAdded:Connect(function()
		scheduleRefresh()
	end)
	CollectionService:GetInstanceAddedSignal(PLOT_TAG):Connect(watchPlot)
	CollectionService:GetInstanceRemovedSignal(PLOT_TAG):Connect(unwatchPlot)
	for _, inst in CollectionService:GetTagged(PLOT_TAG) do
		watchPlot(inst)
	end
end

return UpgradeController
