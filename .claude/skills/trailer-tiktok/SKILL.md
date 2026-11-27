---
name: trailer-tiktok
description: Tourne et monte des plans de caméra de Steal a Shop pour des trailers TikTok, Shorts ou Reels verticaux (9:16) - travellings avant, arrière, haut, bas, gauche et droite, orbites, panoramiques, révélations et plans larges du hub, du jardin, des 6 boutiques, des 6 zones du couloir, des actions (vitrine cassée, colis, vol, poursuite, objet exposé, plaque d'argent) et des événements (camion, fourgon blindé, Fortune Tower, nuit), avec de faux joueurs bacon hair animés. Caméra scriptée en Edit dans Roblox Studio par le MCP, capture de la vue 3D, recadrage et montage ffmpeg. À utiliser dès que Clément demande des plans, un trailer, une bande-annonce, une vidéo pour les réseaux ou de « refaire des plans comme les TikTok ».
---

# Trailer TikTok : tourner des plans du jeu

Clément veut des plans de caméra du jeu pour des trailers sur les réseaux, avec des joueurs qui ont l'air de jouer (ils cassent des vitres, volent, se font poursuivre) pendant que la caméra bouge. Ce skill dit comment choisir, tourner et exporter ces plans. Le montage complet d'une vidéo (textes, bruitages, ordre des plans) se fait ensuite avec l'agent `video-tiktok`, d'après les fiches de `docs/claude/video/references/`. Nos vidéos n'ont pas de musique : bruitages du jeu seuls. Clément pose lui-même sa musique sur TikTok.

Réponds en français. Textes à l'écran en anglais (public Roblox mondial).

## Fichiers

| Fichier | Rôle |
| --- | --- |
| [references/vrai-jeu.md](references/vrai-jeu.md) | **À lire d'abord** : ce que voit et entend un vrai joueur (vitrine en plusieurs coups, colis au sol, étiquettes, tailles, poursuite, sons par moment) |
| [references/mouvements.md](references/mouvements.md) | Catalogue des mouvements : durée, courbe, cadrage 9:16, code `T.moves` |
| [references/plans-du-jeu.md](references/plans-du-jeu.md) | Liste des plans du jeu, avec leurs repères (coordonnées, tags) et ce qu'il faut mettre en scène |
| [references/tournage-export.md](references/tournage-export.md) | Méthode pas à pas : préparer, filmer, monter, vérifier, nettoyer ; pannes connues |
| `tools/clement/trailer/trailer_lib.luau` | L'outil Studio : `_G.Trailer` (mouvements, faux joueurs, effets, moteur d'un plan) |
| `tools/clement/trailer/shots.luau` | Les plans déjà écrits (`T.shots.<nom>`), modèles à copier |
| `tools/clement/trailer/shots_naturels.luau` | La série « plans naturels » (24 plans de jeu, caméra à l'épaule), sa troupe et ses aides (`cast`, `strike`, `broken`, `fullShop`) |
| `tools/clement/trailer/trailer_real.luau` | **La couche « vrai jeu »** (`T.real`) : objets à la taille de leur poids avec étiquette, halo et contour, vitrine en plusieurs coups, colis au sol et ses actions, RUN!/CAUGHT!/SMASHED!, journal des bruitages |
| `tools/clement/trailer/shots_teaser.luau` | La série teaser (13 plans fidèles au jeu), sur la couche vrai jeu |
| [scripts/mix_sfx.py](scripts/mix_sfx.py) | Pose les bruitages de la banque sur les plans découpés, d'après le journal du tournage |
| `tools/clement/trailer/make_shirt_baconhair.py` | Chemise du bacon hair (gabarit Roblox, chargé en local) |
| [scripts/find_viewport.py](scripts/find_viewport.py) | Trouve la vue 3D de Studio sur l'écran |
| [scripts/vue_libre.ps1](scripts/vue_libre.ps1) | Vérifie qu'aucune fenêtre ne couvre la vue 3D (sans capture) |
| [scripts/capture.sh](scripts/capture.sh) | Filme la vue 3D à 60 i/s |
| [scripts/planche_reperage.py](scripts/planche_reperage.py) | Planche de repérage : une image par plan |
| [scripts/montage_plan.sh](scripts/montage_plan.sh) | Prise d'un plan → 1080 × 1920 à 30 i/s, synchro, ralenti, étalonnage |
| [scripts/decoupe_lot.py](scripts/decoupe_lot.py) | Prise de plusieurs plans (`T.batch`) → un fichier par plan, en 9:16 ou 16:9 |
| [scripts/banque_sons.py](scripts/banque_sons.py) | Banque de bruitages : découpe les prises son d'un Play en un `<Nom>.wav` par son |

Les plans tournés vont dans `C:\Users\Charment\Documents\StealAShop-Art\Trailers\<date>_<sujet>\` (hors Git) ; les prises brutes restent dans le scratchpad.

## Règles fixes

- **Les plans mis en scène se tournent en Edit** : aucun Play n'est lancé ni arrêté sans l'accord de Clément (la place DEV est partagée). Le moteur anime les persos avec `Animator:StepAnimations`, déplace la caméra à chaque image et remet la vue de Clément à la fin. Un Play (avec son accord) sert à observer le vrai jeu, à filmer une vraie partie et à enregistrer les sons : la capture vidéo du MCP enregistre l'image ET le son du jeu, 30 s au plus par prise.
- **Montrer le vrai jeu** : relire [references/vrai-jeu.md](references/vrai-jeu.md) avant d'écrire un plan (étiquettes, tailles, vitrine en plusieurs coups, colis au sol, interface de poursuite, sons).
- **Demande la vue 3D à Clément avant de filmer** : pendant une prise, personne ne touche à Studio et la fenêtre reste devant. Dis-lui combien de temps (environ 30 s par plan, 10 à 15 min pour 4 plans avec les repérages).
- **Aucun script laissé dans le jeu** : l'outil est du Luau envoyé par `execute_luau`. Tout ce qu'il crée va dans `Workspace/_TRAILER`, vidé par `T.clear()` à la fin du tournage, puis `save_place`.
- **Rien n'est modifié hors de `_TRAILER`** : les vitres cassées sont cachées par `LocalTransparencyModifier` (jamais enregistré) ; `StarterGui.ShowDevelopmentGui`, la sélection et la caméra sont remis par `T.stop()`. Ne touche ni à `Lighting`, ni à la Map, ni à `StarterGui`.
- **Ne montre rien qui n'existe pas dans le jeu.** On montre tout le jeu DEV, y compris ce qui est éteint en PROD. Rien de ce qui est éteint partout (`Features.* = false` en DEV aussi ; liaison, `src/shared/Config`) ne se montre. Les chiffres à l'écran (raretés, chances, prix) se lisent dans `Config`, jamais inventés. Un modèle présent dans `Assets/Items` n'est pas forcément au catalogue actif : vérifier son `Id` dans `Config/Items` (catalogue v2, ou v3 derrière `Features.ItemsV3`).
- **On ne copie jamais un autre jeu** : des références on reprend la technique (mouvement, durée, rythme), jamais leurs images, leurs textes ni leurs sons.
- **Aucune coupe sous 1 s** (règle de Clément). Les références coupent plus court : on ne les suit pas sur ce point.
- **Pas de musique** dans nos fichiers, même celle du jeu (`MUS_*`) : bruitages du jeu seuls, dès la première image, sans trou sous −40 dB.
- **Personne de couché, personne qui traverse une vitre** : une capture se coupe sur « CAUGHT! », le personnage debout.
- **Ne publie rien** : Clément poste lui-même.
- Enregistre la place (`save_place`) à la fin, une fois `_TRAILER` vidé.

## Déroulé

0. **Écrire la vidéo en une phrase**, comme un joueur la raconterait (« tu casses une vitrine, tu voles l'objet du colis et tu sèmes le vigile »), et choisir son modèle : ordre chronologique, « expliquer le jeu » (un plan long), « In a World… » (le monde, le héros, le problème, la riposte, les obstacles), ou clip (TikTok où Clément pose sa musique). Si la vidéo ne se raconte pas ainsi, on la recoupe.
1. **Choisir les plans** dans [references/plans-du-jeu.md](references/plans-du-jeu.md), et pour chacun un mouvement dans [references/mouvements.md](references/mouvements.md). Un plan = un lieu + un mouvement + une action. Propose la liste à Clément (3 à 5 plans pour un essai).
2. **Charger l'outil** : envoyer `trailer_lib.luau` puis `shots.luau` par `execute_luau` (Edit). Ajouter les nouveaux plans dans `shots.luau` sur le modèle des existants.
3. **Repérer** : une image de la première vue de chaque plan (`T.still`) sur une planche (`planche_reperage.py`), montrée à Clément ; corriger les cadrages ratés sur une image fixe avant de filmer. Sur chaque planche : une grille 3 × 3 et une version floue (`boxblur=10`). Si l'action ne se lit plus floue, le plan est trop chargé.
4. **Filmer** : agrandir d'abord la vue 3D (panneaux fermés), au moins 1080 px de haut pour le 9:16, puisque la hauteur de la vue devient la largeur de l'image. Puis `vue_libre.ps1` (rien devant Studio) → `T.prepare(premier plan)` (noir tenu) → `capture.sh` en arrière-plan (prises + 25 s) → vérifier que le `.mkv` existe → `T.go()` pour un plan, ou `T.batch({…})` pour un lot de 5 à 10. Le moteur fait 1,5 s de noir, joue le plan au ralenti (`slow`), refait du noir, puis remet tout.
5. **Monter** : `montage_plan.sh` (un plan) ou `decoupe_lot.py` (un lot), puis regarder les images et les vidéos. Écouter de 0 s à la fin (aucun trou sous −40 dB) et lire chaque mot seul, sans l'image d'avant : s'il peut se comprendre de travers, le changer.
6. **Montrer à Clément** (SendUserFile), corriger, refilmer ce qui ne va pas.
7. **Nettoyer** : `T.clear()`, vérifier que `Workspace/_TRAILER` n'existe plus, `save_place`.

Le détail de chaque étape, les commandes exactes et les pannes connues sont dans [references/tournage-export.md](references/tournage-export.md).

## Ce qui fait un bon plan (d'après les références de Clément)

- **Un plan bouge toujours** : jamais de caméra fixe, sauf un plan tenu de fin, ou un jump cut (même cadre exact, ou même trajectoire rejouée à l'identique).
- **Naturel** (demande de Clément du 2026-11-25) : caméra à l'épaule (`M.handheld`) et cadreur qui suit l'action (`M.operator`) plutôt qu'un mouvement géométrique ; des joueurs qui jouent à plusieurs (casse à trois, vol entre joueurs, vigile qui attrape ou éjecte, propriétaire qui frappe le voleur).
- **1 à 2 s par plan au montage, jamais moins d'1 s.** Un plan long de 3 à 5 s montre une action entière (les coups, le colis qui s'ouvre, l'objet pris). Poser d'abord, accélérer ensuite : 2 s pour la casse et le colis, 1 s dans la poursuite. Pas de rafale : la vitesse se dit par contraste avec le plan long. On tourne 3 à 4 s pour avoir le choix.
- **Accroche dès la première image, avec son** : le moment le plus fort (vitrine qui explose, colis rare, poursuite). Ni titre, ni logo, ni décor de loin avant ; le titre vient après, vers 2 s. Le genre se comprend tout de suite (3e personne, perso Roblox, magasin).
- **Près du sol et grand angle** pour que les objets paraissent énormes ; plans larges en hauteur pour situer.
- **Des joueurs à l'image** dans la plupart des plans, qui font quelque chose (courir, casser, porter, fuir).
- **Couleurs saturées**, lumière flatteuse ; l'étalonnage du montage pousse un peu saturation et contraste.
- **Sujet dans la zone sûre** du 9:16 : rien d'important dans le haut (15 %) ni le bas (20 %) de l'image, où TikTok pose ses textes et boutons.
- **Peu de mots** : 5 ou 6 pour 30 s, 6 au plus par ligne, chacun compréhensible seul, posés à côté du sujet, jamais dessus. En TikTok, un titre fixe en haut (vers 20 à 30 % de la hauteur) dès la première image ; ligne 1 = le sujet, ligne 2 = le contraste.
- **Les coupes** : du large au serré pour la casse (rue, façade, masse sur la vitre) ; flow cut (même sens, même vitesse) entre la casse et la fuite ; match cut (même forme au même endroit) pour les révélations ; smash cut sur un changement de son pour les gags.
- **TikTok** : 7 à 15 s, tout lisible avant 10 s. Séries (« PART n/6 », même gabarit refait à l'identique), cliffhanger (la menace approche, coupe juste avant, personnage debout), chiffre qui monte (chiffres de `Config` ou de la prise), boucle sans carte de fin. Le nom « Steal a Shop » dans le dernier plan ou la légende.
- **La fin** prend le plus long temps : 4 à 6 s en 16:9, 2 s de carte en TikTok (ou une boucle sans carte).
