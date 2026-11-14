---
name: aura-vfx
description: Savoir-faire pour concevoir, construire et juger les auras, trails et VFX de Steal a Shop dans Roblox Studio (ParticleEmitter, Beam, planches animées, textures Blender). À utiliser dès qu'on touche à une aura (FX_Aura_*), un trail, un éclair, un impact, un effet de tapis ou toute particule du jeu, ou qu'on benchmarke des packs VFX du Creator Store.
---

# Auras et VFX de Steal a Shop

Tout ce qui suit a été vérifié le 2026-11-14 (14 versions d'aura Éclair refusées, 39 packs du Creator Store démontés, une vidéo de pro lue en entier). Ce qui n'est pas vérifié est marqué « à vérifier ».

Références : `StealAShop-Art/References/Auras_VFX/` (`images/` de Clément, `videos/liens.md`, `benchmark/` avec les planches et les notes). **Ouvrir les images avant de construire.**

## 1. Les règles de Clément (non négociables)

1. **Benchmark avant de construire.** Montrer des références réelles (packs, autres jeux), le laisser choisir un style, puis seulement construire. Ne jamais partir d'une idée à soi.
2. **Un éclair n'est jamais un tube.** Pas de cylindres bout à bout, pas de mesh extrudé, pas de contour épais. Un éclair est une **texture dessinée**, en planche animée, très brève.
3. **Rien qui fait « PNG plat ».** Une image fixe qui monte, descend ou tourne est refusée. Il faut du changement d'image (planche animée ou plusieurs textures qui alternent), de la profondeur (plusieurs couches à des distances différentes) et du mouvement varié.
4. **Le sol est discret.** Hors des moments forts, rien au sol. « Mieux vaut aucun effet au sol que trop gros. » Pas de cercle magique géant par défaut.
5. **Toon seulement là où il le demande.** Sur l'aura Éclair : seul le nuage est toon. Ne pas « tooniser » le reste de sa propre initiative.
6. **Le personnage reste visible.** Une aura qui cache le joueur est refusée.
7. **Relire ses propres captures avant d'envoyer** (grille en section 10). Ne jamais envoyer une image qu'on n'a pas regardée d'un œil critique.
8. **Une seule aura d'abord**, validée, avant de décliner les thèmes.
9. Il valide en **vraie 3D sur un perso R15**, de face et de trois quarts, jamais sur une maquette. Réponses courtes, une question à la fin.

## 2. Méthode

1. **Référence** : ouvrir l'image ou la planche choisie. La décomposer en couches (section 3) par écrit avant de toucher Studio.
2. **Textures d'abord** : 80 % de la qualité vient des textures. Chercher ou dessiner les planches avant de régler quoi que ce soit (sections 5 et 6).
3. **Construire à part** : `Workspace/_PROTO_<NOM>` sur un mannequin R15 habillé (pas blanc : un perso blanc cache les effets clairs), sol vert, **en plein jour**. Ne jamais toucher aux `FX_Aura_*` existants.
4. **Une couche à la fois**, en commençant par la plus grosse forme. Régler taille → durée de vie → courbes → couleur → débit.
5. **Désactiver puis réactiver tous les émetteurs** avant de juger (dans le jeu ils démarrent ensemble).
6. **Capturer** (mémoire `studio-visual-capture`) : caméra + `Focus` en Edit, cliquer l'onglet de la vue avant chaque capture (sinon la vue 3D est figée et la capture est périmée), puis zoom computer-use.
7. **Auto-critique** (section 10), au moins 2 tours, de jour puis de nuit.
8. **Montrer** : face + trois quarts + le moment fort. Dire ce qui n'est pas vérifié.
9. Après validation seulement : import au nom du groupe, rangement, ContractChecker, note pour Ironix.

## 3. Décomposer une aura en couches

Une bonne aura = **2 à 4 grands motifs lisibles** + 2 ou 3 couches de finition. Jamais un nuage de particules sans forme.

| Couche | Objet | Réglages vérifiés |
| --- | --- | --- |
| **Lueur de corps** | 1 ParticleEmitter sur un Attachment au centre | Texture à bord fondu, `Rate` 2, `Lifetime` 1, **transparence en V** (1 → 0 → 1) pour rester en place sans clignoter, `ZOffset` 2 à 4 ou négatif pour passer derrière, `LockedToPart`. Souvent doublée : une grande sombre + une petite claire |
| **Flammes de silhouette** | 1 à 3 émetteurs, planche 2×2 ou 4×4 | `FacingCameraWorldUp`, taille 2 à 4 studs, `Lifetime` 0,5 à 1, monte de 1 à 3 studs/s, `ZOffset` −1 à −2,5 (derrière le perso), `LockedToPart` |
| **Arcs électriques sur le corps** | 2 à 4 émetteurs, planches différentes | Planches 4×4 ou 8×8 d'arcs fins, taille 1 à 4 studs, `Lifetime` 0,2 à 1, `LockedToPart`, à plat (`VelocityPerpendicular`) ou face caméra |
| **Éclats / traits** | 1 émetteur | `VelocityParallel`, vitesse 10 à 30, `Drag` 1 à 5, `Lifetime` 0,3 à 0,6. Les **doubler en noir** (`LightEmission` 0) pour le contraste |
| **Specs** (petits points) | 1 émetteur | Vitesse 1 à 3, directions au hasard, fondu aux deux bouts. La signature des jeux d'auras |
| **Grand motif** (ailes, vortex, prisme, orbe) | Beams courbes + planches | Voir « Beams » ci-dessous |
| **Sol** (si demandé) | 1 ou 2 émetteurs | `Speed` 0,01 (jamais 0), `VelocityPerpendicular`, `ZOffset` 0, posé 0,05 à 0,15 stud au-dessus du sol, anneau qui grossit vite puis ralentit |
| **Fumée d'ambiance** | 1 émetteur | À peine visible, émission en sphère |
| **Lumière** | 0 à 1 PointLight | Luminosité ≤ 1,2 de jour ; sans ombres |

**Règles de réglage**
- **Toujours un fondu**, en taille ou en transparence. Une particule qui apparaît d'un coup est une faute.
- **Varier** vitesse et durée de vie (plages, pas des valeurs fixes) ; rotation −45 à 45 ; texture décentrée + rotation pour faire « flotter ».
- `LightInfluence` 0 partout (l'aura ne doit pas dépendre de l'éclairage de la map).
- Avec `LightEmission` 1, assombrir la couleur = rendre plus transparent. Plus rapide que de retoucher la courbe.
- Émettre en **disque** plutôt qu'en boîte dès que le débit est fort.
- `Squash` étire une texture (utile pour la pluie) ; il déforme mal les textures en diagonale.
- Traits verticaux : `FacingCameraWorldUp`, sinon ils sont plats vus de côté.
- `VelocityParallel` aligne l'**axe X de l'image** sur la vitesse : dessiner les traits **couchés**.

**Planches animées (flipbooks)** — doc Roblox
- Grilles 2×2, 4×4, 8×8 ou `Custom`. **Laisser une marge transparente autour de chaque image** (sinon bavures).
- `OneShot` : joue une fois sur la durée de vie (le framerate ne compte pas). `Loop` : `FlipbookFramerate`, **30 images/s au plus**. `Random` : fondu d'une image à l'autre, pour un scintillement lent.
- **Image fixe tirée au hasard** : `FlipbookStartRandom` + framerate 0.
- Les planches coûtent de la mémoire ; les vieux téléphones les coupent. **Réutiliser les mêmes textures** entre auras, préférer 512 à 1024.

**Beams**
- Courbe de Bézier : P1 = `CurveSize0` studs dans le +X de l'Attachment0, P2 = `CurveSize1` studs dans le −X de l'Attachment1. Tourner les Attachments pour orienter la courbe ; un second Beam en miroir avec la courbe négative.
- `Segments` 20 ou plus, `FaceCamera` pour être vu de partout.
- La texture d'un Beam doit **toucher les deux bords** de l'image, sinon elle se morcelle. Son axe vertical court le long du ruban (mémoire `roblox-ribbon-texture-orientation`).
- **Rotation sans script** : des anneaux de Beams dont la texture défile (`TextureSpeed`) donnent une tornade ou un vortex qui tourne. Un cercle en 2 Beams : Attachments en ±r, axes opposés, `CurveSize` ≈ 1,1 × r… à régler à l'œil (à vérifier pour un cercle parfait).
- Les **Trails** ne se dessinent pas en Edit : il faut un Play.

## 4. Lisibilité de jour et de nuit

- **Régler en plein jour, montrer aussi de nuit.** Un effet réglé dans le noir rate presque toujours au jour ; l'inverse est rare.
- **Tout ce qui est purement additif (`LightEmission` 1, couleurs claires) disparaît sur notre ciel clair.** Vérifié sur une dizaine d'auras de packs.
- Ce qui tient de jour : un **cœur opaque** (`LightEmission` ≤ 0,5, couleur saturée) ou du **noir derrière** (éclats ou voile en `LightEmission` 0). Le noir en contraste est la technique des meilleures auras (images 06, 09 ; pack B17).
- Ne pas contourner un manque de contraste par un contour épais : ça fait tube ou cartoon.
- **Nuit du jeu** (`src/shared/Config/Night.luau`, `Night.Sky`) : `ClockTime` 0, `Brightness` 1, `Ambient` 45,50,80, `OutdoorAmbient` 70,80,125. Pour une capture de nuit en Edit : poser ces 4 valeurs sur `Lighting`, capturer, **les remettre**. Ne jamais lancer un Play sans demander (d'autres sessions utilisent la place).
- Une PointLight de flash à 2 ou plus surexpose toute la scène de jour.
- Revue lumière du jeu (`docs/claude/notes/revue-lumiere.md`) : pas de bloom ni de néon partout.

## 5. Recettes par thème

Ce sont des points de départ tirés des références ; **aucune n'est encore validée par Clément**. Le benchmark du thème passe avant.

- **Éclair** : nuage toon gris au-dessus de la tête (validé : mesh Blender en boules fondues, couleurs de sommet à 3 tons, contour sombre en coque inversée) + pluie fine (validée : stries de 1,25 stud, `Lifetime` 0,06 à 0,15, vitesse 30 à 42, émises dans tout le volume sous le nuage, gris-bleu, transparence 0,2). L'éclair lui-même : **1 ou 2 particules en planche animée d'éclair dessiné**, `FacingCameraWorldUp`, du nuage au sol, 0,3 à 0,45 s, déclenchées par `Emit`. Arcs fins en planche sur le corps. Référence : pack B04 (asset 104797265894967) pour l'impact, B14 (78011019574795) pour les arcs. Refusé : cylindres, mesh extrudé, icône, contour bleu nuit, gros effets au sol.
- **Feu** : flammes de silhouette en planche (2×2 ou 4×4), grandes flammes derrière le perso, braises `VelocityParallel` qui montent, éclats noirs pour le contraste. Palier haut : vortex au-dessus de la tête + rubans en Beams courbes (B32, 121403739363367).
- **Glace** : brume de givre lente, flocons en image fixe tirée au hasard, éclats de glace en planche ; motif possible : sceau en flocon derrière le dos. Peu lumineux (la glace ne brille pas comme le feu).
- **Poison** : rien de bon trouvé dans les packs. Piste : bulles qui montent et éclatent (planche), brume verte basse, gouttes ; vert saturé + noir.
- **Money** : billets et pièces en planche qui tournent (le tapis CashRegister du jeu a déjà ces textures : 124877141136214, 93580691646372), éclats dorés. Rien cherché dans les packs.
- **Ninja** : fumée sombre en planche, traits noirs verticaux (image 09), feuilles ou shurikens. Rien cherché.
- **Vent** : coques de vent courbes à texture qui défile (meshes « run / wind », vidéo 3, non vue) ou Beams courbes.
- **Tornade** : anneaux de Beams empilés qui s'élargissent vers le haut, texture qui défile (B36, 113405326730173).
- **Pluie** : la pluie fine de l'aura Éclair, plus de petites flammes d'eau en planche (B39 Water-Aura-01).
- **Neige** : flocons qui tombent d'un disque au-dessus de la tête, rotation −30 à 30, fondu d'entrée, blancs et peu lumineux.
- **Sombre** : fumée noire en planche + arcs ou braises d'une seule couleur vive (image 07).

**Montée par palier** : palier bas = lueur + 1 couche de silhouette (3 ou 4 émetteurs) ; palier moyen = + éclats et specs ; palier haut = + un grand motif (ailes, vortex, orbe relié) et un moment fort ponctuel.

## 6. Fabriquer textures, planches et meshes

- **Toujours préférer une planche animée à une image fixe.**
- **Dessin procédural** (Python + Pillow) : `StealAShop-Art/FX/Aura3D/_src/toon_textures.py`. Dessiner à 4× puis réduire (bords propres). Bon pour formes simples : anneau, étincelle, éclat, onde.
- **Planches rendues dans Blender** : `StealAShop-Art/FX/Toon/_src/toon_fx.py` (mémoire `toon-vfx-blender-pipeline`) : Cycles + OSL, 16 plans dans une caméra ortho = une planche 4×4 en un rendu, film transparent, textures en gris pour teinter dans Roblox. Attention : Clément a jugé ces textures toon procédurales « horribles » pour les auras ; viser des formes **dessinées et organiques**, pas des aplats géométriques.
- **Meshes** (nuage, formes pleines) : Blender en ligne de commande (`C:\Program Files\Blender Foundation\Blender 5.2\blender.exe -b --factory-startup --python …`). Exemple complet : `StealAShop-Art/FX/Aura3D/_src/aura_eclair.py`.
  - Formes organiques : icosphères + modificateur Remesh (voxel) + lissage. Les metaballs fondent trop.
  - **Couleurs de sommet** : Roblox les affiche sur un MeshPart (mettre `Color` blanc). Donne un ombrage toon sans texture.
  - **Contour toon** : copie gonflée le long des normales, normales retournées (coque inversée). Une échelle négative sur un SpecialMesh ne retourne pas les faces.
  - Conversion Blender → Roblox : (x, y, z) → (−x, z, y).
- **Aperçu local sans import** (ce PC seulement) :
  - textures : copier les PNG dans `%LOCALAPPDATA%\Roblox\Versions\<version>\content\textures\StealAShopFX\` → `rbxasset://textures/StealAShopFX/<nom>.png` ;
  - meshes : écrire un fichier Roblox « version 2.00 » (`_src/export_rbxmesh.py`) dans `content\meshes\…` puis `AssetService:CreateMeshPartAsync(Content.fromUri("rbxasset://meshes/…"))`. Changer de nom de dossier à chaque version (cache).
  - Ces aperçus ne s'affichent pas chez Ironix ni dans le jeu : **rien n'est fini tant que ce n'est pas importé au nom du groupe**.
- **Vidéos** : `yt-dlp` et `ffmpeg` ne sont pas installés ; demander avant d'installer. La transcription se lit par le navigateur intégré (panneau « Afficher la transcription »).

## 7. Budget

- Par aura : **6 à 10 émetteurs, 2 lumières au plus**, aucun script, objets natifs seulement.
- Compter les **particules vivantes** = `Rate × Lifetime` par émetteur : viser 1 à 10, jamais 50 sur un seul.
- 8 joueurs peuvent porter une aura en même temps : multiplier par 8.
- Meshes : nuage ≤ 5 000 triangles, contour ≤ 1 600.
- Mobile d'abord : planches en 512, textures partagées entre auras.

## 8. Sécurité des packs du Creator Store

**3 packs sur 39 testés portaient un piège** : un Script `Runtime` et un LocalScript `ScreenBuilder`, cachés dans un ScreenGui sous un Beam. Au Play, ils affichent une fausse fenêtre « Roblox Studio — Recovery » qui demande de coller une ligne dans la barre de commande ; cette ligne installe une porte dérobée. D'autres packs ont des scripts `Check`, `CoreValidation`, `Material`, `CoreTextureSystem`.

1. Insérer **uniquement dans `ServerStorage/_BENCH_AURAS`**, jamais dans Workspace.
2. Aussitôt : désactiver chaque `Script` et `LocalScript` (`Enabled = false`, attribut `DesactiveParClaude`), marquer les ModuleScripts (y compris la racine du pack), supprimer tout ScreenGui.
3. Pour regarder un effet : cloner dans une zone de test, puis **supprimer tout ce qui n'est pas** BasePart, Attachment, ParticleEmitter, Beam, Trail, Model, Folder, Decal, Texture, mesh, lumière. Vérifier à la fin : 0 script, 0 ScreenGui. Les mannequins créés par `CreateHumanoidModelFromDescription` portent un LocalScript `Animate` : le retirer aussi.
4. **Aucun Play** avec un pack non nettoyé. **Ne jamais coller une ligne** proposée par une fenêtre. Ne jamais réactiver un script marqué.
5. Les textures des packs appartiennent à d'autres créateurs, et beaucoup de packs sont des reprises : vérifier la page de l'asset, ou redessiner. Clément a refusé des copies recolorées d'un pack.
6. L'outil `search_asset` ne donne qu'une page par recherche, sans notes : varier les mots plutôt que chercher une pagination.

## 9. Contrat et livraison

- **Nom** : `FX_Aura_<Nom>`, PascalCase sans accents. Modèle dans `ReplicatedStorage/Assets/FX/Auras/`. Le Decal du même nom reste **enfant direct de `Assets/FX`** (mémoire `fx-decals-homonymes`).
- **Structure lue par le code** (`CosmeticService`, à Ironix : ne jamais toucher `src/`) : le modèle reprend les pièces R15 par leur nom (`HumanoidRootPart`, `UpperTorso`, `Head`, mains, pieds). Le code copie **les Attachments de chaque pièce**, avec leurs émetteurs, lumières, Beams et Trails, sur la pièce du même nom du joueur. Donc : tout émetteur ou Beam doit être **sous un Attachment**, pas posé à même la pièce. Un Attachment du `HumanoidRootPart` à moins de 0,5 stud du sol est recalé sur les pieds du joueur.
- Ce que le code **ne fait pas** aujourd'hui : copier des MeshParts, déplacer un Attachment, appeler `Emit`, faire tourner ou clignoter quoi que ce soit. Tout effet ponctuel (coup de foudre, flash) ou tout mesh (nuage) demande du code client : l'écrire pour Ironix dans une note (noms des objets, attribut `EmitCount` sur les émetteurs à `Rate` 0, durées), jamais un script dans l'aura.
- Prix, multiplicateur et ordre : `src/shared/Config/Cosmetics.luau`. Ne rien inventer.
- **Import** : meshes et textures au nom du groupe **RoundStone Studio** (groupId 207192094). Par `open_cloud_invoke`, le dossier source doit être approuvé dans Studio (Assistant Settings → MCP Permissions) ; sinon Clément importe par l'Importateur 3D.
- Avant livraison : ContractChecker sans ligne rouge (mémoire `contractchecker-edit`), aucun script ni ScreenGui dans ce qu'on livre, rien en PROD, note courte pour le chef de projet.

## 10. Grille d'auto-critique (avant chaque envoi)

Regarder sa capture à côté de la référence et répondre honnêtement :

1. Le personnage est-il visible et reconnaissable ?
2. L'effet se lit-il à 30 studs **en plein jour** ? Et de nuit ?
3. Y a-t-il un élément plat qui fait PNG (image fixe, aplat, anneau épais) ?
4. Y a-t-il un tube, un contour épais, un trait droit qui ressemble à un bug ?
5. Le sol attire-t-il l'œil plus que le reste ?
6. Le moment fort donne-t-il un « boum » sans masquer le joueur ?
7. Tout a-t-il un fondu d'entrée et de sortie ? Les vitesses sont-elles variées ?
8. Ai-je ajouté du toon, un sol ou un motif que Clément n'a pas demandé ?
9. La capture est-elle fraîche (vue 3D non figée), sans effet voisin dans le cadre ?
10. Qu'est-ce que je n'ai pas vérifié ? Le dire dans le message.

Si une réponse est mauvaise : corriger et refaire un tour avant d'envoyer.

## 11. Ce qui reste à apprendre

- Vidéos 1 à 4 de `videos/liens.md` : non vues (pas d'images, pas de transcription).
- Meshes de vent et de flammes dans Blender (vidéo 3), « slash » (vidéo 4), ailes en fumée (image 08) : techniques non vérifiées.
- Thèmes money, ninja, neige, vent : pas encore benchmarkés.
- Bibliothèques B18 (898 images) et B20 (1 381 textures) : seule une sélection de 20 est testée.
