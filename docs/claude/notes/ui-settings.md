# UI_Settings : écran des réglages (2026-11-10, demande de Clément)

Demande de Clément : « un bouton paramètres pour gérer les paramètres du jeu, dont le son de la musique et des VFX ». Construit dans Studio, sans script, avec un prototype jouable. Rien n'est commité.

## Dans Studio

- **`StarterGui/UI_Settings`** : caché, `ScreenGroup = "Menu"`.
  - Même fenêtre que les boutiques, bandeau gris-bleu, titre « Settings », `CloseButton`. `Root` est plus étroit (rapport 1,3, minimum 470 × 362).
  - `Rows` contient 3 rangées :
    - **`MusicRow`** : `Icon`, `RowLabel` (« MUSIC »), `Slider` (avec `Track`, un TextButton qui contient `Fill`, et `Knob`, un TextButton), et `ValueLabel` (« 80% ») ;
    - **`SoundRow`** : pareil, « SOUND EFFECTS », 100 % ;
    - **`VfxRow`** : `Icon`, `RowLabel` (« VISUAL EFFECTS ») et `Toggle` (TextButton), avec `OnFill` (vert), `OffFill` (gris), `ToggleLabel` (« ON » ou « OFF ») et `ToggleKnob`.
  - Chaque bouton a son calque `Shade`.
- **`UI_HUD.SocialRow.SettingsButton`** : engrenage gris-bleu, à droite d'Invite et Rewards, avec `SettingsIcon` et `SettingsLabel`. Il est **caché** tant que le code ne l'affiche pas, comme `InventoryButton`.
- **Tailles testées** (de 1920×1080 à 667×375) : aucun texte ne déborde.
  - Le bouton rond du curseur fait au moins 44 px, et l'interrupteur et le X 44 px de haut au minimum.
  - Sur téléphone, la fenêtre fait 452 × 327.
- **Icônes à importer par Clément** : `StealAShop-Art/UI/_A_importer_settings/` contient `UI_Icon_Settings`, `UI_Icon_Music`, `UI_Icon_Sound` et `UI_Icon_Vfx` (dessinées avec le contour bleu nuit de l'UI). Je les branche ensuite sur leur attribut `IconAsset`. En attendant, le prototype affiche des émojis.
- **Prototype** : `tools/clement/settings_proto.luau`, lancé en Edit dans `CoreGui/_PROTO_Settings`.
  - L'engrenage du HUD ouvre et ferme la fenêtre, avec la même animation que l'inventaire.
  - On glisse les curseurs, par le bouton rond ou en cliquant sur la barre, et le pourcentage suit.
  - L'interrupteur bascule entre ON et OFF.
  - Arrêt : `_G.SettingsProto.Stop()`.

## Sons : ce qu'on a appris

En Edit, Studio ne joue pas les sons du prototype (`PlayLocalSound`) : Clément n'en entend aucun. En Play, il entend bien la musique. Les sons de l'interface ne se testent donc qu'en Play, avec le code.

## Pour Ironix

- **Musique** : le curseur règle l'attribut **`MusicVolume`** du Player (de 0 à 1), que `MusicController` lit déjà (`Config/Music.VolumeAttribute`).
- **Effets sonores** : attribut proposé **`SfxVolume`** (de 0 à 1). Il s'applique à un `SoundGroup` des effets (UI, achats, coups). Il n'en existe aucun dans la place pour l'instant : à créer côté code.
- **Effets visuels** : attribut proposé **`VfxEnabled`** (booléen). À OFF, moins de particules (auras, traînées, éclats, chiffres de dégâts), pour les téléphones peu puissants.
- **Sauvegarde** : ces 3 réglages vont dans le profil pour être retrouvés à la reconnexion. Le code les pose côté client dès le chargement.
- **Bouton** : `SettingsButton` est à afficher par `Features`, comme les autres.
- **Animations** : mêmes valeurs que l'inventaire. Pendant le glisser, le bouton rond passe à × 1,18 ; l'interrupteur glisse en 0,16 s (Back Out).
- **Noms à valider** avant le contrat 2.2.

## Icônes importées et branchées (2026-11-10)

- `UI_Icon_Music` (131190578712685) sur `MusicRow.Icon`.
- `UI_Icon_Sound` (129520563545053) sur `SoundRow.Icon`.
- `UI_Icon_Vfx` (87021920953592) sur `VfxRow.Icon`.
- `UI_Icon_Settings` (96039690137195) sur `UI_HUD.SocialRow.SettingsButton.SettingsIcon`.

Les 4 images se chargent. Le prototype affiche les vraies icônes.

## Choix du son de clic (2026-11-10, demande de Clément)

- **Nouvelle rangée `ClickRow`** (« CLICK SOUND ») entre SOUND EFFECTS et VISUAL EFFECTS. Elle contient `Icon`, `RowLabel`, `PrevButton` (« < »), `ChoiceLabel` (le nom du son) et `NextButton` (« > »).
  - Changer de son le joue tout de suite, et c'est lui qu'on entend ensuite sur tous les clics (testé en Play, avec l'inventaire).
  - Les 4 rangées font maintenant 0,215 de haut, avec un écart de 0,04.
  - Essayée en Play sur une copie, puis reportée dans `StarterGui/UI_Settings` (Edit, sans script).
- **Sons proposés** (volume mesuré en Play, au volume 1) :
  - CLASSIC : Roblox_UI_Bright_Click, 15675059323 (211) ;
  - SHARP : UI Click 2, 116080744084010 (103) ;
  - TICK : ui-simple-button-click, 88442833509532 (64) ;
  - BUBBLE : ui-bubble-click, 77120543307812 (246) ;
  - SOFT : RBLX UI Select 01, 10128760939 (35).
- **Pour Ironix** :
  - attribut proposé **`ClickSound`** (nom du choix : CLASSIC, SHARP, TICK, BUBBLE ou SOFT) ; le son de clic de toute l'interface suit ce choix ;
  - le curseur SOUND EFFECTS règle le volume de tous les sons d'interface ;
  - le curseur MUSIC règle déjà `MusicVolume`, testé en Play : `MusicController` suit le changement en direct.
- Pour le test, la musique de fond est coupée (`MusicVolume` = 0, curseur MUSIC à 0 %). Elle revient à l'arrêt du Play, ou avec le curseur.
