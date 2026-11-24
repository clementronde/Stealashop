--!nocheck
-- Banc a128 (vague 39, 2026-11-14), scénario « idle » : ItemIdleController (correction 1 de perf-telephone.md).
-- Faux Roblox : celui de la copie a128 d'a22-core (faux Camera avec FieldOfView 70 et ViewportSize 1280 × 720,
-- Workspace:BulkMoveTo compté dans BULK_MOVES). Vérifie : un BulkMoveTo par objet animé et par image, rien
-- hors de l'écran (dernière pose gardée, pas de retour au repos), bord de l'écran gardé grâce au rayon,
-- cadence FarInterval au-delà de NearDistance (pose toujours exacte), de près chaque image comme avant,
-- retour au repos au-delà de MaxDistance comme avant.

local TAU = 2 * math.pi

local Shared = folder(ReplicatedStorage, "Shared")
local ConfigF = folder(Shared, "Config")
for _, n in { "Balance", "Bat", "Cosmetics", "DeepFreeze", "Features", "Formulas", "ItemIdle", "Items", "Night", "PvP", "Rarities", "Shatter", "ShelfBoxes", "Tools", "Training", "Tutorial", "Upgrades", "Zones" } do
	moduleScript(ConfigF, n, `shared/Config/{n}.luau`)
end
local ContractF = folder(Shared, "Contract")
for _, n in { "Animations", "Attributes", "Find", "Icons", "Models", "Tags", "UI" } do
	moduleScript(ContractF, n, `shared/Contract/{n}.luau`)
end
local Controllers = folder(folder(StarterPlayerScripts, "Client"), "Controllers")
local IdleModule = moduleScript(Controllers, "ItemIdleController", "client/Controllers/ItemIdleController.luau")
local ItemIdle = requireModule(ConfigF.ItemIdle, "server")

print("== I0. Réglages (Config/ItemIdle, V0 de la vague 39)")
check(ItemIdle.NearDistance == 30 and ItemIdle.FarInterval > 0 and ItemIdle.FarInterval < 0.2, `NearDistance 30, FarInterval ({ItemIdle.FarInterval} s)`)
check(ItemIdle.OnScreenOnly == true and type(ItemIdle.ScreenMargin) == "number", "OnScreenOnly et ScreenMargin")
check(ItemIdle.NearDistance < ItemIdle.MaxDistance, "NearDistance < MaxDistance")

local FPS = 60
local DT = 1 / FPS
local camera = new("Camera", { CFrame = CFrame.new(0, 5, 0) }, Workspace) -- regarde vers −Z
Workspace.CurrentCamera = camera
local displayF = folder(folder(Workspace, "Plot_1"), "DisplayItems")
local function part(name, parent, position, size)
	return new("Part", { Name = name, Size = size or Vector3.new(1, 1, 1), CFrame = CFrame.new(position.X, position.Y, position.Z), Anchored = true }, parent)
end
-- Objet exposé tournant (Idle = Spin), pivot en bas au centre, une seule pièce Root.
local function spinner(name, x, z)
	local model = new("Model", { Name = name }, nil)
	local root = part("Root", model, Vector3.new(x, 0.25, z), Vector3.new(1, 0.5, 1))
	root.PivotOffset = CFrame.new(0, -0.25, 0)
	model.PrimaryPart = root
	model:SetAttribute("Idle", "Spin")
	model.Parent = displayF
	addTag(model, "DisplayItem")
	return model, root, (x * 0.37 + z * 0.61) % 10
end
local nearM, nearRoot, nearPhase = spinner("Near", 0, -10) -- 11 studs, devant
local farM, farRoot, farPhase = spinner("Far", 0, -50) -- 50 studs, devant
local backM, backRoot, backPhase = spinner("Behind", 0, 15) -- 16 studs, derrière la caméra
local sideM, sideRoot = spinner("Side", -40, -10) -- 41 studs, hors du champ à gauche
local edgeM, edgeRoot = spinner("Edge", -15, -10) -- centre hors du champ (12,4 studs au plus), sphère dedans
local rest = {}
for _, p in { nearRoot, farRoot, backRoot, sideRoot, edgeRoot } do
	rest[p] = p.CFrame
end

local function yawOf(cf)
	return math.atan2(cf.r[3], cf.r[1])
end
local function angleDiff(a, b)
	local diff = (a - b) % TAU
	if diff > math.pi then
		diff -= TAU
	end
	return math.abs(diff)
end
local Idle = requireModule(IdleModule, "client")
local clock = 0
local function frames(n)
	for _ = 1, n do
		step(DT, FPS)
		clock += DT
	end
end
local function poseOk(root, phase)
	local angle = Idle.ModelMotion("Spin", clock + phase)
	return angleDiff(yawOf(root.CFrame), angle) < 1e-6
end

Idle.Start()
frames(1)
print("== I1. À l'écran seulement")
local stats = Idle.GetStats()
check(stats.Tracked == 5 and stats.Animated == 3, `5 suivis ; animés : proche, lointain et bord d'écran ; pas celui de derrière ni celui hors du champ ({stats.Tracked}, {stats.Animated})`)
check(poseOk(nearRoot, nearPhase), "proche : pose exacte (ModelMotion depuis l'instant)")
check(backRoot.CFrame == rest[backRoot] and sideRoot.CFrame == rest[sideRoot], "derrière et hors du champ : jamais déplacés")
check(edgeRoot.CFrame ~= rest[edgeRoot], "bord de l'écran : animé (rayon + ScreenMargin)")

print("== I2. Un BulkMoveTo par objet animé, cadence réduite au loin")
local before = BULK_MOVES
local nearChanges, farChanges, farExact = 0, 0, true
local lastNear, lastFar = nearRoot.CFrame, farRoot.CFrame
local nearEvery = true
for _ = 1, FPS do
	frames(1)
	if nearRoot.CFrame ~= lastNear then
		nearChanges += 1
	else
		nearEvery = false
	end
	if farRoot.CFrame ~= lastFar then
		farChanges += 1
		farExact = farExact and poseOk(farRoot, farPhase)
	end
	lastNear, lastFar = nearRoot.CFrame, farRoot.CFrame
end
local moves = BULK_MOVES - before
local expectedFar = 1 / ItemIdle.FarInterval -- poses par seconde au loin
check(nearEvery and nearChanges == FPS and poseOk(nearRoot, nearPhase), `de près (≤ {ItemIdle.NearDistance} studs) : replacé à chaque image, pose exacte ({nearChanges}/{FPS})`)
check(math.abs(farChanges - expectedFar) <= 1, `au loin : {farChanges} poses en 1 s (≈ {expectedFar}, une toutes les FarInterval s)`)
check(farExact, "au loin : chaque pose reste exacte (calculée depuis l'instant, pas ralentie)")
check(moves == 2 * FPS + farChanges, `BulkMoveTo : un appel par objet animé et par pose ({moves} = 2 × {FPS} + {farChanges})`)

print("== I3. Hors de l'écran : dernière pose gardée, reprise à l'écran")
camera.CFrame = CFrame.new(0, 5, 0) * CFrame.Angles(0, math.pi, 0) -- regarde vers +Z : l'objet de derrière
frames(math.ceil(ItemIdle.DistanceCheckInterval * FPS) + 2)
check(Idle.GetStats().Animated >= 1 and poseOk(backRoot, backPhase), "caméra tournée : l'objet de derrière s'anime, pose exacte")
local nearFrozen = nearRoot.CFrame
frames(10)
check(nearRoot.CFrame == nearFrozen and nearRoot.CFrame ~= rest[nearRoot], "l'objet proche, maintenant dans le dos : ni animé ni remis au repos (dernière pose gardée)")
camera.CFrame = CFrame.new(0, 5, 0)
frames(math.ceil(ItemIdle.DistanceCheckInterval * FPS) + 2)
local backFrozen = backRoot.CFrame
frames(5)
check(poseOk(nearRoot, nearPhase) and backRoot.CFrame == backFrozen, "caméra revenue : le proche reprend là où l'instant le dit, celui de derrière s'arrête")

print("== I4. De près de nouveau : chaque image ; au-delà de MaxDistance : repos exact")
camera.CFrame = CFrame.new(0, 5, -40) -- l'objet « Far » à 10 studs
frames(math.ceil(ItemIdle.DistanceCheckInterval * FPS) + 2)
local every = true
for _ = 1, 8 do
	local last = farRoot.CFrame
	frames(1)
	every = every and farRoot.CFrame ~= last and poseOk(farRoot, farPhase)
end
check(every, "objet lointain devenu proche : replacé à chaque image")
camera.CFrame = CFrame.new(0, 5, 5000)
frames(math.ceil(ItemIdle.DistanceCheckInterval * FPS) + 2)
local allRest = true
for p, cf in rest do
	allRest = allRest and p.CFrame == cf
end
check(allRest and Idle.GetStats().Animated == 0, "caméra loin : toutes les pièces à leur CFrame de repos exact, rien d'animé")
before = BULK_MOVES
frames(30)
check(BULK_MOVES == before, "rien d'animé : aucun BulkMoveTo")

summary()
print(string.format("scénario idle : %d vérification(s), %d échec(s)", CHECKS, FAILS))
