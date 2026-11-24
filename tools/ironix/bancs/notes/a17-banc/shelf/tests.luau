--!nocheck
-- Banc a17 : ShelfBoxController (client, L-031). Faux Roblox du banc carry (a11), complété ici :
-- Heartbeat image par image, DescendantAdded, Attachment.WorldPosition, caméra, Raycast contre des
-- boîtes orientées (Exclude, CanQuery, AddToFilter ; un rayon ne touche pas une pièce qui contient
-- son origine, comme Roblox).

---------------------------------------------------------------- compléments du faux Roblox
CLASS_EVENTS.DescendantAdded = true
local baseNewIndex = InstanceMT.__newindex
InstanceMT.__newindex = function(self, key, value)
	baseNewIndex(self, key, value)
	if key == "Parent" and value ~= nil then
		local list = subtree(self)
		local ancestor = value
		while ancestor do
			local signal = rawget(ancestor, "_signals").DescendantAdded
			if signal then
				for _, inst in list do
					signal:Fire(inst)
				end
			end
			ancestor = rawget(ancestor, "_parent")
		end
	end
end
local baseIndex = InstanceMT.__index
InstanceMT.__index = function(self, key)
	if key == "WorldPosition" and rawget(self, "_class") == "Attachment" then
		return self.WorldCFrame.Position
	end
	return baseIndex(self, key)
end

HEARTBEAT = newSignal()
games.client:GetService("RunService").Heartbeat = HEARTBEAT
local FRAME = 1 / 60
local frameIndex = 0
local function frames(n)
	for _ = 1, n do
		advance(FRAME)
		frameIndex += 1
		HEARTBEAT:Fire(FRAME)
	end
end

RaycastParams = {
	new = function()
		local params = { FilterDescendantsInstances = {}, IgnoreWater = false }
		function params.AddToFilter(self, instance)
			table.insert(self.FilterDescendantsInstances, instance)
		end
		return params
	end,
}

-- Entrée (0 à 1 le long du segment) dans la boîte (cf, size), ou nil ; nil aussi si l'origine est dedans.
local function rayBox(origin, direction, cf, size)
	local o = cf:PointToObjectSpace(origin)
	local e = cf:PointToObjectSpace(origin + direction)
	local d = e - o
	local tmin, tmax = 0, 1
	local inside = true
	for _, axis in { "X", "Y", "Z" } do
		local h = size[axis] / 2
		local oa, da = o[axis], d[axis]
		if oa < -h or oa > h then
			inside = false
		end
		if math.abs(da) < 1e-12 then
			if oa < -h or oa > h then
				return nil
			end
		else
			local t1, t2 = (-h - oa) / da, (h - oa) / da
			if t1 > t2 then
				t1, t2 = t2, t1
			end
			tmin = math.max(tmin, t1)
			tmax = math.min(tmax, t2)
			if tmin > tmax then
				return nil
			end
		end
	end
	if inside then
		return nil
	end
	return tmin
end
RAYS = {} -- { frame, origin, target }
function Methods.Raycast(self, origin, direction, params)
	table.insert(RAYS, { frame = frameIndex, origin = origin, target = origin + direction })
	local excluded = if params then params.FilterDescendantsInstances else {}
	local best, bestT = nil, nil
	for _, part in Methods.GetDescendants(self) do
		if isA(part, "BasePart") and part.CanQuery ~= false then
			local skip = false
			for _, ex in excluded do
				if part == ex or Methods.IsDescendantOf(part, ex) then
					skip = true
					break
				end
			end
			if not skip then
				local t = rayBox(origin, direction, part.CFrame, part.Size)
				if t and (bestT == nil or t < bestT) then
					best, bestT = part, t
				end
			end
		end
	end
	if best == nil then
		return nil
	end
	return { Instance = best, Position = origin + direction * bestT, Distance = direction.Magnitude * bestT }
end

---------------------------------------------------------------- arbre du jeu
local shared = make("Folder", { Name = "Shared" }, ReplicatedStorage)
for key in SOURCES do
	local rel = string.match(key, "^shared/(.+)%.luau$")
	if rel then
		local parent = shared
		local segments = string.split(rel, "/")
		for i = 1, #segments - 1 do
			parent = parent:FindFirstChild(segments[i]) or make("Folder", { Name = segments[i] }, parent)
		end
		moduleScript(parent, segments[#segments], key)
	end
end
local sps = make("StarterPlayerScripts", { Name = "StarterPlayerScripts" }, StarterPlayer)
local clientFolder = make("Folder", { Name = "Client" }, sps)
local controllers = make("Folder", { Name = "Controllers" }, clientFolder)
local controllerModule = moduleScript(controllers, "ShelfBoxController", "client/Controllers/ShelfBoxController.luau")
local ShelfBoxes = requireModule(shared.Config.ShelfBoxes, "client")

local player = make("Player", { Name = "Alice", UserId = 1 }, Players)
local character = make("Model", { Name = "Alice" })
make("Humanoid", { Name = "Humanoid" }, character)
make("Part", { Name = "HumanoidRootPart", Size = Vector3.new(2, 2, 1), CFrame = CFrame.new(0, 3, -6) }, character)
character.Parent = Workspace
player.Character = character
Players.LocalPlayer = player

local camera = make("Camera", { Name = "Camera", CFrame = CFrame.new(0, 5, 0) })
Workspace.CurrentCamera = camera
local CS = games.client:GetService("CollectionService")

-- Colis du rayon façon StoreHeistService : pièce sans requête, LabelPoint au sommet, BB_Box de
-- Clément (MaxDistance 32), Highlight OutlineHighlight, tag ShelfBox.
local boxes = {}
local function shelfBox(name, position, parent)
	local model = make("Model", { Name = name })
	local body = make("Part", { Name = "Body", Size = Vector3.new(1.6, 1.2, 1.6), CFrame = CFrame.new(position), CanQuery = false, Anchored = true }, model)
	model.PrimaryPart = body
	local point = make("Attachment", { Name = "LabelPoint", CFrame = CFrame.new(0, 0.95, 0) }, body)
	make("BillboardGui", { Name = "BB_Box", MaxDistance = 32, AlwaysOnTop = true, Enabled = true, Adornee = point }, point)
	make("Highlight", { Name = "OutlineHighlight", Enabled = true }, model)
	model.Parent = parent or Workspace
	CS:AddTag(model, "ShelfBox")
	return model
end
local function labelOf(model)
	return model:FindFirstChild("BB_Box", true)
end
local function outlineOf(model)
	return model:FindFirstChild("OutlineHighlight", true)
end
-- 40 colis alignés : n à x = 3n, z = 10 ; étiquette à (3n, 5.35, 10), caméra en (0, 5, 0).
for n = 1, 40 do
	boxes[n] = shelfBox(string.format("ShelfBox_%02d", n), Vector3.new(3 * n, 4.4, 10))
end
-- Obstacles (pièces de requête) entre la caméra et certaines étiquettes.
make("Part", { Name = "Wall", Size = Vector3.new(1.5, 4, 0.5), CFrame = CFrame.new(1.5, 5, 5), Transparency = 0 }, Workspace) -- cache 01
make("Part", { Name = "Glass", Size = Vector3.new(1, 2, 0.3), CFrame = CFrame.new(3, 5, 5), Transparency = 0.6 }, Workspace) -- devant 02
local guard = make("Model", { Name = "Guard" })
make("Humanoid", { Name = "Humanoid" }, guard)
make("Part", { Name = "Torso", Size = Vector3.new(1, 2, 1), CFrame = CFrame.new(4.5, 5, 5) }, guard) -- devant 03
guard.Parent = Workspace
make("Part", { Name = "ShelfEdge", Size = Vector3.new(1, 0.2, 0.2), CFrame = CFrame.new(12, 5.35, 9.7), Transparency = 0 }, Workspace) -- bord du casier de 04 (0,3 stud)
make("Part", { Name = "Shelf", Size = Vector3.new(0.6, 0.6, 0.6), CFrame = CFrame.new(13.5, 5.32, 9), Transparency = 0 }, Workspace) -- cache 05, à 2 studs
-- Autres Highlight : le contour rouge d'un objet volé n'est jamais touché.
local stolen = make("Model", { Name = "CarryVisual" })
make("Part", { Name = "Root", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(0, 8, 2), CanQuery = false }, stolen)
local stolenOutline = make("Highlight", { Name = "StolenOutline", Enabled = true }, stolen)
stolen.Parent = Workspace

---------------------------------------------------------------- démarrage
print("--- 1. Démarrage")
local Controller = requireModule(controllerModule, "client")
clearLog()
Controller.Start()
check(logCount("PRINT", "[ShelfBoxController] 40 contour(s) suivi(s), 25 au plus actifs ; 40 étiquette(s) de rayon") == 1, "sortie Studio au démarrage")
local allOff = true
for _, model in boxes do
	if labelOf(model).Enabled or outlineOf(model).Enabled then
		allOff = false
	end
end
check(allOff, "étiquettes et contours coupés à leur découverte, avant le premier contrôle")
frames(60)

print("--- 2. Contours : les 25 plus proches")
local outlinesOk = true
for n, model in boxes do
	if outlineOf(model).Enabled ~= (n <= 25) then
		outlinesOk = false
		print(`  contour {n} : {outlineOf(model).Enabled}`)
	end
end
check(outlinesOk, "contours actifs : les 25 colis les plus proches, les 15 autres coupés")
check(stolenOutline.Enabled == true, "StolenOutline (objet volé) jamais touché")

print("--- 3. Étiquettes : en vue seulement")
local expected = {
	[1] = false, -- mur opaque
	[2] = true, -- vitre transparente
	[3] = true, -- un personnage (vigile) ne cache rien
	[4] = true, -- obstacle à moins de 0,75 stud (bord de son casier)
	[5] = false, -- obstacle opaque à 2 studs
	[6] = true,
	[10] = true, -- 31,6 studs : à portée de BB_Box (32)
	[11] = false, -- 34,5 studs : hors de portée
	[25] = false,
	[40] = false,
}
for n, want in expected do
	check(labelOf(boxes[n]).Enabled == want, `étiquette {n} : {if want then "active" else "coupée"}`)
end
local stats = Controller.GetStats()
check(stats.Outlines == 40 and stats.ActiveOutlines == 25, "GetStats : 40 contours suivis, 25 actifs")
check(stats.Labels == 40 and stats.NearLabels == 10 and stats.VisibleLabels == 8, `GetStats : 40 étiquettes, 10 à portée, 8 visibles (01 et 05 cachées) ({stats.NearLabels}, {stats.VisibleLabels})`)

print("--- 4. Rayons : budget par image et fréquence par colis")
table.clear(RAYS)
frames(60)
local camPos = camera.CFrame.Position
local perFrame, perTarget = {}, {}
for _, ray in RAYS do
	if (ray.origin - camPos).Magnitude < 1e-9 then -- premier rayon d'un contrôle
		perFrame[ray.frame] = (perFrame[ray.frame] or 0) + 1
		local key = tostring(ray.target)
		perTarget[key] = (perTarget[key] or 0) + 1
	end
end
local maxFrame, maxTarget, targets = 0, 0, 0
for _, count in perFrame do
	maxFrame = math.max(maxFrame, count)
end
for _, count in perTarget do
	maxTarget = math.max(maxTarget, count)
	targets += 1
end
check(maxFrame <= ShelfBoxes.LabelChecksPerFrame, `au plus {ShelfBoxes.LabelChecksPerFrame} contrôles par image ({maxFrame})`)
check(maxTarget <= 6, `un même colis revu au plus ~5 fois par seconde ({maxTarget})`)
check(targets == 10, `seules les 10 étiquettes à portée sont visées ({targets})`)

print("--- 5. Streaming : un colis arrive, un autre part")
local newcomer = shelfBox("ShelfBox_41", Vector3.new(4, 4.4, -10))
check(labelOf(newcomer).Enabled == false and outlineOf(newcomer).Enabled == false, "nouveau colis : coupé à son arrivée")
frames(30)
check(labelOf(newcomer).Enabled == true and outlineOf(newcomer).Enabled == true, "nouveau colis proche : étiquette et contour actifs")
local active = 0
for _, model in boxes do
	if outlineOf(model).Enabled then
		active += 1
	end
end
check(active == 24 and outlineOf(boxes[25]).Enabled == false, "toujours 25 contours : le 25e plus loin coupé")
clearLog()
boxes[6]:Destroy()
frames(30)
check(Controller.GetStats().Labels == 40 and logCount("WARN", "") == 0, "colis détruit : oublié, sans erreur")

print("--- 6. Caméra loin de tout")
camera.CFrame = CFrame.new(5000, 5, 0)
frames(30)
local anyOn = false
for n, model in boxes do
	if n ~= 6 and (labelOf(model).Enabled or outlineOf(model).Enabled) then
		anyOn = true
	end
end
check(not anyOn and not labelOf(newcomer).Enabled and not outlineOf(newcomer).Enabled, "plus d'étiquette ni de contour (au-delà de 32 et de 100 studs)")
camera.CFrame = CFrame.new(3 * 30, 5, 0) -- au milieu de la file
frames(30)
active = 0
for n, model in boxes do
	if n ~= 6 and outlineOf(model).Enabled then
		active += 1
	end
end
check(active == 25, "au milieu : 25 contours de nouveau")
check(labelOf(boxes[30]).Enabled == true and labelOf(boxes[1]).Enabled == false, "étiquettes revues avec la caméra")

print("--- 7. Erreurs")
check(logCount("WARN", "") == 0, "aucun avertissement")

---------------------------------------------------------------- bilan
print(string.format("%d vérification(s), %d échec(s)", CHECKS, FAILS))
if FAILS > 0 then
	print("Sortie des modules :")
	dumpLog()
end
