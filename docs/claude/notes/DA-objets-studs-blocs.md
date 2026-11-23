# Objets exposés en studs et en blocs

Relevé du 2026-11-20 dans Studio (place DEV, en Play, lecture seule), agent `revue-modeles`, à la demande de Clément : revoir les objets exposés (`ITM_*`) dans un style en studs et en blocs, comme les nouveaux colis.

**Remplace**, pour les objets exposés, les règles de [DA-reference-colis.md](DA-reference-colis.md) (qui interdisait le Plastic à studs) et les verdicts des objets de [revue-modeles-2026-11-20.md](revue-modeles-2026-11-20.md). Rejoint le « mode studs » déjà écrit dans `.claude/agents/prompteur-3d.md` et le « décor en studs » de `docs/Partie-1-MVP.md`.

> **Correction de Clément (2026-11-20)** : les « nouveaux colis » sont le **`BOX_Shop_ExclusiveCrate`** (`ReplicatedStorage/Assets/UI`), fait avec Claude Design, et non le `Studded Egg Pack`. Le colis fait 4,5 × 4,2 × 3,4 studs, en 19 MeshPart :
> - le corps (`Body`) et les rabats (`Shell`) sont en Plastic + `Studs`, violet `#7B2CFF` / `#B13CFF` ;
> - le cadre (`FrameBody`, `Frame`), le médaillon et la serrure sont lisses, en or `#FFC21A` ;
> - 6 bandes de néon arc-en-ciel, une bande `Tint` en néon blanc, et des cristaux rose et cyan (transparence 0,1, reflet 0,15) ;
> - le contour vient de `OutlineHighlight`, en noir.
>
> La règle qui en sort : **studs sur les grandes faces, cadre lisse sur les bords**. Un exemple en deux versions est dans [exemple-studs/](exemple-studs/) : en Parts dans Studio, et en maillage via Claude Design. Le reste de cette fiche est à reprendre une fois les deux versions comparées.

## L'ancienne référence : le `Studded Egg Pack`

Les colis `BOX_*` de `ReplicatedStorage/Assets/Boxes` sont toujours lisses (MeshPart, Cardboard et SmoothPlastic, aucun stud). Le seul modèle en blocs à studs de ce genre est le dossier `Workspace/Studded Egg Pack` : c'est lui qui sert de référence ici. **À confirmer par Clément** : ce sont bien eux, les « nouveaux colis » ?

| Mesure | Valeur |
| --- | --- |
| Modèles | 8 œufs : Starter, Common, Uncommon, Rare, Epic, Legendary, Mythic, Angel |
| Taille | 3,54 × 4,50 × 3,54 studs (Angel : 4,80 × 6,99 × 4,87 avec ailes et auréole) |
| Construction | 27 Parts en blocs, sans MeshPart (Angel : 29) |
| Grille | Toutes les tailles sont des multiples de **0,32 stud** (4,5 ÷ 14) : tranches de 0,32 × 1,61, colonnes de 0,32 × 0,32, cœur de 1,61 × 4,18 × 1,61 |
| Forme | Un œuf en « voxels » : des tranches empilées en escalier qui dessinent la courbe |
| Matériau | Plastic + MaterialVariant **`Studs`** (ColorMap seule, 1 tuile par stud), sur toutes les pièces |
| Couleurs | **Une seule couleur par œuf** : Common `#CC8E69`, Uncommon `#4B974B`, Rare `#0989CF`, Epic `#FF66CC`, Legendary `#FFB000`, Mythic `#FF5959`, Starter `#F8F8F8` |
| Rareté haute | Angel : corps gris clair `#CACBD1` + ailes `#A3A2A5` + auréole `#F5CD30` (2 pièces ajoutées, aussi en `Studs`) |
| Contour, néon, lumière | Aucun |

Le même variant `Studs` est déjà posé sur les magasins (139 pièces sur la supérette Z1), le hub et les boutiques des joueurs : les objets en studs iraient avec le décor.

## Ce que donnent les objets aujourd'hui

Les 83 objets (`ReplicatedStorage/Assets/Items`) sont faits de la même façon :

- 2 à 10 **MeshPart** lisses venus de Blender, formes arrondies (cylindres, sphères, sculptures) ;
- SmoothPlastic surtout, avec Glass, Foil, Neon, Metal par endroits ;
- **0 pièce en `Studs`**, 0 bloc de Part.

Ils sont donc tous à refaire dans ce style : un MeshPart arrondi ne prend pas bien la texture à studs (elle suit les UV de Blender, pas la grille des studs), et la silhouette n'est pas en blocs.

## La DA en studs et en blocs, en règles chiffrées

### 1. Des blocs sur une grille

- L'objet est fait de **Parts en blocs** (pavés, et cylindres à 12 côtés au plus pour les formes rondes), construits dans Studio. Plus de MeshPart arrondi.
- Toutes les tailles et positions sont des **multiples d'un pas de grille**. Proposition : **0,125 stud** pour un objet de 1,5 à 2,5 studs de haut, soit 12 à 20 pas en hauteur (l'œuf en a 14).
- Une forme ronde (fruit, ballon, diamant, statue) se fait **en escalier** comme l'œuf : des tranches empilées, plus larges au milieu.
- Épaisseur minimale d'un bloc : **1 pas** (0,125 stud). Rien de plus fin : une chaîne, des lunettes ou une bague se font en blocs pleins grossis.
- **15 à 60 blocs** par objet (l'œuf en a 27). À 12 triangles le bloc, ça fait 180 à 720 triangles, loin du budget 10.2 (2 000).

### 2. Studs partout

- Toutes les pièces visibles en **Plastic + MaterialVariant `Studs`**.
- Exceptions : le **verre** reste en Glass (vitre de télé, diamant, vitrine), le **néon** reste en Neon (écran allumé, lueur), sans studs sur ces pièces.
- Plus de SmoothPlastic, de Foil ni de Metal : l'or devient du Plastic `Studs` jaune or, le métal du Plastic `Studs` gris.

### 3. Peu de couleurs, franches

- **2 à 4 couleurs** par objet (l'œuf en a 1, l'Angel 3).
- Une couleur principale qui dit l'objet (rouge de la canette, vert de la pastèque), 1 ou 2 couleurs de détail, et au plus une couleur claire ou foncée.
- L'or reste **`#FFC21A`** (clair `#FFD95A`, foncé `#8C5A14`), comme les colis.

### 4. La rareté se voit aux ajouts

Comme l'œuf Angel, la rareté se lit à ce qu'on **ajoute** au corps, pas à la matière :

| Rareté | Ajout |
| --- | --- |
| Commun, Peu commun | Rien : l'objet seul, en studs |
| Rare | Un socle en blocs à la couleur de la rareté (`#2F9BFF`) |
| Épique | Une pièce en Neon `#A855F7` (bande, écran, lueur) |
| Légendaire | Or `#FFC21A` en studs sur les pièces nobles + néon |
| Mythique | Ailes ou auréole en blocs, comme l'Angel |
| Secret | Ailes et auréole + néon arc-en-ciel |

Les lumières et particules restent posées par le code (`DisplayService`), comme aujourd'hui.

### 5. Contour

L'œuf n'a pas de contour noir. Les studs et les arêtes des blocs suffisent à détacher la forme. **À décider par Clément** : on garde des objets sans contour, comme l'œuf, ou on ajoute le contour noir des colis ?

## Points à tester avant de lancer la production

- **Taille des studs.** Le variant `Studs` met 1 stud par stud. Sur l'œuf (3,5 studs de large), on voit environ 3 studs par face. Sur un objet de 1,5 stud, on n'en verra qu'un ou deux, et ils paraîtront énormes. Il faudra sans doute un deuxième variant, par exemple `StudsSmall` avec une tuile de 0,25 stud (4 studs par stud). C'est un réglage dans `MaterialService`, que je n'ai pas fait (lecture seule).
- **Taille des objets en jeu.** L'objet grandit avec son poids (de × 0,46 à × 10, T-128). Les studs grandissent avec lui si on agrandit les pièces : à × 10, un stud ferait 2,5 studs. À vérifier sur un objet lourd.
- **Capture.** Aucune capture ici : Studio était en Play (la capture ne marche qu'en Edit). Il faut une capture d'un œuf et d'un premier objet refait avant de valider.

## Verdict des 83 objets dans ce style

Tous sont **à refaire**. Le classement dit l'effort, pas la qualité.

### Facile : déjà des pavés (38)

La forme est une boîte, une plaque ou un empilement de boîtes : on la reconstruit presque bloc pour bloc.

| Zone | Objets |
| --- | --- |
| Z1 | `BriqueDeLait`, `CanetteDeSoda`, `BoissonEnergisante`, `PaquetDeChips`, `Pasteque` |
| Z2 | `BoosterDeCartes`, `CarteHolographique`, `BusAImperiale`, `MaisonEnPainDEpices`, `TrainElectrique`, `VoitureTelecommandee`, `RobotJouet`, `Skateboard` |
| Z3 | `ConsoleADoubleEcran`, `ConsoleDeSalon`, `ConsolePortable`, `OrdinateurPortable`, `PcGamer`, `Smartphone`, `TeleGeante`, `TeleRetro`, `TelephoneAClapet`, `CarteGraphiqueEnOr` |
| Z4 | `CoffretDeMontres`, `Parfum`, `HorlogeDeParquet`, `PenduleDoree`, `Couronne` |
| Z5 | `LaJoconde`, `TableauDeMaitre`, `Sarcophage`, `ArmureDeChevalier` |
| Z6 | `LingotDOr`, `PyramideDeLingots`, `CoffreFortBlinde`, `CoffreDeDiamants`, `CleDuCoffreUltime`, `TroneEnOr` |

### Moyen : forme ronde à mettre en escalier (35)

Même méthode que l'œuf : des tranches empilées.

| Zone | Objets |
| --- | --- |
| Z1 | `Ananas`, `Banane`, `Brocoli`, `Carotte`, `Donut`, `EpiDeMais`, `HotDog`, `PotDeNouilles` |
| Z2 | `BallonDeFoot`, `BarbeAPapa`, `CanardEnPlastique`, `OursEnPeluche`, `PelucheGeante`, `Sucette`, `YoYo`, `FigurineHolographique` |
| Z3 | `CasqueVr`, `Ecouteurs`, `Manette`, `Souris` |
| Z4 | `Bague`, `BasketsDeCollection`, `DiamantBrut`, `MontreAGousset`, `MontreEnOr`, `OeufEnDiamant`, `Rubis` |
| Z5 | `VaseAncien`, `Meteorite`, `MasqueAncien`, `LustreEnCristal` |
| Z6 | `DiamantGeant`, `SacDeDiamants`, `SceptreRoyal` |
| Secret | `ChatPorteBonheurDore` |

### Difficile : sculpture ou objet fin (10)

Il faut beaucoup de blocs pour qu'on les reconnaisse, ou les grossir franchement.

`ITM_Z4_ChaineEnOr`, `ITM_Z4_CollierDePerles`, `ITM_Z4_LunettesDeStar`, `ITM_Z5_BusteEnMarbre`, `ITM_Z5_LePenseur`, `ITM_Z5_StatueDoree`, `ITM_Z5_TourEiffelEnBronze`, `ITM_Z6_AigleDeCristal`, `ITM_Z6_TaureauEnOr`, `ITM_Z6_StatueDeLaLiberte`.

## Lots à refaire

Dans l'ordre où les joueurs voient les objets : zone 1 d'abord.

- **Lot 0, essai (1 objet)** : `ITM_Z1_CanetteDeSoda`. Un cylindre en escalier, 3 couleurs. Sert à régler le pas de grille et la taille des studs avant le reste.
- **Lot 1, zone 1 en pavés et fruits simples (7)** : `BoissonEnergisante`, `BriqueDeLait`, `PaquetDeChips`, `Pasteque`, `HotDog`, `Donut`, `PotDeNouilles`.
- **Lot 2, fin de zone 1 (6)** : `Ananas`, `Banane`, `Brocoli`, `Carotte`, `EpiDeMais`, et le Secret `ChatPorteBonheurDore`.
- **Lots 3 et 4, zone 2 (8 + 8)** : d'abord les pavés (`BoosterDeCartes`, `CarteHolographique`, `BusAImperiale`, `MaisonEnPainDEpices`, `TrainElectrique`, `VoitureTelecommandee`, `RobotJouet`, `Skateboard`), puis les ronds.
- **Lots 5 à 10** : zones 3 à 6, un ou deux lots par zone, les pavés avant les ronds, les 10 sculptures en dernier.

## Phrase de style pour les prompts

> Objet de jeu Roblox en blocs et en studs, comme un œuf de Roblox en voxels : construit uniquement de pavés sur une grille de 0,125 stud, formes rondes en escalier, studs Roblox sur toutes les faces, 2 à 4 couleurs franches, verre et néon en pièces séparées sans studs, aucune forme lisse ni arrondie, lisible à 40 studs et en icône de 64 px.

## Questions pour Clément

1. Les « nouveaux colis » sont-ils bien le `Studded Egg Pack` ? Et les colis `BOX_*` passent-ils aussi en studs ?
2. Les objets se construisent-ils dans Studio en Parts (rapide, comme l'œuf), ou toujours dans Blender ?
3. Contour noir ou pas ?
4. On teste un variant `StudsSmall` (studs 4 fois plus petits) sur le lot 0 ?
