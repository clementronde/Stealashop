# Icône « La casse » v2 (MOD-043, 2026-11-21)

Retouche par ChatGPT, faite dans le Chrome de Clément avec son compte, à partir de la vraie capture Studio de la v1
([../note.md](../note.md)). Clément a choisi la variante **bacon hair avec cagoule**. Rien n'est publié.

**Remplacée par la v3** le même jour : tenue bacon hair, mains, pose et masse revues ([../v3/note.md](../v3/note.md)).

## Fichiers

| Fichier | Contenu |
| --- | --- |
| [ICON_StealAShop_v2.png](ICON_StealAShop_v2.png) | Icône 512 × 512, PNG, 400 Ko |
| [controle_planche.png](controle_planche.png) | Icône à 512, 150 et 64 px, coins arrondis, cercle de 440 px |
| [controle_grille.png](controle_grille.png) | Icône à 150 px au milieu de 14 icônes « Steal a … » relevées au benchmark |
| [controle_comparaison.png](controle_comparaison.png) | v1 et v2 côte à côte, à 150 et 64 px |
| `controle_150px.png`, `controle_64px.png` | Réductions seules |
| `chatgpt/chatgpt_cagoule.png` | Image téléchargée depuis chatgpt.com (1254 × 1254, 1,9 Mo), source de l'icône |
| `apercu_versions.png`, `apercu_baconhair.png`, `apercu_chatgpt_*.png` | Captures d'écran des versions essayées, montrées à Clément pour choisir (ce ne sont pas des images finales) |
| [prompt.md](prompt.md) | Les 4 prompts envoyés et ce qu'ils ont donné |

Refaire la finition et les contrôles à partir de l'image téléchargée :
`py -I tools/clement/miniatures/controle_icone.py docs/claude/miniatures/2026-11-21_icone/v2/chatgpt/chatgpt_cagoule.png docs/claude/miniatures/2026-11-21_icone/v2 ICON_StealAShop_v2.png`

## Comment elle a été faite

1. ChatGPT reçoit la capture brute et l'icône v1 (pour le cadrage). Le prompt décrit la scène du jeu et demande de la
   rendre lisible à 150 px (prompt 1). On obtient la version 1, qui sert de base.
2. Un essai de dézoom pour tout faire tenir dans le cercle (prompt 2) donne la version 2 : le sujet y devient trop
   petit, elle est abandonnée.
3. À la demande de Clément, sur la version 1 : un perso en bacon hair et une masse plus jolie, mais le même outil
   avec les mêmes couleurs (prompt 3). Puis la même image avec une cagoule (prompt 4). Clément choisit la cagoule.
4. Téléchargement de cette seule image (avec l'accord de Clément), réduction en 512 avec un léger renfort de netteté,
   puis les contrôles.

## Ce qui est montré

- **Moment** : la casse de la vitrine de la Bijouterie vue de l'intérieur de la boutique, comme dans la capture de la
  v1.
- **Perso** : un avatar R15 en bacon hair (les cheveux gratuits de Roblox) avec une cagoule noire, un sweat orange et
  un pantalon bleu nuit. C'est un avatar générique, ni un joueur connu ni le personnage d'un autre jeu.
- **Masse** : `TOOL_Masse` redessinée plus nette (tête de métal sombre biseautée, bande néon rose, manche violet). La
  forme et les couleurs restent celles du jeu.
- **Vitre** : éclats et cubes de verre bleu clair, flash blanc à l'impact, cadre jaune de la vitrine en bas à gauche.
- **Objet** : la Couronne `ITM_Z4_Couronne` (Épique) au premier plan, avec son halo violet.

## Contrôle

- 512 × 512, PNG, sans texte. ✓
- **À 150 px**, on lit un braqueur masqué qui casse une vitre avec une masse, et une couronne dorée. ✓ À 64 px, le
  perso orange, la masse et la Couronne se voient encore. ✓
- **Dans la grille** ([controle_grille.png](controle_grille.png)), l'icône est aussi saturée et lisible que ses
  voisines. C'est aussi la seule à montrer un braquage. ✓
- **Cercle de 440 px** : le perso, la masse et l'impact y sont, l'impact sur le bord gauche. Le bas droit de la
  Couronne en sort et les coins arrondis en coupent un peu, mais on lit toujours la croix, les perles et l'or.
- **Écart au brief** : le rendu est une illustration, plus poussée que les « +10 à 15 % de contraste et de
  saturation » du brief, avec un visage et des cheveux qui ne viennent pas de la capture. C'est le choix de Clément
  (retouche IA, 2026-11-21). La scène, la masse, la vitrine et la Couronne restent celles du jeu.
- **À vérifier par Clément** : que la masse retouchée reste assez proche de `TOOL_Masse` en jeu.
