# « La nuit tombe » : découpage

Teaser TikTok, vertical 1080 × 1920, 30 i/s, **12 s**, un seul plan, sans musique (Clément l'ajoute dans TikTok).
D'après la fiche `references/2026-11-20_ref5_nuit-qui-tombe.md` et les points communs des références (ref4).

L'idée : un accéléré sur l'entrée du couloir, de la fin d'après-midi à la nuit. Vers 6 s, quand le ciel vire au violet saturé, le couloir se ferme pour la nuit.

## Ce que le jeu fait vraiment la nuit (vérifié dans `src/`)

- **Le mur de nuit monte du sol** (`Workspace/Map/Entry/NightWall`, `RiseHeight = 24`, montée en 3 s, `NightCycleService`). Il ne descend pas : la vidéo le montre comme dans le jeu.
- **Les lumières taggées `NightLight` s'allument et passent en Neon** (`SkyController`) : fenêtres de la skyline, cadres des façades.
- **Les vigiles de nuit apparaissent** sur les points `NightPatrol`, 2 par zone (`GuardService.StartNightPatrol`).
- **Les rideaux (`Shutter`) ne tombent pas à la tombée de la nuit** : ils ne tombent qu'à la fermeture d'un magasin braqué. La fiche les prévoit, mais les montrer reviendrait à montrer quelque chose qui n'est pas dans le jeu. Je les laisse de côté, sauf si Clément veut cet effet.
- Le ciel de nuit du jeu est bleu (`Night.Sky`). Le violet saturé se fait au montage et par une `ColorCorrection` locale le temps de la capture.

## Le plan

| Temps | Ce qu'on voit | Caméra | Texte | Son |
| --- | --- | --- | --- | --- |
| 0 à 2 s | Fin d'après-midi (ClockTime 15 → 17,5) : lumière dorée, les ombres s'allongent. Le temps file dès la 1re image. | Cadrage choisi ; avancée lente et continue sur tout le plan (environ 8 studs) | « COMING SOON », petit, blanc avec ombre, au tiers haut, du début à la fin | Aucun (musique dans TikTok) |
| 2 à 4 s | Coucher du soleil (17,5 → 18,5) : ciel orange et rouge, comme l'alerte du jeu | Avancée | idem | |
| 4 à 6 s | Heure bleue (18,5 → 20) : le ciel fonce, les fenêtres de la skyline s'allument | Avancée | idem | |
| **6 à 7 s** | **Temps fort** : le ciel vire au violet saturé (#5B2BFF environ), **le mur de nuit monte et ferme le couloir**, les néons des façades s'allument | Avancée, petite secousse quand le mur arrive en haut | idem | |
| 7 à 11 s | Nuit violette : les vigiles de nuit en ronde avec leur lampe, les lumières chaudes ressortent sur le violet | Avancée qui ralentit | idem | |
| 11 à 12 s | Image tenue, prête à boucler | Arrêt | idem | |

## Cadrages candidats (captures en Edit, de jour)

Les captures sont tournées puis remises à l'endroit : voir « Résolution ».

| | Où | Pour | Contre |
| --- | --- | --- | --- |
| **A** `cadrages/cadrage_A.jpg` | Dans l'axe du couloir, depuis la zone safe, à hauteur d'homme | Symétrique, le mur monte face à la caméra, le plus lisible | Le sol bleu de la zone safe prend le bas ; une fois le mur levé, on ne voit plus le couloir |
| **C** `cadrages/cadrage_C.jpg` | En hauteur au-dessus de la zone safe, en plongée sur la rue | On voit le mur, la rue derrière, les vigiles et toute la skyline en même temps | Plongée et non contre-plongée comme la référence |
| **D** `cadrages/cadrage_D.jpg` | En contre-plongée de biais, depuis le coin de la zone safe | Le plus proche de la référence : beaucoup de ciel, le Mini Mart et la tour au premier plan | Le mur est vu de biais, le couloir est moins lisible |

Ma préférence : **C**, parce que c'est le seul cadrage où l'on voit en même temps le ciel qui change, le mur qui ferme la rue et les vigiles qui arrivent.

## Résolution

Le viewport de Studio fait 1209 × 642. Un recadrage 9:16 direct ne garderait que 361 × 642 px, agrandis 3 fois : trop flou.
Solution retenue : **la caméra est tournée de 90° (roulis)**, ce qui donne des images de 642 × 1209, remises debout au montage puis recadrées en 642 × 1141 et agrandies 1,68 fois jusqu'à 1080 × 1920 (lanczos et léger renforcement de la netteté). C'est propre sur un téléphone, mais un peu doux.
Pour mieux faire : agrandir la fenêtre de Studio avant le tournage. La taille des captures suit celle du viewport : avec un viewport de 1900 × 1080, on aurait du vrai 1080 × 1920.

## Tournage (fait le 2026-11-20)

Clément a choisi les trois cadrages : une version par cadrage.

- Une prise en temps réel par cadrage, en Play, enregistrée avec `video_capture` (1568 × 640, environ 9,5 i/s). Le tournage image par image a été abandonné : trop lent.
- Côté client, un `BindToRenderStep` pose à chaque image `ClockTime`, la lumière, une `ColorCorrection` locale, l'`Atmosphere` et la caméra (en `Scriptable`, avec un roulis de 90°, une avancée lente et une petite secousse quand le mur arrive en haut). L'UI est cachée sur la copie du joueur (`PlayerGui`, à chaque image) et le perso est rendu invisible. `StarterGui` n'est pas touché.
- Côté serveur, l'attribut de test `NightSkipTo = "Night 120"` à 4,3 s lance la vraie nuit : le mur monte (4,3 à 7,3 s), les néons `NightLight` s'allument et le panneau « CLOSED AT NIGHT » apparaît. `NightSkipTo = "Day"` entre deux prises.
- Les vigiles de nuit ne se voient pas dans ces cadrages : ils sont derrière le mur.
- `SetCore("TopbarEnabled", false)` a donné une prise grise : il est retiré du script.
- Luau : `tools/clement/video/nuit_qui_tombe.luau`. Montage : `tools/clement/video/nuit_qui_tombe_montage.sh`. Le test Play a été arrêté, rien n'est enregistré, et la place en Edit est revenue à son état d'avant.

## Montage (v1)

ffmpeg : début à 1,4 s dans chaque prise, 12 s ; rotation, recadrage 640 × 1138 en haut de l'image (le sol est coupé) ; passage à 30 i/s par fondu entre images (l'interpolation par mouvement faisait une lune fantôme) ; agrandissement lanczos en 1080 × 1920 et léger renforcement de la netteté ; à partir de 2,6 s, virage au violet (teinte +34°, saturation, gamma) ; ciel étoilé en fondu à 3 s et deux étoiles filantes (7,7 s et 10,1 s) ; « C O M I N G   S O O N » en Futura Bold blanc avec ombre, au tiers haut (y = 560). Pas de piste son : la prise contenait le son du jeu, que Clément peut demander s'il le veut.

| Fichier | Taille | Avis |
| --- | --- | --- |
| `nuit-qui-tombe_C_v1.mp4` et `miniature_C.jpg` | 6,5 Mo | La meilleure : rue, néons, mur et skyline restent lisibles de nuit |
| `nuit-qui-tombe_A_v1.mp4` et `miniature_A.jpg` | 4,6 Mo | Une fois le mur levé, il remplit le bas : un aplat violet sous un ciel noir |
| `nuit-qui-tombe_D_v1.mp4` et `miniature_D.jpg` | 4,6 Mo | Pareil que A, avec le mur de biais |

Limites : sur la lune, qui bouge vite, le fondu entre images laisse par moments deux lunes. Le jour ne dure qu'environ 1,5 s avant le coucher : le soleil passe sous l'horizon vers 2,2 s.

## v2 (2026-11-21) : prise C au ralenti, avec les lampes torches

Clément a trouvé la v1 saccadée, comme à 8 i/s : `video_capture` n'en enregistrait que 9,5 environ.

- **Ralenti ×4** : le même déroulé est joué 4 fois plus lentement, puis accéléré au montage. `video_capture` s'arrête à 30 s : la prise est donc faite en deux parties (t 0 à 7,2 s, puis 5,0 à 12,5 s), calées par PSNR sur la zone du mur et raccordées à t = 5,4 s, avant l'apparition des vigiles. Environ 19,6 i/s enregistrés × 4, soit des vraies images à 30 i/s.
- **Mur, néons et vigiles pilotés côté client** au rythme de la vidéo. La vraie nuit est lancée avant la prise, avec le perso ancré sous la rue côté couloir, pour garder le passage de nuit. Sans cela, la nuit s'arrêterait après 15 s (`EmptyCorridorRemaining`). Les néons s'allument en cascade en partant du mur. Les vigiles de nuit apparaissent à 5,5 s.
- **Lampes torches** : le modèle `NightGuard` de Clément a déjà `ACC_Nuit_LampeTorche` (une `SpotLight` dans `Lens`). Une `SpotLight` n'éclaire que les surfaces : pour la vidéo, j'ai ajouté côté client un `Beam` (faisceau visible, 26 studs) à chaque `Lens` et poussé la `SpotLight` (Brightness 4, Range 40). Rien n'est changé dans le modèle. Si Clément veut ce faisceau dans le jeu, c'est à ajouter à son modèle.
- Coucher plus étalé (ClockTime 17 à 18,3 entre 1,2 et 3,6 s) ; virage au violet à partir de 3,0 s ; caméra qui avance de 28 studs au lieu de 12.
- Rendu : `nuit-qui-tombe_C_v2.mp4` (10,3 Mo) et `miniature_C_v2.jpg`. On voit les faisceaux dans la rue, derrière le mur ; à cette distance, les vigiles restent petits.

## Variantes (2026-11-21), dans `variantes/`

Toutes viennent de la prise C v2, sans nouveau tournage. Script : `tools/clement/video/nuit_qui_tombe_variantes.sh`. Chaque vidéo a sa miniature (`.jpg` du même nom).

| Fichier | Durée | Ce qui change |
| --- | --- | --- |
| `nqt_var1_slam.mp4` | 12 s | Pas de texte au début ; quand le mur arrive en haut (7,3 s), flash blanc et « COMING SOON » en gros qui claque |
| `nqt_var2_decompte.mp4` | 12 s | Décompte du jeu « NIGHT FALLS IN 3, 2, 1 » pendant le coucher (texte d'alerte du jeu, en orange), puis le même claquement |
| `nqt_var3_ralenti.mp4` | 14 s | Rampe de vitesse : montée du mur en ralenti ×2 (vraies images de la prise ×4), puis claquement à 10,3 s |
| `nqt_var4_rose.mp4` | 12 s | Nuit rose néon au lieu du violet, petit texte fixe |
| `nqt_var5_courte.mp4` | 8 s | Commence au coucher du soleil, claquement à 5,5 s : la plus courte |
| `nqt_var6_boucle.mp4` | 12 s | Petit texte fixe ; la fin se fond en 0,6 s dans la 1re image (le jour revient), pour une boucle sans coupure sur TikTok |

Chaque fichier fait de 7,5 à 12 Mo, et le dossier `variantes/` environ 62 Mo en tout.

## Nouveaux plans (2026-11-21) et versions à plusieurs plans

Trois plans tournés en Play, avec le même Luau (cadrages `P1`, `P2`, `P3`) :

| Plan | Où | Prise |
| --- | --- | --- |
| P1, la rue | Au ras du sol dans le couloir, devant le Kiosque, vers les façades et la tour de l'horloge | Ralenti ×4, t 2,8 à 9,6 s : coucher, néons en cascade, puis un vigile qui traverse la rue avec sa lampe |
| P2, le mur côté couloir | Dans la rue, face au mur | Ralenti ×4, t 2,8 à 9,6 s : le mur sort du sol et cache la zone safe ; dessus, « NIGHT GUARDS ARE OUT! BACK TO THE SAFE ZONE » (le panneau côté couloir du modèle) dans le faisceau d'une lampe |
| P3, un vigile de près | Caméra basse qui suit un vigile de nuit de la zone 1 | Temps réel, de nuit, 15 s. `video_capture` n'en a gardé que 8,7 i/s : passage à 30 i/s par fondu (léger flou de mouvement ; l'interpolation par mouvement déformait le vigile). Les panneaux d'info des magasins (« Kiosk, Speed, Strength ») sont cachés |

| Fichier | Durée | Montage |
| --- | --- | --- |
| `variantes/nqt_var7_rafale.mp4` | 12,6 s | 8 plans de 1,2 à 1,8 s, dans l'ordre de l'histoire : C (jour doré), P1 (coucher, néons), C (le mur commence), P2 (le mur arrive en haut : flash et « COMING SOON » à 6,1 s), C (nuit), P3 (vigile), P1 (faisceau dans la rue), C (fin large, étoile filante) |
| `variantes/nqt_var8_vigiles.mp4` | 9,1 s | 5 plans : P2 (le mur monte côté couloir, claquement à 3,0 s), P3, P1, P3, C |

Script : `tools/clement/video/nuit_qui_tombe_rafale.sh` (profil `rafale` ou `vigiles`). Chaque plan est étalonné d'après son heure dans l'histoire, pour que la couleur suive d'un plan à l'autre.
