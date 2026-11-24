--!nocheck
-- Copie a159 (2026-11-14, L-163) : la porte se casse en coups (40, Reinforced Door +8 par niveau), sans lien avec
-- le niveau de boutique, la force ni Walls (qui ne garde que le mur visible).
-- Scénario « walls » (a93, vague 29, L-105 point 3, L-106 points 2 et 3) : PV de la porte = base du niveau de
-- boutique (StageLevel : 50 × dégâts conseillés de la zone du même rang) × Glass × Walls, une seule barre ;
-- attribut WallsLevel de la parcelle et mur visible (ShowFromWalls / HideFromWalls) par ShopWallsService.
startSkills()
local adaData = newProfile()
adaData.Cash = 1e12
local ada = join("Ada", adaData)
local bob = join("Bob", newProfile())
advance(1.2)
local adaShop = shopOf(ada)
local door = doorOf(adaShop)
local function maxHP()
	return door:GetAttribute("MaxHP")
end

section("40 coups à tous les niveaux de boutique (copie a159)")
for level = 1, 9 do
	adaShop:SetAttribute("StageLevel", level)
	advance(0.15)
	check(maxHP() == 40, `niveau {level} : 40 coups (trouvé {maxHP()})`)
end
DAMAGE[ada] = 999999
advance(0.15)
check(maxHP() == 40, "les dégâts du propriétaire ne comptent pas")
DAMAGE[ada] = nil
adaShop:SetAttribute("StageLevel", 2)
advance(0.15)

section("Walls sans effet, Reinforced Door en coups (copie a159)")
buy(ada, "Walls")
check(ada:GetAttribute("Skill_Walls") == 1 and adaData.Cash == 1e12 - 10000, "Walls niveau 1 pour 10 000 $")
check(maxHP() == 40, `Walls 1 : toujours 40 coups (trouvé {maxHP()})`)
buy(ada, "GlassThickness")
check(maxHP() == 48, `Walls 1 et Glass 1 : 40 + 8 = 48 (trouvé {maxHP()})`)
local hpList = remotes("WindowHP", function(e)
	return e.args[1] == windowIdOf(adaShop)
end)
check(#hpList > 0 and hpList[#hpList].args[3] == 48, "WindowHP envoie le maximum de coups (barre BB_WindowHP)")
Workspace:SetAttribute("SkillTest", "Ada Walls 4")
Workspace:SetAttribute("SkillTest", nil)
advance(0.1)
Workspace:SetAttribute("SkillTest", "Ada GlassThickness 5")
advance(0.2)
check(maxHP() == 80, `Walls 4 et Glass 5 : 80 coups (trouvé {maxHP()})`)
DAMAGE[bob] = 2000
hitDoor(bob, adaShop, 3)
DAMAGE[bob] = nil
local hp, max = lastHP(adaShop)
check(max == 80 and hp < 80 and hp > 76.5, `Bob frappe la porte, 3 coups à 2000 de dégâts = 3 coups : {hp} / {max}`)
buy(ada, "Traps")
check(lastNotify(ada) == "Traps: coming soon!", `Traps s'ouvre à Walls 2 (Soon) : « {lastNotify(ada)} »`)

section("attribut WallsLevel de la parcelle")
check(adaShop:GetAttribute("WallsLevel") == 4, `WallsLevel = 4 (trouvé {adaShop:GetAttribute("WallsLevel")})`)
local bobShop = shopOf(bob)
check(bobShop:GetAttribute("WallsLevel") == 0, "Bob sans Walls : WallsLevel = 0")

section("mur visible par niveau")
Workspace:SetAttribute("SkillTest", "Ada Walls 0")
advance(0.1)
check(adaShop:GetAttribute("WallsLevel") == 0, "Walls 0 : WallsLevel = 0")
local w1 = newInstance("Part")
w1.Name = "Walls_1"
w1.Transparency = 0.2
w1:SetAttribute("HideFromWalls", 2)
w1.Parent = adaShop
local w2 = newInstance("Model")
w2.Name = "Walls_2"
w2:SetAttribute("ShowFromWalls", 2)
w2:SetAttribute("HideFromWalls", 3)
local w2Part = newInstance("Part")
w2Part.Transparency = 0.3
w2Part.Parent = w2
local w2Trail = newInstance("Trail")
w2Trail.Parent = w2
w2.Parent = adaShop
local w4 = newInstance("Part")
w4.Name = "Walls_4"
w4:SetAttribute("ShowFromWalls", 4)
w4.Parent = adaShop
advance(0.1)
check(w1.Transparency == 0.2 and w1.CanCollide == true, "niveau 0 : Walls_1 visible (HideFromWalls 2)")
check(w2Part.Transparency == 1 and w2Part.CanCollide == false and w2Part.CanQuery == false and w2Trail.Enabled == false, "niveau 0 : Walls_2 caché avec ses descendants")
check(w4.Transparency == 1 and w4.CanCollide == false, "niveau 0 : Walls_4 caché")
Workspace:SetAttribute("SkillTest", "Ada Walls 2")
advance(0.1)
check(w1.Transparency == 1 and w1.CanCollide == false, "niveau 2 : Walls_1 caché")
check(w2Part.Transparency == 0.3 and w2Part.CanCollide == true and w2Part.CanQuery == true and w2Trail.Enabled == true, "niveau 2 : Walls_2 rendu avec ses valeurs d'origine")
check(w4.Transparency == 1, "niveau 2 : Walls_4 toujours caché")
Workspace:SetAttribute("SkillTest", "Ada Walls 4")
advance(0.1)
check(w4.Transparency == 0 and w4.CanCollide == true and w2Part.Transparency == 1, "niveau 4 : Walls_4 montré, Walls_2 caché")
local late = newInstance("Part")
late:SetAttribute("HideFromWalls", 3)
late.Parent = adaShop
advance(0.05)
check(late.Transparency == 1, "pièce arrivée après coup (copie Stage_j) : revue tout de suite")
adaShop:SetAttribute("WallsLevel", 0)
advance(0.05)
check(w1.Transparency == 0.2 and w4.Transparency == 1, "WallsLevel posé à la main (bot, Studio) : visuel suivi")

section("parcelle libérée")
leave(ada)
advance(1)
check(adaShop:GetAttribute("OwnerUserId") ~= ada.UserId, "Ada partie : parcelle libérée")
check(adaShop:GetAttribute("WallsLevel") == 0, `parcelle libre : WallsLevel = 0 (trouvé {adaShop:GetAttribute("WallsLevel")})`)

section("sortie")
check(not logHas("ShopWallsService", "WARN"), "ShopWallsService : aucun avertissement")
check(not logHas("mal formé", "WARN"), "aucun envoi de remote mal formé")
summary("scénario walls")
