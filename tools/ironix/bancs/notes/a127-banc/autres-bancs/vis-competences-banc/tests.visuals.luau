--!nocheck
-- Scénario « visuals » (2026-11-13, règle de Cantin) : un visuel de la boutique lié à une compétence de l'arbre
-- n'apparaît qu'à son déblocage, quel que soit le niveau de la boutique (ShopWallsService, Config/SkillTree
-- PlotVisuals et attribut ShowFromSkill). La boutique monte au niveau 5 par le vrai ShopStageService, depuis un
-- faux gabarit PLOT_Shop qui a Stage_5/Cameras (comme celui de Clément), Stage_5/Alarm et Stage_5/LuxFacade.
moduleScript(SERVICES, "ShopStageService", "server/Services/ShopStageService.luau")
startSkills()
local ShopStageService = serverModule("ShopStageService")

-- Faux gabarit ReplicatedStorage/Assets/Plots/PLOT_Shop (taggé PlayerPlot, comme dans Studio).
local assets = ReplicatedStorage:FindFirstChild("Assets")
if assets == nil then
	assets = newInstance("Folder")
	assets.Name = "Assets"
	assets.Parent = ReplicatedStorage
end
local plots = newInstance("Folder")
plots.Name = "Plots"
plots.Parent = assets
local template = newInstance("Model")
template.Name = "PLOT_Shop"
template.WorldPivot = CFrame.new()
local stage5 = newInstance("Model")
stage5.Name = "Stage_5"
stage5.WorldPivot = CFrame.new()
stage5.Parent = template
local cameras = newInstance("Model")
cameras.Name = "Cameras"
cameras.Parent = stage5
local body = newInstance("Part")
body.Name = "Cam_Door_Body"
body.Transparency = 0.1
body.Parent = cameras
local led = newInstance("Part")
led.Name = "Cam_Door_LED"
led.Parent = cameras
local light = newInstance("PointLight")
light.Enabled = true
light.Parent = led
local alarm = newInstance("Part")
alarm.Name = "Alarm"
alarm.Transparency = 0.25
alarm.Parent = stage5
local facade = newInstance("Part")
facade.Name = "LuxFacade"
facade.Parent = stage5
template.Parent = plots
CollectionService:AddTag(template, "PlayerPlot")

local adaData = newProfile()
adaData.Cash = 1e12
local ada = join("Ada", adaData)
local bob = join("Bob", newProfile())
advance(1.2)
local adaShop = shopOf(ada)
local bobShop = shopOf(bob)
for _, shop in { adaShop, bobShop } do
	if shop:GetPivot() == nil then
		shop.WorldPivot = CFrame.new()
	end
end

local function camOf(shop)
	local stage = shop:FindFirstChild("Stage_5")
	local cams = if stage then stage:FindFirstChild("Cameras") else nil
	return cams, if cams then cams:FindFirstChild("Cam_Door_Body") else nil, if cams then cams:FindFirstChild("Cam_Door_LED") else nil
end
local function shown(shop)
	local cams, b, l = camOf(shop)
	local pl = if l then l:FindFirstChildOfClass("PointLight") else nil
	return cams ~= nil and b.Transparency == 0.1 and b.CanCollide == true and b.CanQuery == true and l.Transparency == 0 and pl.Enabled == true
end
local function hiddenNow(shop)
	local cams, b, l = camOf(shop)
	local pl = if l then l:FindFirstChildOfClass("PointLight") else nil
	return cams ~= nil and b.Transparency == 1 and b.CanCollide == false and b.CanQuery == false and b.CanTouch == false and l.Transparency == 1 and pl.Enabled == false
end
local function baseIntact(shop)
	local stage = shop:FindFirstChild("Stage_5")
	local a = if stage then stage:FindFirstChild("Alarm") else nil
	local f = if stage then stage:FindFirstChild("LuxFacade") else nil
	return a ~= nil and a.Transparency == 0.25 and a.CanCollide == true and f.Transparency == 0
end

section("boutique au niveau 5 sans aucune compétence")
check(ada:GetAttribute("Skill_Cameras") == 0, "Ada commence sans Cameras")
ShopStageService.Apply(adaShop, 5)
ShopStageService.Apply(bobShop, 5)
advance(0.1)
check(camOf(adaShop) ~= nil, "Stage_5 copié du gabarit chez Ada")
check(hiddenNow(adaShop), "niveau 5, Cameras 0 : caméras cachées (pièces, lumière, collisions)")
check(hiddenNow(bobShop), "niveau 5, Cameras 0 : caméras cachées chez Bob aussi")
-- a127 (2026-11-14, L-137 point 1) : Alarm suit Cameras 1 ; LuxFacade n'est pas touché.
local function alarmHidden(shop)
	local stage = shop:FindFirstChild("Stage_5")
	local a = if stage then stage:FindFirstChild("Alarm") else nil
	local f = if stage then stage:FindFirstChild("LuxFacade") else nil
	return a ~= nil and a.Transparency == 1 and a.CanCollide == false and f.Transparency == 0
end
check(alarmHidden(adaShop), "niveau 5, Cameras 0 : Alarm caché (a127), LuxFacade pas touché")
check(body.Transparency == 0.1 and body.CanCollide == true and light.Enabled == true, "le gabarit PLOT_Shop (ReplicatedStorage) n'est jamais modifié")

section("déblocage")
buy(ada, "Cameras")
check(ada:GetAttribute("Skill_Cameras") == 1, "Ada achète Cameras 1")
check(shown(adaShop), "Cameras 1 : caméras d'Ada montrées tout de suite, valeurs d'origine rendues")
check(hiddenNow(bobShop), "Bob n'a pas Cameras : les siennes restent cachées")
check(baseIntact(adaShop), "Cameras 1 : Alarm montré à ses valeurs d'origine, LuxFacade inchangé")
check(alarmHidden(bobShop), "Bob sans Cameras : son Alarm reste caché")

section("niveau de boutique qui redescend puis remonte")
ShopStageService.Apply(adaShop, 1)
ShopStageService.Apply(bobShop, 1)
advance(0.1)
check(adaShop:FindFirstChild("Stage_5") == nil, "niveau 1 : Stage_5 retiré")
ShopStageService.Apply(adaShop, 5)
ShopStageService.Apply(bobShop, 5)
advance(0.1)
check(shown(adaShop), "nouvelle copie Stage_5 : caméras d'Ada (Cameras 1) montrées")
check(hiddenNow(bobShop), "nouvelle copie Stage_5 : caméras de Bob (Cameras 0) cachées")

section("crochet de test SkillTest (remise à zéro, puis niveau 2)")
Workspace:SetAttribute("SkillTest", "Ada reset")
Workspace:SetAttribute("SkillTest", nil)
advance(0.1)
check(ada:GetAttribute("Skill_Cameras") == 0 and hiddenNow(adaShop), "arbre remis à 0 : caméras cachées")
Workspace:SetAttribute("SkillTest", "Ada Cameras 2")
Workspace:SetAttribute("SkillTest", nil)
advance(0.1)
check(shown(adaShop), "Cameras 2 : caméras montrées")

section("attribut ShowFromSkill")
local cam2 = newInstance("Part")
cam2.Name = "Cam_Extra"
cam2:SetAttribute("ShowFromSkill", "Cameras 3")
cam2.Parent = adaShop
local safeBox = newInstance("Model")
safeBox.Name = "SafeCage"
safeBox:SetAttribute("ShowFromSkill", "Safe")
local safePart = newInstance("Part")
safePart.Transparency = 0.4
safePart.Parent = safeBox
safeBox.Parent = adaShop
local renamed = newInstance("Part")
renamed.Name = "Cameras" -- nom de PlotVisuals, mais l'attribut passe avant
renamed:SetAttribute("ShowFromSkill", "Safe 2")
renamed.Parent = adaShop
local typo = newInstance("Part")
typo.Name = "Typo"
typo.Transparency = 0.3
typo:SetAttribute("ShowFromSkill", "Camras")
typo.Parent = adaShop
advance(0.1)
check(cam2.Transparency == 1, "\"Cameras 3\" avec Cameras 2 : caché")
check(safePart.Transparency == 1 and safePart.CanCollide == false, "\"Safe\" (niveau 1 par défaut) avec Safe 0 : caché avec ses descendants")
check(renamed.Transparency == 1, "pièce nommée Cameras avec ShowFromSkill \"Safe 2\" : suit Safe, cachée")
check(typo.Transparency == 0.3 and typo.CanCollide == true, "Id inconnu : pièce laissée telle quelle")
check(logCount("ShowFromSkill = « Camras »", "WARN") == 1, "Id inconnu : une ligne dans la sortie")
Workspace:SetAttribute("SkillTest", "Ada Safe 1")
Workspace:SetAttribute("SkillTest", nil)
advance(0.1)
check(safePart.Transparency == 0.4 and safePart.CanCollide == true, "Safe 1 : montré, valeurs d'origine")
check(renamed.Transparency == 1, "Safe 1 : la pièce \"Safe 2\" reste cachée")
Workspace:SetAttribute("SkillTest", "Ada Safe 2")
Workspace:SetAttribute("SkillTest", nil)
advance(0.1)
check(renamed.Transparency == 0, "Safe 2 : montrée")
Workspace:SetAttribute("SkillTest", "Ada Cameras 3")
Workspace:SetAttribute("SkillTest", nil)
advance(0.1)
check(ada:GetAttribute("Skill_Cameras") == 3 and cam2.Transparency == 0, "Cameras 3 : \"Cameras 3\" montré")
local wallsTagged = newInstance("Part")
wallsTagged:SetAttribute("ShowFromSkill", "Walls 2")
wallsTagged.Parent = adaShop
advance(0.1)
check(wallsTagged.Transparency == 1, "\"Walls 2\" suit WallsLevel (0) : caché")
Workspace:SetAttribute("SkillTest", "Ada Walls 2")
Workspace:SetAttribute("SkillTest", nil)
advance(0.1)
check(adaShop:GetAttribute("WallsLevel") == 2 and wallsTagged.Transparency == 0, "Walls 2 : montré")

section("parcelle libérée, puis bot (attribut Skill_<Id> de la parcelle)")
leave(ada)
advance(1)
check(adaShop:GetAttribute("OwnerUserId") ~= ada.UserId, "Ada partie : parcelle libérée")
if camOf(adaShop) then
	check(hiddenNow(adaShop), "parcelle libre : caméras cachées")
else
	check(true, "parcelle libre : Stage_5 retiré")
	ShopStageService.Apply(adaShop, 5)
	advance(0.1)
	check(hiddenNow(adaShop), "parcelle libre au niveau 5 : caméras cachées")
end
adaShop:SetAttribute("Skill_Cameras", 1)
advance(0.1)
check(shown(adaShop), "Skill_Cameras = 1 posé sur la parcelle (bot, Studio) : caméras montrées")
adaShop:SetAttribute("Skill_Cameras", nil)
advance(0.1)
check(hiddenNow(adaShop), "attribut retiré : caméras cachées")

section("sortie")
check(logCount("[ShopWallsService]", "WARN") == 1, `ShopWallsService : un seul avertissement, celui de l'Id inconnu (trouvé {logCount("[ShopWallsService]", "WARN")})`)
check(not logHas("mal formé", "WARN"), "aucun envoi de remote mal formé")
summary("scénario visuals")
