# Vidéo de référence « Settings » (2026-11-22) : analyse et propositions pour `UI_Settings`

Demande de Clément : « Analyses cette vidéo pour mettre les mêmes effets pour notre UI de settings. Je parle des animations d'entrées, d'hover, au clic sur on off, au slide du son ect. Analyses tous les détails et fais moi des propositions d'améliorations de notre UI settings. »

- **Vidéo** : `WhatsApp Video 2026-11-22 at 12.11.01.mp4`. 21 s, 576 × 1024, 30 i/s. C'est un TikTok filmé au téléphone devant un écran de Studio : un menu Settings d'un autre jeu.
- **Planches** (10 i/s) dans `docs/claude/video/references/2026-11-22_Reglages/frames/` :
  - `entree.jpg` : l'ouverture ;
  - `toggle_b.jpg` : les clics ON / OFF ;
  - `slider.jpg` : le glisser du son ;
  - `sheet_b.jpg` : la vue d'ensemble de 6 à 12 s.
- **Les temps viennent des images.** La vidéo est filmée, floue et en 30 i/s : c'est à ± 0,05 s près.

## 1. Ce que fait la vidéo

### Ouverture (de 0,7 à 1,5 s)

1. Un voile bleu en dégradé couvre le jeu, que l'on devine dessous. Des flocons tombent lentement (thème d'hiver du jeu), et un cadeau reste en bas à gauche.
2. Le panneau apparaît presque à sa taille : environ 0,95 → 1, en fondu, en moins de 0,1 s. Pas de gros rebond.
3. Les rangées arrivent une par une, de haut en bas, **en fondu** (pas en grandissant), environ 40 ms d'écart. Les 8 rangées sont là en 0,3 s.
4. **Les curseurs se remplissent de 0 à leur valeur** pendant l'arrivée, et le pourcentage compte en même temps. Par exemple, Sound Effects passe par 15 %, 46 %, 68 %, 82 %, 96 %, 99 % puis 100 % (une image par 0,1 s) : environ 0,6 s, avec un ralenti à la fin.
5. L'engrenage de l'en-tête apparaît en dernier, vers 1,5 s. Il ne semble pas tourner ensuite.

### Fermeture (de 12,5 à 13,2 s)

Le panneau rétrécit, vers environ 0,85, en s'effaçant, en 0,3 à 0,4 s. Puis le voile disparaît.

À la réouverture, tout recommence : les rangées en cascade, et les curseurs repartent de 0 %.

### Clic sur ON / OFF

- **Toute la rangée s'allume** de la couleur du nouvel état : rose vif pour OFF, vert pour ON. Elle revient à son bleu nuit en environ 0,3 s.
- Le bouton rond glisse d'un bout à l'autre (environ 0,1 à 0,15 s). La pastille change de couleur (vert ↔ rose), et le mot ON / OFF passe du côté opposé au rond.
- La pastille est une **pilule** bien arrondie, avec le rond **à l'intérieur**. Le rond est blanc, avec un motif rayé.

### Glisser du son

- Le rond grossit nettement quand on le tient, à environ ×1,4 / ×1,5.
- Le pourcentage suit en direct.
- **Des notes de musique bleues (♪) s'envolent du rond** pendant le glisser de Music : elles montent sur 20 à 30 px en s'effaçant en environ 0,5 s, avec 3 ou 4 notes visibles à la fois.
- La piste est bleu foncé rayée, le remplissage vert.

### Survol

Rien de visible dans la vidéo : le curseur passe sur les rangées sans changement que l'on puisse lire à cette résolution.

### Mise en page

- 8 rangées : All Sounds, Sound Effects, Music, Performance Mode, Screen Shake, Show Pets, Title Animation, Speed.
- Chaque rangée est une barre bleu nuit avec un liseré clair. Le nom est à gauche, la commande à droite.
- Les rangées de son ont à la fois un curseur et un ON / OFF.
- L'en-tête porte un engrenage, le titre et une croix rouge.

## 2. Ce que notre `UI_Settings` fait déjà (code d'Ironix)

- **Ouverture** (`Motion`, `Config/UiMotion`, vague 74) :
  - la fenêtre passe de 0,5 à 1,055 puis à 1 ;
  - le flou et le voile noir (`UI_Veil`) sont derrière ;
  - les rangées de `Rows` arrivent en cascade, **en grandissant** de 0,2 à 1 ;
  - le titre arrive en « tampon » (`Appear = Stamp`).
- **Fermeture** : 1 → 1,04 → 0,5, puis l'écran s'éteint.
- **Boutons** : `Hover = Pop`, `Press = Squash` sur la croix, l'interrupteur, ‹ › et REDEEM.
- **Curseurs** : le rond grossit à ×1,18 pendant le glisser (`KnobGrab`) et le pourcentage suit.
- **Interrupteur** : le rond glisse en 0,16 s avec un rebond (`ToggleSlide`). `OnFill` et `OffFill` s'échangent d'un coup.

## 3. Propositions, de la plus visible à la moins visible

Légende : **C** = Clément (visuel, sans code, je peux le faire dans Studio) ; **I** = Ironix (code). Toutes les valeurs sont des V0 à régler à l'œil.

| # | Proposition | Qui | Détail |
| --- | --- | --- | --- |
| 1 | **La rangée s'allume au clic ON / OFF** | I (+ C) | Le fond de la rangée prend la couleur du nouvel état : vert `#9AFF09` pour ON, rose `#FF3D8B` pour OFF, à 60 % environ. Il revient à sa couleur en 0,3 s (Quad Out). Clément peut poser un cadre `RowFlash` caché dans chaque rangée ; le code joue sa transparence. |
| 2 | **Les curseurs se remplissent à l'ouverture** | I | `Fill` passe de 0 à sa valeur et `ValueLabel` compte de 0 % à la valeur, en 0,6 s Quad Out, en partant avec la rangée dans la cascade. |
| 3 | **Des notes qui s'envolent pendant le glisser** | I (+ C) | Music : des ♪. Sound effects : des petites ondes. Une note toutes les 0,12 s pendant que le rond bouge ; elle monte de 25 px en tournant un peu et s'efface en 0,5 s. Clément livre les deux icônes (`UI_Icon_Note`, `UI_Icon_Wave`) et un modèle caché `Slider.NoteTemplate`. |
| 4 | **Un interrupteur en pilule, au style de nos boutons** | C | Pilule bien arrondie, rose `#FF3D8B` pour OFF et vert `#9AFF09` pour ON, avec rebord sombre, motif Quilt et liseré clair comme les autres boutons. Rond blanc **dans** la pilule, contour sombre, petit motif ; ON / OFF du côté opposé au rond. Aujourd'hui, la pastille est un rectangle à angles presque droits et le rond déborde. |
| 5 | **Des curseurs au même style** | C | Piste sombre en creux, remplissage avec Quilt (violet pour Music, jaune pour Sound, comme aujourd'hui, ou les deux en vert comme la vidéo), rond blanc à contour sombre. Ils restent pour l'instant à l'ancien style, car ce ne sont pas des boutons. |
| 6 | **Le rond grossit plus** | I | ×1,18 aujourd'hui, ×1,35 proposé, avec un halo clair derrière pendant le glisser. |
| 7 | **Les rangées arrivent en fondu** | I | Dans les Réglages seulement : fondu et léger glissement (12 px de la gauche), 40 ms d'écart, au lieu de grandir de 0,2 à 1. C'est plus doux pour une liste. On garde le pop de la fenêtre. |
| 8 | **Un engrenage dans l'en-tête** | C (+ I) | Icône à gauche du titre, comme le gemme de Displays. Elle arrive en dernier, en pop avec un quart de tour (code). Facultatif : rotation lente avec `SpinSpeed`, déjà lu par le code pour les rayons. |
| 9 | **Un voile bleu au lieu de noir** | C + I | Dégradé bleu nuit vers bleu sur `UI_Veil` pour les Réglages, avec quelques étoiles ou pièces qui flottent. Les flocons, seulement pendant un événement d'hiver. |
| 10 | **La pastille change de couleur en fondu** | I | Vert ↔ rose en 0,12 s pendant que le rond glisse, au lieu de l'échange d'un coup de `OnFill` / `OffFill`. Le rond s'écrase un peu en arrivant (squash 0,9 puis 1). |
| 11 | **Survol d'une rangée** | I | Pas dans la vidéo, proposé : la rangée s'éclaircit de 8 % quand le pointeur est dessus (PC). |
| 12 | **Aperçu du son** | I | Au relâché de SOUND EFFECTS, jouer un petit son au nouveau volume. Au glisser de MUSIC, la musique change déjà. |
| 13 | **Nouvelles rangées** (facultatif, à valider) | C + I | « All Sounds » (tout couper d'un coup), « Screen Shake » (secousses de caméra), « Performance Mode » (moins d'effets, pour les petits téléphones). Il faut que le jeu sache le faire (Ironix). |

### Ordre proposé

1. **D'abord les points 4 et 5** : interrupteur et curseurs au style de nos boutons. C'est du visuel, je peux le faire dans Studio après une maquette.
2. **Ensuite 1, 2 et 3** pour Ironix : ce sont les trois effets qui font l'effet de la vidéo.
3. **Le reste en bonus.**

## 4. Maquette des points 4 et 5 (2026-11-22, à valider par Clément)

- **Images** dans `docs/claude/video/references/2026-11-22_Reglages/frames/` :
  - `reglages_interrupteur_curseurs_maquette.png` (PC, 1920 × 1080) : fenêtre avant / après, gros plans ON, OFF, curseur au repos et curseur tenu ;
  - `reglages_interrupteur_curseurs_telephone.png` (iPhone 17 Pro en paysage) : avant à gauche, après à droite, à la vraie taille du jeu.
- **Figma**, modifiable par Clément : fichier « Steal a Shop — UI », page `214:369`, cadre « Maquette Réglages — interrupteur et curseurs (22/11) » (node `294:4`), à droite de `UI_Admin` sur la rangée de `UI_Settings`. Il a été importé avec la chaîne `tools/clement/figma_copie` : 240 éléments, comme dans Studio. Seule différence avec Studio : `Halo` y est le frère de `Knob`, juste derrière lui, et non son enfant, sinon Figma le dessinerait par-dessus le rond.
- **Script** : `tools/clement/ui_reglages_interrupteur_curseurs_preview.luau`. Il construit un écran temporaire `_Maquette_Reglages`, supprimé après la capture. `UI_Settings` n'a pas été touché. Sa fonction `_G.ReglagesApres(window)` servira telle quelle pour le vrai écran.

### Ce qui change

- **Interrupteur** (`VfxRow.Toggle`) :
  - c'est une pilule de 0,24 × 0,7 de la rangée, avec le même bord droit que les curseurs ;
  - `OnFill` (vert `#9AFF09`) et `OffFill` (rose `#FF3D8B`) deviennent chacun un rebord sombre avec `Face`, `Quilt` et `Rim`, comme les boutons ;
  - `ToggleKnob` est un rond blanc dans la pilule (0,7 de haut, centré sur la face à 0,44), avec un contour sombre et un petit motif ;
  - `ToggleLabel` est centré sur la face ;
  - sur téléphone, la pilule fait au moins 88 × 44 px : à 71 × 44 px, le rond cachait « ON ».
- **Curseurs** (`MusicRow`, `SoundRow`) :
  - `Track` est une piste sombre en creux (dégradé, contour sombre, en pilule) ; ses anciens `Lip`, `Rim` et `Gloss` partent ;
  - `Fill` est un remplissage en pilule avec motif, violet `#A970FF` pour Music et jaune `#FFC62E` pour Sound ;
  - `Knob` est un rond blanc à contour sombre ;
  - `Slider` passe à 0,27 de large (0,32 avant) et `ValueLabel` se décale de 0,005 : le rond ne mange plus « 100% », ni sur PC ni sur téléphone. Aujourd'hui, il le mange sur les deux.
- **Ajout caché** : `Knob.Halo`, un disque clair derrière le rond, que le code montrera pendant le glisser.

### Ce qui ne change pas

- **Les noms lus par le code** : `Toggle`, `OnFill`, `OffFill`, `ToggleKnob`, `ToggleLabel`, `Track`, `Fill`, `Knob` et `ValueLabel` gardent leurs noms et leurs parents. Le code change toujours la visibilité, la place du rond et la largeur de `Fill`.
- **Pas de `UIScale` posé sur `Knob`** : le code n'en ajoute pas si Clément en a déjà posé un, et `KnobGrab` ne marcherait plus.

### Pour Ironix, si c'est validé

- Pendant le glisser, montrer `Knob.Halo`.
- Passer `Settings.Motion.KnobGrab.To` de 1,18 à 1,35 (proposition 6).

### Retouches de Clément (2026-11-22)

Faites dans Figma, sur les deux maquettes (`294:4` et `301:4`), et reportées dans `_G.ReglagesApres` (`tools/clement/ui_reglages_interrupteur_curseurs_preview.luau`). La fenêtre « Avant » est restée telle que l'écran est aujourd'hui.

- **Interrupteurs calés à droite**, sur le bord droit des flèches › : `Toggle` passe en `AnchorPoint` (1 ; 0,5), `Position` (0,97 ; 0,5). Clément les a déplacés dans Figma, de x = 364 à x = 443 dans une rangée de 606 px.
- **Motif en croix deux fois plus léger**, partout où il se trouve. Sur les faces des boutons et des pilules, la transparence passe de 0,82 à 0,91 (opacité Figma 0,18 → 0,09) ; sur les remplissages des curseurs, de 0,86 à 0,93.
- **Plus de motif sur les ronds blancs** (`Knob`, `ToggleKnob`).
- **Rien de la face sur l'ombre** : le liseré blanc (`Rim`) faisait une bande claire sur le bord du bas de la face, posée sur le rebord. Il s'efface maintenant vers le bas : dans Studio, c'est un `UIGradient` sous le `UIStroke` (transparence 0 jusqu'à 0,55, puis 1 à 0,9) ; dans Figma, un contour en dégradé. Le rebord du bas est donc une ombre unie.
- **À faire à l'application** : les mêmes retouches sur tous les boutons au style Framewisp du jeu (`tools/clement/ui_boutons_style_framewisp.luau`, 13 écrans et le HUD). Sinon, les boutons des Réglages ne seraient plus pareils que ceux des boutiques.

### Appliqué dans Studio (2026-11-22, « Oui, applique »)

Rien n'est enregistré, commité ni poussé.

- **Tous les boutons du jeu** : 131 boutons et plaques sur 14 écrans. Le motif passe à 0,91, et le liseré s'efface vers le bas (`RimFade`).
  - Script : `tools/clement/ui_boutons_retouches_motif_lisere.luau` (rejouable).
  - Sauvegarde : `MapBackups/2026-11-22_RetouchesBoutons/<écran>`.
  - `ui_boutons_style_framewisp.luau` prend les mêmes valeurs pour un prochain passage.
  - Les panneaux d'enseigne (`UpgradeSign`, `StoreReqSign`), où le motif est un fond opaque, ne sont pas touchés : ce ne sont pas des boutons.
- **Écran Réglages** : interrupteur en pilule calé à droite, curseurs au nouveau style, `Knob.Halo` caché.
  - Script : `tools/clement/ui_reglages_interrupteur_curseurs.luau`, à lancer une seule fois.
  - Sauvegarde : `MapBackups/2026-11-22_ReglagesStyle/UI_Settings`.
  - Les 6 nouvelles rangées et la liste qui défile (section 5) ne sont pas encore posées.
- **Vérifié** :
  - en Edit, sur PC (1920 × 1080) et sur iPhone 17 Pro : les pilules font 88 × 44 px et « 100% » se lit ;
  - en Play (environ 3 min) : le contrat est OK, sans ligne rouge. Le code pose `KnobScale` sur le rond. Un clic sur l'interrupteur met `VfxEnabled` à false, montre `OffFill` en rose, fait glisser le rond à gauche et passe « OFF » à droite ; un 2e clic remet ON. La musique à 35 % (valeur sauvegardée du compte de test) s'affiche bien, remplissage et rond compris.
  - Pendant ce Play, la fenêtre « Hors ligne » du compte de test a été réclamée ($6,9B, place DEV), pour fermer son voile qui bloquait les clics.
- **Copie Figma** (page `214:369`) mise à jour : les 14 écrans ont les retouches, et `UI_Settings` est refait depuis Studio (node `315:4`, 91 éléments). Le recentrage du texte sur la face n'est toujours dans la copie que pour `UI_Settings`.

### Vu en passant, hors maquette

Sur téléphone, dans la rangée `ClickRow`, « CLICK SOUND » touche le bouton ‹ et « CLASSIC » touche ›. Ce défaut existe déjà aujourd'hui.

## 5. Nouvelles options de confort et de performances (maquette du 2026-11-22, validée par Clément le 2026-11-22)

Demande de Clément : « ajouter plus d'options intéressantes dans l'UI settings qui peuvent être utiles pour le confort du joueur et pour les performances ».

- **Images** dans `docs/claude/video/references/2026-11-22_Reglages/frames/` :
  - `reglages_options_maquette.png` (PC) : haut et bas de la liste, et les notes. C'est le rendu du cadre Figma, avec les textes d'aide corrigés ;
  - `reglages_options_telephone.png` (iPhone 17 Pro) : haut et bas de la liste, à la vraie taille. Il montre encore les anciens textes d'aide de CAMERA SHAKE et FLASHING LIGHTS (« … and on hits », « Flashes and alarm lights »).
- **Figma** : page `214:369`, cadre « Maquette Réglages — nouvelles options confort et performances (22/11) » (node `301:4`), à droite de la maquette de l'interrupteur. Il a 419 éléments sur 434 : la conversion a supprimé `MusicRow` et `AudioHeader` de la fenêtre « bas de la liste », cachés au-dessus de la zone qui défile. Ils sont entiers dans la fenêtre « haut ».
- **Script** : `tools/clement/ui_reglages_options_preview.luau`, qui construit l'écran temporaire `_Maquette_Options`. Il s'appuie sur `_G.ReglagesApres` (section 4). `UI_Settings` n'a pas été touché.

### Les options proposées

Clément a validé les 6 options le 2026-11-22 (« Oui, garde-les »). Le style de l'interrupteur et des curseurs (section 4) attend encore ses retouches dans Figma.

Chacune correspond à un effet qui existe déjà dans le code. Aujourd'hui, `VISUAL EFFECTS` (`VfxEnabled`) les coupe toutes d'un coup (voir l'en-tête de `SettingsController`) : casse allégée sans tremblement de caméra, auras, trails et halos éteints, pas de `ChaseFov`, pas de gerbe d'argent.

| Rangée | Texte en jeu | Par défaut | Ce que ça fait | Pourquoi |
| --- | --- | --- | --- | --- |
| `PerfRow` | PERFORMANCE MODE, « Fewer particles, no blur or shadows » | OFF | moins de particules, pas de flou derrière les menus (`UiBlur`), pas d'effets de lumière de la casse, rayons (`SpinSpeed`) et reflets (`Sheen`) de l'UI à l'arrêt | petits téléphones |
| `OthersFxRow` | OTHERS' AURAS, « Auras & trails of other players » | ON | cacher les auras et les trails des autres joueurs (`CosmeticController`) | lisibilité et performances à 6 joueurs |
| `ShakeRow` | CAMERA SHAKE, « When glass breaks » | ON | tremblement de la caméra quand la vitrine casse (`ShatterController`) | confort |
| `FovRow` | FOV EFFECTS, « Camera zoom in chases » | ON | zoom de la caméra en poursuite (`ChaseFov`) et aux révélations | mal des transports |
| `FlashRow` | FLASHING LIGHTS, « Screen flashes » | ON | flash blanc de la casse (`ShatterController`) et des révélations rares (`RevealFlash`) | joueurs sensibles à la lumière |
| `HudSizeRow` | HUD SIZE : SMALL / NORMAL / LARGE | NORMAL | taille des boutons du HUD | confort sur téléphone et tablette |

- `VfxRow` reçoit un petit texte d'aide : « Auras, trails & particles ».
- **Écarté** : un réglage de qualité graphique. Le jeu ne peut pas changer la qualité de Roblox, c'est le joueur qui la règle dans le menu Roblox. Le flou des menus et les ombres sont rangés dans PERFORMANCE MODE, pour ne pas allonger la liste.

### Mise en page

- La liste défile, dans un `ScrollingFrame` `RowsScroll` posé à la place de `Rows`.
- **Seul `Rows` change de parent** : il passe dans `RowsScroll`, et les rangées restent ses enfants, avec leurs noms.
  - `Rows` n'est pas lu par chemin. `Find.path` cherche les rangées dans tous les descendants, et `Motion` (`OpenStagger.Rows`) trouve `Rows` par son nom, n'importe où dans l'écran.
  - C'est quand même un déplacement : à faire seulement avec l'accord de Clément au moment d'appliquer.
- **Quatre titres de section** : `AudioHeader`, `GraphicsHeader`, `ComfortHeader` et `CodesHeader`, chacun avec `HeaderLabel` et `HeaderLine`. C'est du décor, que le code ne lit pas.
- **Ordre** : AUDIO (Music, Sound Effects, Click Sound) ; GRAPHICS (Visual Effects, Performance Mode, Others' Auras) ; COMFORT (Camera Shake, FOV Effects, Flashing Lights, HUD Size) ; CODES.
- **Petit texte d'aide `RowHint`** sous le nom de chaque nouvelle rangée. `RowLabel` remonte à 0,36.
- **Hauteurs** : en px dans la maquette (rangées de 68 px sur PC, 44 sur téléphone ; titres de 30 et 22 px). À l'application, elles doivent suivre la taille de l'écran ; c'est à vérifier sur téléphone.
- **Téléphone** : la liste défile bien, les pilules font 88 × 44 px et les textes d'aide font environ 10 px de haut. Il reste le défaut de `ClickRow` (« CLICK SOUND » et « CLASSIC » touchent les flèches), et `HudSizeRow` l'a aussi (« NORMAL »). Les deux sont à corriger à l'application.
- **Icônes provisoires**, prises dans le jeu : Upgrades, Aura, Camera, SpeedBoost, Warning et Displays. Les vraies sont à dessiner par Clément (noms V0 dans l'attribut `IconAsset` : `UI_Icon_Performance`, `UI_Icon_OthersFx`, `UI_Icon_Shake`, `UI_Icon_Fov`, `UI_Icon_Flash`, `UI_Icon_HudSize`).

### Posé dans Studio (2026-11-22, « Oui, pose-les »)

Rien n'est enregistré, commité ni poussé.

- **Script** : `tools/clement/ui_reglages_options.luau`, à lancer une seule fois. **Sauvegarde** : `MapBackups/2026-11-22_ReglagesOptions/UI_Settings`.
- **`Rows` est dans `RowsScroll`** (`ScrollingFrame`, `AutomaticCanvasSize` Y), à sa place.
  - `Rows` fait 1,755 fois la hauteur visible, et toutes les tailles sont en proportion. Sur PC, les rangées font 70 px et les titres 30 px.
  - `RowMin` garde 44 px au moins sur téléphone, les titres 18 px.
  - Le `UIListLayout` de `Rows` est calé en haut. Il était centré, ce qui décalait tout vers le bas.
- **Titres de section** : `AudioHeader`, `GraphicsHeader`, `ComfortHeader` (caché) et `CodesHeader`.
- **Les 6 rangées sont posées, CACHÉES** (`Visible = false`) : `PerfRow` (montrée sur OFF), `OthersFxRow`, `ShakeRow`, `FovRow`, `FlashRow` et `HudSizeRow` (« NORMAL »). Leurs icônes sont provisoires. `VfxRow` a son texte d'aide.
- **Défilement** : tant que les options sont cachées, tout tient sans défiler sur PC. Sur téléphone, la liste défile jusqu'aux codes. Avec tout visible, la liste fait 1 013 px sur PC et défile.
- **ClickRow lisible sur téléphone** (et `HudSizeRow`, sa copie) :
  - `RowLabel` fait 0,3 de large ;
  - `PrevButton` est à 0,45 ;
  - `NextButton` est calé à droite (`AnchorPoint` 1, à 0,98) ;
  - `ChoiceLabel` est centré à 0,715.
- **Vérifié** :
  - en Edit, sur PC et sur iPhone 17 Pro, haut et bas de la liste. Images : `reglages_reel_pc.jpg` et `reglages_reel_telephone.png` ;
  - en Play (environ 2 min) : le contrat est OK. Le code trouve toujours `VfxRow.Toggle` et `ClickRow` dans la liste qui défile : un clic sur l'interrupteur met `VfxEnabled` à false, `NextButton` passe à SHARP (`ClickSound` = Sharp), et tout a été remis (CLASSIC, ON). Les rangées cachées le restent.
  - Pendant ce Play, la fenêtre « Hors ligne » n'a pas été réclamée : Réglages a été passé devant, seulement pendant le Play.
- **Copie Figma** : `UI_Settings` est refait (node `317:4`, 205 éléments, rangées cachées comprises).

### Pour Ironix, si c'est validé

1. Des attributs du joueur et une sauvegarde, comme `VfxEnabled` (V0) : `PerfMode`, `OthersFx`, `CameraShake`, `FovEffects`, `FlashingLights`, `HudSize` (`Small`, `Normal`, `Large`). Les ajouter à `Settings.Default`, `Sanitize` et `SaveSettings`.
2. Brancher les rangées, déjà posées et cachées dans Studio, puis les montrer (`Visible = true`, avec `ComfortHeader` dès qu'une rangée COMFORT l'est) :
   - les 5 interrupteurs comme `VfxRow.Toggle` (`OnFill`, `OffFill`, `ToggleKnob`, `ToggleLabel`) ;
   - `HudSizeRow` comme `ClickRow` (`PrevButton`, `NextButton`, `ChoiceLabel`).
3. Faire lire ces attributs par les contrôleurs déjà cités. `VISUAL EFFECTS` ne couperait plus que les auras, trails et particules, puisque le tremblement et le zoom ont maintenant leur propre option. C'est à décider par Ironix.
4. `HUD SIZE` : un `UIScale` sur les groupes du HUD (0,85 / 1 / 1,15, valeurs V0), sans sortir des zones sûres du téléphone.