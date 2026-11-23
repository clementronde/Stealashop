# Miniature « la casse », faite avec les règles de la vidéo (MOD-043, 2026-11-22)

La meilleure miniature possible d'après la vidéo analysée dans
[../2026-11-22_analyse-video-miniatures-ia.md](../2026-11-22_analyse-video-miniatures-ia.md). Faite par ChatGPT dans
le Chrome de Clément, finie en Python. Rien n'est publié.

| Fichier | Contenu |
| --- | --- |
| [THUMB_Casse_video.png](THUMB_Casse_video.png) | Miniature 1920 × 1080, PNG, 1,9 Mo |
| [THUMB_Casse_video_controle_320x180.png](THUMB_Casse_video_controle_320x180.png) | Contrôle à 320 × 180 |
| [THUMB_Casse_video_controle_zones.png](THUMB_Casse_video_controle_zones.png) | Bande des 216 px du bas en rouge, tiers en blanc |
| `chatgpt/chatgpt_casse.png` | Image téléchargée depuis chatgpt.com (1672 × 941, 1,7 Mo) |
| `apercu_chatgpt_1.png`, `_2.png` | Captures d'écran des 2 essais |
| [prompt.md](prompt.md) | Le prompt |

Refaire, dans PowerShell, depuis la racine du dépôt :

```powershell
$env:ETIQUETTE = '|||+$48.7B/s'; $env:ETIQUETTE_CENTRE = '820,236'; $env:ETIQUETTE_TAILLES = '54,40,40,110'; $env:ETIQUETTE_ARC_EN_CIEL = '1'; $env:FLECHE_IMAGE = 'docs/claude/miniatures/elements/fleche_rouge_clement.png|1225|340|320|26|1'
```

```powershell
py -I tools/clement/miniatures/miniature_ia.py docs/claude/miniatures/2026-11-22_miniature-casse-video/chatgpt/chatgpt_casse.png docs/claude/miniatures/2026-11-22_miniature-casse-video - haut-droite THUMB_Casse_video.png
```

## Les règles de la vidéo, appliquées

- **Le fantasme et ce qu'on ressent** : le braqueur sort de la vitrine cassée avec son butin, sous le nez du vigile.
  C'est l'excitation du vol, sur la mécanique qui nous distingue : la casse.
- **Deux persos aux émotions lisibles** : le bacon hair à cagoule a un sourire menaçant et des sourcils froncés ; le
  vigile, choqué, a les yeux écarquillés, la bouche ouverte et pointe le voleur du doigt.
- **Un fond simple et contrasté** : ciel bleu sans nuages, herbe verte, une seule boutique « SHOP » en brique à la
  vitrine brisée.
- **L'élément clé énorme** : la Couronne, plus grosse que la tête du voleur, avec son halo violet ; la masse posée
  dans l'herbe.
- **Rien n'est couvert** : l'argent est dans le ciel, au-dessus de la Couronne. La flèche est à droite, dans le ciel
  libre, et pointe la Couronne sans toucher l'argent ni le panneau « SHOP ».

## La flèche de Clément (2026-11-23)

La flèche dessinée par le script est remplacée par celle que Clément a fournie :
[../elements/fleche_rouge_clement.png](../elements/fleche_rouge_clement.png), 512 × 512, fond transparent, rouge à
contour noir. Elle est retournée pour pointer à gauche, tournée de 26° et mise à 320 px de large. 4 placements ont été
essayés (tournée de 18°, 26°, 35° et 50°) : celui de 26° vise le mieux la Couronne et garde une belle courbe. Elle se
lit bien à 320 × 180.
- **Bacon hair** : le perso qui marche le mieux selon la vidéo, et le même que sur l'icône et les autres miniatures.

## Contrôle

- 1920 × 1080, 1,9 Mo, donc moins de 3 Mo. ✓
- **À 320 × 180**, on lit l'argent, la Couronne, le braqueur, le vigile choqué et « SHOP ». ✓
- **Bas** : les 216 px du bas ne montrent que l'herbe, la masse et les pieds. ✓
- **Valeur gonflée**, comme sur les autres miniatures, à la demande de Clément : voir
  [../2026-11-21_miniature-01_casse/v4/note.md](../2026-11-21_miniature-01_casse/v4/note.md).
- **À vérifier sur un vrai téléphone**, comme le conseille la vidéo. L'outil qu'elle cite, qptr.io, demande d'y
  envoyer l'image : à faire seulement si Clément le veut.
