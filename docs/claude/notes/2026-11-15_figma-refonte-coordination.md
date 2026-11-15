# Refonte UI dans Figma : coordination des 4 sessions (2026-11-15)

Fichier Figma : « Steal a Shop — UI », fileKey `fXjkvf39sRhlsL94YicwDH`.

## Qui possède quelle page (ne jamais modifier la page d'une autre session)

| Session | Pages |
| --- | --- |
| figma-briques | `Old` (anciens écrans), `00 Briques` (composants communs, fiche des animations) |
| figma-boutiques | `10 Boutiques` (armes, auras, Robux, diamants) |
| figma-index-exposes | `20 Index et Exposés` |
| figma-hud-tapis-poursuite | `30 HUD, tapis, poursuite` |

## Composants communs (rempli par figma-briques)

Les autres sessions utilisent les composants de `00 Briques` dès qu'ils sont publiés ici. Avant, elles font des brouillons locaux et les remplacent ensuite.

| Composant | Node id | État |
| --- | --- | --- |
| `Title` (Variant = Fenetre, Petit, Badge) : titre en relief | 105:379 | Validé par Clément (2026-11-15) |
| `Btn` (Kind = Principal, Secondaire, Robux, Argent, Diamants × State = Normal, Survol, Appuye, Desactive ; booléen Badge) | 105:490 | Validé par Clément (2026-11-15) |
| `Btn_Close` (State = Normal, Survol, Appuye) | 105:500 | Validé par Clément (2026-11-15) |
| `Icon_Diamond` (icône provisoire des diamants) | 105:382 | Provisoire |
| `Tag_Rarity` (Rarity = Common … Secret, Divine) ; images clés à côté (105:655) | 105:654 | Validé par Clément (2026-11-15) |
| `Card_Item` (Rarity × State = Normal, Survol, Verrouille ; prix = instance de `Btn`, passer en Desactive si trop cher) | 106:1263 | Validé par Clément (2026-11-15) |
| `Tab` (State = Actif, Inactif, Survol) | 106:1447 | Validé par Clément (2026-11-15) |
| `Window` (Header = Vert, Bleu, Orange, Violet ; booléen Onglets ; Title, CloseButton, Content, Tabs) | 106:1540 | Validé par Clément (2026-11-15) |
| Fiche des animations (tableau Appear / Hover / Press, images clés) | 106:2755 | Fait |
| Exemple monté 1920 × 1080 (pas un écran du jeu) | 106:4183 | Fait |

Notes d'usage : base d'écran 1920 × 1080 ; textes du jeu en anglais ; Montserrat Black, contour `#1B1B24` ; studs en `OVERLAY` (hash `d3778b89…`). Les états Survol et Appuyé de `Btn` sont plus grands ou plus petits : dans les maquettes d'écran, poser `State=Normal`. Robux en violet pour ne pas se confondre avec le prix en argent vert (validé par Clément).

## Journal (une ligne par session à chaque étape)

- figma-briques : pages `00 Briques` (103:1404) et `Old` (103:1405) créées. Dans `Old` : inventaire (v1, v3, assets), ancienne barre du bas, HUD+barre inventaire, receleur v1, index v1 (`UI_Index — zone 1`), arbre v1 en lignes, et les composants Slot_Hotbar, Card_Inventory*, SkillNode, Card_IndexItem (section 103:1408). Les icônes `Icon_*` restent sur `Boutique` (l'arbre hexagonal s'en sert). `UI_Unbox`, `UI_Index_v2`, `UI_SkillTree_v2_old` n'existent que dans Studio, pas dans Figma.

- figma-boutiques : page `10 Boutiques` (103:1415) créée. Images des boutiques (armes, auras, trails, rayons) importées sur cette page seulement.

- figma-briques : Clément a validé les briques de `00 Briques` (2026-11-15). Les autres sessions peuvent remplacer leurs brouillons par ces composants.
- figma-index-exposes : page `20 Index et Exposés` (103:1409) créée. Brouillons locaux (aucun composant de `00 Briques` publié à cette heure) : `UI_Index v4` PC (105:507) et téléphone (106:369), `UI_Displayed` PC (106:1279) et téléphone (106:2677), 3 bandes d'images clés (106:7160 ouverture de l'index, 106:9566 survol/clic/récompense, 106:9700 glissement du panneau), cadres des noms (106:11389, 106:11405). 26 icônes `ICON_*` importées (cadre 103:1453 ; hachages réutilisables). En attente des retours de Clément.

### Noms pour la liaison (figma-index-exposes, à valider par Clément)

- **UI_Index (v4)**, gardés de la v3 : `Window`, `Header.Title`, `CloseButton.XLabel`, `UnlockedBar` (`BookIcon`, `Counter`), `ZoneArt.ZoneName`, `ZoneBar` (`Fill`, `ZoneCount`), `Tabs` (`Zone1Tab`…`Zone6Tab`, `SecretsTab` : `TabIcon`, `TabLabel`, `Selected`), carte `Template` (`Clip`, `Rays`, `Icon`, `ItemName`, `HoverOutline`), pastilles `ClaimAlert` et `ZoneAlert` (cette dernière passe sur `Zone<N>Tab`).
- **UI_Index (v4)**, nouveaux : `Cards` (grille 4 × 2), `Footer.Pager` (`PrevButton`, `NextButton`, `PageLabel`), `ZoneArt.ZoneTheme`, `Footer.ClaimButton` (`RewardIcon`, `RewardCaption`, `ClaimAlert`), `Clip.Shine`, `Clip.RarityGradient`.
- **UI_Index (v4)**, retirés (à confirmer) : `ListPanel.List`, `Zone<N>Section`, `Detail`, `Rewards`, `Categories`, `MutationTabs`, `MutationCaption`, `ZoneItem`.
- **UI_Displayed** (nom à confirmer), tout nouveau : `OpenButton` (`OpenIcon`, `OpenLabel`, `OpenCount.OpenCountLabel`), `CloseButton`, `Panel` (`Header.Title`, `DisplayCount` (`CountIcon`, `CountLabel`), `List.Template` (`IconBack`, `Icon`, `RarityChip.RarityLabel`, `ItemName`, `Income`, `RemoveButton.RemoveLabel`)), `DisplayBestButton.DisplayBestLabel`.
- Attributs d'animation (L-182) : `Window` Pop ; `Cards`, `Tabs`, `List` Cascade ; `Template` Hover Pop + Press Squash ; `Panel` SlideRight ; `DisplayBestButton` Stamp.
- Pour la session HUD (page 30) : `UI_Displayed.OpenButton` occupe le bord droit au milieu de la hauteur (PC : 100 × 100 à 24 px du bord ; téléphone : 56 × 56). Si le HUD veut le porter lui-même, le dire ici.

- figma-hud-tapis-poursuite : page `30 HUD, tapis, poursuite` (103:1428) faite, en attente des retours de Clément. 9 états PC 1920 × 1080 + téléphone 844 × 390, avec leurs bandes d'images clés : 1 repos (106:557), 2 menu More (106:1621), 3 tapis (106:2070), 4 couloir zZz (106:2993), 5 après achat (106:3458), 6 poursuite (106:5046), 7 zone safe (106:6010), 8 barre du bas (106:10453), 9 noms (106:10614). Briques utilisées : studs `OVERLAY`, contour `#1B1B24`, violet Robux, durées de la fiche des animations. Icônes importées sur cette page seulement (`_Icônes importées`). Captures : `StealAShop-Art/Captures/2026-11-15_Figma_HUD/`.

## Noms nouveaux ou déplacés (page 30, à ajouter au contrat 2.2 après accord)

| Écran | Nom | Rôle |
| --- | --- | --- |
| `UI_HUD` | `MenuButton` (+ `MenuAlert`) | 3e bouton de `LeftRail` et `LeftRailTouch` (après `RobuxShopButton` et `SkillTreeButton`) ; ouvre `MenuPanel` ; `MenuAlert` allumé si une alerte du menu l'est |
| `UI_HUD` | `MenuPanel` | Frame caché ; contient `IndexButton`, `RebirthButton`, `RewardsButton`, `InviteButton`, `SettingsButton` (déplacés, mêmes noms) ; `SocialRow` disparaît |
| `UI_HUD` | `RightRail` | Frame à droite, mi-hauteur ; porte `DisplayedButton` et les boutons en situation |
| `UI_HUD` | `DisplayedButton` | ouvre « Mes objets exposés » (`UI_Displayed`, nom à confirmer) |
| `UI_HUD` | `SpeedBoostButton` (+ `Label`, `Price.Amount`) | caché, montré sur un tapis (Robux « x2 vitesse ») |
| `UI_HUD` | `SleepButton` (+ `Label`, `Hint`, `Price.Amount`, `Cooldown`) | caché, montré dans le couloir (« zZz » 60 s) |
| `UI_HUD` | `CashSpent` | TextLabel rouge caché, montré après un achat. Pas de diamants dans le HUD (décision de Clément, 2026-11-15) : leur solde n'est que dans la boutique de diamants |
| `UI_HUD` | `InventoryButton`, `InventoryAlert` | retirés (inventaire archivé) |
| `UI_HUD` | `BottomRow` | passe au-dessus des chiffres (l'argent reste tout en bas) ; `HeistTimer` passe en bas à droite au-dessus de `NightCountdown` ; `DropButton` (déjà lu par DropController) montré en poursuite, aussi sur PC |
| `BB_Gain` | `Amount`, `Icon` | billboard du « +X » du tapis (nom de la fiche B, à confirmer par Ironix) |
- figma-boutiques (2026-11-15) : les 4 écrans de `10 Boutiques` sont posés, PC 1920×1080 + téléphone 844×390, chacun avec une bande d'images clés (cascade d'ouverture, survol, appui) et un panneau des noms. Sections : `UI_WeaponShop` (106:3830), `UI_AuraShop` (106:10750), `UI_RobuxShop` (108:2539), `UI_DiamondShop (nouvel écran)` (111:5169). Brouillons locaux, à remplacer par les briques dès qu'elles sont ici : section 106:486 (`Draft/ShopCard_PC` 106:487, `Draft/ShopCard_Phone` 106:521, `Draft/RobuxCard_PC` 108:2501, `Draft/RobuxCard_Phone` 108:2520, `Draft/DecorCard_PC` 111:5125, `Draft/DiamondPack_Phone` 111:5157, `Draft/DiamondIcon` 111:5112). En attente des retours de Clément.

### Nouveaux noms des boutiques, pour la liaison (figma-boutiques)

- `UI_WeaponShop` : aucun nouveau nom (contrat 2.2 + noms de L-176 gardés).
- `UI_AuraShop` : aucun nouveau nom.
- `UI_RobuxShop` (offre vedette en tête) : `Root.Featured`, avec `Featured.Icon`, `Featured.ItemName`, `Featured.Subtitle`, `Featured.Perks.Perk1` à `Perk3` (chacun `Icon` + `Label`), `Featured.Timer.Label` (fin de l'offre, attribut `StarterPackEndsAt`), `Featured.BuyButton.Content.Price`. Nouveaux produits dans l'onglet Boosts : « ×2 Speed » et « zZz » (prix, Id et règles à proposer par Ironix). Icônes à faire : `UI_Icon_DP_x2Speed`, `UI_Icon_DP_Sleep`.
- `UI_DiamondShop` (écran nouveau) : `Root`, `Header.Title`, `CloseButton`, `Balance` (`Icon`, `Amount`), `AddButton`, `Tabs.GetDiamondsTab`, `Tabs.CustomizeTab` (`Icon`, `Label`) ; onglet Diamonds : `PacksList` (ScrollingFrame), `PacksList.Template` (`Icon`, `Amount`, `BuyButton.Content.RobuxIcon`, `BuyButton.Content.Price`) ; onglet My Shop : `ShopPreview` (ViewportFrame), `Categories.Template` (`Label`, `Selected`), `CatalogList` (ScrollingFrame), `CatalogList.Template` (`Preview`, `ItemName`, `BuyButton.Content.DiamondIcon`, `BuyButton.Content.Price`, `ApplyButton`, `Applied`). Images à faire : `UI_Icon_Diamond`, `UI_Icon_DiamondPack_1` à `_4`. Contenus et prix : à définir.
- figma-boutiques (2026-11-15, suite) : **solde de diamants** (décision de Clément : il ne s'affiche que dans `UI_DiamondShop`, il sort du HUD). Dans `UI_DiamondShop`, `Header.Balance` est agrandi et mis en avant (pastille sombre avec halo, à côté de `AddButton`), avec `Balance.Icon`, `Balance.Amount` (le solde, qui décompte après un achat : 1,9 s, Quint Out) et `Balance.Spent` (nouveau : le montant dépensé, « −X » en rouge, caché au repos ; il apparaît en 0,2 s, reste 1 s, puis monte et s'efface en 0,3 s). Ces 3 états sont montrés en gros plan dans la bande de l'écran. Vérifié : aucun prix ni icône en diamants dans `UI_WeaponShop`, `UI_AuraShop` ni `UI_RobuxShop` ($ du jeu et Robux seulement). Pour figma-hud-tapis-poursuite : pas de compteur de diamants dans le HUD.
- figma-boutiques (2026-11-15, demande de Clément) : images des auras et des traînées **bien plus grosses** (≈ 1,2 × `IconArea`, elles débordent sous le nom et touchent la bande du bonus). Nouvelles variantes de brouillon : `Draft/ShopCard_Aura_PC` (115:4708) et `Draft/ShopCard_Aura_Phone` (115:4742). Les armes gardent leur taille.
- figma-boutiques (2026-11-15, demande de Clément) : **`UI_RobuxShop` v2**, tout défile de haut en bas (plus rien à l'horizontale). Remplace les noms Robux donnés plus haut. Structure : `List` (ScrollingFrame vertical) › `Content` (UIListLayout) avec, dans l'ordre, `Crate`, `Featured` (Starter Pack, noms inchangés), `GamepassesSection`, `BoostsSection`, `CashSection` (chacune `Header.Label` + `Grid` avec `Template`). Les onglets de droite (`Tabs.OffersTab`… gardés) font défiler jusqu'à leur section au lieu de filtrer. **Nouveau, la caisse exclusive en tête** : `Crate.Icon`, `Crate.ItemName`, `Crate.Subtitle`, `Crate.Odds` (une case par objet : `Fill`, `Rays`, `Icon`, `Chance`), `Crate.BuyRow.BuyButton1` à `BuyButton3` (`Content.Count`, `Content.RobuxIcon`, `Content.Price`), `Crate.OddsNote`. À définir : objets exclusifs (images d'exemple prises dans les zones 4 à 6), chances, prix, nombre de caisses par bouton (×1, ×3, ×10 proposés). Règle Roblox : chances affichées avant l'achat, caisse cachée si `PolicyService` renvoie `ArePaidRandomItemsRestricted` ; la Partie 2, section 4 (« pas de colis contre Robux ») est à mettre à jour.

- figma-hud-tapis-poursuite : Clément a validé la page `30 HUD, tapis, poursuite` (2026-11-15). Après ses retours : pas de diamants dans le HUD (solde seulement dans la boutique de diamants), la force (`Strength`) reste. Prix et règles de « x2 SPEED » et « zZz » à proposer par Ironix (L-182, point 7) ; couleur du flash de zone safe (or `#FFC93A`) et Index rangé dans More gardés tels quels.

## Images à générer (figma-hud)

Seulement là où l'icône actuelle est générique ou reprise d'un autre écran. Toutes : PNG 512 × 512, fond transparent, objet seul centré avec 6 % de marge, contour sombre épais `#1B1B24`, ombrage toon à 2 tons, vu de face légèrement de 3/4, sans texte ni chiffre (le texte reste dans les `Label`). Affichées à environ 77 px sur PC et 40 px sur téléphone : la silhouette doit se lire petite.

| Fichier | Élément | Ce qu'elle montre | Pourquoi |
| --- | --- | --- | --- |
| `UI_Icon_Upgrades` | `SkillTreeButton` (rail gauche) | Une clé à molette croisée avec une flèche qui monte, verte et dorée | Les chevrons verts actuels font gabarit |
| `UI_Icon_Displays` | `DisplayedButton` (« Mes objets exposés ») | Un petit présentoir de boutique en verre avec un objet brillant dessus, éclat doré | L'icône actuelle est une caisse orange reprise des gamepasses |
| `UI_Icon_SpeedBoost` | `SpeedBoostButton` (« x2 SPEED ») | Une basket rose et bleue avec des traits de vitesse et une petite flamme derrière | L'actuelle est l'icône du gamepass x2 entraînement, avec un « x2 » déjà dessiné qui double le texte |
| `UI_Icon_Sleep` | `SleepButton` (« zZz ») | Une casquette de vigile posée de travers sur un oreiller, bulles « z » en forme de nuage (sans lettres lisibles) | La lune actuelle est celle de la nuit : on confond les deux |
| `UI_Icon_Drop` | `DropButton` (poursuite) | Une main ouverte qui lâche une caisse, petite flèche vers le bas | DROP n'a aucune icône aujourd'hui |

Une fois livrées : import dans `ReplicatedStorage/Assets/Icons` au nom du groupe, puis remplacement dans la page `30 HUD, tapis, poursuite`.
- figma-index-exposes : Clément a validé `UI_Index v4` et `UI_Displayed` (2026-11-15). Écrans refaits ensuite sur les briques validées, sans changer la mise en page ni les noms : Index = instance `Window` (Bleu, sans onglets) + `Title` + `Btn_Close` + `Btn` Secondaire (flèches) + `Tab` (zones) ; Displayed = `Title` Petit + `Btn_Close` + `Btn` Principal + `Tag_Rarity`, fond et en-tête repris de `Window` Orange. Bandes refaites : 126:460, 126:1226, 126:1344. Seul `RemoveButton` (rouge) reste local : pas de bouton rouge dans `Btn`. Questions encore ouvertes pour Clément : nom `UI_Displayed`, retrait de la fiche Detail / Categories / Mutations, récompense de zone (le code a +5 % revenus, +3 % vitesse, prime), `OpenButton` dans `UI_Displayed` ou dans `UI_HUD`.

## Images à générer (figma-index-exposes)

Seulement ce qui change vraiment le rendu. Rien à reprendre du jeu de référence : nos magasins, nos objets, notre style (Roblox « studs », ombrage toon à 2 tons, contour sombre `#1B1B24`). Aucun texte lisible dans les images (enseignes en formes ou pictogrammes) : les noms restent dans `ZoneName` et `ZoneTheme`.

### 1. Illustrations de zone de l'index (prioritaire, prompts écrits)

`ZoneArt` de chaque `Zone<N>Section` de `UI_Index` : colonne à gauche des cartes, 170 px de large sur PC et haute comme la section (484 px pour 3 rangées de cartes, 624 px pour 4). **À générer en portrait 1024 × 1536, fond plein.** Dans le jeu : `ScaleType = Crop`, centré : on ne voit que la bande du milieu (environ 40 % de la largeur), d'où une composition très verticale. Fichiers `UI_ZoneArt_Z1` à `UI_ZoneArt_Z6`, PNG, recadrés à 512 × 1024 avant l'import (rapport 1:2) au nom du groupe. Joindre au prompt une capture du quartier dans le jeu quand il y en a une (`StealAShop-Art/Captures/`), pour rester fidèle à nos magasins.

Début commun à coller avant chaque sujet :

> Illustration verticale pour l'interface d'un jeu Roblox, format portrait 1024 × 1536. Rendu 3D stylisé façon Roblox : formes simples et épaisses, texture de studs discrète sur les surfaces, couleurs vives et saturées, lumière douce de fin d'après-midi, léger voile atmosphérique au fond. Composition très verticale : tout ce qui compte tient dans une bande centrale large de 40 % de l'image, du ciel en haut jusqu'au trottoir en bas ; les côtés gauche et droit seront coupés. Aucun personnage, aucun texte, aucune lettre, aucun chiffre ni logo (les enseignes sont des formes et des pictogrammes). Pas de cadre ni de bordure.

| Fichier | Zone | Sujet à ajouter après le début commun |
| --- | --- | --- |
| `UI_ZoneArt_Z1` | 1 · Mini Mart | Une petite supérette de quartier vue de face : vitrine éclairée pleine de canettes, de chips et de fruits, store rayé vert et blanc, distributeur de boissons à côté, un petit kiosque à journaux devant, un réverbère haut qui monte dans le ciel bleu. Dominante vert pomme et jaune. |
| `UI_ZoneArt_Z2` | 2 · London · Toys | Un magasin de jouets anglais à devanture en bois rouge vernie, vitrine de peluches, de robots et de trains, une confiserie aux bocaux colorés juste au-dessus ou à côté, rue pavée, réverbère noir, un bus rouge à impériale et une grande roue au loin dans le haut de l'image. Dominante rouge et rose bonbon. |
| `UI_ZoneArt_Z3` | 3 · Tokyo · Electronics | Une boutique d'électronique et de jeux vidéo dans une ruelle étroite : écrans et consoles en vitrine, panneaux lumineux empilés verticalement jusqu'en haut de l'image (formes et pictogrammes seulement), lanternes en papier rouges, un petit portique torii au fond. Dominante cyan et magenta. |
| `UI_ZoneArt_Z4` | 4 · Los Angeles · Jewelry | Une bijouterie chic à façade blanche et dorée, vitrine de bagues, de colliers et de montres sur coussins de velours, une horlogerie à côté, deux grands palmiers qui montent jusqu'en haut, trottoir sable et chaussée prune, ciel orangé. Dominante or et violet. |
| `UI_ZoneArt_Z5` | 5 · Paris · Gallery | Une galerie d'art dans un immeuble haussmannien en pierre crème : devanture vert sapin, auvent vert et crème, balcons en fer forgé, toit mansardé en zinc ; tableaux et statues derrière les hautes vitrines, la tour Eiffel dans le haut de l'image, un peu de neige sur le trottoir. Dominante bleu nuit, crème et vert sapin. |
| `UI_ZoneArt_Z6` | 6 · New York · Bank | Une banque en forme de temple de pierre calcaire à colonnes, fronton orné d'une pièce d'or, toit de cuivre vert ; en dessous ou à côté, une porte ronde de coffre-fort en acier avec bandes jaune et noir ; gratte-ciel qui montent jusqu'en haut de l'image. Dominante vert billet et or. |

### 2. Icônes de récompense de zone

Décision de Clément (2026-11-15) : une zone complète donne **de l'argent et de la vitesse en valeurs fixes (pas en %)** et **une arme, une aura ou une trail**. Montants et objets à fixer.

- L'objet (arme, aura ou trail) reprend son icône de boutique déjà faite (`ICON_Aura_<Nom>` de L-179, icônes des armes et des trails de figma-boutiques) : **rien à générer**.
- `CashReward.Icon` reprend l'icône d'argent de la brique `Btn` (Argent) et `SpeedReward.Icon` celle de vitesse du HUD (`Hud_Speed`) : **rien à générer**.
- L'icône `UI_Icon_RewardIncome` prévue plus haut n'a plus lieu d'être (plus de bonus en %) : retirée.

Le panneau des objets exposés n'a besoin d'aucune image nouvelle : son bouton d'ouverture est le `DisplayedButton` du HUD, avec `UI_Icon_Displays` (section figma-hud). Je retire donc mon `OpenButton` de `UI_Displayed` dès que Clément le confirme.

Une fois livrées : import dans `ReplicatedStorage/Assets/Icons` au nom du groupe, puis remplacement dans la page `20 Index et Exposés`.

- figma-index-exposes : Clément a validé la version sur briques de `UI_Index v4` et `UI_Displayed` (2026-11-15). Page `20 Index et Exposés` terminée. Restent ouverts pour la ligne de liaison de ces écrans : nom `UI_Displayed`, retrait de Detail / Categories / Mutations, contenu de la récompense de zone, `OpenButton` remplacé par le `DisplayedButton` du HUD.
- figma-boutiques (2026-11-15, retours de Clément) : **boutons coupés corrigés** (plus de carte à moitié visible : 3 cartes entières sur PC, fenêtre téléphone ramenée à 580 px dans les boutiques d'armes et d'auras ; la liste Robux s'arrête sur un bloc entier), vérifié par script sur les 8 vues. **Caisse exclusive refaite et animée** (vraies animations Figma, boucle de 4 s, vidéos `captures-boutiques-figma/UI_RobuxShop_caisse_*.mp4`). Noms de la caisse : `Crate.Backdrop` (`VaultDoor`, `Spotlight1`, `Spotlight2`, `Rays`, `Glow`, `Shadow`), `Crate.Icon`, `Crate.NewBadge.Label`, `Crate.ItemName`, `Crate.Odds.Odd_1` à `Odd_6` (`Icon`, `Chance`), `RarityGlow` et `Star` dans `Odds`, `Crate.BuyRow.BuyButton1` à `3` (`Content.RobuxIcon`, `Content.Price`, `Count.Label`). `Subtitle` et `OddsNote` sont retirés. 6 **objets exclusifs** neufs, en brouillon, faits dans Blender avec itm_lib : `Items/Exclusive/` (`Exclusive_Objets.blend`, `_scripts/exclusive_items.py`, icônes dans `Icons_brouillon/`, hors du dossier d'import en masse) : Boule disco (Rare), Gramophone doré (Epic), Fusée en or (Legendary), Crâne de cristal (Mythic), Jukebox néon (Secret), Planète dorée (Divine), de 628 à 1 088 triangles.

## Images à générer (figma-boutiques)

7 images, celles qui changent vraiment le rendu. Règles communes :
- notre style : Roblox « mode studs », formes rondes et grasses, couleurs franches. Les icônes ont un contour sombre `#040435`, comme nos `ICON_*` ;
- **aucun texte dans l'image** : titres, prix et chances restent des textes du jeu ;
- rien de Break and Steal an Egg (ni leur château, ni leurs œufs, ni leur cadre doré) ;
- 1024 px au plus de côté (limite Roblox) ;
- les rayons, projecteurs, étoiles et lueurs **restent à part**, parce que le code les anime.

| # | Écran | Emplacement (nom) | Ce qu'elle montre | Format, taille | Fond | Ce qu'elle remplace |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `UI_RobuxShop` | `Crate.Backdrop` (fond de la bannière de la caisse, PC 1130 × 356, téléphone 660 × 258) | L'intérieur d'une chambre forte la nuit : grande porte de coffre ronde à droite, à moitié ouverte ; lingots, liasses et petits diamants au sol ; lumière bleu-violet. Zone gauche plus claire et vide (la caisse s'y pose), zone droite assez sombre pour que les 6 cases restent lisibles. | PNG paysage 1024 × 323 (rapport 3,17), cadré pour être recadré en 2,56 sur téléphone | Opaque | Le dégradé violet, la porte de coffre en vecteurs (`VaultDoor`) et les studs du fond |
| 2 | `UI_RobuxShop` | `Crate.Icon` (la caisse, 300 px sur PC) | La caisse exclusive fermée, vue de 3/4 : coffre-caisse noir et violet, liseré arc-en-ciel, gros cadenas doré, une lueur sort des fentes. Elle doit se lire comme « plus rare que tout ». | PNG carré 1024 × 1024 | Transparent | `ICON_BOX_Secret` (le colis Secret, pris pour l'exemple) |
| 3 | `UI_RobuxShop` | `Featured` (fond de la bannière Starter Pack, PC 1130 × 170) | Un bandeau « départ en braquage » : rue de nuit vue de face, devanture éclairée floue, billets qui volent. Le tiers gauche plus calme (icône), le tiers droit plus calme (bouton prix). | PNG 1024 × 154 (rapport 6,6) | Opaque | Le dégradé orange et les studs |
| 4 | Les 4 boutiques | `Root` (le fond de toutes les fenêtres, sous les cartes) | Une plaque de métal sombre `#33353E` à studs et rivets aux coins, usée juste ce qu'il faut ; centre uni pour ne pas gêner les cartes. Doit pouvoir s'étirer (9-slice : coins de 64 px). | PNG 512 × 512, en 9-slice | Opaque | L'aplat gris et la texture de studs Roblox (3014551673) |
| 5 | `UI_DiamondShop` + HUD de la boutique | `Balance.Icon`, boutons de prix en diamants, packs | Le diamant de la monnaie du jeu : gemme taillée cyan-turquoise, facettes nettes, un éclat blanc. Il sert aussi, répété en tas, aux 4 packs (`UI_Icon_DiamondPack_1` à `_4` composés à partir de lui). | PNG 512 × 512, nom `UI_Icon_Diamond` | Transparent | Le diamant en vecteurs `Draft/DiamondIcon` |
| 6 | `UI_RobuxShop` | `BoostsSection` › carte « ×2 Speed », `Icon` | Une chaussure de course lancée à toute vitesse sur un tapis de course, traînées de vitesse orange, sans texte (le « ×2 » est un texte du jeu). | PNG 512 × 512, nom `UI_Icon_DP_x2Speed` | Transparent | L'icône vitesse du HUD + « ×2 » collés |
| 7 | `UI_RobuxShop` | `BoostsSection` › carte « zZz », `Icon` | Une casquette de vigile posée sur une matraque, avec un croissant de lune et de petites bulles « z » dessinées (sans lettres lisibles). Fait penser « les gardes dorment ». | PNG 512 × 512, nom `UI_Icon_DP_Sleep` | Transparent | La lune et le « zZz » en vecteurs |

Ce qui n'est pas dans la liste, et pourquoi :
- **Objets exclusifs** : déjà faits dans Blender, au même rendu que les objets du jeu (`Items/Exclusive/Icons_brouillon`).
- **Cartes par rareté** : elles ont déjà leurs fonds `ShopCardBg` (L-176).
- **Aperçu de la boutique** : c'est un ViewportFrame, donc une vraie vue 3D, pas une image.
- figma-boutiques (2026-11-15) : **Clément a validé** l'état actuel des 4 boutiques de `10 Boutiques` (armes, auras, Robux v2 avec la caisse animée et les 6 objets exclusifs, diamants). Les noms à reporter dans la liaison sont ceux des entrées figma-boutiques ci-dessus. La boutique Robux v2 remplace la v1. Rien n'est commité.

- figma-index-exposes : **décision de Clément (2026-11-15), récompense de zone de l'index** = argent + vitesse en valeurs fixes (pas en %) + une arme, une aura ou une trail. Maquettes mises à jour : `Footer.CashReward` et `Footer.SpeedReward` (noms de la v3 : `Icon`, `Amount`) entre la barre et `ClaimButton`, qui porte l'objet (`RewardIcon`, `RewardCaption` = son nom). **Pour la liaison (Ironix)** : aujourd'hui `Config/Index` donne +3 % de WalkSpeed (`ZoneSpeedBonus`), +5 % de revenus (`ZoneBonus`) et une prime de 10 min de revenu (`ZoneCashMinutes`) ; à remplacer par une prime fixe, une vitesse fixe et un objet par zone, montants et objets à proposer. À demander à Clément : le +5 % de revenus disparaît-il aussi ? À noter dans le journal des décisions (section 15).
- figma-index-exposes : **retour de Clément (2026-11-15)** : plus de coins arrondis, tout en carré (« c'est plus clean »). Appliqué à `UI_Index` (PC et téléphone), y compris aux instances des briques (rayons forcés à 0) ; seules les pastilles « ! » restent rondes. À voir avec figma-briques : passer les briques elles-mêmes en carré pour que tous les écrans suivent.
- figma-boutiques (2026-11-15, L-184 point 6, « soft ») : **décor qui tombe et bord arc-en-ciel à l'achat Robux** dans `UI_RobuxShop`. Cadres de démonstration animés (« Démo — UI_RobuxShop PC, ouverture et achat », « Démo — … téléphone, achat », 4,5 s), une bande d'images clés et deux vidéos (`captures-boutiques-figma/UI_RobuxShop_decor_et_achat_PC.mp4`, `UI_RobuxShop_achat_telephone.mp4`).
  - **Décor**, noms proposés : `UI_RobuxShop.Decor` (à côté de `Root`, hors de la fenêtre), avec `Hang1` à `Hang4`, chacun avec `String`, `Knot` et `Icon` (billets, caisse, étoile, fusée). Seulement sur PC, dans les marges : rien sur téléphone.
  - **Entrée** : chaque décor tombe de −(sa hauteur) à sa place en 0,25 s (Back Out), avec 0,05 s d'écart, dès que la fenêtre est posée. Il se balance ensuite de ± 2 à 3° toutes les 1,2 s. Une fois par ouverture. Attribut proposé : `Appear = "DropIn"` (vocabulaire de L-182).
  - **Bord**, noms proposés : un ScreenGui `UI_PurchaseGlow`, avec `RainbowBorder`, qui fait 8 px sur PC et 5 px sur téléphone. Dans Roblox : 4 Frames ou une ImageLabel en 9-slice, avec un `UIGradient` arc-en-ciel (`#1DC395`, `#3C9AB6`, `#8B63D9`, `#FF5CC8`, `#FFC21A`) dont la `Rotation` tourne d'environ 0,5 tour/s.
  - **Allumage** : d'un coup au clic sur un prix Robux. Le HUD se cache, et la fenêtre de Roblox arrive environ 0,3 s après. Le bord s'efface en 0,1 s à `PromptProductPurchaseFinished` ou `PromptGamePassPurchaseFinished`, puis le HUD revient. Sert aussi aux boutons Robux en situation (×2 Speed, zZz).
- figma-boutiques (2026-11-15) : **Clément a validé** le décor qui tombe et le bord arc-en-ciel de l'achat Robux (L-184, point 6). Noms et réglages : entrée précédente. Rien n'est commité.
- figma-index-exposes : `UI_Displayed` aussi passé en carré (PC, téléphone, bande d'images clés 126:1344), à la demande de Clément.

- figma-hud-tapis-poursuite : L-184 dessiné sur la page 30, en attente des retours de Clément : 10 CAUGHT! (132:6962), 11 discret puis repéré (132:9641), 12 carte ITEM SECURED! (134:369), 13 gains qui volent (135:805). Tableau des noms (106:10614) complété.

## Noms nouveaux de L-184 (page 30, à ajouter au contrat 2.2 après accord)

| Écran | Nom | Rôle |
| --- | --- | --- |
| `UI_Caught` (nouvel écran, nom à valider) | `Title`, `ItemCard` (`Icon`, `ItemName`), `Hint`, `LetterboxTop`, `LetterboxBottom` | « CAUGHT! » en Stamp ; la carte de l'objet perdu repart vers son présentoir ; `Hint` = vitesse conseillée (message actuel) ; bandes noires cachées, la nuit seulement |
| `UI_HUD` | `SneakLabel` | petit texte jaune pendant le braquage tant que personne n'a vu le joueur ; caché d'un coup à « RUN! » |
| `UI_Chase` | `ScreenEdges` (inchangé) | pulse en poursuite : transparence 0 ↔ 0,4, Sine InOut, 1,2 s le cycle |
| `UI_Escape.Banner` | `Title`, `Subtitle`, `BoxIcon` (gardés) ; `Rays`, `RarityLabel`, `Income`, `NewBadge` (nouveaux) | carte d'objet ; `Subtitle` = nom dans la couleur de la rareté ; `NewBadge` seulement si nouveau dans l'index |
| `UI_Escape` | `Hint` | « Place it in your shop! », caché dès que l'objet est exposé |
| `UI_HUD.CashFly` | `CounterPop` (gardé) | « +$ » du gain ponctuel ; les billets sont des copies de `CashIcon` faites par le code |
- figma-index-exposes : **Clément a validé le nouvel Index en carré (2026-11-15)** : mise en page de sa capture de référence (liste de zones qui défile, `Detail`, `Rewards`, `Categories` NORMAL / LIMITED / MUTATIONS), titre jaune et compteur « 23 / 83 discovered » gardés. Écrans 105:507 (PC) et 106:369 (téléphone), noms dans 106:11389. Bandes refaites : 136:719 (ouverture), 136:1791 (survol, clic et 3 états de la récompense : en cours = `ClaimButton` grisé, prête = vert + `ClaimAlert`, réclamée = « CLAIMED »). `UI_Displayed` validé aussi. Prompts des 6 images de zone dans la section « Images à générer (figma-index-exposes) ». Page `20 Index et Exposés` terminée.
- **Pour la liaison (Ironix), à reporter par le chef de projet** : catégorie `LimitedButton` à définir (n'existe pas dans le code ; remplace `SecretsButton`) ; `RewardIcon` (arme, aura ou trail) au bout de `ZoneBar` dans chaque `Zone<N>Section` ; `SpeedReward` et `CashReward` en valeurs fixes ; plus d'onglets de ville (`Tabs`) ni de pages.

- figma-hud-tapis-poursuite : Clément a validé les états 10 à 13 de la page 30 (L-184 : CAUGHT!, braquage discret puis repéré, carte ITEM SECURED!, gains qui volent), 2026-11-15. Gardés tels quels : « Recommended speed: 28 » sous CAUGHT! ; nom `UI_Caught`. Reste : effet de poussière de la capture (nom à venir, Clément).

- figma-hud-tapis-poursuite : icônes générées posées sur la page 30 (2026-11-15) : `UI_Icon_Upgrades` (SkillTreeButton), `UI_Icon_Displays` (DisplayedButton), `UI_Icon_SpeedBoost` (SpeedBoostButton), `UI_Icon_Sleep` (SleepButton), dans tous les états et vignettes. `UI_Icon_Drop` manque encore : DROP reste sans icône.
- figma-boutiques (2026-11-15) : **images générées par Clément posées** dans `10 Boutiques`.
  - `UI_Bg_CrateVault` sert de fond aux 21 `Crate.Backdrop` (écrans, liste complète, démos, bandes). La porte de coffre en vecteurs est cachée ; rayons et projecteurs animés restent par-dessus.
  - `UI_Bg_StarterPack` remplit les 21 `Featured` (remplissage recadré), avec un voile bleu nuit dégradé à gauche pour que le titre et les étiquettes restent lisibles.
  - `UI_Icon_Diamond` est dans le composant `Draft/DiamondIcon` : solde, boutons de prix, packs, onglet Diamonds.
  - `UI_Icon_SpeedBoost` et `UI_Icon_Sleep` sont dans les cartes ×2 Speed et zZz (`Icon`). Noms des Decals pour Ironix : `UI_Icon_SpeedBoost` et `UI_Icon_Sleep` (au lieu des noms proposés `UI_Icon_DP_x2Speed` et `UI_Icon_DP_Sleep`).
  - Le fond `ShopPanel` est refusé : le fond des fenêtres reste en vecteurs.
  - Vérifié : aucune coupe sur les 10 vues.
- figma-index-exposes : les 6 illustrations de Clément (`UI_Index_Zone1` à `Zone6`) et `UI_Icon_Displays` importées (cadre 103:1453). Zone 2 posée dans `ZoneArt` des deux écrans de l'index (remplissage recadré = `ScaleType Crop`) ; planche des 6 zones à la taille réelle avec la bande visible (142:621) : on voit 54 % de la largeur en zone 1 (1:2), 41 % en zones 2 à 4, 53 % en zones 5 et 6 (3 rangées). `UI_Icon_Displays` dans tous les `OpenButton.OpenIcon`. Corrigé au passage : la liste de l'index s'arrête après 2 rangées entières (plus de carte coupée) et le panneau des exposés sur téléphone montre 3 lignes entières.
- figma-index-exposes : nouvelle `UI_Index_Zone1` (683 × 1024, 2:3) posée à la place de l'ancienne (cadre Assets et planche 142:621) ; on en voit maintenant 41 % de la largeur, comme les zones 2 à 4.
- figma-boutiques (2026-11-15) : **Clément a validé** les images générées posées dans `10 Boutiques` (chambre forte, Starter Pack avec voile, diamant, ×2 Speed, zZz). Rien n'est commité.
- figma-hud-tapis-poursuite : icônes générées validées par Clément sur la page 30 (2026-11-15). Reste `UI_Icon_Drop`.
