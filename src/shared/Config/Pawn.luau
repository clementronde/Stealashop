--!strict
-- Receleur (DEV-034 ; liaison L-106 point 4 et L-107 point 2 ; note docs/claude/notes/ui-pawnshop.md) : le stand
-- ENV_Hub_PawnStall du hub (tag PawnShop) rachète les objets du joueur. Partie 1, 5.8 : « Le receleur rachète un
-- objet 120 × son $/s » ; 5.9 : « ses répliques donnent le ton humoristique du jeu ».
--
-- Partagé entre le serveur (PawnShopService : prix, ventes) et le client (PawnShopController : dialogue).
-- Le serveur recalcule toujours le prix : le client ne fait que l'afficher.

local DeepFreeze = require(script.Parent.DeepFreeze)

local Pawn = {
	-- Doc 5.8 et DEV-034 : rachat = PriceFactor × $/s de l'objet (mutation comprise, sans les bonus du joueur,
	-- même revenu que l'écran d'inventaire), arrondi au dollar inférieur.
	PriceFactor = 120,
	-- Note ui-pawnshop.md, point 6 : confirmation « Deal? » pour l'objet tenu de cette rareté ou plus
	-- (Config/Rarities, Order) ; « tout vendre » se confirme toujours (proposition de la note, V0).
	ConfirmFrom = "Common", -- Ironix (2026-11-12) : un objet n'est jamais tenu en main (le « tenu » est le dernier obtenu, choix d'a95) : toute vente se confirme tant que Clément n'a pas tranché (L-114)
	-- V0 proposé, absent du doc : distance (studs) acceptée par le serveur entre le HumanoidRootPart et la plaque
	-- ShopPad du stand (ShopService : 20 autour des comptoirs ; la plaque fait quelques studs, marge pour la
	-- gigue réseau).
	Reach = 20,
	-- V0 proposé, absent du doc : nombre d'objets au plus dans une vente « tout vendre » (borne du remote ;
	-- l'inventaire en garde 30, Balance.Display.InventoryMax).
	MaxSellAll = 200,
	-- V0 proposé, absent du doc : temps (s) pendant lequel la dernière réplique reste dans la bulle après la
	-- fermeture de l'écran (« Come back anytime! »).
	FarewellTime = 2.5,
	-- Répliques du vendeur (bulle BB_PawnTalk.Line), en anglais. Propositions de la note ui-pawnshop.md (points
	-- 3 à 7), à valider par Clément ; celles marquées V0 sont absentes de la note. %s et %d : string.format.
	Lines = {
		Greeting = "Got anything to sell?", -- texte de la maquette
		NothingHeld = "You're holding nothing, pal.",
		NotYours = "That's not yours yet, pal.", -- V0 : pendant un portage (colis, objet volé)
		EmptyInventory = "Your pockets are empty, pal.", -- V0
		ConfirmHeld = "%s %s? I'll give you %s. Deal?", -- « A » ou « An », rareté, prix (« A Mythic? … »)
		ConfirmAll = "%d items for %s. Deal?", -- nombre, prix
		ConfirmAllOne = "1 item for %s. Deal?", -- V0 : la même au singulier
		NoDeal = "Suit yourself.", -- V0
		Sold = "Pleasure doing business!",
		Changed = "Hold on, that's not what you showed me.", -- V0 : le serveur a refusé (inventaire changé)
		Farewell = "Come back anytime!",
	},
	-- Note ui-pawnshop.md, point 8 (T.49 et T.18 de ui-motion-skilltree.md) : couleurs du texte des choix.
	HoverColor = Color3.fromHex("FFF36B"), -- survol : KeyLabel et ChoiceLabel
	DisabledColor = Color3.fromHex("9AA3B5"), -- choix grisé
	-- Note, point 3 : prix en vert (posé par Clément dans la maquette ; le code ne le change pas).
}

return DeepFreeze(Pawn)
