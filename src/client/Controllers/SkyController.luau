--!strict
-- SkyController (DEV-047, client) : ciel et lumière du cycle jour/nuit (Partie 1, 5.12 : « Ciel et
-- lumières animés côté client (Lighting.ClockTime), lampadaires allumés »).
--
-- Côté client seulement, pendant le jeu : Lighting est à Clément (2.1) et rien n'est enregistré dans
-- la place. Ce contrôleur ne change que la copie locale de Lighting, chez ce joueur.
--
-- Suit les attributs du Workspace posés par NightCycleService (NightPhase, NightPhaseEndsAt) :
--   - Day : les réglages de Clément, lus au démarrage (ClockTime, Brightness, Ambient,
--     OutdoorAmbient), jamais changés de jour.
--   - Warning : au fil de l'alerte, du jour au couchant (Night.Sky.DuskClockTime), l'ambiance
--     extérieure teintée de Night.Sky.DuskTint : « ciel qui rougit ».
--   - Night : en Night.Sky.TransitionTime s, vers la nuit (NightClockTime, NightBrightness,
--     NightAmbient, NightOutdoorAmbient), qui reste jusqu'à l'aube.
--   - Aube (Night → Day) : en TransitionTime s, retour aux réglages de Clément.
--   L'heure avance : la nuit tombe par le soir, l'aube passe par le matin. Un joueur qui arrive en
--   pleine nuit la voit tomber en TransitionTime s.
--
-- Lampadaires : proposition à Clément, absente du contrat 2.1 (liaison) : le tag `NightLight` sur la
-- partie lumineuse. La nuit, ses lumières (PointLight, SpotLight, SurfaceLight, enfants ou
-- descendants) s'allument et la pièce passe en Neon ; le jour, tout reprend l'état livré. Rien de
-- taggé : rien ne change.
--
-- Coupé par Config/Features.NightCycle = false. API (client) : aucune.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Features = require(Config:WaitForChild("Features"))
local Night = require(Config:WaitForChild("Night"))

type Look = {
	Clock: number, -- heures, de 0 à 24
	Brightness: number,
	Ambient: Color3,
	Outdoor: Color3,
}

type LampState = {
	Material: Enum.Material,
	Lights: { [Light]: boolean }, -- Enabled d'origine
}

-- Posés par NightCycleService (mêmes noms là-bas).
local PHASE_ATTRIBUTE = "NightPhase"
local ENDS_AT_ATTRIBUTE = "NightPhaseEndsAt"
-- V0 proposé, absent du contrat 2.1 : partie lumineuse des lampadaires (à valider par Clément).
local LAMP_TAG = "NightLight"

local Sky = Night.Sky

local SkyController = {}

local base: Look? = nil -- réglages de Clément (le jour)
local phase: string? = nil
local fromLook: Look? = nil -- état au changement de phase
local changedAt = 0 -- os.clock() du changement de phase
local applied: Look? = nil -- dernier état écrit dans Lighting
local lampsOn = false
local lamps: { [BasePart]: LampState } = setmetatable({}, { __mode = "k" }) :: any

local function lerpNumber(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Heure de `a` à `b` : en avançant (`forward`), sinon par le plus court.
local function lerpClock(a: number, b: number, t: number, forward: boolean): number
	local delta = (b - a) % 24
	if not forward and delta > 12 then
		delta -= 24
	end
	return (a + delta * t) % 24
end

local function lerpLook(a: Look, b: Look, t: number, forward: boolean): Look
	return {
		Clock = lerpClock(a.Clock, b.Clock, t, forward),
		Brightness = lerpNumber(a.Brightness, b.Brightness, t),
		Ambient = a.Ambient:Lerp(b.Ambient, t),
		Outdoor = a.Outdoor:Lerp(b.Outdoor, t),
	}
end

local function duskLook(day: Look): Look
	return {
		Clock = Sky.DuskClockTime,
		Brightness = day.Brightness,
		Ambient = day.Ambient,
		Outdoor = day.Outdoor:Lerp(Sky.DuskTint, math.clamp(Sky.DuskTintAmount, 0, 1)),
	}
end

local NIGHT_LOOK: Look = {
	Clock = Sky.NightClockTime,
	Brightness = Sky.NightBrightness,
	Ambient = Sky.NightAmbient,
	Outdoor = Sky.NightOutdoorAmbient,
}

local function sameLook(a: Look, b: Look): boolean
	return a.Clock == b.Clock and a.Brightness == b.Brightness and a.Ambient == b.Ambient and a.Outdoor == b.Outdoor
end

local function apply(look: Look)
	local last = applied
	if last and sameLook(last, look) then
		return
	end
	applied = look
	Lighting.ClockTime = look.Clock
	Lighting.Brightness = look.Brightness
	Lighting.Ambient = look.Ambient
	Lighting.OutdoorAmbient = look.Outdoor
end

-- Lampadaires --------------------------------------------------------------------------------

local function setLamp(part: BasePart, on: boolean)
	local state = lamps[part]
	if on then
		if state == nil then
			local lights: { [Light]: boolean } = {}
			for _, descendant in part:GetDescendants() do
				if descendant:IsA("Light") then
					lights[descendant :: Light] = (descendant :: Light).Enabled
				end
			end
			state = { Material = part.Material, Lights = lights }
			lamps[part] = state
		end
		part.Material = Enum.Material.Neon
		for light in (state :: LampState).Lights do
			light.Enabled = true
		end
	elseif state then
		lamps[part] = nil
		part.Material = state.Material
		for light, enabled in state.Lights do
			light.Enabled = enabled
		end
	end
end

local function setLamps(on: boolean)
	lampsOn = on
	for _, instance in CollectionService:GetTagged(LAMP_TAG) do
		if instance:IsA("BasePart") then
			setLamp(instance :: BasePart, on)
		end
	end
end

-- Ciel ---------------------------------------------------------------------------------------

local function current(): Look
	return applied or base or NIGHT_LOOK
end

local function onPhaseChanged()
	local newPhase = Workspace:GetAttribute(PHASE_ATTRIBUTE)
	local name = if type(newPhase) == "string" then newPhase else nil
	if name == phase then
		return
	end
	phase = name
	fromLook = current()
	changedAt = os.clock()
	setLamps(name == "Night")
end

local function update()
	local day = base
	if day == nil then
		return
	end
	local transition = math.max(Sky.TransitionTime, 1e-3)
	local t = math.clamp((os.clock() - changedAt) / transition, 0, 1)
	local from = fromLook or day
	if phase == "Warning" then
		local endsAt = Workspace:GetAttribute(ENDS_AT_ATTRIBUTE)
		local length = math.max(Night.WarningDuration, 1e-3)
		local left = if type(endsAt) == "number" then endsAt - Workspace:GetServerTimeNow() else length
		local progress = math.clamp(1 - left / length, 0, 1)
		apply(lerpLook(day, duskLook(day), progress, false))
	elseif phase == "Night" then
		apply(lerpLook(from, NIGHT_LOOK, t, true))
	else
		-- Day (ou phase inconnue) : retour aux réglages de Clément, par le matin s'il faisait nuit.
		apply(if t >= 1 then day else lerpLook(from, day, t, true))
	end
end

function SkyController.Start()
	if not Features.NightCycle then
		return
	end
	base = {
		Clock = Lighting.ClockTime,
		Brightness = Lighting.Brightness,
		Ambient = Lighting.Ambient,
		Outdoor = Lighting.OutdoorAmbient,
	}
	applied = base
	fromLook = base
	phase = "Day"
	Workspace:GetAttributeChangedSignal(PHASE_ATTRIBUTE):Connect(onPhaseChanged)
	onPhaseChanged()
	CollectionService:GetInstanceAddedSignal(LAMP_TAG):Connect(function(instance: Instance)
		if lampsOn and instance:IsA("BasePart") then
			setLamp(instance :: BasePart, true) -- pièce arrivée en pleine nuit (streaming)
		end
	end)
	RunService.Heartbeat:Connect(update)
end

return SkyController
