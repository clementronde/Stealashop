--!nocheck
---------------------------------------------------------------- a183, scénario « alert » : pastille « ! » du bouton Upgrades
-- RailAlertController (SkillTreeAlert) : une tuile à renaissance encore fermée ne compte pas comme achetable.
-- Tout le premier anneau est au maximum ou pas codé : seules Curtain ($50K) et Potion Time ($100K) restent à acheter.
REBIRTH_OFF183 = true
local RAIL_MODULE = moduleScript(CONTROLLERS, "RailAlertController", "client/Controllers/RailAlertController.luau")
start85({
	Cash = 1e12,
	Skill_Walls = 4,
	Skill_GlassThickness = 5,
	Skill_GlassRegen = 5,
	Skill_Cameras = 2,
	Skill_Bodyguards = 0,
	Skill_PotionLuck = 3,
	Skill_Curtain = 0,
	Skill_DoorGuard = 0,
	Skill_PotionTime = 0,
	Skill_Traps = 0,
})
local Rail = requireModule(RAIL_MODULE, "client")
local function pending()
	Rail.Refresh()
	return Rail.GetState().SkillTree
end

section("A1. Pastille SkillTreeAlert et tuiles à renaissance")
check(pending() == false, "A1a renaissance coupée : Curtain et Potion Time ne comptent pas, pastille éteinte")
P1:SetAttribute("Rebirths", 0)
check(pending() == false, "A1b renaissance ouverte, aucune faite : éteinte")
P1:SetAttribute("Rebirths", 1)
check(pending() == true, "A1c 1 renaissance : Curtain achetable, pastille allumée")
P1:SetAttribute("Skill_Curtain", 2)
check(pending() == false, "A1d Curtain au maximum, Potion Time demande la 2e : éteinte")
P1:SetAttribute("Rebirths", 2)
check(pending() == true, "A1e 2 renaissances : Potion Time achetable, allumée")
P1:SetAttribute("Skill_PotionTime", 1)
P1:SetAttribute("Rebirths", nil)
check(pending() == true, "A1f renaissance recoupée, Potion Time déjà achetée (niveau 2 à $2M) : allumée")
P1:SetAttribute("Cash", 1000)
check(pending() == false, "A1g plus d'argent : éteinte")
check(not logHas("attempt to"), "A1h aucune erreur dans la sortie")

summary()
