--!strict
-- StoreHeistService (DEV-015) : braquage des magasins PNJ, chrono de 10 s, rideau, rayons et
-- tirage des colis (Partie 1, sections 5.3, 5.5, 5.6, 5.7, 5.11, 5.12, 7.3 et 9.4 ; question
-- « Vitrine PNJ partagée » de la section 15 ; règles des colis de Clément, liaison L-031 et L-033,
-- acceptées par Ironix le 2026-11-07).
--
-- Magasin PNJ = Model taggé `NPCStore` (attribut Zone), posé dans la map (Workspace, hors
-- _INBOX_CLEMENT, comme WindowService). Enfants lus, cherchés parmi les descendants (contrat
-- 10.4) : `ShelfSlot_01` à `_10` (Attachments ; leur attribut Tier n'est plus lu, L-033),
-- `Bounds` (volume intérieur), `Shutter` (rideau livré en position ouvert), `Window` (on sort
-- les joueurs devant elle).
--
-- Règles :
--   - Rayons : à chaque remplissage (démarrage, RefillAll à la tombée de la nuit), le
--     serveur répartit au hasard sur les ShelfSlot du magasin un jeu neuf de colis :
--     Balance.Heist.BoxTiers[Tier].Count de chaque type (6 Standard, 3 Premium, 1 Luxe, L-033).
--     Le type appartient au colis, plus à l'emplacement : le temps de prise est celui du colis
--     (attribut Tier du colis, lu par HeistController). Magasin à moins de 10 rayons (contrat
--     incomplet) : le Luxe est posé d'abord, puis les Premium, les Standard en trop manquent.
--     Les colis sont créés par le code dans un dossier `ShelfBoxes` du magasin (`ShelfBox_01`…,
--     numéro de l'emplacement, tag ShelfBox) : le modèle du magasin n'en contient pas. Aspect :
--     modèle `BOX_<Rareté>` de Clément (rareté du contenu, tiré à la mise en rayon ; L-097 point 3)
--     s'il existe dans ReplicatedStorage/Assets (ou ServerStorage/Assets), sinon `BOX_<Tier>`, sinon
--     un bloc V0 (carton brun, carton bleu scellé, caisse en bois cerclée d'or, 7.3). Sur le rayon,
--     le colis n'est pas teint (BOX_<Rareté> est déjà à la couleur de sa rareté).
--     Avec Features.ShelfOpen (vague 32, règle de Cantin du 2026-11-13) : seule la rareté de la CAISSE
--     est tirée à la mise en rayon, comme la rareté ci-dessous (ZoneOdds, sinon Rarities.BoxOdds par
--     type) ; elle choisit BOX_<Rareté>, va dans l'attribut BoxRarity du colis et sur son BB_Box (rareté
--     seule). Le contenu (objet, rareté de l'objet, mutation, taille) n'est PAS tiré ici : il l'est à
--     l'ouverture (« Sortie », plus bas). Les deux points suivants (contenu et mutation à la mise en
--     rayon) ne valent donc que pour l'ancien déroulé.
--   - Contenu tiré à la mise en rayon (L-031), plus à la prise : la rareté selon
--     ShelfBoxes.ZoneOdds[zone][Tier] s'il existe (zone 1 = zone tuto : Communs seulement, L-033),
--     sinon Rarities.BoxOdds[Tier] (7.3) ; puis un objet au hasard parmi ceux de la zone et de
--     cette rareté (Items.Pick, catalogue v2 : plusieurs objets par case, jamais un objet
--     TutorialOnly ; un Secret, toutes zones). Case vide (Config incohérente) : la rareté tirable
--     la plus proche en dessous, avec un avertissement par case (drawContent). Ce contenu ne quitte
--     jamais le serveur avant OpenBox (5.7) : ni le colis ni son étiquette ne portent l'ItemId ou
--     le nom de l'objet.
--   - Mutation (DEV-131, L-084 point 3) : tirée au même moment, côté serveur (Mutations.Roll : une
--     taille et un effet au plus, indépendants de la rareté), gardée avec le contenu : le colis qui
--     revient sur son rayon garde la sienne, le payload la porte jusqu'au présentoir (UnboxService).
--     Jamais pour un objet TutorialOnly, ni pour un contenu remplacé par l'accroche du tuto.
--   - Étiquette : chaque colis du rayon porte BB_Box (CarryService.AttachBoxLabel : copie de
--     ReplicatedStorage/Assets/UI/BB_Box accrochée à son LabelPoint) : catégorie de l'objet (ligne
--     cachée tant qu'elle est vide), rareté à sa couleur, mutation (« BIG · GOLD », cachée sans
--     mutation). Le colis porté
--     garde la même étiquette (CarryService). ShelfBoxController (client) ne montre que celles des
--     colis en vue et ne garde que 25 contours.
--   - Casse (WindowService.OnBroken, vitrine d'un magasin PNJ) : le magasin ouvre pour
--     Balance.Heist.Duration (10 s). Vitrine partagée (proposition de 5.3 point 8 et de la
--     section 15) : tout le monde peut entrer ; le casseur a Balance.Heist.BreakerHeadStart
--     (1 s) d'avance exclusive pour prendre un colis. HeistTimer(storeId, endsAt) part au
--     casseur et aux joueurs à TIMER_RADIUS studs ou moins du magasin, puis à ceux qui
--     s'approchent pendant le chrono ; HeistTimer(storeId, 0) le masque.
--   - Prise : GrabItem(slotId), en deux appels (voir « Maintien » plus bas). Le serveur vérifie :
--     magasin ouvert (et pas fermé pour lui), colis posé sur le rayon, avance du casseur, mains vides
--     (CarryService.IsCarrying), joueur vivant dans le volume Bounds et à GrabMaxDistance
--     (8 studs) au plus de l'emplacement, maintien du type du colis (Balance.Heist.BoxTiers). Le
--     rayon se vide, CarryService.StartCarry reçoit le payload avec le contenu tiré à la mise en
--     rayon (ou celui de l'accroche du tuto, plus bas), et le chrono est masqué pour ce joueur
--     (« le chrono ne compte plus pour lui », 5.3 point 5).
--   - Accroche du tuto (5.11) : StoreHeistService.SetContentOverride(fn), appelée à chaque prise
--     avant StartCarry. fn peut remplacer, pour ce joueur, le type, la rareté et l'objet du colis
--     qu'il soulève (1er colis Premium, objet Rare garanti : Tutorial.FirstBoxTier et
--     GuaranteedItemId, le Pot de nouilles, qu'aucun tirage ne donne) ;
--     le BB_Box du colis porté, construit par CarryService d'après le payload, montre alors le
--     contenu remplacé. Le colis du rayon, lui, garde le sien : s'il revient (porteur rattrapé),
--     c'est avec son contenu d'origine. TutorialService (pas encore écrit) posera cette accroche.
--   - Fermé pour le voleur seulement (Cantin, 2026-11-11 ; remplace l'interdiction de reprise après une
--     capture et son message) : dès qu'un joueur prend un colis sur un rayon, ce magasin
--     est fermé pour lui seul, jusqu'au départ du vigile apparu pour ce vol (GuardService.OnGuardGone :
--     rentré et effacé) ou, au plus tard, jusqu'à la réouverture du magasin (vitrine reconstruite). Sans
--     vigile (plafonds de 9.7, GuardService absent) : jusqu'à la réouverture (V0 proposé, absent du
--     doc). Pendant ce temps, côté serveur : plus aucune prise pour lui dans ce magasin, et plus de
--     chrono. D'abord « en sortie » (Leaving) tant qu'il est dans le volume Bounds avec le colis ; puis
--     « fermé » (Closed) dès qu'il en sort ou qu'il ne porte plus le colis (attrapé dedans, colis tombé) :
--     alors, s'il est (ou revient) dans Bounds, il est sorti devant la vitrine (moveOut, colis gardé).
--     L'attribut CLOSED_ATTRIBUTE du Player liste les StoreId fermés (Closed) pour lui : son client
--     (StoreLockController) y montre le rideau baissé et solide, chez lui seul. Les autres joueurs voient
--     le magasin normal et peuvent continuer à le braquer, chacun fermé pour lui-même s'il vole.
--   - Rideau local qui attend les vigiles (a70, Cantin 2026-11-11 : on ne doit jamais voir un vigile
--     traverser ce rideau) : un magasin n'est écrit dans CLOSED_ATTRIBUTE (rideau local baissé) que si
--     aucun vigile n'y est. Il est retenu (CurtainHeld) tant qu'un vigile (n'importe lequel, de
--     Workspace/ActiveGuards : celui du voleur, celui d'un autre voleur qui vient d'apparaître…) est
--     dans le volume Bounds ou à CURTAIN_GUARD_MARGIN studs de lui, ou qu'un vigile de ce magasin qui
--     rentre vers sa réserve (GuardService.GetReturningGuards) est à CURTAIN_RETURN_MARGIN studs ou
--     moins : le rideau local remonte alors avant qu'il l'atteigne, et retombe quand il est reparti.
--     Un vigile qui rentre et qui est déjà dans Bounds ne le retient pas : il est passé derrière (Cantin,
--     2026-11-11 : attrapé dans le magasin, le rideau restait levé jusqu'au départ du vigile).
--     Rien de tout ça quand le vrai rideau est baissé (personne ne passe, les deux rideaux sont au même
--     endroit). Seul le visuel attend : la règle du serveur (pas d'entrée, pas de prise) reste la même.
--     Choix d'a70 : lever le rideau plutôt qu'effacer le vigile chez le voleur ; une seule règle sert à
--     la sortie, au retour et au vigile d'un autre voleur, tout côté serveur, sans rien de nouveau au
--     client.
--   - Un seul braquage à la fois (a70, Cantin 2026-11-11, L-099 point 3 ; WindowService.AddHitGate) :
--     un joueur dont le braquage n'est pas fini ne fait aucun dégât à la vitrine d'un AUTRE magasin
--     PNJ, et reçoit Balance.Heist.OneAtATimeMessage, au plus une fois toutes les
--     Balance.Heist.OneAtATimeCooldown s. Braquage en cours (V0) : le chrono de 10 s d'un magasin dont
--     il a cassé la vitrine (Breaker) tourne encore, ou il porte un colis PNJ (de n'importe quel
--     magasin). La poursuite du vigile de jour ne finit qu'avec le portage (capture, zone safe, colis
--     posé, tombé ou perdu) : « porte un colis » la couvre. Braquage fini = chrono fini et mains vides
--     de colis PNJ ; la fermeture du magasin pour lui (rideau local) ne compte pas. Taper la vitrine
--     d'un magasin de son braquage reste permis. Parcelles des joueurs et camion de l'événement : la
--     règle ne s'applique pas (ni comme cible, ni comme braquage en cours).
--   - Fermeture, à la fin du chrono : plus aucune prise ; les joueurs dedans sans colis sont
--     sortis devant la vitrine, avec un Notify. Tant que le magasin est fermé, un joueur sans
--     colis qui se retrouve dans le volume Bounds en est sorti de la même façon (pas de camping
--     dedans). Le rideau `Shutter` tombe (il descend de sa propre hauteur, comme dans la greybox)
--     dès que plus personne ne doit sortir : ni joueur qui porte un colis, ni vigile (les modèles
--     de Workspace/ActiveGuards, GuardService) dans le volume Bounds. Décision d'Ironix du
--     2026-11-08 : un rideau tombé à 10 s pile enfermait le vigile, qui ne pouvait plus poursuivre
--     le voleur sorti juste avant.
--   - Reconstruction : WindowService reconstruit la vitrine 20 s après la fermeture (30 s après
--     la casse). Le rideau remonte alors, et tout joueur encore dedans est sorti, colis gardé
--     (sinon il serait enfermé derrière la vitre).
--   - Les colis pris ne reviennent pas avant la nuit : RefillAll() est un nouveau tirage (5.12).
--     Pour chaque magasin, tous les colis encore posés (ou en vol de retour) sont retirés et un
--     jeu neuf est réparti au hasard, chacun avec son contenu tiré. NightCycleService (DEV-047)
--     l'appelle à chaque tombée de la nuit.
--   - Remplissage d'un magasin ouvert (choix V0, absent du doc) : il attend la fermeture du
--     magasin (fin du chrono, ou vitrine reconstruite avant). Aucun colis ne change donc sous les
--     mains d'un joueur pendant les 10 s, et la nouvelle répartition se fait rideau baissé, une fois
--     les joueurs sans colis sortis. Les autres magasins sont remplis tout de suite.
--   - Colis en vol de retour au moment d'un remplissage : retiré avec les autres (il était du
--     tirage précédent).
--   - Colis sortis du magasin (portés, ou tombés au sol après un coup de batte) : ils gardent leur
--     contenu. Échec du porteur (CarryService.OnCarryEnded, résultat « Failed », colis PNJ) : le
--     colis revole vers son emplacement (5.5), depuis la tête du porteur si elle existe encore, avec
--     son contenu d'origine (sinon mourir exprès relancerait le dé). Colis au sol (« Dropped ») :
--     rien tant qu'il est au sol (n'importe qui peut le ramasser, il reste sorti) ; resté
--     Bat.DroppedLifetime s sans preneur (CarryService.OnDropExpired, 6.2), il revole vers son
--     emplacement depuis sa place au sol. Si son magasin a été rempli depuis sa prise (nuit), il ne
--     revient pas : nouveau tirage, pas de doublon.
--
-- Maintien (temps de prise de 5.3, vérifié par le serveur) : le client envoie GrabItem(slotId)
-- au début du maintien de l'invite, puis une seconde fois quand elle se déclenche. Le premier
-- appel ouvre un maintien sur ce colis (heure serveur) ; le second n'est accepté que si
-- GrabTime − GRAB_TIME_TOLERANCE s se sont écoulées. Pendant le maintien, le serveur revérifie
-- tout 10 fois par seconde : s'il sort du volume, s'éloigne au-delà de 8 studs, meurt, porte
-- déjà un colis, si le colis du rayon change ou si le magasin ferme, le maintien est annulé. Un
-- maintien non conclu expire GrabTime + HOLD_EXPIRY s après son début. Un seul maintien par
-- joueur : un appel sur un autre rayon remplace le précédent. Le client ne peut donc pas prendre
-- plus vite que GrabTime − 0,1 s, ni sans rester à portée pendant ce temps. Comme il n'existe
-- pas de remote d'annulation, relâcher l'invite ne prévient pas le serveur : un nouvel appui sur
-- le même rayon dans la seconde qui suit, sans s'être éloigné, conclut tout de suite (le joueur
-- est bien resté à portée tout ce temps).
--
-- Ouverture des colis sur le rayon (liaison L-112, décisions de Cantin du 2026-11-12 ; interrupteur
-- Features.ShelfOpen ; valeurs : Config/ShelfOpen ; attributs : Shared/ShelfOpenState). À true, le colis
-- ne se porte plus fermé : on l'ouvre sur son rayon, on voit l'objet, et c'est l'objet qu'on vole. À
-- false, tout ce qui précède reste tel quel (ancien déroulé, gardé en secours) et rien de ce qui suit
-- n'existe.
--   - Règle du braquage (Clément, L-118 points 8 et 9, 2026-11-13 ; remplace le chrono de 10 s après la
--     casse) : (a) pendant la casse, vitrine pas cassée avant que le « ? » des témoins soit plein : la
--     police vient (WitnessService), et elle renvoie à la base. (b) Le chrono du vigile part au PREMIER
--     coup sur la vitrine (Balance.Window.BreakTimer, WindowService : BreakInfo.ChronoEndsAt) et continue
--     après la casse ; il est montré à chaque intrus (entré dans Bounds pendant cette ouverture : Entered),
--     dedans ou dehors, objet ou non. Entre la casse et la fin du chrono, tout le monde peut entrer. À la
--     fin du chrono (chronoEnd) : GuardService.ChaseIntruder pour chaque intrus (ceux du magasin d'abord),
--     même sans objet ; personne n'est sorti, ceux qui sont dedans continuent d'ouvrir et de prendre ;
--     celui qui n'y était pas n'entre plus (sorti devant la vitrine, MESSAGES.Closed). Plus de vigile à la
--     prise. (c) Dès qu'un intrus sort de Bounds, avec ou sans objet, le magasin est fermé pour lui (Closed :
--     rideau local baissé, sorti s'il revient) jusqu'à la réouverture (vitrine reconstruite), plus jusqu'au
--     départ de son vigile. Sorti SANS objet avant la fin du chrono (Cantin, 2026-11-13) : il n'a rien
--     volé, c'est fini pour lui ; il n'est plus intrus (retiré d'Entered : aucun vigile pour lui) et son
--     chrono disparaît tout de suite. Sorti en portant un objet, ou encore dedans à la fin du chrono : vigile
--     comme avant. Rideau local : la règle a70 reste (levé seulement pendant qu'un vigile, sorti pour un
--     AUTRE intrus, passe ; entrée toujours refusée) ; seul, plus aucun vigile ne le lève. Le magasin se ferme (closeStore, vrai rideau) quand le chrono est fini, que
--     plus personne n'est dans Bounds et qu'aucune ouverture ni réservation n'est en cours ; la vitrine est
--     reconstruite Balance.Window.RebuildDelay s après au plus tôt (point d'attente de WindowService, qui
--     reconstruit de toute façon au bout de son attente maximale, en sortant ceux qui y seraient encore).
--     Les témoins ne montent plus pendant l'ouverture (ils fuient à la casse, L-118 point 10).
--   - Lancement : OpenShelfBox(slotId), deux appels comme GrabItem (Cantin, 2026-11-13 : rester appuyé sur
--     E) : début puis fin du maintien, maintien = GrabTime du type du colis (Balance.Heist.BoxTiers),
--     temps écoulé vérifié ici avec la même tolérance (GRAB_TIME_TOLERANCE) ; un seul appel ne lance rien.
--     Maintien d'ouverture à part (openHolds), revérifié 10 fois par seconde comme celui de la prise
--     (colis changé, refus d'ouverture, expiration GrabTime + HOLD_EXPIRY). Vérifié à chaque appel (9.4) : magasin
--     ouvert (fermé seulement quand plus personne n'y est, voir plus haut), colis posé, fermé et pas
--     déjà en cours d'ouverture, avance du casseur, magasin pas fermé pour lui, mains vides, joueur
--     vivant dans le volume Bounds et à GrabMaxDistance au plus, anti-triche ; puis, au lancement seulement (fin du maintien),
--     si un témoin du magasin appelle la police (WitnessService.IsCalling) : refus avec le Notify « Witnesses are calling
--     the police! » (Warning, V0, au plus un par seconde et par joueur). Débit : celui du remote (5/s, V0).
--     Rien n'empêche un joueur d'ouvrir plusieurs colis à la suite (V0, à trancher par Cantin).
--   - Chance : tirée ici au hasard dans ShelfOpen.LuckTable (poids), jamais par le client. Le colis
--     reçoit ShelfOpenBy, ShelfOpenAt, ShelfLuck, ShelfRevealAt (= ShelfOpenAt +
--     ShelfOpenState.revealDelay(chance)) puis ShelfOpenState = "Opening" : chaque client calcule le
--     compteur « ×N LUCK » sans flux réseau. Une fois lancée, l'ouverture va au bout seule : le joueur
--     peut bouger, sortir, partir.
--   - Témoins : plus de WitnessService.Raise au lancement (L-118) ; WitnessService.Calm(magasin)
--     seulement quand la DERNIÈRE ouverture en cours dans ce magasin est finie (Calm vide le « ? » de
--     tous les témoins du magasin : un joueur qui finit ne vide pas la jauge d'un autre qui ouvre encore).
--     Police appelée pour ce magasin pendant la montée (WitnessService.OnCall) : ShelfRevealAt de chaque
--     ouverture en cours est avancé à maintenant et l'objet sort tout de suite, avec la chance atteinte à
--     cet instant (ShelfOpenState.luckAt). Sans WitnessService (bancs) : ni témoins ni police.
--   - Sortie, à ShelfRevealAt : le contenu est tiré à cet instant (vague 32, règle de Cantin du
--     2026-11-13, qui remplace les crans de rareté du 2026-11-12 ; valeurs de Config/ShelfOpen) :
--     (1) rareté de l'objet tirée dans ShelfOpen.BoxRarityOdds[rareté de la caisse] (poids relatifs),
--     les poids des raretés au-dessus d'un seuil multipliés par la chance (ShelfOpen.LuckBoost :
--     "AboveBox", au-dessus de la rareté de la caisse, proposé par l'équilibrage ; "AboveLowest",
--     au-dessus de la plus basse de la table), puis normalisés : rien n'est garanti, une caisse
--     Mythique peut donner un Commun ou un Secret ; (2) objet de cette rareté (Items.Pick, jamais
--     TutorialOnly) dans la zone du magasin, sinon dans la zone la plus proche qui en a un (zone + 1,
--     puis − 1, + 2…) ; un Secret (ou une Divine), toutes zones ; aucun objet de cette rareté nulle
--     part dans tout le catalogue (Divine aujourd'hui, Config incohérente) : la rareté la plus proche en
--     dessous qui en a, avec un avertissement. Un objet sorti peut donc être d'une autre zone que son magasin ; (3)
--     mutation et taille tirées à ce moment (Mutations.Roll). Table de la caisse absente : l'objet est
--     de la rareté de la caisse (avertissement). L'accroche du tuto (SetContentOverride) est appelée
--     ici, pour l'ouvreur, AVANT tout tirage : si elle impose un contenu, c'est l'objet sorti, sans
--     tirage ni mutation (V0 : l'objet garanti du tuto reste garanti). Le contenu ne quitte jamais le
--     serveur avant cet instant (5.7) ; il n'existe même pas avant : aucun attribut ItemId, Rarity ni
--     Mutation* n'est posé sur un colis. Log : « chance ×N, caisse <rareté> → objet <rareté> (<ItemId>) ».
--     Le colis disparaît (ShelfOpenState = "Revealed" juste avant) et l'objet sort à sa place : copie du
--     modèle ITM_<ItemId> de Clément (cherché comme les BOX_*), sinon un bloc V0 à la couleur de la
--     rareté ; à l'échelle de sa mutation de taille ; pivot posé sur le ShelfSlot et tourné comme lui ;
--     dans le dossier ShelfBoxes, nommé ShelfItem_NN, tag ShelfItem, attributs SlotId, Slot, Tier (le
--     type du colis d'origine : son temps de prise), Landed, ItemId, Rarity, MutationSize,
--     MutationEffect, Income, ShelfLuck, ShelfReservedBy, ShelfReservedUntil (= sortie +
--     ShelfOpen.ReserveTime). BB_Item, halo et effets de la révélation sont posés par le client
--     (ShelfOpenController) d'après ces attributs. Annonce : Notify (Unbox.AnnounceKind) aux autres
--     joueurs à partir de ShelfOpen.AnnounceMinRarity.
--   - Prise de l'objet : GrabItem(slotId), deux appels comme avant (maintien du Tier du colis d'origine).
--     Avant ShelfReservedUntil, seul l'ouvreur ; ensuite tout joueur dans le magasin. Mêmes contrôles
--     que pour un colis (Bounds, distance, mains vides, magasin pas fermé pour lui). Le portage est un
--     NPCItemPayload (CarryService : l'objet visible sur la tête, halo, BB_Carry) ; le vigile ne part
--     plus à la prise (L-118 : il sort à la fin du chrono), le magasin se ferme pour lui quand il sort.
--   - Rideau : tant qu'une ouverture est en cours dans ce magasin ou que la réservation d'un objet sorti
--     (ShelfReservedUntil) n'est pas passée, le magasin ne se ferme pas ; une fois fermé, le rideau tombe
--     comme avant (L-064 : porteurs et vigiles sortis).
--   - Objet sorti que personne n'a pris : il reste sur son rayon, libre pour tous, visible au prochain
--     braquage de ce magasin, jusqu'au prochain remplissage (nuit).
--   - Nuit (RefillAll) : comme un magasin ouvert, un magasin où une ouverture est en cours ou un objet
--     encore réservé est rempli dès que c'est fini (ouverture au bout, réservation passée). Le
--     remplissage retire tout : colis fermés, objets sortis non pris ; un objet porté ou au sol à ce
--     moment ne reviendra pas sur son rayon.
--   - Fin du portage d'un objet (CarryService.OnCarryEnded) : « Consumed », rangé en base (UnboxService) ;
--     attrapé (« Caught » : vigile, police, vigile de nuit), CarryService le lâche au sol (« Dropped »),
--     où il se reprend comme un colis tombé d'un coup de batte (GrabDropped, BatService) ; coup de
--     batte : pareil. Resté Bat.DroppedLifetime s au sol sans preneur, ou échec sans chute (mort,
--     départ, personnage retiré, anomalie de l'anti-triche, refus du rangement : « Failed ») : il revole
--     vers son rayon, objet déjà sorti, sa réservation n'est pas relancée (V0 : le plus simple, la règle
--     des colis), sauf si son magasin a été rempli depuis ou si son rayon est occupé : il disparaît.
--
-- Posé par le serveur, lu par HeistController, ShelfBoxController et StoreLockController :
--   sur le magasin : StoreId (texte), HeistOpen (booléen), ShutterClosedPivot (CFrame : pivot du
--     rideau baissé, s'il a un rideau) ; pendant le chrono seulement,
--     HeistEndsAt et HeistExclusiveUntil (heures serveur, workspace:GetServerTimeNow()) et
--     HeistBreakerId (UserId du casseur) ;
--   sur le Player : ClosedStores (texte, StoreId séparés par des virgules, triés ; absent = aucun) ;
--   sur chaque colis du rayon : tag ShelfBox ; SlotId (à renvoyer dans GrabItem, « <StoreId>/03 »),
--     Slot (nom de l'Attachment, « ShelfSlot_03 »), Tier (type du colis), Landed (false tant
--     qu'un colis rendu vole) ; son étiquette BB_Box ; avec Features.ShelfOpen, BoxRarity (rareté de la
--     caisse, vague 32 ; Shared/ShelfOpenState) et les attributs ShelfOpen* de l'ouverture.
--
-- API (serveur) :
--   StoreHeistService.RefillAll() -> number
--       Nouveau tirage de tous les magasins (voir plus haut). Renvoie le nombre de colis posés
--       tout de suite (les magasins ouverts sont remplis à leur fermeture, pas comptés). Pour
--       NightCycleService (la nuit, 5.12).
--   StoreHeistService.IsOpen(store) -> boolean
--       store = le Model du magasin ou son StoreId. true pendant les 10 s du chrono.
--   StoreHeistService.OnBoxGrabbed(listener) -> déconnexion
--       listener(player, payload) après chaque prise réussie (CarryService.StartCarry a accepté).
--   StoreHeistService.ReturnBox(payload, from?) -> boolean
--       Remet sur son emplacement, avec son contenu d'origine, le colis sorti de ce payload NPCBox,
--       en vol depuis `from` (Vector3) s'il est donné. false si le colis est inconnu, déjà revenu,
--       d'avant un remplissage de son magasin, ou si son emplacement est occupé. Utilisé ici à
--       l'échec du porteur et pour le colis tombé au sol qui revient au bout de 15 s (DEV-048) :
--       le payload doit être la même table que celle donnée à StartCarry (CarryService la garde).
--   StoreHeistService.SetContentOverride(fn?)
--       Accroche du tuto (voir plus haut). fn(player, drawn) -> override?, appelée à chaque prise,
--       ne doit pas yield. drawn = { StoreId, SlotId, Zone, Tier, Rarity, ItemId } (contenu du
--       colis du rayon). Un contenu remplacé n'a jamais de mutation (DEV-131 : jamais pour le colis
--       du tuto). override = nil (rien ne change) ou { Tier?, Rarity?, ItemId? } : Tier =
--       type du colis porté (clé de Balance.Heist.BoxTiers) ; ItemId = objet (de la zone du
--       magasin, ou un Secret) ; Rarity seule = un objet de cette rareté est tiré dans la zone
--       (Items.Pick : jamais un objet TutorialOnly, sans le repli de la mise en rayon).
--       Un remplacement invalide est ignoré, avec un avertissement. nil retire l'accroche.
--       Avec Features.ShelfOpen : appelée à la sortie de l'objet, pour l'ouvreur, avant tout tirage ;
--       drawn.Rarity = rareté de la caisse et drawn.ItemId = "" (contenu pas encore tiré, vague 32) ;
--       un override avec ItemId ou Rarity donne l'objet sorti tel quel, sans tirage ni mutation.
--   StoreHeistService.SetLuckOverride(fn?)  (vague 31, a107 ; Features.ShelfOpen)
--       Accroche du tuto : fn(player, drawn) -> number?, appelée au lancement de chaque ouverture sur
--       le rayon, sans yield ; un nombre fini ≥ 1 remplace la chance tirée ; nil ou une valeur invalide
--       garde le tirage de LuckTable. nil retire l'accroche. drawn comme pour SetContentOverride avec
--       Features.ShelfOpen (Rarity = rareté de la caisse, ItemId = "").
--   StoreHeistService.GetStoreId(model) -> string? et GetStoreModel(storeId) -> Model?
--       StoreId = l'id de vitrine de WindowService (le nom du modèle, « STORE_Z1_Superette »).
--
-- Payload d'un colis PNJ, transmis à CarryService : { Kind = "NPCBox", Tier, Zone, Rarity,
-- ItemId, StoreId, SlotId, Mutation? }. ItemId ne doit jamais partir vers un client avant OpenBox (5.7).
-- Payload d'un objet sorti (Features.ShelfOpen) : { Kind = "NPCItem", ItemId, Rarity, Mutation?, Zone,
-- StoreId, SlotId, Luck } (Shared/Types/Carry). OnBoxGrabbed ne prévient que pour un colis.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local Items = require(Shared.Config.Items)
local Rarities = require(Shared.Config.Rarities)
local ShelfBoxes = require(Shared.Config.ShelfBoxes)
local Mutations = require(Shared.Config.Mutations)
local Zones = require(Shared.Config.Zones)
local Features = require(Shared.Config.Features)
local Formulas = require(Shared.Config.Formulas)
local ShelfOpen = require(Shared.Config.ShelfOpen)
local Unbox = require(Shared.Config.Unbox)
local Attributes = require(Shared.Contract.Attributes)
local Net = require(Shared.Net.Net)
local ShelfOpenState = require(Shared.ShelfOpenState)

local AntiCheatService = require(script.Parent.AntiCheatService)
local WindowService = require(script.Parent.WindowService)

export type NPCBoxPayload = {
	Kind: "NPCBox",
	Tier: string, -- "Standard", "Premium" ou "Luxe"
	Zone: number,
	Rarity: string, -- Id de Rarities ("Epic"…)
	ItemId: string, -- Id de Items ("Z3_Smartphone"…), secret jusqu'à OpenBox
	StoreId: string,
	SlotId: string,
	Mutation: Mutations.Mutation?, -- DEV-131 : tirée à la mise en rayon ; nil = aucune
}

-- Objet sorti d'un colis ouvert sur le rayon (L-112), porté : même forme que Shared/Types/Carry.
export type NPCItemPayload = {
	Kind: "NPCItem",
	ItemId: string,
	Rarity: string, -- rareté de l'objet, tirée à la sortie (table de la caisse et chance, vague 32)
	Mutation: Mutations.Mutation?,
	Zone: number,
	StoreId: string,
	SlotId: string,
	Luck: number, -- chance de l'ouverture (≥ 1)
}

-- Contenu du colis du rayon, passé à l'accroche du tuto.
export type OverrideInfo = {
	StoreId: string,
	SlotId: string,
	Zone: number,
	Tier: string,
	Rarity: string,
	ItemId: string,
}

-- Ce que l'accroche du tuto remplace (champs absents = inchangés).
export type OverrideResult = {
	Tier: string?,
	Rarity: string?,
	ItemId: string?,
}

export type ContentOverride = (player: Player, drawn: OverrideInfo) -> OverrideResult?
-- Vague 31 (a107) : chance imposée par le tuto au lancement d'une ouverture (nil = tirage normal).
export type LuckOverride = (player: Player, drawn: OverrideInfo) -> number?

-- Ce que ce service utilise de CarryService (a11, DEV-017). Typé ici pour ne pas dépendre
-- des noms de types de son module.
type CarryApi = {
	StartCarry: (player: Player, payload: NPCBoxPayload | NPCItemPayload) -> boolean,
	IsCarrying: (player: Player) -> boolean,
	GetPayload: (player: Player) -> any,
	OnCarryEnded: (listener: (player: Player, payload: any, result: string, reason: string) -> ()) -> any,
	OnDropExpired: (listener: (dropId: string, payload: any, position: Vector3) -> ()) -> any,
	AttachBoxLabel: (model: Model, rarityId: string, itemId: string?, mutation: Mutations.Mutation?) -> BillboardGui?,
}

local CarryService: CarryApi = require(script.Parent.CarryService) :: any

-- Ce que ce service utilise de WitnessService (L-111), s'il existe (require protégé dans Init).
type WitnessApi = {
	Raise: (store: Model, suspect: Player?, fillTime: number?) -> boolean,
	Calm: (store: Model) -> boolean,
	IsCalling: (store: Model) -> boolean,
	OnCall: (listener: (store: Model, suspect: Player?, police: Model?) -> ()) -> any,
}

-- Mutation (DEV-131) : nil = aucune ; jamais pour l'accroche du tuto.
type Content = { Rarity: string, ItemId: string, Mutation: Mutations.Mutation? }

-- Ouverture en cours d'un colis sur son rayon (L-112).
type Opening = {
	ByUserId: number, -- l'ouvreur
	Luck: number, -- chance tirée (≥ 1)
	OpenAt: number, -- heure serveur du lancement
}

-- Colis posé sur un rayon, ou en vol vers lui.
type ShelfBox = {
	Tier: string,
	Rarity: string, -- rareté de la caisse (BOX_<Rareté>, BB_Box) ; ancien déroulé : celle de son contenu
	-- Ancien déroulé : tiré à la mise en rayon (L-031), jamais envoyé aux clients. Features.ShelfOpen
	-- (vague 32) : nil, le contenu n'est tiré qu'à la sortie de l'objet (reveal).
	Content: Content?,
	Model: Model,
	Landed: boolean, -- false tant que le colis rendu vole vers le rayon
	StopFlight: (() -> ())?,
	Opening: Opening?, -- L-112 : en cours d'ouverture ; nil = fermé
}

-- Ce qui décrit un objet sorti d'un colis (L-112), sur son rayon comme une fois porté ou au sol.
type ItemInfo = {
	Tier: string, -- type du colis d'origine : son temps de prise
	Content: Content, -- contenu tiré à la sortie (vague 32), ou imposé par l'accroche du tuto
	Luck: number, -- chance de l'ouverture
	OpenerId: number, -- UserId de l'ouvreur
	ReservedUntil: number, -- os.clock() : avant, seul l'ouvreur peut le prendre
	ReservedUntilServer: number, -- la même heure, à l'horloge du serveur (attribut ShelfReservedUntil)
}

-- Objet sorti, posé à la place de son colis (ou en vol de retour vers elle).
type ShelfItem = {
	Info: ItemInfo,
	Model: Model,
	Landed: boolean,
	StopFlight: (() -> ())?,
}

type Slot = {
	Store: Store,
	Number: number, -- 1 à 10
	Name: string, -- « ShelfSlot_03 »
	Id: string, -- « <StoreId>/03 », envoyé par le client dans GrabItem
	Attachment: Attachment,
	Box: ShelfBox?, -- colis posé (ou en vol vers le rayon) ; nil = rayon vide
	Item: ShelfItem?, -- L-112 : objet sorti du colis de ce rayon (jamais en même temps que Box)
}

-- Objet sorti du magasin (porté ou au sol) : ce qui revient sur le rayon s'il revient.
type OutItem = {
	Slot: Slot,
	Info: ItemInfo,
}

-- Colis sorti du magasin (porté, ou au sol au jalon M3) : ce qui revient sur le rayon s'il revient.
type OutBox = {
	Slot: Slot,
	Tier: string,
	Content: Content, -- contenu d'origine, même si l'accroche du tuto a changé celui du porteur
}

type Store = {
	Id: string,
	Model: Model,
	Zone: number,
	Bounds: BasePart?,
	Window: PVInstance?,
	Shutter: PVInstance?,
	ShutterParts: { BasePart },
	ShutterCollide: { [BasePart]: boolean }, -- CanCollide d'origine, rideau ouvert
	ShutterOpen: CFrame,
	ShutterClosed: CFrame,
	ShutterDown: boolean,
	ShutterPending: boolean, -- fermé, vitrine cassée : le rideau attend que tout le monde soit sorti
	ShutterToken: number,
	StopShutter: (() -> ())?,
	Slots: { Slot },
	Folder: Folder,
	Open: boolean,
	Token: number, -- change à chaque ouverture et fermeture : périme les délais en cours
	Breaker: Player?,
	ExclusiveUntil: number, -- os.clock() de fin de l'avance du casseur
	EndsAt: number, -- heure serveur de fin du chrono
	Viewers: { [Player]: boolean }, -- joueurs qui voient le chrono
	RefillPending: boolean, -- RefillAll pendant le chrono : nouveau tirage à la fermeture
	Locked: { [Player]: LockState }, -- fermé pour ces voleurs seulement (voir l'en-tête)
	CurtainHeld: boolean, -- un vigile y est (ou va y entrer) : rideaux locaux levés (voir l'en-tête)
	-- Règle du braquage de Clément (L-118 points 8 et 9, Features.ShelfOpen ; voir l'en-tête) :
	Entered: { [Player]: boolean }, -- entrés dans Bounds pendant cette ouverture (les intrus)
	ChronoOver: boolean, -- chrono du vigile fini : les vigiles sont sortis
	ClosedAt: number, -- os.clock() de la dernière fermeture (reconstruction RebuildDelay s après au plus tôt)
	KickAfter: { [Player]: number }, -- attrapé dans Bounds : fermé pour lui, sorti à cet os.clock() (après le coup)
}

-- Leaving : vient de prendre un colis, encore dans Bounds avec lui ; Closed : fermé pour lui, rideau
-- baissé chez lui et sorti s'il entre.
type LockState = "Leaving" | "Closed"

-- Target : le colis (ShelfBox) ou l'objet sorti (ShelfItem, L-112) visé par le maintien.
type Hold = { Slot: Slot, Target: any, Tier: string, StartedAt: number }

type GrabbedListener = (player: Player, payload: NPCBoxPayload) -> ()

type BoxLook = {
	Size: Vector3,
	Color: Color3,
	Material: Enum.Material,
	Trim: Color3?, -- bande de scellé (Premium) ou cerclage (Luxe)
	Bands: number, -- 1 = scellé sur le dessus, 2 = deux cercles autour de la caisse
}

local STORE_TAG = "NPCStore" -- contrat 2.1 (Contract/Tags)
local INBOX_NAME = "_INBOX_CLEMENT" -- livraisons pas encore posées : ignorées (comme WindowService)
local SLOT_FORMAT = "ShelfSlot_%02d" -- contrat 10.4
local BOUNDS_NAME = "Bounds"
local SHUTTER_NAME = "Shutter"
local GUARDS_FOLDER = "ActiveGuards" -- vigiles en jeu, posés par GuardService dans le Workspace
local WINDOW_NAME = "Window"
local ASSETS_NAME = "Assets" -- ReplicatedStorage/Assets et ServerStorage/Assets (Clément, 9.2)
local BOX_PREFIX = "BOX_" -- BOX_<Rareté> (L-097 point 3), sinon BOX_<Tier> (10.3, Contract/Models)

-- Noms posés par ce service, lus par HeistController et ShelfBoxController (mêmes noms là-bas).
local BOXES_FOLDER = "ShelfBoxes"
local BOX_NAME_FORMAT = "ShelfBox_%02d"
local SHELF_BOX_TAG = "ShelfBox" -- tag posé par le code, hors du contrat de la section 2.1
local STORE_ID_ATTRIBUTE = "StoreId"
local OPEN_ATTRIBUTE = "HeistOpen"
local ENDS_AT_ATTRIBUTE = "HeistEndsAt"
local EXCLUSIVE_ATTRIBUTE = "HeistExclusiveUntil"
local BREAKER_ATTRIBUTE = "HeistBreakerId"
local SLOT_ID_ATTRIBUTE = "SlotId"
local SLOT_ATTRIBUTE = "Slot"
local TIER_ATTRIBUTE = "Tier"
local LANDED_ATTRIBUTE = "Landed"
-- Objet sorti d'un colis (L-112) : nom du modèle et attributs lus par le client (ShelfOpenController,
-- HeistController), en plus de ceux de Shared/ShelfOpenState.
local ITEM_NAME_FORMAT = "ShelfItem_%02d"
local ITEM_ID_ATTRIBUTE = "ItemId"
local RARITY_ATTRIBUTE = "Rarity"
local MUTATION_SIZE_ATTRIBUTE = "MutationSize"
local MUTATION_EFFECT_ATTRIBUTE = "MutationEffect"
local INCOME_ATTRIBUTE = "Income"
-- Fermeture pour le voleur seulement (même noms dans StoreLockController).
local CLOSED_ATTRIBUTE = "ClosedStores" -- sur le Player
local CLOSED_SEPARATOR = ","
local SHUTTER_PIVOT_ATTRIBUTE = "ShutterClosedPivot" -- sur le magasin

local MAX_ID_LENGTH = 64 -- longueur max d'un slotId accepté par Net (Definitions)

-- V0 proposé, absent du doc : services, joueurs et colis vérifiés 10 fois par seconde.
local TICK = 0.1
-- V0 proposé, absent du doc : après WindowService (100) pour lire les WindowId à l'Init.
local PRIORITY = 110
-- V0 proposé, absent du doc : le chrono est montré aux joueurs à 60 studs ou moins du centre
-- du magasin (le boulevard devant lui et le magasin d'en face).
local TIMER_RADIUS = 60
-- V0 proposé, absent du doc : écart du réseau toléré sur la durée de maintien.
local GRAB_TIME_TOLERANCE = 0.1
-- V0 proposé, absent du doc : un maintien non conclu expire 1 s après sa durée.
local HOLD_EXPIRY = 1
-- V0 proposé, absent du doc : rideau. Il tombe en 0,4 s, remonte en 0,8 s, et devient solide dès
-- qu'il est en bas. Il ne tombe qu'une fois le magasin vide de porteurs et de vigiles (L-064) : plus
-- besoin des 3 s où il restait franchissable (Cantin, 2026-11-10 : on passait à travers puis on était
-- téléporté dehors). Un joueur sans colis resté dedans est sorti comme avant.
local SHUTTER_FALL_TIME = 0.4
local SHUTTER_RISE_TIME = 0.8
local SHUTTER_EXIT_GRACE = SHUTTER_FALL_TIME
-- V0 proposé, absent du doc (a70) : rideau local du voleur. Un vigile à 1,5 stud ou moins du volume
-- Bounds le retient (son corps dépasse de son centre). Un vigile qui rentre vers la réserve le fait
-- remonter à 16 studs : à 10 studs/s (RETURN_WALK_SPEED de GuardService), il lui faut 1,6 s pour
-- arriver, le temps du tick (0,1 s), du réseau et de la remontée (0,8 s, StoreLockController).
local CURTAIN_GUARD_MARGIN = 1.5
local CURTAIN_RETURN_MARGIN = 16
-- V0 proposé, absent du doc : on sort les joueurs à 6 studs devant la vitrine (comme
-- l'apparition de PlotService), sol cherché de 4 studs au-dessus jusqu'à 8 en dessous.
local EJECT_DISTANCE = 6
local GROUND_RAY_UP = 4
local GROUND_RAY_DOWN = 8
local EJECT_LIFT = 0.1
-- V0 proposé, absent du doc : vol du colis rendu vers son rayon, à 150 studs/s, entre 0,4 et
-- 1,5 s, en arc (hauteur = 20 % de la distance, entre 2 et 12 studs).
local FLIGHT_SPEED = 150
local FLIGHT_MIN_TIME = 0.4
local FLIGHT_MAX_TIME = 1.5
local FLIGHT_ARC = 0.2
local FLIGHT_ARC_MIN = 2
local FLIGHT_ARC_MAX = 12
-- V0 proposé, absent du doc : un colis resté au sol (6.2) part 1 stud au-dessus de sa place au sol.
local DROP_RETURN_LIFT = 1

-- V0 proposé, absent du doc : blocs de remplacement tant que BOX_<Tier> n'est pas livré
-- (MOD-013). Aspect de 7.3 ; bois et or de la planche de style (10.6).
local V0_LOOKS: { [string]: BoxLook } = {
	Standard = {
		Size = Vector3.new(1.6, 1.2, 1.6),
		Color = Color3.fromRGB(176, 132, 84), -- carton brun
		Material = Enum.Material.SmoothPlastic,
		Bands = 0,
	},
	Premium = {
		Size = Vector3.new(1.8, 1.4, 1.8),
		Color = Color3.fromRGB(58, 104, 176), -- carton bleu
		Material = Enum.Material.SmoothPlastic,
		Trim = Color3.fromRGB(235, 235, 240), -- bande de scellé
		Bands = 1,
	},
	Luxe = {
		Size = Vector3.new(1.9, 1.6, 1.9),
		Color = Color3.fromHex("#9A5B2E"), -- bois (10.6)
		Material = Enum.Material.WoodPlanks,
		Trim = Color3.fromHex("#FFC52E"), -- or (10.6)
		Bands = 2,
	},
}

-- V0 proposé, absent du doc : bloc de remplacement d'un objet sorti tant que ITM_<ItemId> n'est pas
-- livré, à la couleur de sa rareté (la taille du bloc des présentoirs, DisplayService).
local V0_ITEM_SIZE = Vector3.new(1.2, 1.6, 1.2)
-- V0 proposé, absent du doc : au plus un Notify « les témoins appellent la police » par seconde et par joueur.
local CALL_NOTICE_INTERVAL = 1

-- Messages lus par le joueur (Notify), en anglais (L-036).
local MESSAGES = {
	Closed = "Too late: the shutter came down!",
	WitnessCalling = "Witnesses are calling the police!", -- V0 (L-112) : ouverture refusée pendant l'appel
}

-- Features.ShelfOpen (L-112) : true = les colis s'ouvrent sur le rayon et c'est l'objet qu'on vole ;
-- false = l'ancien déroulé (colis porté fermé), inchangé.
local SHELF_OPEN: boolean = Features.ShelfOpen == true

local IS_STUDIO = RunService:IsStudio()

local StoreHeistService = {}
StoreHeistService.Priority = PRIORITY

local stores: { [Instance]: Store } = {}
local storesById: { [string]: Store } = {}
local slotsById: { [string]: Slot } = {}
local holds: { [Player]: Hold } = {}
local openHolds: { [Player]: Hold } = {} -- maintiens d'ouverture d'un colis sur le rayon (L-112, Cantin 2026-11-13)
-- Colis sortis, par payload (la table donnée à StartCarry, que CarryService garde telle quelle).
local outBoxes: { [any]: OutBox } = {}
-- Objets sortis de leur magasin (L-112), par payload NPCItem (même règle que outBoxes).
local outItems: { [any]: OutItem } = {}
local lastCallNotice: { [Player]: number } = {} -- dernier Notify « les témoins appellent la police »
local witnessApi: WitnessApi? = nil -- WitnessService, s'il existe (Init)
local grabbedListeners: { GrabbedListener } = {}
local contentOverride: ContentOverride? = nil
local luckOverride: LuckOverride? = nil -- accroche du tuto (a107), voir SetLuckOverride
local lastRefusal: { [Player]: number } = {}
local lastGreedy: { [Player]: number } = {} -- dernier message « un seul braquage à la fois »
-- GuardService.GetReturningGuards, s'il existe (require protégé dans Init, comme OnGuardGone).
local returningGuards: ((store: Model) -> { BasePart })? = nil
-- GuardService.ChaseIntruder, s'il existe (Init) : le vigile sort à la fin du chrono (L-118).
local chaseIntruder: ((player: Player, store: Model) -> boolean)? = nil
local templates: { [string]: Instance } = {} -- BOX_<Rareté> ou BOX_<Tier> trouvé, par nom
local templateSearched: { [string]: boolean } = {} -- cherché une fois par nom, trouvé ou non
local noticed: { [string]: boolean } = {}
local random = Random.new()

-- Outils ----------------------------------------------------------------------------------

local function subscribe<T>(list: { T }, listener: T): () -> ()
	table.insert(list, listener)
	return function()
		local index = table.find(list, listener)
		if index then
			table.remove(list, index)
		end
	end
end

local function log(message: string)
	if IS_STUDIO then
		print(`[StoreHeistService] {message}`)
	end
end

-- Avertissement écrit une seule fois par serveur (Config ou modèle mal formé).
local function warnOnce(key: string, message: string)
	if noticed[key] then
		return
	end
	noticed[key] = true
	warn(`[StoreHeistService] {message}`)
end

-- Prise (ou ouverture, `remote` = "OpenShelfBox") refusée : signalée en Studio seulement (aide au
-- test), une ligne par seconde et par joueur.
local function refuse(player: Player, slotId: string, reason: string, remote: string?)
	if not IS_STUDIO then
		return
	end
	local now = os.clock()
	if now - (lastRefusal[player] or -math.huge) < 1 then
		return
	end
	lastRefusal[player] = now
	warn(`[StoreHeistService] {remote or "GrabItem"} de {player.Name} sur « {slotId} » refusé : {reason}`)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Boîte orientée d'une pièce ou d'un modèle.
local function boxOf(object: PVInstance): (CFrame, Vector3)
	if object:IsA("BasePart") then
		return object.CFrame, object.Size
	end
	return (object :: Model):GetBoundingBox()
end

-- Étendue de la boîte (cf, size) le long de la direction unitaire `axis`.
local function extentAlong(cf: CFrame, size: Vector3, axis: Vector3): number
	return math.abs(cf.RightVector:Dot(axis)) * size.X
		+ math.abs(cf.UpVector:Dot(axis)) * size.Y
		+ math.abs(cf.LookVector:Dot(axis)) * size.Z
end

local function inside(part: BasePart, point: Vector3): boolean
	local p = part.CFrame:PointToObjectSpace(point)
	local h = part.Size / 2
	return math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z
end

-- Distance de `point` au volume `part` (0 dedans).
local function distanceTo(part: BasePart, point: Vector3): number
	local p = part.CFrame:PointToObjectSpace(point)
	local h = part.Size / 2
	return Vector3.new(
		math.max(math.abs(p.X) - h.X, 0),
		math.max(math.abs(p.Y) - h.Y, 0),
		math.max(math.abs(p.Z) - h.Z, 0)
	).Magnitude
end

local function inMap(instance: Instance): boolean
	if not instance:IsDescendantOf(Workspace) then
		return false
	end
	local inbox = Workspace:FindFirstChild(INBOX_NAME)
	return inbox == nil or not instance:IsDescendantOf(inbox)
end

-- HumanoidRootPart d'un joueur vivant, ou nil.
local function rootOf(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if character == nil then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil, nil
	end
	return root :: BasePart, humanoid
end

local function isCarrying(player: Player): boolean
	local ok, carrying = pcall(CarryService.IsCarrying, player)
	return ok and carrying == true
end

-- Copie mélangée de `list` (Fisher-Yates).
local function shuffled<T>(list: { T }): { T }
	local copy = table.clone(list)
	for index = #copy, 2, -1 do
		local other = random:NextInteger(1, index)
		copy[index], copy[other] = copy[other], copy[index]
	end
	return copy
end

-- Déplace `target` sur la trajectoire path(alpha), alpha de 0 à 1 en `duration` s, à chaque
-- Heartbeat. Renvoie une fonction qui arrête le mouvement. `done` est appelé à l'arrivée.
local function animate(target: PVInstance, path: (alpha: number) -> CFrame, duration: number, done: (() -> ())?): () -> ()
	local started = os.clock()
	local connection: RBXScriptConnection? = nil
	local function stop()
		if connection then
			connection:Disconnect()
			connection = nil
		end
	end
	connection = RunService.Heartbeat:Connect(function()
		if target.Parent == nil then
			stop()
			return
		end
		local alpha = if duration > 0 then math.min((os.clock() - started) / duration, 1) else 1
		target:PivotTo(path(alpha))
		if alpha >= 1 then
			stop()
			if done then
				done()
			end
		end
	end)
	return stop
end

-- Tirage (serveur seulement) -----------------------------------------------------------------

-- Probabilités d'un type de colis dans une zone : celles de la zone (ShelfBoxes.ZoneOdds, zone 1
-- = Communs seulement, L-033), sinon celles du type (Rarities.BoxOdds, 7.3).
local function oddsFor(tier: string, zone: number): { [string]: number }?
	local byZone = ShelfBoxes.ZoneOdds[zone]
	local odds = if byZone then byZone[tier] else nil
	return odds or Rarities.BoxOdds[tier]
end

-- Rareté tirée selon oddsFor(tier, zone) (pourcentages).
local function drawRarity(tier: string, zone: number): string?
	local odds = oddsFor(tier, zone)
	if odds == nil then
		return nil
	end
	local total = 0
	for _, rarity in Rarities.List do
		total += odds[rarity.Id] or 0
	end
	if total <= 0 then
		return nil
	end
	local roll = random:NextNumber() * total
	local last: string? = nil
	for _, rarity in Rarities.List do
		local weight = odds[rarity.Id] or 0
		if weight > 0 then
			last = rarity.Id
			if roll < weight then
				return rarity.Id
			end
			roll -= weight
		end
	end
	return last -- arrondi des nombres à virgule : la dernière rareté possible
end

-- Un objet au hasard parmi ceux de la zone et de la rareté (Items.Pick : plusieurs objets par case
-- au catalogue v2, jamais un objet TutorialOnly) ; un Secret, toutes zones. nil si la case est vide.
local function drawItem(zone: number, rarityId: string): string?
	local item = Items.Pick(zone, rarityId :: Rarities.RarityId, random)
	return if item then item.Id else nil
end

-- Contenu d'un colis de la mise en rayon. Repli (V0 proposé, absent du doc) si la case (zone,
-- rareté) tirée est vide : la rareté tirable la plus proche en dessous, avec un avertissement par
-- case ; rien en dessous : nil (rayon laissé vide, signalé par fillStore). Le catalogue v2 n'a
-- aucune case vide qu'un tirage puisse atteindre (zone 1 : Communs seulement, ShelfBoxes.ZoneOdds) :
-- ce repli ne sert qu'à une Config incohérente. La rareté du contenu reste celle de son objet.
-- Mutation du colis (DEV-131, L-084 point 3) : tirée avec le contenu, jamais pour un objet
-- TutorialOnly (qu'aucun tirage ne donne : garde-fou).
local function drawMutation(itemId: string): Mutations.Mutation?
	local item = Items.ById[itemId]
	if item == nil or item.TutorialOnly then
		return nil
	end
	return Mutations.Roll(random)
end

local function drawContent(tier: string, zone: number): Content?
	local rarity = drawRarity(tier, zone)
	if rarity == nil then
		return nil
	end
	local itemId = drawItem(zone, rarity)
	if itemId then
		return { Rarity = rarity, ItemId = itemId, Mutation = drawMutation(itemId) }
	end
	-- Rarities.List va de Commun à Secret : en partant de la fin, la première rareté plus basse qui
	-- a un objet est la plus proche en dessous.
	local drawnOrder = Rarities.ById[rarity].Order
	local list = Rarities.List
	for index = #list, 1, -1 do
		local candidate = list[index]
		if candidate.Order < drawnOrder then
			local fallbackRarity: string = candidate.Id
			local fallbackItem = drawItem(zone, fallbackRarity)
			if fallbackItem then
				warnOnce(
					`empty.{zone}.{rarity}`,
					`aucun objet {rarity} tirable en zone {zone} (Config/Items) : ces colis reçoivent un objet {fallbackRarity} à la place`
				)
				return { Rarity = fallbackRarity, ItemId = fallbackItem, Mutation = drawMutation(fallbackItem) }
			end
		end
	end
	return nil
end

-- Types des colis d'un remplissage, du plus rare au plus courant (1 Luxe, 3 Premium, 6 Standard) :
-- si un magasin a moins de rayons que de colis, ce sont des Standard qui manquent.
local function layoutTiers(): { string }
	local list: { string } = {}
	local order = Balance.Heist.TierOrder
	for index = #order, 1, -1 do
		local tier = order[index]
		local info = Balance.Heist.BoxTiers[tier]
		local count = if info then info.Count else 0
		for _ = 1, count do
			table.insert(list, tier)
		end
	end
	return list
end

-- Colis des rayons -----------------------------------------------------------------------------

-- Modèle `name` de Clément (BOX_<Rareté> ou BOX_<Tier>), cherché une fois par nom, ou nil.
local function boxTemplate(name: string): Instance?
	if templateSearched[name] then
		return templates[name]
	end
	templateSearched[name] = true
	local found: Instance? = nil
	for _, service in { ReplicatedStorage, ServerStorage } :: { Instance } do
		local assets = service:FindFirstChild(ASSETS_NAME)
		local candidate = if assets then assets:FindFirstChild(name, true) else nil
		if candidate and (candidate:IsA("Model") or candidate:IsA("BasePart")) then
			found = candidate
			break
		end
	end
	if found then
		templates[name] = found
	end
	return found
end

-- Bloc V0 : pivot en bas au centre (10.1), comme un BOX_* livré.
local function makeV0Box(tier: string): Model
	local look = V0_LOOKS[tier] or V0_LOOKS.Standard
	local size = look.Size
	local model = Instance.new("Model")
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = size
	body.CFrame = CFrame.new(0, size.Y / 2, 0)
	body.Color = look.Color
	body.Material = look.Material
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.PivotOffset = CFrame.new(0, -size.Y / 2, 0)
	body.Parent = model
	model.PrimaryPart = body
	local trim = look.Trim
	if trim then
		local bands: { CFrame } = {}
		local bandSize: Vector3
		if look.Bands == 1 then
			-- bande de scellé sur le dessus, d'un bord à l'autre
			bandSize = Vector3.new(size.X + 0.04, 0.06, size.Z * 0.25)
			table.insert(bands, CFrame.new(0, size.Y + 0.01, 0))
		else
			-- deux cercles dorés autour de la caisse
			bandSize = Vector3.new(size.X + 0.08, size.Y * 0.12, size.Z + 0.08)
			table.insert(bands, CFrame.new(0, size.Y * 0.25, 0))
			table.insert(bands, CFrame.new(0, size.Y * 0.75, 0))
		end
		for index, cf in bands do
			local band = Instance.new("Part")
			band.Name = `Trim_{index}`
			band.Size = bandSize
			band.CFrame = cf
			band.Color = trim
			band.Material = if look.Bands == 2 then Enum.Material.Metal else Enum.Material.SmoothPlastic
			band.TopSurface = Enum.SurfaceType.Smooth
			band.BottomSurface = Enum.SurfaceType.Smooth
			band.Parent = model
		end
	end
	return model
end

-- Modèle d'un colis de type `tier` pour l'emplacement `slot`, avec son étiquette BB_Box : celui de la
-- rareté `rarity` de la caisse, tirée à la mise en rayon (BOX_<Rareté>, L-097 point 3 ; ancien déroulé :
-- la rareté de son contenu), sinon BOX_<Tier>, sinon le bloc V0. Seul le modèle change : le type reste la
-- règle de jeu (prise, chances, ShelfSlot). `content` nil (Features.ShelfOpen, vague 32) : étiquette à la
-- rareté seule, attribut BoxRarity ; jamais d'ItemId, de Rarity d'objet ni de mutation sur le colis.
local function makeBoxModel(slot: Slot, tier: string, rarity: string, content: Content?): Model
	local model: Model? = nil
	local template = boxTemplate(BOX_PREFIX .. rarity) or boxTemplate(BOX_PREFIX .. tier)
	if template then
		local clone = template:Clone() -- nil si le modèle n'est pas Archivable
		if clone then
			for _, descendant in clone:GetDescendants() do
				if descendant:IsA("LuaSourceContainer") then
					descendant:Destroy() -- jamais de script dans un colis (contrat)
				end
			end
			if clone:IsA("Model") then
				model = clone
			elseif clone:IsA("BasePart") then
				local wrapper = Instance.new("Model")
				clone.Parent = wrapper
				wrapper.PrimaryPart = clone
				model = wrapper
			end
		end
	end
	local box = model or makeV0Box(tier)
	for _, descendant in box:GetDescendants() do
		if descendant:IsA("BasePart") then
			-- petit décor posé sur un rayon : ni collision, ni contact, ni requête (les rayons
			-- de ShelfBoxController et des vigiles le traversent)
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
	-- Jamais « BOX_… » dans la map : ce nom est celui de l'asset (ContractChecker).
	box.Name = string.format(BOX_NAME_FORMAT, slot.Number)
	box.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- le colis et son étiquette arrivent ensemble
	box:SetAttribute(SLOT_ID_ATTRIBUTE, slot.Id)
	box:SetAttribute(SLOT_ATTRIBUTE, slot.Name)
	box:SetAttribute(TIER_ATTRIBUTE, tier)
	if SHELF_OPEN then
		box:SetAttribute(ShelfOpenState.BoxRarityAttribute, rarity)
	end
	CollectionService:AddTag(box, SHELF_BOX_TAG)
	local ok, label
	if content then
		ok, label = pcall(CarryService.AttachBoxLabel, box, content.Rarity, content.ItemId, content.Mutation)
	else
		ok, label = pcall(CarryService.AttachBoxLabel, box, rarity, nil, nil)
	end
	if not ok then
		warnOnce("label.error", `CarryService.AttachBoxLabel : {label}`)
	elseif label == nil then
		warnOnce(`label.{tier}`, `colis {tier} de {slot.Id} : aucune étiquette BB_Box posée (colis sans pièce ?)`)
	end
	return box
end

local function setLanded(box: ShelfBox, landed: boolean)
	box.Landed = landed
	box.Model:SetAttribute(LANDED_ATTRIBUTE, landed)
end

-- Arrête le vol d'un colis et retire son modèle.
local function discard(box: ShelfBox)
	local stop = box.StopFlight
	if stop then
		box.StopFlight = nil
		stop()
	end
	box.Model:Destroy()
end

-- Pose un colis sur le rayon vide `slot`, en vol depuis `from` s'il est donné. `rarity` : rareté de la
-- caisse ; `content` : nil avec Features.ShelfOpen (tiré à la sortie, vague 32).
local function placeBox(slot: Slot, tier: string, rarity: string, content: Content?, from: Vector3?)
	local model = makeBoxModel(slot, tier, rarity, content)
	local box: ShelfBox = { Tier = tier, Rarity = rarity, Content = content, Model = model, Landed = false, StopFlight = nil }
	local target = slot.Attachment.WorldCFrame
	slot.Box = box
	if from == nil then
		setLanded(box, true)
		model:PivotTo(target)
		model.Parent = slot.Store.Folder
		return
	end
	setLanded(box, false)
	local start: Vector3 = from
	local rotation = target.Rotation
	local finish = target.Position
	local distance = (finish - start).Magnitude
	local height = math.clamp(distance * FLIGHT_ARC, FLIGHT_ARC_MIN, FLIGHT_ARC_MAX)
	local duration = math.clamp(distance / FLIGHT_SPEED, FLIGHT_MIN_TIME, FLIGHT_MAX_TIME)
	model:PivotTo(CFrame.new(start) * rotation)
	model.Parent = slot.Store.Folder
	box.StopFlight = animate(model, function(alpha: number): CFrame
		local position = start:Lerp(finish, alpha) + Vector3.new(0, 4 * height * alpha * (1 - alpha), 0)
		return CFrame.new(position) * rotation
	end, duration, function()
		box.StopFlight = nil
		if slot.Box == box then
			model:PivotTo(target)
			setLanded(box, true)
		end
	end)
end

local function removeBox(slot: Slot)
	local box = slot.Box
	slot.Box = nil
	if box then
		box.Opening = nil -- L-112 : une ouverture en cours s'arrête là (sa sortie différée ne fait plus rien)
		discard(box)
	end
end

-- Objets sortis des colis (L-112, Features.ShelfOpen) ------------------------------------------------

-- Trajectoire du vol de retour vers un rayon (la même que celle d'un colis rendu, placeBox) : de `start`
-- à `target` en arc, et sa durée.
local function flightPath(start: Vector3, target: CFrame): ((alpha: number) -> CFrame, number)
	local rotation = target.Rotation
	local finish = target.Position
	local distance = (finish - start).Magnitude
	local height = math.clamp(distance * FLIGHT_ARC, FLIGHT_ARC_MIN, FLIGHT_ARC_MAX)
	local duration = math.clamp(distance / FLIGHT_SPEED, FLIGHT_MIN_TIME, FLIGHT_MAX_TIME)
	return function(alpha: number): CFrame
		local position = start:Lerp(finish, alpha) + Vector3.new(0, 4 * height * alpha * (1 - alpha), 0)
		return CFrame.new(position) * rotation
	end,
		duration
end

-- $/s de l'objet (attribut Income, pour BB_Item), comme une fois exposé (DisplayService) : revenu de sa
-- zone (celle du magasin pour un Secret, qui n'en a pas) et de sa rareté, mutation comprise.
local function itemIncome(zone: number, content: Content): number
	local def = Items.ById[content.ItemId]
	local itemZone: number = if def and def.Zone then def.Zone else zone
	return Formulas.ItemIncome(itemZone, content.Rarity) * Mutations.IncomeMultiplier(content.Mutation)
end

-- Bloc V0 d'un objet : pivot en bas au centre (10.1), comme un ITM_* livré.
local function makeV0Item(color: Color3): Model
	local model = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = V0_ITEM_SIZE
	root.CFrame = CFrame.new(0, V0_ITEM_SIZE.Y / 2, 0)
	root.Color = color
	root.Material = Enum.Material.SmoothPlastic
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.PivotOffset = CFrame.new(0, -V0_ITEM_SIZE.Y / 2, 0)
	root.Parent = model
	model.PrimaryPart = root
	return model
end

-- Modèle de l'objet sorti sur l'emplacement `slot` : copie de ITM_<ItemId> de Clément (cherchée comme
-- les BOX_*), sinon le bloc V0 à la couleur de sa rareté ; à l'échelle de sa mutation de taille (comme
-- sur un présentoir) ; tag et attributs du contrat (Shared/ShelfOpenState, voir l'en-tête). Ni BB_Item
-- ni halo ici : le client les pose d'après les attributs.
local function makeItemModel(slot: Slot, info: ItemInfo): Model
	local content = info.Content
	local def = Items.ById[content.ItemId]
	local rarity = Rarities.ById[content.Rarity]
	local model: Model? = nil
	local template = if def then boxTemplate(def.Asset) else nil
	if template then
		local clone = template:Clone() -- nil si le modèle n'est pas Archivable
		if clone then
			for _, descendant in clone:GetDescendants() do
				if descendant:IsA("LuaSourceContainer") then
					descendant:Destroy() -- jamais de script dans un objet (contrat 10.4)
				end
			end
			if clone:IsA("Model") then
				model = clone
			elseif clone:IsA("BasePart") then
				local wrapper = Instance.new("Model")
				clone.Parent = wrapper
				wrapper.PrimaryPart = clone
				model = wrapper
			end
		end
	end
	local object = model or makeV0Item(if rarity then rarity.Color else Color3.new(1, 1, 1))
	for _, descendant in object:GetDescendants() do
		if descendant:IsA("BasePart") then
			-- posé sur un rayon comme un colis : ni collision, ni contact, ni requête
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
	local scale = Mutations.Scale(content.Mutation)
	if scale ~= 1 then
		local ok, problem = pcall(object.ScaleTo, object, scale)
		if not ok then
			warnOnce(`scale.{content.ItemId}`, `{content.ItemId} : Model:ScaleTo({scale}) a échoué ({problem}), taille normale`)
		end
	end
	-- Jamais « ITM_… » dans la map : ce nom est celui de l'asset (ContractChecker).
	object.Name = string.format(ITEM_NAME_FORMAT, slot.Number)
	object.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local mutation = content.Mutation
	object:SetAttribute(SLOT_ID_ATTRIBUTE, slot.Id)
	object:SetAttribute(SLOT_ATTRIBUTE, slot.Name)
	object:SetAttribute(TIER_ATTRIBUTE, info.Tier)
	object:SetAttribute(ITEM_ID_ATTRIBUTE, content.ItemId)
	object:SetAttribute(RARITY_ATTRIBUTE, content.Rarity)
	object:SetAttribute(MUTATION_SIZE_ATTRIBUTE, if mutation then mutation.Size else nil)
	object:SetAttribute(MUTATION_EFFECT_ATTRIBUTE, if mutation then mutation.Effect else nil)
	object:SetAttribute(INCOME_ATTRIBUTE, itemIncome(slot.Store.Zone, content))
	object:SetAttribute(ShelfOpenState.LuckAttribute, info.Luck)
	object:SetAttribute(ShelfOpenState.ReservedByAttribute, info.OpenerId)
	object:SetAttribute(ShelfOpenState.ReservedUntilAttribute, info.ReservedUntilServer)
	CollectionService:AddTag(object, ShelfOpenState.ItemTag)
	return object
end

local function setItemLanded(item: ShelfItem, landed: boolean)
	item.Landed = landed
	item.Model:SetAttribute(LANDED_ATTRIBUTE, landed)
end

-- Arrête le vol d'un objet et retire son modèle.
local function discardItem(item: ShelfItem)
	local stop = item.StopFlight
	if stop then
		item.StopFlight = nil
		stop()
	end
	item.Model:Destroy()
end

-- Pose l'objet `info` sur le rayon vide `slot`, à la place de son colis, tourné comme le ShelfSlot ; en
-- vol depuis `from` s'il est donné (objet qui revient).
local function placeItem(slot: Slot, info: ItemInfo, from: Vector3?)
	local model = makeItemModel(slot, info)
	local item: ShelfItem = { Info = info, Model = model, Landed = false, StopFlight = nil }
	local target = slot.Attachment.WorldCFrame
	slot.Item = item
	if from == nil then
		setItemLanded(item, true)
		model:PivotTo(target)
		model.Parent = slot.Store.Folder
		return
	end
	setItemLanded(item, false)
	local start: Vector3 = from
	local path, duration = flightPath(start, target)
	model:PivotTo(path(0))
	model.Parent = slot.Store.Folder
	item.StopFlight = animate(model, path, duration, function()
		item.StopFlight = nil
		if slot.Item == item then
			model:PivotTo(target)
			setItemLanded(item, true)
		end
	end)
end

local function removeItem(slot: Slot)
	local item = slot.Item
	slot.Item = nil
	if item then
		discardItem(item)
	end
end

-- Nombre d'ouvertures en cours dans le magasin.
local function openingCount(store: Store): number
	local count = 0
	for _, slot in store.Slots do
		local box = slot.Box
		if box ~= nil and box.Opening ~= nil then
			count += 1
		end
	end
	return count
end

-- Une ouverture est en cours dans le magasin, ou un objet sorti y est encore réservé à son ouvreur :
-- le rideau ne tombe pas et le remplissage attend (voir l'en-tête).
local function storeBusy(store: Store): boolean
	local now = os.clock()
	for _, slot in store.Slots do
		local box, item = slot.Box, slot.Item
		if box ~= nil and box.Opening ~= nil then
			return true
		end
		if item ~= nil and now < item.Info.ReservedUntil then
			return true
		end
	end
	return false
end

-- `player` attend ici la sortie d'un colis qu'il a ouvert, ou l'objet qu'il a sorti lui est encore
-- réservé : magasin fermé, il n'est pas sorti du magasin et peut encore prendre son objet.
local function hasClaim(store: Store, player: Player): boolean
	local now = os.clock()
	local userId = player.UserId
	for _, slot in store.Slots do
		local box, item = slot.Box, slot.Item
		local opening = if box then box.Opening else nil
		if opening ~= nil and opening.ByUserId == userId then
			return true
		end
		if item ~= nil and item.Info.OpenerId == userId and now < item.Info.ReservedUntil then
			return true
		end
	end
	return false
end

-- Le « ? » des témoins du magasin se vide (WitnessService.Calm : tous les témoins du magasin, donc
-- seulement quand plus aucune ouverture n'y est en cours).
local function calmWitnesses(store: Store)
	local api = witnessApi
	if api == nil then
		return
	end
	local ok, err = pcall(api.Calm, store.Model)
	if not ok then
		warn(`[StoreHeistService] WitnessService.Calm({store.Id}) : {err}`)
	end
end

local function cancelHolds(store: Store)
	for player, hold in holds do
		if hold.Slot.Store == store then
			holds[player] = nil
		end
	end
	for player, hold in openHolds do
		if hold.Slot.Store == store then
			openHolds[player] = nil
		end
	end
end

-- Nouveau tirage du magasin (L-031, L-033, 5.12) : retire tous ses colis (posés ou en vol de
-- retour), oublie ceux qui en sont sortis, puis répartit au hasard un jeu neuf de colis sur ses
-- rayons, chacun avec son contenu tiré. Renvoie le nombre de colis posés.
local function fillStore(store: Store): number
	store.RefillPending = false
	cancelHolds(store)
	for payload, out in outBoxes do
		if out.Slot.Store == store then
			outBoxes[payload] = nil -- tirage précédent : il ne reviendra pas
		end
	end
	for payload, out in outItems do
		if out.Slot.Store == store then
			outItems[payload] = nil -- objet sorti d'un colis du tirage précédent : il ne reviendra pas
		end
	end
	for _, slot in store.Slots do
		removeBox(slot)
		removeItem(slot)
	end
	local tiers = layoutTiers()
	local count = 0
	for index, slot in shuffled(store.Slots) do
		local tier = tiers[index]
		if tier == nil then
			break -- plus de rayons que de colis : le reste reste vide
		end
		-- Vague 32 (Features.ShelfOpen) : la rareté de la caisse seule ; le contenu est tiré à la sortie.
		local content = if SHELF_OPEN then nil else drawContent(tier, store.Zone)
		local rarity = if SHELF_OPEN then drawRarity(tier, store.Zone) elseif content then content.Rarity else nil
		if rarity then
			placeBox(slot, tier, rarity, content, nil)
			count += 1
		else
			warnOnce(
				`draw.{tier}.{store.Zone}`,
				`aucun objet ne peut sortir d'un colis {tier} en zone {store.Zone} (Config : ShelfBoxes, Rarities, Items) : rayon laissé vide`
			)
		end
	end
	return count
end

-- Rideau -------------------------------------------------------------------------------------

local function stopShutter(store: Store)
	local stop = store.StopShutter
	if stop then
		store.StopShutter = nil
		stop()
	end
end

local function setShutterSolid(store: Store, solid: boolean)
	for _, part in store.ShutterParts do
		part.CanCollide = solid
	end
end

local function restoreShutterCollide(store: Store)
	for part, canCollide in store.ShutterCollide do
		part.CanCollide = canCollide
	end
end

-- Baisse le rideau : il tombe de sa hauteur, et devient solide une fois en bas (SHUTTER_EXIT_GRACE s).
local function lowerShutter(store: Store)
	local shutter = store.Shutter
	if shutter == nil or store.ShutterDown then
		return
	end
	store.ShutterDown = true
	store.ShutterToken += 1
	local token = store.ShutterToken
	stopShutter(store)
	setShutterSolid(store, false)
	local from = shutter:GetPivot()
	local to = store.ShutterClosed
	store.StopShutter = animate(shutter, function(alpha: number): CFrame
		return from:Lerp(to, TweenService:GetValue(alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.In))
	end, SHUTTER_FALL_TIME)
	task.delay(SHUTTER_EXIT_GRACE, function()
		if store.ShutterToken == token and store.ShutterDown and stores[store.Model] == store then
			setShutterSolid(store, true)
		end
	end)
end

-- Remonte le rideau en position ouverte (d'un coup si `instant`).
local function raiseShutter(store: Store, instant: boolean)
	local shutter = store.Shutter
	if shutter == nil or not store.ShutterDown then
		return
	end
	store.ShutterDown = false
	store.ShutterToken += 1
	stopShutter(store)
	restoreShutterCollide(store)
	local to = store.ShutterOpen
	if instant then
		shutter:PivotTo(to)
		return
	end
	local from = shutter:GetPivot()
	store.StopShutter = animate(shutter, function(alpha: number): CFrame
		return from:Lerp(to, TweenService:GetValue(alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
	end, SHUTTER_RISE_TIME)
end

-- Sortie devant la vitrine -----------------------------------------------------------------------

-- Hauteur du sol sous `position`, cherchée autour de `referenceY` ; personnages et pièces sans
-- collision ignorés.
local function groundY(position: Vector3, referenceY: number): number
	local characters: { Instance } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			table.insert(characters, character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = characters
	params.RespectCanCollide = true
	params.IgnoreWater = true
	local origin = Vector3.new(position.X, referenceY + GROUND_RAY_UP, position.Z)
	local result = Workspace:Raycast(origin, Vector3.new(0, -(GROUND_RAY_UP + GROUND_RAY_DOWN), 0), params)
	return if result then result.Position.Y else referenceY
end

-- Point au sol devant la vitrine, au hasard sur sa largeur, et direction vers la rue.
local function ejectSpot(store: Store): (Vector3, Vector3)
	local pivot = store.Model:GetPivot()
	local center = if store.Bounds then store.Bounds.Position else pivot.Position
	local window = store.Window
	-- Vers la rue : du centre du magasin vers sa vitrine (à défaut, l'avant du pivot, 10.1).
	local front = pivot.Position
	local out = flat(pivot.LookVector)
	local windowCf: CFrame? = nil
	local windowSize = Vector3.zero
	if window then
		local cf, size = boxOf(window)
		windowCf, windowSize = cf, size
		front = cf.Position
		local toWindow = flat(cf.Position - center)
		if toWindow.Magnitude > 1e-3 then
			out = toWindow
		end
	end
	out = if out.Magnitude > 1e-3 then out.Unit else Vector3.zAxis
	local side = Vector3.yAxis:Cross(out).Unit
	local halfWidth = if windowCf then math.max(extentAlong(windowCf, windowSize, side) / 2 - 1, 0) else 0
	local spot = front + out * EJECT_DISTANCE + side * ((random:NextNumber() * 2 - 1) * halfWidth)
	return Vector3.new(spot.X, groundY(spot, pivot.Y), spot.Z), out
end

-- Sort `player` devant la vitrine de `store`, tourné vers la rue.
local function moveOut(store: Store, player: Player, root: BasePart, humanoid: Humanoid)
	local character = player.Character
	if character == nil then
		return
	end
	local ground, out = ejectSpot(store)
	-- R15 : HipHeight = du bas du HumanoidRootPart au sol ; R6 : jambes de 2 studs.
	local hip = if humanoid.RigType == Enum.HumanoidRigType.R15 then humanoid.HipHeight else 2
	local position = ground + Vector3.new(0, hip + root.Size.Y / 2 + EJECT_LIFT, 0)
	local target = CFrame.lookAt(position, position + out)
	AntiCheatService.Allow(player, 0, "StoreHeistService (sortie du magasin)") -- déplacement du code (DEV-060)
	character:PivotTo(target * root.CFrame:ToObjectSpace(character:GetPivot()))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

-- Sort les joueurs qui sont dans le volume Bounds : ceux sans colis, ou tous si `everyone`.
-- Renvoie les joueurs sortis.
local function ejectInside(store: Store, everyone: boolean): { Player }
	local moved: { Player } = {}
	local bounds = store.Bounds
	if bounds == nil then
		return moved
	end
	for _, player in Players:GetPlayers() do
		local root, humanoid = rootOf(player)
		-- L-112 : celui qui attend la sortie de son colis, ou dont l'objet sorti est encore réservé, reste.
		if root and humanoid and inside(bounds, root.Position)
			and (everyone or not (isCarrying(player) or hasClaim(store, player))) then
			moveOut(store, player, root, humanoid)
			table.insert(moved, player)
		end
	end
	return moved
end

-- Ce qui retient le rideau (voir l'en-tête) : un joueur qui porte un colis ou un vigile dans le
-- volume Bounds, décrit pour la sortie ; nil si plus personne ne doit sortir.
local function shutterBlocker(store: Store): string?
	-- L-112 (V0, précision de l'équilibrage, même esprit que L-064) : le rideau ne tombe pas tant qu'une
	-- ouverture lancée dans ce magasin n'est pas finie et que la réservation de son objet sorti
	-- (ShelfReservedUntil) n'est pas passée ; sinon un gros tirage (6 à 8,4 s de montée) ne pourrait
	-- jamais être pris dans les 10 s du chrono.
	if storeBusy(store) then
		return "ouverture en cours ou objet sorti encore réservé"
	end
	local bounds = store.Bounds
	if bounds == nil then
		return nil
	end
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root and isCarrying(player) and inside(bounds, root.Position) then
			return `{player.Name} porte un colis`
		end
	end
	local guards = Workspace:FindFirstChild(GUARDS_FOLDER)
	if guards then
		for _, guard in guards:GetChildren() do
			local root = if guard:IsA("Model") then guard:FindFirstChild("HumanoidRootPart") else nil
			if root and root:IsA("BasePart") and inside(bounds, root.Position) then
				return `vigile {guard.Name}`
			end
		end
	end
	return nil
end

-- Rideau en attente : il tombe dès que plus personne ne doit sortir. Renvoie true s'il vient de
-- tomber, sinon false et ce qui le retient encore (nil s'il n'y a plus rien à attendre).
local function lowerWhenClear(store: Store): (boolean, string?)
	if not store.ShutterPending then
		return false, nil
	end
	if store.Open or not WindowService.IsBroken(store.Id) then
		store.ShutterPending = false
		return false, nil
	end
	local blocker = shutterBlocker(store)
	if blocker then
		return false, blocker
	end
	store.ShutterPending = false
	lowerShutter(store)
	return true, nil
end

-- Fermé pour le voleur seulement (voir l'en-tête) ------------------------------------------------------

-- Écrit dans l'attribut CLOSED_ATTRIBUTE du joueur les magasins fermés (Closed) pour lui, triés ;
-- l'attribut est retiré quand il n'y en a plus.
local function publishClosed(player: Player)
	if player.Parent ~= Players then
		return
	end
	local ids: { string } = {}
	for _, store in stores do
		if store.Locked[player] == "Closed" and not store.CurtainHeld then
			table.insert(ids, store.Id)
		end
	end
	table.sort(ids)
	local value: string? = if #ids > 0 then table.concat(ids, CLOSED_SEPARATOR) else nil
	if player:GetAttribute(CLOSED_ATTRIBUTE) ~= value then
		player:SetAttribute(CLOSED_ATTRIBUTE, value)
	end
end

-- Il vient de prendre un colis sur un rayon de ce magasin : fermé pour lui (d'abord en sortie).
local function lockFor(store: Store, player: Player)
	store.Locked[player] = "Leaving"
end

local function unlock(store: Store, player: Player, why: string)
	local state = store.Locked[player]
	if state == nil then
		return
	end
	store.Locked[player] = nil
	if state == "Closed" then
		publishClosed(player)
	end
	log(`{store.Id} rouvert pour {player.Name} ({why})`)
end

local function unlockAll(store: Store, why: string)
	for player in table.clone(store.Locked) do
		unlock(store, player, why)
	end
end

-- Ce qui retient les rideaux locaux de ce magasin (voir l'en-tête), décrit pour la sortie ; nil si
-- aucun vigile n'y est ni n'est sur le point d'y entrer.
local function curtainBlocker(store: Store): string?
	local bounds = store.Bounds
	if bounds == nil or store.ShutterDown then
		return nil
	end
	-- Vigiles qui rentrent vers la réserve de ce magasin (a70).
	local returning: { any } = {}
	local getReturning = returningGuards
	if getReturning then
		local ok, roots = pcall(getReturning, store.Model)
		if ok and type(roots) == "table" then
			returning = roots
		end
	end
	local guards = Workspace:FindFirstChild(GUARDS_FOLDER)
	if guards then
		for _, guard in guards:GetChildren() do
			local root = if guard:IsA("Model") then guard:FindFirstChild("HumanoidRootPart") else nil
			-- Un vigile qui rentre et qui est déjà dans le volume Bounds est passé derrière le rideau : il ne
			-- le traversera plus (celui qui vient d'attraper le voleur dans le magasin, Cantin 2026-11-11).
			if root and root:IsA("BasePart") and distanceTo(bounds, root.Position) <= CURTAIN_GUARD_MARGIN
				and not (table.find(returning, root) ~= nil and inside(bounds, root.Position)) then
				return `vigile {guard.Name} dans le magasin`
			end
		end
	end
	-- Vigile qui rentre et qui va passer le rideau (encore dehors, tout près).
	for _, root in returning do
		if typeof(root) == "Instance" and root:IsA("BasePart") and not inside(bounds, root.Position)
			and distanceTo(bounds, root.Position) <= CURTAIN_RETURN_MARGIN then
			local name = if root.Parent then root.Parent.Name else "?"
			return `vigile {name} qui rentre vers la réserve`
		end
	end
	return nil
end

-- Tick : rideaux locaux retenus ou non par un vigile ; un voleur en sortie passe à Closed dès qu'il
-- quitte le volume Bounds ou ne porte plus le colis ; un voleur Closed qui est dans Bounds en est
-- sorti devant la vitrine (colis gardé).
local function stepLocks(store: Store)
	if next(store.Locked) == nil then
		store.CurtainHeld = false
		return
	end
	local blocker = curtainBlocker(store)
	local held = blocker ~= nil
	if held ~= store.CurtainHeld then
		store.CurtainHeld = held
		local any = false
		for player, state in store.Locked do
			if state == "Closed" then
				any = true
				publishClosed(player)
			end
		end
		if any then
			log(if blocker
				then `{store.Id} : rideau local levé chez ses voleurs ({blocker})`
				else `{store.Id} : rideau local baissé chez ses voleurs, plus de vigile dans le magasin`)
		end
	end
	local bounds = store.Bounds
	for player, state in table.clone(store.Locked) do
		if player.Parent ~= Players then
			store.Locked[player] = nil
			continue
		end
		local root, humanoid = rootOf(player)
		local isInside = root ~= nil and bounds ~= nil and inside(bounds, root.Position)
		if state == "Leaving" then
			if isInside and isCarrying(player) then
				continue -- il sort avec son colis, rideau encore levé pour lui
			end
			store.Locked[player] = "Closed"
			publishClosed(player)
			log(`{store.Id} fermé pour {player.Name} jusqu'au retour de son vigile`)
		end
		if isInside and root and humanoid then
			local kickAfter = store.KickAfter[player]
			if kickAfter ~= nil and os.clock() < kickAfter then
				continue -- attrapé : le coup du vigile et l'étourdissement d'abord, sur place
			end
			store.KickAfter[player] = nil
			moveOut(store, player, root, humanoid)
			log(`{player.Name} sorti de {store.Id} (fermé pour lui)`)
		end
	end
end

-- Chrono -----------------------------------------------------------------------------------------

local function hideTimer(store: Store, player: Player)
	if store.Viewers[player] then
		store.Viewers[player] = nil
		if player.Parent == Players then
			Net.Server.HeistTimer:Fire(player, store.Id, 0)
		end
	end
end

local function showTimer(store: Store, player: Player)
	if not store.Viewers[player] then
		store.Viewers[player] = true
		Net.Server.HeistTimer:Fire(player, store.Id, store.EndsAt)
	end
end

-- Chrono montré aux joueurs proches sans colis, masqué pour ceux qui en portent un et pour ceux
-- pour qui le magasin est fermé.
local function updateViewers(store: Store)
	local center = if store.Bounds then store.Bounds.Position else store.Model:GetPivot().Position
	for _, player in Players:GetPlayers() do
		if SHELF_OPEN and store.Entered[player] then
			showTimer(store, player) -- L-118 : le vigile viendra pour lui à la fin, dedans ou dehors, objet ou non
		elseif isCarrying(player) or store.Locked[player] ~= nil then
			hideTimer(store, player)
		elseif not store.Viewers[player] then
			local root = rootOf(player)
			if root and (root.Position - center).Magnitude <= TIMER_RADIUS then
				showTimer(store, player)
			end
		end
	end
end

-- Ouverture et fermeture ---------------------------------------------------------------------------

local function setHeistAttributes(store: Store)
	local model = store.Model
	model:SetAttribute(OPEN_ATTRIBUTE, store.Open)
	if store.Open then
		local headStartLeft = math.max(store.ExclusiveUntil - os.clock(), 0)
		model:SetAttribute(ENDS_AT_ATTRIBUTE, store.EndsAt)
		model:SetAttribute(EXCLUSIVE_ATTRIBUTE, Workspace:GetServerTimeNow() + headStartLeft)
		model:SetAttribute(BREAKER_ATTRIBUTE, if store.Breaker then store.Breaker.UserId else nil)
	else
		model:SetAttribute(ENDS_AT_ATTRIBUTE, nil)
		model:SetAttribute(EXCLUSIVE_ATTRIBUTE, nil)
		model:SetAttribute(BREAKER_ATTRIBUTE, nil)
	end
end

-- Définie plus bas (Prise).
local grabRefusal: (player: Player, slot: Slot) -> string?

-- Ferme le magasin : plus de prise, chrono masqué, joueurs sans colis sortis, rideau baissé si la
-- vitrine est cassée (tout de suite, ou dès que porteurs et vigiles sont sortis), puis nouveau
-- tirage si RefillAll est passé pendant le chrono. L-112 : une ouverture lancée va au bout, son
-- ouvreur reste et garde le droit de prendre son objet tant qu'il lui est réservé (voir l'en-tête).
local function closeStore(store: Store)
	if not store.Open then
		return
	end
	store.Open = false
	store.Token += 1
	store.Breaker = nil
	store.ClosedAt = os.clock()
	setHeistAttributes(store)
	-- Maintiens annulés, sauf celui d'un ouvreur sur son objet encore réservé (L-112) ; dans l'ancien
	-- déroulé, tous (magasin fermé = prise refusée).
	for player, hold in holds do
		if hold.Slot.Store == store and grabRefusal(player, hold.Slot) ~= nil then
			holds[player] = nil
		end
	end
	for player, hold in openHolds do
		if hold.Slot.Store == store then
			openHolds[player] = nil -- magasin fermé : ouverture refusée
		end
	end
	for player in table.clone(store.Viewers) do
		hideTimer(store, player)
	end
	store.ShutterPending = WindowService.IsBroken(store.Id)
	local moved = ejectInside(store, false)
	for _, player in moved do
		Net.Server.Notify:Fire(player, MESSAGES.Closed, "Warning")
	end
	local _, blocker = lowerWhenClear(store)
	local shutterText = if store.ShutterDown
		then "rideau baissé"
		elseif blocker then `rideau baissé dès que plus personne n'est dedans (pour l'instant : {blocker})`
		else "vitrine intacte, rideau levé"
	log(`{store.Id} fermé, {shutterText} ; {#moved} joueur(s) sans colis sorti(s)`)
	-- L-112 : remplissage reporté tant qu'une ouverture est en cours ou qu'un objet est réservé (step).
	if store.RefillPending and not storeBusy(store) then
		log(`{store.Id} : remplissage reporté à la fermeture, {fillStore(store)} colis répartis au hasard`)
	end
end

-- Fin du chrono du vigile (L-118 points 8 et 9) : le vigile sort et poursuit chaque intrus, même sans objet
-- (ceux du magasin d'abord, puis les autres ; plafonds de GuardService) ; personne n'est sorti du magasin.
local function chronoEnd(store: Store)
	store.ChronoOver = true
	for player in table.clone(store.Viewers) do
		hideTimer(store, player)
	end
	local inStore: { Player } = {}
	local outside: { Player } = {}
	local bounds = store.Bounds
	for player in store.Entered do
		local root = rootOf(player)
		if player.Parent == Players and root then
			table.insert(if bounds and inside(bounds, root.Position) then inStore else outside, player)
		end
	end
	local sent = 0
	local chase = chaseIntruder
	if chase then
		for _, list in { inStore, outside } do
			for _, player in list do
				local ok, started = pcall(chase, player, store.Model)
				if ok and started == true then
					sent += 1
				elseif not ok then
					warn(`[StoreHeistService] GuardService.ChaseIntruder({player.Name}) : {started}`)
				end
			end
		end
	end
	log(`{store.Id} : fin du chrono, {sent} vigile(s) sorti(s) pour {#inStore + #outside} intrus ({#inStore} dans le magasin)`)
end

-- Entrées et sorties (L-118 point 8 c) : entré pendant l'ouverture, un joueur reste libre dans le magasin,
-- même après le chrono ; dès qu'il en sort, le rideau tombe pour lui (Closed) jusqu'à la réouverture.
-- Après le chrono, celui qui n'y était pas n'entre plus : il est sorti devant la vitrine.
local function stepEntries(store: Store)
	local bounds = store.Bounds
	if bounds == nil then
		return
	end
	for _, player in Players:GetPlayers() do
		if store.Locked[player] ~= nil then
			continue -- stepLocks le sort s'il revient
		end
		local root, humanoid = rootOf(player)
		if root and inside(bounds, root.Position) then
			if store.Entered[player] then
				continue
			end
			if not store.ChronoOver then
				store.Entered[player] = true
				log(`{player.Name} entre dans {store.Id}`)
			elseif humanoid then
				moveOut(store, player, root, humanoid)
				Net.Server.Notify:Fire(player, MESSAGES.Closed, "Warning")
			end
		elseif store.Entered[player] then
			store.Locked[player] = "Closed"
			publishClosed(player)
			if not store.ChronoOver and not isCarrying(player) then
				-- Cantin (2026-11-13) : entré puis sorti sans rien, il n'a rien volé, c'est fini pour lui : plus
				-- intrus (aucun vigile pour lui à la fin du chrono) et plus de chrono.
				store.Entered[player] = nil
				hideTimer(store, player)
				log(`{player.Name} sorti de {store.Id} sans objet : rideau baissé pour lui, plus de chrono ni de vigile`)
			else
				log(`{player.Name} sorti de {store.Id} : rideau baissé pour lui jusqu'à la réouverture`)
			end
		end
	end
end

-- Un joueur vivant est-il dans le volume Bounds du magasin ?
local function anyoneInside(store: Store): boolean
	local bounds = store.Bounds
	if bounds == nil then
		return false
	end
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root and inside(bounds, root.Position) then
			return true
		end
	end
	return false
end

-- `endsAt` (L-118 point 9, Features.ShelfOpen) : fin du chrono du vigile lancé au premier coup sur la
-- vitrine (WindowService) ; sans lui, Balance.Heist.Duration s à partir de maintenant.
local function openStore(store: Store, breaker: Player?, endsAt: number?)
	if store.Open then
		return
	end
	local now = Workspace:GetServerTimeNow()
	local duration = if SHELF_OPEN and endsAt then math.max(endsAt - now, 0) else Balance.Heist.Duration
	store.Open = true
	store.Token += 1
	local token = store.Token
	store.Breaker = if breaker and breaker.Parent == Players then breaker else nil
	store.ExclusiveUntil = os.clock() + Balance.Heist.BreakerHeadStart
	store.EndsAt = now + duration
	store.Entered = {}
	store.ChronoOver = false
	store.ShutterPending = false
	raiseShutter(store, true) -- au cas où il serait resté baissé
	setHeistAttributes(store)
	local first = store.Breaker
	if first and not isCarrying(first) then
		showTimer(store, first)
	end
	updateViewers(store)
	task.delay(duration, function()
		if store.Token == token and stores[store.Model] == store then
			if SHELF_OPEN then
				chronoEnd(store) -- L-118 : le magasin reste ouvert pour ceux qui y sont
			else
				closeStore(store)
			end
		end
	end)
	log(
		`{store.Id} ouvert, chrono du vigile {math.round(duration * 10) / 10} s, par {if first then first.Name else "?"} ({Balance.Heist.BreakerHeadStart} s d'avance pour lui)`
	)
end

-- Prise ----------------------------------------------------------------------------------------------

-- Temps de prise d'un colis de type `tier` (ou de l'objet sorti d'un tel colis, L-112).
local function grabTime(tier: string): number
	local info = Balance.Heist.BoxTiers[tier]
	return if info then info.GrabTime else 0
end

-- Raison pour laquelle `player` ne peut ni prendre ni ouvrir sur `slot`, quoi qui s'y trouve (magasin
-- fermé pour lui, mains pleines, pas de personnage vivant, hors du volume Bounds, trop loin), ou nil.
local function reachRefusal(player: Player, slot: Slot): string?
	local store = slot.Store
	if store.Locked[player] then
		return "magasin fermé pour lui : son vigile n'est pas encore rentré"
	end
	if isCarrying(player) then
		return "mains pleines"
	end
	local root = rootOf(player)
	if root == nil then
		return "pas de personnage vivant"
	end
	local bounds = store.Bounds
	if bounds == nil then
		return "magasin sans volume Bounds"
	end
	if not inside(bounds, root.Position) then
		return "hors du volume Bounds"
	end
	local distance = (root.Position - slot.Attachment.WorldPosition).Magnitude
	if distance > Balance.Heist.GrabMaxDistance then
		return `trop loin ({math.round(distance * 10) / 10} studs)`
	end
	return nil
end

-- Raison du refus d'une prise sur `slot`, ou nil si elle est permise maintenant.
function grabRefusal(player: Player, slot: Slot): string?
	local store = slot.Store
	if SHELF_OPEN then
		-- L-112 : on ne prend plus un colis fermé, seulement l'objet sorti de son colis.
		local item = slot.Item
		if item == nil then
			return if slot.Box then "colis fermé : il s'ouvre d'abord sur son rayon (OpenShelfBox)" else "rayon vide"
		end
		if not item.Landed then
			return "objet en vol vers son rayon"
		end
		local reserved = os.clock() < item.Info.ReservedUntil
		if reserved and player.UserId ~= item.Info.OpenerId then
			return "objet encore réservé à celui qui a ouvert le colis"
		end
		-- L'ouvreur prend son objet réservé même après la fin du chrono (voir l'en-tête) ; sinon les
		-- règles du magasin : ouvert, avance du casseur.
		if not reserved then
			if not store.Open then
				return "magasin fermé"
			end
			if player ~= store.Breaker and os.clock() < store.ExclusiveUntil then
				return "avance du casseur"
			end
		end
		return reachRefusal(player, slot)
	end
	if not store.Open then
		return "magasin fermé"
	end
	local box = slot.Box
	if box == nil or not box.Landed then
		return "rayon vide"
	end
	if player ~= store.Breaker and os.clock() < store.ExclusiveUntil then
		return "avance du casseur"
	end
	return reachRefusal(player, slot)
end

-- Contenu remis au porteur : `base` (celui du colis, de type `baseTier`), ou celui de l'accroche du tuto
-- s'il est valide. Renvoie la table `base` elle-même quand rien ne change. Features.ShelfOpen (vague 32) :
-- appelée à la sortie avec base = { Rarity = rareté de la caisse, ItemId = "" } (contenu pas encore tiré) ;
-- une Rarity imposée seule tire alors un objet de cette rareté (itemId == "").
local function contentFor(player: Player, slot: Slot, baseTier: string, base: Content): (string, Content)
	local override = contentOverride
	if override == nil then
		return baseTier, base
	end
	local store = slot.Store
	local drawn: OverrideInfo = {
		StoreId = store.Id,
		SlotId = slot.Id,
		Zone = store.Zone,
		Tier = baseTier,
		Rarity = base.Rarity,
		ItemId = base.ItemId,
	}
	local ok, result = pcall(override, player, drawn)
	if not ok then
		warn(`[StoreHeistService] accroche SetContentOverride : {result}`)
		return baseTier, base
	end
	if result == nil then
		return baseTier, base
	end
	local function invalid(reason: string): (string, Content)
		warn(`[StoreHeistService] accroche SetContentOverride pour {player.Name} ignorée : {reason}`)
		return baseTier, base
	end
	if type(result) ~= "table" then
		return invalid(`elle renvoie un {type(result)}, pas une table`)
	end
	local tier = result.Tier or baseTier
	if type(tier) ~= "string" or Balance.Heist.BoxTiers[tier] == nil then
		return invalid(`type de colis inconnu ({tier})`)
	end
	local rarity: string = base.Rarity
	local itemId: string = base.ItemId
	local wantedItem = result.ItemId
	local wantedRarity = result.Rarity
	if wantedRarity ~= nil and type(wantedRarity) ~= "string" then
		return invalid(`rareté invalide ({wantedRarity})`)
	end
	if wantedItem ~= nil then
		local item = if type(wantedItem) == "string" then Items.ById[wantedItem] else nil
		if item == nil then
			return invalid(`objet inconnu ({wantedItem})`)
		end
		if wantedRarity ~= nil and wantedRarity ~= item.Rarity then
			return invalid(`{item.Id} est {item.Rarity}, pas {wantedRarity}`)
		end
		if item.Zone ~= nil and item.Zone ~= store.Zone then
			return invalid(`{item.Id} est un objet de la zone {item.Zone}, pas de la zone {store.Zone}`)
		end
		rarity, itemId = item.Rarity, item.Id
	elseif wantedRarity ~= nil and (wantedRarity ~= rarity or itemId == "") then
		local drawnItem = drawItem(store.Zone, wantedRarity)
		if drawnItem == nil then
			return invalid(`aucun objet {wantedRarity} en zone {store.Zone}`)
		end
		rarity, itemId = wantedRarity, drawnItem
	end
	if tier == baseTier and itemId == base.ItemId then
		return baseTier, base
	end
	log(`accroche du tuto : {player.Name} reçoit un colis {tier} {rarity} ({itemId}) au lieu de {baseTier} {base.Rarity}`)
	-- Jamais de mutation pour le colis du tuto (DEV-131) : un contenu remplacé n'en a aucune.
	local content: Content = { Rarity = rarity, ItemId = itemId, Mutation = nil }
	return tier, content
end

local function grant(player: Player, slot: Slot)
	local store = slot.Store
	local box = slot.Box
	-- Ancien déroulé seulement : avec Features.ShelfOpen, grabRefusal refuse toute prise d'un colis fermé
	-- (et son contenu n'existe pas encore, vague 32).
	local original = if box then box.Content else nil
	if box == nil or original == nil then
		return
	end
	local tier, content = contentFor(player, slot, box.Tier, original)
	local payload: NPCBoxPayload = {
		Kind = "NPCBox",
		Tier = tier,
		Zone = store.Zone,
		Rarity = content.Rarity,
		ItemId = content.ItemId,
		StoreId = store.Id,
		SlotId = slot.Id,
		Mutation = content.Mutation,
	}
	-- Rayon réservé pendant l'appel : une autre prise ne peut pas passer si StartCarry attend.
	slot.Box = nil
	outBoxes[payload] = { Slot = slot, Tier = box.Tier, Content = original }
	local ok, started = pcall(CarryService.StartCarry, player, payload)
	if not ok or started ~= true then
		outBoxes[payload] = nil
		if not ok then
			warn(`[StoreHeistService] CarryService.StartCarry : {started}`)
		end
		if slot.Box == nil and stores[store.Model] == store then
			slot.Box = box -- rien n'a changé : le colis reste sur le rayon
		else
			discard(box) -- rayon rempli entre-temps : pas de doublon
		end
		refuse(player, slot.Id, "CarryService a refusé le portage")
		return
	end
	discard(box)
	hideTimer(store, player)
	lockFor(store, player)
	local mutation = Mutations.Label(content.Mutation)
	log(`{player.Name} prend le colis {box.Tier} {slot.Name} de {store.Id} : {content.Rarity} ({content.ItemId}){if mutation then ", " .. mutation else ""}`)
	for _, listener in table.clone(grabbedListeners) do
		task.spawn(listener, player, payload)
	end
end

-- Ouverture sur le rayon (L-112, Features.ShelfOpen ; voir l'en-tête) -----------------------------------

-- `player` prend l'objet sorti posé sur `slot` : portage NPCItem (CarryService), rayon vidé, magasin
-- fermé pour lui (le vigile part à la prise, GuardService).
local function grantItem(player: Player, slot: Slot)
	local store = slot.Store
	local item = slot.Item
	if item == nil then
		return
	end
	local info = item.Info
	local content = info.Content
	local payload: NPCItemPayload = {
		Kind = "NPCItem",
		ItemId = content.ItemId,
		Rarity = content.Rarity,
		Mutation = content.Mutation,
		Zone = store.Zone,
		StoreId = store.Id,
		SlotId = slot.Id,
		Luck = info.Luck,
	}
	-- Rayon réservé pendant l'appel : une autre prise ne peut pas passer si StartCarry attend.
	slot.Item = nil
	outItems[payload] = { Slot = slot, Info = info }
	local ok, started = pcall(CarryService.StartCarry, player, payload)
	if not ok or started ~= true then
		outItems[payload] = nil
		if not ok then
			warn(`[StoreHeistService] CarryService.StartCarry : {started}`)
		end
		if slot.Item == nil and slot.Box == nil and stores[store.Model] == store then
			slot.Item = item -- rien n'a changé : l'objet reste sur le rayon
		else
			discardItem(item) -- rayon rempli entre-temps : pas de doublon
		end
		refuse(player, slot.Id, "CarryService a refusé le portage")
		return
	end
	discardItem(item)
	-- L-118 : il garde le chrono (le vigile sortira aussi pour lui) ; fermé pour lui quand il sort (stepEntries).
	local mutation = Mutations.Label(content.Mutation)
	log(`{player.Name} prend l'objet sorti {slot.Name} de {store.Id} : {content.Rarity} ({content.ItemId}){if mutation then ", " .. mutation else ""}, chance ×{info.Luck}`)
end

-- Chance d'une ouverture, tirée au hasard dans ShelfOpen.LuckTable (poids relatifs) ; jamais sous ×1.
local function drawLuck(): number
	local total = 0
	for _, entry in ShelfOpen.LuckTable do
		total += math.max(entry.Weight, 0)
	end
	if total <= 0 then
		return 1
	end
	local roll = random:NextNumber() * total
	local last = 1
	for _, entry in ShelfOpen.LuckTable do
		local weight = math.max(entry.Weight, 0)
		if weight > 0 then
			last = math.max(entry.Luck, 1)
			if roll < weight then
				return last
			end
			roll -= weight
		end
	end
	return last -- arrondi des nombres à virgule : la dernière chance possible
end

-- Un objet de la rareté `rarityId` pour un magasin de la zone `zone` : de sa zone, sinon de la zone la
-- plus proche qui en a un (zone + 1, puis zone − 1, zone + 2…) ; un Secret ou une Divine, toutes zones
-- (Items.Pick) ; jamais un objet TutorialOnly. nil si aucune zone n'en a.
local function drawItemNear(zone: number, rarityId: string): string?
	local itemId = drawItem(zone, rarityId)
	if itemId then
		return itemId
	end
	for distance = 1, #Zones do
		for _, other in { zone + distance, zone - distance } do
			if Zones[other] ~= nil then
				local found = drawItem(other, rarityId)
				if found then
					return found
				end
			end
		end
	end
	return nil
end

-- Vague 32 (règle de Cantin du 2026-11-13 ; valeurs de Config/ShelfOpen) : poids de la rareté de l'objet
-- pour une caisse de rareté `boxRarity` et la chance `luck` : ShelfOpen.BoxRarityOdds[boxRarity], dont les
-- poids des raretés au-dessus d'un seuil sont multipliés par la chance (ShelfOpen.LuckBoost) : "AboveBox",
-- au-dessus de la rareté de la caisse ; "AboveLowest", au-dessus de la plus basse de la table (plus basse
-- de poids > 0). Le tirage les ramène ensuite à 100 % (roll × total). nil si la caisse n'a pas de table ou
-- si sa table est vide.
local function itemRarityWeights(boxRarity: string, luck: number): { [string]: number }?
	local odds = ShelfOpen.BoxRarityOdds[boxRarity]
	if odds == nil then
		return nil
	end
	local lowest: number? = nil
	for _, rarity in Rarities.List do
		if (odds[rarity.Id] or 0) > 0 then
			lowest = rarity.Order
			break
		end
	end
	if lowest == nil then
		return nil
	end
	local boost = if luck > 1 and luck < math.huge then luck else 1
	local mode = ShelfOpen.LuckBoost
	local box = Rarities.ById[boxRarity]
	local threshold: number = lowest
	if mode == "AboveBox" and box then
		threshold = box.Order
	elseif mode ~= "AboveLowest" then
		warnOnce(`luckboost.{mode}`, `ShelfOpen.LuckBoost « {mode} » inconnu (ou caisse {boxRarity} inconnue) : la chance ne change pas la rareté de l'objet`)
		boost = 1
	end
	local weights: { [string]: number } = {}
	for _, rarity in Rarities.List do
		local weight = odds[rarity.Id] or 0
		if weight > 0 then
			weights[rarity.Id] = if rarity.Order > threshold then weight * boost else weight
		end
	end
	return weights
end

-- Rareté de l'objet tirée selon itemRarityWeights ; table absente : la rareté de la caisse (avertissement).
local function drawItemRarity(boxRarity: string, luck: number): string
	local weights = itemRarityWeights(boxRarity, luck)
	if weights == nil then
		warnOnce(`boxodds.{boxRarity}`, `aucune table ShelfOpen.BoxRarityOdds.{boxRarity} : l'objet est de la rareté de sa caisse`)
		return boxRarity
	end
	local total = 0
	for _, rarity in Rarities.List do
		total += weights[rarity.Id] or 0
	end
	local roll = random:NextNumber() * total
	local last = boxRarity
	for _, rarity in Rarities.List do
		local weight = weights[rarity.Id] or 0
		if weight > 0 then
			last = rarity.Id
			if roll < weight then
				return rarity.Id
			end
			roll -= weight
		end
	end
	return last -- arrondi des nombres à virgule : la dernière rareté possible
end

-- Contenu tiré à la sortie d'une caisse `boxRarity` d'un magasin de la zone `zone`, avec la chance `luck`
-- (voir l'en-tête, « Sortie ») : rareté (drawItemRarity), objet (drawItemNear), mutation et taille
-- (drawMutation). Aucun objet de la rareté tirée nulle part (Config incohérente ; Divine sans catalogue) :
-- la rareté la plus proche en dessous qui en a un, avec un avertissement. nil si rien ne peut sortir.
-- Renvoie aussi la rareté tirée (avant ce garde-fou).
local function drawShelfContent(boxRarity: string, zone: number, luck: number): (Content?, string)
	local wanted = drawItemRarity(boxRarity, luck)
	local info = Rarities.ById[wanted]
	if info == nil then
		return nil, wanted
	end
	for order = info.Order, 1, -1 do
		local rarityId: string = Rarities.List[order].Id
		local itemId = drawItemNear(zone, rarityId)
		if itemId then
			if order < info.Order then
				warnOnce(`nowhere.{wanted}`, `aucun objet {wanted} tirable dans aucune zone (Config/Items) : un objet {rarityId} sort à la place`)
			end
			local content: Content = { Rarity = rarityId, ItemId = itemId, Mutation = drawMutation(itemId) }
			return content, wanted
		end
	end
	return nil, wanted
end

-- Article anglais devant un mot en capitales : « a LEGENDARY », « an EPIC ».
local function article(word: string): string
	return if string.find(word, "^[AEIOU]") then "an" else "a"
end

-- Annonce aux autres joueurs du serveur, à partir de ShelfOpen.AnnounceMinRarity (le même Notify que
-- l'ancienne ouverture en base, Unbox.AnnounceKind) : « Alice unboxed a LEGENDARY Giant Plush! ».
local function announce(opener: Player?, content: Content)
	local rarity = Rarities.ById[content.Rarity]
	local item = Items.ById[content.ItemId]
	local minimum = Rarities.ById[ShelfOpen.AnnounceMinRarity]
	if opener == nil or rarity == nil or item == nil or minimum == nil or rarity.Order < minimum.Order then
		return
	end
	local name = rarity.DisplayNameUpper
	local message = `{opener.DisplayName} unboxed {article(name)} {name} {item.DisplayName}!`
	for _, other in Players:GetPlayers() do
		if other ~= opener then
			Net.Server.Notify:Fire(other, message, Unbox.AnnounceKind)
		end
	end
	log(`annonce aux autres joueurs : {message}`)
end

-- Sortie de l'objet du colis `box` de `slot`, avec la chance `luck` (celle tirée, ou celle atteinte si
-- la police a coupé la montée) : accroche du tuto, sinon contenu tiré selon la caisse et la chance (vague
-- 32), le colis disparaît, l'objet prend sa place, réservé ShelfOpen.ReserveTime s à l'ouvreur.
local function reveal(slot: Slot, box: ShelfBox, luck: number)
	local opening = box.Opening
	local store = slot.Store
	if opening == nil or slot.Box ~= box or stores[store.Model] ~= store then
		return
	end
	box.Opening = nil
	slot.Box = nil
	local opener = Players:GetPlayerByUserId(opening.ByUserId)
	-- Accroche du tuto d'abord, sans tirage : un contenu imposé est l'objet sorti tel quel (voir l'en-tête).
	local pending: Content = { Rarity = box.Rarity, ItemId = "", Mutation = nil }
	local imposed: Content? = nil
	if opener then
		local _, given = contentFor(opener, slot, box.Tier, pending)
		if given ~= pending then
			imposed = given
		end
	end
	local drawnRarity = box.Rarity
	local final: Content? = imposed
	if final == nil then
		final, drawnRarity = drawShelfContent(box.Rarity, store.Zone, luck)
	end
	box.Model:SetAttribute(ShelfOpenState.StateAttribute, "Revealed")
	discard(box)
	if final == nil then
		-- Garde-fou (Config incohérente) : rien ne peut sortir de cette caisse, le rayon reste vide.
		warnOnce(`reveal.{box.Rarity}.{store.Zone}`, `aucun objet ne peut sortir d'une caisse {box.Rarity} en zone {store.Zone} (Config : ShelfOpen.BoxRarityOdds, Items) : rayon laissé vide`)
		if openingCount(store) == 0 then
			calmWitnesses(store)
		end
		return
	end
	local info: ItemInfo = {
		Tier = box.Tier,
		Content = final,
		Luck = luck,
		OpenerId = opening.ByUserId,
		ReservedUntil = os.clock() + ShelfOpen.ReserveTime,
		ReservedUntilServer = Workspace:GetServerTimeNow() + ShelfOpen.ReserveTime,
	}
	placeItem(slot, info, nil)
	if openingCount(store) == 0 then
		calmWitnesses(store) -- c'était la dernière ouverture en cours dans ce magasin
	end
	local mutation = Mutations.Label(final.Mutation)
	local how = if imposed then " (contenu imposé par le tuto, sans tirage)"
		elseif drawnRarity ~= final.Rarity then ` (tirée : {drawnRarity}, aucun objet nulle part)`
		else ""
	log(`{slot.Id} : l'objet sort, chance ×{luck}, caisse {box.Rarity} → objet {final.Rarity} ({final.ItemId}){how}{if mutation then ", " .. mutation else ""}, réservé {ShelfOpen.ReserveTime} s à {if opener then opener.Name else opening.ByUserId}`)
	announce(opener, final)
end

-- Lance l'ouverture du colis `box` de `slot` par `player` : chance tirée, attributs du contrat, témoins,
-- sortie programmée.
local function startOpening(player: Player, slot: Slot, box: ShelfBox)
	local store = slot.Store
	local luck = drawLuck()
	local forced = luckOverride
	if forced then
		-- Accroche du tuto (a107, SetLuckOverride) : une chance finie ≥ 1, sinon le tirage normal.
		-- Vague 32 : le contenu n'est pas encore tiré ; Rarity = rareté de la caisse, ItemId = "".
		local drawn: OverrideInfo = { StoreId = store.Id, SlotId = slot.Id, Zone = store.Zone, Tier = box.Tier, Rarity = box.Rarity, ItemId = "" }
		local ok, value = pcall(forced, player, drawn)
		if ok and type(value) == "number" and value >= 1 and value < math.huge then
			luck = value
		elseif not ok then
			warn(`[StoreHeistService] accroche SetLuckOverride : {value}`)
		end
	end
	local delay = ShelfOpenState.revealDelay(luck)
	local openAt = Workspace:GetServerTimeNow()
	local opening: Opening = { ByUserId = player.UserId, Luck = luck, OpenAt = openAt }
	box.Opening = opening
	local model = box.Model
	model:SetAttribute(ShelfOpenState.ByAttribute, player.UserId)
	model:SetAttribute(ShelfOpenState.AtAttribute, openAt)
	model:SetAttribute(ShelfOpenState.LuckAttribute, luck)
	model:SetAttribute(ShelfOpenState.RevealAtAttribute, openAt + delay)
	model:SetAttribute(ShelfOpenState.StateAttribute, "Opening") -- en dernier : les autres sont déjà lisibles
	-- L-118 : plus de témoins pendant l'ouverture (ils ont fui à la casse) ; seul le vigile compte, à la fin du chrono.
	task.delay(delay, function()
		if box.Opening == opening then
			reveal(slot, box, luck)
		end
	end)
	log(`{player.Name} ouvre la caisse {box.Rarity} ({box.Tier}) {slot.Name} de {store.Id} : chance ×{luck}, sortie dans {math.round(delay * 10) / 10} s`)
end

-- La police est appelée pour ce magasin (WitnessService.OnCall) : chaque ouverture en cours s'arrête là,
-- ShelfRevealAt avancé à maintenant, l'objet sort tout de suite avec la chance atteinte à cet instant.
local function onPoliceCalled(model: Model)
	local store = stores[model]
	if store == nil then
		return
	end
	local now = Workspace:GetServerTimeNow()
	for _, slot in store.Slots do
		local box = slot.Box
		local opening = if box then box.Opening else nil
		if box and opening then
			local reached = ShelfOpenState.luckAt(opening.OpenAt, opening.Luck, now)
			box.Model:SetAttribute(ShelfOpenState.RevealAtAttribute, now)
			log(`{slot.Id} : police appelée pendant la montée, la chance s'arrête à ×{reached} (tirée : ×{opening.Luck})`)
			reveal(slot, box, reached)
		end
	end
end

-- Raison du refus d'une ouverture du colis de `slot`, ou nil si elle est permise maintenant.
local function openRefusal(player: Player, slot: Slot): string?
	local store = slot.Store
	if not store.Open then
		return "magasin fermé"
	end
	local box = slot.Box
	if box == nil or not box.Landed then
		return if slot.Item then "colis déjà ouvert" else "rayon vide"
	end
	if box.Opening then
		return "ouverture déjà lancée"
	end
	if player ~= store.Breaker and os.clock() < store.ExclusiveUntil then
		return "avance du casseur"
	end
	return reachRefusal(player, slot)
end

-- OpenShelfBox(slotId) : premier appel = début du maintien, second = fin (voir l'en-tête).
local function onOpenShelfBox(player: Player, slotId: string)
	if not SHELF_OPEN then
		return -- ancien déroulé : les colis ne s'ouvrent pas sur le rayon
	end
	local slot = slotsById[slotId]
	if slot == nil then
		refuse(player, slotId, "emplacement inconnu", "OpenShelfBox")
		return
	end
	if not AntiCheatService.Verify(player) then
		refuse(player, slotId, "déplacement sanctionné par l'anti-triche (audit 9.8)", "OpenShelfBox")
		return
	end
	local hold = openHolds[player]
	local reason = openRefusal(player, slot)
	if reason then
		if hold and hold.Slot == slot then
			openHolds[player] = nil
		end
		refuse(player, slotId, reason, "OpenShelfBox")
		return
	end
	local box = slot.Box :: ShelfBox -- openRefusal a vérifié qu'il est posé et fermé
	local required = grabTime(box.Tier)
	local now = os.clock()
	local finishing = hold ~= nil and hold.Slot == slot and hold.Target == box
	if not finishing and required > 0 then
		openHolds[player] = { Slot = slot, Target = box, Tier = box.Tier, StartedAt = now } -- début du maintien
		return
	end
	if finishing then
		local elapsed = now - (hold :: Hold).StartedAt
		if elapsed + GRAB_TIME_TOLERANCE < required then
			refuse(
				player,
				slotId,
				`maintien trop court ({math.round(elapsed * 100) / 100} s sur {required} s)`,
				"OpenShelfBox"
			)
			return
		end
	end
	openHolds[player] = nil
	-- Témoins vérifiés au lancement seulement (fin du maintien) : un seul message par appui.
	local api = witnessApi
	local okCalling, calling = false, false
	if api then
		okCalling, calling = pcall(api.IsCalling, slot.Store.Model)
	end
	if okCalling and calling == true then
		if now - (lastCallNotice[player] or -math.huge) >= CALL_NOTICE_INTERVAL then
			lastCallNotice[player] = now
			Net.Server.Notify:Fire(player, MESSAGES.WitnessCalling, "Warning")
		end
		refuse(player, slotId, "un témoin du magasin appelle la police", "OpenShelfBox")
		return
	end
	startOpening(player, slot, box)
end

-- GrabItem(slotId) : premier appel = début du maintien, second = fin (voir l'en-tête).
local function onGrabItem(player: Player, slotId: string)
	local slot = slotsById[slotId]
	if slot == nil then
		refuse(player, slotId, "emplacement inconnu")
		return
	end
	if not AntiCheatService.Verify(player) then
		refuse(player, slotId, "déplacement sanctionné par l'anti-triche (audit 9.8)")
		return
	end
	local hold = holds[player]
	local reason = grabRefusal(player, slot)
	if reason then
		if hold and hold.Slot == slot then
			holds[player] = nil
		end
		refuse(player, slotId, reason)
		return
	end
	-- grabRefusal a vérifié qu'il est posé : le colis, ou l'objet sorti (L-112).
	local target: any, tier: string
	local give = grant
	if SHELF_OPEN then
		local item = slot.Item :: ShelfItem
		target, tier, give = item, item.Info.Tier, grantItem
	else
		local box = slot.Box :: ShelfBox
		target, tier = box, box.Tier
	end
	local required = grabTime(tier)
	local now = os.clock()
	if hold and hold.Slot == slot and hold.Target == target then
		local elapsed = now - hold.StartedAt
		if elapsed + GRAB_TIME_TOLERANCE >= required then
			holds[player] = nil
			give(player, slot)
		else
			refuse(player, slotId, `maintien trop court ({math.round(elapsed * 100) / 100} s sur {required} s)`)
		end
		return
	end
	if required <= 0 then
		holds[player] = nil
		give(player, slot)
		return
	end
	holds[player] = { Slot = slot, Target = target, Tier = tier, StartedAt = now }
end

-- Retour d'un colis ------------------------------------------------------------------------------

local function returnBox(payload: any, from: Vector3?): boolean
	if type(payload) ~= "table" then
		return false
	end
	local out = outBoxes[payload]
	if out == nil then
		return false -- inconnu, déjà revenu, ou d'avant un remplissage de son magasin
	end
	outBoxes[payload] = nil
	local slot = out.Slot
	if stores[slot.Store.Model] ~= slot.Store or slot.Box ~= nil or slot.Item ~= nil then
		return false -- magasin retiré, ou emplacement occupé : pas de doublon
	end
	placeBox(slot, out.Tier, out.Content.Rarity, out.Content, from)
	return true
end

-- L-112 : remet sur son emplacement l'objet sorti de ce payload NPCItem, en vol depuis `from` s'il est
-- donné. Sa réservation n'est pas relancée. false s'il est inconnu, déjà revenu, d'avant un
-- remplissage de son magasin, ou si son emplacement est occupé (il disparaît alors).
local function returnItem(payload: any, from: Vector3?): boolean
	local out = outItems[payload]
	if out == nil then
		return false
	end
	outItems[payload] = nil
	local slot = out.Slot
	if stores[slot.Store.Model] ~= slot.Store or slot.Box ~= nil or slot.Item ~= nil then
		return false
	end
	placeItem(slot, out.Info, from)
	return true
end

-- Tête (ou centre) du porteur, point de départ du vol de retour.
local function carrierPosition(player: Player): Vector3?
	local character = player.Character
	if character == nil or not character:IsDescendantOf(Workspace) then
		return nil
	end
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head.Position + Vector3.new(0, 2, 0)
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position + Vector3.new(0, 3, 0)
	end
	return nil
end

local function onCarryEnded(player: Player, payload: any, result: string, reason: string)
	if type(payload) == "table" and payload.Kind == "NPCItem" then
		-- L-112 : objet sorti d'un colis. Rangé en base : il ne reviendra jamais. Au sol (attrapé, coup
		-- de batte) : rien, il revient par onDropExpired s'il n'est pas ramassé. Autre échec (mort,
		-- départ, anomalie…) : il revole vers son rayon.
		if result == "Consumed" then
			outItems[payload] = nil
		elseif result == "Failed" then
			local back = returnItem(payload, carrierPosition(player))
			log(`objet {payload.ItemId} de {player.Name} ({reason}) : {if back then "revient" else "ne revient pas"} sur {payload.SlotId}`)
		end
		return
	end
	if type(payload) ~= "table" or payload.Kind ~= "NPCBox" then
		return
	end
	if result == "Consumed" then
		outBoxes[payload] = nil -- posé sur un établi : il ne reviendra jamais
		return
	end
	if result ~= "Failed" then
		return -- « Dropped » (DEV-048) : au sol, il revient par onDropExpired s'il n'est pas ramassé
	end
	-- Attrapé dans le magasin : il en est sorti par la fermeture pour le voleur (stepLocks).
	if returnBox(payload, carrierPosition(player)) then
		log(`colis {payload.Tier} de {player.Name} ({reason}) : revient sur {payload.SlotId}`)
	else
		log(
			`colis {payload.Tier} de {player.Name} ({reason}) : ne revient pas sur {payload.SlotId} (magasin rempli depuis, ou colis inconnu)`
		)
	end
end

-- Colis tombé au sol après un coup de batte, jamais ramassé (6.2 : Bat.DroppedLifetime s) : il
-- revole vers son emplacement depuis l'endroit où il était, avec son contenu d'origine. Un colis
-- qui n'est pas d'un magasin (camion) est inconnu ici : il disparaît, rien à faire.
local function onDropExpired(dropId: string, payload: any, position: Vector3?)
	if type(payload) == "table" and payload.Kind == "NPCItem" then
		-- L-112 : objet resté au sol sans preneur, il revole vers son rayon (ou disparaît, voir returnItem).
		local start = if typeof(position) == "Vector3" then position + Vector3.new(0, DROP_RETURN_LIFT, 0) else nil
		local back = returnItem(payload, start)
		log(`objet {payload.ItemId} {dropId} resté au sol : {if back then "revient" else "ne revient pas"} sur {payload.SlotId}`)
		return
	end
	if type(payload) ~= "table" or payload.Kind ~= "NPCBox" then
		return
	end
	if outBoxes[payload] == nil then
		if storesById[payload.StoreId] then
			log(`colis {payload.Tier} {dropId} resté au sol : ne revient pas sur {payload.SlotId} (magasin rempli depuis)`)
		end
		return -- colis du camion, ou d'avant un remplissage de son magasin : il disparaît
	end
	local from = if typeof(position) == "Vector3" then position + Vector3.new(0, DROP_RETURN_LIFT, 0) else nil
	if returnBox(payload, from) then
		log(`colis {payload.Tier} {dropId} resté au sol : revient sur {payload.SlotId}`)
	else
		log(`colis {payload.Tier} {dropId} resté au sol : ne revient pas sur {payload.SlotId} (emplacement occupé)`)
	end
end

-- Magasins --------------------------------------------------------------------------------------------

local function findShutter(store: Store, model: Model)
	local object = model:FindFirstChild(SHUTTER_NAME, true)
	if object == nil or not object:IsA("PVInstance") then
		warn(`[StoreHeistService] {model:GetFullName()} : pas de rideau « {SHUTTER_NAME} » (Part ou Model), il ne tombera pas`)
		return
	end
	local shutter = object :: PVInstance
	local parts: { BasePart } = {}
	if object:IsA("BasePart") then
		table.insert(parts, object)
	end
	for _, descendant in shutter:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	local collide: { [BasePart]: boolean } = {}
	for _, part in parts do
		collide[part] = part.CanCollide
	end
	local cf, size = boxOf(shutter)
	local drop = extentAlong(cf, size, Vector3.yAxis)
	local open = shutter:GetPivot()
	store.Shutter = shutter
	store.ShutterParts = parts
	store.ShutterCollide = collide
	store.ShutterOpen = open
	store.ShutterClosed = open - Vector3.new(0, drop, 0)
end

local function register(instance: Instance)
	if not instance:IsA("Model") or stores[instance] ~= nil or not inMap(instance) then
		return
	end
	local model = instance :: Model
	local zone = model:GetAttribute(Attributes.Zone.Name)
	if type(zone) ~= "number" or Zones[zone] == nil then
		warn(`[StoreHeistService] {model:GetFullName()} : attribut {Attributes.Zone.Name} invalide ({zone}), magasin ignoré`)
		return
	end
	local id = WindowService.GetWindowId(model) or model.Name
	if storesById[id] ~= nil then
		warn(`[StoreHeistService] {model:GetFullName()} : StoreId « {id} » déjà pris, magasin ignoré`)
		return
	end
	local bounds = model:FindFirstChild(BOUNDS_NAME, true)
	local window = model:FindFirstChild(WINDOW_NAME, true)
	local folder = Instance.new("Folder")
	folder.Name = BOXES_FOLDER

	local store: Store = {
		Id = id,
		Model = model,
		Zone = zone,
		Bounds = if bounds and bounds:IsA("BasePart") then bounds else nil,
		Window = if window and window:IsA("PVInstance") then window else nil,
		Shutter = nil,
		ShutterParts = {},
		ShutterCollide = {},
		ShutterOpen = CFrame.identity,
		ShutterClosed = CFrame.identity,
		ShutterDown = false,
		ShutterPending = false,
		ShutterToken = 0,
		StopShutter = nil,
		Slots = {},
		Folder = folder,
		Open = false,
		Token = 0,
		Breaker = nil,
		ExclusiveUntil = 0,
		EndsAt = 0,
		Viewers = {},
		RefillPending = false,
		Locked = {},
		CurtainHeld = false,
		Entered = {},
		ChronoOver = false,
		KickAfter = {},
		ClosedAt = 0,
	}
	if store.Bounds == nil then
		warn(`[StoreHeistService] {model:GetFullName()} : pas de volume « {BOUNDS_NAME} » (Part), aucune prise possible`)
	end
	findShutter(store, model)
	if store.Shutter then
		-- Le rideau baissé que le client du voleur montre chez lui seul (StoreLockController).
		model:SetAttribute(SHUTTER_PIVOT_ATTRIBUTE, store.ShutterClosed)
	end

	-- Le type des colis ne vient plus de l'emplacement (L-033) : l'attribut Tier des ShelfSlot
	-- n'est pas lu.
	for number = 1, Balance.Heist.ShelfSlots do
		local name = string.format(SLOT_FORMAT, number)
		local attachment = model:FindFirstChild(name, true)
		if attachment == nil or not attachment:IsA("Attachment") then
			warn(`[StoreHeistService] {model:GetFullName()} : {name} manquant (Attachment), rayon ignoré`)
			continue
		end
		local slotId = `{id}/{string.format("%02d", number)}`
		if #slotId > MAX_ID_LENGTH or slotsById[slotId] ~= nil then
			warn(`[StoreHeistService] {attachment:GetFullName()} : identifiant « {slotId} » trop long ou en double, rayon ignoré`)
			continue
		end
		local slot: Slot = {
			Store = store,
			Number = number,
			Name = name,
			Id = slotId,
			Attachment = attachment,
			Box = nil,
			Item = nil,
		}
		table.insert(store.Slots, slot)
	end
	local boxTotal = #layoutTiers()
	if #store.Slots < boxTotal then
		warn(
			`[StoreHeistService] {model:GetFullName()} : {#store.Slots} rayon(s) pour {boxTotal} colis, {boxTotal - #store.Slots} colis Standard en moins`
		)
	end

	for _, slot in store.Slots do
		slotsById[slot.Id] = slot
	end
	stores[model] = store
	storesById[id] = store
	model:SetAttribute(STORE_ID_ATTRIBUTE, id)
	setHeistAttributes(store)
	folder.Parent = model
	fillStore(store) -- rayons pleins au démarrage, répartis au hasard
end

local function unregister(instance: Instance)
	local store = stores[instance]
	if store == nil then
		return
	end
	stores[instance] = nil
	storesById[store.Id] = nil
	unlockAll(store, "magasin retiré de la map")
	if openingCount(store) > 0 then
		calmWitnesses(store) -- ouvertures interrompues
	end
	store.Open = false
	store.Token += 1
	store.ShutterToken += 1
	stopShutter(store)
	cancelHolds(store)
	for player in table.clone(store.Viewers) do
		hideTimer(store, player)
	end
	for payload, out in outBoxes do
		if out.Slot.Store == store then
			outBoxes[payload] = nil
		end
	end
	for payload, out in outItems do
		if out.Slot.Store == store then
			outItems[payload] = nil
		end
	end
	for _, slot in store.Slots do
		slotsById[slot.Id] = nil
		removeBox(slot)
		removeItem(slot)
	end
	store.Folder:Destroy()
end

-- Tick : maintiens, chrono des joueurs proches, sortie des magasins fermés.
local function step()
	local now = os.clock()
	for player, hold in holds do
		local slot = hold.Slot
		local current: any = if SHELF_OPEN then slot.Item else slot.Box
		if
			current ~= hold.Target
			or now - hold.StartedAt > grabTime(hold.Tier) + HOLD_EXPIRY
			or grabRefusal(player, slot) ~= nil
		then
			holds[player] = nil
		end
	end
	for player, hold in openHolds do
		if
			hold.Slot.Box ~= hold.Target
			or now - hold.StartedAt > grabTime(hold.Tier) + HOLD_EXPIRY
			or openRefusal(player, hold.Slot) ~= nil
		then
			openHolds[player] = nil
		end
	end
	for _, store in stores do
		stepLocks(store)
		if store.Open and SHELF_OPEN then
			-- L-118 : fermé quand le chrono est fini et que plus personne n'est dedans (ouvertures finies).
			stepEntries(store)
			if not store.ChronoOver then
				updateViewers(store)
			elseif not anyoneInside(store) and not storeBusy(store) then
				closeStore(store)
			end
		elseif store.Open then
			updateViewers(store)
		else
			for _, player in ejectInside(store, false) do
				log(`{player.Name} sorti de {store.Id} (magasin fermé)`)
			end
			if store.ShutterPending and lowerWhenClear(store) then
				log(`{store.Id} : rideau baissé, porteurs et vigiles sortis`)
			end
			-- L-112 : remplissage qui attendait la fin d'une ouverture ou d'une réservation.
			if store.RefillPending and not storeBusy(store) then
				log(`{store.Id} : remplissage reporté à la fin des ouvertures, {fillStore(store)} colis répartis au hasard`)
			end
		end
	end
end

local function onBroken(info: WindowService.BreakInfo)
	if info.Kind ~= "NPC" then
		return
	end
	local store = stores[info.Model]
	if store == nil then
		return
	end
	openStore(store, info.Breaker, info.ChronoEndsAt)
end

-- Un seul braquage à la fois (voir l'en-tête) : le magasin du braquage en cours de `player` qui
-- n'est pas `target`, ou nil (pas de braquage en cours, ou seulement dans `target`).
local function otherHeist(player: Player, target: Store): string?
	for _, store in stores do
		-- L-118 : sorti du magasin (fermé pour lui), son braquage là-bas est fini, sauf l'objet qu'il porte.
		if store ~= target and store.Open and store.Breaker == player and not (SHELF_OPEN and store.Locked[player]) then
			return store.Id
		end
	end
	local payload = CarryService.GetPayload(player)
	if type(payload) == "table" and (payload.Kind == "NPCBox" or payload.Kind == "NPCItem") and payload.StoreId ~= target.Id then
		return if type(payload.StoreId) == "string" then payload.StoreId else "?"
	end
	return nil
end

-- WindowService.AddHitGate : false = coup sur la vitrine d'un autre magasin PNJ, ignoré, avec un
-- message drôle au plus toutes les OneAtATimeCooldown s.
local function hitGate(player: Player, _windowId: string, kind: WindowService.WindowKind, model: Model): boolean
	if kind ~= "NPC" then
		return true -- parcelles et camion : la règle ne s'applique pas
	end
	local target = stores[model]
	if target == nil then
		return true
	end
	local busy = otherHeist(player, target)
	if busy == nil then
		return true
	end
	local now = os.clock()
	local last = lastGreedy[player]
	if last == nil or now - last >= Balance.Heist.OneAtATimeCooldown then
		lastGreedy[player] = now
		Net.Server.Notify:Fire(player, Balance.Heist.OneAtATimeMessage, "Warning")
		log(`{player.Name} frappe {target.Id} pendant son braquage de {busy} : aucun dégât`)
	end
	return false
end

local function onRebuilt(_windowId: string, model: Model)
	local store = stores[model]
	if store == nil then
		return
	end
	closeStore(store) -- vitrine reconstruite avant la fin du chrono (WindowService.Rebuild)
	unlockAll(store, "réouverture du magasin") -- au plus tard ici (sans vigile, ou vigile pas signalé)
	store.ShutterPending = false
	raiseShutter(store, false)
	for _, player in ejectInside(store, true) do
		log(`{player.Name} sorti de {store.Id} : la vitrine est reconstruite`)
	end
end

-- API ----------------------------------------------------------------------------------------------

function StoreHeistService.RefillAll(): number
	local count, deferred = 0, 0
	for _, store in stores do
		if store.Open or storeBusy(store) then
			-- nouveau tirage à la fermeture, ou (L-112) à la fin des ouvertures et des réservations en cours
			store.RefillPending = true
			deferred += 1
		else
			count += fillStore(store)
		end
	end
	local later = if deferred > 0 then `, {deferred} magasin(s) ouvert(s) rempli(s) à leur fermeture` else ""
	log(`rayons remplis (nouveau tirage) : {count} colis répartis au hasard{later}`)
	return count
end

function StoreHeistService.IsOpen(store: Instance | string): boolean
	local found = if type(store) == "string" then storesById[store] else stores[store]
	return found ~= nil and found.Open
end

function StoreHeistService.OnBoxGrabbed(listener: GrabbedListener): () -> ()
	return subscribe(grabbedListeners, listener)
end

function StoreHeistService.ReturnBox(payload: NPCBoxPayload, from: Vector3?): boolean
	return returnBox(payload, from)
end

function StoreHeistService.SetContentOverride(override: ContentOverride?)
	contentOverride = override
end

function StoreHeistService.SetLuckOverride(override: LuckOverride?)
	luckOverride = override
end

function StoreHeistService.GetStoreId(model: Instance): string?
	local store = stores[model]
	return if store then store.Id else nil
end

function StoreHeistService.GetStoreModel(storeId: string): Model?
	local store = storesById[storeId]
	return if store then store.Model else nil
end

function StoreHeistService.Init()
	for _, instance in CollectionService:GetTagged(STORE_TAG) do
		register(instance)
	end
	CollectionService:GetInstanceAddedSignal(STORE_TAG):Connect(function(instance: Instance)
		-- Après WindowService, qui enregistre la vitrine sur le même signal.
		task.defer(register, instance)
	end)
	CollectionService:GetInstanceRemovedSignal(STORE_TAG):Connect(unregister)
	WindowService.OnBroken(onBroken)
	WindowService.OnRebuilt(onRebuilt)
	-- Accès protégé : les faux WindowService des bancs n'ont pas tous AddHitGate.
	local addHitGate: ((gate: typeof(hitGate)) -> ())? = (WindowService :: any).AddHitGate
	if addHitGate then
		addHitGate(hitGate)
	else
		log("WindowService.AddHitGate indisponible : pas de règle « un seul braquage à la fois »")
	end
	CarryService.OnCarryEnded(onCarryEnded)
	CarryService.OnDropExpired(onDropExpired)
	Net.Server.GrabItem:Connect(onGrabItem)
	Net.Server.OpenShelfBox:Connect(onOpenShelfBox)
	Players.PlayerRemoving:Connect(function(player: Player)
		holds[player] = nil
		openHolds[player] = nil
		lastRefusal[player] = nil
		lastGreedy[player] = nil
		lastCallNotice[player] = nil
		for _, store in stores do
			store.Viewers[player] = nil
			store.Locked[player] = nil
			store.Entered[player] = nil
			store.KickAfter[player] = nil
		end
	end)
	-- Le vigile apparu pour un vol est parti : le magasin se rouvre pour ce voleur. require protégé :
	-- sans GuardService (bancs), la fermeture pour le voleur dure jusqu'à la réouverture du magasin.
	local okGuard, guardApi = pcall(function(): any
		return require(script.Parent.GuardService) :: any
	end)
	-- L-118 (Features.ShelfOpen) : fermé pour lui jusqu'à la réouverture seulement, et le vigile sort à la
	-- fin du chrono (ChaseIntruder), plus à la prise.
	local onGone: any = if okGuard and type(guardApi) == "table" and not SHELF_OPEN then guardApi.OnGuardGone else nil
	local chase: any = if okGuard and type(guardApi) == "table" then guardApi.ChaseIntruder else nil
	if type(chase) == "function" then
		chaseIntruder = chase
	elseif SHELF_OPEN then
		log("GuardService.ChaseIntruder indisponible : aucun vigile à la fin du chrono")
	end
	-- Attrapé DANS le magasin par un vigile de jour (Cantin, 2026-11-13 ; Features.ShelfOpen) : le magasin se
	-- ferme pour lui tout de suite (plus d'ouverture ni de prise, reachRefusal), puis il est sorti devant la
	-- vitrine par stepLocks une fois le coup donné (Balance.Guard.CatchStunDuration s, V0), comme un joueur
	-- qui sort : rideau baissé pour lui jusqu'à la réouverture. La nuit renvoie déjà à la base.
	local onCatch: any = if okGuard and type(guardApi) == "table" and SHELF_OPEN then guardApi.OnCatch else nil
	if type(onCatch) == "function" then
		(onCatch :: any)(function(player: Player, _zone: number, night: boolean, _carrying: boolean)
			if night then
				return
			end
			local root = rootOf(player)
			if root == nil then
				return
			end
			for _, store in stores do
				local bounds = store.Bounds
				if bounds ~= nil and inside(bounds, root.Position) and store.Locked[player] ~= "Closed" then
					store.Locked[player] = "Closed"
					store.KickAfter[player] = os.clock() + Balance.Guard.CatchStunDuration
					publishClosed(player)
					log(`{player.Name} attrapé dans {store.Id} : fermé pour lui, sorti après le coup`)
				end
			end
		end)
	elseif SHELF_OPEN then
		log("GuardService.OnCatch indisponible : un joueur attrapé dans un magasin y reste")
	end
	if SHELF_OPEN then
		-- La vitrine n'est reconstruite qu'une fois le magasin fermé, et RebuildDelay s après au plus tôt.
		local addGate: any = (WindowService :: any).AddRebuildGate
		if addGate ~= nil then
			(addGate :: any)(function(_windowId: string, model: Model?): boolean
				local store = if model then stores[model] else nil
				return store == nil or (not store.Open and os.clock() >= store.ClosedAt + Balance.Window.RebuildDelay)
			end)
		end
	end
	local subscribed = onGone ~= nil and pcall(onGone, function(thief: Player, model: Model)
		local store = stores[model]
		if store then
			unlock(store, thief, "son vigile est rentré")
		end
	end)
	if not subscribed and not SHELF_OPEN then
		log("GuardService.OnGuardGone indisponible : un magasin reste fermé pour son voleur jusqu'à sa réouverture")
	end
	-- a70 : vigiles qui rentrent vers la réserve, pour lever le rideau local avant leur arrivée.
	local getReturning: any = if okGuard and type(guardApi) == "table" then guardApi.GetReturningGuards else nil
	if type(getReturning) == "function" then
		returningGuards = getReturning
	else
		log("GuardService.GetReturningGuards indisponible : le rideau local n'attend que les vigiles dans le magasin")
	end

	-- L-112 : témoins et police (WitnessService, L-111). require protégé : sans lui (bancs), les colis
	-- s'ouvrent sans témoins.
	if SHELF_OPEN then
		local okWitness, witness = pcall(function(): any
			return require(script.Parent.WitnessService) :: any
		end)
		local usable = okWitness
			and type(witness) == "table"
			and type(witness.Raise) == "function"
			and type(witness.Calm) == "function"
			and type(witness.IsCalling) == "function"
			and type(witness.OnCall) == "function"
		if usable then
			witnessApi = witness
			local okCall, err = pcall(witness.OnCall, onPoliceCalled)
			if not okCall then
				warn(`[StoreHeistService] WitnessService.OnCall : {err}`)
			end
		else
			log("WitnessService indisponible : les colis s'ouvrent sur le rayon sans témoins ni police")
		end
	else
		log("Features.ShelfOpen = false : ancien déroulé, les colis se portent fermés")
	end

	local storeCount, boxCount = 0, 0
	for _, store in stores do
		storeCount += 1
		for _, slot in store.Slots do
			if slot.Box then
				boxCount += 1
			end
		end
	end
	local delivered: { string } = {}
	for _, rarity in Rarities.List do
		if boxTemplate(BOX_PREFIX .. rarity.Id) then
			table.insert(delivered, BOX_PREFIX .. rarity.Id)
		end
	end
	for _, tier in Balance.Heist.TierOrder do
		if boxTemplate(BOX_PREFIX .. tier) then
			table.insert(delivered, BOX_PREFIX .. tier)
		end
	end
	local looks = if #delivered > 0 then `modèles {table.concat(delivered, ", ")}` else "blocs V0 (aucun BOX_* livré)"
	print(
		`[StoreHeistService] {storeCount} magasin(s) prêt(s), {boxCount} colis répartis au hasard sur les rayons, contenu tiré à la mise en rayon ({looks})`
	)
end

function StoreHeistService.Start()
	while true do
		task.wait(TICK)
		xpcall(step, function(err: any)
			warn(`[StoreHeistService] tick : {err}`)
		end)
	end
end

return StoreHeistService
