---------------------------------------------------------------- scénarios (agent a300, 21/11)
print("== Banc a300 : barre de PV des boutiques de joueurs fixe, centrée sur la façade")

-- Faux Net : seuls les signaux client écoutés par WindowController (WindowHP, WindowHit, WindowBroken).
local CLIENT_SIGNALS = {}
FAKE_NET = { Server = {}, Client = setmetatable({}, {
	__index = function(t, name)
		local s = newSignal()
		CLIENT_SIGNALS[name] = s
		local remote = { Connect = function(_, fn) return s:Connect(fn) end }
		rawset(t, name, remote)
		return remote
	end,
}) }
SOURCES["shared/Net/Net.luau"] = "return FAKE_NET"

local ROOTS = { shared = { ReplicatedStorage, "Shared" }, server = { ServerScriptService, "Server" }, client = { StarterPlayerScripts, "Client" } }
MODULES = {}
local keys = {}
for key in SOURCES do
	table.insert(keys, key)
end
table.sort(keys)
local function child(parent, name)
	return parent:FindFirstChild(name) or folder(parent, name)
end
for _, key in keys do
	local parts = string.split(key, "/")
	local root = ROOTS[parts[1]]
	local current = child(root[1], root[2])
	for i = 2, #parts - 1 do
		current = child(current, parts[i])
	end
	local name = string.gsub(parts[#parts], "%.luau$", "")
	MODULES[key] = moduleScript(current, name, key)
end

---------------------------------------------------------------- monde
new("Part", { Name = "Floor", Size = Vector3.new(800, 1, 800), CFrame = CFrame.new(0, -0.5, 0) }, Workspace)
local terrain = new("Terrain", { Name = "Terrain" }, Workspace)
local ui = folder(folder(ReplicatedStorage, "Assets"), "UI")
local OFFSET = Vector3.new(0, 5.45, 0) -- décalage du modèle de Clément (lu dans Studio le 21/11)
local SIZE = UDim2.new(4.5, 100, 1.2, 40)
local bb = new("BillboardGui", { Name = "BB_WindowHP", Size = SIZE, StudsOffset = OFFSET, MaxDistance = 80, AlwaysOnTop = true }, ui)
new("TextLabel", { Name = "Label", Text = "100 / 100" }, bb)
local bar = new("Frame", { Name = "Bar" }, bb)
new("Frame", { Name = "Fill", Size = UDim2.new(1, 0, 1, 0) }, bar)
local map = folder(Workspace, "Map")

-- Parcelle comme PLOT_Shop_05 (lue dans Studio le 21/11) : Bounds 48 x 29,7 x 80 tournée de 90°, porte
-- PlotDoor/Window au bord avant, vantaux Leaf_L et Leaf_R (Glass, rails), PrimaryPart = Leaf_L.Glass.
-- `parts = false` : le Model arrive sans pièces (streaming), elles sont ajoutées par le test.
local BOUNDS_CF = CFrame.new(-106, 15.15, -88.5) * CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, 1), Vector3.new(0, 1, 0), Vector3.new(-1, 0, 0))
local function leaf(window, name, z)
	local m = new("Model", { Name = name })
	local glass = new("Part", { Name = "Glass", Size = Vector3.new(0.6, 9.9, 8.4), CFrame = CFrame.new(-66.5, 5.85, z) }, m)
	new("Part", { Name = "Rail_Top", Size = Vector3.new(0.6, 0.3, 8.4), CFrame = CFrame.new(-66.5, 10.95, z) }, m)
	new("Part", { Name = "Rail_Bottom", Size = Vector3.new(0.6, 0.3, 8.4), CFrame = CFrame.new(-66.5, 0.75, z) }, m)
	m.Parent = window
	return m, glass
end
local function plot(name, offset, id, withParts)
	local model = new("Model", { Name = name })
	model.WorldPivot = CFrame.new(offset) * CFrame.new(-106, 0, -88.5) * CFrame.Angles(0, -math.pi / 2, 0)
	local door = new("Model", { Name = "PlotDoor" }, model)
	new("Part", { Name = "Header", Size = Vector3.new(2, 11.5, 20), CFrame = CFrame.new(offset) * CFrame.new(-66.5, 16.8, -88.5) }, door)
	local window = new("Model", { Name = "Window" })
	window:SetAttribute("WindowId", id)
	window:SetAttribute("MaxHP", 100)
	window:SetAttribute("Broken", false)
	window.Parent = door
	local res = { model = model, window = window, door = door, offset = offset }
	if withParts then
		local l, glassL = leaf(window, "Leaf_L", -93)
		local r = leaf(window, "Leaf_R", -84)
		window.PrimaryPart = glassL
		res.leafL, res.leafR, res.glassL = l, r, glassL
		res.bounds = new("Part", { Name = "Bounds", Size = Vector3.new(48, 29.7, 80), CFrame = BOUNDS_CF, Transparency = 1, CanCollide = false }, model)
		-- tout à `offset` près
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Name ~= "Header" then
				d.CFrame = CFrame.new(offset) * d.CFrame
			end
		end
	end
	return res
end

local P1 = plot("PLOT_Shop_01", Vector3.zero, "Plot_1", true)
P1.model:SetAttribute("OwnerUserId", 1)
P1.model.Parent = map
addTag(P1.model, "PlayerPlot")
-- Centre de la vitre fermée = centre de la façade (lu dans Studio : Bounds local (0, -9,3, -39,5)).
local EXPECT1 = Vector3.new(-66.5, 5.85, -88.5)

-- Magasin PNJ : vitre Part, plus un HealthBarPoint qui doit être ignoré (rien ne change pour un magasin PNJ).
local store = new("Model", { Name = "STORE_Z1_Superette" })
store.WorldPivot = CFrame.new(74, 0, 50)
local storeWindow = new("Part", { Name = "Window", Size = Vector3.new(12, 7, 0.4), CFrame = CFrame.new(74, 6.15, 54.75) }, store)
storeWindow:SetAttribute("WindowId", "STORE_Z1_Superette")
storeWindow:SetAttribute("MaxHP", 27)
storeWindow:SetAttribute("Broken", false)
local storeBounds = new("Part", { Name = "Bounds", Size = Vector3.new(14, 8, 16), CFrame = CFrame.new(74, 4, 46), Transparency = 1, CanCollide = false }, store)
new("Attachment", { Name = "HealthBarPoint", Position = Vector3.new(0, 10, 0) }, storeBounds)
store:SetAttribute("Zone", 1)
store.Parent = map
addTag(store, "NPCStore")

local function addPlayer(name, id, position)
	local player = new("Player", { Name = name, UserId = id }, Players)
	local model = new("Model", { Name = name })
	new("Part", { Name = "HumanoidRootPart", Size = Vector3.new(2, 2, 1), CFrame = CFrame.new(position) }, model)
	new("Humanoid", {}, model)
	model.Parent = Workspace
	player.Character = model
	return player
end
LOCAL = addPlayer("Ironix", 1, Vector3.new(300, 3, 300)) -- loin de tout : barres cachées tant que la vitre est pleine
Players.LocalPlayer = LOCAL
new("PlayerGui", { Name = "PlayerGui" }, LOCAL)
local playerGui = LOCAL.PlayerGui
local root = LOCAL.Character.HumanoidRootPart

local function gui(id)
	return playerGui:FindFirstChild("BB_WindowHP_" .. id)
end
local function worldOf(adornee)
	if adornee == nil then
		return nil
	end
	if adornee:IsA("Attachment") then
		return adornee.WorldPosition
	end
	return adornee.Position
end
local function close(a, b, eps)
	return a ~= nil and b ~= nil and (a - b).Magnitude <= (eps or 1e-3)
end
local function terrainPoints()
	local n = 0
	for _, c in terrain:GetChildren() do
		if c:IsA("Attachment") then
			n += 1
		end
	end
	return n
end

---------------------------------------------------------------- démarrage
print("\n== Démarrage : WindowController (client)")
local WC = requireModule(MODULES["client/Controllers/WindowController.luau"], "client")
local Shatter = requireModule(MODULES["shared/Config/Shatter.luau"], "client")
WC.Init()
taskLib.spawn(WC.Start)
step(0.5)

print("\n== A. Parcelle sans HealthBarPoint : point fixe à nous, au centre de la façade")
local g1 = gui("Plot_1")
check(g1 ~= nil, "barre de la parcelle créée")
local a1 = g1 and g1.Adornee
check(a1 ~= nil and a1:IsA("Attachment") and a1.Parent == terrain, "accrochée à un Attachment de Workspace.Terrain (plus à Leaf_L.Glass)")
check(a1 ~= P1.glassL and not (a1 and a1:IsDescendantOf(P1.model)), "rien n'est accroché ni posé dans le modèle de Clément")
check(close(worldOf(a1), EXPECT1), `point au centre de la façade, hauteur du centre de la vitre : {worldOf(a1)} (attendu {EXPECT1})`)
check(a1 ~= nil and a1.Name == "BB_WindowHP_Plot_1", "point nommé comme la barre (BB_WindowHP_Plot_1)")
check(g1 ~= nil and g1.StudsOffset == OFFSET and g1.Size == SIZE and g1.MaxDistance == 80 and g1.AlwaysOnTop == true, "taille, décalage, portée du modèle de Clément gardés")
check(g1 ~= nil and g1.Enabled == false, "cachée loin de la vitre pleine (comme avant)")
check(terrainPoints() == 1, "un seul point posé dans Terrain")

print("\n== B. La vitre bouge (vantaux qui coulissent, puis tout le Model Window déplacé)")
local right = P1.model:GetPivot().RightVector
P1.leafL:PivotTo(P1.leafL:GetPivot() + right * -5.7)
P1.leafR:PivotTo(P1.leafR:GetPivot() + right * 5.7)
step(0.5)
check(g1.Adornee == a1 and close(worldOf(g1.Adornee), EXPECT1), "vantaux ouverts : même Adornee, même place")
P1.window:PivotTo(P1.window:GetPivot() * CFrame.new(3, 2, -4))
step(0.5)
check(g1.Adornee == a1 and close(worldOf(g1.Adornee), EXPECT1), "pivot du Model Window déplacé : même Adornee, même place")
P1.window:PivotTo(P1.window:GetPivot() * CFrame.new(-3, -2, 4))
P1.leafL:PivotTo(P1.leafL:GetPivot() + right * 5.7)
P1.leafR:PivotTo(P1.leafR:GetPivot() + right * -5.7)
root.CFrame = CFrame.new(-60, 3, -88.5) -- devant la porte (à 6 studs de la vitre)
step(0.5)
check(g1.Enabled == true, `visible près de la vitre (moins de {Shatter.HPBar.ShowDistance} studs, distance mesurée à la vitre)`)
check(g1.Label.Text == "100 / 100", `texte des PV : {g1.Label.Text}`)

print("\n== C. Cachée quand la vitre est cassée ou la parcelle libre")
P1.window:SetAttribute("Broken", true)
step(0.3)
check(g1.Enabled == false, "vitre cassée : cachée")
P1.window:SetAttribute("Broken", false)
step(0.3)
check(g1.Enabled == true and g1.Adornee == a1, "vitre refaite : revisible, même point")
P1.window:SetAttribute("MaxHP", 0)
step(0.3)
check(g1.Enabled == false, "parcelle libre (MaxHP = 0) : cachée")
P1.window:SetAttribute("MaxHP", 100)
step(0.3)

print("\n== D. HealthBarPoint livré par Clément : il passe devant")
local hbp = new("Attachment", { Name = "HealthBarPoint", Position = Vector3.new(0, -8, -40) }, P1.bounds)
step(0.3)
check(g1.Adornee == hbp, "barre accrochée à HealthBarPoint (enfant de Bounds)")
check(g1.StudsOffset == OFFSET, "décalage du modèle gardé (il s'ajoute au point)")
P1.window:PivotTo(P1.window:GetPivot() * CFrame.new(0, 0, 3))
step(0.3)
check(g1.Adornee == hbp, "la vitre bouge : toujours HealthBarPoint")
P1.window:PivotTo(P1.window:GetPivot() * CFrame.new(0, 0, -3))
hbp.Parent = nil
step(0.3)
check(g1.Adornee == a1 and close(worldOf(a1), EXPECT1), "HealthBarPoint retiré : retour au point fixe à nous, même place")
check(terrainPoints() == 1, "toujours un seul point dans Terrain")

print("\n== E. Magasin PNJ : rien ne change")
local gs = gui("STORE_Z1_Superette")
check(gs ~= nil and gs.Adornee == storeWindow, "barre du magasin PNJ accrochée à sa vitre (HealthBarPoint du magasin ignoré)")
check(gs.StudsOffset == OFFSET and gs.Size == SIZE, "taille et décalage du modèle")
storeWindow.CFrame = storeWindow.CFrame + Vector3.new(0, 0, 1)
step(0.3)
check(gs.Adornee == storeWindow, "vitre déplacée : toujours la vitre")
root.CFrame = CFrame.new(74, 3, 60)
step(0.3)
check(gs.Enabled == true, "visible près de la vitre")
root.CFrame = CFrame.new(300, 3, 300)
step(0.3)
check(gs.Enabled == false, "cachée loin de la vitre pleine")

print("\n== F. Parcelle qui arrive en streaming (pièces en retard)")
local OFF2 = Vector3.new(0, 0, 200)
local P2 = plot("PLOT_Shop_02", OFF2, "Plot_2", false)
P2.model.Parent = map
addTag(P2.model, "PlayerPlot")
step(0.3)
check(gui("Plot_2") == nil and terrainPoints() == 1, "Model Window sans pièce ni Bounds : pas encore de barre, aucun point posé")
local _, glass2 = leaf(P2.window, "Leaf_L", -93)
glass2.CFrame = CFrame.new(OFF2) * glass2.CFrame
for _, d in P2.window.Leaf_L:GetChildren() do
	if d ~= glass2 then
		d.CFrame = CFrame.new(OFF2) * d.CFrame
	end
end
P2.window.PrimaryPart = glass2
step(0.3)
local g2 = gui("Plot_2")
check(g2 ~= nil and g2.Adornee == glass2, "un vantail arrivé, Bounds pas encore : barre à la vitre en attendant (comme avant)")
local bounds2 = new("Part", { Name = "Bounds", Size = Vector3.new(48, 29.7, 80), CFrame = CFrame.new(OFF2) * BOUNDS_CF, Transparency = 1, CanCollide = false })
bounds2.Parent = P2.model
step(0.3)
local a2 = g2 and g2.Adornee
check(a2 ~= nil and a2:IsA("Attachment") and a2.Parent == terrain, "Bounds arrivé : raccrochée au point fixe")
check(close(worldOf(a2), EXPECT1 + OFF2), `un seul vantail là : point quand même au centre de la façade ({worldOf(a2)})`)
local r2 = leaf(P2.window, "Leaf_R", -84)
for _, d in r2:GetChildren() do
	d.CFrame = CFrame.new(OFF2) * d.CFrame
end
step(0.3)
check(g2.Adornee == a2 and close(worldOf(a2), EXPECT1 + OFF2), "second vantail arrivé : point inchangé")
-- HealthBarPoint qui arrive avec une pièce en retard (Attachment déjà dans la pièce)
local carrier = new("Part", { Name = "BarCarrier", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(OFF2) * CFrame.new(-66, 18, -88.5) })
local hbp2 = new("Attachment", { Name = "HealthBarPoint" }, carrier)
carrier.Parent = P2.model
step(0.3)
check(g2.Adornee == hbp2, "HealthBarPoint arrivé avec sa pièce en retard : il passe devant")
check(terrainPoints() == 2, "points dans Terrain : un par parcelle")

print("\n== G. Parcelle qui sort du streaming : barre et point retirés")
CollectionServiceStub:RemoveTag(P2.model, "PlayerPlot")
step(0.3)
check(gui("Plot_2") == nil, "barre de Plot_2 retirée")
check(terrainPoints() == 1, "point de Plot_2 retiré de Terrain")
addTag(P2.model, "PlayerPlot")
step(0.3)
local g2b = gui("Plot_2")
check(g2b ~= nil and g2b.Adornee == hbp2, "retour de la parcelle : barre recréée, à HealthBarPoint")
hbp2.Parent = nil
step(0.3)
check(g2b.Adornee ~= nil and g2b.Adornee:IsA("Attachment") and g2b.Adornee.Parent == terrain and close(worldOf(g2b.Adornee), EXPECT1 + OFF2), "sans HealthBarPoint : nouveau point fixe au même endroit")

print("\n== Sortie")
local warnsOut = 0
for _, line in LOG do
	if line.kind == "WARN" then
		warnsOut += 1
		print("    " .. line.text)
	end
end
check(warnsOut == 0, "aucun avertissement")
summary()
