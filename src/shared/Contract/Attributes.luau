--!strict
-- Contrat : attributs posés par Clément et lus par le code (doc, sections 2.1 et 10.4).

local Attributes = {
	-- Numéro de zone d'un magasin PNJ ou d'une arche : entier de 1 à 6.
	Zone = { Name = "Zone", Min = 1, Max = 6 },
	-- Vague 76 (Cantin et Clément, 19/11) : plus d'attribut Tier (Standard, Premium, Luxe) au contrat : les colis des
	-- rayons n'ont plus de type, seulement une rareté (attribut BoxRarity, posé par le code).
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
	-- Boîte où l'objet exposé doit tenir (L-216 point 2, L-217 ; a234) : Vector3 en studs, posé par Clément sur chaque
	-- Attachment DisplaySlot_xx, dans son repère : X le long de RightVector, Y vers le haut depuis le point, Z le long du
	-- LookVector ; centrée sur le point en X et Z, bas sur le point. DisplayService réduit seulement l'échelle d'affichage
	-- pour y tenir (jamais plus grand). Celui du Model RarestDisplay n'est pas lu (L-220 : vraie taille sur le socle).
	-- Facultatif (absent ou illisible : l'objet garde la taille de son poids).
	FitSize = { Name = "FitSize" },
	-- Son d'ambiance d'une zone (L-221, vague 71, a237 ; AmbienceController) : sur un Sound du Workspace, « Day » = joue le
	-- jour (alerte comprise), « Night » = joue la nuit, avec un fondu (Config/Night.AmbienceFade). Facultatif : sans lui, le
	-- son joue comme il est livré.
	PlayAt = { Name = "PlayAt", Values = { "Day", "Night" } },
	-- Looks de résistance de la boutique (a280, vague GC2 ; L-294 Q3 ; ShopWallsService, Config/SkillTree.HideFromSkill) : sur
	-- une pièce de la parcelle (Look_0 à Look_4), "<Id>" ou "<Id> <niveau>" d'une compétence de Config/SkillTree
	-- (ex. "GlassThickness 1") : la pièce est cachée dès ce niveau (borne haute exclue de ShowFromSkill). Facultatif.
	HideFromSkill = { Name = "HideFromSkill" },
	-- Côté d'une vitre de boutique taguée ShopGlass (a315, L-291) : Front (la rue), Left, Right ou Back, dans le repère de la
	-- boutique. Facultatif : sans lui, GlassThrowService le déduit du nom (Pane_L…, Pane_R…, Pane_F…, Pane_B…) ou de la
	-- place de la vitre dans Bounds ; absent ou faux, ContractChecker le signale en orange.
	GlassSide = { Name = "GlassSide", Values = { "Front", "Left", "Right", "Back" } },
}

return Attributes
