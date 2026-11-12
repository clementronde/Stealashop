# Vigiles et animations (MOD-017, MOD-030, ANI-010, ANI-012) — passation, 2026-11-07

## Livré dans Studio (place DEV, Team Create)
- `ReplicatedStorage/Assets/Guards/Guard_Z1` à `Guard_Z6` : rig R15 Roblox (AnimationConstraint, comme les persos joueurs), Humanoid + Animator, dossier `Animations` vide, aucun script. Échelle (`Model:ScaleTo`) 1,00 / 1,08 / 1,16 / 1,24 / 1,32 / 1,40 ; HipHeight 2,19 → 3,07.
- Looks : Z1 supérette (casquette, gilet fluo SECURITY, ceinture radio, café), Z2 Londres (garde royal, bonnet en poil), Z3 Tokyo (casquette plate, baudrier, bâton lumineux néon), Z4 LA (tactique, lunettes aviateur, gilet SECURITY), Z5 Paris (képi, épaulettes, moustache), Z6 New York (costume, lunettes noires, oreillette).
- 21 accessoires `ACC_Z<n>_<Nom>` (Accessory + Handle + attache du corps), ≤ ~610 triangles chacun (budget 1 000).
- Showroom : silhouette `Show_8` et socle `Ped_Vigile zone 1` remplacés par `Ped_Guard_Z1..6` + `Show_Guard_Z1..6` (sans Humanoid, ancrés, accessoires renommés `Show_ACC_…`), rangée BASE ET BOUTIQUES, x = −106,5 à −61,5, z = 280.
- ContractChecker (Edit et Play du 2026-11-07) : « Contrat : OK », seules lignes nouvelles = Guard_Z1..6 « pas encore livrée(s) : Idle, Walk, Run, Catch, Tired ».

## Animations : prêtes à publier, pas publiées
KeyframeSequence dans `ServerStorage/RBX_ANIMSAVES` (Clément les ouvre dans l'éditeur d'animation et publie au nom de RoundStone Studio) :

| Save | Rig | Objet `Animation` à créer avec l'ID | Boucle | Priorité | Marqueur |
| --- | --- | --- | --- | --- | --- |
| Guard_Idle | Rig_Guard | `Guard_Z1..6/Animations/Idle` | oui, 4 s | Idle | — |
| Guard_Walk | Rig_Guard | `…/Walk` | oui, 0,8 s | Movement | — |
| Guard_Run | Rig_Guard | `…/Run` | oui, 0,4 s | Movement | — |
| Guard_Catch | Rig_Guard | `…/Catch` | non, 1,4 s | Action | Impact 0,30 s |
| Guard_Tired | Rig_Guard | `…/Tired` | non, 3,3 s | Action | — |
| Player_HitWindow | Rig_Player | `Assets/Animations/Player/HitWindow` | non, 0,4 s | Action | Impact 0,133 s |
| Player_HitWindowHeavy | Rig_Player | `Assets/Animations/Player/HitWindowHeavy` | non, 0,7 s | Action | Impact 0,233 s |

Coups du joueur : haut du corps seulement (jambes libres). ID : à venir de Clément → registre de la liaison (section 2).

**Publiées par Clément (2026-11-07), groupe RoundStone Studio vérifié, branchées dans Guard_Z1..6/Animations** :
Guard_Idle `74584301698483` · Guard_Walk `131553467994764` · Guard_Catch `137437669321264` (Impact 0,30 s) · Guard_Tired `75185461666074`.
ContractChecker (Edit) : « Contrat : OK », clips lus sans problème.
Player_HitWindow `116996900953276` · Player_HitWindowHeavy `84621500655735` : groupe vérifié, branchées dans `Assets/Animations/Player` (Contrat : OK).

**Nouvelles sauvegardes à publier (demande de Clément, 2026-11-07)** :
- `Guard_Run` refaite d'après sa référence (Officer Earl : buste droit un peu penché, coudes à 90°, bras avant levé « comme Mario qui saute », genou à 90°), boucle 0,4 s, Movement. Remplace l'ancienne, jamais publiée.
- `Player_Grab` (0,6 s, Action, marqueur `Grab` à 0,167 s, haut du corps) : tend les bras, attrape, monte le colis sur la tête et finit dans la pose de portage.
- `Player_CarryIdle` (boucle 2 s, Action, bras seuls) : bras tendus de chaque côté de la tête, mains aux côtés du colis.
- `Player_CarryRun` (boucle 0,4 s, Action) : **corps entier**, mêmes bras + jambes de la course à genoux hauts (90°), voulu par Clément.

**Pour Ironix (contrat)** : `CarryRun` anime désormais aussi les jambes, alors que le contrat 2.4, la liaison 3.2 et `Contract/Animations.luau` (`UpperBodyOnly = true`) disent « bras seuls ». Le code marche tel quel (CarryRun n'est jouée qu'au-dessus de 0,75 stud/s, CarryIdle reste bras seuls) et le ContractChecker ne vérifie pas ce drapeau : seul le texte du contrat est à mettre à jour. Les animations de portage soulèvent les épaules de 0,25 stud (bras du R15 trop courts pour tenir le colis soudé 0,25 stud au-dessus de la tête). `Grab` et `CarryIdle` sont toutes deux en Action : si CarryIdle démarre pendant Grab, elles se mélangent ; mieux vaut lancer le portage après la fin de Grab, ou arrêter Grab quand il commence.
Ne pas créer d'objet `Animation` vide : le ContractChecker le signale en orange.

## Retours de Clément après Play (2026-11-08) — sauvegardes prêtes à publier
`Guard_Run` publiée (`85972816841598`, groupe, version « Officer Earl » vérifiée) et déjà branchée dans les 7 vigiles. Dans `ServerStorage/RBX_ANIMSAVES` :
- `Guard_Catch` v2 : il plonge (accroupi, envol, vol à l'horizontale bras tendus), `Impact` à 0,30 s (mains à ~4,5 studs devant lui), retombe à plat ventre, se relève ; 2 s. Remplace la Catch publiée `137437669321264` : après publication, changer l'`AnimationId` de `Catch` dans les 7 vigiles (ou écraser le même asset).
- `Player_Knockback` (0,8 s, Action, `Land` à 0,533 s ≈ fin du vol de la poussée 40/25 studs/s) : frappé de dos, projeté en avant, atterrit à plat ventre. `Player_Stunned` (boucle, Action) : sonné au sol, tête qui dodeline ; non demandée mais jouée après Knockback par ChaseController (sans elle, le joueur se relève pendant l'étourdissement).
- `Player_TreadmillRun` (boucle 0,53 s, Movement) : course sur place, coudes à 90°.
- `Player_BenchIdle` (boucle 2 s, Idle) : allongé sur le dos, pieds sur le plateau, mains à la barre ; calée sur `PLOT_Shop.Bench` (UsePoint au pied du plateau, plateau derrière le joueur). `Player_BenchLift` (0,4 s, Action, bras seuls, `Top` à 0,267 s, donc tenu jusqu'à 3 répétitions/s) : descend la barre à la poitrine et la repousse. La barre du banc est fixe : pour qu'elle suive les mains, le code doit la souder aux mains pendant la répétition.
- `Player_Grab`, `Player_CarryIdle`, `Player_CarryRun` : déjà faites (colis sur la tête). Le message dit `CarryRun` « haut du corps seulement », mais Clément m'avait demandé les genoux à 90° : `Player_CarryRun` anime le corps entier, `Player_CarryRun_HautDuCorps` est la variante bras seuls. Clément publie celle qu'il veut sous le nom `CarryRun`.

**Publiées et branchées (2026-11-08)**, groupe vérifié, boucle/priorité/marqueurs vérifiés, ContractChecker « Contrat : OK » :
`Assets/Animations/Player` : Grab `96326925175959` (Grab 0,167 s) · CarryIdle `70480373886226` · CarryRun `136022751001682` (version corps entier, genoux à 90°) · Knockback `120060895923003` (Land 0,533 s) · Stunned `121567497792585` · TreadmillRun `124742821111593` · BenchLift `91066734447697` (Top 0,267 s).
Vigiles (Guard_Z1..6 + NightGuard) : Catch remplacée par la v2 plongeon `84825852307632` (Impact 0,30 s) ; ancienne `137437669321264` débranchée.
BenchIdle `95459665314491` (boucle, Idle) : publiée et branchée le 2026-11-08, Contrat : OK.
Faites le 2026-11-08, dans `RBX_ANIMSAVES/Rig_Player`, à publier : `Player_Place` (0,7 s, haut du corps, part de la pose de portage, `Release` 0,4 s) · `Player_Unbox` (1,2 s, haut du corps, `Open` 0,6 s < OpenMarkerTimeout 1,5 s) · `Player_Celebrate` (1,5 s, corps entier, saut bras en V puis poings qui pompent) · `Player_SwingBat` (0,6 s, haut du corps, `Impact` 0,2 s < Bat.ImpactMaxWait 0,3 s, durée < Bat.Cooldown 0,8 s). Avec elles, les 14 animations du joueur et les 5 du vigile du contrat 2.4 sont faites.
**Publiées et branchées (2026-11-08)** : Place `84787876044209` · Unbox `134738340861218` · Celebrate `104410974947269` · SwingBat `101367023213685` (groupe, boucle, priorité et marqueurs vérifiés). ContractChecker : « Contrat : OK », plus aucune animation manquante (14/14 joueur, 5/5 dans les 7 vigiles).

## L-076 et L-083 (2026-11-10) — sauvegardes prêtes à publier, dans `ServerStorage/RBX_ANIMSAVES`
- `Player_Knockdown` (1,2 s, Action, sans boucle, `Land` à 0,4 s) : frappé de dos, trébuche, tombe à plat ventre, reste sonné ; finit dans la pose de départ de `Stunned`, et `Player_GetUp` (1,2 s, Action, sans boucle) part de cette pose : le code peut enchaîner Knockdown → Stunned (aussi longtemps qu'il veut) → GetUp sans saut.
- Arrestation de nuit, 2,4 s chacune, Action, sans boucle, `Grab` à 0,4 s dans les deux : `Guard_Arrest` (Rig_Guard, pour `NightGuard/Animations/Arrest`) et `Player_Arrested`. **Placement pour Ironix** : lancer les deux ensemble, tournés du même côté, le joueur 3,2 studs devant le vigile (`joueur.HRP = vigile.HRP * CFrame.new(0, 0, -3.2)`). Le vigile saisit les poignets à `Grab`, met le joueur à genoux mains dans le dos et le tient ; la dernière pose tient jusqu'au fondu. Calé à l'échelle 1 ; NightGuard est à 1,1 (bras 10 % plus longs, passe).
- **Contrat à compléter par Ironix** : `Knockdown`, `GetUp`, `Arrested` (joueur) et `Arrest` (vigile de nuit) ne sont pas encore dans `Contract/Animations` : une fois branchés, le ContractChecker les signalerait « hors contrat ».
- **Publiées et branchées (2026-11-10)**, groupe vérifié : `NightGuard/Animations/Arrest` `130512644530503` (Grab 0,4 s) · `Player/GetUp` `99478078081657` · `Player/Arrested` `123026587429719` (Grab 0,4 s). ContractChecker : 9 lignes orange attendues (GetUp, Arrested, Arrest « hors contrat » + les 6 des conducteurs), jusqu'à la mise à jour du contrat par Ironix. `Player/Knockdown` `140255853524203` (Land 0,4 s) branchée ensuite ; l'ID `131515434722404` (republication de Player_Knockback) n'est pas branché, Knockback garde `120060895923003`. Contrat : 10 lignes orange attendues (Knockdown, GetUp, Arrested, Arrest + 6 des conducteurs) jusqu'à la mise à jour par Ironix.
- **Conducteurs du camion** : `TruckDriver_01` et `_02` rangés dans `Assets/Events/ENV_Event_Truck` (hors `Pieces`, position inchangée), `DisplayDistanceType = None`, R15, Animator, aucun script ; `Animations` : Idle, Walk (déjà là), Run `85972816841598`, Catch `84825852307632`. Dans le camion, le ContractChecker n'admet que `Idle` pour eux : **6 lignes orange** (Walk, Run, Catch × 2) jusqu'à ce qu'Ironix ajoute Run et Catch (et Walk, ou on l'enlève) à leur contrat.

## Vigile de nuit (L-043 point 2, MOD-032) — livré 2026-11-07
- `ReplicatedStorage/Assets/Guards/NightGuard` (commun à toutes les zones) : rig R15, échelle 1,10 (6,2 studs), aucun script, Animator, `Animations` avec les mêmes ID que Guard_Z1 (Idle, Walk, Catch, Tired) ; `Run` à brancher dès que Clément publie `Guard_Run`.
- Accessoires `ACC_Nuit_Casquette` (badge argent), `ACC_Nuit_Gilet` (bandes réfléchissantes en Neon, lisibles la nuit, SECURITY au dos), `ACC_Nuit_LampeTorche` en main droite : `SpotLight` « Flashlight » dans la pièce `Lens`, Range 40, Angle 90, face avant, Shadows coupées.
- Showroom : `Ped_NightGuard` + `Show_NightGuard` à x = −52,5 (fin de la rangée BASE ET BOUTIQUES).
- ContractChecker (Edit) : « Contrat : OK », seule ligne : NightGuard « pas encore livrée(s) : Run ».
- À savoir : la lampe suit la main, donc avec le `Walk` de jour (bras qui balancent) le faisceau balance de ±25°. Le contrat 2.4 prévoit un `Walk` de nuit où il tient sa lampe devant lui : possible plus tard avec un ID propre au NightGuard, si Clément le veut.

## Pour Ironix (à mettre dans la liaison si utile)
- `Run` est une boucle de 0,4 s pensée pour ~20 studs/s à l'échelle 1 : `track:AdjustSpeed(WalkSpeed / (20 * model:GetScale()))`, borné 0,6–1,6, évite les pieds qui glissent de la zone 1 à la zone 6. `Walk` (0,8 s) colle à ~10 studs/s à l'échelle 1.
- Rappel L-040 : AgentHeight 5 / AgentRadius 2 de GuardService pour des vigiles jusqu'à 7,3 studs de haut.

## À vérifier par Clément d'un coup d'œil
- Lunettes Z4/Z6 et moustache Z5 posées à la hauteur supposée des yeux de la tête dynamique par défaut (pas pu la lire : droits).
- Plugin Blender « RBX Animations » (Cautioned's Fork v1.96) : installé seulement pour Blender 4.2, qui n'a plus d'exécutable ; dans 5.2 son export plante (matrices des os rangées à plat). Contourné en mémoire pour ce travail ; pas installé dans 5.2.

## Fichiers
- Sources : `StealAShop-Art/Guards/_scripts/` (guards_data.py, anim_defs.py, build_anims.py…), `Guard_Animations.blend`, `Player_Animations.blend`, `rbxanim/*.rbxanim` (format du plugin), `renders/`.
- Dépôt (non commités) : `tools/clement/guards_builder.luau`, `tools/clement/guard_anims_import.luau` (relançables en mode Edit).

**BenchLift v2 (L-091 point 2, 2026-11-10)**, dans `RBX_ANIMSAVES/Rig_Player/Player_BenchLift`, à republier par Clément :
- Pourquoi : la barre ne bouge pas parce que `Bar` est ancrée et que rien ne la déplace. L'ancienne BenchLift (`91066734447697`) écartait les coudes et tournait les mains de 70° en bas : une barre soudée à une main aurait basculé.
- v2 : développé couché bras dans le plan du corps, calculé par IK (`StealAShop-Art/Guards/_scripts/bench_press_gen.py`). Le poignet compense pour garder la main dans l'orientation de BenchIdle (écart vérifié dans la KeyframeSequence : 0,000°). Les deux mains restent à la même hauteur, l'écart des mains varie de moins de 0,07 stud. La barre descend de 0,95 stud vers le milieu du torse (0,45 stud vers les pieds), sans toucher les disques ni la tête. Mêmes réglages : 0,4 s, Action, sans boucle, bras seuls, `Top` à 0,267 s (bras tendus, barre sur les crochets).
- Pour Ironix (soudure) :
  - Au début de l'usage, une fois les mains sur la barre (pose BenchIdle), désancrer et souder à `RightHand` toute la barre, pas seulement `Bar` : `Bar`, `Collar_L`, `Collar_R`, `Plate_L1`, `Plate_L2`, `Plate_R1`, `Plate_R2` sont 7 pièces séparées et toutes ancrées. Soudure `C0 = RightHand.CFrame:Inverse() * part.CFrame`, en `Massless` et `CanCollide = false`.
  - À la sortie, défaire la soudure, remettre la CFrame d'origine et réancrer.
- Pour Clément, à voir en Play : les montants (x ±1,6 du UsePoint) traversent le côté extérieur des bras par défaut (1 stud d'épaisseur, centrés à x ±1,47). C'était déjà le cas dans BenchIdle. Modèle à revoir seulement si ça se voit.
- Après publication : remplacer l'`AnimationId` de `Assets/Animations/Player/BenchLift`, ou écraser le même asset.
**BenchLift v2 publiée et branchée (2026-11-10)** : `97749171238379` dans `Assets/Animations/Player/BenchLift` (remplace `91066734447697`). Vérifié : groupe RoundStone Studio, Action, sans boucle, 0,4 s, `Top` à 0,267 s, bras seuls, main à orientation constante (0,000°). ContractChecker : aucune ligne rouge ; les 10 lignes orange restent celles déjà connues (Knockdown, GetUp, Arrested, Arrest, Walk/Run/Catch des conducteurs), en attente de la mise à jour du contrat par Ironix.

## Témoins et policier (L-111, 2026-11-12)

**Modèles posés dans Studio** (R15 standard, Humanoid + Animator, `DisplayDistanceType = None`, aucun script) :
- **12 témoins** `NPC_Witness_Z<n>_01` et `_02`, dans `Workspace/Map/Zone_<n>/Witnesses` :
  - Placement : `_01` regarde le magasin du sud, `_02` celui du nord. Chacun est sur le trottoir d'en face, à 1,8 stud de la bordure et à 10 studs de l'axe de la vitrine, tourné vers elle, à environ 104 studs. `HumanoidRootPart` ancré.
  - Attribut `WatchedStore` = nom du magasin regardé. Attachment `WitnessHead` dans la tête, 1,85 stud au-dessus du centre.
  - Téléphone `ACC_Temoin_Telephone` dans la main droite, objet du thème dans la main gauche.
  - Looks : Z1 mamie au cabas / ado à capuche · Z2 gentleman au chapeau melon et parapluie / trench et écharpe écossaise · Z3 écolier au cartable rouge / salaryman à la mallette · Z4 surfeur au skate / joggeuse à la gourde · Z5 marinière, béret et baguette / élégante au manteau rouge · Z6 homme d'affaires au café / touriste « NEW YORK » à l'appareil photo.
- **`NPC_Police`** dans `ReplicatedStorage/Assets/Guards` :
  - Échelle 1,12, 6,4 studs de haut : casquette à visière, lunettes, chemise bleue, étoile, ceinturon (radio, menottes, matraque), « POLICE » dans le dos.
  - Animations copiées des vigiles (mêmes ID) : Idle `74584301698483`, Walk `131553467994764`, Run `85972816841598`, Catch `84825852307632`. J'ai aussi ajouté Tired `75185461666074`, que le contrat des vigiles demande.
- **Rig de travail** `ServerStorage/AnimRigs/Rig_Witness`, avec le look du témoin Z1_01 et son téléphone, pour l'éditeur d'animation.
- Constructeur relançable : `tools/clement/npc_builder.luau`, généré depuis `StealAShop-Art/Guards/_scripts/npc_data.py` par `make_npc_luau.py`. Il est non suivi dans le dépôt, rien n'est commité. Après une reconstruction des zones, il suffit de le relancer.

**Animations à publier par Clément** (dans `RBX_ANIMSAVES/Rig_Witness`, rig `Rig_Witness`) :
- `Witness_Idle` : boucle de 4 s, priorité Idle. Tourné de 35° vers sa droite, tête baissée sur l'écran. Le fondu vers Look le remet face au magasin.
- `Witness_Look` : boucle de 3 s, priorité Action. Face au magasin, buste en arrière, téléphone serré contre lui, la tête qui cherche.
- `Witness_CallPolice` : boucle de 3 s, priorité Action. Il porte le téléphone à l'oreille, avec le marqueur `Call` à 0,4 s, parle en s'agitant, regarde l'écran, puis recommence. `Call` revient donc à chaque boucle : le code ne doit réagir qu'au premier.
- À publier sous les noms `Idle`, `Look` et `CallPolice`. Je créerai ensuite le dossier `Animations` dans les 12 témoins. Il n'existe pas encore, exprès : sans lui, le ContractChecker ignore les témoins.

**Pour Ironix** :
- Le ContractChecker traite tout modèle de la map qui a un dossier `Animations` comme un vigile. Dès que j'aurai posé les ID, `Look` et `CallPolice` sortiront « hors contrat » et Walk, Run, Catch et Tired « pas encore livrées ». Il faut ajouter un `Animations.Witness` (Idle, Look en boucle Action, CallPolice en boucle Action avec le marqueur `Call`), reconnu par le nom `NPC_Witness_*`.
- À voir en Play : les témoins sont à environ 104 studs, derrière le joueur qui casse la vitrine. Le « ? » risque de ne pas se voir. Si besoin, je les rapproche, par exemple au coin du même trottoir.
- ContractChecker en Edit : « Contrat : OK », aucune ligne rouge ni orange.
