--!nocheck
-- Copie a195 (vague 60, T-086) des scénarios a179 (2026-11-15, vague 55) : la boutique grandit petit à petit, un présentoir à la fois. Préambule repris du banc a83.
SOURCES["stub/DataService.luau"] = [[
local DataService = {}
function DataService.Get(player) return FAKE_DATA[player] end
function DataService.IsLoaded(player) return FAKE_DATA[player] ~= nil end
return DataService
]]

SOURCES["stub/PlotService.luau"] = [[
local PlotService = { Plots = {} }
local ownerOf, plotOf, assigned, released = {}, {}, {}, {}
function PlotService.GetPlots() return table.clone(PlotService.Plots) end
function PlotService.GetOwner(plot) return ownerOf[plot] end
function PlotService.GetPlot(player) return plotOf[player] end
function PlotService.OnPlotAssigned(fn)
	table.insert(assigned, fn)
	for player, plot in table.clone(plotOf) do task.spawn(fn, player, plot) end
	return function() end
end
function PlotService.OnPlotReleased(fn) table.insert(released, fn) return function() end end
function PlotService.Assign(player, plot)
	ownerOf[plot] = player
	plotOf[player] = plot
	plot:SetAttribute("OwnerUserId", player.UserId)
	for _, fn in assigned do task.spawn(fn, player, plot) end
end
function PlotService.Release(player)
	local plot = plotOf[player]
	plotOf[player] = nil
	ownerOf[plot] = nil
	plot:SetAttribute("OwnerUserId", 0)
	for _, fn in released do fn(player, plot) end
end
return PlotService
]]

BUY_LOG = {}
SOURCES["shared/Net/Net.luau"] = [[
return { Client = { BuyItem = { Fire = function(_, id) table.insert(BUY_LOG, id) end } } }
]]

FAKE_DATA = {}

---------------------------------------------------------------- arbre
local Shared = folder(ReplicatedStorage, "Shared")
do
	local keys = {}
	for key in SOURCES do
		if string.sub(key, 1, 7) == "shared/" then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	for _, key in keys do
		local parts = string.split(string.sub(key, 8), "/")
		local parent = Shared
		for i = 1, #parts - 1 do
			parent = parent:FindFirstChild(parts[i]) or folder(parent, parts[i])
		end
		moduleScript(parent, string.gsub(parts[#parts], "%.luau$", ""), key)
	end
end
local Services = folder(folder(ServerScriptService, "Server"), "Services")
moduleScript(Services, "DataService", "stub/DataService.luau")
local PlotModule = moduleScript(Services, "PlotService", "stub/PlotService.luau")
local StageModule = moduleScript(Services, "ShopStageService", "server/Services/ShopStageService.luau")
local RayonModule = moduleScript(Services, "RayonService", "server/Services/RayonService.luau")
local Controllers = folder(folder(StarterPlayerScripts, "Client"), "Controllers")
local UpgradeModule = moduleScript(Controllers, "UpgradeController", "client/Controllers/UpgradeController.luau")


local function new(class, name, parent)
	local inst = InstanceAPI.new(class)
	inst.Name = name
	if parent then
		inst.Parent = parent
	end
	return inst
end
local function part(name, parent, cframe, size)
	local p = new("Part", name, parent)
	p.Anchored = true
	p.CFrame = cframe
	if size then
		p.Size = size
	end
	return p
end
local function close(a, b, eps)
	return (a - b).Magnitude <= (eps or 1e-3)
end
local GREY = Color3.new(0.5, 0.5, 0.5)
local BLUE = Color3.new(0.18, 0.65, 0.95)
local RED = Color3.new(1, 0, 0)

-- UpgradeSign (comme a52), dans Assets/UI.
local Assets = folder(ReplicatedStorage, "Assets")
do
	local sign = new("Model", "UpgradeSign", folder(Assets, "UI"))
	sign.WorldPivot = CFrame.new(100, 10, 0)
	part("Foot", sign, CFrame.new(100, 10.3, 0), Vector3.new(1.3, 0.6, 1.3))
	local board = part("Board", sign, CFrame.new(100, 13.45, 0), Vector3.new(7, 4.5, 0.4))
	local gui = new("SurfaceGui", "SignGui", board)
	new("TextLabel", "Title", gui)
	new("TextLabel", "Level", gui)
	local buy = new("TextButton", "BuyButton", gui)
	new("TextLabel", "Price", buy)
	new("TextButton", "RobuxButton", gui)
end


---------------------------------------------------------------- géométrie (plot_shop_builder, L-141)
-- Boîte (x0, y0, z0) → (x1, y1, z1) dans le repère `frame`.
local function box(name, parent, frame, x0, y0, z0, x1, y1, z1)
	return part(name, parent, frame * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), Vector3.new(x1 - x0, y1 - y0, z1 - z0))
end
local function rowZ(r, b)
	return -32 + 7 * (2 * (r - 1) + b)
end
local function slotPos(n)
	local r = math.ceil(n / 4)
	local i = n - 4 * (r - 1)
	return Vector3.new(if i % 2 == 1 then -16 else 16, 1.5, rowZ(r, if i <= 2 then 0 else 1))
end

local T = CFrame.new(1000, 0, 0)
local Plots = folder(Assets, "Plots")
local template = new("Model", "PLOT_Shop", Plots)
template.WorldPivot = T
local store = new("Model", "PLOT_Shop_Rayons", Plots)
store.WorldPivot = T
local function stage(parent, n, pivot)
	local s = new("Model", "Stage_" .. n, parent)
	s.WorldPivot = pivot
	return s
end
do
	stage(template, 1, T)
	local s2 = stage(template, 2, T)
	box("PlotFloorExt", s2, T, -24, -0.6, -16, 24, 0.3, 40):SetAttribute("Accent", true)
	local tiles = new("Model", "FloorTilesExt", s2)
	for iz = 6, 19 do
		box("Tile_" .. iz, tiles, T, 0, 0.3, -40 + 4 * iz, 4, 0.32, -36 + 4 * iz)
	end
	box("CarpetExt", s2, T, -6, 0.32, -16.4, 6, 0.35, 39.6)
	local murets = new("Model", "Murets_Sides", s2)
	box("Muret_L", murets, T, -24, 0.3, -39, -23, 3.3, 40)
	box("Muret_B", murets, T, -23, 0.3, 39, 23, 3.3, 40)
	local field = new("Model", "ForceField", s2)
	field:SetAttribute("HideFromStage", 3)
	box("Field_L", field, T, -23.65, 3.3, -39.65, -23.55, 8.5, 39.65)
	local barriers = new("Model", "Barriers", s2)
	box("Barrier_L", barriers, T, -24, 0.3, -40, -23.6, 30, 40).Transparency = 1
	box("Barrier_B", barriers, T, -24, 0.3, 39.6, 24, 30, 40).Transparency = 1
	box("Barrier_Lid", barriers, T, -24, 30, -40, 24, 30.5, 40).Transparency = 1
	local spots = new("Model", "RayonSpots", s2)
	for r = 2, 5 do
		local spot = new("Model", string.format("RayonSpot_%02d", r), spots)
		box("Outline_L1", spot, T, -18.4, 0.32, rowZ(r, 0) - 2.4, -9, 0.36, rowZ(r, 0) - 2.1)
		box("Outline_L3", spot, T, -18.4, 0.32, rowZ(r, 0) - 2.1, -18.1, 0.36, rowZ(r, 1) + 2.1)
	end
	local s3 = stage(template, 3, T)
	local walls = new("Model", "Walls", s3)
	box("Wall_L", walls, T, -24, 0.3, -39, -23, 16.2, 40)
	box("Wall_B", walls, T, -23, 0.3, 39, 23, 16.2, 40)
	box("InnerSkin_L", walls, T, -23, 0.3, -39, -22.9, 16.1, 39)
	box("InnerSkin_B", walls, T, -22.9, 0.3, 38.9, 22.9, 16.1, 39)
	box("Vitrine_L", walls, T, -22, 3.6, -39.7, -11, 12.3, -39.3)
	local s4 = stage(template, 4, T)
	local roof = new("Model", "Roof", s4)
	box("RoofSlab", roof, T, -24, 16.2, -40, 24, 17, 40)
	box("Ceiling", roof, T, -22.9, 16.1, -39, 22.9, 16.2, 38.9)
	box("Parapet_B", roof, T, -24, 17, 39.4, 24, 18, 40)
	box("AC_2", roof, T, -2, 17, 20.4, 2, 19.2, 23.6)
	local lights = new("Model", "CeilingLights", s4)
	new("PointLight", "Light", box("Neon_1", lights, T, -0.4, 15.7, -30, 0.4, 16, 30))
	local s5 = stage(template, 5, T)
	local cams = new("Model", "Cameras", s5)
	local body = part("Cam_BackL_Body", cams, T * CFrame.lookAt(Vector3.new(-22.1, 14.6, 37.3), Vector3.new(0, 2, 0)), Vector3.new(0.7, 0.7, 1.6))
	local chand = new("Model", "Chandeliers", s5)
	box("Ring_1", chand, T, -1.6, 13.25, -13.6, 1.6, 13.55, -10.4)
	-- Visuels des rayons 2 à 5 (PLOT_Shop_Rayons, repère du gabarit) : socles et plaques.
	for r = 2, 5 do
		local R = new("Model", string.format("Rayon_%02d", r), store)
		R.WorldPivot = T
		for n = 4 * r - 3, 4 * r do
			local p = slotPos(n)
			box(string.format("DisplayStand_%02d", n), R, T, p.X - 2, 0.3, p.Z - 2, p.X + 2, 1.5, p.Z + 2)
			box(string.format("CollectPad_%02d", n), R, T, p.X * 11 / 16 - 1.6, 0.3, p.Z - 1.6, p.X * 11 / 16 + 1.6, 0.42, p.Z + 1.6)
		end
	end
end

-- Boutique du hub (niveau 1, comme install) : PlotFloor et ses points, Stage_1, PlotBarrier, Rayon_01 complet,
-- Rayon_02 à _05 avec leur RayonAnchor et leurs DisplaySlot.
local function buildPlot(name, pivot)
	local plot = new("Model", name, nil)
	plot.WorldPivot = pivot
	local floor = box("PlotFloor", plot, pivot, -24, -0.6, -40, 24, 0.3, -16)
	new("Attachment", "StageUpgradePoint", floor).CFrame = CFrame.new(0, 0.45, 9.4)
	new("Attachment", "StageUpgradePoint_2", floor).CFrame = CFrame.new(0, 0.45, 65.6)
	local s1 = stage(plot, 1, pivot)
	local rails = new("Model", "Railings", s1)
	rails:SetAttribute("HideFromStage", 2)
	box("Rail_B", rails, pivot, -24, 1.6, -16.5, 24, 1.85, -16.3)
	local barrier = new("Model", "PlotBarrier", plot)
	local small = box("Barrier_B1", barrier, pivot, -24, 0.3, -16.4, 24, 30, -16)
	small.Transparency = 1
	small:SetAttribute("HideFromStage", 2)
	for r = 1, 5 do
		local rayon = new("Model", string.format("Rayon_%02d", r), plot)
		local anchor = if r > 1 then box("RayonAnchor", rayon, pivot, -0.5, 1, rowZ(r, 0) - 0.5, 0.5, 1.5, rowZ(r, 0) + 0.5) else nil
		if anchor then
			anchor.Transparency = 1
		end
		for n = 4 * r - 3, 4 * r do
			local p = slotPos(n)
			local holder = anchor or box(string.format("DisplayStand_%02d", n), rayon, pivot, p.X - 2, 0.3, p.Z - 2, p.X + 2, 1.5, p.Z + 2)
			local at = new("Attachment", string.format("DisplaySlot_%02d", n), holder)
			at.CFrame = holder.CFrame:Inverse() * (pivot * CFrame.new(p.X, p.Y, p.Z))
		end
	end
	plot:SetAttribute("AccentColor", BLUE)
	plot.Parent = Workspace
	addTag(plot, "PlayerPlot")
	plot:SetAttribute("OwnerUserId", 0)
	return plot
end
local P1 = CFrame.new(50, 0, 30) * CFrame.Angles(0, math.pi / 2, 0)
local P2 = CFrame.new(-200, 0, 0)
local plot1 = buildPlot("PLOT_Shop_01", P1)
local plot2 = buildPlot("PLOT_Shop_02", P2)

local function find(root, path)
	local cur = root
	for _, name in string.split(path, ".") do
		cur = cur and cur:FindFirstChild(name)
	end
	return cur
end
-- z avant et arrière d'une pièce dans le repère de sa boutique (boîtes alignées, ou AABB pour une pièce tournée).
local function span(plot, p)
	local cf = plot:GetPivot():Inverse() * p.CFrame
	local s = p.Size
	local axes = { cf.RightVector, cf.UpVector, -cf.LookVector }
	local half = (math.abs(axes[1].Z) * s.X + math.abs(axes[2].Z) * s.Y + math.abs(axes[3].Z) * s.Z) / 2
	return cf.Position.Z - half, cf.Position.Z + half
end
local function near(a, b)
	return a ~= nil and b ~= nil and math.abs(a - b) <= 1e-3
end
local function isHidden(p)
	return p.Transparency == 1 and not p.CanCollide
end
-- Signature géométrique des copies (Stage_j, j ≥ 2) : chemin, z avant et arrière arrondis.
local function signature(plot)
	local lines = {}
	for _, c in plot:GetChildren() do
		local n = tonumber(string.match(c.Name, "^Stage_(%d+)$") or "")
		if n and n >= 2 then
			for _, d in c:GetDescendants() do
				if d:IsA("BasePart") then
					local z0, z1 = span(plot, d)
					local rel = string.sub(d:GetFullName(), #plot:GetFullName() + 2)
					table.insert(lines, string.format("%s %.2f %.2f %s", rel, z0, z1, tostring(isHidden(d))))
				end
			end
		end
	end
	table.sort(lines)
	return table.concat(lines, "\n")
end
local function templateSignature()
	local lines = {}
	for _, d in table.move(store:GetDescendants(), 1, #store:GetDescendants(), 1, template:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(lines, d:GetFullName() .. tostring(d.Size) .. tostring(d.CFrame.Position) .. d.Transparency)
		end
	end
	table.sort(lines)
	return table.concat(lines, "\n")
end
local templateBefore = templateSignature()

local PlotService = requireModule(PlotModule, "server")
PlotService.Plots = { plot1, plot2 }
local Stage = requireModule(StageModule, "server")
local Rayon = requireModule(RayonModule, "server")
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
local function setCount(p, count)
	FAKE_DATA[p] = { Upgrades = { DisplaySlots = count - 4, Treadmill = 0, Bench = 0 } }
	p:SetAttribute("TreadmillLevel", 0)
	p:SetAttribute("BenchLevel", 0)
	p:SetAttribute("DisplaySlotsLevel", count - 4)
	advance(0)
end
local function pointZ(plot)
	local at = find(plot, "PlotFloor.StageUpgradePoint_2")
	return plot:GetPivot():PointToObjectSpace(at.WorldCFrame.Position).Z
end
local function expectedDepth(count)
	if count <= 4 or count >= 19 then
		return nil
	end
	local z = slotPos(count).Z
	return math.ceil((z + 5 + 40) / 4 - 1e-3) * 4 - 40 -- RowMargin 5, Step 4, StepOrigin −40
end

---------------------------------------------------------------- G1 présentoir par présentoir
print("\nG1 présentoir par présentoir, de 4 à 20 (Alice)")
setCount(alice, 4)
PlotService.Assign(alice, plot1)
advance(0)
local stepSig = {}
for count = 4, 20 do
	setCount(alice, count)
	local depth = expectedDepth(count)
	local level = math.min(5, math.ceil(count / 4))
	local limit = depth or 40
	check(plot1:GetAttribute("StageLevel") == level and near(plot1:GetAttribute("StageDepth") or 40, limit) and (depth ~= nil) == (plot1:GetAttribute("StageDepth") ~= nil),
		`{count} présentoirs : niveau {level}, fond {tostring(depth)} (attribut {tostring(plot1:GetAttribute("StageDepth"))})`)
	-- rien de visible au-delà du fond
	local beyond = {}
	for _, d in plot1:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			local z0, z1 = span(plot1, d)
			if (z0 + z1) / 2 > limit + 1e-3 or z1 > limit + 1e-3 then
				table.insert(beyond, d.Name)
			end
		end
	end
	check(#beyond == 0, `{count} : rien de visible au-delà du fond ({table.concat(beyond, ", ")})`)
	if level >= 2 then
		local _, floorEnd = span(plot1, find(plot1, "Stage_2.PlotFloorExt"))
		local b0, b1 = span(plot1, find(plot1, "Stage_2.Barriers.Barrier_B"))
		local _, carpetEnd = span(plot1, find(plot1, "Stage_2.CarpetExt"))
		check(near(floorEnd, limit) and near(b1, limit) and near(b0, limit - 0.4) and near(carpetEnd, limit - 0.4),
			`{count} : sol, allée et mur invisible du fond au fond ({floorEnd}, {carpetEnd}, {b0}..{b1})`)
		local _, lid = span(plot1, find(plot1, "Stage_2.Barriers.Barrier_Lid"))
		check(near(lid, limit) and find(plot1, "Stage_2.Barriers.Barrier_Lid").CanCollide, `{count} : couvercle invisible jusqu'au fond, solide`)
		check(near(pointZ(plot1), limit - 2.4), `{count} : StageUpgradePoint_2 à 2,4 du fond ({pointZ(plot1)})`)
	end
	if level >= 3 then
		local w0, w1 = span(plot1, find(plot1, "Stage_3.Walls.Wall_B"))
		local _, side = span(plot1, find(plot1, "Stage_3.Walls.Wall_L"))
		local _, skin = span(plot1, find(plot1, "Stage_3.Walls.InnerSkin_L"))
		check(near(w0, limit - 1) and near(w1, limit) and near(side, limit) and near(skin, limit - 1), `{count} : murs fermés au fond (côté {side}, revêtement {skin}, fond {w0}..{w1})`)
		check(find(plot1, "Stage_3.Walls.Vitrine_L") ~= nil, `{count} : vitrine de façade intacte`)
	end
	if level >= 4 then
		local _, ceil = span(plot1, find(plot1, "Stage_4.Roof.Ceiling"))
		local _, neon = span(plot1, find(plot1, "Stage_4.CeilingLights.Neon_1"))
		local p0 = span(plot1, find(plot1, "Stage_4.Roof.Parapet_B"))
		check(near(ceil, limit - 1.1) and near(neon, math.min(30, limit - 1.5)) and near(p0, limit - 0.6), `{count} : plafond, néon et parapet suivent ({ceil}, {neon}, {p0})`)
		check((find(plot1, "Stage_4.Roof.AC_2") ~= nil) == (22 <= limit), `{count} : climatiseur au z 22 présent seulement s'il est dans la boutique`)
		check(find(plot1, "Stage_4.CeilingLights.Neon_1.Light") ~= nil, `{count} : la lumière du néon suit sa pièce`)
	end
	if level >= 5 then
		local c0, c1 = span(plot1, find(plot1, "Stage_5.Cameras.Cam_BackL_Body"))
		check(near((c0 + c1) / 2, 37.3 + limit - 40), `{count} : caméra du fond avancée avec le mur ({(c0 + c1) / 2})`)
		check(find(plot1, "Stage_5.Chandeliers.Ring_1") ~= nil, `{count} : lustre de devant gardé`)
	end
	-- socles des rayons montrés : cachés au-delà du fond, visibles en deçà
	local wrong = {}
	for n = 5, 4 * math.ceil(count / 4) do
		local stand = find(plot1, string.format("Rayon_%02d.RayonVisuals.DisplayStand_%02d", math.ceil(n / 4), n))
		local pad = find(plot1, string.format("Rayon_%02d.RayonVisuals.CollectPad_%02d", math.ceil(n / 4), n))
		local should = slotPos(n).Z + 2 > limit or n > count -- socle de 4 de profondeur ; a195 : pas encore débloqué
		if stand == nil or pad == nil or isHidden(stand) ~= should or isHidden(pad) ~= should then
			table.insert(wrong, tostring(n))
		end
	end
	check(#wrong == 0, `{count} : socles et plaques cachés au-delà du fond ou pas encore débloqués ({table.concat(wrong, ",")})`)
	stepSig[count] = signature(plot1)
end
check(stepSig[5] ~= stepSig[20] and stepSig[19] == stepSig[20], "19 et 20 présentoirs : même boutique entière")
do
	-- Au maximum : copies identiques au gabarit (aucune coupe).
	local same = true
	for _, d in find(template, "Stage_4"):GetDescendants() do
		if d:IsA("BasePart") then
			local copy = find(plot1, "Stage_4." .. string.sub(d:GetFullName(), #find(template, "Stage_4"):GetFullName() + 2))
			if copy == nil or not close(copy.Size, d.Size) then
				same = false
			end
		end
	end
	check(same and near(pointZ(plot1), 37.6), "20 présentoirs : rien de coupé, point du panneau à sa place d'origine")
end
local mid = 11
setCount(alice, mid)
check(signature(plot1) == stepSig[mid], "redescendu de 20 à 11 : même boutique qu'en montant")

---------------------------------------------------------------- G2 profil chargé au milieu
print("\nG2 profil chargé au milieu (Bob, 11 présentoirs d'un coup)")
setCount(bob, mid)
PlotService.Assign(bob, plot2)
advance(0.1)
check(plot2:GetAttribute("StageLevel") == 3 and near(plot2:GetAttribute("StageDepth"), expectedDepth(mid)), `niveau 3, fond {tostring(plot2:GetAttribute("StageDepth"))}`)
check(signature(plot2) == stepSig[mid], "même boutique qu'Alice arrivée pas à pas (autre pivot)")
check(not isHidden(find(plot2, "Rayon_03.RayonVisuals.DisplayStand_11")) and isHidden(find(plot2, "Rayon_03.RayonVisuals.DisplayStand_12")), "présentoir 11 visible, 12 caché (a195)")
advance(1.5)
check(signature(plot2) == stepSig[mid], "contrôle d'une seconde : rien ne bouge")

---------------------------------------------------------------- G3 client : panneau qui suit son point
print("\nG3 panneau des présentoirs (UpgradeController)")
rawget(Players, "_props").LocalPlayer = alice
CLIENT_PLAYER = alice
local Upgrade = requireModule(UpgradeModule, "client")
local function signs()
	local f = Workspace:FindFirstChild("UpgradeSigns")
	return if f then f:GetChildren() else {}
end
local function signNear(plot)
	local at = find(plot, "PlotFloor.StageUpgradePoint_2").WorldCFrame.Position
	local found = 0
	for _, sign in signs() do
		local boxCf, size = sign:GetBoundingBox()
		if close(boxCf.Position - Vector3.new(0, size.Y / 2, 0), at) then
			found += 1
		end
	end
	return found
end
setCount(alice, 5)
taskLib.spawn(Upgrade.Start)
advance(0.1)
check(signNear(plot1) == 1, "5 présentoirs : panneau d'Alice sur le point avancé")
setCount(alice, 9)
advance(0.1)
check(signNear(plot1) == 1 and near(pointZ(plot1), expectedDepth(9) - 2.4), "9 présentoirs : panneau reposé avec le fond")
check(signNear(plot2) == 1, "panneau de Bob sur son point")

---------------------------------------------------------------- G4 libérée, renaissance
print("\nG4 parcelle libérée et renaissance")
setCount(alice, 4) -- renaissance : présentoirs remis au départ
check(plot1:GetAttribute("StageLevel") == 1 and plot1:GetAttribute("StageDepth") == nil and find(plot1, "Stage_2") == nil, "4 présentoirs : niveau 1, pas de fond, plus de copie")
check(near(pointZ(plot1), 37.6), "point du panneau rendu à sa place")
PlotService.Release(bob)
advance(0.1)
check(plot2:GetAttribute("StageLevel") == 1 and plot2:GetAttribute("StageDepth") == nil and near(pointZ(plot2), 37.6), "Bob parti : parcelle 2 au niveau 1, point rendu")
setCount(alice, 7)
check(near(plot1:GetAttribute("StageDepth"), expectedDepth(7)) and signature(plot1) == stepSig[7], "Alice remonte à 7 : même boutique qu'au premier passage")
check(templateSignature() == templateBefore, "gabarit et visuels des rayons intacts")
check(find(template, "Stage_2.FloorTilesExt.Tile_19") ~= nil and find(template, "Stage_5.Cameras.Cam_BackL_Body") ~= nil, "aucune pièce retirée du gabarit")

summary()
