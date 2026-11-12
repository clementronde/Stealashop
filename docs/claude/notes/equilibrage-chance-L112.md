# Chance de l'ouverture dans le magasin : proposition chiffrée (liaison L-112)

Note de l'agent a106 (vague 31, 2026-11-12), pour Cantin et Clément. **Rien n'est changé dans le jeu** : aucune valeur de `src/` n'a bougé.

- Outil : `bash tools/ironix/equilibrage/run.sh` (section 12 du rapport, environ 11 s). Les valeurs sont dans `tools/ironix/equilibrage/chance.luau` : on change un nombre, on relance.
- Règles reprises du code : montée de `Shared/ShelfOpenState` (rabats 0,6 s, puis ×1,03 tous les 0,1 s), « ? » plein en 8 s (`Config/Witness`), police au marqueur Call (0,4 s plus tard).

**Décisions de Cantin (2026-11-12, soir), après la première version de cette note :**

1. La table de chance de la section 2 est **adoptée** telle quelle.
2. Le rideau attend la fin d'une ouverture lancée et de la réservation (option A de la section 5).
3. « Open Now » et « Fast Open » s'appliquent à l'antivol.
4. **Les crans ne sont plus limités à 2** : « ça va jusqu'à l'infini, donc on peut avoir Secret ». Tant qu'un cran réussit, la rareté monte, même depuis un Commun de zone 1. Formule codée par a103 : chance du cran n = min(`UpgradeChance` × chance, `UpgradeChanceCap`) × `UpgradeDecay`^(n − 1), arrêt au premier échec ou à `UpgradeTop`. La section 3 propose ses 4 valeurs.

## 1. En bref

| | Aujourd'hui (ouvert en base, 2 crans) | 1re version (2 crans) | Crans sans limite, V0 d'a103 (0,10 ; 0,9 ; 1) | **Crans sans limite, proposé (0,08 ; 0,9 ; 0,7)** |
| --- | --- | --- | --- | --- |
| Multiplicateur de rareté moyen Standard / Premium / Luxe (zones 2 à 6) | 1,89 / 5,68 / 18,9 | 2,18 / 7,11 / 22,6 | 11,3 / 18,3 / 39,7 | **2,37 / 7,35 / 24,9** |
| Secret depuis un Commun de zone 1, par ouverture | jamais | jamais | 1 sur 137 | **1 sur 83 500** |
| Un Secret, joueur moyen en zones 2 à 6 | 1 par 43 h | 1 par 43 h | 1 par 1,7 h | **1 par 8,6 h** |
| Entrée en zone 6, joueur moyen, économie actuelle | 1 h 56 | 1 h 54 | 1 h 26 | **1 h 51** |
| Entrée en zone 6, joueur moyen, économie L-108 proposée | 6 h 52 | 6 h 17 | 5 h 01 | **6 h 16** |

La V0 d'a103 (aucune baisse d'un cran à l'autre) casse l'économie : un ×10 sur un Commun donne un Secret une fois sur deux. Avec le réglage proposé, l'économie reste celle de la 1re version. Le Secret devient environ 5 fois plus fréquent : c'est le prix de « on peut avoir Secret ».

## 2. La table de chance (adoptée)

Durée = rabats + montée (`ShelfOpenState.revealDelay`). « ? » = remplissage des témoins à la sortie de l'objet, l'ouverture lancée « ? » vide. Crans : avec le réglage proposé de la section 3.

| Chance tirée | Poids | Objet sorti à | « ? » à la sortie | Police | 1er cran | 2 crans ou plus | 3 crans ou plus |
| --- | --- | --- | --- | --- | --- | --- | --- |
| ×1 | 55 | 0,6 s | 8 % | non | 8 % | 0,45 % | 0,02 % |
| ×1,5 | 20 | 2,0 s | 25 % | non | 12 % | 1,0 % | 0,06 % |
| ×2 | 12 | 3,0 s | 38 % | non | 16 % | 1,8 % | 0,14 % |
| ×3 | 7 | 4,4 s | 55 % (orange) | non | 24 % | 4,0 % | 0,47 % |
| ×5 | 4 | 6,1 s | 76 % (orange) | non | 40 % | 11 % | 2,2 % |
| ×8 | 1,5 | 7,7 s | 96 % (rouge) | non, de justesse | 64 % | 29 % | 9,0 % |
| ×10 | 0,5 | 8,4 s | plein | **oui** | 80 % | 45 % | 18 % |

Valeurs à coller dans `src/shared/Config/ShelfOpen.luau` (adoptées par Cantin le 2026-11-12) :

```lua
	-- Adopté (Cantin, 2026-11-12 ; note docs/claude/notes/equilibrage-chance-L112.md, agent a106).
	-- 55 % sans chance ; ×8 frôle la police (« ? » à 96 %) ; ×10 la fait venir (« ? » plein à 8 s).
	LuckTable = {
		{ Luck = 1, Weight = 55 },
		{ Luck = 1.5, Weight = 20 },
		{ Luck = 2, Weight = 12 },
		{ Luck = 3, Weight = 7 },
		{ Luck = 5, Weight = 4 },
		{ Luck = 8, Weight = 1.5 },
		{ Luck = 10, Weight = 0.5 },
	} :: { LuckEntry },
```

Pourquoi ces valeurs :

- **×10 est le plafond naturel.** Le « ? » est plein à 8,0 s et la police part à 8,4 s, l'heure de sortie d'un ×10. Une chance plus haute serait arrêtée par la police vers ×10 de toute façon.
- **×8 est le palier « de justesse »** : « ? » rouge à 96 %, pas de police.
- En moyenne : chance ×1,67, ouverture de 1,8 s, police dans 0,5 % des ouvertures.

## 3. Crans sans limite : les 4 valeurs proposées

Valeurs à coller dans `src/shared/Config/ShelfOpen.luau` (**proposé**, a106, à la place de `UpgradeMax` et des V0 d'a103) :

```lua
	-- Proposé (a106, note equilibrage-chance-L112, section 3). Chance du cran n :
	-- min(UpgradeChance × chance, UpgradeChanceCap) × UpgradeDecay^(n − 1) ; arrêt au premier échec ou à UpgradeTop.
	UpgradeChance = 0.08, -- ×1 : 8 % au premier cran ; ×10 : 80 %
	UpgradeChanceCap = 0.9, -- jamais un cran sûr (aucun palier de la table ne l'atteint avec 0,08)
	UpgradeDecay = 0.7, -- chaque cran : la chance du précédent × 0,7
	UpgradeTop = "Secret", -- Divine exclue
```

Pourquoi :

- **`UpgradeDecay` est le seul vrai levier.** Sans baisse (1), un Commun ouvert à ×10 monte à Secret une fois sur deux (0,9⁶), et l'économie double. Avec 0,7, la chance fond d'un cran à l'autre : à ×10, 80 %, puis 56 %, 39 %, 27 %, 19 %, 13 %.
- **`UpgradeChance` passe de 0,10 à 0,08** pour garder l'économie de la 1re version (multiplicateur moyen +9 % sur un Standard, +3 % sur un Premium, +10 % sur un Luxe). Un tirage ×1 a 8 % de chance de cran au lieu de 10 % : c'est le seul recul.
- **`UpgradeChanceCap` à 0,9** ne sert que de garde-fou (Chance ×3, ou une table plus généreuse plus tard).
- **Un ×10 reste un vrai jackpot sans donner presque toujours le maximum** : sur un Commun, 20 % sans cran, 1,5 cran en moyenne, 18 % d'Épique ou mieux, 0,12 % de Secret.

### Secret depuis la zone 1, et sur une session

| | Probabilité | Soit |
| --- | --- | --- |
| Une ouverture en zone 1 (un Commun) | 0,0012 % | 1 sur 83 500 ouvertures |
| Toute la phase de la zone 1 (7 colis pour le joueur moyen) | 0,0084 % | 1 joueur sur 12 000 |
| Une heure de jeu en zones 2 à 6 (77 colis : 47 % Standard, 38 % Premium, 15 % Luxe) | 11,6 % | 1 Secret par 8,6 h |
| Même heure, 2 crans (1re version) | 2,3 % | 1 par 43 h |
| Même heure, V0 d'a103 | 58 % | 1 par 1,7 h |

Possible même en zone 1, mais un joueur sur 12 000 : c'est la « queue très faible mais réelle » de l'idée de Clément. En zones 2 à 6, le Secret vient surtout des Luxe (0,73 % au lieu de 0,2 %) et des Premium (0,11 % au lieu de 0).

### Les autres réglages essayés (section 12.4 du rapport)

| UpgradeChance | Cap | Decay | M moyen Std / Prem / Luxe | Secret depuis zone 1 | Secret par heure | ×10 : aucun cran / crans moyens |
| --- | --- | --- | --- | --- | --- | --- |
| 0,10 | 0,9 | 1 (V0 d'a103) | 11,3 / 18,3 / 39,7 | 1 sur 137 | 1 par 1,7 h | 10 % / 4,2 |
| 0,10 | 0,9 | 0,75 | 3,07 / 9,23 / 29,7 | 1 sur 10 200 | 1 par 5,3 h | 10 % / 2,0 |
| 0,10 | 0,9 | 0,6 | 2,49 / 7,96 / 27,1 | 1 sur 292 000 | 1 par 7,7 h | 10 % / 1,6 |
| **0,08** | **0,9** | **0,7** | **2,37 / 7,35 / 24,9** | **1 sur 83 500** | **1 par 8,6 h** | **20 % / 1,5** |
| 0,07 | 0,9 | 0,75 | 2,27 / 6,94 / 23,6 | 1 sur 66 100 | 1 par 10 h | 30 % / 1,3 |
| 0,06 | 0,9 | 0,75 | 2,10 / 6,38 / 22,0 | 1 sur 166 000 | 1 par 12,6 h | 40 % / 1,0 |

Pour un Secret plus rare que 1 par 8,6 h sans toucher au reste, la formule ne suffit pas : le premier cran d'un Mythique (Luxe) vise déjà Secret. Il faudrait baisser la part de Secret des Luxe dans `Rarities.BoxOdds` (0,2 %), qui viendrait alors surtout des crans.

### Pour a103

- Les crans ne regardent plus la zone ni le type de colis (règle « Infini » du simulateur). Mais le catalogue de la zone 1 n'a **que des Communs** (et le Rare du tuto) : un Commun de zone 1 monté en Peu commun n'a aucun objet à donner. Il faut une règle de repli, par exemple un objet de cette rareté pris dans la zone la plus proche au-dessus. Le Secret, lui, est tiré toutes zones.
- Un contenu imposé (colis garanti du tuto) n'est toujours jamais amélioré : c'est ce que suppose le simulateur.

## 4. Effet sur l'économie

### Rareté obtenue par type de colis

« M » = multiplicateur de revenu moyen de la rareté (Commun ×1 … Secret ×1000). « Brut » = cotes de `Rarities.BoxOdds` sans cran. Zones 2 à 6 (mêmes cotes partout).

| Colis | Mode | M moyen | ≥ Épique | ≥ Légendaire | ≥ Mythique | Secret |
| --- | --- | --- | --- | --- | --- | --- |
| Standard | Brut | 1,64 | 1,00 % | 0 % | 0 % | 0 % |
| Standard | Aujourd'hui (2 crans à ×1) | 1,89 | 1,92 % | 0 % | 0 % | 0 % |
| Standard | 1re version (2 crans) | 2,18 | 3,17 % | 0 % | 0 % | 0 % |
| Standard | **Sans limite, proposé** | **2,37** | 2,65 % | 0,41 % | 0,07 % | 0,012 % |
| Premium | Brut | 4,55 | 10,0 % | 2,00 % | 0,20 % | 0 % |
| Premium | Aujourd'hui | 5,68 | 12,4 % | 3,00 % | 0,46 % | 0 % |
| Premium | 1re version | 7,11 | 14,9 % | 4,25 % | 0,87 % | 0 % |
| Premium | **Sans limite, proposé** | **7,35** | 13,5 % | 3,64 % | 0,71 % | 0,11 % |
| Luxe | Brut | 15,9 | 35,0 % | 10,0 % | 2,00 % | 0,20 % |
| Luxe | Aujourd'hui | 18,9 | 39,3 % | 12,9 % | 3,05 % | 0,20 % |
| Luxe | 1re version | 22,6 | 42,8 % | 16,0 % | 4,48 % | 0,20 % |
| Luxe | **Sans limite, proposé** | **24,9** | 40,9 % | 14,3 % | 3,75 % | 0,73 % |

Zone 1 (que des Communs) : M moyen 1,28 au lieu de 1 ; 0,38 % d'Épique ou mieux. Le Standard n'est plus bloqué à Épique.

### Parties simulées (section 12.3 du rapport, 60 parties par ligne)

Le simulateur joue l'ouverture dans le magasin (`Modele.Ouverture`, branchée par `chance.luau`) : chance tirée, montée passée dans le magasin, police traitée comme une seconde poursuite, antivol au lieu de l'attente `OpenDelay`, rideau qui attend l'ouverture. Sans l'accroche, les sections 6 à 11 sortent exactement comme avant.

| Économie | Profil | Aujourd'hui (2 crans à ×1) | 1re version (2 crans) | Sans limite, V0 d'a103 | **Sans limite, proposé** |
| --- | --- | --- | --- | --- | --- |
| Actuelle | Prudent | 2 h 21 | 2 h 04 | 1 h 42 | **2 h 05** |
| Actuelle | Moyen | 1 h 56 | 1 h 54 | 1 h 26 | **1 h 51** |
| Actuelle | Acharné | 1 h 45 | 1 h 31 | 1 h 13 | **1 h 41** |
| L-108 proposée | Moyen | 6 h 52 | 6 h 17 | 5 h 01 | **6 h 16** |

(Entrée en zone 6, médiane.) Le réglage proposé reste proche de la 1re version (de −3 % à +11 %, dans le bruit des parties) ; la V0 d'a103 fait gagner 18 à 25 % de temps. L'antivol, plus court que l'ancienne attente, ne compte presque pas dans ce modèle ; il compte en PvP, que le simulateur ne joue pas.

## 5. Le chrono de 10 s et l'antivol

### Le chrono : décidé, le rideau attend l'ouverture (option A)

Après la casse, le joueur a 10 s (`Balance.Heist.Duration`), dont environ 3 s pour atteindre le rayon et 0,3 à 1 s pour la prise. Sans changement, ×8 et ×10 ne pouvaient jamais être pris, et ×5 pas sur un Luxe :

| Chance | Objet sorti à | Prise finie avant 10 s ? (Standard / Luxe) |
| --- | --- | --- |
| ×1 à ×3 | 0,6 à 4,4 s | oui / oui |
| ×5 | 6,1 s | oui / non |
| ×8 | 7,7 s | non / non |
| ×10 | 8,4 s | non / non |

Décision de Cantin : un magasin ne ferme pas tant qu'un colis y est « Opening », ni avant la fin de la réservation (`ShelfReservedUntil`) d'un objet sorti et pas encore pris. Aucune nouvelle ouverture après la fin du chrono. Les témoins deviennent la seule limite.

### La réservation de 5 s : gardée

Avec le rideau qui attend, elle tient aussi après un ×10.

### L'antivol (5 s Commun → 180 s Divine) : gardé

- Il remplace l'attente d'ouverture d'aujourd'hui (10 s Commun → 3 min Légendaire, 15 min Secret). Le joueur touche ses revenus plus tôt, mais l'effet sur la progression est faible (section 4).
- Le vrai coût de l'antivol est le risque de vol. 60 s pour un Légendaire, c'est déjà long à défendre seul.
- Décision de Cantin : « Open Now » et « Fast Open » s'appliquent à l'antivol.

### Deux joueurs dans le même magasin (pour a103)

Le « ? » est commun au magasin. Si deux joueurs ouvrent en même temps, `Calm` à la sortie du premier objet vide le « ? » pendant que le second compteur monte encore. Proposé : n'appeler `Calm` que s'il ne reste aucun colis « Opening » dans ce magasin, sinon relancer `Raise` pour l'autre ouvreur.

## 6. « Chance ×3 » (Robux)

Proposé : **Chance ×3 multiplie la chance des crans, pas la chance tirée.** Le compteur, sa durée et les témoins ne changent pas ; seul le résultat est meilleur. Dans la formule : min(`UpgradeChance` × chance × 3, `UpgradeChanceCap`) × `UpgradeDecay`^(n − 1). Si elle multipliait la chance tirée, 13 % des ouvertures feraient venir la police (au lieu de 0,5 %) : on vendrait une punition.

Avec les crans sans limite et le réglage proposé (zones 2 à 6) :

| | Sans boost | Chance ×2 | Chance ×3 |
| --- | --- | --- | --- |
| Premium : M moyen ; ≥ Légendaire ; Secret | 7,35 ; 3,6 % ; 0,11 % | 13,0 ; 6,2 % ; 0,43 % | 19,1 ; 8,8 % ; 0,79 % |
| Luxe : M moyen ; ≥ Légendaire ; Secret | 24,9 ; 14,3 % ; 0,73 % | 40,5 ; 19,6 % ; 1,8 % | 57,0 ; 24,8 % ; 3,0 % |
| Zone 1 : M moyen ; Secret | 1,28 ; 0,001 % | 1,98 ; 0,011 % | 2,75 ; 0,021 % |

Chance ×3 multiplie les revenus des colis par plus de 2 et le Secret par 4 à 7. Pendant 15 min, c'est fort, mais pas absurde pour 79 Robux. Si c'est trop, un « Chance ×2 » suffit.

À afficher (cotes) : pour la zone du joueur et chaque type de colis, la part de chaque rareté **finale**, avec et sans le boost (les tableaux de la section 12.1 du rapport ; `Chance.Repartition` de `chance.luau` se porte tel quel en Luau strict dans `Shared`). Comme prévu dans la Partie 2 : masquer l'offre si `PolicyService` renvoie `ArePaidRandomItemsRestricted`.

## 7. À trancher

**Cantin**

1. Les 4 valeurs des crans (section 3) : 0,08 ; 0,9 ; 0,7 ; Secret.
2. Un Secret par 8,6 h de jeu au lieu d'un par 43 h : acceptable, ou baisser aussi la part de Secret des Luxe dans `Rarities.BoxOdds` ?
3. Chance ×3 sur les crans (proposé) : garder ×3, ou ×2.

**Clément et a103**

1. L'objet donné quand un cran vise une rareté sans objet dans la zone (zone 1 surtout) : repli proposé, un objet de la zone la plus proche au-dessus.
2. Un signe à l'écran pour le palier ×8 « de justesse », et un effet propre au jackpot ×10 (Clément).
