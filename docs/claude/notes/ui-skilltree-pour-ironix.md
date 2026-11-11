# Arbre de compétences : liste pour la liaison (2026-11-11)

Noms relevés dans Studio le 2026-11-11. L'écran est construit, mais rien ne l'ouvre, et aucun code ne le lit. « T.n » = ligne n de `docs/claude/notes/ui-motion-skilltree.md`. Il n'y a aucun script dans l'UI. Rien n'est commité.

## 1. L'écran

1. `StarterGui/UI_SkillTree` (`ScreenGroup=Menu`, `IgnoreGuiInset`, `DisplayOrder` 5) : écran plein, maquette v3 validée par Clément (Figma `48:748` et `49:900`).
   - Ouverture : T.54 (« bop bop bop », de la tuile centrale vers les anneaux). Fermeture : T.28.
   - `StarterGui/UI_SkillTree_v2_old` est l'ancienne version : à supprimer, ne pas la brancher.
2. **Bouton qui l'ouvre : —.** Le HUD n'a aucun bouton d'arbre. Les bornes de la boutique (`UpgradeKiosk`) ont été retirées le 2026-11-10. C'est à Clément de décider : un bouton dans `LeftRail`, ou un point dans la boutique.
3. Hors de l'arbre :
   - `Backdrop` (`Light`, `Studs`) bloque les clics vers le jeu ;
   - `CashPill.Cash` affiche l'argent : il défile (T.15 `Roll`) et sursaute (T.16) ;
   - `Hint` et `HelpLabel` : textes fixes ;
   - `CloseButton` (`CloseLabel`, `Shade`) ferme l'écran (T.30 à T.32).
4. `Tree` : le code le déplace (`Position`, en Offset) et le zoome (`UIScale`).
   - Glisser : T.67. Limite du glisser : T.68. Molette : T.69. Pincement : T.70. Zoom de 0,75 à 1,8 : T.71. Zoom à l'ouverture : T.72.
   - Une couche `NavLayer` est posée par le code (T.74). L'écran a `IgnoreGuiInset` : ajouter `GetGuiInset()` à `input.Position`.
5. Les tuiles sont des TextButton `Tree.Tile_<Id>`, avec les attributs `Q` et `R` (coordonnées dans la grille hexagonale). Chacune contient :
   - `Shadow` ;
   - 3 calques d'état, chacun avec `Rim`, `Body` et `Gloss` :
     - `Bought` : bord doré ;
     - `Available` : achetable ;
     - `Locked` : avec `Mystery` « ? », `LockedName` « ??? » et `LockedLabel` « LOCKED » ;
   - `Info` (caché quand la tuile est verrouillée) : `Level` « Lv 2/5 », `Icon`, `TileName` (nom et valeur, par exemple « Glass ×2 »), et `PriceRow` avec `CashIcon`, `Price` (blanc) et `PriceNeed` (rouge, quand l'argent manque).
   - Le code change seulement les visibilités et les textes. Il n'y a pas de `Template` : les 13 tuiles sont posées à la main.
6. `Tree.RootTile` (Q 0, R 0) : la tuile centrale « UPGRADES ». Rien ne s'y achète.
7. `Tree.SelectionGlow` : le code le pose sous la tuile choisie (même `Position`). T.55.
8. `InfoPanel`, à gauche, montre la tuile cliquée :
   - `Header.NodeName`, `NodeIcon`, `NodeLevel` (« Level 1 / 4 ») ;
   - `StatBox.NodeStat` (« Shop size ») et `StatBox.NodeEffect` (« Shop ▶ Store ») ;
   - `PriceRow.NodePrice` (« MAX » au dernier niveau) ;
   - `BuyButton` (`BuyLabel`, `Shade`), et `NeedButton` (`NeedLabel` « Need $X », caché) à la place de BUY quand l'argent manque ;
   - changement de tuile : T.56. Refus : T.18 (`Shake`).
9. **Achat** : la tuile gonfle (T.57), revient (T.58), avec un éclat (T.59) et des étincelles (T.60). La voisine qui s'ouvre se découvre avec un badge NEW! (T.61). L'argent défile et sursaute (T.15, T.16) ; `Success` (T.33).
10. **À importer par Clément, sinon les tuiles n'ont pas de fond en jeu** : `StealAShop-Art/UI/_A_importer_hex/UI_Hex_Fill.png` et `UI_Hex_Gloss.png`.
    - Aujourd'hui, `Rim`, `Body` et `Gloss` ont une `Image` vide (attribut `IconAsset`), et seul le prototype dessine les hexagones.
    - Les icônes de Traps et de Safe (`Tile_Next1`, `Tile_Next4`) sont vides elles aussi.

## 2. Le contenu (maquette validée, L-085)

Les valeurs viennent de Partie 2, section 2 (V0). Le doc range ces défenses en MAJ 2 à 4. Un tiret « — » veut dire que rien n'est décidé.

| Tuile (Studio) | `Id` proposé | Effet | Niveaux | Prix V0 | Voisines : s'ouvre quand… |
| --- | --- | --- | --- | --- | --- |
| `Tile_ShopLevel` (0, −1) | `ShopLevel` | Stand → Shop → Store → Concept Store → Flagship : la boutique grandit, et gagne 1 emplacement de piège par niveau | 4 achats (5 paliers) | 10K, 250K, 6,25M, 156M $ | ouverte dès le départ (voisine de la tuile centrale). Au niveau 2, elle ouvre Traps |
| `Tile_Glass` (−1, 0) | `GlassThickness` | PV de la vitrine ×1,5, ×2, ×3, ×5, ×8 ; vitre plus épaisse et plus teintée | 5 | 25K, 300K, 4M, 50M, 600M $ | ouverte dès le départ. Au niveau 1, elle ouvre Curtain |
| `Tile_GlassRegen` (−1, 1) | `GlassRegen` | Réparation de la vitre : +1 % des PV/s par niveau (base 3 %, jusqu'à 8 %) | 5 | 50K, 500K, 5M, 50M, 500M $ | ouverte dès le départ. Au niveau 1, elle ouvre Safe |
| `Tile_Cameras` (1, −1) | `Cameras` | N1 : alerte au 1er coup sur la vitrine. N2 : voleur surligné à travers les murs 30 s. N3 : flèche, distance et son jusqu'au voleur | 3 | 5K, 150K, 5M $ | ouverte dès le départ. Voisine de `Tile_Next2` (ne s'ouvre jamais) |
| `Tile_Guards` (1, 0) | `Bodyguards` | Un agent PNJ dans la boutique poursuit le voleur qui prend un objet ; s'il le touche, l'objet revient. Vitesse 20, 28, 36, 44, 52 | 5 | 100K, 2M, 40M, 800M, 16B $ (un 2e agent à la 8e renaissance) | ouverte dès le départ. Au niveau 1, elle ouvre Door Guard (planche Figma `49:900`) |
| `Tile_PotionLuck` (0, 1) | `PotionLuck` | Plus de chances de trouver des potions par terre | 3 | — | ouverte dès le départ. Au niveau 1, elle ouvre Potion Time |
| `Tile_Curtain` (−2, 0) | `Curtain` | Bouton dans la boutique : vitrine invulnérable 30 s (offert), puis 60 s, puis 90 s. Recharge 180 s, impossible si un voleur est déjà dedans | 2 | 50K, 1M $ | Glass niveau 1 |
| `Tile_DoorGuard` (2, 0) | `DoorGuard` | Un garde devant la porte (L-085 : « dans et devant le magasin ») | 1 | — | Bodyguards niveau 1 |
| `Tile_PotionTime` (0, 2) | `PotionTime` | Les potions durent plus longtemps | 2 | — | Potion Luck niveau 1 |
| `Tile_Next1` (0, −2), « TRAPS » | `Traps` | Emplacements de pièges derrière la vitrine (banane, colle, trappe, laser, filet ; recharge 45 s), 4 au plus | 1 dans la maquette | — (les pièges coûtent de 20K à 20M $ selon le type) | Shop Level niveau 2 |
| `Tile_Next4` (−2, 2), « SAFE » | `Safe` | Coffre-fort : +1 présentoir non volable par niveau (1 offert dès le MVP) | 2 | 250K, 25M $ | Glass Regen niveau 1 |
| `Tile_Next2` (2, −2) | — | — (« ??? » qui ne s'ouvre jamais dans la maquette) | — | — | — |

- **Règle proposée, à confirmer par Clément** : une tuile s'ouvre quand sa voisine du rang d'avant atteint le niveau 1, sauf Traps, qui attend Shop Level niveau 2. Les 6 tuiles autour de la tuile centrale sont ouvertes dès le départ.
  - La maquette ne montre que Bodyguards → Door Guard.
  - Le prototype ajoute Shop Level 2 → Traps et Glass Regen 1 → Safe.
  - Les autres seuils de la colonne de droite sont ma proposition.
- **Icônes** : Wall 89598496809365 (Shop Level), Glass 101463818389249, GlassRegen 126487278824716, Camera 130895616275969, Guard 133701105676131 (Bodyguards et Door Guard), Curtain 135129985966759, PotionLuck 82423065290603, PotionTime 102799696275335. La tuile centrale prend l'icône Base du HUD (107276625389501).
- **Sauvegarde** : un niveau par `Id`, comme `Upgrades` aujourd'hui (Treadmill, Bench, DisplaySlots).
