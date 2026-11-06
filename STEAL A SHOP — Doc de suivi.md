# SMASH A SHOP — Doc de suivi

Nov 6, 2026 · @Clément RONDEPIERRE

## 1. Pitch & TL;DR

**Smash a Shop** (titre de travail) est un « Steal a … » à 6 joueurs : on casse la vitrine de magasins PNJ, on vole un colis mystère en 10 secondes, on sème le vigile, et l'objet déballé rapporte de l'argent par seconde dans sa propre boutique. Les 5 autres joueurs peuvent braquer cette boutique à leur tour.

**La boucle en une phrase** : s'entraîner → casser une vitrine → voler un colis → semer le vigile → déballer → exposer → encaisser → améliorer → braquer plus loin, ou braquer un joueur.

| Élément | Choix |
| --- | --- |
| Genre | Tycoon de parcelle « Steal a … » (référence : Steal an Egg) + braquage |
| Joueurs par serveur | 6, une parcelle-boutique chacun |
| Plateforme prioritaire | Mobile d'abord : tap sur la vitre, UI au pouce, perf sur téléphone d'entrée de gamme |
| Public visé | 9–15 ans, sessions de 15 à 30 min, retour quotidien |
| Lancement visé | MVP public le vendredi 18 décembre 2026 (début des vacances de Noël), puis une mise à jour par semaine |

**Ce qui nous différencie du jeu de référence**

1. **La casse** : on ne vole pas en un clic. On tape la vitrine le plus vite possible contre ses PV, puis elle explose en éclats. C'est le moment signature du jeu.
2. **Le colis mystère** : on vole une boîte sans savoir ce qu'elle contient. Le déballage en base est un second pic de plaisir.
3. **La poursuite** : le vigile rend la vitesse concrète. On sent physiquement si on est assez rapide pour la zone.
4. **Le PvP lisible** : chacun voit les vitrines et les $/s des autres. La victime défend à la batte et investit dans des défenses (vitres, caméras, pièges, rideau).

**Règle de propriété intellectuelle** : on reprend la mécanique de genre, jamais les noms, modèles, sons ou UI du jeu de référence. Le titre est à vérifier sur Roblox avant publication (alternatives : Rob a Shop, Smash & Grab Tycoon).

## 2. Équipe & règles de collaboration

Ironix possède tout ce qui s'exécute (code, systèmes, intégration, publication). Clément possède tout ce qui se voit en 3D (map, modèles, textures, rendus). Chaque tâche a un seul propriétaire, même quand l'autre aide.

| Domaine | Propriétaire | Livrable attendu | L'autre fournit |
| --- | --- | --- | --- |
| Code Luau serveur + client | Ironix | Scripts dans Git, synchronisés par Rojo | — |
| Greybox de la map (blocs) | Ironix | Map jouable en blocs gris, distances finales | Clément valide les volumes |
| Map finale, parcelles, magasins PNJ | Clément | Modèles dans Team Create, contrat d'intégration respecté (section 10) | Ironix branche les scripts |
| Objets, colis, outils, batte | Clément | MeshParts nommés + attachments | Ironix fournit la liste et les raretés |
| Vitres pré-fracturées + fissures | Clément | 3 tailles de vitre fracturée + 3 textures de fissure | Ironix code la casse |
| Vigiles | Clément | Accessoires sur rig R15 standard (pas de rig custom) | Ironix code l'IA |
| VFX | Ironix | Particules et effets intégrés | Clément fait les textures de particules |
| UI | Ironix | UI fonctionnelle, mobile d'abord | Clément fait les icônes d'objets (rendus 3D) |
| Sons | Ironix | Sélection Creator Store + intégration | — |
| Équilibrage | Ironix | Valeurs dans `Config/Balance` | Validation à deux en playtest |
| Page du jeu | Ironix | Description, gamepasses, paramètres | Clément fait l'icône et les miniatures |

Deux sujets restent à attribuer (animations, maquettes UI) : voir section 15.

**Outils et emplacements**

- **Places Roblox** : une place DEV (Team Create, on casse ce qu'on veut) et une place PROD (publiée uniquement par Ironix).
- **Code** : GitHub privé + Rojo. Branche `main` protégée, une branche par tâche nommée avec l'ID (`dev/DEV-018-vigile`).
- **Sources 3D** : fichiers `.blend` dans un drive partagé, `/Art/<Catégorie>/<Nom>.blend`, export `.fbx` à côté.
- **Livraison d'un modèle** : Clément dépose dans `Workspace/_INBOX_CLEMENT`, passe la tâche en « En revue ». Ironix vérifie le contrat d'intégration, puis range dans `ReplicatedStorage/Assets/<Catégorie>`.
- **Communication** : Discord, un salon par pôle + `#bugs`. Ce doc est la source de vérité : une décision non écrite ici n'existe pas.

**Définition de « fini »**

- **Tâche dev** : marche en test multi-clients (2 joueurs minimum), zéro erreur en sortie, chaque remote validé côté serveur, valeurs dans `Config`, testé dans l'émulateur mobile.
- **Tâche modèle** : budget de triangles, nommage, pivot et attachments conformes à la section 10, testé en jeu à côté d'un perso R15, collisions réglées.

**Rituels**

- **Lundi, 15 min** : on choisit les tâches de la semaine dans les backlogs (sections 12 et 13).
- **Jeudi, 30 min** : playtest à deux, chaque bug devient une ligne de backlog.
- **Dimanche** : chacun met à jour ses statuts dans ce doc.

## 3. Boucle de jeu

&#91;embedded content: boucle de jeu · 8 étapes, 1 échec, couche PvP\]

Un braquage complet dure environ 30 s en zone 1 et 1 min en zone 6 ; le déballage tourne pendant qu'on repart. La casse est en couleur parce que c'est le moment signature : c'est là qu'on met le plus de soin.

**Les 10 premières minutes** (onboarding sans mur de texte, uniquement des flèches et des objectifs)

1. **0:00** : arrivée sur sa parcelle (stand vide). Flèche au sol vers la Supérette, à 60 studs.
2. **0:15** : premiers coups aux poings sur la vitre (35 PV). Fissures et son qui monte.
3. **0:25** : casse + chrono de 10 s. Le premier colis est forcément Premium, le vigile du tuto est lent.
4. **0:45** : retour en zone safe, colis posé sur l'établi. Déballage tuto de 5 s, objet Rare garanti.
5. **1:00** : objet posé sur un présentoir, son billboard affiche 5 $/s. Premier encaissement.
6. **2:00** : le tapis et le banc s'allument, 30 s d'entraînement guidé.
7. **3:00** : assez d'argent pour la clé à molette (300 $), flèche vers le magasin d'outils.
8. **5:00** : objectif affiché, la zone 2 (vitesse conseillée 22, dégâts conseillés 10).
9. **10:00** : fin du bouclier débutant. Message « Ta boutique est maintenant braquable » + premier niveau de vitrine offert.

## 4. Carte & zones

La map est une seule rue droite : la zone safe (6 parcelles) au départ, puis 6 zones de magasins de plus en plus loin. Plus la zone est loin, plus le retour est long : c'est ce qui rend la vitesse indispensable. Le MVP sort avec les zones 1 à 4 (8 magasins) ; les zones 5 et 6 arrivent en mise à jour.

**Layout**

- **Zone safe** : carré de 240 × 240 studs. 6 parcelles de 64 × 80 studs, 3 de chaque côté d'une allée centrale de 60 studs. De porte à porte : 80 studs minimum (face à face), environ 180 studs maximum (diagonale).
- **Dans la zone safe** : spawn au centre de l'allée, magasin d'outils et receleur à l'entrée de l'allée, panneaux de classement.
- **Limite safe** : arche « ZONE SAFE » + ligne au sol, une seule sortie vers le boulevard. Les vigiles PNJ ne la franchissent jamais. Le PvP reste possible entre parcelles.
- **Boulevard** : 40 studs de large, un magasin PNJ de chaque côté par zone (12 magasins au total). Rue droite : depuis la zone safe on voit les magasins lointains, c'est l'objectif sous les yeux.
- **Arche de zone** : à l'entrée de chaque zone, « Zone 3 · Vitesse conseillée 28 · Dégâts conseillés 80 ».

| Zone | Magasins PNJ | PV vitre | Dégâts/coup conseillés | Vitesse conseillée (WalkSpeed) | Vitesse du vigile | Distance de retour (studs) | Revenu de base ($/s, Commun) | Jalon |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Supérette, Kiosque | 35 | 1 | 16 | 13,4 | 60 | 1 | MVP |
| 2 | Magasin de jouets, Confiserie | 350 | 10 | 22 | 18,8 | 140 | 8 | MVP |
| 3 | Électronique, Jeux vidéo | 2 800 | 80 | 28 | 24,2 | 240 | 60 | MVP |
| 4 | Bijouterie, Horlogerie | 21 000 | 600 | 34 | 29,6 | 360 | 450 | MVP |
| 5 | Galerie d'art, Antiquaire | 175 000 | 5 000 | 40 | 35 | 500 | 3 500 | MAJ 1 |
| 6 | Banque, Salle des coffres | 1 400 000 | 40 000 | 48 | 42,2 | 660 | 25 000 | MAJ 2 |

**D'où viennent ces chiffres** (valeurs V0, toutes dans `Config/Zones`) :

- **PV vitre = 35 × dégâts conseillés** : à 7 coups/s et avec la régénération de 3 % des PV/s, la vitre casse en 6 s environ.
- **Vitesse du vigile = 0,9 × vitesse conseillée − 1** : à la vitesse conseillée, on le distance même avec le malus de portage (−10 %). Un peu en dessous, on s'en sort parfois : c'est voulu.
- **Retour à vitesse conseillée** : 4 s en zone 1, 15 s en zone 6.

## 5. Systèmes de jeu détaillés

Chaque système donne sa règle et ses valeurs V0 ; les formules d'économie sont regroupées en section 7, le PvP en section 6.

### 5.1 Stats et entraînement

Deux stats permanentes, entraînées dans sa propre parcelle.

| Stat | Machine | Gain | Effet en jeu |
| --- | --- | --- | --- |
| Vitesse | Tapis de course | +1 par seconde × multiplicateur du tapis | WalkSpeed = 16 + Vitesse × 0,05, plafonné à 70 |
| Force | Banc de musculation | +1 par répétition (1 tap, 3 rép/s max) × multiplicateur du banc | Dégâts × (1 + Force / 100) |

- **Tapis** : invite « Courir », le perso est placé sur le tapis, animation de course, la bande défile. AFK autorisé (bon pour le temps de jeu) ; taper l'écran donne +50 % de gain.
- **Banc** : invite « Soulever », une répétition animée par tap, chiffre flottant « +1 Force ».
- **Plafond de 70** : au-delà, collisions et caméra deviennent instables sur Roblox.
- **Cible d'équilibrage** : passer d'une zone à la suivante demande environ 5 min d'entraînement et 5 min de revenus.

### 5.2 Outils et dégâts

- **Hotbar** : slot 1 = outil de casse équipé, slot 2 = batte. On garde tous les outils achetés, on en équipe un.
- **Coup** : 1 tap = 1 coup, portée 8 studs. Plafond serveur de 10 coups/s : les autoclickers sont tolérés mais pas avantagés au-delà.
- **Réactivité** : le client joue tout de suite l'animation, le son et les mini-éclats. Le serveur valide, applique les PV et les renvoie à tous.
- Formule des dégâts et table des outils : section 7.

### 5.3 Braquer un magasin PNJ

1. **Approche** : un panneau au-dessus de la vitrine affiche nom, PV, dégâts et vitesse conseillés. Chiffres verts si le joueur les atteint, orange entre 50 et 99 %, rouges en dessous.
2. **Frappe** : barre de PV au-dessus de la vitre, régénération continue de 3 % des PV max par seconde, fissures visibles à 75, 50 et 25 %.
3. **Casse** : à 0 PV, séquence de casse (5.4) et chrono de 10 s affiché en grand.
4. **Pillage** : 10 colis par magasin. 6 Standard sur les rayons avant (prise en 0,3 s), 3 Premium au milieu (0,6 s), 1 Luxe dans la réserve du fond (1,0 s). Un seul colis porté à la fois.
5. **Fuite** : dès qu'un colis est soulevé, le vigile sort de la réserve (5.5). Le chrono ne compte plus pour ce joueur.
6. **Fermeture** : à 10 s, le rideau métallique tombe. Les joueurs encore dedans sans colis sont éjectés devant l'entrée.
7. **Reconstruction** : vitrine et rayons reviennent 20 s après la fermeture, avec un nouveau tirage de colis.
8. **Multijoueur (proposition, à valider en section 15)** : la vitrine est partagée. Une fois cassée, tout le monde peut entrer pendant les 10 s ; le casseur a 1 s d'avance exclusive.

### 5.4 Le moment de la casse

C'est la séquence des miniatures et des vidéos : priorité absolue en qualité.

- **Pendant les coups** : son de verre dont la hauteur monte quand les PV baissent, léger tremblement caméra, chiffre de dégâts flottant, mini-éclats au point d'impact, fissures progressives.
- **À la casse** : arrêt sur image de 60 ms, flash blanc de 80 ms, tremblement caméra de 0,25 s, texte « CASSÉ ! ».
- **Les éclats** : la vitre intacte disparaît, la version pré-fracturée (30 à 40 éclats) apparaît à sa place. Chaque éclat part depuis le point d'impact avec une rotation aléatoire, rebondit au sol, puis s'efface en 1,2 s après 1,5 s.
- **Le son** : 3 couches (impact sourd, éclatement, cliquetis des morceaux qui retombent), hauteur variable de ±10 %.
- **Particules** : paillettes de verre + poussière.
- **Technique** : tout est simulé côté client ; le serveur envoie seulement « vitrine X cassée au point P ». Les éclats ignorent les joueurs (groupe de collision). Version à 10 éclats sur mobile faible ou au-delà de 2 casses simultanées.

### 5.5 Le vigile et la poursuite

- **Apparition** : à la porte de la réserve, au moment où un colis est soulevé. Un vigile par voleur, 3 max par magasin.
- **Vitesse** : table de la section 4.
- **IA** : course directe si ligne de vue, sinon PathfindingService recalculé toutes les 0,3 s. Le serveur possède la physique du vigile.
- **Capture** : distance ≤ 4 studs, vérifiée côté serveur. Le colis revole vers son rayon, le joueur est étourdi 1,5 s, message « Rattrapé ! Vitesse conseillée : 28 ».
- **Abandon** : le joueur passe l'arche safe, ou 20 s de poursuite, ou 120 studs d'avance. Le vigile rentre en marchant, essoufflé.
- **Tension** : jauge de distance vigile/joueur au bord de l'écran, battements de cœur sous 10 studs.
- **Visuel** : un look par zone (gilet de supérette jusqu'à agent de banque), mêmes scripts.
- **P1** : comportements par zone (chien en zone 4, taser à distance en zone 6).

### 5.6 Porter un colis

- Le colis se fixe au-dessus de la tête (attachment `CarryAttachment` soudé à la tête, sans masse).
- Malus de vitesse de −10 %. Saut autorisé. Impossible d'équiper un outil ou la batte.
- Mort, déconnexion ou anomalie anti-triche : le colis retourne à son magasin.
- En zone safe, le colis passe dans les mains ; le joueur le pose sur un établi d'ouverture de sa boutique.

### 5.7 Le déballage

- **Le contenu est tiré par le serveur au moment du vol** et stocké dans la sauvegarde. Le déballage ne fait que le révéler.
- **Durée** : Standard 15 s, Premium 60 s, Luxe 180 s, multipliée par (1 + 0,5 × (zone − 1)). Un Luxe de zone 6 prend 10 min 30.
- **Le minuteur continue hors ligne** (horodatage serveur) : on revient pour ouvrir.
- Un colis en déballage est **volable**, comme un objet exposé.
- **Révélation** : zoom caméra, le colis tremble 1,5 s, le couvercle saute, lumière de la couleur de la rareté, l'objet monte en tournant avec nom, rareté et $/s. Confettis dès Épique, annonce serveur dès Légendaire, son unique pour Secret.
- **Accélérer** : produit Robux « Ouvrir maintenant » (section 8).

### 5.8 Présentoirs, revenus et caisse

- **Présentoirs** : 4 au départ, +1 par amélioration, 20 max en V1. Chaque objet exposé rapporte son revenu en $/s.
- **Billboard** au-dessus de chaque objet, visible par tous : nom, rareté (couleur), $/s. C'est ce qui attire les voleurs.
- **Caisse** : l'argent produit s'accumule dans la caisse. Le joueur marche sur le tapis de caisse pour encaisser, ce qui le ramène en base, donc en défense.
- L'argent en caisse n'est **pas volable** : seuls les objets et les colis le sont.
- **Inventaire** : 30 objets non exposés maximum. Le receleur rachète un objet 120 × son $/s.

### 5.9 PNJ de la zone safe

- **Magasin d'outils** : vend les outils de casse et affiche le gain de dégâts avant achat.
- **Receleur** : rachète les objets ; ses répliques donnent le ton humoristique du jeu.

## 6. PvP & défenses

Toute boutique se braque avec la même mécanique que les magasins PNJ. La victime est prévenue en plein écran et récupère son objet si elle frappe le voleur à la batte avant qu'il atteigne sa propre boutique.

### 6.1 Voler un joueur

1. **Repérage** : à 15 studs d'une boutique, un panneau affiche le propriétaire, la valeur exposée (« 12,4 K$/s ») et les PV de la vitrine.
2. **Frappe** : même système que les PNJ (PV, régénération 3 %/s). Si la victime a une caméra niveau 1, elle reçoit « Quelqu'un frappe ta vitrine ! » dès le premier coup.
3. **Casse** : 10 s pour prendre un objet exposé ou un colis en déballage (prise en 1,0 s). Les pièges de la boutique s'activent.
4. **Fuite** : l'objet est sur la tête du voleur, avec un contour rouge visible par tous. Malus de vitesse de −25 % (au lieu de −10 % pour un colis PNJ), car les boutiques sont proches.
5. **Réussite** : le voleur entre dans la zone de dépôt de SA boutique. L'objet passe définitivement dans son inventaire.
6. **Échec** : coup de batte de la victime, mort ou déconnexion du voleur, ou déconnexion de la victime. L'objet revient à son présentoir d'origine.

### 6.2 Défendre à la batte

- **Alerte** : bannière rouge plein écran « \[Pseudo\] VOLE TON \[Objet\] ! FRAPPE-LE ! », sirène, flèche permanente vers le voleur, voleur surligné à travers les murs.
- **Réaction** : la batte s'équipe automatiquement. Bonus Adrénaline de +25 % de vitesse jusqu'à la fin de la poursuite.
- **Coup** : portée 7 studs, recharge 0,8 s, validé par le serveur. Un seul coup réussi suffit : le voleur est étourdi 2 s, l'objet revole en arc vers son présentoir.
- **Qui peut frapper** : le propriétaire seul en V1 (proposition, section 15).
- **Retour base** : bouton gratuit, recharge 90 s, interdit en portant quelque chose. Il permet de rentrer défendre depuis le boulevard.

### 6.3 Défenses achetables

| Défense | Effet | Niveaux et coût V0 | Jalon |
| --- | --- | --- | --- |
| Vitrine | PV : 100, 1 000, 8 000, 60 000, 500 000, 4 M, 30 M, 250 M | Gratuit, 2 K, 25 K, 300 K, 4 M, 50 M, 600 M, 8 Md $ | MVP |
| Alarme | Alerte quand ta vitrine casse | Gratuite, de base | MVP |
| Caméras | N1 : alerte dès le 1er coup. N2 : voleur surligné 30 s. N3 : flèche, distance et son spatialisé | 5 K, 150 K, 5 M $ | N1 MVP, N2–N3 P1 |
| Rideau métallique | Bouton dans la boutique : vitrine invulnérable 30 s, recharge 180 s, impossible si un voleur est dedans | 60 s pour 50 K $, 90 s pour 1 M $ | MVP |
| Coffre-fort | Présentoirs non volables | 1 gratuit, +1 à 250 K $, +1 à 25 M $ | MVP |
| Pièges | Derrière la vitrine, recharge 45 s. Peau de banane (glissade 1,5 s), colle (−60 % de vitesse 3 s), trappe (éjecte dehors), laser (étourdit 2 s), filet (immobilise 3 s) | 1 emplacement par niveau de boutique, 4 max | Banane et colle P1, autres P2 |
| Régénération vitrine | +1 % des PV/s par niveau (base 3 %) | 5 niveaux | P1 |

Avec la régénération, une vitrine ne peut être cassée que par un joueur qui fait au moins 0,43 % de ses PV par coup. Le PvP se joue donc naturellement entre joueurs de niveau proche.

### 6.4 Règles anti-frustration (non négociables)

Le vol d'objets est le cœur émotionnel du genre, mais aussi la première cause d'abandon le premier jour. Ces règles protègent les nouveaux joueurs.

- **Bouclier débutant** : boutique inviolable pendant les 10 premières minutes de jeu cumulées.
- **Immunité après un vol subi** : 120 s de vitrine invulnérable.
- **Pas de racket** : impossible de voler un joueur dont la valeur exposée est inférieure à 10 % de la tienne.
- **Coffre-fort** : au moins 1 objet est toujours à l'abri.
- **L'argent n'est jamais volé** : seulement les objets et les colis.
- **Transfert sûr** : l'objet ne change de propriétaire qu'au dépôt, avec les deux joueurs connectés. Toute déconnexion annule le vol.

## 7. Économie & équilibrage V0

Toutes les valeurs vivent dans `ReplicatedStorage/Shared/Config` et se règlent sans toucher au code. Cible de rythme : 6 à 8 h de jeu pour atteindre la zone 6, avant le premier rebirth. Ce sont des valeurs de départ, ajustées en bêta avec les données de la section 14.

### 7.1 Formules

```latex
\text{Dégâts par coup} = P_{\text{outil}} \times \left(1 + \frac{\text{Force}}{100}\right) \times M_{\text{puissance}}
```

```latex
\text{Revenu d'un objet (\$/s)} = R_{\text{zone}} \times M_{\text{rareté}} \times M_{\text{mutation}} \times M_{\text{global}}
```

```latex
\text{Coût du niveau } n = C_0 \times g^{\,n}
```

- R zone : table de la section 4. M global : bonus cumulés (rebirth, gamepass, groupe, amis, Premium).
- Exemple zone 3 : Marteau (20) × Force 100 (×2) × multiplicateur ×2 = 80 dégâts, soit exactement les dégâts conseillés.

### 7.2 Outils de casse

Un outil coûte environ 3 à 7 min de revenus de la zone précédente.

| Outil | Puissance | Prix | Zone visée | Jalon |
| --- | --- | --- | --- | --- |
| Poings | 1 | Gratuit | 1 | MVP |
| Clé à molette | 3 | 300 $ | 2 | MVP |
| Pied-de-biche | 8 | 8 000 $ | 2–3 | MVP |
| Marteau | 20 | 120 K$ | 3 | MVP |
| Masse | 50 | 2 M$ | 4 | MVP |
| Hache d'incendie | 125 | 30 M$ | 5 | MAJ 1 |
| Disqueuse | 300 | 400 M$ | 6 | MAJ 2 |
| Marteau-piqueur | 750 | 5 Md$ | Après la zone 6 | P2 |
| Bélier | 2 000 | 60 Md$ | Après rebirth | P2 |

### 7.3 Raretés et colis

La boîte montre son type, jamais son contenu : Standard = carton brun, Premium = carton bleu scellé, Luxe = caisse en bois cerclée d'or.

| Rareté | Couleur | Multiplicateur de revenu | Colis Standard | Colis Premium | Colis Luxe |
| --- | --- | --- | --- | --- | --- |
| Commun | Gris | ×1 | 70 % | 35 % | 0 % |
| Peu commun | Vert | ×2 | 22 % | 35 % | 25 % |
| Rare | Bleu | ×5 | 7 % | 20 % | 40 % |
| Épique | Violet | ×15 | 1 % | 8 % | 25 % |
| Légendaire | Or | ×50 | 0 % | 1,8 % | 8 % |
| Mythique | Rouge | ×200 | 0 % | 0,2 % | 1,8 % |
| Secret | Arc-en-ciel animé | ×1 000 | 0 % | 0 % | 0,2 % |

**Mutations (P1)** : tirées au vol en plus de la rareté. Or ×2 (2 %), Diamant ×5 (0,5 %), Néon ×10 (0,1 %). Côté modèle, c'est un changement de matériau, pas un nouveau mesh.

### 7.4 Améliorations de base

| Amélioration | Effet par niveau | Niveaux V1 | C0 (1er niveau) | g |
| --- | --- | --- | --- | --- |
| Multiplicateur de puissance | +0,5 (de ×1 à ×11) | 20 | 300 $ | 2,0 |
| Tapis de course | +0,5 au multiplicateur de gain de vitesse | 20 | 200 $ | 1,9 |
| Banc de musculation | +0,5 au multiplicateur de gain de force | 20 | 200 $ | 1,9 |
| Présentoirs | +1 (de 4 à 20) | 16 | 500 $ | 2,5 |
| Établis d'ouverture | +1 (de 1 à 4) | 3 | 2 000 $ | 12 |
| Niveau de boutique | Stand, Boutique, Magasin, Concept store, Flagship (+1 emplacement de piège chacun) | 4 | 10 000 $ | 25 |

Coûts des défenses : table de la section 6.3.

### 7.5 Sources et puits d'argent

- **Sources** : objets exposés (l'essentiel), récompenses quotidiennes, récompenses de temps de jeu, codes.
- **Puits** : outils, améliorations, défenses, niveaux de boutique, rebirth.
- **Règle** : aucun prix ni gain ne vient du client. Le serveur lit `Config` et calcule tout.

## 8. Monétisation & rétention

On monétise le confort, la vitesse de progression et l'émotion du moment (vol subi, colis rare), jamais l'accès au contenu. Les prix sont des points de départ à tester.

### 8.1 Gamepasses (achat unique)

| Gamepass | Effet | Prix (Robux) | Jalon |
| --- | --- | --- | --- |
| ×2 Argent | Double tous les revenus | 449 | MVP |
| ×2 Entraînement | Double les gains du tapis et du banc | 299 | MVP |
| VIP | Tag dans le chat, +1 coffre-fort, rideau +30 s, +10 % de revenus | 249 | MVP |
| Encaissement auto | La caisse se vide toute seule, même loin de la base | 199 | MVP |
| Déballage rapide | Tous les déballages 2 fois plus courts | 299 | MVP |
| +4 présentoirs | 4 présentoirs au-delà du maximum | 349 | P1 |
| Gants hydrauliques | Outil exclusif : puissance = 2,5 × ton meilleur outil acheté | 499 | P1 |

### 8.2 Produits développeur (achats répétables)

| Produit | Effet | Prix (Robux) | Jalon |
| --- | --- | --- | --- |
| Ouvrir maintenant | Termine un déballage | 19 à 99 selon le temps restant | MVP |
| Packs d'argent | 10, 60 ou 300 min de tes revenus actuels | 49, 199, 799 | MVP |
| Rideau instantané | Ferme ta boutique sans attendre la recharge | 29 | MVP |
| Vengeance | Téléporte derrière le voleur pendant une poursuite | 25 | MVP |
| Pack de départ | Offre unique la 1re heure : ×2 argent 1 h + Marteau + 50 000 $ | 99 | P1 |
| Chance ×3 | Raretés boostées pendant 15 min, cotes affichées | 79 | P1 |
| Bouclier 30 min | Boutique inviolable, une fois par session | 99 | P1 |

**Règles Roblox à respecter**

- **Pas de colis contre Robux en V1** : un objet aléatoire payant oblige à afficher les probabilités et il est restreint dans certains pays. Pour « Chance ×3 » : afficher les cotes et masquer l'offre si `PolicyService` renvoie `ArePaidRandomItemsRestricted`.
- **Bonus Premium** : +10 % de revenus pour les abonnés Roblox Premium, ce qui augmente les Premium Payouts.
- **Achats** : traités côté serveur et idempotents (section 9).

### 8.3 Rétention

| Levier | Règle | Jalon |
| --- | --- | --- |
| Récompenses quotidiennes | 7 jours en boucle, jour 7 = colis Luxe garanti Épique ou mieux | MVP |
| Récompenses de temps de jeu | À 5, 15, 30 et 60 min de session : argent, puis colis | MVP |
| Social | Groupe Roblox rejoint : +10 % de revenus. Ami dans le serveur : +10 % par ami, +30 % max | MVP |
| Codes | Un code sur Discord et les réseaux à chaque mise à jour | MVP |
| Notifications | « Ton colis Luxe est prêt » via les notifications d'expérience Roblox | P1 |
| Index des objets | Collection par zone ; zone complète = +5 % de revenus permanents | P1 |
| Classements globaux | $/s, vols réussis, défenses réussies | P1 |
| Événements live | « Nuit des soldes » : vitrines PNJ à −50 % de PV pendant 10 min, toutes les heures. Événement admin en direct chaque semaine | P1 |
| Rebirth « Nouvelle enseigne » | Condition : 1 Md $ + 1 objet Légendaire exposé. Remet à zéro argent, outils, stats et améliorations ; garde 3 objets au choix et l'index. Donne +50 % de revenus permanents (cumulable) et +1 coffre-fort | MAJ 2 |

**Rythme des mises à jour** : une par semaine, même jour, même heure (proposition : samedi 16 h à Paris, 10 h à New York), avec un compte à rebours visible en jeu.

## 9. Spécifications techniques (Ironix)

Le serveur fait autorité sur tout ce qui touche à l'argent, aux PV, aux stats et aux objets ; le client ne fait que demander et afficher.

### 9.1 Stack

- **Langage** : Luau en mode strict (`--!strict`), Rojo 7, GitHub, Wally pour les dépendances.
- **Sauvegarde** : ProfileStore (verrou de session, pas de duplication entre serveurs).
- **Réseau** : RemoteEvent et UnreliableRemoteEvent natifs, tous déclarés dans un module `Net`, avec validation de type et limite de débit par remote.
- **Tests** : mode Studio « Serveur + 2 clients » obligatoire pour toute fonctionnalité PvP.

### 9.2 Arborescence

```text
src/
  server/                 -> ServerScriptService
    Main.server.luau      (charge les services dans l'ordre)
    Services/
  client/                 -> StarterPlayerScripts
    Main.client.luau
    Controllers/
  shared/                 -> ReplicatedStorage/Shared
    Config/   Balance, Zones, Tools, Items, Upgrades, Defenses, Products
    Net/      définition de tous les remotes
    Types/
Modeles (Team Create)     -> ReplicatedStorage/Assets/<Categorie>
```

### 9.3 Services serveur

| Service | Responsabilité |
| --- | --- |
| DataService | Profils ProfileStore, schéma, migrations, sauvegarde |
| PlotService | Attribution et libération des 6 parcelles, chargement de la boutique sauvegardée |
| StatsService | Vitesse, Force, WalkSpeed appliqué par le serveur |
| TrainingService | Tapis et banc : présence, ticks, gains |
| ToolService | Outils possédés, équipement, calcul des dégâts |
| WindowService | PV, régénération, casse, reconstruction ; commun aux PNJ et aux joueurs |
| StoreHeistService | Magasins PNJ : chrono de 10 s, rayons, tirage des colis, rideau |
| GuardService | Vigiles : apparition, IA, capture, abandon |
| CarryService | Port d'un colis ou d'un objet, malus, dépôt, retour en cas d'échec |
| UnboxService | Établis, minuteurs horodatés, révélation |
| DisplayService | Présentoirs, revenus par seconde, caisse, encaissement |
| PvPService | Vol entre joueurs, alerte, batte, protections, transfert d'objet |
| DefenseService | Niveaux de vitrine, caméras, rideau, coffre-fort, pièges |
| ShopService | Achats en argent du jeu (outils, améliorations, défenses) |
| MonetizationService | Gamepasses, produits développeur, ProcessReceipt |
| RewardService | Quotidien, temps de jeu, codes, groupe, amis |
| TelemetryService | Funnel et événements d'économie via AnalyticsService |
| AntiCheatService | Contrôle des déplacements, journal des anomalies |

Contrôleurs client : Input (tap et clic), Hit (prédiction du coup), Shatter, Carry, Unbox (caméra de révélation), Alert, HUD, ShopUI, Sound.

### 9.4 Remotes

| Remote (client vers serveur) | Données | Le serveur vérifie |
| --- | --- | --- |
| HitWindow | windowId | Outil équipé, distance ≤ 10 studs, ≤ 10 coups/s, vitrine cassable (ni bouclier, ni rideau, ni immunité) |
| GrabItem | slotId | Magasin ouvert, joueur dans le volume `Bounds`, mains vides, distance ≤ 8 studs, durée de maintien respectée |
| PlaceBox | benchIndex | Sur sa parcelle, porte un colis, établi libre |
| PlaceItem | itemUid, slotIndex | Possède l'objet, présentoir débloqué et libre |
| SwingBat | — | Recharge 0,8 s, un voleur de SON objet à ≤ 7 studs |
| ToggleShutter | — | Recharge écoulée, aucun voleur dans la boutique |
| BuyItem | catalogId | Prix lu dans `Config`, argent suffisant, prérequis remplis |
| TrainTap | — | Joueur sur une machine, ≤ 3 taps/s au banc, ≤ 6 taps/s au tapis |
| ReturnToBase | — | Recharge 90 s, mains vides |
| ClaimReward | rewardId | Conditions remplies, pas déjà réclamé |

L'encaissement passe par le contact serveur avec le tapis de caisse, sans remote. Serveur vers client : WindowHP (non fiable, 10 Hz max), WindowBroken (id, point d'impact), HeistTimer, ChaseState, TheftAlert, UnboxReveal, Notify.

### 9.5 Schéma de sauvegarde v1

```lua
-- Profil ProfileStore, clé "Player_<UserId>"
{
  Version = 1,
  Cash = 0,
  Stats = { Speed = 0, Strength = 0 },
  Upgrades = { PowerMult = 0, Treadmill = 0, Bench = 0, DisplaySlots = 0, UnboxBenches = 0, ShopLevel = 0 },
  Defenses = { Window = 0, Cameras = 0, Shutter = 0, Vault = 0, Regen = 0, Traps = {} },
  Tools = { Owned = { "Fists" }, Equipped = "Fists" },
  Items = {},     -- [uid] = { Id = "Z3_Smartphone", Mutation = nil, Source = "NPC", At = 0 }
  Display = {},   -- [slotIndex] = uid
  Vault = {},     -- [vaultIndex] = uid
  Boxes = {},     -- [benchIndex] = { Tier = "Luxe", Zone = 3, ItemId = "...", Mutation = nil, EndsAt = 0 }
  Rebirths = 0,
  Index = {},     -- [itemId] = true
  Rewards = { DailyStreak = 0, LastDaily = 0, Codes = {} },
  Lifetime = { Heists = 0, Steals = 0, Defenses = 0, PlaySeconds = 0 },
  Purchases = {}, -- [PurchaseId] = true, idempotence de ProcessReceipt
}
```

### 9.6 Anti-triche

- **Déplacements** : toutes les 0,25 s, le serveur compare la distance parcourue à la vitesse autorisée × 1,25. 3 anomalies en 5 s : retour à la dernière position valide et colis rendu.
- **Téléport ou noclip en portage** : un saut de plus de 30 studs entre deux contrôles rend le colis ou l'objet.
- **WalkSpeed** : calculé et appliqué par le serveur. Une modification côté client est attrapée par le contrôle de déplacement.
- **Rien de sensible ne vient du client** : ni dégâts, ni prix, ni rareté, ni position de dépôt.
- **Objets uniques** : chaque objet a un uid. Un vol PvP retire l'objet de la victime et l'ajoute au voleur dans la même exécution serveur, les deux profils actifs.
- **ProcessReceipt** : on applique l'achat, on enregistre le `PurchaseId` dans le profil, et seulement ensuite on renvoie `PurchaseGranted`.
- **Pas de bannissement automatique en V1** : on journalise, on corrige, on revoit les cas à la main.

### 9.7 Performance

- StreamingEnabled activé ; parcelles et magasins en `ModelStreamingMode = Atomic`.
- Éclats, particules et révélations : côté client uniquement, nettoyés avec Debris.
- Vigiles : 6 actifs maximum par serveur, états Humanoid inutiles désactivés (nage, escalade).
- PV des vitrines : envoyés en non fiable, 10 fois par seconde maximum.
- Test chaque semaine sur un vrai téléphone Android d'entrée de gamme.

## 10. Bible assets (Clément)

Un modèle est livrable quand il respecte 5 règles : échelle en studs, pivot en bas au centre, budget de triangles, nommage, et les pièces nommées que le code attend (contrat d'intégration, 10.4).

### 10.1 Règles techniques

- **Chaîne d'export** : 1 unité Blender = 1 stud. Première tâche (MOD-001) : exporter un cube de 4 × 4 × 4 en `.fbx`, l'importer avec le 3D Importer, vérifier qu'il arrive à 4 × 4 × 4 studs et bien orienté. Noter ici les réglages validés.
- **Repères d'échelle** : un perso R15 fait environ 5 studs de haut. Porte = 4 × 7,5 studs. Rayon de 2 studs de profondeur, 3 étages, étagère du haut à 5 studs maximum.
- **Vitrines standard** : 3 tailles réutilisées partout. S = 8 × 6, M = 12 × 7, L = 16 × 8 studs (largeur × hauteur), épaisseur 0,4 stud. Un modèle fracturé par taille.
- **Pivot** : en bas au centre. Face avant tournée vers la rue (ou vers la caméra pour les objets).
- **Collisions** : `CollisionFidelity = Box` par défaut, `Hull` si la forme compte, `CanCollide` désactivé pour le décor de moins d'1 stud.
- **Textures** : 1024² maximum (objets Légendaire et plus, outils), 512² en standard, 256² pour les petits props. Préférer couleurs et matériaux Roblox ; `SurfaceAppearance` (PBR) seulement à partir de Légendaire.
- **Style** : cartoon low-poly, silhouettes exagérées, couleurs saturées. Un objet se reconnaît à 40 studs et en icône de 64 px. Plus c'est rare, plus ça brille : Commun mat, Légendaire doré avec halo, Secret animé.
- **Vigiles** : rig R15 standard + accessoires modélisés (casquette, gilet, badge, matraque cartoon). Pas de rig custom, pas d'arme réaliste.

### 10.2 Budgets de triangles

| Asset | Budget max (triangles) |
| --- | --- |
| Objet exposé, Commun à Épique | 2 000 |
| Objet exposé, Légendaire et plus | 4 000 |
| Colis | 300 |
| Outil de casse ou batte | 1 500 |
| Accessoire de vigile | 1 000 |
| Vitre fracturée (tous éclats) | 1 500 |
| Magasin PNJ, extérieur | 12 000 |
| Magasin PNJ, intérieur avec rayons | 15 000 |
| Parcelle complète au niveau max | 25 000 |
| Tapis ou banc | 3 000 |
| Prop de décor (lampadaire, voiture, arbre) | 1 500 |

### 10.3 Nommage

Format : `PREFIXE_Zone-ou-Categorie_Nom_Variante`, en PascalCase, sans accents ni espaces.

| Préfixe | Pour | Exemple |
| --- | --- | --- |
| ITM | Objet exposé | `ITM_Z3_Smartphone` |
| BOX | Colis | `BOX_Luxe` |
| TOOL | Outil de casse | `TOOL_PiedDeBiche` |
| STORE | Magasin PNJ | `STORE_Z1_Superette` |
| PLOT | Parcelle et boutique | `PLOT_Shop_L2` |
| WIN | Vitre intacte ou fracturée | `WIN_M_Fractured` |
| ACC | Accessoire de vigile | `ACC_Z1_Casquette` |
| ENV | Décor | `ENV_Lampadaire_A` |
| FX | Texture de particule | `FX_GlassSparkle` |

### 10.4 Contrat d'intégration

Ces noms sont lus par le code : un nom faux = une fonctionnalité qui ne marche pas.

| Modèle | Enfants obligatoires (noms exacts) |
| --- | --- |
| Magasin PNJ `STORE_*` | `Window` (vitre intacte), `WindowFractured` (Model, éclats `Shard_01` à `Shard_40`), `Shutter` (rideau en position ouverte), `Door`, `Bounds` (Part invisible = volume intérieur), `ShelfSlot_01` à `ShelfSlot_10` (Attachments avec attribut `Tier` = Standard, Premium ou Luxe), `GuardSpawn` (Attachment), `SignPart` (support du panneau) |
| Parcelle `PLOT_*` | `Window`, `WindowFractured`, `Shutter`, `ShutterButton`, `DisplaySlot_01` à `_20`, `VaultSlot_01` à `_03`, `UnboxBench_01` à `_04`, `TrapSlot_01` à `_04` (Attachments), `CashPad`, `DepositZone` (Part), `Treadmill`, `Bench`, `NameSign`, `Bounds` |
| Objet `ITM_*` | PrimaryPart nommé `Root` (pivot base centre), attribut `ItemId`, aucun script |
| Colis `BOX_*` | `CarryAttachment` (dessous, au centre), `Lid` (couvercle séparé pour l'animation) |
| Outil `TOOL_*` | `Handle` (MeshPart), `HitPoint` (Attachment à la tête de l'outil, pour les effets) |
| Tapis et banc | `UsePoint` (Attachment où se place le perso), `Belt` (surface qui défile, tapis seulement) |
| Accessoire `ACC_*` | Accessory Roblox standard avec son attachment de corps (`HatAttachment`, `BodyFrontAttachment`, etc.) |

### 10.5 Catalogue d'objets V1

Un objet par rareté et par zone. Le MVP compte 24 objets (zones 1 à 4) + 1 Secret. Chaque objet Légendaire et plus a une petite animation idle (rotation, rebond ou étincelles) : des objets drôles et vivants se partagent en capture.

| Zone | Commun | Peu commun | Rare | Épique | Légendaire | Mythique |
| --- | --- | --- | --- | --- | --- | --- |
| 1 Supérette | Canette de soda | Paquet de chips | Pot de nouilles | Boisson énergisante | Ticket à gratter gagnant | Hot-dog en or |
| 2 Jouets | Canard en plastique | Yo-yo | Voiture télécommandée | Robot jouet | Peluche géante | Figurine holographique |
| 3 Électronique | Écouteurs | Manette | Smartphone | Console portable | PC gamer | Carte graphique en or |
| 4 Bijouterie | Bague | Montre | Collier de perles | Diamant brut | Couronne | Œuf en diamant |
| 5 Galerie | Vase | Buste en marbre | Toile abstraite | Statue dorée | Masque ancien | Météorite |
| 6 Banque | Liasse de billets | Sac de pièces | Lingot d'or | Mallette de billets | Coffre de diamants | Clé du coffre ultime |

Secrets, toutes zones (0,2 % des colis Luxe) : Chat porte-bonheur doré (MVP), Toilettes en or (MAJ 1).

## 11. Roadmap & jalons

Le MVP sort le vendredi 18 décembre 2026, six semaines après le démarrage du lundi 9 novembre ; ensuite, une mise à jour chaque samedi.

&#91;embedded content: roadmap proposée · démarrage le lundi 9 novembre 2026, à valider à deux\]

**Critères de sortie** : on ne passe pas au jalon suivant tant qu'ils ne sont pas tenus.

1. **M0** : Clément édite la map en Team Create, le code se synchronise par Rojo, la sauvegarde fonctionne, le cube de test arrive à la bonne échelle.
2. **M1** : un joueur fait toute la boucle en zone 1 (casse, vol, vigile, déballage, présentoir, caisse) avec les vrais modèles de la Supérette et de la vitre.
3. **M2** : zones 1 à 4 jouables, outils et améliorations achetables ; un testeur atteint la zone 3 en moins d'1 h.
4. **M3** : deux joueurs se volent, se défendent à la batte et utilisent rideau et coffre-fort, sans aucune duplication sur 20 essais.
5. **M4** : la casse et le déballage sont assez beaux pour une vidéo promo ; l'UI marche au pouce.
6. **M5** : achats Robux testés, récompenses quotidiennes actives, funnel visible dans le tableau de bord.
7. **Gel des fonctionnalités** : plus aucune nouveauté, uniquement des corrections.
8. **M6** : 20 à 30 testeurs, zéro bug P0 ouvert, valeurs de `Config` ajustées.
9. **Lancement** : jeu public, icône et miniatures en ligne, Discord et codes prêts.

## 12. Backlog Ironix (DEV)

47 tâches, dont 40 avant le lancement. Ordre de travail = ordre du tableau ; une tâche ne démarre que si ses dépendances sont « Fait ». P0 = bloquant pour le jalon, P1 = important, P2 = plus tard.

| ID | Tâche | Fini quand… | Jalon | Prio | Dépend de | Statut |
| --- | --- | --- | --- | --- | --- | --- |
| DEV-001 | Places DEV et PROD, Team Create, repo GitHub, Rojo | Clément édite la map en Team Create ; `rojo serve` synchronise le code | M0 | P0 | — | À faire |
| DEV-002 | Squelette : chargeur de services et contrôleurs, `Config`, module `Net` | Un service vide démarre côté serveur et client sans erreur | M0 | P0 | DEV-001 | À faire |
| DEV-003 | Greybox : zone safe, 6 parcelles, boulevard, 8 magasins en blocs | On court du spawn à la zone 4 aux distances de la section 4 | M0 | P0 | DEV-001 | À faire |
| DEV-004 | DataService : ProfileStore, schéma v1, migrations | Argent sauvegardé et rechargé ; verrou de session testé sur 2 serveurs | M0 | P0 | DEV-002 | À faire |
| DEV-010 | PlotService : attribution, libération, spawn, panneau du nom | 6 joueurs ont chacun leur parcelle ; un départ libère la place | M1 | P0 | DEV-003, DEV-004 | À faire |
| DEV-011 | StatsService : Vitesse, Force, WalkSpeed serveur | WalkSpeed = 16 + Vitesse × 0,05, plafond 70, appliqué par le serveur | M1 | P0 | DEV-004 | À faire |
| DEV-012 | TrainingService : tapis et banc | Gains × multiplicateurs, AFK au tapis, +50 % au tap, limites de taps | M1 | P0 | DEV-011, MOD-016 | À faire |
| DEV-013 | ToolService : outils, équipement, calcul des dégâts | Dégâts selon la formule 7.1, calculés côté serveur | M1 | P0 | DEV-011 | À faire |
| DEV-014 | WindowService : PV, régénération 3 %/s, casse, reconstruction | Même code pour PNJ et joueurs ; PV synchronisés à 10 Hz | M1 | P0 | DEV-013 | À faire |
| DEV-015 | StoreHeistService : chrono 10 s, rideau, rayons, tirage | 6 Standard, 3 Premium, 1 Luxe ; tirage serveur au vol ; reconstruction à 20 s | M1 | P0 | DEV-014 | À faire |
| DEV-016 | ShatterController : casse côté client | Séquence 5.4 complète, version à 10 éclats sur mobile faible | M1 | P0 | DEV-014, MOD-010 | À faire |
| DEV-017 | CarryService : colis sur la tête, malus, échecs | Mort, déconnexion et anomalie rendent le colis | M1 | P0 | DEV-015 | À faire |
| DEV-018 | GuardService : vigile, poursuite, capture, abandon | Vitesses de la section 4 ; capture ≤ 4 studs vérifiée serveur | M1 | P0 | DEV-017 | À faire |
| DEV-019 | UnboxService : établis, minuteurs horodatés, révélation simple | Le minuteur continue hors ligne ; contenu déjà tiré au vol | M1 | P0 | DEV-017 | À faire |
| DEV-020 | DisplayService : présentoirs, billboards, revenus, caisse | $/s exact, encaissement sur `CashPad`, billboards visibles par tous | M1 | P0 | DEV-019 | À faire |
| DEV-021 | HUD v1 : argent, $/s, Vitesse, Force, dégâts/coup, chrono, PV | Lisible sur écran de téléphone dans l'émulateur | M1 | P0 | DEV-020 | À faire |
| DEV-030 | Config des zones 1 à 4 + panneaux de magasin colorés | Vert, orange ou rouge selon les stats du joueur | M2 | P0 | DEV-015 | À faire |
| DEV-031 | Magasin d'outils : UI et achat serveur | 5 outils MVP achetables, prix lus dans `Config` | M2 | P0 | DEV-013 | À faire |
| DEV-032 | Améliorations : puissance, tapis, banc, présentoirs, établis, niveau de boutique | Coûts C0 × g^n ; panneaux d'achat dans la parcelle | M2 | P0 | DEV-020 | À faire |
| DEV-033 | Onboarding des 10 premières minutes | Flèches, 1er colis Premium, vigile lent, objet Rare garanti | M2 | P0 | DEV-030 | À faire |
| DEV-034 | Receleur et inventaire de 30 objets | Vente à 120 × $/s | M2 | P1 | DEV-020 | À faire |
| DEV-040 | Vitrines de joueurs cassables + panneau de repérage | Réutilise WindowService ; PV selon le niveau de vitrine | M3 | P0 | DEV-014 | À faire |
| DEV-041 | Vol PvP : prise, malus −25 %, dépôt, transfert sûr | Annulé si l'un des deux se déconnecte ; aucune duplication en test | M3 | P0 | DEV-040 | À faire |
| DEV-042 | Alerte victime + Adrénaline | Bannière, sirène, flèche, surbrillance, +25 % de vitesse | M3 | P0 | DEV-041 | À faire |
| DEV-043 | Batte : équipement auto, coup validé serveur, retour de l'objet | Portée 7 studs, recharge 0,8 s, étourdissement 2 s | M3 | P0 | DEV-042 | À faire |
| DEV-044 | Défenses MVP : vitrine 8 niveaux, caméra N1, rideau, coffre-fort | Valeurs de la table 6.3 | M3 | P0 | DEV-040 | À faire |
| DEV-045 | Protections anti-frustration | Les 6 règles de la section 6.4 testées une par une | M3 | P0 | DEV-041 | À faire |
| DEV-046 | Bouton Retour base | Recharge 90 s, interdit en portant | M3 | P0 | DEV-010 | À faire |
| DEV-050 | Révélation de déballage complète | Caméra, lumière de rareté, confettis, annonce serveur | M4 | P0 | DEV-019 | À faire |
| DEV-051 | Sons : sélection Creator Store + intégration | Casse, coups, sirène, caisse, déballage, vigile | M4 | P0 | — | À faire |
| DEV-052 | UI finale, mobile d'abord | Tous les écrans utilisables au pouce, aucun texte coupé | M4 | P0 | DEV-021 | À faire |
| DEV-053 | Retours de frappe : dégâts flottants, fissures, son qui monte | Fissures à 75, 50 et 25 % des PV | M4 | P0 | DEV-016, MOD-011 | À faire |
| DEV-060 | Gamepasses et produits développeur | ProcessReceipt idempotent testé avec des achats de test | M5 | P0 | DEV-004 | À faire |
| DEV-061 | Récompenses quotidiennes et de temps de jeu | Série de 7 jours, remise à zéro correcte à minuit UTC | M5 | P0 | DEV-004 | À faire |
| DEV-062 | Bonus groupe, amis, Premium | Multiplicateurs cumulés dans M global | M5 | P1 | DEV-020 | À faire |
| DEV-063 | TelemetryService : funnel d'onboarding + économie | Les 10 étapes de la section 14 remontent dans le tableau de bord | M5 | P0 | DEV-033 | À faire |
| DEV-070 | AntiCheatService | Speed hack et téléport détectés en test, colis rendu | M6 | P0 | DEV-017 | À faire |
| DEV-071 | Passe performance mobile | Pas de chute sous 30 FPS pendant une casse sur le téléphone de test | M6 | P0 | DEV-016 | À faire |
| DEV-072 | Bêta fermée : 20 à 30 testeurs, réglage de `Config` | Plus aucun bug P0 ouvert | M6 | P0 | M1 à M5 | À faire |
| DEV-073 | Page du jeu, questionnaire de maturité, publication PROD | Jeu public le 18 décembre avec icône et miniatures | M6 | P0 | MOD-043 | À faire |
| DEV-080 | Zone 5 + Hache d'incendie | 2 magasins et 6 objets jouables | MAJ 1 | P1 | MOD-050 | À faire |
| DEV-081 | Mutations Or, Diamant, Néon | Tirées au vol, matériau appliqué, multiplicateur juste | MAJ 1 | P1 | DEV-019 | À faire |
| DEV-082 | Pièges : peau de banane et colle | Recharge 45 s, effets de la table 6.3 | MAJ 1 | P1 | DEV-044, MOD-033 | À faire |
| DEV-083 | Zone 6 + Disqueuse | 2 magasins et 6 objets jouables | MAJ 2 | P1 | MOD-051 | À faire |
| DEV-084 | Rebirth « Nouvelle enseigne » | Conditions et bonus de la section 8.3 | MAJ 2 | P1 | DEV-004 | À faire |
| DEV-085 | Caméras N2 et N3, régénération de vitrine, classements | Valeurs des tables 6.3 et 8.3 | MAJ 3 | P1 | DEV-044 | À faire |
| DEV-086 | Index des objets, notifications, événements live | Index récompensé, « Nuit des soldes » automatique | MAJ 3 | P1 | DEV-020 | À faire |

## 13. Backlog Clément (MOD)

36 tâches, dont 28 avant le lancement. Le 2e magasin de chaque zone est une variante du 1er (enseigne, couleurs, rayons) : on modélise 4 magasins pour le MVP, pas 8. Livraison dans `_INBOX_CLEMENT`, statut « En revue », Ironix valide le contrat 10.4.

| ID | Tâche | Fini quand… | Jalon | Prio | Dépend de | Statut |
| --- | --- | --- | --- | --- | --- | --- |
| MOD-001 | Valider la chaîne Blender vers Studio | Le cube 4 × 4 × 4 arrive à la bonne taille et orientation ; réglages notés en 10.1 | M0 | P0 | DEV-001 | À faire |
| MOD-002 | Planche de style | Palette, 3 objets test et langage visuel des raretés validés à deux | M0 | P0 | — | À faire |
| MOD-010 | Vitre M intacte + pré-fracturée | 30 à 40 éclats `Shard_xx`, ≤ 1 500 triangles, test de casse validé | M1 | P0 | MOD-001 | À faire |
| MOD-011 | 3 textures de fissures (75, 50, 25 %) | Lisibles de loin, calées sur la vitre M | M1 | P0 | MOD-010 | À faire |
| MOD-012 | Magasin zone 1 « Supérette » : extérieur, intérieur, rayons | Contrat 10.4 complet, 10 `ShelfSlot` | M1 | P0 | MOD-001, DEV-003 | À faire |
| MOD-013 | Colis Standard, Premium, Luxe | `Lid` séparé, `CarryAttachment`, ≤ 300 triangles | M1 | P0 | MOD-002 | À faire |
| MOD-014 | 6 objets de la zone 1 | Budgets et nommage 10.2 et 10.3, idle sur Légendaire et Mythique | M1 | P0 | MOD-002 | À faire |
| MOD-015 | Parcelle niveau 1 « Stand » | Tous les points nommés du contrat 10.4 | M1 | P0 | DEV-003 | À faire |
| MOD-016 | Tapis de course et banc, niveau 1 | `UsePoint` et `Belt`, ≤ 3 000 triangles chacun | M1 | P0 | MOD-001 | À faire |
| MOD-017 | Accessoires vigile zone 1 | Casquette + gilet sur rig R15 standard | M1 | P0 | MOD-001 | À faire |
| MOD-018 | Variante zone 1 « Kiosque » | Même structure que la Supérette, enseigne et couleurs différentes | M2 | P1 | MOD-012 | À faire |
| MOD-020 | Magasin zone 2 « Jouets » + variante « Confiserie » | Contrat 10.4 complet | M2 | P0 | MOD-012 | À faire |
| MOD-021 | Magasin zone 3 « Électronique » + variante « Jeux vidéo » | Contrat 10.4 complet | M2 | P0 | MOD-012 | À faire |
| MOD-022 | Magasin zone 4 « Bijouterie » + variante « Horlogerie » | Contrat 10.4 complet | M2 | P0 | MOD-012 | À faire |
| MOD-023 | Vitres S et L intactes + pré-fracturées | Mêmes règles que MOD-010 | M2 | P0 | MOD-010 | À faire |
| MOD-024 | 18 objets des zones 2 à 4 | Budgets, nommage, idle à partir de Légendaire | M2 | P0 | MOD-014 | À faire |
| MOD-025 | Outils : clé à molette, pied-de-biche, marteau, masse + batte | `Handle` + `HitPoint`, ≤ 1 500 triangles | M2 | P0 | MOD-001 | À faire |
| MOD-026 | Boulevard : route, trottoirs, lampadaires, voitures, arbres, arches de zone | ≤ 1 500 triangles par prop, arches avec support de panneau | M2 | P0 | DEV-003 | À faire |
| MOD-027 | Zone safe : sol, arche SAFE, magasin d'outils, receleur, supports de classement | Lisible depuis le spawn | M2 | P0 | DEV-003 | À faire |
| MOD-028 | Accessoires vigiles zones 2 à 4 | Un look distinct par zone | M2 | P1 | MOD-017 | À faire |
| MOD-030 | Parcelle niveaux 2 et 3 (Boutique, Magasin) | Mêmes points nommés, ≤ 25 000 triangles au total | M3 | P0 | MOD-015 | À faire |
| MOD-031 | Vitrines de joueur par niveau | 3 modèles + variantes de matériau couvrant les 8 niveaux | M3 | P0 | MOD-010 | À faire |
| MOD-032 | Caméra de sécurité, bouton et rideau métallique, coffre-fort | Rideau livré en 2 positions (ouvert, fermé) | M3 | P0 | MOD-015 | À faire |
| MOD-040 | Icônes des 25 objets MVP | Rendus 512 × 512, fond transparent, même angle et même lumière | M4 | P0 | MOD-024 | À faire |
| MOD-041 | Textures de particules : éclat de verre, étincelle, confetti, poussière | PNG 256 × 256 sur fond transparent | M4 | P0 | — | À faire |
| MOD-042 | Maquettes UI : HUD, alerte vol, magasin, déballage | Seulement si attribué à Clément (section 15) | M4 | P1 | — | À faire |
| MOD-043 | Icône du jeu + 3 miniatures | Icône 512 × 512, miniatures 1920 × 1080, la casse de vitrine en vedette | M4 | P0 | MOD-012 | À faire |
| MOD-044 | Secret « Chat porte-bonheur doré » | Animé, ≤ 4 000 triangles | M4 | P0 | MOD-002 | À faire |
| MOD-033 | Pièges : peau de banane et colle | Visibles de près, discrets de loin | MAJ 1 | P1 | MOD-015 | À faire |
| MOD-050 | Zone 5 : Galerie + Antiquaire, 6 objets, hache d'incendie | Contrat 10.4 complet | MAJ 1 | P1 | MOD-012 | À faire |
| MOD-052 | Secret « Toilettes en or » | Animé, ≤ 4 000 triangles | MAJ 1 | P1 | MOD-002 | À faire |
| MOD-051 | Zone 6 : Banque + Salle des coffres, 6 objets, disqueuse | Contrat 10.4 complet | MAJ 2 | P1 | MOD-012 | À faire |
| MOD-053 | Tapis et banc niveaux 2 à 5 | Une variante visible par palier | MAJ 2 | P1 | MOD-016 | À faire |
| MOD-054 | Pièges laser, trappe, filet | Visibles de près, discrets de loin | MAJ 3 | P2 | MOD-033 | À faire |
| MOD-055 | Parcelle niveaux 4 et 5 (Concept store, Flagship) | Mêmes points nommés | MAJ 3 | P2 | MOD-030 | À faire |
| MOD-056 | Variantes de matériau des mutations (Or, Diamant, Néon) | Appliquables par script sur n'importe quel objet | MAJ 1 | P1 | MOD-002 | À faire |

## 14. KPIs, analytics & risques

On juge le jeu d'abord sur la rétention J1 et sur le funnel des 10 premières minutes. Si plus d'un joueur sur cinq lâche avant son premier déballage, on corrige l'onboarding avant d'ajouter du contenu.

### 14.1 Indicateurs

Cibles internes, à revoir après 2 semaines de données réelles.

| Indicateur | Cible bêta | Cible 1er mois | Où le lire |
| --- | --- | --- | --- |
| Rétention J1 | ≥ 25 % | ≥ 30 % | Creator Dashboard, Retention |
| Rétention J7 | ≥ 6 % | ≥ 10 % | Creator Dashboard, Retention |
| Durée moyenne de session | ≥ 12 min | ≥ 18 min | Creator Dashboard, Engagement |
| Joueurs qui déballent un objet | ≥ 80 % | ≥ 90 % | Funnel d'onboarding |
| Joueurs payeurs | — | ≥ 2 % | Creator Dashboard, Monetization |

### 14.2 Funnel d'onboarding

Chaque étape est envoyée une seule fois par joueur avec `AnalyticsService:LogOnboardingFunnelStepEvent`.

1. Arrivée sur sa parcelle
2. Premier coup sur une vitrine
3. Première vitrine cassée
4. Premier colis volé
5. Arrivée en zone safe avec le colis
6. Colis posé sur l'établi
7. Premier objet révélé
8. Premier objet exposé
9. Premier encaissement
10. Premier achat d'outil

**Économie** : chaque gain (revenus, quotidien, code, Robux) et chaque dépense (outil, amélioration, défense) part avec `LogEconomyEvent`. **Événements custom** : vol PvP réussi ou raté, capture par un vigile (par zone), achat de défense.

### 14.3 Risques

| Risque | Gravité | Parade | Responsable |
| --- | --- | --- | --- |
| Duplication d'objets lors d'un vol PvP | Critique | Transfert atomique, uid uniques, annulation à la déconnexion, test dédié | Ironix |
| Frustration PvP (volé en étant loin) qui fait fuir dès J1 | Élevée | Règles 6.4, retour base, rideau, alertes caméra | Ironix |
| Exploits de vitesse ou de téléport pendant un vol | Élevée | Contrôles serveur de la section 9.6, colis rendu | Ironix |
| Périmètre trop gros pour le 18 décembre | Élevée | MVP limité aux zones 1 à 4 ; gel des fonctionnalités le 13 décembre, ensuite uniquement des corrections | Les deux |
| Aucun trafic au lancement | Élevée | Plusieurs miniatures testées, budget pub à décider (section 15), codes et Discord prêts le jour J | Les deux |
| Volume d'assets (25 objets, 4 magasins + variantes, 3 niveaux de parcelle) | Moyenne | Low-poly, kits réutilisables, 3 tailles de vitre, vigiles = R15 + accessoires | Clément |
| Performance mobile (éclats, vigiles, streaming) | Moyenne | Éclats côté client limités à 40, version basse, test hebdo sur téléphone réel | Ironix |
| Trop proche du jeu de référence | Moyenne | Noms, modèles, UI et sons 100 % originaux | Les deux |
| Thème du vol mal perçu par la modération | Faible | Ton cartoon, aucune arme réaliste, questionnaire de maturité rempli honnêtement | Ironix |

## 15. Questions ouvertes & journal des décisions

10 décisions restent à prendre. Chacune a une proposition par défaut, appliquée si personne ne tranche avant le jalon indiqué. Une fois tranchée : on coche, et on ajoute une ligne au journal.

- [ ] **Partage des revenus (M0)** : répartition des Robux entre Clément et Ironix, écrite noir sur blanc avant toute publication. Proposition : publier sous un groupe Roblox commun, pour que revenus et droits ne dépendent pas d'un compte perso.
- [ ] **Animations (M0)** : course, frappe, banc, vigile, déballage. Proposition : Clément, avec l'Animation Editor de Studio ; Ironix intègre.
- [ ] **Maquettes UI (M1)** : proposition : Ironix construit l'UI, Clément fournit icônes et habillage (MOD-042 si Clément prend plus).
- [ ] **Vitrine PNJ partagée (M1)** : proposition : oui, tout le monde entre pendant les 10 s, le casseur a 1 s d'avance. Alternative : une instance par joueur, plus calme mais moins drôle.
- [ ] **Minuteur de déballage hors ligne (M1)** : proposition : oui, avec notification « ton colis est prêt ».
- [ ] **Qui peut frapper le voleur (M3)** : proposition V1 : le propriétaire seul. Alternative : tous les joueurs, plus chaotique, avec un risque d'acharnement.
- [ ] **Titre définitif (M4)** : Smash a Shop, Rob a Shop ou autre. Vérifier sur Roblox qu'aucun jeu connu ne porte déjà le nom.
- [ ] **Testeurs bêta (M5)** : qui recrute les 20 à 30 testeurs, et où (Discord, amis, groupe).
- [ ] **Budget publicité au lancement (M6)** : montant pour les publicités Roblox, ou zéro.
- [ ] **Rebirth (avant MAJ 2)** : garder 3 objets au choix, ou repartir de zéro.

**Journal des décisions** (une ligne par décision, la plus récente en haut)

| Date | Décision | Par |
| --- | --- | --- |
| 2026-11-06 | Doc de suivi créé. Périmètre MVP : zones 1 à 4, PvP à la batte, défenses de base ; lancement visé le 18 décembre 2026 | Clément, à valider par Ironix |
