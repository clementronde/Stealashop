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
	-- a125 : élément facultatif (le code ne fait rien sans lui) : absent, avertissement orange (Note dit le
	-- repli), jamais un problème ; présent, contrôlé comme les autres.
	Optional: boolean?,
	Note: string?,
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
			-- ReturnBaseButton : retiré le 2026-11-14 (vague 38, L-135 point 3, Clément : « le bouton BASE n'existe plus »).
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
			-- Bouton engrenage de SocialRow (L-095 point 2, relevé de Studio du 2026-11-11) : caché par
			-- Clément, montré par SettingsController (Features.Settings) ; ouvre UI_Settings.
			{ Path = "SettingsButton", Class = BUTTON },
			-- Bouton « Upgrades » de la colonne gauche (vague 27, L-096 point 2) : caché par Clément, montré
			-- par SkillTreeController ; ouvre UI_SkillTree. Un exemplaire dans LeftRail et un dans
			-- LeftRailTouch (UI.Twins).
			{ Path = "SkillTreeButton", Class = BUTTON },
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
	-- Revu par Clément (L-108 point 5, 2026-11-12) : StoreName, Stats > HP (caché), SpeedLine (Speed,
	-- SpeedIcon), DamageLine (Damage « Strength 1 », DamageIcon). Le code ne lit que ces 4 noms, cherchés
	-- parmi les descendants : l'ancien gabarit (sans Stats ni lignes) et le nouveau passent tous deux.
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
	-- BB_ZoneGate (panneau des arches, L-071 point 9) : retiré par Clément le 2026-11-12 (L-110), remplacé
	-- par l'écran UI_ZoneBanner (en fin de fichier).
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
	Optional = true, -- depuis UI_Index_v3 (L-095 point 1) : repli d'IndexController, vérifié s'il est encore là
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
		-- Vague 34 (L-127 points 3 et 4 de Clément) : voile de l'objet sous antivol, pastille « ! » qui bat.
		{ Path = "AntiTheft" },
		{ Path = "AntiTheft.LockLabel", Class = "TextLabel" },
		{ Path = "CardAlert" },
		{ Path = "CardAlert.Pulse", Class = "UIScale" },
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
		{ Path = "CardAlert" }, -- vague 34 (L-127 point 3)
		{ Path = "CardAlert.Pulse", Class = "UIScale" },
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

-- Gains hors ligne (DEV-102, L-092 3f ; relevé de Studio du 2026-11-11, agents/wave22-studio.md) : écran
-- UI_Offline de Clément (groupe « Menu », sans CloseButton), branché par OfflineController. Amount = la
-- somme en attente ; ClaimButton la réclame ; DoubleButton (×2 contre des Robux) dit « Soon » tant que la
-- boutique Robux est coupée. EarnedLabel, PriceLabel, TwoXTag et Flyer restent de Clément.
table.insert(UI.Screens, {
	Name = "UI_Offline",
	Class = "ScreenGui",
	Elements = {
		{ Path = "Amount", Class = "TextLabel" },
		{ Path = "ClaimButton", Class = BUTTON },
		{ Path = "DoubleButton", Class = BUTTON },
	},
})

-- Index v3 (L-095 point 1 ; noms de docs/claude/notes/ui-index-v3.md, prototype tools/clement/index_v3.luau,
-- relevé de Studio du 2026-11-11) : remplace UI_Index_v2. Une liste, une section par zone (cartes dans
-- Content.Cards, ZoneArt.ZoneName, Content.ZoneBar avec Fill, ZoneCount et ZoneItem), la fiche Detail de
-- l'objet cliqué, Rewards de la zone visible, Categories (NORMAL, SECRETS, MUTATIONS) et MutationTabs
-- (un onglet par effet de Config/Mutations). Branché par IndexController.
local indexV3Elements = {
	{ Path = "CloseButton", Class = BUTTON },
	{ Path = "Counter" },
	{ Path = "List", Class = "ScrollingFrame" },
	{ Path = "List.Template", Class = BUTTON, Template = true },
	{ Path = "List.Template.Clip" },
	{ Path = "List.Template.Clip.Glow" },
	{ Path = "List.Template.Clip.Rays" },
	{ Path = "List.Template.Icon" },
	{ Path = "List.Template.ItemName" },
	{ Path = "List.Template.Lock" },
	{ Path = "List.Template.HoverOutline" },
	{ Path = "Detail" },
	{ Path = "Detail.DetailIcon" },
	{ Path = "Detail.DetailName" },
	{ Path = "Detail.DetailRarity" },
	{ Path = "Detail.DetailIncome" },
	{ Path = "Rewards" },
	{ Path = "Rewards.SpeedReward.Amount" },
	{ Path = "Rewards.CashReward.Amount" },
	{ Path = "Rewards.ClaimButton", Class = BUTTON },
	{ Path = "Rewards.ClaimButton.ClaimLabel" },
	{ Path = "MutationTabs" },
	{ Path = "MutationCaption" },
} :: { Element }
for _, section in indexSections do
	for _, path in { "", ".ZoneName", ".ZoneBar", ".ZoneBar.Fill", ".ZoneBar.ZoneCount", ".ZoneBar.ZoneItem", ".Cards" } do
		table.insert(indexV3Elements, { Path = section .. path })
	end
end
for _, button in { "NormalButton", "SecretsButton", "MutationsButton" } do
	table.insert(indexV3Elements, { Path = `Categories.{button}`, Class = BUTTON })
	table.insert(indexV3Elements, { Path = `Categories.{button}.Selected` })
end
for _, effect in { "Shiny", "Gold", "Neon", "Diamond", "Glitch", "Hacked", "Rainbow" } do -- Config/Mutations.Effects
	table.insert(indexV3Elements, { Path = `MutationTabs.{effect}Tab`, Class = BUTTON })
	table.insert(indexV3Elements, { Path = `MutationTabs.{effect}Tab.Selected` })
end
table.insert(UI.Screens, {
	Name = "UI_Index_v3",
	Class = "ScreenGui",
	Elements = indexV3Elements,
})

-- Réglages (L-095 point 2 ; noms de docs/claude/notes/ui-settings.md, relevé de Studio du 2026-11-11,
-- agents/wave23-studio.md) : écran UI_Settings, branché par SettingsController.
local settingsElements = {
	{ Path = "CloseButton", Class = BUTTON },
	{ Path = "VfxRow.Toggle", Class = BUTTON },
	{ Path = "VfxRow.Toggle.OnFill" },
	{ Path = "VfxRow.Toggle.OffFill" },
	{ Path = "VfxRow.Toggle.ToggleKnob" },
	{ Path = "VfxRow.Toggle.ToggleLabel" },
	{ Path = "ClickRow.PrevButton", Class = BUTTON },
	{ Path = "ClickRow.NextButton", Class = BUTTON },
	{ Path = "ClickRow.ChoiceLabel" },
} :: { Element }
for _, row in { "MusicRow", "SoundRow" } do
	table.insert(settingsElements, { Path = `{row}.Slider.Track`, Class = BUTTON })
	table.insert(settingsElements, { Path = `{row}.Slider.Track.Fill` })
	table.insert(settingsElements, { Path = `{row}.Slider.Knob`, Class = BUTTON })
	table.insert(settingsElements, { Path = `{row}.ValueLabel` })
end
table.insert(UI.Screens, {
	Name = "UI_Settings",
	Class = "ScreenGui",
	Elements = settingsElements,
})

-- Barre du bas (L-095 point 6 ; noms de docs/claude/notes/ui-liste-pour-liaison.md, lignes 22 et 23,
-- relevé de Studio du 2026-11-11, agents/wave24-studio.md) : écran UI_Hotbar, branché par
-- HotbarController. Bar porte les attributs SlotCount et TouchSlotCount ; une case = une copie de
-- Bar.Template.
local hotbarElements = {
	{ Path = "Bar" },
	{ Path = "Bar.Template", Class = BUTTON, Template = true },
} :: { Element }
-- Vague 34 (L-127 points 3 et 4 de Clément) : AntiTheft (voile, LockLabel caché ici), SlotAlert (pastille « ! »)
-- et son UIScale Pulse, en fin de liste.
for _, path in { "Clip", "Clip.Glow", "Icon", "KeyLabel", "ItemName", "Income", "Equipped", "HoverOutline", "AntiTheft", "SlotAlert", "SlotAlert.Pulse" } do
	table.insert(hotbarElements, { Path = `Bar.Template.{path}` })
end
table.insert(UI.Screens, {
	Name = "UI_Hotbar",
	Class = "ScreenGui",
	Elements = hotbarElements,
})

-- Messages du bas (L-095 point 3 ; note ui-feel2-horsligne-poursuite-barre.md, relevé de Studio du
-- 2026-11-11, agents/wave24-studio.md) : NotifyController clone Stack.Template ; sans cet écran, UI_Notify.
table.insert(UI.Screens, {
	Name = "UI_Toast",
	Class = "ScreenGui",
	Optional = true,
	Elements = {
		{ Path = "Stack" },
		{ Path = "Stack.Template", Class = "TextLabel", Template = true },
	} :: { Element },
})

-- Arrivée en zone safe avec un colis (L-095 point 4 ; contrat dans ui-L092-retours.md, section 2) :
-- UiFeelController.Escape.
table.insert(UI.Screens, {
	Name = "UI_Escape",
	Class = "ScreenGui",
	Optional = true,
	Elements = {
		{ Path = "Flash" },
		{ Path = "Banner" },
		{ Path = "Banner.Title", Class = "TextLabel" },
		{ Path = "Banner.Subtitle", Class = "TextLabel" },
		{ Path = "Banner.BoxIcon", Class = "ImageLabel" },
	} :: { Element },
})

-- Arbre de compétences (vague 27, L-096 point 2 ; note docs/claude/notes/ui-skilltree-pour-ironix.md, relevé de
-- Studio du 2026-11-11, agents/wave27-studio.md) : écran UI_SkillTree, branché par SkillTreeController. Les
-- tuiles sont posées à la main dans Tree (pas de Template) : une par compétence de Config/SkillTree (champ
-- Tile), plus RootTile (rien à acheter) et Tile_Next2 (jamais ouverte). Chaque tuile de compétence a ses
-- calques d'état Bought, Available et Locked, et Info (Level, TileName, PriceRow.Price, PriceRow.PriceNeed).
local skillTreeElements = {
	{ Path = "Tree" },
	{ Path = "Tree.SelectionGlow" },
	{ Path = "Tree.RootTile", Class = BUTTON },
	{ Path = "Tree.Tile_Next2", Class = BUTTON },
	{ Path = "CashPill.Cash", Class = "TextLabel" },
	{ Path = "InfoPanel.Header.NodeName" },
	{ Path = "InfoPanel.NodeIcon" },
	{ Path = "InfoPanel.NodeLevel" },
	{ Path = "InfoPanel.StatBox.NodeStat" },
	{ Path = "InfoPanel.StatBox.NodeEffect" },
	{ Path = "InfoPanel.PriceRow.NodePrice" },
	{ Path = "InfoPanel.BuyButton", Class = BUTTON },
	{ Path = "InfoPanel.NeedButton", Class = BUTTON },
	{ Path = "InfoPanel.NeedButton.NeedLabel" },
	{ Path = "CloseButton", Class = BUTTON },
} :: { Element }
-- Tile_ShopLevel : la tuile Walls (vague 29, L-105 point 3). Renommage en Tile_Walls proposé, pas encore annoncé :
-- le contrat garde l'ancien nom ; SkillTreeController accepte les deux (Config/SkillTree, OldTiles).
for _, tile in { "Tile_ShopLevel", "Tile_Glass", "Tile_GlassRegen", "Tile_Cameras", "Tile_Guards", "Tile_PotionLuck", "Tile_Curtain", "Tile_DoorGuard", "Tile_PotionTime", "Tile_Next1", "Tile_Next4" } do
	table.insert(skillTreeElements, { Path = `Tree.{tile}`, Class = BUTTON })
	for _, part in { "Bought", "Available", "Locked", "Info", "Info.Level", "Info.TileName", "Info.PriceRow.Price", "Info.PriceRow.PriceNeed" } do
		table.insert(skillTreeElements, { Path = `Tree.{tile}.{part}` })
	end
end
table.insert(UI.Screens, {
	Name = "UI_SkillTree",
	Class = "ScreenGui",
	Elements = skillTreeElements,
})

-- Doublons voulus (L-099 point 1 ; décision de Clément du 2026-11-11, version B) : la colonne de gauche
-- existe deux fois dans UI_HUD, LeftRail (PC) et LeftRailTouch (téléphone), avec les mêmes boutons.
-- Le code branche chaque exemplaire ; le ContractChecker accepte un exemplaire par cadre de Containers.
UI.Twins = {
	UI_HUD = {
		Containers = { "LeftRail", "LeftRailTouch" },
		Names = { "RobuxShopButton", "IndexButton", "RebirthButton", "InventoryButton", "SkillTreeButton" },
	},
} :: { [string]: { Containers: { string }, Names: { string } } }

-- Receleur (vague 29, DEV-034 ; L-106 point 4, L-107 point 2 ; note docs/claude/notes/ui-pawnshop.md, relevé de
-- Studio du 2026-11-12, agents/wave29-studio.md) : dialogue UI_PawnShop (ScreenGroup Menu) et bulle BB_PawnTalk du
-- vendeur, branchés par PawnShopController. DealButton et NoDealButton sont cachés par Clément, montrés par le code.
local pawnElements = { { Path = "Dialog" }, { Path = "Dialog.Choices" } } :: { Element }
local PAWN_PRICED: { [string]: boolean } = { SellHeldButton = true, SellAllButton = true, DealButton = true }
for _, button in { "SellHeldButton", "SellAllButton", "LeaveButton", "DealButton", "NoDealButton" } do
	local path = `Dialog.Choices.{button}`
	table.insert(pawnElements, { Path = path, Class = BUTTON })
	table.insert(pawnElements, { Path = `{path}.KeyLabel`, Class = "TextLabel" })
	table.insert(pawnElements, { Path = `{path}.ChoiceLabel`, Class = "TextLabel" })
	if PAWN_PRICED[button] then
		table.insert(pawnElements, { Path = `{path}.Price`, Class = "TextLabel" })
	end
end
table.insert(UI.Screens, {
	Name = "UI_PawnShop",
	Class = "ScreenGui",
	Elements = pawnElements,
})
table.insert(UI.Billboards, {
	Name = "BB_PawnTalk",
	Class = "BillboardGui",
	Elements = { { Path = "Line", Class = "TextLabel" } },
})
-- Panel admin (vague 29, L-108 point 4 ; note docs/claude/notes/ui-admin.md, relevé de Studio du 2026-11-12,
-- agents/wave29-studio.md) : écran UI_Admin, branché par AdminController. Facultatif : vérifié seulement s'il est
-- dans StarterGui. Chaque liste = un Template caché (EntryName, Selected) dans son ScrollingFrame.
local adminElements = {
	{ Path = "Root.StatusLabel", Class = "TextLabel" },
	{ Path = "Root.Header.CloseButton", Class = BUTTON },
	{ Path = "TargetSection.TargetLabel", Class = "TextLabel" },
	{ Path = "GiveSection.SearchRow.SearchBox", Class = "TextBox" },
	{ Path = "GiveSection.MutationTitle" },
	{ Path = "GiveSection.GiveRow.GiveButton", Class = BUTTON },
	{ Path = "DangerSection.ResetRow.ResetProfileButton", Class = BUTTON },
} :: { Element }
for _, list in { "TargetSection.PlayerList", "GiveSection.ChoiceList", "GiveSection.MutationList", "EventsSection.EventList", "TeleportSection.ZoneList" } do
	table.insert(adminElements, { Path = `{list}.Template`, Class = BUTTON, Template = true })
	table.insert(adminElements, { Path = `{list}.Template.EntryName` })
	table.insert(adminElements, { Path = `{list}.Template.Selected` })
end
for _, row in { "Cash", "Speed", "Strength" } do
	table.insert(adminElements, { Path = `StatsSection.{row}Row.{row}Box`, Class = "TextBox" })
	table.insert(adminElements, { Path = `StatsSection.{row}Row.Give{row}Button`, Class = BUTTON })
end
for _, row in { "Treadmill", "Bench", "ShopLevel", "Rayons" } do
	table.insert(adminElements, { Path = `BaseSection.{row}Row.{row}Box`, Class = "TextBox" })
	table.insert(adminElements, { Path = `BaseSection.{row}Row.Set{row}Button`, Class = BUTTON })
end
for _, kind in { "Item", "Box", "Aura", "Trail", "Potion", "Gamepass" } do
	table.insert(adminElements, { Path = `GiveSection.KindRow.{kind}KindButton`, Class = BUTTON })
	table.insert(adminElements, { Path = `GiveSection.KindRow.{kind}KindButton.Selected` })
end
table.insert(UI.Screens, {
	Name = "UI_Admin",
	Class = "ScreenGui",
	Optional = true,
	Elements = adminElements,
})
-- Bouton du HUD qui ouvre UI_Admin (caché par Clément, montré par AdminController aux seuls admins). Entrée à part,
-- facultative, pour ne pas changer la liste d'UI_HUD : vérifiée quand UI_HUD est là.
table.insert(UI.Screens, {
	Name = "UI_HUD",
	Class = "ScreenGui",
	Optional = true,
	Elements = {
		{ Path = "AdminButton", Class = BUTTON },
		{ Path = "AdminButton.AdminLabel" },
	} :: { Element },
})
-- Bandeau d'entrée de zone (vague 30, L-110 ; relevé de Studio du 2026-11-12, agents/wave30-studio.md) : écran
-- UI_ZoneBanner, éteint au repos, allumé quelques secondes par ZoneBannerController quand le joueur passe une arche.
-- ZoneName = ville de la zone ; Advice.Speed et Advice.Damage = textes et couleurs des panneaux des magasins ;
-- Difficulty = « Easy », « Medium » ou « Hard ». Advice.RecommendedLabel est un texte fixe de Clément (pas lu).
table.insert(UI.Screens, {
	Name = "UI_ZoneBanner",
	Class = "ScreenGui",
	Elements = {
		{ Path = "Banner.ZoneName", Class = "TextLabel" },
		{ Path = "Advice.Speed", Class = "TextLabel" },
		{ Path = "Advice.Damage", Class = "TextLabel" },
		{ Path = "Difficulty", Class = "TextLabel" },
	} :: { Element },
})
-- Bulle des témoins (vague 30, liaison L-111 ; relevé de Studio du 2026-11-12, agents/wave30-studio.md) :
-- BB_Witness, copiée sur chaque témoin par WitnessController. Mark = le « ? » (Fill : cadre qui coupe, dont le
-- code règle la hauteur ; FillMark : le « ? » coloré) ; Alert = le « ! » de l'appel, caché par Clément, avec
-- PhoneIcon qui sonne. Back et Bang ne sont pas lus par le code.
table.insert(UI.Billboards, {
	Name = "BB_Witness",
	Class = "BillboardGui",
	Elements = {
		{ Path = "Mark" },
		{ Path = "Mark.Fill" },
		{ Path = "Mark.Fill.FillMark", Class = "TextLabel" },
		{ Path = "Alert" },
		{ Path = "Alert.PhoneIcon" },
	} :: { Element },
})
-- Compteur de chance au-dessus d'un colis qui s'ouvre sur son rayon (vague 31, L-112 ; relevé de Studio du
-- 2026-11-12, agents/wave31-studio.md) : BB_ShelfOpen, copiée par ShelfOpenController. Row.Luck = « ×1.25 LUCK »
-- écrit par le code ; Row.LuckIcon = le trèfle, penché à chaque tic.
table.insert(UI.Billboards, {
	Name = "BB_ShelfOpen",
	Class = "BillboardGui",
	Elements = {
		{ Path = "Row" },
		{ Path = "Row.Luck", Class = "TextLabel" },
		{ Path = "Row.LuckIcon" },
	} :: { Element },
})
-- Ligne Mutation de BB_Item (vague 34, L-127 point 5, a119) : « BIG GOLD », cachée sans mutation ; texte blanc sous
-- le dégradé TextGradient du style (Assets/UI/MutationStyles/<Id>, contrat 10.4 : Contract/Models.MutationStyles),
-- posé par MutationFxController. Entrée à part, facultative, pour ne pas changer la liste de BB_Item.
table.insert(UI.Billboards, {
	Name = "BB_Item",
	Class = "BillboardGui",
	Optional = true,
	Elements = {
		{ Path = "Mutation", Class = "TextLabel" },
	} :: { Element },
})
-- Claim All et pastilles « ! » (vague 34, L-127 points 2 et 3 ; script de Clément tools/clement/alerts_claimall_build.luau).
-- Pastilles cachées par Clément, montrées par le code quand le joueur a quelque chose à faire (UI/AlertBadge) ; leur
-- UIScale Pulse bat tant qu'elles sont visibles. Entrées à part, à la fin, pour ne pas changer les listes existantes.
-- UI_HUD : un exemplaire dans LeftRail et un dans LeftRailTouch (UI.Twins) ; RailAlertController et RewardsController.
local hudAlerts = {} :: { Element }
for _, pair in { { "IndexButton", "IndexAlert" }, { "InventoryButton", "InventoryAlert" }, { "RebirthButton", "RebirthAlert" }, { "SkillTreeButton", "SkillTreeAlert" }, { "RewardsButton", "RewardsAlert" } } do
	table.insert(hudAlerts, { Path = `{pair[1]}.{pair[2]}` })
	table.insert(hudAlerts, { Path = `{pair[1]}.{pair[2]}.Pulse`, Class = "UIScale" })
end
table.insert(UI.Screens, {
	Name = "UI_HUD",
	Class = "ScreenGui",
	Optional = true,
	Elements = hudAlerts,
})
-- UI_Index_v3 (IndexController) : UnlockedBar.ClaimAllButton (toutes les primes de zone à réclamer, en une demande),
-- ClaimAllAlert, ClaimButton.ClaimAlert (la zone visible), ZoneAlert de chaque section, CategoryAlert de NORMAL.
local indexAlerts = {
	{ Path = "UnlockedBar.ClaimAllButton", Class = BUTTON },
	{ Path = "UnlockedBar.ClaimAllButton.ClaimAllAlert" },
	{ Path = "UnlockedBar.ClaimAllButton.ClaimAllAlert.Pulse", Class = "UIScale" },
	{ Path = "Rewards.ClaimButton.ClaimAlert" },
	{ Path = "Rewards.ClaimButton.ClaimAlert.Pulse", Class = "UIScale" },
	{ Path = "Categories.NormalButton.CategoryAlert" },
	{ Path = "Categories.NormalButton.CategoryAlert.Pulse", Class = "UIScale" },
} :: { Element }
for _, section in { "Zone1Section", "Zone2Section", "Zone3Section", "Zone4Section", "Zone5Section", "Zone6Section", "SecretsSection" } do
	table.insert(indexAlerts, { Path = `{section}.ZoneArt.ZoneAlert` })
	table.insert(indexAlerts, { Path = `{section}.ZoneArt.ZoneAlert.Pulse`, Class = "UIScale" })
end
table.insert(UI.Screens, {
	Name = "UI_Index_v3",
	Class = "ScreenGui",
	Optional = true,
	Elements = indexAlerts,
})
-- UI_Rewards (RewardsController) : TabAlert de chaque onglet (le jour à réclamer ; un palier atteint à réclamer).
table.insert(UI.Screens, {
	Name = "UI_Rewards",
	Class = "ScreenGui",
	Optional = true,
	Elements = {
		{ Path = "Tabs.DailyTab.TabAlert" },
		{ Path = "Tabs.DailyTab.TabAlert.Pulse", Class = "UIScale" },
		{ Path = "Tabs.PlaytimeTab.TabAlert" },
		{ Path = "Tabs.PlaytimeTab.TabAlert.Pulse", Class = "UIScale" },
	} :: { Element },
})
-- Barre de PV de la vitrine de la Fortune Tower (L-108 point 8, vague 37, a123 ; nom proposé à Clément) :
-- mêmes éléments que BB_TruckHP. Facultative : sans elle, FortuneTowerController prend BB_TruckHP telle quelle.
table.insert(UI.Billboards, {
	Name = "BB_FortuneHP",
	Class = "BillboardGui",
	Optional = true,
	Elements = { { Path = "Fill" }, { Path = "Label" } } :: { Element },
})
-- Ligne Mutation de BB_Carry (L-131 g, vague 38, a125 ; nom proposé à Clément, comme celle de BB_Item) :
-- facultative. Présente : CarryService y écrit la mutation (« BIG · GOLD ») et MutationFxController lui
-- donne le style de Assets/UI/MutationStyles/<Id>, comme à BB_Item et MutationTag. Absente : la mutation
-- reste écrite devant ItemName, sans style.
for _, billboard in UI.Billboards do
	if billboard.Name == "BB_Carry" then
		table.insert(billboard.Elements, {
			Path = "Mutation",
			Class = "TextLabel",
			Optional = true,
			Note = "la mutation reste écrite devant ItemName, sans style de mutation",
		})
	end
end

return UI
