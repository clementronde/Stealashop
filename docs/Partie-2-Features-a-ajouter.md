# Partie 2 · Features à ajouter

Tout ce qui sort après le lancement du MVP du 18 décembre 2026, à raison d'une mise à jour par samedi. Le cœur du jeu, l'équipe, la tech et la bible assets sont dans la [Partie 1 · MVP](Partie-1-MVP.md).

## 1. Ordre de sortie

La boutique Robux sort en premier, le 26 décembre : c'est le moment où les joueurs activent les cartes cadeaux Roblox reçues à Noël. Sans boutique ce jour-là, on rate le pic d'achat de l'année.

1. **MAJ 1, samedi 26 décembre** : boutique Robux (gamepasses et produits), récompenses quotidiennes et hebdomadaires.
2. **MAJ 2, samedi 2 janvier** : défenses de niveau 1 (épaisseur de vitre, caméras de sécurité, rideau, coffre-fort, niveaux de boutique) + index d'objets.
3. **MAJ 3, samedi 9 janvier** : renaissances + agents de sécurité.
4. **MAJ 4, samedi 16 janvier** : pièges, régénération de vitre, mutations, quêtes quotidiennes, premier événement « Casse du siècle ».
5. **Ensuite** : une nouveauté par semaine, prise dans les idées de rétention (section 5), puis la grande MAJ « Centre commercial » (section 6).

Chaque mise à jour sort à 16 h (heure de Paris, 10 h à New York), avec un compte à rebours visible en jeu et un code cadeau.

## 2. Défenses avancées de la boutique

Le joueur dépense son argent pour rendre sa boutique plus dure à braquer. Chaque défense se voit de l'extérieur : le voleur sait à quoi il s'attaque avant de frapper.

**Point de départ au MVP** (Partie 1, section 6) : les PV de la vitrine valent 50 × les dégâts par coup du propriétaire. Un voleur de même niveau met donc environ 9 s à la casser. S'y ajoutent l'alarme, la batte, 1 coffre-fort gratuit et les règles anti-frustration.

| Défense | Effet | Niveaux et coût V0 | MAJ |
| --- | --- | --- | --- |
| Épaisseur de vitre | Multiplie les PV de la vitrine : ×1,5, ×2, ×3, ×5, ×8. La vitre est visiblement plus épaisse et plus teintée à chaque niveau | 25 K, 300 K, 4 M, 50 M, 600 M $ | MAJ 2 |
| Caméras de sécurité | N1 : alerte dès le 1er coup sur ta vitrine. N2 : voleur surligné à travers les murs pendant 30 s. N3 : flèche, distance et son spatialisé jusqu'au voleur | 5 K, 150 K, 5 M $ | MAJ 2 |
| Rideau métallique | Bouton dans la boutique : vitrine invulnérable 30 s, recharge 180 s, impossible si un voleur est déjà dedans | 30 s offert ; 60 s pour 50 K $, 90 s pour 1 M $ | MAJ 2 |
| Coffre-fort | Présentoirs non volables (1 offert dès le MVP) | +1 à 250 K $, +1 à 25 M $ | MAJ 2 |
| Niveau de boutique | Stand, Boutique, Magasin, Concept store, Flagship : la boutique grandit visuellement et gagne 1 emplacement de piège par niveau | 10 K, 250 K, 6,25 M, 156 M $ | MAJ 2 |
| Agents de sécurité | Un vigile PNJ posté dans ta boutique. Dès qu'un voleur prend un objet, il le poursuit comme les vigiles des magasins PNJ ; s'il le touche, l'objet revient. Vitesse de l'agent : 20, 28, 36, 44, 52 | 1 agent ; niveaux à 100 K, 2 M, 40 M, 800 M, 16 Md $. Un 2e agent avec la 8e renaissance | MAJ 3 |
| Pièges | Derrière la vitrine, recharge 45 s. Peau de banane (glissade 1,5 s), colle (−60 % de vitesse 3 s), trappe (éjecte dehors), laser (étourdit 2 s), filet (immobilise 3 s) | 1 emplacement par niveau de boutique, 4 max ; 20 K à 20 M $ selon le piège | MAJ 4 |
| Régénération de vitre | +1 % des PV/s par niveau (base 3 %) | 50 K, 500 K, 5 M, 50 M, 500 M $ | MAJ 4 |

**Lisibilité** : en approchant d'une boutique, le panneau de repérage liste ses défenses par icônes (vitre ×3, caméra N2, 1 agent). Avec la régénération, une vitrine n'est cassable que par un joueur qui fait au moins 0,43 % de ses PV par coup : le PvP se joue entre joueurs de niveau proche.

## 3. Écrans d'UI (Clément)

Toute l'UI est conçue et construite par Clément dans Studio. Ironix branche la logique en suivant le contrat UI (Partie 1, section 2.2). Ces 4 écrans arrivent après le lancement ; chacun a un bouton sur le HUD, à droite, à portée de pouce.

### 3.1 Boutique Robux (MAJ 1)

- **Onglets** : Offres (pack de départ, offre du jour), Gamepasses, Argent, Boosts. C'est la 3e boutique du jeu (Partie 1, section 5.9) : on l'ouvre par le bouton du HUD, partout, ou par le comptoir doré de la zone safe.
- **Carte produit** : icône 3D rendue, nom, effet en une ligne, prix en Robux, bouton d'achat. Déjà possédé = coche verte, bouton grisé.
- **Contenu et prix** : section 4 de cet onglet.

### 3.2 Renaissances (MAJ 3)

Pour renaître, il faut un montant d'argent ET un objet précis, que l'on remet (il disparaît). Les premières renaissances sont très simples : la 1re se fait en 20 minutes environ, avec l'objet Rare offert par le tutoriel. Ensuite, chaque palier demande 10 fois plus d'argent et un objet plus rare, venu d'une zone plus lointaine. Chaque renaissance donne +50 % de revenus permanents, qui s'additionnent (×1,5 après la 1re, ×2 après la 2e, ×3 après la 4e). Les temps de jeu visés sont cumulés depuis la première connexion, à ajuster en bêta.

| Renaissance | Argent requis | Objet requis (remis) | Récompense en plus des +50 % de revenus | Temps de jeu visé |
| --- | --- | --- | --- | --- |
| 1 | 10 K$ | Pot de nouilles (Rare, zone 1) | Aura « Renaissance » | 20 min |
| 2 | 100 K$ | Voiture télécommandée (Rare, zone 2) | +1 coffre-fort | 45 min |
| 3 | 1 M$ | Robot jouet (Épique, zone 2) | +25 % de gains d'entraînement | 1 h 15 |
| 4 | 10 M$ | Console portable (Épique, zone 3) | Trail « Renaissance » | 2 h |
| 5 | 100 M$ | Diamant brut (Épique, zone 4) | Marteau-piqueur débloqué | 3 h |
| 6 | 1 Md$ | Couronne (Légendaire, zone 4) | +25 % de gains d'entraînement | 5 h |
| 7 | 10 Md$ | Masque ancien (Légendaire, zone 5) | Bélier débloqué | 8 h |
| 8 | 100 Md$ | Coffre de diamants (Légendaire, zone 6) | 2e agent de sécurité | 12 h |
| 9 | 1 000 Md$ | Météorite (Mythique, zone 5) | Aura « Légende » | 18 h |
| 10 et suivantes | ×10 à chaque fois | Clé du coffre ultime (Mythique, zone 6) | Titre affiché au-dessus de la tête | — |

- **Remis à zéro** : argent, outils, Vitesse et Force, améliorations du tapis, du banc et des présentoirs, auras et trails.
- **Gardé** : 3 objets au choix, l'index, les défenses, tous les achats Robux.
- **Écran** : barre de progression de l'argent, vignette de l'objet requis (grisée tant qu'on ne l'a pas), trois colonnes « tu perds / tu gardes / tu gagnes », confirmation en 2 temps.
- **Prestige** : annonce à tout le serveur et titre au-dessus de la tête (« Renaissance 2 »).

**Aperçu (2026-11-08, liaison L-071)** : le bouton Rebirth et l'écran `UI_Rebirth` montrent déjà la prochaine renaissance (tableau ci-dessus, recopié dans `Config/Rebirths`) avec la progression de l'argent. La renaissance elle-même (DEV-120) n'est pas codée : le bouton reste grisé, « Coming soon ».

### 3.3 Récompenses quotidiennes et hebdomadaires (MAJ 1)

- **Quotidien** : calendrier de 7 jours, une réclamation par jour, remise à zéro à minuit UTC. J1 : 5 min de revenus. J2 : colis Standard. J3 : 15 min de revenus. J4 : colis Premium. J5 : boost ×2 argent 15 min. J6 : 30 min de revenus. J7 : colis Luxe garanti Épique ou mieux.
- **Jour manqué** : on recule d'un jour au lieu de repartir à J1, c'est moins punitif.
- **Hebdomadaire** : un coffre se débloque après 5 jours de connexion entre lundi et dimanche. Il contient l'aura ou le trail exclusif de la semaine + 1 colis Luxe.
- **Écran** : calendrier avec le jour actuel mis en avant, jauge des 5 jours pour le coffre, pastille rouge sur le bouton du HUD quand une récompense attend.

**Proposition V0 d'Ironix (2026-11-08), à valider par Clément** : boutons Invite et Rewards du HUD et écran `UI_Rewards` (liaison L-057), avancés avant la MAJ 1. Le calendrier, le jour manqué et le bonus d'amis restent ceux du doc ; ce qui suit complète ce qu'il ne dit pas.

- **« X min de revenus »** : X minutes du revenu par seconde du joueur au moment où il réclame, avec au moins 50 $ par minute (J1 : 250 $ au moins, J3 : 750 $, J6 : 1 500 $), pour qu'un nouveau joueur reçoive quelque chose.
- **Colis offerts** : de la zone la plus haute parmi les objets du joueur (zone 1 s'il n'en a pas), posés sur un établi libre, avec l'attente d'ouverture habituelle. Sans établi libre, la récompense attend et reste réclamable. J7 : zone 2 au moins, puisque la zone 1 n'a que des Communs (L-033).
- **Boost ×2 argent** : double les revenus des présentoirs, compté seulement pendant le jeu (le temps restant est sauvegardé) ; il se multiplie avec les autres bonus ; un deuxième boost prolonge le premier au lieu de le doubler.
- **Temps de jeu** (onglet `PlaytimeTab`) : paliers à 5, 15, 30 et 60 min de jeu **dans la journée** plutôt que par session, pour qu'on ne les refasse pas en se reconnectant ; remise à zéro à minuit UTC ; chaque palier se réclame avec `ClaimButton`. 5 min : 2 min de revenus (100 $ au moins). 15 min : colis Standard. 30 min : boost ×2 argent pendant 10 min. 60 min : colis Premium.
- **Hebdomadaire** : le coffre reste pour la MAJ 1 ; `UI_Rewards` n'a pas d'onglet pour lui.
- **Inviter un ami** : le bouton ouvre l'invitation de Roblox. Le bonus est celui de la section 5 : +10 % de revenus par ami Roblox présent dans le serveur (30 % au plus), et +10 % pour les membres du groupe Roblox du studio. L'envoi d'une invitation ne donne rien à lui seul.
- **Mesure** : chaque gain part avec `LogEconomyEvent` (Partie 1, 14.2).

**Codé (DEV-101, 2026-11-09, vague 19), à valider par Clément** : RewardService et UI_Rewards branchés avec ces valeurs (Config/Rewards). Choix V0 en plus : un jour de recul par jour manqué, jamais avant J1, et nouveau cycle à J1 après J7 ; temps de jeu compté par le serveur, AFK compris ; colis offerts dans l'inventaire (barre) depuis L-089, plus sur un établi ; mutation tirée sur les colis offerts ; le boost ×2 marche même quand la boutique Robux est coupée ; événement custom RewardClaimed en plus de LogEconomyEvent (qui ne compte que l'argent). Remotes ClaimDaily() et ClaimPlaytime(minutes) ; profil v8.

### 3.4 Index d'objets (MAJ 2)

- **Grille** par zone (6 onglets + Secrets). Objet découvert en couleur ; non découvert = silhouette noire avec la couleur de sa rareté.
- **Compteur** : « 23 / 38 découverts ».
- **Récompenses** : zone complète = +5 % de revenus permanents ; index complet = aura exclusive « Collectionneur ».
- **Relance** : quand les mutations arrivent (MAJ 4), une colonne Or, Diamant, Néon par objet relance la collection.

**Codé (DEV-111, 2026-11-08), avancé avant la MAJ 2** (Clément veut le bouton Index visible dès le MVP, liaison L-071) : découverte sauvegardée (profil v4, la migration compte les objets déjà possédés), écran `UI_Index` (onglets par zone et Secrets, silhouettes, compteur « X / 83 discovered »), +5 % de revenus permanents par zone complète, additionnés aux autres bonus en pour cent. Pas encore : l'aura « Collectionneur » de l'index complet, à créer par Clément (liaison L-083).

## 4. Monétisation (boutique Robux, MAJ 1)

On vend du confort, de la vitesse de progression et l'émotion du moment (vol subi, colis rare), jamais l'accès au contenu. Les prix sont des points de départ à tester.

### 4.1 Gamepasses (achat unique)

| Gamepass | Effet | Prix (Robux) |
| --- | --- | --- |
| ×2 Argent | Double tous les revenus | 449 |
| ×2 Entraînement | Double les gains du tapis et du banc | 299 |
| VIP | Tag dans le chat, aura VIP, +10 % de revenus, +1 coffre-fort, rideau +30 s | 249 |
| Encaissement auto | La caisse se vide toute seule, même loin de la base | 199 |
| Ouverture rapide | Toutes les attentes d'ouverture des colis PNJ 2 fois plus courtes | 299 |
| +4 présentoirs | 4 présentoirs au-delà du maximum | 349 |
| Gants hydrauliques | Outil exclusif : puissance = 2,5 × ton meilleur outil acheté | 499 |

### 4.2 Produits développeur (achats répétables)

| Produit | Effet | Prix (Robux) |
| --- | --- | --- |
| Ouvrir maintenant | Termine l'attente d'un colis PNJ | 19 à 99 selon le temps restant |
| Packs d'argent | 10, 60 ou 300 min de tes revenus actuels | 49, 199, 799 |
| Vengeance | Téléporte derrière le voleur pendant une poursuite | 25 |
| Rideau instantané | Ferme ta boutique sans attendre la recharge (après la MAJ 2) | 29 |
| Pack de départ | Offre unique la 1re heure : ×2 argent 1 h + Marteau + 50 000 $ | 99 |
| Chance ×3 | Raretés boostées pendant 15 min, cotes affichées | 79 |
| Bouclier 30 min | Boutique inviolable, une fois par session | 99 |

**Règles Roblox à respecter**

- **Pas de colis contre Robux** : un objet aléatoire payant oblige à afficher les probabilités et il est restreint dans certains pays. Pour « Chance ×3 » : afficher les cotes et masquer l'offre si `PolicyService` renvoie `ArePaidRandomItemsRestricted`.
- **Bonus Premium** : +10 % de revenus pour les abonnés Roblox Premium, ce qui augmente les Premium Payouts.
- **Achats** : traités côté serveur et idempotents (Partie 1, section 9.6).

**Codé (DEV-100, 2026-11-08), caché derrière `Features.RobuxShop` jusqu'à la MAJ 1** : `MonetizationService` (reçus idempotents, `PurchaseGranted` seulement une fois le `PurchaseId` sauvegardé ; gamepasses lus à l'arrivée et à la fin d'un achat), `Config/Monetization` (Id = 0 tant que l'offre n'est pas créée sur le Creator Hub), `RobuxShopController` (écran `UI_RobuxShop` de Clément). Codés : ×2 Argent, ×2 Entraînement, Encaissement auto, Ouverture rapide, +4 présentoirs, bonus Premium, packs d'argent, Ouvrir maintenant, pack de départ. Pas encore : VIP, Gants hydrauliques, Vengeance, Rideau instantané, Chance ×3, Bouclier 30 min. **Valeurs V0 d'Ironix, à valider avec Clément (liaison L-066, L-067)** : Ouvrir maintenant en 4 produits selon le temps restant (jusqu'à 1 min : 19 ; 3 min : 39 ; 8 min : 59 ; au-delà : 99 ; pas proposé sous 10 s), les secondes payées sans colis en attente vont aux prochains colis posés ; packs d'argent = revenu actuel, bonus compris, × minutes, au moins 50 $ par minute ; revenus = valeur exposée × (1 + Premium) × ×2 Argent × boost ×2 (les pourcentages s'additionnent, les ×2 se multiplient) ; pack de départ : « 1re heure » = temps de jeu cumulé, boost compté en jeu seulement, Marteau équipé s'il est plus fort que l'outil en main ; Ouverture rapide divise aussi l'attente des colis déjà posés ; +4 présentoirs = `DisplaySlot_21` à `_24` de la boutique ; historique des reçus limité à 100. **Vitrine (2026-11-08, liaison L-071)** : `Features.RobuxShopPreview` montre déjà le bouton Shop et l'écran, avec les offres et leurs prix ; tant que `RobuxShop` est coupé, aucun achat ne part et « Soon » remplace le prix au clic.

## 5. Idées de rétention en plus

Les trois idées les plus rentables pour l'effort : le « Casse du siècle » (rendez-vous social toutes les 30 min), les gains hors ligne (une raison de revenir chaque jour) et les quêtes quotidiennes (un objectif à chaque session).

| Idée | Pourquoi ça retient | Effort | Priorité |
| --- | --- | --- | --- |
| **Casse du siècle** : toutes les 30 min, un fourgon blindé géant traverse le boulevard. Les 6 joueurs le frappent ensemble ; chacun reçoit un colis selon ses dégâts (Luxe pour le top 3) | Rendez-vous régulier, coopération entre joueurs qui se volent par ailleurs, garde les joueurs en jeu jusqu'au prochain passage | Moyen | Haute (MAJ 4) |
| **Gains hors ligne** : 100 % des revenus pendant 4 h max (décision du 2026-11-09, L-084), réclamés au retour (« Ta boutique a gagné 1,2 M $ pendant ton absence ») | Raison concrète de revenir chaque jour | Faible | Haute (MAJ 1) |
| **Quêtes quotidiennes** : 3 par jour (« Casse 10 vitrines en zone 3 », « Défends ta boutique 1 fois ») | Donne un objectif clair à chaque session | Faible | Haute (MAJ 4) |
| **Récompenses de temps de jeu** : à 5, 15, 30, 60 min de session | Allonge les sessions | Faible | Haute (MAJ 1) |
| **Bonus d'amis et de groupe** : +10 % par ami dans le serveur (30 % max), +10 % pour les membres du groupe Roblox | Acquisition par invitation, sessions plus longues | Faible | Haute (MAJ 1) |
| **Événements live** : événement admin en direct chaque samedi, « Nuit des soldes » (vitrines PNJ à −50 % de PV pendant 10 min, chaque heure) | Pic de joueurs à heure fixe, contenu à partager en vidéo | Moyen | Haute (MAJ 4) |
| **Notifications Roblox** : « Ton colis Légendaire est prêt » quand une longue attente se termine hors ligne | Ramène le joueur sans qu'il ait à y penser | Faible | Moyenne |
| **Objet limité par mise à jour** : un Secret disponible une semaine seulement | Peur de rater, retour chaque samedi | Faible | Moyenne |
| **Classements hebdomadaires récompensés** : top 100 en $/s et en vols = aura du classement | Compétition, raison de jouer longtemps | Moyen | Moyenne |
| **Roue de la fortune gratuite** : 1 tour par jour, tours bonus au temps de jeu, jamais vendue en Robux sans cotes affichées | Rituel de connexion | Faible | Moyenne |
| **Braquage en équipe** : 2 joueurs braquent ensemble un magasin d'une zone au-dessus de leur niveau | Social, jouer avec ses amis | Élevé | Basse |
| **Échanges entre joueurs** | Très fort dans le genre, mais risque d'arnaques et de duplication | Élevé | Basse, après stabilisation |

## 6. Centre commercial (refonte du lobby et du couloir)

Le MVP garde un lobby simple, comme le jeu de référence. Ensuite, toute la map devient un grand centre commercial : le lobby devient son atrium, le couloir sa galerie marchande. Grâce aux tags (Partie 1, section 2.1), le code change peu : c'est surtout un chantier de modélisation.

- **Atrium (le lobby)** : grand hall sous verrière, avec fontaine, escalators et un 2e niveau pour la vue et le food court. Les 6 boutiques des joueurs sont des devantures face à face autour de l'atrium, avec une enseigne au nom du joueur.
- **Galerie marchande (le couloir)** : une allée de centre commercial bordée de boutiques PNJ, découpée en 6 zones qui deviennent des ailes à thème (alimentation, jouets, high-tech, joaillerie, art, banque). Chaque aile a son portique « Zone 3 · Vitesse conseillée 28 ».
- **Distances** : on garde les distances de retour de la Partie 1, section 4 (60 à 660 studs), pour ne pas casser l'équilibrage.
- **La nuit** : à la fermeture du centre, un rideau de fer géant descend à l'entrée de la galerie et les agents de nuit patrouillent avec leur lampe torche (mêmes règles que la Partie 1, section 5.12).
- **Ambiance** : musique d'ascenseur, annonces au micro (« Le centre commercial ferme dans 30 secondes »), sols brillants, plantes, bancs.
- **Quand** : grande MAJ après la MAJ 4. Il faut compter environ 3 semaines de modélisation pour Clément ; date à fixer ensemble.

| ID | Tâche | Qui | Prio | Statut |
| --- | --- | --- | --- | --- |
| MOD-140 | Atrium : hall sous verrière, fontaine, escalators, 2e niveau, 6 devantures de joueurs | Clément | P0 | À faire |
| MOD-141 | Galerie marchande : allée, 12 boutiques PNJ refaites en boutiques de centre commercial, 6 portiques de zone | Clément | P0 | À faire |
| MOD-142 | Rideau de fer géant de fermeture + éclairage de nuit du centre | Clément | P1 | À faire |
| DEV-150 | Rebrancher parcelles, magasins et vigiles sur la nouvelle map par tags, revérifier les distances | Ironix | P0 | À faire |
| DEV-151 | Rondes de nuit adaptées à la galerie (points de ronde, lampes torches) | Ironix | P1 | À faire |
| DEV-152 | Annonces au micro et musique d'ambiance liées au cycle jour/nuit | Ironix | P2 | À faire |

## 7. Backlog Partie 2

27 tâches réparties en 4 mises à jour. Préfixes : DEV = Ironix (code), MOD = Clément (modèles), UI = Clément (écrans). Une tâche UI et sa tâche DEV avancent ensemble, sur le même contrat de noms. Les tâches du centre commercial sont en section 6.

| ID | Tâche | Qui | MAJ | Prio | Statut |
| --- | --- | --- | --- | --- | --- |
| DEV-100 | MonetizationService : gamepasses, produits, ProcessReceipt idempotent | Ironix | MAJ 1 | P0 | À faire |
| UI-100 | Écran Boutique Robux : onglets, cartes, achat | Clément | MAJ 1 | P0 | À faire |
| MOD-100 | Rendus d'icônes des gamepasses et produits | Clément | MAJ 1 | P0 | À faire |
| DEV-101 | RewardService : calendrier de 7 jours + coffre hebdomadaire | Ironix | MAJ 1 | P0 | À faire |
| UI-101 | Écran récompenses quotidiennes et hebdomadaires + pastille sur le HUD | Clément | MAJ 1 | P0 | À faire |
| DEV-102 | Temps de jeu, gains hors ligne, bonus amis et groupe | Ironix | MAJ 1 | P1 | À faire |
| UI-102 | Fenêtre « pendant ton absence » + récompenses de temps de jeu | Clément | MAJ 1 | P1 | À faire |
| DEV-110 | DefenseService : épaisseur de vitre, caméras N1 à N3, rideau, coffre-fort, niveaux de boutique | Ironix | MAJ 2 | P0 | À faire |
| MOD-110 | Vitres épaisses (5 niveaux), caméra, rideau animé, coffre-fort, bouton | Clément | MAJ 2 | P0 | À faire |
| MOD-111 | Parcelle niveaux 2 à 5 | Clément | MAJ 2 | P1 | À faire |
| UI-110 | Panneau d'achat des défenses + icônes de défense sur le panneau de repérage | Clément | MAJ 2 | P0 | À faire |
| DEV-111 | Index : découverte, compteur, récompenses de zone | Ironix | MAJ 2 | P0 | À faire |
| UI-111 | Écran Index : grille, silhouettes, compteur | Clément | MAJ 2 | P0 | À faire |
| DEV-120 | Renaissances : conditions argent + objet, remise à zéro, bonus | Ironix | MAJ 3 | P0 | À faire |
| UI-120 | Écran Renaissance : progression, objet requis, perds / gardes / gagnes | Clément | MAJ 3 | P0 | À faire |
| DEV-121 | Agents de sécurité de boutique : IA de défense | Ironix | MAJ 3 | P0 | À faire |
| MOD-120 | Agent de sécurité : 5 looks de niveau (accessoires R15) | Clément | MAJ 3 | P0 | À faire |
| DEV-130 | Pièges (5 types) + régénération de vitre | Ironix | MAJ 4 | P1 | À faire |
| MOD-130 | Pièges : banane, colle, trappe, laser, filet | Clément | MAJ 4 | P1 | À faire |
| DEV-131 | Mutations Or, Diamant, Néon | Ironix | MAJ 4 | P1 | À faire |
| MOD-131 | Variantes de matériau des mutations | Clément | MAJ 4 | P1 | À faire |
| DEV-132 | Quêtes quotidiennes | Ironix | MAJ 4 | P1 | À faire |
| UI-130 | Écran des quêtes | Clément | MAJ 4 | P1 | À faire |
| DEV-133 | Casse du siècle : fourgon blindé, partage des colis | Ironix | MAJ 4 | P1 | À faire |
| MOD-132 | Fourgon blindé cassable (intact, défoncé) | Clément | MAJ 4 | P1 | À faire |
| DEV-140 | Classements hebdomadaires, notifications Roblox, objet limité | Ironix | Plus tard | P2 | À faire |
| DEV-141 | Roue de la fortune gratuite | Ironix | Plus tard | P2 | À faire |
