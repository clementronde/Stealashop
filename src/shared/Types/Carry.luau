--!strict
-- Types du portage (DEV-017) : ce qu'un joueur porte au-dessus de la tête (Partie 1, sections
-- 5.6, 6.1 et 6.2). ReplicatedStorage/Shared/Types/Carry. Ce module ne contient que des types :
--   local CarryTypes = require(ReplicatedStorage.Shared.Types.Carry)
--   local payload: CarryTypes.NPCBoxPayload = { Kind = "NPCBox", ... }
--
-- Le payload est fabriqué par le serveur seulement (StoreHeistService pour un colis PNJ,
-- PvPService pour un objet volé), jamais avec une valeur envoyée par le client (9.6).
-- CarryService garde la même table pendant tout le portage et la repasse à ses écouteurs :
-- ne plus la modifier une fois donnée à StartCarry (6.2 : le contenu tiré au vol ne change pas,
-- même quand le colis change de porteur).

-- Type de colis (attribut `Tier` des ShelfSlot, contrat 10.4).
export type BoxTier = "Standard" | "Premium" | "Luxe"

-- Colis volé à un magasin PNJ (5.3, 5.6). Rareté et objet sont tirés au vol par le serveur.
-- La rareté se voit dès qu'on soulève le colis ; l'objet reste caché jusqu'à l'ouverture (5.7) :
-- CarryService ne l'affiche jamais.
export type NPCBoxPayload = {
	Kind: "NPCBox",
	Tier: BoxTier,
	Zone: number, -- 1 à 6, zone du magasin
	Rarity: string, -- Id de Config.Rarities, ex. « Epic »
	ItemId: string, -- Id de Config.Items, ex. « Z3_Smartphone » (de la même rareté)
	StoreId: string, -- magasin d'origine, ex. « STORE_Z1_Superette » (Id de sa vitrine)
	SlotId: string, -- emplacement de rayon d'origine, au format choisi par StoreHeistService
}

-- Objet volé à un joueur (6.1, jalon M3, DEV-041) : prévu ici, pas encore branché. C'est
-- l'objet lui-même qui flotte, avec son nom, sa rareté et son $/s. Champs à confirmer par
-- PvPService quand il sera écrit.
export type PlayerItemPayload = {
	Kind: "PlayerItem",
	ItemUid: string, -- uid de l'objet dans le profil de la victime (Items[uid], 9.5)
	ItemId: string, -- Id de Config.Items
	Rarity: string, -- Id de Config.Rarities (celle de l'objet)
	Income: number, -- $/s de l'objet, calculé par le serveur, affiché sur BB_Carry
	VictimUserId: number, -- propriétaire, chez qui l'objet revient en cas d'échec (6.1)
	SlotIndex: number, -- présentoir d'origine (Display, 9.5)
}

export type Payload = NPCBoxPayload | PlayerItemPayload

-- Fin d'un portage, passée à CarryService.OnCarryEnded :
--   "Consumed"  réussite : le colis est posé sur un établi (ou l'objet déposé chez le voleur) ;
--   "Failed"    échec : le colis ou l'objet retourne d'où il vient, remis par le service
--               d'origine (StoreHeistService remet le colis sur son rayon) ;
--   "Dropped"   jalon M3 (DEV-048), pas encore branché : coup de batte, le colis est tombé au
--               sol. Il n'est pas perdu : CarryService le garde (voir CarryService.Drop).
export type EndResult = "Consumed" | "Failed" | "Dropped"

return {}
