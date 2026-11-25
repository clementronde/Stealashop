# Tourner et exporter un plan

Méthode vérifiée le 2026-11-24 dans la place DEV (Edit, MCP Roblox Studio, ffmpeg 9). Chemins : `SK` = `.claude/skills/trailer-tiktok`, `TL` = `tools/clement/trailer`, `ART` = `C:\Users\Charment\Documents\StealAShop-Art\Trailers`.

## Sommaire

1. Avant de commencer
2. Charger l'outil
3. Faux joueurs
4. Écrire un plan
5. Repérer un cadrage
6. Filmer
7. Monter et exporter
8. Nettoyer
9. Pannes connues

## 1. Avant de commencer

- `list_roblox_studios` : Studio en **Edit**, place DEV. Personne en Play (sinon attendre ; ne jamais arrêter le Play d'un autre).
- Demander à Clément la vue 3D pour la durée du tournage : il ne touche pas Studio, la fenêtre reste devant et non couverte. S'il peut, il agrandit la vue 3D (fermer l'éditeur d'animation et les panneaux du bas) : plus le viewport est haut, plus l'image 9:16 est nette (la hauteur du viewport devient la largeur de l'image). Avec 560 px de haut, l'image est agrandie 1,9 fois ; avec 900 px, 1,2 fois.
- Le cube de vue (en haut à droite de la vue 3D) tombe dans le haut de l'image : le montage le coupe (`coupe=haut`). S'il est désactivé (menu Affichage), on peut garder le centre (`coupe=centre`).
- La chemise du bacon hair est un fichier local : `python -I TL/make_shirt_baconhair.py ART/_textures/shirt_baconhair.png`, puis copier le PNG dans `%LOCALAPPDATA%\Roblox\Versions\<version de Studio>\content\textures\StealAShopTrailer\` (la version qui contient `RobloxStudioBeta.exe`). À refaire après une mise à jour de Studio.

## 2. Charger l'outil

`execute_luau` (Edit) avec le contenu de `TL/trailer_lib.luau`, puis de `TL/shots.luau`. Les deux définissent `_G.Trailer` (noté `T`), qui reste chargé tant que Studio est ouvert. Recharger `trailer_lib.luau` reprend les acteurs déjà dans `_TRAILER/Actors`.

## 3. Faux joueurs

- `T.actor(id, tenue)` : un PNJ R15 créé par `Players:CreateHumanoidModelFromDescriptionAsync`, scripts retirés, racine ancrée, nom caché. Tenues dans `T.LOOKS` :
  - `bacon` : le bacon hair de départ exact (cheveux Pal Hair 63690008, chemise maison veste noire ouverte et t-shirt bleu à moto, jean vert foncé 144076760, peau beige comme les vigiles) ;
  - `bacon_guitare`, `bacon_jean` : d'autres tenues de départ de Roblox, pour que la foule ne soit pas faite de clones.
- `T.actor(id, "guard:Guard_Z1")` : copie d'un vigile de `ReplicatedStorage/Assets/Guards`.
- Un id par rôle et par plan (`casseur`, `voleur`, `vigile`…) : un acteur qui n'est pas dans le plan en cours est rangé sous la carte par `T.prepare`.
- Animations par leur nom : `a:play("HitWindow", { looped = false })`. L'outil cherche dans le dossier `Animations` du modèle, puis dans `Assets/Animations/Player`, puis les animations R15 de base (`Run`, `Walk`, `Idle`). `CarryRun` (haut du corps, priorité Action) se joue par-dessus `Run`.
- En Edit, les animations n'avancent pas seules : le moteur appelle `Animator:StepAnimations(dt)` à chaque image (animateur par animateur : l'éditeur d'animation de Clément n'est pas touché). Les marqueurs (`Impact`…) ne sont pas lus pendant ces pas : prévoir un repli sur une fraction de la durée (`HitWindow` dure 0,4 s, l'impact est pris à 40 %).
- Déplacement : `a:follow(chemin, t)` avec `chemin = { {t0, Vector3}, {t1, Vector3}, … }` ; le perso est posé sur le sol (raycast) et regarde où il va. 16 studs/s pour une course.
- Accessoires : `T.fx.carry(a, "ITM_…", échelle)` (objet au-dessus de la tête), `T.fx.hold(a, "TOOL_…")` (outil dans la main droite).
- Décor et véhicules : `T.fx.prop(S, "cle", "Events", "ENV_Event_Truck_Legendary")` copie un modèle d'`Assets/<dossier>` dans `_TRAILER/Props` (gardé d'une prise à l'autre, rangé sous la carte s'il n'est pas dans le plan) ; `T.fx.setOn(modèle, point, direction)` le pose par le bas. `T.fx.emit("FX_Collect_Bill", cf)` émet une fois un effet d'`Assets/FX`.

## 4. Écrire un plan

Dans `TL/shots.luau`, sur le modèle des plans existants :

```lua
T.shots.mon_plan = {
	dur = 3,   -- secondes de vidéo
	slow = 2,  -- prise jouée 2 fois plus lentement, accélérée au montage
	cam = M.travelling({ from = V(...), look = V(...), dir = "avant", dist = 8, dur = 3, ease = "linear", fov = 45 }),
	setup = function(S) S.actors.p1 = T.actor("mon_role", "bacon") ... end,
	update = function(S, t, dt) S.actors.p1:follow(CHEMIN, t) ... end,
}
```

Effets : `table.insert(S.fx, T.fx.breakWindow(magasin))` dans `update` au moment de l'impact (la vitre est cachée en local et ses éclats volent vers la rue ; `T.stop()` remet tout). Une secousse : `M.shake(cam, { atKey = "breakAt", ... })` et `S.breakAt = t` au même moment.

## 5. Repérer un cadrage

**Planche de tous les plans** (vérifié le 2026-11-24, 21 plans en 35 s) :
1. Construire d'avance tous les acteurs et décors : appeler `setup` de chaque plan sur un `S` vide (`{ actors = {}, fx = {}, props = {}, t = 0 }`), puis attendre 1,5 s que les animations se chargent.
2. `T.prepare(premier plan)` (noir tenu), lancer une capture de 65 s à 10 i/s, vérifier le `.mkv`, puis dans un seul `execute_luau` : pour chaque plan, `T.still(nom, 0)`, `task.wait(1.1)`, `T._black(true)`, `task.wait(0.45)` ; enfin `T.stop()`.
3. `python -I SK/scripts/planche_reperage.py prise.mkv planche.jpg nom1,nom2,… 7` : une image par plan, son nom dessous.
4. Corriger un cadrage raté sur une image fixe : `T.still(nom, t)` (le plan posé à l'instant t, sans noir), une capture de l'écran, puis `T.stop()`.

**Repérage fidèle d'un moment d'action** (vérifié le 2026-11-25, 48 images en 76 s) : `T.stillAt(nom, t)` JOUE le plan image par image de 0 à t (animations, éclats, objet lâché, vol plané, lissage de la caméra) puis le tient. Pour chaque plan, deux images : `T.stillAt(nom, 0)` et `T.stillAt(nom, T.KEY_NATUREL[nom])` (l'instant clé), séparées par `T._black(true)`. La première image de la capture se perd souvent (la capture démarre 1 à 2 s après) : attendre 2 s avant la première.

**Troupe construite d'avance** (série naturelle) : `T.prebuildNaturel()` crée les 18 acteurs et les 30 décors en 5 s, puis précharger les animations de chacun (`a:track(nom)` pour toutes celles des plans) et attendre 2 s : sinon la première frappe d'un plan joue une piste vide.

**Un seul cadrage, à la main** :
1. `T.peek(pos, cible, fov, true)` : pose la caméra tournée (comme au tournage).
2. Capture de l'écran : `ffmpeg -f gdigrab -framerate 1 -offset_x 0 -offset_y 0 -video_size 1920x1080 -draw_mouse 0 -i desktop -frames:v 1 repere.png`, puis la regarder (Read). L'image est couchée : la tourner de 90° vers la gauche pour juger (`ffmpeg -i repere.png -vf transpose=2 repere_debout.png`).
3. Corriger, recommencer. `T.unpeek()` remet la vue de Clément.

La capture `screen_capture` du MCP sort blanche en 3D sur ce PC : passer par l'écran (mémoire `studio-visual-capture`).

## 6. Filmer

Pour chaque plan :

1. **Rien devant la vue 3D ?** La prise filme l'écran : une autre fenêtre (navigateur, WhatsApp, Bloc-notes, Roblox Player) ou une notification Windows sur la région est filmée à la place du jeu. `pwsh -NoProfile -File SK/scripts/vue_libre.ps1 x y w h 20` demande à Windows quel programme est sous 9 points de la région, sans capture, et attend jusqu'à 20 s qu'une notification parte. La fenêtre au premier plan ne suffit pas : la session Claude peut être devant, sur l'autre écran, sans rien couvrir. Si la vue reste couverte, demander à Clément de remettre Studio devant.
2. `T.prepare("nom")` (Edit) : construit, pose la première image et la **tient en noir** jusqu'à `T.go()` (aucune course contre la montre). Rend la durée de prise et la taille du viewport.
3. Repérer la vue 3D pendant le noir : capture de l'écran (étape 5.2) puis `python -I SK/scripts/find_viewport.py ecran.png <largeur> <hauteur>` → `x y w h` (inutile si les panneaux de Studio n'ont pas bougé).
4. Lancer la prise **en arrière-plan** : `bash SK/scripts/capture.sh <scratchpad>/rush/nom.mkv <durée> x y w h`, avec durée = celle donnée par `T.prepare` + **25 s**. Entre le début de la capture et l'arrivée de `T.go()` dans Studio, il passe de 2 à 12 s (lancement en arrière-plan, puis appel au MCP) : une capture courte s'arrête avant la fin du plan. Le noir tenu par `T.prepare` remplit l'attente et le montage recoupe sur les noirs.
5. **Vérifier que la prise a démarré** (`ls` du `.mkv` : le fichier existe) avant `T.go()`. Un `T.go()` envoyé en même temps que la capture rate l'écran noir, et la synchro est perdue.
5 bis. Ne pas préparer le plan suivant avant la fin de la capture en cours : son noir se collerait à la fin de la prise et fausserait la fin du plan au montage.
6. `T.go()` (Edit). Le moteur fait 1,5 s de noir, joue le plan, refait 0,5 s de noir, puis `T.stop()` remet la caméra de Clément, `ShowDevelopmentGui` et la vitrine. On peut attendre la fin dans le même appel : `while T.state.phase ~= "done" do task.wait(0.2) end` (Studio continue de rendre pendant `task.wait`).
7. `T.state.fps` donne le nombre d'images par seconde rendues par Studio pendant le plan (31 à 108 le 2026-11-24) : au-dessous de 30, augmenter `slow`.

**Par lots** (le plus rapide, vérifié le 2026-11-24 : 17 plans en trois lots, puis 21 en 16:9 en deux lots) : `T.prepare(premier plan)`, capture de (somme des prises + 25 s), vérifier le `.mkv`, puis `T.batch({ "plan1", "plan2", … })` dans un seul `execute_luau` (jusqu'à 11 plans, environ 90 s). Découpe : `python -I SK/scripts/decoupe_lot.py prise.mkv dossier plan1,plan2,… 2 1 2` (ralenti, 1 = 9:16 ou 0 = 16:9, étalonnage). Pour du 16:9, mettre `roll = false` sur les plans avant le lot, et le remettre après.

Après chaque étape (repérage, lot), `save_place` (mémoire studio-save-preview-work) ; à la fin, `T.clear()` puis `save_place`.

## 7. Monter et exporter

`bash SK/scripts/montage_plan.sh <scratchpad>/rush/nom.mkv ART/<date>_<sujet>/nom.mp4 <slow> haut`

- Synchro sur les deux noirs, accélération × `slow`, image redressée (`transpose=2`), recadrage 9:16, 1080 × 1920, 30 i/s, étalonnage léger, sans son. Une miniature `nom.jpg` est écrite à côté.
- Étalonnage : `grade=1` (par défaut) ou `grade=2` (un peu plus de contraste, vignette légère). Jamais plus sombre : notre identité est claire et saturée (DA).
- Trailer en 16:9 (session trailer de lancement) : plans avec `roll = false`, et montage sans `transpose` ni recadrage 9:16 (`trim`, `setpts=(PTS-STARTPTS)/slow`, `scale=1920:1080`).
- Regarder la miniature (Read), puis envoyer la vidéo à Clément (SendUserFile).
- Pour une rafale de plusieurs plans : couper chaque plan sur la grille de 1/3, 1/2, 2/3 ou 1 s (`-ss`, `-t`), puis `concat` ; les textes et la musique se font avec l'agent `video-tiktok`.
- Fichiers vidéo hors Git ; dans le dépôt, seulement les scripts et les découpages.

## 6 bis. Plans fidèles au jeu (couche `T.real`, vérifié le 2026-11-25)

- Charger `trailer_lib.luau`, `shots_naturels.luau` (troupe), `trailer_real.luau`, puis `shots_teaser.luau`.
- **Étiquettes dans un plan tourné** : une BillboardGui reste alignée sur l'écran, donc couchée après `transpose=2`. `T.real.rotBB` tourne son contenu de 90°, permute sa taille et passe ses décalages en repère monde ; toute BillboardGui ajoutée sous `_TRAILER` ou sur un Attachment du Terrain pendant un plan l'est automatiquement.
- **Écrans** (RUN!, SMASHED!, CAUGHT!, bords verts, minuterie) : dans `CoreGui/_TrailerUI`, un cadre tourné de 90° qui couvre exactement l'image 9:16 gardée (la partie gauche du viewport, 1286 × 724). Ils se cachent pendant les noirs, sinon les plans d'un lot se collent au découpage.
- **Vérifier** : la capture du MCP (`screen_capture`) marche en Edit sans Studio devant, mais ne montre ni les étiquettes ni les écrans ; pour eux, une capture `gdigrab` de la vue.
- **Bruitages** : chaque événement note son son (`T.real.sfx`) ; après le tournage, `T.real.sfxJson()` → fichier JSON → `python -I SK/scripts/mix_sfx.py journal.json <dossier des plans> <banque> plan=fichier,…`.
- Les écrans du jeu livrés transparents (le code les anime, comme `UI_HUD.HeistTimer`) sortent vides : refaire le texte soi-même (GothamBlack, contour sombre).

## 6 ter. Vraie partie en Play (accord de Clément)

- Le compte DEV de Clément casse une vitrine en un coup (dégâts 100 000) et court à 85 : c'est le vrai jeu, pas celui d'un nouveau joueur.
- Couper seulement la musique côté Client, à chaque image (`RenderStepped`, sons `MUS_*`), garder les bruitages.
- Jouer par le MCP : équiper l'outil par `Humanoid:EquipTool` (le clic sur la barre d'outils ne l'équipe pas toujours), viser la vitrine avec `WorldToViewportPoint` puis `user_mouse_input`, se déplacer par `Humanoid:MoveTo` (la navigation du MCP ne trouve pas de chemin dans un magasin), maintenir E pour un colis.
- Filmer en même temps `capture.sh` (60 i/s, vue du Play : 1808 × 724 en (3, 108) le 2026-11-25) et `video_capture` du MCP (25 i/s, mais avec le son). Caler les deux par la courbe de luminance moyenne (corrélation), puis poser le son du MCP sur l'image à 60 i/s. Sortie 16:9 par recadrage au centre (1288 × 724).

## 7 bis. Banque de sons (dans un Play, accord de Clément)

Vérifié le 2026-11-25 (122 sons en 18 prises, environ 12 min) :
1. Dans le Play, côté Client : couper la musique et l'ambiance **à chaque image** (`RenderStepped` qui remet `Volume = 0` sur tout son qui joue hors de nos copies). Les couper une seule fois ne suffit pas : le contrôleur de musique du jeu les remet en fondu, et le fond est remonté à −30 dB sur les derniers lots.
2. Ranger les 120 sons d'`Assets/Sounds` en lots de 25 s au plus (6 s au plus par son, 0,9 s de silence entre deux).
3. Pour chaque lot : `video_capture` (début), puis un `execute_luau` qui attend 1 s et joue les sons du lot un par un (copie dans `SoundService`, `Play`, attente, `Stop`) et rend « Dossier/Nom@début+durée;… », puis `video_capture` (fin). Noter « chemin de la vidéo|résultat » dans `lots.txt`.
4. `python -I SK/scripts/banque_sons.py lots.txt <dossier>` : cale tous les débuts d'un lot sur la courbe d'attaque de la piste (décalage cherché entre 0,85 et 1,7 s), puis écrit un `<Nom>.wav` par son (48 kHz, fondu de fin 0,12 s).
5. Les musiques (`Assets/Music`) : un extrait de 25 s par prise, `TimePosition` posé au départ.

Les prises du MCP sont dans `%LOCALAPPDATA%\Roblox\tmp-capture-storage\mcp\<id>\` ; elles restent après l'arrêt du Play.

## 8. Nettoyer

- `T.clear()` : supprime `Workspace/_TRAILER` (acteurs, accessoires, effets) et remet ce qui reste.
- Vérifier : `workspace:FindFirstChild("_TRAILER") == nil`, la vue de Clément est revenue, `StarterGui.ShowDevelopmentGui == true`.
- `save_place`.

## 9. Pannes connues

| Ce qu'on voit | Cause | Solution |
| --- | --- | --- |
| Image blanche en 3D | `screen_capture` du MCP | Capture de l'écran par ffmpeg (`gdigrab`) |
| Le HUD du jeu par-dessus la vue | `StarterGui` affiché en Edit | `T.prepare` coupe `ShowDevelopmentGui` ; `T.stop` le remet |
| Un perso reste figé | Animation pas encore chargée (`Length = 0`) | Construire les acteurs avant (`setup` à vide), attendre 1 s |
| Le plan ne commence pas au bon moment | Prise lancée après `T.go()` | Toujours lancer la prise d'abord ; le noir de 1,5 s laisse la marge |
| « pas d'écran noir dans la prise » | La fenêtre de Studio était couverte, ou la région est fausse | Refaire `find_viewport.py` ; garder Studio devant |
| Saccades | Studio rend moins de 30 images par seconde | `slow = 3` ou 4 |
| Une autre fenêtre ou une notification passe dans l'image | La capture filme l'écran | Vérifier le premier plan avant chaque prise (étape 6.1). Si une prise a filmé une autre fenêtre, la supprimer aussitôt sans la regarder ni la garder (elle peut montrer ce que fait quelqu'un d'autre), et refilmer |
| L'image est couchée, ou droite alors qu'on voulait la tourner | Studio redresse sa caméra à chaque image en Edit | Le roulis est reposé à chaque image par `BindToRenderStep` (priorité Last + 100) : `T.prepare`, `T.go` et `T.peek` le font. Ne pas poser `Camera.CFrame` à la main pour un cadrage tourné |
| Les sélections d'un collaborateur s'affichent | Option « Afficher les sélections du collaborateur » | Demander à Clément de la décocher le temps du tournage |
| Les Trails ne se voient pas | Roblox ne les dessine pas en Edit | Pour un trail, il faut un Play (accord de Clément) |
| Un point blanc et deux traits fins sur la scène (au centre, ou posés au sol) | Le repère de visée de la caméra de Studio (type `Fixed`), apparu le 2026-11-25 | `T.prepare` et `T.peek` passent la caméra en `Scriptable` pendant le plan ; `T.stop` et `T.unpeek` remettent le type d'origine |
| `capture.sh` refuse la prise (« width not divisible by 2 ») | Viewport de largeur impaire (1525 px) | Capturer 1 px de moins (1524) |
| Un plan sombre (magasin de jeux vidéo) manque sur la planche | La planche coupe sur les noirs : un intérieur sombre passe pour du noir | Repérer ce plan à part : `T.stillAt` espacés de 2,5 s, capture à 2 i/s, une image sur deux |
