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
	Optional: boolean?, -- écran de repli : absent, rien à dire ; présent, vérifié comme les autres
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
			{ Path = "IndexButton", Class = BUTTON }, -- caché jusqu'à la MAJ 2 (L-026)
			{ Path = "RebirthButton", Class = BUTTON }, -- caché jusqu'à la MAJ 3 (L-026)
			-- Bouton « inviter un ami » de Clément, dans le cadre SocialRow (L-057, livré le
			-- 2026-11-07) : ouvre l'invitation de Roblox (InviteController). RewardsButton, à côté, ouvre
			-- UI_Rewards ; RewardsAlert = sa pastille rouge (RewardsController, DEV-101).
			{ Path = "InviteButton", Class = BUTTON },
			{ Path = "RewardsButton", Class = BUTTON },
			{ Path = "RewardsButton.RewardsAlert" },
			-- Bouton sac à dos de la colonne gauche (L-079, relevé de Studio du 2026-11-10) : ouvre et ferme
			-- UI_Inventory (InventoryController).
			{ Path = "InventoryButton", Class = BUTTON },
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
			-- Dans un cadre Buttons depuis la v2 (avec OpenNextButton) : chemin inchangé (Contract/Find).
			{ Path = "ContinueButton", Class = BUTTON },
			-- Ouverture des colis v2 (spec ouverture-colis, liaison L-046, UI_Unbox v2 de Clément du
			-- 2026-11-07, DEV-050) : cachés au repos, sauf ItemPreview, Backdrop et les cadres vides.
			{ Path = "Backdrop", Class = "Frame" }, -- scène assombrie (version complète)
			{ Path = "SkipButton", Class = BUTTON }, -- « TAP TO SKIP », plein écran
			{ Path = "Upgrade", Class = "Frame" }, -- amélioration du colis, au-dessus du colis
			{ Path = "Upgrade.UpgradeLabel", Class = "TextLabel" }, -- « UPGRADE! »
			{ Path = "Upgrade.UpgradeRarity", Class = "TextLabel" }, -- rareté atteinte, à sa couleur
			{ Path = "Reel", Class = "Frame" }, -- rouleau, un objet à la fois
			{ Path = "Reel.ReelGlow", Class = "Frame" }, -- lueur à la couleur de l'objet au centre
			{ Path = "Reel.ReelView", Class = "ViewportFrame" }, -- clones ITM_*, silhouettes par ImageColor3
			{ Path = "ItemPreview", Class = "Frame" }, -- l'objet révélé (ViewportFrame posé par le code)
			{ Path = "Rays", Class = "ImageLabel" }, -- rayons à la couleur de la rareté (texture MOD-041)
			{ Path = "Rarity.Rainbow", Class = "UIGradient" }, -- arc-en-ciel du Secret, désactivé au repos
			{ Path = "Rays.Rainbow", Class = "UIGradient" },
			{ Path = "UpgradeRarity.Rainbow", Class = "UIGradient" },
			{ Path = "Confetti", Class = "Frame" },
			{ Path = "Confetti.Template", Class = "Frame", Template = true }, -- cloné par le code
			{ Path = "Flash", Class = "Frame" }, -- flash blanc
			{ Path = "OpenNextButton", Class = BUTTON }, -- « OPEN NEXT », caché au repos
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
	-- Boutique Robux (MAJ 1, 5.9 ; Partie 2, 3.1) : noms de Clément validés par Ironix (L-047, sans
	-- GiftButton depuis L-051), branchés par RobuxShopController (DEV-100). Price est dans BuyButton ;
	-- Owned = coche et bouton gris d'un gamepass possédé.
	{
		Name = "UI_RobuxShop",
		Class = "ScreenGui",
		Elements = {
			{ Path = "CloseButton", Class = BUTTON },
			{ Path = "Tabs.OffersTab" },
			{ Path = "Tabs.GamepassesTab" },
			{ Path = "Tabs.CashTab" },
			{ Path = "Tabs.BoostsTab" },
			{ Path = "List", Class = "ScrollingFrame" },
			{ Path = "List.Template", Template = true },
			{ Path = "List.Template.Icon" },
			{ Path = "List.Template.ItemName" },
			{ Path = "List.Template.Effect" },
			{ Path = "List.Template.Price" },
			{ Path = "List.Template.BuyButton", Class = BUTTON },
			{ Path = "List.Template.Owned" },
		},
	},
	-- Écran de poursuite (liaison L-071, point 6 ; a42, en cours chez Clément : sirènes rouges et
	-- bleues, liseré rouge, avertissement). Ses noms internes ne sont pas fixés : le code n'allume et
	-- n'éteint que l'écran (ChaseController, pendant qu'un vigile poursuit le joueur local).
	{
		Name = "UI_Chase",
		Class = "ScreenGui",
		Elements = {},
	},
} :: { Screen }

-- Renaissance (MAJ 3 ; Partie 2, 3.2) : écran UI_Rebirth de Clément (UI-120, noms validés par Ironix
-- en L-047), ouvert en aperçu par RebirthController (L-071). Hint, le texte sous le bouton, est un nom
-- de Clément relevé dans Studio le 2026-11-08 (le code y écrit « Coming soon »). Les colonnes Lose et
-- Keep sont du texte fixe, pas au contrat.
table.insert(UI.Screens, {
	Name = "UI_Rebirth",
	Class = "ScreenGui",
	Elements = {
		{ Path = "CloseButton", Class = BUTTON },
		{ Path = "Level" },
		{ Path = "CashRequirement" },
		{ Path = "CashRequirement.CashAmount" },
		{ Path = "CashRequirement.CashBar" },
		{ Path = "CashRequirement.CashBar.Fill" },
		{ Path = "CashRequirement.CashLabel" },
		{ Path = "ItemRequirement" },
		{ Path = "ItemRequirement.Icon" },
		{ Path = "ItemRequirement.ItemName" },
		{ Path = "ItemRequirement.Rarity" },
		{ Path = "ItemRequirement.Status" },
		{ Path = "GainList" },
		-- Bouton en 2 temps : un cadre par état (Disabled → Ready → Confirm), un seul visible à la fois.
		{ Path = "ConfirmButton", Class = BUTTON },
		{ Path = "ConfirmButton.Disabled" },
		{ Path = "ConfirmButton.Ready" },
		{ Path = "ConfirmButton.Confirm" },
		{ Path = "Hint" },
	},
})

-- Billboards modèles, des BillboardGui directement dans ReplicatedStorage/Assets/UI.
UI.Billboards = {
	{ Name = "BB_WindowHP", Class = "BillboardGui", Elements = { { Path = "Fill" }, { Path = "Label" } } },
	-- Barre de vie du camion de l'événement (nom proposé par Ironix en L-052, livré par Clément le
	-- 2026-11-07) : mêmes éléments que BB_WindowHP (TruckController ; sans elle, BB_WindowHP agrandie).
	{ Name = "BB_TruckHP", Class = "BillboardGui", Elements = { { Path = "Fill" }, { Path = "Label" } } },
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
	-- Étiquette de chaque colis PNJ, dès le rayon (décision de Clément du 2026-11-07, L-031) :
	-- catégorie de l'objet, rareté, mutation (DEV-131 : « BIG · GOLD », cachée sans mutation). BB_Item et
	-- BB_Carry peuvent avoir un texte Mutation facultatif (nom proposé à Clément, hors contrat : sans lui, la
	-- mutation est écrite devant ItemName).
	{
		Name = "BB_Box",
		Class = "BillboardGui",
		Elements = { { Path = "Category" }, { Path = "Rarity" }, { Path = "Mutation" } },
	},
	-- Panneau d'approche au-dessus de la vitrine de chaque magasin PNJ (5.3, point 1 ; noms de L-044
	-- acceptés par Clément le 2026-11-07) : nom du magasin, PV de la vitrine, dégâts et vitesse
	-- conseillés. StoreInfoController écrit les 4 textes et colore Damage et Speed pour le joueur local.
	{
		Name = "BB_StoreInfo",
		Class = "BillboardGui",
		Elements = {
			{ Path = "StoreName", Class = "TextLabel" },
			{ Path = "HP", Class = "TextLabel" },
			{ Path = "Damage", Class = "TextLabel" },
			{ Path = "Speed", Class = "TextLabel" },
		},
	},
	-- Panneau de chaque arche de zone (liaison L-071, point 9 ; a42, noms de Clément, à remplir par le
	-- code) : nom de la zone, dégâts et vitesse conseillés. ZoneGateController écrit les 3 textes et
	-- colore Damage et Speed pour le joueur local, comme sur BB_StoreInfo.
	{
		Name = "BB_ZoneGate",
		Class = "BillboardGui",
		Elements = {
			{ Path = "ZoneName", Class = "TextLabel" },
			{ Path = "Speed", Class = "TextLabel" },
			{ Path = "Damage", Class = "TextLabel" },
		},
	},
} :: { Screen }

-- Dossier des billboards, depuis ReplicatedStorage.
UI.BillboardFolder = { "Assets", "UI" }

-- Écrans connus hors MVP : acceptés, pas encore vérifiés (UI_RobuxShop y était jusqu'à DEV-100 : il
-- est maintenant dans UI.Screens).
UI.Later = {} :: { string }

-- Noms interdits pour un élément d'UI : ce sont aussi des propriétés Roblox (2.2).
UI.ReservedNames = { "Name", "Text", "Size", "Position", "Visible", "Parent" }

-- Index des objets (DEV-111, avancé avant la MAJ 2 : L-071 point 1 ; Partie 2, 3.4) : noms des calques
-- de la maquette de Clément (UI-111, relevé de Studio du 2026-11-08), branchés par IndexController.
-- Counter est dans CounterPill ; Rays et Glow (dans le cadre Clip de la carte) prennent la couleur de
-- la rareté ; Lock = cadenas d'un objet pas encore découvert.
-- Depuis UI_Index_v2 (L-083, 2026-11-10), l'ancien écran n'est plus qu'un repli d'IndexController :
-- facultatif (Optional), vérifié seulement s'il est encore dans StarterGui.
table.insert(UI.Screens, {
	Name = "UI_Index",
	Class = "ScreenGui",
	Optional = true,
	Elements = {
		{ Path = "CloseButton", Class = BUTTON },
		{ Path = "Counter" },
		{ Path = "Tabs.Zone1Tab" },
		{ Path = "Tabs.Zone2Tab" },
		{ Path = "Tabs.Zone3Tab" },
		{ Path = "Tabs.Zone4Tab" },
		{ Path = "Tabs.Zone5Tab" },
		{ Path = "Tabs.Zone6Tab" },
		{ Path = "Tabs.SecretsTab" },
		{ Path = "ZoneReward" },
		{ Path = "ZoneReward.ZoneName" },
		{ Path = "ZoneReward.ZoneBar" },
		{ Path = "ZoneReward.ZoneBar.Fill" },
		{ Path = "ZoneReward.ZoneCount" },
		{ Path = "ZoneReward.Reward" },
		{ Path = "ZoneReward.Reward.RewardLabel" },
		{ Path = "List", Class = "ScrollingFrame" },
		{ Path = "List.Template", Template = true },
		{ Path = "List.Template.Icon" },
		{ Path = "List.Template.Lock" },
		{ Path = "List.Template.ItemName" },
		{ Path = "List.Template.Rays" },
		{ Path = "List.Template.Glow" },
		{ Path = "List.Template.RarityBar.Rarity" }, -- nom de la rareté, écrit par le code (vu en Play le 2026-11-08)
	},
})

-- Index v2 (L-083, points 5 et 6 ; relevé de Studio du 2026-11-10, agents/wave20-studio.md) : une seule
-- liste qui défile, une section par zone (Zone1Section à Zone6Section, SecretsSection), plus d'onglets.
-- Les cartes clonées de List.Template vont dans le Cards (UIGridLayout) de leur section. ScrollTrack est
-- le curseur de défilement, déplacé et dimensionné par le code dans la piste que Clément a posée.
-- Reward n'est demandé que dans les sections de zone (caché dans SecretsSection, pas lu).
local indexV2Elements = {
	{ Path = "CloseButton", Class = BUTTON },
	{ Path = "Counter" },
	{ Path = "List", Class = "ScrollingFrame" },
	{ Path = "List.Template", Template = true },
	{ Path = "List.Template.Icon" },
	{ Path = "List.Template.Lock" },
	{ Path = "List.Template.ItemName" },
	{ Path = "List.Template.Rays" },
	{ Path = "List.Template.Glow" },
	{ Path = "List.Template.RarityBar.Rarity" },
	{ Path = "ScrollTrack" },
} :: { Element }
local indexSections = {}
for zone = 1, 6 do
	table.insert(indexSections, `Zone{zone}Section`)
end
table.insert(indexSections, "SecretsSection")
for _, section in indexSections do
	table.insert(indexV2Elements, { Path = section })
	table.insert(indexV2Elements, { Path = `{section}.ZoneName` })
	table.insert(indexV2Elements, { Path = `{section}.ZoneBar` })
	table.insert(indexV2Elements, { Path = `{section}.ZoneBar.Fill` })
	table.insert(indexV2Elements, { Path = `{section}.ZoneCount` })
	if section ~= "SecretsSection" then
		table.insert(indexV2Elements, { Path = `{section}.Reward` })
		table.insert(indexV2Elements, { Path = `{section}.Reward.RewardLabel` })
	end
	table.insert(indexV2Elements, { Path = `{section}.Cards` })
end
table.insert(UI.Screens, {
	Name = "UI_Index_v2",
	Class = "ScreenGui",
	Elements = indexV2Elements,
})

-- Récompenses quotidiennes et de temps de jeu (DEV-101 ; Partie 2, 3.3 ; L-057) : écran UI_Rewards de
-- Clément (relevé de Studio du 2026-11-09), branché par RewardsController. Les lignes d'exemple Preview_*
-- (à côté du Template) sont retirées par le code. DayLabel et RewardName des jours restent de Clément.
local rewardsElements = {
	{ Path = "CloseButton", Class = BUTTON },
	{ Path = "Tabs.DailyTab" },
	{ Path = "Tabs.DailyTab.Selected" },
	{ Path = "Tabs.PlaytimeTab" },
	{ Path = "Tabs.PlaytimeTab.Selected" },
	{ Path = "DailyPage" },
	{ Path = "DailyPage.DailyClaimButton", Class = BUTTON },
	{ Path = "DailyPage.DailyClaimButton.ClaimLabel" },
	{ Path = "PlaytimePage" },
	{ Path = "PlaytimePage.List", Class = "ScrollingFrame" },
	{ Path = "PlaytimePage.List.Template", Template = true },
	{ Path = "PlaytimePage.List.Template.Icon" },
	{ Path = "PlaytimePage.List.Template.RewardName" },
	{ Path = "PlaytimePage.List.Template.Timer" },
	{ Path = "PlaytimePage.List.Template.ClaimButton" }, -- classe pas relevée : bouton ou cadre, le code accepte les deux
	{ Path = "PlaytimePage.List.Template.Claimed" },
} :: { Element }
for day = 1, 7 do
	table.insert(rewardsElements, { Path = `DailyPage.Streak.Day{day}` })
	table.insert(rewardsElements, { Path = `DailyPage.Streak.Day{day}.Today` })
	table.insert(rewardsElements, { Path = `DailyPage.Streak.Day{day}.Claimed` })
end
table.insert(UI.Screens, {
	Name = "UI_Rewards",
	Class = "ScreenGui",
	Elements = rewardsElements,
})

-- Inventaire (L-079, L-089, L-091 point 6 ; relevé de Studio du 2026-11-10, agents/wave21-studio.md) :
-- écran UI_Inventory de Clément, qui remplace toute la barre d'outils de Roblox, branché par
-- InventoryController. Quatre onglets (Tabs.<Nom>Tab, image Selected sur l'onglet choisi), une section
-- par onglet dans List (une seule visible). Les cartes clonées du Template de chaque section vont dans
-- son Cards (UIGridLayout). PotionsSection n'a pas de Template (pas de potions dans le jeu). Counter est
-- dans CounterPill, Displays dans DisplayPill ; Rays et Glow (dans le cadre Clip d'une carte) prennent
-- la couleur de la rareté ; HoverOutline = contour montré au survol d'une carte.
local inventoryElements = {
	{ Path = "CloseButton", Class = BUTTON },
	{ Path = "List", Class = "ScrollingFrame" },
	{ Path = "ScrollTrack" },
	{ Path = "Counter" },
	{ Path = "Displays" },
	{ Path = "EquipBestButton", Class = BUTTON },
	{ Path = "PotionsSection" },
} :: { Element }
for _, tab in { "Items", "Boxes", "Tools", "Potions" } do
	table.insert(inventoryElements, { Path = `Tabs.{tab}Tab`, Class = BUTTON })
	table.insert(inventoryElements, { Path = `Tabs.{tab}Tab.Selected` })
end
local inventoryCards: { [string]: { Element } } = {
	ItemsSection = {
		{ Path = "Icon" },
		{ Path = "ItemName" },
		{ Path = "RarityBar.Rarity" },
		{ Path = "Rays" },
		{ Path = "Glow" },
		{ Path = "MutationTag" },
		{ Path = "MutationTag.MutationLabel" },
		{ Path = "Income" },
		{ Path = "DisplayedBadge" },
		{ Path = "PlaceButton", Class = BUTTON },
		{ Path = "UnequipButton", Class = BUTTON },
		{ Path = "HoverOutline" },
	},
	BoxesSection = {
		{ Path = "Icon" },
		{ Path = "BoxName" },
		{ Path = "RarityBar.Rarity" },
		{ Path = "Rays" },
		{ Path = "Glow" },
		{ Path = "PlaceButton", Class = BUTTON },
		{ Path = "PlacedPill" },
		{ Path = "ReadyPill" },
		{ Path = "TimerPill" },
		{ Path = "TimerPill.TimerLabel" },
		{ Path = "HoverOutline" },
	},
	ToolsSection = {
		{ Path = "Icon" },
		{ Path = "ToolName" },
		{ Path = "ToolStat" },
		{ Path = "Rays" },
		{ Path = "Glow" },
		{ Path = "EquipButton", Class = BUTTON },
		{ Path = "EquippedPill" },
		{ Path = "HoverOutline" },
	},
}
for _, section in { "ItemsSection", "BoxesSection", "ToolsSection" } do
	table.insert(inventoryElements, { Path = section })
	table.insert(inventoryElements, { Path = `{section}.SectionCount.CountLabel` })
	table.insert(inventoryElements, { Path = `{section}.Cards` })
	table.insert(inventoryElements, { Path = `{section}.Cards.Template`, Class = BUTTON, Template = true })
	for _, element in inventoryCards[section] do
		table.insert(inventoryElements, { Path = `{section}.Cards.Template.{element.Path}`, Class = element.Class })
	end
end
table.insert(UI.Screens, {
	Name = "UI_Inventory",
	Class = "ScreenGui",
	Elements = inventoryElements,
})

return UI
