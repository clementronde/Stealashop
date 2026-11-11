--!strict
-- Réglages du joueur (liaison L-095 point 2 ; écran UI_Settings de Clément, docs/claude/notes/ui-settings.md).
-- Lu par SettingsService (serveur : sauvegarde dans le profil, champ facultatif Settings) et par
-- SettingsController (client : écran, attributs du Player, groupe de sons SFX, son de clic) ; MusicController
-- lit déjà l'attribut de la musique (Config/Music.VolumeAttribute), ShatterController, CosmeticController,
-- DamageNumberController et DisplayController lisent celui des effets visuels (Settings.VfxReduced).
--
-- Origine des valeurs :
--   « Clément »  noms et valeurs de Clément (ui-settings.md, prototype tools/clement/settings_proto.luau) ;
--   « tableau »  docs/claude/notes/ui-motion-skilltree.md (T.47 KnobGrab, T.48 ToggleSlide) ;
--   « V0 »       V0 proposé, absent du doc.
--
-- API :
--   Settings.Default -> Values                    réglages d'un joueur qui n'a rien sauvegardé
--   Settings.Sanitize(value) -> Values            copie propre d'une valeur lue (profil) : un champ
--                                                 absent ou invalide prend sa valeur par défaut
--   Settings.IsClick(id) -> boolean               id est l'un des sons de clic (Settings.Clicks)
--   Settings.ClickIndex(id) -> number             rang du son de clic (1 si inconnu)
--   Settings.ClickSound(id) -> string             nom de l'objet Sound de Clément (UI_Click_<Id>)
--   Settings.ReadVolume(value) -> number?         volume lu sur un attribut (0 à 1), nil si invalide
--   Settings.VfxReduced(player) -> boolean        effets visuels coupés (VfxEnabled = false)

local DeepFreeze = require(script.Parent.DeepFreeze)
local Music = require(script.Parent.Music)

-- Réglages d'un joueur, tels qu'ils sont sauvegardés (Types/Profile, champ Settings).
export type Values = {
	Music: number, -- 0 à 1
	Sfx: number, -- 0 à 1
	Vfx: boolean,
	Click: string, -- Id d'un son de Settings.Clicks
}

export type Click = { Id: string, DisplayName: string }

local Settings = {
	-- Attributs du Player, posés par SettingsService (chargement, sauvegarde acceptée) et par
	-- SettingsController (aussitôt, côté client).
	MusicAttribute = Music.VolumeAttribute, -- « MusicVolume », de 0 à 1, déjà lu par MusicController
	SfxAttribute = "SfxVolume", -- Clément (ui-settings.md) : de 0 à 1
	VfxAttribute = "VfxEnabled", -- Clément (ui-settings.md) : booléen
	ClickAttribute = "ClickSound", -- Clément (ui-settings.md) : Id du son de clic

	Default = {
		Music = 0.8, -- Clément : prototype settings_proto.luau (state.Music = 0.8), ValueLabel « 80% »
		Sfx = 1, -- Clément : ValueLabel « 100% »
		Vfx = true, -- Clément : ToggleLabel « ON »
		Click = "Classic", -- Clément : ChoiceLabel « CLASSIC »
	} :: Values,

	-- Sons de clic, dans l'ordre de la rangée ClickRow (Clément, 2026-11-10) : objets Sound
	-- ReplicatedStorage/Assets/Sounds/UI/Clicks/UI_Click_<Id>.
	Clicks = {
		{ Id = "Classic", DisplayName = "CLASSIC" },
		{ Id = "Sharp", DisplayName = "SHARP" },
		{ Id = "Tick", DisplayName = "TICK" },
		{ Id = "Bubble", DisplayName = "BUBBLE" },
		{ Id = "Soft", DisplayName = "SOFT" },
	} :: { Click },
	ClickSoundFormat = "UI_Click_%s",
	MaxClickLength = 16, -- V0 : longueur maximale de l'Id envoyé par le client (Net/Definitions)

	-- Groupe de sons des effets (Clément : « SoundGroup des effets, à créer côté code ») : créé par le
	-- client dans SoundService ; son Volume suit SfxVolume. Tous les sons du jeu y vont, sauf la musique
	-- (préfixe MUS_, Config/Music) et un son que Clément a déjà rangé dans un autre groupe.
	SfxGroup = "SFX", -- V0 : nom proposé
	MusicPrefix = "MUS_", -- L-056 : préfixe des musiques (10.3)

	-- Sauvegarde : le client attend SaveDelay s sans nouveau changement avant d'envoyer ses réglages
	-- (un seul envoi pour un glisser ou plusieurs clics de suite).
	SaveDelay = 0.5, -- V0
	SaveRate = 4, -- V0 : envois acceptés par seconde glissante (Net/Definitions, SaveSettings)

	-- Effets visuels coupés (VfxEnabled = false) : ce que les contrôleurs allègent.
	VfxOff = {
		AuraFactor = 0, -- V0 (vague 24, retour de Cantin : 0,5 changeait trop peu) : auras coupées (débit de particules × 0)
		BurstFactor = 0, -- V0 (vague 24) : part des particules de la gerbe d'une plaque d'argent (DisplayController) ; 0 = pas de gerbe
	},

	-- Animations de l'écran (tableau, lignes T.47 et T.48 ; prototype settings_proto.luau).
	Motion = {
		KnobGrab = {
			To = 1.18, -- tableau : « × 1,18 en 0,08 pendant le glisser, retour à 1 au relâché »
			Time = 0.08,
			ReleaseTime = 0.2, -- prototype : retour en M.ReleaseTime (0,2), Back Out
			Style = Enum.EasingStyle.Back,
			Direction = Enum.EasingDirection.Out,
			ScaleName = "KnobScale", -- V0 : UIScale du bouton rond (posé à la liaison de l'écran, à 1 au repos)
		},
		ToggleSlide = {
			Time = 0.16, -- tableau : « glisse d'un bout à l'autre en 0,16 », Back Out
			Style = Enum.EasingStyle.Back,
			Direction = Enum.EasingDirection.Out,
		},
	},
}

function Settings.IsClick(id: any): boolean
	if type(id) ~= "string" then
		return false
	end
	for _, click in Settings.Clicks do
		if click.Id == id then
			return true
		end
	end
	return false
end

function Settings.ClickIndex(id: any): number
	for index, click in Settings.Clicks do
		if click.Id == id then
			return index
		end
	end
	return 1
end

function Settings.ClickSound(id: string): string
	return string.format(Settings.ClickSoundFormat, id)
end

function Settings.ReadVolume(value: any): number?
	if type(value) == "number" and value == value and value >= 0 and value <= 1 then
		return value
	end
	return nil
end

function Settings.Sanitize(value: any): Values
	local default = Settings.Default
	local source = if type(value) == "table" then value else {}
	local vfx = source.Vfx
	return {
		Music = Settings.ReadVolume(source.Music) or default.Music,
		Sfx = Settings.ReadVolume(source.Sfx) or default.Sfx,
		Vfx = if type(vfx) == "boolean" then vfx else default.Vfx,
		Click = if Settings.IsClick(source.Click) then source.Click else default.Click,
	}
end

function Settings.VfxReduced(player: Instance?): boolean
	return player ~= nil and player:GetAttribute(Settings.VfxAttribute) == false
end

export type Settings = typeof(Settings)

return DeepFreeze(Settings)
