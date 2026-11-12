# UI_Admin : écran admin, version grise (2026-11-12)

Construit dans Studio par `tools/clement/admin_build.luau`. Aucun script. Rien n'est commité.

## Noms pour la liaison

1. `UI_HUD.AdminButton` : TextButton **caché**, à droite au milieu de l'écran, avec `AdminLabel` « ADMIN » et `Shade`. Il fait au moins 44 px.
   - Le code le montre seulement aux admins (Clément, Ironix), et il ouvre `UI_Admin`.
2. `StarterGui/UI_Admin` : ScreenGui caché, `ScreenGroup=Menu`, `DisplayOrder` 50.
   - `Root.Header` contient `Title` et `CloseButton` ;
   - `Root.Body` est un ScrollingFrame vertical qui contient les sections ;
   - `Root.StatusLabel` : le code y écrit le résultat de la dernière action (« Gave $1M to Cantin »).
3. **Toutes les listes** sont un ScrollingFrame horizontal, avec un `Template` caché (TextButton) que le code clone : `EntryName` (le texte) et `Selected` (contour jaune, caché, allumé sur l'entrée choisie).
4. `Body.TargetSection` : `TargetLabel` (« Target: you ») et `PlayerList` (les joueurs du serveur).
   - Le joueur choisi est la cible de **toutes** les actions de l'écran ; c'est soi-même par défaut.
5. `Body.StatsSection` : `CashRow`, `SpeedRow` et `StrengthRow`.
   - Chaque ligne a un TextBox (`CashBox`, `SpeedBox`, `StrengthBox`) et un bouton (`GiveCashButton`, `GiveSpeedButton`, `GiveStrengthButton`).
   - Le code lit le nombre tapé.
6. `Body.BaseSection` : `TreadmillRow`, `BenchRow`, `ShopLevelRow` et `RayonsRow`.
   - TextBox : `TreadmillBox`, `BenchBox`, `ShopLevelBox`, `RayonsBox`.
   - Boutons : `SetTreadmillButton` (palier du tapis), `SetBenchButton` (palier du banc), `SetShopLevelButton` (niveau de boutique) et `SetRayonsButton` (nombre de rayons).
7. `Body.GiveSection` :
   - `KindRow` : `ItemKindButton`, `BoxKindButton`, `AuraKindButton`, `TrailKindButton`, `PotionKindButton` et `GamepassKindButton`. Chacun a `Label`, `Shade` et `Selected`, allumé sur la sorte choisie.
   - `SearchRow.SearchBox` filtre la liste.
   - `ChoiceList` : les entrées de la sorte choisie.
     - Item : les objets de `Config/Items` ;
     - Box : les raretés (un colis de cette rareté) ;
     - Aura et Trail : les auras et les trails ;
     - Potion : les potions ;
     - Gamepass : le VIP et les gamepasses.
   - `MutationTitle` et `MutationList` : None, puis les mutations de `Config/Mutations`. Elles servent seulement pour un objet.
   - `GiveRow.GiveButton` donne le choix au joueur ciblé.
8. `Body.EventsSection.EventList` : une entrée par événement (Truck, Night, Day, Rain, et les prochains). Un clic lance l'événement sur le serveur.
9. `Body.TeleportSection.ZoneList` : Safe zone, puis Zone 1 à Zone 6. Un clic téléporte le joueur ciblé.
10. `Body.DangerSection.ResetRow.ResetProfileButton` (rouge, avec `Label`) : il remet le profil à zéro en **deux clics**. Au premier clic, le code écrit « Click again to confirm ».
11. **Serveur** : chaque action passe par un remote vérifié côté serveur. Le serveur refuse tout joueur qui n'est pas admin (section 9.4), même si le client montre l'écran.
12. **Tailles** : lignes de 44 px, fenêtre d'au moins 560 × 300. Mesuré en 1920 × 1080 et en 844 × 390 : aucun texte ne déborde, et le bouton ne touche rien.
