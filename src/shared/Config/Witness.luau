--!strict
-- Témoins et police (idée de Clément, liaison L-111 ; animations d'UI T.50 à T.52 de
-- docs/claude/notes/ui-motion-skilltree.md). Lu par WitnessService (serveur : règle, balade, police) et
-- WitnessController (client : bulle BB_Witness). Sources :
--   « Clément » : la ligne L-111 de la liaison (valeurs et noms donnés par Clément) ;
--   « Note » : le tableau T.50 à T.52 de la note ;
--   « V0 » : V0 proposé, absent du doc.
-- Unités : secondes, studs ; échelles de UIScale (1 = taille de Clément) ; angles en degrés.

local DeepFreeze = require(script.Parent.DeepFreeze)

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
	StuckTime = 3, -- V0 : sans avancer d'un stud pendant ce temps, il vise le point suivant
	MoveRefresh = 2, -- V0 : MoveTo redonné à ce rythme (Humanoid.MoveTo lâche au bout de 8 s)
	StepInterval = 0.1, -- V0 : cadence de la boucle serveur des témoins

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
	-- foule apparaît en arc devant la vitrine, tournée vers lui : des copies des témoins NPC_Witness_* présents chez le
	-- joueur (même modèle, même téléphone), créées et jouées par chaque client seul (WitnessCrowdController) : aucun
	-- remote, rien sur le serveur. Interrupteur : Features.WitnessCrowd.
	Crowd = {
		Count = 5, -- V0 : nombre de PNJ
		Filmers = 2, -- V0 : les premiers filment (TakePhoto figée sur la pose du téléphone levé, sans flash), les autres photographient
		Duration = 6, -- V0 : s, puis ils s'effacent
		FadeTime = 0.3, -- V0 : s, apparition et disparition (LocalTransparencyModifier) ; animations réduites : d'un coup
		Distance = 12, -- V0 : studs devant la vitrine
		Arc = 110, -- V0 : degrés, largeur de l'arc
		Jitter = 1.5, -- V0 : studs de hasard sur chaque place
		FlashMin = 0.7, -- V0 : rythme des flashs sans marqueur Flash (s, au hasard entre les deux)…
		FlashMax = 1.5, -- V0 : … ; avec TakePhoto, ses marqueurs Flash donnent le rythme
		FilmFreeze = 1, -- V0 : s ; sans marqueur Flash dans ce temps, le filmeur fige sa pose là où elle est
		Cooldown = 15, -- V0 : s, pas deux foules pour un même magasin dans ce temps
		MaxCrowds = 2, -- V0 : foules à la fois chez un joueur
		ViewDistance = 220, -- V0 : studs ; voleur plus loin de la caméra : pas de foule
		CheckInterval = 0.2, -- V0 : s, contrôle des porteurs
		TurnInterval = 0.1, -- V0 : s, la foule se tourne vers le voleur
		Anim = "TakePhoto", -- l'animation de Clément (Contract/Animations.Witness) ; absente : pose de repos
		Folder = "WitnessCrowd", -- V0 : dossier du Workspace (chez le joueur seul) qui range les copies
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
