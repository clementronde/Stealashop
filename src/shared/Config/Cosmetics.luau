--!strict
-- Auras (multiplicateur de puissance) et trails (multiplicateur de vitesse) de la
-- boutique d'auras (Partie 1, sections 5.10 et 7.4). Lu par CosmeticService (possession,
-- équipement, multiplicateurs, effets), ShopService (prix), CosmeticController et
-- AuraShopController (client).
-- Une aura et un trail équipés à la fois ; on garde tout ce qu'on a acheté, et
-- acheter un palier ne demande pas d'avoir le précédent.
--
-- Origine de chaque valeur, notée en commentaire :
--   doc   valeur de la Partie 1 (tables 7.4, sections 5.10 et 7.1) ;
--   V0    V0 proposé, absent du doc, à régler à l'œil.
--
-- `Id` est la clé de la sauvegarde (Cosmetics.Auras, Cosmetics.Trails, 9.5) et de
-- BuyItem / EquipCosmetic (9.4). `DisplayName` est le nom affiché, en anglais (L-036).
-- `Texture` est le nom du Decal de Clément (MOD-045 : PNG 256 × 256 sur fond transparent),
-- cherché dans ReplicatedStorage/Assets, sous-dossiers compris (le premier Decal de ce nom), au
-- format `FX_Aura_<Nom>` / `FX_Trail_<Nom>` de 10.4. Le <Nom> est le nom français d'origine sans
-- accents : c'est un nom technique, que L-036 ne traduit pas. Les 11 Decals sont livrés dans
-- ReplicatedStorage/Assets/FX (Clément, 2026-11-07, L-042).
-- Le même nom désigne aussi l'effet complet de Clément (vague 26, L-097 point 1) : le modèle
-- Assets/FX/Auras/FX_Aura_<Nom> ou Assets/FX/Trails/FX_Trail_<Nom>, dont CosmeticService copie les
-- Attachments sur le personnage ; sans ce modèle, l'effet est refait à partir du Decal. Lien Id ↔
-- modèle : Spark = Etincelle, Flame = Flamme, Lightning = Foudre, Plasma, Galaxy = Galaxie,
-- Royal = Royale ; Dust = Poussiere, Wind = Vent, Turbo, Comet = Comete, Hyperspace = Hyperespace.
-- `Color` est la couleur principale du palier (10.4) : elle teinte les particules, la lumière et
-- le trail (texture de Clément en gris ou en blanc, comme ENV_Texture_Stud, L-030). Couleurs de
-- Clément (MOD-045, L-042).

local DeepFreeze = require(script.Parent.DeepFreeze)
local Features = require(script.Parent.Features)

export type CosmeticKind = "Aura" | "Trail"

export type Cosmetic = {
	Id: string,
	Kind: CosmeticKind,
	Order: number, -- palier, du plus faible au plus fort
	DisplayName: string,
	Multiplier: number, -- aura : M aura des dégâts ; trail : M trail de la Speed affichée (7.1, v2)
	Price: number, -- en $ du jeu
	TargetZones: { number }, -- { première, dernière } zone visée
	Texture: string,
	Color: Color3,
	-- Vague 63 (a210) : ancienne aura retirée de la boutique (Features.NewAuras) ; gardée dans ById pour les
	-- sauvegardes, les kits de Config/Zones et les récompenses de Config/Index.
	Retired: boolean?,
}

-- Rééquilibrage v2 (Cantin, 2026-11-14 ; note equilibrage-v2-proposition.md, 4.4, V0 proposés) : l'aura est LE
-- multiplicateur de force (dégâts d'un coup = P arme × M aura) ; un kit par zone (arme, aura, trail), mêmes paliers
-- pour les auras et les trails (×2, ×3, ×5, ×8, ×12), plus Royal ×20. Galaxy : palier du milieu de la zone 5.
-- Color : couleurs de Clément (MOD-045, liaison L-042, 2026-11-07).
-- Vague 63 (a210) : la boutique d'aujourd'hui, tant que Features.NewAuras est false.
-- Vague 68 (a226, V0 proposés) : prix revus avec ceux des armes (Config/Tools, temps entre zones qui s'allonge) ;
-- la première aura et la première traînée à 100 $ (L-210 (a), Clément : achetables dès le tuto, où l'objet Rare
-- exposé rapporte 5 $/s ; la clé à molette reste donnée). Multiplicateurs inchangés. Avant : 500, 60 K, 1,5 M, 30 M,
-- 400 M, 8 B (auras) ; 300, 40 K, 1 M, 20 M, 2,5 B (traînées) ; Storm 300 K, Demon 2 B.
local LegacyAuras: { Cosmetic } = {
	{ Id = "Spark", Kind = "Aura", Order = 1, DisplayName = "Spark", Multiplier = 2, Price = 100, TargetZones = { 2, 2 }, Texture = "FX_Aura_Etincelle", Color = Color3.fromRGB(255, 217, 59) },
	{ Id = "Flame", Kind = "Aura", Order = 2, DisplayName = "Flame", Multiplier = 3, Price = 4_700, TargetZones = { 3, 3 }, Texture = "FX_Aura_Flamme", Color = Color3.fromRGB(255, 106, 26) }, -- V0 proposé (Cantin, 20/11), avant : 120_000
	{ Id = "Lightning", Kind = "Aura", Order = 3, DisplayName = "Lightning", Multiplier = 5, Price = 130_000, TargetZones = { 4, 4 }, Texture = "FX_Aura_Foudre", Color = Color3.fromRGB(47, 196, 255) }, -- V0 proposé (Cantin, 20/11), avant : 6_000_000
	{ Id = "Plasma", Kind = "Aura", Order = 4, DisplayName = "Plasma", Multiplier = 8, Price = 1_900_000, TargetZones = { 5, 5 }, Texture = "FX_Aura_Plasma", Color = Color3.fromRGB(255, 59, 212) }, -- V0 proposé (Cantin, 20/11), avant : 180_000_000
	{ Id = "Galaxy", Kind = "Aura", Order = 5, DisplayName = "Galaxy", Multiplier = 12, Price = 15_000_000, TargetZones = { 5, 5 }, Texture = "FX_Aura_Galaxie", Color = Color3.fromRGB(139, 92, 255) }, -- V0 proposé (Cantin, 20/11), avant : 1_500_000_000
	{ Id = "Royal", Kind = "Aura", Order = 6, DisplayName = "Royal", Multiplier = 20, Price = 110_000_000, TargetZones = { 6, 6 }, Texture = "FX_Aura_Royale", Color = Color3.fromRGB(255, 194, 26) }, -- V0 proposé (Cantin, 20/11), avant : 11_000_000_000
}

-- Vague 63 (a210, L-205 et L-206) : PROPOSITION pour les 8 auras de Clément, à valider par lui (rien en jeu tant que
-- Features.NewAuras est false). Ordre de Clément (L-205), du plus simple au plus fort. Les 6 paliers d'aujourd'hui
-- gardent leur multiplicateur, leur prix et leurs zones (×2, ×3, ×5, ×8, ×12, ×20 : mêmes PV de vitrine, même kit
-- par zone dans Config/Zones) ; deux paliers s'intercalent : Storm ×4 (fin de zone 3) et Demon ×16 (fin de zone 5).
-- Id = clé de sauvegarde, en anglais (L-036) ; « Lightning » est pris par l'ancienne aura, d'où Storm pour Éclair
-- (nuage, pluie et éclairs). Texture = modèle de Clément dans Assets/FX/Auras (et ICON_Aura_<Nom> de L-179).
-- Prix de Storm et Demon, Id, DisplayName et Color : V0 proposés, absents du doc.
local NewAuras: { Cosmetic } = {
	{ Id = "Shine", Kind = "Aura", Order = 1, DisplayName = "Shine", Multiplier = 2, Price = 100, TargetZones = { 2, 2 }, Texture = "FX_Aura_Shine", Color = Color3.fromRGB(255, 240, 170) },
	{ Id = "Fire", Kind = "Aura", Order = 2, DisplayName = "Fire", Multiplier = 3, Price = 4_700, TargetZones = { 3, 3 }, Texture = "FX_Aura_Feu", Color = Color3.fromRGB(255, 106, 26) }, -- V0 proposé (Cantin, 20/11), avant : 120_000
	{ Id = "Storm", Kind = "Aura", Order = 3, DisplayName = "Storm", Multiplier = 4, Price = 22_000, TargetZones = { 3, 3 }, Texture = "FX_Aura_Eclair", Color = Color3.fromRGB(47, 196, 255) }, -- V0 proposé (Cantin, 20/11), avant : 1_000_000
	{ Id = "Poison", Kind = "Aura", Order = 4, DisplayName = "Poison", Multiplier = 5, Price = 130_000, TargetZones = { 4, 4 }, Texture = "FX_Aura_Poison", Color = Color3.fromRGB(120, 230, 60) }, -- V0 proposé (Cantin, 20/11), avant : 6_000_000
	{ Id = "Tornado", Kind = "Aura", Order = 5, DisplayName = "Tornado", Multiplier = 8, Price = 1_900_000, TargetZones = { 5, 5 }, Texture = "FX_Aura_Tornado", Color = Color3.fromRGB(200, 210, 220) }, -- V0 proposé (Cantin, 20/11), avant : 180_000_000
	{ Id = "Angel", Kind = "Aura", Order = 6, DisplayName = "Angel", Multiplier = 12, Price = 15_000_000, TargetZones = { 5, 5 }, Texture = "FX_Aura_Angel", Color = Color3.fromRGB(255, 230, 150) }, -- V0 proposé (Cantin, 20/11), avant : 1_500_000_000
	{ Id = "Demon", Kind = "Aura", Order = 7, DisplayName = "Demon", Multiplier = 16, Price = 39_000_000, TargetZones = { 5, 5 }, Texture = "FX_Aura_Demon", Color = Color3.fromRGB(220, 30, 40) }, -- V0 proposé (Cantin, 20/11), avant : 4_000_000_000
	{ Id = "Chained", Kind = "Aura", Order = 8, DisplayName = "Chained", Multiplier = 20, Price = 110_000_000, TargetZones = { 6, 6 }, Texture = "FX_Aura_Chained", Color = Color3.fromRGB(110, 70, 160) }, -- V0 proposé (Cantin, 20/11), avant : 11_000_000_000
}

-- Proposition a210 : chaque ancienne aura achetée devient la nouvelle de même multiplicateur (personne ne perd
-- rien). Appliquée au chargement du profil par CosmeticService, seulement avec Features.NewAuras.
local Migration: { [string]: string } = {
	Spark = "Shine",
	Flame = "Fire",
	Lightning = "Poison",
	Plasma = "Tornado",
	Galaxy = "Angel",
	Royal = "Chained",
}

local Auras: { Cosmetic } = if Features.NewAuras then NewAuras else LegacyAuras

-- Rééquilibrage v2 (note 4.4, V0 proposés) : le trail multiplie la Speed affichée (Vitesse × M trail), d'où sort
-- la marche (Formulas.WalkSpeed, en log) : un trail ×2 vaut un niveau de tapis.
-- Color : couleurs de Clément (MOD-045, liaison L-042, 2026-11-07).
local Trails: { Cosmetic } = {
	{ Id = "Dust", Kind = "Trail", Order = 1, DisplayName = "Dust", Multiplier = 2, Price = 100, TargetZones = { 2, 2 }, Texture = "FX_Trail_Poussiere", Color = Color3.fromRGB(229, 195, 138) },
	{ Id = "Wind", Kind = "Trail", Order = 2, DisplayName = "Wind", Multiplier = 3, Price = 3_100, TargetZones = { 3, 3 }, Texture = "FX_Trail_Vent", Color = Color3.fromRGB(140, 255, 212) }, -- V0 proposé (Cantin, 20/11), avant : 80_000
	{ Id = "Turbo", Kind = "Trail", Order = 3, DisplayName = "Turbo", Multiplier = 5, Price = 88_000, TargetZones = { 4, 4 }, Texture = "FX_Trail_Turbo", Color = Color3.fromRGB(255, 122, 26) }, -- V0 proposé (Cantin, 20/11), avant : 4_000_000
	{ Id = "Comet", Kind = "Trail", Order = 4, DisplayName = "Comet", Multiplier = 8, Price = 1_200_000, TargetZones = { 5, 5 }, Texture = "FX_Trail_Comete", Color = Color3.fromRGB(79, 195, 255) }, -- V0 proposé (Cantin, 20/11), avant : 120_000_000
	{ Id = "Hyperspace", Kind = "Trail", Order = 5, DisplayName = "Hyperspace", Multiplier = 12, Price = 30_000_000, TargetZones = { 6, 6 }, Texture = "FX_Trail_Hyperespace", Color = Color3.fromRGB(155, 92, 255) }, -- V0 proposé (Cantin, 20/11), avant : 3_000_000_000
}

-- Auras et trails partagent le même espace d'Id (un seul catalogId pour BuyItem).
-- Avec Features.NewAuras, les anciennes auras restent dans ById, marquées Retired (pas dans Auras : ni boutique ni
-- achat) : un Id d'ancienne aura (sauvegarde, kit de Config/Zones, récompense de Config/Index) se lit toujours.
local ById: { [string]: Cosmetic } = {}
local retired: { Cosmetic } = {}
if Features.NewAuras then
	for _, cosmetic in LegacyAuras do
		cosmetic.Retired = true
		table.insert(retired, cosmetic)
	end
end
for _, list in { Auras, Trails, retired } do
	for _, cosmetic in list do
		assert(ById[cosmetic.Id] == nil, `Config.Cosmetics : Id en double {cosmetic.Id}`)
		ById[cosmetic.Id] = cosmetic
	end
end
-- Proposition a210 : la migration garde le multiplicateur (même kit, mêmes PV de vitrine).
for old, new in Migration do
	local before: number? = nil
	for _, legacy in LegacyAuras do
		if legacy.Id == old then
			before = legacy.Multiplier
		end
	end
	local after: number? = nil
	for _, aura in NewAuras do
		if aura.Id == new then
			after = aura.Multiplier
		end
	end
	assert(before ~= nil and before == after, `Config.Cosmetics : migration {old} → {new} sans le même multiplicateur`)
end

-- Id à jour : avec Features.NewAuras, une ancienne aura donne sa remplaçante (Migration) ; sinon l'Id tel quel.
local function current(id: string): string
	return if Features.NewAuras then Migration[id] or id else id
end

local Cosmetics = {
	Auras = Auras,
	Trails = Trails,
	ById = ById,
	-- Vague 63 (a210) : proposition des 8 auras de Clément (L-205) et migration des 6 anciennes, en jeu seulement
	-- avec Features.NewAuras. Current(id) : Id à jour (Grant, Equip, Owns de CosmeticService).
	NewAuras = NewAuras,
	LegacyAuras = LegacyAuras,
	Migration = Migration,
	Current = current,
	-- doc 7.1 : sans aura ou sans trail équipé, le multiplicateur vaut 1.
	NoneMultiplier = 1,
	-- doc 7.4 : acheter le palier suivant ne demande pas d'avoir le précédent.
	RequiresPreviousTier = false,
	-- doc 5.10 : les auras des autres joueurs perdent la moitié de leurs particules au-delà de
	-- 60 studs (distance à la caméra du joueur local ; CosmeticController).
	RemoteParticleCutDistance = 60,
	RemoteParticleCutFactor = 0.5,
	-- V0 : intervalle (s) entre deux mesures de distance des auras des autres joueurs.
	RemoteParticleCheckInterval = 0.5,
	-- Vague 63 (a210, L-206) : mouvement des pièces soudées des auras de Clément (attributs Spin, Orbit, Tumble,
	-- Period ; CosmeticController), une seule boucle côté client pour tous les porteurs.
	PieceMotion = {
		MaxDistance = 120, -- V0 : au-delà (studs, de la caméra à la pièce d'accroche), les pièces restent figées
		-- Bulles (Period) : prototype de Clément (L-206) : gonfle de 0 à sa taille sur 86 % du cycle, enfle d'un coup,
		-- disparaît, puis repart ailleurs sur la flaque.
		BubbleGrowShare = 0.86, -- Clément (note du 2026-11-16)
		BubblePopShare = 0.07, -- V0 : part du cycle où la bulle enfle d'un coup (puis cachée jusqu'au cycle suivant)
		BubblePopScale = 1.25, -- V0 : taille au moment d'éclater (× taille livrée)
		BubbleMinScale = 0.05, -- V0 : taille de départ (une pièce ne peut pas avoir une taille nulle)
		BubbleSpread = 1.6, -- V0 : rayon (studs) autour de l'axe de la pièce d'accroche où la bulle réapparaît
	},
}

export type Cosmetics = typeof(Cosmetics)

return DeepFreeze(Cosmetics)
