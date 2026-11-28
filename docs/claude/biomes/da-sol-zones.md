# Le sol des zones : flaques, trottoirs, passages piétons, neige, détails (Chef DA, 28/11)

Pour le chef Map, d'après le retour de Clément : « les flaques font un cercle plat, les rues piétonnes sont buggées, les passages piétons aussi. Il faut un effet de neige sur le sol et que le sol soit rempli. »

## 0. Ce qui fait « bug » aujourd'hui (relevé en lecture seule, place DEV, 28/11)

| Problème | Où | Cause mesurée |
| --- | --- | --- |
| Flaques en « cercle plat » | Z2, 28 flaques `Puddle_*` | Des disques `Cylinder` en **Glass**, Transparency 0,25 : une forme ronde parfaite, sans bord mouillé, et le verre transparent se trie mal avec le sol |
| Passages piétons qui clignotent | toutes les zones | Les bandes (`Zebra_*`, `Crosswalk_*`, `Crossing_*`, 0,04 d'épaisseur) ont **leur dessus à 0,04, à la même hauteur que les pointillés** (`CentreDash_*`, `LaneDash_*`, `EdgeLine_*`), là où ils se croisent : deux faces au même niveau qui se superposent, donc un clignotement |
| Rues piétonnes buggées | Z3, 45 `EntryPaving_*` | Des plaques de 0,05 posées **sur la chaussée**, qui se chevauchent entre elles et avec le passage piéton |
| Petites marches et joints | toutes les zones | Le dessus des trottoirs (`Pavement_*`) est tantôt à 0,48, tantôt à 0,45 (Z6 sud), et celui des bordures (`Kerb_*`) à 0,45 ou 0,48 (Z4 `Kerb_N3`, `S3`). Les étoiles de LA (`StarTile_*`) sont à 0,51 ou 0,54 |
| Trottoirs vides | Z2, Z3, Z4, Z5, Z6 | **Une seule dalle** de 112 à 188 × 12,8 par côté, sans joint ni détail. Seule la zone 1 a des dalles séparées |
| Neige restée à Paris | Z5 | 57 bandes de neige (`Hedge_*_Snow`, etc.), des trottoirs blancs (`Pavement_*` et `Boulevard_Sidewalk*` en #ecf2f8) |
| Aucune texture au sol | toutes les zones | Aucun objet `Texture` sur le sol : tout est en aplat |

## 1. Les règles communes (pour ne plus jamais avoir de « bug »)

1. **Les hauteurs** : chaussée à 0 ; **trottoir et bordure à 0,48 partout**, dans les 6 zones. La bordure fait 0,8 de large et pose sur le bord de la chaussée (|z| de 46,5 à 47,3), le trottoir va de 47,3 à 60. Dans le sens x, chaque pièce s'arrête **exactement** à la limite de la zone, sans chevauchement avec la voisine : même hauteur, donc ni marche ni joint qui clignote.
2. **Pas de deux faces au même niveau qui se superposent.** Toute couche plate posée sur une autre dépasse d'au moins **0,03 stud**, et son dessous **s'enfonce de 0,05** dans la pièce du dessous. Deux couches qui se croisent (bande et pointillé) ne sont jamais à la même hauteur : on coupe l'une des deux.
3. **Les détails passent par des `Texture`, pas par des pièces.** Une `Texture` sur la face du dessus (Top) ne coûte aucune pièce. Le plafond est de 4 500 pièces par zone, et les zones en ont aujourd'hui de 2 650 à 3 530.
4. **Pour casser la répétition**, deux `Texture` superposées sur la même face, avec des tailles de tuile premières entre elles (par exemple 37 et 23 studs), et un `OffsetStudsU`/`V` différent par zone.
5. **Les bonnes proportions** : `StudsPerTileU` = `StudsPerTileV` pour une image carrée, jamais étirée. Un `Decal` couvre toute sa face et s'étire : on le réserve aux petites pièces carrées (plaques d'égout). Les grandes surfaces prennent une `Texture`.
6. **L'échelle** : un perso fait 5 studs. Un pavé fait environ 1 stud, une dalle de 3 à 4 studs, et une dalle de béton à l'américaine 6 studs.
7. **Nos images à nous**, jamais une image d'un pack ni un rendu de générateur. Elles sont dessinées en pixels dans nos palettes (512 × 512, PNG transparent), avec un léger contour, puis publiées au nom du groupe, comme nos icônes. Liste des images à la section 6.

## 2. Flaques

- **La forme** : une **tache en pixels**, comme nos objets voxel, faite d'une grille de carrés de 0,5 stud.
  - Le contour est irrégulier, avec 3 ou 4 « lobes » ; les cases se touchent sans se superposer, et on les fusionne en bandes, rang par rang.
  - Taille : de 3 × 2 à 7 × 4 studs, jamais un rond.
- **L'eau** : SmoothPlastic **#2b3038**, `Reflectance` 0,35, Transparency 0 (plus de Glass). Le dessus est à **+0,03** au-dessus de la chaussée, et le dessous s'enfonce de 0,05.
- **L'auréole de sol mouillé** : un anneau de cases d'une case de large tout autour, à **+0,015**, dans la couleur de la chaussée × 0,75 (plus sombre), `Reflectance` 0,1. Une deuxième case par endroits, pour que le bord soit irrégulier.
- **Le reflet** : à Tokyo, l'auréole prend un reflet de néon, avec quelques cases en `Neon` rose #ff3ea5 ou cyan #18e0ff à Transparency 0,7, côté enseigne.
- **Les ronds de pluie** : le chef VFX les fait, avec un `ParticleEmitter` à plat au centre de chaque flaque, des anneaux qui s'élargissent. Ils n'existent que là où il pleut.
- **Où** :
  - **Londres** : 14 flaques, le long des bordures et près des passages ;
  - **Tokyo** : 8, avec les reflets de néon ;
  - **New York** : 6, de la **gadoue grise** (#6b6a66, `Reflectance` 0,15, bord de neige sale #c9cbc8) ;
  - **Paris** : 3 petites, avec 2 ou 3 feuilles posées dessus ;
  - **zone 1** : 4 **taches mouillées** sans eau (l'auréole seule), au pied des arroseurs ;
  - **Los Angeles** : aucune, la zone est sèche.

## 3. Trottoirs, bordures et rues piétonnes

- Hauteurs et emprise : voir la règle 1. Les `Pavement_*` et `Kerb_*` de chaque zone sont refaits à 0,48, sans chevauchement.
- **Les dalles** : on garde une seule grande pièce par côté (c'est économique), et ses joints sont dessinés par une `Texture` `Sol_Joints` (des lignes de joints sur fond transparent), teintée par `Color3`.

| Zone | Trottoir (couleur) | Dalle (`StudsPerTile`) | Bordure |
| --- | --- | --- | --- |
| Z1 | béton clair #d9d2c3, joints #b9b2a3 | 4 × 4 | béton #f6f6f2 |
| Z2 | pierre #6e6a64, joints #4e4b47 | 4 × 3, en rangs décalés | granit #8a8f96 |
| Z3 | encre #2a2440, joints #1c1830 | 2 × 2 | encre #3a3358, liseré néon (fiche Tokyo) |
| Z4 | sable #e9c48a, joints #c9a46a | 6 × 6 | terracotta #d9733f |
| Z5 | calcaire #d8cfbf, joints #b8af9f | 3 × 3 | granit #7d7a75 |
| Z6 | béton #bab8b2 sous la neige (section 5) | 5 × 5 | #8c8c90 |

- **Les rues piétonnes et les parvis** (les 45 `EntryPaving_*` de Tokyo, les `Boulevard_Sidewalk*` de Paris) : plus de plaques fines posées sur la chaussée.
  - Un parvis devant un magasin **fait partie du trottoir** : même pièce, même hauteur de 0,48. Il se distingue seulement par une deuxième `Texture` de dalles plus grandes, ou par une couleur.
  - S'il doit être sur la chaussée, c'est une `Texture` sur la face Top de la chaussée, jamais une pièce.
- **La jonction entre deux zones** : la coupure de couleur nette au sol (décision prise à Tokyo) se fait sur une **ligne de joint**, en x exact, entre deux pièces qui se touchent sans se superposer. Elle est soulignée par une bande de 0,4 stud plus foncée, en `Texture` ou dans la couleur de la bordure, pour qu'on lise une frontière et pas une erreur.

## 4. Passages piétons (le même modèle partout)

- **La géométrie**, identique dans les 6 zones :
  - des bandes de **9 × 1,8 studs** (9 dans le sens de la rue), espacées de 1,8 ;
  - **25 bandes** sur la largeur de la chaussée ;
  - la première et la dernière à 0,6 stud de la bordure, jamais coupées par la bordure.
- **La hauteur** : le dessus à **+0,03**, le dessous enfoncé de 0,05 dans la chaussée. Pièces `CanCollide` false et `CastShadow` false.
- **Les pointillés et les lignes s'arrêtent** à 1 stud avant le passage et reprennent 1 stud après. Ils ne passent plus jamais dessous : c'est ce qui clignotait. Les pointillés sont à **+0,02**, plus bas que les bandes.
- **La couleur** : blanc **#f2f0ea** partout. Seuls la neige de New York (section 5) et le zigzag jaune avant les passages de Londres changent.
- **L'usure** : une `Texture` `Sol_Usure` sur la face Top de chaque bande (des manques irréguliers, de la couleur de la chaussée, sur fond transparent). Elle ne coûte rien, et on change l'`OffsetStudsU` d'une bande à l'autre pour que l'usure ne se répète pas.
- **Le nombre** : un passage par zone, à l'entrée, comme aujourd'hui (25 pièces). Il est fait par une **seule fonction** commune aux 6 scripts de zone.

## 5. La neige au sol, à New York (et plus du tout à Paris)

- **La matière** : le matériau **Snow** de Roblox, déjà essayé sur `SidewalkDrift_*` et `Sidewalk_*`, couleur **#eef3f8**. Il a son propre grain et ne demande aucune image. Pas de SmoothPlastic blanc, qui fait « plâtre ».
- **Une couche continue** sur chaque trottoir : une pièce Snow par côté, de la bordure à la façade, sur toute la zone, avec le dessus à **0,62** (0,14 au-dessus du trottoir) et le dessous enfoncé dans le trottoir. Elle remplace les bandes `Sidewalk_N1`, `N2`, `S1`, `S2` et `SidewalkDrift_*`, qui se chevauchent à des hauteurs différentes (0,50, 0,51, 0,55).
- **Les congères**, contre les murets, les façades et les poteaux : **2 ou 3 marches** de neige empilées, à la façon voxel.
  - Les marches font 2,4, puis 1,6, puis 0,8 de large, et 0,3, 0,25, 0,2 de haut.
  - Elles sont plus épaisses dans les coins et devant les escaliers de secours.
  - Elles sont posées les unes sur les autres, sans se superposer de côté.
- **Le bord de la chaussée** : une bande de neige sale de 1 stud (Snow #c9cbc8) le long de la bordure, côté chaussée, à **+0,08**.
- **La gadoue de la chaussée** : la chaussée reste en Plastic **#5d6470**, avec deux `Texture` : `Sol_Gadoue` (des taches de neige fondue, 40 × 40) et `Sol_TracesPneus` (4 paires de traces dans le sens de la rue, 30 × 93). Il n'y a aucune pièce en plus.
- **Les rebords** : un chapeau de Snow de 0,3 sur les appuis de fenêtre, les auvents, les murets, les bouches à incendie et le toit des taxis.
- **Paris** : on retire toute la neige. Les 57 bandes de neige partent, et les `Pavement_*` et `Boulevard_Sidewalk*` passent en calcaire #d8cfbf (fiche de Paris). Le chef VFX vérifie qu'aucun émetteur de neige ne reste.

## 6. Un sol « rempli », zone par zone

**Images à faire** (une fois pour toutes, en pixels, nos palettes, PNG transparent, publiées au nom du groupe) :
- `Sol_Joints` : joints de dalles ;
- `Sol_Paves` : des pavés à joints sombres ;
- `Sol_Fissures` : des fissures fines et clairsemées ;
- `Sol_Taches` : des taches d'huile et de chewing-gum ;
- `Sol_TracesPneus` ;
- `Sol_Feuilles` : des feuilles éparses ;
- `Sol_Petales` : des pétales de cerisier épars ;
- `Sol_Gadoue` ;
- `Sol_Usure` : de la peinture usée.
Plus deux `Decal` carrés : `Sol_PlaqueEgout` (avec une variante décorée d'une fleur de cerisier pour Tokyo) et `Sol_Grille` (grille de caniveau).

| Zone | Chaussée | Trottoir | Pièces en plus (1 pièce chacune) |
| --- | --- | --- | --- |
| Z1 | `Sol_Fissures` (37) + `Sol_Taches` (23), pointillés jaunes | `Sol_Joints` 4 × 4 + `Sol_Taches` | 3 plaques d'égout, 4 grilles le long de la bordure, 4 taches mouillées (section 2) |
| Z2 | `Sol_Paves` (1 stud) + `Sol_Fissures` | `Sol_Joints` 4 × 3 + `Sol_Feuilles` rares, mouillées | 14 flaques, 6 grilles, 3 plaques ; le zigzag jaune avant le passage |
| Z3 | `Sol_Taches` + reflets de néon (fiche Tokyo, à **+0,02**, sans chevauchement) | `Sol_Joints` 2 × 2 + `Sol_Petales` | 8 flaques, 4 plaques décorées ; la bande podotactile jaune (`TactileStrip_*`, déjà là) |
| Z4 | `Sol_TracesPneus` + `Sol_Fissures` (fissures de chaleur) + `Sol_Taches` (huile) | `Sol_Joints` 6 × 6 ; les `StarTile_*` posées toutes à **0,51** (+0,03) | 4 grilles, 2 plaques ; des bandes de sable au pied des palmiers (fiche LA) |
| Z5 | `Sol_Paves` gris-beige à joints sombres (fiche Paris) | `Sol_Joints` 3 × 3 + `Sol_Feuilles` | 3 petites flaques, des grilles d'arbre autour des troncs (décor de fonte), 3 plaques ; les tas de feuilles (fiche Paris) |
| Z6 | `Sol_Gadoue` + `Sol_TracesPneus` | la neige (section 5) | 6 flaques de gadoue, 4 plaques d'égout (la vapeur est déjà là), les congères |

## 7. À contrôler avant d'envoyer la capture au Chef de projet

- **Pas de clignotement** : survoler le passage et une flaque en Edit, en approchant et en reculant la caméra, à hauteur de joueur et en vue haute.
- **Hauteurs** : un script qui relève le dessus de chaque `Pavement_*` et `Kerb_*` des 6 zones doit trouver 0,48 partout.
- **Pas de bande coupée** : les 25 bandes du passage sont entières, et aucun pointillé ne passe dessous.
- **Pas d'étirement** : chaque `Texture` a `StudsPerTileU` = `StudsPerTileV` (sauf les traces de pneus, longues par nature).
- **Le budget** : le nombre de pièces de la zone reste sous 4 500.
- **Paris** : il ne reste plus une seule pièce en Snow, ni aucun blanc #ecf2f8 au sol.
- **La capture** : avant et après, pour chaque zone, au même point de vue (la rue à hauteur de joueur et le passage piéton de près).
