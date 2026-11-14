# Boutique du joueur (MOD-015) et tapis et banc (MOD-016) : passation

Session « boutique du joueur », 2026-11-07, mode Edit seulement (pas de Play, pas de capture). Ni commit, ni push. La liaison et le doc n'ont pas été modifiés.

## Ce qui est livré

- **Gabarit** `ReplicatedStorage/Assets/Plots/PLOT_Shop` : 64 × 80 studs (x −32..32, z −40..40), pivot en bas au centre, avant vers −Z. Tags posés : `PlayerPlot` (boutique), `CashPad`, `Treadmill`, `Bench`. Pas de `PlotIndex` (posé à l'installation). Aucun script.
- **Script** `tools/clement/hub/plot_shop_builder.luau` (non commité) : `build()`, `install({ cframe, index, parent, stage, accent })`, `preview(copie, niveau)`, `check(modèle)`. Il s'envoie à `execute_luau` d'un bloc, ou en 5 morceaux (« Morceau 2 » à « Morceau 5 ») si le bloc est trop long. `install` pose une copie à la position voulue, avec `PlotIndex`, le numéro « SHOP n » sur l'enseigne, une couleur d'accent par numéro, et ne garde que les niveaux 1 à `stage` (1 par défaut).
- **Vérifié** (`check`, mêmes règles que `Contract/Models`) : contrat 10.4 complet, chaque nom une seule fois ; `WindowFractured` = copie de `WIN_M_Fractured` (36 éclats), alignée au stud près sur `Window` ; rideau caché dans le linteau, 7,8 de haut ; points tournés vers −Z ; `UsePoint` sur la surface où l'on se tient ; place du joueur libre au tapis et au banc ; apparition dégagée.
- **Triangles** : ~5 800 au niveau 1, ~20 400 au niveau 5 (budget 25 000). Tapis ~190, banc ~840 (budget 3 000).
- **5 niveaux** (décision de Clément, 2026-11-07, comme le doc Partie 2, section 2) : `Stage_1` à `Stage_5`. Installation retestée aux niveaux 1 et 5 : contrat OK, porte et banc dégagés, copies de test retirées.

## Mise à jour du 2026-11-08 (retours de Clément)

- **Tapis et banc dehors**, sur une terrasse `Terrace` devant la façade (z −52..−40) : tapis en x −24, banc en x 24, tags et `UpgradePoint` gardés, haltères à côté du banc. L'emprise passe à 64 × 92 studs (z −52..40), et `Bounds` ne couvre que le bâtiment (z −40..40). Le pivot reste au centre du bâtiment (z 0) : **la session du hub doit reculer ses boutiques d'environ 12 studs**, ou prévoir 12 studs de place devant chaque façade.
- **5 rayons de 4 présentoirs** `Rayon_01` (devant) à `Rayon_05`, le long de la façade, en deux moitiés autour de l'allée centrale. `DisplaySlot_01` à `_04` sont dans `Rayon_01`, et ainsi de suite. Les rayons portent leurs produits (l'ancien décor des îlots du niveau 2 est retiré).
- **Montrer un rayon pas encore acheté** (proposition) : l'emplacement vide avec un contour blanc au sol, `RayonSpot_02` à `_05` (dans `RayonSpots`). Le contour est caché sous le rayon tant que celui-ci est là. Le code retire le `Rayon_n` pas encore débloqué et le remet, depuis le gabarit, quand l'un de ses présentoirs est acheté. Je préfère ça à un rayon caché : on voit qu'il reste de la place à remplir.
- **Contrat** : le ContractChecker exige les 20 `DisplaySlot` dans la map. Les boutiques sont donc posées avec les 5 rayons (`install` par défaut), et c'est le code qui retire les rayons en jeu. Sinon il faut qu'Ironix assouplisse le contrôle (`install({ rayons = 1 })` fait la pose réduite, et le contrôle le signale bien).
- **`CollectPad_01` à `_20`** : une case verte en néon avec « $ », à plat au pied de chaque présentoir, dans son rayon. Elle est sans collision, avec `CanTouch` actif. `CashPad` reste en place (déplacée en z −32,5..−27,5) tant que le contrat l'exige : à retirer quand Ironix aura validé les `CollectPad`.
- **`DisplayUpgradePoint`** : sur une borne à gauche de la porte (−10, 6,2, −36), en miroir de `StageUpgradePoint`.
- Triangles : environ 6 700 au niveau 1 avec un rayon, et 18 100 au niveau 5 avec les 5 rayons.

## Socle de l'objet le plus rare (2026-11-08)

- `RarestPedestal` (Model, enfant direct de la boutique, présent à tous les niveaux) : au centre de la terrasse, face à la porte, x 0, z −51,3..−45,7, 3,35 de haut. Il reste 3,5 studs pour passer de chaque côté et environ 5 studs devant la porte. Socle sombre et tambour blanc ; néons de bordure et `PointLight` à la couleur de la boutique (`install` recolore aussi les lumières marquées `Accent`). Environ 590 triangles, sans script.
- `RarestSlot` (Attachment sur `TopPlate`, en (0, 3,35, −48,5), face à la rue −Z) : le code y pose l'objet debout. `RarestLabelPoint` 6 studs au-dessus, pour l'étiquette ; le code peut le remonter selon la hauteur de l'objet.
- **Déplacé** (Clément, 2026-11-08 : il bloquait l'entrée) en x 13, entre la porte et le banc, à gauche de la porte vu de l'allée.

## Mise à jour du 2026-11-08, après le hub en Play (L-086)

- **Gabarit reconstruit, 6 boutiques du hub réinstallées** à leur pivot (niveau 1, une rangée), puis `collect_pad_fx.luau` relancé (qui traite aussi `PLOT_Shop_Rayons`). ContractChecker en Edit : « Contrat : OK », aucune ligne orange ni rouge.
- **Plus de coffre visible** (`Safe`, `VaultFrame`, `VaultDoor` retirés). `VaultSlot_01` à `_03` sont sur `VaultAnchor`, invisible et sans collision. Clavier du Flagship sur la colonne droite ; les rails du rideau restent au niveau 5.
- **Plus d'établis** : `UnboxBench_01` à `_04` sont sur `DisplayStand_01` à `_04` (`Rayon_01`), au même point que `DisplaySlot_01` à `_04`.
- **Niveau 1 = une seule rangée** : `PlotFloor` z −40..−16 ; `Stage_1` (barrière basse, champ de force) suit ce petit pourtour. `Stage_2` pose `PlotFloorExt` (z −16..40), le grand champ de force et les cartons. Nouvel attribut `FromStage` (la pièce n'existe qu'à partir de ce niveau) : murs invisibles `Barrier_L/R/B/Lid` (FromStage 2) ; `Barrier_L1/R1/B1/Lid1` (HideFromStage 2) ; `RayonSpots` (FromStage 2).
- **Rangées 2 à 5** : dans la boutique, `Rayon_0n` ne contient qu'une pièce invisible `RayonAnchor`, qui porte les `DisplaySlot` (contrat). Les visuels (présentoirs, `CollectPad`, produits) sont dans `ReplicatedStorage/Assets/Plots/PLOT_Shop_Rayons/Rayon_0n`, même repère : pour les montrer, on les copie dans `Rayon_0n` au pivot de la boutique, on recolore les pièces `Accent` et on retire `RayonSpot_0n` (`showRayon` dans le builder).
- **`Bounds` ne couvre plus la terrasse** (z −40..40) : le `ejectStep` de PvPService sortait les non-propriétaires dès qu'ils approchaient du tapis, du banc ou de la vitre.
- Triangles : ~4 600 au niveau 1, ~8 600 au niveau 2 avec 3 rangées, ~17 500 au niveau 5 avec 5 rangées.

**Ce que le code d'Ironix doit changer** :
1. `UnboxService` : ouvrir le colis sur le `DisplaySlot` (les 4 `UnboxBench` y sont déjà, au même point) ; retirer l'amélioration « établis ».
2. Rangées : montrer `Rayon_02` à `_05` depuis `PLOT_Shop_Rayons` ; ne pas poser d'objet sur un `DisplaySlot` dont la rangée n'est pas montrée.
3. Niveaux : appliquer `FromStage` en plus de `HideFromStage`. Une rangée 2 à 5 n'a de sol qu'à partir du niveau 2.
4. Au niveau 1, `Bounds` couvre encore l'herbe derrière la petite boutique (z −16..40) : y entrer fait sortir un non-propriétaire. Réduire `Bounds` au niveau 1 côté code, ou l'ignorer.
5. Plus tard : `VaultSlot_*` et `UnboxBench_*` hors du contrat, `CashPad` remplacé par les `CollectPad`.

## Où sont les choses (repère de la boutique)

- Porte à casser = `Window` (2 vantaux de 6 × 7, `Leaf_L` et `Leaf_R`) au centre de la façade, dans le portique `PlotDoor`. `NameSign`/`OwnerName` sur le linteau, `ShutterButton` à l'intérieur du montant droit.
- 20 présentoirs sur 4 îlots (x −21,5, −7,5, 7,5, 21,5 ; rangées z −20 à 8). Les 4 premiers sont au bord de l'allée centrale, puis ils s'éloignent dans l'ordre de déblocage.
- `UnboxBench_01` à `_04` sur les présentoirs de `Rayon_01`, `VaultSlot_01` à `_03` invisibles au fond au centre, caisse et `CashPad` devant à gauche, tapis (x −24), banc (x 24) et socle `RarestPedestal` (x 13) sur la terrasse.
- `TrapSlot_01` à `_04` derrière la porte, `SpawnPoint` en (0, 0,3, −27) tourné vers la rue, `StageUpgradePoint` sur une borne à droite de la porte. `DepositZone` = tout l'intérieur, invisible ; `Bounds` = le bâtiment (z −40..40, sans la terrasse), 30 de haut.

## Niveaux

1. Stand : stand ouvert, barrière basse chromée, champ de force léger au-dessus (matériau ForceField), tapis WELCOME.
2. Boutique : murets et rayons garnis (produits sous les présentoirs, têtes d'îlots, promo, haltères).
3. Magasin : murs pleins, vitrines de façade (décor, incassables), rayons muraux.
4. Concept store : toit, néons au plafond, enseigne lumineuse, rails du rideau, auvents.
5. Flagship : façade marbre et or, porte blindée en cadre de coffre-fort avec sa porte ronde, clavier, 5 caméras (décor), alarme, tapis rouge, lustres, palmiers.

`HideFromStage` : barrière basse 2, champ de force 3, murets des côtés 3, rails du rideau 5, néons de l'enseigne 5, pilastres 5, tapis WELCOME 5.

## Noms proposés à Ironix (rien n'est encore au contrat)

- `Stage_1` à `Stage_5` (Models, enfants directs de la boutique, pivot = pivot de la boutique) : décor ajouté à chaque niveau, cumulatif. Aucun nom du contrat dedans.
- Attribut `HideFromStage` (nombre) : la pièce ou le groupe disparaît à partir de ce niveau.
- Règle conseillée côté code : le gabarit garde tout ; pour passer au niveau n, cloner les `Stage_k` (k ≤ n) du gabarit, les placer au pivot de la boutique (`PivotTo`) et retirer les pièces dont `HideFromStage` ≤ n.
- `PlotDoor` (Model de l'entrée) ; `Leaf_L` et `Leaf_R` dans `Window`, que le code fait coulisser pour le propriétaire, côté client.
- `PlotBarrier` (Model) : murs invisibles sur le pourtour (côtés, fond, avant hors porte, couvercle à 30 studs). Le code les rend franchissables pour le propriétaire seul ; les autres doivent casser `Window`. La casse marche déjà sans code nouveau : WindowService accepte une `Window` en Model.
- `StageUpgradePoint` (Attachment) : où flotte l'achat du niveau suivant.
- En option : `BeltTexture` (Texture du `Belt`, le code peut faire défiler `OffsetStudsV`) ; `Barbell` (Model de la barre du banc, que le code peut souder aux mains pendant `BenchLift`). `UpgradePoint` est posé dans le tapis et le banc (L-041).

## Points à trancher ou à savoir

- **Présentoirs** : les 20 sont là dès le niveau 1, car ils ont leur propre amélioration (7.5, de 4 à 20) ; le niveau 2 n'ajoute que du décor.
- **Pose dans la map** : retirer d'abord les 6 parcelles grises (`Greybox/Safe/Plots`), sinon les `PlotIndex` et les tags seront en double.
- **Pour le code** : un voleur encore dedans quand la porte se reconstruit (30 s) reste enfermé par `PlotBarrier` ; il faudra le sortir, par exemple à la reconstruction.

## Grande vitre (Clément, 2026-11-08)

- `Window` mesure maintenant 18 × 10,5 × 0,6 (WIN_M × 1,5, vantaux `Leaf_L` et `Leaf_R` de 9 de large) ; `WindowFractured` = `WIN_M_Fractured` × 1,5 (36 éclats), aligné exactement. Le ShatterController ne trouve pas de variante `WIN_M_*` à cette taille : il fait exploser le `WindowFractured` de la boutique, sans les variantes gauche et droite.
- Le portique est plus grand : poteaux à x ±9..10, linteau jusqu'à y 22,6 (au-dessus du toit, il cache le rideau de 10,84 et porte l'enseigne, en y 16,6..21,2). Les vitrines, murets, auvents, colonnes, corniche, clavier et cadres d'enseigne suivent. Au Flagship, une couronne de marbre et le diamant sont posés sur le linteau ; le fronton est retiré.
- « Plus facile à casser » : la vitre est plus grande, donc plus facile à toucher. Ses PV restent dans `Config` ; c'est à Ironix de les baisser si Clément le veut.
- Les 6 boutiques du hub sont réinstallées à leurs nouveaux pivots (x −138, LookVector +X), `collect_pad_fx` est relancé, et le ContractChecker en Edit affiche « Contrat : OK ».

## Tapis de course de Clément (2026-11-08)

- Sources : `StealAShop-Art/Training/Treadmill/` (GLB copiés, `.blend`, `.json`, `_scripts/build_treadmill.py`). Agrandis ×4 : 8,6 × 4,5 studs, 4,6 de haut, bande à 0,86. 572 triangles chacun : seuls les rouleaux cachés et le dessous de la bande ont été retirés.
- `tools/clement/hub/treadmill_assets.luau` range les imports dans `Assets/Plots/PLOT_Treadmill_Base` et `PLOT_Treadmill_Silver` : même repère (pivot en bas au centre, console vers −Z), sans tag. Chaque variante contient `Belt` (avec `BeltTexture` et `UsePoint`), `BeltArrows`, `BeltEnds`, `Frame` (avec `UpgradePoint`), `Trim`, `ConsoleScreen`, `ConsoleButtons` et 3 boîtes invisibles `Collision_*`.
- `PLOT_Shop.Treadmill` est maintenant une copie de la base, avec le tag. Pour passer à l'argent, le code copie `PLOT_Treadmill_Silver` au pivot de `Treadmill`, le nomme `Treadmill` et lui donne le tag. Le nouveau tapis n'a plus de pièces `Accent` (couleurs de Clément).
- Les 6 boutiques du hub sont réinstallées et les cases refaites ; ContractChecker en Edit : « Contrat : OK ».

## Tapis Void et Fire, et leurs effets (2026-11-08)

- `PLOT_Treadmill_Void` (1 444 triangles) et `PLOT_Treadmill_Fire` (1 450) sont dans `Assets/Plots`, au même pivot que la base, sans tag (script Blender `build_treadmill_variant.py`, rangement `treadmill_assets.luau`). Leur bande est plus haute (y 1,04) ; chacun a son `UsePoint`. `Belt` y est une Part plate dont la `BeltTexture` porte l'image de Clément (une fois sur la bande), et le code la fait défiler.
- Effets sans script (`tools/clement/hub/treadmill_fx.luau`), images importées au nom du groupe (`FX_Treadmill_*`) :
  - Void : `PortalPoint` (`Portal` qui tourne et `Ring` en sens inverse), `FlamePoint_L` et `_R` (flammes violettes 4×4), `AuraPoint_L` et `_R` (`Glow` et `Sparkle`) ;
  - Fire : `FlamePoint_L` et `_R` (flammes orange 4×4).
  Tout est allumé en permanence ; le code peut jouer sur `Enabled` ou `Rate` pendant la course.
- Pour les voir en 3D : `_SHOWROOM_CLEMENT/TAPIS`, les 4 tapis côte à côte en (−24, 0, 427). ContractChecker en Edit : « Contrat : OK ».

## Tapis Ice (2026-11-08)

- `PLOT_Treadmill_Ice` (1 498 triangles, fichier de Clément déjà en studs, noms gardés) est dans `Assets/Plots`, au même pivot, sans tag. Sa bande est une Part plate à y 0,86 ; `BeltTexture` a une tuile de 3,4 × 1,7 ; `UpgradePoint` est au point commun (6,75, 0, 2).
- Clément a fourni `IceTreadmill.lua`, un script client à poser dans le modèle. **Il n'est pas posé** : le tapis est répété dans les 6 boutiques, et la règle FX_ interdit tout script dessus. Copie de référence : `StealAShop-Art/Training/Treadmill/_scripts/IceTreadmill_reference.lua`.
- Partie fixe refaite sans script (`treadmill_fx.luau`, dossier `IceFX`) : 11 reflets sur les cristaux, brume au sol (flipbook 4×4), neige, cercle de givre et halo au sol (Decals), 2 PointLight, cristaux en verre, flèches et lueurs en néon.
- **Pour Ironix (code client)** : ce que le script animait, pour tous les tapis texturés :
  1. faire défiler `Belt.BeltTexture.OffsetStudsV` (référence Ice : 3 studs/s à vide, 9 avec un joueur dessus, transition douce) ;
  2. allumer `Belt.RunBurstPoint.RunBurst` (Ice) pendant la course ;
  3. Ice : faire pulser `BeltArrows.Transparency` (0 à 0,25) et la couleur de `CrystalGlow`, varier `IceFX.CrownLight` (luminosité 1,6 à 2,6, sinus 3 rad/s) et faire tourner `IceFX.FrostRing` (0,12 rad/s autour de Y).

## Tapis Gold, palier 1 (2026-11-08)

- `PLOT_Treadmill_Gold` (1 499 triangles, fichier déjà en studs, noms gardés) est dans `Assets/Plots`, au même pivot, sans tag. Bande plate à y 0,86 avec `BeltTexture` (tuile 3,44 × 1,72), `UpgradePoint` au point commun. Cadre et bordures en Metal, colonnes et ailes en ivoire, `GoldGlow` et boutons en néon.
- `GoldTreadmill.lua` (script client fourni par Clément) **n'est pas posé**, pour la même raison que l'Ice. Copie de référence : `_scripts/GoldTreadmill_reference.lua`. La partie fixe est dans `treadmill_fx.luau`, dossier `GoldFX` : `Halo1` à `Halo4` (anneaux), `ColSparkle1` à `4` (scintillements, `Beam` de lumière, `PointLight`), `WingFX` (scintillements, plumes, `WingLight`), `GroundGlow`, plus `Belt.RunBurstPoint.RunBurst` éteint.
- **Pour Ironix** : défiler `BeltTexture` (3 et 9 studs/s, comme l'Ice), allumer `RunBurst` pendant la course, faire pulser la couleur de `GoldGlow` et `WingFX.WingLight` (1,2 à 2,2, sinus 3 rad/s), faire tourner `GoldFX.Halo1` à `Halo4` autour de Y (1,1 rad/s, sens alternés : impairs −, pairs +).
- Showroom : `_SHOWROOM_CLEMENT/TAPIS`, 6 tapis en rangée (base, argent, Void, Fire, Ice, Gold). ContractChecker en Edit : « Contrat : OK ».

## Tapis Fire, version 2 (2026-11-08)

- `PLOT_Treadmill_Fire` est remplacé par la version 2 de Clément (FireTreadmill.glb, 1 499 triangles au lieu de 2 316, déjà en studs). La version 1 reste dans StealAShop-Art sous `PLOT_Treadmill_Fire_v1.*`. Même pivot ; bande plate à y 0,86 avec `BeltTexture` (tuile 3,44 × 1,72).
- `FireTreadmill.lua` (script client) **n'est pas posé**. Copie de référence : `_scripts/FireTreadmill_reference.lua`. La partie fixe est dans `treadmill_fx.luau`, dossier `FireFX` : 2 braseros arrière (flammes réalistes 8×8, braises, fumée, `Light`), 4 `LavaWindow_*` (SurfaceLight), 2 `CrackEmbers`, 11 contours `Fire_*` (flamme, cœur, braises, brume de chaleur, fumée, lueur) avec 8 rideaux `Curtain` (Beam qui défile seul), `GroundGlow`, `Belt.RunBurstPoint.RunBurst` éteint.
- **Performance** : 74 émetteurs et 8 Beams par tapis Fire. Si ce tapis est dans plusieurs boutiques, ou sur téléphone, le code peut diviser les `Rate` par deux (le `QUALITY = 0,5` du script) ou couper les contours éloignés.
- **Pour Ironix** : défiler `BeltTexture` (3 et 9 studs/s), allumer `RunBurst` pendant la course, faire scintiller `FireFX.Brazier1.Light` et `Brazier2.Light` (2 ± 0,7, en opposition, f = 0,5·sin 11t + 0,3·sin 23t + 0,2·sin 5t) et la couleur de `EmberGlow` (FF5A17 vers FFA040, 0,2 + 0,15·f).

## Tapis Cash Register (2026-11-08)

- `PLOT_Treadmill_CashRegister` (CashRegisterTreadmill.glb de Clément, déjà en studs) est dans `Assets/Plots`, au même pivot, sans tag. Il garde ses 2 900 triangles : l'alléger abîmait les pièces et les billets. Les pièces à deux couleurs sont séparées (`Bills` et `BillsBandGreen`, `Register` et `RegisterGold`). Bande plate à y 0,90 ; `BeltTexture` a une tuile de 3,44 × 1,72.
- `CashRegisterTreadmill.lua` **n'est pas posé**. Copie de référence : `_scripts/CashRegisterTreadmill_reference.lua`. La partie fixe est dans `treadmill_fx.luau`, dossier `CashFX` : `PillarFX1` et `2` (Beam `Stream` de billets qui défile seul, pièces qui jaillissent, scintillements, lumière dorée), `DrawerFX` (billets qui s'envolent du tiroir), `RegisterLight`, `GroundGlow`, plus `Belt.RunBurstPoint` avec `RunBurst` (billets) et `RunBurstCoins`, éteints.
- **Pour Ironix** : défiler `BeltTexture` (3 et 9 studs/s), allumer `RunBurst` et `RunBurstCoins` pendant la course, passer `CashFX.DrawerFX.Bills.Rate` de 3 à 9 et `CashFX.PillarFXn.Stream.TextureSpeed` de 0,35 à 0,9 en course, faire pulser la couleur de `GlowMint` et `CashFX.RegisterLight.Light` (1,3 à 1,9, sinus 3 rad/s).
- Showroom : `_SHOWROOM_CLEMENT/TAPIS`, 7 tapis (base, argent, Void, Fire, Ice, Gold, Cash Register). ContractChecker en Edit : « Contrat : OK ».

## Tapis Police (2026-11-08)

- `PLOT_Treadmill_Police` (PoliceTreadmill.glb de Clément, déjà en studs) est dans `Assets/Plots`, au même pivot, sans tag. Il fait 1 899 triangles : seuls les rubans de chantier et les menottes sont allégés, sans changer la forme. Les pièces multicolores sont séparées (`FramePanelWhite`, `BarriersPanelWhite`, `LightBarChrome`, `PoliceCapBadgeGold`, `PoliceCapPoliceNavy`, `TrafficConesPanelWhite`). Bande plate à y 0,90 ; `BeltTexture` a une tuile de 3,4 × 1,7.
- `PoliceTreadmill.lua` **n'est pas posé** (référence : `_scripts/PoliceTreadmill_reference.lua`). La partie fixe est dans `treadmill_fx.luau`, dossier `PoliceFX` : `FlareR1-2` et `FlareB1-2` (émetteurs à Rate 0), `Light_red` et `Light_blue` (PointLight à 1,5 au repos), `Sweep_red` et `Sweep_blue` (SpotLight et Beam vers la rue), `StarFX1-2` (badge et casquette), `RunTrail` (Trail modèle, éteint), plus `Belt.RunBurstPoint.RunStreak` éteint.
- **Pour Ironix** (presque tout ce tapis est animé) : cycle de 0,9 s, rouge-rouge puis bleu-bleu (flash de 0,12 s à 0 et 0,2 s, décalé de 0,45 s pour le bleu) ; pendant un flash, `SirenRed`/`SirenBlue` en couleur pleine (sinon assombrie à 65 %), `PoliceFX.Light_*.Light` à 6 (sinon 0), et `Emit(1)` sur les `Flare` du côté au début du flash. Rotation de `PoliceFX.Sweep_red` et `Sweep_blue` autour de Y à 4,5 rad/s en sens opposés. En course : défilement de `BeltTexture`, `RunStreak` allumé, et `PoliceFX.RunTrail` (Trail et ses deux attaches) copié sur le HumanoidRootPart, attaches en (±0,9, −0,5, 0,4).
- Showroom : `_SHOWROOM_CLEMENT/TAPIS`, 8 tapis. ContractChecker en Edit : « Contrat : OK ».

## Tapis Laser Vault, palier 4 (2026-11-08)

- `PLOT_Treadmill_LaserVault` (LaserVaultTreadmill.glb de Clément, déjà en studs) est dans `Assets/Plots`, au même pivot, sans tag. Il fait 1 899 triangles : châssis et liserés dorés allégés, sans changer la forme. Les pièces bicolores sont séparées (`FrameSteelPlate`, `VaultDoorVaultSteel`, `SecurityCameraCameraLens`). Bande plate à y 0,90 ; `BeltTexture` a une tuile de 3,4 × 1,7. L'arrière est un portique : `Collision_RearL`, `Collision_RearR` et `Collision_RearTop`, pas un mur, pour pouvoir monter par l'arrière.
- `LaserVaultTreadmill.lua` **n'est pas posé** (référence : `_scripts/LaserVaultTreadmill_reference.lua`). La partie fixe est dans `treadmill_fx.luau`, dossier `LaserVaultFX` : `Laser1` à `9` (Beam qui défile seul, étincelles aux deux bouts), `ScanGate` (laser de la porte arrière, au repos en haut), `CamScan1-2` (faisceau et SpotLight, pose de repos), `Alarm1-3` (`Flash` à Rate 0 et PointLight à 1), `LaserLight`, plus `Belt.RunBurstPoint.RunCoins` éteint. La pièce d'or est la même image que celle du Cash Register (on réutilise son ID).
- **Pour Ironix** : alarme (couleur de `AlarmGlow` de 3A0A10 vers FF3B5C selon a = max(0, sin(rate·t))², rate 5,5 au repos et 9 en course ; `Alarm*.Light` = 3a ; `Emit(1)` des `Alarm*.Flash` quand a > 0,9, au plus une fois toutes les 0,3 s), scintillement des Beam (transparence 0,05 à 0,13) et de `LaserBeams` (0 à 0,05), `ScanGate` à y = 3,5 + 2,5·cos(0,8t), `CamScan1-2` en lacet ± 0,45·sin(0,9t + 1,7·i), défilement de `BeltTexture` et `RunCoins` allumé pendant la course.
- Showroom : `_SHOWROOM_CLEMENT/TAPIS`, 9 tapis. ContractChecker en Edit : « Contrat : OK ».

## Tapis Toxic Gothic, palier 6 (2026-11-08)

- `PLOT_Treadmill_Toxic` (ToxicGothicTreadmill.glb de Clément, déjà en studs) est dans `Assets/Plots`, au même pivot, sans tag. Il fait 2 098 triangles : slime, barils et grille allégés, sans changer la forme. Pas d'image de bande dans le pack : `Belt` reste un MeshPart avec la texture à studs (comme la base), et les flèches `BeltArrows` sont en relief.
- `ToxicGothicTreadmill.lua` **n'est pas posé** (référence : `_scripts/ToxicGothicTreadmill_reference.lua`). La partie fixe est dans `treadmill_fx.luau`, dossier `ToxicFX` (34 émetteurs) : `Lantern1-2` (flamme 4×4 et lumière), 4 zones de bulles, `Drip1-20`, `Fumes` et `SmallFume1-3`, `GooLight`, `ToxicMist`, `Spores`, `GooGlow`, `RunTrail` (Trail modèle éteint), plus `Belt.RunBurstPoint.RunSplash` éteint. Les chauves-souris du script (BillboardGui en orbite) sont remplacées par des particules flipbook 2×2 qui voltigent (`BatsArch`, `BatsRoam`).
- **Pour Ironix** : pulsation de `ToxicGoo` (7CFF2E vers EAFFC8, 0,18·pulse, sinus 2,2 rad/s) et de `ToxicFX.GooLight.Light` (1,5 à 2,1), clignotement de `BeltArrows` (vers 1F4A12, 6 rad/s au repos, 12 en course), vacillement des `ToxicFX.Lantern1-2.Light` (1,3 + 0,4·sin 13t + bruit), défilement de `BeltTexture`, et pendant la course `RunSplash` allumé et `ToxicFX.RunTrail` copié sur le HumanoidRootPart (attaches en (±0,6, −2,7, 0,3)). Si on veut la ronde exacte des chauves-souris du script, c'est au code de la faire.
- Showroom : `_SHOWROOM_CLEMENT/TAPIS`, 10 tapis. ContractChecker en Edit : « Contrat : OK ».

## Tapis Candy, palier 7 (2026-11-08)

- `PLOT_Treadmill_Candy` (CandyTreadmill.glb de Clément, déjà en studs) est dans `Assets/Plots`, au même pivot, sans tag. Il fait 2 499 triangles : bordures, glaçage et bonbons allégés ; sucres d'orge, sucettes et menthe intacts (un essai plus poussé cassait les sucres d'orge). Plastique brillant, néons roses. Bande plate à y 0,86 avec `BeltTexture` (tuile 3,4 × 1,7), flèches `BeltArrows` en relief. L'arrière est l'arche des sucres d'orge : `Collision_RearL`, `Collision_RearR` et `Collision_RearTop`.
- `CandyTreadmill.lua` **n'est pas posé** (référence : `_scripts/CandyTreadmill_reference.lua`). La partie fixe est dans `treadmill_fx.luau`, dossier `CandyFX` (18 émetteurs) : `SprinkleArch` (vermicelles et lumière rose), `Sparkle1-4`, `Cotton1-5`, `CandyRain1-2`, `Popper1-6` (`Pop` à Rate 0), `CandyGlowGround`, `RunTrail` (Trail modèle éteint), plus `Belt.RunBurstPoint` avec `RunPops` et `RunPuff` éteints.
- **Pour Ironix** : rotation de `Peppermint` et `PeppermintSwirl` autour de l'axe avant-arrière (centre (0, 2,45, −3,1), 0,6 rad/s au repos, 2,5 en course, sens horaire vu de l'avant), pulsation de `CandyGlow` (FF4FA3 vers blanc, 0,3·pulse, sinus 2,6 rad/s) et de `CandyFX.SprinkleArch.Light` (1,2 à 1,8), clignotement de `BeltArrows` (FFD6EA vers FF4FA3, 6 rad/s au repos, 12 en course), `Emit` d'un `CandyFX.PopperN.Pop` au hasard (18 au repos, 30 en course, toutes les 0,9 à 1,5 s ; 0,4 à 1 s en course), défilement de `BeltTexture` (sens inverse : OffsetStudsV diminue), et pendant la course `RunPops`, `RunPuff` allumés et `CandyFX.RunTrail` copié sur le HumanoidRootPart (attaches en (±0,8, −1,5, 0,4)).
- Showroom : `_SHOWROOM_CLEMENT/TAPIS`, 11 tapis. ContractChecker en Edit : « Contrat : OK ».

## 2026-11-12 : tapis Void, dossier VoidFX (L-102 q12) et barre du banc (L-101 q3)

- **Tapis Void.** `PLOT_Treadmill_Void` a maintenant son dossier **`VoidFX`**, comme les autres paliers : c'est à ce dossier que le code reconnaît la variante. Ce sont des pièces invisibles, sans collision, tournées vers le coureur.
  - Allumées en permanence :
    - `Portal`, avec les émetteurs `Portal` (tourbillon) et `Ring` (anneau de runes), qui tournent seuls (`RotSpeed`) ;
    - `PortalLight/Light`, une PointLight violette `A35CFF` de luminosité 1,9 ;
    - `Flame_L` et `Flame_R`, avec l'émetteur `Flame` ;
    - `Aura_L` et `Aura_R`, avec les émetteurs `Glow` et `Sparkle`.
  - **`Belt/RunBurstPoint/RunBurst`** : des étincelles violettes aux pieds, **éteintes** (`Enabled = false`).
  - Les anciens points posés sur `VoidSteel` (`PortalPoint`, `FlamePoint_*`, `AuraPoint_*`) sont retirés.
  - Pour Ironix, ce que le code anime :
    - le défilement de `BeltTexture` ;
    - `RunBurst` allumé pendant la course ;
    - `PortalLight.Light` qui pulse de 1,4 à 2,4 ;
    - en course, le `Rate` de `Portal` et de `Ring` multiplié par 2.
  - Script : `tools/clement/hub/treadmill_fx.luau`.
- **Barre du banc.** Rien à changer. `Bench/Barbell/Bar` est un cylindre de 6,2 × 0,22 × 0,22, et son grand axe (X local) va d'une main à l'autre, le long de l'axe X de la boutique, puisque le joueur est allongé selon Z. Je l'ai vérifié sur le gabarit et sur les 6 boutiques. `BenchBarController` prend déjà le plus long côté de la boîte : la barre est orientée correctement, et les disques et colliers suivent.

## 2026-11-14 : disposition « Steal a … » (allée centrale et deux files)

Référence : `StealAShop-Art/References/2026-11-13_Boutiques/boutique_joueur_reference.webp`. Sauvegarde : `ServerStorage/Assets/MapBackup_Shops_2026-11-14_09h31` (gabarit, `PLOT_Shop_Rayons` et les 8 boutiques, sans tags). Fait sur le gabarit et sur `PLOT_Shop_Rayons`. Aperçu validé par Clément, puis files écartées de 2 studs de l'allée. Les 8 boutiques du hub sont réinstallées (même pivot, mêmes attributs), l'aperçu est retiré, et le ContractChecker est OK.

Repère du gabarit : avant vers −Z, porte en z −40.

- **Allée** : `Carpet`, un tapis rouge (x −6..6, de z −39,6 à −16,4) dans le cœur, prolongé par `Stage_2/CarpetExt` (de z −16,4 à 39,6). C'est du décor : sans collision, sans contact, sans requête.
- **Deux files face à face**, avec un rang tous les 7 studs (z = −32, −25, −18, −11, −4, 3, 10, 17, 24, 31) :
  - **`DisplayStand_xx`** : un socle bas de 4 × 1,2 × 4, centré en x = ±16 (dessus à y 1,5) ;
  - **`DisplaySlot_xx`** : en (±16, 1,5, z), **tourné vers l'allée** (axe −Z de l'attachment vers +X à gauche et vers −X à droite). Le code pose l'objet à ce point, donc l'objet regarde l'allée ;
  - **`UnboxBench_01` à `_04`** : au même point que `DisplaySlot_01` à `_04` ;
  - **`CollectPad_xx`** : en (±11, 0,36, z), devant l'objet, côté allée. Elle reste carrée (3,2) et couchée, et son texte se lit toujours en marchant vers la sortie.
- **Numérotation** : le rayon r occupe les rangs `2r−1` et `2r`. `4r−3` à gauche et `4r−2` à droite au premier rang, `4r−1` à gauche et `4r` à droite au second. Le rayon 1 (z −32 et −25) est le plus près de l'entrée. Le niveau k contient les rayons 1 à k : au niveau 1, le fond est à z −16,4 ; dès le niveau 2, à z 39,6.
- **`RayonSpot_02` à `_05`** (dans `Stage_2/RayonSpots`) : deux contours par rayon, un de chaque côté, autour des socles et des plaques.
- **Décor retiré**, parce qu'il gênait les files ou l'allée, ou ne servait à rien :
  - `Stage_2/Stock` et `Stage_2/Promo` ;
  - `Stage_3/WallShelves` (étagères murales et produits factices) ;
  - `Stage_5/Palms` et `Stage_5/RedCarpet` (l'ancien tapis à cordons).
- **Inchangé** : `RarestPedestal`, `StageUpgradePoint` (0, −18,6) et `StageUpgradePoint_2` (0, 37,6), `DisplayUpgradePoint` (−15,1, −36,5), `SpawnPoint`, `TrapSlot_xx`, `VaultSlot_xx`, `Treadmill`, `Bench`, les `UseZone`, `Bounds` et `DepositZone`.
- Contrôlé : socles, plaques et allée ne se chevauchent pas, et aucune autre pièce du gabarit n'est posée sur les files. Seule exception : la rambarde du fond du niveau 1, qui disparaît au niveau 2, quand le rayon 2 arrive. Un rang laisse 3 studs entre deux socles, et 3,4 studs entre une plaque et l'allée (files écartées de 2 studs à la demande de Clément).
- **Pour Ironix** :
  - aucun nom ne change ;
  - à vérifier dans le code : ce qui supposait un objet tourné vers −Z (étiquette au-dessus de l'objet, invite de vol, caméra de l'ouverture du colis sur le présentoir).

## 2026-11-14 : boutique moins large (48 studs au lieu de 64)

Demande de Clément, après le passage aux deux files. Sauvegarde : `ServerStorage/Assets/MapBackup_Shops_2026-11-14_10h10`. Fait sur le gabarit, avec la fonction `narrowWidth` de `plot_shop_builder.luau`. Les 8 boutiques du hub sont réinstallées (même pivot, mêmes attributs), et le ContractChecker est OK.

- **Murs à x = ±24.** Tout ce qui est au-delà de |x| = 10 est resserré vers le centre, de façon continue : x' = ±(10 + (|x| − 10) × 14/22). Rien ne se chevauche et rien ne se décolle.
  - Pièces concernées : façade, vitrines, murs, toit, auvents, barrières invisibles, champs de force, murets, rambardes et caméras.
  - Les carreaux du damier hors de |x| ≤ 24 sont retirés.
- **Nouvelles tailles** : `Bounds` et `PlotFloor` font 48 × 80 (x −24..24), et `DepositZone` va de x −23,7 à 23,7.
- **Points déplacés** : `DisplayUpgradePoint` passe en (−13,25, 0,3, −36,5) ; `CashPad`, toujours invisible et enfoui, suit la même règle. `SpawnPoint`, `StageUpgradePoint`, `StageUpgradePoint_2`, `TrapSlot_xx` et `VaultSlot_xx` ne bougent pas (|x| ≤ 10).
- **Inchangé** :
  - la porte (x −10..10) et l'allée (`Carpet` et `CarpetExt`) ;
  - les deux files : socles à x ±16, à 5,3 studs des murs, et plaques à x ±11 ;
  - les `RayonSpots` ;
  - `Treadmill` (x −24) et `Bench` (x 24), avec leurs `UseZone`, ainsi que `RarestPedestal` (x 7,5) : ils restent devant, aux coins de la façade.
- **À vérifier dans le hub** : les boutiques laissent 8 studs de pelouse de plus de chaque côté. Les allées du hub posées pour l'ancienne largeur sont à revoir, si besoin.

## Banc, potion de vitesse et murets (2026-11-14, L-149, L-150, L-157)

- Sauvegarde avant changement : `ServerStorage/Assets/MapBackup_Shops_2026-11-14_17h47`. Elle contient le gabarit, les rayons, les 8 boutiques et `POT_Speed`, sans tags.
- **Banc retiré** du gabarit `PLOT_Shop` et des 8 boutiques du hub : le modèle `Bench` entier, avec sa `UseZone` et son `UpgradePoint`. Sa place, en (24, 0, -46) devant la façade, reste vide. Le builder ne le construit plus ; `buildBench` existe encore mais n'est plus appelé.
- **`POT_Speed` supprimé** de `ReplicatedStorage/Assets/Potions`. Il reste `POT_Invisibility`, `POT_Money` et `POT_Strength`. **`ICON_POT_Speed` n'existait nulle part** dans Studio, donc il n'y avait rien à supprimer.
- **`Stage_2/Murets_Sides`** : `HideFromStage = 3` est remplacé par `HideFromWalls = 1` dans le gabarit, et dans le builder. Les 8 boutiques du hub n'ont pas de `Stage_2` (le code le copie depuis le gabarit), donc il n'y avait rien à y changer.
- **ContractChecker en Edit** : aucune ligne rouge, mais 9 lignes orange disent toutes « Bench introuvable » ou « tag Bench pas posé ». C'est la copie du code dans le Studio de Clément qui n'est pas à jour : sur le disque, `Contract/Tags` n'a plus `Bench`, et `Models.luau` le marque `Optional = true`. Ces lignes devraient disparaître à la prochaine synchro d'Ironix.
