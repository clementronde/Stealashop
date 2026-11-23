# Icônes des échelles ×2 → ×16 (gamepasses), proposition du 2026-11-21

Agent `createur-gamepasses`. **Proposition, à valider par Clément** : rien n'est importé dans Studio ni publié sur Roblox.

**Source : Figma** « Steal a Shop — UI » (`fXjkvf39sRhlsL94YicwDH`), page `10 Boutiques`, section « Gamepasses — icônes échelles ×2 → ×16 (proposition 2026-11-21) » (node `265:2815`, à droite du groupe 199:4143). Sceau, chiffres et étincelles y sont en vecteur et modifiables, les symboles sont tes images ; les PNG de ce dossier en sont des exports à 512 px (réglage d'export PNG déjà posé sur chaque icône). Les deux premières versions (rendu Blender, puis symboles redessinés) sont remplacées.

| Fichier | Composant Figma | Gamepass | Couleur du sceau |
|---|---|---|---|
| `UI_Icon_GP_x2Cash.png` | 266:2815 | `DoubleCash` (×2 CASH, 29 R$) | `45D63A` (celle de la carte) |
| `UI_Icon_GP_x4Cash.png` | 266:2831 | `CashX4` (V0) | `2CB24A` |
| `UI_Icon_GP_x8Cash.png` | 266:2857 | `CashX8` (V0) | `9CCB2A` |
| `UI_Icon_GP_x16Cash.png` | 266:2901 | `CashX16` (V0) | `FFC21A` (or) |
| `UI_Icon_GP_x2Training.png` | 266:2963 | `DoubleTraining` (×2 TRAINING, 29 R$) | `FF9A2E` (celle de la carte) |
| `UI_Icon_GP_x4Training.png` | 266:2981 | `TrainingX4` (V0) | `FF7A22` |
| `UI_Icon_GP_x8Training.png` | 266:3003 | `TrainingX8` (V0) | `FF5436` |
| `UI_Icon_GP_x16Training.png` | 266:3029 | `TrainingX16` (V0) | `FFC21A` (or) |

Planches : `planche_echelles.png` et `planche_echelles_100px.png` (contrôle à 100 px).

## Famille visuelle (reprise de la maquette de Clément)
- Fond : le **sceau dentelé** de l'icône ×2 Training de Clément (composant `GP/Seal`), contour sombre `14142B`, cercle intérieur clair, reflet. Seule sa couleur change d'une marche à l'autre ; les deux échelles finissent sur l'or au ×16.
- Symboles : **les icônes de Clément déjà dans Figma** (demande de Clément) — argent : la liasse seule (`5afbdb…`, 320 px, page 40) pour ×2, la pile des cartes Cash (`UI_Icon_Cash`, 150 px) pour ×4, la grosse pile du ×2 Cash (`Icon_x2Argent`, 150 px) pour ×8, grosse pile + liasse pour ×16 ; vitesse : la basket rouge ailée de « ×2 SPEED » (`UI_Icon_SpeedBoost`, 512 px) sur les 4 marches. Petites étincelles vectorielles (`GP/Symbol/Sparkle`) ajoutées en montant.
- Limites : les piles de billets n'existent qu'en 150 px, un peu douces une fois agrandies dans une icône de 512 (nettes à la taille d'une carte). Une version 512 des piles (rendu MOD-100 ou image du Decal dans Studio) les rendrait nettes. L'échelle vitesse montre la même basket : la marche se lit au chiffre, à la couleur et aux étincelles.
- Chiffre : Montserrat Black (la police de la boutique), blanc, contour sombre, ombre pleine, penché de 8°, en bas à droite, dans le cercle (Roblox recadre les icônes de gamepass en rond).

## Pour Clément
- Les noms ×2 sont ceux des icônes déjà dans `ReplicatedStorage/Assets/Icons` : si tu les prends, remplace l'image du `Decal` existant (ne le supprime pas, ne le renomme pas). Les ×4, ×8, ×16 sont des noms nouveaux (V0), à ajouter au contrat après validation.
- Les icônes de la page Roblox de chaque gamepass (Creator Hub) peuvent être ces mêmes PNG.
