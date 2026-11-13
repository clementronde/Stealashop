# Tests en jeu à faire (2026-11-13 au soir)

Ce qui a été poussé le 13/11 vers 20 h (e0e3f16). Pour chaque test : ce que tu fais → ce que tu dois voir. Note ce qui coince.

**Avant de commencer** : relance le Play (un Play déjà lancé garde l'ancien code).

## 1. Le vigile garde l'objet tombé
1. Prends un objet dans un magasin, sors, et laisse le vigile t'attraper dans la rue. → L'objet tombe, et le vigile va se poster à côté de l'objet au lieu de rentrer.
2. Attends sans toucher à l'objet. → Le vigile reste à côté pendant 15 s. L'objet repart vers son rayon, puis seulement le vigile rentre.
3. Recommence, mais reprends l'objet avant 15 s (après ton étourdissement). → Le même vigile te poursuit tout de suite. Aucun autre vigile ne sort du magasin, et le vigile ne reste jamais coincé derrière la vitrine.
4. Même chose avec un 2e joueur qui reprend l'objet. → Le vigile poursuit celui qui l'a pris.

## 2. « HEIST » et « RUN! »
1. Casse une vitrine. → « HEIST: 13s » en haut au centre.
2. Prends un objet. → « RUN! » s'affiche et « HEIST » disparaît : jamais les deux en même temps.
3. Lâche l'objet (G) ou fais-toi attraper avant la fin du chrono. → « HEIST » ne revient pas pour ce vol.
4. Casse une autre vitrine plus tard. → « HEIST » s'affiche de nouveau, normalement.

## 3. Intrus à la fin du chrono
1. Casse une vitrine, entre, et reste dans le magasin sans rien prendre jusqu'à la fin du chrono. → Un vigile sort et te poursuit.
2. Fuis sans objet. → Au bout d'environ 10 s, le vigile lâche, souffle, puis rentre.
3. Recommence, et cette fois prends un objet pendant ces 10 s. → La poursuite ne s'arrête plus (comme un vol normal), jusqu'à la zone safe ou la capture.

## 4. Bandeau de zone
1. Passe une arche sans rien d'autre à l'écran. → Le bandeau s'affiche comme avant, avec « Speed 22 » et « Damage 40K » (mot + chiffre).
2. Vole un objet en zone 2 ou 3 et fuis vers le hub en passant les arches. → Aucun bandeau de zone pendant « RUN! », même une fois la poursuite finie.
3. Pendant un « HEIST » affiché (le tien, ou en passant près d'un magasin cassé), passe une arche. → Rien tout de suite ; le bandeau de la zone s'affiche à la fin du chrono si tu y es toujours.
4. Bandeau affiché, casse vite une vitrine (ou fais-toi poursuivre). → Le bandeau s'efface aussitôt.
5. Avec un 2e joueur qui vole ta boutique, passe des arches pendant l'alerte rouge. → Aucun bandeau par-dessus l'alerte.

## 5. Ouverture d'un colis (pas vérifié par Claude)
1. Ouvre un colis sur le rayon (reste appuyé sur E) et regarde le haut du colis pendant que « ×N LUCK » monte. → Dis si « ×N LUCK » recouvre le nom du colis (« Premium Box »…). Si oui, on cachera le nom dès le début de l'ouverture.

## 6. Attrapé dans le magasin (ajouté plus tard le 13/11 au soir)
1. Prends un objet sur un rayon et reste dans le magasin jusqu'à ce que le vigile t'attrape. → L'objet ne tombe pas : il revole tout de suite sur son rayon. Le vigile rentre au fond du magasin, s'efface, et le rideau se baisse comme d'habitude.
2. Même chose, mais fais-toi attraper dans la rue. → Rien ne change : l'objet tombe et le vigile reste à côté (partie 1).

## 7. Son du Claim hors ligne (ajouté le 13/11 vers 22 h, L-097)
1. Dans la barre de commande (serveur) : `workspace:SetAttribute("OfflineTest", "<ton pseudo> 3600")`, puis attends l'écran des gains hors ligne. → L'écran s'ouvre avec la somme.
2. Clique Claim. → Tu entends `Offline_Claim` au clic, puis `Cash_Collect` quand l'argent arrive dans le total.
3. Dis si l'enchaînement des deux sons te va (trop proches, trop forts…).

## 8. Fin du tuto : voler le bot (ajouté le 13/11 vers 22 h, L-085 et L-136)
Vu par Claude jusqu'à l'étape 12 seulement : ton profil DEV a l'inventaire plein, donc le vol était refusé. Il faut un joueur qui fait le tuto depuis le début **avec de la place dans l'inventaire** (un compte qui n'a jamais joué au jeu, ou un profil dont tu as libéré une place), et le bot doit être dans le serveur.
1. Va jusqu'à la fin du bouclier débutant (étape 10). → Bulle « Steal from another shop! » et flèches vers la porte de la boutique du bot.
2. Approche de la porte du bot. → Bulle « Break in and grab an item! ».
3. Casse la porte et prends un objet du bot. → Bulle « Bring it back to your shop! ».
4. Rapporte l'objet chez toi. → Le tuto est fini, plus aucune bulle.
5. Recommence, mais perds l'objet en route (lâche-le avec G ou fais-toi attraper). → Retour à « Break in and grab an item! ».
6. Sans bot dans le serveur. → Le tuto finit comme avant, juste après le bouclier, sans ces trois étapes.
7. Quitte et reviens après avoir fini le tuto. → Il ne recommence pas.
