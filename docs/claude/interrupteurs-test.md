# Fiche des interrupteurs pour le jeu TEST

Pour Cantin : choisir ce qui est allumé sur le jeu TEST (« Steal a shop [TEST] ») **sans republier**.
Tout vient du code au 27/11 : `src/shared/Config/Features.luau` (les valeurs par défaut), `src/shared/Config/LiveFeatures.luau` et `src/shared/LiveFeatures.luau` (la lecture en ligne), `src/shared/Config/GameEnv.luau` (quel jeu est quel jeu). Si le code change, cette fiche peut prendre du retard : le code fait foi.

## Ce qu'il faut savoir avant

- Le code reconnaît trois jeux : **DEV**, **TEST** et **PROD**. Le jeu TEST se comporte **comme le DEV** (toutes les variantes `…Dev` y comptent), avec deux différences : **pas d'achat Robux** (la boutique répond « Not available in test ») et **aucun badge donné**. Ses profils sont à part (ni ceux du DEV ni ceux de la PROD).
- Chaque jeu a **ses propres Configs** dans le Creator Hub. Une clé posée sur le jeu TEST ne touche ni le DEV ni la PROD.
- Valeur d'un interrupteur, de la plus forte à la plus faible : la commande `/feature` sur ce serveur (seulement pour les interrupteurs « à chaud ») ; puis la clé `Feature_<Nom>` du Creator Hub ; puis la valeur écrite dans le fichier `Config/Features`. **Clé absente = valeur du fichier.**
- Beaucoup de nouveautés ont **deux lignes** : `X` (vaut partout, PROD comprise) et `XDev` (vaut seulement sur DEV et TEST). Le code allume la fonction si `X` est vrai **ou** si `XDev` est vrai dans un jeu DEV ou TEST. Comme `X` est à `false` et `XDev` à `true` dans le fichier, **sur TEST c'est la clé `Feature_XDev` qui compte** : la mettre à `false` éteint la fonction sur TEST. Mettre `Feature_X` à `false` ne change rien sur TEST, puisque `XDev` reste vrai.

## Marche à suivre (4 étapes)

1. **Créer la clé.** Creator Hub > le jeu **TEST** > **Configs**. Créer une clé de type **booléen** (vrai / faux) dont le nom est **exactement** celui de la colonne « Clé à créer » du tableau ci-dessous, par exemple `Feature_ChaseV3Dev`. Même casse, aucun espace.
2. **Publier la config.** Une clé pas encore publiée n'est pas lue par les serveurs.
3. **Avoir un nouveau serveur.** Sauf pour les interrupteurs marqués « à chaud », la clé n'est prise qu'**au démarrage d'un serveur**. Il faut donc soit lancer « Shut Down All Servers » sur le jeu TEST dans le Creator Hub, soit attendre qu'un nouveau serveur s'ouvre. Un serveur déjà ouvert garde l'ancienne valeur ; il note juste dans sa sortie « pris au prochain serveur ». Les interrupteurs « à chaud » changent sur les serveurs ouverts dès que Roblox leur annonce la nouvelle config, sans redémarrage.
4. **Vérifier en jeu avec `/feature`.** Taper `/feature` dans le chat du jeu TEST.
   - **Qui peut la lancer** : un admin selon la même règle que le panneau admin (`Config/Admin`) : le compte IRONIX01 (UserId 296770611), et le **propriétaire du groupe du studio** (rang 255 du groupe qui possède le jeu). En Studio, tout le monde. Pour les autres joueurs, la réponse est « Not allowed. » et rien ne change.
   - **Ce qu'elle affiche** : une notification, seulement pour l'admin, de la forme
     `Config: ok. Overrides: ChaseV3Dev = false (Config), …. Live: BatFreePvP, BatFreePvPDev, DenounceRecover, HeistPartnerBonus, IndexMutations, ShopGlassThrow, ShopGlassThrowDev`
     - `Config:` donne l'état de la lecture des Configs : `ok`, `waiting` (en attente), `error` ou `absent`.
     - `Overrides:` donne la liste des interrupteurs dont la valeur **ne vient pas du fichier**, avec leur valeur et la source : `(Config)` pour une clé du Creator Hub, `(Admin)` pour une commande `/feature`. Elle affiche `none` s'il n'y en a aucun. **Si ta clé n'apparaît pas ici, elle n'a pas été prise** (nom mal écrit, pas publiée, mauvais type, ou serveur trop ancien).
     - `Live:` donne la liste des interrupteurs à chaud.
     - Le message est **coupé à 200 caractères** : avec beaucoup de clés, la fin manque. La liste complète est dans la sortie du serveur (console F9 > Server), au démarrage : une ligne `[LiveFeaturesService] Config: …` et une ligne `[LiveFeatures] ConfigService au démarrage : …` avec chaque interrupteur changé.
   - **Autres commandes**, pour les seuls interrupteurs à chaud et sur ce seul serveur, jusqu'à sa fermeture : `/feature <Nom> on`, `/feature <Nom> off` et `/feature <Nom> reset` (retour à la clé du Creator Hub, ou au fichier). La casse du nom n'y compte pas. Pour un interrupteur qui n'est pas à chaud, la réponse est « <Nom> changes on the next server only (Creator Hub > Configs). ».

## Le tableau des interrupteurs

Colonnes : **Clé à créer** (sur le jeu TEST) ; **Ce que ça fait** ; les valeurs **DEV / TEST / PROD** telles que le joueur les vit sans aucune clé (« oui » = allumé) ; **Quand** : « serveur » = au prochain serveur, « à chaud » = sur les serveurs déjà ouverts.

Pour une paire `X` / `XDev`, la clé indiquée est `Feature_XDev` (celle qui compte sur TEST). En PROD, la même fonction s'allumerait avec `Feature_X` créée dans les Configs **du jeu PROD**.

### Braquage, poursuite, couloir

| Clé à créer | Ce que ça fait | DEV | TEST | PROD | Quand |
| --- | --- | --- | --- | --- | --- |
| `Feature_ChaseV3Dev` | Nouvelle poursuite du vigile (plus rapide, toujours derrière, éjection à la capture) | oui | oui | non | serveur |
| `Feature_HeistTensionDev` | Tension pendant le vol : flèches au sol jusqu'à sa boutique, vigile surligné, chrono | oui | oui | non | serveur |
| `Feature_StealMusicDev` | Musique du vol, musique de la victime, musique du braquage d'une boutique | oui | oui | non | serveur |
| `Feature_BatFreePvPDev` | Batte libre dans le couloir : tout le monde frappe tout le monde, ragdoll, plus d'immunité | oui | oui | non | **à chaud** |
| `Feature_HeistPartnerBonus` | Prime au complice d'un braquage à deux | oui | oui | oui | **à chaud** |
| `Feature_UnboxBoxClimbDev` | Caisse exclusive : le colis monte d'une rareté à chaque coup, avec le bon modèle de colis | oui | oui | non | serveur |
| `Feature_UnboxLuckClimbDev` | Pendant les coups sur un colis, c'est le « ×N LUCK » qui monte ; le « 1 IN N » vient à la fin | oui | oui | non | serveur |
| `Feature_UnboxClimbMatchesItemDev` | La montée de rareté d'un colis de rayon suit l'objet tiré | oui | oui | non | serveur |
| `Feature_ZoneBoxEverywhereDev` | Colis de zone partout (camion, cadeaux, codes, Fortune Tower), plus de Standard / Premium / Luxe | oui | oui | non | serveur |
| `Feature_SecuredFireworksDev` | Feux d'artifice vus de tous quand un objet est ramené en zone safe | oui | oui | non | serveur |
| `Feature_ValueAnnounceDev` | Annonces à tout le serveur pour les objets de grande valeur | oui | oui | non | serveur |
| `Feature_StolenOutlineVictimOnlyDev` | Le contour rouge d'un objet volé n'est vu que par la victime | oui | oui | non | serveur |
| `Feature_WitnessCrowd` | Foule de PNJ qui filme le voleur à la sortie d'un magasin | oui | oui | oui | serveur |
| `Feature_NightCycle` | Cycle jour / nuit (mur du couloir, vigiles de nuit, ciel) | oui | oui | oui | serveur |
| `Feature_TruckEvent` | Événement du camion | oui | oui | oui | serveur |
| `Feature_ArmoredVan` | Fourgon blindé toutes les 30 min dans le couloir | oui | oui | oui | serveur |
| `Feature_FortuneTower` | Événement de la Fortune Tower (il faut le modèle dans la map) | oui | oui | oui | serveur |
| `Feature_FittingRoom` | Cabine d'essayage : déguisement, dénonciation | oui | oui | oui | serveur |
| `Feature_DenounceRecover` | Le voleur attrapé après une dénonciation donne son objet au dénonciateur | oui | oui | oui | **à chaud** |

### Boutique du joueur et défense

| Clé à créer | Ce que ça fait | DEV | TEST | PROD | Quand |
| --- | --- | --- | --- | --- | --- |
| `Feature_TrapsDev` | Pièges de la boutique (tuile de l'arbre achetable) | oui | oui | non | serveur |
| `Feature_NewTrapsDev` | Nouvelle disposition des pièges (banane, trappe) ; demande les pièges allumés | oui | oui | non | serveur |
| `Feature_BodyguardsDev` | Agent de sécurité qui poursuit le voleur | oui | oui | non | serveur |
| `Feature_DoorGuardDev` | Garde à la porte qui repousse le voleur | oui | oui | non | serveur |
| `Feature_CamerasDev` | Tuile Caméras niveaux 1 et 2 (alerte, voleur surligné) | oui | oui | non | serveur |
| `Feature_CameraRadarDev` | Caméras niveau 3 : voleur en rouge vif et bip de radar | oui | oui | non | serveur |
| `Feature_ShopGlassThrowDev` | L'intrus frappé par le propriétaire traverse la vitre en ragdoll | oui | oui | non | **à chaud** |
| `Feature_NoIntactDoorEjectDev` | Plus de sortie forcée d'une boutique à la porte intacte | oui | oui | non | serveur |
| `Feature_ShopInsideBackWallDev` | « Dans la boutique » s'arrête au mur du fond (plus de vol à travers le mur) | oui | oui | non | serveur |
| `Feature_ShopFloor2` | 2e étage de la boutique (il faut le modèle `Floor_2`) | oui | oui | oui | serveur |
| `Feature_ShopSpy` | Étiquettes des objets d'un autre joueur visibles à travers sa façade | oui | oui | oui | serveur |
| `Feature_EquipBestOrderDev` | Equip Best range les objets dans l'ordre des présentoirs vu depuis l'entrée | oui | oui | non | serveur |
| `Feature_DisplayRaritySizeDev` | Taille des objets exposés selon leur rareté | oui | oui | non | serveur |
| `Feature_BiggerTrophiesDev` | Objets exposés plus gros (au moins 2,5 studs de haut) | oui | oui | non | serveur |
| `Feature_RaritySizeEverywhereDev` | Taille minimale par rareté partout : en main, porté, au sol, à l'ouverture | oui | oui | non | serveur |
| `Feature_RarestFloatDev` | L'objet du socle du plus rare flotte comme sur les présentoirs | oui | oui | non | serveur |

### Économie, progression, récompenses

| Clé à créer | Ce que ça fait | DEV | TEST | PROD | Quand |
| --- | --- | --- | --- | --- | --- |
| `Feature_EconomyBTDev` | Nouvelle économie « B/T » (table 2 : prix, raretés, tapis, classements à part) ; les profils sont convertis | oui | oui | non | serveur |
| `Feature_RebirthBT` | Renaissance permise avec la nouvelle économie | non | non | non | serveur |
| `Feature_Rebirth` | Renaissance (voir le piège plus bas : coupée sur DEV et TEST par la nouvelle économie) | non* | non* | oui | serveur |
| `Feature_LuckModelV2Dev` | Nouveau calcul de la chance (achetée × arbre × serveur, sans plafond) | oui | oui | non | serveur |
| `Feature_SkillBoxLuckDev` | Tuile « chance des colis » de l'arbre achetable | oui | oui | non | serveur |
| `Feature_SkillOfflineTimeDev` | Deux tuiles de l'arbre : +30 min de gains hors ligne chacune | oui | oui | non | serveur |
| `Feature_ItemsV3Dev` | Catalogue d'objets v3 (objets drôles, boucles animées) ; les objets des profils sont renommés | oui | oui | non | serveur |
| `Feature_Index` | Index des objets | oui | oui | oui | serveur |
| `Feature_IndexMutations` | Mutations déjà obtenues visibles dans l'index | oui | oui | oui | **à chaud** |
| `Feature_Quests` | Quêtes quotidiennes | oui | oui | oui | serveur |
| `Feature_Wheel` | Roue de la fortune du hub, un tour gratuit par jour | oui | oui | oui | serveur |
| `Feature_WeeklyChest` | Coffre hebdomadaire | oui | oui | oui | serveur |
| `Feature_WeeklyLeaderboards` | Classements de la semaine ($/s et vols) | oui | oui | oui | serveur |
| `Feature_WeeklyNoPrivateDev` | Les serveurs privés payants ne comptent pas dans les classements de la semaine | oui | oui | non | serveur |
| `Feature_Badges` | Badges du jeu (sur TEST, aucun badge n'est donné de toute façon) | oui | non* | oui | serveur |
| `Feature_ExperienceNotifications` | Notifications Roblox hors du jeu (demande d'accord, envois) | oui | oui | oui | serveur |

\* Rebirth : `true` dans le fichier, mais coupée par la table 2 de l'économie, active sur DEV et TEST. Badges : `true` dans le fichier, mais le jeu TEST n'en donne aucun.

### Boutique Robux

Sur le jeu TEST, **aucun achat n'est possible**, même boutique allumée : on voit les cartes, sans pouvoir payer.

| Clé à créer | Ce que ça fait | DEV | TEST | PROD | Quand |
| --- | --- | --- | --- | --- | --- |
| `Feature_RobuxShop` | Boutique Robux ouverte (gamepasses, produits, leurs effets) | non | non | non | serveur |
| `Feature_RobuxShopPreview` | Bouton Shop et boutique en vitrine, sans achat, tant que la boutique est éteinte | oui | oui | oui | serveur |
| `Feature_RobuxCrateDev` | Caisse exclusive dans la boutique Robux | oui | oui | non | serveur |
| `Feature_ServerLuckDev` | Chance du serveur vendue en Robux (avec la boutique) | oui | oui | non | serveur |
| `Feature_TrainingX4Dev` | Le gamepass « ×2 Training » devient « ×4 Training », sans se cumuler avec ×2 Speed | oui | oui | non | serveur |
| `Feature_ExtraStandsGateDev` | La carte « +4 Displays » n'apparaît que si la boutique a ses présentoirs bonus | oui | oui | non | serveur |

### Déplacements et contrôles

| Clé à créer | Ce que ça fait | DEV | TEST | PROD | Quand |
| --- | --- | --- | --- | --- | --- |
| `Feature_FullSpeedStickDev` | Au stick (manette, téléphone), on court toujours à pleine vitesse | oui | oui | non | serveur |
| `Feature_Gamepad` | Jeu à la manette (menus, boutons B, L1 / R1) | oui | oui | oui | serveur |
| `Feature_SafeZoneSpeed` | Même vitesse pour tous en zone safe, léger ralenti si l'on porte un objet volé | oui | oui | oui | serveur |
| `Feature_PlayerCollision` | `true` = les joueurs se bousculent comme avant ; `false` = ils se traversent (contre le « fling ») | non | non | non | serveur |
| `Feature_AntiCheat` | Contrôle des déplacements (anti-triche) | oui | oui | oui | serveur |

### Interface et effets

| Clé à créer | Ce que ça fait | DEV | TEST | PROD | Quand |
| --- | --- | --- | --- | --- | --- |
| `Feature_BdOutlinesDev` | Contours « façon BD » sur ce qui est interactif | oui | oui | non | serveur |
| `Feature_BdOutlinesHubDev` | Ces contours toujours visibles dans le hub et sa boutique ; demande `BdOutlinesDev` allumé | oui | oui | non | serveur |
| `Feature_PanelFocusDev` | Quand une fenêtre est ouverte, les autres écrans disparaissent | oui | oui | non | serveur |
| `Feature_InventoryScreenDev` | Le bouton du sac ouvre l'inventaire au lieu des objets exposés | oui | oui | non | serveur |
| `Feature_TreadmillGainPopsDev` | Gain du tapis affiché en 3D autour du joueur, avec un son | oui | oui | non | serveur |
| `Feature_PadPredictDev` | Son et flash des plaques d'argent joués tout de suite, sans attendre le serveur | oui | oui | non | serveur |
| `Feature_Settings` | Bouton et écran des réglages | oui | oui | oui | serveur |
| `Feature_UiAttrFx` | Effets d'UI posés par Clément (reflets, survol, balancement) | oui | oui | oui | serveur |
| `Feature_FramewispFx` | Effets des boutons faits avec Framewisp ; demande `UiAttrFx` allumé | oui | oui | oui | serveur |
| `Feature_Analytics` | Mesures envoyées au tableau de bord Roblox | oui | oui | oui | serveur |

## Fonctions récentes sans interrupteur

Elles sont allumées partout, PROD comprise, et ne se coupent pas depuis le Creator Hub (il faut changer le code et republier).

- **a493** : plus aucun $/s à décimales, tous les revenus d'objet arrondis à l'entier (présentoirs, colis, portés, annonces, inventaire, receleur, renaissance).
- **a494** : la chance finale de l'ouverture d'un colis s'affiche avec des décimales (affichage seul).
- **a502** : $/s juste sur la carte « ITEM SECURED! » (correctif d'affichage).
- **Receleur** : il vend l'objet tenu en main (correctif du « You're holding nothing, pal. »).
- **a477, alerte d'intrusion** : les étapes du contrôle des boutiques sont protégées une à une (une erreur ne coupe plus l'alerte).
- **a477, barre du bas** : plus de message « … equipped! » quand on prend un outil en main.

## Les pièges

- **Une clé mal écrite est ignorée, sans message.** Seuls les noms exacts `Feature_` + un nom de `Config/Features` sont lus, casse comprise (`Feature_chasev3dev` ne marche pas). Une clé qui n'est pas de type booléen (le texte « true », un nombre) est ignorée elle aussi : une ligne d'alerte dans la sortie du serveur, et le fichier garde sa valeur. Le contrôle : la clé doit apparaître dans `Overrides:` de `/feature`.
- **`Feature_X` au lieu de `Feature_XDev` sur TEST** : mettre `Feature_X` à `false` n'éteint rien sur TEST, car `XDev` reste vrai. Pour éteindre, il faut `Feature_XDev` à `false`.
- **Pour revenir au défaut**, supprimer la clé (puis publier, puis nouveau serveur) : clé absente = valeur du fichier.
- **Sur la PROD** : les clés du jeu TEST n'ont **aucun effet** sur la PROD (chaque jeu a ses Configs). Dans les Configs **du jeu PROD**, une clé `Feature_X` marche de la même façon (même lecture, mêmes règles « à chaud » ou « serveur ») ; une clé `Feature_XDev` n'y fait **rien**, car la PROD n'est pas un jeu DEV.
- **Configs lentes au démarrage** : si les Configs ne répondent pas dans les 5 s après l'ouverture d'un serveur, ce serveur part sur les valeurs du fichier ; la réponse tardive ne change alors que les interrupteurs à chaud. En cas de doute, regarder `Config:` dans `/feature` (il faut `ok`), ou ouvrir un autre serveur.
- **Un interrupteur qui en demande un autre** : `NewTrapsDev` ne sert à rien sans les pièges (`TrapsDev`) ; `BdOutlinesHubDev` demande `BdOutlinesDev` ; `FramewispFx` demande `UiAttrFx` ; `CameraRadarDev` agit au niveau 3 des Caméras ; `DenounceRecover` n'agit qu'avec la cabine d'essayage ; `ServerLuckDev`, `RobuxCrateDev`, `TrainingX4Dev` et `ExtraStandsGateDev` vivent dans la boutique Robux.
- **Renaissance coupée sur DEV et TEST** : avec la nouvelle économie (`EconomyBTDev`, allumée), la renaissance est coupée quel que soit `Rebirth`. Pour la tester sur TEST : `Feature_RebirthBT` = `true` (les montants sont encore à resimuler), ou éteindre la nouvelle économie.
- **Interrupteurs qui touchent les profils des testeurs** : `EconomyBTDev` convertit l'argent et les gains en attente d'une économie à l'autre au chargement, dans les deux sens ; `ItemsV3Dev` renomme les objets des profils, puis les remet en v2 si on l'éteint. À changer entre deux sessions de test, pas pendant.
- **Ce qui demande quand même une republication** :
  - changer un nombre (prix, PV, vitesses, durées, chances) : ce ne sont pas des interrupteurs ;
  - ajouter un interrupteur, ou rendre un interrupteur « à chaud » (liste `Hot` de `Config/LiveFeatures`) ;
  - couper tout ce système (`Config/LiveFeatures.Enabled`) ;
  - remettre à zéro les profils du jeu TEST (changer `TestStoreName` dans `Config/GameEnv`, puis republier la place TEST) ;
  - ajouter ce qu'une fonction attend dans la place : sans le modèle de Clément, l'allumer ne montre rien (`FortuneTower` sans `ENV_Event_FortuneVault`, `ShopFloor2` sans `Floor_2`, `WeeklyChest` sans son cadre d'UI, `ExperienceNotifications` sans ses messages réglés dans le Creator Hub) ;
  - les « fonctions sans interrupteur » de la liste plus haut.
- **Les attributs de test de Studio** (`TrapsTest`, `FortuneTest`, `WeeklyChestTest`…) ne servent qu'en Studio, jamais sur le jeu TEST.
- **La commande `/feature … on|off`** ne vaut que pour **un serveur**, jusqu'à sa fermeture, et seulement pour les 7 interrupteurs à chaud. Pour tous les serveurs, passer par le Creator Hub.
