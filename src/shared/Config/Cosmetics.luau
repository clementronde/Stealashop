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
}

-- Rééquilibrage v2 (Cantin, 2026-11-14 ; note equilibrage-v2-proposition.md, 4.4, V0 proposés) : l'aura est LE
-- multiplicateur de force (dégâts d'un coup = P arme × M aura) ; un kit par zone (arme, aura, trail), mêmes paliers
-- pour les auras et les trails (×2, ×3, ×5, ×8, ×12), plus Royal ×20. Galaxy : palier du milieu de la zone 5.
-- Color : couleurs de Clément (MOD-045, liaison L-042, 2026-11-07).
local Auras: { Cosmetic } = {
	{ Id = "Spark", Kind = "Aura", Order = 1, DisplayName = "Spark", Multiplier = 2, Price = 500, TargetZones = { 2, 2 }, Texture = "FX_Aura_Etincelle", Color = Color3.fromRGB(255, 217, 59) },
	{ Id = "Flame", Kind = "Aura", Order = 2, DisplayName = "Flame", Multiplier = 3, Price = 60_000, TargetZones = { 3, 3 }, Texture = "FX_Aura_Flamme", Color = Color3.fromRGB(255, 106, 26) },
	{ Id = "Lightning", Kind = "Aura", Order = 3, DisplayName = "Lightning", Multiplier = 5, Price = 1_500_000, TargetZones = { 4, 4 }, Texture = "FX_Aura_Foudre", Color = Color3.fromRGB(47, 196, 255) },
	{ Id = "Plasma", Kind = "Aura", Order = 4, DisplayName = "Plasma", Multiplier = 8, Price = 30_000_000, TargetZones = { 5, 5 }, Texture = "FX_Aura_Plasma", Color = Color3.fromRGB(255, 59, 212) },
	{ Id = "Galaxy", Kind = "Aura", Order = 5, DisplayName = "Galaxy", Multiplier = 12, Price = 400_000_000, TargetZones = { 5, 5 }, Texture = "FX_Aura_Galaxie", Color = Color3.fromRGB(139, 92, 255) },
	{ Id = "Royal", Kind = "Aura", Order = 6, DisplayName = "Royal", Multiplier = 20, Price = 8_000_000_000, TargetZones = { 6, 6 }, Texture = "FX_Aura_Royale", Color = Color3.fromRGB(255, 194, 26) },
}

-- Rééquilibrage v2 (note 4.4, V0 proposés) : le trail multiplie la Speed affichée (Vitesse × M trail), d'où sort
-- la marche (Formulas.WalkSpeed, en log) : un trail ×2 vaut un niveau de tapis.
-- Color : couleurs de Clément (MOD-045, liaison L-042, 2026-11-07).
local Trails: { Cosmetic } = {
	{ Id = "Dust", Kind = "Trail", Order = 1, DisplayName = "Dust", Multiplier = 2, Price = 300, TargetZones = { 2, 2 }, Texture = "FX_Trail_Poussiere", Color = Color3.fromRGB(229, 195, 138) },
	{ Id = "Wind", Kind = "Trail", Order = 2, DisplayName = "Wind", Multiplier = 3, Price = 40_000, TargetZones = { 3, 3 }, Texture = "FX_Trail_Vent", Color = Color3.fromRGB(140, 255, 212) },
	{ Id = "Turbo", Kind = "Trail", Order = 3, DisplayName = "Turbo", Multiplier = 5, Price = 1_000_000, TargetZones = { 4, 4 }, Texture = "FX_Trail_Turbo", Color = Color3.fromRGB(255, 122, 26) },
	{ Id = "Comet", Kind = "Trail", Order = 4, DisplayName = "Comet", Multiplier = 8, Price = 20_000_000, TargetZones = { 5, 5 }, Texture = "FX_Trail_Comete", Color = Color3.fromRGB(79, 195, 255) },
	{ Id = "Hyperspace", Kind = "Trail", Order = 5, DisplayName = "Hyperspace", Multiplier = 12, Price = 2_500_000_000, TargetZones = { 6, 6 }, Texture = "FX_Trail_Hyperespace", Color = Color3.fromRGB(155, 92, 255) },
}

-- Auras et trails partagent le même espace d'Id (un seul catalogId pour BuyItem).
local ById: { [string]: Cosmetic } = {}
for _, list in { Auras, Trails } do
	for _, cosmetic in list do
		assert(ById[cosmetic.Id] == nil, `Config.Cosmetics : Id en double {cosmetic.Id}`)
		ById[cosmetic.Id] = cosmetic
	end
end

local Cosmetics = {
	Auras = Auras,
	Trails = Trails,
	ById = ById,
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
}

export type Cosmetics = typeof(Cosmetics)

return DeepFreeze(Cosmetics)
