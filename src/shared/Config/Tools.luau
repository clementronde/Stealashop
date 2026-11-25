--!strict
-- Outils de casse de la boutique d'armes (Partie 1, sections 5.2, 7.2 et 2.4).
-- On garde tous les outils achetés et on en équipe un (slot 1).
--
-- Les outils de renaissance d'a407 (Marteau-piqueur, Bélier ; Features.RebirthTools, coupé en fusion98) sont retirés
-- du code (a438, 24/11 ; L-173 de Clément : plus d'outil à la renaissance, accord de Clément et de Cantin, L-310).
--
-- `Id` est la clé utilisée dans la sauvegarde (Tools.Owned, Tools.Equipped, 9.5) et
-- dans BuyItem (9.4). `Asset` est le nom du modèle de Clément dans
-- ReplicatedStorage/Assets/Tools (convention 10.3, noms confirmés par Clément le
-- 2026-11-07, MOD-027).

local DeepFreeze = require(script.Parent.DeepFreeze)

-- a486 : table de l'économie à appliquer par-dessus les nombres de ce fichier (Config/Economy.Override : la table 2
-- quand elle est active). nil avec la table 1, ou sans le module (bancs à liste de modules fixe, comme dans
-- Config/Items) : les nombres écrits dans ce fichier, qui SONT la table 1, ne sont jamais remplacés.
local ECO: any = (function(): any
	local found, module = pcall(function(): any
		return script.Parent:FindFirstChild("Economy")
	end)
	if found and module ~= nil then
		local ok, result = pcall(require, module :: any)
		if ok and type(result) == "table" then
			return result.Override
		end
	end
	return nil
end)()

export type ToolId =
	"Fists"
	| "Wrench"
	| "Crowbar"
	| "Hammer"
	| "Sledgehammer"
	| "FireAxe"
	| "AngleGrinder"

export type Tool = {
	Id: ToolId,
	Order: number, -- rang dans la boutique, du plus faible au plus fort
	DisplayName: string,
	Power: number, -- P outil de la formule des dégâts (7.1)
	Price: number, -- en $ du jeu, 0 = gratuit et possédé dès le départ
	TargetZones: { number }, -- { première, dernière } zone visée
	HitAnimation: "HitWindow" | "HitWindowHeavy", -- animation joueur jouée à chaque coup (2.4)
	Asset: string?, -- nil pour les poings
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

-- a486 : prix pris dans la table active de l'économie (table 2 : Hammer 450K, Sledgehammer 400M, Fire Axe 36B, Angle
-- Grinder 160B ; Wrench et Crowbar gardent leur prix). Les puissances ne dépendent pas de la table.
if ECO ~= nil then
	for _, tool in List do
		local price = ECO.ToolPrices[tool.Id]
		assert(type(price) == "number", `Config/Tools : prix de {tool.Id} absent de Config/Economy`)
		tool.Price = price
	end
end

local ById: { [string]: Tool } = {}
for _, tool in List do
	ById[tool.Id] = tool
end

local Tools = {
	DefaultId = "Fists" :: ToolId, -- possédé et équipé à la création du profil (9.5)
	List = List,
	ById = ById, -- clé = Id ; indexer avec une chaîne venue du client renvoie nil si inconnue
}

export type Tools = typeof(Tools)

return DeepFreeze(Tools)
