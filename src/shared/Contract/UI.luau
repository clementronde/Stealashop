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
			-- Bouton sac à dos de la colonne gauche (L-079) : sorti du contrat à la vague 59 (L-182 point 5, L-183 :
			-- inventaire archivé) ; encore là, une note (UI.Retired), et il ouvre toujours UI_Inventory (code en sommeil).
			-- Bouton engrenage de SocialRow (L-095 point 2, relevé de Studio du 2026-11-11) : visible dans Studio depuis le 2026-11-14 (L-159), caché par HudController sans
			-- Features.Settings, montré par SettingsController ; ouvre UI_Settings.
			{ Path = "SettingsButton", Class = BUTTON },
			-- Bouton « Upgrades » de la colonne gauche (vague 27, L-096 point 2) : visible dans Studio depuis le 2026-11-14 (L-159), montré
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
	-- Vague 52 (a170) : UI_Unbox (ouverture des colis en base) retiré du contrat ; Clément peut retirer l'écran.
	{
		Name = "UI_TheftAlert",
		Class = "ScreenGui",
		Elements = {
			{ Path = "Banner" },
			-- L-175 (Clément, 2026-11-15) : l'alerte n'est plus qu'un bandeau de texte ; ces trois éléments sont facultatifs.
			{ Path = "ThiefName", Optional = true, Note = "le pseudo du voleur n'est pas affiché (L-175)" },
			{ Path = "ItemName", Optional = true, Note = "le nom de l'objet n'est pas affiché (L-175)" },
			{ Path = "Arrow", Class = "ImageLabel", Optional = true, Note = "pas de flèche vers le voleur (L-175)" },
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
	-- Boutique Robux : l'ancien écran UI_RobuxShop est retiré (a438, 24/11 ; UI.Retired) ; UI_RobuxShop_v2, plus bas.
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
	-- Vague 52 (a170) : BB_OpenTimer (minuteur du colis posé) retiré du contrat ; Clément peut le retirer.
	{
		Name = "BB_Item",
		Class = "BillboardGui",
		Elements = {
			{ Path = "ItemName" },
			{ Path = "Rarity" },
			{ Path = "Income" },
			-- Ligne Mutation (vague 34, L-127 point 5, a119) : « BIG GOLD », cachée sans mutation ; texte blanc sous le
			-- dégradé TextGradient du style (Assets/UI/MutationStyles/<Id>, contrat 10.4 : Contract/Models.MutationStyles),
			-- posé par MutationFxController. a312 : venue de la 2e entrée BB_Item (fusionnée ici, rien de plus ni moins strict).
			{ Path = "Mutation", Class = "TextLabel" },
		},
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
	-- a303 (21/11, demande de Cantin) : le gain du palier (« $1.2K cash », « Box from your best zone », « ×2 Cash for 10 min »),
	-- écrit par le code (Config/Rewards.Texts) ; sans lui, le gain va dans RewardName (« 5 min: 2 min of cash »).
	{ Path = "PlaytimePage.List.Template.RewardDesc", Optional = true, Note = "le gain du palier est écrit dans RewardName (a303)" },
	-- a303 : icône du type de récompense, image prise dans le Decal UI_Icon_Reward_Cash, _Box ou _Boost de
	-- ReplicatedStorage/Assets ; cachée tant que ce Decal n'est pas livré.
	{ Path = "PlaytimePage.List.Template.RewardIcon", Class = "ImageLabel", Optional = true, Note = "pas d'icône par type de récompense (a303)" },
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
-- InventoryController. Trois onglets depuis la vague 52 (Tabs.<Nom>Tab, image Selected sur l'onglet choisi), une section
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
-- Vague 52 (a170) : Tabs.BoxesTab et BoxesSection retirés du contrat (plus de colis dans l'inventaire) ; s'ils
-- sont encore là, InventoryController les cache. Clément peut les retirer.
for _, tab in { "Items", "Tools", "Potions" } do
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
for _, section in { "ItemsSection", "ToolsSection" } do
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
	-- Vague 59 (L-182 point 5) : inventaire archivé, Clément range l'écran hors de StarterGui ; absent, rien à dire.
	Optional = true,
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

-- Vague 74 (a258, L-259 b ; UiMotionController, Config/UiMotion.Veil) : voile noir derrière les fenêtres centrales.
-- Écran éteint en Studio ; le code l'allume sous la fenêtre (DisplayOrder − 1), fond Veil de 1 à sa transparence de
-- Studio (0,62), puis l'éteint et remet les valeurs de Clément. Un clic sur Veil ferme la fenêtre. Absent : flou seul.
table.insert(UI.Screens, {
	Name = "UI_Veil",
	Class = "ScreenGui",
	Optional = true,
	Elements = {
		{ Path = "Veil", Class = "GuiObject" },
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
	{ Path = "Rewards.SpeedReward", Optional = true, Note = "caché depuis L-192 (plus de vitesse), peut sortir de l'écran" },
	{ Path = "Rewards.CashReward", Optional = true, Note = "caché depuis L-192 (plus d'argent), peut sortir de l'écran" },
	{ Path = "Rewards.ClaimButton", Class = BUTTON },
	{ Path = "Rewards.ClaimButton.ClaimLabel" },
} :: { Element }
-- Vague 63 (a207, L-201) : retirés de l'écran refait, donc du contrat (IndexController les lit encore s'ils sont là,
-- sans eux rien ne manque) : MutationTabs et MutationCaption, Categories.SecretsButton, ZoneBar.ZoneItem.
for _, section in indexSections do
	for _, path in { "", ".ZoneName", ".ZoneBar", ".ZoneBar.Fill", ".ZoneBar.ZoneCount", ".Cards" } do
		table.insert(indexV3Elements, { Path = section .. path })
	end
end
for _, button in { "NormalButton", "MutationsButton" } do
	table.insert(indexV3Elements, { Path = `Categories.{button}`, Class = BUTTON })
	table.insert(indexV3Elements, { Path = `Categories.{button}.Selected` })
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
for _, tile in { "Tile_ShopLevel", "Tile_Glass", "Tile_GlassRegen", "Tile_Cameras", "Tile_Guards", "Tile_PotionLuck", "Tile_Curtain", "Tile_DoorGuard", "Tile_PotionTime", "Tile_Next1" } do
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
		-- Vague 70 (a230, L-189 point 8) : InventoryButton retiré (inventaire archivé, UI.Retired).
		Names = { "RobuxShopButton", "IndexButton", "RebirthButton", "SkillTreeButton" },
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
for _, row in { "Cash", "Speed" } do -- StrengthRow n'est plus au contrat (plus de Force, v2)
	table.insert(adminElements, { Path = `StatsSection.{row}Row.{row}Box`, Class = "TextBox" })
	table.insert(adminElements, { Path = `StatsSection.{row}Row.Give{row}Button`, Class = BUTTON })
end
for _, row in { "Treadmill", "ShopLevel", "Rayons" } do -- BenchRow n'est plus au contrat (plus de banc, v2)
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
-- Ligne Mutation de BB_Item (vague 34, a119) : a312, dans la liste de BB_Item en tête de fichier (avant : une 2e entrée
-- BB_Item, où les boucles du poids mettaient Weight une 2e fois, d'où des avertissements comptés deux fois).

-- Claim All et pastilles « ! » (vague 34, L-127 points 2 et 3 ; script de Clément tools/clement/alerts_claimall_build.luau).
-- Pastilles cachées par Clément, montrées par le code quand le joueur a quelque chose à faire (UI/AlertBadge) ; leur
-- UIScale Pulse bat tant qu'elles sont visibles. Entrées à part, à la fin, pour ne pas changer les listes existantes.
-- UI_HUD : un exemplaire dans LeftRail et un dans LeftRailTouch (UI.Twins) ; RailAlertController et RewardsController.
local hudAlerts = {} :: { Element }
-- Vague 59 : InventoryButton.InventoryAlert sorti avec l'inventaire (UI.Retired).
for _, pair in { { "IndexButton", "IndexAlert" }, { "RebirthButton", "RebirthAlert" }, { "SkillTreeButton", "SkillTreeAlert" }, { "RewardsButton", "RewardsAlert" } } do
	-- a312 : RewardsButton.RewardsAlert est déjà dans la liste principale d'UI_HUD (exigée pareil) : pas une 2e fois.
	if pair[1] ~= "RewardsButton" then
		table.insert(hudAlerts, { Path = `{pair[1]}.{pair[2]}` })
	end
	table.insert(hudAlerts, { Path = `{pair[1]}.{pair[2]}.Pulse`, Class = "UIScale" })
end
table.insert(UI.Screens, {
	Name = "UI_HUD",
	Class = "ScreenGui",
	Optional = true,
	Elements = hudAlerts,
})
-- UI_Index_v3 (IndexController) : ClaimButton.ClaimAlert (la zone visible), ZoneAlert de chaque section, CategoryAlert
-- de NORMAL. Vague 72 (a242, L-213) : UnlockedBar.ClaimAllButton et son ClaimAllAlert sortis du contrat (retirés de
-- l'écran par Clément, UI.Retired) ; IndexController le branche encore s'il revient.
local indexAlerts = {
	{ Path = "Rewards.ClaimButton.ClaimAlert" },
	{ Path = "Rewards.ClaimButton.ClaimAlert.Pulse", Class = "UIScale" },
	{ Path = "Categories.NormalButton.CategoryAlert" },
	{ Path = "Categories.NormalButton.CategoryAlert.Pulse", Class = "UIScale" },
} :: { Element }
for _, section in { "Zone1Section", "Zone2Section", "Zone3Section", "Zone4Section", "Zone5Section", "Zone6Section", "SecretsSection" } do
	table.insert(indexAlerts, { Path = `{section}.ZoneArt.ZoneAlert` })
	table.insert(indexAlerts, { Path = `{section}.ZoneArt.ZoneAlert.Pulse`, Class = "UIScale" })
end
-- a312 : ajoutées à la seule définition d'UI_Index_v3 (indexV3Elements, plus haut) ; avant, une 2e entrée UI_Index_v3
-- (écran facultatif) où la boucle des nouveautés a207 remettait ses 16 éléments, comptés deux fois par le ContractChecker.
for _, element in indexAlerts do
	table.insert(indexV3Elements, element)
end
-- UI_Rewards (RewardsController) : TabAlert de chaque onglet (le jour à réclamer ; un palier atteint à réclamer).
-- a312 : dans la seule définition d'UI_Rewards (rewardsElements, plus haut) ; avant, une 2e entrée où la boucle du
-- coffre hebdomadaire remettait WeeklyChest et ses 8 éléments.
for _, element in {
	{ Path = "Tabs.DailyTab.TabAlert" },
	{ Path = "Tabs.DailyTab.TabAlert.Pulse", Class = "UIScale" },
	{ Path = "Tabs.PlaytimeTab.TabAlert" },
	{ Path = "Tabs.PlaytimeTab.TabAlert.Pulse", Class = "UIScale" },
} :: { Element } do
	table.insert(rewardsElements, element)
end
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
-- Panneau d'amélioration UpgradeSign (Model de Clément dans Assets/UI, L-082 ; UpgradeController) : vague 42
-- (L-157 point 2, accord de Clément), TextLabel facultatif Gain sous Level, « +16/s > +32/s » sur le panneau du
-- tapis. Seul Gain est vérifié ici (le reste du panneau est contrôlé par UpgradeController au démarrage).
table.insert(UI.Billboards, {
	Name = "UpgradeSign",
	Class = "Model",
	Optional = true,
	Elements = {
		{
			Path = "Gain",
			Class = "TextLabel",
			Optional = true,
			Note = "le gain du tapis (« +16/s > +32/s ») n'est pas affiché",
		},
	} :: { Element },
})
-- Multiplicateur du trail sur BB_Gain (vague 47, a155 ; nom proposé à Clément) : facultatif. Présent : le
-- code y écrit « ×2 » (trail équipé > 1) et le montre, sinon le cache. Absent : « ×2 » ajouté à Row.Amount
-- en texte enrichi (UiMotion.FloatGain.TrailMultiplierColor).
table.insert(UI.Billboards, {
	Name = "BB_Gain",
	Class = "BillboardGui",
	Optional = true,
	Elements = {
		{ Path = "Row.Multiplier", Class = "TextLabel", Optional = true, Note = "le « ×2 » du trail est ajouté à Row.Amount en texte enrichi" },
	} :: { Element },
})
-- Billboard du grand socle de l'objet le plus rare (vague 50, a161, L-165 point 5 ; noms proposés par Clément,
-- pas encore livré) : facultatif. VfxController en pose une copie sur RarestDisplay/LabelPoint de chaque boutique ;
-- absent : BB_Rarest à la place. Vague 60 (a196, T-096) : le code écrit « BEST ITEM » dans Header (Config/Vfx.Rarest.Title)
-- et le revenu/s de l'objet dans Income (nom proposé à Clément ; absent : dans Odds).
table.insert(UI.Billboards, {
	Name = "BB_RarestDisplay",
	Class = "BillboardGui",
	Optional = true,
	Elements = {
		{ Path = "Header", Class = "TextLabel", Optional = true, Note = "« BEST ITEM » n'est pas affiché" },
		{ Path = "Rarity", Class = "TextLabel", Optional = true, Note = "la rareté n'est pas affichée" },
		{ Path = "ItemName", Class = "TextLabel", Optional = true, Note = "le nom de l'objet n'est pas affiché" },
		{ Path = "Mutation", Class = "TextLabel", Optional = true, Note = "la mutation n'est pas affichée" },
		{ Path = "Odds", Class = "TextLabel", Optional = true, Note = "la chance (« 1 in 5,300,000,000 ») n'est pas affichée" },
		{ Path = "Income", Class = "TextLabel", Optional = true, Note = "le revenu/s de l'objet s'écrit dans Odds, à la place de la chance" },
	} :: { Element },
})

-- Code cadeau et compte à rebours de MAJ (MAJ 0, a162 ; noms proposés à Clément) : CodeController. Tous
-- facultatifs ; le code les cherche aussi dans UI_Rewards. a312 : dans la seule définition d'UI_Settings
-- (settingsElements, plus haut), au lieu d'une 2e entrée UI_Settings.
for _, element in {
	{ Path = "CodeBox", Class = "TextBox", Optional = true, Note = "pas de champ de code cadeau" },
	{ Path = "RedeemButton", Class = BUTTON, Optional = true, Note = "le code s'envoie avec Entrée seulement" },
	{ Path = "CodeStatus", Class = "TextLabel", Optional = true, Note = "la réponse arrive en Notify seulement" },
	{ Path = "UpdateCountdown", Class = "TextLabel", Optional = true, Note = "pas de compte à rebours de MAJ" },
} :: { Element } do
	table.insert(settingsElements, element)
end

-- Étiquette des stands et des zones du hub (L-165 point 6, vague 50, a160 ; nom proposé par Clément, V0) : posée
-- par Clément au-dessus de chaque stand et de chaque zone (dans la map, pas seulement ici), avec l'attribut texte
-- LabelKey ; HubController écrit dans Label le texte anglais de Config/Hub.Labels. Facultative.
table.insert(UI.Billboards, {
	Name = "BB_ZoneLabel",
	Class = "BillboardGui",
	Optional = true,
	Elements = {
		{ Path = "Label", Class = "TextLabel", Optional = true, Note = "le texte de LabelKey n'est pas écrit" },
	} :: { Element },
})

-- Chrono de police (vague 51, a165 ; L-157, posé par Clément) : UIGradient éteint de HeistTimer.Box, allumé par
-- HudController pendant « POLICE IN » à la place de Box.UIGradient. Facultatif : sans lui, seul le texte change de
-- couleur (attribut HeistTimer@PoliceTextColor, sinon UiMotion.TimerTick.PoliceColor).
-- Rangé juste après HeistTimer (la fin de la liste du HUD reste SkillTreeButton). a312 : seulement dans l'entrée
-- UI_HUD qui a HeistTimer (avant : aussi au bout des entrées à part d'UI_Admin et des pastilles, compté 3 fois).
for _, screen in UI.Screens do
	local after: number? = nil
	if screen.Name == "UI_HUD" then
		for rank, element in screen.Elements do
			if element.Path == "HeistTimer" then
				after = rank
			end
		end
	end
	if after ~= nil then
		table.insert(screen.Elements, after + 1, {
			Path = "HeistTimer.Box.PoliceGradient",
			Class = "UIGradient",
			Optional = true,
			Note = "le fond du chrono de police reste orange",
		})
	end
end

-- Coffre hebdomadaire de UI_Rewards (agent a166, MAJ 1 ; noms proposés à Clément, tous facultatifs) :
-- RewardsController cache WeeklyChest tant que Features.WeeklyChest est coupé. Vague 80 (a267) : allumé en DEV ; sans
-- WeeklyChest.WeeklyClaimButton, les jours se comptent mais rien ne se montre ni ne se réclame (aucune pastille).
for _, screenDef in UI.Screens do
	if screenDef.Name == "UI_Rewards" then
		table.insert(screenDef.Elements, { Path = "WeeklyChest", Optional = true, Note = "pas de coffre hebdomadaire dans UI_Rewards (MAJ 1)" })
		table.insert(screenDef.Elements, { Path = "WeeklyChest.Progress", Class = "TextLabel", Optional = true, Note = "le compte « 3/5 » des jours n'est pas écrit" })
		for day = 1, 5 do
			table.insert(screenDef.Elements, { Path = `WeeklyChest.WeekDays.Day{day}.Done`, Optional = true, Note = "la jauge des 5 jours ne s'allume pas" })
		end
		table.insert(screenDef.Elements, { Path = "WeeklyChest.WeeklyClaimButton", Class = BUTTON, Optional = true, Note = "le coffre hebdomadaire ne se réclame pas" })
		table.insert(screenDef.Elements, { Path = "WeeklyChest.WeeklyClaimButton.ClaimLabel", Optional = true, Note = "le texte CLAIM / LOCKED / CLAIMED va dans le bouton" })
	end
end

-- Vague 52 (a170) : éléments sortis du contrat, que le code ne lit plus. Encore là chez Clément, le ContractChecker
-- les signale en note, jamais en problème : il peut les retirer quand il veut. Screens : chemin depuis StarterGui ;
-- Billboards : depuis le dossier BillboardFolder (Contract/Find, segments cherchés parmi les descendants).
local BOX_GONE = "colis porté et ouvert en base retirés (2026-11-15)"
UI.Retired = {
	Screens = {
		-- Vague 73 (a251, L-246) : UI_Unbox revient au contrat (le fondu des bords de la nouvelle ouverture, plus bas).
		["UI_Inventory.Tabs.BoxesTab"] = BOX_GONE,
		["UI_Inventory.BoxesSection"] = BOX_GONE,
		-- Vague 59 (a190, L-182 point 5, L-183) : inventaire archivé (InventoryController en sommeil).
		["UI_HUD.InventoryButton"] = "inventaire archivé (L-182 point 5), bouton retiré du nouveau HUD (L-183)",
		-- Vague 63 (a205, L-202 point 1, L-192 Q1) : plus de menu « More ».
		["UI_HUD.MenuButton"] = "menu « More » retiré (L-202), les boutons sont dans LeftRail et TopLeftRow",
		["UI_HUD.MenuPanel"] = "menu « More » retiré (L-202), les boutons sont dans LeftRail et TopLeftRow",
		["UI_HUD.MenuArea"] = "menu « More » retiré (L-202), les boutons sont dans LeftRail et TopLeftRow",
		-- Vague 72 (a242, L-213) : « Claim All » de l'index retiré de l'écran par Clément.
		["UI_Index_v3.UnlockedBar.ClaimAllButton"] = "« Claim All » de l'index retiré par Clément (L-213)",
		-- a438 (24/11, lot 5 du check-up a417) : l'ancienne boutique Robux, remplacée par UI_RobuxShop_v2 (vague 63).
		["UI_RobuxShop"] = "ancienne boutique Robux, remplacée par UI_RobuxShop_v2 (a438)",
	},
	Billboards = {
		BB_OpenTimer = BOX_GONE,
		-- Vague 74 (a257, L-253 point 3, L-254 point 2) : plus de mot au-dessus des coups de l'ouverture du colis.
		BB_UnboxWord = "plus de mot au-dessus des coups de l'ouverture du colis (L-253, L-254)",
	},
} :: { Screens: { [string]: string }, Billboards: { [string]: string } }

-- Bannière d'événement live (vague 51, a167, MAJ 0 ; noms proposés à Clément) : facultative. En bas ou au milieu
-- de l'écran, jamais en haut. EventBannerController l'allume (Enabled) pendant un événement de Config/LiveEvents :
-- Title (« ADMIN ABUSE »), Timer (« 29:59 »), Effect (effet en une ligne). Absente : aucun affichage, les effets
-- jouent quand même.
table.insert(UI.Screens, {
	Name = "UI_EventBanner",
	Class = "ScreenGui",
	Optional = true,
	Elements = {
		{ Path = "Title", Class = "TextLabel" },
		{ Path = "Timer", Class = "TextLabel" },
		{ Path = "Effect", Class = "TextLabel" },
	} :: { Element },
})

-- Vague 56 (a181, L-166 Q4) : icône de Damage dans UI_HUD, montrée avec Damage pendant la potion de force (HudController).
-- Rangée juste après Damage (SkillTreeButton reste le dernier élément du HUD). a312 : seulement dans l'entrée UI_HUD
-- qui a Damage (avant : aussi au bout des entrées à part, compté 3 fois).
for _, screenDef in UI.Screens do
	local after: number? = nil
	if screenDef.Name == "UI_HUD" then
		for rank, element in screenDef.Elements do
			if element.Path == "Damage" then
				after = rank
			end
		end
	end
	if after ~= nil then
		table.insert(screenDef.Elements, after + 1, { Path = "DamageIcon", Optional = true, Note = "Damage se montre sans son icône pendant la potion" })
	end
end

-- Cartes des boutiques par palier (vague 58, a186, L-176 ; Shared/ShopCardTier) : tout facultatif. Le fond de chaque
-- palier est dans Assets/UI/ShopCardBg (Contract/Models.ShopCardBg) ; TrailIconRotation est un attribut du Template
-- d'UI_AuraShop (trails couchés), pas un élément.
for _, screenDef in UI.Screens do
	if screenDef.Name == "UI_WeaponShop" or screenDef.Name == "UI_AuraShop" then
		table.insert(screenDef.Elements, { Path = "List.Template.Card", Optional = true, Note = "la carte garde le fond, la bordure et les studs du Template (L-176)" })
		table.insert(screenDef.Elements, { Path = "List.Template.RarityLabel", Class = "TextLabel", Optional = true, Note = "le nom du palier n'est pas écrit (L-176)" })
		table.insert(screenDef.Elements, { Path = "List.Template.IconArea", Optional = true, Note = "ni taille du visuel, ni ombre, ni rayons, lueur et étoiles (L-176)" })
		table.insert(screenDef.Elements, { Path = "List.Template.IconShadow", Class = "ImageLabel", Optional = true, Note = "le visuel n'a pas d'ombre (L-176)" })
	end
end

-- Panneau du voleur devant la boutique d'un autre joueur (L-169 Q6, livré par Clément le 2026-11-15) :
-- copié par PvPController. OwnerName (« Alice's Shop »), Income, HP (« 7/40 », dans HPLine avec HPIcon),
-- Status (pastille « LOCKED 23s », « OPEN », « ROB AGAIN IN 42s », cachée quand il n'y a rien à dire).
-- Panel, HPLine et HPIcon sont du décor. Facultatif : sans lui, un panneau V0 gris.
table.insert(UI.Billboards, {
	Name = "BB_ShopInfo",
	Class = "BillboardGui",
	Optional = true,
	Elements = {
		{ Path = "OwnerName", Class = "TextLabel" },
		{ Path = "Income", Class = "TextLabel" },
		{ Path = "HP", Class = "TextLabel" },
		{ Path = "Status", Class = "GuiObject" },
		-- Vague 72 (a245, L-216 point 3) : PvPController.
		{ Path = "OwnerAvatar", Class = "ImageLabel", Optional = true, Note = "pas de miniature du propriétaire" },
		{ Path = "BestItem", Class = "TextLabel", Optional = true, Note = "pas de nom du meilleur objet exposé" },
		-- a316 (L-296, Clément, 2026-11-23) : enfants de BestItem, cachés avec lui. BestIcon reçoit l'image ICON_ du
		-- meilleur objet (PvPController) ; BestLabel (« BEST ITEM ») est du décor, jamais écrit par le code.
		{ Path = "BestItem.BestIcon", Class = "ImageLabel", Optional = true, Note = "pas d'icône du meilleur objet exposé" },
		{ Path = "BestItem.BestLabel", Class = "TextLabel", Optional = true, Note = "pas de légende « BEST ITEM »" },
	} :: { Element },
})

-- Récompenses de renaissance (L-173 et L-168 Q2, vague 56, a183), tout est facultatif.
-- Tuiles à renaissance de l'arbre (les 4 tuiles de Config/SkillTree qui ont RequiresRebirth ; noms proposés par
-- Clément le 2026-11-15, adoptés) : calque RebirthLocked à côté de Bought, Available et Locked, avec LockedName
-- (« REBIRTH 1 ») et LockedLabel (« TO UNLOCK ») écrits par SkillTreeController.
for _, screenDef in UI.Screens do
	if screenDef.Name == "UI_SkillTree" then
		for _, tile in { "Tile_Curtain", "Tile_PotionTime", "Tile_DoorGuard", "Tile_Next1" } do
			table.insert(screenDef.Elements, { Path = `Tree.{tile}.RebirthLocked`, Optional = true, Note = "tuile à renaissance : le calque Locked est montré à la place" })
			table.insert(screenDef.Elements, { Path = `Tree.{tile}.RebirthLocked.LockedName`, Class = "TextLabel", Optional = true, Note = "« REBIRTH n » n'est pas écrit" })
			table.insert(screenDef.Elements, { Path = `Tree.{tile}.RebirthLocked.LockedLabel`, Class = "TextLabel", Optional = true, Note = "« TO UNLOCK » n'est pas écrit" })
		end
	end
end
-- Titre au-dessus du joueur (noms proposés à Clément, Config/Rebirths.Title) : RebirthTitleController en pose une
-- copie sur la tête de chaque joueur qui a fait une renaissance et écrit « REBIRTH n » dans TitleLabel.
table.insert(UI.Billboards, {
	Name = "BB_RebirthTitle",
	Class = "BillboardGui",
	Optional = true,
	Elements = {
		{ Path = "TitleLabel", Class = "TextLabel", Optional = true, Note = "« REBIRTH n » n'est pas écrit au-dessus du joueur" },
	} :: { Element },
})

-- Nouveau HUD (vague 59, a190 ; L-183 `UI_HUD`, noms de la page Figma « 30 HUD, tapis, poursuite », validés par
-- Clément ; docs/claude/notes/2026-11-15_figma-refonte-coordination.md). Pas encore construit dans Studio : tout est
-- facultatif, l'ancien HUD marche sans. Vague 63 (a205, L-202 point 1, L-192 Q1) : plus de menu « More » (MenuButton,
-- MenuAlert, MenuArea et MenuPanel sortis, UI.Retired) ; les petites icônes RewardsButton, InviteButton, SettingsButton
-- et RebirthButton sont dans TopLeftRow (attribut FollowTopbarInset : calé sur la barre de Roblox), mêmes noms, les
-- contrôleurs les cherchent partout dans l'écran.
-- RightRail porte DisplayedButton (ouvre UI_Displayed) et les boutons en situation de Config/Boosts, cachés par
-- Clément. Vague 72 (a242, L-219 point 4) : le bouton inventaire (dernier bouton du HUD) garde le nom DisplayedButton,
-- où qu'il soit dans UI_HUD (HudMenuController le cherche partout) ; InventoryButton reste l'inventaire archivé. CashSpent : « -$X » rouge après un achat. HudController et HudMenuController.
table.insert(UI.Screens, {
	Name = "UI_HUD",
	Class = "ScreenGui",
	Optional = true,
	Elements = {
		{ Path = "DisplayedButton", Class = BUTTON, Optional = true, Note = "UI_Displayed ne s'ouvre que par son propre bouton" },
		-- a319 (L-303) : SpeedBoostButton vend le gamepass ×2 Speed (DoubleSpeed) ; OnlyLabel, RobuxIcon et son Fill sont
		-- décoratifs, Hint n'est plus lu (retiré par Clément).
		{ Path = "SpeedBoostButton", Class = BUTTON, Optional = true, Note = "pas de bouton « x2 » sur le tapis" },
		{ Path = "SpeedBoostButton.Price.Amount", Class = "TextLabel", Optional = true, Note = "le prix Robux n'est pas écrit" },
		{ Path = "SleepButton", Class = BUTTON, Optional = true, Note = "pas de bouton « zZz » dans le couloir" },
		{ Path = "SleepButton.Price.Amount", Class = "TextLabel", Optional = true, Note = "le prix Robux n'est pas écrit" },
		{ Path = "SleepButton.Cooldown", Class = "TextLabel", Optional = true, Note = "la recharge n'est pas affichée" },
		{ Path = "CashSpent", Class = "TextLabel", Optional = true, Note = "l'argent décompte sans « -$X » à côté" },
		-- Vague 63 (a205, L-202 point 1) : cadre des petites icônes, dans la barre de Roblox.
		{ Path = "TopLeftRow", Optional = true, Note = "les petites icônes restent où Clément les a mises" },
	} :: { Element },
})

-- Capture, alerte et gains qui volent (vague 59, a192, L-184 et L-182 point 9 ; noms proposés à Clément), tout est
-- facultatif. UI_Caught : écran de la capture (CatchSceneController) : Title (« CAUGHT! », tamponné), ItemIcon (l'objet
-- qui repart vers son présentoir ou tombe), BarTop et BarBottom (bandes noires du renvoi à la base, la nuit : leur
-- taille de Clément = fermées, le code part de 0). Sans lui : un écran V0 du code, mêmes noms.
table.insert(UI.Screens, {
	Name = "UI_Caught",
	Class = "ScreenGui",
	Optional = true,
	Elements = {
		{ Path = "Title", Class = "GuiObject", Optional = true, Note = "pas de « CAUGHT! » tamponné" },
		{ Path = "ItemIcon", Class = "ImageLabel", Optional = true, Note = "l'objet ne repart pas à l'écran" },
		{ Path = "BarTop", Class = "GuiObject", Optional = true, Note = "pas de bande noire en haut au renvoi de nuit" },
		{ Path = "BarBottom", Class = "GuiObject", Optional = true, Note = "pas de bande noire en bas au renvoi de nuit" },
	} :: { Element },
})
for _, screenDef in UI.Screens do
	-- UI_Chase.HeistHint (palier 1 de l'alerte, ChaseController) n'est pas mis au contrat : UI_Chase n'a aucun nom imposé
	-- (L-071 point 6) ; sans lui, UI_Chase n'arrive qu'avec la poursuite, comme avant.
	if screenDef.Name == "UI_Escape" then
		-- « ITEM SECURED! » en carte (CatchSceneController).
		table.insert(screenDef.Elements, { Path = "Card", Optional = true, Note = "pas de carte d'objet" })
		table.insert(screenDef.Elements, { Path = "Card.ItemIcon", Class = "ImageLabel", Optional = true, Note = "pas d'objet en grand" })
		table.insert(screenDef.Elements, { Path = "Card.ItemName", Class = "TextLabel", Optional = true, Note = "pas de nom" })
		table.insert(screenDef.Elements, { Path = "Card.Rarity", Class = "TextLabel", Optional = true, Note = "pas de rareté" })
		table.insert(screenDef.Elements, { Path = "Card.Income", Class = "TextLabel", Optional = true, Note = "pas de revenu/s" })
		table.insert(screenDef.Elements, { Path = "Card.NewBadge", Class = "GuiObject", Optional = true, Note = "pas de « NEW! »" })
	elseif screenDef.Name == "UI_HUD" and screenDef.Elements[1] and screenDef.Elements[1].Path == "Cash" then
		-- Gains ponctuels qui volent (GainController) : le « +$X » du départ et le billet. Rangés juste après Cash (la
		-- fin de la liste du HUD reste SkillTreeButton).
		table.insert(screenDef.Elements, 2, { Path = "CashFly.Bill", Class = "GuiObject", Optional = true, Note = "CashFly.Template sert de billet" })
		table.insert(screenDef.Elements, 2, { Path = "CashFly.GainPop", Class = "TextLabel", Optional = true, Note = "CashFly.CounterPop sert au « +$X » du départ" })
	end
end

-- Écrans refaits de L-183 (vague 59, a191 ; noms de la page Figma « 20 Index et Exposés », pas encore dans
-- Studio) : facultatifs. UI_Index_v4 (IndexController) passe avant UI_Index_v3 quand il est là.
table.insert(UI.Screens, {
	Name = "UI_Index_v4",
	Class = "ScreenGui",
	Optional = true,
	Elements = {
		{ Path = "CloseButton", Class = BUTTON },
		{ Path = "UnlockedBar.Counter", Class = "TextLabel" },
		{ Path = "ZoneArt" },
		{ Path = "ZoneArt.ZoneName", Class = "TextLabel" },
		{ Path = "ZoneArt.ZoneTheme", Class = "TextLabel", Optional = true, Note = "les magasins de la zone ne sont pas écrits" },
		{ Path = "ZoneBar.Fill", Class = "GuiObject" },
		{ Path = "ZoneBar.ZoneCount", Class = "TextLabel" },
		{ Path = "Tabs.Zone1Tab", Class = BUTTON },
		{ Path = "Tabs.Zone2Tab", Class = BUTTON },
		{ Path = "Tabs.Zone3Tab", Class = BUTTON },
		{ Path = "Tabs.Zone4Tab", Class = BUTTON },
		{ Path = "Tabs.Zone5Tab", Class = BUTTON },
		{ Path = "Tabs.Zone6Tab", Class = BUTTON },
		{ Path = "Tabs.SecretsTab", Class = BUTTON, Optional = true, Note = "pas d'onglet des Secrets" },
		{ Path = "Cards", Class = "GuiObject" },
		{ Path = "Cards.Template", Template = true },
		{ Path = "Cards.Template.Clip", Class = "GuiObject" },
		{ Path = "Cards.Template.Icon", Class = "ImageLabel" },
		{ Path = "Cards.Template.ItemName", Class = "TextLabel" },
		{ Path = "Footer.Pager.PrevButton", Class = BUTTON },
		{ Path = "Footer.Pager.NextButton", Class = BUTTON },
		{ Path = "Footer.Pager.PageLabel", Class = "TextLabel", Optional = true, Note = "la page n'est pas écrite" },
		{ Path = "Footer.ClaimButton", Class = BUTTON },
		{ Path = "Footer.ClaimButton.RewardCaption", Class = "TextLabel", Optional = true, Note = "la récompense n'est pas écrite" },
		{ Path = "Footer.ClaimButton.RewardIcon", Class = "ImageLabel", Optional = true, Note = "pas d'icône de l'objet donné" },
		{ Path = "Footer.ClaimButton.ClaimAlert", Optional = true, Note = "pas de pastille « ! » sur la récompense" },
	} :: { Element },
})
-- UI_Displayed (DisplayedController ; nom gardé par Clément, L-192 Q4) : panneau des objets exposés, écran entier
-- allumé et éteint par UI_HUD.RightRail.DisplayedButton (vague 63 : plus d'OpenButton, L-202 point 4) ; sa réserve
-- (vague 63, a206, L-192 Q3, noms de L-202) : Panel.Reserve, facultative ; vague 73 (a255, L-241 point 4, décision de
-- Cantin du 18/11) : elle revient, titrée INVENTORY par Clément (Config/Displayed.ShowReserve = true), toujours montrée ;
-- l'écran s'ouvre aussi par UI_Hotbar.Bar.InventoryButton (en fin de fichier). La flèche de fermeture est CloseButton
-- (L-241 : même nom) : CloseArrowButton (vague 72) n'est plus au contrat, le code le branche encore s'il existe.
table.insert(UI.Screens, {
	Name = "UI_Displayed",
	Class = "ScreenGui",
	Optional = true,
	Elements = {
		{ Path = "Panel", Class = "GuiObject" },
		{ Path = "CloseButton", Class = BUTTON, Optional = true, Note = "le panneau se ferme par le bouton du HUD seulement" },
		{ Path = "DisplayCount.CountLabel", Class = "TextLabel", Optional = true, Note = "le compte « 3/8 » n'est pas écrit" },
		{ Path = "List.Template", Template = true },
		{ Path = "List.Template.Icon", Class = "ImageLabel" },
		{ Path = "List.Template.ItemName", Class = "TextLabel" },
		{ Path = "List.Template.Income", Class = "TextLabel" },
		{ Path = "List.Template.RarityChip.RarityLabel", Class = "TextLabel", Optional = true, Note = "la rareté n'est pas écrite" },
		{ Path = "List.Template.RemoveButton", Class = BUTTON, Optional = true, Note = "un objet ne se retire pas depuis le panneau" },
		{ Path = "DisplayBestButton", Class = BUTTON },
		{ Path = "Reserve", Class = "GuiObject", Optional = true, Note = "la réserve n'est pas montrée" },
		{ Path = "Reserve.ReserveCount.ReserveCountLabel", Class = "TextLabel", Optional = true, Note = "le nombre d'objets en réserve n'est pas écrit" },
		{ Path = "Reserve.ReserveList.Template", Template = true, Optional = true, Note = "la réserve reste vide" },
		{ Path = "Reserve.ReserveList.Template.Icon", Class = "ImageLabel", Optional = true, Note = "pas d'icône dans la réserve" },
		{ Path = "Reserve.ReserveList.Template.ItemName", Class = "TextLabel", Optional = true, Note = "pas de nom dans la réserve" },
		{ Path = "Reserve.ReserveList.Template.Income", Class = "TextLabel", Optional = true, Note = "pas de revenu/s dans la réserve" },
		{ Path = "Reserve.ReserveList.Template.DisplayButton", Class = BUTTON, Optional = true, Note = "un objet de la réserve ne se remet pas sur un présentoir" },
		-- Vague 66 (a219) : texte « PLACE » (Config/Displayed.LockedButtonText) sur un objet sous antivol à poser au sol.
		{ Path = "Reserve.ReserveList.Template.DisplayButton.DisplayLabel", Class = "TextLabel", Optional = true, Note = "un objet sous antivol garde « DISPLAY » sur son bouton" },
		-- a286 (Clément, 19/11, tools/clement/ui_displayed_une_liste.luau) : une seule liste. Panel.Reserve retiré,
		-- List.Template porte aussi DisplayButton (caché, montré par le code sur un objet de la réserve, RemoveButton
		-- sur un objet exposé) ; les objets exposés d'abord, la réserve en dessous ; Panel.ListEmpty montré quand il
		-- n'y a aucun objet. Les deux formes marchent : avec Panel.Reserve, la réserve reste à part.
		{ Path = "List.Template.DisplayButton", Class = BUTTON, Optional = true, Note = "liste unique pas encore là : la réserve reste dans Panel.Reserve" },
		{ Path = "List.Template.DisplayButton.DisplayLabel", Class = "TextLabel", Optional = true, Note = "liste unique : un objet sous antivol garde « DISPLAY » sur son bouton" },
		{ Path = "ListEmpty", Class = "GuiObject", Optional = true, Note = "liste unique : pas de texte quand il n'y a aucun objet" },
	} :: { Element },
})


-- Liste des tâches du tuto (vague 60, a197 ; noms proposés à Clément, tous facultatifs) : TutorialController clone
-- Tasks.Template par tâche montrée (LayoutOrder = numéro de la tâche), écrit Goal, montre Check sur une tâche faite,
-- Progress (ce qu'il faut faire, « Earn cash: $100 / $300 to buy the Wrench ») et Why sur la tâche en cours.
for _, screenDef in UI.Screens do
	if screenDef.Name == "UI_Tutorial" then
		table.insert(screenDef.Elements, { Path = "Tasks", Optional = true, Note = "pas de liste des tâches : l'étape et sa progression s'écrivent dans Bubble.Label, sous la bulle" })
		table.insert(screenDef.Elements, { Path = "Tasks.Template", Template = true, Optional = true, Note = "la liste des tâches n'est pas remplie" })
		table.insert(screenDef.Elements, { Path = "Tasks.Template.Goal", Class = "TextLabel", Optional = true, Note = "le but de la tâche n'est pas écrit" })
		table.insert(screenDef.Elements, { Path = "Tasks.Template.Check", Optional = true, Note = "une tâche faite n'est pas cochée" })
		table.insert(screenDef.Elements, { Path = "Tasks.Template.Progress", Class = "TextLabel", Optional = true, Note = "ce qu'il faut faire et la progression ne sont pas écrits" })
		table.insert(screenDef.Elements, { Path = "Tasks.Template.Why", Class = "TextLabel", Optional = true, Note = "la raison de la tâche n'est pas écrite" })
	end
end

-- Récompense de zone de l'index v4 : l'objet seul (vague 61, a201, décision de Clément L-192) ; Footer.ItemReward
-- remplace SpeedReward et CashReward (cachés par IndexController s'ils sont encore là). Facultatifs.
for _, screenDef in UI.Screens do
	if screenDef.Name == "UI_Index_v4" then
		table.insert(screenDef.Elements, { Path = "Footer.ItemReward", Optional = true, Note = "l'objet donné par la zone n'est montré que sur ClaimButton" })
		table.insert(screenDef.Elements, { Path = "Footer.ItemReward.RewardIcon", Class = "ImageLabel", Optional = true, Note = "pas d'image de l'objet donné" })
		table.insert(screenDef.Elements, { Path = "Footer.ItemReward.RewardCaption", Class = "TextLabel", Optional = true, Note = "le nom de l'objet donné n'est pas écrit" })
	end
end

-- Billboard de la cinématique d'ouverture (vague 62, a204, L-198 ; noms proposés à Clément) : facultatif. RevealController
-- en pose une copie au-dessus de l'objet qui sort du colis, au marqueur Reveal, et y écrit le nom, la rareté (à sa
-- couleur), le poids (« 1 250 kg ») et la mutation d'effet (cachée sans). Absent : un billboard V0 du code, mêmes noms.
table.insert(UI.Billboards, {
	Name = "BB_Reveal",
	Class = "BillboardGui",
	Optional = true,
	Elements = {
		{ Path = "ItemName", Class = "TextLabel" },
		{ Path = "Rarity", Class = "TextLabel" },
		{ Path = "Weight", Class = "TextLabel", Optional = true, Note = "le poids n'est pas écrit" },
		{ Path = "Mutation", Class = "TextLabel", Optional = true, Note = "la mutation n'est pas écrite" },
		-- a287 (2026-11-21) : la vraie cote « 1 IN N » (cachée sans plan) et le revenu « +$X/s » de l'objet révélé.
		{ Path = "Odds", Class = "TextLabel", Optional = true, Note = "la cote finale n'est pas écrite sous l'objet" },
		{ Path = "Income", Class = "TextLabel", Optional = true, Note = "le revenu de l'objet n'est pas écrit" },
	} :: { Element },
})


-- Poids des objets (vague 62, a203 ; noms proposés à Clément, tous facultatifs) : « 1,250 kg » (Shared/ItemWeight.Format)
-- dans un texte Weight à côté du revenu/s, sur l'étiquette d'un objet exposé (BB_Item, DisplayService), d'un objet porté
-- (BB_Carry, CarryService), du grand socle « BEST ITEM » (BB_RarestDisplay, VfxController) et des cases de la barre du
-- bas (UI_Hotbar Bar.Template, HotbarController). Absent : le poids n'est pas affiché.
for _, billboardDef in UI.Billboards do
	if billboardDef.Name == "BB_Item" or billboardDef.Name == "BB_Carry" or billboardDef.Name == "BB_RarestDisplay" then
		table.insert(billboardDef.Elements, { Path = "Weight", Class = "TextLabel", Optional = true, Note = "le poids de l'objet n'est pas affiché" })
	end
end
for _, screenDef in UI.Screens do
	if screenDef.Name == "UI_Hotbar" then
		table.insert(screenDef.Elements, { Path = "Bar.Template.Weight", Class = "TextLabel", Optional = true, Note = "le poids de l'objet n'est pas affiché dans sa case" })
	end
end

-- Antivol d'un objet posé au sol ou tenu en main (vague 31, L-112 ; a178) : BB_AntiTheft de Clément, copié par
-- UnboxController (sinon un billboard V0 aux mêmes noms). Vague 63 (a205, L-202 point 3) : LockIcon, le cadenas doré,
-- caché quand TimeLabel passe à « UNLOCKED! » sur un objet posé au sol ; absent, rien ne casse.
table.insert(UI.Billboards, {
	Name = "BB_AntiTheft",
	Class = "BillboardGui",
	Optional = true,
	Elements = {
		{ Path = "ItemName", Class = "TextLabel" },
		{ Path = "TimeLabel", Class = "TextLabel" },
		{ Path = "LockIcon", Class = "GuiObject", Optional = true, Note = "pas de cadenas au-dessus du nom" },
	} :: { Element },
})

-- Index v4 de Figma construit sous le nom UI_Index_v3 (vague 63, a207, L-201) : nouveautés de Clément, facultatives
-- (IndexController marche sans elles, comme avec l'écran d'avant).
for _, screenDef in UI.Screens do
	if screenDef.Name == "UI_Index_v3" then
		for zone = 1, 6 do
			local section = `Zone{zone}Section`
			table.insert(screenDef.Elements, { Path = `{section}.ZoneTheme`, Class = "TextLabel", Optional = true, Note = "ZoneName garde les magasins de la zone, pas la ville" })
			table.insert(screenDef.Elements, { Path = `{section}.ZoneBar.RewardIcon`, Class = "ImageLabel", Optional = true, Note = "l'objet donné par la zone n'est pas montré au bout de la barre" })
		end
		table.insert(screenDef.Elements, { Path = "Rewards.ItemReward.RewardIcon", Class = "ImageLabel", Optional = true, Note = "pas d'image de l'objet donné" })
		table.insert(screenDef.Elements, { Path = "Rewards.ItemReward.RewardCaption", Class = "TextLabel", Optional = true, Note = "le nom de l'objet donné n'est pas écrit" })
		table.insert(screenDef.Elements, { Path = "Rewards.ClaimButton.ReadyGradient", Class = "UIGradient", Optional = true, Note = "ClaimButton ne passe pas au vert quand la récompense est prête" })
		table.insert(screenDef.Elements, { Path = "Categories.LimitedButton", Class = BUTTON, Optional = true, Note = "rien à cacher" })
	end
end

-- Boutique Robux v2 (vague 63, a208 ; L-200, noms v3 de L-204) : a438 (24/11) : le seul écran de la boutique Robux,
-- donc obligatoire (l'ancien UI_RobuxShop est retiré) : une seule liste List qui défile, les onglets y font défiler jusqu'à leur
-- section ; chaque section remplit sa Grid depuis son Template ; Featured = pack de départ ; Crate = caisse
-- exclusive (cachée tant que Features.RobuxCrate est à false).
do
	local elements: { Element } = {
		{ Path = "CloseButton", Class = BUTTON },
		{ Path = "Tabs.OffersTab" },
		{ Path = "Tabs.GamepassesTab" },
		{ Path = "Tabs.CashTab" },
		{ Path = "Tabs.BoostsTab" },
		{ Path = "List", Class = "ScrollingFrame" },
	}
	for _, section in { "GamepassesSection", "BoostsSection", "CashSection" } do
		table.insert(elements, { Path = `{section}.Grid`, Class = "GuiObject" })
		table.insert(elements, { Path = `{section}.Grid.Template`, Template = true })
		table.insert(elements, { Path = `{section}.Grid.Template.Icon` })
		table.insert(elements, { Path = `{section}.Grid.Template.ItemName` })
		table.insert(elements, { Path = `{section}.Grid.Template.Price` })
		table.insert(elements, { Path = `{section}.Grid.Template.BuyButton`, Class = BUTTON })
	end
	table.insert(elements, { Path = "GamepassesSection.Grid.Template.Owned", Optional = true, Note = "un gamepass possédé n'est pas montré" })
	table.insert(elements, { Path = "Featured", Class = "GuiObject", Optional = true, Note = "pas de pack de départ dans la v2" })
	table.insert(elements, { Path = "Featured.BuyButton", Class = BUTTON, Optional = true, Note = "le pack de départ ne s'achète pas" })
	table.insert(elements, { Path = "Featured.Timer", Optional = true, Note = "le temps restant du pack de départ n'est pas écrit" })
	table.insert(elements, { Path = "Crate", Class = "GuiObject", Optional = true, Note = "pas de caisse exclusive dans la v2" })
	for index = 1, 3 do
		table.insert(elements, { Path = `Crate.BuyRow.BuyButton{index}`, Class = BUTTON, Optional = true, Note = "ce lot de caisses ne s'achète pas" })
	end
	for index = 1, 6 do
		table.insert(elements, { Path = `Crate.Odd_{index}.Chance`, Optional = true, Note = "la chance de cette case n'est pas écrite" })
	end
	table.insert(UI.Screens, {
		Name = "UI_RobuxShop_v2",
		Class = "ScreenGui",
		Elements = elements,
	})
end


-- Animations des boutiques (vague 63, a209, L-204 points 1 à 3), tout est facultatif. Caisse exclusive de
-- UI_RobuxShop_v2 (Controllers/UI/CrateLoop, boucle de 4 s ; L-203 pour les noms) ; lueur d'un achat Robux
-- (Controllers/UI/PurchaseGlow, UI_PurchaseGlow construit par Clément) ; solde de diamants de UI_DiamondShop
-- (Controllers/UI/DiamondBalance). Un élément absent n'est simplement pas animé. Star et RarityGlow (plusieurs du même
-- nom dans Odds, voulu) ne sont pas listés : le ContractChecker en ferait des problèmes.
-- fusion57 : UI_RobuxShop_v2 est déjà déclaré par a208 (plus haut) ; ses éléments d'animation s'y ajoutent.
for _, screenDef in UI.Screens do
	if screenDef.Name == "UI_RobuxShop_v2" then
		for _, element in {
			{ Path = "Crate.Backdrop.Rays", Optional = true, Note = "les rayons de la caisse ne tournent pas" },
			{ Path = "Crate.Backdrop.Rays.Fade", Class = "UIGradient", Optional = true, Note = "le bord fondu des rayons tourne avec eux" },
			{ Path = "Crate.Backdrop.Glow", Optional = true, Note = "la lueur de la caisse ne respire pas" },
			{ Path = "Crate.Backdrop.Shadow", Optional = true, Note = "l'ombre de la caisse ne suit pas son mouvement" },
			{ Path = "Crate.Odds", Optional = true, Note = "les cases de la caisse ne bougent pas" },
			{ Path = "Crate.Odds.Odd_1", Optional = true, Note = "les cases entrent dans l'ordre commun de la Cascade" },
			{ Path = "Crate.NewBadge", Optional = true, Note = "pas de badge NEW! qui saute" },
			{ Path = "Decor", Optional = true, Note = "pas de décor suspendu (caché sur téléphone)" },
			-- Vague 73 (a253, L-242 point 3, L-247) : RobuxShopController.
			-- a285 (21/11) : « Crate.Preview » (dans Crate.Icon) et non « Crate.Icon.Preview » : chaque segment se cherche
			-- dans tous les descendants, et « Icon » sous Crate désigne aussi les 6 Odds.Odd_n.Icon (doublon signalé).
			{ Path = "Crate.Preview", Class = "ViewportFrame", Optional = true, Note = "pas de caisse 3D (l'image d'Icon reste)" },
			{ Path = "Featured.OldPrice", Optional = true, Note = "pas d'ancien prix du pack de départ" },
			{ Path = "Featured.DiscountTag.DiscountLabel", Optional = true, Note = "pas d'étiquette de remise du pack de départ" },
		} :: { Element } do
			table.insert(screenDef.Elements, element)
		end
	end
end
table.insert(UI.Screens, {
	Name = "UI_PurchaseGlow",
	Class = "ScreenGui",
	Optional = true,
	Elements = {
		{ Path = "RainbowBorder", Class = "GuiObject", Optional = true, Note = "pas de lueur arc-en-ciel pendant un achat Robux" },
	} :: { Element },
})
table.insert(UI.Screens, {
	Name = "UI_DiamondShop",
	Class = "ScreenGui",
	Optional = true,
	Elements = {
		{ Path = "Balance.Amount", Class = "TextLabel", Optional = true, Note = "le solde de diamants n'est pas écrit" },
		{ Path = "Balance.Spent", Class = "TextLabel", Optional = true, Note = "le solde décompte sans « -X » à côté" },
	} :: { Element },
})
-- Vague 64 (a212, Config/UiMotion.HudAway et Appear.Blocks) : rien de nouveau à livrer, tout est facultatif.
--   - UI_Hotbar.Bar (déjà au contrat) descend sous le bord du bas par sa Position tant qu'une boutique d'achat est
--     ouverte, puis revient exactement à la Position de Clément. Un autre écran plein peut faire de même s'il porte
--     l'attribut HudAway = true (booléen, sur le ScreenGui).
--   - Dans un écran qui s'ouvre, les éléments Appear = Pop ou Stamp posés dans un cadre animé (titre, onglets, lignes,
--     objet, bouton) entrent l'un après l'autre, de haut en bas puis de gauche à droite : un bloc = un élément à part.

-- Vague 64 (a213) : modèle facultatif du « +X » du tapis qui vole jusqu'au nombre Speed (GainController,
-- Config/Hud.TrainGainFly ; nom proposé à Clément). Absent : une copie de BB_Gain.Row dans un cadre fait par le code.
-- Entrée à part, facultative, comme le bouton d'UI_Admin : la liste d'UI_HUD ne change pas (SkillTreeButton reste le dernier).
table.insert(UI.Screens, {
	Name = "UI_HUD",
	Class = "ScreenGui",
	Optional = true,
	Elements = {
		{ Path = "TrainGainFly.Template", Class = "GuiObject", Optional = true, Note = "le gain du tapis vole dans une copie de BB_Gain.Row" },
		{ Path = "TrainGainFly.Template.Amount", Class = "TextLabel", Optional = true, Note = "le « +X Speed/s » qui vole n'a pas de texte" },
	} :: { Element },
})

-- Bulles ×N du tapis (vague 64, a214 ; noms proposés à Clément, pas encore livré) : facultatif. BubbleController en pose
-- une copie autour du joueur sur son tapis ; Button reçoit le clic (son UIScale PopScale est animé, créé s'il manque),
-- MultiplierLabel reçoit « ×N », Shine n'est visible qu'à partir de Config/Bubbles.Client.ShineFrom. Absent ou sans
-- Button : bulle de repli construite par le code.
table.insert(UI.Billboards, {
	Name = "BB_TrainBubble",
	Class = "BillboardGui",
	Optional = true,
	Elements = {
		{ Path = "Button", Class = BUTTON },
		{ Path = "MultiplierLabel", Class = "TextLabel", Optional = true, Note = "la bulle n'affiche pas son « ×N »" },
		{ Path = "Shine", Class = "GuiObject", Optional = true, Note = "les grosses valeurs n'ont pas d'éclat à elles" },
	} :: { Element },
})

-- Vague 66 (a222, L-210 points 6 et 9 ; Config/UiMotion.ScrollReveal et HoverFit) : rien de nouveau à livrer.
--   - Dans une liste qui défile (ScrollingFrame) d'une boutique, de l'index, d'UI_Displayed, d'UI_Inventory ou
--     d'UI_Rewards, les cartes hors de la zone visible entrent quand elles y arrivent en défilant (une fois chacune par
--     ouverture). Un autre écran fait de même s'il porte l'attribut ScrollReveal = true (booléen, sur le ScreenGui) ;
--     false le coupe. Une carte = un enfant de la liste ; une section plus haute que la moitié de la liste (zone de
--     l'index) fait entrer ses propres enfants un par un.
--   - Un bouton dans une carte de liste grossit (survol, rebond, réussite) au plus jusqu'au bord de sa carte (le
--     premier parent qui dessine un cadre : fond, UIStroke ou image).

-- Vague 70 (a230, L-189 points 2 et 6) : bonus de BottomRow (HudMenuController, Config/Hud.BottomRow), tout facultatif.
-- NightCountdown lit aussi ses attributs PhonePosition et PhoneAnchorPoint sur téléphone (pas des éléments).
-- Entrée à part, facultative, comme TrainGainFly : la liste d'UI_HUD ne change pas.
do
	local elements: { Element } = {}
	for _, pill in { "FriendBoost", "VipBoost", "CashBoost", "TrainingBoost" } do
		table.insert(elements, { Path = pill, Class = "GuiObject", Optional = true, Note = "ce bonus n'est pas montré dans BottomRow" })
		table.insert(elements, { Path = `{pill}.Amount`, Class = "TextLabel", Optional = true, Note = "la valeur du bonus n'est pas écrite" })
	end
	table.insert(elements, { Path = "CashBoost.Timer", Class = "TextLabel", Optional = true, Note = "le temps restant du boost ×2 argent n'est pas écrit (nom proposé à Clément)" })
	table.insert(UI.Screens, { Name = "UI_HUD", Class = "ScreenGui", Optional = true, Elements = elements })
end

-- Vague 70 (a230, L-189) : revenu de l'objet tenu en main (HeldIncomeController, Config/Hud.HeldIncome). Facultatif :
-- absent, un billboard de repli aux mêmes noms.
table.insert(UI.Billboards, {
	Name = "BB_HeldIncome",
	Class = "BillboardGui",
	Optional = true,
	Elements = {
		{ Path = "Income", Class = "TextLabel" },
	} :: { Element },
})

-- Vague 73 (a256, L-242 points 5 et 6) : écrans de Clément du 2026-11-17, facultatifs.
-- UI_TutorialFocus (TutorialController, Config/Tutorial.Focus) : Focus posé sur le bouton à cliquer, Pointer montré
-- quand le joueur hésite. UI_HelpInvite (HelpInviteController, Config/HelpInvite) : conseil après une capture.
table.insert(UI.Screens, {
	Name = "UI_TutorialFocus",
	Class = "ScreenGui",
	Optional = true,
	Elements = {
		{ Path = "Focus", Class = "GuiObject", Optional = true, Note = "le bouton à cliquer du tuto n'est pas mis en avant" },
		{ Path = "Focus.Pointer", Class = "GuiObject", Optional = true, Note = "pas de flèche quand le joueur hésite" },
	} :: { Element },
})
table.insert(UI.Screens, {
	Name = "UI_HelpInvite",
	Class = "ScreenGui",
	Optional = true,
	Elements = {
		{ Path = "Card.Message", Class = "TextLabel", Optional = true, Note = "le conseil garde le texte posé par Clément" },
		{ Path = "Card.InviteButton", Class = BUTTON, Optional = true, Note = "pas d'invitation depuis le conseil" },
		{ Path = "Card.CloseButton", Class = BUTTON, Optional = true, Note = "le conseil s'éteint seul (HelpInvite.Duration)" },
	} :: { Element },
})
-- Vague 73 (a255, L-241 point 4, L-248 ; décision de Cantin du 18/11) : l'inventaire est la réserve d'UI_Displayed, sous
-- les objets exposés (DisplayedController). Noms de Clément, tous facultatifs.
for _, screenDef in UI.Screens do
	if screenDef.Name == "UI_Hotbar" then
		table.insert(screenDef.Elements, { Path = "Bar.InventoryButton", Class = BUTTON, Optional = true, Note = "l'écran des objets exposés et de l'inventaire ne s'ouvre que par le HUD" })
		table.insert(screenDef.Elements, { Path = "Bar.InventoryButton.InventoryAlert", Class = "GuiObject", Optional = true, Note = "pas de pastille pour un objet entré dans l'inventaire" })
	elseif screenDef.Name == "UI_Displayed" then
		table.insert(screenDef.Elements, { Path = "Reserve.ReserveEmpty", Class = "GuiObject", Optional = true, Note = "inventaire vide : rien ne le dit" })
	end
end
-- a314 (L-292, L-271 ; maquette de Clément, tools/clement/ui_displayed_v2.luau) : vendre un objet depuis sa ligne, avec
-- une confirmation YES / NO (DisplayedController ; prix du serveur, PawnShopService). Tous facultatifs. SellButton est
-- rangé dans Template.Buttons chez Clément (les noms sont cherchés parmi les descendants).
for _, screenDef in UI.Screens do
	if screenDef.Name == "UI_Displayed" then
		local function add(path: string, class: string?, note: string)
			table.insert(screenDef.Elements, { Path = path, Class = class, Optional = true, Note = note })
		end
		add("List.Template.SellButton", BUTTON, "un objet ne se vend pas depuis le panneau")
		add("List.Template.SellButton.SellLabel", "TextLabel", "le bouton de vente garde le texte de Clément")
		add("Confirm", "GuiObject", "un objet ne se vend pas depuis le panneau (pas de confirmation)")
		add("Confirm.Header.Title", "TextLabel", "texte de Clément, le code ne l'écrit pas")
		add("Confirm.ItemIcon", "ImageLabel", "pas d'icône dans la confirmation de vente")
		add("Confirm.ItemRarity", "TextLabel", "la rareté n'est pas écrite dans la confirmation de vente")
		add("Confirm.ItemName", "TextLabel", "le nom n'est pas écrit dans la confirmation de vente")
		add("Confirm.SellPrice", "TextLabel", "le prix de vente n'est pas écrit dans la confirmation")
		add("Confirm.YesButton", BUTTON, "la confirmation de vente ne vend pas")
		add("Confirm.YesButton.YesLabel", "TextLabel", "YES garde le texte de Clément")
		add("Confirm.NoButton", BUTTON, "la confirmation ne se ferme que par la croix")
		add("Confirm.NoButton.NoLabel", "TextLabel", "NO garde le texte de Clément")
		break
	end
end
-- Vague 73 (a254, L-240 point 3) : annonces à tout le serveur (AnnounceController, Config/Announce). Facultatif :
-- absent, chaque annonce part en Notify (sans balises). Le code touche Enabled de l'écran, le texte de Message et de
-- Detail et l'image d'Icon ; Banner entre par son Appear (Pop) de Clément.
table.insert(UI.Screens, {
	Name = "UI_Announce",
	Class = "ScreenGui",
	Optional = true,
	Elements = {
		{ Path = "Banner", Class = "GuiObject" },
		{ Path = "Banner.Icon", Class = "ImageLabel", Optional = true, Note = "pas d'icône dans l'annonce" },
		{ Path = "Banner.Message", Class = "TextLabel" },
		{ Path = "Banner.Detail", Class = "TextLabel", Optional = true, Note = "pas de petite ligne sous le message" },
	} :: { Element },
})
-- Nouvelle ouverture du colis (vague 73, a251 ; Clément, L-236 et L-246 ; Config/Unbox.New ; Controllers/Reveal/Unbox).
-- Tout est facultatif.
--   UI_Unbox.EdgeGlow : le fondu des bords de l'écran chez l'ouvreur (ImageLabel plein écran, ImageTransparency 1 au
--   repos) ; le code allume l'écran pendant l'ouverture, règle ImageColor3 (couleur de la rareté) et ImageTransparency.
--   BB_UnboxOdds : au-dessus du colis, puis des silhouettes. Odds = la cote « 1 IN 37 » ; Rarity = le nom de la rareté
--   montrée, à sa couleur ; Upgrade (« UPGRADE! ») montré le temps d'une amélioration. Absent : un billboard du code.
--   BB_UnboxWord : retiré en vague 74 (a257, L-253, L-254 : plus de mot au-dessus des coups ; UI.Retired).
--   BB_UnboxMark : au-dessus de la tête de l'ouvreur pendant l'inspection à la loupe ; Mark = « ? » puis « ! ».
table.insert(UI.Screens, {
	Name = "UI_Unbox",
	Class = "ScreenGui",
	Optional = true,
	Elements = {
		{ Path = "EdgeGlow", Class = "ImageLabel", Optional = true, Note = "pas de fondu des bords pendant l'ouverture du colis, L-246" },
	} :: { Element },
})
table.insert(UI.Billboards, {
	Name = "BB_UnboxOdds",
	Class = "BillboardGui",
	Optional = true,
	Elements = {
		{ Path = "Odds", Class = "TextLabel" },
		{ Path = "Rarity", Class = "TextLabel", Optional = true, Note = "le nom de la rareté n'est pas écrit sous la cote" },
		{ Path = "Upgrade", Class = "GuiObject", Optional = true, Note = "« UPGRADE! » n'est pas montré" },
	} :: { Element },
})
table.insert(UI.Billboards, {
	Name = "BB_UnboxMark",
	Class = "BillboardGui",
	Optional = true,
	Elements = {
		{ Path = "Mark", Class = "TextLabel" },
	} :: { Element },
})

-- Vague 80 (a266) : quêtes quotidiennes (DEV-132, UI-130 ; QuestController, Config/Quests) et roue de la fortune (DEV-141 ;
-- WheelController, Config/Wheel). Tout est facultatif : écran ou élément absent, rien ne s'affiche, aucune erreur.
-- UI_Quests (noms proposés à Clément, version grise d'abord) : une ligne par quête du jour, clonée depuis List.Template
-- (nommée Quest_<place>). Le code touche Enabled de l'écran, les textes, Visible des lignes, de ClaimButton et de
-- Claimed, la taille X (Scale) de Bar.Fill et l'image d'Icon (Decal ICON_QUEST_<Id> livré par Clément, sinon celle du
-- Template).
table.insert(UI.Screens, {
	Name = "UI_Quests",
	Class = "ScreenGui",
	Optional = true,
	Elements = {
		{ Path = "CloseButton", Class = BUTTON },
		{ Path = "List" },
		{ Path = "List.Template", Template = true },
		{ Path = "List.Template.QuestName", Class = "TextLabel" },
		{ Path = "List.Template.ProgressLabel", Class = "TextLabel", Optional = true, Note = "la progression « 2/3 » n'est pas écrite" },
		{ Path = "List.Template.Bar", Optional = true, Note = "pas de barre de progression" },
		{ Path = "List.Template.Bar.Fill", Optional = true, Note = "pas de barre de progression" },
		{ Path = "List.Template.RewardLabel", Class = "TextLabel", Optional = true, Note = "la récompense n'est pas écrite" },
		{ Path = "List.Template.Icon", Class = "ImageLabel", Optional = true, Note = "pas d'icône de quête" },
		{ Path = "List.Template.ClaimButton", Class = BUTTON },
		{ Path = "List.Template.ClaimButton.ClaimLabel", Class = "TextLabel", Optional = true, Note = "texte de ClaimButton laissé tel quel" },
		{ Path = "List.Template.Claimed", Optional = true, Note = "rien ne montre une quête réclamée, sauf ClaimLabel « DONE »" },
		{ Path = "Timer", Class = "TextLabel", Optional = true, Note = "le temps avant les nouvelles quêtes n'est pas écrit" },
	} :: { Element },
})
-- UI_Wheel (L-165 (d), version grise et habillée de Clément du 2026-11-14 ; WheelController) : Wheel tourne (sa Rotation),
-- Pointer et Rim restent fixes. Segment_01 à Segment_08 dans l'ordre de Config/Wheel.Sectors : Amount reçoit le texte du
-- lot, Icon l'image du Decal ICON_<Sectors[n].Icon> s'il est livré. Chance (pourcentage), BuySpinButton et PriceLabel
-- (tours en plus en Robux, « Soon » tant qu'aucun produit n'existe) : noms proposés à Clément, facultatifs.
local wheelElements = {
	{ Path = "CloseButton", Class = BUTTON },
	{ Path = "Wheel", Class = "GuiObject" },
	{ Path = "Pointer", Class = "GuiObject", Optional = true, Note = "le secteur gagnant est amené en haut de la roue" },
	{ Path = "Result", Optional = true, Note = "le lot gagné part en notification" },
	{ Path = "SpinButton", Class = BUTTON },
	{ Path = "SpinButton.SpinLabel", Optional = true, Note = "texte de SpinButton laissé tel quel" },
	{ Path = "Timer", Optional = true, Note = "le temps avant le prochain tour gratuit n'est pas écrit" },
	{ Path = "BuySpinButton", Class = BUTTON, Optional = true, Note = "pas de tour en plus en Robux (pas encore en vente)" },
	{ Path = "BuySpinButton.PriceLabel", Class = "TextLabel", Optional = true, Note = "prix du tour en plus pas écrit" },
} :: { Element }
for n = 1, 8 do
	local segment = string.format("Wheel.Segment_%02d", n)
	table.insert(wheelElements, { Path = segment, Class = "GuiObject" })
	table.insert(wheelElements, { Path = `{segment}.Amount` })
	table.insert(wheelElements, { Path = `{segment}.Icon`, Class = "ImageLabel", Optional = true, Note = "l'icône d'exemple de Clément reste" })
	table.insert(wheelElements, { Path = `{segment}.Chance`, Class = "TextLabel", Optional = true, Note = "la chance du lot n'est pas écrite" })
end
table.insert(UI.Screens, {
	Name = "UI_Wheel",
	Class = "ScreenGui",
	Optional = true,
	Elements = wheelElements,
})
-- Boutons du HUD (noms proposés à Clément, facultatifs ; dans LeftRail et LeftRailTouch s'il y a deux exemplaires, tous
-- branchés) : QuestsButton ouvre UI_Quests, sa pastille QuestsAlert s'allume quand une quête finie attend d'être
-- réclamée ; WheelButton ouvre UI_Wheel, WheelAlert s'allume quand le tour gratuit du jour attend. Cachés par
-- HudController quand Features.Quests ou Features.Wheel est coupé.
table.insert(UI.Screens, {
	Name = "UI_HUD",
	Class = "ScreenGui",
	Optional = true,
	Elements = {
		{ Path = "QuestsButton", Class = BUTTON, Optional = true, Note = "les quêtes ne s'ouvrent pas depuis le HUD" },
		{ Path = "QuestsButton.QuestsAlert", Optional = true, Note = "pas de pastille pour une quête finie" },
		{ Path = "WheelButton", Class = BUTTON, Optional = true, Note = "la roue ne s'ouvre que par sa zone du hub (WheelZone)" },
		{ Path = "WheelButton.WheelAlert", Optional = true, Note = "pas de pastille pour le tour gratuit" },
	} :: { Element },
})
-- a317 (L-299, Clément, 2026-11-23 ; tools/clement/cash_flash_build.luau) : voile vert sur les bords de l'écran à chaque
-- plaque CollectPad_xx vidée par le joueur local (GainController, Config/CashFlash). Enabled = false au repos ; la
-- BackgroundTransparency posée de chaque bande est le voile à son plus fort. Facultatif : sans lui, pas de voile.
table.insert(UI.Screens, {
	Name = "UI_CashFlash",
	Class = "ScreenGui",
	Optional = true,
	Elements = {
		{ Path = "EdgeGlow", Class = "GuiObject", Optional = true, Note = "pas de voile à l'encaissement d'une plaque" },
		{ Path = "EdgeGlow.Top", Class = "GuiObject", Optional = true, Note = "pas de voile en haut de l'écran" },
		{ Path = "EdgeGlow.Bottom", Class = "GuiObject", Optional = true, Note = "pas de voile en bas de l'écran" },
		{ Path = "EdgeGlow.Left", Class = "GuiObject", Optional = true, Note = "pas de voile à gauche de l'écran" },
		{ Path = "EdgeGlow.Right", Class = "GuiObject", Optional = true, Note = "pas de voile à droite de l'écran" },
	} :: { Element },
})

-- Vague GC6 (a410, MAJ 7, Partie 2 section 3.4) : colonnes de mutations de l'index, noms proposés à Clément, facultatifs
-- (IndexController ; sans eux : « 2/7 » construit par le code sur la carte et la liste dans DetailIncome, en MUTATIONS).
for _, screenDef in UI.Screens do
	if screenDef.Name == "UI_Index_v3" then
		table.insert(screenDef.Elements, { Path = "List.Template.MutationRow", Optional = true, Note = "repli : « 2/7 » sur la carte en MUTATIONS" })
		table.insert(screenDef.Elements, { Path = "List.Template.MutationRow.Template", Template = true, Optional = true, Note = "repli : « 2/7 » sur la carte en MUTATIONS" })
		table.insert(screenDef.Elements, { Path = "List.Template.MutationRow.Template.MutationLabel", Class = "TextLabel", Optional = true, Note = "le nom de l'effet n'est pas écrit" })
		table.insert(screenDef.Elements, { Path = "Detail.DetailMutations", Class = "TextLabel", Optional = true, Note = "repli : les effets obtenus dans DetailIncome, en MUTATIONS" })
	end
end
-- Cabine d'essayage (a411, vague GC6, L-113 ; noms proposés à Clément, pas encore livrés) : tout est facultatif.
-- UI_FittingRoom : choix de la zone du déguisement, ouvert par l'invite de la cabine (DisguiseController). ZoneList.Template
-- (bouton caché) est copié une fois par zone (Zone_1 à Zone_6) : ZoneName reçoit « ZONE n · Thème », Locked est montré
-- tant que la zone demande une renaissance de plus (LockedLabel = « REBIRTH n »). UnlockButton (tuile FittingRoom pas
-- encore achetée) achète la compétence (remote BuySkill), UnlockButton.PriceLabel reçoit son prix. Absent : liste de
-- repli construite par le code. UI_Disguise : chrono du déguisement (Timer = « UNDERCOVER 0:42 ») ; absent : texte de
-- repli en bas de l'écran. Tile_FittingRoom : la tuile de l'arbre (mêmes calques que les autres tuiles) ; absente,
-- l'achat passe par UnlockButton ou par l'écran de repli.
table.insert(UI.Screens, {
	Name = "UI_FittingRoom",
	Class = "ScreenGui",
	Optional = true,
	Elements = {
		{ Path = "CloseButton", Class = BUTTON },
		{ Path = "ZoneList", Class = "GuiObject" },
		{ Path = "ZoneList.Template", Class = BUTTON, Template = true },
		{ Path = "ZoneList.Template.ZoneName", Class = "TextLabel" },
		{ Path = "ZoneList.Template.Locked", Class = "GuiObject", Optional = true, Note = "une zone fermée garde l'aspect d'une zone ouverte" },
		{ Path = "ZoneList.Template.Locked.LockedLabel", Class = "TextLabel", Optional = true, Note = "« REBIRTH n » n'est pas écrit" },
		{ Path = "UnlockButton", Class = BUTTON, Optional = true, Note = "la cabine ne s'achète que par la tuile de l'arbre" },
		{ Path = "UnlockButton.PriceLabel", Class = "TextLabel", Optional = true, Note = "le prix de la cabine n'est pas écrit" },
	} :: { Element },
})
table.insert(UI.Screens, {
	Name = "UI_Disguise",
	Class = "ScreenGui",
	Optional = true,
	Elements = {
		{ Path = "Timer", Class = "TextLabel" },
	} :: { Element },
})
-- La tuile va dans l'entrée UI_SkillTree qui existe (a312 : une seule entrée par écran).
for _, screenDef in UI.Screens do
	if screenDef.Name == "UI_SkillTree" then
		table.insert(screenDef.Elements, { Path = "Tree.Tile_FittingRoom", Class = BUTTON, Optional = true, Note = "la cabine d'essayage s'achète par l'écran de la cabine" })
	end
end
-- a431 (L-332, Cantin, 24/11) : phrase de la compétence choisie (Description de Config/SkillTree), sous Header ; nom
-- proposé à Clément, pas encore livré : facultatif.
for _, screenDef in UI.Screens do
	if screenDef.Name == "UI_SkillTree" then
		table.insert(screenDef.Elements, { Path = "InfoPanel.NodeDesc", Class = "TextLabel", Optional = true, Note = "la phrase de la compétence n'est pas écrite" })
	end
end

return UI
