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
