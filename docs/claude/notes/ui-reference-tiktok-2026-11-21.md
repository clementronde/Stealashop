# Boutons « vivants » : analyse d'une vidéo TikTok de référence (2026-11-21)

Vidéo envoyée par Clément : lien TikTok `vm.tiktok.com/ZGdXnNqJH` (compte phoxik.dev), fichier `C:\Users\User\Downloads\WhatsApp Video 2026-11-21 at 04.08.53.mp4` (43,6 s, 576 × 1024, 30 i/s ; la page TikTok demandait une connexion au bout de 10 s). C'est une **pub pour un plugin Figma → Roblox** (Framewisp). On y voit le même menu de 4 tuiles (Shop, Rebirth, Index, Settings) sans effets, puis avec effets, et entre les deux les réglages du plugin. On reprend les **techniques** (durées, courbes, couches), jamais leurs dessins, leurs textes ni le plugin.

Images clés, gardées dans le dépôt : [img/tiktok-2026-11-21/](img/tiktok-2026-11-21/). Les autres planches sont dans le scratchpad de la session (pas durables).

Méthode : planches horodatées à 2 i/s sur toute la vidéo ; à 30 i/s sur les deux passages de démo (2,0 à 3,9 s et 36,0 à 39,4 s) ; **colonne de pixels** à travers la tuile Index, image par image, pour suivre au pixel le bord de la tuile et le haut de l'icône ; zoom × 3 quadrillé de l'icône Rebirth, au repos et au survol, pour l'angle ; spectre du son. Deux valeurs se lisent dans le panneau du plugin à l'écran : **Hover scale 1.08** et **Sweep time 0.8 s**. Toutes les autres sont comptées image par image, à ± 1 image (33 ms) et ± 1 px. La capture fait 576 px de large ; une tuile mesure 196 px de côté.

## En bref

1. **Trois couches bougent séparément au survol** : la tuile entière grossit un peu, l'icône **saute** (ou **s'incline**) à part, et le titre a un **reflet** qui passe. Le bouton répond sans bouger en bloc.
2. **Tuile** : × 1,08 en 0,07 à 0,1 s, sans rebond ; retour pareil à la sortie.
3. **Saut de l'icône** : elle monte de 15 px (≈ 13 % de sa hauteur, ≈ 7,5 % de la tuile) et redescend doucement, en ≈ 0,4 s en tout. Le saut va jusqu'au bout même si la souris est déjà partie.
4. **Inclinaison** (une seule icône sur quatre) : ≈ 3 à 4° vers la gauche, en ≈ 0,07 s, tenue tant que la souris est dessus.
5. **Reflet** : une bande claire traverse **tous les titres en même temps**, de gauche à droite, en 0,8 s (0,6 s visibles sur le mot). Il passe dès que l'écran apparaît, puis revient environ toutes les 2,7 s, **sans lien avec la souris**.
6. La construction des tuiles est celle de la maquette de Clément (« Boutique clément », Figma 191:2772) : fond en dégradé vif, motif de studs, gros contour sombre, titre blanc à contour noir épais. Les effets ne changent rien à cette construction : ils la font vivre.

## 1. Catalogue des moments

| Temps (s) | Ce qu'on voit |
| --- | --- |
| 0,0 à 1,9 | Menu 2 × 2 dans le jeu, « without effects » : la souris passe, rien ne bouge |
| 2,0 à 3,9 | Le même menu « with effects » : survol tuile par tuile, reflet sur les 4 titres à 2,13 s |
| 4,0 à 6,0 | Figma : sélection des 4 calques |
| 6,0 à 9,0 | Plugin : ajout de `_smooth` (« grandit au survol, rétrécit à l'appui »), Hover scale 1.08 |
| 10,0 à 12,0 | Ajout de `_lean` sur l'icône de Rebirth (« incline un calque intérieur quand le bouton est survolé ») |
| 16,5 à 20,0 | Ajout de `_jump` sur les 3 autres icônes (« un saut complet haut-bas au survol ») |
| 21,0 à 24,3 | Ajout de `_gleam` sur les 4 textes (« balaie une lumière sur le texte et son contour »), Sweep time 0.8 s |
| 25,0 à 35,5 | Aperçu des 4 tuiles, export vers Roblox, import dans Studio |
| 36,0 à 39,4 | Le menu dans le jeu, avec effets : survol de chaque tuile, reflets à 36,0 et à 38,7 s |
| 39,5 à 43,6 | Logo TikTok de fin |

## 2. La tuile qui grossit (`_smooth`)

Images : `survol_30ips_2-3s.jpg`, `survol_30ips_36-37s.jpg`.

### Chez eux

| Mesure | Valeur |
| --- | --- |
| Taille finale | × 1,08 (lu dans le plugin). Mesuré : + 7 à 8 px par bord sur 196 px (bord haut de la tuile Index de y 517 à 510 ; bord bas de Shop de y 501 à 509) |
| Montée | Atteinte en **2 à 3 images (0,07 à 0,1 s)** ; pas de 1, 3, puis 2 px, donc départ franc et arrivée douce : `Quad Out` |
| Rebond | Aucun dépassement au-delà de 1,08 (à 1 px près) |
| Sortie | Retour à 1 en ≈ 0,1 s, même courbe |
| Inclinaison de la tuile | Aucune |
| Appui | Le plugin dit « rétrécit à l'appui » ; aucun clic n'est montré dans la vidéo |

Traduction Roblox : `UIScale` 1 → 1,08, `TweenInfo(0.1, Quad, Out)`, retour pareil.

### Chez nous aujourd'hui

- **Boutons** (`Motion.Button`, ex. `LeftRail/IndexButton`, `RightRail/DisplayedButton`, tous en `Hover = "Pop"`) : le bouton grossit × 1,1 en 0,067 s, Quad Out (`Config/UiMotion.HoverPop`). C'est déjà de la même famille que la vidéo, un peu plus fort et plus sec.
- **Cartes de liste** (`Motion.HoverCard`, une carte avec un enfant `HoverOutline`, ex. les cartes de `UI_RobuxShop` en `Hover = "Pop"`) : **la carte ne grossit pas**. Elle penche de 3° (`HoverPop.CardTilt`), son `Icon` grossit × 1,15 et `HoverOutline` s'allume. C'est la plus grosse différence avec la vidéo, où c'est la tuile entière qui grossit, sans pencher.

## 3. L'icône qui saute (`_jump`)

Mesure : colonne de pixels à travers la tuile Index (x = 182), deux sauts complets (36,57 à 37,13 s et 37,70 à 38,13 s). Hauteur de l'icône au repos mesurée par rapport au bord haut de la tuile.

### Chez eux

| Mesure | Valeur |
| --- | --- |
| Hauteur | **15 px**, soit ≈ 13 % de la hauteur de l'icône (≈ 110 px) et ≈ 7,5 % de la tuile |
| Montée | ≈ 0,17 à 0,2 s ; pas de 2, 3, 4, 2, 2 px : départ lent, arrivée lente (`Sine InOut`) |
| Descente | ≈ 0,2 s ; pas de 1, 4, 3, 3, 2, 2 px : atterrissage en douceur, sans rebond visible (≤ 2 px, dans le bruit de mesure) |
| Total | ≈ 0,4 s |
| Départ | Avec le survol, sans attente |
| Fin | Le saut va **jusqu'au bout même si la souris part** (au premier saut, la souris quitte la tuile à 36,70 s, le sommet est à 36,93 s) |
| Pendant le saut | Un nouveau survol pendant la descente (37,10 s) n'a pas relancé de saut |
| Avec la tuile | L'icône est un enfant de la tuile : elle grossit avec elle (× 1,08) pendant qu'elle saute |
| Hors du cadre | Le plugin a une option « Hop above clipping » : l'icône peut dépasser du cadre en sautant |

Traduction Roblox : deux tweens de `Position` de l'`Icon`, 0,18 s `Sine InOut` vers le haut puis 0,2 s `Sine InOut` vers le bas, en partant toujours de la `Position` posée par Clément.

### Chez nous aujourd'hui

Rien ne saute. En `Pop`, l'icône grossit sur place ; sans attribut (`HoverCard`), elle monte de 3 % de la hauteur de la carte et reste en haut tant que la souris est dessus. **Le saut complet est nouveau : il demande du code** (section 8).

## 4. L'icône qui s'incline (`_lean`)

Images : `inclinaison_rebirth_repos-survol.jpg` (zoom × 3 quadrillé, 37,300 s au repos et 37,533 s au survol), `inclinaison_rebirth_30ips_37s.jpg`.

### Chez eux

| Mesure | Valeur |
| --- | --- |
| Angle | **≈ 3 à 4° vers la gauche** (sens inverse des aiguilles d'une montre), mesuré sur deux segments de l'icône : de −30,0° à −33,0°, et de 5,6° à 2,0° |
| Taille | La même que la tuile (× 1,09 mesuré entre deux points de l'icône, pour × 1,08 sur la tuile) : pas de grossissement à part |
| Aller | ≤ 0,07 s (déjà penchée l'image d'après l'entrée de la souris) |
| Tenue | Penchée tant que la souris est dessus |
| Retour | ≈ 0,07 s |

Traduction Roblox : `Rotation` de l'`Icon` de 0 à −3,5, `TweenInfo(0.07, Quad, Out)`, retour pareil.

### Chez nous aujourd'hui

Sans attribut, `HoverCard` penche déjà l'icône (−6°), la grossit (× 1,12) et la décale vers le haut, en 0,1 s `Back Out` : c'est proche, en plus fort. En `Pop`, l'icône ne penche pas.

## 5. Le reflet sur les titres (`_gleam`)

Images : `gleam_15ips_23-24s.jpg` (aperçu du plugin), `reflet_titres_30ips_2-4s.jpg` et `reflet_titres_30ips_36-39s.jpg` (dans le jeu).

### Chez eux

| Mesure | Valeur |
| --- | --- |
| Forme | Bande claire floue, presque verticale (légèrement penchée), large d'environ une lettre (≈ 12 % du mot) |
| Sens | De gauche à droite |
| Durée | Réglée à 0,8 s ; visible sur le mot pendant ≈ 0,6 s (INDEX : de 2,13 à 2,73 s ; REBIRTH : de 38,70 à 39,27 s) |
| Courbe | Vitesse constante (`Linear`) |
| Ce qu'il touche | Surtout le **contour** : sur un texte blanc, le contour noir devient blanc et flou au passage de la bande |
| Quand | **Sur les 4 titres en même temps**, dès que l'écran apparaît (2,13 s, juste après le passage à « with effects » ; 36,0 s, juste après l'import), puis à nouveau ≈ 2,7 s plus tard (38,70 s). Soit 0,8 s de reflet et ≈ 1,9 s de pause. Une seule période mesurée |
| Lien avec la souris | Aucun : les 4 titres brillent ensemble, que la souris soit dessus ou non |

Traduction Roblox, à vérifier en jeu : un `UIGradient` fait **varier** une couleur mais ne peut pas la rendre plus claire que la couleur de base (il la multiplie). Pour un titre blanc à contour sombre :

- le `UIStroke` du titre passe en **blanc**, et un `UIGradient` nommé `Gleam`, enfant de ce `UIStroke`, porte la couleur sombre du contour partout, sauf une bande blanche au milieu (couleur du contour jusqu'à 0,44, blanc à 0,5, couleur du contour à partir de 0,56) ;
- au repos, `Offset` = (−0,7 ; 0) : la bande est hors du texte, donc le contour garde exactement sa couleur d'avant ;
- le code fait défiler `Offset.X` de −0,7 à 0,7 en 0,8 s `Linear`, puis attend 1,9 s, en boucle ;
- `Rotation` du dégradé ≈ 15° pour la bande penchée ;
- pour un titre de couleur (jaune, par exemple), même chose sur le `TextLabel` lui-même : `TextColor3` en blanc et un `UIGradient` `Gleam` jaune, blanc au milieu, jaune.

### Chez nous aujourd'hui

`RarityFx` fait déjà passer un reflet (`Sheen`, toutes les 2 s) sur les éléments de rareté Légendaire, mais rien sur les titres. **Le défilement demande du code** (section 8). Clément peut préparer la couche `Gleam` au repos, sans script et sans rien changer à l'image.

## 6. Pour UI_RobuxShop

Pour la session qui refait la boutique Robux d'après la maquette « Boutique clément » (Figma 191:2772). Les noms entre guillemets sont ceux de l'écran actuel dans Studio (`List/Template`, `Icon`, `ItemName`, `HoverOutline`) : à adapter aux noms de la nouvelle version.

| Couche | Ce qu'on reprend de la vidéo | Ce qu'il faut dans l'écran (Clément) | Ce que fait le code |
| --- | --- | --- | --- |
| La carte | Grossit au survol, sans pencher. Petites tuiles (≈ 200 px) : × 1,08. **Grandes cartes** (passes de jeu, ≈ 550 px de large) : garder la même croissance en pixels (≈ 8 px par bord), soit × 1,03 à × 1,05, sinon la carte touche ses voisines (les écarts de la maquette font ≈ 23 px). 0,1 s `Quad Out`, retour 0,1 s | Rien de plus (garder `HoverOutline`) | Aujourd'hui, la carte penche de 3° sans grossir : demande 1 |
| L'icône, saut | Monte de ≈ 13 % de sa hauteur, redescend, ≈ 0,4 s en tout, une fois par survol, jusqu'au bout | L'`Icon` reste un enfant direct de la carte et n'est **pas dans un cadre qui coupe** (`Clip` ou `ClipsDescendants`), sinon le haut du saut est coupé. Attribut proposé sur la carte : `IconHover = "Jump"` | Demande 2 |
| L'icône, inclinaison | −3,5°, 0,07 s, tenue pendant le survol | Attribut proposé : `IconHover = "Lean"` | Demande 3 (ou `HoverCard` actuel, un peu plus fort) |
| Le titre (« ×2 CASH », etc.) | Reflet sur le contour, tous les titres de l'écran ensemble, à l'ouverture puis toutes les ≈ 2,7 s | `UIStroke` du titre en blanc + `UIGradient` `Gleam` dessous, au repos (section 5) ; pour un titre de couleur, `Gleam` sur le `TextLabel` | Demande 4 |
| La carte survolée | Passe au-dessus de ses voisines | — | `ZIndex` de la carte survolée relevé le temps du survol (avec la demande 1) |

Une icône sur quatre qui s'incline et les autres qui sautent : c'est le choix de la vidéo. Le même effet pour toutes les icônes d'une même rangée, ou un effet par type d'offre, c'est à Clément de décider (section 10).

## 7. Le HUD (fait dans Studio le 2026-11-21, accord de Clément)

Les boutons du HUD ressemblent aux tuiles de la vidéo et grossissent déjà au survol (`Hover = "Pop"`, × 1,1 en 0,067 s). On leur a préparé le saut de l'icône et le reflet du titre ; **rien ne bouge encore** : il faut les demandes 2 et 4 (section 8).

**Ce qui a changé** (script rejouable [tools/clement/ui_hud_tiktok.luau](../../../tools/clement/ui_hud_tiktok.luau), avec `REVERT = true` pour tout enlever) :

- Copie de l'écran avant le changement : `ServerStorage/MapBackups/2026-11-21_HUD_TikTok/UI_HUD`.
- Sur 7 boutons : `UI_HUD/LeftRail/{RobuxShopButton, IndexButton, SkillTreeButton}`, `UI_HUD/LeftRailTouch/{RobuxShopButton, IndexButton, SkillTreeButton}` (les petits carrés du téléphone, L-265), `UI_HUD/RightRail/DisplayedButton` :
  - `Label/UIStroke` : `Color` passe en blanc, et un nouvel enfant `UIGradient` nommé **`Gleam`** porte l'ancienne couleur du contour (vert, bleu, rouge ou jaune foncé selon le bouton), sauf une bande blanche au milieu (0,44 à 0,56), `Rotation` 15°, `Offset` (−0,7 ; 0) au repos ;
  - attribut **`IconHover = "Jump"`** sur le bouton (le saut partout ; mettre `"Lean"` à la main pour une icône qui s'incline).
- Rien n'est renommé ni déplacé, aucun script dans l'UI.
- **Pour changer la couleur d'un contour de ces 7 titres** : changer les couleurs de `Gleam` (ses 4 points sombres), plus `UIStroke.Color`, qui doit rester blanc.

**Vérifié** :

- Au repos, l'image ne change pas : captures avant et après dans Studio, zones des 4 titres identiques au pixel près (PSNR 48 à 49 dB, le bruit de compression ; une zone témoin où la pluie bouge : 32 dB).
- Play sur PC (1753 × 753) : les 7 `Gleam` et les attributs sont dans la copie du joueur ; en plaçant la bande à la main sur cette copie (comme le fera le code), une bande blanche traverse bien le contour sombre de chaque titre, et le texte reste lisible : `hud_play_pc_repos-reflet.jpg` (à gauche au repos, à droite avec la bande), `hud_play_pc_capture.jpg`.
- Play en émulation iPhone 17 Pro (750 × 381, tactile) lancé avec l'appareil déjà réglé : `LeftRailTouch` s'affiche (boutons de 48 × 48 px), la bande passe aussi sur ses titres, mais ces titres ne font que 12 à 16 px de haut, donc le reflet y est discret : `hud_play_telephone_repos-reflet.jpg`, `hud_play_telephone_capture.jpg`.
- Sortie : aucune erreur côté client ; le ContractChecker ne signale rien sur `UI_HUD` (son seul « problème » est un nom en double dans `UI_RobuxShop_v2`, l'écran en cours chez la session de la boutique).
- Les deux Play ont été arrêtés, l'émulation remise par défaut, la place n'a pas été enregistrée.

**Pas vérifié** : le saut et le reflet qui défile, puisque le code ne les joue pas encore. Points d'attention pour Ironix sur le HUD : les icônes de `LeftRail` dépassent déjà du haut du bouton (`Position` Y −0,086) et sautent à partir de là ; le code choisit `LeftRail` ou `LeftRailTouch` au démarrage, il faut donc brancher les deux barres.

## 8. Demande pour Ironix

Toutes les valeurs sont des **V0 proposées**, mesurées sur la vidéo, à régler en jeu. Les noms (`Hover = "Grow"`, `IconHover`, `Gleam`, `Config/UiMotion.*`) sont des propositions : Ironix les valide avant que Clément les pose partout.

1. **Carte qui grossit** (`Motion.HoverCard`) : une variante, par exemple `Hover = "Grow"` sur la carte, où la carte entière grossit (UIScale) à `To` en 0,1 s `Quad Out`, retour 0,1 s `Quad Out`, sans `CardTilt`. `To` = 1,08 pour une carte de moins de ≈ 250 px, sinon la valeur qui donne ≈ 8 px par bord (en pratique 1,03 à 1,05). Relever le `ZIndex` de la carte le temps du survol.
2. **Saut de l'icône** : `IconHover = "Jump"` sur la carte ou le bouton. L'enfant `Icon` monte de 13 % de sa propre hauteur (`AbsoluteSize.Y`) en 0,18 s `Sine InOut`, puis redescend en 0,2 s `Sine InOut`, et retrouve exactement la `Position` de Clément. Un saut par entrée de la souris ; pas d'interruption si la souris part ; pas de nouveau saut tant que le précédent n'est pas fini. Valeurs proposées : `Config/UiMotion.HoverJump = { Height = 0.13, UpTime = 0.18, DownTime = 0.2, Style = Sine, Direction = InOut }`.
3. **Inclinaison de l'icône** : `IconHover = "Lean"` : `Rotation` de l'`Icon` de sa valeur de Clément à −3,5° en 0,07 s `Quad Out`, tenue pendant le survol, retour en 0,07 s, sans décalage ni grossissement à part. `Config/UiMotion.HoverLean = { Tilt = -3.5, Time = 0.07, BackTime = 0.07 }`.
4. **Reflet `Gleam`** : pour chaque `UIGradient` nommé `Gleam` d'un écran ouvert (enfant d'un `UIStroke` ou d'un `TextLabel`), faire défiler `Offset.X` de −0,7 à 0,7 en 0,8 s `Linear`, puis attendre 1,9 s, en boucle. Tous les `Gleam` d'un écran partent ensemble, à l'ouverture de l'écran ; arrêt quand l'écran est fermé ou caché, avec `Offset` remis à (−0,7 ; 0). Une boucle par écran, pas une par titre. `Config/UiMotion.Gleam = { Sweep = 0.8, Pause = 1.9, From = -0.7, To = 0.7 }`.

Pour les 4 demandes : ne rien jouer quand le réglage « animations réduites » est actif (`Settings.VfxReduced` ou `ReducedMotionEnabled` de Roblox, comme `PurchaseGlow`).

Déjà prêt côté Clément : les 7 boutons du HUD ont leur `Gleam` et leur `IconHover = "Jump"` (section 7). La boutique Robux suivra avec sa nouvelle version (section 6).

À tester en jeu ensuite (humain) : la sensation au survol sur PC, et le reflet sur téléphone (lisibilité, pas de clignotement gênant).

## 9. Sons, rythme, et ce qui fait « pro »

- **Sons** (déduit du spectre, pas écouté) : voix off et musique pendant toute la vidéo ; des coups larges sur le rythme de la musique (≈ 37,2 ; 37,9 ; 38,9 s), sans lien avec les survols. **Aucun son d'UI repérable**. Chez nous, `UI_Hover` existe déjà.
- **Rythme** : dans la démo de fin, la souris passe sur 7 tuiles en 3,4 s, soit ≈ 2 retours par seconde, chacun en deux ou trois temps (tuile, icône, puis le reflet qui passe tout seul). Comme chaque couche est petite et courte, l'écran reste calme.
- **Pro** : les couches bougent séparément, avec des réglages différents ; le reflet périodique attire l'œil sur les titres sans clignoter.
- **Chez nous en comparaison** : la carte et son icône partent ensemble (Pop), ou l'icône monte et reste en haut (HoverCard). C'est propre, mais moins vivant. Notre maquette a déjà la construction de leurs tuiles : il ne manque que les mouvements.

## 10. Questions pour Clément (choix de jeu)

1. ~~Veux-tu ces effets aussi sur les boutons du HUD ?~~ Oui (2026-11-21) : fait, section 7.
2. Le reflet : toutes les ≈ 2,7 s comme dans la vidéo, ou plus rarement ?
3. Saut ou inclinaison : le saut partout (posé par défaut sur le HUD), ou comme dans la vidéo, une icône qui s'incline au milieu d'icônes qui sautent ?
4. Les cartes de la boutique : grossir sans pencher (comme la vidéo), ou garder la petite inclinaison de 3° actuelle en plus ?
