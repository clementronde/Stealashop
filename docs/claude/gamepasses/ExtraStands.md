# +4 DISPLAYS (`ExtraStands`) — fiche gamepass

Statut : **proposition, à valider par Clément** (2026-11-21). Rien créé sur Roblox. **Bloqué par la map** (voir plus bas).

| Champ | Contenu |
|---|---|
| Clé | `ExtraStands` (`Order = 6`) |
| Nom | **+4 DISPLAYS** (inchangé) |
| Effet exact | `Stands = 4` présentoirs au-delà du maximum de 20 : `DisplaySlot_21` à `_24` (DisplayService.GetExtraSlots), **s'ils sont posés dans la boutique**. |
| **Bloquant** | Vérifié dans Studio le 2026-11-21 (lecture seule) : **aucune parcelle n'a `DisplaySlot_21` à `_24`** (`PLOT_Shop_01` à `_06`, le modèle `ReplicatedStorage/Assets/Plots/PLOT_Shop` : maximum 20). Vendu aujourd'hui, le pass ne donnerait rien. À ne **pas** créer sur le Creator Hub avant que les 4 présentoirs existent. |
| Équilibre | 4 objets exposés de plus = jusqu'à +20 % de revenus pour une boutique pleine (24 au lieu de 20), et 4 objets de plus à voler pour les autres : ça nourrit aussi le vol entre joueurs. Sain. |
| Prix actuel | 349 R$ |
| **Prix proposé** | **349 R$, inchangé** (seul repère : « Extra Stalls » +2 de Steal a Wild Horse, retiré de la vente). |
| Description (page Roblox) | `4 extra display stands in your shop. More items on show, more cash!` |
| Ligne de carte | `4 extra display stands` (inchangée) |
| Place dans la boutique | Gamepasses, après Fast Unlock. |
| Icône | `UI_Icon_GP_Displays` (existe, aussi sur le bouton `Displays` du HUD : gemme sur un socle). Concept famille : présentoir avec un objet brillant, **« +4 » en gros** en bas à droite, médaillon rose `E05AD8`. Garder la même icône que le HUD, ou en faire une version « +4 » à part (le bouton du HUD n'est pas le gamepass). |

## Pour Clément (map)
- Poser `DisplaySlot_21` à `_24` (et `CollectPad_21` à `_24` si Ironix confirme qu'il les attend) dans `PLOT_Shop` et les 6 boutiques, cachés pour qui n'a pas le pass si c'est la règle d'Ironix.

## Pour Ironix
- Confirmer à Clément ce que le code attend pour les présentoirs 21 à 24 (DisplaySlot seul, ou aussi CollectPad ; montrés ou cachés sans le pass), le commentaire de DisplayService ne parle que de `CollectPad_01` à `_20`.
- Tant que les présentoirs n'existent pas : laisser `Ready = false` (ou vérifier au démarrage que la parcelle a bien les slots), pour qu'aucun Id créé par erreur ne vende du vide.

## Questions
- Clément : tu poses les 4 présentoirs avant la MAJ 1 ? Sinon, ce pass attend.
- Clément : même icône que le bouton du HUD, ou une icône « +4 » à part ?
