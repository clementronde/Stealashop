--!strict
-- OpenLuck (a476, 25/11 ; liaison L-374 et L-375) : LA formule de la chance d'une ouverture de colis de rayon, commune
-- à tous les chemins du serveur (StoreHeistService : startReveal, cinématique d'un colis de magasin ; startOpening,
-- colis d'un rayon d'événement, camion et Fortune Tower). Le serveur seul la calcule ; le client ne lit que le résultat.
--
--   chance = Table × Event × Server × Skill          (puis l'accroche du tuto, si elle répond, la remplace)
--     Table   chance tirée dans Config/ShelfOpen.LuckTable (×1 à ×10 ; ×1 si Reveal.TableLuck est coupé) ;
--     Event   bonus d'un événement live (attribut LiveEventShelfLuck du Workspace, EventService ; ×1 dans la
--             cinématique tant que Config/ShelfOpen.Reveal.EventLuck est coupé) ;
--     Server  chance du serveur achetée en Robux (attribut ServerLuck du Workspace, MonetizationService : ×2, ×4, ×8) ;
--     Skill   compétence BoxLuck de l'ouvreur (Config/SkillTree, Effects[niveau] : ×1,1 à ×1,5 ; ×1 sans achat ou
--             tuile coupée : Features.SkillBoxLuck / SkillBoxLuckDev). Niveau lu dans l'attribut Skill_BoxLuck du
--             Player, que SkillTreeService seul écrit (un attribut changé par le client ne remonte pas au serveur).
--   Potion : aucune potion de chance n'existe (Config/Potions : Money, Strength, Invisibility) ; PotionLuck de l'arbre
--   rapproche les apparitions des potions et n'entre pas ici.
-- Chaque facteur illisible (nil, NaN, infini, sous son minimum) vaut ×1 ; Table, Server et Skill jamais sous ×1, Event
-- jamais sous ×0,001. Aucun plafond : la plus forte pile possible aujourd'hui est 10 × 8 × 1,5 = ×120 (×3 de plus si un
-- événement LuckRush tourne pendant un colis d'événement). La chance ne force aucune rareté : elle multiplie le poids des
-- raretés au-dessus de la caisse (Config/ShelfBoxes.ContentWeights) et des paliers lourds (Shared/ItemWeight), puis
-- tout est ramené à 100 % ; la caisse et les raretés en dessous gardent leur part, toujours > 0.
-- La cote « 1 IN N » (Shared/ItemOdds) ne compte ni Event, ni Server, ni Skill : c'est la chance de l'objet lui-même.
--
-- API :
--   OpenLuck.Combine(parts) -> number       parts = { Table: any, Event: any, Server: any, Skill: any } (valeurs brutes)
--   OpenLuck.SkillFactor(level: any) -> number   Effects[niveau] de BoxLuck (niveau borné à Coded) ; 1 sinon
--   OpenLuck.SkillFactorOf(player: Player) -> number   SkillFactor de l'attribut Skill_BoxLuck du joueur

--
-- a486 (Cantin, 25/11 ; note d'a479, section 5) : modèle « R2, sans plafond », allumé par OpenLuck.V2
-- (Features.LuckModelV2 partout, ou LuckModelV2Dev dans le jeu DEV ; coupé : tout ce qui suit est sans effet et la
-- chance est celle d'a476, octet pour octet) :
--   chance achetée = Personal × Skill × Server        Personal : ×3 Luck (attributs PersonalLuck et PersonalLuckEndsAt
--                                                     du Player, Config/ShelfOpen.LuckV2, écrits par le serveur seul)
--   table du ×N    les entrées à partir de ShelfOpen.LuckV2.BoostedMinLuck (×8, ×10) × chance achetée, prises sur ×1
--   chance finale  ×N tiré × Event × chance achetée (Combine avec Personal)
--   chance du serveur, en plus : rareté des colis mis en rayon, mutations d'effet ; serveur × personnelle : la roue
--   (StoreHeistService, Config/Mutations.Roll, WheelService), par la même règle Shift. Aucun plafond.
--   OpenLuck.V2: boolean
--   OpenLuck.PersonalFactor(value, endsAt, now) -> number    value si finie ≥ 1 et endsAt > now ; 1 sinon
--   OpenLuck.PersonalFactorOf(player) -> number              PersonalFactor des attributs du joueur (0 sans V2 : ×1)
--   OpenLuck.Bought(parts) -> number                         Personal × Skill × Server (chaque facteur ≥ 1)
--   OpenLuck.Shift(weights, base, isRare, factor) -> { number }
--        poids relatifs : ceux d'indice isRare(i) × factor, la hausse prise sur weights[base] (jamais sous 0) ; le
--        tirage ramène le total à 100 %. factor ≤ 1 ou illisible : une copie inchangée.
--   OpenLuck.LuckTable(entries, bought) -> entries           la table du ×N de la règle R2
--   OpenLuck.StockOdds(odds, list, factor) -> odds          rareté des colis en rayon avec la chance du serveur
--   OpenLuck.Additive: boolean                              a513 : bonus additifs (Features.LuckAdditive, LuckAdditiveDev
--        en DEV et TEST) : Bought = somme des bonus actifs (×1 sans aucun) et Combine = Table × Event × Bought ; coupé : les produits

local Config = script.Parent:WaitForChild("Config")
local SkillTree = require(Config:WaitForChild("SkillTree"))

-- Config/Features, Config/ProductIds et Config/ShelfOpen chargés s'ils sont là (bancs à liste de modules fixe) ; sans eux,
-- V2 coupé (et sans ShelfOpen.LuckV2 : ×1 personnel, table du ×N inchangée).
local function optional(name: string): any
	local found, module = pcall(function(): any
		return Config:FindFirstChild(name)
	end)
	if found and module ~= nil then
		local ok, result = pcall(require, module :: any)
		if ok and type(result) == "table" then
			return result
		end
	end
	return {}
end
local Features: any = optional("Features")
local ProductIds: any = optional("ProductIds")
local ShelfOpen: any = optional("ShelfOpen")

local OpenLuck = {}

OpenLuck.SkillId = "BoxLuck"
OpenLuck.V2 = Features.LuckModelV2 == true or (Features.LuckModelV2Dev == true and ProductIds.IsDev == true)

export type Parts = { Table: any, Event: any, Server: any, Skill: any, Personal: any? }

local function factor(value: any, minimum: number): number
	if type(value) == "number" and value == value and value >= minimum and value < math.huge then
		return value
	end
	return 1
end

-- a513 (Cantin, 27/11) : bonus additifs (Features.LuckAdditive partout, ou LuckAdditiveDev en DEV et TEST) : les bonus
-- (serveur, arbre, personnelle) s'additionnent comme le joueur les lit : la somme des bonus actifs (au-dessus de ×1),
-- ×3 et ×2 donnent ×5 (exemple de Cantin), ×1 sans aucun bonus, un bonus seul inchangé ; le ×N tiré (Table) et
-- l'événement (Event) multiplient ensuite ce total (×4 tiré avec ×5 de bonus = ×20). Coupé : le produit d'avant, à
-- l'identique.
OpenLuck.Additive = Features.LuckAdditive == true or (Features.LuckAdditiveDev == true and ProductIds.IsDev == true)

-- Total des bonus achetés ou gagnés (chaque facteur ≥ 1) : leur produit, ou, avec OpenLuck.Additive, la somme de ceux
-- qui sont actifs (> ×1), ×1 s'il n'y en a aucun.
local function stack(server: any, skill: any, personal: any): number
	local a, b, c = factor(server, 1), factor(skill, 1), factor(personal, 1)
	if OpenLuck.Additive then
		local total = 0
		for _, bonus in { a, b, c } do
			if bonus > 1 then
				total += bonus
			end
		end
		return if total > 0 then total else 1
	end
	return c * b * a
end

function OpenLuck.Combine(parts: Parts): number
	if OpenLuck.Additive then
		return factor(parts.Table, 1) * factor(parts.Event, 1e-3) * stack(parts.Server, parts.Skill, parts.Personal)
	end
	local luck = factor(parts.Table, 1) * factor(parts.Event, 1e-3) * factor(parts.Server, 1) * factor(parts.Skill, 1)
	if parts.Personal ~= nil then
		luck *= factor(parts.Personal, 1)
	end
	return luck
end

function OpenLuck.Bought(parts: { Server: any, Skill: any, Personal: any? }): number
	return stack(parts.Server, parts.Skill, parts.Personal)
end

function OpenLuck.PersonalFactor(value: any, endsAt: any, now: number): number
	if type(endsAt) ~= "number" or endsAt ~= endsAt or endsAt <= now then
		return 1
	end
	return factor(value, 1)
end

function OpenLuck.PersonalFactorOf(player: Player): number
	if not OpenLuck.V2 then
		return 1
	end
	local config = ShelfOpen.LuckV2
	if type(config) ~= "table" then
		return 1
	end
	local now = (workspace :: any):GetServerTimeNow()
	return OpenLuck.PersonalFactor(player:GetAttribute(config.PersonalAttribute), player:GetAttribute(config.PersonalEndsAtAttribute), now)
end

function OpenLuck.Shift(weights: { number }, base: number, isRare: (index: number) -> boolean, multiplier: any): { number }
	local out = table.clone(weights)
	local f = factor(multiplier, 1)
	if f <= 1 or out[base] == nil then
		return out
	end
	local added = 0
	for index, weight in weights do
		if index ~= base and isRare(index) and weight > 0 then
			out[index] = weight * f
			added += weight * (f - 1)
		end
	end
	out[base] = math.max(0, weights[base] - added)
	return out
end

export type LuckEntry = { Luck: number, Weight: number }

function OpenLuck.LuckTable(entries: { LuckEntry }, bought: any): { LuckEntry }
	local weights: { number } = {}
	local base: number? = nil
	for index, entry in entries do
		weights[index] = math.max(entry.Weight, 0)
		if base == nil and entry.Luck <= 1 then
			base = index
		end
	end
	if base == nil then
		return entries
	end
	local boosted = if type(ShelfOpen.LuckV2) == "table" then ShelfOpen.LuckV2.BoostedMinLuck else nil
	if type(boosted) ~= "number" then
		return entries
	end
	local shifted = OpenLuck.Shift(weights, base, function(index: number): boolean
		return entries[index].Luck >= boosted
	end, bought)
	local out: { LuckEntry } = {}
	for index, entry in entries do
		out[index] = { Luck = entry.Luck, Weight = shifted[index] }
	end
	return out
end

function OpenLuck.SkillFactor(level: any): number
	local skill = SkillTree.ById[OpenLuck.SkillId]
	if skill == nil or type(level) ~= "number" or level ~= level then
		return 1
	end
	local capped = math.min(math.floor(level), skill.Coded, skill.MaxLevel)
	if capped < 1 then
		return 1
	end
	return factor(skill.Effects[capped], 1)
end

function OpenLuck.SkillFactorOf(player: Player): number
	return OpenLuck.SkillFactor(player:GetAttribute(SkillTree.AttributePrefix .. OpenLuck.SkillId))
end

-- a486 : rareté des colis mis en rayon avec la chance du serveur (`multiplier`) : `odds` = { [rareté] = poids } d'une zone
-- (Config/ShelfBoxes.ZoneOdds), `list` = les raretés dans l'ordre (Config/Rarities.List). Les raretés au-dessus de la plus
-- basse de la zone (poids > 0) × multiplier, prises sur la plus basse (OpenLuck.Shift). multiplier ≤ 1 : une copie.
function OpenLuck.StockOdds(odds: { [string]: number }, list: { any }, multiplier: any): { [string]: number }
	local weights: { number } = {}
	local base: number? = nil
	for index, rarity in list do
		local weight = odds[rarity.Id] or 0
		weights[index] = math.max(weight, 0)
		if base == nil and weight > 0 then
			base = index
		end
	end
	local out: { [string]: number } = table.clone(odds)
	if base == nil then
		return out
	end
	local shifted = OpenLuck.Shift(weights, base, function(_index: number): boolean
		return true
	end, multiplier)
	for index, rarity in list do
		if odds[rarity.Id] ~= nil then
			out[rarity.Id] = shifted[index]
		end
	end
	return out
end

return OpenLuck
