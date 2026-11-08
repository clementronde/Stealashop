# Animations de l'UI : valeurs du prototype de l'arbre (2026-11-08)

Valeurs du prototype jouable `tools/clement/skilltree_proto.luau` (tableau `M`), **à valider par Clément** en le voyant dans Studio, puis à reporter par Ironix dans `Config/UiMotion`. Ce sont des V0 proposés, absents du doc. Les durées sont en secondes ; les échelles s'expriment en part de la taille posée par Clément (UIScale).

## Valables pour toute l'interface

| Moment | Valeur | Courbe | Remplace dans `UiMotion` |
| --- | --- | --- | --- |
| Écran qui s'ouvre : fond | fondu 0,25 | Quad Out | — |
| Écran qui s'ouvre : panneaux et boutons | glissent depuis le bord en 0,42 (départ 0,05 à 0,25 s) | Back Out | `Open` (aujourd'hui 0,9 → 1 en 0,25) |
| Écran qui se ferme | éléments à 0 en 0,14, cascade inverse de 0,012 ; fond en 0,25 | Quad In | `Close` |
| Bouton survolé | 1,05 en 0,12 (tuile : 1,07) | Quad Out | nouveau `Hover` |
| Bouton appuyé | 0,92 en 0,07 (tuile : 0,88, « s'enfonce ») | Quad Out | nouveau `Press` |
| Bouton relâché | retour à 1 (ou au survol) en 0,30 | Back Out | nouveau `Release` |
| Argent qui défile | 0,6 | Cubic Out | `Roll` (inchangé) |
| Compteur qui sursaute à chaque gain ou dépense | 1,15 → 1 en 0,30 | Back Out | nouveau `CashBump` |
| « +$350K » ou « −$250K » flottant | monte de 6 % de l'écran et s'efface en 0,9 | Quad Out | nouveau `FloatText` |
| Refus (pas assez d'argent) | secousse de ±6 px, 4 allers-retours en 0,30 | Quad | nouveau `Shake` |

## Propres à l'arbre de compétences

| Moment | Valeur | Courbe |
| --- | --- | --- |
| Ouverture « bop bop bop » | chaque tuile 0 → 1 en 0,38 ; 0,055 entre deux tuiles, de la tuile centrale vers les anneaux ; départ à 0,12 | Back Out |
| Halo de sélection | glisse vers la tuile choisie en 0,20 | Quad Out |
| Panneau de gauche qui change de tuile | 0,9 → 1 en 0,25 | Back Out |
| Achat : la tuile gonfle | 1 → 1,3 en 0,09 | Quad Out |
| Achat : la tuile revient | 1,3 → 1 en 0,60 | Elastic Out |
| Achat : éclat | copie blanche du corps, s'efface en 0,35 | Quad Out |
| Achat : étincelles | 12 losanges or et blancs, à 0,9 largeur de tuile (± 25 %), en 0,55 | Quad Out |
| Tuile voisine qui se découvre | après 0,30 : se retourne (1 → 0 en 0,10, Quad In), puis pop 0 → 1 en 0,45 (Back Out), étincelles et badge NEW! (1,6 s) | Back Out |

## Ce que le prototype montre (démo)

- L'argent monte de $350K toutes les 2,5 s, pour qu'on puisse continuer d'acheter.
- Acheter Glass Regen ouvre la tuile Safe ; monter Shop Level au niveau 2 ouvre la tuile Traps.
- Les tuiles sans valeur au doc (Door Guard, Potion Luck, Potion Time, Traps) affichent « — » et « Coming soon ».

Pour le code : tout passe par un `UIScale` sur l'élément animé et par des tweens. Aucun visuel de Clément ne change, sauf la visibilité des calques d'état (`Bought`, `Available`, `Locked`, `Info`), les textes et la position de `SelectionGlow`. L'éclat, les étincelles et le badge NEW! sont créés par le code, puis détruits.
