# Référence : l'ouverture de l'œuf dans Break and Steal an Egg (vidéo de Clément, 2026-11-12)

Vidéo de 37,7 s, avec deux œufs cassés : un Épique, puis un arc-en-ciel. Analyse image par image (2 à 10 images par seconde) et analyse du son (enveloppe, attaques, hauteur des notes). Le son de l'enregistrement est faible, donc les mesures sont relatives.

On s'inspire du **rythme** et des **effets**. On ne copie ni ses images ni ses sons.

## Le déroulé, en 3 temps

| Temps | Durée | Image | Son |
| --- | --- | --- | --- |
| **1. Les coups** | environ 1 s, au rythme des coups | À chaque coup, un éclair blanc et des rayons sortent de l'œuf, et le dégât monte en rouge (« -250K »). La barre de PV est en haut. **L'œuf blanchit coup après coup**, de sa couleur vers le blanc. | Un impact bref et aigu à chaque coup, le centre du son vers 2,4 kHz. |
| **2. La chance** | 4 s | L'œuf est une **silhouette blanche unie**, sans ombre. Il **grossit petit à petit** et palpite. Au-dessus, un texte vert avec un trèfle, « ×9.68K Chance », **monte toutes les 0,1 s, d'environ 3 % à chaque fois** (× 1,32 par seconde : la montée accélère). C'est la chance de rareté de l'**objet dedans**, pas la rareté de l'œuf. | Un **tic rapide** (14 à 20 par seconde) dont la **note monte d'une octave** en 4 s (de 375 à 700 Hz environ). C'est lui qui fait monter la tension. |
| **3. La révélation** | environ 1 s | L'œuf reprend ses vraies couleurs une image, puis **éclate** : de longs traits blancs partent du centre, des étoiles à 4 branches de couleur (cyan, jaune, rose) l'entourent, et **un faisceau de lumière tombe d'en haut**. Pour un Mythique, **tout l'écran se teinte** (orange, puis arc-en-ciel). **L'objet apparaît d'abord tout blanc, puis prend ses couleurs** en 0,1 à 0,2 s. Au-dessus : le temps, le $/s et la rareté (texte arc-en-ciel pour un Mythique). | Un **carillon clair** de 0,7 s environ, vers 1 à 2 kHz, plus fort que les tics. |

Ensuite, l'objet fuit (« Poursuivez-moi! »). Le joueur le porte avec le bandeau « COURIR ! », les bords rouges et un bouton « Lâcher » en bas. On a déjà les équivalents (`RunBanner`, `ScreenEdges`).

## Ce qu'on reprend pour l'ouverture du colis (L-112)

1. **Pendant l'ouverture**, le colis gigote, et **sa couleur part vers le blanc** à chaque secousse ou à chaque coup.
2. **Pendant la chance**, le colis devient blanc uni, par exemple avec un `Highlight` blanc plein. Il grossit de 1 à 1,3 environ et palpite à chaque tic.
   - Au-dessus, un texte vert avec un trèfle : « ×N LUCK ». Il monte à chaque tic, et de plus en plus vite.
   - Le tic sonne au même moment, avec une note qui monte (`PlaybackSpeed` de 1 à 2 en 4 s, soit une octave), environ 10 à 15 fois par seconde.
3. **À la révélation** :
   - une image aux vraies couleurs, puis l'éclatement : traits blancs, étoiles de couleur, faisceau d'en haut à la couleur de la rareté ;
   - à partir d'Épique, l'écran se teinte à la couleur de la rareté, plus fort pour Mythique, Secret et Divine ;
   - l'objet sort blanc, puis prend ses couleurs, avec un pop de 0 à 1,15 puis à 1 ;
   - un carillon, plus long et plus riche pour les grandes raretés.
4. **Ce qui change par rapport à notre aperçu actuel** : on affiche un **multiplicateur de chance qui monte** (« ×N »), au lieu d'une rareté avec son pourcentage. Le colis **blanchit et grossit** au lieu de garder ses couleurs.

Les valeurs (durées, multiplicateur de départ et d'arrivée) viendront du code d'Ironix. Celles-ci sont celles mesurées sur la vidéo.
