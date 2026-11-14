# Revue « trop lumineux » (2026-11-12) : état des lieux et direction proposée, rien d'appliqué

**Références (27 images uniques et 5 vidéos)** : plein soleil, couleurs pleines et saturées (herbe citron, briques, bleu ciel). Presque pas de bloom ni de voile. Le néon ne sert que d'accent, sur un tapis rare ou un pet rare. Les cases « Récupérer » sont des plaques vert plein, sans néon, et les panneaux sont bleu nuit avec du texte coloré.

**État des lieux (relevé en Play, côté client, de nuit)**
- `Lighting` : exposition +0,1 ; Bloom 0,6/28/2,2 ; ColorCorrection saturation 0,18, contraste 0,06 ; Atmosphere densité 0,28, voile 0,6, éblouissement 0,15 ; SunRays 0,06.
- **Néon le jour**, par surface :
  - zone 3, fenêtres des immeubles (39 pièces, environ 60 000 st²) ;
  - zone 6, anneaux de la GatewayTower (24 pièces, 17 000 st²) ;
  - zone 4 `CrownNeon` ;
  - les 6 magasins, cadres de façade `Facade/Frame_*` (or 255,232,150, la mise en avant des vitrines) et plafonniers ;
  - hub : plaques `CollectPad` (48), `RarestPedestal` (DrumNeon, TopNeon bleus) et bords rouges `PadEdge` des stands.
- **Halos de rareté** (code d'Ironix, `DisplayService.HALOS`) : PointLight de 0,8 à 3,5 (portée 6 à 16), particules à `LightEmission` 1, rayons `Beam` à `LightEmission` 1 et transparence 0,35. Du Légendaire au Secret, les rayons et le bloom noient l'objet.
- **Tapis par palier** : le Fire a 74 émetteurs (565 particules/s) ; le Police a des lumières jusqu'à 5 ; LaserVault 21 émetteurs, 12 beams.
- **Auras** : PointLight de 1,2 à 2.
- **Oubli de L-087** : `Assets/Plots/PLOT_Shop_Rayons/Rayon_02..05` ont encore 16 `Glow` à 3.

**Direction proposée (à valider par Clément)**
1. `Lighting` : exposition 0 ; Bloom 0,25/18/2,6 ; saturation 0,12, contraste 0,1, teinte blanche ; Atmosphere 0,2, voile 0,2, éblouissement 0 ; SunRays 0,02. Soleil et ambiances inchangés.
2. **Néon seulement la nuit** : fenêtres de la zone 3, anneaux de la zone 6, cadres de façade et piédestal passent en SmoothPlastic, même couleur, avec le tag `NightLight` (SkyController les repasse en néon la nuit, sans code nouveau).
3. Plaques `CollectPad` : vert plein (76,214,72), en SmoothPlastic.
4. **Pour Ironix (halos)** :
   - PointLight à environ un tiers : 0,3 / 0,5 / 0,8 / 1 / 1,2, portée 4 à 10.
   - Particules : `LightEmission` 0,3 et `Rate` divisé par 2.
   - Rayons : transparence 0,6, `LightEmission` 0,3.
5. **Tapis** : Fire à 30 émetteurs au plus ; lumières à 2 au plus.

**Appliqué à tout le jeu le 2026-11-13** (accord de Clément) avec `tools/clement/glow_review.luau` :
- `Lighting` (point 1) ;
- 502 néons de décor de la map et des gabarits en SmoothPlastic le jour, avec le tag `NightLight`. `NightLight` compte maintenant 611 pièces. Restent en néon : plafonniers, écrans, présentoirs d'auras, ZoneGate et NightWall ;
- 52 plaques en vert plein (`collect_pad_fx.luau` à jour) ;
- 19 tapis au repos : 196 émetteurs à `LightEmission` 0,5 au plus et `Rate` divisé par 2, lumières à 2 au plus ;
- `Heist_Breath` passé à 0,5 ;
- 3 sons à écouter, `Cash/Cash_Collect_B`, `_C` et `_D` ;
- 52 `Glow` laissés à 3 après L-087, ramenés à 0,8 / 6.

**Pour Ironix (liaison)** :
- les halos du point 4 ;
- les valeurs « en course » de `Config/TreadmillFX` : Police `LightOn` 6 → 2, LaserVault `AlarmLight` 3 → 1,5, Gold `WingLight.Max` 2,2 → 1,2.

Il reste à vérifier la nuit en Play. Le script s'annule avec `MODE = "revert"`.

Script : `tools/clement/glow_review.luau` (`MODE = "apply"` / `"revert"`, attributs `AncienGlow_*`). Il touche `Lighting`, la zone 1 et `PLOT_Shop_01` seulement.
