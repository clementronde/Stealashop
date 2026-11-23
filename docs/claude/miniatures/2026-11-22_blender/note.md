# Test d'une chaîne Blender : la miniature 01 avec nos vrais modèles (MOD-043, 2026-11-22)

Clément voulait savoir si l'on peut faire comme le concurrent « Casser et voler » : un rendu 3D des vrais modèles du jeu,
retouché ensuite (benchmark, section « Concurrent direct »). Rien n'est publié.

| Fichier | Contenu |
| --- | --- |
| [THUMB_01_Casse_blender.png](THUMB_01_Casse_blender.png) | Miniature 1920 × 1080 : le rendu Blender, retouché, avec « +$48.7B/s » et la flèche |
| [comparaison_ia_blender.png](comparaison_ia_blender.png) | La version IA (v4) et la version Blender, en grand et à 320 × 180 |
| `rendu_casse_1920.png` | Le rendu Blender brut (Cycles, 128 échantillons, 3 min 30 sur la carte graphique) |
| `essais/` | Les 7 essais de cadrage et de lumière (960 px) |
| `studio_mise-en-scene.jpg` | La scène posée dans Studio, avant l'export |
| `export/` | L'OBJ exporté de Studio par Clément (`casse.obj`, son `.mtl` et ses textures) |

## La chaîne

1. **Studio**, en Edit, avec des copies dans `workspace.CurrentCamera._MINIATURE_TMP` :
   - insertion de 2 modèles gratuits du Creator Store, aussitôt vidés de leurs scripts : « R15 Bacon Hair »
     (4278649430) et une cagoule (130752228296009) ;
   - puis `tools/clement/miniatures/blender_casse_scene.luau` : la pose `HitWindowHeavy` du jeu à son marqueur Impact,
     la masse `TOOL_Masse` en main, les cubes de verre, la Couronne sur un socle sous verre.
2. **Clément exporte** `_MINIATURE_TMP` et `STORE_Z4_Bijouterie` en OBJ (clic droit, « Export Selection »). C'est la
   seule étape à la main : Claude n'a pas d'outil d'export.
3. **Studio est remis comme avant** : vitre visible, dossier supprimé, rien d'enregistré.
4. **Blender 5.3**, sans interface : `tools/clement/miniatures/blender_casse_rendu.py`.
   - Studio n'exporte pas les vêtements ni les textures de l'avatar : ils sont recolorés (haut noir, cravate bleue,
     pantalon sombre, baskets blanches, cagoule noire et yeux, cheveux roux).
   - Les grands éclats de la vitre, invisibles avant la casse et donc absents de l'export, sont recréés.
   - La masse est grossie de 1,5 fois autour de la main pour se lire en petit. Le flash d'impact, le halo violet de la
     Couronne, le ciel, la caméra et la lumière sont ajoutés dans Blender.
5. **Finition** : `miniature_ia.py` avec `RETOUCHE` (contraste et saturation), l'argent arc-en-ciel et la flèche.

Refaire le rendu (PowerShell, depuis la racine du dépôt) :

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.3\blender.exe" -b --factory-startup --python tools/clement/miniatures/blender_casse_rendu.py -- docs/claude/miniatures/2026-11-22_blender/export/casse.obj docs/claude/miniatures/2026-11-22_blender/rendu_casse_1920.png 1920 128
```

```powershell
$env:RETOUCHE = '1.08,1.2'; $env:ETIQUETTE = '|||+$48.7B/s'; $env:ETIQUETTE_CENTRE = '1600,205'; $env:ETIQUETTE_TAILLES = '54,40,40,100'; $env:ETIQUETTE_ARC_EN_CIEL = '1'; $env:FLECHE_ARC = '1290,290,105,-106,-272,32'
```

```powershell
py -I tools/clement/miniatures/miniature_ia.py docs/claude/miniatures/2026-11-22_blender/rendu_casse_1920.png docs/claude/miniatures/2026-11-22_blender - haut-droite THUMB_01_Casse_blender.png
```

## Verdict du test

- **Ce qui marche** : la chaîne va de Studio à l'image finie. Le rendu a le vrai aspect du jeu : la Bijouterie, la
  masse, la Couronne, les cubes de verre et un avatar Roblox, avec des ombres douces. Ce sont les vrais modèles, comme
  le demande Roblox. Une fois la scène exportée, un nouveau rendu prend 3 à 4 minutes.
- **Moins bien que la version IA, à 320 × 180** :
  - le perso est plus petit et sa pose plus raide (c'est l'image de l'animation du jeu, pas une pose de miniature) ;
  - le fond est vide (ciel et rue grise) ;
  - les couleurs sont plus ternes ;
  - la masse se lit moins bien.
- **Pour faire aussi bien que le concurrent**, il faudrait :
  - une pose faite pour la miniature : le corps penché, les deux mains sur le manche, un visage expressif ;
  - un perso plus grand dans le cadre ;
  - un fond simple mais vivant : de l'herbe ou une rue avec quelques façades floues ;
  - les vrais vêtements de l'avatar, que l'export de Studio ne donne pas.

  Clément peut faire la pose dans Studio ou dans Blender ; le reste se règle dans `blender_casse_rendu.py`.
