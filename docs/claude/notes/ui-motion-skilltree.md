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

## Étendues à tout le jeu (2026-11-10, validées par Clément sur l'inventaire et en Play)

Elles remplacent, pour les fenêtres et les boutons, les lignes « Écran qui s'ouvre », « Écran qui se ferme » et « Bouton » du tableau du dessus. Prototypes : `tools/clement/inventory_proto.luau`, `ui_feel_proto.luau`, `feel2_proto.luau` (Play) et `gain_proto.luau` (Edit).

| Moment | Valeur | Courbe | Nom proposé dans `UiMotion` |
| --- | --- | --- | --- |
| Fenêtre qui s'ouvre (tous les menus) | `Root` 0,55 → 1 en 0,14 | Back Out | `Open` |
| Contenu qui arrive après la fenêtre | chaque carte ou rangée 0 → 1 en 0,14 ; départ à 0,08 ; 0,035 entre deux, 14 au plus | Back Out | `OpenStagger` |
| Fenêtre qui se ferme | 1 → 0 en 0,09 | Quad In | `Close` |
| Changement d'onglet | sortie : cartes à 0 en 0,1, 0,03 entre deux ; entrée comme `OpenStagger` | Quad In, puis Back Out | `Swap` |
| Bouton survolé | × 1,06 en 0,08 ; calque `Shade` de transparence 1 → 0,78 ; son `UI_Hover` | Quad Out | `Hover` |
| Bouton appuyé | × 0,95 en 0,05 ; `Shade` 0,62 | Quad Out | `Press` |
| Bouton relâché | retour en 0,2 | Back Out | `Release` |
| Achat ou validation réussis | bouton × 1,22 → 1 en 0,28 ; `UI_Success` 0,12 s après le clic | Back Out | `Success` |
| Carte survolée | `Icon` × 1,12, −6°, décalée de (0,02 ; −0,03) en 0,1 ; `HoverOutline` visible ; retour en 0,12 | Back Out, puis Quad Out | `HoverCard` |
| Message en bas (`UI_Toast`) | 0,6 → 1 en 0,2 ; 2,4 s à l'écran ; s'efface en 0,25 ; 3 messages au plus | Back Out | `Toast` |
| **Gain au-dessus du joueur** (`BB_Gain`) | `Row` 0,4 → 1 en 0,16 ; monte de 2,2 studs en 1 ; s'efface à partir de 55 % ; décalage au hasard de ± 1 stud. Un seul modèle : le code règle son attribut `GainKind` (`Speed`, `Power` ou `Cash`), puis lit sur le modèle la couleur et l'icône du même nom (`SpeedColor` `4fd2ff`, `PowerColor` `ff7a3a`, `CashColor` `5cff4a` ; `SpeedIcon`, `PowerIcon`, `CashIcon`). Texte : « +2 Speed/s », « +5 Power », « +$1.2K ». **Plus petit depuis le 2026-11-11** (retour de Clément en Play) : `BB_Gain.Size` = {2,7 ; 42}, {0,72 ; 12}, soit 60 % d'avant. Au ramassage d'argent, c'est le seul retour visuel : « +$X » monte et s'efface, avec le son `Cash_Collect`. Un ramassage au plus par seconde environ, pour que deux textes ne se superposent pas (L-091) | Back Out, puis Quad Out | `FloatGain` |
| ~~Case qui vole vers l'argent~~ (`UI_HUD.CashFly.Template`) | **Retirée le 2026-11-11** (Clément : plus de case carrée). `CashFly.Template` est supprimé ; `CashFly.CounterPop` reste, mais n'est plus montré | — | ~~`CashFly`~~, ~~`CounterPop`~~ |
| Argent qui arrive au compteur | `CashRow` 1,15 → 1 en 0,3 (`CashBump`) ; l'argent défile (`Roll`) | Back Out | `CashBump` |
| Chrono du vol (`HeistTimer.Box`) | à chaque seconde : 1,12 → 1 en 0,25 et tic `UI_Click_Tick`. Sous 3 s, le chiffre (`HeistTimer.TextColor3`) passe en rouge `E8413C` (décision de Clément, 2026-11-11) | Back Out | `TimerTick` |
| RUN! (`UI_Chase.RunBanner`) | 0 → 1,18 en 0,18, puis 1 en 0,12 ; ensuite il bat (+5 %) avec les bords et penche de ± 1,5° | Back Out | `RunBanner` |
| Bords rouges de poursuite (`ScreenEdges.Left`, `ScreenEdges.Right`, `ScreenEdges.Bottom`, `Vignette.Edge`) | transparence de 0,1 à 0,6, 1,6 battement par seconde. **Jamais le cadre `ScreenEdges` lui-même** : c'est un conteneur plein écran, au fond gris transparent ; le faire battre pose un voile gris sur tout l'écran (vu en jeu le 2026-11-11) | sinus | `ChasePulse` |
| Vigile qui poursuit | `Assets/FX/FX_ChaseHighlight` (Highlight rouge, `AlwaysOnTop`) posé sur le vigile pendant la poursuite, retiré à la fin | — | — |
| Caméra pendant la poursuite | champ de vision + 6 en 0,3, retour en 0,4 | Quad Out | `ChaseFov` |
| Arrivée en zone safe | `UI_Escape.Flash` transparence 0,05 → 1 en 0,5 ; champ de vision + 12 en 0,08 puis retour en 0,45 ; bannière 0 → 1 en 0,35 | Quad Out, Back Out | `SafeFlash` |

## Propres à l'arbre de compétences

| Moment | Valeur | Courbe |
| --- | --- | --- |
| Ouverture « bop bop bop » | chaque tuile 0 → 1 en 0,38 ; 0,055 entre deux tuiles, de la tuile centrale vers les anneaux ; départ à 0,12 | Back Out |
| Contour de sélection | s'efface en 0,08, se pose sous la tuile choisie, puis apparaît (transparence d'origine, échelle 0,92 → 1) en 0,20 ; la tuile, elle, ne bouge pas | Quad Out |
| Panneau de gauche qui change de tuile | 0,9 → 1 en 0,25 | Back Out |
| Achat : la tuile gonfle | 1 → 1,3 en 0,09 | Quad Out |
| Achat : la tuile revient | 1,3 → 1 en 0,60 | Elastic Out |
| Achat : éclat | copie blanche du corps, s'efface en 0,35 | Quad Out |
| Achat : étincelles | 12 losanges or et blancs, à 0,9 largeur de tuile (± 25 %), en 0,55 | Quad Out |
| Tuile voisine qui se découvre | après 0,30 : se retourne (1 → 0 en 0,10, Quad In), puis pop 0 → 1 en 0,45 (Back Out), étincelles et badge NEW! (1,6 s) | Back Out |

## Navigation dans l'arbre (ajoutée le 2026-11-08)

| Geste | Valeur |
| --- | --- |
| Glisser (clic gauche ou un doigt) | l'arbre suit le pointeur 1 pour 1 ; un appui devient un glisser après 6 px (sinon c'est un clic sur la tuile) |
| Limite du glisser | on décale l'arbre de 55 % de sa taille (zoomée) au plus. Au-delà, il suit à 35 % (élastique) ; au relâché, il revient à la limite en 0,35 (Back Out) |
| Molette | ±12 % par cran, lissé en 0,14 (Quad Out). Le point sous le pointeur reste sous le pointeur |
| Pincement (deux doigts) | zoom = zoom de départ × écart des doigts / écart de départ, autour du milieu des doigts ; même lissage |
| Limites du zoom | de 0,75 à 1,8 |
| Zoom à l'ouverture | 1, ou plus sur petit écran pour que les tuiles fassent au moins 100 px (≈ 1,1 dans une petite fenêtre Studio, ≈ 1,5 sur téléphone) ; le déplacement repart de 0 |

Pour le code : le prototype pose une couche transparente (`NavLayer`, un TextButton plein écran) au-dessus de l'arbre et sous le panneau, l'argent et Close. Elle reçoit `InputBegan`, `InputChanged` (souris, molette, doigts) et `InputEnded`. Le clic est retrouvé par un test « point dans l'hexagone », sur la tuile la plus proche, et le survol aussi. Le zoom passe par un `UIScale` sur `Tree`, le glisser par le décalage (Offset) de `Tree.Position`. `UI_SkillTree` a `IgnoreGuiInset = true` : en jeu, ajouter `GuiService:GetGuiInset()` à `input.Position` avant de le comparer aux `AbsolutePosition`. En Edit (le prototype), il n'y a pas de barre du haut.

## Tailles retenues (2026-11-08, « tout est trop gros »)

- **Arbre** : 0,528 de la hauteur + 150 px (tuiles agrandies de 20 % à la demande de Clément), soit des tuiles de 166 px sur un PC 1080p, 106 px dans une fenêtre Studio de 594 px et 80 px sur un iPhone SE avant le zoom de départ (×1,25, donc 100 px). Dans une petite fenêtre, les tuiles « ??? » du bord passent sous l'aide et sous Close : on les atteint en glissant.
- **Panneau de gauche** : 10 % de la largeur + 120 px (312 × 400 sur PC, 186 × 239 sur iPhone SE). **Close** : 5 % + 90 px (186 × 66 sur PC, 123 × 44 sur iPhone SE). BUY fait au moins 44 px.
- **Contenu des tuiles** : niveau, icône, nom et prix tiennent dans le corps de l'hexagone, marge comprise, à toutes les tailles (vérifié de 1920 à 667 px de large). Les noms longs (« Concept Store ») passent sur deux lignes ou rétrécissent.

## Ce que le prototype montre (démo)

- L'argent monte de $350K toutes les 2,5 s, pour qu'on puisse continuer d'acheter.
- Acheter Glass Regen ouvre la tuile Safe ; monter Shop Level au niveau 2 ouvre la tuile Traps.
- Les tuiles sans valeur au doc (Door Guard, Potion Luck, Potion Time, Traps) affichent « — » et « Coming soon ».

Pour le code : tout passe par un `UIScale` sur l'élément animé et par des tweens. Aucun visuel de Clément ne change, sauf la visibilité des calques d'état (`Bought`, `Available`, `Locked`, `Info`), les textes et la position de `SelectionGlow`. L'éclat, les étincelles et le badge NEW! sont créés par le code, puis détruits.
