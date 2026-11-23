# Images de la page du jeu (MOD-043)

Agent `.claude/agents/miniaturiste.md`. Base : `docs/claude/notes/brief-icone-miniatures.md` et
`docs/claude/notes/publication-prod.md`. **Rien n'est publié par Claude** : Clément envoie les images sur le Creator
Hub de la place PROD, 3 ou 4 jours avant la sortie (modération).

| Date | Dossier ou fichier | Contenu | État |
| --- | --- | --- | --- |
| 2026-11-21 | [benchmark-2026-11-21.md](benchmark-2026-11-21.md) | Icônes et miniatures de 17 jeux « Steal a … » et assimilés, principes qui reviennent | Fait |
| 2026-11-21 | [2026-11-21_icone/](2026-11-21_icone/note.md) | Croquis des 3 pistes, icône « La casse » v1 et contrôles | v1 faite |
| 2026-11-21 | [2026-11-21_icone/v2/](2026-11-21_icone/v2/note.md) | Icône v2 : la v1 retouchée par ChatGPT, bacon hair avec cagoule, nouvelle masse | Remplacée par la v3 |
| 2026-11-21 | [2026-11-21_icone/v3/](2026-11-21_icone/v3/note.md) | Icône v3 : la v2 avec la tenue bacon hair, des mains, une vraie frappe et une masse plus grosse | **Faite, choisie par Clément** |
| 2026-11-22 | [2026-11-22_analyse-video-miniatures-ia.md](2026-11-22_analyse-video-miniatures-ia.md) | Analyse de la vidéo « How I Make High Quality Roblox Thumbnails with AI » : règles, concepts à tester, méthode | Fait |
| 2026-11-22 | [2026-11-22_miniature-casse-video/](2026-11-22_miniature-casse-video/note.md) | Miniature « la casse » faite avec ces règles : braqueur au sourire menaçant, vigile choqué, Couronne énorme, ciel bleu et herbe ; flèche rouge de Clément depuis le 2026-11-23 | Faite, à valider par Clément |
| 2026-11-23 | [2026-11-23_miniature-avant-apres/](2026-11-23_miniature-avant-apres/note.md) | Miniature avant/après : stand délabré et perso triste (« +$1/s », vraie valeur de la Canette de soda) contre boutique dorée pleine de trésors et perso ravi (« +$999T/s », valeur gonflée), reliés par la flèche de Clément | Faite, à valider par Clément |
| 2026-11-23 | [2026-11-23_ameliorations/](2026-11-23_ameliorations/analyse.md) | Analyse des 38 miniatures de Clément : 7 idées et 3 logos, un verdict par image, 15 miniatures améliorées (texte incrusté retiré par ChatGPT sur 6 images, argent du jeu en arc-en-ciel, flèche de Clément, « !! »), et les 10 à mettre en ligne en premier | **Faites, validées par Clément** |
| 2026-11-23 | [elements/fleche_rouge_clement.png](elements/fleche_rouge_clement.png) | Flèche rouge à contour noir fournie par Clément (512 × 512, fond transparent), posée par `miniature_ia.py` avec `FLECHE_IMAGE` | À utiliser pour les flèches |
| 2026-11-22 | [2026-11-22_blender/](2026-11-22_blender/note.md) | Test d'une chaîne Blender : la miniature 01 rendue avec les vrais modèles du jeu, et sa comparaison avec la version IA | Test fait : moins percutant que l'IA à 320 × 180, la suite est à décider |
| 2026-11-21 | [2026-11-21_logo/](2026-11-21_logo/note.md) | 3 logos « STEAL A SHOP » en PNG transparent, versions fond clair et fond sombre | Gardés en réserve |
| 2026-11-21 | [2026-11-21_logo/embleme/](2026-11-21_logo/embleme/note.md) | Logo sans texte en tuile carrée : le braqueur masqué s'enfuit de la boutique cassée avec une Couronne géante (512 et 1024 px) | **Fait, choisi par Clément** |
| 2026-11-21 | [2026-11-21_miniature-01_casse/](2026-11-21_miniature-01_casse/note.md) | Miniature 01 « SMASH & GRAB! » | v1 faite, remplacée par la v2 |
| 2026-11-21 | [2026-11-21_miniature-01_casse/v2/](2026-11-21_miniature-01_casse/v2/note.md) | Miniature 01 v2 : la scène refaite par ChatGPT avec le perso de l'icône v3, la Couronne sous vitrine | Remplacée par la v3 |
| 2026-11-21 | [2026-11-21_miniature-01_casse/v3/](2026-11-21_miniature-01_casse/v3/note.md) | Miniature 01 v3 : la v2 sans titre, avec l'étiquette `BB_Item` du jeu et la vraie valeur (« +$4.9K/s ») | Faite, gardée en réserve |
| 2026-11-21 | [2026-11-21_miniature-01_casse/v4/](2026-11-21_miniature-01_casse/v4/note.md) | Miniature 01 v4 : la v3 avec seulement la ligne d'argent « +$48.7B/s » en arc-en-ciel et une flèche rouge vers la Couronne ; valeur volontairement gonflée à la demande de Clément | **Faite, choisie par Clément** |
| 2026-11-21 | [2026-11-21_miniature-02_poursuite/](2026-11-21_miniature-02_poursuite/note.md) | Miniature 02, la poursuite : le bacon hair à cagoule fuit avec un gros PC gamer, poursuivi par le vigile ; boutique « SHOP », herbe, ciel bleu ; « +$63.2B/s » au-dessus du PC (valeur gonflée) | Faite selon les demandes de Clément |
| 2026-11-21 | [2026-11-21_miniature-03_boutique/](2026-11-21_miniature-03_boutique/note.md) | Miniature 03, la boutique pleine : le Coffre de diamants au centre, les trésors aux halos de rareté sur les rayons, le perso de dos ; « +$1.2T/s » en arc-en-ciel (valeur gonflée) et une flèche rouge | **Faite, validée par Clément** |

Scripts : `tools/clement/miniatures/` (scène, matte et nettoyage en Luau ; croquis, logos, retouches et contrôles
en Python avec Pillow). Polices : Montserrat, Luckiest Guy et Fredoka One (licence OFL), livrées avec Roblox Studio.

**Note de méthode : retouche par IA**. ChatGPT dans le Chrome de Clément, avec son compte (méthode de l'agent
`planches-chatgpt`). Les prompts sont en anglais et ne donnent pas le nom du jeu. On joint la vraie capture, puis on
demande de garder la scène du jeu. Chaque téléchargement depuis chatgpt.com demande l'accord de Clément. L'image
téléchargée va dans un sous-dossier `chatgpt/`, et `controle_icone.py` la finit en 512 et fait les contrôles.

**Note de méthode : Studio en Edit**. La scène est montée uniquement avec des copies, dans
`workspace.CurrentCamera._MINIATURE_TMP`. Ce qui est masqué l'est par `LocalTransparencyModifier`, que Studio
n'enregistre pas. `StarterGui.ShowDevelopmentGui` passe à false le temps des captures, sinon le HUD s'affiche dans la
capture (accord de Clément du 2026-11-21) ; le script de nettoyage le remet. La fenêtre de Studio doit être au premier
plan, sinon la 3D sort noire. Avant de commencer, demander aux autres sessions de ne pas lancer de Play.
