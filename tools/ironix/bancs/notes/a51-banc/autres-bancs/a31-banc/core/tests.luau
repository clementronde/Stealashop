--!nocheck
-- Banc a31 (vague 11 ; liaison L-055 ; côté code de MOD-014, MOD-026, MOD-031) :
--   A. Config/Items à 83 objets : les 9 ajouts du 2026-11-07, la catégorie Mode / Fashion, aucun
--      ItemId, zone, rareté ni nom des 74 objets d'avant changé, tirage des nouveaux objets ;
--   B. profils v2 : chargés sans migration, objets anciens et nouveaux gardés ;
--   C. contrat et réglages : WavePrefix, ExpectedCount, Config/ItemIdle ;
--   D. Contract/Icons : règle de recherche des Decals ICON_<ItemId> (celle des auras, L-042) ;
--   E. ContractChecker : pièces Wave_ et icônes ICON_ sur une fausse place ;
--   F. ItemIdleController : pièces Wave_ (va-et-vient sans dérive sur 10 000 images, retour exact
--      à la pose de départ, avec Bob, en groupe Model), pivot des pièces Spin_ avec PivotOffset.

local TAU = 2 * math.pi
local DT = 1 / 30

---------------------------------------------------------------- arbre
local Shared = folder(ReplicatedStorage, "Shared")
local ConfigF = folder(Shared, "Config")
for _, n in { "Balance", "Bat", "Cosmetics", "DeepFreeze", "Features", "Formulas", "ItemIdle", "Items", "Night", "PvP", "Rarities", "Shatter", "ShelfBoxes", "Tools", "Training", "Tutorial", "Upgrades", "Zones" } do
	moduleScript(ConfigF, n, `shared/Config/{n}.luau`)
end
local ContractF = folder(Shared, "Contract")
for _, n in { "Animations", "Attributes", "Find", "Icons", "Models", "Tags", "UI" } do
	moduleScript(ContractF, n, `shared/Contract/{n}.luau`)
end
local TypesF = folder(Shared, "Types")
for _, n in { "Carry", "Profile" } do
	moduleScript(TypesF, n, `shared/Types/{n}.luau`)
end
local Server = folder(ServerScriptService, "Server")
moduleScript(folder(Server, "Packages"), "ProfileStore", "stub/ProfileStore")
local Services = folder(Server, "Services")
local DataModule = moduleScript(Services, "DataService", "server/Services/DataService.luau")
local CheckerModule = moduleScript(Services, "ContractChecker", "server/Services/ContractChecker.luau")
local Controllers = folder(folder(StarterPlayerScripts, "Client"), "Controllers")
local IdleModule = moduleScript(Controllers, "ItemIdleController", "client/Controllers/ItemIdleController.luau")

local Items = requireModule(ConfigF.Items, "server")
local ItemIdle = requireModule(ConfigF.ItemIdle, "server")
local Models = requireModule(ContractF.Models, "server")
local IconsServer = requireModule(ContractF.Icons, "server")
local IconsClient = requireModule(ContractF.Icons, "client")
local RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

local function cfNear(a, b, eps)
	eps = eps or 1e-9
	if (a.Position - b.Position).Magnitude > eps then
		return false
	end
	for i = 1, 9 do
		if math.abs(a.r[i] - b.r[i]) > eps then
			return false
		end
	end
	return true
end
local function part(name, parent, cframe, size, class)
	return new(class or "Part", { Name = name, Size = size or Vector3.new(1, 1, 1), CFrame = cframe, Anchored = true }, parent)
end

---------------------------------------------------------------- A. catalogue
print("== A. Config/Items : 83 objets, les 9 ajouts du 2026-11-07 (L-055)")
check(#Items.List == 83, `83 objets ({#Items.List})`)
-- Les 9 ajouts (objets-catalogue-v2.md) : ItemId, zone, rareté, id de catégorie, catégorie et nom
-- affichés (anglais, L-036).
local ADDED = {
	{ "Z2_BallonDeFoot", 2, "Common", "Jouet", "Toy", "Soccer Ball" },
	{ "Z2_BoosterDeCartes", 2, "Uncommon", "Jouet", "Toy", "Card Booster Pack" },
	{ "Z2_CarteHolographique", 2, "Epic", "Jouet", "Toy", "Holo Card" },
	{ "Z2_Skateboard", 2, "Uncommon", "Vehicule", "Vehicle", "Skateboard" },
	{ "Z3_ConsoleADoubleEcran", 3, "Rare", "Console", "Console", "Dual-Screen Console" },
	{ "Z3_ConsoleDeSalon", 3, "Epic", "Console", "Console", "Home Console" },
	{ "Z4_Parfum", 4, "Common", "Mode", "Fashion", "Perfume" },
	{ "Z4_LunettesDeStar", 4, "Uncommon", "Mode", "Fashion", "Star Sunglasses" },
	{ "Z4_BasketsDeCollection", 4, "Rare", "Mode", "Fashion", "Collector Sneakers" },
}
local addedOk, addedFirst = true, nil
for _, a in ADDED do
	local item = Items.ById[a[1]]
	local ok = item ~= nil
		and item.Zone == a[2]
		and item.Rarity == a[3]
		and item.CategoryId == a[4]
		and item.Category == a[5]
		and item.DisplayName == a[6]
		and item.Asset == `ITM_{a[1]}`
		and item.TutorialOnly == false
		and table.find(Items.ByZone[a[2]][a[3]], item) ~= nil
	if not ok then
		addedOk = false
		addedFirst = addedFirst or a[1]
	end
end
check(addedOk, "les 9 ajouts : zone, rareté, catégorie (id et nom anglais), nom anglais, modèle ITM_, tirables" .. (if addedFirst then ` (premier écart : {addedFirst})` else ""))
-- Aucun des 74 objets d'avant ne change (liste figée de main, da07a30).
local sameOld, oldFirst = true, nil
for _, m in MAIN_ITEMS do
	local item = Items.ById[m[1]]
	if item == nil or item.Zone ~= m[2] or item.Rarity ~= m[3] or item.CategoryId ~= m[4] or item.DisplayName ~= m[5] then
		sameOld = false
		oldFirst = oldFirst or m[1]
	end
end
check(#MAIN_ITEMS == 74 and sameOld, "les 74 objets d'avant gardent ItemId, zone, rareté, catégorie et nom : aucune migration de profil nécessaire" .. (if oldFirst then ` (écart : {oldFirst})` else ""))
local union = {}
for _, m in MAIN_ITEMS do
	union[m[1]] = true
end
for _, a in ADDED do
	union[a[1]] = true
end
local onlyThose = true
for _, item in Items.List do
	if not union[item.Id] then
		onlyThose = false
	end
end
check(onlyThose, "83 = 74 d'avant + 9 ajouts, aucun autre")
-- Tailles des zones et cases (zone, rareté) touchées par les ajouts, dans l'ordre du catalogue.
local perZone = {}
for _, item in Items.List do
	local key = item.Zone or "Secret"
	perZone[key] = (perZone[key] or 0) + 1
end
check(perZone[1] == 13 and perZone[2] == 16 and perZone[3] == 14 and perZone[4] == 15 and perZone[5] == 12 and perZone[6] == 12 and perZone.Secret == 1, "zones : 13, 16, 14, 15, 12, 12 objets, plus le Secret")
local function ids(list)
	local out = {}
	for _, item in list do
		table.insert(out, item.Id)
	end
	return table.concat(out, ",")
end
check(ids(Items.ByZone[2].Common) == "Z2_CanardEnPlastique,Z2_BallonDeFoot,Z2_OursEnPeluche,Z2_Sucette", "zone 2 Commun : Canard, Ballon de foot, Ours, Sucette")
check(ids(Items.ByZone[2].Uncommon) == "Z2_BoosterDeCartes,Z2_YoYo,Z2_BarbeAPapa,Z2_BusAImperiale,Z2_Skateboard", "zone 2 Peu commun : Booster, Yo-yo, Barbe à papa, Bus, Skateboard")
check(ids(Items.ByZone[2].Epic) == "Z2_CarteHolographique,Z2_RobotJouet,Z2_TrainElectrique", "zone 2 Épique : Carte holographique, Robot, Train")
check(ids(Items.ByZone[3].Epic) == "Z3_TeleGeante,Z3_ConsoleDeSalon,Z3_ConsolePortable", "zone 3 Épique : Télé géante, Console de salon, Console portable")
check(ids(Items.ByZone[4].Common) == "Z4_Bague,Z4_MontreEnOr,Z4_PenduleDoree,Z4_Parfum", "zone 4 Commun : Bague, Montre en or, Pendule, Parfum")
check(ids(Items.ByZone[4].Uncommon) == "Z4_ChaineEnOr,Z4_CoffretDeMontres,Z4_LunettesDeStar,Z4_Rubis", "zone 4 Peu commun : Chaîne, Coffret, Lunettes de star, Rubis")
check(ids(Items.ByZone[4].Rare) == "Z4_CollierDePerles,Z4_MontreAGousset,Z4_BasketsDeCollection", "zone 4 Rare : Collier, Montre à gousset, Baskets de collection")
-- Tirage : chacun des objets d'une case à parts égales, nouveaux compris.
local rng = Random.new(3108)
local function spread(zone, rarity, n, tolerance)
	local list = Items.ByZone[zone][rarity]
	local seen = {}
	for _ = 1, n do
		local item = Items.Pick(zone, rarity, rng)
		seen[item.Id] = (seen[item.Id] or 0) + 1
	end
	for _, item in list do
		if math.abs((seen[item.Id] or 0) / n - 1 / #list) > tolerance then
			return false
		end
	end
	return true
end
check(spread(2, "Uncommon", 25000, 0.015), "zone 2 Peu commun : chacun des 5 ≈ 1/5 des 25 000 tirages (± 1,5 %)")
check(spread(3, "Rare", 24000, 0.015), "zone 3 Rare : chacun des 3 ≈ 1/3 (Console à double écran comprise)")
check(spread(4, "Common", 24000, 0.015), "zone 4 Commun : chacun des 4 ≈ 1/4 (Parfum compris)")
-- Les catégories affichées, sans accent (textes anglais, L-036).
local cats = {}
for _, item in Items.List do
	cats[item.Category] = true
end
local catList = {}
for name in cats do
	table.insert(catList, name)
end
table.sort(catList)
-- 4 + 4 + 4 + 5 + 4 + 3 (Jewel déjà en zone 4) + « ??? » du Secret = 25.
check(cats.Fashion == true and #catList == 25, `25 catégories affichées, Fashion comprise ({#catList} : {table.concat(catList, ", ")})`)

---------------------------------------------------------------- B. profils v2
print("== B. Profils v2 : chargés sans migration (aucun ItemId changé)")
PRESET_PROFILES["Player_201"] = {
	Version = 2,
	Cash = 4321,
	Items = {
		a = { Id = "Z2_YoYo", Source = "NPC", At = 10, Zone = 2 },
		b = { Id = "Z4_MontreEnOr", Source = "NPC", At = 11, Zone = 4 },
		c = { Id = "Z1_PotDeNouilles", Source = "NPC", At = 12, Zone = 1 },
		d = { Id = "Secret_ChatPorteBonheurDore", Source = "NPC", At = 13, Zone = 6 },
		e = { Id = "Z4_Parfum", Source = "PvP", At = 14 }, -- objet ajouté, déjà écrit par ce code
	},
	Display = { ["1"] = "a", ["2"] = "d" },
	Boxes = { ["1"] = { Tier = "Premium", Zone = 3, ItemId = "Z3_CasqueVr", Rarity = "Rare", ReadyAt = 55 } },
}
local DataService = requireModule(DataModule, "server")
DataService.Init()
taskLib.spawn(DataService.Start)
local function join(name, userId)
	local player = InstanceAPI.new("Player")
	player.Name = name
	player.UserId = userId
	player.Parent = Players
	Players.PlayerAdded:Fire(player)
	return player
end
-- a51 : le colis du profil v2 : établi 1 (v4), présentoir 3 (v5, v6), inventaire sous un uid neuf (v7).
function BOX_OF(data, v)
	if v >= 7 then
		local _, box = next(data.Boxes)
		return box
	end
	return data.Boxes[if v >= 5 then "3" else "1"]
end
clearLog()
local P1 = join("P1", 201)
local d = DataService.Get(P1)
-- Copie d'a38 (DEV-100) : v3 quand l'arbre testé a la boutique Robux (Config/Monetization), sinon v2.
-- Copie d'a40 (DEV-111) : v4 quand l'arbre a l'index des objets (Config/Index).
-- Copie d'a48 (DEV-102) : v6 quand Types/Profile a Offline (gains hors ligne).
-- Copie d'a46 (L-086) : v5 quand Types/Profile a BoxQueue (colis sur les présentoirs).
-- Copie d'a51 (L-089) : v7 quand Types/Profile a Spot (colis rangés par uid dans l'inventaire).
local V = if SOURCES["shared/Types/Profile.luau"] and string.find(SOURCES["shared/Types/Profile.luau"], "Spot: Spot?", 1, true) then 7 elseif SOURCES["shared/Types/Profile.luau"] and string.find(SOURCES["shared/Types/Profile.luau"], "Offline: Offline", 1, true) then 6 elseif SOURCES["shared/Types/Profile.luau"] and string.find(SOURCES["shared/Types/Profile.luau"], "BoxQueue", 1, true) then 5 elseif SOURCES["shared/Config/Index.luau"] then 4 elseif SOURCES["shared/Config/Monetization.luau"] then 3 else 2
check(d ~= nil and d.Version == V, `profil v2 : chargé en v{V}, objets intacts (plus bas)`)
local keep = d ~= nil
	and d.Items.a.Id == "Z2_YoYo"
	and d.Items.b.Id == "Z4_MontreEnOr"
	and d.Items.c.Id == "Z1_PotDeNouilles"
	and d.Items.d.Id == "Secret_ChatPorteBonheurDore"
	and d.Items.e.Id == "Z4_Parfum"
	and BOX_OF(d, V).ItemId == "Z3_CasqueVr" -- copie a46 : en v5, sur le 1er présentoir libre (le 3) ; a51 : en v7, dans l'inventaire
	and BOX_OF(d, V).Rarity == "Rare"
	and d.Display["2"] == "d"
	and d.Cash == 4321
check(keep, "objets, colis, présentoirs et argent gardés tels quels (Parfum, ajouté, compris)")
-- a40 : en v4, la seule ligne de migration est celle de l'index (les 5 objets possédés sont découverts).
-- a46 : en v5, plus une ligne pour le colis de l'établi 1 posé sur le présentoir 3.
-- a51 : en v7, plus une ligne pour le colis rangé dans l'inventaire.
check(logCount("migration", nil) == (if V >= 7 then 3 elseif V >= 5 then 2 elseif V >= 4 then 1 else 0) and logCount("migration v2", nil) == 0 and logCount("[DataService]", "WARN") == 0, "aucune ligne de migration des ItemId ni avertissement de DataService")
if V >= 4 then
	check(logHas("migration v4 : Index : 5 objet(s) déjà possédé(s) compté(s) comme découvert(s)", "PRINT") and d.Index.Z4_Parfum == 14 and d.Index.Secret_ChatPorteBonheurDore == 13 and d.Index.Z3_CasqueVr == nil, "v4 : les 5 objets possédés découverts, pas l'objet du colis (a40)")
end

---------------------------------------------------------------- C. contrat et réglages
print("== C. Contrat (Contract/Models) et réglages (Config/ItemIdle)")
check(Models.Item.ExpectedCount == 83 and Models.Item.ExpectedCount == #Items.List, "ExpectedCount des ITM_ = 83 (#Items.List)")
check(Models.Item.SpinPrefix == "Spin_" and Models.Item.WavePrefix == "Wave_", "préfixes des pièces mobiles : Spin_ et Wave_")
check(type(ItemIdle.WaveAmplitude) == "number" and ItemIdle.WaveAmplitude > 0 and ItemIdle.WaveAmplitude < 90 and type(ItemIdle.WavePeriod) == "number" and ItemIdle.WavePeriod > 0, "Config/ItemIdle : WaveAmplitude (degrés) et WavePeriod (s)")
check(table.isfrozen(ItemIdle), "Config/ItemIdle gelé")
check(IconsServer.Prefix == "ICON_" and table.concat(IconsServer.Folder, ".") == "Assets.Icons" and IconsServer.name("Z1_Banane") == "ICON_Z1_Banane", "Contract/Icons : ICON_<ItemId> dans Assets/Icons (10.3)")

---------------------------------------------------------------- D. Contract/Icons
print("== D. Contract/Icons : règle de recherche (L-042)")
check(IconsServer.find("Z1_Banane") == nil and IconsServer.get("Z1_Banane") == nil, "sans ReplicatedStorage/Assets : nil")
local Assets = folder(ReplicatedStorage, "Assets")
-- FX avant Icons dans l'arbre : un parcours de tout Assets y passerait en premier.
local FxF = folder(Assets, "FX")
check(IconsServer.get("Z1_Banane") == nil, "Assets sans Icons : nil")
local IconsF = folder(Assets, "Icons")
local function decal(name, texture, parent)
	return new("Decal", { Name = name, Texture = texture }, parent)
end
decal("ICON_Z1_Banane", "rbxassetid://101", IconsF)
check(IconsServer.get("Z1_Banane") == "rbxassetid://101" and IconsClient.get("Z1_Banane") == "rbxassetid://101", "Decal dans Assets/Icons : sa Texture (serveur et client)")
check(IconsServer.find("Z1_Banane") == IconsF.ICON_Z1_Banane, "Icons.find : le Decal lui-même")
decal("ICON_Z2_YoYo", "rbxassetid://102", folder(IconsF, "Zone2"))
check(IconsServer.get("Z2_YoYo") == "rbxassetid://102", "sous-dossier d'Assets/Icons : trouvé")
decal("ICON_Z3_Souris", "rbxassetid://103", folder(Assets, "UI"))
check(IconsServer.get("Z3_Souris") == "rbxassetid://103", "ailleurs sous Assets : trouvé (comme les Decals d'auras)")
part("ICON_Z4_Bague", IconsF, CFrame.new(0, 0, 0))
decal("ICON_Z4_Bague", "rbxassetid://104", folder(IconsF, "Sub"))
check(IconsServer.get("Z4_Bague") == "rbxassetid://104", "un autre objet du même nom (Part) est sauté : le premier Decal")
decal("ICON_Z5_VaseAncien", "", IconsF)
check(IconsServer.get("Z5_VaseAncien") == nil, "Decal sans Texture : pas livré (nil)")
decal("ICON_Z6_LingotDOr", "rbxassetid://105", FxF)
decal("ICON_Z6_LingotDOr", "rbxassetid://106", folder(IconsF, "Zone6"))
check(IconsServer.get("Z6_LingotDOr") == "rbxassetid://106", "en double : celui d'Assets/Icons d'abord (même dans un sous-dossier), avant un autre dossier d'Assets")
decal("ICON_Z1_Donut", "rbxassetid://107", Workspace)
check(IconsServer.get("Z1_Donut") == nil, "hors de ReplicatedStorage/Assets (Workspace) : pas vu par le code")
check(IconsServer.get("Z9_Inconnu") == nil, "ItemId inconnu : nil")
IconsServer.preload({ "rbxassetid://101" })
check(#PRELOADS == 0, "Icons.preload côté serveur : rien")
IconsClient.preload({})
check(#PRELOADS == 0, "Icons.preload d'une liste vide : rien")
IconsClient.preload({ "rbxassetid://101", "rbxassetid://102" })
check(#PRELOADS == 1 and PRELOADS[1].side == "client" and #PRELOADS[1].list == 2 and PRELOADS[1].list[2] == "rbxassetid://102", "Icons.preload côté client : un PreloadAsync avec les textures")
Assets:Destroy()
Workspace.ICON_Z1_Donut:Destroy()

---------------------------------------------------------------- E. ContractChecker
print("== E. ContractChecker : pièces Wave_ et icônes ICON_")
Assets = folder(ReplicatedStorage, "Assets")
local AssetItems = folder(Assets, "Items")
local Inbox = folder(Workspace, "_INBOX_CLEMENT")
local function itm(name, parent)
	local model = new("Model", { Name = name }, nil)
	local root = part("Root", model, CFrame.new(0, 0.25, 0), Vector3.new(1, 0.5, 1))
	model.PrimaryPart = root
	model:SetAttribute("ItemId", string.sub(name, 5))
	part("Body", model, CFrame.new(0, 1, 0))
	model.Parent = parent
	return model
end
-- Le Chat de Clément : patte Wave_Paw et Wave_PawPads (MeshParts), conforme.
local cat = itm("ITM_Secret_ChatPorteBonheurDore", AssetItems)
part("Wave_Paw", cat, CFrame.new(0.4, 1.5, -0.3), nil, "MeshPart")
part("Wave_PawPads", cat, CFrame.new(0.4, 1.6, -0.4), nil, "MeshPart")
-- Erreurs : Root dans une pièce Wave_, une Wave_ qui n'est pas une pièce, une Wave_ soudée.
local skate = new("Model", { Name = "ITM_Z2_Skateboard" }, nil)
local deck = new("Model", { Name = "Wave_Deck" }, skate)
skate.PrimaryPart = part("Root", deck, CFrame.new(0, 0.25, 0))
skate:SetAttribute("ItemId", "Z2_Skateboard")
skate.Parent = Inbox
local homeConsole = itm("ITM_Z3_ConsoleDeSalon", Inbox)
new("Attachment", { Name = "Wave_Light" }, homeConsole.Body)
local perfume = itm("ITM_Z4_Parfum", Inbox)
local capPart = part("Wave_Cap", perfume, CFrame.new(0, 1.6, 0))
new("WeldConstraint", { Name = "CapWeld", Part0 = capPart, Part1 = perfume.Body }, capPart)
-- Icônes : toutes, sauf les Baskets (absente) et le Ballon de foot (Texture vide) ; plus une faute
-- de casse, un ItemId inconnu et une Part au nom d'une icône.
local IconsDir = folder(Assets, "Icons")
for _, item in Items.List do
	if item.Id ~= "Z4_BasketsDeCollection" then
		decal(`ICON_{item.Id}`, if item.Id == "Z2_BallonDeFoot" then "" else `rbxassetid://9{#item.Id}`, IconsDir)
	end
end
decal("ICON_Z1_banane", "rbxassetid://1", IconsDir)
decal("ICON_Z9_Inconnu", "rbxassetid://2", IconsDir)
part("ICON_Z1_Ananas", IconsDir, CFrame.new(0, 0, 0))
clearLog()
local Checker = requireModule(CheckerModule, "server")
Checker.Start()
local function dump(kind)
	for _, line in LOG do
		if line.kind == kind and string.find(line.text, "Objets", 1, true) then
			print("    " .. line.text)
		end
	end
end
check(logHas("ITM_Z2_Skateboard.Root est dans Wave_Deck : une pièce Wave_ bouge", "WARN"), "Root dans une pièce Wave_ : signalé")
check(logHas("ITM_Z3_ConsoleDeSalon.Wave_Light : une pièce Wave_ doit être une pièce (BasePart) ou un Model (trouvé : Attachment)", "WARN"), "Wave_ qui n'est pas une pièce : signalée")
check(logHas("ITM_Z4_Parfum.Wave_Cap : soudée au reste du modèle par CapWeld (WeldConstraint), elle ne pourrait pas bouger seule", "WARN"), "pièce Wave_ soudée au reste : signalée")
check(logCount("ChatPorteBonheurDore", "WARN") == 0, "le Chat (Wave_Paw, Wave_PawPads) : rien à signaler")
check(logHas("ICON_Z1_banane : Z1_banane n'est pas au catalogue d'objets (Config/Items) : la renommer ICON_Z1_Banane", "WARN"), "icône mal nommée (casse) : signalée, nom exact donné")
check(logHas("ICON_Z9_Inconnu : Z9_Inconnu n'est pas au catalogue d'objets (Config/Items)", "WARN") and not logHas("Z9_Inconnu n'est pas au catalogue d'objets (Config/Items) : la renommer", "WARN"), "icône hors catalogue : signalée, sans nom proposé")
check(logHas("Icons.ICON_Z1_Ananas : une icône d'objet doit être un Decal (trouvé : Part, 10.3)", "WARN"), "objet ICON_ qui n'est pas un Decal : signalé")
check(logHas("icônes ICON_* : 81 sur 83 livrées dans ReplicatedStorage.Assets.Icons (manquent : ICON_Z2_BallonDeFoot, ICON_Z4_BasketsDeCollection)", "PRINT"), "icônes manquantes (absente, Texture vide) : « pas encore livré », avec leurs noms")
check(logHas("objets exposés ITM_* : 4 sur 83 livrés", "PRINT"), "objets exposés : 4 sur 83")
check(logHas("[Contrat] Contrat : 6 problème(s)", "WARN"), "6 problèmes en tout (3 Wave_, 3 icônes)")
if not logHas("[Contrat] Contrat : 6 problème(s)", "WARN") then
	dump("WARN")
end
-- Tout corrigé : plus de ligne sur les icônes ni de problème.
IconsDir.ICON_Z1_banane:Destroy()
IconsDir.ICON_Z9_Inconnu:Destroy()
for _, child in IconsDir:GetChildren() do
	if child.Name == "ICON_Z1_Ananas" and child:IsA("Part") then
		child:Destroy()
	end
end
IconsDir.ICON_Z2_BallonDeFoot.Texture = "rbxassetid://3"
decal("ICON_Z4_BasketsDeCollection", "rbxassetid://4", IconsDir)
Inbox:Destroy()
clearLog()
Checker.Start()
check(not logHas("icônes ICON_", nil) and logHas("[Contrat] Contrat : OK", "PRINT"), "83 icônes livrées, Wave_ conformes : aucune ligne d'icône, « Contrat : OK »")
if not logHas("[Contrat] Contrat : OK", "PRINT") then
	dump("WARN")
end
Assets:Destroy()

---------------------------------------------------------------- F. ItemIdleController : Wave_
print("== F. ItemIdleController : pièces Wave_ (patte du Chat) et pivot des pièces Spin_")
local Idle = requireModule(IdleModule, "client")
local A = math.rad(ItemIdle.WaveAmplitude)
local P = ItemIdle.WavePeriod
check(Idle.WaveAngle(0) == 0, "WaveAngle(0) = 0 : la pose de départ")
check(near(Idle.WaveAngle(P / 4), A, 1e-12) and near(Idle.WaveAngle(3 * P / 4), -A, 1e-12), "WaveAngle : +A au quart de période, −A aux trois quarts")
check(near(Idle.WaveAngle(P / 2), 0, 1e-12) and near(Idle.WaveAngle(P), 0, 1e-12), "WaveAngle : 0 à la demi-période et à la période")
local bounded, periodic = true, true
for i = 0, 2000 do
	local t = i * 0.0137
	local a = Idle.WaveAngle(t)
	if math.abs(a) > A + 1e-12 then
		bounded = false
	end
	if math.abs(a - Idle.WaveAngle(t + 7 * P)) > 1e-9 then
		periodic = false
	end
end
check(bounded and periodic, "WaveAngle : jamais au-delà de ±WaveAmplitude, périodique (WavePeriod)")
check(Idle.WaveAngle(3600 * 5 + 0.3) == Idle.WaveAngle(3600 * 5 + 0.3), "WaveAngle : ne dépend que de l'instant (aucun état)")

local camera = new("Camera", { CFrame = CFrame.new(0, 3, -10) }, Workspace)
Workspace.CurrentCamera = camera
local displayF = folder(folder(Workspace, "Plot_1"), "DisplayItems")
local function displayModel(name, x, idle)
	local model = new("Model", { Name = name }, nil)
	local root = part("Root", model, CFrame.new(x, 0.25, 0), Vector3.new(1.4, 0.5, 1.2))
	root.PivotOffset = CFrame.new(0, -0.25, 0)
	model.PrimaryPart = root
	if idle then
		model:SetAttribute("Idle", idle)
	end
	return model, root
end
local function show(model)
	model.Parent = displayF
	addTag(model, "DisplayItem")
end
-- Pièce dont le pivot (GetPivot = CFrame × PivotOffset) est `pivot`, centre ailleurs.
local function pivoted(name, parent, center, pivot, class)
	local p = part(name, parent, center, Vector3.new(0.3, 0.5, 0.3), class or "MeshPart")
	p.PivotOffset = center:Inverse() * pivot
	return p
end

-- 1. Le Chat porte-bonheur doré, sans Idle, en x = 0 (décalage dans le temps nul) : pivot à
-- l'épaule, orienté gauche-droite (son axe Y le long de −X).
local SHOULDER = CFrame.new(0.42, 1.25, -0.2) * CFrame.Angles(0, 0, math.pi / 2)
local cat1, catRoot = displayModel("DisplayItem_01", 0, nil)
local gold = part("Gold", cat1, CFrame.new(0, 1, 0))
local paw = pivoted("Wave_Paw", cat1, CFrame.new(0.5, 1.55, -0.35) * CFrame.Angles(0, 0.3, 0), SHOULDER)
local pads = pivoted("Wave_PawPads", cat1, CFrame.new(0.52, 1.7, -0.5), SHOULDER)
local halo = part("RarityHalo", cat1, CFrame.new(0, 1, 0), Vector3.new(2, 2, 2))
new("Attachment", { Name = "Wave_Spark" }, gold) -- pas une pièce : ignorée
show(cat1)
check(cfNear(paw:GetPivot(), SHOULDER, 1e-12) and cfNear(pads:GetPivot(), SHOULDER, 1e-12), "banc : les deux pièces ont le pivot de l'épaule")
local rest = {}
for _, p in { catRoot, gold, paw, pads, halo } do
	rest[p] = p.CFrame
end
local padsFromPaw = paw.CFrame:Inverse() * pads.CFrame

-- 2. Le Chat avec Idle = Bob, en x = 6 (décalage dans le temps : 6 × 0,37 = 2,22 s).
local SHOULDER2 = CFrame.new(6.42, 1.25, -0.2) * CFrame.Angles(0, 0, math.pi / 2)
local cat2, root2 = displayModel("DisplayItem_02", 6, "Bob")
part("Gold", cat2, CFrame.new(6, 1, 0))
local paw2 = pivoted("Wave_Paw", cat2, CFrame.new(6.5, 1.55, -0.35), SHOULDER2)
show(cat2)
local root2Rest = root2.CFrame
local PHASE2 = (6 * 0.37 + 0 * 0.61) % 10

-- 3. Un groupe Wave_ (Model, pivot WorldPivot) avec deux pièces, en x = −6.
local ARM = CFrame.new(-6, 1.2, 0) * CFrame.Angles(math.pi / 2, 0, 0)
local cat3 = displayModel("DisplayItem_03", -6, nil)
local arm = new("Model", { Name = "Wave_Arm", WorldPivot = ARM }, cat3)
local armA = part("Upper", arm, CFrame.new(-6, 1.5, 0.2))
local armB = part("Lower", arm, CFrame.new(-6.1, 1.9, 0.3))
show(cat3)
local armARest, armBRest = armA.CFrame, armB.CFrame
local PHASE3 = (-6 * 0.37) % 10

-- 4. Un ventilateur Spin_ dont le PivotOffset met l'axe Y sur l'avant-arrière (comme ceux du PC
-- gamer), centre de la pièce à 0,05 stud du moyeu, en x = 12.
local FAN = CFrame.new(12, 1, 0.1) * CFrame.Angles(math.pi / 2, 0, 0)
local pc = displayModel("DisplayItem_04", 12, nil)
local fan = pivoted("Spin_Fan1", pc, CFrame.new(12, 1.05, 0.1), FAN, "Part")
show(pc)
local PHASE4 = (12 * 0.37) % 10

-- 5. Rien à animer : pas suivi.
show((displayModel("DisplayItem_05", 3, nil)))

Idle.Start()
local clock = 0
local function frames(n)
	for _ = 1, n do
		step(DT, 30)
		clock += DT
	end
end
frames(1)
local stats = Idle.GetStats()
check(stats.Tracked == 4 and stats.Animated == 4, `suivis : les deux Chats, le groupe Wave_ et le ventilateur ; pas l'objet sans pièce mobile ({stats.Tracked}, {stats.Animated})`)

local function wavePose(t)
	return SHOULDER * CFrame.Angles(0, Idle.WaveAngle(t), 0)
end
local function catOk(t, eps)
	local pivotWanted = wavePose(t)
	return cfNear(paw:GetPivot(), pivotWanted, eps) and cfNear(pads:GetPivot(), pivotWanted, eps)
end
check(catOk(clock, 1e-12), "patte : pivot de l'épaule tourné de WaveAngle(t) autour de son propre axe Y")
check((paw:GetPivot().Position - SHOULDER.Position).Magnitude < 1e-12 and (pads:GetPivot().Position - SHOULDER.Position).Magnitude < 1e-12, "le pivot ne bouge pas : la patte tourne à l'épaule")
check((paw:GetPivot().UpVector - SHOULDER.UpVector).Magnitude < 1e-12 and (SHOULDER.UpVector - Vector3.new(-1, 0, 0)).Magnitude < 1e-12, "axe de rotation : l'axe Y du pivot (gauche-droite), qui ne bouge pas")
check(catRoot.CFrame == rest[catRoot] and gold.CFrame == rest[gold] and halo.CFrame == rest[halo], "sans Idle : le reste du Chat et son halo ne sont jamais réécrits")
-- Sur une période : de −A à +A, toujours sur l'arc (corps rigide), les deux pièces d'un bloc.
local lo, hi = math.huge, -math.huge
local rigid, outside = true, false
for _ = 1, math.ceil(P / DT) + 2 do
	frames(1)
	local rel = SHOULDER:Inverse() * paw:GetPivot()
	local a = math.atan2(rel.r[3], rel.r[1])
	lo = math.min(lo, a)
	hi = math.max(hi, a)
	if math.abs(a) > A + 1e-9 then
		outside = true
	end
	if not cfNear(paw.CFrame:Inverse() * pads.CFrame, padsFromPaw, 1e-9) or not catOk(clock, 1e-9) then
		rigid = false
	end
end
check(not outside and hi > A * 0.98 and lo < -A * 0.98, `va-et-vient de −A à +A (A = {ItemIdle.WaveAmplitude}°), jamais au-delà ({math.floor(math.deg(lo) * 10) / 10}° à {math.floor(math.deg(hi) * 10) / 10}°)`)
check(rigid, "les deux pièces bougent d'un bloc (même pivot, même angle) à chaque image")
-- Avec Bob : la patte suit le mouvement du modèle entier, puis fait signe.
local function cat2Ok()
	local whole = root2.CFrame * root2Rest:Inverse()
	local wanted = whole * SHOULDER2 * CFrame.Angles(0, Idle.WaveAngle(clock + PHASE2), 0)
	return cfNear(paw2:GetPivot(), wanted, 1e-9) and whole.p.Y > -1e-9 and whole.p.Y < ItemIdle.BobHeight + 1e-9
end
check(cat2Ok(), "Idle = Bob : la patte monte avec le Chat et fait signe à son épaule")
-- Groupe Wave_ (Model) : ses pièces tournent ensemble autour du pivot du groupe.
local function armOk()
	local move = ARM * CFrame.Angles(0, Idle.WaveAngle(clock + PHASE3), 0) * ARM:Inverse()
	return cfNear(armA.CFrame, move * armARest, 1e-9) and cfNear(armB.CFrame, move * armBRest, 1e-9)
end
check(armOk(), "groupe Wave_ (Model) : ses pièces font le va-et-vient autour du pivot du groupe")
-- Ventilateur Spin_ : autour de l'axe Y de son pivot (avant-arrière), pas autour de son centre.
local function fanOk()
	local wanted = FAN * CFrame.Angles(0, Idle.PieceAngle(clock + PHASE4), 0)
	return cfNear(fan:GetPivot(), wanted, 1e-9)
end
check(fanOk(), "Spin_ avec PivotOffset : rotation autour de l'axe Y du pivot (GetPivot, comme Clément l'a réglé)")
check((fan:GetPivot().UpVector - Vector3.new(0, 0, 1)).Magnitude < 1e-9 and (fan:GetPivot().Position - FAN.Position).Magnitude < 1e-9, "ventilateur : l'axe reste l'avant-arrière, le moyeu reste en place")
local hubDistance = (fan.Position - FAN.Position).Magnitude
check(near(hubDistance, 0.05, 1e-9) and (fan.Position - Vector3.new(12, 1.05, 0.1)).Magnitude > 1e-3, "ventilateur : son centre tourne autour du moyeu (0,05 stud), il ne tourne pas sur lui-même")

-- 10 000 images (5 min 33 s) : aucune dérive, pose toujours égale au calcul depuis la pose de départ.
frames(10000)
local rel = SHOULDER:Inverse() * paw:GetPivot()
local r = rel.r
local ortho = true
for i = 0, 2 do
	for j = 0, 2 do
		local dot = r[1 + i] * r[1 + j] + r[4 + i] * r[4 + j] + r[7 + i] * r[7 + j]
		if math.abs(dot - (if i == j then 1 else 0)) > 1e-9 then
			ortho = false
		end
	end
end
check(catOk(clock, 1e-9), `après 10 000 images : la patte suit toujours WaveAngle(t) depuis sa pose de départ (t = {math.floor(clock)} s)`)
check(ortho and rel.p.Magnitude < 1e-9 and math.abs(r[2]) < 1e-9 and math.abs(r[4]) < 1e-9 and math.abs(r[6]) < 1e-9 and math.abs(r[8]) < 1e-9, "aucune dérive : rotation pure autour de l'axe Y du pivot, pivot à sa place, matrice orthonormée")
check(cfNear(paw.CFrame:Inverse() * pads.CFrame, padsFromPaw, 1e-9), "après 10 000 images : les deux pièces toujours d'un bloc")
check(cat2Ok() and armOk() and fanOk(), "après 10 000 images : Bob + Wave_, groupe Wave_ et ventilateur sans dérive")
-- Retour exact à la pose de départ : la caméra s'éloigne, les pièces reprennent leur CFrame de départ.
camera.CFrame = CFrame.new(400, 3, 0)
frames(math.ceil(ItemIdle.DistanceCheckInterval / DT) + 2)
check(paw.CFrame == rest[paw] and pads.CFrame == rest[pads], "caméra loin : la patte reprend exactement sa pose de départ (le même CFrame)")
check(cfNear(paw:GetPivot(), SHOULDER, 1e-12) and armA.CFrame == armARest and root2.CFrame == root2Rest, "et les autres objets aussi (pivot de l'épaule, groupe, Bob)")
check(Idle.GetStats().Animated == 0, "plus aucun objet animé loin de la caméra")
camera.CFrame = CFrame.new(0, 3, -10)
frames(math.ceil(ItemIdle.DistanceCheckInterval / DT) + 2)
check(catOk(clock, 1e-9) and Idle.GetStats().Animated == 4, "caméra revenue : la patte reprend le va-et-vient là où l'instant le dit (aucune mémoire des images)")
-- Pièce Wave_ ajoutée pendant l'animation : relue depuis le repos.
local extra = pivoted("Wave_Bell", nil, CFrame.new(0.3, 1.2, -0.5), SHOULDER)
local extraRest = extra.CFrame
extra.Parent = cat1
frames(2)
local move = wavePose(clock) * SHOULDER:Inverse()
check(cfNear(extra.CFrame, move * extraRest, 1e-9) and catOk(clock, 1e-9), "pièce Wave_ ajoutée en cours d'animation : prise dans le mouvement, pose de départ gardée")
cat1:Destroy()
frames(1)
check(Idle.GetStats().Tracked == 3, "objet détruit : plus suivi")

---------------------------------------------------------------- fin
summary()
