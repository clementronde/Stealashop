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
	PlotIndex = { Name = "PlotIndex", Min = 1, Max = 8 },
	-- Ordre d'attribution d'une parcelle PlayerPlot (L-174, 2026-11-15) : entier de 1 à 8, 1 = la
	-- plus en face du point d'arrivée, donnée au premier joueur. Facultatif (sans lui : ordre des PlotIndex).
	AssignOrder = { Name = "AssignOrder", Min = 1, Max = 8 },
	-- Animations d'UI (L-182 point 1, vague 59, a189 ; noms proposés par Clément, validés par Ironix) : posés par
	-- Clément sur un GuiObject de ses écrans (ou sur un Template : ses copies les gardent), lus par le client
	-- (Controllers/UI/Appear, Motion ; durées dans Config/UiMotion). Tous facultatifs ; une autre valeur est ignorée
	-- (une ligne dans la sortie, en Studio).
	--   Appear : à l'ouverture de l'écran (Enabled) ou de l'élément (Visible), et sa fermeture courte par Motion.Close
	--            ou Motion.Hide. Pop = le cadre grossit ; Cascade = ses enfants entrent l'un après l'autre ; Stamp = un
	--            titre tamponné ; SlideRight = un panneau qui glisse depuis le bord droit ; DropIn (L-188) = un décor qui
	--            tombe à sa place puis se balance.
	--   Hover  : Pop = bouton plus grand au survol ; sur une carte (cadre qui n'est pas un bouton), elle penche et son
	--            Icon grossit.
	--   Press  : Squash = bouton écrasé à l'appui, puis il rebondit au relâché (seulement sur un GuiButton).
	Appear = { Name = "Appear", Values = { "Pop", "Cascade", "Stamp", "SlideRight", "DropIn" } },
	Hover = { Name = "Hover", Values = { "Pop" } },
	Press = { Name = "Press", Values = { "Squash" } },
	-- Meuble qui ne casse jamais sous un objet trop gros pendant l'ouverture d'un colis (L-210 point 3, vague 66, a220 ;
	-- Controllers/Reveal/Shelf, Config/Reveal.Shelf) : vrai (booléen) sur une pièce ou un Model d'un magasin PNJ. Facultatif.
	NoShelfBreak = { Name = "NoShelfBreak" },
}

return Attributes
