--!strict
-- Interrupteurs des fonctions pas encore livrées (DEV-021 ; décision d'Ironix du 2026-11-07,
-- liaison L-026). false = la fonction n'existe pas encore : ses éléments d'UI sont cachés
-- (HudController). Repasser un interrupteur à true suffit à les réafficher, tels que Clément
-- les a posés (le code ne force jamais Visible = true). NightCycle coupe aussi son service serveur (NightCycleService)
-- et le ciel animé (SkyController). Le retour base (DEV-045, ReturnToBase) est retiré du code (a438, 24/11).
-- TruckEvent n'a pas d'UI : false coupe TruckEventService (aucun camion) et TruckController.
-- RobuxShop coupe aussi toute la boutique Robux (DEV-100) : MonetizationService (ni gamepass, ni bonus de
-- revenus, ni effet ; a485 : ProcessReceipt reste branché et garde chaque reçu pour plus tard, NotProcessedYet) et
-- RobuxShopController (écran UI_RobuxShop, comptoir).
-- Aperçus (L-071, décision de Clément du 2026-11-08 : les boutons Shop, Index et Rebirth du HUD sont
-- visibles dès maintenant) : RobuxShopPreview montre le bouton Shop et ouvre UI_RobuxShop en vitrine
-- tant que RobuxShop est false (RobuxShopController : aucun achat, aucun appel à MarketplaceService ;
-- le serveur reste coupé). Index passe à true (L-071) : l'index est codé par IndexController.
-- a438 (24/11, lot 5 du check-up a417, R1 et R9) : retirés avec leur ancien chemin, car toujours dans le même état
-- depuis longtemps : RebirthPreview (inutile depuis Rebirth = true), SingleBoxReveal (l'ouverture et les mutations de
-- taille d'avant la vague 62), NewAuras (la boutique des 6 anciennes auras ; leur migration reste), RebirthTools
-- (outils de renaissance d'a407, coupés en fusion98 : L-173, plus d'outil à la renaissance) et ReturnToBase.

local DeepFreeze = require(script.Parent.DeepFreeze)

local Features = {
	RobuxShop = false, -- MAJ 1, boutique Robux (5.9) : UI_HUD.RobuxShopButton, MonetizationService, RobuxShopController
	RobuxShopPreview = true, -- L-071 : avec RobuxShop à false, UI_HUD.RobuxShopButton visible et UI_RobuxShop en vitrine (aucun achat)
	RobuxCrate = false, -- vague 63 (L-200, L-204) : caisse exclusive de UI_RobuxShop_v2 (Monetization.Crate) ; false = section Crate cachée (contenu et chances pas décidés)
	RobuxCrateDev = true, -- a294 (validé par Cantin, 21/11) : la caisse exclusive allumée dans le jeu DEV seulement (Config/ProductIds.IsDev, Monetization.Crate.Live), même boutique coupée ; PROD : RobuxCrate seul (false = cachée, invendue)
	Index = true, -- MAJ 2, index des objets : UI_HUD.IndexButton (L-071 : visible dès maintenant, IndexController)
	Rebirth = true, -- MAJ 3, renaissance (DEV-120, codée en V0 vague 51 : RebirthService, remote Rebirth) : UI_HUD.RebirthButton ; true depuis la vague 72 (a244 ; L-216 point 5, L-231 : au lancement, décision de Cantin)
	NightCycle = true, -- DEV-047, cycle jour/nuit (5.12) : UI_HUD.NightCountdown, NightCycleService, SkyController
	AntiCheat = true, -- DEV-060, contrôle des déplacements (9.6, Config/AntiCheat) : false coupe AntiCheatService (Allow et Verify ne font rien), aucune UI
	TruckEvent = true, -- L-049, événement camion (Config/TruckEvent) : TruckEventService, TruckController
	Settings = true, -- L-095 point 2, réglages : UI_HUD.SettingsButton (montré par SettingsController) et écran UI_Settings ; à false, les réglages sauvegardés s'appliquent quand même (sons, effets)
	-- a443 (Cantin, 24/11 : refonte de la poursuite, fiche docs/references/Poursuite.md) : poursuite « V3 » (Config/Chase.V3,
	-- server/Services/Guard/ChaseLaw, Shared/ChaseV3) : distance de croisière, retour en une seule loi, vigile plus rapide
	-- à vitesse constante, éjection à la capture, image du vigile toujours derrière le joueur. Interrupteur PROD
	-- (partout) : false tant qu'un test humain ne l'a pas validée (décision C2) ; false = la poursuite d'avant, intacte.
	-- GuardChaseV2 (vague 45) est retiré : toujours à true depuis le 14/11, son chemin est la règle (check-up, R9).
	ChaseV3 = false,
	-- a443 : la même chose allumée dans le jeu DEV seulement (Config/ProductIds.IsDev), comme les autres nouveautés.
	ChaseV3Dev = true,
	-- a443 (Cantin, 24/11 : « qu'on ne puisse pas être ralenti ») : dès que le stick (manette, stick virtuel du téléphone)
	-- sort de la zone morte, le personnage marche à sa pleine vitesse, comme au clavier (Shared/FullStick,
	-- FullStickController, Config/Gamepad.FullStick). Interrupteur PROD (partout) : false tant qu'un test humain ne l'a pas
	-- validé (décision C2) ; false = la marche de Roblox (stick à moitié = moitié de la vitesse).
	FullSpeedStick = false,
	-- a443 : la même chose allumée dans le jeu DEV seulement (Config/ProductIds.IsDev).
	FullSpeedStickDev = true,
	FortuneTower = true, -- L-108 point 8 (vague 37, a123), événement de la Fortune Tower (Config/FortuneTower) : FortuneTowerService, FortuneTowerController ; true depuis la validation de Clément (L-145 réponse (a), vague 42) ; sans ENV_Event_FortuneVault, rien en jeu publié (bloc V0 en Studio seulement) ; en Studio, workspace:SetAttribute("FortuneTest", true) la fait apparaître tout de suite
	-- Vague 80 (a267, Cantin 20/11 « Pièges et coffre ») : true en DEV ; sans UI_Rewards.WeeklyChest de Clément, les jours
	-- se comptent mais rien ne se montre (ni cadre ni pastille : RewardsController).
	WeeklyChest = true, -- MAJ 1, coffre hebdomadaire (DEV-101, Partie 2 3.3 ; Config/Rewards.Weekly) : RewardService (remote ClaimWeekly), RewardsController (UI_Rewards.WeeklyChest, facultatif) ; false = rien ne change en jeu ; en Studio, workspace:SetAttribute("WeeklyChestTest", true) l'allume
	-- Vague 66 (a221, L-210 point 4) : la foule de PNJ qui filme et photographie le voleur à sa sortie d'un magasin PNJ
	-- (Config/Witness.Crowd, WitnessCrowdController, client seul, aucun remote) ; false = rien ne change.
	WitnessCrowd = true,
	-- Vague 72 (a243, L-218, L-216 point 11) : pièges de la boutique (Config/Traps, TrapService, TrapController ; tuile
	-- Traps de Config/SkillTree achetable) ; false = aucun piège posé, tuile « Soon » ; en Studio,
	-- workspace:SetAttribute("TrapsTest", true) les allume sans toucher à cette ligne.
	-- Vague 80 (a267, Cantin 20/11 « Pièges et coffre ») : true en DEV ; les 3 modèles de Clément (L-218) sont
	-- branchés, un modèle absent est remplacé par le repli de TrapService, un TrapSlot absent = pas de piège.
	-- a467 (L-163, A2 ; décision C2 de Cantin, 24/11 : T-247 pas encore passé) : interrupteur PROD (partout), false ;
	-- allumé en DEV par TrapsDev. Lu par SkillTree.DefenseOn (Config/SkillTree), comme les 3 défenses plus bas.
	-- NewTraps / NewTrapsDev (disposition) ne comptent que si les pièges sont allumés.
	Traps = false,
	-- a467 : la même chose allumée dans le jeu DEV seulement (Config/ProductIds.IsDev), comme les autres nouveautés.
	TrapsDev = true,
	-- Vague 80 (a266, DEV-132, UI-130) : quêtes quotidiennes (Config/Quests, QuestService, QuestController ; écran UI_Quests et
	-- bouton UI_HUD.QuestsButton de Clément, facultatifs) ; false = rien n'est compté, aucun attribut, bouton caché.
	Quests = true,
	-- Vague 80 (a266, DEV-141) : roue de la fortune du hub, un tour gratuit par jour (Config/Wheel, WheelService,
	-- WheelController ; écran UI_Wheel, zone WheelZone de ENV_Hub_Wheel) ; false = rien ne s'ouvre, SpinWheel ignoré.
	Wheel = true,
	-- a286 (L-218, L-231, L-268) : les deux pièges de plus de Clément, peau de banane (TRAP_BananaPeel) et trappe
	-- (TRAP_TrapDoor) ; true = disposition Traps.SlotLayoutNew (a293 : colle, banane, portique, trappe, la colle
	-- gardée) ; false = l'ancienne disposition Traps.SlotLayout (colle, filet, portique, colle).
	-- a296 : interrupteur PROD (partout) ; false, validé par Cantin, 21/11 : coupé en PROD, allumé en DEV par NewTrapsDev.
	NewTraps = false,
	-- a296 (validé par Cantin, 21/11) : la disposition Traps.SlotLayoutNew allumée dans le jeu DEV seulement
	-- (Config/ProductIds.IsDev, TrapService) ; PROD (ou ProductIds absent) : NewTraps seul (false = l'ancienne).
	NewTrapsDev = true,
	-- a286 (L-216 point 10, L-235 « 60 s du revenu de l'objet pour chaque ami entré dans le magasin ») : prime au
	-- complice d'un braquage à deux (Config/Balance.Heist.PartnerBonusSeconds, StoreHeistService) ; false = rien ne
	-- change. a293 : true, validé par Cantin, 21/11 (en DEV comme en PROD).
	HeistPartnerBonus = true,
	-- a285 (21/11, retour de Cantin en jeu : « les glims, les effets de texte, les effets des over ») : les effets d'UI que
	-- Clément pose en attribut et qu'aucun code ne jouait (Gleam, IconHover, Idle = Wiggle ou Fall ; Controllers/UI/
	-- UiAttrFx, valeurs V0 dans Config/UiMotion.AttrFx) ; false = rien ne change en jeu.
	UiAttrFx = true,
	-- a298 (21/11, demande de Cantin : « Tous », validé par Cantin, 21/11) : les effets des boutons de Clément faits avec le
	-- plugin Figma Framewisp (reflet, soleil qui tourne, balancement, bascule au survol, éclats au clic, assombrissement,
	-- contour animé), rejoués par Controllers/UI/FramewispFx depuis les attributs Figma* du plugin, à la place de ses 6
	-- LocalScripts, et le reflet du bouton entier (Config/UiMotion.AttrFx.ButtonSheen). Sous Features.UiAttrFx (éteint :
	-- rien). V0 proposé (2026-11-21) : true ; false = rien de cela en jeu.
	FramewispFx = true,
	-- a301 (21/11, demande de Cantin) : près de la boutique d'un autre joueur, dehors, les étiquettes BB_Item de ses objets exposés se voient à travers la façade (ShopSpyController, Config/ShopSpy) ; V0 proposé (2026-11-21) : true ; false = comme avant.
	ShopSpy = true,
	-- a400 (vague GC3, décision de Cantin du 23/11 ; audit a272, faille M1, option (a)) : contre le « fling », les
	-- personnages des joueurs sont dans le groupe de collision « Players », qui ne se touche pas lui-même
	-- (PlayerCollisionService) ; ils touchent toujours le décor, les vigiles, le bot, les PNJ, le mur de nuit, les
	-- vitrines et les portes. false = les joueurs se traversent ; true = le contact entre joueurs d'avant.
	PlayerCollision = false,
	-- a413 (vague GC7, 23/11) : badges du jeu (BadgeService, Config/Badges ; Id à 0 = badge sauté) ; V0 proposé (Cantin, 23/11) : true ; false = aucun badge donné.
	Badges = true,
	-- Vague GC6 (a410, MAJ 7) : notifications Roblox hors du jeu (Config/Notifications, NotificationService, demande de
	-- consentement de NotificationController) ; rien ne part tant que les MessageId et le secret ne sont pas posés dans le
	-- Creator Hub. V0 proposé (Cantin, 23/11) : true ; false = ni demande de consentement ni envoi.
	ExperienceNotifications = true,
	-- Vague GC6 (a410, MAJ 7, Partie 2 section 3.4) : mutations déjà obtenues de chaque objet dans l'index (catégorie
	-- MUTATIONS d'UI_Index_v3, IndexController ; notées par IndexService même à false). V0 proposé (Cantin, 23/11) : true.
	IndexMutations = true,
	-- a280 (vague GC2, lot C de l'audit a270 ; L-217, L-231, L-277) : 2e étage de la boutique, Model `Floor_2` de Clément
	-- (Config/ShopGrowth.Floor2, Shared/ShopFloor, ShopStageService ; règle de L-294 : 8 présentoirs en bas, puis l'étage
	-- acheté et ses 8 places) ; true : sans Floor_2 livré, rien ne change ; false = pas d'étage, l'amélioration Display Stands
	-- s'arrête aux 20 présentoirs du bas comme avant. V0 proposé (Cantin, 23/11).
	ShopFloor2 = true,
	-- GC6 (a409, MAJ 6, DEV-133 ; Cantin, 23/11 : « tu fais tout maintenant ») : casse du siècle, un fourgon blindé toutes
	-- les 30 min à heure fixe dans le couloir, PV partagés, un colis de zone selon ses dégâts (Config/ArmoredVan,
	-- ArmoredVanService) ; modèle ENV_Event_ArmoredVan de Clément facultatif (repli en blocs). true en DEV ; false = aucun fourgon.
	ArmoredVan = true,
	-- GC6 (a409, MAJ 6, DEV-140) : classements hebdomadaires, top 100 en $/s et en vols, remis à zéro le lundi 00:00 UTC,
	-- récompense la semaine suivante (Config/WeeklyLeaderboard, WeeklyLeaderboardService ; panneaux de Clément
	-- facultatifs). true en DEV ; false = rien n'est compté ni écrit.
	WeeklyLeaderboards = true,
	-- a414 (vague GC7, 23/11, demande de Cantin) : mesures du lancement dans le tableau de bord Roblox (AnalyticsService) :
	-- entonnoirs de Config/Funnels (FunnelService, FunnelController ; le tutoriel garde l'onboarding), événements
	-- WindowBroken, HighRarityOpened, ItemSold, LoadingTime, gains pas encore comptés (receleur, codes, dons du tuto,
	-- prime au complice). Sous Config/Telemetry.Enabled. false = rien de cela.
	Analytics = true,
	-- a408 (vague GC6, MAJ 5 « Défense de la boutique », Cantin 23/11 : tout maintenant ; V0 à valider par Clément) :
	-- tuiles de l'arbre devenues achetables (Config/SkillTree, Config/ShopDefense, ShopDefenseService) ; false = la
	-- tuile reste « Soon » et rien n'est posé.
	-- a467 (L-163, A2 ; décision C2 de Cantin, 24/11 : T-285 pas encore passé) : interrupteurs PROD (partout), false ;
	-- chacun allumé en DEV par sa variante …Dev (Config/ProductIds.IsDev). Lus par SkillTree.DefenseOn (Config/SkillTree).
	Bodyguards = false, -- agent de sécurité qui poursuit le voleur (Partie 2, section 2)
	-- a515 (Cantin, 27/11) : garde du corps et garde de porte retirés du jeu pour la V1 : coupés partout, DEV et TEST compris
	-- (tuiles « Soon », achat refusé par SkillTreeService, aucun agent posé) ; le code reste. Niveaux déjà achetés en DEV
	-- ou TEST : retirés des profils au chargement, une fois, sans remboursement (DataService, removeRetiredDefenses).
	BodyguardsDev = false,
	DoorGuard = false, -- garde à la porte qui repousse le voleur (L-163)
	DoorGuardDev = false, -- a515 : voir BodyguardsDev
	CameraRadar = false, -- Cameras niveau 3 : voleur en rouge vif et son de radar, sans flèche (L-163, L-175)
	CameraRadarDev = true,
	-- a467 (L-373, Clément 25/11 : défenses reportées, « Coming soon » ; C2) : tuile Cameras de l'arbre,
	-- niveaux 1 et 2 (alerte au 1er coup, voleur surligné : SkillTreeService) ; interrupteur PROD (partout),
	-- false = tuile « Soon », rien ne s'achète, aucun effet ; allumée en DEV par CamerasDev. Lu par SkillTree.DefenseOn.
	Cameras = false,
	CamerasDev = true,
	-- a411 (vague GC6, L-113, feuille de route MAJ 4) : cabine d'essayage (Config/Disguise, DisguiseService, DisguiseController ;
	-- tuile FittingRoom de Config/SkillTree achetable) : se déguiser en passant d'une zone, dénoncer un magasin, être démasqué
	-- d'un coup de batte. V0 proposé (Cantin, 23/11) : true en DEV ; false = tuile « Soon », remotes Disguise et Denounce ignorés.
	FittingRoom = true,
	-- a419 (23/11, demande de Cantin : jouable à la manette Xbox, PlayStation ou sur PC ; Config/Gamepad) : sélection du
	-- premier bouton d'un menu, ButtonB pour fermer, L1 / R1 pour la barre du bas, aides au bon bouton ; V0 proposé
	-- (Cantin, 23/11) : true ; false = rien ne change (clavier, souris et tactile ne changent jamais).
	Gamepad = true,
	-- a315 (L-291, règle de Cantin du 23/11) : l'intrus frappé par le propriétaire dans sa boutique part en ragdoll à
	-- travers la vitre la plus proche dans le sens du coup, la troue (givre, éclats), atterrit dehors et se relève ;
	-- le trou se répare (GlassThrowService, GlassThrowController, Config/GlassThrow, remote GlassThrow). Interrupteur
	-- PROD (partout) : false, V0 proposé (2026-11-23) ; false = le coup pose l'intrus devant la porte, comme avant.
	ShopGlassThrow = false,
	-- a315 : la même chose allumée dans le jeu DEV seulement (Config/ProductIds.IsDev), comme les autres nouveautés.
	ShopGlassThrowDev = true,
	-- a468 (Cantin, 25/11 : « c'est un truc qui a été fait au tout début du jeu parce qu'avant il n'y avait pas les
	-- vitres ») : plus de sortie forcée « Only the owner can be inside this shop. » d'une boutique à la porte intacte
	-- (PvPService, ejectStep) ; on se faisait sortir en passant derrière une boutique du niveau 1 (son volume Bounds
	-- dépasse de 32 studs derrière son mur du fond). Restent : la sortie d'un joueur interdit de voler cette boutique
	-- (RobCooldown) et celle de la reconstruction de la porte (DoorBack). Interrupteur PROD (partout) : false (règle C2,
	-- pas encore de test humain) ; false = la sortie d'avant, intacte.
	NoIntactDoorEject = false,
	-- a468 : la même chose allumée dans le jeu DEV seulement (Config/ProductIds.IsDev), comme les autres nouveautés.
	NoIntactDoorEjectDev = true,
	-- a468 (correctif du 25/11, petit chef et grand chef) : « dans la boutique » = dans son volume Bounds ET devant son
	-- mur du fond posé (niveau 1 : ShopGrowth.MinBack ; sinon StageDepth ; boutique entière : Bounds seul), pour tous les
	-- lecteurs de Bounds qui jugent « dedans » (Shared/ShopInside) : plus de vol à travers le mur du fond, ni de passant
	-- frappé, interdit ou sorti derrière une boutique. Avec NoIntactDoorEject, la sortie « porte intacte » ne vise plus
	-- que qui est vraiment dans les murs (boutique qui a grandi autour de lui). Interrupteur PROD (partout) : false
	-- (règle C2) ; false = Bounds seul, la règle d'avant.
	ShopInsideBackWall = false,
	-- a468 : la même chose allumée dans le jeu DEV seulement (Config/ProductIds.IsDev), comme les autres nouveautés.
	ShopInsideBackWallDev = true,
	-- a426 (L-319, décision de Clément du 23/11) : dans une zone `SafeZone`, la même vitesse pour tous et un léger
	-- ralenti pour qui porte un objet pris chez un joueur (Balance.SafeZoneSpeed, StatsService). V0 proposé (Cantin,
	-- 24/11) : true ; false = vitesse de la formule partout et vitesse fixe Carry.StolenItemWalkSpeed, comme avant.
	SafeZoneSpeed = true,
	-- a428 (L-328 point 7, Clément 24/11) : le voleur attrapé par la police d'une dénonciation donne son objet au
	-- dénonciateur (Config/Disguise.RecoverCatchRange, DisguiseService, CarryService.Transfer). V0 proposé (Cantin, 24/11) :
	-- true ; false = l'objet tombe au sol, ou revole sur son rayon si le voleur est attrapé dans le magasin (comme avant).
	DenounceRecover = true,
	-- a429 (L-327, L-339, Clément 24/11 ; décision C2 de Cantin, 24/11 : en PROD, seul ce qu'un humain a testé est
	-- allumé) : catalogue d'objets v3 (Config/Items : objets drôles, modèles de L-339, boucles Animations/Boucle jouées
	-- par ItemLoopController) ; les objets des profils sont renommés au chargement (DataService, Items.V2ToV3), et
	-- remis en v2 si l'interrupteur est recoupé. Interrupteur PROD (partout) : false ; false = catalogue v2, comme avant.
	ItemsV3 = false,
	-- a429 : la même chose allumée dans le jeu DEV seulement (Config/ProductIds.IsDev), comme les autres nouveautés.
	ItemsV3Dev = true,
	-- a481 (Cantin, 25/11) : nœuds OfflineTime1 et OfflineTime2 de l'arbre de compétences achetables, +30 min de gains
	-- hors ligne chacun (Config/Offline.CapHours, 5 h au plus, 3 h avec la table 2 de l'économie, a515 ; plafond appliqué par OfflineService). Interrupteur PROD
	-- (partout) : false (règle C2 : pas encore de test humain) ; false = tuiles « Soon », plafond de base pour tous (Config/Offline.MaxHours).
	SkillOfflineTime = false,
	-- a481 : la même chose allumée dans le jeu DEV seulement (Config/ProductIds.IsDev), comme les autres nouveautés.
	SkillOfflineTimeDev = true,
	-- a446 (L-305, L-344, Clément 23/11 et 24/11) : contours « façon BD » sur ce qui est interactif (Config/Outlines,
	-- OutlineController) : FX_Outline de Clément sur les éléments proches, FX_OutlineFocus (blanc) sur celui dont l'invite
	-- est affichée ; les colis y entrent (leur OutlineHighlight est retiré côté client). Interrupteur PROD (partout) :
	-- false (règle C2 : pas encore de test humain) ; false = contours des colis de ShelfBoxController, comme avant.
	BdOutlines = false,
	-- a446 : la même chose allumée dans le jeu DEV seulement (Config/ProductIds.IsDev), comme les autres nouveautés.
	BdOutlinesDev = true,
	-- a473 (L-369, Clément 25/11) : contours « façon BD » toujours visibles (Config/Outlines.MaxPinned, en plus des
	-- MaxOutlines de près) : dans la zone safe, les 6 stands du hub et les éléments de la boutique du joueur local ;
	-- partout, son outil en main et l'objet porté au-dessus de sa tête. Demande aussi BdOutlines ou BdOutlinesDev.
	-- Interrupteur PROD (partout) : false (règle C2) ; false = règle de L-305 seule (de près), comme avant.
	BdOutlinesHub = false,
	-- a473 : la même chose allumée dans le jeu DEV seulement (Config/ProductIds.IsDev).
	BdOutlinesHubDev = true,
	-- a483 (décision de Cantin du 25/11, remplace la règle 6.1) : le contour rouge d'un objet volé à un joueur n'est vu
	-- que par la victime (Shared/StolenOutline : plus posé par CarryService, posé par le client de la victime seule,
	-- TheftAlertController) ; vol chez le bot : personne. Interrupteur PROD (partout) : false (règle C2) ; false = vu de
	-- tous, comme avant.
	StolenOutlineVictimOnly = false,
	-- a483 : la même chose allumée dans le jeu DEV seulement (Config/ProductIds.IsDev).
	StolenOutlineVictimOnlyDev = true,
	-- a465 (L-340, Clément 24/11 : « un peu d'UI de tension ») : tension pendant un braquage (Config/HeistTension,
	-- Shared/HeistTension, TensionController) : chevrons FX_ChaseChevron au sol jusqu'à sa boutique tant qu'on porte un
	-- objet volé, vigile en HL_ChaseGuard, DropButton gardé dans le HUD vidé de la poursuite, chrono HeistTimer gardé
	-- pendant la phase discrète (même sous l'écran de révélation), flash jaune d'arrivée 0 → 0,6 → 1. Tout est côté
	-- client. Interrupteur PROD (partout) : false (règle C2 : pas encore de test humain, T-303) ; false = comme avant.
	HeistTension = false,
	-- a465 : la même chose allumée dans le jeu DEV seulement (Config/ProductIds.IsDev), comme les autres nouveautés.
	HeistTensionDev = true,
	-- a477 (L-377, L-385, Clément 25/11) : musique du vol (Config/Music.Steal, MusicController) : MUS_Steal tant qu'on
	-- porte un objet volé (magasin PNJ ou boutique de joueur), MUS_Victim chez le joueur volé, MUS_Heist dès le 1er coup
	-- sur la porte d'une boutique de joueur, bascules rapides. Interrupteur PROD (partout) : false (règle C2 : pas encore
	-- de test humain) ; false = musiques comme avant (MUS_Chase, MUS_Heist au chrono PNJ, MUS_Truck, fond).
	StealMusic = false,
	-- a477 : la même chose allumée dans le jeu DEV seulement (Config/ProductIds.IsDev), comme les autres nouveautés.
	StealMusicDev = true,
	-- a480 (Clément via Cantin, 25/11) : le gain du tapis sort autour du joueur dans le monde 3D (copies de BB_Gain),
	-- nombre final sans « ×N », 6 fois plus d'apparitions et un son à chacune (Config/TreadmillFX.GainPops, Shared/GainPops,
	-- GainController). Interrupteur PROD (partout) : false (règle C2) ; false = le « +X » 2D qui vole au compteur, comme avant.
	TreadmillGainPops = false,
	-- a480 : la même chose allumée dans le jeu DEV seulement (Config/ProductIds.IsDev), comme les autres nouveautés.
	TreadmillGainPopsDev = true,
	-- a472 (L-365 point 5, Clément 25/11) : le client prévoit le ramassage d'une de ses plaques (Shared/PadZone, la même
	-- règle que le serveur) et joue le son Cash_Pad et le voile UI_CashFlash sans attendre le remote CashCollect
	-- (Config/CashFlash.Predict, GainController) ; l'argent, le compteur et « +$X » restent ceux du serveur. Interrupteur
	-- PROD (partout) : false (règle C2 : pas encore de test humain) ; false = son et voile au remote, comme avant (a422).
	PadPredict = false,
	-- a472 : la même chose allumée dans le jeu DEV seulement (Config/ProductIds.IsDev), comme les autres nouveautés.
	PadPredictDev = true,
	-- a484 (Cantin, 25/11) : Equip Best pose les objets du meilleur au moins bon dans l'ordre des présentoirs vu depuis
	-- l'entrée (rez-de-chaussée puis étage ; mur gauche puis mur droit, puis ceux du milieu (Config/Displayed.EquipBestOrder) ; du plus près de l'entrée au fond ; Shared/
	-- DisplayOrder) et réordonne aussi les objets déjà exposés (DisplayService.EquipBest). Interrupteur PROD (partout) :
	-- false (règle C2 : pas encore de test humain) ; false = Equip Best d'avant (un exposé parmi les meilleurs reste en
	-- place, les autres remplissent les trous du plus petit numéro au plus grand).
	EquipBestOrder = false,
	-- a484 : la même chose allumée dans le jeu DEV seulement (Config/ProductIds.IsDev), comme les autres nouveautés.
	EquipBestOrderDev = true,
	-- a478 (L-380, Clément 25/11 : « le bouton inventaire n'ouvre pas le display ») : UI_Hotbar.Bar.InventoryButton ouvre
	-- l'écran d'inventaire UI_Inventory (InventoryController : tenir en main, exposer, vendre) au lieu des objets exposés
	-- (UI_Displayed garde son propre bouton, RightRail.DisplayedButton, L-364). Écran absent de PlayerGui : le bouton
	-- ouvre encore les objets exposés. Calculé dans Config/Displayed.InventoryScreen. Interrupteur PROD (partout) : false
	-- (règle C2 : pas encore de test humain) ; false = le bouton ouvre les objets exposés, comme avant.
	InventoryScreen = false,
	-- a478 : la même chose allumée dans le jeu DEV seulement (Config/ProductIds.IsDev), comme les autres nouveautés.
	InventoryScreenDev = true,
	-- a475 (L-371, Clément 25/11) : à chaque objet ramené en zone safe (rangé par UnboxService ou déposé par PvPService),
	-- feux d'artifice aux points FireworksPoint de la map, vus par tous (CelebrationService, remote Fireworks,
	-- VfxController.Fireworks, Config/Vfx.Fireworks). Interrupteur PROD (partout) : false (règle C2) ; false = comme avant
	-- (seul FX_Escape aux pieds du joueur).
	SecuredFireworks = false,
	-- a475 : la même chose allumée dans le jeu DEV seulement (Config/ProductIds.IsDev), comme les autres nouveautés.
	SecuredFireworksDev = true,
	-- a475 (L-372, Clément 25/11) : annonces de valeur à tout le serveur (UI_Announce, Shared/Announce, CelebrationService) :
	-- objet de grande valeur ramené en zone safe, objet de grande valeur en fuite, valeur dans le texte du vol chez un
	-- joueur (Config/Announce.Value*). Interrupteur PROD (partout) : false (règle C2) ; false = annonces d'avant.
	ValueAnnounce = false,
	-- a475 : la même chose allumée dans le jeu DEV seulement (Config/ProductIds.IsDev), comme les autres nouveautés.
	ValueAnnounceDev = true,
	-- a476 (L-374, Clément 25/11) : tuile BoxLuck de l'arbre de compétences achetable, chance des colis ouverts par le
	-- joueur × Effects[niveau] (Config/SkillTree, Shared/OpenLuck). Interrupteur PROD (partout) : false (règle C2 : pas
	-- encore de test humain) ; false = tuile « Soon », aucun effet (un niveau acheté en DEV ne compte pas).
	SkillBoxLuck = false,
	-- a476 : la même chose allumée dans le jeu DEV seulement (Config/ProductIds.IsDev), comme les autres nouveautés.
	SkillBoxLuckDev = true,
	-- a476 (L-375) : chance du serveur en Robux, produits ServerLuck2, 4 et 8 (Config/Monetization.ServerLuck, codée par
	-- a247) vendue avec la boutique Robux (Features.RobuxShop). Interrupteur PROD (partout) : false (règle C2) ; false =
	-- cartes cachées et reçus refusés (NotProcessedYet), comme avant (SERVER_LUCK = false).
	ServerLuck = false,
	-- a476 : la même chose allumée dans le jeu DEV seulement (Config/ProductIds.IsDev), comme les autres nouveautés.
	ServerLuckDev = true,
	-- a462 (L-356 Q4, réponse de Clément du 24/11 à L-281) : pendant les coups de l'ouverture de la caisse exclusive, le
	-- colis monte d'une rareté à chaque action jusqu'à celle tirée par le serveur (MonetizationService, UnboxPlan.draw), et
	-- le colis montré (caisse, colis de rayon amélioré) prend le modèle BOX_<Rareté> de Clément de sa rareté
	-- (Controllers/Reveal/Unbox). Interrupteur PROD (partout) : false (règle C2 : pas encore de test humain) ; false = le
	-- colis de la caisse reste Épique et seules les silhouettes montent, scotch recoloré, comme avant.
	UnboxBoxClimb = false,
	-- a462 : la même chose allumée dans le jeu DEV seulement (Config/ProductIds.IsDev), comme les autres nouveautés.
	UnboxBoxClimbDev = true,
	-- a462 (L-376, Clément 25/11) : pendant les coups sur le colis, c'est la chance (luck) de l'ouvreur qui monte et
	-- s'affiche (« ×N LUCK » sur BB_UnboxOdds.Odds, de ×1 à la chance tirée par le serveur, StoreHeistService) ; le
	-- « 1 IN N » n'apparaît qu'à l'éclatement et monte sur les silhouettes jusqu'à la vraie cote (Shared/UnboxPlan,
	-- Controllers/Reveal/Unbox). Interrupteur PROD (partout) : false (règle C2) ; false = la cote monte pendant les coups
	-- (a287), comme avant.
	UnboxLuckClimb = false,
	-- a462 : la même chose allumée dans le jeu DEV seulement (Config/ProductIds.IsDev), comme les autres nouveautés.
	UnboxLuckClimbDev = true,
	-- a462 (décision de Cantin, 25/11) : la montée de rareté d'un colis de rayon pendant les coups suit l'objet tiré : un
	-- objet plus rare que le colis le fait monter d'une rareté par action, juste avant le coup final, jusqu'à la sienne
	-- exactement ; même rareté ou en dessous : aucune montée (comme la caisse exclusive, UnboxBoxClimb). Le tirage de
	-- l'objet et de la chance ne change pas (Shared/UnboxPlan.shelfClimb, StoreHeistService.startReveal). Interrupteur
	-- PROD (partout) : false (règle C2) ; false = améliorations tirées à part de l'objet (UnboxPlan.upgrades), comme avant.
	UnboxClimbMatchesItem = false,
	-- a462 : la même chose allumée dans le jeu DEV seulement (Config/ProductIds.IsDev), comme les autres nouveautés.
	UnboxClimbMatchesItemDev = true,
	-- a486 (Cantin, 25/11 ; note d'a479 « économie B/T ») : table 2 de l'économie (Config/Economy : raretés × 60, zone 6 à
	-- Speed 30T, tapis à 6 crédits par seconde et 25 niveaux, prix refaits, classements à part, profils convertis au
	-- chargement dans les deux sens). Lu par Config/Economy seul, au chargement : chaque module de Config prend ses
	-- nombres dans la table active, aucun service ne lit cet interrupteur. Interrupteur PROD (partout) : false (règle
	-- C2 : pas encore de test humain) ; false = la table 1, l'économie d'avant, intacte. Pas dans LiveFeatures.Hot :
	-- une clé Feature_EconomyBT du Creator Hub est prise au prochain serveur.
	EconomyBT = false,
	-- a486 : la même chose allumée dans le jeu DEV seulement (game.GameId = DevGameId, Config/Economy.IsDev) ; le jeu
	-- DEV lit alors un store de profils neuf (Economy, DevStoreName de la table 2 : profils DEV remis à zéro).
	EconomyBTDev = true,
	-- a486 (Cantin, 25/11) : la renaissance avec la table 2 de l'économie. false partout, DEV compris : avec la table 2
	-- la renaissance est coupée (montants à resimuler), quel que soit Features.Rebirth (Config/Rebirths.Enabled). Avec
	-- la table 1, Features.Rebirth garde seul son effet.
	RebirthBT = false,
	-- a486 (Cantin, 25/11 ; note d'a479, section 5) : modèle de chance « R2, sans plafond » (Config/ShelfOpen.LuckV2,
	-- Shared/OpenLuck) : chance achetée = personnelle (×3, 30 min) × arbre (BoxLuck) × serveur ; à l'ouverture d'un
	-- colis les taux du ×8 et du ×10 sont multipliés par elle (pris sur le ×1) et le ×N tiré aussi ; la chance du
	-- serveur augmente en plus la rareté des colis mis en rayon, les mutations d'effet et, avec la chance personnelle,
	-- la roue. Indépendant de EconomyBT. Interrupteur PROD (partout) : false (règle C2) ; false = la chance d'a476.
	LuckModelV2 = false,
	-- a486 : la même chose allumée dans le jeu DEV seulement (Config/ProductIds.IsDev), comme les autres nouveautés.
	LuckModelV2Dev = true,
	-- a440 (lot 6 du check-up a417, R13 ; décision C1 de Cantin, 24/11 : « colis de zone partout ») : plus de types de
	-- colis Standard / Premium / Luxe hors des rayons. Le camion, les cadeaux du jour J2 et J4 et les codes « Item »
	-- donnent un colis de zone (Shared/ZoneBoxOdds ; ancien type → règle : Config/Rewards.TierZoneBox), la Fortune Tower
	-- tire ses caisses dans Config/FortuneTower.ZoneBox (Shared/ZoneBoxEverywhere). J7 est un colis Épique ou mieux,
	-- allumé comme coupé ; aucune migration de profil (aucun colis typé n'y reste). Interrupteur PROD (partout) : false
	-- (règle C2 : pas encore de test humain) ; false = les types et leurs tables (Balance.Heist.BoxTiers,
	-- Rarities.BoxOdds), comme avant.
	ZoneBoxEverywhere = false,
	-- a440 : la même chose allumée dans le jeu DEV seulement (Config/ProductIds.IsDev), comme les autres nouveautés.
	ZoneBoxEverywhereDev = true,
	-- a459 (L-354, Clément 24/11) ; a459b, a459c (L-367, règle finale de Cantin 25/11) : sur un présentoir, la vraie taille
	-- du modèle × le facteur de sa rareté (minimum / modèle médian de la rareté, au moins ×1, Config/DisplaySize : 4, 5 ou 7 studs),
	-- remontée au minimum si elle reste en dessous, puis grossie par le poids (×1 à ×1,25 / ×1,5 / ×2), réduite seulement
	-- par la place physique (plafond du présentoir, voisins), au lieu de la taille de son poids.
	-- Interrupteur PROD (partout) : false (règle C2 : pas encore de test humain) ; false = taille du poids et FitSize, comme avant.
	DisplayRaritySize = false,
	-- a459 : la même chose allumée dans le jeu DEV seulement (Config/ProductIds.IsDev), comme les autres nouveautés.
	DisplayRaritySizeDev = true,
	-- a491 (L-429, idée 10 de « pousser un œuf », validée par Clément le 26/11 ; Config/DisplaySize.Trophies) : trophées
	-- plus gros. Sur un présentoir, un objet a au moins 2,5 studs de haut à ×1 (5 studs à 10 kg, la hauteur du perso) ; un
	-- objet plat est compté par la moitié de son plus grand côté. Avec la taille par rareté (DisplayRaritySize) : la plus
	-- grande des deux tailles. Puis la place physique réduit, comme avant. Le colis de l'ouverture a 3 studs de haut au
	-- départ (0,6 fois le perso), puis grossit de UpgradeGrow par amélioration, comme avant ; les colis des rayons ne
	-- changent pas. Interrupteur PROD (partout) : false (règle C2 : pas encore de test humain) ; false = comme avant.
	BiggerTrophies = false,
	-- a491 : la même chose allumée dans le jeu DEV seulement (Config/ProductIds.IsDev), comme les autres nouveautés.
	BiggerTrophiesDev = true,
	-- a496 (règle de Cantin, 26/11 ; Config/DisplaySize, étapes 1 à 3) : le minimum de taille par rareté (facteur du modèle
	-- médian, minimum 4, 5 ou 7 studs, grossissement par le poids) vaut partout : en main (HeldItemService), porté
	-- (CarryService), au sol (DisplayService.BuildFloorItem) et à l'ouverture dans le magasin PNJ (StoreHeistService :
	-- l'objet du rayon et la taille envoyée à RevealController). Hors présentoir, l'objet prend la plus grande des deux
	-- tailles (rareté, poids), sans plafond (ni Weight.HeldMaxScale ni Weight.CarryMaxScale) ; le présentoir et le socle
	-- « BEST ITEM » ne changent pas. Interrupteur PROD (partout) : false (règle C2 : pas encore de test humain) ;
	-- false = la taille du poids et ses plafonds, comme avant.
	RaritySizeEverywhere = false,
	-- a496 : la même chose allumée dans le jeu DEV seulement (Config/ProductIds.IsDev), comme les autres nouveautés.
	RaritySizeEverywhereDev = true,
	-- a459 (L-306, Cantin 25/11) : l'objet du socle du plus rare (RarestDisplay, copie RarestItem de VfxController) flotte
	-- exactement comme sur les présentoirs (ItemIdleController, Config/DisplayMotion). Interrupteur PROD (partout) : false
	-- (règle C2) ; false = l'objet du socle reste immobile, comme avant.
	RarestFloat = false,
	-- a459 : la même chose allumée dans le jeu DEV seulement (Config/ProductIds.IsDev), comme les autres nouveautés.
	RarestFloatDev = true,
	-- a485 (L-351 question 2, réponse de Clément du 25/11 : V0 gardés) : le gamepass ×2 Training devient « ×4 Training »
	-- (×4, nom et effet de Config/Monetization) et ne se cumule plus avec ×2 Speed : le plus fort des deux compte
	-- (Monetization.TrainingMultiplier, lu par MonetizationService et HudMenuController). Interrupteur PROD (partout) :
	-- false (règle C2) ; false = « ×2 Training » et ×2 Speed font chacun ×2 et se multiplient (×4 avec les deux), comme avant.
	TrainingX4 = false,
	-- a485 : la même chose allumée dans le jeu DEV seulement (Config/ProductIds.IsDev), comme les autres nouveautés.
	TrainingX4Dev = true,
	-- a485 (L-351, brief point 5) : la carte « +4 Displays » de la boutique Robux ne se montre que si la boutique du joueur a
	-- ses présentoirs bonus DisplaySlot_21 à _24 (Floor_2 compris ; attribut ExtraStandsReady posé par MonetizationService,
	-- lu par RobuxShopController ; gamepass déjà possédé : carte « Owned » montrée). Interrupteur PROD (partout) : false
	-- (règle C2) ; false = la carte se montre toujours, comme avant.
	ExtraStandsGate = false,
	-- a485 : la même chose allumée dans le jeu DEV seulement (Config/ProductIds.IsDev), comme les autres nouveautés.
	ExtraStandsGateDev = true,
	-- a485 (L-351 question 6) : dans un serveur privé payant (game.PrivateServerOwnerId ≠ 0), les classements de la semaine
	-- ne comptent rien : aucune écriture, ni revenu ni vol de la semaine qui monte (WeeklyLeaderboardService). Interrupteur
	-- PROD (partout) : false (règle C2) ; false = un serveur privé compte comme les autres, comme avant.
	WeeklyNoPrivate = false,
	-- a485 : la même chose allumée dans le jeu DEV seulement (Config/ProductIds.IsDev), comme les autres nouveautés.
	WeeklyNoPrivateDev = true,
	-- a492 (L-430, Clément 26/11 : « Quand un panneau est ouvert, tous les autres UI doivent disparaître. ») : tant qu'une
	-- fenêtre est ouverte (Config/UiMotion.Windows, PanelFocus.Extra, ou un ScreenGui avec l'attribut Focus ou HideHud =
	-- true), tous les autres écrans UI_* sont cachés (Controllers/UI/PanelFocus, HudMask) sauf PanelFocus.Keep et
	-- HeistFeel.NeverMask, puis remis tels qu'ils étaient ; en ouvrir une ferme l'autre (UI/Motion). Client seul.
	-- Interrupteur PROD (partout) : false (règle C2) ; false = HudHide d'avant (seuls UI_HUD et UI_Hotbar cachés), intact.
	PanelFocus = false,
	-- a492 : la même chose allumée dans le jeu DEV seulement (Config/ProductIds.IsDev), comme les autres nouveautés.
	PanelFocusDev = true,
	-- a503 (décision de Cantin du 26/11) : PvP libre à la batte dans le couloir. Hors zone safe, n'importe qui frappe
	-- n'importe qui à tout moment ; en zone safe, seule la défense de sa boutique (propriétaire ou bot) ; plus
	-- d'immunité après un coup ; un coup dans le couloir éjecte la cible en ragdoll puis l'assomme (BatService,
	-- Config/Bat, Shared/Ragdoll). Interrupteur PROD (partout) : false (règle C2) ; false = la batte d'avant, intacte
	-- (porteurs seulement, immunité de 3 s, recul sans ragdoll). Lu à chaque coup (Config/LiveFeatures.Hot).
	BatFreePvP = false,
	-- a503 : la même chose allumée dans le jeu DEV seulement (Config/ProductIds.IsDev), comme les autres nouveautés.
	BatFreePvPDev = true,
	-- a456 (L-334, Clément 24/11 : « tes vitres te bloquent aussi, tu sors par la porte ») : dans sa boutique, le
	-- propriétaire ne traverse plus que sa porte (PlotDoor/Window) ; les murs invisibles PlotBarrier et Stage_j/Barriers
	-- restent solides pour lui comme pour les autres (PlotDoorController, client seul). Interrupteur PROD (partout) :
	-- false (règle C2 : pas encore de test humain) ; false = le propriétaire traverse ses murs, comme avant (L-050).
	OwnerSolidWalls = false,
	-- a456 : la même chose allumée dans le jeu DEV seulement (Config/ProductIds.IsDev), comme les autres nouveautés.
	OwnerSolidWallsDev = true,
	-- a508 (L-474 point 1, chef UI 26/11) : récompense réclamée, DailyClaimButton et WeeklyClaimButton de UI_Rewards prennent
	-- le dégradé gris ClaimedGradient de Clément (UIGradient caché dans le bouton, par exemple Face.ClaimedGradient) à la
	-- place de leurs autres UIGradient voisins, rendus tels quels ensuite (RewardsController). Sans ClaimedGradient : rien ne
	-- change. Interrupteur PROD (partout) : false (règle C2) ; false = le bouton d'avant, intact.
	RewardsClaimedGrey = false,
	-- a508 : la même chose allumée dans le jeu DEV seulement (Config/ProductIds.IsDev), comme les autres nouveautés.
	RewardsClaimedGreyDev = true,
	-- a508 (L-475 point 2, Clément 26/11 : textes des tuiles de 5 à 8 px sur téléphone) : sur téléphone (tactile sans
	-- clavier), l'arbre de compétences s'ouvre zoomé à UiMotion.SkillTree.PhoneZoom, centré sur la dernière tuile achetée ;
	-- le glisser déplace, le pincement va jusqu'à PhoneZoomMax (SkillTreeController, SkillTree/Nav). Interrupteur PROD
	-- (partout) : false (règle C2) ; false = l'ouverture d'avant (zoom StartTilePx, centre de l'arbre), intacte.
	SkillTreePhoneZoom = false,
	-- a508 : la même chose allumée dans le jeu DEV seulement (Config/ProductIds.IsDev), comme les autres nouveautés.
	SkillTreePhoneZoomDev = true,
}

export type Features = typeof(Features)

local frozen = DeepFreeze(Features)

-- a442 (25/11, check-up a417 P5, décision C2 de Cantin) : dans un vrai jeu Roblox, la table vivante de Shared/LiveFeatures
-- (surcharges sans republier : ConfigService, commande d'admin ; voir son en-tête) ; ailleurs (bancs hors Studio, outils,
-- Edit) ou sans ce module : la table gelée du fichier, comme avant. Les lignes ci-dessus restent la valeur par défaut.
if type(game) == "userdata" then
	local module = script.Parent.Parent:FindFirstChild("LiveFeatures")
	if module ~= nil and module:IsA("ModuleScript") then
		local ok, wrapped = pcall(function(): any
			return (require(module :: any) :: any).Wrap(frozen, script)
		end)
		if ok and type(wrapped) == "table" then
			return wrapped :: Features
		end
		warn(`[Features] Shared/LiveFeatures en erreur, le fichier seul : {wrapped}`)
	end
end

return frozen
