--!strict
-- Mutations des objets (DEV-131, MOD-131 ; décision de Clément du 2026-11-08, liaison L-084 point 3,
-- qui remplace « Or, Diamant, Néon » seuls). Lu par le serveur (StoreHeistService et TruckEventService :
-- tirage ; UnboxService, PvPService : suivi ; DisplayService, CarryService : revenu, étiquettes,
-- échelle du modèle exposé) et par le client (écran d'ouverture).
--
-- Deux familles cumulables, une mutation par famille au plus :
--   - Taille : le modèle exposé change vraiment d'échelle (Model:ScaleTo, DisplayService) ;
--   - Effet : aucun changement du modèle par le code. Les effets visuels sont à Clément (MOD-131) :
--     il les accroche aux attributs MutationSize et MutationEffect du modèle exposé.
-- Revenu d'un objet = revenu de base (Formulas.ItemIncome) × multiplicateur de taille ×
-- multiplicateur d'effet ; les bonus globaux (Premium, Index, ×2) restent par-dessus.
--
-- Tirage (serveur seulement) : à la mise en rayon, comme la rareté (L-031), et pour chaque colis du
-- camion ; jamais pour le colis du tuto (Pot de nouilles, accroche du tuto de StoreHeistService) ni
-- pour un objet TutorialOnly. Les deux familles sont tirées l'une après l'autre, indépendamment, et
-- indépendamment de la rareté.
--
-- Stockage (profil, Types/Profile) : champ facultatif Mutation = { Size = "Big", Effect = "Gold" } de
-- l'objet (Items[uid]) et du colis posé (Boxes[n], BoxQueue) ; un champ absent = aucune mutation dans
-- cette famille, un objet sans champ = aucune mutation. Des chaînes seulement (DataStore).
--
-- Origine de chaque valeur, notée en commentaire :
--   L-084   décision de Clément écrite dans la liaison (multiplicateurs : décidés) ;
--   L-084c  chance « de départ » proposée par Clément, équilibrage à la main d'Ironix ;
--   V0      V0 proposé, absent du doc, à régler en jeu.
-- Chances en pour cent (comme Rarities.BoxOdds) ; le reste = aucune mutation dans la famille.
--
-- API :
--   Mutations.Sizes, Mutations.Effects: { Entry }      dans l'ordre, du plus courant au plus rare
--   Mutations.SizeById, Mutations.EffectById: { [Id]: Entry }
--   Mutations.Roll(rng) -> Mutation?                   un tirage des deux familles ; nil = aucune
--   Mutations.Sanitize(value) -> Mutation?             copie propre d'une mutation lue (profil,
--                                                      payload) : Id inconnus retirés ; nil si vide
--   Mutations.IsValid(value) -> boolean                nil, ou table aux seuls champs Size/Effect connus
--   Mutations.IncomeMultiplier(mutation?) -> number    taille × effet (1 sans mutation ou mal formée)
--   Mutations.Scale(mutation?) -> number               échelle du modèle exposé (1 sans taille)
--   Mutations.Label(mutation?) -> string?              étiquette en capitales : « BIG · GOLD » ; nil sans
--   Mutations.ItemName(name, mutation?) -> string      nom précédé de la mutation : « Big Gold Soda Can »

local DeepFreeze = require(script.Parent.DeepFreeze)

export type SizeId = "Tiny" | "Big" | "Huge" | "Colossal"
export type EffectId = "Shiny" | "Gold" | "Neon" | "Diamond" | "Glitch" | "Hacked" | "Rainbow"

-- Mutation d'un objet ou d'un colis, telle qu'elle est sauvegardée (Types/Profile, Types/Carry).
export type Mutation = {
	Size: string?, -- SizeId, absent = taille normale
	Effect: string?, -- EffectId, absent = aucun effet
}

export type Entry = {
	Id: string,
	DisplayName: string, -- texte affiché, en anglais (L-036)
	DisplayNameUpper: string, -- étiquette BB_Box (comme les raretés)
	IncomeMultiplier: number,
	Scale: number, -- échelle du modèle exposé (1 pour un effet)
	Chance: number, -- pour cent
}

local SIZES: { Entry } = {
	{ Id = "Tiny", DisplayName = "Tiny", DisplayNameUpper = "TINY", Scale = 0.6, IncomeMultiplier = 0.5, Chance = 10 }, -- L-084 ; chance L-084c
	{ Id = "Big", DisplayName = "Big", DisplayNameUpper = "BIG", Scale = 1.5, IncomeMultiplier = 2, Chance = 10 }, -- L-084 ; chance L-084c
	{ Id = "Huge", DisplayName = "Huge", DisplayNameUpper = "HUGE", Scale = 2, IncomeMultiplier = 5, Chance = 4 }, -- L-084 ; chance L-084c
	{ Id = "Colossal", DisplayName = "Colossal", DisplayNameUpper = "COLOSSAL", Scale = 3, IncomeMultiplier = 10, Chance = 1 }, -- L-084 ; chance L-084c
}

local EFFECTS: { Entry } = {
	{ Id = "Shiny", DisplayName = "Shiny", DisplayNameUpper = "SHINY", Scale = 1, IncomeMultiplier = 1.5, Chance = 6 }, -- L-084 ; chance L-084c
	{ Id = "Gold", DisplayName = "Gold", DisplayNameUpper = "GOLD", Scale = 1, IncomeMultiplier = 2, Chance = 3 }, -- L-084 ; chance L-084c
	{ Id = "Neon", DisplayName = "Neon", DisplayNameUpper = "NEON", Scale = 1, IncomeMultiplier = 2.5, Chance = 2 }, -- L-084 ; chance L-084c
	{ Id = "Diamond", DisplayName = "Diamond", DisplayNameUpper = "DIAMOND", Scale = 1, IncomeMultiplier = 3, Chance = 1.5 }, -- L-084 ; chance L-084c
	{ Id = "Glitch", DisplayName = "Glitch", DisplayNameUpper = "GLITCH", Scale = 1, IncomeMultiplier = 4, Chance = 1 }, -- L-084 ; chance L-084c
	{ Id = "Hacked", DisplayName = "Hacked", DisplayNameUpper = "HACKED", Scale = 1, IncomeMultiplier = 6, Chance = 0.5 }, -- L-084 ; chance L-084c
	{ Id = "Rainbow", DisplayName = "Rainbow", DisplayNameUpper = "RAINBOW", Scale = 1, IncomeMultiplier = 10, Chance = 0.2 }, -- L-084 ; chance L-084c
}

-- V0 : séparateur des deux familles sur l'étiquette BB_Box (« BIG · GOLD »), comme l'exemple de la
-- consigne ; ordre affiché : taille, puis effet.
local LABEL_SEPARATOR = " · "

local function byId(list: { Entry }): { [string]: Entry }
	local map: { [string]: Entry } = {}
	for _, entry in list do
		map[entry.Id] = entry
	end
	return map
end

local SIZE_BY_ID = byId(SIZES)
local EFFECT_BY_ID = byId(EFFECTS)

-- Une mutation de la famille `list`, ou nil (pour cent ; le reste de 100 = aucune).
local function rollFamily(list: { Entry }, rng: Random): string?
	local roll = rng:NextNumber() * 100
	for _, entry in list do
		if roll < entry.Chance then
			return entry.Id
		end
		roll -= entry.Chance
	end
	return nil
end

local function sizeOf(value: any): Entry?
	if type(value) ~= "table" then
		return nil
	end
	local id = value.Size
	return if type(id) == "string" then SIZE_BY_ID[id] else nil
end

local function effectOf(value: any): Entry?
	if type(value) ~= "table" then
		return nil
	end
	local id = value.Effect
	return if type(id) == "string" then EFFECT_BY_ID[id] else nil
end

local Mutations = {
	Sizes = SIZES,
	Effects = EFFECTS,
	SizeById = SIZE_BY_ID,
	EffectById = EFFECT_BY_ID,
}

-- Tirage des deux familles (serveur). nil quand aucune ne sort : rien à sauvegarder.
function Mutations.Roll(rng: Random): Mutation?
	local size = rollFamily(SIZES, rng)
	local effect = rollFamily(EFFECTS, rng)
	if size == nil and effect == nil then
		return nil
	end
	return { Size = size, Effect = effect }
end

-- Copie propre d'une mutation venue du profil ou d'un payload : seuls les Id connus restent. nil si
-- rien ne reste (aucune mutation). Ne lève jamais d'erreur.
function Mutations.Sanitize(value: any): Mutation?
	local size = sizeOf(value)
	local effect = effectOf(value)
	if size == nil and effect == nil then
		return nil
	end
	return { Size = if size then size.Id else nil, Effect = if effect then effect.Id else nil }
end

-- nil, ou une table dont les seuls champs sont Size et Effect, chacun absent ou connu.
function Mutations.IsValid(value: any): boolean
	if value == nil then
		return true
	end
	if type(value) ~= "table" then
		return false
	end
	for key, id in value do
		if key == "Size" then
			if type(id) ~= "string" or SIZE_BY_ID[id] == nil then
				return false
			end
		elseif key == "Effect" then
			if type(id) ~= "string" or EFFECT_BY_ID[id] == nil then
				return false
			end
		else
			return false
		end
	end
	return true
end

-- Multiplicateur de revenu : taille × effet ; 1 sans mutation (Id inconnu : 1 pour sa famille).
function Mutations.IncomeMultiplier(mutation: any): number
	local size = sizeOf(mutation)
	local effect = effectOf(mutation)
	return (if size then size.IncomeMultiplier else 1) * (if effect then effect.IncomeMultiplier else 1)
end

-- Échelle du modèle exposé : celle de la taille, 1 sinon.
function Mutations.Scale(mutation: any): number
	local size = sizeOf(mutation)
	return if size then size.Scale else 1
end

-- Étiquette en capitales (BB_Box, champ Mutation de BB_Item ou BB_Carry s'il existe) : « BIG · GOLD »,
-- « HUGE », « RAINBOW » ; nil sans mutation (ligne cachée).
function Mutations.Label(mutation: any): string?
	local parts: { string } = {}
	local size = sizeOf(mutation)
	local effect = effectOf(mutation)
	if size then
		table.insert(parts, size.DisplayNameUpper)
	end
	if effect then
		table.insert(parts, effect.DisplayNameUpper)
	end
	if #parts == 0 then
		return nil
	end
	return table.concat(parts, LABEL_SEPARATOR)
end

-- Nom de l'objet précédé de sa mutation (V0 : BB_Item, BB_Carry et écran d'ouverture n'ont pas de
-- champ à eux) : « Big Gold Soda Can », « Rainbow Soda Can » ; le nom seul sans mutation.
function Mutations.ItemName(name: string, mutation: any): string
	local size = sizeOf(mutation)
	local effect = effectOf(mutation)
	local prefix = ""
	if size then
		prefix ..= size.DisplayName .. " "
	end
	if effect then
		prefix ..= effect.DisplayName .. " "
	end
	return prefix .. name
end

export type Mutations = typeof(Mutations)

return DeepFreeze(Mutations)
