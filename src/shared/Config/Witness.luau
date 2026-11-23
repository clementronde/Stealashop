--!strict
-- Témoins et police (idée de Clément, liaison L-111 ; animations d'UI T.50 à T.52 de
-- docs/claude/notes/ui-motion-skilltree.md). Lu par WitnessService (serveur : règle, balade, police) et
-- WitnessController (client : bulle BB_Witness). Sources :
--   « Clément » : la ligne L-111 de la liaison (valeurs et noms donnés par Clément) ;
--   « Note » : le tableau T.50 à T.52 de la note ;
--   « V0 » : V0 proposé, absent du doc.
-- Unités : secondes, studs ; échelles de UIScale (1 = taille de Clément) ; angles en degrés.

local DeepFreeze = require(script.Parent.DeepFreeze)

-- Un rôle de la foule (Crowd.Roles) : Sign = Side de la pancarte tenue ("For" ou "Against") ; Phone = le téléphone.
-- Vague 72 (a240, L-229) : Sounds = les sons du marqueur Shout de ce rôle (un au hasard).
export type CrowdRole = { Name: string, Anim: string, Weight: number, Sign: string?, Phone: boolean?, Sounds: { string }? }

local Witness = {
	-- Le « ? » -------------------------------------------------------------------------------------
	FillTime = 8, -- Clément : de vide à plein en 8 s à partir du premier coup ; plein, le témoin appelle
	EmptyTime = 1, -- V0 : vitrine cassée à temps, le « ? » se vide en ce temps (depuis plein), puis la balade reprend
	-- V0 : montée mise en pause par un autre service (WitnessService.Pause, pour L-112) : sans nouvelle
	-- montée au bout de ce temps, le « ? » se vide (un témoin ne reste jamais figé).
	PauseTimeout = 6,

	-- L'appel ---------------------------------------------------------------------------------------
	CallDuration = 4, -- V0 : le témoin reste au téléphone (CallPolice, « ! ») ce temps, puis reprend sa balade
	-- V0 : sans marqueur Call (animation pas encore chargée ou pas livrée), l'appel part quand même après
	-- ce délai (Clément a posé le marqueur à 0,4 s).
	CallMarkerMaxWait = 1,
	CallSound = "Witness_Call", -- V0 : nom du Sound dans ReplicatedStorage/Assets/Sounds ; absent : pas de son

	-- La balade -------------------------------------------------------------------------------------
	WalkSpeed = 6, -- V0 : WalkSpeed du témoin sur son circuit WitnessPaths
	WalkAnimSpeed = 10, -- vitesse au sol pour laquelle Walk est faite, à l'échelle 1 (la marche des vigiles, L-048)
	WalkAnimMin = 0.5, -- V0 : bornes de la vitesse de lecture de Walk
	WalkAnimMax = 1.6,
	PointReached = 2, -- V0 : distance horizontale à laquelle un point du circuit est atteint
	PauseChance = 0.25, -- V0 : à chaque point atteint, chance de s'arrêter (Idle)…
	PauseMin = 2, -- V0 : … entre PauseMin…
	PauseMax = 6, -- V0 : … et PauseMax s
	PauseClearance = 10, -- V0 proposé (a269, 22/11 ; a269g, Play f81f : pauses au bout d'un passage étroit ou devant l'autre témoin) : pas de pause sur un point qui touche un passage étroit (Avoid.Lanes) ni à moins de ce nombre de studs de l'autre témoin du circuit ; la pause est reportée au point suivant
	StuckTime = 3, -- V0 : sans avancer d'un stud pendant ce temps, il vise le point suivant
	MoveRefresh = 2, -- V0 : MoveTo redonné à ce rythme (Humanoid.MoveTo lâche au bout de 8 s)
	StepInterval = 0.1, -- V0 : cadence de la boucle serveur des témoins

	-- a269 (Cantin, 20/11 : « les PNJ dans les zones arrêtent de se rentrer dedans ») : deux PNJ qui marchent et se
	-- croisent (témoins en balade ; vigiles en ronde, en retour ou qui gardent un objet tombé, jamais en poursuite)
	-- s'écartent chacun sur leur droite, passent côte à côte et reviennent sur leur circuit (Services/Npc/NpcAvoid) ; en
	-- filet, les témoins ne heurtent plus ni un autre témoin ni un vigile (groupe de collision). Les joueurs restent
	-- bloqués par les PNJ comme avant. Enabled = false : comme avant (ni écart ni groupe).
	Avoid = {
		Enabled = true, -- V0 proposé (a269, 20/11)
		Detect = 8, -- V0 proposé (a269, 20/11) : un PNJ devant lui à ce nombre de studs ou moins (à plat)…
		Gap = 3, -- V0 proposé (a269, 20/11) : … à moins de Gap studs de sa ligne : il passe avec lui à Gap studs sur sa gauche
		Look = 3, -- V0 proposé (a269, 20/11) : pendant l'écart, il vise ce nombre de studs devant lui (plus petit : écart plus vif)
		PassBehind = 1.5, -- V0 proposé (a269, 20/11) : l'écart finit quand l'autre est ce nombre de studs derrière lui
		MinClosing = 1, -- V0 proposé (a269, 20/11) : studs/s ; un PNJ dont il ne se rapproche pas (même sens, même pas) n'est pas évité
		MaxRise = 6, -- V0 proposé (a269, 20/11) : au plus ce nombre de studs d'écart en hauteur (un autre étage n'est pas évité)
		PointReach = 5, -- V0 proposé (a269, 20/11) : témoin qui s'écarte : point atteint à ce nombre de studs (plus utilisé depuis a269c : témoins sans écart)
		Guards = true, -- V0 proposé (a269, 20/11) : les vigiles s'écartent aussi (ronde, retour, Follow)
		NoCollide = true, -- V0 proposé (a269, 20/11) : les témoins ne heurtent ni un autre témoin ni un vigile (groupe Guards)
		Group = "Witnesses", -- V0 proposé (a269, 20/11) : groupe de collision des témoins, créé par le code en jeu (pas un nom du contrat)
		-- a269b (Play fusion81, 21/11) : poteaux près du circuit, témoin en pause frôlé, joueur qui traverse un témoin.
		StillSpeed = 0.5, -- V0 proposé (a269, 21/11) : studs/s ; plus lent : PNJ arrêté, évité du côté où il n'est pas, même à côté de soi
		Clearance = 1.1, -- V0 proposé (a269, 21/11) : rayon (studs) du corps balayé vers le point visé : un poteau dedans réduit l'écart
		LowDrop = 1.2, -- V0 proposé (a269, 21/11) : second balayage ce nombre de studs plus bas (bornes, bancs bas)
		StuckTime = 0.5, -- V0 proposé (a269, 21/11) : s ; pendant un écart, sans avancer de StuckMove studs : il l'abandonne et vise son point…
		StuckMove = 1, -- V0 proposé (a269, 21/11) : … (studs)
		RetryAfter = 2, -- V0 proposé (a269, 21/11) : s sans s'écarter à nouveau du même PNJ après un écart abandonné
		Players = false, -- V0 proposé (a269, 22/11 ; true au 21/11) : true, un témoin s'arrête devant un joueur qui vient sur sa ligne (Play f81b : il attendait sans fin derrière un joueur immobile)…
		PlayerStop = 10, -- V0 proposé (a269, 21/11) : … à ce nombre de studs devant lui ou moins…
		PlayerLane = 2.5, -- V0 proposé (a269, 21/11) : … et à moins de ce nombre de studs de sa ligne
		-- a269c (Play f81b, 22/11) : plus d'écart dynamique pour les témoins (gardé pour les vigiles) ; chaque témoin marche
		-- sur SA voie, son circuit décalé sur sa droite (Services/Npc/WitnessLanes), et se dégage s'il est bloqué.
		Lanes = true, -- V0 proposé (a269, 22/11) : false, les témoins marchent sur le circuit même (sans écart)
		Lane = 1.5, -- V0 proposé (a269, 22/11) : décalage (studs) de sa voie sur sa droite : deux témoins à 2 × Lane l'un de l'autre
		LaneClearance = 1.2, -- V0 proposé (a269, 22/11) : rayon (studs) du corps balayé le long de chaque segment de voie
		LaneLowDrop = 0.8, -- V0 proposé (a269, 22/11) : second balayage ce nombre de studs plus bas (bornes basses)
		LaneStep = 0.25, -- V0 proposé (a269, 22/11) : pas (studs) des décalages essayés quand un segment est bouché…
		LaneMax = 4, -- V0 proposé (a269, 22/11) : … jusqu'à ce décalage (studs), d'un côté ou de l'autre
		LaneReach = 0.5, -- V0 proposé (a269, 22/11 ; 1 à a269c) : point de la voie atteint à ce nombre de studs (au lieu de PointReached : il coupe moins les virages ; a269d : à 1 stud, le raccourci frôlait encore les poteaux)
		LaneOvershoot = 1, -- V0 proposé (a269, 22/11) : il vise ce nombre de studs au-delà du point de voie (a269e, Play f81d : Humanoid.MoveTo s'arrête vers 0,9 stud avant son but ; il passe donc sur le point et enchaîne sans arrêt)
		UnstickTime = 1, -- V0 proposé (a269, 22/11) : s ; sans avancer de UnstickMove studs : il va à un point libre à côté de lui…
		UnstickMove = 1, -- V0 proposé (a269, 22/11) : … (studs)…
		UnstickSide = 2.5, -- V0 proposé (a269, 22/11) : … à ce nombre de studs sur sa droite, sinon sur sa gauche (a269d : d'où il voit son point visé, sinon son point d'avant), puis reprend le même point (le suivant au second échec)
		-- a269d (Play f81c, 22/11) : poteaux sans collision, renfoncements, passages étroits.
		LaneVisibleMax = 0.5, -- V0 proposé (a269, 22/11) : une pièce de la map sans collision compte comme obstacle des voies si sa Transparency est au plus ceci
		LaneLeash = 2, -- V0 proposé (a269, 22/11) : à plus de LaneMax + ceci studs de sa voie, il revient au point le plus proche de sa voie
		NarrowWait = 8, -- V0 proposé (a269, 22/11) : s au plus d'attente à l'entrée d'un passage étroit (voies à moins de 2 × Lane − LaneStep studs) où est l'autre témoin
		-- a269e (Play f81d, 22/11) : point jamais atteint, passage gardé sans fin.
		LaneGoalSlack = 4, -- V0 proposé (a269, 22/11) : s ; sur un même point de voie plus de (segment / WalkSpeed + ceci) s, quoi qu'il arrive : il passe au suivant
		NarrowHold = 6, -- V0 proposé (a269, 22/11) : s ; un témoin garde un passage étroit au plus (longueur / WalkSpeed + ceci) s, puis le libère
		-- a269f (Play f81e, 22/11) : segment encore bouché (zone 6), attente trop près de celui qui passe (zone 1).
		LaneDetourMax = 8, -- V0 proposé (a269, 22/11) : studs ; un segment de voie encore bouché est contourné en déplaçant ses points jusqu'à ce nombre de studs (au-delà de LaneMax), ou en retirant l'un d'eux
		NarrowStandOff = 2, -- V0 proposé (a269, 22/11) : studs ; passage étroit occupé par l'autre témoin : il attend à ce nombre de studs avant l'entrée (au lieu de l'entrée même), loin de la voie de celui qui sort
		-- a269g (Play f81f, 22/11) : « Script timeout » au démarrage, épingle au coin de la zone 1, détours sur la chaussée.
		LaneStepQueries = 1500, -- V0 proposé (a269, 22/11 ; 200 à a269g) : plafond de sûreté ; le calcul des voies (hors du démarrage, une zone après l'autre) rend la main (task.wait) au moins toutes les ce nombre de requêtes…
		LaneStepBudget = 0.01, -- V0 proposé (a269, 22/11 ; 0,004 à a269g) : … ou toutes les ce nombre de secondes de calcul (a269h, Play f81g : la vraie coupe ; moins de morceaux, chacun attend une image)
		LaneTurnMax = 120, -- V0 proposé (a269, 22/11) : degrés ; un virage de voie plus serré (pas sur le circuit même) est refusé pour un détour et lissé ailleurs
		LaneCurbSlack = 2, -- V0 proposé (a269, 22/11) : studs ; un détour qui ne va pas plus vers la rue que le point de voie d'avant est préféré s'il n'est pas plus long que le plus court de plus de ceci (et ne rapproche pas les deux voies)
		-- a269h (Play f81g : les 12 témoins figés 4,7 à 11,4 s en Walk, une fois, cause inconnue) : rattrapage.
		WalkRetry = 2, -- V0 proposé (a269, 22/11) : s ; en marche sans bouger de WalkRetryMove studs depuis ce temps, il redonne son MoveTo (une ligne dans la sortie au 3e témoin du même épisode ; rien si Enabled est coupé)
		WalkRetryMove = 0.25, -- V0 proposé (a269, 22/11) : … (studs)
	},

	-- La fuite à la casse (Clément, L-118 point 10 : il a peur, court à l'opposé de la vitrine, puis reprend
	-- sa balade plus loin ; animation Flee, sinon Walk accélérée) -----------------------------------------
	FleeSpeed = 16, -- V0 : WalkSpeed pendant la fuite
	FleeDistance = 30, -- V0 : il court jusqu'à ce point, à l'opposé de la vitrine (studs)…
	FleeMaxTime = 4, -- V0 : … au plus ce temps…
	FleeStuckTime = 1, -- V0 : … ou jusqu'à rester ce temps sans avancer d'un stud (un mur)

	-- Le témoin qui filme la casse (Clément, L-172, 2026-11-15) : au premier coup il s'approche de la vitrine
	-- (Walk) pendant que son « ? » monte, puis il appelle (CallPolice) et, l'appel fini, il prend des photos
	-- au flash (TakePhoto, marqueur Flash ; effet FX_Witness_Flash côté client) jusqu'à l'arrivée du policier
	-- ou au départ du voleur, puis reprend sa balade. -----------------------------------------------------
	Photo = {
		-- V0 : false = l'ancien déroulé (il regarde sur place, reprend sa balade après l'appel).
		Enabled = true,
		Distance = 8, -- V0 : il se poste à ce nombre de studs devant la vitrine…
		SideOffset = 2, -- V0 : … décalé de ce nombre de studs sur le côté (témoin impair à droite, pair à gauche)
		ApproachSpeed = 10, -- V0 : WalkSpeed pendant qu'il s'approche (il presse le pas)
		-- Vague 60 (a196, Cantin, T-087) : loin, il va plus vite, pour être à son poste ApproachLead s avant que son
		-- « ? » soit plein (vitesse = distance / temps restant, revue à chaque MoveTo) ; jamais moins
		-- qu'ApproachSpeed ni plus qu'ApproachMaxSpeed (V0).
		ApproachLead = 1,
		ApproachMaxSpeed = 32,
		-- Vague 66 (a221, Clément, L-210 point 4 : « il doit foncer sur le joueur dès le premier coup, arriver vite et
		-- photographier avec flash »). Avant, le flash ne partait qu'après le « ? » plein (8 s) et l'appel (4 s) : un
		-- joueur seul casse la vitre en 6,5 s (Balance.WindowHP.SoloBreakTime), le témoin fuyait avant son premier flash.
		-- Rush = true : il court à son poste à RushSpeed au moins (animation RushAnim, sinon Walk accélérée) et, arrivé,
		-- prend ses photos tout de suite (TakePhoto, flash) pendant que son « ? » monte ; « ? » plein : l'appel, puis les
		-- photos comme avant. La casse le fait toujours fuir (L-118 point 10). false = l'approche d'a196 et Look à l'arrivée.
		Rush = true, -- V0
		RushSpeed = 24, -- V0 : WalkSpeed de la course (jamais plus qu'ApproachMaxSpeed)
		RushAnim = "Flee", -- V0 : la course de Clément (Contract/Animations.Witness) ; absente : Walk accélérée
		-- f70c2 (Cantin, 18/11 : il « passe de son animation de course à une animation posée devant la boutique sans que ce
		-- soit fluide ») : il freine sur les derniers studs, la course s'efface en fondu pendant que la pose (TakePhoto, ou
		-- Look) arrive en fondu, et il se tourne vers la vitrine en douceur. Avant : arrêt net vers 24 studs/s, quart de tour
		-- en une image, fondus de 0,1 s (ceux de Roblox).
		BrakeDistance = 6, -- V0 : studs avant son poste où il commence à freiner (vitesse proportionnelle à la distance)…
		BrakeMinSpeed = 4, -- V0 : … sans descendre sous cette vitesse (studs/s)
		BrakeAnimMin = 0.4, -- V0 : vitesse de lecture la plus basse de la course (RushAnim) pendant le freinage
		ArriveDistance = 1, -- V0 : à ce nombre de studs de son poste, il est arrivé (avant : Witness.PointReached, 2)
		StopFade = 0.35, -- V0 : s, fondu de sortie de la course (ou de la marche) à l'arrivée
		PoseFade = 0.35, -- V0 : s, fondu d'entrée de TakePhoto (ou de Look) à l'arrivée
		TurnTime = 0.4, -- V0 : s, il se tourne vers la vitrine en ce temps (0 : d'un coup, comme avant)
		-- V0 (a196, T-087 : « le flash se voit mal ») : chaque flash émet Bursts fois, à BurstGap s d'écart (la lumière
		-- reste allumée jusqu'au dernier) ; l'effet de Clément (EmitCount, LightTime) n'est pas touché.
		Bursts = 2,
		BurstGap = 0.08,
		Interval = 0.9, -- Clément : un flash toutes les 0,9 s environ (rythme tant qu'aucun marqueur Flash ne vient)
		MinInterval = 0.45, -- Clément : jamais plus d'un flash toutes les 0,45 s (le reflet dure 0,2 s)
		PoliceArrive = 15, -- V0 : un policier du magasin à moins de ce nombre de studs de la vitrine : il arrête
		LeaveDistance = 40, -- V0 : plus aucun voleur (dehors, vivant) à moins de ce nombre de studs de la vitrine : il arrête
		MaxTime = 20, -- V0 : il filme au plus ce temps
		Sound = "Witness_Photo", -- V0 : Sound de ReplicatedStorage/Assets/Sounds, joué à chaque flash ; absent : pas de son
		-- Clément (L-172) : l'effet, joué par le client. Les enfants de l'Attachment FxSource de Fx sont copiés une
		-- fois par témoin dans l'Attachment PhonePoint du Handle de son téléphone (le flash part du téléphone).
		Fx = "FX_Witness_Flash",
		FxFolder = { "Assets", "FX" }, -- depuis ReplicatedStorage
		FxSource = "Flash",
		Phone = "ACC_Temoin_Telephone",
		PhonePart = "Handle",
		PhonePoint = "FlashPoint",
		-- Repli sans FlashPoint : Forward stud devant le témoin, au Handle ; sans téléphone : à la main droite.
		Forward = 0.4,
		Hand = "RightHand",
		CodePoint = "WitnessFlashPoint", -- V0 : nom de l'Attachment que le code crée pour ce repli (chez le joueur)
	},

	-- La foule qui filme (vague 66, a221, Clément, L-210 point 4 ; proposition à valider par Clément, tout en V0) : quand un
	-- voleur sort d'un magasin PNJ avec l'objet sur la tête (attribut Carrying, il quitte le volume Bounds), une petite
	-- foule apparaît devant la vitrine, tournée vers lui (a288 : dès l'entrée dans le magasin, Crowd.Trigger), créée et
	-- jouée par chaque client seul (WitnessCrowdController) :
	-- aucun remote, rien sur le serveur. Interrupteur : Features.WitnessCrowd.
	--
	-- Vague 71 (a236 ; Clément, L-219 point 1, L-220 point 2, L-223) : les personnes viennent de
	-- ReplicatedStorage/Assets/Crowd/Models/NPC_Crowd_* (repli : les copies des témoins d'avant), chacune avec un rôle
	-- (Roles) et l'accessoire de ce rôle (Assets/Crowd/Props) ; rangées des deux côtés du passage qui part de la vitrine
	-- (personne devant la vitrine, ni tapis ni barrière), plus serrées en s'éloignant ; aucune collision.
	Crowd = {
		Models = { "Assets", "Crowd", "Models" }, -- Clément (L-223), depuis ReplicatedStorage
		ModelPrefix = "NPC_Crowd_", -- Clément : NPC_Crowd_01 à _12 ; aucun : les copies des témoins NPC_Witness_*
		Props = { "Assets", "Crowd", "Props" }, -- Clément : accessoires de rôle (Humanoid:AddAccessory)
		SideAttribute = "Side", -- Clément : attribut des pancartes, "For" ou "Against"
		-- Rôles (Clément, L-223) tirés au hasard selon Weight (V0) : pour le voleur (Cheer, ou HoldSign + pancarte For),
		-- contre (Boo, ou HoldSign + pancarte Against), crieur (Shout), photographe (TakePhoto + ACC_Temoin_Telephone,
		-- flash à chaque marqueur Flash). Une personne qui n'a pas l'animation (ou la pancarte) de son rôle devient
		-- photographe ; sans TakePhoto non plus : pose de repos.
		Roles = {
			{ Name = "Cheer", Anim = "Cheer", Weight = 2, Sounds = { "Crowd_Cheer", "Crowd_Clap" } }, -- sons : Clément (L-229)
			{ Name = "SignFor", Anim = "HoldSign", Sign = "For", Weight = 1 },
			{ Name = "Boo", Anim = "Boo", Weight = 2, Sounds = { "Crowd_Boo" } },
			{ Name = "SignAgainst", Anim = "HoldSign", Sign = "Against", Weight = 1 },
			{ Name = "Shouter", Anim = "Shout", Weight = 2, Sounds = { "Crowd_Shout", "Crowd_Scream" } },
			{ Name = "Photographer", Anim = "TakePhoto", Phone = true, Weight = 3 },
		} :: { CrowdRole },
		Photographer = "Photographer", -- le rôle de repli (Roles)
		ShoutMarker = "Shout", -- Clément (L-223) : le cri, pour le son de foule à venir (WitnessCrowdController.OnShout)
		PerSide = 12, -- V0 : personnes de chaque côté du passage (Clément : au moins 10)…
		PerSideLow = 10, -- V0 : … sur appareil faible (ShatterController.IsLowEnd), jamais moins de 10
		Start = 2, -- V0 : studs devant la vitrine, la première personne de chaque côté…
		Length = 34, -- V0 : … la dernière à Start + Length studs (la rue fait environ 105 studs entre façades, L-226)
		Spread = 0.6, -- V0 : < 1 = plus serrés en s'éloignant (place k sur n : Start + Length × (k − 0,5) / n ^ Spread)
		PassageMin = 8, -- V0 : largeur du passage (studs) au moins…
		PassageMax = 24, -- V0 : … et au plus ; entre les deux : largeur de la vitrine + 2 × PassageMargin
		PassageMargin = 1, -- V0 : studs
		RowGap = 2.5, -- V0 : une personne sur deux un rang derrière (studs), en quinconce
		Jitter = 0.6, -- V0 : studs de hasard sur chaque place
		-- a269 (Cantin, 20/11 : « les PNJ arrêtent de se rentrer dedans ») : deux personnes de la foule jamais plus proches
		-- que leur largeur réelle (la plus grande empreinte au sol, X ou Z de GetExtentsSize, des modèles tirés) + Margin.
		-- Une place trop proche d'une autre personne (de cette foule ou d'une foule voisine), d'un témoin ou du circuit
		-- WitnessPaths de sa zone recule par pas de Step studs vers la rue, ou un rang derrière, jusqu'à MaxPush studs ;
		-- au-delà, elle reste vide. Enabled = false : les places d'avant (WitnessCrowdController.spots).
		Spacing = {
			Enabled = true, -- V0 proposé (a269, 20/11)
			Margin = 0.5, -- V0 proposé (a269, 20/11) : studs libres entre deux personnes, en plus de leur largeur
			WidthFallback = 4, -- V0 proposé (a269, 20/11) : largeur d'une personne (R15, bras compris) si le modèle ne la donne pas
			WidthMax = 6, -- V0 proposé (a269, 20/11) : largeur comptée au plus (un accessoire très large ne vide pas la rue)
			Step = 0.5, -- V0 proposé (a269, 20/11) : recul d'une place trop proche (studs)
			MaxPush = 20, -- V0 proposé (a269, 20/11) : recul au plus (studs) ; au-delà, la place reste vide
			Witnesses = true, -- V0 proposé (a269, 20/11) : places loin des témoins et de leur circuit, vus chez ce joueur
		},
		-- a288 (Cantin, 21/11 : « la foule apparaît trop tard, elle va apparaître dès qu'on rentre dans le magasin ») :
		-- "Enter" = la foule se forme dès qu'un joueur entre dans le volume Bounds d'un magasin PNJ ouvert (vitrine
		-- cassée : attribut HeistOpen du magasin, posé par StoreHeistService), avec ou sans objet ; elle reste tant
		-- qu'un joueur est dans Bounds (au plus MaxStay s), puis Duration s après la sortie du dernier, et s'efface.
		-- "Exit" = l'ancien moment (L-210 point 4) : à la sortie de Bounds avec l'objet (Carrying), pour Duration s.
		-- a289 (Cantin, 21/11 : « elle disparaît quand le vol est fini cad quand l'item est ramené ») : avec "Enter", un
		-- joueur qui prend un objet dans ce magasin (attribut Carrying du Player, posé par CarryService et vu par tous les
		-- clients, absent à son entrée dans Bounds, présent pendant qu'il y est ou à sa sortie) en est le voleur : la
		-- foule reste, même voleur loin du magasin, tant qu'il porte, puis s'efface dès que Carrying disparaît, c'est-à-
		-- dire quand le vol se termine : objet déposé chez lui (rangé à l'entrée de la zone safe ou exposé), ou vol raté
		-- (attrapé, objet tombé, volé par un autre joueur, mort, départ du jeu) : validé par Cantin, 21/11.
		-- À la sortie, la foule suit le voleur des yeux, comme a288 : validé par Cantin, 21/11.
		-- V0 proposé (a289, 21/11) : un joueur entré et ressorti sans prendre d'objet (ou entré en portant déjà un objet
		-- venu d'ailleurs) n'est pas un voleur de ce magasin : sans vol, la foule part Duration s après la sortie du
		-- dernier joueur, comme a288 ; après un vol fini, elle part dès que plus personne ne la retient (voleur qui
		-- porte encore, autre joueur dans Bounds), sans attendre Duration.
		Trigger = "Enter", -- Cantin (21/11)
		-- s : filet seulement, une foule formée à l'entrée part au plus tard ce temps après sa formation, même vol en
		-- cours (a288 : 60) : validé par Cantin, 21/11
		MaxStay = 300,
		Duration = 6, -- V0 : s, puis ils s'effacent ("Enter" : après la sortie du dernier joueur, sans vol ; "Exit" : après la formation)
		FadeTime = 0.3, -- V0 : s, apparition et disparition (LocalTransparencyModifier) ; animations réduites : d'un coup
		FlashMin = 0.7, -- V0 : rythme des flashs sans marqueur Flash (s, au hasard entre les deux)…
		FlashMax = 1.5, -- V0 : … ; avec TakePhoto, ses marqueurs Flash donnent le rythme
		-- a293 (Cantin, 21/11) : voleur attrapé dans la rue, la foule part tout de suite et ne revient pas ; attrapé
		-- dans le magasin, elle part tout de suite aussi, et une nouvelle foule de ce magasin ne se forme qu'une fois
		-- Cooldown passé depuis sa fin, à la prochaine entrée d'un joueur dans Bounds (le voleur attrapé qui ressort
		-- les mains vides n'en forme pas : seule une sortie en portant un objet en forme une) : validé par Cantin, 21/11.
		Cooldown = 15, -- s, pas deux foules pour un même magasin dans ce temps (a288, "Enter" : compté depuis la fin de la foule) : validé par Cantin, 21/11
		MaxCrowds = 2, -- foules à la fois chez un joueur (validé par Cantin, 21/11)…
		MaxCrowdsLow = 1, -- V0 : … sur appareil faible
		AtNight = false, -- V0 : comme avant (la nuit, plus de témoins, donc plus de foule) ; à valider par Clément
		ViewDistance = 220, -- V0 : studs ; voleur plus loin de la caméra : pas de foule…
		ViewDistanceLow = 120, -- V0 proposé (Cantin, 23/11) : … sur appareil faible (audit a271 point 1c)
		-- Vague GC3 (a281, audit a271 points 1a et 1b) : le coût des personnes qu'on ne voit pas. Revu au pas de
		-- TurnInterval : une personne hors de l'écran (sphère de Radius studs autour de sa racine hors du champ de la
		-- caméra) ou à plus de AnimDistance studs de la caméra a son animation en pause (elle garde sa pose et sa phase)
		-- et repart à son rythme dès qu'elle revient en vue ; seules les personnes à l'écran se tournent vers le voleur.
		-- Enabled = false : comme avant (toutes animées et tournées).
		Cull = {
			Enabled = true, -- V0 proposé (Cantin, 23/11)
			AnimDistance = 80, -- V0 proposé (Cantin, 23/11) : studs ; plus loin de la caméra, animation en pause
			Radius = 5, -- V0 proposé (Cantin, 23/11) : studs autour de la racine (une personne R15, pancarte levée comprise)
		},
		CheckInterval = 0.2, -- V0 : s, contrôle des porteurs
		TurnInterval = 0.1, -- V0 : s, la foule se tourne vers le voleur…
		TurnIntervalLow = 0.3, -- V0 : … sur appareil faible
		Folder = "WitnessCrowd", -- V0 : dossier du Workspace (chez le joueur seul) qui range les copies
		-- Vague 72 (a240) : la foule n'est plus créée en une seule image (mesuré en Play, fusion65 : 140 à 485 ms d'arrêt
		-- à sa formation) ; à chaque image, au plus BuildPerFrame personnes, et plus aucune une fois BuildBudget s
		-- dépensées (au moins une par image). Chaque personne fait son propre fondu d'entrée ; rien ne change à la fin.
		BuildPerFrame = 3, -- V0
		BuildBudget = 0.004, -- V0 : s par image
		-- Vague 72 (a240, Clément, L-229) : les sons de la foule, 3D sur la personne (Assets/Sounds, MarkerSounds.find ;
		-- absent : muet). Cris au marqueur Shout (Roles[].Sounds), photo au flash, Gasp à la casse d'une vitrine de magasin
		-- PNJ. Jamais relancé sur une personne tant que son son précédent joue.
		Sounds = {
			Enabled = true, -- V0
			Voices = 3, -- V0 : cris de foule (Cheer, Boo, Shout…) joués à la fois chez ce joueur, au plus
			PhotoVoices = 2, -- V0 : sons de photo joués à la fois, au plus
			Photo = "Witness_Photo", -- Clément (L-229) : à chaque flash d'un photographe…
			Burst = "Crowd_PhotoBurst", -- Clément : … parfois la rafale à la place…
			BurstChance = 0.2, -- V0 : … avec cette chance
			Gasp = "Crowd_Gasp", -- Clément : une fois à la casse de la vitrine (3D sur la vitrine)
		},
	},

	-- La police -------------------------------------------------------------------------------------
	Police = {
		Template = "NPC_Police", -- Clément : ReplicatedStorage/Assets/Guards/NPC_Police
		CloneName = "NPC_Police_Z%d", -- V0 : nom de la copie en jeu (zone)
		-- V0 : sa vitesse = celle du vigile de jour de la zone (Zones[zone].GuardSpeed, ou celle du tutoriel
		-- pour un joueur en tutoriel) × ce facteur. À la vitesse conseillée de la zone, on la sème.
		SpeedFactor = 1,
		-- V0 : il poursuit au plus ce temps, puis s'essouffle (Tired) et s'efface. Il s'arrête aussi à la
		-- capture et quand sa cible entre en zone safe (règles des vigiles). Il entre dans le magasin comme
		-- un vigile (même calcul de chemin) si la vitrine finit par casser.
		ChaseDuration = 30,
		-- V0 : il arrive « du bout de la rue » : le point du circuit WitnessPaths de la zone le plus loin
		-- de la vitrine. Zone sans circuit : à côté du témoin qui appelle.
		-- Vague 43 (Cantin, 2026-11-14) : un policier par joueur qui a frappé la vitrine pendant ce braquage
		-- (avant : un seul, sur le dernier à avoir frappé). V0 : au plus ce nombre de policiers en jeu à la
		-- fois pour un magasin (les derniers à avoir frappé d'abord).
		MaxPerStore = 4,
		-- V0 : écart entre les policiers d'un même appel à l'apparition (studs), côte à côte.
		SpawnSpacing = 3,
	},

	-- Messages (Notify), en anglais. V0 : textes à valider par Clément.
	Messages = {
		Called = "A witness called the police! Run!",
		Caught = "Busted! The police caught you.",
	},

	-- La bulle (client) -----------------------------------------------------------------------------
	Billboard = "BB_Witness", -- Clément : ReplicatedStorage/Assets/UI/BB_Witness
	BillboardFolder = { "Assets", "UI" }, -- depuis ReplicatedStorage
	HeadAttachment = "WitnessHead", -- Clément : Attachment de la bulle ; absent : au-dessus de la Head
	-- Clément : couleur du « ? » (Fill.FillMark.TextColor3) selon le remplissage.
	Colors = {
		{ From = 0, Color = Color3.fromHex("FFD84A") }, -- jaune
		{ From = 0.5, Color = Color3.fromHex("FF8C1A") }, -- orange dès 50 %
		{ From = 0.8, Color = Color3.fromHex("E8413C") }, -- rouge dès 80 %
	},
	Motion = {
		-- T.50 WitnessFill : à chaque changement de couleur, Mark 1,1 → 1 en 0,15 (Back Out).
		StagePopFrom = 1.1,
		StagePopTime = 0.15,
		-- T.51 WitnessAlert : Alert 0 → 1,3 en 0,12 (Back Out), puis 1 en 0,1 (Quad Out) ; tremblement de
		-- ± 8°, 4 allers-retours en 0,3.
		AlertPopTo = 1.3,
		AlertPopTime = 0.12,
		AlertSettleTime = 0.1,
		AlertShakeAngle = 8,
		AlertShakeCount = 4,
		AlertShakeTime = 0.3,
		-- T.52 WitnessCall : Alert bat de 1 à 1,12, 2 fois par seconde ; PhoneIcon sonne : ± 12° autour de
		-- −12°, 6 fois par seconde (sinus), jusqu'à la fin de l'appel.
		CallPulseTo = 1.12,
		CallPulseRate = 2,
		PhoneAngle = -12,
		PhoneSwing = 12,
		PhoneRate = 6,
		ScaleName = "WitnessScale", -- V0 : UIScale posé par le code sur Mark et Alert de la copie
	},
}

export type Witness = typeof(Witness)

return DeepFreeze(Witness)
