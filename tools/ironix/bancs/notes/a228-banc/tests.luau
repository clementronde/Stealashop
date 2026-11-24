--!nocheck
-- Banc a228 (vague 69) : la table `hidden` de ShopWallsService ne grandit plus quand les copies Stage_j sont
-- refaites (détruites puis recopiées) ; une pièce sortie puis remise (sans Destroy) garde ses valeurs d'origine.
-- Gabarit PLOT_Shop minimal (Stage_5 : Cameras, Alarm, LuxFacade), comme le banc vis-competences.
moduleScript(SERVICES, "ShopStageService", "server/Services/ShopStageService.luau")
startSkills()
local ShopStageService = serverModule("ShopStageService")
local ShopWallsService = serverModule("ShopWallsService")

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
local alarm = newInstance("Part")
alarm.Name = "Alarm"
alarm.Transparency = 0.25
alarm.Parent = stage5
local facade = newInstance("Part")
facade.Name = "LuxFacade"
facade.Parent = stage5
template.Parent = plots
CollectionService:AddTag(template, "PlayerPlot")

local bob = join("Bob", newProfile())
advance(1.2)
local shop = shopOf(bob)
if shop:GetPivot() == nil then
	shop.WorldPivot = CFrame.new()
end

local hidden = ShopWallsService._hidden
local function count()
	local n = 0
	for _ in hidden do
		n += 1
	end
	return n
end

section("table hidden exposée")
check(type(hidden) == "table", "ShopWallsService._hidden lisible (remplacement du source du banc)")

section("20 refontes de Stage_5")
ShopStageService.Apply(shop, 5)
advance(0.1)
local first = count()
check(first >= 2, `niveau 5, Cameras 0 : Cameras et Alarm cachés ({first} entrées)`)
for _ = 1, 20 do
	ShopStageService.Apply(shop, 1)
	advance(0.1)
	ShopStageService.Apply(shop, 5)
	advance(0.1)
end
check(count() == first, `après 20 refontes : {count()} entrées (attendu {first})`)
local stage = shop:FindFirstChild("Stage_5")
local cams = stage and stage:FindFirstChild("Cameras")
local camBody = cams and cams:FindFirstChild("Cam_Door_Body")
check(camBody ~= nil and camBody.Transparency == 1 and camBody.CanCollide == false, "copie neuve : caméras cachées")
ShopStageService.Apply(shop, 1)
advance(0.1)
check(shop:FindFirstChild("Stage_5") == nil and count() == first - first, `niveau 1 : Stage_5 détruit, table vide ({count()} entrées)`)

section("pièce sortie puis remise")
ShopStageService.Apply(shop, 5)
advance(0.1)
stage = shop:FindFirstChild("Stage_5")
cams = stage:FindFirstChild("Cameras")
camBody = cams:FindFirstChild("Cam_Door_Body")
check(hidden[cams] ~= nil, "Cameras cachée et suivie")
cams.Parent = nil
advance(0.1)
check(hidden[cams] ~= nil, "Cameras sortie (Parent = nil, sans Destroy) : entrée gardée")
cams.Parent = stage
advance(0.1)
check(camBody.Transparency == 1 and camBody.CanCollide == false, "remise : toujours cachée")
Workspace:SetAttribute("SkillTest", "Bob Cameras 1")
Workspace:SetAttribute("SkillTest", nil)
advance(0.1)
check(bob:GetAttribute("Skill_Cameras") == 1, "Bob passe à Cameras 1")
check(camBody.Transparency == 0.1 and camBody.CanCollide == true and camBody.CanQuery == true, "Cameras 1 : valeurs d'origine rendues à la pièce remise")
check(hidden[cams] == nil, "montrée : entrée retirée")
Workspace:SetAttribute("SkillTest", "Bob reset")
Workspace:SetAttribute("SkillTest", nil)
advance(0.1)
check(hidden[cams] ~= nil and camBody.Transparency == 1, "Cameras 0 : cachée de nouveau")
cams:Destroy()
advance(0.1)
check(hidden[cams] == nil, "Cameras détruite : entrée retirée")

section("sortie")
check(logCount("[ShopWallsService]", "WARN") == 0, "aucun avertissement de ShopWallsService")
summary("scénario a228")
