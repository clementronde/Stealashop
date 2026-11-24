--!nocheck
-- Scénarios a47 (L-082 point 2, L-086 point 3) : les rayons de présentoirs apparaissent avec les achats.
-- Vrais : RayonService, UpgradeController (côté client), Shared (Config, Contract, Format). Bouchons :
-- DataService (FAKE_DATA), PlotService (attribution et départ pilotés par le banc), Net (BuyItem noté).
--   R1 parcelles libres : Rayon_01 seul ; tout ce qui est caché l'est bien (pièces, Decal, Texture,
--      SurfaceGui, BillboardGui, lumières, particules, Beam, Highlight) ; ProximityPrompt et
--      ClickDetector de Clément, présentoir bonus 21 et sol de la parcelle intacts
--   R2 présentoirs d'un rayon caché toujours trouvables (Find.path, dans le Workspace, même parent)
--   R3 attribution à 4 présentoirs, puis achats : 5 (Rayon_02 apparaît), 9, 20, au-delà de 20
--   R4 restauration exacte (valeurs de départ inhabituelles de Rayon_03, toute la parcelle à 20)
--   R5 contrôle de sécurité : niveau changé sans attribut, rattrapé en 1 s
--   R6 ajouté pendant qu'il est caché : caché, puis rendu à sa valeur
--   R7 départ du joueur : Rayon_01 seul ; l'autre parcelle jamais touchée
--   R8 arrivée avec un niveau déjà acheté (13 présentoirs) ; profil absent = 4
--   R9 premier présentoir lu dans le rayon (rangement différent) ; parcelle sans rayon
--   U1 invite « Unlock stand » (UpgradeController) : sur le prochain présentoir verrouillé, même
--      dans un rayon caché, active et dans le Workspace ; achat envoyé ; puis déplacée ; disparue à 20

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

-- Net : seul BuyItem sert (UpgradeController).
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
local DataModule = moduleScript(Services, "DataService", "stub/DataService.luau")
local PlotModule = moduleScript(Services, "PlotService", "stub/PlotService.luau")
moduleScript(Services, "ShopStageService", "server/Services/ShopStageService.luau") -- ajout a83 (L-096)
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
local function part(name, parent, x, z)
	local p = new("Part", name, parent)
	p.Anchored = true
	p.CFrame = CFrame.new(x or 0, 2, z or 0)
	return p
end

-- Une boutique comme celle de Clément (wave16-studio.md) : 5 rayons de 4 présentoirs, décor varié.
local function buildPlot(name, x0)
	local plot = new("Model", name, nil)
	local floor = part("PlotFloor", plot, x0, 0)
	floor.Size = Vector3.new(60, 1, 60)
	for k = 1, 5 do
		local rayon = new("Model", string.format("Rayon_%02d", k), plot)
		local kick = part("Kick_L", rayon, x0, k * 9)
		new("Decal", "Logo", kick)
		local board = part("Board_L", rayon, x0, k * 9)
		new("Texture", "Wood", board)
		new("SurfaceGui", "PriceGui", board)
		new("PointLight", "Glow", board)
		new("ParticleEmitter", "Sparkle", board)
		new("Beam", "Shine", board)
		new("Highlight", "Edge", rayon)
		new("BillboardGui", "Tag", board)
		local mesh = new("MeshPart", "Prod_L_P1", rayon)
		mesh.CFrame = CFrame.new(x0, 3, k * 9)
		for i = 4 * k - 3, 4 * k do
			local stand = new("Model", string.format("DisplayStand_%02d", i), rayon)
			local top = part("Top", stand, x0 + i, k * 9)
			local slot = new("Attachment", string.format("DisplaySlot_%02d", i), top)
			slot.CFrame = CFrame.new(0, 1, 0)
		end
	end
	-- Rayon_03 : valeurs de départ inhabituelles, à rendre à l'identique.
	local r3 = plot:FindFirstChild("Rayon_03")
	local odd = part("Band_FL", r3, x0, 27)
	odd.Transparency = 0.3
	odd.CanCollide = false
	odd.CanTouch = false
	odd.CanQuery = true
	local d = new("Decal", "Faded", odd)
	d.Transparency = 0.5
	local g = new("SurfaceGui", "OffGui", odd)
	g.Enabled = false
	local e = new("ParticleEmitter", "OffFx", odd)
	e.Enabled = false
	-- ProximityPrompt et ClickDetector posés dans le modèle : jamais touchés.
	new("ProximityPrompt", "ModelPrompt", odd)
	new("ClickDetector", "Click", odd)
	-- Présentoir bonus du gamepass, hors rayon (L-066).
	local bonus = part("DisplayStand_21", plot, x0 + 30, 50)
	new("Attachment", "DisplaySlot_21", bonus)
	plot.Parent = Workspace
	addTag(plot, "PlayerPlot")
	plot:SetAttribute("OwnerUserId", 0)
	return plot
end

local WATCHED = {
	BasePart = { "Transparency", "CanCollide", "CanTouch", "CanQuery" },
	Decal = { "Transparency" },
	Texture = { "Transparency" },
	SurfaceGui = { "Enabled" },
	BillboardGui = { "Enabled" },
	PointLight = { "Enabled" },
	ParticleEmitter = { "Enabled" },
	Beam = { "Enabled" },
	Highlight = { "Enabled" },
	ProximityPrompt = { "Enabled" },
	ClickDetector = { "MaxActivationDistance" },
}
local function propsOf(inst)
	local list = if inst:IsA("BasePart") then WATCHED.BasePart else WATCHED[inst.ClassName]
	if list == nil then
		return nil
	end
	local out = {}
	for _, p in list do
		out[p] = inst[p]
	end
	return out
end
local function snapshot(root)
	local snap = {}
	for _, d in root:GetDescendants() do
		local p = propsOf(d)
		if p then
			snap[d] = p
		end
	end
	return snap
end
local function sameAs(snap, root)
	local count = 0
	for inst, props in snap do
		for k, v in props do
			if inst[k] ~= v then
				print(`    diff {inst:GetFullName()}.{k} : {tostring(inst[k])} au lieu de {tostring(v)}`)
				return false
			end
		end
		count += 1
	end
	return count > 0
end
-- Un rayon est vu « caché » si toutes ses pièces et effets le sont, « montré » s'il est comme au départ.
local function isHidden(rayon)
	for _, d in rayon:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Transparency ~= 1 or d.CanCollide or d.CanTouch or d.CanQuery then
				return false
			end
		elseif d:IsA("Decal") then
			if d.Transparency ~= 1 then
				return false
			end
		elseif WATCHED[d.ClassName] and WATCHED[d.ClassName][1] == "Enabled" and d.ClassName ~= "ProximityPrompt" then
			if d.Enabled then
				return false
			end
		end
	end
	return true
end
local function shownPattern(plot)
	local out = {}
	for k = 1, 5 do
		local rayon = plot:FindFirstChild(string.format("Rayon_%02d", k))
		out[k] = if isHidden(rayon) then "-" else "X"
	end
	return table.concat(out)
end

local plot1 = buildPlot("PLOT_Shop_01", 0)
local plot2 = buildPlot("PLOT_Shop_02", 200)
local initial1 = snapshot(plot1)
local initial2 = snapshot(plot2)
local rayon3Initial = snapshot(plot1:FindFirstChild("Rayon_03"))

local PlotService = requireModule(PlotModule, "server")
PlotService.Plots = { plot1, plot2 }
local Find = requireModule(Shared.Contract.Find, "server")
local RayonService = requireModule(RayonModule, "server")
taskLib.spawn(RayonService.Start)
advance(0)

---------------------------------------------------------------- R1
print("\nR1 parcelles libres")
check(shownPattern(plot1) == "X----", `parcelle 1 libre : Rayon_01 seul ({shownPattern(plot1)})`)
check(shownPattern(plot2) == "X----", `parcelle 2 libre : Rayon_01 seul ({shownPattern(plot2)})`)
check(RayonService.IsShown(plot1, 1) == true and RayonService.IsShown(plot1, 2) == false, "IsShown : 1 montré, 2 caché")
check(RayonService.IsShown(plot1, 9) == nil, "IsShown : rayon absent → nil")
do
	local r2 = plot1:FindFirstChild("Rayon_02")
	local board = r2:FindFirstChild("Board_L")
	check(board.Transparency == 1 and not board.CanCollide and not board.CanTouch and not board.CanQuery, "pièce cachée : Transparency 1, CanCollide/CanTouch/CanQuery coupés")
	check(r2:FindFirstChild("Logo", true).Transparency == 1, "Decal caché")
	check(board:FindFirstChild("Wood").Transparency == 1, "Texture cachée")
	check(board:FindFirstChild("PriceGui").Enabled == false and board:FindFirstChild("Tag").Enabled == false, "SurfaceGui et BillboardGui coupés")
	check(board:FindFirstChild("Glow").Enabled == false, "lumière coupée")
	check(board:FindFirstChild("Sparkle").Enabled == false and board:FindFirstChild("Shine").Enabled == false, "particules et Beam coupés")
	check(r2:FindFirstChild("Edge").Enabled == false, "Highlight coupé")
	check(r2:FindFirstChild("Prod_L_P1").Transparency == 1, "MeshPart cachée")
	local r3 = plot1:FindFirstChild("Rayon_03")
	check(r3:FindFirstChild("ModelPrompt", true).Enabled == true, "ProximityPrompt du modèle pas touchée")
	check(r3:FindFirstChild("Click", true).MaxActivationDistance == 32, "ClickDetector pas touché")
	local bonus = plot1:FindFirstChild("DisplayStand_21")
	check(bonus.Transparency == 0 and bonus.CanCollide, "présentoir bonus 21 (hors rayon) intact")
	check(plot1:FindFirstChild("PlotFloor").Transparency == 0, "sol de la parcelle intact")
	check(sameAs(snapshot(plot1:FindFirstChild("Rayon_01")), plot1) and isHidden(plot1:FindFirstChild("Rayon_01")) == false, "Rayon_01 intact")
end

---------------------------------------------------------------- R2
print("\nR2 présentoirs d'un rayon caché trouvables")
for _, index in { 5, 8, 9, 16, 17, 20 } do
	local name = string.format("DisplaySlot_%02d", index)
	local slot = Find.path(plot1, name)
	local k = math.ceil(index / 4)
	check(
		slot ~= nil and slot:IsA("Attachment") and slot:IsDescendantOf(Workspace) and slot:IsDescendantOf(plot1:FindFirstChild(string.format("Rayon_%02d", k))),
		`{name} : Attachment trouvé par Find.path, dans le Workspace et dans Rayon_{k}`
	)
end
check(Find.path(plot1, "DisplaySlot_21") ~= nil, "DisplaySlot_21 trouvable")

---------------------------------------------------------------- R3 / R4
print("\nR3 attribution et achats")
local alice = new("Player", "Alice", Players)
rawget(alice, "_props").UserId = 101
FAKE_DATA[alice] = { Upgrades = { Treadmill = 0, Bench = 0, DisplaySlots = 0, UnboxBenches = 0 } }
alice:SetAttribute("DisplaySlotsLevel", 0)
PlotService.Assign(alice, plot1)
advance(0)
check(shownPattern(plot1) == "X----", `4 présentoirs : Rayon_01 seul ({shownPattern(plot1)})`)

local function buy(player, level)
	FAKE_DATA[player].Upgrades.DisplaySlots = level
	player:SetAttribute("DisplaySlotsLevel", level)
end
buy(alice, 1)
check(shownPattern(plot1) == "XX---", `achat → 5 présentoirs : Rayon_02 apparaît tout de suite ({shownPattern(plot1)})`)
check(not isHidden(plot1:FindFirstChild("Rayon_02")), "Rayon_02 plus caché")
do
	local ok = true
	for inst, props in snapshot(plot1:FindFirstChild("Rayon_02")) do
		for k, v in props do
			if initial1[inst][k] ~= v then
				ok = false
			end
		end
	end
	check(ok, "Rayon_02 : chaque propriété = valeur de départ")
end
buy(alice, 4)
check(shownPattern(plot1) == "XX---", `8 présentoirs : 2 rayons ({shownPattern(plot1)})`)
buy(alice, 5)
check(shownPattern(plot1) == "XXX--", `9 présentoirs : 3 rayons ({shownPattern(plot1)})`)
do
	local ok = true
	for inst, props in rayon3Initial do
		for k, v in props do
			if inst[k] ~= v then
				ok = false
				print(`    diff {inst.Name}.{k}`)
			end
		end
	end
	check(ok, "Rayon_03 : valeurs inhabituelles rendues (0,3 ; CanCollide/CanTouch coupés ; Decal 0,5 ; SurfaceGui et particules éteints)")
	local odd = plot1:FindFirstChild("Band_FL", true)
	check(odd.Transparency == 0.3 and odd.CanCollide == false and odd.CanTouch == false and odd.CanQuery == true, "Band_FL exactement 0,3 / false / false / true")
end
buy(alice, 16)
check(shownPattern(plot1) == "XXXXX", `20 présentoirs : 5 rayons ({shownPattern(plot1)})`)
check(sameAs(initial1, plot1), "à 20 : toute la parcelle exactement comme au départ")
buy(alice, 99)
check(shownPattern(plot1) == "XXXXX", "niveau au-delà du max : 20, 5 rayons")
buy(alice, -3)
check(shownPattern(plot1) == "X----", "niveau négatif : compté 0, Rayon_01 seul")

---------------------------------------------------------------- R5
print("\nR5 contrôle de sécurité")
FAKE_DATA[alice].Upgrades.DisplaySlots = 2 -- sans attribut
check(shownPattern(plot1) == "X----", "pas encore vu")
advance(1.1)
check(shownPattern(plot1) == "XX---", `rattrapé en 1 s : 6 présentoirs, 2 rayons ({shownPattern(plot1)})`)

---------------------------------------------------------------- R6
print("\nR6 ajout dans un rayon caché")
local r4 = plot1:FindFirstChild("Rayon_04")
local late = part("LateDecor", nil, 0, 36) -- réglé avant d'entrer dans le rayon, comme un clone
late.Transparency = 0.2
local lateLight = new("PointLight", "LateGlow", late)
late.Parent = r4
check(late.Transparency == 1 and not late.CanCollide and lateLight.Enabled == false, "ajouté pendant qu'il est caché : caché aussi")
buy(alice, 12)
check(shownPattern(plot1) == "XXXX-", `16 présentoirs : 4 rayons ({shownPattern(plot1)})`)
check(late.Transparency == 0.2 and late.CanCollide and late.CanTouch and late.CanQuery and lateLight.Enabled, "rendu à ses valeurs (0,2, collisions, lumière)")
late:Destroy()
buy(alice, 0)
buy(alice, 12)
check(shownPattern(plot1) == "XXXX-", "pièce détruite pendant qu'il est caché : pas d'erreur")

---------------------------------------------------------------- R7
print("\nR7 départ du joueur")
PlotService.Release(alice)
check(shownPattern(plot1) == "X----", `départ : Rayon_01 seul ({shownPattern(plot1)})`)
buy(alice, 16)
check(shownPattern(plot1) == "X----", "un achat après le départ ne touche plus la parcelle")
advance(1.1)
check(shownPattern(plot1) == "X----", "ni le contrôle de sécurité")
check(shownPattern(plot2) == "X----", "parcelle 2 restée libre (Rayon_01 seul)")

---------------------------------------------------------------- R8
print("\nR8 arrivée avec un niveau déjà acheté, profil absent")
local bob = new("Player", "Bob", Players)
rawget(bob, "_props").UserId = 102
FAKE_DATA[bob] = { Upgrades = { Treadmill = 0, Bench = 0, DisplaySlots = 9, UnboxBenches = 0 } }
PlotService.Assign(bob, plot2)
check(shownPattern(plot2) == "XXXX-", `Bob, 13 présentoirs : 4 rayons dès l'arrivée ({shownPattern(plot2)})`)
check(shownPattern(plot1) == "X----", "parcelle 1 pas touchée")
local carl = new("Player", "Carl", Players)
rawget(carl, "_props").UserId = 103
PlotService.Assign(carl, plot1)
check(shownPattern(plot1) == "X----", "profil absent : 4 présentoirs, Rayon_01 seul")
PlotService.Release(carl)
PlotService.Release(bob)
check(shownPattern(plot2) == "X----", "départ de Bob : Rayon_01 seul")

---------------------------------------------------------------- R9
print("\nR9 rangement différent, parcelle sans rayon")
do
	local plot3 = new("Model", "PLOT_Shop_03", Workspace)
	local a = new("Model", "Rayon_01", plot3)
	local b = new("Model", "Rayon_02", plot3)
	for i = 1, 3 do
		new("Attachment", string.format("DisplaySlot_%02d", i), part("Top", a))
	end
	for i = 4, 6 do
		new("Attachment", string.format("DisplaySlot_%02d", i), part("Top", b))
	end
	local c = new("Model", "Rayon_03", plot3) -- décor seul : premier présentoir 9 d'après son nom
	part("Decor", c)
	RayonService.Refresh(plot3)
	check(not isHidden(a) and not isHidden(b) and isHidden(c), "Rayon_02 commence à DisplaySlot_04 : montré à 4 ; Rayon_03 sans présentoir : caché")
	clearLog()
	local plot4 = new("Model", "PLOT_Shop_04", Workspace)
	part("Thing", plot4)
	RayonService.Refresh(plot4)
	check(logHas("aucun Rayon_0k", "WARN") and plot4:FindFirstChild("Thing").Transparency == 0, "parcelle sans rayon : avertissement, rien de caché")
end

---------------------------------------------------------------- U1
print("\nU1 invite « Unlock stand » (UpgradeController, client)")
rawget(Players, "_props").LocalPlayer = alice
CLIENT_PLAYER = alice
buy(alice, 0)
PlotService.Assign(alice, plot1)
local Upgrade = requireModule(UpgradeModule, "client")
taskLib.spawn(Upgrade.Start)
advance(0.1)
local function promptAt(index)
	local slot = Find.path(plot1, string.format("DisplaySlot_%02d", index))
	return slot and slot:FindFirstChild("UpgradePrompt")
end
local function allPrompts()
	local n = 0
	for _, d in plot1:GetDescendants() do
		if d.Name == "UpgradePrompt" then
			n += 1
		end
	end
	return n
end
do
	local prompt = promptAt(5)
	local slot = Find.path(plot1, "DisplaySlot_05")
	check(prompt ~= nil, "4 présentoirs : invite sur DisplaySlot_05")
	check(isHidden(plot1:FindFirstChild("Rayon_02")) and slot.Parent.Transparency == 1, "… qui est dans Rayon_02, caché")
	check(prompt and prompt.Enabled and prompt:IsDescendantOf(Workspace), "… invite active et dans le Workspace (visible : une ProximityPrompt ne dépend pas de la transparence)")
	check(prompt and string.find(prompt.ActionText, "Unlock stand", 1, true) ~= nil and prompt.ObjectText == "Stands 4/20", `… textes « {prompt and prompt.ActionText} » / « {prompt and prompt.ObjectText} »`)
	check(allPrompts() == 1, "une seule invite d'amélioration dans la parcelle")
	check(prompt and prompt.Enabled == true, "le rayon caché n'a pas coupé l'invite (ProximityPrompt jamais touchée)")
	prompt.Triggered:Fire()
	advance(0.1)
	check(BUY_LOG[#BUY_LOG] == "DisplaySlots", "maintien → BuyItem(\"DisplaySlots\")")
end
buy(alice, 1) -- réponse du serveur
advance(0.1)
check(shownPattern(plot1) == "XX---" and promptAt(6) ~= nil and promptAt(5) == nil, "5 présentoirs : Rayon_02 visible, invite déplacée sur DisplaySlot_06")
buy(alice, 4)
advance(0.1)
check(promptAt(9) ~= nil and promptAt(9).Enabled and isHidden(plot1:FindFirstChild("Rayon_03")), "8 présentoirs : invite sur DisplaySlot_09 (Rayon_03 caché), active")
buy(alice, 15)
advance(0.1)
check(promptAt(20) ~= nil and shownPattern(plot1) == "XXXXX", "19 présentoirs : invite sur DisplaySlot_20")
buy(alice, 16)
advance(0.1)
check(allPrompts() == 0, "20 présentoirs : plus d'invite")

---------------------------------------------------------------- R10
print("\nR10 étagères rangées par Clément (PLOT_Shop_Rayons), copiées au déblocage")
do
	local assets = ReplicatedStorage:FindFirstChild("Assets") or folder(ReplicatedStorage, "Assets")
	local plots = assets:FindFirstChild("Plots") or folder(assets, "Plots")
	new("Model", "PLOT_Shop", plots) -- gabarit, pivot à l'origine
	local store = new("Model", "PLOT_Shop_Rayons", plots)
	local stored = new("Model", "Rayon_02", store)
	local kick = part("Kick_L", stored)
	kick.CFrame = CFrame.new(0, 3.75, -13)
	part("CollectPad_05", stored).CFrame = CFrame.new(4, 0.5, -13)
	-- Boutique du hub : pivot déplacé et tourné ; Rayon_01 complet, Rayon_02 = ancre invisible + slots.
	local plot5 = new("Model", "PLOT_Shop_05", Workspace)
	local pivot = CFrame.new(-138, 0, 185) * CFrame.Angles(0, math.pi / 2, 0)
	plot5.WorldPivot = pivot
	local r1 = new("Model", "Rayon_01", plot5)
	for i = 1, 4 do
		new("Attachment", string.format("DisplaySlot_%02d", i), part("Top", r1))
	end
	local r2 = new("Model", "Rayon_02", plot5)
	local anchor = part("RayonAnchor", r2)
	anchor.Transparency = 1
	anchor.CanCollide = false
	for i = 5, 8 do
		new("Attachment", string.format("DisplaySlot_%02d", i), anchor)
	end
	local spots = new("Folder", "RayonSpots", plot5)
	local spot = part("RayonSpot_02", spots)
	addTag(plot5, "PlayerPlot")
	local dan = new("Player", "Dan", Players)
	rawget(dan, "_props").UserId = 104
	FAKE_DATA[dan] = { Upgrades = { Treadmill = 0, Bench = 0, DisplaySlots = 0 } }
	dan:SetAttribute("DisplaySlotsLevel", 0)
	PlotService.Assign(dan, plot5)
	advance(0)
	check(r2:FindFirstChild("RayonVisuals") == nil and spot.Transparency == 0, "4 présentoirs : pas d'étagère copiée, contour RayonSpot_02 visible")
	check(r1:FindFirstChild("RayonVisuals") == nil, "Rayon_01 (rien de rangé) : jamais de copie")
	buy(dan, 1)
	local copy = r2:FindFirstChild("RayonVisuals")
	check(copy ~= nil and copy:IsA("Model"), "5 présentoirs : copie RayonVisuals posée dans Rayon_02")
	local copiedKick = copy and copy:FindFirstChild("Kick_L")
	local want = pivot * CFrame.new(0, 3.75, -13)
	check(copiedKick ~= nil and (copiedKick.Position - want.Position).Magnitude < 1e-3, `… au pivot de la boutique ({copiedKick and tostring(copiedKick.Position)} ; attendu {tostring(want.Position)})`)
	check(copiedKick and copiedKick.Transparency == 0 and copiedKick.CanCollide, "… visible et solide")
	check(copy and copy:FindFirstChild("CollectPad_05") ~= nil, "… avec ses CollectPad")
	check(spot.Transparency == 1 and not spot.CanCollide, "contour RayonSpot_02 caché")
	check(anchor.Transparency == 1 and not anchor.CanCollide, "ancre restée invisible et sans collision")
	check(kick.Parent == stored and kick.CFrame.Position.Z == -13, "modèle rangé intact")
	RayonService.Refresh(plot5)
	advance(1.1)
	local n = 0
	for _, c in r2:GetChildren() do
		if c.Name == "RayonVisuals" then
			n += 1
		end
	end
	check(n == 1, `Refresh et contrôle de sécurité : une seule copie ({n})`)
	buy(dan, 0)
	check(r2:FindFirstChild("RayonVisuals") == nil and spot.Transparency == 0, "retour à 4 : copie retirée, contour revenu")
	buy(dan, 1)
	check(r2:FindFirstChild("RayonVisuals") ~= nil and spot.Transparency == 1, "de nouveau 5 : copie revenue, contour caché")
	PlotService.Release(dan)
	check(r2:FindFirstChild("RayonVisuals") == nil and spot.Transparency == 0, "départ : copie retirée")
end

summary()
