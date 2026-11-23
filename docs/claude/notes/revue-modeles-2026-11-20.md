# Revue des modèles contre la DA des colis (2026-11-20)

Agent `revue-modeles`, place DEV, lecture seule (MCP Roblox Studio : arbre, Luau en lecture, captures). Référence : [DA-reference-colis.md](DA-reference-colis.md). Budgets, nommage et contrat : Partie 1, sections 10.2 à 10.4. Rien n'a été modifié, déplacé ni renommé dans Studio.

> **Mise à jour du 2026-11-20** : pour les objets exposés (`ITM_*`), les verdicts et les lots ci-dessous sont remplacés par ceux de [DA-objets-studs-blocs.md](DA-objets-studs-blocs.md) (style en studs et en blocs, les 83 objets à refaire). Le reste de la revue (colis, outils, magasins, décor) ne change pas.

## Méthode et limites

- **Périmètre** : les modèles rangés dans `ReplicatedStorage/Assets` (Items, Boxes, Tools, Unbox, Windows, Plots, Events), `ServerStorage/Assets/Env`, les magasins `Workspace/Map/Zone_1..6/STORE_*` et le hub `Workspace/Map/Hub`. **Hors revue** : `ServerStorage/MapBackups`, `ServerStorage/_GREYBOX_REMPLACE`, les prototypes `_PROTO_*`, `_BENCH_*` et `_APERCU_*`, les copies de la vitrine `_SHOWROOM_CLEMENT`, l'UI.
- **Mesures** pour chaque modèle : taille, nombre de pièces visibles, matériaux, nombre de couleurs (hex), Highlight, SelectionBox, Decal, SurfaceAppearance, scripts. Triangles mesurés pour les colis (180 à 300, tous dans le budget de 300). Le comptage des objets et des outils a dépassé le délai du MCP ; ils comptent 2 à 10 MeshParts chacun, et 10.6 donne 276 à 288 triangles pour les objets test. Ils sont donc **très probablement** sous 2 000, mais ce n'est pas mesuré : à vérifier dans Blender.
- **Captures** : 14, dans [img/revue-2026-11-20/](img/revue-2026-11-20/), prises dans la vitrine `_SHOWROOM_CLEMENT` et dans la rue. La HUD apparaît dessus (l'UI est visible en Edit). Pas de capture des magasins Z3 et Z4, ni des immeubles Z6 : leur verdict vient des mesures et porte la mention « à confirmer ».
- **Aucun modèle ne contient de script.** Aucun modèle `ACC_*` n'existe dans la place (accessoires de vigile pas encore livrés).

### Verdicts

- **Conforme** : suit la DA (forme pleine, couleurs franches, matière et rareté lisibles). Le contour noir manque partout sauf sur les colis et le camion : c'est traité à part (« Retouche commune » plus bas), pas dans le verdict.
- **À retoucher** : la forme est bonne, on corrige dans Studio ou en quelques minutes dans Blender (couleur, matériau, néon, une pièce à épaissir).
- **À refaire** : la silhouette ne se lit pas (pièces fines, transparentes, plates) : nouveau modèle.
- **Priorité** : P1 = objets exposés et ce qu'on tient en main ; P2 = magasins PNJ et rue du couloir ; P3 = hub et boutiques des joueurs ; P4 = décor de fond.

### Retouche commune à tous les objets exposés : le contour noir

Les colis ont un contour noir (Highlight `OutlineHighlight` et arêtes en SelectionBox de 0,025 stud) ; **aucun des 83 objets ITM_ n'en a**. C'est l'écart qui se voit le plus quand un objet sort de son colis. Comme un Highlight ne peut pas servir sur 120 objets exposés (31 au plus à l'écran, 20 déjà réservés aux colis), la piste proposée est un contour dans le maillage (coque inversée noire de 0,03 stud). À décider à deux avec Ironix avant de refaire les objets, car ça s'applique à tout le catalogue.

## Résultat

| Catégorie | Modèles | Conforme | À retoucher | À refaire |
| --- | --- | --- | --- | --- |
| Colis `BOX_` (référence) | 12 | 12 | 0 | 0 |
| Objets `ITM_` | 83 | 44 | 31 | 8 |
| Outils `TOOL_` (casse + ouverture) | 12 | 6 | 6 | 0 |
| Magasins `STORE_` | 12 | 5 | 7 | 0 |
| Parcelles et tapis `PLOT_` | 13 | 12 | 1 | 0 |
| Vitres `WIN_` | 4 | 4 | 0 | 0 |
| Accessoires `ACC_` | 0 | — | — | — |
| Décor `ENV_` (bibliothèque, hub, événements, objets-farces) | 191 | 134 | 37 | 20 |
| **Total** | **327** | **217** | **82** | **28** |

## Tableaux par catégorie

### Colis `BOX_` — `ReplicatedStorage/Assets/Boxes`

| Nom | Verdict | Raison | Priorité |
| --- | --- | --- | --- |
| BOX_Common, BOX_Uncommon, BOX_Rare, BOX_Epic, BOX_Legendary, BOX_Mythic, BOX_Secret, BOX_Divine | Conforme | Référence (180 à 300 triangles, contour, `Lid`, `Tint`) | — |
| BOX_Standard, BOX_Premium, BOX_Luxe | Conforme | Même construction, carton et ruban à la couleur du palier | — |
| BOX_Shop_ExclusiveCrate (`Assets/UI`) | Non jugé | Modèle d'aperçu de l'UI, hors périmètre | — |

### Objets exposés `ITM_` — `ReplicatedStorage/Assets/Items`

Captures : [vue d'ensemble](img/revue-2026-11-20/02_objets_vue_ensemble.jpg), [Z1 gauche](img/revue-2026-11-20/03_objets_z1_gauche.jpg), [Z1 droite](img/revue-2026-11-20/04_objets_z1_droite.jpg), [Z2](img/revue-2026-11-20/05_objets_z2.jpg), [Z3](img/revue-2026-11-20/06_objets_z3.jpg), [Z4](img/revue-2026-11-20/07_objets_z4.jpg), [Z5 et Z6](img/revue-2026-11-20/08_objets_z5_z6.jpg). Rareté : catalogue 10.5. « Or hors palette » = or `#E8B830` ou `#F2C230` en SmoothPlastic, au lieu de l'or des colis `#FFC21A` (en Foil à partir de Rare).

| Nom | Rareté | Verdict | Raison | Priorité |
| --- | --- | --- | --- | --- |
| ITM_Z1_CanetteDeSoda | Commun | Conforme | Cylindre plein, 3 couleurs, mat | P1 |
| ITM_Z1_BoissonEnergisante | Commun | Conforme | 3 couleurs, silhouette nette | P1 |
| ITM_Z1_BriqueDeLait | Commun | Conforme | Bloc, 3 couleurs | P1 |
| ITM_Z1_PaquetDeChips | Commun | Conforme | Forme pleine, couleurs chaudes | P1 |
| ITM_Z1_Donut | Commun | Conforme | Forme pleine, 5 couleurs | P1 |
| ITM_Z1_HotDog | Commun | Conforme | 3 couleurs, bonne silhouette | P1 |
| ITM_Z1_PotDeNouilles | Rare | Conforme | 6 couleurs, particules, lisible | P1 |
| ITM_Z1_Banane | Commun | Conforme | 2 couleurs, forme simple | P1 |
| ITM_Z1_Ananas | Commun | Conforme | 4 couleurs | P1 |
| ITM_Z1_Pasteque | Commun | Conforme | 5 couleurs, forme pleine | P1 |
| ITM_Z1_Carotte | Commun | Conforme | 4 couleurs | P1 |
| ITM_Z1_Brocoli | Commun | Conforme | 3 verts, forme en blocs | P1 |
| ITM_Z1_EpiDeMais | Commun | Conforme | 3 couleurs | P1 |
| ITM_Z2_CanardEnPlastique | Commun | Conforme | 3 couleurs, forme pleine | P1 |
| ITM_Z2_BallonDeFoot | Commun | Conforme | Sphère, noir et blanc | P1 |
| ITM_Z2_BoosterDeCartes | Peu commun | À retoucher | 7 couleurs et 0,5 stud d'épaisseur : réduire à 5 couleurs, épaissir à 0,8 | P1 |
| ITM_Z2_YoYo | Peu commun | Conforme | 3 couleurs | P1 |
| ITM_Z2_CarteHolographique | Épique | **À refaire** | Carte plate de 0,5 stud en Glass : invisible de profil, 7 couleurs | P1 |
| ITM_Z2_RobotJouet | Épique | Conforme | Blocs, un accent néon | P1 |
| ITM_Z2_FigurineHolographique | Mythique | À retoucher | 4 pièces sur 5 en néon : la forme se perd dans la lueur ; socle et corps pleins, néon sur une pièce | P1 |
| ITM_Z2_OursEnPeluche | Commun | Conforme | 4 couleurs, forme pleine | P1 |
| ITM_Z2_PelucheGeante | Légendaire | Conforme | Foil, particules, idle `Bob` | P1 |
| ITM_Z2_Sucette | Commun | Conforme | 5 couleurs | P1 |
| ITM_Z2_BarbeAPapa | Peu commun | Conforme | Rose pastel, forme pleine | P1 |
| ITM_Z2_MaisonEnPainDEpices | Rare | Conforme | Bloc détaillé en plaques | P1 |
| ITM_Z2_BusAImperiale | Peu commun | Conforme | Bloc, 6 couleurs | P1 |
| ITM_Z2_Skateboard | Peu commun | Conforme | 6 couleurs | P1 |
| ITM_Z2_VoitureTelecommandee | Rare | Conforme | 7 couleurs, forme pleine | P1 |
| ITM_Z2_TrainElectrique | Épique | Conforme | Bien lu en capture, un néon | P1 |
| ITM_Z3_Ecouteurs | Commun | À retoucher | Néon sur un Commun : passer l'accent en SmoothPlastic | P1 |
| ITM_Z3_TelephoneAClapet | Peu commun | À retoucher | Gris clair `#B8C2D0` dominant : coque en couleur franche | P1 |
| ITM_Z3_Smartphone | Rare | À retoucher | 8 couleurs, gris foncé dominant : 5 couleurs, coque colorée | P1 |
| ITM_Z3_Souris | Commun | **À refaire** | Galette de 0,5 stud de haut : se lit comme un disque | P1 |
| ITM_Z3_OrdinateurPortable | Peu commun | Conforme | Bleu franc, bien lu | P1 |
| ITM_Z3_PcGamer | Légendaire | Conforme | Néon, Foil, particules (attribut `Idle` absent : voir notes) | P1 |
| ITM_Z3_CarteGraphiqueEnOr | Mythique | Conforme | Foil or, néon, particules (`Idle` absent) | P1 |
| ITM_Z3_TeleRetro | Commun | Conforme | Bien lue en capture | P1 |
| ITM_Z3_TeleGeante | Épique | Conforme | Écran néon, cadre jaune | P1 |
| ITM_Z3_Manette | Peu commun | Conforme | Bleu franc | P1 |
| ITM_Z3_CasqueVr | Rare | À retoucher | Tout en gris foncé `#3A404B` / `#1B1B24`, pas de brillance de Rare | P1 |
| ITM_Z3_ConsoleADoubleEcran | Rare | **À refaire** | 3 pièces pâles sans détail, ne se reconnaît pas | P1 |
| ITM_Z3_ConsoleDeSalon | Épique | À retoucher | Gris foncé dominant : couleur de corps franche | P1 |
| ITM_Z3_ConsolePortable | Épique | Conforme | Rose et blanc, néon | P1 |
| ITM_Z4_Bague | Commun | À retoucher | Or hors palette, Glass sur un Commun | P1 |
| ITM_Z4_ChaineEnOr | Peu commun | **À refaire** | Chaîne fine : pas de silhouette à 40 studs | P1 |
| ITM_Z4_CollierDePerles | Rare | **À refaire** | Perles fines sur fil : pas de silhouette | P1 |
| ITM_Z4_MontreEnOr | Commun | À retoucher | Or hors palette | P1 |
| ITM_Z4_CoffretDeMontres | Peu commun | Conforme | Bloc bois, vitre | P1 |
| ITM_Z4_MontreAGousset | Rare | À retoucher | Or hors palette, pas de Foil | P1 |
| ITM_Z4_PenduleDoree | Commun | À retoucher | Or hors palette | P1 |
| ITM_Z4_HorlogeDeParquet | Épique | À retoucher | Or hors palette (forme bonne en capture) | P1 |
| ITM_Z4_Parfum | Commun | À retoucher | Or hors palette, Glass sur un Commun | P1 |
| ITM_Z4_LunettesDeStar | Peu commun | **À refaire** | Montures fines : pas de silhouette | P1 |
| ITM_Z4_BasketsDeCollection | Rare | À retoucher | Or hors palette | P1 |
| ITM_Z4_Rubis | Peu commun | À retoucher | Or hors palette sur le socle | P1 |
| ITM_Z4_DiamantBrut | Épique | Conforme | Cristaux en blocs, néon | P1 |
| ITM_Z4_Couronne | Légendaire | Conforme | Foil, particules, idle `Spin` | P1 |
| ITM_Z4_OeufEnDiamant | Mythique | Conforme | Foil, particules, idle `Spin` | P1 |
| ITM_Z5_TableauDeMaitre | Commun | À retoucher | Bruns sombres `#3B2A1E` / `#8A5A33` : cadre plus clair, toile plus vive | P1 |
| ITM_Z5_LaJoconde | Épique | À retoucher | 10 couleurs : ramener à 6 | P1 |
| ITM_Z5_BusteEnMarbre | Commun | À retoucher | 2 gris ternes : socle en couleur | P1 |
| ITM_Z5_TourEiffelEnBronze | Peu commun | **À refaire** | Treillis fin, 2 teintes sombres : pas de silhouette | P1 |
| ITM_Z5_LePenseur | Peu commun | À retoucher | Brun et gris ternes : bronze plus chaud, socle coloré | P1 |
| ITM_Z5_StatueDoree | Rare | À retoucher | Or hors palette, pas de Foil | P1 |
| ITM_Z5_VaseAncien | Commun | Conforme | Blanc et bleu, forme pleine | P1 |
| ITM_Z5_LustreEnCristal | Peu commun | À retoucher | Or hors palette, bras fins à épaissir | P1 |
| ITM_Z5_ArmureDeChevalier | Rare | À retoucher | Or hors palette (forme bonne en capture) | P1 |
| ITM_Z5_Sarcophage | Épique | À retoucher | Or hors palette | P1 |
| ITM_Z5_MasqueAncien | Légendaire | Conforme | Foil, néon, particules, idle `Bob` | P1 |
| ITM_Z5_Meteorite | Mythique | Conforme | Basalt et néon, particules, `SpinBob` | P1 |
| ITM_Z6_LingotDOr | Commun | À retoucher | Or hors palette | P1 |
| ITM_Z6_SceptreRoyal | Commun | À retoucher | Or hors palette, tige de 0,8 stud à épaissir | P1 |
| ITM_Z6_PyramideDeLingots | Peu commun | À retoucher | Or hors palette | P1 |
| ITM_Z6_TroneEnOr | Épique | À retoucher | Or hors palette, pas de Foil | P1 |
| ITM_Z6_SacDeDiamants | Peu commun | À retoucher | Or hors palette | P1 |
| ITM_Z6_DiamantGeant | Rare | À retoucher | Or hors palette | P1 |
| ITM_Z6_AigleDeCristal | Commun | **À refaire** | Glass transparent en 2 pièces : la forme disparaît | P1 |
| ITM_Z6_TaureauEnOr | Rare | À retoucher | Or hors palette, pas de Foil | P1 |
| ITM_Z6_StatueDeLaLiberte | Épique | Conforme | 3 couleurs, flamme néon | P1 |
| ITM_Z6_CoffreFortBlinde | Peu commun | À retoucher | Or hors palette sur la roue | P1 |
| ITM_Z6_CoffreDeDiamants | Légendaire | Conforme | Foil, particules, idle `Bob` | P1 |
| ITM_Z6_CleDuCoffreUltime | Mythique | Conforme | Foil, néon, particules, `SpinBob` | P1 |
| ITM_Secret_ChatPorteBonheurDore | Secret | Conforme | Foil, lumière, particules (`Idle` absent) | P1 |

Notes sur les objets :

- Attribut `Idle` absent sur 4 objets Légendaire et plus : `ITM_Z3_PcGamer`, `ITM_Z3_CarteGraphiqueEnOr`, `ITM_Z2_FigurineHolographique`, `ITM_Secret_ChatPorteBonheurDore`. Ce n'est pas une question de DA, mais 10.5 demande une animation idle à partir de Légendaire. À vérifier par Clément.
- `ITM_Z3_TeleGeante` existe en 2 exemplaires dans `Assets/Items` (doublon de nom).

### Outils — `ReplicatedStorage/Assets/Tools` et `Assets/Unbox`

Capture : [outils de casse](img/revue-2026-11-20/09_outils.jpg).

| Nom | Verdict | Raison | Priorité |
| --- | --- | --- | --- |
| TOOL_Batte | Conforme | 3 couleurs franches | P1 |
| TOOL_Marteau | Conforme | Bleu franc, Metal sur la tête | P1 |
| TOOL_PiedDeBiche | Conforme | Vert et métal | P1 |
| TOOL_Masse | Conforme | Violet, un néon | P1 |
| TOOL_HacheDIncendie | Conforme | Or `#FFC21A` en Foil, rouge | P1 |
| TOOL_Disqueuse | Conforme | 7 couleurs, mais bien lue | P1 |
| TOOL_CleAMolette | À retoucher | 3 gris, rien qui accroche l'œil : manche en couleur | P1 |
| TOOL_Unbox_Crowbar | À retoucher | Construit en Parts Metal texturé (6/7) : SmoothPlastic + 1 pièce Metal | P1 |
| TOOL_Unbox_Drill | À retoucher | Plastic à studs mêlé à Metal : SmoothPlastic | P1 |
| TOOL_Unbox_Saw | À retoucher | 13 pièces sur 17 en Metal texturé | P1 |
| TOOL_Unbox_Sledgehammer | À retoucher | Mélange Metal, Fabric, Plastic : 2 matériaux | P1 |
| TOOL_Unbox_Magnifier | À retoucher | 14 pièces sur 17 en Metal texturé | P1 |

### Magasins PNJ `STORE_` — `Workspace/Map/Zone_N`

Captures : [Z1](img/revue-2026-11-20/10_magasins_z1.jpg), [Z5 et Z6](img/revue-2026-11-20/11_magasins_z5_z6.jpg). Le décor suit la planche 10.6 (« mode studs ») : les studs y sont voulus. On juge ici la saturation, la palette et la lisibilité.

| Nom | Verdict | Raison | Priorité |
| --- | --- | --- | --- |
| STORE_Z1_Kiosque | Conforme | Bleu franc, auvent rayé, studs | P2 |
| STORE_Z1_Superette | Conforme | Rouge franc, auvent rayé | P2 |
| STORE_Z2_Confiserie | Conforme | Pastels chauds, saturés | P2 |
| STORE_Z2_MagasinDeJouets | Conforme | Rouge et rose francs | P2 |
| STORE_Z3_Electronique | À retoucher | Dominante noire `#1E1E24` (à confirmer en capture) | P2 |
| STORE_Z3_JeuxVideo | Conforme | Vert, rose, bleu francs | P2 |
| STORE_Z4_Bijouterie | À retoucher | Noir et bordeaux `#7A162C`, or `#D4AF37` hors palette (à confirmer) | P2 |
| STORE_Z4_Horlogerie | À retoucher | Or `#D6B250` hors palette, bruns (à confirmer) | P2 |
| STORE_Z5_Antiquaire | À retoucher | Façade pâle, or `#D4B05A` hors palette | P2 |
| STORE_Z5_GalerieDArt | À retoucher | Bleu-gris délavé, vert sombre (capture) | P2 |
| STORE_Z6_Banque | À retoucher | Bleu-gris délavé (capture), or `#D4AC3C` | P2 |
| STORE_Z6_SalleDesCoffres | À retoucher | Gris `#B4BAC4` dominant, or `#F5C414` | P2 |

### Parcelles et tapis `PLOT_` — `ReplicatedStorage/Assets/Plots`

Capture : [tapis](img/revue-2026-11-20/14_tapis.jpg).

| Nom | Verdict | Raison | Priorité |
| --- | --- | --- | --- |
| PLOT_Shop (modèle des boutiques ; copies `PLOT_Shop_01` à `_06` dans le hub) | À retoucher | Blanc, verre et marbre dominants (27 couleurs, 69 pièces en Glass) : peu saturé à côté des colis (à confirmer en capture) | P3 |
| PLOT_Shop_Rayons | Conforme | 2 couleurs franches | P3 |
| PLOT_Treadmill_Base, _Silver, _Gold, _Fire, _Ice, _Void, _Toxic, _Candy, _CashRegister, _Police, _LaserVault (11) | Conforme | Thèmes francs, un ou deux néons, lisibles | P3 |

### Vitres `WIN_` — `ReplicatedStorage/Assets/Windows`

| Nom | Verdict | Raison | Priorité |
| --- | --- | --- | --- |
| WIN_M, WIN_M_Fractured, WIN_M_Fractured_Left, WIN_M_Fractured_Right | Conforme | Verre `#BFE6FF`, une seule teinte, rôle fonctionnel | P2 |

### Décor `ENV_`

Captures : [décor de rue](img/revue-2026-11-20/12_decor_props.jpg), [comptoirs du hub](img/revue-2026-11-20/13_comptoirs_hub.jpg). Familles de variantes groupées sur une ligne.

| Nom | Chemin | Verdict | Raison | Priorité |
| --- | --- | --- | --- | --- |
| ENV_Event_Truck et ses 8 variantes `_Common` à `_Divine` | `RS/Assets/Events` | Conforme | Le plus proche des colis : carton, `OutlineHighlight`, couleur de rareté | P2 |
| ENV_Event_FortuneVault | `RS/Assets/Events` | À retoucher | Or `#D4AC3C` / `#ECBA28` hors palette | P2 |
| ENV_Unbox_Junk_BananaPeel, _Boot, _Duck, _FishBone, _Sock (5) | `RS/Assets/Unbox` | Conforme | Petits, 2 à 5 couleurs franches | P2 |
| ENV_Hub_AuraStall, _PawnStall, _RobuxStall, _WeaponStall (4) | `Map/Hub/Stalls` | Conforme | Bois et auvents rayés, couleurs franches (capture) | P3 |
| ENV_Hub_FreeGift | `Map/Hub/Zones` | À retoucher | C'est un cadeau : il devrait ressembler à un colis (contour, matière) ; Plastic par défaut | P3 |
| ENV_Hub_InviteNoob | `Map/Hub/Zones` | À retoucher | Couleurs Roblox par défaut `#4B974B`, `#0D69AC` | P3 |
| ENV_Hub_Wheel, ENV_Hub_Leaderboard | `Map/Hub/Zones` | Conforme | Couleurs franches | P3 |
| ENV_Hub_Fountain | `SS/Assets/Env` | Conforme | 10 couleurs, studs | P3 |
| ENV_Stalls_AuraStall_Hub, _PawnStall_Hub, _RobuxStall_Hub, _WeaponStall_Hub (4) | `SS/Assets/Env/Stalls` | Conforme | Mêmes comptoirs que dans le hub | P3 |
| Immeubles Z1 : House_Z1 (×2), House_Flats_Z1 (×2), Shop_Bakery, _Cafe, _Florist, _IceCream, _Pharmacy (9) | `SS/Assets/Env/Buildings` | Conforme | Pastels saturés (capture) | P4 |
| Immeubles Z2 : House_Z2, Mansion_Z2 (×3), Terrace_Z2 (×2) (6) | idem | Conforme | 5 à 10 couleurs | P4 |
| Immeubles Z3 : Apartment, Hall, House (×2), Shop (×2), Tower (×8) (14) | idem | Conforme | Néons de Tokyo | P4 |
| Immeubles Z4 : Apartments, Bungalow, Hotel, SoundStage, Tower (×2) (6) | idem | Conforme | Blocs simples | P4 |
| Immeubles Z5 : BackRow, Building_Z5 (×6) (7) | idem | À retoucher | Bleu-gris délavé (capture) | P4 |
| Immeubles Z6 : GatewayTower (×2), Midrise (×3), Tower_Z6 (×6) (11) | idem | À retoucher | Verre pâle dominant (à confirmer) | P4 |
| Immeubles Z6 : Tenement_Z6 (×4), Tenement_End_Z6 (5) | idem | Conforme | 11 à 13 couleurs, briques | P4 |
| Façades Z1 : Barber, Books, Laundry, Pizza (4) ; Boutique_Z4 ; CafeTerrace_Z5 | `SS/Assets/Env/Facades` | Conforme | Couleurs franches | P4 |
| Façades Haussmann_Z5 (×4) | idem | À retoucher | Bleu-gris délavé (capture) | P4 |
| Monuments (14) : Bandstand, Carousel, ClockTower, EiffelTower, EndTower, Fountain_Z1, Fountain_Z5, GoldenDome, ObservationWheel, RadioTower, StarTower, Temple, Torii, WaterTower | `SS/Assets/Env/Landmarks` | Conforme | Vus de loin, formes simples | P4 |
| Arbres PBR : BigTree_Z1, Poplar_Z1, Tree_Z1, Tree_Z2, Tree_Z5, YardTree_Z5, Sakura_Z3, SakuraBig_Z3, BoulevardTree_A1 à _A6, BoulevardTree_B1 à _B6 (20) | `SS/Assets/Env/Nature` | **À refaire** | Feuillage LeafyGrass + SurfaceAppearance (PBR réaliste) : rien de commun avec un décor en blocs | P4 |
| Palm_Z4 et Palm_B1 à _B11 (12) | idem | À retoucher | Feuillage violet en capture : couleur à valider avec Clément | P4 |
| Fir_Z5, FlowerBed_Z1 | idem | Conforme | Blocs, couleurs franches | P4 |
| Panneaux (5) : Billboard_Z4, StreetNamePlate_Z1, StreetSign_Z4, TownMap_Z1, WelcomeSign_Z1 | `SS/Assets/Env/Signs` | Conforme | Simples, 2 à 4 couleurs | P2 |
| Mobilier de rue (40) : lampadaires, bancs, bouches d'incendie, poubelles, arrêts de bus, guirlandes, cabine, kiosque, etc. | `SS/Assets/Env/Street` | Conforme | 2 à 8 couleurs, petits volumes | P2 |
| Véhicules : DoubleDecker_Z2, Taxi_Z6 | `SS/Assets/Env/Vehicles` | Conforme | Formes en blocs | P2 |

## Ce qu'il faut refaire, par lots

Les 28 modèles « À refaire », regroupés par style commun, dans l'ordre de passage.

### Lot 1 — Objets exposés à silhouette fine (8 modèles, P1)

Point commun : objets fins ou transparents qu'il faut rebâtir en volumes pleins, posés sur un petit socle si besoin, avec la couleur et la matière de leur rareté (tableau 5 de la fiche DA).

1. `ITM_Z2_CarteHolographique` (Épique) : carte épaisse (≥ 0,3 stud) dans un présentoir debout, une face néon.
2. `ITM_Z3_Souris` (Commun) : souris bombée d'au moins 0,9 stud de haut, molette en relief.
3. `ITM_Z3_ConsoleADoubleEcran` (Rare) : console ouverte, deux écrans pleins, boutons en plaques.
4. `ITM_Z4_ChaineEnOr` (Peu commun) : grosse chaîne à maillons épais (≥ 0,2 stud) sur un buste ou un coussin.
5. `ITM_Z4_CollierDePerles` (Rare) : perles d'au moins 0,25 stud sur un buste de présentation.
6. `ITM_Z4_LunettesDeStar` (Peu commun) : grosses montures (≥ 0,15 stud) sur un support.
7. `ITM_Z5_TourEiffelEnBronze` (Peu commun) : tour en 3 étages pleins, treillis suggéré par des plaques, bronze chaud.
8. `ITM_Z6_AigleDeCristal` (Commun) : aigle en blocs opaques bleu glacier (pas de Glass), socle sombre.

### Lot 2 — Arbres en blocs (10 modèles de base pour 20 arbres, P4)

Point commun : remplacer le feuillage PBR par des boules ou des blocs de feuillage en SmoothPlastic, 2 verts de la palette (`#7ED957`, `#5CC23A`) ou rose pour les cerisiers, tronc bois `#9A5B2E`, sans SurfaceAppearance.

1. `ENV_Nature_BigTree_Z1`
2. `ENV_Nature_Poplar_Z1`
3. `ENV_Nature_Tree_Z1`
4. `ENV_Nature_Tree_Z2`
5. `ENV_Nature_Tree_Z5`
6. `ENV_Nature_YardTree_Z5`
7. `ENV_Nature_Sakura_Z3`
8. `ENV_Nature_SakuraBig_Z3`
9. `ENV_Nature_BoulevardTree_A` (un modèle, décliné en `_A1` à `_A6` par la taille)
10. `ENV_Nature_BoulevardTree_B` (un modèle, décliné en `_B1` à `_B6`)

## Retouches dans Studio, par lots (sans remodeler)

À faire avant ou pendant les lots à refaire. Ce sont surtout des changements de couleur et de matériau.

- **R1, l'or des colis (20 objets + 1 décor, P1)** : recolorer l'or `#E8B830` / `#F2C230` en `#FFC21A`, en Foil à partir de Rare. Objets Z4 (Bague, MontreEnOr, MontreAGousset, PenduleDoree, HorlogeDeParquet, Parfum, BasketsDeCollection, Rubis), Z5 (StatueDoree, LustreEnCristal, ArmureDeChevalier, Sarcophage), Z6 (LingotDOr, SceptreRoyal, PyramideDeLingots, TroneEnOr, SacDeDiamants, DiamantGeant, TaureauEnOr, CoffreFortBlinde), plus `ENV_Event_FortuneVault`.
- **R2, objets ternes ou trop chargés (11 objets, P1)** : BoosterDeCartes, FigurineHolographique, Ecouteurs, TelephoneAClapet, Smartphone, CasqueVr, ConsoleDeSalon, TableauDeMaitre, LaJoconde, BusteEnMarbre, LePenseur ; en plus, épaissir la tige de SceptreRoyal et les bras de LustreEnCristal (déjà dans R1 pour l'or).
- **R3, outils (6, P1)** : manche coloré pour la clé à molette ; les 5 outils d'ouverture passent en SmoothPlastic avec une seule pièce en Metal.
- **R4, magasins et façades pâles des zones 3 à 6 (7 magasins + 22 immeubles et façades, P2 puis P4)** : saturer les façades, or `#FFC21A`, garder les studs. Prendre d'abord les captures manquantes (Z3, Z4, tours Z6).
- **R5, hub (3, P3)** : FreeGift en colis cadeau (carton ou couleur pleine, ruban, contour), InviteNoob aux couleurs de la palette, et PLOT_Shop à revoir après capture.
- **R6, palmiers (12, P4)** : feuillage violet à valider avec Clément.

## Questions pour Clément

1. Le contour noir des objets exposés : coque inversée dans le maillage (proposition) ou autre méthode ? À voir avec Ironix, puisque le Highlight est réservé aux colis.
2. Les palmiers violets de la zone 4 : voulus (coucher de soleil de Los Angeles) ou à repasser en vert ?
3. Faut-il une capture en Play des 8 colis de rareté avant la planche ChatGPT ? Elle n'a pas pu être faite en Edit.
