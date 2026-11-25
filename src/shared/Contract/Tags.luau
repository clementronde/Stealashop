--!strict
-- Contrat : tags posés par Clément et lus par le code (doc, section 2.1).
-- Source unique : le code et le ContractChecker lisent cette liste, jamais un nom recopié.
--
-- Count = nombre exact attendu dans la map jouée (Workspace, hors des dossiers de travail en « _ » : Contract/Find.inMap) ;
-- absent quand le doc ne donne pas de nombre.
-- PerZone = nombre attendu pour chaque valeur de l'attribut Zone (1 à 6).
-- NeedsZone = chaque exemplaire porte l'attribut Zone.

export type TagSpec = {
	Tag: string,
	Count: number?,
	PerZone: number?,
	NeedsZone: boolean?,
	For: string, -- ce qui porte le tag, en clair, pour le rapport
}

local Tags = {}

Tags.List = {
	-- 12 magasins, un de chaque côté du boulevard par zone (section 4).
	-- Zone sur le magasin : déduit de 2.1 (attribut Zone = 1 à 6), le tableau 10.4 ne le cite pas.
	{ Tag = "NPCStore", Count = 12, PerZone = 2, NeedsZone = true, For = "magasins PNJ STORE_*" },
	-- 6 parcelles dans la zone safe (section 4 ; 8 avec le hub de L-113, puis 6 depuis la Place du Mall, L-228 :
	-- serveurs de 6 joueurs, PLOT_Shop_01 à _06).
	{ Tag = "PlayerPlot", Count = 6, For = "parcelles PLOT_*" },
	-- 1 tapis par parcelle : déduit du 10.4 (enfant Treadmill de la parcelle), le doc ne donne pas le nombre
	-- de tags. Plus de banc depuis le rééquilibrage v2 (2026-11-14) : le tag Bench n'est plus au contrat. Plus de tag CashPad (L-091 point 4, 2026-11-10) : l'argent
	-- se ramasse sur les plaques CollectPad_xx, trouvées par leur nom (Contract/Models).
	{ Tag = "Treadmill", Count = 6, For = "tapis de course, 1 par parcelle" },
	-- Une boutique de chaque dans la zone safe (sections 4 et 5.9).
	{ Tag = "WeaponShop", Count = 1, For = "boutique d'armes" },
	{ Tag = "AuraShop", Count = 1, For = "boutique d'auras" },
	{ Tag = "RobuxShop", Count = 1, For = "comptoir Robux (MAJ 1, posé dès MOD-029)" },
	-- Comptoir du receleur, à l'entrée de l'allée (sections 4 et 5.9). Ajouté le 2026-11-06
	-- (liaison L-015 et L-017) : « PawnShop » plutôt que « Fence », qui veut d'abord dire
	-- clôture en anglais.
	{ Tag = "PawnShop", Count = 1, For = "comptoir du receleur" },
	{ Tag = "SafeZone", For = "zone safe" },
	-- Une arche à l'entrée de chaque zone (section 4, MOD-028).
	{ Tag = "ZoneGate", Count = 6, PerZone = 1, NeedsZone = true, For = "arches de zone" },
	-- Un mur géant à l'entrée du couloir (section 5.12).
	{ Tag = "NightWall", Count = 1, For = "mur de nuit" },
	{ Tag = "NightPatrol", For = "points de ronde des vigiles de nuit" },
	-- Vague 42 (L-145 (d), 2026-11-14) : point d'apparition de la vitrine de la Fortune Tower (pièce, Attachment
	-- ou Model, en zone 6), posé par Clément. Facultatif : sans lui, FortuneTowerService calcule la place ;
	-- pas encore posé, il est dans la ligne « Tags pas encore posés » (jamais un problème).
	{ Tag = "FortuneVaultSpawn", For = "point d'apparition de la vitrine de la Fortune Tower (facultatif)" },
	-- Vague 50 (a161, L-165 point 4) : les deux panneaux ENV_Hub_Leaderboard du hub (attribut Stat = Income ou
	-- Speed). Facultatif : pas encore posé, ligne « Tags pas encore posés » (jamais un problème).
	{ Tag = "Leaderboard", For = "panneaux de classement du hub ENV_Hub_Leaderboard (facultatif)" },
	-- Vague 50 (L-165 points 1 et 2, a160 ; noms proposés par Clément, V0) : pièce Zone du cadeau gratuit
	-- (ENV_Hub_FreeGift, ouvre UI_Rewards) et du noob « invite un ami » (ENV_Hub_InviteNoob, ouvre l'invitation).
	-- Facultatifs : pas encore posés, ils sont dans la ligne « Tags pas encore posés » (HubController, HubService).
	{ Tag = "RewardsZone", For = "zone du cadeau gratuit du hub (facultatif)" },
	{ Tag = "InviteZone", For = "zone du noob « invite un ami » du hub (facultatif)" },
	-- Vague 80 (a266, L-165 point 3) : pièce Zone de la roue ENV_Hub_Wheel (y entrer ouvre UI_Wheel, HubController). Facultatif.
	{ Tag = "WheelZone", For = "zone de la roue de la fortune du hub (facultatif)" },
	-- a315 (L-291) : vitres des boutiques de joueurs (Pane_L_01…, Pane_R_01…, Pane_FL, Pane_FR, Pane_B), avec l'attribut
	-- GlassSide ; lues par GlassThrowService (intrus projeté à travers la vitre). Facultatif tant que Clément ne les a pas
	-- posés : sans lui, repli par nom (Pane_* de la boutique) ; pas encore posé, il est dans la ligne « Tags pas encore
	-- posés » (jamais un problème) et ContractChecker le rappelle en orange (catégorie Parcelles).
	{ Tag = "ShopGlass", For = "vitres Pane_* des boutiques de joueurs (facultatif, L-291, L-298 : repli par nom)" },
	-- a430 (L-331) : statues ENV_Hub_LeaderboardStatue du n° 1 des classements de la semaine (attribut Stat), habillées
	-- par LeaderboardStatueService. Facultatif.
	{ Tag = "LeaderboardStatue", For = "statues du n° 1 des classements de la semaine ENV_Hub_LeaderboardStatue (facultatif)" },
	-- a436 (lot101, check-up a417 I6) : points d'apparition du camion d'événement (Attachment, pièce ou Model, attribut
	-- Zone), lus par TruckEventService (un point de la zone au hasard). Facultatif : sans lui, le camion se pose entre les
	-- magasins de la zone. 6 posés par Clément au 23/11 ; le doc ne donne pas de nombre.
	{ Tag = "TruckSpawn", NeedsZone = true, For = "points d'apparition du camion d'événement (facultatif)" },
	-- a436 (I6) : pièces lumineuses des lampadaires (BasePart), allumées la nuit et éteintes le jour par SkyController
	-- (néon et lumières enfants). Facultatif ; 642 posés au 23/11, pas de nombre au doc.
	{ Tag = "NightLight", For = "pièces lumineuses des lampadaires, allumées la nuit (facultatif)" },
	-- fusion102 (L-322 (8), contrat proposé par Clément, accepté le 25/11) : modèles de la déco du hub qui balancent au
	-- vent (attribut SwayAngle en degrés, parties mobiles Sway_*). Pas encore lu par le code : le balancement côté
	-- client reste à coder (L-322 (b)). Facultatif.
	{ Tag = "WindSway", For = "déco du hub qui balance au vent, SwayAngle et Sway_* (facultatif ; pas encore lu par le code, L-322)" },
	-- a475 (L-371) : points des feux d'artifice aux coins de la zone safe (pièce, Attachment ou Model), lus par VfxController
	-- (Config/Vfx.Fireworks, au plus MaxPoints). Posés par Clément le 25/11 : FireworksPoint_N et _S (Map/Hub/Zones). Facultatif.
	{ Tag = "FireworksPoint", For = "points des feux d'artifice de la zone safe (facultatif, L-371)" },
} :: { TagSpec }

-- a436 (lot101, check-up a417 P4) : tags posés par le code lui-même sur ses copies, jamais par Clément. Le
-- ContractChecker ne les compte pas comme « inconnus » s'il en trouve dans la map.
Tags.CodeTags = {
	"ArmoredVan", -- ArmoredVanService
	"CarriedItem", -- CarryService (Config/HeldItem.CarriedTag)
	"CarryRainbow", -- CarryService, colis arc-en-ciel
	"CosmeticAura", -- CosmeticService
	"CosmeticPiece", -- CosmeticService
	"DisplayItem", -- DisplayService
	"EventShelf", -- StoreHeistService
	"EventTruck", -- TruckEventService
	"FloorItem", -- DisplayService
	"FortuneVault", -- FortuneTowerService
	"HitTarget", -- WindowService
	"PlotTrap", -- TrapService (Config/Traps.Tag)
	"RarestItem", -- VfxController (Config/Vfx, copie de l'objet du socle)
	"RevealItem", -- RevealController, objet sorti d'un colis (client)
	"ShelfBox", -- StoreHeistService
	"ShelfItem", -- StoreHeistService (Shared/ShelfOpenState.ItemTag)
	"WitnessNpc", -- WitnessService, DisguiseService (Shared/WitnessGauge.Tag)
} :: { string }

-- a436 (P4) : tags qui ne sont plus au contrat, avec ce qui les a retirés. Encore posés dans la map, ils sont
-- signalés en orange (à retirer quand Clément veut), jamais comme « inconnus ».
Tags.Retired = {
	Bench = "plus de banc depuis le rééquilibrage v2 (14/11) ; plus aucun code ne lit ce tag (a437)",
	CashPad = "plaques CollectPad_xx trouvées par leur nom depuis L-091 point 4 (10/11)",
} :: { [string]: string }

return Tags
