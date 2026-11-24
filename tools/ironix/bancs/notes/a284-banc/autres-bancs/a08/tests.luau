--!nocheck
-- Scénarios : ToolService, WindowService (serveur) et HitController (client), avec le vrai Net.
-- Copie a26 (vague 8, 2026-11-07) : faux AnimationController qui rend une piste quand l'animation
-- est « livrée », et section « Coup au marqueur Impact » (HitWindow part au marqueur, au plus tard
-- après Config.Shatter.Hit.ImpactMaxWait, ou au clic suivant ; jamais deux coups pour un clic).

SOURCES["stub/DataService.luau"] = [[
local DataService = {}
DataService.Priority = 1
local profiles = {}
local listeners = {}
function DataService.Get(player) return profiles[player] end
function DataService.OnProfileLoaded(fn)
	table.insert(listeners, fn)
	for p in profiles do task.spawn(fn, p) end
	return function() end
end
function DataService._load(player, data)
	profiles[player] = data
	for _, fn in listeners do task.spawn(fn, player) end
end
return DataService
]]

-- `delivered[name]` = l'animation est livrée : PlayPlayer rend une piste, la même pour un nom donné
-- (comme AnimPlayer, qui garde ses pistes) ; reach(name, marker) simule le passage d'un marqueur.
SOURCES["stub/AnimationController.luau"] = [[
local A = { Calls = {}, delivered = {}, tracks = {} }
function A.PlayPlayer(name)
	table.insert(A.Calls, name)
	if not A.delivered[name] then return nil end
	local track = A.tracks[name]
	if track == nil then
		track = { Name = name, signals = {} }
		function track.GetMarkerReachedSignal(self, marker)
			self.signals[marker] = self.signals[marker] or newSignal()
			return self.signals[marker]
		end
		A.tracks[name] = track
	end
	return track
end
function A.reach(name, marker)
	local track = A.tracks[name]
	local signal = track and track.signals[marker]
	if signal then signal:Fire("") end
end
function A.StopPlayer(_name) end
function A.OnMarker() return function() end end
return A
]]

---------------------------------------------------------------- arbre
local Shared = folder(ReplicatedStorage, "Shared")
local ConfigF = folder(Shared, "Config")
for _, n in { "Balance", "Bat", "Cosmetics", "DeepFreeze", "Features", "Formulas", "Items", "Night", "PvP", "Rarities", "Shatter", "Tools", "Training", "Tutorial", "Upgrades", "Zones" } do
	moduleScript(ConfigF, n, `shared/Config/{n}.luau`)
end
local ContractF = folder(Shared, "Contract")
for _, n in { "Animations", "Attributes", "Find", "Models", "Tags", "UI" } do
	moduleScript(ContractF, n, `shared/Contract/{n}.luau`)
end
local NetF = folder(Shared, "Net")
for _, n in { "Definitions", "Net", "RateLimiter", "Validate" } do
	moduleScript(NetF, n, `shared/Net/{n}.luau`)
end
moduleScript(folder(Shared, "Types"), "Profile", "shared/Types/Profile.luau")
local LoaderModule = moduleScript(Shared, "Loader", "shared/Loader.luau")
moduleScript(Shared, "SafeZone", "shared/SafeZone.luau") -- a157 (2026-11-14) : zone safe, lue par WindowService, ajout pur (reporté par le petit chef dans la copie a159, 2026-11-15)

local Assets = folder(ReplicatedStorage, "Assets")
local ToolsF = folder(Assets, "Tools")
local function part(class, name, parent)
	local p = InstanceAPI.new(class)
	p.Name = name
	p.Parent = parent
	return p
end
-- TOOL_Marteau livré en Model : Handle (MeshPart) + tête non soudée + HitPoint + un script à retirer
local marteau = part("Model", "TOOL_Marteau", ToolsF)
local mHandle = part("MeshPart", "Handle", marteau)
mHandle.Anchored = true
local mHead = part("Part", "Head", marteau)
mHead.Anchored = true
part("Attachment", "HitPoint", mHead)
part("Script", "Junk", marteau)
-- TOOL_Masse livré sans Handle : poignée grise + avertissement
part("Part", "Body", part("Model", "TOOL_Masse", ToolsF))

local Services = folder(folder(ServerScriptService, "Server"), "Services")
moduleScript(Services, "DataService", "stub/DataService.luau")
moduleScript(Services, "ToolService", "server/Services/ToolService.luau")
moduleScript(Services, "WindowService", "server/Services/WindowService.luau")
local Controllers = folder(folder(StarterPlayerScripts, "Client"), "Controllers")
moduleScript(Controllers, "HitController", "client/Controllers/HitController.luau")
local AnimModule = moduleScript(Controllers, "AnimationController", "stub/AnimationController.luau")

-- Map : magasins et parcelles
local function windowPart(parent, name, cframe, size)
	local w = part("Part", name, parent)
	w.CFrame = cframe
	w.Size = size
	w.Transparency = 0.5
	w.Anchored = true
	return w
end
local function store(name, zone)
	local m = InstanceAPI.new("Model")
	m.Name = name
	if zone then
		m:SetAttribute("Zone", zone)
	end
	return m
end
local superette = store("STORE_Z1_Superette", 1)
local superetteWin = windowPart(superette, "Window", CFrame.new(60, 3.5, 20.5), Vector3.new(8, 6, 0.4))
local kiosque = store("STORE_Z1_Kiosque", 1)
local kiosqueWin = windowPart(kiosque, "Window", CFrame.new(60, 0, -34) * CFrame.Angles(0, math.pi, 0) * CFrame.new(0, 3.5, -13.5), Vector3.new(8, 6, 0.4))
local elec = store("STORE_Z3_Electronique", 3)
local elecWin = part("Model", "Window", elec)
local elecGlass = windowPart(elecWin, "Glass", CFrame.new(240, 4, 20.5), Vector3.new(12, 7, 0.4))
local elecFrame = windowPart(elecWin, "Frame", CFrame.new(240, 7.7, 20.5), Vector3.new(12.4, 0.4, 0.6))
elecFrame.Transparency = 0
local bad = store("STORE_Bad", 9)
windowPart(bad, "Window", CFrame.new(900, 3, 0), Vector3.new(8, 6, 0.4))
local noWin = store("STORE_NoWindow", 2)
for _, m in { superette, kiosque, elec, bad, noWin } do
	m.Parent = Workspace
	addTag(m, "NPCStore")
end
local function plot(index, x)
	local m = InstanceAPI.new("Model")
	m.Name = string.format("PLOT_Greybox_%02d", index)
	m:SetAttribute("PlotIndex", index)
	local w = windowPart(m, "Window", CFrame.new(x, 4, 50), Vector3.new(12, 7, 0.4))
	m.Parent = Workspace
	addTag(m, "PlayerPlot")
	return m, w
end
local plot1, plot1Win = plot(1, -200)
local plot2, plot2Win = plot(2, -120)
-- Modèles taggés hors de la map : gabarit rangé dans Assets, livraison dans _INBOX_CLEMENT
local template = store("STORE_Z1_Superette", 1)
windowPart(template, "Window", CFrame.new(0, 0, 0), Vector3.new(8, 6, 0.4))
template.Parent = Assets
addTag(template, "NPCStore")
local inbox = folder(Workspace, "_INBOX_CLEMENT")
local delivered = store("STORE_Z1_Superette", 1)
local deliveredWin = windowPart(delivered, "Window", CFrame.new(0, 0, 0), Vector3.new(8, 6, 0.4))
delivered.Parent = inbox
addTag(delivered, "NPCStore")

---------------------------------------------------------------- joueurs
local function newProfile()
	return {
		Version = 1,
		Cash = 0,
		Stats = { Speed = 0, Strength = 0 },
		Upgrades = { Treadmill = 0, Bench = 0, DisplaySlots = 0, UnboxBenches = 0 },
		Tools = { Owned = { "Fists" }, Equipped = "Fists" },
	}
end
local function addPlayer(name, userId)
	local p = InstanceAPI.new("Player")
	p.Name = name
	p.UserId = userId
	p.Parent = Players
	Players.PlayerAdded:Fire(p)
	return p
end
local function spawnCharacter(player)
	local old = player.Character
	if old then
		old:Destroy()
	end
	local oldBackpack = player:FindFirstChildOfClass("Backpack")
	if oldBackpack then
		oldBackpack:Destroy()
	end
	part("Backpack", "Backpack", player)
	local char = InstanceAPI.new("Model")
	char.Name = player.Name
	part("Humanoid", "Humanoid", char)
	part("Part", "HumanoidRootPart", char)
	player.Character = char
	player.CharacterAdded:Fire(char)
	char.Parent = Workspace
	return char
end
-- Place le joueur en `pos`, regard (à plat) vers `target`.
local function place(player, pos, target)
	local d = target - pos
	player.Character.HumanoidRootPart.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.atan2(-d.X, -d.Z), 0)
end
-- a30 (vague 10) : les outils de casse seulement ; la batte (attribut BatTool, slot 2), donnée à
-- côté par ToolService, est comptée à part (batsOf).
local function toolsOf(player)
	local out = {}
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		if container then
			for _, c in container:GetChildren() do
				if c:IsA("Tool") and c:GetAttribute("BatTool") ~= true then
					table.insert(out, c)
				end
			end
		end
	end
	return out
end
local function batsOf(player)
	local out = {}
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		if container then
			for _, c in container:GetChildren() do
				if c:IsA("Tool") and c:GetAttribute("BatTool") == true then
					table.insert(out, c)
				end
			end
		end
	end
	return out
end
local function equip(player)
	local tool = toolsOf(player)[1]
	tool.Parent = player.Character
	return tool
end
local function lastHP(id)
	local list = remotes("WindowHP", id)
	local e = list[#list]
	if e then
		return e.args[2], e.args[3], #list
	end
	return nil, nil, 0
end

---------------------------------------------------------------- démarrage serveur
print("== Démarrage du serveur (vrai Loader)")
local Loader = requireModule(LoaderModule, "server")
Loader.start(Services, "Serveur")
advance(0)
local DS = requireModule(Services.DataService, "server")
local TS = requireModule(Services.ToolService, "server")
local WS = requireModule(Services.WindowService, "server")
local Remotes = ReplicatedStorage.Remotes
local function hit(player, id)
	Remotes.HitWindow.OnServerEvent:Fire(player, id)
end
check(logHas("[Loader Serveur] 3 module(s) démarré(s)"), "Loader : 3 services démarrés")
check(logHas("[WindowService] 5 vitrine(s) prête(s) : 3 de magasins PNJ, 2 de parcelles"), "5 vitrines enregistrées (3 magasins, 2 parcelles)")
check(logHas("STORE_Bad : attribut Zone invalide (9)", "WARN"), "Zone 9 refusée avec un avertissement")
check(logHas("STORE_NoWindow : pas de vitrine", "WARN"), "magasin sans Window signalé")
check(superetteWin:GetAttribute("WindowId") == "STORE_Z1_Superette", "WindowId du magasin = nom du modèle")
check(plot1Win:GetAttribute("WindowId") == "Plot_1", "WindowId de parcelle = Plot_<PlotIndex>")
check(elecWin:GetAttribute("WindowId") == "STORE_Z3_Electronique" and elecWin:GetAttribute("MaxHP") == 3264, "vitre en Model : id et PV max zone 3 (3 264, v2)")
check(superetteWin:GetAttribute("MaxHP") == 27 and superetteWin:GetAttribute("Broken") == false, "PV max zone 1 = 27 (v2), Broken = false")
check(plot1Win:GetAttribute("MaxHP") == 0, "parcelle libre : MaxHP = 0 (incassable)")
check(WS.GetWindowId(superette) == "STORE_Z1_Superette" and WS.GetWindowId(plot2) == "Plot_2", "GetWindowId")
check(WS.GetWindowId(template) == nil and WS.GetWindowId(delivered) == nil and deliveredWin:GetAttribute("WindowId") == nil, "gabarit dans Assets et livraison dans l'inbox ignorés")

---------------------------------------------------------------- ToolService
print("== ToolService")
local P1 = addPlayer("Alice", 101)
spawnCharacter(P1)
advance(0.05)
check(#toolsOf(P1) == 0 and #batsOf(P1) == 0, "pas d'outil ni de batte tant que le profil n'est pas chargé")
local d1 = newProfile()
DS._load(P1, d1)
advance(0.05)
local tools = toolsOf(P1)
check(#tools == 1 and tools[1].Name == "Fists" and tools[1]:GetAttribute("ToolId") == "Fists", "Poings donnés au chargement du profil")
-- a30 : la batte, après les poings dans le Backpack (slot 2), sans ToolId.
local bats = batsOf(P1)
local backpackList = P1:FindFirstChildOfClass("Backpack"):GetChildren()
check(#bats == 1 and bats[1]:GetAttribute("ToolId") == nil and backpackList[1] == tools[1] and backpackList[2] == bats[1], "a30 : batte donnée après les poings (slot 2), sans ToolId")
check(tools[1].RequiresHandle == false and tools[1].CanBeDropped == false, "poings : sans poignée, pas lâchables")
check(TS.GetHitDamage(P1) == 1, "dégâts poings, Force 0 = 1")
d1.Stats.Strength = 100
check(TS.GetHitDamage(P1) == 1, "a134 : Force 100 sans effet (dégâts = arme × aura)")
d1.Stats.Strength = 0
-- Copie a134 : la Force ne compte plus dans le jeu. Les scénarios de ce banc s'en servaient comme levier de
-- dégâts (« d1.Stats.Strength = 3400 ») : ici, ce levier passe par l'accroche de l'aura, avec les mêmes nombres.
local function a134Aura(player)
	local data = DS.Get(player)
	return if data then 1 + data.Stats.Strength / 100 else 1
end
TS.GetAuraMultiplier = a134Aura
check(TS.Equip(P1, "Hammer") == false and TS.Grant(P1, "Inconnu") == false, "Equip non possédé / Grant inconnu refusés")
check(TS.GetEquippedId(P1) == "Fists" and TS.Owns(P1, "Hammer") == false, "GetEquippedId, Owns")
d1.Tools.Equipped = "Disqueuse?"
check(TS.GetEquippedId(P1) == "Fists" and TS.GetHitDamage(P1) == 1, "outil enregistré inconnu = poings")
d1.Tools.Equipped = "Fists"
check(TS.IsHoldingTool(P1) == false, "IsHoldingTool : dans le Backpack = false")

---------------------------------------------------------------- coups
print("== HitWindow : validations")
local SUP = "STORE_Z1_Superette"
place(P1, Vector3.new(60, 3, 14), Vector3.new(60, 3, 20.5))
hit(P1, SUP)
advance(0.15)
check(lastHP(SUP) == nil, "outil pas en main : aucun dégât")
check(logHas("outil de casse pas en main", "WARN"), "refus signalé en Studio (outil)")
equip(P1)
check(TS.IsHoldingTool(P1), "IsHoldingTool : en main = true")
hit(P1, SUP)
advance(0.1)
local hp, maxHp = lastHP(SUP)
check(hp ~= nil and near(hp, 26 + 0.081, 0.02) and maxHp == 27, `un coup de poing : 27 → 26, + régénération (reçu {hp})`)
advance(2) -- a134 : 0,81 PV/s (27 PV), il faut plus d'une seconde pour revenir aux PV max
place(P1, Vector3.new(60, 3, 5), Vector3.new(60, 3, 20.5))
clearLog()
local _, _, countBefore = lastHP(SUP)
hit(P1, SUP)
advance(0.1)
check(logHas("trop loin (15.3 studs)", "WARN"), "à 15,3 studs : refusé")
hit(P1, "STORE_Inexistant")
check(logHas("vitrine inconnue", "WARN") == false, "vitrine inconnue : pas de 2e ligne dans la même seconde (anti-spam)")
advance(1.1)
hit(P1, "STORE_Inexistant")
check(logHas("vitrine inconnue", "WARN"), "vitrine inconnue signalée")
check(select(3, lastHP(SUP)) == countBefore, "PV pleins et aucun coup accepté : aucun WindowHP envoyé")

print("== Débit : 15 coups d'un coup, Net en accepte 1 (a134 : 5 coups par seconde, débit régulier)")
place(P1, Vector3.new(60, 3, 14), Vector3.new(60, 3, 20.5))
advance(1.1)
for _ = 1, 15 do
	hit(P1, SUP)
end
advance(0.1)
hp = lastHP(SUP)
check(near(hp, 26 + 0.081, 0.02), `1 coup accepté sur 15 au même instant : 27 → 26 (+ régén) (reçu {hp})`)
check(logHas("RateLimit", "WARN"), "Net signale le dépassement de débit")
-- a134 : 10 coups espacés de 0,2 s (5 par seconde) passent tous ; à 10 par seconde, un sur deux.
advance(1.1)
clearLog()
local a134Count = 0
WS.OnHit(function()
	a134Count += 1
end)
local function a134Hits()
	return a134Count
end
local a134Before = a134Hits()
for _ = 1, 10 do
	hit(P1, SUP)
	advance(0.2)
end
check(a134Hits() - a134Before == 10 and not logHas("RateLimit", "WARN"), `a134 : 10 coups à 5 par seconde, tous acceptés ({a134Hits() - a134Before})`)
advance(1.1)
a134Before = a134Hits()
for _ = 1, 20 do
	hit(P1, SUP)
	advance(0.1)
end
check(a134Hits() - a134Before >= 10 and a134Hits() - a134Before <= 11 and logHas("RateLimit", "WARN"), `a134 : 20 coups à 10 par seconde pendant 2 s, 10 acceptés ({a134Hits() - a134Before})`)
advance(0.1)
local a134Hp = lastHP(SUP)

print("== Régénération et cadence 10 Hz")
local _, _, n0 = lastHP(SUP)
local t0 = now()
advance(1.0)
local _, _, n1 = lastHP(SUP)
check(n1 - n0 >= 1 and n1 - n0 <= 3, `a284 : régénération seule, 2 WindowHP par seconde au plus ({n1 - n0} en 1 s)`)
hp = lastHP(SUP)
check(hp - a134Hp >= 0.81 * 0.5 - 0.03 and hp - a134Hp <= 0.81 * 1.2 + 0.03, `a284 : régénération de 3 %/s, 1 s entre deux lectures chacune au plus 0,5 s en retard (a134Hp lu 0,1 s après le dernier envoi) (+{hp - a134Hp} en 1 s)`)
advance(10)
hp = lastHP(SUP)
check(hp == 27, "remontée jusqu'aux PV max")
local _, _, n2 = lastHP(SUP)
advance(2)
check(select(3, lastHP(SUP)) == n2, "PV pleins : plus aucun envoi")

print("== a284 : coup pendant la régénération, puis régénération à 2 par seconde")
local a284h0, _, a284c0 = lastHP(SUP)
hit(P1, SUP)
advance(0.1)
local a284h1, _, a284c1 = lastHP(SUP)
check(a284c1 == a284c0 + 1 and a284h1 < a284h0, `coup : WindowHP envoyé au tick suivant ({a284c1 - a284c0}, {a284h0} → {a284h1})`)
advance(0.2)
hit(P1, SUP)
advance(0.1)
local a284h2, _, a284c2 = lastHP(SUP)
check(a284c2 == a284c1 + 1 and a284h2 < a284h1, `2e coup 0,3 s plus tard, pendant la régénération : envoyé au tick suivant ({a284c2 - a284c1})`)
advance(2)
local _, _, a284c3 = lastHP(SUP)
check(a284c3 - a284c2 >= 3 and a284c3 - a284c2 <= 5, `2 s de régénération seule : 4 WindowHP environ ({a284c3 - a284c2})`)
advance(8)
check(lastHP(SUP) == 27, "a284 : PV pleins envoyés au retour au plein")
local _, _, a284c4 = lastHP(SUP)
advance(2)
check(select(3, lastHP(SUP)) == a284c4, "a284 : PV pleins, plus aucun envoi")

print("== Casse et reconstruction (magasin PNJ)")
local broken = {}
local rebuilt = {}
WS.OnBroken(function(info)
	table.insert(broken, info)
end)
WS.OnRebuilt(function(id, model)
	table.insert(rebuilt, { id = id, model = model })
end)
d1.Stats.Strength = 4100 -- dégâts 42 : casse en un coup (27 PV)
advance(1.1)
hit(P1, SUP)
local wb = remotes("WindowBroken", SUP)
check(#wb == 1, "WindowBroken envoyé une fois")
check(wb[1] and (wb[1].args[2] - Vector3.new(60, 3, 20.3)).Magnitude < 1e-6, `point d'impact = point de la vitre le plus proche ({wb[1] and wb[1].args[2]})`)
check(superetteWin.Transparency == 1 and superetteWin.CanCollide == false and superetteWin.CanQuery == false, "vitre cachée et traversable")
check(superetteWin:GetAttribute("Broken") == true and WS.IsBroken(SUP), "Broken = true, IsBroken")
check(#broken == 1 and broken[1].Breaker == P1 and broken[1].Kind == "NPC" and broken[1].Model == superette, "OnBroken : casseur, type, modèle")
advance(0.1)
check(lastHP(SUP) == 0, "WindowHP : 0 après la casse")
hit(P1, SUP)
check(#remotes("WindowBroken", SUP) == 1, "coup sur vitrine cassée ignoré")
local BAL135 = requireModule(ConfigF.Balance, "server") -- a135 : chrono HEIST (Balance.Heist.Duration, 6 s depuis la vague 40) + RebuildDelay
local REBUILD135 = BAL135.Heist.Duration + BAL135.Window.RebuildDelay
advance(REBUILD135 - 0.5)
check(WS.IsBroken(SUP), "toujours cassée 0,4 s avant la reconstruction (Heist.Duration + RebuildDelay)")
advance(0.5)
check(not WS.IsBroken(SUP) and #rebuilt == 1 and rebuilt[1].id == SUP, "reconstruite à Heist.Duration + RebuildDelay, OnRebuilt")
check(superetteWin.Transparency == 0.5 and superetteWin.CanCollide == true and superetteWin.CanQuery == true, "vitre restaurée (transparence d'origine, collisions)")
check(superetteWin:GetAttribute("Broken") == false, "Broken = false")
advance(0.1)
check(lastHP(SUP) == 27, "WindowHP : PV pleins après reconstruction")

print("== Magasin tourné (Kiosque) et vitre en Model")
d1.Stats.Strength = 0
place(P1, Vector3.new(60, 3, -14), Vector3.new(60, 3, -20.5))
advance(1.1)
hit(P1, "STORE_Z1_Kiosque")
advance(0.1)
check(near(lastHP("STORE_Z1_Kiosque"), 26.081, 0.02), "magasin tourné à 180° : coup accepté à 6,3 studs")
d1.Stats.Strength = 500000 -- dégâts 5 001 (3 264 PV)
place(P1, Vector3.new(240, 3, 14), Vector3.new(240, 3, 20.5))
advance(1.1)
hit(P1, "STORE_Z3_Electronique")
check(WS.IsBroken("STORE_Z3_Electronique") and elecGlass.Transparency == 1 and elecFrame.Transparency == 1, "vitre en Model : toutes ses pièces cachées")
check(WS.Rebuild("STORE_Z3_Electronique") and elecGlass.Transparency == 0.5 and elecFrame.Transparency == 0 and elecFrame.CanCollide, "Rebuild immédiat : chaque pièce retrouve son état")
check(WS.Rebuild("STORE_Z3_Electronique") == false, "Rebuild d'une vitrine intacte : false")
advance(31)
check(#rebuilt == 2, "l'ancien délai de reconstruction ne refait rien après un Rebuild manuel")

print("== Parcelles")
local P2 = addPlayer("Bob", 202)
spawnCharacter(P2)
local d2 = newProfile()
DS._load(P2, d2)
advance(0.05)
plot1:SetAttribute("OwnerUserId", 202)
advance(0.1)
check(plot1Win:GetAttribute("MaxHP") == 40, "copie a159 : parcelle de Bob : 40 coups (L-163)")
local p1hp, p1max, p1count = lastHP("Plot_1")
check(p1hp == 40 and p1max == 40 and p1count == 1, "nouveau propriétaire : un WindowHP (40, 40) envoyé")
d1.Stats.Strength = 0
place(P1, Vector3.new(-120, 3, 44), Vector3.new(-120, 3, 50))
advance(1.1)
hit(P1, "Plot_2")
advance(0.1)
check(lastHP("Plot_2") == nil, "parcelle libre : coup ignoré")
equip(P2)
place(P2, Vector3.new(-200, 3, 44), Vector3.new(-200, 3, 50))
hit(P2, "Plot_1")
advance(0.1)
check(select(3, lastHP("Plot_1")) == p1count, "sa propre vitrine : coup ignoré")
place(P1, Vector3.new(-200, 3, 44), Vector3.new(-200, 3, 50))
hit(P1, "Plot_1")
advance(0.1)
hp, maxHp = lastHP("Plot_1")
check(near(hp, 39, 0.02) and maxHp == 40, `Alice frappe la parcelle de Bob : 40 → 39 (pas de réparation moins de 3 s après un coup, L-163) (reçu {hp})`)
check(TS.Grant(P2, "Hammer") and TS.Equip(P2, "Hammer"), "Bob reçoit et équipe le Marteau")
local t2 = toolsOf(P2)
check(#t2 == 1 and t2[1].Name == "Hammer" and t2[1].Parent == P2.Character, "un seul outil, remplacé et remis en main")
check(#batsOf(P2) == 1, "a30 : la batte reste, une seule")
local th = t2[1]
local handle = th:FindFirstChild("Handle")
local head = th:FindFirstChild("Head")
check(handle and handle.ClassName == "MeshPart" and th.RequiresHandle, "Marteau fait du TOOL_Marteau de Clément (Handle MeshPart)")
check(handle.Anchored == false and handle.CanCollide == false and handle.Massless and head.Anchored == false, "pièces non ancrées, sans collision, sans masse")
check(#head:GetJoints() == 1 and head:GetJoints()[1].Part0 == handle, "pièce libre soudée à la poignée")
check(th:FindFirstChild("Junk") == nil, "script retiré du modèle")
check(marteau.Handle.Anchored == true, "le modèle d'origine dans Assets n'est pas modifié")
check(TS.GetHitDamage(P2) == 300, "dégâts Marteau = 300 (v2)")
local hpBefore = lastHP("Plot_1")
advance(0.1)
hp, maxHp = lastHP("Plot_1")
check(maxHp == 40 and plot1Win:GetAttribute("MaxHP") == 40, "copie a159 : 40 coups, quel que soit l'outil")
check(near(hp / maxHp, hpBefore / 40, 0.005), `même fraction de PV gardée ({hp} / {maxHp})`)

print("== Parcelle cassée, changement de propriétaire")
d1.Stats.Strength = 1e7
advance(1.1)
-- copie a159 : la force ne compte plus, 40 coups (plus la réparation de 3 %/s)
local function breakPlot1()
	for _ = 1, 120 do
		hit(P1, "Plot_1")
		if WS.IsBroken("Plot_1") then
			return
		end
		advance(0.21)
	end
end
breakPlot1()
check(WS.IsBroken("Plot_1") and #broken >= 3 and broken[#broken].Kind == "Plot", "parcelle cassée, OnBroken Kind = Plot")
plot1:SetAttribute("OwnerUserId", 0)
check(not WS.IsBroken("Plot_1") and plot1Win:GetAttribute("MaxHP") == 0 and plot1Win.CanCollide, "parcelle libérée : reconstruite tout de suite, incassable")
plot1:SetAttribute("OwnerUserId", 202)
check(plot1Win:GetAttribute("MaxHP") == 40, "nouveau propriétaire : 40 coups (copie a159)")
advance(1.1)
breakPlot1()
check(WS.IsBroken("Plot_1"), "recassée")
advance(29.9)
check(WS.IsBroken("Plot_1"), "parcelle toujours cassée à 29,9 s")
advance(0.2)
check(not WS.IsBroken("Plot_1"), "parcelle reconstruite à 30 s (10 s de vol + 20 s)")

print("== Points d'accroche")
d1.Stats.Strength = 0
place(P1, Vector3.new(60, 3, 14), Vector3.new(60, 3, 20.5))
advance(15)
local _, _, c0 = lastHP(SUP)
WS.CanBeHit = function()
	return false
end
hit(P1, SUP)
advance(0.1)
check(select(3, lastHP(SUP)) == c0, "CanBeHit = false : coup ignoré")
WS.CanBeHit = function()
	error("boum")
end
clearLog()
advance(1.1)
hit(P1, SUP)
advance(0.1)
check(select(3, lastHP(SUP)) == c0 and logHas("CanBeHit : erreur", "WARN"), "CanBeHit qui plante : coup ignoré + avertissement")
WS.CanBeHit = function()
	return true
end
TS.GetAuraMultiplier = function()
	return 2
end
check(TS.GetHitDamage(P1) == 2, "aura ×2")
TS.GetAuraMultiplier = function()
	return 0 / 0
end
check(TS.GetHitDamage(P1) == 1 and logHas("GetAuraMultiplier : erreur ou valeur invalide", "WARN"), "aura NaN : ×1 + avertissement")
TS.GetAuraMultiplier = a134Aura -- copie a134 : le levier de dégâts du banc (voir plus haut)

print("== Réapparition, modèle sans Handle")
spawnCharacter(P1)
advance(0.05)
local after = toolsOf(P1)
check(#after == 1 and after[1].Parent == P1:FindFirstChildOfClass("Backpack") and not TS.IsHoldingTool(P1), "outil rendu dans le nouveau Backpack")
check(TS.Grant(P1, "Sledgehammer") and TS.Equip(P1, "Sledgehammer"), "Masse accordée et équipée")
local masseTool = toolsOf(P1)[1]
check(masseTool.Name == "Sledgehammer" and masseTool.Handle.ClassName == "Part" and masseTool.Handle.Size == Vector3.new(0.4, 0.4, 2.5), "TOOL_Masse sans Handle : poignée grise V0")
check(logHas("TOOL_Masse : pas de pièce « Handle »", "WARN"), "TOOL_Masse sans Handle signalé")
check(#toolsOf(P1) == 1, "toujours un seul outil")

---------------------------------------------------------------- client
print("== HitController (client), avec le vrai Net client")
CLIENT_PLAYER = P1
Players.LocalPlayer = P1
TS.Equip(P1, "Fists")
local ClientLoader = requireModule(LoaderModule, "client")
ClientLoader.start(Controllers, "Client")
advance(0.05)
check(logHas("[Loader Client] 2 module(s) démarré(s)"), "Loader client : HitController + AnimationController")
local Anim = requireModule(AnimModule, "client")
local fists = equip(P1)
place(P1, Vector3.new(60, 3, 14), Vector3.new(60, 3, 20.5))
advance(15)
local _, _, k0 = lastHP(SUP)
fists.Activated:Fire()
fists.Activated:Fire() -- même instant : gardé par le client (≤ 5/s, a134), il part 0,2 s plus tard
advance(0.1)
hp = lastHP(SUP)
check(FIRE_SERVER.HitWindow == 1 and near(hp, 26.081, 0.02), `clic : un seul HitWindow tout de suite pour deux clics simultanés (envoyés : {FIRE_SERVER.HitWindow})`)
check(#Anim.Calls == 1 and Anim.Calls[1] == "HitWindow", "animation HitWindow jouée pour les poings")
fists.Activated:Fire() -- a134 : un troisième clic trop tôt, un seul clic est gardé : ignoré
advance(0.15)
check(FIRE_SERVER.HitWindow == 2 and #Anim.Calls == 2, `a134 : le clic gardé part 0,2 s après le premier, un seul (envoyés : {FIRE_SERVER.HitWindow})`)
advance(0.3)
check(FIRE_SERVER.HitWindow == 2, "a134 : rien d'autre ensuite")
fists.Activated:Fire()
check(FIRE_SERVER.HitWindow == 3, "0,3 s plus tard : nouveau coup envoyé tout de suite")
place(P1, Vector3.new(60, 3, 14), Vector3.new(60, 3, 0))
advance(0.25)
fists.Activated:Fire()
check(FIRE_SERVER.HitWindow == 3 and #Anim.Calls == 4, "dos à la vitre : rien envoyé, animation jouée dans le vide")
place(P1, Vector3.new(60, 3, 11.4), Vector3.new(60, 3, 20.5))
advance(0.25)
fists.Activated:Fire()
check(FIRE_SERVER.HitWindow == 3, "à 8,9 studs (portée 8) : rien envoyé")
plot2:SetAttribute("OwnerUserId", 101)
place(P1, Vector3.new(-120, 3, 44), Vector3.new(-120, 3, 50))
advance(0.25)
fists.Activated:Fire()
check(FIRE_SERVER.HitWindow == 3, "sa propre parcelle : rien envoyé")
place(P1, Vector3.new(-200, 3, 44), Vector3.new(-200, 3, 50))
advance(0.25)
fists.Activated:Fire()
check(FIRE_SERVER.HitWindow == 4, "parcelle de Bob : coup envoyé")
d1.Stats.Strength = 1e7
place(P1, Vector3.new(60, 3, 14), Vector3.new(60, 3, 20.5))
advance(1.1)
fists.Activated:Fire()
check(FIRE_SERVER.HitWindow == 5 and WS.IsBroken(SUP), "casse depuis le client")
advance(0.25)
fists.Activated:Fire()
check(FIRE_SERVER.HitWindow == 5, "vitrine cassée : rien envoyé")
TS.Grant(P1, "Hammer")
TS.Equip(P1, "Hammer")
local hammer = toolsOf(P1)[1]
check(hammer.Parent == P1.Character, "Marteau remis en main")
place(P1, Vector3.new(60, 3, -14), Vector3.new(60, 3, -20.5))
advance(0.25)
hammer.Activated:Fire()
check(Anim.Calls[#Anim.Calls] == "HitWindowHeavy" and FIRE_SERVER.HitWindow == 6, "Marteau : HitWindowHeavy, coup envoyé")

print("== Coup au marqueur Impact (copie a26, vague 8)")
local ShatterCfg = requireModule(ConfigF.Shatter, "client")
local WAIT = ShatterCfg.Hit.ImpactMaxWait
check(WAIT == 0.3, `délai max du marqueur = Config.Shatter.Hit.ImpactMaxWait, celui du retour local (lu : {WAIT} s)`)
d1.Stats.Strength = 0 -- dégâts 1 (poings) : la vitre tient
advance(31) -- Supérette et Kiosque reconstruites
TS.Equip(P1, "Fists")
local fists2 = toolsOf(P1)[1]
check(fists2 and fists2.Name == "Fists" and fists2.Parent == P1.Character, "poings remis en main")
place(P1, Vector3.new(60, 3, 14), Vector3.new(60, 3, 20.5))
Anim.delivered.HitWindow = true
Anim.delivered.HitWindowHeavy = true
advance(1.1)
local function sent()
	return FIRE_SERVER.HitWindow or 0
end
-- Coups acceptés par le serveur sur `id` : écho WindowHit au frappeur (la vitre tient).
local function hitsOn(id)
	local n = 0
	for _, e in REMOTE_LOG do
		if e.name == "WindowHit" and e.to == P1 and e.args[1] == id then
			n += 1
		end
	end
	return n
end

local s0, h0 = sent(), hitsOn(SUP)
fists2.Activated:Fire()
check(sent() == s0 and Anim.Calls[#Anim.Calls] == "HitWindow", "M1 animation livrée : rien ne part au clic")
advance(0.133)
check(sent() == s0, "M2 0,133 s, marqueur pas encore passé : toujours rien")
Anim.reach("HitWindow", "Impact")
check(sent() == s0 + 1 and hitsOn(SUP) == h0 + 1, "M3 marqueur Impact : le coup part et le serveur l'accepte")
advance(0.5)
check(sent() == s0 + 1 and hitsOn(SUP) == h0 + 1, "M4 délai max passé ensuite : pas de second coup (marqueur puis repli)")

local s1 = sent()
fists2.Activated:Fire()
advance(WAIT - 0.01)
check(sent() == s1, "M5 marqueur jamais atteint : on attend…")
advance(0.02)
check(sent() == s1 + 1, "M6 … au plus 0,3 s : le coup part quand même (repli)")
Anim.reach("HitWindow", "Impact")
advance(0.05)
check(sent() == s1 + 1, "M7 marqueur en retard, après le repli : pas de second coup")

advance(0.5)
local s2, h2 = sent(), hitsOn(SUP)
fists2.Activated:Fire()
advance(0.11)
check(sent() == s2, "M8 0,11 s, avant le marqueur : rien")
advance(0.1) -- a134 : le clic suivant vient après l'intervalle de 0,2 s (5 coups par seconde), toujours avant le marqueur
fists2.Activated:Fire() -- clic suivant : l'animation repart du début
check(sent() == s2 + 1, "M9 clic suivant avant le marqueur : le coup en attente part tout de suite")
advance(0.133) -- a134 : le marqueur de HitWindow arrive 0,133 s après le clic (deux coups au même instant : le débit régulier de Net n'en passe qu'un)
Anim.reach("HitWindow", "Impact")
check(sent() == s2 + 2, "M10 marqueur de la nouvelle lecture : le second coup part")
advance(0.5)
check(sent() == s2 + 2 and hitsOn(SUP) == h2 + 2, "M11 deux clics = deux coups acceptés, pas plus")

advance(1.1)
clearLog()
local h3 = hitsOn(SUP)
local arrivals = {}
local spy = Remotes.HitWindow.OnServerEvent:Connect(function()
	table.insert(arrivals, now())
end)
for _ = 1, 10 do
	fists2.Activated:Fire() -- l'animation repart à chaque clic : son marqueur n'arrive jamais
	advance(0.101)
end
advance(0.5)
spy:Disconnect()
local minGap = math.huge
for i = 2, #arrivals do
	minGap = math.min(minGap, arrivals[i] - arrivals[i - 1])
end
check(#arrivals >= 5 and #arrivals <= 6, `M12 a134 : 10 clics à ~10/s sans marqueur : un coup toutes les 0,2 s, 5 à 6 envoyés (lu : {#arrivals})`)
check(minGap >= 0.19, `M13 a134 : envois espacés d'au moins 0,2 s (écart min {string.format("%.3f", minGap)} s)`)
check(hitsOn(SUP) - h3 == #arrivals and not logHas("RateLimit", "WARN"), "M14 tous acceptés par le serveur, aucun refus de débit")

Anim.delivered.HitWindow = false
advance(0.2)
local s4 = sent()
fists2.Activated:Fire()
check(sent() == s4 + 1, "M15 animation pas livrée : le coup part au clic, comme avant")
advance(0.5)
check(sent() == s4 + 1, "M16 … une seule fois")
Anim.delivered.HitWindow = true

advance(0.2)
clearLog()
local s5 = sent()
fists2.Activated:Fire()
advance(0.05)
fists2.Parent = P1:FindFirstChildOfClass("Backpack") -- outil rangé pendant le coup
advance(WAIT + 0.05)
check(sent() == s5, "M17 outil rangé pendant le coup : rien ne part au repli")
check(not logHas("outil de casse pas en main", "WARN"), "M18 … et le serveur n'a rien à refuser")
fists2.Parent = P1.Character
advance(0.2)
local s6 = sent()
fists2.Activated:Fire()
P1.Character.Humanoid.Health = 0
advance(WAIT + 0.05)
check(sent() == s6, "M19 mort pendant le coup : rien ne part")
P1.Character.Humanoid.Health = 100

TS.Equip(P1, "Hammer")
local hammer2 = toolsOf(P1)[1]
place(P1, Vector3.new(60, 3, -14), Vector3.new(60, 3, -20.5))
advance(0.2)
local s7 = sent()
hammer2.Activated:Fire()
check(hammer2.Name == "Hammer" and Anim.Calls[#Anim.Calls] == "HitWindowHeavy" and sent() == s7, "M20 Marteau : HitWindowHeavy, rien au clic")
advance(0.133)
Anim.reach("HitWindow", "Impact")
check(sent() == s7, "M21 le marqueur d'une autre animation (HitWindow) ne fait rien partir")
advance(0.1)
Anim.reach("HitWindowHeavy", "Impact")
check(sent() == s7 + 1, "M22 marqueur Impact de HitWindowHeavy (0,233 s) : le coup part")
advance(0.5)
check(sent() == s7 + 1, "M23 une seule fois")

print("== Bilan")
local errors = 0
for _, line in LOG do
	if string.find(line.text, "ERREUR", 1, true) then
		errors += 1
	end
end
summary()
print("== Sortie complète des modules (PRINT et WARN)")
for _, line in FULL_LOG do
	print(`  [{line.side}] {line.kind} {string.sub(line.text, 1, 160)}`)
end
