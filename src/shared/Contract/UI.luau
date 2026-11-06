--!strict
-- Contrat UI (doc, section 2.2) : écrans et billboards de Clément lus par le code.
--
-- Element.Path part de l'écran, segments séparés par des points : "List.Template.Price".
-- Chaque segment est cherché parmi les descendants du précédent (règle : Contract/Find),
-- pour que Clément puisse ajouter des cadres décoratifs autour (2.2, « libre pour Clément »).
-- Un nom doit y être unique. Class n'est donnée que quand le doc la donne, sauf les
-- éléments en ...Button, qui doivent être des boutons (déduit du nom).

export type Element = {
	Path: string,
	Class: string?, -- IsA attendu
	Template: boolean?, -- élément modèle cloné par le code : Visible = false
}

export type Screen = {
	Name: string,
	Class: string, -- "ScreenGui" ou "BillboardGui"
	Elements: { Element },
}

local BUTTON = "GuiButton" -- TextButton ou ImageButton

local UI = {}

-- Écrans du MVP, des ScreenGui directement dans StarterGui.
UI.Screens = {
	{
		Name = "UI_HUD",
		Class = "ScreenGui",
		Elements = {
			{ Path = "Cash", Class = "TextLabel" },
			{ Path = "Income", Class = "TextLabel" },
			{ Path = "Speed", Class = "TextLabel" },
			{ Path = "Strength", Class = "TextLabel" },
			{ Path = "Damage", Class = "TextLabel" },
			{ Path = "HeistTimer", Class = "TextLabel" },
			{ Path = "NightCountdown", Class = "TextLabel" },
			{ Path = "GuardMeter", Class = "Frame" },
			{ Path = "GuardMeter.Fill" },
			{ Path = "ReturnBaseButton", Class = BUTTON },
			{ Path = "RobuxShopButton", Class = BUTTON }, -- caché jusqu'à la MAJ 1
		},
	},
	{
		Name = "UI_WeaponShop",
		Class = "ScreenGui",
		Elements = {
			{ Path = "CloseButton", Class = BUTTON },
			{ Path = "List", Class = "ScrollingFrame" },
			{ Path = "List.Template", Template = true },
			{ Path = "List.Template.Icon" },
			{ Path = "List.Template.ItemName" },
			{ Path = "List.Template.Power" },
			{ Path = "List.Template.Price" },
			{ Path = "List.Template.BuyButton", Class = BUTTON },
			{ Path = "List.Template.EquipButton", Class = BUTTON },
		},
	},
	{
		Name = "UI_AuraShop",
		Class = "ScreenGui",
		Elements = {
			{ Path = "CloseButton", Class = BUTTON },
			{ Path = "Tabs.AurasTab" },
			{ Path = "Tabs.TrailsTab" },
			{ Path = "List" },
			{ Path = "List.Template", Template = true },
			{ Path = "List.Template.Icon" },
			{ Path = "List.Template.ItemName" },
			{ Path = "List.Template.Bonus" },
			{ Path = "List.Template.Price" },
			{ Path = "List.Template.BuyButton", Class = BUTTON },
			{ Path = "List.Template.EquipButton", Class = BUTTON },
		},
	},
	{
		Name = "UI_Unbox",
		Class = "ScreenGui",
		Elements = {
			{ Path = "Rarity", Class = "TextLabel" },
			{ Path = "ItemName", Class = "TextLabel" },
			{ Path = "Income", Class = "TextLabel" },
			{ Path = "ContinueButton", Class = BUTTON },
		},
	},
	{
		Name = "UI_TheftAlert",
		Class = "ScreenGui",
		Elements = {
			{ Path = "Banner" },
			{ Path = "ThiefName" },
			{ Path = "ItemName" },
			{ Path = "Arrow", Class = "ImageLabel" },
		},
	},
	{
		Name = "UI_Tutorial",
		Class = "ScreenGui",
		Elements = {
			{ Path = "Bubble" },
			{ Path = "Bubble.Label" },
			-- « Bubble avec Label, NextButton » : NextButton peut être dans la bulle ou à côté.
			{ Path = "NextButton", Class = BUTTON },
		},
	},
	{
		Name = "UI_Notify",
		Class = "ScreenGui",
		Elements = {
			{ Path = "Template", Template = true },
			{ Path = "Template.Icon" },
			{ Path = "Template.Label" },
		},
	},
} :: { Screen }

-- Billboards modèles, des BillboardGui directement dans ReplicatedStorage/Assets/UI.
UI.Billboards = {
	{ Name = "BB_WindowHP", Class = "BillboardGui", Elements = { { Path = "Fill" }, { Path = "Label" } } },
	{ Name = "BB_OpenTimer", Class = "BillboardGui", Elements = { { Path = "Label" } } },
	{
		Name = "BB_Item",
		Class = "BillboardGui",
		Elements = { { Path = "ItemName" }, { Path = "Rarity" }, { Path = "Income" } },
	},
	{
		Name = "BB_Carry",
		Class = "BillboardGui",
		Elements = { { Path = "ItemName" }, { Path = "Rarity" }, { Path = "Income" } },
	},
} :: { Screen }

-- Dossier des billboards, depuis ReplicatedStorage.
UI.BillboardFolder = { "Assets", "UI" }

-- Écrans connus hors MVP : acceptés, pas encore vérifiés (UI_RobuxShop : MAJ 1, 5.9).
UI.Later = { "UI_RobuxShop" }

-- Noms interdits pour un élément d'UI : ce sont aussi des propriétés Roblox (2.2).
UI.ReservedNames = { "Name", "Text", "Size", "Position", "Visible", "Parent" }

return UI
