--!strict
-- Outils de casse de la boutique d'armes (Partie 1, sections 5.2, 7.2 et 2.4).
-- On garde tous les outils achetés et on en équipe un (slot 1).
--
-- Outils de renaissance (a407, vague GC6, MAJ 3 ; Features.RebirthTools ; L-158 Q8 et L-173) : le Marteau-piqueur
-- (Jackhammer) et le Bélier (BatteringRam). L-173 (Clément) : une renaissance ne DONNE plus d'outil ; ils sont donc
-- vendus à la boutique d'armes, ouverts par la renaissance (RequiresRebirth, même règle que les tuiles de l'arbre :
-- attribut `Rebirths` du Player ; absent = fermés). V0 proposé (Cantin, 23/11), d'après docs/claude/notes/
-- renaissance-proposition.md (section 4, oui de Clément en L-158 Q8) :
--   - puissance de l'Angle Grinder (100K), jamais plus : la zone 6 reste à deux joueurs (règle « 1,12 × Angle
--     Grinder × Royal ») ; les PV des vitrines ne suivent pas ces outils (Config/Zones lit le Kit de chaque zone) ;
--   - KeepOnRebirth : gardés à la renaissance (RebirthService), c'est leur intérêt : plus besoin de racheter les
--     outils de chaque zone après une renaissance ;
--   - DoorHits : coups comptés par frappe sur la porte d'une boutique de joueur (1 sans le champ ; Bélier ×3,
--     WindowService par ToolService.GetDoorHits).
--
-- `Id` est la clé utilisée dans la sauvegarde (Tools.Owned, Tools.Equipped, 9.5) et
-- dans BuyItem (9.4). `Asset` est le nom du modèle de Clément dans
-- ReplicatedStorage/Assets/Tools (convention 10.3, noms confirmés par Clément le
-- 2026-11-07, MOD-027).

local DeepFreeze = require(script.Parent.DeepFreeze)
local Features = require(script.Parent.Features)

export type ToolId =
	"Fists"
	| "Wrench"
	| "Crowbar"
	| "Hammer"
	| "Sledgehammer"
	| "FireAxe"
	| "AngleGrinder"
	| "Jackhammer"
	| "BatteringRam"

export type Tool = {
	Id: ToolId,
	Order: number, -- rang dans la boutique, du plus faible au plus fort
	DisplayName: string,
	Power: number, -- P outil de la formule des dégâts (7.1)
	Price: number, -- en $ du jeu, 0 = gratuit et possédé dès le départ
	TargetZones: { number }, -- { première, dernière } zone visée
	HitAnimation: "HitWindow" | "HitWindowHeavy", -- animation joueur jouée à chaque coup (2.4)
	Asset: string?, -- nil pour les poings
	RequiresRebirth: number?, -- a407 : renaissances faites pour l'acheter (nil : aucune)
	KeepOnRebirth: boolean?, -- a407 : gardé à la renaissance (RebirthService)
	DoorHits: number?, -- a407 : coups comptés par frappe sur une porte de boutique de joueur (nil : 1)
}

-- Vague 68 (a226, Cantin : « de 20 000 à 2 millions d'un coup, c'est pas normal ») : marche des dégâts du panneau
-- (arme × aura du kit, Config/Zones) lissée : 1, 10, 300, 10K, 320K, 2M (×30 par zone de 2 à 5 ; la zone 6 se casse
-- à deux, soit 4M d'équipe, ×12,5). Puissances de Crowbar, Hammer, Sledgehammer et Fire Axe, et prix des kits des
-- zones 3 à 6 (pour un temps entre zones qui s'allonge d'environ ×2,5, zone 6 vers 7 h 30) : V0 proposés, réglés au
-- simulateur (RAPPORT=v2 COURT=1 bash tools/ironix/equilibrage/run.sh). Avant : 40, 300, 2 500, 20 000 de puissance ;
-- 40 K$, 1 M$, 20 M$, 250 M$, 5 B$ de prix.
local List: { Tool } = {
	{ Id = "Fists", Order = 1, DisplayName = "Fists", Power = 1, Price = 0, TargetZones = { 1, 1 }, HitAnimation = "HitWindow", Asset = nil },
	{ Id = "Wrench", Order = 2, DisplayName = "Wrench", Power = 5, Price = 300, TargetZones = { 2, 2 }, HitAnimation = "HitWindow", Asset = "TOOL_CleAMolette" },
	{ Id = "Crowbar", Order = 3, DisplayName = "Crowbar", Power = 100, Price = 3_100, TargetZones = { 3, 3 }, HitAnimation = "HitWindow", Asset = "TOOL_PiedDeBiche" }, -- V0 proposé (Cantin, 20/11), avant : 80_000
	{ Id = "Hammer", Order = 4, DisplayName = "Hammer", Power = 2_000, Price = 88_000, TargetZones = { 4, 4 }, HitAnimation = "HitWindowHeavy", Asset = "TOOL_Marteau" }, -- V0 proposé (Cantin, 20/11), avant : 4_000_000
	{ Id = "Sledgehammer", Order = 5, DisplayName = "Sledgehammer", Power = 40_000, Price = 1_200_000, TargetZones = { 5, 5 }, HitAnimation = "HitWindowHeavy", Asset = "TOOL_Masse" }, -- V0 proposé (Cantin, 20/11), avant : 120_000_000
	{ Id = "FireAxe", Order = 6, DisplayName = "Fire Axe", Power = 60_000, Price = 9_900_000, TargetZones = { 5, 5 }, HitAnimation = "HitWindowHeavy", Asset = "TOOL_HacheDIncendie" }, -- V0 proposé (Cantin, 20/11), avant : 1_000_000_000
	{ Id = "AngleGrinder", Order = 7, DisplayName = "Angle Grinder", Power = 100_000, Price = 69_000_000, TargetZones = { 6, 6 }, HitAnimation = "HitWindowHeavy", Asset = "TOOL_Disqueuse" }, -- V0 proposé (Cantin, 20/11), avant : 7_000_000_000
}

-- a407 (Features.RebirthTools) : prix V0 proposés (Cantin, 23/11), absents du doc : ×10 et ×30 l'Angle Grinder (un achat
-- qui se garde d'un cycle à l'autre ; la 5e renaissance coûte 22B). Modèles TOOL_Jackhammer et TOOL_BatteringRam de
-- Clément facultatifs (poignée grise V0 de ToolService) ; frappe HitWindowHeavy comme l'Angle Grinder.
local REBIRTH_TOOLS: { Tool } = {
	{ Id = "Jackhammer", Order = 8, DisplayName = "Jackhammer", Power = 100_000, Price = 690_000_000, TargetZones = { 6, 6 }, HitAnimation = "HitWindowHeavy", Asset = "TOOL_Jackhammer", RequiresRebirth = 5, KeepOnRebirth = true },
	{ Id = "BatteringRam", Order = 9, DisplayName = "Battering Ram", Power = 100_000, Price = 2_100_000_000, TargetZones = { 6, 6 }, HitAnimation = "HitWindowHeavy", Asset = "TOOL_BatteringRam", RequiresRebirth = 7, KeepOnRebirth = true, DoorHits = 3 },
}
if Features.RebirthTools then
	for _, tool in REBIRTH_TOOLS do
		table.insert(List, tool)
	end
end

local ById: { [string]: Tool } = {}
for _, tool in List do
	ById[tool.Id] = tool
end

-- a407 : la renaissance qui ferme encore l'achat de `tool`, ou nil s'il est ouvert. `rebirths` = renaissances faites
-- (la valeur de l'attribut `Rebirths` du Player, posé par RebirthService, telle quelle) ; absente ou illisible =
-- renaissance coupée : tout outil à renaissance reste fermé (même règle que SkillTree.NeedsRebirth).
local function needsRebirth(tool: Tool, rebirths: any): number?
	local needed = tool.RequiresRebirth
	local done = if type(rebirths) == "number" and rebirths == rebirths and rebirths >= 0 then rebirths else nil
	if needed == nil or (done ~= nil and done >= needed) then
		return nil
	end
	return needed
end

-- a407 : les outils que la renaissance numéro `rebirth` ouvre, dans l'ordre de la boutique.
local function unlockedBy(rebirth: number): { Tool }
	local list: { Tool } = {}
	for _, tool in List do
		if tool.RequiresRebirth == rebirth then
			table.insert(list, tool)
		end
	end
	return list
end

local Tools = {
	DefaultId = "Fists" :: ToolId, -- possédé et équipé à la création du profil (9.5)
	List = List,
	ById = ById, -- clé = Id ; indexer avec une chaîne venue du client renvoie nil si inconnue
	NeedsRebirth = needsRebirth,
	UnlockedBy = unlockedBy,
	RebirthsAttribute = "Rebirths", -- a407 : attribut du Player (RebirthService), même nom que SkillTree.RebirthsAttribute
}

export type Tools = typeof(Tools)

return DeepFreeze(Tools)
