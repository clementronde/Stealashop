# Retours de Clément du 2026-11-10 (soir) : poursuite, gains visibles, boutique, inventaire

Demandes de Clément, à reporter dans la liaison pour Ironix. Les parties visuelles sont faites ou en cours chez Clément (voir plus bas). Rien n'est commité.

## Pour Ironix (code)

1. **Poursuite du vigile plus naturelle.** Clément : « quand on va à droite, le policier met 1, 2 secondes à aller à droite ». Le vigile doit suivre le joueur sans retard. Pistes, à toi de choisir :
   - viser la position du joueur à chaque image quand il le voit (`MoveTo` sur la position actuelle, ou un peu en avance selon sa vitesse) ;
   - ne passer par `PathfindingService` qu'en l'absence de ligne de vue ;
   - vérifier que le vigile appartient bien au serveur (`SetNetworkOwner(nil)`).
2. **Argent hors ligne** : après Claim, le montant vole en bas à gauche jusqu'à l'argent total, puis « +$X » vert s'affiche à côté. Le prototype le fait avec `UI_Offline.Flyer` (voir `ui-feel2-horsligne-poursuite-barre.md`).
3. **Gains visibles au-dessus du joueur** :
   - **tapis** : à chaque gain de vitesse, « +2 Speed/s » surgit au-dessus de la tête, avec le vrai gain ;
   - **banc** : la même chose pour la force (« +X Power »).
   - Modèle de Clément : `ReplicatedStorage/Assets/UI/BB_Gain` (voir plus bas).
4. **Banc** :
   - **la barre ne bouge pas pendant `BenchLift`** : la barre fait partie du modèle du banc, l'animation du joueur ne la déplace pas. Il faut l'accrocher aux mains pendant l'animation (soudure à `RightHand`, ou un `Motor6D` de la barre vers le rig), ou la faire suivre par le code ;
   - **le joueur soulève tout seul**, sans cliquer, tant qu'il est assis sur le banc (comme le tapis).
5. **Boutique du joueur, le plus simple possible** :
   - retirer la caisse globale (`CashPad`, tag du contrat : à sortir du contrat, en l'annonçant) et la caisse enregistreuse de la boutique ;
   - **ramasser l'argent par objet** : un rectangle au sol devant chaque objet exposé, qui affiche le total d'argent gagné par cet objet ;
   - quand on marche dessus, on encaisse : « +$X » surgit au-dessus du joueur, puis vole en bas à gauche jusqu'à l'argent total ;
   - le rectangle est fait par la session « boutique-joueur » : `CollectPad_xx/Plate/AmountGui/Amount` (voir en bas).
6. **Inventaire** :
   - le bouton **Equip Best** (`InventoryController.EquipBest`) ;
   - les **onglets à droite** : `ItemsTab` (en haut), `BoxesTab`, `ToolsTab`, `PotionsTab`. Un onglet n'affiche que sa rubrique.
7. **Récompenses** : après Claim, la récompense surgit, puis vole en bas à gauche (l'argent vers l'argent du HUD), comme l'argent hors ligne.
8. **Animations d'interface en général** : les valeurs de `Config/UiMotion` proposées dans `ui-feel-sons-victoire-camion.md`, et le même « vol vers le HUD » pour tout gain (`UI_HUD.CashFly`, voir plus bas). Tableau complet des valeurs : `docs/claude/notes/ui-motion-skilltree.md`, section « Étendues à tout le jeu ».

## Côté Clément : construit dans Studio (Edit), sans script

- **`ReplicatedStorage/Assets/UI/BB_Gain`** (nom demandé par la liaison L-091) : BillboardGui (4,5 studs + 70 px de large, 3,4 studs au-dessus de la tête, `AlwaysOnTop`) avec `Row`, qui contient `Icon` et `Amount`.
  - Couleurs proposées :
    - vitesse : `4fd2ff`, icône `80577187405028` (celle du HUD) ;
    - force : `ff7a3a`, icône `90840823209764` ;
    - argent : `5cff4a`, icône `138179722277427`.
  - Animation du prototype : `Row` passe de 0,4 à 1 (Back, 0,16 s), le billboard monte de 2,2 studs en 1 s et s'efface à partir de 55 %. Décalage horizontal au hasard de ± 1 stud.
  - Le prototype le déclenche à chaque hausse des attributs `Speed`, `Strength` et `CashCollected` du joueur, avec la vraie hausse.
- **`UI_HUD.CashFly`** (cadre plein écran, transparent ; remplace l'ancien `UI_Gain`) : `Template`, la case billets + `FlyerAmount`, que le code clone et fait voler jusqu'à l'argent du HUD (`StatsPanel.CashRow`, qui sursaute à l'arrivée) ; et `CounterPop`, le « +$X » vert posé à côté de l'argent. Elle sert aux rectangles d'argent, à l'argent hors ligne et aux récompenses. Prototype jouable en Edit : `tools/clement/gain_proto.luau` (5 boutons : TREADMILL, BENCH, CASH PAD, OFFLINE, REWARD).
- **`UI_Inventory`** :
  - `Root.Tabs` à droite de la fenêtre : `ItemsTab` (en haut), `BoxesTab`, `ToolsTab` et `PotionsTab`, chacun avec `TabIcon`, `TabLabel`, `Shade` et `Selected` (allumé sur l'onglet choisi) ;
  - la colonne de gauche `Equipment` est retirée (L-091). `List` prend toute la largeur, avec 6 cartes par ligne ;
  - deux nouvelles rubriques dans `List` : `ToolsSection` (son `Template` est l'ancienne carte d'outil : `Icon`, `ToolName`, `ToolStat`, `EquipButton`, `EquippedPill`) et `PotionsSection` (sans `Template` : pas encore de potions) ;
  - un onglet n'affiche que sa rubrique ; seule `ItemsSection` est visible au départ ;
  - `Root` passe à X 0,47 pour que les onglets tiennent sur téléphone (cases de 56 × 48 px) ;
  - maquette Figma à jour (PC, téléphone, liste des noms) : https://www.figma.com/design/fXjkvf39sRhlsL94YicwDH?node-id=67-1018, https://www.figma.com/design/fXjkvf39sRhlsL94YicwDH?node-id=69-1294 et https://www.figma.com/design/fXjkvf39sRhlsL94YicwDH?node-id=70-1574.
- **`UI_HUD.HeistTimer`** (le chrono du vol) : un gros bouton orange en haut au centre. C'est toujours le même `TextLabel` dans lequel le code écrit ; le bouton est son enfant `Box`, derrière le texte. Le prototype le fait battre à chaque seconde, avec un tic (`UI_Click_Tick`), et le passe au rouge sous 3 s.
- **`UI_Chase`** : le bloc en haut à droite (`Alarm` : gyrophares et « GUARD! RUN! ») est retiré. À la place, `RunBanner` (« RUN! » sur un bouton rouge) en haut au centre, sous le chrono s'il est affiché.
- **Sons** :
  - `MUS_Heist` = « Stressful Countdown » (APM, 1839757863), validé par Clément ;
  - `Heist/Heist_Breath` : une respiration discrète en boucle (ProSoundEffects 9125573009, volume 1 : le son est très bas à la source), jouée avec la tension.
- **Intérieur de la boutique** (poteaux noirs inutiles près des portes, `CashPad`, caisse, rectangles au sol par objet) : transmis à la session « boutique-joueur », qui note ici les noms qu'elle pose.

Prototype : `tools/clement/feel2_proto.luau`. Il n'a pas pu être relancé : la session « boutique-joueur » travaille dans Studio.

## Intérieur de la boutique simplifié (session « boutique-joueur », 2026-11-10)

Fait dans Studio (Edit) sur `Assets/Plots/PLOT_Shop`, les 6 boutiques `Map/Hub/Shops/PLOT_Shop_01` à `_06` et `Assets/Plots/PLOT_Shop_Rayons`, et reporté dans `tools/clement/hub/plot_shop_builder.luau` et `tools/clement/collect_pad_fx.luau`.

- **Retirés** : les produits factices des rayons (`Prod_*`, `Bulk_*`), les planches `Board_*`, les étiquettes `PriceStrip_*` et `PriceTag_xx`, dans la boutique et dans `PLOT_Shop_Rayons` ; les deux bornes noires près de la porte, côté intérieur (`DisplayKiosk`, `DisplayKioskScreen`, `UpgradeKiosk`, `UpgradeKioskScreen`) et toute la caisse `Checkout` (comptoir, caisse enregistreuse, panneau CASH).
- **`DisplayUpgradePoint`** reste au même endroit, mais il est maintenant un enfant de `PlotFloor` (`UpgradeController` le lit encore).
- **`CashPad`** : il reste seulement pour que le contrat soit vert (`Models.luau`, et `Tags.luau` qui en compte 6). C'est une pièce invisible et enfouie dans le sol, à 0,1 stud de hauteur (y −0,5 à −0,4), avec `CanTouch`, `CanQuery` et `CanCollide` coupés, sans texte.
  - Plus personne ne marche dessus : l'encaissement par le CashPad ne marche plus en Play.
  - Pour Ironix : sortir `CashPad` du contrat, puis Clément le supprime. Les vieux greybox de `ServerStorage/_GREYBOX_REMPLACE` portent encore ce tag.
- **Rectangle d'argent par objet**, un par présentoir : `CollectPad_01` à `_20`. Ce sont les noms existants, rangés dans `Rayon_0n`, dans la boutique ou dans `PLOT_Shop_Rayons`.
  - Taille : 4,4 × 2,6 studs, devant le présentoir, côté rue.
  - **Un seul rectangle visible (L-091)**, plus de cadre doré :
    - `CollectPad_xx` est maintenant **invisible** (`Transparency = 1`). C'est toujours la pièce à détecter, avec `CanTouch` actif.
    - `Plate` est la plaque néon verte, de la même taille que la case (4,4 × 0,12 × 2,6), posée dans le même volume.
      - `SinkDepth` = 0,1 : le code peut l'enfoncer de 0,1 stud.
      - Elle contient `BurstPoint` (les émetteurs `Sparkles`, `Ring` et `Coins`, éteints, avec `EmitCount`) et `Glow` (une PointLight éteinte).
  - **Montant, nouveau** : `CollectPad_xx/Plate/AmountGui` est un SurfaceGui sur la face du dessus, qui contient le TextLabel **`Amount`**. Le texte par défaut est « $0 ». Le code y écrit le total gagné par l'objet, par exemple « $1.2K », et remet « $0 » après l'encaissement.
  - Il remplace l'ancien `LabelGui_Top/Label` (« $ »).
  - **`BB_Collect` est retiré** (décision de Clément, L-091). Il n'en existait qu'une copie, le modèle de `Assets/UI`, et aucune n'était posée dans le gabarit ni dans les boutiques. Aucun code ne le lit, et il n'est pas dans `Contract/UI.luau` : le ContractChecker reste vert. Le code écrit le montant dans `CollectPad_xx/Plate/AmountGui/Amount`.
- Contrat : aucune ligne rouge en Edit. Les lignes orange portent sur les animations, pas sur la boutique.
- Les 6 boutiques du hub ont été réinstallées depuis le gabarit, au même pivot, au niveau 1.

## Boutique, 2e passe (session « boutique-joueur », 2026-11-11)

Fait dans Studio (Edit) sur `PLOT_Shop`, `PLOT_Shop_Rayons` et les 11 `PLOT_Treadmill_*`. Reporté dans `plot_shop_builder.luau`, `collect_pad_fx.luau` et `treadmill_assets.luau`. Les 6 boutiques du hub sont réinstallées au même pivot, au niveau 1. ContractChecker : aucune ligne rouge.

- **Plus de terrasse** : `Terrace` et `TerraceEdge` sont retirés.
  - Le tapis, le banc, `RarestPedestal` et les `ShutterRails` reposent sur le sol du hub (y 0 au lieu de 0,3).
  - Le support d'haltères `GymRack` (niveau 2) est retiré.
- **Tapis et banc identiques dans les 6 boutiques** :
  - `Treadmill` est une copie de `PLOT_Treadmill_Base` ;
  - `Bench` n'a plus de couleur d'accent ;
  - les variantes restent rangées dans `Assets/Plots`, et c'est le code qui les échange.
- **`UseZone`** (nouveau nom, pour la liaison) : une Part invisible dans `Treadmill`, dans `Bench` et dans chaque `PLOT_Treadmill_*`.
  - Elle a `CanCollide`, `CanQuery` et `CastShadow` coupés, et `CanTouch` actif.
  - Elle couvre la machine avec 3 studs de marge autour, sur 8 studs de haut. Elle s'arrête avant la façade : 1,5 stud de marge à l'arrière du tapis, et 0,2 stud du mur pour le banc.
  - Le code fait monter le joueur sur la machine dès qu'il entre dans la zone.
  - Comme chaque variante de tapis a sa propre `UseZone`, l'échange de variante la garde.
- **Plaques d'argent `CollectPad_xx`** : carrées, 3,2 × 3,2 au sol, collées au présentoir, côté porte.
  - Elles sont couchées : la face **`Front`** (−Z local) regarde le ciel, et l'axe +Y local pointe vers la porte de la boutique. Le texte se lit donc à l'endroit quand on marche vers la sortie. Vérifié par le calcul sur les 6 boutiques du hub, pas en capture.
  - `Plate` occupe le même volume. `Plate/AmountGui` est maintenant sur la face **`Front`** (et plus `Top`), avec le TextLabel `Amount`.
  - Pour Ironix : la plaque étant couchée, il faut l'enfoncer de `SinkDepth` vers le **bas du monde** (−Y du monde), pas selon son axe local Y.
  - `BurstPoint` suit les axes du monde, donc les émetteurs tirent vers le ciel.

## La boutique grandit avec les rayons (session « boutique-joueur », 2026-11-11)

Constat :
- Les 6 boutiques du hub sont posées au **niveau 1**, sans `Stage_2` à `Stage_5`.
- `RayonService` pose les visuels du rayon k, mais rien ne fait grandir le bâtiment. Les rayons 2 à 5 (z −18 à +16 local) sortent donc du petit bâtiment du niveau 1 (z −40..−16).

La géométrie du gabarit `Assets/Plots/PLOT_Shop` est juste. Le niveau 1 contient le rayon 1. Dès le niveau 2, le sol (`Stage_2/PlotFloorExt`), les grands murs invisibles et le volume vont jusqu'à z 40, ce qui couvre les 5 rayons.

Changement côté modèle : ce qui n'existait qu'à partir du niveau 2 (attribut `FromStage`) est rangé dans `Stage_2` :
- `Stage_2/Barriers` : `Barrier_L`, `Barrier_R`, `Barrier_B` et `Barrier_Lid`, les grands murs invisibles ;
- `Stage_2/RayonSpots` : `RayonSpot_02` à `_05`.

L'attribut `FromStage` n'existe plus. Chaque boutique du hub porte l'attribut **`AccentColor`** (Color3).

**Règle pour Ironix** (niveau de la boutique = nombre de rayons) :
1. `k` = nombre de rayons débloqués (1 à 5), le même que `RayonService` (`ceil(présentoirs / 4)`).
2. **Copier les niveaux 2 à k.** Pour `j` de 2 à 5 :
   - si `j ≤ k` et que la boutique n'a pas d'enfant `Stage_j`, cloner `Assets/Plots/PLOT_Shop/Stage_j` et le poser comme les `RayonVisuals` (`plot:GetPivot() * gabarit:GetPivot():Inverse() * copie:GetPivot()`) ;
   - le parenter à la boutique sous le nom `Stage_j` ;
   - si `j > k`, détruire le `Stage_j` de la boutique.
3. **Recolorer les copies.** Leurs pièces (et lumières) qui portent l'attribut `Accent = true` prennent la couleur `plot:GetAttribute("AccentColor")`.
4. **Cacher selon `HideFromStage`.** Dans toute la boutique, copies comprises, tout ce qui porte **`HideFromStage ≤ k`** est caché, et le reste est remontré :
   - cacher : `Transparency = 1` et `CanCollide`, `CanTouch`, `CanQuery` coupés ;
   - remontrer : les valeurs d'origine, enregistrées avant de cacher, pour le cas d'une renaissance.
   - Exemples : les petits murs invisibles `Barrier_L1`, `R1`, `B1` et `Lid1`, `Stage_1/Railings` et `Stage_1/ForceField` à partir du niveau 2 ; `Stage_2/ForceField` et `Murets_Sides` à partir du niveau 3 ; `EntryMat`, `Stage_3/Pilasters` et `Stage_4/SignNeon` au niveau 5.
5. **Faire les étapes 2 à 4 avant `RayonService.apply`.** Les `RayonSpot_0n` arrivent avec `Stage_2`.
6. **Panneau du niveau suivant** : `StageUpgradePoint` au niveau 1, `StageUpgradePoint_2` aux niveaux 2 à 4, aucun au niveau 5.
7. **Ne jamais modifier le gabarit `PLOT_Shop` lui-même** : il contient les 5 niveaux.

Reste à régler : `Bounds` et `DepositZone` gardent la grande taille (z −40..40) dès le niveau 1. Au niveau 1, un adversaire qui passe sur la pelouse derrière la petite boutique est donc sorti, comme s'il était dedans. Si besoin, le code peut leur donner le fond `z = −16` au niveau 1. Sinon, on en fait des pièces par niveau : à décider avec Clément.
