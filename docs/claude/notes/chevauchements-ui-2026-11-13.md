# Chevauchements de l'UI en jeu (2026-11-13)

Demande de Cantin : la liste de **tous** les textes ou blocs de l'UI qui se superposent vraiment en jeu, et pour chacun, quand chaque élément doit apparaître.

Sources :
- les rectangles mesurés en Play sur des copies des écrans, à 1920 × 1080, 1366 × 768 et 844 × 390 (téléphone paysage) ;
- la capture du HUD dans Studio, à 940 × 816 ;
- le code des contrôleurs (`src/client/Controllers`) et des services (`src/server/Services`) ;
- les scripts de construction de Clément (`tools/clement/feel2_build.luau`, `zonebanner_top_build.luau`).

Rien n'a été modifié dans le code ni dans Studio.

Classes :
- **A** : le code peut régler le problème sans toucher au visuel (masquer, retarder ou mettre en file l'un des deux). Il faut la décision de Cantin.
- **B** : c'est un problème de placement, que seul Clément peut régler (déplacer, réduire).
- **C** : ce n'est pas un vrai problème.

Déjà en cours dans la session principale, donc pas repris ici : **« HEIST: 7s » masqué tant que le joueur est poursuivi** (`HeistTimer` × `RunBanner`).

---

## 1. Les trois bandeaux du haut au centre : RUN!, bandeau de zone, chrono

Ils occupent presque le même rectangle. À 1920 × 1080 :

| Élément | Rectangle |
| --- | --- |
| `UI_ZoneBanner.Banner` | 730..1189 × 4..138 |
| `UI_Chase.RunBanner` | 803..1116 × 37..145 |
| `UI_HUD.HeistTimer` | 775..1144 × 37..156 |

### 1.1 RUN! × bandeau de zone (`UI_Chase.RunBanner` × `UI_ZoneBanner.Banner`) : classe A

**Quand RUN! est visible**
- Pendant toute la poursuite.
- `ChaseController.luau:147-169` (remote `ChaseState`) et `:237-261` (`UI_Chase` allumé tant que `active`).
- Côté serveur, la poursuite ne finit qu'en zone safe, à la capture ou quand le portage s'arrête (`GuardService.luau:50` et `:1086-1102`). C'est valable de jour, de nuit et avec les conducteurs du camion.

**Quand le bandeau de zone est visible**
- À chaque passage d'arche vers une zone de 1 à 6, dans les deux sens.
- `ZoneBannerController.luau:278-282`, puis `Show` (`:233-262`).
- Il reste 3,95 s à l'écran : 0,35 s d'apparition, 3 s plein, 0,6 s de disparition (`UiMotion.luau:289-294`).

**Scénario.** Le joueur vole un objet en zone 3, le vigile le poursuit, et il rentre au hub. À l'arche 3 → 2, puis à l'arche 2 → 1, le bandeau de zone (« LONDON », Speed, Damage, Easy/Hard) s'affiche sous RUN! pendant 4 s à chaque fois. En arrivant au hub (zone 0), rien ne s'affiche. Ce cas arrive à presque chaque vol réussi.

**Proposition.** Le bandeau de zone cède. Pendant une poursuite (`ChaseController.IsChased()`), il ne s'affiche pas. Il n'y a rien à rattraper après : la poursuite finit au hub, où il n'y a pas de bandeau.

### 1.2 Bandeau de zone × chrono (`UI_ZoneBanner.Banner` × `UI_HUD.HeistTimer`) : classe A

**Quand le chrono est visible**
- `HudController.luau:368-422` : `Motion.Show` à la ligne 412 dès qu'un chrono court.
- Le serveur l'envoie dans deux cas :
  - à tout joueur sans colis à **60 studs ou moins** d'un magasin ouvert, même s'il ne fait que passer pendant le vol d'un autre (`StoreHeistService.luau:547` et `:1717-1731`) ;
  - au joueur qui est entré dans le magasin, même s'il porte un objet (`:1720`) ;
  - au joueur qui frappe une vitrine, pour le chrono de casse de 13 s (`WindowService.luau:580-590` ; `Balance.luau:54`).

**Scénario.** Cantin marche dans le couloir. Un autre joueur braque le premier magasin de la zone 2, juste après l'arche. Le chrono « HEIST: 7s » s'affiche, car Cantin est à moins de 60 studs. Au même moment, il passe l'arche et le bandeau de zone recouvre le chrono. Le même cas se produit quand il sort d'un magasin qu'il vient d'ouvrir et repasse une arche pendant les 10 s.

**Proposition.** Deux règles possibles :
- **(a)** Le bandeau de zone attend que le chrono disparaisse (10 à 13 s au plus), puis s'affiche si le joueur est toujours dans cette zone.
- **(b)** Il ne s'affiche pas du tout.

Il vaut mieux garder le chrono : pour celui qui braque, c'est l'information qui compte.

### 1.3 RUN! × chrono : en cours dans la session principale

Rien à ajouter.

## 2. L'alerte de vol (`UI_TheftAlert.Banner`)

**Quand elle est visible**
- Du début à la fin d'un vol ou d'une intrusion chez le joueur. Elle peut donc durer longtemps.
- `TheftAlertController.luau:1-12` et `:364` (`Motion.Open`) ; le remote `TheftAlert` est branché à la ligne 748.
- À 1920 × 1080, elle occupe 506..1414 × 161..359. Sur téléphone : 183..660 × 74..169.

### 2.1 Alerte de vol × bandeau de zone (téléphone) : classe A

**Mesure.** Le chevauchement fait 308 × 19 px à 844 × 390. C'est le bas du bandeau de zone, donc la ligne « Easy/Hard », sur le haut de la bannière rouge.

**Scénario.** La boutique de Cantin est braquée pendant qu'il est en zone 3. Il court la défendre. À chaque arche passée vers le hub, le bandeau de zone s'allume par-dessus l'alerte.

**Proposition.** La même règle que pour RUN! : pas de bandeau de zone tant que l'alerte de vol est affichée.

### 2.2 Alerte de vol × arrivée en zone safe (`UI_TheftAlert.Banner` × `UI_Escape.Banner`) : classe A

**Quand l'écran d'arrivée est visible**
- Pendant environ 2,8 s quand le joueur entre en zone safe avec un colis (remote `BoxSecured`).
- `UiFeelController.luau:616` → `Escape` (`:546`), l'écran est allumé à la ligne 478 ; `Hold` = 2,3 s (`UiMotion.luau:281`).

**Mesure.** Le chevauchement fait 13 px à 1920, 27 px à 1366 et **62 px sur téléphone** (`TheftAlert` 74..169, `Escape` 106..221).

**Scénario.** Cantin rapporte un colis au hub pendant qu'un joueur pille sa boutique. La bannière « ESCAPED » arrive par-dessus l'alerte rouge.

**Proposition.** L'alerte de vol reste devant, parce qu'elle est urgente. Deux façons de faire céder l'arrivée :
- **(a)** jouer l'arrivée sans sa bannière (garder le flash, le son et les confettis) ;
- **(b)** la décaler jusqu'à la fin de l'alerte. C'est moins bien, parce que l'alerte peut durer longtemps.

### 2.3 Alerte de vol × RUN! et × chrono (téléphone) : classe C

Le contact fait 4 px, bord contre bord, dans les marges des cadres.

## 3. Les messages du bas (`UI_Toast.Stack`)

Le cadre mesuré, 268..1651 × 712..928 à 1920, est bien plus grand que ce qui s'affiche. Voici où les messages s'affichent vraiment :
- `NotifyController.luau:417-446` envoie tous les messages dans `UI_Toast`.
- `UI_Notify` ne sert que de repli si `UI_Toast` manque (`:306` et `:330`). Comme `UI_Toast` est livré, **`UI_Notify` n'est jamais affiché**.
- Construction de Clément (`feel2_build.luau:132-135`) :
  - `Stack` est ancré en bas, à 86 % de la hauteur, sur 72 % de la largeur et 20 % de la hauteur ;
  - son `UIListLayout` aligne les messages en bas ;
  - chaque message (`Template`) fait toute la largeur et 24 % de la hauteur du cadre, avec `TextScaled` et `TextWrapped`.
- Il y a au plus 3 messages à la fois, chacun visible 2,4 s (`UiMotion.luau:146-153`).
- Les lignes réelles, à 1920 × 1080 :
  - 1er message : 876..928 ;
  - 2e : 822..874 ;
  - 3e : 768..820.
- Le texte est centré. Un message court reste au milieu. Un message long (40 caractères ou plus) s'étale sur toute la largeur.

### 3.1 Messages longs × boutons Invite / Rewards / Settings (`UI_Toast` × `UI_HUD.SocialRow`) : classe B

**Mesure.** `SocialRow` occupe 1495..1879 × 826..928 à 1920. Les deux premières lignes de messages tombent à cette hauteur. Un message d'environ 40 caractères ou plus arrive jusqu'à x = 1495 et s'écrit par-dessus les boutons. Il y en a beaucoup :
- « Item secured! Put it down in your shop to start its anti-theft. » ;
- « Night guards are out: get back to the safe zone! » ;
- « Inventory full: display or sell an item before opening this box. »…

Ça arrive aux trois résolutions. Les boutons restent cliquables, car le texte ne capte pas les clics.

**Pour Clément.** Rétrécir `Stack` (par exemple de 72 % à environ 50 % de la largeur, pour qu'il tienne entre `StatsPanel` et `SocialRow`) ou le remonter au-dessus de `SocialRow`.

### 3.2 Messages × prix « $/s » des cases de la barre du bas (téléphone) : classe B

La mesure ne l'avait pas vu, parce que le libellé `Income` dépasse au-dessus du cadre `Bar`.

**Mesure.** Sur téléphone, en 844 × 390 :
- le 1er message occupe 316..335 ;
- le libellé « $300/s » de chaque case occupe environ 316..332 : il est ancré au-dessus de la case, à 32 % de sa hauteur (`feel2_build.luau:157`).

Le texte du message s'écrit donc sur les prix des cases du milieu. À 1366 et 1920, il reste un écart (11 px et plus).

**Pour Clément.** Remonter `UI_Toast.Stack` sur téléphone, d'au moins 20 px (environ 5 % de la hauteur).

### 3.3 Messages × bulle du tutoriel (`UI_Toast` × `UI_Tutorial.Bubble`) : classe A, ou B

**Quand la bulle est visible**
- Pendant tout le tutoriel.
- Elle ne se cache que derrière `UI_Unbox`, `UI_WeaponShop` et `UI_AuraShop` (`TutorialController.luau:56` et `:172`).

**Mesure.** La bulle occupe 745..864 à 1920, 529..614 à 1366 et 251..312 sur téléphone. Le 1er message passe juste en dessous. Le **2e et le 3e** tombent sur la bulle, aux trois résolutions.

**Scénario.** Pendant le tutoriel, deux messages arrivent coup sur coup, par exemple :
- un refus et une alerte ;
- « Item secured!… » suivi d'un autre message.

Le 2e message s'écrit sur la consigne du tutoriel.

**Propositions.**
- **(A)** Tant que la bulle du tutoriel est affichée, un seul message en bas à la fois : les suivants attendent leur tour.
- **(B)** Clément remonte la bulle d'environ 10 % de la hauteur.

### 3.4 Messages × `StatsPanel` : classe C

Sur les lignes des messages, `StatsPanel` ne contient que les lignes Force et Vitesse, collées à gauche (texte court). La partie qui chevauche est le vide à droite de son cadre. Un texte centré ne peut pas descendre jusqu'à x ≈ 200.

### 3.5 Toutes les paires de `UI_Notify.Stack` : classe C

`UI_Notify` n'est jamais affiché tant que `UI_Toast` est là. Ces paires sont : × TheftAlert, × Escape, × Toast, × Hotbar, × Offline, × PawnShop, × bulle du tutoriel.

### 3.6 Messages × `UI_Offline.Flyer` : classe C

Le `Flyer` n'est jamais utilisé (`OfflineController.luau:27`).

## 4. La barre d'objets × l'argent et « Night in » (`UI_Hotbar.Bar` × `UI_HUD.StatsPanel` / `NightCountdown`) : classe B

**Ce qui chevauche vraiment.** Le cadre `Bar` fait 62 % de la largeur, mais ses cases sont centrées :
- sur PC : 6 cases carrées de 8,2 % de la hauteur, espacées de 8 px ;
- sur téléphone et tablette (tactile sans clavier) : 4 cases (`HotbarController.luau:414-422`).

Selon le format de l'écran :
- **1920 × 1080 et 1366 × 768 (16:9)** : les cases occupent 676..1244 à 1920. Elles ne touchent ni l'argent (`StatsPanel` finit à 654) ni « Night in » (qui commence à 1472). Le chevauchement mesuré ne concerne que le cadre vide.
- **Téléphone 844 × 390** : les 4 cases occupent environ 310..534 et ne touchent rien.
- **Écrans moins larges** : `StatsPanel` suit la largeur de l'écran et les cases suivent sa hauteur. Les cases passent donc sur l'argent et le « +$/s » (et sur `CounterPop`), comme sur la capture 940 × 816, où « $212B » est recouvert :
  - fenêtre Studio ;
  - jeu en fenêtre ;
  - 16:10 (1440 × 900, MacBook) : ça frôle ;
  - 4:3 et 5:4 (1280 × 1024) : environ 250 px de chevauchement.

  En 5:4, elles touchent aussi « Night in ». Sur iPad (4 cases), ça passe.

**Pour Clément.** C'est l'argent, l'information la plus importante du HUD. Deux pistes :
- limiter la largeur de `StatsPanel` et de `NightCountdown` par la hauteur (`UIAspectRatioConstraint` ou `UISizeConstraint`) ;
- réduire les cases quand l'écran est étroit.

Côté code, il serait possible de montrer 4 cases au lieu de 6 sur un écran étroit. C'est à proposer à Clément, pas à faire sans lui.

## 5. Le dialogue du receleur × le bouton « BASE » (`UI_PawnShop.Dialog` × `UI_HUD.ReturnBaseButton` / `AdminButton`) : classe A

La mesure l'avait trouvé, mais il n'était pas dans la liste de départ.

**Quand le dialogue est visible.** Tant que le joueur est sur la plaque du receleur, au hub (`PawnShopController.luau:597-608`).

**Quand le bouton BASE est visible.** Toujours, car `Features.ReturnToBase` vaut true. `AdminButton` ne s'affiche que pour un admin (`AdminController.luau:7`).

**Mesure.**

| Résolution | Dialogue | Bouton BASE | Chevauchement |
| --- | --- | --- | --- |
| 1920 × 1080 | 1286..1862 × 388..615 | 1755..1879 × 459..583 | 106 × 124 |
| 1366 × 768 | | | 76 × 88 |
| 844 × 390 | | | 52 × 60 |

Les choix du dialogue passent sur le bouton BASE à chaque visite chez le receleur, et un appui peut tomber sur le mauvais bouton.

**Proposition (A).** Cacher `ReturnBaseButton` (et `AdminButton`) tant que le dialogue du receleur est ouvert. Le joueur est déjà au hub, donc le bouton n'y sert à rien.

Autre solution (B) : Clément déplace `Dialog` vers la gauche.

## 6. UI créée par le code ou par Roblox

| Élément | Où | Ce qui peut arriver | Classe |
| --- | --- | --- | --- |
| Bouton « Drop » de ContextActionService (téléphone, pendant le portage) | `DropController.luau:72-82` : 70 px, placé par Roblox autour du bouton de saut tant que `UI_HUD.DropButton` n'est pas livré | Sur 844 × 390, le bouton de saut occupe environ 749..819 × 300..370. Le bouton Drop se pose en haut à gauche de celui-ci, donc probablement sur `SocialRow` (657..826 × 298..335). **À vérifier en émulation téléphone.** | **B** : c'est la demande L-125 a) à Clément (`UI_HUD.DropButton` bien placé). Choisir une position dans le code serait un choix visuel. |
| Bouton de saut de Roblox | Interface tactile de Roblox | Il passe déjà sur `NightCountdown` et `SocialRow` sur téléphone (relevé de Clément, `docs/claude/notes/ui-hotbar-et-ramassage.md`) | **B** (Clément) |
| Lignes des potions « Speed 1:42 » (affichage V0) | `PotionController.luau:65-67` et `:395-412` : lignes de 20 px empilées au-dessus de `StatsPanel` | Sur téléphone, avec 3 potions actives ou plus, la ligne du haut touche le bas de `LeftRailTouch` (jusqu'à 22 px) | **B** : `UI_HUD.PotionBar` de Clément remplace ce V0 |
| Compteur « ×N LUCK » (`BB_ShelfOpen`) | `ShelfOpenController.luau:394-423` : billboard sur le colis, 3,2 studs au-dessus, toujours devant | `BB_Box` (« Premium Box ») reste allumé sur le même colis jusqu'à la sortie de l'objet (`:559`) : les deux étiquettes peuvent se superposer selon leurs décalages. Cantin a testé l'ouverture sans le relever. **À vérifier d'un coup d'œil.** | **A** si c'est gênant : couper `BB_Box` dès le début de l'ouverture |
| Pastilles « ! » (AlertBadge) | `RailAlertController`, `IndexController`, `RewardsController` : battement × 1,15 | Elles débordent un peu au coin de leur bouton, comme voulu par Clément | **C** |
| Voile `UI_HUD.RevealTint` | `ShelfOpen/Logic.luau:172-175` : plein écran, 0,55 s, Épique et plus | Couvrir tout l'écran est le but | **C** |
| Étiquettes au-dessus des objets exposés (`BB_Item`) | Monde 3D (capture : « Statue of Liberty », « Gold B… EPIC ») | Elles se superposent entre elles et derrière `LeftRail`. Ce sont des étiquettes du monde, pas l'UI de l'écran. | Hors sujet (à revoir à part si Cantin le veut) |

## 7. Cas écartés (C)

- **`UI_HUD.GuardMeter`** : toujours caché (`HudController.luau:213` et `:574-575`).
- **Écrans modaux** (Inventory, Index, Shop, Rebirth, Rewards, Settings, SkillTree, Unbox, Offline à l'arrivée) : ils couvrent volontairement le HUD. `UI_Offline` ne s'affiche qu'à la connexion, où il n'y a ni poursuite, ni chrono, ni bandeau de zone.
- **Bulle du tutoriel × `StatsPanel`** (27 × 59 px à 1920) : c'est le coin vide en haut à droite du cadre, sans texte.
- **Bulle du tutoriel × dialogue du receleur** (téléphone, 6 px) : contact de bord.
- **Arrivée en zone safe × dialogue du receleur** (téléphone) : il faudrait monter sur la plaque dans les 2,8 s de l'arrivée.
- **Alerte de vol × dialogue du receleur** (téléphone, 63 px) : c'est réel, mais l'alerte doit passer devant tout. À revoir seulement si Cantin trouve ça gênant.

---

## Questions pour Cantin

1. **Bandeau de zone pendant une poursuite.** Quand tu cours avec RUN! à l'écran et que tu passes une arche, le bandeau de la zone (nom de la ville, vitesse et dégâts conseillés) doit-il :
   - ne pas s'afficher du tout ;
   - s'afficher quand même par-dessus RUN! ?

   Proposé : ne pas s'afficher.

2. **Bandeau de zone et chrono « HEIST ».** Quand le chrono d'un braquage est affiché (le tien, ou celui d'un magasin près duquel tu passes) et que tu passes une arche, le bandeau de zone doit-il :
   - attendre la fin du chrono, puis s'afficher si tu es toujours dans la zone ;
   - ne pas s'afficher ;
   - s'afficher quand même par-dessus le chrono ?

   Proposé : attendre la fin du chrono.

3. **Bandeau de zone pendant l'alerte « on vole ta boutique ».** Pendant que l'alerte rouge est affichée, le bandeau de zone doit-il :
   - ne pas s'afficher ;
   - s'afficher quand même ?

   Proposé : ne pas s'afficher, comme pour RUN!.

4. **Arrivée au hub avec un colis pendant l'alerte rouge.** Si tu rentres avec un colis pendant qu'on vole ta boutique, l'écran « ESCAPED » doit-il :
   - se jouer sans sa bannière (flash, son et confettis seulement) ;
   - attendre la fin de l'alerte ;
   - se jouer en entier par-dessus l'alerte ?

   Proposé : sans sa bannière.

5. **Messages du bas pendant le tutoriel.** Pendant le tutoriel, quand deux messages arrivent en même temps en bas de l'écran, le 2e cache la consigne du tuto. Faut-il :
   - n'afficher qu'un message à la fois pendant le tuto (le suivant attend son tour) ;
   - demander à Clément de remonter la bulle du tuto ?

6. **Receleur et bouton BASE.** Quand tu parles au receleur, ses choix passent sur le bouton BASE à droite. Faut-il :
   - cacher le bouton BASE pendant que tu parles au receleur ;
   - demander à Clément de déplacer le dialogue ?

   Proposé : cacher le bouton.

7. **Étiquette du colis pendant l'ouverture (à regarder en jeu).** Quand tu ouvres un colis sur le rayon, est-ce que « ×N LUCK » et le nom du colis (« Premium Box ») se chevauchent ? Si oui, faut-il cacher le nom du colis dès le début de l'ouverture ?

Pour Clément (classe B), à mettre dans la liaison si Cantin est d'accord :
- **Messages du bas** : moins larges, ou plus hauts, pour ne plus passer sur Invite / Rewards / Settings. Sur téléphone, remontés d'au moins 20 px pour ne plus couvrir les « $/s » des cases.
- **Barre d'objets et argent** : sur les écrans moins larges que le 16:9 (fenêtre, 16:10, 4:3), les cases couvrent l'argent et touchent « Night in ».
- **`DropButton` et `PotionBar`** : à livrer, déjà demandés.
- **Bouton de saut de Roblox** : il passe sur `NightCountdown` et `SocialRow` sur téléphone.
