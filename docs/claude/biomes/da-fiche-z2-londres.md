# Fiche de construction : zone 2, Londres sous la pluie (3e zone)

Pour le chef Map, puis le chef 3D. Même méthode que Tokyo et Los Angeles. Planche : `StealAShop-Art/Captures/2026-11-28_biomes/Z2.jpg`. Lu dans la place DEV le 28/11, en lecture seule.

- **Emprise** : x 118 à 230, chaussée |z| < 46,5, trottoirs |z| 47 à 93, façades à |z| = 60.
- **Magasins PNJ** : `STORE_Z2_MagasinDeJouets` au nord et `STORE_Z2_Confiserie` au sud, en x 128 à 210.
- **Voisins** : la zone 1, banlieue d'été claire et verte, à l'ouest ; Tokyo, encre et néons, à l'est.

**L'idée** : la seule zone grise et mouillée. Couleurs éteintes, brique et pierre sombres, d'où ressortent trois rouges (bus, cabines, boîtes aux lettres) et l'or des lampes à gaz. On passe du soleil de la zone 1 à la pluie : l'écart doit se sentir dès la frontière.

## 1. Sol (Studio, en pièces, tout de suite)

| Pièce (Greybox/Corridor/Zone_2/Ground) | Aujourd'hui | Proposé |
| --- | --- | --- |
| `Street` (112 × 93) | Plastic #545864 | Plastic **#3b3f48**, des pavés sombres ; `Reflectance` 0,15 pour l'aspect mouillé, tenons gardés |
| `Side_N`, `Side_S` (trottoirs 112 × 46) | Plastic #54565c | Plastic **#6e6a64**, des dalles de pierre, avec une bordure de granit de 0,6 stud **#8a8f96** |
| `SideWall_N1/N2/S1/S2` | SmoothPlastic #b8ae80 | Plastic **#8a3a2e** brique, chaperon de pierre de 0,6 stud **#c9c2b0**, petites grilles noires **#19191e** |
| Passages piétons | blanc | blanc cassé **#e8e6e0**, et des lignes jaunes en zigzag (**#f2c14e**) avant chaque passage, comme dans les rues anglaises |

- Les **flaques** existent déjà (`zone2_londres_ambiance.luau`) : on en met une dizaine de plus, plus grandes, en `Glass` sombre **#2b3038** avec `Reflectance` 0,3.
- **Transition** : une coupure de couleur nette au sol à x = 118 (pas de marche : décision prise à Tokyo) ; l'herbe et le béton clair de la zone 1 s'arrêtent net sur les pavés sombres. Depuis la zone 1, on doit voir la grande tour d'horloge et le brouillard au fond.

## 2. Monument : une seule grande tour d'horloge (Studio, en pièces à tenons)

- Aujourd'hui, **deux petites tours** (`Street_Londres/ClockTowers/ClockTower_N` et `ClockTower_S`, 49 pièces, 62 studs) encadrent l'entrée, en x 123. **On les garde à l'entrée** (voir 5) et on ajoute **une grande tour** au fond.
- **La grande tour** : environ 105 studs de haut, base de 18 × 18, derrière la rangée nord, en x 175 et z 215, derrière `Buildings/Mansion_3`, qui fait 55 studs. Elle doit se voir depuis la zone 1 au-dessus des toits.
- Pierre **#c9a86a** (couleur miel), cadrans blancs **#f5f5f0** à aiguilles noires sur les 4 faces, éclairés de l'intérieur (`Neon` #ffe8a8 faible), flèche gothique en ardoise **#5b6470** et pointe dorée **#d4af37**.
- Une `PointLight` chaude derrière chaque cadran : la tour doit se lire dans le brouillard.
- On garde la **grande roue** (`ObservationWheel`, 189 pièces, au sud) : elle sert de second repère, avec des lumières blanches sur ses nacelles.

## 3. Murs et façades (Studio, en pièces, par `zone2_londres.luau`)

| Rôle | Couleur | Matière |
| --- | --- | --- |
| Brique rouge | **#a4372d** | Plastic (tenons) |
| Brique jaune de Londres | **#c9a86a** | Plastic |
| Stuc blanc (maisons de maître) | **#ece6d7** | Plastic |
| Portes (on alterne) | **#1f4d3a** vert anglais, **#d62828** rouge, **#2e3a50** bleu nuit, **#f2c14e** jaune | Plastic |
| Toits et ardoise | **#5b6470** | Slate ou Plastic |
| Grilles et réverbères | **#19191e** | Plastic |

- **Les 16 maisons « Terrace »** (`Buildings/Terrace_NE1` à `NE4`, `NW1` à `NW4`, `SE1` à `SE4`, `SW1` à `SW4`, 6 à 9 pièces) : ce sont des boîtes toutes pareilles, le premier « AI slop » de la zone. Chacune reçoit :
  - une couleur de brique (rouge, jaune ou stuc blanc) et une porte de couleur ;
  - une fenêtre en baie au premier étage ;
  - des pots de cheminée sur le toit, le décor posé sur le haut des murs, comme chez le concurrent ;
  - une grille noire devant.
  Les hauteurs varient de ±4 studs.
- Les **5 maisons de maître** (`Buildings/Mansion_1` à `Mansion_5`, 35 à 45 pièces) : on les garde, on ajoute des cheminées et on passe le crépi en stuc **#ece6d7**.
- Les maisons `Houses/House_N3`, `House_S3` et `House_S4` (36 pièces) : on les garde et on les met dans la même palette.

## 4. Objets signature (3 ou 4, répétés en nombre)

| Objet | Combien | Où | Qui |
| --- | --- | --- | --- |
| **Lampadaires à gaz** (on garde `Props/Lamp_N1, N4, N5, S1, S4, S5`, 14 pièces, déjà corrects) | **10** | tous les 14 studs, des deux côtés : c'est l'élément répété de la zone | **Studio** (chef Map) : lanterne en `Neon` **#f2c14e** et une `PointLight` chaude (portée 14) dans chacune |
| **Boîtes aux lettres rouges en colonne** (remplacent `Props/PostBox`, 6 pièces) | 4 | sur les trottoirs, près des passages | **Blender, en voxel à tenons** (chef 3D) |
| **Taxi noir londonien** | 2 | garés le long du trottoir, sans gêner la chaussée | **Blender, en voxel** (chef 3D) |
| **Parapluies ouverts** de terrasse (noirs, rouges et vert anglais) | 6 | devant la Confiserie et le Magasin de jouets | **Blender, en voxel** (chef 3D) |
| **Abribus** (remplace `Props/BusStop`, 2 pièces) | 1 | x 213, z 58, là où il est | **Studio** (chef Map) : toit en verre, banc, panneau rouge |

- On garde les **2 cabines rouges** (`Props/PhoneBox_N` et `PhoneBox_S`, 37 pièces), le **bus à impériale** (`DoubleDecker`, 46 pièces) et les **guirlandes** (`Props/Bunting_N4` et `Bunting_S4`).
- Les arbres (`Buildings/Tree_*`, pack Yasu, ×10) : feuillage plus sombre et mouillé, **#3d6b45** (`SurfaceAppearance.Color`).
- **Météo** : la pluie existe déjà (`Weather`) ; on la rend plus franche, avec des gouttes plus longues et plus nombreuses au-dessus de la chaussée, sans jamais entrer dans les magasins. On ajoute un **brouillard bas** au ras du sol (ParticleEmitter, grandes particules gris-vert **#aab4b0** très transparentes, une vingtaine en tout). Le budget téléphone reste sous 80 particules à l'écran.

## 5. Entrée de zone (Studio, en pièces)

- Entre les deux petites tours d'horloge existantes (en x 123, z ±64), on ajoute **une arche de briques au-dessus de la chaussée**, à 26 studs de haut minimum, pour ne pas gêner la course : brique **#a4372d**, clé de voûte en pierre **#c9a86a**, 4 lanternes à gaz accrochées dessous.
- Juste derrière l'arche, le brouillard bas commence : on entre « dans » Londres.
- La coupure de couleur au sol et le bandeau de zone (code, déjà là) marquent la frontière.

## 6. Décors répétés à remplacer ou à habiller (chemins sous `Workspace/Map/Zone_2/Street_Londres/`)

| Chemin | Nombre | Pièces | Ce qu'on fait |
| --- | --- | --- | --- |
| `Buildings/Terrace_*` | 16 | 6 à 9 | couleurs, portes, baies, cheminées, grilles, hauteurs |
| `Buildings/Mansion_*` | 5 | 35 à 45 | cheminées, stuc |
| `Props/BusStop` | 1 | 2 | refait en abribus |
| `Props/PostBox` | 1 | 6 | remplacé par les boîtes aux lettres voxel (×4) |
| `Props/Lamp_*` | 6 (+4) | 14 | gardés, transformés en lampes à gaz qui brillent |
| `Buildings/Tree_*` | 10 | 2 | gardés, feuillage plus sombre |

## 7. Qui fait quoi

- **Chef Map, dans Studio, en pièces, tout de suite** :
  - le sol, les flaques, les lignes en zigzag et la coupure de couleur de transition ;
  - les murets en brique, les maisons et leurs couleurs ;
  - la grande tour d'horloge et l'arche d'entrée ;
  - les lampes à gaz, l'abribus, le brouillard bas et la pluie renforcée ;
  - le tout dans `zone2_londres.luau` et `zone2_londres_ambiance.luau`, relançables. Attention : ces deux scripts relisent la géométrie ; relancer `corridor_widen.luau` d'abord si besoin, comme le disent leurs en-têtes. Faire une sauvegarde dans `ServerStorage/MapBackups` avant de commencer, et ajouter une ligne au journal de Studio.
- **Chef 3D, dans Blender, en voxel à tenons** : les boîtes aux lettres (4), les taxis noirs (2) et les parapluies (6). Il montre un objet à Clément avant les autres.
- **Cantin** : le ciel couvert et la brume de la zone (`da-ambiances-zones-cantin.md` : ClockTime 15,8, Brightness 1,9, Saturation −0,15, Atmosphere Density 0,4, Haze 2,4 ; gris, mais jamais sombre comme la vraie nuit). En attendant, la zone doit déjà se lire grise et mouillée sous le ciel commun.
- **Règles** : aucun script dans les modèles ; les noms du contrat ne changent pas (`STORE_Z2_*`, `ShelfSlot_*`, `NPCStore`, `Zone`, `TruckSpawn`) ; pas de Play sans le jeton.
- **À montrer à Clément**, en vraie 3D, avant et après :
  - la sortie de la zone 1 vers Londres (changement de sol, arche, tour au fond) ;
  - le milieu de la rue sous la pluie ;
  - les maisons « Terrace » refaites.
