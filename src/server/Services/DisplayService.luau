--!strict
-- DisplayService (DEV-020) : présentoirs, objets exposés, halos, billboards, revenus et plaques de ramassage
-- (Partie 1, sections 5.6, 5.8, 7.1, 7.3, 7.5, 9.4 et 9.5).
--
-- Rôle :
--   - expose les objets du profil sur les présentoirs de la parcelle de leur propriétaire :
--     Display["n"] = uid (9.5, numéro écrit en texte) pose l'objet Items[uid] sur l'Attachment
--     DisplaySlot_0n de la parcelle (10.4). Présentoirs débloqués = Balance.Display.StartSlots
--     (4) + niveau Upgrades.DisplaySlots du profil, au plus Balance.Display.MaxSlots (20), plus les
--     présentoirs bonus du gamepass « +4 présentoirs » (DEV-100, plus bas) ;
--   - pour chaque objet exposé : le modèle ITM_<ItemId> de Clément s'il est livré
--     (ReplicatedStorage/Assets/Items, sous-dossiers permis), sinon un bloc V0 à la couleur de
--     sa rareté ; autour, le halo de sa rareté (5.6) ; au-dessus, le billboard BB_Item de Clément
--     (ReplicatedStorage/Assets/UI, contrat 2.2 : ItemName, Rarity, Income), adossé au pied de
--     l'objet (son StudsOffset part de là, liaison L-027), sinon un billboard V0 adossé à son
--     sommet. Tout est créé par le serveur dans la parcelle : visible par tous les joueurs ;
--   - revenus : chaque objet exposé rapporte Formulas.ItemIncome(objet) $/s (7.1 ; vague 76 :
--     rareté, zone et rang de l'objet dans Config.Items), × le multiplicateur de sa mutation (DEV-131, champ Mutation
--     de Items[uid] : taille × effet, Config/Mutations). Le total des objets (la « valeur exposée », 6.4)
--     est multiplié par le M global du joueur (7.1 : (1 + GetIncomeBonus) ×
--     GetIncomeMultiplier, plus bas ; 1 au MVP). Ramassage par plaque (L-082 point 4, L-091 points 4
--     et 5, à la place de la caisse unique CashPad, retirée du contrat) : l'argent de chaque objet
--     s'accumule au temps exact sur la plaque de son présentoir, `CollectPad_xx` (même numéro que
--     DisplaySlot_xx), pas dans Cash. Quand le propriétaire marche sur une plaque, l'argent de cette
--     plaque passe dans son argent (DataService.AddCash) et elle repart de 0 (5.8). L'argent d'une
--     plaque reste sur elle quand son objet s'en va (déplacé, rangé, volé) : il se ramasse quand même.
--     Le montant s'écrit côté serveur, visible par tous, dans `CollectPad_xx/…/AmountGui/Amount`
--     (Format.money, dollars entiers), au plus une fois par seconde. AmountGui (BillboardGui depuis
--     L-107 point 1, SurfaceGui avant : les deux sont lus) est caché (Enabled = false) quand la plaque
--     porte moins de $1 (présentoir vide, ou plaque qui vient d'être ramassée), proposition de Clément.
--     Ses textes CollectLabel (fixe) et OfflineLabel (caché) ne sont pas touchés : les gains hors
--     ligne ne passent pas par les plaques (versés au Claim d'UI_Offline, plus bas), aucune partie du
--     montant d'une plaque n'en vient ; à chaque ramassage, le remote
--     CashCollect(plotIndex, slotIndex, amount) part vers tous les clients (DisplayController : gerbe
--     de BurstPoint, puis OnCollect chez le propriétaire). L'argent des plaques n'est pas volable :
--     rien ne permet à un autre joueur de le prendre ;
--   - remote PlaceItem(itemUid, slotIndex) (9.4), validé ici.
--
-- Le profil fait foi : Display et Items décident de ce qui est exposé, l'affichage suit. Après
-- chaque changement fait par ce service, et une fois par seconde, l'affichage est remis d'accord
-- avec le profil. Une entrée de Display invalide (objet absent de Items ou inconnu du catalogue,
-- présentoir verrouillé ou absent de la parcelle, objet rangé au coffre-fort ou déjà exposé
-- ailleurs) est retirée de Display, avec un avertissement : l'objet reste dans Items, donc dans
-- l'inventaire. Un objet de Items qui n'est ni exposé ni au coffre-fort est dans l'inventaire.
--
-- Attributs posés par ce service (lus par DisplayController et, plus tard, par le HUD) :
--   sur le Player :
--     Income (number)                $/s que les plaques reçoivent : total des objets exposés × M global
--     ExposedIncome (number)         $/s total des objets exposés, sans bonus (valeur exposée :
--                                    panneau des boutiques, PvPController)
--     CashCollected (number)         argent encaissé depuis l'arrivée sur le serveur : plaques,
--                                    encaissement automatique, gains hors ligne (il ne fait que monter :
--                                    chaque hausse = un encaissement)
--     DisplaySlotsUnlocked (number)  présentoirs débloqués (4 à 20, plus les présentoirs bonus et ceux de l'étage)
--     FloorStands (number)           a280 : places du 2e étage ouvertes au joueur (0 à 8 ; plus bas), lu par
--                                    UpgradeController (prix et prochain présentoir) et ShopService (achat)
--   sur la parcelle :
--     CashRegister (number)          total des plaques, en dollars entiers ; 0 si libre
--   sur chaque objet exposé (Model `DisplayItem_<nn>`, tag de code `DisplayItem`, rangé dans le
--   dossier `DisplayItems` de la parcelle, ModelStreamingMode Atomic) :
--     ItemUid, ItemId, Rarity, Halo, Income, DisplaySlot, OwnerUserId, Placeholder (bloc V0),
--     MutationSize et MutationEffect (DEV-131 : Id de Config/Mutations, absents sans mutation ; les
--     effets visuels sont à Clément, MOD-131 ; une taille met le modèle à l'échelle, Model:ScaleTo) ;
--     la copie du modèle ITM_ garde aussi l'attribut Idle de Clément et ses pièces Spin_ (L-045),
--     qu'ItemIdleController anime côté client (le halo RarityHalo et le billboard restent fixes) ;
--     a317 (L-304 point 3) : avec Config/DisplayMotion, tout objet exposé y flotte, halo et billboard compris (le
--     serveur ne le bouge pas ; il garde seulement la hauteur du flottement libre sous le FitSize et accroche BB_Item
--     au sommet de la boîte)
--
-- API (côté serveur) :
--   DisplayService.PlaceAuto(player, itemUid, near?) -> number?
--       Expose l'objet Items[itemUid] (déjà dans le profil) sur le présentoir libre et débloqué
--       le plus proche de `near` (par défaut : le personnage, donc l'établi où il vient d'ouvrir
--       son colis), sinon sur le premier libre. Renvoie le numéro du présentoir, son présentoir
--       actuel s'il est déjà exposé, ou nil (tout est pris, pas de parcelle, objet inconnu ou au
--       coffre-fort) : l'objet reste alors dans Items. Sans yield. N'envoie aucun message :
--       à l'appelant de prévenir le joueur.
--   DisplayService.PlaceItem(player, itemUid, slotIndex) -> (boolean, PlaceError?)
--       Expose l'objet sur ce présentoir (ou l'y déplace s'il est exposé ailleurs). Mêmes règles
--       que le remote PlaceItem, sans le contrôle de position (pour le code serveur : retour d'un
--       objet volé sur son présentoir d'origine, 6.1). Sans yield.
--   DisplayService.Unplace(player, itemUid) -> number?
--       Retire l'objet de son présentoir ; il reste dans Items (inventaire). Renvoie le numéro du
--       présentoir libéré, nil s'il n'était pas exposé (ou s'il est tenu par un voleur, plus bas).
--       Sans yield. À appeler AVANT de retirer un objet de Items (receleur) ; sinon il disparaît
--       quand même du présentoir à la mise à jour suivante (au plus 1 s).
--   Vol entre joueurs (DEV-041, PvPService, 6.1) : pendant la fuite, l'objet volé est « tenu ». Son
--   présentoir se vide et il ne rapporte plus, mais le profil du propriétaire ne change pas (Display
--   et Items gardent l'objet) jusqu'au dépôt. Un objet tenu ne bouge pas : PlaceItem (« Held »),
--   PlaceAuto et Unplace le refusent. Sans yield :
--   DisplayService.Hold(player, itemUid) -> number?
--       L'objet exposé devient tenu ; renvoie son présentoir, nil s'il n'est pas exposé sur un
--       présentoir de la parcelle (ou déjà tenu).
--   DisplayService.Release(player, itemUid) -> boolean
--       Échec du vol : l'objet tenu revient sur son présentoir et rapporte de nouveau.
--   DisplayService.TakeHeld(player, itemUid) -> boolean
--       Dépôt : l'objet tenu quitte son présentoir pour de bon (Display) ; il reste dans Items, que
--       l'appelant vide dans la même exécution (transfert sûr, 9.6). false s'il n'était pas tenu.
--   DisplayService.IsHeld(player, itemUid) -> boolean
--   DisplayService.GetExposed(player) -> { [présentoir]: { Uid, ItemId, Income } }
--       Objets exposés et affichés en ce moment (tenus exclus), avec leur revenu ($/s).
--   DisplayService.HasRoom(player) -> boolean
--       Un présentoir débloqué libre, ou moins de Balance.Display.InventoryMax objets dans
--       l'inventaire : un objet de plus a sa place.
--   DisplayService.HasInventoryRoom(player) -> boolean
--       Moins de Balance.Display.InventoryMax objets dans l'inventaire (5.8 : 30 objets non exposés) :
--       l'objet d'un colis ouvert y va (L-089, UnboxService). Sans yield.
--   Plus de colis sur les présentoirs depuis L-089 (2026-11-09) : les colis se posent au sol de la
--   boutique (UnboxService). Sans yield :
--   DisplayService.GetSlots(player) -> { [number]: Attachment }
--       Présentoirs DisplaySlot_xx de la parcelle du joueur (bonus posés compris), cherchés une fois
--       par parcelle comme pour les objets ; vide sans parcelle.
--   DisplayService.GetSlotStates(player) -> { [number]: SlotState }
--       État de chacun de ces présentoirs : "Locked" (pas débloqué), "Taken" (un objet exposé, ou tenu
--       par un voleur), "Free" (débloqué, sans objet). Vide sans profil ou sans parcelle.
--   DisplayService.EquipBest(player) -> number
--       Equip Best (L-079, L-089 ; remote EquipBest, bouton de l'écran d'inventaire de Clément à venir) :
--       les objets qui rapportent le plus vont sur les présentoirs. Règle V0 (proposée, absente du
--       doc) : parmi les objets du joueur (exposés et inventaire ; ni au coffre-fort ni tenus par un
--       voleur), les N qui rapportent le plus (revenu de l'objet, mutation comprise, comme plus haut),
--       N = présentoirs débloqués et posés dans la parcelle, sans ceux d'un objet tenu. À revenu égal,
--       un objet déjà exposé passe d'abord (il ne bouge pas pour rien), puis le plus petit uid. Un
--       objet exposé qui en fait partie reste sur son présentoir ; un objet exposé qui n'en fait pas
--       partie retourne dans l'inventaire ; les autres vont sur les présentoirs libres, du plus petit
--       numéro au plus grand. L'inventaire ne grossit jamais (un objet n'en sort que remplacé). Où que
--       soit le joueur, sans yield. Renvoie le nombre d'objets posés sur un présentoir (0 : rien à
--       changer, ou pas de parcelle).
--       Vague 63 (a206, L-192 Q3) : un exposé remplacé va aussi dans la RÉSERVE (au bout, du meilleur au moins bon).
--   Réserve (vague 63, a206 ; L-192 Q3, L-202 point 4 ; Config/Displayed) : champ Reserve du profil, liste d'uids
--   d'objets ni exposés, ni au coffre-fort, ni sous antivol, au plus ReserveMax (V0 : 30 ; pleine, un objet remplacé
--   reste hors liste, dans Items). Nettoyée à chaque usage ; publiée dans l'attribut DisplayReserve du Player (uids
--   séparés par « , ») après chaque changement fait ici et une fois par seconde. Profil d'avant (champ absent) :
--   migré au chargement, ses objets non exposés y vont (les plus rentables d'abord), rien ne quitte Items. Un objet
--   de la réserve reste un objet du joueur comme avant (barre du bas, mise en main, Equip Best, vente).
--   DisplayService.GetReserve(player) -> { string }          copie de la réserve nettoyée
--   DisplayService.AddToReserve(player, itemUid) -> boolean  au bout ; false si pleine, déjà dedans ou pas possible
--   DisplayService.PlaceFromReserve(player, itemUid) -> (number?, string?)
--       Remote PlaceFromReserve (DisplayButton de UI_Displayed) : l'objet de sa réserve va sur le présentoir libre et
--       débloqué le plus proche (PlaceAuto) ; refus : "NoProfile", "NotInReserve", "NoPlot", "NoFreeDisplay" (V0 : Notify
--       « No free display », rien ne bouge, règle à proposer à Clément). Réussite : Notify « Success ».
--   Vague 66 (a219, L-210 point 2 « bloqués à vie », Config/Displayed) : un objet en main n'est pas dans la réserve
--   (attribut HeldItem du Player) ; ReserveCatchAll : une fois par seconde et au chargement, tout objet que la réserve
--   peut garder et qui n'y est pas y entre au bout (les plus rentables d'abord, au plus ReserveMax) ; SwapWhenFull :
--   PlaceFromReserve sans présentoir libre échange avec l'exposé qui rapporte le moins (il va dans la réserve, 3e valeur
--   rendue = son uid ; Notify « … moved to your reserve »).
--   DisplayService.GetIncome(player) -> number      $/s total exposé, sans bonus (0 sans parcelle)
--   DisplayService.GetRegister(player) -> number    total des plaques, en dollars entiers
--   DisplayService.GetCollectTarget(player) -> Vector3?
--       Plaque à montrer au joueur (flèche du tuto) : celle qui porte le plus d'argent, sinon celle
--       de l'objet exposé au plus petit numéro ; nil sans parcelle ou sans plaque. Sans yield.
--   DisplayService.CashOut(player) -> number
--       Vide toutes les plaques dans l'argent du joueur, sans y marcher ; renvoie le montant.
--   DisplayService.OnCashOut(listener) -> déconnexion
--       listener(player, amount, source) après chaque encaissement : source = "Pad" (une plaque
--       CollectPad_xx), "Leave" (départ du joueur), "Api" (CashOut), "Auto" (encaissement
--       automatique, plus bas) ou "Offline" (gains hors ligne). Pour le tutoriel et la télémétrie
--       (« Premier encaissement », 14.2).
--   DisplayService.AddOfflineEarnings(player, amount) -> boolean
--       Gains hors ligne (DEV-102, OfflineService) : verse `amount` $ (nombre fini > 0 ; les centimes
--       sont perdus) directement dans l'argent du joueur, au Claim de l'écran UI_Offline (vague 22),
--       source « Offline » (V0, plus bas). false si
--       le profil n'est pas chargé ou le montant invalide. Sans yield.
--
-- Points d'accroche de la boutique Robux (DEV-100, Partie 2, 4.1 ; MonetizationService les
-- remplace en gardant ceux d'avant) et de l'index (DEV-111, IndexService). Par défaut : le MVP, sans
-- bonus. Ne doivent pas yield ; une erreur ou une valeur invalide compte pour la valeur par défaut
-- (un avertissement par serveur). M global des revenus (7.1) = (1 + GetIncomeBonus) ×
-- GetIncomeMultiplier (Partie 2, section 4 : les bonus en pour cent s'additionnent, les ×2 se
-- multiplient), relu à chaque mise à jour (une fois par seconde) : un changement compte dès cet
-- instant, jamais en arrière.
--   DisplayService.GetIncomeBonus(player) -> number
--       Somme des bonus de revenus en pour cent, en fraction (0,15 = +15 %), nombre fini ≥ 0 ; 0 par
--       défaut. Chaque accroche ajoute le sien à celui d'avant : Roblox Premium (MonetizationService),
--       zones complètes de l'index (IndexService) ; plus tard amis, groupe, VIP, renaissances.
--   DisplayService.GetIncomeMultiplier(player) -> number
--       Produit des multiplicateurs de revenus (×2 Argent, boost ×2 argent), nombre fini > 0 ; 1 par
--       défaut. Chaque accroche multiplie celui d'avant.
--   DisplayService.GetExtraSlots(player) -> number
--       Présentoirs bonus, au-delà de Balance.Display.MaxSlots : DisplaySlot_21 et suivants, optionnels
--       dans la parcelle (aucun avertissement s'ils manquent ; seuls ceux posés comptent) ; 0 par défaut.
--       Un objet posé sur un présentoir bonus qui n'est plus débloqué retourne dans l'inventaire.
-- 2e étage (a280, vague GC2, lot C ; L-217, L-277, règle de L-294 ; Shared/ShopFloor, Config/ShopGrowth.Floor2) : avec
-- un Floor_2 et un profil passé à la nouvelle échelle (ShopLayout 1 ; ShopStageService.FloorStands), le bas s'arrête à
-- 8 présentoirs, puis l'étage s'achète et ses places DisplaySlot_31 à _38 (Model Floor_2 de la parcelle, que
-- ShopStageService.EnsureFloor copie du gabarit au besoin) se débloquent une à une (Shared/ShopFloor). Elles comptent
-- comme les autres (Equip Best, réserve, plaques CollectPad_31 à _38, sinon la plaque au plus petit numéro). Les
-- présentoirs bonus (DisplaySlot_21 et suivants, posés dans Floor_2 par Clément) ne s'ouvrent qu'avec l'étage acheté.
-- Les présentoirs 9 à 20 ne sont plus attendus dans la parcelle. Sans Floor_2 ni ShopStageService : comme avant.
--   DisplayService.HasAutoCollect(player) -> boolean
--       true : les plaques se vident toutes seules dans l'argent du joueur à chaque mise à jour (une fois par
--       seconde), où qu'il soit (source « Auto », sans ligne dans la sortie) ; false par défaut.
-- Et, sans être une accroche :
--   DisplayService.GetGlobalMultiplier(player) -> number
--       Le M global du joueur, lu tout de suite dans les accroches (bonus compris) : $/s des plaques
--       = GetIncome × GetGlobalMultiplier (packs d'argent de la boutique Robux). Sans yield.
--   DisplayService.BuildBotItem(plot, slotIndex, itemUid, itemId) -> Model?
--       Bot joueur (L-105, BotService) : l'objet `itemId` du bot, posé sur le présentoir DisplaySlot_xx de
--       `plot`, construit comme un objet de joueur (modèle ITM_ ou bloc V0, halo, BB_Item, tag DisplayItem et
--       attributs, OwnerUserId = 0 ; revenu de sa zone au catalogue). Ni profil, ni plaque, ni revenu : à
--       l'appelant de le ranger et de le détruire. nil si le présentoir manque ou si l'objet est inconnu.
--   DisplayService.BuildFloorItem(ownerUserId, pivot, itemUid, entry) -> Model?
--       Vague 31 (L-112, UnboxService) : l'objet `entry` (Items[uid]) sous antivol, posé au sol en `pivot`,
--       construit comme un objet exposé (modèle ITM_ ou bloc V0, mutation de taille, halo, attributs), sans
--       BB_Item (BB_AntiTheft le remplace, côté client), sans tag DisplayItem ni DisplaySlot (ni invite de vol
--       de présentoir, ni revenu). Nommé FloorItem. À l'appelant de le ranger et de le détruire.
-- Objet sous antivol (vague 31, L-112 ; Items[uid].AntiTheft) : PlaceItem (« AntiTheft »,
-- Notify), PlaceAuto (nil) et Equip Best le refusent ; une entrée de Display qui le montre est retirée.
--
-- Remote PlaceItem(itemUid, slotIndex) : refusé (Notify « Warning » au joueur, avertissement en
-- Studio) si le joueur n'a pas de parcelle, n'est pas dans le volume Bounds de sa parcelle, ne
-- possède pas l'objet, l'a rangé au coffre-fort, si un voleur l'emporte (tenu), ou si le présentoir
-- est verrouillé, absent ou déjà occupé. Un objet déjà exposé sur un autre présentoir y est déplacé.
-- Vague 44 (a152) : envoyé par l'invite « Display » d'un présentoir libre quand on tient un objet en main
-- (DisplayController). Pas de contrôle de portée en plus de Bounds : PlaceItemAuto pose déjà de n'importe où,
-- et le joueur ne pose que chez lui. L'objet tenu, exposé, quitte la main (HeldItemService).
-- Depuis L-091 point 6, l'écran d'inventaire (UI_Inventory) pose un objet par PlaceItemAuto
-- (premier présentoir libre) et le reprend par UnplaceItem ; PlaceItem reste pour un présentoir choisi.
-- Remote EquipBest() : DisplayService.EquipBest (plus haut), puis un Notify « Info » (MESSAGES).
-- Après chaque changement de Display fait ici, la barre d'inventaire est remise à jour tout de suite
-- (InventoryService.Refresh, s'il est là).
--
-- Choix V0 (marqués « V0 proposé, absent du doc » plus bas) :
--   - ramassage à chaque arrivée sur une plaque : Touched par le personnage du propriétaire, ou
--     HumanoidRootPart au-dessus de la plaque (contrôlé 10 fois par seconde, pour une plaque sans
--     CanTouch). Une arrivée = un seul ramassage de tout ce que la plaque contient (vague 24, retour
--     de Cantin du 2026-11-11 : ça ramassait plusieurs fois). Rester dessus ne ramasse pas davantage :
--     les Touched répétés des pieds ne comptent pas, et le joueur ne quitte la plaque qu'une fois son
--     HumanoidRootPart hors d'une zone de sortie plus large (PAD_EXIT_MARGIN, PAD_EXIT_ABOVE) pendant
--     PAD_EXIT_DELAY s : marcher ou sauter sur la plaque ne la fait pas « quitter ». Passer sur une
--     autre plaque la ramasse tout de suite (plaques indépendantes). Délai par plaque (L-106 point 12,
--     remplace L-091 : deux textes de gain se superposaient) : une même plaque attend PAD_COOLDOWN s
--     après son dernier ramassage avant d'être ramassée de nouveau ; un joueur qui y revient plus tôt
--     la ramasse dès la fin du délai s'il y est encore. Une autre plaque n'attend pas. Une plaque donne
--     des dollars entiers, les centimes restent sur elle. Seul le propriétaire ramasse ;
--   - plaques cherchées dans toute la parcelle (CollectPad_01 à _20 ; ceux des rayons 2 à 5 n'y sont
--     que quand RayonService a posé le rayon) : à l'installation, quand le nombre de présentoirs
--     débloqués change, quand une plaque connue disparaît, et toutes les PAD_RESCAN_INTERVAL s tant
--     qu'un présentoir débloqué n'a pas la sienne. L'argent d'un présentoir sans plaque (présentoirs
--     bonus DisplaySlot_21 et suivants) va sur la plaque au plus petit numéro ;
--   - départ du joueur : toutes ses plaques sont encaissées automatiquement dans son argent, juste
--     avant la sauvegarde (DataService.OnProfileReleasing). Il ne perd pas ce qu'il a gagné, et
--     aucun champ n'est ajouté au schéma 9.5 ;
--   - gains hors ligne (DEV-102, OfflineService) : versés directement dans son argent au Claim, pas
--     sur les plaques. Le plus simple et le plus juste : ils ne viennent d'aucune plaque (les objets
--     ont pu changer depuis le départ), et rien n'attend sur une plaque qu'il faudrait ramasser ;
--   - zone d'un Secret : le catalogue ne lui en donne pas, et Items[uid] ne la stocke pas (9.5).
--     Ce service lit un champ Zone dans Items[uid] s'il existe, sinon prend la zone 1.
--
-- Tester dans Studio : rapport de l'agent a14 (notes partagées) ou fin de ce fichier.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Formulas = require(ReplicatedStorage.Shared.Config.Formulas)
local ItemsConfig = require(ReplicatedStorage.Shared.Config.Items)
local Mutations = require(ReplicatedStorage.Shared.Config.Mutations)
local WeightConfig = require(ReplicatedStorage.Shared.Config.Weight)
local ItemWeight = require(ReplicatedStorage.Shared.ItemWeight)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local DisplayedConfig = require(ReplicatedStorage.Shared.Config.Displayed) -- vague 63 (a206) : réserve
local HeldItemConfig = require(ReplicatedStorage.Shared.Config.HeldItem) -- vague 66 (a219) : objet en main, hors réserve
local InventoryState = require(ReplicatedStorage.Shared.InventoryState) -- vague 63 : IsSafeId (attribut de la réserve)
local Format = require(ReplicatedStorage.Shared.Format)
local RarityHalo = require(ReplicatedStorage.Shared.RarityHalo)
local Find = require(ReplicatedStorage.Shared.Contract.Find)
local Attributes = require(ReplicatedStorage.Shared.Contract.Attributes) -- a234 : FitSize, Idle
-- a317 (L-304 point 3) : hauteur gardée libre pour le flottement (Headroom) et accroche de BB_Item au sommet ; Bob de
-- l'attribut Idle (ItemIdle.BobHeight). Facultatifs : bancs plus anciens (sans eux, comme avant).
local motionModule = ReplicatedStorage.Shared.Config:FindFirstChild("DisplayMotion")
local DisplayMotion: any = if motionModule and motionModule:IsA("ModuleScript") then require(motionModule) :: any else nil
local FLOAT: boolean = DisplayMotion ~= nil and DisplayMotion.Enabled == true
local idleModule = ReplicatedStorage.Shared.Config:FindFirstChild("ItemIdle")
local ItemIdleConfig: any = if idleModule and idleModule:IsA("ModuleScript") then require(idleModule) :: any else nil
local UI = require(ReplicatedStorage.Shared.Contract.UI)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local ProfileTypes = require(ReplicatedStorage.Shared.Types.Profile)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local ShopGrowth = require(ReplicatedStorage.Shared.Config.ShopGrowth) -- a280 : 2e étage
local ShopFloor = require(ReplicatedStorage.Shared.ShopFloor) -- a280

type Data = ProfileTypes.Data
type ItemEntry = ProfileTypes.Item
type ItemDef = ItemsConfig.Item
type Rarity = Rarities.Rarity

export type CashOutSource = "Pad" | "Leave" | "Api" | "Auto" | "Offline"
export type CashOutListener = (player: Player, amount: number, source: CashOutSource) -> ()
export type PlaceError = "NoProfile" | "NoPlot" | "UnknownItem" | "InVault" | "Held" | "NoSlot" | "Locked" | "Taken" | "NotOnPlot" | "AntiTheft"
-- État d'un présentoir pour UnboxService (GetSlotStates ; attribut UnboxState, L-089).
export type SlotState = "Free" | "Locked" | "Taken"

-- Barre d'inventaire (InventoryService, L-089), chargée si elle est là : sans elle (banc d'essai), la
-- barre suit quand même le profil, au plus 0,5 s plus tard.
type InventoryApi = { Refresh: (player: Player) -> () }
local inventoryModule = script.Parent:FindFirstChild("InventoryService")
local inventoryLoaded: boolean, inventoryResult: any = false, nil
if inventoryModule and inventoryModule:IsA("ModuleScript") then
	inventoryLoaded, inventoryResult = pcall(require, inventoryModule)
end
local InventoryService: InventoryApi? = if inventoryLoaded and type(inventoryResult) == "table" then inventoryResult :: any else nil

-- a280 : 2e étage (ShopStageService), chargé s'il est là (banc d'essai sans lui : aucune place d'étage).
type StageApi = {
	EnsureFloor: (plot: Model) -> Instance?,
	FloorSlots: (floor: Instance) -> ({ [number]: Attachment }, number),
	FloorStands: (plot: Model, rebirths: number?) -> number,
}
local stageModule = script.Parent:FindFirstChild("ShopStageService")
local stageLoaded: boolean, stageResult: any = false, nil
if stageModule and stageModule:IsA("ModuleScript") then
	stageLoaded, stageResult = pcall(require, stageModule)
end
local ShopStageService: StageApi? = if stageLoaded and type(stageResult) == "table" then stageResult :: any else nil

-- Objet exposé en ce moment (GetExposed).
export type ExposedItem = { Uid: string, ItemId: string, Income: number }
-- Objet candidat d'Equip Best (L-089).
type Candidate = { uid: string, income: number, shown: boolean }

local IS_STUDIO = RunService:IsStudio()

-- Contrat 10.4 (parcelle) : présentoirs, plaques de ramassage et volume de la parcelle, cherchés
-- parmi les descendants (règle Contract/Find).
local SLOT_FORMAT = "DisplaySlot_%02d" -- Attachments DisplaySlot_01 à DisplaySlot_20
local COLLECT_PAD_PATTERN = "^CollectPad_(%d+)$" -- CollectPad_01 à _20, une plaque par présentoir
local AMOUNT_GUI = "AmountGui" -- BillboardGui (L-107) ou SurfaceGui (avant) de la plaque, caché à $0
local AMOUNT_PATH = "AmountGui.Amount" -- TextLabel de AmountGui où s'écrit le montant
local BOUNDS = "Bounds"
-- Contrat 2.2 : billboard modèle d'un objet exposé et ses 3 champs.
local ITEM_BILLBOARD = "BB_Item"
local BILLBOARD_FIELDS = { "ItemName", "Rarity", "Income" }
-- Texte facultatif de BB_Item pour la mutation (DEV-131) : nom proposé à Clément, hors contrat.
local MUTATION_FIELD = "Mutation"
-- Attributs de la mutation sur l'objet exposé (DEV-131) : Clément y accroche ses effets (MOD-131).
local MUTATION_SIZE_ATTRIBUTE = "MutationSize"
local MUTATION_EFFECT_ATTRIBUTE = "MutationEffect"
-- Rangement des modèles finis (2.1 : ReplicatedStorage/Assets/<Catégorie>) : ITM_<ItemId>.
local ASSETS = "Assets"
local ITEMS_FOLDER = "Items"

-- Attributs posés par ce service (voir l'en-tête).
local INCOME_ATTRIBUTE = "Income"
local EXPOSED_INCOME_ATTRIBUTE = "ExposedIncome"
local COLLECTED_ATTRIBUTE = "CashCollected"
local SLOTS_ATTRIBUTE = "DisplaySlotsUnlocked"
local FLOOR_STANDS_ATTRIBUTE = "FloorStands" -- a280, nom V0 (absent du doc) : places d'étage ouvertes
local REGISTER_ATTRIBUTE = "CashRegister"
-- Posé par PlotService sur la parcelle : son numéro, envoyé avec CashCollect.
local PLOT_INDEX_ATTRIBUTE = "PlotIndex"

-- Objets créés par ce service. Aucun n'est un nom du contrat 10.4 : ils ne gênent pas les
-- recherches des autres services dans la parcelle.
local FOLDER_NAME = "DisplayItems"
local MODEL_FORMAT = "DisplayItem_%02d"
local DISPLAY_TAG = "DisplayItem" -- tag de code, pas un tag de la map : lu par DisplayController
local FLOOR_ITEM_NAME = "FloorItem" -- vague 31 (L-112) : objet sous antivol posé au sol (BuildFloorItem, UnboxService)
local BILLBOARD_POINT = "BillboardPoint"
local RAINBOW_GRADIENT = "RarityRainbow"

-- V0 proposé, absent du doc : cadence de la mise à jour des montants des plaques (texte Amount,
-- attribut CashRegister) et de l'affichage. Les revenus, eux, comptent au temps exact.
local REFRESH_INTERVAL = 1
-- V0 proposé, absent du doc : cadence du contrôle « debout sur une plaque » (Touched déclenche
-- aussi le ramassage tout de suite, pour un joueur rapide qui traverse la plaque sans s'arrêter).
local PAD_CHECK_INTERVAL = 0.1
-- V0 proposé, absent du doc : délai entre deux recherches des plaques d'une parcelle quand un
-- présentoir débloqué n'a pas la sienne (voir l'en-tête).
local PAD_RESCAN_INTERVAL = 5
-- V0 proposé, absent du doc : volume où l'on ramasse : l'emprise de la plaque élargie de PAD_MARGIN,
-- de PAD_BELOW sous son dessus à PAD_ABOVE au-dessus (le HumanoidRootPart d'un R15 debout est à
-- environ 3 studs du sol).
local PAD_MARGIN = 0.5
local PAD_BELOW = 1
local PAD_ABOVE = 6
-- V0 proposés, absents du doc (vague 24) : zone de sortie, plus large que la zone d'arrivée, et
-- temps passé hors d'elle avant de pouvoir ramasser de nouveau la même plaque (un saut monte
-- d'environ 7 studs, le HumanoidRootPart d'un R15 qui marche oscille).
local PAD_EXIT_MARGIN = 2
local PAD_EXIT_ABOVE = 12
local PAD_EXIT_DELAY = 0.3
-- L-106 point 12 (Clément, 2026-11-12) : délai d'1 s par plaque entre deux ramassages de la même plaque.
local PAD_COOLDOWN = 1
-- V0 proposé, absent du doc : borne de la recherche des présentoirs bonus (DisplaySlot_21 et
-- suivants, DEV-100) ; pas une règle de jeu, le gamepass en donne 4 (Config/Monetization).
local BONUS_SLOT_LIMIT = 10
-- a280 : jusqu'à la dernière place du 2e étage (DisplaySlot_40, L-277).
local MAX_SLOT_INDEX = math.max(Balance.Display.MaxSlots + BONUS_SLOT_LIMIT, ShopFloor.Slot(ShopGrowth.Floor2.Slots))

-- V0 proposé, absent du doc : bloc de remplacement d'un objet pas encore livré, à la taille d'un
-- objet exposé (environ 1,5 à 2 studs de haut, planche 10.6).
local PLACEHOLDER_SIZE = Vector3.new(1.2, 1.6, 1.2)

-- V0 proposé, absent du doc : billboard de remplacement tant que BB_Item n'est pas livré.
-- Taille en studs (échelle d'un BillboardGui), posé au-dessus du sommet de l'objet.
local BILLBOARD_SIZE = UDim2.fromScale(5, 2.4)
local BILLBOARD_LIFT = 1.4
local BILLBOARD_MAX_DISTANCE = 60
local TEXT_COLOR = Color3.new(1, 1, 1)
local OUTLINE_COLOR = Color3.fromHex("#1B1B24") -- contour du texte, planche 10.6
local INCOME_COLOR = Color3.fromHex("#35C93B") -- vert « acheter / OK », planche 10.6

-- Halo de rareté (5.6) : rendu commun avec CarryService, Shared/RarityHalo (vague 37, a122).

-- Messages lus par le joueur (Notify « Warning ») quand PlaceItem est refusé, en anglais (L-036).
-- Les refus qui ne viennent pas d'un joueur honnête (objet qui n'est pas à lui, profil absent)
-- restent muets.
local MESSAGES: { [string]: string } = {
	NoPlot = "You don't have a shop yet: wait for one to free up.",
	NotOnPlot = "Go back to your shop to display an item.",
	InVault = "This item is in your safe.",
	Held = "This item is being stolen: hit the thief to get it back!",
	NoSlot = "This display doesn't exist.",
	Locked = "This display is locked: upgrade your Display Stands.",
	Taken = "This display is already taken.",
	-- Vague 31 (L-112), V0 proposé, absent du doc : objet sous antivol (au sol de la boutique, ou à y poser).
	AntiTheft = "This item is still under anti-theft: wait until it's UNLOCKED!",
	-- Equip Best (L-089), catégorie « Info » : V0 proposés, absents du doc.
	EquipBest = "Your best items are now on display!",
	EquipBestSame = "Your best items are already on display.",
	-- Vague 63 (a206, L-202 point 4) : DisplayButton d'un objet de la réserve. NoFreeDisplay : le texte de la consigne,
	-- V0 en attendant la règle de Clément ; ReservePlaced : V0, comme InventoryService (MESSAGES.Placed).
	NoFreeDisplay = "No free display",
	ReservePlaced = "%s placed on a display!",
	-- Vague 66 (a219), V0 : présentoirs tous pris, échange (Config/Displayed.SwapWhenFull).
	ReserveSwapped = "%s placed on a display, %s moved to your inventory",
}

local SOURCE_LABELS: { [string]: string } = {
	Pad = "plaque",
	Leave = "départ du joueur",
	Api = "CashOut",
	Auto = "encaissement automatique",
	Offline = "gains hors ligne",
}

type Visual = {
	model: Model,
	uid: string,
	itemId: string,
	income: number,
}

-- Ce qui est affiché sur une parcelle, et pour qui.
type View = {
	owner: Player,
	folder: Folder,
	visuals: { [number]: Visual }, -- [numéro de présentoir]
}

-- Pièces du contrat d'une parcelle, trouvées une fois avant d'y poser des objets.
type PlotRefs = {
	slots: { [number]: Attachment? }, -- nil : présentoir absent de la parcelle
	extra: number, -- présentoirs bonus posés : DisplaySlot_21 à 20 + extra (DEV-100)
	bounds: BasePart?,
	plot: Model, -- a280
	floor: Instance?, -- a280 : Floor_2 où les places d'étage ont été cherchées (nil : pas d'étage)
	floorCount: number, -- a280 : places d'étage posées, DisplaySlot_31 à 30 + floorCount
}

-- Plaque de ramassage CollectPad_xx d'une parcelle (voir l'en-tête).
type Pad = {
	part: BasePart,
	label: TextLabel?, -- AmountGui/Amount, cherché tant qu'il manque
	shown: string?, -- dernier texte écrit
	gui: LayerCollector?, -- AmountGui (BillboardGui ou SurfaceGui), cherché tant qu'il manque
	enabled: boolean?, -- dernier Enabled écrit sur gui
}
-- Plaques connues d'une parcelle, par numéro de présentoir.
type PadSet = {
	bySlot: { [number]: Pad },
	scannedAt: number, -- os.clock() de la dernière recherche
	unlocked: number, -- présentoirs débloqués lors de la dernière recherche
}

-- Argent d'un joueur : revenu courant et plaques.
type Account = {
	plot: Model?,
	income: number, -- $/s des objets exposés, sans bonus
	multiplier: number, -- M global ((1 + GetIncomeBonus) × GetIncomeMultiplier) : les plaques reçoivent income × multiplier
	pending: { [number]: number }, -- $ sur chaque plaque (numéro de présentoir), centimes compris
	lastAccrue: number, -- os.clock() du dernier ajout aux plaques
	collected: number, -- argent encaissé depuis l'arrivée (attribut CashCollected)
	onSlot: number?, -- plaque où se tient le joueur (nil : aucune), déjà ramassée à son arrivée
	padSeenAt: number, -- os.clock() du dernier signe de présence sur onSlot (zone de sortie, Touched)
	padCollectedAt: { [number]: number }, -- os.clock() du dernier ramassage de chaque plaque (PAD_COOLDOWN)
	padWaiting: boolean, -- arrivé sur onSlot pendant son délai : ramassée dès la fin du délai
	shownRegister: number?,
	shownSlots: number?,
	shownFloor: number?, -- a280 : dernier FloorStands écrit
}

local DisplayService = {}

local accounts: { [Player]: Account } = {}
local views: { [Model]: View } = {}
local refsOf: { [Model]: PlotRefs } = {}
local padsOf: { [Model]: PadSet } = {}
-- Plaques dont le Touched est déjà branché (clés faibles : une plaque détruite s'en va seule).
local touchConnected: { [BasePart]: boolean } = setmetatable({}, { __mode = "k" }) :: any
-- Objets tenus par un voleur pendant sa fuite (voir l'en-tête) : [propriétaire][uid] = true.
local held: { [Player]: { [string]: boolean } } = {}
local cashOutListeners: { CashOutListener } = {}
local reported: { [string]: boolean } = {}
local padClock = 0
local refreshClock = 0

------------------------------------------------------------------------------
-- Aides
------------------------------------------------------------------------------

-- Renvoie une fonction qui retire `listener` de `list` (même règle que DataService).
local function subscribe<T>(list: { T }, listener: T): () -> ()
	table.insert(list, listener)
	return function()
		local index = table.find(list, listener)
		if index then
			table.remove(list, index)
		end
	end
end

-- Un message par clé et par serveur : "warn" partout, "print" en Studio seulement.
local function reportOnce(key: string, message: string, level: "print" | "warn")
	if reported[key] then
		return
	end
	reported[key] = true
	if level == "warn" then
		warn(message)
	elseif IS_STUDIO then
		print(message)
	end
end

local function notify(player: Player, message: string, kind: string)
	local ok, err = pcall(function()
		Net.Server.Notify:Fire(player, message, kind)
	end)
	if not ok then
		warn(`[DisplayService] Notify vers {player.Name} : {err}`)
	end
end

------------------------------------------------------------------------------
-- Profil et catalogue
------------------------------------------------------------------------------

-- Points d'accroche de la boutique Robux et de l'index (voir l'en-tête), lus sans laisser une erreur
-- casser la boucle : une valeur invalide compte pour la valeur par défaut.
local function incomeFactor(player: Player): number
	local ok, value = pcall(DisplayService.GetIncomeMultiplier, player)
	if ok and type(value) == "number" and value == value and value > 0 and value < math.huge then
		return value
	end
	reportOnce("hook:GetIncomeMultiplier", `[DisplayService] GetIncomeMultiplier : erreur ou valeur invalide ({value}), revenus × 1`, "warn")
	return 1
end

local function incomeBonus(player: Player): number
	local ok, value = pcall(DisplayService.GetIncomeBonus, player)
	if ok and type(value) == "number" and value == value and value >= 0 and value < math.huge then
		return value
	end
	reportOnce("hook:GetIncomeBonus", `[DisplayService] GetIncomeBonus : erreur ou valeur invalide ({value}), aucun bonus en pour cent`, "warn")
	return 0
end

-- M global (7.1) : les bonus en pour cent s'additionnent, puis les multiplicateurs (Partie 2, 4).
local function incomeMultiplier(player: Player): number
	return (1 + incomeBonus(player)) * incomeFactor(player)
end

local function autoCollect(player: Player): boolean
	local ok, value = pcall(DisplayService.HasAutoCollect, player)
	if ok then
		return value == true
	end
	reportOnce("hook:HasAutoCollect", `[DisplayService] HasAutoCollect : {value}, pas d'encaissement automatique`, "warn")
	return false
end

-- a280 : places du 2e étage ouvertes au propriétaire (0 sans étage dans la parcelle, sans ShopStageService ou avec
-- l'ancienne échelle de boutique, ShopLayout 0).
local function floorStands(data: Data, refs: PlotRefs?): number
	local api = ShopStageService
	if refs == nil or refs.floorCount <= 0 or api == nil then
		return 0
	end
	local ok, value = pcall(api.FloorStands :: any, refs.plot, data.ShopLayout)
	if not ok or type(value) ~= "number" or value ~= value then
		reportOnce("stage:FloorStands", `[DisplayService] ShopStageService.FloorStands : {value}, aucune place d'étage`, "warn")
		return 0
	end
	return math.clamp(math.floor(value), 0, refs.floorCount)
end

-- a280 : niveau Upgrades.DisplaySlots du profil (0 s'il est douteux ; Shared/ShopFloor le borne).
local function standsLevel(data: Data): number
	local level = data.Upgrades.DisplaySlots
	return if type(level) == "number" then level else 0
end

-- Présentoirs de base débloqués (7.5) : StartSlots + niveau Upgrades.DisplaySlots, au plus MaxSlots ; a280 (L-294) : au
-- plus les 8 du bas avec l'étage (Shared/ShopFloor.BaseSlots).
local function baseSlots(data: Data, refs: PlotRefs?): number
	return ShopFloor.BaseSlots(standsLevel(data), floorStands(data, refs))
end

-- a280 : places du 2e étage débloquées (Shared/ShopFloor.Unlocked).
local function floorSlots(data: Data, refs: PlotRefs?): number
	local stands = floorStands(data, refs)
	return if stands > 0 then ShopFloor.Unlocked(standsLevel(data), stands) else 0
end

-- Présentoirs bonus débloqués : GetExtraSlots(player), au plus ceux posés dans la parcelle (`refs`). a280 (L-294
-- point 3) : avec l'étage, seulement une fois l'étage acheté (ils y sont posés).
local function extraSlots(player: Player, data: Data, refs: PlotRefs?): number
	if refs == nil or refs.extra <= 0 then
		return 0
	end
	local stands = floorStands(data, refs)
	if stands > 0 and not ShopFloor.Bought(standsLevel(data), stands) then
		return 0
	end
	local ok, value = pcall(DisplayService.GetExtraSlots, player)
	if not ok or type(value) ~= "number" or value ~= value then
		reportOnce("hook:GetExtraSlots", `[DisplayService] GetExtraSlots : erreur ou valeur invalide ({value}), aucun présentoir bonus`, "warn")
		return 0
	end
	return math.clamp(math.floor(value), 0, refs.extra)
end

-- Le présentoir `index` est-il débloqué ? Ceux de base (1 à baseSlots), puis les présentoirs bonus
-- (MaxSlots + 1 à MaxSlots + extraSlots), puis ceux de l'étage (a280 : 31 à 30 + floorSlots).
local function isUnlocked(player: Player, data: Data, refs: PlotRefs?, index: number): boolean
	if index >= 1 and index <= baseSlots(data, refs) then
		return true
	end
	local first = ShopFloor.Slot(1)
	if index >= first then
		return index < first + floorSlots(data, refs)
	end
	local max = Balance.Display.MaxSlots
	return index > max and index <= max + extraSlots(player, data, refs)
end

local function unlockedCount(player: Player, data: Data, refs: PlotRefs?): number
	return baseSlots(data, refs) + extraSlots(player, data, refs) + floorSlots(data, refs)
end

-- Présentoirs débloqués, dans l'ordre : ceux de base, puis les bonus, puis ceux de l'étage (a280).
local function unlockedList(player: Player, data: Data, refs: PlotRefs?): { number }
	local list: { number } = {}
	for index = 1, baseSlots(data, refs) do
		table.insert(list, index)
	end
	local max = Balance.Display.MaxSlots
	for index = max + 1, max + extraSlots(player, data, refs) do
		table.insert(list, index)
	end
	for n = 1, floorSlots(data, refs) do
		table.insert(list, ShopFloor.Slot(n))
	end
	return list
end

local function isInVault(data: Data, uid: string): boolean
	for _, stored in data.Vault do
		if stored == uid then
			return true
		end
	end
	return false
end

-- Vague 63 (a206) : réserve nettoyée et republiée (définie plus bas, avec la réserve).
local syncReserve: (player: Player, fill: boolean?) -> ()

-- Barre d'inventaire remise à jour tout de suite (en-tête) ; sans InventoryService, sa boucle suit.
-- Vague 63 : la réserve aussi (attribut DisplayReserve).
local function refreshInventory(player: Player)
	syncReserve(player)
	local api = InventoryService
	if api then
		local ok, err = pcall(api.Refresh :: any, player) -- :: any : sinon l'ancien solveur croit que pcall ne renvoie qu'une valeur
		if not ok then
			reportOnce("inventory", `[DisplayService] InventoryService.Refresh : {err}`, "warn")
		end
	end
end

-- Vague 31 (L-112) : objet sous antivol (Items[uid].AntiTheft, UnboxService) : jamais
-- sur un présentoir avant « UNLOCKED! » (voir l'en-tête).
local function isAntiTheft(entry: any): boolean
	return type(entry) == "table" and entry.AntiTheft == true
end

-- L'objet est-il tenu par un voleur (vol en cours, voir l'en-tête) ?
local function isHeld(player: Player, uid: string): boolean
	local byUid = held[player]
	return byUid ~= nil and byUid[uid] == true
end

-- Présentoir où l'objet est exposé, d'après le profil.
local function slotOf(data: Data, uid: string): number?
	for key, stored in data.Display do
		if stored == uid then
			return tonumber(key)
		end
	end
	return nil
end

-- L'objet du profil et sa fiche du catalogue (nil, nil si l'un des deux manque).
local function lookup(data: Data, uid: string): (ItemEntry?, ItemDef?)
	local entry = data.Items[uid]
	if type(entry) ~= "table" then
		return nil, nil
	end
	local def = ItemsConfig.ById[entry.Id]
	if def == nil or Rarities.ById[def.Rarity] == nil then
		return entry, nil
	end
	return entry, def
end

-- Revenu d'un objet ($/s), formule 7.1, mutation comprise (DEV-131 : taille × effet du champ
-- Mutation de Items[uid], 1 sans champ) ; le M global s'applique au total (Account.multiplier).
local function itemIncome(def: ItemDef, entry: ItemEntry, uid: string): number
	return Formulas.ItemIncome(def.Id) * -- vague 76 : rareté, zone et rang de l'objet
		Mutations.IncomeMultiplier(entry.Mutation, entry.Weight) -- vague 62 : poids compris
end

------------------------------------------------------------------------------
-- Réserve (vague 63, a206 ; L-192 Q3, L-202 point 4 ; Config/Displayed)
------------------------------------------------------------------------------

local RESERVE_MAX = DisplayedConfig.ReserveMax
local RESERVE_ATTRIBUTE = DisplayedConfig.ReserveAttribute

-- Vague 66 (a219) : uid de l'objet tenu en main (attribut HeldItem du Player, HeldItemService), nil sinon. Un objet en
-- main n'est pas dans la réserve (L-192 Q3 : retiré à la main = dans la main) ; rangé, il y revient (ReserveCatchAll).
local function inHandOf(player: Player): string?
	local uid = player:GetAttribute(HeldItemConfig.PlayerAttribute)
	return if type(uid) == "string" then uid else nil
end

-- Objets que la réserve peut garder : au joueur, connus du catalogue, ni exposés, ni au coffre-fort, ni sous antivol,
-- ni en main (vague 66).
local function reservable(data: Data, inHand: string?): (uid: string) -> boolean
	local excluded: { [string]: boolean } = {}
	for _, uid in data.Display do
		excluded[uid] = true
	end
	for _, uid in data.Vault do
		excluded[uid] = true
	end
	if inHand then
		excluded[inHand] = true
	end
	return function(uid: string): boolean
		if type(uid) ~= "string" or excluded[uid] then
			return false
		end
		local entry, def = lookup(data, uid)
		return entry ~= nil and def ~= nil and not isAntiTheft(entry)
	end
end

-- La réserve nettoyée (doublons, objets partis, exposés, au coffre-fort, sous antivol, au-delà de RESERVE_MAX
-- retirés), réécrite dans le profil si elle a changé. Sans profil migré (champ absent) : vide, rien d'écrit.
local function cleanReserve(data: Data, inHand: string?): { string }
	local list = data.Reserve
	if type(list) ~= "table" then
		return {}
	end
	local ok = reservable(data, inHand)
	local clean: { string } = {}
	local seen: { [string]: boolean } = {}
	for _, uid in list do
		if #clean < RESERVE_MAX and not seen[uid] and ok(uid) then
			seen[uid] = true
			table.insert(clean, uid)
		end
	end
	local same = #clean == #list
	if same then
		for index, uid in clean do
			if list[index] ~= uid then
				same = false
				break
			end
		end
	end
	if not same then
		data.Reserve = clean
	end
	return clean
end

-- Ajoute l'objet au bout de la réserve. false s'il ne peut pas y aller (pas reservable, déjà dedans, pleine).
local function addToReserve(data: Data, uid: string, inHand: string?): boolean
	local list = cleanReserve(data, inHand)
	if #list >= RESERVE_MAX or table.find(list, uid) ~= nil or not reservable(data, inHand)(uid) then
		return false
	end
	table.insert(list, uid)
	data.Reserve = list
	return true
end

-- Objets que la réserve peut garder et qui n'y sont pas (sauf `skip`), les plus rentables d'abord (puis par uid).
local function missingFromReserve(data: Data, inHand: string?, skip: { [string]: boolean }): { string }
	local ok = reservable(data, inHand)
	type Ranked = { uid: string, income: number }
	local ranked: { Ranked } = {}
	for uid, entry in data.Items do
		if not skip[uid] and ok(uid) then
			local _, def = lookup(data, uid)
			table.insert(ranked, { uid = uid, income = if def then itemIncome(def, entry, uid) else 0 })
		end
	end
	table.sort(ranked, function(a: Ranked, b: Ranked): boolean
		if a.income ~= b.income then
			return a.income > b.income
		end
		return a.uid < b.uid
	end)
	local list: { string } = {}
	for _, item in ranked do
		table.insert(list, item.uid)
	end
	return list
end

-- Profil d'avant la réserve (champ absent) : ses objets ni exposés, ni au coffre-fort, ni sous antivol, ni en main y
-- vont, les plus rentables d'abord (puis par uid), au plus RESERVE_MAX. Rien ne quitte Items. Sans yield.
local function migrateReserve(player: Player, data: Data)
	if data.Reserve ~= nil then
		return
	end
	local list: { string } = {}
	for _, uid in missingFromReserve(data, inHandOf(player), {}) do
		if #list >= RESERVE_MAX then
			break
		end
		table.insert(list, uid)
	end
	data.Reserve = list
	if IS_STUDIO then
		print(`[DisplayService] {player.Name} : réserve créée avec {#list} objet(s) non exposé(s) (profil d'avant la vague 63)`)
	end
end

-- Vague 66 (a219, L-210 point 2, Config/Displayed.ReserveCatchAll) : chaque objet que la réserve peut garder et qui
-- n'y est pas (arrivé après la migration : fin d'antivol les mains prises, objet rangé de la main, volé à un joueur,
-- donné, revenu d'une renaissance…) y entre au bout, les plus rentables d'abord, au plus RESERVE_MAX (pleine : il
-- attend une place, il entre dès qu'un objet en sort). Seulement depuis la boucle d'une seconde et au chargement,
-- jamais pendant un retrait (InventoryService : main, puis AddToReserve, dans la même exécution). Sans yield.
local function fillReserve(player: Player, data: Data)
	if DisplayedConfig.ReserveCatchAll ~= true or type(data.Reserve) ~= "table" then
		return
	end
	local inHand = inHandOf(player)
	local list = cleanReserve(data, inHand)
	if #list >= RESERVE_MAX then
		return
	end
	local seen: { [string]: boolean } = {}
	for _, uid in list do
		seen[uid] = true
	end
	local added = 0
	for _, uid in missingFromReserve(data, inHand, seen) do
		if #list >= RESERVE_MAX then
			break
		end
		table.insert(list, uid)
		added += 1
	end
	if added > 0 then
		data.Reserve = list
		if IS_STUDIO then
			print(`[DisplayService] {player.Name} : {added} objet(s) non exposé(s) ajouté(s) à la réserve`)
		end
	end
end

-- Attribut DisplayReserve du Player : les uids de la réserve, dans l'ordre, séparés par « , » (lu par
-- DisplayedController avec l'état de l'inventaire). Écrit seulement s'il change. Sans yield. `fill` (vague 66) :
-- d'abord les objets qui manquent (fillReserve).
syncReserve = function(player: Player, fill: boolean?)
	local data = DataService.Get(player)
	if data == nil or player.Parent ~= Players then
		return
	end
	if fill then
		fillReserve(player, data)
	end
	local shown: { string } = {}
	for _, uid in cleanReserve(data, inHandOf(player)) do
		if InventoryState.IsSafeId(uid) then
			table.insert(shown, uid)
		end
	end
	local text = table.concat(shown, ",")
	if player:GetAttribute(RESERVE_ATTRIBUTE) ~= text then
		player:SetAttribute(RESERVE_ATTRIBUTE, text)
	end
end

------------------------------------------------------------------------------
-- Parcelle
------------------------------------------------------------------------------

-- Présentoirs et volume de la parcelle. Cherchés une seule fois, avant que ce
-- service y pose des objets (dont les pièces pourraient porter les mêmes noms).
-- Présentoirs bonus (gamepass « +4 présentoirs », DEV-100) : DisplaySlot_21 et suivants, à la suite, optionnels (aucun
-- avertissement s'ils manquent). a280 (L-294 point 3) : cherchés aussi dans le Floor_2 (rangé hors de la parcelle tant
-- que l'étage n'est pas montré), de nouveau quand il change.
local function scanBonus(plot: Model, refs: PlotRefs)
	local max = Balance.Display.MaxSlots
	for index = max + 1, max + BONUS_SLOT_LIMIT do
		refs.slots[index] = nil
	end
	local extra = 0
	while extra < BONUS_SLOT_LIMIT do
		local index = max + extra + 1
		local name = string.format(SLOT_FORMAT, index)
		local found = Find.path(plot, name)
		local floor = refs.floor
		if (found == nil or not found:IsA("Attachment")) and floor then
			found = floor:FindFirstChild(name, true)
		end
		if found == nil or not found:IsA("Attachment") then
			break
		end
		refs.slots[index] = found :: Attachment
		extra += 1
	end
	refs.extra = extra
end

-- a280 : places du 2e étage cherchées dans le Floor_2 de la parcelle (copié du gabarit au besoin), de nouveau tant
-- qu'il manque ou s'il a changé (un Floor_2 retiré : ses places partent avec lui), et les présentoirs bonus avec elles.
local function syncFloor(plot: Model, refs: PlotRefs)
	local api = ShopStageService
	local floor = if api then api.EnsureFloor(plot) else nil
	if floor == refs.floor and (floor == nil or floor.Parent ~= nil) then
		return
	end
	for n = 1, ShopGrowth.Floor2.Slots do
		refs.slots[ShopFloor.Slot(n)] = nil
	end
	refs.floor, refs.floorCount = floor, 0
	if floor and api then
		local found, count = api.FloorSlots(floor)
		for index, slot in found do
			refs.slots[index] = slot
		end
		refs.floorCount = count
	end
	scanBonus(plot, refs)
end

local function refsFor(plot: Model): PlotRefs
	local cached = refsOf[plot]
	if cached then
		syncFloor(plot, cached)
		return cached
	end

	local slots: { [number]: Attachment? } = {}
	local missing: { number } = {}
	for index = 1, Balance.Display.MaxSlots do
		local found = Find.path(plot, string.format(SLOT_FORMAT, index))
		if found ~= nil and found:IsA("Attachment") then
			slots[index] = found :: Attachment
		else
			table.insert(missing, index)
		end
	end

	local bounds = Find.path(plot, BOUNDS)
	local refs: PlotRefs = {
		slots = slots,
		extra = 0,
		bounds = if bounds ~= nil and bounds:IsA("BasePart") then bounds :: BasePart else nil,
		plot = plot,
		floor = nil,
		floorCount = 0,
	}
	syncFloor(plot, refs)
	if refs.floor == nil then
		scanBonus(plot, refs) -- sans étage : syncFloor n'a rien cherché
	end
	-- a280 (L-294) : avec un étage, seuls les 8 présentoirs du bas sont attendus (9 à 20 : ancien gabarit, facultatifs).
	local expected = if refs.floorCount > 0 then ShopGrowth.Floor2.GroundSlots else Balance.Display.MaxSlots
	local names: { string } = {}
	for _, index in missing do
		if index <= expected then
			table.insert(names, string.format(SLOT_FORMAT, index))
		end
	end
	if #names > 0 then
		warn(
			`[DisplayService] {plot:GetFullName()} : {#names} présentoir(s) absent(s) ou qui ne sont pas des Attachments (contrat 10.4) : {table.concat(names, ", ")}`
		)
	end
	refsOf[plot] = refs
	return refs
end

-- HumanoidRootPart d'un personnage vivant, ou nil.
local function rootOf(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil
	end
	return root :: BasePart
end

local function isInsidePart(part: BasePart, position: Vector3): boolean
	local p = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z
end

-- Le joueur est-il dans sa parcelle ? Volume Bounds (10.4), sinon emprise de la parcelle.
local function isOnPlot(player: Player, plot: Model, refs: PlotRefs): boolean
	local root = rootOf(player)
	if root == nil then
		return false
	end
	local bounds = refs.bounds
	if bounds then
		return isInsidePart(bounds, root.Position)
	end
	local boxCFrame, boxSize = plot:GetBoundingBox()
	local p = boxCFrame:PointToObjectSpace(root.Position)
	return math.abs(p.X) <= boxSize.X / 2 and math.abs(p.Z) <= boxSize.Z / 2
end

-- `position` dans le volume de la plaque élargi de `margin` sur les côtés, jusqu'à `above` au-dessus.
-- La hauteur se lit sur l'axe de la plaque le plus tourné vers le ciel : Clément pose ses plaques à plat avec
-- l'épaisseur sur Y ou sur Z (plaques carrées tournées vers la porte, L-091), dans un sens ou dans l'autre.
local function isOnPad(position: Vector3, pad: BasePart, margin: number?, above: number?): boolean
	local side = margin or PAD_MARGIN
	local cf = pad.CFrame
	local p = cf:PointToObjectSpace(position)
	local half = pad.Size / 2
	-- Le haut du monde vu dans le repère de la plaque : composante verticale de ses axes X, Y et Z.
	local up = cf:PointToObjectSpace(cf.Position + Vector3.new(0, 1, 0))
	local ups = { up.X, up.Y, up.Z }
	local coords = { p.X, p.Y, p.Z }
	local halves = { half.X, half.Y, half.Z }
	local axis = 1
	for i = 2, 3 do
		if math.abs(ups[i]) > math.abs(ups[axis]) then
			axis = i
		end
	end
	for i = 1, 3 do
		if i ~= axis and math.abs(coords[i]) > halves[i] + side then
			return false
		end
	end
	local height = if ups[axis] >= 0 then coords[axis] else -coords[axis]
	return height >= halves[axis] - PAD_BELOW and height <= halves[axis] + (above or PAD_ABOVE)
end

-- `position` encore dans la zone de sortie de la plaque (voir l'en-tête).
local function isNearPad(position: Vector3, pad: BasePart): boolean
	return isOnPad(position, pad, PAD_EXIT_MARGIN, PAD_EXIT_ABOVE)
end

------------------------------------------------------------------------------
-- Plaques de ramassage CollectPad_xx (voir l'en-tête)
------------------------------------------------------------------------------

-- Numéro de présentoir d'une plaque (BasePart CollectPad_xx), nil sinon.
local function padSlotOf(inst: Instance): number?
	if not inst:IsA("BasePart") then
		return nil
	end
	local digits = string.match(inst.Name, COLLECT_PAD_PATTERN)
	local slot = if digits then tonumber(digits) else nil
	if slot and slot >= 1 and slot <= MAX_SLOT_INDEX then
		return slot
	end
	return nil
end

-- Ramassage au Touched d'une plaque (défini plus bas, avec l'encaissement).
local onPadTouched: (plot: Model, slot: number, part: BasePart, hit: BasePart) -> ()

-- Cherche toutes les plaques de la parcelle et branche leur Touched (une fois par plaque).
local function scanPads(plot: Model, unlocked: number): PadSet
	local old = padsOf[plot]
	local bySlot: { [number]: Pad } = {}
	for _, descendant in plot:GetDescendants() do
		local slot = padSlotOf(descendant)
		if slot and bySlot[slot] == nil then
			local part = descendant :: BasePart
			local previous = if old then old.bySlot[slot] else nil
			-- La même plaque garde son texte déjà écrit (pas de réécriture pour rien).
			bySlot[slot] = if previous and previous.part == part then previous else { part = part, label = nil, shown = nil, gui = nil, enabled = nil }
			if not touchConnected[part] then
				touchConnected[part] = true
				part.Touched:Connect(function(hit: BasePart)
					onPadTouched(plot, slot, part, hit)
				end)
			end
		end
	end
	local set: PadSet = { bySlot = bySlot, scannedAt = os.clock(), unlocked = unlocked }
	padsOf[plot] = set
	return set
end

-- Plaques de la parcelle, cherchées de nouveau si besoin (voir l'en-tête). `unlocked` = présentoirs
-- débloqués de son propriétaire.
local function padsFor(plot: Model, unlocked: number): PadSet
	local set = padsOf[plot]
	if set == nil or set.unlocked ~= unlocked then
		return scanPads(plot, unlocked)
	end
	for _, pad in set.bySlot do
		if pad.part.Parent == nil then
			return scanPads(plot, unlocked) -- rayon retiré, plaque détruite
		end
	end
	if os.clock() - set.scannedAt >= PAD_RESCAN_INTERVAL then
		for slot = 1, math.min(unlocked, Balance.Display.MaxSlots) do
			if set.bySlot[slot] == nil then
				return scanPads(plot, unlocked) -- rayon peut-être posé depuis
			end
		end
	end
	return set
end

-- Plaque qui reçoit l'argent du présentoir `slot` : la sienne, sinon celle au plus petit numéro,
-- sinon le présentoir lui-même (aucune plaque : l'argent attend le départ du joueur).
local function padSlotFor(set: PadSet?, slot: number): number
	if set == nil or set.bySlot[slot] ~= nil then
		return slot
	end
	local lowest: number? = nil
	for index in set.bySlot do
		if lowest == nil or index < lowest then
			lowest = index
		end
	end
	return lowest or slot
end

-- Plaque sous `position`, nil s'il n'y en a pas.
local function padAt(set: PadSet, position: Vector3): number?
	for slot, pad in set.bySlot do
		if pad.part.Parent ~= nil and isOnPad(position, pad.part) then
			return slot
		end
	end
	return nil
end

------------------------------------------------------------------------------
-- Objet exposé : modèle, halo, billboard
------------------------------------------------------------------------------

local function itemTemplate(def: ItemDef): Instance?
	local assets = ReplicatedStorage:FindFirstChild(ASSETS)
	local folder = if assets then assets:FindFirstChild(ITEMS_FOLDER) else nil
	if folder == nil then
		return nil
	end
	return folder:FindFirstChild(def.Asset, true)
end

local function billboardTemplate(): BillboardGui?
	local current: Instance? = ReplicatedStorage
	for _, name in UI.BillboardFolder do
		current = if current then current:FindFirstChild(name) else nil
	end
	local found = if current then current:FindFirstChild(ITEM_BILLBOARD) else nil
	if found ~= nil and found:IsA("BillboardGui") then
		return found :: BillboardGui
	end
	return nil
end

local function placeholderModel(rarity: Rarity): Model
	local model = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = PLACEHOLDER_SIZE
	root.Color = rarity.Color
	root.Material = Enum.Material.SmoothPlastic
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	-- Pivot en bas au centre, comme un objet de Clément (10.4).
	root.PivotOffset = CFrame.new(0, -PLACEHOLDER_SIZE.Y / 2, 0)
	root.Parent = model
	model.PrimaryPart = root
	return model
end

-- Copie du modèle ITM_ de Clément, ancrée et sans script ; nil si l'objet n'est pas livré.
local function copyOfTemplate(def: ItemDef): Model?
	local template = itemTemplate(def)
	if template == nil then
		reportOnce(
			`model:{def.Asset}`,
			`[DisplayService] {def.Asset} pas encore livré dans ReplicatedStorage/{ASSETS}/{ITEMS_FOLDER} : bloc V0 à la couleur de sa rareté`,
			"print"
		)
		return nil
	end
	local copy = template:Clone() :: Instance?
	local model: Model? = nil
	if copy ~= nil and copy:IsA("Model") then
		model = copy :: Model
	elseif copy ~= nil and copy:IsA("BasePart") then
		local wrapper = Instance.new("Model")
		copy.Parent = wrapper
		wrapper.PrimaryPart = copy :: BasePart
		model = wrapper
	elseif copy ~= nil then
		copy:Destroy()
	end
	if model == nil then
		reportOnce(
			`bad:{def.Asset}`,
			`[DisplayService] {template:GetFullName()} : ni un Model ni une pièce, ou non copiable (Archivable) ; contrat 10.4 : Model avec PrimaryPart Root. Bloc V0 à la place`,
			"warn"
		)
		return nil
	end
	local scripts = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			scripts += 1
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			part.Anchored = true
		end
	end
	if scripts > 0 then
		reportOnce(
			`scripts:{def.Asset}`,
			`[DisplayService] {template:GetFullName()} : {scripts} script(s) retiré(s) de la copie exposée (10.4 : aucun script dans un objet ITM_)`,
			"warn"
		)
	end
	return model
end

local function makeBillboard(): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = ITEM_BILLBOARD
	gui.Size = BILLBOARD_SIZE
	gui.StudsOffset = Vector3.new(0, BILLBOARD_LIFT, 0)
	gui.MaxDistance = BILLBOARD_MAX_DISTANCE
	gui.LightInfluence = 0
	for i, name in BILLBOARD_FIELDS do
		local label = Instance.new("TextLabel")
		label.Name = name
		label.Size = UDim2.fromScale(1, 1 / #BILLBOARD_FIELDS)
		label.Position = UDim2.fromScale(0, (i - 1) / #BILLBOARD_FIELDS)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
		label.TextColor3 = if name == "Income" then INCOME_COLOR else TEXT_COLOR
		label.TextStrokeColor3 = OUTLINE_COLOR
		label.TextStrokeTransparency = 0
		label.Text = ""
		label.Parent = gui
	end
	return gui
end

-- Écrit `text` dans l'élément texte `name` du billboard ; renvoie l'élément, nil s'il manque.
local function setText(gui: Instance, name: string, text: string, color: Color3?): GuiObject?
	local element = Find.path(gui, name)
	if element == nil or not (element:IsA("TextLabel") or element:IsA("TextButton") or element:IsA("TextBox")) then
		return nil
	end
	local textElement = element :: any
	textElement.Text = text
	if color then
		textElement.TextColor3 = color
	end
	return element :: GuiObject
end

-- a234 (L-216 point 2, L-217) : boîte FitSize d'un présentoir (Vector3, studs, repère de l'Attachment), ou nil si
-- elle manque ou n'est pas lisible (trois côtés > 0, finis).
local function fitSizeOf(slot: Attachment): Vector3?
	local value = slot:GetAttribute(Attributes.FitSize.Name)
	if typeof(value) ~= "Vector3" then
		return nil
	end
	local size = value :: Vector3
	local smallest, largest = math.min(size.X, size.Y, size.Z), math.max(size.X, size.Y, size.Z)
	if not (smallest > 0 and largest < math.huge) then
		return nil -- aussi NaN
	end
	return size
end

-- Coins d'une pièce (demi-taille × signe), pour fitFactor.
local CORNERS = {
	Vector3.new(1, 1, 1),
	Vector3.new(1, 1, -1),
	Vector3.new(1, -1, 1),
	Vector3.new(1, -1, -1),
	Vector3.new(-1, 1, 1),
	Vector3.new(-1, 1, -1),
	Vector3.new(-1, -1, 1),
	Vector3.new(-1, -1, -1),
}

-- Facteur (au plus 1) qui fait tenir `model`, déjà posé en `pivot`, dans la boîte `fit` du repère de `pivot` :
-- centrée sur le pivot en X et Z, de 0 à fit.Y en hauteur. Pièces visibles seulement (Transparency < 1 : une boîte de
-- collision invisible ne compte pas). Un objet qui tourne sur lui-même (attribut Idle Spin ou SpinBob,
-- ItemIdleController) doit tenir en tournant : son rayon horizontal, dans le plus petit côté de la boîte.
local function fitFactor(model: Model, pivot: CFrame, fit: Vector3): number
	local idle = model:GetAttribute(Attributes.Idle.Name)
	local spins = idle == "Spin" or idle == "SpinBob"
	local maxX, maxY, maxZ, maxRadius = 0, 0, 0, 0
	local seen = false
	for _, d in model:GetDescendants() do
		if not d:IsA("BasePart") or (d :: BasePart).Transparency >= 1 then
			continue
		end
		local part = d :: BasePart
		local half = part.Size / 2
		for _, corner in CORNERS do
			local p = pivot:PointToObjectSpace(part.CFrame * (half * corner))
			maxX = math.max(maxX, math.abs(p.X))
			maxY = math.max(maxY, p.Y)
			maxZ = math.max(maxZ, math.abs(p.Z))
			maxRadius = math.max(maxRadius, math.sqrt(p.X * p.X + p.Z * p.Z))
		end
		seen = true
	end
	if not seen then
		return 1
	end
	local factor = 1
	local function limit(extent: number, room: number)
		if extent > room and extent > 0 then
			factor = math.min(factor, room / extent)
		end
	end
	if spins then
		limit(maxRadius, math.min(fit.X, fit.Z) / 2)
	else
		limit(maxX, fit.X / 2)
		limit(maxZ, fit.Z / 2)
	end
	limit(maxY, fit.Y)
	return factor
end

-- a234 : portée de chaque lumière du modèle (PointLight, SpotLight, SurfaceLight) avant sa mise à l'échelle.
local function lightRanges(model: Model): { [Light]: number }
	local ranges: { [Light]: number } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
			ranges[d :: Light] = (d :: any).Range
		end
	end
	return ranges
end

-- a234 : après la réduction FitSize, la portée d'une lumière ne dépasse pas sa portée d'origine × la taille montrée
-- (ScaleTo ne la réduit pas toujours) ; elle n'est jamais agrandie ici.
local function trimLights(ranges: { [Light]: number }, factor: number)
	for light, range in ranges do
		local current = (light :: any).Range :: number
		local wanted = range * factor
		if light.Parent ~= nil and wanted < current then
			(light :: any).Range = wanted
		end
	end
end

-- Billboard visible par tous : nom, rareté (couleur), $/s (5.8). BB_Item de Clément : accroché au
-- pied de l'objet (son pivot, en bas au centre, posé sur le présentoir, 10.1), car Clément règle
-- son StudsOffset depuis la base (liaison L-027). Billboard V0 : accroché au sommet.
local function addBillboard(
	model: Model,
	def: ItemDef,
	rarity: Rarity,
	income: number,
	boxCFrame: CFrame,
	boxSize: Vector3,
	mutation: Mutations.Mutation?,
	weight: number?, -- vague 62 (a203) : poids de l'objet (kg), écrit dans Weight s'il existe
	fit: number -- a234 : réduction FitSize (1 = aucune)
)
	local anchor = model.PrimaryPart or (model:FindFirstChildWhichIsA("BasePart", true) :: BasePart?)
	if anchor == nil then
		return
	end
	local template = billboardTemplate()
	local gui: BillboardGui? = if template then template:Clone() :: BillboardGui? else nil
	local point = Instance.new("Attachment")
	point.Name = BILLBOARD_POINT
	point.Parent = anchor
	-- Mutation de taille (DEV-131) : BB_Item de Clément monte (ou descend) de ce que l'objet a gagné en
	-- hauteur, pour garder le même écart au-dessus de lui (V0 proposé). Le V0 suit déjà le sommet.
	local scale = Mutations.Scale(mutation, weight) * fit
	local lift = boxSize.Y - boxSize.Y / scale
	local top = boxCFrame.Position + Vector3.new(0, boxSize.Y / 2, 0)
	-- a317 (L-304 point 3, validé par Clément) : BB_Item de Clément accroché au sommet de la boîte de l'objet,
	-- DisplayMotion.BillboardTopOffset plus bas (le bas de l'étiquette touche presque l'objet), StudsOffset posé plus
	-- bas ; ItemIdleController le fait suivre le flottement. Sans DisplayMotion : au pied, comme avant (L-027).
	local atTop = gui ~= nil and FLOAT and DisplayMotion.BillboardAtTop == true
	point.WorldPosition = if atTop
		then top + Vector3.new(0, DisplayMotion.BillboardTopOffset, 0)
		elseif gui then (model:GetPivot() * CFrame.new(0, lift, 0)).Position
		else top
	if atTop and gui then
		gui.StudsOffset = Vector3.new(0, DisplayMotion.BillboardStudsOffset, 0)
	end

	if gui == nil then
		reportOnce(
			"billboard",
			`[DisplayService] {ITEM_BILLBOARD} pas encore livré dans ReplicatedStorage/{table.concat(UI.BillboardFolder, "/")} : billboard V0 au-dessus des objets exposés`,
			"print"
		)
		gui = makeBillboard()
	end
	local billboard = gui :: BillboardGui
	billboard.Name = ITEM_BILLBOARD
	billboard.Adornee = point

	-- Mutation (DEV-131) : devant le nom (« Big Gold Soda Can ») ; si Clément ajoute un texte
	-- Mutation à BB_Item (nom proposé, hors contrat pour l'instant), elle y va en capitales
	-- (« BIG · GOLD », caché sans mutation) et ItemName garde le nom seul.
	local mutationField = Find.path(billboard, MUTATION_FIELD)
	if mutationField ~= nil and mutationField:IsA("GuiObject") then
		local mutationLabel = mutationField :: GuiObject
		local text = Mutations.Label(mutation)
		setText(billboard, "ItemName", def.DisplayName)
		setText(billboard, MUTATION_FIELD, text or "")
		mutationLabel.Visible = text ~= nil
	else
		setText(billboard, "ItemName", Mutations.ItemName(def.DisplayName, mutation))
	end
	setText(billboard, "Income", Format.income(income))
	-- Vague 62 (a203) : poids « 1,250 kg » dans l'élément facultatif Weight de BB_Item (nom proposé à Clément) ; rien sans lui.
	-- a317 (L-304 Q1, décision de Cantin du 23/11, « Oui, afficher ») : Clément cache Weight par défaut ; il est montré
	-- avec le vrai poids, en capitales comme sur son étiquette (« 20 KG », ItemWeight.Format sans autre formule), et
	-- reste caché sans poids (ou sans ItemWeight).
	local weightField = Find.path(billboard, WeightConfig.Field)
	if ItemWeight.Enabled() and type(weight) == "number" then
		setText(billboard, WeightConfig.Field, string.upper(ItemWeight.Format(weight)))
		if weightField ~= nil and weightField:IsA("GuiObject") then
			(weightField :: GuiObject).Visible = true
		end
	elseif weightField ~= nil and weightField:IsA("GuiObject") then
		(weightField :: GuiObject).Visible = false
	end
	local rarityLabel = setText(billboard, "Rarity", rarity.DisplayNameUpper, if rarity.Rainbow then TEXT_COLOR else rarity.Color)
	-- Secret : arc-en-ciel (DisplayController le fait tourner). Un dégradé déjà posé par Clément
	-- sur ce texte est gardé.
	if rarity.Rainbow and rarityLabel and rarityLabel:FindFirstChildOfClass("UIGradient") == nil then
		local gradient = Instance.new("UIGradient")
		gradient.Name = RAINBOW_GRADIENT
		gradient.Color = RarityHalo.Sequence(RarityHalo.Colors(rarity))
		gradient.Parent = rarityLabel
	end
	billboard.Parent = model
end

-- Construit l'objet exposé sur le présentoir `slot`, prêt à être rangé dans la parcelle.
-- Modèle de l'objet (copie d'ITM_ ou bloc V0, mutation de taille, halo, BB_Item si `billboard`), pivot posé
-- en `pivot`, avec les attributs communs (ItemUid, ItemId, Rarity, Halo, Income, OwnerUserId, Placeholder,
-- mutation). Sans tag ni DisplaySlot : à l'appelant. Renvoie le modèle et son revenu.
-- a234 : `fitSize` (FitSize du présentoir, fitSizeOf) : boîte où l'objet doit tenir ; nil = la taille de son poids.
local function buildItemModel(
	ownerUserId: number,
	pivot: CFrame,
	name: string,
	uid: string,
	entry: ItemEntry,
	def: ItemDef,
	billboard: boolean,
	fitSize: Vector3?
): (Model, number)
	local rarity = Rarities.ById[def.Rarity]
	local income = itemIncome(def, entry, uid)
	local model = copyOfTemplate(def)
	local placeholder = model == nil
	local display = model or placeholderModel(rarity)
	display.Name = name
	-- Arrive en entier chez les clients (StreamingEnabled) : ItemIdleController y lit la position de
	-- repos de toutes les pièces avant de les animer (L-045).
	display.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	-- Mutation de taille (DEV-131) : le modèle change vraiment d'échelle autour de son pivot (en bas
	-- au centre, 10.1 : il reste posé sur le présentoir), avant le halo et le billboard qui suivent
	-- sa nouvelle taille. Échec (modèle sans pièce ?) : taille normale, signalé une fois.
	local mutation = Mutations.Sanitize(entry.Mutation)
	-- Vague 62 (a203) : poids de l'objet (Items[uid].Weight ; absent : celui de son ancienne taille, ItemWeight.Effective).
	local rawMutation = entry.Mutation
	local weight = ItemWeight.Effective(entry.Weight, if rawMutation then rawMutation.Size else nil)
	local scale = Mutations.Scale(mutation, weight)
	-- a234 : échelle et portées d'avant toute mise à l'échelle, seulement s'il faudra peut-être réduire
	local baseScale = if fitSize then display:GetScale() else 1
	local ranges = if fitSize then lightRanges(display) else nil
	if scale ~= 1 then
		local ok, problem = pcall(display.ScaleTo, display, scale)
		if not ok then
			reportOnce(`scale:{uid}`, `[DisplayService] {def.Id} ({uid}) : Model:ScaleTo({scale}) a échoué ({problem}), taille normale`, "warn")
		end
	end
	display:PivotTo(pivot)
	-- a234 (L-216 point 2, L-217, L-220) : sur un présentoir qui a FitSize, seulement l'échelle d'affichage est réduite
	-- pour que l'objet y tienne (jamais grossi) ; poids, revenu et étiquette inchangés. Le halo et le billboard, posés
	-- ensuite, suivent la taille montrée ; les lumières du modèle aussi (portée au plus proportionnelle à la taille).
	-- Attribut FitScale (Config/Weight.FitScaleAttribute) : la réduction, lue par le socle « BEST ITEM » (vraie taille).
	-- a317 (L-304 Q2, validé par Cantin le 23/11) : la hauteur du flottement et du saut (DisplayMotion.Headroom, plus
	-- ItemIdle.BobHeight pour un Idle Bob ou SpinBob) est retirée de la hauteur du FitSize lu sur le présentoir, quelle
	-- que soit la courbe d'échelle : l'objet le plus haut ne touche jamais le plancher de l'étage. Rien sans FitSize.
	local fitBox = fitSize
	if fitBox and FLOAT then
		local idle = display:GetAttribute(Attributes.Idle.Name)
		local bob = if (idle == "Bob" or idle == "SpinBob") and ItemIdleConfig then ItemIdleConfig.BobHeight else 0
		local room = fitBox.Y - DisplayMotion.Headroom - bob
		if room > 0 then
			fitBox = Vector3.new(fitBox.X, room, fitBox.Z)
		end
	end
	local fit = if fitBox then fitFactor(display, pivot, fitBox) else 1
	if fit < 1 then
		local shown = display:GetScale() * fit
		local ok, problem = pcall(display.ScaleTo, display, shown)
		if ok then
			display:PivotTo(pivot)
			if ranges then
				trimLights(ranges, shown / baseScale)
			end
			display:SetAttribute(WeightConfig.FitScaleAttribute, fit)
		else
			fit = 1
			reportOnce(`fit:{uid}`, `[DisplayService] {def.Id} ({uid}) : Model:ScaleTo({shown}) pour FitSize a échoué ({problem}), taille de son poids`, "warn")
		end
	end

	local boxCFrame, boxSize = display:GetBoundingBox()
	RarityHalo.AddDisplayed(display, rarity, boxCFrame, boxSize)
	if billboard then
		addBillboard(display, def, rarity, income, boxCFrame, boxSize, mutation, weight, fit)
	end

	display:SetAttribute("ItemUid", uid)
	display:SetAttribute("ItemId", def.Id)
	display:SetAttribute("Rarity", def.Rarity)
	display:SetAttribute("Halo", rarity.Halo)
	display:SetAttribute("Income", income)
	display:SetAttribute("OwnerUserId", ownerUserId)
	display:SetAttribute("Placeholder", placeholder)
	-- Mutation (DEV-131) : Id de Config/Mutations, absents sans mutation dans la famille. Les effets
	-- visuels sont à Clément (MOD-131) : le code n'en pose aucun.
	display:SetAttribute(MUTATION_SIZE_ATTRIBUTE, if mutation then mutation.Size else nil)
	display:SetAttribute(MUTATION_EFFECT_ATTRIBUTE, if mutation then mutation.Effect else nil)
	-- Vague 62 (a203) : poids (kg) lu par les contrôleurs (deux mains, socle « BEST ITEM »), absent sans le poids.
	display:SetAttribute(WeightConfig.Attribute, if ItemWeight.Enabled() then weight else nil)
	return display, income
end

local function buildVisual(ownerUserId: number, refs: PlotRefs, slot: number, uid: string, entry: ItemEntry, def: ItemDef): Visual
	-- présentoir vérifié par sanitize
	local attachment = refs.slots[slot] :: Attachment
	local pivot = attachment.WorldCFrame
	local display, income = buildItemModel(ownerUserId, pivot, string.format(MODEL_FORMAT, slot), uid, entry, def, true, fitSizeOf(attachment))
	display:SetAttribute("DisplaySlot", slot)
	CollectionService:AddTag(display, DISPLAY_TAG)
	return { model = display, uid = uid, itemId = def.Id, income = income }
end

------------------------------------------------------------------------------
-- Caisse
------------------------------------------------------------------------------

-- Ajoute aux plaques ce que les objets ont rapporté depuis le dernier ajout (M global compris) :
-- l'argent de chaque objet exposé va sur la plaque de son présentoir (padSlotFor). À appeler avant
-- tout changement des objets affichés ou du revenu.
local function accrue(account: Account, now: number)
	local elapsed = now - account.lastAccrue
	account.lastAccrue = now
	local plot = account.plot
	local view = if plot then views[plot] else nil
	if elapsed <= 0 or plot == nil or view == nil then
		return
	end
	local set = padsOf[plot]
	local factor = account.multiplier * elapsed
	for slot, visual in view.visuals do
		if visual.income > 0 then
			local target = padSlotFor(set, slot)
			account.pending[target] = (account.pending[target] or 0) + visual.income * factor
		end
	end
end

-- Argent de toutes les plaques, centimes compris.
local function pendingTotal(account: Account): number
	local total = 0
	for _, amount in account.pending do
		total += amount
	end
	return total
end

-- Écrit le montant de chaque plaque dans son AmountGui/Amount (dollars entiers, Format.money),
-- seulement s'il a changé. `account` nil : parcelle libre, toutes les plaques à $0.
local function showPads(set: PadSet, account: Account?)
	for slot, pad in set.bySlot do
		local label = pad.label
		if label == nil or label.Parent == nil then
			local found = Find.path(pad.part, AMOUNT_PATH)
			label = if found ~= nil and found:IsA("TextLabel") then found :: TextLabel else nil
			pad.label = label
			pad.shown = nil
		end
		local amount = if account then math.floor(account.pending[slot] or 0) else 0
		if label then
			local text = Format.money(amount)
			if text ~= pad.shown then
				pad.shown = text
				label.Text = text
			end
		end
		-- L-107 point 1 : AmountGui caché quand la plaque porte moins de $1 (voir l'en-tête).
		local gui = pad.gui
		if gui == nil or gui.Parent == nil then
			local found = Find.path(pad.part, AMOUNT_GUI)
			gui = if found ~= nil and found:IsA("LayerCollector") then found :: LayerCollector else nil
			pad.gui = gui
			pad.enabled = nil
		end
		if gui then
			local enabled = amount >= 1
			if enabled ~= pad.enabled then
				pad.enabled = enabled
				gui.Enabled = enabled
			end
		end
	end
end

-- Met à jour les montants des plaques, les attributs CashRegister (parcelle) et DisplaySlotsUnlocked
-- (joueur) s'ils changent. Avec `data`, les plaques sont cherchées de nouveau si besoin (padsFor).
local function publish(player: Player, account: Account, data: Data?)
	local plot = account.plot
	local slots = if data then unlockedCount(player, data, if plot then refsFor(plot) else nil) else nil
	if plot then
		local set = if slots then padsFor(plot, slots) else padsOf[plot]
		if set then
			showPads(set, account)
		end
		local shown = math.floor(pendingTotal(account))
		if shown ~= account.shownRegister then
			account.shownRegister = shown
			plot:SetAttribute(REGISTER_ATTRIBUTE, shown)
		end
	end
	-- a280 : places du 2e étage ouvertes (UpgradeController, ShopService).
	local stands = if data and plot then floorStands(data, refsFor(plot)) else nil
	if stands and stands ~= account.shownFloor then
		account.shownFloor = stands
		player:SetAttribute(FLOOR_STANDS_ATTRIBUTE, stands)
	end
	if slots and slots ~= account.shownSlots then
		account.shownSlots = slots
		player:SetAttribute(SLOTS_ATTRIBUTE, slots)
	end
end

-- Verse `amount` $ (entier ≥ 1) dans l'argent du joueur et prévient les écouteurs ; false si le
-- profil est absent (rien n'est versé). Sans yield.
local function pay(player: Player, account: Account, amount: number, source: CashOutSource): boolean
	local cash = DataService.AddCash(player, amount)
	if cash == nil then
		return false
	end
	account.collected += amount
	player:SetAttribute(COLLECTED_ATTRIBUTE, account.collected)
	if IS_STUDIO and source ~= "Auto" then -- l'encaissement automatique, chaque seconde, resterait muet
		print(`[DisplayService] {player.Name} encaisse {Format.money(amount)} ({SOURCE_LABELS[source]}) : {Format.money(cash)} en tout`)
	end
	for _, listener in table.clone(cashOutListeners) do
		task.spawn(listener, player, amount, source)
	end
	return true
end

-- Vide la plaque `slot` (nil : toutes) dans l'argent du joueur : dollars entiers, les centimes
-- restent sur chaque plaque. Ramassage sur une plaque (source « Pad ») : remote CashCollect vers
-- tous les clients. Renvoie le montant. Sans yield.
local function cashOut(player: Player, account: Account, source: CashOutSource, slot: number?): number
	accrue(account, os.clock())
	local taken: { [number]: number } = {}
	local amount = 0
	for index, value in account.pending do
		if slot == nil or index == slot then
			local whole = math.floor(value)
			if whole >= 1 then
				taken[index] = whole
				amount += whole
			end
		end
	end
	if amount < 1 or not pay(player, account, amount, source) then
		return 0 -- rien à prendre, ou profil absent : l'argent reste sur les plaques
	end
	for index, whole in taken do
		local rest = (account.pending[index] or 0) - whole
		if rest > 0 then
			account.pending[index] = rest
		else
			(account.pending :: any)[index] = nil -- plaque vide : on retire la clé
		end
	end
	publish(player, account, nil)
	local plot = account.plot
	local plotIndex = if plot then plot:GetAttribute(PLOT_INDEX_ATTRIBUTE) else nil
	if source == "Pad" and slot and type(plotIndex) == "number" then
		local ok, err = pcall(function()
			Net.Server.CashCollect:FireAll(plotIndex, slot, amount)
		end)
		if not ok then
			reportOnce("cashCollect", `[DisplayService] CashCollect : {err}`, "warn")
		end
	end
	return amount
end

-- Appelle fn(...) sans laisser une erreur arrêter la boucle : elle est écrite une fois par clé.
local function guarded<A...>(key: string, label: string, fn: (A...) -> (), ...: A...)
	xpcall(fn, function(err: any)
		reportOnce(key, `[DisplayService] {label} : {err}`, "warn")
	end, ...)
end

------------------------------------------------------------------------------
-- Accord entre le profil et l'affichage
------------------------------------------------------------------------------

-- Retire de Display les entrées invalides (voir l'en-tête) et renvoie ce qu'il faut afficher :
-- { [numéro de présentoir] = uid }. Un uid exposé deux fois reste sur le plus petit numéro.
local function sanitize(player: Player, data: Data, refs: PlotRefs): { [number]: string }
	local valid: { [number]: string } = {}
	local drops: { { key: string, why: string } } = {}

	for key, uid in data.Display do
		local index = tonumber(key)
		local why: string? = nil
		if index == nil or index % 1 ~= 0 or tostring(index) ~= key or index < 1 or index > MAX_SLOT_INDEX then
			why = "numéro de présentoir invalide"
		elseif index > Balance.Display.MaxSlots and refs.slots[index] == nil then
			why = `présentoir bonus {index} absent de la parcelle`
		elseif not isUnlocked(player, data, refs, index) then
			why = `présentoir {index} verrouillé ({unlockedCount(player, data, refs)} débloqué(s))`
		elseif refs.slots[index] == nil then
			why = `présentoir {index} absent de la parcelle`
		elseif type(uid) ~= "string" then
			why = "uid invalide"
		else
			local entry, def = lookup(data, uid)
			if entry == nil then
				why = `objet {uid} absent de Items`
			elseif def == nil then
				why = `objet {uid} : ItemId « {tostring(entry.Id)} » inconnu du catalogue`
			elseif isInVault(data, uid) then
				why = `objet {uid} rangé au coffre-fort`
			elseif isAntiTheft(entry) then
				why = `objet {uid} sous antivol (L-112)`
			end
		end
		if why then
			table.insert(drops, { key = key, why = why :: string })
		else
			valid[index :: number] = uid
		end
	end

	local wanted: { [number]: string } = {}
	local seenAt: { [string]: number } = {}
	for index = 1, MAX_SLOT_INDEX do
		local uid = valid[index]
		if uid then
			local first = seenAt[uid]
			if first then
				table.insert(drops, { key = tostring(index), why = `objet {uid} déjà exposé sur le présentoir {first}` })
			else
				seenAt[uid] = index
				wanted[index] = uid
			end
		end
	end

	for _, drop in drops do
		data.Display[drop.key] = nil
		warn(`[DisplayService] {player.Name} : Display["{drop.key}"] retiré ({drop.why}) ; l'objet reste dans l'inventaire`)
	end
	return wanted
end

-- Remet l'affichage de la parcelle et le revenu d'accord avec le profil. Sans yield.
local function reconcile(player: Player, account: Account, data: Data, plot: Model)
	local view = views[plot]
	if view == nil or view.owner ~= player then
		return
	end
	-- Les objets affichés jusqu'ici ont rapporté jusqu'à maintenant, chacun sur sa plaque.
	accrue(account, os.clock())
	local refs = refsFor(plot)
	local wanted = sanitize(player, data, refs)
	-- Objet tenu par un voleur : présentoir vide, revenu arrêté, profil inchangé (6.1, DEV-041).
	local heldBy = held[player]
	if heldBy then
		for slot, uid in wanted do
			if heldBy[uid] then
				wanted[slot] = nil
			end
		end
	end

	for slot, visual in view.visuals do
		local uid = wanted[slot]
		local entry = if uid then data.Items[uid] else nil
		if uid ~= visual.uid or entry == nil or entry.Id ~= visual.itemId then
			visual.model:Destroy()
			view.visuals[slot] = nil
		end
	end

	for slot, uid in wanted do
		if view.visuals[slot] == nil then
			local entry, def = lookup(data, uid)
			if entry and def then
				local ok, result = pcall(buildVisual, player.UserId, refs, slot, uid, entry, def)
				if ok then
					local visual = result :: Visual
					visual.model.Parent = view.folder
					view.visuals[slot] = visual
				else
					reportOnce(`build:{uid}`, `[DisplayService] {player.Name} : objet {uid} ({def.Id}) non affiché : {result}`, "warn")
				end
			end
		end
	end

	local income = 0
	for _, visual in view.visuals do
		income += visual.income
	end
	local multiplier = incomeMultiplier(player)
	if income ~= account.income or multiplier ~= account.multiplier then
		account.income = income -- l'ancien revenu a compté jusqu'à maintenant (accrue, plus haut)
		account.multiplier = multiplier
		player:SetAttribute(INCOME_ATTRIBUTE, income * multiplier)
		player:SetAttribute(EXPOSED_INCOME_ATTRIBUTE, income)
	end
end

-- Compte et affichage du joueur sur sa parcelle (profil chargé et parcelle attribuée).
local function context(player: Player): (Data?, Account?, Model?)
	local data = DataService.Get(player)
	local account = accounts[player]
	local plot = if account then account.plot else nil
	if data == nil or account == nil or plot == nil then
		return data, account, nil
	end
	local view = views[plot]
	if view == nil or view.owner ~= player then
		return data, account, nil
	end
	return data, account, plot
end

local function describe(data: Data, uid: string, slot: number): string
	local _, def = lookup(data, uid)
	if def == nil then
		return `objet {uid} sur le présentoir {slot}`
	end
	return `{def.DisplayName} ({Rarities.ById[def.Rarity].DisplayName}) sur le présentoir {slot}`
end

------------------------------------------------------------------------------
-- Arrivée et départ
------------------------------------------------------------------------------

local function newAccount(): Account
	return {
		plot = nil,
		income = 0,
		multiplier = 1,
		pending = {},
		lastAccrue = os.clock(),
		collected = 0,
		onSlot = nil,
		padSeenAt = 0,
		padCollectedAt = {},
		padWaiting = false,
		shownRegister = nil,
		shownSlots = nil,
	}
end

local function clearView(plot: Model)
	local view = views[plot]
	if view then
		views[plot] = nil
		view.folder:Destroy()
	end
end

-- Ramassage de la plaque `slot` où se tient le joueur (L-106 point 12) : tout de suite si son dernier
-- ramassage date d'au moins PAD_COOLDOWN s, sinon dès la fin du délai (padWaiting, checkPads).
local function collectPad(player: Player, account: Account, slot: number, now: number)
	local last = account.padCollectedAt[slot]
	if last and now - last < PAD_COOLDOWN then
		account.padWaiting = true
		return
	end
	account.padWaiting = false
	if cashOut(player, account, "Pad", slot) > 0 then
		account.padCollectedAt[slot] = now
	end
end

-- Touched d'une plaque (branché par scanPads) : ramassage immédiat quand le personnage du
-- propriétaire y arrive.
onPadTouched = function(plot: Model, slot: number, part: BasePart, hit: BasePart)
	local view = views[plot]
	local set = padsOf[plot]
	local pad = if set then set.bySlot[slot] else nil
	if view == nil or pad == nil or pad.part ~= part then
		return -- parcelle libre, ou plaque remplacée
	end
	local owner = view.owner
	local account = accounts[owner]
	local character = owner.Character
	if account == nil or account.plot ~= plot or character == nil or not hit:IsDescendantOf(character) then
		return
	end
	local root = rootOf(owner)
	if root == nil then
		return
	end
	local now = os.clock()
	if account.onSlot == slot then
		account.padSeenAt = now -- toujours dessus : pas de nouveau ramassage
		return
	end
	-- Un pied ou une main qui touche la plaque loin du corps ne compte pas, ni le bord d'une plaque
	-- voisine tant que le joueur se tient encore sur la sienne.
	if not isNearPad(root.Position, part) then
		return
	end
	local onSlot = account.onSlot
	local current = if set and onSlot then set.bySlot[onSlot] else nil
	if current and current.part.Parent ~= nil and isOnPad(root.Position, current.part) then
		return
	end
	account.onSlot = slot -- checkPads le remet à nil quand il en est vraiment sorti
	account.padSeenAt = now
	collectPad(owner, account, slot, now)
end

-- Installe la boutique sauvegardée du joueur sur sa parcelle. Sans yield.
local function install(player: Player, plot: Model)
	local data = DataService.Get(player)
	if data == nil or PlotService.GetPlot(player) ~= plot then
		return
	end
	local existing = views[plot]
	if existing and existing.owner == player then
		return -- déjà installée (attribution et chargement du profil arrivent tous les deux ici)
	end
	clearView(plot)
	-- Pièces cherchées avant d'y poser le moindre objet.
	local refs = refsFor(plot)
	local set = scanPads(plot, unlockedCount(player, data, refs))
	if next(set.bySlot) == nil then
		reportOnce(
			`pads:{plot:GetFullName()}`,
			`[DisplayService] {plot:GetFullName()} : aucune plaque CollectPad_xx (contrat 10.4), son propriétaire ne pourra ramasser son argent qu'en partant`,
			"warn"
		)
	end

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = plot
	views[plot] = { owner = player, folder = folder, visuals = {} }

	local current = accounts[player] or newAccount()
	accounts[player] = current
	accrue(current, os.clock())
	current.plot = plot
	current.onSlot = nil
	current.shownRegister = nil

	reconcile(player, current, data, plot)
	player:SetAttribute(INCOME_ATTRIBUTE, current.income * current.multiplier)
	player:SetAttribute(EXPOSED_INCOME_ATTRIBUTE, current.income)
	player:SetAttribute(COLLECTED_ATTRIBUTE, current.collected)
	publish(player, current, data)

	local count = 0
	for _ in (views[plot] :: View).visuals do
		count += 1
	end
	print(
		`[DisplayService] {player.Name} : {count} objet(s) exposé(s) sur {unlockedCount(player, data, refs)} présentoir(s) débloqué(s), revenu {Format.money(current.income)}/s`
	)
end

local function onProfileLoaded(player: Player)
	-- Vague 63 (a206) : réserve migrée (profil d'avant) et publiée, parcelle ou pas.
	local data = DataService.Get(player)
	if data then
		migrateReserve(player, data)
		syncReserve(player, true)
	end
	local plot = PlotService.GetPlot(player)
	if plot then
		install(player, plot)
	end
end

-- Parcelle libérée (départ) : on retire tout ce qui y est affiché et les plaques repassent à $0.
-- L'argent des plaques reste dans le compte du joueur jusqu'à OnProfileReleasing, qui l'encaisse
-- (l'ordre des deux n'est pas garanti).
local function onPlotReleased(player: Player, plot: Model)
	local account = accounts[player]
	if account and account.plot == plot then
		accrue(account, os.clock()) -- avant de retirer les objets : ils ont rapporté jusqu'ici
		account.income = 0
		account.plot = nil
		account.onSlot = nil
	end
	clearView(plot)
	local set = padsOf[plot]
	if set then
		showPads(set, nil)
	end
	plot:SetAttribute(REGISTER_ATTRIBUTE, 0)
end

-- Départ : dernier moment pour écrire dans le profil. Les plaques sont encaissées (V0, en-tête).
local function onProfileReleasing(player: Player)
	local account = accounts[player]
	if account == nil then
		return
	end
	local amount = cashOut(player, account, "Leave")
	if amount > 0 then
		print(`[DisplayService] {player.Name} part : {Format.money(amount)} de ses plaques encaissés automatiquement`)
	end
	accounts[player] = nil
end

local function onPlayerRemoving(player: Player)
	-- Un objet tenu par un voleur n'a jamais quitté le profil : il part avec lui (PvPService annule
	-- le vol).
	held[player] = nil
	-- Profil encore ouvert : OnProfileReleasing va encaisser puis effacer le compte. Sinon (profil
	-- déjà fermé, repris par un autre serveur), il n'y a plus rien à sauvegarder.
	if not DataService.IsLoaded(player) then
		accounts[player] = nil
	end
end

------------------------------------------------------------------------------
-- Poser un objet
------------------------------------------------------------------------------

local function place(player: Player, itemUid: string, slot: number, fromClient: boolean): (boolean, PlaceError?)
	local data, account, plot = context(player)
	if data == nil then
		return false, "NoProfile"
	end
	if account == nil or plot == nil then
		return false, "NoPlot"
	end
	reconcile(player, account, data, plot)
	local entry, def = lookup(data, itemUid)
	if entry == nil or def == nil then
		return false, "UnknownItem"
	end
	if isInVault(data, itemUid) then
		return false, "InVault"
	end
	if isHeld(player, itemUid) then
		return false, "Held"
	end
	if isAntiTheft(entry) then
		return false, "AntiTheft"
	end
	if slot % 1 ~= 0 or slot < 1 or slot > MAX_SLOT_INDEX then
		return false, "NoSlot"
	end
	local refs = refsFor(plot)
	if slot > Balance.Display.MaxSlots and refs.slots[slot] == nil then
		return false, "NoSlot" -- présentoir bonus pas posé dans la parcelle
	end
	if not isUnlocked(player, data, refs, slot) then
		return false, "Locked"
	end
	if refs.slots[slot] == nil then
		return false, "NoSlot"
	end
	local key = tostring(slot)
	local occupant = data.Display[key]
	if occupant == itemUid then
		return true, nil
	end
	if occupant ~= nil then
		return false, "Taken"
	end
	if fromClient and not isOnPlot(player, plot, refs) then
		return false, "NotOnPlot"
	end

	local previous = slotOf(data, itemUid)
	if previous then
		data.Display[tostring(previous)] = nil
	end
	data.Display[key] = itemUid
	reconcile(player, account, data, plot)
	refreshInventory(player)
	if IS_STUDIO then
		local moved = if previous then ` (déplacé du présentoir {previous})` else ""
		print(`[DisplayService] {player.Name} : {describe(data, itemUid, slot)}{moved}, revenu {Format.money(account.income)}/s`)
	end
	return true, nil
end

local function onPlaceItem(player: Player, itemUid: string, slotIndex: number)
	local ok, reason = place(player, itemUid, slotIndex, true)
	if ok or reason == nil then
		return
	end
	if IS_STUDIO then
		warn(`[DisplayService] {player.Name} → PlaceItem({itemUid}, {slotIndex}) refusé : {reason}`)
	end
	local message = MESSAGES[reason]
	if message then
		notify(player, message, "Warning")
	end
end

------------------------------------------------------------------------------
-- Boucle : plaques et affichage
------------------------------------------------------------------------------

local function checkPads()
	for player, account in accounts do
		local plot = account.plot
		local set = if plot then padsOf[plot] else nil
		if set == nil then
			continue
		end
		local root = rootOf(player)
		local now = os.clock()
		local onSlot = account.onSlot
		local current = if onSlot then set.bySlot[onSlot] else nil
		if root and onSlot and current and current.part.Parent ~= nil and isOnPad(root.Position, current.part) then
			account.padSeenAt = now -- encore sur sa plaque : elle garde la priorité sur une voisine
			if account.padWaiting then
				collectPad(player, account, onSlot, now) -- arrivé pendant le délai : ramassée à sa fin
			end
			continue
		end
		local slot = if root then padAt(set, root.Position) else nil
		if slot and slot ~= onSlot then
			-- Arrivée sur une plaque (ou passage direct sur une autre) : un seul ramassage.
			account.onSlot = slot
			account.padSeenAt = now
			collectPad(player, account, slot, now)
		elseif onSlot then
			if root and current and current.part.Parent ~= nil and isNearPad(root.Position, current.part) then
				account.padSeenAt = now
			elseif now - account.padSeenAt >= PAD_EXIT_DELAY then
				account.onSlot = nil -- vraiment sorti : la prochaine arrivée ramasse de nouveau
				account.padWaiting = false
			end
		end
	end
end

local function refreshAll()
	local now = os.clock()
	for player, account in accounts do
		local data, _, plot = context(player)
		if data and plot then
			guarded(`reconcile:{player.UserId}`, `{player.Name} : mise à jour de l'affichage impossible`, reconcile, player, account, data, plot)
		end
		accrue(account, now)
		publish(player, account, data)
		-- Encaissement automatique (gamepass, DEV-100) : les plaques vont dans l'argent, où que soit le joueur.
		if data and account.plot and autoCollect(player) then
			cashOut(player, account, "Auto")
		end
	end
	-- Vague 63 (a206) : réserve d'accord avec le profil (objet vendu, volé, rangé au coffre-fort ailleurs), parcelle
	-- ou pas.
	for _, player in Players:GetPlayers() do
		syncReserve(player, true)
	end
end

-- Le reste de chaque intervalle est gardé (cadence juste en moyenne), sans rattrapage en rafale
-- après un ralentissement du serveur.
local function onHeartbeat(dt: number)
	padClock += dt
	refreshClock += dt
	if padClock >= PAD_CHECK_INTERVAL then
		padClock = math.min(padClock - PAD_CHECK_INTERVAL, PAD_CHECK_INTERVAL)
		guarded("checkPads", "contrôle des plaques CollectPad", checkPads)
	end
	if refreshClock >= REFRESH_INTERVAL then
		refreshClock = math.min(refreshClock - REFRESH_INTERVAL, REFRESH_INTERVAL)
		guarded("refreshAll", "mise à jour des plaques", refreshAll)
	end
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------

function DisplayService.PlaceAuto(player: Player, itemUid: string, near: Vector3?): number?
	local data, account, plot = context(player)
	if data == nil or account == nil or plot == nil or type(itemUid) ~= "string" then
		return nil
	end
	reconcile(player, account, data, plot)
	local entry, def = lookup(data, itemUid)
	if entry == nil or def == nil or isInVault(data, itemUid) or isHeld(player, itemUid) or isAntiTheft(entry) then
		return nil
	end
	local current = slotOf(data, itemUid)
	if current then
		return current
	end

	local refs = refsFor(plot)
	local origin = near
	if origin == nil then
		local root = rootOf(player)
		origin = if root then root.Position else nil
	end
	local best: number? = nil
	local bestScore = math.huge
	for _, index in unlockedList(player, data, refs) do
		local attachment = refs.slots[index]
		if attachment and data.Display[tostring(index)] == nil then
			-- Sans position, le score est le numéro : premier présentoir libre.
			local score = if origin then (attachment.WorldPosition - origin).Magnitude else index
			if score < bestScore then
				best, bestScore = index, score
			end
		end
	end
	if best == nil then
		return nil
	end
	local slot = best :: number
	data.Display[tostring(slot)] = itemUid
	reconcile(player, account, data, plot)
	refreshInventory(player)
	if data.Display[tostring(slot)] ~= itemUid then
		return nil
	end
	if IS_STUDIO then
		print(`[DisplayService] {player.Name} : {describe(data, itemUid, slot)}, revenu {Format.money(account.income)}/s`)
	end
	return slot
end

function DisplayService.PlaceItem(player: Player, itemUid: string, slotIndex: number): (boolean, PlaceError?)
	return place(player, itemUid, slotIndex, false)
end

function DisplayService.Unplace(player: Player, itemUid: string): number?
	local data = DataService.Get(player)
	if data == nil or isHeld(player, itemUid) then
		return nil
	end
	local slot = slotOf(data, itemUid)
	if slot == nil then
		return nil
	end
	data.Display[tostring(slot)] = nil
	local _, account, plot = context(player)
	if account and plot then
		reconcile(player, account, data, plot)
	end
	refreshInventory(player)
	return slot
end

-- Remet l'affichage du joueur d'accord avec son profil, s'il est installé sur sa parcelle.
local function refresh(player: Player)
	local data, account, plot = context(player)
	if data and account and plot then
		reconcile(player, account, data, plot)
	end
end

function DisplayService.Hold(player: Player, itemUid: string): number?
	local data = DataService.Get(player)
	if data == nil or type(itemUid) ~= "string" or isHeld(player, itemUid) then
		return nil
	end
	local _, account, plot = context(player)
	local view = if plot then views[plot] else nil
	if account == nil or plot == nil or view == nil then
		return nil
	end
	reconcile(player, account, data, plot)
	local slot = slotOf(data, itemUid)
	local visual = if slot then view.visuals[slot] else nil
	if slot == nil or visual == nil or visual.uid ~= itemUid then
		return nil -- pas exposé sur un présentoir de la parcelle (inventaire, coffre-fort, présentoir absent)
	end
	local byUid = held[player] or {}
	held[player] = byUid
	byUid[itemUid] = true
	reconcile(player, account, data, plot)
	if IS_STUDIO then
		print(`[DisplayService] {player.Name} : {describe(data, itemUid, slot)} tenu par un voleur, revenu {Format.money(account.income)}/s`)
	end
	return slot
end

-- Oublie le maintien de l'objet ; true s'il était tenu.
local function forget(player: Player, itemUid: string): boolean
	local byUid = held[player]
	if byUid == nil or byUid[itemUid] ~= true then
		return false
	end
	byUid[itemUid] = nil
	if next(byUid) == nil then
		held[player] = nil
	end
	return true
end

function DisplayService.Release(player: Player, itemUid: string): boolean
	if not forget(player, itemUid) then
		return false
	end
	refresh(player)
	return true
end

function DisplayService.TakeHeld(player: Player, itemUid: string): boolean
	if not isHeld(player, itemUid) then
		return false
	end
	local data = DataService.Get(player)
	if data == nil then
		return false
	end
	forget(player, itemUid)
	for key, uid in table.clone(data.Display) do
		if uid == itemUid then
			data.Display[key] = nil
		end
	end
	refresh(player)
	return true
end

function DisplayService.IsHeld(player: Player, itemUid: string): boolean
	return isHeld(player, itemUid)
end

function DisplayService.GetExposed(player: Player): { [number]: ExposedItem }
	local exposed: { [number]: ExposedItem } = {}
	local account = accounts[player]
	local plot = if account then account.plot else nil
	local view = if plot then views[plot] else nil
	if view == nil or view.owner ~= player then
		return exposed
	end
	for slot, visual in view.visuals do
		exposed[slot] = { Uid = visual.uid, ItemId = visual.itemId, Income = visual.income }
	end
	return exposed
end

-- Objets exposés (présentoirs distincts) et objets de l'inventaire (ni exposés ni au coffre-fort).
local function counts(data: Data): (number, number)
	local placed: { [string]: boolean } = {}
	local displayed = 0
	for _, uid in data.Display do
		if not placed[uid] then
			placed[uid] = true
			displayed += 1
		end
	end
	for _, uid in data.Vault do
		placed[uid] = true
	end
	local stored = 0
	for uid in data.Items do
		if not placed[uid] then
			stored += 1
		end
	end
	return displayed, stored
end

function DisplayService.HasRoom(player: Player): boolean
	local data = DataService.Get(player)
	if data == nil then
		return false
	end
	local displayed, stored = counts(data)
	local account = accounts[player]
	local plot = if account then account.plot else nil
	return displayed < unlockedCount(player, data, if plot then refsFor(plot) else nil) or stored < Balance.Display.InventoryMax
end

function DisplayService.HasInventoryRoom(player: Player): boolean
	local data = DataService.Get(player)
	if data == nil then
		return false
	end
	local _, stored = counts(data)
	return stored < Balance.Display.InventoryMax
end

-- Présentoirs de la parcelle du joueur et leur état (L-086, UnboxService ; voir l'en-tête).
local function playerRefs(player: Player): PlotRefs?
	local plot = PlotService.GetPlot(player)
	return if plot then refsFor(plot) else nil
end

function DisplayService.GetSlots(player: Player): { [number]: Attachment }
	local slots: { [number]: Attachment } = {}
	local refs = playerRefs(player)
	if refs then
		for index, attachment in refs.slots do
			if attachment then
				slots[index] = attachment
			end
		end
	end
	return slots
end

function DisplayService.GetSlotStates(player: Player): { [number]: SlotState }
	local states: { [number]: SlotState } = {}
	local data = DataService.Get(player)
	local refs = playerRefs(player)
	if data == nil or refs == nil then
		return states
	end
	for index, attachment in refs.slots do
		if attachment then
			local state: SlotState
			if not isUnlocked(player, data, refs, index) then
				state = "Locked"
			elseif data.Display[tostring(index)] ~= nil then
				state = "Taken"
			else
				state = "Free"
			end
			states[index] = state
		end
	end
	return states
end

-- Equip Best (règle V0 dans l'en-tête). Sans yield.
function DisplayService.EquipBest(player: Player): number
	local data, account, plot = context(player)
	if data == nil or account == nil or plot == nil then
		return 0
	end
	reconcile(player, account, data, plot)
	local refs = refsFor(plot)
	local heldBy = held[player] or {}
	-- Présentoirs utilisables : débloqués, posés, sans objet tenu par un voleur.
	local slots: { number } = {}
	for _, index in unlockedList(player, data, refs) do
		local occupant = data.Display[tostring(index)]
		if refs.slots[index] ~= nil and not (occupant ~= nil and heldBy[occupant]) then
			table.insert(slots, index)
		end
	end
	table.sort(slots)
	local displayedAt: { [string]: number } = {}
	for _, index in slots do
		local uid = data.Display[tostring(index)]
		if uid ~= nil and displayedAt[uid] == nil then
			displayedAt[uid] = index
		end
	end
	local candidates: { Candidate } = {}
	for uid, entry in data.Items do
		local _, def = lookup(data, uid)
		if def and not isInVault(data, uid) and not heldBy[uid] and not isAntiTheft(entry) then
			table.insert(candidates, { uid = uid, income = itemIncome(def, entry, uid), shown = displayedAt[uid] ~= nil })
		end
	end
	table.sort(candidates, function(a: Candidate, b: Candidate): boolean
		if a.income ~= b.income then
			return a.income > b.income
		end
		if a.shown ~= b.shown then
			return a.shown
		end
		return a.uid < b.uid
	end)
	local best: { [string]: boolean } = {}
	for position = 1, math.min(#slots, #candidates) do
		best[candidates[position].uid] = true
	end
	-- Les exposés qui ne font plus partie des meilleurs retournent dans l'inventaire…
	-- Vague 63 (a206, L-192 Q3) : … et dans la réserve (au bout, du meilleur au moins bon ; pleine : hors liste).
	local bumped: { Candidate } = {}
	for _, index in slots do
		local key = tostring(index)
		local uid = data.Display[key]
		if uid ~= nil and not best[uid] then
			data.Display[key] = nil
			local entry, def = lookup(data, uid)
			table.insert(bumped, { uid = uid, income = if entry and def then itemIncome(def, entry, uid) else 0, shown = true })
		end
	end
	table.sort(bumped, function(a: Candidate, b: Candidate): boolean
		if a.income ~= b.income then
			return a.income > b.income
		end
		return a.uid < b.uid
	end)
	if data.Reserve == nil then
		migrateReserve(player, data) -- profil pas encore migré (chargé avant ce service) : tout le non-exposé y va
	end
	for _, candidate in bumped do
		addToReserve(data, candidate.uid, inHandOf(player))
	end
	-- … et les meilleurs pas encore exposés prennent les présentoirs libres, dans l'ordre.
	local moved = 0
	local position = 1
	for _, candidate in candidates do
		if best[candidate.uid] and displayedAt[candidate.uid] == nil then
			while position <= #slots and data.Display[tostring(slots[position])] ~= nil do
				position += 1
			end
			if position > #slots then
				break
			end
			data.Display[tostring(slots[position])] = candidate.uid
			moved += 1
		end
	end
	reconcile(player, account, data, plot)
	refreshInventory(player)
	if IS_STUDIO then
		print(`[DisplayService] {player.Name} : Equip Best, {moved} objet(s) posé(s), revenu {Format.money(account.income)}/s`)
	end
	return moved
end

local function onEquipBest(player: Player)
	local data, _, plot = context(player)
	if data == nil then
		return
	end
	if plot == nil then
		notify(player, MESSAGES.NoPlot, "Warning")
		return
	end
	local moved = DisplayService.EquipBest(player)
	notify(player, if moved > 0 then MESSAGES.EquipBest else MESSAGES.EquipBestSame, "Info")
end

-- Vague 63 (a206) : réserve (voir l'en-tête). Sans yield.
function DisplayService.GetReserve(player: Player): { string }
	local data = DataService.Get(player)
	return if data then table.clone(cleanReserve(data, inHandOf(player))) else {}
end

function DisplayService.AddToReserve(player: Player, itemUid: string): boolean
	local data = DataService.Get(player)
	if data == nil or type(itemUid) ~= "string" then
		return false
	end
	if data.Reserve == nil then
		migrateReserve(player, data)
	end
	local added = addToReserve(data, itemUid, inHandOf(player))
	syncReserve(player)
	return added
end

-- Remet sur le présentoir libre et débloqué le plus proche du joueur (sinon le premier libre ; PlaceAuto) un objet
-- de SA réserve. Renvoie le présentoir, ou nil et la raison : "NoProfile", "NotInReserve" (pas dans sa réserve
-- nettoyée : pas à lui, exposé, au coffre-fort, sous antivol, parti), "NoPlot", "NoFreeDisplay". Rien ne bouge sur
-- un refus. Où que soit le joueur (comme Equip Best). Sans yield.
-- Vague 66 (a219, Config/Displayed.SwapWhenFull, V0) : aucun présentoir libre : l'objet prend la place de l'exposé
-- qui rapporte le moins (à revenu égal, le plus grand numéro ; jamais un objet tenu par un voleur), qui prend sa
-- place dans la réserve. Troisième valeur rendue : l'uid de l'objet sorti, nil sans échange.

-- L'échange (voir plus haut). Renvoie le présentoir et l'uid sorti, ou nil (rien ne bouge). Sans yield.
local function swapIn(player: Player, data: Data, plot: Model, itemUid: string): (number?, string?)
	local account = accounts[player]
	if DisplayedConfig.SwapWhenFull ~= true or account == nil then
		return nil, nil
	end
	local refs = refsFor(plot)
	local heldBy = held[player] or {}
	local slot: number?, out: string?, lowest = nil, nil, math.huge
	for _, index in unlockedList(player, data, refs) do
		local uid = data.Display[tostring(index)]
		if refs.slots[index] ~= nil and uid ~= nil and not heldBy[uid] then
			local entry, def = lookup(data, uid)
			local income = if entry and def then itemIncome(def, entry, uid) else 0
			if income < lowest or (income == lowest and slot ~= nil and index > slot) then
				slot, out, lowest = index, uid, income
			end
		end
	end
	if slot == nil or out == nil then
		return nil, nil
	end
	local key = tostring(slot)
	data.Display[key] = itemUid
	reconcile(player, account, data, plot)
	if data.Display[key] ~= itemUid then
		data.Display[key] = out -- refusé par la mise d'accord : l'ancien revient
		reconcile(player, account, data, plot)
		return nil, nil
	end
	-- L'objet sorti prend la place de l'objet exposé dans la réserve (même taille : jamais au-delà de ReserveMax).
	local list = data.Reserve
	local at = if type(list) == "table" then table.find(list, itemUid) else nil
	if list and at then
		list[at] = out :: string
	else
		addToReserve(data, out :: string, inHandOf(player))
	end
	refreshInventory(player)
	if IS_STUDIO then
		print(`[DisplayService] {player.Name} : {describe(data, itemUid, slot)} à la place de {out} (réserve), revenu {Format.money(account.income)}/s`)
	end
	return slot, out
end

function DisplayService.PlaceFromReserve(player: Player, itemUid: string): (number?, string?, string?)
	local data, _, plot = context(player)
	if data == nil then
		return nil, "NoProfile", nil
	end
	if type(itemUid) ~= "string" or table.find(cleanReserve(data, inHandOf(player)), itemUid) == nil then
		return nil, "NotInReserve", nil
	end
	if plot == nil then
		return nil, "NoPlot", nil
	end
	local slot = DisplayService.PlaceAuto(player, itemUid)
	if slot == nil then
		local swapped, out = swapIn(player, data, plot, itemUid)
		if swapped == nil then
			return nil, "NoFreeDisplay", nil
		end
		return swapped, nil, out
	end
	syncReserve(player) -- exposé : il quitte la réserve (cleanReserve)
	return slot, nil, nil
end

-- Remote PlaceFromReserve(itemUid) : DisplayButton d'une ligne de UI_Displayed.Panel.Reserve (DisplayedController).
local function onPlaceFromReserve(player: Player, itemUid: string)
	local slot, reason, out = DisplayService.PlaceFromReserve(player, itemUid)
	if slot then
		local data = DataService.Get(player)
		local function nameOf(uid: string): string
			local entry: ItemEntry?, def: ItemDef? = nil, nil
			if data then
				entry, def = lookup(data, uid)
			end
			return if entry and def then Mutations.ItemName(def.DisplayName, Mutations.Sanitize(entry.Mutation)) else "Item"
		end
		if out then -- vague 66 (a219) : échange, présentoirs tous pris
			notify(player, string.format(MESSAGES.ReserveSwapped, nameOf(itemUid), nameOf(out)), "Success")
		else
			notify(player, string.format(MESSAGES.ReservePlaced, nameOf(itemUid)), "Success")
		end
		return
	end
	if reason == "NoFreeDisplay" then
		notify(player, MESSAGES.NoFreeDisplay, "Warning")
	elseif reason == "NoPlot" then
		notify(player, MESSAGES.NoPlot, "Warning")
	elseif IS_STUDIO then
		warn(`[DisplayService] {player.Name} → PlaceFromReserve({itemUid}) refusé : {reason}`)
	end
end

function DisplayService.GetIncome(player: Player): number
	local account = accounts[player]
	return if account then account.income else 0
end

function DisplayService.GetRegister(player: Player): number
	local account = accounts[player]
	if account == nil then
		return 0
	end
	accrue(account, os.clock())
	return math.floor(pendingTotal(account))
end

function DisplayService.GetCollectTarget(player: Player): Vector3?
	local account = accounts[player]
	local plot = if account then account.plot else nil
	local set = if plot then padsOf[plot] else nil
	if account == nil or set == nil then
		return nil
	end
	accrue(account, os.clock())
	local best: number? = nil
	local bestAmount = 0
	for slot in set.bySlot do
		local amount = math.floor(account.pending[slot] or 0)
		if amount >= 1 and (amount > bestAmount or (amount == bestAmount and best ~= nil and slot < best)) then
			best, bestAmount = slot, amount
		end
	end
	if best == nil then
		local view = if plot then views[plot] else nil
		if view then
			for slot in view.visuals do
				local target = padSlotFor(set, slot)
				if set.bySlot[target] and (best == nil or target < best) then
					best = target
				end
			end
		end
	end
	local pad = if best then set.bySlot[best] else nil
	return if pad then pad.part.Position else nil
end

function DisplayService.CashOut(player: Player): number
	local account = accounts[player]
	if account == nil then
		return 0
	end
	return cashOut(player, account, "Api")
end

function DisplayService.OnCashOut(listener: CashOutListener): () -> ()
	return subscribe(cashOutListeners, listener)
end

-- Gains hors ligne (DEV-102, voir l'en-tête) : versés directement dans l'argent au Claim (dollars entiers).
function DisplayService.AddOfflineEarnings(player: Player, amount: number): boolean
	if DataService.Get(player) == nil or type(amount) ~= "number" or amount ~= amount or amount <= 0 or amount >= math.huge then
		return false
	end
	local account = accounts[player]
	if account == nil then
		-- Pas encore de parcelle : install reprendra ce compte (argent encaissé compris).
		account = newAccount()
		accounts[player] = account
	end
	local whole = math.floor(amount)
	if whole < 1 then
		return true -- moins de 1 $ : rien à verser
	end
	return pay(player, account, whole, "Offline")
end

function DisplayService.GetGlobalMultiplier(player: Player): number
	return incomeMultiplier(player)
end

function DisplayService.BuildBotItem(plot: Model, slotIndex: number, itemUid: string, itemId: string): Model?
	local def = ItemsConfig.ById[itemId]
	local refs = refsFor(plot)
	if def == nil or Rarities.ById[def.Rarity] == nil or refs.slots[slotIndex] == nil then
		return nil
	end
	local entry: ItemEntry = { Id = def.Id, Source = "NPC", At = 0, Zone = def.Zone }
	local ok, result = pcall(buildVisual, 0, refs, slotIndex, itemUid, entry, def)
	if not ok then
		reportOnce(`bot:{itemId}`, `[DisplayService] objet du bot {itemId} non affiché : {result}`, "warn")
		return nil
	end
	return (result :: Visual).model
end

function DisplayService.BuildFloorItem(ownerUserId: number, pivot: CFrame, itemUid: string, entry: ItemEntry): Model?
	local def = if type(entry) == "table" then ItemsConfig.ById[entry.Id] else nil
	if def == nil or Rarities.ById[def.Rarity] == nil then
		return nil
	end
	local ok, model = pcall(buildItemModel :: any, ownerUserId, pivot, FLOOR_ITEM_NAME, itemUid, entry, def, false) -- :: any : idem
	if not ok then
		reportOnce(`floor:{def.Id}`, `[DisplayService] objet au sol {def.Id} non construit : {model}`, "warn")
		return nil
	end
	return model :: Model
end

-- Points d'accroche (DEV-100 et DEV-111, voir l'en-tête) : valeurs du MVP, sans bonus.
function DisplayService.GetIncomeBonus(_player: Player): number
	return 0
end

function DisplayService.GetIncomeMultiplier(_player: Player): number
	return 1
end

function DisplayService.GetExtraSlots(_player: Player): number
	return 0
end

function DisplayService.HasAutoCollect(_player: Player): boolean
	return false
end

function DisplayService.Init()
	-- Rejoue les attributions déjà faites ; la parcelle n'est donnée qu'à un profil chargé.
	PlotService.OnPlotAssigned(install)
	PlotService.OnPlotReleased(onPlotReleased)
	DataService.OnProfileLoaded(onProfileLoaded)
	DataService.OnProfileReleasing(onProfileReleasing)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	Net.Server.PlaceItem:Connect(onPlaceItem)
	Net.Server.EquipBest:Connect(onEquipBest)
	Net.Server.PlaceFromReserve:Connect(onPlaceFromReserve) -- vague 63 (a206)
	RunService.Heartbeat:Connect(onHeartbeat)
end

return DisplayService

-- Tester dans Studio (après fusion avec DataService et PlotService ; UnboxService pour la boucle) :
--   1. Play. Sortie : « [DisplayService] <Nom> : 0 objet(s) exposé(s) sur 4 présentoir(s)
--      débloqué(s), revenu 0 $/s », aucune ligne rouge. Attributs : Income = 0,
--      DisplaySlotsUnlocked = 4 sur le Player ; CashRegister = 0 sur sa parcelle.
--   2. Objets : par la boucle (UnboxService appelle PlaceAuto), ou par un Script temporaire dans
--      Workspace/_SANDBOX_IRONIX (la barre de commande a son propre cache de require) qui ajoute
--      des objets à Items et appelle PlaceAuto : voir le rapport de l'agent a14.
--   3. Barre de commande, contexte Client :
--      game.ReplicatedStorage.Remotes.PlaceItem:FireServer("<uid>", 2)
--   4. Le montant de chaque objet monte sur sa plaque CollectPad_xx (AmountGui/Amount, chaque seconde).
--      Marcher sur la plaque : son argent passe dans Cash, la plaque repart à « $0 », gerbe de
--      BurstPoint chez tous les joueurs proches (remote CashCollect). Partir encaisse toutes les plaques.
