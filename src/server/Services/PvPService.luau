--!strict
-- PvPService (DEV-041, DEV-044, fin de DEV-040) : vol entre joueurs et règles anti-frustration
-- (Partie 1, sections 6, 6.1, 6.2, 6.4, 9.3, 9.4, 9.6 et 14.3 ; boutique du hub, liaison L-050).
--
-- Une boutique = un Model taggé PlayerPlot (PlotService), avec sa porte à casser `PlotDoor/Window`
-- (la vitrine « Plot_<PlotIndex> » de WindowService : PV de base selon le niveau de la boutique,
-- Formulas.PlayerWindowHP, × Glass et Walls de l'arbre ; porte du bot joueur : base du niveau 1 ;
-- régénération 3 %/s), son volume `Bounds`, sa `DepositZone` et ses `DisplaySlot_01` à `_20`.
--
-- Le vol, dans l'ordre (6.1) :
--   1. Repérage : panneau côté client (PvPController), rien ici. Ce service publie sur la parcelle
--      ce que le panneau ne peut pas deviner (attributs plus bas).
--   2. Frappe : WindowService.CanBeHit est remplacé ici (l'ancienne fonction sert toujours pour les
--      autres vitrines). Décision de Cantin (2026-11-12) : plus aucune protection des boutiques, tout le
--      monde peut voler tout le monde. Un coup sur la porte d'un joueur n'est refusé que pendant
--      l'interdiction de PvP.KickRobCooldown s du frappeur sur CETTE boutique (« Défense par le
--      propriétaire », plus bas) ; il reçoit alors un Notify (au plus un par NOTICE_INTERVAL s).
--      Quand la porte casse, la victime est prévenue (« l'alarme de base », Notify Warning), et l'alerte
--      d'intrusion part (voir « Alerte d'intrusion », plus bas).
--   3. Casse (WindowService.OnBroken, Kind « Plot ») : la boutique s'ouvre au vol jusqu'à la reconstruction
--      de sa porte. Vague 33 (Cantin, 2026-11-13) : plus aucun chrono chez un joueur (ni HeistTimer, ni
--      StealEndsAt) : le voleur a tout le temps qu'il lui faut. La porte ne se reconstruit pas tant qu'un
--      non-propriétaire est dans le volume Bounds (point d'attente WindowService.AddRebuildGate, sans limite
--      pour une boutique), puis comme avant (PvP.StealDuration + Balance.Window.RebuildDelay s après la casse
--      au plus tôt). Les magasins PNJ ne changent pas. Prise par StealItem(plotIndex, slotIndex), en deux
--      appels comme GrabItem : le premier ouvre un maintien (heure serveur), le second n'est accepté
--      qu'après PvP.StealGrabTime − GRAB_TIME_TOLERANCE s ; le maintien est revérifié 10 fois par
--      seconde et expire GrabTime + HOLD_EXPIRY s après son début. Le serveur vérifie : boutique
--      ouverte, pas la sienne, les deux profils chargés, mains vides (un objet à la fois), pas
--      d'interdiction sur cette boutique (voir 2), le voleur a une boutique et de la place (DisplayService.HasRoom), il est
--      vivant, dans Bounds de la boutique et à PvP.StealMaxDistance (8 studs) au plus du présentoir,
--      l'objet est exposé sur ce présentoir (ni colis des établis, ni coffre-fort, ni objet déjà
--      tenu) et n'est pas l'objet à l'abri (coffre-fort V0, plus bas).
--   4. Fuite : DisplayService.Hold vide le présentoir (le profil de la victime ne change pas), puis
--      CarryService.StartCarry(voleur, PlayerItemPayload) : l'objet flotte au-dessus de sa tête avec
--      son halo, BB_Carry et un contour rouge, vitesse fixe (CarryService). TheftAlert(true,
--      voleur, itemId) et un Notify à la victime (UI_TheftAlert et Adrénaline : DEV-042).
--   5. Réussite : le voleur entre dans la DepositZone de SA boutique (contrôlé 10 fois par seconde :
--      emprise au sol de la DepositZone, et dans le volume Bounds de sa boutique).
--      Transfert (voir « Transfert sûr ») : l'objet est à lui tout de suite, Source = "PvP", avec sa
--      zone et sa mutation (DEV-131 : même revenu, même nom, même taille chez le voleur), sur un
--      présentoir libre (DisplayService.PlaceAuto, le plus proche de lui) sinon dans son inventaire,
--      et il rapporte aussitôt. Puis Lifetime.Steals + 1 pour le voleur, TheftAlert(false), un Notify
--      à chacun, et une sauvegarde des deux profils (plus d'immunité pour la victime).
--   6. Échec : coup de batte (CarryService.Fail(voleur, "Bat"), DEV-043), mort, départ ou personnage
--      retiré du voleur, départ de la victime (Fail « VictimLeft »), anomalie (ReportAnomaly), plus de
--      place au dépôt (« NoRoom »), ou toute autre fin de portage : l'objet revient sur son présentoir
--      d'origine (DisplayService.Release). Rien à défaire : le profil n'a jamais changé.
--
-- Transfert sûr (6.4, 9.6, 14.3) : l'objet ne change de propriétaire qu'au dépôt, et dans une seule
-- exécution serveur, sans yield : vérification (les deux joueurs présents et pas en train de partir,
-- leurs deux profils actifs dans DataService, l'objet toujours dans Items de la victime avec le même
-- ItemId, absent de chez le voleur, toujours tenu, le portage est bien celui de ce vol), puis
-- DisplayService.TakeHeld (présentoir de la victime), retrait de Items de la victime, ajout à Items
-- du voleur (même uid), PlaceAuto, CarryService.Consume. Roblox n'exécute qu'un fil à la fois : un
-- départ (PlayerRemoving, libération du profil) passe soit avant le dépôt (vérification ratée : le
-- vol échoue, l'objet n'a jamais quitté le profil de la victime), soit après (les deux profils sont
-- déjà à jour et chacun se sauvegarde avec son état). Jamais deux exemplaires, jamais aucun.
-- Sauvegarde : DataService.Save de la victime, puis du voleur, tout de suite (au lieu de la sauvegarde
-- automatique, jusqu'à 5 min plus tard). Seul un arrêt brutal du serveur pendant ces deux écritures
-- pourrait encore laisser un doublon ou une perte (deux clés DataStore, aucune transaction possible) ;
-- l'uid reste le même chez le voleur : un doublon se repère.
-- Contrôle du dépôt (9.6, V0 proposé, absent du doc) : la distance de la prise au dépôt ne peut pas
-- dépasser ce qu'un joueur au plafond de vitesse parcourt dans ce temps (Balance.Stats.MaxWalkSpeed ×
-- Balance.AntiCheat.SpeedTolerance, plus ESCAPE_MARGIN s ; le voleur, lui, porte à vitesse fixe, 2026-11-13) :
-- sinon CarryService.ReportAnomaly, l'objet revient. Un joueur lent ou qui rame n'est jamais pris.
-- Avant lui, AntiCheatService.Verify(voleur, From, StartedAt) (DEV-060) contrôle tout de suite son
-- dernier déplacement (téléport) et le trajet depuis la prise à sa vitesse réelle (speed hack) :
-- sanctionné, le portage échoue et l'objet revient. Le contrôle du dépôt reste un filet : il marche
-- aussi en Studio sans AntiCheatStrict et quand Features.AntiCheat = false.
--
-- Protections (6.4, décision de Cantin du 2026-11-12) : plus de bouclier débutant sur la boutique, plus
-- d'immunité après un vol subi, plus d'anti-racket. Restent : 3 s d'immunité aux coups de batte
-- (DEV-043, BatService) ; coffre-fort ; l'argent n'est jamais volé (ni Cash ni la caisse ne sont lus ou
-- écrits ici) ; transfert sûr. Le bouclier débutant ne protège plus que le colis PNJ porté (BatService).
--
-- Défense par le propriétaire (Cantin, 2026-11-12) : BatService.IsIntruder est remplacé ici : le
-- propriétaire frappe à la batte tout autre joueur qui est dans le volume Bounds de SA boutique, même
-- mains vides et en zone safe (mêmes portée, angle, mur et immunité de 3 s que les autres coups). Sur un
-- coup du propriétaire (BatService.OnHit, usage « Intruder », ou « Defend » : son voleur avec son objet),
-- la cible :
--   - est sortie devant la porte (PlotService.PutOutside) si elle est dans Bounds ; l'objet qu'elle lui
--     volait est déjà revenu sur son présentoir (Fail « Bat ») ;
--   - ne peut plus voler cette boutique-là pendant PvP.KickRobCooldown (60) s : coups sur sa porte et
--     StealItem refusés (Notify au plus un par NOTICE_INTERVAL s), et ressortie 10 fois par seconde si
--     elle revient dans Bounds, même porte cassée. Les autres boutiques et les magasins PNJ restent
--     ouverts pour elle.
-- Un joueur mort dans le volume Bounds d'une boutique qui n'est pas la sienne (joueur ou bot) prend la
-- même interdiction sur cette boutique (pièges de l'arbre à venir compris). Interdictions oubliées au
-- départ du joueur, et celles d'une boutique quand son propriétaire part (OnPlotReleased).
-- require protégé de BatService (bancs sans lui) : sans lui, pas de défense par le propriétaire.
-- Coffre-fort V0 (6.4 « au moins 1 objet est toujours à l'abri » ; Partie 2, section 2 : « présentoirs
-- non volables, 1 offert dès le MVP ») : les PvP.VaultSlots (1) objets exposés qui rapportent le
-- plus ne sont jamais volables (à revenu égal, le présentoir de plus petit numéro). Ils restent sur
-- leur présentoir et rapportent ; aucune action du joueur, aucun remote, profil inchangé (le champ
-- Vault et VaultSlot_01 restent pour le coffre physique de la MAJ 2, DEV-110). Un joueur qui n'expose
-- qu'un objet ne peut donc pas être volé.
--
-- Boutique du hub (L-050), sortie par le serveur devant la porte (PlotService.PutOutside), avec ce
-- qu'il porte :
--   - 10 fois par seconde : un non-propriétaire dans Bounds d'une boutique dont la porte n'est pas
--     cassée et dont la fenêtre de vol est fermée (rien n'y entre sans casser la porte ; boutique
--     libre comprise, où il serait enfermé), et, porte cassée ou non, un joueur interdit de voler
--     cette boutique (voir plus haut). Un joueur qui part (profil libéré) n'est pas déplacé ;
--   - à la reconstruction de la porte (WindowService.OnRebuilt) : tout non-propriétaire encore
--     dedans (le point d'attente fait qu'il n'y a d'habitude plus personne ; une reconstruction forcée,
--     WindowService.Rebuild ou départ du propriétaire, sort même un voleur chargé) ; la fenêtre de vol se ferme.
-- Le passage du propriétaire reste côté client (PlotDoorController).
--
-- Alerte d'intrusion (vague 33, Cantin, 2026-11-13) : la victime est prévenue dès qu'on casse sa porte
-- ou qu'on entre chez elle pour voler, plus seulement à la prise d'un objet. Intrus d'une boutique dont
-- la porte est cassée (fenêtre de vol ouverte) : tout non-propriétaire présent, profil chargé, vivant,
-- sans interdiction sur cette boutique, qui est dans son volume Bounds ; celui qui a cassé la porte compte
-- aussi tant qu'il est à PvP.ScoutDistance studs ou moins de Bounds (il est à la porte). Un intrus qui porte
-- déjà un objet volé à cette victime n'est pas compté ici (son alerte avec l'objet passe avant). Revu 10 fois
-- par seconde : un intrus nouveau = TheftAlert(true, intrus, nil) à la victime (bannière « BOB IS STEALING
-- YOUR SHOP! », sirène, flèche, surbrillance, batte en main ; TheftAlertController) ; un intrus parti =
-- TheftAlert(false) puis réannonce des intrus restants, puis des vols en cours (du plus ancien au plus
-- récent). TheftAlertService réannonce aussi les intrus (GetIntruders) après la fin d'un vol. Jamais pour
-- la boutique du bot. L'Adrénaline reste aux vols (objet pris).
--
-- Posé par ce service sur la parcelle, lu par PvPController (aucun nom du contrat) :
--   StealOpen (booléen, nil fermé ; plus de StealEndsAt depuis la vague 33) ;
--   SafeSlots (texte « 3 » ou « 3,7 » : présentoirs à l'abri, nil sans objet exposé).
-- Posé sur le Player interdit de voler une boutique (lu par PvPController, son panneau) :
--   RobCooldown_<PlotIndex> (heure serveur de la fin de l'interdiction), retiré à la fin.
--
-- Remote StealItem(plotIndex, slotIndex) (Net/Definitions, ajout de la vague 10 au tableau 9.4).
--
-- Objet sous antivol au sol (vague 31, L-112, Features.ShelfOpen ; UnboxService) : pendant son antivol, un
-- objet posé au sol d'une boutique est volable. Remote StealFloorItem(plotIndex, itemUid), deux appels comme
-- StealItem, mêmes règles (boutique ouverte au vol, mains vides, interdiction, dans Bounds, à
-- PvP.StealMaxDistance de l'objet, maintien PvP.StealGrabTime), plus : un vrai joueur (le bot n'en a pas),
-- antivol encore en cours (UnboxService.IsStealable), place dans l'inventaire du voleur ; pas de coffre-fort.
-- Fuite : UnboxService.HoldFloorItem sort le modèle du monde, même portage PlayerItem (SlotIndex = 0). Échec :
-- UnboxService.ReleaseFloorItem, l'objet revient à sa place (son antivol a continué de courir). Dépôt (même
-- transfert sûr) : UnboxService.TakeFloorItem, l'objet quitte le profil de la victime et arrive chez le voleur
-- dans son inventaire, de nouveau sous antivol (AntiTheft, sans UnlockAt : l'attente complète repart à sa pose
-- au sol chez lui), jamais sur un présentoir.
--
-- API (serveur) :
--   PvPService.GetTheft(thief) -> TheftInfo?
--       { Victim, ItemUid, ItemId, SlotIndex } du vol en cours (objet porté), nil sinon.
--   PvPService.IsThiefOf(player, owner) -> boolean
--       true si `player` porte un objet volé à `owner` (SwingBat, usage 1 de 6.2, DEV-043).
--   PvPService.GetRobCooldown(player, plot) -> number
--       Secondes restantes de l'interdiction de `player` sur la boutique `plot`, 0 sans interdiction.
--   PvPService.GetIntruders(victim) -> { Player }
--       Vague 33 : intrus annoncés à `victim` (voir « Alerte d'intrusion »), dans l'ordre d'arrivée ; une
--       copie, vide sans intrus. Pour la réannonce de TheftAlertService.
--   PvPService.GetVaultSlots(owner) -> number
--       Point d'accroche : nombre d'objets exposés à l'abri chez `owner` (coffre-fort V0) ; PvP.VaultSlots
--       (1) par défaut, remplacé par SkillTreeService (compétence Safe, vague 27 : 1 + Effects[niveau]).
--       Jamais moins que PvP.VaultSlots ; une erreur ou une valeur invalide reprend PvP.VaultSlots.
--   PvPService.OnTheftStarted(listener) -> déconnexion     listener(thief, victim, itemId)
--   PvPService.OnTheftEnded(listener) -> déconnexion
--       listener(thief, victim, itemId, result, reason) ; result = "Stolen" (dépôt) ou "Returned"
--       (échec : l'objet est revenu sur son présentoir), reason = raison du portage. Pour DEV-042
--       (UI_TheftAlert, Adrénaline, batte équipée) et la télémétrie.
--   Branchés par TheftAlertService (DEV-042) : Adrénaline de la victime, réannonce de l'alerte quand
--   plusieurs vols ont lieu chez elle, Lifetime.Defenses ; côté client, TheftAlertController.
--
-- Bot joueur (L-085 point 4, L-105 point 1, L-108 point 3 ; BotService, Config/Bot) : sa boutique (attribut
-- BotName de la parcelle, PlotService) se braque comme celle d'un joueur, par le même chemin (HitWindow,
-- casse, StealItem en deux appels, fuite, dépôt chez soi, échec). Ici, une victime nil = le bot : ses objets
-- exposés viennent de BotService (Hold, Release, IsHeld, TakeHeld). Ce qui change pour lui :
--   - aucune protection (comme un joueur depuis le 2026-11-12) et pas de coffre-fort de l'arbre
--     (PvP.VaultSlots objet à l'abri, comme un joueur sans compétence) ;
--   - le voleur reçoit l'objet au dépôt (Source = "PvP", zone du catalogue, sans mutation) et sa sauvegarde
--     part tout de suite ; le bot n'a pas de profil, BotService fait revenir un objet plus tard ;
--   - jamais compté comme un joueur : ni Notify, ni TheftAlert, ni alarme de base vers lui, ni
--     OnTheftStarted/OnTheftEnded (Adrénaline, défenses, télémétrie et index restent aux vrais joueurs ;
--     GetTheft renvoie nil pour un vol au bot), ni Lifetime.Steals (classements) ;
--   - le bot part pendant un vol (5e joueur, boutique manquante) : le vol échoue (« VictimLeft »), sa
--     fenêtre de vol se ferme au tick suivant.
-- require protégé : sans BotService (anciens bancs), aucune boutique de bot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local Features = require(Shared.Config.Features)
local Items = require(Shared.Config.Items)
local Mutations = require(Shared.Config.Mutations)
local PvP = require(Shared.Config.PvP)
local Find = require(Shared.Contract.Find)
local Format = require(Shared.Format)
local Net = require(Shared.Net.Net)
local CarryTypes = require(Shared.Types.Carry)

local AntiCheatService = require(script.Parent.AntiCheatService)
local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)
local DisplayService = require(script.Parent.DisplayService)
local PlotService = require(script.Parent.PlotService)
local WindowService = require(script.Parent.WindowService)

type PlayerItemPayload = CarryTypes.PlayerItemPayload

export type TheftResult = "Stolen" | "Returned"

export type TheftInfo = {
	Victim: Player,
	ItemUid: string,
	ItemId: string,
	SlotIndex: number,
}

type StartedListener = (thief: Player, victim: Player, itemId: string) -> ()
type EndedListener = (thief: Player, victim: Player, itemId: string, result: TheftResult, reason: string) -> ()

-- Boutique à la porte cassée, ouverte au vol jusqu'à la reconstruction (vague 33 : sans chrono). Victim
-- nil : la boutique du bot joueur.
type Shop = {
	Plot: Model,
	Victim: Player?,
	WindowId: string,
	Breaker: Player?, -- celui qui a cassé la porte (alerte d'intrusion)
}

type Hold = {
	Plot: Model,
	Victim: Player?, -- nil : le bot joueur
	Slot: number, -- 0 : objet sous antivol au sol (Floor)
	Uid: string,
	StartedAt: number, -- os.clock()
	Floor: boolean, -- vague 31 : objet sous antivol posé au sol (StealFloorItem), pas un présentoir
}

type Theft = {
	Thief: Player,
	Victim: Player?, -- nil : le bot joueur
	Plot: Model, -- boutique de la victime
	Uid: string,
	ItemId: string,
	Slot: number, -- 0 : objet sous antivol pris au sol (Floor)
	Floor: boolean, -- vague 31 (L-112) : objet sous antivol pris au sol de la victime (UnboxService)
	Payload: PlayerItemPayload, -- la table donnée à StartCarry (CarryService la garde telle quelle)
	StartedAt: number, -- os.clock() de la prise
	From: Vector3, -- position du voleur à la prise (contrôle du dépôt)
}

-- Pièces du contrat 10.4 d'une parcelle, trouvées avant que DisplayService y pose des objets.
type PlotRefs = {
	Bounds: BasePart?,
	Deposit: BasePart?,
	Slots: { [number]: Attachment? },
}

-- Noms du contrat (10.4).
local BOUNDS = "Bounds"
local DEPOSIT_ZONE = "DepositZone"
local SLOT_FORMAT = "DisplaySlot_%02d"
-- Attributs posés par ce service sur la parcelle (mêmes noms dans PvPController).
local OPEN_ATTRIBUTE = "StealOpen"
local SAFE_SLOTS_ATTRIBUTE = "SafeSlots"
-- Posé sur le Player interdit de voler une boutique (même nom dans PvPController).
local ROB_COOLDOWN_FORMAT = "RobCooldown_%d"
local PLOT_INDEX_ATTRIBUTE = "PlotIndex" -- numéro de la parcelle, posé par PlotService

-- V0 proposé, absent du doc : services, joueurs et maintiens vérifiés 10 fois par seconde (comme
-- StoreHeistService) ; attributs de la parcelle publiés toutes les PUBLISH_EVERY images.
local TICK = 0.1
local PUBLISH_EVERY = 5
-- V0 proposé, absent du doc : après WindowService et StoreHeistService (110), avant les écrans.
local PRIORITY = 120
-- V0 proposé, absent du doc : écart du réseau toléré sur la durée de maintien, et expiration d'un
-- maintien non conclu (comme GrabItem).
local GRAB_TIME_TOLERANCE = 0.1
local HOLD_EXPIRY = 1
-- V0 proposé, absent du doc : au plus un message de refus par raison toutes les 3 s.
local NOTICE_INTERVAL = 3
-- V0 proposé, absent du doc : marge du contrôle du dépôt (voir l'en-tête), en secondes.
local ESCAPE_MARGIN = 0.5
-- Filet contre les téléportations : le plafond de vitesse, large exprès (le voleur porte à vitesse fixe,
-- Balance.Carry.StolenItemWalkSpeed, et AntiCheatService.Verify suit déjà sa vitesse réelle).
local MAX_ESCAPE_SPEED = Balance.Stats.MaxWalkSpeed * Balance.AntiCheat.SpeedTolerance

-- Bot joueur (voir l'en-tête) : ce que ce service lit et appelle chez BotService. require protégé : sans
-- BotService (anciens bancs), aucune boutique de bot.
type BotApi = {
	IsBotPlot: (plot: Model) -> boolean,
	GetExposed: (plot: Model) -> { [number]: DisplayService.ExposedItem },
	Hold: (plot: Model, uid: string, thief: Player) -> boolean,
	Release: (plot: Model, uid: string, thief: Player) -> boolean,
	IsHeld: (plot: Model, uid: string) -> boolean,
	TakeHeld: (plot: Model, uid: string, thief: Player) -> boolean,
}
local botModule = script.Parent:FindFirstChild("BotService")
local botLoaded: boolean, botResult: any = false, nil
if botModule and botModule:IsA("ModuleScript") then
	botLoaded, botResult = pcall(require, botModule)
end
local Bot: BotApi? = if botLoaded and type(botResult) == "table" and type(botResult.IsBotPlot) == "function"
	then botResult :: any
	else nil

local function isBotPlot(plot: Model): boolean
	local api = Bot
	if api == nil then
		return false
	end
	return api.IsBotPlot(plot)
end

-- Défense par le propriétaire (voir l'en-tête) : ce que ce service utilise de BatService. require protégé :
-- sans BatService (anciens bancs), pas de défense par le propriétaire.
type BatApi = {
	IsIntruder: (hitter: Player, target: Player) -> boolean,
	OnHit: (listener: (hitter: Player, target: Player, usage: string, payload: any) -> ()) -> () -> (),
}
local batModule = script.Parent:FindFirstChild("BatService")
local batLoaded: boolean, batResult: any = false, nil
if batModule and batModule:IsA("ModuleScript") then
	batLoaded, batResult = pcall(require, batModule)
end
local BatHooks: BatApi? = if batLoaded and type(batResult) == "table" and type(batResult.OnHit) == "function"
	then batResult :: any
	else nil

-- Vague 31 (L-112) : objets sous antivol posés au sol (UnboxService ; voir l'en-tête). require protégé : sans
-- UnboxService (anciens bancs), aucun objet au sol à voler. UnboxService ne requiert pas ce service.
type FloorItem = {
	Uid: string,
	ItemId: string,
	Rarity: string,
	Income: number,
	Position: Vector3,
	UnlockAt: number,
}
type FloorApi = {
	GetFloorItem: (owner: Player, itemUid: string) -> FloorItem?,
	IsStealable: (owner: Player, itemUid: string) -> boolean,
	HoldFloorItem: (owner: Player, itemUid: string) -> boolean,
	ReleaseFloorItem: (owner: Player, itemUid: string) -> boolean,
	TakeFloorItem: (owner: Player, itemUid: string) -> boolean,
	IsFloorHeld: (owner: Player, itemUid: string) -> boolean,
}
local floorModule = script.Parent:FindFirstChild("UnboxService")
local floorLoaded: boolean, floorResult: any = false, nil
if Features.ShelfOpen and floorModule and floorModule:IsA("ModuleScript") then
	floorLoaded, floorResult = pcall(require, floorModule)
end
local Floor: FloorApi? = if floorLoaded and type(floorResult) == "table" and type(floorResult.HoldFloorItem) == "function"
	then floorResult :: any
	else nil

-- Messages lus par les joueurs (Notify), en anglais (L-036) ; nombres par Shared/Format.
local MESSAGES: { [string]: string } = {
	DoorSmashed = "%s smashed your shop door! Defend your shop!",
	Stealing = "%s is stealing your %s! Hit them with your bat!",
	Grabbed = "You grabbed the %s: run back to your shop!",
	Stolen = "You stole the %s: %s!",
	StolenToInventory = "You stole the %s: it went to your inventory (your stands are full).",
	Robbed = "%s stole your %s!",
	Returned = "Your %s is back on its stand!",
	Lost = "The %s went back to its owner.",
	-- Défense par le propriétaire (V0, à valider par Clément) :
	KickedOut = "Kicked out! You can rob this shop again in %ds.", -- à l'intrus frappé par le propriétaire
	Eliminated = "Eliminated! You can rob this shop again in %ds.", -- au joueur mort dans la boutique d'un autre
	RobCooldown = "You can rob this shop again in %ds.", -- refus pendant l'interdiction, et voleur frappé dehors
	IntruderOut = "%s was kicked out of your shop!", -- au propriétaire
	Safe = "This item is in the safe: nobody can steal it.",
	Full = "Your shop is full: make room before stealing.",
	NoShop = "You need a shop to steal.",
	DoorBack = "The door is fixed: you were moved outside.",
	NotYourShop = "Only the owner can be inside this shop.",
	-- Vague 31 (L-112), objet sous antivol volé au sol, V0 proposés, absents du doc :
	StolenLocked = "You stole the %s! Put it down in your shop: its anti-theft starts there.",
	FloorReturned = "Your %s is back in your shop!",
	FullInventory = "Your inventory is full: make room before stealing.",
}

local IS_STUDIO = RunService:IsStudio()

local PvPService = {}
PvPService.Priority = PRIORITY

local shops: { [Model]: Shop } = {}
local holds: { [Player]: Hold } = {}
local thefts: { [Player]: Theft } = {}
-- Alerte d'intrusion (vague 33) : intrus annoncés à chaque victime, dans l'ordre d'arrivée.
local intruders: { [Player]: { Player } } = {}
-- Interdictions de voler une boutique (voir l'en-tête) : heure serveur de fin, par joueur et par boutique.
local robBans: { [Player]: { [Model]: number } } = {}
-- Dernier personnage vu mort, pour ne compter chaque mort qu'une fois. Clés faibles.
local deathSeen: { [Player]: Model } = setmetatable({}, { __mode = "k" }) :: any
-- Joueurs dont PlayerRemoving est passé. Clés faibles : l'entrée part avec le Player.
local leaving: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local lastNotice: { [Player]: { [string]: number } } = {}
local lastRefusal: { [Player]: number } = {}
local refsOf: { [Model]: PlotRefs } = {}
local startedListeners: { StartedListener } = {}
local endedListeners: { EndedListener } = {}
local previousCanBeHit: ((player: Player, windowId: string) -> boolean)? = nil
local publishCount = 0

-- Outils ------------------------------------------------------------------------------------------

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
		print(`[PvPService] {message}`)
	end
end

-- Refus anormal : signalé en Studio seulement (aide au test), une ligne par seconde et par joueur.
local function refuse(player: Player, what: string, reason: string)
	if not IS_STUDIO then
		return
	end
	local now = os.clock()
	if now - (lastRefusal[player] or -math.huge) < 1 then
		return
	end
	lastRefusal[player] = now
	warn(`[PvPService] {what} de {player.Name} refusé : {reason}`)
end

local function notify(player: Player, message: string, kind: string)
	if player.Parent ~= Players then
		return
	end
	local ok, err = pcall(function()
		Net.Server.Notify:Fire(player, message, kind)
	end)
	if not ok then
		warn(`[PvPService] Notify vers {player.Name} : {err}`)
	end
end

-- Message de refus, au plus un par raison toutes les NOTICE_INTERVAL s (coups à 10 par seconde).
local function notice(player: Player, key: string, message: string)
	local byKey = lastNotice[player] or {}
	lastNotice[player] = byKey
	local now = os.clock()
	if now - (byKey[key] or -math.huge) < NOTICE_INTERVAL then
		return
	end
	byKey[key] = now
	notify(player, message, "Warning")
end

local function itemName(itemId: string): string
	local item = Items.ById[itemId]
	return if item then item.DisplayName else itemId
end

local function inside(part: BasePart, point: Vector3): boolean
	local p = part.CFrame:PointToObjectSpace(point)
	local h = part.Size / 2
	return math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z
end

-- Dans l'emprise au sol de la pièce (sa hauteur n'est pas lue) : la DepositZone « couvre tout le sol
-- intérieur » (relevé Studio), sa hauteur exacte ne compte pas ; le volume Bounds dit qu'on est dedans.
local function overFootprint(part: BasePart, point: Vector3): boolean
	local p = part.CFrame:PointToObjectSpace(point)
	local h = part.Size / 2
	return math.abs(p.X) <= h.X and math.abs(p.Z) <= h.Z
end

-- HumanoidRootPart d'un joueur vivant, ou nil.
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

local function isCarrying(player: Player): boolean
	local ok, carrying = pcall(CarryService.IsCarrying, player)
	return ok and carrying == true
end

-- Le joueur est-il là, et pas en train de partir ?
local function present(player: Player): boolean
	return player.Parent == Players and not leaving[player]
end

local function refsFor(plot: Model): PlotRefs
	local cached = refsOf[plot]
	if cached then
		return cached
	end
	local bounds = Find.path(plot, BOUNDS)
	local deposit = Find.path(plot, DEPOSIT_ZONE)
	local slots: { [number]: Attachment? } = {}
	for index = 1, Balance.Display.MaxSlots do
		local found = Find.path(plot, string.format(SLOT_FORMAT, index))
		if found and found:IsA("Attachment") then
			slots[index] = found :: Attachment
		end
	end
	-- Présentoirs bonus du gamepass « +4 présentoirs » (DEV-100) : DisplaySlot_21 et suivants, à la
	-- suite, optionnels (même règle et même borne V0 de 10 que DisplayService) : leurs objets se volent
	-- comme les autres.
	for index = Balance.Display.MaxSlots + 1, Balance.Display.MaxSlots + 10 do
		local found = Find.path(plot, string.format(SLOT_FORMAT, index))
		if found == nil or not found:IsA("Attachment") then
			break
		end
		slots[index] = found :: Attachment
	end
	local refs: PlotRefs = {
		Bounds = if bounds and bounds:IsA("BasePart") then bounds :: BasePart else nil,
		Deposit = if deposit and deposit:IsA("BasePart") then deposit :: BasePart else nil,
		Slots = slots,
	}
	refsOf[plot] = refs
	return refs
end

local function plotOfWindow(windowId: string): Model?
	for _, plot in PlotService.GetPlots() do
		if WindowService.GetWindowId(plot) == windowId then
			return plot
		end
	end
	return nil
end

-- Interdiction de voler une boutique (défense par le propriétaire, voir l'en-tête) -----------------

local function cooldownAttribute(plot: Model): string?
	local index = plot:GetAttribute(PLOT_INDEX_ATTRIBUTE)
	if type(index) ~= "number" then
		return nil
	end
	return string.format(ROB_COOLDOWN_FORMAT, index)
end

local function clearBan(player: Player, plot: Model)
	local byPlot = robBans[player]
	if byPlot == nil or byPlot[plot] == nil then
		return
	end
	byPlot[plot] = nil
	if next(byPlot) == nil then
		robBans[player] = nil
	end
	local name = cooldownAttribute(plot)
	if name and player.Parent == Players then
		player:SetAttribute(name, nil)
	end
end

-- Secondes restantes de l'interdiction de `player` sur `plot` (0 : aucune ; une interdiction finie est
-- oubliée ici).
local function banLeft(player: Player, plot: Model): number
	local byPlot = robBans[player]
	local endsAt = if byPlot then byPlot[plot] else nil
	if endsAt == nil then
		return 0
	end
	local left = endsAt - Workspace:GetServerTimeNow()
	if left <= 0 then
		clearBan(player, plot)
		return 0
	end
	return left
end

-- `player` ne peut plus voler `plot` pendant PvP.KickRobCooldown s (une interdiction en cours repart à zéro).
local function ban(player: Player, plot: Model, why: string)
	local endsAt = Workspace:GetServerTimeNow() + PvP.KickRobCooldown
	local byPlot = robBans[player] or {}
	robBans[player] = byPlot
	byPlot[plot] = endsAt
	local name = cooldownAttribute(plot)
	if name then
		player:SetAttribute(name, endsAt)
	end
	log(`{player.Name} ne peut plus voler {plot.Name} pendant {PvP.KickRobCooldown} s ({why})`)
end

local function cooldownMessage(format: string, left: number): string
	return string.format(format, math.max(1, math.ceil(left)))
end

-- Objets exposés de la boutique `plot` : ceux de `victim`, ou ceux du bot (victim nil).
local function exposedOf(plot: Model, victim: Player?): { [number]: DisplayService.ExposedItem }
	if victim then
		return DisplayService.GetExposed(victim)
	end
	local api = Bot
	return if api then api.GetExposed(plot) else {}
end

-- Échec d'un vol : l'objet tenu revient sur son présentoir, chez `victim` ou chez le bot (victim nil).
local function releaseItem(plot: Model, victim: Player?, uid: string, thief: Player)
	if victim then
		DisplayService.Release(victim, uid)
		return
	end
	local api = Bot
	if api then
		api.Release(plot, uid, thief)
	end
end

-- Nombre de présentoirs à l'abri chez `owner` : PvPService.GetVaultSlots (arbre de compétences, Safe),
-- un entier ≥ PvP.VaultSlots ; une erreur ou une valeur invalide reprend PvP.VaultSlots.
local vaultWarned = false
local function vaultSlotsOf(owner: Player): number
	local ok, value = pcall(PvPService.GetVaultSlots, owner)
	if not ok then
		if not vaultWarned then
			vaultWarned = true
			warn(`[PvPService] GetVaultSlots : erreur ({value}), {PvP.VaultSlots} présentoir(s) à l'abri`)
		end
		return PvP.VaultSlots
	end
	if type(value) ~= "number" or value ~= value or value == math.huge then
		return PvP.VaultSlots
	end
	return math.max(PvP.VaultSlots, math.floor(value))
end

-- Coffre-fort V0 : présentoirs à l'abri parmi les objets exposés de `owner` (voir l'en-tête) ; le bot
-- (owner nil) en a PvP.VaultSlots.
local function safeSlotsOf(owner: Player?, exposed: { [number]: DisplayService.ExposedItem }): { [number]: boolean }
	local list: { number } = {}
	for slot in exposed do
		table.insert(list, slot)
	end
	table.sort(list, function(a: number, b: number): boolean
		local ia, ib = exposed[a].Income, exposed[b].Income
		if ia ~= ib then
			return ia > ib
		end
		return a < b
	end)
	local safe: { [number]: boolean } = {}
	for index = 1, math.min(if owner then vaultSlotsOf(owner) else PvP.VaultSlots, #list) do
		safe[list[index]] = true
	end
	return safe
end

-- Remplace WindowService.CanBeHit (voir l'en-tête).
local function canBeHit(player: Player, windowId: string): boolean
	local plot = plotOfWindow(windowId)
	if plot then
		local victim = PlotService.GetOwner(plot)
		if victim == player or not present(player) or DataService.Get(player) == nil then
			return false
		end
		if victim then
			if not present(victim) or DataService.Get(victim) == nil then
				return false
			end
		elseif not isBotPlot(plot) then
			return false -- boutique libre
		end
		local left = banLeft(player, plot)
		if left > 0 then
			notice(player, "RobCooldown", cooldownMessage(MESSAGES.RobCooldown, left))
			return false
		end
	end
	local previous = previousCanBeHit
	return previous == nil or previous(player, windowId)
end

-- Ouverture et fermeture --------------------------------------------------------------------------

local function closeShop(shop: Shop, why: string)
	local plot = shop.Plot
	if shops[plot] ~= shop then
		return
	end
	shops[plot] = nil
	plot:SetAttribute(OPEN_ATTRIBUTE, nil)
	for player, hold in holds do
		if hold.Plot == plot then
			holds[player] = nil
		end
	end
	log(`{plot.Name} : fenêtre de vol fermée ({why})`)
end

-- Vague 33 (Cantin, 2026-11-13) : plus de chrono chez un joueur, la boutique reste ouverte au vol jusqu'à
-- la reconstruction de sa porte (voir l'en-tête).
local function openShop(plot: Model, victim: Player?, windowId: string, breaker: Player?)
	local existing = shops[plot]
	if existing then
		closeShop(existing, "nouvelle casse")
	end
	local shop: Shop = {
		Plot = plot,
		Victim = victim,
		WindowId = windowId,
		Breaker = breaker,
	}
	shops[plot] = shop
	plot:SetAttribute(OPEN_ATTRIBUTE, true)
	local whose = if victim then `de {victim.Name}` else "du bot"
	log(`{plot.Name} {whose} : porte cassée par {if breaker then breaker.Name else "?"}, ouverte au vol sans chrono`)
end

-- Point d'attente de la reconstruction (WindowService.AddRebuildGate, vague 33) : la porte d'une boutique
-- (joueur ou bot) reste cassée tant qu'un non-propriétaire présent, profil chargé et vivant est dans son
-- volume Bounds. true pour toute autre vitrine, et pour une boutique libre.
local function rebuildGate(_windowId: string, model: Model?): boolean
	if model == nil or not table.find(PlotService.GetPlots(), model) then
		return true
	end
	local owner = PlotService.GetOwner(model)
	if owner == nil and not isBotPlot(model) then
		return true
	end
	local bounds = refsFor(model).Bounds
	if bounds == nil then
		return true
	end
	for _, player in Players:GetPlayers() do
		if player ~= owner and present(player) and DataService.Get(player) ~= nil then
			local root = rootOf(player)
			if root and inside(bounds, root.Position) then
				return false
			end
		end
	end
	return true
end

-- Alerte d'intrusion (voir l'en-tête) ---------------------------------------------------------------------

-- Dans le volume `part` agrandi de `margin` studs de chaque côté.
local function near(part: BasePart, point: Vector3, margin: number): boolean
	local p = part.CFrame:PointToObjectSpace(point)
	local h = part.Size / 2 + Vector3.new(margin, margin, margin)
	return math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z
end

-- Intrus de la boutique `shop` de `victim` maintenant (ordre de Players:GetPlayers).
local function currentIntruders(shop: Shop, victim: Player): { Player }
	local list: { Player } = {}
	local plot = shop.Plot
	local bounds = refsFor(plot).Bounds
	if bounds == nil then
		return list
	end
	for _, player in Players:GetPlayers() do
		if player == victim or not present(player) or DataService.Get(player) == nil or banLeft(player, plot) > 0 then
			continue
		end
		local theft = thefts[player]
		if theft and theft.Victim == victim then
			continue -- son alerte avec l'objet passe avant
		end
		local root = rootOf(player)
		if root == nil then
			continue
		end
		if inside(bounds, root.Position) or (player == shop.Breaker and near(bounds, root.Position, PvP.ScoutDistance)) then
			table.insert(list, player)
		end
	end
	return list
end

-- TheftAlert(false), puis les intrus de `list`, puis les vols en cours chez `victim` (plus ancien d'abord).
local function reannounce(victim: Player, list: { Player })
	Net.Server.TheftAlert:Fire(victim, false)
	for _, player in list do
		Net.Server.TheftAlert:Fire(victim, true, player, nil)
	end
	local ongoing: { Theft } = {}
	for _, theft in thefts do
		if theft.Victim == victim then
			table.insert(ongoing, theft)
		end
	end
	table.sort(ongoing, function(a: Theft, b: Theft): boolean
		return a.StartedAt < b.StartedAt
	end)
	for _, theft in ongoing do
		Net.Server.TheftAlert:Fire(victim, true, theft.Thief, theft.ItemId)
	end
end

-- 10 fois par seconde : intrus nouveaux annoncés, intrus partis retirés (réannonce).
local function intrusionStep()
	local seen: { [Player]: boolean } = {}
	for _, plot in PlotService.GetPlots() do
		local victim = PlotService.GetOwner(plot)
		if victim == nil or not present(victim) then
			continue -- boutique libre ou du bot : pas d'alerte
		end
		seen[victim] = true
		local shop = shops[plot]
		local now: { Player } = if shop and shop.Victim == victim then currentIntruders(shop, victim) else {}
		local stored: { Player }? = intruders[victim]
		local previous: { Player } = if stored then stored else {}
		local kept: { Player } = {}
		local removed = false
		for _, player in previous do
			if table.find(now, player) then
				table.insert(kept, player)
			else
				-- Devenu voleur chez elle : son alerte avec l'objet a déjà remplacé la sienne, rien à retirer.
				local theft = thefts[player]
				if theft == nil or theft.Victim ~= victim then
					removed = true
				end
			end
		end
		local added: { Player } = {}
		for _, player in now do
			if not table.find(kept, player) then
				table.insert(kept, player)
				table.insert(added, player)
			end
		end
		if #kept > 0 then
			intruders[victim] = kept
		else
			intruders[victim] = nil
		end
		if removed then
			reannounce(victim, kept)
		else
			for _, player in added do
				Net.Server.TheftAlert:Fire(victim, true, player, nil)
			end
		end
		for _, player in added do
			log(`{victim.Name} prévenu : {player.Name} est dans sa boutique (porte cassée)`)
		end
	end
	-- Victime partie, ou sans boutique : oubliée (rien à lui envoyer de plus).
	for victim in table.clone(intruders) do
		if not seen[victim] then
			intruders[victim] = nil
		end
	end
end

-- Sortie devant la porte ----------------------------------------------------------------------------

-- Sort `player` de la boutique `plot` s'il est dans son volume Bounds. true s'il a été sorti.
local function putOut(player: Player, plot: Model, bounds: BasePart): boolean
	local root = rootOf(player)
	if root == nil or not inside(bounds, root.Position) or not PlotService.PutOutside(player, plot) then
		return false
	end
	local theft = thefts[player]
	local outside = rootOf(player)
	if theft and outside then
		-- Déplacement fait par le serveur : le contrôle du dépôt repart d'ici.
		theft.From = outside.Position
		theft.StartedAt = os.clock()
	end
	return true
end

-- Sort de la boutique `plot` les non-propriétaires qui sont dans son volume Bounds (seulement ceux
-- qu'accepte `only`, s'il est donné). Renvoie les joueurs sortis.
local function ejectFrom(plot: Model, owner: Player?, only: ((Player) -> boolean)?): { Player }
	local moved: { Player } = {}
	local bounds = refsFor(plot).Bounds
	if bounds == nil then
		return moved
	end
	for _, player in Players:GetPlayers() do
		-- Un joueur qui part (profil déjà libéré) reste où il est : c'est souvent l'ancien propriétaire.
		if player ~= owner and present(player) and DataService.Get(player) ~= nil and (only == nil or only(player)) then
			if putOut(player, plot, bounds) then
				table.insert(moved, player)
			end
		end
	end
	return moved
end

local function ejectStep()
	for _, plot in PlotService.GetPlots() do
		-- Parcelle libre comprise : ses murs et sa porte sont solides pour tous, on y serait enfermé.
		local owner = PlotService.GetOwner(plot)
		local windowId = WindowService.GetWindowId(plot)
		if shops[plot] == nil and windowId ~= nil and not WindowService.IsBroken(windowId) then
			for _, player in ejectFrom(plot, owner) do
				notice(player, "NotYourShop", MESSAGES.NotYourShop)
				log(`{player.Name} sorti de {plot.Name} : porte intacte, ce n'est pas sa boutique`)
			end
			continue
		end
		-- Porte cassée ou boutique ouverte au vol : on entre librement jusqu'à la reconstruction, sauf un
		-- joueur interdit de voler cette boutique (défense par le propriétaire).
		local function banned(player: Player): boolean
			return banLeft(player, plot) > 0
		end
		for _, player in ejectFrom(plot, owner, banned) do
			notice(player, "RobCooldown", cooldownMessage(MESSAGES.RobCooldown, banLeft(player, plot)))
			log(`{player.Name} ressorti de {plot.Name} : interdit de la voler encore {math.ceil(banLeft(player, plot))} s`)
		end
	end
end

-- Fin d'un vol ------------------------------------------------------------------------------------------

-- Vols chez un vrai joueur seulement : un vol au bot ne prévient personne (voir l'en-tête).
local function emitEnded(theft: Theft, result: TheftResult, reason: string)
	local victim = theft.Victim
	if victim == nil then
		return
	end
	for _, listener in table.clone(endedListeners) do
		task.spawn(listener, theft.Thief, victim, theft.ItemId, result, reason)
	end
end

-- Échec : l'objet revient sur son présentoir (le profil de la victime n'a jamais changé).
local function returnItem(theft: Theft, reason: string)
	if thefts[theft.Thief] ~= theft then
		return
	end
	thefts[theft.Thief] = nil
	local victim = theft.Victim
	local floorApi = Floor
	if theft.Floor then
		-- Vague 31 : l'objet sous antivol revient à sa place au sol (son antivol a continué de courir).
		if victim and floorApi then
			floorApi.ReleaseFloorItem(victim, theft.Uid)
		end
	else
		releaseItem(theft.Plot, victim, theft.Uid, theft.Thief)
	end
	local name = itemName(theft.ItemId)
	if victim and present(victim) then
		Net.Server.TheftAlert:Fire(victim, false)
		notify(victim, string.format(if theft.Floor then MESSAGES.FloorReturned else MESSAGES.Returned, name), "Info")
	end
	if reason ~= "Left" and reason ~= "NoRoom" then
		notify(theft.Thief, string.format(MESSAGES.Lost, name), "Alert")
	end
	local back = if theft.Floor then "revient au sol" else `revient sur le présentoir {theft.Slot}`
	log(`vol de {theft.Thief.Name} chez {if victim then victim.Name else "le bot"} raté ({reason}) : {theft.ItemId} {back}`)
	emitEnded(theft, "Returned", reason)
end

-- Fait échouer le vol : le portage finit (CarryService prévient onCarryEnded, qui rend l'objet). Si
-- le portage avait déjà disparu, l'objet est rendu ici.
local function abandon(theft: Theft, reason: string)
	pcall(CarryService.Fail, theft.Thief, reason)
	if thefts[theft.Thief] == theft then
		returnItem(theft, reason)
	end
end

local function onCarryEnded(player: Player, payload: any, _result: string, reason: string)
	if type(payload) ~= "table" or payload.Kind ~= "PlayerItem" then
		return
	end
	local theft = thefts[player]
	if theft == nil or theft.Payload ~= payload then
		return -- déjà réglé (dépôt) : rien à rendre
	end
	-- Toute autre fin (batte, mort, départ, anomalie… et un Consume qui ne vient pas d'ici) : l'objet revient.
	returnItem(theft, reason)
end

-- Dépôt : transfert sûr (voir l'en-tête). Sans yield.
local function deposit(theft: Theft, root: BasePart)
	local thief, victim = theft.Thief, theft.Victim
	if not present(thief) or (victim and not present(victim)) or (victim == nil and not isBotPlot(theft.Plot)) then
		return -- le départ (du bot compris) va annuler le vol
	end
	local thiefData = DataService.Get(thief)
	local victimData = if victim then DataService.Get(victim) else nil
	if thiefData == nil or (victim and victimData == nil) then
		return -- profil en cours de libération : le départ va annuler le vol
	end
	-- Contrôle des déplacements tout de suite (DEV-060), sans attendre le suivant, et du trajet depuis la
	-- prise (à la vitesse réelle du voleur) : un téléport dans sa propre DepositZone ou un speed hack
	-- entre deux boutiques proches sont vus avant le transfert. Sanctionné : le portage vient d'échouer.
	if not AntiCheatService.Verify(thief, theft.From, theft.StartedAt) then
		if thefts[thief] == theft then
			returnItem(theft, "Anomaly")
		end
		return
	end
	local elapsed = os.clock() - theft.StartedAt
	local distance = (root.Position - theft.From).Magnitude
	if distance > MAX_ESCAPE_SPEED * (elapsed + ESCAPE_MARGIN) then
		CarryService.ReportAnomaly(thief, `objet volé déposé à {math.round(distance)} studs en {math.round(elapsed * 10) / 10} s`)
		if thefts[thief] == theft then
			returnItem(theft, "Anomaly")
		end
		return
	end
	if CarryService.GetPayload(thief) ~= theft.Payload then
		warn(`[PvPService] {thief.Name} : le portage n'est plus celui du vol, objet rendu`)
		abandon(theft, "Anomaly")
		return
	end
	-- L'objet est toujours le même : dans le profil de la victime et tenu chez elle, ou tenu chez le bot.
	local entry = if victimData then victimData.Items[theft.Uid] else nil
	local bot = Bot
	local floorApi = Floor
	local same: boolean
	if theft.Floor then
		-- Vague 31 : l'objet sous antivol est toujours dans le profil de la victime et porté depuis son sol.
		same = victim ~= nil and entry ~= nil and entry.Id == theft.ItemId and floorApi ~= nil and floorApi.IsFloorHeld(victim, theft.Uid)
	elseif victim and victimData then
		same = entry ~= nil and entry.Id == theft.ItemId and DisplayService.IsHeld(victim, theft.Uid)
	else
		same = bot ~= nil and bot.IsHeld(theft.Plot, theft.Uid)
	end
	if not same or thiefData.Items[theft.Uid] ~= nil then
		warn(`[PvPService] {thief.Name} : l'objet {theft.Uid} n'est plus le même chez {if victim then victim.Name else "le bot"}, vol annulé`)
		abandon(theft, "Anomaly")
		return
	end
	-- Objet sous antivol : il arrive dans l'inventaire (jamais sur un présentoir) ; sinon, présentoir ou inventaire.
	local room = if theft.Floor then DisplayService.HasInventoryRoom(thief) else DisplayService.HasRoom(thief)
	if not room then
		notify(thief, if theft.Floor then MESSAGES.FullInventory else MESSAGES.Full, "Warning")
		abandon(theft, "NoRoom")
		return
	end

	-- Transfert, d'un seul tenant.
	thefts[thief] = nil
	if theft.Floor and victim and victimData and floorApi then
		floorApi.TakeFloorItem(victim, theft.Uid)
		victimData.Items[theft.Uid] = nil
	elseif victim and victimData then
		DisplayService.TakeHeld(victim, theft.Uid)
		victimData.Items[theft.Uid] = nil
	elseif bot then
		bot.TakeHeld(theft.Plot, theft.Uid, thief) -- le bot n'a pas de profil : il le remplacera plus tard
	end
	-- La mutation suit l'objet (DEV-131), comme sa zone. Objet du bot : zone du catalogue, sans mutation.
	local def = Items.ById[theft.ItemId]
	local zone = if entry then entry.Zone elseif def then def.Zone else nil
	local mutation = Mutations.Sanitize(if entry then entry.Mutation else nil)
	-- Vague 31 (L-112, décision a105) : un objet volé pendant son antivol redevient un objet sous antivol chez le
	-- voleur, dans son inventaire ; l'attente repart de zéro à sa pose au sol (UnlockAt et Spot non recopiés).
	thiefData.Items[theft.Uid] = {
		Id = theft.ItemId,
		Source = "PvP",
		At = os.time(),
		Zone = zone,
		Mutation = mutation,
		AntiTheft = if theft.Floor then true else nil,
	}
	local slot = if theft.Floor then nil else DisplayService.PlaceAuto(thief, theft.Uid, root.Position)
	CarryService.Consume(thief, "Deposited")

	-- Un vol au bot ne compte pas pour les classements (en-tête).
	if victim then
		local lifetime = (thiefData :: any).Lifetime
		if type(lifetime) == "table" and type(lifetime.Steals) == "number" then
			lifetime.Steals += 1
		else
			warn(`[PvPService] {thief.Name} : Lifetime absent du profil, vol non compté`)
		end
		Net.Server.TheftAlert:Fire(victim, false)
	end
	local name = itemName(theft.ItemId)
	if theft.Floor then
		notify(thief, string.format(MESSAGES.StolenLocked, name), "Info")
	elseif slot then
		notify(thief, string.format(MESSAGES.Stolen, name, Format.income(theft.Payload.Income)), "Info")
	else
		notify(thief, string.format(MESSAGES.StolenToInventory, name), "Info")
	end
	-- Les deux sauvegardes tout de suite (la victime d'abord), plutôt qu'à la sauvegarde automatique :
	-- seul un arrêt brutal du serveur pendant ces deux écritures pourrait encore créer un écart.
	if victim then
		notify(victim, string.format(MESSAGES.Robbed, thief.DisplayName, name), "Alert")
		DataService.Save(victim)
	end
	DataService.Save(thief)
	local where = if slot then `présentoir {slot}` else "inventaire"
	if victim then
		log(`{thief.Name} a volé {theft.ItemId} ({theft.Uid}) à {victim.Name} : {where}`)
	else
		log(`{thief.Name} a volé {theft.ItemId} ({theft.Uid}) au bot : {where}`)
	end
	emitEnded(theft, "Stolen", "Deposited")
end

-- Prise ------------------------------------------------------------------------------------------------------

-- Partie commune aux prises sur un présentoir et au sol (vague 31) : la boutique, les deux joueurs, le
-- voleur (mains vides, interdiction, boutique, vivant, dans Bounds). nil si tout va.
local function shopRefusal(player: Player, plot: Model): (string?, string?, string?)
	local victim = PlotService.GetOwner(plot) -- nil : boutique libre, ou celle du bot
	if victim == nil and not isBotPlot(plot) then
		return "boutique libre", nil, nil
	end
	if victim == player then
		return "sa propre boutique", nil, nil
	end
	local shop = shops[plot]
	if shop == nil or shop.Victim ~= victim then
		return "boutique fermée (porte intacte ou 10 s écoulées)", nil, nil
	end
	if not present(player) or (victim and not present(victim)) then
		return "départ en cours", nil, nil
	end
	local victimData = if victim then DataService.Get(victim) else nil
	if DataService.Get(player) == nil or (victim and victimData == nil) then
		return "profil pas chargé", nil, nil
	end
	if thefts[player] or isCarrying(player) then
		return "mains pleines", nil, nil
	end
	local left = banLeft(player, plot)
	if left > 0 then
		return `interdit de voler cette boutique encore {math.ceil(left)} s (sorti par le propriétaire ou mort dedans)`,
			"RobCooldown",
			cooldownMessage(MESSAGES.RobCooldown, left)
	end
	if PlotService.GetPlot(player) == nil then
		return "pas de boutique", "NoShop", MESSAGES.NoShop
	end
	local root = rootOf(player)
	if root == nil then
		return "pas de personnage vivant", nil, nil
	end
	local refs = refsFor(plot)
	local bounds = refs.Bounds
	if bounds == nil then
		return "boutique sans volume Bounds", nil, nil
	end
	if not inside(bounds, root.Position) then
		return "hors du volume Bounds", nil, nil
	end
	return nil, nil, nil
end

-- Raison du refus d'une prise sur le présentoir `slot` de `plot` (texte pour la sortie de Studio) et,
-- pour un joueur honnête, la clé et le texte du message à lui envoyer ; nil si la prise est permise.
local function stealRefusal(player: Player, plot: Model, slot: number): (string?, string?, string?)
	local reason, key, message = shopRefusal(player, plot)
	if reason then
		return reason, key, message
	end
	local victim = PlotService.GetOwner(plot)
	local victimData = if victim then DataService.Get(victim) else nil
	local root = rootOf(player) :: BasePart
	local refs = refsFor(plot)
	local attachment = refs.Slots[slot]
	if attachment == nil then
		return `présentoir {slot} absent de la boutique`, nil, nil
	end
	local distance = (root.Position - attachment.WorldPosition).Magnitude
	if distance > PvP.StealMaxDistance then
		return `trop loin ({math.round(distance * 10) / 10} studs)`, nil, nil
	end
	local exposed = exposedOf(plot, victim)
	local item = exposed[slot]
	if item == nil or (victimData and (victimData.Display[tostring(slot)] ~= item.Uid or victimData.Items[item.Uid] == nil)) then
		return "présentoir vide", nil, nil
	end
	if safeSlotsOf(victim, exposed)[slot] then
		return "objet à l'abri (coffre-fort)", "Safe", MESSAGES.Safe
	end
	if not DisplayService.HasRoom(player) then
		return "plus de place chez le voleur", "Full", MESSAGES.Full
	end
	return nil, nil, nil
end

-- Vague 31 (L-112) : refus d'une prise de l'objet sous antivol `uid` posé au sol de `plot`. Mêmes règles que
-- le présentoir (shopRefusal, PvP.StealMaxDistance de l'objet), plus : un vrai joueur (le bot n'a rien au
-- sol), l'antivol court encore (UnboxService.IsStealable), et de la place dans l'inventaire du voleur
-- (l'objet y arrive sous antivol). Pas de coffre-fort : l'objet au sol est volable par décision de Cantin.
local function floorRefusal(player: Player, plot: Model, uid: string): (string?, string?, string?)
	local api = Floor
	if api == nil then
		return "objets au sol coupés (Features.ShelfOpen ou UnboxService absent)", nil, nil
	end
	local reason, key, message = shopRefusal(player, plot)
	if reason then
		return reason, key, message
	end
	local victim = PlotService.GetOwner(plot)
	if victim == nil then
		return "boutique du bot : aucun objet au sol", nil, nil
	end
	local item = api.GetFloorItem(victim, uid)
	if item == nil or not api.IsStealable(victim, uid) then
		return "aucun objet sous antivol de ce nom au sol (absent, porté ou débloqué)", nil, nil
	end
	local root = rootOf(player) :: BasePart
	local distance = (root.Position - item.Position).Magnitude
	if distance > PvP.StealMaxDistance then
		return `trop loin ({math.round(distance * 10) / 10} studs)`, nil, nil
	end
	if not DisplayService.HasInventoryRoom(player) then
		return "plus de place dans l'inventaire du voleur", "FullInventory", MESSAGES.FullInventory
	end
	return nil, nil, nil
end

local beginTheft: (
	thief: Player,
	victim: Player?,
	plot: Model,
	slot: number,
	uid: string,
	def: Items.Item,
	income: number,
	mutation: Mutations.Mutation?,
	floor: boolean,
	root: BasePart
) -> ()

local function grant(thief: Player, victim: Player?, plot: Model, slot: number, uid: string)
	local item = exposedOf(plot, victim)[slot]
	local def = if item then Items.ById[item.ItemId] else nil
	local root = rootOf(thief)
	if item == nil or item.Uid ~= uid or def == nil or root == nil then
		refuse(thief, "StealItem", "objet changé pendant le maintien")
		return
	end
	local bot = Bot
	local held = if victim then DisplayService.Hold(victim, uid) ~= nil else bot ~= nil and bot.Hold(plot, uid, thief)
	if not held then
		refuse(thief, "StealItem", "DisplayService.Hold (ou BotService.Hold) a refusé")
		return
	end
	-- Mutation de l'objet (DEV-131) : sur BB_Carry pendant la fuite (le revenu d'item.Income la compte déjà).
	local victimData = if victim then DataService.Get(victim) else nil
	local victimEntry = if victimData then victimData.Items[uid] else nil
	local mutation = if victimEntry then Mutations.Sanitize(victimEntry.Mutation) else nil
	beginTheft(thief, victim, plot, slot, uid, def, item.Income, mutation, false, root)
end

-- Vague 31 (L-112) : prise de l'objet sous antivol `uid` au sol de `victim` (floorRefusal déjà passé).
local function grantFloor(thief: Player, victim: Player, plot: Model, uid: string)
	local api = Floor
	local item = if api then api.GetFloorItem(victim, uid) else nil
	local def = if item then Items.ById[item.ItemId] else nil
	local root = rootOf(thief)
	if api == nil or item == nil or def == nil or root == nil then
		refuse(thief, "StealFloorItem", "objet changé pendant le maintien")
		return
	end
	if not api.HoldFloorItem(victim, uid) then
		refuse(thief, "StealFloorItem", "UnboxService.HoldFloorItem a refusé")
		return
	end
	local victimData = DataService.Get(victim)
	local victimEntry = if victimData then victimData.Items[uid] else nil
	local mutation = if victimEntry then Mutations.Sanitize(victimEntry.Mutation) else nil
	beginTheft(thief, victim, plot, 0, uid, def, item.Income, mutation, true, root)
end

-- L'objet tenu (présentoir ou sol) part sur la tête du voleur : portage, alertes, écouteurs.
beginTheft = function(
	thief: Player,
	victim: Player?,
	plot: Model,
	slot: number,
	uid: string,
	def: Items.Item,
	income: number,
	mutation: Mutations.Mutation?,
	floor: boolean,
	root: BasePart
)
	local payload: PlayerItemPayload = {
		Kind = "PlayerItem",
		ItemUid = uid,
		ItemId = def.Id,
		Rarity = def.Rarity,
		Income = income,
		VictimUserId = if victim then victim.UserId else 0, -- 0 : le bot (personne ne le défend à la batte)
		SlotIndex = slot, -- 0 : objet pris au sol (vague 31)
		Mutation = mutation,
	}
	local theft: Theft = {
		Thief = thief,
		Victim = victim,
		Plot = plot,
		Uid = uid,
		ItemId = def.Id,
		Slot = slot,
		Floor = floor,
		Payload = payload,
		StartedAt = os.clock(),
		From = root.Position,
	}
	thefts[thief] = theft
	local ok, started = pcall(CarryService.StartCarry, thief, payload)
	if not ok or started ~= true then
		thefts[thief] = nil
		local api = Floor
		if floor and victim and api then
			api.ReleaseFloorItem(victim, uid)
		else
			releaseItem(plot, victim, uid, thief)
		end
		if not ok then
			warn(`[PvPService] CarryService.StartCarry : {started}`)
		end
		refuse(thief, if floor then "StealFloorItem" else "StealItem", "CarryService a refusé le portage")
		return
	end
	local name = itemName(def.Id)
	if victim then
		Net.Server.TheftAlert:Fire(victim, true, thief, def.Id)
		notify(victim, string.format(MESSAGES.Stealing, thief.DisplayName, name), "Alert")
	end
	notify(thief, string.format(MESSAGES.Grabbed, name), "Info")
	local whose = if victim then `de {victim.Name}` else "du bot"
	local where = if floor then "au sol (sous antivol)" else `sur le présentoir {slot}`
	log(`{thief.Name} prend {def.Id} ({uid}) {where} {whose}`)
	if victim then
		for _, listener in table.clone(startedListeners) do
			task.spawn(listener, thief, victim, def.Id)
		end
	end
end

-- StealItem(plotIndex, slotIndex) : premier appel = début du maintien, second = fin (voir l'en-tête).
local function onStealItem(player: Player, plotIndex: number, slotIndex: number)
	local what = `StealItem({plotIndex}, {slotIndex})`
	local plot = PlotService.GetPlotByIndex(plotIndex)
	if plot == nil then
		refuse(player, what, "boutique inconnue")
		return
	end
	if not AntiCheatService.Verify(player) then
		refuse(player, what, "déplacement sanctionné par l'anti-triche (audit 9.8)")
		return
	end
	local hold = holds[player]
	local reason, key, message = stealRefusal(player, plot, slotIndex)
	if reason then
		if hold and hold.Plot == plot and hold.Slot == slotIndex then
			holds[player] = nil
		end
		refuse(player, what, reason)
		if key and message then
			notice(player, key, message)
		end
		return
	end
	local victim = PlotService.GetOwner(plot) -- nil : le bot (stealRefusal l'a vérifié)
	local uid = exposedOf(plot, victim)[slotIndex].Uid
	local now = os.clock()
	if hold and hold.Plot == plot and hold.Slot == slotIndex and hold.Uid == uid then
		local elapsed = now - hold.StartedAt
		if elapsed + GRAB_TIME_TOLERANCE >= PvP.StealGrabTime then
			holds[player] = nil
			grant(player, victim, plot, slotIndex, uid)
		else
			refuse(player, what, `maintien trop court ({math.round(elapsed * 100) / 100} s sur {PvP.StealGrabTime} s)`)
		end
		return
	end
	holds[player] = { Plot = plot, Victim = victim, Slot = slotIndex, Uid = uid, StartedAt = now, Floor = false }
end

-- Vague 31 (L-112) : StealFloorItem(plotIndex, itemUid), objet sous antivol au sol ; deux appels comme StealItem.
local function onStealFloorItem(player: Player, plotIndex: number, itemUid: string)
	local what = `StealFloorItem({plotIndex}, {itemUid})`
	local plot = PlotService.GetPlotByIndex(plotIndex)
	if plot == nil then
		refuse(player, what, "boutique inconnue")
		return
	end
	if not AntiCheatService.Verify(player) then
		refuse(player, what, "déplacement sanctionné par l'anti-triche (audit 9.8)")
		return
	end
	local hold = holds[player]
	local reason, key, message = floorRefusal(player, plot, itemUid)
	if reason then
		if hold and hold.Plot == plot and hold.Floor and hold.Uid == itemUid then
			holds[player] = nil
		end
		refuse(player, what, reason)
		if key and message then
			notice(player, key, message)
		end
		return
	end
	local victim = PlotService.GetOwner(plot) :: Player -- floorRefusal : un vrai joueur
	local now = os.clock()
	if hold and hold.Plot == plot and hold.Floor and hold.Uid == itemUid then
		local elapsed = now - hold.StartedAt
		if elapsed + GRAB_TIME_TOLERANCE >= PvP.StealGrabTime then
			holds[player] = nil
			grantFloor(player, victim, plot, itemUid)
		else
			refuse(player, what, `maintien trop court ({math.round(elapsed * 100) / 100} s sur {PvP.StealGrabTime} s)`)
		end
		return
	end
	holds[player] = { Plot = plot, Victim = victim, Slot = 0, Uid = itemUid, StartedAt = now, Floor = true }
end

-- Attributs de la parcelle -----------------------------------------------------------------------------------

local function setIfChanged(plot: Model, name: string, value: any)
	if plot:GetAttribute(name) ~= value then
		plot:SetAttribute(name, value)
	end
end

local function publish(plot: Model)
	local owner = PlotService.GetOwner(plot) -- nil : boutique libre, ou celle du bot
	local safeText: string? = nil
	if owner or isBotPlot(plot) then
		local slots: { number } = {}
		for slot in safeSlotsOf(owner, exposedOf(plot, owner)) do
			table.insert(slots, slot)
		end
		table.sort(slots)
		if #slots > 0 then
			local parts: { string } = {}
			for _, slot in slots do
				table.insert(parts, tostring(slot))
			end
			safeText = table.concat(parts, ",")
		end
	end
	setIfChanged(plot, SAFE_SLOTS_ATTRIBUTE, safeText)
end

-- Défense par le propriétaire ------------------------------------------------------------------------------------

-- Remplace BatService.IsIntruder : `target` est-il dans le volume Bounds de la boutique de `hitter` ?
local function isIntruder(hitter: Player, target: Player): boolean
	if hitter == target then
		return false
	end
	local plot = PlotService.GetPlot(hitter)
	local bounds = if plot then refsFor(plot).Bounds else nil
	local root = rootOf(target)
	return bounds ~= nil and root ~= nil and inside(bounds, root.Position)
end

-- Coup de batte réussi (BatService.OnHit, l'effet déjà appliqué : l'objet volé au frappeur est déjà revenu).
-- Seuls les coups du propriétaire sur un intrus (« Intruder ») ou sur son voleur (« Defend ») comptent ici.
local function onBatHit(hitter: Player, target: Player, usage: string, _payload: any)
	if usage ~= "Intruder" and usage ~= "Defend" then
		return
	end
	local plot = PlotService.GetPlot(hitter)
	if plot == nil or not present(target) then
		return
	end
	ban(target, plot, if usage == "Intruder" then `frappé dans la boutique par {hitter.Name}` else `frappé par {hitter.Name} avec son objet`)
	local bounds = refsFor(plot).Bounds
	if bounds and putOut(target, plot, bounds) then
		notify(target, cooldownMessage(MESSAGES.KickedOut, PvP.KickRobCooldown), "Alert")
		notify(hitter, string.format(MESSAGES.IntruderOut, target.DisplayName), "Success")
		log(`{target.Name} sorti de {plot.Name} par son propriétaire {hitter.Name}`)
	else
		notify(target, cooldownMessage(MESSAGES.RobCooldown, PvP.KickRobCooldown), "Alert")
	end
end

-- Mort dans la boutique d'un autre (joueur ou bot) : même interdiction sur cette boutique. Chaque mort n'est
-- comptée qu'une fois (dernier personnage vu mort).
local function onDeath(player: Player, character: Model)
	if deathSeen[player] == character or player.Character ~= character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	deathSeen[player] = character
	local position = (root :: BasePart).Position
	local mine = PlotService.GetPlot(player)
	for _, plot in PlotService.GetPlots() do
		if plot == mine or (PlotService.GetOwner(plot) == nil and not isBotPlot(plot)) then
			continue
		end
		local bounds = refsFor(plot).Bounds
		if bounds and inside(bounds, position) then
			ban(player, plot, "mort dans la boutique")
			notify(player, cooldownMessage(MESSAGES.Eliminated, PvP.KickRobCooldown), "Alert")
			return
		end
	end
end

-- Humanoid.Died de chaque personnage (le Humanoid est déjà là à CharacterAdded pour un personnage R15).
local function watchCharacter(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			onDeath(player, character)
		end)
	end
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(function(character: Model)
		watchCharacter(player, character)
	end)
	local character = player.Character
	if character then
		watchCharacter(player, character)
	end
end

-- Filet, 10 fois par seconde : un Humanoid arrivé après CharacterAdded, un Died manqué.
local function deathStep()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character == nil or deathSeen[player] == character then
			continue
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health <= 0 then
			onDeath(player, character)
		end
	end
end

-- Interdictions finies : attribut retiré.
local function banStep()
	for player, byPlot in table.clone(robBans) do
		for plot in table.clone(byPlot) do
			banLeft(player, plot)
		end
	end
end

-- Tick -----------------------------------------------------------------------------------------------------------

local function step()
	local now = os.clock()
	for player, hold in table.clone(holds) do
		if hold.Floor then
			if now - hold.StartedAt > PvP.StealGrabTime + HOLD_EXPIRY or floorRefusal(player, hold.Plot, hold.Uid) ~= nil then
				holds[player] = nil
			end
			continue
		end
		local exposed = exposedOf(hold.Plot, hold.Victim)[hold.Slot]
		if
			exposed == nil
			or exposed.Uid ~= hold.Uid
			or now - hold.StartedAt > PvP.StealGrabTime + HOLD_EXPIRY
			or stealRefusal(player, hold.Plot, hold.Slot) ~= nil
		then
			holds[player] = nil
		end
	end
	for thief, theft in table.clone(thefts) do
		if thefts[thief] ~= theft then
			continue
		end
		local victim = theft.Victim
		if (victim and not present(victim)) or (victim == nil and not isBotPlot(theft.Plot)) then
			abandon(theft, "VictimLeft") -- la victime, ou le bot, est partie
			continue
		end
		local plot = PlotService.GetPlot(thief)
		local root = rootOf(thief)
		local refs = if plot then refsFor(plot) else nil
		local zone = if refs then refs.Deposit else nil
		local bounds = if refs then refs.Bounds else nil
		if root and zone and overFootprint(zone, root.Position) and (bounds == nil or inside(bounds, root.Position)) then
			deposit(theft, root)
		end
	end
	for _, shop in table.clone(shops) do
		if shop.Victim == nil and not isBotPlot(shop.Plot) then
			closeShop(shop, "départ du bot")
		end
	end
	deathStep()
	ejectStep()
	intrusionStep()
	publishCount += 1
	if publishCount >= PUBLISH_EVERY then
		publishCount = 0
		for _, plot in PlotService.GetPlots() do
			publish(plot)
		end
		banStep()
	end
end

-- Événements -------------------------------------------------------------------------------------------------------

local function onBroken(info: WindowService.BreakInfo)
	if info.Kind ~= "Plot" then
		return
	end
	local plot = info.Model
	local victim = PlotService.GetOwner(plot)
	if victim == nil then
		if isBotPlot(plot) then
			openShop(plot, nil, info.WindowId, info.Breaker) -- le bot : pas d'alarme à prévenir
		end
		return
	end
	openShop(plot, victim, info.WindowId, info.Breaker)
	-- L'alarme de base (6.1, point 2).
	notify(victim, string.format(MESSAGES.DoorSmashed, info.Breaker.DisplayName), "Alert")
end

local function onRebuilt(_windowId: string, model: Model)
	if not table.find(PlotService.GetPlots(), model) then
		return -- pas une boutique (magasin PNJ)
	end
	local shop = shops[model]
	if shop then
		closeShop(shop, "porte reconstruite")
	end
	for _, player in ejectFrom(model, PlotService.GetOwner(model)) do
		notify(player, MESSAGES.DoorBack, "Alert")
		log(`{player.Name} sorti de {model.Name} : la porte est reconstruite`)
	end
end

local function onPlayerRemoving(player: Player)
	leaving[player] = true
	holds[player] = nil
	for thief, theft in table.clone(thefts) do
		if theft.Victim == player then
			abandon(theft, "VictimLeft")
		elseif thief == player then
			abandon(theft, "Left")
		end
	end
	intruders[player] = nil
	for _, shop in table.clone(shops) do
		if shop.Breaker == player then
			shop.Breaker = nil
		end
		if shop.Victim == player then
			closeShop(shop, "départ de la victime")
		end
	end
	robBans[player] = nil
	lastNotice[player] = nil
	lastRefusal[player] = nil
end

-- Le propriétaire part : les interdictions sur sa boutique tombent (elle servira à un autre joueur).
local function onPlotReleased(_owner: Player, plot: Model)
	for player, byPlot in table.clone(robBans) do
		if byPlot[plot] ~= nil then
			clearBan(player, plot)
		end
	end
end

-- API --------------------------------------------------------------------------------------------------------------

function PvPService.GetTheft(thief: Player): TheftInfo?
	local theft = thefts[thief]
	local victim = if theft then theft.Victim else nil
	if theft == nil or victim == nil then
		return nil -- aucun vol, ou un vol au bot (voir l'en-tête)
	end
	return { Victim = victim, ItemUid = theft.Uid, ItemId = theft.ItemId, SlotIndex = theft.Slot }
end

function PvPService.IsThiefOf(player: Player, owner: Player): boolean
	local theft = thefts[player]
	return theft ~= nil and theft.Victim == owner
end

function PvPService.GetRobCooldown(player: Player, plot: Model): number
	return banLeft(player, plot)
end

function PvPService.GetIntruders(victim: Player): { Player }
	local list = intruders[victim]
	return if list then table.clone(list) else {}
end

-- Point d'accroche du coffre-fort (voir l'en-tête) : PvP.VaultSlots par défaut ; SkillTreeService le
-- remplace (compétence Safe).
function PvPService.GetVaultSlots(_owner: Player): number
	return PvP.VaultSlots
end

function PvPService.OnTheftStarted(listener: StartedListener): () -> ()
	return subscribe(startedListeners, listener)
end

function PvPService.OnTheftEnded(listener: EndedListener): () -> ()
	return subscribe(endedListeners, listener)
end

function PvPService.Init()
	for _, plot in PlotService.GetPlots() do
		refsFor(plot) -- avant que DisplayService y pose des objets (mêmes noms possibles)
	end
	previousCanBeHit = WindowService.CanBeHit
	WindowService.CanBeHit = canBeHit
	WindowService.OnBroken(onBroken)
	WindowService.OnRebuilt(onRebuilt)
	-- Vague 33 : porte cassée tant qu'un intrus est dedans.
	WindowService.AddRebuildGate(rebuildGate)
	CarryService.OnCarryEnded(onCarryEnded)
	PlotService.OnPlotReleased(onPlotReleased)
	local bat = BatHooks
	if bat then
		bat.IsIntruder = isIntruder
		bat.OnHit(onBatHit)
	end
	Net.Server.StealItem:Connect(onStealItem)
	if Floor then
		-- Vague 31 (L-112) : remote absent d'un ancien Net/Definitions (bancs) : rien à voler au sol.
		local wired, err = pcall(function()
			Net.Server.StealFloorItem:Connect(onStealFloorItem)
		end)
		if not wired then
			log(`StealFloorItem pas branché : {err}`)
		end
	end
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	log(`{#PlotService.GetPlots()} boutique(s) suivie(s) pour le vol entre joueurs`)
end

function PvPService.Start()
	while true do
		task.wait(TICK)
		xpcall(step, function(err: any)
			warn(`[PvPService] tick : {err}`)
		end)
	end
end

return PvPService
