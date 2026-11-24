# Monétisation de Steal a Shop : ce qu'on vend, ce que vend le genre, ce qu'on peut ajouter (2026-11-24)

Étude de l'analyste monétisation, sans aucune modification (rien dans `src/`, ni Studio, ni commit). Elle part du benchmark du 21/11 (`benchmark-2026-11-21.md`) et le complète. Son principal ajout : **les produits développeur des jeux du genre**, que le benchmark n'avait pas pu relever et qui sont en fait publics (API `developer-products/v2`).

- **Notre état** : lu dans `src/shared/Config/` (Monetization, Boosts, ProductIds, Features, Cosmetics, Tools, Rebirths, SkillTree, Wheel, Quests, Rewards, Codes, Potions, LiveEvents, Disguise, Traps, Upgrades, ShopGrowth, Offline, Balance, PvP, ShelfOpen) et dans `MonetizationService` et `RobuxShopController`.
- **Le marché** : relevé du 2026-11-24 dans les API publiques de Roblox (gamepasses et produits « en vente » de 9 jeux), plus quelques guides cités en fin de document.
- **Les règles** : documentation officielle de Roblox, lue le 2026-11-24, liens en fin de document.
- **Limites** : un produit « en vente » dans l'API n'est pas forcément affiché dans la boutique du jeu. Sans jouer, on ne voit pas la mise en avant (bannière, ordre des cartes, minuteurs). Tous les prix et effets proposés ici sont des **V0** à valider.

---

## 1. Ce qu'on vend aujourd'hui

**Ce qui bloque toutes les offres** : `Features.RobuxShop = false`, et **tous les Id valent 0** en PROD (`Config/Monetization`, `Config/Boosts`) comme en DEV (`Config/ProductIds`). Il faut donc, pour chaque offre, la créer sur le Creator Hub au nom du groupe, en DEV puis en PROD, et faire un vrai achat de test sur DEV. Côté Clément, il faut aussi une **icône 512 × 512** par gamepass pour la page Roblox (les Decals en jeu existent tous, d'après l'état des lieux du 21/11).

### 1.1 Gamepasses (`Monetization.Passes`)

| Clé | Nom | Effet (Config) | Prix R$ | Ready | Ce qui manque pour le vendre |
|---|---|---|---|---|---|
| `DoubleCash` | ×2 Cash | revenus × 2 | 449 | oui | Id ; le prix est à revoir (section 3) |
| `DoubleTraining` | ×2 Training | gains du tapis × 2 | 299 | oui | Id ; **même effet que `DoubleSpeed`**, les deux se multiplient (×4) : à clarifier avant la vente (section 3) |
| `DoubleSpeed` | ×2 Speed | gains du tapis × 2 (bouton `SpeedBoostButton` du HUD) | 149 | oui | Id ; le doublon ci-dessus ; le bouton du HUD affiche le prix de la Config, codé en dur (voir 6.4) |
| `VIP` | VIP | +10 % de revenus, aura, tag, rideau +30 s | 249 | **non** | aura VIP (Clément) ; effets à coder (tag, +10 %, rideau) |
| `AutoCollect` | Auto Collect | la caisse se vide toute seule, partout | 199 | oui | Id |
| `FastOpen` | Fast Open | antivol × 0,5 (`DelayFactor`) | 299 | oui | Id ; le nom ne colle plus à l'effet (il n'y a plus de colis posé : il raccourcit seulement la fenêtre de vol d'un objet posé en base, 5 à 180 s selon la rareté, `ShelfOpen.AntiTheft`) |
| `ExtraStands` | +4 Displays | `DisplaySlot_21` à `_24` | 349 | oui (code) | **les 4 présentoirs dans les parcelles** (absents au 21/11, à revérifier dans Studio) |
| `HydraulicGloves` | Hydraulic Gloves | puissance = 2,5 × le meilleur outil | 499 | **non** | modèle `TOOL_` et règle de puissance ; **casse la règle de la zone 6** (section 3) |

En dehors de la boutique, les abonnés Roblox Premium reçoivent +10 % de revenus (`Premium.IncomeBonus = 0.1`). C'est codé, mais **dépassé** : voir 4.11.

### 1.2 Produits développeur (`Monetization.Products`, `Config/Boosts`, `Config/Wheel`)

| Clé | Onglet | Effet | Prix R$ | Ready | Ce qui manque pour le vendre |
|---|---|---|---|---|---|
| `StarterPack` | Offers | ×2 Cash 1 h + Hammer + 2 600 $, offert la 1re heure de jeu | 99 (`OldPrice = 399`) | oui | Id ; **retirer le faux « 75% OFF »** (6.3) |
| `Cash10` → `Cash720` | Cash | 10, 30, 60, 180, 300, 720 min de revenus (au moins 50 $/min) | 49, 129, 199, 499, 799, 1 599 | oui | Id ; prix à revoir (section 3) |
| `OpenNow` (4 paliers) | Boosts | retire jusqu'à 60, 180, 480 ou 900 s d'antivol | 19, 39, 59, 99 | oui | Id ×4 ; **les paliers 3 et 4 ne servent plus** (l'antivol le plus long fait 180 s) |
| `SleepGuards` | Boosts + HUD « zZz » | vigiles, vigiles de nuit et police dorment 60 s, pour tout le serveur, puis 300 s de recharge | 79 | **non** | effet serveur à coder ; règle à valider par Clément |
| `Revenge` | Boosts | téléport derrière son voleur | 25 | **non** | règle PvP à écrire |
| `InstantShutter` | Boosts | ferme sa boutique tout de suite | 29 | **non** | MAJ 2 (défenses) |
| `Luck3` | Boosts | raretés boostées pendant 15 min | 79 | **non** | effet, **cotes affichées**, offre cachée si `ArePaidRandomItemsRestricted` |
| `Shield30` | Boosts | boutique inviolable 30 min, une fois par session | 99 | **non** | règle PvP à écrire ; risque d'injustice (section 6) |
| `ServerLuck2`, `4`, `8` | Boosts | chance × 2, 4 ou 8 pour tout le serveur pendant 15 min, mise en file, annoncée à tous | 149, 399, 999 | coupé (`SERVER_LUCK = false`) | **cotes à afficher et à tenir à jour, offre à cacher pour les joueurs restreints** : rien de cela n'est codé (seule la caisse lit `PolicyService`) |
| `Crate` (1, 3, 10) | caisse exclusive | 6 objets exclusifs, de l'Épique au Divin, chances 30/30/25/10/4/1 | 99, 249, 799 | oui | allumée en DEV seulement (`RobuxCrateDev`) ; en PROD, `Features.RobuxCrate = false`. Cotes et `PolicyService` : OK |
| `Wheel.ExtraSpin` | roue | tour de roue en plus | 25 | `ProductId = 0` | **tour payant = objet aléatoire payant** : cotes, `PolicyService`, et les secteurs « BOX », dont le contenu est lui-même tiré au hasard (6.2) |

---

## 2. Ce que vendent les jeux du genre

Relevé du **2026-11-24** dans les API publiques de Roblox : `apis.roblox.com/game-passes/v1/universes/{id}/game-passes` et `apis.roblox.com/developer-products/v2/universes/{id}/developerproducts`. Seules les offres « en vente » sont gardées, sans les entrées factices « DISABLED PRODUCT » à 999 999 999. Le nombre de joueurs est celui affiché au moment du relevé.

| Jeu (joueurs) | Gamepasses (R$) | Produits développeur marquants (R$) | À retenir |
|---|---|---|---|
| **Steal An Egg** (≈ 538 000) | X2 MONEY 299 · X2 GROWTH SPEED 467 | 125 produits. Argent 39 → 799 ; **échelle de vitesse en 12 marches de 3 à 1 035** ; tapis cosmétiques 15 → 2 999 ; trails 15 → 1 999 ; **œufs limités par saison** ×1 / ×3 / ×10 / ×50 = 99 / 249 / 799 / 3 499 ; Luck Boost 49 / 99 / 199 ; Speed 5 min → 4 h, 90 → 499 ; Instant Hatch 9 → 299 ; Shop Reroll 49 ; « Sample Pack » à **1 R$** ; objet exclusif 999 ; versions **[GIFT]** | Seulement 2 gamepasses : l'argent vient des produits. Très large gamme de 1 à 4 999 R$, cosmétiques nombreux, offres de saison |
| **Steal a Brainrot** (≈ 55 000) | 2x Money 299 · VIP 375 · Admin Commands 7 999 | 126 produits. **Server Luck ×2 / ×4 / ×8 = 249 / 999 / 2 999** ; Lucky Blocks 175 → 11 992 ; Cash Pack 59 → 2 499 ; StarterPack 189 ; Speed +1 / +5 / +10 = 39 / 99 / 229 ; armes PvP 199 → 999 ; pelles 29 → 199 ; roues 99 / 199 / 499 (1er tour « DISCOUNT » à 49) ; Skip Timer 19 → 199 ; Reveal Now 199 ; Craft Now 49 → 299 ; **Unlock Base 39** (force la base verrouillée d'un autre joueur, d'après des guides de fans) ; skin de base de saison 499 ; **[GIFT] de presque tout** | Chance du serveur et caisses en tête, cadeaux partout, beaucoup de PvP payant (à ne pas copier, section 6) |
| **Steal an Anime Pack** (≈ 13 000) | 3 anciens passes retirés (X2 LUCK, X4 LUCK, X2 MONEY) | 187 produits. **Server Luck ×2 → ×64 = 99 → 1 399** ; vitesse ×2 → ×8192 = **3 → 2 199** ; **argent au temps : 15 min 19, 1 h 49, 3 h 99, 10 h 249, 2 jours 499** ; Cash Pack 79 → 1 299 ; **unités LIMITED en achat direct 1 499 → 3 799** ; VIP 149 (produit) ; base cosmétique 999 ; tirages ×1 / ×3 / ×10 / ×50 = 99 / 229 / 649 / 2 799 | Les gamepasses sont devenus des produits. Argent au temps très bon marché. Exclusifs vendus en direct, sans hasard |
| **Steal A Dumpling** (≈ 5 500) | VIP 299 (+50 % d'argent, +50 % d'éclosion, tag) · X2 MONEY 399 · X2 GROWTH 467 | 78 produits. Starter Pack 79 et « Starter Pack Limited Offer » 49 ; **skins de base 29 / 59** ; niveaux de base 19 → 299 ; niveaux de tapis 19 → 599 ; vitesse en 12 marches 3 → 1 375 ; boosts de 15 min : ×2 revenus 29, ×5 entraînement 19, ×2 éclosion 15 ; roue ×1 / ×3 / ×10 = 19 / 49 / 149 ; œufs 99 / 249 / 799 / 3 499 ; trails 19 → 399 | Même modèle qu'Egg, en plus petit. Boosts courts très bon marché, skins de base |
| **Steal A Pet And Ride It** (≈ 5 900) | VIP 199 · 3x Open Speed 299 · **Auto Collect 49** · **Champion Pass 399** (70 récompenses) · x2 Pass XP 299 · x2 Tickets 299 · granges, tapis, trail et aura cosmétiques 99 → 299 | 387 produits. Cages ×1 / ×3 / ×10 / ×30 ; talismans 39 → 1 099 ; **« Ad: 2x Speed & Cash » 25** (récompense de pub) ; « Fill Lucky Bar » 29 / 89 (jauge de chance garantie) ; **2x Offline Cash 45** ; Equip Best 49 ; Buy Second Barn 79 ; **Gift** de presque tout | Pass de saison, cosmétiques à thème, publicités récompensées, cadeaux |
| **Steal a PC** (≈ 3 400) | VIP 99 (×2 argent, ×2 vitesse, titre) · x2 Money 99 · x2 Unbox Speed 99 | — | Tout à 99 R$ : petit jeu, prix d'appel |
| **Steal a Wild Horse** (relevé du 21/11) | x2 Money 399 · x2 Treadmill 349 · **20 trails de vitesse, de ×1,5 à ×50, de 19 à 2 999** · **Forever Lock 499** | — | Échelle de vitesse ; protection de la base vendue (à ne pas copier) |
| **Criminal Simulator** (braquage, ≈ 23 000) | VIP 99 · outils et armes « pour toujours » 299 → 649 · Strong Back 99 · Drop Crates 249 · **Armored Truck Intel 499** · **Armored Truck Guaranteed 1 699** (le fourgon blindé chaque nuit) · No Midtown Wait 49 | Outils à l'unité 9 → 199 ; argent 25 → 1 199 ; **Heist Crew Bundle 699, Kingpin Bundle 999** ; Revive 39 ; **Gift** de chaque gamepass | Vend l'événement « fourgon blindé », proche de notre `ArmoredVan` |
| **Jailbreak** (braquage, ≈ 6 800) | Pro Garage 450 · VIP (Lifetime) 750 · Crime Boss 400 · Duffel Bag 345 · SWAT 400 · VIP Trading 350 · Car Stereo 200 | Presque tout est retiré (packs d'argent, paliers de saison) ; Get Out Of Jail 1 500 | Vieux jeu : peu de passes, chers, qui donnent des rôles et du confort |
| **Restaurant Tycoon 3** (tycoon, ≈ 6 900) | Auto Money Collection 299 · **3x Customer Luck 399** · 2x Item Limits 299 · Faster Cooking 449 · Sandbox 1 499 · lots de meubles 349 / 399 | — | Tycoon : confort de construction, chance permanente, décor |
| **Plants vs Brainrots** (guide Beebom, 01/2026) | — | **Pass de saison premium 299 R$**, 35 paliers, environ 3 semaines, quêtes du jour, boutique de jetons, paliers rachetables en Robux | Le pass de saison fait vendre les quêtes |
| **Grow a Garden** (guide Beebom) | — | Caisse cosmétique ×1 / ×3 / ×10 = 199 / 575 / 1 699 ; graines et outils achetables en Robux sans attendre le réassort | Cosmétiques au hasard, achat « sans attendre » |

**Présentation** (ce qu'on en sait sans jouer) : chez Steal An Egg, le bouton Shop est vert, sur le côté gauche, fixe, et la boutique s'ouvre sur les PASSES (allthings.how). Chez Steal a Brainrot, la chance du serveur et les événements admin augmentent la chance de tout le serveur (benchmark du 17/11). Les **versions cadeau** sont des produits développeur au même prix que l'original (`[GIFT] 2x Money 299`).

**Ce qui revient partout**
1. Peu de gamepasses (2 ou 3) dans les gros jeux ; l'argent vient de **centaines de produits**.
2. **Chance du serveur** en échelle (×2 → ×8, jusqu'à ×64), en tête des prix.
3. **Échelle de vitesse** en 10 à 12 marches, à partir de **3 R$** (Egg, Dumpling, Anime Pack).
4. **Cadeaux** : chaque gamepass et chaque pack existe en version `[GIFT]` (SAB, Egg, Pet, Criminal Sim).
5. **Caisses et œufs ×1 / ×3 / ×10 / ×50**, souvent par saison (Limited Egg [Halloween], [Crystal]…).
6. **Cosmétiques sans effet** : skins de base, tapis, trails (la longue traîne des petits jeux).
7. **Grosse dernière marche** : de 2 999 à 11 992 R$ (SAB), 3 499 (Egg, Dumpling). Le plus petit achat se trouve **entre 1 et 19 R$**.

---

## 3. Nos prix face aux autres

### 3.1 Offre par offre

| Notre offre (prix actuel) | Équivalents chez les autres (source) | Verdict | Prix V0 proposé et pourquoi |
|---|---|---|---|
| **×2 Cash** (449) | SAB 2x Money 299, Egg X2 MONEY 299 (API, 24/11 ; 399 dans un guide d'août) ; Dumpling 399 ; Wild Horse 399 (benchmark du 21/11) ; Steal a PC 99 | **Trop cher** : au-dessus de tous | **299**, le prix des deux plus gros jeux. La fiche `DoubleCash.md` propose 29 R$ avec une échelle ×4 / ×8 / ×16, mais à 29 R$, un ×2 **permanent** coûterait moins que 10 min d'argent (`Cash10`, 49), et l'échelle d'argent n'est pas passée au simulateur. Je garde l'idée de l'échelle pour la vitesse (ligne suivante), pas pour l'argent |
| **×2 Training** (299) et **×2 Speed** (149) | Wild Horse x2 Treadmill 349 et trails de ×2 à 29, ×4 à 399… ; échelles de vitesse en 12 marches : Egg 3 → 1 035, Dumpling 3 → 1 375, Anime Pack 3 → 2 199 ; PC : ×2 vitesse dans le VIP à 99 | **Incohérent** : deux gamepasses au même effet (« ×2 treadmill gains » et « ×2 speed on the treadmill »), qui se multiplient. Le joueur croit acheter deux fois la même chose | **Une seule échelle, « la plus haute marche gagne »** : `DoubleSpeed` = ×2 à **49** (le bouton du HUD, l'achat réflexe), `DoubleTraining` devient ×4 à **149** (renommé « ×4 Training »), puis ×8 à **399** et ×16 à **799** plus tard, selon les ventes. Avec les deux, on garde ×4, comme aujourd'hui. Sans danger pour le PvP : la marche suit le log de la Speed et plafonne (`Balance.Stats.MaxWalkSpeed = 70`). Va contre le V0 de Cantin du 23/11 (×2 Speed à 149) : question en section 8 |
| **VIP** (249) | SAB 375 ; Dumpling 299 ; Pet 199 ; Anime Pack 149 ; Criminal Sim 99 ; PC 99 | **Cohérent** | **249**. En revanche, le **rideau +30 s** est lourd : le verrou dure 30 s de base et 60 s au plus (`SkillTree.Curtain`), donc +30 s fait 60 à 90 s. SAB donne +10 s. V0 : **+10 s** |
| **Auto Collect** (199) | Pet 49 ; RT3 « Auto Money Collection » 299 ; Wild Horse (retiré) | **Un peu cher** : c'est notre meilleur candidat au **pass d'appel** (le benchmark du 21/11 en voulait un à 99 R$ ou moins) | **99** |
| **Fast Open** (299) | Egg X2 Growth 467, Pet 3x Open Speed 299, PC x2 Unbox 99 : ces passes accélèrent toute la boucle | **Trop cher pour son effet** : chez nous, il raccourcit seulement une fenêtre de vol de 5 à 180 s | **99**, renommé « Quick Lock » (« Anti-theft 2× shorter »), ou retiré de la vente au lancement |
| **+4 Displays** (349) | Wild Horse « Extra Stalls » (retiré) ; Dumpling « Base Level » 19 → 299 (produits) | **Cohérent**. Il vaut beaucoup au début (`Display.StartSlots = 4`, donc 4 → 8) et +20 % au maximum (20 → 24) | **349**, mais pas en vente tant que les présentoirs 21 à 24 ne sont pas posés |
| **Hydraulic Gloves** (499) | Armes de SAB 199 → 999 ; outils de Criminal Sim 299 → 649 ; cartes exclusives de Superpower 649 / 799 | **Prix cohérent, effet à revoir**. 2,5 × l'Angle Grinder dépasse la règle écrite dans `Config/Tools` (« la zone 6 reste à deux joueurs », « 1,12 × Angle Grinder × Royal ») : un acheteur casserait seul la zone 6. La porte d'une boutique de joueur compte les coups (`PvP.DoorHits = 40`), donc les gants ne touchent pas au vol entre joueurs | **499**, avec une puissance de **1,5 × le meilleur outil acheté, jamais plus que l'Angle Grinder** (V0) |
| **Starter Pack** (99, affiché « 75% OFF » d'un ancien prix de 399) | SAB 189 ; Dumpling 79 (et 49 en « Limited Offer ») ; Pet Explorer Pack 79 ; Anime Advanced Pack 199 | **Prix cohérent ; la remise ne l'est pas** : le pack n'a jamais été vendu 399, et Roblox interdit les remises qui ne sont pas réelles (6.3) | **99**, `OldPrice = nil` (la Config l'accepte), et le texte « First hour of play only » avec le vrai minuteur |
| **Packs d'argent** : 10 min 49 · 30 min 129 · 1 h 199 · 3 h 499 · 5 h 799 · 12 h 1 599 | Anime Pack, au temps : 15 min **19**, 1 h 49, 3 h 99, 10 h 249, 2 jours 499 ; Egg 39 → 799 ; SAB 59 → 2 499 ; chez Egg, le plus gros pack d'argent donne **20 fois plus par Robux** que le plus petit | **Entrée trop chère** : 10 min de nos revenus à 49 R$, alors que la quête « Rob 3 stores » en donne 10 et le 6e jour 30, gratuitement. **Gros packs trop peu avantageux** : de 4,9 à 2,2 R$ la minute, soit ×2,2 seulement ; et 12 h à 1 599 valent moins que le ×2 Cash permanent | **10 min 29 · 30 min 69 · 1 h 119 · 3 h 249 · 5 h 349 · 12 h 699**, de 2,9 à 0,97 R$ la minute (×3 entre le premier et le dernier), étiquette « BEST VALUE » sur 3 h |
| **Open Now** (19 / 39 / 59 / 99) | SAB Skip Timer 19 → 199, Reveal Now 199 ; Egg Instant Hatch 9 → 299 ; Dumpling 9 → 299 | **Cohérent pour les paliers 1 et 2**, **les paliers 3 et 4 ne servent plus** (480 et 900 s, alors que `ShelfOpen.AntiTheft` s'arrête à 180 s) | **2 paliers : 19 (≤ 60 s) et 39 (≤ 180 s)** ; ne pas créer les deux autres produits |
| **Sleeping Guards** (79) | Pas d'équivalent direct ; achats « pour tout le serveur » : SAB Server Luck 249, Criminal Sim « Armored Truck Guaranteed » 1 699 | **Cohérent** | **79** |
| **×3 Luck** (79, 15 min, pour soi) | Egg Luck Boost 49 / 99 / 199 ; Superpower « 2x Luck » permanent 49 ; RT3 « 3x Customer Luck » permanent 399 | **Cohérent** | **79**, avec les cotes affichées (6.2) |
| **Server Luck** ×2 / ×4 / ×8 (149 / 399 / 999) | SAB 249 / 999 / 2 999 ; Anime Pack ×2 → ×64 = 99 → 1 399 | **Cohérent**, entre les deux, pour un jeu qui démarre | **149 / 399 / 999**. Remonter ×8 vers 1 499 si les ventes suivent |
| **Caisse exclusive** ×1 / ×3 / ×10 (99 / 249 / 799) | Egg et Dumpling 99 / 249 / 799 / 3 499 (×50) ; Pet 79 / 219 / 699 / 1 999 (×30) ; Anime 99 / 229 / 649 / 2 799 ; GAG 199 / 575 / 1 699 | **Cohérent** (copie d'Egg) | **99 / 249 / 799** ; un lot ×50 à 3 499 plus tard, si la caisse a assez d'objets (6 aujourd'hui, donc beaucoup de doublons) |
| **Tour de roue** (25) | SAB 99 (49 pour le 1er), ×3 199, ×10 499 ; Dumpling 19 / 49 / 149 | **Cohérent** | **19 / 49 / 149** (×1 / ×3 / ×10), et seulement une fois les règles des objets aléatoires payants respectées (6.2) |
| **Revenge** 25 · **Instant Shutter** 29 · **Shield30** 99 | SAB « Unlock Base » 39 (attaque) ; Wild Horse « Forever Lock » 499 (défense) | Prix cohérents ; **le problème est la justice du vol** (section 6) | Shield30 : ne pas le vendre tel quel. Les deux autres : seulement avec des limites (6.1) |

### 3.2 Cohérence entre nos prix

- **De 19 à 1 599 R$** aujourd'hui (Open Now contre 12 h d'argent), soit un écart de ×84. Le genre va de **1 à 3 R$** jusqu'à **3 499, voire 11 992**. Avec les V0 ci-dessus, on va de **19 à 999** (Server Luck ×8) : **il nous manque une dernière marche** (5.1, propositions N7 et N10).
- **Premiers achats** : aucun gamepass sous 149 R$. Avec les V0, on a Auto Collect et Quick Lock à 99, et ×2 Speed à 49.
- **×2 contre ×4** : la chance du serveur monte bien (×2,7 puis ×2,5 par marche). La vitesse est aujourd'hui incohérente (deux ×2) ; avec l'échelle, ×3 puis ×2,7 puis ×2.
- **Pack de départ** : à 99, il donne plus que `Cash60` à 199 (×2 pendant 1 h, plus un outil de zone 4 à 88 000 $, plus de l'argent). C'est bien : le pack de départ doit être la meilleure affaire.
- **×2 Cash contre packs** : à 449 pour le permanent et 1 599 pour 12 h, le gros pack est une mauvaise affaire. Avec 299 et 699, le permanent reste meilleur sur la durée et le pack sert à l'achat immédiat (« il me manque X pour la renaissance »).
- **Auto Collect contre VIP** : 199 contre 249, et VIP donne plus. Avec 99, l'écart se lit tout de suite.

---

## 4. Ce qui nous manque (du plus important au moins important)

1. **Rien n'est en vente** : boutique coupée, tous les Id à 0. Le pic de lancement est le seul vrai pic d'un jeu du genre (benchmark du 15/11).
2. **La chance du serveur est coupée**, alors que c'est le produit le plus cher de SAB et d'Anime Pack. Elle est codée, mais il manque l'affichage des cotes et le filtre `PolicyService`.
3. **Des prix hors marché** : ×2 Cash, entrée des packs, doublon de vitesse, fausse remise (section 3).
4. **Ni serveurs privés payants, ni Roblox Plus** : Roblox paie le créateur pour les abonnés Plus qui jouent sur ses serveurs privés payants et pour les abonnements Plus lancés depuis son jeu (5.1, N2).
5. **Pas de cadeaux** : tous les jeux du genre vendent des versions `[GIFT]`.
6. **Pas de cosmétiques en Robux** (skins de boutique, de tapis, de batte) : c'est la longue traîne des jeux du genre (387 produits chez Pet).
7. **Pas de grosse dernière marche** au-dessus de 1 000 R$ (après les corrections).
8. **Pas de pass de saison**, alors que nos quêtes en sont la base (Plants vs Brainrots 299, Pet Champion Pass 399).
9. **Pas d'exclusif en achat direct** : la seule offre pour les joueurs à qui la caisse est cachée.
10. **Pas de publicités récompensées.**
11. **Un bonus Premium dépassé** : Premium ne se vend plus aux nouveaux joueurs depuis le lancement de Roblox Plus (30/04/2026), et les Premium Payouts que visait ce bonus (Partie 2, 4.2) sont arrêtés depuis le 24/07/2025, remplacés par les Creator Rewards.

---

## 5. Propositions

Lecture des charges : **XS** < 2 h, **S** ½ journée, **M** 1 à 2 jours, **L** 3 jours et plus. « Ironix » = code, « Clément » = UI, icône ou modèle. Sauf mention contraire, rien ne touche au vol entre joueurs.

### 5.1 Produits nouveaux

**N1. Allumer la chance du serveur, en règle** (existe dans la Config, coupée)
- Quoi et pourquoi : ×2 / ×4 / ×8 pendant 15 min pour tout le serveur, annoncée avec le nom de l'acheteur. C'est le gros poste de SAB (249 → 2 999) et d'Anime Pack (99 → 1 399). Le joueur y gagne un moment partagé et peut frimer devant les autres.
- Prix V0 : 149 / 399 / 999 (inchangés).
- Équilibre : tout le serveur en profite, y compris les rivaux. Pas de pay-to-win.
- Règle Roblox : un boost de chance est un objet aléatoire payant. Il faut **expliquer son effet en chiffres avant l'achat et tenir les chances affichées à jour pendant qu'il agit**, et **cacher l'offre** aux joueurs pour qui `ArePaidRandomItemsRestricted` est vrai (page *Paid random items*). Un joueur restreint peut profiter de la chance achetée par un autre, puisqu'il ne paie rien.
- Travail : Ironix **M**, pour le filtre `PolicyService` (le même que la caisse) et le calcul des chances de rareté par zone, avec et sans chance (`ShelfOpen`, `ShelfBoxes`) ; Clément **S**, pour un panneau « Odds » (avant / avec boost) et l'icône propre de la chance du serveur (elle partage `UI_Icon_DP_Luck3`).
- Priorité : **avant la sortie**.

**N2. Serveurs privés payants + Roblox Plus**
- Quoi et pourquoi : (a) activer les serveurs privés payants sur le Creator Hub ; (b) donner aux abonnés Plus le même +10 % que Premium ; (c) une carte « Roblox Plus » dans l'onglet Offers. Roblox verse **jusqu'à 100 R$ par abonné Plus** qui passe 60 min ou plus par mois sur notre serveur privé payant, et **250 R$ par mois pendant 3 mois (750 R$ en tout)** pour chaque abonnement Plus lancé depuis notre jeu avec `PromptRobloxSubscriptionPurchase`, ce qui rapporte plus que la plupart de nos gamepasses. Le joueur, lui, veut jouer entre amis.
- Prix V0 : serveur privé à **100 R$ par mois** (le versement Plus dépend du prix du serveur et plafonne à 100 R$). Changer ce prix plus tard annule tous les abonnements en cours : bien le choisir dès le départ.
- Équilibre : en serveur privé, on farme sans voleurs. SAB l'accepte. Il faut **exclure les serveurs privés des classements hebdomadaires** (`WeeklyLeaderboardService`, vols et $/s), sinon on monte au classement en volant un ami.
- Règle Roblox : serveurs privés et accès payant ne se cumulent pas (page *Private servers*). Pour Plus : vérifier `Player.HasRobloxSubscription` avant de proposer l'abonnement, ne pas écrire les prix en dur, puisque les abonnés ont 10 à 20 % de remise (page *Roblox Plus*). La page ne dit rien des avantages en jeu pour les abonnés : à confirmer avant d'en donner.
- Travail : Ironix **S** (bonus Plus dans `MonetizationService`, à côté de Premium ; carte Plus ; classements sans les serveurs privés) ; Clément **XS** (une carte). Les réglages du Creator Hub sont à faire par Cantin, au nom du groupe.
- Priorité : **avant la sortie**.

**N3. Cadeaux (versions `[GIFT]`)**
- Quoi et pourquoi : offrir un gamepass ou un pack à un joueur du serveur. SAB, Egg, Pet et Criminal Sim le font tous, au même prix que l'original. Le joueur veut faire plaisir à un ami ou à un créateur de contenu.
- Prix V0 : celui de l'original (×2 Cash offert 299, etc.).
- Équilibre : neutre.
- Règle Roblox : avec la tarification régionale (activée par défaut sur les passes, `managed pricing`), un cadeau peut servir à acheter moins cher ailleurs. Il faut filtrer qui peut offrir à qui avec `GetUsersPriceLevelsAsync`, ou couper la tarification gérée sur les produits cadeau (pages *Regional pricing* et *Managed pricing*).
- Travail : Ironix **M** (un produit `Gift_<Clé>` par offre ; un gamepass offert est noté dans le profil du destinataire, et `HasPass` doit le lire aussi) ; Clément **S** (choix d'un joueur : liste `Template`, bouton « Gift » sur les cartes).
- Priorité : **juste après la sortie** (MAJ suivante).

**N4. Cosmétiques en Robux, sans effet**
- Quoi et pourquoi : skins de boutique (façade, enseigne, sol), skins de batte, trails et auras purement visuels (sans multiplicateur). C'est la longue traîne du genre : skins de base chez Dumpling (29 / 59), granges chez Pet (99 → 299), base de saison chez SAB (499), base chez Anime (999), tapis et trails chez Egg (15 → 2 999). Le joueur veut montrer sa boutique, que les autres voient en passant (`ShopSpy`).
- Prix V0 : skin de boutique 149 → 499, skin de batte 99 → 199, trail visuel 99 → 299.
- Équilibre : nul. C'est le meilleur revenu qui ne touche pas au vol.
- Règle Roblox : aucune règle particulière, sauf s'ils sont vendus en caisse (alors, objet aléatoire payant).
- Travail : Clément **L** (modèles ; c'est le gros du travail) ; Ironix **M** (possession, équipement, sauvegarde).
- Priorité : plus tard, une série par mise à jour du samedi.

**N5. Pass de saison « Heist Pass »**
- Quoi et pourquoi : une piste de paliers qui avance avec les quêtes du jour (`Config/Quests`, 3 par jour). Rangée gratuite, plus une rangée premium payante. Plants vs Brainrots vend sa rangée 299 R$ (35 paliers, environ 3 semaines), Pet son Champion Pass 399 et un « x2 Pass XP » 299. Le joueur a une raison de revenir tous les jours.
- Prix V0 : **299** la rangée premium, par saison de 4 semaines (une saison = un cycle de MAJ du samedi).
- Équilibre : récompenses premium cosmétiques ou en confort (boosts ×2 Cash, colis de zone), **jamais d'aura, d'outil ni de défense**.
- Règle Roblox : pas de fausse urgence. La fin de saison est une vraie date, et le compte à rebours ne se remet jamais à zéro (page *Monetization*, Guidelines). Si un palier donne un colis au hasard, la rangée premium payante devient un achat indirect d'objet aléatoire : afficher les cotes ou donner des colis à rareté fixe.
- Travail : Ironix **L** ; Clément **L** (écran de la piste, visuels des récompenses).
- Priorité : plus tard.

**N6. Exclusif de la semaine en achat direct**
- Quoi et pourquoi : vendre un des objets exclusifs de la caisse (`Items.Exclusives`) en direct, sans hasard, pendant une semaine. Anime Pack vend ainsi ses unités LIMITED de 1 499 à 3 799, Egg un exclusif à 999. C'est aussi **l'alternative que Roblox conseille pour les joueurs à qui la caisse est cachée** (« proposer directement les résultats à l'achat »). La catégorie LIMITED de l'index, déjà prévue et cachée (`IndexController`), s'y prête bien.
- Prix V0 : Épique 299, Légendaire 499, Mythique 999.
- Équilibre : un objet qui rapporte des $/s, donc un peu d'avance PvE. L'acheteur expose un objet unique, donc tentant à voler (voir 6.1).
- Règle Roblox : la rareté doit être vraie. « Cette semaine seulement » veut dire qu'il ne revient pas la semaine d'après, ou alors le dire (« returns later »).
- Travail : Ironix **S** (un produit par objet, rotation dans la Config) ; Clément **S** (carte ; icônes `ICON_Exclusive_*` existantes).
- Priorité : plus tard (ou avant la sortie si la caisse reste coupée en PROD).

**N7. Événements de serveur achetables**
- Quoi et pourquoi : lancer pour tout le serveur un format de `Config/LiveEvents` (Potion Rain 10 min, Item Rain 15 min) ou appeler le camion (`TruckEvent`), annoncé avec le nom de l'acheteur, comme la chance du serveur. Criminal Simulator vend le fourgon blindé « garanti chaque nuit » 1 699 et son « Intel » 499.
- Prix V0 : Potion Rain 149, appel du camion 199, Item Rain 399.
- Équilibre : tout le serveur en profite.
- Règle Roblox : ce qui tombe est tiré au hasard (types de potions, objets). Il faut donc traiter ces achats comme des objets aléatoires payants (cotes affichées, offre cachée aux joueurs restreints). Respecter aussi la règle de la feuille de route : un seul événement à la fois, les achats mis en file.
- Travail : Ironix **M** (file d'attente, comme `ServerLuck`) ; Clément **S** (cartes).
- Priorité : plus tard.

**N8. Publicités vidéo récompensées**
- Quoi et pourquoi : « Regarde une pub : ×2 sur tes gains hors ligne » au retour du joueur, ou « ×2 Cash 10 min ». Pet a des produits « Ad: … » à 25 R$. Le joueur qui ne paie pas peut quand même gagner un petit plus.
- Prix V0 : gratuit (Roblox paie le créateur).
- Équilibre : neutre, si la récompense reste petite.
- Règle Roblox : récompense = un produit développeur, **jamais un objet aléatoire** (donc **pas de tour de roue**) ; annoncée clairement avant la pub ; lancée par le joueur ; jamais une barrière de progression. Éligibilité : créateur de 13 ans ou plus, identité vérifiée, 2FA, jeu public d'au moins **2 000 visiteurs uniques par mois** (page *Rewarded video ads*).
- Travail : Ironix **M** (`AdService`) ; Clément **XS** (un bouton).
- Priorité : plus tard (le jeu doit d'abord être public, avec du monde).

**N9. Abonnement « VIP Club »** (abonnement d'expérience)
- Quoi : chaque jour, un ×2 Cash de 30 min, plus un cosmétique exclusif par mois et un tag. Aucun jeu relevé n'en vend, à part les serveurs privés de SAB, et Roblox Plus lui fait concurrence.
- Prix V0 : 149 R$ par mois (minimum Roblox : 49).
- Règle Roblox : un seul niveau, les avantages ne se retirent jamais pendant l'abonnement, rien d'aléatoire dedans (sinon, achat indirect d'objet aléatoire) (page *Subscriptions*).
- Travail : Ironix **M** ; Clément **S**.
- Priorité : **basse**, à reconsidérer après les chiffres de vente.

**N10. Dernières marches**
- Quoi : lot de caisses ×50 à **3 499** (Egg, Dumpling) une fois la caisse plus riche ; plus tard, une marche ×16 de la chance du serveur (Anime Pack monte à ×64).
- Règle Roblox : comme la caisse.
- Travail : Ironix **XS** ; Clément **XS**.
- Priorité : plus tard.

**N11. Mettre en vente hors du jeu**
- Quoi : marquer « Listed » les gamepasses et les packs d'argent. Ils apparaissent alors sur la page du jeu, dans la recherche et après un achat de Robux (pages *Passes* et *Developer products*). Ne pas le faire pour la chance du serveur, qui n'a de sens que dans un serveur.
- Règle Roblox : `ProcessReceipt` correct ; le nôtre renvoie `NotProcessedYet` si le joueur est absent, et Roblox rappelle le reçu à son retour.
- Travail : un réglage du Creator Hub (Cantin) ; Ironix **XS** (test).
- Priorité : **avant la sortie**.

### 5.2 Ce qui est gratuit et pourrait se vendre en plus

**G1. Boost ×2 Cash à l'unité** (aujourd'hui offert par la roue, les quêtes et le calendrier)
- Pourquoi : Dumpling vend « 2x Income 15 min » 29, Egg « 2x Earnings » 99. Il va bien avec l'Admin Abuse du samedi (×2 pour tout le serveur).
- Prix V0 : **30 min à 39**.
- Équilibre : neutre ; il prolonge le boost en cours, comme `AddCashBoost` (déjà codé).
- Travail : Ironix **XS** (un produit, `MonetizationService.AddCashBoost` existe) ; Clément **XS** (carte, icône `UI_Icon_Reward_Boost`).
- Priorité : **avant la sortie**.

**G2. Tours de roue en plus** (`Wheel.ExtraSpin` existe, `ProductId = 0`)
- Pourquoi : SAB 99, Dumpling 19.
- Prix V0 : 19 / 49 / 149.
- Règle Roblox : **objet aléatoire payant**. Il faut afficher les chances de chaque secteur avant l'achat (poids 30 / 20 / 15 / 5 / 15 / 7 / 5 / 3, déjà sur 100) et cacher l'achat aux joueurs restreints. Les secteurs « BOX » et « RARE BOX » donnent un objet tiré au hasard, alors que Roblox demande les chances de chaque **résultat final**, avec un total d'exactement 100 % : afficher aussi la répartition des raretés de ces colis, ou remplacer ces deux secteurs, pour le tour payant, par des lots fixes.
- Travail : Ironix **S** ; Clément **S** (panneau des chances dans `UI_Wheel`).
- Priorité : plus tard (ou avant la sortie si le panneau est prêt).

**G3. Pass « Night Shift » : gains hors ligne sur 12 h** (aujourd'hui `Offline.MaxHours = 4`)
- Pourquoi : Pet vend « 2x Offline Cash » 45. Le joueur veut que sa boutique travaille pendant la nuit.
- Prix V0 : **99** (gamepass).
- Équilibre : nul pour le PvP, puisque la boutique ne se vole pas hors ligne.
- Travail : Ironix **XS** (`OfflineService` lit le gamepass) ; Clément **S** (icône).
- Priorité : avant la sortie si le temps le permet.

**G4. Échelle de vitesse** (le tapis est gratuit, les ×2 existent) : voir 3.1, de ×2 à 49 jusqu'à ×16 à 799. Ironix **S** (règle « la plus haute gagne », dans `TrainingService.GetGainMultiplier`) ; Clément **S** (icônes ×4, ×8, ×16 dans la même famille). **Avant la sortie** pour ×2 et ×4.

**G5. Potions d'argent en lot** (aujourd'hui ramassées dans le couloir)
- Pourquoi : Pet « Halloween Potions » 49, Anime « Cash Potion » 19.
- Prix V0 : **3 potions Money à 29** (dans la limite de `Potions.MaxStock = 5`).
- Équilibre : seulement Money (revenus ×2 pendant 120 s). **Jamais l'invisibilité**, qui sert au vol entre joueurs.
- Travail : Ironix **XS** ; Clément **XS**.
- Priorité : plus tard.

**G6. Nouvelle série de quêtes du jour**
- Pourquoi : Egg « Shop Reroll » 49, « Rift Refresh » 49.
- Prix V0 : **19**, une fois par jour au plus (les récompenses des quêtes restent petites : 5 à 10 min d'argent, un colis).
- Travail : Ironix **S** ; Clément **XS**.
- Priorité : plus tard.

**G7. Apparences de tapis exclusives**
- Les 11 apparences de `Upgrades.TreadmillVariants` (Base à Void) se gagnent avec les niveaux : **ne pas les vendre**, elles marquent la progression. En revanche, des apparences **en plus, seulement en Robux**, sont dans la norme du genre (Egg 15 → 2 999, Pet 249). V0 49 → 249. Clément **M** (modèles) ; Ironix **S**. Plus tard.

**G8. Garder plus d'objets à la renaissance** (aujourd'hui 3, `KEEP_ITEMS`)
- Pass « +2 objets gardés », V0 199. C'est du confort, sans PvP, mais ça touche au rythme des renaissances : à passer au simulateur avant. Ironix **S**. Plus tard, à valider.

**G9. Ne pas vendre** : les auras et trails à multiplicateur, les outils, les tuiles de l'arbre (défenses, pièges, gardes), la cabine d'essayage et les codes (voir 6.1).

---

## 6. Ce qu'il ne faut pas faire

### 6.1 Injustice entre joueurs (le vol doit rester juste)

- **Ne pas forcer la boutique d'un autre en Robux** (SAB vend « Unlock Base » 39 R$). C'est le contraire d'un vol juste.
- **Ne pas vendre l'immunité** : `Shield30` (« Nobody can rob your shop », 30 min) et un verrou permanent comme le « Forever Lock » de Wild Horse retirent une cible du serveur. S'il faut absolument une défense payante, plutôt **Instant Shutter** (un verrou normal tout de suite), jamais pendant une poursuite ni quand on porte un objet volé, avec la recharge normale. Même logique pour **Revenge** : jamais plus d'une fois par vol, et sans téléport dans une boutique.
- **Pas d'armes ni de défenses en Robux** : SAB vend Laser Gun 499 et Ban Hammer 999, Criminal Sim l'AK-47. Ni auras ni trails à multiplicateur (`Cosmetics`), ni outils plus forts que le kit de la zone (Hydraulic Gloves plafonnés, voir 3.1), ni tuiles de défense (`SkillTree`), ni potion d'invisibilité.
- **Pas de commandes d'admin pour les joueurs** (SAB 7 999) : elles servent à embêter les autres.
- **Les objets payants se volent comme les autres** : l'objet exclusif de la caisse, une fois exposé, se vole, et aucun code ne le protège. C'est la règle du genre (chez SAB, les Lucky Blocks se volent), mais il faut **le dire** dans la description de la caisse (« Can be stolen like any item! »). Sinon, on a des plaintes du type « j'ai payé, on me l'a pris ».
- **Le VIP ne doit pas doubler le verrou** : +10 s, comme SAB, plutôt que +30 s (3.1).

### 6.2 Règles de Roblox sur les objets aléatoires payants

- Tout ce qui se paie en Robux (directement, ou avec une monnaie achetée en Robux) et dont le résultat est tiré au hasard demande **toutes les issues et leurs chances en %**, avant l'achat, avec un total d'exactement 100 %. Une icône (i) seule ne suffit pas. C'est le cas de la caisse (déjà en règle), du tour de roue payant, de `Luck3`, de la chance du serveur, d'un événement de serveur payant, et d'un pass ou abonnement qui donne des colis au hasard.
- Pour les **boosts de chance** : expliquer leur effet en chiffres avant l'achat, et tenir les chances à jour pendant qu'ils agissent.
- `ArePaidRandomItemsRestricted` vrai : **cacher ou bloquer** l'offre. La chance du serveur et la roue ne le font pas encore.
- `IsPaidItemTradingAllowed` faux : pas d'échange des objets payants. Nous n'avons pas d'échange ; si on en ajoute un, il faudra ce filtre.
- **Pas de récompense de pub aléatoire** (donc jamais « une pub = un tour de roue »).

### 6.3 Image et tromperie

- **Pas de fausse remise** : le Starter Pack affiche « 75% OFF » d'un prix de 399 qu'il n'a jamais eu. Roblox : une remise doit être « sincère et équitable », et un article toujours « en promotion » au même prix ne l'est pas.
- **Pas de faux minuteur** : jamais de compte à rebours qui se remet à zéro, ni d'« offre du jour » qui revient tous les jours. Le minuteur du Starter Pack est honnête (1re heure de jeu, jamais remis à zéro) s'il le dit : « First hour of play ».
- **Pas de textes pressants** pour un public jeune : Roblox conseille « View Item » plutôt que « GET IT NOW », « See Price » plutôt que « LAST CHANCE ». Aucun texte de ce genre n'existe aujourd'hui dans `src/` : garder cette règle pour la suite.
- **Pas deux offres au même effet** (×2 Speed et ×2 Training), ni un nom qui ne dit plus ce que fait l'offre (Fast Open).
- **Pas d'accès payant** au jeu : il coupe la découverte et ne se cumule pas avec les serveurs privés.
- **Pas trop de gamepasses** : les gros jeux en ont 2 ou 3. Ajouter des produits, pas des gamepasses.

### 6.4 Pièges techniques

- **Prix codés en dur** : le bouton du HUD (`HudMenuController`, `Price.Amount`) écrit le prix de la Config. Avec la tarification régionale (activée par défaut) et la remise Plus, il peut afficher un prix plus haut que le vrai. La boutique, elle, lit déjà `GetProductInfoAsync`. Il faut faire pareil sur le HUD, et calculer l'étiquette de remise sur le prix lu.
- **Ne jamais supprimer ni recréer** une offre dont l'Id est écrit (règle déjà notée dans la Config).

---

## 7. Les 5 meilleures idées (pour Cantin)

1. **Remettre nos prix d'aplomb avant la sortie** : ×2 Cash de 449 à 299, ×2 Speed et ×2 Training en une seule échelle (×2 à 49, ×4 à 149), Auto Collect à 99, packs d'argent de 29 à 699 avec une vraie remise sur les gros, Open Now en 2 paliers, et plus de faux « 75% OFF » sur le Starter Pack.
2. **Allumer la chance du serveur (149 / 399 / 999) dès la sortie**, avec ses cotes affichées et le filtre `PolicyService`. C'est le gros poste de Steal a Brainrot.
3. **Serveurs privés payants à 100 R$ par mois, bonus +10 % pour Roblox Plus et carte « Get Plus »** : Roblox paie jusqu'à 100 R$ par abonné Plus sur nos serveurs et 750 R$ par abonnement lancé depuis le jeu, pour très peu de code.
4. **Offrir en cadeau** chaque gamepass et chaque pack (versions `[GIFT]`), comme tous les gros jeux du genre.
5. **Cosmétiques en Robux sans effet** (skins de boutique et de batte) et un **Heist Pass** de saison bâti sur les quêtes : du revenu qui ne touche jamais au vol entre joueurs.

---

## 8. Questions pour Cantin (avec une proposition V0)

1. **×2 Cash** : 299 (ma proposition) ou l'échelle à 29 / 99 / 399 / 999 de la fiche `DoubleCash.md` (demande de Clément du 21/11) ? V0 : 299, et une échelle pour la vitesse seulement.
2. **×2 Speed** : 49 (ma proposition, marche 1 de l'échelle) ou 149 (ton V0 du 23/11) ? Et `DoubleTraining` devient-il la marche ×4 ?
3. **Fast Open** : renommé « Quick Lock » à 99, ou retiré au lancement ?
4. **Hydraulic Gloves** : puissance de 1,5 × le meilleur outil, plafonnée à l'Angle Grinder, pour garder la zone 6 à deux ?
5. **Shield30** : on le retire pour de bon ?
6. **Serveurs privés** : 100 R$ par mois, en excluant ces serveurs des classements hebdomadaires ?
7. **VIP** : verrou +10 s au lieu de +30 s ?

---

## Sources

**Règles de Roblox** (lues le 2026-11-24)
- Objets aléatoires payants : https://create.roblox.com/docs/production/monetization/paid-random-items
- Lignes directrices de monétisation (sections *Presenting products* et *Promoting to global audiences*) : https://create.roblox.com/docs/production/monetization
- `PolicyService` : https://create.roblox.com/docs/reference/engine/classes/PolicyService
- Abonnements : https://create.roblox.com/docs/production/monetization/subscriptions
- Publicités vidéo récompensées : https://create.roblox.com/docs/production/promotion/rewarded-video-ads
- Serveurs privés : https://create.roblox.com/docs/production/monetization/private-servers
- Roblox Plus (créateurs) : https://create.roblox.com/docs/production/monetization/roblox-plus et annonce : https://about.roblox.com/newsroom/2026/04/introducing-roblox-plus-subscription
- Accès payant : https://create.roblox.com/docs/production/monetization/paid-access-robux
- Passes : https://create.roblox.com/docs/production/monetization/passes
- Produits développeur : https://create.roblox.com/docs/production/monetization/developer-products
- Tarification régionale et gérée : https://create.roblox.com/docs/production/monetization/regional-pricing et https://create.roblox.com/docs/production/monetization/managed-pricing
- Fin des Premium Payouts (Creator Rewards) : https://create.roblox.com/docs/production/monetization/engagement-based-payouts
- Community Standards (section *Roblox Economy*, jeux d'argent) : https://about.roblox.com/community-standards

**Marché**
- API publiques de Roblox, relevé du 2026-11-24 : `https://apis.roblox.com/game-passes/v1/universes/{universeId}/game-passes` et `https://apis.roblox.com/developer-products/v2/universes/{universeId}/developerproducts`. Univers : Steal An Egg 10563114921, Steal a Brainrot 7709344486, Steal an Anime Pack 10701622575, Steal A Dumpling 10770229689, Steal A Pet And Ride It 10769315427, Steal a PC 10769563057, Criminal Simulator 10769851460, Jailbreak 245662005, Restaurant Tycoon 3 7094518649.
- Benchmark du 21/11 (Wild Horse, Superpower) : `docs/claude/gamepasses/benchmark-2026-11-21.md` ; benchmark du genre du 17/11 : `docs/claude/notes/2026-11-17_benchmark-genre-steal-a.md`.
- SAB, relevé du 10/11 : https://buffget.com/news/steal-a-brainrot-game-pass-prices-robux-2026
- SAB, « Unlock Base » (guides de fans, non officiels) : https://progameguides.com/?p=999806
- Steal An Egg, boutique : https://allthings.how/steal-an-egg-how-to-get-gamepasses-in-roblox/
- Plants vs Brainrots, pass de saison : https://beebom.com/plants-vs-brainrots-season-pass-guide
- Grow a Garden, caisse cosmétique : https://beebom.com/roblox-grow-a-garden-cosmetic-items-guide/
