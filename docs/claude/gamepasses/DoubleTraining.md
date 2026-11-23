# ×2 → ×16 TRAINING (`DoubleTraining` + échelle) — fiche gamepass

Statut : **proposition, à valider par Clément** (2026-11-21, revue après sa demande : « les ×2 doivent être des petits montants pour ensuite montrer ×4, ×8, ×16 »). Rien créé sur Roblox.

## Principe

Même échelle que l'argent (voir `DoubleCash.md`) : un ×2 très bon marché, puis ×4, ×8, ×16. C'est exactement le modèle des trails de vitesse du tapis de Steal a Wild Horse (×2 à 29 R$ … ×16 à 1 599), qui y sont la plus grosse source de gamepasses.

| Marche | Clé | Nom | Multiplicateur (gains du tapis) | Prix proposé (R$) | Icône | Couleur de carte |
|---|---|---|---|---|---|---|
| 1 | `DoubleTraining` (existe, Id = 0) | ×2 TRAINING | 2 (Config) | **29** (au lieu de 299 ; demande de Clément) | `UI_Icon_GP_x2Training` (existe) | `FF9A2E` (existe) |
| 2 | `TrainingX4` (V0 proposé) | ×4 TRAINING | 4 | **79** | `UI_Icon_GP_x4Training` (à faire) | V0 : orange foncé |
| 3 | `TrainingX8` (V0 proposé) | ×8 TRAINING | 8 | **299** | `UI_Icon_GP_x8Training` (à faire) | V0 : rouge-orange |
| 4 | `TrainingX16` (V0 proposé) | ×16 TRAINING | 16 | **799** | `UI_Icon_GP_x16Training` (à faire) | V0 : rouge feu |

×2 à 29 R$ comme l'argent (demande de Clément) ; ensuite moins cher que l'argent à chaque marche, comme aujourd'hui (299 contre 449) : la vitesse se rattrape en s'entraînant, l'argent fait les renaissances.

## Produit « ×2 Speed » retiré (décision de Clément, 2026-11-21)

Le produit développeur `SpeedBoost` (Config/Boosts : ×2 sur le tapis pendant 10 min, 29 R$, pas codé, Id = 0) faisait doublon avec le gamepass ×2 Training permanent au même prix. **Clément l'a retiré** : l'échelle ×2 / ×4 / ×8 / ×16 le remplace. Rien n'avait été créé sur Roblox, donc rien à supprimer côté Creator Hub.

## Règle de cumul

Comme l'argent : **la plus haute marche possédée gagne** (×16, pas ×1 024), quel que soit l'ordre d'achat.

## Équilibre

- Le gain du tapis monte la stat Speed ; elle sert à fuir le vigile et à poursuivre ou semer les autres joueurs. **Vérifié dans le code** : la vitesse de marche suit le logarithme de Speed (`Formulas`, `WalkPerDecade × log10(…)`) et a un **plafond**, `Balance.Stats.MaxWalkSpeed = 70` × `RealSpeedScale`. Un ×16 fait gagner environ 1,2 « décade » de Speed à temps égal, pas 16 fois la vitesse, et tout le monde finit au même plafond. Pas d'acheteur intouchable : le ×16 fait arriver plus tôt au plafond, c'est tout. Acceptable.
- Le ×2 Training du HUD (`TrainingBoost` affiche « x2 ») devra afficher la marche possédée (« x4 », « x8 », « x16 »).

## Textes (anglais)

| Marche | Ligne de carte | Description de la page Roblox |
|---|---|---|
| ×2 | `×2 treadmill gains` | `Every treadmill run gives ×2 speed, forever!` |
| ×4 | `×4 treadmill gains` | `Every treadmill run gives ×4 speed, forever! Replaces ×2 Training.` |
| ×8 | `×8 treadmill gains` | `Every treadmill run gives ×8 speed, forever! Replaces ×4 Training.` |
| ×16 | `×16 treadmill gains` | `Every treadmill run gives ×16 speed, forever! The fastest training in the game.` |

## Place dans la boutique

Gamepasses, **2e carte**, une seule carte qui montre la marche suivante (comme l'argent).

## Icônes

Même médaillon pour les 4 marches : la chaussure de course de l'icône actuelle, qui prend des ailes puis des flammes en montant ; « ×4 », « ×8 », « ×16 » en très gros en bas à droite.

## Pour Ironix

- `DoubleTraining` : `Price = 29`.
- Ajouter `TrainingX4`, `TrainingX8`, `TrainingX16` (`Multiplier = 4, 8, 16`, Id = 0, prix ci-dessus, même champ d'échelle que l'argent).
- Accroche `TrainingService.GetGainMultiplier` : le plus grand `Multiplier` possédé de l'échelle.
- HUD : `TrainingBoost` affiche « x » + la marche possédée (`HudMenuController`, ligne de `passMultiplier("DoubleTraining")`).
- **Retirer `SpeedBoost`** (décision de Clément) : de `Config/Boosts.List`, de `Monetization.ShopBoosts` (carte « ×2 Speed » de l'onglet Boosts ; Open Now passe en 2e après Sleeping Guards) et du code du HUD qui montre `SpeedBoostButton` sur le tapis. Ne pas créer ce produit sur le Creator Hub.
- Pour Clément (UI, sa session) : retirer ou cacher pour de bon `SpeedBoostButton` du `RightRail` de `UI_HUD`, la carte `Preview_1` « ×2 SPEED » de `BoostsSection` (le `Template` de cette section porte aussi son icône : à remplacer par une autre), et décider du sort de `UI_Icon_SpeedBoost` (la garder pour l'échelle ×2 Training ?).

## Questions

1. Clément : prix 29 / 79 / 299 / 799 ?
