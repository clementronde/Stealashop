--!strict
-- SettingsService (L-095 point 2) : réglages du joueur gardés d'une session à l'autre (écran UI_Settings
-- de Clément, SettingsController ; valeurs dans Config/Settings).
--
-- Rôle :
--   - chargement du profil : les réglages sauvegardés (champ facultatif Settings du profil, sans
--     changement de version : absent = réglages par défaut ; un champ invalide reprend sa valeur par
--     défaut, Settings.Sanitize) sont posés en attributs du Player : MusicVolume (lu par
--     MusicController), SfxVolume, VfxEnabled et ClickSound (lus par SettingsController et par les
--     contrôleurs d'effets). Le profil n'est pas réécrit au chargement ;
--   - SaveSettings(music, sfx, vfx, click) : Net a déjà contrôlé la forme (volumes finis de 0 à 1,
--     booléen, texte de 16 caractères au plus) et le débit (Settings.SaveRate par seconde). Le service
--     vérifie que click est l'un des sons de Config/Settings.Clicks ; refusé, rien ne change (une ligne
--     en Studio). Accepté : profil Settings remplacé, attributs remis aux valeurs enregistrées.
-- Rien de sensible : aucune valeur de jeu (argent, stats, raretés) ne dépend des réglages.
--
-- API (côté serveur) :
--   SettingsService.Get(player) -> Values?   réglages en vigueur (défaut si rien n'est sauvegardé) ;
--                                            nil si le profil n'est pas chargé

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Settings = require(Shared.Config.Settings)
local Net = require(Shared.Net.Net)

local DataService = require(script.Parent.DataService)

type Values = Settings.Values

local IS_STUDIO = RunService:IsStudio()

local SettingsService = {}

local function log(message: string)
	if IS_STUDIO then
		print(`[SettingsService] {message}`)
	end
end

local function publish(player: Player, values: Values)
	player:SetAttribute(Settings.MusicAttribute, values.Music)
	player:SetAttribute(Settings.SfxAttribute, values.Sfx)
	player:SetAttribute(Settings.VfxAttribute, values.Vfx)
	player:SetAttribute(Settings.ClickAttribute, values.Click)
end

function SettingsService.Get(player: Player): Values?
	local data = DataService.Get(player)
	if data == nil then
		return nil
	end
	return Settings.Sanitize(data.Settings)
end

local function onProfileLoaded(player: Player)
	local values = SettingsService.Get(player)
	if values ~= nil and player.Parent ~= nil then
		publish(player, values)
	end
end

local function onSave(player: Player, music: number, sfx: number, vfx: boolean, click: string)
	if not Settings.IsClick(click) then
		log(`{player.Name} : son de clic « {click} » inconnu, réglages refusés`)
		return
	end
	local data = DataService.Get(player)
	if data == nil then
		return
	end
	local values: Values = { Music = music, Sfx = sfx, Vfx = vfx, Click = click }
	data.Settings = values
	publish(player, values)
end

function SettingsService.Init()
	Net.Server.SaveSettings:Connect(onSave)
	DataService.OnProfileLoaded(onProfileLoaded)
end

return SettingsService
