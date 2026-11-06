# Parcours de Clément avec Claude

Les 43 tâches MVP de Clément : les 36 de modèles et d'UI (backlog, Partie 1 section 13), regroupées en 20 étapes dans l'ordre où les faire, plus les 7 tâches d'animation (section 2.4), à mener en parallèle (piste « Animations » en fin de fichier). Chaque étape donne ce que tu fais toi-même, la consigne à copier-coller dans Claude, et le critère « fini quand ».

Claude lit [CLAUDE.md](../../CLAUDE.md) au démarrage : il connaît déjà les noms, tags, budgets et règles. Les consignes ci-dessous restent courtes pour cette raison.

## Avant de commencer (une seule fois)

1. Crée le groupe Roblox du studio, avec un nom de studio et pas le nom du jeu. Ajoute un rôle « Dev » qui peut modifier les jeux du groupe et publier des assets, et mets-y Ironix (L-001 dans la [liaison](../Liaison-Code-Visuel.md)).
2. Clone le dépôt dans un dossier permanent, par exemple dans tes Documents :

   ```bash
   git clone https://github.com/clementronde/Stealashop
   ```

   Puis ouvre Claude Code dans ce dossier `Stealashop`, pour qu'il lise `CLAUDE.md`. Quand Claude Code te demande d'accepter les réglages du projet, réponds **oui** : sinon le garde-fou d'Ironix, qui refuse tout envoi modifiant `src/`, ne s'active pas. Ce garde-fou ne contrôle que les envois faits par Claude : à la main, depuis un terminal ou GitHub Desktop, rien ne t'arrête. Ne touche donc jamais à `src/`.
3. Ouvre la place DEV du groupe en Team Create (tâche DEV-001).
4. Connecte le MCP Roblox Studio (plugin actif dans Studio) et le MCP Blender (add-on activé dans Blender).
5. Dans Blender, active l'extension **Cell Fracture** (pour les vitres).
6. Vérifie que tout répond :

   > Liste ce que tu vois dans Workspace et dans StarterGui de la place ouverte dans Studio, puis dis-moi quels objets sont dans la scène Blender.

7. **À chaque session ensuite**, commence par :

   > Récupère les derniers commits du dépôt, lis la liaison et dis-moi ce qui m'attend et ce qui a changé.

## Routine de livraison (à chaque asset)

1. Dépose le modèle dans `Workspace/_INBOX_CLEMENT`.
2. Demande la vérification :

   > Vérifie `<NOM DU MODÈLE>` dans `_INBOX_CLEMENT` avec le contrat de CLAUDE.md : nom, enfants obligatoires (section 10.4), tags, attributs, triangles, pivot, taille à côté d'un perso R15, aucun script (sauf un script d'effet `FX_` autorisé par la liaison, section 3.3). Corrige ce qui est purement technique (collisions, ancrage) et liste le reste sans le modifier.

3. Lance un test dans Studio : le ContractChecker ne doit afficher aucune ligne rouge.
4. Passe la tâche en « En revue » dans le doc partagé ; Ironix valide et range le modèle.

## M0 · semaine du 9 novembre

### Étape 1 · MOD-001 · Chaîne Blender vers Studio

- **Toi** : tu importes le FBX dans Studio avec le 3D Importer (Claude ne peut pas le faire à ta place).
- **Consigne** :

  > Dans Blender, crée un cube de 4 × 4 × 4 unités, pivot en bas au centre, nommé `ENV_TestCube`, et exporte-le en FBX dans `/Art/Test/`. Une fois que je l'ai importé dans Studio, mesure sa taille en studs et son orientation. Si ce n'est pas 4 × 4 × 4 et bien orienté, dis-moi quel réglage d'export ou d'import changer, puis on refait le test.

- **Fini quand** : le cube arrive à 4 × 4 × 4 studs, et les réglages validés sont notés dans la section 10.1 du doc.

### Étape 2 · MOD-002 · Planche de style

- **Toi** : tu colles d'abord tes références dans la section 2.3 du doc (style, objets, UI).
- **Consigne** :

  > À partir des références de la section 2.3, propose une palette (fond, accents, 7 couleurs de raretés du gris à l'arc-en-ciel). Modélise dans Blender 3 objets test low-poly : `ITM_Z1_CanetteDeSoda` (Commun), `ITM_Z1_BoissonEnergisante` (Épique), `ITM_Z1_TicketAGratterGagnant` (Légendaire), dans les budgets de la section 10.2. Fais un rendu des trois côte à côte, puis propose un style d'UI (police, coins, ombres, couleurs de boutons).

- **Fini quand** : palette, objets test et style d'UI validés avec Ironix.

## M1 · du 16 au 29 novembre

### Étape 3 · MOD-010 et MOD-011 · Vitre M et fissures

- **Consigne** :

  > Dans Blender, crée `WIN_M` : 12 × 7 × 0,4 studs, pivot en bas au centre. Puis `WIN_M_Fractured` avec Cell Fracture : 30 à 40 éclats nommés `Shard_01`, `Shard_02`…, pivot de chaque éclat en son centre, 1 500 triangles maximum au total. Exporte les deux en FBX. Prépare aussi 3 textures de fissures (75, 50 et 25 % de PV) en PNG transparent 512 × 512.

- **Toi** : import dans Studio, puis :

  > Renomme la vitre intacte `Window` et le modèle fracturé `WindowFractured`, place-les exactement au même endroit, et cache `WindowFractured`.

- **Fini quand** : Ironix a joué la casse avec (DEV-016) et elle est belle.

### Étape 4 · MOD-013 · Colis

- **Consigne** :

  > Modélise `BOX_Standard` (carton brun), `BOX_Premium` (carton bleu scellé) et `BOX_Luxe` (caisse en bois cerclée d'or), 300 triangles maximum chacun, avec un couvercle séparé nommé `Lid` et une pièce `Tint` recolorable selon la rareté. Après import dans Studio, ajoute à chacun un attachment `CarryAttachment` sous le colis, au centre.

- **Fini quand** : les 3 colis passent la routine de livraison.

### Étape 5 · MOD-012 · Magasin zone 1, la Supérette

- **Consigne** :

  > Construis `STORE_Z1_Superette` : façade de supérette, vitrine `WIN_M`, intérieur avec 3 rangées de rayons et une réserve au fond. Dans Studio, ajoute tous les enfants du contrat 10.4 : `Window`, `WindowFractured`, `Shutter` (position ouverte), `Door`, `Bounds`, `ShelfSlot_01` à `_10` avec l'attribut `Tier` (6 Standard devant, 3 Premium au milieu, 1 Luxe dans la réserve), `GuardSpawn` près de la réserve, `SignPart`. Pose l'attribut `Zone = 1` et le tag `NPCStore`. Vérifie les budgets : 12 000 triangles dehors, 15 000 dedans.

- **Fini quand** : routine de livraison passée, et un perso R15 circule bien entre les rayons.

### Étape 6 · MOD-015 · Parcelle niveau 1, le Stand

- **Consigne** :

  > Construis `PLOT_Shop_L1` sur 64 × 80 studs : un petit stand, sa vitrine, l'emplacement du tapis et du banc. Ajoute tous les points du contrat 10.4, y compris ceux prévus pour la Partie 2 : `Window`, `WindowFractured`, `Shutter`, `ShutterButton`, `DisplaySlot_01` à `_20`, `VaultSlot_01` à `_03`, `UnboxBench_01` à `_04`, `TrapSlot_01` à `_04`, `CashPad`, `DepositZone`, `NameSign`, `Bounds`. Tags `PlayerPlot` et `CashPad`.

- **Fini quand** : routine de livraison passée ; les points de la Partie 2 sont là, même s'ils ne servent pas encore.

### Étape 7 · MOD-016 et MOD-017 · Tapis, banc et vigile de la zone 1

- **Consigne** :

  > Modélise un tapis de course et un banc de musculation, 3 000 triangles maximum chacun, avec un attachment `UsePoint` où se place le perso, et une surface `Belt` sur le tapis. Tags `Treadmill` et `Bench`. Puis modélise une casquette et un gilet de vigile de supérette en Accessory R15 (`HatAttachment`, `BodyFrontAttachment`), 1 000 triangles maximum chacun, nommés `ACC_Z1_Casquette` et `ACC_Z1_Gilet`.

- **Fini quand** : un rig R15 debout sur `UsePoint` est bien placé, et le vigile habillé a l'air d'un vigile.

### Étape 8 · MOD-014 · Les 6 objets de la zone 1

- **Consigne** :

  > Modélise les 6 objets de la zone 1 dans le style de la planche : Canette de soda (Commun), Paquet de chips (Peu commun), Pot de nouilles (Rare), Boisson énergisante (Épique), Ticket à gratter gagnant (Légendaire), Hot-dog en or (Mythique). Budgets : 2 000 triangles, 4 000 pour Légendaire et Mythique. Dans Studio, chacun a une PrimaryPart `Root` au pivot et un attribut `ItemId` (`Z1_Canette`, etc.). Sépare en pièces ce qui doit bouger dans l'animation idle des 2 plus rares.

- **Fini quand** : les 6 objets passent la routine et se reconnaissent à 40 studs.

### Étape 9 · UI-001 · Premiers écrans gris

- **Consigne** :

  > Dans StarterGui, construis en gris, sans aucun style, `UI_HUD` et `UI_Unbox` avec exactement les éléments du contrat 2.2. Dans `ReplicatedStorage/Assets/UI`, crée les billboards `BB_WindowHP`, `BB_OpenTimer`, `BB_Item` et `BB_Carry`. Tailles en Scale, `UIAspectRatioConstraint`, boutons d'au moins 44 px sur téléphone, aucun script. Lance ensuite un test et lis-moi la sortie du ContractChecker.

- **Fini quand** : zéro erreur du ContractChecker. Ironix peut brancher (DEV-021).

**Point de fin M1** : un joueur fait toute la boucle en zone 1 avec tes vrais modèles.

## M2 · du 23 novembre au 10 décembre

### Étape 10 · MOD-020 à MOD-024 · Magasins des zones 2 à 6

Un magasin par zone, puis sa variante (même structure, autre enseigne et autres couleurs). On part de la Supérette pour garder le contrat.

- **Consigne** (à refaire pour chaque zone) :

  > Duplique `STORE_Z1_Superette` en `STORE_Z<N>_<Nom>` et transforme-le en <thème : magasin de jouets / électronique / bijouterie / galerie d'art / banque>. Garde tous les enfants du contrat, mets l'attribut `Zone = <N>`, vérifie les budgets. Puis crée la variante `STORE_Z<N>_<Variante>` : même structure, autre enseigne et autres couleurs.

- **Ordre** : zones 2, 3, 4, puis 5 et 6 (à finir avant le go / no-go du 6 décembre).

### Étape 11 · MOD-025 et MOD-027 · Vitres S et L, outils et batte

- **Consigne** :

  > Refais la vitre comme `WIN_M` en taille S (8 × 6) et L (16 × 8), versions intacte et fracturée. Puis modélise les outils `TOOL_CleAMolette`, `TOOL_PiedDeBiche`, `TOOL_Marteau`, `TOOL_Masse`, `TOOL_HacheIncendie`, `TOOL_Disqueuse` et la batte `TOOL_Batte` : 1 500 triangles maximum, une pièce `Handle` et un attachment `HitPoint` à la tête de l'outil.

### Étape 12 · MOD-026 · Les 30 objets des zones 2 à 6

Par lots de 6, une zone à la fois (liste complète en section 10.5).

- **Consigne** :

  > Modélise les 6 objets de la zone <N> listés en section 10.5, avec les mêmes règles que pour la zone 1 (Root, ItemId, budgets, pièces séparées pour l'idle des plus rares).

### Étape 13 · MOD-028 et MOD-029 · Couloir et zone safe

- **Consigne** :

  > Habille le couloir sur la greybox d'Ironix sans changer les distances : route, trottoirs, lampadaires, voitures garées, arbres, et une arche par zone avec le tag `ZoneGate` et l'attribut `Zone`. Pour le petit décor, cherche des modèles gratuits du Creator Store, et supprime tout script dedans avant de les garder. Puis la zone safe : sol, arche SAFE (tag `SafeZone`), boutique d'armes (tag `WeaponShop`), boutique d'auras (tag `AuraShop`), comptoir Robux (tag `RobuxShop`), receleur.

### Étape 14 · MOD-045, UI-002 et UI-003 · Auras, trails et écrans des boutiques

- **Consigne** :

  > Crée les textures des 6 auras (Étincelle, Flamme, Foudre, Plasma, Galaxie, Royale) et des 5 trails (Poussière, Vent, Turbo, Comète, Hyperespace) : PNG 256 × 256 sur fond transparent, nommés `FX_Aura_<Nom>` et `FX_Trail_<Nom>`, une couleur principale par palier. Puis construis en gris `UI_WeaponShop` et `UI_AuraShop` (2 onglets) selon le contrat 2.2.

### Étape 15 · MOD-018 et MOD-030 · Si tu as le temps

La variante Kiosque de la zone 1 et les accessoires de vigile des zones 2 à 6.

**Go / no-go du 6 décembre** : si les magasins des zones 5 et 6 ne sont pas prêts, on lance avec 4 zones et on les ajoute le 26 décembre.

## M3 · du 30 novembre au 10 décembre

### Étape 16 · MOD-032 · La nuit

- **Consigne** :

  > Modélise le mur de nuit qui monte du sol à l'entrée du couloir, en 2 états (baissé, levé), avec le tag `NightWall`. Habille les vigiles de nuit : lampe torche et casquette. Place 2 points de ronde par zone avec le tag `NightPatrol`. Donne aux lampadaires une partie lumineuse que le code pourra allumer la nuit.

### Étape 17 · UI-005, UI-006 et MOD-031 · Alerte de vol, tuto et premier Secret

- **Consigne** :

  > Construis en gris `UI_TheftAlert` (bannière lisible en une demi-seconde, flèche vers le voleur) et `UI_Tutorial` (bulle de 8 mots maximum, bouton Suivant) selon le contrat 2.2. Puis modélise le Secret « Chat porte-bonheur doré », 4 000 triangles maximum, avec une patte séparée pour l'animer.

## M4 · du 1er au 13 décembre

### Étape 18 · UI-007, UI-004 et UI-008 · Habillage final de l'UI

- **Consigne** :

  > Habille tous les écrans MVP avec le style de la planche MOD-002, sans renommer ni déplacer aucun élément du contrat. Soigne particulièrement `UI_Unbox` en suivant le storyboard de la section 5.7 et nos vidéos de référence. Puis les billboards finaux, lisibles à 40 studs. Vérifie le rendu sur un écran de téléphone et lance le ContractChecker.

### Étape 19 · MOD-040 · Icônes des 37 objets

- **Consigne** :

  > Pour chaque objet `ITM_*`, fais un rendu Blender 512 × 512 sur fond transparent : caméra de trois quarts face, même lumière et même cadrage pour tous. Enregistre-les sous `/Art/Icons/<ItemId>.png`.

### Étape 20 · MOD-041 et MOD-043 · Particules, icône et miniatures

- **Consigne** :

  > Crée les textures de particules en PNG 256 × 256 transparent : éclats de verre, étincelles, confettis, rayons de révélation, et les halos des 7 raretés. Puis propose 3 compositions de miniatures 1920 × 1080 avec la casse de vitrine en vedette, et une icône 512 × 512 lisible en tout petit.

**Gel du 13 décembre** : plus aucune nouveauté, seulement des corrections jusqu'au lancement du 18.

## Piste « Animations » (en parallèle)

Toutes les animations suivent le contrat de la section 2.4 du doc partagé (le même que la section 3.2 de la [liaison](../Liaison-Code-Visuel.md)) : 20 animations, avec leur boucle, leur priorité et leurs marqueurs. **C'est toi qui animes dans l'éditeur d'animation de Studio** ; Claude prépare, découpe et vérifie, mais ne peut pas animer à ta place.

- **Joueur** : objets `Animation` dans `ReplicatedStorage/Assets/Animations/Player/`.
- **Vigiles et vendeurs** : dans le modèle lui-même, `<Modèle>/Animations/`. Le modèle n'a besoin d'aucun script : un Humanoid avec un `Animator`, plus son dossier `Animations`, suffit. C'est le code d'Ironix qui fait marcher, courir et attraper le vigile en jouant ces animations.
- **Publication** : au nom du groupe du studio, jamais depuis ton compte perso, sinon l'animation ne se joue pas dans le jeu. Chaque animation publiée va dans le registre de la liaison (nom, emplacement, ID).

### Étape A1 · ANI-001 · Rig et animation test (M0)

- **Consigne** :

  > Dans la place DEV, ajoute un rig R15 standard nommé `Rig_Player` dans `ServerStorage/AnimRigs`, et un deuxième nommé `Rig_Guard` habillé avec les accessoires du vigile de la zone 1. Crée le dossier `ReplicatedStorage/Assets/Animations/Player`.

- **Toi** : anime un geste test d'une seconde sur `Rig_Player`, ajoute un marqueur `Test`, puis publie-le au nom du groupe.
- **Consigne** :

  > Crée l'objet `Test` dans `ServerStorage/AnimRigs` avec l'identifiant `<ID>`, puis pendant un test, joue-la sur mon personnage pour vérifier qu'elle se lance bien dans le jeu. Ajoute la ligne au registre de la liaison.

  `Test` ne va pas dans `Assets/Animations/Player` : le ContractChecker y signale en rouge tout nom hors du contrat 2.4. Ce dossier ne reçoit que les 13 animations du contrat.

- **Fini quand** : l'animation test se joue en jeu. Ironix peut faire DEV-006 dessus.

### Étape A2 · ANI-010, ANI-011 et ANI-012 · Braquage, base et vigile de jour (M1)

- **Joueur** : `HitWindow`, `HitWindowHeavy`, `Grab`, `CarryIdle`, `CarryRun`, `Place`, `TreadmillRun`, `BenchLift`, `Unbox`.
- **Vigile de jour** (dans son modèle) : `Idle`, `Walk`, `Run`, `Catch`, `Tired`.
- **Avant d'animer** :

  > Pour `<Nom>`, propose-moi un découpage d'après la section 2.4 : les poses clés, la durée totale, la priorité, la boucle, et à quelle image poser le marqueur.

- **Toi** : tu animes, tu règles priorité, boucle et marqueurs, tu publies au nom du groupe.
- **Après publication** :

  > Crée ou mets à jour ces objets `Animation` : `<emplacement>/<Nom>` = `<ID>`, … Vérifie chacun contre le tableau 2.4 (nom, priorité, boucle, marqueurs), puis ajoute-les au registre de la liaison.

- **Fini quand** : `CarryIdle` et `CarryRun` restent fluides, et les marqueurs tombent au bon moment quand Ironix y branche les sons.

### Étape A3 · ANI-020 et ANI-021 · PvP, vigile de nuit et vendeurs (M3)

- **Joueur** : `SwingBat`, `Stunned`, `Knockback`.
- **Vigile de nuit** (dans son modèle, mêmes 5 noms que le vigile de jour, avec la lampe torche) et **vendeurs** (`Idle`, `Wave`).
- Même méthode qu'à l'étape A2.
- **Fini quand** : un coup de batte se lit en une demi-seconde, et la lampe torche reste bien en main dans toutes les poses.

### Étape A4 · ANI-030 · Célébration et finition (M4)

- **Consigne** :

  > Pendant un test, joue toutes les animations l'une après l'autre sur mon personnage, sur un vigile et sur un vendeur, et signale celles qui glissent, qui se coupent mal ou dont la boucle saute.

- **Toi** : tu animes `Celebrate`, puis tu corriges ce qui a été signalé.
- **Fini quand** : validé en playtest à deux.

## Consignes utiles à tout moment

> Quelles tâches du backlog de Clément (Partie 1, section 13) n'attendent plus rien ?

> Fais l'état des lieux de `_INBOX_CLEMENT` par rapport au contrat.

> Compte les triangles de tous les modèles de `ReplicatedStorage/Assets` et signale ceux qui dépassent le budget.

> Liste tous les modèles qui n'ont pas leur tag ou un attribut obligatoire.
