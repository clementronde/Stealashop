# UpgradeSign et BB_Collect : fait dans la place DEV (2026-11-08)

Deux gabarits dans `ReplicatedStorage/Assets/UI`, sans aucun script, textes en anglais, sans Play. `BB_Upgrade` n'a pas été touché : il reste là tant que le code l'utilise.

- **`UpgradeSign`** (Model, 6 × 7,4 × 1,6 studs). Pivot en bas au centre, `PrimaryPart` = `Base`. Face avant = LookVector du pivot (−Z) : le code le pose avec `PivotTo` sur le sol, devant `UpgradePoint` (tapis, banc), `StageUpgradePoint` (boutique) ou `DisplayUpgradePoint` (présentoir suivant). Pièces `Base`, `Post` et `Board` ancrées, sans collision. Le bord noir de `Board` fait le gros contour.
  - `Board/SignGui` (SurfaceGui sur la face avant, 60 pixels par stud, `LightInfluence` 0, `MaxDistance` 80) : une plaque bleu nuit à studs avec, de haut en bas :
    - `Title` (« Upgrade », blanc à contour noir) ;
    - `Level` (« Level 5 > Level 6 », dégradé vert) ;
    - `BuyButton` (TextButton vert, avec `Icon` argent et `Price` « $1.2K ») ;
    - `RobuxButton` (TextButton violet, avec `Icon` Robux et `Price` « 49 »).
  - Une liste verticale centrée range ces éléments : si le code cache `RobuxButton`, le reste se recentre.
  - Testé avec « Display Stand », « Level 19 > Level 20 », « $999.9B » et « 1,499 » : tout tient.
  - **Pour Ironix** : `Icon` et `Price` existent deux fois dans le panneau. Il faut donc les chercher par chemin : `BuyButton.Price`, `RobuxButton.Price`. Les boutons d'un SurfaceGui posé dans Workspace ne reçoivent pas les clics. Pour qu'ils soient cliquables, mettre une copie du SurfaceGui dans PlayerGui avec `Adornee = Board`. Sinon, garder l'invite (touche F).
- **`BB_Collect`** (BillboardGui) : même construction que `BB_Item`. Taille 4 studs + 100 px sur 1,3 stud + 46 px. `SizeOffset (0, 0.5)` : le bas du billboard est au point d'accroche. `MaxDistance` 30 (lisible de près seulement), `LightInfluence` 0. Il contient `Label` (« Collect », blanc) au-dessus de `Amount` (« $1,250 », dégradé vert comme l'argent du HUD), tous deux à contour noir. Texte de 36 px à 30 studs, et plus de près. « $999.9B » tient.

## Noms proposés (à valider par Ironix, puis contrats 2.2 et 10.4)

- `UpgradeSign` (gabarit Model) : `SignGui`, `Title`, `Level`, `BuyButton` (`Icon`, `Price`), `RobuxButton` (`Icon`, `Price`). Points d'accroche : `UpgradePoint`, `StageUpgradePoint`, `DisplayUpgradePoint`.
- `BB_Collect` : `Label`, `Amount`.

## UpgradeSign v2, d'après l'image de référence de Clément (2026-11-08, L-082 point 1)

- **Modèle** `ReplicatedStorage/Assets/UI/UpgradeSign`, refait à neuf (l'ancien, en bleu nuit à studs, est remplacé). C'est un panneau de 7 × 4,5 studs sur un pied court et carré (`Foot` et `FootBase`), 6,1 studs de haut en tout. Le pivot est au sol, au centre, la face avant vers −Z. Pièces ancrées, sans collision, aucun script.
- **`Board/SignGui`** (SurfaceGui sur la face avant, 60 pixels par stud, `MaxDistance` 100) :
  - fond `Panel` bleu nuit, matelassé en diagonale (`Quilt`, attribut `IconAsset` = `UI_Tex_Quilt`), avec une bordure plus sombre ;
  - `Title` (« Upgrade », blanc, gros contour noir) et `Level` (« Level 2 > Level 3 », vert vif) ;
  - `BuyButton` (TextButton vert, avec `Icon` argent et `Price` « $60K ») et `RobuxButton` (TextButton violet, avec `Icon` Robux et `Price` « 25 »).
  - Sur les 4 aperçus, tous les textes tiennent (titre de 53 à 67 px, niveau de 40 px, prix de 48 px sur une toile de 420 × 270).
- **Texture à importer par Clément** (au nom de RoundStone Studio) : `StealAShop-Art/UI/_A_importer_upgradesign/UI_Tex_Quilt.png` (motif gris raccordable, teinté en bleu nuit par `ImageColor3`). Sans elle, le fond est bleu nuit uni.
- **Points de pose au sol** (y = 0,3), tournés vers l'allée (−Z de la parcelle), dans `ReplicatedStorage/Assets/Plots/PLOT_Shop` et `PLOT_Shop_01` à `_06`. Les attachments gardent leur parent ; seule leur position change. Coordonnées dans le repère de la parcelle :
  - `UpgradePoint` du tapis (`Treadmill.Frame`) : (−17,25 ; −44), côté intérieur du tapis ;
  - `UpgradePoint` du banc (`Bench.RackTop`) : (17,25 ; −44), côté intérieur du banc. **À valider** : le socle `RarestPedestal` (x 13, z −48,5) et son `BB_Rarest` sont devant la partie gauche du panneau. Côté extérieur, les grands murs `BigWall` cachent le panneau sur les boutiques 01 et 06 ;
  - `StageUpgradePoint` (`UpgradeKiosk`) : (15,1 ; −36,5), à droite de la borne, porte libre ;
  - `DisplayUpgradePoint` (`DisplayKiosk`) : (−15,1 ; −36,5), à gauche de la borne, porte libre.
  - Chaque volume de panneau a été testé sur `PLOT_Shop_01` : il ne touche aucune pièce, sauf le socle déjà cité, devant le banc.
  - **Pour la session du hub** : `tools/clement/hub/hub_place_du_mall.luau` ne connaît pas ces nouvelles positions. Relancer le script du hub remettrait les points en hauteur.
- **Aperçu** : 4 copies dans `Workspace/_PREVIEW_UpgradeSigns`, sur les points de `PLOT_Shop_01`, avec le matelassage dessiné en direct. À supprimer après la validation de Clément.
- **ContractChecker** lancé en Edit : « Contrat : OK · 3 point(s) pas encore livré(s) ». Les 3 points existaient déjà (arches en greybox, animations des conducteurs du camion) ; il n'y a aucune ligne rouge.

### Socle RarestPedestal déplacé (2026-11-08, choix de Clément : « Déplacer le socle »)

- Le socle passe de (13 ; −48,5) à **(7,5 ; −48,5)** dans le repère de la parcelle : il est maintenant devant le battant droit de la porte, sur la terrasse, et non plus devant le panneau du banc. C'est fait dans `PLOT_Shop` et `PLOT_Shop_01` à `_06`. `RarestSlot` et `RarestLabelPoint` suivent, à la même hauteur (3,35 et 9,35).
- Le passage vers la porte reste large : 14,8 studs libres à gauche du socle. Le socle ne touche plus aucune pièce.
- **Vue sur le panneau du banc** : depuis l'allée, aucun rayon n'est coupé de face ni de haut. Seul un regard très en biais, depuis le côté du tapis (x −10), voit 15 % du panneau caché par le socle.
- **ContractChecker** relancé en Edit : toujours « Contrat : OK · 3 point(s) pas encore livré(s) », sans ligne rouge.
- **Pour le script de la boutique** : dans `tools/clement/hub/plot_shop_builder.luau`, `buildRarest` utilise toujours `X = 13`, et le commentaire du contrat (ligne 53) dit « x 13 ». Il faut passer à 7,5. Sinon, reconstruire `PLOT_Shop` remettra le socle à son ancienne place, comme les 4 points des panneaux d'amélioration.
- **Aperçus étendus (2026-11-08)** : Clément regardait `PLOT_Shop_04` et ne voyait rien, car les aperçus n'étaient que sur `PLOT_Shop_01`. Ils sont maintenant sur les 6 boutiques : 24 copies dans `Workspace/_PREVIEW_UpgradeSigns/PLOT_Shop_0n`. Il suffit de supprimer ce dossier après validation.

### Positions revues par Clément (2026-11-08)

- **Panneau plus bas** : le gabarit `UpgradeSign` est descendu de 1 stud. `Foot` mesure maintenant 0,6 stud de haut, et la plaque va de 0,55 à 5,05 stud au-dessus du sol. Le pivot reste au sol (`PivotOffset` de `Foot` = (0 ; −0,3 ; −0,1)). Les noms n'ont pas changé.
- **Tapis et banc** : les deux `UpgradePoint` restent en (∓17,25 ; 0,3 ; −44), mais ils sont **tournés vers la boutique (+Z)**. Le propriétaire qui sort par la porte voit le panneau de face. L'invite F du code est toujours sur ce point, au sol.
- **Niveau de la boutique** : `StageUpgradePoint` est déplacé **au fond, au centre**, en (0 ; 0,3 ; −18,6), face à la porte (−Z). C'est entre la rangée `Rayon_01`, dont l'allée centrale x −7..7 est libre, et la rambarde arrière du niveau 1, à z −16,4. Il est maintenant enfant de `PlotFloor` et non plus de `UpgradeKiosk`, pour qu'il reste en place si la borne près de la porte disparaît. Il ne touche rien dans les 6 boutiques. **À trancher** : aux niveaux 2 à 5, la boutique va jusqu'à z 39. Le panneau reste alors au milieu, dans l'allée entre les rangées 1 et 2. Pour qu'il suive le fond, il faudra qu'Ironix le déplace selon le niveau (fond du niveau 2 et plus : environ (0 ; 0,3 ; 37,6), devant le mur du fond).
- **Plus de panneau « présentoir suivant »** : Clément le retire, l'achat des présentoirs passera par l'arbre de compétences. L'aperçu est supprimé. L'attachment `DisplayUpgradePoint` et la borne `DisplayKiosk` restent en place pour l'instant (le code ne les lit pas). À retirer des noms proposés.
- Aperçus mis à jour : 3 par boutique (`Preview_Treadmill`, `Preview_Bench` et `Preview_ShopUpgrade`), dans `Workspace/_PREVIEW_UpgradeSigns`. ContractChecker : OK.

### Ligne bleue et panneau qui suit le fond (2026-11-08, Clément)

- **Tapis et banc** : Clément a tracé une ligne bleue sur une capture : les panneaux vont **devant la machine, côté allée**, alignés sur le socle. Les `UpgradePoint` sont maintenant en **(∓15,6 ; 0,3 ; −50)**, toujours tournés vers la boutique (+Z). Côté banc, le panneau est centré entre le socle et le banc, à 1,8 stud de chacun. Côté tapis, il est à 2,6 studs du tapis. L'avant du pied est à z −51, juste avant le bord de la terrasse (−51,6). Ils ne touchent rien dans les 6 boutiques.
- **Le panneau du niveau suit le fond** (décision de Clément) :
  - `StageUpgradePoint` reste en (0 ; 0,3 ; −18,6), au fond de la boutique de **niveau 1**.
  - **Nouveau point proposé `StageUpgradePoint_2`** (Attachment sous `PlotFloor`, à côté du premier) en (0 ; 0,3 ; 37,6), face à la porte. Il est devant le mur du fond, qui est le même pour les niveaux **2 à 5** (z 39). Il ne touche aucune pièce des `Stage_2` à `Stage_5` ni des rayons.
  - **Pour Ironix** : poser le panneau sur le `StageUpgradePoint_n` dont le n est le plus grand sans dépasser le niveau de la boutique, sinon sur `StageUpgradePoint`. Le déplacer à chaque montée de niveau.
  - Ce nom est à valider avant le contrat 2.2 / 10.4.
- Aperçus : `Preview_ShopUpgrade_Niveau2a5` est ajouté dans chaque boutique. Il se trouve derrière la rambarde du niveau 1, car les boutiques du hub sont au niveau 1. ContractChecker : OK.
