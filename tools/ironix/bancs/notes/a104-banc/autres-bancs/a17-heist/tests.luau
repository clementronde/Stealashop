--!nocheck
-- Banc a17 (L-031, L-033) : StoreHeistService (serveur, vrai Net et vraie Config) et
-- HeistController (client). WindowService, CarryService et AnimationController sont des bouchons.
-- Repris du banc d'a10 (tests.a10.luau, ancienne règle : type par emplacement, tirage à la prise).
-- Vérifie : 6 Standard, 3 Premium, 1 Luxe répartis au hasard à chaque remplissage ; contenu tiré à
-- la mise en rayon (étiquette BB_Box posée par CarryService.AttachBoxLabel) ; zone 1 = Communs ;
-- prise = contenu tiré ; temps de prise du colis ; retour avec le contenu d'origine ; remplissage
-- reporté d'un magasin ouvert ; colis d'avant un remplissage perdu ; accroche du tuto.

math.randomseed(17)

-- Copie d'a66 (2026-11-11, Cantin : magasin fermé pour le voleur seulement, jusqu'au retour de son vigile ;
-- plus d'interdiction « The guard knows you now… ») : bouchon de GuardService avec OnGuardGone ; avant
-- chaque prise du banc par un joueur qui a déjà volé dans ce magasin, son vigile est « rentré »
-- (guardBack), sinon la prise serait refusée pour une bonne raison. La fermeture elle-même est vérifiée
-- par le banc a66.
SOURCES["stub/GuardService.luau"] = [[
local G = { gone = {} }
function G.OnGuardGone(fn) table.insert(G.gone, fn) return function() end end
function G._back(player, store) for _, fn in G.gone do fn(player, store) end end
return G
]]

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
local C = { carrying = {}, ended = {}, started = {}, refuseNext = false, labels = {}, labelCalls = 0 }
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
-- a30 (vague 10) : StoreHeistService remet sur son rayon un colis resté au sol (DEV-048).
function C.OnDropExpired(fn) return function() end end
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
function C.Drop(player) return finish(player, "Dropped", "Bat") end
-- Étiquette BB_Box : le vrai CarryService la construit (banc carry) ; ici on note ce qu'il reçoit.
function C.AttachBoxLabel(model, rarityId, itemId)
	C.labelCalls += 1
	local gui = Instance.new("Folder")
	gui.Name = "BB_Box"
	gui.Parent = model
	C.labels[model] = { Rarity = rarityId, ItemId = itemId, Gui = gui }
	return gui
end
return C
]]

SOURCES["stub/AnimationController.luau"] = [[
local A = { Calls = {} }
function A.PlayPlayer(name) table.insert(A.Calls, name) return nil end
return A
]]

-- Propriétés et méthodes utilisées par le nouveau code ou par ce banc, absentes des bouchons de a08.
PROPS.Model.ModelStreamingMode = "Enum.ModelStreamingMode.Default"
function Methods.GetAttributes(self)
	return table.clone(rawget(self, "_attrs"))
end
-- Clone qui, comme Roblox, fait pointer PrimaryPart (et toute propriété Instance) de la copie vers
-- la copie de la pièce, pas vers l'original (le Clone des bouchons de a08 ne le fait pas).
local function cloneTree(original, map)
	local copy = InstanceAPI.new(rawget(original, "_class"))
	map[original] = copy
	for k, v in rawget(original, "_props") do
		rawget(copy, "_props")[k] = v
	end
	for k, v in rawget(original, "_attrs") do
		rawget(copy, "_attrs")[k] = v
	end
	for _, child in rawget(original, "_children") do
		cloneTree(child, map).Parent = copy
	end
	return copy
end
function Methods.Clone(self)
	local map = {}
	local copy = cloneTree(self, map)
	for _, c in map do
		local props = rawget(c, "_props")
		for k, v in props do
			if type(v) == "table" and map[v] then
				props[k] = map[v]
			end
		end
	end
	return copy
end

---------------------------------------------------------------- arbre
local Shared = folder(ReplicatedStorage, "Shared")
local ConfigF = folder(Shared, "Config")
for _, n in { "Balance", "Bat", "Cosmetics", "DeepFreeze", "Formulas", "Items", "Night", "PvP", "Rarities", "ShelfBoxes", "Tools", "Training", "Tutorial", "Upgrades", "Zones" } do
	moduleScript(ConfigF, n, `shared/Config/{n}.luau`)
end
-- a49 (DEV-131) : Config/Mutations, requis par StoreHeistService depuis les mutations (s'il existe dans l'arbre testé).
if SOURCES["shared/Config/Mutations.luau"] then
	moduleScript(ConfigF, "Mutations", "shared/Config/Mutations.luau")
end
-- a104 (vague 31, L-112) : Config/Features, Config/ShelfOpen et Shared/ShelfOpenState, requis par HeistController
-- (s'ils existent dans l'arbre testé). Invite « Open » sans maintien quand HeistController ouvre sur le rayon
-- (OpenShelfBox) et que Features.ShelfOpen est vrai ; sinon l'ancienne invite « Steal ».
-- a103 (2026-11-12, vague 31, L-112) : avec Features.ShelfOpen, StoreHeistService ouvre les colis sur le
-- rayon et refuse la prise d'un colis fermé. Ce banc vérifie l'ancien déroulé (colis porté fermé, invite
-- « Steal »), gardé derrière l'interrupteur : il y est forcé à false, pour le serveur comme pour le client
-- (le nouveau déroulé est vérifié par les bancs a103 et a104). Config/Unbox : requis par StoreHeistService.
if SOURCES["shared/Config/Features.luau"] then
	SOURCES["shared/Config/Features.luau"] = (string.gsub(SOURCES["shared/Config/Features.luau"], "ShelfOpen = true", "ShelfOpen = false"))
end
if SOURCES["shared/Config/Unbox.luau"] then
	moduleScript(ConfigF, "Unbox", "shared/Config/Unbox.luau")
end
for _, n in { "Features", "ShelfOpen" } do
	if SOURCES[`shared/Config/{n}.luau`] then
		moduleScript(ConfigF, n, `shared/Config/{n}.luau`)
	end
end
if SOURCES["shared/ShelfOpenState.luau"] then
	moduleScript(Shared, "ShelfOpenState", "shared/ShelfOpenState.luau")
end
local featuresSource = SOURCES["shared/Config/Features.luau"] or ""
SHELF_OPEN_CLIENT = string.find(SOURCES["client/Controllers/HeistController.luau"], "OpenShelfBox", 1, true) ~= nil
	and string.find(featuresSource, "ShelfOpen = true", 1, true) ~= nil
local ContractF = folder(Shared, "Contract")
for _, n in { "Animations", "Attributes", "Find", "Models", "Tags", "UI" } do
	moduleScript(ContractF, n, `shared/Contract/{n}.luau`)
end
local NetF = folder(Shared, "Net")
for _, n in { "Definitions", "Net", "RateLimiter", "Validate" } do
	moduleScript(NetF, n, `shared/Net/{n}.luau`)
end

local Services = folder(folder(ServerScriptService, "Server"), "Services")
moduleScript(Services, "AntiCheatService", "stub/AntiCheatService") -- a36 (DEV-060) : StoreHeistService déclare ses sorties (Allow)
local HeistModule = moduleScript(Services, "StoreHeistService", "server/Services/StoreHeistService.luau")
local WindowModule = moduleScript(Services, "WindowService", "stub/WindowService.luau")
local CarryModule = moduleScript(Services, "CarryService", "stub/CarryService.luau")
local GuardStubModule = moduleScript(Services, "GuardService", "stub/GuardService.luau") -- a66
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
-- Emplacement de rayon. L'attribut Tier n'est plus lu (L-033) : les emplacements n'en ont pas,
-- sauf le 05 qui porte une valeur fausse (l'ancien code l'aurait ignoré avec un avertissement).
local function slot(shelf, n, world)
	local a = new("Attachment", string.format("ShelfSlot_%02d", n), nil)
	a.CFrame = shelf.CFrame:ToObjectSpace(CFrame.new(world))
	if n == 5 then
		a:SetAttribute("Tier", "Gold")
	end
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
		slot(left, n, (frame * CFrame.new(-10, 3, dz)).Position)
	end
	for _, dz in { -9, -6, -3 } do
		n += 1
		slot(right, n, (frame * CFrame.new(10, 3, dz)).Position)
	end
	for _, dx in { -3, 0, 3 } do
		n += 1
		slot(middle, n, (frame * CFrame.new(dx, 3, 1.5)).Position)
	end
	slot(reserve, 10, (frame * CFrame.new(0, 3, 10.5)).Position)
	return m
end
local superette = buildStore("STORE_Z1_Superette", 1, 60, 34)
superette.Parent = Workspace
addTag(superette, "NPCStore")
local kiosque = buildStore("STORE_Z1_Kiosque", 1, 300, 34)
kiosque.Parent = Workspace
addTag(kiosque, "NPCStore")
local electro = buildStore("STORE_Z3_Electronique", 3, 600, 34)
electro.Parent = Workspace
addTag(electro, "NPCStore")
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

local P = {
	outside = Vector3.new(60, 3, 15), -- devant la vitrine de la Supérette, dehors
	center = Vector3.new(60, 3, 34),
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
local GuardStub = requireModule(GuardStubModule, "server") -- a66
-- a66 : le vigile apparu pour le vol de `player` dans `store` est rentré : le magasin se rouvre pour lui.
local function guardBack(player, store)
	GuardStub._back(player, store)
end
local Anim = requireModule(AnimModule, "client")
local Items = requireModule(ConfigF.Items, "server")
local Night = requireModule(ConfigF.Night, "server")
local Balance = requireModule(ConfigF.Balance, "server")
local Rarities = requireModule(ConfigF.Rarities, "server")
local Tutorial = requireModule(ConfigF.Tutorial, "server")
local GrabRemote -- RemoteEvent GrabItem (créé par le Net du serveur)
local CS = games.server:GetService("CollectionService")

---------------------------------------------------------------- aides
local function boxesOf(store)
	return store:FindFirstChild("ShelfBoxes")
end
local function boxAt(store, n)
	return boxesOf(store):FindFirstChild(string.format("ShelfBox_%02d", n))
end
local function slotId(store, n)
	return string.format("%s/%02d", store.Name, n)
end
local function slotAttachment(store, n)
	return store:FindFirstChild(string.format("ShelfSlot_%02d", n), true)
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
local function isDestroyed(inst)
	return rawget(inst, "_destroyed") == true
end
local function insideBounds(store, position)
	local b = store.Bounds
	local p = b.CFrame:PointToObjectSpace(position)
	return math.abs(p.X) <= b.Size.X / 2 and math.abs(p.Y) <= b.Size.Y / 2 and math.abs(p.Z) <= b.Size.Z / 2
end
-- Joueur posé à 2 studs de l'emplacement n, côté allée (vers le centre du magasin).
local function standNear(player, store, n)
	local at = slotAttachment(store, n).WorldPosition
	local center = store.Bounds.Position
	local toward = Vector3.new(center.X - at.X, 0, center.Z - at.Z).Unit
	moveTo(player, Vector3.new(at.X, 3, at.Z) + toward * 2)
end
-- Numéro de l'emplacement d'un colis posé de ce type (le premier trouvé).
local function findSlot(store, tier)
	for n = 1, 10 do
		local box = boxAt(store, n)
		if box and box:GetAttribute("Tier") == tier and box:GetAttribute("Landed") == true then
			return n
		end
	end
	return nil
end
-- Répartition des types d'un magasin : { Standard = 6, … } et { [n] = Tier }.
local function layoutOf(store)
	local counts, byNumber = {}, {}
	for _, box in boxesOf(store):GetChildren() do
		local tier = box:GetAttribute("Tier")
		counts[tier] = (counts[tier] or 0) + 1
		byNumber[tonumber(string.match(box.Name, "%d+"))] = tier
	end
	return counts, byNumber
end
local function isLayout631(store)
	local counts = layoutOf(store)
	return #boxesOf(store):GetChildren() == 10 and counts.Standard == 6 and counts.Premium == 3 and counts.Luxe == 1
end
local function boxSet(store)
	local set = {}
	for _, box in boxesOf(store):GetChildren() do
		set[box] = true
	end
	return set
end
-- Prise complète (début, maintien du type, fin) de l'emplacement n ; renvoie le payload ou nil.
local function take(player, store, n)
	guardBack(player, store) -- a66 : son vigile d'un vol précédent est rentré
	local box = boxAt(store, n)
	local hold = Balance.Heist.BoxTiers[box:GetAttribute("Tier")].GrabTime
	standNear(player, store, n)
	local before = startedCount()
	grab(player, slotId(store, n))
	advance(hold + 0.05)
	grab(player, slotId(store, n))
	if startedCount() == before + 1 then
		return lastStarted().payload
	end
	print(`  (banc) prise de {player.Name} sur {slotId(store, n)} refusée :`)
	for _, line in LOG do
		if line.kind == "WARN" then
			print("    " .. line.text)
		end
	end
	return nil
end
-- Magasin rouvert (chrono neuf) par `breaker` ; renvoie l'heure de la casse. Laisse aussi passer
-- plus d'une seconde : la limite de GrabItem (5 par seconde, Net) repart de zéro.
local function reopen(store, breaker, refill)
	if Heist.IsOpen(store) then
		W._rebuild(store)
		advance(0.1)
	end
	W._rebuild(store)
	advance(0.1)
	if refill then
		Heist.RefillAll() -- magasin fermé : rayons pleins tout de suite
	end
	W._break(store, breaker)
	local at = now()
	advance(Balance.Heist.BreakerHeadStart + 0.05) -- après l'avance du casseur
	return at
end
local function unexpectedWarnings(allowed)
	local list = {}
	for _, line in LOG do
		if line.kind == "WARN" then
			local ok = false
			for _, pattern in allowed do
				if string.find(line.text, pattern, 1, true) then
					ok = true
				end
			end
			if not ok then
				table.insert(list, line.text)
			end
		end
	end
	return list
end

---------------------------------------------------------------- démarrage
print("== Démarrage : 6 Standard, 3 Premium, 1 Luxe au hasard, contenu tiré à la mise en rayon")
clearLog()
Heist.Init()
GrabRemote = ReplicatedStorage.Remotes.GrabItem
taskLib.spawn(Heist.Start)
check(
	logHas("[StoreHeistService] 3 magasin(s) prêt(s), 30 colis répartis au hasard sur les rayons, contenu tiré à la mise en rayon (modèles BOX_Premium)", "PRINT"),
	"Init : 3 magasins (inbox ignorée), 30 colis, BOX_Premium reconnu"
)
check(boxesOf(inboxStore) == nil, "magasin de _INBOX_CLEMENT ignoré")
check(isLayout631(superette) and isLayout631(kiosque) and isLayout631(electro), "chaque magasin : 6 Standard, 3 Premium, 1 Luxe")
check(#unexpectedWarnings({}) == 0, "aucun avertissement : l'attribut Tier des ShelfSlot n'est plus lu (05 porte « Gold »)")
check(C.labelCalls == 30, "une étiquette BB_Box par colis (CarryService.AttachBoxLabel × 30)")
check(#CS:GetTagged("ShelfBox") == 30, "tag ShelfBox sur chaque colis")
local allOk, noLeak = true, true
for _, store in { superette, kiosque, electro } do
	for _, box in boxesOf(store):GetChildren() do
		local n = tonumber(string.match(box.Name, "ShelfBox_(%d+)"))
		local label = C.labels[box]
		local at = slotAttachment(store, n).WorldPosition
		if
			box:GetAttribute("SlotId") ~= slotId(store, n)
			or box:GetAttribute("Slot") ~= string.format("ShelfSlot_%02d", n)
			or box:GetAttribute("Landed") ~= true
			or box.ModelStreamingMode ~= "Enum.ModelStreamingMode.Atomic"
			or label == nil
			or label.Gui.Parent ~= box
			or (box:GetPivot().Position - at).Magnitude > 1e-6
		then
			allOk = false
			print(
				`  (banc) {box.Name} de {store.Name} : SlotId {box:GetAttribute("SlotId")}, Slot {box:GetAttribute("Slot")}, Landed {box:GetAttribute("Landed")}, streaming {box.ModelStreamingMode}, étiquette {label and label.Gui.Parent == box}, écart {(box:GetPivot().Position - at).Magnitude}`
			)
		end
		local item = label and Items.ById[label.ItemId]
		if item == nil or item.Rarity ~= label.Rarity or (item.Zone ~= nil and item.Zone ~= store:GetAttribute("Zone")) then
			allOk = false
			print(`  (banc) {box.Name} de {store.Name} : contenu {label and label.Rarity} {label and label.ItemId}`)
		end
		for name, value in box:GetAttributes() do
			if name == "ItemId" or name == "Rarity" or (label and value == label.ItemId) then
				noLeak = false
			end
		end
	end
end
check(allOk, "chaque colis : SlotId, Slot, Landed, streaming atomique, posé sur son emplacement, étiquette au contenu valide")
check(noLeak, "aucun attribut ItemId (ni rareté) sur les colis du rayon (5.7)")
local b07 = boxAt(superette, findSlot(superette, "Premium"))
check(b07:FindFirstChild("Tint") ~= nil and b07:FindFirstChild("Junk") == nil, "Premium : clone de BOX_Premium, script retiré")
check(b07.Tint.Anchored == true and b07.Tint.CanCollide == false and b07.Tint.CanQuery == false, "colis ancré, sans collision ni requête")
local shutterOpenY = superette.Shutter.CFrame.Position.Y

print("== Client : HeistController (textes en anglais, temps de prise du colis)")
local Controller = requireModule(ControllerModule, "client")
taskLib.spawn(Controller.Start)
advance(0.3)
local promptsOk = true
for n = 1, 10 do
	local prompt = slotAttachment(superette, n):FindFirstChild("GrabPrompt")
	local tier = boxAt(superette, n):GetAttribute("Tier")
	local info = Balance.Heist.BoxTiers[tier]
	if
		prompt == nil
		or prompt.ActionText ~= (if SHELF_OPEN_CLIENT then "Open" else "Steal")
		or prompt.ObjectText ~= info.DisplayName .. " Box"
		or not near(prompt.HoldDuration, if SHELF_OPEN_CLIENT then 0 else info.GrabTime)
	then
		promptsOk = false
	end
end
check(promptsOk, "une invite par emplacement : « Steal », « <Type> Box », maintien du type du colis")
check(slotAttachment(superette, 1).GrabPrompt.Enabled == false, "invite inactive : magasin fermé")

---------------------------------------------------------------- hasard et raretés
print("== 120 remplissages : placement au hasard, zone 1 Communs, zone 3 selon 7.3")
local refillOk, countOk = true, true
local seen = {} -- [n] = { [Tier] = true } (Supérette)
local zone1 = {} -- raretés vues en zone 1
local zone3 = { Standard = {}, Premium = {}, Luxe = {} } -- raretés vues en zone 3, par type
local itemsOk = true
ITEM_COUNT = {} -- a22 : [ItemId] = nombre de colis tirés
local function record()
	for _, store in { superette, kiosque, electro } do
		if not isLayout631(store) then
			refillOk = false
		end
		for _, box in boxesOf(store):GetChildren() do
			local label = C.labels[box]
			local tier = box:GetAttribute("Tier")
			local zone = store:GetAttribute("Zone")
			local item = Items.ById[label.ItemId]
			ITEM_COUNT[label.ItemId] = (ITEM_COUNT[label.ItemId] or 0) + 1 -- a22
			if item.Rarity ~= label.Rarity or (item.Zone ~= nil and item.Zone ~= zone) then
				itemsOk = false
			end
			if zone == 1 then
				zone1[label.Rarity] = true
				if table.find(Items.ByZone[1].Common, item) == nil then -- a22 : plusieurs Communs tirables
					itemsOk = false
				end
			else
				zone3[tier][label.Rarity] = true
			end
		end
	end
	local _, byNumber = layoutOf(superette)
	for n, tier in byNumber do
		seen[n] = seen[n] or {}
		seen[n][tier] = true
	end
end
record()
for _ = 1, 120 do
	if Heist.RefillAll() ~= 30 then
		countOk = false
	end
	record()
end
check(countOk, "RefillAll renvoie 30 à chaque fois (aucun magasin ouvert)")
check(refillOk, "chaque remplissage : 6 Standard, 3 Premium, 1 Luxe par magasin")
local everyTier = true
for n = 1, 10 do
	local s = seen[n] or {}
	if not (s.Standard and s.Premium and s.Luxe) then
		everyTier = false
	end
end
check(everyTier, "chaque emplacement a reçu les 3 types (placement au hasard, L-033)")
local onlyCommon = true
for rarity in zone1 do
	if rarity ~= "Common" then
		onlyCommon = false
	end
end
check(onlyCommon and zone1.Common, "zone 1 : uniquement des Communs, pour les trois types (L-033)")
check(itemsOk, "objet tiré de la bonne rareté et de la bonne zone (zone 1 : un Commun tirable)")
-- a22 : répartition du tirage au catalogue v2 (Items.Pick), sur les 121 remplissages ci-dessus.
-- Zone 1 : 2 magasins × 121 × 10 colis, tous Communs ; zone 3 : 121 × 10 colis (7.3).
do
	local function share(ids, total)
		local low, high = math.huge, 0
		for _, item in ids do
			local n = ITEM_COUNT[item.Id] or 0
			low = math.min(low, n / total)
			high = math.max(high, n / total)
		end
		return low, high
	end
	local zone1Total = 0
	for _, item in Items.ByZone[1].Common do
		zone1Total += ITEM_COUNT[item.Id] or 0
	end
	check(zone1Total == 2 * 121 * 10, `a22 : zone 1, {zone1Total} colis, tous des 12 Communs tirables`)
	local low, high = share(Items.ByZone[1].Common, zone1Total)
	check(low >= 0.05 and high <= 0.12, `a22 : zone 1, chaque Commun entre 5 % et 12 % des colis (attendu 8,3 % ; vu {math.floor(low * 1000) / 10} à {math.floor(high * 1000) / 10} %)`)
	check((ITEM_COUNT["Z1_PotDeNouilles"] or 0) == 0, "a22 : le Pot de nouilles (TutorialOnly) ne sort d'aucun tirage")
	for _, rarity in { "Common", "Uncommon", "Rare", "Epic" } do
		local list = Items.ByZone[3][rarity]
		local total = 0
		for _, item in list do
			total += ITEM_COUNT[item.Id] or 0
		end
		local lowR, highR = share(list, total)
		local expected = 1 / #list
		check(
			total > 0 and lowR > 0 and lowR >= expected * 0.6 and highR <= expected * 1.4,
			`a22 : zone 3 {rarity}, {#list} objets tirés à parts proches ({total} colis, {math.floor(lowR * 100)} à {math.floor(highR * 100)} %, attendu {math.floor(expected * 100)} %)`
		)
	end
end
check(zone3.Luxe.Common == nil and zone3.Standard.Legendary == nil and zone3.Standard.Secret == nil and zone3.Premium.Secret == nil, "zone 3 : raretés impossibles jamais tirées (7.3)")
local stdCount = 0
for _ in zone3.Standard do
	stdCount += 1
end
check(stdCount >= 3 and zone3.Luxe.Rare and zone3.Premium.Uncommon, "zone 3 : tirage varié selon Rarities.BoxOdds")
check(C.labelCalls == 30 * 121, "une étiquette par colis à chaque remplissage")
check(#CS:GetTagged("ShelfBox") == 30, "anciens colis détruits (tag retiré), 30 colis en place")
advance(0.3)
check(#boxesOf(superette):GetChildren() == 10, "client : toujours 10 colis")
local promptCount = 0
for n = 1, 10 do
	for _, child in slotAttachment(superette, n):GetChildren() do
		if child.Name == "GrabPrompt" then
			promptCount += 1
		end
	end
end
check(promptCount == 10, "client : une seule invite par emplacement après les remplissages")

---------------------------------------------------------------- prise
print("== Prise : le contenu tiré à la mise en rayon, le temps du colis")
W._break(superette, p1)
local tBreak = now()
advance(0.05)
local nStd = findSlot(superette, "Standard")
local labelStd = C.labels[boxAt(superette, nStd)]
standNear(p1, superette, nStd)
advance(0.25)
check(slotAttachment(superette, nStd).GrabPrompt.Enabled == true, "client : invite active (casseur, dedans, mains vides)")
clearLog()
grab(p1, slotId(superette, nStd))
advance(0.1)
grab(p1, slotId(superette, nStd))
check(startedCount() == 0 and logHas("maintien trop court", "WARN"), "Standard : fin à 0,1 s refusée")
advance(0.25)
grab(p1, slotId(superette, nStd))
check(startedCount() == 1, "Standard : fin à 0,35 s acceptée")
local pay = lastStarted().payload
check(pay.Kind == "NPCBox" and pay.Tier == "Standard" and pay.Zone == 1, "payload : Kind, Tier du colis, Zone")
check(pay.Rarity == labelStd.Rarity and pay.ItemId == labelStd.ItemId, "payload = contenu de l'étiquette (tiré à la mise en rayon)")
check(pay.Rarity == "Common", "zone 1 : colis Commun")
check(pay.StoreId == "STORE_Z1_Superette" and pay.SlotId == slotId(superette, nStd), "payload : StoreId, SlotId")
check(boxAt(superette, nStd) == nil, "l'emplacement se vide")
check(logHas(`P1 prend le colis Standard ShelfSlot_{string.format("%02d", nStd)} de STORE_Z1_Superette : Common`, "PRINT"), "sortie Studio de la prise")

print("== Échec du porteur : retour avec le contenu d'origine")
-- 2026-11-10 : « Died » plutôt que « Caught » : un joueur attrapé ne reprend plus de colis dans ce magasin
-- jusqu'à sa réouverture (règle par joueur, Cantin) ; le retour du colis est le même.
C.Fail(p1, "Died")
advance(0.1)
local back = boxAt(superette, nStd)
check(back ~= nil and back:GetAttribute("Landed") == false and back:GetAttribute("Tier") == "Standard", "colis rendu : en vol vers son emplacement, même type")
check(C.labels[back].Rarity == labelStd.Rarity and C.labels[back].ItemId == labelStd.ItemId, "colis rendu : même contenu (étiquette)")
advance(1.6)
check(back:GetAttribute("Landed") == true and (back:GetPivot().Position - slotAttachment(superette, nStd).WorldPosition).Magnitude < 1e-6, "colis rendu : posé sur son emplacement")
check(logHas(`colis Standard de P1 (Died) : revient sur {slotId(superette, nStd)}`, "PRINT"), "sortie Studio du retour")
advance(1.1)
local again = take(p1, superette, nStd)
check(again ~= nil and again ~= pay and again.ItemId == labelStd.ItemId and again.Rarity == labelStd.Rarity, "reprise : même contenu, nouveau payload (nouvelle table)")
C.Consume(p1)
check(Heist.ReturnBox(again) == false, "colis posé sur un établi : ReturnBox refusé")

print("== Luxe 1,0 s et Premium 0,6 s (type du colis)")
reopen(superette, p1)
local nLux = findSlot(superette, "Luxe")
standNear(p1, superette, nLux)
advance(0.25)
check(near(slotAttachment(superette, nLux).GrabPrompt.HoldDuration, if SHELF_OPEN_CLIENT then 0 else 1.0), "client : invite du Luxe à 1,0 s, où qu'il soit (a104 : « Open » sans maintien avec ShelfOpen)")
local before = startedCount()
grab(p1, slotId(superette, nLux))
advance(0.85)
grab(p1, slotId(superette, nLux))
check(startedCount() == before, "Luxe : fin à 0,85 s refusée")
advance(0.1)
grab(p1, slotId(superette, nLux))
check(startedCount() == before + 1 and lastStarted().payload.Tier == "Luxe", "Luxe : fin à 0,95 s acceptée (tolérance 0,1 s)")
check(lastStarted().payload.Rarity == "Common", "Luxe de la zone 1 : Commun (L-033)")
C.Consume(p1)
advance(1.1) -- limite de GrabItem
guardBack(p1, superette) -- a66 : son vigile du Luxe est rentré
local nPrem = findSlot(superette, "Premium")
standNear(p1, superette, nPrem)
before = startedCount()
grab(p1, slotId(superette, nPrem))
advance(0.45)
grab(p1, slotId(superette, nPrem))
check(startedCount() == before, "Premium : fin à 0,45 s refusée")
advance(0.2)
grab(p1, slotId(superette, nPrem))
check(startedCount() == before + 1 and lastStarted().payload.Tier == "Premium", "Premium : fin à 0,65 s acceptée")
C.Consume(p1)

print("== Refus de CarryService : le colis reste")
reopen(superette, p1)
local nRef = findSlot(superette, "Standard")
local boxRef = boxAt(superette, nRef)
standNear(p1, superette, nRef)
before = startedCount()
grab(p1, slotId(superette, nRef))
advance(0.35)
C.refuseNext = true
grab(p1, slotId(superette, nRef))
check(C.refuseNext == false, "le refus est bien passé par StartCarry")
check(startedCount() == before and boxAt(superette, nRef) == boxRef and not isDestroyed(boxRef), "StartCarry refusé : le même colis reste sur l'emplacement")
advance(1.1)
check(take(p1, superette, nRef) ~= nil, "puis prise normale du même colis")
C.Consume(p1)

---------------------------------------------------------------- remplissage reporté
print("== RefillAll pendant le chrono : reporté à la fermeture")
tBreak = reopen(superette, p1)
local nOut = findSlot(superette, "Standard")
local carried = take(p1, superette, nOut) -- P1 sort un colis avant la nuit
check(carried ~= nil, "P1 porte un colis de la Supérette")
local setBefore = boxSet(superette)
clearLog()
local filledNow = Heist.RefillAll()
check(filledNow == 20, "RefillAll : 20 colis posés tout de suite (Kiosque, Électronique) : " .. tostring(filledNow))
check(logHas("1 magasin(s) ouvert(s) rempli(s) à leur fermeture", "PRINT"), "sortie Studio : la Supérette attend sa fermeture")
local same = true
for box in boxSet(superette) do
	if not setBefore[box] then
		same = false
	end
end
for box in setBefore do
	if isDestroyed(box) then
		same = false
	end
end
check(same, "Supérette : aucun colis ne change pendant le chrono")
moveTo(p2, P.center)
advance(tBreak + 10 - now() - 0.05)
check(Heist.IsOpen(superette), "encore ouvert juste avant 10 s")
clearLog()
advance(0.1)
check(not Heist.IsOpen(superette), "fermé à 10 s")
check(logHas("STORE_Z1_Superette : remplissage reporté à la fermeture, 10 colis répartis au hasard", "PRINT"), "nouveau tirage à la fermeture")
check(isLayout631(superette), "Supérette : 10 colis neufs, 6/3/1")
local renewed = true
for box in boxSet(superette) do
	if setBefore[box] then
		renewed = false
	end
end
check(renewed, "tous les colis de la Supérette sont neufs")
check(not insideBounds(superette, rootOf(p2)), "P2 (sans colis) sorti")
-- Correctif du 2026-11-08 (décision d'Ironix, L-064) : le rideau attend que le porteur P1, encore
-- dedans, et les vigiles (Workspace/ActiveGuards) soient sortis du volume Bounds.
advance(0.5)
check(near(superette.Shutter.CFrame.Position.Y, shutterOpenY, 1e-6), "rideau levé tant que le porteur P1 est dedans")
check(logHas("rideau baissé dès que plus personne n'est dedans (pour l'instant : P1 porte un colis)", "PRINT"), "sortie Studio : le rideau attend le porteur")
local guardsFolder = new("Folder", "ActiveGuards", Workspace)
local fakeGuard = new("Model", "Guard_Test", guardsFolder)
local fakeGuardRoot = block(fakeGuard, "HumanoidRootPart", CFrame.new(), P.center, Vector3.new(2, 2, 1))
moveTo(p1, P.far)
advance(0.5)
check(near(superette.Shutter.CFrame.Position.Y, shutterOpenY, 1e-6), "porteur sorti, vigile encore dedans : rideau toujours levé")
fakeGuardRoot.CFrame = CFrame.new(P.outside)
advance(0.2)
check(logHas("STORE_Z1_Superette : rideau baissé, porteurs et vigiles sortis", "PRINT"), "sortie Studio : rideau baissé une fois porteur et vigile sortis")
advance(0.5)
check(near(superette.Shutter.CFrame.Position.Y, shutterOpenY - 7.5, 1e-6), "rideau tombé")

print("== Colis sorti avant le remplissage : perdu à l'échec (nouveau tirage)")
-- P2 vide l'emplacement d'où venait le colis de P1 : même vide, il ne doit pas le reprendre.
moveTo(p1, P.far) -- P1 garde son colis, loin du magasin
reopen(superette, p2)
local p2box = take(p2, superette, nOut)
check(p2box ~= nil and boxAt(superette, nOut) == nil, "P2 prend le nouveau colis de cet emplacement : il est vide")
clearLog()
C.Fail(p1, "Died")
advance(2)
check(boxAt(superette, nOut) == nil, "le colis d'avant le remplissage ne revient pas, même sur un emplacement vide")
check(#boxesOf(superette):GetChildren() == 9, "9 colis (celui de P2 est sorti)")
check(logHas(`ne revient pas sur {slotId(superette, nOut)}`, "PRINT"), "sortie Studio du colis perdu")
check(Heist.ReturnBox(carried) == false, "ReturnBox du même payload : false")
C.Fail(p2, "Caught")
advance(2)
check(boxAt(superette, nOut) ~= nil and C.labels[boxAt(superette, nOut)].ItemId == p2box.ItemId, "le colis de P2 (tirage en cours) revient, lui")

print("== Colis en vol de retour au moment d'un remplissage")
reopen(superette, p1)
local nFly = findSlot(superette, "Standard")
local flying = take(p1, superette, nFly)
check(flying ~= nil, "P1 prend un colis")
C.Fail(p1, "Caught")
advance(0.1)
local flyingBox = boxAt(superette, nFly)
check(flyingBox ~= nil and flyingBox:GetAttribute("Landed") == false, "colis en vol vers son emplacement")
W._rebuild(superette) -- ferme le magasin (vitrine reconstruite)
advance(0.1)
check(not Heist.IsOpen(superette), "magasin fermé")
Heist.RefillAll()
check(isDestroyed(flyingBox), "colis en vol retiré par le remplissage")
advance(2)
check(isLayout631(superette), "10 colis, 6/3/1, aucun doublon")
local allLanded = true
for _, box in boxesOf(superette):GetChildren() do
	if box:GetAttribute("Landed") ~= true then
		allLanded = false
	end
end
check(allLanded, "tous posés")

print("== Colis au sol (M3) : ReturnBox le remet sur son emplacement")
reopen(superette, p1)
local nDrop = findSlot(superette, "Premium")
local labelDrop = C.labels[boxAt(superette, nDrop)]
local dropped = take(p1, superette, nDrop)
C.Drop(p1) -- résultat « Dropped » : pas de retour tout de suite
advance(0.5)
check(boxAt(superette, nDrop) == nil, "Dropped : rien ne revient tout de suite")
check(Heist.ReturnBox(dropped) == true, "ReturnBox(payload) au bout du délai : true")
local dropBack = boxAt(superette, nDrop)
check(dropBack ~= nil and dropBack:GetAttribute("Tier") == "Premium" and C.labels[dropBack].ItemId == labelDrop.ItemId, "remis avec son type et son contenu")
check(Heist.ReturnBox(dropped) == false, "pas deux fois")
check(Heist.ReturnBox({ Kind = "NPCBox", StoreId = "STORE_Z1_Superette", SlotId = slotId(superette, 1), Tier = "Standard", Rarity = "Common", ItemId = Items.ByZone[1].Common[1].Id }) == false, "payload jamais sorti : false")
check(Heist.ReturnBox({ Kind = "Item" }) == false, "objet volé à un joueur : false")

---------------------------------------------------------------- accroche du tuto
print("== Accroche du tuto : SetContentOverride")
local calls = {}
Heist.SetContentOverride(function(player, drawn)
	table.insert(calls, drawn)
	if player == p1 then
		return { Tier = Tutorial.FirstBoxTier, ItemId = Tutorial.GuaranteedItemId } -- 5.11 : 1er colis Premium, objet Rare garanti (a22)
	end
	return nil
end)
advance(1.1)
local nTuto = findSlot(superette, "Standard")
local labelTuto = C.labels[boxAt(superette, nTuto)]
clearLog()
local tuto = take(p1, superette, nTuto)
check(tuto ~= nil and tuto.Tier == "Premium" and tuto.Rarity == "Rare" and tuto.ItemId == "Z1_PotDeNouilles", "P1 reçoit un colis Premium Rare : le Pot de nouilles (Tutorial.GuaranteedItemId)")
local drawn = calls[#calls]
check(
	drawn.StoreId == "STORE_Z1_Superette" and drawn.SlotId == slotId(superette, nTuto) and drawn.Zone == 1 and drawn.Tier == "Standard"
		and drawn.Rarity == labelTuto.Rarity and drawn.ItemId == labelTuto.ItemId,
	"l'accroche reçoit le contenu du colis du rayon"
)
check(logHas("accroche du tuto : P1 reçoit un colis Premium Rare (Z1_PotDeNouilles)", "PRINT"), "sortie Studio du remplacement")
C.Fail(p1, "Caught")
advance(2)
local tutoBack = boxAt(superette, nTuto)
check(tutoBack:GetAttribute("Tier") == "Standard" and C.labels[tutoBack].Rarity == "Common" and C.labels[tutoBack].ItemId == labelTuto.ItemId, "colis rendu : son type et son contenu d'origine (pas le Rare du tuto)")
moveTo(p2, P.center)
advance(0.2)
local nOther = findSlot(superette, "Standard")
local p2pay = take(p2, superette, nOther)
check(p2pay ~= nil and p2pay.Rarity == "Common" and p2pay.Tier == "Standard", "accroche sans remplacement (nil) pour P2 : contenu du rayon")
C.Consume(p2)
local function overrideCase(fn, label, warning)
	Heist.SetContentOverride(fn)
	reopen(superette, p1, true)
	local n = findSlot(superette, "Standard")
	local original = C.labels[boxAt(superette, n)]
	clearLog()
	local got = take(p1, superette, n)
	check(
		got ~= nil and got.Tier == "Standard" and got.Rarity == original.Rarity and got.ItemId == original.ItemId and logHas(warning, "WARN"),
		label
	)
	C.Consume(p1)
end
overrideCase(function() return { Tier = "Gold" } end, "type inconnu : ignoré, avertissement", "type de colis inconnu")
overrideCase(function() return { ItemId = "Z3_Smartphone" } end, "objet d'une autre zone : ignoré", "pas de la zone 1")
overrideCase(function() return { ItemId = Tutorial.GuaranteedItemId, Rarity = "Epic" } end, "objet et rareté qui ne vont pas ensemble : ignoré", "pas Epic")
overrideCase(function() return { Rarity = "Rare" } end, "a22 : Rarity seule Rare en zone 1 : aucun Rare tirable (Pot de nouilles TutorialOnly), ignorée", "aucun objet Rare en zone 1")
overrideCase(function() error("boum") end, "accroche en erreur : ignorée", "accroche SetContentOverride")
overrideCase(function() return 42 end, "accroche qui ne renvoie pas une table : ignorée", "pas une table")
Heist.SetContentOverride(function() return { Rarity = "Secret" } end)
reopen(superette, p1, true)
local secret = take(p1, superette, findSlot(superette, "Standard"))
check(secret ~= nil and secret.Rarity == "Secret" and secret.ItemId == Items.Secrets[1].Id, "Rarity seule : un objet de cette rareté est tiré (Secret, toutes zones)")
C.Consume(p1)
Heist.SetContentOverride(nil)
advance(1.1)
local plain = take(p1, superette, findSlot(superette, "Standard"))
check(plain ~= nil and plain.Rarity == "Common", "SetContentOverride(nil) : accroche retirée")
C.Consume(p1)

---------------------------------------------------------------- reste
print("== OnBoxGrabbed")
local grabbed = {}
Heist.OnBoxGrabbed(function(player, payload)
	table.insert(grabbed, { player, payload })
end)
advance(1.1)
local nGrab = findSlot(superette, "Standard")
local gp = take(p1, superette, nGrab)
check(#grabbed == 1 and grabbed[1][1] == p1 and grabbed[1][2] == gp, "OnBoxGrabbed(player, payload) après la prise")
C.Consume(p1)

print("== Plus de remplissage V0 automatique (a21, DEV-047 : la nuit s'en charge)")
moveTo(p1, P.far)
moveTo(p2, P.far)
advance(11)
W._rebuild(superette)
local beforeCount = #boxesOf(superette):GetChildren()
clearLog()
advance(Night.CycleDuration)
check(not logHas("rayons remplis (nouveau tirage)", "PRINT"), "a21 : plus de RefillAll tout seul après Night.CycleDuration")
check(#boxesOf(superette):GetChildren() == beforeCount and beforeCount < 10, "a21 : rayons toujours à " .. beforeCount .. " (pas rempli avant la nuit)")
Heist.RefillAll() -- comme NightCycleService à la tombée de la nuit
check(isLayout631(superette), "a21 : RefillAll (tombée de la nuit) remplit les rayons (6/3/1)")

print("== Départ d'un joueur")
p2.Parent = nil
Players.PlayerRemoving:Fire(p2)
advance(0.5)
check(true, "aucune erreur au départ")

print("== Avertissements hors refus attendus")
local unexpected = 0
for _, line in FULL_LOG do
	if
		line.kind == "WARN"
		and not string.find(line.text, "GrabItem de", 1, true)
		and not string.find(line.text, "accroche SetContentOverride", 1, true)
	then
		unexpected += 1
		print("  WARN " .. line.side .. " : " .. line.text)
	end
end
check(unexpected == 0, "aucun autre avertissement (Net, envois mal formés, erreurs)")
summary()
