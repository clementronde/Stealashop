# Neige qui reste à Paris (zone 5), pour le chef Map, relevé du 28/11 (lecture seule, place v1555)

J'ai relevé, sous `Workspace/Map/Zone_5`, les pièces de neige (couleur #ecf2f8), de glace (Ice, #d6ecfa) et celles dont le nom contient « Snow » ou « Ice ». Il y en a environ 250, réparties en 5 groupes.

## 1. Au sol : ce que Clément voit en premier
- `Street_Paris/Ground` : **27 pièces**, la couche de neige de la chaussée et les congères (`RoadSnow_*`, `RoadSnow_Entry`, `SnowBank_1` à `_6`…). Ce sont elles qui rendent la chaussée blanche sur la vidéo.
- `Street_Paris/District` : **10 pièces**, la neige du boulevard (`Boulevard_Snow1_E` à `Snow3_E`, `Boulevard_SidewalkB_E`…).
- `Street_Paris/Garden` : `Hedge_12_Snow` et `Hedge_22_Snow` (neige sur les haies), et les assises de `Bench_3` et `Bench_4`.
- `Street_Paris/Weather/SnowCloud` : la Part source de la neige qui tombe. Mes feuilles la remplacent.

## 2. L'entrée d'hiver
- `Street_Paris/Entrance` : **53 pièces**. Ce sont les piliers enneigés (`PillarSnow_N1`, `_N2`…) et les **32 stalactites en Ice** (`Icicle_*`).
- `Entrance/Fir_N` et `Fir_S` : les deux sapins (6 pièces de neige chacun). La fiche les retire.
- `Entrance/Candelabra_N` et `_S` : les toits des lanternes sont blancs (3 chacun). La fiche garde les candélabres, repeints en vert bronze.

## 3. La neige sur les toits
- `Street_Paris/Facades/Haussmann_N1` à `N5` et `S6` à `S10` : **7 pièces chacun** (`Mansard`, `MansardBack`, `RoofTop`, `DormerCap_*`, `ChimneyBackCap`). La fiche les veut en **zinc #6f7f8f**.
- `Street_Paris/District/Building_NE1`, `NE2`, `NW1`, `NW2`, `SE1`, `SE2` et `BackRow_1`, `2`, `5`, `6` : **8 pièces chacun** (`Mansard_*`, `RoofTop`, `ChimneyCap_*`).
- Les deux magasins PNJ, `STORE_Z5_GalerieDArt/UpperFloors` et `STORE_Z5_Antiquaire/UpperFloors` : `Mansard`, `AtticTop`, `DormerCap_*` en #ecf2f8. Ce sont des modèles du contrat : on change seulement la couleur, sans renommer.

## 4. Les petits « chapeaux » de neige sur le décor
- `Props` :
  - les lanternes de `Lamp_N1`, `N3`, `S1` et `S2` (`LanternRoof`) ;
  - les dessus des bornes (`Bollard_*_Top`, 8 pièces) ;
  - les dômes de `Fountain`, `MorrisColumn_N` et `MorrisColumn_S`.
- `District/BoulevardLamp_1` et `_3` (`LanternRoof`).
- `Garden` :
  - les lanternes de `Lamp_3` et `Lamp_4` (`LanternRoof`) ;
  - `Bandstand` : le sol et les 3 toits ;
  - `Carousel` : les 3 toits.
- `CafeTerrace` : **9 pièces**, le dessus des tables et les assises des chaises (`TableTop_*`, `Chair_*_Seat`).
- `Landmarks/EiffelTower/CampanileRoof` et `Landmarks/GoldenDome/DomeSnow`.

## Ce qui n'est pas de la neige
Je l'ai écarté, même si c'est blanc ou clair :
- les intérieurs des magasins (étagères, étiquettes de prix) ;
- les corniches crème (#f0e8d6, #f2ecdc, #f0eada) ;
- les témoins (`Witnesses`) ;
- le verre de `BrushJar` ;
- les néons de l'entrée.
