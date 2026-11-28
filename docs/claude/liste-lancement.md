# Liste de lancement : tableau des fonctions

Généré par `tools/ironix/tableau-lancement.py` sur le commit `27d5fbdd`. Ne pas éditer à la main : relancer le script.

Sources : `src/shared/Config/Features.luau` (valeurs du fichier, sans clé du Creator Hub), `docs/claude/interrupteurs-test.md` (descriptions), la liaison (tests ouverts de « Tests à faire » ; T- relié par le commentaire de l'interrupteur ou par une ligne L- qu'il cite).

- **PROD** = valeur de `X` ; **DEV** = `X` ou `XDev`. Une fonction sans `XDev` a la même valeur partout.
- **Tests ouverts** : encore dans la liste. **Hors liste** : passé ou retiré (sans objet) ; le script ne sait pas lequel.
- **Lancement ?** : la case que Cantin remplit (oui / non).


## A. Déjà allumées en PROD (à garder ou à éteindre) — 27

| Lancement ? | Interrupteur | Ce que ça fait | PROD | DEV | Tests ouverts | Hors liste | Lignes L- |
| --- | --- | --- | --- | --- | --- | --- | --- |
|  | `RobuxShopPreview` | Bouton Shop et boutique en vitrine, sans achat, tant que la boutique est éteinte | oui | oui | — | — | L-071 |
|  | `Index` | Index des objets | oui | oui | — | — | L-071 |
|  | `Rebirth` | Renaissance (voir le piège plus bas : coupée sur DEV et TEST par la nouvelle économie) | oui | oui | T-190, T-195 | — | L-216, L-231 |
|  | `NightCycle` | Cycle jour / nuit (mur du couloir, vigiles de nuit, ciel) | oui | oui | — | — | — |
|  | `AntiCheat` | Contrôle des déplacements (anti-triche) | oui | oui | — | — | — |
|  | `TruckEvent` | Événement du camion | oui | oui | — | — | L-049 |
|  | `Settings` | Bouton et écran des réglages | oui | oui | — | — | L-095 |
|  | `FortuneTower` | Événement de la Fortune Tower (il faut le modèle dans la map) | oui | oui | T-058 | — | L-108, L-145 |
|  | `WeeklyChest` | Coffre hebdomadaire | oui | oui | — | — | — |
|  | `WitnessCrowd` | Foule de PNJ qui filme le voleur à la sortie d'un magasin | oui | oui | — | — | L-210 |
|  | `Quests` | Quêtes quotidiennes | oui | oui | — | — | — |
|  | `Wheel` | Roue de la fortune du hub, un tour gratuit par jour | oui | oui | — | — | — |
|  | `HeistPartnerBonus` | Prime au complice d'un braquage à deux | oui | oui | T-195 | T-203, T-216 | L-216, L-235 |
|  | `UiAttrFx` | Effets d'UI posés par Clément (reflets, survol, balancement) | oui | oui | — | — | — |
|  | `FramewispFx` | Effets des boutons faits avec Framewisp ; demande `UiAttrFx` allumé | oui | oui | — | — | — |
|  | `ShopSpy` | Étiquettes des objets d'un autre joueur visibles à travers sa façade | oui | oui | — | — | — |
|  | `Badges` | Badges du jeu (sur TEST, aucun badge n'est donné de toute façon) | oui | oui | — | — | — |
|  | `ExperienceNotifications` | Notifications Roblox hors du jeu (demande d'accord, envois) | oui | oui | — | — | — |
|  | `IndexMutations` | Mutations déjà obtenues visibles dans l'index | oui | oui | — | — | — |
|  | `ShopFloor2` | 2e étage de la boutique (il faut le modèle `Floor_2`) | oui | oui | T-111, T-190, T-282 | — | L-217, L-231, L-277, L-294 |
|  | `ArmoredVan` | Fourgon blindé toutes les 30 min dans le couloir | oui | oui | — | — | — |
|  | `WeeklyLeaderboards` | Classements de la semaine ($/s et vols) | oui | oui | — | — | — |
|  | `Analytics` | Mesures envoyées au tableau de bord Roblox | oui | oui | — | — | — |
|  | `FittingRoom` | Cabine d'essayage : déguisement, dénonciation | oui | oui | T-287 | — | L-113 |
|  | `Gamepad` | Jeu à la manette (menus, boutons B, L1 / R1) | oui | oui | — | — | — |
|  | `SafeZoneSpeed` | Même vitesse pour tous en zone safe, léger ralenti si l'on porte un objet volé | oui | oui | T-317 | — | L-319 |
|  | `DenounceRecover` | Le voleur attrapé après une dénonciation donne son objet au dénonciateur | oui | oui | T-320 | — | L-328 |

## B. Éteintes en PROD, allumées en DEV, aucun test ouvert (test passé ou retiré : à confirmer) — 0

| Lancement ? | Interrupteur | Ce que ça fait | PROD | DEV | Tests ouverts | Hors liste | Lignes L- |
| --- | --- | --- | --- | --- | --- | --- | --- |

## C. Éteintes en PROD, allumées en DEV, au moins un test ouvert — 54

| Lancement ? | Interrupteur | Ce que ça fait | PROD | DEV | Tests ouverts | Hors liste | Lignes L- |
| --- | --- | --- | --- | --- | --- | --- | --- |
|  | `RobuxCrate` (+ `RobuxCrateDev`) | Caisse exclusive dans la boutique Robux | non | oui | T-133, T-139 | T-138 | L-200, L-204 |
|  | `Traps` (+ `TrapsDev`) | Pièges de la boutique (tuile de l'arbre achetable) | non | oui | T-059, T-195, T-247, T-256 | T-026, T-028 | L-163, L-216, L-218 |
|  | `NewTraps` (+ `NewTrapsDev`) | Nouvelle disposition des pièges (banane, trappe) ; demande les pièges allumés | non | oui | T-190, T-256 | — | L-218, L-231, L-268 |
|  | `BotWalk` (+ `BotWalkDev`) | a539 (L-506) : le robot de la boutique (BotService) joue Walk en revenant à sa place, au lieu de Run ; T-453 pas encore passé (C2) : false en PROD, allumé en DE… | non | oui | T-453 | — | L-506 |
|  | `MutationTextureTint` (+ `MutationTextureTintDev`) | a542 (L-512, Clément 28/11 : « l'effet diamant, tout est bleu ») : sur les objets texturés, une mutation dont FX_Mutation_<Id> porte TextureMode = "Tint" teint … | non | oui | T-462 | — | L-512 |
|  | `ArmoredVanBurst` (+ `ArmoredVanBurstDev`) | a509 (L-457, Clément 26/11) : à la casse du fourgon, le colis de chaque casseur récompensé jaillit derrière lui et s'ouvre sur place comme ceux du camion (n'imp… | non | oui | T-397, T-445 | — | L-457 |
|  | `CameraRadar` (+ `CameraRadarDev`) | Caméras niveau 3 : voleur en rouge vif et bip de radar | non | oui | T-059, T-161 | T-026, T-028, T-159 | L-163, L-175 |
|  | `Cameras` (+ `CamerasDev`) | Tuile Caméras niveaux 1 et 2 (alerte, voleur surligné) | non | oui | T-358 | — | L-373 |
|  | `ShopGlassThrow` (+ `ShopGlassThrowDev`) | L'intrus frappé par le propriétaire traverse la vitre en ragdoll | non | oui | T-288 | — | L-291 |
|  | `ShopBackPieceOffset` (+ `ShopBackPieceOffsetDev`) | a540 (L-509, Clément 27/11) : boutique coupée, les pièces fines du fond (ShopStageService) sont posées ShopGrowth.BackPieceOffset derrière le nouveau fond : plu… | non | oui | T-456 | — | L-509 |
|  | `ItemsV3` (+ `ItemsV3Dev`) | Catalogue d'objets v3 (objets drôles, boucles animées) ; les objets des profils sont renommés | non | oui | T-321 | — | L-327, L-339 |
|  | `BdOutlines` (+ `BdOutlinesDev`) | Contours « façon BD » sur ce qui est interactif | non | oui | T-307, T-325 | — | L-305, L-344 |
|  | `BdOutlinesHub` (+ `BdOutlinesHubDev`) | Ces contours toujours visibles dans le hub et sa boutique ; demande `BdOutlinesDev` allumé | non | oui | T-325 | — | L-305, L-369 |
|  | `HeistTension` (+ `HeistTensionDev`) | Tension pendant le vol : flèches au sol jusqu'à sa boutique, vigile surligné, chrono | non | oui | T-303 | — | L-340 |
|  | `StealMusic` (+ `StealMusicDev`) | Musique du vol, musique de la victime, musique du braquage d'une boutique | non | oui | T-161, T-334 | — | L-377, L-385 |
|  | `PadPredict` (+ `PadPredictDev`) | Son et flash des plaques d'argent joués tout de suite, sans attendre le serveur | non | oui | T-331 | — | L-365 |
|  | `InventoryScreen` (+ `InventoryScreenDev`) | Le bouton du sac ouvre l'inventaire au lieu des objets exposés | non | oui | T-330, T-346 | — | L-364, L-380 |
|  | `SecuredFireworks` (+ `SecuredFireworksDev`) | Feux d'artifice vus de tous quand un objet est ramené en zone safe | non | oui | T-355, T-367 | — | L-371 |
|  | `AuraCarryMode` (+ `AuraCarryModeDev`) | a541 (L-511, piste A, Clément 28/11) : pendant qu'un joueur porte (attribut Carrying du Player, CarryService), chez tous les joueurs, chaque Attachment de son a… | non | oui | T-461 | — | L-511 |
|  | `SecuredCardV2` (+ `SecuredCardV2Dev`) | a521 (L-405, Clément 25 et 26/11) : carte ITEM SECURED spectaculaire (Controllers/Escape/SecuredCard, réglages Config/SecuredCard) : l'objet en 3D dans Card.Pre… | non | oui | T-368, T-423, T-449 | — | L-405 |
|  | `SafeLineFlash` (+ `SafeLineFlashDev`) | a521 (L-465, Clément 26/11) : à l'arrivée en zone safe, UI_Escape.Flash plein sur 2 images puis effacé en 0,15 s, à la couleur de la rareté de l'objet ; Card 0,… | non | oui | T-405, T-449 | — | L-465 |
|  | `CrossServerAnnounce` (+ `CrossServerAnnounceDev`) | a521 (L-405, Clément 25/11 : « oui les plus grosses ») : un objet ramené de très grande valeur (ou un Secret) est annoncé sur les autres serveurs (MessagingServ… | non | oui | T-368, T-423, T-449 | — | L-405 |
|  | `ValueAnnounce` (+ `ValueAnnounceDev`) | Annonces à tout le serveur pour les objets de grande valeur | non | oui | T-355 | — | L-372 |
|  | `SkillBoxLuck` (+ `SkillBoxLuckDev`) | Tuile « chance des colis » de l'arbre achetable | non | oui | T-356 | — | L-374 |
|  | `ServerLuck` (+ `ServerLuckDev`) | Chance du serveur vendue en Robux (avec la boutique) | non | oui | T-214 | — | L-375 |
|  | `UnboxBoxClimb` (+ `UnboxBoxClimbDev`) | Caisse exclusive : le colis monte d'une rareté à chaque coup, avec le bon modèle de colis | non | oui | T-357 | — | L-281, L-356 |
|  | `UnboxLuckClimb` (+ `UnboxLuckClimbDev`) | Pendant les coups sur un colis, c'est le « ×N LUCK » qui monte ; le « 1 IN N » vient à la fin | non | oui | T-335 | — | L-376 |
|  | `UnboxHitLuck` (+ `UnboxHitLuckDev`) | a523 (L-462, Clément 26/11 : « chaque coup de l'animation fait monter la luck ») : pendant l'ouverture d'un colis de rayon, la chance tirée est la base, puis de… | non | oui | T-335, T-402 | — | L-376, L-462 |
|  | `LuckTiers` (+ `LuckTiersDev`) | a523 (L-442, Clément 27/11 : « plein de versions en fonction des paliers de luck ») : le compteur « ×N LUCK » (BB_ShelfOpen.Row.Luck, BB_UnboxOdds.Odds) prend l… | non | oui | T-382, T-451 | — | L-442 |
|  | `WeightIncomeV2` (+ `WeightIncomeV2Dev`) | a513 (Cantin, 27/11 ; liaison L-444 b) : poids → revenu proportionnel (10 kg ×1, 100 kg ×10, 10 000 kg ×1 000 : Config/Weight.IncomeExponentV2), paliers de poid… | non | oui | T-373, T-384, T-441, T-442 | — | L-444 |
|  | `DisplayRaritySize` (+ `DisplayRaritySizeDev`) | Taille des objets exposés selon leur rareté | non | oui | T-314 | — | L-354, L-367 |
|  | `BiggerTrophies` (+ `BiggerTrophiesDev`) | Objets exposés plus gros (au moins 2,5 studs de haut) | non | oui | T-370 | — | L-429 |
|  | `UnboxSpacingV2` (+ `UnboxSpacingV2Dev`) | a536 (L-502 et L-504, recette du chef animation du 28/11 ; Config/Unbox.New StandFaceGap à EndStandMinGap, Controllers/Reveal/Unbox) : espacement v2 de l'ouvert… | non | oui | T-458, T-459 | — | L-502, L-504 |
|  | `UnboxToolGrip` (+ `UnboxToolGripDev`) | a536 (L-508, Controllers/Reveal/Unbox.takeTool et poseTool) : un TOOL_Unbox_* livré en Tool est posé dans la main avec son Grip (Handle = RightGripAttachment × … | non | oui | T-455 | — | L-508 |
|  | `RarestFloat` (+ `RarestFloatDev`) | L'objet du socle du plus rare flotte comme sur les présentoirs | non | oui | T-363 | — | L-306 |
|  | `TrainingX4` (+ `TrainingX4Dev`) | Le gamepass « ×2 Training » devient « ×4 Training », sans se cumuler avec ×2 Speed | non | oui | T-360, T-361 | — | L-351 |
|  | `ExtraStandsGate` (+ `ExtraStandsGateDev`) | La carte « +4 Displays » n'apparaît que si la boutique a ses présentoirs bonus | non | oui | T-360, T-361 | — | L-351 |
|  | `WeeklyNoPrivate` (+ `WeeklyNoPrivateDev`) | Les serveurs privés payants ne comptent pas dans les classements de la semaine | non | oui | T-360, T-361 | — | L-351 |
|  | `PanelFocus` (+ `PanelFocusDev`) | Quand une fenêtre est ouverte, les autres écrans disparaissent | non | oui | T-372 | — | L-430 |
|  | `OwnerSolidWalls` (+ `OwnerSolidWallsDev`) | a456 (L-334, Clément 24/11 : « tes vitres te bloquent aussi, tu sors par la porte ») : dans sa boutique, le propriétaire ne traverse plus que sa porte (PlotDoor… | non | oui | T-440 | — | L-050, L-334 |
|  | `RewardsClaimedGrey` (+ `RewardsClaimedGreyDev`) | a508 (L-474 point 1, chef UI 26/11) : récompense réclamée, DailyClaimButton et WeeklyClaimButton de UI_Rewards prennent le dégradé gris ClaimedGradient de Cléme… | non | oui | T-414, T-439 | — | L-474 |
|  | `SkillTreePhoneZoom` (+ `SkillTreePhoneZoomDev`) | a508 (L-475 point 2, Clément 26/11 : textes des tuiles de 5 à 8 px sur téléphone) : sur téléphone (tactile sans clavier), l'arbre de compétences s'ouvre zoomé à… | non | oui | T-415, T-439 | — | L-475 |
|  | `GuardScale` (+ `GuardScaleDev`) | a518 (L-437, Clément 27/11 : « les vigiles doivent être 1,5 fois plus gros que les joueurs ») : chaque vigile de magasin et de nuit en jeu est mis à Config/Guar… | non | oui | T-378, T-446 | — | L-437 |
|  | `GuardDayPatrol` (+ `GuardDayPatrolDev`) | a518 (L-438, Clément 27/11 : « les vigiles doivent tourner dans le magasin au lieu qu'ils apparaissent de nulle part ») : un vigile par magasin PNJ fait sa rond… | non | oui | T-379, T-446 | — | L-438 |
|  | `GuardCatchRagdoll` (+ `GuardCatchRagdollDev`) | a518 (L-426, Clément 25/11 et 26/11) : attrapé par un vigile de magasin, le voleur part en ragdoll assez loin (Guard/CatchRagdoll, Config/Guards.CatchRagdoll), … | non | oui | T-446 | — | L-426 |
|  | `GuardCatchRagdollOnly` (+ `GuardCatchRagdollOnlyDev`) | a537 (L-501, Clément 28/11 : « Ragdoll seul ») : à la capture de jour en ragdoll (GuardCatchRagdoll ci-dessus), seul le ragdoll se joue : plus de Knockdown pend… | non | oui | T-457 | — | L-501 |
|  | `StrikeFeel` (+ `StrikeFeelDev`) | a519 (L-448, Clément 26/11, repasse animation point 12) : coups plus secs et course portée calée, sur le joueur local (Shared/Anim/StrikeFeel, valeurs Config/An… | non | oui | T-388, T-447 | — | L-448 |
|  | `HitVariants` (+ `HitVariantsDev`) | a538 (L-505, Clément 27/11) : coups variés, une série de Hit_* par arme (Config/Tools.HitAnimations), tirée au hasard à chaque frappe de vitrine, jamais le même… | non | oui | T-452 | — | L-505 |
|  | `OpenNowOnLocked` (+ `OpenNowOnLockedDev`) | a520 (L-410, Clément 25/11 : « skip le temps en cliquant sur E ») : E sur son objet posé encore sous antivol ouvre la fenêtre d'achat d'Open Now (palier choisi … | non | oui | T-448 | — | L-410 |
|  | `DawnBoxAnnounce` (+ `DawnBoxAnnounceDev`) | a457 (L-335 point 2, Clément 24/11) : l'annonce des caisses rares part au lever du jour (fin de la nuit), une seule phrase « A LEGENDARY box is in Zone 6! » (Co… | non | oui | T-299, T-343, T-395 | — | L-335 |
|  | `ShopInfoSafeZone` (+ `ShopInfoSafeZoneDev`) | a457 (L-335 point 3, Clément 24/11) : les panneaux BB_ShopInfo des boutiques des autres s'allument dès que le joueur local est dans une zone `SafeZone` (Shared/… | non | oui | T-299, T-343, T-395 | — | L-335 |
|  | `ServerWinSound` (+ `ServerWinSoundDev`) | a522 (L-455, Clément 26/11) : un objet ramené en zone safe fait entendre aux autres joueurs le son de victoire du serveur Heist_ServerWin, en 3D à l'endroit où … | non | oui | T-299, T-395 | — | L-455 |
|  | `GainFlyToCounter` (+ `GainFlyToCounterDev`) | a524 (L-447, Clément 26/11, repasse point 11) : les billets d'un gain ponctuel (récompense, prime de l'index) et des gains hors ligne réclamés s'écartent d'abor… | non | oui | T-387, T-450 | — | L-447 |
|  | `DisplayPlaceMoment` (+ `DisplayPlaceMomentDev`) | a524 (L-466, Clément 26/11) : objet posé sur un présentoir chez le joueur local (GainController.incomeFly) : l'objet blanc puis ses couleurs (Highlight), « +$X/… | non | oui | T-406, T-450 | — | L-466 |

## E. Éteintes en PROD, allumées en DEV, aucun test relié trouvé par le script (à relier à la main) — 22

| Lancement ? | Interrupteur | Ce que ça fait | PROD | DEV | Tests ouverts | Hors liste | Lignes L- |
| --- | --- | --- | --- | --- | --- | --- | --- |
|  | `ChaseV3` (+ `ChaseV3Dev`) | Nouvelle poursuite du vigile (plus rapide, toujours derrière, éjection à la capture) | non | oui | — | — | — |
|  | `FullSpeedStick` (+ `FullSpeedStickDev`) | Au stick (manette, téléphone), on court toujours à pleine vitesse | non | oui | — | — | — |
|  | `ArmoredVanV2` (+ `ArmoredVanV2Dev`) | a516 (décision de Cantin, 27/11) : fourgon V2, jauge en 6 paliers de 25 s (zone 6 au départ, zone 1 à la fin), seuils de dégâts fixes, 12 colis de la zone du pa… | non | oui | — | — | — |
|  | `LoadingReal` (+ `LoadingRealDev`) | a532 (Cantin, 28/11) : vrai écran de chargement (ReplicatedFirst/First/LoadingScreen et LoadingFlow) : on entre dans le jeu quand le jeu, le profil, le personna… | non | oui | — | — | — |
|  | `NoIntactDoorEject` (+ `NoIntactDoorEjectDev`) | Plus de sortie forcée d'une boutique à la porte intacte | non | oui | — | — | — |
|  | `ShopInsideBackWall` (+ `ShopInsideBackWallDev`) | « Dans la boutique » s'arrête au mur du fond (plus de vol à travers le mur) | non | oui | — | — | — |
|  | `SkillOfflineTime` (+ `SkillOfflineTimeDev`) | Deux tuiles de l'arbre : +30 min de gains hors ligne chacune | non | oui | — | — | — |
|  | `StolenOutlineVictimOnly` (+ `StolenOutlineVictimOnlyDev`) | Le contour rouge d'un objet volé n'est vu que par la victime | non | oui | — | — | — |
|  | `TreadmillGainPops` (+ `TreadmillGainPopsDev`) | Gain du tapis affiché en 3D autour du joueur, avec un son | non | oui | — | — | — |
|  | `EquipBestOrder` (+ `EquipBestOrderDev`) | Equip Best range les objets dans l'ordre des présentoirs vu depuis l'entrée | non | oui | — | — | — |
|  | `UnboxClimbMatchesItem` (+ `UnboxClimbMatchesItemDev`) | La montée de rareté d'un colis de rayon suit l'objet tiré | non | oui | — | — | — |
|  | `EconomyBT` (+ `EconomyBTDev`) | Nouvelle économie « B/T » (table 2 : prix, raretés, tapis, classements à part) ; les profils sont convertis | non | oui | — | — | — |
|  | `LuckModelV2` (+ `LuckModelV2Dev`) | Nouveau calcul de la chance (achetée × arbre × serveur, sans plafond) | non | oui | — | — | — |
|  | `WeightTail` (+ `WeightTailDev`) | a528 (Cantin, 28/11) : poids sans limite au-dessus de 10 000 kg. a528a : étiquettes Titan (Weight.TitanFrom) et Cosmic (Weight.CosmicFrom) au-dessus de Colossal… | non | oui | — | — | — |
|  | `LuckAdditive` (+ `LuckAdditiveDev`) | a513 (Cantin, 27/11, « tout V0 ») : les bonus de chance s'additionnent comme le joueur les lit (×3 et ×2 donnent ×5 : la somme des bonus actifs, ×1 sans aucun) … | non | oui | — | — | — |
|  | `ZoneBoxEverywhere` (+ `ZoneBoxEverywhereDev`) | Colis de zone partout (camion, cadeaux, codes, Fortune Tower), plus de Standard / Premium / Luxe | non | oui | — | — | — |
|  | `RaritySizeEverywhere` (+ `RaritySizeEverywhereDev`) | Taille minimale par rareté partout : en main, porté, au sol, à l'ouverture | non | oui | — | — | — |
|  | `BatFreePvP` (+ `BatFreePvPDev`) | Batte libre dans le couloir : tout le monde frappe tout le monde, ragdoll, plus d'immunité | non | oui | — | — | — |
|  | `HeldIncomeAll` (+ `HeldIncomeAllDev`) | a469 (Cantin, 25/11) : le revenu de l'objet tenu en main (BB_HeldIncome, « $300/s ») vu par tous les joueurs, pas seulement le porteur (Config/HeldItem.IncomeFo… | non | oui | — | — | — |
|  | `HeldItemLevel` (+ `HeldItemLevelDev`) | a531 (L-500, Cantin 28/11) : objet de l'inventaire tenu en main redressé (Config/HeldItem.Pitch et Roll : il tourne sur lui-même, à la même place devant la main… | non | oui | — | — | L-500 |
|  | `BoxZoneTag` (+ `BoxZoneTagDev`) | a517 (demande de Cantin, 27/11) : étiquette « ZONE N » sur un colis d'une zone plus haute que celle de l'endroit (rayon d'événement du camion ou du fourgon) ou,… | non | oui | — | — | — |
|  | `AdminForceUnbox` (+ `AdminForceUnboxDev`) | a527 (Cantin, 28/11, pour une vidéo) : commande d'admin ForceNextUnbox (Config/Admin, AdminService) : l'admin choisit l'objet, le poids et la mutation de SON pr… | non | oui | — | — | — |

## D. Éteintes partout (pas prêtes, ou en attente d'une décision) — 5

| Lancement ? | Interrupteur | Ce que ça fait | PROD | DEV | Tests ouverts | Hors liste | Lignes L- |
| --- | --- | --- | --- | --- | --- | --- | --- |
|  | `RobuxShop` | Boutique Robux ouverte (gamepasses, produits, leurs effets) | non | non | — | — | — |
|  | `PlayerCollision` | `true` = les joueurs se bousculent comme avant ; `false` = ils se traversent (contre le « fling ») | non | non | — | — | — |
|  | `Bodyguards` (+ `BodyguardsDev`) | Agent de sécurité qui poursuit le voleur | non | non | T-059, T-285 | T-026, T-028 | L-163 |
|  | `DoorGuard` (+ `DoorGuardDev`) | Garde à la porte qui repousse le voleur | non | non | T-059 | T-026, T-028 | L-163 |
|  | `RebirthBT` | Renaissance permise avec la nouvelle économie | non | non | — | — | — |
