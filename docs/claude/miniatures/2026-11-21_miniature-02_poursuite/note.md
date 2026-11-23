# Miniature 02, la poursuite (MOD-043, 2026-11-21)

C'est la scène 2 du brief (« OUTRUN THE GUARD »), faite par ChatGPT dans le Chrome de Clément et retouchée selon ses
demandes. Sont posés en Python : l'argent en arc-en-ciel, les « !! » sur le vigile et la flèche rouge de l'argent vers
le PC. Rien n'est publié.

| Fichier | Contenu |
| --- | --- |
| [THUMB_02_Poursuite.png](THUMB_02_Poursuite.png) | Miniature 1920 × 1080, PNG, 2,1 Mo |
| [THUMB_02_Poursuite_controle_320x180.png](THUMB_02_Poursuite_controle_320x180.png) | Contrôle à 320 × 180 |
| [THUMB_02_Poursuite_controle_zones.png](THUMB_02_Poursuite_controle_zones.png) | Bande des 216 px du bas en rouge, tiers en blanc (960 × 540) |
| `chatgpt/chatgpt_poursuite.png` | Image téléchargée depuis chatgpt.com (1672 × 941, 1,9 Mo), source de la miniature |
| `apercu_chatgpt_1.png` à `_5.png` | Captures d'écran des 5 étapes, montrées à Clément (ce ne sont pas des images finales) |
| [prompt.md](prompt.md) | Le premier prompt et les éléments du jeu relevés dans Studio |

Refaire, dans PowerShell, depuis la racine du dépôt :

```powershell
$env:ETIQUETTE = '|||+$63.2B/s'; $env:ETIQUETTE_CENTRE = '560,228'; $env:ETIQUETTE_TAILLES = '54,40,40,120'; $env:ETIQUETTE_RARETE = '#2F9BFF'; $env:ETIQUETTE_ARC_EN_CIEL = '1'; $env:EXCLAMATION = '1005,500,165,-10'; $env:FLECHE_ARC = '250,282,128,-106,-272,36'
```

```powershell
py -I tools/clement/miniatures/miniature_ia.py docs/claude/miniatures/2026-11-21_miniature-02_poursuite/chatgpt/chatgpt_poursuite.png docs/claude/miniatures/2026-11-21_miniature-02_poursuite - haut-droite THUMB_02_Poursuite.png
```

## Comment elle a été faite

1. **Prompt 1** (voir `prompt.md`) : la scène du brief dans la rue de Tokyo de la zone 3. ChatGPT reçoit le perso de
   l'icône v3 ; le vigile `Guard_Z3`, le PC gamer et le trail Wind lui sont décrits d'après Studio. Les cerisiers et
   la tour radio qu'il dessine existent bien dans `Workspace/Map/Zone_3/Street_Tokyo`.
2. **Demande de Clément** : moins de décor, comme les meilleures miniatures du benchmark. Il reste une seule boutique
   à la vitrine cassée, de l'herbe, le ciel bleu, et un PC plus gros. L'image de l'autre jeu n'a pas été envoyée à
   ChatGPT ; on en a gardé les principes (fond simple, gros objet volé, argent au-dessus), pas sa mise en page.
3. **Demande de Clément** : un joueur plus petit, et une boutique aux couleurs naturelles, sans néons, avec une
   pancarte « SHOP ».
4. **Demande de Clément** : un joueur un peu plus grand et un PC plus gros. Puis on recule la caméra pour laisser du
   ciel au-dessus du PC.
5. Téléchargement, puis `miniature_ia.py` : recadrage en 16:9, agrandissement en 1920 × 1080 (environ 15 %), et
   l'argent posé au-dessus du PC.

## Ce qui est montré

- Le bacon hair à cagoule de l'icône v3 s'enfuit en portant au-dessus de sa tête un très gros PC gamer
  (`ITM_Z3_PcGamer`, boîtier sombre à bordures dorées, néons, halo bleu des Rares), avec son trail menthe.
- Le vigile de la zone 3 (`Guard_Z3` : casquette marine à bande dorée, baudrier jaune fluo, matraque au bout rouge)
  le poursuit, le bras tendu.
- Derrière : une boutique « SHOP » en brique, avec un store rayé et la vitrine cassée. Les éclats sont sur l'herbe,
  sous un ciel bleu à rayons.

## Contrôle

- 1920 × 1080, 2,1 Mo, donc moins de 3 Mo. ✓
- **Argent** : « +$63.2B/s » au-dessus du PC (la ligne Income de `BB_Item`, corps de 120 px). À la demande de
  Clément, elle est en **arc-en-ciel**, avec les couleurs du jeu pour la rareté Secret (`Rarities.Secret.RainbowColors`,
  `#FF3B3B` → `#A855F7`). ✓
- **« !! »** au-dessus du vigile : deux « ! » dans le style du « ! » de sa bulle `BB_GuardShout` (`#FF2D55`, contour
  `#040435`), un peu penchés. ✓
- **Flèche rouge**, à la demande de Clément : un arc épais à gauche de l'argent, qui part du « + » et descend vers le
  PC. Trait plein au rouge `#E3241B` du texte de `BB_GuardShout`, contour sombre fin, grosse pointe. ✓
- Les arcs-en-ciel, « !! » et flèches sont des procédés courants des miniatures du genre. Ils sont dessinés ici aux
  couleurs du jeu, sans reprendre la mise en page d'un autre jeu.
  **Valeur volontairement gonflée**, comme sur la miniature 01, à la demande de Clément. En jeu, le PC gamer (Rare,
  3e des 4 Rares de la zone 3) rapporte 60 × 1,1² = 72,6 $/s de base (« +$72.6/s », `Formulas.ItemIncome`). Ne
  jamais reprendre la valeur de la miniature comme valeur du jeu ; Roblox peut refuser une miniature trompeuse.
- **À 320 × 180**, on lit l'argent, le PC, le braqueur, le vigile et « SHOP ». ✓
- **Bas** : les 216 px du bas montrent l'herbe et les baskets du perso, sans visage ni objet important. ✓
- **Écarts au brief, décidés par Clément** :
  - pas de titre « OUTRUN THE GUARD » ;
  - de l'herbe au lieu de la route grise à flèches ;
  - une boutique « SHOP » générique au lieu de la rue de Tokyo.

  Les vrais modèles (perso, vigile, PC, trail) sont redessinés par l'IA, et le PC est plus gros qu'en jeu.
- La bulle complète du vigile (`BB_GuardShout`, « THIEF! ») n'est pas posée. Clément a préféré les « !! ».
