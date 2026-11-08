--!strict
-- ZoneGateController (client) : le panneau de chaque arche de zone (liaison L-071, point 9 ; Partie 1,
-- section 4 : « Arche de zone : à l'entrée de chaque zone, Zone 3 · Vitesse conseillée 28 · Dégâts
-- conseillés 80 » ; contrat UI 2.2). Sur le modèle de StoreInfoController, qui fait la même chose
-- au-dessus des vitrines.
--
-- Un panneau par arche de la map : Model taggé ZoneGate, dans le Workspace hors _INBOX_CLEMENT,
-- attribut Zone de 1 à 6. Le panneau est une copie du billboard de Clément
-- ReplicatedStorage/Assets/UI/BB_ZoneGate (sous-dossiers permis), rangée dans le PlayerGui : seul le
-- joueur local le voit, avec ses couleurs à lui. Rien n'est envoyé au serveur.
--
-- Textes, en anglais (L-036), valeurs de Config/Zones (section 4) :
--   ZoneName  le nom anglais de la zone (Theme : « Mini Mart », « Electronics »…) ;
--   Damage    « Damage 80 » : dégâts par coup conseillés, comme sur BB_StoreInfo ;
--   Speed     « Speed 28 » : vitesse conseillée (un WalkSpeed), comme sur BB_StoreInfo.
-- Damage et Speed prennent la couleur du joueur local (vert, orange, rouge), refaite dès que ses
-- attributs Damage ou WalkSpeed changent : mêmes textes, même règle et mêmes couleurs que les
-- panneaux des magasins (Shared/AdvicePanel).
--
-- Point d'accroche :
--   - l'Attachment InfoPoint de l'arche (Contract/Models, facultatif, comme celui des magasins) : le
--     panneau garde tous les décalages du modèle de Clément ;
--   - sinon la pièce SignPart de l'arche (le bandeau du greybox, tools/greybox.luau) : le bas du
--     panneau passe SIGN_GAP au-dessus du haut de SignPart et il avance de SIGN_FORWARD vers la caméra
--     (décalage ajouté au StudsOffset du modèle, comme le repli de StoreInfoController) ;
--   - ni l'un ni l'autre : pas de panneau sur cette arche, jusqu'à leur arrivée.
-- Tant que BB_ZoneGate manque, rien ne change : aucun panneau, et les panneaux du greybox restent.
-- Dès qu'il est là, les deux SurfaceGui SignLeft et SignRight de SignPart (texte « ZONE 3 /
-- Recommended speed… » du greybox) sont éteints chez ce joueur (Enabled = false) : rien n'est retiré
-- de la carte. Ils sont rallumés si le panneau de l'arche disparaît (BB_ZoneGate retiré).
-- BB_ZoneGate livré en cours de partie : les panneaux sont posés à son arrivée.
-- Streaming : une arche qui sort du streaming perd son panneau, refait à son retour ; tant qu'elle est
-- là, l'arrivée ou le départ d'InfoPoint ou de SignPart refait l'accroche.
-- Seuls les textes, la couleur du texte de Damage et Speed, l'accroche et, sans InfoPoint, le
-- StudsOffset de la copie sont touchés : ni taille, ni position d'élément, ni style de Clément.
--
-- API (client) :
--   ZoneGateController.GetPanels() -> { GatePanelInfo }
--       Panneaux du joueur local, triés par zone, pour un test dans Studio (barre de commande côté
--       client) : { Gate, Zone, Anchor ("InfoPoint", "SignPart", ou nil sans panneau), Damage et
--       Speed ("Green", "Orange" ou "Red", nil sans panneau), SignsOff (SurfaceGui éteints ici) }.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Zones = require(Shared:WaitForChild("Config"):WaitForChild("Zones"))
local Contract = Shared:WaitForChild("Contract")
local Attributes = require(Contract:WaitForChild("Attributes"))
local Find = require(Contract:WaitForChild("Find"))
local UI = require(Contract:WaitForChild("UI"))
local AdvicePanel = require(Shared:WaitForChild("AdvicePanel"))

export type Level = AdvicePanel.Level
export type AnchorKind = "InfoPoint" | "SignPart"

export type GatePanelInfo = {
	Gate: string,
	Zone: number,
	Anchor: AnchorKind?,
	Damage: Level?,
	Speed: Level?,
	SignsOff: number,
}

type Panel = {
	Gate: Model,
	Zone: number,
	Gui: BillboardGui?,
	Damage: TextLabel?,
	Speed: TextLabel?,
	DamageLevel: Level?,
	SpeedLevel: Level?,
	Anchor: Instance?, -- InfoPoint, ou SignPart (repli)
	AnchorKind: AnchorKind?,
	Muted: { SurfaceGui }, -- panneaux du greybox éteints ici
	Pending: boolean, -- accroche à refaire au prochain tour (task.defer)
	Connections: { RBXScriptConnection },
}

local GATE_TAG = "ZoneGate" -- contrat 2.1
local INBOX_NAME = "_INBOX_CLEMENT" -- livraisons pas encore posées : ignorées
local TEMPLATE_NAME = "BB_ZoneGate" -- contrat 2.2 (L-071, point 9)
local INFO_POINT_NAME = "InfoPoint" -- Contract/Models, facultatif
local SIGN_NAME = "SignPart" -- bandeau de l'arche du greybox
-- SurfaceGui du greybox sur SignPart (tools/greybox.luau, fonction label : « Sign » .. face).
local OLD_SIGNS = { "SignLeft", "SignRight" }
-- Suivis dans l'arche : leur arrivée ou leur départ refait l'accroche.
local WATCHED: { [string]: boolean } = { [INFO_POINT_NAME] = true, [SIGN_NAME] = true }

-- V0 proposé, absent du doc : repli sans InfoPoint, le panneau un demi-stud au-dessus du bandeau
-- SignPart, avancé de 2 studs vers la caméra (le bandeau du greybox fait 3 studs d'épaisseur : le
-- panneau ne rentre pas dedans quand on le regarde d'en bas).
local SIGN_GAP = 0.5
local SIGN_FORWARD = 2

local IS_STUDIO = RunService:IsStudio()

local localPlayer = Players.LocalPlayer

local ZoneGateController = {}

local panels: { [Instance]: Panel } = {}
local playerGui: Instance? = nil
local said: { [string]: boolean } = {}

local function sayOnce(key: string, message: string, isProblem: boolean?)
	if not IS_STUDIO or said[key] then
		return
	end
	said[key] = true
	if isProblem then
		warn(`[ZoneGateController] {message}`)
	else
		print(`[ZoneGateController] {message}`)
	end
end

-- Élément texte du panneau (contrat 2.2), ou nil (une ligne en Studio ; le ContractChecker le signale).
local function label(gui: Instance, name: string): TextLabel?
	local found = Find.path(gui, name)
	if found and found:IsA("TextLabel") then
		return found :: TextLabel
	end
	sayOnce(`element:{name}`, `{TEMPLATE_NAME}.{name} introuvable ou pas un TextLabel : ignoré`, true)
	return nil
end

-- Panneaux du greybox -------------------------------------------------------------------------------

local function unmute(panel: Panel)
	for _, sign in panel.Muted do
		if sign.Parent ~= nil then
			sign.Enabled = true
		end
	end
	table.clear(panel.Muted)
end

-- Éteint SignLeft et SignRight du bandeau (seulement ceux qui étaient allumés : un SurfaceGui éteint
-- par quelqu'un d'autre n'est jamais rallumé ici).
local function mute(panel: Panel, sign: Instance?)
	if sign == nil then
		return
	end
	for _, name in OLD_SIGNS do
		local gui = sign:FindFirstChild(name)
		if gui and gui:IsA("SurfaceGui") and (gui :: SurfaceGui).Enabled then
			local surface = gui :: SurfaceGui
			surface.Enabled = false
			table.insert(panel.Muted, surface)
		end
	end
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
	gui.Name = `{TEMPLATE_NAME}_{panel.Zone}`
	gui.ResetOnSpawn = false -- survit à la réapparition du personnage, comme les panneaux des magasins
	local zoneName = label(gui, "ZoneName")
	if zoneName then
		zoneName.Text = zone.Theme
	end
	local damage = label(gui, "Damage")
	if damage then
		damage.Text = AdvicePanel.damageText(zone)
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
	panel.DamageLevel, panel.SpeedLevel = nil, nil
	if gui then
		gui:Destroy()
	end
	unmute(panel)
end

-- Décalage du panneau posé sur SignPart (à ajouter au StudsOffset du modèle), voir l'en-tête.
local function signOffset(sign: BasePart, template: BillboardGui): Vector3
	local _, top = AdvicePanel.verticalSpan(sign)
	local bottom = (if top then top - sign.Position.Y else 0) + SIGN_GAP
	local height = template.Size.Y.Scale -- hauteur du panneau en studs (sa part en pixels pousse vers le haut)
	-- Le centre du panneau est à SizeOffset × sa taille de son point : son bas doit tomber sur `bottom`.
	return Vector3.new(0, bottom - (template.SizeOffset.Y - 0.5) * height, SIGN_FORWARD)
end

-- Pose ou refait le panneau d'une arche : accroche, décalage de repli, couleurs, panneaux du greybox.
local function place(panel: Panel)
	panel.Pending = false
	local gate = panel.Gate
	if panels[gate] ~= panel then
		return -- arche oubliée entre-temps (sortie du streaming)
	end
	local template = AdvicePanel.template(TEMPLATE_NAME)
	if template == nil then
		sayOnce(
			"template",
			`{TEMPLATE_NAME} absent de ReplicatedStorage.{table.concat(UI.BillboardFolder, ".")} : les arches gardent leurs panneaux du greybox (L-071)`
		)
		clearGui(panel)
		return
	end
	local found = gate:FindFirstChild(SIGN_NAME, true)
	local sign: BasePart? = if found and found:IsA("BasePart") then found :: BasePart else nil
	local anchor: Instance? = nil
	local kind: AnchorKind? = nil
	local info = gate:FindFirstChild(INFO_POINT_NAME, true)
	if info and info:IsA("Attachment") then
		anchor, kind = info, "InfoPoint"
	elseif sign then
		anchor, kind = sign, "SignPart"
	end
	local parent = playerGui
	if anchor == nil or parent == nil then
		if anchor == nil then
			sayOnce(`anchor:{gate:GetFullName()}`, `{gate:GetFullName()} : ni {INFO_POINT_NAME} ni {SIGN_NAME}, pas de panneau sur cette arche`, true)
		end
		clearGui(panel)
		return
	end
	local existing = panel.Gui
	local gui: BillboardGui = if existing and existing.Parent ~= nil then existing else build(panel, template)
	panel.Gui = gui
	gui.Adornee = anchor
	if kind == "SignPart" and sign then
		gui.StudsOffset = template.StudsOffset + signOffset(sign, template)
		sayOnce(`fallback:{gate:GetFullName()}`, `{gate:GetFullName()} : pas d'{INFO_POINT_NAME}, panneau posé au-dessus de {SIGN_NAME}`)
	else
		gui.StudsOffset = template.StudsOffset
	end
	panel.Anchor, panel.AnchorKind = anchor, kind
	if gui.Parent ~= parent then
		gui.Parent = parent
	end
	mute(panel, sign)
	recolor(panel)
end

local function schedule(panel: Panel)
	if not panel.Pending then
		panel.Pending = true
		task.defer(place, panel)
	end
end

local function scheduleAll()
	for _, panel in panels do
		schedule(panel)
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
		sayOnce(`zone:{instance:GetFullName()}`, `{instance:GetFullName()} : attribut {Attributes.Zone.Name} invalide ({zone}), pas de panneau`, true)
		return
	end
	local panel: Panel = {
		Gate = instance :: Model,
		Zone = zone,
		Gui = nil,
		Damage = nil,
		Speed = nil,
		DamageLevel = nil,
		SpeedLevel = nil,
		Anchor = nil,
		AnchorKind = nil,
		Muted = {},
		Pending = false,
		Connections = {},
	}
	panels[instance] = panel
	-- Streaming : InfoPoint, SignPart et ses SurfaceGui peuvent arriver après l'arche, ou repartir avant elle.
	local function onDescendant(descendant: Instance)
		if
			WATCHED[descendant.Name]
			or descendant == panel.Anchor
			or table.find(OLD_SIGNS, descendant.Name) ~= nil
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

function ZoneGateController.GetPanels(): { GatePanelInfo }
	local list: { GatePanelInfo } = {}
	for gate, panel in panels do
		local shown = panel.Gui ~= nil
		table.insert(list, {
			Gate = gate.Name,
			Zone = panel.Zone,
			Anchor = panel.AnchorKind,
			Damage = if shown then panel.DamageLevel else nil,
			Speed = if shown then panel.SpeedLevel else nil,
			SignsOff = #panel.Muted,
		})
	end
	table.sort(list, function(a: GatePanelInfo, b: GatePanelInfo): boolean
		if a.Zone ~= b.Zone then
			return a.Zone < b.Zone
		end
		return a.Gate < b.Gate
	end)
	return list
end

function ZoneGateController.Start()
	playerGui = localPlayer:WaitForChild("PlayerGui")
	for _, attribute in { AdvicePanel.DamageAttribute, AdvicePanel.WalkSpeedAttribute } do
		localPlayer:GetAttributeChangedSignal(attribute):Connect(recolorAll)
	end
	-- BB_ZoneGate livré (ou retiré) en cours de partie : toutes les arches sont refaites.
	local function onAsset(descendant: Instance)
		if descendant.Name == TEMPLATE_NAME then
			scheduleAll()
		end
	end
	ReplicatedStorage.DescendantAdded:Connect(onAsset)
	ReplicatedStorage.DescendantRemoving:Connect(onAsset)
	-- Avec StreamingEnabled, les arches arrivent et repartent avec la zone autour du joueur.
	CollectionService:GetInstanceAddedSignal(GATE_TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(GATE_TAG):Connect(untrack)
	for _, gate in CollectionService:GetTagged(GATE_TAG) do
		track(gate)
	end
	if IS_STUDIO and AdvicePanel.template(TEMPLATE_NAME) then
		local shown, fallback = 0, 0
		for _, panel in panels do
			if panel.Gui then
				shown += 1
				if panel.AnchorKind == "SignPart" then
					fallback += 1
				end
			end
		end
		print(`[ZoneGateController] {shown} panneau(x) d'arche, dont {fallback} sans InfoPoint (au-dessus de SignPart)`)
	end
end

return ZoneGateController
