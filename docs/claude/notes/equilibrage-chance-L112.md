# Chance de l'ouverture dans le magasin : proposition chiffrée (liaison L-112)

Note de l'agent a106 (vague 31, 2026-11-12), pour Cantin et Clément. **Rien n'est changé dans le jeu** : aucune valeur de `src/` n'a bougé. Tout ce qui est marqué « proposé » attend l'accord de Cantin.

- Point de départ : les décisions de Cantin du 2026-11-12 (L-112) : chance **tirée au hasard** au lancement, compteur qui monte jusqu'à elle, 2 crans au plus à 10 % × la chance, « ? » des témoins qui se remplit pendant la montée.
- Outil : `bash tools/ironix/equilibrage/run.sh` (section 12 du rapport, 10 s). Les valeurs sont dans `tools/ironix/equilibrage/chance.luau` : on change un poids, on relance.
- Règles reprises telles quelles du code : montée de `Shared/ShelfOpenState` (rabats 0,6 s, puis ×1,03 tous les 0,1 s), « ? » plein en 8 s (`Config/Witness`), crans de `UnboxService.rollUpgrades` (jamais vers Secret, jamais vers une rareté que ce colis ne donne pas dans sa zone).

## 1. En bref

| | Aujourd'hui (ouvert en base) | Table proposée |
| --- | --- | --- |
| Ouvertures sans chance (objet à 0,6 s) | — | 55 % |
| Durée moyenne d'une ouverture | — | 1,8 s |
| Ouvertures qui font venir la police | 0 % | 0,5 % (le ×10) |
| Crans par colis, en moyenne | 0,10 | 0,21 |
| Multiplicateur de rareté moyen d'un Premium / d'un Luxe (zones 2 à 6) | 5,68 / 18,9 | 7,11 / 22,6 (+25 % / +19 %) |
| Entrée en zone 6, joueur moyen, économie actuelle | 1 h 56 | 1 h 54 (dans le bruit) |
| Entrée en zone 6, joueur moyen, économie L-108 proposée | 6 h 52 | 6 h 17 (−9 %) |

La chance pèse peu sur l'économie : elle double les crans, mais un cran reste rare. Son vrai rôle est le frisson du compteur.

**Un point bloque la table telle quelle : le chrono de 10 s du magasin** (section 5). Sans changement, les tirages ×8 et ×10 ne peuvent jamais être pris.

## 2. La table proposée

Durée = rabats + montée (`ShelfOpenState.revealDelay`). « ? » = remplissage des témoins à la sortie de l'objet, l'ouverture lancée « ? » vide.

| Chance tirée | Poids | Objet sorti à | « ? » à la sortie | Police | Chance d'un cran | 0 / 1 / 2 crans | Ce que ressent le joueur |
| --- | --- | --- | --- | --- | --- | --- | --- |
| ×1 | 55 | 0,6 s | 8 % | non | 10 % | 90 / 9 / 1 % | rien, l'objet sort tout de suite |
| ×1,5 | 20 | 2,0 s | 25 % | non | 15 % | 85 / 13 / 2 % | petit frisson |
| ×2 | 12 | 3,0 s | 38 % | non | 20 % | 80 / 16 / 4 % | |
| ×3 | 7 | 4,4 s | 55 % (orange) | non | 30 % | 70 / 21 / 9 % | bon coup |
| ×5 | 4 | 6,1 s | 76 % (orange) | non | 50 % | 50 / 25 / 25 % | gros coup |
| ×8 | 1,5 | 7,7 s | 96 % (rouge) | non, de justesse | 80 % | 20 / 16 / 64 % | frôle la police |
| ×10 | 0,5 | 8,4 s | plein | **oui** | 100 % | 0 / 0 / 100 % | jackpot : 2 crans sûrs, mais la police part |

Valeurs prêtes à coller dans `src/shared/Config/ShelfOpen.luau` (**proposé**, a106) :

```lua
	-- Proposé (a106, note docs/claude/notes/equilibrage-chance-L112.md), à valider par Cantin.
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

- **×10 est le plafond naturel.** Le « ? » est plein à 8,0 s et la police part au marqueur Call (0,4 s), donc à 8,4 s : c'est exactement la sortie d'un ×10. Une chance plus haute serait arrêtée par la police vers ×10 de toute façon : inutile de la mettre dans la table.
- **×8 est le palier « de justesse »** : « ? » rouge à 96 %, pas de police. C'est l'histoire à raconter (« j'ai eu un ×8, le témoin allait appeler »).
- **Écart avec la V0 du jeu** : même chance moyenne (×1,67 contre ×1,62), mais la police deux fois plus rare (0,5 % contre 1 %) et un palier ×8 en plus. L'effet sur l'économie est le même (section 4).
- Un tirage ×1 garde 10 % de chance de cran : c'est la règle d'aujourd'hui en base (chance ×1), rien n'est perdu par rapport à l'ancienne ouverture.

## 3. UpgradeMax et UpgradeChance : à garder (2 et 10 %)

- Avec la table proposée, la chance d'un cran va de 10 % (×1) à 100 % (×10). Monter `UpgradeChance` ferait de chaque ×5 un double cran presque sûr ; la baisser rendrait le ×1 moins bon qu'aujourd'hui.
- 3 crans au lieu de 2 : surtout utile aux Luxe (M moyen 22,6 → 33,8, voir 12.2 du rapport). Pas nécessaire.

**La « queue très faible jusqu'à Secret, même en zone 1 » de Clément est impossible avec 2 crans**, pour trois raisons cumulées :

1. La zone 1 ne tire que des Communs (L-033), et un cran ne vise jamais une rareté que le colis ne donne pas dans sa zone : en zone 1, aucun cran.
2. Même sans cette règle, le catalogue de la zone 1 n'a que des Communs (et le Rare du tuto) : rien à viser.
3. De Commun à Secret, il faut 6 crans. Avec 2 crans, le Secret ne se gagne qu'en partant d'un Légendaire, et la règle du code l'interdit (jamais de cran vers Secret).

Si Cantin et Clément veulent cette queue, il faut une autre règle, par exemple **« jackpot Secret »** : un tirage ×10 a en plus une petite chance (par exemple 1 %) de remplacer le contenu par un Secret, toutes zones. Ça donnerait 1 Secret pour 20 000 ouvertures. Rien n'est chiffré au-delà : à décider d'abord.

Variante « crans libres » (un cran peut viser Secret, la zone 1 reste bloquée) : en zones 2 à 6, Secret 0,12 % d'un Premium et 0,87 % d'un Luxe (au lieu de 0 % et 0,2 %). C'est ×4 sur le Secret des Luxe : déconseillé sans relire la table 7.3.

## 4. Effet sur l'économie

### Rareté obtenue par type de colis (zones 2 à 6 ; la zone 1 ne donne que des Communs dans tous les cas)

« M » = multiplicateur de revenu moyen de la rareté (Commun ×1 … Secret ×1000). « Brut » = cotes de `Rarities.BoxOdds` sans cran.

| Colis | Mode | M moyen | ≥ Épique | ≥ Légendaire | ≥ Mythique |
| --- | --- | --- | --- | --- | --- |
| Standard | Brut | 1,64 | 1,00 % | 0 % | 0 % |
| Standard | Aujourd'hui (crans à ×1) | 1,89 | 1,92 % | 0 % | 0 % |
| Standard | Table proposée | 2,18 | 3,17 % | 0 % | 0 % |
| Premium | Brut | 4,55 | 10,0 % | 2,00 % | 0,20 % |
| Premium | Aujourd'hui | 5,68 | 12,4 % | 3,00 % | 0,46 % |
| Premium | Table proposée | 7,11 | 14,9 % | 4,25 % | 0,87 % |
| Luxe | Brut | 15,9 | 35,0 % | 10,0 % | 2,00 % |
| Luxe | Aujourd'hui | 18,9 | 39,3 % | 12,9 % | 3,05 % |
| Luxe | Table proposée | 22,6 | 42,8 % | 16,0 % | 4,48 % |

Le Standard plafonne à Épique (il ne donne jamais de Légendaire), le Premium et le Luxe à Mythique (jamais de cran vers Secret).

### Parties simulées (section 12.3 du rapport, 60 parties par ligne)

Le simulateur sait maintenant jouer l'ouverture dans le magasin (`Modele.Ouverture`, branchée par `chance.luau`) : chance tirée, montée passée dans le magasin, police traitée comme une seconde poursuite, antivol au lieu de l'attente `OpenDelay`. Sans l'accroche, les sections 6 à 11 sortent exactement comme avant.

| Économie | Profil | Aujourd'hui (crans à ×1) | Table V0 du jeu | Table proposée |
| --- | --- | --- | --- | --- |
| Actuelle | Prudent | 2 h 21 | 2 h 08 | 2 h 04 |
| Actuelle | Moyen | 1 h 56 | 1 h 51 | 1 h 54 |
| Actuelle | Acharné | 1 h 45 | 1 h 31 | 1 h 31 |
| L-108 proposée | Moyen | 6 h 52 | 6 h 11 | 6 h 17 |

(Entrée en zone 6, médiane.) Effet : 0 à −13 % selon le profil. L'antivol, plus court que l'ancienne attente, ne compte presque pas dans ce modèle (table proposée avec l'attente `OpenDelay` : 1 h 51 et 6 h 21) ; il compte en PvP, que le simulateur ne joue pas.

## 5. Le chrono de 10 s et l'antivol

### Le chrono de 10 s : à revoir

Après la casse, le joueur a 10 s (`Balance.Heist.Duration`). Il lui faut environ 3 s pour atteindre le rayon, puis la prise demande 0,3 à 1 s selon le colis. Il reste donc **6 à 6,7 s pour l'ouverture**. À la fin du chrono, un joueur qui ne porte rien est sorti du magasin.

| Chance | Objet sorti à | Prise finie avant 10 s ? (Standard / Luxe) |
| --- | --- | --- |
| ×1 à ×3 | 0,6 à 4,4 s | oui / oui |
| ×5 | 6,1 s | oui / non |
| ×8 | 7,7 s | non / non |
| ×10 | 8,4 s | non / non |

Tel quel, le chrono coupe avant les témoins : **le joueur perdrait ses meilleurs tirages**, sans y être pour rien (la chance est tirée, pas choisie). C'est la pire frustration possible. Proposé, au choix de Cantin :

- **A (conseillé)** : *le rideau attend l'ouverture*. Un magasin ne ferme pas tant qu'un colis y est « Opening », ni avant la fin de la réservation (`ShelfReservedUntil`) d'un objet sorti et pas encore pris. Aucune nouvelle ouverture après la fin du chrono. C'est la règle qui existe déjà pour un joueur qui porte un colis ou un vigile dans le magasin. Les témoins deviennent la seule limite, comme le veut la décision de Cantin.
- **B** : allonger le chrono à 14 s. Plus simple, mais tous les braquages durent plus longtemps, ×10 + réservation de 5 s ne tient toujours pas.

Le simulateur suppose A.

### La réservation de 5 s

À garder. Avec A, elle tient aussi après un ×10.

### L'antivol (5 s Commun → 180 s Divine) : à garder

- Il remplace l'attente d'ouverture d'aujourd'hui (10 s Commun → 3 min Légendaire, 15 min Secret, 30 min Divine). Le joueur touche ses revenus bien plus tôt, mais l'effet sur la progression est faible (voir 4).
- Le vrai coût de l'antivol est le risque de vol, pas le temps. 60 s pour un Légendaire, c'est déjà long à défendre ; plus long serait punitif pour un joueur seul.
- Effet de bord : avec `Features.ShelfOpen`, les produits Robux « Ouvrir maintenant » et « Ouverture rapide » n'ont plus rien à accélérer. À décider : les cacher, ou les faire agir sur l'antivol.

### Deux joueurs dans le même magasin (pour a103)

Le « ? » est commun au magasin. Si deux joueurs ouvrent en même temps, `Calm` à la sortie du premier objet vide le « ? » pendant que le second compteur monte encore. Proposé : n'appeler `Calm` que s'il ne reste aucun colis « Opening » dans ce magasin, sinon relancer `Raise` pour l'autre ouvreur.

## 6. « Chance ×3 » (Robux)

Proposé : **Chance ×3 multiplie la chance d'un cran, pas la chance tirée.** Le compteur, sa durée et les témoins ne changent pas ; seul le résultat est meilleur. Si elle multipliait la chance tirée, chaque ouverture durerait plus longtemps et 13 % des ouvertures feraient venir la police (au lieu de 0,5 %) : on vendrait une punition.

| Zones 2 à 6 | Sans boost | Avec Chance ×3 (sur les crans) |
| --- | --- | --- |
| Premium : M moyen, ≥ Épique, ≥ Légendaire | 7,11 ; 14,9 % ; 4,25 % | 14,4 ; 27,8 % ; 10,6 % |
| Luxe : M moyen, ≥ Épique, ≥ Légendaire | 22,6 ; 42,8 % ; 16,0 % | 40,8 ; 59,3 % ; 31,3 % |

À afficher (cotes) : pour la zone du joueur et chaque type de colis, la part de chaque rareté **finale**, avec et sans le boost (exactement les tableaux de la section 12.1 du rapport ; `Chance.Repartition` de `chance.luau` se porte tel quel en Luau strict dans `Shared`). Comme prévu dans la Partie 2 : masquer l'offre si `PolicyService` renvoie `ArePaidRandomItemsRestricted`. À noter : avec ×3, un cran est sûr dès ×3,3 de chance tirée. Si c'est trop fort, un « Chance ×2 » suffit.

## 7. À trancher

**Cantin**

1. La table proposée (section 2), ou la V0 du jeu.
2. Le chrono : A (le rideau attend l'ouverture) ou B (chrono à 14 s).
3. Une queue jusqu'à Secret : non, ou une règle « jackpot Secret » à part (section 3).
4. « Ouvrir maintenant » et « Ouverture rapide » quand `Features.ShelfOpen` est actif : cachés, ou appliqués à l'antivol.
5. Chance ×3 sur les crans (proposé) ; ×3 ou ×2.

**Clément**

1. Le palier ×8 « de justesse » (« ? » rouge à 96 %) : lui faut-il un signe à l'écran (son, tremblement du compteur) ?
2. Le ×10 : police à 8,4 s pile à la sortie de l'objet. Faut-il un effet propre au jackpot (le compteur qui « casse » en rouge) ?
