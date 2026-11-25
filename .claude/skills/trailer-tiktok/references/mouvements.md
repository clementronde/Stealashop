# Catalogue des mouvements de caméra

Mesuré sur les TikTok de référence de Clément (fiche de l'analyste vidéo : `StealAShop-Art/Trailers/references/2026-11-24_mouvements-camera.md`, et les fiches de forme `docs/claude/video/references/`). On reprend la technique, jamais les images.

## Le champ en 9:16 (à lire d'abord)

La caméra est tournée de 90° (`roll`) : la hauteur du viewport de Studio devient la largeur de l'image verticale. Donc **`fov` dans nos plans = angle horizontal de l'image 9:16 finale**, et l'angle vertical est bien plus grand :

| `fov` (horizontal) | Vertical | Usage |
| --- | --- | --- |
| 40 | 67° | serré, objet ou visage |
| 45 | 74° | **le standard** (comme un TikTok vertical natif au champ par défaut de Roblox) |
| 50 | 80° | grand angle au ras du sol : les objets paraissent énormes |
| 55 et plus | 85° et plus | à éviter : les bords se déforment |

Le recadrage 9:16 enlève le haut de l'image (`coupe=haut`, à cause du cube de vue de Studio) : la cible visée apparaît un peu au-dessus du centre (environ 8 % de la hauteur).

**Zone sûre** : le sujet entre 15 % et 80 % de la hauteur. TikTok couvre le haut (onglets) et le bas (texte, boutons).

## Les règles mesurées

- **La caméra ne s'arrête jamais** : le plus lent avance encore de 1,5 % de sa distance au sujet par seconde.
- **Vitesse constante** dans 22 plans sur 29 : on coupe au milieu d'un long mouvement, sans montrer ni le départ ni l'arrêt. Donc `ease = "linear"` pour les plans qu'on coupera court ; `sine` ou `outCubic` seulement quand on garde l'arrivée.
- **Durées sur une grille** de 1/3, 1/2, 2/3 et 1 s au montage (0,8 s en moyenne, 0,57 s au plus serré). On tourne toujours 3 à 4 s pour choisir.
- **Ras du sol** (2 à 5 studs) pour presque tout ; haut (40 à 100 studs) seulement pour les plans larges.
- **Un sujet par plan, centré** en largeur, sa base dans le tiers bas.
- **Avancer de k %** veut dire : la caméra parcourt k % de sa distance au sujet par seconde (indépendant du champ). Un latéral, lui, paraît 3,2 fois plus rapide en 9:16 qu'en 16:9 à la même vitesse en studs : rester sous 0,25 × la distance au sujet par seconde.

## Le catalogue

`T.moves` dans `tools/clement/trailer/trailer_lib.luau`. Durées = durée du plan au montage (on tourne plus long).

| Mouvement | Durée | Courbe | Distance ou angle | Hauteur | `fov` | Sujet en 9:16 | Code |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **Travelling avant lent** | 0,7-1 s | `linear` | 2 à 15 % de la distance au sujet par seconde | 3-5 | 45 | centré, base au tiers bas | `travelling{dir="avant"}` |
| **Travelling avant rapide** (poussée) | 0,5-1 s | `linear`, ou `outQuad` pour freiner sur le dernier tiers | 30 à 40 % de la distance par seconde | 2-4, légère contre-plongée | 45-50 | centré | `travelling{dir="avant"}` |
| **Travelling arrière** (fin qui boucle, ou recul devant un coureur) | 2-2,5 s | `linear`, ou `sine` | 10 à 40 % de la distance, en montant un peu | finit sur l'image de l'accroche | 45 | même cadre que l'accroche | `travelling{dir="arriere"}` ou `follow{offset→offsetTo}` |
| **Travelling haut** (montée qui révèle) | 0,7-1 s | `inQuad`, coupé en pleine vitesse | de 3 à 20-30 studs ; la cible reste au loin, l'axe bascule vers le bas | 3 → 25 | 45 | décor au centre | `travelling{dir="haut", keepLook=true}` ou `path` |
| **Travelling bas** (descente sur le héros) | 2-2,5 s | `inQuad` ou `inCubic` | environ 55 % de la distance au sujet ; finir à travers un effet pour masquer la coupe | 40 → 8 | 45 | sujet au centre, haut vide au départ | `path` |
| **Travelling gauche** (défilé) | 0,7-1 s | `linear` | 0,18 × la distance au sujet par seconde | 3-5, plongée 10-15° | 45 | les sujets entrent par un bord et sortent par l'autre | `travelling{dir="gauche"}` |
| **Travelling droite** (passage) | 0,8-1,2 s | `sine` (vitesse en cloche) | 0,25 × la distance par seconde en moyenne (pic 0,38) | 3-5 | 45 | du tiers droit au tiers gauche | `travelling{dir="droite"}` |
| **Orbite** | 0,7-1,5 s | `sine` (`inQuad` si on coupe en vitesse) | 10-20° par plan court, 30-70° par plan long ; rayon 8-12 studs | 4-5, ou 2-3 en contre-plongée | 45-50 | sujet entier, centré | `orbit{from, to}` |
| **Panoramique** | 0,7-1,5 s | `sine` | 20°/s au plus | — | 45 | — | `pan` ; jamais seul : ajouter un léger déplacement |
| **Révélation** | 0,7-1,5 s | `outQuint` (coup de frein net) | passer derrière un mur, sous un toit ou au ras d'un objet, puis découvrir | variable | 45 | le sujet arrive au centre au moment du frein | `reveal{from, to, look}` |
| **Plan large** (accroche, drone) | 2,5-3 s | `linear` | dérive de 8 % de la distance sur tout le plan | 60-100, plongée 45° | 45-50 | couloir ou hub dans l'axe vertical | `wide` ou `path` |
| **Suivi d'un joueur** | 1-3 s | lissage `lag` 0,1-0,2 s | à 8-14 studs, de 3/4 arrière ou de face ; la caméra gagne lentement (+7 %/s) | 1-5 | 45-50 | joueur au tiers bas | `follow{actor, offset, offsetTo}` |

Ajouts :
- **Caméra à l'épaule** (plans « naturels », demande de Clément du 2026-11-25) : `M.handheld(move, { amp = 0.12, look = 0.24, freq = 0.55, seed = n })` ajoute un bruit doux (deux octaves de `math.noise`) à la position et à la visée de n'importe quel mouvement. 0,06-0,08 pour un plan posé (boutique, zoom lent), 0,1-0,15 pour l'action. Un `seed` différent par plan, sinon tous les plans tremblent pareil.
- **Cadreur** : `M.operator({ keys = { {t, pos}, … }, targets = { "p", "g" }, lookOffset, lag = 0.25-0.45, fov })`. La caméra suit son chemin et vise la moyenne des acteurs cités, avec du retard, comme quelqu'un qui panote pour garder l'action au centre. C'est le mouvement des plans naturels : on n'écrit plus la cible, on dit qui regarder. `lag` court (0,15) pour un corps qui vole, long (0,4) pour un groupe.
- **Zoom** : `M.zoom(move, { to = 34, at = 0 | atKey = "breakAt", dur, ease })` resserre ou ouvre le champ d'un mouvement. Zoom lent de 50 à 34 sur 4 s avec un petit travelling avant : approche « documentaire » d'une vitrine ; zoom de 56 à 38 en 0,7 s `outQuad` juste avant l'impact : coup de poing.
- **Secousse** à l'impact (vitrine, plaquage, explosion) : `M.shake(move, { atKey = "breakAt", dur = 0.3, amp = 0.25 })`.
- **Enchaîner** deux mouvements dans une même prise (arrivée en arc, comme les « stations » de la ref7) : `M.chain({ {1.2, moveA}, {0.6, moveB} })`. Une station toutes les 1,7 s : trajet de 1,2 s, arrêt de 0,5 s pendant lequel la caméra avance encore de 20 à 40 %/s, l'effet déclenché à l'arrivée (± 0,2 s).

## Rythme d'un trailer de 15 à 25 s

Deux manières (mesurées) :
1. **Montage nerveux** (ref1) : accroche large de 2,5 s, 18 à 20 plans de 0,33 à 1 s (0,57 s au plus serré), fin en recul de 2,5 s qui retombe sur l'accroche. Coupes sèches sur le temps de la musique (environ 120 battements par minute : un plan = 1 ou 2 temps).
2. **Plan continu à stations** (ref7) : une caméra qui va de sujet en sujet, une station toutes les 1,7 s, environ 10 stations pour 20 s.

**Couper court** : chaque prise de 3 à 4 s ne donne au montage que 10 à 30 images (0,33 à 1 s) autour de son meilleur moment (l'impact, le passage au plus près, la révélation). Un trailer de 20 s demande donc 15 à 20 sujets différents : prévoir la liste des plans en conséquence (comparaison du chef vidéo, `StealAShop-Art/Trailers/references/2026-11-24_comparaison-teaser-soon.md`).

**Le mot en masque** (validé par la DA le 2026-11-24) : un mot fixe et énorme au centre, dont les lettres montrent l'image inversée (ffmpeg `negate` + `alphamerge`), sert de fil entre les plans. On reprend la technique, **jamais le mot « SOON » ni sa mise en page** : notre mot et notre police (par exemple le nom du jeu ou « COMING SOON » dans notre style).

**Notre image reste claire et saturée** (DA, `StealAShop-Art/References/Style/Ciel_Couleurs`) : contraste et vignette seulement légers (`montage_plan.sh … grade=2`), jamais un jeu assombri.

Ordre type : accroche (le plus fort, ou le plan large) → les lieux par groupes (zones 1 à 6, puis vitrine, colis, vigile, boutique pleine) → sommet (les plans les plus courts et les plus rapides) → fin qui boucle.

Joueurs à l'image : un tiers à la moitié des plans pour un trailer de braquage (casse, colis, poursuite) ; presque aucun pour un teaser « SOON » sur les lieux.

À éviter : la caméra par défaut de Roblox (elle saute quand un mur passe et traverse les billboards) ; un panoramique pur sans déplacement ; un plan fixe (sauf l'image tenue de fin).
