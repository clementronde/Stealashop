--!strict
-- AmbienceController (client, vague 71, a237) : les sons d'ambiance des zones suivent le jour et la nuit
-- (liaison L-221, L-222 partie sons).
--
-- Clément pose des Sound en boucle dans la map avec l'attribut PlayAt (convention commune des zones) :
--   PlayAt = "Day"    joue le jour (alerte de la tombée de la nuit comprise), livré en lecture ;
--   PlayAt = "Night"  joue la nuit, livré arrêté ;
--   sans PlayAt       rien ne change : le son joue (ou non) comme Clément l'a livré.
-- La phase est celle que publie NightCycleService (attribut NightPhase du Workspace : Day, Warning, Night),
-- comme SkyController. Sans attribut (Features.NightCycle coupé) : le jour.
--
-- Au changement de phase, un son qui doit se taire descend à 0 en Night.AmbienceFade s puis s'arrête ; un son
-- qui doit jouer repart de 0 et monte à son volume livré (lu la première fois qu'on le voit) dans le même temps.
-- Un son arrivé plus tard (streaming, zones livrées ensuite, DescendantAdded) prend tout de suite l'état de la
-- phase, sans fondu. Le volume général reste celui du groupe SFX de SettingsController (ce contrôleur ne touche
-- que Sound.Volume, Playing par Play et Stop, et seulement sur la copie locale : la place n'est jamais modifiée).
-- Coût : une connexion sur le Workspace, une par phase ; un Tween par son au changement. Rien n'est envoyé au
-- serveur.
--
-- API (client) :
--   AmbienceController.GetState() -> { Phase: string, Night: boolean, Count: number }   pour un banc ou un essai

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Night = require(Shared:WaitForChild("Config"):WaitForChild("Night"))
local Attributes = require(Shared:WaitForChild("Contract"):WaitForChild("Attributes"))

export type AmbienceState = {
	Phase: string,
	Night: boolean,
	Count: number, -- sons PlayAt suivis
}

type Tracked = {
	Volume: number, -- volume livré par Clément
	Tween: Tween?,
}

-- Posés par NightCycleService (mêmes noms là-bas et dans SkyController).
local PHASE_ATTRIBUTE = "NightPhase"
local NIGHT_PHASE = "Night"
-- Convention des zones (L-221, Contract/Attributes.PlayAt).
local PLAY_AT_ATTRIBUTE: string = Attributes.PlayAt.Name
local DAY: string = Attributes.PlayAt.Values[1]
local NIGHT: string = Attributes.PlayAt.Values[2]

local FADE: number = Night.AmbienceFade

local AmbienceController = {}

local tracked: { [Sound]: Tracked } = setmetatable({}, { __mode = "k" }) :: any
local isNight = false

local function readNight(): boolean
	return Workspace:GetAttribute(PHASE_ATTRIBUTE) == NIGHT_PHASE
end

-- Le son doit-il jouer maintenant ? nil : pas un son d'ambiance (pas de PlayAt connu).
local function wanted(sound: Sound): boolean?
	local playAt = sound:GetAttribute(PLAY_AT_ATTRIBUTE)
	if playAt == DAY then
		return not isNight
	elseif playAt == NIGHT then
		return isNight
	end
	return nil
end

local function cancel(entry: Tracked)
	local tween = entry.Tween
	entry.Tween = nil
	if tween then
		tween:Cancel()
	end
end

-- Met le son dans l'état voulu : d'un coup (instant), ou par un fondu de FADE s.
local function apply(sound: Sound, entry: Tracked, on: boolean, instant: boolean)
	cancel(entry)
	if instant or FADE <= 0 then
		if on then
			sound.Volume = entry.Volume
			if not sound.Playing then
				sound:Play()
			end
		else
			sound:Stop()
			sound.Volume = entry.Volume
		end
		return
	end
	if on then
		if not sound.Playing then
			sound.Volume = 0
			sound:Play()
		end
	elseif not sound.Playing then
		sound.Volume = entry.Volume -- déjà arrêté : rien à faire entendre
		return
	end
	local tween = TweenService:Create(sound, TweenInfo.new(FADE, Enum.EasingStyle.Linear), {
		Volume = if on then entry.Volume else 0,
	})
	entry.Tween = tween
	tween.Completed:Connect(function(playbackState: Enum.PlaybackState)
		if entry.Tween ~= tween then
			return -- remplacé par un autre changement
		end
		entry.Tween = nil
		if not on and playbackState == Enum.PlaybackState.Completed then
			sound:Stop()
			sound.Volume = entry.Volume -- au repos, le volume livré
		end
	end)
	tween:Play()
end

local function track(instance: Instance)
	if not instance:IsA("Sound") then
		return
	end
	local sound = instance :: Sound
	if tracked[sound] ~= nil then
		return
	end
	local on = wanted(sound)
	if on == nil then
		return -- sans PlayAt : rien ne change
	end
	local entry: Tracked = { Volume = sound.Volume, Tween = nil }
	tracked[sound] = entry
	apply(sound, entry, on, true)
end

local function onPhaseChanged()
	local night = readNight()
	if night == isNight then
		return
	end
	isNight = night
	for sound, entry in tracked do
		if sound.Parent == nil then
			cancel(entry)
			tracked[sound] = nil
			continue
		end
		local on = wanted(sound)
		if on ~= nil then
			apply(sound, entry, on, false)
		end
	end
end

function AmbienceController.GetState(): AmbienceState
	local count = 0
	for _ in tracked do
		count += 1
	end
	local phase = Workspace:GetAttribute(PHASE_ATTRIBUTE)
	return {
		Phase = if type(phase) == "string" then phase else DAY,
		Night = isNight,
		Count = count,
	}
end

function AmbienceController.Start()
	isNight = readNight()
	Workspace:GetAttributeChangedSignal(PHASE_ATTRIBUTE):Connect(onPhaseChanged)
	Workspace.DescendantAdded:Connect(track)
	for _, descendant in Workspace:GetDescendants() do
		track(descendant)
	end
end

return AmbienceController
