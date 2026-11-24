-- Tests de PlotService hors Studio. `newWorld()` (fake.luau) crée un faux jeu neuf.

local failures, passes = 0, 0
local function check(cond, label)
	if cond then
		passes += 1
		print("OK    " .. label)
	else
		failures += 1
		print("ÉCHEC " .. label)
	end
end
local function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-4)
end
local function nearV(a, b)
	return a ~= nil and near(a.X, b.X) and near(a.Y, b.Y) and near(a.Z, b.Z)
end
local function hasLine(list, needle)
	for _, line in list do
		if string.find(line, needle, 1, true) then
			return true
		end
	end
	return false
end

------------------------------------------------------------------------------
-- Construction d'un monde comme la greybox
------------------------------------------------------------------------------
local function makePart(F, name, parent, cframe, size)
	local p = F.newInst("Part", name, parent)
	p.CFrame = cframe
	p.Size = size or F.Vector3.new(1, 1, 1)
	p.Color = F.Color3.new(0.2, 0.2, 0.2)
	return p
end

local function makePlot(F, parent, index, x, side, opts)
	opts = opts or {}
	local CF = F.CFrame
	local frame = CF.new(x, 0, side * 80) * (if side > 0 then CF.identity else CF.Angles(0, math.pi, 0))
	local model = F.newInst("Model", opts.name or string.format("PLOT_Greybox_%02d", index), parent)
	model.WorldPivot = frame
	if not opts.noWindow then
		makePart(F, "Window", model, frame * CF.new(0, 4, -39.5), F.Vector3.new(12, 7, 0.4))
	end
	if not opts.noSign then
		local signFrame = frame * CF.new(0, 18, -39.7) * (opts.signYaw and CF.Angles(0, opts.signYaw, 0) or CF.identity)
		local sign = makePart(F, "NameSign", model, signFrame, F.Vector3.new(28, 4, 0.6))
		if opts.ownerLabel then
			local g = F.newInst("SurfaceGui", "ClementSign", sign)
			local l = F.newInst(opts.ownerLabel, "OwnerName", g)
			l.Text = "Boutique de Pseudo"
		else
			local g = F.newInst("SurfaceGui", "SignFront", sign)
			g.Face = F.Enum.NormalId.Front
			local l = F.newInst("TextLabel", "Label", g)
			l.Text = "PARCELLE " .. tostring(index)
		end
	end
	if opts.spawnPoint then
		local floor = makePart(F, "PlotFloor", model, frame * CF.new(0, -0.45, 0), F.Vector3.new(64, 1.1, 80))
		local a = F.newInst("Attachment", "SpawnPoint", floor)
		a.WorldCFrame = opts.spawnPoint
	end
	if opts.plotIndex ~= false then
		model:SetAttribute("PlotIndex", if opts.plotIndex == nil then index else opts.plotIndex)
	end
	F.addTag(model, "PlayerPlot")
	return model
end

local function greybox(F)
	local root = F.newInst("Folder", "Greybox", F.Workspace)
	local folder = F.newInst("Folder", "Plots", root)
	local spawn = makePart(F, "Spawn", root, F.CFrame.new(-120, -0.4, 0), F.Vector3.new(8, 1, 8))
	local list = {}
	for k = 1, 3 do
		local x = -120 + (2 - k) * 80
		list[k] = makePlot(F, folder, k, x, 1)
		list[k + 3] = makePlot(F, folder, k + 3, x, -1)
	end
	return list, spawn
end

local function addPlayer(F, userId, displayName)
	local p = F.newInst("Player", "Player_" .. displayName, F.Players)
	p.UserId = userId
	p.DisplayName = displayName
	p.CharacterAdded = F.newSignal()
	return p
end

-- Comme DataService : profil chargé, puis les listeners OnProfileLoaded.
local function loadProfile(F, player)
	F.DS.loaded[player] = true
	for _, listener in table.clone(F.DS.listeners) do
		F.task.spawn(listener, player)
	end
end

-- Comme Roblox : PlayerRemoving (DataService branché avant, il libère le profil
-- en premier), puis le joueur quitte Players.
local function removePlayer(F, player)
	F.DS.loaded[player] = nil
	F.Players.PlayerRemoving:Fire(player)
	player.Parent = nil
end

local function makeCharacter(F, player, inWorkspace)
	local char = F.newInst("Model", player.Name, nil)
	local root = makePart(F, "HumanoidRootPart", char, F.CFrame.new(-120, 3, 0), F.Vector3.new(2, 2, 1))
	char.PrimaryPart = root
	local hum = F.newInst("Humanoid", "Humanoid", char)
	hum.RigType = F.Enum.HumanoidRigType.R15
	hum.HipHeight = 2
	hum.Health = 100
	if inWorkspace ~= false then
		char.Parent = F.Workspace
	end
	player.Character = char
	return char, root, hum
end

local function signLabel(plot)
	return plot.NameSign:FindFirstChild("OwnerName", true)
end
local function signGui(plot)
	return plot.NameSign:FindFirstChild("OwnerSign")
end

------------------------------------------------------------------------------
print("== 1. Greybox : 7 joueurs, départs, file d'attente")
------------------------------------------------------------------------------
do
	local F = newWorld()
	local plots = greybox(F)
	local inbox = F.newInst("Folder", "_INBOX_CLEMENT", F.Workspace)
	local inboxPlot = makePlot(F, inbox, 7, 300, 1)
	local sandbox = F.newInst("Folder", "_SANDBOX_IRONIX", F.Workspace)
	local sandboxPlot = makePlot(F, sandbox, 8, 400, 1)
	local assets = F.newInst("Folder", "Assets", F.ReplicatedStorage)
	local assetPlot = makePlot(F, assets, 9, 500, 1)

	local PS = F.require(F.PlotModule)
	check(PS.Priority == 10, "Priority = 10")
	PS.Init()
	check(#F.LOG.warns == 0, "Init sans avertissement")
	check(hasLine(F.LOG.prints, "6 parcelle(s) : 1 PLOT_Greybox_01, 2 PLOT_Greybox_02"), "Init liste les 6 parcelles dans l'ordre")
	local allFree, allSigns = true, true
	for _, plot in plots do
		allFree = allFree and plot:GetAttribute("OwnerUserId") == 0
		local gui = signGui(plot)
		allSigns = allSigns
			and gui ~= nil
			and gui.Enabled == false
			and gui.ZOffset == 1
			and gui.Face == F.Enum.NormalId.Front
			and gui.OwnerName ~= nil
			and gui.OwnerName.Text == ""
			and gui.OwnerName.ClassName == "TextLabel"
	end
	check(allFree, "les 6 parcelles ont OwnerUserId = 0")
	check(allSigns, "SurfaceGui V0 OwnerSign sur la face avant, masqué, texte vide (N et S)")
	check(plots[1].NameSign.SignFront.Label.Text == "PARCELLE 1", "le texte de la greybox n'est pas touché")
	check(
		inboxPlot:GetAttribute("OwnerUserId") == nil and sandboxPlot:GetAttribute("OwnerUserId") == nil and assetPlot:GetAttribute("OwnerUserId") == nil,
		"parcelles de _INBOX_CLEMENT, _SANDBOX_IRONIX et Assets ignorées"
	)

	local assigned, released = {}, {}
	PS.OnPlotAssigned(function(p, plot)
		table.insert(assigned, { p = p, plot = plot, owner = PS.GetOwner(plot) })
	end)
	PS.OnPlotReleased(function(p, plot)
		table.insert(released, { p = p, plot = plot, attr = plot:GetAttribute("OwnerUserId"), owner = PS.GetOwner(plot), mine = PS.GetPlot(p), index = p:GetAttribute("PlotIndex") })
	end)

	local names = { "Alice", "Bob", "Chloe", "David", "Emma", "Farid", "Gus" }
	local players = {}
	for i = 1, 7 do
		players[i] = addPlayer(F, 100 + i, names[i])
		loadProfile(F, players[i])
	end
	local okAssign = true
	for i = 1, 6 do
		okAssign = okAssign
			and PS.GetPlot(players[i]) == plots[i]
			and plots[i]:GetAttribute("OwnerUserId") == 100 + i
			and players[i]:GetAttribute("PlotIndex") == i
			and PS.GetOwner(plots[i]) == players[i]
	end
	check(okAssign, "6 joueurs : parcelles 1 à 6 dans l'ordre, OwnerUserId et PlotIndex posés")
	check(signLabel(plots[1]).Text == "Alice's Shop", "panneau « Alice's Shop » (L-036)")
	check(signLabel(plots[2]).Text == "Bob's Shop", "panneau « Bob's Shop »")
	check(signLabel(plots[4]).Text == "David's Shop" and signGui(plots[4]).Enabled == true, "panneau affiché quand la parcelle est prise")
	check(#assigned == 6 and assigned[1].owner == players[1], "OnPlotAssigned × 6, GetOwner déjà à jour")
	check(PS.GetPlot(players[7]) == nil and players[7]:GetAttribute("PlotIndex") == nil, "7e joueur : pas de parcelle")
	check(#F.NOTIFY == 1 and F.NOTIFY[1].player == players[7] and F.NOTIFY[1].kind == "Warning", "7e joueur prévenu (Notify Warning)")
	check(hasLine(F.LOG.warns, "aucune parcelle libre (6 prise(s))"), "avertissement « aucune parcelle libre » dans la sortie")

	local replay = {}
	PS.OnPlotAssigned(function(p)
		table.insert(replay, p)
	end)
	check(#replay == 6, "OnPlotAssigned rejoue les 6 attributions existantes")

	removePlayer(F, players[3])
	local r = released[1]
	check(#released == 1 and r.p == players[3] and r.plot == plots[3], "départ de Chloe : OnPlotReleased(Chloe, parcelle 3)")
	check(r.attr == 0 and r.owner == nil and r.mine == nil and r.index == nil, "pendant OnPlotReleased : parcelle déjà libre (OwnerUserId 0)")
	check(PS.GetPlot(players[7]) == plots[3] and plots[3]:GetAttribute("OwnerUserId") == 107, "Gus (en attente) reçoit la parcelle 3")
	check(players[7]:GetAttribute("PlotIndex") == 3 and signLabel(plots[3]).Text == "Gus's Shop", "PlotIndex et panneau de Gus")
	check(F.NOTIFY[2] ~= nil and F.NOTIFY[2].player == players[7] and F.NOTIFY[2].kind == "Info", "Gus prévenu (Notify Info)")
	check(#assigned == 7, "OnPlotAssigned appelé pour Gus")

	local hugo = addPlayer(F, 108, "Hugo")
	loadProfile(F, hugo)
	check(PS.GetPlot(hugo) == nil, "Hugo attend")
	removePlayer(F, hugo)
	removePlayer(F, players[1])
	check(plots[1]:GetAttribute("OwnerUserId") == 0 and PS.GetOwner(plots[1]) == nil, "Hugo parti de la file, puis Alice : parcelle 1 libre")
	check(signLabel(plots[1]).Text == "" and signGui(plots[1]).Enabled == false, "panneau vide et masqué quand la parcelle est libre")
	check(#F.NOTIFY == 3 and F.NOTIFY[3].player == hugo, "pas de Notify à un joueur parti")

	-- Départ pendant le chargement : l'événement tardif ne doit rien attribuer.
	local ines = addPlayer(F, 109, "Ines")
	removePlayer(F, ines)
	for _, listener in F.DS.listeners do
		F.task.spawn(listener, ines)
	end
	check(PS.GetPlot(ines) == nil and plots[1]:GetAttribute("OwnerUserId") == 0, "joueur parti pendant le chargement : aucune parcelle prise")
	local jade = addPlayer(F, 110, "Jade")
	for _, listener in F.DS.listeners do
		F.task.spawn(listener, jade) -- profil non chargé (ou déjà libéré par DataService)
	end
	check(PS.GetPlot(jade) == nil, "profil non chargé : aucune parcelle")

	local kim = addPlayer(F, 111, "Kim")
	loadProfile(F, kim)
	check(PS.GetPlot(kim) == plots[1], "nouveau joueur : plus petite parcelle libre (1)")
	loadProfile(F, kim)
	check(PS.GetPlot(kim) == plots[1] and plots[2]:GetAttribute("OwnerUserId") == 102, "profil chargé deux fois : une seule parcelle")

	PS.OnPlotReleased(function()
		error("boum")
	end)
	removePlayer(F, kim)
	check(plots[1]:GetAttribute("OwnerUserId") == 0 and hasLine(F.LOG.warns, "OnPlotReleased"), "erreur dans un OnPlotReleased : signalée, parcelle libérée quand même")
	check(#F.LOG.errors == 0, "aucune erreur dans les tâches")
end

------------------------------------------------------------------------------
print("== 2. Apparition, retour base")
------------------------------------------------------------------------------
do
	local F = newWorld()
	local plots = greybox(F)
	local PS = F.require(F.PlotModule)
	PS.Init()
	local V = F.Vector3.new

	local alice = addPlayer(F, 201, "Alice")
	local _, root = makeCharacter(F, alice)
	loadProfile(F, alice)
	check(nearV(root.CFrame.Position, V(-120, 3, 0)), "pas déplacée avant une image (le moteur la pose d'abord au spawn)")
	F.step(1)
	check(nearV(root.CFrame.Position, V(-40, 3.1, 34.5)), "Alice (parcelle 1, côté N) : 6 studs devant la vitrine, pieds au sol")
	check(nearV(root.CFrame.LookVector, V(0, 0, -1)), "tournée vers l'allée (−Z)")
	check(root.AssemblyLinearVelocity == F.Vector3.zero, "vitesse remise à zéro")
	local ray = F.Workspace.LastRaycast
	check(ray ~= nil and near(ray.origin.Y, 4) and near(ray.direction.Y, -12), "sol cherché de 4 studs au-dessus à 8 en dessous du pivot")
	check(ray.params.RespectCanCollide == true and ray.params.FilterType == F.Enum.RaycastFilterType.Exclude, "rayon : collisions respectées, personnages exclus")
	check(table.find(ray.params.FilterDescendantsInstances, alice.Character) ~= nil, "le personnage d'Alice est exclu du rayon")

	local others = {}
	for i = 2, 4 do
		others[i] = addPlayer(F, 200 + i, "P" .. i)
		loadProfile(F, others[i])
	end
	local _, root4 = makeCharacter(F, others[4])
	others[4].CharacterAdded:Fire(others[4].Character)
	F.step(1)
	check(nearV(root4.CFrame.Position, V(-40, 3.1, -34.5)) and nearV(root4.CFrame.LookVector, V(0, 0, 1)), "parcelle 4 (côté S) : devant la vitrine, tourné vers l'allée (+Z)")

	-- Réapparition : nouveau personnage, d'abord hors du Workspace
	local char3, root3 = makeCharacter(F, alice, false)
	alice.CharacterAdded:Fire(char3)
	F.step(2)
	check(nearV(root3.CFrame.Position, V(-120, 3, 0)), "réapparition : attend que le personnage soit dans le Workspace")
	char3.Parent = F.Workspace
	F.step(3)
	check(nearV(root3.CFrame.Position, V(-40, 3.1, 34.5)), "réapparition : replacée sur sa parcelle")

	-- Retour base
	root3.CFrame = F.CFrame.new(600, 3, 0)
	check(PS.TeleportHome(alice) == true and nearV(root3.CFrame.Position, V(-40, 3.1, 34.5)), "TeleportHome : retour devant sa vitrine")
	local nobody = addPlayer(F, 299, "Personne")
	check(PS.TeleportHome(nobody) == false, "TeleportHome sans parcelle : false")
	F.Workspace.GroundY = 0.5
	PS.TeleportHome(alice)
	check(near(root3.CFrame.Position.Y, 3.6), "sol plus haut (0,5) : pieds sur ce sol")
	F.Workspace.GroundY = nil
	PS.TeleportHome(alice)
	check(near(root3.CFrame.Position.Y, 3.1), "rayon sans sol : hauteur du pivot de la parcelle")
	F.Workspace.GroundY = 0

	local hum = char3:FindFirstChildOfClass("Humanoid")
	hum.Health = 0
	root3.CFrame = F.CFrame.new(600, 3, 0)
	check(PS.TeleportHome(alice) == false and nearV(root3.CFrame.Position, V(600, 3, 0)), "personnage mort : pas déplacé")
	hum.Health = 100

	-- StreamingEnabled : attente du client, puis revérification
	F.Workspace.StreamingEnabled = true
	alice.StreamYield = true
	local result = "pas fini"
	F.task.spawn(function()
		result = PS.TeleportHome(alice)
	end)
	check(result == "pas fini" and alice.StreamRequests == 1, "StreamingEnabled : RequestStreamAroundAsync avant le déplacement")
	F.step(1)
	check(result == true and nearV(root3.CFrame.Position, V(-40, 3.1, 34.5)), "StreamingEnabled : déplacée après le chargement")
	root3.CFrame = F.CFrame.new(600, 3, 0)
	result = "pas fini"
	F.task.spawn(function()
		result = PS.TeleportHome(alice)
	end)
	removePlayer(F, alice)
	F.step(1)
	check(result == false and nearV(root3.CFrame.Position, V(600, 3, 0)), "parti pendant le chargement de la zone : pas déplacée")
	check(#F.LOG.errors == 0, "aucune erreur dans les tâches")
end

------------------------------------------------------------------------------
print("== 3. SpawnPoint, panneau OwnerName, NameSign tourné ou absent")
------------------------------------------------------------------------------
do
	local F = newWorld()
	local CF = F.CFrame
	local V = F.Vector3.new
	local folder = F.newInst("Folder", "Map", F.Workspace)
	local p1 = makePlot(F, folder, 1, 0, 1, { spawnPoint = CF.new(10, 0.1, 50) * CF.Angles(0, math.pi / 2, 0), ownerLabel = "TextLabel" })
	local p2 = makePlot(F, folder, 2, 80, 1, { signYaw = math.pi / 2 })
	local p3 = makePlot(F, folder, 3, 160, 1, { noSign = true, noWindow = true })
	local p4 = makePlot(F, folder, 4, 240, 1, { ownerLabel = "Frame" })
	local PS = F.require(F.PlotModule)
	PS.Init()
	check(p1.NameSign:FindFirstChild("OwnerSign") == nil and signLabel(p1).Text == "", "OwnerName fourni : pas de SurfaceGui créé, texte vidé")
	check(signGui(p2) ~= nil and signGui(p2).Face == F.Enum.NormalId.Right, "NameSign tourné de 90° : face Right, celle tournée vers l'allée")
	check(hasLine(F.LOG.warns, "pas de NameSign"), "NameSign absent : avertissement")
	check(hasLine(F.LOG.warns, "doit être un TextLabel"), "OwnerName qui n'est pas un TextLabel : avertissement")

	F.Workspace.GroundY = 0.1
	local a = addPlayer(F, 301, "Ophelie")
	local _, root = makeCharacter(F, a)
	loadProfile(F, a)
	F.step(1)
	check(signLabel(p1).Text == "Ophelie's Shop", "OwnerName de Clément rempli")
	check(nearV(root.CFrame.Position, V(10, 3.2, 50)) and nearV(root.CFrame.LookVector, V(-1, 0, 0)), "SpawnPoint : position et regard de l'Attachment")

	F.Workspace.GroundY = 0
	local b, c = addPlayer(F, 302, "Bob"), addPlayer(F, 303, "Cyril")
	loadProfile(F, b)
	loadProfile(F, c)
	local _, rootC = makeCharacter(F, c)
	c.CharacterAdded:Fire(c.Character)
	F.step(1)
	check(PS.GetPlot(c) == p3 and nearV(rootC.CFrame.Position, V(160, 3.1, 80)), "sans Window ni SpawnPoint : pivot de la parcelle")
	removePlayer(F, a)
	check(signLabel(p1).Text == "", "OwnerName vidé au départ")
	check(#F.LOG.errors == 0, "aucune erreur dans les tâches")
end

------------------------------------------------------------------------------
print("== 4. PlotIndex absent, en double ou invalide ; tag sur une Part")
------------------------------------------------------------------------------
do
	local F = newWorld()
	local folder = F.newInst("Folder", "Map", F.Workspace)
	local a = makePlot(F, folder, 1, 0, 1, { name = "PLOT_A", plotIndex = 2 })
	local b = makePlot(F, folder, 2, 80, 1, { name = "PLOT_B", plotIndex = 2 })
	local c = makePlot(F, folder, 3, 160, 1, { name = "PLOT_C", plotIndex = false })
	local d = makePlot(F, folder, 4, 240, 1, { name = "PLOT_D", plotIndex = "3" })
	local e = makePlot(F, folder, 5, 320, 1, { name = "PLOT_E", plotIndex = 5 })
	local f = makePlot(F, folder, 6, 400, 1, { name = "PLOT_F", plotIndex = 2.5 })
	local part = F.newInst("Part", "PLOT_Part", folder)
	F.addTag(part, "PlayerPlot")
	local PS = F.require(F.PlotModule)
	PS.Init()
	check(
		a:GetAttribute("PlotIndex") == 2 and e:GetAttribute("PlotIndex") == 5,
		"numéros valides et uniques gardés (2 et 5)"
	)
	check(
		b:GetAttribute("PlotIndex") == 1 and c:GetAttribute("PlotIndex") == 3 and d:GetAttribute("PlotIndex") == 4 and f:GetAttribute("PlotIndex") == 6,
		"doublon, absent, texte, non entier : plus petits numéros libres (1, 3, 4, 6)"
	)
	local n = 0
	for _, line in F.LOG.warns do
		if string.find(line, "attribut PlotIndex", 1, true) then
			n += 1
		end
	end
	check(n == 4, "4 avertissements PlotIndex")
	check(hasLine(F.LOG.warns, "n'est pas un Model"), "tag sur une Part : ignoré avec avertissement")
	local p = addPlayer(F, 401, "Zoe")
	loadProfile(F, p)
	check(PS.GetPlot(p) == b and p:GetAttribute("PlotIndex") == 1, "1er joueur : parcelle numéro 1")
end

------------------------------------------------------------------------------
print("== 5. Aucune parcelle ; listener OnPlotAssigned en erreur")
------------------------------------------------------------------------------
do
	local F = newWorld()
	local PS = F.require(F.PlotModule)
	PS.Init()
	check(hasLine(F.LOG.warns, "aucune parcelle taggée PlayerPlot"), "aucune parcelle : avertissement à l'Init")
	local p = addPlayer(F, 501, "Ugo")
	loadProfile(F, p)
	check(PS.GetPlot(p) == nil, "aucune parcelle : joueur sans parcelle, pas d'erreur")

	local G = newWorld()
	local plots = greybox(G)
	local PS2 = G.require(G.PlotModule)
	PS2.Init()
	local seen = 0
	PS2.OnPlotAssigned(function()
		error("listener cassé")
	end)
	PS2.OnPlotAssigned(function()
		seen += 1
	end)
	local q = addPlayer(G, 502, "Val")
	loadProfile(G, q)
	check(PS2.GetPlot(q) == plots[1] and seen == 1, "un listener en erreur n'empêche pas les autres")
	check(#G.LOG.errors == 1, "l'erreur du listener est signalée")
end

------------------------------------------------------------------------------
print("== 6. Ordre des PlayerRemoving inversé ; objet exposé qui contient « Window »")
------------------------------------------------------------------------------
do
	local F = newWorld()
	local CF = F.CFrame
	local V = F.Vector3.new
	local plots = greybox(F)
	local PS = F.require(F.PlotModule)
	PS.Init()

	-- PlotService reçoit PlayerRemoving avant DataService (profil encore actif, joueur
	-- encore dans Players), puis le chargement du profil se termine : rien ne doit être pris.
	local late = addPlayer(F, 601, "Tardif")
	F.DS.loaded[late] = true
	F.Players.PlayerRemoving:Fire(late)
	for _, listener in F.DS.listeners do
		F.task.spawn(listener, late)
	end
	check(PS.GetPlot(late) == nil and plots[1]:GetAttribute("OwnerUserId") == 0, "profil chargé pendant le départ : aucune parcelle prise")
	F.DS.loaded[late] = nil
	late.Parent = nil

	-- Parcelle dont la vitrine est dans un sous-modèle, et un dossier d'objets exposés
	-- placé avant lui : un objet posé après l'Init ne doit pas remplacer la vitrine.
	local G = newWorld()
	local folder = G.newInst("Folder", "Map", G.Workspace)
	local frame = G.CFrame.new(0, 0, 80)
	local plot = G.newInst("Model", "PLOT_Shop_L1", folder)
	plot.WorldPivot = frame
	local display = G.newInst("Folder", "Display", plot)
	local shop = G.newInst("Model", "Shop", plot)
	makePart(G, "Window", shop, frame * G.CFrame.new(0, 4, -39.5), G.Vector3.new(12, 7, 0.4))
	makePart(G, "NameSign", shop, frame * G.CFrame.new(0, 18, -39.7), G.Vector3.new(28, 4, 0.6))
	plot:SetAttribute("PlotIndex", 1)
	G.addTag(plot, "PlayerPlot")
	local PS2 = G.require(G.PlotModule)
	PS2.Init()
	local item = G.newInst("Model", "ITM_Z3_Console", display)
	makePart(G, "Window", item, G.CFrame.new(999, 0, 999), G.Vector3.new(1, 1, 1))
	local p = addPlayer(G, 602, "Lea")
	local _, root = makeCharacter(G, p)
	loadProfile(G, p)
	G.step(1)
	check(nearV(root.CFrame.Position, V(0, 3.1, 34.5)), "apparition devant la vraie vitrine, pas devant celle d'un objet posé après l'Init")
	check(#F.LOG.errors == 0 and #G.LOG.errors == 0, "aucune erreur dans les tâches")
end

print(string.format("\n%d réussi(s), %d échec(s)", passes, failures))
if failures > 0 then
	error("tests en échec")
end
