# ×2 → ×16 CASH (`DoubleCash` + échelle) — fiche gamepass

Statut : **proposition, à valider par Clément** (2026-11-21, revue après sa demande : « les ×2 doivent être des petits montants pour ensuite montrer ×4, ×8, ×16 »). Rien créé sur Roblox.

## Principe

Une **échelle de 4 gamepasses** : le ×2 ne coûte presque rien (premier achat facile), puis chaque marche double le multiplicateur. Repris du principe des trails de Steal a Wild Horse (×2 à 29 R$, puis ×4 à 399, ×8 à 799, ×16 à 1 599, jusqu'à ×50 à 2 999), sans leurs noms ni leurs visuels.

| Marche | Clé | Nom | Multiplicateur | Prix proposé (R$) | Icône | Couleur de carte |
|---|---|---|---|---|---|---|
| 1 | `DoubleCash` (existe, Id = 0) | ×2 CASH | 2 (Config) | **29** (au lieu de 449 ; demande de Clément) | `UI_Icon_GP_x2Cash` (existe) | `45D63A` (existe) |
| 2 | `CashX4` (V0 proposé) | ×4 CASH | 4 | **99** | `UI_Icon_GP_x4Cash` (à faire) | V0 : vert plus foncé |
| 3 | `CashX8` (V0 proposé) | ×8 CASH | 8 | **399** | `UI_Icon_GP_x8Cash` (à faire) | V0 : vert-or |
| 4 | `CashX16` (V0 proposé) | ×16 CASH | 16 | **999** | `UI_Icon_GP_x16Cash` (à faire) | V0 : or |

Les multiplicateurs ×4, ×8, ×16 sont ta demande ; les prix, clés, noms d'icônes et couleurs sont des propositions. Prix : ×2 à 29 R$ (demande de Clément, 2026-11-21 : un achat « réflexe » que presque tout le monde peut faire, qui met le joueur dans l'échelle) ; puis 99, 399, 999, un peu moins cher que la référence (×4 à 399, ×8 à 799, ×16 à 1 599) pour que le saut après 29 reste franchissable. À 29 R$, Roblox nous reverse environ 20 R$ (70 %) : la marche 1 rapporte peu, elle sert surtout à amener aux suivantes. C'est aussi le prix de la référence (×2 à 29 R$). Prix minimum d'un gamepass : à vérifier sur le Creator Hub au moment de le créer (aucune limite trouvée dans le vault ; la mise en avant « bonus pool » de Roblox demande plus de 49 R$, ce pass n'y aura pas droit).

## Règle de cumul (à décider, c'est le point le plus important)

- **Proposition : la plus haute marche possédée gagne, on ne multiplie pas les passes entre eux.** ×2 + ×4 + ×8 + ×16 possédés = ×16, pas ×1 024. C'est aussi la règle des trails de référence.
- Roblox ne permet pas d'empêcher l'achat d'un ×8 sans le ×4 (on peut acheter un gamepass depuis la page du jeu) : le code doit marcher avec n'importe quelle combinaison possédée, d'où « la plus haute gagne ».
- Dans la boutique : on montre **la marche suivante seulement** (le joueur qui a ×4 voit la carte ×8), ou toute l'échelle avec les marches possédées cochées. Proposition : la marche suivante seulement, l'échelle tient alors dans une seule carte qui « monte ».
- Avec les autres bonus (inchangé) : le boost ×2 argent du pack de départ se multiplie (×16 × ×2 = ×32) ; les bonus en % (Premium, index, VIP) s'additionnent avant.

## Équilibre (à vérifier avant de vendre)

- ×16 sur tous les revenus est **énorme** : un acheteur fait en 1 h ce qu'un joueur gratuit fait en 16 h. Les coûts des renaissances et le simulateur de l'économie (L-151) sont réglés pour ×2 au plus. Il faut relancer le simulateur avec ×16 (et ×32 avec le boost) avant d'allumer les marches 3 et 4.
- Le vol entre joueurs n'est pas touché (ni force, ni vitesse, ni défense), donc pas de « pay to win » PvP. Mais un joueur ×16 a vite les meilleurs objets, donc une boutique très tentante à voler : plutôt bon pour le jeu.
- Piste plus prudente si le simulateur coince : ×2, ×3, ×5, ×10 (à toi de voir).

## Textes (anglais)

| Marche | Ligne de carte | Description de la page Roblox |
|---|---|---|
| ×2 | `Doubles all your income` | `Double ALL the cash your shop makes, forever!` |
| ×4 | `×4 all your income` | `×4 ALL the cash your shop makes, forever! Replaces ×2 Cash.` |
| ×8 | `×8 all your income` | `×8 ALL the cash your shop makes, forever! Replaces ×4 Cash.` |
| ×16 | `×16 all your income` | `×16 ALL the cash your shop makes, forever! The best cash boost in the game.` |

« Replaces » dit honnêtement que les passes ne se cumulent pas (règle Roblox : pas de texte trompeur).

## Place dans la boutique

Gamepasses, **1re carte** (une seule carte qui montre la marche suivante). Étiquette proposée sur ×2 : « ONLY 29! » ou « STARTER » ; sur ×16 : « MAX ».

## Icônes

Même médaillon pour les 4 marches, même liasse de billets : seuls **le chiffre** et **la richesse** changent (×2 : une liasse ; ×4 : deux liasses ; ×8 : une pile + pièces ; ×16 : pile dorée qui brille). Le chiffre en très gros, blanc à contour noir, en bas à droite. On voit tout de suite qu'il y a « plus haut ».

## Pour Ironix

- `DoubleCash` : `Price = 29`.
- Ajouter 3 gamepasses à `Config/Monetization.Passes` : `CashX4`, `CashX8`, `CashX16`, `Multiplier = 4, 8, 16`, Id = 0, prix ci-dessus, et un champ commun (par ex. `Ladder = "Cash"`, `Rung = 1..4`) pour dire qu'ils forment une échelle.
- `MonetizationService` (accroche `DisplayService.GetIncomeMultiplier`) : prendre le **plus grand** `Multiplier` des passes de l'échelle possédés, au lieu de multiplier.
- `RobuxShopController` : une carte par échelle qui montre la plus petite marche pas possédée (toutes possédées : la carte ×16 cochée).
- Avant d'allumer ×8 et ×16 : relancer le simulateur de l'économie avec ×16 (×32 avec le boost).
- Doc 4.1 et `PassKey` à mettre à jour.

## Questions

1. Clément : 4 marches ×2 / ×4 / ×8 / ×16, ou on va plus loin (×32…) ?
2. Clément : prix 29 / 99 / 399 / 999 ?
3. Clément et Ironix : « la plus haute gagne » ?
4. Clément : une seule carte qui monte, ou toute l'échelle visible ?
