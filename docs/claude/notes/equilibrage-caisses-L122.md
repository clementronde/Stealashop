# Caisses : rareté de l'objet tirée à l'ouverture (proposition chiffrée, L-122)

Note de l'agent a108 (vague 32, 2026-11-13), pour Clément (qui décide) et Cantin. **Rien n'est changé dans le jeu** : aucune valeur de `src/` n'a bougé. Toutes les valeurs ci-dessous sont **proposées**.

- La règle (Cantin, 2026-11-13) : la rareté posée sur le rayon devient celle de la **caisse**. À l'ouverture, la rareté de l'objet est tirée dans `BoxRarityOdds[caisse]`, après que la chance tirée (×1 à ×10) a multiplié certains poids. Elle remplace les crans de la vague 31.
- Outil : `bash tools/ironix/equilibrage/run.sh` (section 13 du rapport, environ 20 s ; `GRAINES=60` pour les chiffres de cette note, environ 50 s). Les tables sont dans `tools/ironix/equilibrage/caisses.luau` : on change un nombre, on relance.
- La rareté de la caisse sur le rayon ne change pas : `ShelfBoxes.ZoneOdds` (zone 1 : que des caisses Communes) et `Rarities.BoxOdds` (zones 2 à 6).

## 1. En bref

| | Avant (crans de la vague 31) | **Après (proposé, AboveBox)** |
| --- | --- | --- |
| M moyen Standard / Premium / Luxe (zones 2 à 6) | 2,37 / 7,35 / 24,9 | **2,51 / 7,39 / 23,5** |
| M moyen en zone 1 | 1,28 | **1,37** |
| Entrée en zone 6, joueur moyen, économie actuelle | 1 h 45 | **1 h 48** |
| Entrée en zone 6, joueur moyen, économie L-108 | 6 h 21 | **6 h 31** |
| Secret par ouverture en zone 1 | 1 sur 83 500 | **1 sur 68 800** |
| Un Secret, joueur moyen en zones 2 à 6 | 1 par 8,4 h | **1 par 7,9 h** |

« M » = multiplicateur de revenu de la rareté (Commun ×1 … Secret ×1000). L'économie reste celle de la vague 31 (de 0 à +3 % sur l'entrée en zone 6, dans le bruit des parties).

## 2. Les 8 tables (proposé)

Forme commune : environ **57 % de la rareté de la caisse**, puis 20 %, 8 %, 3 %, 2 %, 1 %, 0,5 % en descendant, et **9 %, 2 %, 0,3 %, 0,05 %, 0,008 %** en montant, coupée aux bords et ramenée à 100. Donc : surtout sa rareté et en dessous (environ 88 %), un peu au-dessus (environ 11 %), toujours un peu de Commun, rien de garanti.

La caisse Commune est à part, plus serrée : c'est toute la zone 1 et 70 % des Standard. Son Secret (0,001 %) est le « très rare mais possible ».

Valeurs à coller dans `src/shared/Config/ShelfOpen.luau` (chaque ligne fait 100) :

```lua
	-- Proposé (a108, note docs/claude/notes/equilibrage-caisses-L122.md), à valider par Clément.
	-- BoxRarityOdds[rareté de la caisse][rareté de l'objet] = poids (relatifs ; ici en %, chaque ligne fait 100).
	-- Divine : 0 tant que Items.Divines est vide ; la caisse Divine n'est jamais posée (Rarities.BoxOdds.Divine = 0).
	BoxRarityOdds = {
		Common = { Common = 88.841, Uncommon = 9, Rare = 1.8, Epic = 0.3, Legendary = 0.05, Mythic = 0.008, Secret = 0.001, Divine = 0 },
		Uncommon = { Common = 23, Uncommon = 64.29, Rare = 10, Epic = 2.3, Legendary = 0.34, Mythic = 0.06, Secret = 0.01, Divine = 0 },
		Rare = { Common = 8.3, Uncommon = 21, Rare = 58.94, Epic = 9.3, Legendary = 2.1, Mythic = 0.31, Secret = 0.05, Divine = 0 },
		Epic = { Common = 3, Uncommon = 8, Rare = 20, Epic = 57.6, Legendary = 9.1, Mythic = 2, Secret = 0.3, Divine = 0 },
		Legendary = { Common = 2, Uncommon = 3, Rare = 8, Epic = 20, Legendary = 56, Mythic = 9, Secret = 2, Divine = 0 },
		Mythic = { Common = 1, Uncommon = 2, Rare = 3, Epic = 8, Legendary = 20, Mythic = 57, Secret = 9, Divine = 0 },
		Secret = { Common = 0.5, Uncommon = 1, Rare = 2, Epic = 3.5, Legendary = 8.5, Mythic = 22, Secret = 62.5, Divine = 0 },
		Divine = { Common = 0.5, Uncommon = 1, Rare = 2, Epic = 3, Legendary = 3.5, Mythic = 8, Secret = 22, Divine = 60 },
	},
	-- Proposé (a108) : la chance multiplie les raretés au-dessus de celle de la caisse ; s'il n'y en a aucune
	-- (caisse Secret sans Divine), la rareté de la caisse elle-même. Puis normalisation.
	LuckBoost = "AboveBox",
```

### Divine

- Le catalogue n'a **aucun objet Divine** (`Items.Divines` vide). La colonne Divine vaut donc 0 dans les 7 premières tables : un poids sans objet ferait sortir un Secret en silence (repli vers la rareté en dessous).
- La caisse Divine n'est jamais posée (`Rarities.BoxOdds.Divine = 0`). Sa table est prête quand même : 60 % Divine.
- Quand Clément livrera des objets Divine, poser la colonne Divine comme le reste de la forme (proposé) : caisse Secret 9 (pris sur Secret, 62,5 → 53,5), Mythique 2 (57 → 55), Légendaire 0,3, Épique 0,05, Rare 0,008, en dessous 0. Puis la part Divine des Luxe dans `Rarities.BoxOdds` (déjà proposée : 0,02 %).

## 3. La règle de la chance

La chance tirée à l'ouverture est celle de la table adoptée (×1 55 %, ×1,5 20 %, ×2 12 %, ×3 7 %, ×5 4 %, ×8 1,5 %, ×10 0,5 %).

**AboveLowest (contrat de la vague 32) n'a presque aucun effet au-dessus de la caisse Commune.** Elle multiplie tout sauf la plus basse de la table, donc seul le Commun perd sa part. Sur une caisse Rare, ×10 fait passer « au-dessus de la caisse » de 11,8 % à 12,7 %.

**Proposé : AboveBox.** La chance multiplie seulement les raretés au-dessus de la caisse. Un ×N veut dire « N fois plus de chances de dépasser sa caisse » : c'est ce que le joueur lit dans « ×N LUCK ».

Part de l'objet au-dessus de la caisse, et Secret, à ×1 / ×3 / ×10 :

| Caisse | AboveLowest : au-dessus | **AboveBox : au-dessus** | AboveLowest : Secret | **AboveBox : Secret** |
| --- | --- | --- | --- | --- |
| Commune | 11 % / 27 % / 56 % | **11 % / 27 % / 56 %** | 0,001 / 0,002 / 0,005 % | **0,001 / 0,002 / 0,005 %** |
| Peu commune | 13 % / 15 % / 16 % | **13 % / 30 % / 59 %** | 0,010 / 0,012 / 0,013 % | **0,010 / 0,024 / 0,047 %** |
| Rare | 12 % / 12 % / 13 % | **12 % / 29 % / 57 %** | 0,05 / 0,05 / 0,05 % | **0,05 / 0,12 / 0,24 %** |
| Épique | 11 % / 12 % / 12 % | **11 % / 28 % / 56 %** | 0,30 / 0,31 / 0,31 % | **0,30 / 0,73 / 1,5 %** |
| Légendaire | 11 % / 11 % / 11 % | **11 % / 27 % / 55 %** | 2,0 / 2,0 / 2,0 % | **2,0 / 4,9 / 10 %** |
| Mythique | 9 % / 9 % / 9 % | **9 % / 23 % / 50 %** | 9,0 / 9,1 / 9,1 % | **9,0 / 23 / 50 %** |
| Secret | (rien au-dessus) | (le Secret lui-même) | 62,5 / 62,7 / 62,8 % | **62,5 / 83 / 94 %** |

Avec AboveLowest, il faudrait des tables bien plus généreuses au-dessus pour garder l'économie (Luxe : M 19,8 au lieu de 24,9 ; entrée en zone 6 : 1 h 57 au lieu de 1 h 45), et la chance resterait muette sur les caisses rares.

## 4. Chances par caisse : sans chance, ×3 et ×10 (AboveBox, proposé)

En %. Ligne « ×1 » = la table telle quelle.

| Caisse | Chance | Com | PeuC | Rare | Épi | Lég | Myth | Sec |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Commune | ×1 | 88,8 | 9,0 | 1,8 | 0,30 | 0,050 | 0,008 | 0,001 |
| | ×3 | 72,6 | 22,1 | 4,4 | 0,74 | 0,12 | 0,020 | 0,0025 |
| | ×10 | 44,3 | 44,9 | 9,0 | 1,5 | 0,25 | 0,040 | 0,005 |
| Peu commune | ×1 | 23,0 | 64,3 | 10,0 | 2,3 | 0,34 | 0,060 | 0,010 |
| | ×3 | 18,3 | 51,3 | 23,9 | 5,5 | 0,81 | 0,14 | 0,024 |
| | ×10 | 10,7 | 30,0 | 46,6 | 10,7 | 1,6 | 0,28 | 0,047 |
| Rare | ×1 | 8,3 | 21,0 | 58,9 | 9,3 | 2,1 | 0,31 | 0,050 |
| | ×3 | 6,7 | 17,0 | 47,7 | 22,6 | 5,1 | 0,75 | 0,12 |
| | ×10 | 4,0 | 10,2 | 28,6 | 45,2 | 10,2 | 1,5 | 0,24 |
| Épique | ×1 | 3,0 | 8,0 | 20,0 | 57,6 | 9,1 | 2,0 | 0,30 |
| | ×3 | 2,4 | 6,5 | 16,3 | 46,9 | 22,2 | 4,9 | 0,73 |
| | ×10 | 1,5 | 4,0 | 9,9 | 28,4 | 44,9 | 9,9 | 1,5 |
| Légendaire | ×1 | 2,0 | 3,0 | 8,0 | 20,0 | 56,0 | 9,0 | 2,0 |
| | ×3 | 1,6 | 2,5 | 6,6 | 16,4 | 45,9 | 22,1 | 4,9 |
| | ×10 | 1,0 | 1,5 | 4,0 | 10,1 | 28,1 | 45,2 | 10,1 |
| Mythique | ×1 | 1,0 | 2,0 | 3,0 | 8,0 | 20,0 | 57,0 | 9,0 |
| | ×3 | 0,85 | 1,7 | 2,5 | 6,8 | 16,9 | 48,3 | 22,9 |
| | ×10 | 0,55 | 1,1 | 1,7 | 4,4 | 11,0 | 31,5 | 49,7 |
| Secret | ×1 | 0,50 | 1,0 | 2,0 | 3,5 | 8,5 | 22,0 | 62,5 |
| | ×3 | 0,22 | 0,44 | 0,89 | 1,6 | 3,8 | 9,8 | 83,3 |
| | ×10 | 0,08 | 0,15 | 0,30 | 0,53 | 1,3 | 3,3 | 94,3 |

Un ×10 sur une caisse Commune : une fois sur deux mieux que Commun. Sur une caisse Mythique : un Secret une fois sur deux.

## 5. Effet sur l'économie

### Rareté obtenue par zone et par type de colis

Toutes chances mêlées. Rang moyen : 1 = Commun … 7 = Secret.

| Zone | Colis | Mode | Rang moyen | M moyen | ≥ Épique | ≥ Légendaire | Secret |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | tous | Avant (crans) | 1,16 | 1,28 | 0,38 % | 0,07 % | 0,0012 % |
| 1 | tous | **Caisses, AboveBox** | **1,20** | **1,37** | 0,52 % | 0,09 % | 0,0015 % |
| 2 à 6 | Standard | Avant (crans) | 1,55 | 2,37 | 2,65 % | 0,41 % | 0,012 % |
| 2 à 6 | Standard | Caisses, AboveLowest | 1,51 | 2,30 | 2,53 % | 0,45 % | 0,010 % |
| 2 à 6 | Standard | **Caisses, AboveBox** | **1,52** | **2,51** | 3,12 % | 0,60 % | 0,014 % |
| 2 à 6 | Premium | Avant (crans) | 2,23 | 7,35 | 13,5 % | 3,64 % | 0,11 % |
| 2 à 6 | Premium | Caisses, AboveLowest | 2,07 | 6,31 | 10,9 % | 2,99 % | 0,09 % |
| 2 à 6 | Premium | **Caisses, AboveBox** | **2,09** | **7,39** | 12,4 % | 3,68 % | 0,13 % |
| 2 à 6 | Luxe | Avant (crans) | 3,38 | 24,9 | 40,9 % | 14,3 % | 0,73 % |
| 2 à 6 | Luxe | Caisses, AboveLowest | 3,03 | 19,8 | 31,8 % | 11,1 % | 0,55 % |
| 2 à 6 | Luxe | **Caisses, AboveBox** | **3,08** | **23,5** | 34,4 % | 13,0 % | 0,75 % |

Le rang moyen baisse un peu (une caisse rare peut donner moins bien), mais le revenu moyen tient : les gros coups viennent de la chance.

### Parties simulées : entrée en zone 6 (médiane, 60 parties par ligne)

| Économie | Profil | Avant (crans) | Caisses, AboveLowest | **Caisses, AboveBox** |
| --- | --- | --- | --- | --- |
| Actuelle | Prudent | 2 h 11 | — | **2 h 12** |
| Actuelle | Moyen | 1 h 45 | 1 h 57 | **1 h 48** |
| Actuelle | Acharné | 1 h 31 | — | **1 h 31** |
| L-108 proposée | Moyen | 6 h 21 | 6 h 32 | **6 h 31** |

### Le Secret

Joueur moyen : 6 colis en zone 1, puis 80 colis par heure (Standard 48 %, Premium 37 %, Luxe 15 %).

| Mode | Une ouverture en zone 1 | Toute la zone 1 | Une heure en zones 2 à 6 |
| --- | --- | --- | --- |
| Avant (crans) | 1 sur 83 500 | 1 joueur sur 13 900 | 11,8 %, soit 1 par 8,4 h |
| Caisses, AboveLowest | 1 sur 68 800 | 1 joueur sur 11 400 | 9,2 %, soit 1 par 10,8 h |
| **Caisses, AboveBox** | **1 sur 68 800** | **1 joueur sur 11 400** | **12,6 %, soit 1 par 7,9 h** |

En zones 2 à 6, le Secret vient surtout des caisses Mythiques et Secret des Luxe (environ la moitié), puis des Légendaires.

## 6. Pour a109 (le code)

- `LuckBoost = "AboveBox"` est une valeur de plus à côté de `"AboveLowest"` : multiplier les poids des raretés d'ordre > caisse ; si aucune n'a de poids, multiplier la rareté de la caisse. Le simulateur le fait dans `Caisses.Booste` (`tools/ironix/equilibrage/caisses.luau`).
- Le simulateur suppose le repli déjà prévu : rareté sans objet dans la zone → zone + 1, puis − 1… ; Divine sans objet → Secret. Il compte le revenu à la zone du magasin, même pour un objet d'une zone voisine (en zone 1, un Peu commun vient de la zone 2 : un peu plus de revenu en vrai).
- Un contenu imposé (premier colis du tuto, Rare garanti) n'est pas tiré dans la table.
- La section 12 du rapport ne lit plus les crans de `Config/ShelfOpen` (que la vague 32 retire) : les 2 crans de la 1re version y sont figés (`Chance.Crans_2`). Quand `ShelfOpen.BoxRarityOdds` existera, la section 13 ajoute une ligne « Dans le jeu ».

## 7. À trancher

**Clément**

1. Les 8 tables de la section 2 (forme : 57 % la rareté de la caisse, environ 11 % au-dessus, toujours un peu de Commun).
2. La règle de la chance : **AboveBox** (proposé) ou AboveLowest (contrat actuel, presque sans effet au-dessus d'une caisse Commune).
3. Le Secret : 1 par 7,9 h de jeu et 1 ouverture sur 68 800 en zone 1. Plus rare : baisser les 9 % de Secret de la caisse Mythique, ou les 0,2 % de caisses Secret des Luxe (`Rarities.BoxOdds`).
4. Divine : colonne à 0 tant qu'il n'y a pas d'objet Divine, puis les valeurs prévues de la section 2.
5. L'étiquette du rayon montre la rareté de la **caisse**, plus celle du contenu : faut-il un mot à l'écran (« caisse Rare ») pour que le joueur ne croie pas l'objet garanti ?

**Cantin**

1. « Chance ×3 » (Robux) : proposé de multiplier la chance utilisée dans la table (pas le compteur ni les témoins), comme à la vague 31. Avec AboveBox, c'est trois fois plus de chances de dépasser sa caisse.
