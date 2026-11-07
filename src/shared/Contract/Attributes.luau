--!strict
-- Contrat : attributs posés par Clément et lus par le code (doc, sections 2.1 et 10.4).

local Attributes = {
	-- Numéro de zone d'un magasin PNJ ou d'une arche : entier de 1 à 6.
	Zone = { Name = "Zone", Min = 1, Max = 6 },
	-- Type de colis. Posé par le code sur chaque colis du rayon (StoreHeistService) ; plus
	-- exigé sur les emplacements ShelfSlot_xx, où le code ne le lit plus (L-033, 2026-11-07).
	-- Partout où il se trouve, il doit valoir l'une de ces valeurs.
	Tier = { Name = "Tier", Values = { "Standard", "Premium", "Luxe" } },
	-- Identifiant de catalogue d'un objet exposé ITM_* (texte non vide) : le nom du modèle sans
	-- le préfixe ITM_ (10.3), un ItemId de Config/Items.
	ItemId = { Name = "ItemId" },
	-- Animation idle d'un objet ITM_* (liaison L-045, proposition de Clément validée par Ironix le
	-- 2026-11-07), posé sur le modèle lui-même, jouée côté client (ItemIdleController) : Spin = le
	-- modèle tourne sur l'axe Y de son pivot, Bob = il monte et descend doucement, SpinBob = les
	-- deux ; absent = immobile. Les pièces Spin_<Nom> tournent avec ou sans lui (Contract/Models).
	Idle = { Name = "Idle", Values = { "Spin", "Bob", "SpinBob" } },
	-- Numéro d'une parcelle taggée PlayerPlot : entier de 1 à 6, chaque numéro une seule
	-- fois, égal au numéro écrit sur la parcelle (« Parcelle 2 » = 2). Ajouté le 2026-11-06
	-- (liaison L-015 et L-017).
	PlotIndex = { Name = "PlotIndex", Min = 1, Max = 6 },
}

return Attributes
