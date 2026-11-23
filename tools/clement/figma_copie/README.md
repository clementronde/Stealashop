# Copie Figma de toute l'UI du jeu

Ces outils servent à refaire la copie modifiable de l'UI quand les écrans changent. Elle se trouve dans le fichier Figma « Steal a Shop — UI » (clé `fXjkvf39sRhlsL94YicwDH`), page « 40 Jeu — copie de Studio (21/11) » (`214:369`). Clément l'a demandée le 2026-11-21 : « Mets tous les éléments du jeu en terme d'UI dans le figma », en « copie modifiable ». Le détail et les limites sont dans la section 10 de `docs/claude/notes/ui-reference-shop-tiktok-2026-11-21.md`.

Ce qui est copié :

- les 30 écrans de StarterGui en 1920 × 1080, sans les 4 anciens (`UI_Index`, `UI_Index_v2`, `UI_SkillTree_v2_old`, `UI_RobuxShop`) ;
- 40 éléments posés à plat :
  - les 22 billboards `BB_*` ;
  - les tableaux des scores et les 2 enseignes ;
  - `AlertBadge`, `AntiTheftOverlay` et les 8 fonds de cartes `ShopCardBg` ;
  - un exemplaire de chacun des 4 billboards du décor qui n'existent pas dans `Assets/UI`.

Chaque calque porte le nom de son élément Studio et suit la même hiérarchie. Les textes restent modifiables. Les images sont le remplissage de leur cadre. Les éléments cachés dans Studio sont cachés aussi dans Figma.

Rien n'est modifié dans la place. Les seuls objets créés dans Studio sont temporaires et supprimés juste après (`StarterGui._FigmaAtlas`, `StarterGui._FigmaBB`).

## Fichiers

| Fichier | Rôle |
| --- | --- |
| `export_studio.luau` | À lancer en Edit (barre de commande ou `execute_luau`). Il installe les fonctions `_G.Figma*` sans rien lancer. |
| `extract.js` | Lit les blocs `@@UIEXPORT@@` et `@@ATLAS@@` sortis par Studio et écrit `data/<écran>.json` et `atlas/<planche>.json`. |
| `alpha.js` | Découpe une planche photographiée sur noir puis sur blanc et retrouve la transparence : `a = 1 − (blanc − noir) / 255`, `C = noir / a`. |
| `build.js` | Construit une page HTML pour `html_to_figma` : un ou plusieurs écrans, chacun avec sa place sur la page. |
| `passe.js` | À coller dans `use_figma` après chaque import. Il rend contours, images, mosaïques, textes et calques cachés comme dans Studio, pose les écrans et remplace l'ancienne copie du même nom. Il compare aussi le nombre de cadres au nombre d'éléments Studio. |
| `grille.txt` | Place des écrans : une ligne = une rangée de la page. Colonne × 2119 px, rangée × 1279 px. |

Il faut Node, et ffmpeg à l'emplacement WinGet (`%LOCALAPPDATA%\Microsoft\WinGet\Links\ffmpeg.exe`).

## Refaire la copie

1. **Dans Studio, en Edit** :
   1. Lancer `export_studio.luau`.
   2. Lancer `_G.FigmaDevice()`, qui règle un appareil simulé de 1920 × 1080 : tous les écrans sont relevés à la même taille.
2. **Relever les écrans.** `_G.FigmaExportMany({ "UI_HUD", "UI_Hotbar", … })` relève chaque écran en l'allumant le temps du relevé, car un écran éteint garde des positions périmées. Au-delà de 100 000 caractères, la sortie est coupée : relever les gros écrans un par un (`UI_Index_v3`, `UI_RobuxShop_v2`).
3. **Relever les billboards et panneaux.** Lancer `_G.FigmaExportAssets()`, puis `_G.FigmaExportMany(_G.FigmaAssetNames)`.
4. **Photographier les images.**
   1. Lancer `_G.FigmaComputeSheets()`.
   2. Pour chaque planche `i`, lancer `_G.FigmaAtlas(_G.FigmaSheets[i], Color3.new(0, 0, 0))` et renvoyer la carte de la planche (`"@@ATLAS@@\tsheet" .. i …`).
   3. Faire une capture (`screen_capture`).
   4. Lancer `_G.FigmaAtlasBg(Color3.new(1, 1, 1))` et refaire une capture.
   5. Lancer `_G.FigmaAtlasDone()`.

   Les images vues seulement sur les billboards demandent une planche de plus.
5. **Extraire les données.** Lancer `node extract.js <historique de la session .jsonl> ui_export`. Les réponses trop longues, que l'outil a rangées dans le dossier `tool-results` de la session, sont lues aussi.
6. **Découper les images.** Lancer `node alpha.js ui_export/atlas/sheetN.json <capture noire> <capture blanche> ui_export/images` pour chaque planche.
7. **Construire les lots.** Lancer `node build.js html/lotN.html images data/UI_X.json@x,y …`, avec 1 à 15 écrans par lot. Le HUD se construit avec `NOCLIP=UI_HUD` : sa rangée `TopLeftRow` est au-dessus du cadre, car en jeu elle se trouve dans la barre du haut de Roblox.
8. **Importer dans Figma.** Pour chaque lot :
   1. Appeler `html_to_figma` (fichier ci-dessus, nœud `214:369`) pour obtenir une adresse.
   2. Envoyer le lot avec `curl -X POST <adresse> -H "Content-Type: text/html" --data-binary @lotN.html`. La réponse donne l'identifiant du document importé.
   3. Coller `passe.js` dans `use_figma`, en remplaçant `__DOCS__` par les identifiants et `__EXPECT__` par `{ écran: nombre d'éléments }`, qui se lit dans `data/<écran>.json`.
   4. Vérifier que `mismatch` est vide.
9. **Remettre Studio en état.** Lancer `_G.FigmaDeviceOff()`.

## Refaire un seul écran qui a changé

`_G.FigmaExportMany` garde chaque relevé dans `_G.FigmaCache` pendant toute la session Studio. Pour relever un écran modifié depuis, vider d'abord son entrée : `_G.FigmaCache["UI_Settings"] = nil`. Sinon, c'est l'ancien relevé qui sort, sans message.

Le relevé ne porte pas le dégradé d'un contour (`UIGradient` sous un `UIStroke`, comme `RimFade` du liseré des boutons). Après la passe, il faut le reposer dans Figma : contour en dégradé du haut vers le bas, opaque jusqu'à 0,55 puis transparent à 0,9.

## Pièges connus de la conversion

- Un cadre sans fond ni contour disparaît. `build.js` lui donne un fond presque invisible, que la passe retire.
- Une bordure CSS décale les enfants. Le contour est donc posé dans une aide `__stroke`, puis reporté sur son cadre.
- La conversion fond parfois une aide dans son cadre : un cadre dont le seul enfant est son contour, ou un texte qui remplit son cadre. Chaque aide porte donc le numéro et le nom de son cadre (`o=`, `lbl=`).
- Une marge entre deux écrans ajoute un cadre autour de chacun. Les écrans sont donc empilés en position absolue.
- Un élément entièrement hors d'un écran coupé est supprimé. D'où `NOCLIP`.
