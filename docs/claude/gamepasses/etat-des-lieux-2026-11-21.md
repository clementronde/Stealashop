# Boutique Robux : état des lieux des gamepasses et produits (2026-11-21)

Agent `createur-gamepasses`. Lecture seule de `src/shared/Config/Monetization.luau`, `src/shared/Config/Boosts.luau`, `src/server/Services/MonetizationService.luau` et de la place DEV dans Studio (« Voler un magasin [DEV] », placeId 131580149465482). Rien modifié, rien enregistré.

**Rappels** : tout est coupé tant que `Features.RobuxShop = false` (MAJ 1). `Id = 0` = pas encore créé sur le Creator Hub (au nom du groupe). `Ready = false` = effet pas codé : ni affiché ni vendu, reçu refusé (`NotProcessedYet`). Prix = Partie 2, section 4 (sauf « V0 proposé, absent du doc »).

## 1. Gamepasses (achat unique) — onglet « Gamepasses »

| # | Clé | Nom (carte) | Effet (ligne de carte) | Valeurs de Config | Prix R$ | Id | Ready | Icône attendue | Couleur carte |
|---|---|---|---|---|---|---|---|---|---|
| 1 | `DoubleCash` | ×2 Cash | Doubles all your income | `Multiplier = 2` (sur tous les revenus, se multiplie avec le boost ×2 argent) | 449 | 0 | **true** | `UI_Icon_GP_x2Cash` | `45D63A` |
| 2 | `DoubleTraining` | ×2 Training | ×2 treadmill gains | `Multiplier = 2` (gains du tapis ; le banc n'existe plus en v2) | 299 | 0 | **true** | `UI_Icon_GP_x2Training` | `FF9A2E` |
| 3 | `VIP` | VIP | +10% income, aura, chat tag | aucune valeur en Config ; doc 4.1 : tag de chat, aura VIP, +10 % revenus, rideau +30 s (le +1 coffre-fort a été retiré, vague 54) | 249 | 0 | false | `UI_Icon_GP_VIP` | `8A5CF0` |
| 4 | `AutoCollect` | Auto Collect | Cash collects itself, anywhere | pas de valeur : la caisse se vide chaque seconde, où que soit le joueur | 199 | 0 | **true** | `UI_Icon_GP_AutoCollect` | `FFC928` |
| 5 | `FastOpen` | Fast Open | Anti-theft 2× shorter | `DelayFactor = 0.5` ; depuis la vague 52 il n'y a plus de colis posé : **ne raccourcit que l'antivol d'un objet posé au sol** | 299 | 0 | **true** | `UI_Icon_GP_FastOpen` | `2FA8F0` |
| 6 | `ExtraStands` | +4 Displays | 4 extra display stands | `Stands = 4` (`DisplaySlot_21` à `_24`, au-delà du maximum de 20) | 349 | 0 | **true** | `UI_Icon_GP_Displays` | `E05AD8` |
| 7 | `HydraulicGloves` | Hydraulic Gloves | Exclusive tool: 2.5× your best tool | aucune valeur en Config ; doc : puissance = 2,5 × meilleur outil acheté | 499 | 0 | false | `UI_Icon_GP_HydraulicGloves` | — (celle du Template) |

Bonus hors boutique : **Roblox Premium** = +10 % de revenus (`Premium.IncomeBonus = 0.1`), codé.

## 2. Produits développeur (achat répétable)

### Onglet « Offers » (bannière `Featured`)

| Clé | Nom | Effet | Valeurs | Prix R$ | Id | Ready | Icône |
|---|---|---|---|---|---|---|---|
| `StarterPack` | Starter Pack | ×2 Cash 1h + Hammer + $2.6K | 1re heure de jeu (`Window = 3600`), boost ×2 argent 3600 s, `Tool = "Hammer"`, `Cash = 2 600` (V0 de Cantin du 20/11 ; doc : 50 000 $), `OldPrice = 399` (V0) | 99 | 0 | **true** | `UI_Icon_DP_StarterPack` |

### Onglet « Cash »

| Clé | Nom | Minutes | Prix R$ | R$/min | Id | Ready | Icône | Source |
|---|---|---|---|---|---|---|---|---|
| `Cash10` | 10 Minutes of Cash | 10 | 49 | 4,9 | 0 | true | `UI_Icon_DP_Cash_1` | doc |
| `Cash30` | 30 Minutes of Cash | 30 | 129 | 4,3 | 0 | true | `UI_Icon_DP_Cash_2` | V0 |
| `Cash60` | 1 Hour of Cash | 60 | 199 | 3,3 | 0 | true | `UI_Icon_DP_Cash_3` | doc |
| `Cash180` | 3 Hours of Cash | 180 | 499 | 2,8 | 0 | true | `UI_Icon_DP_Cash_4` | V0 |
| `Cash300` | 5 Hours of Cash | 300 | 799 | 2,7 | 0 | true | `UI_Icon_DP_Cash_5` | doc |
| `Cash720` | 12 Hours of Cash | 720 | 1 599 | 2,2 | 0 | true | `UI_Icon_DP_Cash_6` | V0 |

Montant = revenu actuel (bonus compris) × minutes, au moins `CashPacks.MinPerMinute = 50` $ par minute.

### Onglet « Boosts »

| Ordre | Clé | Nom | Effet | Valeurs | Prix R$ | Id | Ready | Icône |
|---|---|---|---|---|---|---|---|---|
| 1 | `SpeedBoost` (Config/Boosts) | ×2 Speed | ×2 speed on the treadmill | `Multiplier = 2`, 600 s, max 3 600 s, cumul avec ×2 Training (×4) — tout V0 | 29 | 0 | false | `UI_Icon_SpeedBoost` |
| 2 | `SleepGuards` (Config/Boosts) | Sleeping Guards 60s (HUD : « zZz ») | Guards & police sleep 60 s | 60 s, tout le serveur, vigiles + vigiles de nuit + police, recharge serveur 300 s — tout V0 | 79 | 0 | false | `UI_Icon_Sleep` |
| 3 | `OpenNow` | Open Now | Unlock now | 4 paliers (un produit chacun) : 19 R$ ≤ 60 s, 39 R$ ≤ 180 s, 59 R$ ≤ 480 s, 99 R$ ≤ 900 s ; pas proposé sous 10 s (V0) | 19 → 99 | 0 ×4 | true | `UI_Icon_DP_OpenNow` |
| 4 | `Revenge` | Revenge | Teleport behind your thief | règle pas écrite | 25 | 0 | false | `UI_Icon_DP_Revenge` |
| 5 | `InstantShutter` | Instant Shutter | Close your shop right now | MAJ 2 | 29 | 0 | false | `UI_Icon_DP_InstantShutter` |
| 6 | `Luck3` | ×3 Luck | Rarer boxes for 15 min | cotes à afficher, caché si `ArePaidRandomItemsRestricted` | 79 | 0 | false | `UI_Icon_DP_Luck3` |
| 7 | `Shield30` | 30 Min Shield | Nobody can rob your shop | une fois par session, règle pas écrite | 99 | 0 | false | `UI_Icon_DP_Shield30` |
| 8 | `ServerLuck2` | ×2 Server Luck | ×2 luck for the whole server, 15 min | `Luck = 2`, 15 min (V0) | 149 | 0 | `SERVER_LUCK` = false | `UI_Icon_DP_Luck3` (partagée) |
| 9 | `ServerLuck4` | ×4 Server Luck | idem ×4 | `Luck = 4`, 15 min (V0) | 399 | 0 | false | `UI_Icon_DP_Luck3` |
| 10 | `ServerLuck8` | ×8 Server Luck | idem ×8 | `Luck = 8`, 15 min (V0) | 999 | 0 | false | `UI_Icon_DP_Luck3` |

### Caisse exclusive (`Crate`, derrière `Features.RobuxCrate = false`)

1 caisse 99 R$, 3 pour 249, 10 pour 799 (décision de Clément du 16/11) ; chances V0 45 / 28 / 15 / 7 / 4 / 1 % ; `Ready = false`, Id = 0 ×3. Hors périmètre gamepasses (pas d'icône `GP`/`DP`).

## 3. Icônes dans Studio (lecture seule)

**Toutes les icônes attendues existent** : un `Decal` par nom dans `ReplicatedStorage/Assets/Icons`, chacun avec une image.

| Icône | Image (Decal) | Utilisée dans `UI_RobuxShop_v2` |
|---|---|---|
| `UI_Icon_GP_x2Cash` | rbxassetid://90748953656553 | Gamepasses `Template`, `Preview_1`, `Featured.Perks.Perk1` |
| `UI_Icon_GP_x2Training` | rbxassetid://106315635775683 | `Preview_2` |
| `UI_Icon_GP_AutoCollect` | rbxassetid://104046420442482 | `Preview_3` |
| `UI_Icon_GP_FastOpen` | rbxassetid://96887942138631 | `Preview_4` |
| `UI_Icon_GP_Displays` | rbxassetid://73166344877661 | `Preview_5` (+ bouton `Displays` du HUD) |
| `UI_Icon_GP_VIP` | rbxassetid://74312993351317 | `Preview_6` |
| `UI_Icon_GP_HydraulicGloves` | rbxassetid://95039189664067 | seulement dans une ancienne sauvegarde de l'écran |
| `UI_Icon_SpeedBoost` | rbxassetid://114903617420676 | Boosts `Preview_1` |
| `UI_Icon_Sleep` | rbxassetid://81902433249804 | Boosts `Preview_2` |
| `UI_Icon_DP_OpenNow` | rbxassetid://135335375478952 | Boosts `Preview_3`, `Featured.Timer` |
| `UI_Icon_DP_Luck3` | rbxassetid://86703854115395 | Boosts `Preview_4` (carte « SERVER LUCK ») |
| `UI_Icon_DP_StarterPack` | rbxassetid://134605812442314 | `Featured.Icon` |
| `UI_Icon_DP_Cash_1` … `_6` | 137831162447641 / 107818570357492 / 101929982691500 / 121831594993702 / 103564967498534 / 86676020914512 | Cash `Preview_1` à `_3` (= Cash_1, _3, _5) |
| `UI_Icon_DP_Revenge`, `_InstantShutter`, `_Shield30` | 109184638398125 / 122784522108032 / 102177562046868 | seulement dans d'anciennes sauvegardes |

Les vignettes de ces images ne sont pas lisibles de l'extérieur (images du groupe) et aucun fichier source n'est dans le dépôt : je n'ai pas pu les regarder une à une. Le style vu en jeu (bouton `Displays` du HUD) est un **rendu 3D brillant, contour sombre**, cohérent avec les boutons Shop / Index / Upgrades.

## 4. Écarts relevés

1. **Ordre des cartes** : Config met VIP en 3e (`Order = 3`) ; la maquette dans Studio le met en **6e** (×2 Cash, ×2 Training, Auto Collect, Fast Open, +4 Displays, VIP). À trancher par Clément ; le code devra suivre.
2. **Fast Open** : la ligne « Anti-theft 2× shorter » est juste depuis la vague 52, mais le nom « Fast Open » ne correspond plus vraiment (on n'ouvre plus de colis posé ; il raccourcit l'antivol d'un objet posé au sol). À revoir dans la fiche.
3. **×2 Training** : le doc 4.1 dit « tapis et banc », mais le banc a disparu en v2 ; Config et la carte disent bien « treadmill ».
4. **Starter Pack** : le doc dit 50 000 $, Config 2 600 $ (V0 de Cantin du 20/11, revenus remis à l'échelle). Le doc partagé est à mettre à jour.
5. **Packs d'argent** : seulement 3 cartes dans la maquette (Cash_1, _3, _5) pour 6 produits en Config (la grille est clonée depuis `Template` en jeu, donc normal).
6. **Server Luck** partage l'icône `UI_Icon_DP_Luck3` avec `Luck3` (choix assumé tant que `Luck3` n'est pas en vente).
7. **+4 Displays ne donne rien aujourd'hui** : vérifié dans Studio, aucune parcelle (`PLOT_Shop_01` à `_06`, le modèle `ReplicatedStorage/Assets/Plots/PLOT_Shop` et les greybox) n'a `DisplaySlot_21` à `_24` ; le maximum est 20 partout. Le code est prêt (`Ready = true`) mais le gamepass ne doit pas être vendu tant que Clément n'a pas posé ces 4 présentoirs (avec leurs `CollectPad_21` à `_24` si le code les attend).
8. **Gamepasses vendables dès la MAJ 1** (Ready = true) : ×2 Cash, ×2 Training, Auto Collect, Fast Open, +4 Displays. Pas encore : VIP, Hydraulic Gloves.
