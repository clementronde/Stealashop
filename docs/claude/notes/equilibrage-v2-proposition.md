# Rééquilibrage v2 : tout recalculé à partir de zéro

Note de l'agent a132 (2026-11-14), pour Cantin et Clément. **Rien n'est changé dans le jeu** : aucune valeur de `src/` n'a bougé. Toutes les valeurs nouvelles de cette note sont des **V0 proposés**, avec leur calcul ; seules les décisions de la section 1 viennent de Cantin.

- Outil : `RAPPORT=v2 bash tools/ironix/equilibrage/run.sh` (hors Studio, 2 min environ). Il lit les vraies tables de `src/shared/Config`, fait jouer 3 profils de joueurs, 25 parties chacun, et sort les tableaux de cette note.
- Toutes les valeurs proposées sont dans un seul fichier : `tools/ironix/equilibrage/proposition_v2.luau`. On change un nombre, on relance (`COURT=1` : seulement les temps par zone, 20 s).
- Cette note remplace `equilibrage-proposition.md` (L-108 point 1, L-116 point 4), qui gardait le banc.
- Nombres écrits comme dans le jeu (`Format.short` : K, M, B, T, Qa).

## 1. Décisions de départ (Cantin, 2026-11-14)

1. **Tapis** : niveau 1 = +1 de vitesse par seconde, ×2 à chaque niveau, jusqu'au niveau 20 (2^19 = 524K par seconde).
2. **Plus de banc.** Dégâts d'un coup = dégâts de l'arme × multiplicateur de l'aura (× potion). L'aura est le multiplicateur de force.
3. **Potion de force : ×1,5** (au lieu de ×2). Elle n'entre dans **aucun** calcul de seuil ni de PV : tous les calculs se font avec arme × aura.
4. **Zone 6 en 7 h 30** de jeu actif pour le joueur moyen.
5. **Zone 6 jamais cassable seul.** PV de la vitrine = ce que font **deux** des meilleurs joueurs possibles (meilleure arme × meilleure aura, tout au maximum, sans potion) pendant le chrono de casse de 13 s. Un joueur seul avec la potion reste dessous (1,5 < 2).
6. Tout le reste s'adapte à ces cibles.

## 2. En bref

| | Aujourd'hui | Proposition v2 |
| --- | --- | --- |
| Entrée en zone 6, joueur moyen | 2 h 09 | **7 h 35** (7 h 27 sur 75 parties) |
| Stats entraînées | Vitesse (tapis) et Force (banc) | Vitesse seule |
| Dégâts d'un coup | arme × (1 + Force / 100) × aura | arme × aura |
| Strength du panneau de la zone 6 | 40K | 2M (Angle Grinder 100K × Royal ×20) |
| Vitrine de la zone 6 | 1.4M PV, cassable seul | 374M PV, il faut être deux (choix de Cantin, 14/11 ; 320M proposé d'abord) |
| Speed du panneau de la zone 6 | 48 (un WalkSpeed) | 3B (marche réelle : 46) |
| Vitesse de marche au plafond de 70 | au bout de 29 min | jamais en pratique (45 à l'entrée en zone 6) |
| Niveau du tapis à l'entrée en zone 6 | 20 sur 20 | 15 sur 20 |
| Part du temps au tapis | 20 % (tapis et banc) | 43 % |

## 3. Les formules proposées

```
Speed affichée    = Vitesse entraînée × M trail
WalkSpeed         = min(70, 16 + 4 × log10(1 + Speed affichée / 100))
Strength affichée = dégâts d'un coup = P arme × M aura          (× 1,5 sous potion de force)
Gain du tapis     = 2^(niveau − 1) par seconde, niveau de 1 à 20 (× 1,5 avec les taps)
Prix du niveau    = 150 × 3,8^(niveau − 1) pour passer du niveau au suivant
```

### 3.1 La règle de la vitesse : « un zéro de plus = +4 de marche »

La stat Speed monte sans fin (2^19 par seconde au niveau 20), la marche réelle reste entre 16 et 70. **Chaque fois que la Speed affichée est multipliée par 10, la marche gagne 4.** C'est la règle déjà proposée en L-116, gardée : la map, l'anti-triche, les animations de course et le plafond de 70 restent valables.

| Speed affichée | WalkSpeed | Repère |
| --- | --- | --- |
| 0 | 16.0 | |
| 100 | 17.2 | |
| 1K | 20.2 | |
| 3K | 22.0 | panneau zone 2 |
| 10K | 24.0 | |
| 100K | 28.0 | panneau zone 3 |
| 1M | 32.0 | |
| 3M | 33.9 | panneau zone 4 |
| 10M | 36.0 | |
| 100M | 40.0 | panneau zone 5 |
| 1B | 44.0 | |
| 3B | 45.9 | panneau zone 6 |
| 10B | 48.0 | |
| 100B | 52.0 | |
| 1T | 56.0 | tapis au niveau 20, trail ×12, taps : après 30 h de tapis environ |
| 10T | 60.0 | |
| 3.2Qa | 70.0 | plafond (une sécurité, plus un but) |

Calcul du repère « 1T » : 524 288 × 1,5 (taps) × 12 (Hyperspace) = 9,4M de Speed affichée par seconde ; 1T / 9,4M = 106 000 s, soit 29 h 30.

Un seul nombre sur le HUD et sur les panneaux : la Speed affichée (trail compris) et la Strength (arme × aura).

## 4. Les valeurs proposées, par fichier de Config

### 4.1 `Config/Zones`

| Zone | Speed du panneau (nouveau champ `SpeedRequired`) | `AdvisedSpeed` (marche) | Kit du panneau | `AdvisedDamage` = Strength du panneau | `WindowHP` | PV / dégâts | `GuardSpeed` | `BaseIncome` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 16 → 0 | 16 → 16 | Fists | 1 → 1 | 35 → 35 | 35 → 35 | 13.4 → 13.4 | 1 → 1 |
| 2 | 22 → 3K | 22 → 22 | Wrench × Spark | 10 → 10 | 350 → 350 | 35 → 35 | 18.8 → 20.8 | 8 → 8 |
| 3 | 28 → 100K | 28 → 28 | Crowbar × Flame | 80 → 120 | 2.8K → 4.2K | 35 → 35 | 24.2 → 26.2 | 60 → 60 |
| 4 | 34 → 3M | 34 → 34 | Hammer × Lightning | 600 → 1.5K | 21K → 52.5K | 35 → 35 | 29.6 → 31.5 | 450 → 450 |
| 5 | 40 → 100M | 40 → 40 | Sledgehammer × Plasma | 5K → 20K | 175K → 700K | 35 → 35 | 35 → 37 | 3.5K → 3.5K |
| 6 | 48 → 3B | 48 → 46 | Angle Grinder × Royal | 40K → 2M | 1.4M → **374M** | 35 → **187** | 42.2 → 42.3 | 25K → 25K |

D'où viennent ces nombres :

- **Speed** : un pas de ×30 environ par zone, soit +6 de marche, comme aujourd'hui (22, 28, 34, 40). Zone 6 à 46 au lieu de 48, pour garder le même pas (à 48, il faudrait 10B).
- **Strength** : c'est le produit du kit de la zone, une arme et une aura. Il n'y a plus de stat à entraîner : le panneau passe au vert quand on a acheté le kit. Pas de ×8 à ×13 par zone, puis ×100 vers la zone 6 (deux achats intermédiaires existent, section 4.3).
- **PV, zones 1 à 5** : 35 × dégâts du panneau, règle gardée. Seul, au panneau : 11,9 s à 4 coups/s, 7,1 s à 6 coups/s, 3,9 s à 10 coups/s, sous le chrono de 13 s. Avec le kit de la zone d'avant, même à 10 coups/s : jamais (la régénération de 3 %/s l'emporte).
- **PV, zone 6** : section 5.
- **Vigile** : 0,9 × marche conseillée + 1, arrondi à 0,1 (aujourd'hui − 1) ; zone 1 gardée à 13,4 (zone du tuto). Avec − 1, on sème le vigile avec 8 fois moins de Speed que le panneau (2 de marche = ×3 de Speed). Avec + 1, le porteur au seuil du panneau perd 1 stud par seconde et rentre de justesse : le joueur moyen entre avec la moitié de la Speed du panneau. À essayer en Play.
- **Revenus de base** : inchangés. Les cibles de durée sont tenues sans y toucher, et le pas de ×7 à ×8 par zone reste cohérent avec des kits environ 20 fois plus chers d'une zone à l'autre. Les multiplicateurs de rareté (`Config/Rarities`), les mutations et le receleur (120 ×) ne changent pas non plus.
- `ReturnDistance`, `Theme`, `Stores` : inchangés.

### 4.2 `Config/Upgrades` et `Config/Training` (tapis)

| Clé | Aujourd'hui | Proposition |
| --- | --- | --- |
| Gain du tapis | (1 + 0,5 × n) par seconde, n de 0 à 20 | 2^(niveau − 1) par seconde, niveau de 1 à 20 (décision de Cantin) |
| `Upgrades.Treadmill.BaseCost` | 200 | 150 (V0 proposé) |
| `Upgrades.Treadmill.Growth` | 1,9 | 3,8 (V0 proposé, réglé au simulateur) |
| `Upgrades.Treadmill.MaxLevel` | 20 achats (niveaux 0 à 20) | 19 achats (niveaux affichés 1 à 20) |
| `Upgrades.Treadmill.EffectPerLevel`, `Training.BaseMultiplier` | 0,5 et 1 | ne servent plus au tapis |
| `Training.Treadmill.TapBonus` | +50 % | +50 % (inchangé) |
| `Upgrades.Bench`, `Training.Bench` | banc | **retirés** (le niveau reste dans les profils, sans effet, comme `UnboxBenches`) |
| `Upgrades.DisplaySlots` | 500 × 2,5^n | inchangé |

Niveau affiché = niveau enregistré + 1 : le joueur commence au niveau 1 (+1 par seconde). Le modèle du tapis garde sa règle, lue sur le niveau affiché : `floor(niveau / 2) + 1`, donc Base au niveau 1, Silver aux niveaux 2 et 3… Void au niveau 20.

| Niveau | Gain par seconde (avant → après) | Prix pour passer à ce niveau (avant → après) | Cumul (avant → après) | Modèle du tapis |
| --- | --- | --- | --- | --- |
| 1 | 1 → 1 | — | — | Base |
| 2 | 1.5 → 2 | $200 → $150 | $200 → $150 | Silver |
| 3 | 2 → 4 | $380 → $570 | $580 → $720 | Silver |
| 4 | 2.5 → 8 | $722 → $2.1K | $1.3K → $2.8K | Gold |
| 5 | 3 → 16 | $1.3K → $8.2K | $2.6K → $11.1K | Gold |
| 6 | 3.5 → 32 | $2.6K → $31.2K | $5.2K → $42.3K | CashRegister |
| 7 | 4 → 64 | $4.9K → $118K | $10.2K → $161K | CashRegister |
| 8 | 4.5 → 128 | $9.4K → $451K | $19.6K → $612K | Police |
| 9 | 5 → 256 | $17.8K → $1.7M | $37.5K → $2.3M | Police |
| 10 | 5.5 → 512 | $33.9K → $6.5M | $71.4K → $8.8M | LaserVault |
| 11 | 6 → 1K | $64.5K → $24.7M | $136K → $33.6M | LaserVault |
| 12 | 6.5 → 2K | $122K → $94.1M | $258K → $127M | Ice |
| 13 | 7 → 4K | $232K → $357M | $491K → $485M | Ice |
| 14 | 7.5 → 8.1K | $442K → $1.3B | $934K → $1.8B | Toxic |
| 15 | 8 → 16.3K | $841K → $5.1B | $1.7M → $7B | Toxic |
| 16 | 8.5 → 32.7K | $1.5M → $19.6B | $3.3M → $26.6B | Candy |
| 17 | 9 → 65.5K | $3M → $74.6B | $6.4M → $101B | Candy |
| 18 | 9.5 → 131K | $5.7M → $283B | $12.1M → $384B | Fire |
| 19 | 10 → 262K | $10.9M → $1T | $23.1M → $1.4T | Fire |
| 20 | 10.5 → 524K | $20.8M → $4T | $43.9M → $5.5T | Void |

Le joueur moyen est au niveau 3 à l'entrée en zone 2, 6 en zone 3, 9 en zone 4, 12 en zone 5, 15 en zone 6. Les niveaux 16 à 20 sont pour la suite (5.5T en tout).

### 4.3 `Config/Tools` (armes)

| Arme | `Power` (avant → après) | `Price` (avant → après) | `TargetZones` (avant → après) |
| --- | --- | --- | --- |
| Fists | 1 → 1 | $0 → $0 | 1-1 → 1-1 |
| Wrench | 3 → 5 | $300 → $300 | 2-2 → 2-2 |
| Crowbar | 8 → 40 | $8K → $40K | 2-3 → 3-3 |
| Hammer | 20 → 300 | $120K → $1M | 3-3 → 4-4 |
| Sledgehammer | 50 → 2.5K | $2M → $20M | 4-4 → 5-5 |
| Fire Axe | 125 → 20K | $30M → $250M | 5-5 → 5-5 (milieu de zone 5) |
| Angle Grinder | 300 → 100K | $400M → $5B | 6-6 → 6-6 |

### 4.4 `Config/Cosmetics` (auras et trails)

| Aura | `Multiplier` (avant → après) | `Price` (avant → après) | `TargetZones` (avant → après) |
| --- | --- | --- | --- |
| Spark | 1.5 → 2 | $500 → $500 | 1-2 → 2-2 |
| Flame | 2 → 3 | $15K → $60K | 2-3 → 3-3 |
| Lightning | 3 → 5 | $400K → $1.5M | 3-4 → 4-4 |
| Plasma | 5 → 8 | $10M → $30M | 4-5 → 5-5 |
| Galaxy | 8 → 12 | $250M → $400M | 5-6 → 5-5 (milieu de zone 5) |
| Royal | 11 → 20 | $3B → $8B | 6-6 → 6-6 |

| Trail | `Multiplier` (avant → après) | `Price` (avant → après) | `TargetZones` (avant → après) |
| --- | --- | --- | --- |
| Dust | 1.1 → 2 | $300 → $300 | 1-2 → 2-2 |
| Wind | 1.25 → 3 | $10K → $40K | 2-3 → 3-3 |
| Turbo | 1.4 → 5 | $300K → $1M | 3-4 → 4-4 |
| Comet | 1.6 → 8 | $8M → $20M | 4-5 → 5-5 |
| Hyperspace | 1.8 → 12 | $200M → $2.5B | 5-6 → 6-6 |

Pourquoi :

- **Un kit par zone** : une arme, une aura, un trail. Les mêmes paliers pour les auras et les trails (×2, ×3, ×5, ×8, ×12), plus Royal ×20.
- **Un trail ×2 vaut un niveau de tapis**, pour toujours. Dans un log, ×1,1 ne se voyait pas.
- **Fire Axe et Galaxy** sont le palier du milieu de la zone 5, qui dure près de 5 h : casse de la zone 5 en moins d'une seconde, et un achat à faire en attendant le kit de la zone 6.
- **Prix** : zone 2 inchangée (le tuto cite l'aura à 500 $). Ensuite chaque article du kit coûte 2 à 7 minutes de revenus au moment de l'achat (cible du doc 7.2 : 3 à 7 min), section 6.4. Le kit de la zone 6 (15.5B) est le grand objectif de la zone 5 : 38 à 61 minutes de revenus par article.
- **L'échelle des dégâts est libre** : on peut multiplier toutes les armes par 10 ou par 1 000 sans rien changer aux durées, puisque les PV suivent (question 2 pour Clément).

### 4.5 `Config/Potions`

| Clé | Aujourd'hui | Proposition |
| --- | --- | --- |
| `Strength.Multiplier` | 2 | 1,5 (décision de Cantin) |
| `Speed.Multiplier` (sur la marche) | 2 | inchangé, mais voir la question 5 pour Cantin |

### 4.6 `Config/Balance`, `Config/Formulas`

| Clé | Aujourd'hui | Proposition |
| --- | --- | --- |
| `Balance.Stats.SpeedToWalkSpeed` | 0,05 | retiré ; à la place `WalkPerDecade = 4` et `SpeedScale = 100` |
| `Balance.Stats.StrengthDivisor` | 100 | retiré |
| `Balance.Stats.BaseWalkSpeed`, `MaxWalkSpeed` | 16, 70 | inchangés |
| `Balance.Window.BreakTimer`, `RegenPerSecond` | 13 s, 3 %/s | inchangés |
| `Balance.Hit.MaxHitsPerSecond` | 10 | inchangé (la règle de la zone 6 en dépend) |
| `Formulas.HitDamage` | arme × (1 + Force / 100) × aura | arme × aura |
| `Formulas.WalkSpeed` | linéaire | la formule en log |
| `Formulas.MachineMultiplier` | 1 + 0,5 × niveau | remplacée par le gain 2^(niveau − 1) |

### 4.7 `Config/PvP`, `Config/SkillTree` (portes des boutiques de joueurs)

Règle gardée : base = 50 × Strength du panneau de la zone du même rang que le niveau de la boutique (`PvP.PlayerWindowHPPerDamage = 50`). Arbre inchangé (Glass jusqu'à ×8, Walls jusqu'à ×3, réparation de 3 à 8 %/s), prix de l'arbre inchangés : les revenus ne changent pas, et les prix de l'arbre (10K à 600M) restent à l'échelle des kits des zones 2 à 5.

| Niveau de boutique | PV de base (avant → après) | Arbre complet (×24) | Sans arbre : voleur du même rang, 6 coups/s | Sans arbre : voleur d'une zone au-dessus | Arbre complet : même rang, 10 coups/s | Arbre complet : une zone au-dessus, 10 coups/s | Arbre complet : meilleur kit (2M), 10 coups/s |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 50 → 50 | 1.2K | 11.1 s | 0.9 s | jamais | 5 min | < 0.1 s |
| 2 | 500 → 500 | 12K | 11.1 s | 0.7 s | jamais | 50.0 s | < 0.1 s |
| 3 | 4K → 6K | 144K | 11.1 s | 0.7 s | jamais | 41.4 s | < 0.1 s |
| 4 | 30K → 75K | 1.8M | 11.1 s | 0.6 s | jamais | 32.1 s | 0.1 s |
| 5 | 250K → 1M | 24M | 11.1 s | 0.1 s | jamais | 1.3 s | 1.3 s |

Entre les zones 1 à 5, les pas de dégâts (×8 à ×13) ressemblent à ceux d'aujourd'hui (×8 à ×10) : l'arbre garde son sens, une porte entièrement améliorée tient 30 s à 5 min face à un voleur d'une zone au-dessus. **Le joueur de zone 6 (2M par coup) ouvre n'importe quelle porte en 1 s** : question 4 pour Clément.

### 4.8 Ce qui suit tout seul, ou qu'il faut revoir

| Fichier | Effet |
| --- | --- |
| `Config/FortuneTower` | `MAX_HP = 4 × AdvisedDamage zone 6 × 7 × 90` : suit tout seul, 100.8M → 5.04B |
| `Config/TruckEvent` | `MaxHP = 1000` fixe : dérisoire. V0 proposé : 100 × `AdvisedDamage` de la zone où il passe (un joueur au panneau, 6 coups/s, sans régénération : 100 / 6 = 17 s), soit 100, 1K, 12K, 150K, 2M, 200M |
| `Config/Bot` | Rien : porte de niveau 1 (50 PV), vitesse = vigile de la zone 1 (13,4, inchangé) |
| `Config/Night` | Rien : les vigiles de nuit restent à 80, au-dessus du plafond |
| `Config/Monetization` | `DoubleTraining` ×2 vaut un niveau de tapis : rien à changer. **`HydraulicGloves` (« 2.5× your best tool », pas encore prêt) casse la règle de la zone 6** (2,5 > 2) : à revoir avant de le vendre |
| `Config/Rebirths` (Partie 2) | « +25 % Training Gains » ne pèse presque rien quand un niveau fait ×2 ; les outils de renaissance (Marteau-piqueur, Bélier) déplaceront D, donc les PV de la zone 6 |
| `Config/Index` | +3 % de marche par zone complète : inchangé (question 5 pour Cantin) |
| `Config/Tutorial` | Textes : étape du banc à retirer, « vitesse 22, dégâts 10 » → « Speed 3K, Strength 10 » |
| `Config/Rewards`, `Config/Offline`, `Config/Rarities`, `Config/Mutations`, `Config/ShelfOpen`, `Config/Pawn` | Rien |

## 5. Zone 6 : jamais seul (règle de Cantin)

**Règle** : les PV de la vitrine de la zone 6 sont ce que font deux des meilleurs joueurs possibles pendant le chrono de casse de 13 s, sans potion. La potion de force n'entre pas dans le calcul : comme elle multiplie par 1,5, un joueur seul, même avec la potion, reste sous ce que font deux joueurs (1,5 < 2).

**Le meilleur joueur possible** : D = meilleure arme × meilleure aura = Angle Grinder 100K × Royal ×20 = **2M par coup**. Coups : 10 par seconde, le plafond du serveur (`Balance.Hit.MaxHitsPerSecond`, débit du remote `HitWindow`). L'arbre de compétences n'a aucune compétence d'attaque : il ne change rien ici.

**Formule.** La vitrine se répare de 3 % de ses PV max par seconde, même sous les coups (`WindowService`). Elle casse dans le chrono si :

```
coups/s × dégâts × 13 ≥ PV × (1 + 0,03 × 13)      soit      PV ≤ 9,353 × coups/s × dégâts
```

| Qui frappe | Dégâts par seconde | PV cassables en 13 s | En multiples de D |
| --- | --- | --- | --- |
| Seul, 10 coups/s, sans potion | 20M | 187M | 93.5 |
| Seul, 10 coups/s, potion ×1,5 | 30M | 280M | 140.3 |
| **Deux, 10 coups/s chacun, sans potion (la règle)** | 40M | **374M** | **187.1** |
| Deux, 8,6 coups/s chacun, sans potion | 34.4M | 321M | 160.9 |
| Trois, 6 coups/s chacun, sans potion | 36M | 336M | 168.3 |
| Deux, 6 coups/s chacun, potion ×1,5 | 36M | 336M | 168.3 |
| Deux, 6 coups/s chacun, sans potion | 24M | 224M | 112.2 |

**Bornes** :

- maximum = la règle = 2 × 10 × D × 13 / 1,39 = **187,05 × D = 374M** (260 × D = 520M si on oublie la régénération : avec 520M, deux joueurs parfaits n'y arriveraient pas) ;
- minimum = plus que ce que fait un joueur seul avec la potion = 1,5 × 10 × D × 13 / 1,39 = **140,3 × D = 280M**.

**Valeur choisie par Cantin (14/11, « 374M ») : 187 × D = 374M PV** (`Zone6.HPPerDamage = 187`), la règle sans marge. Il faut deux joueurs au meilleur kit à 10 coups/s pendant tout le chrono, ou quatre joueurs à 6 coups/s ; trois ne suffisent plus. Le joueur seul avec la potion de force reste loin en dessous. Exception voulue par Cantin (« Il peut casser car il a payé ») : avec le gamepass Hydraulic Gloves, un joueur seul casse la vitrine. Proposé d'abord : 160 × D = 320M (deux joueurs à 8,6 coups/s).

**À vérifier avant d'appliquer (Claude, 14/11)** : le simulateur tourne encore avec 160. Avec `HPPerDamage = 187`, `RAPPORT=v2 COURT=1 bash tools/ironix/equilibrage/run.sh` donne 0 partie sur 25 qui atteint la zone 5 ou la zone 6, pour les trois profils (avec 160 : zone 6 en 7 h 35 pour le joueur moyen). La cause n'est pas encore trouvée : les temps par zone de cette note sont ceux de 320M.

Temps de casse avec 374M PV, régénération de 3 %/s comprise (temps = PV / (dégâts par seconde − 0,03 × PV) ; « non » au-delà du chrono de 13 s) :

| Avec 374M PV | Temps de casse |
| --- | --- |
| Seul, 10 coups/s, sans potion | non (42.6 s) |
| Seul, 10 coups/s, potion | non (19.9 s) |
| Seul, 10 coups/s, Hydraulic Gloves (2,5 × l'arme) | 9.6 s |
| Deux, 10 coups/s | 13.0 s (tout juste) |
| Deux, 9 coups/s | non (15.1 s) |
| Deux, 8 coups/s | non (18.0 s) |
| Trois, 6 coups/s | non (15.1 s) |
| Quatre, 6 coups/s | 10.2 s |
| Deux, 6 coups/s, potion | non (15.1 s) |
| Quatre, 10 coups/s, Angle Grinder × Galaxy (1.2M) | 10.2 s |
| Huit, 10 coups/s, kit de la zone 5 (20K) | jamais |

À écrire dans le code comme un calcul, pas comme un nombre : `Zones[6].WindowHP = 160 × (meilleur Power de Tools) × (meilleur Multiplier des auras)`. Toute nouvelle arme ou aura (renaissances, gamepass) déplace alors la vitrine avec elle.

## 6. Résultats du simulateur

### 6.1 Temps de jeu actif pour entrer dans chaque zone

Médiane de 25 parties (de la plus rapide à la plus lente), premier colis rapporté de la zone, sans aucune aide. Zone 6 : cassée en équipe.

| Profil | Zone 2 | Zone 3 | Zone 4 | Zone 5 | Zone 6 |
| --- | --- | --- | --- | --- | --- |
| Cible (courbe de la proposition d'avant) | 7 min | 27 min | 1 h 07 | 2 h 45 | 7 h 30 |
| Prudent | 14 min (11 à 21) | 47 min (35 min à 1 h 01) | 2 h 21 (1 h 24 à 2 h 45) | 5 h 53 (3 h 52 à 6 h 24) | 15 h 37 (12 h 02 à 17 h 18) |
| **Moyen** | **7 min** (5 à 9) | **25 min** (18 à 34) | **1 h 06** (48 min à 1 h 21) | **2 h 35** (2 h 18 à 3 h 11) | **7 h 35** (6 h 23 à 8 h 41) |
| Acharné | 6 min (4 à 8) | 21 min (15 à 25) | 55 min (41 min à 1 h 08) | 2 h 13 (1 h 11 à 2 h 41) | 6 h 05 (4 h 14 à 7 h 34) |

- **Joueur moyen** : 7 h 35 (7 h 27 sur 75 parties). Chaque zone prend 2,4 à 3,6 fois plus de temps que la précédente.
- **Joueur acharné** : 6 h 05.
- **Le plus rapide des 25 parties** : 4 h 14 (acharné) ; 6 h 23 pour le plus rapide des joueurs moyens.
- **Joueur prudent** : 15 h 37. Il attend les deux nombres verts, ne tape pas sur le tapis et flâne : il lui faut 2 fois la Speed du joueur moyen avec un gain 1,5 fois plus faible. C'est long ; le levier est la règle du vigile (section 6.6).

Les profils : prudent = 4 coups/s, attend le vert, sans taps, obtient 35 % des colis ; moyen = 6 coups/s, entre dès qu'il casse en 10 s et que le vigile ne le rattrape plus, taps, 50 % des colis ; acharné = 9 coups/s, 75 % des colis, ne flâne pas.

### 6.2 Le joueur moyen à son entrée dans chaque zone (médianes)

| Zone | Temps de jeu | Speed affichée | WalkSpeed | Strength | Casse | Outil | Niveau du tapis | Présentoirs | Revenus | Depuis la zone d'avant : tapis | braquages |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2 | 7 min | 808 | 19.8 | 10 | 7.1 s | Wrench | 3 | 5 | $16/s | 1 min | 6 min |
| 3 | 25 min | 37.8K | 26.3 | 120 | 7.1 s | Crowbar | 6 | 9 | $402/s | 7 min | 11 min |
| 4 | 1 h 06 | 1.3M | 32.5 | 1.5K | 7.1 s | Hammer | 9 | 12 | $6.9K/s | 17 min | 23 min |
| 5 | 2 h 35 | 49.7M | 38.8 | 20K | 7.1 s | Sledgehammer | 12 | 15 | $133K/s | 45 min | 44 min |
| 6 | 7 h 35 | 1.6B | 44.8 | 2M | 12.1 s (à plusieurs) | Angle Grinder | 15 | 18 | $2.1M/s | 2 h 06 | 2 h 53 |

### 6.3 Répartition du temps jusqu'à la zone 6 (médianes)

| Profil | Tapis | Braquages | Part d'entraînement | Colis rapportés | Niveau du tapis |
| --- | --- | --- | --- | --- | --- |
| Prudent | 9 h 47 | 5 h 50 | 63 % | 325 | 15 |
| Moyen | 3 h 17 | 4 h 18 | 43 % | 279 | 15 |
| Acharné | 2 h 46 | 3 h 21 | 45 % | 263 | 15 |

La proposition d'avant était à 57 % d'entraînement (tapis et banc) : sans banc, et avec des kits plus chers, le joueur moyen passe plus de temps à braquer qu'à courir sur son tapis. La nuit (2 min sur 10) est un temps de tapis forcé.

### 6.4 Ce que coûte chaque achat au joueur moyen

Prix divisé par ce qu'il gagne par minute au moment de l'achat (présentoirs et receleur).

| Article | Prix | Acheté à | Minutes de revenus |
| --- | --- | --- | --- |
| Wrench | $300 | 3 min | 0.7 |
| Crowbar | $40K | 17 min | 2.1 |
| Hammer | $1M | 40 min | 4.0 |
| Sledgehammer | $20M | 1 h 19 | 7.4 |
| Fire Axe | $250M | 4 h 15 | 3.6 |
| Angle Grinder | $5B | 5 h 20 | 46.2 |
| Spark | $500 | 4 min | 0.7 |
| Flame | $60K | 23 min | 2.5 |
| Lightning | $1.5M | 48 min | 4.1 |
| Plasma | $30M | 1 h 39 | 6.0 |
| Galaxy | $400M | 4 h 59 | 3.7 (23 parties sur 25) |
| Royal | $8B | 7 h 02 | 60.7 |
| Dust | $300 | 5 min | 0.5 |
| Wind | $40K | 20 min | 1.7 |
| Turbo | $1M | 43 min | 3.7 |
| Comet | $20M | 1 h 26 | 5.6 |
| Hyperspace | $2.5B | 4 h 17 | 38.0 |
| Tapis niveau 3 | $570 | 5 min | 0.6 |
| Tapis niveau 5 | $8.2K | 11 min | 1.1 |
| Tapis niveau 8 | $451K | 34 min | 2.7 |
| Tapis niveau 10 | $6.5M | 1 h 09 | 7.1 |
| Tapis niveau 12 | $94.1M | 1 h 56 | 12.5 |
| Tapis niveau 14 | $1.3B | 3 h 28 | 30.9 |
| Tapis niveaux 16 à 20 | $19.6B à $4T | après la zone 6 | — |

### 6.5 Les aides : de combien elles raccourcissent la zone 6 du joueur moyen

Médianes de 75 parties (l'effet d'une aide est du même ordre que l'écart entre deux médianes de 25 parties). **Hypothèses, pas des mesures** : sessions de 45 min, 2 par jour, absence plus longue que le plafond des gains hors ligne (4 h de revenus des présentoirs à chaque retour, `Config/Offline`) ; toutes les récompenses réclamées (`Config/Rewards` : calendrier de 7 jours et paliers de temps de jeu) ; un camion toutes les 10 min de jour dans une zone au hasard, 1 colis rapporté quand il est dans une zone que le joueur braque déjà.

| Aides comptées | Entrée en zone 6 | Temps gagné | Gains hors ligne reçus | Argent des récompenses | Colis offerts | Camions pillés |
| --- | --- | --- | --- | --- | --- | --- |
| Aucune (référence) | 7 h 27 | — | — | — | — | — |
| Gains hors ligne seuls, sessions de 45 min | 5 h 57 | 20 % | $74.6B | — | — | — |
| Gains hors ligne seuls, sessions de 90 min | 6 h 21 | 15 % | $44B | — | — | — |
| Gains hors ligne seuls, sessions de 20 min | 6 h 23 | 14 % | $114B | — | — | — |
| Récompenses quotidiennes et de temps de jeu seules | 6 h 52 | 8 % | — | $1.6B | 11 | — |
| Camion seul | 7 h 35 | −2 % (dans le bruit) | — | — | — | 32 |
| **Les trois, sessions de 45 min** | **5 h 46** | **23 %** | $71.8B | $1B | 10 | 24 |

- **Gains hors ligne : 15 à 20 %** (1 h à 1 h 30 de moins). Ils versent 3 à 7 fois le prix du kit de la zone 6, mais l'argent n'achète pas la Speed : il n'achète que des niveaux de tapis, et il reste à courir.
- **Récompenses : 8 % environ** (35 min de moins), surtout par les colis offerts et le boost ×2 argent.
- **Camion : rien de mesurable** (un colis de plus de temps en temps, souvent d'une zone plus basse).
- **Tout ensemble : zone 6 en 5 h 45 à 6 h de jeu actif** au lieu de 7 h 30, soit 1 h 30 à 1 h 45 de moins.

Si la cible de 7 h 30 doit tenir **avec** les aides, il faut monter `Growth` du tapis vers 4,1 (9 h sans aide, tableau suivant). À décider (question 1 pour Cantin).

### 6.6 Sensibilité : ce qui fait bouger la zone 6 du joueur moyen

| Variante | Zone 5 | Zone 6 | Part d'entraînement |
| --- | --- | --- | --- |
| Proposition telle quelle | 2 h 35 | 7 h 35 | 43 % |
| Prix des niveaux ×3,5 par niveau (au lieu de ×3,8) | 2 h 26 | 7 h 15 | 42 % |
| Prix des niveaux ×4,1 par niveau | 3 h 22 | 9 h 03 | 61 % |
| Armes, auras et trails 2 fois moins chers | 2 h 27 | 7 h 08 | 46 % |
| Armes, auras et trails 2 fois plus chers | 2 h 57 | 8 h 53 | 37 % |
| Vigile à 0,9 × vitesse conseillée − 1 (règle d'aujourd'hui) | 1 h 45 | 5 h 47 | 33 % |
| Vigile à 0,9 × vitesse conseillée | 2 h 11 | 6 h 55 | 41 % |
| Vigile à 0,9 × vitesse conseillée + 2 | 3 h 31 | 9 h 38 | 56 % |
| Avance sur le vigile 10 studs (au lieu de 20) | 3 h 06 | 8 h 23 | 51 % |
| Avance sur le vigile 30 studs | 2 h 24 | 7 h 02 | 39 % |
| Il obtient 25 % des colis de sa zone (au lieu de 50 %) | 2 h 59 | 9 h 16 | 47 % |
| Il obtient 100 % des colis de sa zone | 2 h 21 | 6 h 34 | 48 % |

Les trois vrais boutons : le prix des niveaux du tapis, la vitesse des vigiles (1 de marche = 1 h 30 à 2 h sur la zone 6) et le prix des kits.

## 7. Ce qu'il faudra changer dans le code (rien n'est fait)

| Fichier | Changement |
| --- | --- |
| `src/shared/Config/Balance.luau` | `Stats` : `WalkPerDecade`, `SpeedScale` ; retirer `SpeedToWalkSpeed` et `StrengthDivisor` |
| `src/shared/Config/Formulas.luau` | `HitDamage(arme, aura)`, `WalkSpeed` en log, `ShownSpeed`, gain du tapis à la place de `MachineMultiplier` |
| `src/shared/Config/Zones.luau` | Tableau 4.1 ; nouveau champ `SpeedRequired` ; `WindowHP` de la zone 6 calculé (section 5) |
| `src/shared/Config/Upgrades.luau`, `Training.luau` | Tapis du tableau 4.2 ; banc retiré |
| `src/shared/Config/Tools.luau`, `Cosmetics.luau`, `Potions.luau` | Tableaux 4.3 à 4.5 |
| `src/shared/Config/TruckEvent.luau`, `Tutorial.luau`, `Monetization.luau` | Tableau 4.8 |
| `TrainingService`, `MachineVariantService`, `UpgradeController` | Plus de banc ; niveau affiché = niveau enregistré + 1 ; texte « +8/s → +16/s » |
| `StatsService`, `ToolService`, `HudController`, `AdvicePanel` | Attribut de Speed affichée ; `Damage` = arme × aura ; la ligne Strength du HUD lit `Damage` ; le panneau compare la Speed affichée à `SpeedRequired` |
| `PotionService` | Rien (il lit `Multiplier`) |
| Contrat | Tag `Bench`, animation `BenchLift`, panneau d'amélioration du banc : à retirer avec Clément (annoncer avant, tableaux 2.2 et 10.4) |
| Sauvegarde | `Stats.Strength` et `Upgrades.Bench` restent dans les profils, sans effet ; `Stats.Speed` change d'échelle : remettre à zéro les profils de la place DEV |
| Docs | Partie 1 : sections 4, 5.1, 7.1, 7.2, 7.4, 7.5 ; journal des décisions (section 15) |
| Bancs de test | Ceux qui figent ces valeurs (stats, entraînement, panneaux, portes, HUD, potions) |

## 8. Limites

- C'est un modèle, pas un Play. Aucune hypothèse de `Modele.Hypotheses` n'a été mesurée en jeu : 20 studs d'avance sur le vigile, 6 s pour poser un colis, part des colis obtenue.
- **Zone 6 en équipe** : le simulateur suppose qu'une équipe est là (18 coups/s en tout, au niveau du joueur : 2 joueurs à 9 coups/s ou 3 à 6). Il ne compte pas le temps passé à trouver un partenaire. Sur un serveur où personne d'autre n'a le kit, la zone 6 reste fermée.
- La rareté des objets est tirée dans l'ancienne table à trois types de colis (`Rarities.BoxOdds`), pas dans les tables par caisse de L-122 ; la note de L-122 mesure que l'économie bouge peu (3 min sur la zone 6).
- Le joueur simulé n'achète pas l'arbre de compétences, ne vole pas les autres joueurs et ne se fait pas voler.
- Potions, gamepasses et renaissances ne sont pas comptés. Le gamepass ×2 Entraînement vaut un niveau de tapis d'avance.
- Les durées bougent beaucoup avec trois nombres (section 6.6) : à régler en bêta avec les données de la section 14 du doc.

## 9. Questions

### Pour Cantin

1. **La cible de 7 h 30 s'entend sans les aides** (ce que j'ai fait) : avec les gains hors ligne et les récompenses, un joueur moyen arrive en zone 6 en 5 h 45 à 6 h de jeu actif. D'accord, ou faut-il 7 h 30 aides comprises (tapis à ×4,1 par niveau) ?
2. **Marge de la zone 6** : 320M PV (deux joueurs à 8,6 coups/s) ou la règle sans marge, 374M (deux joueurs à 10 coups/s parfaits) ?
3. **Niveau du tapis** : le joueur commence au niveau 1 (+1/s) et achète 19 niveaux. C'est bien ce que tu voulais, ou le niveau 1 doit-il s'acheter ?
4. **Taps au tapis** (+50 %) : on les garde ? Ils font du « +1 par seconde » un « +1,5 » pour qui tape.
5. **Potion Speed (×2 sur la marche) et Index (+3 % de marche par zone)** : ils multiplient la marche réelle, pas la stat. Une potion Speed fait passer n'importe quel vigile pendant 2 min. On les garde tels quels, ou la potion passe à ×1,5 comme la force ?
6. **Gamepass Hydraulic Gloves** (« 2.5× your best tool ») : il permettrait de casser la zone 6 seul. On le retire, ou il compte dans « le meilleur joueur possible » (les PV montent alors de 2,5 fois pour tout le monde) ?
7. **Joueur prudent à 15 h 30** : acceptable ? Sinon, vigile à 0,9 × vitesse conseillée (sans le + 1) et tapis un peu plus cher.
8. **Profils de la place DEV** : remise à zéro au passage ?

**Réponses de Cantin (2026-11-14), ses mots** :

1. « Sans les aides » : la cible reste 7 h 35 de jeu actif.
2. « 374M » : vitrines de la zone 6 à 374M PV (`Zone6.HPPerDamage = 187`), deux joueurs au maximum à 10 coups/s. Voir la section de la zone 6.
3. Pas encore répondu : on garde le choix par défaut (niveau 1 offert).
4. Pas encore répondu : on garde le choix par défaut (taps gardés, +50 %).
5. « On enlève potion de vitesse » : la potion Speed sort du jeu. L'Index (+3 % de marche par zone) reste, tant que Cantin n'a rien dit.
6. « Il peut casser car il a payé » : le gamepass Hydraulic Gloves reste, et un joueur qui l'a peut casser la zone 6 seul (2,5 × 100K × 20 = 5M par coup, 10 coups/s : 374M en 9,6 s). Les PV ne montent pas pour autant.
7. Pas encore répondu : on garde le choix par défaut (joueur prudent à 15 h 30 accepté).
8. Remise à zéro des profils DEV (déjà décidé).

### Pour Clément

1. **Plus de banc** : le modèle, le tag `Bench`, l'animation `BenchLift`, le panneau d'amélioration du banc et l'étape du tuto disparaissent. Que devient la place du banc dans la parcelle ?
2. **Échelle de la Strength** : 10, 120, 1.5K, 20K, 2M sur les panneaux. Assez grand, ou veux-tu des millions et des milliards comme pour la Speed ? On peut multiplier toute l'échelle sans rien changer d'autre.
3. **Zone 6 à plusieurs** : il faut deux joueurs avec le meilleur kit (ou trois joueurs moyens, ou quatre avec Angle Grinder × Galaxy). Le panneau de la zone 6 doit le dire : un texte (« 2 PLAYERS ») ou une icône sur `StoreReqSign`, `BB_StoreInfo`, `BB_ZoneGate` ?
4. **Portes** : un joueur de zone 6 ouvre n'importe quelle porte en 1 s, même avec l'arbre complet. Accepté, ou un sixième niveau de boutique, ou une base plus haute au niveau 5 (par exemple 50 × 240K, le kit Fire Axe × Galaxy) ?
5. **Auras ×2, ×3, ×5, ×8, ×12, ×20 et trails ×2, ×3, ×5, ×8, ×12** : ça te va ? Les textes de la boutique changent (« ×20 Strength »).
6. **Seuils de Speed** 3K, 100K, 3M, 100M, 3B, zone 6 à 46 de marche au lieu de 48 ; HUD : « Speed » = Vitesse × trail, « Strength » = arme × aura (questions déjà posées en L-116, toujours ouvertes).
7. **Vigiles** : au seuil du panneau, le vigile reprend 1 stud par seconde au porteur. À essayer en Play. Il me manque toujours une mesure : de combien de studs le voleur devance-t-il le vigile quand celui-ci s'élance ? J'ai supposé 20 ; 10 studs de moins retardent la zone 6 de 50 min.
8. **Tapis** : niveau affiché de 1 à 20, Void au niveau 20, « +262K/s → +524K/s » sur `UpgradeSign`.
9. **Revenus de la zone 6** : faut-il récompenser le jeu à plusieurs par des objets qui rapportent plus (par exemple 40K $/s au lieu de 25K pour un Commun) ?

## 10. Relancer l'outil

```
RAPPORT=v2 bash tools/ironix/equilibrage/run.sh                  # rapport v2 complet
RAPPORT=v2 COURT=1 bash tools/ironix/equilibrage/run.sh          # seulement les temps par zone
RAPPORT=v2 GRAINES=75 bash tools/ironix/equilibrage/run.sh       # plus de parties
bash tools/ironix/equilibrage/run.sh                             # ancien rapport (L-108), inchangé
```

| Fichier | Rôle |
| --- | --- |
| `proposition_v2.luau` | Toutes les valeurs de cette note |
| `rapport_v2.luau` | Les tableaux de cette note |
| `modele.luau` | Le joueur simulé ; ajouts v2 : économie sans banc, zone d'équipe, aides (hors ligne, récompenses, camion) |
| `proposition.luau`, `rapport.luau` | L'ancienne proposition (avec banc), gardée pour comparer |
