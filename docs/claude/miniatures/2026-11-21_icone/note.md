# Icône « La casse » v1 (MOD-043, 2026-11-21)

**Piste A**, choisie par Clément le 2026-11-21 sur les croquis ([croquis-pistes.png](croquis-pistes.png)).
Capture dans Studio (place DEV, en Edit), retouche en Python avec Pillow. Rien n'est publié.

## Fichiers

| Fichier | Contenu |
| --- | --- |
| [ICON_StealAShop_v1.png](ICON_StealAShop_v1.png) | Icône 512 × 512 |
| [controle_planche.png](controle_planche.png) | Icône à 512, 150 et 64 px, coins arrondis, cercle de 440 px |
| [controle_grille.png](controle_grille.png) | Icône à 150 px au milieu de 14 icônes « Steal a … » relevées au benchmark |
| `brut.png`, `matte.png` | Captures Studio (1469 × 753) : la scène, puis la même avec le perso et la masse en vert, la Couronne en magenta (masques) |
| `essais/` | Cadrages essayés avant celui-ci |

Refaire : `tools/clement/miniatures/icone_casse_scene.luau`, puis la capture, `icone_casse_matte.luau`, la 2e
capture et `icone_casse_nettoyage.luau` ; ensuite
`py -I tools/clement/miniatures/retouche_icone.py docs/claude/miniatures/2026-11-21_icone 505 120 620 600 388`.

## Ce qui est montré (tout existe dans le jeu)

- **Moment** : la casse de la vitrine de la Bijouterie (zone 4), vue **de l'intérieur de la boutique** : le perso
  frappe depuis la rue, les cubes de verre jaillissent vers nous, la Couronne est au premier plan.
- Perso : copie du rig R15 de travail (`Rig_Player`), avec des couleurs d'avatar (sweat orange, pantalon bleu nuit)
  et le visage de base de Roblox. Pose : animation `HitWindowHeavy` du jeu, à son marqueur `Impact` (0,23 s).
- Outil : `TOOL_Masse`, tenu comme un Tool du jeu (Grip neutre). En jeu, la masse vise plutôt la zone 5, mais rien
  n'empêche de casser la Bijouterie avec.
- Vitre : les vrais éclats `Shard_*` de `WindowFractured`, plus de petits cubes de verre à la couleur de
  `Shatter.GlassColor`, que le jeu fait jaillir à la casse.
- Objet : `ITM_Z4_Couronne`, **Épique** depuis la vague 76 (le brief la disait Légendaire), en taille **Colossal**
  (× 3, `Config/Mutations`), avec le vrai halo du jeu (`RarityHalo.AddCarried`).
- Retouche : recadrage, contraste et saturation + 12 à 15 %, décor un peu flou et assombri, vignette, contour
  `#1B1B24` (9 px autour du perso, 6 px autour de la Couronne), halo violet renforcé autour de la Couronne, flash
  blanc à l'impact. Rien n'est ajouté qui n'existe pas en jeu.

## Contrôle

- 512 × 512, PNG, sans texte ; le sujet tient dans le cercle de 440 px. ✓
- **À 150 px**, on lit un perso orange avec une masse, une gerbe blanche et une grosse couronne dorée. On ne lit
  **pas** tout de suite « il casse une vitre » : la masse ressemble à une canne et la vitre se voit peu.
- **Dans la grille** ([controle_grille.png](controle_grille.png)), l'icône est **plus pâle et moins lisible que ses
  voisines**, qui sont des illustrations très saturées. En l'état, elle ne vise pas 8 à 10 % de clics.

## Pour une v2 (à décider avec Clément)

**Faite le 2026-11-21** par retouche ChatGPT (option 1), en bacon hair avec cagoule : [v2/note.md](v2/note.md).
Puis la **v3**, choisie par Clément : tenue bacon hair, mains, pose et masse revues ([v3/note.md](v3/note.md)).

1. **Retouche par IA à partir de cette capture** (ChatGPT dans Chrome après connexion de Clément, ou ForgeGUI, payant :
   demander avant) : mêmes éléments, mais vitre qui éclate nettement, masse lisible, visage expressif et couleurs
   d'illustration. C'est ce que font les icônes voisines. L'IA améliore la capture, elle n'invente pas une scène
   absente du jeu.
2. **Ou une 2e capture** : de côté, pour voir la masse de profil sur la vitre, perso plus grand dans le cadre, et un
   visage plus expressif s'il y en a un gratuit.
