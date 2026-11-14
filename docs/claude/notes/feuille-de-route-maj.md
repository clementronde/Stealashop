# Feuille de route des mises à jour : les 8 premiers samedis (19/12/2026 → 6/2/2027)

Note de l'agent a143 (2026-11-14), pour Cantin (Ironix) et Clément. **Rien n'est décidé ni changé dans le jeu** :
c'est une proposition, à trancher à deux (section 5) puis à reporter dans le doc partagé (Partie 2, section 1, et
journal de la section 15). Sources lues : Partie 2 en entier, Partie 1 sections 11 et 15, `Config/Features`,
`Config/Admin`, `Config/SkillTree`, `Config/Rebirths`, `Config/FortuneTower`, `Config/TruckEvent`,
`equilibrage-v2-proposition.md` (passe 3), `beta-fermee.md`, liaison L-066, L-067, L-108, L-113, L-115, L-145, L-152.

## 0. En bref

- **Le problème** : le joueur moyen entre en zone 6 après **7 h 26 de jeu actif** (passe 3), l'acharné après
  6 h 26, le plus rapide vers 5 h. Pendant les vacances de Noël (en France du samedi 19/12 au lundi 4/1, à
  vérifier), un joueur accroché joue 2 à 3 h par jour : **il touche la zone 6 vers le 21 ou 22/12**, l'acharné dès
  le premier week-end. Après la zone 6, le MVP n'offre rien : ni renaissance (bouton « Coming soon »), ni
  Fortune Tower (coupée), un seul objet Secret (Golden Lucky Cat), aucun Divine.
- **La réponse** : avancer la **Renaissance au 26/12 avec la boutique Robux** (MAJ 1), au lieu du 9/1 ; allumer la
  **Fortune Tower et de nouveaux Secrets le 2/1** ; garder la cabine d'essayage (L-113), qui dépend des
  renaissances, pour le 16/1.
- **Ce qui a changé depuis la Partie 2** : une bonne part des MAJ 2 et 4 prévues est **déjà au MVP** (arbre de
  compétences avec vitre, régénération, murs, caméras, coffre ; index ; mutations ; gains hors ligne ; récompenses
  quotidiennes et de temps de jeu ; camion). Les tuiles « Soon » de l'arbre (`Coded = 0` : Bodyguards, Curtain,
  DoorGuard, Traps) deviennent du contenu de MAJ tout trouvé : l'UI existe déjà.
- **Le vrai goulot est Clément** : chaque MAJ lui demande des modèles, de l'UI ou des icônes, en plus d'une charge
  fixe chaque semaine (section 2). Le code, lui, peut être écrit d'avance et coupé dans `Features`.

## 1. Les 8 samedis

Chaque MAJ sort à **16 h, heure de Paris** (Partie 2, section 1), avec un compte à rebours en jeu et un code
cadeau. Charge : **petite** = moins d'une journée, **moyenne** = 2 à 4 jours, **grosse** = une semaine ou plus,
pour la personne concernée.

| Samedi | MAJ | Contenu en une ligne | Ironix | Clément |
| --- | --- | --- | --- | --- |
| 19/12 | MAJ 0 « Lendemain du lancement » | Correctifs des premières 24 h, `Config` réglée sur les vraies données, premier événement live | petite à moyenne (imprévisible) | petite |
| 26/12 | **MAJ 1 « Noël »** | Boutique Robux allumée + Renaissances 1 à 4 + coffre hebdomadaire | moyenne (presque tout codé avant) | moyenne |
| 2/1 | **MAJ 2 « Après la zone 6 »** | Fortune Tower + 3 nouveaux Secrets + 1er Divine + 1er Secret limité | petite | moyenne à grosse |
| 9/1 | MAJ 3 « Renaissances, suite » | Renaissances 5 à 10 + Marteau-piqueur et Bélier + quêtes quotidiennes | moyenne | moyenne |
| 16/1 | **MAJ 4 « Cabine d'essayage »** | Se déguiser en PNJ, dénoncer, voler (L-113) | grosse | moyenne à grosse |
| 23/1 | MAJ 5 « Défense de la boutique » | Agents de sécurité (Bodyguards, DoorGuard), rideau, pièges : les tuiles « Soon » de l'arbre | grosse | moyenne |
| 30/1 | MAJ 6 « Casse du siècle » | Fourgon blindé à heure fixe toutes les 30 min + classements hebdomadaires | moyenne | moyenne |
| 6/2 | MAJ 7 « Rendez-vous » | Roue de la fortune gratuite, notifications Roblox, colonnes de mutations de l'index ; le centre commercial se prépare pour mars | moyenne | petite (Clément modélise le centre commercial) |

### MAJ 0 · samedi 19/12 · « Lendemain du lancement »

- **Contenu** : aucune fonction nouvelle. Les bugs remontés le jour du lancement, les valeurs de `Config` revues sur
  les premières mesures (temps par zone, `ZoneReached` de la note bêta), le **premier événement live à 16 h**
  (section 3) et un code cadeau (boost ×2 argent 15 min, qui existe déjà dans `RewardService`).
- **Pourquoi** : sortir une fonction le lendemain d'un lancement, c'est risquer deux casses à la fois. Le premier
  samedi sert à prouver le rythme (« il se passe quelque chose chaque samedi ») et à corriger.
- **Ironix** : correctifs ; système de codes cadeaux (absent du code : un remote `RedeemCode`, une liste de codes
  dans `Config`, un code par profil) ; l'événement live (section 3) s'il n'est pas prêt avant le 18.
- **Clément** : un champ de saisie du code (dans `UI_Settings` ou `UI_Rewards`), une miniature « UPDATE » pour la
  page du jeu.
- **Charge** : Ironix petite à moyenne selon les bugs ; Clément petite.

### MAJ 1 · samedi 26/12 · « Noël » : boutique Robux + Renaissances 1 à 4

- **Contenu** :
  - **Boutique Robux** (`Features.RobuxShop = true`) : déjà codée (DEV-100) avec ×2 Argent, ×2 Entraînement,
    Encaissement auto, Ouverture rapide, +4 présentoirs, Premium, packs d'argent, Ouvrir maintenant, pack de
    départ. En plus si le temps le permet : **VIP** et **Gants hydrauliques** (`Hydraulic Gloves`, gardé par
    l'équilibrage passe 2 et 3). Les autres (Vengeance, Rideau instantané, Chance ×3, Bouclier 30 min) attendent.
  - **Renaissances 1 à 4** (DEV-120, avancé de la MAJ 3) : argent + objet remis, remise à zéro, +50 % de revenus
    par renaissance, récompenses des 4 premiers paliers (aura « Renaissance », +1 coffre-fort, +25 % d'entraînement,
    trail « Renaissance »). L'écran `UI_Rebirth` existe en aperçu (L-071) ; il lui manque la confirmation en deux
    temps et les colonnes « tu perds / tu gardes / tu gagnes ». Les paliers 5 et plus restent affichés
    « Coming 9/1 ».
  - **Coffre hebdomadaire** (5 connexions entre lundi et dimanche, Partie 2, 3.3) : le reste de DEV-101.
- **Pourquoi à ce moment-là** : le 26/12 est le jour des cartes cadeaux Roblox (Partie 2, section 1), et c'est
  aussi le moment où les premiers joueurs bloquent en zone 6. La renaissance donne en même temps un but au joueur
  de 20 minutes (la 1re coûte 10 K$) et au joueur de la zone 6. La mettre au 9/1, comme prévu, laisse deux semaines
  de vacances sans rien après la zone 6.
- **Ironix** : avant le 18/12, coder la renaissance coupée (`Features.Rebirth = false`) et la passer au simulateur
  d'équilibrage (le tableau de la Partie 2, 3.2, date d'avant la v2 : les montants et les « temps de jeu visés »
  sont à revérifier avec la remise à zéro, voir section 5) ; créer les Ids des produits en DEV et en PROD (L-067) ;
  tester un vrai achat sur DEV ; le coffre hebdomadaire. Après le 18 : VIP et Gants hydrauliques si la semaine le
  permet.
- **Clément** : les trois choses de L-066 (icônes des produits, MOD-100 ; habillage final de `UI_RobuxShop`) ; les
  icônes des gamepasses sur le Creator Hub ; l'habillage final de `UI_Rebirth` (confirmation, trois colonnes) ;
  l'aura et le trail « Renaissance » ; un emplacement de coffre hebdomadaire dans `UI_Rewards` (absent aujourd'hui) ;
  le modèle des Gants hydrauliques si on les sort.
- **Charge** : Ironix moyenne si la renaissance est codée avant le 18 (sinon grosse, trop pour la semaine de Noël) ;
  Clément moyenne.

### MAJ 2 · samedi 2/1 · « Après la zone 6 » : Fortune Tower et objets Secret

- **Contenu** :
  - **Fortune Tower** (`Features.FortuneTower = true`, L-145) : vitrine géante en zone 6 toutes les 40 à 60 min,
    3.6B de PV (passe 3), à casser à plusieurs, 8 colis Luxe Mythique ou Secret en taille Huge ou Colossal. Codée et
    coupée, commandes d'admin `Fortune`, `FortuneOpen`, `FortuneSeal` déjà au panel (L-152).
  - **3 nouveaux Secrets** (il n'y en a qu'un) et le **1er objet Divine** (la rareté existe depuis L-106, la liste
    `Items.Divines` est vide). Proposition : la Fortune Tower devient la seule source de Divine (0 % aujourd'hui).
  - **1er Secret limité** (Partie 2, section 5) : un Secret qu'on ne trouve que pendant une semaine.
- **Pourquoi à ce moment-là** : dernier week-end des vacances ; c'est la semaine où le plus de joueurs sont en
  zone 6 sans renaissance avancée. La Fortune Tower est le seul contenu « à plusieurs » pensé pour la zone 6.
- **Ironix** : allumer l'interrupteur, répondre aux questions (b) et (c) de L-145 (Mythiques des autres zones,
  colis ou objets), ajouter les Secrets et le Divine dans `Config/Items` et l'index (onglet Secrets), la rotation
  du Secret limité (une date de début et de fin par objet dans `Config`). Petite.
- **Clément** : le modèle `ENV_Event_FortuneVault` et son point `FortuneVaultSpawn` (L-145, point d) ; les
  4 objets (≤ 4 000 triangles chacun) et leurs icônes ; valider les valeurs de L-145. Moyenne à grosse : c'est la
  MAJ la plus chargée pour lui, à commencer avant le 18 si possible.

### MAJ 3 · samedi 9/1 · « Renaissances, suite » et quêtes quotidiennes

- **Contenu** : renaissances 5 à 10 et suivantes avec leurs récompenses (Marteau-piqueur à la 5e, Bélier à la 7e,
  +25 % d'entraînement à la 6e, 2e agent à la 8e, aura « Légende » à la 9e, titre au-dessus de la tête) ;
  **quêtes quotidiennes** (DEV-132 : 3 par jour, « Casse 10 vitrines en zone 3 »).
- **Pourquoi à ce moment-là** : la rentrée (4/1) fait baisser le temps de jeu ; les quêtes donnent un objectif court
  à chaque session. Les acharnés auront fait les 4 premières renaissances en deux semaines : il leur faut la suite.
- **Ironix** : les deux nouveaux outils dans `Config/Tools` et leur effet sur la vitrine de la zone 6 (passe 3 : les
  PV de la zone 6 suivent la meilleure arme ; il faut décider si les outils de renaissance comptent, section 5) ;
  QuestService (compteurs déjà disponibles côté serveur : casse, vol, ouverture). Le « 2e agent » de la 8e
  renaissance n'a de sens qu'après la MAJ 5 : le remplacer ou l'afficher « Coming ».
- **Clément** : modèles `TOOL_Jackhammer` et `TOOL_BatteringRam` (≤ 1 500 triangles) et leurs animations de frappe ;
  l'aura « Légende » ; l'écran `UI_Quests` (UI-130), en gris d'abord.
- **Charge** : Ironix moyenne ; Clément moyenne.

### MAJ 4 · samedi 16/1 · « Cabine d'essayage »

- **Contenu** : la mécanique principale vue par Clément (L-113) : une tuile `FittingRoom` de l'arbre débloque une
  cabine dans la boutique ; on se déguise en passant d'une zone ouverte par les renaissances (zone n avec n − 1
  renaissances, à confirmer), pendant 60 s au plus ; on dénonce un magasin, la police (`NPC_Police`) rattrape les
  voleurs qui s'y trouvent, et on vole leur objet ; un coup de batte démasque.
- **Pourquoi à ce moment-là** : elle a besoin des renaissances (MAJ 1 et 3) pour ouvrir ses zones, et des témoins
  et de la police, déjà en jeu. C'est la plus grosse nouveauté de gameplay : la sortir quand les joueurs ont déjà
  plusieurs renaissances lui donne un public. Avant, ses règles doivent être tranchées (propositions a à f de L-113).
- **Ironix** : DisguiseService (apparence de passant sans nom, chrono, sortie de zone, dénonciation, démasquage,
  vol qui relance le vigile) ; validation serveur de tout. Grosse.
- **Clément** : modèle de la cabine, tuile de l'arbre, écran de choix de zone avec le chrono de 60 s, effet de
  démasquage, éventuellement une animation de « dénonciation » (marqueur `Call`, déjà au contrat). Moyenne à grosse.

### MAJ 5 · samedi 23/1 · « Défense de la boutique »

- **Contenu** : les quatre tuiles « Soon » de l'arbre (`Coded = 0`) : **Bodyguards** (agent de sécurité qui
  poursuit le voleur, Partie 2, section 2 : vitesse 20 à 52), **DoorGuard**, **Curtain** (rideau 30 s offert, 60 s,
  90 s), **Traps** (banane, colle, trappe, laser, filet).
- **Pourquoi à ce moment-là** : une fois le vol entre joueurs bien rodé et les boutiques remplies d'objets chers
  (Secrets, Divines), les joueurs veulent protéger ce qu'ils ont. Rien ne presse avant : la décision de Cantin du
  12/11 (L-115) défend la boutique par le propriétaire seul, et le PvP doit d'abord vivre.
- **Ironix** : l'IA de l'agent (reprise de `GuardService` et du bot qui défend, L-146), les pièges (DEV-130), le
  rideau. Grosse ; si la semaine déborde, les pièges passent à la MAJ 6.
- **Clément** : 5 looks d'agent (MOD-120, accessoires R15) et ses animations (reprises du vigile) ; 5 pièges
  (MOD-130) ; le bouton et l'animation du rideau. Moyenne.

### MAJ 6 · samedi 30/1 · « Casse du siècle » et classements

- **Contenu** : **Casse du siècle** (DEV-133) : toutes les 30 min, à heure fixe, un fourgon blindé géant traverse
  le couloir ; tous le frappent, chacun reçoit un colis selon ses dégâts (Luxe pour le top 3).
  **Classements hebdomadaires** (DEV-140) : top 100 en $/s et en vols, aura du classement.
- **Pourquoi à ce moment-là** : un rendez-vous toutes les 30 min garde les joueurs connectés en semaine, quand les
  sessions raccourcissent. Les classements arrivent quand il y a assez de joueurs pour qu'un top 100 veuille dire
  quelque chose.
- **Ironix** : le fourgon reprend presque tout `TruckEventService` (PV partagés, colis, annonces) : il faut une
  heure fixe au lieu d'un tirage, un partage selon les dégâts, un trajet. Classements : `OrderedDataStore`, remise à
  zéro le lundi, récompense. Moyenne.
- **Clément** : fourgon blindé cassable (MOD-132 : intact, défoncé ; reprendre les états à 75, 50, 25 % du
  camion), un panneau de classement dans le hub, l'aura du classement. Moyenne.

### MAJ 7 · samedi 6/2 · « Rendez-vous »

- **Contenu** : **roue de la fortune gratuite** (DEV-141 : 1 tour par jour, tours bonus au temps de jeu, jamais
  vendue sans cotes affichées) ; **notifications Roblox** (« Ton colis Légendaire est prêt ») ; **colonnes de
  mutations de l'index** (Partie 2, 3.4 : relance la collection maintenant que les mutations existent).
- **Pourquoi à ce moment-là** : des fonctions de rétention légères, pendant que Clément modélise le **centre
  commercial** (Partie 2, section 6 : environ 3 semaines), qui pourrait sortir fin février ou début mars.
- **Ironix** : RouletteService, notifications (Experience Notifications de Roblox), colonnes de l'index. Moyenne.
- **Clément** : écran de la roue, habillage des colonnes de l'index ; le reste de son temps va au centre commercial
  (MOD-140 à MOD-142). Petite pour cette MAJ.

### Ce qui reste pour après le 6/2

Centre commercial (MOD-140 à 142, DEV-150 à 152), braquage en équipe, échanges entre joueurs (décision ouverte en
section 15 de la Partie 1), les gamepasses restants (Vengeance, Rideau instantané, Chance ×3, Bouclier 30 min),
la cabine étendue aux zones 5 et 6, une zone 7 si les joueurs vont trop vite (rien n'est prévu dans le doc).

## 2. La charge fixe de chaque samedi

En plus du contenu de la MAJ, chaque semaine :

| Quoi | Ironix | Clément |
| --- | --- | --- |
| Compte à rebours en jeu jusqu'au samedi 16 h | une fois codé, une date dans `Config` | un élément d'UI (une seule fois) |
| Code cadeau de la semaine | une ligne de `Config` | — |
| Secret limité de la semaine (à partir du 2/1) | une ligne de `Config` | un objet et son icône, chaque semaine |
| Aura ou trail exclusif du coffre hebdomadaire (à partir du 26/12) | une ligne de `Config` | une aura ou un trail, chaque semaine |
| Événement live du samedi (section 3) | rien si le planificateur existe | rien, sauf un événement à thème |
| Miniature et texte « UPDATE » de la page du jeu | publication | une image |
| Notes de mise à jour (Discord, en anglais) | à écrire | — |

**À trancher** : un Secret limité **et** une aura exclusive chaque semaine, c'est un objet de plus et un effet de
plus par semaine pour Clément, en plus de la MAJ. Proposition : en préparer 4 de chaque avant le 18/12, pour le
mois de janvier.

## 3. Événements récurrents du samedi

Le principe des « Admin Abuse » de Steal a Brainrot : à heure fixe, pendant 30 à 45 min, le jeu devient
généreux pour tout le monde, et un admin se montre. C'est ce qui fait venir les joueurs à 16 h et alimente les
vidéos.

### Ce qui existe déjà

| Brique | Où | Ce qu'elle permet |
| --- | --- | --- |
| Panel admin | `Config/Admin`, `AdminService`, `UI_Admin` | Donner argent, stats, objets, colis, auras ; téléporter. **`StartEvent` (camion, nuit, jour, Fortune) est marqué `StudioOnly`** : refusé sur un serveur en ligne aujourd'hui |
| Admins hors Studio | `Config/Admin` : membres du groupe de rang ≥ 254, ou `UserIds` (vide) | Cantin et Clément peuvent être admins en PROD si leur rang est bon |
| Camion | `TruckEventService`, `Config/TruckEvent` | Toutes les 8 à 12 min, 12 colis, PV partagés, annonces |
| Fortune Tower | `FortuneTowerService`, `Config/FortuneTower` (coupée) | Vitrine géante, 8 colis Mythique ou Secret, annonces à tout le serveur |
| Multiplicateur de revenus | `DisplayService.GetGlobalMultiplier` (Premium, ×2 Argent, index) | Le bon endroit pour un « ×2 argent pour tout le serveur » |
| Potions | `PotionService`, `Config/Potions` (`SpawnEvery = 45`) | Une « pluie de potions » = un délai plus court pendant l'événement |
| Nuit | `NightCycleService` | Forcer une nuit (rondes, mur, rayons qui se remplissent) |
| Chance des colis | `Config/ShelfOpen`, `UnboxService`, compétence `PotionLuck` | Une « chance ×3 » pendant l'événement passerait par le tirage de la rareté |

### Ce qui manque (à coder une fois, puis chaque événement n'est qu'une ligne de `Config`)

1. **Un `EventService` planifié** : une liste d'événements dans `Config/LiveEvents` (début en UTC, durée, effets),
   lancée **sur tous les serveurs à la même heure** sans admin présent. Les serveurs ont 8 joueurs : un admin ne
   peut être que dans un seul. Optionnel : `MessagingService` pour qu'un admin lance un événement sur tous les
   serveurs depuis le panel (le code n'utilise pas encore `MessagingService`).
2. **Des effets d'événement** branchés aux bons endroits : multiplicateur de revenus du serveur
   (`GetGlobalMultiplier`), multiplicateur de chance des colis, délai du camion, délai des potions, PV des vitrines
   PNJ (Nuit des soldes).
3. **`StartEvent` autorisé en ligne** pour les admins (aujourd'hui `StudioOnly`), avec un journal.
4. **Une bannière d'événement** (Clément) : nom, chrono, effet en une ligne, en bas ou au milieu de l'écran (rien
   d'important en haut, règle d'UI).

Charge : Ironix moyenne (une fois), Clément petite (la bannière). **À faire avant le 18/12 si possible**, sinon pour
le 19/12.

### Formats proposés (V0, valeurs à régler)

| Événement | Durée | Effet | Briques |
| --- | --- | --- | --- |
| **Admin Abuse** (le rendez-vous du samedi 16 h) | 30 à 45 min | ×2 revenus pour tous, camion toutes les 2 à 3 min, un admin qui distribue des colis dans le hub | EventService, `GetGlobalMultiplier`, `TruckEvent`, panel admin |
| **Pluie de colis** | 15 min | colis qui tombent dans le hub et le couloir, ramassables par tous (comme les colis du camion) | colis au sol du camion |
| **Chance ×3** | 15 min | raretés boostées pour tous, cotes affichées | tirage des colis |
| **Nuit des soldes** (Partie 2, section 5) | 10 min, chaque heure | vitrines PNJ à −50 % de PV | `Config/Zones` lu avec un facteur |
| **Fortune garantie** | une apparition | la Fortune Tower apparaît à heure annoncée | `FortuneTowerService` (après le 2/1) |
| **Pluie de potions** | 10 min | potions 5 fois plus fréquentes | `PotionService` |
| **Nuit éternelle** | 10 min | nuit forcée, vigiles de nuit, rayons qui se remplissent | `NightCycleService` |
| **Week-end ×2 entraînement** | samedi et dimanche | gains du tapis ×2 | `TrainingService` |

Règles proposées : un seul événement à la fois ; jamais de Robux pour entrer ; les effets s'additionnent aux
gamepasses mais pas entre événements ; chaque événement part dans la télémétrie (pic de joueurs, revenus).

## 4. Ce qui doit être prêt avant le 18/12

Pour tenir le rythme sans travailler la semaine de Noël, tout ce qui suit est **codé et coupé** dans `Features`
avant le gel du 11/12, ou au plus tard le 18 :

| Quoi | Qui | Pour |
| --- | --- | --- |
| Ids des produits et gamepasses créés en DEV et PROD (L-067), un achat réel testé sur DEV | Ironix | MAJ 1 |
| Icônes des produits et habillage de `UI_RobuxShop` (L-066) | Clément | MAJ 1 |
| **Renaissance codée** derrière `Features.Rebirth = false`, avec le simulateur relancé (renaissances comprises) | Ironix | MAJ 1 |
| `UI_Rebirth` final (confirmation, trois colonnes), aura et trail « Renaissance » | Clément | MAJ 1 |
| Coffre hebdomadaire codé et coupé | Ironix | MAJ 1 |
| Codes cadeaux et compte à rebours de MAJ | Ironix (code), Clément (champ et compte à rebours) | MAJ 0 |
| EventService planifié + `StartEvent` en ligne + bannière | Ironix, Clément | MAJ 0 |
| Valeurs de la Fortune Tower validées (L-145) et modèle `ENV_Event_FortuneVault` commencé | Clément | MAJ 2 |
| 4 Secrets limités et 4 auras ou trails de la semaine prêts | Clément | janvier |
| Règles de la cabine d'essayage tranchées (L-113, a à f) | Cantin et Clément | MAJ 4 |
| Une routine de publication écrite (PROD, notes, miniature, code) | Ironix | chaque samedi |

Si ce n'est pas tenable avec la bêta (30/11 → 6/12) et le gel du 11/12, la priorité est : **1. boutique Robux,
2. renaissance, 3. EventService**. Le reste peut s'écrire entre le 19 et le 25/12.

## 5. Décisions à prendre (Cantin et Clément)

1. **Renaissance avancée au 26/12** (avec la boutique Robux) au lieu du 9/1 ? Proposition : oui.
2. **Montants des renaissances** : garder le tableau de la Partie 2 (10 K$ → ×10) ou le recalculer au simulateur
   v2 avec la remise à zéro ? Proposition : recalculer, la 1re toujours vers 20 min.
3. **Renaissance : on garde l'arbre de compétences** (les défenses) ? Proposition : oui (question ouverte de la
   section 15).
4. **Outils de renaissance** (Marteau-piqueur, Bélier) : comptent-ils dans les PV de la zone 6 (passe 3) ?
   Proposition : non, sinon la récompense s'annule.
5. **Fortune Tower le 2/1** et réponses (a) à (d) de L-145 : à Clément.
6. **Divine** : seulement par la Fortune Tower ? Proposition : oui.
7. **Un Secret limité et une aura exclusive chaque semaine** : Clément peut-il tenir ce rythme ? Sinon, un sur
   deux semaines.
8. **Cabine d'essayage le 16/1**, et ses règles a à f de L-113 : à trancher avant Noël.
9. **Défenses (MAJ 5) après la cabine** : d'accord avec la décision du 12/11 (L-115), qui défend par le
   propriétaire seul ?
10. **Événement live du samedi** : planifié sur tous les serveurs (proposition), ou seulement là où un admin est
    présent ?
11. **Qui est admin en PROD** : le rang 254 du groupe suffit-il, ou une liste de `UserIds` ?
12. **Centre commercial** : début mars, avec Clément qui le modélise dès fin janvier ? Proposition : oui.
13. **Heure de sortie** : garder 16 h de Paris (10 h à New York) ? Proposition : oui.
