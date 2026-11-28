# Fiche de construction : zone 3, Tokyo néon (zone pilote, validée par Clément le 28/11)

Pour le chef Map, puis le chef 3D. Planche : `StealAShop-Art/Captures/2026-11-28_biomes/Z3.jpg`. Lu dans la place DEV le 28/11, en lecture seule. Zone : x 230 à 368, chaussée |z| < 46,5, trottoirs |z| 47 à 93, façades à |z| = 60. Le joueur fait environ 5 studs.

Le biome tient à 4 choses, dans cet ordre (leçon du concurrent) : **le sol sur toute la largeur, le monument géant, les murs, puis 3 ou 4 décors répétés**. Le coucher de soleil rose-violet du ciel (clair, jamais la nuit) vient ensuite, par le code de Cantin (voir `da-ambiances-zones-cantin.md`). Sans lui, la zone doit déjà se reconnaître en plein jour.

## 1. Sol (Studio, en pièces, tout de suite)

| Pièce (Greybox/Corridor/Zone_3/Ground) | Aujourd'hui | Proposé |
| --- | --- | --- |
| `Street` (138 × 93) | Plastic #34304c | Plastic **#1c1830** (encre violette), tenons gardés ; `Reflectance` 0,12 pour l'aspect mouillé |
| `Side_N`, `Side_S` (trottoirs 138 × 46) | Plastic #dacec2 beige | Plastic **#2a2440**, avec un liseré `Neon` de 0,4 stud au bord du trottoir : **#18e0ff** côté nord, **#ff3ea5** côté sud |
| `SideWall_N1/N2/S1/S2` | SmoothPlastic #8099bb | Plastic **#12122a** laqué, chaperon de 0,6 stud en rouge **#b8322c** |
| Passages piétons et marquages | blanc | blanc **#f2eefc** (on garde la lecture de la course) |

- **Reflets de néon** au sol : de longues bandes plates (0,05 stud d'épaisseur) en `Neon`, `Transparency` 0,85, rose **#ff3ea5** et cyan **#18e0ff**, sous chaque grande enseigne. Elles imitent les reflets sur le bitume mouillé (Roblox ne reflète que le ciel). Une dizaine en tout.
- **Transition** : une coupure de couleur nette au sol à x = 230 (pas de marche : décision prise à Tokyo), coupure de couleur nette, sans dégradé. Depuis Londres, on doit voir le rose et le cyan au bout de la rue.

## 2. Monument : la grande pagode (Studio, en pièces à tenons)

- On part de la pagode existante, `Map/Zone_3/Street_Tokyo/Temple/Pagoda` (18 × 62 × 19, en x 241, z 76, juste après le torii, côté nord).
- **5 toits, environ 95 studs de haut** (le toit des magasins est à 52 : elle doit dépasser de 40 studs pour se voir depuis Londres), base de 26 × 26. Hauteur des étages décroissante (16, 14, 12, 10, 8), avec la flèche au sommet (`sorin`) en or **#d4a72c**.
- Couleurs : poteaux et balustrades rouge vermillon **#e8452c**, murs papier **#f6e7c8**, toits encre **#22203a**.
- **Les bords de chaque toit soulignés de `Neon` rose #ff3ea5**, plus une lanterne rouge **#e63946** à chaque coin (20 lanternes, chacune une `PointLight` de portée 10, couleur #ff7a7a). C'est ce qui la fait briller au crépuscule et la nuit.
- Emplacement : même place (x 241, z 76), ou un peu plus au fond (z 90) si elle gêne le trottoir. Elle doit se voir dans l'axe de la rue depuis l'entrée de Londres (x 118).

## 3. Murs et façades (Studio, en pièces, par `zone3_tokyo.luau`)

Les tons dominants d'aujourd'hui sont gris et bleus (SmoothPlastic #344664 ×83, #96928a ×70, #f5f5f0 ×57, #787874 ×39). On passe à :

| Rôle | Couleur | Matière |
| --- | --- | --- |
| Murs | **#22203a** encre | Plastic (tenons) |
| Bois, poutres, auvents | **#b8322c** rouge | Wood ou Plastic |
| Écrans de papier et fenêtres allumées | **#f6e7c8** | `Neon` faible ou SmoothPlastic clair |
| Enseignes | **#ff3ea5** rose, **#18e0ff** cyan, **#6b2bd9** violet | `Neon` |
| Accents | **#ffd23f** jaune | Plastic |

- **Les 8 tours en boîtes** (`City/Tower_N1, N2, N5, N6, S1, S2, S5, S6`, 26 pièces chacune) : on les garde, mais chacune reçoit des fenêtres en grille qui s'allument (une `Neon` #f6e7c8 sur trois) et une enseigne verticale en néon, avec un picto et sans mot (règle des enseignes, `da-enseignes-sans-slop.md`). On varie aussi leur hauteur (±15 studs) et la couleur du haut (rose, cyan ou violet), pour casser la répétition.
- `City/RadioTower` (88 studs) : elle passe en rouge et blanc, avec des feux `Neon` à chaque étage (elle sert de second repère).
- Les toits des magasins et des maisons portent le décor de la zone : antennes, panneaux d'enseigne, petits jardins de cerisiers (comme le concurrent pose le décor sur ses murs).

## 4. Objets signature (3 ou 4, répétés en nombre)

| Objet | Combien | Où | Qui |
| --- | --- | --- | --- |
| **Distributeurs lumineux** (remplacent `Props/Vending_N1, N2, S1, S2`, 5 pièces chacun) | 8, par groupes de 2 sur les trottoirs | faces avant éclairées (`Neon` #18e0ff, #ff3ea5), boutons et bouteilles visibles | **Blender, en voxel à tenons** (chef 3D, agent `createur-stud-voxel`), puis refaits en pièces par le convertisseur |
| **Guirlandes de lanternes de papier** au-dessus de la chaussée | 4 guirlandes, de façade à façade, à 24 studs de haut | lanternes rouges #e63946 et blanches #f6e7c8, reliées par des `Beam` | **Studio, en pièces** (chef Map) |
| **Poteaux électriques avec des câbles emmêlés** (remplacent `Props/Pole_N343, N360, S338, S360`, 5 pièces chacun) | 6 | transformateur gris, câbles en `Beam` noirs qui pendent d'un poteau à l'autre | **Studio, en pièces** (chef Map) |
| **Chat porte-bonheur géant**, une patte levée | 2, devant les deux magasins (Électronique, Jeux vidéo) | blanc, oreilles et collier rouges, pièce d'or | **Blender, en voxel** (chef 3D) |
| (option) Étal de ramen avec rideau et lanterne | 1, au milieu de la zone | — | **Blender, en voxel** (chef 3D) |

- Cerisiers (`Trees/Sakura*`, pack Yasu) : on les garde, mais le feuillage passe à un rose plus franc, **#ff8fc8** (`SurfaceAppearance.Color`, comme dans `trees_replace.luau`). C'est la couleur d'accent du feuillage.
- Pétales (déjà là, dans `zone3_tokyo_ambience.luau`) : on les garde. On ajoute une **brume violette au ras du sol** (ParticleEmitter, grandes particules très transparentes, #7a3fa8, environ 20 particules en tout) et une **poussière lumineuse** près des enseignes (petites étincelles rose et cyan). Le budget téléphone reste sous 70 particules à l'écran.

## 5. Entrée de zone (Studio, en pièces)

- Le torii existant (`Entrance/Torii`, 6 × 43 × 129, en x 241) : passer les piliers et la poutre en vermillon **#e8452c** avec la poutre du haut en encre **#22203a**, et souligner le dessous de la poutre de `Neon` rose.
- Juste derrière : une **allée de lanternes** (`Entrance/StreetLantern_*` et les `Nobori`, déjà là, en x 233 à 249) prolongée à 8 lanternes de chaque côté, avec des bannières `Nobori` rose et cyan.
- Le bandeau de zone (code, déjà là) et la coupure de couleur nette au sol (sans marche) marquent la frontière.

## 6. Décors répétés à remplacer ou à habiller (chemins sous `Workspace/Map/Zone_3/Street_Tokyo/`)

| Chemin | Nombre | Pièces | Ce qu'on fait |
| --- | --- | --- | --- |
| `Props/Vending_N1`, `Vending_N2`, `Vending_S1`, `Vending_S2` | 4 | 5 | remplacés par les distributeurs voxel |
| `Props/Pole_N343`, `Pole_N360`, `Pole_S338`, `Pole_S360` | 4 | 5 | remplacés par les poteaux avec câbles |
| `City/Tower_*` | 8 | 26 | habillés (fenêtres, enseignes, hauteurs variées) |
| `Houses/House` | 4 | 9 | toits et enseignes ajoutés, couleurs de la palette |
| `Temple/Pagoda` | 1 | — | devient le monument (section 2) |
| `Temple/StoneLantern_*` | 6 | 8 | gardés (ils sont corrects) |

## 7. Qui fait quoi

- **Chef Map, dans Studio, en pièces, tout de suite** : sol, trottoirs, murets, reflets de néon, coupure de couleur de transition, façades et tours (couleurs, fenêtres, enseignes), pagode agrandie, torii et allée de lanternes, guirlandes, poteaux et câbles, brume et poussière lumineuse. Le tout dans `zone3_tokyo.luau` et `zone3_tokyo_ambience.luau`, relançables, avec une sauvegarde dans `ServerStorage/MapBackups` avant de commencer et une ligne au journal de Studio.
- **Chef 3D, dans Blender, en voxel à tenons** : distributeurs (8), chat porte-bonheur (2) et, en option, l'étal de ramen. On montre un objet à Clément avant les autres.
- **Cantin (liaison)** : le coucher de soleil clair de la zone (valeurs V1 dans `da-ambiances-zones-cantin.md` : ClockTime 17,0, Brightness 2,2). La zone pilote doit d'abord plaire sous le ciel commun ; le coucher de soleil s'ajoute ensuite, et il reste nettement plus clair que la vraie nuit.
- **Règles** : aucun script, sauf un `FX_` visuel dans le décor unique si un objet natif ne suffit pas (une enseigne qui clignote, comme le `FX_NeonFlicker` du KARAOKE). Les noms du contrat ne changent pas (`STORE_Z3_*`, `ShelfSlot_*`, `NPCStore`, `Zone`). Pas de Play sans le jeton.
- **À montrer à Clément** : trois vues en vraie 3D, avant et après. La rue depuis l'entrée de Londres (on doit voir la pagode et le rose au bout), l'entrée sous le torii et le milieu de la rue.
