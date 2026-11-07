--!strict
-- Contrat : attributs posés par Clément et lus par le code (doc, sections 2.1 et 10.4).

local Attributes = {
	-- Numéro de zone d'un magasin PNJ ou d'une arche : entier de 1 à 6.
	Zone = { Name = "Zone", Min = 1, Max = 6 },
	-- Type de colis. Posé par le code sur chaque colis du rayon (StoreHeistService) ; plus
	-- exigé sur les emplacements ShelfSlot_xx, où le code ne le lit plus (L-033, 2026-11-07).
	-- Partout où il se trouve, il doit valoir l'une de ces valeurs.
	Tier = { Name = "Tier", Values = { "Standard", "Premium", "Luxe" } },
	-- Identifiant de catalogue d'un objet exposé ITM_* (texte non vide).
	ItemId = { Name = "ItemId" },
	-- Numéro d'une parcelle taggée PlayerPlot : entier de 1 à 6, chaque numéro une seule
	-- fois, égal au numéro écrit sur la parcelle (« Parcelle 2 » = 2). Ajouté le 2026-11-06
	-- (liaison L-015 et L-017).
	PlotIndex = { Name = "PlotIndex", Min = 1, Max = 6 },
}

return Attributes
