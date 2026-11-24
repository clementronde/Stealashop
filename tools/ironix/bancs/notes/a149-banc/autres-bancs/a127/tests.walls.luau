--!nocheck
-- a127 W, copie a149 (vague 42, L-150 points 5 (c) et 6 de Clément) : Stage_3/Walls suit la tuile Walls, mais ne se
-- voit qu'à partir du niveau 3 (plus de copie dans SkillVisuals) ; Stage_2/Murets_Sides (HideFromWalls = 1) part dès
-- Walls 1 ; Stage_5/Security et Stage_5/Alarm suivent Cameras 1. Harnais du banc vis-competences (copie a93 du banc
-- a84, plus le vrai ShopStageService), faux gabarit PLOT_Shop.
moduleScript(SERVICES, "ShopStageService", "server/Services/ShopStageService.luau")
startSkills()
local ShopStageService = serverModule("ShopStageService")

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
local function stage(n)
	local s = newInstance("Model")
	s.Name = "Stage_" .. n
	s.WorldPivot = CFrame.new()
	s.Parent = template
	return s
end
local function part(name, parent, transparency)
	local p = newInstance("Part")
	p.Name = name
	p.Transparency = transparency or 0
	p.Parent = parent
	return p
end
local stage2 = stage(2)
part("Murets", stage2)
local muretsSides = part("Murets_Sides", stage2)
muretsSides:SetAttribute("HideFromWalls", 1) -- copie a149 : réglage de Clément (L-150 point 6)
local stage3 = stage(3)
local walls = newInstance("Model")
walls.Name = "Walls"
walls.Parent = stage3
local wallL = part("Wall_L", walls)
local vitrine = part("Vitrine_L", walls, 0.55)
part("WallShelves", stage3)
local stage5 = stage(5)
local cams = newInstance("Model")
cams.Name = "Cameras"
cams.Parent = stage5
part("Cam_Door_Body", cams, 0.1)
local security = newInstance("Model")
security.Name = "Security"
security.Parent = stage5
part("Keypad", security)
local screen = part("KeypadScreen", security)
local screenLight = newInstance("PointLight")
screenLight.Enabled = true
screenLight.Parent = screen
local alarm = newInstance("Model")
alarm.Name = "Alarm"
alarm.Parent = stage5
part("AlarmBase", alarm)
part("AlarmDome", alarm)
part("LuxFacade", stage5)
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

local function skill(cmd)
	Workspace:SetAttribute("SkillTest", cmd)
	Workspace:SetAttribute("SkillTest", nil)
	advance(0.1)
end
local function level(k)
	ShopStageService.Apply(adaShop, k)
	ShopStageService.Apply(bobShop, k)
	advance(0.1)
end
-- Tous les « Walls » de la boutique (doit en avoir exactement un).
local function wallsOf(shop)
	local list = {}
	for _, d in shop:GetDescendants() do
		if d.Name == "Walls" then
			table.insert(list, d)
		end
	end
	return list
end
local function wallState(shop)
	local list = wallsOf(shop)
	if #list ~= 1 then
		return "absent", #list
	end
	local w = list[1]
	local l = w:FindFirstChild("Wall_L")
	local v = w:FindFirstChild("Vitrine_L")
	if l.Transparency == 0 and l.CanCollide == true and v.Transparency == 0.55 then
		return "shown", 1, w
	elseif l.Transparency == 1 and l.CanCollide == false and l.CanQuery == false and v.Transparency == 1 then
		return "hidden", 1, w
	end
	return "other", 1, w
end
local function where(shop)
	local _, _, w = wallState(shop)
	return if w == nil then "?" else w.Parent.Name
end

section("W1 sans Walls : murs cachés au niveau 3 et plus, absents en dessous")
check(ada:GetAttribute("Skill_Walls") == 0, "W1 (banc) Ada commence sans Walls")
for k = 1, 5 do
	level(k)
	if k < 3 then
		check(wallState(adaShop) == "absent" and select(2, wallState(adaShop)) == 0, `W1a niveau {k} : aucun Walls (copie a149 : plus de copie dans SkillVisuals)`)
	else
		check(wallState(adaShop) == "hidden" and where(adaShop) == "Stage_3", `W1b niveau {k}, Walls 0 : celui de Stage_3, caché (état {wallState(adaShop)})`)
	end
end
check(adaShop:FindFirstChild("Stage_3"):FindFirstChild("WallShelves").Transparency == 0, "W1c le reste de Stage_3 n'est pas touché")

section("W2 Walls 1 : murs montrés à partir du niveau 3 seulement, murets cachés dès Walls 1")
level(2)
local function murets(shop)
	local s2 = shop:FindFirstChild("Stage_2")
	return s2 and s2:FindFirstChild("Murets_Sides")
end
check(murets(adaShop) ~= nil and murets(adaShop).Transparency == 0, "W2 (banc) niveau 2, Walls 0 : murets visibles")
skill("Ada Walls 1")
check(adaShop:GetAttribute("WallsLevel") == 1, "W2 (banc) WallsLevel 1")
check(wallState(adaShop) == "absent", "W2a niveau 2, Walls 1 : pas de murs (L-150 point 5, réponse c)")
check(murets(adaShop).Transparency == 1 and murets(adaShop).CanCollide == false, "W2b niveau 2, Walls 1 : Murets_Sides (HideFromWalls = 1) caché (L-150 point 6)")
check(murets(bobShop).Transparency == 0, "W2c Bob (Walls 0) : ses murets visibles")
for k = 3, 5 do
	level(k)
	check(wallState(adaShop) == "shown", `W2d niveau {k}, Walls 1 : un seul Walls, montré (état {wallState(adaShop)})`)
	check(wallState(bobShop) == "hidden", `W2e niveau {k} : Bob, murs cachés`)
end
level(1)
check(wallState(adaShop) == "absent" and adaShop:FindFirstChild("Stage_3") == nil, "W2f redescente au niveau 1 : plus de murs")
local folder = adaShop:FindFirstChild("SkillVisuals")
check(folder == nil or folder:FindFirstChild("Walls") == nil, "W2g aucune copie des murs dans SkillVisuals")
section("W3 remise à zéro et Walls 3")
skill("Ada reset")
check(wallState(adaShop) ~= "shown", "W3a arbre remis à 0 au niveau 1 : pas de murs montrés")
level(4)
check(wallState(adaShop) == "hidden", "W3b niveau 4 : murs cachés")
skill("Ada Walls 3")
check(wallState(adaShop) == "shown", "W3c Walls 3 : murs montrés")
check(wallL.Transparency == 0 and wallL.CanCollide == true and vitrine.Transparency == 0.55, "W3d le gabarit n'est jamais modifié")

section("W4 digicode et gyrophare avec Cameras 1")
level(5)
local s5 = adaShop:FindFirstChild("Stage_5")
local function hiddenModel(m)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and (d.Transparency ~= 1 or d.CanCollide ~= false) then
			return false
		end
		if d:IsA("PointLight") and d.Enabled ~= false then
			return false
		end
	end
	return true
end
local function shownModel(m)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and (d.Transparency ~= 0 or d.CanCollide ~= true) then
			return false
		end
		if d:IsA("PointLight") and d.Enabled ~= true then
			return false
		end
	end
	return true
end
check(hiddenModel(s5.Security) and hiddenModel(s5.Alarm) and hiddenModel(s5.Cameras), "W4a niveau 5, Cameras 0 : digicode, gyrophare et caméras cachés (lumière comprise)")
check(s5.LuxFacade.Transparency == 0, "W4b LuxFacade pas touché")
skill("Ada Cameras 1")
check(shownModel(s5.Security) and shownModel(s5.Alarm), "W4c Cameras 1 : digicode et gyrophare montrés")
local b5 = bobShop:FindFirstChild("Stage_5")
check(hiddenModel(b5.Security) and hiddenModel(b5.Alarm), "W4d Bob sans Cameras : cachés chez lui")
level(1)
check(adaShop:FindFirstChild("SkillVisuals") == nil or (adaShop.SkillVisuals:FindFirstChild("Security") == nil and adaShop.SkillVisuals:FindFirstChild("Alarm") == nil), "W4e niveau 1 : pas de copie à part du digicode ni du gyrophare (décor du niveau 5)")

section("W5 parcelle libérée")
level(3)
skill("Ada Walls 1")
leave(ada)
advance(1)
if wallState(adaShop) ~= "absent" then
	check(wallState(adaShop) == "hidden", "W5a parcelle libre : murs cachés")
else
	check(true, "W5a parcelle libre : boutique revenue sans murs copiés")
end

section("sortie")
check(logCount("[ShopWallsService]", "WARN") == 0, "W6 aucun avertissement de ShopWallsService")
check(logCount("[ShopStageService]", "WARN") == logCount("pas d'attribut AccentColor", "WARN"), "W7 ShopStageService : seulement la ligne AccentColor (une par boutique)")
summary("scénario walls")
