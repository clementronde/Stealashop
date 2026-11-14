# Bêta fermée : ouverture, testeurs, programme, mesures, go / no-go (DEV-062, 2026-11-14)

**Tâche** : DEV-062, « Bêta fermée : 20 à 30 testeurs, réglage de `Config` ». **Fini quand** : plus aucun bug P0
ouvert. **Dépend de** : M1 à M4. Jalon M5 (Partie 1, section 11, point 8 : 20 à 30 testeurs, zéro P0, `Config`
ajustée). Propriétaire : Ironix (Cantin). Clément : rôles du groupe (il en est propriétaire) et retours visuels.

Dates proposées : **bêta du lundi 30 novembre au dimanche 6 décembre**, bilan le lundi 7, ce qui tombe avec le
go / no-go du 6 décembre (zones 5 et 6). Lancement le vendredi 18 décembre, date fixe.

Règles Roblox relues le 2026-11-14 (sources en fin de note). Rien n'est fait sur le Creator Hub : cette note
prépare, Cantin et Clément cliquent. Tout ce qui est marqué **V0 proposé** est à valider.

---

## 1. Ouvrir la bêta sur Roblox

### Ce que Roblox propose aujourd'hui

| Moyen | Combien | Pour nous |
| --- | --- | --- |
| **Early testers** (Studio, Fichier > Invite early testers) | 10 au plus, amis Roblox seulement | Trop peu pour 20 à 30 testeurs |
| **Expérience privée + rôle du groupe avec la permission « Playtest »** | Pas de limite écrite | **Retenu** : le testeur rejoint le groupe RoundStone Studio, on lui donne le rôle, il joue sans que le jeu soit public |
| **Beta mode** (expérience publique, hors recommandations, déc. 2025) | Tout le monde avec le lien ou la recherche | Pas une bêta fermée : n'importe qui peut entrer, et il faut le questionnaire de maturité. À garder pour une éventuelle bêta ouverte après le 7 décembre |
| Serveurs privés | — | Inutiles ici : ils servent aux joueurs, pas à limiter l'accès |

### Quelle place : une 3e expérience « Steal a Shop [BETA] » (V0 proposé)

Trois choix possibles :

1. **DEV** (« Steal a Shop [DEV] ») : non. Clément y travaille en Team Create, ses profils de test (`PlayerData` de
   DEV) sont mélangés aux testeurs, et `Admin.StudioEveryone` ou les attributs de test traînent dans la place.
2. **PROD** (« Steal a Shop ») restée privée : répète la vraie publication, mais les profils des testeurs restent
   dans le `PlayerData` de PROD au lancement (un testeur qui a joué 10 h partirait devant tout le monde). Il faudrait
   effacer ces profils avant le 18, à la main, sans droit à l'erreur.
3. **Recommandé : une expérience BETA dans le groupe**. Les DataStores appartiennent à l'expérience (note
   publication-prod, étape 3) : BETA a donc son propre `PlayerData`, PROD reste vierge, **aucun changement dans
   `src/`**. On y publie avec la même chaîne que pour PROD (copie locale, `tools/prod-check.luau`, « Publier sur
   Roblox sous… »), ce qui fait la répétition à blanc prévue vers le 7 décembre.

### Pas à pas

**Clément (propriétaire du groupe)**, avant le jeudi 26 novembre :

- [ ] Creator Hub > sélecteur de compte > RoundStone Studio > **Roles** > créer le rôle **« Beta Tester »**, de rang
      **bas (par ex. 10), bien sous 254** : `Config/Admin` rend admin tout membre de rang 254 ou plus
      (`MinGroupRank = 254`, `GroupId = 0` = groupe propriétaire).
- [ ] Permissions du rôle : rien d'autre que **Playtest**, et seulement sur l'expérience BETA si le réglage par
      expérience est proposé (Roblox le permet, chemin à vérifier dans « Configure experiences » ; à défaut, la
      permission de groupe « Playtest all group experiences » ouvre aussi DEV et PROD privées : à éviter si on peut).
      Jamais de droit d'édition, de publication ni d'accès aux revenus. Rôle **privé** (invisible sur la page du groupe).
- [ ] Donner à Cantin le droit d'attribuer ce rôle (« Assign or remove roles », demande la double authentification
      chez Cantin), ou l'attribuer lui-même au fil des arrivées.

**Cantin (Ironix)** :

- [ ] Créer l'expérience BETA **au nom du groupe** (Creator Hub > Créations > Groupe RoundStone Studio > Créer, ou
      Studio : Fichier > Publier sur Roblox sous… > groupe > « Créer une nouvelle expérience »), nom « Steal a Shop
      [BETA] », 8 joueurs par serveur, **privée**.
- [ ] Manage Audience > Manage access : onglet Playtest, **Playtesters activé** ; rien dans l'onglet Public.
- [ ] Paramètres > Sécurité : accès Studio aux services d'API **coupé** (sinon un Play en Studio écrit dans les
      profils des testeurs).
- [ ] `src/shared/Config/Features.luau` comme au lancement (note publication-prod, étape 2) :
      `FortuneTower = false` tant que Clément ne l'a pas validée, `RobuxShop = false`, le reste à `true`.
      `Telemetry.Enabled = true` (déjà le cas).
- [ ] Copie locale, `tools/prod-check.luau` (`RETIRER = true` puis rapport propre), publication sur la tuile BETA.
      Mêmes étapes 4 à 6 que publication-prod. Chaque correctif de la semaine repasse par cette chaîne.
- [ ] Jeudi 26 novembre : playtest à deux sur BETA (Cantin et Clément), avec deux comptes : rejoindre en ligne,
      boucle complète, quitter, revenir, la sauvegarde tient.
- [ ] Copier le lien de l'expérience BETA pour les testeurs (il ne s'ouvre que pour les membres qui ont le rôle).

**Le testeur** : demande à rejoindre le groupe RoundStone Studio (lien), on accepte et on lui donne « Beta Tester »,
puis il ouvre le lien du jeu.

**Après la bêta** (lundi 7 décembre) : retirer le rôle à tous (ou couper sa permission), passer BETA en privée sans
testeurs. Garder l'expérience : elle resservira aux tests des mises à jour du samedi.

---

## 2. Qui inviter

**25 testeurs visés** (20 au moins, 30 au plus), pour remplir trois serveurs de 8 aux sessions à heure fixe.

| Profil | Combien | Pourquoi |
| --- | --- | --- |
| Joueurs de « Steal a … » et de simulateurs, 10 à 16 ans | 10 à 12 | Notre public : ils jugent le rythme, le vol entre joueurs, ce qui donne envie de revenir |
| Joueurs sur **téléphone** (Android d'entrée de gamme compris, au moins 2 iPhone) | 8 au moins, parmi tous | DEV-061 (30 FPS pendant une casse), T-031 à T-035, T-038, T-048, T-049 |
| Joueurs PC | 8 au moins | Comparaison, et les sessions dirigées (duplication, nuit) sont plus faciles à mener au clavier |
| Quelques « acharnés » prêts à jouer 1 h par jour ou plus | 4 à 5 | Les seuls qui iront vers les zones 4 à 6 en une semaine |
| Proches du studio qui savent décrire un bug (âge indifférent) | 3 à 4 | Rapports précis, présents aux sessions dirigées |

**Recrutement** (du 16 au 27 novembre) :

1. Cercle proche : amis, frères et sœurs, cousins de Cantin et de Clément, et leurs amis. C'est la source la plus
   sûre pour les plus jeunes (un adulte connu est dans la boucle).
2. Le serveur Discord du jeu, s'il est ouvert d'ici là (Discord exige 13 ans) : un salon `#beta` avec la règle et
   le formulaire.
3. Un message dans des communautés Roblox de genre « Steal a … » (serveurs Discord, groupes), seulement là où
   l'autopromotion est permise. Pas de pub payante pour une bêta fermée.

**Règles de prudence** (les testeurs seront en partie mineurs) :

- On ne demande **que le pseudo Roblox**. Ni nom, ni âge exact, ni téléphone, ni adresse, ni photo. Le formulaire
  ne demande même pas le pseudo s'il n'est pas utile (question facultative).
- Aucun échange en message privé avec un mineur : tout passe par le salon public de la bêta ou par un parent.
- Pour les moins de 13 ans, passer par un parent ou un grand frère ou une grande sœur connus.
- Pas de récompense en Robux ni en argent. Proposé : un badge ou un titre « Beta Tester » dans le jeu au lancement
  (à coder plus tard, MAJ 1 ; décision à noter en section 15).

**Message d'invitation (anglais, avec traduction)** :

> Steal a Shop closed beta, Nov 30 to Dec 6. Break into shops, steal the loot, run from the guard, show it off in your
> own store, and rob your friends. Join the RoundStone Studio group, we give you the Beta Tester role, then play
> whenever you want. Group sessions every evening at 6 pm (French time). Your progress will be reset at launch.

> Bêta fermée de Steal a Shop, du 30 nov. au 6 déc. Casse des magasins, vole le butin, sème le vigile, expose-le dans
> ta propre boutique et braque tes amis. Rejoins le groupe RoundStone Studio, on te donne le rôle Beta Tester, puis
> joue quand tu veux. Sessions à plusieurs chaque soir à 18 h (heure française). Ta progression sera remise à zéro au
> lancement.

---

## 3. Programme sur 7 jours

Chaque jour : **jeu libre** toute la journée (c'est ce qui donne la rétention et les temps par zone), plus **une
session dirigée à 18 h** (V0 proposé, après l'école), 45 min, Cantin présent, au moins 8 joueurs dans le même
serveur (ils rejoignent Cantin depuis son profil). Les tests T- qui demandent deux vrais joueurs se font là. Un test
passé sort de la liste « Tests à faire » de la liaison (règle de la liaison) ; un test raté reçoit « Raté le … ».

**Avant de commencer chaque jour** : lire les bugs de la veille, corriger les P0, republier BETA le matin
(chaîne de la section 1), redémarrer les serveurs.

| Jour | Thème du jour (jeu libre) | Session dirigée de 18 h | Tests de la liaison |
| --- | --- | --- | --- |
| **Lun 30/11** | **Premier quart d'heure et tuto** : chaque testeur arrive avec un profil neuf (c'est le cas sur BETA). Ne rien leur expliquer : on regarde où ils bloquent | Le bot du tuto dans le serveur : 3 testeurs font le tuto en même temps, Cantin regarde | T-016, T-017, T-018 (serveur sans bot), T-019, T-043, T-044, T-045, T-013 |
| **Mar 1/12** | **Progression zones 1 à 3** : tapis, banc, outils, auras. Critère M2 : un testeur atteint la zone 3 en moins d'1 h | Course : qui arrive en zone 3 le premier (chrono noté) ; ressenti du vigile et de la vitesse portée | T-004, T-010, T-023, T-036, T-037, T-015 (gains hors ligne au retour du lendemain) |
| **Mer 2/12** | **Vol entre joueurs** : se voler, se défendre à la batte, alerte, Adrénaline, caméras, coffre | Serveur plein (8 boutiques occupées) : vols croisés pendant 30 min. Cantin prévient Claude avant : **mesure T-050** (`PvPController`) | T-003, T-012, T-021, T-024 à T-029, **T-050** |
| **Jeu 3/12** | Jeu libre | **Duplication, critère M3** : 20 essais de vol entre joueurs et 20 essais de colis PNJ à la batte (protocole plus bas), à 3 clients au moins | Critère M3, DEV-048 (20 essais), T-025 |
| **Ven 4/12** | **Nuit et camion** : jouer pendant les phases de nuit, vigiles de nuit, mur du couloir, camion | Attendre une nuit tous ensemble dans le couloir ; casser le camion à plusieurs | T-030, T-049 (compte à rebours de nuit) ; T-046 seulement si la Fortune Tower est allumée |
| **Sam 5/12** | **Téléphone** : tous les testeurs sur téléphone jouent au moins 30 min ; ceux qui ont PC et téléphone comparent | Session sur téléphone : casse à plusieurs devant le même magasin, poursuite, boutique pleine. Chacun note s'il y a des saccades | T-031 à T-035, T-038, T-048, T-049 ; DEV-061 (30 FPS pendant une casse) |
| **Dim 6/12** | **Zones 3 à 6** : les acharnés poussent le plus loin possible. Contenu des zones 5 et 6 vu par 2 testeurs (profil monté par le panel admin si personne n'y est arrivé : on teste le contenu, pas le temps) | Bilan à chaud : formulaire rempli en direct, questions ouvertes à l'oral | Go / no-go des zones 5 et 6 (Partie 1, section 11, point 4) |

**Protocole de duplication (critère M3, jeudi)** — un essai = une situation, notée par Cantin dans un tableau :

1. Avant l'essai, chaque joueur concerné ouvre son inventaire et compte objets et présentoirs (capture d'écran).
2. On joue la situation, puis on recompte chez les deux, puis **chacun quitte et revient** (sauvegarde relue).
3. Réussi si chaque objet existe une seule fois, chez une seule personne, avant et après la reconnexion.

Situations, 20 essais au total (environ 3 de chaque) : vol réussi jusqu'au dépôt ; voleur frappé à la batte
(l'objet revient) ; voleur qui quitte le jeu en portant ; victime qui quitte pendant le vol ; voleur tué ou attrapé
la nuit ; deux voleurs sur le même présentoir au même instant ; voleur qui rejoint aussitôt un autre serveur
(verrou de session de ProfileStore). Même chose pour les **colis PNJ à la batte** (DEV-048) : colis tombé ramassé
par un autre, retour au rayon à 15 s, deux joueurs qui le ramassent en même temps. Une seule duplication = P0.

---

## 4. Ce qu'on mesure

### Télémétrie déjà en place (Creator Dashboard > Analytics de l'expérience BETA)

`TelemetryService` et `TutorialService` envoient déjà tout cela ; rien n'est envoyé depuis Studio, il faut de vrais
joueurs en ligne.

| Mesure | Où | Cible (Partie 1, section 14.1) |
| --- | --- | --- |
| **Funnel du tuto** : 14 étapes de `Config/Tutorial.FunnelSteps` (parcelle, premier coup, vitrine cassée, colis volé, zone safe, colis posé, objet révélé, objet exposé, encaissement, outil acheté, puis le bot) | Analytics > Funnels | 80 % au moins déballent un objet ; moins d'un joueur sur cinq lâche avant son premier déballage |
| **Rétention J1** (et J7, trop tôt pour une bêta d'une semaine) | Analytics > Retention | J1 ≥ 25 % |
| **Durée moyenne de session**, sessions par joueur | Analytics > Engagement | ≥ 12 min |
| **Économie** : revenus (`Income`, `Offline`), achats (`Tool`, `Upgrade` avec niveau, `Aura`, `Trail`) | Analytics > Economy | Chaque achat du kit d'une zone coûte 3 à 7 min de revenus au moment de l'achat (7.2) |
| **Événements** : `PvPTheftSuccess`, `PvPTheftFail` (avec `Reason`), `BatBoxKnockdown`, `GuardCatch` (par `Zone` et `Phase`), `PotionPicked`, `RewardClaimed` | Analytics > Custom events | Captures par zone : repérer une zone où le vigile prend presque tout le monde |

Avec 25 testeurs, les courbes sont maigres : Roblox peut masquer ou retarder certains graphiques sur un petit
nombre de joueurs (de quelques heures à 2 jours de délai). Lire les chiffres comme des indices, pas comme des
preuves, et les croiser avec le formulaire.

### Ce qui manque : le temps par zone

**Aucun envoi ne dit aujourd'hui quand un joueur entre dans une zone, ni après combien de temps de jeu** (le profil
ne garde pas de temps de jeu total). Or c'est la mesure qui valide le rééquilibrage v2 : joueur moyen en zone 2 en
7 min, zone 3 en 23 min, zone 4 en 1 h 04, zone 5 en 2 h 37, zone 6 en **7 h 26 à 7 h 31** (passe 3, cible 7 h 30
sans les aides, `equilibrage-v2-proposition.md`).

**Proposé à Cantin, à coder avant le 30/11 (petit, V0 proposé)** : un temps de jeu actif cumulé dans le profil, et
un événement custom `ZoneReached` envoyé une fois par zone et par joueur au **premier colis rapporté de la zone**
(la même définition que le simulateur), champs `Zone - n` et `Minutes - <tranche>` (tranches de 5 min jusqu'à 1 h,
puis de 15 min, pour rester sous les 8 000 combinaisons de valeurs). Sans lui, solution de secours : les testeurs
notent l'heure à laquelle ils rapportent leur premier colis de chaque zone (peu fiable, à croiser avec la session
dirigée de mardi).

**Lecture** : un écart de plus de 25 % sur les zones 2 à 4, dans le même sens chez la plupart des testeurs, fait
tourner le bouton prévu : prix du tapis (`Upgrades.Treadmill`, ×3,8 par niveau ; ×3,75 donne environ 10 min de
moins sur la zone 6, ×3,7 environ 25 min). Les zones 5 et 6 ne seront pas atteintes en une semaine par un joueur
moyen : on ne les juge pas sur le temps, seulement sur le contenu.

### Formulaire de retours (7 questions, en anglais pour les testeurs)

Google Forms (V0 proposé), **sans connexion requise et sans collecte d'adresse e-mail**, lien dans le salon de la
bêta. Rempli le dimanche 6 (et une fois en cours de semaine pour ceux qui veulent).

| # | Question (anglais, à coller) | Traduction | Type |
| --- | --- | --- | --- |
| 1 | What did you play on? (Phone / Tablet / PC / Console) | Sur quoi as-tu joué ? (Téléphone / Tablette / PC / Console) | Cases à cocher |
| 2 | In your first 10 minutes, was there a moment where you did not know what to do? Where? | Pendant tes 10 premières minutes, y a-t-il eu un moment où tu ne savais pas quoi faire ? Où ? | Oui / Non + texte |
| 3 | What is the highest zone you reached? (1 to 6) | Quelle est la zone la plus haute que tu as atteinte ? (1 à 6) | Liste |
| 4 | How did progress feel? (Too slow / A bit slow / Just right / A bit fast / Too fast) | Comment as-tu trouvé la progression ? (Trop lente / Un peu lente / Juste bien / Un peu rapide / Trop rapide) | Échelle |
| 5 | Stealing from other players and getting robbed: fun or frustrating? Why? | Voler les autres joueurs et te faire voler : amusant ou frustrant ? Pourquoi ? | Échelle 1 à 5 + texte |
| 6 | Did you see a bug, lag, or lose an item or money? Describe what happened and when. | As-tu vu un bug, du lag, ou perdu un objet ou de l'argent ? Décris ce qui s'est passé et quand. | Texte |
| 7 | Would you keep playing after launch? What would make you come back every day? | Continuerais-tu à jouer après le lancement ? Qu'est-ce qui te ferait revenir chaque jour ? | Oui / Peut-être / Non + texte |
| 8 (facultative) | Your Roblox username, only if you want us to contact you about a bug | Ton pseudo Roblox, seulement si tu veux qu'on te recontacte pour un bug | Texte court, facultatif |

**Rapports de bug pendant la semaine** : un salon `#beta-bugs` (ou un second formulaire) avec trois champs :
ce que j'ai fait, ce que j'ai vu, l'heure. Cantin les classe chaque soir (P0, P1, plus tard) dans la liaison, une
ligne L- quand Clément doit agir.

---

## 5. Lancer ou repousser

La **date du 18 décembre ne bouge pas** (Partie 1, section 11, point 4). « Repousser » veut donc dire couper une
fonction ou une zone pour la MAJ 1 du 26 décembre ; seul un P0 non corrigé sur les données justifierait de
repousser la date elle-même, décision à prendre à deux et à noter en section 15.

**Bug P0** (V0 proposé, absent du doc) : crash ou blocage du serveur, perte ou duplication d'objet ou d'argent,
sauvegarde perdue ou abîmée, exploit qui donne de l'argent ou des objets, tuto qui bloque un nouveau joueur, jeu
injouable sur téléphone (bouton inaccessible, chute de FPS qui empêche de jouer).

| Critère | Lancer tel quel | Couper ou corriger avant le 18 |
| --- | --- | --- |
| Bugs P0 | **Zéro ouvert** le 11 décembre (gel des fonctionnalités) | Un P0 ouvert le 11 : la fonction en cause passe à `false` dans `Features` si elle en a un (camion, nuit, aperçus), sinon correction prioritaire et nouveau test à deux |
| Duplication | **Zéro sur 20 essais** de vol entre joueurs et zéro sur 20 essais de colis à la batte (M3, DEV-048) | Une seule duplication : P0. Correction, puis les 20 essais refaits en entier |
| Perf téléphone | **30 FPS au moins pendant une casse** sur le téléphone de test (DEV-061), aucun plantage chez les testeurs téléphone, T-048 et T-049 bons | Sous 30 FPS : passe téléphone (corrections restantes de `perf-telephone.md`, auras et halos allégés) ; si T-050 ne gagne rien, retirer la correction de `PvPController` |
| Temps par zone | Zones 2 à 4 à ±25 % de 7 / 23 / 64 min pour le joueur médian ; personne en zone 3 après plus d'1 h 30 sans avoir décroché | Écart plus grand : régler `Config` (prix du tapis d'abord), une seule valeur à la fois, republier BETA et remesurer avant le 11 |
| Tuto et funnel | 80 % déballent un objet ; moins de 20 % lâchent avant le premier déballage | Corriger l'onboarding avant tout le reste (Partie 1, section 14) |
| Zones 5 et 6 | Magasins prêts et vus par 2 testeurs le 6 décembre | Pas prêts : lancement avec les zones 1 à 4, zones 5 et 6 dans la MAJ 1 (go / no-go du 6 décembre) |
| Rétention J1, sessions | J1 ≥ 25 %, sessions ≥ 12 min (indicatif, échantillon trop petit pour bloquer) | Très en dessous : lire le formulaire (questions 4, 5, 7) pour trouver pourquoi, sans bloquer le lancement |

---

## Ce que Cantin doit faire, et quand

| Quand | Quoi |
| --- | --- |
| Cette semaine (avant le 20/11) | Valider les choix V0 de cette note (expérience BETA, sessions à 18 h, définition des P0, `ZoneReached`) ; demander à Clément le rôle « Beta Tester » (liaison) ; noter la décision en section 15 |
| Du 16 au 27/11 | Recruter 25 testeurs (section 2), ouvrir le salon de la bêta, préparer le Google Form |
| Avant le 26/11 | Créer l'expérience BETA au nom du groupe, coder `ZoneReached` et le temps de jeu cumulé, publier BETA |
| Jeudi 26/11 | Playtest à deux sur BETA (sauvegarde, boucle complète) |
| Du 30/11 au 6/12 | Programme de la section 3 ; corrections du matin ; prévenir Claude avant la session du mercredi (T-050) |
| Lundi 7/12 | Bilan : formulaire, Analytics, tableau de duplication, décisions de `Config` et go / no-go, notés dans le doc partagé |

## Sources (lues le 2026-11-14)

- Roblox, Publish experiences and places (Manage Audience, Playtest, early testers limités à 10) :
  https://create.roblox.com/docs/production/publishing/publish-experiences-and-places
- Roblox, Groups (rôles, permission Playtest, réglage par expérience, double authentification) :
  https://create.roblox.com/docs/projects/groups
- DevForum, « A new way to test before launch: Experience Betas » (11 décembre 2025 : beta mode, testeurs privés par
  rôle de groupe) : https://devforum.roblox.com/t/a-new-way-to-test-before-launch-experience-betas/4144485
