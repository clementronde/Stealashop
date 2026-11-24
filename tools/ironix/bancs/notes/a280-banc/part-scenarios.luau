---------------------------------------------------------------- a280 : Floor_2 du gabarit (sur le toit, y 16,2 à 32)
local floor2 = new("Model", "Floor_2", template)
floor2.WorldPivot = T * CFrame.new(0, 16.2, 0)
local deck = box("Deck", floor2, T, -24, 16.2, -40, 24, 17, 40)
deck:SetAttribute("Accent", true)
deck.Color = GREY
local glass = box("Glass_L", floor2, T, -24, 17, -40, -23.6, 32, 40)
glass.Transparency = 0.88
new("Script", "Leftover", floor2) -- retiré de la copie (aucun script, CLAUDE.md)
local light = new("PointLight", "Lamp", deck)
for n = 31, 40 do -- _39 et _40 : ancien contrat (L-277), plus lus depuis L-294
	local stand = box(string.format("FloorStand_%02d", n), floor2, T, -2, 17, n - 2, 2, 18, n + 2)
	new("Attachment", string.format("DisplaySlot_%02d", n), stand)
	box(string.format("CollectPad_%02d", n), floor2, T, 5, 17, n - 1, 7, 17.1, n + 1)
end
-- Looks de résistance de l'étage (L-294 Q3) : Look_0 au départ, Look_1 avec GlassThickness 1.
local look0 = new("Model", "Look_0", floor2)
look0:SetAttribute("HideFromSkill", "GlassThickness 1")
box("Wood", look0, T, -24, 17, 39, 24, 18, 40)
local look1 = new("Model", "Look_1", floor2)
look1:SetAttribute("ShowFromSkill", "GlassThickness 1")
look1:SetAttribute("HideFromSkill", "GlassThickness 2")
box("Steel", look1, T, -24, 17, 38, 24, 18, 39)
local function templateSignature()
	local lines = {}
	for _, d in template:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(lines, d:GetFullName() .. tostring(d.Size) .. tostring(d.CFrame.Position) .. d.Transparency .. tostring(d.Color))
		end
	end
	table.sort(lines)
	return table.concat(lines, "\n")
end
local templateBefore = templateSignature()

local ShopFloor = requireModule(find(Shared, "ShopFloor"), "server")
local PlotService = requireModule(PlotModule, "server")
PlotService.Plots = { plot1, plot2 }
local Stage = requireModule(StageModule, "server")
local Rayon = requireModule(RayonModule, "server")
local WallsModule = moduleScript(Services, "ShopWallsService", "server/Services/ShopWallsService.luau")
local Walls = requireModule(WallsModule, "server")
taskLib.spawn(Rayon.Start)
advance(0)

local function players(name, id)
	local p = new("Player", name, Players)
	rawget(p, "_props").UserId = id
	new("PlayerGui", "PlayerGui", p)
	return p
end
local alice = players("Alice", 101)
local bob = players("Bob", 102)
Walls.Init() -- après les joueurs : le faux Players ne signale pas PlayerAdded
-- Niveau DisplaySlots `level`, échelle `layout` (champ ShopLayout).
local function setData(p, level, layout)
	FAKE_DATA[p] = { Upgrades = { DisplaySlots = level, Treadmill = 0, Bench = 0 }, Rebirths = 0, ShopLayout = layout }
	p:SetAttribute("TreadmillLevel", 0)
	p:SetAttribute("BenchLevel", 0)
	p:SetAttribute("DisplaySlotsLevel", level)
	advance(0)
end
local function visibleParts(model)
	local shown, hidden = 0, 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Transparency < 1 and d.CanCollide then
				shown += 1
			elseif d.Transparency == 1 and not d.CanCollide then
				hidden += 1
			end
		end
	end
	return shown, hidden
end
local function parked(inst)
	local folder = ServerStorage:FindFirstChild("ShopFloorParking")
	return folder ~= nil and inst ~= nil and inst.Parent == folder
end

---------------------------------------------------------------- F1 règles (Shared/ShopFloor)
print("\nF1 règles de Shared/ShopFloor")
check(ShopFloor.Stands(8, 1) == 8 and ShopFloor.Stands(8, 0) == 0 and ShopFloor.Stands(8, nil) == 0 and ShopFloor.Stands(10, 1) == 8, "places ouvertes : 8 avec ShopLayout 1, 0 avec l'ancienne échelle, jamais plus de 8")
check(ShopFloor.Stands(0 / 0, 1) == 0 and ShopFloor.Stands(3, 1) == 3, "NaN refusé ; capacité 3 gardée")
do
	local a, b = ShopFloor.Total(5, 0)
	check(ShopFloor.BaseSlots(16, 0) == 20 and ShopFloor.NextSlot(15, 0) == 20 and ShopFloor.NextSlot(16, 0) == nil and ShopFloor.StandCost(15, 0) == 4_300_000 and ShopFloor.StandCost(16, 0) == nil and a == 9 and b == 20, "sans étage : comme avant (20 présentoirs, prix du bas, 9/20)")
end
check(ShopFloor.BaseSlots(3, 8) == 7 and ShopFloor.BaseSlots(4, 8) == 8 and ShopFloor.BaseSlots(13, 8) == 8, "avec l'étage : le bas s'arrête à 8")
check(ShopFloor.IsFloorStep(4, 8) and not ShopFloor.IsFloorStep(3, 8) and not ShopFloor.IsFloorStep(4, 0), "5e achat = l'étage")
check(not ShopFloor.Bought(4, 8) and ShopFloor.Bought(5, 8) and not ShopFloor.Bought(5, 0), "étage acheté au niveau 5")
check(ShopFloor.Unlocked(5, 8) == 0 and ShopFloor.Unlocked(6, 8) == 1 and ShopFloor.Unlocked(13, 8) == 8 and ShopFloor.Unlocked(20, 8) == 8 and ShopFloor.Unlocked(20, 0) == 0, "places débloquées une à une après l'étage, au plus 8")
check(ShopFloor.NextSlot(3, 8) == 8 and ShopFloor.NextSlot(4, 8) == 8 and ShopFloor.NextSlot(5, 8) == 31 and ShopFloor.NextSlot(12, 8) == 38 and ShopFloor.NextSlot(13, 8) == nil, "prochain présentoir : 8, l'étage au 8, puis 31 à 38")
check(ShopFloor.StandCost(0, 8) == 500 and ShopFloor.StandCost(3, 8) == 2_100 and ShopFloor.StandCost(4, 8) == 2_800 and ShopFloor.StandCost(5, 8) == 3_600 and ShopFloor.StandCost(12, 8) == 300_000 and ShopFloor.StandCost(13, 8) == nil, "prix V0 : bas inchangé, étage 2,8K, places 3,6K à 300K, rien après")
check(ShopFloor.NextSlot(8, 3) == nil and ShopFloor.StandCost(8, 3) == nil and ShopFloor.StandCost(7, 3) == 9_800, "3 places posées : rien après la 3e")
do
	local a, b = ShopFloor.Total(4, 8)
	local c, d = ShopFloor.Total(7, 8)
	local e, f = ShopFloor.Total(13, 8)
	check(a == 8 and b == 16 and c == 10 and d == 16 and e == 16 and f == 16, `« Stands x/y » : 8/16, 10/16, 16/16 ({a}/{b}, {c}/{d}, {e}/{f})`)
end

---------------------------------------------------------------- F2 migration des profils (ShopFloor.Migrate)
print("\nF2 migration des profils")
do
	local items = { a = {}, b = {}, c = {}, d = {}, e = {} }
	local data = { Upgrades = { DisplaySlots = 10 }, Items = items, Display = { ["1"] = "a", ["9"] = "b", ["10"] = "c", ["14"] = "d", ["21"] = "e" } }
	local note = ShopFloor.Migrate(data, 8)
	check(data.ShopLayout == 1 and data.Upgrades.DisplaySlots == 11 and note ~= nil, `14 présentoirs : niveau 10 → 11 (étage et 6 places offerts) ({data.Upgrades.DisplaySlots})`)
	local d = data.Display
	check(d["1"] == "a" and d["31"] == "b" and d["32"] == "c" and d["36"] == "d" and d["21"] == "e" and d["9"] == nil and d["10"] == nil and d["14"] == nil, "objets des présentoirs 9, 10 et 14 montés sur 31, 32 et 36 ; 1 et le bonus 21 inchangés")
	local a, b = ShopFloor.Total(data.Upgrades.DisplaySlots, 8)
	check(a == 14 and b == 16, `même nombre de places au total (14 : {a}/{b})`)
	check(ShopFloor.Migrate(data, 8) == nil and data.Upgrades.DisplaySlots == 11, "une seule fois")
end
do
	local display, items = {}, {}
	for n = 1, 20 do
		display[tostring(n)] = "u" .. n
		items["u" .. n] = {}
	end
	local data = { Upgrades = { DisplaySlots = 16 }, Items = items, Display = display }
	ShopFloor.Migrate(data, 8)
	local onFloor, gone = 0, 0
	for n = 31, 38 do
		onFloor += if display[tostring(n)] == "u" .. (n - 22) then 1 else 0
	end
	for n = 9, 20 do
		gone += if display[tostring(n)] == nil then 1 else 0
	end
	local kept = 0
	for _ in items do
		kept += 1
	end
	check(data.Upgrades.DisplaySlots == 13 and onFloor == 8 and gone == 12 and kept == 20, "20 présentoirs : niveau 13 (16 places), 9 à 16 à l'étage, 17 à 20 rendus à l'inventaire, Items intact")
end
do
	local data = { Upgrades = { DisplaySlots = 3 }, Items = {}, Display = { ["5"] = "x" } }
	check(ShopFloor.Migrate(data, 8) == nil and data.ShopLayout == 1 and data.Upgrades.DisplaySlots == 3 and data.Display["5"] == "x", "7 présentoirs : rien ne bouge, ShopLayout 1")
	local old = { Upgrades = { DisplaySlots = 12 }, Items = {}, Display = { ["12"] = "y" } }
	check(ShopFloor.Migrate(old, 0) == nil and old.ShopLayout == nil and old.Upgrades.DisplaySlots == 12 and old.Display["12"] == "y", "pas d'étage livré : profil laissé à l'ancienne échelle")
	local few = { Upgrades = { DisplaySlots = 10 }, Items = {}, Display = { ["13"] = "z", ["9"] = "w" } }
	ShopFloor.Migrate(few, 3)
	check(few.Upgrades.DisplaySlots == 8 and few.Display["31"] == "w" and few.Display["13"] == nil and few.Display["35"] == nil, "3 places posées : 3 offertes, l'objet du 13 rendu à l'inventaire")
end

---------------------------------------------------------------- F3 ancienne échelle : pas d'étage, 20 présentoirs
print("\nF3 Bob, ancienne échelle (ShopLayout 0), 20 présentoirs : pas d'étage")
setData(bob, 16, 0)
PlotService.Assign(bob, plot2)
advance(0.1)
check(Stage.FloorStands(plot2, 0) == 0 and Stage.FloorStands(plot2, 1) == 8 and Stage.FloorStands(plot2, nil) == 0, "places ouvertes : 0 avec l'ancienne échelle, 8 avec la nouvelle")
check(plot2:FindFirstChild("Floor_2") == nil, "aucun Floor_2 dans la boutique")
check(plot2:GetAttribute("StageLevel") == 5, `boutique entière comme avant (niveau {plot2:GetAttribute("StageLevel")})`)

---------------------------------------------------------------- F4 nouvelle échelle : 8 en bas, puis l'étage acheté
print("\nF4 Bob passe à la nouvelle échelle : 8 présentoirs, puis l'étage")
setData(bob, 4, 1)
advance(1.2)
local copy = Stage.EnsureFloor(plot2)
check(copy ~= nil and parked(copy) and plot2:FindFirstChild("Floor_2") == nil, "8 présentoirs : étage copié mais rangé hors de la boutique")
check(plot2:GetAttribute("StageLevel") == 2, `bas arrêté à 8 présentoirs (niveau {plot2:GetAttribute("StageLevel")})`)
setData(bob, 5, 1)
advance(0.1)
check(copy ~= nil and copy.Parent == plot2, "étage acheté (niveau 5) : dans la boutique")
if copy then
	local shown, hidden = visibleParts(copy)
	check(shown > 0, `pièces visibles ({shown} montrées, {hidden} cachées)`)
	check(copy:FindFirstChild("Leftover") == nil, "script retiré de la copie")
	check(find(copy, "Deck").Color == BLUE and find(template, "Floor_2.Deck").Color == GREY, "pièce Accent recolorée (AccentColor), gabarit intact")
	local want = P2 * T:Inverse() * find(template, "Floor_2.Deck").CFrame
	check(close(find(copy, "Deck").CFrame.Position, want.Position), "posé dans la boutique comme les Stage_j (pivot du gabarit → pivot de la boutique)")
	check(find(copy, "Glass_L").Transparency == 0.88 and find(copy, "Deck.Lamp").Enabled == true, "verre à 0,88, lumière allumée")
	local slots, count = Stage.FloorSlots(copy)
	check(count == 8 and slots[31] ~= nil and slots[38] ~= nil and slots[39] == nil and slots[31]:IsDescendantOf(plot2), "FloorSlots : DisplaySlot_31 à _38 (plus _39 ni _40)")
	check(Stage.EnsureFloor(plot2) == copy, "EnsureFloor rend la même copie (pas de doublon)")
end
check(plot2:GetAttribute("StageLevel") == 2, "bas toujours à 8 sous l'étage")

---------------------------------------------------------------- F5 renaissance : rangé, puis remis tel quel
print("\nF5 Bob refait une renaissance (niveau 0) : étage rangé, pas détruit")
setData(bob, 0, 1)
advance(0.1)
check(parked(copy) and Stage.EnsureFloor(plot2) == copy, "même copie, rangée")
setData(bob, 13, 1)
advance(0.1)
check(copy ~= nil and copy.Parent == plot2 and find(copy, "Glass_L").Transparency == 0.88 and find(copy, "Deck.Lamp").Enabled == true, "rachetée : remise telle quelle (verre 0,88, lumière)")

---------------------------------------------------------------- F6 looks de résistance (ShopWallsService, HideFromSkill)
print("\nF6 Look_0 / Look_1 de l'étage selon GlassThickness")
local function lookShown(root, name)
	local model = root:FindFirstChild(name)
	local p = model and model:FindFirstChildWhichIsA("BasePart")
	return p ~= nil and p.Transparency == 0
end
if copy then
	bob:SetAttribute("Skill_GlassThickness", 0)
	advance(0)
	check(lookShown(copy, "Look_0") and not lookShown(copy, "Look_1"), "niveau 0 : Look_0 seul")
	bob:SetAttribute("Skill_GlassThickness", 1)
	advance(0)
	check(not lookShown(copy, "Look_0") and lookShown(copy, "Look_1"), "niveau 1 : Look_1 seul (HideFromSkill = « GlassThickness 1 » sur Look_0)")
	bob:SetAttribute("Skill_GlassThickness", 2)
	advance(0)
	check(not lookShown(copy, "Look_0") and not lookShown(copy, "Look_1"), "niveau 2 : ni l'un ni l'autre (borne haute exclue)")
	setData(bob, 0, 1)
	advance(0.1)
	bob:SetAttribute("Skill_GlassThickness", 1)
	advance(0)
	setData(bob, 5, 1)
	advance(0.1)
	check(copy.Parent == plot2 and lookShown(copy, "Look_1") and not lookShown(copy, "Look_0"), "compétence changée pendant que l'étage est rangé : bon look à son retour")
end
do
	local bad = new("Model", "Look_9", nil)
	bad:SetAttribute("HideFromSkill", "Nope 1")
	local p = box("P", bad, P2, 0, 1, 0, 1, 2, 1)
	bad.Parent = plot2
	advance(0)
	check(p.Transparency == 0, "HideFromSkill illisible : pièce laissée telle quelle")
	local walls = new("Model", "Look_3", nil)
	walls:SetAttribute("ShowFromSkill", "GlassThickness 3")
	walls:SetAttribute("HideFromSkill", "GlassThickness 4")
	local q = box("Q", walls, P2, 0, 1, 0, 1, 2, 1)
	walls.Parent = plot2
	advance(0)
	check(q.Transparency == 1, "Look_3 caché à GlassThickness 1")
	bob:SetAttribute("Skill_GlassThickness", 3)
	advance(0)
	check(q.Transparency == 0, "Look_3 montré à GlassThickness 3")
	bob:SetAttribute("Skill_GlassThickness", 4)
	advance(0)
	check(q.Transparency == 1, "Look_3 caché à GlassThickness 4")
end

---------------------------------------------------------------- F7 départ du joueur : rangé
print("\nF7 Bob part : parcelle libérée, étage rangé")
PlotService.Release(bob)
advance(0.1)
check(parked(copy), "étage rangé sur une parcelle libre")

---------------------------------------------------------------- F8 EnsureFloor avant Apply : copie rangée tout de suite
print("\nF8 EnsureFloor sur plot1 (Alice, 6 présentoirs) : copie rangée dès sa pose")
setData(alice, 2, 1)
PlotService.Assign(alice, plot1)
advance(0.1)
local c1 = Stage.EnsureFloor(plot1)
check(c1 ~= nil and parked(c1) and c1 ~= copy, "copie posée, rangée, une par boutique")

---------------------------------------------------------------- F9 série interrompue, Floor_2 déjà dans la boutique
print("\nF9 places à la suite ; Floor_2 posé directement dans une boutique")
do
	local m = new("Model", "Floor_2", nil)
	for _, n in { 31, 32, 33, 34, 36 } do
		local p = part("S" .. n, m, CFrame.new(0, 0, n))
		new("Attachment", string.format("DisplaySlot_%02d", n), p)
	end
	local _, count = Stage.FloorSlots(m)
	check(count == 4 and ShopFloor.Capacity(m) == 4, `DisplaySlot_35 manquant : 4 places (31 à 34) ({count})`)
	local plot3 = new("Model", "PLOT_Shop_03", Workspace)
	plot3.WorldPivot = CFrame.new(400, 0, 0)
	local own = new("Model", "Floor_2", plot3)
	local deck3 = part("Deck", own, CFrame.new(400, 17, 0), Vector3.new(10, 1, 10))
	new("Attachment", "DisplaySlot_31", deck3)
	check(Stage.EnsureFloor(plot3) == own and Stage.FloorStands(plot3, 1) == 1, "Floor_2 de la boutique : lu tel quel, 1 place")
	Stage.Apply(plot3, 1, 4, false)
	check(parked(own) and Stage.EnsureFloor(plot3) == own, "rangé par Apply quand l'étage n'est pas montré (pas de copie en plus)")
	Stage.Apply(plot3, 2, 8, true)
	check(own.Parent == plot3 and deck3.Transparency == 0 and deck3.CanCollide, "remis par Apply quand il l'est, intact")
	check(ShopFloor.Capacity(floor2) == 8 and ShopFloor.TemplateFloor() == floor2, "Capacity du gabarit : 8 ; TemplateFloor le trouve")
end

---------------------------------------------------------------- F10 gabarit intact
print("\nF10 gabarit intact")
check(templateSignature() == templateBefore, "gabarit (Floor_2 compris) inchangé")
check(floor2:FindFirstChild("Leftover") ~= nil, "script du gabarit pas touché (seule la copie en est vidée)")

summary()
