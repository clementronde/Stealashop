# Liste complète pour la liaison : écrans de Clément à brancher (2026-11-11)

Noms relevés dans Studio (Edit) le 2026-11-11. « T.n » = ligne n du tableau `docs/claude/notes/ui-motion-skilltree.md`. Aucun script dans l'UI.

## Index (remplace `UI_Index_v2`)

1. `StarterGui/UI_Index_v3` (`ScreenGroup=Menu`) : `IndexController` l'ouvre à la place de `UI_Index_v2` (bouton `LeftRail.IndexButton`) et éteint v2. `Root` s'ouvre et se ferme (T.26 `Open`, T.27 `OpenStagger`, T.28 `Close`).
2. `Root.Window.ListPanel.List.Template` (TextButton caché) : cloné dans `Zone<N>Section.Content.Cards`, une carte par objet de `Config/Items`, par rareté croissante.
   - `Icon` = `ICON_<ItemId>` ; `ItemName`, ou « ??? » si l'objet n'est pas trouvé ;
   - `Clip.BackgroundColor3` = couleur de la rareté, assombrie si l'objet n'est pas trouvé ; `Clip.Glow` et `Clip.Rays` teintés de la rareté ;
   - objet pas trouvé : silhouette = `Icon.ImageColor3` sombre, teinté de la rareté ; `Lock` reste caché ;
   - survol : T.34 `HoverCard` (`HoverOutline`).
3. `Zone<N>Section.ZoneArt` (`ZoneName`, `ZoneIcon`) et `Content.ZoneBar` :
   - `Fill` = part des objets trouvés ; `ZoneCount` « 4/13 » ;
   - `ZoneItem` = l'objet le plus rare de la zone, en silhouette tant qu'il n'est pas trouvé ;
   - `SecretsSection` reste caché (catégorie Secrets).
4. `Root.Window.UnlockedBar.Counter` « Unlocked: 7/83 ». `Root.Window.CloseButton` ferme l'écran (T.30 à T.32).
5. `Root.Window.Detail` : se remplit au **clic** sur une carte (`Template.Activated`, avec le son de clic), jamais au survol.
   - `IconFrame.DetailIcon`, `DetailName`, `DetailRarity` (couleur de la rareté) et `DetailIncome` « $X/s » (`Formulas.ItemIncome`) ;
   - animation T.45 `DetailPop`.
6. `Root.Window.Rewards` : la récompense de la zone visible dans la liste.
   - `RewardsTitle`, `SpeedReward.Amount`, `CashReward.Amount` ;
   - `ClaimButton` (`ClaimLabel`, `Shade`) réclame la récompense (L-083 point 7) ;
   - animations T.46 `RewardsSwap` et T.33 `Success`.
7. `Root.Categories` : `NormalButton`, `SecretsButton` et `MutationsButton`, chacun avec `Label`, `Shade` et `Selected`.
   - Normal = les zones ; Secrets = `SecretsSection` ; Mutations = montre `MutationTabs` et `MutationCaption`.
   - Animation T.29 `Swap`.
8. `Root.MutationTabs.<Effet>Tab` (de `ShinyTab` à `RainbowTab`, chacun avec `TabLabel`, `Shade` et `Selected`) et `Root.MutationCaption` : filtrent par mutation (`Config/Mutations`). Animation T.29 `Swap`.

## Réglages

9. `UI_HUD.SocialRow.SettingsButton` (caché ; `SettingsIcon`, `SettingsLabel`, `Shade`) : à montrer par `Features`. Il ouvre `UI_Settings` (T.30 à T.32).
10. `StarterGui/UI_Settings` (`ScreenGroup=Menu`) : `Root.Window.CloseButton` ferme l'écran. Ouverture et fermeture : T.26 à T.28.
11. `Root.Window.Rows.MusicRow` et `SoundRow` :
    - `Slider.Track` (TextButton qui contient `Fill`), `Slider.Knob` (TextButton) et `ValueLabel` « 80% » ;
    - on glisse le bouton rond ou on clique sur la barre : ça règle l'attribut du Player `MusicVolume` (déjà lu par `MusicController`) ou `SfxVolume` (0 à 1, `SoundGroup` des effets à créer) ;
    - les réglages sont sauvegardés dans le profil ;
    - animation T.47 `KnobGrab`.
12. `Rows.VfxRow.Toggle` (`OnFill`, `OffFill`, `ToggleLabel` ON/OFF, `ToggleKnob`) : règle `VfxEnabled` (OFF = moins de particules). Sauvegardé. Animation T.48 `ToggleSlide`.
13. `Rows.ClickRow` :
    - `PrevButton` et `NextButton` changent le son de clic, et `ChoiceLabel` affiche son nom ;
    - 5 sons : CLASSIC 15675059323, SHARP 116080744084010, TICK 88442833509532, BUBBLE 77120543307812, SOFT 10128760939 ;
    - le son choisi se joue tout de suite, puis sert à tous les clics. Sauvegardé ;
    - animations T.30 à T.32.

## Argent hors ligne, messages du bas, zone safe

14. `StarterGui/UI_Offline` (`ScreenGroup=Menu`) : s'ouvre au retour s'il y a des gains hors ligne, à la place du Notify « Your shop earned … while you were away ».
    - `Root.Window.Amount` = le montant ;
    - `ClaimButton` (`Content.ClaimLabel`) encaisse ;
    - `DoubleButton` (`Content.PriceLabel`, `RobuxIcon`, `TwoXTag`) double le montant contre des Robux : produit à créer, bouton caché d'ici là ;
    - animations T.26 et T.33 ;
    - **ne pas faire voler `Flyer`** tant que Clément n'a pas confirmé : il ne veut plus de case qui vole (2026-11-11).
15. `StarterGui/UI_Toast.Stack.Template` (TextLabel caché) : une copie par message, en bas au centre, 3 au plus.
    - réussite en vert `5dff3a`, information en blanc ;
    - remplace les Notify de réussite : objet équipé, achat, colis en sécurité ;
    - ne pas montrer le Notify « Box saved… » en zone safe : la bannière ESCAPED! dit déjà la même chose ;
    - animation T.35 `Toast`.
16. `StarterGui/UI_Escape` (sans `ScreenGroup`) : à l'entrée en zone safe avec un colis.
    - `Flash` : plein écran doré, transparence 1 au repos ;
    - `Banner` : `Title` « ESCAPED! », `Subtitle`, `BoxIcon` = `ICON_BOX_<Tier>` ;
    - sons `Heist_SafeFlash`, puis `Heist_Escape` 0,12 s après ; l'écran s'éteint au bout de 2,3 s ;
    - animation T.44 `SafeFlash`.

## Déjà en cours chez Ironix (L-092, L-094), pour mémoire

17. `UI_Chase` :
    - `RunBanner` (`RunLabel`) : T.40 ;
    - `ScreenEdges.Left`, `Right`, `Bottom` et `Vignette.Edge` : T.41 (cibles corrigées dans 326e618) ;
    - `Assets/FX/FX_ChaseHighlight` sur le vigile pendant la poursuite : T.42. Pas encore codé.
18. `UI_HUD.HeistTimer.Box` : un tic à chaque seconde ; sous 3 s, le chiffre passe en rouge `E8413C`. T.39.
19. `Assets/UI/BB_Gain` :
    - `GainKind`, avec `<Kind>Color` et `<Kind>Icon` (L-092) ;
    - plus petit depuis le 2026-11-11 ;
    - au ramassage, c'est le seul retour visuel : y ajouter le son `Cash_Collect` ;
    - `UI_HUD.CashFly.Template` est supprimé : retirer le vol de la case dans `GainController` ;
    - T.36 et T.38.
20. `UI_Inventory` :
    - les noms **ne changent pas** (`ToolsTab`, `ToolsSection`, texte « WEAPONS ») ;
    - ordre Items, Boxes, Potions, Weapons par `LayoutOrder` ;
    - contrat complet (58 éléments sur 58) ;
    - animations : L-094 (T.26 à T.34).
21. `Assets/UI/UpgradeSign` : plus petit, mêmes noms. Rien à changer dans le code.
## Barre du bas : `UI_Hotbar` (choisie par Clément le 2026-11-11)

Clément garde la barre de test, pas la maquette Figma `UI_HUD.Hotbar`. La barre Roblox reste coupée, et `UI_Inventory` reste l'écran complet.

22. `StarterGui/UI_Hotbar.Bar` : en bas au centre, `UIListLayout` horizontal centré, cases d'au moins 50 px (`UISizeConstraint`).
    - Attributs `SlotCount` = 6 (PC) et `TouchSlotCount` = 4 (téléphone) : le nombre de cases affichées.
    - À 844 × 390, 4 cases tiennent entre l'argent et le compteur de nuit (x 310 à 534).
    - La barre se cache pendant la poursuite, comme dans le prototype.
23. `Bar.Template` (TextButton caché) : cloné, une copie par case. Ordre : outil de casse, batte, puis les colis et objets tenus ou gagnés, du plus récent au plus ancien.
    - `Icon` : `ICON_TOOL_<Id>`, `ICON_BOX_<Tier>` ou `ICON_<ItemId>` ;
    - `Clip.BackgroundColor3` = couleur de la rareté assombrie de 45 % ; `Clip.Glow.ImageColor3` = couleur de la rareté ; les outils gardent le fond du modèle ;
    - `KeyLabel` : « 1 » à « 6 », caché sur téléphone ;
    - `ItemName` : le nom ;
    - `Income` : « $X/s » au-dessus de la case, pour les objets seulement, caché sinon ;
    - `Equipped` : contour vert, visible sur la case tenue en main ;
    - `HoverOutline` : contour blanc au survol.
24. Jeu : touches 1 à 6 sur PC, clic ou appui partout. Choisir une case l'équipe ; la choisir encore la range.
    - Survol : T.34 `HoverCard` (`Icon` × 1,12, −6°, `HoverOutline`) ;
    - appui et relâché : T.31 `Press` et T.32 `Release` ;
    - équipement : T.33 `Success` et son `UI_Equip`.
25. Petit téléphone (667 × 375) : il n'y a que 152 px libres entre l'argent et le compteur de nuit. Même 3 cases y touchent l'argent (de 16 px environ) : à revoir avec Clément.
