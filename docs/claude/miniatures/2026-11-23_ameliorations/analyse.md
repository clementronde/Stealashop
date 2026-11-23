# Analyse et amélioration des 38 miniatures de Clément (MOD-043, 2026-11-23)

Clément a envoyé 38 miniatures, dans `miniatures_steal_a_shop_partie_1.zip` puis `miniatures_steal_a_shop.zip`. Elles
sont rangées dans [originaux/](originaux/), avec les noms du zip sans accents. La demande : les analyser avec un œil
d'expert du taux de clic, puis les améliorer. Rien n'est publié.

**Validé par Clément le 2026-11-23** : les 15 miniatures améliorées et le classement des 10 à mettre en ligne en
premier.

## Ce qu'il faut retenir

- **Les 38 se ramènent à 7 idées de miniature, plus 3 logos.** Beaucoup sont des variantes de la même image, avec ou
  sans texte. 4 images viennent de nos propres conversations ChatGPT : la 06 (notre miniature 02), la 26 (notre 03),
  la 25 et la 32 (nos essais de logo).
- **15 miniatures améliorées**, dans [finales/](finales/), soit 1 à 3 par idée, faites à partir de la meilleure base.
  Les autres images sont des doublons plus faibles : chacune renvoie à la version améliorée qui la remplace.
- **Ce qui freinait le clic, presque partout** :
  - du texte incrusté qu'on ne pouvait pas corriger : « LEGENDARY » en plus de l'argent, des formats faux comme
    « 457,852 M B/s » ou « 958 B/s », des titres en français dans un jeu en anglais, parfois dans la bande du bas ;
  - des flèches fines ;
  - des fonds chargés : lampadaires, hélicoptère, coffre-fort, immeubles.
- **Ce qui a été fait** :
  - ChatGPT a retiré le texte incrusté et simplifié 6 images ;
  - le script a posé l'argent dans le style `BB_Item` du jeu, en arc-en-ciel, avec la flèche rouge de Clément vers
    l'objet, et les « !! » du vigile.

## La grille utilisée

Les règles viennent de la vidéo analysée ([../2026-11-22_analyse-video-miniatures-ia.md](../2026-11-22_analyse-video-miniatures-ia.md)),
du benchmark ([../benchmark-2026-11-21.md](../benchmark-2026-11-21.md)) et des choix de Clément :

1. **Lisible à 320 × 180**, la taille d'une vignette sur téléphone : un seul point fort, des sujets gros.
2. **Le fantasme du jeu** : casser la vitrine, voler, semer le vigile, encaisser des $/s.
3. **Des émotions lisibles** : 1 ou 2 persos, des visages assez gros.
4. **L'objet clé énorme, jamais couvert.**
5. **Un fond simple et contrasté.**
6. **L'argent seul** (sans nom ni rareté), au format du jeu « +$X/s », en arc-en-ciel. Une valeur gonflée est acceptée
   par Clément.
7. **La flèche rouge de Clément** entre l'argent et l'objet, quand la place le permet.
8. **Pas de titre, rien d'important dans les 216 px du bas** : c'est là que Roblox affiche le nombre de joueurs.
9. **Le vrai jeu** : le bacon hair à cagoule, des objets qui existent dans `Config/Items` (Couronne, Diamant géant,
   Œuf en diamant, PC gamer, Coffre de diamants).

## Les 7 idées

| Idée | Images | Améliorées |
| --- | --- | --- |
| La casse de la vitrine | 04, 12, 15, 37 | [THUMB_04_Casse](finales/THUMB_04_Casse.png), [THUMB_37_CasseVitrine](finales/THUMB_37_CasseVitrine.png) |
| La fuite avec la Couronne | 02, 09, 10, 11, 13, 14, 16, 20, 24, 36 | [THUMB_02_FuiteCouronne](finales/THUMB_02_FuiteCouronne.png), [THUMB_16_FuiteCouronneVigile](finales/THUMB_16_FuiteCouronneVigile.png), [THUMB_11_FuiteGrosPlan](finales/THUMB_11_FuiteGrosPlan.png) |
| Le diamant sous vitrine | 01, 03 | [THUMB_01_CasseDiscret](finales/THUMB_01_CasseDiscret.png), [THUMB_03_CasseRepere](finales/THUMB_03_CasseRepere.png) |
| La fuite avec l'Œuf en diamant | 07, 18, 23, 27, 28 | [THUMB_07_FuiteOeuf](finales/THUMB_07_FuiteOeuf.png), [THUMB_18_FuiteOeufBoutique](finales/THUMB_18_FuiteOeufBoutique.png) |
| Le marteau, niveau 1 contre niveau 99 | 05, 08, 17, 19, 33 | [THUMB_05_MarteauNiveaux](finales/THUMB_05_MarteauNiveaux.png), [THUMB_08_MarteauAvantApres](finales/THUMB_08_MarteauAvantApres.png) |
| La poursuite avec le PC gamer | 06, 21, 30, 31, 38 | [THUMB_06_PoursuitePC](finales/THUMB_06_PoursuitePC.png), [THUMB_31_PoursuiteTokyo](finales/THUMB_31_PoursuiteTokyo.png) |
| La boutique pleine de trésors | 22, 26, 29, 34 | [THUMB_22_SalleAuxTresors](finales/THUMB_22_SalleAuxTresors.png), [THUMB_26_Boutique](finales/THUMB_26_Boutique.png) |
| Logos et icônes, hors miniature | 25, 32, 35 | aucune |

## Les 38, une par une

| N° | Idée | Ce qui marche | Ce qui freine le clic | Verdict |
| --- | --- | --- | --- | --- |
| 01 | Diamant sous vitrine | Tension : le vigile siffle sans voir le voleur ; diamant énorme | « LEGENDARY » en plus de l'argent ; argent sans « + » | Améliorée : THUMB_01 |
| 02 | Fuite, vigile de nuit | Action, 2 émotions, vitrine cassée | « 457,852 M B/s » faux et long ; flèche fine ; Couronne petite ; lampadaire, arbre et immeubles | Améliorée : THUMB_02 |
| 03 | Diamant sous vitrine | Fond plus propre que la 01 | Presque la même image que la 01, même texte | Améliorée en variante « voleur repéré » : THUMB_03 |
| 04 | La casse | La mécanique propre au jeu, l'impact, la Couronne géante, le visage furieux | Pas d'argent | Améliorée : THUMB_04 |
| 05 | Marteau 1 contre 99 | Avant/après lisible, badges « LVL » clairs | Rien ne relie les deux moitiés | Améliorée : THUMB_05 |
| 06 | Poursuite au PC | C'est notre miniature 02 (image ChatGPT brute) | Persos un peu petits | Améliorée : THUMB_06 (notre 02 avec la flèche de Clément) |
| 07 | Fuite avec l'Œuf | Œuf énorme, 2 policiers avec « !! », voleur ravi | « 958 B/s » mal espacé ; « LEGENDARY » ; hélicoptère, coffre-fort et lingots | Améliorée : THUMB_07 |
| 08 | Marteau avant/après | Contraste petit marteau / masse géante | Long titre en français, dans la bande du bas ; flèche fine | Améliorée : THUMB_08 |
| 09 | Fuite, vigile de nuit | — | Doublon de la 02 ; « 457,852 M/S » faux | Remplacée par THUMB_02 |
| 10 | Fuite, vigile de nuit | — | Doublon de la 02 ; « 457,852 B/s » sans « $ » | Remplacée par THUMB_02 |
| 11 | Fuite en gros plan | Visages énormes, émotions fortes | Couronne coupée en bas ; les lunettes cachent les yeux du vigile ; pas d'argent | Améliorée : THUMB_11 |
| 12 | La casse | Variante de la 04 | Voleur qui sourit : moins de tension que la 04 | Remplacée par THUMB_04 |
| 13 | Fuite, vigile bleu | Grand perso, grosse Couronne | « $548B/s LEGENDARY » | Remplacée par THUMB_16 |
| 14 | Fuite, vigile bleu | — | Titre et question en français, dont un dans la bande du bas | Remplacée par THUMB_16 |
| 15 | La casse | — | « $548B/s LEGENDARY » ; doublon de la 04 | Remplacée par THUMB_04 |
| 16 | Fuite, vigile bleu | Le « ! » du vigile, la joie du voleur, le vigile aux couleurs du jeu | « $548B/s LEGENDARY » | Améliorée : THUMB_16 |
| 17 | Marteau 1 contre 99 | — | Doublon de la 05, badges plus pauvres | Remplacée par THUMB_05 |
| 18 | Fuite avec l'Œuf, dans la boutique | Gros plan, 2 policiers | Fond violet chargé (bannières à dragon), pas d'argent | Améliorée : THUMB_18 |
| 19 | Marteau 1 contre 99 | — | Doublon de la 05 | Remplacée par THUMB_05 |
| 20 | Fuite, vigile bleu | — | 3 textes (titre en français, argent et rareté, question en français) et une flèche : surchargée | Remplacée par THUMB_16 |
| 21 | Poursuite au PC | — | Doublon de la 06 | Remplacée par THUMB_06 |
| 22 | Boutique pleine | Gros visage ravi, coffre de diamants, trésors | Pas d'argent | Améliorée : THUMB_22 |
| 23 | Fuite avec l'Œuf | — | Doublon de la 07, avec son texte | Remplacée par THUMB_07 |
| 24 | Fuite, vigile bleu | — | Titre et question en français, dont un dans la bande du bas | Remplacée par THUMB_16 |
| 25 | Logo | C'est notre logo en tuile, déjà choisi | Ce n'est pas une miniature | Logo, déjà en place |
| 26 | Boutique pleine | C'est notre miniature 03 (image ChatGPT brute), validée | Perso petit, de dos | Améliorée : THUMB_26 (notre 03 avec la flèche de Clément) |
| 27 | Fuite avec l'Œuf | — | « $999,999,999/s », rareté et hélicoptère | Remplacée par THUMB_07 |
| 28 | Fuite avec l'Œuf | — | « $9,999,999/s » et rareté ; ville chargée | Remplacée par THUMB_07 |
| 29 | Boutique pleine | — | Bandeau « 457,852 M/S », format faux | Remplacée par THUMB_22 |
| 30 | Poursuite au PC | — | Plan large, persos minuscules à 320 × 180 | Remplacée par THUMB_06 |
| 31 | Poursuite au PC, à Tokyo | La rue de la zone 3 (cerisiers, néons) | Fond chargé, pas d'argent | Améliorée : THUMB_31 |
| 32 | Logo | Notre premier essai de logo, à grosse Couronne | Ce n'est pas une miniature | Logo, gardé en réserve |
| 33 | Marteau 1 contre 99 | — | Badges dans la bande du bas, cachés par le nombre de joueurs | Remplacée par THUMB_05 |
| 34 | Boutique pleine | — | Perso de dos ; doublon de la 26 | Remplacée par THUMB_26 |
| 35 | Icônes | 3 idées d'icône sur fond blanc | Ce n'est pas une miniature | Hors miniatures (idées d'icône) |
| 36 | Fuite, vigile de nuit | — | Bulle « 457,852 M/S » ; doublon de la 02 | Remplacée par THUMB_02 |
| 37 | La casse, vitrine en verre | Intérieur, Couronne sous verre, l'éclat du coup | Pas d'argent | Améliorée : THUMB_37 |
| 38 | Poursuite au PC, boutique néon | — | Doublon de la 06 | Remplacée par THUMB_06 |

## Les 15 améliorées

Comparaisons avant/après : [comparaison_1.png](comparaison_1.png) à [comparaison_4.png](comparaison_4.png). Les 15 en
320 × 180 : [planche_finales_320x180.png](planche_finales_320x180.png).

| Miniature | Base | Ce qui a changé | Argent |
| --- | --- | --- | --- |
| THUMB_01_CasseDiscret | 01, retouchée | Texte retiré par ChatGPT ; argent au-dessus du diamant ; flèche à droite vers le diamant | +$548B/s |
| THUMB_03_CasseRepere | 03, retouchée | Texte retiré ; le vigile a repéré le voleur (yeux ronds, bouche ouverte, il pointe du doigt) ; pas de flèche, son doigt guide déjà le regard | +$548B/s |
| THUMB_02_FuiteCouronne | 02, retouchée | Texte et flèche fine retirés ; Couronne 2 fois plus grosse, à halo violet ; ciel bleu sans lampadaire ni immeubles ; « !! » sur le vigile ; flèche vers la Couronne | +$457.8B/s |
| THUMB_16_FuiteCouronneVigile | 16, retouchée | Texte retiré ; argent dans le ciel au-dessus de la Couronne ; flèche vers la Couronne | +$548B/s |
| THUMB_11_FuiteGrosPlan | 11 | Argent en haut à droite ; flèche vers la Couronne | +$458B/s |
| THUMB_04_Casse | 04 | Argent au-dessus de la Couronne ; flèche vers la Couronne | +$48.7B/s |
| THUMB_37_CasseVitrine | 37 | Argent dans la vitrine, au-dessus de la Couronne ; flèche vers la Couronne | +$48.7B/s |
| THUMB_07_FuiteOeuf | 07, retouchée | Texte, flèche fine, hélicoptère, coffre-fort et lingots retirés ; ciel bleu et herbe ; flèche vers l'Œuf | +$958B/s |
| THUMB_18_FuiteOeufBoutique | 18 | Argent en haut entre les bannières ; pas de flèche, la tête du voleur monte jusqu'en haut | +$958B/s |
| THUMB_05_MarteauNiveaux | 05 | Flèche de « LVL 1 » vers « LVL 99 » | — |
| THUMB_08_MarteauAvantApres | 08, retouchée | Titre en français et flèche fine retirés ; flèche en haut, du petit marteau vers la masse | — |
| THUMB_06_PoursuitePC | 06 | Notre miniature 02, avec la flèche de Clément au lieu de la flèche dessinée | +$63.2B/s |
| THUMB_31_PoursuiteTokyo | 31 | Argent dans le ciel ; flèche vers le PC ; « !! » sur le vigile | +$63.2B/s |
| THUMB_22_SalleAuxTresors | 22 | Argent au-dessus du coffre ; flèche vers le coffre | +$1.2T/s |
| THUMB_26_Boutique | 26 | Notre miniature 03, avec la flèche de Clément | +$1.2T/s |

**Valeurs** : toutes sont volontairement gonflées, à la demande de Clément. On reprend celles de ses images quand il y
en avait (548B, 457,852 M, soit 457.8B, et 958B) et celles de nos miniatures sinon. Ce ne sont pas des valeurs du jeu.

## Les 10 à mettre en ligne en premier

Il ne faut pas mettre en ligne des doublons. Ce classement, validé par Clément, reste un avis d'expert à confirmer par les chiffres. La page
d'un jeu Roblox accepte un nombre limité d'images (10 au plus, à vérifier dans le Creator Hub).

1. **THUMB_04_Casse** : la mécanique qui distingue le jeu, l'impact énorme, la Couronne géante et un visage furieux.
2. **THUMB_16_FuiteCouronneVigile** : la fuite, avec deux émotions (joie contre colère) et le vigile aux couleurs du jeu.
3. **THUMB_03_CasseRepere** : pris sur le fait, sourire contre stupeur, diamant énorme.
4. **THUMB_07_FuiteOeuf** : un butin énorme, un fond très simple, deux policiers. À surveiller : un œuf peut faire
   penser aux jeux d'œufs, alors que l'Œuf en diamant est bien un objet du jeu.
5. **THUMB_22_SalleAuxTresors** : la récompense, avec un gros visage ravi.
6. **THUMB_02_FuiteCouronne** : la poursuite avec le vigile de nuit.
7. **THUMB_01_CasseDiscret** : la tension du vol discret.
8. **THUMB_05_MarteauNiveaux** : la progression, de « LVL 1 » à « LVL 99 ».
9. **THUMB_11_FuiteGrosPlan** : des visages énormes.
10. **THUMB_06_PoursuitePC** : notre miniature 02, ciel bleu et panneau « SHOP ».

En réserve : THUMB_08, THUMB_18, THUMB_26, THUMB_31, THUMB_37. S'y ajoutent les miniatures « la casse » et
« avant/après », qui n'étaient pas dans le zip.

## Contrôle

- 15 miniatures en 1920 × 1080, de 2,1 à 2,7 Mo, donc moins de 3 Mo. ✓
- **À 320 × 180** : l'argent, l'objet et les persos se lisent sur les 15. L'argent est plus petit sur THUMB_11 et
  THUMB_02, à cause de la place. ✓
- **Bas** : aucun texte ni objet clé dans les 216 px du bas. Le contrôle de chaque miniature est dans `finales/`
  (`_controle_320x180` et `_controle_zones`). ✓
- **À vérifier sur un vrai téléphone**, comme pour les autres miniatures.

## Les retouches de ChatGPT

Elles ont été faites dans le Chrome de Clément, une conversation par image, avec l'image d'origine jointe. Les
téléchargements ont été autorisés par Clément le 2026-11-23. Les images téléchargées sont dans [chatgpt/](chatgpt/),
et les captures d'écran dans [apercus_chatgpt/](apercus_chatgpt/).

- **01** : « Edit this exact image. Remove all the text: the green '$548B/s' and the yellow 'LEGENDARY' above the glass
  case, and repaint that area with the same purple glowing background, so there are no letters or numbers anywhere in
  the image. Keep everything else exactly the same: the same masked bacon hair thief sneaking on the left with his sly
  grin, the same giant glowing blue diamond on its red cushion in the glass case, the same guard on the right with
  closed eyes whistling a music note, the same framing and the same style, wide 16:9. »
- **02** : « Edit this exact image, same characters and same style, with only these changes: 1) remove the rainbow
  text '457,852 M B/s' and the thin red arrow, and leave plain clear blue sky there, so there are no letters or numbers
  anywhere in the image; 2) make the golden crown in the thief's hands about twice as big, glowing with a purple aura,
  still held in his hands and fully visible; 3) simplify the background on the right: plain clear blue sky with no
  clouds, no street lamp, no tree and no buildings. Keep the shop with its smashed display window, the angry guard
  chasing out of it and the scared masked bacon hair thief running away with the crown. No text, no arrow, no UI, wide
  16:9. »
- **03** : « Edit this exact image, same characters and same style, with only these changes: 1) remove all the text:
  the green '$548B/s' and the yellow 'LEGENDARY' above the glass case, and repaint that area with the same purple
  glowing background, so there are no letters or numbers anywhere in the image; 2) the guard on the right has just
  spotted the thief: his eyes are wide open and shocked, eyebrows raised, mouth wide open in surprise, and he points at
  the thief with one hand; remove the music note. Keep everything else exactly the same: the masked bacon hair thief
  sneaking on the left with his sly grin, the giant glowing blue diamond on its red cushion in the glass case, the same
  framing, wide 16:9. »
- **07** : « Edit this exact image, same characters and same style, with only these changes: 1) remove all the text
  ('958 B/s' and 'LEGENDARY') and the red arrow, and leave plain clear blue sky there, so there are no letters or
  numbers anywhere in the image; 2) remove the helicopter; 3) simplify the background: plain clear blue sky with no
  clouds and bright green grass, keep only the shop on the right, with no vault and no gold bars. Keep the happy masked
  bacon hair running with the giant glowing purple diamond egg in his arms, and the two angry policemen chasing him
  with the red exclamation marks. No text, no arrow, no UI, wide 16:9. »
- **08** : « Edit this exact image, same characters and same style, with only these changes: remove the big text at
  the bottom ('DU PETIT MARTEAU À LA MASSE ULTIME') and the red arrow in the middle, and fill those areas with the scene
  behind them (the pavement, the shop fronts, the glass shards), so there are no letters or numbers anywhere in the
  image. Keep everything else the same: the diagonal white split, the nervous masked bacon hair with the small hammer
  in front of the intact window on the left, and the fierce masked bacon hair smashing the window with the giant
  glowing purple and gold sledgehammer on the right. No text, no arrow, no UI, wide 16:9. »
- **16** : « Edit this exact image, same characters and same style, with only these changes: remove all the text (the
  green '$548B/s' and the yellow 'LEGENDARY' at the top right) and leave plain clear blue sky there, so there are no
  letters or numbers anywhere in the image. Keep everything else exactly the same: the happy masked bacon hair running
  with the big golden crown, the angry guard chasing him with the red exclamation mark above his head, the shop with
  its smashed display window, the same framing, wide 16:9. »

## Refaire les 15

Dans PowerShell, depuis la racine du dépôt :

```powershell
powershell -ExecutionPolicy Bypass -File tools/clement/miniatures/ameliorations_2026-11-23.ps1
```

Le script [ameliorations_2026-11-23.ps1](../../../../tools/clement/miniatures/ameliorations_2026-11-23.ps1) contient les
réglages de chaque miniature : argent, flèche, « !! ». `-Seulement 04,16` n'en refait que certaines, et `-Sortie`
choisit un autre dossier.

## Fichiers

| Dossier ou fichier | Contenu |
| --- | --- |
| [originaux/](originaux/) | Les 38 images de Clément |
| [chatgpt/](chatgpt/) | Les 6 retouches de ChatGPT (01, 02, 03, 07, 08, 16), 1672 × 941 |
| [apercus_chatgpt/](apercus_chatgpt/) | Les captures d'écran des retouches, et leur planche |
| [finales/](finales/) | Les 15 miniatures améliorées, chacune avec son contrôle à 320 × 180 et sa carte des zones |
| [comparaison_1.png](comparaison_1.png) à [comparaison_4.png](comparaison_4.png) | Avant et après, côte à côte |
| [planche_finales_320x180.png](planche_finales_320x180.png) | Les 15 à la taille d'une vignette sur téléphone |
