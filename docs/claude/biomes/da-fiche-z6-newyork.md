# Fiche de construction : zone 6, New York, neige au crépuscule (5e zone)

Pour le chef Map, puis le chef 3D. Même méthode que les zones précédentes. Planche : `StealAShop-Art/Captures/2026-11-28_biomes/Z6.jpg`. Lu dans la place DEV le 28/11, en lecture seule.

- **Emprise** : x 718 à 868, chaussée |z| < 46,5, trottoirs |z| 47 à 93, façades à |z| = 60.
- **Magasins PNJ** : `STORE_Z6_Banque` au nord et `STORE_Z6_SalleDesCoffres` au sud, en x 778 à 858.
- **Coffre de la Fortune Tower** : `FortuneVaultSpawn`. On ne touche pas à son emprise (x 843 à 869, |z| < 20).
- **Voisin** : Paris en automne, crème et or, à l'ouest. C'est la dernière zone.

**L'idée** : la zone finale, la plus spectaculaire. Un crépuscule d'hiver froid, de la neige partout, des fenêtres jaunes qui s'allument et des taxis jaunes. **Ce n'est jamais la nuit du jeu** (décision de Clément) : le ciel reste bleu acier et pêche, plus clair que la vraie nuit.

## 1. Sol (Studio, en pièces, tout de suite)

| Pièce (Greybox/Corridor/Zone_6/Ground) | Aujourd'hui | Proposé |
| --- | --- | --- |
| `Street` (150 × 93) | Plastic #28282c | Plastic **#5d6470**, de la gadoue gris-bleu, avec 4 **traces de pneus** plus sombres (**#3a3f48**, 3 studs de large) le long des voies ; tenons gardés |
| `Side_N`, `Side_S` (trottoirs 150 × 46) | Plastic #808084 | Plastic **#eef3f8**, de la neige tassée ; des **congères** de 0,6 à 1,2 stud le long de la bordure, qui cachent le trottoir par endroits |
| `SideWall_N1/N2/S1/S2` | SmoothPlastic #b57d80 | Plastic **#8c3b2a** brique, chapeau de neige **#eef3f8** de 0,8 stud |
| Passages piétons | blanc | blanc **#f2eefc**, à moitié couverts de gadoue par endroits (on doit encore les lire) |

- `Street_NewYork/Ground` (71 pièces) : on garde la neige posée existante (bandes au pied des façades, haut des murets, d'après `zone6_ambience.luau`), et on l'élargit.
- **Transition** : une coupure de couleur nette au sol à x = 718 (pas de marche : décision prise à Tokyo). Les pavés gris-beige et les feuilles dorées de Paris s'arrêtent net sur la neige ; depuis Paris, on doit voir la grande tour éclairée au fond et la neige qui tombe.

## 2. Monument : la tour Art déco du fond (Studio, en pièces à tenons)

- Elle existe déjà sous forme de boîte : `Street_NewYork/Backdrop/EndTower` (40 pièces, **229 studs**, en x 891, au bout de la rue, derrière le coffre). Elle ferme la perspective : c'est le monument.
- On la **coiffe d'une couronne Art déco** : 5 gradins de plus en plus étroits, chacun bordé de **chevrons** en `Neon` **#ffd68c**, puis une **flèche** en acier **#c4ccd8** jusqu'à 260 studs environ.
- La façade : acier **#4a6a9a** et fenêtres jaune chaud **#ffb347** allumées (une `Neon` faible sur deux).
- Un **halo** chaud au sommet (une `PointLight` forte), pour la voir à travers la neige depuis Paris.
- Les `Backdrop/Tower_E1` à `E6` (15 à 31 pièces, 101 à 206 studs) l'encadrent : on les passe en acier et brique, avec quelques fenêtres allumées, plus sombres qu'elle.

## 3. Murs et façades (Studio, en pièces, par `zone6_newyork.luau`)

| Rôle | Couleur | Matière |
| --- | --- | --- |
| Brique des immeubles | **#8c3b2a** (et **#6b4a3a** grès brun en variante) | Plastic (tenons) |
| Gratte-ciel | **#4a6a9a** acier, **#969ca4** pierre | Plastic |
| Fenêtres allumées | **#ffb347** | `Neon` faible |
| Fenêtres éteintes | **#344050** | Glass (on garde) |
| Escaliers de secours | **#1e1e22** | Plastic |
| Neige sur les toits et les rebords | **#eef3f8** | Plastic |

- **Les 18 tours en boîtes** (`Skyline/Tower_N1` à `N7`, `Tower_S1` à `S7`, `Midrise_N`, `N2`, `S`, `S2`, de 7 à 32 pièces, 72 à 227 studs) : c'est le « AI slop » de la zone. Elles reçoivent :
  - des **retraits Art déco** en haut (2 ou 3 gradins) ;
  - une **grille de fenêtres** dont une sur trois est allumée, en jaune chaud ;
  - de la **neige** sur chaque gradin, le décor posé sur le haut des murs ;
  - une couleur parmi l'acier, la pierre, la brique et le grès.
  On varie les hauteurs (±20 studs) pour casser les silhouettes.
- **Les tours d'entrée** (`Buildings/GatewayTower_N` et `GatewayTower_S`, 39 à 43 pièces, 125 et 139 studs) : on les garde (voir 5).
- **Les immeubles** (`Buildings/Tenement_N`, `N2`, `S`, `S2`, `Tenement_End`, 35 à 69 pièces, bien faits) : on les garde et on ajoute des **escaliers de secours** noirs en zigzag sur leurs façades, des fenêtres allumées et de la neige sur les rebords.

## 4. Objets signature (3 ou 4, répétés en nombre)

| Objet | Combien | Où | Qui |
| --- | --- | --- | --- |
| **Taxis jaunes** (remplacent `Parking/Taxi_1`, `Taxi_2`, `Taxi_3`, 11 pièces, empilés au parking) | **5** : 3 au parking et 2 garés le long des trottoirs | jaune **#ffcc00**, damier noir et blanc, enseigne lumineuse sur le toit, de la neige sur le toit | **Blender, en voxel à tenons** (chef 3D) |
| **Cheminées de vapeur** rayées orange et blanc (on garde `Props/SteamStack`, 5 pièces, et la vapeur existante) | **5** | au milieu de la chaussée, sur les bouches d'égout, sans bloquer la course (1,5 stud de large) | **Studio** (chef Map) |
| **Chariots de hot-dogs**, avec leur parasol | 2 | sur les trottoirs, devant la Banque et la Salle des coffres | **Blender, en voxel** (chef 3D) |
| **Guirlandes lumineuses** de Noël au-dessus de la rue | 3 | de façade à façade, à 26 studs de haut minimum, ampoules **#ffd68c** et rouges **#ff463c** reliées par des `Beam` | **Studio** (chef Map) |
| **Lampadaires new-yorkais** à double bras (remplacent `Props/StreetLamp_N1` à `N4` et `S1` à `S4`, 5 pièces chacun) | 8 | tous les 20 studs | **Studio** (chef Map) |

- On garde le **kiosque à journaux** (`Props/NewsKiosk`, 16 pièces), l'**entrée de métro** (`Props/SubwayEntrance`, 15 pièces) et les **feux tricolores** (`Props/TrafficPole_N`, `TrafficPole_S`, 11 pièces).
- Les **poubelles** (`Props/TrashCan_1`, `TrashCan_2`, 2 pièces) : refaites en voxel avec le reste du chef 3D (poubelles grillagées), ou retirées. Les **bouches à incendie** (`Props/Hydrant_1` à `_3`, 6 pièces) : repeintes en rouge **#ff463c**, avec de la neige dessus.
- **Météo** : la neige existe (`Ambience_NewYork`) ; on la rend **plus épaisse**, avec des flocons plus gros et plus nombreux au loin, pour boucher un peu le fond. Elle reste au-dessus du couloir seulement, jamais dans les magasins ni sur le coffre. On garde la **vapeur** des bouches d'égout et les sons de la ville. Le budget téléphone reste sous 80 particules à l'écran.

## 5. Entrée de zone (Studio, en pièces)

- **On garde les deux grandes tours d'entrée** (`GatewayTower_N` et `S`, en x 732).
- Entre elles, on ajoute **une arche de pont suspendu** au-dessus de la chaussée : deux poutres en acier riveté **#4a6a9a**, à 30 studs de haut minimum, reliées par des câbles en `Beam` gris **#969ca4** qui descendent des tours, avec une rangée d'ampoules **#ffd68c**.
- La coupure de couleur au sol, la neige qui commence et le bandeau de zone (code, déjà là) marquent la frontière.

## 6. Décors répétés à remplacer ou à habiller (chemins sous `Workspace/Map/Zone_6/Street_NewYork/`)

| Chemin | Nombre | Pièces | Ce qu'on fait |
| --- | --- | --- | --- |
| `Skyline/Tower_*`, `Skyline/Midrise_*` | 18 | 7 à 32 | retraits Art déco, fenêtres allumées, neige, couleurs, hauteurs |
| `Backdrop/EndTower` | 1 | 40 | couronne Art déco, flèche, chevrons lumineux (le monument) |
| `Backdrop/Tower_E*` | 6 | 15 à 31 | acier et brique, quelques fenêtres allumées |
| `Parking/Taxi_*` | 3 | 11 | taxis voxel (×5) |
| `Props/StreetLamp_*` | 8 | 5 | lampadaires à double bras |
| `Props/TrashCan_*` | 2 | 2 | voxel ou retirées |
| `Props/Hydrant_*` | 3 | 6 | repeintes, neige dessus |

## 7. Qui fait quoi

- **Chef Map, dans Studio, en pièces, tout de suite** :
  - la gadoue, les traces de pneus, la neige tassée, les congères, les murets et la coupure de couleur de transition ;
  - les tours Art déco, les fenêtres allumées, les escaliers de secours et la neige sur les rebords ;
  - la tour du fond couronnée et l'arche du pont suspendu ;
  - les cheminées de vapeur, les guirlandes et les lampadaires ;
  - la neige plus épaisse ;
  - le tout dans `zone6_newyork.luau` et `zone6_ambience.luau`, relançables, sans toucher à l'emprise du coffre (`zone6_fortune_tower_relief.luau`), avec une sauvegarde dans `ServerStorage/MapBackups` avant de commencer et une ligne au journal de Studio.
- **Chef 3D, dans Blender, en voxel à tenons** : les taxis jaunes (5), les chariots de hot-dogs (2) et, si on les garde, les poubelles. Il montre un objet à Clément avant les autres.
- **Cantin** : le crépuscule d'hiver de la zone (`da-ambiances-zones-cantin.md` : ClockTime 16,6, Brightness 1,9, ColorShift_Top 255,190,160, Atmosphere Density 0,38, Haze 2,0). Il doit rester **plus clair que la vraie nuit**, qui garde la main quand elle tombe. En attendant, la zone doit déjà se lire « hiver » sous le ciel commun.
- **Règles** : aucun script dans les modèles ; les noms du contrat ne changent pas (`STORE_Z6_*`, `ShelfSlot_*`, `NPCStore`, `Zone`, `TruckSpawn`, `FortuneVaultSpawn`) ; pas de Play sans le jeton.
- **À montrer à Clément**, en vraie 3D, avant et après :
  - la sortie de Paris vers New York (changement de sol, arche du pont, tour au fond) ;
  - le milieu de la rue sous la neige ;
  - la tour du fond.
