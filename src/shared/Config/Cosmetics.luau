--!strict
-- Auras (multiplicateur de puissance) et trails (multiplicateur de vitesse) de la
-- boutique d'auras (Partie 1, sections 5.10 et 7.4).
-- Une aura et un trail équipés à la fois ; on garde tout ce qu'on a acheté, et
-- acheter un palier ne demande pas d'avoir le précédent.
--
-- `Id` est la clé de la sauvegarde (Cosmetics.Auras, Cosmetics.Trails, 9.5) et de
-- BuyItem / EquipCosmetic (9.4). `Texture` suit le format `FX_Aura_<Nom>` /
-- `FX_Trail_<Nom>` de 10.4 ; le <Nom> exact est dérivé du nom affiché, à confirmer avec Clément.

local DeepFreeze = require(script.Parent.DeepFreeze)

export type CosmeticKind = "Aura" | "Trail"

export type Cosmetic = {
	Id: string,
	Kind: CosmeticKind,
	Order: number, -- palier, du plus faible au plus fort
	DisplayName: string,
	Multiplier: number, -- aura : M aura des dégâts ; trail : M trail du WalkSpeed (7.1)
	Price: number, -- en $ du jeu
	TargetZones: { number }, -- { première, dernière } zone visée
	Texture: string,
}

local Auras: { Cosmetic } = {
	{ Id = "Spark", Kind = "Aura", Order = 1, DisplayName = "Étincelle", Multiplier = 1.5, Price = 500, TargetZones = { 1, 2 }, Texture = "FX_Aura_Etincelle" },
	{ Id = "Flame", Kind = "Aura", Order = 2, DisplayName = "Flamme", Multiplier = 2, Price = 15_000, TargetZones = { 2, 3 }, Texture = "FX_Aura_Flamme" },
	{ Id = "Lightning", Kind = "Aura", Order = 3, DisplayName = "Foudre", Multiplier = 3, Price = 400_000, TargetZones = { 3, 4 }, Texture = "FX_Aura_Foudre" },
	{ Id = "Plasma", Kind = "Aura", Order = 4, DisplayName = "Plasma", Multiplier = 5, Price = 10_000_000, TargetZones = { 4, 5 }, Texture = "FX_Aura_Plasma" },
	{ Id = "Galaxy", Kind = "Aura", Order = 5, DisplayName = "Galaxie", Multiplier = 8, Price = 250_000_000, TargetZones = { 5, 6 }, Texture = "FX_Aura_Galaxie" },
	{ Id = "Royal", Kind = "Aura", Order = 6, DisplayName = "Royale", Multiplier = 11, Price = 3_000_000_000, TargetZones = { 6, 6 }, Texture = "FX_Aura_Royale" },
}

local Trails: { Cosmetic } = {
	{ Id = "Dust", Kind = "Trail", Order = 1, DisplayName = "Poussière", Multiplier = 1.1, Price = 300, TargetZones = { 1, 2 }, Texture = "FX_Trail_Poussiere" },
	{ Id = "Wind", Kind = "Trail", Order = 2, DisplayName = "Vent", Multiplier = 1.25, Price = 10_000, TargetZones = { 2, 3 }, Texture = "FX_Trail_Vent" },
	{ Id = "Turbo", Kind = "Trail", Order = 3, DisplayName = "Turbo", Multiplier = 1.4, Price = 300_000, TargetZones = { 3, 4 }, Texture = "FX_Trail_Turbo" },
	{ Id = "Comet", Kind = "Trail", Order = 4, DisplayName = "Comète", Multiplier = 1.6, Price = 8_000_000, TargetZones = { 4, 5 }, Texture = "FX_Trail_Comete" },
	{ Id = "Hyperspace", Kind = "Trail", Order = 5, DisplayName = "Hyperespace", Multiplier = 1.8, Price = 200_000_000, TargetZones = { 5, 6 }, Texture = "FX_Trail_Hyperespace" },
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
	-- Sans aura ou sans trail équipé, le multiplicateur vaut 1 (7.1).
	NoneMultiplier = 1,
	RequiresPreviousTier = false,
	-- 5.10 : les auras des autres joueurs perdent la moitié de leurs particules au-delà de 60 studs
	RemoteParticleCutDistance = 60,
	RemoteParticleCutFactor = 0.5,
}

export type Cosmetics = typeof(Cosmetics)

return DeepFreeze(Cosmetics)
