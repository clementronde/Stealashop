--!nocheck
-- Scénario « crate » (a285) : boutique Robux et caisse exclusive allumées (Features.RobuxShop et RobuxCrate à true,
-- lots 8301 à 8303, pre.luau). C1 contenu (Items.Exclusives hors du catalogue des colis) ; C2 Config/ProductIds ;
-- C3 reçus x1, x3, x10 (objets Exclusive_* dans l'inventaire, un message par objet, PurchaseId noté, reçu rejoué
-- sans rien de plus) ; C4 inventaire plein : donné quand même (IgnoreInventoryMax) ; C5 tirages selon Crate.Odds.

startServer()
local Crate = Monetization.Crate
local ProductIds = sharedModule("Config/ProductIds")
local Balance = sharedModule("Config/Balance")

section("C1 contenu de la caisse")
local exclusives = Items.Exclusives
check(type(exclusives) == "table" and #exclusives == 6, `6 objets exclusifs ({type(exclusives) == "table" and #exclusives or "?"})`)
local inList = 0
for _, item in Items.List do
	if string.find(item.Id, "^Exclusive_") then
		inList += 1
	end
end
check(inList == 0, "aucun objet exclusif dans Items.List (ni colis, ni index, ni tirage)")
local rarities = { "Rare", "Epic", "Legendary", "Mythic", "Secret", "Divine" }
for index, id in Crate.Items do
	local def = Items.ById[id]
	check(def ~= nil and exclusives[index] == def and def.Rarity == rarities[index] and def.Zone == nil and def.Asset == `ITM_{id}` and (def.DrawWeight or 0) == 0,
		`case {index} : {id} dans Items.ById, rareté {rarities[index]}, sans zone, modèle ITM_{id}, jamais tiré`)
	check(Rarities.ById[def and def.Rarity or ""] ~= nil, `case {index} : rareté connue de Config/Rarities`)
end
check(#Crate.Odds == #Crate.Items and Crate.Ready == true and Crate.IgnoreInventoryMax == true, "6 chances pour 6 objets, don codé (Ready), inventaire plein ignoré")
check(Features.RobuxCrate == true, "banc : Features.RobuxCrate allumé")

section("C2 Ids DEV et PROD (Config/ProductIds)")
check(ProductIds.Environment == "Auto" and ProductIds.IsDev == false, "Environment = Auto ; faux Roblox sans GameId : Ids de PROD")
check(ProductIds.Pick("Crate1", 8301) == 8301 and ProductIds.Pick("DoubleCash", 9001) == 9001, "hors DEV, Pick rend l'Id de PROD")
local devGame = Balance.Profiles.DevGameId
check(ProductIds.IsDevFor("Auto", devGame) == true, `Auto sur le jeu DEV ({devGame}) : Ids de DEV`)
check(ProductIds.IsDevFor("Auto", 10774998269) == false and ProductIds.IsDevFor("Auto", nil) == false and ProductIds.IsDevFor("Auto", 0) == false, "Auto sur PROD, sans GameId ou GameId 0 : Ids de PROD")
check(ProductIds.IsDevFor("Dev", nil) == true and ProductIds.IsDevFor("Prod", devGame) == false, "Dev et Prod forcés")
local missing, nonZero = {}, {}
local function want(key)
	local id = ProductIds.Dev[key]
	if id == nil then
		table.insert(missing, key)
	elseif id ~= 0 then
		table.insert(nonZero, key)
	end
end
for _, pass in Monetization.Passes do
	want(pass.Key)
end
for _, product in Monetization.Products do
	if product.Tiers then
		for index in product.Tiers do
			want(`{product.Key}{index}`)
		end
	else
		want(product.Key)
	end
end
for _, pack in Crate.Packs do
	want(`Crate{pack.Count}`)
end
local Boosts = sharedModule("Config/Boosts")
for _, boost in Boosts.List do
	want(boost.Key)
end
check(#missing == 0, `une clé de DEV par offre (manque : {table.concat(missing, ", ")})`)
check(#nonZero == 0, `toutes les clés de DEV à 0 (autres : {table.concat(nonZero, ", ")})`)
check(Monetization.PassByKey.DoubleCash.Id == 9001 and Crate.Packs[1].Id == 8301, "Ids de PROD inchangés après Pick (9001, 8301)")
check(logHas("6 gamepass(es) et 14 produit(s) en vente", "PRINT", "server"), "les 3 lots de la caisse en vente (11 + 3)")

local ada = join("Ada", newProfile())
local bob = join("Bob", newProfile())
advance(1.5)

local function exclusivesOf(player)
	local list = {}
	for uid, entry in dataOf(player).Items do
		if type(entry.Id) == "string" and string.find(entry.Id, "^Exclusive_") then
			list[uid] = entry
		end
	end
	return list
end
local function count(map)
	local n = 0
	for _ in map do
		n += 1
	end
	return n
end
local function crateNotes(player)
	return notifies(player, "Exclusive Crate: you got a")
end

section("C3 reçus x1, x3, x10")
local r1 = receipt(ada, CRATE_IDS[1], "CR-1")
check(settle(r1) == GRANTED, "x1 : PurchaseGranted après la sauvegarde")
check(type(dataOf(ada).Purchases["CR-1"]) == "number", "x1 : PurchaseId noté")
local got = exclusivesOf(ada)
check(count(got) == 1, `x1 : 1 objet exclusif dans l'inventaire ({count(got)})`)
for _, entry in got do
	check(table.find(Crate.Items, entry.Id) ~= nil and entry.Source == "NPC" and type(entry.At) == "number", `objet {entry.Id} : de la caisse, Source NPC, At`)
end
local notes = crateNotes(ada)
check(#notes == 1, `x1 : un message ({#notes})`)
if notes[1] then
	local entry = next(got) and got[next(got)]
	local def = Items.ById[entry.Id]
	local expected = `Exclusive Crate: you got a {Rarities.ById[def.Rarity].DisplayNameUpper} {def.DisplayName}!`
	check(notes[1].args[1] == expected, `texte : « {notes[1].args[1]} » (attendu « {expected} »)`)
end
check(#crateNotes(bob) == 0, "Bob n'a rien reçu")
check(settle(receipt(ada, CRATE_IDS[1], "CR-1")) == GRANTED, "x1 rejoué : PurchaseGranted")
check(count(exclusivesOf(ada)) == 1 and #crateNotes(ada) == 1, "x1 rejoué : aucun objet ni message de plus")
check(settle(receipt(ada, CRATE_IDS[3], "CR-3")) == GRANTED and count(exclusivesOf(ada)) == 4 and #crateNotes(ada) == 4, "x3 : 3 objets et 3 messages de plus")
check(settle(receipt(bob, CRATE_IDS[10], "CR-10")) == GRANTED and count(exclusivesOf(bob)) == 10 and #crateNotes(bob) == 10, "x10 : 10 objets et 10 messages pour Bob")
local uids = {}
local unique = true
for uid in exclusivesOf(bob) do
	if uids[uid] then
		unique = false
	end
	uids[uid] = true
end
check(unique, "chaque objet a son propre uid")

section("C4 inventaire plein : la caisse donne quand même")
local cyd = join("Cyd", newProfile())
advance(1)
local max = Balance.Display.InventoryMax
for index = 1, max do
	addItem(dataOf(cyd), `full-{index}`, Items.List[1].Id, nil, 1)
end
check(not DisplayService.HasInventoryRoom(cyd), `inventaire plein ({max} objets)`)
check(settle(receipt(cyd, CRATE_IDS[3], "CR-FULL")) == GRANTED and count(exclusivesOf(cyd)) == 3, "x3 : PurchaseGranted, 3 objets au-delà de la place")

section("C5 tirages selon Crate.Odds")
local seen = {}
for index = 1, 40 do
	settle(receipt(bob, CRATE_IDS[10], `CR-STAT-{index}`))
end
local total = 0
for _, entry in exclusivesOf(bob) do
	seen[entry.Id] = (seen[entry.Id] or 0) + 1
	total += 1
end
check(total == 410, `410 tirages pour Bob ({total})`)
local disco, planet = seen[Crate.Items[1]] or 0, seen[Crate.Items[6]] or 0
check(disco / total > 0.35 and disco / total < 0.55, `{Crate.Items[1]} (45 %) : {math.floor(disco / total * 1000) / 10} %`)
check(planet / total < 0.04, `{Crate.Items[6]} (1 %) : {math.floor(planet / total * 1000) / 10} %`)
local order = true
for index = 2, 5 do
	if (seen[Crate.Items[index]] or 0) > (seen[Crate.Items[index - 1]] or 0) * 1.3 + 5 then
		order = false
	end
end
check(order, "du plus commun au plus rare, dans l'ordre des chances")
check(not logHas("inventaire pas rafraîchi", "WARN", "server"), "sans InventoryService (banc) : aucune alerte")

summary("scénario crate")
