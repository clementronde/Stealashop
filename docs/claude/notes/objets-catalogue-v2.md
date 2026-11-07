# Session « objets » : catalogue v2 VALIDÉ (MOD-014, MOD-026)

**Validé par Clément le 2026-11-07.** 74 objets : 31 repris de la v1, 43 nouveaux, 6 retirés. Données machine : `objets-catalogue-v2.json` (même dossier). **Noms affichés en anglais** (consigne de Clément du 2026-11-07 : tout le texte du jeu est en anglais) ; les identifiants `ITM_<Zone>_<Nom>` ne changent pas.

## Règles validées

- Zone 1 (Supérette, Kiosque) = zone tuto : 12 Communs (3 par catégorie) ; le Pot de nouilles (Rare) ne sort que du premier colis du tuto.
- Zones 2 à 6 : 12 objets chacune, 4 catégories ; 3 Communs, 3 Peu communs, 2 Rares, 2 Épiques, 1 Légendaire, 1 Mythique.
- Progression : le moins cher d'une zone vaut entre le Rare et l'Épique de la zone d'avant (comme les revenus). Pas de billets ni de chèques (demande de Clément).
- Tirage inchangé : rareté selon la table 7.3, puis un objet au hasard parmi ceux de (zone, rareté). Aucun chiffre d'équilibrage ne change.
- Étiquette `BB_Box` : catégorie + rareté (+ mutation cachée), en anglais. Vélo et Voiture réunis dans « Vehicle » (zone 2). Secret : catégorie affichée « ??? ».
- Légendaire et plus (11 objets) : animation idle par pièces mobiles nommées + effets natifs, jouée par le code (aucun script dans le modèle).
- Nommage : modèle `ITM_<ItemId>`, ItemId = `Z<zone>_<NomPascalCase>` (Secret : `Secret_ChatPorteBonheurDore`).

## Catalogue

| Zone | Catégorie (FR) | Category (EN) | Objet (FR) | Name (EN) | Rareté | ItemId | Origine |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 Supérette | Boisson | Drink | Canette de soda | Soda Can | Commun | `Z1_CanetteDeSoda` | v1, déjà modélisé |
| 1 Supérette | Boisson | Drink | Boisson énergisante | Energy Drink | Commun | `Z1_BoissonEnergisante` | v1, déjà modélisé (était Épique) |
| 1 Supérette | Boisson | Drink | Brique de lait | Milk Carton | Commun | `Z1_BriqueDeLait` | nouveau |
| 1 Supérette | Snack | Snack | Paquet de chips | Bag of Chips | Commun | `Z1_PaquetDeChips` | v1 (était Peu commun) |
| 1 Supérette | Snack | Snack | Donut | Donut | Commun | `Z1_Donut` | nouveau |
| 1 Supérette | Snack | Snack | Hot-dog | Hot Dog | Commun | `Z1_HotDog` | nouveau |
| 1 Supérette | Snack | Snack | Pot de nouilles | Instant Noodles | Rare | `Z1_PotDeNouilles` | v1 (tuto · renaissance 1) |
| 1 Supérette | Fruit | Fruit | Banane | Banana | Commun | `Z1_Banane` | nouveau |
| 1 Supérette | Fruit | Fruit | Ananas | Pineapple | Commun | `Z1_Ananas` | nouveau |
| 1 Supérette | Fruit | Fruit | Pastèque | Watermelon | Commun | `Z1_Pasteque` | nouveau |
| 1 Supérette | Légumes | Vegetable | Carotte | Carrot | Commun | `Z1_Carotte` | nouveau |
| 1 Supérette | Légumes | Vegetable | Brocoli | Broccoli | Commun | `Z1_Brocoli` | nouveau |
| 1 Supérette | Légumes | Vegetable | Épi de maïs | Corn Cob | Commun | `Z1_EpiDeMais` | nouveau |
| 2 Londres | Jouet | Toy | Canard en plastique | Rubber Duck | Commun | `Z2_CanardEnPlastique` | v1 |
| 2 Londres | Jouet | Toy | Yo-yo | Yo-Yo | Peu commun | `Z2_YoYo` | v1 |
| 2 Londres | Jouet | Toy | Robot jouet | Toy Robot | Épique | `Z2_RobotJouet` | v1 (renaissance 3) |
| 2 Londres | Jouet | Toy | Figurine holographique | Hologram Figure | Mythique | `Z2_FigurineHolographique` | v1 |
| 2 Londres | Peluche | Plush | Ours en peluche | Teddy Bear | Commun | `Z2_OursEnPeluche` | nouveau |
| 2 Londres | Peluche | Plush | Peluche géante | Giant Plush | Légendaire | `Z2_PelucheGeante` | v1 |
| 2 Londres | Bonbon | Candy | Sucette | Lollipop | Commun | `Z2_Sucette` | nouveau |
| 2 Londres | Bonbon | Candy | Barbe à papa | Cotton Candy | Peu commun | `Z2_BarbeAPapa` | nouveau |
| 2 Londres | Bonbon | Candy | Maison en pain d'épices | Gingerbread House | Rare | `Z2_MaisonEnPainDEpices` | nouveau |
| 2 Londres | Véhicule | Vehicle | Bus à impériale | Double-Decker Bus | Peu commun | `Z2_BusAImperiale` | nouveau |
| 2 Londres | Véhicule | Vehicle | Voiture télécommandée | RC Car | Rare | `Z2_VoitureTelecommandee` | v1 (renaissance 2) |
| 2 Londres | Véhicule | Vehicle | Train électrique | Toy Train | Épique | `Z2_TrainElectrique` | nouveau |
| 3 Tokyo | Téléphone | Phone | Écouteurs | Earbuds | Commun | `Z3_Ecouteurs` | v1 |
| 3 Tokyo | Téléphone | Phone | Téléphone à clapet | Flip Phone | Peu commun | `Z3_TelephoneAClapet` | nouveau |
| 3 Tokyo | Téléphone | Phone | Smartphone | Smartphone | Rare | `Z3_Smartphone` | v1 |
| 3 Tokyo | Ordinateur | Computer | Souris | Computer Mouse | Commun | `Z3_Souris` | nouveau |
| 3 Tokyo | Ordinateur | Computer | Ordinateur portable | Laptop | Peu commun | `Z3_OrdinateurPortable` | nouveau |
| 3 Tokyo | Ordinateur | Computer | PC gamer | Gaming PC | Légendaire | `Z3_PcGamer` | v1 |
| 3 Tokyo | Ordinateur | Computer | Carte graphique en or | Golden Graphics Card | Mythique | `Z3_CarteGraphiqueEnOr` | v1 |
| 3 Tokyo | Télé | TV | Télé rétro | Retro TV | Commun | `Z3_TeleRetro` | nouveau |
| 3 Tokyo | Télé | TV | Télé géante | Giant TV | Épique | `Z3_TeleGeante` | nouveau |
| 3 Tokyo | Console | Console | Manette | Game Controller | Peu commun | `Z3_Manette` | v1 |
| 3 Tokyo | Console | Console | Casque VR | VR Headset | Rare | `Z3_CasqueVr` | nouveau |
| 3 Tokyo | Console | Console | Console portable | Handheld Console | Épique | `Z3_ConsolePortable` | v1 (renaissance 4) |
| 4 Los Angeles | Bijou | Jewelry | Bague | Ring | Commun | `Z4_Bague` | v1 |
| 4 Los Angeles | Bijou | Jewelry | Chaîne en or | Gold Chain | Peu commun | `Z4_ChaineEnOr` | nouveau |
| 4 Los Angeles | Bijou | Jewelry | Collier de perles | Pearl Necklace | Rare | `Z4_CollierDePerles` | v1 |
| 4 Los Angeles | Montre | Watch | Montre en or | Gold Watch | Commun | `Z4_MontreEnOr` | v1 (v1 : Montre, était Peu commun) |
| 4 Los Angeles | Montre | Watch | Coffret de montres | Watch Box | Peu commun | `Z4_CoffretDeMontres` | nouveau |
| 4 Los Angeles | Montre | Watch | Montre à gousset | Pocket Watch | Rare | `Z4_MontreAGousset` | nouveau |
| 4 Los Angeles | Horloge | Clock | Pendule dorée | Golden Clock | Commun | `Z4_PenduleDoree` | nouveau |
| 4 Los Angeles | Horloge | Clock | Horloge de parquet | Grandfather Clock | Épique | `Z4_HorlogeDeParquet` | nouveau |
| 4 Los Angeles | Joyau | Jewel | Rubis | Ruby | Peu commun | `Z4_Rubis` | nouveau |
| 4 Los Angeles | Joyau | Jewel | Diamant brut | Rough Diamond | Épique | `Z4_DiamantBrut` | v1 (renaissance 5) |
| 4 Los Angeles | Joyau | Jewel | Couronne | Crown | Légendaire | `Z4_Couronne` | v1 (renaissance 6) |
| 4 Los Angeles | Joyau | Jewel | Œuf en diamant | Diamond Egg | Mythique | `Z4_OeufEnDiamant` | v1 |
| 5 Paris | Tableau | Painting | Tableau de maître | Classic Painting | Commun | `Z5_TableauDeMaitre` | nouveau |
| 5 Paris | Tableau | Painting | La Joconde | Mona Lisa | Épique | `Z5_LaJoconde` | nouveau |
| 5 Paris | Sculpture | Sculpture | Buste en marbre | Marble Bust | Commun | `Z5_BusteEnMarbre` | v1 (était Peu commun) |
| 5 Paris | Sculpture | Sculpture | Tour Eiffel en bronze | Bronze Eiffel Tower | Peu commun | `Z5_TourEiffelEnBronze` | nouveau |
| 5 Paris | Sculpture | Sculpture | Le Penseur | The Thinker | Peu commun | `Z5_LePenseur` | nouveau |
| 5 Paris | Sculpture | Sculpture | Statue dorée | Golden Statue | Rare | `Z5_StatueDoree` | v1 (était Épique) |
| 5 Paris | Antiquité | Antique | Vase ancien | Ancient Vase | Commun | `Z5_VaseAncien` | v1 (v1 : Vase) |
| 5 Paris | Antiquité | Antique | Lustre en cristal | Crystal Chandelier | Peu commun | `Z5_LustreEnCristal` | nouveau |
| 5 Paris | Antiquité | Antique | Armure de chevalier | Knight Armor | Rare | `Z5_ArmureDeChevalier` | nouveau |
| 5 Paris | Relique | Relic | Sarcophage | Sarcophagus | Épique | `Z5_Sarcophage` | nouveau |
| 5 Paris | Relique | Relic | Masque ancien | Ancient Mask | Légendaire | `Z5_MasqueAncien` | v1 (renaissance 7) |
| 5 Paris | Relique | Relic | Météorite | Meteorite | Mythique | `Z5_Meteorite` | v1 (renaissance 9) |
| 6 New York | Trésor | Treasure | Lingot d'or | Gold Bar | Commun | `Z6_LingotDOr` | v1 (était Rare) |
| 6 New York | Trésor | Treasure | Sceptre royal | Royal Scepter | Commun | `Z6_SceptreRoyal` | nouveau |
| 6 New York | Trésor | Treasure | Pyramide de lingots | Gold Bar Pyramid | Peu commun | `Z6_PyramideDeLingots` | nouveau |
| 6 New York | Trésor | Treasure | Trône en or | Golden Throne | Épique | `Z6_TroneEnOr` | nouveau |
| 6 New York | Joyau | Jewel | Sac de diamants | Bag of Diamonds | Peu commun | `Z6_SacDeDiamants` | nouveau |
| 6 New York | Joyau | Jewel | Diamant géant | Giant Diamond | Rare | `Z6_DiamantGeant` | nouveau |
| 6 New York | Statue | Statue | Aigle de cristal | Crystal Eagle | Commun | `Z6_AigleDeCristal` | nouveau |
| 6 New York | Statue | Statue | Taureau en or | Golden Bull | Rare | `Z6_TaureauEnOr` | nouveau |
| 6 New York | Statue | Statue | Statue de la Liberté | Statue of Liberty | Épique | `Z6_StatueDeLaLiberte` | nouveau |
| 6 New York | Coffre | Vault | Coffre-fort blindé | Armored Safe | Peu commun | `Z6_CoffreFortBlinde` | nouveau |
| 6 New York | Coffre | Vault | Coffre de diamants | Diamond Chest | Légendaire | `Z6_CoffreDeDiamants` | v1 (renaissance 8) |
| 6 New York | Coffre | Vault | Clé du coffre ultime | Ultimate Vault Key | Mythique | `Z6_CleDuCoffreUltime` | v1 (renaissance 10) |
| Toutes | ??? | ??? | Chat porte-bonheur doré | Golden Lucky Cat | Secret | `Secret_ChatPorteBonheurDore` | v1 |

## Retirés de la v1

- Ticket à gratter gagnant (Légendaire, zone 1, déjà modélisé) : Zone 1 = Communs seulement ; thème de jeu d'argent évité.
- Hot-dog en or (Mythique, zone 1) : Zone 1 = Communs seulement ; le Hot-dog en or pourra revenir avec la mutation Or (MAJ 4).
- Toile abstraite (Rare, zone 5) : Pas assez impressionnante pour Paris (demande de Clément).
- Liasse de billets (Commun, zone 6) : Pas de billets ni de chèques (demande de Clément).
- Sac de pièces (Peu commun, zone 6) : Pas assez impressionnant pour la salle des coffres (demande de Clément).
- Mallette de billets (Épique, zone 6) : Pas de billets ni de chèques (demande de Clément).

## À faire par la session principale (doc et liaison)

- Doc 10.5 : remplacer le tableau « un objet par rareté et par zone » par ce catalogue (catégories et noms anglais compris) ; 10.6 inchangé (objets test).
- Backlog : MOD-014 = 13 objets de la zone 1 ; MOD-026 = 60 objets des zones 2 à 6 ; MOD-040 = icônes des 74 objets ; Partie 2 3.4 : compteur de l'index sur 74.
- Renaissances (Partie 2, 3.2) : les 10 objets demandés restent au même endroit et à la même rareté.
- Pour Ironix (`Config/Items.luau`) : nom affiché = colonne Name (EN), catégorie affichée = colonne Category (EN) ; plusieurs objets par (zone, rareté) au lieu d'un seul ; un champ catégorie (id sans accent + nom anglais) ; zone 1 = Communs seulement, sauf le colis du tuto (Pot de nouilles) ; deux ItemId v1 renommés : `Z4_Montre` → `Z4_MontreEnOr`, `Z5_Vase` → `Z5_VaseAncien` ; ItemId retirés : `Z1_TicketAGratterGagnant`, `Z1_HotDogEnOr`, `Z5_ToileAbstraite`, `Z6_LiasseDeBillets`, `Z6_SacDePieces`, `Z6_MalletteDeBillets`.
- Point de conception à trancher avant la MAJ 3 : le Pot de nouilles (renaissance 1) ne s'obtient qu'une fois, au tuto ; vendu au receleur ou volé, la renaissance 1 devient impossible (sauf à le revoler).
- Journal (section 15) : catalogue v2 validé par Clément le 2026-11-07.

## Pour `ouverture-colis`

- Ensembles par (zone, rareté) : 3, 3, 2, 2, 1, 1 en zones 2 à 6 ; 12 Communs en zone 1. Catégorie + rareté désigne presque toujours un seul objet en zones 2 à 6, sauf deux cases à 2 objets (zone 5 Sculpture + Peu commun : Tour Eiffel en bronze, Le Penseur ; zone 6 Trésor + Commun : Lingot d'or, Sceptre royal), et 3 en zone 1. Clément a validé l'étiquette telle quelle.
