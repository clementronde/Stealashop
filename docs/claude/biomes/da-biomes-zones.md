# Biomes des 6 zones : constat et propositions (Chef DA, 28/11)

Demande de Clément (28/11) : « dans les jeux comme Steal an Egg, il y a des grosses différences de biome entre les maps ; chez nous, pas du tout ». Planches : `StealAShop-Art/Captures/2026-11-28_biomes/` (`00_ensemble.jpg`, puis `Z1` à `Z6`). Rien n'a changé dans Studio.

## 1. Constat chez nous (mesuré sur les covers 11 à 16 du 27/11)

| Zone | Ciel | Sol | Façades (5 tons dominants) |
| --- | --- | --- | --- |
| Z1 supérette | #3ec4ea | #4c6ca1 bleu | #6fd1cb #b8cbcf #47679e #69aac9 #cceae1 |
| Z2 Londres | #41bde2 | #6b82a4 bleu | #cfd7db #9bb3d1 #6c6c99 #9bd7dd #dfecea |
| Z3 Tokyo | #42afd4 | #424c89 bleu | #051c4e #5b7d9c #5e2763 #91c2d2 #d1d9d5 |
| Z4 Los Angeles | #4faac9 | #474276 bleu | #042c5e #39497d #a3c2ce #7293a5 #d0d5cd |
| Z5 Paris | #5bafcf | #edf1f2 blanc | #0a3370 #692c53 #93a7b0 #c2d5d8 #f1f2ea |
| Z6 New York | #559bbe | #152744 bleu nuit | #123a6d #7089a6 #9fb6bf #50547c #dbd8b7 |

- **Un seul ciel, une seule lumière, une seule heure** pour tout le couloir (le même ciel peint, `Lighting` à 14 h 30). Le code n'a pas de lumière par zone : le `SkyController` ne change que le jour et la nuit.
- **Le même sol bleu marine à tenons** dans 5 zones sur 6 (Paris est blanc, et éblouit).
- **Des façades froides** partout : le bleu domine les 6 palettes. Seules les enseignes changent.
- **La météo existe, mais elle est discrète** : pluie à Londres, pétales à Tokyo, chaleur à LA, neige à Paris et à New York (doublon), pollen en zone 1. Elle ne change ni le ciel ni le sol.
- **« AI slop » des rues** : ce ne sont pas des modèles Meshy (les rues sont faites de pièces, environ 3 000 par zone, posées par les scripts `tools/clement/zones/`), mais **des décors pauvres et répétés**, de 2 à 8 pièces lisses, sans tenons ni contour :
  - Z1 `Street_Zone1/Props/Lamp` (8 pièces), `Neighborhood_Zone1/Parks/Fountain` (5) ;
  - Z3 `Street_Tokyo/Props/Vending` (×4, 5 pièces), `Props/Pole` (×4, 5), `Houses/House` (×4, 9), `City/Tower` (×8, 26 : des boîtes) ;
  - Z4 `Street_LosAngeles/Props/Lamp` (×6, 5), `Props/Hydrant` (×4, 6), `Buildings/Bungalow` (7), `Boutiques/Boutique` (×10, 19 : la même façade dix fois), `Skyline/Tower` (×7) ;
  - Z5 `Street_Paris/Pigeons/Pigeon` (×10, 3 pièces), `Garden/Bench` (3), `District/BoulevardLamp` (3), `Facades/Haussmann` (×10, 44 : le même immeuble dix fois) ;
  - Z6 `Street_NewYork/Props/StreetLamp` (×8, 5), `Props/TrashCan` (2), `Props/Hydrant` (6), `Parking/Taxi` (×3, 11), `Skyline/Tower` (×14, 12 : des boîtes) ;
  - Z2 : `Buildings/Terrace_*` (×16, 6 à 9 pièces) et `Mansion` (×5).
  À garder : la cabine rouge et le bus de Londres (37 et 46 pièces), la grande roue (189), le torii et le temple de Tokyo, le dôme doré de Paris, les immeubles de New York (`Tenement_*`, 35 à 69 pièces), les arbres du pack Yasu.

## 2. Ce qui fait un biome chez les concurrents

Détail dans `biomes-concurrents.md` (même dossier) et images dans `Captures/2026-11-28_biomes/references/`. Un seul des jeux étudiés a des biomes (le jeu des œufs : prairie, forêt, désert, neige, magenta) ; les concurrents F et G n'ont qu'une plaine verte, et c'est ce qui les rend fades. Leviers mesurés, du plus fort au plus faible :
1. **Un sol d'une seule couleur saturée sur toute la largeur de la zone** (vert #81D725, sable #F6D154, blanc rosé #F9E8F4, magenta #DA5BE0).
2. **Un repère géant, 3 à 5 fois la taille du joueur, visible depuis la zone d'avant** (sphinx, yéti, dragon).
3. **Des murs qui changent de matière**, avec le décor de la zone posé sur leur sommet.
4. Trois ou quatre éléments de décor répétés en grand nombre (cactus, sapins, sucettes).
5. Une couleur d'accent dans le feuillage ; des objets à voler teintés comme la zone ; un peu de fumée colorée.
6. **Leur ciel ne change jamais** : un seul ciel pour toute la carte. Le biome tient au sol, aux murs, au décor et au repère.

Transitions chez le concurrent : le sol change d'un coup, avec une marche, sans arche (chez nous : coupure de couleur nette, sans marche, décision prise à Tokyo) ; on aperçoit la zone suivante depuis le bord ; un bandeau d'entrée et un visage de difficulté au-dessus du gardien. Ce qui reste commun : le HUD, les tenons, le gabarit du couloir et le ciel.

**Conséquence pour nous** : l'essentiel se fait dans Studio, sans code (sol, murs, décor, repère). Le ciel et l'heure par zone sont un plus, qui demande Cantin, mais on peut s'en passer pour la zone pilote.

## 3. Propositions, une par zone

Règle commune : chaque zone a **son heure, son sol et sa météo**, et aucun des trois ne se répète. La chaussée de course, les passages piétons, l'UI et les tenons restent communs, pour que le joueur ne se perde pas.

| | Z1 Banlieue d'été | Z2 Londres sous la pluie | Z3 Tokyo néon | Z4 Los Angeles au couchant | Z5 Paris en automne | Z6 New York, neige au crépuscule |
| --- | --- | --- | --- | --- | --- | --- |
| Heure et lumière | midi, soleil blanc, ombres courtes | 15 h 45, ciel couvert, lumière froide et grise | coucher de soleil clair (17 h), ciel rose-violet lumineux, néons en plus | 17 h 20, soleil orange rasant, ombres longues | 10 h, lumière douce rose doré | 16 h 35, fin d'après-midi d'hiver bleu acier et pêche, fenêtres qui s'allument (jamais la vraie nuit) |
| Brouillard | aucun, air très clair | brouillard bas gris-vert, épais au loin | brume rose légère au sol | brume de chaleur orange au loin | voile léger crème | neige qui bouche le fond |
| Sol | trottoirs béton clair et pelouses vertes, chaussée gris chaud | pavés sombres mouillés, flaques qui reflètent | bitume noir mouillé, reflets roses et cyan | bitume pâli par le soleil, trottoirs sable | pavés beige, feuilles mortes en tas | chaussée sale et neige en bord de trottoir, gadoue |
| Palette | #5fbf3f pelouse, #ffd23f beurre, #e0623c tuile, #f7f3e8 palissade, #59c9f2 ciel | #a4372d brique, #d62828 rouge bus, #1f4d3a vert anglais, #5b6470 ardoise, #f2c14e lampe | #ff3ea5 rose néon, #18e0ff cyan, #6b2bd9 violet, #e63946 lanterne, #12122a encre | #ff8c42 orange, #ff5d8f rose, #2a9d8f palme, #f4d58d sable, #3bc9db piscine | #efe3c8 pierre, #6f7f8f zinc, #b23a48 rouge café, #d4a72c or, #e07a2f feuille | #ffcc00 taxi, #8c3b2a brique, #4a6a9a acier, #ffb347 fenêtre, #eef3f8 neige |
| Météo, particules | pollen (déjà), papillons, arrosage des pelouses | pluie plus franche (déjà), flaques qui ondulent | pétales (déjà) et poussière de néon | air qui tremble (déjà), poussière dorée | feuilles qui tombent, à la place de la neige | neige épaisse (déjà) et vapeur des bouches d'égout (déjà) |
| Objets de rue signature | palissades blanches, boîtes aux lettres, camion de glaces, arroseurs, nains de jardin | lampadaires à gaz, taxi noir, borne postale rouge, parapluies, cabine (garder) | distributeurs voxel, guirlandes de lanternes, enseignes verticales, chat porte-bonheur | palmiers (garder), planches de surf, food truck, cabriolet, néon de motel | terrasse de café, fontaine Wallace, colonnes Morris (garder), étals de bouquinistes | taxis jaunes voxel, chariot de hot-dogs, escaliers de secours, guirlandes de Noël |
| Monument | château d'eau géant au nom de la rue | une seule grande tour d'horloge, au fond | pagode à cinq toits illuminée | grandes lettres sur la colline (« HEIST ») | tour de fer en treillis | gratte-ciel Art déco à flèche, étages éclairés |
| Entrée de zone | haie taillée en arche, panneau « Bienvenue » | arche de briques et lanternes à gaz, brouillard derrière | grand torii (agrandir celui d'aujourd'hui) | arche de néon de motel | bouche de métro Art nouveau, fer vert | arche de pont suspendu, câbles d'acier |

Paris passe à l'automne pour que la neige reste à New York seul. Le blanc éblouissant du sol de Paris disparaît.

**Décision de Clément (28/11)** : biomes validés « sauf la nuit » ; New York passe au crépuscule d'hiver (17 h), pour ne pas se confondre avec la vraie nuit du jeu, qui ferme le couloir. Zone pilote : **Tokyo néon** (fiche `da-fiche-tokyo-neon.md`). Valeurs d'ambiance pour Cantin : `da-ambiances-zones-cantin.md`.

## 4. Comment le faire

| Élément | Où | Qui |
| --- | --- | --- |
| Sol (couleur, matière, pelouses, pavés, flaques) | Studio, par les scripts de zone (`zoneN_*.luau`) : couleurs et matières des pièces | nous (Map) |
| Façades (palette, toits, variété des immeubles répétés) | Studio, par les scripts de zone ; varier `Haussmann`, `Boutique`, `Tower` (couleur, hauteur, toit) | nous (Map) |
| Météo et particules | Studio, `ParticleEmitter` natifs dans les scripts d'ambiance (déjà en place, à renforcer) | nous (VFX) |
| **Ciel, heure, brouillard, teinte par zone** | Des préréglages par zone (`Atmosphere`, `ColorCorrection`, `Sky`, heure et couleurs en attributs) que nous posons dans `ReplicatedStorage/Assets/ZoneLooks/Z1..Z6`, **et un petit contrôleur client qui passe de l'un à l'autre quand on change de zone** (comme le bandeau de zone le fait déjà). Le contrôleur est du code : **liaison pour Cantin** | nous + Cantin |
| Objets de rue signature | **Blender** en voxel à tenons (recette validée, agent `createur-stud-voxel`), puis refaits en pièces à tenons par le convertisseur du dépôt | nous (3D) |
| Monuments et entrées | Studio en pièces à tenons pour les grands volumes (arches, tours), Blender pour les détails | nous (Map, 3D) |
| Arbres et feuillage | pack du Creator Store vidé de ses scripts (comme le pack Yasu), teinté par zone | nous (Map) |

Ordre proposé, du plus fort au moins coûteux, comme chez le concurrent :
1. **Le sol de toute la zone**, trottoirs compris, dans la couleur du biome ; la chaussée prend un ton plus foncé de la même couleur, et les passages piétons restent blancs. Une coupure de couleur nette au sol entre deux zones, sans marche (décision prise à Tokyo). (Studio, S)
2. **Le monument géant**, visible depuis la zone d'avant. (Studio en pièces à tenons, M)
3. **Les murs et les façades** dans la palette, avec le décor de la zone posé sur les toits. (Studio, M)
4. **Trois ou quatre objets signature répétés**, refaits en voxel à la place des décors pauvres. (Blender, M à L)
5. La météo renforcée, puis, en option, le ciel et l'heure par zone (Cantin).

**Zone pilote** : Tokyo néon ou Los Angeles au couchant, les deux qui tranchent le plus. Elle est montrée à Clément en vraie 3D avant les cinq autres.
