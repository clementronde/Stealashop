# Benchmark du genre « Steal a … » — ce que Steal a Shop doit en retenir

2026-11-17, demande de Clément. Trois recherches croisées : jeux de référence (web), rétention et algorithme Roblox 2026 (web), état de notre design (doc, liaison, `src/`). Les chiffres viennent surtout de guides de fans et de sites de stats (RoWatcher, ROLearn, Profitable) : ordres de grandeur, pas vérité. Aucune donnée publique J1/J7 n'existe pour ces jeux. Aucune valeur de jeu n'est fixée ici : ce sont des pistes, les valeurs restent celles de la Partie 1 et de `Config`.

## 1. Les jeux étudiés en une ligne

| Jeu | Sortie | Pic CCU | Ce qu'il nous apprend |
| --- | --- | --- | --- |
| Steal a Brainrot (SAB) | mai 2025 | ≈ 25 M (oct. 2025), ≈ 114-224 k de moyenne en 2026 | La référence : bases face à face, $/s écrit partout, verrou court à relancer, vol ralenti et rendu en un coup |
| Grow a Garden (1 et 2) | 2025 / mai 2026 | ≈ 21-22 M (2025) | Stock renouvelé toutes les 5 min, pousse hors ligne ; GaG 2 : **on ne vole que la nuit** (2 min sur 10), comme notre cycle |
| Break and Steal an Egg | 5 sept. 2026 | 1,3 M (18/10/2026), ≈ 100 k début nov. | Le plus proche de nous : vitesse pour ouvrir les zones, casse, fuite devant des gardes PNJ |
| Steal an Egg | juillet 2026 | chiffres contradictoires | Gain selon taille (kg) et mutation, nids qui se remplissent toutes les 5 min, Secret annoncé au chat |
| Escape Tsunami For Brainrots | déc. 2025 | ≈ 5 M, retombé à ≈ 164 k en 3 mois | Le genre monte très vite et retombe aussi vite sans contenu prêt |

## 2. Comment marche le genre

1. **La richesse se voit.** Au-dessus de chaque objet : nom, rareté en couleur, mutation, $/s. Les bases se font face autour d'un couloir commun : on voit d'un coup d'œil qui vaut la peine d'être volé.
2. **La base est ouverte, la protection est courte.** SAB : rez-de-chaussée ouvert, lasers à la porte quand on verrouille, verrou de 60 s (+10 s par renaissance, +10 s VIP), **à relancer à la main** ; l'oubli est la première cause de vol. Les rôdeurs attendent devant : la fenêtre prévisible crée la tension, c'est voulu.
3. **Le transport est le moment fort.** Le voleur est ralenti, ses objets sont coupés, le propriétaire est alerté, un seul coup fait lâcher le butin, on ne peut pas se téléporter avec, un tiers peut l'intercepter.
4. **Anti-frustration.** Batte gratuite, objet rendu au premier coup, butin qui tombe au sol plutôt que de disparaître (SAB, janvier 2026, voté par 67 % des joueurs), serveurs privés sûrs. Le schéma d'abandon type : « j'arrive, j'achète cher, on me vole tout de suite, je quitte ».
5. **Urgence permanente.** Stock qui tourne toutes les 5 min, apparitions garanties chronométrées (SAB : un Légendaire ≈ toutes les 5 min, un Mythique ≈ toutes les 15 min), Secret annoncé à tout le serveur, chance du serveur achetable.
6. **Collection longue.** Mutations multiplicatrices (SAB : Or ×1,25, Diamant ×1,5, puis ×10 à ×13 en événement), traits cumulables, fusion, index dont la récompense est **visible sur la base** (skin coloré).
7. **Renaissance.** Étages et emplacements en plus, verrou plus long, multiplicateur, équipements de défense.
8. **Rendez-vous du samedi.** SAB : samedi 15 h ET (21 h Paris), admin abuse de 30-45 min. GaG : samedi 10 h ET (16 h Paris). Le pic du mois vaut 9 à 22 fois la moyenne : la vie du jeu se fait le samedi.
9. **Monétisation.** Les plus gros prix sont sur la **chance du serveur** (×2 à ×8, jusqu'à 2 999 R$) et les **Lucky Blocks** (caisses). Puis x2 Money (≈ 299-399 R$), VIP, packs d'argent, vitesse, armes, tours de roue.

## 3. Les objets animés : faut-il le faire ?

- Les brainrots dansent parce que **ce sont des personnages-mèmes** : l'animation fait partie du mème. Aucune étude ne mesure l'effet de l'animation seule.
- **Chez nous, c'est déjà fait** : `ItemIdleController` fait tourner (`Spin`, un tour en 5 s) ou flotter (`Bob`) les objets exposés, et anime les pièces `Spin_*` et `Wave_*` (`Config/ItemIdle.luau`). Pas besoin de rig ni d'animation de Clément par objet.
- Ce qui compense vraiment des objets inanimés, par ordre d'effet supposé :
  1. **Mutations visibles** sur le modèle (matière Or, Diamant, Arc-en-ciel) ;
  2. **Halo et particules de rareté** lisibles de loin (fait, `RarityHalo`) ;
  3. rotation et flottement (fait) ;
  4. un petit son de rareté quand on s'approche ;
  5. une réaction de l'objet quand on le vole ;
  6. **des objets drôles et absurdes dans les hautes raretés** : le produit doit faire rire, pas être réaliste.

## 4. Eux et nous

| Point | Le genre | Steal a Shop aujourd'hui | Écart |
| --- | --- | --- | --- |
| Visibilité des bases | Bases face à face, $/s partout | 8 boutiques en arc sur la Place du Mall ; `BB_Item` au-dessus de chaque objet ; `BB_ShopInfo` (nom, $/s, PV de la porte, état) visible à 180 studs ; classements du hub | Murs et vitrine cachent l'intérieur ; pas de photo du propriétaire ni de meilleur objet sur le panneau |
| Taille des objets | Les gros débordent (SAB), le poids compte (Egg) | **Aucune normalisation** : chaque `ITM_` garde sa taille ; `ScaleTo` seulement pour les mutations de taille | À faire : réduire chaque objet à sa place ; le socle `RarestDisplay` devant la boutique garde la vraie taille (c'est déjà le « podium ») |
| Animation | Personnages qui dansent | Spin / Bob déjà codés | Suffisant ; ajouter mutations visibles et objets absurdes |
| Entrée chez l'autre | On entre si ce n'est pas verrouillé | Porte en 40 coups, puis 10 s pour prendre | Plus lent que le genre : à surveiller au test |
| Verrou | 60 s à relancer, +renaissance, +VIP | 30 / 45 / 60 s, recharge 120 s, invite E sur sa porte | Comparable |
| Fuite | Ralenti, alerte, rendu en un coup | Vitesse fixe 16, alerte, batte, +25 % pour la victime, rendu si frappé | Comparable |
| Anti-frustration | Butin au sol, batte gratuite, serveur privé | Rien pour la victime ; « Revenge » seulement en Robux, pas codé ; bouclier débutant réduit au colis porté (L-115) | **Manque principal** |
| Urgence | Stock toutes les 5 min, garanties chronométrées, Secret annoncé | Nuit de 2 min toutes les 10 min qui remplit les rayons | Il manque l'annonce serveur des colis rares |
| Collection | Mutations ×1,25 à ×13, index visible sur la base | Mutations de taille, index avec récompense de zone (L-183) | Mutations de matière à ajouter ; récompense d'index visible sur la boutique |
| Renaissance | Étages, emplacements, verrou plus long | Codée mais coupée (`Features.Rebirth = false`) | À allumer au lancement |
| Hors ligne | ≈ 50 % (SAB, non officiel) | 100 %, 4 h max | Plus généreux que le genre |
| Co-jeu | Peu récompensé | +15 % par ami présent (4 max) | Bon ; le braquage à deux peut venir en MAJ |
| Samedi | MAJ + admin abuse | Compte à rebours prévu, feuille de route MAJ 0 à 7 | Choisir une heure fixe |
| Robux | Chance du serveur, caisses | Chance ×3 pas prête ; caisses en MAJ 1 ; tous les Id à 0 | Chance du serveur à prioriser |

## 5. Ce que l'algorithme de Roblox récompense en 2026

- Depuis juin 2026 : fenêtre de **28 jours** en trois tranches (J1, J2-7, J8-28), temps de jeu, jours joués, **jours de co-jeu intentionnel**, dépenses. Le **taux de rebond à la première partie** est désormais un critère.
- Seul le trafic organique compte au classement.
- Repères GameAnalytics (jeux > 1 M d'actifs par mois) : J1 médian 10 %, top 1 % 22 % ; J7 médian 1,6 %, top 1 % 9 % ; session médiane 10 min, top 1 % 21 min.
- Cibles proposées : J1 ≥ 20 %, J7 ≥ 6 %, session ≥ 15 min.
- Conséquence directe : **les 90 premières secondes** doivent tenir la promesse de la vignette (casser une vitrine, voler, exposer, voir l'argent monter).

## 6. Ce qui tue ces jeux

Chute de 70 à 95 % dans le mois qui suit le pic quand il n'y a plus de contenu prêt ; plus rien à viser après la renaissance ; économie qui gonfle ; serveurs dominés par des joueurs très riches qui pillent les nouveaux ; pay-to-win ressenti ; exploits ; vignette trompeuse.

## 7. Recommandations

### Au lancement (18/12)

1. **Premier braquage en moins de 90 s, sans entraînement**, et premier objet visiblement rare (tirage favorable au débutant). À vérifier en jeu.
2. **Boutique lisible de la rue** : façade en verre, objets réduits à leur place, `RarestDisplay` à vraie taille devant, `BB_ShopInfo` avec photo du propriétaire et meilleur objet.
3. **Anti-frustration** : protection des débutants sur la boutique (quelques minutes ou quelques braquages), butin qui retombe sur place si le voleur est frappé, une vengeance gratuite (le voleur reste marqué un moment).
4. **Annonce au serveur** quand un colis Légendaire ou plus apparaît la nuit.
5. **Renaissance allumée.**
6. **Heure fixe de la MAJ du samedi**, avec compte à rebours en jeu ; premier samedi le 19/12, en pleines vacances de Noël.

### Peut attendre une mise à jour

Mutations de matière (Or, Diamant, Arc-en-ciel), chance du serveur en Robux, caisses (MAJ 1), braquage à deux avec bonus, pièges et tourelles, admin abuse, quêtes, objets limités, étages.

## Sources principales

- Roblox, 15/06/2026 : https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox
- DevForum, juin 2026 : https://devforum.roblox.com/t/recommended-for-you-algorithm-improvements-that-better-value-long-term-retention/4684575
- GameAnalytics : https://gamedevreports.substack.com/p/gameanalytics-key-roblox-and-roblox
- RoWatcher, déclin du genre : https://rowatcher.com/news/is-the-brainrot-trend-dying-what-ccu-data-from-three-top-games-reveals
- RoWatcher, après la viralité : https://rowatcher.com/news/one-year-on-the-charts-what-really-happens-after-a-roblox-game-goes-viral
- SAB 25 M : https://www.pocketgamer.biz/robloxs-steal-a-brainrot-becomes-first-game-to-surpass-25m-concurrent-players
- SAB vol et verrou : https://allthings.how/steal-a-brainrot-roblox-efficient-stealing-events-and-rebirths et https://nerdschalk.com/anti-griefing-system-in-steal-a-brainrot-stealing/
- SAB prix Robux : https://buffget.com/news/steal-a-brainrot-game-pass-prices-robux-2026
- SAB mutations : https://rblxguide.com/games/steal-a-brainrot/updates/steal-a-brainrot-mutations-multipliers-2026
- GaG 2, vol de nuit : https://allthings.how/stealing-in-grow-a-garden-2-how-night-raids-and-garden-defense-work/
- Break and Steal an Egg : https://rowatcher.com/games/10765288803/break-and-steal-an-egg et https://roonby.com/2026/10/08/break-and-steal-an-egg-progression-guide-tips-and-tricks/amp/
- Steal an Egg : https://rblxguide.com/games/steal-an-egg/mechanics
- Abandon des débutants : https://steal-a-brainrot-6ak.pages.dev/guide

## Décision de Clément (2026-11-17)

Au lancement : points 1, 2, 4, 5 et 6 de la section 7, plus tout ce qui « peut attendre » (mutations de matière, déjà là ; chance du serveur ; caisses ; braquage à deux ; pièges ; étages). Le point 3 est refusé : pas de protection des débutants sur la boutique ni de compensation. Liaison L-216.
