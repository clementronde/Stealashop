# Style v3 (2026-11-21) : « tout en blocs à studs », d'après les références de Clément

Références envoyées par Clément, rangées dans [references/](references/) : un pack de plus de 200 objets en blocs à studs (animaux, nature, plage, coffres, mécaniques de jeu), et une vignette « STUDS » avec un piment. **Ce sont des références de style, pas des modèles à copier** : le pack appartient à son auteur (« Raphie Assets » est écrit sur ses panneaux). On reprend la façon de construire, jamais ses modèles.

## Ce que montrent les références

| Point | Ce qu'on voit | Ce qu'on avait en v2 |
| --- | --- | --- |
| Construction | **Tout est fait de blocs** : pavés empilés sur une grille, formes rondes en escalier (rochers, piment, pattes, feuillage) | Un maillage lisse avec quelques grandes faces planes |
| Studs | **Sur toutes les faces de tous les blocs**, cadres compris : carreaux carrés en relief, à bords arrondis | Studs seulement sur `Body`, cadre lisse |
| Taille des studs | **La même partout**, quel que soit l'objet : un gros stud fait à peu près un quart de la hauteur d'une tête de perso. Les petits objets n'en ont que 2 ou 3 par face | Non réglée, elle suivait les UV |
| Contour | Aucun contour noir : ce sont les ombres et les creux des studs qui détachent les formes | Contour noir (Highlight) |
| Couleurs | Une couleur franche par bloc, 2 à 4 par objet, peu de dégradés. Le néon est rare (lanternes, portail) | 3 à 5, avec néon dès Épique |
| Créatures | Façon voxel : tête en pavé, corps en pavé, pattes en colonnes, yeux en carrés noirs posés sur la face | Peluche ronde « chibi » |
| Coffres | Corps à studs, **cadre or lui aussi à studs**, serrure lisse | C'est l'Exclusive Crate, en plus « blocs » |

## Ce que ça change pour la chaîne

1. **Les studs doivent avoir la même taille sur tous les objets.** On l'obtient avec le variant `Studs` sur des **Parts** : Roblox pose la texture en studs du monde, donc chaque bloc reçoit la même grille. Sur un MeshPart venu de Claude Design, la texture suit les UV du maillage, et la taille des studs change d'une pièce à l'autre. C'est **à vérifier** sur les `.glb` du tour 2, avant de choisir la méthode.
2. **Deux méthodes possibles**, à comparer sur le bubble tea :
   - **A. En Parts dans Studio**, comme la canette d'essai de `exemple-studs/` : studs réguliers garantis, quelques dizaines de blocs, très peu de triangles. Le risque, ce sont les formes en escalier sur les objets ronds.
   - **B. Claude Design en blocs** : on lui demande un objet fait uniquement de boîtes sur une grille de 0,25 stud, chaque boîte en pièce séparée, UV en « box mapping » à 1 unité d'UV = 1 stud. Ensuite, le script applique `Studs` à tout. Ça reste à tester.
3. **La planche ChatGPT** doit montrer cette construction, sinon Claude Design suit une planche lisse.

## Le bloc de style v3 (en anglais, brouillon à tester)

```
STYLE — "Steal a Shop" Roblox brick-voxel style (reference images attached):
- The whole object is BUILT FROM CHUNKY BLOCKS on a grid, like a toy brick build: stacked boxes, round shapes made as stepped blocks, no smooth curved surfaces.
- EVERY face of EVERY block is covered with the classic Roblox STUDS: big square studs with rounded corners, in relief, all the same size on the whole object (frames and borders included).
- Studs are big compared to the object: only 2 to 4 studs across a face of a small item.
- One flat saturated color per block, 2 to 4 colors per object. No outline, no gradients, no photo textures, no text, no logo.
- Creatures are voxel style: boxy head, boxy body, column legs, square black eyes set on the face.
- Rarity is shown by add-ons: Rare = a block frame in the rarity color; Epic = plus one glowing neon block; Legendary and above = studded gold #FFC21A frame, neon blocks and chunky crystals.
- Soft daylight render on a plain light background, readable at 40 studs away and as a 64 px icon.
```

## Prochaine étape proposée

Refaire le bubble tea avec les deux méthodes (A en Parts, B avec Claude Design en blocs), les poser côte à côte dans `_EXEMPLE_STUDS` avec l'Exclusive Crate, et garder la méthode qui donne les studs les plus réguliers.
