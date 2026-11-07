# Boutique du joueur (MOD-015) et tapis et banc (MOD-016) : passation

Session « boutique du joueur », 2026-11-07, mode Edit seulement (pas de Play, pas de capture). Ni commit, ni push. La liaison et le doc n'ont pas été modifiés.

## Ce qui est livré

- **Gabarit** `ReplicatedStorage/Assets/Plots/PLOT_Shop` : 64 × 80 studs (x −32..32, z −40..40), pivot en bas au centre, avant vers −Z. Tags posés : `PlayerPlot` (boutique), `CashPad`, `Treadmill`, `Bench`. Pas de `PlotIndex` (posé à l'installation). Aucun script.
- **Script** `tools/clement/hub/plot_shop_builder.luau` (non commité) : `build()`, `install({ cframe, index, parent, stage, accent })`, `preview(copie, niveau)`, `check(modèle)`. Il s'envoie à `execute_luau` d'un bloc, ou en 5 morceaux (« Morceau 2 » à « Morceau 5 ») si le bloc est trop long. `install` pose une copie à la position voulue, avec `PlotIndex`, le numéro « SHOP n » sur l'enseigne, une couleur d'accent par numéro, et ne garde que les niveaux 1 à `stage` (1 par défaut).
- **Vérifié** (`check`, mêmes règles que `Contract/Models`) : contrat 10.4 complet, chaque nom une seule fois ; `WindowFractured` = copie de `WIN_M_Fractured` (36 éclats), alignée au stud près sur `Window` ; rideau caché dans le linteau, 7,8 de haut ; points tournés vers −Z ; `UsePoint` sur la surface où l'on se tient ; place du joueur libre au tapis et au banc ; apparition dégagée.
- **Triangles** : ~5 800 au niveau 1, ~20 400 au niveau 6 (budget 25 000). Tapis ~190, banc ~840 (budget 3 000).

## Où sont les choses (repère de la boutique)

- Porte à casser = `Window` (2 vantaux de 6 × 7, `Leaf_L` et `Leaf_R`) au centre de la façade, dans le portique `PlotDoor`. `NameSign`/`OwnerName` sur le linteau, `ShutterButton` à l'intérieur du montant droit.
- 20 présentoirs sur 4 îlots (x −21,5, −7,5, 7,5, 21,5 ; rangées z −20 à 8). Les 4 premiers sont au bord de l'allée centrale, puis ils s'éloignent dans l'ordre de déblocage.
- Établis `UnboxBench_01` à `_04` au fond à gauche, coffre `VaultSlot_01` à `_03` au fond au centre, caisse et `CashPad` devant à gauche, tapis (x 18) et banc (x 25,5) devant à droite.
- `TrapSlot_01` à `_04` derrière la porte, `SpawnPoint` en (0, 0,3, −27) tourné vers la rue, `StageUpgradePoint` sur une borne à droite de la porte. `DepositZone` = tout l'intérieur ; `Bounds` = toute l'emprise, 30 de haut.

## Niveaux

1. Stand ouvert : barrière basse chromée, champ de force léger au-dessus (matériau ForceField), tapis WELCOME.
2. Murets et rayons garnis : produits sous les présentoirs, têtes d'îlots, promo, haltères.
3. Murs pleins, vitrines de façade (décor, incassables), rayons muraux.
4. Toit, néons au plafond, enseigne lumineuse, rails du rideau, auvents.
5. Porte blindée (cadre d'acier, rivets, bandes de danger, clavier), 5 caméras (décor), alarme.
6. Façade marbre et or, cadre et porte ronde de coffre-fort, tapis rouge, lustres, palmiers.

`HideFromStage` : barrière basse 2, champ de force 3, murets des côtés 3, rails du rideau 5, néons de l'enseigne 6, cadre blindé 6, pilastres 6, tapis WELCOME 6.

## Noms proposés à Ironix (rien n'est encore au contrat)

- `Stage_1` à `Stage_6` (Models, enfants directs de la boutique, pivot = pivot de la boutique) : décor ajouté à chaque niveau, cumulatif. Aucun nom du contrat dedans.
- Attribut `HideFromStage` (nombre) : la pièce ou le groupe disparaît à partir de ce niveau.
- Règle conseillée côté code : le gabarit garde tout ; pour passer au niveau n, cloner les `Stage_k` (k ≤ n) du gabarit, les placer au pivot de la boutique (`PivotTo`) et retirer les pièces dont `HideFromStage` ≤ n.
- `PlotDoor` (Model de l'entrée) ; `Leaf_L` et `Leaf_R` dans `Window`, que le code fait coulisser pour le propriétaire, côté client.
- `PlotBarrier` (Model) : murs invisibles sur le pourtour (côtés, fond, avant hors porte, couvercle à 30 studs). Le code les rend franchissables pour le propriétaire seul ; les autres doivent casser `Window`. La casse marche déjà sans code nouveau : WindowService accepte une `Window` en Model.
- `StageUpgradePoint` (Attachment) : où flotte l'achat du niveau suivant.
- En option : `BeltTexture` (Texture du `Belt`, le code peut faire défiler `OffsetStudsV`) ; `Barbell` (Model de la barre du banc, que le code peut souder aux mains pendant `BenchLift`). `UpgradePoint` est posé dans le tapis et le banc (L-041).

## Points à trancher ou à savoir

- **Nombre de niveaux** : le doc (Partie 2, section 2) prévoit 5 niveaux de boutique (Stand, Boutique, Magasin, Concept store, Flagship) et 4 prix (10 K, 250 K, 6,25 M, 156 M $). Avec 6 niveaux, il faut un 5e prix, ou alors fusionner les niveaux 5 et 6.
- **Présentoirs** : les 20 sont là dès le niveau 1, car ils ont leur propre amélioration (7.5, de 4 à 20) ; le niveau 2 n'ajoute que du décor.
- **Pose dans la map** : retirer d'abord les 6 parcelles grises (`Greybox/Safe/Plots`), sinon les `PlotIndex` et les tags seront en double.
- **Pour le code** : un voleur encore dedans quand la porte se reconstruit (30 s) reste enfermé par `PlotBarrier` ; il faudra le sortir, par exemple à la reconstruction.
