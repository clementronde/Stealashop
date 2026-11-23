# « La course des 6 zones » : découpage

Teaser TikTok, vertical 1080 × 1920, 30 i/s, **18 s**, sans musique (Clément l'ajoute dans TikTok). Textes à l'écran en anglais.
D'après la fiche `references/2026-11-21_ref6_lancer-infini.md` (l'escalade et la récompense démesurée) et les points communs des références (ref4). La réalisation reste la nôtre : images soignées, couleurs saturées, texte au tiers haut.

L'idée : un joueur traverse tout le couloir en courant, de la zone 1 à la zone 6. À chaque porte de zone, la ville et la rareté la plus haute de la zone s'affichent, de plus en plus haut. Au bout, il ouvre un colis **Secret**.

## Ce que le jeu a vraiment (lu dans `src/shared/Config`, le 2026-11-21)

| Zone | Thème (`Zones.Theme`) | Ville (`Zones.City`, bandeau d'entrée) | Rareté la plus haute (`Rarities.ZoneOdds`) |
| --- | --- | --- | --- |
| 1 | Mini Mart | (aucune : le bandeau écrit MINI MART) | Common |
| 2 | Toys | LONDON | Uncommon |
| 3 | Electronics | TOKYO | Rare |
| 4 | Jewelry | LOS ANGELES | Epic |
| 5 | Gallery | PARIS | Legendary |
| 6 | Bank | NEW YORK | Mythic, puis **Secret** |

- **Chance d'un colis Secret** sur un rayon de zone 6 : **0,045 %, soit « 1 in 2,222 »** (`ZoneOdds[6].Secret`). C'est une valeur V0 (Cantin, 20/11), qui peut changer : à relire juste avant le montage, sans jamais l'arrondir à notre avantage.
- **Le Secret** a son arc-en-ciel animé (`Rainbow`) et son ralenti à l'ouverture (`SlowMotion`). **Divine** n'a encore aucun objet (chance 0) : on ne le montre pas.
- Rien de caché par `Features` dans ce qu'on montre (zones, vigiles de jour, colis, ouverture).

## Le plan par plan

| Temps | Ce qu'on voit | Cadrage et caméra | Texte à l'écran |
| --- | --- | --- | --- |
| 0 à 1,5 s | **Accroche** : le joueur part en sprint depuis la zone safe, la caméra plonge derrière lui | Drone (c) qui descend vers le dos du joueur (a) | « HOW FAR CAN YOU GO? » en gros, puis il s'efface |
| 1,5 à 3 s | Passage de la porte de la zone 1 | Derrière le joueur (a) | « ZONE 1 · MINI MART » et « COMMON », dans la couleur de la rareté |
| 3 à 5 s | Zone 2, LONDON | Derrière (a), puis 0,5 s de côté (b) devant les façades rouges | « ZONE 2 · LONDON » et « UNCOMMON » |
| 5 à 7 s | Zone 3, TOKYO | Derrière (a) | « ZONE 3 · TOKYO » et « RARE » |
| 7 à 9 s | Zone 4, LOS ANGELES : la grande arche rouge | Derrière (a), l'arche passe au-dessus de la caméra | « ZONE 4 · LOS ANGELES » et « EPIC » |
| 9 à 11 s | Zone 5, PARIS | Derrière (a), plus près et plus vite | « ZONE 5 · PARIS » et « LEGENDARY » |
| 11 à 13 s | Zone 6, NEW YORK : il arrive à la Banque et casse la vitrine | De côté (b), coupe sur l'impact | « ZONE 6 · NEW YORK » et « MYTHIC… » |
| 13 à 16,5 s | **Récompense** : il ouvre le colis, ralenti du jeu, arc-en-ciel | Plan serré sur le colis | « SECRET » en arc-en-ciel, puis « 1 in 2,222 » |
| 16,5 à 18 s | Image tenue, prête à boucler | Arrêt | « COMING SOON » |

Rythme : une porte toutes les 2 s, chaque palier un peu plus court et plus serré que le précédent, pour que l'escalade accélère comme le multiplicateur de la référence. Les étiquettes de rareté reprennent les couleurs de `Config/Rarities`.

## Cadrages candidats (captures en Edit, de jour, tournées en vertical)

| | Où | Rôle |
| --- | --- | --- |
| **a** `cadrages/cadrage_a.jpg` | Derrière et au-dessus du coureur, dans l'axe du couloir (14 studs de haut) | Le plan principal, qui suit le joueur : on voit les portes de zone arriver |
| **b** `cadrages/cadrage_b.jpg` | Au ras du sol, sur le côté, devant les façades | Inserts de 0,5 s pour relancer le rythme, et la casse de la vitrine |
| **c** `cadrages/cadrage_c.jpg` | Drone très haut au-dessus de l'entrée, tout le couloir en enfilade jusqu'à la skyline | L'accroche (les 6 zones d'un coup d'œil), et une fin possible |

## Tournage prévu, et ce qui reste à régler

- En Play, avec le même principe que « la nuit tombe » : caméra `Scriptable` tournée de 90° (images de 640 × 1568), UI cachée sur la copie du joueur, rien d'enregistré.
- **Course au ralenti ×4**, pour avoir de vraies images à 30 i/s : vitesse de marche du perso divisée par 4 côté serveur (la course standard ralentit avec elle), puis accélérée ×4 au montage. À vérifier au premier essai. Le perso court de x = 30 à x = 820 : environ 12 s à la vitesse maximale, soit 48 s de prise, donc 2 parties de 30 s.
- **Le vigile de jour** qui le poursuit courrait 4 fois trop vite au ralenti : on ne le filme pas pendant la course, sauf en temps réel pour un insert.
- **Choix de Clément (2026-11-21) : finir sur un Mythique.** Essai en Play le même jour :
  - **Un colis Mythique, on sait l'obtenir** : chaque tombée de la nuit (`NightSkipTo`) remplit à nouveau les 120 colis des rayons. Il est apparu au 3e remplissage, sur la Banque (zone 6), à l'emplacement `STORE_Z6_Banque/03` (attribut `BoxRarity = "Mythic"`). Sa chance est de 0,42 % par colis en zone 6, soit « 1 in 238 » (`ZoneOdds[6].Mythic`, valeur V0).
  - **L'ouvrir n'est pas possible en solo** : la vitrine de la zone 6 se répare au bout de 8 s (« Too slow! The glass repaired itself »), puis un témoin appelle la police, qui rattrape le joueur. Les dégâts du profil DEV de Clément ne suffisent pas seul.
  - **Le profil DEV est réellement sauvegardé en Play** (« les profils sont réellement sauvegardés », DataStore `PlayerData_DEV_20261114`). Une vraie ouverture ajouterait l'objet à l'inventaire DEV de Clément. Ce Play n'a rien fait perdre : la capture par la police n'a aucune autre perte.
  - **Une ouverture ne garantit pas un Mythique** : une caisse Mythique donne un objet Mythique dans environ 57 % des cas, sinon surtout un Légendaire (`ShelfOpen`).
  - **Fin proposée, sans ouverture** : plan serré qui avance sur le colis Mythique, posé sur le rayon de la Banque avec son contour et son étiquette, puis « MYTHIC » et « 1 in 238 ». Autres options : Clément fait l'ouverture lui-même à plusieurs, et je filme ; ou Ironix ajoute un réglage de test Studio (à demander dans la liaison).
- **Ancien point bloquant, le colis Secret** : 1 chance sur 2 222, impossible à obtenir par hasard pendant le tournage. Il faudrait un attribut de test Studio pour imposer un colis Secret sur le rayon d'un magasin de zone 6, à demander à Ironix dans la liaison. Sans cela, il reste deux options : finir sur un Mythique (il existe en zone 6), ou rester sur les deux premiers tiers de l'idée, sans l'ouverture.
- Les panneaux de zone du jeu (`UI_ZoneBanner`) s'affichent à chaque entrée de zone : on peut les laisser à l'image à la place de nos étiquettes, puisqu'ils sont dans le jeu.

## Tournage et montage (v1, 2026-11-21)

Fin choisie par Clément : **le colis Mythique sur son rayon**, sans l'ouvrir. Rendu : `course-6-zones_v1.mp4` (16,6 s, 15,9 Mo, 1080 × 1920, 30 i/s, sans son) et `course-6-zones_v1.jpg` (miniature : MYTHIC, 1 in 238 et le colis).

**Tournage**, en Play dans la place DEV, avec `tools/clement/video/course_6_zones.luau` :
- **Le colis Mythique** est apparu au 5e remplissage des rayons, sur la Banque, emplacement 05. Personne n'a cassé ni ouvert de vitrine : le profil DEV n'a pas changé.
- **La course au ralenti ×4** : vitesse de marche divisée par 4, côté client seulement (la course standard de Roblox ralentit avec elle). `video_capture` a enregistré à 8,8 i/s, soit environ 35 vraies images par seconde une fois accéléré. La course est en deux parties de moins de 30 s, raccordées à la porte de la zone 4, sur le changement d'angle.
- **Un angle de caméra par zone**, qui change d'un coup à chaque porte : drone qui plonge vers le dos du coureur, de dos, de côté (Londres), de face (Tokyo), de dos au ras du sol (Los Angeles), de côté (Paris), de dos (New York).
- **La fin**, en deux temps dans la même prise. Le colis est sur un îlot de rayonnage, côté allée : de la rue, le panneau central de l'îlot le cache. On voit donc d'abord la rue (l'enseigne BANK, le perso de dos devant la vitrine, hache à la main), puis on coupe à 1,6 s sur l'allée, où la caméra descend vers le colis.

**Montage** (`tools/clement/video/course_6_zones_montage.sh`) :

| Temps | Plan | Texte |
| --- | --- | --- |
| 0 à 1,1 s | Drone qui plonge vers le coureur | « HOW FAR / CAN YOU GO? » |
| 1,10 s | Zone 1, de dos | ZONE 1 - MINI MART · COMMON |
| 2,23 s | Zone 2, de côté | ZONE 2 - LONDON · UNCOMMON |
| 3,68 s | Zone 3, de face | ZONE 3 - TOKYO · RARE |
| 5,45 s | Zone 4, de dos au ras du sol (raccord des deux prises) | ZONE 4 - LOS ANGELES · EPIC |
| 7,53 s | Zone 5, de côté | ZONE 5 - PARIS · LEGENDARY |
| 9,95 s | Zone 6, de dos, puis la Banque | ZONE 6 - NEW YORK · MYTHIC |
| 12,51 s | Flash, l'allée, le colis Mythique | « MYTHIC », puis « 1 in 238 » |
| 14,6 à 16,6 s | Image tenue sur le colis | « C O M I N G   S O O N » sous le colis |

- La rareté de chaque zone est celle qui y apparaît (`ZoneOdds`), dans la couleur de `Rarities`, en plus gros d'une zone à l'autre. Petit zoom-punch à chaque porte.
- Le point médian n'existe pas dans Futura Bold : le séparateur est un tiret.
- Les prises brutes (R1, R2, F) sont dans le dossier temporaire de la session, hors du dépôt.
- **À relire avant de publier** : « 1 in 238 » et les raretés par zone sont des valeurs V0 de `Config/Rarities` (Cantin, 20/11).
