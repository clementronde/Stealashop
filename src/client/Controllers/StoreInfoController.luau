--!strict
-- StoreInfoController (DEV-030, client) : panneau d'approche au-dessus de la vitrine de chaque
-- magasin PNJ (Partie 1, section 5.3, point 1 ; liaison L-044 ; contrat UI 2.2 et 10.4).
--
-- Un panneau par magasin PNJ de la map, même règle que WindowService : Model taggé NPCStore, dans le
-- Workspace hors _INBOX_CLEMENT, attribut Zone de 1 à 6. Le panneau est une copie du billboard de
-- Clément ReplicatedStorage/Assets/UI/BB_StoreInfo, rangée dans le PlayerGui : seul le joueur local
-- le voit, avec ses couleurs à lui. Rien n'est envoyé au serveur.
--
-- Textes, en anglais (L-036), nombres par Shared/Format, valeurs de Config/Zones (section 4) :
--   StoreName  nom anglais du magasin (Stores), retrouvé par le nom du modèle STORE_Z<n>_<Id>
--              (StoreIds ; une variante STORE_Z<n>_<Id>_<Variante> est reconnue, 10.3). Un nom
--              inconnu affiche le nom de la zone (Theme), avec une ligne en Studio ;
--   HP         « HP 35 » : PV de la vitrine (WindowHP), écrits comme sur la barre de PV BB_WindowHP
--              (Format.hp : « 2800 », « 21K », « 1.4M ») ;
--   Damage     « Damage 1 » : dégâts par coup conseillés (AdvisedDamage), écrits comme sur le HUD
--              (Format.short : « 600 », « 5K ») ;
--   Speed      « Speed 16 » : vitesse conseillée (AdvisedSpeed, un WalkSpeed), Format.short.
--
-- Couleur du texte de Damage et de Speed, chez le joueur local (5.3 : « verts si le joueur les
-- atteint, orange entre 50 et 99 %, rouges en dessous ») :
--   valeur du joueur ≥ valeur conseillée                                       vert
--   valeur du joueur ≥ Balance.StorePanel.OrangeFrom (50 %) de la conseillée    orange
--   en dessous                                                                 rouge
-- Valeurs du joueur, attributs du Player posés par le serveur :
--   Damage     dégâts d'un coup avec l'outil équipé, la Force et l'aura (ToolService, 7.1) : la
--              grandeur de la colonne « Dégâts/coup conseillés » de la section 4 ;
--   WalkSpeed  WalkSpeed de la formule 5.1, trail compris, sans les effets passagers (StatsService).
--              La section 4 donne la vitesse conseillée en WalkSpeed (16 en zone 1 : la vitesse de
--              départ), et StatsService réserve cet attribut à cette comparaison. Ce n'est ni la stat
--              Speed (Vitesse entraînée au tapis, 0 au départ), ni Humanoid.WalkSpeed (0 sur le tapis,
--              −10 % avec un colis : le panneau ne change pas de couleur pendant une fuite).
--   Attribut absent (profil pas encore chargé) : 0, donc rouge.
-- Les couleurs sont refaites dès que l'un de ces attributs change : outil équipé, aura, trail,
-- entraînement.
--
-- Point d'accroche :
--   - l'Attachment InfoPoint du magasin (10.4, facultatif), posé par Clément au-dessus de la
--     vitrine : le panneau garde tous les décalages du modèle ;
--   - sans InfoPoint (L-044 : « le code le pose au-dessus de Window ») : la pièce de la vitre Window,
--     celle où WindowController accroche la barre de PV BB_WindowHP, avec un décalage ajouté au
--     StudsOffset du modèle (repère de la caméra, comme la barre). Le bas du panneau passe
--     FALLBACK_GAP au-dessus du haut de la barre (décalage et hauteur en studs de son modèle ; sans
--     lui, le haut de la vitre). S'il tombe alors sur l'enseigne SignPart, il passe FALLBACK_GAP
--     au-dessus d'elle, comme les InfoPoint de Clément. Il avance aussi de FALLBACK_FORWARD vers la
--     caméra, pour ne pas entrer dans la façade ;
--   - ni l'un ni l'autre : pas de panneau, jusqu'à leur arrivée.
-- Streaming : un magasin qui sort du streaming perd son panneau, refait à son retour. Tant qu'il est
-- là, l'arrivée ou le départ d'InfoPoint, de Window ou de SignPart refait l'accroche.
-- Seuls les textes, la couleur du texte de Damage et Speed, l'accroche et, sans InfoPoint, le
-- StudsOffset de la copie sont touchés : ni taille, ni position d'élément, ni style de Clément.
--
-- API (client) :
--   StoreInfoController.GetPanels() -> { PanelInfo }
--       Panneaux du joueur local, triés par nom de magasin, pour un test dans Studio (barre de
--       commande côté client) : { Store, Zone, Anchor ("InfoPoint", "Window", ou nil quand le
--       magasin n'a pas encore de panneau), Damage et Speed ("Green", "Orange" ou "Red") }.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Contract = Shared:WaitForChild("Contract")
local Balance = require(Config:WaitForChild("Balance"))
local Zones = require(Config:WaitForChild("Zones"))
local Attributes = require(Contract:WaitForChild("Attributes"))
local Find = require(Contract:WaitForChild("Find"))
local UI = require(Contract:WaitForChild("UI"))
local Format = require(Shared:WaitForChild("Format"))

export type Level = "Green" | "Orange" | "Red"
export type AnchorKind = "InfoPoint" | "Window"

export type PanelInfo = {
	Store: string,
	Zone: number,
	Anchor: AnchorKind?,
	Damage: Level?,
	Speed: Level?,
}

type Panel = {
	Store: Model,
	Zone: number,
	Gui: BillboardGui?,
	Damage: TextLabel?,
	Speed: TextLabel?,
	DamageLevel: Level?,
	SpeedLevel: Level?,
	Anchor: Instance?, -- InfoPoint, ou la pièce de la vitre (repli)
	AnchorKind: AnchorKind?,
	Pending: boolean, -- accroche à refaire au prochain tour (task.defer)
	Connections: { RBXScriptConnection },
}

local STORE_TAG = "NPCStore" -- contrat 2.1
local INBOX_NAME = "_INBOX_CLEMENT" -- livraisons pas encore posées : ignorées, comme dans WindowService
local TEMPLATE_NAME = "BB_StoreInfo" -- contrat 2.2 (L-044)
local HP_BAR_NAME = "BB_WindowHP" -- barre de PV de Clément (WindowController) : jamais recouverte
local INFO_POINT_NAME = "InfoPoint" -- contrat 10.4, facultatif (L-044)
local WINDOW_NAME = "Window" -- contrat 10.4
local SIGN_NAME = "SignPart" -- contrat 10.4 : l'enseigne du magasin
-- Suivis dans le magasin : leur arrivée ou leur départ refait l'accroche.
local WATCHED: { [string]: boolean } = { [INFO_POINT_NAME] = true, [WINDOW_NAME] = true, [SIGN_NAME] = true }
-- Attributs du Player posés par le serveur (mêmes noms dans ToolService et StatsService).
local DAMAGE_ATTRIBUTE = "Damage"
local WALK_SPEED_ATTRIBUTE = "WalkSpeed"
-- Textes de L-044 (exemples de Clément : « Mini Mart », « HP 35 », « Damage 1 », « Speed 16 »).
local HP_TEXT = "HP %s"
local DAMAGE_TEXT = "Damage %s"
local SPEED_TEXT = "Speed %s"
-- Nom d'un magasin : STORE_Z<n>_<Id>, puis une variante éventuelle (_<Variante>, 10.3).
local STORE_NAME_PATTERN = "^STORE_Z%d+_(.+)$"

-- V0 proposé, absent du doc : couleurs prises dans la planche de style (10.6), à valider par Clément.
-- Vert = celui de l'exemple de Clément sur BB_StoreInfo (#91F630, le vert des prix) ; orange =
-- « améliorations » (#FF8C1A) ; rouge = « fermer » (#E8413C).
local COLORS: { [Level]: Color3 } = {
	Green = Color3.fromHex("#91F630"),
	Orange = Color3.fromHex("#FF8C1A"),
	Red = Color3.fromHex("#E8413C"),
}
local ORANGE_FROM: number = Balance.StorePanel.OrangeFrom -- 50 % (5.3)
-- Marge contre les erreurs d'arrondi des nombres à virgule (10 × 1,07 ne donne pas exactement 10,7).
local EPSILON = 1e-9

-- V0 proposé, absent du doc : repli sans InfoPoint, d'après les InfoPoint posés par Clément (relevé
-- Studio du 2026-11-07) : 0,4 stud au-dessus de l'enseigne (zones 2 à 4), 3,05 studs devant la vitre.
local FALLBACK_GAP = 0.4
local FALLBACK_FORWARD = 3.05

local IS_STUDIO = RunService:IsStudio()

local localPlayer = Players.LocalPlayer

local StoreInfoController = {}

local panels: { [Instance]: Panel } = {}
local playerGui: Instance? = nil
local said: { [string]: boolean } = {} -- lignes de Studio déjà écrites, une fois chacune

local function sayOnce(key: string, message: string, isProblem: boolean?)
	if not IS_STUDIO or said[key] then
		return
	end
	said[key] = true
	if isProblem then
		warn(message)
	else
		print(message)
	end
end

-- Modèles et valeurs ------------------------------------------------------------------------------

-- Billboard modèle de Clément, dans ReplicatedStorage/Assets/UI ou un de ses sous-dossiers (2.2).
local function billboard(name: string): BillboardGui?
	local current: Instance? = ReplicatedStorage
	for _, segment in UI.BillboardFolder do
		current = if current then current:FindFirstChild(segment) else nil
	end
	local found = if current then current:FindFirstChild(name, true) else nil
	if found and found:IsA("BillboardGui") then
		return found
	end
	return nil
end

-- Vert, orange ou rouge : `value` comparée à `advised` (5.3).
local function levelOf(value: number, advised: number): Level
	if advised <= 0 or value >= advised * (1 - EPSILON) then
		return "Green"
	elseif value >= advised * (ORANGE_FROM - EPSILON) then
		return "Orange"
	end
	return "Red"
end

-- Valeur d'un attribut du joueur local ; 0 s'il n'est pas encore posé.
local function playerValue(attribute: string): number
	local value = localPlayer:GetAttribute(attribute)
	return if type(value) == "number" and value == value then value else 0
end

-- Nom anglais du magasin (Config/Zones), ou le nom de la zone si son modèle n'y est pas.
local function storeNameOf(store: Instance, zone: Zones.Zone): string
	local rest = string.match(store.Name, STORE_NAME_PATTERN)
	if rest then
		for index, id in zone.StoreIds do
			if rest == id or string.sub(rest, 1, #id + 1) == `{id}_` then
				local name = zone.Stores[index]
				if name then
					return name
				end
			end
		end
	end
	local known: { string } = {}
	for _, id in zone.StoreIds do
		table.insert(known, `STORE_Z{zone.Index}_{id}`)
	end
	sayOnce(
		`name:{store:GetFullName()}`,
		`[StoreInfoController] {store:GetFullName()} : nom absent de Config/Zones (zone {zone.Index} : {table.concat(known, " ou ")}), le panneau affiche le nom de la zone « {zone.Theme} »`,
		true
	)
	return zone.Theme
end

-- Élément texte du panneau (contrat 2.2), ou nil (une ligne en Studio ; le ContractChecker le signale).
local function label(gui: Instance, name: string): TextLabel?
	local found = Find.path(gui, name)
	if found and found:IsA("TextLabel") then
		return found :: TextLabel
	end
	sayOnce(`element:{name}`, `[StoreInfoController] {TEMPLATE_NAME}.{name} introuvable ou pas un TextLabel : ignoré`, true)
	return nil
end

-- Repli sans InfoPoint ------------------------------------------------------------------------------

local function boxOf(object: Instance?): (CFrame?, Vector3?)
	if object and object:IsA("BasePart") then
		return object.CFrame, object.Size
	elseif object and object:IsA("Model") then
		return object:GetBoundingBox()
	end
	return nil, nil
end

-- Bas et haut (Y du monde) de la boîte d'une pièce ou d'un modèle, ou nil.
local function verticalSpan(object: Instance?): (number?, number?)
	local frame, size = boxOf(object)
	if frame == nil or size == nil then
		return nil, nil
	end
	local half = (
		math.abs(frame.RightVector.Y) * size.X
		+ math.abs(frame.UpVector.Y) * size.Y
		+ math.abs(frame.LookVector.Y) * size.Z
	) / 2
	return frame.Position.Y - half, frame.Position.Y + half
end

-- Pièce de la vitre où s'accroche la barre de PV (même choix que WindowController).
local function windowPart(store: Model): BasePart?
	local window = store:FindFirstChild(WINDOW_NAME) or store:FindFirstChild(WINDOW_NAME, true)
	if window and window:IsA("BasePart") then
		return window
	elseif window and window:IsA("Model") then
		local primary = window.PrimaryPart
		if primary then
			return primary
		end
		local first = window:FindFirstChildWhichIsA("BasePart", true)
		return if first then first :: BasePart else nil
	end
	return nil
end

-- Haut de la barre de PV, en studs au-dessus du centre de `part` : décalage et hauteur en studs du
-- modèle BB_WindowHP (son bas est à SizeOffset près au point d'accroche), sinon le haut de la vitre.
local function barTopOf(part: BasePart): number
	local bar = billboard(HP_BAR_NAME)
	if bar then
		return bar.StudsOffset.Y + (bar.SizeOffset.Y + 0.5) * bar.Size.Y.Scale
	end
	local _, top = verticalSpan(part)
	return if top then top - part.Position.Y else 0
end

-- Décalage du panneau de repli (à ajouter au StudsOffset du modèle), voir l'en-tête.
local function fallbackOffset(store: Model, part: BasePart, template: BillboardGui): Vector3
	local center = part.Position.Y
	local height = template.Size.Y.Scale -- hauteur du panneau en studs (sa part en pixels pousse vers le haut)
	local bottom = barTopOf(part) + FALLBACK_GAP
	local signBottom, signTop = verticalSpan(store:FindFirstChild(SIGN_NAME, true))
	if signBottom and signTop and signBottom - center < bottom + height and signTop - center > bottom then
		bottom = signTop - center + FALLBACK_GAP
	end
	-- Le centre du panneau est à SizeOffset × sa taille de son point : son bas doit tomber sur `bottom`.
	return Vector3.new(0, bottom - (template.SizeOffset.Y - 0.5) * height, FALLBACK_FORWARD)
end

-- Panneaux ------------------------------------------------------------------------------------------

local function recolor(panel: Panel)
	local zone = Zones[panel.Zone]
	local damageLevel: Level = levelOf(playerValue(DAMAGE_ATTRIBUTE), zone.AdvisedDamage)
	local speedLevel: Level = levelOf(playerValue(WALK_SPEED_ATTRIBUTE), zone.AdvisedSpeed)
	panel.DamageLevel, panel.SpeedLevel = damageLevel, speedLevel
	local damage, speed = panel.Damage, panel.Speed
	if damage then
		damage.TextColor3 = COLORS[damageLevel]
	end
	if speed then
		speed.TextColor3 = COLORS[speedLevel]
	end
end

local function recolorAll()
	for _, panel in panels do
		recolor(panel)
	end
end

-- Copie du modèle de Clément, textes écrits ; seules les couleurs changent ensuite.
local function build(panel: Panel, template: BillboardGui): BillboardGui
	local zone = Zones[panel.Zone]
	local gui = template:Clone()
	gui.Name = `{TEMPLATE_NAME}_{panel.Store.Name}`
	gui.ResetOnSpawn = false -- survit à la réapparition du personnage, comme les barres de PV
	local storeName = label(gui, "StoreName")
	if storeName then
		storeName.Text = storeNameOf(panel.Store, zone)
	end
	local hp = label(gui, "HP")
	if hp then
		hp.Text = string.format(HP_TEXT, Format.hp(zone.WindowHP))
	end
	local damage = label(gui, "Damage")
	if damage then
		damage.Text = string.format(DAMAGE_TEXT, Format.short(zone.AdvisedDamage))
	end
	local speed = label(gui, "Speed")
	if speed then
		speed.Text = string.format(SPEED_TEXT, Format.short(zone.AdvisedSpeed))
	end
	panel.Damage, panel.Speed = damage, speed
	return gui
end

local function clearGui(panel: Panel)
	local gui = panel.Gui
	panel.Gui, panel.Damage, panel.Speed = nil, nil, nil
	panel.Anchor, panel.AnchorKind = nil, nil
	if gui then
		gui:Destroy()
	end
end

-- Pose ou refait le panneau d'un magasin : accroche, décalage de repli, couleurs.
local function place(panel: Panel)
	panel.Pending = false
	local store = panel.Store
	if panels[store] ~= panel then
		return -- magasin oublié entre-temps (sorti du streaming)
	end
	local anchor: Instance? = nil
	local kind: AnchorKind? = nil
	local part: BasePart? = nil
	local info = store:FindFirstChild(INFO_POINT_NAME, true)
	if info and info:IsA("Attachment") then
		anchor, kind = info, "InfoPoint"
	else
		part = windowPart(store)
		if part then
			anchor, kind = part, "Window"
		end
	end
	local template = billboard(TEMPLATE_NAME)
	local parent = playerGui
	if template == nil then
		sayOnce(
			"template",
			`[StoreInfoController] {TEMPLATE_NAME} absent de ReplicatedStorage.{table.concat(UI.BillboardFolder, ".")} : pas de panneau d'approche (L-044)`
		)
	end
	if anchor == nil or template == nil or parent == nil then
		clearGui(panel)
		return
	end
	local existing = panel.Gui
	local gui: BillboardGui = if existing and existing.Parent ~= nil then existing else build(panel, template)
	panel.Gui = gui
	gui.Adornee = anchor
	if part then
		gui.StudsOffset = template.StudsOffset + fallbackOffset(store, part, template)
		sayOnce(
			`fallback:{store:GetFullName()}`,
			`[StoreInfoController] {store:GetFullName()} : pas d'{INFO_POINT_NAME}, panneau posé au-dessus de la vitre (L-044)`
		)
	else
		gui.StudsOffset = template.StudsOffset
	end
	panel.Anchor, panel.AnchorKind = anchor, kind
	if gui.Parent ~= parent then
		gui.Parent = parent
	end
	recolor(panel)
end

local function schedule(panel: Panel)
	if not panel.Pending then
		panel.Pending = true
		task.defer(place, panel)
	end
end

local function inMap(instance: Instance): boolean
	if not instance:IsDescendantOf(Workspace) then
		return false
	end
	local inbox = Workspace:FindFirstChild(INBOX_NAME)
	return inbox == nil or not instance:IsDescendantOf(inbox)
end

local function track(instance: Instance)
	if panels[instance] ~= nil or not instance:IsA("Model") or not inMap(instance) then
		return
	end
	local zone = instance:GetAttribute(Attributes.Zone.Name)
	if type(zone) ~= "number" or Zones[zone] == nil then
		sayOnce(
			`zone:{instance:GetFullName()}`,
			`[StoreInfoController] {instance:GetFullName()} : attribut {Attributes.Zone.Name} invalide ({zone}), pas de panneau`,
			true
		)
		return
	end
	local panel: Panel = {
		Store = instance :: Model,
		Zone = zone,
		Gui = nil,
		Damage = nil,
		Speed = nil,
		DamageLevel = nil,
		SpeedLevel = nil,
		Anchor = nil,
		AnchorKind = nil,
		Pending = false,
		Connections = {},
	}
	panels[instance] = panel
	-- Streaming : InfoPoint, Window et SignPart peuvent arriver après le magasin, ou repartir avant lui.
	local function onDescendant(descendant: Instance)
		if
			WATCHED[descendant.Name]
			or descendant == panel.Anchor
			or (panel.Anchor == nil and descendant:IsA("BasePart"))
		then
			schedule(panel)
		end
	end
	table.insert(panel.Connections, instance.DescendantAdded:Connect(onDescendant))
	table.insert(panel.Connections, instance.DescendantRemoving:Connect(onDescendant))
	place(panel)
end

local function untrack(instance: Instance)
	local panel = panels[instance]
	if panel == nil then
		return
	end
	panels[instance] = nil
	for _, connection in panel.Connections do
		connection:Disconnect()
	end
	table.clear(panel.Connections)
	clearGui(panel)
end

-- API -----------------------------------------------------------------------------------------------

function StoreInfoController.GetPanels(): { PanelInfo }
	local list: { PanelInfo } = {}
	for store, panel in panels do
		local shown = panel.Gui ~= nil
		table.insert(list, {
			Store = store.Name,
			Zone = panel.Zone,
			Anchor = panel.AnchorKind,
			Damage = if shown then panel.DamageLevel else nil,
			Speed = if shown then panel.SpeedLevel else nil,
		})
	end
	table.sort(list, function(a: PanelInfo, b: PanelInfo): boolean
		return a.Store < b.Store
	end)
	return list
end

function StoreInfoController.Start()
	playerGui = localPlayer:WaitForChild("PlayerGui")
	for _, attribute in { DAMAGE_ATTRIBUTE, WALK_SPEED_ATTRIBUTE } do
		localPlayer:GetAttributeChangedSignal(attribute):Connect(recolorAll)
	end
	-- Avec StreamingEnabled, les magasins arrivent et repartent avec la zone autour du joueur.
	CollectionService:GetInstanceAddedSignal(STORE_TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(STORE_TAG):Connect(untrack)
	for _, store in CollectionService:GetTagged(STORE_TAG) do
		track(store)
	end
	if IS_STUDIO then
		local shown, fallback = 0, 0
		for _, panel in panels do
			if panel.Gui then
				shown += 1
				if panel.AnchorKind == "Window" then
					fallback += 1
				end
			end
		end
		print(`[StoreInfoController] {shown} panneau(x) de magasin, dont {fallback} sans InfoPoint (au-dessus de la vitre)`)
	end
end

return StoreInfoController
