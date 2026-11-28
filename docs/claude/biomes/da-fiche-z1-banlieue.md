# Fiche de construction : zone 1, banlieue d'été (6e et dernière zone)

Pour le chef Map, puis le chef 3D. Même méthode que les autres zones. Planche : `StealAShop-Art/Captures/2026-11-28_biomes/Z1.jpg`. Lu dans la place DEV le 28/11, en lecture seule.

- **Emprise** : x 30 à 118, soit 88 studs, la zone la plus courte. Chaussée |z| < 46,5, trottoirs |z| 47 à 93, façades à |z| = 60.
- **Magasins PNJ** : `STORE_Z1_Superette` au nord et `STORE_Z1_Kiosque` au sud, en x 34 à 114.
- **Voisins** : le hub, zone safe en herbe verte en damier, à l'ouest ; Londres, pavés sombres et pluie, à l'est.

**L'idée** : la première rue qu'on braque, douce et rassurante. Midi d'été, béton clair, pelouses tondues, palissades blanches, couleurs de bonbon.

**Pour ne pas ressembler au hub**, qui est lui aussi vert :
- le hub est **une grande pelouse en damier** ; la zone 1 est **une rue de béton clair**, avec des bandes de pelouse seulement au pied des maisons ;
- la zone 1 porte **les palissades blanches et les toits de tuiles** ; le hub, lui, a ses boutiques de verre.

## 1. Sol (Studio, en pièces, tout de suite)

| Pièce (Greybox/Corridor/Zone_1/Ground) | Aujourd'hui | Proposé |
| --- | --- | --- |
| `Street` (88 × 93) | Plastic #3c465e (bleu marine) | Plastic **#6b6d72**, un bitume gris chaud ; pointillés centraux jaunes **#ffd23f** ; tenons gardés |
| `Side_N`, `Side_S` (trottoirs 88 × 46) | Plastic #6aba58 (vert) | Plastic **#d9d2c3** béton clair, en dalles (joints **#b9b2a3** tous les 4 studs), avec une **bande de pelouse** **#5fbf3f** de 6 studs côté façades |
| `SideWall_N1/N2/S1/S2` | SmoothPlastic #87aa8a | des **palissades blanches** **#f7f3e8** à piquets (voir 4), à la place des murets pleins |
| Passages piétons | blanc | blanc **#ffffff** |

- On garde la **ligne de départ** et la **ligne de sortie** (`Street_Zone1/Ground/StartLine`, 59 pièces, et `ExitLine`, 30 pièces), repeintes dans la palette.
- **Transition depuis le hub** : la ligne de la zone safe existe déjà (`SAFE ZONE`). On ajoute une coupure nette entre le damier vert du hub et le béton clair.
- **Transition vers Londres** : une coupure de couleur nette au sol à x 118 (pas de marche). Le béton clair s'arrête net sur les pavés sombres.

## 2. Monument : le château d'eau (Studio, en pièces à tenons)

- **Un château d'eau géant** derrière la rangée nord, en x 74 et z 235, derrière les commerces du quartier (`Neighborhood_Zone1/Buildings/Shop_N1_Bakery` à `Shop_N3_Cafe`, 22 à 28 studs).
- **Environ 75 studs de haut** :
  - 4 pieds en treillis blanc **#f7f3e8**, qui montent à 45 studs ;
  - une cuve ronde bleu ciel **#59c9f2**, de 22 studs de diamètre et 18 de haut, avec un toit conique rouge tuile **#e0623c** ;
  - un grand soleil peint sur la cuve, sans mots (règle des enseignes).
- Il dépasse les toits des magasins (42 studs) : on le voit dès la sortie du hub.
- Le soir et la nuit, une rangée d'ampoules **#ffd23f** souligne le bas de la cuve.

## 3. Murs et façades (Studio, en pièces)

| Rôle | Couleur | Matière |
| --- | --- | --- |
| Bardage des maisons (on alterne) | **#bee8d2** menthe, **#ffe296** beurre, **#ff78aa** rose, **#59c9f2** ciel, **#f7f3e8** blanc | Plastic (tenons) |
| Toits | **#e0623c** tuile | Plastic |
| Volets et portes | **#2e86de** bleu, **#348c40** vert, **#e8413c** rouge | Plastic |
| Encadrements et palissades | **#f7f3e8** | Plastic |
| Fenêtres | **#34425c** | Glass (on garde) |

- **Les 2 magasins PNJ** (`STORE_Z1_Superette`, `STORE_Z1_Kiosque`) : on ne touche pas à leur contrat (`Window`, `ShelfSlot_*`, `SignPart`…). On met seulement leurs façades dans la palette (bardage, auvent rayé, toit de tuiles).
- **Les commerces et maisons du quartier** (`Neighborhood_Zone1/Buildings/Shop_*` et `House_*`, 18 à 45 pièces, bien faits) : on les garde et on les met dans la palette, avec un toit de tuiles chacun. Les deux petites maisons (`House_N5`, `House_S5`, 18 pièces) reçoivent une véranda et une haie.
- Le décor posé sur le haut des murs : antennes, cheminées en brique, un panneau solaire, un drapeau.

## 4. Objets signature (3 ou 4, répétés en nombre)

| Objet | Combien | Où | Qui |
| --- | --- | --- | --- |
| **Palissades blanches à piquets** | tout le long des deux côtés, entre la pelouse et le trottoir, interrompues devant les portes | 1,2 stud de haut, `CanCollide` coupé | **Studio** (chef Map) : c'est l'élément répété de la zone |
| **Boîtes aux lettres** sur pied, de couleurs différentes | 6 | devant les maisons | **Blender, en voxel à tenons** (chef 3D) |
| **Camion de glaces** rose et blanc, avec son cornet géant sur le toit | 1 | garé dans un retrait du trottoir nord, sans gêner la chaussée | **Blender, en voxel** (chef 3D) |
| **Nains de jardin et flamants roses** | 4 et 4 | dans les pelouses | **Blender, en voxel** (chef 3D) |
| **Arroseurs** qui tournent | 4 | dans les pelouses | **Studio** (chef Map) : petite pièce grise et un `ParticleEmitter` d'eau en arc, environ 8 particules chacun |
| **Lampadaires de banlieue** (remplacent `Street_Zone1/Props/Lamp_S1`, `Lamp_N3`, `Lamp_N4`, 8 pièces) | 6 | tous les 16 studs | **Studio** (chef Map) |

- Les **grands arbres** du parc (`Neighborhood_Zone1/Parks/BigTree_1` à `_8`, 3 pièces, pack) : on les garde, feuillage vert vif **#5fbf3f**. On ajoute 4 petits arbres ronds dans les pelouses de la rue.
- La **fontaine** du parc (`Parks/Fountain`, 5 pièces), derrière les maisons, au nord : on la refait plus tard ; elle se voit peu.
- **Météo** : on garde le pollen, les abeilles et la fumée de pizzeria (`zone1_ambience.luau`), et on ajoute des **papillons** (une dizaine, jaunes et blancs) au-dessus des pelouses. Le budget téléphone reste sous 80 particules à l'écran, arroseurs compris.

## 5. Entrée de zone (Studio, en pièces)

- On garde les **colonnes et les mâts** de l'entrée (`Street_Zone1/Gate/Column_N1`, `Column_S1`, `FlagMast_N`, `FlagMast_S`, en x 33) et le **plan de la ville** (`Signs/TownMap`).
- Entre les deux colonnes, une **arche de haie taillée** au-dessus de la chaussée, à 24 studs de haut minimum : haie vert foncé **#3e8e3a** en blocs, avec des fleurs roses **#ff78aa** et jaunes **#ffd23f**.
- Le **panneau de bienvenue** (`Signs/WelcomeSign`, 6 pièces) devient un panneau en bois peint avec un grand soleil, sans mots (règle des enseignes, `da-enseignes-sans-slop.md`).
- Côté Londres, les colonnes `Column_N2` et `Column_S2` (x 115) restent ; l'arche de briques de Londres commence juste après.

## 6. Décors répétés à remplacer ou à habiller (chemins sous `Workspace/Map/Zone_1/`)

| Chemin | Nombre | Pièces | Ce qu'on fait |
| --- | --- | --- | --- |
| `Street_Zone1/Props/Lamp_*` | 3 (+3) | 8 | lampadaires de banlieue |
| Greybox `SideWall_*` | 4 | — | remplacés par les palissades blanches |
| `Street_Zone1/Signs/WelcomeSign` | 1 | 6 | panneau en bois peint |
| `Neighborhood_Zone1/Parks/Fountain` | 1 | 5 | plus tard (peu visible) |
| `Neighborhood_Zone1/Buildings/House_N5`, `House_S5` | 2 | 18 | véranda et haie |

## 7. Qui fait quoi

- **Chef Map, dans Studio, en pièces, tout de suite** :
  - le bitume gris chaud, le béton clair, les bandes de pelouse et la coupure avec le hub ;
  - les palissades blanches et les façades dans la palette ;
  - le château d'eau ;
  - l'arche de haie et le panneau de bienvenue ;
  - les lampadaires, les arroseurs, les petits arbres et les papillons ;
  - le tout dans `zone1_superette.luau` et `zone1_ambience.luau`, relançables (`zone1_ambience` se relance après `zone1_superette`), avec une sauvegarde dans `ServerStorage/MapBackups` avant de commencer et une ligne au journal de Studio.
- **Chef 3D, dans Blender, en voxel à tenons** : les boîtes aux lettres (6), le camion de glaces (1), les nains de jardin (4) et les flamants roses (4). Il montre un objet à Clément avant les autres.
- **Cantin** : le midi de la zone (`da-ambiances-zones-cantin.md` : ClockTime 12,5, Brightness 3,0, Atmosphere Haze 0,6). En attendant, la zone doit déjà se lire « été » sous le ciel commun.
- **Règles** : aucun script dans les modèles ; les noms du contrat ne changent pas (`STORE_Z1_*`, `ShelfSlot_*`, `NPCStore`, `Zone`, `TruckSpawn`). La zone 1 est celle du tutoriel (« Smash the Mini Mart window ») : la vitrine et la porte de la Supérette doivent rester bien visibles depuis la rue. Pas de Play sans le jeton.
- **À montrer à Clément**, en vraie 3D, avant et après :
  - la sortie du hub vers la zone 1 (coupure de sol et château d'eau au fond) ;
  - la rue avec les palissades et les pelouses ;
  - la sortie vers Londres (le contraste soleil contre pluie).
