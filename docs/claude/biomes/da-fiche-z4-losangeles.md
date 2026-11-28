# Fiche de construction : zone 4, Los Angeles au couchant (2e zone, après Tokyo)

Pour le chef Map, puis le chef 3D. Même méthode que Tokyo (`da-fiche-tokyo-neon.md`), validée par Clément le 28/11 (« Oui, on continue »). Planche : `StealAShop-Art/Captures/2026-11-28_biomes/Z4.jpg`. Lu dans la place DEV le 28/11, en lecture seule.

- **Emprise** : x 368 à 530, chaussée |z| < 46,5, trottoirs |z| 47 à 93, façades à |z| = 60.
- **Magasins PNJ** : `STORE_Z4_Bijouterie` au nord et `STORE_Z4_Horlogerie` au sud, en x 402 à 482.
- **Voisins** : Tokyo à l'ouest, déjà posé (sol #1c1830, néons), et Paris à l'est.

**L'idée** : la seule zone chaude et dorée du couloir. On sort du violet de Tokyo pour entrer dans le sable et l'orange : l'écart doit sauter aux yeux dès la frontière.

## 1. Sol (Studio, en pièces, tout de suite)

| Pièce (Greybox/Corridor/Zone_4/Ground) | Aujourd'hui | Proposé |
| --- | --- | --- |
| `Street` (162 × 93) | Plastic #44384a | Plastic **#6a5a4f**, un bitume pâli par le soleil ; double ligne centrale jaune **#ffd23f**, tenons gardés |
| `Side_N`, `Side_S` (trottoirs 162 × 46) | SmoothPlastic #e0c8aa | Plastic **#e9c48a** sable, avec une bordure de trottoir de 0,6 stud en terracotta **#d9733f** |
| `SideWall_N1/N2/S1/S2` | SmoothPlastic #a387b8 (lilas) | Plastic **#f2b6a0** stuc saumon, chaperon de 0,6 stud en turquoise **#2a9d8f** |
| Passages piétons et marquages | blanc | blanc **#fff7e6** |

- Quelques **bandes de sable** (#f4d58d, 0,1 stud de relief) au pied des palmiers et des boutiques : le sol doit lire « plage et chaleur ».
- **Transition** : une coupure de couleur nette au sol à x = 368 (pas de marche : décision prise à Tokyo), et une coupure nette entre l'encre de Tokyo et le bitume pâle. Depuis Tokyo, on doit voir la lumière orange et les palmiers au bout de la rue.

## 2. Monument : les grandes lettres « HEIST » sur la colline (Studio, en pièces à tenons)

- **Une colline au fond, derrière la rangée sud**, en x 420 à 480 et z −200 à −240, derrière l'Horlogerie et le `SoundStage_S`. On la fait en pièces inclinées (`WedgePart`), sable olive **#c9a46a**, avec des buissons secs (#8a9a5b) et deux ou trois palmiers.
- **5 lettres blanches « H E I S T »** (**#f7f3e8**), refaites dans la police maison en blocs voxel (règle des enseignes) : 12 studs de large et 18 de haut chacune, posées sur des pieds, légèrement de biais. Le sommet est à environ 100 studs, au-dessus des toits (56) : elles doivent se lire depuis la sortie de Tokyo (x 368).
- Une rangée d'ampoules `Neon` **#ffcc48** souligne le bas des lettres, pour le couchant et la nuit.
- **Pour dégager la vue** : on retire les tours en boîtes du sud (`Skyline/Tower_S1`, `Tower_S2`, `Tower_S4`), qui sont dans l'axe. Les tours du nord restent (voir 3). On reprend l'idée du panneau « IT'S HEIST O'CLOCK » déjà dans la zone (`Billboards/Billboard_S`), qui reste.

## 3. Murs et façades (Studio, en pièces, par `zone4_losangeles.luau`)

| Rôle | Couleur | Matière |
| --- | --- | --- |
| Stuc des murs (on alterne) | **#ff8c42** orange, **#ff5d8f** rose, **#3bc9db** piscine, **#f4d58d** sable, **#f7f3e8** blanc | Plastic (tenons) |
| Toits de tuiles | **#c8553d** | Plastic |
| Auvents rayés | blanc et l'une des couleurs du stuc | Plastic |
| Enseignes | **#ff5d8f**, **#ffcc48**, **#3bc9db** | `Neon` |
| Vitrines | **#3e4a5c** | Glass (on garde) |

- **Les 10 boutiques identiques** (`Street_LosAngeles/Boutiques/Boutique_N1, N2, N5, N6, N7, S1, S2, S5, S6, S7`, 19 pièces chacune) : c'est le premier « AI slop » de la zone. On en fait **3 modèles** qu'on alterne, chacun avec sa couleur de stuc et son toit :
  - toit plat avec une grande enseigne `Neon` ;
  - toit de tuiles à l'espagnole ;
  - façade Art déco à gradins.
  Les hauteurs varient aussi (de 22 à 30 studs). Les 4 piliers de remplissage (`Boutique_Filler_NE, NW, SE, SW`, 3 pièces) deviennent des palmiers en pot ou des cabines de plage.
- **Les tours du nord** (`Skyline/Tower_N1`, `N2`, `N3`, de 14 à 21 pièces) : on les passe en pastel (rose, sable, piscine), avec des fenêtres orange qui reflètent le couchant (une `Neon` #ffb070 faible sur deux) et un toit plat avec une antenne.
- `District_LosAngeles/Buildings/Hotel_N` (62 studs) devient un **hôtel rose à néon**, avec une grande enseigne verticale en néon à étoiles, sans mot. `SoundStage_S` devient un studio blanc avec un grand chiffre peint. Les `Bungalow_S1` et `S2` prennent des toits de tuiles et une haie.

## 4. Objets signature (3 ou 4, répétés en nombre)

| Objet | Combien | Où | Qui |
| --- | --- | --- | --- |
| **Palmiers** (on garde `Palms/Palm_*` et les `Palm_B`, 16 pièces, déjà bien faits) | **+6**, pour en avoir une vingtaine | des deux côtés, réguliers tous les 16 studs : c'est l'élément répété de la zone | **Studio** (chef Map), copies des palmiers en place |
| **Planches de surf** debout contre les boutiques | 8 | 4 couleurs de la palette, motifs en bandes | **Blender, en voxel à tenons** (chef 3D) |
| **Cabriolet rose et turquoise**, garé | 2 | dans les retraits de trottoir, sans gêner la chaussée | **Blender, en voxel** (chef 3D) |
| **Food truck de tacos**, avec sa toile et son menu | 1 | devant la Bijouterie, en x 455 | **Blender, en voxel** (chef 3D) |
| **Lampadaires californiens** hauts et courbés (remplacent `Props/Lamp_N1, N3, N4, S1, S3, S4`, 5 pièces chacun) | 8 | tous les 20 studs | **Studio** (chef Map) |

- Les bouches à incendie (`Props/Hydrant_N1, N2, S1, S2`, 6 pièces) : on les repeint en jaune **#ffd23f** avec un chapeau rouge. On les garde, elles sont petites.
- Les panneaux `Props/StreetSign_N` et `StreetSign_S` (4 pièces) sont retirés (pas de faux noms de rue, règle des enseignes, `da-enseignes-sans-slop.md`).
- **Météo** : on garde l'air qui tremble (`FX_Z4_HeatHaze`), la poussière dorée (`FX_Z4_GoldenDust`) et les brins de palme qui tombent. On ajoute quelques **reflets dorés** au ras du sol, côté soleil couchant (une dizaine de particules). Le budget téléphone reste sous 60 particules à l'écran.

## 5. Entrée de zone (Studio, en pièces)

- **On garde l'enseigne à étoiles** (`Entrance/CrownSign`, `CrownStar_*`, `CrownPost_N`, `CrownPost_S`) et les **projecteurs** (`Entrance/Searchlight_N`, `Searchlight_S`) : ils sont déjà dans le thème « Hollywood ».
- On ajoute au-dessus une **flèche de motel en néon, sans mot** (orange #ff8c42 et rose #ff5d8f, ampoules jaunes #ffcc48) qui pointe vers la rue, sur les deux poteaux de l'enseigne.
- Le changement de sol (coupure de couleur nette, sans marche) et le bandeau de zone (code, déjà là) marquent la frontière avec Tokyo.

## 6. Décors répétés à remplacer ou à habiller (chemins sous `Workspace/Map/Zone_4/`)

| Chemin | Nombre | Pièces | Ce qu'on fait |
| --- | --- | --- | --- |
| `Street_LosAngeles/Boutiques/Boutique_*` | 10 | 19 | 3 modèles alternés (couleur, toit, hauteur) |
| `Street_LosAngeles/Boutiques/Boutique_Filler_*` | 4 | 3 | palmiers en pot ou cabines de plage |
| `Street_LosAngeles/Props/Lamp_*` | 6 (+2) | 5 | lampadaires californiens |
| `Street_LosAngeles/Props/Hydrant_*` | 4 | 6 | repeints, gardés |
| `Street_LosAngeles/Skyline/Tower_S1`, `S2`, `S4` | 3 | 10 à 17 | retirées (elles cachent les lettres) |
| `Street_LosAngeles/Skyline/Tower_N1`, `N2`, `N3` | 3 | 14 à 21 | habillées en pastel |
| `District_LosAngeles/Buildings/Bungalow_S1`, `S2` | 2 | — | toits de tuiles et haies |

## 7. Qui fait quoi

- **Chef Map, dans Studio, en pièces, tout de suite** :
  - le sol, les trottoirs, les murets, les bandes de sable et la coupure de couleur de transition ;
  - les façades et les 3 modèles de boutiques ;
  - les tours, l'hôtel et le studio ;
  - la colline et les lettres « HEIST » ;
  - les lampadaires, les palmiers en plus et la flèche de motel ;
  - le tout dans `zone4_losangeles.luau` et `zone4_ambience.luau`, relançables, avec une sauvegarde dans `ServerStorage/MapBackups` avant de commencer et une ligne au journal de Studio.
- **Chef 3D, dans Blender, en voxel à tenons** : les planches de surf (8), les cabriolets (2) et le food truck (1). Il montre un objet à Clément avant les autres.
- **Cantin** : le couchant de la zone (`da-ambiances-zones-cantin.md` : ClockTime 17,3, ColorShift_Top 255,170,100, Atmosphere Haze 1,8 ; toujours plus clair que la vraie nuit). En attendant, la zone doit déjà se lire chaude sous le ciel commun.
- **Règles** : aucun script dans les modèles ; les noms du contrat ne changent pas (`STORE_Z4_*`, `ShelfSlot_*`, `NPCStore`, `Zone`, `TruckSpawn`) ; pas de Play sans le jeton.
- **À montrer à Clément**, en vraie 3D, avant et après :
  - la sortie de Tokyo vers Los Angeles (on doit voir le changement de sol, les palmiers et les lettres) ;
  - le milieu de la rue ;
  - la colline et les lettres vues de la rue.
