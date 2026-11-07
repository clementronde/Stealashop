--!strict
-- Outils de casse de la boutique d'armes (Partie 1, sections 5.2, 7.2 et 2.4).
-- On garde tous les outils achetés et on en équipe un (slot 1). Le Marteau-piqueur
-- et le Bélier sont réservés aux renaissances (Partie 2) : absents ici.
--
-- `Id` est la clé utilisée dans la sauvegarde (Tools.Owned, Tools.Equipped, 9.5) et
-- dans BuyItem (9.4). `Asset` est le nom du modèle dans ReplicatedStorage/Assets :
-- dérivé de la convention 10.3 (exemple `TOOL_PiedDeBiche`), absent du tableau
-- 10.4, à confirmer avec Clément.

local DeepFreeze = require(script.Parent.DeepFreeze)

export type ToolId = "Fists" | "Wrench" | "Crowbar" | "Hammer" | "Sledgehammer" | "FireAxe" | "AngleGrinder"

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

local List: { Tool } = {
	{ Id = "Fists", Order = 1, DisplayName = "Fists", Power = 1, Price = 0, TargetZones = { 1, 1 }, HitAnimation = "HitWindow", Asset = nil },
	{ Id = "Wrench", Order = 2, DisplayName = "Wrench", Power = 3, Price = 300, TargetZones = { 2, 2 }, HitAnimation = "HitWindow", Asset = "TOOL_CleAMolette" },
	{ Id = "Crowbar", Order = 3, DisplayName = "Crowbar", Power = 8, Price = 8_000, TargetZones = { 2, 3 }, HitAnimation = "HitWindow", Asset = "TOOL_PiedDeBiche" },
	{ Id = "Hammer", Order = 4, DisplayName = "Hammer", Power = 20, Price = 120_000, TargetZones = { 3, 3 }, HitAnimation = "HitWindowHeavy", Asset = "TOOL_Marteau" },
	{ Id = "Sledgehammer", Order = 5, DisplayName = "Sledgehammer", Power = 50, Price = 2_000_000, TargetZones = { 4, 4 }, HitAnimation = "HitWindowHeavy", Asset = "TOOL_Masse" },
	{ Id = "FireAxe", Order = 6, DisplayName = "Fire Axe", Power = 125, Price = 30_000_000, TargetZones = { 5, 5 }, HitAnimation = "HitWindowHeavy", Asset = "TOOL_HacheDIncendie" },
	{ Id = "AngleGrinder", Order = 7, DisplayName = "Angle Grinder", Power = 300, Price = 400_000_000, TargetZones = { 6, 6 }, HitAnimation = "HitWindowHeavy", Asset = "TOOL_Disqueuse" },
}

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
