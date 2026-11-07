# Session « objets » : zone 1 livrée (MOD-014) et plan des zones 2 à 6 (MOD-026)

## Livré et validé par Clément (2026-11-07)

- **13 modèles `ITM_Z1_*` dans `Workspace/_INBOX_CLEMENT`**, conformes au catalogue v2 (`objets-catalogue-v2.md`) : CanetteDeSoda, BoissonEnergisante, BriqueDeLait, PaquetDeChips, Donut, HotDog, Banane, Ananas, Pasteque, Carotte, Brocoli, EpiDeMais, PotDeNouilles. À ranger par Ironix dans `ReplicatedStorage/Assets/Items` (DisplayService et UnboxController y cherchent `ITM_<ItemId>`). MOD-014 → « En revue ».
- **Contrat 10.4** : Model, PrimaryPart `Root` (Part invisible, `CanQuery` vrai, `CanCollide` faux, `PivotOffset` en bas au centre), attribut `ItemId` = `Z1_<Nom>`, aucun script (vérifié : 0 script, 63 pièces). Pièces maillées : `Anchored`, `CanCollide`/`CanTouch`/`CanQuery` faux, `Massless`, `CollisionFidelity` Box, SmoothPlastic.
- **Triangles** (budget 2 000) : de 210 (Banane) à 972 (Ananas). Tailles 0,8 à 2,2 studs de haut ; mêmes valeurs dans Studio que dans Blender.
- **Effet natif** : `ITM_Z1_PotDeNouilles/Noodles/SteamPoint/Steam` (ParticleEmitter, vapeur, texture `rbxasset://textures/particles/smoke_main.dds`, 3 particules/s). Il marche sans code.
- **Maillages** importés par Clément dans la place DEV (groupe RoundStone Studio).
- **Showroom** : sur la ligne de la zone 1 de la rangée « OBJETS (catalogue 10.5) », 13 copies `Show_<Nom>` (sans `ItemId`) sur des socles `Ped_<nom>` (« VALIDÉ ») en x = −109,2 à −58,8, pas de 4,2. Les 6 cubes et 6 socles de la zone 1 du catalogue v1 sont retirés.
- **Fichiers** : `StealAShop-Art/Items/Z1/` (`Z1_Objets.blend`, `.json`, `.fbx`, `FBX/` un fichier par objet, `_scripts/` pour tout régénérer). Les anciens .blend de la canette, de la boisson et du ticket sont gardés tels quels.

## À dire à Ironix (liaison)

1. Ranger les 13 `ITM_Z1_*` dans `ReplicatedStorage/Assets/Items` et vérifier avec le ContractChecker (`ExpectedCount` des objets passe de 37 à 74 avec le catalogue v2).
2. `Config/Items.luau` suit le catalogue v2 (`objets-catalogue-v2.json`) : catégories, plusieurs objets par (zone, rareté), zone 1 en Communs sauf le colis du tuto.
3. **Proposition de contrat pour les animations idle** (les 11 objets Légendaire et plus des zones 2 à 6, aucun script dans les modèles) : attribut `Idle` sur le modèle (`Spin` = rotation lente autour de Y, `Bob` = rebond, `SpinBob` = les deux), joué côté client ; pièces nommées `Spin_<Nom>` qui tournent sur leur axe Y propre (ventilateurs, anneau d'hologramme) ; lumières et étincelles en objets natifs déjà posés (PointLight, ParticleEmitter), qui marchent sans code. À valider par Ironix avant la zone 2.

## Plan des zones 2 à 6 (MOD-026, 60 objets)

- Même chaîne que la zone 1, une zone à la fois : modélisation Blender, contrôle, **un seul FBX par zone importé par Clément**, script de rangement, copies au showroom, validation de Clément dans Studio.
- Ordre : zone 2 Londres, 3 Tokyo, 4 Los Angeles, 5 Paris, 6 New York (5 et 6 avant le go / no-go du 6 décembre). Puis le Secret, le Chat porte-bonheur doré (MOD-031, M3).
- Par zone : 12 objets, dont 2 animés (Légendaire et Mythique), selon le contrat idle ci-dessus une fois validé.
- Showroom : une ligne par zone au même pas de 4,2 (12 socles), en remplaçant les cubes du catalogue v1.
- Ensuite, MOD-040 (icônes des 74 objets) peut sortir des mêmes fichiers Blender, même angle et même lumière.

## Zone 2 Londres livrée et validée par Clément (2026-11-07, MOD-026 en partie)

- **12 modèles `ITM_Z2_*` dans `Workspace/_INBOX_CLEMENT`** : CanardEnPlastique, OursEnPeluche, Sucette, YoYo, BarbeAPapa, BusAImperiale, VoitureTelecommandee, MaisonEnPainDEpices, RobotJouet, TrainElectrique, PelucheGeante, FigurineHolographique. Constaté à la livraison : les 6 objets déjà au catalogue v1 (Canard, Yo-yo, Voiture télécommandée, Robot jouet, Peluche géante, Figurine holographique) sont déjà rangés dans `ReplicatedStorage/Assets/Items` ; les 6 nouveaux restent dans le bac, à ranger quand `Config/Items` passe au catalogue v2. Même contrat que la zone 1 (`Root`, `ItemId`, aucun script, aucun maillage nommé `Root`).
- **Triangles** : de 392 (Sucette) à 1 404 (Train électrique) jusqu'à Épique, budget 2 000 ; Peluche géante 2 486 et Figurine holographique 976, budget 4 000.
- **Langage des raretés** : Rare en SmoothPlastic avec `Reflectance` 0,08 ; Épique à 0,14 avec un accent Neon (yeux et voyant violets du Robot jouet, phare jaune du Train électrique) ; Légendaire en Foil doré (corne et sabots de la licorne) ; Mythique en Foil doré + hologramme Neon translucide.
- **Effets natifs, sans code** : `PelucheGeante/Plush/Sparkles` (ParticleEmitter doré, 4/s) ; `FigurineHolographique/Glow/Sparkles` (cyan, 6/s, vers le haut) et `FigurineHolographique/Root/LightPoint/Glow` (PointLight cyan, Brightness 1,5, Range 8).
- **Points d'accroche d'animation (contrat proposé, à valider par Ironix)** : `ITM_Z2_PelucheGeante` porte l'attribut `Idle = "Bob"` (rebond du modèle entier, côté client) ; `ITM_Z2_FigurineHolographique` a deux MeshParts `Spin_Figure` et `Spin_Ring` dont le `PivotOffset` est sur l'axe vertical de l'objet : les faire tourner autour de Y (`part:PivotTo(part:GetPivot() * CFrame.Angles(0, dθ, 0))`, côté client, pièces ancrées).
- **Showroom** : ligne de la zone 2 (z = 299,5), 12 copies `Show_<Nom>` sur des socles « VALIDÉ », x = −109,2 à −63,0 ; les 6 cubes et 6 socles du catalogue v1 sont retirés.
- **Fichiers** : `StealAShop-Art/Items/Z2/` (`Z2_Objets.blend`, `.json`, `.fbx`, `FBX/`, `_scripts/z2_items.py`, `z2_studio_setup.luau`). Scripts communs dans `Items/Z1/_scripts/` (`itm_lib.py`, `build_zone.py`, `render_qa.py`, `make_studio_setup.py`).
- **Zone 1, correction** : le maillage `Root` de la carotte s'appelle `CarrotRoot` partout (script, FBX, copie du showroom), comme dans `Assets/Items`.
- **Reste du plan** : zones 3 Tokyo, 4 Los Angeles, 5 Paris, 6 New York, puis le Secret (MOD-031).

## Zone 3 Tokyo livrée et validée par Clément (2026-11-07, MOD-026 en partie)

- **12 modèles `ITM_Z3_*` dans `Workspace/_INBOX_CLEMENT`** : Ecouteurs, Souris, TeleRetro, TelephoneAClapet, OrdinateurPortable, Manette, Smartphone, CasqueVr, ConsolePortable, TeleGeante, PcGamer, CarteGraphiqueEnOr. À ranger dans `ReplicatedStorage/Assets/Items`. Même contrat (un seul `Root`, `ItemId`, aucun script).
- **Triangles** : de 232 (Télé géante) à 1 284 (Ordinateur portable) jusqu'à Épique ; PC gamer 1 288 et Carte graphique en or 1 340 (budget 4 000).
- **Raretés** : Rare `Reflectance` 0,08 (Smartphone, Casque VR) ; Épique 0,14 + accent Neon (cœur en pixels rose de la Console portable, soleil de la Télé géante) ; PC gamer : boîtier noir, arêtes et pieds en Foil doré, vitre en Glass, 3 fonds de ventilateur en Neon cyan, rose et violet ; Carte graphique en or : coque en Foil doré, cercles Neon rouge rosé.
- **Effets natifs** : `PcGamer/Gold/Sparkles` (doré, 3/s) et `PcGamer/Root/LightPoint/Glow` (PointLight rose, Range 6) ; `CarteGraphiqueEnOr/Shroud/Sparkles` (doré, 6/s, vers le haut) et `CarteGraphiqueEnOr/Root/LightPoint/Glow` (PointLight rouge rosé, Range 7).
- **Points d'accroche d'animation** : `Spin_Fan1`, `Spin_Fan2`, `Spin_Fan3` dans les deux modèles. **Précision du contrat proposé** : une pièce `Spin_*` tourne autour de l'axe Y de son pivot (`part:GetPivot()`), quel qu'il soit. Pour la figurine de Londres, ce pivot est vertical ; pour ces ventilateurs, il est réglé (`PivotOffset`) sur l'axe avant-arrière, au centre du moyeu. Une seule formule côté client suffit donc : `part:PivotTo(part:GetPivot() * CFrame.Angles(0, dθ, 0))`.
- **Showroom** : le showroom a été déplacé (+150 en z) par une autre session ; la ligne de la zone 3 est à z = 455 (zone 1 à 444, zone 2 à 449,5), 12 copies `Show_<Nom>` sur des socles « VALIDÉ », x = −109,2 à −63,0.
- **Fichiers** : `StealAShop-Art/Items/Z3/` (`Z3_Objets.blend`, `.json`, `.fbx`, `FBX/`, `_scripts/z3_items.py`, `z3_studio_setup.luau`).
- **Reste du plan** : zones 4 Los Angeles, 5 Paris, 6 New York, puis le Secret (MOD-031).

## Zone 4 Los Angeles livrée et validée par Clément (2026-11-07, MOD-026 en partie)

- **12 modèles `ITM_Z4_*` dans `Workspace/_INBOX_CLEMENT`** : Bague, MontreEnOr, PenduleDoree, ChaineEnOr, CoffretDeMontres, Rubis, CollierDePerles, MontreAGousset, HorlogeDeParquet, DiamantBrut, Couronne, OeufEnDiamant. À ranger dans `ReplicatedStorage/Assets/Items` (rappel : `Z4_Montre` de la v1 devient `Z4_MontreEnOr`). Même contrat (un seul `Root`, `ItemId`, aucun script).
- **Triangles** : de 270 (Diamant brut) à 1 076 (Collier de perles) jusqu'à Épique ; Couronne 1 840 et Œuf en diamant 2 036 (budget 4 000).
- **Matières** : or mat (SmoothPlastic `#E8B830`) en Commun et Peu commun, légèrement brillant en Rare (`Reflectance` 0,10), Foil `#FFC21A` en Légendaire et Mythique ; pierres en Glass (transparence 0,2) ; Épiques avec un accent Neon (cercle violet du cadran de l'Horloge de parquet, cœur cyan du Diamant brut).
- **Effets natifs** : `Couronne/Gold/Sparkles` (doré, 4/s) et `Couronne/Root/LightPoint/Glow` (lumière dorée, Range 6) ; `OeufEnDiamant/Diamonds/Sparkles` (blanc, 6/s) et `OeufEnDiamant/Root/LightPoint/Glow` (lumière rose, Range 7).
- **Animation** : attribut `Idle = "Spin"` sur `ITM_Z4_Couronne` et `ITM_Z4_OeufEnDiamant` (rotation lente du modèle entier autour de son pivot, côté client), selon le contrat proposé.
- **Showroom** : ligne de la zone 4 à z = 460,5, 12 copies `Show_<Nom>` sur des socles « VALIDÉ », x = −109,2 à −63,0.
- **Fichiers** : `StealAShop-Art/Items/Z4/` (`Z4_Objets.blend`, `.json`, `.fbx`, `FBX/`, `_scripts/z4_items.py`, `z4_studio_setup.luau`).
- **Reste du plan** : zones 5 Paris, 6 New York, puis le Secret (MOD-031).

## Zone 5 Paris livrée et validée par Clément (2026-11-07, MOD-026 en partie)

- **12 modèles `ITM_Z5_*` dans `Workspace/_INBOX_CLEMENT`** : TableauDeMaitre, BusteEnMarbre, VaseAncien, TourEiffelEnBronze, LePenseur, LustreEnCristal, StatueDoree, ArmureDeChevalier, LaJoconde, Sarcophage, MasqueAncien, Meteorite (rappel : `Z5_Vase` de la v1 devient `Z5_VaseAncien`). Même contrat.
- **Triangles** : de 488 (Le Penseur) à 1 352 (Lustre en cristal) jusqu'à Épique ; Masque ancien 974, Météorite 646.
- **Matières** : or mat jusqu'à Rare, Foil pour le Masque ancien ; armure en Metal ; verre de La Joconde en Glass (transparence 0,75) ; roche de la Météorite en Basalt ; accents Neon des Épiques (lampe de tableau de La Joconde, scarabée turquoise du Sarcophage).
- **Effets natifs** : `MasqueAncien/Gold/Sparkles` et lumière dorée ; `Meteorite/Lava/Sparkles` (braises orange vers le haut, 8/s) et lumière orange (Range 8).
- **Animation** : `Idle = "Bob"` sur `ITM_Z5_MasqueAncien`, `Idle = "SpinBob"` sur `ITM_Z5_Meteorite` (rotation lente + flottement), selon le contrat proposé.
- **Showroom** : ligne de la zone 5 à z = 466, 12 copies sur des socles « VALIDÉ ».

## 9 objets ajoutés à la demande de Clément, livrés et validés (2026-11-07)

- **Catalogue** : déjà reportés dans `objets-catalogue-v2.md` et `.json` (83 objets, noms anglais compris). Versions génériques, sans marque (pas de DS, de PlayStation ni de Pokémon).
- **9 modèles dans `Workspace/_INBOX_CLEMENT`** : `ITM_Z2_BallonDeFoot`, `ITM_Z2_BoosterDeCartes`, `ITM_Z2_Skateboard`, `ITM_Z2_CarteHolographique`, `ITM_Z3_ConsoleADoubleEcran`, `ITM_Z3_ConsoleDeSalon`, `ITM_Z4_Parfum`, `ITM_Z4_LunettesDeStar`, `ITM_Z4_BasketsDeCollection`. Même contrat ; de 220 à 900 triangles ; accents Neon sur les deux Épiques (créature de la Carte holographique, barre de la Console de salon).
- **Pour Ironix** : nouvelle catégorie Mode / Fashion en zone 4 ; zone 2 passe à 16 objets, zone 3 à 14, zone 4 à 15 ; `ExpectedCount` des objets à 83.
- **Showroom** : lignes des zones 2, 3 et 4 réalignées par rareté avec les ajouts (zone 2 : 16 socles jusqu'à x = −46,2 ; zone 3 : 14 ; zone 4 : 15).
- **Fichiers** : `StealAShop-Art/Items/Ajouts/` (`Ajouts_Objets.blend`, `.json`, `.fbx`, `FBX/`, `_scripts/ajouts_items.py`, `ajouts_studio_setup.luau`). Le script de rangement accepte maintenant des objets de plusieurs zones dans un même FBX.
- **Reste du plan** : zone 6 New York, puis le Secret (MOD-031).

## Zone 6 New York livrée et validée par Clément (2026-11-07, MOD-026 terminé)

- **12 modèles `ITM_Z6_*` dans `Workspace/_INBOX_CLEMENT`** : LingotDOr, SceptreRoyal, AigleDeCristal, PyramideDeLingots, SacDeDiamants, CoffreFortBlinde, DiamantGeant, TaureauEnOr, TroneEnOr, StatueDeLaLiberte, CoffreDeDiamants, CleDuCoffreUltime. Même contrat ; de 168 à 1 116 triangles.
- **Matières** : or mat `#F2C230` jusqu'à Peu commun, légèrement brillant en Rare, Foil pour le Coffre de diamants et la Clé ; Glass pour les diamants, le rubis et l'Aigle de cristal ; coffre-fort en Metal ; socle du taureau en Marble ; accents Neon des Épiques (gemme violette du Trône, flamme de la Statue de la Liberté).
- **Effets natifs** : `CoffreDeDiamants/Diamonds/Sparkles` (blanc, 5/s) et lumière dorée (Range 7) ; `CleDuCoffreUltime/Gold/Sparkles` (doré, 7/s) et lumière rouge rosé (Range 8), cœur Neon `#FF3B5C`.
- **Animation** : `Idle = "Bob"` sur `ITM_Z6_CoffreDeDiamants`, `Idle = "SpinBob"` sur `ITM_Z6_CleDuCoffreUltime` (pivot exactement sur l'axe de la clé).
- **Showroom** : ligne de la zone 6 à z = 471,5 ; plus aucun cube du catalogue v1 dans la rangée OBJETS (seul le Secret garde le sien).

## Le Secret livré et validé par Clément (2026-11-07, MOD-031 terminé)

- **`ITM_Secret_ChatPorteBonheurDore` dans `Workspace/_INBOX_CLEMENT`** : `ItemId = "Secret_ChatPorteBonheurDore"`, `Root` en PrimaryPart, pivot en bas au centre, aucun script ; 1 830 triangles (limite 4 000), 1,39 × 2,09 × 1,19 studs.
- **Pièces** : `Gold` (Foil `#FFC21A`), `Face` (`#1B1B24`), `Pink` (`#FF9EC7`), `Red` (coussin, collier, `#D7263D`), `Wave_Paw` (Foil `#FFC21A`), `Wave_PawPads` (`#FF9EC7`).
- **Effets natifs** : `Gold/Sparkles` arc-en-ciel (8/s) et lumière `#FFF2CC` devant le visage (`Root/LightPoint/Glow`, Range 9).
- **Animation, nouveau pour Ironix** : les pièces `Wave_*` forment la patte qui fait signe. Elles font un va-et-vient (pas une rotation continue) autour de l'axe Y de leur pivot, placé à l'épaule et orienté gauche-droite. Les deux pièces ont le même pivot et reçoivent le même angle. Calculer l'angle depuis la pose de départ, sans l'ajouter image après image, pour que la patte ne dérive pas :
  - garder une fois `rel = model:GetPivot():ToObjectSpace(part:GetPivot())` ;
  - puis à chaque image `part:PivotTo(model:GetPivot() * rel * CFrame.Angles(0, A * math.sin(w * t), 0))`.
  - Pas d'attribut `Idle` sur le chat.
- **Showroom** : `Show_ChatPorteBonheurDore` remplace le cube gris (x = −51, ligne de la zone 1). Étiquette « VALIDÉ · Secret · Toutes zones », remontée à 3,6 studs pour ne pas couper la tête.

## Bilan pour la session principale

- **83 objets livrés et validés** (13 + 16 + 14 + 15 + 12 + 12 + le Secret) : MOD-014, MOD-026 et MOD-031 terminés côté modèles.
- **Contrat d'animation idle proposé à Ironix** (à écrire dans la liaison s'il l'accepte), tout côté client, aucun script dans les modèles :
  - attribut `Idle` sur le modèle : `Bob` (rebond lent), `Spin` (rotation lente autour du pivot), `SpinBob` (les deux) ;
  - pièces `Spin_*` : rotation continue autour de l'axe Y de leur pivot (`part:PivotTo(part:GetPivot() * CFrame.Angles(0, dθ, 0))`) ;
  - pièces `Wave_*` : va-et-vient autour de l'axe Y de leur pivot (détail dans la section du Secret) ;
  - objets concernés : Peluche géante (Bob), Figurine holographique (`Spin_Figure`, `Spin_Ring`), PC gamer et Carte graphique en or (`Spin_Fan1` à `Spin_Fan3`), Couronne et Œuf en diamant (Spin), Masque ancien (Bob), Météorite (SpinBob), Coffre de diamants (Bob), Clé du coffre ultime (SpinBob), Chat porte-bonheur doré (`Wave_Paw`, `Wave_PawPads`).
- **Effets natifs déjà actifs sans code** : étincelles (ParticleEmitter), lumières (PointLight), vapeur du Pot de nouilles.
- **Rangement** : les modèles restés dans `_INBOX_CLEMENT` vont dans `ReplicatedStorage/Assets/Items` quand `Config/Items` passe au catalogue v2 (83 objets, `ExpectedCount` à 83).
