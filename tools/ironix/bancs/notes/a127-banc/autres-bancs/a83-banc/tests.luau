--!nocheck
-- Scénarios a83 (2026-11-11, L-096 point 1) : la boutique grandit avec ses rayons.
-- Vrais : RayonService, ShopStageService (serveur), UpgradeController et PlotDoorController (client), Shared.
-- Bouchons : DataService (FAKE_DATA), PlotService (attribution et départ pilotés par le banc), Net (BuyItem).
--   B1 démarrage, parcelles libres : niveau 1, aucune copie, rien de caché, StageLevel = 1
--   B2 ordre : Apply appelé avant que RayonService montre le nouveau rayon ; contours RayonSpot de Stage_2
--      cachés (rayon montré) ou visibles (rayon pas encore là) dès le premier passage
--   B3 niveau 1 → 3 → 5 : Stage_2 à Stage_k copiés une seule fois, posés au pivot de la boutique ; aucun
--      script ; gabarit intact
--   B4 recoloration Accent (pièces et lumières), le reste garde sa couleur ; parcelle sans AccentColor :
--      couleur du gabarit et une ligne
--   B5 HideFromStage ≤ k caché avec ses descendants (Stage_1, PlotBarrier, copies), > k visible
--   B6 parcelle libérée : retour au niveau 1, copies retirées, valeurs d'origine rendues à l'identique
--   B7 rechargement du profil : niveau 5 d'un coup ; un 2e passage ne copie rien de plus
--   B8 panneau des présentoirs : StageUpgradePoint au niveau 1, StageUpgradePoint_2 au niveau 2 et plus
--   B9 propriétaire : murs Stage_2/Barriers traversables chez lui (PlotDoorController)

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
local DoorModule = moduleScript(Controllers, "PlotDoorController", "client/Controllers/PlotDoorController.luau")

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

-- Gabarit Assets/Plots/PLOT_Shop (L-096, wave27-studio.md), pivot loin de l'origine : Stage_1 à Stage_5.
local T = CFrame.new(1000, 0, 0)
local Plots = folder(Assets, "Plots")
local template = new("Model", "PLOT_Shop", Plots)
template.WorldPivot = T
local function stage(parent, n)
	local s = new("Model", "Stage_" .. n, parent)
	s.WorldPivot = T
	return s
end
local function accent(p)
	p.Color = GREY
	p:SetAttribute("Accent", true)
	return p
end
do
	stage(template, 1) -- déjà dans les boutiques : jamais copié
	local s2 = stage(template, 2)
	local floorExt = accent(part("PlotFloorExt", s2, T * CFrame.new(0, 0, 12), Vector3.new(64, 1, 56)))
	local lamp = new("PointLight", "Lamp", floorExt)
	lamp.Color = GREY
	lamp:SetAttribute("Accent", true)
	local plain = part("Stock", s2, T * CFrame.new(10, 2, 20))
	plain.Color = GREY
	local field = new("Model", "ForceField", s2)
	field:SetAttribute("HideFromStage", 3)
	part("Field_L", field, T * CFrame.new(-30, 4, 0))
	new("ParticleEmitter", "Sparks", part("Field_R", field, T * CFrame.new(30, 4, 0)))
	local barriers = new("Model", "Barriers", s2)
	local wall = part("Barrier_L", barriers, T * CFrame.new(-32, 15, 0), Vector3.new(1, 30, 80))
	wall.Transparency = 1
	local spots = new("Model", "RayonSpots", s2)
	for k = 2, 5 do
		part(string.format("RayonSpot_%02d", k), spots, T * CFrame.new(0, 0.1, -18 + 8 * k))
	end
	new("Script", "Junk", s2)
	new("LocalScript", "JunkLocal", floorExt)
	local s3 = stage(template, 3)
	accent(part("Walls", s3, T * CFrame.new(0, 10, 39)))
	local pil = new("Model", "Pilasters", s3)
	pil:SetAttribute("HideFromStage", 5)
	part("Pilaster_01", pil, T * CFrame.new(-20, 5, 39))
	local s4 = stage(template, 4)
	local neon = accent(part("SignNeon", s4, T * CFrame.new(0, 20, -40)))
	neon:SetAttribute("HideFromStage", 5)
	new("SurfaceGui", "NeonGui", neon)
	local s5 = stage(template, 5)
	part("Cam_Door_01", new("Model", "Cameras", s5), T * CFrame.new(5, 12, -40))
end

-- Boutique du hub : Stage_1 seul, PlotBarrier, PlotFloor (points du panneau), 5 rayons de 4 présentoirs.
local function buildPlot(name, pivot, accentColor)
	local plot = new("Model", name, nil)
	plot.WorldPivot = pivot
	local floor = part("PlotFloor", plot, pivot * CFrame.new(0, 0, -28), Vector3.new(64, 1, 24))
	new("Attachment", "StageUpgradePoint", floor).CFrame = CFrame.new(0, 0.8, 9.4)
	new("Attachment", "StageUpgradePoint_2", floor).CFrame = CFrame.new(0, 0.8, 65.6)
	new("Attachment", "DisplayUpgradePoint", floor).CFrame = CFrame.new(-10, 0.8, -8)
	local s1 = stage(plot, 1)
	s1.WorldPivot = pivot
	local rails = new("Model", "Railings", s1)
	rails:SetAttribute("HideFromStage", 2)
	local rail = part("Rail_01", rails, pivot * CFrame.new(0, 1, -16))
	rail.CanQuery = false -- valeur de départ inhabituelle, à rendre telle quelle
	new("Decal", "RailDecal", rail)
	local mat = part("EntryMat", s1, pivot * CFrame.new(0, 0.1, -39))
	mat:SetAttribute("HideFromStage", 5)
	accent(part("Trim", s1, pivot * CFrame.new(0, 3, -40))).Color = accentColor or GREY
	local barrier = new("Model", "PlotBarrier", plot)
	local small = part("Barrier_L1", barrier, pivot * CFrame.new(-32, 15, -28))
	small.Transparency = 1
	small:SetAttribute("HideFromStage", 2)
	local front = part("Barrier_F", barrier, pivot * CFrame.new(20, 15, -40))
	front.Transparency = 1
	for k = 1, 5 do
		local rayon = new("Model", string.format("Rayon_%02d", k), plot)
		for i = 4 * k - 3, 4 * k do
			local top = part("Top", rayon, pivot * CFrame.new(i * 2, 2, -34 + k * 8))
			new("Attachment", string.format("DisplaySlot_%02d", i), top)
		end
	end
	if accentColor then
		plot:SetAttribute("AccentColor", accentColor)
	end
	plot.Parent = Workspace
	addTag(plot, "PlayerPlot")
	plot:SetAttribute("OwnerUserId", 0)
	return plot
end
local P1 = CFrame.new(50, 0, 30) * CFrame.Angles(0, math.pi / 2, 0)
local plot1 = buildPlot("PLOT_Shop_01", P1, BLUE)
local plot2 = buildPlot("PLOT_Shop_02", CFrame.new(-200, 0, 0), nil)

-- Valeurs surveillées (cacher / rendre).
local WATCHED = {
	BasePart = { "Transparency", "CanCollide", "CanTouch", "CanQuery", "Color" },
	Decal = { "Transparency" },
	SurfaceGui = { "Enabled" },
	PointLight = { "Enabled", "Color" },
	ParticleEmitter = { "Enabled" },
}
-- a127 : le dossier SkillVisuals (copies à part des visuels EveryStage, ex. Walls) est refait à chaque retour sous
-- le niveau de son Stage_j : il n'entre pas dans les comparaisons.
local function inSkillVisuals(d)
	local p = d.Parent
	while p do
		if p.Name == "SkillVisuals" then
			return true
		end
		p = p.Parent
	end
	return false
end
local function snapshot(root)
	local snap = {}
	for _, d in root:GetDescendants() do
		local list = if inSkillVisuals(d) then nil elseif d:IsA("BasePart") then WATCHED.BasePart else WATCHED[d.ClassName]
		if list then
			local props = {}
			for _, p in list do
				props[p] = d[p]
			end
			snap[d] = props
		end
	end
	return snap
end
local function sameAs(snap, root)
	local count = 0
	for inst, props in snap do
		if not inst:IsDescendantOf(root) then
			print(`    {inst.Name} n'est plus dans {root.Name}`)
			return false
		end
		for k, v in props do
			if inst[k] ~= v then
				print(`    diff {inst:GetFullName()}.{k} : {tostring(inst[k])} au lieu de {tostring(v)}`)
				return false
			end
		end
		count += 1
	end
	local now = 0
	for _, d in root:GetDescendants() do
		if not inSkillVisuals(d) and (d:IsA("BasePart") or WATCHED[d.ClassName]) then
			now += 1
		end
	end
	return count > 0 and now == count
end
local function isHidden(inst)
	local all = inst:GetDescendants()
	table.insert(all, inst)
	for _, d in all do
		if d:IsA("BasePart") and (d.Transparency ~= 1 or d.CanCollide or d.CanTouch or d.CanQuery) then
			return false
		elseif d:IsA("Decal") and d.Transparency ~= 1 then
			return false
		elseif (d.ClassName == "SurfaceGui" or d.ClassName == "ParticleEmitter" or d.ClassName == "PointLight") and d.Enabled then
			return false
		end
	end
	return true
end
local function stages(plot)
	local out = {}
	for _, c in plot:GetChildren() do
		local n = string.match(c.Name, "^Stage_(%d+)$")
		if n then
			out[tonumber(n)] = (out[tonumber(n)] or 0) + 1
		end
	end
	return out
end
local function stageList(plot)
	local s, list = stages(plot), {}
	for n = 1, 6 do
		if s[n] then
			table.insert(list, if s[n] == 1 then tostring(n) else `{n}×{s[n]}`)
		end
	end
	return table.concat(list, ",")
end
local function find(plot, path)
	local cur = plot
	for _, name in string.split(path, ".") do
		cur = cur and cur:FindFirstChild(name)
	end
	return cur
end

local templateInitial = snapshot(template)

local PlotService = requireModule(PlotModule, "server")
PlotService.Plots = { plot1, plot2 }
local Stage = requireModule(StageModule, "server")
local Rayon = requireModule(RayonModule, "server")
-- B2 : chaque appel note si RayonService montrait déjà le rayon k (il ne doit pas encore).
local CALLS = {}
local realApply = Stage.Apply
Stage.Apply = function(plot, k)
	table.insert(CALLS, { plot = plot, k = k, shownBefore = Rayon.IsShown(plot, k) })
	return realApply(plot, k)
end
local railBefore = snapshot(find(plot1, "Stage_1.Railings"))
taskLib.spawn(Rayon.Start)
advance(0)
-- État de référence : parcelles libres, après le premier passage (rayons 2 à 5 cachés par RayonService).
local initial1 = snapshot(plot1)
local initial2 = snapshot(plot2)

local function players(name, id)
	local p = new("Player", name, Players)
	rawget(p, "_props").UserId = id
	new("PlayerGui", "PlayerGui", p)
	return p
end
local alice = players("Alice", 101)
local bob = players("Bob", 102)
local function setLevel(p, level)
	FAKE_DATA[p] = { Upgrades = { DisplaySlots = level, Treadmill = 0, Bench = 0 } }
	p:SetAttribute("TreadmillLevel", 0)
	p:SetAttribute("BenchLevel", 0)
	p:SetAttribute("DisplaySlotsLevel", level)
	advance(0)
end

---------------------------------------------------------------- B1
print("\nB1 démarrage, parcelles libres")
check(stageList(plot1) == "1" and stageList(plot2) == "1", `Stage_1 seul ({stageList(plot1)} ; {stageList(plot2)})`)
check(plot1:GetAttribute("StageLevel") == 1 and Stage.GetLevel(plot1) == 1, "StageLevel = 1, GetLevel = 1")
check(sameAs(railBefore, find(plot1, "Stage_1.Railings")) and not isHidden(find(plot1, "PlotBarrier.Barrier_L1")) and not isHidden(find(plot2, "Stage_1.EntryMat")), "niveau 1 : rien de caché (HideFromStage ≥ 2 partout)")
check(#CALLS >= 2 and CALLS[1].k == 1, "Apply appelé par RayonService au démarrage, niveau 1")

---------------------------------------------------------------- B3, B4, B5 : 1 → 3
print("\nB3 niveau 1 → 3 → 5 (Alice)")
setLevel(alice, 0)
PlotService.Assign(alice, plot1)
advance(0)
check(stageList(plot1) == "1" and plot1:GetAttribute("StageLevel") == 1, `4 présentoirs : niveau 1 ({stageList(plot1)})`)
table.clear(CALLS)
setLevel(alice, 8) -- 12 présentoirs : 3 rayons
check(stageList(plot1) == "1,2,3" and plot1:GetAttribute("StageLevel") == 3, `12 présentoirs : Stage_1 à 3 ({stageList(plot1)}, StageLevel {plot1:GetAttribute("StageLevel")})`)
do
	local ext = find(plot1, "Stage_2.PlotFloorExt")
	local expected = P1 * CFrame.new(0, 0, 12)
	check(ext and close(ext.Position, expected.Position) and close(ext.CFrame.LookVector, expected.LookVector), "copie posée au pivot de la boutique (pivot × gabarit⁻¹ × pièce)")
	check(close(find(plot1, "Stage_3.Walls").Position, (P1 * CFrame.new(0, 10, 39)).Position), "Stage_3 aussi")
	check(find(plot1, "Stage_2"):GetPivot() and close(find(plot1, "Stage_2"):GetPivot().Position, P1.Position), "pivot de la copie = pivot de la boutique")
	local scripts = 0
	for _, d in plot1:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			scripts += 1
		end
	end
	check(scripts == 0, `aucun script dans les copies ({scripts})`)
	check(template:FindFirstChild("Junk", true) and template:FindFirstChild("JunkLocal", true) and sameAs(templateInitial, template), "gabarit intact (scripts, couleurs, visibilité, rien déplacé)")
	check(find(template, "Stage_2.PlotFloorExt").Position == (T * CFrame.new(0, 0, 12)).Position, "gabarit pas déplacé")

	print("\nB4 recoloration Accent")
	check(ext.Color == BLUE and find(plot1, "Stage_3.Walls").Color == BLUE, "pièces Accent copiées : AccentColor de la boutique")
	check(find(plot1, "Stage_2.PlotFloorExt.Lamp").Color == BLUE, "lumière Accent : AccentColor")
	check(find(plot1, "Stage_2.Stock").Color == GREY, "pièce sans Accent : couleur du gabarit")
	check(find(plot1, "Stage_1.Trim").Color == BLUE, "Stage_1 (déjà dans la boutique) pas touché")

	print("\nB5 HideFromStage")
	check(isHidden(find(plot1, "Stage_1.Railings")), "Stage_1/Railings (2) caché avec ses descendants (pièce et Decal)")
	check(isHidden(find(plot1, "PlotBarrier.Barrier_L1")), "PlotBarrier/Barrier_L1 (2) caché")
	check(not isHidden(find(plot1, "PlotBarrier.Barrier_F")) and find(plot1, "PlotBarrier.Barrier_F").CanCollide, "Barrier_F (sans attribut) intact")
	check(isHidden(find(plot1, "Stage_2.ForceField")), "Stage_2/ForceField (3) caché au niveau 3, particules comprises")
	check(not isHidden(find(plot1, "Stage_1.EntryMat")) and not isHidden(find(plot1, "Stage_3.Pilasters")), "EntryMat et Pilasters (5) visibles au niveau 3")
	check(find(plot1, "Stage_2.Barriers.Barrier_L").CanCollide, "grands murs Stage_2/Barriers solides (pour les autres)")
end

print("\nB2 ordre avant RayonService")
do
	local last = CALLS[#CALLS]
	check(last and last.plot == plot1 and last.k == 3 and last.shownBefore == false, `Apply(niveau 3) appelé avant que Rayon_03 soit montré ({last and tostring(last.shownBefore)})`)
	check(Rayon.IsShown(plot1, 3) == true and Rayon.IsShown(plot1, 4) == false, "puis Rayon_03 montré, Rayon_04 caché")
	check(isHidden(find(plot1, "Stage_2.RayonSpots.RayonSpot_02")) and isHidden(find(plot1, "Stage_2.RayonSpots.RayonSpot_03")), "contours des rayons 2 et 3 (arrivés avec Stage_2) cachés dès ce passage")
	check(not isHidden(find(plot1, "Stage_2.RayonSpots.RayonSpot_04")), "contour du rayon 4 visible")
end

print("\nB3 suite : niveau 5")
setLevel(alice, 16) -- 20 présentoirs
check(stageList(plot1) == "1,2,3,4,5" and plot1:GetAttribute("StageLevel") == 5, `20 présentoirs : Stage_1 à 5 une fois chacun ({stageList(plot1)})`)
check(isHidden(find(plot1, "Stage_1.EntryMat")) and isHidden(find(plot1, "Stage_3.Pilasters")) and isHidden(find(plot1, "Stage_4.SignNeon")), "niveau 5 : EntryMat, Pilasters, SignNeon (5) cachés, SurfaceGui compris")
check(find(plot1, "Stage_4.SignNeon").Color == BLUE and find(plot1, "Stage_5.Cameras.Cam_Door_01") ~= nil, "Stage_4 recoloré, Stage_5 posé")
Rayon.Refresh(plot1)
Rayon.Refresh(plot1)
check(stageList(plot1) == "1,2,3,4,5", "deux Refresh de plus : aucune copie en double")
check(Stage.Apply(plot1, 0 / 0) == 1, "niveau NaN : ramené à 1")
Rayon.Refresh(plot1)
check(stageList(plot1) == "1,2,3,4,5" and plot1:GetAttribute("StageLevel") == 5, "Refresh suivant : niveau 5 rétabli")

---------------------------------------------------------------- B8 panneau (client)
print("\nB8 panneau des présentoirs")
local Find = requireModule(Shared:FindFirstChild("Contract"):FindFirstChild("Find"), "client")
rawget(Players, "_props").LocalPlayer = alice
CLIENT_PLAYER = alice
local Upgrade = requireModule(UpgradeModule, "client")
local function signs()
	local f = Workspace:FindFirstChild("UpgradeSigns")
	return if f then f:GetChildren() else {}
end
local function signAt(point)
	local at = point.WorldCFrame.Position
	for _, sign in signs() do
		local box, size = sign:GetBoundingBox()
		if close(box.Position - Vector3.new(0, size.Y / 2, 0), at) then
			return sign
		end
	end
	return nil
end
local stage1Point = find(plot1, "PlotFloor.StageUpgradePoint")
local stage2Point = find(plot1, "PlotFloor.StageUpgradePoint_2")
local displayPoint = find(plot1, "PlotFloor.DisplayUpgradePoint")
setLevel(alice, 2) -- 6 présentoirs : 2 rayons
taskLib.spawn(Upgrade.Start)
advance(0.1)
check(plot1:GetAttribute("StageLevel") == 2 and signAt(stage2Point) ~= nil and signAt(stage1Point) == nil and signAt(displayPoint) == nil, "niveau 2 : panneau sur StageUpgradePoint_2")
setLevel(alice, 0)
advance(0.1)
check(plot1:GetAttribute("StageLevel") == 1 and signAt(stage1Point) ~= nil and signAt(stage2Point) == nil, "niveau 1 : panneau sur StageUpgradePoint")
check(#signs() == 1, `un seul panneau (présentoirs ; pas de tapis ni de banc ici) : {#signs()}`)
setLevel(alice, 1) -- 5 présentoirs : Rayon_02 apparaît, niveau 2
advance(0.1)
check(signAt(stage2Point) ~= nil and signAt(stage1Point) == nil, "5 présentoirs : niveau 2, panneau déplacé sur StageUpgradePoint_2")
setLevel(alice, 12) -- 16 présentoirs : 4 rayons
advance(0.1)
check(signAt(stage2Point) ~= nil and signAt(stage1Point) == nil, "niveau 4 : panneau sur StageUpgradePoint_2")
setLevel(alice, 16)
advance(0.1)
check(signAt(stage2Point) ~= nil, "niveau 5, présentoirs au max : panneau « Max level » resté sur StageUpgradePoint_2 (question à Clément)")

---------------------------------------------------------------- B6 libérée
print("\nB6 parcelle libérée")
PlotService.Release(alice)
advance(0.1)
check(stageList(plot1) == "1" and plot1:GetAttribute("StageLevel") == 1, `retour au niveau 1 ({stageList(plot1)})`)
check(sameAs(initial1, plot1), "valeurs d'origine rendues à l'identique (Railings, EntryMat, Barrier_L1, CanQuery coupé de départ)")
check(Rayon.IsShown(plot1, 1) == true and Rayon.IsShown(plot1, 2) == false, "Rayon_01 seul")
check(#signs() == 0, "plus de panneau sur la parcelle libre")
check(sameAs(templateInitial, template), "gabarit toujours intact")

---------------------------------------------------------------- B4 sans AccentColor
print("\nB4 parcelle sans AccentColor (Bob)")
-- a127 : la copie à part de Stage_3/Walls (niveau 1) a déjà écrit cette ligne au premier passage (une par boutique).
local accentWarnedEarly = logHas("PLOT_Shop_02 : pas d'attribut AccentColor", "WARN")
clearLog()
setLevel(bob, 4)
PlotService.Assign(bob, plot2)
advance(0.1)
check(stageList(plot2) == "1,2" and find(plot2, "Stage_2.PlotFloorExt").Color == GREY, "Stage_2 copié, couleur du gabarit gardée")
check(accentWarnedEarly or logHas("AccentColor", "WARN"), "une ligne dans la sortie (pas d'AccentColor)")
check(stageList(plot1) == "1", "l'autre parcelle pas touchée")
PlotService.Release(bob)
advance(0.1)
check(sameAs(initial2, plot2), "Bob parti : parcelle 2 comme au départ")

---------------------------------------------------------------- B7 rechargement
print("\nB7 rechargement du profil")
setLevel(alice, 16)
PlotService.Assign(alice, plot1)
advance(0.1)
check(stageList(plot1) == "1,2,3,4,5" and plot1:GetAttribute("StageLevel") == 5, `retour d'Alice à 20 présentoirs : niveau 5 d'un coup ({stageList(plot1)})`)
check(isHidden(find(plot1, "Stage_1.Railings")) and isHidden(find(plot1, "Stage_2.ForceField")) and isHidden(find(plot1, "Stage_1.EntryMat")), "tout ce qui a HideFromStage ≤ 5 caché")
check(find(plot1, "Stage_5.Cameras.Cam_Door_01") and close(find(plot1, "Stage_5.Cameras.Cam_Door_01").Position, (P1 * CFrame.new(5, 12, -40)).Position), "Stage_5 posé au bon endroit")
advance(1.5) -- contrôle d'une seconde : rien ne bouge
check(stageList(plot1) == "1,2,3,4,5", "contrôle de sécurité : pas de copie en double")
check(signAt(stage2Point) ~= nil, "panneau revenu sur StageUpgradePoint_2")

---------------------------------------------------------------- B9 murs du propriétaire
print("\nB9 murs Stage_2/Barriers (PlotDoorController)")
local Door = requireModule(DoorModule, "client")
taskLib.spawn(Door.Start)
advance(0.1)
check(find(plot1, "Stage_2.Barriers.Barrier_L").CanCollide == false, "chez Alice : grand mur Stage_2/Barriers traversable")
check(find(plot1, "PlotBarrier.Barrier_F").CanCollide == false, "PlotBarrier toujours traversable")
setLevel(alice, 2)
advance(0.1)
check(stageList(plot1) == "1,2", `redescendu au niveau 2 : Stage_3 à 5 retirés ({stageList(plot1)})`)
setLevel(alice, 16)
advance(0.1)
check(find(plot1, "Stage_2.Barriers.Barrier_L").CanCollide == false, "Stage_2 gardé : toujours traversable")

summary()
