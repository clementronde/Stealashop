# Atelier du skill « modèles dans la DA »

Commencé le 2026-11-21 avec Clément. But : un skill qu'on appelle avec un nom d'objet (« un capybara en peluche, Commun ») et qui sort le bon modèle, du premier coup, dans le style du jeu.

On ne l'écrit pas d'abord : on le **trouve** en essayant. On fait des tours de prompts (ChatGPT pour la planche, puis Claude Design pour la 3D), on note chaque résultat, on corrige le bloc de style, et on recommence jusqu'à ce que ça marche sur plusieurs sortes d'objets. Le skill final reprend les prompts qui ont marché, mot pour mot.

## La chaîne

1. **Fiche de l'objet** : nom, rareté, zone, taille en studs, pièces (voir `catalogue-v3-proposition.md`).
2. **Planche ChatGPT** : prompt de [tour-01.md](tour-01.md), avec en pièce jointe la **référence du colis** (`img/revue-2026-11-20/15_canette_studs_vue_ensemble.jpg`, à remplacer par une vraie planche du colis dès qu'on a de bonnes captures). Résultat : face, côté, dos, trois-quarts et palette.
3. **Contrôle de la planche** avec la grille ci-dessous. Si elle ne passe pas, on redemande dans la même conversation en nommant ce qui ne va pas (3 essais au plus).
4. **Claude Design** : le prompt 3D de l'objet, avec la planche validée en pièce jointe. Résultat : un `.glb`.
5. **Contrôle du `.glb`** : taille, triangles, noms des pièces (agent `prompteur-3d`).
6. **Import dans Studio**, puis [appliquer-da.luau](appliquer-da.luau) : studs sur `Body*`, contour noir, ancrage, pivot. On pose l'objet dans `_EXEMPLE_STUDS` à côté du colis.
7. **Capture et note**, puis une ligne dans le journal ci-dessous. On change **une seule chose** dans le bloc de style pour le tour suivant.

## Ce qu'on fait varier

- [style-v1.md](style-v1.md) : le bloc de style en anglais, commun aux deux prompts. C'est lui qu'on règle, version par version (v1, v2…). On ne réécrit jamais une version : on en crée une nouvelle.
- Les images jointes : la référence du colis seule, ou le colis plus les modèles déjà validés. Plus on a d'exemples validés, mieux ça marche.

## Les 3 objets de test

Un skill qui ne marche que sur une boîte ne sert à rien. On teste donc 3 familles de formes en même temps :

| Famille | Objet de test | Rareté | Ce qu'il teste |
| --- | --- | --- | --- |
| Objet simple | Bubble tea (`Z1_BubbleTea`) | Commun | Studs sur un cylindre, cadre sur un petit objet |
| Créature | Capybara en peluche (`Z2_CapybaraPlush`) | Commun | Un visage mignon, des formes rondes en blocs |
| Objet très rare | Œuf de dragon (`Z5_DragonEgg`) | Légendaire | Le cadre or, le néon et les cristaux de l'Exclusive Crate |

## La grille (sur 20)

Chaque point vaut 0 (non), 1 (à moitié) ou 2 (oui). **Validé : 16 sur 20 ou plus, sans aucun 0.**

| # | Critère | Comment juger |
| --- | --- | --- |
| 1 | On reconnaît l'objet | En silhouette noire, et en vignette de 64 px |
| 2 | Il ressemble à l'Exclusive Crate | Posé à côté du colis, il fait partie de la même famille |
| 3 | Studs sur les grandes faces | Studs sur les faces planes du corps, pas sur les petits détails |
| 4 | Cadre lisse sur les bords | Bords épais, lisses, avec de petits biseaux |
| 5 | Couleurs | 3 à 5 couleurs pleines, celle de la rareté au bon endroit |
| 6 | Trapu, rien de fin | Pas de tige, de fil ni de pointe fine ; une créature a une grosse tête |
| 7 | Vues cohérentes | Planche : mêmes proportions de face, de côté et de dos |
| 8 | Pièces séparées et nommées | `Body`, `Frame`, `Accent`, `Neon_*`, `Root` (voir le style) |
| 9 | Budget | Moins de 2 000 triangles (4 000 à partir de Légendaire), 600 visés |
| 10 | Taille et pivot | La bonne taille en studs, pivot en bas au centre, face avant vers −Z |

Les points 7 à 10 se jugent sur le `.glb`, ou sur la planche quand on n'a que la planche.

## Journal des tours

| Tour | Objet | Style | Planche (/20) | 3D (/20) | Ce qui ne va pas | Changement pour le tour suivant |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Bubble tea | v1 | 18 (un 0) | — | **Échelle fausse** : le gobelet est aussi haut que le perso R15 (au lieu d'un tiers). Sinon très bien : studs en carreaux sur le corps, cadre blanc lisse et biseauté, paille épaisse, 4 couleurs, contour noir | Mise en page : dessiner l'objet à sa vraie taille à côté du R15 |
| 1 | Capybara | v1 | 15 (un 0) | — | Échelle fausse. **Ressemble à un ourson** (oreilles rondes, museau court). Vue de côté peu cohérente. Studs sur le dos et la tête, ventre et museau lisses : bien. Bandeau de titre et étiquette « COMMON » ajoutés | Fiche de l'objet : décrire l'anatomie du capybara (tête longue en pavé, gros nez plat, toutes petites oreilles, corps en tonneau, « not a bear ») |
| 1 | Œuf de dragon | v1 | 17 (un 0) | — | Échelle fausse. **Fissures de néon trop fines** (zigzags en traits). Le reste est très proche du colis : cadre or, cristaux, nid, écailles en blocs | Style : le néon en bandes épaisses, au moins aussi larges qu'un stud |

| 2 | Bubble tea | v2 | **19, validée** | — | Échelle juste (petite vue à la vraie taille près du R15, puis les 4 grandes vues). Perles en carrés posés sur la face, un peu « peintes » | — |
| 2 | Capybara | v2 | **18, validée** | — | Échelle juste. Le profil montre bien la tête longue et le gros nez du capybara ; de face, il ressemble encore un peu à un ours. Pas de bande lisse sur les bords (seulement le ventre et le museau lisses) | Pour les créatures : demander une face avant plus allongée (nez qui avance) |
| 2 | Œuf de dragon | v2 | **19, validée** | — | Néon en bandes épaisses, échelle juste. Cristaux un peu plus petits et pointus qu'au tour 1 | Demander des cristaux « big chunky » à 6 pans, plus gros |

**3D du tour 2 (Claude Design, prompts de [tour-02-3d.md](tour-02-3d.md)) :**

| Objet | 3D (/20) | Ce qu'on voit |
| --- | --- | --- |
| Capybara | 14 (un 0), non validé | La technique est juste : 1,40 × 1,60 × 1,50 studs, base à y = 0, face vers −Z, 728 triangles, pièces bien nommées (Body 176, Frame 264, Face 124, Accent 120, AccentLeaf 32, Root 12). Mais **la tête et le corps ne font qu'un seul pavé** : on dirait une boîte avec un visage, pas la créature chibi de la planche. Le museau et le « Y » de la bouche sont plaqués sur la face, et les oreilles sont posées aux coins. 0 au point 7, car il ne suit pas la planche |
| Capybara (après correction) | **17, validé de justesse** | 736 triangles, mêmes taille, pivot et noms. Tête séparée, museau plat qui avance, yeux fermés sur les côtés, petites oreilles, pattes avant posées devant : on reconnaît un capybara de trois quarts. Mais la tête n'est pas plus grosse que le corps (pas assez chibi), et le tout reste très « boîte » : pas de bande lisse sur les bords |
| Bubble tea | **18, validé** | 592 / 600 triangles, 1,00 × 1,00 × 1,80 studs, pivot (0, 0, 0). Gobelet à 12 pans, cadres blancs épais en haut et en bas, paille épaisse, perles en petits cubes autour du bas du gobelet. Le couvercle bombé fait un peu « cage » (nervures blanches et panneaux roses) |
| Œuf de dragon | **17, validé** | 1 094 / 1 200 triangles, 1,40 × 1,40 × 2,00 studs. Coque à facettes, 2 bandes or épaisses, fissures de néon en larges zigzags, nid en blocs gris. Le pack VFX est fourni (`DragonEggVFX.lua`, `DragonEggVFX.client.lua`, `README.md`). Les cristaux sont trop petits et cachés au pied de l'œuf |

Aperçus 3D : `tour-02/*_3d_*_apercu.jpg` (captures de la visionneuse).

**Les `.glb` du tour 2 (2026-11-21) :**
- Le bubble tea est dans `tour-02/bubble-tea_3d_v1.glb` (46 Ko). Il est arrivé dans les Téléchargements à 02:58, et on ne sait pas si c'est un de mes clics ou celui de Clément.
- Le fichier est conforme au prompt, contrôlé avec [lire-glb.ps1](lire-glb.ps1) :
  - 592 triangles ;
  - 1,00 × 1,80 × 1,00 studs, base à y = 0, centré ;
  - les 6 pièces demandées (`Root`, `Body`, `Frame`, `Frame2`, `Accent`, `Accent2`), avec exactement les couleurs du prompt ;
  - des UV, aucune texture, aucune animation.
- Le capybara corrigé est dans `tour-02/capybara_3d_v2.glb` (77 Ko, arrivé à 04:57). Lui aussi est conforme au prompt :
  - 736 triangles sur 800 ;
  - 1,40 × 1,50 × 1,60 studs (largeur × hauteur × profondeur), base à y = 0, centré ;
  - les 6 pièces demandées (`Body`, `Frame`, `Face`, `Accent`, `AccentLeaf`, `Root`), avec exactement les couleurs du prompt.
- L'œuf n'est pas encore téléchargé. Quand je clique sur « Download GLB », aucun fichier n'arrive : 3 essais sur le capybara, dans 2 onglets. La page `chrome://downloads` n'est pas accessible à l'extension.
- Pour le skill, **c'est donc Clément qui clique sur « Download GLB »**, puis Claude range et contrôle le fichier.

**Style v3, version A (en blocs dans Studio, 2026-11-21) :** 21 Parts en `Studs`, en croix étagées (3 étages pour le gobelet, couvercle en 2 marches, perles en cubes de 0,125, paille carrée de 0,25). Capture : `tour-02/bubble-tea_A_parts_studio.jpg`. Les studs ont exactement la même taille partout, comme sur les références, et on reconnaît le bubble tea. Mais à la taille du jeu, on ne voit qu'un ou deux studs par face, et le rose paraît délavé sous la lumière du jour. Note provisoire : 17 sur 20. 

**Style v3, version B (Claude Design en blocs) :** projet « Roblox Bubble Tea Model », fichier `Bubble Tea Brick.html`. 29 boîtes, 348 triangles, 1,00 × 1,00 × 1,80 studs, pièces bien nommées. Le visualiseur propose un aperçu « Studs 1:1 ». Capture : `tour-02/bubble-tea_B_claude-design-blocs.jpg`. Note : 15 sur 20. La construction en boîtes est respectée, mais les perles sont trop grosses et en tas, le gobelet est étroit et disparaît entre les gros cadres blancs, et ça se lit moins bien comme un bubble tea que la version A. Il resterait aussi à l'importer dans Studio (envoi d'un asset), et à vérifier que la texture `Studs` suit bien les UV d'un MeshPart.

**Verdict A contre B :** la **version A gagne**. Elle a le même rendu de blocs, des studs réguliers garantis, aucun import ni asset à envoyer, et elle se règle bloc par bloc dans Studio. La chaîne du skill devient donc : planche ChatGPT, puis construction en Parts dans Studio par Claude (Luau), puis capture et note. Claude Design ne sert plus que pour les formes trop organiques pour les blocs. Reste à régler la taille des studs sur les petits objets, avec un variant `StudsSmall`.

**Décision de Clément (2026-11-21, après les tests A/B) :** on revient à la méthode d'avant les tests, celle de l'Exclusive Crate. La planche ChatGPT passe par le style v2, puis Claude Design fait un maillage aux grandes faces planes, avec les studs posés dans Studio par `appliquer-da.luau`. Les modèles de référence sont ceux du tour 2 : bubble tea, capybara corrigé et œuf de dragon. Le style v3 « tout en blocs » et la méthode en Parts restent notés, mais ils ne sont pas retenus pour le skill.

**Test `StudsSmall` (2026-11-21) :** j'ai ajouté le variant `MaterialService/StudsSmall` (copie de `Studs`, `StudsPerTile` 0,5), puis posé une copie du bubble tea à la taille du jeu dans `_EXEMPLE_STUDS` (`EX_A_BubbleTea_StudsSmall`, à gauche de l'original). Capture : `tour-02/bubble-tea_A_StudsSmall_vs_Studs.jpg`. On passe d'environ 1 carreau par face à 2 : c'est mieux, et plus proche des références. Deux écarts restent avec les références :
1. **La texture `Studs` actuelle n'est qu'un dessin de carré en creux** (ColorMap seule, sans NormalMap). Les références ont des studs **en relief**, à coins arrondis, avec de vraies ombres. Il faudrait une nouvelle texture de studs avec une NormalMap, c'est le plus gros levier visuel.
2. Le rose `#F7A8C8` sort lilas sous l'éclairage du jeu : il faut des couleurs plus saturées que sur la planche (par exemple `#FF8FC0`).
Une tuile de 0,33 donnerait 3 carreaux par face, à essayer si 2 ne suffisent pas.

**Ce que la 3D apprend :**
- Claude Design suit très bien la technique : taille, pivot, noms des pièces et budget sont justes du premier coup sur les 3 objets.
- Il simplifie la forme plus que la planche. Pour une créature, il faut écrire la hiérarchie des volumes (« tête séparée, plus grosse que le corps »), sinon il fait un seul pavé.
- Les détails secondaires rétrécissent (cristaux, perles). Il faut leur donner une taille en studs (« cristaux de 0,4 stud de haut au moins »).
- Un projet à la fois : à 3 en parallèle, il y a eu 2 à 4 coupures par projet.

Leçons : lancer les 3 projets en même temps semble provoquer des coupures, il vaut mieux les faire un par un. Pour une créature, il faut demander **une tête séparée du corps**, plus grosse que lui (« separate head part, bigger than the body, sitting on top of it »), sinon Claude Design colle tout dans un seul bloc.

Aperçu 3D : `tour-02/capybara_3d_v1_apercu.jpg` (capture d'écran de la visionneuse).

Aperçus : [tour-01/](tour-01/) et [tour-02/](tour-02/). Les `*_apercu.png` sont des captures d'écran. Les planches d'origine du tour 2, à joindre à Claude Design, ont été téléchargées le 2026-11-21 : `tour-02/bubble-tea_planche_v2.png`, `capybara_planche_v2.png` et `oeuf-dragon_planche_v2.png`.

Planches du tour 1 : conversations ChatGPT « Create Bubble Tea Model Sheet », « Create character model sheet » et « Dragon Egg Model Sheet » (compte de Clément), pas encore téléchargées.

**Ce que le tour 1 apprend :**
- Le bloc v1 donne déjà la bonne famille : studs en carreaux sur les grandes faces, cadre lisse, contour noir. Les 3 objets ressemblent à l'Exclusive Crate.
- ChatGPT dessine toujours l'objet à la taille du personnage. Une simple phrase de dimensions ne suffit pas : il faut l'écrire en rapport (« à peu près un tiers de la hauteur du perso »).
- Pour une créature, il faut décrire l'animal, sinon ChatGPT retombe sur un ourson.
- Le néon et les petits détails doivent être demandés épais, sinon ils sortent en traits fins.

## Ce qu'on a déjà, et qui sera fondu dans le skill

- `.claude/agents/planches-chatgpt.md` : fait faire les planches par ChatGPT dans Chrome. Il s'appuie encore sur l'ancienne DA des colis lisses (`DA-reference-colis.md`).
- `.claude/agents/prompteur-3d.md` : écrit le prompt Claude Design et vérifie le `.glb`. Il parle déjà du « mode studs », mais pas du cadre lisse de l'Exclusive Crate. Il pointe vers `C:\Users\Charment\Documents\StealAShop-Art\`, absent de ce PC.
- `.claude/skills/aura-vfx` : le modèle à suivre pour la forme du skill (règles de Clément, méthode, grille d'auto-critique).
- Dans l'outil Roblox Studio : `generate_mesh` et `generate_procedural_model` (génération 3D de Roblox). C'est une troisième voie à essayer pour comparer, sans passer par Claude Design.

## Skills trouvés sur internet (le 2026-11-21)

Aucun ne fait notre style « colis en studs avec cadre lisse ». Il y a des choses à reprendre, à lire avant de les installer (on n'installe rien sans l'accord de Clément) :

- [SyphoDev roblox-ai-skills](https://github.com/SyphoDev-yt/roblox-ai-skills) : un skill `roblox-3d-model`, du texte ou d'une image jusqu'à un MeshPart, via Blender et Hugging Face.
- [claude-roblox-game-studio](https://skills.rest/skill/generate-asset) : `generate-asset` et `asset-from-image` (génération par IA, finition dans Blender, export FBX pour Roblox).
- [RBSmithy](https://github.com/gogolumo/rbsmithy-roblox-claude-skill) : fiches d'objets, ébauches en Python pour Blender et prototypes en Parts.
- [ohzw roblox-design-consultant](https://github.com/ohzw/roblox-dev-skills/blob/main/.claude/skills/roblox-design-consultant/SKILL.md) : fait correspondre un style aux matériaux et couleurs de Roblox.
- [arjun988 lowpoly-style](https://skills.sh/arjun988/blender-skills/lowpoly-style) : règles de low-poly lisible (grandes formes, silhouette).
- Studify (cité sur [roclicks.gg](https://roclicks.gg/make/building)) : construction de décors en studs. Son SKILL.md n'est pas public.

## Questions et décisions ouvertes

1. **Couleur du cadre.** Sur le colis, il est en or. Proposition de la v1 : le cadre prend la couleur de la rareté (gris Commun, menthe, bleu, violet, or à partir de Légendaire). Ça se lit de loin et ça ne coûte rien.
2. **Taille des studs.** Sur un objet de 1,5 stud, le variant `Studs` est trop gros. Il faut sans doute un variant `StudsSmall` (tuile de 0,25), à tester au tour 1.
3. **Captures propres du colis** pour la référence : la vue 3D de Studio était figée le 2026-11-21. Il faut cliquer dans la vue avant de capturer (voir `aura-vfx`, section 2).
4. **Claude Design** : je colle moi-même les prompts dans Chrome, comme au tour 2. Mais mes clics sur « Download GLB » ne téléchargent rien. Pour l'instant, c'est donc Clément qui télécharge les `.glb`.
