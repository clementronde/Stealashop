# Ressenti de l'UI : analyse du jeu de référence (2026-11-10)

Analyse de la vidéo de Clément : 2 min 21 s, 30 images/s, avec le son. Elle comprend sa boutique, l'Index, le panneau des objets équipés, le tapis de course, les boutiques de pioches, de gemmes et de traînées, et la récompense gratuite. J'ai aussi comparé ses 5 captures, prises avec et sans survol.

Méthode :
- Les durées sont comptées image par image : précision ± 33 ms.
- Les sons sont lus sur des spectrogrammes. Je les décris par leur forme (durée, hauteur, attaque), sans les avoir écoutés.

## 1. Survol (hover) : ce que Clément veut copier

| Élément | Ce qui se passe au survol | Valeurs relevées | Pour nous |
| --- | --- | --- | --- |
| **Case d'objet** (barre d'outils, Index, cartes) | Le cadre ne bouge pas. **L'icône grossit, sort du cadre par le haut et penche un peu.** La batte dépasse de la case. Le poulet de l'Index déborde de sa carte, qui reçoit un contour blanc | Icône × 1,25 à 1,3 ; inclinaison d'environ −8° ; contour blanc de 2 px ; transition courte et sans à-coup | Cartes de l'inventaire, de l'Index et de l'arbre : `Icon` dans un cadre qui **ne coupe pas** son contenu (`ClipsDescendants = false`) ; le code anime l'`UIScale` et la `Rotation` de l'icône |
| **Bouton** (Déséquiper, prix Robux, Équiper le meilleur) | **Il s'assombrit** (il ne s'éclaircit pas) et grossit légèrement. Son contour paraît plus épais | Environ −20 à −25 % de luminosité ; × 1,05 à 1,08 | Un calque `Shade` (cadre noir, coins arrondis) dans chaque bouton. Le code passe sa transparence de 1 à 0,78. Il ajoute × 1,06 par `UIScale` |
| **Carte de l'Index** | La fiche de droite montre **tout de suite** l'objet survolé (nom, rareté, $/s), sans clic | Instantané | Index v2 : à prévoir si on ajoute une fiche détail |
| **Petite vignette** (pets de l'œuf) | Une infobulle apparaît au pointeur : nom en blanc, rareté dans sa couleur. La vignette reçoit un contour | Instantané, l'infobulle suit le pointeur | Les objets possibles d'un colis, et les tuiles de l'arbre |
| **Son** | Un « tic » très court à **chaque début de survol** | Moins de 20 ms, aigu et large, très discret | `UI_Hover` |

## 2. Clic

- **Un seul son de clic pour tous les boutons** : ouvrir, fermer, onglets, cartes. Deux attaques très rapprochées (environ 30 ms), puis un petit « bip » brillant (deux notes, vers 3 kHz et 7,5 kHz, environ 60 ms). Toute l'interface sonne donc pareil. → `UI_Click`.
- **Bouton appuyé** : tant qu'on appuie, il devient plus foncé et un peu plus petit (environ × 0,95).
- **Au relâché** :
  - le bouton change d'état tout de suite (« $6M » devient « Équipé », en vert clair) ;
  - un **son de réussite** joue : une pluie scintillante de 0,35 à 0,45 s avec deux carillons, vers 3,4 et 7,8 kHz. → `UI_Purchase`, ou `UI_Equip` ;
  - un **message bref en bas, au centre** apparaît (« Pioche de cactus équipée avec succès ! ») ;
  - à côté de l'argent, la somme dépensée s'affiche en rouge (« −$6M »).

## 3. Ouverture, fermeture, apparition des éléments

| Moment | Relevé | Valeur proposée (`Config/UiMotion`) |
| --- | --- | --- |
| Ouverture d'une fenêtre (Boutique, Index, Récompense) | La fenêtre surgit d'environ 55 % de sa taille à 100 % en **3 à 4 images (100 à 130 ms)**, avec un léger rebond | Échelle 0,55 → 1 en 0,14 s, Back Out (dépassement d'environ 1,04) |
| **Contenu, élément par élément** | Les éléments arrivent après la fenêtre, **un par un**. Boutique : 6 pets apparaissent l'un après l'autre, **à 33 ms d'écart**, 0,4 s après l'ouverture. Index : les onglets de mutation **glissent depuis la gauche, à environ 50 ms d'écart** | Chaque élément passe de l'échelle 0,8 (ou d'un décalage de 20 px) à 1 et de la transparence 1 à 0, en 0,12 s. Écart de 0,04 s. Départ 0,08 s après la fenêtre |
| Changement de rubrique dans la boutique | Les anciennes cartes s'effacent **de droite à gauche** (environ 33 ms d'écart, 100 ms chacune). Les nouvelles arrivent **de gauche à droite** (40 à 50 ms d'écart, environ 130 ms chacune, d'abord en semi-transparence). Environ 0,55 s en tout | Sortie : transparence 1 et échelle 0,9 en 0,1 s, écart de 0,03 s. Entrée : comme l'ouverture du contenu |
| Fermeture | La fenêtre **rétrécit vers son centre en 2 à 3 images (70 à 100 ms)**, sans fondu ni rebond, avec le son de clic | Échelle 1 → 0 en 0,09 s, Quad In |
| Panneau latéral (objets équipés) | Il glisse depuis le bord droit en environ 130 ms. Une languette rouge « > » le replie | Décalage de la largeur du panneau → 0 en 0,13 s, Quad Out |
| Boutique de proximité | Monter sur le cercle lumineux ouvre la boutique (même animation). En partir la ferme | Pour nous : panneaux d'amélioration et boutiques de la place |
| Images | À l'ouverture de la boutique de pioches, des cases grises restent visibles 1 à 2 images, le temps que les images chargent | Chez nous : **précharger** les icônes (le code de l'Index le fait déjà) |

## 4. Gains et améliorations (tapis de course)

- **Pendant la course** :
  - des chiffres « +16 » s'envolent au-dessus du joueur, environ toutes les 0,22 s, à des places un peu différentes ;
  - chaque gain fait un **« boing » grave et montant** (environ 300 → 800 Hz, environ 80 ms) ;
  - le compteur de vitesse du HUD monte en même temps.
- **À l'achat de l'amélioration** :
  - le tapis **change de modèle tout de suite** (version dorée) ;
  - les gains passent **à « +32 »** dès le gain suivant : le joueur voit l'effet de son achat ;
  - le panneau affiche déjà le niveau suivant (« Niveau 3 > Niveau 4 », « $500M ») ;
  - le son de réussite et le message en bas jouent, et le cash affiche en rouge « −$10M ».
- **Prix trop cher** : le bouton de prix devient **gris**. On sait d'un coup d'œil si on peut acheter. Le prix en Robux reste violet à côté : c'est la porte de sortie payante.

## 5. Ce qui fait acheter et rester (vu dans la vidéo)

1. **Œuf vedette à durée limitée** : compte à rebours en direct (« 11d 21h 2m 11s »), étiquette « NOUVEAU ! », taux affichés sous chaque pet (48 % … 0,1 %), cadres de la couleur de la rareté. Achats groupés (1, 3, 10 ou 50 œufs) au prix unitaire dégressif.
2. **Bouton cadeau 🎁 à côté de chaque prix** : on offre à un ami.
3. **Une seule page qui défile, en rubriques** (« ~ Passes de jeu ~ », « ~ Packs de vitesse ~ », « ~ Packs d'argent ~ », « ~ Potions ~ »…), sans onglets. Des bandeaux « MEILLEURES VENTES » et « MEILLEURE OFFRE ».
4. **Achat d'impulsion très peu cher** : « Doublez votre vitesse x1 > x2 » pour 3 Robux.
5. **Boost gratuit contre une pub** (« FREE Boost! 5 minutes, Regarder une publicité »), et des **récompenses communautaires** : rejoindre le groupe donne un pet exclusif.
6. **Index à objectifs** :
   - barre de la zone (« 4/8 ») avec une récompense à réclamer (+60 de vitesse, $100), et un compteur global (« Débloqué : 7/120 ») ;
   - index par mutation (Or, Diamant, Foudre…) : « Découvre 80 % de l'index Or pour le Golden Rake » donne un objet exclusif ;
   - **pastille rouge « ! »** sur l'onglet qui a quelque chose de neuf ;
   - silhouettes « ??? » **teintées de la couleur de leur rareté**.
7. **Emplacements limités qu'on achète** : « 7/10 Actifs », « +1 Équiper [45M$] », et un gros « Équiper le meilleur ».
8. **HUD** : bouton « Balancement automatique » (frappe automatique), compte à rebours d'événement (« Dans : 01:32 », puis « Fin : 04:56 »), annonce en haut de l'écran.
9. **Base** :
   - « Vous gagnez $35.2M /jour hors ligne » affiché dans la base ;
   - chaque objet a son « $/s » flottant ;
   - l'objet porté a son étiquette (mutation en couleur, $/s, rareté).
10. **Cadeau « GRATUIT » posé sur la carte** : la récompense « TEMPS LIMITÉ ! +10K de vitesse » demande d'aimer le jeu, de le mettre en favori et de rejoindre le groupe. Chaque action est cochée une par une, puis on clique « Réclamer ! ».
11. **Messages de réussite** systématiques en bas de l'écran, et le prix dépensé en rouge à côté de l'argent.

## 6. Ce que je propose pour Steal a Shop

**Valeurs à reporter dans `Config/UiMotion`** (elles remplacent les V0 de `ui-motion-skilltree.md` pour l'ouverture, la fermeture et le survol) :

| Nom proposé | Valeur |
| --- | --- |
| `Open` | fenêtre 0,55 → 1 en 0,14 s, Back Out |
| `OpenStagger` | contenu : 0,12 s par élément, écart de 0,04 s, départ à 0,08 s |
| `Close` | 1 → 0 en 0,09 s, Quad In |
| `SwapOut` / `SwapIn` | changement de rubrique : sortie en 0,1 s (écart de 0,03 s), entrée comme `OpenStagger` |
| `HoverButton` | × 1,06 en 0,08 s, Quad Out ; `Shade` de 1 à 0,78 |
| `HoverIcon` | icône × 1,28 et −8° en 0,1 s, Back Out ; retour en 0,12 s, Quad Out |
| `Press` | × 0,95 en 0,05 s ; relâché en 0,2 s, Back Out |
| `Drawer` | panneau latéral en 0,13 s, Quad Out |
| `FloatGain` | « +16 » : monte de 3 studs et s'efface en 0,6 s, place au hasard (± 1 stud) |

**Ce que Clément livre** (aucun script) :
- un calque `Shade` dans chaque bouton ;
- des icônes qui ne sont pas coupées par leur cadre ;
- un contour `HoverOutline` caché sur les cartes ;
- les sons, au nom du groupe :
  - `UI_Hover` (tic) et `UI_Click` (clic et bip) ;
  - `UI_Purchase` et `UI_Equip` (scintillement d'environ 0,4 s) ;
  - `Train_Gain` (boing qui monte) et `UI_Reward` (petite fanfare) ;
- la variante dorée du tapis et du banc à chaque niveau (déjà prévue par la session de la boutique).

**Ce qu'Ironix code** :
- le module de mouvement d'interface avec les valeurs ci-dessus, et le son à chaque survol et à chaque clic ;
- l'apparition des éléments un par un dans tous les écrans ;
- le bouton de prix en gris quand l'argent manque ;
- le message de réussite et le « −$X » rouge ;
- le changement de modèle immédiat à l'amélioration.

**Idées d'économie et de rétention** (à trancher) :
- un colis vedette à durée limitée, avec les taux affichés ;
- le bouton cadeau à côté des prix Robux ;
- la pastille « ! » sur les écrans qui ont du nouveau ;
- la récompense de complétion par zone de l'Index, à réclamer (nous avons +5 % de revenus : un bouton « Claim » le rendrait visible) ;
- le gain hors ligne affiché dans la boutique du joueur ;
- un achat d'impulsion à 3 à 5 Robux ;
- la récompense « aime le jeu, mets-le en favori, rejoins le groupe ».
