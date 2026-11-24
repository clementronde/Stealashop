--!nocheck
-- Scénarios : StoreHeistService (serveur, vrai Net et vraie Config) et HeistController (client).
-- WindowService, CarryService et AnimationController sont des bouchons.

SOURCES["stub/WindowService.luau"] = [[
local W = { broken = {}, brokenListeners = {}, rebuiltListeners = {} }
function W.GetWindowId(model) return model.Name end
function W.IsBroken(id) return W.broken[id] == true end
function W.OnBroken(fn) table.insert(W.brokenListeners, fn) return function() end end
function W.OnRebuilt(fn) table.insert(W.rebuiltListeners, fn) return function() end end
function W._break(model, breaker)
	W.broken[model.Name] = true
	local info = table.freeze({ WindowId = model.Name, Kind = "NPC", Model = model, Breaker = breaker, ImpactPoint = Vector3.zero })
	for _, fn in W.brokenListeners do task.spawn(fn, info) end
end
function W._rebuild(model)
	W.broken[model.Name] = nil
	for _, fn in W.rebuiltListeners do task.spawn(fn, model.Name, model) end
end
return W
]]

SOURCES["stub/CarryService.luau"] = [[
local C = { carrying = {}, ended = {}, started = {}, refuseNext = false }
function C.StartCarry(player, payload)
	if C.refuseNext then C.refuseNext = false return false end
	if C.carrying[player] then return false end
	C.carrying[player] = payload
	table.insert(C.started, { player = player, payload = payload })
	player:SetAttribute("Carrying", payload.Rarity)
	return true
end
function C.IsCarrying(player) return C.carrying[player] ~= nil end
function C.GetPayload(player) return C.carrying[player] end
function C.OnCarryEnded(fn) table.insert(C.ended, fn) return function() end end
local function finish(player, result, reason)
	local payload = C.carrying[player]
	if payload == nil then return nil end
	C.carrying[player] = nil
	player:SetAttribute("Carrying", nil)
	for _, fn in C.ended do task.spawn(fn, player, payload, result, reason) end
	return payload
end
function C.Fail(player, reason) finish(player, "Failed", reason) end
function C.Consume(player) return finish(player, "Consumed", "Placed") end
return C
]]

SOURCES["stub/AnimationController.luau"] = [[
local A = { Calls = {} }
function A.PlayPlayer(name) table.insert(A.Calls, name) return nil end
return A
]]

---------------------------------------------------------------- arbre
local Shared = folder(ReplicatedStorage, "Shared")
local ConfigF = folder(Shared, "Config")
for _, n in { "Balance", "Bat", "Cosmetics", "DeepFreeze", "Formulas", "Items", "Night", "PvP", "Rarities", "Tools", "Training", "Tutorial", "Upgrades", "Zones" } do
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

local Services = folder(folder(ServerScriptService, "Server"), "Services")
local HeistModule = moduleScript(Services, "StoreHeistService", "server/Services/StoreHeistService.luau")
local WindowModule = moduleScript(Services, "WindowService", "stub/WindowService.luau")
local CarryModule = moduleScript(Services, "CarryService", "stub/CarryService.luau")
local Controllers = folder(folder(StarterPlayerScripts, "Client"), "Controllers")
local ControllerModule = moduleScript(Controllers, "HeistController", "client/Controllers/HeistController.luau")
local AnimModule = moduleScript(Controllers, "AnimationController", "stub/AnimationController.luau")

---------------------------------------------------------------- map
local function new(class, name, parent, props)
	local inst = InstanceAPI.new(class)
	inst.Name = name
	for k, v in props or {} do
		inst[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end
local function block(parent, name, frame, center, size)
	return new("Part", name, parent, { Anchored = true, CFrame = frame * CFrame.new(center), Size = size })
end
local function slot(shelf, n, world, tier)
	local a = new("Attachment", string.format("ShelfSlot_%02d", n), nil)
	a.CFrame = shelf.CFrame:ToObjectSpace(CFrame.new(world))
	a:SetAttribute("Tier", tier)
	a.Parent = shelf
	return a
end
-- Magasin façon greybox : origine au sol, au centre ; façade en −Z local (vers la rue).
local function buildStore(name, zone, x, z)
	local frame = CFrame.new(x, 0, z)
	local m = new("Model", name, nil)
	m.WorldPivot = frame
	m:SetAttribute("Zone", zone)
	block(m, "Window", frame, Vector3.new(0, 4, -13.5), Vector3.new(12, 7, 0.4))
	block(m, "Shutter", frame, Vector3.new(0, 11.25, -14.2), Vector3.new(13, 7.5, 0.3))
	block(m, "Door", frame, Vector3.new(-9, 4, -13.5), Vector3.new(4, 8, 0.4))
	local bounds = block(m, "Bounds", frame, Vector3.new(0, 6.6, 0), Vector3.new(22, 12.8, 26))
	bounds.Transparency = 1
	bounds.CanCollide = false
	local left = block(m, "Shelf_Front_L", frame, Vector3.new(-10, 1.5, -6), Vector3.new(2, 3, 9))
	local right = block(m, "Shelf_Front_R", frame, Vector3.new(10, 1.5, -6), Vector3.new(2, 3, 9))
	local middle = block(m, "Shelf_Middle", frame, Vector3.new(0, 1.5, 1.5), Vector3.new(9, 3, 2))
	local reserve = block(m, "Shelf_Reserve", frame, Vector3.new(0, 1.5, 10.5), Vector3.new(2, 3, 2))
	local n = 0
	for _, dz in { -9, -6, -3 } do
		n += 1
		slot(left, n, (frame * CFrame.new(-10, 3, dz)).Position, "Standard")
	end
	for _, dz in { -9, -6, -3 } do
		n += 1
		slot(right, n, (frame * CFrame.new(10, 3, dz)).Position, "Standard")
	end
	for _, dx in { -3, 0, 3 } do
		n += 1
		slot(middle, n, (frame * CFrame.new(dx, 3, 1.5)).Position, "Premium")
	end
	slot(reserve, 10, (frame * CFrame.new(0, 3, 10.5)).Position, "Luxe")
	return m
end
local superette = buildStore("STORE_Z1_Superette", 1, 60, 34)
superette.Parent = Workspace
addTag(superette, "NPCStore")
local kiosque = buildStore("STORE_Z1_Kiosque", 1, 300, 34) -- loin, pour le rayon du chrono
kiosque.Parent = Workspace
addTag(kiosque, "NPCStore")
local inboxStore = buildStore("STORE_Z1_Livraison", 1, 900, 34)
inboxStore.Parent = folder(Workspace, "_INBOX_CLEMENT")
addTag(inboxStore, "NPCStore")
-- BOX_Premium livré par Clément (Model), avec un script à retirer ; Standard et Luxe absents.
local Assets = folder(ReplicatedStorage, "Assets")
local boxPremium = new("Model", "BOX_Premium", folder(Assets, "Boxes"))
local tint = new("Part", "Tint", boxPremium, { Size = Vector3.new(1.8, 1.4, 1.8), CFrame = CFrame.new(0, 0.7, 0) })
tint.PivotOffset = CFrame.new(0, -0.7, 0)
boxPremium.PrimaryPart = tint
new("Part", "Lid", boxPremium, { Size = Vector3.new(1.8, 0.2, 1.8), CFrame = CFrame.new(0, 1.5, 0) })
new("Script", "Junk", boxPremium)

-- Coordonnées utiles (superette) : vitrine en z = 20,5, intérieur de z = 21 à 47, x de 49 à 71.
local P = {
	outside = Vector3.new(60, 3, 15), -- devant la vitrine, dehors
	slot01 = Vector3.new(50, 3, 25),
	nearSlot01 = Vector3.new(52, 3, 25), -- dedans, à 2 studs du rayon 01
	nearSlot02 = Vector3.new(52, 3, 28),
	nearSlot07 = Vector3.new(57, 3, 33), -- 2,5 studs du rayon 07 (Premium)
	nearSlot10 = Vector3.new(60, 3, 42), -- 2,5 studs du rayon 10 (Luxe)
	center = Vector3.new(60, 3, 34),
	farInside = Vector3.new(68, 3, 44), -- dedans, à plus de 8 studs des rayons 01 et 02
	outsideNearSlot01 = Vector3.new(50, 3, 19), -- dehors, à 6 studs du rayon 01
	far = Vector3.new(60, 3, -500),
}

---------------------------------------------------------------- joueurs
local function addPlayer(name, userId, position)
	local p = InstanceAPI.new("Player")
	p.Name = name
	p.UserId = userId
	local character = new("Model", name, nil)
	new("Humanoid", "Humanoid", character)
	local root = new("Part", "HumanoidRootPart", character, { Size = Vector3.new(2, 2, 1), CFrame = CFrame.new(position) })
	new("Part", "Head", character, { Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(position + Vector3.new(0, 1.5, 0)) })
	character.PrimaryPart = root
	character.Parent = Workspace
	p.Character = character
	p.Parent = Players
	return p
end
local p1 = addPlayer("P1", 1, P.outside)
local p2 = addPlayer("P2", 2, P.far)
CLIENT_PLAYER = p1
Players.LocalPlayer = p1

local function moveTo(player, position)
	player.Character:PivotTo(CFrame.new(position))
end
local function rootOf(player)
	return player.Character.HumanoidRootPart.Position
end

---------------------------------------------------------------- chargement
local Heist = requireModule(HeistModule, "server")
local W = requireModule(WindowModule, "server")
local C = requireModule(CarryModule, "server")
local Anim = requireModule(AnimModule, "client")
local Items = requireModule(ConfigF.Items, "server")
local Night = requireModule(ConfigF.Night, "server")
local GrabRemote -- RemoteEvent GrabItem (créé par le Net du serveur)

local function boxesOf(store)
	return store:FindFirstChild("ShelfBoxes")
end
local function boxAt(store, n)
	return boxesOf(store):FindFirstChild(string.format("ShelfBox_%02d", n))
end
local function slotId(store, n)
	return string.format("%s/%02d", store.Name, n)
end
local function grab(player, id)
	GrabRemote.OnServerEvent:Fire(player, id)
end
local function startedCount()
	return #C.started
end
local function lastStarted()
	return C.started[#C.started]
end
local function timersTo(player, storeId)
	local out = {}
	for _, e in remotes("HeistTimer", storeId) do
		if e.to == player then
			table.insert(out, e.args[2])
		end
	end
	return out
end
local function notifiesTo(player)
	local out = {}
	for _, e in remotes("Notify") do
		if e.to == player then
			table.insert(out, e.args[1])
		end
	end
	return out
end
local function shutterY(store)
	return store.Shutter.CFrame.Position.Y
end
local function insideBounds(store, position)
	local b = store.Bounds
	local p = b.CFrame:PointToObjectSpace(position)
	return math.abs(p.X) <= b.Size.X / 2 and math.abs(p.Y) <= b.Size.Y / 2 and math.abs(p.Z) <= b.Size.Z / 2
end

print("== Démarrage")
Heist.Init()
GrabRemote = ReplicatedStorage.Remotes.GrabItem
taskLib.spawn(Heist.Start)
check(logHas("[StoreHeistService] 2 magasin(s) prêt(s), 20 colis sur les rayons (modèles BOX_Premium)", "PRINT"), "Init : 2 magasins (la livraison de l'inbox est ignorée), 20 colis, BOX_Premium reconnu")
check(boxesOf(inboxStore) == nil, "magasin de _INBOX_CLEMENT ignoré")
check(boxesOf(superette) ~= nil and #boxesOf(superette):GetChildren() == 10, "10 colis sur les rayons de la Supérette")
local b01, b07, b10 = boxAt(superette, 1), boxAt(superette, 7), boxAt(superette, 10)
check(b01 and b01:GetAttribute("SlotId") == "STORE_Z1_Superette/01" and b01:GetAttribute("Slot") == "ShelfSlot_01", "attributs SlotId et Slot du colis 01")
check(b01:GetAttribute("Tier") == "Standard" and b01:GetAttribute("Landed") == true, "colis 01 : Standard, posé")
check(b01:FindFirstChild("Body") ~= nil and b01:FindFirstChild("Tint") == nil, "Standard : bloc V0 (BOX_Standard absent)")
check(b07:FindFirstChild("Tint") ~= nil and b07:FindFirstChild("Lid") ~= nil, "Premium : clone de BOX_Premium")
check(b07:FindFirstChild("Junk") == nil, "script du modèle livré retiré")
check(b07.Tint.Anchored == true and b07.Tint.CanCollide == false and b07.Tint.CanQuery == false, "colis ancré, sans collision ni requête")
check(b10:FindFirstChild("Trim_1") ~= nil and b10:FindFirstChild("Trim_2") ~= nil, "Luxe V0 : caisse cerclée (2 cercles)")
check(near((b01:GetPivot().Position - Vector3.new(50, 3, 25)).Magnitude, 0, 1e-6), "colis posé sur son ShelfSlot (pivot en bas au centre)")
check(near(b01.Body.CFrame.Position.Y, 3.6, 1e-6), "bloc V0 : le bas du colis touche le rayon")
check(superette:GetAttribute("StoreId") == "STORE_Z1_Superette" and superette:GetAttribute("HeistOpen") == false, "attributs StoreId et HeistOpen du magasin")
check(Heist.GetStoreModel("STORE_Z1_Superette") == superette and Heist.GetStoreId(superette) == "STORE_Z1_Superette", "GetStoreModel et GetStoreId")
local shutterOpenY = shutterY(superette)

print("== Client : HeistController")
local Controller = requireModule(ControllerModule, "client")
local timerEvents = {}
Controller.OnTimer(function(storeId, endsAt)
	table.insert(timerEvents, { storeId, endsAt })
end)
taskLib.spawn(Controller.Start)
advance(0.3)
local prompt01 = superette:FindFirstChild("ShelfSlot_01", true):FindFirstChild("GrabPrompt")
local prompt07 = superette:FindFirstChild("ShelfSlot_07", true):FindFirstChild("GrabPrompt")
local prompt10 = superette:FindFirstChild("ShelfSlot_10", true):FindFirstChild("GrabPrompt")
check(prompt01 ~= nil and prompt07 ~= nil and prompt10 ~= nil, "une invite sur chaque ShelfSlot du magasin")
check(prompt01.Enabled == false, "invite inactive : magasin fermé")
check(near(prompt01.HoldDuration, 0.3) and near(prompt07.HoldDuration, 0.6) and near(prompt10.HoldDuration, 1.0), "maintien 0,3 / 0,6 / 1,0 s selon le type")
check(near(prompt01.MaxActivationDistance, 7.5) and prompt01.RequiresLineOfSight == false, "portée 7,5 studs, sans ligne de vue")
check(prompt01.ObjectText == "Colis Standard" and prompt10.ObjectText == "Colis Luxe" and prompt01.ActionText == "Voler", "textes de l'invite")

print("== Prise refusée magasin fermé")
moveTo(p1, P.nearSlot01)
clearLog()
grab(p1, slotId(superette, 1))
advance(0.4)
grab(p1, slotId(superette, 1))
check(startedCount() == 0 and logHas("magasin fermé", "WARN"), "GrabItem refusé tant que la vitrine n'est pas cassée")
advance(1.2) -- passe la limite d'une ligne de refus par seconde
check(boxAt(superette, 1) ~= nil, "le colis reste")
moveTo(p1, P.outside)
advance(0.2)
check(rootOf(p1) == P.outside, "dehors devant la vitrine")
clearLog()

print("== Casse et ouverture")
local t0 = now()
W._break(superette, p1)
check(superette:GetAttribute("HeistOpen") == true, "HeistOpen = true")
check(near(superette:GetAttribute("HeistEndsAt"), t0 + 10), "HeistEndsAt = casse + 10 s (heure serveur)")
check(near(superette:GetAttribute("HeistExclusiveUntil"), t0 + 1), "HeistExclusiveUntil = casse + 1 s")
check(superette:GetAttribute("HeistBreakerId") == 1, "HeistBreakerId = UserId du casseur")
check(Heist.IsOpen(superette) and Heist.IsOpen("STORE_Z1_Superette") and not Heist.IsOpen(kiosque), "IsOpen (modèle ou StoreId)")
local t1 = timersTo(p1, "STORE_Z1_Superette")
check(#t1 == 1 and near(t1[1], t0 + 10), "HeistTimer(storeId, endsAt) au casseur")
check(#timersTo(p2, "STORE_Z1_Superette") == 0, "rien au joueur loin du magasin")
check(#timerEvents == 1 and timerEvents[1][1] == "STORE_Z1_Superette" and near(timerEvents[1][2], t0 + 10), "client : OnTimer reçoit le chrono")
check(Controller.GetTimers()["STORE_Z1_Superette"] ~= nil, "client : GetTimers")
check(logHas("[Heist] STORE_Z1_Superette : chrono de 10 s", "PRINT") and not logHas("[Heist] STORE_Z1_Superette : 9 s", "PRINT"), "client : une ligne de sortie par chrono (a15 : le compte à rebours est dans le HUD)")
advance(0.25)
check(prompt01.Enabled == false, "client : invite inactive tant que le joueur est dehors")

print("== Avance du casseur")
moveTo(p2, P.nearSlot02)
advance(0.15)
check(#timersTo(p2, "STORE_Z1_Superette") == 1, "un joueur qui approche reçoit le chrono")
clearLog()
grab(p2, slotId(superette, 2))
check(logHas("avance du casseur", "WARN"), "un autre joueur ne peut pas prendre pendant la 1re seconde")

print("== Maintien de P1 (Standard, 0,3 s)")
moveTo(p1, P.nearSlot01)
advance(0.25)
check(prompt01.Enabled == true, "client : invite active (casseur, dedans, mains vides)")
local sentBefore = FIRE_SERVER.GrabItem or 0
RANDOM_VALUES = { 0.95 } -- Standard : 95 % tombe dans Rare (92 à 99)
prompt01.PromptButtonHoldBegan:Fire(p1)
check((FIRE_SERVER.GrabItem or 0) == sentBefore + 1, "client : GrabItem au début du maintien")
advance(0.1)
clearLog()
grab(p1, slotId(superette, 1))
check(startedCount() == 0 and logHas("maintien trop court", "WARN"), "fin à 0,1 s refusée (maintien trop court)")
advance(0.2)
prompt01.Triggered:Fire(p1)
check((FIRE_SERVER.GrabItem or 0) == sentBefore + 2, "client : GrabItem à la fin du maintien")
check(startedCount() == 1, "prise acceptée après 0,3 s")
local pay = lastStarted().payload
check(lastStarted().player == p1 and pay.Kind == "NPCBox" and pay.Tier == "Standard" and pay.Zone == 1, "payload : Kind, Tier, Zone")
check(pay.Rarity == "Rare" and pay.ItemId == Items.ByZone[1].Rare.Id, "tirage : Rare, objet Rare de la zone 1 (" .. tostring(pay.ItemId) .. ")")
check(pay.StoreId == "STORE_Z1_Superette" and pay.SlotId == "STORE_Z1_Superette/01", "payload : StoreId, SlotId")
check(boxAt(superette, 1) == nil, "le rayon 01 se vide")
check(superette:FindFirstChild("ShelfSlot_01", true):FindFirstChild("GrabPrompt") == nil, "client : invite retirée avec le colis")
local t1b = timersTo(p1, "STORE_Z1_Superette")
check(#t1b == 2 and t1b[2] == 0, "HeistTimer(storeId, 0) : le chrono ne compte plus pour le porteur")
check(Anim.Calls[#Anim.Calls] == "Grab", "client : animation Grab à la fin du maintien")
check(logHas("P1 prend le colis Standard ShelfSlot_01 de STORE_Z1_Superette : Rare", "PRINT"), "sortie Studio de la prise")
advance(0.25)
check(prompt07.Enabled == false, "client : invites inactives quand on porte (attribut Carrying)")

print("== Mains pleines, distance, volume")
advance(1.1) -- une ligne de refus par seconde et par joueur
clearLog()
grab(p1, slotId(superette, 3))
check(logHas("mains pleines", "WARN") and startedCount() == 1, "mains pleines : refusé")
advance(1.1)
moveTo(p2, P.farInside)
advance(0.1)
clearLog()
grab(p2, slotId(superette, 2))
check(logHas("trop loin", "WARN"), "à plus de 8 studs : refusé")
advance(1.1)
moveTo(p2, P.outsideNearSlot01)
clearLog()
grab(p2, slotId(superette, 2))
check(logHas("hors du volume Bounds", "WARN"), "dehors, même à portée : refusé")
advance(1.1)
clearLog()
grab(p2, "STORE_Z1_Superette/99")
check(logHas("emplacement inconnu", "WARN"), "slotId inconnu : refusé")

print("== Maintien interrompu")
moveTo(p2, P.nearSlot02)
advance(1.1)
grab(p2, slotId(superette, 2)) -- début
advance(0.1)
moveTo(p2, P.farInside) -- s'éloigne pendant le maintien
advance(0.15)
moveTo(p2, P.nearSlot02)
advance(0.2)
grab(p2, slotId(superette, 2)) -- revient : nouveau début, pas une fin
check(startedCount() == 1, "maintien annulé en s'éloignant : la fin ne passe pas")
advance(0.35)
RANDOM_VALUES = { 0.1 } -- Commun
grab(p2, slotId(superette, 2))
check(startedCount() == 2 and lastStarted().player == p2 and lastStarted().payload.Rarity == "Common", "nouveau maintien complet : prise de P2 (Commun)")

print("== Fermeture à 10 s")
moveTo(p1, P.center) -- porteur encore dedans
moveTo(p2, P.nearSlot07)
C.Fail(p2, "Test") -- P2 perd son colis tout de suite : il revient sur le rayon 02
advance(0.1)
check(boxAt(superette, 2) ~= nil and boxAt(superette, 2):GetAttribute("Landed") == false, "colis rendu : en vol vers son rayon")
advance(1.6)
check(boxAt(superette, 2):GetAttribute("Landed") == true, "colis rendu : posé à l'arrivée")
check(near((boxAt(superette, 2):GetPivot().Position - Vector3.new(50, 3, 28)).Magnitude, 0, 1e-6), "colis rendu : pile sur son ShelfSlot")
local untilClose = t0 + 10 - now()
grab(p2, slotId(superette, 7)) -- début d'un maintien qui sera coupé par la fermeture
advance(untilClose - 0.05)
check(Heist.IsOpen(superette), "encore ouvert juste avant 10 s")
clearLog()
advance(0.1)
check(not Heist.IsOpen(superette) and superette:GetAttribute("HeistOpen") == false, "fermé à 10 s")
check(superette:GetAttribute("HeistEndsAt") == nil and superette:GetAttribute("HeistBreakerId") == nil, "attributs du chrono effacés")
check(not insideBounds(superette, rootOf(p2)), "P2 (sans colis) sorti du magasin")
local r2 = rootOf(p2)
check(near(r2.Z, 20.5 - 6, 1e-6) and near(r2.Y, 3.1, 1e-6) and r2.X >= 55 - 1e-6 and r2.X <= 65 + 1e-6, "P2 posé à 6 studs devant la vitrine, au sol, sur sa largeur")
check(insideBounds(superette, rootOf(p1)), "P1 (porteur) pas sorti")
local n2 = notifiesTo(p2)
check(#n2 == 1 and n2[1] == "Trop tard : le rideau est tombé !", "Notify à P2")
check(#notifiesTo(p1) == 0, "pas de Notify au porteur")
local t2 = timersTo(p2, "STORE_Z1_Superette")
check(t2[#t2] == 0, "chrono masqué pour P2 à la fermeture")
advance(0.5)
check(near(shutterY(superette), shutterOpenY - 7.5, 1e-6), "rideau tombé de sa hauteur (7,5 studs)")
check(superette.Shutter.CanCollide == false, "rideau franchissable pendant la sortie des porteurs")
clearLog()
grab(p2, slotId(superette, 7))
check(logHas("magasin fermé", "WARN"), "plus de prise après la fermeture (maintien coupé)")
advance(1.1)
check(startedCount() == 2, "aucune prise de plus")

print("== Magasin fermé : pas de camping dedans")
moveTo(p2, P.nearSlot07)
advance(0.15)
check(not insideBounds(superette, rootOf(p2)), "un joueur sans colis qui rentre est ressorti")
check(logHas("P2 sorti de STORE_Z1_Superette (magasin fermé)", "PRINT"), "sortie Studio")
advance(3)
check(superette.Shutter.CanCollide == true, "rideau solide après 3 s")

print("== Reconstruction à 30 s")
local untilRebuild = t0 + 30 - now()
advance(untilRebuild)
W._rebuild(superette)
check(insideBounds(superette, rootOf(p1)) == false, "le porteur encore dedans est sorti à la reconstruction")
check(C.IsCarrying(p1), "… avec son colis")
advance(1)
check(near(shutterY(superette), shutterOpenY, 1e-6), "rideau remonté")
check(superette.Shutter.CanCollide == true, "collision d'origine du rideau rendue")

print("== Échec du porteur : retour avec le contenu gardé")
C.Fail(p1, "Caught")
advance(2)
check(boxAt(superette, 1) ~= nil and boxAt(superette, 1):GetAttribute("Landed") == true, "colis de P1 revenu sur le rayon 01")
check(logHas("colis Standard de P1 (Caught) : revient sur STORE_Z1_Superette/01", "PRINT"), "sortie Studio du retour")
W._break(superette, p1)
moveTo(p1, P.nearSlot01)
advance(0.2)
RANDOM_VALUES = { 0.0 } -- un nouveau tirage donnerait Commun
grab(p1, slotId(superette, 1))
advance(0.35)
grab(p1, slotId(superette, 1))
check(startedCount() == 3 and lastStarted().payload.Rarity == "Rare" and lastStarted().payload.ItemId == pay.ItemId, "même contenu qu'avant (pas de nouveau tirage)")
check(#RANDOM_VALUES == 1, "aucun tirage pour un colis rendu")
RANDOM_VALUES = {}

print("== Premium 0,6 s et Luxe 1,0 s, Secret")
C.Consume(p1)
advance(1.1)
moveTo(p1, P.nearSlot10)
advance(0.2)
grab(p1, slotId(superette, 10))
advance(0.85)
grab(p1, slotId(superette, 10))
check(startedCount() == 3, "Luxe : fin à 0,85 s refusée")
advance(0.1)
RANDOM_VALUES = { 0.9999 } -- Luxe : 99,99 % tombe dans Secret (99,8 à 100)
grab(p1, slotId(superette, 10))
check(startedCount() == 4, "Luxe : fin à 0,95 s acceptée (tolérance 0,1 s)")
check(lastStarted().payload.Rarity == "Secret" and lastStarted().payload.ItemId == Items.Secrets[1].Id, "Secret : objet secret toutes zones")
C.Consume(p1)
advance(1.1)
moveTo(p1, P.nearSlot07)
advance(0.2)
grab(p1, slotId(superette, 7))
advance(0.45)
grab(p1, slotId(superette, 7))
check(startedCount() == 4, "Premium : fin à 0,45 s refusée")
advance(0.2)
grab(p1, slotId(superette, 7))
check(startedCount() == 5 and lastStarted().payload.Tier == "Premium", "Premium : fin à 0,65 s acceptée")
check(boxAt(superette, 7) == nil, "rayon Premium vidé")

print("== Maintien expiré")
C.Consume(p1)
advance(1.1)
moveTo(p1, P.nearSlot02)
advance(0.2)
grab(p1, slotId(superette, 2))
advance(1.5) -- plus de 0,3 + 1 s
grab(p1, slotId(superette, 2))
check(startedCount() == 5, "maintien expiré : le 2e appel recommence")

print("== Refus de CarryService")
advance(0.35)
C.refuseNext = true
grab(p1, slotId(superette, 2))
check(startedCount() == 5 and boxAt(superette, 2) ~= nil, "StartCarry refusé : le colis reste sur le rayon")
advance(1.1)
grab(p1, slotId(superette, 2))
advance(0.35)
grab(p1, slotId(superette, 2))
check(startedCount() == 6, "puis prise normale")

print("== Reconstruction pendant le chrono (Rebuild anticipé)")
moveTo(p2, P.center)
advance(0.1)
local shutterBefore = shutterY(superette)
W._rebuild(superette)
advance(0.1)
check(not Heist.IsOpen(superette), "magasin fermé par la reconstruction")
check(near(shutterY(superette), shutterBefore, 1e-6), "rideau pas baissé : la vitre est déjà là")
check(not insideBounds(superette, rootOf(p1)) and not insideBounds(superette, rootOf(p2)), "tout le monde est sorti, porteur compris")

print("== Remplissage (nuit)")
local filled = Heist.RefillAll()
check(filled == 4, "RefillAll remet les 4 colis pris (01, 02, 07, 10) : " .. tostring(filled))
check(#boxesOf(superette):GetChildren() == 10, "Supérette : 10 colis")
C.Fail(p1, "Died") -- le colis de P1 vient du rayon 02, rempli entre-temps
advance(2)
check(#boxesOf(superette):GetChildren() == 10, "rayon déjà rempli : pas de doublon")
check(logHas("rayon STORE_Z1_Superette/02 déjà rempli ou inconnu, colis perdu", "PRINT"), "sortie Studio du colis perdu")
check(Heist.ReturnBox({ Kind = "NPCBox", StoreId = "STORE_Z1_Superette", SlotId = "STORE_Z1_Superette/02", Tier = "Standard" }) == false, "ReturnBox sur un rayon occupé : false")
check(Heist.ReturnBox({ Kind = "Item" }) == false, "ReturnBox d'un objet volé à un joueur : false")

print("== OnBoxGrabbed")
local grabbed = {}
Heist.OnBoxGrabbed(function(player, payload)
	table.insert(grabbed, { player, payload })
end)
W._break(superette, p1)
moveTo(p1, P.nearSlot01)
advance(0.2)
grab(p1, slotId(superette, 1))
advance(0.35)
grab(p1, slotId(superette, 1))
check(#grabbed == 1 and grabbed[1][1] == p1 and grabbed[1][2].SlotId == "STORE_Z1_Superette/01", "OnBoxGrabbed(player, payload) après la prise")

print("== Client : avance du casseur pour un autre")
C.Consume(p1)
advance(11) -- fin du chrono
W._rebuild(superette)
advance(1)
W._break(superette, p2) -- P2 casse, P1 (le client) attend
moveTo(p1, P.nearSlot02)
advance(0.25)
local prompt02 = superette:FindFirstChild("ShelfSlot_02", true):FindFirstChild("GrabPrompt")
check(prompt02 and prompt02.Enabled == false, "client : invite inactive pendant l'avance du casseur")
advance(1)
check(prompt02.Enabled == true, "client : invite active après 1 s")

print("== Remplissage V0 automatique (toutes les 10 min)")
moveTo(p1, P.far)
moveTo(p2, P.far)
advance(11)
W._rebuild(superette)
local before = #boxesOf(superette):GetChildren()
clearLog()
advance(Night.CycleDuration)
check(logHas("rayons remplis", "PRINT"), "RefillAll appelé tout seul après Night.CycleDuration")
check(#boxesOf(superette):GetChildren() == 10 and before < 10, "rayons pleins (" .. before .. " → 10)")

print("== Départ d'un joueur")
p2.Parent = nil
Players.PlayerRemoving:Fire(p2)
advance(0.5)
check(true, "aucune erreur au départ")


print("== Avertissements hors refus attendus")
local unexpected = 0
for _, line in FULL_LOG do
	if line.kind == "WARN" and not string.find(line.text, "GrabItem de", 1, true) then
		unexpected += 1
		print("  WARN " .. line.side .. " : " .. line.text)
	end
end
check(unexpected == 0, "aucun autre avertissement (Net, envois mal formés, erreurs)")
summary()
