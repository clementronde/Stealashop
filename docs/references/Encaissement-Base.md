# Encaissement en base : étude d'une capture et version Steal a Shop

Demande de Cantin, le 23/11 : « pareil l'anim pour récupérer l'argent ».
Source : `C:\Users\user\Videos\NVIDIA\Desktop\Desktop 2026.11.23 - 16.48.53.03.mp4`. La capture dure 4,70 s, en 2560 × 1440 à 60 images/s, son AAC 48 kHz.
Images clés : `docs/references/Encaissement-Base/` (liste en fin de fiche).

Règle : on reprend les **techniques** (durées, courbes, ordre, rythme des sons). On ne reprend ni leurs dessins (billet, plaque), ni leurs textes, ni leurs sons. Chez nous, on garde les modèles de Clément (`FX_Collect_Bill`, `FX_Collect_Coin`, `CollectPad_xx`), notre vert et nos sons.

Méthode :
- les durées viennent d'un comptage d'images à 60 i/s (une image = 16,7 ms) ;
- les tailles et les couleurs viennent de mesures de pixels sur l'image ;
- les sons sont **déduits du spectre**, sans écoute (voir la section 7).

`t = 0` est la première image où quelque chose change (1,467 s dans la vidéo). L'image de 1,484 s est la copie exacte de celle de 1,467 s : il y a sans doute un petit à-coup au moment de l'encaissement, et les mesures de cette image peuvent être décalées d'une image.

---

## 0. En bref

Le joueur pose le pied sur la plaque verte de son présentoir. Pas de clic. Ensuite, pendant à peu près 1,1 s :

1. Sur la même image :
   - le chiffre d'argent du HUD change ;
   - une **vignette verte** envahit les bords de l'écran ;
   - la **plaque flashe en blanc** ;
   - un **« +montant » vert** surgit sur la plaque.
2. Les **billets** sortent un par un, à hauteur du joueur, et jaillissent. Ils flottent un instant, puis filent vers le compteur d'argent du HUD avec une traînée blanche.
3. Quand le premier billet arrive, le **groupe argent du HUD grossit** (× 1,16) et reste gros tant que les billets arrivent.
4. Le son suit les billets plutôt que le contact :
   - un souffle brillant ;
   - une petite montée ;
   - une cloche de caisse ;
   - des tics de plus en plus aigus pendant les arrivées.

Ce qui manque chez nous, d'après le code :
- nous avons déjà les billets ;
- il nous manque la vignette et le flash de la plaque ;
- il manque aussi la **synchronisation du HUD et des sons sur l'arrivée des billets**. Aujourd'hui, tout part dès le contact.

---

## 1. Catalogue des moments

| Vidéo (s) | t (s) | Ce qui se passe |
| --- | --- | --- |
| 0,00 – 1,10 | | Le joueur est sur le tapis violet de sa base. La plaque du présentoir du milieu affiche son montant (texte blanc à contour foncé, écrit sur la plaque). |
| 1,10 – 1,45 | −0,35 | Il marche jusqu'à la plaque. |
| **1,467** | **0** | **Contact.** Le chiffre du HUD change d'un coup, sans défiler. Vignette, flash de la plaque et « +montant » commencent sur cette image. |
| 1,48 – 1,60 | +0,02 – 0,13 | Le montant de la plaque décompte jusqu'à 0. Le texte grossit et dépasse sa taille (+10 % vers +0,13). Premier billet à hauteur du torse à +0,03. La vignette atteint son maximum vers +0,13. |
| 1,50 – 1,90 | +0,03 – 0,43 | Un nouveau billet toutes les 33 à 50 ms, environ 6 à l'écran à la fois. Chacun jaillit, flotte, puis part vers le compteur en bas à gauche. |
| 1,70 | +0,23 | Premier son : souffle aigu et brillant. |
| 1,72 | +0,25 | Le texte est revenu à sa taille. |
| 1,75 – 2,20 | +0,28 – 0,73 | La vignette s'efface. La plaque est redevenue verte vers +0,38, et son montant remonte depuis 0. |
| 1,87 – 2,00 | +0,40 – 0,53 | Petite montée de son, puis cloche de caisse. |
| 2,09 – 2,37 | +0,63 – 0,90 | Les billets arrivent sur le compteur, environ un toutes les 50 ms. Le groupe argent grossit dès +0,65, avec un petit ressaut à chaque arrivée. Un son bref à chaque arrivée, puis des tics qui montent. |
| 2,40 – 2,60 | +0,93 – 1,13 | Le texte rétrécit jusqu'à disparaître. Le HUD revient à sa taille (+1,00 → +1,05). |
| 2,49 – 3,07 | +1,02 – 1,60 | Un autre système, distinct : un message propose un achat devenu possible, et il se construit en étapes. |
| 3,07 – 4,70 | | Fin. Aucun autre encaissement. |

Images : `01_vue_ensemble_2ips.jpg` (toute la vidéo), `02_avant_1450.jpg` (juste avant), `03_vignette_billets_1700.jpg` (pic de l'effet), `04_vol_vers_hud_2250.jpg` (billets vers le HUD).

---

## 2. Le déclenchement

**Chez eux.**
- Il suffit de marcher sur la plaque : aucun bouton à presser.
- Les invites « E » et « Q » du présentoir servent à autre chose.
- Tout ce qui se voit part sur la même image : chiffre, vignette, flash et texte. Les billets suivent à l'image d'après.

**Pourquoi ça marche.** La cause (le pied sur la plaque) et l'effet tombent sur la même image. Le joueur n'a aucun doute sur ce qui vient de se passer.

**Chez nous.** C'est déjà le même déclenchement : on marche sur `CollectPad_xx`.
1. `DisplayService` encaisse et envoie `CashCollect(plotIndex, slotIndex, amount)` à tous les clients.
2. Côté client, `DisplayController.onCashCollect` lance la gerbe de la plaque (`burst`).
3. Chez le propriétaire, il prévient ensuite `OnCollect`.

Il n'y a rien à changer côté serveur.

---

## 3. La vignette verte plein écran

**Chez eux** (`03_vignette_billets_1700.jpg`, `09_vignette_alpha.png`) :
- **Couleur** : vert vif, environ `#55D800`.
- **Plan** : la vignette passe **au-dessus du HUD** : elle teinte aussi le compteur et les boutons.
- **Forme** (opacité au maximum, estimée sur une carte bruitée) :
  - centre presque libre, entre 0 et 0,1 ;
  - milieu des côtés entre 0,3 et 0,4 ;
  - haut entre 0,25 et 0,35 ;
  - **coins du bas les plus forts**, entre 0,6 et 0,8.
- **Temps** :
  - montée en **0,14 s environ**, rapide au début : 36 % dès la 1re image, 71 % à +0,03, 90 % à +0,07, 100 % vers +0,13. La courbe colle à Cubic Out ;
  - **tenue** environ 0,15 s ;
  - **descente** en **0,45 s**, lente au départ puis presque droite, ce qui colle à Sine In ;
  - total environ 0,75 s.
- Pas de tremblement ni de zoom de caméra.

**Pourquoi ça marche.**
- L'écran entier « respire » la couleur de l'argent, sans bouger la caméra : le jeu reste lisible.
- Le centre reste libre et le poids est en bas, là où se trouve le compteur.
- La sortie lente évite une coupure sèche.

**Chez nous (proposition V0).**
- **Élément (Clément)** : `UI_HUD.CollectGlow`. C'est un nom proposé : l'annoncer dans la liaison et dans le tableau 2.2 avant de le créer. Il existe déjà un précédent de voile plein écran dans `UI_HUD`, `RevealTint`, que l'ouverture d'un colis utilise.
  - Type `ImageLabel` : `Size = UDim2.fromScale(1, 1)`, `BackgroundTransparency = 1`, `ScaleType = Stretch`, `Active = false` (les clics passent au travers).
  - `Visible = false` et `ImageTransparency = 1` au repos.
  - `ZIndex` au-dessus de tout le HUD.
  - **Pas de `UIAspectRatioConstraint` ici** : la vignette doit toucher les 4 coins sur tous les écrans.
- **Image (Clément)** : une vignette **blanche**, avec son alpha dans l'image elle-même. Le centre est transparent sur environ la moitié de l'écran. L'alpha vaut 0,3 à 0,4 au milieu des côtés, 0,25 à 0,35 en haut et 0,6 à 0,8 dans les coins du bas. La teinte vient de `ImageColor3`.
- **Couleur** : notre vert d'argent, `#5CFF4A` (`UiMotion.FloatGain.Colors.Cash`), ou un vert choisi par Clément.
- **Animation (code)** :
  1. `ImageTransparency` passe de 1 à 0 avec `TweenInfo.new(0.14, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)` ;
  2. tenue de 0,15 s ;
  3. retour de 0 à 1 avec `TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.In)`.
- **Deux ramassages de suite** : repartir de la valeur en cours (annuler le tween, en relancer un), sans empiler.
- **VISUAL EFFECTS sur OFF** (`Settings.VfxReduced`) : pas de vignette.

---

## 4. La plaque : flash blanc et montant qui se vide

**Chez eux** (`05_planche60_1434-1917.jpg`, `08_flash_plaque.png`) :
- **Flash blanc** de la plaque, qui part de son vert (≈ `#5DDE05`) :
  - 38 % de blanc dès la 1re image, 84 % à +0,03, **pic à 90 % vers +0,05** ;
  - puis descente presque droite : 9 % à +0,32, environ 0 vers +0,38. La montée prend donc 50 ms et la descente environ 300 ms.
  - Le texte de la plaque est délavé en même temps.
- **Le montant de la plaque se vide** en environ 0,12 s : il décompte de son total jusqu'à presque 0, avec de grosses marches au début. Il remonte ensuite en continu.
- La plaque ne s'enfonce pas de façon visible.

**Pourquoi ça marche.** Le flash désigne la source de l'argent. Le décompte montre que l'argent quitte la plaque : il ne disparaît pas, il part ailleurs.

**Chez nous** (aujourd'hui, dans `DisplayController.burst`) :
- gerbe des émetteurs de `Plate/BurstPoint` ;
- lumière `Glow` allumée 0,35 s **sans fondu** (allumée puis éteinte) ;
- plaque descendue de `SinkDepth` puis remise en place **d'un coup**, au bout de 0,15 s ;
- le montant (`AmountGui`) est caché dès que la plaque passe sous $1 (L-107).

**Ce qui manque ou change (V0).**
- **Enfoncement** : le faire comme dans la note de Clément (`docs/claude/notes/case-ramassage.md`) :
  - descente en `TweenInfo.new(0.06, Quad, Out)` ;
  - remontée en `TweenInfo.new(0.25, Back, Out)` ;
  - pendant ce temps, écrasement de la plaque à × 1,08 en XZ.

  Le code fait aujourd'hui une descente et une remontée sèches. C'est notre signature : on la garde, même si eux n'en ont pas.
- **Flash blanc** :
  - `Plate` est en néon vert : on fait passer sa `Color` au blanc en `TweenInfo.new(0.05, Quad, Out)`, puis on revient à sa couleur d'origine en `TweenInfo.new(0.3, Linear)`. Le néon blanc rayonne, sans rien ajouter.
  - Variante : un `Highlight` blanc (`FillTransparency` de 1 à 0,1 puis à 1). Attention à la limite de 31 Highlight que gère `ShelfBoxController.Reserve`.
- **`Glow`** : même courbe que le flash. Faire monter `Brightness` en 0,05 s puis la faire descendre en 0,3 s, au lieu de l'allumer et l'éteindre. Clément avait écrit 0,15 s ; chez eux le flash dure environ 0,35 s.
- **Montant qui se vide** (facultatif) : côté client, une copie locale de `AmountGui` qui décompte de `amount` (donné par `CashCollect`) jusqu'à 0. Elle utilise `TweenInfo.new(0.12, Quad, Out)` et `Format.money`, puis elle est détruite. L'`AmountGui` du serveur reste caché, comme aujourd'hui.

---

## 5. Le « +montant » sur la plaque

**Chez eux** (`06_texte_pop_1451-1634.jpg`, `07_texte_sortie.jpg`) :
- **Support** : un BillboardGui posé **sur la plaque**, à mi-hauteur du joueur. Il reste sur la plaque quand le joueur s'en va. Sa taille est en studs : il rapetisse quand la caméra s'éloigne.
- **Style** : vert plat (≈ `#64D46C`), police grasse arrondie, **sans contour ni ombre**.
- **Place et taille au repos** (caméra de la capture) : centre à 47 % de la largeur et 56 % de la hauteur. Largeur 12,9 % de l'écran. Hauteur ≈ 4,6 % de l'écran (estimée d'après la largeur).
- **Entrée**, en largeur mesurée : 0,53 → 0,71 → 0,85 → 0,93 → 0,99 → 1,04 → **1,09-1,10** (entre +0,12 et +0,15) → 1,09 → 1,06 → 1,04 → **1,00 à +0,25**.
  - Ce profil, c'est une montée rapide avec un dépassement de **+10 %**, puis un retour doux.
  - Un seul `Back Out` partant de 0,35 ne dépasse que de 6,5 %. **Deux tweens à la suite** collent mieux.
- **Tenue** jusqu'à environ +0,93.
- **Sortie en rétrécissant jusqu'à 0** en 0,2 s, sans fondu : 1 → 0,87 → 0,67 → 0,33 → 0, ce qui colle à Sine In. Le texte monte un peu pendant la sortie (≈ 40 px à l'écran).
- Durée de vie environ 1,13 s.

**Pourquoi ça marche.**
- Le texte naît là où l'argent était : l'œil va de la plaque aux billets, puis au HUD.
- Le dépassement de 10 % donne le « pop ».
- La sortie en rétrécissant est nette. Pas de texte à moitié transparent qui traîne.

**Chez nous** (aujourd'hui) :
- `GainController.showGain` → `floatGain` : copie de `BB_Gain` **au-dessus du joueur**, choix de Clément en L-091 ;
- `Row` passe de 0,4 à 1 en 0,16 s (Back Out) ;
- le texte monte de 2,2 studs en 1 s (Quad Out) et s'efface à partir de 55 % ;
- un texte par seconde au plus (`CashMinGap`).

**Proposition V0** (même `BB_Gain`, même place, seule l'animation change) :
1. `UIScale` de `Row` : de 0,45 à 1,10 avec `TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)`.
2. Puis de 1,10 à 1 avec `TweenInfo.new(0.11, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)`.
3. Tenue de 0,7 s, sans montée ni fondu.
4. Sortie : `UIScale` de 1 à 0 avec `TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.In)`. Pendant ce temps, `StudsOffset` monte de 0,4 stud.
5. Le texte meurt au bout d'environ 1,15 s. Avec `CashMinGap = 1`, le texte suivant peut naître pendant que l'ancien rétrécit : celui-ci est déjà petit, on ne lit pas deux textes à la fois.

---

## 6. Les billets

**Chez eux** (`03`, `04`, `05`) :
- **Dessin** : un billet stylisé vert clair à épais contour noir. Il reste **à plat face à la caméra** et tourne seulement dans le plan de l'écran.
- **Traînée** : une traînée **blanche effilée** derrière chaque billet (durée de vie estimée entre 0,2 et 0,25 s).
- **Sortie** : le premier billet apparaît à +0,03, à hauteur du torse du joueur. On ne voit pas s'il part du joueur ou de la plaque sous lui. Ensuite, **un nouveau billet toutes les 33 à 50 ms**, jusque vers +0,43 : les billets sortent en fontaine, pas tous ensemble.
- **Nombre** : environ 6 à l'écran à la fois, une dizaine en tout (estimation : 10 à 12).
- **Trajet de chaque billet** :
  1. il jaillit vers le haut et l'extérieur, jusqu'à la hauteur des objets voisins, en 0,10 à 0,15 s (ease-out) ;
  2. il **flotte en dérivant**, sans s'arrêter, pendant 0,2 à 0,3 s ;
  3. il **file vers le compteur** d'argent en bas à gauche, en 0,3 à 0,4 s (ease-in), **en rapetissant**.
- **Arrivée** : les billets disparaissent juste au-dessus et à droite du compteur, entre 12 et 18 % de la largeur et entre 75 et 82 % de la hauteur. Ils arrivent à +0,63, +0,68, +0,73, +0,78, +0,84 et +0,89 : **un toutes les 50 ms environ, régulièrement**.

**Pourquoi ça marche.**
- La fontaine donne un flux continu pendant près de 0,9 s : départs puis arrivées, environ 20 événements par seconde.
- Les arrivées régulières font un rythme que le HUD et le son reprennent.
- L'argent fait un vrai trajet, de la plaque au compte du joueur.

**Chez nous.** C'est déjà là : `VfxController.Collect` avec les valeurs de Clément (`Config/Vfx.Collect`) :
- 5 à 12 billets et pièces selon le montant ;
- jaillissement de 0,2 s, de 2 à 3,5 studs ;
- vol de 0,4 à 0,5 s en Quad In vers un point situé 3 studs devant la caméra, sous `UI_HUD.Cash` ;
- rapetissent à 0,25, tournent en 3D à 720°/s ;
- les modèles ont leurs `Trail`.

Trois écarts avec la référence :

| | Chez eux | Chez nous aujourd'hui | Proposition V0 |
| --- | --- | --- | --- |
| Sortie | un billet toutes les 33-50 ms (fontaine) | tous jaillissent ensemble ; seul le départ vers le HUD est décalé de 0,04 s | décaler le **jaillissement** : le billet `i` sort à `(i − 1) × Stagger`, avec le `Stagger` de Clément (0,04 s) |
| Attente | flottent en dérivant (0,2-0,3 s) | immobiles au point haut (seule la rotation bouge), de 0 à 0,44 s selon leur rang | attente fixe de 0,2 s, avec une petite dérive de 0,3 à 0,5 stud vers le haut et l'extérieur (Sine Out) |
| Vol | 0,3-0,4 s, arrivées régulières | 0,4 à 0,5 s au hasard : les arrivées peuvent se croiser | vol presque fixe, 0,35 s Quad In (au hasard ± 0,02 s au plus) : les billets arrivent dans l'ordre, un toutes les 40 ms |

Avec un jaillissement de 0,12 à 0,15 s, une attente de 0,2 s et un vol de 0,35 s :
- le premier billet arrive vers 0,7 s, comme chez eux (0,63 s) ;
- avec 12 billets, le dernier arrive vers 1,15 s.

Autres points :
- **Traînée** (propriétés des `Trail` des modèles de Clément, estimées) :
  - `Lifetime` entre 0,2 et 0,25 ;
  - `WidthScale` de 1 à 0 (effilée) ;
  - `Transparency` de 0,2 à 1 ;
  - couleur blanche, `LightEmission` vers 0,5.
- **Téléphone** : chez eux, l'image de +0,017 est répétée, ce qui ressemble à un à-coup quand tout est créé d'un coup. Sortir les billets en fontaine (un clone toutes les 0,04 s) ou les préparer d'avance évite cet à-coup.

---

## 7. Les sons (déduits du spectre, à écouter)

Je n'entends rien : tout ce qui suit est lu sur le spectre (`11_spectre_1350-2150.jpg`, `12_spectre_2150-2950.jpg`) et sur les niveaux par bandes, par tranches de 10 ms. Il faut donc écouter pour confirmer.

**À écouter : de 1,40 à 2,70 s de la vidéo**, si possible au quart de la vitesse (VLC, lecture 0,25×). Les passages clés :
- 1,70 s : le souffle ;
- 1,87 à 2,00 s : la montée, puis la cloche ;
- 2,10 à 2,50 s : les tics.

**Chez eux** :

| Vidéo (s) | t (s) | Son | Ce qu'il accompagne |
| --- | --- | --- | --- |
| tout le long | | musique de fond, environ 150 battements par minute (un temps toutes les 0,40 s) | |
| 1,467 | 0 | **rien de net** (ou trop faible pour sortir de la musique) | le contact |
| 1,70 → 2,25 | +0,23 → +0,78 | **souffle aigu et brillant** (au-dessus de 5 kHz), monté en 0,1 s, avec des scintillements | les billets qui partent vers le HUD |
| 1,87 → 1,99 | +0,40 → +0,52 | **petite montée** (environ 450 Hz → 1,1 kHz) | l'attente avant la première arrivée |
| 1,98 → 2,00 | +0,52 | **cloche de caisse** : attaque sèche puis cloche métallique claire, qui résonne environ 0,5 s | environ 0,1 s avant la première arrivée |
| 2,06 → 2,27 | +0,60 → +0,80 | son rond qui glisse vers le grave (vers 550 Hz, puis 400 Hz) | les premières arrivées |
| 2,11 ; 2,17 ; 2,22 ; 2,31 ; 2,37 ; 2,45 | +0,64 → +0,98 | **aigus très brefs** | une arrivée de billet chacun (le 2,11 tombe avec le pop du HUD) |
| 2,28 → 2,48 | +0,81 → +1,01 | **5 à 6 tics brefs, de plus en plus aigus** (environ +3 demi-tons en tout), espacés de 40 à 60 ms | les dernières arrivées, comme un compteur qui tourne |
| 2,64 → 2,69 | +1,17 | petit son médium | le message d'achat |

**Écart entre l'image et le son.** Le premier son arrive 0,23 s après le contact. Il y a deux lectures possibles :
- **c'est voulu** : le son suit les billets (départ, cloche juste avant la première arrivée, un son par arrivée), et le son bref de 2,11 tombe pile sur le pop du HUD à 2,117 ;
- c'est un décalage de la capture.

La première lecture est la plus probable, mais ce n'est pas sûr.

**Pourquoi ça marche.**
- Chaque couche du son correspond à une étape visuelle.
- Les tics qui montent créent l'attente puis la récompense : on entend l'argent « se compter ».
- La cloche de caisse dit « argent » sans mot.

**Chez nous** (aujourd'hui) : un seul `Cash_Collect`, joué au contact (`GainController.classify`, L-117 point 4). La note de Clément demandait un son de caisse ou de pièces à l'enfoncement (DEV-051).

**Proposition V0** :
- Les sons vont dans `ReplicatedStorage/Assets/Sounds/Cash/`.
- Ce sont des descriptions à chercher dans la bibliothèque. Aucun ID n'est donné ici.
- Les noms marqués « proposé » sont à valider.

| Quand | Son | Description à chercher |
| --- | --- | --- |
| contact (t = 0) | `Cash_Pad` (proposé) | confirme le contact (le son d'enfoncement de la note de Clément, DEV-051), court (moins de 0,2 s) : petit froissement de billets ou pop sourd. Pas le gros son |
| départ des billets (t ≈ 0,05) | `Cash_Whoosh` (proposé) | souffle aigu et brillant de papier qui s'envole, avec des scintillements, environ 0,5 s, qui monte en 0,1 s |
| première arrivée (t ≈ 0,7) | `Cash_Collect` (existant) | c'est déjà son rôle ailleurs : « une fois à l'arrivée » dans `UiMotion.CashFly` et `HeistFeel.BillFly`. Si le son actuel n'en est pas une, chercher une cloche de caisse claire, attaque sèche, environ 0,5 s de résonance ; on peut la faire précéder d'une petite montée de 0,1 s |
| chaque arrivée | `Cash_Tick` (proposé) | tic très court (≈ 40 ms), clair, pièce ou clic métallique. `PlaybackSpeed` = `1 + 0,035 × (n − 1)`, soit environ +½ demi-ton par billet, plafonné à une octave |

Côté code, deux points pour Ironix :
- `Motion.PlaySound(name)` ne règle pas la hauteur. Il faut jouer une copie avec `PlaybackSpeed`, comme `ShelfOpenController` (ligne 251) ou `ShatterController` (ligne 991).
- Il y a déjà des précédents de tics qui montent : `ShelfOpen/Logic.luau` (ligne 119, une octave sur la montée) et `Config/Unbox` (`RattlePitchStep = 0.04`).

---

## 8. Le HUD : grossir sur l'arrivée des billets

**Chez eux** (`10_pop_hud.jpg`) :
- **Le chiffre** saute dès le contact (t = 0), sans défiler. À ce moment, l'œil regarde la plaque : on ne voit pas ce saut.
- **Le pop** commence à la **première arrivée de billet** (+0,65) et ne touche que le groupe argent (ligne de l'argent et ligne du bonus en dessous) :
  - 1,00 → 1,08 à +0,65 → **1,16 à +0,68**, soit 50 ms ;
  - puis il **reste gros** tant que les billets arrivent, avec un ressaut d'environ 1 % à chaque arrivée ;
  - il **revient à 1** en 50 ms (+1,00 → +1,05), un peu après la dernière arrivée ;
  - les autres boutons ne bougent pas.
- **Place** : compteur en bas à gauche, de 4 à 13 % de la largeur, centre vers 85 % de la hauteur. Le texte fait environ 4 % de la hauteur de l'écran.

**Pourquoi ça marche.** Le HUD réagit au moment où l'argent « touche » le compteur. Le pop et le son tombent sur la même image : l'œil, l'oreille et le chiffre disent la même chose au même instant.

**Chez nous** (aujourd'hui, branche « ramassage » de `GainController.classify`) :
- au **contact**, le chiffre défile tout de suite (`Motion.Roll`, 0,6 s en Cubic Out) ;
- `CashRow` sursaute aussitôt (1,15 → 1 en 0,3 s, Back Out) ;
- `Cash_Collect` part au même moment.

Les billets arrivent donc 0,6 à 1,1 s **après** le sursaut. Le HUD a fini de réagir quand ils arrivent. La note de Clément demandait pourtant : « À chaque arrivée, faire pulser `Cash` (échelle 1,15, puis retour) et monter le chiffre ».

**Proposition V0** (comme la note de Clément et comme `billFly`, qui le fait déjà pour les récompenses) :
1. **Au contact** : retenir le chiffre (`HudController.HoldCash`).
2. **Première arrivée** :
   - relâcher le chiffre, qui défile (`Motion.Roll`) ;
   - `CashRow` grossit avec un `UIScale` de 1 à 1,16 en `TweenInfo.new(0.05, Quad, Out)` ;
   - jouer `Cash_Collect`.
3. **Chaque arrivée suivante** :
   - ressaut de 1,16 à 1,19 en `TweenInfo.new(0.03, Quad, Out)`, puis retour à 1,16 en `TweenInfo.new(0.06, Quad, Out)` ;
   - `Cash_Tick`, à une hauteur qui monte à chaque billet.
4. **0,1 s après la dernière arrivée** : retour à 1 en `TweenInfo.new(0.06, Quad, Out)`, comme chez eux. On peut aussi garder notre `CashBump` (0,3 s, Back Out) pour rester cohérent avec le reste du jeu.
5. **Sans billets** (VISUAL EFFECTS sur OFF, ou compteur absent de l'écran) : faire comme aujourd'hui, c'est-à-dire tout relâcher tout de suite, avec sursaut et son.

---

## 9. Le message d'achat qui suit (autre système)

**Chez eux** (pas d'image gardée) :
- environ 1 s après l'encaissement, un message propose un achat devenu possible ;
- il se construit **par étapes décalées** :
  1. une pastille (+1,02) ;
  2. elle s'élargit (+1,16 → +1,36) ;
  3. l'icône (+1,36) ;
  4. le titre (+1,40) ;
  5. la 2e ligne (+1,43) ;
  6. le bouton « voir » saute (+1,50 → +1,56) ;
  7. puis le bouton OK (+1,56 → +1,60).
- Il y a 30 à 70 ms entre deux éléments.

**Pourquoi ça marche.**
- L'encaissement débouche tout de suite sur la dépense suivante, ce qui fait tourner la boucle.
- Les étapes décalées guident la lecture.

**Chez nous.** C'est un choix de jeu (voir les questions). La technique, elle, peut servir à notre `UI_Toast` : faire entrer l'icône, le titre puis le bouton à environ 40 ms d'écart, au lieu de faire entrer le message d'un bloc (0,6 → 1 en 0,2 s).

---

## 10. Le rythme

| De t (s) | à t (s) | Retours au joueur |
| --- | --- | --- |
| 0 | 0,15 | 5 en même temps : chiffre, vignette, flash, texte, montant de la plaque qui se vide |
| 0,03 | 0,45 | un billet de plus toutes les 33-50 ms (20 à 30 par seconde), chacun avec sa traînée |
| 0,23 | 0,55 | souffle, montée, cloche |
| 0,63 | 1,0 | une arrivée toutes les 50 ms : ressaut du HUD et son bref (environ 20 par seconde), puis tics qui montent |
| 0,93 | 1,13 | le texte s'en va ; le HUD revient |

Environ **1 s de retours sans trou**, à une vingtaine par seconde, puis le calme. Tout est fini en 1,15 s, donc on peut ramasser plusieurs plaques à la suite sans que les effets s'empilent.

---

## 11. Ce qui fait « pro » chez eux, et ce qui fait « générique » chez nous

**Pro chez eux.**
- Un seul instant de départ pour tout, puis une chaîne cause → effet : la plaque, puis les billets, puis le HUD.
- Une courbe par rôle : montée rapide (Cubic ou Quad Out) pour ce qui arrive, Sine In pour ce qui part, dépassement de 10 % pour le texte. Rien ne dure plus de 1,15 s.
- Le HUD et le son sont calés sur l'arrivée des billets, pas sur le contact.
- La vignette a une forme (centre libre, poids en bas) : ce n'est pas un aplat de couleur.
- Le texte sort en rétrécissant, pas en s'effaçant.
- Le son est fait de couches, avec une hauteur qui monte.

**Générique chez nous**, comparé au code. Les captures de notre jeu (`2026-11-15_Revue_UI`) ne sont pas sur cette machine, je n'ai donc pas pu comparer à l'image.
- Tout part au contact : sursaut, défilement et son. Les billets arrivent ensuite **sans réponse du HUD**.
- `Glow` s'allume puis s'éteint d'un coup, et la plaque descend puis remonte sans tween : c'est mécanique.
- Les billets **attendent immobiles** en l'air, en file, avant de partir. Chez eux, ils sont toujours en mouvement.
- Un seul son pour tout l'encaissement.
- Rien à l'échelle de l'écran pour un gros ramassage.
- Le texte s'efface en montant : c'est la sortie par défaut qu'on voit partout.

---

## 12. Où brancher dans le code (lu sans rien modifier)

| Étape | Fichier (lignes) | Aujourd'hui | À faire (Ironix) |
| --- | --- | --- | --- |
| Encaissement (serveur) | `src/server/Services/DisplayService.luau` : `collectPad` (≈ 1776), `CashCollect:FireAll` (≈ 1584), `showPads` (1477) | encaisse, envoie `CashCollect`, cache `AmountGui` à $0 | rien |
| Plaque (tous les clients) | `src/client/Controllers/DisplayController.luau` : `burst` (271-320), `GLOW_TIME` et `SINK_TIME` (98-99), `onCashCollect` (322-339) | gerbe, `Glow` 0,35 s, enfoncement sec | flash blanc, `Glow` en fondu, enfoncement de la note de Clément, montant qui se vide (facultatif) |
| Billets (propriétaire) | `src/client/Controllers/VfxController.luau` : `Collect` (334-373), `stepFlyer` (380-416), `cashTarget` (309-332), branchement `OnCollect` (824-826) ; valeurs `src/shared/Config/Vfx.luau` `Collect` (42-62) | jaillissent ensemble, attendent, volent 0,4-0,5 s | fontaine, dérive, vol presque fixe ; **signaler chaque arrivée** (rang du billet et total), pour le HUD et les sons |
| HUD, texte, son | `src/client/Controllers/GainController.luau` : `classify` (1059-1106), branche ramassage sans case (1082-1093), `floatGain` (482-558), `bump` (610-614), `billFly` (810-888, modèle « retenir puis relâcher à l'arrivée ») ; `HudController.HoldCash` (416) | tout au contact | retenir au contact, relâcher à la 1re arrivée, ressaut et tic à chaque arrivée, nouvelle entrée et sortie du texte, vignette |
| Valeurs | `src/shared/Config/UiMotion.luau` : `FloatGain` (238-274), `CashBump` (293-298), `Roll` (134-138) | | ajouter les valeurs V0 de cette fiche (vignette, flash, pop d'arrivée, tics) |
| Sons | `src/client/Controllers/UI/Motion.luau` : `PlaySound` (1021) | nom seul | jouer une copie avec `PlaybackSpeed` pour les tics |

Deux points d'attention pour Ironix :
- **Arrivées des événements.** Le remote `CashCollect` (billets) et les attributs `Cash` / `CashCollected` (HUD) arrivent à peu près dans la même image, mais par deux chemins différents. Le lien entre « billet arrivé » et « relâcher le chiffre » doit tenir si l'un arrive avant l'autre, ou s'il n'y a pas de billet du tout.
- **Nouvel élément d'UI.** `UI_HUD.CollectGlow` est à annoncer dans la liaison et dans le tableau 2.2 avant que Clément le crée.

---

## 13. Questions à Clément (passent d'abord par Cantin)

1. **Le chiffre d'argent du HUD** : défile-t-il dès le contact (comme aujourd'hui), ou seulement quand les billets arrivent (comme ta note `case-ramassage.md` et les récompenses) ? *V0 : à l'arrivée des billets.*
2. **Le « +montant »** : on le garde au-dessus du joueur (ton choix L-091), ou on le pose sur la plaque, où il reste quand tu repars ? *V0 : au-dessus du joueur, avec la nouvelle entrée et la sortie en rétrécissant.*
3. **La vignette verte plein écran** :
   - la veux-tu à chaque ramassage ?
   - passe-t-elle au-dessus du HUD (elle le teinte) ou en dessous ?

   *V0 : à chaque ramassage, au-dessus du HUD, coupée par VISUAL EFFECTS sur OFF. Tu dessines l'image (vignette blanche, coins du bas plus forts).*
4. **Les billets** : à plat face à la caméra (le dessin est toujours lisible, comme chez eux), ou en 3D qui tournoie (comme maintenant) ? *V0 : garder la 3D, avec une traînée blanche effilée.*
5. **Le son** :
   - un petit son au contact, puis le gros son (cloche de caisse) à la première arrivée et des tics qui montent ;
   - ou le gros son au contact, comme aujourd'hui ?

   *V0 : la première solution. Les sons sont à choisir, et tu peux écouter la vidéo de 1,40 à 2,70 s.*
6. **Après un gros ramassage**, un message « tu peux maintenant acheter … » ? *V0 : pas pour le MVP, à noter dans les idées.*

---

## 14. Images clés (`docs/references/Encaissement-Base/`)

| Fichier | Contenu |
| --- | --- |
| `01_vue_ensemble_2ips.jpg` | toute la vidéo, 2 images/s |
| `02_avant_1450.jpg` | juste avant le contact (1,450) |
| `03_vignette_billets_1700.jpg` | pic : vignette, billets, texte (1,700) |
| `04_vol_vers_hud_2250.jpg` | billets et traînées vers le compteur, HUD grossi (2,250) |
| `05_planche60_1434-1917.jpg` | planche à 60 i/s, de 1,434 à 1,917 : flash de la plaque, décompte, texte, sortie des billets |
| `06_texte_pop_1451-1634.jpg` | entrée du texte et premiers billets, zoomés |
| `07_texte_sortie.jpg` | sortie du texte en rétrécissant, de 2,30 à 3,25, toutes les 50 ms |
| `08_flash_plaque.png` | plaque avant et pendant le flash blanc |
| `09_vignette_alpha.png` | carte d'opacité de la vignette (bruitée par le décor) |
| `10_pop_hud.jpg` | pop du groupe argent, de 2,034 à 2,217 |
| `11_spectre_1350-2150.jpg` | spectre de 1,35 à 2,15 s : souffle, montée, cloche |
| `12_spectre_2150-2950.jpg` | spectre de 2,15 à 2,95 s : arrivées, tics qui montent |
