# La police maison en lettres voxel (Chef DA, 28/11)

Pour le chef Map, qui écrit `tools/clement/zones/lettres_voxel.luau`. Elle sert aux enseignes des 12 magasins PNJ, à HEIST et à FORTUNE TOWER (règle des enseignes, `da-enseignes-sans-slop.md`).

## Références (on prend la technique, pas les lettres)

- **L'enseigne « SELL » du teaser TikTok** : `StealAShop-Art/References/Video/Trailers/teaser_tiktok_soon.mp4`, vers 0:20. Des lettres blanches en blocs, épaisses, légèrement biseautées, avec une ombre sombre, sur un panneau rouge encadré de briques au-dessus d'un store rayé.
  C'est exactement l'effet voulu : **une vraie enseigne construite, pas un texte imprimé**.
- **Le stand « VENDRE »** : `References/Map/Base_joueur/05_Stands_Machine_fusion_Vendre.webp`, lettres pleines très lisibles sur un panneau.
- **Notre « SAFE ZONE »** au sol (LuckiestGuy) : il est validé, il reste en texte.

## La grille : des lettres de 7 pixels de haut, en traits de 2 pixels

`#` = un cube plein, `.` = vide. Largeurs : 6 pixels pour la plupart des lettres, 5 pour E, F et L, 4 pour I et 1, 7 pour M et W.
- **1 pixel** d'espace entre deux lettres, **3** entre deux mots.
- **1 pixel de contour** tout autour (voir plus bas).

```
A        B        C        D        E       F       G        H
.####.   #####.   .####.   #####.   #####   #####   .####.   ##..##
##..##   ##..##   ##..##   ##..##   ##...   ##...   ##..##   ##..##
##..##   ##..##   ##....   ##..##   ##...   ##...   ##....   ##..##
######   #####.   ##....   ##..##   ####.   ####.   ##.###   ######
##..##   ##..##   ##....   ##..##   ##...   ##...   ##..##   ##..##
##..##   ##..##   ##..##   ##..##   ##...   ##...   ##..##   ##..##
##..##   #####.   .####.   #####.   #####   ##...   .#####   ##..##

I      J        K        L       M         N        O        P
####   ....##   ##..##   ##...   ##...##   ##..##   .####.   #####.
.##.   ....##   ##.##.   ##...   ###.###   ###.##   ##..##   ##..##
.##.   ....##   ####..   ##...   #######   ######   ##..##   ##..##
.##.   ....##   ###...   ##...   ##.#.##   ##.###   ##..##   #####.
.##.   ##..##   ####..   ##...   ##...##   ##..##   ##..##   ##....
.##.   ##..##   ##.##.   ##...   ##...##   ##..##   ##..##   ##....
####   .####.   ##..##   #####   ##...##   ##..##   .####.   ##....

Q        R        S        T        U        V        W         X
.####.   #####.   .####.   ######   ##..##   ##..##   ##...##   ##..##
##..##   ##..##   ##..##   ..##..   ##..##   ##..##   ##...##   ##..##
##..##   ##..##   ##....   ..##..   ##..##   ##..##   ##...##   .####.
##..##   #####.   .####.   ..##..   ##..##   ##..##   ##.#.##   ..##..
##.###   ####..   ....##   ..##..   ##..##   ##..##   #######   .####.
.####.   ##.##.   ##..##   ..##..   ##..##   .####.   ###.###   ##..##
....##   ##..##   .####.   ..##..   .####.   ..##..   ##...##   ##..##

Y        Z
##..##   ######
##..##   ....##
##..##   ...##.
.####.   ..##..
..##..   .##...
..##..   ##....
..##..   ######

0        1      2        3        4        5        6        7        8        9
.####.   .##.   .####.   .####.   ...###   ######   .####.   ######   .####.   .####.
##..##   ###.   ##..##   ##..##   ..####   ##....   ##....   ....##   ##..##   ##..##
##.###   .##.   ....##   ....##   .##.##   #####.   ##....   ...##.   ##..##   ##..##
######   .##.   ..###.   ..###.   ##..##   ....##   #####.   ..##..   .####.   .#####
###.##   .##.   .##...   ....##   ######   ....##   ##..##   ..##..   ##..##   ....##
##..##   .##.   ##....   ##..##   ....##   ##..##   ##..##   ..##..   ##..##   ....##
.####.   ####   ######   .####.   ....##   .####.   .####.   ..##..   .####.   .####.
```

Pour les 14 mots, il faut les lettres A B C E F G H I J K L M N O Q R S T U V W Y. Les autres (D, P, X, Z) et les chiffres sont là pour la suite (guichets 1 et 2, numéros).

## Construction d'un mot

- **Taille d'un pixel `p`** : choisie par enseigne (tableau plus bas).
  - La lettre fait 7 p de haut, et le mot avec son contour 9 p.
  - Sur les `SignPart` basses (2,7 à 3,2 studs), on prend p = 0,4 : les lettres dépassent un peu du panneau, comme de vraies lettres posées dessus. C'est voulu, elles se lisent mieux de la rue.
- **Trois couches**, de l'arrière vers l'avant :
  1. **Le contour** : la silhouette du mot **élargie d'un pixel dans les 8 directions**, en cubes p × p de **0,4 p** d'épaisseur, couleur **#040435** (le contour du jeu), SmoothPlastic, posée à 0,05 stud devant la face avant de la `SignPart`.
  2. **La face** : les pixels du mot, en cubes p × p de **0,6 p** d'épaisseur, posés devant le contour. Le mot sort donc de 1 p en tout.
  3. **Le biseau**, en trois tons de la couleur de face, sans pièce en plus :
     - le pixel dont la case au-dessus est vide prend le **ton clair** (la face mélangée à 30 % de blanc) ;
     - le pixel dont la case au-dessous est vide prend le **ton foncé** (la face × 0,7) ;
     - les autres pixels prennent le ton de face.
     C'est la même logique que nos boutons, plus foncés en bas.
- **Fusionner les pixels** : sur chaque ligne, les pixels voisins du même ton et de la même couche ne font qu'**une seule pièce** (une bande). On divise ainsi le nombre de pièces par 3 environ, soit une cinquantaine pour SWEETS au lieu de 150.
- **Matière** :
  - en relief : SmoothPlastic, sans tenons (trop petit pour en porter) ;
  - en néon : la face en `Neon` (le biseau aussi, sur ses trois tons), le contour reste en SmoothPlastic sombre, et **une seule `PointLight` par mot**, placée au centre, à 1 stud devant (portée = la moitié de la largeur du mot, 16 au plus ; Brightness 1 ; couleur de face).
- **Placement** : centré sur la face de la `SignPart` qui portait la `SurfaceGui` (Front, Left…). On retire seulement le `TextLabel`, la `SignPart` reste (le code s'en sert pour placer le panneau d'infos). Toutes les pièces en `CanCollide` false, `CanQuery` false et `CastShadow` false, dans un modèle `SignLetters` sous la `SignPart`.
- **Garde-fou** : si le mot dépasse 80 % de la largeur de la `SignPart`, on réduit `p`.

## Les 14 enseignes

Largeur du mot en pixels, contour compris, puis en studs avec le `p` choisi. Couleurs : face, puis clair et foncé calculés.

| Enseigne | `SignPart` (l × h) | Mot | Largeur (px) | p | Mot (l × h, studs) | Face | Style |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `STORE_Z1_Superette` | 38,8 × 5,1 | MINI MART | 57 | 0,5 | 28,5 × 4,5 | blanc #f7f3e8 | relief |
| `STORE_Z1_Kiosque` | 38,8 × 5,1 | KIOSK | 34 | 0,5 | 17 × 4,5 | blanc #f7f3e8 | relief |
| `STORE_Z2_Confiserie` | 62,1 × 2,7 | SWEETS | 42 | 0,4 | 16,8 × 3,6 | rose #ff5d8f | relief |
| `STORE_Z2_MagasinDeJouets` | 62,1 × 2,7 | TOYS | 29 | 0,4 | 11,6 × 3,6 | jaune #ffd23f | relief |
| `STORE_Z3_Electronique` | 50,5 × 3,2 | TECH | 28 | 0,4 | 11,2 × 3,6 | cyan #18e0ff | néon |
| `STORE_Z3_JeuxVideo` | 50,5 × 3,2 | GAMES | 36 | 0,4 | 14,4 × 3,6 | rose #ff3ea5 | néon |
| `STORE_Z4_Bijouterie` | 62,1 × 2,7 | JEWELRY | 48 | 0,4 | 19,2 × 3,6 | or #d4a72c | relief |
| `STORE_Z4_Horlogerie` | 62,1 × 2,7 | CLOCKS | 42 | 0,4 | 16,8 × 3,6 | blanc #f7f3e8 | relief |
| `STORE_Z5_GalerieDArt` | 62,1 × 2,8 | ART | 22 | 0,5 | 11 × 4,5 | pierre #efe3c8 | relief |
| `STORE_Z5_Antiquaire` | 62,1 × 2,8 | ANTIQUES | 54 | 0,4 | 21,6 × 3,6 | or #d4a72c | relief |
| `STORE_Z6_Banque` | 24,8 × 4,2 | BANK | 29 | 0,45 | 13 × 4,1 | or #ffcc48 | relief |
| `STORE_Z6_SalleDesCoffres` | 42,7 × 3,0 | VAULT | 35 | 0,4 | 14 × 3,6 | acier #c4ccd8 | relief |
| `Street_NewYork/EndSign` (face Left, 30 de long) | 30 × 3,0 | FORTUNE TOWER | 85 | 0,28 | 23,8 × 2,5 | or #ffd68c | néon |
| `Zone_4/…/Colline_HEIST` (5 lettres de 11 × 24 aujourd'hui) | — | HEIST | 33 | 2,0 | 66 × 18 | blanc #f7f3e8 | relief, sur pieds |

- **HEIST** : les 5 lettres actuelles (`Lettre_1_H` à `Lettre_5_T`) sont remplacées par le même mot construit dans la police, en cubes de 2 studs (une lettre fait 14 studs de haut, le contour compris 18).
  - Chaque lettre reste un modèle à part, sur ses pieds, légèrement de biais.
  - On garde la rangée d'ampoules `Neon` #ffcc48 sous chaque lettre.
  - La colline doit faire environ 75 studs de large pour les tenir (la fiche de Los Angeles disait 60).
- **Ce qui ne change pas** : les textes de jeu du hub, le mur de nuit et SAFE ZONE (règle 5). Ils restent des textes, en FredokaOne.

## À montrer à Clément avant de poser les 14

Une seule enseigne, en vraie 3D : **SWEETS** sur la Confiserie. On la compare avec l'ancienne « SWEET SHOP », dans deux captures prises du même point de la rue.
