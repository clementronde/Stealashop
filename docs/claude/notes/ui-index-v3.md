# UI_Index_v3 : l'Index du jeu de référence (2026-11-10, demande de Clément)

Demande de Clément : « affiche l'index exactement comme dans la vidéo ». Copie de l'Index de sa vidéo de référence (36 s à 58 s), sans script dans l'UI. Rien n'est commité.

## Où en est l'Index v3

- Script : `tools/clement/index_v3.luau`.
  - En Edit, il construit `StarterGui/UI_Index_v3` (caché, `ScreenGroup = "Menu"`).
  - En Play, côté client, il construit une copie remplie avec les vrais objets de `Config/Items` (un tiers par zone marqué « découvert ») et l'ouvre par le bouton Index du prototype `_G.UiFeel`.
- **Vu en Play seulement**. Pas encore dans StarterGui : il attend la validation de Clément.
- Tailles vérifiées :
  - 1614×871 : fenêtre de 962×600 et cartes de 86 px ;
  - 1280×720 : cartes de 71 px ;
  - 667×375 : cartes de 45 px. Tout tient dans l'écran et aucun texte ne déborde.

## Mise en page (comme la vidéo)

- **Fenêtre** : bandeau rose à bandes claires, titre « Index », `CloseButton` rouge, fond vert foncé.
- **Liste** (à gauche) : `ListPanel.List` défile, un bloc par zone, `Zone1Section` à `Zone6Section` (`SecretsSection` cachée).
  - `ZoneArt` : colonne haute aux couleurs de la zone, avec `ZoneIcon` et `ZoneName`. Son `Image` est vide, prête pour une illustration de la zone.
  - `Content.Cards` : 5 cartes par ligne, objets par rareté croissante.
  - `Content.ZoneBar` : `Fill` vert, `ZoneCount` (« 4/13 ») et `ZoneItem` (l'objet le plus rare de la zone, en silhouette tant qu'il n'est pas trouvé).
- **Carte** (`List.Template`, un `TextButton` sans texte) : `Clip` (fond à la couleur de la rareté, avec `Glow` et `Rays`), `Icon` hors du cadre (pour le survol), `ItemName` en haut, `Lock` (vide, invisible), `HoverOutline`.
  - Objet pas découvert : fond assombri, icône en silhouette sombre teintée de la rareté, nom « ??? ». Le Secret a un fond arc-en-ciel.
- **Compteur** : `UnlockedBar.Counter` (« Unlocked: 7/83 ») et `BookIcon` (l'icône Index du HUD), qui déborde à gauche.
- **Fiche** (à droite) : `Detail` (fond à la couleur de la rareté), avec `IconFrame.DetailIcon`, `DetailName`, `DetailRarity` et `DetailIncome` (« $X/s », calculé par `Formulas.ItemIncome`). Elle montre l'objet **cliqué** ou touché, et ne change pas au survol (retour de Clément, 2026-11-10). Le `Template` est donc un `TextButton` (`Activated`).
- **Récompenses** : `Rewards` (`RewardsTitle`, `SpeedReward` et `CashReward` avec `Icon` et `Amount`, `ClaimButton` avec `ClaimLabel` et `Shade`), pour la zone visible dans la liste.
- **Catégories**, hors de la fenêtre à droite : `Categories` avec `NormalButton`, `SecretsButton` et `MutationsButton`. Chacun a `Label`, `Shade` et `Selected` (caché, allumé sur la catégorie choisie).
- **Mutations**, hors de la fenêtre à gauche : `MutationTabs`, avec un onglet par effet de `Config/Mutations` (`ShinyTab` à `RainbowTab`, chacun avec `TabLabel`, `Shade` et `Selected`), et `MutationCaption` sous la fenêtre.

## Pour Ironix

- **Noms gardés** : le code lit déjà `Template` (`Icon`, `ItemName`, `Lock`, `Glow`, `Rays`), `ZoneName`, `ZoneBar.Fill`, `ZoneCount`, `Counter` et `CloseButton`.
- **Nouveau à brancher** :
  - `Clip.BackgroundColor3` = couleur de la rareté, assombrie si l'objet n'est pas trouvé ;
  - silhouette = `Icon.ImageColor3` sombre teinté de la rareté ;
  - fiche `Detail` au clic sur une carte (`Template.Activated`), avec le son de clic ; au survol, seulement l'icône qui grossit et le contour ;
  - panneau `Rewards` de la zone visible dans la liste ;
  - `ZoneItem` ;
  - les catégories.
- **Récompense d'une zone complète** : Clément a demandé de l'argent **et** de la vitesse (L-083, point 7). Les montants sont à proposer. En attendant, `Amount` affiche « +Speed » et « +Cash ». L'icône de vitesse est vide : aucune icône de chaussure n'existe encore.
- **Catégorie MUTATIONS** : un Index par effet (Shiny, Gold…) n'existe pas dans le code. C'est à décider (récompense, seuil) ; la légende dit pour l'instant « Collect every item in SHINY! ». SECRETS remplace le « Limité » de la vidéo.
- **Animations du prototype** :
  - au survol d'une carte, l'icône passe à × 1,12, penche de −6° et monte vers la droite ;
  - la fiche apparaît de 0,82 à 1 (Back, 0,16 s) ;
  - changement de catégorie : les cartes sortent puis rentrent une par une ;
  - les onglets de mutation entrent à 0,05 s d'écart ;
  - « Claim » sur une zone pas complète : `UI_Deny` et le bouton tremble.
