# Tests en jeu à faire (2026-11-13)

**Résultat (Cantin, 2026-11-13 au soir)** : tout passe, plus les pastilles « ! », l'antivol visible (chaînes) et les mutations (une vue de près). Seul le Claim All de l'Index n'a pas pu être testé (aucune zone complète) : à tester par Claude dans Studio. Bandeau de zone : Cantin veut revenir à « Speed 22 » (L-132).

Tout ce que Cantin a demandé depuis le 12/11 et qui n'a pas encore été vu en Play, pas à pas. Pour chaque test : ce qu'on fait, puis ce qu'on doit voir. Cocher au fur et à mesure et noter ce qui coince.

**Avant de commencer**
- Relancer le Play (un Play déjà lancé garde l'ancien code).
- Ton inventaire est plein : 58 objets non exposés pour 30 places, parce que tes colis rangés sont devenus des objets. Vends au moins 30 objets au receleur, sinon un objet volé revole vers son rayon en arrivant en base.
- Tests à deux joueurs : le bot ne reçoit pas d'alerte. Il faut deux vrais joueurs (Studio → Test → 2 joueurs, ou toi avec Clément).

## 1. Magasin PNJ : ouvrir, prendre, fuir

Déjà vérifié par Claude en Play : un appui bref n'ouvre rien, un maintien de 0,3 s ouvre un colis Standard, et la prise de l'objet fait sortir un vigile.
1. **Ouvrir en restant appuyé** : casse une vitrine, entre, fais un appui bref sur E devant un colis. → Rien ne s'ouvre.
2. Reste appuyé sur E. → L'invite se remplit (0,3 s pour un Standard, 0,6 s pour un Premium, 1 s pour un Luxe), puis les rabats ou le couvercle se lèvent et la lumière sort.
3. **Compteur de chance** : ouvre plusieurs colis. → « ×N LUCK » monte en 2 s au plus. Avec ×1, l'objet sort tout de suite. Le colis grandit avec la chance.
4. **Étiquette des colis** : regarde les colis sur le rayon. → On ne voit que la rareté de la caisse : ni la catégorie de l'objet, ni la mutation.
5. **Sortie de l'objet** : → L'objet apparaît à la place du colis, avec son nom, sa rareté, sa mutation s'il en a une, et son revenu par seconde. À partir d'Épique, un voile de couleur passe sur l'écran.
6. **Aucun vigile à l'ouverture** : ouvre un colis sans prendre l'objet. → Aucun vigile ne sort.
7. **Vigile à la prise** : prends l'objet (maintien de E). → Un vigile sort tout de suite et te poursuit, et l'objet flotte au-dessus de ta tête.
8. **Objet réservé** : avec un 2e joueur, ouvre un colis. → Pendant 5 s, l'autre joueur n'a pas d'invite pour prendre l'objet, puis il peut le prendre.

## 2. Vigile, capture et objet lâché

1. **Lâcher** : en portant un objet, appuie sur G (sur téléphone : le bouton « Drop »). → L'objet tombe à tes pieds, avec son nom sur l'invite « Grab ». Le vigile arrête de te poursuivre et va vers l'objet.
2. Reprends l'objet. → Le même vigile te poursuit de nouveau.
3. Laisse l'objet 15 s au sol sans y toucher. → Il revole vers son rayon et le vigile rentre.
4. **Capture dehors** : laisse le vigile t'attraper dans la rue. → L'objet tombe, et le vigile rentre vers son magasin.
5. Reprends l'objet, ou fais-le reprendre par un 2e joueur, avant 15 s. → Le vigile fait demi-tour et poursuit celui qui a l'objet. S'il avait déjà disparu, un vigile ressort du magasin.
6. **Capture dans le magasin** : reste dans le magasin jusqu'à ce que le vigile t'attrape. → Après le coup (2,4 s), tu es sorti devant la vitrine, et le rideau est baissé pour toi.
7. Essaie de rentrer, puis d'ouvrir un colis. → Tu es ressorti, et l'ouverture est refusée.
8. **Jauge du vigile** : pendant une poursuite. → Plus de jauge de distance au vigile ; « RUN! » et les battements de cœur restent.

## 3. Entrer et ressortir sans objet

1. Casse une vitrine, entre, puis ressors sans rien prendre avant la fin du chrono de 13 s. → Le chrono disparaît tout de suite et le rideau est baissé pour toi.
2. Attends la fin du chrono dehors. → Aucun vigile ne sort pour toi, et le rideau ne se relève pas chez toi.
3. Recommence en restant dedans jusqu'à la fin du chrono. → Un vigile sort pour toi.

## 4. Base : antivol (après avoir vendu au receleur)

1. Rentre en base avec un objet volé. → « Item secured! » : l'objet est dans ton inventaire.
2. Pose-le au sol de ta boutique (inventaire → PLACE). → Au-dessus, de près, son nom à la couleur de sa rareté et le temps qui défile (5 s pour un Commun, jusqu'à 180 s pour un Divine).
3. Pendant le décompte, essaie de le mettre sur un présentoir. → Refusé.
4. À la fin. → « UNLOCKED! », puis l'invite « Display » le met sur un présentoir.
5. **Vol pendant l'antivol** (2 joueurs) : l'autre joueur casse ta porte et appuie sur « Steal » sur l'objet au sol. → Il le prend. Chez lui, l'objet repart avec un antivol complet.

## 5. Potions

1. Ramasse une potion dans le couloir. → Pas d'effet tout de suite, et le message « … potion added to your inventory! ».
2. Inventaire, onglet Potions. → Une carte par type, avec le nombre (« SPEED POTION x2 ») et un bouton « USE ».
3. Appuie sur USE. → L'effet démarre et le nombre baisse.
4. Ramasse une 6e potion du même type. → Elle reste par terre, avec un message « full (5/5) ».

## 6. Braquer un autre joueur (2 vrais joueurs)

1. Casse la porte de l'autre joueur. → Aucun chrono pour toi, et le panneau de sa boutique affiche « OPEN ».
2. Côté victime. → L'alerte « TOI IS STEALING YOUR SHOP! », la sirène et la flèche arrivent dès la casse, avant même que tu prennes un objet.
3. Reste plus de 40 s dans sa boutique. → La porte reste cassée et tu peux toujours voler.
4. Ressors les mains vides. → La porte se répare, au plus tôt 30 s après la casse.
5. La victime te frappe à la batte dans sa boutique. → Tu es sorti, et tu ne peux plus voler cette boutique pendant 60 s.

## 7. Tapis et banc

Déjà vérifié par Claude en Play : on monte sur le tapis 0,02 s après être entré dans la zone.
1. Approche-toi du tapis. → Tu te mets à courir tout de suite, sans 1 à 2 s d'attente, et l'animation de course tourne en boucle.
2. Sur le tapis, appuie sur une touche de déplacement, ou bouge le joystick sur téléphone. → Tu sors du tapis dès le premier mouvement.
3. Reviens sur la bande du tapis. → Tu remontes tout de suite.
4. Approche-toi du banc. → Tu te mets à soulever tout de suite. Bouger ne fait rien, et un saut te fait descendre (comme avant).

## 8. Tutoriel (nouveau déroulé)

Hook DEV : `workspace:SetAttribute("TutorialReset", <ton UserId>)`. À la fin, ton profil reste au tutoriel recommencé : prévenir Claude pour le remettre comme avant.
1. Casse la vitrine de la Supérette. → La bulle et la flèche montrent un colis.
2. Ouvre-le. → « ×1.50 LUCK », puis le Pot de nouilles sort, avec l'indice « Grab your item and run! ».
3. Prends-le et rentre. → En zone safe, l'indice « place it on the floor ».
4. Pose-le. → 5 s d'antivol, puis « UNLOCKED! » et l'invite Display.
5. Mets-le sur un présentoir, puis encaisse. → Le tuto passe à l'entraînement.
