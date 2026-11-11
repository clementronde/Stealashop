# Argent hors ligne, poursuite, zone safe, barre du bas (2026-11-10, vidéo 2 de Clément)

Analyse complète : `docs/claude/notes/ui-reference-ressenti-2.md`. Tout est construit dans Studio, sans script, par `tools/clement/feel2_build.luau`. Prototype en Play : `tools/clement/feel2_proto.luau`. Rien n'est commité.

## Dans Studio

- **`StarterGui/UI_Offline`** (caché, `ScreenGroup = "Menu"`) : refait avec la DA du jeu (retour de Clément) : même fenêtre que `UI_Settings`, bandeau vert de la boutique Robux, boutons d'achat de `UI_WeaponShop`.
  - `Root.Window` : `Header.Title` « Offline Cash », `EarnedLabel`, `CashIcon`, `Amount`.
  - `ClaimButton` (vert) : `Content.ClaimLabel` « CLAIM », `Shade`.
  - `DoubleButton` (violet du `RobuxButton` des panneaux) : `Content.RobuxIcon`, `Content.PriceLabel` (« ??? » : le prix est à fixer), `TwoXTag` « 2x », `Shade`.
  - Pas de `CloseButton` : on sort en encaissant.
  - Les deux boutons sont centrés sur leur point (`AnchorPoint` 0,5) : au survol (× 1,06), ils gardent au moins 16 px d'écart, même sur téléphone.
  - `Flyer` (caché) : la case `Icon` et `FlyerAmount`, qui vole vers l'argent du HUD après Claim.
- **Boutons du HUD** : son `UI_Hover` au survol, clic `UI_Click_Classic` et `Shade` assombri (0,78), en plus du « pop » de `Motion.Hover`. Dans le prototype, rien n'était branché sans ces sons ; Clément croyait que la fenêtre hors ligne les coupait.
- **`StarterGui/UI_Toast`** (caché) : `Stack`, une pile en bas au centre, avec un `Template` caché (TextLabel) à cloner, 3 messages au plus.
- **`StarterGui/UI_Hotbar`** (caché) : la barre du bas maison, qui remplace la barre Roblox.
  - `Bar` contient un `Template` (TextButton carré) : `Clip` (avec `Glow`), `Icon`, `KeyLabel`, `ItemName`, `Income` (vert, au-dessus de la case), `Equipped` (contour vert) et `HoverOutline`.
- **`ReplicatedStorage/Assets/UI/BB_GuardShout`** : la bulle au-dessus du vigile.
  - `Bubble` (blanche) contient `ShoutLabel`, en rouge ; `Tail` est la pointe de la bulle ; `Bang` est le « ! » rose.
  - `AlwaysOnTop`, distance max 150 studs.
- **`UI_Escape.Flash`** : cadre doré plein écran, transparent au repos.
- **`UI_Inventory`** : le `$/s` (`Income`) des cartes d'objets est un peu plus grand (`ItemName` légèrement remonté).
- **`StarterGui/UI_Index_v3`** : enregistré (validé par Clément, fiche au clic). Voir `ui-index-v3.md`.
- **Sons** (Roblox, ProSoundEffects et APM) :
  - `Chase/Chase_Music` : APM « Police Chase », en boucle. Commencer à 1,5 s, après l'intro calme.
  - `Chase/Chase_Siren` : sirène synthétique APM, en boucle.
  - `Chase/Chase_Whistle` : sifflet de policier.
  - `Chase/Guard_Radio` : voix de radio de police.
  - `Heist/Heist_Grab` : coup de départ de la poursuite.
  - `Heist/Heist_SafeFlash` : éclat brillant à l'arrivée en zone safe.
  - `Cash/Offline_Claim` : encaissement.
  - `UI/UI_Equip` : objet équipé.

## Vérifié en Play (prototype)

- **Barre du bas** : 6 cases. `$22.5K/s` sur la couronne, `$1/s` sur le brocoli et l'épi de maïs (calculés par `Formulas.ItemIncome`). Les outils et les colis n'ont pas de `$/s`.
- **Inventaire** : les vrais objets avec leur `$/s`.
- **Écran hors ligne** : il s'ouvre au lancement.
- **Poursuite** : sons et bulle vus. La bulle était sur un PNJ du hub, faute de vigile chargé à côté.
- **Zone safe** : le flash et le zoom (champ de vision 70 → 82 → 70) fonctionnent.

## Pour Ironix

- **Argent hors ligne** : montrer `UI_Offline` au retour, à la place du Notify « Your shop earned … while you were away ».
  - Claim encaisse.
  - `DoubleButton` = produit développeur ×2 : le prix est à fixer ; le jeu de référence demande 49 Robux.
  - Après Claim : `Flyer` vole vers l'argent du HUD, `Offline_Claim` puis `Cash_Collect`, et « +$X » en vert à côté de l'argent.
- **`UI_Toast`** : les Notify de réussite (objet équipé, achat, colis en sécurité) en vert (`5dff3a`), les informations en blanc. Pop de 0,6 à 1 (Back, 0,2 s), 2,4 s à l'écran, effacement en 0,25 s.
- **`UI_Hotbar`** :
  - cacher la barre Roblox (`SetCoreGuiEnabled(Backpack, false)`) ;
  - une case par Tool, avec les touches 1 à 9, le clic ou l'appui ;
  - `Income` = `$/s` de l'objet (`ItemId`, `Rarity`, mutation) ;
  - `Equipped` sur l'outil en main ;
  - au survol, l'icône passe à × 1,12, penche de −6° et monte vers la droite, avec `HoverOutline` et `UI_Hover` ;
  - à l'équipement : `UI_Equip` et le message vert « <objet> equipped! ».
- **Poursuite** :
  - au départ : `Heist_Grab`, puis `Chase_Whistle` 0,15 s après ; `Chase_Music` (à partir de 1,5 s) et `Chase_Siren` en boucle, et la musique de zone baissée ;
  - cacher la barre de gauche et la barre du bas ;
  - `BB_GuardShout` sur la tête du vigile : `Bang` grossit (0 → 1,35 → 1) et tremble, puis une phrase toutes les 2,4 s. La bulle grossit de 0 à 1 en 0,2 s (Back), reste 1,6 s, puis rapetisse en 0,12 s ;
  - `Guard_Radio` une fois sur deux, à essayer.
- **Arrivée en zone safe** :
  - `UI_Escape.Flash` de 0,05 à 1 en transparence, en 0,5 s ;
  - champ de vision +12 en 0,08 s, puis retour en 0,45 s ;
  - `Heist_SafeFlash`, puis `Heist_Escape` 0,12 s après ;
  - arrêt des sons de poursuite ;
  - message vert « Box secured! Open it in your shop. ».
- **Bouton « Lâcher »** (vu dans la vidéo) : pas construit. Il faudrait d'abord décider si le joueur peut lâcher son colis.

## Tension après la casse, poursuite, bannière (2026-11-10, retours de Clément)

- **Musique de tension** : `ReplicatedStorage/Assets/Music/MUS_Heist`, en boucle, volume 0,4.
  - Elle est enregistrée avec « Ticking Tension B » (APM, 9038224813). En Play, on essaie « Stressful Countdown » (APM, 1839757863), qui monte tout de suite plus fort. À reporter dans Studio si Clément le garde.
  - **Pour Ironix** : ajouter `HeistTrack = "MUS_Heist"` dans `Config/Music`, joué par `MusicController` tant que le chrono du braquage est en cours (`HeistTimer`, après la casse de la vitre). Priorité : poursuite (`MUS_Chase`), puis braquage (`MUS_Heist`), puis camion, puis zone.
  - Dans le prototype, la musique de zone se tait pendant la tension.
- **`Chase_Music` retiré** : il faisait doublon avec `MUS_Chase`, déjà joué par `MusicController` pendant une poursuite.
- **Nouvel effet visuel de poursuite** : `UI_Chase.ScreenEdges` (`Left`, `Right`, `Bottom`), des bords rouges en dégradé comme dans la vidéo. Dans le prototype, pendant une poursuite :
  - `ScreenEdges` et `Vignette.Edge` battent à 1,6 fois par seconde (transparence de 0,1 à 0,6) ;
  - les gyrophares `SirenRed` et `SirenBlue` clignotent à tour de rôle toutes les 0,25 s ;
  - `Warning` (« GUARD! RUN! ») surgit de 0 à 1 (Back, 0,25 s), puis tremble de ± 2° ;
  - `FX_ChaseHighlight` (déjà dans `Assets/FX`, encore jamais utilisé par le code) est posé sur le vigile ;
  - la caméra s'élargit de 6 en 0,3 s, puis revient en 0,4 s à la fin de la poursuite. À l'arrivée en zone safe, elle revient d'un coup, avant le zoom de la zone safe.
- **`UI_Escape`** : `Banner.Rays` et `Banner.Glow` retirés à la demande de Clément : on voyait leurs bords.
- **Message en double** : à l'arrivée en zone safe, le Notify « Box saved to your inventory… » s'affiche en même temps que la bannière ESCAPED! et passe dessous. Le message vert du bas (`UI_Toast`) dit déjà la même chose : ne pas montrer ce Notify-là.

## Encore à faire côté Clément

- **`BB_GuardShout`** : une taille minimale pour qu'elle reste lisible de loin (taille en studs plus un décalage en pixels).
- **Une vraie sirène de police** : rien dans les bibliothèques sous licence. Une vidéo ou un son de référence de Clément aiderait.
- **Les noms ci-dessus** sont à valider avant le contrat 2.2 et 10.4.
