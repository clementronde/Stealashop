--!nocheck
-- Copie a83 (2026-11-11, L-096 point 1) : boutique sans StageUpgradePoint ni StageUpgradePoint_2 (voir buildPlot).
-- Scénarios a52 (2026-11-09, L-082 point 1) : panneaux d'amélioration plantés UpgradeSign.
-- Vrais : UpgradeController (côté client), Shared (Config, Contract, Format). Bouchon : Net (BuyItem noté).
-- Le serveur n'est pas simulé : le banc pose OwnerUserId sur les parcelles et les niveaux sur les Player.
--   P1 pose : 3 panneaux sur la boutique d'Alice (tapis, banc, présentoirs au DisplayUpgradePoint),
--      debout au point, face tournée comme le point ; rien sur StageUpgradePoint ; plus aucune invite
--   P2 textes : Title, Level « Level 0 > Level 1 », Price (Formulas + Format), RobuxButton caché ;
--      SignGui dans le PlayerGui d'Alice, Adornee = Board, ResetOnSpawn coupé ; modèle d'origine intact
--   P3 achat : clic → BuyItem ; double clic muet ; muet PENDING_TIMEOUT s puis rejouable ; prix
--      périmé (niveau changé, panneau pas encore mis à jour) refusé ; niveau suivant : même panneau
--   P4 boutique de Bob : panneaux visibles (ses niveaux), SignGui sur Board, clic sans effet
--   P5 niveau max : « Max level », BuyButton caché, clic sans effet
--   P6 sans DisplayUpgradePoint : panneau sur le prochain présentoir, déplacé à l'achat ; plusieurs
--      DisplayUpgradePoint : le plus proche du prochain présentoir
--   P7 streaming : machine retirée puis revenue ; machine sans UpgradePoint : point créé au-dessus
--   P8 réapparition (SignGui perdu : reposé), départ de Bob, parcelle libérée puis nouvelle parcelle
--   P9 repli : UpgradeSign absent ou incomplet → une ligne, invites d'avant ; revenu → panneaux

-- Net : seul BuyItem sert (UpgradeController).
BUY_LOG = {}
SOURCES["shared/Net/Net.luau"] = [[
return { Client = { BuyItem = { Fire = function(_, id) table.insert(BUY_LOG, id) end } } }
]]

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
local Controllers = folder(folder(StarterPlayerScripts, "Client"), "Controllers")
local UpgradeModule = moduleScript(Controllers, "UpgradeController", "client/Controllers/UpgradeController.luau")
local Format = requireModule(Shared:FindFirstChild("Format"), "client")
local Formulas = requireModule(Shared:FindFirstChild("Config"):FindFirstChild("Formulas"), "client")

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
	p.CFrame = cframe
	if size then
		p.Size = size
	end
	return p
end
local function close(a, b, eps)
	return (a - b).Magnitude <= (eps or 1e-3)
end

-- Modèle UpgradeSign de Clément (wave18-studio.md), rangé loin de l'origine, bas à y = 10.
local Assets = folder(ReplicatedStorage, "Assets")
local AssetsUI = folder(Assets, "UI")
local function buildTemplate(withBuy)
	local sign = new("Model", "UpgradeSign", nil)
	sign.WorldPivot = CFrame.new(100, 10, 0)
	part("Foot", sign, CFrame.new(100, 10.9, 0), Vector3.new(1.3, 0.6, 1.3))
	part("FootBase", sign, CFrame.new(100, 10.1, 0), Vector3.new(2.2, 0.2, 1.8))
	local board = part("Board", sign, CFrame.new(100, 13.45, 0), Vector3.new(7, 4.5, 0.4))
	local gui = new("SurfaceGui", "SignGui", board)
	new("Frame", "Panel", gui)
	new("TextLabel", "Title", gui).Text = "Upgrade"
	new("TextLabel", "Level", gui).Text = "Level 2 > Level 3"
	if withBuy ~= false then
		local buy = new("TextButton", "BuyButton", gui)
		new("ImageLabel", "Icon", buy)
		new("TextLabel", "Price", buy).Text = "$0"
	end
	local robux = new("TextButton", "RobuxButton", gui)
	new("ImageLabel", "Icon", robux)
	new("TextLabel", "Price", robux).Text = "R$0"
	return sign
end
local template = buildTemplate()
template.Parent = AssetsUI

-- Boutique comme PLOT_Shop_01 (wave18-studio.md) : points en Attachment.
local AWAY = CFrame.Angles(0, -math.pi / 2, 0) -- LookVector = +X
local function buildPlot(name, x0)
	local plot = new("Model", name, nil)
	local floor = part("PlotFloor", plot, CFrame.new(x0, 0, 0), Vector3.new(60, 1, 60))
	-- Copie a83 (2026-11-11, L-096 point 1) : plus de StageUpgradePoint ici, le panneau des présentoirs y
	-- irait (panneau du niveau suivant de la boutique, testé par le banc a83) ; ce banc garde le repli
	-- DisplayUpgradePoint, le même avant et après la fusion d'a83.
	local treadmill = new("Model", "Treadmill", plot)
	local frame = part("Frame", treadmill, CFrame.new(x0 + 10, 1.5, -20), Vector3.new(4, 3, 8))
	new("Attachment", "UpgradePoint", frame).CFrame = CFrame.new(4, -1.5, 0) * AWAY
	addTag(treadmill, "Treadmill")
	local bench = new("Model", "Bench", plot)
	local rack = part("RackTop", bench, CFrame.new(x0 - 10, 4, -20), Vector3.new(4, 1, 2))
	new("Attachment", "UpgradePoint", rack).CFrame = CFrame.new(0, -4, -3)
	addTag(bench, "Bench")
	local kiosk = part("DisplayKiosk", plot, CFrame.new(x0, 1, 10), Vector3.new(2, 2, 2))
	new("Attachment", "DisplayUpgradePoint", kiosk).CFrame = CFrame.new(0, -1, -2)
	for k = 1, 5 do
		local rayon = new("Model", string.format("Rayon_%02d", k), plot)
		for i = 4 * k - 3, 4 * k do
			local top = part("Top", rayon, CFrame.new(x0 + i * 2, 2, k * 5), Vector3.new(2, 1, 2))
			new("Attachment", string.format("DisplaySlot_%02d", i), top)
		end
	end
	plot.Parent = Workspace
	addTag(plot, "PlayerPlot")
	plot:SetAttribute("OwnerUserId", 0)
	return plot
end
local plot1 = buildPlot("PLOT_Shop_01", 0)
local plot2 = buildPlot("PLOT_Shop_02", 200)
local plot3 = buildPlot("PLOT_Shop_03", 400)

local function player(name, id)
	local p = new("Player", name, Players)
	rawget(p, "_props").UserId = id
	return p
end
local function setLevels(p, t, b, d)
	p:SetAttribute("TreadmillLevel", t)
	p:SetAttribute("BenchLevel", b)
	p:SetAttribute("DisplaySlotsLevel", d)
end
local alice = player("Alice", 101)
local aliceGui = new("PlayerGui", "PlayerGui", alice)
local bob = player("Bob", 102)
setLevels(alice, 0, 0, 0)
setLevels(bob, 3, 5, 2)
plot1:SetAttribute("OwnerUserId", 101)
plot2:SetAttribute("OwnerUserId", 102)

rawget(Players, "_props").LocalPlayer = alice
CLIENT_PLAYER = alice
local Upgrade = requireModule(UpgradeModule, "client")
taskLib.spawn(Upgrade.Start)
advance(0.1)

-- Outils de lecture ----------------------------------------------------------------------------------
local function signFolder()
	return Workspace:FindFirstChild("UpgradeSigns")
end
local function allSigns()
	local f = signFolder()
	return if f then f:GetChildren() else {}
end
local function pointOf(plot, path)
	return Find.path(plot, path)
end
-- Panneau posé sur le point (bas de la boîte au point, à 1e-3 près), ou nil.
local function signAt(point)
	local at = point.WorldCFrame.Position
	for _, sign in allSigns() do
		local box, size = sign:GetBoundingBox()
		local bottom = box.Position - Vector3.new(0, size.Y / 2, 0)
		if close(bottom, at) then
			return sign
		end
	end
	return nil
end
local function guiOf(sign)
	local board = sign and sign:FindFirstChild("Board")
	if board == nil then
		return nil
	end
	local onBoard = board:FindFirstChild("SignGui")
	if onBoard then
		return onBoard
	end
	for _, g in aliceGui:GetChildren() do
		if g.Adornee == board then
			return g
		end
	end
	return nil
end
local function text(gui, path)
	local found = gui and Find.path(gui, path)
	return found and found.Text
end
local function countIn(root, name)
	local n = 0
	for _, d in root:GetDescendants() do
		if d.Name == name then
			n += 1
		end
	end
	return n
end
local function click(sign)
	local gui = guiOf(sign)
	Find.path(gui, "BuyButton").Activated:Fire()
	advance(0)
end
Find = requireModule(Shared:FindFirstChild("Contract"):FindFirstChild("Find"), "client")

local treadPoint = pointOf(plot1, "Treadmill.UpgradePoint")
local benchPoint = pointOf(plot1, "Bench.UpgradePoint")
local kioskPoint = pointOf(plot1, "DisplayUpgradePoint")

---------------------------------------------------------------- P1
print("\nP1 pose des panneaux")
do
	check(#allSigns() == 4, `a134 : 4 panneaux (Alice 2, Bob 2 : tapis et présentoirs ; plus de panneau du banc) : {#allSigns()}`)
	local tread = signAt(treadPoint)
	check(tread ~= nil, "panneau du tapis : bas de la boîte au UpgradePoint")
	local board = tread and tread:FindFirstChild("Board")
	check(board and close(board.CFrame.LookVector, Vector3.new(1, 0, 0)), `… face de Board tournée comme le point (+X) : {board and tostring(board.CFrame.LookVector)}`)
	local p = treadPoint.WorldCFrame.Position
	check(board and math.abs(board.Position.X - p.X) < 1e-3 and math.abs(board.Position.Z - p.Z) < 1e-3, "… Board centré au-dessus du point")
	check(board and close(board.Size, Vector3.new(7, 4.5, 0.4)) and board.Anchored, "… taille inchangée, pièces ancrées")
	local bench = signAt(benchPoint)
	check(bench == nil, "a134 : plus de panneau d'amélioration au banc (plus de banc)")
	check(signAt(kioskPoint) ~= nil, "panneau des présentoirs : au DisplayUpgradePoint")
	check(countIn(plot1, "StageUpgradePoint") == 0 and countIn(plot1, "StageUpgradePoint_2") == 0, "copie a83 : boutique sans StageUpgradePoint (panneau du niveau testé par a83)")
	check(countIn(Workspace, "UpgradePrompt") == 0, "plus aucune invite UpgradePrompt")
	check(countIn(plot3, "UpgradeSign") == 0 and signAt(pointOf(plot3, "Treadmill.UpgradePoint")) == nil, "parcelle libre : aucun panneau")
	check(not logHas("UpgradeSign absent"), "pas de ligne de repli")
end

---------------------------------------------------------------- P2
print("\nP2 textes et SignGui")
do
	local gui = guiOf(signAt(treadPoint))
	check(gui ~= nil and gui.Parent == aliceGui, "SignGui du tapis dans le PlayerGui d'Alice")
	check(gui and gui.Adornee == signAt(treadPoint):FindFirstChild("Board") and gui.ResetOnSpawn == false, "… Adornee = Board, ResetOnSpawn coupé")
	check(text(gui, "Title") == "Treadmill" and text(gui, "Level") == "Level 1 > Level 2", `… a134 (niveau affiché = niveau enregistré + 1) « {text(gui, "Title")} » / « {text(gui, "Level")} »`)
	check(text(gui, "BuyButton.Price") == Format.money(Formulas.UpgradeCost("Treadmill", 0)), `… prix {text(gui, "BuyButton.Price")}`)
	check(Find.path(gui, "BuyButton").Visible and not Find.path(gui, "RobuxButton").Visible, "… BuyButton visible, RobuxButton caché")
	check(signAt(benchPoint) == nil, "a134 : aucun SignGui pour le banc")
	local standGui = guiOf(signAt(kioskPoint))
	check(text(standGui, "Title") == "Display Stands" and text(standGui, "BuyButton.Price") == Format.money(500), `présentoirs : « Display Stands », {text(standGui, "BuyButton.Price")}`)
	check(#aliceGui:GetChildren() == 2, "a134 : 2 SignGui dans le PlayerGui d'Alice (pas ceux de Bob)")
	local original = template:FindFirstChild("Board"):FindFirstChild("SignGui")
	check(original ~= nil and original.Adornee == nil and text(original, "Title") == "Upgrade" and template:FindFirstChild("Board").CFrame.Position.Y == 13.45, "modèle d'origine intact (SignGui, textes, position)")
end

---------------------------------------------------------------- P3
print("\nP3 achat au clic")
do
	local sign = signAt(treadPoint)
	table.clear(BUY_LOG)
	click(sign)
	check(#BUY_LOG == 1 and BUY_LOG[1] == "Treadmill", "clic → BuyItem(\"Treadmill\")")
	click(sign)
	check(#BUY_LOG == 1, "double clic : rien de plus")
	advance(1.6) -- le serveur n'a pas répondu (refus)
	click(sign)
	check(#BUY_LOG == 2, "après PENDING_TIMEOUT sans nouveau niveau : rejouable")
	alice:SetAttribute("TreadmillLevel", 1) -- réponse du serveur
	advance(0.1)
	local gui = guiOf(sign)
	check(signAt(treadPoint) == sign and text(gui, "Level") == "Level 2 > Level 3", "niveau enregistré 1 : même panneau, « Level 2 > Level 3 » (a134)")
	check(text(gui, "BuyButton.Price") == Format.money(Formulas.UpgradeCost("Treadmill", 1)), `… prix {text(gui, "BuyButton.Price")}`)
	click(sign)
	check(#BUY_LOG == 3, "achat du niveau suivant")
	alice:SetAttribute("TreadmillLevel", 2)
	click(sign) -- avant la mise à jour du panneau (prix affiché = niveau 1)
	check(#BUY_LOG == 3, "prix périmé (niveau changé, panneau pas encore à jour) : refusé")
	advance(0.1)
	click(sign)
	check(#BUY_LOG == 4 and BUY_LOG[4] == "Treadmill", "panneau à jour : achat accepté")
	click(signAt(kioskPoint))
	check(BUY_LOG[5] == "DisplaySlots", "panneau des présentoirs → BuyItem(\"DisplaySlots\")")
	alice:SetAttribute("TreadmillLevel", 3)
	alice:SetAttribute("DisplaySlotsLevel", 1)
	advance(0.1)
end

---------------------------------------------------------------- P4
print("\nP4 boutique de Bob, vue par Alice")
do
	local sign = signAt(pointOf(plot2, "Treadmill.UpgradePoint"))
	local gui = guiOf(sign)
	check(sign ~= nil and gui and gui.Parent == sign:FindFirstChild("Board"), "panneau de Bob : SignGui reste sur Board (visible, pas cliquable)")
	check(text(gui, "Level") == "Level 4 > Level 5" and text(gui, "BuyButton.Price") == Format.money(Formulas.UpgradeCost("Treadmill", 3)), `… niveaux de Bob : « {text(gui, "Level")} », {text(gui, "BuyButton.Price")}`)
	local n = #BUY_LOG
	click(sign)
	check(#BUY_LOG == n, "clic sur le panneau de Bob : rien envoyé")
	bob:SetAttribute("TreadmillLevel", 6)
	advance(0.1)
	check(text(guiOf(signAt(pointOf(plot2, "Treadmill.UpgradePoint"))), "Level") == "Level 7 > Level 8", "niveau de Bob suivi (a134 : sur le tapis, plus de banc)")
	bob:SetAttribute("TreadmillLevel", 3)
	advance(0.1)
end

---------------------------------------------------------------- P5
print("\nP5 niveau max")
do
	alice:SetAttribute("TreadmillLevel", 20)
	advance(0.1)
	local sign = signAt(treadPoint)
	local gui = guiOf(sign)
	check(sign ~= nil and text(gui, "Level") == "Max level" and not Find.path(gui, "BuyButton").Visible, "tapis au max : « Max level », BuyButton caché")
	local n = #BUY_LOG
	click(sign)
	check(#BUY_LOG == n, "… clic sans effet")
	alice:SetAttribute("DisplaySlotsLevel", 16)
	advance(0.1)
	local stand = guiOf(signAt(kioskPoint))
	check(stand and text(stand, "Level") == "Max level", "présentoirs au max : panneau resté au DisplayUpgradePoint, « Max level »")
	alice:SetAttribute("TreadmillLevel", 3)
	alice:SetAttribute("DisplaySlotsLevel", 1)
	advance(0.1)
	check(Find.path(guiOf(signAt(treadPoint)), "BuyButton").Visible, "retour sous le max : BuyButton revenu")
end

---------------------------------------------------------------- P6
print("\nP6 point des présentoirs")
do
	local kiosk = kioskPoint.Parent
	kioskPoint.Parent = nil
	advance(0.1)
	local slot6 = pointOf(plot1, "DisplaySlot_06")
	local sign = signAt(slot6)
	check(sign ~= nil, "sans DisplayUpgradePoint : panneau sur le prochain présentoir (DisplaySlot_06, niveau 1)")
	check(#allSigns() == 4, "… l'ancien panneau retiré")
	alice:SetAttribute("DisplaySlotsLevel", 2)
	advance(0.1)
	check(signAt(pointOf(plot1, "DisplaySlot_07")) ~= nil and signAt(slot6) == nil and sign.Parent == nil, "achat : panneau déplacé sur DisplaySlot_07")
	check(#aliceGui:GetChildren() == 2, "… toujours 2 SignGui dans le PlayerGui (l'ancien détruit)")
	click(signAt(pointOf(plot1, "DisplaySlot_07")))
	check(BUY_LOG[#BUY_LOG] == "DisplaySlots", "… cliquable")
	-- Deux DisplayUpgradePoint (un par rayon, L-086 question 4) : le plus proche du prochain présentoir.
	kioskPoint.Parent = kiosk
	local far = new("Attachment", "DisplayUpgradePoint", Find.path(plot1, "DisplaySlot_08").Parent)
	far.CFrame = CFrame.new(0, -0.5, 1)
	advance(0.1)
	check(signAt(far) ~= nil and signAt(kioskPoint) == nil, "deux DisplayUpgradePoint : le plus proche de DisplaySlot_07")
	far:Destroy()
	advance(0.1)
	check(signAt(kioskPoint) ~= nil, "retour au DisplayUpgradePoint du kiosque")
end

---------------------------------------------------------------- P7
print("\nP7 streaming")
do
	local treadmill = plot1:FindFirstChild("Treadmill")
	treadmill.Parent = nil
	advance(0.1)
	check(signAt(treadPoint) == nil and #allSigns() == 3, "tapis retiré (streaming) : son panneau retiré")
	check(#aliceGui:GetChildren() == 1, "… et son SignGui")
	treadmill.Parent = plot1
	advance(0.1)
	check(signAt(treadPoint) ~= nil and #allSigns() == 4 and #aliceGui:GetChildren() == 2, "tapis revenu : panneau reposé")
	local benchPointNow = benchPoint
	benchPointNow.Parent = nil
	advance(0.1)
	local made = Find.path(plot1, "Bench.UpgradePointV0")
	check(made == nil, "a134 : banc sans UpgradePoint : aucun point créé, aucun panneau")
	benchPointNow.Parent = Find.path(plot1, "Bench.RackTop")
	advance(0.1)
	check(signAt(benchPoint) == nil and #allSigns() == 4, "a134 : UpgradePoint du banc revenu : toujours aucun panneau")
end

---------------------------------------------------------------- P8
print("\nP8 réapparition, départ, parcelles")
do
	local gui = guiOf(signAt(treadPoint))
	gui:Destroy() -- un SignGui perdu
	alice.CharacterAdded:Fire()
	advance(0.1)
	check(guiOf(signAt(treadPoint)) ~= nil and #aliceGui:GetChildren() == 2, "réapparition : SignGui perdu reposé")
	bob.Parent = nil
	Players.PlayerRemoving:Fire(bob)
	advance(0.1)
	check(#allSigns() == 2 and signAt(pointOf(plot2, "Treadmill.UpgradePoint")) == nil, "départ de Bob : ses panneaux retirés")
	plot1:SetAttribute("OwnerUserId", 0)
	advance(0.1)
	check(#allSigns() == 0 and #aliceGui:GetChildren() == 0, "parcelle libérée : panneaux et SignGui retirés")
	check(Find.path(plot1, "Bench.UpgradePointV0") == nil, "… et le point créé au-dessus du banc")
	plot3:SetAttribute("OwnerUserId", 101)
	advance(0.1)
	check(#allSigns() == 2 and signAt(pointOf(plot3, "Treadmill.UpgradePoint")) ~= nil and #aliceGui:GetChildren() == 2, "nouvelle parcelle : 2 panneaux, SignGui chez Alice")
	bob.Parent = Players
	Players.PlayerAdded:Fire(bob)
	plot2:SetAttribute("OwnerUserId", 102)
	advance(0.1)
	check(#allSigns() == 4, "Bob revenu : ses panneaux aussi")
end

---------------------------------------------------------------- P9
print("\nP9 repli sans UpgradeSign")
do
	template.Parent = nil
	clearLog()
	alice:SetAttribute("TreadmillLevel", 2) -- a134 : le niveau du banc n'est plus suivi ; un changement du tapis relance la pose
	advance(0.1)
	alice:SetAttribute("TreadmillLevel", 3)
	advance(0.1)
	check(#allSigns() == 0 and #aliceGui:GetChildren() == 0, "modèle absent : panneaux retirés")
	check(logHas("UpgradeSign absent de ReplicatedStorage.Assets.UI", "PRINT"), "… une ligne dans la sortie")
	check(countIn(plot3, "UpgradePrompt") == 2 and countIn(plot2, "UpgradePrompt") == 0, "… invites d'avant, chez Alice seulement (a134 : tapis et présentoirs)")
	local prompt = Find.path(plot3, "Treadmill.UpgradePoint.UpgradePrompt")
	check(prompt and prompt.ActionText == "Upgrade (" .. Format.money(Formulas.UpgradeCost("Treadmill", 3)) .. ")" and prompt.ObjectText == "Treadmill Lv 4/20", `… textes « {prompt and prompt.ActionText} » / « {prompt and prompt.ObjectText} »`)
	local n = #BUY_LOG
	prompt.Triggered:Fire()
	advance(0)
	check(#BUY_LOG == n + 1 and not prompt.Enabled, "… maintien → BuyItem, invite coupée")
	bob:SetAttribute("TreadmillLevel", 4)
	advance(0.1)
	local lines = 0
	for _, line in LOG do
		if string.find(line.text, "UpgradeSign", 1, true) then
			lines += 1
		end
	end
	check(lines == 1, `… une seule ligne ({lines})`)
	local broken = buildTemplate(false)
	broken.Parent = AssetsUI
	alice:SetAttribute("TreadmillLevel", 4) -- a134 : le niveau du banc n'est plus suivi
	advance(0.1)
	check(#allSigns() == 0 and countIn(plot3, "UpgradePrompt") == 2, "modèle sans BuyButton : toujours les invites")
	broken:Destroy()
	template.Parent = AssetsUI
	alice:SetAttribute("TreadmillLevel", 5)
	advance(0.1)
	check(#allSigns() == 4 and countIn(Workspace, "UpgradePrompt") == 0, "modèle revenu : panneaux reposés, invites retirées")
end

summary()
