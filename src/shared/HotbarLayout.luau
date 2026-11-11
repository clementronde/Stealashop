--!strict
-- HotbarLayout (vague 25, retour du Play de Cantin du 2026-11-11 ; serveur et client) : la disposition de
-- la barre du bas UI_Hotbar, choisie par le joueur (HotbarController) et gardée dans son profil
-- (HotbarService, champ facultatif Hotbar du profil, sans changement de version).
--
-- Une disposition = Size cases, dans l'ordre ; chaque case contient un identifiant :
--   "Tool"  l'outil de casse (Tools.DefaultId ou celui que le joueur a équipé) ;
--   "Bat"   la batte ;
--   <uid>   un colis ou un objet du joueur (uid de Boxes ou d'Items du profil) ;
--   ""      case vide.
-- Texte de l'attribut HotbarLayout du Player (posé par HotbarService au chargement du profil puis à
-- chaque disposition acceptée) : les Size identifiants séparés par « , », toujours Size champs
-- (« Tool,Bat,,{uid},, ») ; texte vide = rien de sauvegardé (disposition de départ, choisie par le client).
-- Un uid contient seulement des lettres, chiffres, « _ », « - », « . », « { » et « } »
-- (InventoryState.IsSafeId) : jamais de virgule.
--
-- API (serveur et client) :
--   HotbarLayout.Size                       6 (cases gardées ; le téléphone n'en montre que TouchSlotCount)
--   HotbarLayout.Attribute                  "HotbarLayout" (attribut du Player)
--   HotbarLayout.Tool / Bat / Empty         "Tool", "Bat", ""
--   HotbarLayout.MaxIdLength                64 (comme les autres identifiants des remotes)
--   HotbarLayout.IsId(text) -> boolean      "Tool", "Bat" ou un uid écrivable ; "" n'en est pas un
--   HotbarLayout.Default() -> { string }    outil, batte, puis Size - 2 cases vides
--   HotbarLayout.Encode(list) -> string     Size champs ; un champ absent ou invalide = case vide
--   HotbarLayout.Decode(text) -> { string }?  nil si rien n'est sauvegardé (texte vide ou absent) ;
--                                           sinon Size cases, champ invalide ou en double = case vide

local InventoryState = require(script.Parent:WaitForChild("InventoryState"))

local SIZE = 6 -- décision d'Ironix (vague 25) : 6 cases gardées, comme SlotCount de Bar
local SEPARATOR = ","
local MAX_ID_LENGTH = 64

local HotbarLayout = {}

HotbarLayout.Size = SIZE
HotbarLayout.Attribute = "HotbarLayout"
HotbarLayout.Tool = "Tool"
HotbarLayout.Bat = "Bat"
HotbarLayout.Empty = ""
HotbarLayout.MaxIdLength = MAX_ID_LENGTH

function HotbarLayout.IsId(text: any): boolean
	if type(text) ~= "string" or #text == 0 or #text > MAX_ID_LENGTH then
		return false
	end
	return text == HotbarLayout.Tool or text == HotbarLayout.Bat or InventoryState.IsSafeId(text)
end

function HotbarLayout.Default(): { string }
	local list = { HotbarLayout.Tool, HotbarLayout.Bat }
	for _ = 3, SIZE do
		table.insert(list, HotbarLayout.Empty)
	end
	return list
end

-- Size cases : chaque identifiant valide une seule fois, le reste vide.
local function clean(list: { any }): { string }
	local out: { string } = {}
	local seen: { [string]: boolean } = {}
	for index = 1, SIZE do
		local value = list[index]
		if HotbarLayout.IsId(value) and not seen[value] then
			seen[value] = true
			table.insert(out, value)
		else
			table.insert(out, HotbarLayout.Empty)
		end
	end
	return out
end

function HotbarLayout.Encode(list: { string }): string
	return table.concat(clean(list), SEPARATOR)
end

function HotbarLayout.Decode(text: any): { string }?
	if type(text) ~= "string" or text == "" then
		return nil
	end
	local fields: { string } = {}
	for field in string.gmatch(text .. SEPARATOR, "([^,]*),") do
		table.insert(fields, field)
	end
	return clean(fields)
end

return HotbarLayout
