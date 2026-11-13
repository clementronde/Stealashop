--!strict
-- AlertBadge (vague 34, L-127 point 3, client) : les pastilles « ! » de Clément (modèle
-- ReplicatedStorage/Assets/UI/AlertBadge : pastille rouge, AlertLabel « ! », UIScale `Pulse`), toujours
-- cachées dans Studio. Module commun à tous les contrôleurs qui allument une pastille (Index, récompenses,
-- colonne de gauche du HUD, cartes de l'inventaire, barre du bas) : ReplicatedStorage/Shared/AlertBadge,
-- requis par le client seulement.
--
-- Règle (proposition de Clément, L-127) : une pastille est visible quand le joueur a quelque chose à
-- faire, et s'éteint quand l'action est faite (pas à l'ouverture de l'écran). Tant qu'elle est visible,
-- son UIScale `Pulse` bat : Scale 1 → 1,15 → 1 en 0,8 s, en boucle (valeurs de Clément, L-127). Toutes
-- les pastilles allumées battent ensemble (une seule horloge, une seule connexion Heartbeat, coupée quand
-- aucune n'est allumée). Éteinte : Visible = false et Pulse.Scale remis à 1. Une pastille sans `Pulse`
-- s'allume sans battre ; une pastille retirée de l'écran (écran recréé) est oubliée toute seule.
-- Seuls Visible et Pulse.Scale sont touchés (2.2, « Libre pour Ironix »).
--
-- API (client) :
--   AlertBadge.Set(badge, on)        allume (true) ou éteint (false) une pastille ; badge nil ou pas un
--                                    GuiObject : rien. Sans yield, rien n'est refait si rien ne change.
--   AlertBadge.SetAll(badges, on)    la même chose pour une liste (les deux exemplaires PC et téléphone…)
--   AlertBadge.IsOn(badge) -> boolean   allumée par ce module (bancs, barre de commande)
--   AlertBadge.Find(root, name) -> { GuiObject }   toutes les pastilles `name` sous `root` (Contract/Find)

local RunService = game:GetService("RunService")

local Find = require(script.Parent:WaitForChild("Contract"):WaitForChild("Find"))

local PULSE = "Pulse" -- UIScale posé par Clément dans chaque pastille (L-127)
local PEAK = 1.15 -- L-127 : Scale 1 → 1,15 → 1
local PERIOD = 0.8 -- L-127 : en 0,8 s, en boucle

local AlertBadge = {}

local lit: { [GuiObject]: boolean } = {}
local pulses: { [GuiObject]: UIScale } = {}
local clock = 0
local connection: RBXScriptConnection? = nil

local function pulseOf(badge: GuiObject): UIScale?
	local found = badge:FindFirstChild(PULSE)
	return if found and found:IsA("UIScale") then found :: UIScale else nil
end

local function forget(badge: GuiObject)
	lit[badge] = nil
	local pulse = pulses[badge]
	pulses[badge] = nil
	if pulse and pulse.Scale ~= 1 then
		pulse.Scale = 1
	end
end

local function step(dt: number)
	clock = (clock + dt) % PERIOD
	-- 1 → PEAK → 1 sur une période, en douceur (cosinus).
	local scale = 1 + (PEAK - 1) * (1 - math.cos(2 * math.pi * clock / PERIOD)) / 2
	for badge in lit do
		if badge.Parent == nil then
			forget(badge)
		else
			local pulse = pulses[badge]
			if pulse then
				pulse.Scale = scale
			end
		end
	end
	if next(lit) == nil then
		local running = connection
		connection = nil
		if running then
			running:Disconnect()
		end
	end
end

function AlertBadge.Set(badge: Instance?, on: boolean)
	if badge == nil or not badge:IsA("GuiObject") then
		return
	end
	local object = badge :: GuiObject
	if on then
		if object.Visible ~= true then
			object.Visible = true
		end
		if not lit[object] then
			lit[object] = true
			local pulse = pulseOf(object)
			if pulse then
				pulses[object] = pulse
			end
			if connection == nil then
				clock = 0
				connection = RunService.Heartbeat:Connect(step)
			end
		end
	else
		if object.Visible ~= false then
			object.Visible = false
		end
		if lit[object] then
			forget(object)
		end
	end
end

function AlertBadge.SetAll(badges: { GuiObject }, on: boolean)
	for _, badge in badges do
		AlertBadge.Set(badge, on)
	end
end

function AlertBadge.IsOn(badge: Instance?): boolean
	return badge ~= nil and badge:IsA("GuiObject") and lit[badge :: GuiObject] == true and (badge :: GuiObject).Visible
end

function AlertBadge.Find(root: Instance?, name: string): { GuiObject }
	local found: { GuiObject } = {}
	if root == nil then
		return found
	end
	for _, inst in Find.all(root, name) do
		if inst:IsA("GuiObject") then
			table.insert(found, inst :: GuiObject)
		end
	end
	return found
end

return AlertBadge
