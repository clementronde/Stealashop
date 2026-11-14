# Publication PROD : page du jeu, questionnaire de maturité, liste pas à pas (DEV-063, 2026-11-14)

**Tâche** : DEV-063, « Page du jeu, questionnaire de maturité, publication PROD ». **Fini quand** : jeu public le
18 décembre avec icône et miniatures. **Dépend de** : MOD-043. Propriétaire : Ironix (Cantin) ; Clément fait l'icône
et les miniatures (Partie 1, section 2, tableau « Page du jeu »).

Règles Roblox relues le 2026-11-14 sur la doc officielle (liens en fin de note). Rien n'est encore fait sur le
Creator Hub : cette note prépare, Cantin exécute. Les textes du jeu et de la page sont en anglais.

Repères (liaison, section 3.4, L-001) : groupe **RoundStone Studio** (ID 207192094, propriétaire Clément).
DEV = « Steal a Shop [DEV] » (GameId 10774974820, place 131580149465482). PROD = « Steal a Shop »
(GameId 10774998269, place 121215476173365), privée, publiée uniquement par Ironix après un playtest.

---

## 1. Page du jeu

### Titre : 3 propositions

| # | Titre | Pour | Contre |
| --- | --- | --- | --- |
| 1 | **Steal a Shop** (recommandé) | Suit la convention du genre (« Steal a … »), se cherche bien, nom déjà prévu pour la place PROD | Vérifier avant qu'aucun jeu connu ne porte exactement ce nom (Partie 1, règle de propriété intellectuelle) |
| 2 | Steal a Shop: Heist Street | Dit le braquage et le couloir, se distingue d'un éventuel homonyme | Plus long, coupé sur les petites cartes de la page d'accueil |
| 3 | Steal a Shop [Heist] | Court, le mot « Heist » aide la recherche | Roblox déconseille les décorations ; on peut y ajouter `[UPDATE]` les samedis, mais jamais de répétitions ni d'émojis en série (risque de rétrogradation) |

Garder le même titre dans la durée : Roblox prévient qu'un nom qui change souvent se retrouve moins bien.
Pour les samedis, mieux vaut annoncer la mise à jour dans la description et les miniatures que dans le titre.

### Description (anglais, à coller)

La première phrase résume le jeu (conseil de Roblox) ; mots-clés utiles sans répétition.

```text
Smash the window, grab the loot, outrun the guard, and build the richest shop on the street!

HOW TO PLAY
- Train on the treadmill for Speed and on the bench for Strength.
- Break into NPC stores along the street: smash the window before the witnesses call the police.
- Open the boxes on the shelves and grab what's inside, from Common to Secret.
- Run back to your shop before the guard catches you, then display your loot to earn cash every second.
- Upgrade your tools, buy auras and trails, and heist stores in harder zones.
- Defend your shop with your bat, or sneak into another player's shop and steal their best item.

6 zones from easy to legendary. When night falls, the street closes and night guards patrol.

NEW UPDATE EVERY SATURDAY!
Like and favorite the game to get notified of new zones, items and events.
```

Variante courte (une ligne, pour le champ de résumé des campagnes ou un partage) :
`Smash, grab, run! Heist NPC stores, display your loot and steal from other players. Updates every Saturday.`

À éviter dans la description : les promesses non vérifiables (« #1 game », « 50% off »), les noms d'autres jeux,
les mots-clés répétés.

### Genre et tags

- **Genre proposé** : Simulation, sous-genre Tycoon (la boucle « exposer, encaisser, améliorer » est celle d'un
  tycoon, comme les autres « Steal a … »). Alternative : Action. À choisir dans la liste du Creator Hub
  (Configurer > Informations de base), qui fait foi.
- **Mots-clés à placer dans la description** (Roblox n'a plus de champ de tags libres pour la recherche) :
  steal, heist, shop, loot, tycoon, robbery, guard.
- **Joueurs par serveur** : 8 (CLAUDE.md). La décision du 2026-11-12 parle de 8 à 10 : la valeur réglée dans le
  Creator Hub doit être celle du code (nombre de parcelles `PlayerPlot`). À vérifier par Cantin.
- **Appareils** : ordinateur, téléphone, tablette, console (la console affiche la page sans vidéo).

### Textes courts pour les miniatures (anglais)

Peu de texte, qui décrit le jeu, en haut ou au milieu : le bas de la miniature est caché par le nombre de joueurs.
Pas de prix ni de promesse.

| Miniature | Scène à montrer (vraie scène du jeu) | Texte |
| --- | --- | --- |
| 1 (principale) | Le joueur fracasse une vitrine, éclats en l'air, objet brillant derrière | **SMASH & GRAB!** |
| 2 | Le joueur court avec un objet Légendaire, le vigile juste derrière | **OUTRUN THE GUARD** |
| 3 | Sa boutique pleine d'objets exposés, $/s au-dessus | **BUILD THE RICHEST SHOP** |
| 4 | Un joueur vole l'objet d'un autre, la victime arrive avec sa batte | **STEAL FROM PLAYERS** |
| 5 | Le couloir de nuit, mur fermé, vigiles de nuit | **NIGHT HEISTS** |
| 6 | Colis qui s'ouvre sur un objet Secret | **FIND SECRET ITEMS** |
| Samedi | Nouveauté de la semaine | **NEW UPDATE!** (seulement le jour de la mise à jour) |

---

## 2. Questionnaire de maturité (Maturity & Compliance, devenu « Content Ratings Questionnaire »)

Il se remplit sur le Creator Hub (Paramètres de l'expérience > Questionnaire), ou à la première publication
publique. Quatre parties : type d'application, questions IARC, questions propres à Roblox, aperçu de la note.
Sans note, Roblox restreint le jeu pour tout le monde ; une réponse inexacte peut valoir une modération.

### Réponses proposées, d'après le contenu réel du MVP

| Rubrique | Question (résumée) | Réponse proposée | Pourquoi, dans le jeu |
| --- | --- | --- | --- |
| Première question | Contenu réservé aux adultes (restreint) ? | **Non, puis remplir le questionnaire complet** | Répondre « Non » sans tout remplir donne « Content May Vary », réservé aux 16 ans et plus contrôlés : il faut le questionnaire complet pour viser tous les âges |
| Violence | Y a-t-il de la violence ? | **Oui** | Coups de batte entre joueurs (PvP), le vigile et la police attrapent le joueur, outils de casse sur les vitrines |
| Violence | Contre qui ? | **Humains** (et non-humains) | La batte touche des avatars ; les vitrines (non-humains) sont la cible la plus fréquente |
| Violence | Type de monde | **Fantastique** | Ville cartoon, 6 zones à thème, objets imaginaires |
| Violence | Style | **Animé** | Style Roblox « studs », aucun rendu réaliste |
| Violence | Réactions des personnages | **Irréalistes** | Le joueur frappé tombe, se relève, 3 s d'immunité ; aucune blessure, aucun cadavre |
| Violence | Fréquence et caméra | **« Souvent et de loin » + « Rarement et de près »** | C'est la consigne de Roblox pour la caméra par défaut à la 3e personne |
| Violence | Comment le joueur le sait | **Violence directe** | Le coup de batte se voit |
| Sang, gore | Sang, mutilation ? | **Non** | Aucun sang, aucune blessure ; éclats de verre seulement |
| Armes | Armes réalistes ? | **Non** | Batte cartoon, outils de chantier (clé, pied-de-biche, marteau, masse, hache, disqueuse) qui ne frappent que les vitrines ; matraque cartoon du vigile ; pas d'arme à feu |
| Peur | Éléments effrayants ? | **Non** (ou « effrayant, rarement » si Cantin trouve la nuit oppressante) | Nuit, vigiles de nuit, battements de cœur sous 10 studs : tension de poursuite, pas d'horreur |
| Sexualité, rencontres | | **Non** | |
| Jeux d'argent | Thème de jeu d'argent ? | **Non** | Les colis s'ouvrent avec l'argent du jeu, sans mise ni pari ; aucune machine à sous, roulette ni casino. La Fortune Tower est coupée (`Features.FortuneTower = false`) et n'est pas un jeu d'argent non plus |
| Langage | Grossièretés ? | **Non** | Textes du jeu en anglais neutre |
| Substances | Alcool, drogue, tabac ? | **Non** | Les « potions » sont des bonus magiques : vérifier qu'aucune icône ne ressemble à une bouteille d'alcool |
| Humour grossier | | **Non** | |
| Achats numériques | Le jeu vend-il des produits, passes, objets aléatoires payants ? | **Non au MVP** | `Features.RobuxShop = false` : aucun produit ni passe, aucun appel à MarketplaceService. **À refaire à la MAJ 1 (26 décembre)** : « Oui » aux achats ; « Non » aux objets aléatoires payants tant qu'on tient la règle de la Partie 2 (pas de colis contre Robux ; « Chance ×3 » affiche les cotes et se cache si `PolicyService` renvoie `ArePaidRandomItemsRestricted`) |
| Divers | Communication entre joueurs ? | **Oui** | Chat Roblox (TextChatService) |
| Divers | Blocage et signalement ? | **Oui / Oui** | Fournis par Roblox |
| Divers | Modération du chat ? | **Oui** | Filtre de Roblox ; le jeu n'affiche aucun texte écrit par un joueur à part les noms |
| Divers | Accès réservé aux amis invités ? | **Selon le réglage** | « Oui » seulement si les serveurs privés sont activés dans le Creator Hub (rien n'est prévu au MVP) |
| Divers | Position physique précise ? | **Non** | Roblox ne la donne jamais au jeu |
| IARC | Symboles nazis, terrorisme, **techniques criminelles détaillées** ? | **Non** | Le vol est un thème cartoon (casser une vitrine, courir) : aucune méthode réelle de vol ou d'effraction n'est montrée ni expliquée |
| Roblox | Lieu social (hangout) ? | **Non** | Jeu à objectifs |
| Roblox | Création libre par les joueurs ? | **Non** | Le joueur range ses objets sur des présentoirs prévus |
| Roblox | Sujets sensibles (politique, religion…) ? | **Non** | |
| Roblox | Contenu d'autres expériences ? | **Non** | |
| Roblox | Interaction avec une IA ? | **Non** | |
| Roblox | Partage de médias, fil de contenu continu ? | **Non / Non** | |

### Note attendue

**Légère (Mild)**, descripteur « violence légère » (cartoon, répétée, réactions irréalistes, sans sang). Elle ouvre le
jeu à tous les âges, Roblox Kids et Roblox Select compris (sous réserve de leur évaluation). Si l'aperçu affiche
**Modérée** (souvent à cause de « Humains » + « Violence directe »), c'est encore jouable dès 9 ans (Select) et par les
16 ans et plus. Ne jamais « arranger » une réponse pour baisser la note : une note inexacte est modérée.

### Points à vérifier par Cantin avant d'envoyer

1. **Vérification du compte** : pour rendre un jeu public, le compte doit avoir plus de 2 jours, être en règle et
   passer un contrôle d'âge (estimation faciale ou pièce d'identité). Pour tous les âges : vérification d'identité,
   double authentification, et soit 2 mois de Roblox Plus/Premium, soit des frais remboursables de 1 000 Robux.
   **À vérifier** : pour un jeu de groupe, la doc ne dit pas si c'est le compte qui publie (Cantin) ou le propriétaire
   du groupe (Clément) qui doit remplir ces conditions. Le tester sur la place PROD **avant** décembre, pas le 18.
2. La **police** et le **vigile** « attrapent » sans frapper (renvoi en zone safe ou en base) : le confirmer en Play ;
   s'ils frappent, la réponse « Humains, violence directe » ne change pas.
3. Les **potions** (icônes et noms) ne doivent rien évoquer d'alcool ; sinon, « Substances » change.
4. **Réglage des serveurs privés** dans le Creator Hub, qui décide de la réponse « amis invités ».
5. Refaire le questionnaire à chaque ajout qui change une réponse : boutique Robux (MAJ 1), Fortune Tower activée,
   tout nouveau contenu effrayant.

---

## 3. Liste de publication PROD, pas à pas

À faire par Cantin, de préférence une première fois à blanc vers le 7 décembre (place PROD restée privée), puis le
jour du lancement.

### Étape 1 : place PROD et droits du groupe

- [ ] Place PROD « Steal a Shop » (GameId 10774998269) bien dans le groupe RoundStone Studio, privée tant qu'on n'a
      pas fini (Creator Hub > Créations > Groupe).
- [ ] Le rôle « Dev » de Cantin a le droit de publier sur cette expérience (Groupe > Rôles, ou Accès de
      collaboration de l'expérience).
- [ ] Le playtest du jeudi sur DEV est réussi (Partie 1, circuit, règle 5).

### Étape 2 : réglages du code (sur le disque de Cantin, `src/`, avant la synchro de la copie)

- [ ] `src/shared/Config/Features.luau` : `RobuxShop = false` (MVP sans boutique Robux), `FortuneTower = false`
      (pas validée par Clément), `Rebirth = false`. **À décider par Cantin et Clément** : garder
      `RobuxShopPreview = true` (bouton Shop et prix visibles, « Soon » au clic) et `RebirthPreview = true` au
      lancement, ou les couper. Si l'aperçu Robux reste, les prix affichés ne sont pas achetables : c'est voulu (L-071).
- [ ] Les autres interrupteurs comme en playtest : `NightCycle`, `AntiCheat`, `ReturnToBase`, `TruckEvent`,
      `Settings`, `ShelfOpen`, `Index` à `true`.
- [ ] **Admins** (`src/shared/Config/Admin.luau`) : `StudioEveryone = true` ne joue qu'en Studio ; en ligne, est admin
      un UserId de `UserIds` (vide aujourd'hui) ou un membre du groupe de rang `MinGroupRank = 254` ou plus
      (`GroupId = 0` = le groupe propriétaire). Vérifier le **rang du rôle « Dev »** de Cantin : s'il est sous 254,
      Cantin ne sera pas admin en PROD ; soit monter le rang, soit ajouter son UserId. Personne d'autre.
- [ ] Les commandes `StudioOnly` (événements, potions, gamepass de test) sont refusées en ligne : rien à faire.
- [ ] Sortie propre : aucun `print` de débogage bruyant laissé dans les services chauds (relire la sortie en Play).

### Étape 3 : DataStore PROD séparé de DEV

- [ ] Rien à coder : les DataStores appartiennent à une **expérience** ; DEV (GameId 10774974820) et PROD
      (10774998269) sont deux expériences, donc `PlayerData` (nom fixé dans `DataService`, à ne jamais changer) est
      une base différente dans chacune. Les profils de test de DEV ne passent jamais en PROD.
- [ ] Creator Hub > PROD > Paramètres > Sécurité : **activer l'accès Studio aux services d'API** seulement le temps
      d'un test, puis le couper (sinon un Play en Studio sur PROD écrit dans les vrais profils).
- [ ] Ne jamais publier la place DEV par-dessus PROD avec l'accès API ouvert pendant que des joueurs jouent : publier,
      puis redémarrer les serveurs (« Mettre à jour » / « Redémarrer les serveurs » du Creator Hub).

### Étape 4 : copie locale et `tools/prod-check.luau`

- [ ] Dans la place DEV (Team Create), Fichier > **Enregistrer dans un fichier** (`StealAShop-PROD-AAAAMMJJ.rbxl`),
      fermer, puis ouvrir ce fichier (son `PlaceId` est 0 : le retrait y est permis).
- [ ] Coller `tools/prod-check.luau` dans la barre de commande avec `RETIRER = false` : lire le rapport.
- [ ] Il doit lister, et le retrait enlève : `Workspace/_SHOWROOM_CLEMENT` (L-032), `Workspace/_INBOX_CLEMENT`,
      `Workspace/_SANDBOX_IRONIX`, `ServerStorage/_GREYBOX_REMPLACE`, les deux **packs piégés de L-143**
      (« Aura Pack Premium By Sanzzzzz », « THE ULTRA VFX AND PARTICLES PACK », où qu'ils soient) et les scripts
      `Runtime` / `ScreenBuilder` du piège.
- [ ] Il signale sans supprimer : sources avec `require(<numéro>)`, `loadstring`, `getfenv`, `HttpService` hors des
      dossiers de code ; tout script hors des dossiers de code (ex. `ReplicatedStorage.GuiAnimatorPlugin`, L-143 : à
      retirer s'il ne sert pas) ; les effets `FX_` admis ; `HttpEnabled` (doit être `false`) ; les attributs de test
      (`AntiCheatStrict`, `NightSkipTo`, `TruckSpawnNow`, `TutorialReset`, `FortuneTest`).
- [ ] Mettre `RETIRER = true`, relancer, puis relancer avec `RETIRER = false` : rapport propre attendu (aucun dossier,
      aucun pack, aucun script suspect, `HttpEnabled = false`).
- [ ] `ServerStorage/AnimRigs` et `ServerStorage/RBX_ANIMSAVES` restent (jamais retirés, invisibles des joueurs).

### Étape 5 : droits des assets (animations, sons, images, maillages)

- [ ] Toutes les **animations** du registre de la liaison (section 3.2) appartiennent au groupe : en Play sur la copie,
      aucune ligne « Failed to load animation » dans la sortie.
- [ ] **Sons** : chaque son utilisé est au groupe ou est un son public de Roblox / du Creator Store autorisé ; un son
      privé d'un compte perso reste muet en PROD. Vérifier dans la sortie : aucune ligne « Failed to load sound ».
- [ ] **Images et maillages** (icônes `Contract/Icons`, décalques, MeshParts) : importés au nom du groupe ; aucune
      image grise en jeu.
- [ ] Creator Hub > PROD > **Permissions d'utilisation des assets** : si un asset du groupe est refusé, l'autoriser pour
      l'expérience PROD (pas seulement DEV).
- [ ] Aucun modèle du Creator Store avec ses scripts (CLAUDE.md) : couvert par le prod-check (scripts hors des
      dossiers de code).

### Étape 6 : test final sur la copie

- [ ] Play en Studio sur la copie : **aucune ligne rouge du ContractChecker**, aucune erreur dans la sortie.
- [ ] Mode « Serveur + 2 clients » : une boucle complète (entraînement, casse, colis, vigile, exposition, encaissement)
      et un vol entre joueurs (CLAUDE.md, tests PvP).
- [ ] Le tutoriel démarre pour un compte neuf (profil vide).

### Étape 7 : publier et ouvrir

- [ ] Fichier > **Publier sur Roblox sous…** > tuile « Steal a Shop » (groupe) > place de départ > **Écraser**
      (jamais « Publier » simple depuis DEV).
- [ ] Fermer la copie locale (pour ne pas la republier par erreur).
- [ ] Sur la place PROD encore privée : rejoindre en ligne avec 2 comptes, refaire la boucle, vérifier la sauvegarde
      (quitter, revenir).
- [ ] Remplir la page (section 1), téléverser icône et miniatures, remplir le questionnaire (section 2).
- [ ] Le 18 décembre : passer l'expérience en **Publique** (Creator Hub > Publier > Gérer l’audience).
- [ ] Noter la publication dans le journal des décisions (section 15 du doc partagé) et passer DEV-063 à « Fait ».

---

## 4. Ce que chacun doit fournir

### Clément (visuels)

| Livrable | Taille et format exigés par Roblox | Règles |
| --- | --- | --- |
| **Icône** | Carré, **512 × 512 px** au moins (modèle Roblox de 512 × 512), PNG ou JPG | Lisible à environ 150 × 150 px ; montre le vrai jeu (pas d'image trompeuse) ; une seule par langue |
| **Miniatures** | **1920 × 1080 px, 16:9** (autre ratio = étirée), PNG, JPG, GIF, TGA ou BMP, moins de 3 Mo ; **10 au plus** (vidéos comprises) | Vraie scène du jeu ; peu de texte, rien d'important en bas (nombre de joueurs) ; pas de prix ni de promesse ; textes de la section 1 |
| **Vidéo** (facultative) | Comptée dans les 10 ; 3 envois par mois (un refus compte) ; pas sur console ni casque VR | Vrai gameplay ; montage, angles et logo permis ; musique du catalogue Roblox sans paroles ; ni voix ni narration ; pas d'images réelles |
| Miniature « samedi » | Même format | Une version « NEW UPDATE! » par mise à jour |

Toutes ces images passent par la modération de Roblox avant d'être visibles : les envoyer au moins 2 ou 3 jours
avant le 18 décembre.

### Cantin (Ironix), lui-même

1. Creator Hub : vérification d'âge ou d'identité, double authentification, et (pour tous les âges) Roblox Plus ou
   Premium 2 mois ou les 1 000 Robux remboursables. Claude ne peut ni ne doit le faire à sa place.
2. Vérifier qui, de lui ou de Clément, doit remplir ces conditions pour un jeu de groupe (point 2.1).
3. Régler le rang « Dev » ou `Admin.UserIds` (étape 2).
4. Remplir la page, choisir le genre, téléverser icône et miniatures de Clément.
5. Remplir le questionnaire avec la section 2, relire l'aperçu de la note, l'envoyer.
6. Faire la liste de publication (section 3), publier, passer en public le 18 décembre.
7. Écrire la part des Robux du groupe reversée à chacun avant toute publication (Partie 1, question ouverte
   « Partage des revenus »).

---

## Sources (doc officielle Roblox, lue le 2026-11-14)

- Questionnaire et notes : https://create.roblox.com/docs/production/promotion/content-maturity
- Rendre un jeu public, conditions, frais, titre et description :
  https://create.roblox.com/docs/production/publishing/publish-experiences-and-places
- Miniatures et vidéos : https://create.roblox.com/docs/production/publishing/thumbnails
- Icône : https://create.roblox.com/docs/production/publishing/experience-icons
- Règles de conduite (métadonnées trompeuses = spam) :
  https://en.help.roblox.com/hc/en-us/articles/203313410-Roblox-Rules-of-Conduct

Aucune règle propre aux jeux « Steal a … » ni au thème du vol n'a été trouvée : le vol cartoon relève des règles
générales (violence cartoon, pas de techniques criminelles détaillées).
