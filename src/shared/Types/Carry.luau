--!strict
-- Types du portage (DEV-017) : ce qu'un joueur porte au-dessus de la tête (Partie 1, sections
-- 5.6, 6.1 et 6.2). ReplicatedStorage/Shared/Types/Carry. Ce module ne contient que des types :
--   local CarryTypes = require(ReplicatedStorage.Shared.Types.Carry)
--   local payload: CarryTypes.NPCBoxPayload = { Kind = "NPCBox", ... }
--
-- Le payload est fabriqué par le serveur seulement (StoreHeistService pour un colis PNJ,
-- PvPService pour un objet volé), jamais avec une valeur envoyée par le client (9.6).
-- CarryService garde la même table pendant tout le portage et la repasse à ses écouteurs :
-- ne plus la modifier une fois donnée à StartCarry (6.2 : le contenu tiré ne change pas, même
-- quand le colis change de porteur). StoreHeistService reconnaît un colis qui revient sur son
-- rayon à cette table.

-- Type de colis : attribut `Tier` du colis posé sur le rayon par StoreHeistService (L-033 : le
-- type appartient au colis, plus à l'emplacement). « Luxe » est l'identifiant technique ; à
-- l'écran, le type s'écrit « Luxury » (L-036).
export type BoxTier = "Standard" | "Premium" | "Luxe"

-- Colis volé à un magasin PNJ (5.3, 5.6). Rareté et objet sont tirés par le serveur à la mise en
-- rayon (L-031), ou remplacés à la prise par l'accroche du tuto (StoreHeistService.SetContentOverride).
-- La rareté et la catégorie de l'objet se voient dès le rayon, sur l'étiquette BB_Box ; l'objet
-- lui-même reste caché jusqu'à l'ouverture (5.7) : son nom et son ItemId ne sont jamais affichés.
export type NPCBoxPayload = {
	Kind: "NPCBox",
	Tier: BoxTier,
	Zone: number, -- 1 à 6, zone du magasin
	Rarity: string, -- Id de Config.Rarities, ex. « Epic »
	ItemId: string, -- Id de Config.Items, ex. « Z3_Smartphone » (de la même rareté), secret jusqu'à OpenBox
	StoreId: string, -- magasin d'origine, ex. « STORE_Z1_Superette » (Id de sa vitrine)
	SlotId: string, -- emplacement de rayon d'origine, au format choisi par StoreHeistService
	-- DEV-131 (L-084) : mutation tirée avec le contenu (Config/Mutations) ; nil = aucune. Visible sur
	-- BB_Box dès le rayon ; jamais pour le colis du tuto.
	Mutation: Mutation?,
}

-- Mutation (Config/Mutations, Types/Profile) : { Size = "Big", Effect = "Gold" }, champs facultatifs.
export type Mutation = {
	Size: string?,
	Effect: string?,
}

-- Objet volé à un joueur (6.1, jalon M3, DEV-041), fabriqué par PvPService à la prise (StealItem).
-- C'est l'objet lui-même qui flotte, avec son nom, sa rareté et son $/s, et un contour rouge. Le
-- profil de la victime ne change pas avant le dépôt : en cas d'échec, l'objet revient sur son
-- présentoir (DisplayService.Release), rien n'est à défaire dans les profils.
export type PlayerItemPayload = {
	Kind: "PlayerItem",
	ItemUid: string, -- uid de l'objet dans le profil de la victime (Items[uid], 9.5)
	ItemId: string, -- Id de Config.Items
	Rarity: string, -- Id de Config.Rarities (celle de l'objet)
	Income: number, -- $/s de l'objet, calculé par le serveur, affiché sur BB_Carry (Format.income)
	VictimUserId: number, -- propriétaire, chez qui l'objet revient en cas d'échec (6.1)
	SlotIndex: number, -- présentoir d'origine (Display, 9.5)
	Mutation: Mutation?, -- DEV-131 : celle de l'objet de la victime (nom de BB_Carry) ; nil = aucune
}

-- Objet sorti d'un colis ouvert sur le rayon d'un magasin PNJ (L-112, Features.ShelfOpen), fabriqué par
-- StoreHeistService quand le joueur prend l'objet sur le rayon. C'est l'objet lui-même qui flotte (comme
-- PlayerItemPayload), avec son halo de rareté et BB_Carry. Rareté finale (crans de chance compris) et
-- mutation sont tirées par le serveur ; rien ne vient du client. À l'entrée de la zone safe, UnboxService
-- le range comme objet sous antivol (Config/ShelfOpen.AntiTheft). Contrat de la vague 31 : StoreHeistService
-- et CarryService (a103) l'ajoutent à l'union Payload plus bas ; UnboxService (a105) le reçoit.
export type NPCItemPayload = {
	Kind: "NPCItem",
	ItemId: string, -- Id de Config.Items
	Rarity: string, -- Id de Config.Rarities, rareté finale (après les crans de chance)
	Mutation: Mutation?, -- tirée avec le contenu (DEV-131) ; nil = aucune
	Zone: number, -- 1 à 6, zone du magasin d'origine
	StoreId: string, -- magasin d'origine (même format que NPCBoxPayload.StoreId)
	SlotId: string, -- emplacement de rayon d'origine (même format que NPCBoxPayload.SlotId)
	Luck: number, -- chance tirée à l'ouverture (≥ 1), pour l'annonce et les statistiques
}

export type Payload = NPCBoxPayload | PlayerItemPayload | NPCItemPayload

-- Fin d'un portage, passée à CarryService.OnCarryEnded :
--   "Consumed"  réussite : le colis est rangé dans l'inventaire à l'entrée de la zone safe (L-089,
--               UnboxService) (ou l'objet déposé chez le voleur,
--               raison « Deposited », après le transfert entre les deux profils) ;
--   "Failed"    échec : le colis ou l'objet retourne d'où il vient, remis par le service
--               d'origine (StoreHeistService remet le colis sur son rayon) ;
--   "Dropped"   coup de batte (DEV-048, raison « Bat »), ou porteur d'un objet NPCItem attrapé
--               (L-112, raison « Caught ») : le colis ou l'objet est tombé au sol. Il n'est pas
--               perdu : CarryService le garde (voir CarryService.Drop et CarryService.Fail).
export type EndResult = "Consumed" | "Failed" | "Dropped"

return {}
