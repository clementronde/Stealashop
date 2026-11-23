# Référence 3 : la montée jusqu'à la rareté max

Source : vidéo TikTok d'un jeu Roblox de lancer et de chance, envoyée par Clément (WhatsApp, 20/11). Étudiée pour sa forme, jamais réutilisée.

**Ce que Clément aime** : montrer la rareté max avec une bonne musique ; « les gens adorent la rareté max ».

## Mesures

- **Durée** : 38,5 s, dont **35,5 s de contenu** puis la fin TikTok automatique. Vertical 9:16 (576 × 1024).
- **Aucune voix** : la musique et les chiffres font tout.
- **Le rythme suit une montée** : plans longs au début, coupes de plus en plus serrées (0,3 à 0,6 s entre 11 et 20 s), puis **6 s presque noires** avant l'explosion finale.

## Structure : une escalade, un silence, une explosion

| Temps | Durée | Ce qu'on voit | Le chiffre à l'écran |
| --- | --- | --- | --- |
| Le lancer | 0 à 2,7 s | Le perso, la jauge, « tap to throw » | — |
| La course | 2,7 à 10,8 s | Le projectile traverse les zones l'une après l'autre (prairie, arctique, forêt, royaume des nuages, le vide) | La chance en haut : 2,09 M× → 1,45 B× → 410 B× → 229 T× → 1,73 Qa× |
| La charge | 10,8 à 15,5 s | Fond noir, éclairs, anneaux de néon rose et cyan, particules | Le multiplicateur s'emballe : ×34 → ×33,8 K → ×170 M → ×2,52 T → ×3,46 Qa |
| Les silhouettes | 15,5 à 22 s | Silhouettes d'objets de plus en plus grandes, en contour lumineux, sur fond sombre ; trèfles verts qui pleuvent | « 1 in 45 » → « 1 in 153 K » → « 1 in 10,3 M » → « 1 in 55,4 B » → « 1 in 7,04 Qa » |
| Le silence | 22 à 28,7 s | Noir complet, un petit cercle qui grandit lentement au centre | — (la musique retient) |
| L'explosion | 28,7 à 35,5 s | Flash blanc, rayons, l'objet énorme et brillant, particules partout | « ULTRA RARE », « INFINITY!! » en arc-en-ciel, « 1 in 7,048,376,644,198,790 » |

## Ce qui marche

- **Des chiffres qui grossissent sans arrêt** (M, B, T, Qa) : on reste pour voir jusqu'où ça va.
- **Les silhouettes** : on devine l'objet avant de le voir, chaque palier plus gros que le précédent.
- **Le silence avant la révélation** : 6 s de presque rien, puis tout d'un coup. C'est le moment qu'on partage.
- **La révélation est énorme** : l'objet remplit l'écran, nom en arc-en-ciel, cote absurde écrite en entier.

## Pour Steal a Shop : la vidéo « rareté max » (demande de Clément)

Les ingrédients de Clément : **casser ce qu'il y a autour, un objet énorme, une rareté de fou, un argent par seconde de fou, et fuir le vigile avec l'objet énorme sur la tête.**

| Temps | Plan | Ce qui monte à l'écran |
| --- | --- | --- |
| 0 à 2 s | Accroche : la vitrine de la Fortune Tower (zone 6) vole en éclats, ralenti | « HEIST » |
| 2 à 8 s | L'ouverture du colis : les actions s'enchaînent (masse, scie, perceuse), caméra qui tourne | « ×N LUCK » qui grimpe, la cote qui monte |
| 8 à 13 s | Silhouettes de plus en plus grandes, plafond qui craque | « 1 IN … » de plus en plus gros |
| 13 à 17 s | Le silence : noir, un point lumineux qui grandit | — |
| 17 à 21 s | L'explosion : l'objet Divine (ou Secret) colossal, taille ×10, qui **casse le plafond et le rayon**, débris partout | Nom de la rareté en grand, la vraie cote « 1 IN N » |
| 21 à 26 s | La fuite : le perso court avec l'objet géant sur la tête, le vigile derrière, caméra basse de côté | « RUN! », le `$…/s` énorme au-dessus de l'objet |
| 26 à 30 s | En base : l'objet posé, le compteur d'argent qui s'emballe | `$/s` de fou, puis « COMING SOON » |

## Ce qu'il faut pour la tourner

- **Forcer le tirage** : il faut une commande de test serveur qui donne une ouverture à la rareté choisie et à la taille choisie (×10). Elle n'existe pas dans la liaison (seules `FortuneTest`, `RebirthTest`, `OfflineTest`, `SkillTest`, `MonetizationTest` existent ; T-174 dit qu'Ironix a déjà forcé un ×10 pour un test). **À demander à Ironix** dans la liaison.
- La casse autour (plafond, rayon) existe déjà pour les objets très lourds (T-174, T-196 : `Ceiling_Crash`, `Ceiling_Debris`).
- `BB_HeldIncome` affiche déjà le `$/s` au-dessus de l'objet porté (T-198).
- Les plans « silence » et « explosion » se font au montage (fond noir, flash, rayons) à partir des plans filmés.
