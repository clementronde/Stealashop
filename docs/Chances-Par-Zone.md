# a424 — L-317 : chances d'ouverture par zone (rapport seulement, rien n'est changé dans le jeu)

Base lue : worktree `agents/a424` (09d2dcb). Branche `agents/a421` regardée : elle ne touche ni aux chances ni à la cote
(seulement l'attribut `RevealId` du colis et l'invite « Open », L-316) ; elle ne change rien ici.

Chiffres calculés hors du jeu (script Python qui refait `ShelfBoxes.ContentWeights`, `Shared/ItemOdds` et
`Formulas.ItemIncome` à l'identique ; scratchpad `a424_odds.py`, `a424_solve.py`, `a424_v0.py`). Ils retombent exactement
sur les repères du 20/11 (« la plus basse ≈ la moitié », Mythique zone 6 ≈ 0,5 %, Secret ≈ 0,03 %), ce qui valide le calcul.

## Q1 — D'où vient le « 1 sur 5 » en zone 6

### Le chemin d'une ouverture (serveur)

1. **Rareté du colis** posé sur le rayon : `Rarities.ZoneOdds[zone]` (`src/shared/Config/Rarities.luau`, l. 209-216).
   Zone 6 : Rare 38,9 · Épique 36,4 · Légendaire 24,235 · Mythique 0,42 · Secret 0,045 %.
2. **Chance de la boîte** : `ShelfOpen.LuckTable` (×1 à ×10, 55 % de ×1), × `ServerLuck` (Robux) — `StoreHeistService`
   l. 2327 et 2934. Pas de chance du joueur, des potions ni de l'arbre dans ce tirage (`Reveal.EventLuck = false`).
3. **Rareté de l'objet** : `ShelfBoxes.ContentWeights(rareté du colis, chance, zone)` (`Config/ShelfBoxes.luau` l. 96) =
   `ShelfOpen.BoxRarityOdds[colis]`, limitée aux raretés de la zone, × chance au-dessus du colis, × `ShelfStepUp` 0,05
   par cran au-dessus. **Rien ne réduit les raretés sous le colis** : un colis Épique donne encore ≈ 26 % de Rare
   en zone 6 (poids 20 sur ≈ 78, Commun et Peu commun n'y existant pas), un Légendaire ≈ 9 % de Rare.
4. **Objet** dans sa rareté et sa zone (3 objets par rareté en zone 6, poids 1 ; 0,91 ; 0,83), puis effet et poids.

Résultat en zone 6, part réelle de chaque rareté d'objet : **Rare 50 %**, Épique 33 %, Légendaire 16,5 %,
Mythique 0,5 %, Secret 0,034 %. C'est voulu par le V0 du 20/11 (« la plus basse ≈ la moitié »), et c'est ce que Clément
ne veut plus.

### Ce que l'écran affiche (`BB_UnboxOdds.Odds`, puis `BB_Reveal.Odds`)

- **Cote finale** = 1 / la vraie chance d'avoir **cet objet précis, avec sa mutation**, sur un emplacement de rayon de sa
  zone (`Shared/ItemOdds.Chance`, l. 70, arrondi `Formulas.UnboxOdds`), calculée par le serveur et envoyée dans le plan.
  Pour un objet Rare de zone 6 sans effet ni Huge/Colossal : 50 % × 1/3 environ × 0,83 = **« 1 IN 7 » ou « 1 IN 8 »**
  (Épique : 1 IN 10 à 12 ; Légendaire : 1 IN 20 à 24 ; Mythique : 1 IN 660 à 800 ; Secret : 1 IN 3 500).
- **Cote qui monte** pendant les coups et les silhouettes (`Config/Unbox.luau` l. 355 et 359, `UnboxPlan.climb` l. 237) :
  elle part **toujours de « 1 IN 2 »** (`OddsClimb.Start = 2`, quelle que soit la zone) et monte jusqu'à la cote finale
  (Offset 20 : 2, 3, 4, 5, 6, 7).
- Donc **une ouverture sur deux en zone 6 (un Rare) montre « 1 IN 2… 1 IN 5… » et finit à « 1 IN 7 ou 8 »** : c'est le
  « 1 sur 5 » de Clément. Ce n'est pas un bug d'affichage : le chiffre dit vrai.

### L'écran dit-il la même chose que le tirage du serveur ?

Oui. `ItemOdds` lit les mêmes tables et la même fonction (`ShelfBoxes.ContentWeights`) que le tirage de
`StoreHeistService`, moyennées sur `LuckTable`. Écarts connus, tous voulus et notés dans le code :
- la chance du serveur achetée en Robux (`ServerLuck`) agit sur le tirage mais pas sur la cote affichée ;
- le contenu imposé du tuto (zone 1) montre une cote tirée dans `OddsRanges`, pas la vraie ;
- la cote est celle de l'objet dans **sa zone** et sa mutation, pas celle de la rareté, ni « sur tout le jeu » ;
- la montée part de 1 IN 2 partout : c'est un effet de mise en scène, pas une probabilité.

Le colis de zone offert (`Rewards.ZoneBox.BestZone`, 15 min de jeu) tire la rareté de l'objet directement dans
`ZoneOdds` (rareté des **colis**, × 1,5 sur la plus haute), pas dans la part réelle des objets : il suit lui aussi tout
changement de `ZoneOdds`.

## Pourquoi changer seulement `ZoneOdds` ne suffit pas

Même avec le colis de la rareté la plus basse presque à 0 dans chaque zone, les colis du dessus « fuient » vers le bas
(point 3) : la plus basse ne descend pas sous **22 à 26 %** des objets (zone 3 : Commun 26 % ; zones 4 à 6 : 23 %).
Il faut un second réglage, le pendant de `ShelfStepUp` vers le bas.

**V0 proposé (Cantin, 24/11) : `ShelfOpen.ShelfStepDown = 0,25`** — sur un rayon de magasin (zone donnée), le poids
d'une rareté **sous** le colis est multiplié par 0,25 par cran (1 cran : × 0,25 ; 2 crans : × 0,0625). Il irait dans
`ShelfBoxes.ContentWeights`, que lisent déjà le tirage et `ItemOdds` : l'écran resterait juste sans autre travail.
Camion, tour, cadeaux et rayons d'événement (sans zone) : inchangés, comme `ShelfStepUp`.

## Q2 — Tableau V0 zone par zone (V0 proposé, Cantin, 24/11)

Règle visée, en part réelle des objets : la plus basse de la zone s'efface à **10 %** (zone 3 : 20 %), la suivante devient
la rareté normale de la zone (≈ 73 à 78 %), la rareté du dessus garde sa part d'aujourd'hui (≈ 15 %), la rareté qui
apparaît garde ses ≈ 2 % ; Mythique 0,5 % et Secret ≈ 0,03 % en zone 6 ne bougent pas. Aucune rareté ne tombe à 0 : le
catalogue (v2 comme v3) garde des objets de la plus basse dans chaque zone, et `Config/Items` refuse un objet d'une
rareté absente de sa zone.

### Rareté des colis sur les rayons (`Rarities.ZoneOdds`, à poser avec `ShelfStepDown = 0,25`)

| Zone | Avant (20/11) | V0 proposé (Cantin, 24/11) |
| --- | --- | --- |
| 1 | C 100 | C 100 |
| 2 | C 98,4 · U 1,6 | C 98,7 · U 1,3 |
| 3 | C 33 · U 65 · R 2 | C 13 · U 85,9 · R 1,1 |
| 4 | C 38,5 · U 37,5 · R 21,2 · E 2,8 | C 3,5 · U 79 · R 15,5 · E 2 |
| 5 | U 38,7 · R 37,5 · E 21 · L 2,8 | U 3,5 · R 79 · E 15,5 · L 2 |
| 6 | R 38,9 · E 36,4 · L 24,235 · M 0,42 · S 0,045 | R 3,7 · E 78,7 · L 17,27 · M 0,3 · S 0,03 |

### Part réelle des objets (ce que le joueur obtient)

| Zone | Avant | Après (V0) |
| --- | --- | --- |
| 1 | C 100 | C 100 |
| 2 | C 98 · U 2 | C 98 · U 2 |
| 3 | C 49,9 · U 48,2 · R 1,95 | C 19,9 · U 78,1 · R 2,0 |
| 4 | C 50,0 · U 32,9 · R 15,0 · E 2,0 | C 10,0 · U 72,9 · R 15,0 · E 2,0 |
| 5 | U 50,0 · R 33,0 · E 15,0 · L 2,0 | U 10,0 · R 72,9 · E 15,1 · L 2,0 |
| 6 | R 50,0 · E 33,0 · L 16,5 · M 0,50 · S 0,034 | R 10,0 · E 73,0 · L 16,5 · M 0,49 · S 0,033 |

### Revenu moyen d'un objet sorti d'un colis du rayon ($/s de base)

Calcul : `Formulas.ItemIncome` (revenu de la rareté × (1 + 0,25 × zones au-dessus de sa première zone) × 1,1^(rang − 1)),
pondéré par `DrawWeight` et par la part réelle de chaque rareté. Poids (kg) et effets sont tirés à part de la rareté :
ils multiplient avant et après de la même façon (≈ × 1,3), d'où des montants de base.

| Zone | Avant | Après (V0) | Écart |
| --- | --- | --- | --- |
| 1 | 1,6 | 1,6 | 0 |
| 2 | 1,9 | 1,9 | 0 |
| 3 | 8,0 | 11,1 | + 39 % |
| 4 | 28,4 | 33,1 | + 17 % |
| 5 | 209 | 244 | + 17 % |
| 6 | 1 280 | 1 527 | + 19 % |

Le revenu reste porté par les raretés du haut (Légendaire en zone 6), qui ne bougent pas : l'économie ne saute pas,
elle avance d'environ un sixième plus vite dans les zones 4 à 6 (zone 3 : + 3 $/s par objet).

### Cote affichée, objet le plus fréquent de chaque rareté (« 1 IN N », sans effet ni Huge/Colossal)

| Zone | Avant | Après (V0) |
| --- | --- | --- |
| 3 | C 10 · U 10 · R 210 | C 25 · U 6 · R 210 |
| 4 | C 8 · U 13 · R 28 · E 160 | C 42 · U 6 · R 28 · E 160 |
| 5 | U 7 · R 10 · E 22 · L 170 | U 33 · R 5 · E 22 · L 160 |
| 6 | R 7 · E 10 · L 20 · M 660 · S 3 500 | R 33 · E 5 · L 20 · M 670 · S 3 600 |

## Effets à connaître avant de décider

1. **Le « 1 sur 5 » ne disparaît pas, il change de rareté.** Chaque zone n'a que 12 à 16 objets et 3 à 5 par rareté :
   la rareté la plus fréquente de la zone donne toujours une cote de 1 IN 5 à 10 sur son meilleur objet. Avec le V0, en
   zone 6, c'est l'Épique qui affiche « 1 IN 5 » (73 % des ouvertures). Pour ne plus voir de petite cote en zone 6, il
   faudrait étaler les objets sur 3 raretés à parts presque égales : le revenu moyen de la zone 6 ferait alors environ
   × 2 (le Légendaire passerait de 16 à 40 %). Ou bien changer ce que dit le chiffre (question 3 plus bas).
2. **Cote inversée** : la rareté qui s'efface affiche une cote plus haute que celle du dessus (zone 6 : un Rare « 1 IN 33 »,
   un Épique « 1 IN 5 »). C'est vrai, mais ça peut surprendre.
3. **Index** : les objets de la rareté effacée deviennent 5 fois plus durs à trouver (les 3 Rares de la zone 6, les
   3 Peu communs de la zone 5, les 4 Communs de la zone 4 ; 2,5 fois pour les 5 Communs de la zone 3). Chaque objet
   n'existe que dans sa zone : il n'y a pas d'autre endroit où les trouver.
4. **Rayons** : en zone 6, 79 % des colis posés seraient des colis Épiques (étiquette et couleur), au lieu d'un mélange
   Rare / Épique / Légendaire. Le temps de prise suit (0,6 s Épique). Zone 4 : surtout des Peu communs (0,3 s).
5. **Colis de zone offert « BestZone »** (15 min de jeu) : il tire dans `ZoneOdds` lui-même ; revenu moyen − 8 à − 13 %
   en zones 4 à 6 (moins de colis Légendaires), + 12 % en zone 3. « NextZone » (60 min) ne change pas (poids fixes).
6. **Camion, tour de la fortune, colis offerts par type** : inchangés (`Rarities.BoxOdds`, sans zone).
7. **À mettre à jour en codant** : le banc qui vérifie les repères du 20/11 (« la plus basse ≈ la moitié », a262), les
   commentaires de `Rarities.ZoneOdds`, de `Rewards.ZoneBox.BestZone` (« Commun 33 → 32 % ») et de `ShelfOpen`.

## Sans règle nouvelle (si Clément refuse `ShelfStepDown`)

`ZoneOdds` seul, colis de la plus basse à 0,1 % : la plus basse reste à 22-26 % des objets (zone 6 : R 22,7 · E 64,4 ·
L 12,4 · M 0,44 · S 0,03), revenu − 1 à + 32 % selon la zone. Moins net que le V0, mais sans nouveau réglage.

## Questions pour Clément (via Cantin), avec la V0

1. Le tableau V0 (la plus basse à 10 %, 20 % en zone 3 ; revenu + 17 à 19 % en zones 4 à 6) te va-t-il ?
   V0 : oui, avec `ShelfStepDown = 0,25`.
2. « Ça devrait plus exister » : la rareté la plus basse doit-elle disparaître **tout à fait** d'une zone (alors ses
   objets changent de rareté ou de zone au catalogue v3) ? V0 : non, elle reste à 10 %.
3. Le chiffre « 1 IN N » : garder la vraie chance de l'objet dans sa zone (aujourd'hui, donc « 1 IN 5 » possible en
   zone 6 sur l'Épique), ou montrer autre chose (par exemple la chance de l'objet sur tout le jeu) ? Et la montée doit-elle
   toujours partir de « 1 IN 2 » ? V0 : on garde la vraie cote et le départ à 1 IN 2.

## Phrase pour la liaison (réponse à L-317)

> (Q1) Le « 1 sur 5 » est vrai : en zone 6 la moitié des objets sortis sont des Rares (V0 du 20/11, « la plus basse ≈ la
> moitié » : colis Rare 38,9 % et colis Épiques et Légendaires qui donnent encore 26 % et 9 % de Rare), soit
> « 1 IN 7 ou 8 » par objet Rare, et la cote qui monte part toujours de « 1 IN 2 » (2, 3, 4, 5…). L'écran calcule avec les
> mêmes tables que le tirage du serveur (seule la chance du serveur achetée en Robux n'y est pas). (Q2) Tableau V0 dans
> `docs/Chances-Par-Zone.md` : la plus basse de chaque zone passe à 10 % des objets (zone 3 : 20 %), la suivante à
> ≈ 73 %, le haut ne bouge pas (zone 6 : R 10, E 73, L 16,5, M 0,5, S 0,03) ; il faut un nouveau réglage
> `ShelfStepDown = 0,25` (sinon la plus basse ne descend pas sous 22 %) ; revenu moyen d'un colis + 17 à 19 % en zones 4
> à 6 (zone 6 : 1 280 → 1 527 $/s de base). Attention : le « 1 IN 5 » passe alors sur l'Épique en zone 6 (3 objets par
> rareté). Rien n'est changé dans le jeu tant que tu n'as pas dit oui.
