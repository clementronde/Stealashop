# Fiche de construction : zone 5, Paris en automne (4e zone)

Pour le chef Map, puis le chef 3D. Même méthode que Tokyo, Los Angeles et Londres. Planche : `StealAShop-Art/Captures/2026-11-28_biomes/Z5.jpg`. Lu dans la place DEV le 28/11, en lecture seule.

- **Emprise** : x 530 à 718, chaussée |z| < 46,5, trottoirs |z| 47 à 93, façades à |z| = 60.
- **Magasins PNJ** : `STORE_Z5_GalerieDArt` au nord et `STORE_Z5_Antiquaire` au sud, en x 578 à 658.
- **Voisins** : Los Angeles, chaud, saturé, sable et orange, à l'ouest ; New York, neige au crépuscule, bleu et blanc, à l'est.

**L'idée** : un matin d'automne doux, pierre crème et zinc gris-bleu, feuilles orange et or. **On retire la neige**, qui reste à New York seul.

**Pour ne pas ressembler à Los Angeles**, sa voisine :
- Paris est **éteint et élégant** (crème, zinc, bordeaux, or), là où Los Angeles est **saturé** (orange, rose, turquoise) ;
- le feuillage de Paris est **doré** (marronniers), celui de Los Angeles **vert** (palmiers) ;
- le sol de Paris est en **pavés gris-beige à joints sombres**, celui de Los Angeles est un bitume chaud et du sable.

## 1. Sol (Studio, en pièces, tout de suite)

| Pièce | Aujourd'hui | Proposé |
| --- | --- | --- |
| `Greybox/Corridor/Zone_5/Ground/Street` (188 × 93) | Plastic #686c76, **couvert par la couche de neige** de `Street_Paris/Ground` | Plastic **#8f8a80**, des pavés gris-beige, avec un quadrillage de joints sombres **#5e5a54** (bandes de 0,2 stud tous les 3 studs) ; tenons gardés |
| `Side_N`, `Side_S` (trottoirs 188 × 46) | SmoothPlastic #b49888 | Plastic **#d8cfbf** calcaire, avec une bordure de 0,6 stud en granit **#7d7a75** |
| `SideWall_N1/N2/S1/S2` | SmoothPlastic #bc957c | Plastic **#efe3c8** pierre, chaperon en zinc **#6f7f8f**, grille noire **#1e2022** |
| `Street_Paris/Ground` (51 pièces : la couche de neige) | blanc #ecf2f8 | **retirée**, à remplacer par des **tas de feuilles** (#e07a2f, #d4a72c, #b2502a) au pied des arbres et le long des trottoirs |

- On retire aussi les pièces en `Ice` (#d6ecfa, ×32) et la neige posée sur les toits et les murets.
- **Transition** : une coupure de couleur nette au sol à x = 530 (pas de marche : décision prise à Tokyo). Le sable de Los Angeles s'arrête net sur les pavés gris ; depuis Los Angeles, on doit voir la tour Eiffel et l'or des arbres.

## 2. Monument : la tour Eiffel (déjà là)

- Elle existe : `Street_Paris/Landmarks/EiffelTower` (105 pièces, **300 studs**, en x 624, z 233, au nord, derrière le jardin). On la garde.
- On la met en valeur :
  - peinte en **brun-bronze #6b5a45** ;
  - **ampoules dorées** (`Neon` **#ffcc48** faible) le long des quatre arêtes et à chaque étage, pour qu'elle brille au matin brumeux et la nuit ;
  - un **phare** au sommet (une `SpotLight` qui tourne n'est pas possible sans script : on met une `PointLight` fixe forte).
- Elle doit se voir dans l'axe de la rue depuis la sortie de Los Angeles (x 530). Si une façade la cache, on baisse `District/Building_NW1` ou `NW2` de quelques studs.
- Le **dôme doré** (`Landmarks/GoldenDome`, 23 pièces, au sud) reste : c'est le second repère.

## 3. Murs et façades (Studio, en pièces, par `zone5_paris.luau`)

| Rôle | Couleur | Matière |
| --- | --- | --- |
| Pierre des immeubles | **#efe3c8** (et **#e8dcc4** en variante) | Plastic (tenons) |
| Toits en zinc et mansardes | **#6f7f8f** | Plastic |
| Balcons et grilles | **#1e2022** | Plastic |
| Devantures (on alterne) | **#b23a48** bordeaux, **#1a3e2e** vert, **#2e3a50** bleu nuit | Plastic |
| Dorures et lettres des enseignes | **#d4a72c** | Plastic |
| Fenêtres | **#344052** | Glass (on garde) |

- **Les 10 immeubles Haussmann identiques** (`Facades/Haussmann_N1` à `N5` et `S6` à `S10`, 43 à 46 pièces, tous à 47 studs) : c'est le « AI slop » de la zone. On en fait **3 variantes** qu'on alterne :
  - **5 étages** (47 studs), balcon filant au 2e ;
  - **6 étages** (54 studs), avec une mansarde de plus ;
  - **un angle arrondi** (rotonde) avec un dôme de zinc.
  On varie aussi la couleur de la devanture du rez-de-chaussée (bordeaux, vert, bleu nuit) et l'enseigne, qui devient un picto voxel (tasse, baguette, livre, fromage), sans mot (règle des enseignes, `da-enseignes-sans-slop.md`). Les **cheminées** et les **pots de fleurs rouges** sur les balcons font le décor posé sur le haut des murs.
- `District/Building_*` et `District/BackRow_*` (20 à 36 pièces) : on les met dans la même palette, en plus simple (c'est l'arrière-plan).

## 4. Objets signature (3 ou 4, répétés en nombre)

| Objet | Combien | Où | Qui |
| --- | --- | --- | --- |
| **Marronniers dorés** (arbres du pack Yasu déjà en place : `Garden/Tree_*` ×14, `District/YardTree_*` ×8, `BoulevardTree_*` ×7) | on les garde, **+8** le long des trottoirs de la rue | tous les 18 studs : c'est l'élément répété de la zone | **Studio** (chef Map) : feuillage **#e0a030** et **#c8641e** (`SurfaceAppearance.Color`), en alternant |
| **Terrasse de café** (on part de `CafeTerrace`, 30 pièces) | 3 | devant la Galerie et l'Antiquaire, et au bout de la rue | **Blender, en voxel à tenons** (chef 3D) : tables rondes, chaises en rotin, auvent bordeaux |
| **Fontaine Wallace** verte (remplace `Props/Fountain`, 9 pièces) | 2 | sur les trottoirs | **Blender, en voxel** (chef 3D) |
| **Étals de bouquinistes** (boîtes vertes avec livres) | 4 | le long du trottoir sud | **Blender, en voxel** (chef 3D) |
| **Lampadaires parisiens** à trois lanternes (remplacent `Props/Lamp_N1, N3, S1, S2`, 7 pièces, et `District/BoulevardLamp_*`, 3 pièces) | 8 | tous les 22 studs | **Studio** (chef Map) |

- On garde les **colonnes Morris** (`Props/MorrisColumn_N`, `MorrisColumn_S`, 8 pièces), le **kiosque à musique** (`Garden/Bandstand`) et le **manège** (`Garden/Carousel`).
- Les 10 **pigeons** de 3 pièces (`Pigeons/Pigeon_*`) et les **bancs** de 3 pièces (`Garden/Bench_*`) : on les refait en voxel avec le reste du chef 3D (pigeons gris, bancs verts), ou on les retire.
- **Météo** : à la place de la neige (`Street_Paris/Weather`), des **feuilles qui tombent en tournant** (ParticleEmitter, feuilles orange et dorées, environ 30 à l'écran). On garde le **marchand de marrons** et la **musique d'accordéon** d'`Ambience_Paris`. Le budget téléphone reste sous 60 particules à l'écran.

## 5. Entrée de zone (Studio, en pièces)

- Aujourd'hui, l'entrée est d'hiver (`Entrance/Fir_N`, `Fir_S` et `Candelabra_N`, `Candelabra_S`). **On retire les deux sapins**, et on garde les candélabres, repeints en vert bronze.
- On ajoute une **arche de métro Art nouveau** au-dessus de chaque trottoir, ou une seule au-dessus de la chaussée à 26 studs de haut minimum : fer vert **#2f5d4a** en courbes, deux lampes ambre **#ffb347** et l'enseigne « MÉTRO » en lettres crème sur fond vert.
- La coupure de couleur au sol et le bandeau de zone (code, déjà là) marquent la frontière.

## 6. Décors répétés à remplacer ou à habiller (chemins sous `Workspace/Map/Zone_5/Street_Paris/`)

| Chemin | Nombre | Pièces | Ce qu'on fait |
| --- | --- | --- | --- |
| `Facades/Haussmann_*` | 10 | 43 à 46 | 3 variantes (étages, angle arrondi), devantures, enseignes, pots de fleurs |
| `Ground` (couche de neige) et les pièces `Ice` | — | 51, puis 32 | retirées, remplacées par des tas de feuilles |
| `Weather` (neige) | 1 | 1 | remplacé par les feuilles qui tombent |
| `Entrance/Fir_N`, `Fir_S` | 2 | 11 | retirés |
| `Props/Lamp_*`, `District/BoulevardLamp_*` | 4 et 3 | 7 et 3 | lampadaires parisiens |
| `Props/Fountain` | 1 | 9 | fontaines Wallace voxel |
| `Pigeons/Pigeon_*`, `Garden/Bench_*` | 10 et 4 | 3 | refaits en voxel ou retirés |

## 7. Qui fait quoi

- **Chef Map, dans Studio, en pièces, tout de suite** :
  - retirer la neige ; poser le sol, les joints, les trottoirs, les murets et la coupure de couleur de transition ;
  - les 3 variantes des Haussmann, les devantures, les enseignes et les pots de fleurs ;
  - la tour Eiffel peinte et éclairée ;
  - les marronniers dorés, les lampadaires et l'arche de métro ;
  - les feuilles qui tombent ;
  - le tout dans `zone5_paris.luau` et `zone5_ambience.luau`, relançables, avec une sauvegarde dans `ServerStorage/MapBackups` avant de commencer et une ligne au journal de Studio.
- **Chef 3D, dans Blender, en voxel à tenons** : les terrasses de café (3), les fontaines Wallace (2), les étals de bouquinistes (4) et, si on les garde, les pigeons et les bancs. Il montre un objet à Clément avant les autres.
- **Cantin** : la lumière du matin de la zone (`da-ambiances-zones-cantin.md` : ClockTime 9,8, ColorShift_Top 255,220,190, Atmosphere Haze 1,4). En attendant, la zone doit déjà se lire automnale sous le ciel commun.
- **Règles** : aucun script dans les modèles ; les noms du contrat ne changent pas (`STORE_Z5_*`, `ShelfSlot_*`, `NPCStore`, `Zone`, `TruckSpawn`) ; pas de Play sans le jeton.
- **À montrer à Clément**, en vraie 3D, avant et après :
  - la sortie de Los Angeles vers Paris (changement de sol et tour Eiffel au fond) ;
  - le milieu de la rue avec les marronniers et les feuilles ;
  - une terrasse de café.
