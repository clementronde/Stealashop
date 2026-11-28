# Enseignes sans « AI slop » (Chef DA, 28/11)

Clément : « les lettres sur le magasin font trop IA ». **Relevé en lecture seule** dans la place DEV le 28/11, sur les 6 zones, le hub et l'entrée :
- **569 textes**, tous des `TextLabel` dans des `SurfaceGui`, posés à plat sur des panneaux, presque tous en **Montserrat** ;
- **aucune lettre en image** (`Decal`, `ImageLabel`) ;
- **une seule série de lettres en pièces** : les 5 lettres de `Zone_4/…/Colline_HEIST`.

Ce qui fait « IA » :
- des slogans inventés (« THE FIRST MARSHMALLOW WAS MADE HERE 1887 », « IT'S HEIST O'CLOCK ») ;
- des sous-titres (« SWEETS & TREATS ») ;
- des faux noms de rue (« PICKPOCKET LANE SW1 ») ;
- des mots écrits lettre par lettre à la verticale (« T / O / K / Y / O » ×22) ;
- des écrans de faux jeux (« PLAYER 1 READY? », « LEVEL 8 ») ;
- la même police plate partout ;
- plus de 200 en-têtes de rayons.

## La règle

1. **Plus aucun faux mot, slogan, sous-titre, date ni promo** : « SINCE 1931 », « SALE », « LIMITED EDITION », « OPEN 24/7 », « HOT DOGS $1 ». Pas non plus de faux nom de rue ni de mot épelé à la verticale.
2. **L'enseigne d'un magasin PNJ** : un seul mot court au plus (1 à 7 lettres), sur la `SignPart`.
   - Le mot n'est plus un texte plat : il est fait de **lettres en blocs voxel à tenons**, dans une seule « police maison » (une grille de 5 × 7 cubes par lettre), d'une couleur, avec le contour sombre du jeu.
   - Il est en relief, ou en `Neon` à Tokyo et à New York.
   - **Exception** : « MINI MART », que le tutoriel et l'Index nomment.
3. **Partout ailleurs, des pictogrammes en voxel** de ce que vend le lieu (bonbon, ours, diamant, manette, horloge, tableau, vase, lingot…), à la place des mots : façades du décor, rayons, affiches, bannières, néons.
4. **Restent les mots qui font partie d'un objet réel connu**, petits et à leur place : TELEPHONE sur la cabine, TAXI sur le taxi, BUS STOP, SUBWAY, NEWS sur le kiosque, le nom du bus. Restent aussi les **chiffres et les symboles** : numéros de maison, guichets 1 et 2, ★, $, H de l'héliport, P du parking.
5. **Les textes de jeu restent** (ils informent le joueur) : le hub (YOUR SHOP, SHOP 1 à 6, BEST ITEM, FITTING ROOM, plaques $, classements, étiquettes des stands, SAFE ZONE), le mur de nuit et FORTUNE TOWER (l'événement). Ils passent tous dans **une seule police de jeu, FredokaOne**, celle des étiquettes du hub, au lieu de Montserrat.
6. **`SignPart` reste sur chaque magasin PNJ** : le code s'en sert seulement pour placer le panneau d'infos (`StoreInfoController`), pas pour son texte. On ne change que ce qu'elle affiche.

**Les lettres HEIST de Los Angeles** : on les **garde**, c'est le monument de la zone et un seul mot, mais on les **refait dans la police maison en blocs voxel**, avec leurs ampoules. Si Clément n'en veut plus, le plan B est un **diamant voxel géant** sur la colline, à la même place.

**Les fiches de zone sont corrigées en conséquence** (à reprendre par le chef Map) :
- zone 1 : le panneau de bienvenue ne porte plus de mots, juste un soleil ;
- Los Angeles : plus de panneaux « SUNSET AVE » ni « HEIST BLVD », et la flèche de motel sans le mot ;
- Paris : les enseignes « CAFÉ », « BOULANGERIE »… deviennent des pictos ; « MÉTRO » reste, comme mot d'objet ;
- Tokyo : les enseignes verticales deviennent des pictos en néon.

## Tableau par zone

| Zone | Objet (chemin court) | Texte actuel | On fait quoi |
| --- | --- | --- | --- |
| Z1 | `STORE_Z1_Superette/SignPart` | MINI MART | **garde**, en lettres voxel (exception du tutoriel) |
| Z1 | `STORE_Z1_Superette/BladeBoard` ×2, `STORE_Z1_Kiosque/BladeBoard` ×2 | M/I/N/I M/A/R/T, K/I/O/S/K à la verticale | **retire** |
| Z1 | `STORE_Z1_Kiosque/SignPart` | KIOSK | **garde**, en lettres voxel |
| Z1 | `Street_Zone1/Signs` (panneaux, plan) | WELCOME!, FIRST HEIST STREET, SEE YOU SOON! ×2, TOWN MAP, YOU ARE HERE, TO LONDON, MINI MART, KIOSK | **retire** ; le plan devient un dessin en blocs de couleur, le panneau d'accueil un soleil |
| Z1 | `Neighborhood_Zone1` `SignBand` ×5 | ICE CREAM, BAKERY, PHARMACY, CAFÉ, FLOWERS | **pictos** : cornet, croissant, croix verte, tasse, fleur |
| Z1 | `Neighborhood_Zone1/BillboardFace` | SMILE! / YOU'RE ON CAMERA | **picto** caméra |
| Z1 | `HouseNumber` ×3 | 7, 12, 3 | **garde** (chiffres) |
| Z2 | `STORE_Z2_Confiserie/SignPart` | SWEET SHOP | **remplace** par **SWEETS** en lettres voxel |
| Z2 | `STORE_Z2_Confiserie/PanelBoard`, `BluePlaque`, `HangingSign` ×2 | SWEETS & TREATS ; THE FIRST MARSHMALLOW WAS MADE HERE 1887 ; SWEETS | **retire** le panneau et la plaque ; les enseignes suspendues deviennent une **sucette** picto |
| Z2 | `STORE_Z2_MagasinDeJouets/SignPart` | TOY SHOP | **remplace** par **TOYS** |
| Z2 | `STORE_Z2_MagasinDeJouets/PanelBoard`, `BluePlaque`, `HangingSign` ×2 | TOYS & GAMES ; THE FIRST TEDDY BEAR… 1887 ; TOYS | **retire** le panneau et la plaque ; picto **ours** sur les enseignes suspendues |
| Z2 | `Street_Londres/StreetSign` ×2 | PICKPOCKET LANE SW1 | **retire** |
| Z2 | cabines (`Header_*` ×8), `StopFlag` ×2, `Destination` du bus | TELEPHONE, BUS STOP, LONDON | **garde** (mots d'objets réels), en FredokaOne |
| Z2 | `PostBox/LetterPlate`, `DepotSign`, `Advert_L`/`R` | LETTERS, BUS DEPOT, SEE LONDON ×2 | **retire** ; les deux affiches deviennent une silhouette de tour d'horloge |
| Z3 | `STORE_Z3_Electronique/SignPart` | ELECTRONICS | **remplace** par **TECH** en néon voxel |
| Z3 | `STORE_Z3_Electronique` `FacadeScreen`, `AdScreen`, `VSign_1`/`_2`, `Noren_1`/`_2`, `ShopBoard`, `WallScreen_*` | HIGH-TECH, TV 4K ULTRA HD, T/E/C/H, N/E/W, TECH, SHOP, O/P/E/N, 8K/4K/HD | **retire** les mots ; les écrans montrent une **mire de couleurs** ou un **paysage en pixels** ; picto **éclair** sur les norens |
| Z3 | `STORE_Z3_JeuxVideo/SignPart` | VIDEO GAMES | **remplace** par **GAMES** en néon voxel |
| Z3 | `STORE_Z3_JeuxVideo` `FacadeScreen`, `AdScreen`, `VideoWall`, `ArcadeScreen_*`, `WallScreen_*`, `VSign_*`, `Noren_*`, `ShopBoard` | PLAYER 1 READY?, NEW GAME!, PLAYER 1 VS PLAYER 2, LEVEL 8, VICTORY!, BONUS, G/A/M/E, P/L/A/Y, GAME, ZONE, OPEN | **retire** les mots ; les écrans montrent des **sprites en pixels** (vaisseaux, cœurs, pièces) ; picto **manette** sur les norens |
| Z3 | `Street_Tokyo` `Banner` ×22, `Plaque` ×2 | T/O/K/Y/O, S/A/K/U/R/A | **pictos** : fleur de cerisier, lanterne |
| Z3 | `Street_Tokyo` `RoofSign` ×9, `BladeSign` ×6, `BarSign` ×4, `VSign` ×4, `Noren` ×4, `Kanban` ×2 | ARCADE, HOTEL SAKURA, SAKURA, CAMERA, MANGA, HOTEL, SUSHI, GAME, ANIME, NOODLES, KARAOKE, BAR, RAMEN, SING, COMICS, PHARMACY | **pictos néon** : manette, appareil photo, livre, sushi, bol de ramen, micro, verre, croix. Le `FX_NeonFlicker` du KARAOKE reste, sur le picto micro |
| Z4 | `STORE_Z4_Bijouterie/SignPart` | JEWELRY | **garde**, en lettres voxel dorées |
| Z4 | `STORE_Z4_Bijouterie/Plaque` | FINE JEWELRY SINCE 1926 | **retire** ; picto **diamant** |
| Z4 | `STORE_Z4_Horlogerie/SignPart` | WATCHES & CLOCKS | **remplace** par **CLOCKS** |
| Z4 | `STORE_Z4_Horlogerie/Plaque` | MASTER WATCHMAKERS SINCE 1931 | **retire** |
| Z4 | `STORE_Z4_Horlogerie/WorldClockPlate_1` à `_5` | LONDON, TOKYO, LOS ANGELES, PARIS, NEW YORK | **garde** (les vraies villes du jeu, sous des horloges), en FredokaOne |
| Z4 | `Street_LosAngeles` `BladeMain`/`BladeCross` ×8 | SUNSET AVE, HEIST BLVD | **retire** |
| Z4 | `Street_LosAngeles` `SignBand` ×10 (boutiques) | FLORIST, COUTURE, JUICE BAR, DINER, LEATHER GOODS, PERFUME, CHOCOLATES, HAIR SALON, SHOES, COFFEE | **pictos** : fleur, robe, verre, burger, sac, flacon, chocolat, ciseaux, chaussure, tasse |
| Z4 | `Panel` (`Billboard_S`) | IT'S HEIST O'CLOCK | **retire** ; l'affiche devient une image : un sac « $ » et une horloge |
| Z4 | `SignBoard` ×4, `EnseigneHOTEL`, `District/StageSign`, `District/SignFrame` | SURF, SUNSET, MOTEL, BEACH, H/O/T/E/L, STUDIO B, GRAND HOTEL | **pictos** : planche, soleil, flèche de motel, palmier, étoiles ; **retire** STUDIO B et GRAND HOTEL |
| Z4 | `StarTile` ×9, `Chiffre7`, `HelipadMark` | ★, 7, H | **garde** (symboles) |
| Z4 | `Colline_HEIST/Lettre_1_H` à `Lettre_5_T` | HEIST (pièces) | **garde**, refaites en police voxel (voir plus haut) |
| Z5 | `STORE_Z5_GalerieDArt/SignPart` | ART GALLERY | **remplace** par **ART** |
| Z5 | `STORE_Z5_GalerieDArt` `BladeSign` ×2, `PanelBoard`, `StreetPlaque` | GALLERY ; PAINTING SCULPTURE DRAWING ; 5TH DISTRICT ARTS STREET | **retire** ; picto **cadre** sur les enseignes en drapeau |
| Z5 | `STORE_Z5_Antiquaire/SignPart` | ANTIQUES | **garde** (un mot), en lettres voxel |
| Z5 | `STORE_Z5_Antiquaire` `BladeSign` ×2, `PanelBoard`, `StreetPlaque` | ANTIQUES ; WE BUY WE SELL APPRAISALS ; 5TH DISTRICT TIME STREET | **retire** ; picto **vase** |
| Z5 | `Street_Paris/ShopSign` ×7 | CHOCOLATES, CHEESE SHOP, PASTRY SHOP, CAFÉ, BAKERY, FLORIST, BOOKSHOP | **pictos** : chocolat, fromage, gâteau, tasse, baguette, fleur, livre |
| Z5 | `Poster_1`/`_2` ×4, `WelcomePlaque_N`/`_S`, `Ambience_Paris/Sign` | GRAND BALL, THEATRE TONIGHT, OPERA, CIRCUS ; WELCOME TO PARIS ; HOT CHESTNUTS | **retire** les mots ; les affiches deviennent des images (masques, chapiteau), et un picto **marron** pour le marchand |
| Z6 | `STORE_Z6_Banque/SignPart` | BANK | **garde**, en lettres voxel |
| Z6 | `STORE_Z6_Banque/Frieze`, `VaultDoor_Plaque` | SAVINGS · LOANS · VAULTS ; VAULT | **retire** ; garde le `CoinFace` « $ » |
| Z6 | `STORE_Z6_SalleDesCoffres/SignPart` | VAULT | **garde**, en lettres voxel |
| Z6 | `STORE_Z6_SalleDesCoffres/VaultDoor_Plaque` | VAULT #6 | **retire** |
| Z6 | `Guichet_Sign_1`/`_2` (les deux magasins) | TELLER 1, TELLER 2 | **remplace** par **1** et **2** |
| Z6 | `Street_NewYork` `StreetSignA`/`B` ×8 | WALL ST, BROADWAY | **retire** |
| Z6 | `Board_1`/`_2`/`_3` ×6, `Blade` ×4, `ShopSign` ×5, `Witnesses/Handle` | NEW YORK, OPEN 24/7, BIG APPLE, SALE, HOT DOGS $1, LIVE SHOW, T/H/E/A/T/E/R, H/O/T/E/L, FLOWERS, LAUNDROMAT, DELI, PIZZA, COFFEE, NEW YORK | **pictos** : pomme, hot-dog, masques, étoiles, fleur, machine à laver, sandwich, pizza, tasse ; **retire** le reste |
| Z6 | `TaxiSign` ×6, `Sign` ×2 (métro), `SignBand` (kiosque), `ParkingSign` | TAXI, SUBWAY, NEWS, P | **garde** (objets réels, symbole) |
| Z6 | `ParkingBand` | TAXI · PARKING | **remplace** par **P** |
| Z6 | `EndSign` | FORTUNE TOWER | **garde** (nom de l'événement), en lettres voxel |
| Tous | intérieurs : `Shelf_*_Header` (≈ 200), `Fridge_Header` ×12, `PromoSign_A`/`_B` ×24, `ReserveSign` ×12 | SNACKS, CANDY…, SALE, EXCLUSIVE, LIMITED EDITION, SECURITY, SAVINGS, RARE, EXPO, NEW, STOCKROOM | **retire** les mots ; chaque en-tête garde sa couleur, avec un **picto** du rayon ; les promos sont retirées ; la réserve a un picto carton |
| Hub | `Shops` : `NameSign`, `NumberBadge`, `Sign` (BEST ITEM, FITTING ROOM), `Plate` ($), `Zones` (classements), `Stalls` (étiquettes), `Ground/SafeZoneText` | textes de jeu | **garde**, tout en FredokaOne. Seul SAFE ZONE garde sa police, LuckiestGuy, déjà validée au sol |
| Hub | `Shops/EntryMat` ×6 | WELCOME | **retire** (paillasson sans mot) |
| Entrée | `NightWall/SignPanel_*` | CLOSED AT NIGHT, OPENS AT DAWN, NIGHT GUARDS ARE OUT!, BACK TO THE SAFE ZONE | **garde** (information de jeu), en FredokaOne |

**À signaler au chef UI** : chacune des 4 étiquettes des stands du hub (SELL, AURAS, ROBUX SHOP, WEAPONS) porte une seconde ligne, « +15 % MONEY PER FRIEND ». C'est le sous-titre de la zone « invite un ami », copié par erreur.

**Pour le chef Map** :
- la police maison en blocs (26 lettres de 5 × 7 cubes) se fait **une fois**, puis sert à toutes les enseignes ;
- les pictos voxel se font en Studio, en pièces, ou par le chef 3D pour les plus fins.
On applique zone par zone, avec une sauvegarde, dans l'ordre des fiches.
