# Miniature 01 « SMASH & GRAB! » v2 (MOD-043, 2026-11-21)

C'est la scène 1 du brief (la casse), refaite par ChatGPT avec le perso et la masse de l'icône v3
([../../2026-11-21_icone/v3/note.md](../../2026-11-21_icone/v3/note.md)). La mise en scène suit les demandes de
Clément, et le titre est posé en Python. Rien n'est publié.

**Remplacée par la v3** le même jour : sans titre, avec l'étiquette `BB_Item` du jeu au-dessus de la Couronne
([../v3/note.md](../v3/note.md)).

## Fichiers

| Fichier | Contenu |
| --- | --- |
| [THUMB_01_SmashGrab_v2.png](THUMB_01_SmashGrab_v2.png) | Miniature 1920 × 1080, PNG, 2,1 Mo |
| [THUMB_01_SmashGrab_v2_controle_320x180.png](THUMB_01_SmashGrab_v2_controle_320x180.png) | Contrôle à 320 × 180 |
| [THUMB_01_SmashGrab_v2_controle_zones.png](THUMB_01_SmashGrab_v2_controle_zones.png) | Bande des 216 px du bas en rouge, tiers en blanc (960 × 540) |
| `chatgpt/chatgpt_large.png` | Image téléchargée depuis chatgpt.com (1672 × 941, 1,9 Mo), source de la miniature |
| `apercu_chatgpt_large.png`, `_2`, `_3` | Captures d'écran des 3 essais, montrées à Clément (ce ne sont pas des images finales) |
| [prompt.md](prompt.md) | Les 3 prompts et ce qu'ils ont donné |

Refaire : `py -I tools/clement/miniatures/miniature_ia.py docs/claude/miniatures/2026-11-21_miniature-01_casse/v2/chatgpt/chatgpt_large.png docs/claude/miniatures/2026-11-21_miniature-01_casse/v2 "SMASH & GRAB!" haut-droite THUMB_01_SmashGrab_v2.png 158 36`

## Comment elle a été faite

1. ChatGPT reçoit l'image source de l'icône v3 et la capture brute de Studio (prompt A). Clément refuse le résultat :
   la Couronne flotte et le perso est debout dans la fenêtre.
2. Prompt B : une mise en scène naturelle. Le perso est dehors, derrière la vitre, et la casse depuis la rue ; la
   Couronne est posée sur un présentoir sous sa petite vitrine de verre. Mais le haut du cadre part en biais.
3. Prompt C : la vitrine est plate et vue de face. Clément accepte le téléchargement.
4. `miniature_ia.py` recadre en 16:9 exact (1 px en moins), agrandit en 1920 × 1080 (environ 15 %), renforce un peu
   la netteté et pose le titre.

## Ce qui est montré

- **Moment** : la casse de la vitrine de la Bijouterie (zone 4), vue de l'intérieur. Le perso est dans la rue,
  derrière la vitre, et la frappe ; le verre éclate vers nous et retombe sur le sol de la boutique.
- **Perso et masse** : les mêmes que sur l'icône v3 (bacon hair à cagoule, haut noir et cravate bleue, mains
  visibles, `TOOL_Masse` redessinée).
- **Objet** : la Couronne `ITM_Z4_Couronne` (Épique, halo violet), posée sur un présentoir sous une petite vitrine de
  verre (le brief prévoit un présentoir, Clément a demandé la vitrine).
- **Décor** : le cadre jaune de la vitrine vu de face, la rue floue en bleu ciel, le jour.

## Contrôle

- 1920 × 1080, PNG, 2,1 Mo, donc moins de 3 Mo. ✓
- **Titre** : « SMASH & GRAB! » (texte du brief) en Montserrat Black blanc, contour `#1B1B24` et ombre dure, en haut
  à droite, avec des capitales de 110 px. ✓ Il est sur **une seule ligne** et non deux : sur deux lignes, il
  cacherait la vitrine de la Couronne. Il ne touche ni le perso ni la vitrine. ✓
- **Bas** : les 216 px du bas ne montrent que le sol, les éclats tombés, le pied du présentoir et le tapis, sans
  visage ni objet important. ✓
- **Tiers** : le perso et l'impact sont à gauche, la Couronne à droite. ✓
- **À 320 × 180**, on lit le titre, le braqueur masqué qui casse la vitrine et la Couronne dans sa vitrine. ✓
- **Écarts au brief, à valider par Clément** :
  - Le rendu est une illustration, pas une capture légèrement retouchée.
  - Deux éléments sont ajoutés à la mise en scène : la petite vitrine de verre autour de la Couronne, et la traînée
    rose derrière la masse. Le brief interdit les effets peints qui n'existent pas en jeu, et Roblox demande de montrer
    le vrai jeu. Il faut donc vérifier que la Bijouterie et la masse du jeu restent proches de ce qu'on voit.
  - Agrandie d'environ 15 %, l'image est un peu moins nette qu'une image native en 1920 × 1080.
