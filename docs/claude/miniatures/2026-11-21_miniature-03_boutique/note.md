# Miniature 03, la boutique pleine (MOD-043, 2026-11-21)

C'est la scène 3 du brief (« BUILD THE RICHEST SHOP »), faite par ChatGPT dans le Chrome de Clément, dans le style de
la 01 et de la 02 : pas de titre, l'argent en arc-en-ciel et une flèche rouge. Rien n'est publié.

| Fichier | Contenu |
| --- | --- |
| [THUMB_03_Boutique.png](THUMB_03_Boutique.png) | Miniature 1920 × 1080, PNG, 2,4 Mo |
| [THUMB_03_Boutique_controle_320x180.png](THUMB_03_Boutique_controle_320x180.png) | Contrôle à 320 × 180 |
| [THUMB_03_Boutique_controle_zones.png](THUMB_03_Boutique_controle_zones.png) | Bande des 216 px du bas en rouge, tiers en blanc (960 × 540) |
| `chatgpt/chatgpt_boutique.png` | Image téléchargée depuis chatgpt.com (1672 × 941, 2,0 Mo), source de la miniature |
| `apercu_chatgpt_1.png` | Capture d'écran de l'image de ChatGPT (ce n'est pas l'image finale) |
| [prompt.md](prompt.md) | Le prompt et les éléments du jeu relevés dans Studio |

Refaire, dans PowerShell, depuis la racine du dépôt :

```powershell
$env:ETIQUETTE = '|||+$1.2T/s'; $env:ETIQUETTE_CENTRE = '960,175'; $env:ETIQUETTE_TAILLES = '54,40,40,130'; $env:ETIQUETTE_RARETE = '#FF3B5C'; $env:ETIQUETTE_ARC_EN_CIEL = '1'; $env:FLECHE = '1045,214,1080,282,1003,350,24'; $env:FLECHE_TETE = '0.7'
```

```powershell
py -I tools/clement/miniatures/miniature_ia.py docs/claude/miniatures/2026-11-21_miniature-03_boutique/chatgpt/chatgpt_boutique.png docs/claude/miniatures/2026-11-21_miniature-03_boutique - haut-droite THUMB_03_Boutique.png
```

## Ce qui est montré

- **La boutique** du bacon hair à cagoule, vue de trois quarts en hauteur. Elle reprend les murs blancs à touches
  roses et le sol de marbre de la parcelle du jeu (`PLOT_Shop_05`), ainsi que le tapis à gauche.
- **Au centre**, sur un socle rond (le `RarestDisplay` du jeu) : le Coffre de diamants, Mythique, halo rouge rose.
- **Sur les rayons**, avec leur halo :
  - le PC gamer et la Carte graphique en or (Rares, bleu) ;
  - la Couronne et l'Œuf en diamant (Épiques, violet) ;
  - le Diamant géant, le Taureau en or et le Trône en or (Légendaires, or).
- **Au premier plan**, le perso, de dos, ouvre les bras devant ses trésors.

## Contrôle

- 1920 × 1080, 2,4 Mo, donc moins de 3 Mo. ✓
- **Argent** : « +$1.2T/s » en arc-en-ciel (couleurs Secret du jeu), en haut au centre, avec un corps de 130 px. ✓
  Plus gros que sur la 01 et la 02, puisque c'est « la boutique la plus riche ».
- **Valeur volontairement gonflée**, comme sur la 01 et la 02, et non calculée à partir du jeu. Le brief demandait des
  montants réellement atteignables ; Clément a choisi de gonfler les valeurs. Ne jamais la reprendre comme valeur du
  jeu ; Roblox peut refuser une miniature trompeuse.
- **Flèche rouge** courte, de l'argent vers le Coffre (même style que la 01 et la 02, pointe réduite pour une flèche
  courte). ✓
- **À 320 × 180**, on lit l'argent, la flèche, le Coffre et les objets autour. ✓
- **Bas** : les 216 px du bas montrent le sol de marbre et les baskets du perso, sans visage ni objet important. ✓
- **Écarts au brief** :
  - pas de titre « BUILD THE RICHEST SHOP », comme les 01 et 02 (choix de Clément) ;
  - pas d'étiquettes $/s au-dessus de chaque objet, mais une seule grosse valeur ;
  - la boutique et les objets sont redessinés par l'IA d'après le jeu.
- **Validée par Clément** le 2026-11-21.
