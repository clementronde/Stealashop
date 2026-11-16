# Bulles multiplicatrices autour du tapis : analyse d'une vidéo de référence (2026-11-16)

Vidéo fournie par Cantin : `C:\Users\user\Videos\NVIDIA\Desktop\Desktop 2026.11.16 - 18.16.28.02.mp4` (11,5 s, 1920 × 1080, 120 i/s, un seul plan, caméra fixe, joueur sur un tapis de niveau 1 pendant toute la vidéo).
Images extraites, gardées dans le scratchpad, **pas durables** : `C:\Users\user\AppData\Local\Temp\claude\4da6080c406c1ed3\6c086951-47a0-4d5f-97f2-0fdce09c2163\scratchpad\video2\frames\`. Les noms cités plus bas renvoient à ce dossier.

Ce qu'on reprend : la **mécanique**, les durées, les courbes et le rythme. On ne reprend ni leurs dessins (curseur de souris, bulle violette, arc-en-ciel tel quel), ni leurs textes, ni leurs sons.

## En bref

- Des bulles cliquables apparaissent **dans le monde, autour du tapis**, pendant l'entraînement. Deux au plus à la fois.
- Un clic sur une bulle gratuite donne **tout de suite** « ×N un tic du tapis » : +14 pour ×2, +21 pour ×3, +32 pour ×4,5, avec un tic de +7. **Ce n'est pas un bonus qui dure** : le gain par seconde reste le même juste après (mesuré sur le compteur).
- Une bulle arc-en-ciel « ×20 » est **payante** : le clic ouvre l'achat d'un produit Robux (« 20x Entraînement », 9 R$). Elle disparaît seule au bout d'environ 6 s.
- Cantin pensait plutôt à « ×2 pendant un moment, 2/s devient 4/s ». Ce n'est pas ce que fait leur jeu. À trancher par Clément (question 1).

## 1. Catalogue des moments

Temps mesurés image par image (planches à 10 i/s `z10_01` à `z10_04`, puis 30 i/s autour de chaque événement).

| Temps | Ce qui se passe |
| --- | --- |
| 0,0 | Deux bulles violettes « ×2 » déjà là : une au-dessus de l'avant du tapis, une à l'arrière |
| 0,6 | Clic sur la bulle du haut : « +14 Vitesse » apparaît à sa place, la bulle éclate |
| 1,7 | Clic sur la seconde bulle ×2 : « +14 Vitesse » |
| 2,7 | Nouvelle bulle « ×4,5 » à gauche du tapis (environ 3 largeurs de bulle) |
| 3,65 | Clic : « +32 Vitesse » ; la bulle éclate à 3,78 |
| 4,3 | Apparition d'une bulle **arc-en-ciel « ×20 »** à droite, contre le panneau d'amélioration |
| 5,8 | Clic sur la ×20 : fenêtre d'achat Roblox « 20x Entraînement », prix 9 R$ (le joueur a 0 R$, Roblox propose donc d'abord un pack de Robux) (`robux_prompt2.jpg`) |
| 6,0 | Achat annulé, la ×20 reste à l'écran |
| 6,1 | Nouvelle bulle « ×3 » au-dessus de l'avant du tapis |
| 6,98 | Clic : « +21 Vitesse » ; la bulle éclate à 7,12 |
| 8,9 | Nouvelle bulle « ×4,5 », à gauche, plus loin (vers la clôture) |
| 9,5 | Clic : « +32 Vitesse » |
| 10,13 à 10,23 | La ×20, jamais achetée, disparaît seule |
| 10,5 à la fin | Fenêtre de l'enregistreur NVIDIA, plus rien d'utile |

Tout le long : de petits « +7 » avec une icône de chaussure sortent du tapis, et l'étiquette du tapis affiche « Tapis de course de niveau 1, +45 Vitesse/s ».

## 2. La mécanique

### Où et quand

- **Dans le monde 3D, autour du tapis**, à hauteur de poitrine ou un peu au-dessus. Positions vues : au-dessus de l'avant du tapis, à l'arrière du tapis, 3 à 4 largeurs de bulle à gauche, contre le panneau d'amélioration à droite. La place semble tirée au hasard dans un rayon de quelques studs autour du tapis (estimation, la caméra ne bouge pas).
- Très probablement des `BillboardGui` : les « +7 » du tapis passent par-dessus le bord d'une bulle (`m30_apparition_x3.jpg`, ligne 2), et la bulle garde **la même taille à l'écran quelle que soit sa profondeur** (127 px de diamètre au premier plan comme au fond), donc une taille en pixels (Offset). La caméra fixe empêche d'en être certain.
- Elles n'apparaissent que pendant l'entraînement : le joueur est sur le tapis toute la vidéo. On ne voit pas s'il en vient ailleurs.
- **Deux à la fois au plus** : deux ×2 (0 à 0,6 s), puis ×20 avec ×3 (6,1 à 7,0 s), puis ×20 avec ×4,5 (8,9 à 9,5 s). Jamais trois.
- **Fréquence** : apparitions à 2,7, 4,3, 6,1 et 8,9 s, soit un écart de **1,6 à 2,8 s** entre deux bulles. Après une prise, la suivante arrive 0,65 à 1,9 s plus tard. On ne sait pas si c'est un minuteur fixe avec du hasard ou un « remplir jusqu'à 2 ».
- **Durée de vie** : les bulles gratuites ont toutes été prises entre 0,6 et 2 s après leur apparition, donc **on ne sait pas si elles expirent**. La ×20 payante, jamais prise, a vécu **environ 5,9 s** (4,3 à 10,2 s), sans doute 6 s.

### Comment on les prend

- **Un clic sur la bulle**, curseur en main au survol (`full_5.0.jpg`). Il ne suffit pas de passer dessus : elles sont hors de portée du perso, qui reste sur le tapis.
- Pas de délai visible entre le clic et le chiffre. L'éclatement et son son arrivent 0,10 à 0,13 s plus tard (voir 4).

### Ce qu'elles donnent

- **Un gain immédiat de Vitesse, une seule fois** : `gain = multiplicateur × gain d'un tic du tapis`.
  - Le tapis donne des « +7 » à peu près **6,4 fois par seconde**, un nouveau toutes les 4 à 5 images à 30 i/s (`m30_tic_tapis.jpg`), soit environ 45/s, ce qui colle avec l'étiquette « +45 Vitesse/s ».
  - ×2 → **+14** (2 × 7) ; ×3 → **+21** (3 × 7) ; ×4,5 → **+32** (4,5 × 7 = 31,5, arrondi au-dessus).
- **Aucun bonus qui dure** : le compteur de Vitesse (`compteur.jpg`, 10 i/s) monte de 1,36K (0,2 s) à 1,96K (11,2 s), soit +600. Si l'on retire les cinq prises (14 + 14 + 32 + 21 + 32 = 113), il reste 487 en 11 s, soit **44/s**, le rythme de base. Juste après chaque prise, il reprend son pas habituel : +0,01K tous les 1 à 2 dixièmes de seconde.
- **Pas de cumul, pas de minuteur, pas d'icône d'effet actif** : rien à l'écran ne montre un bonus en cours.
- **Valeurs vues** : ×2 (deux fois), ×3, ×4,5 (deux fois) gratuites ; ×20 payante. La table des chances est inconnue.
- **Bulle payante** : produit développeur « 20x Entraînement » à 9 R$. Comme l'achat a été annulé, on ne sait pas si elle donne 20 × un tic (140) d'un coup ou un ×20 pendant un temps.

### Autres offres visibles (même idée, même écran)

- Un bouton à gauche « ×2 Vitesse, UNIQUEMENT ⓡ3 », une offre Robux en situation, comme notre `SpeedBoostButton`.
- Le panneau d'amélioration du tapis : « 44K $ » ou « ⓡ9 ».
- Un objet « ×3 » dans la barre d'objets (case 2), qui ne sert pas dans la vidéo. Rôle inconnu.

## 3. Le rendu

### La bulle gratuite (`zoom_bulle_x2.jpg`)

- **Forme** : disque plein, environ **127 px de diamètre sur 1080, soit 11,8 % de la hauteur** de l'écran. Toutes les valeurs (×2, ×3, ×4,5) ont **la même taille et la même couleur** : aucune rareté visible chez les gratuites.
- **Remplissage** : dégradé vertical, de haut en bas `#F6BEFF` (lilas très clair) → `#E76BF7` → `#CC57F4` → `#BD4AF1` (violet vif). Reflet clair en haut, plus sombre en bas : effet bombé.
- **Contour** : anneau violet foncé, environ 3 % du diamètre (épaisseur et teinte estimées, le bord est flou).
- **Icône** : une grosse flèche blanche en relief (face `#FEFFFF`, biseau gris, contour sombre), environ 55 % du diamètre, inclinée. Elle dit « clique-moi ».
- **Étiquette « ×N »** : texte blanc à gros contour noir, environ 30 px (2,8 % de la hauteur), posé en bas à droite, à cheval sur le bord, penché d'environ −10°.

### La bulle payante ×20 (`zoom_bulle_x20.jpg`, `strip_x20.jpg`)

- Même forme, même taille, même icône, même étiquette.
- Remplissage **arc-en-ciel en diagonale** (jaune, vert, bleu, violet, magenta), contour violet.
- **Le dégradé tourne** : en un point fixe de la bulle, la couleur passe de magenta (6,4 s) à bleu (7,2), vert (7,6 à 8,0), jaune (8,4 à 8,8), puis revient au vert (9,2 à 9,6) et au bleu (10,0). Cet aller-retour colle avec un dégradé linéaire qui tourne : **environ un tour en 4,5 s** (estimé), soit environ 80° par seconde.
- C'est le seul repère de « rareté » : **la couleur arc-en-ciel signale la bulle payante**. La taille ne change pas.

### Apparition (`m30_apparition_x3.jpg`, 30 i/s, une case = 33 ms)

- Image 1 : environ 35 % de la taille finale. Image 2 : 75 %. Image 3 : 90 %. Images 4 et 5 : **environ 105 %**, petit dépassement. Puis retour à 100 % vers 0,3 s.
- Pas de fondu : elle grossit, opaque dès la première image. Aucun son.
- Roblox : `TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)` sur un `UIScale`, de 0,35 à 1.

### Flottement

- **Aucun** mouvement mesurable : la bulle ×20 suivie pendant 5,4 s (`strip_x20.jpg`) bouge de ±4 px au plus. Pas de rotation, pas de brillance, pas de particules. Seul l'arc-en-ciel de la ×20 bouge.

### Prise (`m30_prise_x45.jpg`, `m30_prise_x3.jpg`)

1. Clic (t0) : le texte de gain apparaît **au centre de la bulle**, en fondu sur 0,1 s (3 images).
2. t0 à t0 + 0,1 s : la bulle **gonfle jusqu'à environ 120 %**.
3. t0 + 0,1 à t0 + 0,13 s : elle **s'écrase à rien en 1 à 2 images**. Pas d'éclats, pas de particules.
4. Le son tombe avec l'écrasement (voir 4).

- Roblox : `UIScale` de 1 à 1,2 en `TweenInfo.new(0.1, Quad, Out)`, puis de 1,2 à 0 en `TweenInfo.new(0.05, Quad, In)`.

### Texte de gain (`zoom_texte_gain.jpg`)

- « +32 Vitesse », précédé d'une icône de chaussure bleue. Environ 30 px de haut (2,8 % de l'écran).
- Remplissage : dégradé vertical, bleu clair `#65C6FF` en haut, bleu profond `#0056A0` en bas. Gros contour bleu nuit.
- **Vie : environ 1,0 s.** Fondu d'entrée 0,1 s, montée lente d'environ 30 px (≈ 3 % de l'écran) qui ralentit, fondu de sortie sur les 0,1 à 0,2 dernières secondes.
- Ce sont les mêmes couleurs que les petits « +7 » du tapis, en plus gros : la bulle est clairement un « gros tic ».

### Expiration (`m30_fin_x20.jpg`)

- La bulle gonfle d'environ 10 % en 0,1 s, puis rétrécit jusqu'à disparaître en 0,1 s (le rétrécissement commence vers 10,13 s ; plus rien à 10,23 s). Aucun son.
- Roblox : de 1 à 1,1 en `TweenInfo.new(0.1, Quad, Out)`, puis de 1,1 à 0 en `TweenInfo.new(0.1, Back, In)`.

## 4. Les sons, déduits du spectre (je n'entends rien)

Spectres : `spec_tout.png` (toute la vidéo) et `spec_prise_x3.png` (6,9 à 7,5 s).

- **Prise d'une bulle** : un **clic sec** (bruit large jusqu'à environ 15 kHz, très court), puis un **petit glissando qui monte** d'environ 300 Hz à environ 1 kHz en 80 ms, un « bloup » de bulle. En tout moins de 0,1 s. On le voit aux cinq prises : 0,70, 1,83, 3,76, 7,11 et 9,63 s.
- **Décalage** : le son tombe avec l'écrasement de la bulle (±20 ms), soit **0,10 à 0,13 s après l'apparition du chiffre**.
- **Le son ne change pas avec la valeur** (×2 ou ×4,5) : même trace.
- **Aucun son** à l'apparition, à l'expiration ni au survol.
- Fond : musique très douce, autour de −90 dB dans les aigus, qui s'efface vers 7 s. Petites paires de bruits entre 5 et 8 kHz, sans doute les pas sur le tapis. Le gros bruit vers 10,5 s vient de l'enregistreur NVIDIA.
- **À écouter par Clément** : 3,6 à 3,9 s et 6,9 à 7,2 s, pour confirmer le « clic plus bloup ».

## 5. Rythme : pourquoi c'est satisfaisant

- Un fond régulier : environ 6 petits « +7 » par seconde.
- Par-dessus, un **gros moment toutes les 1,5 à 2,5 s** : une bulle apparaît (avec rebond), on clique, un gros chiffre sort et le compteur saute.
- La bulle demande un geste, mais le prix est faible : un clic, sans viser vite, sans perdre son gain (on reste sur le tapis). C'est un « clicker » posé sur un jeu inactif.
- La bulle payante apparaît **au milieu des gratuites**, avec la même forme. Le joueur a pris l'habitude de cliquer dessus, d'où un clic d'achat presque réflexe : c'est voulu de leur côté.

## 6. Comment le refaire dans Steal a Shop

### Nos valeurs (rien d'inventé)

- Tapis : `Config/Training.Treadmill`, avec un gain de `1 × 2^(niveau − 1)` par seconde (`Formulas.TreadmillGain`). **Un tic par seconde** (`TREADMILL_TICK = 1`), affiché en un seul « +X Speed » par seconde (`Config/Hud.TreadmillGain`, `ChunksPerSecond = 1`).
- Aujourd'hui, taper l'écran donne +50 % de gain pendant 1 s (`TapBonus = 0.5`, `TapBonusWindow = 1`), avec au plus 6 taps/s (`MaxTapsPerSecond = 6`, remote `TrainTap`).
- Offre Robux déjà prévue sur le tapis : `Config/Boosts`, `SpeedBoost` (×2 pendant 10 min, 29 R$, V0 non validé, `Ready = false`).
- Multiplicateurs, chances, nombre de bulles, cadence, durée de vie, prix de la bulle payante : **rien n'existe dans le doc ni dans `Config`**. Tout ce qui suit est à faire décider par Clément.

### Formule proposée

- Comme chez eux, **gain immédiat = multiplicateur × gain d'un tic** du tapis, avec les mêmes multiplicateurs que le tic (gamepass ×2 Training, `LiveEvents`, `SpeedBoost`). Chez nous un tic vaut une seconde, donc **une bulle ×2 = deux secondes de tapis d'un coup**.
- Variante que Cantin a décrite : un ×N sur le gain du tapis **pendant D secondes**. Plus simple à expliquer, mais il faut alors un minuteur à l'écran, et le cumul devient une question. À choisir (question 1).

### Partie code (Ironix)

- **Serveur autoritaire** (un `TrainingBubbleService`, ou dans `TrainingService`) :
  - il crée les bulles pour chaque joueur sur un tapis (id, multiplicateur, position, heure de fin), dans la limite du maximum à la fois et à la cadence choisie ;
  - il les envoie **au seul propriétaire** par un remote serveur → client (`TrainBubbleSpawn`) ;
  - le clic du client part par `TrainBubbleClaim(id)`, que le serveur valide (section 9.4) : la bulle existe, elle est à ce joueur, elle n'a pas expiré, le joueur est sur son tapis, cadence limitée. Le serveur calcule le gain lui-même, le client n'envoie jamais de valeur.
- **Client** : il clone le gabarit de Clément `BB_TrainBubble` (`ReplicatedStorage/Assets/UI`), le place autour du tapis, joue les tweens d'apparition, de prise et d'expiration, et réutilise le texte flottant existant (`Config/UiMotion.FloatGain`) en plus gros, avec l'icône Speed.
- **Piège Roblox** : un bouton dans un `BillboardGui` ne reçoit les clics que si le `BillboardGui` est **dans `PlayerGui`, avec `Adornee`** posé sur une pièce ou un `Attachment` du monde. Dans `Workspace`, il ne réagit pas. Mettre `Active = true` et `AlwaysOnTop = true`.
- **Positions** : soit des `Attachment` posés par Clément autour du tapis (`BubbleSlot_01` à `_06`, **nouveau nom du contrat, à annoncer et à ajouter au tableau 10.4 avant usage**), soit un tirage dans un anneau autour de `UsePoint` fait par le code. À choisir (question 6).
- **Bulle payante** (si Clément la veut) : un produit développeur créé **au nom du groupe**, reçu traité par `MonetizationService` (`PurchaseId` stocké, achat idempotent). L'arc-en-ciel tourne par le code : `UIGradient.Rotation` +80° par seconde, puisqu'il n'y a aucun script dans l'UI.
- **Valeurs de tween** (mesurées, à mettre dans `Config/UiMotion`) :

| Moment | Tween |
| --- | --- |
| Apparition | `UIScale` 0,35 → 1, `TweenInfo.new(0.25, Back, Out)` |
| Prise | 1 → 1,2 en `TweenInfo.new(0.1, Quad, Out)`, puis 1,2 → 0 en `TweenInfo.new(0.05, Quad, In)` ; son au début du second tween |
| Texte de gain | fondu d'entrée 0,1 s ; montée d'environ 3 % de l'écran en `TweenInfo.new(0.9, Quad, Out)` ; fondu de sortie 0,15 s ; vie totale environ 1,0 s |
| Expiration | 1 → 1,1 en `TweenInfo.new(0.1, Quad, Out)`, puis 1,1 → 0 en `TweenInfo.new(0.1, Back, In)` ; sans son |
| Arc-en-ciel | `UIGradient.Rotation` +80° par seconde (environ un tour en 4,5 s) |

- Son : un seul `Sound` de prise (clic plus « bloup » qui monte, moins de 0,1 s), joué par le code au moment de l'écrasement. On peut monter un peu le `PlaybackSpeed` avec la valeur si Clément veut que ×5 sonne plus haut que ×2 (eux ne le font pas).

### Partie visuelle (Clément)

Gabarit `BB_TrainBubble` dans `ReplicatedStorage/Assets/UI`, gris d'abord, puis habillé :

- `BB_TrainBubble` (`BillboardGui`) : taille fixe à l'écran (Offset), comme chez eux, **au moins 44 px sur téléphone**. Leur 11,8 % de la hauteur donne environ 46 px sur un écran de téléphone de 390 px : c'est la bonne échelle. `LightInfluence = 0`.
  - `Bubble` (`ImageButton`, disque) avec `UICorner` (0,5), `UIGradient` vertical (clair en haut, saturé en bas, notre palette et non leur violet), `UIStroke` (anneau foncé, environ 3 % du diamètre) et `PopScale` (`UIScale`, animé par le code).
  - `Icon` (`ImageLabel`) : **notre** icône, pas un curseur de souris. Par exemple l'icône Speed, une chaussure ou un éclair, de notre style, environ 55 % du diamètre.
  - `Multiplier` (`TextLabel`) : « x2 », blanc, `UIStroke` noir épais, en bas à droite à cheval sur le bord, `Rotation` −10°. Le code écrit la valeur.
  - Variante payante, si Clément la veut : un second `UIGradient` `PremiumFill`, multicolore ou à nos couleurs « Robux », que le code active et fait tourner.
- **Couleur par valeur** : eux n'en ont pas (toutes violettes, sauf la payante). On pourrait reprendre nos couleurs de rareté (×2 commun, ×5 épique…) pour que les grosses valeurs se repèrent. À choisir (question 5).
- **Son de prise** : un « bloup » court de notre banque, rangé avec les autres sons de l'UI.
- **Texte de gain** : le flottant existant « +X Speed », en version grande (environ 2,8 % de l'écran au lieu de celle du tic).
- Aucun script dans le gabarit.

## 7. Ce qui fait « pro » chez eux

- **Une seule idée lisible** : un disque, une icône qui dit « clique », un nombre. On comprend sans tutoriel.
- **Le gain reprend le langage du tapis** : même chaussure, même bleu, en plus gros. Le joueur relie tout de suite la bulle à sa Vitesse.
- **Des animations courtes et sèches** : apparition en 0,25 s, éclatement en 0,13 s. Rien de mou.
- **Un son seulement à la prise** : la récompense sonne, le reste est silencieux, donc pas de bruit de fond agaçant.
- **De la retenue** : pas de particules, pas de flottement, pas de brillance sur les gratuites. Seule la payante bouge, et elle se remarque d'autant plus.

## 8. Ce que la vidéo ne permet pas de savoir

- Si les bulles gratuites expirent, et au bout de combien de temps (toutes ont été prises en moins de 2 s).
- La règle exacte d'apparition : minuteur, hasard ou « remplir jusqu'à 2 ». La table des chances des multiplicateurs (vus : ×2, ×3, ×4,5).
- L'effet réel de la ×20 payante : gain immédiat ou effet qui dure (achat annulé).
- Si les bulles viennent ailleurs que sur le tapis, et si les autres joueurs les voient.
- Le comportement sur téléphone (vidéo prise sur PC, à la souris).
- Le rôle de l'objet « ×3 » de la barre d'objets.
- Le son exact : tout est déduit du spectre. Il faut l'écouter.

## 9. Questions pour Clément (choix de jeu)

1. **Gain immédiat** (comme chez eux : ×2 = deux secondes de tapis d'un coup) ou **multiplicateur qui dure** (idée de Cantin : ×2 pendant D secondes, avec un minuteur à l'écran) ?
2. Quels multiplicateurs, avec quelles chances ? Combien de bulles à la fois (eux : 2) ? Toutes les combien de secondes (eux : environ 2 s) ? Durée de vie (eux : environ 6 s pour la payante) ?
3. Une bulle payante au milieu des gratuites (eux : ×20 pour 9 R$) ? Si oui, remplace-t-elle ou complète-t-elle le bouton « ×2 vitesse » (`SpeedBoost`) ?
4. Les bulles remplacent-elles le « taper l'écran = +50 % » actuel, ou s'y ajoutent-elles ?
5. Une couleur par valeur (nos couleurs de rareté) ou une seule couleur comme eux ?
6. Positions : au hasard autour du tapis (le code tire) ou sur des emplacements que tu poses (`BubbleSlot_01` à `_06`, nouveau nom du contrat) ?
7. Quelle icône dans la bulle, de notre style ?
