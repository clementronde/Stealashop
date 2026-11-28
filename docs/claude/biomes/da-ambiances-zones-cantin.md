# Ambiance par zone : valeurs pour Cantin (Chef DA, 28/11, V1)

Décision de Clément (28/11) : chaque zone a son heure et sa lumière (biomes validés « sauf la nuit » : New York est au crépuscule, pas en nuit). Le code les applique quand le joueur entre dans une zone, avec un fondu, et **la vraie nuit du jeu passe par-dessus**. Valeurs à ajuster par Clément en jeu.

## Ce que fait le code (proposition)

- **Côté client seulement**, comme le `SkyController` : la copie locale de `Lighting` change, rien n'est enregistré dans la place.
- **Déclencheur** : la zone où se trouve le joueur, au même endroit que le bandeau de zone. Hub et zone safe = **les réglages de Clément** lus au démarrage (la ligne « Hub » ci-dessous).
- **Fondu** de 2,5 s (`TweenService`, Sine InOut) entre l'ancienne zone et la nouvelle. S'il fait demi-tour pendant le fondu, on repart de l'état en cours.
- **Nuit du jeu** (`NightPhase` = Warning puis Night) : elle prend la main, comme aujourd'hui (`Config/Night.Sky`), quelle que soit la zone. Seuls la teinte `ColorCorrection.TintColor` et le brouillard (`Atmosphere`) de la zone restent mélangés à 30 %, pour que les villes se distinguent encore la nuit. À l'aube, le retour se fait vers la zone où se trouve le joueur, pas vers le hub.
- Le **ciel (`Sky`) ne change pas** : un seul ciel peint pour tout le jeu, comme chez le concurrent.
- Interrupteurs : `Features.ZoneLooks` (PROD, false) et `Features.ZoneLooksDev` (DEV, true), règle C2.
- Valeurs dans une table de config (par exemple `Config/ZoneLooks.luau`, nom au choix de Cantin), avec les champs ci-dessous.

## Règle « jamais la nuit » (ajoutée le 28/11, après le retour de Clément sur Tokyo)

La vraie nuit du jeu (couloir fermé, `Config/Night.Sky` : ClockTime 0, Brightness 1, OutdoorAmbient 70,80,125) doit rester **la seule ambiance sombre**. Chaque zone respecte donc :
- **ClockTime entre 8 et 17,4** : le soleil est encore au-dessus de l'horizon (il se couche vers 18 h dans la place, latitude 35°) ;
- **Brightness d'au moins 1,9** ;
- **OutdoorAmbient d'au moins 140 en moyenne** (R + G + B divisé par 3) ;
- **ExposureCompensation d'au moins −0,05** ;
- **Atmosphere.Density d'au plus 0,4** ;
- **Bloom.Intensity d'au plus 0,3**.

Les néons s'ajoutent à la lumière du jour, ils ne la remplacent pas.

Vérification des 6 zones (V0 du matin, puis V1) :
- **Tokyo** ne respectait pas la règle (18,6 h, Brightness 1,2, brume et bloom violets) : on aurait dit la nuit. Refait en **coucher de soleil clair, 17,0 h**.
- **New York** était trop sombre (Brightness 1,5, exposition −0,1, brume 0,45) : passe à 16,6 h et Brightness 1,9.
- **Londres** était trop sombre (Brightness 1,6, brume 0,48) : passe à 15,8 h, Brightness 1,9 et brume 0,4. Il reste gris et couvert.
- **Los Angeles** : 17,6 h était trop près du coucher ; passe à **17,3 h**, brume 0,32.
- **Paris** (9,8 h) et la **zone 1** (12,5 h) respectent déjà la règle : rien ne change.

## Valeurs V1 (28/11)

Couleurs en R, G, B (0 à 255). Base de la ligne Hub : relevé de `Lighting` dans la place DEV le 28/11. Les valeurs changées depuis la V0 sont en gras.

| Champ | Hub (actuel) | Z1 banlieue | Z2 Londres | Z3 Tokyo | Z4 Los Angeles | Z5 Paris | Z6 New York |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Lighting.ClockTime | 14,5 | 12,5 | **15,8** | **17,0** | **17,3** | 9,8 | **16,6** |
| Lighting.Brightness | 2,6 | 3,0 | **1,9** | **2,2** | 2,4 | 2,2 | **1,9** |
| Lighting.Ambient | 120,115,130 | 130,125,115 | **115,120,125** | **140,120,160** | 140,110,90 | 135,120,115 | **120,128,150** |
| Lighting.OutdoorAmbient | 150,155,172 | 165,165,160 | **140,148,152** | **175,150,200** | 175,135,110 | 170,155,150 | **150,162,190** |
| Lighting.ColorShift_Top | 255,236,205 | 255,245,220 | **210,215,220** | **255,150,200** | 255,170,100 | 255,220,190 | 255,190,160 |
| Lighting.ExposureCompensation | 0 | 0,1 | **−0,05** | **0** | 0 | 0 | **0** |
| ColorCorrection.Brightness | 0,01 | 0,02 | −0,02 | **0,02** | 0,02 | 0,01 | 0 |
| ColorCorrection.Contrast | 0,15 | 0,12 | 0,05 | **0,12** | 0,15 | 0,08 | 0,1 |
| ColorCorrection.Saturation | 0,28 | 0,3 | −0,15 | **0,32** | 0,3 | 0,15 | −0,05 |
| ColorCorrection.TintColor | 255,250,240 | 255,250,235 | 225,235,232 | **250,235,255** | 255,230,200 | 255,240,225 | 225,235,255 |
| Atmosphere.Density | 0,3 | 0,22 | **0,4** | **0,3** | **0,32** | 0,32 | **0,38** |
| Atmosphere.Offset | 0,35 | 0,25 | 0,15 | **0,25** | 0,2 | 0,25 | 0,2 |
| Atmosphere.Color | 185,212,255 | 205,230,255 | 170,180,178 | **235,185,225** | 255,190,140 | 240,225,205 | 215,222,235 |
| Atmosphere.Decay | 105,148,230 | 120,170,235 | 120,130,128 | **190,120,210** | 230,120,90 | 200,170,150 | 230,170,150 |
| Atmosphere.Glare | 0 | 0 | 0 | **0,3** | 0,6 | 0,2 | 0,2 |
| Atmosphere.Haze | 1,2 | 0,6 | **2,4** | **1,3** | **1,8** | 1,4 | **2,0** |
| Bloom.Intensity | 0,15 | 0,15 | 0,2 | **0,25** | 0,2 | 0,15 | **0,25** |
| Bloom.Size | 16 | 16 | 18 | **20** | 18 | 16 | 20 |
| Bloom.Threshold | 2,8 | 2,8 | 2,4 | **2,3** | 2,6 | 2,8 | 2,2 |
| SunRays.Intensity | 0,01 | 0,02 | 0 | **0,03** | 0,08 | 0,03 | 0,02 |

Ce que chaque zone doit donner à l'œil :
- **Z1** : midi net, air clair, couleurs franches.
- **Z2** : après-midi gris et couvert, brume au loin, couleurs éteintes ; le rouge des bus et des cabines ressort. Gris, mais pas sombre.
- **Z3** : **coucher de soleil clair**. Ciel rose-violet encore lumineux, rue bien lisible, façades éclairées par le jour ; les néons s'ajoutent, avec un bloom léger.
- **Z4** : soleil orange rasant, ombres longues, brume chaude.
- **Z5** : matin doux rose doré.
- **Z6** : fin d'après-midi d'hiver, froide, bleu acier en haut et pêche à l'horizon, fenêtres jaunes allumées. Nettement plus clair que la vraie nuit.

Tokyo et Los Angeles sont tous deux en fin de journée (17,0 et 17,3 h). On les distingue par la couleur : **Tokyo rose-violet** (ColorShift_Top 255,150,200, brume 235,185,225), **Los Angeles orange** (ColorShift_Top 255,170,100, brume 255,190,140).

## Météo et particules

Rien à coder : elles sont déjà posées dans la map par nos scripts d'ambiance (`tools/clement/zones/zoneN_*ambience*.luau`), et nous les renforçons zone par zone. Z1 : pollen et papillons. Z2 : pluie et flaques. Z3 : pétales, brume violette au sol et poussière néon. Z4 : air qui tremble et poussière dorée. Z5 : feuilles qui tombent (à la place de la neige, qui sera retirée de Paris). Z6 : neige épaisse et vapeur. Sons d'ambiance : déjà localisés par zone.

## À vérifier en Play (Clément)

- Le fondu ne doit pas se voir comme un saut quand on court vite d'une zone à l'autre (68 studs/s avec la vitesse max).
- Le contraste du HUD et des billboards doit rester lisible dans chaque zone, surtout à Londres (sombre) et à Tokyo (violet).
- Aucune zone ne doit paraître aussi sombre que la vraie nuit : comparer chaque zone avec une capture prise pendant la phase de nuit.

## V1.1 Londres (28/11, après la planche du chef Map)

Sur la planche `Captures/2026-11-28_biomes/Z2_londres_vues/planche_londres_avant_apres.jpg`, la V1 de Londres sortait **bleue et sombre**, presque la nuit. Les causes :
- une teinte et un brouillard gris-bleu ;
- la saturation baissée à −0,15 ;
- le ciel peint, qui reste bleu.
La V1.1 passe à un **ciel couvert mais clair, gris chaud** : la rue reste bien lisible sous la pluie, et le rouge des bus et des cabines ressort. Vérifiée à l'image, sur une simulation de la vue 2 : `Z2_londres_vues/V2_milieu_rue_ambiance_V1-1_simulation_DA.jpg`.

| Champ | Londres V1 | **Londres V1.1** |
| --- | --- | --- |
| Lighting.ClockTime | 15,8 | **14,8** |
| Lighting.Brightness | 1,9 | **2,3** |
| Lighting.Ambient | 115,120,125 | **140,138,132** |
| Lighting.OutdoorAmbient | 140,148,152 | **168,165,158** |
| Lighting.ColorShift_Top | 210,215,220 | **235,228,215** |
| Lighting.ExposureCompensation | −0,05 | **0,05** |
| ColorCorrection.Brightness | −0,02 | **0,02** |
| ColorCorrection.Contrast | 0,05 | **0,06** |
| ColorCorrection.Saturation | −0,15 | **−0,05** |
| ColorCorrection.TintColor | 225,235,232 | **248,242,230** |
| Atmosphere.Density | 0,4 | **0,36** |
| Atmosphere.Offset | 0,15 | **0,2** |
| Atmosphere.Color | 170,180,178 | **205,202,192** |
| Atmosphere.Decay | 120,130,128 | **175,170,158** |
| Atmosphere.Glare | 0 | 0 |
| Atmosphere.Haze | 2,4 | **2,0** |
| Bloom (Intensity, Size, Threshold) | 0,2 · 18 · 2,4 | **0,18 · 18 · 2,5** |
| SunRays.Intensity | 0 | 0 |

Elle respecte la règle « jamais la nuit » : ClockTime 14,8, Brightness 2,3, OutdoorAmbient de 164 en moyenne, Exposure 0,05, brume 0,36, bloom 0,18.

**Leçon pour les autres zones** : juger à l'image, pas seulement aux chiffres. Une teinte ou un brouillard à dominante bleue assombrit tout, parce que le ciel peint est déjà bleu. Seul New York a le droit au bleu, et il est plus lumineux (Brightness 1,9).
