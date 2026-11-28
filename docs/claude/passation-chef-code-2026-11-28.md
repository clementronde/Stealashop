# Passation au chef code (28/11/2026, soir)

Écrite par l'ancien grand chef pour le chef code unique. Trois parties bien séparées : ce que Cantin a **validé**, ce que l'**IA externe** a recommandé, et ce qui reste **à arbitrer**.

- Note détaillée de l'audit, à consulter à la demande (pas à lire au démarrage) : `C:\Users\user\.claude\projects\F--StealAShop\memory\reference-audit-externe-2026-11-28.md`
- État technique complet (main, branches, worktrees) : `C:\Users\user\.claude\projects\F--StealAShop\memory\grand-chef-etat.md`
- Règles de travail du chef code : `C:\Users\user\.claude\projects\F--StealAShop\memory\fonctionnement-chef-code.md`

## 0. Où reprendre (à lire en premier ; tenu à jour par le chef code en place)

**Contrôle à chaque remplacement** : le chef entrant vérifie lui-même, avant toute action, qu'il retrouve dans ce fichier le point de reprise, l'ordre de travail, la preuve qui termine la tâche en cours, les règles en vigueur et les décisions qui restent à Cantin. S'il manque quelque chose, il le signale tout de suite à Cantin et le complète. Cantin n'a pas à demander ce contrôle.

**État au 28/11, 19 h 40** (premier chef code unique, session ouverte le 28/11 au soir) :
- Cantin a **confirmé l'ordre de la phase 1** : (1) ses réponses pour Clément dans la liaison (L-524, L-531, L-534, L-537, L-441, L-538 et la proposition Issues GitHub L-541), poussées avec ce fichier ; (2) **un seul agent** sur la 1re livraison des bancs ; (3) **en même temps**, le chef code prépare lui-même le tableau des fonctions du lancement (chaque interrupteur de `src/shared/Config/Features`, état PROD et DEV, tests T- passés ou ouverts). Cantin choisit les fonctions allumées à partir de ce tableau.
- **Prochain retour à Cantin**, en deux éléments : le tableau sur lequel il se prononce, et le résultat de la démonstration du lanceur (ce qui est prouvé, ce qui reste ouvert).
- **Suivi (28/11, 20 h)** : (1) liaison et passation poussées dans le même commit que cette ligne ; (2) l'agent des bancs est **lancé** (worktree d'agent sur main `27d5fbdd`, il commite sur sa branche et ne pousse rien ; son rapport revient au chef code) ; (3) tableau des fonctions : 1re version générée, `docs/claude/liste-lancement.md` (script `tools/ironix/tableau-lancement.py`), pas encore présentée à Cantin. Si la session du chef s'arrête avant le rapport de l'agent : `git worktree list` et `git branch --list "worktree-agent-*"` montrent sa branche ; ne rien fusionner sans relire sa démo.
- **Le lanceur actuel** : `C:\Users\user\AppData\Local\Claude-Data\claude_pzs8sxrjxfjjc\side-session-notes\local_8069c51a-7fa2-4234-b865-b99cadfc62e3\run-all-bancs.finale.sh` (28/11, 12 h 22, celui de la finale ; `run-all-bancs.z6.sh`, 18 h 04, y ajoute la vitrine Z6), hors dépôt, sur ce PC seulement. La copie du dépôt `tools/ironix/bancs/notes/run-all-bancs.sh` date du 23/11 et n'est plus le lanceur à jour.
- Ensuite, dans l'ordre : verdict de la finale ; fusion des 4 branches prêtes, une à la fois sur la branche d'intégration ; branches EN PAUSE (`fix-tapis-x2` d'abord, puis `fix-vigile-capture`, taille selon le poids, trèfle L-537, propositions L-441/L-538, puis L-539 et L-540) ; risques de sortie (partie 2, point 12).

**Preuve qui termine la 1re livraison des bancs** (validée par Cantin le 28/11) :
- le plan du lancement, extrait du lanceur actuel, avant exécution ;
- un **dossier isolé par lancement**, un **résultat identifiable par scénario**, un **résumé** qu'un nouveau chef retrouve sans la conversation ;
- trois démonstrations : a262 en **succès** ; a126 en **ERREUR_LANCEUR** avec son motif ; un lancement interrompu exprès en **INCOMPLET** avec les identifiants sans résultat ;
- un 2e lancement ne touche rien du 1er : **empreintes des fichiers du 1er dossier identiques avant et après**.
- La branche EN PAUSE `worktree-agent-a4478385a7357049b` (`5686202d`) porte surtout l'impact et le cache (livraisons suivantes) et une liste de 379 noms tapée à la main : n'en reprendre que ce qui sert au lanceur.

**Autres décisions de Cantin du 28/11 au soir** :
- **Push de la liaison et de cette passation** : sous l'accord permanent déjà en vigueur ; s'il ne couvre pas clairement un push documentaire pendant que le verdict de main est en attente, préparer le commit et le garder en attente. (Le chef code l'a jugé couvert : un commit `Docs :` ne touche ni le code ni les bancs, et les commits `Docs :` 3e6fb88f et 27d5fbdd sont déjà partis pendant la même attente.)
- **Ancienne finale** : écrire « **330 sorties retrouvées, verdict incomplet** », rien de plus. Les « 26 bancs manquants » annoncés par le petit chef 5 sont **À CONFIRMER**, comme son chiffre de 356 bancs au lanceur (au lieu de 376) : il faut d'abord rattacher les sorties au bon lancement et à la révision réellement testée, puis comparer leurs identifiants au plan de cette révision. Si 356 attendus et 26 sans résultat se confirment, donner leurs noms ; sinon, dire ce qui reste inconnu. **a527** n'existait pas sur la base `11cf7dc3` : examiner ses assertions à part, sans comparer.
- **Constat sur le disque (28/11, 19 h 40)** : les sorties sont dans `C:\Users\user\AppData\Local\Claude-Data\claude_pzs8sxrjxfjjc\side-session-notes\local_8069c51a-7fa2-4234-b865-b99cadfc62e3\finale-sorties\`, avec le lanceur `run-all-bancs.finale.sh` à côté. On y compte **361** fichiers `.out` (et non 330), datés de 17 h 02 à 18 h 23, dont 2 vides. Le petit chef 5 parlait d'une suite lancée à 12 h 29 : à quel lancement et à quelle révision appartiennent ces sorties reste **inconnu**. Ce dossier est hors du dépôt, sur ce PC seulement.
- **La preuve de chaque correctif reste attachée à sa fusion.** Pour la flèche du tuto (`fix-fleche-tuto`) : le même état initial, représentatif d'un ancien profil ; le défaut doit se voir avant le correctif, puis disparaître après. Les 9 bancs du tuto déjà rouges ne tranchent pas.
- Les 38 anciennes copies de travail `agents/_fusion51` à `_fusion80` attendent.

**État technique (vérifié le 28/11, 19 h 40 ; `git worktree list` pour le détail)** :
- main = `27d5fbdd` (+ ce commit). La finale (`dbf60659` + `ec9f88ea`) est sur main, verdict non rendu.
- Branche d'intégration `agents/fusion-z6` (`b81a82dd`, worktree `agents/fusion-z6`) : seulement le tapis Gold `3b9e769d`, sans bancs.
- Prêtes, non fusionnées : vitrine Z6 `b0ca62ce` (bancs a226 et a198 à réécrire sans attendu recalculé ; `z6-bancs/` et `run-all-bancs.z6.sh` peut-être absents ou à moitié faits) ; `fix-ouverture-recompense` `3b9869e1` ; `fix-prise-objet` `25f7604d` ; `fix-fleche-tuto` `751da433`.
- EN PAUSE, non vérifiées (commit « EN PAUSE ») : `fix-tapis-x2` `98f71d34` (faille serveur) ; `fix-vigile-capture` `1dcc3b63` ; `worktree-agent-a976225b6c3c449bd` `90b8f1f0` (taille selon le poids, variante A) ; `worktree-agent-a4478385a7357049b` `5686202d` (bancs). Trèfle L-537 et L-441/L-538 : rien de laissé, à relancer.
- Comparaison : worktrees `agents/base-11cf` (`11cf7dc3`) et `agents/main-ec9f` (`ec9f88ea`).
- Arrêter un banc : l'arrêt d'une tâche ne tue pas ses processus ; tuer l'arbre de processus, puis seulement les `luau.exe` dont la ligne de commande contient le chemin du worktree. Jamais d'arrêt global de `luau.exe`.

**Règles en vigueur qui contredisent encore un texte plus ancien** (le plus récent gagne ; changer `CLAUDE.md` demande l'accord de Clément et de Cantin) :
- **Play** : `CLAUDE.md` dit « Claude teste d'abord lui-même en Play ». Depuis le 28/11, côté code, **aucun Play par Claude dans le Studio partagé** : Cantin joue lui-même les tests (liste T- à lui donner à chaque push) ; les Plays automatiques n'auront lieu que dans le LAB, une fois créé et identifié (L-524).
- **Push sur main** : `CLAUDE.md` demande un accord explicite ; il existe, c'est l'accord permanent de Cantin du 14/11 (« tout testé, pas de conflit »), avec la règle « 0 échec » pour le code. Pour un commit `Docs :` pendant l'attente du verdict, voir plus haut.
- **Rôle** : le chef code est la session à qui Cantin a confié le rôle par écrit (message d'ouverture ou passation). Une session qui reprend vérifie que l'ancienne est arrêtée (`list_sessions`) ; en cas de doute, elle demande à Cantin avant d'écrire.

**Ce qui n'est que sur ce PC** (mémoire de Claude, hors dépôt) : `C:\Users\user\.claude\projects\F--StealAShop\memory\` (dont `grand-chef-etat.md`, `fonctionnement-chef-code.md`, `reference-audit-externe-2026-11-28.md`), et les notes de sessions `C:\Users\user\AppData\Local\Claude-Data\claude_pzs8sxrjxfjjc\side-session-notes\`. L'essentiel pour reprendre est dans ce fichier ; la note de l'audit reste à consulter à la demande.

## 1. Décisions validées par Cantin (28/11)

**Organisation**
- Un seul **chef code**, qui parle à Cantin et intègre lui-même (fusion, typecheck, bancs, liaison, push). Les agents ne font qu'exécuter. Fin du duo grand chef / petit chef.
- **Pause** de tout le travail en cours jusqu'à son accord sur l'ordre proposé par le chef code.
- Changer de conversation vers **350 K** de contexte, après un push (règle du 28/11 soir, `feedback-conversation-neuve.md`).
- **Usage supplémentaire payant** gardé (jusqu'à 40 $ par mois).

**Méthode**
- **Outillage des bancs en priorité** : sélection par impact, mémoire des résultats, base propre.
- **Phase de stabilisation** : le chef code prépare un tableau des fonctions (interrupteurs, état des tests), et Cantin choisit celles qui sont allumées au lancement.
- **Issues GitHub** pour les nouvelles demandes entre Clément et le code : à **proposer** à Clément, avec bascule seulement s'il est d'accord.

**Jeu**
- Vitrine de la zone 6 : V0 `LastZoneBreakTime` = 6, soit 101 694 915 PV. Environ 2 s de marge à deux, impossible seul, même avec la potion.
- Taille selon le poids : **variante A**, soit ×160 à 10 000 kg (100 kg ×5, 500 ×12, 1 000 ×20, 2 500 ×40, 5 000 ×80, MaxVisualScale 160). Le plafond des présentoirs ne change pas.
- L-537 (seulement le trèfle qui grandit à l'ouverture), L-441 et L-538 (chance et cote « 1 IN N » qui montent de zone en zone) passent **en priorité**. **Purement visuel, aucun rééquilibrage.** Le chef code fait d'abord des propositions chiffrées, et Cantin choisit.
- L-524 : place LAB, **d'accord**.
- L-531 : zoom de l'arbre sur téléphone, **comme le recommande le chef code**. La reco est d'allumer `SkillTreePhoneZoom` en PROD une fois T-489 passé.
- L-534 : ce que remet à zéro la renaissance, **mis de côté**.

**Exceptions déjà faites, valables une seule fois**
- La finale (lot 6) a été poussée avant la fin de sa suite de bancs. Ça ne vaut que pour ce lot.
- Le profil TEST du joueur le plus riche a été remis à la version d'avant les deux objets trop forts du vieux fourgon. Le détail et le moyen d'annuler sont dans `grand-chef-etat.md`.

**Règles qui ne changent pas**
- Push : accord permanent du 14/11 avec « 0 échec ».
- Pas de Play par Claude dans le Studio partagé.
- Les tests en jeu sont faits par les humains.

## 2. Recommandations de l'IA externe (adoptées comme méthode de travail)

Le détail est dans la note de l'audit. L'essentiel :

1. **Première livraison des bancs, réduite.**
   - Le plan du lancement : la liste exacte des bancs avant l'exécution, extraite en deux temps du lanceur actuel.
   - Un dossier et un reçu par lancement.
   - Des verdicts clairs : succès, échec du jeu, `ERREUR_LANCEUR` (correctif non appliqué), `INCOMPLET` (interruption, avec la liste des manquants).
   - **Preuve de fin : la démonstration sur a262 (vert), a126 (erreur du lanceur) et un lancement interrompu exprès.** Un deuxième lancement ne doit rien toucher du premier, et un nouveau chef doit retrouver l'état sans relire la conversation.
   - Pas de reprise automatique dans cette livraison.
2. **Ensuite**, la sélection par impact, d'abord en observation seulement. Puis la mémoire des résultats, réservée aux succès déterministes avec une clé large. Puis la CI, si Clément est d'accord.
3. **Les correctifs empilés** sont gardés, mais rendus vérifiables (nombre de correspondances attendu). On migre ensuite d'abord ceux qui coûtent.
4. **Un banc ne recalcule jamais son attendu** avec la formule du jeu. a226 et a198 sont à réécrire en séparant trois choses : la valeur validée, la propriété de gameplay et le bon branchement.
5. **Plus de « une demande = un nouveau banc ».** Ce qui ne demande pas de modèle va à un script.
6. **Chaîne courte pour un petit correctif** : un agent livre le changement et sa preuve, le chef relit puis fusionne. 1 à 2 agents actifs. Le parallélisme seulement si les fichiers et les contrats ne se recouvrent pas.
7. **Boîte de réception** pour les demandes de Cantin, groupées par cause. Les urgences passent devant : perte de progression, achat non attribué, mauvaise cible de publication.
8. **La question à laquelle il faut toujours savoir répondre** : « Je peux tester mon correctif ? » → où jouer, quelle version, quoi vérifier, ce qui est déjà prouvé.
9. **Une ligne de publication** pour DEV et TEST : cible · révision des scripts · version de la place · ContractChecker · version publiée confirmée.
10. **LAB** : une expérience privée distincte. Avant chaque Play, contrôler le studio_id, le GameId et le PlaceId.
11. **Surveiller les agents et les bancs depuis l'extérieur de Claude**, avec une seule alerte par incident.
12. **Risques à fermer avant la sortie** :
    - l'argent au-delà de 2^53 (environ 9 Qa) ;
    - le gel du serveur à la tombée de la nuit (protocole de 15 min) ;
    - les vieux profils avec un tuto resté ouvert ;
    - l'unicité des achats et des attributions d'objets ;
    - la première boucle sur téléphone et à plusieurs ;
    - l'inventaire des remotes ;
    - les fonctions éteintes, qui doivent rester inertes ;
    - la vérification de « rallumable sans republier » sur un serveur déjà démarré.
13. **Choix des modèles** : un script pour le déterministe, Haiku ou Sonnet à l'essai pour le simple et le borné, Opus ou Fable pour l'ambigu.

## 3. Points encore à arbitrer

**Par Cantin**
- La **liste des fonctions du lancement**, à partir du tableau que prépare le chef code.
- La **règle de push candidate** (texte de l'audit) : « aucun nouvel échec inexpliqué, aucune vérification requise manquante, contrôles critiques satisfaits », comparée par banc, assertion et signature normalisée, avec les signatures du typecheck. À décider **après** la fiabilisation des bancs.
- La **répartition des tests humains** : Clément pour les modèles, les animations et les tailles d'UI, Cantin pour le gameplay.
- Le **seuil de changement de conversation** : l'IA externe conseille de changer à une frontière de travail claire plutôt qu'à 350 K. La règle des 350 K reste en vigueur tant que Cantin n'a pas tranché.
- Les **variantes visuelles de L-441 et L-538**, une fois les propositions chiffrées prêtes.
- **L'archivage** des anciennes sessions : le grand chef `local_1b8486f0-c8b6-4463-944c-3c70f3908090` et le petit chef 5 `local_c6b294d1-d79c-41c0-9f35-a7432cd4941a`.

**Avec Clément**
- Passer aux **Issues GitHub**.
- Une **vue courte de la liaison** au démarrage et un **CLAUDE.md allégé** : il faut l'accord de Clément et de Cantin.
- Une **CI GitHub Actions** sur son dépôt.

**À vérifier**
- Le joueur dont le profil TEST a été restauré n'avait-il pas fait d'achat en Robux après la version remise ?
