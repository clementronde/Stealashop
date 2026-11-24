# Le braqueur avec la vraie tenue du bacon hair (MOD-043, 2026-11-23)

Le braqueur du logo, de l'icône et des 15 miniatures portait une veste de costume noire et une cravate bleue. Clément
a donné la vraie tenue de départ de Roblox (`StealAShop-Art\Discord\_chatgpt\ref_tenue_baconhair.png`) : veste
noire ouverte à manches courtes sur un t-shirt bleu vif avec une moto noire, jean vert foncé chiné, baskets blanches.
La peau reste **beige**, comme avant et comme les vigiles (correction de Clément : pas blanche, même si l'avatar de
référence l'est). Le braqueur garde sa cagoule noire et ses cheveux bacon.

ChatGPT a refait les 17 images dans le Chrome de Clément, en ne changeant que la tenue, puis la couleur de la peau.
**Clément a validé les 17 en peau beige le 2026-11-23**, ainsi que les téléchargements depuis chatgpt.com. Rien
n'est publié. Les anciennes versions restent à côté, dans le dossier parent de chaque `v_tenue/`.

## Fichiers

| Dossier | Contenu |
| --- | --- |
| [../../../2026-11-21_logo/embleme/v_tenue/](../../../2026-11-21_logo/embleme/v_tenue/) | Logo en tuile 512 et 1024 px, contrôles de `controle_icone.py`, source `chatgpt/chatgpt_tuile_tenue.png`, avant/après du logo et de l'icône |
| [../../../2026-11-21_icone/v3/v_tenue/](../../../2026-11-21_icone/v3/v_tenue/) | Icône v3 512 px, contrôles, source `chatgpt/chatgpt_pose_tenue.png` |
| ici | Les 15 `THUMB_*.png` en 1920 × 1080 (2,2 à 2,8 Mo), chacune avec `_controle_320x180` et `_controle_zones` ; [planche_finales_320x180.png](planche_finales_320x180.png) dans l'ordre du top 10 ; `comparaison_tenue_1.png` à `_5.png` (avant à gauche, après à droite) |
| `chatgpt/` | Les 15 images refaites par ChatGPT (`<nn>_tenue.png`, environ 1672 × 941) |

## Comment c'est fait

1. **Base** : la même image que pour l'ancienne finale, sans texte (retouche ChatGPT pour 01, 02, 03, 07, 08 et 16,
   original de Clément pour les autres). Une conversation ChatGPT par image, avec la base et la référence de tenue
   jointes.
2. **Prompt** (en anglais, sans le nom du jeu, sans « suit », « blazer » ni « tie ») : « Edit the first image. Keep
   exactly the same scene, framing, composition, poses, facial expressions, [objets et persos de l'image],
   background, lighting, colors, art style and thick dark outline. Change ONLY the clothes and skin color of the
   masked bacon hair thief, to match the outfit in the second image (use it only as a reference for the clothes and
   skin, not for the style or the pose): 1) pure white blocky skin on the arms and hands, like the classic Roblox
   avatar; 2) an open black jacket with short sleeves, worn over a bright blue t-shirt with a black motorcycle printed
   on the chest; 3) dark green heathered denim jeans; 4) white sneakers. He keeps his black balaclava and his
   brown-orange bacon hair, and stays a blocky Roblox R15 avatar. The guard does not change at all. Wide 16:9, same
   size as the first image. Do not add any text, letters or numbers. » Pour la 05, les badges « LVL 1 » et « LVL 99 »
   sont gardés ; pour la 06, le panneau « SHOP ».
3. **Peau beige** : le premier passage avait donné une peau blanche. Une nouvelle conversation par image, avec la
   version à la bonne tenue en première image et l'original en seconde : « Edit the first image. Keep it exactly the
   same [...] Change ONLY the thief's skin color: his arms, hands and the skin visible around his eyes must be a light
   beige skin tone, the same beige as the same character in the second image, instead of white. Every other
   character keeps its skin exactly as it is. » Les fichiers de `chatgpt/` sont ces versions beige.
4. **Finition** : [ameliorations_tenue_2026-11-23.ps1](../../../../../../tools/clement/miniatures/ameliorations_tenue_2026-11-23.ps1)
   repose l'argent, la flèche de Clément et les « !! » avec les réglages de l'ancienne finale. Le logo et l'icône sont
   finis par `controle_icone.py`, comme avant.

## Ce qui a demandé un second essai

- **01** : ChatGPT a proposé deux versions ; la 2e est gardée, le t-shirt à moto s'y voit mieux.
- **18** : ChatGPT avait aussi blanchi les mains des deux policiers ; elles sont remises en beige, comme leur visage.
- **26** : le premier prompt disait à tort que le perso était de dos ; ChatGPT l'avait retourné, sans cagoule.
  Redemandé de face, avec la cagoule.

## Contrôle

- Scène, cadrage, objets et autres persos inchangés ; l'argent, la flèche et les « !! » tombent à la même place
  qu'avant sur les 15. ✓
- 1920 × 1080, moins de 3 Mo ; rien d'important dans les 216 px du bas (cartes `_controle_zones`). ✓
- Le logo et l'icône se lisent toujours à 150 et 64 px (`controle_comparaison.png` de chaque dossier). ✓
- Peau beige sur les bras, les mains et autour des yeux ; les vigiles et les policiers gardent la leur. ✓

## Ligne du README des miniatures

À ajouter dans `docs/claude/miniatures/README.md`, sous la ligne du 2026-11-23 « 2026-11-23_ameliorations/ » :

| 2026-11-23 | [2026-11-23_ameliorations/finales/v_tenue/](2026-11-23_ameliorations/finales/v_tenue/note.md) | Le logo en tuile, l'icône v3 et les 15 miniatures refaits par ChatGPT avec la vraie tenue du bacon hair (veste noire ouverte, t-shirt bleu à moto, jean vert, peau beige) au lieu du costume et de la cravate ; rangés dans un `v_tenue/` à côté de chaque ancienne version | **Faits, validés par Clément** |
