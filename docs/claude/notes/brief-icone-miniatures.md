# Brief de l'icône et des miniatures (MOD-043, 2026-11-14)

**Tâche** : MOD-043, « Icône du jeu + 3 miniatures ». **Fini quand** : icône 512 × 512, miniatures 1920 × 1080, la
casse de vitrine en vedette. **Dépend de** : MOD-012. **Bloque** : DEV-063 (publication PROD). Propriétaire : Clément.

**À livrer avant le 18/12/2026**, et en pratique **envoyées sur le Creator Hub au plus tard le 14 ou le 15 décembre** :
Roblox modère chaque image avant de l'afficher (2 à 3 jours de marge, `publication-prod.md`, section 4).

Le backlog demande 3 miniatures. Ce brief en propose 6 (celles de `publication-prod.md`) : **les 3 premières de
l'ordre de passage font le MVP de MOD-043**, les 3 autres se font si le temps le permet (Roblox en accepte 10).

Sources lues : CLAUDE.md, `publication-prod.md` (tailles et textes), Partie 1 (sections 1, 4, 5.4 à 5.7, 5.12, 6, 7.3,
10.1 et 10.6), `ui-reference-*.md`, `Config/Zones`, `Items`, `Rarities`, `Tools`. Textes affichés en anglais, comme le
jeu. Aucune valeur de jeu n'est inventée ici : objets, outils et couleurs viennent du code ou de la planche MOD-002.

---

## 0. Ce qu'on reprend du genre (principes, rien d'autre)

Les icônes et miniatures qui marchent sur Roblox, « Steal a … » compris, tiennent sur peu de règles. On reprend ces
principes, **jamais un visuel, un nom, un personnage ni une mise en page d'un autre jeu** (Partie 1, règle de propriété
intellectuelle).

1. **Un seul sujet, une seule action** : on doit comprendre le jeu en une demi-seconde, sur un téléphone, dans une
   grille de dizaines d'autres tuiles. Une scène chargée se lit comme du bruit.
2. **Un personnage en pleine action**, pas une pose immobile : un geste (frapper, courir) vend mieux qu'un décor.
3. **Silhouette forte** : sujet très contrasté contre un fond simple ; c'est la silhouette qui reste lisible en petit.
4. **Couleurs saturées et contour sombre** : le « mode studs » du jeu s'y prête déjà (palette 10.6).
5. **Montrer ce qu'on fait vraiment dans le jeu** : c'est une règle de Roblox (section 3) et c'est aussi ce qui retient
   le joueur après le clic.
6. **Tester plusieurs miniatures** : Roblox choisit seul la miniature qui retient le mieux les joueurs (personnalisation
   des miniatures, Creator Hub). D'où l'intérêt d'en avoir 5 ou 6 nettement différentes, et non 6 variantes de la même.
   Il n'y a pas d'équivalent pour l'icône : elle doit être juste du premier coup.

---

## 1. Icône (512 × 512, lisible à 150 px)

**Format** : carré 512 × 512 px, PNG (ou JPG). Une seule icône. **Pas de texte** : le titre « Steal a Shop » s'affiche
déjà sous la tuile, et un mot ne se lit pas à 150 px. **Aucun bord important** : Roblox arrondit les coins de la tuile,
garder le sujet dans le cercle central d'environ 440 px.

**Commun aux 3 idées** :

- Capture dans Studio (vrais modèles du jeu), puis retouche permise : recadrage, fond, contour, lumière, flou. Pas de
  dessin qui montre autre chose que le jeu.
- Personnage : un avatar R15 de l'équipe, habillé d'accessoires libres ou du groupe. Jamais l'avatar d'un joueur connu
  ni un personnage d'un autre jeu. Visage Roblox expressif (bouche ouverte, sourcils levés) si un visage gratuit le
  permet.
- Contour sombre `#1B1B24` d'environ 8 à 10 px autour du sujet principal (comme l'UI), pour le détacher du fond.
- Rendu avec l'éclairage de jour du jeu, contraste et saturation poussés d'environ 10 à 15 %, pas plus (l'image doit
  rester le jeu).

### Idée A · « La casse » (recommandée)

- **Cadrage** : plan rapproché, en légère contre-plongée. Le personnage occupe la moitié gauche, de la taille au haut de
  la tête, tourné de trois quarts vers la droite, **la masse (`TOOL_Masse`) levée en arrière**, juste avant ou à
  l'instant de l'impact. La moitié droite : la **vitrine de la Bijouterie (zone 4) en train d'exploser** depuis le point
  d'impact, éclats et petits cubes de verre bleu clair projetés vers le spectateur.
- **Derrière la vitre** : la **Couronne (`ITM_Z4_Couronne`, Légendaire)** sur son présentoir, avec ses **rayons dorés**
  `#FFC21A`. C'est le seul objet de l'image.
- **Couleurs** : fond bleu ciel `#8FD0FF` qui fonce vers les bords (vignette), ou rayons bleus `#2F9BFF` derrière la
  couronne ; verre bleu très clair avec reflets blancs ; or `#FFC21A` de la couronne, qui est le point le plus lumineux
  de l'image.
- **Ce qui doit se lire à 150 px** : 1) une silhouette qui frappe, 2) une explosion de verre, 3) un point doré derrière.
  Rien d'autre. Le décor de la rue disparaît dans le flou ou la vignette.
- **Pourquoi** : c'est le moment signature du jeu (Partie 1, section 1 : « la casse … c'est le moment signature »),
  exigé par MOD-043 (« la casse de vitrine en vedette »), et la masse comme la couronne existent bien en zone 4 : la
  scène est jouable telle quelle.
- **Mise en place** : place DEV, Bijouterie de la zone 4, caméra à environ 6 studs du personnage. Pour figer les éclats,
  lancer une casse en Play (outil admin pour la masse et les dégâts) et capturer pendant l'arrêt sur image de 60 ms, ou
  poser à la main les `Shard_01` à `Shard_40` de `WindowFractured` dans une copie de la vitrine en mode édition.

### Idée B · « La fuite »

- **Cadrage** : le personnage court **vers la caméra**, cadré des genoux à la tête, légèrement décentré à gauche. Au-dessus
  de sa tête, **l'objet volé** (sorti du colis ouvert sur le rayon) avec son halo de rareté (Légendaire, or, rayons).
  Derrière lui, à droite et plus petit, le **vigile** (R15, casquette, matraque cartoon) qui tend le bras.
- **Couleurs** : route `#4E5560` et façades floues derrière ; objet or `#FFC21A` en haut de l'image, contre le ciel
  `#8FD0FF` ; gilet du vigile dans sa couleur de jeu.
- **Ce qui doit se lire** : un personnage qui fuit, un objet qui brille, quelqu'un qui le poursuit.
- **Pour / contre** : dit la poursuite et la tension, mais à 150 px le vigile devient une tache ; la casse, plus
  originale, disparaît. Bonne idée de **miniature** (scène 2), moins bonne d'icône.

### Idée C · « Le trésor derrière la vitre »

- **Cadrage** : gros plan frontal sur **un objet rare derrière une vitrine fissurée**. Le **Chat porte-bonheur doré**
  (`Secret_ChatPorteBonheurDore`, Secret) au centre, halo arc-en-ciel (`#FF3B3B` → `#FFC21A` → `#3BE15A` → `#2F9BFF` →
  `#A855F7`). Au premier plan, en bas à gauche, **le poing ou la masse** qui entre dans le cadre et touche la vitre ;
  fissures et premiers éclats qui partent du point d'impact.
- **Couleurs** : fond sombre `#2C2163` (violet nuit de l'UI) pour faire briller l'arc-en-ciel ; verre bleu clair.
- **Ce qui doit se lire** : un objet précieux qui brille, et une vitre qu'on casse pour l'avoir.
- **Pour / contre** : très lisible et coloré ; mais le personnage est absent (on perd l'action) et un Secret à 0,2 % des
  colis Luxe vend un moment rare comme s'il était courant. À garder en icône de secours, ou pour une icône
  d'événement plus tard.

**Recommandation : idée A.** Faire aussi un brouillon rapide de B pour comparer les deux côte à côte à 150 px (section 4).

---

## 2. Miniatures (1920 × 1080, 16:9)

**Format** : 1920 × 1080 px exactement (un autre ratio est étiré), PNG ou JPG, moins de 3 Mo.

**Zones de l'image** :

- **Bas** : la bande inférieure (environ 20 %, soit les 216 px du bas) est couverte par le nombre de joueurs et les
  boutons de la page : **ni texte, ni visage, ni objet important**. Y mettre le sol, la route, des éclats.
- **Texte** : en haut ou au milieu, 2 à 4 mots, **en Montserrat Black blanc, contour noir `#1B1B24` épais** (comme
  l'UI, `UIStroke` 3,7 mis à l'échelle : environ 10 à 14 px à cette taille) et ombre dure dessous. Hauteur des lettres :
  **au moins 110 px** (environ 10 % de la hauteur), pour rester lisible sur une carte de téléphone. Un seul bloc de texte
  par image, jamais au-dessus du visage du personnage.
- **Sujet** : un seul centre d'intérêt, placé sur un tiers (gauche ou droit), l'autre tiers pour le texte.

**Mise en scène commune** : vraies captures de Studio (mode Play, ou mode édition avec les modèles du jeu), HUD masqué
(sauf scène 3 où l'étiquette $/s du monde fait partie du jeu), un ou deux avatars de l'équipe, retouche légère permise
(recadrage, lumière, flou de profondeur, contour du sujet). Utiliser les vrais effets du jeu (halos, éclats, rayons) :
pas d'effet peint qui n'existe pas en jeu.

### Ordre de passage

| Ordre | Scène | Texte | Lot |
| --- | --- | --- | --- |
| 1 | La casse | **SMASH & GRAB!** | MVP de MOD-043 |
| 2 | La poursuite | **OUTRUN THE GUARD** | MVP de MOD-043 |
| 3 | La boutique pleine | **BUILD THE RICHEST SHOP** | MVP de MOD-043 |
| 4 | Le vol entre joueurs | **STEAL FROM PLAYERS** | Si le temps le permet |
| 5 | La nuit | **NIGHT HEISTS** | Si le temps le permet |
| 6 | L'ouverture du colis | **FIND SECRET ITEMS** | Si le temps le permet |
| Samedi | Nouveauté de la semaine | **NEW UPDATE!** | Après le lancement, le jour de la MAJ seulement |

La première est celle de la page du jeu au lancement ; la personnalisation de Roblox réordonnera ensuite selon les
résultats. Les textes sont ceux de `publication-prod.md` (section 1), à garder identiques pour que la page reste
cohérente.

### Scène 1 · La casse (principale) · « SMASH & GRAB! »

- **Où** : zone 4, Bijouterie (`STORE_Z4_Bijouterie`), de jour.
- **Mise en scène** : le personnage à gauche (tiers gauche), de profil trois quarts, **masse en fin de coup** ; la
  vitrine qui éclate en grand au centre-droit, les 30 à 40 éclats en l'air depuis le point d'impact, paillettes de
  verre ; derrière, les rayons visibles et un présentoir avec la **Couronne** et ses rayons dorés. Flash blanc léger au
  point d'impact (le jeu fait un flash de 80 ms à la casse : il existe vraiment).
- **Lumière** : jour, soleil de côté pour faire briller le verre ; intérieur du magasin un peu plus chaud que la rue.
- **Texte** : « SMASH & GRAB! » en haut à droite, au-dessus de la vitrine.
- **Bas** : sol de la rue et éclats retombés.

### Scène 2 · La poursuite · « OUTRUN THE GUARD »

- **Où** : le couloir, sortie de la zone 3 (Électronique ou Jeux vidéo, Tokyo), vers la zone safe ; de jour.
- **Mise en scène** : caméra basse devant le joueur qui court vers elle (tiers gauche), **l'objet volé au-dessus de la
  tête** (sorti du colis ouvert sur le rayon, CLAUDE.md), par exemple le **PC gamer** (`ITM_Z3_PcGamer`, Légendaire) avec
  son halo (or, rayons) et son étiquette de rareté visible ; le **vigile**
  à 3 ou 4 studs derrière, bras tendu, matraque cartoon. Trail du joueur visible (un vrai trail de la boutique, par
  exemple Vent ou Turbo). Rideau métallique en train de tomber au fond si possible.
- **Lumière** : jour, ciel `#8FD0FF`, enseignes de Tokyo allumées pour la couleur.
- **Texte** : « OUTRUN THE GUARD » en haut à droite.
- **Bas** : route `#4E5560` avec ses flèches blanches.

### Scène 3 · La boutique pleine · « BUILD THE RICHEST SHOP »

- **Où** : une parcelle `PlayerPlot` de la zone safe, de jour.
- **Mise en scène** : vue de trois quarts en hauteur sur la boutique d'un joueur **remplie d'objets exposés**, de raretés
  variées et lisibles (beaucoup de Rare, Épique et Légendaire avec leurs halos ; un Mythique au centre). Leurs étiquettes
  $/s flottantes (vrais billboards du jeu) au-dessus. Le joueur au premier plan, de dos ou de trois quarts, qui
  contemple. Tapis et banc dorés visibles sur un côté s'ils existent.
- **Lumière** : jour, lumière douce et chaude ; halos bien visibles (léger assombrissement global accepté pour les faire
  ressortir).
- **Texte** : « BUILD THE RICHEST SHOP » en haut, centré ou à gauche.
- **Attention** : les montants affichés doivent être des valeurs réellement atteignables (une vraie partie avancée, ou
  un profil de test réglé avec l'outil admin sur des valeurs du jeu). Aucun chiffre ajouté à la retouche.

### Scène 4 · Le vol entre joueurs · « STEAL FROM PLAYERS »

- **Où** : la zone safe, entre deux parcelles, de jour.
- **Mise en scène** : le **voleur** (tiers droit) qui s'enfuit, l'objet volé flottant au-dessus de sa tête avec son
  halo, son étiquette et le **contour rouge** visible par tous (section 6.1) ; la **victime** (tiers gauche) qui arrive
  en courant, **batte levée**. La vitrine de la boutique volée cassée au fond.
- **Deux avatars** différents et reconnaissables (couleurs de tenue opposées : un en bleu, un en rouge, par exemple).
- **Lumière** : jour.
- **Texte** : « STEAL FROM PLAYERS » en haut, au centre, entre les deux personnages.
- **Attention** : la batte est cartoon, le coup reste léger : pas de joueur à terre au premier plan.

### Scène 5 · La nuit · « NIGHT HEISTS »

- **Où** : le couloir de nuit, zone 5 (Paris : Galerie d'art, Antiquaire) ou zone 6 (New York : Banque).
- **Mise en scène** : un joueur caché contre une façade, l'objet volé au-dessus de la tête (halo **Mythique**
  rouge rose `#FF3B5C`, par exemple la Météorite `ITM_Z5_Meteorite`, ou un Épique violet) ; au milieu de la rue, un **vigile de nuit** avec sa **lampe torche** dont le cône balaie
  le sol vers lui. Au fond, le **mur de nuit** (`NightWall`) levé.
- **Lumière** : nuit du jeu (`Lighting.ClockTime` de nuit), lampadaires allumés, cône de torche blanc chaud ; le halo de
  l'objet est la deuxième source de lumière de l'image.
- **À vérifier avant** : qu'un joueur peut bien rester dans le couloir la nuit avec un objet (il y était avant la tombée
  de la nuit, section 5.12) ; sinon, cadrer l'alerte des 30 dernières secondes (ciel qui rougit).
- **Texte** : « NIGHT HEISTS » en haut à gauche, sur le ciel sombre.
- **Attention** : rester dans le ton de la poursuite, pas de l'horreur (questionnaire : « Peur : Non »). Pas de visage
  menaçant en gros plan, pas de rouge sang.

### Scène 6 · L'ouverture du colis · « FIND SECRET ITEMS »

- **Où** : le rayon d'un magasin PNJ (zone 6, Salle des coffres, colis Luxe), de jour : depuis L-112
  (`Features.ShelfOpen`), le colis s'ouvre **sur le rayon** et l'objet sort à sa place.
- **Mise en scène** : l'instant de la sortie : rabats levés, lumière qui sort du colis, texte vert « ×N LUCK » au-dessus
  (vrai texte du jeu, avec la valeur réellement affichée), et le **Chat porte-bonheur doré** (Secret) dans son halo
  arc-en-ciel au centre de l'image. Le joueur à gauche, bras levés (animation `Celebrate` si elle est publiée).
- **Lumière** : intérieur du magasin un peu assombri, toute la lumière sur le colis et l'objet.
- **Capture** : un Secret est rare (0,2 % des colis Luxe) ; le forcer avec un outil admin en Studio est permis, l'objet
  et l'effet étant ceux du jeu. Demander à Ironix quelle commande admin le force.
- **Texte** : « FIND SECRET ITEMS » en haut, centré.
- **Attention** : ne rien écrire qui fasse croire que le Secret est facile (pas de « 100% », pas de « EVERY BOX »). Les
  vrais textes en jeu (rareté, nom, $/s, « ×N LUCK ») peuvent rester.

### Miniature du samedi · « NEW UPDATE! »

Même format ; la nouveauté de la semaine en vedette (nouvelle zone, nouvel objet, événement), avec le texte « NEW
UPDATE! » en haut. **La remplacer ou la retirer dès que la mise à jour n'est plus nouvelle** (une semaine au plus) :
laisser « NEW UPDATE! » sur une vieille mise à jour devient un texte trompeur.

---

## 3. Règles à respecter

### Roblox (doc officielle, relue le 2026-11-14 pour `publication-prod.md`)

1. **Vrai jeu** : l'icône et les miniatures montrent ce qu'on fait vraiment dans le jeu. Retouche, recadrage et effets
   permis ; montrer un lieu, un objet, une mécanique ou un personnage absents du jeu est interdit (métadonnées
   trompeuses = spam dans les règles de conduite, modération possible).
2. **Pas de texte trompeur** : pas de prix, de promesse ou de classement (« FREE ROBUX », « #1 GAME », « 50% OFF »,
   « 1M VISITS ») ; pas de « NEW UPDATE! » hors de la semaine de mise à jour.
3. **Rien d'autre que nous** : aucun nom, logo, personnage, avatar ou capture d'un autre jeu ou d'une marque ; aucune
   image réelle (photo, personne réelle) ; aucun logo Roblox détourné.
4. **Contenu** : cohérent avec la note de maturité visée (Légère) : violence cartoon seulement, pas de sang, pas d'arme
   réaliste, rien d'effrayant ni de suggestif. Les potions ne doivent pas ressembler à de l'alcool.
5. **Format** : icône 512 × 512 ; miniatures 1920 × 1080, moins de 3 Mo, 10 au plus vidéos comprises.
6. **Propriété** : téléversées depuis la page de l'expérience PROD, qui appartient au groupe RoundStone Studio.

### Lisibilité sur téléphone

1. Le jeu vise d'abord le téléphone (Partie 1, section 1) : la tuile y fait environ 150 px de côté pour l'icône, et la
   miniature est petite dans la grille de l'accueil.
2. Un sujet, une action, un fond simple ; contraste fort entre le sujet et le fond.
3. Texte : 2 à 4 mots, lettres d'au moins 110 px de haut sur la miniature, contour noir épais ; jamais de texte sur
   l'icône.
4. Rien d'important dans le bas de la miniature (environ 20 %) ni dans les coins de l'icône.
5. La couleur de rareté dit la valeur : or, rouge rose ou arc-en-ciel doivent être les couleurs les plus lumineuses de
   l'image.

### Liste de contrôle avant envoi

**Icône**

- [ ] 512 × 512 px, PNG ou JPG, une seule.
- [ ] Aucun texte ; sujet dans le cercle central (coins arrondis).
- [ ] Testée **à 150 px et à 64 px** sur un téléphone : on comprend « quelqu'un casse une vitrine pour un objet
      précieux ».
- [ ] Posée dans une **capture de la grille de l'accueil Roblox** (à côté d'autres tuiles) : elle ressort, elle ne se
      confond pas avec le fond.
- [ ] Personnage, outil, vitrine et objet existent tels quels dans le jeu.

**Chaque miniature**

- [ ] 1920 × 1080 px exactement, moins de 3 Mo.
- [ ] Vraie scène du jeu (capture Studio), retouche légère seulement.
- [ ] Rien d'important dans les 216 px du bas.
- [ ] Texte du tableau de la section 2, en anglais, orthographe vérifiée, lisible sur téléphone.
- [ ] Ni prix, ni promesse, ni chiffre inventé, ni nom d'un autre jeu.
- [ ] Ni sang, ni arme réaliste, ni scène effrayante.
- [ ] Les 6 sont nettement différentes (lieu, couleur dominante, action), pour que la personnalisation de Roblox ait de
      vrais choix.

**Avant de téléverser**

- [ ] Fichiers nommés `ICON_StealAShop_v1.png` et `THUMB_01_SmashGrab.png` à `THUMB_06_SecretItems.png` (sans accents
      ni espaces), rangés dans le dossier d'art de Clément.
- [ ] Relues par Ironix (vrai gameplay, textes) : une ligne dans la liaison avec les fichiers et un aperçu.
- [ ] Téléversées sur la page de l'expérience **PROD** au plus tard le 14 ou le 15 décembre, pour laisser la modération
      passer.
- [ ] Après la modération : vérifier sur un téléphone, page du jeu et accueil, que rien n'est coupé ni étiré.
- [ ] MOD-043 passé à « Fait » dans le doc de suivi ; DEV-063 débloqué.

---

## Sources

- Règles Roblox (icônes, miniatures, règles de conduite) : liens de `publication-prod.md`, section « Sources ».
- Personnalisation des miniatures : https://devforum.roblox.com/t/live-now-personalize-your-thumbnails-to-attract-more-users/3257233
- Demande d'un test A/B des icônes (inexistant à ce jour) : https://devforum.roblox.com/t/icon-ab-testing/3274267
- Principes de lisibilité (sujet unique, action, silhouette, test dans la grille) : guides de tiers, par exemple
  https://devforum.roblox.com/t/optimize-ctr-with-icons-and-thumbnails/3316365 ; leurs chiffres de gains ne sont pas
  vérifiés et ne sont pas repris ici.
