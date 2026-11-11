--!strict
-- Potions (liaison L-085 et L-097 point 4). Décision de Clément du 2026-11-08 : « trouvées par terre dans les
-- zones : Speed ×2 pendant quelques minutes, Invisibility, Money ×2… », validée le jour même. Modèles :
-- ReplicatedStorage/Assets/Potions/POT_<Id> (Root en PrimaryPart, Glass, Liquid avec Glow et Bubbles, Cork,
-- Emblem ; attribut Idle = "SpinBob"). Tout le reste est V0 proposé, absent du doc, à valider avec Clément.
--
-- Contrat partagé entre le serveur (PotionService) et le client (PotionController) :
--   - potions PERSONNELLES (V0) : chaque joueur a les siennes dans le couloir des zones, vues de lui seul ; le
--     serveur tire le type et la place, le client montre le modèle et détecte le contact ;
--   - remotes PotionSpawned(uid, potionId, position) et PotionRemoved(uid), du serveur vers ce joueur seul ;
--     PickPotion(uid), du client vers le serveur (le serveur vérifie la distance) ;
--   - effet actif : attribut du joueur AttributePrefix .. Id (« Potion_Speed »…) = heure serveur de fin
--     (workspace:GetServerTimeNow()), retiré à la fin ; une potion du même type ajoute sa durée à ce qui reste.
-- Arbre de compétences (Config/SkillTree) : PotionLuck rapproche les apparitions, PotionTime allonge les durées.

local DeepFreeze = require(script.Parent.DeepFreeze)

export type PotionId = "Speed" | "Money" | "Strength" | "Invisibility"

export type Potion = {
	Id: PotionId,
	Model: string, -- modèle de Clément dans Assets/Potions
	DisplayName: string, -- texte du jeu (anglais)
	Multiplier: number?, -- vitesse de marche, revenu ou dégâts ; nil pour l'invisibilité
	Duration: number, -- secondes (avant PotionTime)
	Weight: number, -- poids du tirage du type
}

local List: { Potion } = {
	-- ×2 : Clément (L-085). Durée « quelques minutes » : 120 s, V0.
	{ Id = "Speed", Model = "POT_Speed", DisplayName = "Speed", Multiplier = 2, Duration = 120, Weight = 35 },
	-- ×2 : Clément (L-085). Durée V0.
	{ Id = "Money", Model = "POT_Money", DisplayName = "Money", Multiplier = 2, Duration = 120, Weight = 25 },
	-- Modèle livré par Clément sans effet décrit : dégâts ×2 sur les vitrines, V0.
	{ Id = "Strength", Model = "POT_Strength", DisplayName = "Strength", Multiplier = 2, Duration = 120, Weight = 25 },
	-- Effet V0 : les autres joueurs ne te voient presque plus et les vigiles de nuit ne te repèrent pas.
	{ Id = "Invisibility", Model = "POT_Invisibility", DisplayName = "Invisibility", Duration = 60, Weight = 15 },
}

local ById: { [string]: Potion } = {}
for _, potion in List do
	ById[potion.Id] = potion
end

local Potions = {
	List = List,
	ById = ById,
	AttributePrefix = "Potion_",
	MaxPerPlayer = 3, -- V0 : potions à lui en même temps dans le couloir
	SpawnEvery = 45, -- V0 : secondes entre deux apparitions pour un joueur (× l'effet de PotionLuck)
	Lifetime = 180, -- V0 : une potion pas ramassée disparaît au bout de ce temps
	PickupRadius = 4, -- V0 : studs, contact détecté par le client
	PickupMaxDistance = 10, -- V0 : studs, vérifié par le serveur (latence comprise)
}

export type Potions = typeof(Potions)

return DeepFreeze(Potions)
