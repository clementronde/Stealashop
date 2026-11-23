# Logo sans texte, en tuile carrée (MOD-043, 2026-11-21)

Clément voulait un logo qui fasse **comprendre le jeu sans texte**, comme les tuiles des jeux du moment sur Roblox :
une image carrée pleine, sans cadre, avec un perso et un très gros objet sur un fond vif. Faite par ChatGPT dans son
Chrome, **choisie par Clément comme logo**. L'icône v3 reste l'icône de la page. Rien n'est publié.

| Fichier | Contenu |
| --- | --- |
| [LOGO_StealAShop_tuile.png](LOGO_StealAShop_tuile.png) | Logo 512 × 512, PNG, 410 Ko |
| [LOGO_StealAShop_tuile_1024.png](LOGO_StealAShop_tuile_1024.png) | Logo 1024 × 1024, PNG, 1,3 Mo |
| [controle_planche.png](controle_planche.png) | À 512, 150 et 64 px, coins arrondis, cercle de 440 px |
| [controle_grille.png](controle_grille.png) | À 150 px au milieu des 14 icônes « Steal a … » du benchmark |
| [controle_comparaison.png](controle_comparaison.png) | À côté de l'icône v3, à 150 et 64 px |
| `chatgpt/chatgpt_tuile.png` | Image téléchargée depuis chatgpt.com (1254 × 1254, 2,0 Mo), source du logo |
| `chatgpt/chatgpt_tuile_v1_grosse-couronne.png` | Première version, avec une Couronne plus grosse (remplacée) |
| `apercu_*.png` | Captures d'écran des essais : la planche de 3 emblèmes ronds sur fond blanc, puis la tuile |

Refaire la finition et les contrôles :
`py -I tools/clement/miniatures/controle_icone.py docs/claude/miniatures/2026-11-21_logo/embleme/chatgpt/chatgpt_tuile.png docs/claude/miniatures/2026-11-21_logo/embleme LOGO_StealAShop_tuile.png docs/claude/miniatures/2026-11-21_icone/v3/ICON_StealAShop_v3.png`
(et la version 1024 : la même image réduite en 1024 × 1024, LANCZOS, léger renfort de netteté).

## Comment il a été fait

1. Planche de 3 emblèmes ronds sur fond blanc : la vitrine cassée, la mascotte, la fuite
   (`apercu_emblemes.png`). Clément a montré les tuiles des jeux du moment : le logo doit être une image carrée
   pleine, pas un badge.
2. La tuile : le bacon hair à cagoule de l'icône v3 sort en courant d'une boutique à la vitrine cassée, avec une
   Couronne géante au-dessus de la tête. Derrière lui, des éclats de verre, un ciel bleu à rayons et de l'herbe.
   Pas de texte.
3. À la demande de Clément : la même tuile avec une Couronne environ 30 % plus petite, pour que le perso se voie
   mieux.

## Ce qui est montré

- **Le vol** : le braqueur masqué emporte l'objet précieux, la Couronne (Épique, halo violet), plus grosse qu'en jeu
  pour se lire en petit.
- **La casse** : la boutique (store rouge et blanc, comme la boutique « SHOP » de la miniature 02) a sa vitrine
  brisée.
- Les éléments viennent du jeu : le perso de l'icône v3, la Couronne `ITM_Z4_Couronne` et la vitrine qui éclate.

## Contrôle

- 512 × 512 et 1024 × 1024, PNG, sans texte. ✓
- **À 150 et à 64 px**, on lit la Couronne géante, le braqueur masqué qui court et la boutique cassée. ✓
- **Dans la grille du benchmark**, la tuile ressemble aux jeux du moment (un perso qui emporte un très gros objet) et
  se distingue par la Couronne et la boutique cassée. ✓
- **Cercle de 440 px** : avec la Couronne réduite, la Couronne et le perso y sont. Seule la basket au premier plan
  touche le bord du cercle, loin des coins arrondis. ✓
- **Écarts** : comme pour l'icône v3, c'est un rendu d'illustration par IA. La Couronne est bien plus grosse qu'en
  jeu, et la boutique est générique.
- Les 3 logos texte « STEAL A SHOP » ([../note.md](../note.md)) restent disponibles pour d'autres usages (écran de
  chargement, vidéos).
