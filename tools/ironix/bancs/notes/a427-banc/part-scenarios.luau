---------------------------------------------------------------- a427 : Floor_2 au plan livré (L-321, grande_boutique_v1)
-- Plancher à y 23,7, places 31 à 38 (mêmes x, z qu'en bas, x ±24), bonus 21 à 24 au milieu ; chaque place : un socle
-- DisplayStand_xx (avec son DisplaySlot_xx) et une plaque CollectPad_xx (avec son PadBase).
SOURCES["stub/DisplayService.luau"] = [[
local DisplayService = {}
function DisplayService.GetExtraSlots(player) return FAKE_EXTRA[player] or 0 end
return DisplayService
]]
FAKE_EXTRA = {}
moduleScript(Services, "DisplayService", "stub/DisplayService.luau")

local floor2 = new("Model", "Floor_2", template)
floor2.WorldPivot = T * CFrame.new(0, 22.8, 0)
box("Floor2_A", floor2, T, -32, 22.8, -40, 32, 23.7, 8)
local ROWS = { -33, -23, -13, -3 }
local function place(n, x, z, padX)
	local stand = box(string.format("DisplayStand_%02d", n), floor2, T, x - 2, 23.7, z - 2, x + 2, 26, z + 2)
	new("Attachment", string.format("DisplaySlot_%02d", n), stand).CFrame = CFrame.new(0, 1.3, 0)
	local pad = box(string.format("CollectPad_%02d", n), floor2, T, padX - 2.3, 23.7, z - 2.5, padX + 2.3, 24.3, z + 2.5)
	pad.Transparency = 1
	box("PadBase", pad, T, padX - 2.3, 23.7, z - 2.5, padX + 2.3, 24, z + 2.5)
end
for n = 1, 8 do
	local x = if n % 2 == 1 then -24 else 24
	place(30 + n, x, ROWS[math.ceil(n / 2)], if x < 0 then -19.1 else 19.1)
end
for _, b in { { 21, -9, -30 }, { 22, 9, -30 }, { 23, -9, -16 }, { 24, 9, -16 } } do
	place(b[1], b[2], b[3], if b[2] < 0 then -4.5 else 4.5)
end

local ShopFloor = requireModule(find(Shared, "ShopFloor"), "server")
local Plan = requireModule(find(Shared, "ShopBuildPlan"), "server")
local PlotService = requireModule(PlotModule, "server")
PlotService.Plots = { plot1, plot2 }
local Stage = requireModule(StageModule, "server")
local Rayon = requireModule(RayonModule, "server")
taskLib.spawn(Rayon.Start)
advance(0)

local bob = new("Player", "Bob", Players)
rawget(bob, "_props").UserId = 102
new("PlayerGui", "PlayerGui", bob)
local function setData(p, level)
	FAKE_DATA[p] = { Upgrades = { DisplaySlots = level, Treadmill = 0, Bench = 0 }, Rebirths = 0, ShopLayout = 1 }
	p:SetAttribute("TreadmillLevel", 0)
	p:SetAttribute("BenchLevel", 0)
	p:SetAttribute("DisplaySlotsLevel", level)
	advance(0)
end
local function shown(part)
	return part ~= nil and part.Transparency < 1 and part.CanCollide
end
local function hidden(part)
	return part ~= nil and part.Transparency == 1 and not part.CanCollide and not part.CanQuery
end
-- Places de la liste `numbers` : socle et PadBase de la plaque visibles (true) ou cachés (false).
local function places(copy, numbers, visible)
	for _, n in numbers do
		local stand = copy:FindFirstChild(string.format("DisplayStand_%02d", n))
		local pad = copy:FindFirstChild(string.format("CollectPad_%02d", n))
		local base = pad and pad:FindFirstChild("PadBase")
		local ok = if visible then shown(stand) and shown(base) else hidden(stand) and hidden(base)
		if not ok then
			return false
		end
	end
	return true
end

---------------------------------------------------------------- P1 présentoir construit à chaque achat
print("\nP1 Shared/ShopFloor.StandAt et ShopBuildPlan.newStands")
check(ShopFloor.StandAt(1, 8) == 5 and ShopFloor.StandAt(4, 8) == 8 and ShopFloor.StandAt(0, 8) == nil, "bas : niveaux 1 à 4 → présentoirs 5 à 8, rien au niveau 0")
check(ShopFloor.StandAt(5, 8) == nil, "niveau 5 = achat de l'étage : aucun présentoir (Floor_2 construit à part)")
check(ShopFloor.StandAt(6, 8) == 31 and ShopFloor.StandAt(13, 8) == 38 and ShopFloor.StandAt(14, 8) == nil, "étage : niveaux 6 à 13 → 31 à 38, rien au-delà")
check(ShopFloor.StandAt(5, 0) == 9 and ShopFloor.StandAt(16, 0) == 20, "sans étage : comme avant (4 + niveau)")
do
	local function at8(level)
		return ShopFloor.StandAt(level, 8)
	end
	local old = Plan.newStands(4, 2, 4)
	local mixed = Plan.newStands(4, 3, 6, at8)
	local floorOnly = Plan.newStands(4, 4, 5, at8)
	check(#old == 2 and old[1] == 7 and old[2] == 8, "newStands sans fonction : inchangé (7, 8)")
	check(#mixed == 2 and mixed[1] == 8 and mixed[2] == 31, `newStands 3 → 6 avec l'étage : 8 puis 31 (pas 9 ni 10) ({table.concat(mixed, ", ")})`)
	check(#floorOnly == 0, "newStands 4 → 5 (l'étage) : aucun présentoir")
end

---------------------------------------------------------------- P2 places de l'étage cachées tant que pas achetées
print("\nP2 Bob : étage acheté, places une à une, bonus du gamepass")
setData(bob, 4)
PlotService.Assign(bob, plot2)
advance(0.1)
setData(bob, 5)
advance(0.1)
local copy = Stage.EnsureFloor(plot2)
check(copy ~= nil and copy.Parent == plot2, "étage acheté (niveau 5) : dans la boutique")
if copy then
	check(shown(copy:FindFirstChild("Floor2_A")), "plancher visible")
	check(places(copy, { 31, 32, 33, 34, 35, 36, 37, 38 }, false), "aucune place achetée : socles 31 à 38 et leurs plaques cachés")
	check(places(copy, { 21, 22, 23, 24 }, false), "sans le gamepass : bonus 21 à 24 cachés")
	check(copy:FindFirstChild("DisplayStand_31"):FindFirstChild("DisplaySlot_31") ~= nil and Stage.FloorStands(plot2, 1) == 8, "DisplaySlot_31 toujours là (invites, panneau) ; 8 places ouvertes")
	setData(bob, 6)
	check(places(copy, { 31 }, true) and places(copy, { 32, 38 }, false), "niveau 6 : place 31 montrée, 32 à 38 cachées")
	check(copy:FindFirstChild("CollectPad_31").Transparency == 1, "plaque invisible de Clément (Transparency 1) rendue telle quelle")
	FAKE_EXTRA[bob] = 4
	advance(1.2)
	check(places(copy, { 21, 22, 23, 24 }, true), "gamepass acheté (sans changer de niveau) : bonus 21 à 24 montrés au contrôle d'une seconde")
	FAKE_EXTRA[bob] = 2
	advance(1.2)
	check(places(copy, { 21, 22 }, true) and places(copy, { 23, 24 }, false), "2 bonus : 21 et 22 montrés, 23 et 24 cachés")
	setData(bob, 0)
	advance(0.1)
	local folder = ServerStorage:FindFirstChild("ShopFloorParking")
	check(folder ~= nil and copy.Parent == folder, "renaissance : étage rangé")
	setData(bob, 13)
	advance(0.1)
	check(copy.Parent == plot2 and places(copy, { 31, 32, 33, 34, 35, 36, 37, 38, 21, 22 }, true) and places(copy, { 23, 24 }, false), "niveau 13 : les 8 places montrées, bonus selon le gamepass")
	local deck = template:FindFirstChild("Floor_2"):FindFirstChild("DisplayStand_31")
	check(deck.Transparency == 0 and deck.CanCollide, "gabarit intact")
end

summary()
