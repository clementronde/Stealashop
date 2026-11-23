# Miniature 01 v3, la casse avec l'étiquette du jeu (MOD-043, 2026-11-21)

C'est la v2 ([../v2/note.md](../v2/note.md)), avec la même image de ChatGPT (`../v2/chatgpt/chatgpt_large.png`).
À la demande de Clément, elle n'a **pas de titre** et porte au-dessus de la Couronne **l'étiquette du jeu avec le revenu
par seconde**. Rien n'est publié.

| Fichier | Contenu |
| --- | --- |
| [THUMB_01_Casse_v3.png](THUMB_01_Casse_v3.png) | Miniature 1920 × 1080, PNG, 2,2 Mo |
| [THUMB_01_Casse_v3_controle_320x180.png](THUMB_01_Casse_v3_controle_320x180.png) | Contrôle à 320 × 180 |
| [THUMB_01_Casse_v3_controle_zones.png](THUMB_01_Casse_v3_controle_zones.png) | Bande des 216 px du bas en rouge, tiers en blanc (960 × 540) |

Refaire, dans PowerShell, depuis la racine du dépôt :

```powershell
$env:ETIQUETTE = 'Crown|EPIC|COLOSSAL|+$4.9K/s'; $env:ETIQUETTE_CENTRE = '1540,292'; $env:ETIQUETTE_TAILLES = '54,40,40,100'; $env:ETIQUETTE_RARETE = '#A855F7'
```

```powershell
py -I tools/clement/miniatures/miniature_ia.py docs/claude/miniatures/2026-11-21_miniature-01_casse/v2/chatgpt/chatgpt_large.png docs/claude/miniatures/2026-11-21_miniature-01_casse/v3 - haut-droite THUMB_01_Casse_v3.png
```

## L'étiquette

- C'est **`BB_Item`**, le billboard que le jeu pose au-dessus d'un objet. Il est dans
  `ReplicatedStorage/Assets/UI` et a été relevé dans Studio le 2026-11-21, en lecture seule.
  - Il a 4 lignes sans fond, dans l'ordre du jeu (`LayoutOrder`) : le nom en blanc, la rareté à sa couleur, la
    mutation en or `#FFC21A`, puis le revenu en dégradé vert `#D4FF5C` → `#2FCB1F`.
  - La police est Montserrat Heavy ; ici Montserrat Black, la plus proche livrée avec Studio.
  - L'étiquette existe en jeu au-dessus d'un objet sorti de son colis ou exposé. Elle est donc permise sur une
    miniature, comme l'étiquette $/s de la scène 3 du brief.
- **Valeurs lues dans le code**, rien d'inventé :
  - la Couronne est Épique (`#A855F7`) ;
  - son revenu de base est 450 $/s × 1,1 (2e Épique de la zone 4), soit 495 $/s (`Formulas.ItemIncome`) ;
  - une Couronne Colossal pèse 10 000 kg, ce qui multiplie son revenu par 10 (racine cubique du poids,
    `Config/Weight`) : 4 950 $/s ;
  - `Format.income` l'écrit « +$4.9K/s ». `BB_Item` n'inclut pas le multiplicateur global du joueur (renaissances,
    pass), qui s'applique au total de la boutique.
- **Pour la miniature**, la ligne du revenu est agrandie (corps de 100 px) et le contour plus épais qu'en jeu, pour la
  lire en petit.
- **Clément demandait « des milliards par seconde »**. C'est impossible pour la Couronne : son étiquette affiche au plus
  +$49.5K/s, en Colossal Rainbow. Écrire des milliards serait inventer une valeur, ce que `CLAUDE.md` interdit, et
  Roblox peut refuser une miniature trompeuse. Clément a choisi le jour même une valeur gonflée :
  **v4** ([../v4/note.md](../v4/note.md)). Cette v3 reste la version avec la vraie valeur.

## Contrôle

- 1920 × 1080, 2,2 Mo, donc moins de 3 Mo. ✓
- **Pas de titre**, à la demande de Clément. Le brief prévoyait « SMASH & GRAB! » sur cette scène : c'est un écart
  décidé par lui.
- **À 320 × 180**, on lit « +$4.9K/s » et « Crown ». « EPIC » et « COLOSSAL » sont petits mais visibles. ✓
- **Bas** : les 216 px du bas ne montrent que le sol, les éclats et le pied du présentoir. ✓
- Les autres écarts sont ceux de la v2 : la vitrine de verre autour de la Couronne, la traînée rose derrière la masse,
  et l'image agrandie d'environ 15 %.
