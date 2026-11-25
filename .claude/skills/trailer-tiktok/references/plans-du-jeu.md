# Les plans du jeu

Repères relevés dans la place DEV le 2026-11-24. Coordonnées en studs (x, y, z). **Relire la place avant de tourner** : la map bouge (`search_game_tree`, tags `NPCStore`, `PlayerPlot`, `ZoneGate`…). Le code retrouve tout par tags et noms (CLAUDE.md) : l'outil aussi, autant que possible.

Colonne « Plan » : le nom du plan dans `tools/clement/trailer/shots.luau` quand il existe déjà.

## Plans déjà écrits (`tools/clement/trailer/shots.luau`)

« Filmé » : tourné et vu en image (plans dans `StealAShop-Art/Trailers/2026-11-24_serie` en 9:16 et `2026-11-24_16x9`). Un nouveau plan s'écrit d'après les repères, puis se repère (planche) avant d'être filmé.

| Plan | Lieu | Mouvement | État |
| --- | --- | --- | --- |
| `vitrine_orbite` | Kiosque, zone 1 | orbite basse + secousse, le casseur entre ensuite | filmé le 2026-11-24 (9:16 et 16:9) |
| `poursuite_arriere` | rue, zone 1 | suivi de face qui recule, vigile décalé | filmé le 2026-11-24 (9:16 et 16:9) |
| `londres_lateral` | Confiserie, zone 2 | travelling droite, coureurs au premier plan | filmé le 2026-11-24 (9:16 et 16:9) |
| `couloir_drone` | entrée du couloir | montée + avancée | filmé le 2026-11-24 (9:16 et 16:9) |
| `z1_superette_avant` | Supérette, zone 1 | travelling avant rapide | filmé le 2026-11-24 (9:16 et 16:9) |
| `z3_tokyo_gauche` | Jeux vidéo, zone 3 | travelling gauche au ras du sol | filmé le 2026-11-24 (9:16 et 16:9) |
| `z4_la_montee` | rue, zone 4 | travelling haut qui révèle | filmé le 2026-11-24 (9:16 et 16:9) |
| `z5_paris_orbite` | Galerie d'art, zone 5 | orbite autour de La Joconde portée | filmé le 2026-11-24 (9:16 et 16:9) |
| `z6_banque_casse` | Banque, zone 6 | travelling avant qui freine + casse à la hache | filmé le 2026-11-24 (9:16 et 16:9) |
| `porte_zone3` | porte de la zone 3 | suivi de dos | filmé le 2026-11-24 (9:16 et 16:9) |
| `colis_ouvert` | rayon du Kiosque | plongée au-dessus du joueur, objet qui sort | filmé, faible : le joueur cache le colis, à repenser |
| `vol_grab` | rayon du Kiosque | travelling droite, `Grab` puis fuite | filmé le 2026-11-24 (9:16 et 16:9) |
| `boutique_exposes` | présentoirs de la boutique 03 | travelling gauche au ras des objets | filmé le 2026-11-24 (9:16 et 16:9) ; Dragon de diamant, Taxi en or et Chihuahua en diamants sont du catalogue v3 (`Features.ItemsV3` encore à false) : à valider avec Clément avant de publier |
| `plaque_argent` | plaque 01 de la boutique 03 | orbite basse + secousse à l'encaissement | filmé le 2026-11-24 (9:16 et 16:9) |
| `tapis_orbite` | tapis de la boutique 03 | orbite serrée | filmé le 2026-11-24 (9:16 et 16:9) |
| `camion_lateral` | rue, zone 3 | travelling gauche, le camion double la caméra | filmé le 2026-11-24 (9:16 et 16:9) |
| `fourgon_arriere` | rue, zone 5 | travelling arrière devant le fourgon, joueurs derrière | filmé le 2026-11-24 (9:16 et 16:9) |
| `fortune_tower` | `FortuneVaultSpawn`, zone 6 | contre-plongée en travelling haut | filmé le 2026-11-24 (9:16 et 16:9) |
| `hub_revelation` | hub, vers le jardin | révélation (montée qui freine) | filmé le 2026-11-24 (9:16 et 16:9) |
| `hub_stands` | stands d'armes et de Robux | travelling droite | filmé le 2026-11-24 (9:16 et 16:9) |
| `boutique_facade` | porte de la boutique 03 | travelling avant | filmé le 2026-11-24 (9:16 et 16:9) |

## Série « teaser » (`tools/clement/trailer/shots_teaser.luau`, fidèle au jeu)

Après le retour de Clément sur la série naturelle (« une idéalisation du jeu »), le 2026-11-25 : 13 plans 9:16 avec les vrais nombres et les vrais écrans, bruitages du jeu posés, sans musique, dans `StealAShop-Art/Trailers/2026-11-25_teaser/` ; plus une vraie partie filmée en Play en 16:9 (`vraie_partie/`).

| Plan | Ce qu'on voit | Caméra |
| --- | --- | --- |
| `t01_vitrine_poings` | trois joueurs aux poings sur le Kiosque : « -1 », barre 15 → 0, SMASHED! | fixe |
| `t02_vitrine_masses` | trois masses sur la Bijouterie : « -40K », 271K → 0, SMASHED! | orbite lente |
| `t03_colis_saut` | le colis Légendaire saute du rayon au sol | fixe |
| `t04_colis_ouverture` | sept actions, « 1 IN N », silhouettes, Trône en or révélé, posé sur la tête | orbite puis recul |
| `t05_run_trone` | sortie avec le trône, RUN!, vigile rouge, « THIEF! » | cadreur |
| `t06_caught` | le vigile rattrape, CAUGHT!, le trône tombe | fixe |
| `t07_boutique_rayon` | rangée d'objets à leur poids, étiquettes $/s, halos | chemin de trois quarts |
| `t08_boutique_fixe` | la boutique pleine en plan large | fixe |
| `t09_encaisse` | plaque d'encaissement, bords verts, l'objet tourne et saute | fixe |
| `t10_porte_40` | la porte d'une boutique « 5/40 » → SMASHED!, BB_ShopInfo | fixe |
| `t11_vol_contour` | « Steal » : La Joconde sur la tête, contour rouge, sirène | cadreur |
| `t12_batte_ejection` | coup de batte : le voleur éjecté à travers la vitre (version DEV) | fixe + secousse |
| `t13_temoin_police` | Galerie d'art : témoin qui photographie, « POLICE IN 8s », « -60K » | fixe |

## Série « plans naturels » (`tools/clement/trailer/shots_naturels.luau`)

Demandée par Clément le 2026-11-25 : des joueurs qui jouent vraiment, caméra à l'épaule. 24 plans filmés le 2026-11-25 en 9:16, un fichier par plan dans `StealAShop-Art/Trailers/2026-11-25_plans_naturels/` (numérotés dans l'ordre de `T.ORDER_NATUREL`, revue des 24 à la suite dans `_revue/`). Troupe partagée (bacon hair ×3, quatre tenues gratuites de Roblox, vigiles des zones 1 à 6, témoins de la zone 1), objets du catalogue actif seulement.

| Plan | Ce qu'on voit | Mouvement |
| --- | --- | --- |
| `n01_casse_trio` | trois joueurs cassent la vitrine du Kiosque ensemble, entrent ; un témoin s'enfuit | cadreur |
| `n02_casse_epaule` | un joueur court vers la Superette, casse, entre ; on le suit dedans | suivi par-dessus l'épaule |
| `n03_casse_masse_zoom` | coup de masse sur la Bijouterie | travelling bas de côté + zoom sur l'impact |
| `n04_casse_vue_dedans` | la hache casse la vitrine vue de l'intérieur, éclats vers nous | travelling arrière |
| `n05_casse_porte_boutique` | un joueur casse la porte vitrée de la boutique 03 | cadreur |
| `n06_rayons_colis` | allée des Jeux vidéo garnie de colis, deux joueurs ouvrent | travelling avant |
| `n07_colis_profil` | colis Légendaire ouvert, le PC gamer sort, pris, emporté | travelling + zoom |
| `n08_sortie_vitrine` | sortie par la vitrine cassée avec la télé géante, vigile derrière | cadreur |
| `n09_vigile_attrape` | Londres : le vigile rattrape et arrête le voleur, la peluche tombe | cadreur + zoom |
| `n10_vigile_plaquage` | LA : plaquage, chute, la couronne roule, le vigile la ramasse | cadreur bas |
| `n11_ejecte_vitrine` | le vigile éjecte le voleur À TRAVERS la vitrine de l'Horlogerie | cadreur + secousse |
| `n12_poursuite_groupe` | trois voleurs chargés et deux vigiles foncent vers nous | cadreur qui recule |
| `n13_vigile_essouffle` | le vigile abandonne, essoufflé ; le voleur file | cadreur |
| `n14_vol_presentoir` | un voleur prend La Joconde dans la boutique 03 et ressort | cadreur dans la boutique |
| `n15_proprio_frappe` | le propriétaire frappe le voleur à la batte, le voleur est projeté | cadreur bas + zoom |
| `n16_poursuite_hub` | le propriétaire poursuit le voleur sur la place, batte en l'air | cadreur qui recule |
| `n17_ejecte_air` | coup de batte : salto arrière du voleur | cadreur de côté |
| `n18_reprise_objet` | le propriétaire lève La Joconde reprise, le voleur sonné | contre-plongée, travelling avant |
| `n19_boutique_allee` | boutique pleine, le propriétaire remonte l'allée | chemin le long de la rangée |
| `n20_boutique_rayon` | les objets d'une rangée défilent | chemin de trois quarts |
| `n21_boutique_encaisse` | encaissement sur la plaque 01, l'objet exposé fait son tour | travelling arrière |
| `n22_foule_couloir` | la rue de la zone 1 pleine de joueurs, une témoin appelle la police | panoramique à l'épaule |
| `n23_zoom_galerie` | trois joueurs armés marchent vers la Galerie d'art, coup de masse | zoom lent + travelling avant |
| `n24_hub_vie` | vie du hub : tapis, passants, un voleur rentre avec son butin | travelling droite |

Limite vue au repérage : une boutique pleine reste clairsemée à l'image (20 présentoirs à 10 studs les uns des autres, comme en jeu) et la rangée du mur z = 64 est cachée par la cabine d'essayage ; filmer la rangée du mur z = 16.

Repères de la boutique 03 (`Hub/Shops/PLOT_Shop_03`, façade vers +x) : porte `PlotDoor` (-161,5 ; 11,5 ; 40), présentoirs `Rayon_01/DisplayStand_01` à `_04` en (-168 ou -178 ; 1,6 ; 16 ou 64), plaques `CollectPad_0n` à 4,9 studs de leur présentoir vers le centre, `RarestDisplay` (-148 ; 0 ; 62,2), tapis (-151,7 ; 0 ; 15,4). Rayons des magasins : `ShelfSlot_0n` à y = 2,8 (Kiosque : `_02` en (65,1 ; 2,8 ; -77,5)). Événements (`Assets/Events`) : pivot au sol, avant vers -z (`CFrame.lookAt(p, p + direction)` les fait rouler dans le bon sens).

## Sommaire

- Géographie
- Hub et jardin
- Les 6 boutiques des joueurs
- Les 6 zones du couloir
- Actions
- Événements
- Plans larges

## Géographie

- **Hub** (zone safe) à l'ouest, en demi-octogone, centre vers (-120, 0, 0). Sortie vers le couloir entre les piliers `GatePost_N`/`GatePost_S` (22, 0, ±67) ; ligne de la zone safe à x = 22.
- **Couloir** vers l'est, le long de l'axe x, de x = 30 à x ≈ 870. Rue de z = -48 à 48 (sol y = 0), trottoirs à y = 0,4 de |z| = 48 à 54, façades à |z| ≈ 54,75, hauteur des façades 29 à 37.
- Magasins PNJ : un au sud (z = -108, vitrine à z = -54,75) et un au nord (z = 108, vitrine à z = 54,75) dans chaque zone. Vitrine `Window` de 18 × 10,5, centre à y = 6.
- Portes de zone (`ZoneGate_1` à `_6`) à x = 30, 118, 230, 368, 530, 718.
- Mur de nuit (`NightWall`) sous le sol à x = 27, prêt à monter de 24 studs.

## Hub et jardin

| Plan | Où | Mise en scène | Mouvement conseillé |
| --- | --- | --- | --- |
| Révélation du hub | Jardin `Hub/Garden` (-127, 2, 0), dalles surélevées `Ambiance/RaisedTiles` | 4 à 6 faux joueurs qui marchent ou courent vers les boutiques | Révélation par-dessus un mur de terre (`Walls/EarthWalls`) ou montée depuis le ras de l'herbe |
| Le jardin de près | Massifs `Garden/Beds` | Un joueur traverse l'herbe | Travelling latéral bas, ou orbite lente |
| Les stands d'achat | Armes (12, 0, 85), auras (12, 0, -85), Robux (12, 0, 117), receleur (12, 0, -117) | Un joueur devant chaque stand | Travelling latéral le long des 4 stands (axe z), à hauteur d'homme |
| Roue et cadeau | Roue `ENV_Hub_Wheel` (21, 0, -160), cadeau `ENV_Hub_FreeGift` (12, 0, 152) | Joueur qui arrive devant | Travelling avant qui freine (outCubic) |
| Classements | Panneaux du fond (-278, 43, ±18), statues dorées (-281, 39, ±45), panneaux de l'entrée (26, 0, 226 et 256) | Aucun joueur, ou un qui regarde | Contre-plongée en travelling haut sur la statue |
| Tapis | 6 tapis `Treadmill` près des boutiques | Joueur qui court sur place : `TreadmillRun` | Orbite serrée (rayon 8 à 10) |

## Les 6 boutiques des joueurs

`Hub/Shops/PLOT_Shop_01` à `_06`, chacune de 65 × 38 × 98, autour du hub : 01 (-42, 0, 217), 02 (-143, 0, 148), 03 (-201, 0, 40), 04 (-201, 0, -40), 05 (-143, 0, -148), 06 (-42, 0, -217).

| Plan | Mise en scène | Mouvement conseillé |
| --- | --- | --- |
| Façade de la boutique | Le propriétaire devant sa porte, deux joueurs qui passent | Travelling avant vers l'entrée, en légère contre-plongée |
| Objets exposés | Copies d'`ITM_` de `ReplicatedStorage/Assets/Items` posées sur les présentoirs (en Edit, les présentoirs sont vides : à garnir dans `_TRAILER`) | Travelling latéral au ras des présentoirs, ou orbite autour de l'objet le plus rare |
| Plaque d'argent | Le joueur marche sur sa plaque ; effets `FX_Collect_Bill` et `FX_Collect_Coin` (`Assets/FX`) émis à son passage | Plan bas qui suit le joueur, secousse courte à l'encaissement |
| Les 6 en enfilade | Toutes les boutiques depuis le centre du hub | Panoramique lent de 90 à 120°, ou plan large drone |

## Les 6 zones du couloir

| Zone (ville) | x | Magasin sud (z = -108) | Magasin nord (z = 108) | Fourchette de rareté |
| --- | --- | --- | --- | --- |
| 1 · Mini Mart | 30 à 118 | `STORE_Z1_Kiosque` (74) | `STORE_Z1_Superette` (74) | lire `Config/Rarities.ZoneOdds` |
| 2 · Londres | 118 à 230 | `STORE_Z2_Confiserie` (168) | `STORE_Z2_MagasinDeJouets` (168) | idem |
| 3 · Tokyo | 230 à 368 | `STORE_Z3_JeuxVideo` (292) | `STORE_Z3_Electronique` (292) | idem |
| 4 · Los Angeles | 368 à 530 | `STORE_Z4_Horlogerie` (442) | `STORE_Z4_Bijouterie` (442) | idem |
| 5 · Paris | 530 à 718 | `STORE_Z5_Antiquaire` (618) | `STORE_Z5_GalerieDArt` (618) | idem |
| 6 · New York | 718 à 870 | `STORE_Z6_SalleDesCoffres` (818) | `STORE_Z6_Banque` (818) | idem |

Pour chaque zone, trois plans types : **la façade** (travelling latéral le long de la rue, plan `londres_lateral`), **la vitrine** (travelling avant au ras du trottoir vers la vitrine, la caméra freine devant), **la porte de zone** (un joueur passe la `ZoneGate`, caméra de dos qui le suit, plan type « course des 6 zones »).

## Actions

| Plan | Mise en scène (Edit) | Mouvement conseillé | État |
| --- | --- | --- | --- |
| Vitrine cassée (`vitrine_orbite`) | Joueur avec `TOOL_Batte` devant la vitrine, animation `HitWindow` ; `T.fx.breakWindow(store)` cache la vitre et lance les éclats de `WindowFractured` vers la rue | Orbite basse de 60 à 70° autour du joueur, secousse à l'impact | écrit |
| Colis ouvert | Copie de `BOX_<Rareté>` (`Assets/Boxes`) sur un rayon ; joueur avec une animation `Unbox_*` (`Hammer`, `Saw`, `Drill`, `Crowbar`, `Kick`) ; à l'ouverture, effets `FX_Unbox_Burst`, `FX_Unbox_Reveal` émis, l'objet `ITM_` monte au-dessus | Travelling avant serré qui freine sur le colis, puis petit travelling haut avec l'objet | écrit (`colis_ouvert`) |
| Vol | Animation `Grab`, puis l'objet passe au-dessus de la tête (`T.fx.carry`) et `CarryRun` | Plan bas de côté, le joueur sort du champ en courant | écrit (`vol_grab`) |
| Poursuite du vigile (`poursuite_arriere`) | Joueur qui porte l'objet (`Run` + `CarryRun`), vigile `Guard_Z<n>` (copie de `Assets/Guards`) qui court derrière | Travelling arrière : la caméra recule devant le joueur, qui gagne sur elle | écrit |
| Plaquage | Le vigile rattrape le joueur : `Catch` (vigile), `Knockdown` puis `GetUp` (joueur) | Plan fixe très court + secousse, ou ralenti | à écrire |
| Objet exposé | Joueur qui pose l'objet : `Place`, l'objet reste sur le présentoir | Travelling avant vers le présentoir | à écrire (présentoirs garnis : `boutique_exposes`) |
| Entraînement | `TreadmillRun` sur un tapis | Orbite serrée | écrit (`tapis_orbite`) |

Animations des joueurs : `ReplicatedStorage/Assets/Animations/Player/<Nom>` (liste à jour dans `src/shared/Contract/Animations.luau`). Courir et marcher : animations R15 de base de Roblox (`Run`, `Walk`, `Idle` dans l'outil). Vigiles : dossier `Animations` de leur modèle (`Idle`, `Walk`, `Run`, `Sprint`, `Catch`, `Tired`, `PickUp`).

## Événements

| Plan | Où | Mise en scène | Mouvement conseillé |
| --- | --- | --- | --- |
| Camion | Rue, un `TruckSpawn` par zone, sur l'axe (x de la zone, 0, 0) | Copie d'`ENV_Event_Truck_<Rareté>` (`Assets/Events`) qui roule sur l'axe ; `FX_TruckDust` ; à l'explosion `FX_TruckExplosion` | Travelling latéral au ras de la roue, ou camion qui passe devant une caméra fixe basse puis panoramique |
| Fourgon blindé | Rue du couloir | Copie d'`ENV_Event_ArmoredVan` (15,5 × 15,9 × 32) qui roule, joueurs qui le poursuivent | Travelling arrière devant le fourgon |
| Fortune Tower | `Zone_6/FortuneVaultSpawn` (856, 0, 0) | Copie d'`ENV_Event_FortuneVault` | Contre-plongée en travelling haut, révélation par-dessus la foule |
| Nuit | Entrée du couloir, mur `Map/Entry/NightWall` (x = 27) | Le mur monte (copie dans `_TRAILER`, l'original ne bouge pas), vigiles de nuit (`NightGuard`) aux points `NightPatrol_Z<n>_A/B` | Plan large en plongée (cadrage C de « la nuit tombe ») |

**La nuit demande un Play** : le ciel, la lumière et les néons `NightLight` se changent dans `Lighting` (à Clément), donc on ne les touche pas en Edit. La méthode qui a marché le 2026-11-20 (Play, caméra `Scriptable` côté Client, `NightSkipTo`, `video_capture`) est dans `tools/clement/video/nuit_qui_tombe.luau` (branche principale) : la suivre, avec l'accord de Clément pour le Play.

Les événements réels (camion, fourgon, Fortune Tower) se déclenchent aussi en Play par les attributs de test de la liaison ; en Edit, on les met en scène avec des copies des modèles, ce qui suffit pour un trailer.

## Plans larges

| Plan | Où | Mouvement conseillé |
| --- | --- | --- |
| Le couloir en enfilade (`couloir_drone`) | De l'entrée (x ≈ 0) vers l'est, 3 joueurs qui courent | Montée et avancée (travelling haut + avant), 4 s |
| Le hub vu du ciel | Au-dessus du jardin, vers (-120, 0, 0) | Plan large qui dérive, ou orbite haute (rayon 120 à 160, hauteur 60 à 90) |
| La skyline | `Map/Skyline` derrière le couloir | Panoramique lent depuis un toit de la zone 6 |
| Boucle début-fin | La même vue plongeante du couloir au début et à la fin du trailer | Plan large identique pour que la vidéo boucle |
