# Ce que voit et entend un vrai joueur

Relevé le 2026-11-25 dans le code (`origin/main` 38842278) et dans un Play de la place DEV, après le retour de Clément sur la série « plans naturels » : « ça montre une idéalisation du jeu, pas le vrai jeu ». **Un plan de trailer doit montrer ce qui est ici, rien de plus, rien de moins.** Référence filmée : `StealAShop-Art/Trailers/2026-11-25_analyse_jeu/vraie_partie_casse_colis_poursuite.mp4` (casse, colis, poursuite et capture en 27 s, avec le son).

**DEV et PROD diffèrent** (`Config/Features.luau`, « Dev » = GameId 10774974820) : en DEV, poursuite V3, contours BD, catalogue v3 et éjection à travers la vitre (GlassThrow) sont allumés ; en PROD non. Filmer ce que le lancement montrera : demander à Clément quelle version.

## Sommaire

1. Vitrine d'un magasin PNJ
2. Colis
3. Objet porté, poursuite, capture
4. Boutique d'un joueur
5. Vol entre joueurs
6. HUD
7. Sons par moment
8. Règles pour la mise en scène

## 1. Vitrine d'un magasin PNJ

- **Plusieurs coups** : zone 1 = 15 PV (15 coups de poing, 3 s), zones 2 à 5 environ 30 coups avec l'outil de la zone ; 5 coups par seconde au plus ; la vitre se répare (3 %/s). Un compte de développeur (dégâts 100 000) casse en un coup : ce n'est pas le vrai jeu.
- **Chaque coup** : la vitre se creuse (cuvette qui grandit, jamais traversée), 8 à 26 éclats volent vers le casseur, étincelles (`FX_GlassSparkle`), petite poussière, éclair de lumière, petite secousse ; chiffre de dégâts `BB_Damage` « -N » blanc qui monte ; barre `BB_WindowHP` « pv / max » ; panneau `BB_StoreInfo` (nom du magasin, force et vitesse demandées en vert, orange ou rouge). Plus de textures WIN_Crack.
- **Au premier coup** : « POLICE IN 8s » en rouge en haut de l'écran ; un témoin accourt et photographie (flash `FX_Witness_Flash` toutes les 0,9 s), son « ? » se remplit en 8 s puis il appelle la police.
- **La casse** : arrêt sur image de 0,06 s, flash blanc 0,08 s, forte secousse, **« SMASHED! »** à l'écran (0,7 s), 30 à 40 éclats vers l'intérieur et l'extérieur, poussière ; puis **« HEIST: 10s »** au-dessus du magasin et dans le HUD. Les témoins fuient, une foule apparaît devant la vitrine quand quelqu'un entre. Musique `MUS_Heist`. Le rideau tombe à la fin du temps, la vitre revient 20 s plus tard.

## 2. Colis

- Sur le rayon : un `BOX_<Rareté>` par emplacement, étiquette `BB_Box` (la rareté dans sa couleur), contour.
- **Le joueur ne prend pas le colis** : il maintient E (« Open », 0,3 à 1 s selon la rareté), le colis **saute tout seul** du rayon au sol de l'allée (0,6 s, 4,5 studs, bond de 2 studs). Le HUD disparaît, la caméra se place à 11 studs.
- **Ouverture en plusieurs actions** : 3 (Commun) à 10 (Divin), la dernière toujours au marteau. Actions au hasard : marteau, scie, pied-de-biche, perceuse, coup de pied, fouille (jette des babioles), loupe. Le joueur saute d'un côté à l'autre du colis dans un petit nuage (`FX_Unbox_Puff`). Le colis tremble de plus en plus. Compteur `BB_UnboxOdds` « 1 IN N » qui grimpe. Parfois « UPGRADE! » : le colis grossit et change de couleur.
- **Révélation** : explosion (`FX_Unbox_Burst`), silhouettes noires de chaque rareté jusqu'à la bonne, flash blanc, puis l'objet grandit jusqu'à sa taille (un objet énorme casse le plafond et le rayon) ; étiquette `BB_Reveal` (nom, rareté, poids, mutation, chances, $/s). Puis l'objet se pose **tout seul sur la tête** (pas d'animation Grab).

## 3. Objet porté, poursuite, capture

- Objet au-dessus de la tête, à sa taille de poids (jusqu'à ×16), halo de rareté, étiquette `BB_Carry` (nom, mutation, rareté, $/s, poids). Animations `CarryIdle` / `CarryRun`.
- **Poursuite** (écran du voleur) : **« RUN! »** qui pulse, bords d'écran rouges, champ +6, HUD caché ; le vigile surligné en rouge, bulles `BB_GuardShout` (« THIEF! », « STOP RIGHT THERE! »…) ; sifflet, radio, musique `MUS_Chase`, cœur qui bat quand il est à moins de 10 studs. Pas de chevrons au sol.
- **Capture** : `Catch` du vigile, le voleur est projeté (40 studs/s de côté, 22 vers le haut) puis à terre (`Knockdown`, `GetUp`), **« CAUGHT! »** en tampon, poussière. L'objet tombe au sol ; dans le magasin, le vigile le ramasse (`PickUp`) et il revole sur son rayon.
- **Arrivée en zone safe** : le vigile s'arrête essoufflé (`Tired`), écran « Item secured! ».

## 4. Boutique d'un joueur

- Objet exposé sur son présentoir, **à sa taille de poids** : 10 kg = ×2, 50 kg = ×3,4, 250 kg = ×5,6, jusqu'à ×16 ; réduit seulement s'il dépasse le présentoir. Vu en Play : échelles de 1,1 à 9, souvent 2 et plus, des objets de 1 à 10 studs. **Les tailles varient beaucoup** ; un objet à l'échelle 1 est trop petit.
- Il flotte à 0,6 stud, monte et descend (±0,3 stud, 2,6 s) ; il fait un tour et deux sauts quand on encaisse sa plaque.
- **Étiquette `BB_Item` au-dessus de chaque objet** : nom, mutation (« BIG · GOLD »), rareté dans sa couleur (Secret en arc-en-ciel), **« +$X/s »**, poids (« 20 KG »). Lisible de loin.
- Halo de rareté (lumière, particules, rayons dès Légendaire). Plaque verte d'encaissement avec le montant écrit dessus.
- **Contour BD** (DEV) : Highlight trait #040435 sans remplissage sur les 60 éléments interactifs les plus proches (objets, colis, vitrine) ; blanc sur celui qu'on peut utiliser.
- Couleurs de rareté : Commun #B0B7C3, Peu commun #2FE08F, Rare #2F9BFF, Épique #A855F7, Légendaire #FFC21A, Mythique #FF3B5C, Secret arc-en-ciel, Divin #FFE9A8.

## 5. Vol entre joueurs

- La porte vitrée d'une boutique prend **40 coups** (« -1 » à chaque coup), barre « x / 40 », panneau `BB_ShopInfo` (« Alice's Shop », $/s, PV, OPEN ou LOCKED). Le propriétaire peut verrouiller 30 s.
- Porte cassée : le propriétaire reçoit l'alerte « X IS STEALING YOUR SHOP! » et la sirène, sa batte s'équipe.
- Le voleur maintient « Steal » 1 s (`Grab`), l'objet sur la tête **avec un contour rouge** #E8413C visible de tous, vitesse fixe 32.
- **Défense à la batte** : étourdit 2 s, le voleur est remis dehors, l'objet retourne sur son présentoir (il ne tombe pas). En DEV : le voleur est **projeté à travers la vitre** en ragdoll (trou de 6 s dans la vitre, `FX_ShopGlass_Burst`, traînée `FX_ThrownTrail`).
- Défenses achetées : garde du corps « Security », garde de porte, caméras, pièges (colle, filet, alarme).

## 6. HUD

Toujours là, sauf pendant une poursuite ou une révélation : argent, $/s, vitesse, force, boutons (Shop, Index, Upgrades, Display…), barre d'outils (1 outil de casse, 2 batte), compte à rebours de la nuit, minuterie de casse. Encaissement : bords verts, billets et pièces qui volent vers le compteur.

## 7. Sons par moment

Fichiers dans `StealAShop-Art/Video/Trailer/bruitages/<Nom>.wav` (enregistrés dans le Play, voir `_a_refaire.txt`).

| Moment | Sons |
| --- | --- |
| Coup sur la vitre | `HitWindow_Impact` ou `HitWindowHeavy_Impact` + `Glass_Hit` (de plus en plus aigu) |
| Casse | `Glass_BreakThud` + `Glass_BreakShatter`, puis `Glass_BreakDebris` |
| Témoin, police | `Witness_Photo`, `Witness_Call`, `Police_Arrive` |
| Foule | `Crowd_Cheer`, `Crowd_Clap`, `Crowd_Gasp`, `Crowd_Shout`, `Crowd_Scream` |
| Ouverture du colis | `Unbox_Windup` `Unbox_Swing` `Unbox_HammerHit` ; `Unbox_Saw` ; `Unbox_CrowbarWedge/Creak/Crack` ; `Unbox_Drill` ; `Unbox_KickWhoosh` `Unbox_Kick` `Unbox_BoxSlide` ; `Unbox_Rummage` `Unbox_Toss` ; `Unbox_Rattle`, `Unbox_Smoke`, `Unbox_Tier` |
| Révélation | `Unbox_Burst`, `Unbox_Silhouette`, `Unbox_Suspense`, `Unbox_UpgradePop`, `Unbox_Confetti`, puis `Reveal_RarityLow` / `Mid` / `High`, `Reveal_Grow*`, `Reveal_Land*`, `Ceiling_Crash`, `Shelf_Break` |
| Poursuite | `Heist_Grab`, `Chase_Whistle`, `Guard_Radio`, `Chase_Heartbeat`, `MUS_Chase` |
| Capture | `Catch_Impact`, `Catch_Slam`, `Knockdown_Land` |
| Objet sauvé | `Heist_SafeFlash`, `Heist_Escape` |
| Batte | `SwingBat_Impact` (le souffle), `SwingBat_Hit` |
| Vol dans une boutique | `TheftAlert_Siren`, `Grab_Grab` ; éjection : `Throw_Hit` `Throw_Whoosh` `Throw_GlassBurst` |
| Argent | `Cash_Pad` |
| Nuit | `Night_Start`, `Night_WallRise`, `Shutter_Close` |

## 8. Règles pour la mise en scène

- Une vitrine se casse en **plusieurs coups**, à plusieurs ou seul, avec les éclats, les dégâts « -N » et la barre de PV, puis « SMASHED! ».
- Le colis **saute au sol** et s'ouvre en plusieurs actions autour de lui ; l'objet grandit puis se pose sur la tête.
- Tout objet exposé ou porté a **son étiquette** (nom, rareté, $/s, poids), **son halo**, **son contour**, et **sa taille de poids** (variée).
- La poursuite montre « RUN! », les bords rouges et le vigile en rouge qui crie ; la capture montre « CAUGHT! ».
- Un voleur de boutique porte un contour rouge ; la batte l'étourdit et le remet dehors.
- Le son vient de la banque du jeu, posé sur l'image ; il fait partie du plan.
- Alterner travellings et **plans fixes** où quelque chose bouge (colis qui saute, objet qui flotte, vigile qui arrive).
