# Ressenti de l'UI, sons, victoire en zone safe, arrivée du camion (2026-11-10, demande de Clément)

Demande de Clément : même ressenti que l'inventaire dans toutes les UI (Rebirth, Index, boutiques…), barre de vie de la vitre invisible, aucune victoire en arrivant en zone safe avec un colis, sound design à revoir, et le camion qui apparaît sans arriver. Tout est construit dans Studio, sans script. Rien n'est commité.

## Fait dans Studio (Edit)

- **Barre de vie de la vitre** : `ReplicatedStorage/Assets/UI/BB_WindowHP.AlwaysOnTop = true`. Elle était cachée par `Facade.Frame_T` (à 5,45 studs au-dessus du centre de la vitre).
- **Sons** : 30 `Sound` dans `ReplicatedStorage/Assets/Sounds`, tous chargés (PreloadAsync). Uniquement des bibliothèques sous licence : Roblox, ProSoundEffects et APM.
  - Les 14 noms que le code cherche déjà, à la racine : `HitWindow_Impact`, `HitWindowHeavy_Impact`, `SwingBat_Impact`, `Catch_Impact`, `Unbox_Open`, `Chase_Heartbeat` (en boucle), `TheftAlert_Siren`, `Unbox_UpgradeCharge`, `Unbox_UpgradePop`, `Unbox_Whoosh`, `Unbox_Riser`, `Unbox_Stop`, `Unbox_Swell`, `Unbox_Confetti`.
  - Nouveaux, à brancher : `Heist/Heist_Escape`, `Truck/SFX_TruckArrive` (klaxon), `Truck/SFX_TruckBrake` (freins à air), `Training/Train_Gain` (gain du tapis ou du banc), `Cash/Cash_Collect` (ramassage de l'argent).
  - Interface : `UI/UI_Hover`, `UI/UI_Click`, `UI/UI_Open`, `UI/UI_Close`, `UI/UI_Success`, `UI/UI_Deny`, et les 5 clics au choix dans `UI/Clicks` (`UI_Click_Classic`, `_Sharp`, `_Tick`, `_Bubble`, `_Soft`).
  - Premiers choix, pas encore écoutés par Clément : il les validera en Play.
- **Même ressenti dans les menus** : un calque `Shade` (cadre noir caché, coins du bouton) dans 65 boutons (HUD, boutiques, Index, Rebirth, Rewards, arbre, Unbox, tutoriel). Un contour `HoverOutline` (caché, blanc, 3 px) sur 42 cartes (`Template` et `Preview_n`). Les icônes des cartes sont déjà hors du cadre coupé (`Clip`) : elles peuvent sortir au survol. Les onglets et les tuiles de l'arbre, transparents, n'ont pas de `Shade` : au survol, leur icône grossit et penche.
- **`UI_Settings`** : la rangée `ClickRow` (CLICK SOUND, `PrevButton`, `ChoiceLabel`, `NextButton`) est reportée dans StarterGui.

## Coup dans le vide (retour de Clément : « pas de son au clic avec l'arme dans la main »)

- Le code joue l'animation du coup même dans le vide, avec le son de son marqueur `Impact`. Ce son est maintenant un souffle, pas un impact : le contact a déjà son propre son (`Glass_Hit` sur une vitre, `SFX_TruckHit` sur le camion).
  - `HitWindow_Impact` : souffle rapide, 9120972321 ;
  - `HitWindowHeavy_Impact` : souffle lourd, 9120728815 ;
  - `SwingBat_Impact` : souffle de batte, 9113305619.
- Vérifié en Play : un clic dans le vide avec le Marteau, puis avec la batte, joue le souffle (pics de 267 et 419).
- **Pour Ironix** : la batte n'a plus de son quand elle touche. Nouveau son **`SwingBat_Hit`** (9113500863), à jouer quand le serveur confirme un coup sur un joueur ou un vigile.

## Victoire en zone safe

Aujourd'hui, `GuardService` abandonne la poursuite (« zone safe ») et envoie `ChaseState(false)` sans raison : le client ne peut pas savoir que c'est une victoire.

- **Proposé pour Ironix** : un événement à l'entrée en zone safe avec un colis volé (poursuivi ou non), par exemple `HeistEscaped(tier)`, ou une raison dans `ChaseState`.
- **Ce que le client joue** :
  - **`ReplicatedStorage/Assets/FX/FX_Escape`** : Model, `Root` (pièce invisible, à poser aux pieds), `Root.Burst` (`Confetti` 70, `Stars` 24, `Light` avec `FadeTime` 0,5) et `Root.Ground` (`Ring` 1). Chaque émetteur porte `EmitCount` ; le modèle porte `Duration` = 2. Même forme que `FX_TruckExplosion`.
  - **`StarterGui/UI_Escape`** (caché, sans `ScreenGroup`) : `Banner` avec `Rays` (tourne, 40°/s), `Glow` (pulse), `Title` (« ESCAPED! »), `Subtitle` (« Take the box to your shop! ») et `BoxIcon` (le code y met `ICON_BOX_<Tier>`). Texte vérifié de 1920×1080 à 667×375.
  - Le son `Heist_Escape` et l'animation `Celebrate` du joueur.
- **Animation proposée** : bannière 0 → 1 en 0,35 s (Back Out), titre de −14° à −3°, icône puis sous-titre 0,07 s après, tenue 2,2 s, sortie en 0,15 s (Quad In).

## Arrivée du camion

Aujourd'hui, le camion apparaît d'un coup (`PivotTo`, puis Notify « A truck appeared… »).

- **Proposé** : il arrive en roulant le long de la rue (axe X, cabine devant), depuis 90 studs, en 3 s (Quad Out). Il pivote doucement vers sa place, puis son nez plonge de 2,5° au freinage et revient (0,12 s, puis 0,3 s Back).
- **Sons** : `SFX_TruckArrive` au départ, `SFX_TruckBrake` à 78 % du trajet.
- **Effet** : **`Assets/FX/FX_TruckDust`**, de la poussière aux 4 roues : `Root`, 4 attachments `Wheel*`, émetteurs `Dust` (`EmitCount` 10), `Duration` 2,5.
- **Pour Ironix** : le message « A truck appeared » à la fin de l'arrivée, et le camion frappable seulement une fois arrêté.
- **Testé en Play** : en zone 1, le camion part de X −16 et s'arrête à X 73,75 en ralentissant, puis le vrai camion réapparaît. En zone 1, ce départ est dans l'entrée du couloir : il faudra sans doute un point de départ par zone dans la map (`TruckEntry`, nom à valider).

## Valeurs proposées pour `Config/UiMotion`

Elles viennent de l'analyse de la vidéo (`docs/claude/notes/ui-reference-ressenti.md`) et Clément les a validées sur l'inventaire. Aujourd'hui, les valeurs V0 sont Open 0,9 en 0,25 s et Hover 1,08.

| Nom | Valeur |
| --- | --- |
| Open | 0,55 → 1 en 0,14 s, Back Out |
| Éléments un par un | départ à 0,08 s, écart de 0,035 s, 0 → 1 en 0,14 s (Back), 14 au plus |
| Close | 1 → 0 en 0,09 s, Quad In |
| Changement d'onglet | sortie de droite à gauche (écart de 0,03 s, 0,1 s), puis entrée comme à l'ouverture |
| Hover (bouton) | × 1,06 en 0,08 s ; `Shade` de 1 à 0,78 |
| Press | × 0,95 en 0,05 s, `Shade` 0,62 ; relâché en 0,2 s (Back) |
| Hover (carte) | icône × 1,1, −5°, décalée de (0,02 ; −0,015) en 0,1 s (Back) ; `HoverOutline` visible ; retour en 0,12 s |
| Réussite (Buy, Equip, Claim, Confirm, Place) | `UI_Success` 0,12 s après le clic ; le bouton passe à × 1,22 puis revient en 0,28 s (Back) |

- **Sons d'interface** : `UI_Hover` à chaque début de survol, le clic choisi à chaque `Activated`, `UI_Open` et `UI_Close` sur les fenêtres, `UI_Deny` quand l'argent manque.
- **Attributs proposés** (rappel de `ui-settings.md`) : `ClickSound` (CLASSIC, SHARP, TICK, BUBBLE ou SOFT → `UI_Click_<Nom>`), `SfxVolume`, `VfxEnabled`.

## Prototype

`tools/clement/ui_feel_proto.luau`, à lancer en Play, côté client. Il travaille sur des copies des écrans et du HUD.

- **Menus** : copie de la barre de gauche et de la rangée sociale ; touches J (armes), K (auras), L (arbre de compétences).
- **Victoire** : automatique en entrant en zone safe avec un colis (attribut `Carrying`), ou touche H.
- **Camion** : l'arrivée se joue sur chaque `EventTruck` qui apparaît (`workspace:SetAttribute("TruckSpawnNow", 1)` côté serveur) ; touche T pour la rejouer.
- Arrêt : `_G.UiFeel.Stop()`.

Lancé en Play le 2026-11-10 avec l'accord de Clément.
- Les 9 menus s'ouvrent sans erreur ; tous leurs boutons et toutes leurs cartes réagissent.
- La victoire joue l'effet, la bannière et `Celebrate`, puis tout disparaît après 2,9 s.
- L'arrivée du camion fonctionne.
- Aucun avertissement dans la sortie, contrat OK.

Noms à valider avant le contrat 2.2 et 10.4 : `UI_Escape` et ses enfants, `FX_Escape`, `FX_TruckDust`, `Shade`, `HoverOutline`, et les noms des sons.
