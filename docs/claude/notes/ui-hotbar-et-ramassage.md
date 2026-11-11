# Barre d'inventaire du bas et ramassage d'argent (2026-11-11)

## 1. `UI_HUD.Hotbar` : maquette Figma, à valider par Clément

Rien n'est construit dans Studio.

- **PC 1920 × 1080** : https://www.figma.com/design/fXjkvf39sRhlsL94YicwDH?node-id=83-1342
- **Téléphone 844 × 390** : https://www.figma.com/design/fXjkvf39sRhlsL94YicwDH?node-id=84-1350
- **États d'une case** (Hover, Press, Équipée) : https://www.figma.com/design/fXjkvf39sRhlsL94YicwDH?node-id=83-1429
- **Noms lus par le code** : https://www.figma.com/design/fXjkvf39sRhlsL94YicwDH?node-id=84-1428

Noms proposés :

- `Hotbar` (en bas au centre), qui contient `Slots` (UIListLayout horizontal) et `BagButton`.
  - Attributs : `SlotCount` = 6 (PC) et `TouchSlotCount` = 4 (téléphone).
- `Slots.Template` : TextButton caché, cloné par le code. L'ordre des cases : outil de casse, batte, puis les colis et objets, du plus récent au plus ancien.
- Chaque case contient :
  - `Icon` ;
  - `Rarity` : le liseré, dont le code règle la couleur dans `BackgroundColor3` et dans son `UIStroke` ; gris clair `CFD6E0` pour les outils ;
  - `KeyLabel` (caché sur téléphone) ;
  - `Income` (objets seulement) ;
  - `Equipped` : contour blanc et halo vert ;
  - `Shade`.
- `BagButton` : `Icon`, `Label` « INVENTORY » (caché sur téléphone) et `Shade`. Il ouvre `UI_Inventory`.
- **Taille** : une case fait 7,2 % de la hauteur de l'écran, et au moins 46 px.
  - PC : 78 px.
  - Téléphone : 46 px. La barre tient entre `StatsPanel` et `NightCountdown`, loin du bouton de saut et du joystick.
- **Animations** : Hover, Press et Release sur chaque case. Success quand une case s'équipe. La case tenue passe à × 1,1.
- **À regarder avec Clément** :
  - Sur un petit téléphone (667 × 375), il n'y a que 172 px libres entre `StatsPanel` et `NightCountdown` : la barre y touche `StatsPanel`.
  - Sur téléphone, le bouton de saut de Roblox (749 à 819 × 300 à 370) passe déjà sur `NightCountdown` et `SocialRow`. Ce n'est pas lié à la barre.

## 2. Ramassage : plus de case carrée, `BB_Gain` plus petit

- **Fait dans Studio (Edit)**, avec le script `tools/clement/gain_smaller_no_cashfly.luau` :
  - `BB_Gain.Size` passe de {4,5 ; 70}, {1,2 ; 20} à {2,7 ; 42}, {0,72 ; 12}, soit 60 % de sa taille. À 12 studs, sur un écran 1080p, ça fait environ 215 × 58 px ;
  - `UI_HUD.CashFly.Template` est supprimé ; `CounterPop` reste en place ;
  - aucun script.
- **Tableau des animations mis à jour** (`docs/claude/notes/ui-motion-skilltree.md`) :
  - `FloatGain` : nouvelle taille ;
  - `CashFly` et `CounterPop` : rayés ;
  - à l'arrivée, il reste `CashBump` et `Roll`.
- **Pour Ironix** (`GainController`) :
  - Sans `CashFly.Template`, son code écrit un avertissement une fois (« Template absent »), fait seulement sursauter le compteur, et ne joue plus le son `Cash_Collect`.
  - Il faut retirer la case du code. Il faut aussi jouer `Cash_Collect` au moment du « +$X » au-dessus du joueur.
  - La même case servait aux récompenses (Claim) : elles ne volent plus non plus.
