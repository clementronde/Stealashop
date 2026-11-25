--!strict
-- OpenLuck (a476, 25/11 ; liaison L-374 et L-375) : LA formule de la chance d'une ouverture de colis de rayon, commune
-- à tous les chemins du serveur (StoreHeistService : startReveal, cinématique d'un colis de magasin ; startOpening,
-- colis d'un rayon d'événement, camion et Fortune Tower). Le serveur seul la calcule ; le client ne lit que le résultat.
--
--   chance = Table × Event × Server × Skill          (puis l'accroche du tuto, si elle répond, la remplace)
--     Table   chance tirée dans Config/ShelfOpen.LuckTable (×1 à ×10 ; ×1 si Reveal.TableLuck est coupé) ;
--     Event   bonus d'un événement live (attribut LiveEventShelfLuck du Workspace, EventService ; ×1 dans la
--             cinématique tant que Config/ShelfOpen.Reveal.EventLuck est coupé) ;
--     Server  chance du serveur achetée en Robux (attribut ServerLuck du Workspace, MonetizationService : ×2, ×4, ×8) ;
--     Skill   compétence BoxLuck de l'ouvreur (Config/SkillTree, Effects[niveau] : ×1,1 à ×1,5 ; ×1 sans achat ou
--             tuile coupée : Features.SkillBoxLuck / SkillBoxLuckDev). Niveau lu dans l'attribut Skill_BoxLuck du
--             Player, que SkillTreeService seul écrit (un attribut changé par le client ne remonte pas au serveur).
--   Potion : aucune potion de chance n'existe (Config/Potions : Money, Strength, Invisibility) ; PotionLuck de l'arbre
--   rapproche les apparitions des potions et n'entre pas ici.
-- Chaque facteur illisible (nil, NaN, infini, sous son minimum) vaut ×1 ; Table, Server et Skill jamais sous ×1, Event
-- jamais sous ×0,001. Aucun plafond : la plus forte pile possible aujourd'hui est 10 × 8 × 1,5 = ×120 (×3 de plus si un
-- événement LuckRush tourne pendant un colis d'événement). La chance ne force aucune rareté : elle multiplie le poids des
-- raretés au-dessus de la caisse (Config/ShelfBoxes.ContentWeights) et des paliers lourds (Shared/ItemWeight), puis
-- tout est ramené à 100 % ; la caisse et les raretés en dessous gardent leur part, toujours > 0.
-- La cote « 1 IN N » (Shared/ItemOdds) ne compte ni Event, ni Server, ni Skill : c'est la chance de l'objet lui-même.
--
-- API :
--   OpenLuck.Combine(parts) -> number       parts = { Table: any, Event: any, Server: any, Skill: any } (valeurs brutes)
--   OpenLuck.SkillFactor(level: any) -> number   Effects[niveau] de BoxLuck (niveau borné à Coded) ; 1 sinon
--   OpenLuck.SkillFactorOf(player: Player) -> number   SkillFactor de l'attribut Skill_BoxLuck du joueur

local Config = script.Parent:WaitForChild("Config")
local SkillTree = require(Config:WaitForChild("SkillTree"))

local OpenLuck = {}

OpenLuck.SkillId = "BoxLuck"

export type Parts = { Table: any, Event: any, Server: any, Skill: any }

local function factor(value: any, minimum: number): number
	if type(value) == "number" and value == value and value >= minimum and value < math.huge then
		return value
	end
	return 1
end

function OpenLuck.Combine(parts: Parts): number
	return factor(parts.Table, 1) * factor(parts.Event, 1e-3) * factor(parts.Server, 1) * factor(parts.Skill, 1)
end

function OpenLuck.SkillFactor(level: any): number
	local skill = SkillTree.ById[OpenLuck.SkillId]
	if skill == nil or type(level) ~= "number" or level ~= level then
		return 1
	end
	local capped = math.min(math.floor(level), skill.Coded, skill.MaxLevel)
	if capped < 1 then
		return 1
	end
	return factor(skill.Effects[capped], 1)
end

function OpenLuck.SkillFactorOf(player: Player): number
	return OpenLuck.SkillFactor(player:GetAttribute(SkillTree.AttributePrefix .. OpenLuck.SkillId))
end

return OpenLuck
