# Effets, ouvertures d'écrans et « petits pops » : analyse d'une vidéo de référence (2026-11-16)

Vidéo fournie par Cantin : `C:\Users\user\Videos\NVIDIA\Desktop\Desktop 2026.11.16 - 18.12.57.01.mp4` (45,9 s, 1920 × 1080, 120 i/s). Le tapis de course n'apparaît pas dans cette vidéo (le joueur s'entraîne au **banc**) ; pour le tapis, j'ai mesuré en plus la vidéo courte `... 18.16.28.02.mp4` (déjà analysée pour ses bulles dans [2026-11-16_video-bulles-multiplicateur.md](2026-11-16_video-bulles-multiplicateur.md)).

Images extraites, dans le scratchpad, **pas durables** : `C:\Users\user\AppData\Local\Temp\claude\4da6080c406c1ed3\6c086951-47a0-4d5f-97f2-0fdce09c2163\scratchpad\video1\frames\`. Les noms cités plus bas renvoient à ce dossier.

Méthode : planches horodatées à 2, 15, 30, 40 et 60 i/s ; mesures au pixel (bord du panneau sur une colonne, boîte englobante des cartes) ; spectre du son. On reprend les **techniques** (durées, courbes, ordre, rythme), jamais leurs dessins, textes, sons ni leur identité.

## En bref (ce qui fait « fluide »)

1. **Toutes les fenêtres s'ouvrent pareil** : échelle 0,55 → 1,05 → 1,00 en 0,38 s. C'est exactement un `Back Out` de 0,38 s. Chez nous : 0,55 → 1 en 0,15 s `Quint Out`, sans dépassement, donc plus sec.
2. **Toutes les fenêtres se ferment pareil** : elles gonflent d'abord (+11 %), puis rétrécissent jusqu'à 0, en 0,17 à 0,22 s. C'est un `Back In`. Chez nous : 1 → 0,4 en 0,07 s, un « clac » sans élan.
3. **Le contenu arrive après le cadre**, bloc par bloc (titre, onglets, lignes, objet, bouton), avec environ 65 ms entre deux blocs. Les cartes d'une liste arrivent de gauche à droite, avec environ 22 ms de décalage.
4. **Les gains de l'entraînement jaillissent du joueur, restent un instant, puis sont aspirés par le compteur**, qui monte à leur arrivée. Il y en a environ 4 par seconde.
5. **La récompense se montre sur des rayons**, puis fait un tour complet sur elle-même.

## 1. Catalogue des moments

| Temps (s) | Écran | Ce qui se passe |
| --- | --- | --- |
| 0,0 à 1,0 | Monde | Fenêtre système de Roblox (favori), fermée. Superposition de l'enregistreur NVIDIA à gauche, à ignorer |
| 1,0 à 2,9 | Monde | Le joueur court avec une traînée blanche (sprint), entre dans le cercle d'un stand |
| 2,86 | Boutique d'auras | **Ouverture** : panneau large, 5 cartes en ligne |
| 3,09 à 3,31 | Boutique d'auras | Les 5 cartes surgissent l'une après l'autre |
| 7,20 à 7,42 | Boutique d'auras | **Fermeture** |
| 8,88 | Boutique de potions | **Ouverture** (même courbe) |
| 11,85 à 12,0 | Boutique de potions | **Fermeture** (même courbe) |
| 18,7 à 36,3 | Banc | Entraînement : bandeau en haut (« saute pour te lever »), gains « +8 / +9 » qui jaillissent autour du joueur et repartent vers le compteur |
| 36,5 à 37,5 | Monde | Sprint avec traînée blanche |
| 37,70 | Récompenses | **Ouverture**, puis le contenu arrive bloc par bloc |
| 37,73 | Récompenses | Les rayons s'allument derrière l'emplacement de la récompense, avant l'objet |
| 38,10 | Récompenses | La récompense (carte) surgit sur les rayons, puis fait un tour sur elle-même à 38,43 |
| 39,90 | Récompenses | Changement d'onglet : contenu remplacé en une image, nouvelle carte qui tourne en boucle |
| 41,27 à 41,43 | Récompenses | **Fermeture** ; le bas du HUD remonte de 41,43 à 41,60 |

## 2. Gains qui volent (banc, puis tapis)

### Chez eux : banc (vidéo 1, 18,7 à 36,3 s)

Planches : `bench_gain_track.jpg` (30 i/s), `bench_gain_fly60.jpg` et `bench_gain_end60.jpg` (60 i/s), `bench_gain_life.jpg` (15 i/s).

Vie d'un gain, mesurée sur le « +8 » parti à 26,00 s :

| Phase | Mesure | Courbe déduite |
| --- | --- | --- |
| Naissance | Sur le joueur (≈ 940, 550 px), toute petite. Taille finale atteinte en ≈ 80 ms (5 images à 60 i/s) | Échelle 0 → 1, `Back Out` ou `Quint Out`, 0,08 s |
| Jet | Part du joueur vers un point au hasard autour de lui (gauche, droite, au-dessus). Mesuré : ≈ 350 px (18 % de la largeur de l'écran) en ≈ 0,33 s, dont les deux tiers dans les 0,13 premières secondes | `Quint Out`, 0,33 s |
| Pause | Presque immobile ≈ 0,7 s (petite dérive de quelques pixels) | Rien, ou une légère dérive linéaire |
| Aspiration | Repart vers le compteur de puissance (sous la barre d'actions, en bas au centre) en rétrécissant de 1 à ≈ 0,3 ; disparaît en ≈ 0,15 s (25,95 → 26,10) | `Quad In` ou `Back In`, 0,15 s |
| Arrivée | Le compteur du bas change (7,97K → 7,98K…) et la barre d'XP gagne +8 ou +9 | Le chiffre monte à l'arrivée, pas au départ |

- **Vie totale** : ≈ 1,2 s.
- **Cadence** : un gain toutes les 0,23 à 0,27 s, soit **≈ 3,7 à 4 par seconde** (comptage de la barre d'XP : 191 → 199 → 207 → 216 → 224 entre 18,9 et 19,73 s). Il y a donc 4 à 5 gains à l'écran en même temps, éparpillés autour du joueur.
- **Taille** : chiffre + pastille ≈ 110 × 55 px, soit le chiffre à ≈ 3,5 % de la hauteur de l'écran (estimé sur les planches zoomées).
- **Construction** : chiffre blanc à gros contour noir, et à sa droite une pastille en étoile rose à pointes (l'icône de la stat). Pas d'ombre visible.

### Chez eux : tapis (vidéo 2)

Planches : `v2_tread60.jpg`, `v2_tread30.jpg`, `v2_icon_track.jpg` (40 i/s).

- Une icône (chaussure + « +7 ») naît **toute petite à la tête du joueur**, atteint sa taille en ≈ 50 ms en montant de ≈ 20 px, puis dérive lentement vers le haut et la gauche (≈ 50 px en 0,3 s) et s'efface en ≈ 100 ms. Vie ≈ 0,4 à 0,5 s.
- **Cadence** : une icône toutes les **0,15 s** (≈ 6,7 par seconde), naissances à 3,65, 3,80, 3,95 et 4,10 s ; 3 ou 4 icônes visibles à la fois, en grappe.
- Contrairement au banc, je ne vois pas ces icônes rejoindre le compteur de vitesse (en bas à gauche) : elles s'effacent sur place, à l'avant du tapis. Le « vers lui » que Cantin a vu vient sans doute de la grappe qui part toujours du joueur, et du banc où le gain revient bien vers le compteur.
- **Gros gain de bulle** (« +N Vitesse » après un clic sur une bulle) : la bulle gonfle (≈ 1,2) en ≈ 70 ms puis disparaît en ≈ 100 ms ; le texte apparaît à sa place en fondu (≈ 30 ms), reste ≈ 0,8 s, puis s'efface en ≈ 130 ms sans bouger (`v2_bubble.jpg`, `v2_label_end.jpg`).

### Pourquoi ça marche

On **voit le gain voyager** du corps du joueur jusqu'au chiffre qu'il fait monter : la cause et l'effet sont reliés par un trajet. La pause au milieu laisse le temps de lire le nombre, et la cadence (4 à 7 par seconde) remplit l'écran de petits retours sans bruit visuel, parce que chaque gain est petit et court.

### Chez nous (entraînement : tapis = vitesse, banc = force)

Aujourd'hui, `GainController` affiche un `BB_Gain` qui monte de 2,2 studs en 1 s et s'efface (`UiMotion.FloatGain`) ; depuis a200, un seul gain par seconde sur le tapis. Rien ne rejoint le compteur, sauf l'argent (`CashFly`).

**Code (Ironix)** :
- Faire voler les gains d'entraînement comme `CashFly`, mais en version courte et nombreuse : position de départ = `Camera:WorldToViewportPoint` du `HumanoidRootPart`, copie d'un modèle de Clément dans `UI_HUD`, puis :
  1. `UIScale` 0 → 1 en `TweenInfo.new(0.08, Enum.EasingStyle.Back, Enum.EasingDirection.Out)` ;
  2. `Position` vers un point au hasard à 12-18 % de l'écran autour du joueur, `TweenInfo.new(0.33, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)` (en même temps que 1) ;
  3. pause de 0,7 s ;
  4. `Position` vers le compteur du HUD (`SpeedRow` pour le tapis, `StrengthRow` pour le banc) et `UIScale` 1 → 0,3, `TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)` ;
  5. à l'arrivée : le compteur ajoute le morceau et sursaute (`Motion.Pop`, comme `SpeedPulse`).
- Cadence : découper le gain en 4 morceaux par seconde (le réglage `Config/Hud.TreadmillGain.ChunksPerSecond` existe déjà ; Cantin l'a remis à 1 le 15/11, donc c'est à lui de trancher). Le total reste celui du serveur : le découpage est seulement visuel.
- Garder un plafond (par exemple 6 gains en vol) et réutiliser les copies, pour le téléphone.

**Visuel (Clément)** :
- Un modèle de gain dans `UI_HUD` (par exemple `TrainGainFly.Template`, nom à valider dans le contrat) : `Amount` (`TextLabel`, chiffre blanc, `UIStroke` noir d'environ 12 % de la hauteur du texte) et `Icon` (`ImageLabel`) à droite.
- Deux icônes à nous : une pour la vitesse, une pour la force, dans notre palette. Pas de chaussure ni d'étoile rose recopiées.

## 3. Ouverture des fenêtres

### Chez eux

Mesuré au pixel sur le bord haut du panneau, à 60 i/s (`col.py`), pour trois écrans :

| Écran | 1re image | Échelle à la 1re image | 1,00 atteint | Pic | Repos |
| --- | --- | --- | --- | --- | --- |
| Boutique d'auras | 2,86 | ≈ 0,56 | +130 ms | **1,055** à +200 ms | +380 ms |
| Récompenses | 37,70 | ≈ 0,59 | +120 ms | **1,056** à +200 ms | ≈ +400 ms |
| Potions | 8,88 | (non mesurable, masqué) | | 1,035 à +140-250 ms | ≈ +350 ms |

Planches : `aura_open.jpg`, `aura_hud60.jpg`, `rew_open.jpg`.

- **Pas de fondu** : le panneau est opaque dès sa première image, seule l'échelle bouge.
- **Pas de flou ni d'assombrissement du fond** : le monde reste net et lumineux autour.
- **Le HUD s'écarte** : la barre de niveau et les boutons d'achat rapide du bas descendent hors de l'écran pendant l'ouverture (≈ 150 ms, 37,73 → 37,87) ; la barre d'actions disparaît. Le cadre HP en haut reste. Ils reviennent à la fermeture (≈ 170 ms, 41,43 → 41,60).
- **Le contenu arrive après le cadre** :
  - **Boutique d'auras** (`aura_cards60.jpg`, boîtes mesurées) : les 5 cartes surgissent de gauche à droite à 3,09 / 3,11 / 3,13 / 3,16 / 3,18 s, soit **≈ 22 ms de décalage**, à partir de +230 ms (quand le cadre est à son pic). Chaque carte passe de ≈ 0,2 à 1,0 de largeur en **≈ 130 ms**, avec un départ rapide et une fin douce, sans dépassement visible : un `Quad Out`.
  - **Récompenses** (`rew_open.jpg`, 30 i/s) : cadre à +0 ; titre à ≈ +130 ms ; onglets à +200 ms ; ligne 1 à +270 ms (fondu ≈ 60 ms) ; ligne 2 à +330 ms ; récompense à +400 ms ; bouton principal à +470 ms. Soit **≈ 65 ms entre deux blocs**, et le dernier bloc arrive ≈ 0,5 s après le clic.
- **Mise en page des récompenses** (image à 39,0 s, `full_39.0.jpg`) : panneau à 29-71 % de la largeur et 15-85 % de la hauteur ; barre de titre ≈ 9 % de la hauteur (texte ≈ 4 %) ; bouton de fermeture carré rouge ≈ 7,5 % de la hauteur, dans le coin haut droit, à l'intérieur ; lignes ≈ 9 % ; bouton principal ≈ 8 %. Le corps est sombre et translucide (#4C5944 relevé sur fond d'herbe), avec un motif de briques à peine visible. La boutique d'auras est plus large (≈ 13-86 % de la largeur, 17-83 % de la hauteur).

### Pourquoi ça marche

Le dépassement de 5 % donne le « pop » sans faire cartoon ; avec 0,38 s, on le voit sans attendre. Le contenu qui suit fait lire l'écran **dans l'ordre** : cadre, titre, choix, puis action. Le HUD qui s'écarte dit « tu es dans un menu » sans assombrir le monde.

### Chez nous

Notre `UI/Appear` fait aujourd'hui `Pop` 0,55 → 1 en 0,15 s `Quint Out` (pas de dépassement), et une cascade de 0,05 s entre enfants (`Cascade.Gap`).

**Code (Ironix)**, dans `Config/UiMotion` :
- `Pop` : garder `From = 0.55`, passer à `Time = 0.38`, `Style = Back`, `Direction = Out`. Un `Back Out` de 0,55 à 1 dépasse d'environ 10 % du trajet, soit un pic à ≈ 1,045 vers 0,22 s : c'est la courbe mesurée.
- Cascade, deux réglages selon le type d'enfant :
  - blocs d'un écran (titre, onglets, lignes, bouton) : `Start = 0.13`, `Gap = 0.065`, chaque bloc avec un fondu (`GroupTransparency` d'un `CanvasGroup`, ou `TextTransparency`) de 0,06 s plus une petite montée ;
  - cartes d'une liste (boutique, index) : `Start = 0.23`, `Gap = 0.022`, `UIScale` 0,2 → 1 en `TweenInfo.new(0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)`, de gauche à droite. Au-delà de 6 cartes, plafonner le décalage total (environ 0,15 s) pour que le dernier élément n'arrive pas après 0,5 s.
- Écarter le HUD du bas pendant qu'un écran est ouvert : `Position` décalée de +15 % vers le bas en `TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)`, retour en `TweenInfo.new(0.17, Enum.EasingStyle.Back, Enum.EasingDirection.Out)`. Ne pas toucher au haut. À arbitrer par Clément (question 3).

**Visuel (Clément)** : rien de neuf pour la courbe. Pour la cascade, il faut que chaque bloc soit un enfant séparé (Frame ou CanvasGroup) dans l'ordre de lecture, avec un `LayoutOrder` propre, sans changer les noms du contrat.

## 4. Fermeture des fenêtres

### Chez eux

| Écran | Début | Gonflement | Disparu | Total |
| --- | --- | --- | --- | --- |
| Boutique d'auras | 7,20 | **+11 %** à +83 ms | +217 ms | 0,22 s |
| Récompenses | 41,27 | **+11 %** à +50 ms | +167 ms | 0,17 s |
| Potions | 11,85 | ≈ +3 % à +17 ms | ≈ +150 ms | 0,15 s |

Planches : `aura_close.jpg`, `rew_close.jpg`.

- La fenêtre **prend son élan** (elle grossit), puis rétrécit jusqu'à 0. Pas de fondu : elle reste opaque jusqu'au bout.
- Le contenu ne part pas en cascade : tout part avec le cadre.

### Pourquoi ça marche

L'élan avant de partir lit comme un geste, et c'est deux à trois fois plus court que l'ouverture : on ne fait pas attendre le joueur qui veut jouer.

### Chez nous

**Code (Ironix)** : `Pop.CloseTo = 0`, `CloseTime = 0.2`, `CloseStyle = Back`, `CloseDirection = In`. Un `Back In` de 1 à 0 recule d'environ 10 % avant de partir : on retrouve le +11 % mesuré. Aujourd'hui : 1 → 0,4 en 0,07 s `Quad In`.

**Visuel (Clément)** : rien.

## 5. Récompense présentée : rayons, apparition, tour sur elle-même

### Chez eux (37,73 à 41,0 s)

Planches : `rew_card30.jpg`, `rew_rays.jpg`, `rew_rays_1s.jpg`, `rew_spin.jpg`, `rew_tab.jpg`.

- **Rayons** : un soleil de ≈ 16 rayons clairs (crème, translucides) sur le fond sombre, centré sur l'emplacement de la récompense, de diamètre ≈ 2 fois la carte. Il est visible **dès 37,73**, avec le cadre, plus lumineux pendant l'ouverture, avant l'arrivée de l'objet. Il tourne lentement (rotation estimée à moins de 0,1 tour par seconde, non mesurée avec précision).
- **Apparition de la carte** à 38,10 : de 0,5 à 1,0 de largeur en ≈ 150 ms, sans dépassement visible (`Quad Out` ou `Quint Out`).
- **Tour complet** à 38,43 : la carte se met de profil à 38,45 puis à 38,62, soit **un tour en ≈ 0,33 s**, une seule fois, ≈ 0,33 s après son arrivée. Ensuite, elle ne bouge plus.
- **Dans l'onglet suivant** (39,90 → 41,0) : la carte fait un tour toutes les ≈ 0,63 s (profils à 40,10 / 40,27, puis 40,73 / 40,90), en boucle.
- **Changement d'onglet** : le contenu est remplacé **en une image** (39,867 → 39,90), sans glissement. Seul le tour de la carte donne du mouvement.

### Pourquoi ça marche

Les rayons arrivent **avant** l'objet : l'œil sait où regarder, et l'objet « tombe » dans la lumière. Le tour sur lui-même dit « c'est à toi, regarde-le » sans texte.

### Chez nous (récompenses `UI_Rewards`, prime de l'index, gros vol)

**Code (Ironix)** :
- Rayons : rotation continue d'une `ImageLabel` (`Rotation += 36 * dt`, soit 0,1 tour par seconde, à régler à l'œil), allumée avec le cadre : `ImageTransparency` 1 → 0,3 en `TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)`.
- Apparition de l'objet : `UIScale` 0,5 → 1, `TweenInfo.new(0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)`, à +0,4 s de l'ouverture.
- Tour sur lui-même (l'UI de Roblox n'a pas de 3D) : `Size.X.Scale` 1 → 0 en 0,08 s `Quad In`, puis 0 → 1 en 0,08 s `Quad Out`, deux fois (≈ 0,33 s), une fois à l'arrivée. Ou bien un `ViewportFrame` avec le vrai modèle de l'objet qui tourne : c'est plus « nous », puisque nos objets volés sont des modèles 3D.

**Visuel (Clément)** :
- Une image de rayons à nous (`ImageLabel`, carrée, rayons doux, fond transparent), dans notre palette, par exemple teintée de la couleur de la rareté.
- Un emplacement `RewardSlot` (nom à valider) dans l'écran : rayons derrière, objet devant.

## 6. Autres « pops » relevés

| Effet | Temps | Mesure | Chez nous |
| --- | --- | --- | --- |
| Traînée de sprint | 1,0 à 3,0 ; 36,5 à 37,5 | Large ruban blanc derrière le joueur, qui s'efface en ≈ 0,5 s | `Trail` natif, déjà prévu avec nos trails achetés : rien à copier |
| Bandeau d'état en haut pendant le banc | 18,7 à 36,3 | Texte blanc à contour noir, centré, fixe | Rien d'important en haut de l'écran (règle UI) : le mettre au-dessus de la barre d'actions |
| Compteurs qui montent | Tout le banc | Argent +1 à chaque tic, XP +8/+9, puissance +0,01K, ≈ 4 changements par seconde | `Motion.Roll` existe ; lui donner du travail en découpant les gains (section 2) |
| Bulle cliquable qui éclate | Vidéo 2 | Gonfle à ≈ 1,2 en 70 ms, disparaît en 100 ms | Voir la note des bulles |

Je n'ai **pas** mesuré d'animation au repos sur les boutons (respiration, brillance) : rien de net dans les planches.

## 7. Sons (déduits du spectre, rien n'est entendu)

Spectres : `spec_all.png`, `spec_aura_open.png`, `spec_aura_close.png`, `spec_bench.png`, `spec_rew_open.png`.

- **Fond** : une musique en boucle, assez basse (≈ −34 dB en moyenne, crêtes à −18 dB), avec des frappes régulières. Elle s'arrête vers 31,7 s ; ensuite, il ne reste que des sons d'interface.
- **Ouverture de la boutique d'auras** : un bloc large (2 à 6 kHz, ≈ 180 ms) à 3,10 s, au moment où les cartes surgissent (+240 ms après le cadre) : sans doute un souffle ou un pop d'apparition.
- **Fermeture** : un bloc médium (2 à 5 kHz, ≈ 0,2 s) à 7,12 s, ≈ 80 ms **avant** que le cadre ne bouge : c'est le clic du bouton, et l'animation suit.
- **Ouverture des récompenses** : à 37,80 s (+100 ms après le cadre), un scintillement aigu (12 à 17 kHz) qui dure plus d'1 s : des étincelles ou un carillon, calés sur les rayons et la récompense.
- **Banc** : des frappes toutes les ≈ 0,17 s, mais je ne peux pas séparer un éventuel son de gain de la musique.

À faire écouter à Clément : 2,8 à 3,4 s (ouverture), 7,0 à 7,5 s (clic puis fermeture), 37,6 à 39,0 s (étincelles de récompense), 24 à 26 s (banc : y a-t-il un son par gain ?).

**Chez nous** : un clic court sur chaque bouton, joué à l'appui (avant l'animation, comme chez eux) ; un souffle court à l'ouverture ; un scintillement aigu de 1 s pour une récompense. Nos sons à nous ; Clément choisit.

## 8. Rythme

- **Banc** : ≈ 4 gains par seconde, chacun avec 2 retours (le gain qui jaillit, puis le compteur qui change à son arrivée), soit ≈ 8 petits retours par seconde, en plus de la musique.
- **Tapis** : ≈ 6,7 icônes par seconde, plus un gros texte toutes les quelques secondes avec les bulles.
- **Écran de récompenses** : 7 événements en 0,5 s (cadre, titre, onglets, 2 lignes, objet, bouton), puis le tour de l'objet à +0,73 s et les étincelles pendant 1 s.

Chez nous, depuis a200, le tapis donne **1 retour par seconde**. C'est l'écart le plus visible avec leur jeu.

## 9. Ce qui fait « pro » chez eux, et ce qui fait « fait vite » chez nous

Pro chez eux :
- **Une seule courbe d'ouverture et une seule de fermeture** pour tous les écrans : le jeu paraît cohérent.
- **Rien n'arrive en même temps** : cadre, puis contenu, puis action. Mais tout est là en 0,5 s.
- **Tout gain a un trajet** (du joueur vers le chiffre) et **tout chiffre bouge quand il change**.
- **La fermeture est plus rapide que l'ouverture.**

Ce qui ferait « fait vite » chez nous, en comparaison (d'après `Config/UiMotion`, pas d'après des captures : les captures de revue de `2026-11-15_Revue_UI` ne sont pas sur ce poste) :
- l'ouverture sans dépassement (0,15 s `Quint`) : on la voit à peine ;
- la fermeture qui coupe à 0,4 en 0,07 s, sans élan ;
- les gains d'entraînement qui montent et s'effacent sur place, sans rejoindre le compteur ;
- une seule annonce de gain par seconde sur le tapis.

## 10. Questions pour Clément (choix de jeu)

1. **Gains d'entraînement** : on les fait jaillir du joueur puis rejoindre le compteur du HUD (comme le banc chez eux), ou on garde des gains qui montent sur place (comme leur tapis) ? Et combien par seconde : 1 (aujourd'hui), 4 (leur banc) ou 6-7 (leur tapis) ?
2. **Ouverture et fermeture** : on passe tous nos écrans à « 0,55 → 1,05 → 1 en 0,38 s » et « gonfle puis disparaît en 0,2 s » ? Y a-t-il un écran qui doit rester sec (pendant une poursuite, par exemple) ?
3. **HUD du bas** : il se cache quand un écran s'ouvre, ou il reste ?
4. **Récompense** : rayons + tour sur elle-même pour toutes les récompenses, ou seulement à partir d'une rareté (Épique et plus) ?
5. **Sons** : un clic par bouton et un souffle par ouverture, ou du silence en dehors des gros moments ?
