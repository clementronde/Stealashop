--!strict
-- StoreHeistService (DEV-015) : braquage des magasins PNJ, chrono HEIST (Balance.Heist.Duration, 6 s), rideau, rayons et
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
--     serveur pose un colis neuf sur chaque ShelfSlot du magasin. Vague 76 (Cantin et Clément, 19/11) : plus de
--     types de colis (Standard, Premium, Luxe) : la rareté de chaque colis est tirée dans celles de la zone
--     (ShelfBoxes.ZoneOdds) et donne son temps de prise (ShelfBoxes.GrabTime ; attribut BoxRarity du colis et de
--     l'objet sorti, lu par HeistController). Magasin à moins de 10 rayons (contrat
--     incomplet) : le Luxe est posé d'abord, puis les Premium, les Standard en trop manquent.
--     Les colis sont créés par le code dans un dossier `ShelfBoxes` du magasin (`ShelfBox_01`…,
--     numéro de l'emplacement, tag ShelfBox) : le modèle du magasin n'en contient pas. Aspect :
--     modèle `BOX_<Rareté>` de Clément (rareté de la caisse, tirée à la mise en rayon ; L-097 point 3)
--     s'il existe dans ReplicatedStorage/Assets (ou ServerStorage/Assets), sinon l'ancien `BOX_<Standard|Premium|Luxe>` de même temps de prise (vague 76), sinon
--     un bloc V0 (carton brun, carton bleu scellé, caisse en bois cerclée d'or, 7.3). Sur le rayon,
--     le colis n'est pas teint (BOX_<Rareté> est déjà à la couleur de sa rareté).
--     Vague 32 (règle de Cantin du 2026-11-13) : seule la rareté de la CAISSE
--     est tirée à la mise en rayon, comme la rareté ci-dessous (ZoneOdds, sinon Rarities.BoxOdds par
--     type) ; elle choisit BOX_<Rareté>, va dans l'attribut BoxRarity du colis et sur son BB_Box (rareté
--     seule). Le contenu (objet, rareté de l'objet, mutation, taille) n'est PAS tiré ici : il l'est à
--     l'ouverture (« Sortie », plus bas). (L'ancien tirage du contenu et de la mutation à la mise en
--     rayon, L-031, est parti avec Features.ShelfOpen, vague 53.)
--   - Étiquette : chaque colis du rayon porte BB_Box (CarryService.AttachBoxLabel : copie de
--     ReplicatedStorage/Assets/UI/BB_Box accrochée à son LabelPoint) : rareté de la caisse à sa couleur,
--     seule. ShelfBoxController (client) ne montre que celles des
--     colis en vue et ne garde que 25 contours.
--   - Casse (WindowService.OnBroken, vitrine d'un magasin PNJ) : le magasin ouvre pour
--     Balance.Heist.Duration (6 s depuis le 2026-11-14). Vitrine partagée (proposition de 5.3 point 8 et de la
--     section 15) : tout le monde peut entrer ; le casseur a Balance.Heist.BreakerHeadStart
--     (1 s) d'avance exclusive pour prendre un colis. HeistTimer(storeId, endsAt) part au
--     casseur et aux joueurs à TIMER_REACH studs ou moins du volume Bounds (a241), puis à ceux qui
--     s'approchent pendant le chrono ; HeistTimer(storeId, 0) le masque.
--   - Prise : GrabItem(slotId), en deux appels (voir « Maintien » plus bas). Le serveur vérifie :
--     magasin ouvert (et pas fermé pour lui), colis posé sur le rayon, avance du casseur, mains vides
--     (CarryService.IsCarrying), joueur vivant dans le volume Bounds et à GrabMaxDistance
--     (8 studs) au plus de l'emplacement (tolérance au début du maintien, voir « Portée »), maintien selon la rareté du colis (ShelfBoxes.GrabTime). Le
--     rayon se vide, CarryService.StartCarry reçoit le payload avec le contenu tiré à la mise en
--     rayon (ou celui de l'accroche du tuto, plus bas), et le chrono est masqué pour ce joueur
--     (« le chrono ne compte plus pour lui », 5.3 point 5).
--   - Accroche du tuto (5.11) : StoreHeistService.SetContentOverride(fn), appelée à chaque prise
--     avant StartCarry. fn peut remplacer, pour ce joueur, la rareté et l'objet du colis
--     qu'il soulève (1er colis, objet Rare garanti : Tutorial.
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
--     Balance.Heist.OneAtATimeCooldown s. Braquage en cours (V0) : le chrono HEIST d'un magasin dont
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
-- tout 10 fois par seconde : s'il sort du volume, s'éloigne au-delà de la portée (voir « Portée »), meurt, porte
-- déjà un colis, si le colis du rayon change ou si le magasin ferme, le maintien est annulé. Un
-- maintien non conclu expire GrabTime + HOLD_EXPIRY s après son début. Un seul maintien par
-- joueur : un appel sur un autre rayon remplace le précédent. Le client ne peut donc pas prendre
-- plus vite que GrabTime − 0,1 s, ni sans rester à portée pendant ce temps.
-- a265 (vague 79, Cantin le 20/11) : étape du maintien en 2e argument, GrabItem(slotId, phase) et
-- OpenShelfBox(slotId, phase), phase = "Begin" | "End" | "Cancel" (HOLD_PHASES ; toute autre valeur est
-- refusée). "Begin" ouvre TOUJOURS un nouveau maintien (StartedAt = maintenant), même si un maintien du
-- même rayon est déjà ouvert : une fin ne compte qu'à partir du dernier début, quoi que dise le client
-- (avant, un relâché trop tôt ne prévenait pas le serveur et un 2e appui 1 à 2 s après le 1er passait
-- pour une fin : objet donné au début de l'appui, sans maintien). "End" ne conclut qu'un maintien ouvert
-- sur ce rayon et cet objet (sinon refus, rien n'est ouvert). "Cancel" (le client l'envoie au relâché
-- avant la fin) vide le maintien de ce rayon, sans autre contrôle. Sans phase (nil) : l'ancien déroulé en
-- deux appels déduits de l'état du serveur, gardé pour les vieux appels ; il ne donne pas plus qu'un
-- Begin puis un End (GrabTime depuis le premier appel, à portée).
--
-- Portée (Cantin, 2026-11-14 ; GrabItem et OpenShelfBox) : le serveur voit le perso en retard d'environ
-- vitesse × latence (vu en Play : 12,6 studs au lieu de 7,5 en appuyant sur E en courant). Souple au début
-- et pendant le maintien, stricte à la fin. Au premier appel (début du maintien) et aux revérifications
-- (10 par seconde), la tolérance reachPad = min(WalkSpeed × (ping + Balance.Heist.ReachLatencyPad),
-- plafond) studs, plafond = max(ReachToleranceMin, WalkSpeed × ReachToleranceSeconds) (0,3 s, 8 studs et 0,5 s, V0 ; le
-- plafond suit la vitesse : 32,5 studs à 65 studs/s, Cantin le 14/11) s'ajoute à GrabMaxDistance, et le volume
-- Bounds est agrandi d'autant. WalkSpeed est celle du Humanoid côté serveur (réglée par le serveur),
-- ping = player:GetNetworkPing() : rien ne vient du client. Au second appel (fin du maintien, qui prend
-- ou lance l'ouverture), et pour un colis à GrabTime 0 (un seul appel) : contrôle strict (dans Bounds,
-- GrabMaxDistance au plus). Un tricheur qui envoie les deux appels de loin ne prend ni n'ouvre rien.
--
-- Ouverture des colis sur le rayon (liaison L-112, décisions de Cantin du 2026-11-12 ; valeurs :
-- Config/ShelfOpen ; attributs : Shared/ShelfOpenState). Le colis ne se porte plus fermé : on l'ouvre sur
-- son rayon, on voit l'objet, et c'est l'objet qu'on vole. Seul déroulé depuis la vague 53 (l'interrupteur
-- Features.ShelfOpen et l'ancien déroulé, gardé en secours, sont partis) : ce qui précède sur la prise
-- d'un colis fermé, son contenu tiré à la mise en rayon et son retour ne vaut plus.
--   - Règle du braquage (Clément, L-118 points 8 et 9, 2026-11-13 ; remplace le chrono de 10 s après la
--     casse) : (a) pendant la casse, vitrine pas cassée avant que le « ? » des témoins soit plein : la
--     police vient (WitnessService), et elle renvoie à la base. (b) Le chrono du vigile (« HEIST ») part à
--     la casse et dure Balance.Heist.Duration (Cantin, 2026-11-14 : 6 s ; avant, il reprenait la fin du chrono
--     lancé au premier coup, qui est maintenant le chrono de police de WindowService) ; il est montré à chaque intrus (entré dans Bounds pendant cette ouverture : Entered),
--     dedans ou dehors, objet ou non. Entre la casse et la fin du chrono, tout le monde peut entrer. À la
--     fin du chrono (chronoEnd) : GuardService.ChaseIntruder pour chaque intrus ENCORE DANS le magasin (a114,
--     Cantin 2026-11-13 : ceux qui en sont sortis avec un objet ont déjà le vigile de leur prise), même sans
--     objet, jamais un second vigile pour qui en a déjà un ; personne n'est sorti, ceux qui sont dedans
--     continuent d'ouvrir et de prendre ; celui qui n'y était pas n'entre plus (sorti devant la vitrine,
--     MESSAGES.Closed). Ouvrir un colis ne déclenche aucun vigile ; PRENDRE l'objet sorti, si (a114, Cantin
--     2026-11-13, revient en partie sur L-118) : un vigile sort tout de suite du GuardSpawn pour le preneur,
--     quel que soit le chrono, lié à cet objet (GuardService, « Objet lié »). (c) Dès qu'un intrus sort de Bounds, avec ou sans objet, le magasin est fermé pour lui (Closed :
--     rideau local baissé, sorti s'il revient) jusqu'à la réouverture (vitrine reconstruite), plus jusqu'au
--     départ de son vigile. Sorti SANS objet avant la fin du chrono (Cantin, 2026-11-13) : il n'a rien
--     volé, c'est fini pour lui ; il n'est plus intrus (retiré d'Entered : aucun vigile pour lui) et son
--     chrono disparaît tout de suite ; a241 (L-219 point 2, Chase.ChaseOnEmptyExit, V0 à true) : le vigile sort
--     tout de suite pour lui (GuardService.ChaseIntruder, poursuite d'intrus sans objet). Sorti en portant un objet, ou encore dedans à la fin du chrono : vigile
--     comme avant. Rideau local : la règle a70 reste (levé seulement pendant qu'un vigile, sorti pour un
--     AUTRE intrus, passe ; entrée toujours refusée) ; seul, plus aucun vigile ne le lève. Le magasin se ferme (closeStore, vrai rideau) quand le chrono est fini, que
--     plus personne n'est dans Bounds et qu'aucune ouverture ni réservation n'est en cours ; la vitrine est
--     reconstruite Balance.Window.RebuildDelay s après au plus tôt (point d'attente de WindowService, qui
--     reconstruit de toute façon au bout de son attente maximale, en sortant ceux qui y seraient encore).
--     Les témoins ne montent plus pendant l'ouverture (ils fuient à la casse, L-118 point 10).
--   - Lancement : OpenShelfBox(slotId), deux appels comme GrabItem (Cantin, 2026-11-13 : rester appuyé sur
--     E) : début puis fin du maintien, maintien = ShelfBoxes.GrabTime de la rareté du colis,
--     temps écoulé vérifié ici avec la même tolérance (GRAB_TIME_TOLERANCE) ; un seul appel ne lance rien.
--     Maintien d'ouverture à part (openHolds), revérifié 10 fois par seconde comme celui de la prise
--     (colis changé, refus d'ouverture, expiration GrabTime + HOLD_EXPIRY). Vérifié à chaque appel (9.4) : magasin
--     ouvert (fermé seulement quand plus personne n'y est, voir plus haut), colis posé, fermé et pas
--     déjà en cours d'ouverture, avance du casseur, magasin pas fermé pour lui, mains vides, joueur
--     vivant dans le volume Bounds et à GrabMaxDistance au plus (tolérance au début du maintien, « Portée »), anti-triche ; puis, au lancement seulement (fin du maintien),
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
--     dans le dossier ShelfBoxes, nommé ShelfItem_NN, tag ShelfItem, attributs SlotId, Slot, BoxRarity (vague 76 ; le
--     type du colis d'origine : son temps de prise), Landed, ItemId, Rarity, MutationSize,
--     MutationEffect, Income, ShelfLuck, ShelfReservedBy, ShelfReservedUntil (= sortie +
--     ShelfOpen.ReserveTime). BB_Item, halo et effets de la révélation sont posés par le client
--     (ShelfOpenController) d'après ces attributs. Annonce : Notify (Unbox.AnnounceKind) aux autres
--     joueurs à partir de ShelfOpen.AnnounceMinRarity.
--   - Prise de l'objet : GrabItem(slotId), deux appels comme avant (maintien selon la rareté du colis d'origine, vague 76).
--     Avant ShelfReservedUntil, seul l'ouvreur ; ensuite tout joueur dans le magasin. Mêmes contrôles
--     que pour un colis (Bounds, distance, mains vides, magasin pas fermé pour lui). Le portage est un
--     NPCItemPayload (CarryService : l'objet visible sur la tête, halo, BB_Carry) ; le vigile part à la
--     prise (a114 : GuardService.OnCarryStarted, lié à l'objet), le magasin se ferme pour lui quand il sort.
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
--     départ, personnage retiré, anomalie de l'anti-triche, refus du rangement, attrapé par un vigile de
--     jour dans le magasin d'où vient l'objet, Cantin 2026-11-13 : « Failed ») : il revole
--     vers son rayon, objet déjà sorti, sa réservation n'est pas relancée (V0 : le plus simple, la règle
--     des colis), sauf si son magasin a été rempli depuis ou si son rayon est occupé : il disparaît
--     (attrapé, « Caught » : un autre rayon libre du magasin d'abord, a174). 3e capture d'un même objet
--     (GuardService, Chase.ReturnToShelfAfterCatches) : le même retour qu'une capture dans son magasin.
--
-- Posé par le serveur, lu par HeistController, ShelfBoxController et StoreLockController :
--   sur le magasin : StoreId (texte), HeistOpen (booléen), ShutterClosedPivot (CFrame : pivot du
--     rideau baissé, s'il a un rideau) ; pendant le chrono seulement,
--     HeistEndsAt et HeistExclusiveUntil (heures serveur, workspace:GetServerTimeNow()) et
--     HeistBreakerId (UserId du casseur) ;
--   sur le Player : ClosedStores (texte, StoreId séparés par des virgules, triés ; absent = aucun) ;
--   sur chaque colis du rayon : tag ShelfBox ; SlotId (à renvoyer dans GrabItem, « <StoreId>/03 »),
--     Slot (nom de l'Attachment, « ShelfSlot_03 »), BoxRarity (rareté du colis, vague 76 : plus de Tier), Landed (false tant
--     qu'un colis rendu vole) ; son étiquette BB_Box ; BoxRarity (rareté de la
--     caisse, vague 32 ; Shared/ShelfOpenState) et les attributs ShelfOpen* de l'ouverture.
--
-- API (serveur) :
--   StoreHeistService.RefillAll(spread: boolean?) -> number
--       Nouveau tirage de tous les magasins (voir plus haut). Renvoie le nombre de colis posés
--       tout de suite (les magasins ouverts sont remplis à leur fermeture, pas comptés). Pour
--       NightCycleService (la nuit, 5.12), avec `spread` : un magasin par image (a229), renvoie le
--       nombre de magasins.
--   StoreHeistService.IsOpen(store) -> boolean
--       store = le Model du magasin ou son StoreId. true pendant le chrono (Balance.Heist.Duration).
--   Vague 50 (a158, Cantin 2026-11-14 : le colis porté fermé n'existe plus) : OnBoxGrabbed et ReturnBox
--       retirés, comme la prise d'un colis fermé (payload NPCBox) ; vague 53 : Features.ShelfOpen et les
--       restes de l'ancien déroulé sont partis (GrabItem ne prend plus que l'objet sorti).
--   StoreHeistService.SetContentOverride(fn?)
--       Accroche du tuto (voir plus haut). fn(player, drawn) -> override?, appelée à chaque prise,
--       ne doit pas yield. drawn = { StoreId, SlotId, Zone, Rarity, ItemId } (contenu du
--       colis du rayon). Un contenu remplacé n'a jamais de mutation (DEV-131 : jamais pour le colis
--       du tuto). override = nil (rien ne change) ou { Rarity?, ItemId? } (vague 76 : plus de Tier) :
--       ItemId = objet (de la zone du
--       magasin, ou un Secret) ; Rarity seule = un objet de cette rareté est tiré dans la zone
--       (Items.Pick : jamais un objet TutorialOnly, sans le repli de la mise en rayon).
--       Un remplacement invalide est ignoré, avec un avertissement. nil retire l'accroche.
--       Vague 31 : appelée à la sortie de l'objet, pour l'ouvreur, avant tout tirage ;
--       drawn.Rarity = rareté de la caisse et drawn.ItemId = "" (contenu pas encore tiré, vague 32) ;
--       un override avec ItemId ou Rarity donne l'objet sorti tel quel, sans tirage ni mutation.
--   StoreHeistService.SetLuckOverride(fn?)  (vague 31, a107)
--       Accroche du tuto : fn(player, drawn) -> number?, appelée au lancement de chaque ouverture sur
--       le rayon, sans yield ; un nombre fini ≥ 1 remplace la chance tirée ; nil ou une valeur invalide
--       garde le tirage de LuckTable. nil retire l'accroche. drawn comme pour SetContentOverride
--       (Rarity = rareté de la caisse, ItemId = "").
--   StoreHeistService.AddEventShelf(options) -> Model? et RemoveEventShelf(id) -> boolean  (vague 42, a148)
--       Rayon d'événement : colis du coffre de la Fortune Tower (et du camion) ouverts sur place comme sur
--       un rayon (voir « Rayons d'événement », plus bas dans ce fichier).
--   StoreHeistService.GetStoreId(model) -> string? et GetStoreModel(storeId) -> Model?
--       StoreId = l'id de vitrine de WindowService (le nom du modèle, « STORE_Z1_Superette »).
--   StoreHeistService.DrawForZone(zone) -> (Content?, chance)  (vague 58, a188 : pluie d'objets)
--       Un objet tiré comme sur un rayon d'un magasin de la zone, sans rayon ni caisse (voir la fonction).
--
-- Payload d'un objet sorti, transmis à CarryService : { Kind = "NPCItem", ItemId, Rarity, Mutation?, Zone,
-- StoreId, SlotId, Luck, Weight? } (Shared/Types/Carry ; Weight : vague 62).
--
-- Vague 62 (décision de Cantin et Clément, liaison L-198 ; Features.SingleBoxReveal, valeurs V0 de
-- Config/ShelfOpen.Reveal) : un seul colis par braquage, la cinématique, l'objet porté d'office. Sur un magasin
-- PNJ (jamais un rayon d'événement, qui garde l'ouverture d'avant), à la fin du maintien d'OpenShelfBox :
--   - tirage complet tout de suite, sur le serveur : chance de la boîte = le tirage de ShelfOpen.LuckTable
--     (Reveal.TableLuck ; la montée avec le temps et sa coupure par la police n'existent pas ici, le bonus
--     LiveEventShelfLuck est coupé par Reveal.EventLuck), accroche du tuto d'abord ; rareté par la caisse et
--     cette chance (BoxRarityOdds, LuckBoost), objet, mutation d'effet (Mutations.Roll), poids
--     (ItemWeight.Roll avec la même chance), mutation de taille par le poids (ItemWeight.SizeMutationFor, à la
--     place de celle tirée), taille (ScaleFor) et classe (SizeClassFor : hauteur libre jusqu'au haut de Bounds,
--     hauteur de ITM_<ItemId> ou du bloc V0) ;
--   - cinématique : aucun attribut ShelfOpen* sur le colis (l'ouverture d'avant ne joue pas chez le client),
--     RevealStarted à tous les clients ;
--     l'ouvreur est protégé (attribut RevealProtected du Player, Shared/ShelfOpenState.ProtectedAttribute : GuardService fige ses
--     vigiles, BatService refuse la batte, ChaseIntruder et les vigiles de nuit l'ignorent) et immobile
--     (StatsService, modificateur « Reveal » à 0) ; son chrono est en pause (masqué, le vigile de fin de chrono
--     attend) ; ni prise ni autre ouverture pour lui (reachRefusal) ; Large ou Colossal : attribut CeilingBroken
--     du magasin à true, remis à false Reveal.CeilingRepairSeconds s après la fin de la dernière ;
--   - fin sur RevealDone de l'ouvreur ou au plafond Reveal.RevealMaxSeconds[classe], le premier des deux (sortie,
--     mort, colis retiré : fin propre) : protection levée, RevealEnded à tous, colis retiré, objet porté d'office
--     (CarryService.StartCarry, comme une prise : le vigile lié part, GuardService) ; sinon posé sur le rayon,
--     réservé à l'ouvreur comme avant ; sans objet, son chrono reprend où il était (pausedChronos).
--   - un seul colis par braquage : tant qu'il porte son objet, « mains pleines » ; il rouvre après dépôt, perte
--     ou retour au rayon. Ensuite tout est comme avant (capture, 3 captures, dépôt).
--   Le poids suit l'objet : Content.Weight, payload Weight, attribut Weight de l'objet posé sur un rayon ; avec
--   un poids, la taille et le revenu de l'objet posé viennent du poids (ItemWeight.ScaleFor, IncomeFactor).

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
local Formulas = require(Shared.Config.Formulas)
local ShelfOpen = require(Shared.Config.ShelfOpen)
local Unbox = require(Shared.Config.Unbox)
local Attributes = require(Shared.Contract.Attributes)
local Net = require(Shared.Net.Net)
local Announce = require(Shared.Announce) -- a254 (L-240 point 3)
local ShelfOpenState = require(Shared.ShelfOpenState)
local Features = require(Shared.Config.Features)
-- a241 : Chase.ChaseOnEmptyExit ; Config/Chase absent (bancs à arbre partiel) : la règle d'avant.
local Chase: any = if Shared.Config:FindFirstChild("Chase") then require(Shared.Config.Chase) :: any else {}
-- Vague 62 (a203) : poids de l'objet tiré. Absent (faux arbres de bancs plus anciens) : aucun poids tiré, les replis
-- de rollWeight, scaleFor, sizeClassFor (chaque appel passe par pcall).
local ItemWeight: any = if Shared:FindFirstChild("ItemWeight") then require(Shared.ItemWeight) else {}

local AntiCheatService = require(script.Parent.AntiCheatService)
local WindowService = require(script.Parent.WindowService)


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
	Weight: number?, -- vague 62 : poids tiré à l'ouverture (kg, Shared/ItemWeight) ; nil dans l'ancien déroulé
}

-- Contenu du colis du rayon, passé à l'accroche du tuto.
export type OverrideInfo = {
	StoreId: string,
	SlotId: string,
	Zone: number,
	Rarity: string, -- rareté du colis (vague 76 : plus de type de colis)
	ItemId: string,
}

-- Ce que l'accroche du tuto remplace (champs absents = inchangés).
export type OverrideResult = {
	Rarity: string?,
	ItemId: string?,
}

export type ContentOverride = (player: Player, drawn: OverrideInfo) -> OverrideResult?
-- Vague 31 (a107) : chance imposée par le tuto au lancement d'une ouverture (nil = tirage normal).
export type LuckOverride = (player: Player, drawn: OverrideInfo) -> number?

-- Ce que ce service utilise de CarryService (a11, DEV-017). Typé ici pour ne pas dépendre
-- des noms de types de son module.
type CarryApi = {
	StartCarry: (player: Player, payload: NPCItemPayload) -> boolean,
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
-- Vague 62 : Weight = poids tiré à l'ouverture (kg) ; nil dans l'ancien déroulé (Features.SingleBoxReveal = false).
type Content = { Rarity: string, ItemId: string, Mutation: Mutations.Mutation?, Weight: number? }

-- Ouverture en cours d'un colis sur son rayon (L-112).
type Opening = {
	ByUserId: number, -- l'ouvreur
	Luck: number, -- chance tirée (≥ 1)
	OpenAt: number, -- heure serveur du lancement
	Cinematic: boolean?, -- vague 62 : cinématique (Reveal), sans montée de chance ni sortie différée
}

-- Colis posé sur un rayon, ou en vol vers lui.
type ShelfBox = {
	Rarity: string, -- rareté de la caisse (BOX_<Rareté>, BB_Box) ; le contenu n'est tiré qu'à la sortie (reveal, vague 32)
	Model: Model,
	Landed: boolean, -- false tant que le colis rendu vole vers le rayon
	StopFlight: (() -> ())?,
	Opening: Opening?, -- L-112 : en cours d'ouverture ; nil = fermé
}

-- Ce qui décrit un objet sorti d'un colis (L-112), sur son rayon comme une fois porté ou au sol.
type ItemInfo = {
	BoxRarity: string, -- vague 76 : rareté du colis d'origine : son temps de prise (ShelfBoxes.GrabTime)
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
	-- Règle du braquage de Clément (L-118 points 8 et 9 ; voir l'en-tête) :
	Entered: { [Player]: boolean }, -- entrés dans Bounds pendant cette ouverture (les intrus)
	ChronoOver: boolean, -- chrono du vigile fini : les vigiles sont sortis
	ClosedAt: number, -- os.clock() de la dernière fermeture (reconstruction RebuildDelay s après au plus tôt)
	KickAfter: { [Player]: number }, -- attrapé dans Bounds : fermé pour lui, sorti à cet os.clock() (après le coup)
	-- Vague 42 (a148) : rayon d'événement (AddEventShelf) : ni Bounds, ni chrono, ni témoins, ni vigile,
	-- ni accroches du tuto ; ItemZones : zones des objets à la sortie (nil = celles du magasin).
	Event: boolean?,
	ItemZones: { number }?,
	SizeOdds: { [string]: number }?, -- tailles garanties de l'événement (nil : celles de Mutations.Roll)
	NextZoneChance: number?, -- vague 56 (a181, L-166 Q5) : voir EventShelfOptions
}

-- Vague 62 (Features.SingleBoxReveal) : cinématique d'ouverture en cours d'un joueur (voir l'en-tête).
type Reveal = {
	Id: string, -- RevealId des remotes RevealStarted, RevealEnded et RevealDone
	Player: Player,
	Slot: Slot,
	Box: ShelfBox,
	Opening: Opening,
	Info: ItemInfo, -- contenu tiré (poids compris), porté ou posé à la fin
	SizeClass: string,
	StartedAt: number, -- os.clock()
	ChronoLeft: number?, -- secondes de chrono du braquage restantes au début ; nil : chrono déjà fini
	Ceiling: boolean, -- a cassé le plafond (Large ou Colossal)
	Ended: boolean,
}

-- Chrono personnel d'un ouvreur resté sans objet après sa cinématique (repli) : le temps de la pause en plus.
type PausedChrono = { Store: Store, EndsAt: number, Token: number }

-- Plafond cassé d'un magasin : cinématiques Large ou Colossal en cours, jeton de la réparation différée.
type Ceiling = { Count: number, Token: number }

-- Leaving : vient de prendre un colis, encore dans Bounds avec lui ; Closed : fermé pour lui, rideau
-- baissé chez lui et sorti s'il entre.
type LockState = "Leaving" | "Closed"

-- Target : le colis (ShelfBox) ou l'objet sorti (ShelfItem, L-112) visé par le maintien.
type Hold = { Slot: Slot, Target: any, BoxRarity: string, StartedAt: number }


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
local BOX_PREFIX = "BOX_" -- BOX_<Rareté> (L-097 point 3), sinon l'ancien BOX_<Standard|Premium|Luxe> (vague 76 : lookOf)

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
local LANDED_ATTRIBUTE = "Landed"
-- Objet sorti d'un colis (L-112) : nom du modèle et attributs lus par le client (ShelfOpenController,
-- HeistController), en plus de ceux de Shared/ShelfOpenState.
local ITEM_NAME_FORMAT = "ShelfItem_%02d"
local ITEM_ID_ATTRIBUTE = "ItemId"
local RARITY_ATTRIBUTE = "Rarity"
local MUTATION_SIZE_ATTRIBUTE = "MutationSize"
local MUTATION_EFFECT_ATTRIBUTE = "MutationEffect"
local INCOME_ATTRIBUTE = "Income"
local WEIGHT_ATTRIBUTE = "Weight" -- vague 62 : poids de l'objet (kg), contrat a202, a203, a204
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
-- du magasin (le boulevard devant lui et le magasin d'en face). Sert seulement sans volume Bounds.
local TIMER_RADIUS = 60
-- a241 (L-226, magasins de 78 × 108) : avec Bounds, le chrono est montré à TIMER_REACH studs ou moins du volume
-- (à 0 dedans), quelle que soit la taille du magasin. 25 = la portée d'avant devant la vitrine (60 − 34,5, la
-- demi-profondeur de l'ancien Bounds de 57 × 69) ; mesurée du centre, elle tombait à 7,5 studs devant la vitrine
-- des grands magasins (centre de Bounds reculé de 18). V0 proposé, absent du doc.
local TIMER_REACH = 25
-- V0 proposé, absent du doc : écart du réseau toléré sur la durée de maintien.
local GRAB_TIME_TOLERANCE = 0.1
-- V0 proposé, absent du doc : un maintien non conclu expire 1 s après sa durée.
local HOLD_EXPIRY = 1
-- a265 (vague 79) : étapes du maintien acceptées en 2e argument de GrabItem et d'OpenShelfBox (voir « Maintien »).
local HOLD_PHASES = { Begin = true, End = true, Cancel = true }
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
-- Vague 62, V0 proposé, absent du doc : hauteur libre au-dessus d'un rayon d'un magasin sans Bounds (classe de
-- taille, ItemWeight.SizeClassFor) ; clé du modificateur de vitesse qui immobilise l'ouvreur (StatsService).
local V0_FREE_HEIGHT = 10
local REVEAL_SPEED_KEY = "Reveal"
-- V0 proposé, absent du doc : au plus un Notify « les témoins appellent la police » par seconde et par joueur.
local CALL_NOTICE_INTERVAL = 1

-- Messages lus par le joueur (Notify), en anglais (L-036).
local MESSAGES = {
	Closed = "Too late: the shutter came down!",
	WitnessCalling = "Witnesses are calling the police!", -- V0 (L-112) : ouverture refusée pendant l'appel
}


local IS_STUDIO = RunService:IsStudio()

local StoreHeistService = {}
StoreHeistService.Priority = PRIORITY

local stores: { [Instance]: Store } = {}
local eventStores: { [Instance]: Store } = {} -- vague 42 : rayons d'événement (AddEventShelf), hors des boucles des magasins
local storesById: { [string]: Store } = {}
local slotsById: { [string]: Slot } = {}
local holds: { [Player]: Hold } = {}
local openHolds: { [Player]: Hold } = {} -- maintiens d'ouverture d'un colis sur le rayon (L-112, Cantin 2026-11-13)
-- Objets sortis de leur magasin (L-112), par payload NPCItem (la table donnée à StartCarry, que CarryService
-- garde telle quelle). Vague 50 (a158) : plus de colis sorti fermé (outBoxes, payload NPCBox).
local outItems: { [any]: OutItem } = {}
local lastCallNotice: { [Player]: number } = {} -- dernier Notify « les témoins appellent la police »
local witnessApi: WitnessApi? = nil -- WitnessService, s'il existe (Init)

local contentOverride: ContentOverride? = nil
local luckOverride: LuckOverride? = nil -- accroche du tuto (a107), voir SetLuckOverride
local lastRefusal: { [Player]: number } = {}
local lastGreedy: { [Player]: number } = {} -- dernier message « un seul braquage à la fois »
-- GuardService.GetReturningGuards, s'il existe (require protégé dans Init, comme OnGuardGone).
local returningGuards: ((store: Model) -> { BasePart })? = nil
-- GuardService.ChaseIntruder, s'il existe (Init) : le vigile sort à la fin du chrono (L-118).
local chaseIntruder: ((player: Player, store: Model) -> boolean)? = nil
-- GuardService.IsInSafeZone, s'il existe (Init) ; sans lui, personne n'est en zone safe (a157).
local inSafeZone: ((position: Vector3) -> boolean)? = nil
local templates: { [string]: Instance } = {} -- BOX_<Rareté> ou BOX_<Tier> trouvé, par nom
local templateSearched: { [string]: boolean } = {} -- cherché une fois par nom, trouvé ou non
local noticed: { [string]: boolean } = {}
local random = Random.new()
-- Vague 62 (Features.SingleBoxReveal) : cinématiques en cours, par joueur et par RevealId ; chronos repris
-- d'un ouvreur sans objet ; plafonds cassés ; StatsService.SetSpeedModifier (require protégé dans Init).
local reveals: { [Player]: Reveal } = {}
local revealsById: { [string]: Reveal } = {}
local revealCount = 0
local pausedChronos: { [Player]: PausedChrono } = {}
local ceilings: { [Store]: Ceiling } = {}
local setSpeedModifier: ((player: Player, key: string, multiplier: number?) -> ())? = nil

-- Outils ----------------------------------------------------------------------------------

-- Le magasin (ou le rayon d'événement, vague 42) est encore en jeu.
local function live(store: Store): boolean
	return stores[store.Model] == store or eventStores[store.Model] == store
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

-- Tolérance de portée pendant un maintien (Cantin, 2026-11-14) : min(WalkSpeed × (ping + ReachLatencyPad),
-- plafond) studs, plafond = max(ReachToleranceMin, WalkSpeed × ReachToleranceSeconds). WalkSpeed lue sur le serveur (il la règle), ping mesuré par Roblox : rien du client.
local function reachPad(player: Player, humanoid: Humanoid?): number
	-- Lectures protégées (comme pingOf d'AntiCheatService) : les faux Roblox des bancs n'ont pas toujours ces membres.
	local okPing, ping = pcall(function(): number
		return player:GetNetworkPing()
	end)
	local okSpeed, walkSpeed = pcall(function(): number
		return if humanoid then humanoid.WalkSpeed else 0
	end)
	local latency = (if okPing and type(ping) == "number" and ping > 0 then ping else 0) + Balance.Heist.ReachLatencyPad
	local speed = if okSpeed and type(walkSpeed) == "number" and walkSpeed > 0 then walkSpeed else 0
	-- Plafond qui suit la vitesse (Cantin, 2026-11-14) : max(ReachToleranceMin, WalkSpeed × ReachToleranceSeconds).
	local cap = math.max(Balance.Heist.ReachToleranceMin, speed * Balance.Heist.ReachToleranceSeconds)
	return math.min(speed * latency, cap)
end
-- Vague 51 (a165) : la même tolérance pour StealItem (PvPService, require protégé), sans la recopier.
StoreHeistService.ReachPad = reachPad

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

-- Vague 76 (Cantin et Clément, 19/11) : rareté du colis d'un emplacement de rayon de la zone `zone`, tirée dans
-- ShelfBoxes.ZoneOdds[zone] (pourcentages) : plus de type de colis (Standard, Premium, Luxe) sur les rayons.
local function drawRarity(zone: number): string?
	local odds = ShelfBoxes.ZoneOdds[zone]
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

-- Mutation d'un objet sorti (DEV-131, L-084 point 3), tirée à la sortie (vague 32), jamais pour un objet
-- TutorialOnly (qu'aucun tirage ne donne : garde-fou). L'ancien tirage du contenu à la mise en rayon
-- (drawContent) est parti avec Features.ShelfOpen (vague 53).
local function drawMutation(itemId: string): Mutations.Mutation?
	local item = Items.ById[itemId]
	if item == nil or item.TutorialOnly then
		return nil
	end
	return Mutations.Roll(random)
end

-- Vague 76 : apparence d'un colis de rareté `rarity` sans modèle BOX_<Rareté> : l'ancien type de même temps de prise
-- (0,3 s Standard, 0,6 s Premium, 1 s Luxe), pour le modèle BOX_<Type> de Clément ou le bloc V0. Apparence seule.
local function lookOf(rarity: string): string
	local grab = ShelfBoxes.GrabTime(rarity)
	return if grab >= 1 then "Luxe" elseif grab >= 0.6 then "Premium" else "Standard"
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
local function makeV0Box(rarity: string): Model
	local look = V0_LOOKS[lookOf(rarity)] or V0_LOOKS.Standard
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

-- Modèle d'un colis pour l'emplacement `slot`, avec son étiquette BB_Box : celui de la rareté `rarity` de la caisse,
-- tirée à la mise en rayon (BOX_<Rareté>, L-097 point 3), sinon l'ancien BOX_<Type> de même temps de prise (lookOf,
-- vague 76), sinon le bloc V0. Seul le modèle change : la rareté est la règle de jeu (prise, contenu).
-- Vague 32 : étiquette à la rareté seule, attribut BoxRarity ; jamais d'ItemId, de Rarity d'objet ni de
-- mutation sur le colis.
local function makeBoxModel(slot: Slot, rarity: string): Model
	local model: Model? = nil
	local template = boxTemplate(BOX_PREFIX .. rarity) or boxTemplate(BOX_PREFIX .. lookOf(rarity))
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
	local box = model or makeV0Box(rarity)
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
	box:SetAttribute(ShelfOpenState.BoxRarityAttribute, rarity)
	CollectionService:AddTag(box, SHELF_BOX_TAG)
	local ok, label = pcall(CarryService.AttachBoxLabel, box, rarity, nil, nil)
	if not ok then
		warnOnce("label.error", `CarryService.AttachBoxLabel : {label}`)
	elseif label == nil then
		warnOnce(`label.{rarity}`, `colis {rarity} de {slot.Id} : aucune étiquette BB_Box posée (colis sans pièce ?)`)
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
-- caisse (le contenu est tiré à la sortie, vague 32).
local function placeBox(slot: Slot, rarity: string, from: Vector3?)
	local model = makeBoxModel(slot, rarity)
	local box: ShelfBox = { Rarity = rarity, Model = model, Landed = false, StopFlight = nil }
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

-- Objets sortis des colis (L-112) --------------------------------------------------------------------

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

-- $/s de l'objet (attribut Income, pour BB_Item), comme une fois exposé (DisplayService) : Formulas.ItemIncome
-- (vague 76 : rareté, zone et rang de l'objet), mutation comprise.
-- Vague 62 : avec un poids (Content.Weight), le poids remplace la mutation de taille dans le revenu
-- (ItemWeight.IncomeFactor ; seule la mutation d'effet compte en plus).
local function itemIncome(zone: number, content: Content): number
	local base = if Items.ById[content.ItemId] then Formulas.ItemIncome(content.ItemId) else 0 -- vague 76 : rareté, zone, rang
	local weight = content.Weight
	if weight == nil then
		return base * Mutations.IncomeMultiplier(content.Mutation)
	end
	local mutation = content.Mutation
	local effect = Mutations.IncomeMultiplier(if mutation and mutation.Effect then { Effect = mutation.Effect } else nil)
	local ok, factor = pcall(ItemWeight.IncomeFactor, weight)
	local safe = if ok and type(factor) == "number" and factor >= 0 and factor < math.huge then factor else 1
	return base * effect * safe
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
	-- Vague 62 : avec un poids, la taille vient du poids (ItemWeight.ScaleFor), plus de la mutation de taille.
	local scale = Mutations.Scale(content.Mutation)
	local weight = content.Weight
	if weight ~= nil then
		local ok, value = pcall(ItemWeight.ScaleFor, weight)
		scale = if ok and type(value) == "number" and value > 0 and value < math.huge then value else 1
	end
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
	object:SetAttribute(ShelfOpenState.BoxRarityAttribute, info.BoxRarity) -- vague 76 : temps de prise (HeistController)
	object:SetAttribute(ITEM_ID_ATTRIBUTE, content.ItemId)
	object:SetAttribute(RARITY_ATTRIBUTE, content.Rarity)
	object:SetAttribute(MUTATION_SIZE_ATTRIBUTE, if mutation then mutation.Size else nil)
	object:SetAttribute(MUTATION_EFFECT_ATTRIBUTE, if mutation then mutation.Effect else nil)
	object:SetAttribute(INCOME_ATTRIBUTE, itemIncome(slot.Store.Zone, content))
	object:SetAttribute(WEIGHT_ATTRIBUTE, weight) -- vague 62 : absent dans l'ancien déroulé
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
	if api == nil or store.Event then
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

-- Vague 71 (a239, L-216 point 4) : annonce à tout le serveur quand un colis de Unbox.NightBoxMinRarity ou plus
-- apparaît sur un rayon la nuit (attribut NightPhase = "Night" du Workspace, posé par NightCycleService avant
-- RefillAll ; aussi un magasin rempli à sa fermeture pendant la nuit). Les colis apparus en NightBoxGroupDelay s
-- partent en une seule annonce (Notify Unbox.AnnounceKind, à tous). Rayons d'événement exclus.
local NIGHT_PHASE_ATTRIBUTE = "NightPhase" -- NightCycleService (comme HudController et SkyController)
type NightBox = { Store: Store, Rarity: Rarities.Rarity }
local nightBoxes: { NightBox } = {}
local nightBatch = false -- a254 : le paquet en cours est-il de nuit

-- Nom anglais du magasin (Config/Zones.Stores, par son Id ou par le nom STORE_Z<n>_<Id> du modèle), sinon « Zone N ».
local function storeDisplayName(store: Store): string
	local zone = Zones[store.Zone]
	local rest = string.match(store.Model.Name, "^STORE_Z%d+_(.+)$")
	if zone then
		for index, id in zone.StoreIds do
			if store.Id == id or rest == id or (rest ~= nil and string.sub(rest, 1, #id + 1) == `{id}_`) then
				local name = zone.Stores[index]
				if name then
					return name
				end
			end
		end
	end
	return `Zone {store.Zone}`
end

local function flushNightBoxes()
	local list = nightBoxes
	nightBoxes = {}
	local night = nightBatch
	local best = list[1]
	if best == nil then
		return
	end
	for _, entry in list do
		if entry.Rarity.Order > best.Rarity.Order then
			best = entry
		end
	end
	Announce.boxes(best.Rarity, storeDisplayName(best.Store), best.Store.Zone, #list, night) -- a254 : UI_Announce (repli Notify)
	log(`annonce {if night then "de nuit" else "de jour"} : {#list} colis, {best.Rarity.Id} à {storeDisplayName(best.Store)}`)
end

local function noteNightBoxes(store: Store)
	-- a254 : de jour aussi, à partir de Config/Announce.DayBoxMinRarity (nil : coupée).
	local night = Workspace:GetAttribute(NIGHT_PHASE_ATTRIBUTE) == "Night"
	local minimumId = if not night then Announce.dayBoxMinRarity() elseif Unbox.NightBoxAnnounce == true then Unbox.NightBoxMinRarity else nil
	local minimum = if minimumId then Rarities.ById[minimumId] else nil
	if store.Event or minimum == nil then
		return
	end
	local first = #nightBoxes == 0
	if first then
		nightBatch = night
	end
	for _, slot in store.Slots do
		local box = slot.Box
		local rarity = if box then Rarities.ById[box.Rarity] else nil
		if rarity and rarity.Order >= minimum.Order then
			table.insert(nightBoxes, { Store = store, Rarity = rarity })
		end
	end
	if first and #nightBoxes > 0 then
		task.delay(math.max(Unbox.NightBoxGroupDelay, 0), flushNightBoxes)
	end
end

-- Nouveau tirage du magasin (L-031, L-033, 5.12) : retire tous ses colis (posés ou en vol de
-- retour), oublie ceux qui en sont sortis, puis répartit au hasard un jeu neuf de colis sur ses
-- rayons, chacun avec son contenu tiré. Renvoie le nombre de colis posés.
local function fillStore(store: Store): number
	store.RefillPending = false
	cancelHolds(store)
	for payload, out in outItems do
		if out.Slot.Store == store then
			outItems[payload] = nil -- objet sorti d'un colis du tirage précédent : il ne reviendra pas
		end
	end
	for _, slot in store.Slots do
		removeBox(slot)
		removeItem(slot)
	end
	local count = 0
	for _, slot in store.Slots do
		-- Vague 32 : la rareté de la caisse seule ; le contenu est tiré à la sortie. Vague 76 : un colis par
		-- emplacement, sa rareté tirée dans celles de la zone (ShelfBoxes.ZoneOdds).
		local rarity = drawRarity(store.Zone)
		if rarity then
			placeBox(slot, rarity, nil)
			count += 1
		else
			warnOnce(
				`draw.{store.Zone}`,
				`aucun colis ne peut être tiré en zone {store.Zone} (Config : ShelfBoxes, Rarities, Items) : rayon laissé vide`
			)
		end
	end
	noteNightBoxes(store) -- vague 71 (a239) : annonce de nuit des colis rares
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
	-- Vague 72 (a246, L-229 B) : Shutter_Close en 3D sur le rideau (son absent : muet).
	pcall(function()
		(require(Shared.Anim.MarkerSounds) :: any).play("Shutter_Close", if shutter:IsA("BasePart") then shutter else shutter:FindFirstChildWhichIsA("BasePart", true))
	end)
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
	-- jamais être pris pendant le chrono.
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
		local sheltered = rootOf(player)
		local safe = inSafeZone
		local paused = pausedChronos[player]
		if reveals[player] ~= nil then
			hideTimer(store, player) -- vague 62 : sa cinématique, chrono en pause pour lui
		elseif paused ~= nil and paused.Store == store then
			continue -- vague 62 : son chrono personnel, repris après sa cinématique (resumeChrono)
		elseif sheltered and safe and safe(sheltered.Position) then
			-- a157 (Cantin, 2026-11-14) : à l'abri, plus de chrono ni de vigile de fin de chrono pour lui ici.
			if store.Entered[player] then
				store.Entered[player] = nil
				log(`{player.Name} en zone safe : plus de chrono ni de vigile pour {store.Id}`)
			end
			hideTimer(store, player)
		elseif store.Entered[player] then
			showTimer(store, player) -- L-118 : le vigile viendra pour lui à la fin, dedans ou dehors, objet ou non
		elseif isCarrying(player) or store.Locked[player] ~= nil then
			hideTimer(store, player)
		elseif not store.Viewers[player] then
			local root = rootOf(player)
			local bounds = store.Bounds
			if
				root
				and (
					if bounds
						then distanceTo(bounds, root.Position) <= TIMER_REACH
						else (root.Position - center).Magnitude <= TIMER_RADIUS
				)
			then
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
local grabRefusal: (player: Player, slot: Slot, lenient: boolean) -> string?

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
		if hold.Slot.Store == store and grabRefusal(player, hold.Slot, true) ~= nil then
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

-- Fin du chrono du vigile (L-118 points 8 et 9) : le vigile sort et poursuit chaque intrus encore dans le
-- magasin, même sans objet (plafonds de GuardService ; jamais un second vigile pour qui en a déjà un) ;
-- personne n'est sorti du magasin. a114 (Cantin, 2026-11-13) : un intrus déjà sorti l'a fait avec un objet,
-- et le vigile de sa prise s'en occupe (lié à l'objet, GuardService) : rien de plus pour lui ici.
local function chronoEnd(store: Store)
	store.ChronoOver = true
	-- Vague 62 : chrono en pause pendant la cinématique d'un ouvreur, puis repris pour lui (resumeChrono) ; le
	-- vigile de fin de chrono viendra pour lui à la fin de son chrono, pas maintenant.
	local function deferred(player: Player): boolean
		local paused = pausedChronos[player]
		local session = reveals[player]
		return (session ~= nil and session.Slot.Store == store) or (paused ~= nil and paused.Store == store)
	end
	for player in table.clone(store.Viewers) do
		if not deferred(player) then
			hideTimer(store, player)
		end
	end
	local inStore: { Player } = {}
	local outside = 0
	local bounds = store.Bounds
	for player in store.Entered do
		local root = rootOf(player)
		if deferred(player) then
			log(`{store.Id} : fin du chrono, {player.Name} en cinématique ou chrono repris : son vigile attend la fin de son chrono`)
		elseif player.Parent == Players and root then
			if bounds == nil or inside(bounds, root.Position) then
				table.insert(inStore, player)
			else
				outside += 1
			end
		end
	end
	local sent = 0
	local chase = chaseIntruder
	if chase then
		for _, player in inStore do
			local ok, started = pcall(chase, player, store.Model)
			if ok and started == true then
				sent += 1
			elseif not ok then
				warn(`[StoreHeistService] GuardService.ChaseIntruder({player.Name}) : {started}`)
			end
		end
	end
	log(`{store.Id} : fin du chrono, {sent} vigile(s) sorti(s) pour {#inStore} intrus dans le magasin ({outside} déjà sorti(s) avec un objet)`)
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
				local chase = chaseIntruder
				if Chase.ChaseOnEmptyExit and chase and player.Parent == Players then
					-- a241 (L-219 point 2) : casser puis sortir suffit, le vigile sort tout de suite pour lui (hors du
					-- pas : ChaseIntruder peut attendre le rig de remplacement).
					log(`{player.Name} sorti de {store.Id} sans objet : rideau baissé pour lui, le vigile sort pour lui (Chase.ChaseOnEmptyExit)`)
					local model = store.Model
					task.spawn(function()
						local ok, err = pcall(chase, player, model)
						if not ok then
							warn(`[StoreHeistService] GuardService.ChaseIntruder({player.Name}) : {err}`)
						end
					end)
				else
					log(`{player.Name} sorti de {store.Id} sans objet : rideau baissé pour lui, plus de chrono ni de vigile`)
				end
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

-- Chrono « HEIST » : Balance.Heist.Duration s à partir de la casse (Cantin, 2026-11-14, rééquilibrage v2 :
-- 6 s ; remplace L-118 point 9, où il reprenait la fin du chrono lancé au premier coup, devenu le chrono de
-- police de WindowService).
local function openStore(store: Store, breaker: Player?)
	if store.Open then
		return
	end
	local now = Workspace:GetServerTimeNow()
	local duration = Balance.Heist.Duration
	store.Open = true
	store.Token += 1
	local token = store.Token
	store.Breaker = if breaker and breaker.Parent == Players then breaker else nil
	store.ExclusiveUntil = os.clock() + Balance.Heist.BreakerHeadStart
	store.EndsAt = now + duration
	store.Entered = {}
	store.ChronoOver = false
	store.ShutterPending = false
	for player, paused in pausedChronos do
		if paused.Store == store then
			pausedChronos[player] = nil -- vague 62 : chrono repris d'une ouverture précédente, périmé
		end
	end
	raiseShutter(store, true) -- au cas où il serait resté baissé
	setHeistAttributes(store)
	local first = store.Breaker
	if first and not isCarrying(first) then
		showTimer(store, first)
	end
	updateViewers(store)
	task.delay(duration, function()
		if store.Token == token and stores[store.Model] == store then
			chronoEnd(store) -- L-118 : le magasin reste ouvert pour ceux qui y sont
		end
	end)
	log(
		`{store.Id} ouvert, chrono du vigile {math.round(duration * 10) / 10} s, par {if first then first.Name else "?"} ({Balance.Heist.BreakerHeadStart} s d'avance pour lui)`
	)
end

-- Prise ----------------------------------------------------------------------------------------------

-- Temps de prise d'un colis de rareté `rarity` (ou de l'objet sorti d'un tel colis, L-112). Vague 76 : selon la rareté
-- du colis (ShelfBoxes.GrabTime), plus selon son type.
local function grabTime(rarity: string): number
	return ShelfBoxes.GrabTime(rarity)
end

-- Raison pour laquelle `player` ne peut ni prendre ni ouvrir sur `slot`, quoi qui s'y trouve (magasin
-- fermé pour lui, mains pleines, pas de personnage vivant, hors du volume Bounds, trop loin), ou nil.
-- `lenient` (début du maintien et revérifications, voir « Portée » dans l'en-tête) : distance et volume
-- Bounds tolèrent reachPad(...) studs de plus ; sinon (fin du maintien, prise sans maintien) : strict.
local function reachRefusal(player: Player, slot: Slot, lenient: boolean): string?
	local store = slot.Store
	if reveals[player] ~= nil then
		return "cinématique d'ouverture en cours" -- vague 62 : un seul colis par braquage, ni prise ni ouverture
	end
	if store.Locked[player] then
		return "magasin fermé pour lui : son vigile n'est pas encore rentré"
	end
	if isCarrying(player) then
		return "mains pleines" -- vague 62 : aussi « un seul colis par braquage », tant qu'il porte son objet
	end
	local root, humanoid = rootOf(player)
	if root == nil then
		return "pas de personnage vivant"
	end
	local bounds = store.Bounds
	if bounds == nil and not store.Event then -- vague 42 : un rayon d'événement n'a pas de volume, la distance suffit
		return "magasin sans volume Bounds"
	end
	local pad = if lenient then reachPad(player, humanoid) else 0
	if bounds and distanceTo(bounds, root.Position) > pad then
		return "hors du volume Bounds"
	end
	local distance = (root.Position - slot.Attachment.WorldPosition).Magnitude
	if distance > Balance.Heist.GrabMaxDistance + pad then
		return `trop loin ({math.round(distance * 10) / 10} studs)`
	end
	return nil
end

-- Raison du refus d'une prise sur `slot`, ou nil si elle est permise maintenant.
function grabRefusal(player: Player, slot: Slot, lenient: boolean): string?
	local store = slot.Store
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
	return reachRefusal(player, slot, lenient)
end

-- Contenu remis au porteur : `base` (celui du colis), ou celui de l'accroche du tuto
-- s'il est valide. Renvoie la table `base` elle-même quand rien ne change. Vague 32 :
-- appelée à la sortie avec base = { Rarity = rareté de la caisse, ItemId = "" } (contenu pas encore tiré) ;
-- une Rarity imposée seule tire alors un objet de cette rareté (itemId == "").
local function contentFor(player: Player, slot: Slot, base: Content): Content
	local override = contentOverride
	if override == nil then
		return base
	end
	local store = slot.Store
	local drawn: OverrideInfo = {
		StoreId = store.Id,
		SlotId = slot.Id,
		Zone = store.Zone,
		Rarity = base.Rarity,
		ItemId = base.ItemId,
	}
	local ok, result = pcall(override, player, drawn)
	if not ok then
		warn(`[StoreHeistService] accroche SetContentOverride : {result}`)
		return base
	end
	if result == nil then
		return base
	end
	local function invalid(reason: string): Content
		warn(`[StoreHeistService] accroche SetContentOverride pour {player.Name} ignorée : {reason}`)
		return base
	end
	if type(result) ~= "table" then
		return invalid(`elle renvoie un {type(result)}, pas une table`)
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
	if itemId == base.ItemId then
		return base
	end
	log(`accroche du tuto : {player.Name} reçoit un objet {rarity} ({itemId}) au lieu d'un colis {base.Rarity}`)
	-- Jamais de mutation pour le colis du tuto (DEV-131) : un contenu remplacé n'en a aucune.
	local content: Content = { Rarity = rarity, ItemId = itemId, Mutation = nil }
	return content
end

-- Ouverture sur le rayon (L-112 ; voir l'en-tête) -------------------------------------------------

-- Payload NPCItem de l'objet `info` sorti du colis de `slot` (prise sur le rayon, ou portage d'office à la fin de
-- la cinématique, vague 62 : Weight y est recopié).
local function payloadFor(slot: Slot, info: ItemInfo): NPCItemPayload
	local store = slot.Store
	local content = info.Content
	return {
		Kind = "NPCItem",
		ItemId = content.ItemId,
		Rarity = content.Rarity,
		Mutation = content.Mutation,
		Zone = store.Zone,
		StoreId = store.Id,
		SlotId = slot.Id,
		Luck = info.Luck,
		Weight = content.Weight,
	}
end

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
	local payload = payloadFor(slot, info)
	-- Rayon réservé pendant l'appel : une autre prise ne peut pas passer si StartCarry attend.
	slot.Item = nil
	outItems[payload] = { Slot = slot, Info = info }
	local ok, started = pcall(CarryService.StartCarry, player, payload)
	if not ok or started ~= true then
		outItems[payload] = nil
		if not ok then
			warn(`[StoreHeistService] CarryService.StartCarry : {started}`)
		end
		if slot.Item == nil and slot.Box == nil and live(store) then
			slot.Item = item -- rien n'a changé : l'objet reste sur le rayon
		else
			discardItem(item) -- rayon rempli entre-temps : pas de doublon
		end
		refuse(player, slot.Id, "CarryService a refusé le portage")
		return
	end
	discardItem(item)
	-- a114 : son vigile sort à cette prise (GuardService) ; il garde le chrono ; fermé pour lui quand il sort (stepEntries).
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
-- si sa table est vide. Vague 76 : règle déplacée dans ShelfBoxes.ContentWeights (lue aussi par Shared/ItemOdds) ;
-- `zone` (rayons des magasins) : seulement les raretés de cette zone (ShelfBoxes.ZoneOdds).
local function itemRarityWeights(boxRarity: string, luck: number, zone: number?): { [string]: number }?
	local mode = ShelfOpen.LuckBoost
	if (mode ~= "AboveBox" and mode ~= "AboveLowest") or (mode == "AboveBox" and Rarities.ById[boxRarity] == nil) then
		warnOnce(`luckboost.{mode}`, `ShelfOpen.LuckBoost « {mode} » inconnu (ou caisse {boxRarity} inconnue) : la chance ne change pas la rareté de l'objet`)
	end
	return ShelfBoxes.ContentWeights(boxRarity, luck, zone)
end

-- Rareté de l'objet tirée selon itemRarityWeights ; table absente : la rareté de la caisse (avertissement).
-- Vague 42 (a148, L-145 (a)) : `floor` (rayon d'événement) : la rareté de la caisse est un minimum, les raretés
-- en dessous ne sortent jamais ; la chance ne peut que monter. Vague 76 : `zone` : seulement les raretés de cette zone.
local function drawItemRarity(boxRarity: string, luck: number, floor: boolean?, zone: number?): string
	local weights = itemRarityWeights(boxRarity, luck, zone)
	if weights == nil then
		warnOnce(`boxodds.{boxRarity}`, `aucune table ShelfOpen.BoxRarityOdds.{boxRarity} : l'objet est de la rareté de sa caisse`)
		return boxRarity
	end
	local box = Rarities.ById[boxRarity]
	if floor and box then
		local kept: { [string]: number } = {}
		local any = false
		for _, rarity in Rarities.List do
			local weight = weights[rarity.Id]
			if weight and rarity.Order >= box.Order then
				kept[rarity.Id] = weight
				any = true
			end
		end
		if not any then
			return boxRarity
		end
		weights = kept
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
-- Vague 42 (a148) : `zones` (rayon d'événement, ItemZones) : un objet de la rareté pris parmi ceux de toutes
-- ces zones (Items.ByZone, lu dans le catalogue), sinon la règle des magasins (drawItemNear).
local function drawItemIn(zones: { number }, rarityId: string): string?
	if Items.AllZones[rarityId] then
		return nil -- Secret, Divine : toutes zones, drawItemNear s'en charge
	end
	local pool: { string } = {}
	for _, zone in zones do
		local byRarity = Items.ByZone[zone]
		local list: { Items.Item } = (if byRarity then byRarity[rarityId] else nil) or {}
		for _, item in list do
			table.insert(pool, item.Id)
		end
	end
	return if #pool > 0 then pool[random:NextInteger(1, #pool)] else nil
end

-- `floor` : la rareté de la caisse est un minimum (drawItemRarity) ; `sizeOdds` ({ [Id de taille] = poids }) :
-- la taille est tirée là, à la place de celle de Mutations.Roll (l'effet reste celui de Mutations.Roll).
local function drawShelfContent(
	boxRarity: string,
	zone: number,
	luck: number,
	zones: { number }?,
	floor: boolean?,
	sizeOdds: { [string]: number }?,
	zonesOnly: boolean? -- vague 56 (a181) : rareté absente de `zones` (hors Secret, Divine) : la rareté en dessous
): (Content?, string)
	-- Vague 76 (Cantin et Clément, 19/11) : sur un rayon de magasin (pas d'événement, `floor` absent), l'objet n'est
	-- jamais d'une rareté absente de la zone (ShelfBoxes.ContentWeights limitée à `zone`).
	local wanted = drawItemRarity(boxRarity, luck, floor, if floor then nil else zone)
	local info = Rarities.ById[wanted]
	if info == nil then
		return nil, wanted
	end
	for order = info.Order, 1, -1 do
		local rarityId: string = Rarities.List[order].Id
		local itemId = (if zones then drawItemIn(zones, rarityId) else nil)
			or (if zonesOnly and not Items.AllZones[rarityId] then nil else drawItemNear(zone, rarityId))
		if itemId then
			if order < info.Order and not zonesOnly then
				warnOnce(`nowhere.{wanted}`, `aucun objet {wanted} tirable dans aucune zone (Config/Items) : un objet {rarityId} sort à la place`)
			end
			local mutation = drawMutation(itemId)
			if sizeOdds then
				local total, size = 0, nil
				for _, entry in Mutations.Sizes do
					total += math.max(sizeOdds[entry.Id] or 0, 0)
				end
				local roll = random:NextNumber() * total
				for _, entry in Mutations.Sizes do
					local weight = math.max(sizeOdds[entry.Id] or 0, 0)
					if weight > 0 then
						size = entry.Id
						if roll < weight then
							break
						end
						roll -= weight
					end
				end
				mutation = Mutations.Sanitize({ Size = size, Effect = if mutation then mutation.Effect else nil })
			end
			local content: Content = { Rarity = rarityId, ItemId = itemId, Mutation = mutation }
			if sizeOdds and Features.SingleBoxReveal == true then
				-- Vague 62 (a203) : la taille garantie devient un poids tiré dans son palier (ItemWeight.RollForSize ;
				-- sans taille, tout le poids). Absent ou en erreur : pas de poids, la taille d'avant.
				local roller = (ItemWeight :: any).RollForSize
				local ok, kg = pcall(function(): any
					return roller(random, luck, if mutation then mutation.Size else nil)
				end)
				if ok and type(kg) == "number" and kg > 0 and kg < math.huge then
					content.Weight = kg
				elseif type(roller) == "function" then
					warnOnce("weight.rollForSize", `ItemWeight.RollForSize a échoué ou renvoyé {kg} : pas de poids`)
				end
			end
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
	if opening == nil or slot.Box ~= box or not live(store) then
		return
	end
	box.Opening = nil
	slot.Box = nil
	local opener = Players:GetPlayerByUserId(opening.ByUserId)
	-- Accroche du tuto d'abord, sans tirage : un contenu imposé est l'objet sorti tel quel (voir l'en-tête).
	local pending: Content = { Rarity = box.Rarity, ItemId = "", Mutation = nil }
	local imposed: Content? = nil
	if opener and not store.Event then -- vague 42 : pas d'accroche du tuto sur un rayon d'événement
		local given = contentFor(opener, slot, pending)
		if given ~= pending then
			imposed = given
		end
	end
	local drawnRarity = box.Rarity
	local final: Content? = imposed
	if final == nil then
		-- Vague 56 (a181, L-166 Q5) : NextZoneChance : un objet de la zone suivante avec cette probabilité, sinon de la zone.
		local nextChance, zones = store.NextZoneChance, store.ItemZones
		if nextChance then
			zones = if random:NextNumber() < nextChance and Zones[store.Zone + 1] then { store.Zone + 1 } else { store.Zone }
		end
		final, drawnRarity = drawShelfContent(box.Rarity, store.Zone, luck, zones, store.Event, store.SizeOdds, nextChance ~= nil)
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
		BoxRarity = box.Rarity,
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
	local luck = drawLuck() * (Workspace:GetAttribute("LiveEventShelfLuck") :: number? or 1) -- a167 : chance d'un événement live (EventService)
	local serverLuck = Workspace:GetAttribute("ServerLuck") -- a247 : chance du serveur achetée en Robux (MonetizationService)
	luck *= if type(serverLuck) == "number" and serverLuck >= 1 and serverLuck < math.huge then serverLuck else 1
	local forced = luckOverride
	if forced and not store.Event then -- vague 42 : pas d'accroche du tuto sur un rayon d'événement
		-- Accroche du tuto (a107, SetLuckOverride) : une chance finie ≥ 1, sinon le tirage normal.
		-- Vague 32 : le contenu n'est pas encore tiré ; Rarity = rareté de la caisse, ItemId = "".
		local drawn: OverrideInfo = { StoreId = store.Id, SlotId = slot.Id, Zone = store.Zone, Rarity = box.Rarity, ItemId = "" }
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
	log(`{player.Name} ouvre la caisse {box.Rarity} {slot.Name} de {store.Id} : chance ×{luck}, sortie dans {math.round(delay * 10) / 10} s`)
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
		if box and opening and not opening.Cinematic then -- vague 62 : une cinématique n'a pas de montée à couper
			local reached = ShelfOpenState.luckAt(opening.OpenAt, opening.Luck, now)
			box.Model:SetAttribute(ShelfOpenState.RevealAtAttribute, now)
			log(`{slot.Id} : police appelée pendant la montée, la chance s'arrête à ×{reached} (tirée : ×{opening.Luck})`)
			reveal(slot, box, reached)
		end
	end
end

-- Raison du refus d'une ouverture du colis de `slot`, ou nil si elle est permise maintenant.
local function openRefusal(player: Player, slot: Slot, lenient: boolean): string?
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
	return reachRefusal(player, slot, lenient)
end

-- Cinématique d'ouverture (vague 62, Features.SingleBoxReveal ; voir l'en-tête) ------------------------------

-- Le nouveau déroulé s'applique-t-il à ce magasin ? Jamais sur un rayon d'événement (camion, Fortune Tower) :
-- ils gardent l'ouverture d'avant.
local function singleBoxReveal(store: Store): boolean
	return Features.SingleBoxReveal == true and not store.Event
end

-- Appels protégés de Shared/ItemWeight (a203) : une valeur absurde ou une erreur donne le repli (10 kg, taille 1,
-- aucune mutation de taille, classe Small), avec un avertissement unique.
local function finiteOr(value: any, fallback: number, minimum: number): number
	if type(value) == "number" and value == value and value >= minimum and value < math.huge then
		return value
	end
	return fallback
end

local function rollWeight(luck: number): number
	local ok, kg = pcall(ItemWeight.Roll, random, luck)
	if not ok or finiteOr(kg, -1, 0) < 0 then
		warnOnce("weight.roll", `ItemWeight.Roll a échoué ou renvoyé {kg} : poids de repli {ShelfOpen.Reveal.TutorialWeight} kg`)
		return ShelfOpen.Reveal.TutorialWeight
	end
	return kg
end

local function sizeMutationFor(kg: number): string?
	local ok, size = pcall(ItemWeight.SizeMutationFor, kg)
	return if ok and type(size) == "string" then size else nil
end

local function scaleFor(kg: number): number
	local ok, scale = pcall(ItemWeight.ScaleFor, kg)
	return finiteOr(if ok then scale else nil, 1, 1e-3)
end

local function sizeClassFor(kg: number, freeHeight: number, modelHeight: number): string
	local ok, class = pcall(ItemWeight.SizeClassFor, kg, freeHeight, modelHeight)
	if ok and (class == "Small" or class == "Large" or class == "Colossal") then
		return class
	end
	warnOnce("weight.class", `ItemWeight.SizeClassFor a échoué ou renvoyé {class} : classe Small`)
	return "Small"
end

-- Hauteur libre au-dessus du rayon `slot`, jusqu'au haut du volume Bounds (le plafond du magasin).
local function freeHeightAbove(slot: Slot): number
	local bounds = slot.Store.Bounds
	if bounds == nil then
		return V0_FREE_HEIGHT
	end
	local top = bounds.Position.Y + extentAlong(bounds.CFrame, bounds.Size, Vector3.yAxis) / 2
	return math.max(top - slot.Attachment.WorldPosition.Y, 0)
end

-- Hauteur du modèle de l'objet à la taille 1 : ITM_<ItemId> de Clément, sinon le bloc V0.
local function modelHeightOf(itemId: string): number
	local def = Items.ById[itemId]
	local template = if def then boxTemplate(def.Asset) else nil
	if template and template:IsA("BasePart") then
		return template.Size.Y
	elseif template and template:IsA("Model") then
		local ok, size = pcall(function(): Vector3
			return (template :: Model):GetExtentsSize()
		end)
		if ok and typeof(size) == "Vector3" and size.Y > 0 then
			return size.Y
		end
	end
	return V0_ITEM_SIZE.Y
end

-- Plafond du magasin cassé (attribut CeilingBroken, visuel côté client) tant qu'une cinématique Large ou
-- Colossal y joue, puis réparé Reveal.CeilingRepairSeconds s après la fin de la dernière.
local function breakCeiling(store: Store)
	local entry = ceilings[store]
	if entry == nil then
		entry = { Count = 0, Token = 0 }
		ceilings[store] = entry
	end
	local ceiling = entry :: Ceiling
	ceiling.Count += 1
	ceiling.Token += 1 -- une réparation déjà programmée ne fait plus rien
	store.Model:SetAttribute(ShelfOpenState.CeilingAttribute, true)
end

local function repairCeilingLater(store: Store)
	local entry = ceilings[store]
	if entry == nil then
		return
	end
	entry.Count = math.max(entry.Count - 1, 0)
	if entry.Count > 0 then
		return
	end
	entry.Token += 1
	local token = entry.Token
	task.delay(ShelfOpen.Reveal.CeilingRepairSeconds, function()
		if ceilings[store] == entry and entry.Token == token and entry.Count == 0 then
			ceilings[store] = nil
			store.Model:SetAttribute(ShelfOpenState.CeilingAttribute, false)
			log(`{store.Id} : plafond réparé`)
		end
	end)
end

local function setProtected(player: Player, on: boolean)
	pcall(function()
		player:SetAttribute(ShelfOpenState.ProtectedAttribute, if on then true else nil)
	end)
	local setter = setSpeedModifier
	if setter then
		local ok, err = pcall(function()
			setter(player, REVEAL_SPEED_KEY, if on then 0 else nil)
		end)
		if not ok then
			warn(`[StoreHeistService] StatsService.SetSpeedModifier({player.Name}, {REVEAL_SPEED_KEY}) : {err}`)
		end
	end
end

-- Remote de la cinématique (Net/Definitions) ; erreur avalée et signalée : jamais de cinématique bloquée.
local function fireReveal(name: string, ...: any)
	local ok, err = pcall(function(...: any)
		(Net.Server :: any)[name]:FireAll(...)
	end, ...)
	if not ok then
		warnOnce(`fire.{name}`, `Net.Server.{name}:FireAll : {err}`)
	end
end

-- Chrono du braquage repris pour l'ouvreur à la fin de sa cinématique, s'il n'a pas pu porter son objet
-- (repli) : celui qu'il lui restait au début, ou le vigile de fin de chrono tout de suite s'il était fini.
-- Avec son objet sur la tête, rien : le vigile lié à l'objet le poursuit déjà (GuardService, a114).
local function resumeChrono(session: Reveal, carried: boolean)
	local player = session.Player
	local store = session.Slot.Store
	if carried or player.Parent ~= Players or not live(store) or not store.Open or not store.Entered[player] then
		return
	end
	local function chaseIfInside()
		local root = rootOf(player)
		local bounds = store.Bounds
		local chase = chaseIntruder
		if chase and root and (bounds == nil or inside(bounds, root.Position)) and not isCarrying(player) then
			local ok, err = pcall(chase, player, store.Model)
			if not ok then
				warn(`[StoreHeistService] GuardService.ChaseIntruder({player.Name}) : {err}`)
			end
		end
	end
	local left = session.ChronoLeft
	if left == nil or left <= 0 then
		if store.ChronoOver then
			chaseIfInside()
		end
		return
	end
	local endsAt = Workspace:GetServerTimeNow() + left
	local paused: PausedChrono = { Store = store, EndsAt = endsAt, Token = store.Token }
	pausedChronos[player] = paused
	store.Viewers[player] = true
	Net.Server.HeistTimer:Fire(player, store.Id, endsAt)
	task.delay(left, function()
		if pausedChronos[player] ~= paused then
			return
		end
		pausedChronos[player] = nil
		if store.Token ~= paused.Token or not live(store) then
			return
		end
		hideTimer(store, player)
		if store.ChronoOver and store.Entered[player] then
			chaseIfInside()
		end
	end)
end

-- Fin de la cinématique `session` (RevealDone de l'ouvreur, plafond de temps, sortie ou mort), une seule fois :
-- protection levée, RevealEnded à tous, colis retiré, objet porté d'office (CarryService, le vigile lié part
-- à cette prise comme à une prise sur le rayon) ; sinon (mort, parti, portage refusé) posé sur le rayon,
-- réservé ShelfOpen.ReserveTime s à l'ouvreur s'il est encore là. Le chrono reprend.
local function finishReveal(session: Reveal, why: string, gone: boolean?)
	if session.Ended then
		return
	end
	session.Ended = true
	local player = session.Player
	if reveals[player] == session then
		reveals[player] = nil
	end
	revealsById[session.Id] = nil
	setProtected(player, false)
	fireReveal("RevealEnded", session.Id)
	local slot, box = session.Slot, session.Box
	local store = slot.Store
	if session.Ceiling then
		repairCeilingLater(store)
	end
	local seconds = math.round((os.clock() - session.StartedAt) * 10) / 10
	if slot.Box ~= box or box.Opening ~= session.Opening or not live(store) then
		log(`cinématique {session.Id} de {player.Name} finie ({why}, {seconds} s) : colis retiré entre-temps, aucun objet`)
		if live(store) and openingCount(store) == 0 then
			calmWitnesses(store)
		end
		return
	end
	box.Opening = nil
	slot.Box = nil
	discard(box)
	local info = session.Info
	local present = not gone and player.Parent == Players -- PlayerRemoving : encore dans Players
	local carried = false
	if present and rootOf(player) ~= nil then
		local payload = payloadFor(slot, info)
		outItems[payload] = { Slot = slot, Info = info }
		local ok, started = pcall(CarryService.StartCarry, player, payload)
		if ok and started == true then
			carried = true
		else
			outItems[payload] = nil
			if not ok then
				warn(`[StoreHeistService] CarryService.StartCarry : {started}`)
			end
		end
	end
	if not carried then
		local reserve = if present then ShelfOpen.ReserveTime else 0
		info.ReservedUntil = os.clock() + reserve
		info.ReservedUntilServer = Workspace:GetServerTimeNow() + reserve
		placeItem(slot, info, nil)
	end
	if openingCount(store) == 0 then
		calmWitnesses(store)
	end
	local content = info.Content
	local mutation = Mutations.Label(content.Mutation)
	local where = if carried then "sur sa tête" elseif present then `posé sur {slot.Name}, réservé {ShelfOpen.ReserveTime} s` else `posé sur {slot.Name}`
	log(`cinématique {session.Id} de {player.Name} finie ({why}, {seconds} s) : {content.Rarity} ({content.ItemId}), {content.Weight} kg{if mutation then ", " .. mutation else ""}, {where}`)
	announce(if present then player else nil, content)
	resumeChrono(session, carried or not present) -- parti : rien à reprendre
end

-- Lance l'ouverture du colis `box` de `slot` par `player` dans le nouveau déroulé : chance de la boîte (seule
-- source, Config/ShelfOpen.Reveal), contenu tiré tout de suite (accroche du tuto, sinon rareté par la caisse et
-- la chance, objet, mutation d'effet, poids, mutation de taille par le poids), puis la cinématique.
local function startReveal(player: Player, slot: Slot, box: ShelfBox)
	local store = slot.Store
	local config = ShelfOpen.Reveal
	-- La chance liée au temps (montée, police) n'existe pas ici ; le bonus des événements est coupé par V0.
	local luck = if config.TableLuck then drawLuck() else 1
	if config.EventLuck then
		luck *= finiteOr(Workspace:GetAttribute("LiveEventShelfLuck"), 1, 1e-3)
	end
	luck *= finiteOr(Workspace:GetAttribute("ServerLuck"), 1, 1) -- a247 : chance du serveur achetée en Robux (MonetizationService), toujours comptée
	local forced = luckOverride
	if forced then
		local drawn: OverrideInfo = { StoreId = store.Id, SlotId = slot.Id, Zone = store.Zone, Rarity = box.Rarity, ItemId = "" }
		local ok, value = pcall(forced, player, drawn)
		if ok and type(value) == "number" and value >= 1 and value < math.huge then
			luck = value
		elseif not ok then
			warn(`[StoreHeistService] accroche SetLuckOverride : {value}`)
		end
	end
	local pending: Content = { Rarity = box.Rarity, ItemId = "", Mutation = nil }
	local given = contentFor(player, slot, pending)
	local imposed = given ~= pending
	local content: Content? = nil
	local drawnRarity = box.Rarity
	if imposed then
		-- Contenu imposé par le tuto, sans tirage : ni mutation, ni poids tiré.
		content = { Rarity = given.Rarity, ItemId = given.ItemId, Mutation = nil, Weight = config.TutorialWeight }
	else
		local drawn, wanted = drawShelfContent(box.Rarity, store.Zone, luck)
		drawnRarity = wanted
		if drawn then
			local weight = rollWeight(luck)
			local effect = if drawn.Mutation then drawn.Mutation.Effect else nil
			content = {
				Rarity = drawn.Rarity,
				ItemId = drawn.ItemId,
				-- Le poids remplace la mutation de taille tirée (Cantin) ; la mutation d'effet reste un tirage à part.
				Mutation = Mutations.Sanitize({ Size = sizeMutationFor(weight), Effect = effect }),
				Weight = weight,
			}
		end
	end
	if content == nil then
		-- Garde-fou (Config incohérente), comme reveal : rien ne peut sortir de cette caisse, le rayon reste vide.
		warnOnce(`reveal.{box.Rarity}.{store.Zone}`, `aucun objet ne peut sortir d'une caisse {box.Rarity} en zone {store.Zone} (Config : ShelfOpen.BoxRarityOdds, Items) : rayon laissé vide`)
		slot.Box = nil
		discard(box)
		return
	end
	local final = content :: Content
	local weight = final.Weight or config.TutorialWeight
	local scale = scaleFor(weight)
	local sizeClass = sizeClassFor(weight, freeHeightAbove(slot), modelHeightOf(final.ItemId))
	local openAt = Workspace:GetServerTimeNow()
	local opening: Opening = { ByUserId = player.UserId, Luck = luck, OpenAt = openAt, Cinematic = true }
	box.Opening = opening
	-- Aucun attribut ShelfOpen* sur le colis (a204) : l'ouverture d'avant ne joue pas chez le client par-dessus la
	-- cinématique ; l'état est sur le serveur seul (box.Opening, Cinematic).
	revealCount += 1
	local id = `R{revealCount}`
	local session: Reveal = {
		Id = id,
		Player = player,
		Slot = slot,
		Box = box,
		Opening = opening,
		Info = {
			BoxRarity = box.Rarity,
			Content = final,
			Luck = luck,
			OpenerId = player.UserId,
			ReservedUntil = 0, -- posé à la fin s'il reste sur le rayon (finishReveal)
			ReservedUntilServer = 0,
		},
		SizeClass = sizeClass,
		StartedAt = os.clock(),
		ChronoLeft = if store.Open and not store.ChronoOver then math.max(store.EndsAt - openAt, 0) else nil,
		Ceiling = sizeClass == "Large" or sizeClass == "Colossal",
		Ended = false,
	}
	reveals[player] = session
	revealsById[id] = session
	holds[player] = nil
	openHolds[player] = nil
	setProtected(player, true)
	hideTimer(store, player)
	if session.Ceiling then
		breakCeiling(store)
	end
	local effect = if final.Mutation and final.Mutation.Effect then final.Mutation.Effect else ""
	-- Bornes du remote (Net/Definitions : poids 1 000 000 kg, taille 100 au plus).
	-- Vague 73 (a251, L-236 ; Config/Unbox.New) : plan de la nouvelle ouverture (actions du perso, rareté montrée après
	-- chacune, cote finale), tiré ici une fois l'objet tiré, envoyé à tous ; le plafond de la phase suit sa durée. Coupé,
	-- module absent ou plan impossible : la cinématique et le plafond d'avant.
	local plan: string? = nil
	local maxSeconds: number = config.RevealMaxSeconds[sizeClass] or config.DefaultMaxSeconds
	local newUnbox: any = (Unbox :: any).New
	local planModule: any = Shared:FindFirstChild("UnboxPlan")
	if newUnbox and newUnbox.Enabled == true and planModule then
		local ok, text, seconds = pcall(function(): (any, any)
			local UnboxPlan = require(planModule) :: any
			-- Vague 74 (a257, L-253) : améliorations du colis tirées à part de l'objet (aucune pour un contenu imposé),
			-- depuis la rareté du colis ; le nombre d'actions et le plafond suivent le plan tiré.
			local zoneRarities = ShelfBoxes.ZoneRarities[store.Zone]
			local upgrades = if imposed then 0 else UnboxPlan.upgrades(box.Rarity, luck, function(): number
				return random:NextNumber()
			end, if zoneRarities then zoneRarities[#zoneRarities] else nil) -- vague 76 : jamais au-dessus de la zone
			-- Vague 75 (a259, L-262 point 1), vague 76 : la cote finale est 1 / la vraie chance d'avoir cet objet, avec sa
			-- mutation et sa taille, sur un emplacement de rayon de sa zone (Shared/ItemOdds, arrondi Formulas.UnboxOdds),
			-- sans lien avec la caisse trouvée. Contenu imposé : la plage.
			local odds: number? = nil
			if not imposed and newUnbox.RealOdds ~= false then
				local ItemOdds = require(Shared.ItemOdds) :: any
				local chance = ItemOdds.Chance(final.ItemId, final.Mutation)
				odds = if chance then Formulas.UnboxOdds(chance) else nil
			end
			local drawn = UnboxPlan.draw(final.Rarity, function(n: number): number
				return 1 + math.floor(random:NextNumber() * n)
			end, box.Rarity, upgrades, odds)
			local parsed = UnboxPlan.parse(drawn)
			return drawn, UnboxPlan.serverMaxSeconds(final.Rarity, sizeClass, if parsed then #parsed.Steps else nil)
		end)
		if ok and type(text) == "string" and type(seconds) == "number" and seconds > 0 and seconds < math.huge then
			plan = text
			maxSeconds = math.max(maxSeconds, seconds)
			-- L'outil de l'action va dans la main droite de l'ouvreur : son outil à lui est rangé (comme au portage,
			-- CarryService.StartCarry, qui suit de toute façon à la fin).
			pcall(function()
				local character = player.Character
				local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
				if humanoid then
					humanoid:UnequipTools()
				end
			end)
		elseif not ok then
			warnOnce("unbox.plan", `plan de la nouvelle ouverture impossible ({text}) : cinématique d'avant`)
		end
	end
	fireReveal("RevealStarted", player, store.Id, slot.Name, final.ItemId, final.Rarity, effect, math.min(weight, 1_000_000), math.min(scale, 100), sizeClass, id, plan)
	task.delay(maxSeconds, function()
		finishReveal(session, "plafond de temps")
	end)
	local how = if imposed then " (contenu imposé par le tuto, sans tirage)"
		elseif drawnRarity ~= final.Rarity then ` (tirée : {drawnRarity}, aucun objet nulle part)`
		else ""
	local mutation = Mutations.Label(final.Mutation)
	log(`{player.Name} ouvre la caisse {box.Rarity} {slot.Name} de {store.Id} : cinématique {id}, chance ×{luck}, objet {final.Rarity} ({final.ItemId}){how}, {weight} kg, taille ×{scale}, classe {sizeClass}{if mutation then ", " .. mutation else ""}, {maxSeconds} s au plus{if plan then `, plan {plan}` else ""}`)
end

-- RevealDone(revealId) : l'ouvreur a fini de voir sa cinématique. Seule la sienne, en cours ; sinon ignoré.
local function onRevealDone(player: Player, revealId: string)
	local session = revealsById[revealId]
	if session == nil or session.Player ~= player or session.Ended then
		refuse(player, revealId, "cinématique inconnue, d'un autre joueur ou déjà finie", "RevealDone")
		return
	end
	finishReveal(session, "RevealDone")
end

-- Tick : cinématique d'un joueur parti ou mort, ou dont le colis a disparu (magasin retiré) : fin propre.
local function stepReveals()
	for player, session in table.clone(reveals) do
		local slot = session.Slot
		if player.Parent ~= Players then
			finishReveal(session, "joueur parti")
		elseif rootOf(player) == nil then
			finishReveal(session, "joueur mort")
		elseif slot.Box ~= session.Box or not live(slot.Store) then
			finishReveal(session, "colis retiré")
		end
	end
end

-- OpenShelfBox(slotId, phase?) : début, fin ou annulation du maintien ; sans phase, premier appel = début,
-- second = fin (voir « Maintien » dans l'en-tête).
local function onOpenShelfBox(player: Player, slotId: string, phase: string?)
	local slot = slotsById[slotId]
	if slot == nil then
		refuse(player, slotId, "emplacement inconnu", "OpenShelfBox")
		return
	end
	if phase ~= nil and not HOLD_PHASES[phase] then
		refuse(player, slotId, `étape de maintien inconnue « {phase} »`, "OpenShelfBox")
		return
	end
	local hold = openHolds[player]
	if phase == "Cancel" then -- a265 : relâché avant la fin, maintien vidé tout de suite
		if hold and hold.Slot == slot then
			openHolds[player] = nil
		end
		return
	end
	if not AntiCheatService.Verify(player) then
		refuse(player, slotId, "déplacement sanctionné par l'anti-triche (audit 9.8)", "OpenShelfBox")
		return
	end
	-- Début du maintien (pas de maintien en cours sur ce colis, colis à GrabTime > 0) : portée souple ;
	-- fin du maintien ou colis sans maintien : stricte (voir « Portée » dans l'en-tête).
	local current = slot.Box
	local matching = hold ~= nil and hold.Slot == slot and hold.Target == current
	local starting = current ~= nil
		and (if phase == nil then not matching else phase == "Begin")
		and grabTime(current.Rarity) > 0
	local reason = openRefusal(player, slot, starting)
	if reason then
		if hold and hold.Slot == slot then
			openHolds[player] = nil
		end
		refuse(player, slotId, reason, "OpenShelfBox")
		return
	end
	local box = slot.Box :: ShelfBox -- openRefusal a vérifié qu'il est posé et fermé
	local required = grabTime(box.Rarity)
	local now = os.clock()
	-- a265 : un "Begin" n'est jamais une fin, il rouvre le maintien à zéro.
	local finishing = phase ~= "Begin" and hold ~= nil and hold.Slot == slot and hold.Target == box
	if not finishing and required > 0 then
		if phase == "End" then
			-- a265 : fin sans début ouvert sur ce colis (relâché, puis maintien vidé ou expiré) : rien n'est lancé.
			refuse(player, slotId, "fin de maintien sans début ouvert sur ce colis", "OpenShelfBox")
			return
		end
		openHolds[player] = { Slot = slot, Target = box, BoxRarity = box.Rarity, StartedAt = now } -- début du maintien
		return
	end
	if finishing then
		local elapsed = now - (hold :: Hold).StartedAt
		if elapsed + GRAB_TIME_TOLERANCE < required then
			-- a263 (vague 77) : maintien vidé, sinon l'appui suivant passait pour une fin et lançait l'ouverture.
			openHolds[player] = nil
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
	if api and not slot.Store.Event then -- vague 42 : pas de témoins sur un rayon d'événement
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
	if singleBoxReveal(slot.Store) then
		startReveal(player, slot, box) -- vague 62 : tout est tiré maintenant, puis la cinématique
	else
		startOpening(player, slot, box)
	end
end

-- GrabItem(slotId, phase?) : début, fin ou annulation du maintien ; sans phase, premier appel = début,
-- second = fin (voir « Maintien » dans l'en-tête).
local function onGrabItem(player: Player, slotId: string, phase: string?)
	local slot = slotsById[slotId]
	if slot == nil then
		refuse(player, slotId, "emplacement inconnu")
		return
	end
	if phase ~= nil and not HOLD_PHASES[phase] then
		refuse(player, slotId, `étape de maintien inconnue « {phase} »`)
		return
	end
	local hold = holds[player]
	if phase == "Cancel" then -- a265 : relâché avant la fin, maintien vidé tout de suite
		if hold and hold.Slot == slot then
			holds[player] = nil
		end
		return
	end
	if not AntiCheatService.Verify(player) then
		refuse(player, slotId, "déplacement sanctionné par l'anti-triche (audit 9.8)")
		return
	end
	-- Début du maintien : portée souple ; fin du maintien ou prise sans maintien : stricte (« Portée »).
	-- Vague 50 (a158) : le colis fermé ne se porte plus ; seul l'objet sorti de son colis se prend (L-112).
	local current: any, currentRarity: string? = nil, nil
	local shown = slot.Item
	if shown then
		current, currentRarity = shown, shown.Info.BoxRarity
	end
	local matching = hold ~= nil and hold.Slot == slot and hold.Target == current
	local starting = current ~= nil
		and currentRarity ~= nil
		and (if phase == nil then not matching else phase == "Begin")
		and grabTime(currentRarity) > 0
	local reason = grabRefusal(player, slot, starting)
	if reason then
		if hold and hold.Slot == slot then
			holds[player] = nil
		end
		refuse(player, slotId, reason)
		return
	end
	-- grabRefusal a vérifié qu'il est posé : l'objet sorti (L-112).
	local give = grantItem
	local item = slot.Item :: ShelfItem
	local target: any, boxRarity: string = item, item.Info.BoxRarity
	local required = grabTime(boxRarity)
	local now = os.clock()
	-- a265 : un "Begin" n'est jamais une fin, il rouvre le maintien à zéro (plus bas).
	if phase ~= "Begin" and hold and hold.Slot == slot and hold.Target == target then
		local elapsed = now - hold.StartedAt
		if elapsed + GRAB_TIME_TOLERANCE >= required then
			holds[player] = nil
			give(player, slot)
		else
			-- a263 (vague 77) : maintien vidé, sinon l'appui suivant passait pour une fin et donnait l'objet.
			holds[player] = nil
			refuse(player, slotId, `maintien trop court ({math.round(elapsed * 100) / 100} s sur {required} s)`)
		end
		return
	end
	if required <= 0 then
		holds[player] = nil
		give(player, slot)
		return
	end
	if phase == "End" then
		-- a265 : fin sans début ouvert sur cet objet (relâché, puis maintien vidé ou expiré) : rien n'est donné.
		refuse(player, slotId, "fin de maintien sans début ouvert sur cet objet")
		return
	end
	holds[player] = { Slot = slot, Target = target, BoxRarity = boxRarity, StartedAt = now }
end

-- Retour d'un colis ------------------------------------------------------------------------------

-- L-112 : remet sur son emplacement l'objet sorti de ce payload NPCItem, en vol depuis `from` s'il est
-- donné. Sa réservation n'est pas relancée. false s'il est inconnu, déjà revenu, d'avant un
-- remplissage de son magasin, ou si son emplacement est occupé (il disparaît alors).
-- a174 (Cantin, 2026-11-15) : `anySlot` (porteur attrapé, « Caught » : dans le magasin de l'objet ou à la 3e
-- capture de cet objet) : emplacement occupé, il va sur un autre rayon libre du même magasin (ni colis, ni
-- objet, ni objet sorti qui doit y revenir), sinon il disparaît. Magasin retiré (rayon d'événement fini) ou
-- rempli depuis (nuit) : il disparaît, comme avant (nouveau tirage, pas de doublon).
local function returnItem(payload: any, from: Vector3?, anySlot: boolean?): boolean
	local out = outItems[payload]
	if out == nil then
		return false
	end
	outItems[payload] = nil
	local slot = out.Slot
	if not live(slot.Store) then
		return false
	end
	if slot.Box ~= nil or slot.Item ~= nil then
		if not anySlot then
			return false
		end
		local awaited: { [Slot]: boolean } = {}
		for _, other in outItems do
			awaited[other.Slot] = true
		end
		local free: Slot? = nil
		for _, candidate in slot.Store.Slots do
			if candidate.Box == nil and candidate.Item == nil and not awaited[candidate] then
				free = candidate
				break
			end
		end
		if free == nil then
			return false
		end
		log(`objet {payload.ItemId} : {slot.Id} occupé, il revient sur {free.Id}`)
		slot = free
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
			-- a252 (L-244) : l'objet passé par la main du vigile (Guard/CatchPickUp) revole depuis là (payload.ReturnFrom).
			local from = if typeof(payload.ReturnFrom) == "Vector3" then payload.ReturnFrom else carrierPosition(player)
			payload.ReturnFrom = nil
			local back = returnItem(payload, from, reason == "Caught") -- a174 : autre rayon libre si le sien est pris
			log(`objet {payload.ItemId} de {player.Name} ({reason}) : {if back then "revient" else "ne revient pas"} sur {payload.SlotId}`)
		end
	end
end

-- Objet tombé au sol (coup de batte, capture, lâcher), jamais ramassé (6.2 : Bat.DroppedLifetime s) : il
-- revole vers son emplacement depuis l'endroit où il était.
local function onDropExpired(dropId: string, payload: any, position: Vector3?)
	if type(payload) == "table" and payload.Kind == "NPCItem" then
		-- L-112 : objet resté au sol sans preneur, il revole vers son rayon (ou disparaît, voir returnItem).
		local start = if typeof(position) == "Vector3" then position + Vector3.new(0, DROP_RETURN_LIFT, 0) else nil
		local back = returnItem(payload, start)
		log(`objet {payload.ItemId} {dropId} resté au sol : {if back then "revient" else "ne revient pas"} sur {payload.SlotId}`)
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
	local boxTotal = Balance.Heist.ShelfSlots -- vague 76 : un colis par emplacement
	if #store.Slots < boxTotal then
		warn(
			`[StoreHeistService] {model:GetFullName()} : {#store.Slots} rayon(s) pour {boxTotal} colis, {boxTotal - #store.Slots} colis en moins`
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
	stepReveals() -- vague 62
	for player, hold in holds do
		local slot = hold.Slot
		local current: any = slot.Item
		if
			current ~= hold.Target
			or now - hold.StartedAt > grabTime(hold.BoxRarity) + HOLD_EXPIRY
			or grabRefusal(player, slot, true) ~= nil
		then
			holds[player] = nil
		end
	end
	for player, hold in openHolds do
		if
			hold.Slot.Box ~= hold.Target
			or now - hold.StartedAt > grabTime(hold.BoxRarity) + HOLD_EXPIRY
			or openRefusal(player, hold.Slot, true) ~= nil
		then
			openHolds[player] = nil
		end
	end
	for _, store in stores do
		stepLocks(store)
		if store.Open then
			-- L-118 : fermé quand le chrono est fini et que plus personne n'est dedans (ouvertures finies).
			stepEntries(store)
			if not store.ChronoOver then
				updateViewers(store)
			elseif not anyoneInside(store) and not storeBusy(store) then
				closeStore(store)
			end
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
	openStore(store, info.Breaker)
end

-- Un seul braquage à la fois (voir l'en-tête) : le magasin du braquage en cours de `player` qui
-- n'est pas `target`, ou nil (pas de braquage en cours, ou seulement dans `target`).
local function otherHeist(player: Player, target: Store): string?
	for _, store in stores do
		-- L-118 : sorti du magasin (fermé pour lui), son braquage là-bas est fini, sauf l'objet qu'il porte.
		if store ~= target and store.Open and store.Breaker == player and not store.Locked[player] then
			return store.Id
		end
	end
	local payload = CarryService.GetPayload(player)
	if type(payload) == "table" and payload.Kind == "NPCItem" and payload.StoreId ~= target.Id then
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

-- Rayons d'événement (vague 42, a148, demande de Cantin du 2026-11-14) -------------------------------------
-- Les colis du coffre de la Fortune Tower et du camion s'ouvrent sur place, exactement comme sur un rayon :
-- même code (OpenShelfBox, chance, sortie, GrabItem, portage NPCItem). Un rayon d'événement est un faux
-- magasin hors de stores (aucune boucle des magasins ne le voit : ni chrono, ni rideau, ni remplissage de
-- nuit, ni fermeture pour le voleur), toujours ouvert, sans Bounds (reachRefusal : la distance seule, souple
-- au début du maintien et stricte à la fin), sans témoins, sans accroches du tuto ; StoreId « Truck_… » :
-- GuardService n'envoie aucun vigile, TelemetryService le compte à part. Modèle posé dans le Workspace :
-- EventShelf_<Id> (tag EventShelf, attributs StoreId et HeistOpen, lus par HeistController), une pièce
-- invisible Anchor avec les ShelfSlot_NN, et le dossier ShelfBoxes. Retiré en entier au bout de Lifetime s
-- (colis fermés, ouvertures en cours et objets sortis non pris), ou par RemoveEventShelf.

local EVENT_TAG = "EventShelf" -- posé par le code, lu par HeistController
local EVENT_NAME_PREFIX = "EventShelf_"

export type EventSpot = {
	CFrame: CFrame, -- pivot du colis (en bas au centre), posé sur le sol
	Tier: string?, -- vague 76 : ignoré (le temps de maintien suit la rareté du colis, ShelfBoxes.GrabTime)
	Rarity: string, -- rareté de la caisse (BOX_<Rareté>), tirée par l'appelant
	From: Vector3?, -- départ d'un vol jusqu'au point (placeBox), sinon posé tout de suite
}

export type EventShelfOptions = {
	Id: string, -- StoreId, préfixe « Truck_ » (voir plus haut)
	Zone: number, -- zone du faux magasin (objet tiré près d'elle, revenu)
	ItemZones: { number }?, -- zones des objets de rareté rangée par zone (nil : règle des magasins)
	SizeOdds: { [string]: number }?, -- tailles garanties ({ Huge = 80, Colossal = 20 }), nil : comme en magasin
	-- Vague 56 (a181, L-166 Q5, camion) : à chaque sortie, objet de Zone + 1 avec cette probabilité, sinon de Zone ;
	-- jamais d'une autre zone (rareté absente : la rareté en dessous ; Secret et Divine : toutes zones). nil : ItemZones.
	NextZoneChance: number?,
	Spots: { EventSpot },
	Lifetime: number, -- s, puis tout est retiré
}

local function removeEventStore(store: Store, why: string)
	if eventStores[store.Model] ~= store then
		return
	end
	eventStores[store.Model] = nil
	storesById[store.Id] = nil
	store.Open = false
	cancelHolds(store)
	for payload, out in outItems do
		if out.Slot.Store == store then
			outItems[payload] = nil -- un objet porté reste porté ; tombé puis oublié, il ne revient plus
		end
	end
	for _, slot in store.Slots do
		slotsById[slot.Id] = nil
		removeBox(slot)
		removeItem(slot)
	end
	store.Model:Destroy()
	log(`rayon d'événement {store.Id} retiré : {why}`)
end

local function addEventShelf(options: EventShelfOptions): Model?
	local id = options.Id
	if storesById[id] ~= nil or Zones[options.Zone] == nil or #options.Spots == 0 then
		warn(`[StoreHeistService] AddEventShelf({id}) refusé : StoreId déjà pris, zone inconnue ou aucun point`)
		return nil
	end
	local model = Instance.new("Model")
	model.Name = EVENT_NAME_PREFIX .. id
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local anchor = Instance.new("Part")
	anchor.Name = "Anchor"
	anchor.Size = Vector3.one
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.CFrame = CFrame.new(options.Spots[1].CFrame.Position)
	anchor.Parent = model
	model.PrimaryPart = anchor
	local folder = Instance.new("Folder")
	folder.Name = BOXES_FOLDER
	folder.Parent = model
	local store: Store = {
		Id = id,
		Model = model,
		Zone = options.Zone,
		Bounds = nil,
		Window = nil,
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
		Open = true,
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
		Event = true,
		ItemZones = options.ItemZones,
		SizeOdds = options.SizeOdds,
		NextZoneChance = options.NextZoneChance,
	}
	for number, spot in options.Spots do
		local name = string.format(SLOT_FORMAT, number)
		local attachment = Instance.new("Attachment")
		attachment.Name = name
		attachment.CFrame = anchor.CFrame:ToObjectSpace(spot.CFrame)
		attachment.Parent = anchor
		local slot: Slot = {
			Store = store,
			Number = number,
			Name = name,
			Id = `{id}/{string.format("%02d", number)}`,
			Attachment = attachment,
			Box = nil,
			Item = nil,
		}
		table.insert(store.Slots, slot)
		slotsById[slot.Id] = slot
	end
	eventStores[model] = store
	storesById[id] = store
	model:SetAttribute(STORE_ID_ATTRIBUTE, id)
	model:SetAttribute(OPEN_ATTRIBUTE, true)
	CollectionService:AddTag(model, EVENT_TAG)
	model.Parent = Workspace
	for index, slot in store.Slots do
		local spot = options.Spots[index]
		placeBox(slot, spot.Rarity, spot.From)
	end
	task.delay(options.Lifetime, function()
		removeEventStore(store, `fin de sa durée de vie ({options.Lifetime} s)`)
	end)
	log(`rayon d'événement {id} : {#store.Slots} colis à ouvrir sur place, zone {options.Zone}, retiré dans {options.Lifetime} s`)
	return model
end

-- API ----------------------------------------------------------------------------------------------

-- Vague 42 (a148) : rayon d'événement (voir plus haut). Renvoie son modèle, ou nil (StoreId déjà pris,
-- zone inconnue, aucun point).
function StoreHeistService.AddEventShelf(options: EventShelfOptions): Model?
	return addEventShelf(options)
end

-- Retire tout de suite le rayon d'événement `id` (colis, ouvertures, objets non pris). false s'il n'existe pas.
function StoreHeistService.RemoveEventShelf(id: string): boolean
	local store = storesById[id]
	if store == nil or not store.Event then
		return false
	end
	removeEventStore(store, "retiré par son événement")
	return true
end

-- Vague 69 (a229) : change à chaque RefillAll, pour arrêter un remplissage étalé encore en cours.
local refillToken = 0

-- Nouveau tirage d'un magasin, ou report : renvoie les colis posés et 1 s'il est reporté.
local function refillStore(store: Store): (number, number)
	if store.Open or storeBusy(store) then
		-- nouveau tirage à la fermeture, ou (L-112) à la fin des ouvertures et des réservations en cours
		store.RefillPending = true
		return 0, 1
	end
	return fillStore(store), 0
end

local function logRefill(count: number, deferred: number)
	local later = if deferred > 0 then `, {deferred} magasin(s) ouvert(s) rempli(s) à leur fermeture` else ""
	log(`rayons remplis (nouveau tirage) : {count} colis répartis au hasard{later}`)
end

-- `spread` (vague 69, a229 : la tombée de la nuit gelait le serveur) : un magasin par image, le premier
-- tout de suite ; renvoie alors le nombre de magasins à remplir.
function StoreHeistService.RefillAll(spread: boolean?): number
	refillToken += 1
	local token = refillToken
	if not spread then
		local count, deferred = 0, 0
		for _, store in stores do
			local placed, later = refillStore(store)
			count += placed
			deferred += later
		end
		logRefill(count, deferred)
		return count
	end
	local list: { Store } = {}
	for _, store in stores do
		table.insert(list, store)
	end
	task.spawn(function()
		local count, deferred = 0, 0
		for index, store in list do
			if index > 1 then
				task.wait()
			end
			if refillToken ~= token then
				return -- un autre remplissage a pris la suite
			end
			if stores[store.Model] == store then
				local placed, later = refillStore(store)
				count += placed
				deferred += later
			end
		end
		logRefill(count, deferred)
	end)
	return #list
end

function StoreHeistService.IsOpen(store: Instance | string): boolean
	local found = if type(store) == "string" then storesById[store] else stores[store]
	return found ~= nil and found.Open
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

-- Vague 58 (a188, pluie d'objets, ItemRainService) : un objet tiré comme sur un rayon d'un magasin de la zone `zone`,
-- sans rayon ni caisse : rareté de la caisse selon la zone (drawRarity, ShelfBoxes.ZoneOdds, vague 76), chance (drawLuck), puis la sortie (drawShelfContent : rareté, objet, mutation). Renvoie le
-- contenu (nil si rien ne peut sortir) et la chance tirée.
function StoreHeistService.DrawForZone(zone: number): (Content?, number)
	local boxRarity = drawRarity(zone)
	if boxRarity then
		local luck = drawLuck()
		local content = drawShelfContent(boxRarity, zone, luck)
		return content, luck
	end
	return nil, 1
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
	-- Vague 62 : accès protégé, les faux Net des bancs n'ont pas tous RevealDone.
	local okDone, doneErr = pcall(function()
		(Net.Server :: any).RevealDone:Connect(onRevealDone)
	end)
	if not okDone then
		log(`remote RevealDone indisponible ({doneErr}) : chaque cinématique finit à son plafond de temps`)
	end
	-- Vague 62 : StatsService.SetSpeedModifier immobilise l'ouvreur pendant sa cinématique (require protégé :
	-- sans lui, bancs, il n'est pas immobilisé).
	local okStats, stats = pcall(function(): any
		return require(script.Parent.StatsService) :: any
	end)
	if okStats and type(stats) == "table" and type(stats.SetSpeedModifier) == "function" then
		setSpeedModifier = stats.SetSpeedModifier
	else
		log("StatsService.SetSpeedModifier indisponible : l'ouvreur n'est pas immobilisé pendant sa cinématique")
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		local session = reveals[player]
		if session then
			finishReveal(session, "joueur parti", true) -- vague 62 : fin propre, l'objet reste sur le rayon
		end
		pausedChronos[player] = nil
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
	-- require protégé : sans GuardService (bancs), pas de vigile à la fin du chrono.
	local okGuard, guardApi = pcall(function(): any
		return require(script.Parent.GuardService) :: any
	end)
	-- L-118 : fermé pour le voleur jusqu'à la réouverture seulement (plus de réouverture au départ de son
	-- vigile, GuardService.OnGuardGone), et le vigile sort à la fin du chrono (ChaseIntruder), plus à la prise.
	local chase: any = if okGuard and type(guardApi) == "table" then guardApi.ChaseIntruder else nil
	local safe: any = if okGuard and type(guardApi) == "table" then guardApi.IsInSafeZone else nil
	if type(safe) == "function" then
		inSafeZone = safe -- a157 : Shared/SafeZone, par GuardService
	end
	if type(chase) == "function" then
		chaseIntruder = chase
	else
		log("GuardService.ChaseIntruder indisponible : aucun vigile à la fin du chrono")
	end
	-- Attrapé DANS le magasin par un vigile de jour (Cantin, 2026-11-13) : le magasin se
	-- ferme pour lui tout de suite (plus d'ouverture ni de prise, reachRefusal), puis il est sorti devant la
	-- vitrine par stepLocks une fois le coup donné (Balance.Guard.CatchStunDuration s, V0), comme un joueur
	-- qui sort : rideau baissé pour lui jusqu'à la réouverture. La nuit renvoie déjà à la base.
	local onCatch: any = if okGuard and type(guardApi) == "table" then guardApi.OnCatch else nil
	if type(onCatch) == "function" then
		(onCatch :: any)(function(player: Player, _zone: number, night: boolean, _carrying: boolean)
			-- a211 (bug vu en Play le 16/11) : attrapé, il n'est plus l'intrus d'aucun magasin (plus de chrono ni de
			-- vigile de fin de chrono pour lui) ; avant, chronoEnd lui envoyait un 2e vigile s'il était encore dedans,
			-- étourdi, à la fin du chrono : deux « Caught! » et deux scènes de capture.
			for _, store in stores do
				if store.Entered[player] then
					store.Entered[player] = nil
					local paused = pausedChronos[player]
					if paused ~= nil and paused.Store == store then
						pausedChronos[player] = nil
					end
					hideTimer(store, player)
					log(`{player.Name} attrapé : plus intrus de {store.Id}, plus de chrono ni de vigile de fin de chrono`)
				end
			end
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
	else
		log("GuardService.OnCatch indisponible : un joueur attrapé dans un magasin y reste")
	end
	-- La vitrine n'est reconstruite qu'une fois le magasin fermé, et RebuildDelay s après au plus tôt.
	local addGate: any = (WindowService :: any).AddRebuildGate
	if addGate ~= nil then
		(addGate :: any)(function(_windowId: string, model: Model?): boolean
			local store = if model then stores[model] else nil
			return store == nil or (not store.Open and os.clock() >= store.ClosedAt + Balance.Window.RebuildDelay)
		end)
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
	for _, look in { "Standard", "Premium", "Luxe" } do -- vague 76 : anciens modèles, repli d'apparence (lookOf)
		if boxTemplate(BOX_PREFIX .. look) then
			table.insert(delivered, BOX_PREFIX .. look)
		end
	end
	local looks = if #delivered > 0 then `modèles {table.concat(delivered, ", ")}` else "blocs V0 (aucun BOX_* livré)"
	print(
		`[StoreHeistService] {storeCount} magasin(s) prêt(s), {boxCount} colis répartis au hasard sur les rayons, rareté de la caisse tirée à la mise en rayon, objet tiré à l'ouverture ({looks})`
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
