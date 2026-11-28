# Pictos voxel des enseignes (Chef DA, 28/11)

Pour le chef 3D. Ils remplacent les mots retirés par la règle des enseignes (`da-enseignes-sans-slop.md`). Tailles relevées dans la place DEV le 28/11, en lecture seule.

**Règles communes**
- En voxel à tenons, comme nos objets : de petits cubes, 4 couleurs franches au plus, avec le **contour sombre #040435** du jeu (une couche de cubes en retrait derrière la silhouette).
- Lisible de face, à 30 studs : une silhouette simple, sans détail fin, sans texte.
- **Un seul modèle par motif**, fait à la taille M (3 × 3 studs, cubes de 0,25), puis réduit ou agrandi avec `ScaleTo` : S = 1,6 stud (bandes d'enseigne de 1,8 à 2,4 de haut), L = de 5 à 8 studs (grands panneaux, affiches).
- Posé à plat contre son panneau, débordant un peu du bas et du haut si besoin. Aucun support.
- **Néon** (Tokyo, New York, le motel de Los Angeles) : la même pièce, avec les cubes de couleur en `Neon` et le contour en SmoothPlastic.
- Noms : `ENV_Picto_<Motif>`, rangés dans `ReplicatedStorage/Assets/Decor/Pictos`. Le chef Map les pose.

**Ordre** : d'abord les 12 qui servent le plus (★ dans le tableau), puis les autres zone par zone, dans l'ordre des fiches (LA, Londres, Paris, New York, zone 1, puis Tokyo déjà fait).

| Picto | Ce qu'il montre | 3 couleurs (+ contour #040435) | Où il va (tailles) |
| --- | --- | --- | --- |
| ★ `Tasse` | tasse fumante, deux volutes | blanc #f7f3e8, brun café #6b4226, vapeur gris clair #d6dde8 | Z1 `SignBand` CAFÉ, Z4 `SignBand` COFFEE, Z5 `ShopSign` CAFÉ, Z6 `ShopSign` COFFEE (S) |
| ★ `Fleur` | fleur à 5 pétales et 2 feuilles | rose #ff78aa, cœur jaune #ffd23f, vert #348c40 | Z1 FLOWERS, Z4 FLORIST, Z5 FLORIST, Z6 FLOWERS (S) |
| ★ `Chocolat` | tablette entamée, papier doré | brun #5c3a21, or #d4a72c, rouge #b23a48 | Z4 CHOCOLATES, Z5 CHOCOLATES (S), rayons chocolat de la Confiserie |
| ★ `Livre` | livre ouvert | rouge #b23a48, pages crème #f6e7c8, tranche or #d4a72c | Z5 BOOKSHOP (S), Tokyo MANGA, COMICS (`RoofSign` L, `Noren`, `Kanban` M) |
| ★ `CroixVerte` | croix de pharmacie | vert #34c246, blanc #f7f3e8, vert foncé #1f7a2e | Z1 PHARMACY (S), Tokyo PHARMACY (`Noren`, `Kanban` M) |
| ★ `EtoilesHotel` | 3 étoiles empilées | or #ffcc48, blanc #fff7e6, orange #ff8c42 | Tokyo HOTEL (`RoofSign` L, `BladeSign` M, ×2), LA `EnseigneHOTEL` (L, néon), NY `Blade` HOTEL (M, néon) |
| ★ `Masques` | masques de théâtre, joie et tristesse | or #d4a72c, rouge #c81e23, blanc #f7f3e8 | Z5 `Poster_1` THEATRE, OPERA (M, vertical), NY `Blade` THEATER (M, néon), NY `Board_2` LIVE SHOW (L) |
| ★ `Verre` | verre avec paille et tranche | cyan #3bc9db, orange #ff8c42, blanc #f7f3e8 | Tokyo `BarSign` BAR ×4 (M, néon), LA JUICE BAR (S) |
| ★ `Manette` | manette de jeu à 2 boutons | violet #6b2bd9, cyan #18e0ff, rose #ff3ea5 | Jeux vidéo : `Noren_1`/`_2` (M), `VSign_1`/`_2` (M, néon) ; Tokyo GAME et ARCADE (`RoofSign` L, néon) |
| ★ `Eclair` | éclair | jaune #ffd23f, cyan #18e0ff, blanc #ffffff | Électronique : `Noren_1`/`_2` (M), `VSign_1`/`_2` (M, néon) |
| ★ `Sucette` | grosse sucette en spirale | rose #ff5d8f, blanc #ffffff, bâton beige #e8dcc4 | Confiserie `HangingSign` ×2 (M) ; aussi Z2 en vitrine |
| ★ `Ours` | tête d'ours en peluche | brun #a0652e, beige #e8c49a, nœud rouge #e8413c | Magasin de jouets `HangingSign` ×2 (M) |
| `Cornet` | cornet de glace à 2 boules | rose #ff9ec4, menthe #bee8d2, biscuit #d9a066 | Z1 ICE CREAM (S) ; frigo ICE CREAM de la Confiserie |
| `Croissant` | croissant doré | doré #e0a030, brun #a0652e, crème #f6e7c8 | Z1 BAKERY, Z5 BAKERY (S) |
| `Baguette` | deux baguettes croisées | doré #d9a066, brun #8a5a2b, crème #f6e7c8 | Z5 PASTRY SHOP, avec un petit gâteau : on peut le remplacer par `Gateau` |
| `Gateau` | part de gâteau à la fraise | crème #f6e7c8, rose #ff78aa, rouge #e8413c | Z5 PASTRY SHOP (S) ; rayons CAKES |
| `Fromage` | part de fromage à trous | jaune #ffd23f, orange #e0a030, blanc #fff7e6 | Z5 CHEESE SHOP (S) |
| `CameraSurveillance` | caméra de surveillance sur son bras, voyant rouge | gris #a7b0bc, noir #1e2026, rouge #e8413c | Z1 `BillboardFace` SMILE! (L, 10,6 × 4,1) |
| `AppareilPhoto` | appareil photo, gros objectif | noir #1e2026, gris #a7b0bc, cyan #18e0ff | Tokyo CAMERA (`RoofSign` L, néon) |
| `Soleil` | soleil rond à rayons | jaune #ffd23f, orange #ff8c42, blanc #fff7e6 | Z1 panneau d'accueil (L) et cuve du château d'eau (L, peint en cubes) ; LA `SignBoard` SUNSET (M) |
| `FleurCerisier` | fleur de cerisier à 5 pétales | rose #ff8fc8, blanc #ffe0f0, cœur rouge #e63946 | Tokyo `Banner` ×22 (1,6 stud, 2 par bannière, néon faible) et `Plaque` ×2 (M) |
| `Lanterne` | lanterne de papier rouge | rouge #e63946, noir #22203a, jaune #ffd23f | Tokyo : une bannière sur deux, en alternance avec la fleur (1,6 stud) |
| `Sushi` | 2 sushis (saumon et maki) | orange #ff8c42, blanc #f7f3e8, vert algue #1f4d3a | Tokyo SUSHI (`RoofSign` L, néon) |
| `Ramen` | bol de ramen fumant, baguettes | rouge #e63946, crème #f6e7c8, vapeur #d6dde8 | Tokyo RAMEN, NOODLES (`VSign`, `Noren`, `BladeSign` M, néon) |
| `Micro` | micro de karaoké, notes de musique | argent #c4ccd8, rose #ff3ea5, cyan #18e0ff | Tokyo KARAOKE, SING (`BladeSign`, `VSign`, `Noren` M, néon). Le `FX_NeonFlicker` reste sur l'enseigne |
| `ChatPorteBonheur` | chat porte-bonheur, patte levée (petit) | blanc #f7f3e8, rouge #e63946, or #ffd23f | Tokyo ANIME (`RoofSign` L) ; c'est le même motif que le gros chat de la fiche Tokyo, en petit |
| `Robe` | robe sur cintre | rose #ff5d8f, blanc #f7f3e8, or #d4a72c | LA COUTURE (S) |
| `Burger` | burger | brun #a0652e, vert #5fbf3f, jaune #ffd23f | LA DINER (S) |
| `Sac` | sac à main | brun cuir #8a5a2b, or #d4a72c, crème #f6e7c8 | LA LEATHER GOODS (S) |
| `Flacon` | flacon de parfum à pompe | rose #ff78aa, verre #bee8f4, or #d4a72c | LA PERFUME (S) |
| `Ciseaux` | ciseaux ouverts et peigne | argent #c4ccd8, rose #ff5d8f, noir #1e2026 | LA HAIR SALON (S) |
| `Chaussure` | basket | blanc #f7f3e8, rouge #e8413c, bleu #2e86de | LA SHOES (S) |
| `Surf` | planche de surf | turquoise #3bc9db, orange #ff8c42, blanc #f7f3e8 | LA `SignBoard` SURF (M) |
| `Palmier` | palmier | vert #2a9d8f, tronc #8a5a2b, sable #f4d58d | LA `SignBoard` BEACH (M) |
| `SacDollar` | sac « $ » noué, à côté d'une horloge | vert billet #4caf50, beige #e8dcc4, or #d4a72c | LA `Panel` IT'S HEIST O'CLOCK (L, 30 × 12 : le grand modèle du lot) |
| `Diamant` | diamant taillé, reflets | cyan #7fe7ff, blanc #ffffff, bleu #2e86de | Bijouterie `Plaque` (M) ; frigo DIAMONDS |
| `Cadre` | tableau dans un cadre doré, paysage simple | or #d4a72c, bleu ciel #59c9f2, vert #5fbf3f | Galerie `BladeSign` ×2 (M) |
| `Vase` | vase ancien à anses | bleu #2e3a50, blanc #f7f3e8, or #d4a72c | Antiquaire `BladeSign` ×2 (M) |
| `Chapiteau` | chapiteau de cirque rayé | rouge #c81e23, blanc #f7f3e8, or #ffcc48 | Z5 `Poster_2` CIRCUS, GRAND BALL (M, vertical) |
| `Marron` | cornet de marrons chauds | brun #6b4226, papier #e8dcc4, braise #ff8c42 | Z5 `Ambience_Paris/Sign` HOT CHESTNUTS (M) |
| `TourHorloge` | silhouette de tour d'horloge | miel #c9a86a, ardoise #5b6470, cadran #f5f5f0 | Z2 `Advert_L`/`_R` (bandes de 1,3 de haut : S, répété le long de la bande) |
| `Pomme` | grosse pomme rouge et sa feuille | rouge #e8413c, vert #348c40, tige brune #6b4226 | NY `Board_3` BIG APPLE (L) |
| `HotDog` | hot-dog moutarde | brun #c8773a, saucisse #c8553d, moutarde #ffd23f | NY `Board_3` HOT DOGS (L) |
| `MachineALaver` | machine à laver, hublot | blanc #f7f3e8, bleu #59c9f2, gris #a7b0bc | NY LAUNDROMAT (S) |
| `Sandwich` | sandwich garni | pain #d9a066, vert #5fbf3f, rose jambon #ff9ec4 | NY DELI (S) |
| `Pizza` | part de pizza | jaune #ffd23f, rouge #e8413c, croûte #c8773a | NY PIZZA (S) |
| `Carton` | carton fermé, scotch | kraft #c9a46a, scotch #8a6a3a, étiquette #f7f3e8 | les 12 `ReserveSign` (STOCKROOM, 6 × 1,5 : S) |

**Intérieurs des magasins** (≈ 200 en-têtes `Shelf_*_Header`, 4,5 × 1,8, et 12 `Fridge_Header`, 36 × 1,8) : on ne fait pas un picto par rayon. Chaque en-tête garde sa couleur, et on y répète le **picto de son magasin** (S) : `Sucette` à la Confiserie, `Ours` aux Jouets, `Eclair` à l'Électronique, `Manette` aux Jeux vidéo, `Diamant` à la Bijouterie, une **horloge** à l'Horlogerie (`Horloge`, à ajouter : cadran blanc, cerclage or, aiguilles noires), `Cadre` à la Galerie, `Vase` à l'Antiquaire, un **lingot** à la Banque et à la Salle des coffres (`Lingot`, à ajouter : or #d4a72c, reflet #ffe08a, ombre #a07a1e), et pour la Supérette et le Kiosque un **caddie** (`Caddie`, à ajouter : rouge #e8413c, gris #a7b0bc, roues #1e2026). Les `PromoSign_A`/`_B` sont retirés.

**Pas à faire en voxel** (le chef Map s'en charge, en pixels dans des `Frame` de `SurfaceGui`, sans image générée) : les écrans de l'Électronique (une mire de couleurs) et des Jeux vidéo (des sprites, cœurs et pièces).

En tout : 47 pictos plus 3 à ajouter (`Horloge`, `Lingot`, `Caddie`), dont 12 prioritaires.
