# Achat en base qui se construit petit à petit : étude d'une capture et version Steal a Shop

Demande de Cantin, le 23/11 : « reprends les animations que tu vois lorsqu'on achète des choses dans [notre] base. L'animation, elle se fait petit à petit, elle se fait progressivement, c'est super stylé […] et le sound design ».

- Source : `C:\Users\user\Videos\NVIDIA\Desktop\Desktop 2026.11.23 - 16.45.10.02.mp4`. Elle dure 79,4 s, en 2560 × 1440 à 60 images/s, son AAC 48 kHz stéréo.
- Images clés : `docs/references/Achat-Progressif-Base/` (liste en fin de fiche).
- Lié à la croissance de la boutique : DEV-020, MOD-015, liaison L-096, vague 55 « petit à petit », gabarit découpé L-190.

Règle : on reprend les **techniques** (ordre, durées, courbes, rythme des pièces et des sons). On ne reprend ni leur bâtiment, ni leur plaque à billets, ni leurs textes, ni leurs sons. Chez nous, on garde les pièces de Clément (`PLOT_Shop/Stage_j`, `DisplayStand_xx`), notre panneau `UpgradeSign` et nos sons de `Assets/Sounds`.

Méthode :
- les durées sont comptées image par image à 60 i/s (une image = 16,7 ms) ;
- les sons sont **déduits du spectre**, sans écoute (section 5) ;
- l'horloge imprimée sur les planches est **en avance d'une image** : 48,633 sur la planche correspond à 48,649 en vrai. Les durées et les écarts restent justes. Les débuts vérifiés à l'image exacte sont marqués « exact ».

---

## 0. En bref

1. Le joueur paie en marchant sur une plaque posée au sol, là où le morceau va pousser. Il n'y a ni clic, ni menu, ni confirmation.
2. À l'écran, **seul le chiffre d'argent change, d'un coup, en une image**. Pas de défilement, pas de couleur, pas de « −prix » flottant, pas de message.
3. 0,15 à 0,35 s après (0,5 s une fois), la plaque disparaît en une image et **le morceau acheté se construit pièce par pièce** : du bas vers le haut, du milieu vers les côtés.
4. Une pièce arrive en 2 à 4 images (33 à 67 ms). Elle naît plus petite et presque transparente, puis prend sa taille et sa couleur, sans rebond visible.
   - Une longue pièce s'allonge depuis son milieu.
   - Un montant monte depuis son pied.
   - Une vitre s'élargit depuis son centre (~130 ms).
5. Au plus fort, une pièce nouvelle toutes les 17 à 50 ms (20 à 60 par seconde). Un morceau entier dure de 0,1 s (présentoir) à 1,3 ou 1,4 s (façade, escalier).
6. Le son est un **chapelet de petits « pops » brillants** : 20 à 40 ms chacun, entre 0,8 et 2,5 kHz, 15 à 30 par seconde, collé à la construction. Sur l'escalier, il accélère et monte de 6 à 9 dB vers la fin. Au paiement, un ou deux clics secs.
7. Ni flash, ni secousse, ni particules : tout le plaisir vient du rythme des pièces et des pops. Contre-exemple chez eux : le toit arrive d'un coup, en une image, et ça se sent.
8. La plaque suivante réapparaît 0,7 à 0,8 s après la dernière pièce. On enchaîne : un achat toutes les 4 s environ.

Chez nous aujourd'hui (code lu, rien modifié) : la boutique grandit au bon moment, mais tout arrive en une image (copie faite par le serveur), avec un seul son `Unlock`, et le panneau d'achat saute à sa nouvelle place. Il manque **un contrôleur client qui fait pousser les pièces nouvelles** avec ce rythme et ces sons (section 4.8).

---

## 1. Catalogue des moments

| Temps (s) | Où | Ce qu'on voit |
| --- | --- | --- |
| 0 – 12 | Dans la base, rez-de-chaussée | Le joueur passe entre les présentoirs. À **4,300 (exact)**, un présentoir payé se construit en ~0,1 s. |
| 12 – 47 | Devant l'entrée (14 – 26), de nouveau dedans (28 – 42), puis dehors | Petites baisses d'argent (~10 K) vers 14,3, 17,3, 19,8, 28,2, 35,2 et 40,2 : un paquet de billets au-dessus du joueur disparaît, sans construction visible. Mécanique non comprise. |
| 48,15 – 48,2 | Escalier, payé | 14,41 M → 14,4 M. |
| **48,649 (exact) – ~50,0** | Escalier extérieur | Les marches arrivent une à une, de bas en haut. Une pièce claire apparaît en haut vers 50,3 (dernière pièce ou plaque suivante, incertain). |
| avant 55,0 | Dalle de l'étage, payée | 14,4 M → 14,3 M (instant exact non mesuré). |
| **~55,77 – 56,20** | Dalle de l'étage | 5 à 6 dalles poussent depuis leur centre, celle du milieu d'abord (~0,45 s). |
| ~59,75 | Garde-corps, payé | 14,3 M → 14,2 M. |
| **~60,0 – 60,6** | Garde-corps vitré | Mêmes règles (~0,6 s). |
| ~64,25 | Mur vitré de côté, payé | 14,2 M → 14,08 M. |
| **~64,5 – 65,3** | Mur vitré de côté | ~0,8 s ; un portail suit vers 65,8. |
| ~68,45 | Partie gauche, payée | 14,08 M → 12,88 M. |
| **~68,6 – 69,0** | Partie gauche | ~0,4 s ; plaque suivante vers 69,8. |
| 71,80 – 71,82 | Façade avant, payée | 12,88 M → 11,68 M, en une image. |
| **72,15 – 73,48** | Façade avant | La mieux mesurée (section 4.5) : ~1,33 s. Plaque suivante vers 74,15 – 74,2. |
| 75,95 – 75,97 | Toit, payé | 11,68 M → 8,88 M, en une image. |
| **76,216 (exact)** | Toit | Tout le toit en une image, sans animation. |

Ces montants sont les leurs, notés pour retrouver les moments. Aucun n'est une valeur pour notre jeu.

---

## 2. Ce qui est interface et ce qui est 3D

| Couche | Chez eux |
| --- | --- |
| Interface (ScreenGui) | Seul le compteur d'argent bouge : saut direct en une image, sans défilement, sans couleur, sans grossissement. C'est vu image par image à 71,8 et 75,95 s, et à 10 i/s pour les autres achats. Le panneau du haut (gains hors ligne) ne change pas pendant les achats (vu de 67 à 77 s). Aucune notification. |
| 3D | La plaque d'achat au sol, la construction pièce par pièce et la plaque suivante. Tout le spectacle est dans le monde. |
| Son | Un clic au paiement, puis les pops pendant la construction (section 5). |

**Pourquoi ça marche** : le paiement est discret, donc l'œil part tout de suite vers le bâtiment. L'achat se « voit » dans le monde, pas dans un menu.

---

## 3. Le déclenchement : payer, puis laisser la place

### Chez eux
- **La plaque** : un carré plat au sol, au bord clair, rempli d'un dégradé vert, avec le prix écrit dessus (lu à l'envers depuis cette caméra). Un petit tas de billets 3D flotte au-dessus et bouge en boucle : les billets montent en colonne puis s'éparpillent, en 1 à 1,4 s environ (incertain).
- **Paiement** : le joueur marche dessus. On entend un clic sec, puis l'argent saute 40 à 60 ms plus tard (clic à 71,75, saut à 71,80 – 71,82 ; clic à 75,91, saut à 75,95 – 75,97).
- **Place nette** : environ 0,3 s après le saut, la plaque disparaît **en une image** (planche 72,117). La première pièce arrive l'image suivante (planche 72,133).
- **Délai paiement → première pièce** : 0,15 à 0,35 s pour 5 achats sur 6 (escalier : 0,45 à 0,5 s). Ce délai contient sans doute l'aller-retour réseau.
- **Plaque suivante** : elle revient 0,7 à 0,8 s après la dernière pièce (vers 69,8 et 74,15 – 74,2), là où poussera le morceau suivant.

Images : `03_plaque_achat_60ips.jpg`, `04_plaque_suivante_7400.jpg`, `05_argent_debits.jpg`, `06_argent_60ips_debits_7170_7582.jpg`.

### Pourquoi ça marche
- Zéro friction : on marche, on paie.
- Le prix est posé à l'endroit exact où le morceau va naître : on sait ce qu'on achète.
- La plaque qui s'efface « laisse la place » au chantier. Celle qui revient 0,7 s après relance l'envie d'acheter.

### Chez nous
- On garde notre `UpgradeSign` : panneau planté, `BuyButton`, posé par `UpgradeController` sur `StageUpgradePoint_n` ou `DisplayUpgradePoint`. Pas besoin de plaque au sol.
- Ce qu'on reprend : **le panneau s'efface quand la construction commence, puis revient 0,7 s après la dernière pièce**, à sa nouvelle place, avec un pop. Aujourd'hui, `UpgradeController` le repose dès que son point bouge (`StageDepth`) : il saute pendant que la base apparaît.
- Pop du retour : mêmes valeurs que `UiMotion.Appear.Pop`. Échelle 0,55 → 1 en 0,38 s, `Enum.EasingStyle.Back`, `Enum.EasingDirection.Out`, appliquée au modèle par `Model:ScaleTo`, avec une valeur qui suit `TweenService:GetValue`. Le panneau est une copie locale du client (dossier local du Workspace) : on peut le cacher et le faire grossir sans rien répliquer.
- Délai : le nôtre vient tout seul (achat `BuyItem`, puis serveur, puis réplication, soit 0,1 à 0,3 s). Ne rien ajouter.
- Argent : on garde notre `UiMotion.Roll` (0,6 s, `Cubic`, `Out`) et `CashBump`. C'est plus riche que leur saut sec et ça ne vole pas la vedette au bâtiment (question 8).

---

## 4. La construction pièce par pièce (le cœur)

### 4.1 Les règles qu'on retrouve sur tous les morceaux

| Règle | Mesure |
| --- | --- |
| Ordre | Du bas vers le haut, puis du milieu vers les côtés (façade, dalle). Escalier : de la marche du bas à celle du haut. |
| Arrivée d'une pièce | 2 à 4 images (33 à 67 ms). Fantôme très transparent (~85 %) et plus petit, puis taille et opacité finales. Aucun dépassement visible à 60 i/s (un rebond plus court qu'une image passerait inaperçu). |
| Forme selon la pièce | Petit bloc : grossit en fondu. Longue pièce (lisse, barre) : s'allonge depuis son milieu (~70 ms). Montant : monte depuis son pied (50 à 70 ms). Grand panneau (vitre, dalle) : s'élargit depuis son centre (67 à 130 ms). |
| Décalage entre pièces | 17 à 50 ms au plus fort, soit 20 à 60 pièces par seconde (~33 ms au début de l'escalier). |
| Pauses | Façade : 0,45 s sans pièce neuve entre le bas (lisse, montants, vitres) et le haut (barre, lisse du haut). |
| Durée d'un morceau | 0,1 s (présentoir) ; 0,4 à 0,8 s (dalle, garde-corps, mur, partie gauche) ; 1,33 s (façade) ; ~1,4 s (escalier). |
| Joueur | Jamais bloqué : il marche pendant la construction. |
| Effets | Aucun flash, aucune particule, aucune secousse de caméra. |

### 4.2 Présentoir (4,300 exact)
- Le tas de billets disparaît. Le socle arrive d'abord, puis la colonne en fondu (à demi transparente sur une ou deux images), puis le plateau du haut.
- De 4,300 à 4,383, soit ~85 à 100 ms (5 à 6 images), sans rebond.
- Son : une petite montée de bips (section 5).
- Image `10_departs_presentoir_escalier_toit.jpg` (rangée du haut).

### 4.3 Escalier (48,649 exact → ~50,0)
- Chaque marche vient avec ses deux joues. Elle naît en fantôme plus petit (on voit le sol au travers), puis devient opaque et prend sa taille 2 à 3 images plus tard (~50 ms).
- Au début, une marche toutes les ~2 images (~33 ms), puis 20 à 25 par seconde. Du bas vers le haut.
- ~1,4 s en tout. Les dernières marches arrivent vers 49,7 – 50,0, en même temps que le pic des pops. Une pièce claire en haut vers 50,3 reste à identifier.
- Image `07_escalier_60ips.jpg`.

### 4.4 Dalle de l'étage (~55,77 → ~56,20)
- 5 à 6 dalles. Chacune pousse depuis son centre, de toute petite à pleine taille, en fondu, en ~67 à 100 ms.
- La dalle du milieu d'abord, puis les côtés, une toutes les 50 à 100 ms. ~0,45 s en tout.
- Image `08_sol_60ips.jpg`.

### 4.5 Façade avant : la plus fine
Temps de planche (ajouter ~17 ms pour l'heure vraie). Image `09_facade_60ips.jpg`.

| Étape | Planche (s) | Durée | Ce qui arrive |
| --- | --- | --- | --- |
| 0 | 72,117 | 1 image | La plaque disparaît. |
| 1 | 72,133 – 72,200 | ~70 ms | Lisse du bas : naît au milieu et s'allonge vers les deux bouts. |
| 2 | 72,217 – 72,300 | ~85 ms | Retours d'angle (forme en U). |
| 3 | 72,317 – 72,400 | ~85 ms | Montants qui montent depuis leur pied (50 à 70 ms chacun). |
| 4 | 72,417 – 72,550 | ~130 ms | Vitre du milieu : fantôme au centre, qui s'élargit de moins de la moitié à toute sa largeur en ralentissant. |
| 5 | 72,567 – 72,633 | ~70 ms | Vitres de côté. |
| Pause | 72,63 – 73,10 | ~0,45 s | Aucune pièce neuve (les pops continuent). |
| 6 | 73,100 – 73,200 | ~100 ms | Barre du milieu. |
| 7 | 73,233 – 73,400 | ~170 ms | Lisse du haut. |
| 8 | 73,467 | 1 image | Chapeaux des montants. |

Total : ~1,33 s, en deux vagues.

### 4.6 Garde-corps, mur de côté, partie gauche
Mêmes règles, mesurées moins finement (planches à 30 i/s) : ~0,6 s, ~0,8 s et ~0,4 s.

### 4.7 Toit (76,216 exact) : d'un coup
Tout le toit en une image, sans fondu ni ordre. Image `10_departs_presentoir_escalier_toit.jpg` (rangée du bas) et `04_plaque_suivante_7400.jpg` (dernière case).

### Pourquoi ça marche
- On voit ce qu'on a payé se fabriquer : le plaisir de l'achat dure 0,5 à 1,4 s au lieu d'un instant.
- Un ordre de chantier (du bas vers le haut, du milieu vers les bords) : c'est lisible, solide, ça a du poids.
- Des pièces très courtes mais décalées : l'œil lit une vague, pas cinquante animations.
- Chaque type de pièce arrive à sa façon : ça fait « construit », pas « tout grossit pareil ».
- Pas d'effet en trop : on regarde le bâtiment.
- Le toit montre l'inverse : arrivé d'un coup, il passe presque inaperçu (avis, pas une mesure).

### 4.8 Chez nous

**Ce qui se passe aujourd'hui** (lu dans `src/`, rien modifié) :
- Il n'y a pas de `ShopController`. L'achat passe par `UpgradeController` (client) : `BuyButton` envoie `BuyItem(Id)`, puis `ShopService` (serveur) monte l'attribut `DisplaySlotsLevel` du joueur.
- `RayonService` (serveur) calcule le niveau de la boutique et appelle `ShopStageService.Apply(plot, level, count)` (ligne 323). Il montre ensuite rayons et présentoirs (`Rayon_0k`, `DisplayStand_xx`, `DisplaySlot_xx`, `CollectPad_xx`) en rendant leurs `Transparency` et `CanCollide` d'origine : c'est instantané.
- `ShopStageService.Apply` (lignes 424 à 470) copie `ReplicatedStorage/Assets/Plots/PLOT_Shop/Stage_j` dans la boutique (sans script, couleur `AccentColor`), coupe la copie au fond, puis pose `StageLevel` et `StageDepth` sur la parcelle. **Quand le fond change, toutes les copies sont détruites et refaites.** Côté client, « nouvelle instance » ne veut donc pas dire « nouvelle pièce ».
- `UpgradeController` joue `Unlock` en 2D (`MarkerSounds`) quand `DisplaySlotsLevel` monte après sa demande (lignes 716 à 742). Il repose le panneau dès que `StageDepth` bouge.
- `Config/UiMotion` et `ShopFxController` ne touchent qu'à l'interface. `Config/ShopGrowth` règle la coupe (rangs, marges), aucune animation.
- Résultat : à chaque achat, on a l'effet de leur toit.

**Proposition** (le code est pour Ironix, le ressenti pour Clément) :

1. **Un contrôleur client** `ShopBuildController` et ses valeurs dans `Config/ShopBuild` (nouveaux fichiers, noms V0). Aucun écran nouveau, rien d'obligatoire côté serveur.
2. **Quand ça se déclenche** :
   - la parcelle d'un joueur présent passe à un fond plus loin (`StageDepth` ; absent veut dire boutique entière) ;
   - ou à un niveau plus haut (`StageLevel`) ;
   - ou son propriétaire gagne un présentoir (`DisplaySlotsLevel` + 1).

   Rien ne s'anime à l'arrivée en jeu, à l'attribution de la parcelle, au retour du streaming, à la renaissance ou à la libération : là, tout apparaît direct. Rien non plus si la caméra est loin (V0 : plus de 150 studs).
3. **Quelles pièces s'animent** :
   - celles d'un `Stage_j` avec j plus grand que l'ancien `StageLevel` ;
   - celles qui dépassent l'ancien `StageDepth` (avec le gabarit découpé de L-190, les pièces restent entières, rien n'est raccourci) ;
   - le nouveau `DisplayStand_xx` et son `CollectPad_xx`.

   Les pièces refaites à l'identique s'affichent tout de suite. Les pièces fines du fond qui avancent (mur du fond, parapet, caméras) arrivent en dernier avec la vague, comme si elles fermaient le chantier. Les faire glisser demanderait de retenir leur ancienne place.

   Pour éviter de voir la pièce finie pendant une image, le client la cache dès son arrivée (`DescendantAdded`, `LocalTransparencyModifier` = 1). Il ramasse les pièces pendant ~0,1 s, puis lance la vague.

   Autre façon de faire, plus simple côté client : le serveur marque lui-même les pièces neuves (attribut, nom V0 `BuildNew`). Au choix d'Ironix.
4. **Ordre** : par tranches de hauteur de 2 studs, du bas vers le haut. Dans une tranche, de la pièce la plus proche à la plus loin du panneau d'achat : ça pousse depuis l'endroit où le joueur a payé.
   - Un `Model` (présentoir, lampe, caméra) compte comme une seule pièce.
   - Sinon, chaque `BasePart` est une pièce.
5. **Arrivée d'une pièce** : tout en local, rien ne se réplique. Le type se déduit de la forme (`Size`).

| Type de pièce | Départ | Durée et courbe |
| --- | --- | --- |
| Petit bloc | taille × 0,5, `LocalTransparencyModifier` = 1 | taille `TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)` (dépasse de ~10 %), ou `Quad` `Out` sans rebond comme chez eux ; fondu 1 → 0 en 0,08 s `Quad` `Out` |
| Longue pièce (lisse, poutre : une dimension 3 fois plus grande que les autres) | longueur × 0,1, depuis son milieu | `TweenInfo.new(0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)` + même fondu |
| Montant (le plus long est vertical) | hauteur × 0, pied fixe (la `CFrame` descend de la moitié de ce qui manque) | `TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)` + même fondu |
| Panneau (vitre, dalle, mur : deux grandes dimensions, une fine) | les deux grandes × 0,4 depuis le centre, `LocalTransparencyModifier` = 0,85 | `TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)` ; fondu 0,85 → 0 en 0,12 s |
| Présentoir (`DisplayStand_xx`, un `Model`) | `PivotTo` 1,5 stud plus bas + fondu | `TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)` ; fondu 0,1 s |

6. **Rythme** :
   - 0,03 s entre deux pièces (~33 par seconde) ;
   - si la liste est longue, décalage = durée max ÷ nombre de pièces ;
   - durée max d'un morceau : 1,5 s ;
   - en option, une pause de 0,3 s entre le bas et le haut d'un mur, comme leur façade.
7. **Pourquoi plus lent que chez eux** : sur un téléphone à 30 i/s, une pièce de 50 ms dure une image et demie et « pope » sans animation. Avec 0,12 à 0,2 s par pièce, l'animation reste visible, et le décalage de 0,03 s garde la vague.
8. **Technique** :
   - une seule boucle `RunService.RenderStepped` fait avancer toutes les pièces avec `TweenService:GetValue(alpha, style, direction)`, plutôt qu'un `Tween` par pièce ;
   - plafond d'environ 150 pièces animées par achat ; au-delà, on regroupe par `Model` ;
   - `LocalTransparencyModifier` marche sur `BasePart`, `Decal` et `Texture` (précédent : `CarryController`, `CatchScene/Shot`) ;
   - lumières, `SurfaceGui`, `ParticleEmitter` et `Beam` d'une pièce s'allument à la fin de sa pousse (ils ne savent pas faire de fondu) ;
   - les collisions restent celles du serveur. La pièce est solide pendant ses 0,2 s de pousse, sans gêne réelle.
9. **Panneau d'achat** : caché pendant la construction, il revient 0,7 s après la dernière pièce (section 3).

---

## 5. Les sons (déduits du spectre, à écouter)

### Chez eux

| Moment | Temps (s) | Ce que montre le spectre | Écart avec l'image |
| --- | --- | --- | --- |
| Fond | Tout le long | Musique en lignes tenues vers 400 – 530 Hz. Pas du joueur toutes les ~200 ms, vers −45 dB dans la bande. | — |
| Paiement | 48,11 et 48,33 ; 59,51 et 59,61 ; 64,11 et 64,22 ; 68,38 et 68,49 ; 71,75 et 71,84 ; 75,81 et 75,91 | Clics secs très courts (~10 ms, sur tout le spectre), souvent par deux, à 0,09 – 0,2 s d'écart, jusqu'à 17 à 26 dB au-dessus du fond, chacun avec un petit bip vers 1,6 kHz. Pas de caisse enregistreuse. | Le saut du chiffre tombe entre les deux clics, ou 40 à 60 ms après le dernier (71,75 → 71,80 → 71,84 ; 75,91 → 75,95). |
| Présentoir | 4,31 – 4,60 | Petits bips serrés dont la hauteur monte d'environ 1,2 à 2,5 kHz en ~0,3 s. | Démarre 18 ms après le début du fondu (4,318 pour 4,300). |
| Construction | Pendant chaque morceau | Chapelet de pops. Chaque pop = une attaque sèche (trait vertical) + un petit corps de 20 à 40 ms entre 0,8 et 2,5 kHz, qui monte un peu. Vers −33 à −40 dBFS dans cette bande, 15 à 30 par seconde. | Façade : départ à 72,152, avec la première pièce. Escalier : départ à 48,70 – 48,77, soit 50 à 120 ms après la première marche. |
| Escalier, fin | 49,6 – 50,05 | Les écarts entre pops passent de 40 – 90 ms à 25 – 40 ms. Le niveau monte de 6 à 9 dB, puis le chapelet s'arrête net vers 50,05. | Accélération et crescendo sur les dernières marches. |
| Façade, pause | 72,63 – 73,10 | Les pops continuent pendant la pause de l'image. | Le son ne s'arrête pas quand l'image marque une pause. |
| Toit | ~76,0 – 76,3 | Souffle (bruit entre 2,4 et 5 kHz) qui grossit juste avant que le toit apparaisse. Pops non vérifiés. | Possible montée avant le toit (76,216) ; à écouter. |
| Fin d'un morceau ? | ~4,75 ; ~50,25 ; ~74,06 | Sons aigus tenus et faibles (2,75 et 3,55 kHz après le présentoir et l'escalier, ~3,7 kHz après la façade), −40 à −50 dBFS, qui durent plus d'une seconde. | 0,15 à 0,6 s après la dernière pièce. Peut-être une petite cloche de fin qui résonne, ou la plaque suivante. Origine incertaine. |
| Petits débits (~10 K) | 14,3 ; 17,3 ; … | Mêmes chapelets de pops. | Son générique d'achat ou de pose ? (hypothèse) |
| Après chaque morceau | 51,1 – 52,4 ; 56,7 – 57,6 ; 61,0 – 62,6 ; 65,0 – 67,2 ; 69,6 – 70,4 ; 73,18 – 74,0 ; 76,8 – 77,2 | Sons forts (jusqu'à −5 dB), mono, aux harmoniques serrées dont la hauteur ondule comme une voix. | **Très probablement la voix de la personne qui filme**, pas un son du jeu. |

La hauteur des pops qui monte au fil de l'escalier n'est **pas prouvée** : le centre de gravité du spectre ne bouge pas nettement, le spectre la suggère seulement à la fin.

**À écouter (Clément)** :
- 4,2 – 5,0 : présentoir ;
- 48,0 – 50,6 : paiement et escalier ;
- 59,5 – 60,8 : garde-corps ;
- 71,7 – 74,2 : façade ;
- 75,8 – 76,4 : toit.

Spectres : images `11` à `14`.

### Pourquoi ça marche
- Un pop par pièce, ou presque : l'oreille compte les pièces, et le cerveau lie le son à l'image.
- Accélération et crescendo : la tension monte jusqu'à la dernière pièce, puis tout s'arrête net.
- Paiement discret (un clic) : le son « fort » est réservé au bâtiment.
- Pops courts et aigus (0,8 à 2,5 kHz) : ils passent au-dessus de la musique (400 à 530 Hz) et des pas sans avoir besoin d'être forts.

### Chez nous
- Un pop par pièce, **plafonné à 25 par seconde** (au moins 40 ms entre deux) : au-delà, une pièce sur deux sonne. Sans plafond, ça fait une mitraillette.
- L'accélération vient seule du décalage entre pièces. Crescendo : `Volume` de × 1 à × 2 (+6 dB) du premier au dernier pop.
- Hauteur : `PlaybackSpeed` de 1,0 à ~1,3 au fil du morceau, comme nos tics d'ouverture de colis (`UI_Click` qui monte, L-224). Chez eux, ce n'est pas prouvé : c'est notre touche, à valider à l'oreille. Ajouter un petit hasard de ±3 % pour que deux pops de suite ne soient pas identiques.
- Son V0 : `UI_Click` ou `Bubble_Pop`, déjà dans `Assets/Sounds` (L-229). Le mieux serait un son à nous, fait pour ça (nom V0 `Build_Pop`, 20 à 40 ms, clair, sans grave), à ajouter au contrat si Clément le veut.
- Présentoir seul : une petite montée de 0,3 à 0,5 s.
- Fin : `Unlock` à la dernière pièce, comme un « fini ! » (ou au paiement comme aujourd'hui, question 5).
- Où on l'entend : en 2D (`SoundService`) chez le propriétaire. Chez les autres joueurs proches, en 3D sur la boutique et plus bas, ou rien (question 6).
- Aucun son repris d'eux.

---

## 6. Le rythme

- Un achat toutes les 4 s environ : 59,75 → 64,25 → 68,45 → 71,80 → 75,95, soit des écarts de 4,5, 4,2, 3,35 et 4,15 s.
- Un cycle :
  1. paiement : un retour (chiffre + clic) ;
  2. 0,15 à 0,35 s d'attente ;
  3. construction de 0,4 à 1,4 s, avec 20 à 60 pièces et 15 à 30 pops par seconde ;
  4. 0,7 s, puis la plaque suivante ;
  5. ~2 s de marche.
- Entre un cinquième et un tiers du temps de jeu est donc rempli d'un flux très dense de retours, l'œil et l'oreille ensemble. C'est ça, le « satisfaisant ».
- Chez nous aujourd'hui : un seul retour par achat (la base d'un coup + `Unlock`).

---

## 7. Ce qui fait « pro » chez eux, et ce qui fait « générique » chez nous

**Pro chez eux** :
- chaque type de pièce a sa façon d'arriver (s'allonge, monte, s'élargit, grossit) ;
- un ordre de chantier, pas un ordre au hasard ;
- des pièces très courtes (130 ms au plus) mais décalées, qui forment une vague ;
- un son tenu par l'image, qui accélère et finit net ;
- aucun effet gratuit ;
- l'achat suivant se présente tout de suite.

**Chez nous**, d'après le code. Aucune capture de notre jeu sur cette machine : le dossier `StealAShop-Art/References/UI/_Notre_jeu/2026-11-15_Revue_UI/` est absent.
- La partie neuve arrive en une image, comme leur toit.
- Un seul son pour tout.
- Le panneau saute à sa nouvelle place pendant que la base apparaît.

**Pièges qui feraient « généré » en le refaisant** :
- toutes les pièces qui grossissent pareil, avec le même rebond ;
- tout qui part en même temps ;
- un pop par pièce sans plafond ;
- le pop d'interface (`Appear.Pop`) collé tel quel sur des murs ;
- des étincelles ou un flash ajoutés « pour faire riche ».

---

## 8. Où brancher (lu sans rien modifier)

| Fichier | Rôle aujourd'hui | Ce qu'on y ferait |
| --- | --- | --- |
| `src/server/Services/RayonService.luau` | Calcule le niveau, appelle `ShopStageService.Apply` (ligne 323), montre les présentoirs (`showRayon`, ligne 143), instantané | Rien pour la V0 |
| `src/server/Services/ShopStageService.luau` | Copies `Stage_j`, coupe au fond, `StageLevel`, `StageDepth` (`Apply`, lignes 424 à 470) | Option : marquer les pièces neuves |
| `src/client/Controllers/UpgradeController.luau` | `BuyItem`, son `Unlock` (lignes 716 à 742), pose du panneau quand `StageDepth` bouge | Cacher le panneau pendant la construction, le reposer 0,7 s après, déplacer `Unlock` à la fin si Clément le veut |
| Nouveau : `src/client/Controllers/ShopBuildController.luau` | — | La vague de pièces et les pops |
| Nouveau : `src/shared/Config/ShopBuild.luau` | — | Les valeurs ci-dessous |

Valeurs V0 pour `Config/ShopBuild`. Ce sont des réglages d'effet, tirés des mesures et adaptés aux téléphones, pas des valeurs de jeu.

| Nom V0 | Valeur | D'où ça vient |
| --- | --- | --- |
| `Enabled` | `true` | — |
| `MaxDistance` | 150 studs | Pas d'animation pour une boutique lointaine |
| `CollectWindow` | 0,1 s | Ramasser les pièces arrivées par le réseau avant de lancer la vague |
| `Stagger` | 0,03 s | Eux : 17 à 50 ms |
| `MaxDuration` | 1,5 s | Eux : 0,4 à 1,4 s |
| `LayerHeight` | 2 studs | Du bas vers le haut |
| `LayerPause` | 0 (option 0,3 s) | Leur façade : 0,45 s |
| `FadeTime` | 0,08 s (panneaux 0,12 s) | Eux : 33 à 67 ms |
| Petit bloc | × 0,5 → 1, 0,12 s, `Back` `Out` | Eux : 33 à 67 ms, sans rebond visible |
| Longue pièce | × 0,1 → 1, 0,16 s, `Quint` `Out` | Eux : ~70 ms |
| Montant | × 0 → 1, 0,14 s, `Quad` `Out` | Eux : 50 à 70 ms |
| Panneau | × 0,4 → 1, 0,2 s, `Quad` `Out` | Eux : ~130 ms |
| Présentoir | −1,5 stud → 0, 0,25 s, `Back` `Out` | Eux : ~100 ms |
| `SignReturnDelay` | 0,7 s | Eux : 0,7 à 0,8 s |
| `SignPop` | 0,55 → 1, 0,38 s, `Back` `Out` | = `UiMotion.Appear.Pop` |
| `PopSound` | `UI_Click` (V0), puis `Build_Pop` si Clément le fait | — |
| `MaxPopsPerSecond` | 25 | Eux : 15 à 30 |
| `PitchFrom`, `PitchTo`, `PitchJitter` | 1,0 ; 1,3 ; 0,03 | Notre touche (non prouvé chez eux) |
| `VolumeFrom`, `VolumeTo` | × 1 ; × 2 | Eux : +6 à +9 dB |
| `EndSound` | `Unlock` | Déjà dans `Assets/Sounds` |

---

## 9. Questions pour Clément (à passer d'abord par Cantin)

1. Quelles pièces poussent une à une : tout ce qui est neuf, ou seulement les gros morceaux (sol, murs, vitres, toit, escaliers) ? Le toit aussi (chez eux, il arrive d'un coup) ?
2. Ordre : du panneau vers le nouveau fond, du bas vers le haut (proposé) ? Ou depuis la porte, ou depuis le joueur ?
3. Ton : sobre comme eux (fondu et croissance, sans rebond) ou avec un petit rebond (`Back`, ~10 %) ?
4. Durée max d'un morceau : 1,5 s (proposé) ? Une pause entre le bas et le haut d'un mur, comme leur façade ?
5. Son :
   - `UI_Click` ou `Bubble_Pop` en attendant, ou un son à nous (`Build_Pop`) ?
   - Une hauteur qui monte au fil de la construction ?
   - `Unlock` au paiement ou à la dernière pièce ?
6. Les autres joueurs voient-ils la construction ? L'entendent-ils (en 3D, plus bas) ?
7. Le panneau d'achat : caché pendant la construction, puis de retour avec un pop 0,7 s après ?
8. L'argent : on garde notre défilement de 0,6 s, ou un saut sec comme eux ?

---

## 10. Points incertains

- Les sons forts après chaque morceau : voix de la personne qui filme (probable) ou son du jeu ? À écouter.
- Un pop par pièce, ou un son de construction générique ? Les pops existent aussi aux petits débits, sans construction visible.
- La hauteur des pops qui monte : pas prouvée.
- Les sons aigus tenus après chaque morceau : cloche de fin, plaque suivante, ou autre chose ?
- La plaque :
  - prix lu à l'envers ;
  - billets en boucle (~1 à 1,4 s), incertain ;
  - le texte semble changer pendant qu'on est dessus : faut-il y rester un moment ?
- Les petits débits de ~10 K (14,3 à 40,2 s) : mécanique inconnue.
- La pièce claire en haut de l'escalier vers 50,3 : dernière pièce ou plaque suivante ?
- Le rebond : rien de visible à 60 i/s, mais un rebond de moins d'une image passerait inaperçu.
- Le débit de la dalle (avant 55,0) n'est pas daté à l'image près.
- Les planches ont une horloge en avance d'une image. C'est corrigé pour les débuts marqués « exact » et dans le catalogue.

---

## 11. Images clés (`docs/references/Achat-Progressif-Base/`)

| Fichier | Contenu |
| --- | --- |
| `01_vue_ensemble_2s.jpg` | Toute la vidéo, une image toutes les 2 s. |
| `02_avant_apres_4930_7245.jpg` | La base à 49,30 s (rez-de-chaussée, escalier en cours) et à 72,45 s (étage, façade en cours). |
| `03_plaque_achat_60ips.jpg` | La plaque à 60 i/s : le joueur dessus, la plaque qui disparaît (planche 72,117), la première pièce (72,133). |
| `04_plaque_suivante_7400.jpg` | 74,0 → 76,3 à 10 i/s : plaque suivante, billets en boucle, toit d'un coup. |
| `05_argent_debits.jpg` | Le compteur d'argent autour de six achats, à 10 i/s. |
| `06_argent_60ips_debits_7170_7582.jpg` | Le compteur image par image : saut sec à 71,8 et 75,95. |
| `07_escalier_60ips.jpg` | Les marches, 48,62 → 48,90 à 60 i/s. |
| `08_sol_60ips.jpg` | La dalle de l'étage, 55,70 → 56,18 à 60 i/s. |
| `09_facade_60ips.jpg` | La façade, 72,12 → 72,77 à 60 i/s. |
| `10_departs_presentoir_escalier_toit.jpg` | Débuts exacts : présentoir (4,300), escalier (48,649), toit (76,216). |
| `11_spectre_escalier.jpg` | Spectre de l'escalier, 500 – 4 500 Hz, fenêtre de 2 s qui commence vers 48,45 : pops dès 0,25 s, accélération de 1,15 à 1,6 s. |
| `12_spectre_facade.jpg` | Spectre de la façade, fenêtre qui commence vers 71,9 : pops de 0,25 à 1,2 s, voix probable de 1,28 à 2,1 s, son aigu tenu après 2,16 s. |
| `13_spectre_paiement.jpg` | Quatre paiements (fenêtres de 0,45 s à partir de 59,50, 64,10, 68,30 et 75,80) : clics secs. |
| `14_spectre_presentoir.jpg` | Spectre du présentoir, 500 – 4 500 Hz, fenêtre de 1 s qui commence vers 3,95 : bips qui montent de 0,36 à 0,65 s, sons tenus après 0,8 s. |

Rien n'a été modifié dans `src/`, dans `docs/` (hors cette fiche et ses images) ni dans Studio.
