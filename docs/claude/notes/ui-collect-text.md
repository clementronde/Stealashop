# Texte d'argent flottant au-dessus des plaques (validé par Clément, 2026-11-12)

Référence de Clément : une capture d'un jeu du même genre. Au-dessus de la plaque verte de chaque objet flottent « Collect » en blanc, le montant en grand en vert et, s'il y en a, « (Offline cash: $X) » en petit gris. Le texte n'a pas de fond, il a un contour noir, et il rapetisse avec la distance.

- **Aperçu** : `tools/clement/collect_text_preview.luau` (Edit, CoreGui, boutique 1). Validé par Clément.
- **Construction prête, pas lancée** : `tools/clement/collect_text_build.luau`. Elle traite 44 plaques : `PLOT_Shop`, `PLOT_Shop_Rayons` et les 6 boutiques du hub. Elle attend le changement du contrat (ci-dessous).

## Pour la liaison (Ironix) : changement de contrat, à faire avant la pose

1. `CollectPad_xx/Plate/AmountGui` passe de **SurfaceGui** à **BillboardGui**.
   - Le nom ne change pas, ni le chemin `AmountGui.Amount` : `DisplayService` écrit toujours le montant au même endroit.
   - À changer : `Contract/Models.luau`, ligne 142 (`Class = "BillboardGui"`), et le tableau 10.4 du doc.
   - Sinon, le ContractChecker affichera 44 lignes rouges dès que Clément posera les nouveaux textes.
2. Dans `AmountGui`, deux éléments sont ajoutés :
   - `CollectLabel` « Collect », texte fixe ;
   - `OfflineLabel`, caché : le code peut y écrire « (Offline cash: $X) » et le montrer quand une partie du montant vient des gains hors ligne. C'est facultatif.
3. Une proposition : cacher `AmountGui` (`Enabled = false`) quand le présentoir est vide, ou que le montant vaut $0.
4. Clément lance `collect_text_build.luau` quand le contrat est passé. Ironix le dit dans la liaison.
