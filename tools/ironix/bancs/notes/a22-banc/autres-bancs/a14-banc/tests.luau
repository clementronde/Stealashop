--!nocheck
-- Scénarios du banc d'essai de DisplayService et DisplayController (DEV-020, agent a14).
-- DataService et PlotService sont des bouchons qui suivent leur API (attribution, libération,
-- chargement et libération du profil) ; Config, Contract et Net sont les vrais modules.

---------------------------------------------------------------- bouchons des services voisins
SOURCES["stub/DataService"] = [==[
local DataService = {}
local profiles = {}
local loaded, releasing = {}, {}
local function subscribe(list, fn)
	table.insert(list, fn)
	return function()
		local i = table.find(list, fn)
		if i then table.remove(list, i) end
	end
end
function DataService.Get(player) return profiles[player] end
function DataService.IsLoaded(player) return profiles[player] ~= nil end
function DataService.OnProfileLoaded(fn)
	local off = subscribe(loaded, fn)
	for p in profiles do task.spawn(fn, p) end
	return off
end
function DataService.OnProfileReleasing(fn) return subscribe(releasing, fn) end
function DataService.AddCash(player, amount)
	local d = profiles[player]
	if d == nil or type(amount) ~= "number" or amount ~= amount or amount < 0 or amount == math.huge then return nil end
	d.Cash += amount
	return d.Cash
end
function DataService._load(player, data)
	profiles[player] = data
	for _, fn in table.clone(loaded) do task.spawn(fn, player) end
end
-- Comme DataService : écouteurs appelés avant la libération, profil encore actif.
function DataService._release(player)
	if profiles[player] == nil then return end
	for _, fn in table.clone(releasing) do
		local ok, err = pcall(fn, player)
		if not ok then warn("OnProfileReleasing : " .. tostring(err)) end
	end
	profiles[player] = nil
end
return DataService
]==]

SOURCES["stub/PlotService"] = [==[
local PlotService = {}
local plotOf, ownerOf = {}, {}
local assigned, released = {}, {}
local function subscribe(list, fn)
	table.insert(list, fn)
	return function()
		local i = table.find(list, fn)
		if i then table.remove(list, i) end
	end
end
function PlotService.GetPlot(player) return plotOf[player] end
function PlotService.GetOwner(plot) return ownerOf[plot] end
function PlotService.OnPlotAssigned(fn)
	local off = subscribe(assigned, fn)
	for p, plot in table.clone(plotOf) do task.spawn(fn, p, plot) end
	return off
end
function PlotService.OnPlotReleased(fn) return subscribe(released, fn) end
function PlotService._assign(player, plot)
	plotOf[player] = plot
	ownerOf[plot] = player
	plot:SetAttribute("OwnerUserId", player.UserId)
	player:SetAttribute("PlotIndex", plot:GetAttribute("PlotIndex"))
	for _, fn in table.clone(assigned) do task.spawn(fn, player, plot) end
end
-- Comme PlotService : écouteurs appelés après OwnerUserId = 0, sans yield.
function PlotService._release(player)
	local plot = plotOf[player]
	if plot == nil then return end
	plotOf[player] = nil
	ownerOf[plot] = nil
	plot:SetAttribute("OwnerUserId", 0)
	player:SetAttribute("PlotIndex", nil)
	for _, fn in table.clone(released) do
		local ok, err = pcall(fn, player, plot)
		if not ok then warn("OnPlotReleased : " .. tostring(err)) end
	end
end
return PlotService
]==]

---------------------------------------------------------------- montage de l'arbre
local function mount(rootFolder, prefix)
	local keys = {}
	for key in SOURCES do
		if string.sub(key, 1, #prefix) == prefix then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	for _, key in keys do
		local rel = string.sub(key, #prefix + 1)
		local parts = string.split(rel, "/")
		local parent = rootFolder
		for i = 1, #parts - 1 do
			parent = parent:FindFirstChild(parts[i]) or folder(parent, parts[i])
		end
		local name = string.gsub(parts[#parts], "%.luau$", "")
		moduleScript(parent, name, key)
	end
end

local Shared = folder(ReplicatedStorage, "Shared")
mount(Shared, "shared/")
local Server = folder(ServerScriptService, "Server")
local Services = folder(Server, "Services")
moduleScript(Services, "DataService", "stub/DataService")
moduleScript(Services, "PlotService", "stub/PlotService")
local displayModule = moduleScript(Services, "DisplayService", "server/Services/DisplayService.luau")
local Client = folder(StarterPlayerScripts, "Client")
local Controllers = folder(Client, "Controllers")
local controllerModule = moduleScript(Controllers, "DisplayController", "client/Controllers/DisplayController.luau")

---------------------------------------------------------------- décor de test
local SLOT_X = { -10, -5, 0, 5, 10 }
local SLOT_Z = { -8, -4, 0, 4 }
local function buildPlot(index)
	local plot = new("Model", { Name = string.format("PLOT_Test_%02d", index) })
	plot:SetAttribute("PlotIndex", index)
	local i = 0
	for _, z in SLOT_Z do
		for _, x in SLOT_X do
			i += 1
			local stand = new("Part", {
				Name = string.format("DisplayStand_%02d", i),
				Anchored = true,
				Size = Vector3.new(2, 2.5, 2),
				CFrame = CFrame.new(x, 1.25, z),
			}, plot)
			local slot = new("Attachment", { Name = string.format("DisplaySlot_%02d", i) }, stand)
			slot.WorldPosition = Vector3.new(x, 2.5, z)
		end
	end
	new("Part", { Name = "CashPad", Anchored = true, CanCollide = false, Size = Vector3.new(6, 0.3, 6), CFrame = CFrame.new(24, 0.15, -30) }, plot)
	new("Part", { Name = "Bounds", Anchored = true, Transparency = 1, CanCollide = false, Size = Vector3.new(64, 24, 80), CFrame = CFrame.new(0, 12.1, 0) }, plot)
	plot.Parent = Workspace
	addTag(plot, "PlayerPlot")
	return plot
end

local function newPlayer(name, userId)
	local player = new("Player", { Name = name, UserId = userId, DisplayName = name }, Players)
	local character = new("Model", { Name = name }, Workspace)
	local root = new("Part", { Name = "HumanoidRootPart", Size = Vector3.new(2, 2, 1), CFrame = CFrame.new(0, 3, 20) }, character)
	new("Humanoid", {}, character)
	player.Character = character
	return player, root, character
end

local function newProfile()
	return {
		Version = 1,
		Cash = 0,
		Stats = { Speed = 0, Strength = 0 },
		Upgrades = { Treadmill = 0, Bench = 0, DisplaySlots = 0, UnboxBenches = 0 },
		Tools = { Owned = { "Fists" }, Equipped = "Fists" },
		Cosmetics = { Auras = {}, Trails = {} },
		Items = {},
		Display = {},
		Vault = {},
		Boxes = {},
		Tutorial = { Step = 0, Done = false },
		Lifetime = { Heists = 0, Steals = 0, Defenses = 0, PlaySeconds = 0 },
		Purchases = {},
	}
end

local nextUid = 1
local function give(data, id, extra)
	local uid = string.format("uid-%03d", nextUid)
	nextUid += 1
	data.Items[uid] = { Id = id, Source = "NPC", At = 0 }
	for k, v in extra or {} do
		data.Items[uid][k] = v
	end
	return uid
end

local function slotOf(data, uid)
	for key, stored in data.Display do
		if stored == uid then
			return tonumber(key)
		end
	end
	return nil
end

local function displayCount(data)
	local n = 0
	for _ in data.Display do
		n += 1
	end
	return n
end

local function item(plot, slot)
	local f = plot:FindFirstChild("DisplayItems")
	return f and f:FindFirstChild(string.format("DisplayItem_%02d", slot))
end

local function label(model, name)
	local bb = model:FindFirstChild("BB_Item")
	return bb and bb:FindFirstChild(name, true)
end

local function lastNotify(player)
	local list = notifies(player)
	return list[#list]
end

local function rarityColor(id)
	local hexes = { Common = "B0B7C3", Uncommon = "2FE08F", Rare = "2F9BFF", Epic = "A855F7", Legendary = "FFC21A", Mythic = "FF3B5C" }
	return Color3.fromHex("#" .. hexes[id])
end

---------------------------------------------------------------- démarrage
local DataService = requireModule(Services.DataService, "server")
local PlotService = requireModule(Services.PlotService, "server")
local DisplayService = requireModule(displayModule, "server")
DisplayService.Init()
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
check(Remotes ~= nil and Remotes:FindFirstChild("PlaceItem") ~= nil, "Net a créé ReplicatedStorage/Remotes/PlaceItem")

local cashOuts = {}
DisplayService.OnCashOut(function(player, amount, source)
	table.insert(cashOuts, { player = player, amount = amount, source = source, t = now() })
end)

-- Envoi du remote par le client, espacé pour rester sous le débit de Net (5/s).
local function placeItem(uid, slot)
	Remotes.PlaceItem:FireServer(uid, slot)
	step(0.25)
end

local plot1 = buildPlot(1)
local alice, aliceRoot, aliceCharacter = newPlayer("Alice", 1)
CLIENT_PLAYER = alice

print("== 1. Installation de la boutique sauvegardée")
local data = newProfile()
local can = give(data, "Z1_CanetteDeSoda") -- Commun zone 1 : 1 $/s
local phone = give(data, "Z3_Smartphone") -- Rare zone 3 : 60 × 5 = 300 $/s
local ticket = give(data, "Z2_PelucheGeante") -- a22 (catalogue v2 : Ticket retiré) : Légendaire zone 2 : 8 × 50 = 400 $/s
local unknown = give(data, "Z9_Inexistant")
data.Display = { ["1"] = can, ["2"] = phone, ["3"] = "uid-absent", ["7"] = ticket, ["abc"] = can, ["4"] = unknown, ["03"] = ticket }
DataService._load(alice, data)
check(plot1:FindFirstChild("DisplayItems") == nil, "profil chargé sans parcelle : rien d'affiché")
PlotService._assign(alice, plot1)
check(plot1:FindFirstChild("DisplayItems") ~= nil, "dossier DisplayItems créé dans la parcelle")
check(data.Display["1"] == can and data.Display["2"] == phone and displayCount(data) == 2, "Display nettoyé : restent les présentoirs 1 et 2")
check(logHas('Display["3"] retiré (objet uid-absent absent de Items)', "WARN"), "avertissement : objet absent de Items")
check(logHas('Display["7"] retiré (présentoir 7 verrouillé (4 débloqué(s)))', "WARN"), "avertissement : présentoir verrouillé")
check(logHas('Display["abc"] retiré (numéro de présentoir invalide)', "WARN"), "avertissement : clé invalide")
check(logHas('Display["03"] retiré (numéro de présentoir invalide)', "WARN"), "avertissement : clé non canonique 03")
check(logHas("Z9_Inexistant", "WARN"), "avertissement : ItemId inconnu du catalogue")
check(data.Items[ticket] ~= nil and data.Items[unknown] ~= nil, "les objets retirés de Display restent dans Items")
check(alice:GetAttribute("Income") == 301, "Income = 1 + 300 = 301 $/s (" .. tostring(alice:GetAttribute("Income")) .. ")")
check(DisplayService.GetIncome(alice) == 301, "GetIncome = 301")
check(alice:GetAttribute("DisplaySlotsUnlocked") == 4, "DisplaySlotsUnlocked = 4 (Balance.Display.StartSlots)")
check(plot1:GetAttribute("CashRegister") == 0, "CashRegister = 0 au départ")
check(alice:GetAttribute("CashCollected") == 0, "CashCollected = 0 au départ")
check(logHas("Alice : 2 objet(s) exposé(s) sur 4 présentoir(s) débloqué(s), revenu $301/s", "PRINT"), "message d'installation")

local canModel = item(plot1, 1)
check(canModel ~= nil and item(plot1, 2) ~= nil and item(plot1, 3) == nil, "DisplayItem_01 et _02 présents, pas _03")
check(canModel:GetAttribute("ItemUid") == can and canModel:GetAttribute("ItemId") == "Z1_CanetteDeSoda", "attributs ItemUid et ItemId")
check(canModel:GetAttribute("Rarity") == "Common" and canModel:GetAttribute("Halo") == "None", "attributs Rarity et Halo")
check(canModel:GetAttribute("Income") == 1 and canModel:GetAttribute("DisplaySlot") == 1, "attributs Income et DisplaySlot")
check(canModel.ModelStreamingMode == Enum.ModelStreamingMode.Atomic, "a22 : objet exposé en ModelStreamingMode Atomic (il arrive en entier chez les clients, ItemIdleController)")
check(canModel:GetAttribute("OwnerUserId") == 1 and canModel:GetAttribute("Placeholder") == true, "attributs OwnerUserId et Placeholder")
check(CollectionServiceStub:HasTag(canModel, "DisplayItem"), "tag DisplayItem")
check(canModel:FindFirstChild("RarityHalo") == nil, "Commun : aucun halo")
local canRoot = canModel.PrimaryPart
check(canRoot ~= nil and canRoot.Name == "Root" and canRoot.Anchored and not canRoot.CanCollide, "bloc V0 : Root ancré, sans collision")
check(near(canRoot.Position.Y, 2.5 + 0.8) and near(canRoot.Position.X, -10) and near(canRoot.Position.Z, -8), "bloc V0 posé sur DisplaySlot_01, pivot en bas")
check(canRoot.Color == rarityColor("Common"), "bloc V0 à la couleur de la rareté")
local canBillboard = canModel:FindFirstChild("BB_Item")
check(canBillboard ~= nil and canBillboard.ClassName == "BillboardGui", "billboard V0 BB_Item")
check(canBillboard.Adornee ~= nil and canBillboard.Adornee.Name == "BillboardPoint", "billboard accroché à BillboardPoint")
check(near(canBillboard.Adornee.WorldPosition.Y, 2.5 + 1.6), "BillboardPoint au sommet de l'objet")
check(label(canModel, "ItemName").Text == "Soda Can", "billboard : ItemName (anglais, catalogue v2)")
check(label(canModel, "Rarity").Text == "COMMON" and label(canModel, "Rarity").TextColor3 == rarityColor("Common"), "billboard : Rarity et sa couleur")
check(label(canModel, "Income").Text == "+$1/s", "billboard : Income « 1 $/s »")
local phoneModel = item(plot1, 2)
local phoneHalo = phoneModel:FindFirstChild("RarityHalo")
check(phoneHalo ~= nil and phoneHalo.Transparency == 1 and not phoneHalo.CanCollide and phoneHalo.Anchored, "Rare : halo invisible, ancré, sans collision")
check(phoneHalo:FindFirstChild("HaloLight").Color == rarityColor("Rare") and phoneHalo:FindFirstChild("HaloLight").Brightness == 1.5, "halo net : lumière bleue")
check(phoneHalo:FindFirstChild("HaloSparkles").Rate == 8 and phoneHalo:FindFirstChild("RaysCenter") == nil, "halo net : particules, pas de rayons")
check(label(phoneModel, "Income").Text == "+$300/s" and label(phoneModel, "Rarity").Text == "RARE", "billboard du smartphone : 300 $/s, RARE")

print("== 2. Revenus au temps exact")
local seenRegister = {}
plot1:GetAttributeChangedSignal("CashRegister"):Connect(function()
	table.insert(seenRegister, plot1:GetAttribute("CashRegister"))
end)
step(10)
local register = plot1:GetAttribute("CashRegister")
-- L'attribut est mis à jour une fois par seconde : il peut avoir jusqu'à 1 s de retard.
check(register >= 301 * 9 - 1 and register <= 3010, "après 10 s à 301 $/s : CashRegister entre 2708 et 3010 (" .. tostring(register) .. ")")
check(#seenRegister >= 9 and #seenRegister <= 10, "CashRegister mis à jour une fois par seconde (" .. #seenRegister .. " fois en 10 s)")
local steady = true
for i = 2, #seenRegister do
	local gain = seenRegister[i] - seenRegister[i - 1]
	if gain < 300 or gain > 302 then
		steady = false
	end
end
check(steady, "chaque mise à jour ajoute 301 $ (± arrondi)")
check(near(DisplayService.GetRegister(alice), 3010, 1), "GetRegister (au temps exact) ≈ 3010")
check(data.Cash == 0, "l'argent produit reste en caisse, pas dans Cash")

print("== 3. Encaissement sur le CashPad")
aliceRoot.CFrame = CFrame.new(24, 3.1, -30)
step(0.3)
local first = cashOuts[1]
check(#cashOuts == 1 and first.source == "Pad" and first.player == alice, "un encaissement en arrivant sur le tapis")
check(first.amount >= 3009 and first.amount <= 3105 and first.amount % 1 == 0, "montant entier ≈ 301 × 10,3 s (" .. tostring(first.amount) .. ")")
check(data.Cash == first.amount, "la caisse est passée dans Cash")
check(plot1:GetAttribute("CashRegister") == 0, "la caisse repart de 0")
check(alice:GetAttribute("CashCollected") == first.amount, "CashCollected = montant encaissé")
check(logHas("Alice encaisse", "PRINT"), "message d'encaissement en Studio")
step(2)
check(#cashOuts == 1, "rester sur le tapis n'encaisse pas de nouveau")
local expected = 301 * (now() - first.t)
check(
	plot1:GetAttribute("CashRegister") >= 301 and near(DisplayService.GetRegister(alice), expected, 1.01),
	`la caisse se remplit pendant qu'on reste dessus ({DisplayService.GetRegister(alice)} ≈ 301 × {now() - first.t} s)`
)
aliceRoot.CFrame = CFrame.new(0, 3, 20)
step(0.3)
aliceRoot.CFrame = CFrame.new(27.4, 3.1, -30)
step(0.3)
check(#cashOuts == 2, "ressortir puis remonter encaisse de nouveau (au bord, dans la marge de 0,5)")
check(data.Cash == first.amount + cashOuts[2].amount, "Cash = somme des deux encaissements")
check(alice:GetAttribute("CashCollected") == data.Cash, "CashCollected = total encaissé")
aliceRoot.CFrame = CFrame.new(0, 3, 20)
step(0.3)
aliceRoot.CFrame = CFrame.new(27.7, 3.1, -30)
step(0.3)
check(#cashOuts == 2, "à 0,7 stud du bord : pas d'encaissement")
aliceRoot.CFrame = CFrame.new(24, 6.8, -30)
step(0.3)
check(#cashOuts == 2, "plus de 6 studs au-dessus du tapis : pas d'encaissement")
aliceRoot.CFrame = CFrame.new(0, 3, 20)
step(0.3)
aliceCharacter:FindFirstChildOfClass("Humanoid").Health = 0
aliceRoot.CFrame = CFrame.new(24, 3.1, -30)
step(0.3)
check(#cashOuts == 2, "personnage mort : pas d'encaissement")
aliceCharacter:FindFirstChildOfClass("Humanoid").Health = 100
aliceRoot.CFrame = CFrame.new(0, 3, 20)
step(0.3)
-- Joueur rapide qui traverse le tapis entre deux contrôles : Touched suffit.
local pad = plot1:FindFirstChild("CashPad")
local countTouch = #cashOuts
local otherRoot = select(2, newPlayer("Intrus", 99))
pad.Touched:Fire(otherRoot)
check(#cashOuts == countTouch, "Touched par un autre joueur : rien")
pad.Touched:Fire(aliceRoot)
check(#cashOuts == countTouch + 1 and cashOuts[#cashOuts].source == "Pad", "Touched par le propriétaire : encaissement immédiat, même loin du centre")
pad.Touched:Fire(aliceRoot)
check(#cashOuts == countTouch + 1, "second Touched sans être ressorti : rien")
step(1.2)
pad.Touched:Fire(aliceRoot)
check(#cashOuts == countTouch + 2, "Touched après être ressorti (contrôle suivant) : nouvel encaissement")
step(0.3)

print("== 4. PlaceAuto")
local yoyo = give(data, "Z2_YoYo") -- Peu commun zone 2 : 8 × 2 = 16 $/s
local slot4 = plot1:FindFirstChild("DisplaySlot_04", true).WorldPosition
check(DisplayService.PlaceAuto(alice, yoyo, slot4) == 4, "PlaceAuto : présentoir libre le plus proche du point donné (4)")
check(data.Display["4"] == yoyo and item(plot1, 4) ~= nil, "Display[\"4\"] et DisplayItem_04")
check(alice:GetAttribute("Income") == 317, "Income = 301 + 16 = 317")
check(item(plot1, 4):FindFirstChild("RarityHalo"):FindFirstChild("HaloSparkles").Rate == 3, "Peu commun : halo léger")
check(DisplayService.PlaceAuto(alice, yoyo) == 4, "PlaceAuto d'un objet déjà exposé : son présentoir")
local chips = give(data, "Z1_PaquetDeChips") -- a22 : Commun zone 1 au catalogue v2 : 1 $/s
check(DisplayService.PlaceAuto(alice, chips) == 3, "PlaceAuto sans point : le seul présentoir libre (3)")
local noodles = give(data, "Z1_PotDeNouilles") -- Rare zone 1 : 5 $/s
check(DisplayService.PlaceAuto(alice, noodles) == nil, "PlaceAuto : nil quand les présentoirs débloqués sont tous pris")
check(data.Items[noodles] ~= nil and slotOf(data, noodles) == nil, "l'objet reste dans Items (inventaire)")
check(DisplayService.PlaceAuto(alice, "uid-inconnu") == nil, "PlaceAuto d'un objet absent de Items : nil")
check(alice:GetAttribute("Income") == 318, "Income = 317 + 1 = 318")

print("== 5. Remote PlaceItem")
clearRemotes()
placeItem(noodles, 2)
check(lastNotify(alice) == "This stand is already taken.", "présentoir occupé : refusé, Notify")
placeItem(noodles, 5)
check(lastNotify(alice) == "This stand is locked: upgrade your Display Stands.", "présentoir verrouillé : refusé, Notify")
data.Upgrades.DisplaySlots = 2
step(1.1)
check(alice:GetAttribute("DisplaySlotsUnlocked") == 6, "amélioration achetée : DisplaySlotsUnlocked = 6 (mis à jour dans la seconde)")
aliceRoot.CFrame = CFrame.new(100, 3, 0)
placeItem(noodles, 5)
check(lastNotify(alice) == "Go back to your shop to display an item." and data.Display["5"] == nil, "hors de sa parcelle : refusé, Notify")
aliceRoot.CFrame = CFrame.new(0, 3, 20)
placeItem(noodles, 5)
check(data.Display["5"] == noodles and item(plot1, 5) ~= nil, "dans sa parcelle : exposé sur le présentoir 5")
check(alice:GetAttribute("Income") == 323, "Income = 318 + 5 = 323")
clearRemotes()
placeItem("uid-inconnu", 6)
check(#notifies(alice) == 0 and data.Display["6"] == nil, "objet qui n'est pas à lui : refus muet")
placeItem(noodles, 6)
check(data.Display["5"] == nil and data.Display["6"] == noodles, "objet déjà exposé : déplacé du 5 au 6")
check(item(plot1, 5) == nil and item(plot1, 6) ~= nil and alice:GetAttribute("Income") == 323, "affichage déplacé, revenu inchangé")
placeItem(noodles, 6)
check(data.Display["6"] == noodles and #notifies(alice) == 0, "même présentoir : accepté sans message")
placeItem(noodles, 21)
check(lastNotify(alice) == "This stand doesn't exist.", "présentoir 21 (au-delà de 20) : refusé, Notify")
clearRemotes()
clearLog()
placeItem(noodles, 1.5)
check(#notifies(alice) == 0 and logHas("PlaceItem refusé : ArgValue", "WARN", "server"), "slotIndex non entier : refusé par Net")

print("== 6. Coffre-fort")
data.Vault["1"] = noodles
step(1.1)
check(data.Display["6"] == nil and item(plot1, 6) == nil, "objet rangé au coffre-fort : retiré de son présentoir")
check(logHas("rangé au coffre-fort", "WARN"), "avertissement : objet au coffre-fort")
placeItem(noodles, 6)
check(lastNotify(alice) == "This item is in your safe.", "PlaceItem d'un objet au coffre-fort : refusé, Notify")
check(DisplayService.PlaceAuto(alice, noodles) == nil, "PlaceAuto d'un objet au coffre-fort : nil")
data.Vault["1"] = nil

print("== 7. Unplace et changements faits ailleurs")
local before = alice:GetAttribute("Income")
check(DisplayService.Unplace(alice, phone) == 2, "Unplace : renvoie le présentoir libéré (2)")
check(data.Display["2"] == nil and item(plot1, 2) == nil and data.Items[phone] ~= nil, "objet retiré du présentoir, gardé dans Items")
check(alice:GetAttribute("Income") == before - 300, "Income − 300")
check(DisplayService.Unplace(alice, phone) == nil, "Unplace d'un objet non exposé : nil")
data.Display["2"] = phone -- écrit directement par un autre service
step(1.1)
check(item(plot1, 2) ~= nil and alice:GetAttribute("Income") == before, "Display modifié ailleurs : affiché dans la seconde")
data.Items[yoyo] = nil -- retiré de Items sans Unplace
step(1.1)
check(data.Display["4"] == nil and item(plot1, 4) == nil and alice:GetAttribute("Income") == before - 16, "objet retiré de Items ailleurs : présentoir libéré dans la seconde")

print("== 8. Raretés hautes, Secret et halos")
data.Upgrades.DisplaySlots = 16
step(1.1)
check(alice:GetAttribute("DisplaySlotsUnlocked") == 20, "niveau 16 : 20 présentoirs (Balance.Display.MaxSlots)")
data.Upgrades.DisplaySlots = 40
step(1.1)
check(alice:GetAttribute("DisplaySlotsUnlocked") == 20, "niveau au-delà du maximum : toujours 20")
clearLog()
local secret = give(data, "Secret_ChatPorteBonheurDore")
local secretSlot = DisplayService.PlaceAuto(alice, secret)
local secretModel = item(plot1, secretSlot)
check(secretModel ~= nil and secretModel:GetAttribute("Halo") == "Rainbow", "Secret : halo arc-en-ciel")
check(secretModel:GetAttribute("Income") == 1000 and logHas("sans zone : revenu calculé en zone 1", "WARN"), "Secret sans zone : zone 1, 1 × 1000 = 1000 $/s, avertissement")
local secretHalo = secretModel:FindFirstChild("RarityHalo")
local rays = 0
for _, child in secretHalo:GetChildren() do
	if child.ClassName == "Attachment" and string.sub(child.Name, 1, 4) == "Ray_" then
		rays += 1
	end
end
check(rays == 10 and secretHalo:FindFirstChild("RaysCenter") ~= nil, "Secret : 10 rayons autour de RaysCenter")
check(secretHalo:FindFirstChild("Ray_01"):FindFirstChild("RayBeam").Attachment1 == secretHalo:FindFirstChild("Ray_01"), "rayon = Beam de RaysCenter à Ray_xx")
check(#secretHalo:FindFirstChild("HaloSparkles").Color.Keypoints == 5, "particules du Secret : les 5 couleurs de l'arc-en-ciel")
local secretRarity = label(secretModel, "Rarity")
check(secretRarity.Text == "SECRET" and secretRarity:FindFirstChild("RarityRainbow") ~= nil, "billboard du Secret : SECRET en dégradé arc-en-ciel")
check(label(secretModel, "Income").Text == "+$1K/s", "billboard : « 1 K$/s »")
local secret6 = give(data, "Secret_ChatPorteBonheurDore", { Zone = 6 })
local secret6Slot = DisplayService.PlaceAuto(alice, secret6)
check(item(plot1, secret6Slot):GetAttribute("Income") == 25000000, "Secret avec Zone = 6 enregistrée : 25 000 × 1000 = 25 M$/s")
check(label(item(plot1, secret6Slot), "Income").Text == "+$25M/s", "billboard : « 25 M$/s »")
local ticketSlot = DisplayService.PlaceAuto(alice, ticket)
local ticketHalo = item(plot1, ticketSlot):FindFirstChild("RarityHalo")
local ticketRays = 0
for _, child in ticketHalo:GetChildren() do
	if child.ClassName == "Attachment" and string.sub(child.Name, 1, 4) == "Ray_" then
		ticketRays += 1
	end
end
check(ticketRays == 8 and ticketHalo:FindFirstChild("HaloLight").Color == rarityColor("Legendary"), "Légendaire : 8 rayons dorés")
check(item(plot1, ticketSlot):GetAttribute("Income") == 400, "Légendaire zone 2 : 8 × 50 = 400 $/s")
local sum = 0
for _, uid in data.Display do
	local entry = data.Items[uid]
	local def = requireModule(Shared.Config.Items, "server").ById[entry.Id]
	local zone = def.Zone or entry.Zone or 1
	sum += requireModule(Shared.Config.Formulas, "server").ItemIncome(zone, def.Rarity)
end
check(alice:GetAttribute("Income") == sum, "Income = somme exacte des Formulas.ItemIncome exposés (" .. tostring(sum) .. ")")

print("== 9. Modèle ITM_ et billboard BB_Item de Clément")
local assets = folder(ReplicatedStorage, "Assets")
local zone1 = folder(folder(assets, "Items"), "Zone1")
local hotdog = new("Model", { Name = "ITM_Z2_FigurineHolographique" }, zone1) -- a22 : Hot-dog en or retiré, Mythique de la zone 2
local hotRoot = new("Part", { Name = "Root", Size = Vector3.new(1, 2, 1), CFrame = CFrame.new(50, 1, 50), PivotOffset = CFrame.new(0, -1, 0) }, hotdog)
new("Part", { Name = "Bun", Size = Vector3.new(1.5, 0.5, 0.6), CFrame = CFrame.new(50, 1.5, 50) }, hotdog)
new("Script", { Name = "Spin" }, hotRoot)
hotdog.PrimaryPart = hotRoot
hotdog:SetAttribute("ItemId", "Z2_FigurineHolographique")
local ui = folder(assets, "UI")
local template = new("BillboardGui", { Name = "BB_Item", StudsOffset = Vector3.new(0, 2, 0), Size = UDim2.fromScale(6, 3) }, ui)
local card = new("Frame", { Name = "Card" }, template)
new("TextLabel", { Name = "ItemName" }, card)
new("TextLabel", { Name = "Rarity" }, card)
new("TextLabel", { Name = "Income" }, card)
clearLog()
local hot = give(data, "Z2_FigurineHolographique") -- Mythique zone 2 : 8 × 200 = 1 600 $/s
local hotSlot = DisplayService.PlaceAuto(alice, hot)
local hotModel = item(plot1, hotSlot)
check(hotModel ~= nil and hotModel:FindFirstChild("Bun") ~= nil and hotModel:GetAttribute("Placeholder") == false, "copie du modèle ITM_Z2_FigurineHolographique (sous-dossier Zone1)")
local scripts, unanchored = 0, 0
for _, d in hotModel:GetDescendants() do
	if d:IsA("LuaSourceContainer") then
		scripts += 1
	elseif d:IsA("BasePart") and d.Name ~= "RarityHalo" and not d.Anchored then
		unanchored += 1
	end
end
check(scripts == 0 and logHas("1 script(s) retiré(s)", "WARN"), "script retiré de la copie, avertissement")
check(unanchored == 0, "toutes les pièces de la copie sont ancrées")
check(hotdog:FindFirstChild("Spin", true) ~= nil and not hotRoot.Anchored, "le modèle de Clément n'est pas modifié")
local hotSlotPosition = plot1:FindFirstChild(string.format("DisplaySlot_%02d", hotSlot), true).WorldPosition
check(near(hotModel.PrimaryPart.Position.Y, hotSlotPosition.Y + 1) and near(hotModel.PrimaryPart.Position.X, hotSlotPosition.X), "copie posée par son pivot (bas du Root) sur le présentoir")
local hotBillboard = hotModel:FindFirstChild("BB_Item")
check(hotBillboard ~= nil and hotBillboard.StudsOffset == Vector3.new(0, 2, 0) and hotBillboard:FindFirstChild("Card") ~= nil, "copie de BB_Item (réglages de Clément gardés)")
check(label(hotModel, "ItemName").Text == "Hologram Figure" and label(hotModel, "Income").Text == "+$1.6K/s", "BB_Item rempli : nom (anglais) et revenu")
check(label(hotModel, "Rarity").Text == "MYTHIC" and label(hotModel, "Rarity").TextColor3 == rarityColor("Mythic"), "BB_Item rempli : MYTHIQUE en rouge rose")
check(card:FindFirstChild("ItemName").Text == "Label", "le BB_Item de Clément n'est pas modifié")
check(not logHas("pas encore livré", "PRINT"), "aucun message « pas encore livré » pour ce modèle et ce billboard")

print("== 10. Client : DisplayController")
Players.LocalPlayer = alice
local camera = new("Camera", { CFrame = CFrame.new(0, 5, 30) }, Workspace)
Workspace.CurrentCamera = camera
local DisplayController = requireModule(controllerModule, "client")
taskLib.spawn(DisplayController.Start)
step(0.1)
check(DisplayController.GetIncome() == alice:GetAttribute("Income"), "GetIncome = attribut Income")
check(DisplayController.GetUnlockedSlots() == 20, "GetUnlockedSlots = 20")
check(DisplayController.GetRegister() == plot1:GetAttribute("CashRegister"), "GetRegister = caisse de sa parcelle")
local registerSeen, incomeSeen, cashSeen = {}, {}, {}
DisplayController.OnRegisterChanged(function(v)
	table.insert(registerSeen, v)
end)
DisplayController.OnIncomeChanged(function(v)
	table.insert(incomeSeen, v)
end)
DisplayController.OnCashOut(function(v)
	table.insert(cashSeen, v)
end)
step(2.1)
check(#registerSeen >= 2 and registerSeen[#registerSeen] == plot1:GetAttribute("CashRegister"), "OnRegisterChanged suit CashRegister")
clearLog()
local count = #cashOuts
aliceRoot.CFrame = CFrame.new(24, 3.1, -30)
step(0.3)
check(#cashOuts == count + 1 and cashSeen[1] == cashOuts[#cashOuts].amount, "OnCashOut côté client : même montant que le serveur")
check(logHas("[Caisse] +", "PRINT", "client"), "retour en Studio côté client : « [Caisse] +… encaissés »")
aliceRoot.CFrame = CFrame.new(0, 3, 20)
step(0.3)
local free = nil
for i = 1, 20 do
	if data.Display[tostring(i)] == nil then
		free = i
		break
	end
end
clearLog()
DisplayController.PlaceItem(noodles, free)
step(0.3)
check(data.Display[tostring(free)] == noodles, "DisplayController.PlaceItem : exposé par le serveur")
check(#incomeSeen >= 1 and incomeSeen[#incomeSeen] == alice:GetAttribute("Income"), "OnIncomeChanged côté client")
check(not logHas("[Présentoirs] revenu de ta boutique", "PRINT", "client"), "revenu affiché par le HUD (vague 4), plus dans la sortie")

local secret6Halo = item(plot1, secret6Slot):FindFirstChild("RarityHalo")
local ray = secret6Halo:FindFirstChild("Ray_01")
local center = secret6Halo:FindFirstChild("RaysCenter")
local radius0 = (ray.Position - center.Position).Magnitude
local start = ray.Position
local lightStart = secret6Halo:FindFirstChild("HaloLight").Color
step(0.5)
check(not (ray.Position == start) and near((ray.Position - center.Position).Magnitude, radius0, 1e-6), "rayons du Secret : tournent autour du centre, même longueur")
check(not (secret6Halo:FindFirstChild("HaloLight").Color == lightStart), "lumière du Secret : couleur qui défile")
local ticketRay = ticketHalo:FindFirstChild("Ray_01")
local ticketBeamColor = ticketRay:FindFirstChild("RayBeam").Color.Keypoints[1].Value
local ticketStart = ticketRay.Position
step(0.5)
check(not (ticketRay.Position == ticketStart), "rayons du Légendaire : tournent aussi")
check(ticketRay:FindFirstChild("RayBeam").Color.Keypoints[1].Value == ticketBeamColor, "rayons du Légendaire : restent dorés")
camera.CFrame = CFrame.new(1000, 5, 1000)
local farStart = ray.Position
step(0.5)
check(ray.Position == farStart, "loin de la caméra (plus de 120 studs) : pas animé")
camera.CFrame = CFrame.new(0, 5, 30)

local F = DisplayController.FormatMoney
check(F(0) == "$0" and F(999) == "$999" and F(999.9) == "$999", "FormatMoney : moins de 1000")
check(F(1000) == "$1K" and F(1234) == "$1.2K" and F(12450) == "$12.4K" and F(120000) == "$120K", "FormatMoney : K")
check(F(999999) == "$999K" and F(2e6) == "$2M" and F(25e6) == "$25M" and F(3e9) == "$3B", "FormatMoney : M et B")
check(F(1.5e12) == "$1.5T" and F(-5) == "-$5", "FormatMoney : T, et négatif")

print("== 11. Départs")
-- a) Parcelle libérée avant le profil
step(3)
local cashBefore = data.Cash
local pending = DisplayService.GetRegister(alice)
check(pending > 0, "de l'argent attend en caisse (" .. tostring(pending) .. ")")
PlotService._release(alice)
check(plot1:FindFirstChild("DisplayItems") == nil, "parcelle libérée : objets retirés")
check(#CollectionServiceStub:GetTagged("DisplayItem") == 0, "plus aucun objet tagué DisplayItem")
check(plot1:GetAttribute("CashRegister") == 0, "parcelle libérée : CashRegister = 0")
step(2)
check(DisplayService.GetRegister(alice) == pending, "plus de revenus après la libération de la parcelle")
clearLog()
local countBefore = #cashOuts
DataService._release(alice)
check(#cashOuts == countBefore + 1 and cashOuts[#cashOuts].source == "Leave", "départ : encaissement automatique (source Leave)")
check(data.Cash == cashBefore + pending, "la caisse est passée dans Cash avant la sauvegarde")
check(logHas("de sa caisse encaissés automatiquement", "PRINT"), "message de l'encaissement au départ")
Players.PlayerRemoving:Fire(alice)
check(DisplayService.GetIncome(alice) == 0 and DisplayService.GetRegister(alice) == 0, "compte effacé après le départ")

-- b) Profil libéré avant la parcelle ; parcelle donnée avant le chargement du profil
local bob = newPlayer("Bob", 2)
CLIENT_PLAYER = bob
local bobData = newProfile()
local bills = give(bobData, "Z6_LingotDOr") -- a22 (Liasse retirée) : Commun zone 6 : 25 000 $/s
bobData.Display = { ["2"] = bills, ["3"] = bills }
PlotService._assign(bob, plot1)
check(plot1:FindFirstChild("DisplayItems") == nil, "parcelle attribuée avant le profil : rien d'affiché")
clearLog()
DataService._load(bob, bobData)
check(plot1:FindFirstChild("DisplayItems") ~= nil, "profil chargé : boutique installée")
check(bobData.Display["2"] == bills and bobData.Display["3"] == nil, "objet exposé deux fois : gardé sur le plus petit numéro")
check(logHas("déjà exposé sur le présentoir 2", "WARN"), "avertissement : doublon")
check(bob:GetAttribute("Income") == 25000 and label(item(plot1, 2), "Income").Text == "+$25K/s", "Bob : 25 000 $/s, « 25 K$/s »")
check(item(plot1, 2):GetAttribute("OwnerUserId") == 2, "objets de Bob : OwnerUserId = 2")
step(1)
local bobCountBefore = #cashOuts
DataService._release(bob)
check(#cashOuts == bobCountBefore + 1 and cashOuts[#cashOuts].amount >= 24000, "profil libéré d'abord : caisse encaissée (≈ 25 000 $)")
check(bobData.Cash == cashOuts[#cashOuts].amount, "Cash de Bob = sa caisse")
PlotService._release(bob)
check(plot1:FindFirstChild("DisplayItems") == nil and plot1:GetAttribute("CashRegister") == 0, "puis parcelle libérée : vide, caisse à 0")
Players.PlayerRemoving:Fire(bob)
step(1.1)

print("== 12. Sortie")
check(not logHas("mal formé", "WARN"), "aucun envoi mal formé signalé par Net")
check(not logHas("mise à jour", "WARN") and not logHas("contrôle des CashPad", "WARN"), "aucune erreur dans la boucle")
check(not logHas("non affiché", "WARN"), "aucun objet impossible à afficher")

summary()
