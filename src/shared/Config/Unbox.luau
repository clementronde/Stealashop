--!strict
-- Réglages des colis (UI-004, DEV-050 ; liaison L-046, L-089, L-236). Lu par UnboxService (serveur : amélioration du
-- colis offert, portée, colis posés au sol), InventoryService, StoreHeistService (annonces, nouvelle ouverture),
-- UnboxPlan et Announce, et côté client par UnboxController, InventoryController, DisplayController, RevealController
-- et Controllers/Reveal/Unbox (la nouvelle ouverture, table New).
-- a437 (lot 3 du check-up a417, R7) : les réglages de l'ancienne ouverture v2 (rouleau, couvercle, faisceau, confettis,
-- ralenti, textes et boutons) sont retirés : plus rien ne les lisait depuis la nouvelle ouverture (vague 73, New).
--
-- Origine de chaque valeur, notée en commentaire :
--   spec  spec Clément 2026-11-07 (prototype v5) ;
--   V0    V0 proposé, absent de la spec et du doc, à régler en jeu.
-- Unités : secondes, studs ; probabilités de 0 à 1.

local DeepFreeze = require(script.Parent.DeepFreeze)

-- Une action de la nouvelle ouverture (New.Actions, vague 73).
export type Action = {
	Id: string,
	Anim: string,
	Tool: string?,
	Fx: string?,
	RunFx: string?,
	Sound: string?,
	React: string,
	Duration: number,
	Impacts: { number },
	Junk: boolean?,
	Mark: boolean?,
}

-- Vague 75 (a259, L-261) : les sons d'une action (New.Sounds.Actions). Start : joués au lancement, l'un après l'autre
-- (le suivant à la fin du précédent) ; Top : au marqueur Top (en repli : à TopAt × la durée) ; Impacts : au 1er Impact,
-- au 2e…, le dernier pour les suivants ; Stop : les sons de Start arrêtés en fondu au 1er Impact (« Impact ») ou à la fin
-- de l'action (« End » ; sans Stop : ils finissent seuls) ; Smoke = false : pas de Unbox_Smoke aux Impacts.
export type ActionSounds = {
	Start: { string }?,
	Top: string?,
	TopAt: number?,
	Impacts: { string }?,
	Stop: string?,
	Smoke: boolean?,
}

local Unbox = {
	-- Amélioration du colis, tirée par le serveur (UnboxService : colis offert ; UnboxPlan : nouvelle ouverture) --
	UpgradeMax = 2, -- spec : 2 crans au plus
	UpgradeChance = 0.10, -- spec : chaque cran réussit à 10 % × chance du joueur ; 0 coupe la règle

	-- Portée (V0, absents du doc ; déplacés d'UnboxService et d'UnboxController, mêmes valeurs) --
	PromptDistance = 8, -- V0 : portée (studs) des invites (colis posé au sol, présentoir libre)
	ReachTolerance = 4, -- V0 : marge du serveur ; PlaceBox et OpenBox acceptés à 8 + 4 = 12 studs

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
	-- a432 (Cantin, 24/11 : « plus de carré ») : pendant la pose d'un objet sous antivol, aucun aperçu au sol (le
	-- fantôme BoxGhost d'InventoryController) ; un clic, un appui ou R2 pose au point visé, le serveur revérifie tout
	-- (PlaceBox) et répond par un Notify « Warning » (toast et son UI_Deny) en cas de refus.
	PlaceGhost = false, -- V0 proposé (Cantin, 24/11) : interrupteur ; true = l'aperçu vert ou rouge d'avant

	-- Annonce à tout le serveur (5.7, étape 6 : Légendaire et plus, Rarities.Announce) -----------
	AnnounceKind = "Announce", -- V0 : catégorie du Notify envoyé aux autres joueurs
	-- Vague 71 (a239, L-216 point 4) : annonce à tout le serveur quand un colis de NightBoxMinRarity ou plus APPARAÎT
	-- sur un rayon la nuit (StoreHeistService : remplissage de la nuit, ou magasin rempli à sa fermeture pendant la
	-- nuit), avec le même Notify (AnnounceKind). Les colis apparus en NightBoxGroupDelay s partent en une seule
	-- annonce (pas de rafale). Rayons d'événement exclus. Textes en anglais : {rarity} = la plus rare (capitales),
	-- {store} = son magasin (Config/Zones.Stores, sinon « Zone N »), {count} = nombre de colis. Tout V0.
	NightBoxAnnounce = true, -- interrupteur ; false = aucune annonce (comme avant)
	NightBoxMinRarity = "Legendary", -- V0 : comme ShelfOpen.AnnounceMinRarity
	NightBoxGroupDelay = 1, -- V0 : s ; un remplissage de nuit (un magasin par image) tient dans ce délai
	NightBoxText = "A {rarity} box just appeared at {store}!", -- V0 : un seul colis
	NightBoxesText = "{count} rare boxes just appeared! Best: {rarity} at {store}", -- V0 : plusieurs colis

	-- Verrou de l'antivol (a178, Cantin 15/11) -------------------------------------------------------
	-- BB_AntiTheft (UnboxController) se montre selon la distance entre le PERSONNAGE local et l'objet, pas
	-- la caméra : MaxDistance du billboard de Clément ignorée, quel que soit le zoom.
	LockShowDistance = 40, -- V0 : studs
	LockedText = "LOCKED", -- V0 (anglais) : TimeLabel d'un objet tenu sous antivol pas encore lancé (sans UnlockAt)

	-- Vague 73 (a251 ; liaison L-236, L-237, L-246, validé par Clément le 2026-11-17 sur son prototype) : la nouvelle
	-- ouverture du colis sur un magasin PNJ. Le colis saute du rayon au sol de l'allée (L-234), le perso s'acharne
	-- dessus (ActionsByRarity actions, la dernière est toujours FinalAction), la cote monte, le colis s'améliore, il éclate,
	-- les silhouettes montent jusqu'à la rareté gagnée, puis l'objet se révèle. Le serveur tire tout d'avance
	-- (StoreHeistService, Shared/UnboxPlan : actions, rareté montrée après chaque action, cote finale) et l'envoie dans
	-- RevealStarted (argument plan) ; RevealController joue le plan (Controllers/Reveal/Unbox), puis sa croissance et sa
	-- fin comme avant. Origine : L-236 = écrit dans la liaison ; V0 = proposé, absent de la liaison, à régler en jeu.
	New = {
		Enabled = true, -- interrupteur ; false = la cinématique d'avant (Open<Rareté>, Config/Reveal), rien d'autre ne change
		-- Vague 74 (a257, L-253 point 1) : le nombre d'actions suit le résultat (la dernière comprise, 1 à 12) : la valeur de
		-- la rareté gagnée, plus ActionsPerUpgrade par amélioration du colis ; une amélioration demande une action avant
		-- et une après (au moins 2 + améliorations). Commun sans amélioration = la masse seule ; Peu commun = une action
		-- puis la masse (L-253). Tout V0, à régler par Clément.
		-- a287 (2026-11-21, Cantin en jeu : « on tombe tout de suite sur l'objet, on n'a pas cet effet de casser
		-- plusieurs fois la boîte ») : un Commun aussi se casse en plusieurs coups. V0 proposée le 2026-11-21 : la table
		-- d'avant + 2 (Commun 3 = deux actions puis la masse), l'ordre de L-253 gardé (plus rare = plus de coups).
		ActionsByRarity = { Common = 3, Uncommon = 4, Rare = 5, Epic = 6, Legendary = 7, Mythic = 8, Secret = 9, Divine = 10 } :: { [string]: number },
		ActionsPerUpgrade = 1, -- V0
		ActionSpeed = 1, -- L-236, curseur « Vitesse des actions » : animations, durées de repli et pauses ÷ cette valeur
		FinalAction = "Hammer", -- L-236 : la dernière action, celle qui casse le colis ; jamais tirée avant (V0)
		-- Les 7 actions (L-237). Anim = animation du joueur (Contract/Animations) ; Tool = modèle tenu en main
		-- (ToolFolder, facultatif) ; Fx = effet à chaque Impact (L-246) ; RunFx = effet pendant toute l'action jusqu'à son
		-- moment fort (rythme : attribut EmitEvery du modèle) ; sons : Sounds.Actions plus bas (vague 75, L-261) ;
		-- React = réaction du colis (React plus bas).
		-- Duration et Impacts (parts de la durée) : repli codé seulement, quand l'animation manque et chez les spectateurs
		-- (durées indicatives du prototype, L-237) ; avec l'animation, ce sont ses marqueurs Impact et sa fin qui comptent,
		-- et le dernier Impact attendu (#Impacts) est le moment fort.
		Actions = {
			{ Id = "Hammer", Anim = "Unbox_Hammer", Tool = "TOOL_Unbox_Sledgehammer", Fx = "FX_Unbox_Hit", React = "Squash", Duration = 0.6, Impacts = { 0.7 } },
			{ Id = "Saw", Anim = "Unbox_Saw", Tool = "TOOL_Unbox_Saw", Fx = "FX_Unbox_Sawdust", React = "Slide", Duration = 1.25, Impacts = { 0.25, 0.45, 0.65, 0.85 } },
			{ Id = "Crowbar", Anim = "Unbox_Crowbar", Tool = "TOOL_Unbox_Crowbar", Fx = "FX_Unbox_Hit", React = "Lid", Duration = 1.25, Impacts = { 0.5, 0.85 } },
			{ Id = "Drill", Anim = "Unbox_Drill", Tool = "TOOL_Unbox_Drill", Fx = "FX_Unbox_Hit", RunFx = "FX_Unbox_Chips", React = "Spin", Duration = 1.2, Impacts = { 0.85 } },
			{ Id = "Kick", Anim = "Unbox_Kick", Fx = "FX_Unbox_Hit", React = "Push", Duration = 0.8, Impacts = { 0.6 } },
			{ Id = "Search", Anim = "Unbox_Search", Junk = true, React = "Tilt", Duration = 1.4, Impacts = { 0.4, 0.75 } },
			{ Id = "Inspect", Anim = "Unbox_Inspect", Tool = "TOOL_Unbox_Magnifier", Mark = true, React = "Jump", Duration = 1.35, Impacts = { 0.8 } },
		} :: { Action },
		ActionMaxFactor = 1.5, -- V0 : une action est coupée à Duration × ce facteur (animation plus longue ou bloquée)
		ActionGap = 0.25, -- V0 : pause entre deux actions à la même place (le colis tremble)

		-- Vague 75 (a259, L-261 ; sons de Clément dans Assets/Sounds/Unbox, trouvés par MarkerSounds.find, absent = muet) :
		-- les sons de l'ouverture, du lancement de chaque action à l'éclatement. Aucun son de téléportation (Clément,
		-- 19/11 : seuls les nuages FX_Unbox_Puff la marquent). Chez l'ouvreur en 2D, chez les autres sur le colis.
		Sounds = {
			Actions = {
				Hammer = { Start = { "Unbox_Windup" }, Top = "Unbox_Swing", TopAt = 0.52, Impacts = { "Unbox_HammerHit" } }, -- L-261 ; TopAt : V0 (Top 0,37 s pour l'Impact à 0,50 s)
				Saw = { Start = { "Unbox_Saw" }, Stop = "End", Smoke = false }, -- L-261 : aux Impacts, rien de plus
				Crowbar = { Start = { "Unbox_CrowbarWedge" }, Impacts = { "Unbox_CrowbarCreak", "Unbox_CrowbarCrack" } }, -- L-261
				Drill = { Start = { "Unbox_Drill" }, Stop = "Impact", Impacts = { "Unbox_DrillThrough" } }, -- L-261
				Kick = { Start = { "Unbox_KickWhoosh" }, Impacts = { "Unbox_Kick" } }, -- L-261 (+ Unbox_BoxSlide : Slide plus bas)
				Search = { Start = { "Unbox_Rummage" }, Stop = "End", Impacts = { "Unbox_Toss" } }, -- L-261 (+ son de l'objet jeté)
				Inspect = { Start = { "Unbox_InspectHmm", "Unbox_InspectScan" }, Stop = "Impact", Impacts = { "Unbox_InspectDing" } }, -- L-261
				Stomp = { Impacts = { "Unbox_Kick" } }, -- V0 (absent de L-261) : le pied qui frappe le couvercle
				Slam = { Start = { "Unbox_Windup" }, Top = "Unbox_Swing", TopAt = 0.6, Impacts = { "Unbox_HammerHit" } }, -- V0 : comme la masse
			} :: { [string]: ActionSounds },
			StopFade = 0.1, -- L-261 : un son arrêté baisse à 0 en ce temps (s)
			ChainMax = 1, -- V0 : s ; un son de Start part au plus tard ce temps après le précédent (longueur inconnue : tout de suite)
			Burst = { "Unbox_Burst", "Unbox_Smoke" }, -- L-261 : au coup final qui casse le colis, en plus de son coup
			Smoke = "Unbox_Smoke", -- L-261 : quand la fumée (émetteur SmokeEmitter de l'effet de l'Impact) apparaît…
			SmokeEmitter = "Smoke", -- L-254
			SmokeAgainVolume = 0.3, -- L-261 : … puis à chaque Impact où elle revient, à ce Volume au plus (sauf à l'éclatement)
			Slide = "Unbox_BoxSlide", -- L-261 : quand le colis est poussé…
			SlideReacts = { "Push" }, -- V0 : … réactions du colis qui le font glisser (« Slide », la scie : rien de plus, L-261)
			JunkSqueak = "Unbox_JunkSqueak", -- L-261 : objet jeté dont le nom commence par un de SqueakJunk…
			SqueakJunk = { "ENV_Unbox_Junk_Duck" },
			JunkBoing = "Unbox_JunkBoing", -- L-261 : … les autres
			JunkPitch = { 0.9, 1.15 }, -- L-261 : PlaybackSpeed au hasard du son de l'Impact et de l'objet jeté
			Rattle = "Unbox_Rattle", -- L-261 : entre deux actions (le colis tremble), en boucle, arrêté en fondu…
			RattleVolumeStep = 0.15, -- V0 : … Volume × (1 + ceci × (actions faites − 1))…
			RattlePitchStep = 0.04, -- V0 : … PlaybackSpeed 1 + ceci × (actions faites − 1)…
			RattleMax = 2, -- V0 : … facteur de Volume au plus
		},

		-- Vague 74 (a257, L-258) : le perso change de place à chaque action, en se téléportant (ni marche ni saut) :
		-- Cycle (Side = la place de L-236, à côté du colis ; Other = de l'autre côté, réactions du colis dans l'autre
		-- sens ; Top = debout sur le couvercle), la dernière action toujours sur le colis (une seule action : il s'y
		-- téléporte d'abord). Sur le colis : Stomp au lieu de l'action tirée, Slam au lieu de la masse finale ; leur
		-- animation absente (Contract/Animations, facultatives) : l'action tirée et la masse, à la place du cycle à côté
		-- du colis (Side ou Other). Enabled = false : toujours à la même place, comme en vague 73.
		Places = {
			Enabled = true, -- interrupteur
			Cycle = { "Side", "Other", "Top" }, -- L-258
			Teleport = 0.34, -- L-258 : durée d'une téléportation (au lieu d'ActionGap)
			Vanish = 0.1, -- L-258 : disparition dans un nuage (FX_Unbox_Puff au torse) de 0 à cette valeur…
			Appear = 0.19, -- L-258 : … réapparition d'un coup à la nouvelle place (second nuage), puis le rebond
			Bounce = 0.35, -- V0 : studs, hauteur du petit rebond à la réapparition (de Appear à Teleport)
			CameraLift = 0.7, -- L-258 : la caméra monte de 0,7 × la hauteur des pieds au-dessus du sol
			CameraLiftSpeed = 8, -- V0 : 1/s, la caméra rattrape cette hauteur sans à-coup
			OddsSlide = 3.4, -- L-258 : studs, BB_UnboxOdds glisse sur le côté quand le perso est sur le colis…
			OddsSlideSpeed = 8, -- V0 : 1/s, … puis revient
			-- Les deux actions sur le colis (L-258 ; durées et marqueurs du prototype, repli codé seulement comme Actions).
			Stomp = { Id = "Stomp", Anim = "Unbox_Stomp", Fx = "FX_Unbox_Hit", React = "Stomp", Duration = 1.1, Impacts = { 0.45, 0.95 } } :: Action,
			Slam = { Id = "Slam", Anim = "Unbox_Slam", Tool = "TOOL_Unbox_Sledgehammer", Fx = "FX_Unbox_Hit", React = "Squash", Duration = 1.35, Impacts = { 0.8 } } :: Action,
		},

		-- Temps (s). Vague 74 : objet révélé vers 2,1 s (Commun, la masse seule), 6,1 s (Rare) et 9,9 s (Légendaire) ;
		-- a287 (ActionsByRarity de 3 à 10) : 5,2 s (Commun), 9,0 s (Rare) et 13,0 s (Légendaire) ; sans
		-- amélioration, actions moyennes, en repli (UnboxPlan.typical) ; chaque amélioration ajoute une action.
		Intro = 0.6, -- V0 : le colis saute du rayon au sol de l'allée, le perso se place, la caméra arrive
		BurstHold = 0.35, -- V0 : du coup de masse final (le colis éclate, le perso recule) à la première silhouette
		SilhouetteStep = 0.45, -- V0 : une silhouette (0,4 à 0,5 s chez Throw a Seed)
		Suspense = 0.6, -- V0 : la dernière silhouette (le vrai objet en noir) tremble (0,4 à 0,7 s)
		Overexpose = 0.1, -- V0 : l'objet tout blanc avant ses couleurs
		AfterReveal = 0.3, -- V0 : de la révélation au début de la croissance (Config/Reveal, étape Grow)
		ClientMargin = 1.5, -- V0 : le client coupe sa scène à la durée la plus longue possible + cette marge
		ServerMargin = 3, -- V0 : le serveur finit la phase (sans RevealDone) à la durée la plus longue possible + cette marge

		-- Place du colis, du perso et de la caméra (L-234 : au sol dans l'allée, caméra côté allée, jamais dans un mur).
		BoxOut = 4.5, -- V0 : studs entre l'emplacement du rayon et le colis posé au sol, vers l'allée
		BoxOutMin = 2, -- V0 : allée bouchée plus près que cela dans toutes les directions essayées : on prend la plus dégagée
		BoxClear = 1.2, -- V0 : marge (studs) entre le colis et ce qui bouche l'allée
		BoxHop = 2, -- V0 : hauteur (studs) du saut du rayon au sol
		FloorProbe = 8, -- V0 : le sol est cherché jusqu'à cette distance sous l'emplacement du rayon
		StandSide = 3.2, -- V0 : le perso se tient à cette distance du colis, sur le côté (le long du rayon), face à lui
		Recoil = 2, -- V0 : recul (studs) du perso quand le colis éclate
		RecoilTime = 0.25, -- V0
		AnimEndFade = 0.3, -- V0 (f70c4) : s ; la dernière action (la masse) n'est pas arrêtée à son coup : elle finit en
		-- fondu vers la pose d'attente du perso au lieu de s'arrêter net à sa dernière image
		Camera = {
			Distance = 11, -- V0 : studs entre le colis et la caméra, côté allée
			Height = 4.5, -- V0 : au-dessus du sol
			LookHeight = 2, -- V0 : hauteur du point visé (entre le colis et le perso)
			MinDistance = 5, -- V0 : un mur plus près que cela ne rapproche plus la caméra : il devient transparent
			Margin = 0.6, -- V0 : écart gardé devant un mur
			MaxHidden = 12, -- V0 : pièces rendues transparentes au plus entre la caméra et le colis
			-- a449 (testeur 1, 24/11) : rayon (studs) de la sphère qui suit aussi le trajet du point visé à la caméra (ouverture
			-- et révélation) : la caméra s'arrête devant un meuble au lieu d'entrer dedans. 0 : le rayon seul, comme avant.
			Room = 1.2, -- V0
			-- Vague 75 (a259, T-222) : de la caméra du joueur à celle de l'ouverture en fondu (départ et arrivée en douceur)
			-- en ce temps (s), au lieu du lissage du repli qui partait d'un coup (3 images de 3,4 à 2,2 studs à 15 images/s).
			BlendIn = 0.6, -- V0 : la durée de l'Intro
		},

		-- Réactions du colis à chaque Impact : aller et retour en Time s (un coup de pied le pousse, puis il revient).
		React = {
			Time = 0.28, -- V0
			Before = 0.5, -- V0 : force d'un Impact avant le moment fort de l'action
			Jump = 0.6, -- V0 : saut (studs)
			Tilt = 0.22, -- V0 : inclinaison (radians)
			Squash = 0.14, -- V0 : écrasement (part de la taille)
			Spin = 0.5, -- V0 : rotation (radians)
			Slide = 0.35, -- V0 : glissement (studs)
			Push = 1.6, -- V0 : poussée du coup de pied (studs)
			LidLift = 0.3, -- V0 : le couvercle (Lid) se soulève (studs)…
			LidTilt = 0.35, -- V0 : … et bascule (radians)
			Tremble = 0.02, -- V0 : tremblement entre deux actions (studs)…
			TrembleStep = 0.03, -- V0 : … plus fort à chaque action
		},

		-- Cote « 1 IN N » de BB_UnboxOdds.Odds (L-236, plages proposées par rareté ; Divine : V0). Au moment fort de
		-- chaque action, elle défile jusqu'à un nombre de la plage de la rareté montrée, toujours plus haut ; la cote
		-- finale s'affiche à la révélation. Vague 75 (a259, L-262 point 1, Clément : « la vraie probabilité ») : la cote
		-- finale est la vraie chance d'avoir cet objet, calculée par le serveur (Formulas.UnboxOdds : table de la caisse
		-- ShelfOpen.BoxRarityOdds, chance comprise, puis un objet parmi ceux de sa rareté dans la zone) ; RealOdds = false
		-- (ou contenu imposé du tuto) : tirée dans la plage de la rareté gagnée, comme avant.
		RealOdds = true, -- interrupteur
		OddsRanges = {
			Common = { 2, 4 },
			Uncommon = { 5, 12 },
			Rare = { 15, 45 },
			Epic = { 60, 190 },
			Legendary = { 300, 950 },
			Mythic = { 1200, 4800 },
			Secret = { 12000, 60000 },
			Divine = { 150000, 900000 },
		} :: { [string]: { number } },
		OddsText = "1 IN %s", -- L-236 (anglais)
		-- a462 (L-376, Features.UnboxLuckClimb / UnboxLuckClimbDev) : pendant les coups, BB_UnboxOdds.Odds montre la chance
		-- de l'ouvreur qui monte, au même format que BB_ShelfOpen.Row.Luck (ShelfOpen/Logic.luckText).
		LuckText = "×%.2f LUCK",
		OddsRoll = 0.35, -- V0 : durée du défilement d'une cote à la suivante
		OddsTick = 0.07, -- V0 : un changement de chiffre toutes les 67 à 100 ms (Throw a Seed)
		OddsTickSound = "Unbox_OddsTick", -- L-386 (Clément, 25/11 : plus de « bulles ») : les tics du compteur, à la hauteur du son de Clément (avant : UI_Click, L-229)
		OddsTickPitch = 0, -- L-386 : plus de montée par tic (avant : 0,06, + 6 % par tic) ; 0 = le PlaybackSpeed du son de Clément gardé
		OddsPop = 1.25, -- V0 : le texte gonfle à cette échelle au moment fort (créé : UIScale « UnboxPop »)
		FinalOddsAbove = 1.6, -- V0 : à la révélation, la cote finale se place à cette hauteur (studs) au-dessus de BB_Reveal
		FinalOddsHold = 1.6, -- V0 : … et y reste ce temps
		-- a287 (2026-11-21, Cantin en jeu : la chance qui augmente au-dessus de la boîte à chaque coup, puis pendant le
		-- défilement des silhouettes « 1 sur 2, 1 sur 5, 8… », jamais une cote qui redescend) : la cote de
		-- BB_UnboxOdds.Odds monte d'un bout à l'autre, de Start à la vraie cote du plan (UnboxPlan.climb, Offset plus bas) :
		-- un pas à chaque Impact des actions (HitsShare de la montée à l'éclatement du colis), puis un pas par silhouette
		-- (le reste), la vraie cote à la révélation (celle aussi écrite dans BB_Reveal.Odds). Les plages OddsRanges ne
		-- servent plus que si Enabled = false (la cote d'avant : plage de la rareté montrée, cachée pendant les
		-- silhouettes) et pour la cote finale tirée sans vraie cote (RealOdds = false, contenu imposé du tuto).
		OddsClimb = {
			Enabled = true, -- interrupteur
			Start = 2, -- Cantin, 21/11 : « une chance sur 2 » au départ (la vraie cote si elle est plus basse)
			HitsShare = 0.5, -- V0 (2026-11-21) : part de la montée faite par les coups (le reste : les silhouettes)
			-- V0 (2026-11-21) : la courbe monte d'un facteur égal sur (cote + Offset) : une petite vraie cote monte de pas
			-- presque égaux (2, 3, 4… 6 à l'éclatement, 8 à la silhouette, 10), une grande d'un facteur égal ; 0 = géométrique
			Offset = 20,
		},

		-- Améliorations (L-236 : au moment fort, sauf à la première et à la dernière action). Vague 74 (a257, L-253 point 2) :
		-- tirées à part de l'objet, avec les probabilités de l'ouverture v2 (UpgradeChance × chance du joueur par cran,
		-- UpgradeMax crans, jamais jusqu'à Secret), en partant de la rareté du colis du rayon ; elles ne changent pas
		-- l'objet (tiré par les règles de la caisse) : un colis resté Commun peut donner un Légendaire, et les silhouettes
		-- montent jusqu'à la vraie rareté. Un cran = une rareté de plus.
		StartRarity = "Common", -- V0 : rareté de départ d'un colis de rareté inconnue
		UpgradeGrow = 1.16, -- L-236 : le colis grossit à chaque amélioration
		UpgradeShow = 0.9, -- V0 : durée d'affichage de BB_UnboxOdds.Upgrade (« UPGRADE! »)
		UpgradeSound = "Unbox_TierNote", -- L-386 (Clément, 25/11) : la note du palier (avant : Unbox_Tier, cloche aiguë, L-229)
		TapeNames = { "Tape", "Tint" }, -- V0 : pièces du colis qui prennent la couleur de la rareté (le scotch)

		-- Zoom (FieldOfView × (1 − valeur)) et fondu des bords UI_Unbox.EdgeGlow (ImageTransparency), chez l'ouvreur.
		ZoomStep = 0.06, -- L-236 : amélioration et silhouette, × (1 + ZoomRank × rang de la rareté)
		ZoomRank = 0.3, -- L-236
		ZoomReveal = 0.12, -- L-236, × (1 + ZoomRank × rang) aussi (V0 : toujours plus fort que la silhouette)
		ZoomMax = 0.35, -- V0 : jamais plus de 35 % de zoom
		ZoomIn = 0.12, -- V0 : s
		ZoomHold = 0.25, -- V0
		ZoomOut = 0.5, -- V0
		EdgeStep = 0.45, -- V0 : ImageTransparency au plus fort d'une amélioration ou d'une silhouette
		EdgeReveal = 0.15, -- V0 : … à la révélation (plus marqué, L-236)
		EdgeIn = 0.1, -- V0
		EdgeHold = 0.25, -- V0
		EdgeOut = 0.6, -- V0
		EdgeScreen = "UI_Unbox", -- L-246
		EdgeGlow = "EdgeGlow",

		-- Silhouettes (L-236) : un objet de la zone par rareté, en noir, du plus petit au plus gros ; la dernière est le
		-- vrai objet. Sans modèle : un bloc noir.
		SilhouetteFit = 2.4, -- V0 : plus grand côté (studs) de la première silhouette
		SilhouetteGrow = 0.12, -- V0 : + 12 % par silhouette
		SilhouetteShake = 0.07, -- V0 : tremblement (studs) de la dernière pendant le suspense
		SilhouetteSound = "Unbox_Silhouette", -- L-229
		SuspenseSound = "Unbox_Suspense", -- L-229

		-- Modèles et effets de Clément, tous facultatifs (absent : rien, ou le repli du code).
		ToolFolder = { "Assets", "Unbox" }, -- L-237 : TOOL_Unbox_* (poignée Handle) et ENV_Unbox_Junk_*
		ToolHand = "RightHand",
		ToolGrip = "RightGripAttachment",
		-- L-255, L-257 : Handle posé sur RightGripAttachment comme un Tool à Grip neutre (manche le long de +Y du Handle).
		-- Sans RightGripAttachment (rig sans prise) : la main, tournée de ces angles (degrés), comme la prise R6 de Roblox.
		ToolGripAngles = { -90, 0, 0 },
		HitPoint = "HitPoint", -- L-255 : Attachment de Handle, ce qui touche le colis : les effets de l'Impact y sont posés
		JunkPrefix = "ENV_Unbox_Junk_",
		JunkSpeedUp = 16, -- V0 : studs/s
		JunkSpeedBack = 9, -- V0 : studs/s, par-dessus l'épaule du perso
		JunkGravity = 60, -- V0
		JunkSpin = 8, -- V0 : radians/s
		JunkLife = 1.2, -- V0 : s
		Fx = {
			Burst = "FX_Unbox_Burst", -- L-246 : colis de taille normale
			GiantBurst = "FX_RevealSmash", -- L-236 : objet géant (classe Large ou Colossal, L-220)
			Tier = "FX_Unbox_Tier",
			Silhouette = "FX_Unbox_Silhouette",
			Puff = "FX_Unbox_Puff",
			Overexpose = "FX_Unbox_Overexpose",
			Reveal = "FX_Unbox_Reveal",
		},
		FxTopAttachments = { "Top", "Contact" }, -- L-246 : Attachments posés au point touché (les autres restent au pied)
		FxEmit = 12, -- V0 : particules d'un émetteur sans attribut EmitCount
		FxLife = 2, -- V0 : s, effet sans attribut Duration
		OddsBoard = "BB_UnboxOdds", -- L-246 : Odds, Rarity, Upgrade (absent : billboard du code, mêmes noms)
		OddsBelowTop = 0.8, -- V0 : le billboard s'accroche à cette distance sous le haut du colis ou de la silhouette
		MarkBoard = "BB_UnboxMark", -- L-246 : Mark (« ? » puis « ! »)
		MarkStart = "?",
		MarkImpact = "!",
	},
}

export type Unbox = typeof(Unbox)

return DeepFreeze(Unbox)
