--!strict
-- Gains hors ligne (DEV-102 ; Partie 2, section 3 « Gains hors ligne » ; liaison L-084, point 1).
-- Lu par OfflineService (serveur) et OfflineController (client). Au retour, la boutique du joueur a gagné,
-- pendant son absence :
--   absence (s, au plus MaxHours h) × revenu par seconde au départ × Rate
-- revenu au départ = objets exposés × bonus permanents (Premium, ×2 Argent, index), sans les boosts
-- temporaires (boost ×2 argent, compté seulement en jeu : Partie 2, section 4). Depuis la vague 22
-- (L-092 3f, écran UI_Offline de Clément), l'argent attend dans le profil (Offline.Pending) que le joueur
-- appuie sur Claim (remote ClaimOffline), puis il est versé dans son argent (DisplayService.AddOfflineEarnings).
--
-- Le doc (Partie 2) disait « 10 % des revenus pendant 4 h max » ; Clément a décidé le 2026-11-08 (L-084,
-- journal 15) « tout l'argent qu'il aurait gagné pendant son absence », validé par Ironix le 2026-11-09
-- (Rate = 1, 100 %). Plafond : celui du doc (4 h), à valider avec Clément.

local DeepFreeze = require(script.Parent.DeepFreeze)

-- a481 : modules de Config chargés s'ils sont là (bancs à liste de modules fixe, comme dans Config/Items) ; sans eux,
-- l'interrupteur est coupé et IsDev faux, comme en PROD.
local function optional(name: string): any
	local found, module = pcall(function(): any
		return script.Parent:FindFirstChild(name)
	end)
	if found and module ~= nil then
		local ok, result = pcall(require, module :: any)
		if ok and type(result) == "table" then
			return result
		end
	end
	return {}
end
local Features: any = optional("Features")
local ProductIds: any = optional("ProductIds")

-- Plafond de base de l'absence comptée, en heures (doc, Partie 2 ; redit par Cantin le 25/11 : 4 h de base).
local MAX_HOURS = 4
-- a481 (Cantin, 25/11) : 2 nœuds de l'arbre de compétences (Config/SkillTree, Id ci-dessous), +30 min hors ligne
-- chacun, soit 5 h au plus. Comptés par le serveur seul, au retour du joueur (OfflineService), d'après les niveaux
-- sauvegardés dans son profil (champ SkillTree) : un client ne peut rien y changer. Allumés partout
-- (Features.SkillOfflineTime) ou dans le jeu DEV seulement (SkillOfflineTimeDev et ProductIds.IsDev) ; coupés : tuiles
-- « Soon » et plafond de MaxHours, un niveau acheté en DEV ne compte pas.
local SKILLS_ENABLED: boolean = Features.SkillOfflineTime == true
	or (Features.SkillOfflineTimeDev == true and ProductIds.IsDev == true)
local SKILL_IDS = { "OfflineTime1", "OfflineTime2" } -- V0 proposé le 25/11 (a481)
local SKILL_BONUS_HOURS = 0.5 -- Cantin, 25/11 : +30 min par nœud
local MAX_CAP_HOURS = 5 -- Cantin, 25/11 : 5 h au plus, nœuds compris (garde-fou)

-- a481 : plafond (h) d'un joueur d'après les niveaux de son arbre (champ SkillTree du profil, [Id] = niveau) :
-- MAX_HOURS, plus SKILL_BONUS_HOURS par nœud de SKILL_IDS acheté (niveau ≥ 1) quand SKILLS_ENABLED, borné à
-- MAX_CAP_HOURS. Niveau illisible (pas un nombre fini) : pas compté. Pur, sans yield ; à n'appeler que sur le serveur,
-- avec le profil.
local function capHours(tree: { [string]: any }?): number
	local hours = math.max(0, MAX_HOURS)
	if not SKILLS_ENABLED or type(tree) ~= "table" then
		return hours
	end
	for _, id in SKILL_IDS do
		local level = tree[id]
		if type(level) == "number" and level == level and level >= 1 and level < math.huge then
			hours += SKILL_BONUS_HOURS
		end
	end
	return math.min(hours, math.max(MAX_HOURS, MAX_CAP_HOURS))
end

local Offline = {
	-- Part des revenus gagnée hors ligne : 1 = 100 % (Clément, L-084 ; validé par Ironix le 2026-11-09).
	Rate = 1,
	-- Plafond de base de l'absence comptée, en heures (Cantin, 25/11 : 4 h de base) ; un joueur peut avoir plus avec
	-- les nœuds de l'arbre : CapHours(profil.SkillTree) fait foi.
	MaxHours = MAX_HOURS,
	-- a481 : nœuds de l'arbre (voir plus haut). SkillsEnabled = interrupteur résolu (PROD ou DEV).
	SkillsEnabled = SKILLS_ENABLED,
	SkillIds = SKILL_IDS,
	SkillBonusHours = SKILL_BONUS_HOURS,
	MaxCapHours = MAX_CAP_HOURS,
	CapHours = capHours,
	-- V0 proposé, absent du doc : toutes les SnapshotInterval s de jeu, l'heure et le revenu sont écrits
	-- dans le profil (Offline.LastSeenAt et Offline.Income), pour qu'un serveur qui plante ne fasse pas
	-- perdre l'absence (la sauvegarde automatique de ProfileStore passe toutes les 5 min).
	SnapshotInterval = 5,
	-- V0 proposé, absent du doc : délai (s) entre l'arrivée du joueur et l'ouverture de l'écran UI_Offline
	-- (OfflineController), le temps que le personnage et le HUD apparaissent.
	OpenDelay = 3,
	-- Attribut du Player posé par OfflineService, lu par OfflineController : dollars entiers en attente
	-- du Claim (0 : rien à réclamer, l'écran reste fermé).
	PendingAttribute = "OfflinePending",
	-- Message de secours (Notify « Info », en anglais, L-036 ; %s = la somme, Format.money : « $1.2M ») :
	-- montré par le client seulement si l'écran UI_Offline manque (l'argent est alors réclamé tout seul).
	Message = "Your shop earned %s while you were away!",
	-- Son du Claim (L-097 point 8 ; note ui-feel2 : « Après Claim : Offline_Claim puis Cash_Collect ») :
	-- Assets/Sounds/Cash/Offline_Claim, joué au clic sur ClaimButton, avant le Cash_Collect de l'arrivée.
	ClaimSound = "Offline_Claim",
	-- Studio seulement : workspace:SetAttribute(TestAttribute, "<joueur> <secondes>") simule une absence
	-- de ce nombre de secondes (barre de commande serveur ; joueur = nom ou UserId). Voir OfflineService.
	TestAttribute = "OfflineTest",
}

-- a486 (Cantin, 25/11) : la part des revenus gagnée hors ligne est une valeur de la table de l'économie
-- (Config/Economy, OfflineRate), à côté des prix du tapis avec lesquels elle est réglée : table 1 = 1 (100 %, la ligne
-- Rate plus haut), table 2 = 1 aussi tant que Clément n'a pas répondu à L-413 (50 %). Avec la table 2, Rate est
-- remplacé ici, après coup, par la valeur de la table : la changer = une valeur de Config/Economy. MaxHours ne dépend
-- pas de la table (4 h pour les deux).
do
	-- Config/Economy.Override : la table 2 quand elle est active ; nil avec la table 1 ou sans le module.
	local ECO: any = optional("Economy").Override
	if type(ECO) == "table" and type(ECO.Version) == "number" then
		assert(type(ECO.OfflineRate) == "number", "Config/Offline : OfflineRate absent de Config/Economy")
		Offline.Rate = ECO.OfflineRate
	end
end

export type Offline = typeof(Offline)

return DeepFreeze(Offline)
