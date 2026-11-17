# Throw a Seed : ce qu'on reprend (2026-11-17)

Vidéo de Clément (`StealAShop-Art/References/Videos_Jeux/2026-11-17_ThrowASeed_D.mp4`, 219 s), découpée image par image en trois fiches (`…_D_analyse_0-80.md`, `_75-150.md`, `_145-219.md`, même dossier, avec les images). Clément : « inspire-toi un maximum, c'est vraiment top ». On reprend les techniques, le rythme et la construction, jamais leurs dessins, sons ni leur identité. Les cotes, prix et gains restent ceux de `Config` et de la Partie 1.

## 1. Ouverture du colis (décision de Clément)

Ce que Clément veut : « on ne doit pas voir ce qu'on a ; on doit voir le colis qui grossit en fonction de la chance, avec le 1 sur 2, 1 sur 5, 1 sur 10… 1 sur 1 milliard qui augmente ; puis il s'ouvre ; l'objet est en noir, d'abord l'objet le plus bas, puis un peu mieux, puis encore mieux ; seulement à la fin, sur le bon objet, il se découvre en couleur ; avec de belles particules ».

Mesures chez eux :
- **Durée selon la rareté** : 3,4 s pour 1 sur 7, 6,6 s pour 1 sur 1 200, 15 à 17 s du clic à l'objet pour le tirage complet. Jamais 0,5 s sans qu'un chiffre change.
- **Avant l'ouverture** : un multiplicateur de chance recompte depuis ×1,00 (environ +8 % toutes les 100 ms). À chaque palier : éclair de couleur (rose, puis jaune), flash blanc d'une image, anneau au sol, teinte de tout l'écran pendant environ une image, et l'objet grossit (environ ×1,7 à l'écran, la caméra se rapproche un peu).
- **Compteur « 1 IN N »** : billboard au-dessus de l'objet, chiffres blancs très gras, contour noir épais en pastille. Il change toutes les 67 à 100 ms, monte de façon géométrique, s'arrête 0,4 à 0,5 s à chaque changement de silhouette, ralentit à la fin (de ×1,25 à ×1,03 d'une valeur à l'autre ; 767, 791, 799, 800). Grands nombres abrégés (« 1.05K »).
- **Silhouettes** : des **modèles 3D noirs** (ils font une ombre, sont en perspective), pas des images. 3 à 5 objets de plus en plus rares et gros, la dernière étant le vrai objet resté noir 0,4 à 0,7 s. Chaque changement : nuage de fumée blanche, étoile blanche de 0,17 s, petit son qui monte. Chez nous : un `Highlight` noir (ou matériau noir) posé par le code sur des copies d'objets de raretés inférieures, puis sur le vrai.
- **Révélation** (moins de 0,5 s) : objet surexposé 2 images, étoile blanche 5 images, flash blanc plein écran d'environ 100 ms, objet en couleurs en 150 ms, puis anneau et étincelles de la couleur de la rareté, confettis 0,5 s.
- **Textes du résultat**, en haut au centre : rareté (2,2 % de la hauteur), nom (4,5 %), « NEW! » rouge à contour blanc (2 %), revenu vert (2,4 %), cote (4 %).
- **Sons** (déduits du spectre, à écouter par Clément) : un clic aigu par changement du compteur (environ un toutes les 60 ms, plafonné vers 9 à 16 par seconde), un petit son qui monte (500 à 1 300 Hz) à chaque nuage, un coup net au flash final.
- **Cinéma** : HUD caché pendant les moments forts, bandes noires de 9,8 % en haut et en bas (entrée et sortie en 0,23 s).
- **Boutons de fin** (relancer / retour) : montent du bas en 0,27 s, `Back Out`, dépassement léger, sans fondu. Retour en jeu par un fondu au blanc de 0,5 s.

## 2. Boutons et croix (une seule recette partout)

De l'arrière vers l'avant : rebord du bas plus foncé (6 à 9 % de la hauteur) ; contour sombre de la même teinte (3 px, 3 à 4 % de la hauteur) ; face en dégradé vertical, clair en haut (ex. vert #E5FF4E → #9AFF09 → #48FF14, rebord #129D03, contour #113909) ; liseré intérieur clair d'1 px ; deux traits de brillance en diagonale ; texte blanc en capitales (37 % de la hauteur) à gros contour de la teinte sombre. **Coins presque droits (rayon environ 6 % de la hauteur).** Couleurs : vert = oui, rose = non, fermer ou arrêter, bleu = revenir, orange = action conseillée, gris = désactivé. La croix suit la même recette, à la couleur du bandeau : au survol +7 % en 133 ms, au clic environ 90 %, fermeture 130 ms après. Chez nous : au moins 44 px de haut sur téléphone (les leurs sont trop petits).

## 3. Fenêtres

- Ouverture : `UIScale` de 0,84 (ou 0,9) à 1 en 0,2 à 0,33 s, `Back Out`, dépassement de 1 à 2 %. Fond flouté et HUD caché dès la première image.
- Fermeture : vers 89 à 92 % en 0,13 s en glissant un peu vers le bas, puis disparition d'un coup.
- Tailles : leur magasin fait 51 à 53 % × 55 à 64 % de l'écran (notre boutique d'armes : 64 × 67 %, trop grosse).

## 4. Boutique Robux

- **Coffre et packs en 3D** dans un `ViewportFrame` (preuves : l'angle de vue change, les flancs apparaissent) ; à l'ouverture de la fenêtre, le coffre passe d'une forme noire à ses couleurs. Les petites icônes (dés, potions, billets) sont des images fixes.
- **Rayons de lumière** derrière les offres : tournent lentement, environ un tour en 20 s.
- **Survol d'une carte** : environ +3 %, sans dépasser du cadre.
- **Réduction** : ancien prix petit et clair au-dessus, nouveau prix gros, « ONE TIME OFFER », étiquette « 75% OFF » penchée de 5° (chez nous, sans qu'elle sorte du cadre), minuteur qui descend chaque seconde.
- **Une seule liste qui défile par sections**, onglets dans la fenêtre à droite, l'onglet actif suit le défilement.

## 5. Panneau des objets (leur « Mes plantes ») = notre inventaire des objets exposés

Collé à droite, 31 % × 64 % de l'écran. Une ligne par objet (12 % de haut) : vignette, nom, taille, revenu par seconde, et deux boutons empilés (récupérer / vendre). En bas, un bouton pleine largeur « placer au meilleur endroit ». Leurs vignettes sont des images fixes.

## 6. Tutoriel

6 étapes en 16,6 s, une consigne de 3 à 7 mots à la fois, 1,1 à 1,9 s d'action par étape. Trois guides :
- des chevrons au sol qui défilent vers la cible (chez nous : un `Beam` avec `TextureSpeed`) ;
- un grand V au-dessus de la cible, qui rebondit ;
- l'écran assombri à 65 % en une image, sauf le bon bouton entouré, l'autre en gris ; flèche qui arrive si le joueur hésite 1,2 s.

Une seule ligne de message, rouge pour un refus, verte pour une réussite. La récompense quotidienne n'arrive qu'après le tuto.

## 7. Parcelles

Barrière basse, entrée entre deux piliers à lanternes, tout visible de l'extérieur, étiquette nom + revenu sur chaque objet, « vide » sur les places libres, pancarte d'amélioration « 8 > 9 ▲ $3K » posée à l'entrée (avant, après, prix, sans menu), avatar rond + nom + revenu total au-dessus de la parcelle.

## Décisions de Clément du 2026-11-17

- **Boutique des joueurs** : « tout le tour en verre transparent, comme si rien n'était là, sauf la porte qui reste comme elle est et cassable ».
- **Ouverture** : comme décrite en section 1, durée selon la rareté.
- **Tutoriel** : les trois guides de la section 6.
- **Capture par la police ou le vigile** faute de puissance ou de vitesse : message du genre « Pas assez de puissance ? Invite un ami pour t'aider à braquer le magasin », avec un bouton d'invitation.
