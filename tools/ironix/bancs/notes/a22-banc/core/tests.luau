--!nocheck
-- Banc a22 (catalogue d'objets v2, L-045 ; DEV-020) : Config/Items comparé au JSON source,
-- Items.Pick, Tutorial, anciens ItemId du catalogue v1, contrat des ITM_ (Contract/Models,
-- Attributes, ContractChecker sur une fausse place), migration v1 → v2 des profils (vrai
-- DataService, faux ProfileStore) et animation idle (ItemIdleController, calcul des positions).

local TAU = 2 * math.pi

---------------------------------------------------------------- arbre
local Shared = folder(ReplicatedStorage, "Shared")
local ConfigF = folder(Shared, "Config")
for _, n in { "Balance", "Bat", "Cosmetics", "DeepFreeze", "Features", "Formulas", "ItemIdle", "Items", "Night", "PvP", "Rarities", "Shatter", "ShelfBoxes", "Tools", "Training", "Tutorial", "Upgrades", "Zones" } do
	moduleScript(ConfigF, n, `shared/Config/{n}.luau`)
end
local ContractF = folder(Shared, "Contract")
for _, n in { "Animations", "Attributes", "Find", "Icons", "Models", "Tags", "UI" } do -- a31 : Icons (ContractChecker, L-055)
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
local Rarities = requireModule(ConfigF.Rarities, "server")
local Tutorial = requireModule(ConfigF.Tutorial, "server")
local ItemIdle = requireModule(ConfigF.ItemIdle, "server")
local Models = requireModule(ContractF.Models, "server")
local Attributes = requireModule(ContractF.Attributes, "server")
local RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

---------------------------------------------------------------- A. catalogue = JSON
print("== A. Config/Items = docs/claude/notes/objets-catalogue-v2.json")
local json = decodeJson(JSON_TEXT)
local expected = {}
for _, zone in json.zones do
	for _, category in zone.categories do
		for _, item in category.items do
			table.insert(expected, {
				Id = item.itemId,
				Asset = item.asset,
				DisplayName = item.nameEn,
				Rarity = item.rarity,
				Zone = zone.zone,
				Category = category.nameEn,
				CategoryId = category.id,
			})
		end
	end
end
local s = json.secret
table.insert(expected, { Id = s.itemId, Asset = s.asset, DisplayName = s.nameEn, Rarity = s.rarity, Zone = nil, Category = s.categoryEn, CategoryId = "Secret" })
-- a31 : 83 objets depuis les 9 ajouts de Clément du 2026-11-07 (L-055).
check(#expected == 83 and #Items.List == 83, `83 objets au JSON ({#expected}) et dans Config/Items ({#Items.List})`)
local sameAll, firstDiff = true, nil
for i, e in expected do
	local got = Items.List[i]
	for _, field in { "Id", "Asset", "DisplayName", "Rarity", "Zone", "Category", "CategoryId" } do
		if got == nil or got[field] ~= e[field] then
			sameAll = false
			firstDiff = firstDiff or `{i} {e.Id} : {field} = {got and tostring(got[field])}, JSON {tostring(e[field])}`
		end
	end
end
check(sameAll, "chaque objet, dans l'ordre du JSON : Id, Asset, nom et catégorie anglais, id de catégorie, rareté, zone" .. (if firstDiff then ` ({firstDiff})` else ""))
local unique, assetsOk, asciiOk = true, true, true
local seenIds = {}
for _, item in Items.List do
	if seenIds[item.Id] then
		unique = false
	end
	seenIds[item.Id] = true
	if item.Asset ~= `ITM_{item.Id}` or Items.ById[item.Id] ~= item then
		assetsOk = false
	end
	if string.find(item.DisplayName, "[\128-\255]") or string.find(item.Category, "[\128-\255]") or string.find(item.CategoryId, "[\128-\255]") then
		asciiOk = false
	end
end
check(unique, "ItemId uniques")
check(assetsOk, "Asset = ITM_<ItemId>, ById[Id] = l'objet de List")
check(asciiOk, "noms, catégories et ids de catégorie sans accent (textes anglais, L-036)")
-- Comptes par zone et par rareté (objets-catalogue-v2.md, « Règles validées »)
local counts = {}
for _, item in Items.List do
	local key = `{tostring(item.Zone)}.{item.Rarity}`
	counts[key] = (counts[key] or 0) + 1
end
check(counts["1.Common"] == 12 and counts["1.Rare"] == 1 and counts["1.Uncommon"] == nil and counts["1.Epic"] == nil, "zone 1 : 12 Communs et le Pot de nouilles (Rare)")
-- a31 : objets-catalogue-v2.md, « Pour ouverture-colis » : ensembles par (zone, rareté) depuis les
-- 9 ajouts (zone 2 = 16 objets, zone 3 = 14, zone 4 = 15, zones 5 et 6 = 12).
local ZONE_SETS = {
	[2] = { Common = 4, Uncommon = 5, Rare = 2, Epic = 3, Legendary = 1, Mythic = 1, Total = 16 },
	[3] = { Common = 3, Uncommon = 3, Rare = 3, Epic = 3, Legendary = 1, Mythic = 1, Total = 14 },
	[4] = { Common = 4, Uncommon = 4, Rare = 3, Epic = 2, Legendary = 1, Mythic = 1, Total = 15 },
	[5] = { Common = 3, Uncommon = 3, Rare = 2, Epic = 2, Legendary = 1, Mythic = 1, Total = 12 },
	[6] = { Common = 3, Uncommon = 3, Rare = 2, Epic = 2, Legendary = 1, Mythic = 1, Total = 12 },
}
local zonesOk = true
for zone = 2, 6 do
	local want = ZONE_SETS[zone]
	local total = 0
	for _, rarity in RARITY_ORDER do
		if counts[`{zone}.{rarity}`] ~= want[rarity] then
			zonesOk = false
		end
		total += want[rarity]
	end
	if total ~= want.Total then
		zonesOk = false
	end
end
check(zonesOk, "zones 2 à 6 : 16, 14, 15, 12 et 12 objets (zone 2 : 4, 5, 2, 3, 1, 1 ; zone 3 : 3, 3, 3, 3, 1, 1 ; zone 4 : 4, 4, 3, 2, 1, 1 ; zones 5 et 6 : 3, 3, 2, 2, 1, 1)")
check(counts["nil.Secret"] == 1 and #Items.Secrets == 1 and Items.Secrets[1].Id == "Secret_ChatPorteBonheurDore", "1 Secret, sans zone")
check(Items.ById.Secret_ChatPorteBonheurDore.Category == "???" and Items.ById.Secret_ChatPorteBonheurDore.DisplayName == "Golden Lucky Cat", "Secret : catégorie affichée « ??? », nom anglais")
local categoriesOk = true
for zone = 1, 6 do
	local ids = {}
	local n = 0
	for _, item in Items.List do
		if item.Zone == zone and not ids[item.CategoryId] then
			ids[item.CategoryId] = true
			n += 1
		end
	end
	if n ~= (if zone == 4 then 5 else 4) then -- a31 : Mode (Fashion) en zone 4
		categoriesOk = false
	end
end
check(categoriesOk, "4 catégories par zone, 5 en zone 4 (Mode / Fashion)")
local fashion = {}
for _, item in Items.List do
	if item.CategoryId == "Mode" then
		table.insert(fashion, item.Id)
		if item.Category ~= "Fashion" or item.Zone ~= 4 then
			fashion = {}
			break
		end
	end
end
check(table.concat(fashion, ",") == "Z4_Parfum,Z4_LunettesDeStar,Z4_BasketsDeCollection", "catégorie Mode / Fashion (zone 4) : Parfum, Lunettes de star, Baskets de collection")
local tutorialOnly = {}
for _, item in Items.List do
	if item.TutorialOnly then
		table.insert(tutorialOnly, item.Id)
	end
end
check(#tutorialOnly == 1 and tutorialOnly[1] == "Z1_PotDeNouilles", "seul le Pot de nouilles est TutorialOnly")
-- ByZone : objets tirables, dans l'ordre du catalogue, sans les TutorialOnly ; 6 raretés, jamais Secret
local byZoneOk = true
for zone = 1, 6 do
	local byRarity = Items.ByZone[zone]
	if byRarity == nil or byRarity.Secret ~= nil then
		byZoneOk = false
		continue
	end
	for _, rarity in RARITY_ORDER do
		local want = {}
		for _, item in Items.List do
			if item.Zone == zone and item.Rarity == rarity and not item.TutorialOnly then
				table.insert(want, item)
			end
		end
		local list = byRarity[rarity]
		if list == nil or #list ~= #want then
			byZoneOk = false
		else
			for i, item in want do
				if list[i] ~= item then
					byZoneOk = false
				end
			end
		end
	end
end
check(byZoneOk, "ByZone[zone][rareté] : liste des tirables dans l'ordre du catalogue, 6 raretés, vide s'il n'y en a pas")
check(#Items.ByZone[1].Rare == 0 and #Items.ByZone[1].Uncommon == 0 and #Items.ByZone[1].Common == 12, "zone 1 : Rare vide (Pot de nouilles exclu), 12 Communs tirables")
check(#Items.ByZone[3].Rare == 3 and Items.ByZone[3].Rare[1].Id == "Z3_Smartphone" and Items.ByZone[3].Rare[2].Id == "Z3_CasqueVr" and Items.ByZone[3].Rare[3].Id == "Z3_ConsoleADoubleEcran", "ByZone[3].Rare = { Smartphone, Casque VR, Console à double écran }")
check(Items.ByZone[7] == nil, "pas de zone 7")
check(table.isfrozen(Items) and table.isfrozen(Items.List) and table.isfrozen(Items.ByZone[2].Common) and table.isfrozen(Items.ById.Z2_YoYo), "catalogue gelé (DeepFreeze)")
check(not pcall(function() Items.ById.Z2_YoYo.Rarity = "Mythic" end), "écrire dans un objet lève une erreur")

---------------------------------------------------------------- B. Items.Pick
print("== B. Items.Pick")
local rng = Random.new(2207)
local function draws(zone, rarity, n)
	local seen = {}
	for _ = 1, n do
		local item = Items.Pick(zone, rarity, rng)
		local key = if item then item.Id else "nil"
		seen[key] = (seen[key] or 0) + 1
	end
	return seen
end
local d3 = draws(3, "Common", 30000)
local spreadOk = true
for _, item in Items.ByZone[3].Common do
	local share = (d3[item.Id] or 0) / 30000
	if math.abs(share - 1 / 3) > 0.02 then
		spreadOk = false
	end
end
check(spreadOk and d3["nil"] == nil, "zone 3 Commun : chacun des 3 objets ≈ 1/3 des 30 000 tirages (± 2 %)")
local d1 = draws(1, "Common", 24000)
local spread1 = true
for _, item in Items.ByZone[1].Common do
	if math.abs((d1[item.Id] or 0) / 24000 - 1 / 12) > 0.01 then
		spread1 = false
	end
end
check(spread1, "zone 1 Commun : chacun des 12 objets ≈ 1/12 des tirages (± 1 %)")
check(Items.Pick(1, "Rare", rng) == nil and Items.Pick(1, "Uncommon", rng) == nil and Items.Pick(1, "Mythic", rng) == nil, "liste vide : nil (zone 1 Rare, Peu commun, Mythique)")
check(Items.Pick(7, "Common", rng) == nil and Items.Pick(0, "Common", rng) == nil, "zone inconnue : nil")
local secretOk = true
for _, zone in { 1, 2, 3, 4, 5, 6, 42 } do
	local item = Items.Pick(zone, "Secret", rng)
	if item == nil or item.Id ~= "Secret_ChatPorteBonheurDore" then
		secretOk = false
	end
end
check(secretOk, "Secret : le Chat porte-bonheur doré, quelle que soit la zone")
local neverTutorial, sameRecords = true, true
for zone = 1, 6 do
	for _, rarity in RARITY_ORDER do
		for _ = 1, 50 do
			local item = Items.Pick(zone, rarity, rng)
			if item then
				if item.TutorialOnly then
					neverTutorial = false
				end
				if Items.ById[item.Id] ~= item or item.Zone ~= zone or item.Rarity ~= rarity then
					sameRecords = false
				end
			end
		end
	end
end
check(neverTutorial, "jamais un objet TutorialOnly (6 zones × 6 raretés × 50 tirages)")
check(sameRecords, "l'objet rendu est celui du catalogue, de cette zone et de cette rareté")
local noRng = Items.Pick(4, "Uncommon")
check(noRng ~= nil and table.find(Items.ByZone[4].Uncommon, noRng) ~= nil, "sans Random donné : le Random du module")

---------------------------------------------------------------- C. tuto
print("== C. Tutorial")
local guaranteed = Items.ById[Tutorial.GuaranteedItemId]
check(Tutorial.GuaranteedItemId == "Z1_PotDeNouilles" and guaranteed ~= nil, "GuaranteedItemId = Z1_PotDeNouilles, au catalogue")
check(guaranteed.TutorialOnly and guaranteed.Zone == 1 and guaranteed.Rarity == Tutorial.GuaranteedRarity and Tutorial.FirstBoxTier == "Premium", "objet garanti : TutorialOnly, zone 1, de la rareté garantie (Rare), colis Premium")

---------------------------------------------------------------- D. anciens ItemId
print("== D. Anciens ItemId (catalogue v1)")
check(Items.RenamedV1.Z4_Montre == "Z4_MontreEnOr" and Items.RenamedV1.Z5_Vase == "Z5_VaseAncien", "renommés : Z4_Montre → Z4_MontreEnOr, Z5_Vase → Z5_VaseAncien")
-- Rareté et zone v1 des retirés (doc 10.5), et la règle : premier tirable de même zone et rareté,
-- sinon de la rareté la plus proche en dessous.
local V1 = {
	Z1_TicketAGratterGagnant = { 1, "Legendary" },
	Z1_HotDogEnOr = { 1, "Mythic" },
	Z5_ToileAbstraite = { 5, "Rare" },
	Z6_LiasseDeBillets = { 6, "Common" },
	Z6_SacDePieces = { 6, "Uncommon" },
	Z6_MalletteDeBillets = { 6, "Epic" },
}
local retiredCount, ruleOk = 0, true
for old, new in Items.RetiredV1 do
	retiredCount += 1
	local v1 = V1[old]
	local want = nil
	if v1 then
		local order = table.find(RARITY_ORDER, v1[2])
		for o = order, 1, -1 do
			local list = Items.ByZone[v1[1]][RARITY_ORDER[o]]
			if #list > 0 then
				want = list[1].Id
				break
			end
		end
	end
	if want ~= new or Items.ById[old] ~= nil then
		ruleOk = false
		print(`  (banc) {old} → {new}, la règle donne {tostring(want)}`)
	end
end
check(retiredCount == 6, "6 retirés")
check(ruleOk, "chaque retiré → premier objet tirable de même zone et rareté, sinon la rareté la plus proche en dessous")
check(Items.RetiredV1.Z1_HotDogEnOr == "Z1_CanetteDeSoda" and Items.RetiredV1.Z6_MalletteDeBillets == "Z6_TroneEnOr", "ex. Hot-dog en or → Canette de soda, Mallette → Trône en or")

---------------------------------------------------------------- E. contrat
print("== E. Contrat : Contract/Models et Contract/Attributes")
check(Models.Item.ExpectedCount == 83, "ExpectedCount des ITM_ = #Items.List = 83")
local knownCount = 0
for name in Models.Item.Known do
	knownCount += 1
	if Items.ById[string.sub(name, 5)] == nil then
		knownCount = -1000
	end
end
check(knownCount == 83, "Known : les 83 noms de modèles du catalogue")
check(Models.Item.Renamed.ITM_Z4_Montre == "ITM_Z4_MontreEnOr" and Models.Item.Retired.ITM_Z1_HotDogEnOr == true and Models.Item.Known.ITM_Z1_HotDogEnOr == nil, "anciens noms : renommés et retirés")
check(table.concat(Attributes.Idle.Values, ",") == "Spin,Bob,SpinBob" and Attributes.Idle.Name == "Idle" and Models.Item.SpinPrefix == "Spin_", "attribut Idle (Spin, Bob, SpinBob) et préfixe Spin_")

---------------------------------------------------------------- F. ContractChecker
print("== F. ContractChecker : objets ITM_ (catalogue v2, idle)")
local Assets = folder(ReplicatedStorage, "Assets")
local AssetItems = folder(Assets, "Items")
local Inbox = folder(Workspace, "_INBOX_CLEMENT")
local function part(name, parent, position, size)
	return new("Part", { Name = name, Size = size or Vector3.new(1, 1, 1), CFrame = CFrame.new(position.X, position.Y, position.Z), Anchored = true }, parent)
end
-- Modèle ITM_ conforme au 10.4 : Root (PrimaryPart) et ItemId = nom sans ITM_.
local function itm(name, parent, itemId)
	local model = new("Model", { Name = name }, nil)
	local root = part("Root", model, Vector3.new(0, 0.25, 0), Vector3.new(1, 0.5, 1))
	model.PrimaryPart = root
	model:SetAttribute("ItemId", itemId or string.sub(name, 5))
	part("Body", model, Vector3.new(0, 1, 0))
	model.Parent = parent
	return model
end
itm("ITM_Z1_CanetteDeSoda", AssetItems)
local holo = itm("ITM_Z2_FigurineHolographique", AssetItems)
part("Spin_Ring", holo, Vector3.new(0, 1.5, 0))
part("Spin_Figure", holo, Vector3.new(0, 1.2, 0))
itm("ITM_Z2_PelucheGeante", AssetItems):SetAttribute("Idle", "Bob")
itm("ITM_Z1_CanetteDeSoda", Inbox) -- le même, livré aussi dans l'inbox : compté une fois
itm("ITM_Z4_Montre", Inbox) -- renommé
itm("ITM_Z1_HotDogEnOr", Inbox) -- retiré
itm("ITM_Z1_canetteDeSoda", Inbox) -- faute de casse
itm("ITM_Z3_Smartphone", Inbox, "Z3_SmartPhone") -- ItemId faux
itm("ITM_Z4_Couronne", Inbox):SetAttribute("Idle", "Twirl") -- valeur inconnue
local carrot = itm("ITM_Z1_Carotte", Inbox)
part("Root", carrot, Vector3.new(0, 1.8, 0)) -- deuxième Root (relevé Studio, L-045)
local meteor = new("Model", { Name = "ITM_Z5_Meteorite" }, nil)
local core = new("Model", { Name = "Spin_Core" }, meteor)
meteor.PrimaryPart = part("Root", core, Vector3.new(0, 0.25, 0))
meteor:SetAttribute("ItemId", "Z5_Meteorite")
meteor.Parent = Inbox
local pc = itm("ITM_Z3_PcGamer", Inbox)
local fan = part("Spin_Fan", pc, Vector3.new(0, 1, 0.5))
new("WeldConstraint", { Name = "FanWeld", Part0 = fan, Part1 = pc.Body }, fan)
new("Attachment", { Name = "Spin_Light" }, pc.Body)
local key = itm("ITM_Z6_CleDuCoffreUltime", Inbox)
key.Root:SetAttribute("Idle", "Spin") -- sur une pièce, pas sur le modèle
clearLog()
local Checker = requireModule(CheckerModule, "server")
Checker.Start()
check(logHas("ITM_Z4_Montre : objet renommé au catalogue v2 (L-045), le renommer ITM_Z4_MontreEnOr", "WARN"), "nom renommé : refusé, nouveau nom donné")
check(logHas("ITM_Z1_HotDogEnOr : objet retiré du catalogue v2 (L-045)", "WARN"), "nom retiré : refusé")
check(logHas("ITM_Z1_canetteDeSoda : ITM_Z1_canetteDeSoda n'est pas au catalogue d'objets (Config/Items) : le renommer ITM_Z1_CanetteDeSoda", "WARN"), "faute de casse : refusé, nom exact donné")
check(logHas("ITM_Z3_Smartphone : ItemId = « Z3_SmartPhone », attendu « Z3_Smartphone »", "WARN"), "ItemId différent du nom : signalé")
check(logHas("ITM_Z4_Couronne : Idle = « Twirl », attendu Spin, Bob, SpinBob ou rien (L-045)", "WARN"), "Idle inconnu : signalé en orange")
check(logHas("ITM_Z1_Carotte : 2 éléments nommés Root, un seul attendu", "WARN"), "deux Root : signalé (ITM_Z1_Carotte)")
check(logHas("ITM_Z5_Meteorite.Root est dans Spin_Core", "WARN"), "Root dans une pièce Spin_ : signalé")
check(logHas("ITM_Z3_PcGamer.Spin_Fan : soudée au reste du modèle par FanWeld (WeldConstraint)", "WARN"), "pièce Spin_ soudée au reste : signalée")
check(logHas("ITM_Z3_PcGamer.Spin_Light : une pièce Spin_ doit être une pièce (BasePart) ou un Model (trouvé : Attachment)", "WARN"), "Spin_ qui n'est pas une pièce : signalé")
check(logHas("ITM_Z6_CleDuCoffreUltime.Root : attribut Idle ignoré par le code ici, le poser sur le modèle ITM_Z6_CleDuCoffreUltime lui-même", "WARN"), "Idle sur une pièce : signalé")
check(logCount("FigurineHolographique", "WARN") == 0 and logCount("PelucheGeante", "WARN") == 0, "noms v2 conformes, avec pièces Spin_ ou Idle = Bob : rien à signaler")
check(logHas("objets exposés ITM_* : 9 sur 83 livrés", "PRINT"), "compte : 9 noms du catalogue sur 83 (doublon, ancien nom et faute non comptés)")
check(logHas("[Contrat] Contrat : 10 problème(s)", "WARN"), "10 problèmes en tout, tous du catalogue ou de l'idle")
if not logHas("[Contrat] Contrat : 10 problème(s)", "WARN") then
	for _, line in LOG do
		if line.kind == "WARN" then
			print("    " .. line.text)
		end
	end
end
Assets:Destroy()
Inbox:Destroy()

---------------------------------------------------------------- G. migration v1 → v2
print("== G. Migration des profils v1 → v2 (DataService)")
local function v1Profile(items, boxes)
	return {
		Version = 1,
		Cash = 1234,
		Stats = { Speed = 3, Strength = 4 },
		Upgrades = { Treadmill = 1, Bench = 0, DisplaySlots = 2, UnboxBenches = 1 },
		Tools = { Owned = { "Fists", "Wrench" }, Equipped = "Wrench" },
		Cosmetics = { Auras = { "Spark" }, Trails = {}, EquippedAura = "Spark", EquippedTrail = nil },
		Items = items,
		Display = { ["1"] = "u1", ["2"] = "u3" },
		Vault = { ["1"] = "u5" },
		Boxes = boxes,
		Tutorial = { Step = 10, Done = true },
		Lifetime = { Heists = 7, Steals = 0, Defenses = 0, PlaySeconds = 600 },
		Purchases = { ["purchase-1"] = true },
	}
end
PRESET_PROFILES["Player_101"] = v1Profile({
	u1 = { Id = "Z4_Montre", Source = "NPC", At = 100, Zone = 4 },
	u2 = { Id = "Z5_Vase", Source = "PvP", At = 101 },
	u3 = { Id = "Z1_TicketAGratterGagnant", Source = "NPC", At = 102, Zone = 1 },
	u4 = { Id = "Z1_HotDogEnOr", Source = "NPC", At = 103, Zone = 1 },
	u5 = { Id = "Z5_ToileAbstraite", Source = "NPC", At = 104, Zone = 5 },
	u6 = { Id = "Z6_LiasseDeBillets", Source = "NPC", At = 105, Zone = 6 },
	u7 = { Id = "Z6_SacDePieces", Source = "NPC", At = 106, Zone = 6 },
	u8 = { Id = "Z6_MalletteDeBillets", Source = "NPC", At = 107, Zone = 6 },
	u9 = { Id = "Z3_Smartphone", Source = "NPC", At = 108, Zone = 3 },
	u10 = { Id = "Z1_BoissonEnergisante", Source = "NPC", At = 109, Zone = 1 },
	u11 = { Id = "Z9_Inconnu", Source = "NPC", At = 110 },
	u12 = { Source = "NPC", At = 111 },
	u13 = "pas une table",
	u14 = { Id = "Secret_ChatPorteBonheurDore", Source = "NPC", At = 112, Zone = 6 },
}, {
	["1"] = { Tier = "Luxe", Zone = 6, ItemId = "Z6_MalletteDeBillets", Rarity = "Epic", ReadyAt = 1000 },
	["2"] = { Tier = "Standard", Zone = 1, ItemId = "Z1_BoissonEnergisante", Rarity = "Epic", ReadyAt = 1001 },
	["3"] = { Tier = "Premium", Zone = 4, ItemId = "Z4_Montre", Rarity = "Uncommon", ReadyAt = 1002 },
	["4"] = { Tier = "Premium", Zone = 1, ItemId = "Z1_HotDogEnOr", Rarity = "Mythic", ReadyAt = 1003 },
	["5"] = { Tier = "Standard", Zone = 3, ItemId = "Z3_Inconnu", Rarity = "Rare", ReadyAt = 1004 },
	["6"] = { Tier = "Standard", Zone = 3, ItemId = "Z3_Smartphone", Rarity = "Rare", ReadyAt = 1005 },
})
PRESET_PROFILES["Player_102"] = { -- déjà en v2
	Version = 2,
	Cash = 5,
	Items = { a = { Id = "Z1_Banane", Source = "NPC", At = 1, Zone = 1 }, b = { Id = "Z9_Futur", Source = "NPC", At = 2 } },
	Boxes = { ["1"] = { Tier = "Standard", Zone = 1, ItemId = "Z1_Donut", Rarity = "Rare", ReadyAt = 9 } },
}
PRESET_PROFILES["Player_103"] = { Cash = 7, Items = { u1 = { Id = "Z5_Vase", Source = "NPC", At = 3 } } } -- sans Version (v0)
PRESET_PROFILES["Player_105"] = { Version = 3, Cash = 99 } -- écrit par une version plus récente
PRESET_PROFILES["Player_106"] = { Version = 1, Cash = 1, Boxes = "pas une table" } -- Items absent

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
clearLog()
local P1 = join("P1", 101)
local d = DataService.Get(P1)
check(d ~= nil and d.Version == 2, "profil v1 complet : chargé, passé en v2")
local it = d.Items
check(it.u1.Id == "Z4_MontreEnOr" and it.u2.Id == "Z5_VaseAncien", "renommés : Z4_MontreEnOr, Z5_VaseAncien")
check(it.u1.Source == "NPC" and it.u1.At == 100 and it.u1.Zone == 4 and it.u2.Source == "PvP" and it.u2.Zone == nil, "uid, source, heure et zone gardés")
check(
	it.u3.Id == "Z1_CanetteDeSoda" and it.u4.Id == "Z1_CanetteDeSoda" and it.u5.Id == "Z5_StatueDoree" and it.u6.Id == "Z6_LingotDOr"
		and it.u7.Id == "Z6_PyramideDeLingots" and it.u8.Id == "Z6_TroneEnOr",
	"retirés remplacés (Items.RetiredV1)"
)
check(it.u9.Id == "Z3_Smartphone" and it.u10.Id == "Z1_BoissonEnergisante" and it.u14.Id == "Secret_ChatPorteBonheurDore" and it.u14.Zone == 6, "objets du catalogue v2 inchangés")
check(it.u11.Id == "Z9_Inconnu" and it.u12 ~= nil and it.u12.Id == nil and it.u13 == "pas une table", "inconnu, sans Id ou illisible : gardé tel quel (rien d'effacé)")
local itemCount = 0
for _ in it do
	itemCount += 1
end
check(itemCount == 14, "14 objets avant, 14 après")
local b = d.Boxes
check(b["1"].ItemId == "Z6_TroneEnOr" and b["1"].Rarity == "Epic" and b["1"].Tier == "Luxe" and b["1"].Zone == 6 and b["1"].ReadyAt == 1000, "colis : retiré remplacé, même rareté, type, zone et ReadyAt gardés")
check(b["2"].ItemId == "Z1_BoissonEnergisante" and b["2"].Rarity == "Common", "colis : rareté remise à celle du catalogue v2 (Boisson énergisante : Commun)")
check(b["3"].ItemId == "Z4_MontreEnOr" and b["3"].Rarity == "Common" and b["3"].ReadyAt == 1002, "colis : renommé, et sa rareté suit (Montre en or : Commun)")
check(b["4"].ItemId == "Z1_CanetteDeSoda" and b["4"].Rarity == "Common" and b["4"].Tier == "Premium", "colis : Hot-dog en or (Mythique) → Canette de soda (Commun)")
check(b["5"].ItemId == "Z3_Inconnu" and b["5"].Rarity == "Rare" and b["6"].ItemId == "Z3_Smartphone" and b["6"].Rarity == "Rare", "colis : inconnu gardé tel quel, colis à jour inchangé")
check(d.Cash == 1234 and d.Display["2"] == "u3" and d.Vault["1"] == "u5" and d.Purchases["purchase-1"] and d.Tools.Equipped == "Wrench", "le reste du profil ne change pas")
local prefix = "[DataService] P1 (Player_101) : migration v2 : "
check(logHas(prefix .. "objet u1 : Z4_Montre renommé Z4_MontreEnOr (catalogue v2)", "PRINT"), "sortie : renommage")
check(logHas(prefix .. "objet u4 : Z1_HotDogEnOr, retiré du catalogue v2, remplacé par Z1_CanetteDeSoda", "WARN"), "sortie (orange) : remplacement")
check(logCount("retiré du catalogue v2, remplacé par", "WARN") == 8, "un avertissement par remplacement (6 objets, 2 colis)")
check(logHas(prefix .. "objet u11 : ItemId « Z9_Inconnu » inconnu du catalogue v2, gardé tel quel", "WARN"), "sortie (orange) : ItemId inconnu")
check(logHas(prefix .. "objet u12 : ItemId absent ou qui n'est pas un texte (nil), gardé tel quel", "WARN") and logHas(prefix .. "Items[u13] n'est pas une table : gardé tel quel", "WARN"), "sortie (orange) : objets illisibles")
check(logHas(prefix .. "colis de l'établi 2 : rareté Epic remise à Common, celle de Z1_BoissonEnergisante au catalogue v2", "PRINT"), "sortie : rareté d'un colis remise à jour")
check(logHas("[DataService] P1 : profil Player_101 chargé (v2", "PRINT") and #KICKS == 0, "chargé sans expulsion")

local P2 = join("P2", 102)
local d2 = DataService.Get(P2)
check(d2.Version == 2 and d2.Items.a.Id == "Z1_Banane" and d2.Items.b.Id == "Z9_Futur" and d2.Boxes["1"].Rarity == "Rare", "profil déjà en v2 : rien ne change")
check(logCount("P2 (Player_102) : migration", nil) == 0, "profil déjà en v2 : aucune ligne de migration")
check(d2.Stats ~= nil and d2.Stats.Speed == 0, "champs manquants complétés depuis le modèle (Reconcile)")
local P3 = join("P3", 103)
local d3p = DataService.Get(P3)
check(d3p.Version == 2 and d3p.Items.u1.Id == "Z5_VaseAncien" and d3p.Cash == 7, "profil sans Version (v0) : v1 puis v2, renommé")
local P4 = join("P4", 104)
local d4 = DataService.Get(P4)
check(d4 ~= nil and d4.Version == 2 and next(d4.Items) == nil and logCount("P4 (Player_104) : migration", nil) == 0, "nouveau profil : créé en v2, sans migration")
local P5 = join("P5", 105)
check(DataService.Get(P5) == nil and #KICKS == 1 and KICKS[1].player == P5 and SESSIONS["Player_105"].ended, "profil v3 (plus récent) : pas chargé, session fermée, joueur expulsé")
check(KICKS[1] and KICKS[1].message == "The game was just updated. Join a new server to get your progress back.", "message d'expulsion en anglais (TooNew)")
local P6 = join("P6", 106)
local d6 = DataService.Get(P6)
check(d6 ~= nil and d6.Version == 2 and type(d6.Items) == "table" and d6.Boxes == "pas une table" and #KICKS == 1, "profil v1 mal formé (Items absent, Boxes illisible) : chargé sans planter")
check(not logHas("échec de la migration", "WARN"), "aucune migration en échec")

---------------------------------------------------------------- H. animation idle
print("== H. ItemIdleController (animation idle, client)")
local Idle = requireModule(IdleModule, "client")
local spin, height = Idle.ModelMotion(nil, 3.7)
check(spin == 0 and height == 0, "ModelMotion(nil) : immobile")
spin, height = Idle.ModelMotion("Twirl", 3.7)
check(spin == 0 and height == 0, "ModelMotion(valeur inconnue) : immobile")
local quarter = 1 / ItemIdle.SpinTurnsPerSecond / 4
spin, height = Idle.ModelMotion("Spin", quarter)
check(near(spin, math.pi / 2, 1e-9) and height == 0, "Spin : un quart de tour en 1/(4 × tours par seconde) s, sans hauteur")
local _, h0 = Idle.ModelMotion("Bob", 0)
local spinBob, hHalf = Idle.ModelMotion("Bob", ItemIdle.BobPeriod / 2)
check(near(h0, 0, 1e-12) and near(hHalf, ItemIdle.BobHeight, 1e-12) and spinBob == 0, "Bob : 0 au départ, BobHeight à mi-période, sans rotation")
local bobRange = true
for i = 0, 200 do
	local _, h = Idle.ModelMotion("Bob", i * 0.037)
	if h < -1e-12 or h > ItemIdle.BobHeight + 1e-12 then
		bobRange = false
	end
end
check(bobRange, "Bob : jamais sous la position de repos ni au-dessus de BobHeight")
spin, height = Idle.ModelMotion("SpinBob", ItemIdle.BobPeriod / 2)
check(near(spin, (ItemIdle.BobPeriod / 2 * ItemIdle.SpinTurnsPerSecond % 1) * TAU, 1e-9) and near(height, ItemIdle.BobHeight, 1e-12), "SpinBob : les deux")
check(near(Idle.PieceAngle(1 / ItemIdle.PieceTurnsPerSecond / 2), math.pi, 1e-9) and near(Idle.PieceAngle(1 / ItemIdle.PieceTurnsPerSecond), 0, 1e-9), "PieceAngle : un demi-tour, puis un tour complet (0)")

local camera = new("Camera", { CFrame = CFrame.new(20, 5, 10) }, Workspace)
Workspace.CurrentCamera = camera
local displayF = folder(folder(Workspace, "Plot_1"), "DisplayItems")
local function displayModel(name, pivot, idle)
	local model = new("Model", { Name = name }, nil)
	local root = part("Root", model, pivot + Vector3.new(0, 0.25, 0), Vector3.new(1, 0.5, 1))
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
-- 1 : SpinBob, une pièce Spin_, un groupe Spin_ (Model) avec une pièce Spin_ dedans, halo et point de billboard
local m1, root1 = displayModel("DisplayItem_01", Vector3.new(10, 0, 0), "SpinBob")
local body1 = part("Body", m1, Vector3.new(10.6, 1, 0.4))
local ring1 = part("Spin_Ring", m1, Vector3.new(10.3, 1.5, -0.2))
ring1.CFrame = ring1.CFrame * CFrame.Angles(0, 0.3, 0)
local group1 = new("Model", { Name = "Spin_Group", WorldPivot = CFrame.new(9.4, 1.1, 0.6) }, m1)
local inner1 = part("Spin_Inner", group1, Vector3.new(9.5, 1.2, 0.5))
local groupPart1 = part("GroupPart", group1, Vector3.new(9.2, 1.0, 0.8))
local halo1 = part("RarityHalo", m1, Vector3.new(10, 1, 0), Vector3.new(2, 2, 2))
local point1 = new("Attachment", { Name = "BillboardPoint", CFrame = CFrame.new(0.3, 1.2, 0) }, root1)
show(m1)
-- 2 : pas d'Idle, une pièce Spin_ (comme ITM_Z2_FigurineHolographique)
local m2, root2 = displayModel("DisplayItem_02", Vector3.new(20, 0, 0), nil)
local base2 = part("Base", m2, Vector3.new(20, 0.6, 0))
local ring2 = part("Spin_Ring", m2, Vector3.new(20.2, 1.4, 0.1))
show(m2)
-- 3 : Bob seul
local m3, root3 = displayModel("DisplayItem_03", Vector3.new(30, 0, 0), "Bob")
local body3 = part("Body", m3, Vector3.new(30, 1, 0))
show(m3)
-- 4 : Idle inconnu, sans pièce Spin_ ; 5 : rien
local m4 = displayModel("DisplayItem_04", Vector3.new(26, 0, 4), "Twirl")
show(m4)
local m5 = displayModel("DisplayItem_05", Vector3.new(24, 0, 6), nil)
show(m5)

local rest = {}
for _, p in { root1, body1, ring1, inner1, groupPart1, halo1, root2, base2, ring2, root3, body3 } do
	rest[p] = p.CFrame
end
local pointRestWorld = point1.WorldCFrame
local pivot1 = CFrame.new(10, 0, 0)

Idle.Start()
-- 6 : loin de la caméra, ajouté après le démarrage
local m6, root6 = displayModel("DisplayItem_06", Vector3.new(500, 0, 0), "Spin")
local body6 = part("Body", m6, Vector3.new(500.5, 1, 0))
show(m6)
rest[root6], rest[body6] = root6.CFrame, body6.CFrame

step(0.5)
local stats = Idle.GetStats()
check(stats.Tracked == 4 and stats.Animated == 3, `suivis : SpinBob, Spin_ seul, Bob et le lointain (Idle inconnu ou rien : pas suivis) ; 3 animés ({stats.Tracked}, {stats.Animated})`)

local function yawOf(cf)
	return math.atan2(cf.r[3], cf.r[1])
end
local function angleDiff(a, b)
	local diff = (a - b) % TAU
	if diff > math.pi then
		diff -= TAU
	end
	return diff
end
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
-- Déplacement d'ensemble du modèle 1, lu sur Root.
local function wholeMove()
	return root1.CFrame * rest[root1]:Inverse()
end
local function isYawLift(m)
	local r = m.r
	local up = math.abs(r[2]) < 1e-9 and math.abs(r[4]) < 1e-9 and math.abs(r[6]) < 1e-9 and math.abs(r[8]) < 1e-9 and near(r[5], 1, 1e-9)
	local axis = m * pivot1.Position - pivot1.Position
	return up and math.abs(axis.X) < 1e-9 and math.abs(axis.Z) < 1e-9 and axis.Y >= -1e-9 and axis.Y <= ItemIdle.BobHeight + 1e-9, axis.Y
end

local M = wholeMove()
local yawLift, lift = isYawLift(M)
check(yawLift, "SpinBob : le modèle tourne autour de l'axe Y de son pivot et monte de 0 à BobHeight")
check(cfNear(body1.CFrame, M * rest[body1]), "SpinBob : toutes les pièces suivent le même déplacement (Body)")
check(halo1.CFrame == rest[halo1], "halo RarityHalo : jamais déplacé")
check(cfNear(point1.WorldCFrame, pointRestWorld, 1e-9), "point du billboard (BillboardPoint) : recalé à sa place de repos")
check((ring1.CFrame.Position - (M * rest[ring1]).Position).Magnitude < 1e-9, "pièce Spin_ : son centre suit le modèle")
local yaw0 = yawOf(M)
local ringRel0 = yawOf((M * rest[ring1]):Inverse() * ring1.CFrame)
local innerRel0 = yawOf((M * rest[inner1]):Inverse() * inner1.CFrame)
local groupRel0 = yawOf((M * rest[groupPart1]):Inverse() * groupPart1.CFrame)
step(1 / 30, 30)
local M1 = wholeMove()
local dt = 1 / 30
check(near(angleDiff(yawOf(M1), yaw0), TAU * ItemIdle.SpinTurnsPerSecond * dt, 1e-6), "SpinBob : une image = SpinTurnsPerSecond × 2π × dt de rotation")
local ringRel1 = yawOf((M1 * rest[ring1]):Inverse() * ring1.CFrame)
check(near(angleDiff(ringRel1, ringRel0), TAU * ItemIdle.PieceTurnsPerSecond * dt, 1e-6), "pièce Spin_ : tourne sur elle-même de PieceTurnsPerSecond × 2π × dt par image")
local innerRel1 = yawOf((M1 * rest[inner1]):Inverse() * inner1.CFrame)
local groupRel1 = yawOf((M1 * rest[groupPart1]):Inverse() * groupPart1.CFrame)
check(near(angleDiff(groupRel1, groupRel0), TAU * ItemIdle.PieceTurnsPerSecond * dt, 1e-6), "groupe Spin_ (Model) : ses pièces tournent avec lui")
check(near(angleDiff(innerRel1, innerRel0), 2 * TAU * ItemIdle.PieceTurnsPerSecond * dt, 1e-6), "pièce Spin_ dans un groupe Spin_ : sur elle-même et avec le groupe")
-- Centre du groupe : ses pièces restent à la même distance de l'axe du pivot du groupe (repère du modèle)
local groupPivotNow = M1 * CFrame.new(9.4, 1.1, 0.6)
local function axisDistance(position, around)
	local offset = around:PointToObjectSpace(position)
	return math.sqrt(offset.X * offset.X + offset.Z * offset.Z)
end
check(near(axisDistance(groupPart1.CFrame.Position, groupPivotNow), axisDistance(rest[groupPart1].Position, CFrame.new(9.4, 1.1, 0.6)), 1e-9), "groupe Spin_ : tourne autour de son pivot")

-- 2 : seule la pièce Spin_ bouge, sur place
check(root2.CFrame == rest[root2] and base2.CFrame == rest[base2], "sans Idle : les autres pièces ne sont jamais réécrites")
check((ring2.CFrame.Position - rest[ring2].Position).Magnitude < 1e-9 and math.abs(yawOf(ring2.CFrame)) > 1e-6, "sans Idle : la pièce Spin_ tourne sur place")
-- 3 : Bob, vertical seulement
local function bobOk()
	local p, r = root3.CFrame.Position, rest[root3].Position
	local dy = p.Y - r.Y
	return p.X == r.X and p.Z == r.Z and dy >= -1e-9 and dy <= ItemIdle.BobHeight + 1e-9 and cfNear(root3.CFrame.Rotation, CFrame.identity), dy
end
local lowest, highest = math.huge, -math.huge
local always = true
for _ = 1, math.ceil(ItemIdle.BobPeriod * 30) + 2 do
	step(dt, 30)
	local ok, dy = bobOk()
	always = always and ok and cfNear(body3.CFrame, root3.CFrame * rest[root3]:Inverse() * rest[body3])
	lowest = math.min(lowest, dy)
	highest = math.max(highest, dy)
end
check(always, "Bob : monte et descend à la verticale, sans tourner, toutes pièces ensemble")
check(lowest < 0.01 and highest > ItemIdle.BobHeight - 0.01, `Bob : de 0 à BobHeight sur une période ({math.floor(lowest * 1000) / 1000} à {math.floor(highest * 1000) / 1000})`)
-- 6 : loin, au repos ; s'anime quand la caméra approche ; reprend son repos quand elle s'éloigne
check(root6.CFrame == rest[root6] and body6.CFrame == rest[body6], "objet au-delà de MaxDistance : au repos, pas animé")
camera.CFrame = CFrame.new(505, 5, 5)
step(ItemIdle.DistanceCheckInterval + 0.1)
check(Idle.GetStats().Animated == 1 and not cfNear(body6.CFrame, rest[body6]), "caméra proche : l'objet s'anime (les autres, loin, s'arrêtent)")
check(root1.CFrame == rest[root1] and body1.CFrame == rest[body1] and ring1.CFrame == rest[ring1] and inner1.CFrame == rest[inner1] and cfNear(point1.WorldCFrame, pointRestWorld), "objet devenu lointain : chaque pièce reprend exactement sa position de repos")
camera.CFrame = CFrame.new(20, 5, 10)
step(ItemIdle.DistanceCheckInterval + 0.1)
check(root6.CFrame == rest[root6] and body6.CFrame == rest[body6] and Idle.GetStats().Animated == 3, "et inversement")
-- Pièce ajoutée pendant l'animation : relue à partir du repos, sans dérive
local extra = part("Extra", nil, Vector3.new(10.8, 0.6, 0))
local extraRest = extra.CFrame
extra.Parent = m1
step(dt * 2, 30)
M = wholeMove()
check(cfNear(extra.CFrame, M * extraRest) and cfNear(body1.CFrame, M * rest[body1]), "pièce ajoutée en cours d'animation : prise dans le mouvement, repos d'origine gardé")
-- Longue durée : aucune dérive
step(60)
M = wholeMove()
check(isYawLift(M) and cfNear(body1.CFrame, M * rest[body1]) and cfNear(point1.WorldCFrame, pointRestWorld) and halo1.CFrame == rest[halo1], "après 60 s : aucune dérive (pièces replacées depuis leur repos)")
-- Objet retiré (streaming, présentoir vidé)
m1:Destroy()
step(0.1)
check(Idle.GetStats().Tracked == 3, "objet détruit : plus suivi")

---------------------------------------------------------------- fin
-- Une erreur dans une tâche (contrôleur, service) compte comme un échec (bouchons, resume).
summary()
