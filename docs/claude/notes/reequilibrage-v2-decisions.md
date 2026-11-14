# Rééquilibrage v2 : décisions de Cantin (2026-11-14)

Écrit par Claude le 2026-11-14, à la demande de Cantin. Ce fichier sert à mettre ces décisions en place dans le code. **Proposition chiffrée (14/11)** : [equilibrage-v2-proposition.md](equilibrage-v2-proposition.md) (toutes les valeurs, temps par zone, règle de la zone 6, questions pour Cantin et pour Clément en section 9 ; liaison L-151). Elle n'est pas encore appliquée : aucune valeur ne change dans `Config` avant les réponses de Cantin et de Clément.

## Décidé par Cantin le 14/11

Ses mots :

- **Tout reprendre** : « On va tout reprendre ».
- **Tapis** : « Niveau 1, il va rapporter 1 de vitesse par seconde [...] À chaque level up du treadmill, ça sera multiplié par 2 ». Le tapis a 20 niveaux (`Config/Upgrades`, `MaxLevel = 20`) : le niveau n rapporte donc 2^(n−1) de vitesse par seconde.
- **Temps pour la zone 6** : « la proposition pour atteindre la zone 6 qui est de 7h30, on va la prendre ». Un joueur doit pouvoir arriver en zone 6 en environ 7 h 30 de jeu.
- **Zone 6 à deux** : « un joueur tout seul ne puisse pas casser ses magasins. Il faut obligatoirement d'être au minimum 2 ». Le calcul doit tenir compte du chrono de casse de 13 s (« HEIST: 13s »).
- **Plus de banc** : « il n'y aura plus de banc seulement les armes et on va mettre en place le fait que l'aura aura aussi un multiplicateur de force met le dans un doc du git pour qu'on le mette en place ».
- **Potion de force** : « la potion sera une potion x1.5 comme ça plus de problèmes ». La potion Strength passe de ×2 à ×1,5.
- **Profils DEV** : « Remise à zéro en DEV » quand les nouvelles valeurs arriveront.
- **Dégâts pour le calcul, sans la potion** (précision du 14/11) : « pour le calcul final des dégâts, il ne faut pas prendre la potion en compte. Parce que de toute façon, puisqu'elle multiplie fois 1,5, une personne en zone 6 ne pourra pas casser la vitrine toute seule [...] tu prends juste l'aura et l'arme, les dégâts de l'arme. »
  - Règle qui en découle pour l'équilibrage : les calculs se font avec **dégâts = arme × aura**. La potion ×1,5 reste un bonus en plus, en jeu.
  - **PV des vitrines de la zone 6** = les dégâts de deux des meilleurs joueurs possibles (arme × aura au maximum) pendant le chrono de casse de 13 s.

### Réponses de Cantin aux questions de la proposition (14/11)

Ses mots, questions de la section 9 de [equilibrage-v2-proposition.md](equilibrage-v2-proposition.md) :

1. Cible de 7 h 30 : « Sans les aides » (7 h 35 de jeu actif).
2. PV des vitrines de la zone 6 : « 374M » (deux joueurs au maximum à 10 coups/s, et non 320M).
5. Potion de vitesse : « On enlève potion de vitesse ». L'Index (+3 % de marche par zone) reste, tant que Cantin n'a rien dit.
6. Gamepass Hydraulic Gloves : « Il peut casser car il a payé » : le pass reste, et un joueur qui l'a peut casser seul une vitrine de la zone 6.

Questions 3, 4 et 7 (niveau 1 du tapis offert, taps au tapis +50 %, joueur prudent à 15 h 30) : pas encore répondues, on garde les choix par défaut de la proposition. Profils DEV : remise à zéro (déjà décidé).

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
4. **Nouvelles valeurs** (tapis, prix, armes, auras, PV des vitrines par zone, seuils des zones) : celles de [equilibrage-v2-proposition.md](equilibrage-v2-proposition.md), une fois validées par Cantin. Vérifier les deux contraintes : zone 6 en environ 7 h 30, et zone 6 impossible à casser seul (PV de ses vitrines = dégâts de deux des meilleurs joueurs, arme × aura au maximum, pendant le chrono de 13 s ; potion non comptée).
5. **Retirer la potion Speed** : son entrée dans `Config/Potions`, son effet dans `PotionService` (`StatsService.SetSpeedModifier`, le seul modificateur posé au-dessus du plafond), sa carte et son minuteur côté client (`PotionController`, `InventoryController`), son icône, le contrat du modèle `POT_Speed`, et ce qui la cite : `AdminService`, `AntiCheatService`, `StatsService`, `TelemetryService`, les attributs de test (`PotionTest`). Vérifier si la tuile `PotionTime` de l'arbre en dépend (elle allonge toutes les potions : elle reste pour les autres). Les potions déjà dans les profils : à vider à la remise à zéro.
6. **Hydraulic Gloves** : rien à changer, il casse la zone 6 seul (choix de Cantin).
7. **Remise à zéro des profils DEV** quand les nouvelles valeurs arrivent (le profil de Cantin compris), avec son accord au moment de le faire.

## Côté Clément (liaison)

Plus de banc : son modèle de banc et ses animations `BenchLift` et `BenchIdle` ne servent plus. L'aura devient le multiplicateur de force. La potion de force passe à ×1,5. La zone 6 demande au moins 2 joueurs. De nouvelles valeurs arrivent.
