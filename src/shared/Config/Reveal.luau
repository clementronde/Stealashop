--!strict
-- Cinématique d'ouverture d'un colis sur son rayon (vague 62, a204 ; décision de Cantin et Clément du 2026-11-15 ;
-- liaison L-198). Lu par RevealController et Controllers/Reveal (client). Aucune règle de jeu ici : la durée maximale
-- de la phase (RevealMaxSeconds), la protection de l'ouvreur, le tirage, le poids et l'attribut CeilingBroken sont
-- décidés par le serveur (a202, a203). Ici : ce que tout le monde voit, et la caméra de l'ouvreur.
-- Toutes les valeurs sont des V0 proposés, absents du doc. Unités : secondes, studs.

local DeepFreeze = require(script.Parent.DeepFreeze)

local Reveal = {
	-- Rig de caméra de Clément (facultatif) : ReplicatedStorage/<RigPath> = un Model avec un AnimationController et son
	-- Animator, une pièce CameraPart (la caméra suit son CFrame), une pièce ItemAnchor (où se tient l'objet, pivot en bas
	-- au centre) et un dossier Animations (noms : Contract/Animations.Reveal). Le code en pose une copie locale, ItemAnchor
	-- sur l'emplacement du rayon, sa face avant (−Z, LookVector) tournée vers l'allée du magasin.
	RigPath = { "Assets", "Cinematics", "CAM_Reveal" },
	CameraPart = "CameraPart",
	ItemAnchor = "ItemAnchor",
	OpenPrefix = "Open", -- Open<Rareté> : OpenCommon … OpenSecret (OpenDivine), ids de Config/Rarities
	GrowPrefix = "Grow", -- Grow<Classe> : GrowSmall, GrowLarge, GrowColossal (classe envoyée par le serveur)
	-- Une animation dont la longueur est encore 0 au bout de AnimLoadWait s (pas publiée au nom du groupe, id faux) :
	-- son étape passe au repli codé.
	AnimLoadWait = 0.6,

	-- Repli codé (rig ou animation absente) : mêmes étapes et mêmes marqueurs, à ces instants.
	Fallback = {
		OpenAt = 0.45, -- le colis s'ouvre (marqueur Open)
		RevealAt = 0.9, -- l'objet apparaît (Reveal)
		OpenEnd = 1.5, -- fin de l'étape d'ouverture
		PopTime = 0.3, -- l'objet sort de 0,2 à sa taille de départ (Back Out), au Reveal
		GrowTime = { Small = 0.8, Large = 1.6, Colossal = 2.4 }, -- de Grow à Top
		ExplodeAt = 0.65, -- Explode, en part de la croissance (le plafond saute avant la fin)
		LandHold = { Small = 0.9, Large = 1.1, Colossal = 1.6 }, -- de Top à Land (fin)
		Spin = 0.6, -- radians par seconde : l'objet tourne doucement sur lui-même après le Reveal
	},
	-- Plafond côté client : une scène ne dure jamais plus que cela (marqueur Land jamais atteint, animation bloquée).
	-- À garder SOUS le RevealMaxSeconds du serveur, par classe (le serveur finit de toute façon au sien).
	MaxSeconds = { Small = 6, Large = 8, Colossal = 10 },
	-- Après Land, l'objet local reste en place jusqu'au RevealEnded du serveur (l'objet passe alors sur la tête de
	-- l'ouvreur), au plus HoldMax s.
	HoldMax = 2,
	StartScale = 1, -- taille de départ de la croissance (Scale du serveur = taille finale) ; plus petit si Scale l'est
	PopFrom = 0.2,

	-- Caméra de l'ouvreur (repli codé ; avec l'animation, elle suit CameraPart, écart à ItemAnchor × taille).
	Camera = {
		Distance = 7, -- devant l'objet, côté allée, pour une taille 1
		Height = 2.2, -- au-dessus du bas de l'objet, pour une taille 1
		LookHeight = 0.55, -- point visé : en part de la hauteur de l'objet
		MinScale = 0.7, -- la caméra ne s'approche pas plus que pour un objet de cette taille
		Smooth = 7, -- lissage du repli (plus grand = plus vif)
		BlendIn = 0.5, -- passage de la caméra du joueur à la cinématique, et d'une étape à l'autre
		-- Colossal, après Explode : la caméra sort du magasin, côté rue, vue de loin.
		FarBack = 26, -- studs devant la vitrine, plus 1,2 × la hauteur de l'objet
		FarUp = 14, -- studs au-dessus du sol, plus 0,6 × la hauteur de l'objet
	},
	-- HUD masqué chez l'ouvreur (Controllers/UI/HudMask) : seuls ces écrans restent (UI_Escape : le flash de la
	-- révélation, UiFeelController.RevealFlash, Épique et plus). Jamais touchés : HeistFeel.NeverMask.
	MaskKey = "Reveal",
	KeepScreens = { "UI_Escape" },
	FlashMinRarity = "Epic", -- flash et zoom d'UI_Escape chez l'ouvreur au Reveal, à partir de cette rareté

	-- Spectateurs : la scène se joue dans le monde (sans toucher leur caméra) s'ils sont à moins de cette distance.
	SpectatorMaxDistance = 300,

	-- Billboard au-dessus de l'objet, au Reveal : copie de BB_Reveal (Assets/UI, facultatif : ItemName, Rarity,
	-- Weight, Mutation) ; sans lui, un billboard V0 du code (mêmes noms).
	Board = "BB_Reveal",
	BoardV0Size = { X = 240, Y = 72 }, -- pixels
	BoardOffset = 1.5, -- studs au-dessus du haut de l'objet

	-- Sons (Assets/Sounds, sous-dossiers permis ; absents : rien). Noms du relevé de la vague 31.
	Sounds = {
		Open = "Unbox_Open",
		Reveal = "Unbox_UpgradePop",
		Confetti = "Unbox_Confetti",
		Explode = "Glass_BreakShatter",
	},
	RevealFx = "FX_ShelfReveal", -- Assets/FX : émetteurs lancés au Reveal, aux couleurs de la rareté
	RevealEmit = 30, -- particules par émetteur (attribut EmitCount d'un émetteur, s'il y en a un, passe avant)

	-- Plafond du magasin (enfants facultatifs du magasin PNJ : Ceiling, CeilingFractured avec Shard_01…).
	Ceiling = {
		Attribute = "CeilingBroken", -- posé par le serveur sur le magasin (vrai pendant CeilingRepairSeconds)
		Name = "Ceiling",
		Fractured = "CeilingFractured",
		ShardPrefix = "Shard_",
		-- Plafond qui n'est qu'une pièce (greybox) : ces pièces du magasin (début du nom) sont cachées avec lui,
		-- sans quoi le toit reste au-dessus du trou. Un Ceiling en Model de Clément : rien d'autre n'est caché.
		GreyboxAlsoHide = { "RoofSlab", "CeilingLight_", "AC_" },
		-- Plafond cassé à l'écran sans CeilingBroken du serveur (attribut absent, ou pas encore arrivé) : remis au
		-- bout de LocalHold s.
		LocalHold = 8,
		-- Attribut arrivé avant la scène qui doit le casser : on attend son Explode, au plus PendingWait s (pas moins que
		-- MaxSeconds.Colossal : un serveur qui pose l'attribut dès RevealStarted ne fait pas disparaître le plafond avant).
		PendingWait = 10,
		ShardLife = 2.6, -- s avant l'effacement
		ShardFade = 0.5,
		Gravity = 70, -- studs/s²
		SpeedUp = { 18, 34 }, -- vitesse vers le haut, au départ
		SpeedOut = { 8, 22 }, -- vitesse vers l'extérieur, au départ
		Spin = 9, -- radians par seconde, au plus
		MaxShards = 40,
		LowEndShards = 8, -- appareil faible (ShatterController.IsLowEnd)
		-- Sans CeilingFractured : morceaux V0 de la couleur du plafond.
		V0Chunks = 16,
		V0ChunksLowEnd = 5,
		V0ChunkSize = { 1.2, 3.2 },
		Radius = 3, -- studs autour de l'objet, pour une taille 1 (× sa taille)
	},
}

export type Reveal = typeof(Reveal)

return DeepFreeze(Reveal)
