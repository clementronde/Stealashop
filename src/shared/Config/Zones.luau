--!strict
-- Les 6 zones de magasins PNJ du couloir (Partie 1, section 4).
-- Zones[n] = zone n. Le code retrouve les magasins par le tag `NPCStore` et
-- l'attribut `Zone` (1 à 6), jamais par leur nom.
--
-- Rééquilibrage v2, passes 1 à 3 (Cantin, 2026-11-14 ; docs/claude/notes/equilibrage-v2-proposition.md,
-- sections « Passe 3 du 14/11 (8 s) », P2.2, P2.3 et 4.1 ; V0 proposés). Chaque zone fixe deux choses, SpeedRequired et son kit (Kit) ;
-- le reste est CALCULÉ ici, pour suivre tout seul une arme, une aura ou un plafond de coups qui change :
--   AdvisedDamage = « Strength » du panneau = P arme du kit × M aura du kit (1, 10, 120, 1.5K, 20K, 2M)
--   AdvisedSpeed  = marche que donne SpeedRequired (Formulas.WalkSpeed : 16, 22, 28, 33.9, 40, 45.9)
--   WindowHP      = PV / dégâts × AdvisedDamage, arrondi ; les trois nombres de la règle sont dans
--                   Balance.WindowHP (SoloBreakTime, LastZoneBreakTime, LastZoneTeamSize) :
--                   PV / dégâts = temps × MaxHitsPerSecond / (1 + RegenPerSecond × temps)
--                               = 6,5 × 5 / 1,195 = 27,197 : un joueur seul au niveau du panneau casse en
--                   6,5 s, à 5 coups/s, régénération de 3 %/s comprise (27, 272, 3 264, 40 795, 543 933) ;
--                   dernière zone : × 2 joueurs, soit 54,393 × (meilleure arme × meilleure aura) = 108 786 611 :
--                   deux joueurs au panneau cassent en 6,5 s, un joueur seul jamais dans le chrono de 8 s
--                   (16,2 s ; 9,3 s avec la potion de force ×1,5)
--   GuardSpeed    = 0,9 × AdvisedSpeed + 1, arrondi à 0,1 (20.8, 26.2, 31.5, 37, 42.3) : au seuil du panneau,
--                   le vigile reprend 1 stud par seconde au porteur (−10 % avec un colis). Zone 1 : 13,4 gardé
--                   (zone du tuto : 0,9 × 16 − 1).

local DeepFreeze = require(script.Parent.DeepFreeze)
local Balance = require(script.Parent.Balance)
local Cosmetics = require(script.Parent.Cosmetics)
local Tools = require(script.Parent.Tools)

export type Zone = {
	Index: number,
	Theme: string, -- nom affiché de la zone, en anglais (catalogue 10.5, liaison L-036)
	-- Ville de la zone, écrite sur le bandeau d'entrée UI_ZoneBanner (liaison L-110, noms de Clément du
	-- 2026-11-12). nil : pas encore de ville (zone 1) ; le bandeau écrit alors Theme en capitales.
	City: string?,
	Stores: { string }, -- noms affichés des 2 magasins PNJ, en anglais comme leurs enseignes (L-036)
	-- Les mêmes magasins, dans le même ordre, sous leur nom d'asset (10.3) : le modèle de Clément
	-- s'appelle STORE_Z<n>_<Id> (« STORE_Z1_Superette »). Ce sont les noms de la colonne « Magasins
	-- PNJ » de la section 4, sans accents ni espaces, tels qu'ils sont dans la place. Ils servent
	-- seulement à retrouver le nom affiché d'un magasin (StoreInfoController, DEV-030).
	StoreIds: { string },
	-- Speed affichée du panneau (Vitesse × trail, v2) : c'est elle que les panneaux écrivent et comparent à
	-- l'attribut ShownSpeed du joueur (StatsService).
	SpeedRequired: number,
	-- Kit du panneau (v2) : Id de l'arme (Config/Tools), puis de l'aura (Config/Cosmetics ; absente = sans aura).
	Kit: { string },
	WindowHP: number, -- PV de la vitrine (calculé, voir l'en-tête)
	AdvisedDamage: number, -- dégâts par coup conseillés = arme × aura du kit (calculé)
	AdvisedSpeed: number, -- WalkSpeed que donne SpeedRequired (calculé)
	GuardSpeed: number, -- WalkSpeed du vigile de jour (calculé, sauf la zone 1)
	ReturnDistance: number, -- studs jusqu'à la zone safe (zones ×1,25 de Clément, 2026-11-08, liaison L-071)
	BaseIncome: number, -- $/s d'un objet Commun de la zone (R zone, section 7.1)
}

-- Ce que chaque zone fixe ; les champs calculés sont ajoutés plus bas.
type ZoneBase = {
	Index: number,
	Theme: string,
	City: string?,
	Stores: { string },
	StoreIds: { string },
	SpeedRequired: number,
	Kit: { string },
	GuardSpeed: number?, -- fixé seulement pour la zone 1
	ReturnDistance: number,
	BaseIncome: number,
}

local List: { ZoneBase } = {
	{
		Index = 1,
		Theme = "Mini Mart",
		Stores = { "Mini Mart", "Kiosk" },
		StoreIds = { "Superette", "Kiosque" },
		SpeedRequired = 0,
		Kit = { "Fists" },
		GuardSpeed = 13.4,
		ReturnDistance = 75,
		BaseIncome = 1,
	},
	{
		Index = 2,
		Theme = "Toys",
		City = "LONDON",
		Stores = { "Toy Shop", "Sweet Shop" },
		StoreIds = { "MagasinDeJouets", "Confiserie" },
		SpeedRequired = 3_000,
		Kit = { "Wrench", "Spark" },
		ReturnDistance = 175,
		BaseIncome = 8,
	},
	{
		Index = 3,
		Theme = "Electronics",
		City = "TOKYO",
		Stores = { "Electronics", "Video Games" },
		StoreIds = { "Electronique", "JeuxVideo" },
		SpeedRequired = 100_000,
		Kit = { "Crowbar", "Flame" },
		ReturnDistance = 300,
		BaseIncome = 60,
	},
	{
		Index = 4,
		Theme = "Jewelry",
		City = "LOS ANGELES",
		Stores = { "Jewelry", "Watches & Clocks" },
		StoreIds = { "Bijouterie", "Horlogerie" },
		SpeedRequired = 3_000_000,
		Kit = { "Hammer", "Lightning" },
		ReturnDistance = 450,
		BaseIncome = 450,
	},
	{
		Index = 5,
		Theme = "Gallery",
		City = "PARIS",
		Stores = { "Art Gallery", "Antiques" },
		StoreIds = { "GalerieDArt", "Antiquaire" },
		SpeedRequired = 100_000_000,
		Kit = { "Sledgehammer", "Plasma" },
		ReturnDistance = 625,
		BaseIncome = 3_500,
	},
	{
		Index = 6,
		Theme = "Bank",
		City = "NEW YORK",
		Stores = { "Bank", "Vault" },
		StoreIds = { "Banque", "SalleDesCoffres" },
		SpeedRequired = 3_000_000_000,
		Kit = { "AngleGrinder", "Royal" },
		ReturnDistance = 825,
		BaseIncome = 25_000,
	},
}

local stats = Balance.Stats
local window = Balance.Window

-- La formule de Formulas.WalkSpeed, sans trail (Formulas requiert ce module : elle est recopiée ici, et un
-- banc vérifie que les deux donnent le même nombre).
local function walkFor(shownSpeed: number): number
	return math.min(stats.MaxWalkSpeed, stats.BaseWalkSpeed + stats.WalkPerDecade * math.log10(1 + shownSpeed / stats.SpeedScale))
end

-- PV d'une vitrine par point de dégâts du panneau, pour `players` joueurs qui cassent en `seconds` s au plafond
-- de coups, régénération comprise (règle et nombres : Balance.WindowHP).
local function hpPerDamage(players: number, seconds: number): number
	return players * seconds * Balance.Hit.MaxHitsPerSecond / (1 + window.RegenPerSecond * seconds)
end
local rule = Balance.WindowHP
local SOLO_HP_PER_DAMAGE = hpPerDamage(1, rule.SoloBreakTime) -- zones 1 à 5 : 27,197
-- Dernière zone : jamais seul (Cantin, 2026-11-14) : 54,393. Seul avec la potion de force : 9,3 s pour 8.
local LAST_HP_PER_DAMAGE = hpPerDamage(rule.LastZoneTeamSize, rule.LastZoneBreakTime)
-- Vigile de jour (note 4.1) : 0,9 × marche conseillée + 1, arrondi à 0,1.
local GUARD_MARGIN = 1

local Zones: { Zone } = {}
for index, base in List do
	local tool = Tools.ById[base.Kit[1]]
	assert(tool, `Config/Zones : arme inconnue {base.Kit[1]} (zone {index})`)
	local auraMultiplier = Cosmetics.NoneMultiplier
	local auraId = base.Kit[2]
	if auraId ~= nil then
		local aura = Cosmetics.ById[auraId]
		assert(aura and aura.Kind == "Aura", `Config/Zones : aura inconnue {auraId} (zone {index})`)
		auraMultiplier = aura.Multiplier
	end
	local damage = tool.Power * auraMultiplier
	local walk = walkFor(base.SpeedRequired)
	Zones[index] = {
		Index = base.Index,
		Theme = base.Theme,
		City = base.City,
		Stores = base.Stores,
		StoreIds = base.StoreIds,
		SpeedRequired = base.SpeedRequired,
		Kit = base.Kit,
		WindowHP = math.round((if index == #List then LAST_HP_PER_DAMAGE else SOLO_HP_PER_DAMAGE) * damage),
		AdvisedDamage = damage,
		AdvisedSpeed = walk,
		GuardSpeed = base.GuardSpeed or math.round((Balance.Carry.NPCBoxSpeedMultiplier * walk + GUARD_MARGIN) * 10) / 10,
		ReturnDistance = base.ReturnDistance,
		BaseIncome = base.BaseIncome,
	}
end

return DeepFreeze(Zones)
