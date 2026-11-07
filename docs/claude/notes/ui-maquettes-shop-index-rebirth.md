# Maquettes Figma : Shop, Index, Rebirth (UI-100, UI-111, UI-120)

**Validées par Clément le 2026-11-07.** Pour la session principale : noter la décision au journal (section 15 du doc partagé), passer UI-100, UI-111 et UI-120 à « En cours » (maquette validée), et ajouter dans la liaison une ligne « Pour : Ironix » avec les noms proposés ci-dessous.

Demande de Clément du 2026-11-07 : dessiner les écrans qu'ouvrent les boutons Shop, Index et Rebirth du HUD, d'abord en maquettes Figma. BASE n'a pas d'écran : il ramène à la base. Fichier « Steal a Shop — UI » (fileKey `fXjkvf39sRhlsL94YicwDH`), page Boutique.

| Maquette | Nœud | Contenu |
| --- | --- | --- |
| `UI_RobuxShop — onglet Gamepasses` | `4:5` (mise à jour) | En anglais (Shop ; ×2 CASH, ×2 TRAINING, VIP, AUTO COLLECT, FAST OPEN, +4 DISPLAYS ; onglets Offers, Gamepasses, Cash, Boosts). Ligne d'effet sous chaque nom. État « OWNED » (bouton gris + coche) montré sur VIP. Fenêtre de 980 × 600, avec 2 rangées entières |
| `UI_Index — zone 1` | `24:94` | Bandeau bleu, compteur « 23 / 74 discovered », barre de zone « MINI MART 9 / 13 » + récompense « +5% INCOME », grille de 13 objets (vignettes rendues depuis `Z1_Objets.blend`), silhouettes noires pour les objets pas trouvés, onglets Mini Mart, London, Tokyo, L.A., Paris, New York, Secrets |
| `UI_Rebirth — renaissance 1` | `26:220` | Bandeau violet, « Level 0 → 1 », argent requis ($6.4K / $10K), objet requis grisé (Instant Noodles, Rare, « Not owned yet »), colonnes YOU LOSE / YOU KEEP / YOU GAIN (Partie 2, 3.2), bouton REBIRTH |
| `UI_Rebirth — bouton en 2 temps` | `26:301` | Les 3 états du bouton : Disabled → Ready (1er appui) → Confirm (2e appui) |

Nouveaux composants dans la section Composants : `Card_IndexItem` (variantes Found et Locked ; propriétés Name et Rarity) et `Btn_Rebirth` (Disabled, Ready, Confirm). `Card_Gamepass` gagne `Effect` (texte), `Owned` et `Buy` (booléens). Les 24 images importées sont dans le cadre « Assets — Index et Rebirth (images importées) » ; leurs sources sont dans `StealAShop-Art/UI/Figma_a_importer` (avec `_render_icons.py` pour les vignettes d'objets).

## Noms proposés pour le contrat 2.2 (à valider par Ironix avant qu'il code, puis à écrire dans la liaison et au tableau 2.2)

Les calques des maquettes portent déjà ces noms.

- `UI_RobuxShop` : `CloseButton`, `Tabs` avec `OffersTab`, `GamepassesTab`, `CashTab`, `BoostsTab`, `List` (ScrollingFrame), `List.Template` avec `Icon`, `ItemName`, `Effect`, `Price` (dans `BuyButton`), `BuyButton`, `GiftButton`, `Owned`.
- `UI_Index` : `CloseButton`, `Counter`, `Tabs` avec `Zone1Tab` à `Zone6Tab` et `SecretsTab`, `ZoneReward` avec `ZoneName`, `ZoneBar` (et son `Fill`), `ZoneCount`, `Reward`, `List`, `List.Template` avec `Icon`, `ItemName`, `Rarity`. Dans Roblox, la silhouette d'un objet pas trouvé = `ImageColor3` noir sur `Icon`.
- `UI_Rebirth` : `CloseButton`, `Level`, `CashRequirement` avec `CashAmount`, `CashBar` (et son `Fill`), `CashLabel`, `ItemRequirement` avec `Icon`, `ItemName`, `Rarity`, `Status`, `GainList`, `ConfirmButton` (3 états : Disabled, Ready, Confirm). Les colonnes YOU LOSE et YOU KEEP sont du texte fixe.

Questions ouvertes : le bouton cadeau de la boutique (offrir un gamepass n'est pas prévu, doc 10.6) ; les icônes des onglets de zones sont des icônes FOLK provisoires, à remplacer par des rendus d'objets (MOD-040).
