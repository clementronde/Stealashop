# CLAUDE.md — Steal a Shop

Ce fichier est lu par Claude à chaque session ouverte dans ce dossier. Il dit ce qu'est le jeu, où trouver la vérité et quelles règles ne jamais casser.

## Le jeu en 4 lignes

- **Steal a Shop** : jeu Roblox de type « Steal a … » à 6 joueurs, mélangé avec du braquage.
- Boucle : s'entraîner (tapis = vitesse, banc = force) → casser la vitrine d'un magasin PNJ → voler un colis en 10 s → semer le vigile → ouvrir le colis en base → exposer l'objet → encaisser des $/s → améliorer → braquer plus loin, ou braquer un autre joueur.
- 6 zones de magasins PNJ dans un couloir, de plus en plus rares et dures selon la puissance et la vitesse. Cycle jour/nuit : la nuit, un mur ferme le couloir et des vigiles de nuit patrouillent.
- Lancement du MVP visé le vendredi 18 décembre 2026, puis une mise à jour par samedi.

## Qui fait quoi

| Personne | Rôle | Ce que Claude fait pour lui |
| --- | --- | --- |
| Clément | Modèles 3D, map, **toute l'UI** (ScreenGuis), **toutes les animations** (joueurs, vigiles, PNJ), icônes, textures | Modélise et vérifie dans Blender, importe et range dans Studio, pose tags et attributs, construit les écrans d'UI, prépare et vérifie les animations, vérifie le contrat |
| Ironix | Code Luau (serveur + client), intégration, publication | Écrit et relit le code dans `src/`, branche l'UI et les animations de Clément, teste |

Le jeu, ses places DEV et PROD et tous ses assets (modèles, animations, sons) appartiennent au **groupe Roblox du studio** : Clément en est propriétaire, Ironix y a un rôle « Dev ». Tout se publie au nom du groupe, jamais sur un compte perso. Le groupe servira aussi aux jeux suivants.

Le parcours pas à pas de Clément avec Claude est dans [docs/claude/Etapes-Clement.md](docs/claude/Etapes-Clement.md).

## Sources de vérité

1. **Le doc de suivi partagé** (version à jour, avec statuts et commentaires) : https://claude.ai/artifact/QKsqfJ3YEjFn41GERuTGUx
2. Ses copies figées dans ce dépôt : [docs/Partie-1-MVP.md](docs/Partie-1-MVP.md) et [docs/Partie-2-Features-a-ajouter.md](docs/Partie-2-Features-a-ajouter.md).

3. **La liaison code ↔ visuel** : [docs/Liaison-Code-Visuel.md](docs/Liaison-Code-Visuel.md). Ce que Clément attend d'Ironix et inversement, le registre des animations et les contrats qui relient les deux travaux.

**À chaque session, pour les deux** : `git pull`, puis lire la liaison et dire à la personne ce qui l'attend et ce qui a changé (mode d'emploi en tête du fichier). Dès que la conversation produit quelque chose que l'autre doit faire, livrer ou savoir, l'écrire dans la liaison et le pousser dans le même tour. Qui est qui : `git config user.name` = `Ironix` ou `Clement`.

En cas de doute, le doc partagé gagne. Ne jamais inventer une valeur (PV, prix, vitesse, raretés, durées) : la lire dans les sections 4, 5 et 7 de la Partie 1, ou dans `Config` côté code.

## Règles à ne jamais casser

### Qui touche à quoi dans Studio (Partie 1, section 2.1)

| Emplacement | Propriétaire | Règle pour Claude |
| --- | --- | --- |
| `ServerScriptService/Server`, `StarterPlayerScripts/Client`, `ReplicatedStorage/Shared` | Ironix, via Script Sync | Ne rien y créer ni modifier depuis Studio : ces dossiers sont le miroir du disque d'Ironix (`src/`), tout changement part chez lui |
| `Workspace/Map`, `ReplicatedStorage/Assets` (modèles, UI, animations), `ServerStorage/Assets` | Clément | Ne déplacer ni renommer sans que Clément le demande |
| `ServerStorage/AnimRigs`, `ServerStorage/RBX_ANIMSAVES` | Clément | Rigs et brouillons d'animation : ne jamais les supprimer |
| `StarterGui` (toute l'UI), `Lighting` | Clément | Aucun script dans l'UI |
| `Workspace/_INBOX_CLEMENT` | Clément | Zone de dépôt des livraisons, vidée par Ironix |
| `Workspace/_SANDBOX_IRONIX` | Ironix | Tests temporaires |

- **Quand Claude travaille pour Clément** : il peut exécuter du Luau dans Studio pour construire ou vérifier (comme la barre de commande), mais il ne laisse jamais de `Script`, `LocalScript` ou `ModuleScript` dans un modèle ou dans l'UI. Seule exception, acceptée par Clément le 2026-11-06 (liaison, section 3.3) : un petit script d'effet visuel nommé `FX_<Nom>`, en `Script` avec `RunContext = Client`, visuel uniquement (jamais d'argent, de stats, de vitesse, de dégâts, de collisions, de Humanoid ni de RemoteEvent), seulement dans le décor unique (enseigne, fontaine, lumière d'ambiance). Jamais sur un objet répété (objets exposés, présentoirs, colis, outils), jamais dans l'UI ni dans un modèle animé, et jamais quand un objet natif suffit (ParticleEmitter, Beam, Trail, néon).
- **Quand Claude travaille pour Ironix** : il ne modifie aucun visuel (couleurs, tailles, images, positions de la map ou de l'UI).

### Le contrat de noms

Le code retrouve tout par **tags** et par **noms convenus**, jamais par chemin.

- **Tags** : `NPCStore`, `PlayerPlot`, `Treadmill`, `Bench`, `WeaponShop`, `AuraShop`, `RobuxShop`, `SafeZone`, `ZoneGate`, `NightWall`, `NightPatrol`.
- **Attributs** : `Zone` (1 à 6), `Tier` (`Standard`, `Premium`, `Luxe`), `ItemId`.
- **Nommage des assets** (section 10.3) : `PREFIXE_Zone-ou-Categorie_Nom_Variante`, PascalCase, sans accents ni espaces. Préfixes : `ITM`, `BOX`, `TOOL`, `STORE`, `PLOT`, `WIN`, `ACC`, `ENV`, `FX`.
- **Enfants obligatoires des modèles** : section 10.4 (ex. un magasin PNJ a `Window`, `WindowFractured` avec `Shard_01` à `Shard_40`, `Shutter`, `Door`, `Bounds`, `ShelfSlot_01` à `_10`, `GuardSpawn`, `SignPart`).
- **Contrat UI** (section 2.2) : un écran = un ScreenGui `UI_<Nom>` ; éléments lus par le code en anglais PascalCase ; jamais un nom qui est aussi une propriété Roblox (`Name`, `Text`, `Size`, `Position`, `Visible`, `Parent`) ; listes = un `Template` invisible que le code clone ; billboards modèles `BB_*` dans `ReplicatedStorage/Assets/UI`.
- **Changer un nom du contrat** = d'abord l'annoncer, mettre à jour le doc (tableaux 2.2 et 10.4), puis seulement renommer.

### Modèles

- 1 unité Blender = 1 stud ; pivot en bas au centre ; face avant vers la rue.
- Budgets de triangles de la section 10.2 (objet ≤ 2 000, Légendaire et plus ≤ 4 000, colis ≤ 300, outil ≤ 1 500, magasin ≤ 12 000 dehors et 15 000 dedans).
- `CollisionFidelity = Box` par défaut, `Hull` si la forme compte ; `CanCollide` coupé pour le petit décor.
- Tout modèle venu du Creator Store est vidé de ses scripts avant usage.

### Animations (Partie 1, section 2.4)

- Clément fait toutes les animations ; Ironix décide quand elles se jouent. Ils se retrouvent sur un nom (animation et marqueurs), jamais sur un timing en secondes. Contrat complet : section 2.4 du doc partagé et section 3.2 de la liaison (mêmes noms).
- Rig R15 standard pour tout (joueurs, vigiles, vendeurs). Rigs de travail dans `ServerStorage/AnimRigs`.
- **Où** : objets `Animation` dans un dossier `Animations`. Modèle animé (vigile, vigile de nuit, vendeur) : dans le modèle, `<Modèle>/Animations/<Nom>` (`Idle`, `Walk`, `Run`, `Catch`, `Tired` ; vendeur : `Idle`, `Wave`). Joueur : `ReplicatedStorage/Assets/Animations/Player/<Nom>` (`HitWindow`, `HitWindowHeavy`, `Grab`, `CarryIdle`, `CarryRun`, `Place`, `TreadmillRun`, `BenchLift`, `Unbox`, `Celebrate`, `SwingBat`, `Stunned`, `Knockback`).
- **Aucun script dans un modèle animé** : il contient un Humanoid avec un `Animator` et son dossier `Animations` ; c'est le code d'Ironix qui joue les animations, déplacements compris.
- **Publication** : au nom du groupe Roblox du studio, propriétaire du jeu, par Clément ou par Ironix. Une animation publiée sur un compte perso ne se joue pas dans le jeu (« Failed to load animation »).
- **Mettre à jour** : remplacer l'`AnimationId` de l'objet existant, ne jamais le supprimer ni le renommer.
- Clément règle dans chaque animation la priorité (Idle, Movement, Action), la boucle et les marqueurs (`Impact`, `Grab`, `Release`, `Top`, `Open`, `Land`) posés sur l'image clé concernée.
- Ironix charge l'animation par son nom (jamais un ID dans le code) et accroche sons et effets aux marqueurs. Il ne retouche jamais une animation.
- `CarryIdle` et `CarryRun` n'animent que le haut du corps, en priorité Action.
- Chaque animation publiée va dans le registre de la liaison (nom, emplacement, ID).
- Claude ne peut pas animer à la place de Clément dans l'éditeur d'animation : il prépare les rigs et les dossiers, propose un découpage des poses, crée les objets `Animation` avec les identifiants fournis et vérifie noms, priorités, boucles et marqueurs.

### UI

- Tailles en Scale + `UIAspectRatioConstraint` ; boutons d'au moins 44 px de haut sur téléphone ; rien d'important en haut de l'écran.
- Clément livre d'abord une version grise (bons noms, aucun style), puis l'habille sans changer les noms.

### Code (Ironix)

- Luau `--!strict`, serveur autoritaire : le client demande, le serveur décide (argent, PV, raretés, prix).
- Chaque remote est validé côté serveur (section 9.4) ; aucune valeur sensible ne vient du client.
- Sauvegarde avec ProfileStore ; achats Robux idempotents (`PurchaseId` stocké).

### Avant toute livraison

1. Lancer un test dans Studio.
2. Lire la sortie : le ContractChecker ne doit afficher aucune ligne rouge.
3. Pour un modèle : vérifier taille à côté d'un perso R15 (environ 5 studs), triangles, noms, tags.

## Outils de Claude utiles ici

- **MCP Roblox Studio** (si connecté) : lire l'arbre du jeu, exécuter du Luau dans Studio, insérer et ranger des modèles, poser tags et attributs, lancer et arrêter un test, lire la sortie, faire une capture.
- **MCP Blender** (si connecté) : modéliser ou retoucher un asset, compter les triangles, vérifier pivot et échelle, faire des rendus d'icônes, exporter en FBX.
- **Génération 3D (Meshy)** : utile pour un brouillon d'objet, mais elle consomme des crédits. Claude demande toujours avant de lancer une génération payante.

## Façon de travailler

- Répondre en français.
- Avant une tâche, citer son ID du backlog (`MOD-012`, `UI-001`, `DEV-018`…) et relire ses colonnes « Fini quand… » et « Dépend de ».
- Une décision nouvelle se note dans le journal des décisions du doc partagé (section 15), pas seulement dans le chat.
- Git : messages de commit en français, préfixés `Docs :`, `Modèle :`, `UI :` ou `Code :`. Ne jamais pousser sur `main` sans accord explicite.
- **Avant chaque push** : `git pull`, puis relire la section 3.5 de la [liaison](docs/Liaison-Code-Visuel.md) (ce que le Claude de Clément ne touche jamais). Un hook du projet (`.claude/settings.json`) refuse tout push qui modifie `src/` quand `git config user.name` n'est pas `Ironix` : ne jamais le contourner, retirer les changements de `src/` et noter le besoin dans la liaison.

## Lexique

| Mot | Sens dans ce jeu |
| --- | --- |
| Boutique | La parcelle-magasin d'un joueur, où il expose ses objets |
| Magasin PNJ | Un magasin du couloir que l'on braque |
| Couloir | La rue des 6 zones de magasins PNJ |
| Zone safe | Le lobby avec les 6 parcelles ; pas de vigile PNJ, mais le PvP y reste possible |
| Colis | La boîte volée à un magasin PNJ : Standard, Premium ou Luxe |
| Rareté | Commun, Peu commun, Rare, Épique, Légendaire, Mythique, Secret |
| Halo de rareté | L'effet lumineux autour d'un objet ou d'un colis porté, aux couleurs de sa rareté |
| Aura / trail | Effets achetés par le joueur : l'aura multiplie la puissance, le trail la vitesse |
| Boutiques d'achat | Boutique d'armes et boutique d'auras (argent du jeu), boutique Robux |
| Nuit | Phase de 2 min où le couloir est fermé et les rayons PNJ se remplissent |
| Renaissance | Remise à zéro contre argent + un objet précis, pour un bonus permanent |
| Marqueur | Nom posé sur une image clé d'une animation (`Impact`, `Grab`…), auquel le code accroche un son ou un effet |
