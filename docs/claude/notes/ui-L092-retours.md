# Réponses UI à L-092 (2026-11-11)

Fait pour Clément dans Studio (Edit), sans script. Rien n'est commité.

## 1. Inventaire : 4 onglets

- **Ordre, de haut en bas** : `ItemsTab`, `BoxesTab`, `PotionsTab`, `ToolsTab`, dans `UI_Inventory.Root.Tabs` (`LayoutOrder` 1 à 4). Chaque onglet contient `TabIcon`, `TabLabel`, `Shade` et `Selected`.
- **Correction (2026-11-11, plus tard)** : les noms **restent `ToolsTab` et `ToolsSection`**. Seuls le texte (« WEAPONS ») et l'icône changent.
  - Le renommage en `WeaponsTab` et `WeaponsSection` avait cassé l'onglet en Play : le code et `Contract/UI.luau` lisent `ToolsTab` et `ToolsSection`. Il y avait deux lignes rouges du ContractChecker.
  - Cet onglet regroupe l'outil de casse et la batte. Son icône est `ICON_TOOL_Bat` (119130868634894) ; dans les cartes, la batte prend aussi `ICON_TOOL_Bat`.
  - **Rien à changer pour Ironix** : il n'y a pas de nouveau nom.
- **Chevauchement à 940 × 816** : la fenêtre prenait toute la largeur et les onglets sortaient de l'écran à droite, jusqu'à x = 977, sur le bouton BASE.
  - Les onglets sont maintenant **dans** `Root` : `Root` a un rapport de 1,697 au lieu de 1,536, la fenêtre en prend 87 % et les onglets les 9,5 % de droite. `Root` revient au centre (X 0,5).
  - La fenêtre garde sa taille à l'écran, et `Root` tient toujours dans l'écran, onglets compris.

## 2. Contrat de `UI_Escape` (pour le 2.2, animation `SafeFlash`)

- `UI_Escape` (ScreenGui, caché, sans `ScreenGroup`) :
  - **`Flash`** : Frame plein écran, doré `ffd94a`, transparence 1 au repos, derrière tout (ZIndex 0) ;
  - **`Banner`** : Frame au centre, qui contient **`Title`** (« ESCAPED! »), **`Subtitle`** (« Take the box to your shop! ») et **`BoxIcon`** (ImageLabel, l'icône `ICON_BOX_<Tier>` du colis).
- `Rays` et `Glow` sont retirés : Clément ne veut plus d'effet de fond.
- **Animation** (tableau `ui-motion-skilltree.md`) :
  - `Flash` passe de 0,05 à 1 de transparence en 0,5 s ;
  - champ de vision + 12 en 0,08 s, puis retour en 0,45 s ;
  - `Banner` passe de 0 à 1 en 0,35 s (Back Out), `Title` de −14° à −3°, puis `BoxIcon` et `Subtitle` arrivent 0,07 s l'un après l'autre ;
  - au bout de 2,3 s, `Banner` rapetisse à 0 en 0,15 s, puis l'écran s'éteint.
- **Sons** : `Heist_SafeFlash`, puis `Heist_Escape` 0,12 s après.

## 3. Fumée grise pendant la poursuite : c'est le code

- **Cause** : `UiFeelController.collectPulses` fait battre la transparence du fond de chaque cible de `UiMotion.ChasePulse.Targets` qui n'a pas d'image. Pour la cible `"ScreenEdges"`, c'est le cadre **conteneur** plein écran, au fond gris par défaut (`a3a2a5`, transparence 1 au repos). Il descend à 0,1 de transparence : un voile gris sur tout l'écran.
- **À écrire à Ironix** : dans `Config/UiMotion`, mettre `ChasePulse.Targets = { "ScreenEdges.Left", "ScreenEdges.Right", "ScreenEdges.Bottom", "Vignette.Edge" }`. Ce sont les trois bords rouges, et la ligne rouge du bandeau du haut.
- **La version de Clément est bien enregistrée** dans `StarterGui/UI_Chase`, et pas seulement en Play : `Vignette` (bandeau rouge en haut, avec `Edge`), `ScreenEdges` (`Left`, `Right`, `Bottom`, en dégradé rouge `ff1e1e`) et `RunBanner` (« RUN! », avec `RunLabel`). L'ancien bloc `Alarm` est retiré.
- **Le contour rouge du vigile** n'est pas encore dans le code : poser `Assets/FX/FX_ChaseHighlight` (Highlight rouge, `AlwaysOnTop`) sur le vigile pendant la poursuite, et le retirer à la fin.

## 4. Chrono sous 3 s

Le chiffre de `UI_HUD.HeistTimer` (`TextColor3`) passe en rouge `E8413C`. C'est noté dans le tableau, ligne `TimerTick`.

## 5. `BB_Gain` : un seul modèle

- `ReplicatedStorage/Assets/UI/BB_Gain` : le code règle l'attribut **`GainKind`** (`Speed`, `Power` ou `Cash`, `Speed` par défaut), puis lit sur le modèle la couleur et l'icône du même nom :
  - `SpeedColor` `4fd2ff`, `SpeedIcon` 80577187405028 ;
  - `PowerColor` `ff7a3a`, `PowerIcon` 84783828444327 ;
  - `CashColor` `5cff4a`, `CashIcon` 138179722277427.
- Le code écrit `Row.Amount.Text` (« +2 Speed/s », « +5 Power », « +$1.2K »), met `<Kind>Color` dans `Row.Amount.TextColor3` et `<Kind>Icon` dans `Row.Icon.Image`. Clément peut changer couleurs et icônes sans toucher au code.

## 6. `UpgradeSign`

- **Mêmes noms, même pivot** (en bas au centre, `PrimaryPart = Foot`), même `SignGui` : rien ne change pour `UpgradeController`.
- **Plus petit** :
  - `Board` : 4,6 × 3 × 0,3 studs, au lieu de 7 × 4,5 × 0,45 ; le haut à 4 studs du sol ;
  - `Foot` : un pied fin de 0,36 stud ; `FootBase` : un petit socle de 1,4 × 0,16 × 0,9.
- **Plus propre** :
  - `SignGui` à 100 px par stud (460 × 300) ;
  - bord du panneau à 4 px ;
  - reflets `Gloss` des deux boutons retirés ;
  - `Title` en haut, `Level` en vert `5cff4a` ;
  - `BuyButton` vert (prix) et `RobuxButton` violet.
- Les textes tiennent (vérifié à 460 × 300) et il n'y a aucun script.
- Appliqué au modèle `Assets/UI/UpgradeSign` et aux 24 aperçus de `Workspace/_PREVIEW_UpgradeSigns`.
- Script : `tools/clement/upgradesign_restyle.luau`.
