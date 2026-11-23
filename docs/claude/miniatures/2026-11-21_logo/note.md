# Logos « STEAL A SHOP » : 3 propositions (2026-11-21)

> **Logo retenu par Clément le 2026-11-21 : le logo sans texte, en tuile carrée** ([embleme/note.md](embleme/note.md)).
> Les 3 logos texte ci-dessous restent des options pour d'autres usages (écran de chargement, vidéos).

Tâche : MOD-043 (page du jeu). Fait en Python avec Pillow (`tools/clement/miniatures/logos.py`, relançable), polices
libres (licence OFL) livrées avec Roblox Studio : **Luckiest Guy** (1 et 2) et **Fredoka One** (3). Rien de publié.

| Fichier | Usage |
| --- | --- |
| `LOGO_<n>_<nom>_fond-clair.png` | Contour noir `#1B1B24` seul : fonds clairs ou moyens (ciel, herbe, miniatures de jour) |
| `LOGO_<n>_<nom>_fond-sombre.png` | Contour noir + liseré blanc : fonds sombres (nuit, violet de l'UI, noir) |
| [apercu-200px.png](apercu-200px.png) | Les 3 logos **à 200 px de large** sur blanc, ciel du jeu, bleu nuit de l'UI et noir |
| [planche-damier.png](planche-damier.png) | Les 3 en grand sur damier (la transparence se voit) |

## Les 3 propositions

1. **Classique** : « STEAL A » blanc, « SHOP » or (dégradé `#FFEC78` → `#FFC21A` → `#F08C00`), légèrement penché.
   Même idée que le logo de l'écran de chargement (`UI_Loading_Logo`, 134874268685857, validé le 15/11), en plus
   propre et sans pictogramme : le plus lisible des trois à 200 px.
2. **Vitrine cassée** : « STEAL A » rouge, « SHOP » or, devant une vitre bleue fendue depuis un point d'impact, avec des
   éclats qui partent en haut à droite. Dit « on casse une vitrine » ; le pictogramme reste lisible à 200 px, les
   fêlures fines beaucoup moins.
3. **La masse** : « STEAL A » blanc, « SHOP » orange, la masse en travers derrière le texte et une étoile d'impact.
   Dit « on frappe », mais le texte est plus petit à largeur égale (la masse prend de la place).

**Ma recommandation : 1 pour la page et l'écran de chargement, 2 pour les miniatures où le logo est petit et doit dire
le jeu à lui seul.** Le logo n'est jamais sur l'icône (pas de texte sur l'icône, brief section 1).

## À faire avant usage

- Le logo existant de l'écran de chargement et le logo 1 doivent rester le même logo : choisir l'un des deux.
- Les polices OFL peuvent servir dans un jeu et sur sa page ; garder les fichiers de police avec les sources si Clément
  les reprend dans Photoshop (`%LOCALAPPDATA%\Roblox\Versions\*\content\fonts\`).
