# Rééquilibrage : proposition chiffrée (liaison L-108, point 1)

Note de l'agent a102 (vague 30, 2026-11-12), pour Cantin et Clément. **Rien n'est changé dans le jeu** : aucune valeur de `src/` n'a bougé. Cette note propose une nouvelle échelle et donne l'outil qui la vérifie.

- Outil : `bash tools/ironix/equilibrage/run.sh` (hors Studio, 10 s). Il lit les vraies tables de `src/shared/Config`, fait jouer 3 profils de joueurs, 25 parties chacun, dans l'économie actuelle puis dans la proposition, et sort les tableaux de cette note.
- Toutes les valeurs proposées sont dans un seul fichier : `tools/ironix/equilibrage/proposition.luau`. On change un nombre, on relance, on lit le résultat.
- Les nombres des tableaux sont écrits comme dans le jeu (`Format.short` : point décimal, K, M, B, T, Qa).

## 1. En bref

| | Aujourd'hui | Proposition |
| --- | --- | --- |
| Entrée en zone 6, joueur moyen | 2 h 09 | 7 h 32 |
| Vitesse de marche au plafond de 70 | au bout de 29 min de jeu | jamais (45 à l'entrée en zone 6, 61 après 100 h de tapis au niveau 20) |
| Speed affichée à l'entrée en zone 6 | 70 (c'est le WalkSpeed qui est affiché) | 1.6B (panneau : 3B) |
| Strength affichée à l'entrée en zone 6 | 1.1K | 758B (panneau : 1T) |
| Part du temps passée à s'entraîner | 20 % | 55 % |
| Niveau du tapis à l'entrée en zone 6 | 20 sur 20 | 13 sur 20 |

Le constat de Clément se vérifie : aujourd'hui les stats ne comptent presque pas. Pour un panneau vert en zone 6, il faut 355 points de Vitesse (4 min de tapis au niveau 0) et 1.5K de Force. Seul l'argent des outils et des auras retient le joueur.

## 2. Les formules proposées

```
Speed affichée    = Vitesse entraînée × M trail
WalkSpeed         = min(70, 16 + 4 × log10(1 + Speed affichée / 100))

Strength affichée = dégâts par coup = P outil × (1 + Force entraînée) × M aura
```

- **Vitesse** : chaque fois que la Speed affichée est multipliée par 10, la marche gagne 4. La stat monte sans fin, la marche reste entre 16 et 70. Aujourd'hui : `min(70, 16 + 0,05 × Vitesse × M trail)`.
- **Force** : les dégâts n'ont pas besoin de borne, puisque les PV des vitrines suivent. La formule garde sa forme, le diviseur passe de 100 à 1 (`Balance.Stats.StrengthDivisor`). Aujourd'hui : `P outil × (1 + Force / 100) × M aura`.
- **Un nombre sur le HUD, le même sur le panneau.** Le HUD montre la Speed affichée (trail compris) et la Strength affichée (outil et aura compris). Le panneau d'un magasin annonce ces deux mêmes nombres. Acheter un outil ou une aura fait donc bondir sa Strength, acheter un trail fait bondir sa Speed.
- **Les vitesses réelles ne bougent pas.** Les seuils de Speed sont choisis pour retomber sur les vitesses de marche conseillées d'aujourd'hui (22, 28, 34, 40). La map, l'anti-triche, le plafond de 70 et les animations de course restent valables.

### Courbe : vitesse de marche selon la stat

Aujourd'hui (sans trail) :

| Vitesse | WalkSpeed | 16 … 70 | Temps de tapis au niveau 0, avec taps |
| --- | --- | --- | --- |
| 0 | 16.0 | `···························` | — |
| 120 | 22.0 | `███························` | 1 min |
| 240 | 28.0 | `██████·····················` | 3 min |
| 360 | 34.0 | `█████████··················` | 4 min |
| 480 | 40.0 | `████████████···············` | 5 min |
| 640 | 48.0 | `████████████████···········` | 7 min |
| 800 | 56.0 | `████████████████████·······` | 9 min |
| 1.1K | 70.0 | `███████████████████████████` | 12 min |

Proposition (sans trail) :

| Speed affichée | WalkSpeed | 16 … 70 | Repère |
| --- | --- | --- | --- |
| 0 | 16.0 | `···························` | |
| 100 | 17.2 | `█··························` | |
| 1K | 20.2 | `██·························` | |
| 3K | 22.0 | `███························` | panneau zone 2 |
| 100K | 28.0 | `██████·····················` | panneau zone 3 |
| 3M | 33.9 | `█████████··················` | panneau zone 4 |
| 100M | 40.0 | `████████████···············` | panneau zone 5 |
| 3B | 45.9 | `███████████████············` | panneau zone 6 |
| 100B | 52.0 | `██████████████████·········` | |
| 1T | 56.0 | `████████████████████·······` | |
| 100T | 64.0 | `████████████████████████···` | |
| 1Qa | 68.0 | `██████████████████████████·` | |
| 3.2Qa | 70.0 | `███████████████████████████` | plafond |

## 3. Les cibles de durée

Temps de jeu cumulé pour rapporter son premier colis de chaque zone, sans gamepass ni renaissance :

| | Zone 2 | Zone 3 | Zone 4 | Zone 5 | Zone 6 |
| --- | --- | --- | --- | --- | --- |
| Cible, joueur moyen | 8 min | 30 min | 1 h à 1 h 15 | 2 h 45 à 3 h | 7 à 8 h |
| Joueur acharné | environ 0,7 fois ces durées (zone 6 en 5 h) | | | | |
| Joueur prudent | environ 1,5 fois (zone 6 en 11 à 12 h) | | | | |

Pourquoi ces cibles :

- **Zone 2 en moins de 10 min** : c'est le premier vrai progrès, il doit arriver dans la première session. Le tutoriel annonce déjà l'objectif « zone 2 » à 5 min.
- **Chaque zone prend 2 à 3 fois plus de temps que la précédente** : c'est le rythme des jeux « Steal a … » et des simulateurs d'entraînement. On débloque vite au début, puis chaque palier devient un but de session, puis de plusieurs sessions.
- **Zone 6 en 7 à 8 h** : c'est la cible du doc (section 7 : « 6 à 8 h de jeu pour atteindre la zone 6 »), et elle colle au tableau des renaissances de la Partie 2 (objet de zone 5 demandé à 8 h, objet de zone 6 à 12 h). L'économie actuelle y arrive en 2 h.
- **Casse d'une vitrine au seuil du panneau : 7 s à 6 coups/s**, 12 s à 4 coups/s (juste sous le chrono de 13 s), comme aujourd'hui : la règle « PV = 35 × dégâts conseillés » est gardée.
- **Le plafond de 70 n'est plus un but de la première semaine.** La marche continue de monter un peu après la zone 6 (53 après 1 h de tapis au niveau 20, 57 après 10 h, 61 après 100 h).

## 4. Les valeurs proposées

### 4.1 Zones (doc section 4, `Config/Zones`)

| Zone | Speed du panneau (avant → après) | WalkSpeed conseillé | Strength du panneau = dégâts/coup (avant → après) | PV vitrine (avant → après) | Vigile (avant → après) |
| --- | --- | --- | --- | --- | --- |
| 1 | 16 → 0 | 16 | 1 → 1 | 35 → 35 | 13.4 → 13.4 |
| 2 | 22 → 3K | 22 | 10 → 5K | 350 → 175K | 18.8 → 20.8 |
| 3 | 28 → 100K | 28 | 80 → 1M | 2.8K → 35M | 24.2 → 26.2 |
| 4 | 34 → 3M | 34 | 600 → 100M | 21K → 3.5B | 29.6 → 31.5 |
| 5 | 40 → 100M | 40 | 5K → 10B | 175K → 350B | 35.0 → 37.0 |
| 6 | 48 → 3B | 48 → 46 | 40K → 1T | 1.4M → 35T | 42.2 → 42.3 |

- **Speed** : un pas de ×30 par zone. La zone 6 passe de 48 à 46 de marche conseillée, pour garder le même pas que les autres (à 48, il faudrait 10B).
- **Strength** : un pas de ×100 par zone (×5 000 de la zone 1 à la zone 2, puisqu'on part de 1).
- **PV vitrine** : 35 × dégâts conseillés, règle inchangée.
- **Vigile** : `0,9 × vitesse conseillée + 1` au lieu de `− 1` (zone 1 inchangée, c'est la zone du tuto). Dans un log, 2 de marche d'écart valent ×3 de Speed : avec la règle d'aujourd'hui, un joueur passerait avec environ 8 fois moins de Speed que le panneau. Avec `+ 1`, le porteur au seuil du panneau perd 1 stud par seconde sur le vigile et rentre de justesse (retour de 9 à 20 s). Les zones sont plus tendues, ce que Clément demande. **À vérifier en Play** : voir la question 4 pour Clément.
- Distances de retour, revenus de base, raretés, chrono de casse, régénération : inchangés.

### 4.2 Tapis et banc (doc 5.1 et 7.5, `Config/Upgrades`, `Config/Training`)

| | Aujourd'hui | Proposition |
| --- | --- | --- |
| Gain du tapis au niveau n | (1 + 0,5 × n) par seconde | 4 × 2^n par seconde |
| Gain du banc au niveau n | (1 + 0,5 × n) par répétition | 6 × 2^n par répétition |
| Prix du niveau suivant | 200 × 1,9^n | 200 × 3,6^n |
| Niveaux | 20 | 20 (les 11 modèles de tapis de Clément gardent leur palier tous les 2 niveaux) |
| Taps au tapis | +50 % | +50 % |

Le banc rapporte 1,5 fois le tapis par répétition, pour qu'une seconde de banc (une répétition) vaille une seconde de tapis avec taps.

| Niveau | Gain tapis (avant → après) | Prix du niveau (avant → après) | Cumul (avant → après) |
| --- | --- | --- | --- |
| 0 | 1 → 4 | — | — |
| 1 | 1.5 → 8 | $200 → $200 | $200 → $200 |
| 2 | 2 → 16 | $380 → $720 | $580 → $920 |
| 3 | 2.5 → 32 | $722 → $2.5K | $1.3K → $3.5K |
| 5 | 3.5 → 128 | $2.6K → $33.5K | $5.2K → $46.4K |
| 8 | 5 → 1K | $17.8K → $1.5M | $37.5K → $2.1M |
| 10 | 6 → 4K | $64.5K → $20.3M | $136K → $28.1M |
| 12 | 7 → 16.3K | $232K → $263M | $491K → $364M |
| 14 | 8 → 65.5K | $841K → $3.4B | $1.7M → $4.7B |
| 16 | 9 → 262K | $3M → $44.2B | $6.4M → $61.2B |
| 18 | 10 → 1M | $10.9M → $573B | $23.1M → $793B |
| 20 | 11 → 4.1M | $39.5M → $7.4T | $83.5M → $10.2T |

Aujourd'hui le tapis est au niveau 20 avant la zone 6 (83.5M $ pour les 20 niveaux, quand la Disqueuse seule coûte 400M $). Dans la proposition, les machines deviennent le premier poste de dépense : niveau 2 à l'entrée en zone 2, 6 en zone 3, 8 en zone 4, 11 en zone 5, 13 ou 14 en zone 6, et les niveaux 15 à 20 pour la suite.

### 4.3 Trails (doc 7.4, `Config/Cosmetics`)

| Trail | Dust | Wind | Turbo | Comet | Hyperspace |
| --- | --- | --- | --- | --- | --- |
| Aujourd'hui | ×1.1 | ×1.25 | ×1.4 | ×1.6 | ×1.8 |
| Proposition | ×1.5 | ×2 | ×3 | ×5 | ×8 |

Dans un log, ×1,1 ne se voit pas. Les trails prennent les paliers des auras. Prix inchangés. Outils, auras et leurs prix : inchangés.

### 4.4 Portes des boutiques de joueurs (vague 29, `Formulas.PlayerWindowHP`, `Config/SkillTree`)

La règle de la vague 29 est gardée : base = 50 × dégâts conseillés de la zone du même rang que le niveau de la boutique. Elle suit la nouvelle échelle sans rien changer au code : 50, 250K, 50M, 5B, 500B (aujourd'hui 50, 500, 4K, 30K, 250K).

Temps de casse par un voleur à 6 coups/s :

| | Sans arbre, voleur du même rang | Sans arbre, voleur d'une zone au-dessus | Arbre complet, même rang | Arbre complet, une zone au-dessus | Arbre complet, deux zones au-dessus |
| --- | --- | --- | --- | --- | --- |
| Aujourd'hui (Glass ×8, Walls ×3) | 11.1 s | 1 s | jamais | jamais | 3 à 4.5 s |
| Proposition, arbre inchangé | 11.1 s | 0.1 s | jamais | 1.1 à 2.4 s (< 0.1 s au niveau 1) | < 0.1 s |
| Proposition, variante (Glass 2 / 4 / 10 / 25 / 60, Walls 1.5 / 2.5 / 5 / 10) | 11.1 s | 0.1 s | jamais | jamais (1.1 s au niveau 1) | 0.3 à 0.5 s |

Entre joueurs du même rang, rien ne change. Mais les zones sont maintenant séparées par ×100 de dégâts au lieu de ×8 : avec l'arbre d'aujourd'hui, une porte entièrement améliorée ne tient plus que 2 s face à un voleur d'une zone au-dessus. La variante lui rend sa tenue. C'est un choix de jeu : voir la question 5 pour Clément.

## 5. Résultats du simulateur

### 5.1 Temps de jeu pour entrer dans chaque zone

Médiane de 25 parties (de la plus rapide à la plus lente), premier colis rapporté de la zone.

| Économie | Profil | Zone 2 | Zone 3 | Zone 4 | Zone 5 | Zone 6 | Plafond de 70 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Actuelle | Prudent | 11 min (7 à 11) | 21 min (15 à 28) | 58 min (41 min à 1 h 11) | 1 h 37 (1 h 06 à 1 h 55) | 2 h 22 (1 h 46 à 2 h 59) | à 39 min |
| Actuelle | Moyen | 7 min (5 à 8) | 17 min (11 à 24) | 51 min (35 min à 1 h 07) | 1 h 28 (1 h 01 à 1 h 51) | 2 h 09 (1 h 42 à 2 h 35) | à 29 min |
| Actuelle | Acharné | 5 min (3 à 6) | 13 min (11 à 18) | 40 min (25 à 47) | 1 h 11 (37 min à 1 h 31) | 1 h 42 (1 h 01 à 2 h 08) | à 19 min |
| Proposée | Prudent | 12 min (8 à 15) | 42 min (31 à 52) | 1 h 42 (1 h 31 à 2 h 21) | 4 h 32 (3 h 36 à 5 h 24) | 11 h 32 (9 h 26 à 15 h 08) | jamais |
| Proposée | Moyen | 7 min (5 à 8) | 27 min (21 à 36) | 1 h 07 (48 min à 1 h 21) | 2 h 45 (2 h 11 à 3 h 15) | 7 h 32 (6 h 17 à 8 h 31) | jamais |
| Proposée | Acharné | 6 min (4 à 7) | 21 min (17 à 25) | 51 min (36 min à 1 h 01) | 1 h 59 (1 h 22 à 2 h 23) | 5 h 11 (3 h 47 à 6 h 08) | jamais |

### 5.2 Le joueur moyen à son entrée dans chaque zone (médianes)

Économie actuelle :

| Zone | Temps de jeu | WalkSpeed | Force entraînée | Dégâts/coup | Casse | Outil | Tapis / banc | Revenus | Depuis la zone d'avant : tapis, banc, braquages |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2 | 7 min | 18.0 | 68.5 | 7.5 | 10.0 s | Wrench | 2 / 2 | $15.8/s | 15 s, 52 s, 6 min |
| 3 | 17 min | 24.4 | 279 | 60.6 | 10.0 s | Crowbar | 7 / 7 | $310/s | 25 s, 2 min, 8 min |
| 4 | 51 min | 70.0 | 506 | 910 | 4.3 s | Sledgehammer | 15 / 15 | $8K/s | 6 min, 54 s, 25 min |
| 5 | 1 h 28 | 70.0 | 1.1K | 7.8K | 4.2 s | Fire Axe | 18 / 18 | $75.9K/s | 6 min, 2 min, 31 min |
| 6 | 2 h 09 | 70.0 | 1.1K | 30.3K | 10.0 s | Angle Grinder | 20 / 20 | $678K/s | 7 min, 0 s, 34 min |

Proposition :

| Zone | Temps de jeu | Speed affichée | WalkSpeed | Strength affichée | Casse | Outil | Tapis / banc | Revenus | Depuis la zone d'avant : tapis, banc, braquages |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2 | 7 min | 808 | 19.8 | 3.7K | 10.0 s | Wrench | 2 / 2 | $15/s | 28 s, 1 min, 5 min |
| 3 | 27 min | 37.8K | 26.3 | 758K | 10.0 s | Crowbar | 6 / 5 | $541/s | 2 min, 7 min, 12 min |
| 4 | 1 h 07 | 1.3M | 32.5 | 77.5M | 9.7 s | Sledgehammer | 8 / 8 | $7.4K/s | 7 min, 10 min, 18 min |
| 5 | 2 h 45 | 49.7M | 38.8 | 12.3B | 5.5 s | Fire Axe | 11 / 11 | $107K/s | 29 min, 39 min, 40 min |
| 6 | 7 h 32 | 1.6B | 44.8 | 758B | 10.0 s | Angle Grinder | 13 / 14 | $1.9M/s | 1 h 06, 1 h 28, 1 h 58 |

Le joueur moyen n'attend pas le vert : il entre dès qu'il casse en 10 s et que le vigile ne le rattrape plus, soit à environ la moitié de la Speed du panneau et les trois quarts de sa Strength. Le joueur prudent attend les deux nombres verts.

### 5.3 Répartition du temps jusqu'à la zone 6 (médianes)

| Économie | Profil | Tapis | Banc | Braquages | Part d'entraînement | Colis rapportés |
| --- | --- | --- | --- | --- | --- | --- |
| Actuelle | Prudent | 26 min | 8 min | 1 h 49 | 24 % | 154 |
| Actuelle | Moyen | 21 min | 5 min | 1 h 44 | 20 % | 180 |
| Actuelle | Acharné | 18 min | 2 min | 1 h 23 | 19 % | 166 |
| Proposée | Prudent | 4 h 06 | 2 h 51 | 4 h 25 | 61 % | 246 |
| Proposée | Moyen | 1 h 45 | 2 h 25 | 3 h 12 | 57 % | 207 |
| Proposée | Acharné | 1 h 36 | 1 h 21 | 2 h 30 | 54 % | 189 |

La nuit (2 min sur 10) est déjà un temps d'entraînement forcé, et le tapis comme le banc tournent sans clic. Un peu plus de la moitié du temps aux machines reste beaucoup : voir la question 2 pour Cantin.

### 5.4 Ce que coûte chaque achat au joueur moyen

Prix divisé par ce qu'il gagne par minute au moment de l'achat (présentoirs et receleur). Le doc vise 3 à 7 min pour un outil (7.2).

| Article | Prix | Actuelle : acheté à, minutes de revenus | Proposée : acheté à, minutes de revenus |
| --- | --- | --- | --- |
| Wrench | $300 | 4 min, 0.6 | 4 min, 0.6 |
| Crowbar | $8K | 13 min, 0.8 | 11 min, 0.8 |
| Hammer | $120K | 26 min, 0.8 | 30 min, 1.1 |
| Sledgehammer | $2M | 51 min, 4.1 | 49 min, 5.3 |
| Fire Axe | $30M | 1 h 27, 6.6 | 1 h 41, 7.1 |
| Angle Grinder | $400M | 2 h 08, 9.8 | 3 h 28, 11.0 |
| Flame | $15K | 15 min, 0.8 | 15 min, 0.9 |
| Plasma | $10M | 1 h 11, 3.0 | 1 h 23, 4.0 |
| Galaxy | $250M | 1 h 56, 7.8 | 2 h 51, 25.2 |
| Hyperspace | $200M | 1 h 48, 8.1 | 3 h 05, 10.5 |
| Royal | $3B | pas acheté avant la zone 6 | pas acheté avant la zone 6 |
| Tapis niveau 5 | $2.6K / $33.5K | 10 min, 0.5 | 18 min, 1.6 |
| Tapis niveau 10 | $64.5K / $20.3M | 22 min, 0.8 | 1 h 30, 5.7 |
| Tapis niveau 12 | $232K / $263M | 28 min, 1.2 | 3 h 19, 9.1 |
| Tapis niveau 14 | $841K / $3.4B | 38 min, 2.2 | 4 h 45, 26.6 (10 parties sur 25) |
| Tapis niveau 20 | $39.5M / $7.4T | 1 h 37, 2.8 | pas acheté avant la zone 6 |
| Présentoir n° 12 | $305K | 33 min, 0.9 | 42 min, 1.2 |
| Présentoir n° 16 | $11.9M | 1 h 35, 0.7 | 2 h 55, 0.9 |

Dans les deux économies, les trois premiers outils et les présentoirs coûtent moins d'une minute de revenus : ils sont trop bon marché par rapport au doc. Ce n'est pas l'objet de L-108, mais c'est à revoir avec les prix (question 3 pour Cantin).

### 5.5 Sensibilité : ce qui fait bouger la zone 6 du joueur moyen

| Variante | Entrée en zone 6 | Part d'entraînement |
| --- | --- | --- |
| Proposition telle quelle | 7 h 32 | 55 % |
| Prix des niveaux ×3 par niveau (au lieu de ×3,6) | 4 h 08 | 46 % |
| Prix des niveaux ×4 par niveau | 9 h 31 | 58 % |
| Gain ×1,8 par niveau (au lieu de ×2) | 14 h 23 | 63 % |
| Gain ×2,2 par niveau | 4 h 26 | 48 % |
| Vigile à 0,9 × vitesse conseillée − 1 (règle d'aujourd'hui) | 5 h 41 | 52 % |
| Banc : 1 répétition toutes les 1,5 s (au lieu de 1 s) | 8 h 11 | 53 % |
| Banc : 2 répétitions par seconde | 6 h 15 | 59 % |
| Il obtient 25 % des colis de sa zone (au lieu de 50 %) | 8 h 46 | 65 % |
| Il obtient 100 % des colis de sa zone | 6 h 24 | 52 % |
| Avance sur le vigile 10 studs (au lieu de 20) | 7 h 57 | 56 % |
| Avance sur le vigile 30 studs | 7 h 24 | 56 % |

Les deux vrais boutons de réglage sont le prix et le gain des niveaux de machine : 0,2 de plus ou de moins sur l'un des deux déplace la zone 6 de plusieurs heures. Le reste (rythme du banc, monde sur le serveur, avance sur le vigile) pèse une heure au plus.

## 6. Ce qu'il faudrait changer dans le code (rien n'est fait)

| Fichier | Changement |
| --- | --- |
| `src/shared/Config/Balance.luau` | `Stats` : `StrengthDivisor` 100 → 1 ; ajouter `WalkPerDecade = 4` et `SpeedScale = 100` ; retirer `SpeedToWalkSpeed` |
| `src/shared/Config/Formulas.luau` | `WalkSpeed` : la formule en log ; nouvelles `ShownSpeed(vitesse, mTrail)` et `MachineGain(machine, niveau)` (à la place de `MachineMultiplier`) ; `HitDamage`, `UpgradeCost` et `PlayerWindowHP` gardent leur code |
| `src/shared/Config/Zones.luau` | `AdvisedDamage`, `WindowHP`, `GuardSpeed` ; `AdvisedSpeed` 48 → 46 en zone 6 ; nouveau champ `SpeedRequired` (a101 ajoute aussi un champ ce jour-là : à fusionner) |
| `src/shared/Config/Upgrades.luau`, `Training.luau` | Tapis et banc : gain de base 4 et 6, ×2 par niveau, `Growth` 1,9 → 3,6 ; `EffectPerLevel` et `BaseMultiplier` ne servent plus aux machines |
| `src/shared/Config/Cosmetics.luau` | Multiplicateurs des 5 trails |
| `src/shared/Config/SkillTree.luau` | Seulement si la variante de l'arbre est choisie : `Effects` et `Labels` de Glass et de Walls |
| `src/server/Services/StatsService.luau` | Poser un attribut de plus sur le joueur, la Speed affichée (`Formulas.ShownSpeed`) ; l'attribut `WalkSpeed` reste la vitesse réelle |
| `src/server/Services/TrainingService.luau` | `machineMultiplier` appelle `Formulas.MachineGain` ; les gains flottants passent par `Format.short` |
| `src/server/Services/ToolService.luau` | Rien : l'attribut `Damage` devient la Strength affichée |
| `src/shared/AdvicePanel.luau` | `speedText` lit `SpeedRequired` ; `levels` compare la Speed affichée à `SpeedRequired` (aujourd'hui `WalkSpeed` à `AdvisedSpeed`) ; `strengthText` ne change pas |
| `src/client/Controllers/HudController.luau` | La ligne Speed lit la Speed affichée (aujourd'hui `WalkSpeed`) ; la ligne Strength lit `Damage` (aujourd'hui `Strength`) |
| `StoreInfoController`, `StoreReqSignController`, `ZoneGateController`, bandeau `UI_ZoneBanner` (a101) | Rien s'ils passent par `AdvicePanel` ; sinon lire `SpeedRequired` |
| `src/server/Services/GuardService.luau` | Message « Caught! Recommended speed » : `SpeedRequired` ; vigile de nuit : `AdvisedSpeed + ChaseSpeedBonus` reste un WalkSpeed, rien à changer |
| `src/client/Controllers/UpgradeController.luau` | Texte de l'effet du panneau d'amélioration (« +8/s → +16/s ») |
| `src/shared/Config/Tutorial.luau` | Texte de l'étape 9 (« vitesse 22, dégâts 10 ») |
| `src/shared/Config/TruckEvent.luau` | `MaxHP = 1000` fixe : déjà trop peu aujourd'hui en zone 6, dérisoire sur la nouvelle échelle (question 5 pour Cantin) |
| Docs | Partie 1 : sections 4, 5.1, 7.1, 7.4, 7.5 ; journal des décisions (section 15) |
| Bancs | Ceux qui figent ces valeurs : stats et entraînement, panneaux des vitrines, portes, HUD |

Rien à changer : anti-triche et `MaxWalkSpeed` (les vitesses réelles restent entre 16 et 70), `PvPService` (vitesse de fuite maximale), malus de portage, Adrénaline, revenus, raretés, mutations, receleur, présentoirs. `Format.short` écrit déjà K, M, B, T, Qa. Sauvegarde : pas de nouveau champ, mais les `Stats.Speed` et `Stats.Strength` déjà enregistrés n'ont plus le même sens (question 6 pour Cantin).

## 7. Limites du simulateur

- C'est un modèle, pas un Play. Il joue seul : pas de vols entre joueurs, pas de bagarre à la batte.
- Il ne compte aucune aide : gamepasses, boosts, renaissances, gains hors ligne, récompenses, Index, camion, potions. Le jeu réel ira donc un peu plus vite que ces durées, dans les deux économies.
- Ses hypothèses sont en tête de `modele.luau` (`Modele.Hypotheses` et `Modele.Profils`) : 20 studs d'avance sur le vigile, une répétition de banc par seconde, 6 s pour poser et ouvrir un colis, la part des colis de la zone que le joueur obtient, etc. Aucune n'a été mesurée en Play.
- Le joueur simulé ne se fait jamais rattraper : il n'entre dans une zone que quand le vigile ne peut plus le rejoindre. Un vrai joueur tente plus tôt et perd des colis.
- Les durées bougent beaucoup avec le prix des niveaux (tableau 5.5). Il faudra régler ce nombre en bêta, avec les données de la section 14 du doc.

## 8. Questions

### Pour Cantin

1. **Cible de durée** : zone 6 en 7 à 8 h pour un joueur moyen (5 h pour un acharné, 11 à 12 h pour un prudent), au lieu de 2 h aujourd'hui. D'accord, ou plus court ?
2. **Part d'entraînement** : 55 % du temps aux machines, contre 20 % aujourd'hui. Si c'est trop, on baisse le prix des niveaux et on monte celui des outils et des auras, pour que l'argent retienne plus et le tapis moins.
3. **Prix des outils et des présentoirs** : les premiers coûtent moins d'une minute de revenus dans les deux économies. On les revoit dans la même passe, ou plus tard ?
4. **Potion Speed et bonus de l'Index** : ils multiplient la vitesse de marche (×2, et +3 % par zone complète). Dans un log, c'est énorme : ×2 de marche vaut plus que toute la progression, et les 6 zones de l'Index valent environ ×60 de Speed. On les garde tels quels (une potion reste un moment de folie), ou on les fait multiplier la Speed affichée (potion ×10 = +4 de marche) ?
5. **Camion** : 1 000 PV fixes. Quelle règle sur la nouvelle échelle (par exemple un multiple des PV de la vitrine de la zone où il passe) ?
6. **Profils déjà créés** sur la place DEV : on les remet à zéro au passage, ou on convertit leurs stats ?
7. **Renaissances** (Partie 2) : « +25 % de gains d'entraînement » ne pèse presque plus rien quand un niveau de machine fait ×2. À revoir quand elles seront codées.

### Pour Clément

1. **HUD** : d'accord pour que « Speed » montre la Vitesse entraînée × le trail, et « Strength » les dégâts par coup (outil et aura compris), les deux mêmes nombres que sur les panneaux ? L'autre choix : montrer seulement la stat entraînée, et le panneau annonce la stat qu'il faut « avec l'outil conseillé ».
2. **Seuils** : 3K, 100K, 3M, 100M, 3B pour la Speed, et 5K, 1M, 100M, 10B, 1T pour la Strength. Ça te convient ? La zone 6 serait à 46 de marche conseillée au lieu de 48.
3. **Trails** à ×1.5, ×2, ×3, ×5, ×8 (comme les auras), prix inchangés ?
4. **Vigiles** : au seuil du panneau, le vigile reprend 1 stud par seconde au porteur, qui rentre de justesse. À essayer en Play. Il me manque une mesure : de combien de studs le voleur devance-t-il le vigile quand celui-ci s'élance ? J'ai supposé 20.
5. **Portes** : acceptes-tu qu'un voleur d'une zone au-dessus casse n'importe quelle porte en 2 s ? Sinon, la variante de l'arbre (Glass jusqu'à ×60, Walls jusqu'à ×10, mêmes prix).
6. **Banc** : combien dure une boucle de `BenchLift` ? J'ai compté une répétition par seconde. Ça déplace la zone 6 d'une heure (tableau 5.5).
7. **Textes à prévoir** : « Speed 3K » et « Strength 5K » sur `StoreReqSign`, `BB_StoreInfo`, `BB_ZoneGate` et `UI_ZoneBanner` ; « +48 Speed/s » sur `BB_Gain` ; l'effet sur `UpgradeSign` (« +8/s → +16/s »). Les nombres seront plus longs qu'aujourd'hui (jusqu'à 5 caractères : « 12.3B »).
8. **Niveau de boutique** : il y a 5 niveaux (5 rayons) pour 6 zones. La porte d'un joueur de zone 6 a donc les PV d'une boutique de zone 5. On ajoute un sixième niveau, ou c'est voulu ?

## 9. Relancer l'outil

```
bash tools/ironix/equilibrage/run.sh                    # rapport complet, 25 parties par profil
GRAINES=40 HEURES=60 bash tools/ironix/equilibrage/run.sh
SORTIE=rapport.md bash tools/ironix/equilibrage/run.sh  # écrit aussi le rapport dans un fichier
```

| Fichier | Rôle |
| --- | --- |
| `run.sh` | Assemble les sources de `src/shared/Config` et les modules de l'outil, lance le luau de rokit |
| `chargeur.luau` | Faux `script` et `require` : exécute les vrais modules de Config, sans les modifier |
| `proposition.luau` | La nouvelle échelle : toutes les valeurs de cette note |
| `modele.luau` | Les deux économies, les hypothèses, les 3 profils, la partie simulée |
| `rapport.luau` | Les tableaux |

L'économie actuelle est lue dans le code à chaque lancement : si une valeur de `Config` change, la colonne « avant » suit toute seule.
