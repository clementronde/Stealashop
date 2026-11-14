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
--              (Format.hp : « 2800 », « 21K », « 1.4M ») ; caché par Clément depuis L-108 (BB_WindowHP
--              montre déjà les PV), le texte est écrit quand même ;
--   Damage     « Strength 1 » (L-108 point 5, avant « Damage 1 ») : dégâts par coup conseillés
--              (AdvisedDamage, la force requise), écrits comme sur le HUD
--              (Format.short : « 600 », « 5K ») ;
--   Speed      « Speed 16 » : vitesse conseillée (AdvisedSpeed, un WalkSpeed), Format.short.
--
-- Couleur du texte de Damage et de Speed, chez le joueur local (5.3 : « verts si le joueur les
-- atteint, orange entre 50 et 99 %, rouges en dessous ») : vert, orange ou rouge d'après les
-- attributs Damage et WalkSpeed du Player. Règle, couleurs et textes sont communs avec les panneaux
-- des arches (ZoneGateController) : Shared/AdvicePanel. Les couleurs sont refaites dès que l'un de
-- ces attributs change : outil équipé, aura, trail, entraînement.
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
--   StoreInfoController.StoreNameOf(store, zone) -> string
--       Nom anglais du magasin (ou de la zone), le même pour le panneau planté StoreReqSign.
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
local Zones = require(Config:WaitForChild("Zones"))
local Attributes = require(Contract:WaitForChild("Attributes"))
local Find = require(Contract:WaitForChild("Find"))
local UI = require(Contract:WaitForChild("UI"))
local Format = require(Shared:WaitForChild("Format"))
-- Textes, couleurs et modèles communs avec les panneaux des arches (ZoneGateController).
local AdvicePanel = require(Shared:WaitForChild("AdvicePanel"))

export type Level = AdvicePanel.Level
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
-- Texte de L-044 (exemples de Clément : « Mini Mart », « HP 35 », « Damage 1 », « Speed 16 » ;
-- ceux de Damage et de Speed sont dans Shared/AdvicePanel).
local HP_TEXT = "HP %s"
-- Nom d'un magasin : STORE_Z<n>_<Id>, puis une variante éventuelle (_<Variante>, 10.3).
local STORE_NAME_PATTERN = "^STORE_Z%d+_(.+)$"

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
local billboard = AdvicePanel.template

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

-- Partagé avec les panneaux plantés StoreReqSign (StoreReqSignController, L-108 point 5).
StoreInfoController.StoreNameOf = storeNameOf

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

-- Bas et haut (Y du monde) de la boîte d'une pièce ou d'un modèle, ou nil.
local verticalSpan = AdvicePanel.verticalSpan

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
	local damageLevel: Level, speedLevel: Level = AdvicePanel.levels(localPlayer, Zones[panel.Zone])
	panel.DamageLevel, panel.SpeedLevel = damageLevel, speedLevel
	local damage, speed = panel.Damage, panel.Speed
	if damage then
		damage.TextColor3 = AdvicePanel.Colors[damageLevel]
	end
	if speed then
		speed.TextColor3 = AdvicePanel.Colors[speedLevel]
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
		damage.Text = AdvicePanel.strengthText(zone) -- « Strength 1 » (L-108 point 5)
	end
	local speed = label(gui, "Speed")
	if speed then
		speed.Text = AdvicePanel.speedText(zone)
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
	for _, attribute in { AdvicePanel.DamageAttribute, AdvicePanel.SpeedAttribute } do
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
