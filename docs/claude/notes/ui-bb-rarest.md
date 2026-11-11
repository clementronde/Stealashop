# BB_Rarest : fait dans la place DEV (2026-11-08)

`ReplicatedStorage/Assets/UI/BB_Rarest` (BillboardGui), sans script, textes en anglais.

- **Forme** : une plaque bleu nuit à studs, avec un bord doré et un contour noir, surmontée d'une couronne (`CrownIcon`, image du groupe 117932214637008) devant des rayons dorés.
- **Textes, dans `Plaque.Content`** :
  - `Title` : « RAREST PULL », en dégradé or ;
  - `Rarity` : la rareté en capitales (exemple « MYTHIC » en rouge) ; le code met la couleur de la rareté, comme sur les colis portés ;
  - `ItemName` : le nom de l'objet, en blanc ;
  - `Odds` : la mutation et la chance (« Normal · 1 in 400 »), en bleu clair.
- **Taille** : 8 studs + 120 px de large sur 4,6 studs + 70 px de haut. `SizeOffset (0, 0.5)` met le bas au point d'accroche, `StudsOffset (0, 0.6, 0)`, `MaxDistance` 200, `LightInfluence` 0.
- **Mesuré** avec « Golden Graphics Card », « Diamond · 1 in 25,000 » et « Donut » : tout tient. Le titre fait 48 px à 15 studs, 22 px à 50 studs et 14 px à 150 studs ; la couronne ne touche pas le titre.
- **Point d'accroche, nom proposé** : il n'existe pas encore de socle « objet le plus rare » devant les boutiques (rien dans `Map/Hub`). Je propose un Attachment `RarestPoint` en haut de ce socle, posé par la session du hub, sur lequel le code accroche le billboard.

## Noms proposés (contrat 2.2)

- `BB_Rarest` : `Title`, `Rarity`, `ItemName`, `Odds`.
- `CrownIcon`, `Rays`, `Plaque` et `Content` sont du décor, que le code ne touche pas.
- `RarestPoint` (Attachment du socle) est à ajouter au contrat 10.4 du modèle de parcelle.
