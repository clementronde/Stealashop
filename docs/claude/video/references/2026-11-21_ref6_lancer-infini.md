# Référence 6 : le lancer « infini » (Throw Food for Animals)

Source : vidéo TikTok d'un compte de clips Roblox, envoyée par Clément le 21/11 (« INFINITE 💀 », #roblox). Regardée dans le lecteur intégrable de TikTok ; étudiée pour sa forme, jamais réutilisée.
Chiffres affichés le 21/11 : 27 s, environ 60 400 j'aime, 780 commentaires, 5 000 enregistrements, 6 000 partages.

## Mesures

- **Durée** : 27 s.
- **Format** : un enregistrement d'écran du jeu en 16:9, posé au milieu d'un cadre 9:16 avec des bandes noires en haut et en bas. Aucune retouche : pas de texte ajouté ni d'étalonnage, les textes sont ceux de l'UI du jeu.
- **Un seul plan qui suit l'action** : la caméra du jeu suit l'objet lancé du début à la fin.

## Le déroulé

| Temps | Ce qu'on voit |
| --- | --- |
| 0 à 2 s | Le joueur charge son lancer : jauge de puissance qui monte, « +20 » |
| 2 à 4 s | Le lancer part, la caméra suit l'objet en l'air |
| 4 à 15 s | L'objet survole une longue piste qui traverse des zones successives. **Le nom de chaque zone s'affiche** (Mythical Paradise, Phantom Harbor…) et **un multiplicateur grimpe** au centre (37,40X, puis 48,72X, puis 53,59X…) : l'escalade tient le spectateur |
| 15 à 25 s | L'objet retombe très loin. **Révélation de la rareté** : « 1 in 266 », puis « 1 in 6,200,337 », avec le nom d'une créature très rare |
| 25 à 27 s | Image tenue, puis la fin TikTok |

## Pourquoi ça marche (d'après les chiffres)

1. **Une escalade lisible** : un nombre qui monte sans arrêt et des noms de zone qui changent. On veut voir jusqu'où ça va.
2. **Une récompense démesurée à la fin** (« 1 in 6 millions ») qui donne envie de commenter et de partager : 6 000 partages pour 60 000 j'aime.
3. **Le titre promet un « glitch »** (« INFINITE 💀 ») : le spectateur reste pour le vérifier.
4. **Les graphismes ne comptent pas ici** : l'image est brute et mal cadrée. C'est le contraire du cap de Clément (images soignées). On reprend l'idée, pas la réalisation.

## Pour Steal a Shop : idée « la course des 6 zones »

- Un seul plan qui suit un joueur, de dos, qui court dans le couloir de la zone 1 à la zone 6. **Le nom de chaque zone et sa rareté la plus haute s'affichent** à chaque passage de porte (`ZoneGate`), comme les noms de zone de la référence.
- L'escalade : les raretés qui montent zone après zone (couleurs de `Config/Rarities`), et le vigile qui le poursuit de plus en plus vite.
- La récompense : un colis **Secret** ouvert au bout, avec l'arc-en-ciel et le ralenti du jeu (`Rarities.Secret.Rainbow` et `SlowMotion`). La chance réelle s'affiche en « 1 in … », lue dans `Config/Rarities` et `ShelfBoxes` (ne jamais l'inventer).
- On garde notre réalisation : vertical natif, couleurs saturées, texte au tiers haut, 15 à 20 s.
- À vérifier avant de filmer : que tout ce qu'on montre existe dans le jeu (aucune zone ni rareté cachée par `Features.*`).
