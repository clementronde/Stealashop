--!strict
-- Interrupteurs des fonctions pas encore livrées (DEV-021 ; décision d'Ironix du 2026-11-07,
-- liaison L-026). false = la fonction n'existe pas encore : ses éléments d'UI sont cachés
-- (HudController). Repasser un interrupteur à true suffit à les réafficher, tels que Clément
-- les a posés (le code ne force jamais Visible = true). NightCycle coupe aussi son service serveur (NightCycleService)
-- et le ciel animé (SkyController). Le retour base (DEV-045, ReturnToBase) est retiré du code (a438, 24/11).
-- TruckEvent n'a pas d'UI : false coupe TruckEventService (aucun camion) et TruckController.
-- RobuxShop coupe aussi toute la boutique Robux (DEV-100) : MonetizationService (ni ProcessReceipt,
-- ni gamepass, ni bonus de revenus, ni effet) et RobuxShopController (écran UI_RobuxShop, comptoir).
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
	Traps = true,
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
	Bodyguards = true, -- agent de sécurité qui poursuit le voleur (Partie 2, section 2)
	DoorGuard = true, -- garde à la porte qui repousse le voleur (L-163)
	CameraRadar = true, -- Cameras niveau 3 : voleur en rouge vif et son de radar, sans flèche (L-163, L-175)
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
}

export type Features = typeof(Features)

return DeepFreeze(Features)
