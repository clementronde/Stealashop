--!strict
-- Panel admin (vague 29, liaison L-108 point 4 ; écran UI_Admin de Clément, docs/claude/notes/ui-admin.md) : qui
-- est admin et quelles commandes existent. Lu par le serveur (AdminService, qui décide et revalide tout) et par le
-- client (AdminController). Toutes les valeurs sont V0 proposées, absentes du doc.
--
-- Qui est admin (décidé par AdminService seul ; l'attribut IsAdmin = true du Player ne sert qu'à l'affichage) :
--   - en Studio, tout le monde (StudioEveryone) ;
--   - un UserId de UserIds ;
--   - un membre du groupe du studio de rang MinGroupRank ou plus. GroupId = 0 : le groupe propriétaire du jeu
--     (game.CreatorId quand game.CreatorType est Group). Aucun GroupId n'existait encore dans Config.
--
-- Remote AdminCommand(commandId, target?, value?, text?, text2?) (Net/Definitions) :
--   target = joueur visé, présent sur le serveur (absent = celui qui envoie) ; value (nombre), text et text2
--   (Id) = arguments de la commande, décrits dans Args. Le serveur revalide tout (bornes, Id connus).
--   Réponse au seul admin : AdminResult(commandId, ok, message), affiché dans UI_Admin.Root.StatusLabel.
--
-- Une commande : Id, Section (section de UI_Admin), Target (agit sur un joueur), StudioOnly (passe par un crochet
-- de test Studio : refusée sur un serveur en ligne pour l'instant), Args (texte lisible : ce que portent value,
-- text et text2). Les listes de choix (objets, raretés, auras…) viennent de Shared/AdminLists.

local DeepFreeze = require(script.Parent.DeepFreeze)

-- a486 : table active de l'économie (Config/Economy.Active), chargée si le module est là (bancs à liste de modules
-- fixe, comme dans Config/Items) ; sans lui, nil : les nombres écrits dans ce fichier, qui sont ceux de la table 1.
local ECO: any = (function(): any
	local found, module = pcall(function(): any
		return script.Parent:FindFirstChild("Economy")
	end)
	if found and module ~= nil then
		local ok, result = pcall(require, module :: any)
		if ok and type(result) == "table" then
			return result.Active
		end
	end
	return nil
end)()

export type Command = {
	Id: string,
	Section: string,
	Target: boolean,
	StudioOnly: boolean?,
	Args: string,
}

local Commands: { Command } = {
	-- StatsSection : montant ajouté (1 à MaxAmount).
	{ Id = "GiveCash", Section = "Stats", Target = true, Args = "value = amount" },
	{ Id = "GiveSpeed", Section = "Stats", Target = true, Args = "value = amount" },
	-- BaseSection : niveau acheté de Config/Upgrades (0 au MaxLevel) ; boutique et rayons : 1 à 5.
	{ Id = "SetTreadmill", Section = "Base", Target = true, Args = "value = level (0 to MaxLevel)" },
	-- Niveau de boutique k (ShopStageService : k rayons montrés) : le minimum de présentoirs pour l'atteindre.
	{ Id = "SetShopLevel", Section = "Base", Target = true, Args = "value = shop level (1 to 5)" },
	-- k rayons pleins : 4 × (k − 1) présentoirs achetés.
	{ Id = "SetRayons", Section = "Base", Target = true, Args = "value = rayons (1 to 5)" },
	-- GiveSection, une commande par sorte.
	{ Id = "GiveItem", Section = "Give", Target = true, Args = "text = ItemId, text2 = mutation Id (optional), value = zone (Secret only, optional)" },
	{ Id = "GiveBox", Section = "Give", Target = true, Args = "text = rarity Id, value = zone (optional)" },
	{ Id = "GiveAura", Section = "Give", Target = true, Args = "text = aura Id" },
	{ Id = "GiveTrail", Section = "Give", Target = true, Args = "text = trail Id" },
	{ Id = "GivePotion", Section = "Give", Target = true, StudioOnly = true, Args = "text = potion Id" },
	-- Drapeau de test pour la session (crochet MonetizationTest) : jamais un achat ni un reçu.
	{ Id = "GiveGamepass", Section = "Give", Target = true, StudioOnly = true, Args = "text = pass key (VIP…)" },
	-- Pas encore à l'écran : niveau d'une compétence de l'arbre.
	{ Id = "SetSkill", Section = "Base", Target = true, StudioOnly = true, Args = "text = skill Id, value = level" },
	-- EventsSection : Truck (value = zone, au hasard sinon), Night ou Day (value = durée en s, facultative),
	-- Fortune, FortuneOpen, FortuneSeal (vague 39, Fortune Tower ; sans value) : Studio seulement (refusés en ligne
	-- par AdminService). Vague 51 (a167) : un Id de Config/LiveEvents (événement live sur ce serveur, tout de suite)
	-- ou StopLiveEvent (arrête l'événement live en cours), permis en ligne.
	{ Id = "StartEvent", Section = "Events", Target = false, Args = "text = event Id, value = zone or seconds (optional)" },
	-- TeleportSection : 0 = zone safe (sa boutique), 1 à 6 = zone.
	{ Id = "Teleport", Section = "Teleport", Target = true, Args = "value = zone (0 to 6)" },
	-- DangerSection : text = ResetConfirm (le client l'envoie au second clic). Le joueur est renvoyé du serveur,
	-- son profil est vidé juste avant la sauvegarde (achats Robux gardés).
	{ Id = "ResetProfile", Section = "Danger", Target = true, Args = "text = ResetConfirm" },
}

local ById: { [string]: Command } = {}
for _, command in Commands do
	assert(ById[command.Id] == nil, `Config.Admin : commande en double {command.Id}`)
	ById[command.Id] = command
end

local Admin = {
	-- UserId des admins hors Studio. 296770611 : le compte IRONIX01 (décision de Cantin du 25/11, a442). Vaut aussi
	-- pour la commande /feature des interrupteurs (LiveFeaturesService).
	UserIds = { 296770611 } :: { number },
	-- Groupe du studio : 0 = le groupe propriétaire du jeu (game.CreatorId) ; pas de contrôle par groupe si le jeu
	-- n'appartient pas à un groupe.
	GroupId = 0,
	-- Rang minimal dans ce groupe. V0 proposé (Cantin, 23/11, audit a272 F2, à confirmer) : 255, le propriétaire seul
	-- (avant 254 : tout futur rôle ≥ 254 du groupe, qui servira aux jeux suivants, aurait été admin en PROD). Les
	-- autres admins en ligne passent par UserIds.
	MinGroupRank = 255,
	-- V0 proposé (Cantin, 23/11, audit a272 F2) : le rang est relu toutes les RankRefreshSeconds s pour chaque joueur
	-- (attribut IsAdmin à jour), et juste avant une commande s'il a été lu il y a plus de RankMaxAge s : un membre
	-- rétrogradé perd ses droits sans se reconnecter. Lu par GroupService:GetGroupsAsync (Player:GetRankInGroup garde
	-- sa première réponse toute la session côté serveur).
	RankRefreshSeconds = 300,
	RankMaxAge = 60,
	-- En Studio, tout le monde est admin.
	StudioEveryone = true,
	-- Borne des montants donnés (l'échelle des stats va vers les milliards, L-108 point 1).
	-- a486 : pris dans la table active de l'économie (Config/Economy) : 1e15 (1Qa) avec la table 1 ; 1e30 avec la
	-- table 2, au-dessus de tout montant possible (un gros joueur y atteint 33Qi en 30 jours). La même borne pour
	-- `value` du remote AdminCommand (Net/Definitions) ; AdminService revalide toujours le montant.
	MaxAmount = (if ECO then ECO.AdminMaxAmount else 1e15) :: number,
	-- Mot envoyé par le client au second clic de ResetProfileButton.
	ResetConfirm = "RESET",
	-- Événements de StartEvent (Rain plus tard). Vague 39 : Fortune (une vitrine de la Fortune Tower tout de suite,
	-- remplace celle en jeu), FortuneOpen (la vitrine fermée en jeu s'ouvre, butin), FortuneSeal (elle se referme).
	Events = { "Truck", "Night", "Day", "Fortune", "FortuneOpen", "FortuneSeal" },
	-- Vague 51 (a167) : Id de StartEvent qui arrête l'événement live en cours (les Id des événements live viennent
	-- de Config/LiveEvents, ajoutés à la liste « Events » par Shared/AdminLists).
	StopLiveEvent = "StopLive",
	-- Textes du jeu (anglais).
	Messages = {
		Kicked = "An admin reset your progress. Rejoin to start fresh!",
		StudioOnly = "Studio only for now.",
		ConfirmReset = "Click again to confirm",
		Ready = "Ready.",
		Sent = "Sent...",
		TargetSelf = "Target: you",
		TargetOther = "Target: %s",
	},
	Commands = Commands,
	ById = ById,
}

export type Admin = typeof(Admin)

return DeepFreeze(Admin)
