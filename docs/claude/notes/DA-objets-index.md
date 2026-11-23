# DA des objets de l'index : le style « Blender simple » (relevé du 2026-11-21)

Clément, le 2026-11-21 : le stud-voxel ne marche pas sur les objets (essai sur la souris), « on va rester dans le modèle qu'on avait déjà fait au début de l'utilisation simple de Blender pour les objets ». Cette fiche relève ce style sur des objets que la revue du 2026-11-20 a jugés **Conforme**, pour refaire les nouveaux objets pareil.

- **Elle remplace pour les objets exposés** [DA-objets-studs-blocs.md](DA-objets-studs-blocs.md) (studs et blocs, abandonné le 2026-11-21).
- **Elle ne change rien** aux colis ([DA-reference-colis.md](DA-reference-colis.md)), ni aux budgets, au nommage et au contrat (Partie 1, 10.2 à 10.4).

Relevé dans la place DEV, en lecture seule : `ReplicatedStorage/Assets/Items`, par le MCP Roblox Studio. Studio était en test à ce moment, donc la lecture s'est faite côté serveur. Rien n'a été modifié.

Les triangles ont été comptés ensuite, en mode Edit, avec `EditableMesh`. Pendant un test, les maillages ne se lisent pas. La canette fait aujourd'hui 344 triangles (276 dans le tableau 10.6 de la Partie 1).

## Les objets relevés

| Objet | Rareté | Taille L × H × P (studs) | Pièces visibles (couleur, matière) | Triangles | Rareté lue par |
| --- | --- | --- | --- | --- | --- |
| `ITM_Z1_Donut` | Commun | 1,63 × 1,61 × 0,85 | Dough `#E3A55C`, Icing `#FF7EB6`, SprinkleWhite `#F5F7FA`, SprinkleBlue `#2EA6F2`, SprinkleYellow `#FFE14D` | 920 | rien : mat, couleurs pleines |
| `ITM_Z1_CanetteDeSoda` | Commun | 0,98 × 1,60 × 0,98 | Body `#E8413C`, Band `#F5F7FA`, Metal `#C9CFD8` (tout en SmoothPlastic) | 344 | rien |
| `ITM_Z2_CanardEnPlastique` | Commun | 1,35 × 1,31 × 1,16 | Body `#FFD93B`, Beak `#FF8C1A`, Eyes `#1B1B24` | 758 | rien |
| `ITM_Z2_RobotJouet` | Épique | 1,22 × 1,98 × 0,81 | Body `#4E8FE8`, Dark `#3A404B`, Chrome `#C9CFD8` **Metal**, Panel `#E8413C`, Glow `#A855F7` **Neon**, Key `#D9A441` | 1 308 | un accent Neon violet + du Metal |
| `ITM_Z2_PelucheGeante` | Légendaire | 1,08 × 2,29 × 1,66 | Plush `#FFF4FA`, Gold `#FFC21A` **Foil**, Eyes `#1B1B24`, Blush `#FFB3D1`, ManePink `#FF7EB6`, ManeBlue `#7FD3FF`, ManeLilac `#C9A4FF`, ManeYellow `#FFE14D` | 2 486 | Foil or, particules `Sparkles` (`#FFE9A8`, 4 par seconde) dans `Plush`, attribut `Idle = Bob` |
| `ITM_Z3_Manette` | Peu commun | 1,41 × 1,06 × 0,60 | Body `#F5F7FA`, Dark `#2C2F36`, BtnYellow `#FFE14D`, BtnRed `#FF4B5C`, BtnGreen `#4CD964`, BtnBlue `#2EA6F2`, Home `#2EA6F2` (`Dark` comprend le support) | 748 | rien |
| `ITM_Z3_TeleRetro` | Commun | 1,40 × 2,04 × 1,07 | Cabinet `#2A9D8F`, Bezel `#F2E6C9`, Screen `#33475B`, Glare `#F5F7FA`, Dark `#2C2F36` (pieds, antennes), Tips `#FF4B5C` | 752 | rien |

## Les règles

### 1. Construction : un Model, un `Root`, une MeshPart par couleur

- **`Model` nommé `ITM_<ItemId>`**, avec l'attribut `ItemId` (`Z3_Souris`). Dès Légendaire, il porte aussi l'attribut `Idle` (`Bob`, `Spin` ou `SpinBob`), et c'est le code qui joue l'animation. Le modèle ne contient ni script ni `Highlight`.
- **`Root` est le PrimaryPart.** C'est une `Part` Block invisible (Transparency 1, Plastic `#A3A2A5`), de la taille de la boîte englobante. Le pivot du modèle est **en bas au centre** : le décalage du pivot vaut −H/2 sur les 7 objets.
- **Une MeshPart par couleur.** Chaque MeshPart regroupe tout ce qui a la même couleur et la même matière. Elle est nommée par son rôle (`Body`, `Dark`, `Eyes`, `Beak`, `Band`, `Panel`, `Glow`, `Chrome`, `Gold`) ou par sa couleur (`SprinkleBlue`, `BtnRed`, `ManeLilac`). Il y a 3 à 8 pièces visibles par objet.
- **Aucune texture** (`TextureID` vide), pas de `SurfaceAppearance`, `CollisionFidelity = Box`.
- **Réglages des pièces** (relevés sur la canette et l'ancienne souris) :
  - chaque MeshPart : `Anchored`, `CanCollide`, `CanTouch` et `CanQuery` coupés, `Massless`, `CastShadow` gardé, `RenderFidelity` Automatic ;
  - `Root` : Plastic `#A3A2A5`, Transparency 1, `Anchored`, `Massless`, `CanCollide` et `CanTouch` coupés, `CanQuery` gardé (c'est la seule pièce qu'on peut viser), `CastShadow` coupé. Sa taille est celle de la boîte, arrondie au millième supérieur.

### 2. Formes : arrondies et pleines, peu de faces

- Des **volumes ronds et pleins** : canette, donut, canard, peluche, coque de manette. Ce n'est pas du bloc. Le relief vient de pièces posées dessus (boutons, bandes, écran, bec), pas d'une texture.
- Des formes basses en **8 à 12 côtés** (16 × 8 pour l'anneau du donut), **en ombrage plat, à facettes** : **340 à 1 300 triangles** pour un objet Commun à Épique, 2 500 pour la peluche Légendaire. Les petits boutons sont des boules de 40 triangles.
- **Les facettes sont la signature du style** (relevé du 2026-11-21 dans Studio, sur le canard, la pastèque, le donut, la banane, l'ours, la Manette et la Télé rétro) :
  - chaque triangle a ses 3 sommets à lui, soit 3 sommets par triangle ;
  - ses 3 normales sont celles de la face, à 3° près ;
  - dans Blender, ça veut dire faces en ombrage plat (« Shade Flat »), sans lissage ni arêtes adoucies.

  Un objet lissé, comme la première souris du 2026-11-21 (0,6 sommet par triangle, normales jusqu'à 24° d'écart), paraît mou et brillant à côté des autres. Clément l'a vu tout de suite.
- **Taille : 1 à 2,3 studs** sur le plus grand côté. L'objet présente sa face reconnaissable vers l'avant (−Z). La manette tient debout sur un **petit support sombre** (compris dans sa pièce `Dark`) et le donut est debout, tous deux face à la rue ; l'écran de la télé regarde l'avant.
- **Un objet plat se présente debout.** Un objet qui se pose à plat et dont la face reconnaissable est le dessus (souris, manette) tient debout sur un petit support sombre, dessus tourné vers la rue. Couché, on n'en voit que la tranche depuis la rue. Clément a retenu cette présentation pour la souris le 2026-11-21, plutôt que la souris couchée.

### 3. Couleurs : une palette commune, franche

- **3 à 8 couleurs** par objet, en aplats saturés.
- Les mêmes teintes reviennent d'un objet à l'autre. C'est ce qui fait la famille :

| Rôle | Couleur |
| --- | --- |
| Blanc | `#F5F7FA` (coques, bandes, reflets) |
| Sombre | `#2C2F36` (pièces `Dark`), yeux `#1B1B24`, sombre bleuté `#3A404B` |
| Gris métal | `#C9CFD8` (SmoothPlastic sur la canette, Metal sur le robot) |
| Bleu | `#2EA6F2` (boutons, vermicelles) |
| Jaune | `#FFE14D` |
| Rouge | `#E8413C`, `#FF4B5C` |
| Rose | `#FF7EB6` |

### 4. Matière et rareté

| Rareté | Matière | Ce qu'on voit |
| --- | --- | --- |
| Commun, Peu commun | **SmoothPlastic** partout | Rien ne brille ; la rareté se lit sur le halo et la carte, pas sur l'objet (pas de gris `#B0B7C3` sur un objet Commun) |
| Épique | SmoothPlastic + **un accent Neon** à la couleur Épique (`#A855F7`) + Metal | Robot jouet : une bande `Glow` violette |
| Légendaire et plus | **Foil** or `#FFC21A` sur les pièces nobles | Peluche : particules `Sparkles` dans la pièce principale, `Idle = Bob` |

### 5. Contour

Aucun objet de l'index n'a de contour (revue du 2026-11-20). Pas de `Highlight` sur un objet exposé.

**Choix de Clément, le 2026-11-21 : style H, facettes et contour noir.** Il a choisi sur une planche du même avion dans 10 styles (`Vault Stud-Voxel/20 Production/DA Avion - choix du style.md`). Le contour se fait ainsi :
- **Une MeshPart `Outline` noire** (`#000000`, SmoothPlastic, `CastShadow` et `DoubleSided` coupés). C'est une copie de l'objet gonflée de 0,028 stud, aux faces retournées (coque inversée). Roblox n'en montre que le bord autour de la silhouette. Ce n'est ni un `Highlight` ni un script.
- **Seulement sur les volumes principaux** : les morceaux de moins de 0,2 stud (yeux, étoiles, boutons) n'ont pas de contour.
- **Le budget de 10.2 est tenu contour compris.** La boîte à outils refait un objet trop lourd avec moins de contour, puis moins de côtés.
- **Il reste à valider avec Ironix** le coût avec 31 objets à l'écran, avant de passer tout le catalogue au contour dans le jeu.

## Fabrication dans Blender (méthode retenue)

- **Un script Python lancé sans écran** (`blender -b --factory-startup --python <script>.py`). Il construit chaque couleur dans son propre objet Blender, nommé comme la future MeshPart.
- **Unités et repères** : 1 unité Blender = 1 stud. L'avant est à −Y dans Blender, il devient −Z dans Studio. L'origine est en bas au centre de la boîte englobante.
- **Export** : FBX avec les réglages validés en 10.1 (échelle 0,01, « Tout local », avant −Z, haut Y, appliquer l'unité, pas d'« Apply Transform », lissage Face).
- **À l'import dans Studio** : ajouter `Root` (Part invisible de la taille de la boîte, PrimaryPart), l'attribut `ItemId`, `Anchored`, `CollisionFidelity = Box`. Mettre en Neon ou en Foil seulement les pièces prévues pour la rareté.
- **Premier objet fait ainsi** : `ITM_Z3_Souris`, le 2026-11-21, debout sur son support (variante B, 1 330 triangles). Script : `Vault Stud-Voxel/20 Production/ITM_Z3_Souris/blender_simple/souris_simple.py`, lancé avec `-- stand`.
- **Comparer avant de livrer** : relever en mode Edit les maillages de 2 objets voisins de l'index, en lecture seule, avec `EditableMesh`. Les reconstruire dans Blender et rendre le nouvel objet entre eux, sous la même lumière et à la même échelle. Voir `compare_index.py` et `index_dump.txt` (Manette et Télé rétro) dans le même dossier.
- **Boîte à outils du catalogue v3** (2026-11-21, 55 objets) : `Vault Stud-Voxel/20 Production/ITM_v3/`. Elle contient :
  - `objets_lib.py` : formes de base, une pièce par couleur, export 10.1, rendus ;
  - un fichier par zone (`zone1.py` à `zone6.py`) ;
  - `lineup.py` : la rangée à l'échelle entre la Manette et la Télé rétro ;
  - `spec_luau.py` : le script d'après-import de chaque objet.

  Fiche : `20 Production/Catalogue v3.md`.

### Leçons du catalogue v3 (2026-11-21)

- **Regarder la silhouette de face, à l'échelle, avant de livrer.** Plusieurs formes trompaient :
  - des claquettes sur un présentoir incliné faisaient des dents ;
  - un rocher plat entouré de deux pierres faisait une tortue ;
  - des chips qui dépassaient d'un paquet faisaient des flammes ;
  - un blaster avec crosse faisait un vrai fusil.
- **Aucun personnage existant ni aucune marque.** Une figurine « chat blanc en tenue rose » rappelait un personnage connu : elle est devenue un ourson en sweat.
- **Pas de réplique d'arme.** Un blaster est un jouet trapu, en couleurs vives, avec l'embout orange des jouets.
- **Un objet plat se présente debout ou sur un socle** :
  - support incliné pour un pop-it, des autocollants ou une enseigne ;
  - chevalet pour un tableau ;
  - socle bas pour des chaussures, montrées de profil ;
  - socle bas pour des claquettes, posées à plat.
- **La rareté passe par la matière, même quand le nom dit autre chose.** Une « enseigne néon » Commun reste en SmoothPlastic (Clément peut en faire une exception).
  - Or en Foil `#FFC21A` dès Rare, Metal pour la quincaillerie ;
  - une seule pièce en Neon violet `#A855F7` pour un Épique ;
  - néon or pour un Légendaire, néon `#FF3B5C` pour un Mythique.
- **Triangles** : 700 à 2 600 sur ces 55 objets (moyenne 1 375). C'est plus que l'index (340 à 1 300), mais sous le budget. Le réglage `detail` de la boîte à outils allège un objet trop lourd.
