# Publication PROD : page du jeu, questionnaire de maturité, liste pas à pas (DEV-063, 2026-11-14)

**Tâche** : DEV-063, « Page du jeu, questionnaire de maturité, publication PROD ». **Fini quand** : jeu public à la
sortie avec icône et miniatures. **Dépend de** : MOD-043. Propriétaire : Ironix (Cantin) ; Clément fait l'icône
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

## 2. Questionnaire de maturité (« Content Ratings Questionnaire »)

**Revu le 2026-11-24 d'après le code (main 52944638)**, avec le questionnaire de Roblox relu le même jour (page
« Content maturity and compliance », lien en fin de note). Ces réponses remplacent celles du 14/11. Les libellés des
questions sont ceux de Roblox, résumés en français.

**Qui et où** : Clément le remplit avant la sortie (demande de Cantin du 24/11), sur le jeu **PROD** « Steal a Shop »
(GameId 10774998269) : Creator Hub > le jeu > **Publish settings > Content ratings**. Le jeu DEV n'est pas concerné
tant qu'il reste privé.

Le questionnaire a quatre parties : type d'application, questions IARC, questions propres à Roblox, aperçu de la note.
Sans note, Roblox restreint le jeu. Une réponse inexacte peut valoir une modération, et Roblox ou l'IARC peuvent
remplacer ou retirer la note.

**Règle : répondre ce qui est vrai dans le jeu PROD publié. Ne jamais arranger une réponse pour baisser la note.**
Une note un cran plus haute coûte moins cher qu'une note fausse.

### Ce qui a changé depuis le 14/11

- Le banc et la Force sont retirés ; on frappe avec des armes (outils de `Config/Tools`) et des auras.
- Nouveau en jeu : la roue du hub (`Features.Wheel = true`), la Fortune Tower allumée (`Features.FortuneTower = true`),
  le fourgon blindé (`ArmoredVan`), les pièges (`Traps` ; banane et trappe en DEV seulement, `NewTraps = false`),
  l'agent de sécurité et le garde de porte (`Bodyguards`, `DoorGuard`), la cabine d'essayage où l'on démasque un
  déguisé à la batte (`FittingRoom`), la foule de témoins qui filme et crie (`WitnessCrowd`), le camion et le fourgon qui
  explosent sans faire de dégâts, l'intrus projeté à travers une vitre (`ShopGlassThrow = false`, DEV seulement).
- Monétisation : la boutique Robux est codée mais coupée en PROD (`RobuxShop = false`). La caisse exclusive est codée,
  allumée en DEV seulement. La chance du serveur est codée et coupée. Les tours de roue payants sont prévus sans produit.
  Tous les Id d'offres valent 0 (`Config/Monetization`, `Config/ProductIds`).
- Côté Roblox : la question des achats cite maintenant les **boosts de chance** (« chance-based boosts ») parmi les
  objets aléatoires payants. Le questionnaire se trouve dans « Publish settings > Content ratings ».

### Réponses proposées (V0)

| Partie | Question | Réponse proposée | Pourquoi (fichier, interrupteur) |
| --- | --- | --- | --- |
| Type | Type d'application | **Game** | Jeu à objectifs, ni réseau social ni appli de discussion |
| Début | Le jeu contient-il du contenu restreint (18 ans et plus) ? | **Non, puis remplir le questionnaire complet** | Rien de réservé aux adultes. S'arrêter au « Non » donne « Content May Vary » (16 ans et plus contrôlés) ; pour tous les âges (Roblox Kids et Select), il faut le questionnaire complet et une note Minimal, Mild ou Moderate |
| Violence | Y a-t-il de la violence ? | **Oui** | Coups de batte entre joueurs (`Config/Bat`, `BatService` : étourdi 2 s, poussé) ; vigiles, vigiles de nuit et police qui attrapent et arrêtent (animations `Catch`, `Arrest`, `Arrested`, `Knockdown` de `Contract/Animations`) ; pièges qui immobilisent (`Config/Traps`) ; agent de sécurité qui poursuit le voleur (`Bodyguards`) ; vitrines, portes, camion et fourgon cassés à coups d'outils (`Config/Tools`, `TruckEvent`, `ArmoredVan`) |
| Violence | Contre qui ? | **Humains et non-humains** | La batte et les pièges touchent des avatars ; vitrines, portes et véhicules sont des objets |
| Violence | Où (monde fantastique ou réaliste) ? | **Fantastique** | Ville cartoon en briques, 6 zones à thème ; aucune arme du monde réel (`Config/Tools` : poings, clé, pied-de-biche, marteau, masse, hache d'incendie, disqueuse ; aucune arme à feu) |
| Violence | Style | **Animé** | Style Roblox à studs, aucun rendu réaliste |
| Violence | Réactions des personnages | **Irréalistes** | Personne ne perd de PV : aucun service ne baisse la vie d'un Humanoid. Le joueur tombe, se relève, 3 s d'immunité (`Bat.HitImmunity`) ; pris par un vigile, il est étourdi et le vigile reprend l'objet |
| Violence | Fréquence et caméra | **« Often and far away » + « Rarely and close up »** | Consigne de Roblox pour la caméra par défaut à la 3e personne (relue le 24/11) |
| Violence | Comment le joueur le sait | **Violence directe** | Le coup de batte se voit |
| Sang et gore | Sang, mutilation ? | **Non** | Aucun sang ; seulement des éclats de verre (`Config/Shatter`) et des débris de véhicule (`Config/TruckEvent`) |
| Peur | Éléments effrayants ou horribles ? | **Non** (V0) | Poursuite, nuit avec vigiles de nuit, battements de cœur à moins de 10 studs du vigile (`Balance`, `HeartbeatDistance`), cris de la foule (`Config/Witness`, `Crowd_Scream`) : de la tension de poursuite, sans monstre, sans horreur, sans jumpscare. Si Clément trouve la nuit effrayante : « Scary », « Not often » |
| Sexualité, rencontres | Contenu sexuel, suggestif, rencontres ? | **Non** | |
| Jeux d'argent | Thème de jeu d'argent ? | **Non** | La roue donne un tour gratuit par jour, sans mise ni Robux ni argent du jeu, avec des lots du jeu (`Config/Wheel`, `Features.Wheel = true` ; tours payants : `ExtraSpin.ProductId = 0`). La Fortune Tower est une grande vitrine à casser à plusieurs (`Config/FortuneTower`) : « Fortune » est un nom, il n'y a ni mise ni casino. Les colis se prennent en braquant, ils ne s'achètent jamais. Aucune machine à sous, roulette, carte, dé ni pari |
| Langage | Grossièretés ? | **Non** | Textes du jeu en anglais neutre |
| Substances | Alcool, tabac, drogue ? | **Non** | Les potions (`Config/Potions` : Money, Strength, Invisibility) sont des fioles magiques. Clément vérifie qu'aucune icône ne ressemble à une bouteille d'alcool |
| Humour grossier | Fonctions du corps pour faire rire ? | **Non** | La peau de banane fait glisser, rien de plus (DEV seulement) |
| Achats | Le jeu vend-il des produits développeur, des passes ou des récompenses aléatoires ? | **Oui** | Gamepasses et produits codés (`Config/Monetization`), boutique Robux prévue ; création des offres sur le Creator Hub après les réponses de Clément à L-351 (voir les points incertains) |
| Achats | Objets aléatoires payants (caisses, clés, boosts de chance…) ? | **Non** | Aucune offre aléatoire ne se vend en PROD : les quatre trouvées sont coupées (tableau suivant). Rien d'aléatoire ne s'achète non plus avec l'argent du jeu (armes, auras, améliorations, arbre de compétences : prix fixes ; les colis ne se vendent jamais) |
| Divers | Les joueurs communiquent-ils (voix, texte, images, sons) ? | **Oui** | Chat de Roblox par défaut : le code ne le coupe pas (aucun réglage de `TextChatService` dans `src/`) |
| Divers | Bloquer des joueurs ? Signaler des joueurs ? | **Oui / Oui** | Fournis par Roblox |
| Divers | Modération du chat ? | **Oui** | Filtre de Roblox. Le jeu ne montre aucun texte écrit par un joueur aux autres, à part les noms (les codes saisis dans `CodeController` partent au serveur seul) |
| Divers | Échanges limités aux amis invités ? | **Non** | Pas de serveurs privés : aucun code n'en parle (ni `PrivateServerId` ni `PrivateServerOwnerId` dans `src/`), et leur ouverture attend la question 6 de L-351. Cantin vérifie qu'ils sont désactivés sur le Creator Hub |
| Divers | Position physique précise partagée ? | **Non** | Roblox ne la donne jamais au jeu |
| Divers | Symboles nazis, atteinte à l'identité coréenne, terrorisme ? | **Non / Non / Non** | |
| Divers | Descriptions réalistes de crimes, **techniques détaillées utilisables pour un délit** ? | **Non** | Le vol est cartoon : casser une vitrine, ouvrir un colis, courir, se déguiser à la cabine. Aucune vraie méthode de vol ou d'effraction n'est montrée ni expliquée |
| Roblox | Lieu social (hangout) ? Espaces privés ? | **Non / Non** | Jeu à objectifs ; les boutiques sont des parcelles de jeu que tout le monde peut braquer |
| Roblox | Création libre visible des autres (dessin, texte, pixel art) ? | **Non** | Les objets se rangent sur des présentoirs prévus ; aucun texte libre |
| Roblox | Thème sensible (politique, religion…) ? | **Non** | |
| Roblox | Contenu capturé dans d'autres jeux Roblox ? | **Non** | Aucun `TeleportService` ni capture dans `src/` |
| Roblox | Interaction avec une IA générative ? | **Non** | Le bot et les PNJ suivent des scripts (`BotService`, `WitnessService`) ; `NotificationService` appelle l'API de notifications de Roblox, pas une IA |
| Roblox | Partage de médias pris en jeu ? | **Non** | Aucun `CaptureService` ; les « photos » des témoins sont des animations de PNJ |
| Roblox | Fil de contenu continu, audio ou vidéo en lecture automatique ? | **Non** | Pas de fil de médias ; la musique d'ambiance du jeu n'en est pas un |

### Offres aléatoires payantes trouvées dans le code (24/11)

Toutes sont coupées en PROD. Les autres offres ne sont pas aléatoires : gamepasses, packs d'argent (montant fixe), pack
de départ (contenu fixe), Ouvrir maintenant (retire l'attente de l'antivol), zZz, Vengeance, Rideau, Bouclier.

| Offre | Ce qu'elle donne | Interrupteur | En PROD aujourd'hui |
| --- | --- | --- | --- |
| Caisse exclusive (`Monetization.Crate`, lots de 1, 3 et 10 à 99, 249 et 799 R$) | Un objet `Exclusive_*` tiré au hasard (30, 30, 25, 10, 4 et 1 %) | `Features.RobuxCrate = false` ; `Features.RobuxCrateDev = true` l'allume dans le jeu DEV seulement (`Crate.Live`) ; Id à 0 | Cachée, pas en vente |
| Chance du serveur ×2, ×4, ×8 (`ServerLuck2`, `4`, `8` : 149, 399 et 999 R$) | Boost de chance des colis pour tout le serveur pendant 15 min | Constante `SERVER_LUCK = false` en tête de `Config/Monetization` (**pas dans `Features`**), puis `Features.RobuxShop = false` ; Id à 0 | Cachée, pas en vente |
| Chance ×3 (`Luck3`, 79 R$) | Colis plus rares pendant 15 min | `Ready = false` (effet pas codé), `Features.RobuxShop = false` ; Id à 0 | Pas codée |
| Tours de roue en plus (`Config/Wheel.ExtraSpin`, 25 R$) | Un tour de roue de plus, lot tiré au hasard (chances affichées en %) | `ExtraSpin.ProductId = 0` ; pas branché à `MonetizationService` (`WheelService.AddSpins` est prêt) ; **pas sous `RobuxShop`** | Bouton « Soon », pas en vente |

### Note attendue

**Légère (Mild)**, avec le descripteur « violence légère » : violence cartoon, répétée, réactions irréalistes, sans sang.
Minimal et Mild ouvrent Roblox Kids (5 à 8 ans) et Roblox Select (9 à 15 ans), sous réserve de leur évaluation. Si
l'aperçu affiche **Modérée (Moderate)**, souvent à cause de « Humains » et « Violence directe », le jeu reste ouvert à
Roblox Select (9 à 15 ans) et aux 16 ans et plus.

**Ne jamais arranger une réponse pour baisser la note.** Si l'aperçu affiche Moderate, on l'accepte.

### À refaire quand…

Roblox demande de remettre à jour le questionnaire après toute mise à jour qui change une réponse.

1. **La boutique Robux s'allume** (`Features.RobuxShop = true` avec au moins un Id ≠ 0) : « Achats » reste « Oui » ;
   relire la question des objets aléatoires payants.
2. **Un objet aléatoire payant s'allume** : `Features.RobuxCrate = true`, `SERVER_LUCK = true`, `Luck3` prêt, ou
   `Wheel.ExtraSpin.ProductId ≠ 0`. La réponse devient « Oui ». Avant d'allumer, la règle de Roblox (Randomized
   Virtual Items Policy) demande : les chances en % avant l'achat, total 100 ; pour un boost de chance, son effet en
   chiffres et les chances affichées mises à jour pendant le boost ; l'offre cachée là où `PolicyService` dit
   `ArePaidRandomItemsRestricted`.
3. **Les tours de roue deviennent payants** : relire aussi « Jeux d'argent ».
4. **Les serveurs privés s'ouvrent** (L-351, question 6) : « Échanges limités aux amis invités » devient « Oui ».
5. **L'intrus projeté à travers une vitre s'allume en PROD** (`ShopGlassThrow = true`) : relire « Réactions » et
   « Fréquence » (V0 : rien ne change, il se relève).
6. **Contenu vraiment effrayant** (monstre, événement d'horreur, Halloween) : « Peur » change.
7. **Texte ou image d'un joueur montré aux autres** (nom de boutique, pancarte) : « Création libre » et « Partage de
   médias » changent.
8. **Arme à feu, sang ou alcool** ajoutés : les rubriques correspondantes changent.
9. À chaque mise à jour du samedi, relire ce tableau.

### Points à vérifier avant d'envoyer

1. **Vérification du compte** : pour tous les âges, il faut un compte vérifié, la double authentification, et soit
   2 mois de Roblox Plus ou Premium, soit les frais remboursables de 1 000 Robux, puis l'évaluation Kids et Select.
   La doc ne dit toujours pas si c'est le compte qui publie (Cantin) ou le propriétaire du groupe (Clément) qui doit
   remplir ces conditions : le tester sur la place PROD bien avant la sortie.
2. **Vigiles et police** : le code le confirme, ils attrapent sans enlever de vie (aucune perte de PV).
3. **Potions** : leurs icônes et modèles ne doivent rien évoquer d'alcool (Clément).
4. **Serveurs privés** désactivés sur le Creator Hub (Cantin).
5. **Chat** pas coupé dans les réglages de la place (sinon « communication » change).
6. **Roue** : son écran `UI_Wheel` et ses icônes (dont `WHEEL_Jackpot`) ne doivent pas faire casino (jetons, machine à
   sous). Sinon, « Jeux d'argent » devient « Oui, non jouable », ce qui limite le jeu aux 13 ans et plus.

---

## 3. Liste de publication PROD, pas à pas

À faire par Cantin, de préférence une première fois à blanc à la fin de la bêta (place PROD restée privée), puis le
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
- [ ] Le jour de la sortie : passer l'expérience en **Publique** (Creator Hub > Publier > Gérer l’audience).
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
avant la sortie.

### Cantin (Ironix), lui-même

1. Creator Hub : vérification d'âge ou d'identité, double authentification, et (pour tous les âges) Roblox Plus ou
   Premium 2 mois ou les 1 000 Robux remboursables. Claude ne peut ni ne doit le faire à sa place.
2. Vérifier qui, de lui ou de Clément, doit remplir ces conditions pour un jeu de groupe (point 2.1).
3. Régler le rang « Dev » ou `Admin.UserIds` (étape 2).
4. Remplir la page, choisir le genre, téléverser icône et miniatures de Clément.
5. Remplir le questionnaire avec la section 2, relire l'aperçu de la note, l'envoyer.
6. Faire la liste de publication (section 3), publier, passer en public le jour de la sortie.
7. Écrire la part des Robux du groupe reversée à chacun avant toute publication (Partie 1, question ouverte
   « Partage des revenus »).

---

## Sources (doc officielle Roblox, lue le 2026-11-14)

- Questionnaire et notes (relue le 2026-11-24 pour la section 2) :
  https://create.roblox.com/docs/production/promotion/content-maturity
- Objets aléatoires payants (relue le 2026-11-24) :
  https://create.roblox.com/docs/production/monetization/randomized-virtual-items-policy
- Rendre un jeu public, conditions, frais, titre et description :
  https://create.roblox.com/docs/production/publishing/publish-experiences-and-places
- Miniatures et vidéos : https://create.roblox.com/docs/production/publishing/thumbnails
- Icône : https://create.roblox.com/docs/production/publishing/experience-icons
- Règles de conduite (métadonnées trompeuses = spam) :
  https://en.help.roblox.com/hc/en-us/articles/203313410-Roblox-Rules-of-Conduct

Aucune règle propre aux jeux « Steal a … » ni au thème du vol n'a été trouvée : le vol cartoon relève des règles
générales (violence cartoon, pas de techniques criminelles détaillées).

## Résultat du prod-check en lecture seule (Claude, 2026-11-14, place DEV en Team Create, `RETIRER = false`)

- Dossiers de développement à retirer avant la PROD : `Workspace._SHOWROOM_CLEMENT` (30 096 objets), `Workspace._INBOX_CLEMENT` (vide), `ServerStorage._GREYBOX_REMPLACE` (856 objets).
- Packs piégés de L-143 : aucun (déjà retirés). Scripts suspects (`Runtime`, `ScreenBuilder`, `require` d'un numéro, `loadstring`, `getfenv`, `HttpService`) : aucun.
- `HttpService.HttpEnabled = false` : bien. Aucun attribut de test sur le Workspace.
- 5 scripts hors des dossiers de code, à regarder avant la PROD :
  - `Workspace._PROTO_AURA_ECLAIR.Mannequin.Animate` (LocalScript) : prototype d'aura de Clément, posé à la racine du Workspace et pas dans un dossier de développement, il partirait en PROD ; à ranger dans `_SHOWROOM_CLEMENT` ou à ajouter à la liste du prod-check ;
  - `ReplicatedStorage.GuiAnimatorPlugin` (3 ModuleScripts sains, restes d'un plugin, déjà cités en L-143) : à retirer s'ils ne servent pas ;
  - `TestService.LuauLSP_Settings` (ModuleScript, réglages de l'extension Luau LSP) : à retirer de la copie PROD.
