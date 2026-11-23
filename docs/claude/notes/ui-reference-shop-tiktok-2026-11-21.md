# Référence « shop qui vit » (TikTok du 2026-11-21) → boutique Robux

Demande de Clément : améliorer l'UI du shop existant pour qu'elle ressemble à la vidéo TikTok https://vm.tiktok.com/ZGdXndfhE/.

- **Vidéo** : envoyée par Clément (WhatsApp), copiée dans `docs/claude/video/references/2026-11-21_ShopTikTok/v.mp4` (576 × 1024, 30 i/s, 63,8 s ; hors Git). Planches et images clés dans `frames/` à côté.
- **Ce que c'est** : une démo d'un plugin Figma → Roblox (« Framewisp »). Une boutique Robux pixel-art arc-en-ciel (« EXCLUSIVE SHOP », carte « Premium Lucky Block », packs de cash) reçoit **7 micro-animations** posées par des tags : `_smooth`, `_jump`, `_spin`, `_gleam`, `_spring`, `_wiggle`, `_fall`. Le plugin n'est pas le sujet : on reprend les 7 **techniques**, pas leur dessin (pixel-art arc-en-ciel, panier rose, lucky block), qui est leur identité.
- **Le shop concerné** : la boutique Robux, `StarterGui/UI_RobuxShop_v2` (la vidéo ne montre qu'une boutique Robux). Pas `UI_WeaponShop` ni `UI_AuraShop`.
- **Maquette de départ** : Figma « Steal a Shop — UI », page `10 Boutiques`, frame « Boutique clément » (node 191:2772), validée et reportée dans Studio (L-243, L-247, L-252). Image : `frames/avant_figma_191-2772.png`.
- **Croisé avec l'autre fiche** : la session « UI d'après le TikTok de référence » a étudié une autre vidéo du même compte, un menu de 4 tuiles ([ui-reference-tiktok-2026-11-21.md](ui-reference-tiktok-2026-11-21.md)). Repris de sa fiche : le saut ou l'inclinaison de l'icône de chaque carte (`_jump`, `_lean`), le reflet au survol sur le titre des cartes (0,8 s) et le nom d'attribut `IconHover`, pour n'avoir qu'un seul contrat. Son grossissement de tuile (× 1,08 en 0,1 s) est déjà couvert par notre `Hover = Pop` (× 1,1 en 0,067 s). Elle ne touche pas à `UI_RobuxShop_v2` : cette fiche-ci est la seule pour cet écran.

## 1. Catalogue des moments

| Temps | Ce qu'on voit |
| --- | --- |
| 0,0 – 4,5 s | La boutique finie en jeu, la caméra glisse de gauche à droite ; texte « THIS ROBLOX SHOP… » |
| 5 – 8,5 s | Zoom sur la boutique, puis sur le bouton cadeau (40 × 40) |
| 9 – 16,5 s | `_smooth` et `_jump` sur le cadeau (panneau de réglages du plugin) |
| 17 – 23 s | `_spin` : rayons blancs derrière le cadenas « 5 % » |
| 24 – 28,5 s | `_gleam` : reflet qui passe sur « PREMIUM LUCKY BLOCK » |
| 29 – 35 s | `_spring` : le lucky block suit le curseur |
| 35 – 41 s | `_wiggle` : le panier du titre se balance |
| 41 – 50 s | `_fall` : des lucky blocks tombent dans la carte arc-en-ciel |
| 50 – 54 s | « Convert to Roblox » |
| 54 – 60 s | Retour à la boutique en jeu, fin |

## 2. Les 7 effets : chez eux → chez nous

Les valeurs « chez eux » sont **lues sur les panneaux de réglages** visibles dans la vidéo (donc exactes) ; les durées non affichées sont comptées image par image (30 i/s) et marquées « estimé ».

| # | Chez eux | Pourquoi ça marche | Chez nous (`UI_RobuxShop_v2`) | Qui |
| --- | --- | --- | --- | --- |
| 1 `smooth` | Bouton qui grossit au survol, s'écrase à l'appui, avec un son | Retour immédiat sous le doigt | **Déjà là** : `Hover = Pop`, `Press = Squash` sur tous les boutons (L-182). On garde | — |
| 2 `jump` | Le cadeau fait un saut complet au survol : hauteur 8 px, pas de rotation, sans délai ; un nouveau survol pendant le saut le relance après l'atterrissage ; il peut sortir du cadre (« Above clipping ») | L'icône répond, pas seulement le bouton : la carte paraît vivante | L'**icône de chaque carte** (`Icon` des `Template` de Gamepasses, Boosts et Cash, une image libre dans la carte) saute au survol, une fois par survol : 6 à 8 % de la hauteur de la carte, montée 0,12 s Quad Out, retombée 0,18 s Back Out avec un petit tassement (valeurs de l'autre fiche). La carte garde son `Hover = Pop` (elle penche de 3°) : les deux couches bougent à part. Variante `Lean` : l'icône s'incline de 8 à 10° et le reste tant que la souris est dessus. **Pas l'icône Robux des boutons de prix** : elle est rangée par le `UIListLayout` de `Content`, qui ignore sa position et sa rotation (doc Roblox) ; le bouton entier grossit déjà | Code (Ironix) |
| 3 `spin` | Rayons blancs (16 branches, dégradé vers transparent) qui tournent sans fin derrière l'objet, lentement (≈ 20°/s, estimé) | Attire l'œil vers la meilleure offre | **Déjà là partout** : `CrateLoop` fait tourner les rayons de la caisse (`Crate.Backdrop.Rays`) et `RobuxShopController` (`collectSpins`) tous les autres `Rays` de l'écran, cartes comprises (`Monetization.Shop.RaysTurn` = −45° toutes les 4 s). Rien à poser ni à coder | — |
| 4 `gleam` | Un reflet blanc traverse le titre de gauche à droite : passage 3 s, pause 2 s, largeur de la bande 0,22 | Le titre « brille » sans clignoter : effet premium | En boucle sur `Crate.ItemName` (« EXCLUSIVE CRATE ») et `Featured.ItemName` (« STARTER PACK ») : passage 3 s (Sine InOut), pause 2 s, bande de 22 %. Une fois par survol sur le titre de chaque carte (`ItemName` des `Template`) : 0,8 s, linéaire, bande ≈ 12 % (valeurs de l'autre fiche). **Technique** : le code pose par-dessus le titre une copie blanche (remplissage et contour blancs), avec un dégradé de transparence qui ne laisse voir qu'une bande penchée d'environ 15°, et fait glisser son `Offset.X` de −1 à 1 ; il recopie le texte si le titre change. **Le contour plus doux que les lettres** : bande à 0,92 sur le remplissage, mais seulement 0,35 sur le contour (`UIGradient` sous le `UIStroke` de la copie), sinon les lettres et leur contour deviennent un seul bloc blanc illisible. Aperçu animé (fait dans Figma et ffmpeg, pas en jeu) : `frames/apercu_reflet_titre.gif` et `.mp4`. Pourquoi pas le `UIGradient` du titre : celui de `Crate.ItemName` est vertical (jaune en haut, orange en bas, `Rotation` 90), une bande qui va de gauche à droite ne peut pas y entrer ; et sur un titre blanc, un reflet blanc ne se voit que sur le contour noir | Code |
| 5 `spring` | Le lucky block grossit un peu au survol et suit le curseur : inclinaison 10°, petit déplacement amorti ; retour souple à la sortie | On a envie de « toucher » la récompense | La caisse 3D suit la souris. Le code balance déjà la caméra de son aperçu (`Crate.Icon.Preview.Camera`, ±12° en 3,5 s, `Monetization.Shop.PreviewSway`) : au survol, l'angle suit le pointeur à la place (10° au plus, ressort amorti), puis le balancement reprend. Pas en bougeant `Crate.Icon` : `CrateLoop` le fait déjà monter, descendre et se secouer. Sur téléphone, seulement pendant le toucher | Code |
| 6 `wiggle` | Le panier du titre se balance de ±12° de temps en temps, puis s'arrête | Une petite vie dans le décor, toutes les quelques secondes | Le marteau du Starter Pack (`Featured.Icon.Hammer`) et les objets suspendus `Decor.Hang1` à `Hang4` (déjà `DropIn`) se balancent de ±12° autour de leur ficelle toutes les 4 s, décalés de 0,7 s l'un de l'autre (Sine, 0,8 s, retour amorti) | Code |
| 7 `fall` | Des copies d'une image tombent **dans** une carte (découpées par la carte) : 12 copies, chute 6 s, transparence 0,75, tailles et vitesses un peu différentes | La carte « déborde » de récompenses | Dans la carte de **Cash** (`CashSection.Grid.Template`) : un cadre `FallLayer` (découpe, derrière l'icône) avec une image invisible `FallItem` (notre billet `UI_Icon_DP_Cash_3`). Pas le nom `Template` : `UiMotionController` traite tout ce qui s'appelle `Template` comme un modèle de liste. Le code en clone 12, qui tombent en 6 s, transparence 0,75 | Clément (visuel) + code |

Sons : la vidéo n'a qu'une musique et une voix continues (pas de silence avant 60,9 s), on ne peut pas isoler de son d'UI. Nos sons restent ceux de `UiFeelController` (`UI_Hover`, `UI_Success`…).

## 3. Ce qui fait « pro » chez eux, et chez nous

- Chez eux : **chaque élément a sa propre petite animation, toujours douce et courte**, et jamais deux grosses animations en même temps. Le style (pixel-art, arc-en-ciel partout) est criard ; on ne le reprend pas.
- Chez nous : la boutique est déjà riche (caisse 3D, rayons, contours de rareté, cartes à motif) mais **presque immobile une fois ouverte** : seuls la caisse et les rayons bougent. C'est là que la vidéo nous dépasse : les icônes des cartes, les titres et le décor ne bougent pas.

## 4. Avant / après proposé

- **Avant** : `frames/avant_studio_haut.jpg`, `frames/avant_studio_gamepasses.jpg` (Studio, Edit, 2026-11-21), `frames/avant_figma_191-2772.png`.
- **Après** : maquette Figma, même fichier, page `10 Boutiques`, frame « Boutique clément — effets (TikTok 2026-11-21) », node 199:4143 (copie de 191:2772, version PC, annotée de 1 à 7 avec une légende). Image : `frames/apres_figma_199-4143.png`. Rien n'a été changé dans la frame d'origine.

## 5. Demande pour Ironix (à reporter dans la liaison par la session principale)

Rien n'est codé dans l'UI (aucun script). Ce qui est **visuel** est posé par Clément dans Studio ; ce qui **bouge** est pour le code (`UiMotionController` / `CrateLoop`). Proposition de contrat, par attribut, comme `Hover` et `Appear` :

1. `IconHover = "Jump"` ou `"Lean"` (nouvel attribut, même nom que dans l'autre fiche) sur une carte : au survol de la carte, son `Icon` saute (6 à 8 % de la hauteur de la carte, 0,12 s Quad Out puis 0,18 s Back Out, une fois par survol ; un survol pendant le saut est rejoué après l'atterrissage) ou s'incline (8 à 10°, 0,1 s Back Out, tant que la souris reste). En plus de `Hover = Pop`, qui ne change pas. À poser sur les 3 `Template`.
2. Rayons qui tournent : **rien à faire**, c'est déjà en jeu (`collectSpins`, cartes comprises).
3. `Gleam = "Loop"` ou `"Hover"` (nouvel attribut) sur un `TextLabel` : reflet fait par une copie blanche posée par-dessus par le code (voir l'effet 4 ci-dessus), à 0,92 sur les lettres et 0,35 sur le contour ; bande de 22 % de la largeur du titre (`Loop`) ou 12 % (`Hover`), forme douce (cosinus), penchée de 15°. **Aspect validé par Clément le 2026-11-21** sur l'aperçu animé (`frames/apercu_reflet_titre.gif` : vitesse, largeur et force). `Loop` : passage 3 s Sine InOut, pause 2 s, tant que l'écran est ouvert (`Crate.ItemName`, `Featured.ItemName`). `Hover` : un passage de 0,8 s, linéaire, au survol de la carte (`ItemName` des 3 `Template`).
4. `IconHover = "Spring"` sur `Crate` : pendant le survol, la caméra de `Icon.Preview` suit le pointeur (10° au plus, ressort amorti) à la place du balancement `PreviewSway` ; retour en 0,35 s (Back Out) au balancement à la sortie. `Crate.Icon` reste à `CrateLoop`.
5. `Idle = "Wiggle"` sur `Featured.Icon.Hammer` et sur `Decor.Hang1` à `Hang4` : ±12°, 0,8 s, toutes les 4 s, décalés de 0,7 s ; après le `DropIn`. Le `Decor` est déjà caché sur téléphone par `CrateLoop`.
6. `Idle = "Fall"` sur un cadre `FallLayer` (`ClipsDescendants`) qui contient une image invisible `FallItem` : 12 copies, chute 6 s, transparence 0,75, tailles 70 à 110 %, vitesses ± 15 %. Dans les cartes clonées, `FallItem` porte l'image du `Template` (un billet) : tu peux y recopier celle de l'`Icon` de chaque carte, comme pour `Clip.Watermark`.
7. Tout s'arrête quand l'écran se ferme, et rien ne bouge avec « animations réduites » (`Appear.Reduced`).

Tant que ce n'est pas codé, ces attributs ne font rien en jeu : `FallItem` reste invisible et les titres, icônes et rayons restent immobiles.

## 6. Questions pour Clément

1. On ne garde que les **effets** (notre style actuel ne change pas) : d'accord, ou veux-tu aussi un peu de leur look (bordure arc-en-ciel qui tourne autour de la caisse, par exemple) ?
2. Où tombent les billets (`fall`) : seulement dans les cartes Cash, ou aussi dans le Starter Pack ?
3. Les icônes des cartes : toutes sautent (proposé), ou on mélange avec l'inclinaison, comme dans l'autre vidéo (une icône sur quatre s'incline) ?
4. Le reflet des titres de cartes : au survol seulement (proposé), ou aussi tout seul de temps en temps ?

## 7. Intégration (après accord)

Accord de Clément le 2026-11-21 (« Oui, intègre »). Place DEV, **rien enregistré, rien publié, rien commité**.

- **Sauvegarde** : `ServerStorage/MapBackups/2026-11-21_Shop/UI_RobuxShop_v2` (copie de l'écran juste avant).
- **Script** : [tools/clement/ui_shop_tiktok.luau](../../../tools/clement/ui_shop_tiktok.luau), lancé une fois en Edit (une étape d'annulation, peut se relancer).
- **Ce qui a changé** dans `StarterGui/UI_RobuxShop_v2` : 40 attributs et 12 éléments nouveaux. **Aucun nom changé, rien déplacé ni supprimé, aucun script** (vérifié en comparant tout l'écran à la sauvegarde : 0 élément manquant, 0 classe changée, 0 visibilité changée).
  - `IconHover = "Jump"` sur les 16 cartes (le `Template` et les `Preview_*` des 3 sections) ; `Gleam = "Hover"` sur leur `ItemName`.
  - `IconHover = "Spring"` sur `Root.Window.List.Content.Crate` ; `Gleam = "Loop"` sur `Crate.ItemName` et `Featured.ItemName`.
  - `Idle = "Wiggle"` sur `Featured.Icon.Hammer` et `Root.Decor.Hang1` à `Hang4`.
  - Dans les 4 cartes Cash (`CashSection.Grid.Template` et `Preview_1` à `_3`) : `FallLayer` (`Frame` transparent, `ClipsDescendants`, même taille et place que `Clip`, ZIndex 340 entre les rayons et l'icône, `Idle = "Fall"`), avec `FallItem` (`ImageLabel` invisible, le billet de la carte, transparence 0,75, ZIndex 341, `UIAspectRatioConstraint`).
- **Vu en Play par Claude le 2026-11-21** (Play court, boutique ouverte par le bouton Shop du HUD) : la copie du joueur a 5 cartes Gamepasses, 3 Boosts et 6 Cash, toutes avec `IconHover = "Jump"` ; les 6 cartes Cash ont leur `FallLayer`, avec un `FallItem` invisible ; les `Preview_*` sont bien retirées par le code. À l'écran, rien ne change, comme prévu tant que les effets ne sont pas codés. Sur ce compte, la caisse et le Starter Pack sont cachés par le code : les effets `Spring`, `Wiggle` et `Gleam = "Loop"` ne se verront que là où ces blocs s'affichent.
  - Captures : `frames/apres_play_pc_gamepasses.jpg`, `frames/apres_play_pc_cash.jpg`, `frames/apres_play_iphone17pro_cash.jpg` (émulation iPhone 17 Pro, 874 × 402 : la boutique tient dans l'écran, rien ne déborde).
  - ContractChecker : aucune ligne rouge. Bilan « 1 problème(s) · 69 avertissement(s) · 14 point(s) pas encore livré(s) ». Le seul « problème » est un avertissement orange : « `UI_RobuxShop_v2.Crate.Icon` : 7 éléments portent ce nom ». Il existait avant (la sauvegarde a les mêmes 7 `Icon` : celui de la caisse et ceux des 6 cases `Odds.Odd_n`).
  - Pour ouvrir la boutique, Claude a dû cliquer sur **Claim** de `UI_Offline` (seule façon de fermer cet écran) : les 7,8 milliards $ hors ligne en attente sont passés dans l'argent du compte de test de la place DEV.
- **Pour Ironix** : la section 5 ci-dessus, à reporter dans la liaison par la session principale (Claude n'a pas touché à `docs/Liaison-Code-Visuel.md`).
- **Test pour un humain**, une fois codé : à l'ouverture de la boutique, sur PC puis sur téléphone, les icônes des cartes sautent au survol, les titres brillent, les billets tombent dans les cartes Cash, la caisse suit la souris, et rien ne bouge avec « animations réduites ».

## 8. Deuxième vidéo : le bouton « juicy » (zZz et ×2 vitesse)

Demande de Clément (relayée par la session principale) : « je te joins une autre vidéo, je voudrais ça pour les boutons dans l'UI des Robux : ZzZ à payer, 2 fois plus de vitesse ». Lien : https://vm.tiktok.com/ZGdXWJav9/ (même compte phoxik.dev, autre pub du plugin Framewisp ; 59,8 s, 1080 × 1920, 30 i/s).

- **Comment je l'ai vue** : dans le navigateur intégré. J'ai refusé les cookies facultatifs et fermé la demande de connexion avec « Ignorer », deux choix proposés par TikTok. Les images viennent de la vidéo en lecture : rien n'est téléchargé, le son n'est pas analysé.
- **La description de la vidéo donne la recette** : un carré de 100 × 100 aux coins de 10, un dégradé rouge et un contour intérieur dégradé de 4 px. Un « Sunburst » est posé sous un masque, avec l'icône d'un panier par-dessus. Trois tags : `_smooth` (× 1,08 au survol, × 0,9 à l'appui, avec un clic sonore), `_spin` (les rayons tournent sans arrêt) et `_lean` (le panier penche vers le curseur).

### Les produits (rien changé : ni prix, ni Id)

| Ce que dit Clément | Produit | Où il est | Prix, Id, état |
| --- | --- | --- | --- |
| « ZzZ à payer » | `SleepGuards` (`Config/Boosts`) : endort tous les vigiles et policiers du serveur 60 s, puis 5 min de recharge (ce n'est pas « passer la nuit ») | Bouton du HUD `UI_HUD.RightRail.SleepButton` (texte « zZz », montré dans le couloir), et carte « Sleeping Guards 60s » de l'onglet Boosts de la boutique (`Monetization.ShopBoosts`) | 79 R$, `Id = 0`, `Ready = false` (pas encore en vente) |
| « 2 fois plus de vitesse » | `SpeedBoost` (`Config/Boosts`) : gains du tapis × 2 pendant 10 min | Bouton du HUD `UI_HUD.RightRail.SpeedBoostButton` (texte « x2 SPEED », montré sur un tapis), et carte « ×2 Speed » de la boutique | 29 R$, `Id = 0`, `Ready = false` |

### Chez eux (mesuré image par image, sauf mention)

| Élément | Mesure |
| --- | --- |
| Forme | Carré aux coins de 10 % (100 × 100, coins de 10, lus dans la description). Dégradé rouge, plus clair en haut. Contour intérieur clair en dégradé de 4 % (4 px), puis un gros contour sombre |
| Rayons | Environ 16 rayons rouge clair, découpés par le carré. Ils tournent dans le sens des aiguilles d'une montre, à **≈ 100° par seconde** (un tour en ≈ 3,5 s ; 3,5 à 4° par image, mesuré sur trois passages, à ± 10 % près). C'est 9 fois plus vite que nos rayons (45° en 4 s) |
| Icône | Le panier occupe environ 70 % du bouton, un peu sous le centre. Il **penche d'environ 10° vers le curseur** et glisse vers lui d'environ 4 % du bouton (estimé à l'œil sur 4 images) ; il revient droit quand la souris part |
| Survol | **× 1,08 en 0,13 s** (Quad Out, sans dépassement : largeur 392 → 424 px), retour à × 1 en 0,17 s |
| Appui | **× 0,90 en ≈ 0,1 s**, tenu tant que le bouton est enfoncé ; au relâché, × 1,08 en 0,1 s. La vidéo dit qu'un clic sonore part à l'appui (pas entendu) |

**Pourquoi ça marche** : même au repos, le bouton bouge (les rayons tournent), donc l'œil le trouve tout de suite. Au survol, trois couches réagissent à part (le carré grossit, les rayons continuent, l'icône suit la souris) : on a l'impression de toucher un objet.

### Chez nous : deux écrans possibles (question à Clément)

**Choix de Clément (2026-11-21) : A, les boutons du HUD.** La session principale confirme : `UI_HUD.RightRail.SpeedBoostButton` et `SleepButton` sont à cette session, après l'accord de Clément sur la maquette. Ne pas toucher aux 7 boutons `LeftRail`/`LeftRailTouch` (Shop, Index, Upgrades) ni à `RightRail.DisplayedButton`, retouchés par la session « ui-tiktok ». Sauvegarde avant de modifier : `ServerStorage/MapBackups/2026-11-21_HUD_SpeedSleep`.

**À savoir** : `SleepGuards` et `SpeedBoost` ont encore `Id = 0` et `Ready = false` (`Config/Boosts`). Ils ne s'achèteront pas tant que Clément ne les aura pas créés sur le Creator Hub, au nom du groupe. En attendant, un clic montre seulement « Soon ».

- **A. Les boutons du HUD** `SpeedBoostButton` et `SleepButton` (`UI_HUD.RightRail`). Ce sont les seuls à s'appeler « zZz » et « x2 SPEED ». Aujourd'hui, ce sont des pilules larges (270 × 96 dans la maquette) avec icône, texte, prix, `Hover = Pop`, `Press = Squash`, `Appear = SlideRight`. Le jeu les cache, puis les montre en situation. On y ajouterait des rayons qui tournent, découpés par le bouton, derrière l'`Icon` ; on pencherait l'icône vers la souris ; on mettrait un contour intérieur clair en dégradé ; et on passerait la forme en carré (comme la vidéo) ou on garderait la pilule. `UI_HUD` n'est pas l'écran confié à cette session : il faut que la session principale le confirme.
- **B. Les deux cartes de la boutique** « ×2 Speed » et « Sleeping Guards 60s » (`BoostsSection` de `UI_RobuxShop_v2`). Elles ont déjà des rayons (qui tournent lentement), `Hover = Pop` et `IconHover = "Jump"`. On y ajouterait des rayons plus rapides, une icône qui penche (`IconHover = "Lean"`, au lieu du saut) et le contour intérieur clair. Mais les cartes viennent d'un seul `Template` : « Open Now » changerait aussi.

**Ce qui serait pour Ironix, dans les deux cas** : (1) une vitesse de rayons par bouton, par exemple un attribut `SpinSpeed` en degrés par seconde (100), lu par `collectSpins` ; (2) `IconHover = "Lean"` : l'`Icon` penche vers le pointeur (10° au plus) et glisse de 4 % au plus, avec un ressort amorti, puis revient droit en 0,2 s. Sur téléphone, seulement pendant le toucher ; (3) rien pour le survol et l'appui, déjà proches chez nous (`Hover = Pop` : × 1,1 en 0,067 s ; `Press = Squash`). L-270 (le clic qui rate sur le bord d'un bouton écrasé) vaut aussi pour ces boutons.

### Maquette pour le HUD (validée par Clément le 2026-11-21, faite dans Studio)

Figma « Steal a Shop — UI », page `30 HUD, tapis, poursuite`, cadre « Boutons x2 SPEED et zZz — d'après la 2e vidéo (2026-11-21) », node 210:369. Image : `frames/hud_tuiles_maquette_210-369.png`.

- **Forme** : un carré de la taille de Displays (112 × 112 sur la maquette PC), avec la même recette (contour, reflet du haut, studs). Il est posé sous Displays, à 24 px d'écart pour le survol. Un seul des deux se montre à la fois. On garde **nos couleurs** : arc-en-ciel pour « x2 SPEED », indigo pour « zZz », et nos icônes `UI_Icon_SpeedBoost` et `UI_Icon_Sleep`.
- **Contour intérieur clair en dégradé** (blanc vers transparent), comme celui de la vidéo.
- **Rayons blancs transparents derrière l'icône** (`RaysClip`, qui découpe, avec dedans `Rays`) : ils tournent à ≈ 100° par seconde.
- **L'icône penche vers la souris.**
- **Le prix est dans le carré**, en haut à droite. « x2 SPEED » ou « zZz » est écrit en bas, comme « Displays ».
- **En recharge**, le carré s'assombrit et montre le temps restant (`Cooldown`).
- **Ce qui change pour les noms** : rien. `Icon`, `Label`, `Price.Amount`, `Cooldown` et `Hint` restent, avec les mêmes noms et les mêmes parents ; on ajoute `RaysClip` et `Rays` (du décor, pas lu par le code). Le code ne lit pas `Hint` (« Guards sleep 60s ») : dans un carré, il n'a plus de place. **À décider par Clément** : le cacher, ou le garder en petit.
- **Pour Ironix, si c'est validé** :
  1. Les rayons du HUD ne tournent pas aujourd'hui : `collectSpins` ne vit que dans la boutique Robux. Il faudrait un tour générique pour tout écran, par exemple un attribut `SpinSpeed` (degrés par seconde, ici 100) sur l'image `Rays`.
  2. `IconHover = "Lean"`, comme pour les cartes de la boutique (section 5).
  3. Rien pour le survol et l'appui, qui existent déjà (`Hover = "Pop"`, `Press = "Squash"`).
  4. `SleepGuards` et `SpeedBoost` ont `Id = 0` et `Ready = false` : rien ne s'achète tant que Clément ne les a pas créés sur le Creator Hub.

**Fait dans Studio le 2026-11-21** (place DEV, rien enregistré, rien publié, rien commité) :

- **Script** : [tools/clement/ui_hud_tuiles_speed_sleep.luau](../../../tools/clement/ui_hud_tuiles_speed_sleep.luau) (rejouable, valeurs absolues). Sauvegarde avant changement : `ServerStorage/MapBackups/2026-11-21_HUD_SpeedSleep/UI_HUD`. La partie « zZz » de `ui_contours_regle.luau` ne touche plus un bouton déjà en carré.
- **`SpeedBoostButton` et `SleepButton`** :
  - **forme et place** : des carrés de la taille de Displays (même `Size`, `AnchorPoint` en haut à droite, `UIAspectRatioConstraint` à 1), posés sous lui ;
  - **à l'intérieur** : `Icon` au centre, `Label` en bas, à cheval sur le bord comme « Displays », et `Price` en haut à droite ;
  - **les rayons** : un nouveau décor `RaysClip` (qui découpe) contient `Rays`, les rayons doux de la boutique, en blanc à 35 % de transparence, avec l'attribut `SpinSpeed = 100` ;
  - **l'attribut `IconHover = "Lean"`**, posé sur les deux boutons.
- **Couleurs** : « zZz » garde son indigo. « x2 SPEED » passe à l'arc-en-ciel de la maquette validée : son jaune d'avant (`#FFF7A4` → `#E0D44F`) se confondait presque avec Displays (`#FFF0AE` → `#E0C85E`), juste au-dessus. Le jaune reste dans la sauvegarde.
- **« zZz » en recharge** : `Cooldown` couvre tout le carré, avec un voile sombre et le temps restant au centre. Le code n'a qu'à le montrer, comme aujourd'hui.
- **`Hint`** (« Guards sleep 60s ») est caché, faute de place. Le code ne le lit pas ; il suffit de mettre `Visible = true` pour le remettre.
- **Vérifié en Edit** :
  - aucun nom changé ni déplacé, aucun script ; une seule visibilité change, celle de `Hint`, et les ajouts ne sont que du décor ;
  - les 7 boutons de la session « ui-tiktok » sont identiques à leur copie ;
  - les carrés font 62 × 62 px sur PC et 60 × 60 sur téléphone, comme Displays ;
  - rien ne sort du carré, sauf le titre (comme pour Displays) ;
  - il reste 7 px d'écart avec Displays quand les deux sont survolés (12 px au repos sur téléphone) ;
  - à la fin, les deux boutons sont recachés, comme le code l'attend.
- **Captures** : `frames/hud_tuile_speed_pc.jpg`, `frames/hud_tuile_zzz_pc.jpg`, `frames/hud_tuile_zzz_recharge_pc.jpg`, `frames/hud_tuile_zzz_iphone17pro.jpg`, et en gros plan `frames/hud_tuiles_zoom_3etats.png`.
- **Pas vérifié en Play** : le jeu ne montre ces boutons que sur un tapis ou dans le couloir. **À tester par un humain** : sur un tapis puis dans le couloir, le bouton apparaît sous Displays (`Appear = SlideRight`), il grossit au survol sans toucher Displays, et en recharge le temps se lit sur le voile.

## 9. Contours, chevauchements et croix (demande de Clément du 2026-11-21)

Ses mots : « revoir le contour de tous les boutons pour qu'ils soient tous comme les boutons rectangles du HUD, et que les boutons ne se superposent pas, notamment le zZz même au hover ; tous les boutons ne doivent pas se superposer ; réduis d'un tout petit peu les tailles de croix pour fermer les onglets ».

### Ce que dit l'audit (Studio, Edit, lecture seule, écran de 937 × 575)

- **Contours** : la règle est déjà la même presque partout : un trait `#0D0D14` de 5 % de la taille du bouton, à l'extérieur, posé soit sur le bouton (HUD de gauche, croix, armes, auras), soit sur un cadre `Outline` (boutique Robux, « zZz », « x2 SPEED »). Vu de près, un bouton de la boutique et un bouton rectangulaire du HUD ont le même contour (`frames/contours_hud_boutique_croix_zoom.png`). **Des boutons n'ont aucun contour** : `UI_Index_v3` (82), `UI_SkillTree` (13), `UI_PawnShop` (5), `UI_Hotbar` (2), `UI_Rewards` (2), `UI_DiamondShop` (2), `UI_Rebirth` (1), et les 4 onglets cachés de la boutique Robux. Ce sont peut-être des cases (objets de l'index, tuiles) plutôt que des boutons : c'est à Clément de dire lesquels doivent prendre le contour. `UI_Settings` a 3 traits en pixels fixes (2 et 3 px) au lieu de 5 %.
- **Chevauchements** (au repos, puis au survol à × 1,1 autour du point d'ancrage de chaque bouton) :
  - `UI_HUD` : **le « zZz »** (`RightRail.SleepButton`). Son étiquette de prix dépasse de 13 px au-dessus du bouton et s'arrête à 2 px du bouton `DisplayedButton` (« Displays »). Au survol, Displays grossit vers le bas : les deux se touchent. Le « x2 SPEED » n'a pas ce défaut (son prix est dans le bouton).
  - `UI_RobuxShop_v2` : les 3 boutons d'achat de la caisse, ancrés à gauche, grossissaient vers la droite et mordaient de 4 px sur leur voisin. **Corrigé** (voir plus bas).
  - `UI_DiamondShop` : la croix chevauche le bouton « + » (`AddButton`) au repos, de 6 px ; les onglets se touchent de 1 px au survol.
  - `UI_SkillTree` : les cadres des tuiles se recouvrent de 21 px, ce sont des hexagones imbriqués : les cadres se recouvrent, pas les formes (vérifié à l'œil). Le bouton « Close » recouvrait en revanche le bas des deux hexagones du bas, surtout sur téléphone.
  - `UI_Settings` : le curseur et sa piste (normal).
- **Croix de fermeture** (taille sur cet écran) : `UI_Wheel` 53 px, `UI_WeaponShop` et `UI_AuraShop` 52, `UI_RobuxShop_v2` 48, `UI_Displayed` 47, `UI_HelpInvite` 46, `UI_Rebirth`, `UI_Rewards`, `UI_Settings`, `UI_Index_v3` et `UI_DiamondShop` 44 (déjà au minimum de 44 px du téléphone), `UI_SkillTree` 130 × 46 (bouton « Close » large). Réduire d'environ 10 % en taille relative ne change rien là où le minimum de 44 px s'applique ; ça se voit sur les grands écrans.

- **Attention à la mesure** : un écran éteint garde de vieilles positions. L'audit final a donc été refait en allumant chaque écran le temps de la mesure, sur PC et en émulation iPhone 17 Pro.

### Fait sur tous les écrans (2026-11-21)

La session principale a confié à cette session tous les écrans de `StarterGui`. Place DEV, **rien enregistré, rien publié, rien commité**.

- **Script unique et rejouable** : [tools/clement/ui_contours_regle.luau](../../../tools/clement/ui_contours_regle.luau). Il reprend aussi les deux retouches faites plus tôt dans la boutique Robux (l'ancien `ui_shop_boutons_1121.luau` est supprimé). Un deuxième passage ne change rien (vérifié : 0 différence).
- **Copies avant changement** : `ServerStorage/MapBackups/2026-11-21_Contours/<Écran>`, pour 14 écrans. Plus tôt, la boutique avait aussi `2026-11-21_ShopBoutons`.
- **Contours remis à la règle** (110) :
  - les boutons de `UI_Admin` qui n'avaient aucun contour ;
  - `UI_HUD.AdminButton` ;
  - l'interrupteur des effets de `UI_Settings` ;
  - les 3 faces du bouton de confirmation de `UI_Rebirth` ;
  - le fond `Back` des cases de `UI_Hotbar` ;
  - la face `Clip` des cartes de `UI_Index_v3`.
- **Contours laissés tels quels, à dessein** :
  - les contours des titres (`Label.UIStroke`), y compris ceux des 7 boutons du HUD retouchés par la session « ui-tiktok » (contour blanc, couleur portée par `Gleam`) ;
  - les choix du receleur, qui sont du texte sans cadre ;
  - les onglets à icône des récompenses et des diamants ;
  - les tuiles de l'arbre, dont le contour est dessiné dans l'image ;
  - les poignées des curseurs de `UI_Settings`.
- **Croix 10 % plus petites** (10) : roue, renaissance, armes, auras, récompenses, réglages, index, diamants, invitation et boutique Robux. Sur cet écran, la roue, les armes et les auras passent à 47 px (au lieu de 52–53) ; les autres restent à 44 px, le minimum gardé pour le téléphone (ajouté à la croix de l'invitation). Le « Close » de l'arbre, la flèche « > » du dock et la croix de l'Admin (44 px fixes) ne changent pas.
- **Plus aucun bouton qui en chevauche un autre**, au repos ni au survol (× 1,1), sur PC (937 × 575) comme sur téléphone (iPhone 17 Pro). Vérifié en allumant chaque écran :
  - « zZz » : le prix est dans le bouton, en haut à droite. Il reste 7 px entre le « zZz » et Displays survolé (6 sur téléphone) : `frames/regle_hud_zzz_pc.jpg`.
  - Boutique Robux : les 3 boutons d'achat de la caisse sont ancrés au centre (au lieu du bord gauche) et 2,3 % plus étroits. Il reste 9,9 px de marge au survol (6,9 sur téléphone), et 1,9 px au rebond du relâché (1,3 sur téléphone). `CrateLoop` lit l'ancrage : la pulsation de `BuyButton3` reste juste. Captures : `frames/boutons_apres_pc.jpg`, `frames/boutons_apres_iphone17pro.jpg`.
  - Index : cartes écartées de 2,5 % en largeur et de 6 px en hauteur (il y avait 0 px entre les rangées) : `frames/regle_index_pc.jpg`.
  - Diamants : le « + » est décollé de la croix (13 px) et le compteur de diamants suit (17 px avant le « + », 43 px après le titre) : `frames/regle_diamants_pc.jpg`. Le premier essai, qui poussait le « + » sur le compteur, est gardé dans `frames/regle_diamants_essai1_chevauche.jpg`.
  - Arbre de compétences : le « Close » passe dans le coin en bas à droite (`frames/regle_arbre_pc.jpg`, `frames/regle_arbre_iphone17pro.jpg` ; avant : `regle_arbre_avant_*.jpg`). L'arbre se déplace à la souris : des tuiles peuvent encore passer sous le bouton si le joueur fait glisser l'arbre.
  - Admin : les 6 boutons de type écartés (2,3 px de marge au survol).
- Comparaison de chaque écran avec sa copie : 0 élément manquant, 0 classe changée, 0 visibilité changée, aucun script ; ajouts : 21 `UIStroke` (Admin) et 1 `UISizeConstraint` (invitation). Les 7 boutons de la session « ui-tiktok » sont identiques à leur copie.
- **Pas vérifié en Play** : seuls des contours, des tailles, des places et des écarts ont changé, aucun nom lu par le code. Les listes que le code remplit en jeu (cartes de l'index, cases de la barre du bas) ont été vérifiées par leurs écarts.

### Pour Ironix (côté code)

1. **`HoverFit` étendu** (`Config/UiMotion`) : un bouton qui grossit (survol `Pop` × 1,1, rebond de `Squash` × 1,21, réussite) s'arrête 2 px (`Inset`) avant le bouton visible le plus proche du même écran, et avant le bord de l'écran. Aujourd'hui, il ne s'arrête qu'au bord de sa carte. Ça tiendra aussi pour les boutons montrés en situation et les listes remplies en jeu. Voir L-270 (le clic qui rate sur le bord d'un bouton écrasé) et L-275 (un bouton qui reste en survol) : ces deux défauts aggravent les chevauchements.
2. **Deux techniques de reflet sont proposées pour le même effet.** Il faut en choisir une :
   - pour la boutique Robux (cette fiche) : une copie blanche du titre posée par-dessus, avec un attribut `Gleam = "Loop"/"Hover"` ;
   - pour les 7 boutons du HUD (fiche de la session « ui-tiktok ») : un `UIGradient` nommé `Gleam` sous le `UIStroke` du titre, dont on fait défiler `Offset.X`.

   La seconde suffit pour les titres blancs des cartes de la boutique. Le titre de la caisse (« EXCLUSIVE CRATE »), qui a un dégradé vertical sur ses lettres, a besoin de la première pour que le reflet passe aussi sur les lettres, comme dans l'aperçu validé par Clément.

### Reste à faire

- Rien côté Studio : les deux boutons du HUD d'après la 2e vidéo sont faits (section 8). Côté code : les demandes ci-dessus et celles de la section 8 (rayons qui tournent dans le HUD, `IconHover = "Lean"`).

## 10. Copie Figma modifiable de toute l'UI (demande de Clément du 2026-11-21)

Demande : « Mets tous les éléments du jeu en terme d'UI dans le figma ». À la question posée, Clément a choisi « Copie modifiable ».

**Où.** Fichier Figma « Steal a Shop — UI », page « 40 Jeu — copie de Studio (21/11) » : https://www.figma.com/design/fXjkvf39sRhlsL94YicwDH/?node-id=214-369

**Ce qui y est.** Les 30 écrans de StarterGui, relevés dans Studio sur un appareil simulé de 1920 × 1080. Ils sont rangés en 5 rangées de 6 :

| Rangée | Écrans |
| --- | --- |
| HUD et infos permanentes | `UI_HUD`, `UI_Hotbar`, `UI_Displayed`, `UI_Notify`, `UI_Toast`, `UI_ZoneBanner` |
| Boutiques | `UI_RobuxShop_v2`, `UI_DiamondShop`, `UI_AuraShop`, `UI_WeaponShop`, `UI_PawnShop`, `UI_Wheel` |
| Progression | `UI_Index_v3`, `UI_SkillTree`, `UI_Rebirth`, `UI_Rewards`, `UI_Settings`, `UI_Admin` |
| Événements | `UI_Chase`, `UI_Escape`, `UI_TheftAlert`, `UI_EventBanner`, `UI_Announce`, `UI_HelpInvite` |
| Tutoriel et effets | `UI_Tutorial`, `UI_TutorialFocus`, `UI_Offline`, `UI_Unbox`, `UI_Veil`, `UI_PurchaseGlow` |

Sous ces rangées, 40 éléments sont posés à plat :

- les 22 billboards `BB_*`, à 40 px par stud (taille vue à distance moyenne) ;
- un exemplaire de chacun des 4 billboards du décor absents de `Assets/UI` (`WS_BB_OpenTimer`, `WS_ShowLabel`, `WS_AmountGui`, `WS_Show_BB_Box`) ;
- les 2 tableaux des scores (`LB_Income`, `LB_Speed`) et les 2 enseignes (`SIGN_StoreReqSign`, `SIGN_UpgradeSign`) ;
- `AlertBadge`, `AntiTheftOverlay` et les 8 fonds de cartes `ShopCardBg` (`CARD_*`).

Ne sont pas copiés :

- les 4 anciens écrans (`UI_Index`, `UI_Index_v2`, `UI_SkillTree_v2_old`, `UI_RobuxShop`) ;
- les quelque 700 étiquettes imprimées sur les objets du décor (`LabelGui_*`, `SurfaceGui` des produits) : ce sont des emballages, pas de l'interface.

**Ce qui a été vérifié.**

- Chaque cadre Figma est un élément Studio, avec le même nom et la même hiérarchie. Pour les 70 copies, le nombre de cadres est égal au nombre d'éléments relevés.
- Les 762 textes restent modifiables et sont tous en Montserrat, avec les mêmes graisses que dans Studio (Black 702, Bold 35, ExtraBold 17, Black Italic 8).
- Il y a 1 178 remplissages d'image. Ils viennent de 182 images Roblox, photographiées sur fond noir puis sur fond blanc pour retrouver leur transparence.
- Les éléments cachés dans Studio sont cachés dans Figma. Les zones de défilement coupent leur contenu comme dans le jeu, et ce qui est sous la coupe est présent (décocher « Clip content » pour le voir).
- Il ne reste dans la page aucun calque d'aide ni réglage dans les noms. Captures de contrôle : roue, notifications, HUD, armes, boutique Robux, Index, enseignes.

**Limites.**

- C'est une photo de l'écran à 1920 × 1080 en mode Edit. Les tailles en Scale et les `UIAspectRatioConstraint` deviennent des pixels fixes, et les autres tailles d'écran ne sont pas représentées.
- La taille des textes qui s'adaptent (`TextScaled`) est recalculée d'après leur boîte réelle dans Studio, avec un interligne de 120 % : elle est proche, pas au pixel.
- Un contour coloré par un `UIGradient` (le `Gleam` des boutons du HUD) prend la couleur du milieu du dégradé.
- Les animations et effets ne sont pas copiés : survol, rebond, reflet qui passe, rayons qui tournent, chutes.
- Les aperçus 3D (`ViewportFrame`) sont des boîtes translucides.
- Le rang `ZIndex` est respecté dans chaque parent, mais un écran en `ZIndexBehavior = Global` ne peut pas mélanger des enfants de parents différents.
- Les listes que le code remplit en jeu apparaissent sous la forme de leur `Template` (souvent caché).
- La rangée `TopLeftRow` du HUD est posée au-dessus du cadre, avec une note. En jeu, elle se trouve dans la barre du haut de Roblox, qui n'existe pas en mode Edit.

**Dans la place.** Rien n'est modifié. Les seuls objets créés (`StarterGui._FigmaAtlas`, `StarterGui._FigmaBB`) ont été supprimés aussitôt, et l'appareil simulé est arrêté. Il reste 0 script dans StarterGui. Rien n'est enregistré, commité ni poussé.

**Pour la refaire.** `tools/clement/figma_copie/` contient le relevé Studio, la découpe des images, le générateur et la passe Figma. Son `README.md` donne la marche à suivre et les pièges de la conversion. Après un changement d'écran, il suffit de relever cet écran et de le réimporter : la passe remplace l'ancienne copie du même nom.

**Pour Ironix.** Rien : aucune demande de code.

## 11. Boutons du HUD dessinés par Clément avec Framewisp (2026-11-21)

Demandes de Clément : « J'ai ajouté des boutons sur roblox studio, tu peux les remplacer de ce actuellement ? », puis « je te fais les versions responsives ». Il a importé 7 boutons avec le plugin Framewisp, dans 7 écrans `Framewisp_*` de StarterGui :

| Bouton | Version PC (`LeftRail`) | Version téléphone (`LeftRailTouch`) |
| --- | --- | --- |
| Shop | `Framewisp_5C9UZM` (290 × 90) | `Framewisp_YMN8Y4` (94 × 102) |
| Index | `Framewisp_9BEJ6Z` (290 × 90) | `Framewisp_988SNX` (94 × 102) |
| Upgrades | `Framewisp_D2JPMH` (290 × 90) | `Framewisp_UYPUAN` (104 × 102) |

Display n'a qu'une version, pour `RightRail` : d'abord `Framewisp_QMN9WW` (220 × 228), puis « le bon bouton display », `Framewisp_ZDLZ89` (94 × 102, même construction que les versions téléphone). C'est ce dernier qui est posé ; le premier reste dans la sauvegarde. Au survol, il reste 8 px entre Display et les tuiles zZz / x2 SPEED, et 3 px au rebond.

**Fait dans Studio** (`tools/clement/ui_hud_boutons_framewisp.luau`, rejouable et annulable en une étape) :

- **Les boutons restent les mêmes pour le code.** `RobuxShopButton`, `IndexButton` et `SkillTreeButton` (rail PC et rail téléphone) et `DisplayedButton` gardent leur nom, leur classe (`TextButton`) et leur place. Ils gardent aussi leurs attributs (`Hover = Pop`, `Press = Squash`, `IconHover`) et leurs pastilles (`IndexAlert`, `SkillTreeAlert`, avec `Pulse`). Seul l'habillage change :
  - partent les anciens calques : `Studs`, `Shine`, `Icon`, `Label`, `Lip`, `Rim`, le contour, le dégradé et les coins. Le `Gleam` des titres, posé par la session « ui-tiktok », part avec l'ancien `Label` ; aucun code ne le lisait ;
  - arrivent ceux du dessin Framewisp : `Background`, les rayons `Sunburst` dans leur cadre, `LabelShadow`, `Label`, `Icon`, et les petites images d'effet cachées (`*_Sheen`, `BurstImg`) ;
  - la contrainte de forme suit le dessin : 3,222 sur PC, 0,922 et 1,020 sur téléphone, 0,922 pour Display.
- **Aucun script.** Les 34 LocalScripts Framewisp (texte, reflet, éclat, rotation, contour qui tourne) ne sont pas copiés. Les réglages d'effet du dessin restent en attributs `Figma*`, et les rayons portent `SpinSpeed = 45`.
- **Deux corrections imposées par le HUD**, qui est en `ZIndexBehavior = Global` (les écrans Framewisp étaient en `Sibling`) :
  - les `ZIndex` du dessin (4 à 24) sont ramenés de 3 à 14, dans le même ordre, sous les pastilles (20) ;
  - dans ce mode, un `CanvasGroup` ne coupe pas ses enfants, et les rayons débordaient autour des boutons. Les rayons (et l'icône des versions carrées) sont donc posés directement dans leur cadre, qui coupe (`ClipsDescendants`), et le masque est retiré. La coupe a des coins droits au lieu d'arrondis, ce qui se voit à peine.
- **Rayons de Shop sur PC** : le script de rotation de Framewisp les avait laissés hors du bouton dans l'écran d'origine. Ils sont remis à la place de ceux d'Index et d'Upgrades.
- **Écart du rail PC** : 6,6 % → 8,6 %. Sans ce changement, l'icône de Shop touchait Index au rebond de l'appui. Les boutons étant un peu plus bas, la colonne ne grandit que de 4 px.
- **Sauvegardes** dans `ServerStorage/MapBackups/2026-11-21_HUD_Framewisp` : le HUD d'avant, et les 7 écrans Framewisp d'origine, sortis de StarterGui. Ils contenaient des scripts et s'affichaient au milieu de l'écran en jeu.

**Vérifié dans Studio** :

- **PC (1254 × 753)** : il reste au moins 2 px entre deux boutons, au repos, au survol (× 1,1) et au rebond (× 1,21), et 6 px entre Display et les tuiles zZz / x2 SPEED.
- **iPhone 17 Pro** : les boutons font 45 à 49 px sur 48 à 49 px (au moins 44 px), avec au moins 5 px d'écart au rebond.
- Plus aucun rayon ne dépasse des boutons.
- Il reste 0 script dans StarterGui, et le contrat est respecté : boutons, classes, pastilles et `Pulse`.

Pas de Play. Les tuiles zZz et x2 SPEED gardent leur style d'avant ; Clément n'a pas demandé de les changer.

**Figma** : la copie du HUD (page « 40 Jeu — copie de Studio ») est mise à jour, avec 189 calques comme dans Studio. Les versions téléphone sont dans `LeftRailTouch`, caché comme dans Studio.

### Pour Ironix (côté code)

Les boutons marchent déjà comme avant (ouverture, survol, appui, pastilles). Ce qui manque, ce sont les effets du dessin. Framewisp les faisait avec ses propres scripts, qui sont gardés comme référence dans la sauvegarde :

1. **Rotation des rayons** : `Sunburst` tourne à `SpinSpeed` degrés par seconde (45 ici). C'est la même demande que pour les tuiles du HUD (section 8) : un tour générique pour toute image qui porte `SpinSpeed`.
2. **Reflet** (`FigmaGleam = 1`, largeur `FigmaGleamWidth = 0,19` sur Shop) : une bande claire qui passe sur le bouton. Les images de reflet sont déjà là, cachées : `Background_Sheen`, `Icon_Sheen`, `Sunburst_Sheen`.
3. **Éclat au clic** (`FigmaBurst = 1`, `FigmaBurstSize` ou `FigmaBurstSizeMax`) : l'image cachée `BurstImg` jaillit du bouton.
4. **Icône** : `FigmaLean = 1` (penche vers la souris, comme `IconHover = "Lean"` en section 8). Sur Shop PC s'ajoute `FigmaWiggle = 1` (petit tremblement toutes les `FigmaWiggleEvery = 6` s).
5. **Contour qui tourne sur Display** : `Rectangle 2` a `FigmaStroke = 1`, `FigmaStrokeAngle = 90` et `FigmaStrokeRotate = 360`. Son `UIStroke` porte un `UIGradient` dont l'angle tourne.

Rien ne presse : sans ces effets, les boutons sont simplement immobiles.

## 12. Tuiles zZz et x2 SPEED au style de Display, en rectangle (2026-11-21)

Demandes de Clément : « refais les boutons au style du display », puis « Fais les en rectangle pour la description ». Sur la règle d'affichage, il a précisé : « Que le ZzZ quand on est dans la zone non safe, et la course que quand on est sur le treadmill ». C'est déjà ce que fait le code (`Config/Boosts`) :

- x2 SPEED a `ShowWhen = "OnTreadmill"` ;
- zZz a `ShowWhen = "InCorridor"` avec `MinZone = 1`, c'est-à-dire hors de la zone safe.

Rien à demander pour ça.

**Maquettes :**

- `frames/hud_tuiles_style_display_maquette.png` : les tuiles carrées sur les 3 fonds libres (bleu, vert, rouge) ;
- `frames/hud_tuiles_rectangle_maquette.png` : la version rectangle retenue, en grand, en recharge et à sa place sous Display.

**Fait dans Studio** (`tools/clement/ui_hud_tuiles_rectangle.luau`, rejouable et annulable en une étape ; sauvegarde `ServerStorage/MapBackups/2026-11-21_HUD_TuilesRect/UI_HUD`). Ce script remplace l'habillage carré de `ui_hud_tuiles_speed_sleep.luau`.

- **Les boutons restent les mêmes pour le code.** `RightRail.SleepButton` et `RightRail.SpeedBoostButton` gardent leur nom, leur classe et leurs attributs. Ils gardent aussi `Price` (avec `Price.Amount`, où le code écrit le prix, et `Price.RobuxIcon`) et le voile `Cooldown` de zZz. Ils restent cachés : le code les montre selon leur règle.
- **Habillage** : fond, rayons et cadre des boutons PC de Clément. zZz prend le bleu d'Index, x2 SPEED le vert de Shop. Chaque tuile a son icône, un titre (`Label` et `LabelShadow`) et une description (`Hint`) :
  - zZz : « Guards sleep 60s » (60 s dans `Config/Boosts`, c'est le texte d'origine de Clément) ;
  - x2 SPEED : « x2 gains · 10 min » (× 2 pendant 600 s). Ce texte est court pour rester lisible sur téléphone.
- **Forme et place** : rectangle au rapport 3,222 (celui des boutons PC), sur 88 % de la largeur de `RightRail`, à 60 % de sa hauteur, et au moins 142 × 44 px. L'étiquette de prix est posée sur le coin en haut à droite. Le voile de recharge couvre la face du bouton, au-dessus de tout.
- Aucun script. Les rayons portent `SpinSpeed = 45`, comme les autres boutons.

**Vérifié dans Studio :**

- **PC (1254 × 753)** : la tuile fait 174 × 54 px. Il reste au moins 11 px avec Display, même au rebond (× 1,21) de l'un ou de l'autre, et 2,5 px avant le bord de l'écran.
- **iPhone 17 Pro** : la tuile fait 142 × 44 px (le minimum), avec au moins 7 px d'écart avec Display au rebond. Au sommet du rebond, elle dépasserait le bord de l'écran de 3 px, ce qui ne touche aucun bouton. C'est couvert par la demande `HoverFit` de la section 9 (s'arrêter 2 px avant le bord).
- 0 script dans StarterGui. Pas de Play.

**Figma** : la copie du HUD est mise à jour, avec 185 calques comme dans Studio. Elle a le nouveau Display, et les deux tuiles cachées comme dans Studio (il suffit de les afficher pour les voir).

**Pour Ironix** : rien de nouveau. La règle d'affichage existe déjà, et les effets à coder sont ceux de la section 11 (rayons qui tournent, reflet, éclat). `Hint` n'est lu par aucun code : c'est du texte fixe.

## 13. Menu Displays, cohérence des boutons des boutiques, taille de Display (demandes du 2026-11-21 au soir)

Demandes de Clément, transmises par la session « Stylo Shop GitHub review » :

- « Revoir les animations des boutiques d'auras et de trails car on ne voit plus les textes avec le contour et l'ombre. »
- « Globalement il faudrait revoir tous les boutons, tous les contours pour que ça soit dans le même style que les nouveaux boutons. Essaie de faire une bonne cohérence visuelle sur tous les boutons de toutes les boutiques. »
- « Revoir la taille du bouton Display. »
- Pour le menu Displays : « il faut qu'on voit d'abord tous les displays actuels et ensuite, après le dernier display, on voit les items de l'inventaire. Ajoute aussi les boutons Sell et confirmation Yes or No. Tu peux augmenter la hauteur de ce panneau et réduire les éléments, notamment les boutons, regarde les exemples. »

Les exemples sont dans `docs/claude/notes/img/references-displayed-2026-11-21/`.

### Maquettes (à faire valider par Clément avant Studio)

Elles sont rangées dans `docs/claude/video/references/2026-11-21_ShopTikTok/frames/`.

1. **`displayed_liste_unique_maquette.png`** : le menu Displays.
   - Un panneau plus haut, avec un en-tête : icône, « On Display », compteur « 3/8 » et croix rouge.
   - Une seule liste qui défile : le titre « ON DISPLAY 3/8 » et les objets exposés, puis le titre « INVENTORY 2 » et les objets de l'inventaire.
   - Des lignes compactes : icône carrée sur la couleur de la rareté (mention « 1 in 60 » possible dessous), rareté en couleur au-dessus du nom, $/s.
   - Deux petits boutons empilés à droite : REMOVE (bleu) ou DISPLAY (vert), et SELL (rouge).
   - DISPLAY BEST en bas.
   - À côté, la confirmation : « SELL ITEM? », l'objet, son prix de vente, YES / NO.
   - Les prix et revenus de la maquette sont des exemples.
2. **`boutiques_boutons_avant_apres.png`** : la boutique d'auras avant / après.
   - Tous ses boutons (onglets, croix, prix en $, Robux, Equip) sont refaits au style des boutons Framewisp de Clément : fond quadrillé clair, dégradé, liseré clair intérieur, contour sombre épais, rebord du bas plus foncé, texte blanc avec contour et ombre portée.
   - Ce style est refait en pièces Roblox (cadres, `UIGradient`, `UIStroke`, motif `87198718489515` en mosaïque) pour marcher dans toutes les couleurs. Les dessins Framewisp n'existent qu'en vert, bleu, rouge et jaune, et leur fond est une image.
   - Même style ensuite pour toutes les boutiques : armes, diamants, Robux, receleur, roue, récompenses, réglages.
3. **`hud_display_taille_options.png`** : le bouton Display du HUD à 100 % (aujourd'hui), 125 % et 150 %. La tuile zZz / x2 SPEED descend d'autant.

### Textes illisibles des boutiques d'auras et de trails : pas reproduit

- **Dans Studio** (sans le code), tous les textes se lisent.
- **Dans un Play court** (moins de 4 min, code du dépôt jusqu'à fusion86b) :
  - boutique ouverte par `AuraShopController.Open`, onglets Auras et Trails, survol d'un bouton d'achat ;
  - titres, raretés, « ×2 Strength », « ×2 Speed », prix et Equip se lisent tous ;
  - le code n'ajoute qu'un calque `Sheen` dans l'écran.
- **Question posée à la session coordinatrice** : quel texte, et à quel moment ? Une capture de Clément suffirait.

### Noms V0 (à valider par Ironix, Clément ne les pose qu'après la maquette validée)

`UI_Displayed` :

| Nom | Rôle |
| --- | --- |
| `Dock.Panel.List.Template.SellButton` (`TextButton`, texte `SellLabel`) | Vendre l'objet de la ligne (exposé ou inventaire) |
| `Dock.Panel.List.Template.IconSlot.Odds` (`TextLabel`, facultatif) | « 1 in 60 », si le code connaît la chance de l'objet |
| `Dock.Panel.List.SectionTemplate` (`Frame` caché, avec `SectionLabel` et `SectionCount`) | Titre de section cloné par le code deux fois : « ON DISPLAY » + « 3/8 », puis « INVENTORY » + nombre |
| `Dock.Confirm` (`Frame` caché) | Confirmation de vente |
| `Confirm.ItemIcon` (`ImageLabel`), `Confirm.ItemRarity`, `Confirm.ItemName`, `Confirm.SellPrice` (`TextLabel`) | L'objet et son prix de vente (« for $25K ») |
| `Confirm.YesButton`, `Confirm.NoButton` (`TextButton`) | Vendre ou annuler |

Ce qui reste : `Template.RemoveButton` et `Template.DisplayButton` (avec `DisplayLabel`), `Icon`, `ItemName`, `Income`, `RarityChip.RarityLabel`, `DisplayCount.CountLabel`, `DisplayBestButton` et `ListEmpty`.

**Liste unique.** Le code la gère déjà (a286, L-278) : dès que `Panel.Reserve` n'existe plus et que `List.Template` porte `DisplayButton`, il remplit `Panel.List` avec les objets exposés, puis l'inventaire à la suite. Après validation de la maquette, je ferai donc la nouvelle mise en page avec la conversion de `tools/clement/ui_displayed_une_liste.luau`, qui retire `Panel.Reserve`. Jusque-là, rien ne change dans l'écran.

### Pour Ironix (côté code, après validation)

1. **SELL** : `List.Template.SellButton` (exposé comme inventaire). Le clic ouvre `Confirm`, rempli avec l'icône, la rareté, le nom et le prix de vente, lu comme au comptoir du receleur (`PawnShop`). `YesButton` vend côté serveur (l'objet exposé est d'abord retiré de son présentoir) puis ferme `Confirm` ; `NoButton` ferme sans rien faire. Liaison : L-271, déjà complétée par la session coordinatrice.
2. **Titres de section dans la liste unique** : cloner `List.SectionTemplate` avant les objets exposés (« ON DISPLAY » et `x/y` présentoirs) et avant l'inventaire (« INVENTORY » et le nombre), avec le `LayoutOrder` qu'il faut.
3. **`IconSlot.Odds`** (facultatif) : « 1 in N » si la chance de l'objet est connue. Sinon, caché.
4. **Textes des boutiques d'auras et de trails** : à voir quand Clément aura dit quel texte et à quel moment. Si c'est un effet du code (reflet `Sheen`, `FW_GleamShine`, `Motion`), c'est pour Ironix.

## 14. Fait dans Studio le 2026-11-22 (après « Oui, Display 125 % »)

Rien n'est enregistré, commité ni poussé. Chaque écran touché a sa sauvegarde dans `ServerStorage/MapBackups`. Aucun script dans l'UI (0 dans StarterGui), aucun nom lu par le code n'a changé.

### Menu Displays en liste unique

- Script : `tools/clement/ui_displayed_v2.luau`. Sauvegarde : `MapBackups/2026-11-22_Displayed`.
- `Panel.Reserve` est retiré : le code bascule seul en liste unique (a286, L-278). L'ancien `ReserveEmpty` devient `Panel.ListEmpty`.
- Panneau plus haut (`Dock` 0,36 × 0,88), lignes compactes, deux petits boutons empilés par ligne : `RemoveButton` (bleu) ou `DisplayButton` (vert), et `SellButton` (rouge, caché tant que le code ne le montre pas). DISPLAY BEST en bas, croix dans l'en-tête.
- Ajoutés (noms V0 de la section 13, à brancher par Ironix) :
  - `List.SectionTemplate`, caché, avec un seul `SectionLabel` en texte enrichi (« ON DISPLAY <font color>2/8</font> ») : pas de `SectionCount` séparé ;
  - `List.Template.IconSlot.Odds`, caché ;
  - `Dock.Confirm`, caché : `Header.Title` « SELL ITEM? », `ItemSlot.ItemIcon`, `ItemRarity`, `ItemName`, `SellPrice`, `YesButton`, `NoButton`.
- **Téléphone** (script `tools/clement/ui_displayed_telephone.luau`, sauvegarde `MapBackups/2026-11-22_BoutonsFW/UI_Displayed_avantTelephone`) : sur un iPhone en paysage, la croix faisait 24 px, DISPLAY BEST 37 px et REMOVE / SELL 18 px. Des `UISizeConstraint` nommés `PhoneMin` les portent à 44 px au moins (en-tête, croix, DISPLAY BEST, lignes de 100 px, YES / NO de 48 px). Sur téléphone, la liste montre 2 lignes et défile ; sur PC, rien ne bouge.
- Vérifié en Play avec le code (4 min 30) : 19 objets exposés, icônes, raretés, $/s, REMOVE et DISPLAY BEST corrects. Les titres de section et SELL attendent le code.
- Captures : `displayed_v2_studio.png`, `displayed_v2_confirm_studio.png`, `displayed_v2_pc_couleurs.jpg`, `displayed_v2_telephone.jpg`, `displayed_v2_play.jpg`.

### Display à 125 %

- `UI_HUD.RightRail.DisplayedButton` : 0,5185 × 0,5385 (125 % de 0,4148 × 0,4308). Les tuiles zZz / x2 SPEED descendent à Y 0,7175.
- Script : `tools/clement/ui_hud_tuiles_rectangle.luau` (fin du script). Sauvegarde : `MapBackups/2026-11-22_HUD_Display125`.
- Vu en Play sur PC et en simulateur iPhone : rien ne se touche.

### Tous les boutons au style Framewisp

Script : `tools/clement/ui_boutons_style_framewisp.luau`. Sauvegardes : `MapBackups/2026-11-22_BoutonsFW/<écran>`. Rejouable : un second passage ne change rien.

| Écran | Boutons refaits |
| --- | --- |
| Boutique d'auras | 24 |
| Boutique d'armes | 25 |
| Boutique Robux | 21, et les 16 plaques « OWNED » |
| Boutique diamants | 7 |
| Récompenses | 7 |
| Index | 6 |
| Réglages | 4 (les curseurs MUSIC / SOUND restent à l'ancien style : ce ne sont pas des boutons) |
| Arbre de compétences | 3 |
| Roue, Aide / invitation, Hors ligne | 2 chacun |
| Renaissance | 1, avec ses 3 plaques d'état (`Disabled`, `Ready`, `Confirm`) |
| Tutoriel | 1 |

- Chaque bouton : rebord sombre `Lip`, face `Face` en dégradé de sa couleur d'origine, motif `Quilt` (`87198718489515`), liseré clair `Rim`, contour des textes `#0D0D14`. Les calques sont sous les textes (ZIndex du bouton moins 1).
- Couleurs harmonisées : un seul vert d'action (`#9AFF09`, celui des 64 boutons d'achat ; SPIN, CLAIM, REDEEM, DISPLAY et YES s'y alignent) et un seul rose pour toutes les croix (`#FF3D8B`, Displays compris).
- Petits défauts corrigés au passage :
  - **Roue** : l'ombre `ButtonShadow` passait sur SPIN et l'assombrissait ; elle est maintenant dessous ;
  - **Arbre de compétences** : même chose pour l'ombre `Shadow` de BUY, NEED et Close ;
  - **Renaissance** : le bas du bouton REBIRTH était rogné. La marge du corps passe dans sa taille, car la mise en page en flex ne la retirait pas ;
  - **Hors ligne** : CLAIM centré ;
  - **Index et boutiques** : le contour blanc de l'onglet choisi (`Selected`) prend l'arrondi du bouton.
- Pas touchés : les onglets à icône sans fond (Robux, diamants, récompenses), l'interrupteur VISUAL EFFECTS, les cartes de l'Index et de l'arbre, les choix du receleur (style de dialogue).
- Captures : `boutons_fw_robux.jpg`, `boutons_fw_rebirth.jpg`, `boutons_fw_skilltree.jpg`, `boutons_fw_wheel.jpg`, `boutons_fw_aura_telephone.jpg`, `boutons_fw_aura_play.jpg`. Sur téléphone, tous les boutons de la boutique d'auras font 44 px au moins.

### Textes des boutiques d'auras et de trails

- Toujours pas reproduits : en Play, boutique ouverte par l'invite du stand, tous les textes se lisent (`boutons_fw_aura_play.jpg`).
- **Cause probable, trouvée dans le code.** Dans l'ancien style, le reflet de `FramewispFx` (SheenFx) copiait le premier cadre peint du bouton, `Fill` (ZIndex 10), et passait un cran au-dessus (ZIndex 11), donc sur `Price` (ZIndex 10) : le texte disparaissait au passage du reflet.
- Dans le nouveau style, le premier cadre peint est `Lip`, sous les textes : le reflet ne doit plus les couvrir. À confirmer par Clément en jeu ; si ça recommence, c'est pour Ironix (point 5 ci-dessous).

### Copie Figma

Les 15 écrans changés sont remplacés dans la copie Figma (fichier « Steal a Shop — UI », page `214:369`) : HUD, Displays, roue, Renaissance, réglages, aide / invitation, tutoriel, hors ligne, diamants, récompenses, arbre de compétences, auras, armes, Robux et Index. Le nombre de cadres est égal au nombre d'éléments Studio pour chaque écran. Outils : `tools/clement/figma_copie`, sans nouvelle image à photographier.

### Pour Ironix

1. **SELL** (L-271) : montrer `Template.SellButton`. Le clic ouvre `Dock.Confirm`, rempli avec `ItemSlot.ItemIcon`, `ItemRarity`, `ItemName` et `SellPrice` (prix lu comme au receleur). `YesButton` vend côté serveur, après avoir retiré l'objet de son présentoir s'il est exposé ; `NoButton` ferme.
2. **Titres de section** : cloner `List.SectionTemplate` avant les objets exposés et avant l'inventaire, et écrire dans `SectionLabel` (texte enrichi) « ON DISPLAY x/y », puis « INVENTORY n ». `LayoutOrder` : les titres avant leurs lignes.
3. **`IconSlot.Odds`** (facultatif) : « 1 in N », sinon caché.
4. **`IconBack`** (facultatif) : la couleur de la rareté.
5. **Reflet SheenFx** : s'il passe encore sur un texte, le poser sous le plus bas des textes du bouton (aujourd'hui : copie du premier cadre peint, ZIndex + 1).
6. **FramewispFx** dit « pas de fond peint, pas de reflet » pour les boutons-images du HUD (`DisplayedButton`, `SleepButton`, la colonne téléphone `LeftRailTouch`) : leur fond est une `ImageLabel`. Facultatif : accepter une `ImageLabel` comme fond peint pour leur donner le reflet.
7. Le ContractChecker signale `UI_Displayed.Reserve` absent : c'est voulu (liste unique). Il ne lit pas encore `SectionTemplate`, `SellButton` ni `Confirm`.

### Texte centré sur la face des boutons (2026-11-22, après la remarque de Clément)

« L'ombre en dessous du bouton ne doit pas être prise dans l'alignement vertical. »

- **Le défaut.** Le contenu des boutons était centré sur le bouton entier, rebord sombre compris (milieu à 50 % de la hauteur). Il doit l'être sur la face claire, à 44 % : il était 5 à 6 px trop bas sur PC.
- **La correction.** Les textes, les icônes, `Content` et les ombres des textes de 124 boutons et plaques remontent, et le milieu de leur contenu tombe sur celui de `Face` : il ne reste aucun écart, sur 131 boutons mesurés. Les 8 `EquipButton`, dont le texte est porté par le bouton, ont une marge du bas plus grande de 12 points.
- **Où.** Passe ajoutée à la fin de `tools/clement/ui_boutons_style_framewisp.luau`. Sauvegarde : `MapBackups/2026-11-22_TexteCentre/<écran>`.
- **Captures.** `boutons_texte_centre_wheel.jpg` et `boutons_texte_centre_armes.jpg` ; vu aussi en simulateur iPhone.
- **Figma.** La copie n'a pas encore ce décalage.
