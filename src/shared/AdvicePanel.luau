--!strict
-- AdvicePanel (DEV-030 ; liaison L-044 et L-071, point 9) : ce qui est commun aux deux panneaux de
-- conseils, côté client : BB_StoreInfo au-dessus de chaque vitrine (StoreInfoController) et
-- UI_ZoneBanner au passage d'une arche (ZoneBannerController, L-110 ; avant : BB_ZoneGate). Mêmes textes, mêmes nombres (Shared/Format)
-- et mêmes couleurs, pour les mêmes valeurs de Config/Zones (section 4).
--
-- Couleur du texte des dégâts et de la vitesse conseillés, chez le joueur local (5.3 : « verts si le
-- joueur les atteint, orange entre 50 et 99 %, rouges en dessous ») :
--   valeur du joueur ≥ valeur conseillée                                       vert
--   valeur du joueur ≥ Balance.StorePanel.OrangeFrom (50 %) de la conseillée    orange
--   en dessous                                                                 rouge
-- Valeurs du joueur, attributs du Player posés par le serveur :
--   Damage     dégâts d'un coup avec l'outil équipé, la Force et l'aura (ToolService, 7.1) : la
--              grandeur de la colonne « Dégâts/coup conseillés » de la section 4 ;
--   WalkSpeed  WalkSpeed de la formule 5.1, trail compris, sans les effets passagers (StatsService).
--              La section 4 donne la vitesse conseillée en WalkSpeed (16 en zone 1 : la vitesse de
--              départ). Ce n'est ni la stat Speed (0 au départ), ni Humanoid.WalkSpeed (0 sur le tapis,
--              −10 % avec un colis : un panneau ne change pas de couleur pendant une fuite).
--   Attribut absent (profil pas encore chargé) : 0, donc rouge.
--
-- API (client et serveur : rien n'y dépend du joueur local) :
--   AdvicePanel.template(name) -> BillboardGui?     billboard modèle de Clément, dans
--                                                   ReplicatedStorage/Assets/UI ou un sous-dossier (2.2)
--   AdvicePanel.damageText(zone), speedText(zone)   « Damage 80 », « Speed 28 » (Format.short)
--   AdvicePanel.strengthText(zone)                  « Strength 80 » : AdvisedDamage, BB_StoreInfo et StoreReqSign (L-108)
--   AdvicePanel.levelOf(value, advised) -> Level    "Green", "Orange" ou "Red"
--   AdvicePanel.levels(player, zone) -> (Level, Level)  dégâts puis vitesse de `player` face à `zone`
--   AdvicePanel.Colors[level] -> Color3
--   AdvicePanel.DamageAttribute, WalkSpeedAttribute  les attributs du Player à suivre (recolorer)
--   AdvicePanel.verticalSpan(object) -> (bas?, haut?)  Y du monde de la boîte d'une pièce ou d'un Model

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = script.Parent:WaitForChild("Config")
local Balance = require(Config:WaitForChild("Balance"))
local Zones = require(Config:WaitForChild("Zones"))
local UI = require(script.Parent:WaitForChild("Contract"):WaitForChild("UI"))
local Format = require(script.Parent:WaitForChild("Format"))

export type Level = "Green" | "Orange" | "Red"

local AdvicePanel = {}

-- Attributs du Player posés par le serveur (mêmes noms dans ToolService et StatsService).
AdvicePanel.DamageAttribute = "Damage"
AdvicePanel.WalkSpeedAttribute = "WalkSpeed"

-- Textes de L-044 (exemples de Clément sur BB_StoreInfo : « Damage 1 », « Speed 16 »).
local DAMAGE_TEXT = "Damage %s"
local SPEED_TEXT = "Speed %s"
-- L-108 point 5 (Clément, 2026-11-12) : sur BB_StoreInfo et StoreReqSign, la même valeur se lit
-- « Strength 1 » (la force requise), et sur UI_ZoneBanner aussi (L-110). damageText ne sert plus qu'aux bancs.
local STRENGTH_TEXT = "Strength %s"

-- V0 proposé, absent du doc : couleurs prises dans la planche de style (10.6), à valider par Clément.
-- Vert = celui de l'exemple de Clément sur BB_StoreInfo (#91F630, le vert des prix) ; orange =
-- « améliorations » (#FF8C1A) ; rouge = « fermer » (#E8413C).
AdvicePanel.Colors = {
	Green = Color3.fromHex("#91F630"),
	Orange = Color3.fromHex("#FF8C1A"),
	Red = Color3.fromHex("#E8413C"),
} :: { [Level]: Color3 }

local ORANGE_FROM: number = Balance.StorePanel.OrangeFrom -- 50 % (5.3)
-- Marge contre les erreurs d'arrondi des nombres à virgule (10 × 1,07 ne donne pas exactement 10,7).
local EPSILON = 1e-9

function AdvicePanel.template(name: string): BillboardGui?
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

function AdvicePanel.damageText(zone: Zones.Zone): string
	return string.format(DAMAGE_TEXT, Format.short(zone.AdvisedDamage))
end

function AdvicePanel.strengthText(zone: Zones.Zone): string
	return string.format(STRENGTH_TEXT, Format.short(zone.AdvisedDamage))
end

function AdvicePanel.speedText(zone: Zones.Zone): string
	return string.format(SPEED_TEXT, Format.short(zone.AdvisedSpeed))
end

local function levelOf(value: number, advised: number): Level
	if advised <= 0 or value >= advised * (1 - EPSILON) then
		return "Green"
	elseif value >= advised * (ORANGE_FROM - EPSILON) then
		return "Orange"
	end
	return "Red"
end
AdvicePanel.levelOf = levelOf

-- Valeur d'un attribut de `player` ; 0 s'il n'est pas encore posé.
local function playerValue(player: Player, attribute: string): number
	local value = player:GetAttribute(attribute)
	return if type(value) == "number" and value == value then value else 0
end

function AdvicePanel.levels(player: Player, zone: Zones.Zone): (Level, Level)
	local damage: Level = levelOf(playerValue(player, AdvicePanel.DamageAttribute), zone.AdvisedDamage)
	local speed: Level = levelOf(playerValue(player, AdvicePanel.WalkSpeedAttribute), zone.AdvisedSpeed)
	return damage, speed
end

local function boxOf(object: Instance?): (CFrame?, Vector3?)
	if object and object:IsA("BasePart") then
		return object.CFrame, object.Size
	elseif object and object:IsA("Model") then
		return object:GetBoundingBox()
	end
	return nil, nil
end

function AdvicePanel.verticalSpan(object: Instance?): (number?, number?)
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

return AdvicePanel
