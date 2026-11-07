# MOD-027 · Outils de casse : compte rendu (2026-11-07)

Livrés dans `Workspace/_INBOX_CLEMENT` de la place DEV : les 7 modèles, rangés en ligne hors de `_SHOWROOM_CLEMENT` (z = 180, x de -132,5 à -111,5). Planche validée par Clément le 2026-11-07.

## Modèles

Chaque outil est un `Model` `TOOL_*` (ToolService le passe dans un Tool), avec `PrimaryPart = Handle` et le pivot en bas au centre.

| Modèle | Pièces (MeshPart : couleur, matériau) | Triangles | Taille L × H × P (studs) | Centre de `Handle` au-dessus du pivot | `HitPoint` dans `Handle` (X, Y, Z) |
| --- | --- | --- | --- | --- | --- |
| `TOOL_CleAMolette` | Handle `#4A5160` SmoothPlastic · Body `#B0B7C3` SmoothPlastic · Wheel `#5B6371` SmoothPlastic | 480 | 0,31 × 1,98 × 0,73 | 0,54 | 0 ; 1,30 ; -0,41 |
| `TOOL_PiedDeBiche` | Handle `#1C6B47` SmoothPlastic · Bar `#2FE08F` SmoothPlastic · Tips `#C9CFD8` Metal | 468 | 0,35 × 2,57 × 0,86 | 0,95 | 0 ; 1,56 ; -0,51 |
| `TOOL_Marteau` | Handle `#1E3F8A` SmoothPlastic · Shaft `#2F9BFF` SmoothPlastic · Head `#C9CFD8` Metal | 872 | 0,42 × 2,65 × 1,29 | 0,585 | 0 ; 1,845 ; -0,67 |
| `TOOL_Masse` | Handle `#4C1D95` SmoothPlastic · Shaft `#A855F7` SmoothPlastic · Head `#3A404B` Metal · Faces `#E3E8EF` Metal · Glow `#A855F7` Neon | 616 | 0,77 × 3,24 × 1,48 | 0,65 | 0 ; 2,20 ; -0,74 |
| `TOOL_HacheDIncendie` | Handle `#1B1B24` SmoothPlastic · Shaft `#E8413C` SmoothPlastic · Head `#FFC21A` Foil · Edge `#E3E8EF` Foil | 1 004 | 0,36 × 3,56 × 2,12 | 0,72 | 0 ; 2,29 ; -1,12 |
| `TOOL_Disqueuse` | Handle `#1B1B24` SmoothPlastic · Body `#FF3B5C` SmoothPlastic · Details `#2C2F36` SmoothPlastic · Head `#FFC21A` Foil · Guard `#3A404B` Metal · Disc `#5B6371` Metal · DiscHub `#FFC21A` Foil · DiscGlow `#FF8C1A` Neon | 1 268 | 0,85 × 3,67 × 1,73 | 0,66 | -0,375 ; 2,14 ; -0,88 |
| `TOOL_Batte` | Handle `#1B1B24` SmoothPlastic · Body `#E3A35F` SmoothPlastic · Band `#E8413C` SmoothPlastic | 758 | 0,54 × 3,01 × 0,54 | 0,645 | 0 ; 1,905 ; -0,28 |

Progression voulue : la couleur d'accent suit les raretés du doc 10.6 (Commun gris, Peu commun menthe, Rare bleu, Épique violet avec néon, Légendaire or, Mythique rose avec or et néon). La batte n'entre pas dans cette échelle : elle est en bois avec une bande rouge.

## Ce que le code doit savoir (pour Ironix, liaison)

1. **Prise** : `Handle` est la poignée seule. Son centre est l'endroit où la main tient l'outil avec la `Tool.Grip` par défaut (identité). L'outil est alors tenu droit, tête en haut, face de frappe vers l'avant (-Z). Aucune Grip à régler en code a priori. C'est vérifié par le calcul et par une simulation de la pose R15 « toolnone » dans Blender, **pas encore en jeu**.
2. **`HitPoint`** : un Attachment unique dans `Handle`, sans rotation (LookVector = avant), placé au point de frappe. C'est la face du marteau et de la masse, le tranchant de la hache, le bord avant du disque, le haut avant du crochet du pied-de-biche, la mâchoire fixe de la clé et le gros bout de la batte.
3. **Soudures** : les autres pièces sont soudées à `Handle` par un `WeldConstraint` nommé `WeldToHandle`, donc `prepareParts` les laisse telles quelles. Toutes les pièces : `Anchored = true` (le temps du bac ; ToolService les désancre), `CanCollide = false`, `Massless = true`, `CollisionFidelity = Box`. Aucun script.
4. **Noms** : la hache s'appelle `TOOL_HacheDIncendie`, choix de Clément le 2026-11-07. C'est le nom déjà attendu par `Config/Tools.luau`, donc rien à changer. `TOOL_Batte` est confirmé lui aussi. Les commentaires « à confirmer avec Clément » de `Config/Tools.luau` et `Config/Bat.luau` peuvent partir. À corriger dans la doc : `docs/claude/Etapes-Clement.md` (étape 11) écrit encore `TOOL_HacheIncendie`.
5. **À ranger** : déplacer les 7 `TOOL_*` de `_INBOX_CLEMENT` vers `ReplicatedStorage/Assets/Tools`. ToolService cherche dans `Assets` en profondeur.
6. **Options (effets)** : `Glow` (masse) et `DiscGlow` (disqueuse) sont en Neon et brillent avec le Bloom. Le disque de la disqueuse (`Disc`, `DiscHub`, `DiscGlow`) peut tourner autour de l'axe X de `Handle`, centre à (-0,375 ; 2,14 ; -0,06) depuis le centre de `Handle`.

## Vérifié

- Planche validée par Clément : `StealAShop-Art/Tools/MOD-027_Planche_Outils.png`.
- Dans Studio, en mode Edit : tailles identiques à Blender, pivot en bas au centre (écart de 0,02 stud au plus). Triangles relus depuis les maillages Roblox (EditableMesh) : identiques à Blender, tous sous 1 500. Maillages au nom du groupe 207192094 RoundStone Studio. Contrat 10.4 respecté : `Handle` en MeshPart enfant direct, un seul `HitPoint`, aucun script.
- Orientation confirmée sur l'import : -Y Blender donne -Z Roblox, Z donne Y, sans miroir (+X Blender donne -X Roblox).
- Test Play, avec l'accord de Clément : le ContractChecker affiche « Contrat : OK », sans ligne rouge. Les 9 points en attente concernent d'autres livraisons (UI, animations, ITM, ACC). Test arrêté, Studio revenu en mode Edit.

## Pas vérifié

- L'outil équipé sur un vrai perso en jeu : prise et taille dans la main, avec les animations `HitWindow` et `HitWindowHeavy`, qui ne sont pas encore faites.
- Le rendu visuel dans Studio : aucune capture, Clément n'en a pas demandé.

## Hors sujet repéré

- Pendant le Play, la sortie affiche 6 fois `ContentId: rbxassetid://203785492 failed due to: Asset type does not match requested type`. Ce n'est pas un maillage des outils : il faut trouver quelle instance utilise cet ID.
- `_SHOWROOM_CLEMENT/OUTILS DE CASSE` contient toujours les silhouettes `Show_Outil_1` à `_7`. Je n'y ai pas touché : la session principale peut les remplacer par des copies des `TOOL_*`.

## Fichiers

`C:\Users\Charment\Documents\StealAShop-Art\Tools\`
- `TOOL_*.blend` (7) : une collection au nom de l'outil, une pièce par couleur et un repère `HitPoint`.
- `TOOL_*.fbx` (7) : réglages d'export du doc 10.1 (échelle 0,01, -Z avant, Y haut), entièrement en triangles.
- `TOOL_*.json` (7) : fiche de l'outil (pièces, couleurs, matériaux Roblox, triangles, `HitPoint`).
- `MOD-027_Planche_Outils.png` : la planche validée.
- `_scripts\` : `mod027_lib.py`, `build_tools.py`, `render_board.py`, `compose_board.py` et `export_fbx.py`, pour régénérer un outil.

Rien de modifié dans Git, ni dans la liaison, ni dans le doc partagé.
