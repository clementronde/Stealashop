# Ouverture du colis sur le rayon et antivol en base (L-112), validés par Clément le 2026-11-12

L'aperçu est dans `tools/clement/open_counter_antitheft_preview.luau` (Edit, dans la vraie scène). Il a été validé après plusieurs passes. L'analyse de la vidéo de référence est dans `docs/claude/notes/ui-reference-ouverture-oeuf.md`. Rien n'est commité.

## Le déroulé (T.n = ligne n de `docs/claude/notes/ui-motion-skilltree.md`)

1. **Le colis s'ouvre sur son rayon** : les deux rabats du couvercle se lèvent, puis une lumière blanche sort (T.53 `ShelfFlaps`).
2. **La chance monte**, s'il y en a (T.54 `ShelfLuck`) :
   - « ×N LUCK » monte à chaque tic de 0,1 s ;
   - le colis grandit avec la chance, et la lumière aussi ;
   - **sans chance, le colis s'ouvre tout de suite**.
3. **La révélation** (T.55 `ShelfReveal`) :
   - le colis et son contour noir disparaissent, et l'effet éclate ;
   - l'objet sort **à la place du colis, tourné comme le rayon** (sa face avant, le −Z du modèle, vers l'allée, comme le LookVector de `ShelfSlot_xx`). Il sort blanc, puis prend ses couleurs ;
   - au-dessus, `BB_Item` montre le nom, la rareté, la mutation et le $/s.
4. Le joueur vole l'objet et le porte jusqu'à sa base.
5. **En base, l'objet posé est bloqué** par l'antivol tant que le temps n'est pas fini. Le joueur ne peut pas encore l'utiliser (T.56 `AntiTheft`). Puis « UNLOCKED! » s'affiche, et l'objet peut aller sur un présentoir.

## Noms pour la liaison (dans Studio, sans script)

- `ReplicatedStorage/Assets/UI/BB_ShelfOpen` :
  - BillboardGui de 300 × 70 px, `AlwaysOnTop`, `MaxDistance` 60, au-dessus du colis ouvert ;
  - `Row.LuckIcon` : le trèfle (emoji pour l'instant, attribut `IconAsset = UI_Icon_Clover`) ;
  - `Row.Luck` : le texte « ×N LUCK », vert `5cff4a` à contour noir, écrit par le code.
- `ReplicatedStorage/Assets/UI/BB_AntiTheft` (même style que la référence de Clément : sans fond) :
  - BillboardGui, `AlwaysOnTop` coupé, **`MaxDistance` 10** : il ne se voit que juste à côté de l'objet ;
  - `ItemName` : le nom, que le code colore à la couleur de la rareté, avec un contour blanc ;
  - `TimeLabel` : le temps restant, blanc à contour noir, puis « UNLOCKED! » en vert.
- `ReplicatedStorage/Assets/UI/BB_Item` : nouvelle ligne **`Mutation`** (cachée par défaut), entre `Rarity` et `Income`.
  - Le code écrit « BIG GOLD » et la montre quand l'objet a une mutation.
  - Le billboard passe à `{5, 120}, {1.6, 62}`.
- `ReplicatedStorage/Assets/FX/FX_ShelfLight` : la lumière qui sort du colis.
  - Modèle avec `Root` (invisible), `Mouth` et `Up`, `InnerLight` (Beam), `Mouth.Sparkles` et `InnerGlow`.
  - Le code pose `Root` sur le haut du colis et fait grandir la lumière avec la chance (T.54).
- `ReplicatedStorage/Assets/FX/FX_ShelfReveal` : l'éclatement.
  - `Root` contient `Ground.Ring`, `Center.Streaks`, `Center.Confetti` et `Center.Stars` (`Rate` 0, attribut `EmitCount` : 1, 34, 60, 22), le PointLight `Flash` et le Beam `Shaft` (éteint).
  - Le code les règle à la couleur de la rareté.
- `UI_HUD.RevealTint` : un voile plein écran, caché, pour les raretés Épique et plus (T.55).
- **À modéliser par Clément** : deux rabats `FlapL` et `FlapR` dans `Lid` de chaque `BOX_*`, avec leur pivot sur le bord extérieur. Dans l'aperçu, ils sont simulés en coupant le couvercle en deux.

## À décider (pas dans le doc)

- La durée de l'antivol (l'aperçu prend 10 s, comme l'attente actuelle du colis).
- La chance de départ, la chance maximale et la vitesse de montée. L'aperçu fait × 1,03 par tic jusqu'à × 3,2.
- Les sons : le tic qui monte d'une octave et le carillon de la révélation, à choisir et à tester en Play.
