--!strict
-- Ouverture des colis v2 (UI-004, DEV-050, DEV-052 ; liaison L-046) : amélioration du colis,
-- séquence de révélation et rouleau. Spec : docs/claude/notes/ouverture-colis-spec.md, validée par
-- Clément le 2026-11-07 sur le prototype v5 (réglages par défaut). Lu par UnboxService (serveur :
-- amélioration, portée, annonce) et par UnboxController et ses modules d'aide (client : séquence).
--
-- Origine de chaque valeur, notée en commentaire :
--   spec  spec Clément 2026-11-07 (prototype v5) ;
--   V0    V0 proposé, absent de la spec et du doc, à régler en jeu.
-- Unités : secondes, studs ; probabilités de 0 à 1. Les temps sont comptés depuis UnboxReveal (le
-- serveur décide de l'amélioration et de l'objet à OpenBox, avant que la séquence commence).
--
-- Durées obtenues avec ces valeurs (spec, tableau « Durées obtenues ») : objet révélé à 4,9 s et
-- boutons à 6,7 s en version complète (Rare et plus), 3,0 s et 4,4 s en version courte (Commun et
-- Peu commun), +0,9 s par cran d'amélioration. Ouverture comptée au secours de 0,45 s (sans
-- marqueur Open).

local DeepFreeze = require(script.Parent.DeepFreeze)

-- Une durée qui dépend de la version : complète (Rare et plus) ou courte (Commun, Peu commun).
export type ByVersion = { Full: number, Short: number }

local Unbox = {
	-- 0. Amélioration du colis, tirée par le serveur à OpenBox -------------------------------
	UpgradeMax = 2, -- spec : 2 crans au plus
	UpgradeChance = 0.10, -- spec : chaque cran réussit à 10 % × chance du joueur ; 0 coupe la règle
	UpgradeStep = 0.9, -- spec : durée d'un cran
	UpgradeCharge = 0.5, -- spec : charge au début du cran (tremblement, lueur de la rareté suivante)
	UpgradeConfetti = 22, -- spec : confettis de chaque cran
	UpgradeShake = 0.2, -- V0 : amplitude (studs) du tremblement en fin de charge
	UpgradeGlow = 4, -- V0 : luminosité finale de la lueur (PointLight) en fin de charge
	UpgradeGlowRange = 10, -- V0 : portée (studs) de la lueur
	UpgradeGrow = 1.12, -- V0 : le colis grossit d'un coup de ce facteur à chaque cran
	UpgradePop = 0.2, -- V0 : apparition de Upgrade (échelle 0 → 1, Back Out)
	UpgradeAbove = 1.5, -- V0 : hauteur (studs) du point de Upgrade au-dessus du haut du colis
	UpgradeWave = 0.4, -- V0 : durée de l'onde
	UpgradeWaveScale = 4, -- V0 : l'onde finit à 4 fois la largeur du colis
	UpgradePitchStep = 0.12, -- V0 : Unbox_UpgradePop joué 12 % plus vite (plus aigu) à chaque cran
	UpgradeHop = 22, -- V0 : petit saut du perso à chaque cran (vitesse verticale en studs/s, ~1,2 stud de haut)

	-- 1. Ouverture ----------------------------------------------------------------------------
	OpenFallback = 0.45, -- spec : ouverture 0,45 s après le départ de Unbox s'il n'y a pas de marqueur Open
	OpenMarkerTimeout = 1.5, -- V0 : Unbox jouée mais marqueur Open jamais passé : on ouvre quand même
	BackdropFade = 0.3, -- V0 : fondu de Backdrop de 1 à sa valeur de Studio (version complète seulement)
	LidJump = 0.45, -- V0 : le couvercle (Lid) saute et s'efface
	LidHeight = 2.5, -- V0 : hauteur (studs) du saut du couvercle
	BeamHeight = 6, -- V0 : hauteur (studs) du faisceau de lumière qui sort du colis
	BeamGrow = 0.25, -- V0 : montée du faisceau

	-- 2 à 4. Rouleau --------------------------------------------------------------------------
	ReelExit = 0.4, -- spec : les objets sortent du colis
	ReelDuration = { Full = 3.2, Short = 1.3 } :: ByVersion, -- spec : défilement (T de rollPos)
	ReelCount = { Full = 24, Short = 10 } :: ByVersion, -- spec : objets qui défilent (L de rollPos)
	ReelLead = 3, -- spec : gagnant à l'index W = ReelLead + ReelCount (« W ≈ 3 + 24 »)
	ReelTail = 2, -- V0 : objets après le gagnant (on les voit arriver par le haut)
	ReelAccel = 0.25, -- spec : accélération (Ta de rollPos)
	ReelBrake = 4, -- spec : freinage (p de rollPos)
	ReelSpin = 0.15, -- spec : les objets tournent sur eux-mêmes (tours/s)
	NearMissChance = 0.40, -- spec : frôlement dans 40 % des cas
	NearMissStop = 0.45, -- spec : le rouleau hésite à 45 % d'un cran du gagnant (l'objet rare à moitié visible en bas)
	StopShort = 0.15, -- V0 : sans frôlement, l'arrêt tombe juste avant le centre
	LastNotch = 0.3, -- spec : dernier cran (Back Out) qui pose le gagnant au centre
	StopPause = 0.25, -- spec : pause à l'arrêt
	ColorIn = 0.3, -- spec : l'objet prend ses couleurs (ReelView.ImageColor3 du noir au blanc)
	SkipGlide = 0.4, -- spec : SkipButton amène le gagnant au centre
	-- Fenêtre du rouleau au-dessus du colis (liaison L-080) : placée à chaque image par la caméra.
	ReelAbove = 0.4, -- V0 : écart (studs) entre le haut du colis et le bas de la fenêtre Reel (ReelGlow compris)
	ReelEdge = 0.03, -- V0 : marge au bord de l'écran (part de son plus petit côté) quand le colis sort du champ
	ReelSlot = 2.4, -- V0 : hauteur (studs) d'une case dans ReelView
	ReelFit = 1.7, -- V0 : taille max (studs) d'un objet dans sa case
	ReelFov = 30, -- V0 : champ de vision (degrés) de la caméra fixe de ReelView
	TickMaxRate = 35, -- spec : Unbox_Tick 35 fois par seconde au plus
	TickPitchStep = 0.06, -- V0 : Unbox_Tick plus aigu de 6 % par cran de rareté de l'objet
	HeartbeatBelow = 3.5, -- spec : battement de cœur sous 3,5 objets/s (Rare et plus)
	HeartbeatEvery = 0.55, -- spec : un battement toutes les 0,55 s

	-- 5. Éclat --------------------------------------------------------------------------------
	FlashTime = 0.1, -- spec : Flash pendant 100 ms
	FlashPeak = 0, -- V0 : transparence de Flash au plus fort
	ItemMove = 0.45, -- spec : l'objet vient vers ItemPreview (InOut Cubic)
	ItemMoveScale = 1.3, -- spec : … et grossit ×1,3
	RaysGrow = 0.35, -- V0 : les rayons grandissent (Back Out), puis tournent
	RaysSpin = 0.06, -- spec : rotation des rayons (tours/s)
	RainbowSpin = 0.25, -- V0 : rotation (tours/s) des dégradés Rainbow du Secret
	ConfettiBurst = { Uncommon = 16, Rare = 30, Epic = 46, Legendary = 70, Mythic = 90, Secret = 120 }, -- spec
	ConfettiLife = 1.4, -- V0 : durée de vie (s) d'un confetti d'éclat
	ConfettiSpeed = 0.9, -- V0 : vitesse de départ d'un confetti (hauteurs d'écran par seconde)
	ConfettiGravity = 1.6, -- V0 : gravité (hauteurs d'écran par seconde²)
	RainCount = 60, -- V0 : confettis de la pluie plein écran (à partir d'Épique, spec)
	RainDuration = 2.5, -- V0 : durée de la pluie
	SlowMotionScale = 0.3, -- spec : ralenti ×0,3 du Secret…
	SlowMotionTime = 0.5, -- spec : … pendant 0,5 s

	-- 6. Textes -------------------------------------------------------------------------------
	-- V0 calé, absent de la spec : délai entre l'éclat et la rareté qui claque. Avec 0,27 s, le revenu
	-- démarre 0,57 s après l'éclat et les boutons tombent à 6,72 s et 4,37 s : les 6,7 s et 4,4 s du
	-- tableau de la spec, arrondis au dixième (aucune valeur unique ne donne les deux exactement).
	TextsAt = 0.27,
	RaritySlamFrom = 2.3, -- spec : Rarity claque de l'échelle 2,3…
	RaritySlam = 0.3, -- spec : … à 1, Back Out en 0,3 s
	ItemNameAfter = 0.18, -- spec : ItemName 0,18 s après Rarity
	IncomeAfter = 0.12, -- spec : Income 0,12 s après ItemName
	IncomeCount = { Full = 0.9, Short = 0.45 } :: ByVersion, -- spec : le revenu défile de 0 à sa valeur, courbe 1 − (1 − u)³
	CountTickEvery = 0.06, -- V0 : Unbox_CountTick pendant le comptage

	-- 7. Boutons ------------------------------------------------------------------------------
	ButtonsAfter = 0.35, -- spec : boutons 0,35 s après la fin du comptage
	ButtonsPop = 0.2, -- V0 : apparition des boutons (échelle, Back Out)
	AutoClose = 6, -- V0 : l'écran se ferme tout seul 6 s après l'apparition des boutons

	-- Portée (V0, absents du doc ; déplacés d'UnboxService et d'UnboxController, mêmes valeurs) --
	PromptDistance = 8, -- V0 : portée (studs) des invites (colis posé au sol, présentoir libre)
	ReachTolerance = 4, -- V0 : marge du serveur ; PlaceBox et OpenBox acceptés à 8 + 4 = 12 studs
	OpenNextMargin = 0.5, -- V0 : OpenNextButton n'apparaît qu'à 12 − 0,5 studs de l'autre colis au plus

	-- Colis dans l'inventaire et posés au sol de sa boutique (L-089 ; V0 proposés, absents du doc) --
	-- PlaceBox(boxUid, point) : le serveur cherche le sol sous le point visé, dans le volume Bounds de
	-- SA boutique, à PromptDistance + ReachTolerance studs au plus du personnage.
	FloorRayUp = 3, -- V0 : le rayon vers le sol part de cette hauteur (studs) au-dessus du bas de Bounds
	FloorTolerance = 0.5, -- V0 : écart (studs) permis entre le sol trouvé et le bas de Bounds (au-delà : pas le sol)
	FloorMinNormalY = 0.7, -- V0 : sol assez plat (composante verticale de la normale)
	BoxFootprint = Vector3.new(2, 2, 2), -- V0 : volume (studs) d'un colis posé, sans autre pièce solide dedans
	BoxSpacing = 3, -- V0 : écart (studs) au moins entre deux colis posés
	StandClearance = 2.5, -- V0 : écart (studs, à plat) au moins entre un colis posé et un présentoir
	EdgeMargin = 1, -- V0 : marge (studs) entre le colis et le bord de Bounds
	MaxPlacedBoxes = 8, -- V0 : colis posés au sol en même temps, au plus
	BoxInventoryMax = 50, -- V0 : colis dans l'inventaire, au plus (au-delà, le colis porté revole vers son rayon)

	-- Annonce à tout le serveur (5.7, étape 6 : Légendaire et plus, Rarities.Announce) -----------
	AnnounceKind = "Announce", -- V0 : catégorie du Notify envoyé aux autres joueurs
}

export type Unbox = typeof(Unbox)

return DeepFreeze(Unbox)
