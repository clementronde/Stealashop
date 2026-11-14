# Renaissances 1 à 10 dans l'économie v2 (passe 3) : proposition

Note de l'agent a145 (2026-11-14), pour Cantin (Ironix) et Clément. **Rien n'est décidé ni changé dans le jeu** :
aucune valeur de `src/` n'a bougé (`Config/Rebirths` garde le tableau de la Partie 2). Toutes les valeurs de cette
note sont des **V0 proposés**, tirés du simulateur. C'est la décision 2 de
[feuille-de-route-maj.md](feuille-de-route-maj.md) (« recalculer les montants au simulateur »), avec des réponses
proposées aux décisions 3 et 4.

- Sources : Partie 2, section 3.2 (renaissances) ; Partie 1, section 15 (question ouverte « garde-t-on les
  défenses ? ») ; `Config/Rebirths`, `Config/Items`, `Config/Rarities`, `Config/FortuneTower` ;
  [equilibrage-v2-proposition.md](equilibrage-v2-proposition.md), passe 3 (tapis 2^(niveau − 1), plus de banc,
  dégâts = arme × aura, zone 6 à 108.8M PV, zone 6 vers 7 h 30 pour le joueur moyen).
- Outil : `RAPPORT=renaissance bash tools/ironix/equilibrage/run.sh` (8 min environ ; `COURT=1` : seulement la
  proposition pour le joueur moyen, 1 min). Les valeurs sont toutes dans `tools/ironix/equilibrage/renaissance.luau`.
- Le simulateur prend l'économie de la passe 3 (`proposition_v2.luau`), pas les valeurs de `src/` : la vague 40
  (branche `agents/a134`) est encore en cours de fusion.
- Temps = **temps de jeu actif cumulé** depuis la première connexion, comme dans la note v2 ; médiane de
  25 parties par profil, entre parenthèses du 10e au 90e centile.

## 0. En bref

- **Le tableau de la Partie 2 ne tient plus** avec la v2 : 10 K$ et le Pot de nouilles du tuto font la 1re
  renaissance en **12 min**, et la 10e demande 10T$ alors que les revenus montent plus vite : les cycles
  deviennent n'importe quoi (cycle 10 à 64 fois le 1er). Il faut le refaire en entier.
- **Proposition** : 1re renaissance **après la zone 6** (20B$ et un Diamant géant de la zone 6, 8 h 14 pour le
  joueur moyen) ; chaque cycle suivant dure **94 % puis 75 %** du premier ; **10e renaissance à 70 h 07** (51 h à
  86 h selon les parties ; 57 h pour l'acharné, 97 h pour le prudent).
- **Ce qui pèse le plus, c'est « 3 objets gardés »**, pas le +50 % : sans objet gardé, chaque cycle est plus long
  que le premier (153 %) ; avec 3 objets, le retour en zone 6 ne prend plus que 20 min à 3 h. Les montants d'argent
  ci-dessous sont réglés pour 3 objets gardés : si on change cette règle, il faut les refaire.
- **Zone 6 à deux joueurs : la renaissance ne la casse pas**, tant qu'aucune récompense ne monte les dégâts
  au-dessus de **1,12 × Angle Grinder × Royal**. Le +50 % de revenus et le bonus de tapis ne touchent pas aux
  dégâts. Le Marteau-piqueur et le Bélier doivent donc rester à la puissance de l'Angle Grinder (ou n'agir que sur
  les portes des joueurs), et les auras « Renaissance » et « Légende » ne rien multiplier (section 4).

## 1. Règles proposées

### 1.1 Ce que la renaissance remet à zéro

Comme la Partie 2 (3.2), en enlevant le banc (il n'existe plus en v2) :

| Remis à zéro | Remarque |
| --- | --- |
| Argent | |
| Speed et niveau du tapis | Retour au niveau 1 (+1 par seconde) |
| Outils, auras, trails achetés | Sauf ce que donnent les renaissances (Marteau-piqueur, aura et trail « Renaissance ») |
| Présentoirs achetés | Retour à 4 (`Balance.Display.StartSlots`) |
| Tous les objets sauf 3 | L'objet requis est remis (il disparaît) et ne compte pas dans les 3 |
| Colis pas encore ouverts | Perdus dans le simulateur ; à trancher (question 5) |

### 1.2 Ce que la renaissance garde

| Gardé | Pourquoi |
| --- | --- |
| **3 objets au choix** | Partie 2, gardé. C'est le gros de l'avance d'un cycle à l'autre (section 3) |
| **Index** (découvertes et bonus) | Partie 2. Une collection qu'on recommence n'a pas de sens |
| **Arbre de compétences** (défenses, coffre-fort, chance des potions) | Décision 3, proposition : **oui**. L'arbre coûte de 10K à 600M, des miettes après la zone 6 ; le remettre à zéro punirait la défense sans rien ralentir. Il ne change aucune durée du simulateur |
| Achats Robux, gamepasses | Partie 2 |
| Récompenses de renaissance | Aura et trail « Renaissance », coffre-fort en plus, Marteau-piqueur, Bélier, titre |
| Bonus de revenus | +50 % par renaissance, additionnés (×1,5, ×2, ×2,5…), sur les revenus des présentoirs (comme `DisplayService.GetGlobalMultiplier`) ; pas sur le receleur |

### 1.3 L'objet requis

- **Un objet précis** (Partie 2), choisi pour que le joueur l'ait en **1 à 2 h** de braquage. Dans le catalogue, la
  zone 6 n'a qu'un objet Légendaire et un seul Mythique : « un objet précis » et « un objet de cette rareté de cette
  zone » reviennent presque au même.
- Une rareté qui monte (Rare, Épique, Légendaire, Mythique) et, de la 4e à la 7e, des Légendaires des zones 2 à 5 :
  le joueur **redescend** dans une zone qu'il casse en un coup pour y chasser un objet (Chasse du simulateur).
- **Pas de Mythique d'une zone normale** : le joueur moyen a 2,4 % de chance par cycle de 10 min d'en tirer un (3 colis Premium et 1 Luxe pour lui)
  (Rarities.BoxOdds), soit **7 h en moyenne** et plus de 16 h pour un joueur sur dix (essai précédent du simulateur avec la
  Météorite : cycle 9 à 12 h 23, de 6 h 35 à 22 h 31). Seule exception, la **Clé du coffre ultime** (Mythique de la
  zone 6) pour les 9e et 10e : la **Fortune Tower** (MAJ 2, 2/1) donne des colis Mythique à 90 %, et le seul Mythique
  de la zone 6 est la Clé. Hypothèse du simulateur : une tour toutes les 50 min de jeu en zone 6, un colis pour le
  joueur ; la Clé tombe alors en 1 h 10.

### 1.4 La cible de durée (consigne du 14/11)

- 1re renaissance après la zone 6, vers 7 h 30 à 9 h pour le joueur moyen : visée **8 h 15**.
- Chaque cycle suivant un peu plus court que le premier grâce au bonus, **jamais moins de 40 %**. Parts visées :
  95, 90, 85, 80, 80, 75, 75, 70, 70 % du premier.
- **10e renaissance vers 60 à 80 h : justifié.** Avec ces parts, la 10e arrive à 8,2 × le 1er cycle, soit
  67 h 39. Pour tomber sous 60 h, il faudrait des cycles à 61 % du premier en moyenne ; pour passer 80 h, des
  cycles plus longs que le premier, ce qui contredit « grâce au bonus ». 60 à 80 h, c'est 3 à 4 semaines à 3 h par
  jour : la 10e tombe vers la mi-janvier pour un joueur arrivé le 18/12, après la MAJ 3 du 9/1.

## 2. Le tableau des 10 renaissances

| Renaissance | Argent requis | Objet requis (remis) | Récompense en plus du +50 % | Bonus de revenus après | Durée du cycle (joueur moyen) | ÷ 1er cycle | Temps cumulé simulé |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | **20B** | Diamant géant (Rare, zone 6) | Aura « Renaissance » (cosmétique) | ×1,5 | 8 h 14 (6 h 51 à 9 h 35) | 100 % | **8 h 14** (6 h 51 à 9 h 35) |
| 2 | **500B** | Trône en or (Épique, zone 6) | +1 coffre-fort | ×2 | 7 h 44 (5 h 32 à 9 h 22) | 94 % | **15 h 56** (13 h 36 à 17 h 37) |
| 3 | **1.3T** | Statue de la Liberté (Épique, zone 6) | **Tapis ×1,5** (au lieu de +25 %) | ×2,5 | 7 h 12 (4 h 56 à 8 h 45) | 88 % | **22 h 49** (18 h 33 à 25 h 51) |
| 4 | **2T** | Peluche géante (Légendaire, zone 2) | Trail « Renaissance » (cosmétique) | ×3 | 6 h 49 (3 h 35 à 8 h 44) | 83 % | **30 h 08** (22 h 57 à 33 h 23) |
| 5 | **2.6T** | PC gamer (Légendaire, zone 3) | Marteau-piqueur (puissance de l'Angle Grinder, gardé aux renaissances suivantes) | ×3,5 | 6 h 39 (3 h 50 à 8 h 53) | 81 % | **36 h 35** (27 h 02 à 41 h 14) |
| 6 | **3.2T** | Couronne (Légendaire, zone 4) | **Tapis ×1,5** (×2,25 en tout) | ×4 | 6 h 20 (3 h 40 à 8 h 24) | 77 % | **42 h 10** (30 h 09 à 49 h 57) |
| 7 | **5T** | Masque ancien (Légendaire, zone 5) | Bélier (portes des boutiques de joueurs seulement) | ×4,5 | 6 h 56 (4 h 26 à 9 h 39) | 84 % | **49 h 51** (35 h 27 à 58 h 26) |
| 8 | **7T** | Coffre de diamants (Légendaire, zone 6) | 2e agent de sécurité (après la MAJ 5 ; « Coming » avant) | ×5 | 6 h 20 (4 h 41 à 11 h 00) | 77 % | **55 h 59** (40 h 32 à 69 h 26) |
| 9 | **7.5T** | Clé du coffre ultime (Mythique, zone 6) | Aura « Légende » (cosmétique) | ×5,5 | 6 h 12 (4 h 25 à 9 h 23) | 75 % | **64 h 06** (45 h 35 à 76 h 58) |
| 10 et suivantes | **9T**, puis ×1,3 par renaissance (V0, non simulé) | Clé du coffre ultime (Mythique, zone 6) | Titre au-dessus de la tête | ×6 | 6 h 11 (4 h 41 à 9 h 31) | 75 % | **70 h 07** (51 h 21 à 86 h 14) |

Ce que montre le simulateur pour le joueur moyen, renaissance par renaissance :

| Renaissance | Retour en zone 6 dans le cycle | Objet requis trouvé (depuis le début du cycle) | Revenus au moment de renaître | Revenus des 3 objets gardés |
| --- | --- | --- | --- | --- |
| 1 | 7 h 24 | 7 h 53 | 6.8M/s | 3.3M/s |
| 2 | 2 h 50 | 3 h 09 | 39M/s | 11.8M/s |
| 3 | 1 h 27 | 2 h 00 | 86.7M/s | 20M/s |
| 4 | 1 h 02 | 1 h 10 | 124M/s | 26.2M/s |
| 5 | 1 h 04 | 1 h 56 | 148M/s | 30M/s |
| 6 | 58 min | 1 h 34 | 207M/s | 35.6M/s |
| 7 | 41 min | 47 min | 264M/s | 45M/s |
| 8 | 22 min | 1 h 10 | 370M/s | 56.2M/s |
| 9 | 20 min | 1 h 10 | 413M/s | 62.5M/s |
| 10 | 20 min | 1 h 10 | 465M/s | 62.5M/s |

Lecture :

- **L'argent requis monte peu après la 6e** (3.2T, 5T, 7T, 7.5T, 9T) parce que les revenus montent avec le bonus
  et les objets gardés : c'est la durée qui est tenue, pas un ×10 par palier. Un ×10 par palier (Partie 2) donne
  des cycles de plus en plus longs dès que les revenus montent moins vite que ×10 par cycle.
- **Le cycle se partage entre un retour rapide et une longue période en zone 6** : dès la 4e, le joueur revient en
  zone 6 en 1 h au plus, puis braque la zone 6 (et la Fortune Tower) 5 à 6 h pour l'argent. C'est le genre
  (« Steal a Brainrot ») ; si on veut un retour plus long, c'est la règle des 3 objets gardés qu'il faut toucher
  (section 3), pas l'argent.
- Les trois profils (temps cumulé médian) :

| Profil | R1 | R2 | R3 | R4 | R5 | R6 | R7 | R8 | R9 | R10 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Prudent | 15 h 31 | 28 h 37 | 38 h 53 | 46 h 41 | 53 h 40 | 61 h 17 | 70 h 54 | 80 h 09 | 88 h 27 | 96 h 53 |
| **Moyen** | **8 h 14** | **15 h 56** | **22 h 49** | **30 h 08** | **36 h 35** | **42 h 10** | **49 h 51** | **55 h 59** | **64 h 06** | **70 h 07** |
| Acharné | 6 h 58 | 14 h 17 | 20 h 30 | 26 h 00 | 30 h 19 | 35 h 48 | 42 h 01 | 47 h 30 | 51 h 41 | 56 h 52 |

## 3. Variantes (joueur moyen, mêmes montants)

| Variante | R1 | R2 | R4 | R6 | R8 | R10 | Cycle 2 ÷ cycle 1 | Cycle 10 ÷ cycle 1 | Plus court ÷ cycle 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **Proposition** (3 objets, +50 %) | 8 h 14 | 15 h 56 | 30 h 08 | 42 h 10 | 55 h 59 | 70 h 07 | 94 % | 75 % | 75 % |
| Sans objet gardé | 8 h 14 | 20 h 50 | 51 h 01 | 81 h 34 | 114 h 44 | 150 h 49 | 153 % | 226 % | 153 % |
| 1 objet gardé | 8 h 14 | 16 h 26 | 33 h 55 | 48 h 20 | 66 h 48 | 81 h 55 | 99 % | 106 % | 88 % |
| +100 % par renaissance | 8 h 14 | 14 h 22 | 25 h 47 | 34 h 45 | 44 h 36 | 53 h 17 | 81 % | 56 % | 53 % |
| +25 % par renaissance | 8 h 14 | 16 h 29 | 32 h 36 | 47 h 35 | 65 h 23 | 83 h 51 | 104 % | 121 % | 88 % |
| Sans Marteau-piqueur gardé | 8 h 14 | 15 h 56 | 30 h 08 | 43 h 05 | 56 h 36 | 68 h 31 | 94 % | 76 % | 76 % |
| Sans Fortune Tower | 8 h 14 | 15 h 56 | 30 h 08 | 42 h 10 | 55 h 59 | 73 h 33 | 94 % | 95 % | 77 % |
| Tableau de la Partie 2 (10 K$ ×10) | 12 min | 28 min | 9 h 52 | 13 h 31 | 18 h 53 | 37 h 58 | 127 % | 6 445 % | 127 % |

- **Objets gardés** : le levier le plus fort. À 0, les 10 renaissances prennent 150 h et chaque cycle est plus long
  que le premier. À 1, on retombe vers 82 h (cycles à 88 à 106 %). À 3 (proposition), 70 h.
- **+100 %** reste au-dessus de 40 % (53 % au plus court) mais pousse la 10e à 53 h, sous la cible.
- **Le Marteau-piqueur gardé** ne gagne presque rien (moins d'une heure en tout) : l'argent ne manque jamais après
  la 1re renaissance. Sa vraie valeur est le confort (pas d'outil à racheter), pas le temps.
- **Sans Fortune Tower**, la Clé de la 10e ne tombe que des colis de la zone 6 : +3 h 30 sur la 10e. La Fortune
  Tower doit donc être allumée avant les renaissances 9 et 10 (elle l'est le 2/1 dans la feuille de route).

## 4. Zone 6 à deux joueurs (décision 4)

Règle de la passe 3 : vitrine de la zone 6 à **108.8M PV** = 54,39 × D, avec D = Angle Grinder 100K × Royal ×20 =
2M ; chrono de 8 s, 5 coups par seconde, régénération 3 %/s. Seul, même avec la potion ×1,5 : non ; à deux : oui.

**Ce que la renaissance donne n'y touche pas** : le +50 % de revenus, le tapis ×1,5, les objets gardés, l'index, le
coffre-fort ne changent pas les dégâts d'un coup. **La règle tient**, à trois conditions sur les récompenses qui
pourraient monter les dégâts : un outil (Marteau-piqueur, Bélier) ou une aura (« Renaissance », « Légende ») plus
forts que l'Angle Grinder ou que Royal. Avec des dégâts k × D :

| k | Seul | Seul, potion ×1,5 | Deux | Règle tenue ? |
| --- | --- | --- | --- | --- |
| 1 | non (16.1 s) | non (9.3 s) | 6.5 s | oui |
| 1,1 | non (14.1 s) | non (8.2 s) | 5.8 s | oui |
| 1,124 | non (13.6 s) | non (8.0 s) | 5.7 s | oui, à la limite |
| 1,25 | non (11.8 s) | 7.0 s | 5.0 s | **non** |
| 1,5 | non (9.3 s) | 5.7 s | 4.1 s | **non** |
| 2 | 6.5 s | 4.1 s | 3.0 s | **non** |

Ce qu'il faut faire :

1. **Proposé** : le Marteau-piqueur a **la puissance de l'Angle Grinder** (100K) et se garde d'une renaissance à
   l'autre ; le Bélier ne frappe plus fort que sur les **portes des boutiques de joueurs** (×3, V0) ; les auras
   « Renaissance » et « Légende » sont **cosmétiques** (ou au plus ×20, comme Royal). Aucune ne compte dans les PV de
   la zone 6 (réponse proposée à la décision 4 : **non**).
2. Si Clément veut un outil de renaissance plus fort que l'Angle Grinder : **plafonner ses dégâts sur les vitrines
   de la zone 6** à ceux de l'Angle Grinder (une ligne dans le calcul des dégâts côté serveur), ou rester sous
   **1,12 ×** (Marteau-piqueur à 112K au plus).
3. **À ne pas faire** : faire suivre les PV de la zone 6 à l'outil de renaissance (« meilleur Power » qui
   l'inclut). Avec un outil à ×1,5, la vitrine passerait à 163M : **deux joueurs sans renaissance ne la casseraient
   plus** (129M au plus en 8 s), et la zone 6 serait fermée à tous ceux qui n'ont pas 5 renaissances.

## 5. Ce que le simulateur ne compte pas

- Gamepasses et boosts Robux, gains hors ligne, récompenses, camion, potions, bonus de l'index, vols entre
  joueurs : le jeu réel ira un peu plus vite (passe 3 : zone 6 à 6 h 13 au lieu de 7 h 31 avec les trois aides).
- Les objets gagnés à la Fortune Tower ne vont pas sur les présentoirs (seule la Clé compte).
- L'objet requis gagné puis vendu au receleur est quand même compté comme gardé (un vrai joueur le garderait).
- Les rangées de présentoirs liées aux renaissances (L-084, « chaque rebirth donne le droit d'acheter la rangée
  suivante ») : le simulateur garde 20 présentoirs au plus, sans rangées.
- Le joueur achète les mêmes choses qu'en v2 (kits, tapis, présentoirs) ; après la zone 6, il garde son argent pour
  la renaissance.

## 6. Questions

### Pour Cantin et Clément (ensemble)

1. **1re renaissance après la zone 6 (20B, vers 8 h)** comme demandé le 14/11, ou **vers 20 min** comme le dit la
   feuille de route (décision 2) et la Partie 2 ? Les deux ne vont pas ensemble : une 1re à 20 min remet à zéro
   un joueur qui n'a pas encore vu la zone 2 et rend tous les cycles suivants trop courts (variante « Partie 2 »).
   Proposition : après la zone 6.
2. **3 objets gardés** (Partie 2) ? C'est ce qui règle tout le reste (section 3). Proposition : oui, 3.
3. **+50 % de revenus par renaissance** (Partie 2) ? Proposition : oui ; +100 % rend la 10e trop rapide (53 h).
4. **Arbre de compétences gardé** (décision 3) ? Proposition : oui.
5. **Colis pas encore ouverts** au moment de renaître : perdus, gardés dans l'inventaire, ou ouverts d'office ?
   Proposition : ouverts d'office (l'objet entre dans le choix des 3 gardés ou part).
6. **Renaissances 1 à 4 le 26/12, 5 à 10 le 9/1** : l'acharné arrive à la 4e vers 26 h de jeu ; à 4 h par jour
   depuis le 18/12, il attend la 5e du 26/12 au 9/1. Sortir 5 et 6 dès le 26/12, ou 5 à 10 le 2/1 avec la Fortune
   Tower ?

### Pour Clément

7. **Objets requis** : Diamant géant, Trône en or, Statue de la Liberté, Peluche géante, PC gamer, Couronne, Masque
   ancien, Coffre de diamants, puis la Clé du coffre ultime (9e, 10e et suivantes). D'accord avec ce « retour en
   arrière » des 4e à 7e (Légendaires des zones 2 à 5) ? Il remplace le Pot de nouilles, la Voiture télécommandée,
   le Robot jouet, la Console portable, le Diamant brut et la Météorite (trop rare : 7 h en moyenne).
8. **Récompenses** : « +25 % de gains d'entraînement » ne pèse presque rien quand un niveau de tapis fait ×2 ;
   proposé : **tapis ×1,5** aux 3e et 6e. Le Marteau-piqueur à la **puissance de l'Angle Grinder** mais gardé, le
   Bélier pour les **portes des joueurs seulement**, les auras « Renaissance » et « Légende » **cosmétiques**
   (section 4). D'accord ?
9. **Écran `UI_Rebirth`** : la colonne « tu gardes » doit montrer le choix des 3 objets (un sélecteur de 3
   présentoirs ou d'objets de l'inventaire). Prévu dans la maquette ?

### Pour Cantin

10. **Après la 10e** : 9T puis ×1,3 par renaissance (V0, non simulé), avec la
    Clé à chaque fois. Ou arrêter à 10 jusqu'à une zone 7 ?
11. **Hypothèse de la Fortune Tower** (une tour toutes les 50 min de jeu en zone 6, un colis par joueur) : à corriger
    avec les vraies valeurs de L-145 ; sans elle, +3 h 30 sur la 10e.

## 7. Ce qu'il faudra changer dans le code (rien n'est fait)

- `Config/Rebirths` : le tableau de la section 2 (argent, objet, récompense), `CashGrowth` = 1,3 au-delà de la 10e
  (aujourd'hui 10), `PlayTimeMinutes` = temps cumulés simulés (494, 956, 1 369, 1 808, 2 195, 2 530, 2 991, 3 359,
  3 846, 4 207). Ses assertions contrôlent déjà rareté et zone de chaque objet avec `Config/Items`.
- `RebirthService` (DEV-120) : remise à zéro de la section 1.1, choix des 3 objets, bonus de revenus dans
  `DisplayService.GetGlobalMultiplier`, tapis ×1,5 dans `TrainingService`, outil gardé.
- Partie 2, section 3.2 : tableau et lignes « Remis à zéro » / « Gardé » à reporter si la proposition est acceptée,
  et une ligne au journal des décisions (Partie 1, section 15).
