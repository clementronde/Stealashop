# Images des offres et des badges (L-352), validées par Clément le 26/11

23 images de 512 × 512 :
- 6 gamepasses `UI_Icon_GP_*` ;
- 8 produits `UI_Icon_DP_*` (Open Now : une image pour ses 4 paliers) ;
- 9 badges `BADGE_*`.

Planche : `PLANCHE_offres_completes.png`. Fabrication : `_src/build_offres.py`.

Rien n'est publié tant que Clément ne lance pas lui-même les commandes ci-dessous. **Jamais rien en PROD sans son accord explicite.**

## 1. Mettre les images en ligne (Decals du groupe)
Clé API du groupe RoundStone Studio (207192094), avec l'API Assets en lecture et en écriture. Elle se tape au lancement, ne s'affiche pas et ne s'enregistre nulle part.

Essai sur une seule image :
```powershell
pwsh -File C:\Users\Charment\Documents\Stealashop\tools\clement\publier_icones_offres.ps1 -Limite 1
```
Puis le reste :
```powershell
pwsh -File C:\Users\Charment\Documents\Stealashop\tools\clement\publier_icones_offres.ps1
```
- **Le CSV** : les ID sont notés dans `icones_offres_ids.csv`, dans ce dossier. Le script est rejouable : ce qui est publié est sauté.
- **Le script de Studio** : à la fin, le script écrit `poser_decals_offres.luau`.

## 2. Dans le jeu (Studio, en Edit)
- **Lancer le fichier** : coller `poser_decals_offres.luau` dans la barre de commande de Studio, en Edit.
- **Les Decals existants** de `ReplicatedStorage/Assets/Icons` reçoivent la nouvelle image : `UI_Icon_GP_x2Cash`, `x2Training`, `AutoCollect`, `FastOpen`, `Displays`, `UI_Icon_DP_StarterPack`, `Cash_1` à `Cash_6`, `OpenNow`.
  - Ils ne sont jamais renommés ni supprimés.
  - L'ancienne image reste dans l'attribut `TextureAvant`, pour revenir en arrière.
- **Un seul Decal est créé** : `UI_Icon_GP_DoubleSpeed`, dans le même dossier. Le ×2 Speed lit aujourd'hui `UI_Icon_SpeedBoost` (le bouton x2 SPEED du HUD) : Cantin dit si la carte de la boutique prend la nouvelle image.
- **Les `BADGE_*` ne vont pas dans le jeu** : le code ne les lit pas.
- **Pour finir** : `save_place`, puis une ligne dans `docs/claude/journal-studio.md`.

## 3. Creator Hub : gamepasses et produits, par Open Cloud
Doc à jour (create.roblox.com/docs/cloud/reference/features/game-passes.md et developer-products.md, mises à jour le 24/11/2026) :
- **gamepass** : `PATCH /game-passes/v1/universes/{universeId}/game-passes/{gamePassId}`, champ `imageFile`, scope `game-pass:write` ;
- **produit** : `PATCH /developer-products/v2/universes/{universeId}/developer-products/{productId}`, champ `imageFile`, scope `developer-product:write`.

Les deux API sont en BETA. Seule l'image est envoyée : le nom, le prix et la mise en vente ne bougent pas.

**La clé** se crée sur le Creator Hub : Open Cloud > API Keys, au nom du groupe. Elle a les scopes `game-pass:write` et `developer-product:write`, sur le jeu DEV (10774974820) et, plus tard, sur PROD (10774998269).

Voir ce qui serait fait, sans rien envoyer :
```powershell
pwsh -File C:\Users\Charment\Documents\Stealashop\tools\clement\poser_icones_creator_hub.ps1 -Jeu DEV -Essai
```
DEV d'abord (17 offres : 6 gamepasses, 11 produits) :
```powershell
pwsh -File C:\Users\Charment\Documents\Stealashop\tools\clement\poser_icones_creator_hub.ps1 -Jeu DEV
```
PROD, seulement avec l'accord de Clément. Le script demande de taper `OUI PROD` :
```powershell
pwsh -File C:\Users\Charment\Documents\Stealashop\tools\clement\poser_icones_creator_hub.ps1 -Jeu PROD
```
Le journal va dans `creator_hub_dev.csv` ou `creator_hub_prod.csv`. Rejouable.

**Sans clé** : à la main, sur le Creator Hub. Pour chaque jeu, aller dans Monétisation > Gamepasses (ou Produits développeur), ouvrir l'offre, changer l'image et enregistrer. Le fichier de chaque offre est dans le tableau de `poser_icones_creator_hub.ps1`.

## 4. Creator Hub : badges, à la main
Aucune API ne change l'image principale d'un badge : celle d'Open Cloud ne traite que les traductions, et refuse la langue d'origine. Il faut donc passer par le site.

1. Creator Hub > Creations > groupe RoundStone Studio > le jeu (DEV d'abord, PROD ensuite avec l'accord de Clément).
2. Engagement > Badges > le badge.
3. Changer l'image, puis enregistrer.

Changer l'image d'un badge existant ne crée pas de badge.

| Image | Badge (nom sur le Hub) | Id PROD | Id DEV |
| --- | --- | --- | --- |
| `BADGE_Welcome.png` | Welcome to the Street | 734742039332229 | 1421862584260439 |
| `BADGE_FirstHeist.png` | First Heist | 1996896044857741 | 1899748846610750 |
| `BADGE_FirstSteal.png` | Sneaky Thief | 3089515347599975 | 853103740412758 |
| `BADGE_Legendary.png` | Legendary Loot | 2192011030479327 | 3461348261333770 |
| `BADGE_Mythic.png` | Mythic Find | 4412861862965984 | 3741634080661251 |
| `BADGE_Secret.png` | Secret Finder | 12482347170482 | 1046738162941963 |
| `BADGE_Zone6.png` | End of the Street | 2376081713577200 | 1615804164972793 |
| `BADGE_Reborn.png` | Reborn | 3486392182556727 | 1191932509312544 |
| `BADGE_Millionaire.png` | Millionaire Shop | 1297138662347094 | 2825808733331096 |

Les Ids viennent de `Config/Badges` (origin/main du 26/11). Pour vérifier un badge : roblox.com/badges/<Id>.

## Ajout du 26/11 au soir : ×4 Training (24e image, à valider par Clément avant la mise en ligne)
- **Le fichier** : `UI_Icon_GP_x4Training.png`. C'est la proposition du 21/11 (`../UI_Icon_GP_x4Training.png` : même sceau et même basket que le ×2 Training, orange un peu plus foncé, une étincelle), réduite à 91 % pour que le « ×4 » tienne dans le cercle de Roblox.
- **Pourquoi** : avec `TrainingX4Dev`, le gamepass donne ×4 dans le jeu DEV, mais la carte affiche encore le ×2. En PROD, à la sortie, c'est ×2 (`TrainingX4` coupé).
- **Mise en ligne**, avec Clément, en même temps que les badges :
  1. `publier_icones_offres.ps1` : il ne publie que cette nouvelle image, les 23 autres sont déjà dans le CSV. Il récrit ensuite `poser_decals_offres.luau`.
  2. Le Luau dans Studio, en Edit : il crée le Decal `UI_Icon_GP_x4Training` dans `Assets/Icons` (les autres ne changent pas).
  3. Le Creator Hub du jeu DEV :
     ```powershell
     pwsh -File C:\Users\Charment\Documents\Stealashop\tools\clement\poser_icones_creator_hub.ps1 -Jeu DEV -Refaire DoubleTraining
     ```
     Le script prend l'image ×4 pour DEV (`ImageDEV`). PROD garde le ×2.
- **Pour Cantin** : que la carte lise `UI_Icon_GP_x4Training` quand `TrainingX4` est allumé (`Icon` de DoubleTraining dans `Config/Monetization`).

## À savoir
- **Quick Lock vide en Play (26/11)** : son Decal (137953885056000) et son image (89208667413264) sont « Approved » et « Active » chez Roblox. Le Decal d'`Assets/Icons` pointe bien vers cette image, et elle se charge en Studio. Le Play a sans doute eu lieu pendant que Roblox préparait encore l'image (« Asset content representation is being generated », vu juste après la mise en ligne). À revoir au prochain Play.
- **Les ×2 Cash et ×2 Training** existants débordent un peu du cercle de Roblox : leur « ×2 » est un peu rogné. On peut les recadrer d'environ 6 %, si Clément le veut.
