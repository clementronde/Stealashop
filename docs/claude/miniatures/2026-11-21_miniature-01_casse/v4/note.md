# Miniature 01 v4, la casse avec des milliards par seconde (MOD-043, 2026-11-21)

C'est la v3 ([../v3/note.md](../v3/note.md)) : même image de ChatGPT, pas de titre. À la demande de Clément :

- au-dessus de la Couronne, il ne reste que **la ligne d'argent de l'étiquette `BB_Item`**, plus grosse :
  **« +$48.7B/s »** ; le nom, la rareté et la mutation sont retirés ;
- l'argent est **en arc-en-ciel**, aux couleurs du jeu pour la rareté Secret (`Rarities.Secret.RainbowColors`) ;
- une **flèche rouge** en arc épais, à gauche de l'argent, descend vers la Couronne. C'est le même style que sur la
  miniature 02.

Rien n'est publié.

> **Valeur volontairement fausse**, décidée par Clément le 2026-11-21 (« beaucoup plus d'argent, ment sur la
> valeur ce n'est pas grave »). Ce n'est pas une valeur du jeu : l'étiquette d'une Couronne affiche +$495/s de base,
> +$4.9K/s en Colossal et au plus +$49.5K/s en Colossal Rainbow (calcul dans la note v3). Ne jamais la recopier dans
> le code, les docs d'équilibrage ou l'UI. Risque connu : Roblox peut refuser une miniature trompeuse. La version avec
> la vraie valeur reste disponible : [../v3/THUMB_01_Casse_v3.png](../v3/THUMB_01_Casse_v3.png).

| Fichier | Contenu |
| --- | --- |
| [THUMB_01_Casse_v4.png](THUMB_01_Casse_v4.png) | Miniature 1920 × 1080, PNG, 2,2 Mo |
| [THUMB_01_Casse_v4_controle_320x180.png](THUMB_01_Casse_v4_controle_320x180.png) | Contrôle à 320 × 180 |
| [THUMB_01_Casse_v4_controle_zones.png](THUMB_01_Casse_v4_controle_zones.png) | Bande des 216 px du bas en rouge, tiers en blanc (960 × 540) |

Refaire, dans PowerShell, depuis la racine du dépôt :

```powershell
$env:ETIQUETTE = '|||+$48.7B/s'; $env:ETIQUETTE_CENTRE = '1530,286'; $env:ETIQUETTE_TAILLES = '54,40,40,116'; $env:ETIQUETTE_RARETE = '#A855F7'; $env:ETIQUETTE_ARC_EN_CIEL = '1'; $env:FLECHE_ARC = '1215,335,125,-106,-272,36'
```

```powershell
py -I tools/clement/miniatures/miniature_ia.py docs/claude/miniatures/2026-11-21_miniature-01_casse/v2/chatgpt/chatgpt_large.png docs/claude/miniatures/2026-11-21_miniature-01_casse/v4 - haut-droite THUMB_01_Casse_v4.png
```

## Contrôle

- 1920 × 1080, 2,2 Mo, donc moins de 3 Mo. ✓
- La valeur est écrite comme `Format.income` l'écrit (« +$48.7B/s »), avec un corps de 116 px. La ligne fait 625 px de
  large (de 1217 à 1842 px) et reste dans le cadre de la vitrine. ✓
- **À 320 × 180**, on lit « +$48.7B/s ». ✓
- **Bas** : les 216 px du bas ne montrent que le sol, les éclats et le pied du présentoir. ✓
- Les autres écarts sont ceux de la v3 : pas de titre, la vitrine de verre, la traînée rose derrière la masse, et
  l'image agrandie d'environ 15 %.
