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
2. PV des vitrines de la zone 6 : « 374M » (deux joueurs au maximum à 10 coups/s, et non 320M). Remplacé ensuite par la règle du chrono de police (plus bas).
5. Potion de vitesse : « On enlève potion de vitesse ». L'Index (+3 % de marche par zone) reste, tant que Cantin n'a rien dit.
6. Gamepass Hydraulic Gloves : « Il peut casser car il a payé » : le pass reste, et un joueur qui l'a peut casser seul une vitrine de la zone 6.

Questions 3, 4 et 7 (niveau 1 du tapis offert, taps au tapis +50 %, joueur prudent à 15 h 30) : pas encore répondues, on garde les choix par défaut de la proposition. Profils DEV : remise à zéro (déjà décidé).

### Chrono de police, braquage de 6 s et 5 coups par seconde (Cantin, 14/11)

Ses mots : « on va avoir un chrono quand qq casse la vitre qui sera "La police arrive dans 13 sec" par exemple et quand on tentre ca sera le heist classique mais ca sera 6 secondes. Donc pour repondre a ta question non un joueur seul ne pourra pas casser les 13 sec d'appel de police. De plus on va capper les coups sur la vitrine ca sera max 5coups/s que ce soit dans tes calculs mais réellement ». Pour les zones 1 à 5 : un joueur seul au niveau conseillé casse une vitrine en « 11 sec ».

Règles qui en découlent :

1. **Chrono de police** : au premier coup sur une vitrine, un chrono « la police arrive dans 13 s » démarre (aujourd'hui `Balance.Window.BreakTimer = 13`, déjà affiché à ceux qui frappent comme « HEIST: 13s », et qui remet la vitrine à ses PV max à la fin). Vitrine pas cassée à temps : la police arrive.
2. **Braquage de 6 s** : une fois la vitrine cassée, le chrono du braquage (« HEIST ») dure 6 s au lieu de 10 (`Balance.Heist.Duration`).
3. **5 coups par seconde au plus** sur une vitrine, dans les calculs et dans le jeu (aujourd'hui `Balance.Hit.MaxHitsPerSecond = 10`).
4. **Zones 1 à 5** : PV d'une vitrine = ce que casse un joueur seul au niveau conseillé en 11 s.
5. **Zone 6** : un joueur seul ne casse pas une vitrine en 13 s, deux joueurs oui. Cette règle remplace les 374M (et les 320M) : les PV seront recalculés.

### Chrono de police à 8 s (Cantin, 14/11, remplace les 13 s et les 11 s ci-dessus)

Ses mots : « On reste sur 8 secondes et du coup faut tout revoir sur 8 secondes » (les témoins appellent la police à 8 s, `Witness.FillTime = 8`, alors que le chrono affichait 13 s). Pour les zones 1 à 5 : un joueur seul au niveau conseillé casse une vitrine en « 6,5 s ».

Règles qui en découlent :

1. **Chrono de police de 8 s** au premier coup (`Balance.Window.BreakTimer` 13 → 8), texte « POLICE IN 8s » ; les témoins restent à 8 s (`Witness.FillTime`).
2. **Zones 1 à 5** : un joueur seul au niveau conseillé casse une vitrine en 6,5 s.
3. **Zone 6** : un joueur seul ne casse pas une vitrine en 8 s, deux joueurs oui.
4. **Braquage** : 6 s après la casse, inchangé. 5 coups par seconde au plus, inchangé.
5. Les PV des vitrines sont recalculés avec ces règles (passe 3 du rééquilibrage, branche `agents/a138`) : les valeurs de la passe 2 ne valent plus.

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
4. **Nouvelles valeurs** (tapis, prix, armes, auras, PV des vitrines par zone, seuils des zones) : celles de la passe 3 (chrono de police à 8 s, section « Passe 3 du 14/11 (8 s) » en tête de la proposition : PV zones 1 à 5 = 27,197 × dégâts du panneau, zone 6 à 108,8M, zone 6 en 7 h 31) ; la passe 2 ci-dessous ne vaut plus pour les PV des vitrines. Passe 2 : celles de la « Passe 2 du 14/11 » en tête de [equilibrage-v2-proposition.md](equilibrage-v2-proposition.md), qui prime sur le reste de la note, une fois validées par Cantin : 5 coups/s pour tous ; PV des vitrines des zones 1 à 5 = 41,35 × dégâts du panneau (un joueur seul au niveau conseillé en 11 s) ; zone 6 = 165,4M (deux joueurs en 11,0 s ; seul avec la potion 16,5 s, raté ; seul avec Hydraulic Gloves 8,3 s) ; joueur moyen en zone 6 en 7 h 35 sans aides. À ne pas oublier : la formule de la Fortune Tower compte 7 coups/s, à passer à 5. Vérifier les deux contraintes : zone 6 en environ 7 h 30, et zone 6 impossible à casser seul (PV de ses vitrines = dégâts de deux des meilleurs joueurs, arme × aura au maximum, pendant le chrono de 13 s ; potion non comptée).
5. **Retirer la potion Speed** : son entrée dans `Config/Potions`, son effet dans `PotionService` (`StatsService.SetSpeedModifier`, le seul modificateur posé au-dessus du plafond), sa carte et son minuteur côté client (`PotionController`, `InventoryController`), son icône, le contrat du modèle `POT_Speed`, et ce qui la cite : `AdminService`, `AntiCheatService`, `StatsService`, `TelemetryService`, les attributs de test (`PotionTest`). Vérifier si la tuile `PotionTime` de l'arbre en dépend (elle allonge toutes les potions : elle reste pour les autres). Les potions déjà dans les profils : à vider à la remise à zéro.
6. **Hydraulic Gloves** : rien à changer, il casse la zone 6 seul (choix de Cantin).
7. **Chrono de police et braquage** : le chrono qui démarre au premier coup (affiché aujourd'hui « HEIST: 13s ») passe de 13 à 8 s (`Balance.Window.BreakTimer`) et devient le chrono de police (« POLICE IN 8s », texte à valider avec Clément, liaison L-153), au même rythme que les témoins (`Witness.FillTime = 8`) ; la police arrive s'il finit avant la casse ; le chrono « HEIST » après la casse passe de 10 à 6 s (`Balance.Heist.Duration`) ; `Balance.Hit.MaxHitsPerSecond` passe de 10 à 5 ; PV des vitrines recalculés (zones 1 à 5 : un joueur seul au niveau conseillé en 6,5 s ; zone 6 : deux joueurs en 8 s, pas un seul ; passe 3, `agents/a138`).
8. **Remise à zéro des profils DEV** quand les nouvelles valeurs arrivent (le profil de Cantin compris), avec son accord au moment de le faire.

## Côté Clément (liaison)

Plus de banc : son modèle de banc et ses animations `BenchLift` et `BenchIdle` ne servent plus. L'aura devient le multiplicateur de force. La potion de force passe à ×1,5. La zone 6 demande au moins 2 joueurs. De nouvelles valeurs arrivent.
