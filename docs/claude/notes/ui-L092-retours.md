# Réponses UI à L-092 (2026-11-11)

Fait pour Clément dans Studio (Edit), sans script. Rien n'est commité.

## 2. Contrat de `UI_Escape` (pour le 2.2, animation `SafeFlash`)

- `UI_Escape` (ScreenGui, caché, sans `ScreenGroup`) :
  - **`Flash`** : Frame plein écran, doré `ffd94a`, transparence 1 au repos, derrière tout (ZIndex 0) ;
  - **`Banner`** : Frame au centre, qui contient **`Title`** (« ESCAPED! »), **`Subtitle`** (« Take the box to your shop! ») et **`BoxIcon`** (ImageLabel, l'icône `ICON_BOX_<Tier>` du colis).
- `Rays` et `Glow` sont retirés : Clément ne veut plus d'effet de fond.
- **Animation** (tableau `ui-motion-skilltree.md`) :
  - `Flash` passe de 0,05 à 1 de transparence en 0,5 s ;
  - champ de vision + 12 en 0,08 s, puis retour en 0,45 s ;
  - `Banner` passe de 0 à 1 en 0,35 s (Back Out), `Title` de −14° à −3°, puis `BoxIcon` et `Subtitle` arrivent 0,07 s l'un après l'autre ;
  - au bout de 2,3 s, `Banner` rapetisse à 0 en 0,15 s, puis l'écran s'éteint.
- **Sons** : `Heist_SafeFlash`, puis `Heist_Escape` 0,12 s après.

