# Liaison code ↔ visuel

Ce fichier fait le lien entre le travail d'**Ironix** (code) et celui de **Clément** (3D, UI, animations). Tout ce que l'un attend de l'autre, et tout accord qui relie les deux travaux (un nom, un ID, un emplacement, une règle), est écrit ici. Une attente qui n'est que dans le chat n'existe pas.

Il est lu par les deux Claude, à chaque session (voir [CLAUDE.md](../CLAUDE.md)).

## Mode d'emploi (pour les deux Claude)

1. **Début de session** : `git pull`, puis lire ce fichier. Dire à la personne ce qui l'attend (lignes « Pour » à son nom et statut « À faire ») et ce qui a changé depuis son dernier commit (`git log -p <son dernier commit>..HEAD -- docs/Liaison-Code-Visuel.md`).
2. **Qui est qui** : `git config user.name` = `Ironix` → Ironix ; `Clement` → Clément.
3. **Pendant la session** : dès qu'une conversation produit quelque chose que l'autre doit faire, livrer ou savoir (un objet, une animation publiée et son ID, un nom à poser, un renommage, une règle qui touche les deux), ajouter ou mettre à jour une ligne ici et pousser sur `main` dans le même tour, avec un commit `Docs : liaison …`.
4. **Fermer une ligne** : seulement quand c'est vérifié dans Studio. On passe le statut à « Fait » avec la date ; les lignes faites partent dans l'historique (section 4) au bout d'une semaine.
5. **Un accord durable** (contrat de noms, règle de travail) va en section 3, pas dans les tâches.

Statuts : `À faire`, `En cours`, `À vérifier` (livré, l'autre doit tester), `Fait`.

## 1. Attentes ouvertes

C'est **la liste d'attente de Clément** (lignes « Pour : Clément ») et celle d'Ironix. Chaque fois que Claude dit à Ironix « Clément doit faire… » (un modèle, une animation, un son, un écran, une action sur le Creator Hub, une décision), la ligne est ajoutée ici avec le nom exact attendu et la section du doc qui le définit, puis poussée dans le même tour. Une ligne ne se ferme qu'une fois vérifiée en jeu.

| ID | Pour | Quoi | Détail, noms exacts | Débloque | Ajouté | Statut |
| --- | --- | --- | --- | --- | --- | --- |
| L-001 | Clément | Ajouter Ironix comme collaborateur sur les places DEV et PROD | Droit « Modifier » (Creator Hub → l'expérience → Collaborateurs), sinon Ironix ne peut ni coder en Team Create ni publier | DEV-001 | 2026-11-06 | À faire |
| L-002 | Clément | Valider la liste des noms d'animation | Validée et complétée : marqueurs, priorités, boucles et 7 animations en plus (section 3.2) | DEV-012, DEV-018, DEV-043 | 2026-11-06 | Fait (2026-11-06) |
| L-003 | Clément | Valider ou refuser la règle « scripts FX de Clément » | Section 3.3. Tant qu'elle n'est pas validée, la règle de [CLAUDE.md](../CLAUDE.md) s'applique : aucun script laissé dans un modèle ou dans l'UI | — | 2026-11-06 | À faire |
| L-004 | Clément | Reporter dans le doc partagé : animations faites par Clément, intégrées par Ironix via le contrat de noms | Fait dans le doc partagé : section 2.4 « Contrat d'animations », question « Animations (M0) » cochée, ligne « Modèle animé » ajoutée au tableau 10.4 | — | 2026-11-06 | Fait (2026-11-06) |
| L-010 | Ironix | Jouer toutes les animations par leur nom, jamais par un ID écrit dans le code | Le code cherche l'objet `Animation` par son nom (section 3.2) ; un nom manquant est signalé par le ContractChecker | DEV-005, DEV-018 | 2026-11-06 | À faire |
| L-011 | Ironix | Brancher les 7 animations ajoutées et les marqueurs | Joueur : `HitWindowHeavy`, `Grab`, `Place`, `Unbox`, `Celebrate` ; vendeur : `Idle`, `Wave`. Marqueurs `Impact`, `Grab`, `Release`, `Top`, `Open`, `Land` (tableau 3.2) ; tâche DEV-006 du doc partagé | DEV-006 | 2026-11-06 | À faire |

## 2. Registre des animations

Clément remplit une ligne dès qu'une animation est publiée ; Ironix coche « Branchée » quand le code la joue. L'ID sert de trace : le code, lui, ne lit que l'objet `Animation` posé dans Studio.

| Pour | Nom (objet `Animation`) | Où dans Studio | ID publié | Branchée dans le code |
| --- | --- | --- | --- | --- |
| — | — | — | — | — |

## 3. Contrats en vigueur

### 3.1 Les 3 dossiers synchronisés (code d'Ironix)

Seuls ces 3 dossiers viennent du disque d'Ironix (synchro Rojo, section 2.1 du doc). Tout ce qui est posé dedans depuis Studio est effacé à la synchro ; tout ce qui est ailleurs n'est jamais touché par elle.

| Disque (`src/`) | Studio |
| --- | --- |
| `src/shared` | `ReplicatedStorage/Shared` |
| `src/server` | `ServerScriptService/Server` |
| `src/client` | `StarterPlayer/StarterPlayerScripts/Client` |

Une seule personne synchronise : Ironix. Clément ne lance aucune synchro ; il teste en appuyant sur Play dans la place DEV, qui contient toujours le dernier code synchronisé.

### 3.2 Animations

**Le principe** : Clément décide à quoi ressemble une animation, Ironix décide quand elle se joue. Ils se retrouvent sur un nom.

- **Où** : un dossier `Animations` contenant des objets `Animation`.
  - Animations d'un modèle animé (vigile, vigile de nuit, vendeur) : dans le modèle lui-même, `<Modèle>/Animations/<Nom>`. Le modèle contient un Humanoid avec un `Animator`, et aucun script : c'est le code d'Ironix qui joue les animations.
  - Animations du personnage joueur : `ReplicatedStorage/Assets/Animations/Player/<Nom>`.
- **Publication** : le jeu appartient à Clément, donc **toutes les animations sont publiées depuis le compte de Clément**. Une animation publiée par un autre compte ne se joue pas dans son jeu (personnage figé, « Failed to load animation » dans la sortie). Si le jeu passe un jour sous un groupe Roblox, les animations se publient sous ce groupe.
- **Tester** : dans l'Animation Editor (aucune dépendance au code), puis en Play une fois que le code joue ce nom.
- **Mettre à jour** : remplacer l'`AnimationId` de l'objet existant. **Ne jamais supprimer ni renommer l'objet** : le code ne le retrouverait plus.
- **Réglé par Clément dans l'éditeur** : priorité, boucle et marqueurs du tableau ci-dessous, posés sur l'image clé concernée. Ironix accroche sons et effets aux marqueurs. `CarryIdle` et `CarryRun` n'animent que le haut du corps, en priorité Action.
- **Noms validés** (L-002, 2026-11-06), complétés par Clément ; même contrat que la section 2.4 du doc partagé :

| Pour | Nom | Quand | Boucle | Priorité | Marqueur |
| --- | --- | --- | --- | --- | --- |
| Joueur | `HitWindow` | Coup sur une vitrine, des poings au pied-de-biche | Non | Action | `Impact` |
| Joueur | `HitWindowHeavy` | Coup sur une vitrine, du marteau à la disqueuse (ajout) | Non | Action | `Impact` |
| Joueur | `Grab` | Prise d'un colis sur un rayon ou au sol (ajout) | Non | Action | `Grab` |
| Joueur | `CarryIdle` | Colis au-dessus de la tête, à l'arrêt, bras seuls | Oui | Action | — |
| Joueur | `CarryRun` | Colis au-dessus de la tête, en courant, bras seuls | Oui | Action | — |
| Joueur | `Place` | Poser un colis sur l'établi (ajout) | Non | Action | `Release` |
| Joueur | `TreadmillRun` | Course sur le tapis | Oui | Movement | — |
| Joueur | `BenchLift` | Une répétition au banc | Non | Action | `Top` |
| Joueur | `Unbox` | Ouvrir un colis (ajout) | Non | Action | `Open` |
| Joueur | `Celebrate` | Objet Légendaire ou mieux révélé (ajout) | Non | Action | — |
| Joueur | `SwingBat` | Coup de batte | Non | Action | `Impact` |
| Joueur | `Stunned` | Étourdi pendant 2 s | Oui | Action | — |
| Joueur | `Knockback` | Projeté par un coup | Non | Action | `Land` |
| Vigile, jour et nuit | `Idle` | En attente | Oui | Idle | — |
| Vigile, jour et nuit | `Walk` | Ronde ; le vigile de nuit tient sa lampe torche | Oui | Movement | — |
| Vigile, jour et nuit | `Run` | Poursuite | Oui | Movement | — |
| Vigile, jour et nuit | `Catch` | Le coup qui projette le joueur | Non | Action | `Impact` |
| Vigile, jour et nuit | `Tired` | Retour essoufflé | Non | Action | — |
| Vendeur | `Idle` | Derrière son comptoir (ajout) | Oui | Idle | — |
| Vendeur | `Wave` | Salue quand on approche (ajout) | Non | Action | — |

### 3.3 Scripts FX de Clément (proposition d'Ironix, à valider : L-003)

Clément peut écrire de petits scripts d'effets visuels, à ces conditions :

1. **Jamais dans les 3 dossiers synchronisés** (3.1) : rien n'y est créé, modifié ni supprimé.
2. **Visuel uniquement** : particules, lumière, mouvements décoratifs. Jamais de RemoteEvent, de sauvegarde, d'argent, de stats, de vitesse, de dégâts, de collisions, d'ancrage ni de Humanoid.
3. **Côté client** : un `Script` avec `RunContext = Client` (un `LocalScript` ne tourne pas dans un modèle du Workspace), et pas un script serveur par exemplaire de modèle.
4. **Nommé `FX_<Nom>`**, pour qu'on les retrouve tous d'une recherche dans l'explorateur.
5. **Pas de script quand un objet suffit** : ParticleEmitter, Beam, Trail, Highlight ou matériau néon n'en ont pas besoin.
6. **Les animations ne passent pas par ces scripts** : elles suivent la section 3.2.

Ces scripts vivent dans la place (pas dans Git) : leur seul historique est celui des versions de la place. Une logique de jeu passe toujours par le code d'Ironix et GitHub.

### 3.4 Méthode de travail

- **Synchro** : toujours et uniquement sur le PC d'Ironix. Le dossier `F:\StealAShop` d'Ironix est relié à la place DEV : mettre à jour ce dossier, c'est mettre à jour Studio. Personne d'autre ne synchronise, même pour tester.
- **« Pull »** (Ironix dit « pull » ou « récupère le GitHub ») : Claude fait toute la routine sans demander. `git fetch`, mise à jour de `main` en avance rapide (jamais de force), contrôle du code (compilation Rojo, puis les vérifications ajoutées au fil du projet), puis dans Studio : le nombre de scripts correspond au disque, et un court test en Play sans erreur dans la sortie. Il dit ce qui est arrivé (commits, fichiers) et ce qui casse.
- **Agents** : chaque session d'agent travaille dans son propre worktree Git, dans le dossier `agents\` à la racine du projet, `F:\StealAShop\agents\<id>` (par exemple `a01`), jamais directement dans `F:\StealAShop` ni à la racine du disque. Le dossier `agents/` est ignoré par Git (`.gitignore`) et la synchro ne lit que `src/`, donc le travail des agents n'arrive jamais dans la place DEV avant d'être fusionné. Une branche fusionnée l'est d'abord dans un worktree temporaire, puis `main` avance en `--ff-only` : jamais de fichier à moitié fusionné dans Studio. Toujours `git fetch` avant (l'autre pousse souvent), jamais de `push --force`.
- **Pousser** : un changement validé à deux part directement sur `main`, sans branche ni PR.

## 4. Historique

| Date | ID | Ce qui a été fait |
| --- | --- | --- |
| 2026-11-06 | — | Création de ce fichier |
