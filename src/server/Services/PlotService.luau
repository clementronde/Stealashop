--!strict
-- PlotService (DEV-010) : les 6 parcelles des joueurs (Partie 1, sections 3, 4, 5.8, 9.3, 10.4).
--
-- Rôle : dès que le profil d'un joueur est chargé, lui donne la parcelle libre de plus
-- petit numéro, place son personnage dessus à chaque apparition et écrit son pseudo sur
-- le panneau `NameSign`. À son départ, la parcelle redevient libre pour le joueur suivant.
-- Aucun remote : rien ne vient du client. Seules les parcelles taggées `PlayerPlot` dans
-- le Workspace comptent (pas celles de _INBOX_CLEMENT ni de _SANDBOX_IRONIX).
--
-- Attributs posés par ce service (lus par les autres services et par les contrôleurs
-- client, sans require) :
--   sur chaque parcelle (Model taggé PlayerPlot) :
--     OwnerUserId (number) : UserId du propriétaire, 0 = libre. En test local « Serveur +
--       clients », les UserId sont négatifs (-1, -2…) : seul 0 veut dire libre.
--     PlotIndex (number) : numéro de la parcelle, 1 à 6, posé par la greybox (ajout au
--       contrat en attente, liaison L-015). S'il manque ou se répète, ce service donne le
--       plus petit numéro libre et l'écrit dans la sortie.
--   sur le Player :
--     PlotIndex (number) : numéro de sa parcelle ; nil tant qu'il n'en a pas.
--
-- API (côté serveur uniquement) :
--   PlotService.GetPlot(player) -> Model?
--       Parcelle du joueur, nil s'il n'en a pas (profil pas encore chargé, ou en attente).
--   PlotService.GetOwner(plot) -> Player?
--       Propriétaire de la parcelle, nil si elle est libre.
--   PlotService.OnPlotAssigned(listener) -> déconnexion
--       listener(player, plot) à chaque attribution, y compris pour les parcelles déjà
--       attribuées au moment de l'abonnement (pas de course au démarrage). C'est le bon
--       moment pour installer la boutique sauvegardée (présentoirs, établis). Le listener
--       peut yield ; après un yield, revérifier que GetPlot(player) == plot.
--   PlotService.OnPlotReleased(listener) -> déconnexion
--       listener(player, plot) au départ du joueur, une fois la parcelle libérée
--       (OwnerUserId = 0) et avant qu'elle serve à un autre joueur : nettoyer ce que la
--       parcelle affiche (objets, colis). Il ne doit pas yield. Son ordre avec
--       DataService.OnProfileReleasing n'est pas garanti (Roblox ne garantit pas l'ordre
--       des PlayerRemoving) : ce qui s'écrit dans le profil au départ va dans
--       OnProfileReleasing, pas ici.
--   PlotService.TeleportHome(player, canMove?) -> boolean
--       Ramène le personnage sur sa parcelle, au point d'apparition (retour base DEV-045,
--       vigile de nuit 5.12). Peut yield (2 s au plus) ; false si le joueur n'a pas de
--       parcelle ou pas de personnage. Les règles (recharge, mains vides) restent à
--       l'appelant ; `canMove`, s'il est donné, est rappelé juste avant le déplacement, après
--       l'attente : false = on ne bouge pas (le joueur a pris un colis entre-temps, par exemple).
--   PlotService.GetPlots() -> { Model }
--       Parcelles valides de la map, triées par PlotIndex (copie de la liste).
--   PlotService.GetPlotByIndex(index) -> Model?
--       Parcelle de numéro PlotIndex `index`, ou nil (StealItem, PvPService).
--   PlotService.PutOutside(player, plot) -> boolean
--       Sort le personnage devant la porte de la boutique `plot` (boutique du hub, liaison L-050) :
--       au sol, à OUTSIDE_DISTANCE studs devant l'objet Window (`PlotDoor/Window`), au hasard sur la
--       largeur de la porte, tourné vers l'extérieur (du centre de Bounds vers la porte). Il garde ce
--       qu'il porte (le colis ou l'objet est soudé à sa tête). Sans yield ; false sans personnage
--       vivant. Qui sortir et quand : PvPService.
--
-- Exemple (dans un autre service) :
--   local PlotService = require(script.Parent.PlotService)
--   PlotService.OnPlotAssigned(function(player, plot)
--       -- poser les objets exposés sauvegardés sur les présentoirs de `plot`
--   end)
--   PlotService.OnPlotReleased(function(player, plot)
--       -- retirer de `plot` les objets exposés de `player`
--   end)
--
-- Plus de joueurs que de parcelles (Max Players du jeu au-dessus de 6, ou test Studio à
-- 7 clients) : le joueur en trop reste sur le serveur, sans parcelle, au spawn de l'allée.
-- Il est prévenu par Notify et reçoit la première parcelle qui se libère.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DataService = require(script.Parent.DataService)
local Find = require(ReplicatedStorage.Shared.Contract.Find)
local Models = require(ReplicatedStorage.Shared.Contract.Models)
local Net = require(ReplicatedStorage.Shared.Net.Net)

export type PlotListener = (player: Player, plot: Model) -> ()

-- Tag et enfants de la parcelle (contrat 10.4, Contract/Models).
local PLOT_TAG = Models.Plot.Tag :: string
local WINDOW = "Window"
local NAME_SIGN = "NameSign"

-- Attributs de cette vague (voir l'en-tête).
local OWNER_ATTRIBUTE = "OwnerUserId"
local INDEX_ATTRIBUTE = "PlotIndex"

-- Absents du contrat 10.4, proposés pour y entrer (à valider par Clément) :
--   OwnerName (TextLabel dans NameSign) : le code y écrit « <Pseudo>'s Shop » (anglais, L-036),
--     vide quand la parcelle est libre. Sans lui, ce service crée un SurfaceGui minimal.
--   SpawnPoint (Attachment dans la parcelle) : point d'apparition du propriétaire,
--     axe avant (−Z) tourné vers l'allée. Sans lui, le point est devant la vitrine.
local OWNER_LABEL = "OwnerName"
local SPAWN_POINT = "SpawnPoint"
-- Nom du SurfaceGui créé par ce service quand NameSign n'a pas de OwnerName.
local SIGN_GUI = "OwnerSign"

-- Dossiers du Workspace dont les parcelles ne comptent pas (doc, 2.1).
local INBOX_NAME = "_INBOX_CLEMENT"
local SANDBOX_NAME = "_SANDBOX_IRONIX"

-- V0 proposé, absent du doc : le propriétaire apparaît à 6 studs devant sa vitrine. Cet
-- endroit est forcément libre (on y frappe la vitre, portée 8 studs) ; c'est là qu'on
-- défend sa boutique (6.2), et tourné vers l'allée on voit les autres boutiques.
local SPAWN_FRONT_DISTANCE = 6
-- V0 proposé, absent du doc : le sol est cherché de 4 studs au-dessus du point (sous un
-- éventuel auvent) jusqu'à 8 studs en dessous.
local GROUND_RAY_UP = 4
local GROUND_RAY_DOWN = 8
-- V0 proposé, absent du doc : marge entre les pieds et le sol à l'apparition.
local SPAWN_LIFT = 0.1
-- V0 proposé, absent du doc : attente maximale du personnage (HumanoidRootPart, Workspace).
local CHARACTER_TIMEOUT = 10
-- V0 proposé, absent du doc : attente maximale du chargement de la zone chez le client
-- avant de le déplacer (StreamingEnabled, 9.7) ; au-delà, il est déplacé quand même.
local STREAM_TIMEOUT = 2
-- V0 proposé, absent du doc : PutOutside pose le joueur à 6 studs devant la porte (comme
-- StoreHeistService devant une vitrine), à 1 stud au moins des bords de la porte.
local OUTSIDE_DISTANCE = 6
local OUTSIDE_EDGE = 1
local BOUNDS = "Bounds"

-- Messages lus par le joueur (Notify), en anglais (L-036).
local MESSAGES = {
	Waiting = "All shops are taken: you'll get the next one that frees up.",
	Freed = "A shop just freed up: it's yours!",
}

local PlotService = {}
-- Après DataService (1) ; avant les services de jeu (100 par défaut), qui peuvent lire
-- PlotIndex et OwnerUserId sur les parcelles dès leur Init.
PlotService.Priority = 10

local plots: { Model } = {} -- parcelles valides, triées par PlotIndex
local indexOf: { [Model]: number } = {}
local ownerOf: { [Model]: Player } = {}
local plotOf: { [Player]: Model } = {}
local waiting: { Player } = {} -- joueurs chargés sans parcelle, du plus ancien au plus récent
-- Joueurs dont PlayerRemoving est passé : un profil chargé à ce moment-là ne reçoit
-- rien. Clés faibles : l'entrée part avec le Player.
local leaving: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any
-- Point d'apparition, vitrine et volume de chaque parcelle, trouvés à l'Init (avant que des
-- objets exposés, qui peuvent contenir les mêmes noms, soient posés dans la parcelle).
local spawnRefs: { [Model]: { point: Attachment?, window: PVInstance?, bounds: BasePart? } } = {}
local labels: { [Model]: TextLabel } = {} -- texte du panneau de chaque parcelle
local createdGuis: { [Model]: SurfaceGui } = {} -- SurfaceGui créé par ce service
local spawnConnections: { [Player]: RBXScriptConnection } = {}
local assignedListeners: { PlotListener } = {}
local releasedListeners: { PlotListener } = {}

-- Renvoie une fonction qui retire `listener` de `list` (même règle que DataService).
local function subscribe<T>(list: { T }, listener: T): () -> ()
	table.insert(list, listener)
	return function()
		local index = table.find(list, listener)
		if index then
			table.remove(list, index)
		end
	end
end

local function validIndex(value: any): number?
	if type(value) == "number" and value >= 1 and value % 1 == 0 then
		return value
	end
	return nil
end

-- Direction horizontale de l'avant de la parcelle : son pivot regarde l'allée (10.1).
local function frontOf(plot: Model): Vector3
	local look = plot:GetPivot().LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		return Vector3.new(0, 0, -1)
	end
	return flat.Unit
end

------------------------------------------------------------------------------
-- Recherche des parcelles
------------------------------------------------------------------------------

local function collectPlots(): { Model }
	local inbox = Workspace:FindFirstChild(INBOX_NAME)
	local sandbox = Workspace:FindFirstChild(SANDBOX_NAME)
	local found: { Model } = {}
	for _, inst in CollectionService:GetTagged(PLOT_TAG) do
		local excluded = (inbox ~= nil and inst:IsDescendantOf(inbox)) or (sandbox ~= nil and inst:IsDescendantOf(sandbox))
		if not inst:IsDescendantOf(Workspace) or excluded then
			continue
		end
		if inst:IsA("Model") then
			table.insert(found, inst :: Model)
		else
			warn(`[PlotService] {inst:GetFullName()} porte le tag {PLOT_TAG} mais n'est pas un Model : ignoré`)
		end
	end

	-- Numéros valides d'abord, puis par nom : une parcelle sans PlotIndex ou en double
	-- reçoit le plus petit numéro libre.
	table.sort(found, function(a: Model, b: Model): boolean
		local ia = validIndex(a:GetAttribute(INDEX_ATTRIBUTE)) or math.huge
		local ib = validIndex(b:GetAttribute(INDEX_ATTRIBUTE)) or math.huge
		if ia ~= ib then
			return ia < ib
		end
		return a.Name < b.Name
	end)
	local used: { [number]: boolean } = {}
	local toNumber: { Model } = {}
	for _, plot in found do
		local index = validIndex(plot:GetAttribute(INDEX_ATTRIBUTE))
		if index and not used[index] then
			used[index] = true
			indexOf[plot] = index
		else
			table.insert(toNumber, plot)
		end
	end
	for _, plot in toNumber do
		local index = 1
		while used[index] do
			index += 1
		end
		used[index] = true
		indexOf[plot] = index
		warn(
			`[PlotService] {plot:GetFullName()} : attribut {INDEX_ATTRIBUTE} absent, invalide ou en double ({plot:GetAttribute(INDEX_ATTRIBUTE)}), numéro {index} donné pour cette partie`
		)
		plot:SetAttribute(INDEX_ATTRIBUTE, index)
	end
	table.sort(found, function(a: Model, b: Model): boolean
		return indexOf[a] < indexOf[b]
	end)
	return found
end

------------------------------------------------------------------------------
-- Panneau du nom
------------------------------------------------------------------------------

local FACES = {
	Enum.NormalId.Front,
	Enum.NormalId.Back,
	Enum.NormalId.Left,
	Enum.NormalId.Right,
	Enum.NormalId.Top,
	Enum.NormalId.Bottom,
}

-- Face de `part` la plus tournée vers `direction` (Front si égalité).
local function faceToward(part: BasePart, direction: Vector3): Enum.NormalId
	local best, bestDot = Enum.NormalId.Front, -math.huge
	for _, face in FACES do
		local dot = part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(face)):Dot(direction)
		if dot > bestDot + 1e-6 then
			best, bestDot = face, dot
		end
	end
	return best
end

-- V0 : SurfaceGui minimal sur la face du panneau tournée vers l'allée. Fond de la
-- couleur du panneau, pour couvrir le texte déjà posé sur cette face (la greybox y écrit
-- « PARCELLE n ») ; masqué quand la parcelle est libre.
local function createLabel(plot: Model, part: BasePart): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Name = SIGN_GUI
	gui.Face = faceToward(part, frontOf(plot))
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.ZOffset = 1
	gui.Enabled = false

	local label = Instance.new("TextLabel")
	label.Name = OWNER_LABEL
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = part.Color
	label.BorderSizePixel = 0
	label.TextScaled = true
	label.FontFace = Font.fromEnum(Enum.Font.GothamBold)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = ""
	label.Parent = gui

	gui.Parent = part
	createdGuis[plot] = gui
	return label
end

local function setupSign(plot: Model)
	local sign = Find.path(plot, NAME_SIGN)
	if sign == nil then
		warn(`[PlotService] {plot:GetFullName()} : pas de {NAME_SIGN} (contrat 10.4), le nom du propriétaire ne s'affichera pas`)
		return
	end
	local existing = Find.path(sign, OWNER_LABEL)
	if existing ~= nil then
		if existing:IsA("TextLabel") then
			labels[plot] = existing :: TextLabel
		else
			warn(`[PlotService] {existing:GetFullName()} doit être un TextLabel, le nom du propriétaire ne s'affichera pas`)
		end
		return
	end
	local part: BasePart? = nil
	if sign:IsA("BasePart") then
		part = sign :: BasePart
	elseif sign:IsA("Model") then
		part = (sign :: Model).PrimaryPart or (sign:FindFirstChildWhichIsA("BasePart", true) :: BasePart?)
	end
	if part == nil then
		warn(`[PlotService] {sign:GetFullName()} : aucune pièce où écrire le nom du propriétaire`)
		return
	end
	labels[plot] = createLabel(plot, part)
end

-- « Alice's Shop », « Bob's Shop » (anglais, L-036) ; vide pour une parcelle libre.
local function signText(owner: Player?): string
	if owner == nil then
		return ""
	end
	return `{owner.DisplayName}'s Shop`
end

local function updateSign(plot: Model)
	local text = signText(ownerOf[plot])
	local label = labels[plot]
	if label then
		label.Text = text
	end
	local gui = createdGuis[plot]
	if gui then
		gui.Enabled = text ~= ""
	end
end

------------------------------------------------------------------------------
-- Point d'apparition
------------------------------------------------------------------------------

-- Hauteur du sol sous `position`, cherchée autour de `referenceY` ; les personnages et
-- les pièces sans collision (Bounds, DepositZone, CashPad…) sont ignorés.
local function groundY(position: Vector3, referenceY: number): number
	local characters: { Instance } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			table.insert(characters, character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = characters
	params.RespectCanCollide = true
	params.IgnoreWater = true
	local origin = Vector3.new(position.X, referenceY + GROUND_RAY_UP, position.Z)
	local result = Workspace:Raycast(origin, Vector3.new(0, -(GROUND_RAY_UP + GROUND_RAY_DOWN), 0), params)
	return if result then result.Position.Y else referenceY
end

local function findSpawnRefs(plot: Model)
	local point = Find.path(plot, SPAWN_POINT)
	local window = Find.path(plot, WINDOW)
	local bounds = Find.path(plot, BOUNDS)
	local refs = {
		point = if point ~= nil and point:IsA("Attachment") then point :: Attachment else nil,
		window = if window ~= nil and window:IsA("PVInstance") then window :: PVInstance else nil,
		bounds = if bounds ~= nil and bounds:IsA("BasePart") then bounds :: BasePart else nil,
	}
	if refs.point == nil and refs.window == nil then
		warn(`[PlotService] {plot:GetFullName()} : ni {SPAWN_POINT} ni {WINDOW}, le propriétaire apparaîtra au pivot de la parcelle`)
	end
	spawnRefs[plot] = refs
end

-- Position au sol et direction du regard du propriétaire, avant la hauteur du personnage.
local function spawnSpot(plot: Model): (Vector3, Vector3)
	local refs = spawnRefs[plot]
	local point = refs and refs.point
	if point then
		local world = point.WorldCFrame
		local look = Vector3.new(world.LookVector.X, 0, world.LookVector.Z)
		local facing = if look.Magnitude > 1e-3 then look.Unit else frontOf(plot)
		return Vector3.new(world.X, groundY(world.Position, world.Y), world.Z), facing
	end

	local pivot = plot:GetPivot()
	local front = frontOf(plot)
	local spot = pivot.Position
	local window = refs and refs.window
	if window then
		spot = window:GetPivot().Position + front * SPAWN_FRONT_DISTANCE
	end
	-- Le pivot de la parcelle est en bas (10.1) : le sol est cherché autour de sa hauteur.
	return Vector3.new(spot.X, groundY(spot, pivot.Y), spot.Z), front
end

-- CFrame à donner au HumanoidRootPart pour que les pieds touchent le sol au point d'apparition.
local function rootTarget(plot: Model, humanoid: Humanoid, root: BasePart): CFrame
	local ground, facing = spawnSpot(plot)
	-- R15 : HipHeight = du bas du HumanoidRootPart au sol ; R6 : jambes de 2 studs.
	local hip = if humanoid.RigType == Enum.HumanoidRigType.R15 then humanoid.HipHeight else 2
	local position = ground + Vector3.new(0, hip + root.Size.Y / 2 + SPAWN_LIFT, 0)
	return CFrame.lookAt(position, position + facing)
end

-- Étendue de la boîte (cf, size) le long de la direction unitaire `axis`.
local function extentAlong(cf: CFrame, size: Vector3, axis: Vector3): number
	return math.abs(cf.RightVector:Dot(axis)) * size.X
		+ math.abs(cf.UpVector:Dot(axis)) * size.Y
		+ math.abs(cf.LookVector:Dot(axis)) * size.Z
end

-- Boîte orientée d'une pièce ou d'un modèle.
local function boxOf(object: PVInstance): (CFrame, Vector3)
	if object:IsA("BasePart") then
		return object.CFrame, object.Size
	end
	return (object :: Model):GetBoundingBox()
end

-- Point au sol devant la porte de la boutique (PutOutside) et direction vers l'extérieur : du centre
-- de Bounds vers la porte, sinon l'avant de la parcelle.
local function outsideSpot(plot: Model): (Vector3, Vector3)
	local refs = spawnRefs[plot]
	local pivot = plot:GetPivot()
	local front = frontOf(plot)
	local door = refs and refs.window
	local bounds = refs and refs.bounds
	local center = if bounds then bounds.Position else pivot.Position
	local doorPosition = if door then door:GetPivot().Position else center + front * 40
	local toDoor = Vector3.new(doorPosition.X - center.X, 0, doorPosition.Z - center.Z)
	local out = if toDoor.Magnitude > 1e-3 then toDoor.Unit else front
	local side = Vector3.yAxis:Cross(out).Unit
	local halfWidth = 0
	if door then
		local cf, size = boxOf(door)
		halfWidth = math.max(extentAlong(cf, size, side) / 2 - OUTSIDE_EDGE, 0)
	end
	local spot = doorPosition + out * OUTSIDE_DISTANCE + side * ((math.random() * 2 - 1) * halfWidth)
	return Vector3.new(spot.X, groundY(spot, doorPosition.Y), spot.Z), out
end

-- Déplace `character` sur la parcelle `plot` de `player`. Peut yield (zone chargée chez
-- le client). Renvoie true si le personnage a été déplacé. `canMove` : voir TeleportHome.
local function moveCharacter(player: Player, character: Model, plot: Model, canMove: (() -> boolean)?): boolean
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid?
	if root == nil or not root:IsA("BasePart") or humanoid == nil or humanoid.Health <= 0 then
		return false
	end
	local rootPart = root :: BasePart
	local target = rootTarget(plot, humanoid, rootPart)

	if Workspace.StreamingEnabled then
		pcall(function()
			player:RequestStreamAroundAsync(target.Position, STREAM_TIMEOUT)
		end)
		-- Le monde a pu changer pendant l'attente.
		if plotOf[player] ~= plot or player.Character ~= character or not character:IsDescendantOf(Workspace) then
			return false
		end
	end
	if canMove and not canMove() then
		return false
	end

	-- Le pivot d'un personnage standard est son HumanoidRootPart ; le décalage couvre les autres cas.
	character:PivotTo(target * rootPart.CFrame:ToObjectSpace(character:GetPivot()))
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero
	return true
end

-- À chaque apparition : attend le personnage complet dans le Workspace, puis une image
-- pour passer après le placement du moteur sur la SpawnLocation, et le déplace.
local function placeOnSpawn(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", CHARACTER_TIMEOUT) :: Instance?
	local humanoid = character:WaitForChild("Humanoid", CHARACTER_TIMEOUT) :: Instance?
	if root == nil or humanoid == nil then
		return
	end
	local deadline = os.clock() + CHARACTER_TIMEOUT
	while not character:IsDescendantOf(Workspace) do
		if os.clock() > deadline or player.Character ~= character then
			return
		end
		task.wait()
	end
	task.wait()
	local plot = plotOf[player]
	if plot ~= nil and player.Character == character then
		moveCharacter(player, character, plot)
	end
end

------------------------------------------------------------------------------
-- Attribution et libération
------------------------------------------------------------------------------

local function notify(player: Player, message: string, kind: string)
	local ok, err = pcall(function()
		Net.Server.Notify:Fire(player, message, kind)
	end)
	if not ok then
		warn(`[PlotService] Notify vers {player.Name} : {err}`)
	end
end

local function firstFreePlot(): Model?
	for _, plot in plots do
		if ownerOf[plot] == nil then
			return plot
		end
	end
	return nil
end

-- Le joueur peut-il recevoir une parcelle maintenant ? (présent, profil actif, sans parcelle)
local function canReceive(player: Player): boolean
	return player.Parent == Players and not leaving[player] and DataService.IsLoaded(player) and plotOf[player] == nil
end

-- Sans yield : rien ne peut se glisser entre la vérification et l'attribution.
local function assign(player: Player, plot: Model)
	ownerOf[plot] = player
	plotOf[player] = plot
	plot:SetAttribute(OWNER_ATTRIBUTE, player.UserId)
	player:SetAttribute(INDEX_ATTRIBUTE, indexOf[plot])
	updateSign(plot)

	spawnConnections[player] = player.CharacterAdded:Connect(function(character: Model)
		placeOnSpawn(player, character)
	end)
	-- Le personnage est souvent déjà apparu au spawn de l'allée pendant le chargement du
	-- profil : il rejoint sa parcelle (section 3, « arrivée sur sa parcelle »).
	local character = player.Character
	if character then
		task.spawn(placeOnSpawn, player, character)
	end

	print(`[PlotService] {player.Name} : parcelle {indexOf[plot]} ({plot.Name})`)
	for _, listener in table.clone(assignedListeners) do
		task.spawn(listener, player, plot)
	end
end

local function release(player: Player)
	local plot = plotOf[player]
	if plot == nil then
		return
	end
	plotOf[player] = nil
	ownerOf[plot] = nil
	local connection = spawnConnections[player]
	if connection then
		connection:Disconnect()
		spawnConnections[player] = nil
	end
	plot:SetAttribute(OWNER_ATTRIBUTE, 0)
	player:SetAttribute(INDEX_ATTRIBUTE, nil)
	updateSign(plot)
	print(`[PlotService] {player.Name} parti : parcelle {indexOf[plot]} libérée`)

	for _, listener in table.clone(releasedListeners) do
		local ok, err = pcall(listener, player, plot)
		if not ok then
			warn(`[PlotService] OnPlotReleased ({player.Name}, parcelle {indexOf[plot]}) : {err}`)
		end
	end

	-- La parcelle sert au premier joueur qui attend encore.
	while #waiting > 0 do
		local nextPlayer = table.remove(waiting, 1) :: Player
		if canReceive(nextPlayer) then
			assign(nextPlayer, plot)
			notify(nextPlayer, MESSAGES.Freed, "Info")
			break
		end
	end
end

local function onProfileLoaded(player: Player)
	if not canReceive(player) or table.find(waiting, player) then
		return
	end
	local plot = firstFreePlot()
	if plot then
		assign(player, plot)
		return
	end
	table.insert(waiting, player)
	if #plots == 0 then
		return -- déjà signalé à l'Init
	end
	warn(
		`[PlotService] {player.Name} : aucune parcelle libre ({#plots} prise(s)), il attend la prochaine. Plus de joueurs que de parcelles : régler « Max Players » sur {#plots} dans les paramètres du jeu`
	)
	notify(player, MESSAGES.Waiting, "Warning")
end

local function onPlayerRemoving(player: Player)
	leaving[player] = true
	local index = table.find(waiting, player)
	if index then
		table.remove(waiting, index)
	end
	release(player)
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------

function PlotService.GetPlot(player: Player): Model?
	return plotOf[player]
end

function PlotService.GetOwner(plot: Model): Player?
	return ownerOf[plot]
end

function PlotService.OnPlotAssigned(listener: PlotListener): () -> ()
	local disconnect = subscribe(assignedListeners, listener)
	for player, plot in table.clone(plotOf) do
		task.spawn(listener, player, plot)
	end
	return disconnect
end

function PlotService.OnPlotReleased(listener: PlotListener): () -> ()
	return subscribe(releasedListeners, listener)
end

function PlotService.TeleportHome(player: Player, canMove: (() -> boolean)?): boolean
	local plot = plotOf[player]
	local character = player.Character
	if plot == nil or character == nil or not character:IsDescendantOf(Workspace) then
		return false
	end
	return moveCharacter(player, character, plot, canMove)
end

function PlotService.GetPlots(): { Model }
	return table.clone(plots)
end

function PlotService.GetPlotByIndex(index: number): Model?
	for _, plot in plots do
		if indexOf[plot] == index then
			return plot
		end
	end
	return nil
end

function PlotService.PutOutside(player: Player, plot: Model): boolean
	local character = player.Character
	if character == nil or not character:IsDescendantOf(Workspace) or spawnRefs[plot] == nil then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid?
	if root == nil or not root:IsA("BasePart") or humanoid == nil or humanoid.Health <= 0 then
		return false
	end
	local rootPart = root :: BasePart
	local ground, out = outsideSpot(plot)
	-- R15 : HipHeight = du bas du HumanoidRootPart au sol ; R6 : jambes de 2 studs.
	local hip = if humanoid.RigType == Enum.HumanoidRigType.R15 then humanoid.HipHeight else 2
	local position = ground + Vector3.new(0, hip + rootPart.Size.Y / 2 + SPAWN_LIFT, 0)
	local target = CFrame.lookAt(position, position + out)
	character:PivotTo(target * rootPart.CFrame:ToObjectSpace(character:GetPivot()))
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero
	return true
end

function PlotService.Init()
	plots = collectPlots()
	local list = {}
	for _, plot in plots do
		plot:SetAttribute(OWNER_ATTRIBUTE, 0)
		setupSign(plot)
		updateSign(plot)
		findSpawnRefs(plot)
		table.insert(list, `{indexOf[plot]} {plot.Name}`)
	end
	if #plots == 0 then
		warn(`[PlotService] aucune parcelle taggée {PLOT_TAG} dans le Workspace : aucun joueur n'aura de parcelle`)
	else
		print(`[PlotService] {#plots} parcelle(s) : {table.concat(list, ", ")}`)
	end

	-- Départ : libère la parcelle ou retire le joueur de la file d'attente.
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	-- Appelé aussi pour les profils déjà chargés.
	DataService.OnProfileLoaded(onProfileLoaded)
end

return PlotService
