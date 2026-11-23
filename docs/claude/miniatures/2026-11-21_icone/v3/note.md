# Icône « La casse » v3 (MOD-043, 2026-11-21)

C'est la v2 ([../v2/note.md](../v2/note.md)) reprise dans ChatGPT à la demande de Clément. Le perso garde la
cagoule et prend des mains et la tenue classique des bacon hair, puis sa pose et la masse sont revues. Choisie par
Clément. Rien n'est publié.

## Fichiers

| Fichier | Contenu |
| --- | --- |
| [ICON_StealAShop_v3.png](ICON_StealAShop_v3.png) | Icône 512 × 512, PNG, 400 Ko |
| [controle_planche.png](controle_planche.png) | Icône à 512, 150 et 64 px, coins arrondis, cercle de 440 px |
| [controle_grille.png](controle_grille.png) | Icône à 150 px au milieu de 14 icônes « Steal a … » relevées au benchmark |
| [controle_comparaison.png](controle_comparaison.png) | v1, v2 et v3 côte à côte, à 150 et 64 px |
| `controle_150px.png`, `controle_64px.png` | Réductions seules |
| `chatgpt/chatgpt_pose.png` | Image téléchargée depuis chatgpt.com (1254 × 1254, 1,9 Mo), source de l'icône |
| `apercu_tenue.png`, `apercu_pose.png`, `apercu_chatgpt_*.png` | Captures d'écran des étapes, montrées à Clément pour choisir (ce ne sont pas des images finales) |
| [prompt.md](prompt.md) | Les prompts 5 et 6 et ce qu'ils ont donné |

Refaire la finition et les contrôles à partir de l'image téléchargée :
`py -I tools/clement/miniatures/controle_icone.py docs/claude/miniatures/2026-11-21_icone/v3/chatgpt/chatgpt_pose.png docs/claude/miniatures/2026-11-21_icone/v3 ICON_StealAShop_v3.png docs/claude/miniatures/2026-11-21_icone/ICON_StealAShop_v1.png docs/claude/miniatures/2026-11-21_icone/v2/ICON_StealAShop_v2.png`

## Ce qui change par rapport à la v2

- **Perso** : bacon hair avec cagoule noire, haut noir et cravate bleue, pantalon noir, baskets blanches, mains
  visibles. C'est la tenue que portent les bacon hair dans beaucoup d'icônes de Roblox : un avatar générique, pas le
  personnage d'un jeu précis. Elle a été décrite en mots à ChatGPT, sans image d'un autre jeu.
- **Pose** : une vraie frappe, les deux mains sur le manche, le corps penché dans le coup, un pied en avant. Le perso
  est plus grand dans le cadre.
- **Masse** : plus grosse, tête de métal sombre biseautée, bande néon rose, manche violet, traînée rose derrière la
  tête. La forme et les couleurs de `TOOL_Masse` sont gardées.
- Le reste ne change pas : la vitre qui éclate, le flash d'impact, le cadre jaune de la vitrine, la Couronne Épique
  et son halo violet, le fond de rue bleu.

## Contrôle

- 512 × 512, PNG, sans texte. ✓
- **À 150 px**, on lit un braqueur masqué qui frappe la vitre avec une grosse masse, puis la Couronne dorée. La
  masse se lit mieux qu'en v2. ✓ À 64 px, on voit encore la masse, le perso et la Couronne. ✓
- **Dans la grille** ([controle_grille.png](controle_grille.png)), elle est aussi lisible que ses voisines et reste
  la seule à montrer un braquage. ✓
- **Moins bien qu'en v2** : en noir, le perso ressort un peu moins du fond bleu que le sweat orange. La tête de la
  masse et le flash touchent le bord gauche, hors du cercle de 440 px mais loin des coins arrondis. Le bas droit de la
  Couronne sort du cercle, comme en v2.
- **Écarts au brief** : les mêmes qu'en v2 (rendu d'illustration, perso redessiné), au choix de Clément. En plus,
  la traînée rose derrière la masse est un effet peint : le brief n'admet que les effets qui existent en jeu, il faut
  donc vérifier que la masse du jeu en a une.
- **À vérifier par Clément** : que la masse retouchée reste assez proche de `TOOL_Masse` en jeu.
