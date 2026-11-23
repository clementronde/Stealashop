# Miniature avant/après de la boutique (MOD-043, 2026-11-23)

Le concept « avant / après » de la vidéo analysée dans
[../2026-11-22_analyse-video-miniatures-ia.md](../2026-11-22_analyse-video-miniatures-ia.md) : la boutique du joueur
« niveau 1 » contre « niveau 999 ». Faite par ChatGPT dans le Chrome de Clément, finie en Python avec l'argent et la
flèche rouge de Clément. Rien n'est publié.

| Fichier | Contenu |
| --- | --- |
| [THUMB_AvantApres.png](THUMB_AvantApres.png) | Miniature 1920 × 1080, PNG, 2,0 Mo |
| [THUMB_AvantApres_controle_320x180.png](THUMB_AvantApres_controle_320x180.png) | Contrôle à 320 × 180 |
| [THUMB_AvantApres_controle_zones.png](THUMB_AvantApres_controle_zones.png) | Bande des 216 px du bas en rouge, tiers en blanc |
| `chatgpt/chatgpt_avant_apres.png` | Image téléchargée depuis chatgpt.com (1672 × 941, 1,8 Mo) |
| `apercu_chatgpt_1.png`, `_2.png` | Captures d'écran des 2 essais |
| [prompt.md](prompt.md) | Les 2 prompts |

Refaire, dans PowerShell, depuis la racine du dépôt :

```powershell
$env:ETIQUETTE = '|||+$1/s;|||+$999T/s'; $env:ETIQUETTE_CENTRE = '300,515;1460,215'; $env:ETIQUETTE_TAILLES = '54,40,40,96;54,40,40,128'; $env:ETIQUETTE_ARC_EN_CIEL = '0;1'; $env:FLECHE_IMAGE = 'docs/claude/miniatures/elements/fleche_rouge_clement.png|790|300|520|0|0'
```

```powershell
py -I tools/clement/miniatures/miniature_ia.py docs/claude/miniatures/2026-11-23_miniature-avant-apres/chatgpt/chatgpt_avant_apres.png docs/claude/miniatures/2026-11-23_miniature-avant-apres - haut-droite THUMB_AvantApres.png
```

## Ce que montre l'image

- **Avant, à gauche** : un stand en bois délabré, à la bâche trouée, avec une seule canette de soda sur le comptoir.
  Le bacon hair à cagoule, petit, a les épaules tombantes, la bouche triste et une larme. Au-dessus du stand :
  « +$1/s » en vert, la couleur du revenu de `BB_Item`.
- **Après, à droite** : le même perso, plus grand, a un grand sourire et les bras ouverts, devant une boutique dorée
  pleine de trésors à halo (Couronne, coffre de diamants, trophée, PC gamer), avec des pièces et des billets qui
  volent. Au-dessus : « +$999T/s » en arc-en-ciel.
- **La flèche rouge de Clément** ([../elements/fleche_rouge_clement.png](../elements/fleche_rouge_clement.png)),
  à 520 px de large et sans rotation, va de « +$1/s » vers « +$999T/s ». Elle passe par-dessus le trait blanc qui
  sépare l'avant de l'après. 4 placements ont été essayés (520 px, 600 px, 520 px tournée de 8°, 440 px) : celui-ci
  relie le mieux les deux montants sans écraser la scène.

## Les règles de la vidéo, appliquées

- **Le fantasme et ce qu'on ressent** : passer d'un stand minable à une boutique en or. C'est la progression du jeu :
  on vole, on expose, on encaisse des $/s.
- **Deux émotions lisibles** : triste à gauche, fier et ravi à droite.
- **Un fond simple et contrasté** : ciel bleu sans nuages et herbe verte des deux côtés.
- **Rien n'est couvert** : l'argent et la flèche sont dans le ciel ; la Couronne, le coffre, le trophée et le PC
  restent visibles.
- **Bacon hair à cagoule** : le même perso que sur l'icône et les autres miniatures.

## Contrôle

- 1920 × 1080, 2,0 Mo, donc moins de 3 Mo. ✓
- **À 320 × 180**, on lit « +$1/s », la flèche, « +$999T/s », le perso triste, le perso ravi et la boutique dorée. ✓
- **Bas** : les 216 px du bas ne montrent que le bas du stand, les jambes, les pieds et l'herbe. ✓
- **Valeurs** : « +$1/s » est la vraie valeur de la Canette de soda (Commun, `Z1_CanetteDeSoda`, 1 $/s d'après
  `src/shared/Config/Formulas.luau`). « +$999T/s » est volontairement gonflée, comme sur les autres miniatures, à la
  demande de Clément, et rappelle le « niveau 999 » : ne pas la reprendre comme valeur du jeu.
- **À vérifier sur un vrai téléphone**, comme le conseille la vidéo.
