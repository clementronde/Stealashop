# Rééquilibrage v2 : décisions de Cantin (2026-11-14)

Écrit par Claude le 2026-11-14, à la demande de Cantin. Ce fichier sert à mettre ces décisions en place dans le code. Les nouvelles valeurs chiffrées viendront de l'agent d'équilibrage (proposition sur la branche `agents/a132`) : en attendant, aucune valeur ne change dans `Config`.

## Décidé par Cantin le 14/11

Ses mots :

- **Tout reprendre** : « On va tout reprendre ».
- **Tapis** : « Niveau 1, il va rapporter 1 de vitesse par seconde [...] À chaque level up du treadmill, ça sera multiplié par 2 ». Le tapis a 20 niveaux (`Config/Upgrades`, `MaxLevel = 20`) : le niveau n rapporte donc 2^(n−1) de vitesse par seconde.
- **Temps pour la zone 6** : « la proposition pour atteindre la zone 6 qui est de 7h30, on va la prendre ». Un joueur doit pouvoir arriver en zone 6 en environ 7 h 30 de jeu.
- **Zone 6 à deux** : « un joueur tout seul ne puisse pas casser ses magasins. Il faut obligatoirement d'être au minimum 2 ». Le calcul doit tenir compte du chrono de casse de 13 s (« HEIST: 13s »).
- **Plus de banc** : « il n'y aura plus de banc seulement les armes et on va mettre en place le fait que l'aura aura aussi un multiplicateur de force met le dans un doc du git pour qu'on le mette en place ».
- **Potion de force** : « la potion sera une potion x1.5 comme ça plus de problèmes ». La potion Strength passe de ×2 à ×1,5.
- **Profils DEV** : « Remise à zéro en DEV » quand les nouvelles valeurs arriveront.

## À mettre en place dans le code

1. **Retirer le banc du jeu**, partout où il sert :
   - `src/server/Services/TrainingService.luau` (gain de force au banc) et `src/client/Controllers/TrainingController.luau` (côté banc) ;
   - `src/client/Controllers/BenchBarController.luau` (barre du banc) ;
   - l'amélioration `Bench` (« Weight Bench ») de `Config/Upgrades` et son panneau d'amélioration près du banc (`UpgradeController`, `ShopService`) ; son niveau peut rester dans les profils, sans effet, comme `UnboxBenches` ;
   - le tuto : étape 6 `Train` (« Train on the treadmill and bench », `Config/Tutorial`) → le tapis seul ;
   - le contrat : modèle `Bench` et tag `Bench` (`Contract/Models`), animations `BenchLift` et `BenchIdle` (`Contract/Animations`). À retirer du contrat en l'annonçant d'abord dans la liaison (règle du contrat de noms).
   - à revoir aussi : `AdminService` et `AdminController` (commandes du banc), `TutorialService`, `GainController`, `AnimationController`, `Shared/Anim`, et tout ce qui lit la stat Force (`Stats.Strength`) : HUD, renaissance, arbre de compétences, bandeau de zone.
2. **Dégâts = arme × multiplicateur d'aura × potion.** Aujourd'hui, `Formulas.HitDamage(toolPower, strength, auraMultiplier)` vaut `toolPower × (1 + strength / StrengthDivisor) × auraMultiplier`. Sans banc, la part de la force disparaît.
3. **Potion Strength ×1,5** : `Config/Potions`, `Multiplier = 2` → `1.5`.
4. **Nouvelles valeurs** (tapis, prix, armes, auras, PV des vitrines par zone, seuils des zones) : celles de la proposition d'`agents/a132`, une fois validées par Cantin. Vérifier les deux contraintes : zone 6 en environ 7 h 30, et zone 6 impossible à casser seul (en tenant compte du chrono de casse de 13 s).
5. **Remise à zéro des profils DEV** quand les nouvelles valeurs arrivent (le profil de Cantin compris), avec son accord au moment de le faire.

## Côté Clément (liaison)

Plus de banc : son modèle de banc et ses animations `BenchLift` et `BenchIdle` ne servent plus. L'aura devient le multiplicateur de force. La potion de force passe à ×1,5. La zone 6 demande au moins 2 joueurs. De nouvelles valeurs arrivent.
