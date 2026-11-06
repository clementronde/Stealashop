--!strict
-- DisplayService (DEV-020) : présentoirs, objets exposés, halos, billboards, revenus et caisse
-- (Partie 1, sections 5.6, 5.8, 7.1, 7.3, 7.5, 9.4 et 9.5).
--
-- Rôle :
--   - expose les objets du profil sur les présentoirs de la parcelle de leur propriétaire :
--     Display["n"] = uid (9.5, numéro écrit en texte) pose l'objet Items[uid] sur l'Attachment
--     DisplaySlot_0n de la parcelle (10.4). Présentoirs débloqués = Balance.Display.StartSlots
--     (4) + niveau Upgrades.DisplaySlots du profil, au plus Balance.Display.MaxSlots (20) ;
--   - pour chaque objet exposé : le modèle ITM_<ItemId> de Clément s'il est livré
--     (ReplicatedStorage/Assets/Items, sous-dossiers permis), sinon un bloc V0 à la couleur de
--     sa rareté ; autour, le halo de sa rareté (5.6) ; au-dessus, le billboard BB_Item de Clément
--     (ReplicatedStorage/Assets/UI, contrat 2.2 : ItemName, Rarity, Income), sinon un billboard
--     V0. Tout est créé par le serveur dans la parcelle : visible par tous les joueurs ;
--   - revenus : chaque objet exposé rapporte Formulas.ItemIncome(zone, rareté) $/s (7.1), zone
--     et rareté lues dans Config.Items. L'argent s'accumule au temps exact dans la caisse de la
--     parcelle, pas dans Cash. Quand le propriétaire marche sur son CashPad, la caisse passe dans
--     son argent (DataService.AddCash) et repart de 0 (5.8). L'argent en caisse n'est pas
--     volable : rien ne permet à un autre joueur de le prendre ;
--   - remote PlaceItem(itemUid, slotIndex) (9.4), validé ici.
--
-- Le profil fait foi : Display et Items décident de ce qui est exposé, l'affichage suit. Après
-- chaque changement fait par ce service, et une fois par seconde, l'affichage est remis d'accord
-- avec le profil. Une entrée de Display invalide (objet absent de Items ou inconnu du catalogue,
-- présentoir verrouillé ou absent de la parcelle, objet rangé au coffre-fort ou déjà exposé
-- ailleurs) est retirée de Display, avec un avertissement : l'objet reste dans Items, donc dans
-- l'inventaire. Un objet de Items qui n'est ni exposé ni au coffre-fort est dans l'inventaire.
--
-- Attributs posés par ce service (lus par DisplayController et, plus tard, par le HUD) :
--   sur le Player :
--     Income (number)                $/s total des objets exposés
--     CashCollected (number)         argent encaissé au CashPad depuis l'arrivée sur le serveur
--                                    (il ne fait que monter : chaque hausse = un encaissement)
--     DisplaySlotsUnlocked (number)  présentoirs débloqués (4 à 20)
--   sur la parcelle :
--     CashRegister (number)          argent en caisse, en dollars entiers ; 0 si libre
--   sur chaque objet exposé (Model `DisplayItem_<nn>`, tag de code `DisplayItem`, rangé dans le
--   dossier `DisplayItems` de la parcelle) :
--     ItemUid, ItemId, Rarity, Halo, Income, DisplaySlot, OwnerUserId, Placeholder (bloc V0)
--
-- API (côté serveur) :
--   DisplayService.PlaceAuto(player, itemUid, near?) -> number?
--       Expose l'objet Items[itemUid] (déjà dans le profil) sur le présentoir libre et débloqué
--       le plus proche de `near` (par défaut : le personnage, donc l'établi où il vient d'ouvrir
--       son colis), sinon sur le premier libre. Renvoie le numéro du présentoir, son présentoir
--       actuel s'il est déjà exposé, ou nil (tout est pris, pas de parcelle, objet inconnu ou au
--       coffre-fort) : l'objet reste alors dans Items. Sans yield. N'envoie aucun message :
--       à l'appelant de prévenir le joueur.
--   DisplayService.PlaceItem(player, itemUid, slotIndex) -> (boolean, PlaceError?)
--       Expose l'objet sur ce présentoir (ou l'y déplace s'il est exposé ailleurs). Mêmes règles
--       que le remote PlaceItem, sans le contrôle de position (pour le code serveur : retour d'un
--       objet volé sur son présentoir d'origine, 6.1). Sans yield.
--   DisplayService.Unplace(player, itemUid) -> number?
--       Retire l'objet de son présentoir ; il reste dans Items (inventaire). Renvoie le numéro du
--       présentoir libéré, nil s'il n'était pas exposé. Sans yield. À appeler AVANT de retirer un
--       objet de Items (vol PvP, receleur) ; sinon il disparaît quand même du présentoir à la
--       mise à jour suivante (au plus 1 s).
--   DisplayService.GetIncome(player) -> number      $/s total exposé (0 sans parcelle)
--   DisplayService.GetRegister(player) -> number    argent en caisse, en dollars entiers
--   DisplayService.CashOut(player) -> number
--       Vide la caisse dans l'argent du joueur, sans passer par le CashPad ; renvoie le montant.
--   DisplayService.OnCashOut(listener) -> déconnexion
--       listener(player, amount, source) après chaque encaissement : source = "Pad" (CashPad),
--       "Leave" (départ du joueur) ou "Api" (CashOut). Pour le tutoriel et la télémétrie
--       (« Premier encaissement », 14.2).
--
-- Remote PlaceItem(itemUid, slotIndex) : refusé (Notify « Warning » au joueur, avertissement en
-- Studio) si le joueur n'a pas de parcelle, n'est pas dans le volume Bounds de sa parcelle, ne
-- possède pas l'objet, l'a rangé au coffre-fort, ou si le présentoir est verrouillé, absent ou
-- déjà occupé. Un objet déjà exposé sur un autre présentoir y est déplacé.
--
-- Choix V0 (marqués « V0 proposé, absent du doc » plus bas) :
--   - encaissement à chaque arrivée sur le CashPad : Touched par le personnage du propriétaire,
--     ou HumanoidRootPart au-dessus du tapis (contrôlé 10 fois par seconde, pour un tapis sans
--     CanTouch). Rester dessus n'encaisse pas davantage : on ressort et on y remonte. La caisse
--     donne des dollars entiers, les centimes restent dans la caisse ;
--   - départ du joueur : sa caisse est encaissée automatiquement dans son argent, juste avant la
--     sauvegarde (DataService.OnProfileReleasing). Il ne perd pas ce qu'il a gagné, et aucun
--     champ n'est ajouté au schéma 9.5. Pas de revenus hors ligne (Partie 2) ;
--   - zone d'un Secret : le catalogue ne lui en donne pas, et Items[uid] ne la stocke pas (9.5).
--     Ce service lit un champ Zone dans Items[uid] s'il existe, sinon prend la zone 1.
--
-- Tester dans Studio : rapport de l'agent a14 (notes partagées) ou fin de ce fichier.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Formulas = require(ReplicatedStorage.Shared.Config.Formulas)
local ItemsConfig = require(ReplicatedStorage.Shared.Config.Items)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Find = require(ReplicatedStorage.Shared.Contract.Find)
local UI = require(ReplicatedStorage.Shared.Contract.UI)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local ProfileTypes = require(ReplicatedStorage.Shared.Types.Profile)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

type Data = ProfileTypes.Data
type ItemEntry = ProfileTypes.Item
type ItemDef = ItemsConfig.Item
type Rarity = Rarities.Rarity

export type CashOutSource = "Pad" | "Leave" | "Api"
export type CashOutListener = (player: Player, amount: number, source: CashOutSource) -> ()
export type PlaceError = "NoProfile" | "NoPlot" | "UnknownItem" | "InVault" | "NoSlot" | "Locked" | "Taken" | "NotOnPlot"

local IS_STUDIO = RunService:IsStudio()

-- Contrat 10.4 (parcelle) : présentoirs, tapis de caisse et volume de la parcelle, cherchés
-- parmi les descendants (règle Contract/Find).
local SLOT_FORMAT = "DisplaySlot_%02d" -- Attachments DisplaySlot_01 à DisplaySlot_20
local CASH_PAD = "CashPad"
local BOUNDS = "Bounds"
-- Contrat 2.2 : billboard modèle d'un objet exposé et ses 3 champs.
local ITEM_BILLBOARD = "BB_Item"
local BILLBOARD_FIELDS = { "ItemName", "Rarity", "Income" }
-- Rangement des modèles finis (2.1 : ReplicatedStorage/Assets/<Catégorie>) : ITM_<ItemId>.
local ASSETS = "Assets"
local ITEMS_FOLDER = "Items"

-- Attributs posés par ce service (voir l'en-tête).
local INCOME_ATTRIBUTE = "Income"
local COLLECTED_ATTRIBUTE = "CashCollected"
local SLOTS_ATTRIBUTE = "DisplaySlotsUnlocked"
local REGISTER_ATTRIBUTE = "CashRegister"

-- Objets créés par ce service. Aucun n'est un nom du contrat 10.4 : ils ne gênent pas les
-- recherches des autres services dans la parcelle.
local FOLDER_NAME = "DisplayItems"
local MODEL_FORMAT = "DisplayItem_%02d"
local DISPLAY_TAG = "DisplayItem" -- tag de code, pas un tag de la map : lu par DisplayController
local HALO_PART = "RarityHalo"
local BILLBOARD_POINT = "BillboardPoint"
local RAYS_CENTER = "RaysCenter"
local RAY_FORMAT = "Ray_%02d"
local RAINBOW_GRADIENT = "RarityRainbow"

-- V0 proposé, absent du doc : cadence de la mise à jour de la caisse (attribut CashRegister) et
-- de l'affichage. Les revenus, eux, comptent au temps exact, quelle que soit cette cadence.
local REFRESH_INTERVAL = 1
-- V0 proposé, absent du doc : cadence du contrôle « debout sur le CashPad » (Touched déclenche
-- aussi l'encaissement tout de suite, pour un joueur rapide qui traverse le tapis sans s'arrêter).
local PAD_CHECK_INTERVAL = 0.1
-- V0 proposé, absent du doc : volume où l'on encaisse : l'emprise du tapis élargie de PAD_MARGIN,
-- de PAD_BELOW sous son dessus à PAD_ABOVE au-dessus (le HumanoidRootPart d'un R15 debout est à
-- environ 3 studs du sol).
local PAD_MARGIN = 0.5
local PAD_BELOW = 1
local PAD_ABOVE = 6
-- V0 proposé, absent du doc : zone de revenu d'un Secret sans zone enregistrée (voir l'en-tête).
local SECRET_FALLBACK_ZONE = 1

-- V0 proposé, absent du doc : bloc de remplacement d'un objet pas encore livré, à la taille d'un
-- objet exposé (environ 1,5 à 2 studs de haut, planche 10.6).
local PLACEHOLDER_SIZE = Vector3.new(1.2, 1.6, 1.2)

-- V0 proposé, absent du doc : billboard de remplacement tant que BB_Item n'est pas livré.
-- Taille en studs (échelle d'un BillboardGui), posé au-dessus du sommet de l'objet.
local BILLBOARD_SIZE = UDim2.fromScale(5, 2.4)
local BILLBOARD_LIFT = 1.4
local BILLBOARD_MAX_DISTANCE = 60
local TEXT_COLOR = Color3.new(1, 1, 1)
local OUTLINE_COLOR = Color3.fromHex("#1B1B24") -- contour du texte, planche 10.6
local INCOME_COLOR = Color3.fromHex("#35C93B") -- vert « acheter / OK », planche 10.6

-- V0 proposé, absent du doc : halo de rareté par palier (5.6 : « particules et lumière de la
-- couleur de la rareté, plus denses à chaque palier » ; Commun : aucun). Texture de particule
-- par défaut de Roblox (étincelles) en attendant les textures de halo de Clément (MOD-041).
type HaloSpec = {
	Brightness: number, -- PointLight
	Range: number,
	Rate: number, -- particules par seconde
	Size: number, -- taille d'une particule à sa naissance, en studs
	Rays: number, -- rayons de lumière derrière l'objet (0 = aucun)
}
local HALOS: { [string]: HaloSpec } = {
	Light = { Brightness = 0.8, Range = 6, Rate = 3, Size = 0.2, Rays = 0 }, -- Peu commun
	Clear = { Brightness = 1.5, Range = 8, Rate = 8, Size = 0.3, Rays = 0 }, -- Rare, Épique
	Rays = { Brightness = 2.5, Range = 12, Rate = 14, Size = 0.35, Rays = 8 }, -- Légendaire, Mythique
	Rainbow = { Brightness = 3, Range = 14, Rate = 20, Size = 0.4, Rays = 10 }, -- Secret
}
local HALO_MARGIN = 0.3 -- écart entre l'objet et le volume d'où partent les particules
local PARTICLE_LIFETIME = NumberRange.new(0.9, 1.5)
local PARTICLE_SPEED = NumberRange.new(0.3, 0.8)
local PARTICLE_RISE = Vector3.new(0, 0.6, 0)
local RAY_REACH = 1.2 -- les rayons dépassent l'objet de cette longueur
local RAY_START_WIDTH = 0.05
local RAY_END_WIDTH = 0.4 -- × longueur du rayon

-- Messages lus par le joueur (Notify « Warning ») quand PlaceItem est refusé. Les refus qui ne
-- viennent pas d'un joueur honnête (objet qui n'est pas à lui, profil absent) restent muets.
local MESSAGES: { [string]: string } = {
	NoPlot = "Tu n'as pas encore de boutique : attends qu'une parcelle se libère.",
	NotOnPlot = "Reviens dans ta boutique pour exposer un objet.",
	InVault = "Cet objet est dans ton coffre-fort.",
	NoSlot = "Ce présentoir n'existe pas.",
	Locked = "Ce présentoir n'est pas encore débloqué : améliore tes présentoirs.",
	Taken = "Ce présentoir est déjà occupé.",
}

local SOURCE_LABELS: { [string]: string } = {
	Pad = "tapis de caisse",
	Leave = "départ du joueur",
	Api = "CashOut",
}

type Visual = {
	model: Model,
	uid: string,
	itemId: string,
	income: number,
}

-- Ce qui est affiché sur une parcelle, et pour qui.
type View = {
	owner: Player,
	folder: Folder,
	visuals: { [number]: Visual }, -- [numéro de présentoir]
}

-- Pièces du contrat d'une parcelle, trouvées une fois avant d'y poser des objets.
type PlotRefs = {
	slots: { [number]: Attachment? }, -- nil : présentoir absent de la parcelle
	pads: { BasePart },
	bounds: BasePart?,
}

-- Argent d'un joueur : revenu courant et caisse.
type Account = {
	plot: Model?,
	income: number, -- $/s
	register: number, -- $ en caisse, centimes compris
	lastAccrue: number, -- os.clock() du dernier ajout à la caisse
	collected: number, -- argent encaissé depuis l'arrivée (attribut CashCollected)
	onPad: boolean,
	shownRegister: number?,
	shownSlots: number?,
}

local DisplayService = {}

local accounts: { [Player]: Account } = {}
local views: { [Model]: View } = {}
local refsOf: { [Model]: PlotRefs } = {}
local cashOutListeners: { CashOutListener } = {}
local reported: { [string]: boolean } = {}
local padClock = 0
local refreshClock = 0

------------------------------------------------------------------------------
-- Aides
------------------------------------------------------------------------------

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

-- Un message par clé et par serveur : "warn" partout, "print" en Studio seulement.
local function reportOnce(key: string, message: string, level: "print" | "warn")
	if reported[key] then
		return
	end
	reported[key] = true
	if level == "warn" then
		warn(message)
	elseif IS_STUDIO then
		print(message)
	end
end

local function notify(player: Player, message: string, kind: string)
	local ok, err = pcall(function()
		Net.Server.Notify:Fire(player, message, kind)
	end)
	if not ok then
		warn(`[DisplayService] Notify vers {player.Name} : {err}`)
	end
end

-- Tronque à une décimale, virgule française, sans « ,0 » : 12.46 -> « 12,4 ».
local function oneDecimal(value: number): string
	local tenths = math.floor(value * 10 + 1e-9)
	local whole, decimal = tenths // 10, tenths % 10
	if decimal == 0 then
		return string.format("%d", whole)
	end
	return string.format("%d,%d", whole, decimal)
end

-- Espace entre les milliers : 1234567 -> « 1 234 567 ».
local function groupThousands(value: number): string
	local digits = string.format("%d", math.floor(value))
	local grouped = string.reverse((string.gsub(string.reverse(digits), "(%d%d%d)", "%1 ")))
	return (string.gsub(grouped, "^ ", ""))
end

-- Montant lisible, à la façon du doc : « 300 $ », « 12,4 K$ », « 120 K$ », « 2 M$ », « 3 Md$ ».
-- Toujours arrondi vers le bas : on n'affiche jamais plus que ce qu'il y a.
local MONEY_UNITS = {
	{ Value = 1e9, Suffix = "Md$" },
	{ Value = 1e6, Suffix = "M$" },
	{ Value = 1e3, Suffix = "K$" },
}
local function formatMoney(amount: number): string
	if amount ~= amount or amount < 0 then
		amount = 0
	end
	for i, unit in MONEY_UNITS do
		if amount >= unit.Value then
			local scaled = amount / unit.Value
			if scaled < 100 then
				return `{oneDecimal(scaled)} {unit.Suffix}`
			elseif scaled < 1000 or i == 1 then
				return `{groupThousands(scaled)} {unit.Suffix}`
			end
		end
	end
	return `{groupThousands(amount)} $`
end

------------------------------------------------------------------------------
-- Profil et catalogue
------------------------------------------------------------------------------

local function unlockedSlots(data: Data): number
	local level = data.Upgrades.DisplaySlots
	local bought = if type(level) == "number" and level == level then math.max(0, math.floor(level)) else 0
	return math.min(Balance.Display.StartSlots + bought, Balance.Display.MaxSlots)
end

local function isInVault(data: Data, uid: string): boolean
	for _, stored in data.Vault do
		if stored == uid then
			return true
		end
	end
	return false
end

-- Présentoir où l'objet est exposé, d'après le profil.
local function slotOf(data: Data, uid: string): number?
	for key, stored in data.Display do
		if stored == uid then
			return tonumber(key)
		end
	end
	return nil
end

-- L'objet du profil et sa fiche du catalogue (nil, nil si l'un des deux manque).
local function lookup(data: Data, uid: string): (ItemEntry?, ItemDef?)
	local entry = data.Items[uid]
	if type(entry) ~= "table" then
		return nil, nil
	end
	local def = ItemsConfig.ById[entry.Id]
	if def == nil or Rarities.ById[def.Rarity] == nil then
		return entry, nil
	end
	return entry, def
end

local function validZone(value: any): number?
	if type(value) == "number" and value % 1 == 0 and Zones[value] ~= nil then
		return value
	end
	return nil
end

-- Zone du revenu : celle du catalogue ; pour un Secret (aucune zone au catalogue), le champ Zone
-- de Items[uid] s'il existe, sinon SECRET_FALLBACK_ZONE.
local function itemZone(def: ItemDef, entry: ItemEntry, uid: string): number
	local zone = def.Zone
	if zone then
		return zone
	end
	local stored = validZone((entry :: any).Zone)
	if stored then
		return stored
	end
	reportOnce(
		`zone:{uid}`,
		`[DisplayService] objet {uid} ({def.Id}) sans zone : revenu calculé en zone {SECRET_FALLBACK_ZONE} (V0). Pour un Secret, enregistrer Zone dans Items[uid]`,
		"warn"
	)
	return SECRET_FALLBACK_ZONE
end

-- Revenu d'un objet ($/s), formule 7.1 (M global = 1 au MVP).
local function itemIncome(def: ItemDef, entry: ItemEntry, uid: string): number
	return Formulas.ItemIncome(itemZone(def, entry, uid), def.Rarity)
end

------------------------------------------------------------------------------
-- Parcelle
------------------------------------------------------------------------------

-- Présentoirs, tapis de caisse et volume de la parcelle. Cherchés une seule fois, avant que ce
-- service y pose des objets (dont les pièces pourraient porter les mêmes noms).
local function refsFor(plot: Model): PlotRefs
	local cached = refsOf[plot]
	if cached then
		return cached
	end

	local slots: { [number]: Attachment? } = {}
	local missing: { string } = {}
	for index = 1, Balance.Display.MaxSlots do
		local name = string.format(SLOT_FORMAT, index)
		local found = Find.path(plot, name)
		if found ~= nil and found:IsA("Attachment") then
			slots[index] = found :: Attachment
		else
			table.insert(missing, name)
		end
	end
	if #missing > 0 then
		warn(
			`[DisplayService] {plot:GetFullName()} : {#missing} présentoir(s) absent(s) ou qui ne sont pas des Attachments (contrat 10.4) : {table.concat(missing, ", ")}`
		)
	end

	local pads: { BasePart } = {}
	local pad = Find.path(plot, CASH_PAD)
	if pad ~= nil and pad:IsA("BasePart") then
		table.insert(pads, pad :: BasePart)
	elseif pad ~= nil then
		for _, descendant in pad:GetDescendants() do
			if descendant:IsA("BasePart") then
				table.insert(pads, descendant :: BasePart)
			end
		end
	end
	if #pads == 0 then
		warn(`[DisplayService] {plot:GetFullName()} : pas de {CASH_PAD} (contrat 10.4), son propriétaire ne pourra pas encaisser`)
	end

	local bounds = Find.path(plot, BOUNDS)
	local refs: PlotRefs = {
		slots = slots,
		pads = pads,
		bounds = if bounds ~= nil and bounds:IsA("BasePart") then bounds :: BasePart else nil,
	}
	refsOf[plot] = refs
	return refs
end

-- HumanoidRootPart d'un personnage vivant, ou nil.
local function rootOf(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil
	end
	return root :: BasePart
end

local function isInsidePart(part: BasePart, position: Vector3): boolean
	local p = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z
end

-- Le joueur est-il dans sa parcelle ? Volume Bounds (10.4), sinon emprise de la parcelle.
local function isOnPlot(player: Player, plot: Model, refs: PlotRefs): boolean
	local root = rootOf(player)
	if root == nil then
		return false
	end
	local bounds = refs.bounds
	if bounds then
		return isInsidePart(bounds, root.Position)
	end
	local boxCFrame, boxSize = plot:GetBoundingBox()
	local p = boxCFrame:PointToObjectSpace(root.Position)
	return math.abs(p.X) <= boxSize.X / 2 and math.abs(p.Z) <= boxSize.Z / 2
end

local function isOnPad(position: Vector3, pads: { BasePart }): boolean
	for _, pad in pads do
		local p = pad.CFrame:PointToObjectSpace(position)
		local half = pad.Size / 2
		if
			math.abs(p.X) <= half.X + PAD_MARGIN
			and math.abs(p.Z) <= half.Z + PAD_MARGIN
			and p.Y >= half.Y - PAD_BELOW
			and p.Y <= half.Y + PAD_ABOVE
		then
			return true
		end
	end
	return false
end

------------------------------------------------------------------------------
-- Objet exposé : modèle, halo, billboard
------------------------------------------------------------------------------

local function itemTemplate(def: ItemDef): Instance?
	local assets = ReplicatedStorage:FindFirstChild(ASSETS)
	local folder = if assets then assets:FindFirstChild(ITEMS_FOLDER) else nil
	if folder == nil then
		return nil
	end
	return folder:FindFirstChild(def.Asset, true)
end

local function billboardTemplate(): BillboardGui?
	local current: Instance? = ReplicatedStorage
	for _, name in UI.BillboardFolder do
		current = if current then current:FindFirstChild(name) else nil
	end
	local found = if current then current:FindFirstChild(ITEM_BILLBOARD) else nil
	if found ~= nil and found:IsA("BillboardGui") then
		return found :: BillboardGui
	end
	return nil
end

local function placeholderModel(rarity: Rarity): Model
	local model = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = PLACEHOLDER_SIZE
	root.Color = rarity.Color
	root.Material = Enum.Material.SmoothPlastic
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	-- Pivot en bas au centre, comme un objet de Clément (10.4).
	root.PivotOffset = CFrame.new(0, -PLACEHOLDER_SIZE.Y / 2, 0)
	root.Parent = model
	model.PrimaryPart = root
	return model
end

-- Copie du modèle ITM_ de Clément, ancrée et sans script ; nil si l'objet n'est pas livré.
local function copyOfTemplate(def: ItemDef): Model?
	local template = itemTemplate(def)
	if template == nil then
		reportOnce(
			`model:{def.Asset}`,
			`[DisplayService] {def.Asset} pas encore livré dans ReplicatedStorage/{ASSETS}/{ITEMS_FOLDER} : bloc V0 à la couleur de sa rareté`,
			"print"
		)
		return nil
	end
	local copy = template:Clone() :: Instance?
	local model: Model? = nil
	if copy ~= nil and copy:IsA("Model") then
		model = copy :: Model
	elseif copy ~= nil and copy:IsA("BasePart") then
		local wrapper = Instance.new("Model")
		copy.Parent = wrapper
		wrapper.PrimaryPart = copy :: BasePart
		model = wrapper
	elseif copy ~= nil then
		copy:Destroy()
	end
	if model == nil then
		reportOnce(
			`bad:{def.Asset}`,
			`[DisplayService] {template:GetFullName()} : ni un Model ni une pièce, ou non copiable (Archivable) ; contrat 10.4 : Model avec PrimaryPart Root. Bloc V0 à la place`,
			"warn"
		)
		return nil
	end
	local scripts = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			scripts += 1
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			part.Anchored = true
		end
	end
	if scripts > 0 then
		reportOnce(
			`scripts:{def.Asset}`,
			`[DisplayService] {template:GetFullName()} : {scripts} script(s) retiré(s) de la copie exposée (10.4 : aucun script dans un objet ITM_)`,
			"warn"
		)
	end
	return model
end

local function rarityColors(rarity: Rarity): { Color3 }
	local colors = rarity.RainbowColors
	if rarity.Rainbow and colors and #colors > 0 then
		return colors
	end
	return { rarity.Color }
end

local function colorSequence(colors: { Color3 }): ColorSequence
	if #colors == 1 then
		return ColorSequence.new(colors[1])
	end
	local keypoints = {}
	for i, color in colors do
		table.insert(keypoints, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), color))
	end
	return ColorSequence.new(keypoints)
end

local function fade(from: number, to: number): NumberSequence
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, from), NumberSequenceKeypoint.new(1, to) })
end

-- Halo de rareté (5.6) : un volume invisible autour de l'objet, avec une lumière, des
-- particules qui en partent et, du Légendaire au Secret, des rayons derrière l'objet
-- (DisplayController les fait tourner et anime l'arc-en-ciel du Secret, côté client).
local function addHalo(model: Model, rarity: Rarity, boxCFrame: CFrame, boxSize: Vector3)
	local spec = HALOS[rarity.Halo]
	if spec == nil then
		return -- Commun : aucun halo
	end
	local colors = rarityColors(rarity)

	local part = Instance.new("Part")
	part.Name = HALO_PART
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = boxSize + Vector3.one * (2 * HALO_MARGIN)
	part.CFrame = boxCFrame

	local light = Instance.new("PointLight")
	light.Name = "HaloLight"
	light.Color = colors[1]
	light.Brightness = spec.Brightness
	light.Range = spec.Range
	light.Shadows = false
	light.Parent = part

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "HaloSparkles"
	sparkles.Color = colorSequence(colors)
	sparkles.LightEmission = 1
	sparkles.LightInfluence = 0
	sparkles.Rate = spec.Rate
	sparkles.Lifetime = PARTICLE_LIFETIME
	sparkles.Speed = PARTICLE_SPEED
	sparkles.Acceleration = PARTICLE_RISE
	sparkles.Size = fade(spec.Size, 0)
	sparkles.Transparency = fade(0.2, 1)
	sparkles.Rotation = NumberRange.new(0, 360)
	sparkles.RotSpeed = NumberRange.new(-90, 90)
	sparkles.Shape = Enum.ParticleEmitterShape.Box
	sparkles.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	sparkles.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	sparkles.Parent = part

	if spec.Rays > 0 then
		-- Dans le plan de la face avant, juste derrière l'objet (sa face avant regarde −Z, 10.1).
		local radius = math.max(boxSize.X, boxSize.Y) / 2 + RAY_REACH
		local center = Instance.new("Attachment")
		center.Name = RAYS_CENTER
		center.Position = Vector3.new(0, 0, boxSize.Z / 2 + HALO_MARGIN)
		center.Parent = part
		for i = 1, spec.Rays do
			local angle = (i - 1) * 2 * math.pi / spec.Rays
			local tip = Instance.new("Attachment")
			tip.Name = string.format(RAY_FORMAT, i)
			tip.Position = center.Position + Vector3.new(math.cos(angle) * radius, math.sin(angle) * radius, 0)
			tip.Parent = part

			local beam = Instance.new("Beam")
			beam.Name = "RayBeam"
			beam.Attachment0 = center
			beam.Attachment1 = tip
			beam.Color = ColorSequence.new(colors[(i - 1) % #colors + 1])
			beam.Width0 = RAY_START_WIDTH
			beam.Width1 = radius * RAY_END_WIDTH
			beam.Transparency = fade(0.35, 1)
			beam.LightEmission = 1
			beam.LightInfluence = 0
			beam.FaceCamera = true
			beam.Segments = 1
			beam.Parent = tip
		end
	end

	part.Parent = model
end

local function makeBillboard(): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = ITEM_BILLBOARD
	gui.Size = BILLBOARD_SIZE
	gui.StudsOffset = Vector3.new(0, BILLBOARD_LIFT, 0)
	gui.MaxDistance = BILLBOARD_MAX_DISTANCE
	gui.LightInfluence = 0
	for i, name in BILLBOARD_FIELDS do
		local label = Instance.new("TextLabel")
		label.Name = name
		label.Size = UDim2.fromScale(1, 1 / #BILLBOARD_FIELDS)
		label.Position = UDim2.fromScale(0, (i - 1) / #BILLBOARD_FIELDS)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
		label.TextColor3 = if name == "Income" then INCOME_COLOR else TEXT_COLOR
		label.TextStrokeColor3 = OUTLINE_COLOR
		label.TextStrokeTransparency = 0
		label.Text = ""
		label.Parent = gui
	end
	return gui
end

-- Écrit `text` dans l'élément texte `name` du billboard ; renvoie l'élément, nil s'il manque.
local function setText(gui: Instance, name: string, text: string, color: Color3?): GuiObject?
	local element = Find.path(gui, name)
	if element == nil or not (element:IsA("TextLabel") or element:IsA("TextButton") or element:IsA("TextBox")) then
		return nil
	end
	local textElement = element :: any
	textElement.Text = text
	if color then
		textElement.TextColor3 = color
	end
	return element :: GuiObject
end

-- Billboard visible par tous : nom, rareté (couleur), $/s (5.8). Accroché au sommet de l'objet.
local function addBillboard(model: Model, def: ItemDef, rarity: Rarity, income: number, boxCFrame: CFrame, boxSize: Vector3)
	local anchor = model.PrimaryPart or (model:FindFirstChildWhichIsA("BasePart", true) :: BasePart?)
	if anchor == nil then
		return
	end
	local point = Instance.new("Attachment")
	point.Name = BILLBOARD_POINT
	point.Parent = anchor
	point.WorldPosition = boxCFrame.Position + Vector3.new(0, boxSize.Y / 2, 0)

	local template = billboardTemplate()
	local gui: BillboardGui? = if template then template:Clone() :: BillboardGui? else nil
	if gui == nil then
		reportOnce(
			"billboard",
			`[DisplayService] {ITEM_BILLBOARD} pas encore livré dans ReplicatedStorage/{table.concat(UI.BillboardFolder, "/")} : billboard V0 au-dessus des objets exposés`,
			"print"
		)
		gui = makeBillboard()
	end
	local billboard = gui :: BillboardGui
	billboard.Name = ITEM_BILLBOARD
	billboard.Adornee = point

	setText(billboard, "ItemName", def.DisplayName)
	setText(billboard, "Income", `{formatMoney(income)}/s`)
	local rarityLabel = setText(billboard, "Rarity", rarity.DisplayNameUpper, if rarity.Rainbow then TEXT_COLOR else rarity.Color)
	-- Secret : arc-en-ciel (DisplayController le fait tourner). Un dégradé déjà posé par Clément
	-- sur ce texte est gardé.
	if rarity.Rainbow and rarityLabel and rarityLabel:FindFirstChildOfClass("UIGradient") == nil then
		local gradient = Instance.new("UIGradient")
		gradient.Name = RAINBOW_GRADIENT
		gradient.Color = colorSequence(rarityColors(rarity))
		gradient.Parent = rarityLabel
	end
	billboard.Parent = model
end

-- Construit l'objet exposé sur le présentoir `slot`, prêt à être rangé dans la parcelle.
local function buildVisual(owner: Player, refs: PlotRefs, slot: number, uid: string, entry: ItemEntry, def: ItemDef): Visual
	local rarity = Rarities.ById[def.Rarity]
	local income = itemIncome(def, entry, uid)
	local model = copyOfTemplate(def)
	local placeholder = model == nil
	local display = model or placeholderModel(rarity)
	display.Name = string.format(MODEL_FORMAT, slot)
	display:PivotTo((refs.slots[slot] :: Attachment).WorldCFrame) -- présentoir vérifié par sanitize

	local boxCFrame, boxSize = display:GetBoundingBox()
	addHalo(display, rarity, boxCFrame, boxSize)
	addBillboard(display, def, rarity, income, boxCFrame, boxSize)

	display:SetAttribute("ItemUid", uid)
	display:SetAttribute("ItemId", def.Id)
	display:SetAttribute("Rarity", def.Rarity)
	display:SetAttribute("Halo", rarity.Halo)
	display:SetAttribute("Income", income)
	display:SetAttribute("DisplaySlot", slot)
	display:SetAttribute("OwnerUserId", owner.UserId)
	display:SetAttribute("Placeholder", placeholder)
	CollectionService:AddTag(display, DISPLAY_TAG)
	return { model = display, uid = uid, itemId = def.Id, income = income }
end

------------------------------------------------------------------------------
-- Caisse
------------------------------------------------------------------------------

-- Ajoute à la caisse ce que les objets ont rapporté depuis le dernier ajout.
local function accrue(account: Account, now: number)
	local elapsed = now - account.lastAccrue
	if elapsed > 0 then
		account.register += account.income * elapsed
	end
	account.lastAccrue = now
end

-- Met à jour les attributs CashRegister (parcelle) et DisplaySlotsUnlocked (joueur) s'ils changent.
local function publish(player: Player, account: Account, data: Data?)
	local plot = account.plot
	if plot then
		local shown = math.floor(account.register)
		if shown ~= account.shownRegister then
			account.shownRegister = shown
			plot:SetAttribute(REGISTER_ATTRIBUTE, shown)
		end
	end
	if data then
		local slots = unlockedSlots(data)
		if slots ~= account.shownSlots then
			account.shownSlots = slots
			player:SetAttribute(SLOTS_ATTRIBUTE, slots)
		end
	end
end

-- Vide la caisse dans l'argent du joueur (dollars entiers, les centimes restent). Sans yield.
local function cashOut(player: Player, account: Account, source: CashOutSource): number
	accrue(account, os.clock())
	local amount = math.floor(account.register)
	if amount < 1 then
		return 0
	end
	local cash = DataService.AddCash(player, amount)
	if cash == nil then
		return 0 -- profil absent : l'argent reste en caisse
	end
	account.register -= amount
	account.collected += amount
	player:SetAttribute(COLLECTED_ATTRIBUTE, account.collected)
	publish(player, account, nil)
	if IS_STUDIO then
		print(`[DisplayService] {player.Name} encaisse {formatMoney(amount)} ({SOURCE_LABELS[source]}) : {formatMoney(cash)} en tout`)
	end
	for _, listener in table.clone(cashOutListeners) do
		task.spawn(listener, player, amount, source)
	end
	return amount
end

-- Appelle fn(...) sans laisser une erreur arrêter la boucle : elle est écrite une fois par clé.
local function guarded<A...>(key: string, label: string, fn: (A...) -> (), ...: A...)
	xpcall(fn, function(err: any)
		reportOnce(key, `[DisplayService] {label} : {err}`, "warn")
	end, ...)
end

------------------------------------------------------------------------------
-- Accord entre le profil et l'affichage
------------------------------------------------------------------------------

-- Retire de Display les entrées invalides (voir l'en-tête) et renvoie ce qu'il faut afficher :
-- { [numéro de présentoir] = uid }. Un uid exposé deux fois reste sur le plus petit numéro.
local function sanitize(player: Player, data: Data, refs: PlotRefs): { [number]: string }
	local unlocked = unlockedSlots(data)
	local valid: { [number]: string } = {}
	local drops: { { key: string, why: string } } = {}

	for key, uid in data.Display do
		local index = tonumber(key)
		local why: string? = nil
		if index == nil or index % 1 ~= 0 or tostring(index) ~= key or index < 1 or index > Balance.Display.MaxSlots then
			why = "numéro de présentoir invalide"
		elseif index > unlocked then
			why = `présentoir {index} verrouillé ({unlocked} débloqué(s))`
		elseif refs.slots[index] == nil then
			why = `présentoir {index} absent de la parcelle`
		elseif type(uid) ~= "string" then
			why = "uid invalide"
		else
			local entry, def = lookup(data, uid)
			if entry == nil then
				why = `objet {uid} absent de Items`
			elseif def == nil then
				why = `objet {uid} : ItemId « {tostring(entry.Id)} » inconnu du catalogue`
			elseif isInVault(data, uid) then
				why = `objet {uid} rangé au coffre-fort`
			end
		end
		if why then
			table.insert(drops, { key = key, why = why })
		else
			valid[index :: number] = uid
		end
	end

	local wanted: { [number]: string } = {}
	local seenAt: { [string]: number } = {}
	for index = 1, Balance.Display.MaxSlots do
		local uid = valid[index]
		if uid then
			local first = seenAt[uid]
			if first then
				table.insert(drops, { key = tostring(index), why = `objet {uid} déjà exposé sur le présentoir {first}` })
			else
				seenAt[uid] = index
				wanted[index] = uid
			end
		end
	end

	for _, drop in drops do
		data.Display[drop.key] = nil
		warn(`[DisplayService] {player.Name} : Display["{drop.key}"] retiré ({drop.why}) ; l'objet reste dans l'inventaire`)
	end
	return wanted
end

-- Remet l'affichage de la parcelle et le revenu d'accord avec le profil. Sans yield.
local function reconcile(player: Player, account: Account, data: Data, plot: Model)
	local view = views[plot]
	if view == nil or view.owner ~= player then
		return
	end
	local refs = refsFor(plot)
	local wanted = sanitize(player, data, refs)

	for slot, visual in view.visuals do
		local uid = wanted[slot]
		local entry = if uid then data.Items[uid] else nil
		if uid ~= visual.uid or entry == nil or entry.Id ~= visual.itemId then
			visual.model:Destroy()
			view.visuals[slot] = nil
		end
	end

	for slot, uid in wanted do
		if view.visuals[slot] == nil then
			local entry, def = lookup(data, uid)
			if entry and def then
				local ok, result = pcall(buildVisual, player, refs, slot, uid, entry, def)
				if ok then
					local visual = result :: Visual
					visual.model.Parent = view.folder
					view.visuals[slot] = visual
				else
					reportOnce(`build:{uid}`, `[DisplayService] {player.Name} : objet {uid} ({def.Id}) non affiché : {result}`, "warn")
				end
			end
		end
	end

	local income = 0
	for _, visual in view.visuals do
		income += visual.income
	end
	if income ~= account.income then
		accrue(account, os.clock()) -- l'ancien revenu compte jusqu'à maintenant
		account.income = income
		player:SetAttribute(INCOME_ATTRIBUTE, income)
	end
end

-- Compte et affichage du joueur sur sa parcelle (profil chargé et parcelle attribuée).
local function context(player: Player): (Data?, Account?, Model?)
	local data = DataService.Get(player)
	local account = accounts[player]
	local plot = if account then account.plot else nil
	if data == nil or account == nil or plot == nil then
		return data, account, nil
	end
	local view = views[plot]
	if view == nil or view.owner ~= player then
		return data, account, nil
	end
	return data, account, plot
end

local function describe(data: Data, uid: string, slot: number): string
	local _, def = lookup(data, uid)
	if def == nil then
		return `objet {uid} sur le présentoir {slot}`
	end
	return `{def.DisplayName} ({Rarities.ById[def.Rarity].DisplayName}) sur le présentoir {slot}`
end

------------------------------------------------------------------------------
-- Arrivée et départ
------------------------------------------------------------------------------

local function newAccount(): Account
	return {
		plot = nil,
		income = 0,
		register = 0,
		lastAccrue = os.clock(),
		collected = 0,
		onPad = false,
		shownRegister = nil,
		shownSlots = nil,
	}
end

local function clearView(plot: Model)
	local view = views[plot]
	if view then
		views[plot] = nil
		view.folder:Destroy()
	end
end

-- Touched d'un CashPad : encaissement immédiat quand le personnage du propriétaire y arrive.
-- Une connexion par tapis, pour toute la partie (les parcelles ne changent pas).
local padsConnected: { [Model]: boolean } = {}
local function connectPads(plot: Model, refs: PlotRefs)
	if padsConnected[plot] then
		return
	end
	padsConnected[plot] = true
	for _, pad in refs.pads do
		pad.Touched:Connect(function(hit: BasePart)
			local view = views[plot]
			if view == nil then
				return
			end
			local owner = view.owner
			local account = accounts[owner]
			local character = owner.Character
			if account == nil or account.onPad or account.plot ~= plot or character == nil then
				return
			end
			if not hit:IsDescendantOf(character) or rootOf(owner) == nil then
				return
			end
			account.onPad = true -- checkPads le remet à false quand il en sort
			cashOut(owner, account, "Pad")
		end)
	end
end

-- Installe la boutique sauvegardée du joueur sur sa parcelle. Sans yield.
local function install(player: Player, plot: Model)
	local data = DataService.Get(player)
	if data == nil or PlotService.GetPlot(player) ~= plot then
		return
	end
	local existing = views[plot]
	if existing and existing.owner == player then
		return -- déjà installée (attribution et chargement du profil arrivent tous les deux ici)
	end
	clearView(plot)
	connectPads(plot, refsFor(plot)) -- pièces cherchées avant d'y poser le moindre objet

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = plot
	views[plot] = { owner = player, folder = folder, visuals = {} }

	local current = accounts[player] or newAccount()
	accounts[player] = current
	accrue(current, os.clock())
	current.plot = plot
	current.onPad = false
	current.shownRegister = nil

	reconcile(player, current, data, plot)
	player:SetAttribute(INCOME_ATTRIBUTE, current.income)
	player:SetAttribute(COLLECTED_ATTRIBUTE, current.collected)
	publish(player, current, data)

	local count = 0
	for _ in (views[plot] :: View).visuals do
		count += 1
	end
	print(
		`[DisplayService] {player.Name} : {count} objet(s) exposé(s) sur {unlockedSlots(data)} présentoir(s) débloqué(s), revenu {formatMoney(current.income)}/s`
	)
end

local function onProfileLoaded(player: Player)
	local plot = PlotService.GetPlot(player)
	if plot then
		install(player, plot)
	end
end

-- Parcelle libérée (départ) : on retire tout ce qui y est affiché. La caisse reste dans le
-- compte du joueur jusqu'à OnProfileReleasing, qui l'encaisse (l'ordre des deux n'est pas garanti).
local function onPlotReleased(player: Player, plot: Model)
	clearView(plot)
	plot:SetAttribute(REGISTER_ATTRIBUTE, 0)
	local account = accounts[player]
	if account and account.plot == plot then
		accrue(account, os.clock())
		account.income = 0
		account.plot = nil
		account.onPad = false
	end
end

-- Départ : dernier moment pour écrire dans le profil. La caisse est encaissée (V0, en-tête).
local function onProfileReleasing(player: Player)
	local account = accounts[player]
	if account == nil then
		return
	end
	local amount = cashOut(player, account, "Leave")
	if amount > 0 then
		print(`[DisplayService] {player.Name} part : {formatMoney(amount)} de sa caisse encaissés automatiquement`)
	end
	accounts[player] = nil
end

local function onPlayerRemoving(player: Player)
	-- Profil encore ouvert : OnProfileReleasing va encaisser puis effacer le compte. Sinon (profil
	-- déjà fermé, repris par un autre serveur), il n'y a plus rien à sauvegarder.
	if not DataService.IsLoaded(player) then
		accounts[player] = nil
	end
end

------------------------------------------------------------------------------
-- Poser un objet
------------------------------------------------------------------------------

local function place(player: Player, itemUid: string, slot: number, fromClient: boolean): (boolean, PlaceError?)
	local data, account, plot = context(player)
	if data == nil then
		return false, "NoProfile"
	end
	if account == nil or plot == nil then
		return false, "NoPlot"
	end
	reconcile(player, account, data, plot)
	local entry, def = lookup(data, itemUid)
	if entry == nil or def == nil then
		return false, "UnknownItem"
	end
	if isInVault(data, itemUid) then
		return false, "InVault"
	end
	if slot % 1 ~= 0 or slot < 1 or slot > Balance.Display.MaxSlots then
		return false, "NoSlot"
	end
	if slot > unlockedSlots(data) then
		return false, "Locked"
	end
	local refs = refsFor(plot)
	if refs.slots[slot] == nil then
		return false, "NoSlot"
	end
	local key = tostring(slot)
	local occupant = data.Display[key]
	if occupant == itemUid then
		return true, nil
	end
	if occupant ~= nil then
		return false, "Taken"
	end
	if fromClient and not isOnPlot(player, plot, refs) then
		return false, "NotOnPlot"
	end

	local previous = slotOf(data, itemUid)
	if previous then
		data.Display[tostring(previous)] = nil
	end
	data.Display[key] = itemUid
	reconcile(player, account, data, plot)
	if IS_STUDIO then
		local moved = if previous then ` (déplacé du présentoir {previous})` else ""
		print(`[DisplayService] {player.Name} : {describe(data, itemUid, slot)}{moved}, revenu {formatMoney(account.income)}/s`)
	end
	return true, nil
end

local function onPlaceItem(player: Player, itemUid: string, slotIndex: number)
	local ok, reason = place(player, itemUid, slotIndex, true)
	if ok or reason == nil then
		return
	end
	if IS_STUDIO then
		warn(`[DisplayService] {player.Name} → PlaceItem({itemUid}, {slotIndex}) refusé : {reason}`)
	end
	local message = MESSAGES[reason]
	if message then
		notify(player, message, "Warning")
	end
end

------------------------------------------------------------------------------
-- Boucle : caisse, CashPad et affichage
------------------------------------------------------------------------------

local function checkPads()
	for player, account in accounts do
		local plot = account.plot
		if plot == nil then
			continue
		end
		local root = rootOf(player)
		local onPad = root ~= nil and isOnPad(root.Position, refsFor(plot).pads)
		if onPad and not account.onPad then
			cashOut(player, account, "Pad")
		end
		account.onPad = onPad
	end
end

local function refreshAll()
	local now = os.clock()
	for player, account in accounts do
		local data, _, plot = context(player)
		if data and plot then
			guarded(`reconcile:{player.UserId}`, `{player.Name} : mise à jour de l'affichage impossible`, reconcile, player, account, data, plot)
		end
		accrue(account, now)
		publish(player, account, data)
	end
end

-- Le reste de chaque intervalle est gardé (cadence juste en moyenne), sans rattrapage en rafale
-- après un ralentissement du serveur.
local function onHeartbeat(dt: number)
	padClock += dt
	refreshClock += dt
	if padClock >= PAD_CHECK_INTERVAL then
		padClock = math.min(padClock - PAD_CHECK_INTERVAL, PAD_CHECK_INTERVAL)
		guarded("checkPads", "contrôle des CashPad", checkPads)
	end
	if refreshClock >= REFRESH_INTERVAL then
		refreshClock = math.min(refreshClock - REFRESH_INTERVAL, REFRESH_INTERVAL)
		guarded("refreshAll", "mise à jour des caisses", refreshAll)
	end
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------

function DisplayService.PlaceAuto(player: Player, itemUid: string, near: Vector3?): number?
	local data, account, plot = context(player)
	if data == nil or account == nil or plot == nil or type(itemUid) ~= "string" then
		return nil
	end
	reconcile(player, account, data, plot)
	local entry, def = lookup(data, itemUid)
	if entry == nil or def == nil or isInVault(data, itemUid) then
		return nil
	end
	local current = slotOf(data, itemUid)
	if current then
		return current
	end

	local refs = refsFor(plot)
	local origin = near
	if origin == nil then
		local root = rootOf(player)
		origin = if root then root.Position else nil
	end
	local best: number? = nil
	local bestScore = math.huge
	for index = 1, unlockedSlots(data) do
		local attachment = refs.slots[index]
		if attachment and data.Display[tostring(index)] == nil then
			-- Sans position, le score est le numéro : premier présentoir libre.
			local score = if origin then (attachment.WorldPosition - origin).Magnitude else index
			if score < bestScore then
				best, bestScore = index, score
			end
		end
	end
	if best == nil then
		return nil
	end
	local slot = best :: number
	data.Display[tostring(slot)] = itemUid
	reconcile(player, account, data, plot)
	if data.Display[tostring(slot)] ~= itemUid then
		return nil
	end
	if IS_STUDIO then
		print(`[DisplayService] {player.Name} : {describe(data, itemUid, slot)}, revenu {formatMoney(account.income)}/s`)
	end
	return slot
end

function DisplayService.PlaceItem(player: Player, itemUid: string, slotIndex: number): (boolean, PlaceError?)
	return place(player, itemUid, slotIndex, false)
end

function DisplayService.Unplace(player: Player, itemUid: string): number?
	local data = DataService.Get(player)
	if data == nil then
		return nil
	end
	local slot = slotOf(data, itemUid)
	if slot == nil then
		return nil
	end
	data.Display[tostring(slot)] = nil
	local _, account, plot = context(player)
	if account and plot then
		reconcile(player, account, data, plot)
	end
	return slot
end

function DisplayService.GetIncome(player: Player): number
	local account = accounts[player]
	return if account then account.income else 0
end

function DisplayService.GetRegister(player: Player): number
	local account = accounts[player]
	if account == nil then
		return 0
	end
	accrue(account, os.clock())
	return math.floor(account.register)
end

function DisplayService.CashOut(player: Player): number
	local account = accounts[player]
	if account == nil then
		return 0
	end
	return cashOut(player, account, "Api")
end

function DisplayService.OnCashOut(listener: CashOutListener): () -> ()
	return subscribe(cashOutListeners, listener)
end

function DisplayService.Init()
	-- Rejoue les attributions déjà faites ; la parcelle n'est donnée qu'à un profil chargé.
	PlotService.OnPlotAssigned(install)
	PlotService.OnPlotReleased(onPlotReleased)
	DataService.OnProfileLoaded(onProfileLoaded)
	DataService.OnProfileReleasing(onProfileReleasing)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	Net.Server.PlaceItem:Connect(onPlaceItem)
	RunService.Heartbeat:Connect(onHeartbeat)
end

return DisplayService

-- Tester dans Studio (après fusion avec DataService et PlotService ; UnboxService pour la boucle) :
--   1. Play. Sortie : « [DisplayService] <Nom> : 0 objet(s) exposé(s) sur 4 présentoir(s)
--      débloqué(s), revenu 0 $/s », aucune ligne rouge. Attributs : Income = 0,
--      DisplaySlotsUnlocked = 4 sur le Player ; CashRegister = 0 sur sa parcelle.
--   2. Objets : par la boucle (UnboxService appelle PlaceAuto), ou par un Script temporaire dans
--      Workspace/_SANDBOX_IRONIX (la barre de commande a son propre cache de require) qui ajoute
--      des objets à Items et appelle PlaceAuto : voir le rapport de l'agent a14.
--   3. Barre de commande, contexte Client :
--      game.ReplicatedStorage.Remotes.PlaceItem:FireServer("<uid>", 2)
--   4. Marcher sur le CashPad (tapis vert « CAISSE » de la greybox) : la caisse passe dans Cash.
