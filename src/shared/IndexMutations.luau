--!strict
-- Colonnes de mutations de l'index (MAJ 7, vague GC6, a410 ; Partie 2, section 3.4 « Relance » : une colonne par
-- mutation pour chaque objet). Commun au serveur (IndexService : note et attribut) et au client (IndexController).
--
-- V0 proposé (Cantin, 23/11) : les colonnes sont les mutations d'effet (Config/Mutations.Effects : Shiny, Gold, Neon,
-- Diamond, Glitch, Hacked, Rainbow) ; les tailles n'en sont pas (avec le poids, Huge et Colossal sont des paliers de
-- poids, pas des mutations à collectionner). Une mutation est « obtenue » pour un objet la première fois que le joueur
-- possède cet objet avec cet effet ; jamais retirée (objet vendu, volé, remis à une renaissance : elle reste).
-- L'objet du tuto (TutorialOnly) n'a jamais de mutation : il n'a pas de colonnes.
--
-- Profil (Types/Profile.IndexMutations, champ du gabarit) : [ItemId] = { [EffectId] = os.time() de l'obtention }.
-- Attribut du Player (IndexService) : Attribute = « IndexMutations », texte d'Encode :
--   « SodaCan:Gold|Neon,Teddy:Rainbow » (objets dans l'ordre du catalogue, effets dans l'ordre de Mutations.Effects).
--
-- API :
--   IndexMutations.Attribute, IndexMutations.Effects ({ Id }), IndexMutations.PerItem (nombre de colonnes)
--   IndexMutations.Counts(item) -> boolean                    l'objet a des colonnes (pas TutorialOnly)
--   IndexMutations.EffectOf(mutation) -> string?              Id d'effet connu de la mutation d'un objet, ou nil
--   IndexMutations.Note(book, itemId, mutation, at) -> boolean  note l'effet ; true s'il ne l'était pas
--   IndexMutations.Encode(book) -> string ; IndexMutations.Decode(text) -> { [ItemId]: { [EffectId]: true } }
--   IndexMutations.CountItem(decoded, itemId) -> number       effets obtenus pour cet objet
--   IndexMutations.Total() -> number                          colonnes de tout le catalogue

local Config = script.Parent.Config
local Items = require(Config.Items)
local Mutations = require(Config.Mutations)

type Item = Items.Item
export type Book = { [string]: { [string]: any } }
export type Decoded = { [string]: { [string]: boolean } }

local EFFECTS: { string } = {}
for _, effect in Mutations.Effects do
	table.insert(EFFECTS, effect.Id)
end

local IndexMutations = {
	Attribute = "IndexMutations", -- V0 proposé (Cantin, 23/11) : attribut du Player
	Effects = EFFECTS,
	PerItem = #EFFECTS,
}

function IndexMutations.Counts(item: Item): boolean
	return not (item :: any).TutorialOnly and not (item :: any).OutOfDraw -- a497 : ni les hors tirage (Config/Index)
end

function IndexMutations.EffectOf(mutation: any): string?
	if type(mutation) ~= "table" then
		return nil
	end
	local id = mutation.Effect
	return if type(id) == "string" and Mutations.EffectById[id] ~= nil then id else nil
end

function IndexMutations.Note(book: Book, itemId: string, mutation: any, at: number): boolean
	local item = Items.ById[itemId]
	local effect = IndexMutations.EffectOf(mutation)
	if item == nil or effect == nil or not IndexMutations.Counts(item) then
		return false
	end
	local row = book[itemId]
	if type(row) ~= "table" then
		row = {}
		book[itemId] = row
	end
	if row[effect] ~= nil then
		return false
	end
	row[effect] = at
	return true
end

function IndexMutations.Encode(book: Book): string
	local parts: { string } = {}
	for _, item in Items.List do
		local row = book[item.Id]
		if type(row) == "table" then
			local effects: { string } = {}
			for _, effect in EFFECTS do
				if row[effect] ~= nil then
					table.insert(effects, effect)
				end
			end
			if #effects > 0 then
				table.insert(parts, `{item.Id}:{table.concat(effects, "|")}`)
			end
		end
	end
	return table.concat(parts, ",")
end

function IndexMutations.Decode(text: any): Decoded
	local decoded: Decoded = {}
	if type(text) ~= "string" then
		return decoded
	end
	for part in string.gmatch(text, "[^,]+") do
		local itemId, list = string.match(part, "^([^:]+):(.+)$")
		if itemId and list and Items.ById[itemId] ~= nil then
			local row: { [string]: boolean } = {}
			for effect in string.gmatch(list, "[^|]+") do
				if Mutations.EffectById[effect] ~= nil then
					row[effect] = true
				end
			end
			decoded[itemId] = row
		end
	end
	return decoded
end

function IndexMutations.CountItem(decoded: Decoded, itemId: string): number
	local row = decoded[itemId]
	local count = 0
	if row then
		for _ in row do
			count += 1
		end
	end
	return count
end

function IndexMutations.Total(): number
	local count = 0
	for _, item in Items.List do
		if IndexMutations.Counts(item) then
			count += #EFFECTS
		end
	end
	return count
end

return IndexMutations
