# Les 7 auras livrées le 2026-11-16 — ce que le code doit faire

**État** : `ReplicatedStorage/Assets/FX/Auras` contient `FX_Aura_Feu`, `FX_Aura_Poison`, `FX_Aura_Shine`, `FX_Aura_Tornado`, `FX_Aura_Demon`, `FX_Aura_Angel`, `FX_Aura_Chained` (en plus de `FX_Aura_Eclair`). 0 script, 0 ScreenGui, toutes les pièces ancrées et invisibles sauf les meshes. Même structure qu'Éclair : Model, `PrimaryPart` = `HumanoidRootPart`, sol à y = 0, pièces `HumanoidRootPart`, `UpperTorso`, `Head` (Demon, Angel), `LeftFoot`, `RightFoot`. ContractChecker en Edit : aucune ligne rouge, rien sur les auras. Aperçu : `Workspace/_APERCU_AURAS_LIVREES` (vers −1200, 700, 1100). Captures : `StealAShop-Art/Captures/2026-11-16_auras_livrees/`.

**PAS ENCORE DANS LA LIAISON** (2026-11-16) : le dossier partagé a 98 commits de retard et la liaison porte des modifications non commitées d'autres sessions (L-189, L-190, L-197, L-201, L-202) : `git pull` refusé. Prochain numéro libre sur origin : L-206 (L-205 = décision « les 8 nouvelles auras remplacent les 6 »). Ligne prête en bas de ce fichier.

## Convention commune (nouvelle, aussi posée sur Éclair)

1. **Attachments des pièces R15** : copiés par `CosmeticService` comme aujourd'hui (émetteurs, lumières, Beams reliés). Rien à changer.
2. **Pièces à cloner et souder** : toute `BasePart` ou tout `Model` du modèle qui porte l'attribut **`WeldTo`** (texte : `Head` ou `HumanoidRootPart`). La cloner, garder son CFrame relatif à la pièce `WeldTo` du modèle, la souder à la pièce du joueur, `Massless`, sans collision. La retirer avec l'aura et à VISUAL EFFECTS OFF. Un `Model` (chaise) a un `PrimaryPart`.
3. **Mouvement, attributs facultatifs** (nombres, côté client) :
   - `Spin` : rad/s autour de l'axe Y local de la pièce (chaînes) ;
   - `Orbit` : rad/s autour de l'axe vertical de la pièce `WeldTo` (débris de la tornade) ;
   - `Tumble` : rad/s de culbute sur elle-même (débris) ;
   - `Period` : durée en secondes d'un cycle de bulle (Poison).
   Sans ce code, les pièces restent figées à leur place : l'aura reste lisible.
4. Sur Éclair, `Cloud`, `CloudRim` et `RainPlate` ont reçu `WeldTo = "Head"` (rien d'autre n'a changé).
5. Les pièces soudées au `HumanoidRootPart` (flaque, bras, cercle) suivent le joueur quand il saute. Si ça gêne : les recaler au sol par rayon, au choix du code.

## Par aura

| Aura | Marche sans rien changer | Pièces `WeldTo` | Mouvement à coder |
| --- | --- | --- | --- |
| Feu | 4 émetteurs (`UpperTorso/Flames`, `HumanoidRootPart/Ground`) | aucune | aucun |
| Shine | 5 émetteurs + `PointLight` sous `UpperTorso/Shine` | aucune | aucun |
| Demon | ailes, flammes, chauves-souris, yeux de feu (11 émetteurs ; les yeux ≈ 130 particules vivantes) | `Halo` → `Head` (512 triangles) | aucun |
| Angel | ailes, plumes, flammes blanc et or (5 émetteurs) | `Halo` → `Head` | aucun |
| Tornado | vent (22 Beams) et poussière | `Debris` : 16 `Leaf_n` (MeshPart, 2 triangles), 9 `Wood_n` (Part), 3 `Chair_n` (Model de 6 Parts) → `HumanoidRootPart` | `Orbit` et `Tumble` |
| Chained | cercle au sol (2 émetteurs) | `Zone_Body` (Part invisible, émetteur `DarkLines` en volume) ; `Chains/Chain_1..3` (1 440 triangles chacune) → `HumanoidRootPart` | `Spin` (0,55 / −0,45 / 0,7) |
| Poison | brume et crânes (3 émetteurs) | `Puddle`, `PuddleRim`, `Arm_1..3`, `ArmRim_1..3`, `Bubbles/Bubble_1..6` → `HumanoidRootPart` | bulles (`Period`), flaque vivante (facultatif) |

Triangles par porteur : Poison ≈ 6 560 (flaque 840 + contour 56, 3 bras × (696 + 463), 6 bulles × 364), Chained 4 320, Demon et Angel 512, Tornado 32 + pièces simples.

## Pour retrouver exactement les prototypes validés par Clément (facultatif)

- **Tornado, débris** : angle = a − ω t (ω 2 à 3,2 rad/s) ; hauteur relative s = (h0 + 0,02 à 0,06 × t) mod 1 sur 7,4 studs ; rayon = rayon de l'entonnoir à cette hauteur (1,25 en bas → 4,85 en haut) × 0,85 à 1,12 ; culbute. Avec `Orbit` seul, les débris tournent sans monter.
- **Poison, bulles** : chaque bulle gonfle de 0 à sa taille sur 86 % de `Period`, enfle d'un coup, disparaît, puis repart à un autre endroit de la flaque tiré au hasard.
- **Poison, flaque vivante** : le prototype validé déformait un seul mesh en direct (`EditableMesh`, 96 × 12 anneaux). Contour : rayon(θ, t) = 2,3 × (1 + 0,10 sin(3θ + 0,35 t) + 0,07 sin(5θ − 0,5 t + 1) + 0,035 sin(8θ + 0,8 t + 2)) + 4 coulées lentes (bosse gaussienne de largeur 0,32 à 0,44 rad, amplitude 0,85, qui s'étire et se rétracte). Hauteur : 0,05 + bourrelet de 0,07 vers 86 % du rayon. Couleurs par face : bord sombre, bourrelet clair, surface verte, centre plus sombre. La flaque livrée (`Puddle`) est ce mesh figé à t = 0 : à remplacer par l'`EditableMesh` seulement si le coût à 8 joueurs le permet.

## Assets (au nom du groupe RoundStone Studio, 207192094)

| Nom | Type | ID |
| --- | --- | --- |
| `FX_Aura_Halo` | Mesh | 98043519664820 |
| `FX_Aura_Chain` | Mesh | 81815378831843 |
| `FX_Aura_Leaf` | Mesh | 131485688243571 |
| `FX_Poison_Puddle` | Mesh | 105088915834510 |
| `FX_Poison_PuddleRim` | Mesh | 106804519395848 |
| `FX_Poison_Arm` | Mesh | 75547887563429 |
| `FX_Poison_ArmRim` | Mesh | 99049008587398 |
| `FX_Poison_Blob` | Mesh | 95060911742501 |
| `FX_Poison_Skull` | Image | 101847078858804 |

Sources : `StealAShop-Art/FX/Aura3D/Import_Auras/` et `_src/auras_import_fbx.py`. Import brut rangé dans `ServerStorage/FX_Auras_Import` (supprimable).

**Textures de packs du Creator Store** (pas à nous, IDs publics, chargement vérifié) : Feu, Shine, Demon, Angel (ailes, flammes, yeux, plumes), Tornado (vent), Chained (sol, traits noirs). Reprise ou redessin : non tranché par Clément.

## À savoir

- Le ContractChecker avertit que les `ICON_Aura_*` et `ICON_Trail_*` de `Assets/Icons` « ne sont pas au catalogue d'objets » : ce sont les icônes de boutique de L-171 et L-179, pas des objets.
- Pas vérifié : rendu de nuit, rendu en Play sur un vrai joueur (rien n'est branché), coût à 8 porteurs.
- Le 2026-11-16, en voulant capturer, `open_application` a ouvert une seconde fenêtre Studio sur la place DEV : la première session a été fermée par Roblox (« Sessions multiples »). Rien de perdu (Team Create), mais l'identifiant MCP de Studio a changé (`e86899c4-…`).

## Ligne de liaison prête (Pour : Ironix)

> **Les 7 auras manquantes sont livrées** (demande de Clément, 2026-11-16) | `Assets/FX/Auras` contient `FX_Aura_Feu`, `Poison`, `Shine`, `Tornado`, `Demon`, `Angel`, `Chained` : même structure qu'`FX_Aura_Eclair`, 0 script. **Sans rien changer** : tous les Attachments (particules, vent, lumières) sont copiés par `CosmeticService` ; Feu et Shine sont complètes ainsi. **À coder** : (1) cloner et souder toute pièce ou Model portant l'attribut `WeldTo` (`Head` ou `HumanoidRootPart`), en gardant son CFrame relatif : auréole de Demon et Angel, chaînes et `Zone_Body` de Chained, débris de Tornado, flaque, bras et bulles de Poison ; même attribut posé sur `Cloud`, `CloudRim`, `RainPlate` d'Éclair. (2) Mouvement côté client, attributs facultatifs : `Spin` (rad/s, axe Y local : chaînes), `Orbit` (rad/s autour de la pièce `WeldTo`) et `Tumble` (débris), `Period` (s, cycle d'une bulle). Sans (2) les pièces restent figées. Triangles par porteur : Poison ≈ 6 560, Chained 4 320. La flaque du Poison est figée ; le prototype la déformait en direct par `EditableMesh` (formule gardée par Clément, à voir selon le coût). Le ContractChecker prend les `ICON_Aura_*` / `ICON_Trail_*` de `Assets/Icons` pour des objets hors catalogue : à exclure. Non vérifié : nuit, Play sur un joueur, 8 porteurs. | Les 8 auras en boutique (L-205) | 2026-11-16 | À faire |
