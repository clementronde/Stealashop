---------------------------------------------------------------- a43 (L-080) : le rouleau au-dessus du colis
-- Scénarios :
--   A. Config/Unbox : durées et nombres du rouleau, valeurs V0 de la fenêtre ;
--   B. la fenêtre Reel suit le point au-dessus du colis à chaque image (et juste après la caméra),
--      jamais à sa place de Studio (le centre), position remise à la fermeture ;
--   C. couvercle et faisceau à l'ouverture : au marqueur Open, au repli de 0,45 s (sans animation),
--      au repli de 1,5 s (animation sans marqueur) ; faisceau nettoyé à l'éclat ;
--   D. un seul objet à la fois, en silhouette noire, du haut vers le bas ; 24 objets en 3,2 s et
--      10 en 1,3 s ; arrêt sur le gagnant ; couleurs puis éclat vers ItemPreview ;
--   E. colis hors du champ, au-dessus, en dessous, derrière la caméra : la fenêtre reste à l'écran,
--      au bord le plus proche ;
--   F. sans copie du colis : au-dessus de l'établi (Reel et Upgrade) ; sans rien : place de Studio ;
--   G. vrai UnboxController, vrai serveur : la fenêtre au-dessus de la copie locale, puis de
--      l'établi quand le colis du serveur a disparu.
-- Caméra simulée (PROJECT) : 30 px par stud, le point (cam.x, cam.y) du monde en (640, 600) de
-- l'écran ; derrière la caméra, x et y retournés par rapport au centre (comme chez Roblox).

local ScreenMod = requireModule(unboxFolder.Screen, "client")
local UnboxC = requireModule(Config.Unbox, "client")
local AREA = SCREEN_SIZE
local MARGIN = UnboxC.ReelEdge * math.min(AREA.X, AREA.Y)
local EPS = 0.01

local cam = { x = 4, y = 4, behind = false }
local function trueScreen(p)
	return 640 + 30 * (p.X - cam.x), 600 - 30 * (p.Y - cam.y)
end
PROJECT = function(p, viewport)
	local x, y = trueScreen(p)
	if viewport then
		y += 36
	end
	if cam.behind then
		return AREA.X - x, AREA.Y - y, -5
	end
	return x, y, 10
end
local function resetCam()
	cam.x, cam.y, cam.behind = 4, 4, false
	BEFORE_BINDS = nil
end

-- Fenêtre du rouleau à l'écran : Reel et ReelGlow réunis (coins haut gauche et bas droit).
local function windowRect(gui)
	local reel = el(gui, "Reel")
	local glow = el(gui, "ReelGlow")
	local a, b = reel.AbsolutePosition, reel.AbsolutePosition + reel.AbsoluteSize
	local c, d = glow.AbsolutePosition, glow.AbsolutePosition + glow.AbsoluteSize
	return Vector2.new(math.min(a.X, c.X), math.min(a.Y, c.Y)), Vector2.new(math.max(b.X, d.X), math.max(b.Y, d.Y))
end
-- Le bas de la fenêtre est-il centré sur le point (x, y) de l'écran ?
local function sitsOn(gui, x, y)
	local lo, hi = windowRect(gui)
	return math.abs((lo.X + hi.X) / 2 - x) < EPS and math.abs(hi.Y - y) < EPS
end
local function onScreen(gui)
	local lo, hi = windowRect(gui)
	return lo.X >= MARGIN - EPS and lo.Y >= MARGIN - EPS and hi.X <= AREA.X - MARGIN + EPS and hi.Y <= AREA.Y - MARGIN + EPS
end
local function reelCenter(gui)
	local reel = el(gui, "Reel")
	return reel.AbsolutePosition + reel.AbsoluteSize / 2
end

-- Colis local : socle, Tint, couvercle Lid soudé au socle (WeldConstraint), pied en `at`.
local function makeBox(at)
	local box = new("Model", { Name = "UnboxLocalBox" })
	local base = new("Part", { Name = "Base", Size = Vector3.new(2, 1, 2), CFrame = CFrame.new(at.X, at.Y + 0.5, at.Z), Anchored = true }, box)
	local tint = new("Part", { Name = "Tint", Size = Vector3.new(1.8, 0.9, 1.8), CFrame = CFrame.new(at.X, at.Y + 0.5, at.Z), Anchored = true }, box)
	local lid = new("Part", { Name = "Lid", Size = Vector3.new(2, 0.2, 2), CFrame = CFrame.new(at.X, at.Y + 1.1, at.Z), Anchored = true }, box)
	local lidWeld = new("WeldConstraint", { Name = "LidWeld", Part0 = base, Part1 = lid }, box)
	local tintWeld = new("WeldConstraint", { Name = "TintWeld", Part0 = base, Part1 = tint }, base)
	box.PrimaryPart = base
	box.Parent = Workspace
	return { model = box, base = base, lid = lid, lidWeld = lidWeld, tintWeld = tintWeld, top = Vector3.new(at.X, at.Y + 1.2, at.Z) }
end

local played = {}
local deliver = {}
local hooks = {
	PlayPlayer = function(name)
		table.insert(played, name)
		return deliver[name] == true
	end,
	CanOpenNext = function()
		return false
	end,
}
local me = InstanceAPI.new("Player")
me.Name = "Solo"
Players.LocalPlayer = me
local holder = folder(Workspace, "A43Guis")

local function effects()
	local out = {}
	for _, c in Workspace:GetChildren() do
		if c.Name == "UnboxEffect" then
			table.insert(out, c)
		end
	end
	return out
end

-- Une séquence pilotée à la main : vraie vue (Screen) et vrai déroulé (Sequence).
local function startRun(itemId, zone, tier, rarity, opts)
	opts = opts or {}
	local reveal = { SlotIndex = 1, ItemUid = "uid-a43", ItemId = itemId, Zone = zone, Tier = tier, StartRarity = rarity, Upgrades = opts.upgrades or 0 }
	local plan = assert(Sequence.plan(reveal, opts.rng or Random.new(opts.seed or 7)))
	local gui = buildUnbox(holder)
	local box = if opts.box == false then nil else makeBox(opts.at or Vector3.new(10, 3, 0))
	local studio = snapshot(gui)
	local view = ScreenMod.new(gui, plan, box and box.model, hooks, opts.anchor)
	local run = { plan = plan, gui = gui, box = box, view = view, studio = studio, frames = {} }
	local origFrame = ScreenMod.Frame
	view.Frame = function(self, info)
		table.insert(run.frames, { T = info.T, pos = info.ReelPos, drop = info.ReelDrop })
		origFrame(self, info)
	end
	run.runner = Sequence.new(plan, view)
	return run
end
-- Une image : le déroulé (RenderStepped), puis les liaisons BindToRenderStep (après la caméra).
local function frame(run, dt)
	dt = dt or 1 / 60
	advance(dt)
	run.runner:Update(dt)
	fireRenderBinds(dt)
end
local function runUntil(run, event, limit)
	local n = 0
	while not run.runner:IsFired(event) and n < (limit or 2000) do
		frame(run)
		n += 1
	end
	return run.runner:IsFired(event)
end
local function closeRun(run)
	run.view:Close()
	run.gui:Destroy()
end

print("\n== A. Config/Unbox : rouleau et fenêtre")
do
	check(UnboxC.ReelDuration.Full == 3.2 and UnboxC.ReelDuration.Short == 1.3, "A1 défilement de 3,2 s (courte : 1,3 s), spec")
	check(UnboxC.ReelCount.Full == 24 and UnboxC.ReelCount.Short == 10, "A2 24 objets (courte : 10), spec")
	check(UnboxC.OpenFallback == 0.45 and UnboxC.OpenMarkerTimeout == 1.5, "A3 replis de l'ouverture : 0,45 s sans animation, 1,5 s sans marqueur")
	check(type(UnboxC.ReelAbove) == "number" and UnboxC.ReelAbove >= 0 and UnboxC.ReelAbove <= 2, "A4 ReelAbove (V0) : écart de 0 à 2 studs au-dessus du colis")
	check(type(UnboxC.ReelEdge) == "number" and UnboxC.ReelEdge > 0 and UnboxC.ReelEdge < 0.2, "A5 ReelEdge (V0) : une petite marge au bord de l'écran")
end

print("\n== B. La fenêtre suit le point au-dessus du colis, à chaque image")
do
	resetCam()
	table.clear(RENDER_BIND_LOG)
	local run = startRun("Z3_Smartphone", 3, "Premium", "Rare")
	local gui = run.gui
	local studioPos = el(gui, "Reel").Position
	frame(run)
	local bind = RENDER_BIND_LOG[#RENDER_BIND_LOG]
	check(bind and bind.kind == "bind" and bind.side == "client" and string.find(bind.name, "UnboxFollow", 1, true) == 1 and bind.priority == 201, "B1 placement lié juste après la caméra (BindToRenderStep, Camera + 1)")
	check(el(gui, "Reel").Visible == false and el(gui, "Reel").Position == studioPos, "B2 avant l'ouverture : Reel caché, à sa place de Studio")
	check(runUntil(run, "Open"), "B3 ouverture (repli de 0,45 s, sans animation)")
	local x, y = trueScreen(run.box.top + Vector3.new(0, UnboxC.ReelAbove, 0))
	check(el(gui, "Reel").Visible and sitsOn(gui, x, y), `B4 dès l'ouverture : bas de la fenêtre (ReelGlow compris) centré en ({x}, {y}), {UnboxC.ReelAbove} stud au-dessus du colis`)
	local c = reelCenter(gui)
	check(math.abs(c.X - 640) > 100 and math.abs(c.Y - AREA.Y * 0.445) > 50, "B5 fenêtre loin du centre de l'écran (sa place de Studio)")
	local pos = el(gui, "Reel").Position
	check(pos.X.Scale == 0 and pos.Y.Scale == 0, "B6 Reel placé en pixels (WorldToScreenPoint, IgnoreGuiInset = false)")
	-- Le couvercle s'envole : la fenêtre ne monte pas avec lui (haut du colis pris à l'ouverture).
	local lidY0 = run.box.lid.Position.Y
	local steady = true
	for _ = 1, 27 do
		frame(run)
		steady = steady and sitsOn(gui, x, y)
	end
	check(run.box.lid.Position.Y > lidY0 + 2 and steady, "B7 couvercle 2 studs plus haut, la fenêtre n'a pas bougé")
	-- La caméra tourne pendant l'image (après RenderStepped) : la liaison replace la fenêtre.
	local followed = true
	BEFORE_BINDS = function()
		cam.x += 0.1
		cam.y += 0.03
	end
	for _ = 1, 30 do
		frame(run)
		local fx, fy = trueScreen(run.box.top + Vector3.new(0, UnboxC.ReelAbove, 0))
		followed = followed and sitsOn(gui, fx, fy)
	end
	BEFORE_BINDS = nil
	check(followed, "B8 caméra en mouvement : à chaque image, la fenêtre suit la caméra de cette image")
	-- Sans la liaison (RenderStepped seul), la vue suit quand même à l'image suivante.
	local name = bind and bind.name
	local saved = name and RENDER_BINDS[name]
	if name then
		RENDER_BINDS[name] = nil
	end
	cam.x -= 2
	frame(run)
	local gx, gy = trueScreen(run.box.top + Vector3.new(0, UnboxC.ReelAbove, 0))
	check(sitsOn(gui, gx, gy), "B9 sans BindToRenderStep : placée à chaque image par le déroulé")
	if name and saved then
		RENDER_BINDS[name] = saved
	end
	-- Éclat : la liaison est rendue, l'objet part de la fenêtre vers ItemPreview.
	local reelViewAt = nil
	while not run.runner:IsFired("Reveal") do
		reelViewAt = el(gui, "ReelView").AbsolutePosition
		frame(run)
	end
	local last = RENDER_BIND_LOG[#RENDER_BIND_LOG]
	check(last.kind == "unbind" and last.name == name and RENDER_BINDS[name] == nil, "B10 éclat : liaison rendue (UnbindFromRenderStep)")
	local viewport = el(gui, "ItemPreview"):FindFirstChild("ItemViewport")
	check(viewport ~= nil and (viewport.AbsolutePosition - reelViewAt).Magnitude < 3, "B11 éclat : l'objet part de la fenêtre au-dessus du colis (pas du centre)")
	for _ = 1, 30 do
		frame(run)
	end
	local center = el(gui, "ItemPreview").AbsolutePosition + el(gui, "ItemPreview").AbsoluteSize / 2
	local vc = viewport.AbsolutePosition + viewport.AbsoluteSize / 2
	check((vc - center).Magnitude < 1, "B12 0,45 s plus tard : l'objet est devant le joueur (centré sur ItemPreview)")
	runUntil(run, "Buttons")
	run.view:Close()
	local diffs = diffSnapshot(run.studio, gui)
	check(#diffs == 0, "B13 fermeture : UI_Unbox remis dans son état de Studio (Position de Reel comprise)" .. (if #diffs > 0 then " : " .. table.concat(diffs, " ; ") else ""))
	check(next(RENDER_BINDS) == nil, "B14 aucune liaison qui traîne")
	gui:Destroy()
	-- Fermeture en plein rouleau : liaison rendue aussi.
	local run2 = startRun("Z3_Smartphone", 3, "Premium", "Rare")
	runUntil(run2, "ScrollStart")
	check(next(RENDER_BINDS) ~= nil, "B15 pendant le rouleau : liaison active")
	closeRun(run2)
	check(next(RENDER_BINDS) == nil and #effects() == 0, "B16 fermeture en plein rouleau : liaison rendue, faisceau détruit")
end

print("\n== C. Couvercle et faisceau à l'ouverture")
do
	resetCam()
	-- C1 à C9 : sans animation Unbox, repli de 0,45 s.
	deliver.Unbox = nil
	table.clear(played)
	local run = startRun("Z3_Smartphone", 3, "Premium", "Rare")
	local box = run.box
	local basePos = box.base.Position
	local lidY0 = box.lid.Position.Y
	while run.runner.T + 1 / 60 < 0.45 - 1e-9 do
		frame(run)
	end
	check(#effects() == 0 and box.lid.Position.Y == lidY0 and el(run.gui, "Reel").Visible == false, "C1 avant 0,45 s : couvercle fermé, pas de faisceau, pas de rouleau")
	check(played[1] == "Unbox", "C2 l'animation Unbox est demandée au départ")
	frame(run)
	frame(run)
	local beams = effects()
	check(run.runner:IsFired("Open") and math.abs(run.runner:FiredAt("Open") - 0.45) < 1e-9, "C3 ouverture au repli : 0,45 s")
	check(#beams == 1 and sameColor(beams[1].Color, RaritiesC.ById.Rare.Color), "C4 un faisceau, à la couleur de la rareté (Rare)")
	check(box.lidWeld.Parent == nil and box.tintWeld.Parent == box.base, "C5 copie locale : soudure du couvercle retirée, les autres gardées")
	for _ = 1, 30 do
		frame(run)
	end
	local beam = beams[1]
	check(box.lid.Position.Y > lidY0 + 2 and box.lid.Transparency >= 1 - 1e-9, "C6 le couvercle a sauté et s'est effacé (0,45 s)")
	check((box.base.Position - basePos).Magnitude < 1e-9, "C7 le colis, lui, n'a pas bougé")
	check(math.abs(beam.Size.Y - UnboxC.BeamHeight) < 1e-6 and math.abs(beam.Position.Y - beam.Size.Y / 2 - box.top.Y) < 1e-6, "C8 faisceau de 6 studs, posé sur le haut du colis (pas sur le couvercle envolé)")
	runUntil(run, "Reveal")
	check(beam.Parent == nil and box.model.Parent == nil and #effects() == 0, "C9 éclat : faisceau et colis nettoyés")
	closeRun(run)

	-- C10 à C13 : Unbox livrée, ouverture à son marqueur Open.
	deliver.Unbox = true
	local run2 = startRun("Z3_Smartphone", 3, "Premium", "Rare")
	local lidY = run2.box.lid.Position.Y
	while run2.runner.T < 0.7 do
		frame(run2)
	end
	check(not run2.runner:IsFired("Open") and #effects() == 0 and run2.box.lid.Position.Y == lidY, "C10 animation Unbox jouée : à 0,7 s, on attend encore son marqueur (rien n'est ouvert)")
	run2.runner:OpenMarker()
	local x, y = trueScreen(run2.box.top + Vector3.new(0, UnboxC.ReelAbove, 0))
	check(run2.runner:IsFired("Open") and #effects() == 1 and el(run2.gui, "Reel").Visible and sitsOn(run2.gui, x, y), "C11 marqueur Open (entre deux images) : faisceau, et la fenêtre déjà au-dessus du colis")
	check(sameColor(effects()[1].Color, RaritiesC.ById.Rare.Color), "C12 faisceau du marqueur à la couleur de la rareté")
	for _ = 1, 10 do
		frame(run2)
	end
	check(run2.box.lid.Position.Y > lidY + 0.5, "C13 le couvercle saute après le marqueur")
	closeRun(run2)

	-- C14 : Unbox livrée mais marqueur jamais passé : repli de 1,5 s.
	local run3 = startRun("Z3_Smartphone", 3, "Premium", "Rare")
	runUntil(run3, "Open")
	check(math.abs(run3.runner:FiredAt("Open") - UnboxC.OpenMarkerTimeout) < 1e-9 and #effects() == 1, "C14 marqueur absent : ouverture à 1,5 s, avec le faisceau")
	closeRun(run3)
	deliver.Unbox = nil

	-- C15 : Épique : faisceau violet.
	local run4 = startRun("Z3_HandheldConsole", 3, "Luxe", "Epic")
	runUntil(run4, "Open")
	check(#effects() == 1 and sameColor(effects()[1].Color, RaritiesC.ById.Epic.Color), "C15 Épique : faisceau à la couleur de l'Épique")
	closeRun(run4)
end

print("\n== D. Un seul objet à la fois, en silhouette ; 24 objets en 3,2 s, 10 en 1,3 s")
local function reelModelsOf(gui)
	local out = {}
	for _, c in el(gui, "ReelView"):GetChildren() do
		if c:IsA("Model") then
			table.insert(out, c)
		end
	end
	return out
end
local function checkReel(label, itemId, tier, rarity, count, duration, seed)
	resetCam()
	local run = startRun(itemId, 3, tier, rarity, { seed = seed })
	local gui = run.gui
	local plan = run.plan
	local slot = UnboxC.ReelSlot
	runUntil(run, "Open")
	local maxBuilt, maxVisible, single, singleChecks = 0, 0, true, 0
	local silhouette = true
	local downward, enterTop, exitBottom = true, true, true
	local lastY = {}
	local seen = {}
	local centers = {}
	local nCenters = 0
	-- Pendant la sortie du colis (0,4 s), les objets montent dans la fenêtre ; le défilement les fait
	-- ensuite descendre : le sens n'est contrôlé qu'entre deux images du défilement.
	local wasScrolling = false
	while not run.runner:IsFired("ColorStart") do
		frame(run)
		local f = run.frames[#run.frames]
		local nowScrolling = run.runner:IsFired("ScrollStart") and not run.runner:IsFired("LastNotch")
		local scrolling = nowScrolling and wasScrolling
		wasScrolling = nowScrolling
		local models = reelModelsOf(gui)
		maxBuilt = math.max(maxBuilt, #models)
		local visible = 0
		local present = {}
		for _, m in models do
			local cf, size = m:GetBoundingBox()
			local cy = cf.Position.Y
			if math.abs(cy) - size.Y / 2 < slot / 2 then
				visible += 1
			end
			present[m] = true
			if scrolling then
				if lastY[m] ~= nil and cy > lastY[m] + 1e-6 then
					downward = false
				end
				if not seen[m] and cy <= 0 then
					enterTop = false -- apparu pendant le défilement, mais pas par le haut
				end
			end
			seen[m] = true
			lastY[m] = cy
		end
		if scrolling then
			for m, y in lastY do
				if not present[m] and y > 0 then
					exitBottom = false -- disparu pendant le défilement, mais pas par le bas
				end
			end
		end
		for m in lastY do
			if not present[m] then
				lastY[m] = nil
			end
		end
		maxVisible = math.max(maxVisible, visible)
		if f.pos ~= nil then
			local shown = f.pos + f.drop
			if math.abs(shown - math.floor(shown + 0.5)) < 0.2 then
				singleChecks += 1
				single = single and visible == 1
			end
			if run.runner:IsFired("ScrollStart") then
				local c = math.floor(shown + 0.5)
				if not centers[c] then
					centers[c] = true
					nCenters += 1
				end
			end
		end
		-- Jusqu'à l'image où les couleurs commencent à revenir (ColorStart).
		if not run.runner:IsFired("ColorStart") and not sameColor(el(gui, "ReelView").ImageColor3, Color3.new(0, 0, 0)) then
			silhouette = false
		end
	end
	local at = run.runner.At
	check(maxBuilt <= 3 and maxVisible <= 2, `{label} : jamais plus de 3 clones, jamais plus de 2 objets dans la fenêtre (celui qui sort, celui qui entre)`)
	check(single and singleChecks > 20, `{label} : un objet bien au centre est seul dans la fenêtre ({singleChecks} images)`)
	check(downward and enterTop and exitBottom, `{label} : chaque objet arrive par le haut, descend et ressort par le bas (descend {downward}, entre par le haut {enterTop}, sort par le bas {exitBottom})`)
	check(silhouette, `{label} : silhouettes noires jusqu'à l'arrêt`)
	check(math.abs(at.ScrollEnd - at.ScrollStart - duration) < 1e-9, `{label} : défilement de {duration} s`)
	check(nCenters - 1 == count, `{label} : {count} objets passent au centre après le premier ({nCenters - 1})`)
	local last = run.frames[#run.frames]
	local winnerModel = nil
	for _, m in reelModelsOf(gui) do
		local cf = m:GetBoundingBox()
		if math.abs(cf.Position.Y) < 1e-6 then
			winnerModel = m
		end
	end
	check(plan.Reel.Items[plan.Reel.Winner] == plan.Item and last.pos == plan.Reel.Winner and winnerModel ~= nil and winnerModel.Name == plan.Item.Asset, `{label} : arrêt sur le gagnant du serveur ({plan.Item.Id}, frôlement : {plan.Reel.NearMiss})`)
	while not run.runner:IsFired("Reveal") do
		frame(run)
	end
	check(sameColor(el(gui, "ReelView").ImageColor3, Color3.new(1, 1, 1)), `{label} : à l'arrêt, l'objet a pris ses couleurs (blanc) avant l'éclat`)
	check(el(gui, "Reel").Visible == false and el(gui, "ItemPreview"):FindFirstChild("ItemViewport") ~= nil, `{label} : éclat, le rouleau laisse l'objet à ItemPreview`)
	closeRun(run)
	return plan.Reel.NearMiss
end
do
	local nearMiss, plain = false, false
	for seed = 1, 8 do
		local nm = checkReel(`D complète (graine {seed})`, "Z3_Smartphone", "Premium", "Rare", 24, 3.2, seed)
		nearMiss = nearMiss or nm
		plain = plain or not nm
		if nearMiss and plain and seed >= 2 then
			break
		end
	end
	check(nearMiss and plain, "D avec et sans frôlement : les deux cas vus")
	checkReel("D courte", "Z3_Earbuds", "Standard", "Common", 10, 1.3, 3)
end

print("\n== E. Colis hors du champ : la fenêtre reste à l'écran, au bord le plus proche")
do
	resetCam()
	local run = startRun("Z3_Smartphone", 3, "Premium", "Rare")
	local gui = run.gui
	runUntil(run, "ScrollStart")
	local top = run.box.top + Vector3.new(0, UnboxC.ReelAbove, 0)
	local function at(label, setup, test)
		resetCam()
		setup()
		frame(run)
		local lo, hi = windowRect(gui)
		local ok = test(lo, hi)
		check(ok and onScreen(gui) and lo.X == lo.X and lo.Y == lo.Y, `{label} (fenêtre de ({math.floor(lo.X)}, {math.floor(lo.Y)}) à ({math.floor(hi.X)}, {math.floor(hi.Y)}))`)
	end
	local _, y0 = trueScreen(top)
	at("E1 colis loin à gauche : fenêtre au bord gauche, à sa hauteur", function()
		cam.x = 40
	end, function(lo, hi)
		return math.abs(lo.X - MARGIN) < EPS and math.abs(hi.Y - y0) < EPS
	end)
	at("E2 loin à droite : au bord droit", function()
		cam.x = -30
	end, function(_, hi)
		return math.abs(hi.X - (AREA.X - MARGIN)) < EPS
	end)
	at("E3 sous l'écran : au bord du bas", function()
		cam.y = 20
	end, function(_, hi)
		return math.abs(hi.Y - (AREA.Y - MARGIN)) < EPS
	end)
	at("E4 au-dessus de l'écran : au bord du haut", function()
		cam.y = -20
	end, function(lo)
		return math.abs(lo.Y - MARGIN) < EPS
	end)
	at("E5 derrière la caméra, à gauche : au bord gauche (projection retournée)", function()
		cam.x, cam.behind = 40, true
	end, function(lo)
		return math.abs(lo.X - MARGIN) < EPS
	end)
	at("E6 derrière la caméra, à droite : au bord droit", function()
		cam.x, cam.behind = -30, true
	end, function(_, hi)
		return math.abs(hi.X - (AREA.X - MARGIN)) < EPS
	end)
	local saved = PROJECT
	PROJECT = function()
		return 640, 360, -5
	end
	frame(run)
	local _, hi = windowRect(gui)
	check(math.abs(hi.Y - (AREA.Y - MARGIN)) < EPS and onScreen(gui), "E7 juste derrière la caméra (projection au centre) : au bord du bas")
	PROJECT = saved
	at("E8 de retour dans le champ : de nouveau au-dessus du colis", function() end, function(lo, hi)
		local x, y = trueScreen(top)
		return math.abs((lo.X + hi.X) / 2 - x) < EPS and math.abs(hi.Y - y) < EPS
	end)
	closeRun(run)
end

print("\n== F. Sans copie du colis : au-dessus de l'établi")
do
	resetCam()
	local anchor = Vector3.new(-5, 3, 2)
	local run = startRun("Z3_Smartphone", 3, "Premium", "Uncommon", { box = false, anchor = anchor, upgrades = 1 })
	local gui = run.gui
	runUntil(run, "Pop1")
	frame(run)
	local up = el(gui, "Upgrade")
	local ux, uy = trueScreen(anchor + Vector3.new(0, UnboxC.UpgradeAbove, 0))
	check(up.Visible and math.abs(up.Position.X.Offset - ux) < EPS and math.abs(up.Position.Y.Offset - uy) < EPS, "F1 cran sans colis : Upgrade au-dessus de l'établi")
	runUntil(run, "Open")
	local x, y = trueScreen(anchor + Vector3.new(0, UnboxC.ReelAbove, 0))
	check(sitsOn(gui, x, y), "F2 rouleau sans colis : fenêtre au-dessus de l'établi")
	check(#effects() == 0, "F3 sans colis : pas de faisceau (rien d'où il sortirait)")
	closeRun(run)
	local run2 = startRun("Z3_Smartphone", 3, "Premium", "Rare", { box = false })
	local studioPos = el(run2.gui, "Reel").Position
	runUntil(run2, "ScrollStart")
	check(el(run2.gui, "Reel").Visible and el(run2.gui, "Reel").Position == studioPos, "F4 sans colis ni établi : Reel garde sa place de Studio (documenté)")
	closeRun(run2)
end

print("\n== G. Vrai UnboxController, vrai serveur")
do
	resetCam()
	UnboxService = requireModule(unboxModule, "server")
	Data = requireModule(dataModule, "server")
	Plots = requireModule(plotModule, "server")
	Carry = requireModule(carryModule, "server")
	local greybox = folder(Workspace, "Greybox")
	local plot = InstanceAPI.new("Model")
	plot.Name = "PLOT_Greybox_01"
	plot:SetAttribute("PlotIndex", 1)
	plot:SetAttribute("OwnerUserId", 0)
	for k = 1, 4 do
		local t = new("Part", { Name = string.format("UnboxTable_%02d", k), Size = Vector3.new(3.5, 3, 3), CFrame = CFrame.new((k - 1) * 6, 1.5, 0) }, plot)
		new("Attachment", { Name = string.format("DisplaySlot_%02d", k), CFrame = CFrame.new(0, 1.5, 0) }, t)
	end
	plot.Parent = greybox
	addTag(plot, "PlayerPlot")
	local P1 = InstanceAPI.new("Player")
	P1.Name = "Alice"
	P1.UserId = 101
	P1.DisplayName = "Alice"
	local character = InstanceAPI.new("Model")
	character.Name = "Alice"
	local root = new("Part", { Name = "HumanoidRootPart" }, character)
	new("Humanoid", { Name = "Humanoid" }, character)
	character.Parent = Workspace
	P1.Character = character
	P1.Parent = Players
	local playerGui = folder(P1, "PlayerGui")
	rawset(playerGui, "_class", "PlayerGui")
	local function bench(i)
		return plot:FindFirstChild(string.format("DisplaySlot_%02d", i), true)
	end
	local function near(i)
		local p = bench(i).WorldPosition + Vector3.new(0, 0, 3)
		root.CFrame = CFrame.new(p.X, p.Y, p.Z)
	end
	local function fire(name, ...)
		ReplicatedStorage.Remotes[name].OnServerEvent:Fire(P1, ...)
	end
	UnboxService.Init()
	UnboxService.GetOpenDelay = function()
		return 2
	end
	UnboxService.GetLuck = function()
		return 0
	end
	local data = newData()
	Data._load(P1, data)
	Plots._assign(P1, plot)
	step(0.1)
	-- Colis BOX_Premium de Clément : socle, Tint, Lid soudé.
	local template = new("Model", { Name = "BOX_Premium" }, assets)
	local base = new("Part", { Name = "Base", Size = Vector3.new(2, 1, 2), CFrame = CFrame.new(0, 0.5, 0) }, template)
	new("Part", { Name = "Tint", Size = Vector3.new(1.8, 0.9, 1.8), CFrame = CFrame.new(0, 0.5, 0) }, template)
	local lid = new("Part", { Name = "Lid", Size = Vector3.new(2, 0.2, 2), CFrame = CFrame.new(0, 1.1, 0) }, template)
	new("WeldConstraint", { Name = "LidWeld", Part0 = base, Part1 = lid }, template)
	-- Pivot du modèle en bas au centre (10.1) : WorldPivot à l'origine, pas de PrimaryPart.
	template.WorldPivot = CFrame.new(0, 0, 0)
	local gui = buildUnbox(playerGui)
	local studio = snapshot(gui)
	Players.LocalPlayer = P1
	CLIENT_PLAYER = P1
	local Controller = requireModule(controllerModule, "client")
	taskLib.spawn(Controller.Start)
	step(0.1)
	local function placeReady(i)
		Carry._carry(P1, { Kind = "NPCBox", Tier = "Premium", Zone = 3, Rarity = "Rare", ItemId = "Z3_Smartphone", StoreId = "STORE_Test", SlotId = "S/01" })
		near(i)
		fire("PlaceBox", i)
		step(2.2)
	end
	local function openByPrompt(i)
		near(i)
		step(0.05)
		local p = bench(i):FindFirstChild("UnboxPrompt")
		check(p ~= nil and p.Enabled and p.ActionText == "Open", `G invite « Open » sur l'établi {i}`)
		p.Triggered:Fire()
	end
	cam.x, cam.y = 0, 3
	table.clear(RENDER_BIND_LOG)
	placeReady(1)
	openByPrompt(1)
	step(0.5)
	local localBox = Workspace:FindFirstChild("UnboxLocalBox")
	check(localBox ~= nil and gui.Enabled and el(gui, "Reel").Visible, "G1 ouverture par l'invite : copie locale du colis, rouleau visible")
	-- Le couvercle est déjà en l'air : la fenêtre reste sur le haut du colis fermé (socle + couvercle).
	local top = bench(1).WorldPosition + Vector3.new(0, 1.2, 0)
	local x, y = trueScreen(top + Vector3.new(0, UnboxC.ReelAbove, 0))
	check(sitsOn(gui, x, y), `G2 fenêtre au-dessus de la copie locale du colis (bas centré en ({x}, {y}))`)
	check(#RENDER_BIND_LOG >= 1 and RENDER_BIND_LOG[1].kind == "bind", "G3 placement lié après la caméra pendant la séquence")
	cam.x = 1.5
	step(1 / 30)
	local x2, y2 = trueScreen(top + Vector3.new(0, UnboxC.ReelAbove, 0))
	check(sitsOn(gui, x2, y2), "G4 la caméra bouge : la fenêtre suit")
	step(13)
	check(gui.Enabled == false and #diffSnapshot(studio, gui) == 0 and next(RENDER_BINDS) == nil, "G5 fin (fermeture automatique) : écran remis, liaison rendue")
	-- Le colis du serveur a disparu avant l'appui (copie locale impossible) : au-dessus de l'établi.
	placeReady(2)
	local server = plot:FindFirstChild("StandBox_02")
	check(server ~= nil, "G6 colis BenchBox_02 posé")
	if server then
		server:Destroy()
	end
	openByPrompt(2)
	step(0.5)
	local x3, y3 = trueScreen(bench(2).WorldPosition + Vector3.new(0, UnboxC.ReelAbove, 0))
	check(Workspace:FindFirstChild("UnboxLocalBox") == nil and el(gui, "Reel").Visible and sitsOn(gui, x3, y3), "G7 sans copie du colis : fenêtre au-dessus de l'établi 2 (UnboxBench_02)")
	step(13)
	check(gui.Enabled == false and #diffSnapshot(studio, gui) == 0, "G8 fermé, écran remis")
end

summary()
