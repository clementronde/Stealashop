--!strict
-- Gamepad (a419, demande de Cantin du 23/11 : jouable à la manette Xbox, PlayStation ou sur PC, sans rien changer pour le
-- clavier, la souris et le tactile). Lu par Shared/Gamepad (aide commune), GamepadController (menus),
-- HotbarController (L1 / R1), InventoryController (pose au sol), PawnShopController, UpgradeController, RebirthController
-- et SettingsController. Interrupteur : Features.Gamepad. Toutes les valeurs : V0 proposé (Cantin, 23/11).

local DeepFreeze = require(script.Parent.DeepFreeze)

local Gamepad = {
	-- Un menu = un ScreenGui allumé qui porte cet attribut (le groupe « Menu » de Clément, le même que Controllers/UI/Motion).
	-- Ouvert à la manette : son premier bouton utile est choisi (le plus haut, puis le plus à gauche) ; ButtonB le ferme
	-- comme sa croix (Motion.Dismiss) ; fermé, la sélection est rendue (le perso remarche).
	MenuAttribute = "ScreenGroup",
	-- Jamais choisis d'office : la croix (ButtonB la remplace).
	Skip = { "CloseButton", "CloseArrowButton" },
	-- Menus que ButtonB ne ferme pas : UI_Offline n'a pas de croix (choix de Clément), il se ferme par Claim.
	KeepOnBack = { "UI_Offline" },
	-- Sous-fenêtre d'un menu (Visible) : la sélection y va tant qu'elle est montrée (la confirmation YES / NO d'UI_Displayed).
	Modals = { "Confirm" },
	-- s : la sélection est revue (menu ouvert, bouton caché, liste remplie après coup, sélection sortie du menu).
	Tick = 0.2,
	-- px : deux boutons à moins de cet écart de hauteur sont sur la même ligne (le plus à gauche d'abord).
	RowTolerance = 8,
	-- Boutons (KeyCode) : retour, case précédente et suivante de la barre du bas, pose au sol, réglage d'un curseur.
	Back = Enum.KeyCode.ButtonB,
	HotbarPrev = Enum.KeyCode.ButtonL1,
	HotbarNext = Enum.KeyCode.ButtonR1,
	Place = Enum.KeyCode.ButtonR2,
	SliderLess = Enum.KeyCode.DPadLeft,
	SliderMore = Enum.KeyCode.DPadRight,
	SliderStep = 0.1, -- part du volume par appui (Music, Sound)
	-- Textes (en anglais) ; %s = le nom du bouton A de la manette (« A » sur Xbox, « Cross » sur PlayStation).
	-- a443 (Cantin, 24/11 : « qu'on ne puisse pas être ralenti », pareil sur PC, téléphone et manette ; Shared/FullStick,
	-- FullStickController ; interrupteur Features.FullSpeedStick ou FullSpeedStickDev, et non Features.Gamepad) : une
	-- direction de marche plus longue que DeadZone est remise à longueur 1 (pleine WalkSpeed), sinon à 0 (arrêt). Vaut pour
	-- la manette et pour le stick virtuel du téléphone ; le clavier ne change pas.
	FullStick = {
		DeadZone = 0.2, -- V0 proposé (Cantin, 24/11) : part de la course du stick (la zone morte de la manette chez Roblox : 0,2)
	},
	Texts = {
		RebirthConfirm = "Press %s again to rebirth", -- au lieu de « Tap again to rebirth »
	},
}

export type Gamepad = typeof(Gamepad)

return DeepFreeze(Gamepad)
