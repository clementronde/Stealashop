# Séance de tests à deux (environ 1 h) : Cantin et Clément

Préparée par Claude le 2026-11-14, à partir de la section « Tests à faire » de la
[liaison](../../Liaison-Code-Visuel.md) et du code de `main` (7731eb7). Les textes vus dans le jeu restent en anglais.

En bref :

- **Tests à deux ou à plusieurs** : T-003, T-012, T-021, T-024 à T-030, T-038, T-046, T-050 (13 tests).
- **Dans cette séance** : 9 tests. Les 4 autres attendent la vague 40, ou un serveur plein (liste à la fin du déroulé).
- **Tests sur téléphone** : T-031 à T-035, T-048, T-049, plus la partie téléphone de T-038 (section 4).

---

## 1. Avant de commencer (5 min)

### Comment se retrouver dans le même serveur

Un Play dans Studio reste sur le PC de chacun, même en Team Create. « Clients and Servers » lance deux joueurs,
mais sur un seul PC : Clément ne peut pas y entrer. Il faut un vrai serveur Roblox.

**Mise en place retenue (celle des docs, `beta-fermee.md` et `publication-prod.md`) : jouer en ligne sur la place
DEV.**

1. **Cantin** : `git pull`, vérifier que la place DEV a le code voulu (Script Sync), puis dans Studio :
   Fichier > **Publier sur Roblox** (la place DEV, « Steal a Shop [DEV] », place 131580149465482). Sans cette
   publication, les serveurs en ligne gardent l'ancien code.
2. **Les deux**, dans l'appli Roblox sur PC : ouvrir la page de « Steal a Shop [DEV] » (privée : elle s'ouvre pour
   les membres du groupe RoundStone Studio qui y ont accès) et cliquer Play.
3. **Le 2e qui arrive** rejoint l'autre : depuis le profil de l'autre (bouton « Join », il faut être amis Roblox),
   ou depuis l'onglet « Servers » de la page du jeu.
4. Vérifier qu'on se voit dans le hub. Le bot prend une boutique, il y a donc 3 boutiques occupées.

**Ce qui est incertain** :

- **Accès de Cantin à la place DEV en ligne** : son rôle « Dev » lui permet de modifier le jeu. Qu'il puisse aussi
  y jouer en ligne, ce n'est écrit nulle part. Sinon, Clément ouvre l'accès (Creator Hub > Manage Audience, ou les
  droits du rôle).
- **Admin en ligne** : en ligne, est admin un membre du groupe de rang 254 ou plus (`Config/Admin`,
  `MinGroupRank = 254`). **Clément** est propriétaire (rang 255) : il est admin. **Cantin** ne l'est que si son
  rôle « Dev » a un rang de 254 ou plus, et personne n'a vérifié ce rang. Pour le savoir : le bouton admin s'affiche
  dans le HUD de Cantin, ou pas. Sinon, Clément fait les commandes pour lui : chaque commande vise un joueur.
- **Les commandes de test ne marchent pas en ligne** : les attributs `SkillTest`, `FortuneTest`, `NightSkipTo` et
  `TruckSpawnNow` ne sont lus qu'en Studio (`RunService:IsStudio()`). Le panel admin refuse aussi en ligne
  `SetSkill`, `StartEvent` (camion, nuit, Fortune Tower), `GivePotion` et `GiveGamepass`, avec le message
  « Studio only for now. ». En ligne, il reste : `GiveCash`, `GiveSpeed`, `GiveStrength`, `SetTreadmill`, `SetBench`,
  `SetShopLevel`, `SetRayons`, `GiveItem`, `GiveBox`, `GiveAura`, `GiveTrail`, `Teleport`, `ResetProfile`. Une
  compétence s'achète donc dans l'arbre, avec de l'argent du panel.
- **Autre piste, pas prévue dans les docs ni essayée** : Studio, onglet Test > **Team Test**. Il lance un serveur
  Roblox que les collaborateurs du Team Create rejoignent depuis Studio, sans publier. On ne sait pas si les
  commandes « Studio seulement » y marchent. Pour le savoir : panel admin > Events > Night. Si la réponse est
  « Studio only for now. », elles ne marchent pas. Si on essaie, le noter dans la liaison.
- La sauvegarde en ligne est réelle : ce qu'on vend, vole ou achète reste dans les profils DEV.

### Les profils

**Profil DEV de Cantin, aujourd'hui** : 20 présentoirs pleins, un niveau de boutique 5 et un inventaire plein
(58 objets pour 30 places). Avec un inventaire plein, **Cantin ne peut rien prendre** : ni un objet de magasin PNJ,
ni l'objet d'un autre joueur (« Your inventory is full: make room before stealing. »). Ce que ça change :

- Sa boutique pleine fait une très bonne cible : **Clément vole, Cantin se défend.**
- Sans place, T-003 (reprendre l'objet tombé), T-029 (braquer pendant que le magasin est fermé pour l'autre) et
  T-038 (ramener un objet en base) sont impossibles pour Cantin.
- **Proposition** : au début, Cantin va chez le receleur (Pawn Shop du hub) et vend tout son inventaire
  (« tout vendre »). Les objets exposés restent sur les 20 présentoirs. Son profil DEV sera remis à zéro par la
  vague 40 de toute façon. **À Cantin de décider.** S'il refuse, sauter T-003, T-029 et T-038, ou les jouer en
  inversant les rôles quand c'est possible.

**Profil de Clément** : il lui faut de la place dans l'inventaire, de quoi casser la porte de Cantin (environ
500 000 PV : boutique de niveau 5 et Glass niveau 2) et un niveau de boutique 5 pour T-021. Au panel admin, sur
lui-même : `GiveStrength` et `GiveCash` (puis acheter une arme et une aura), `SetShopLevel` 5.

**Si la vague 40 est déjà fusionnée et publiée** : les profils DEV repartent de zéro (a135 : nouvelle DataStore
`PlayerData_DEV_20261114`). Les deux ont alors un profil neuf, le tuto qui démarre, de la place, mais rien
d'exposé. Clément prépare les deux profils au panel admin : `SetShopLevel` 5, `SetRayons` 5, `GiveItem` plusieurs
fois, `GiveCash`. Le banc n'existe plus (`GiveStrength` et `SetBench` sont retirés) : la force vient de l'arme et de
l'aura. Bonus : on peut alors jouer aussi les tests du tuto (T-016 à T-019, T-044), qui demandent un profil neuf.

### Juste avant le premier test

- [ ] Les deux dans le même serveur, dans le hub.
- [ ] Cantin sait s'il est admin. Clément l'est.
- [ ] Inventaire de Cantin vidé chez le receleur (ou décision de ne pas le faire).
- [ ] Clément prêt : force, argent, arme, boutique de niveau 5.
- [ ] Un papier ou ce fichier ouvert pour cocher les cases.

---

## 2. Le déroulé (environ 55 min)

L'ordre suit le terrain : d'abord les boutiques du hub, puis la rue et les arches, puis les magasins PNJ. On ne
relance jamais le serveur.

### A. Boutiques du hub

#### T-021 : caméras seulement avec la compétence Cameras (4 min)

- **Cantin** : il a déjà Cameras (vu par Claude). Il reste dans sa boutique.
- **Clément** : il regarde la boutique de Cantin, puis il va dans la sienne, avec Cameras 0.
- **Ensuite** : Clément achète Cameras niveau 1 dans son arbre de compétences (5 000 $). Cantin regarde la boutique
  de Clément.
- **On doit voir** : Clément voit les caméras chez Cantin (Cantin a Cameras). Chez Clément, pas de caméra tant qu'il
  est à Cameras 0. Après son achat, ses caméras apparaissent chez lui, et Cantin les voit aussi. Les caméras, le
  digicode et le gyrophare ne se voient qu'à partir du niveau 5 de la boutique (L-150, question 7) : Clément doit
  être au niveau 5.
- Résultat : [ ] passé  [ ] raté : ……

#### T-027 : caméras de l'arbre, alerte et surlignage (5 min)

- **Commande** : en ligne, `workspace:SetAttribute("SkillTest", "Player1 Cameras 2")` ne marche pas (Studio
  seulement). À la place, **Cantin achète Cameras niveau 2** dans son arbre (150 000 $ ; Clément lui en donne au
  panel avec `GiveCash` si besoin).
- **Clément** : il frappe une fois la porte de la boutique de Cantin, à la batte ou à l'arme.
- **Cantin** : il reste dans le hub, à distance, et regarde.
- **On doit voir** : chez Cantin, l'alerte part dès le 1er coup. Clément est surligné en bleu, à travers les murs,
  pendant 30 s.
- Résultat : [ ] passé  [ ] raté : ……

#### T-025 : vol entre joueurs, porte, rideau, batte (8 min)

- **Clément** : il casse la porte de la boutique de Cantin, puis le rideau, entre et prend un objet exposé.
- **Cantin** : 1er essai, il le laisse partir et regarde. 2e essai, il le frappe à la batte dans sa boutique.
- **On doit voir** :
  - 1er essai : Clément porte l'objet et le ramène chez lui. Chez Cantin, « Clément stole your … ! ».
  - 2e essai : Clément est sorti de la boutique. Il voit « Kicked out! You can rob this shop again in 60s. ».
    Cantin voit « Clément was kicked out of your shop! ». Sur le panneau de la boutique : « ROB AGAIN IN …s ». Si
    Clément portait un objet, il revient sur son présentoir.
  - Chaque objet n'existe qu'une seule fois : chez Cantin ou chez Clément, jamais chez les deux.
- Résultat : [ ] passé  [ ] raté : ……

#### T-028 : coffre-fort (compétence Safe) (5 min)

- **Cantin** : il a au moins 1 présentoir à l'abri (offert). Il peut acheter Safe niveau 1 (250 000 $) pour en avoir 2.
  Les présentoirs à l'abri sont ceux qui rapportent le plus.
- **Clément** : il entre (attendre la fin des 60 s de T-025) et essaie de prendre l'objet qui rapporte le plus, puis
  un objet moyen.
- **On doit voir** : sur les objets les plus chers, la prise est refusée : « This item is in the safe: nobody can
  steal it. ». L'objet moyen se vole.
- Note : la vague 40 (a141) change la place des présentoirs. Après elle, refaire juste un essai rapide.
- Résultat : [ ] passé  [ ] raté : ……

### B. La rue et les arches

#### T-012 : pas de bandeau de zone par-dessus l'alerte de vol (4 min)

- **Clément** : il vole un objet chez Cantin (comme dans T-025).
- **Cantin** : dès que l'alerte rouge part, il court dans la rue et passe une ou deux arches de zone pendant
  l'alerte.
- **On doit voir** : chez Cantin, aucun bandeau de zone (`UI_ZoneBanner`) ne s'affiche par-dessus l'alerte rouge.
- Résultat : [ ] passé  [ ] raté : ……

### C. Les magasins PNJ (zone 1)

Il faut que Cantin ait de la place dans l'inventaire (receleur, section 1).

#### T-003 : le vigile poursuit celui qui reprend l'objet (6 min)

- **Cantin** : il casse la vitrine d'un magasin de la zone 1, ouvre un colis, prend l'objet, sort du magasin et le
  lâche dans la rue (touche G). Pas dans le magasin : là, l'objet revole sur son rayon (L-150).
- **Clément** : il attend dans la rue. Il reprend l'objet tombé.
- **On doit voir** : le vigile quitte Cantin et poursuit Clément dès qu'il prend l'objet.
- Résultat : [ ] passé  [ ] raté : ……

#### T-029 : magasin fermé pour le voleur seulement (6 min)

- **Cantin** : il braque un magasin PNJ jusqu'au bout. Le magasin se ferme pour lui.
- **Clément** : pendant ce temps, il entre dans le même magasin et le braque.
- **On doit voir** : Cantin ne peut pas y entrer tout de suite. Clément peut y entrer et prendre un objet. Le
  magasin se rouvre ensuite pour Cantin.
- Note : la vague 40 passe le braquage à 6 s (a135). On peut le jouer maintenant, mais refaire un essai rapide
  après la vague 40, car la durée change.
- Résultat : [ ] passé  [ ] raté : ……

#### T-038 (partie PC) : « ESCAPED! » ne touche pas l'alerte de vol (6 min)

- **Cantin** : il prend un objet dans un magasin PNJ et le ramène chez lui.
- **Clément** : pendant le trajet, il vole un objet chez Cantin (Cantin doit avoir l'alerte pendant qu'il porte).
- **On doit voir** : chez Cantin, « ESCAPED! » ne touche plus l'alerte de vol. Le reste du test, à faire par
  Cantin pendant la séance : passer une arche, « Speed 22 » et « Damage 40K » ont la même taille ; 3 messages en bas
  de l'écran à la fois ne touchent ni la colonne de droite ni les cases.
- La partie téléphone est en section 4.
- Résultat : [ ] passé  [ ] raté : ……

#### T-030 : camion cassé à deux (5 min, si le camion passe)

- **En ligne, on ne peut pas faire venir le camion** : `TruckSpawnNow` et `StartEvent` sont Studio seulement. Il
  arrive tout seul toutes les 8 à 12 min. En 1 h, il devrait passer plusieurs fois.
- **Les deux** : à l'annonce du camion, y aller ensemble et le frapper à deux.
- **On doit voir** : la barre de PV du camion baisse chez les deux. Les colis tombent. Chacun peut en prendre et le
  rapporter en zone safe.
- Note : la vague 40 change les PV du camion (100 × les dégâts conseillés de sa zone, a134). Le jeu à deux se
  vérifie quand même maintenant.
- Résultat : [ ] passé  [ ] raté : ……

### Si on manque de temps

Ordre de priorité : **T-025, T-003, T-027, T-012, T-029**, puis T-021, T-028, T-038, T-030.

### Après la vague 40 (pas dans cette séance)

| Test | Pourquoi attendre |
| --- | --- |
| **T-024** : vitesse fixe avec un objet volé, alerte et rattrapage avec l'Adrénaline | La vague 40 change la vitesse de marche (a134 : nouvelle formule, plafond à 70) et les vitesses des zones. Rattraper le voleur « facilement » dépend de ces valeurs. |
| **T-026** : PV de la porte d'une boutique avec Glass et Glass Regen | La vague 40 recalcule les PV (a134 : plus de banc, dégâts = arme × aura, 5 coups par seconde). Les PV de la porte sont à revoir (L-151, question 4). |
| **T-046** : Fortune Tower à deux | Ses PV passent à 3,6 milliards avec 5 coups par seconde (a134). En plus, `FortuneTest` ne marche qu'en Studio, et la Fortune Tower est coupée en ligne (`Features.FortuneTower = false`). À jouer dans Studio (« Clients and Servers », 2 joueurs, Cantin seul avec deux fenêtres) ou en Team Test si les commandes y marchent. |
| **T-050** : mesure de `PvPController` à plusieurs | Il faut le plus de boutiques occupées possible (idéalement 8). À deux plus le bot, on n'a que 3 boutiques, presque comme la mesure du 14/11 (2 boutiques). Le plan de la bêta le prévoit le mercredi 2/12 (serveur plein). Prévenir Claude avant (section 3). |

Pour T-029 et T-030, on peut jouer maintenant, mais on refera un essai rapide après la vague 40 (voir les notes
plus haut).

---

## 3. Après la séance

Règle de la liaison (section « Tests à faire ») :

- **Test passé** : retirer sa ligne `- T-0NN` de « Tests à faire », puis pousser dans le même tour, avec le commit
  `Docs : tests, T-0NN passé(s)`.
- **Test raté** : garder la ligne et ajouter à la fin « Raté le 2026-MM-JJ : ce qu'on a vu ». Puis Cantin corrige
  le code, ou ouvre une ligne L- si Clément doit agir.
- Le plus simple : donner cette fiche remplie à Claude. Il met la liaison à jour et pousse.
- **T-050** : prévenir Claude **avant** de jouer, pas après. Il mesure lui-même pendant le test (10 s dans une
  boutique, 10 s à 80 studs) et compare `refreshAll` à la mesure du 14/11. Il dira comment il se branche. Ses
  outils passent par Studio : dans un jeu ouvert depuis l'appli Roblox, il ne pourra sans doute pas mesurer.
- Si on a essayé Team Test, noter dans la liaison si les commandes « Studio seulement » y marchent.

---

## 4. Tests sur téléphone

Sur un vrai téléphone, dans l'appli Roblox, sur la place DEV publiée (même mise en place qu'en section 1). Clément
peut aussi jouer la séance à deux depuis son téléphone : on fait alors une partie de ces tests en même temps.

| Test | Ce qu'on fait | Ce qu'on regarde | Vague 40 ? | Résultat |
| --- | --- | --- | --- | --- |
| **T-031** : colonne de gauche | Ouvrir la colonne de gauche (`LeftRailTouch`), toucher Upgrades | 2 colonnes, boutons faciles à toucher | Non | [ ] passé  [ ] raté : …… |
| **T-032** : barre du bas | Utiliser les 4 cases, les faire glisser au doigt | Rien ne chevauche l'argent ; le glisser marche | **Après** : a142 (objet en main) change la barre du bas et l'inventaire | [ ] passé  [ ] raté : …… |
| **T-033** : arbre de compétences | Ouvrir l'arbre, le faire glisser, pincer pour zoomer | Glisser et zoom fluides, rien ne bloque | Non | [ ] passé  [ ] raté : …… |
| **T-034** : taille des boutons | Ouvrir chaque écran | Boutons d'au moins 44 px de haut, faciles à toucher | Non | [ ] passé  [ ] raté : …… |
| **T-035** : poursuite et casse lisibles | Casser une vitrine, fuir le vigile | Le chrono, « RUN! » et le vigile se lisent bien | **Après** : a135 change le chrono (« POLICE IN … » au premier coup, braquage de 6 s) | [ ] passé  [ ] raté : …… |
| **T-038** (partie téléphone) | Regarder le bas à droite de l'écran | « Night in » et les boutons sociaux restent à gauche du bouton de saut | Non | [ ] passé  [ ] raté : …… |
| **T-048** : perf, boutique pleine | Dans une boutique pleine (dont un Secret), regarder les objets de près, puis reculer à 40 et 70 studs, puis tourner le dos | De près, rien ne change ; au loin, mouvement fluide, la lumière du halo s'éteint sans clignoter ; jeu fluide | **Après** : a141 change la boutique (deux files) et le halo des objets exposés | [ ] passé  [ ] raté : …… |
| **T-049** : perf, arc-en-ciel et nuit | Porter un objet arc-en-ciel, puis rien, pendant une nuit (compte à rebours affiché), à côté d'une boutique d'un autre joueur | L'arc-en-ciel tourne ; le compte à rebours baisse d'une seconde par seconde ; l'invite de vol s'allume quand on s'approche ; pas de saccade nouvelle | Plutôt après : a141 touche aussi le halo de rareté (`RarityHalo`) | [ ] passé  [ ] raté : …… |

En ligne, on ne peut pas faire venir la nuit (`NightSkipTo` et `StartEvent` sont Studio seulement). Une nuit
arrive toutes les 10 min (8 min de jour, 2 min de nuit) : prévoir T-049 au bon moment.
