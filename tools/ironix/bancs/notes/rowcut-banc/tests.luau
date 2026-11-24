--!nocheck
-- Banc rowcut (2026-11-15, L-190) : gabarit PLOT_Shop découpé par Clément, attribut RowCut. Assemblé depuis le banc a179 (préambule, boutique du hub) + part-template + part-scenarios.
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
-- Gabarit découpé comme Clément le fera (L-190 Q1) : chaque pièce qui traverse un fond est coupée aux plans
-- z −12, −4, 4, 8, 16, 24, 32 (40 = fond du gabarit), même nom, même parent. Pièces fines du fond entières.
local PLANES = { -12, -4, 4, 8, 16, 24, 32 }
local function cutBox(name, parent, frame, x0, y0, z0, x1, y1, z1)
	local cuts = { z0 }
	for _, z in PLANES do
		if z > z0 + 1e-6 and z < z1 - 1e-6 then
			table.insert(cuts, z)
		end
	end
	table.insert(cuts, z1)
	local out = {}
	for i = 1, #cuts - 1 do
		table.insert(out, box(name, parent, frame, x0, y0, cuts[i], x1, y1, cuts[i + 1]))
	end
	return out
end
do
	stage(template, 1, T)
	local s2 = stage(template, 2, T)
	for _, p in cutBox("PlotFloorExt", s2, T, -24, -0.6, -16, 24, 0.3, 40) do
		p:SetAttribute("Accent", true)
	end
	local murets = new("Model", "Murets_Sides", s2)
	cutBox("Muret_L", murets, T, -24, 0.3, -39, -23, 3.3, 40)
	box("Muret_B", murets, T, -23, 0.3, 39, 23, 3.3, 40)
	local barriers = new("Model", "Barriers", s2)
	for _, p in cutBox("Barrier_L", barriers, T, -24, 0.3, -40, -23.6, 30, 40) do
		p.Transparency = 1
	end
	box("Barrier_B", barriers, T, -24, 0.3, 39.6, 24, 30, 40).Transparency = 1
	-- Tronçons pile sur le plan z 4 (et à 0,03 près, bruit de Studio) : devant le fond 4 ; au-delà, retirés.
	local deco = new("Model", "Deco", s2)
	box("Touch_Front", deco, T, 10, 0.3, 0, 11, 1, 4)
	box("Touch_Noise", deco, T, 12, 0.3, 0, 13, 1, 4.03)
	box("Touch_Back", deco, T, 14, 0.3, 4, 15, 1, 6)
	box("Touch_Over", deco, T, 16, 0.3, 0, 17, 1, 4.1)
	local s3 = stage(template, 3, T)
	local walls = new("Model", "Walls", s3)
	cutBox("Wall_L", walls, T, -24, 0.3, -39, -23, 16.2, 40)
	box("Wall_B", walls, T, -23, 0.3, 39, 23, 16.2, 40)
	cutBox("InnerSkin_L", walls, T, -23, 0.3, -39, -22.9, 16.1, 39)
	box("InnerSkin_B", walls, T, -22.9, 0.3, 38.9, 22.9, 16.1, 39)
	-- Pièce longue laissée entière : raccourcie sans RowCut (coupe d'a179), retirée avec RowCut tant que la
	-- boutique n'est pas entière.
	box("Uncut_R", walls, T, 23, 0.3, -39, 24, 16.2, 40)
	local s4 = stage(template, 4, T)
	local roof = new("Model", "Roof", s4)
	cutBox("RoofSlab", roof, T, -24, 16.2, -40, 24, 17, 40)
	cutBox("Ceiling", roof, T, -22.9, 16.1, -39, 22.9, 16.2, 38.9)
	box("Parapet_B", roof, T, -24, 17, 39.4, 24, 18, 40)
	box("AC_2", roof, T, -2, 17, 20.4, 2, 19.2, 23.6)
	local s5 = stage(template, 5, T)
	local cams = new("Model", "Cameras", s5)
	part("Cam_BackL_Body", cams, T * CFrame.lookAt(Vector3.new(-22.1, 14.6, 37.3), Vector3.new(0, 2, 0)), Vector3.new(0.7, 0.7, 1.6))
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

local function key(rel, size, cf)
	local function r(x) return math.floor(x * 1000 + 0.5) / 1000 end
	local p, l = cf.Position, cf.LookVector
	return string.format("%s|%.3f,%.3f,%.3f|%.3f,%.3f,%.3f|%.3f,%.3f,%.3f", rel, r(size.X), r(size.Y), r(size.Z), r(p.X), r(p.Y), r(p.Z), r(l.X), r(l.Y), r(l.Z))
end
-- Pièces attendues dans les copies Stage_2..Stage_level avec RowCut : gardées telles quelles si leur bord arrière
-- est au plus à 0,05 au-delà du fond, pièces fines du fond avancées, le reste absent.
local function expectedRowCut(level, depth)
	local lines = {}
	local tp = template:GetPivot()
	for j = 2, level do
		local s = find(template, "Stage_" .. j)
		for _, d in s:GetDescendants() do
			if d:IsA("BasePart") then
				local cf = tp:Inverse() * d.CFrame
				local z0, z1 = span(template, d)
				local rel = "Stage_" .. j .. "." .. string.sub(d:GetFullName(), #s:GetFullName() + 2)
				if depth == nil or z1 <= depth + 0.05 then
					table.insert(lines, key(rel, d.Size, cf))
				elseif 40 - z1 <= 4 and z0 >= 36 and z1 - z0 <= 2 then
					table.insert(lines, key(rel, d.Size, cf + Vector3.new(0, 0, depth - 40)))
				end
			end
		end
	end
	table.sort(lines)
	return table.concat(lines, "\n")
end
local function actual(plot)
	local lines = {}
	local pp = plot:GetPivot()
	for _, c in plot:GetChildren() do
		local n = tonumber(string.match(c.Name, "^Stage_(%d+)$") or "")
		if n and n >= 2 then
			for _, d in c:GetDescendants() do
				if d:IsA("BasePart") then
					local rel = c.Name .. "." .. string.sub(d:GetFullName(), #c:GetFullName() + 2)
					table.insert(lines, key(rel, d.Size, pp:Inverse() * d.CFrame))
				end
			end
		end
	end
	table.sort(lines)
	return table.concat(lines, "\n")
end
local function firstDiff(a, b)
	local la, lb = string.split(a, "\n"), string.split(b, "\n")
	local seen = {}
	for _, l in lb do seen[l] = (seen[l] or 0) + 1 end
	for _, l in la do
		if (seen[l] or 0) == 0 then return "attendu absent : " .. l end
		seen[l] -= 1
	end
	for l, c in seen do
		if c > 0 then return "en trop : " .. l end
	end
	return ""
end

---------------------------------------------------------------- R1 sans RowCut : coupe d'a179 (filet)
print("\nR1 sans RowCut : la coupe d'a179 reste (Bob, 11 présentoirs)")
check(template:GetAttribute("RowCut") == nil, "gabarit sans attribut RowCut")
setCount(bob, 11)
PlotService.Assign(bob, plot2)
advance(0.1)
local d11 = expectedDepth(11)
check(near(plot2:GetAttribute("StageDepth"), d11), `fond {tostring(plot2:GetAttribute("StageDepth"))} (attendu {d11})`)
do
	local uncut = find(plot2, "Stage_3.Walls.Uncut_R")
	local z0, z1 = nil, nil
	if uncut then z0, z1 = span(plot2, uncut) end
	check(uncut ~= nil and near(z0, -39) and near(z1, d11), `pièce longue entière raccourcie au fond ({tostring(z0)}..{tostring(z1)})`)
	local over = find(plot2, "Stage_2.Deco.Touch_Over")
	check(over ~= nil, "petite pièce à cheval, centre devant : gardée (règle d'a179)")
end
PlotService.Release(bob)
advance(0.1)

---------------------------------------------------------------- R2 avec RowCut : garder ou retirer, rien de raccourci
print("\nR2 avec RowCut = true : présentoir par présentoir, de 4 à 20 (Alice)")
template:SetAttribute("RowCut", true)
setCount(alice, 4)
PlotService.Assign(alice, plot1)
advance(0)
for count = 4, 20 do
	setCount(alice, count)
	local depth = expectedDepth(count)
	local level = math.min(5, math.ceil(count / 4))
	local limit = depth or 40
	check(plot1:GetAttribute("StageLevel") == level and (depth ~= nil) == (plot1:GetAttribute("StageDepth") ~= nil) and near(plot1:GetAttribute("StageDepth") or 40, limit),
		`{count} : niveau {level}, fond {tostring(depth)}`)
	local want, got = expectedRowCut(level, depth), actual(plot1)
	check(want == got, `{count} : pièces gardées identiques au gabarit, fines du fond avancées, le reste retiré {firstDiff(want, got)}`)
	local beyond = {}
	for _, d in plot1:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			local _, z1 = span(plot1, d)
			if z1 > limit + 0.05 then
				table.insert(beyond, d.Name)
			end
		end
	end
	check(#beyond == 0, `{count} : rien de visible au-delà du fond ({table.concat(beyond, ", ")})`)
	if level >= 2 then
		local _, b1 = span(plot1, find(plot1, "Stage_2.Barriers.Barrier_B"))
		check(near(b1, limit) and near(pointZ(plot1), limit - 2.4), `{count} : mur invisible du fond et point du panneau avancés ({b1}, {pointZ(plot1)})`)
	end
	if level >= 3 then
		check((find(plot1, "Stage_3.Walls.Uncut_R") ~= nil) == (depth == nil), `{count} : pièce non découpée retirée tant que la boutique n'est pas entière`)
	end
	if level >= 5 then
		local c0, c1 = span(plot1, find(plot1, "Stage_5.Cameras.Cam_BackL_Body"))
		check(near((c0 + c1) / 2, 37.3 + limit - 40), `{count} : caméra du fond avancée`)
	end
end

---------------------------------------------------------------- R3 tronçon pile sur le plan
print("\nR3 tronçons pile sur le plan z 4 (9 présentoirs)")
setCount(alice, 9)
check(near(plot1:GetAttribute("StageDepth"), 4), `fond 4 ({tostring(plot1:GetAttribute("StageDepth"))})`)
check(find(plot1, "Stage_2.Deco.Touch_Front") ~= nil and find(plot1, "Stage_2.Deco.Touch_Noise") ~= nil, "tronçon qui finit sur le plan (et à 0,03 près) : gardé")
check(find(plot1, "Stage_2.Deco.Touch_Back") == nil and find(plot1, "Stage_2.Deco.Touch_Over") == nil, "tronçon qui commence sur le plan, ou qui le dépasse de 0,1 : retiré")
do
	local n = 0
	for _, d in find(plot1, "Stage_2"):GetDescendants() do
		if d.Name == "PlotFloorExt" then
			local _, z1 = span(plot1, d)
			check(z1 <= 4 + 1e-3, `tronçon de sol gardé devant le fond ({z1})`)
			n += 1
		end
	end
	check(n == 3, `3 tronçons de sol (−16..−12, −12..−4, −4..4) : {n}`)
end

---------------------------------------------------------------- R4 boutique entière, gabarit intact
print("\nR4 boutique entière (19 et 20 présentoirs), gabarit intact")
setCount(alice, 19)
check(plot1:GetAttribute("StageDepth") == nil and actual(plot1) == expectedRowCut(5, nil), "19 présentoirs : tout montré, comme le gabarit")
setCount(alice, 20)
check(actual(plot1) == expectedRowCut(5, nil), "20 présentoirs : tout montré")
check(templateSignature() == templateBefore, "gabarit et visuels des rayons intacts")

summary()
