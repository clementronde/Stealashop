# Ressenti du jeu de référence, vidéo 2 (2026-11-10, 20h03)

Vidéo de Clément : 26 s, 30 images par seconde, avec le son. Les durées sont comptées image par image. Les sons sont lus sur un spectrogramme : je les décris par leur forme, sans les avoir écoutés.

## 1. Argent hors ligne (0 à 6 s) : très important pour Clément

- **Une fenêtre au retour dans le jeu**, avant tout le reste :
  - bandeau vert citron « Argent hors ligne » ;
  - fond sombre translucide à damier ;
  - « Vous avez gagné : » en italique, une liasse de billets et le montant en gros chiffres verts (« $13.9M ») ;
  - deux boutons : « Réclamer » (vert) et « 49 Robux » (violet, avec l'étiquette « 2x » qui double le gain).
- **Au clic sur Réclamer** :
  - un son brillant, très riche en aigus, d'environ 0,5 s ;
  - la fenêtre disparaît, et une case avec les billets et « $13.9M » apparaît en bas au centre, au-dessus de la barre ;
  - à côté de l'argent du HUD s'affiche « +$13.9M » en vert, et le total monte.
- **Chez nous** :
  - `UI_Offline` (`ClaimButton`, `DoubleButton` avec `PriceLabel` et `TwoXTag`, `Amount`) ;
  - `Flyer`, la case qui vole vers l'argent du HUD ;
  - les sons `Offline_Claim` et `Cash_Collect`.

## 2. Événement céleste : à reprendre pour nos événements météo (7 à 20 s)

- **Ciel** : nuages roses et orangés de coucher de soleil, et deux ou trois arcs-en-ciel.
- **Effets dans les airs** :
  - de grandes étoiles blanches à 4 branches qui scintillent (elles grossissent, puis s'effacent) ;
  - des comètes jaunes lumineuses qui traversent le ciel en courbes ;
  - des étincelles qui flottent.
- **Repères de l'événement** :
  - un compte à rebours en bas à droite (« Fin : 01:51 »), à côté de l'emblème de l'événement (des ailes d'ange) ;
  - un panneau dans le monde annonce le prochain événement (« ??? Titanic Egg, Spawns In: 26:50 ») ;
  - un multiplicateur flotte au-dessus des œufs (« x4.28 Chance »).
- **Pour nos événements météo** (pluie d'or, nuit étoilée, tempête…). Chaque événement aurait :
  - un ciel à lui (Sky et Atmosphere) ;
  - une couche de particules qui suit la caméra ;
  - quelques grands éclats en BillboardGui ;
  - des comètes en Beam ou en Trail ;
  - une pastille « Ends in 01:51 » dans le HUD et une annonce au début ;
  - un bonus visible au-dessus des objets (« x2 Cash »).

## 3. Poursuite (19,9 à 22,7 s)

- **Au vol de l'objet, d'un coup** :
  - la barre de gauche et la barre du bas disparaissent ;
  - une bannière rouge « COURIR ! » apparaît en haut ;
  - les bords de l'écran passent au rouge et palpitent ;
  - le poursuivant devient rouge, avec un « ! » au-dessus de lui ;
  - un bouton rouge « Lâcher », avec une poubelle, apparaît en bas.
- **Son** :
  - la musique se coupe environ 0,4 s ;
  - un coup grave et large (environ 0,4 s) lance une musique rapide (environ 150 battements par minute).
- **Chez nous** :
  - `UI_Chase` a déjà la vignette et « GUARD! RUN! » ;
  - nouveaux sons : `Heist_Grab` (le coup de départ), `Chase_Whistle` (sifflet), `Chase_Music` et `Chase_Siren` (en boucle), `Guard_Radio` (voix de radio de police) ;
  - **`BB_GuardShout`**, la bulle du policier au-dessus du vigile : « ! » au départ, puis « STOP RIGHT THERE! », « COME HERE! », « STOP NOW! », « FREEZE! », « THIEF! » ou « GIVE IT BACK! », toutes les 2,4 s.
- **Pas trouvé** : aucune vraie sirène de voiture de police dans les bibliothèques sous licence (Roblox, ProSoundEffects, APM). Une vidéo de Clément avec une sirène aiderait à en choisir une autre.

## 4. Arrivée en zone safe (22,7 s) : l'effet que Clément veut

- **Image** :
  - un flash doré sur tout l'écran, qui s'efface en 0,4 à 0,5 s ;
  - la caméra revient plus large, comme un dézoom ;
  - le rouge et la bannière disparaissent, le HUD et la barre du bas reviennent ;
  - l'objet volé arrive dans une case de la barre, mise en avant.
- **Son** : un balayage brillant, très aigu, puis un petit carillon de réussite ; ensuite, la musique redevient calme.
- **Chez nous** :
  - `UI_Escape.Flash` (doré) ;
  - zoom de la caméra (+12 de champ de vision en 0,08 s, puis retour en 0,45 s) ;
  - `Heist_SafeFlash` puis `Heist_Escape` ;
  - `FX_Escape`, la bannière « ESCAPED! » et `Celebrate`.

## 5. Texte en bas de l'écran

- **Messages courts, sans cadre**, au centre au-dessus de la barre : texte blanc, avec un contour sombre (« Vous pouvez désormais vous offrir le sentier rouge ! »).
- **Réussite** : en vert (« Pioche de cactus équipée avec succès ! », vu dans la 1re vidéo).
- **Chez nous** : `UI_Toast` (`Stack.Template`) : vert pour une réussite, blanc pour une information.
