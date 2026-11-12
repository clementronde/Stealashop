--!strict
-- InventoryState (L-079, L-091 point 6 ; serveur et client) : ce que montre l'écran d'inventaire
-- UI_Inventory, mis en texte par InventoryService dans l'attribut InventoryState du Player, relu par
-- InventoryController. Un attribut plutôt qu'un remote : c'est un état, toujours à jour, même pour un
-- client qui arrive après le dernier changement. Il est visible des autres clients (attribut d'un
-- Player) : il ne contient rien de secret, jamais l'objet d'un colis (5.7).
--
-- Texte (V0, plus court et plus simple à relire qu'un JSON, sans HttpService) : enregistrements séparés
-- par « ; », champs par « , », le premier enregistrement est la version du format :
--   1;I,<uid>,<ItemId>,<revenu>,<présentoir>,<taille>,<effet>;B,<uid>,<type>,<rareté>,<prêt à>,<posé>
--   I  un objet du joueur, exposé (présentoir = son numéro) ou dans l'inventaire (présentoir = 0) ;
--      revenu = $/s de l'objet, mutation comprise, sans les bonus du joueur ; taille et effet = Id de
--      Config/Mutations, vides sans mutation dans la famille ; vague 31 (L-112) : un 8e champ « A » pour
--      un objet sous antivol (à poser au sol de sa boutique avant un présentoir), absent sinon (le texte
--      d'un objet libre ne change pas) ;
--   B  un colis : type (Standard, Premium, Luxe), rareté (Config/Rarities), heure serveur à partir de
--      laquelle il s'ouvre (vide si inconnue), posé = 1 s'il est au sol de la boutique, 0 dans
--      l'inventaire.
-- Un identifiant qui contient autre chose que des lettres, chiffres, « _ », « - », « . », « { » et « } »
-- n'est pas écrit (il casserait le texte ; les remotes refusent de toute façon un uid de plus de 64
-- caractères).
--
-- API (serveur et client) :
--   InventoryState.Attribute                      "InventoryState" (attribut du Player)
--   InventoryState.Encode(state) -> string
--   InventoryState.Decode(text) -> State          l'inverse ; texte absent ou mal formé = état vide,
--                                                 enregistrement mal formé ignoré
--   InventoryState.IsSafeId(text) -> boolean      l'identifiant peut-il être écrit tel quel ?

export type ItemEntry = {
	Uid: string,
	ItemId: string,
	Income: number, -- $/s de l'objet, mutation comprise, sans bonus
	Slot: number?, -- présentoir s'il est exposé, nil dans l'inventaire
	Size: string?, -- Config/Mutations
	Effect: string?,
	AntiTheft: boolean?, -- vague 31 (L-112) : sous antivol, se pose au sol de sa boutique (PlaceBox), pas sur un présentoir
}

export type BoxEntry = {
	Uid: string,
	Tier: string,
	Rarity: string,
	ReadyAt: number?, -- heure serveur (Workspace:GetServerTimeNow) d'ouverture possible
	Placed: boolean, -- au sol de sa boutique
}

export type State = {
	Items: { ItemEntry },
	Boxes: { BoxEntry },
}

local VERSION = "1"
local RECORD = ";"
local FIELD = ","
local SAFE_ID = "^[%w_%-%.{}]+$"
local ANTI_THEFT_FLAG = "A" -- 8e champ d'un objet sous antivol (vague 31)

local InventoryState = {}

InventoryState.Attribute = "InventoryState"

function InventoryState.IsSafeId(text: any): boolean
	return type(text) == "string" and string.match(text, SAFE_ID) ~= nil
end

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function optionalId(value: string?): string
	return if value ~= nil and InventoryState.IsSafeId(value) then value else ""
end

function InventoryState.Encode(state: State): string
	local records: { string } = { VERSION }
	for _, item in state.Items do
		if InventoryState.IsSafeId(item.Uid) and InventoryState.IsSafeId(item.ItemId) then
			local income = if finite(item.Income) then item.Income else 0
			local slot = if finite(item.Slot) then math.floor(item.Slot :: number) else 0
			local fields = {
				"I",
				item.Uid,
				item.ItemId,
				string.format("%.6g", income),
				tostring(slot),
				optionalId(item.Size),
				optionalId(item.Effect),
			}
			if item.AntiTheft == true then
				table.insert(fields, ANTI_THEFT_FLAG)
			end
			table.insert(records, table.concat(fields, FIELD))
		end
	end
	for _, box in state.Boxes do
		if InventoryState.IsSafeId(box.Uid) and InventoryState.IsSafeId(box.Tier) and InventoryState.IsSafeId(box.Rarity) then
			local readyAt = if finite(box.ReadyAt) then string.format("%.3f", box.ReadyAt :: number) else ""
			table.insert(records, table.concat({ "B", box.Uid, box.Tier, box.Rarity, readyAt, if box.Placed then "1" else "0" }, FIELD))
		end
	end
	return table.concat(records, RECORD)
end

-- Champs d'un enregistrement (les champs vides comptent).
local function fieldsOf(record: string): { string }
	local fields: { string } = {}
	for field in string.gmatch(record .. FIELD, "([^,]*),") do
		table.insert(fields, field)
	end
	return fields
end

local function emptyToNil(text: string): string?
	return if text == "" then nil else text
end

function InventoryState.Decode(text: any): State
	local state: State = { Items = {}, Boxes = {} }
	if type(text) ~= "string" then
		return state
	end
	local first = true
	for record in string.gmatch(text, "[^;]+") do
		if first then
			first = false
			if record ~= VERSION then
				return state -- format inconnu : rien plutôt que du faux
			end
			continue
		end
		local fields = fieldsOf(record)
		local kind = fields[1]
		if kind == "I" and (#fields == 7 or #fields == 8) then
			local income = tonumber(fields[4])
			local slot = tonumber(fields[5])
			if InventoryState.IsSafeId(fields[2]) and InventoryState.IsSafeId(fields[3]) and finite(income) and finite(slot) then
				table.insert(state.Items, {
					Uid = fields[2],
					ItemId = fields[3],
					Income = income :: number,
					Slot = if (slot :: number) > 0 then slot else nil,
					Size = emptyToNil(fields[6]),
					Effect = emptyToNil(fields[7]),
					AntiTheft = if fields[8] == ANTI_THEFT_FLAG then true else nil,
				})
			end
		elseif kind == "B" and #fields == 6 then
			local readyAt = tonumber(fields[5])
			if InventoryState.IsSafeId(fields[2]) and InventoryState.IsSafeId(fields[3]) and InventoryState.IsSafeId(fields[4]) then
				table.insert(state.Boxes, {
					Uid = fields[2],
					Tier = fields[3],
					Rarity = fields[4],
					ReadyAt = if finite(readyAt) then readyAt else nil,
					Placed = fields[6] == "1",
				})
			end
		end
	end
	return state
end

return InventoryState
