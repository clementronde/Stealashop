--!nocheck
-- a127 W (2026-11-14, vague 38, L-137 points 1 et 3) : les murs Stage_3/Walls suivent la tuile Walls à tous les
-- niveaux de la boutique (copie à part dans SkillVisuals sous le niveau 3) ; Stage_5/Security et Stage_5/Alarm
-- suivent Cameras 1, comme les caméras. Harnais du banc vis-competences (copie a93 du banc a84, plus le vrai
-- ShopStageService), faux gabarit PLOT_Shop.
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

section("W1 sans Walls : murs cachés à tous les niveaux")
check(ada:GetAttribute("Skill_Walls") == 0, "W1 (banc) Ada commence sans Walls")
for k = 1, 5 do
	level(k)
	check(wallState(adaShop) == "hidden", `W1a niveau {k}, Walls 0 : un seul Walls, caché (état {wallState(adaShop)})`)
	local expected = if k < 3 then "SkillVisuals" else "Stage_3"
	check(where(adaShop) == expected, `W1b niveau {k} : Walls rangé dans {expected} (trouvé {where(adaShop)})`)
end
check(adaShop:FindFirstChild("Stage_3"):FindFirstChild("WallShelves").Transparency == 0, "W1c le reste de Stage_3 n'est pas touché")

section("W2 Walls 1 : murs montrés à tous les niveaux, Bob sans Walls")
level(1)
skill("Ada Walls 1")
check(adaShop:GetAttribute("WallsLevel") == 1, "W2 (banc) WallsLevel 1")
check(wallState(adaShop) == "shown", "W2a niveau 1, Walls 1 : murs montrés tout de suite")
check(wallState(bobShop) == "hidden", "W2b Bob (Walls 0) : murs cachés")
for k = 2, 5 do
	level(k)
	check(wallState(adaShop) == "shown", `W2c niveau {k}, Walls 1 : un seul Walls, montré (état {wallState(adaShop)}, {select(2, wallState(adaShop))} trouvé(s))`)
	check(wallState(bobShop) == "hidden", `W2d niveau {k} : Bob, murs cachés`)
end
for k = 4, 1, -1 do
	level(k)
	check(wallState(adaShop) == "shown", `W2e redescente au niveau {k} : murs toujours montrés`)
end
local folder = adaShop:FindFirstChild("SkillVisuals")
check(folder ~= nil and folder:FindFirstChild("Walls") ~= nil and adaShop:FindFirstChild("Stage_3") == nil, "W2f niveau 1 : la copie à part est dans SkillVisuals, pas de Stage_3")

section("W3 remise à zéro et Walls 3")
skill("Ada reset")
check(wallState(adaShop) == "hidden", "W3a arbre remis à 0 au niveau 1 : murs cachés")
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
check(adaShop:FindFirstChild("SkillVisuals"):FindFirstChild("Security") == nil and adaShop:FindFirstChild("SkillVisuals"):FindFirstChild("Alarm") == nil, "W4e niveau 1 : pas de copie à part du digicode ni du gyrophare (décor du niveau 5)")

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
