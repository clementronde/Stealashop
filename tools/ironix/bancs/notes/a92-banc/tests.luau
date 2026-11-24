--!nocheck
-- Banc a92 (2026-11-12, L-106 point 1) : rareté Divine.

local function buildTree(rootName, itemsKey)
	local Shared = folder(ReplicatedStorage, rootName)
	moduleScript(Shared, "Format", "shared/Format.luau")
	local ConfigF = folder(Shared, "Config")
	for _, n in CONFIG_NAMES do
		local key = `shared/Config/{n}.luau`
		if n == "Items" and itemsKey then
			key = itemsKey
		end
		moduleScript(ConfigF, n, key)
	end
	local ContractF = folder(Shared, "Contract")
	for _, n in { "Animations", "Attributes", "Find", "Icons", "Models", "Tags", "UI" } do
		moduleScript(ContractF, n, `shared/Contract/{n}.luau`)
	end
	return ConfigF, ContractF
end

local ConfigF, ContractF = buildTree("Shared", nil)
local Rarities = requireModule(ConfigF.Rarities, "server")
local Items = requireModule(ConfigF.Items, "server")
local Formulas = requireModule(ConfigF.Formulas, "server")
local ShelfBoxes = requireModule(ConfigF.ShelfBoxes, "server")
local Index = requireModule(ConfigF.Index, "server")
local Unbox = requireModule(ConfigF.Unbox, "server")
local Models = requireModule(ContractF.Models, "server")

---------------------------------------------------------------- A. Config/Rarities
print("== A. Config/Rarities")
local ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Divine" }
local okOrder = #Rarities.List == 8
for i, id in ORDER do
	local r = Rarities.List[i]
	okOrder = okOrder and r ~= nil and r.Id == id and r.Order == i and Rarities.ById[id] == r
end
check(okOrder, "A1 8 raretés, de Common à Divine, Order 1 à 8, ById cohérent")
local divine = Rarities.ById.Divine
local secret = Rarities.ById.Secret
check(divine.DisplayName == "Divine" and divine.DisplayNameUpper == "DIVINE", "A2 noms affichés en anglais : Divine / DIVINE")
check(divine.Color == Color3.fromHex("#FFE9A8") and divine.Rainbow == false and divine.RainbowColors == nil, "A3 couleur #FFE9A8 (L-106), fixe")
check(divine.IncomeMultiplier == 5 * secret.IncomeMultiplier and divine.OpenDelay == 2 * secret.OpenDelay, "A4 V0 : ×5 000 (5 × Secret), 30 min (2 × Secret)")
check(divine.Halo == "Divine" and divine.FullReveal and divine.Confetti and divine.Announce and divine.SlowMotion, "A5 halo Divine, révélation complète, confettis, annonce, ralenti")
local sums = true
for _, tier in { "Standard", "Premium", "Luxe" } do
	local odds = Rarities.BoxOdds[tier]
	local total = 0
	for _, r in Rarities.List do
		total += odds[r.Id] or 0
	end
	sums = sums and near(total, 100, 1e-9) and odds.Divine == 0
end
check(sums, "A6 chaque type de colis fait 100 % ; Divine à 0 tant qu'aucun objet Divine n'existe")
check(ShelfBoxes.OddsFor(1, "Luxe").Divine == nil and ShelfBoxes.OddsFor(4, "Luxe").Divine == 0, "A7 ShelfBoxes.OddsFor : zone 1 Communs seulement, zone 4 Divine 0")
local monotone = true
for i = 2, #Rarities.List do
	local a, b = Rarities.List[i - 1], Rarities.List[i]
	monotone = monotone and b.IncomeMultiplier > a.IncomeMultiplier and b.OpenDelay > a.OpenDelay
end
check(monotone, "A8 revenu et attente croissent de Common à Divine")

---------------------------------------------------------------- B. Config/Items
print("== B. Config/Items")
check(type(Items.Divines) == "table" and #Items.Divines == 0, "B1 Items.Divines existe, vide (aucun objet Divine au catalogue)")
check(Items.AllZones.Secret == Items.Secrets and Items.AllZones.Divine == Items.Divines and Items.AllZones.Rare == nil, "B2 AllZones : Secret, Divine ; les autres raretés par zone")
local noneDivine, secretEverywhere = true, true
for zone = 1, 6 do
	noneDivine = noneDivine and Items.Pick(zone, "Divine", Random.new(zone)) == nil
	local s = Items.Pick(zone, "Secret", Random.new(zone))
	secretEverywhere = secretEverywhere and s ~= nil and s.Rarity == "Secret"
end
check(noneDivine, "B3 Items.Pick(zone, \"Divine\") = nil dans les 6 zones, sans erreur")
check(secretEverywhere, "B4 Items.Pick(zone, \"Secret\") rend toujours le Secret (inchangé)")
check(#Items.List == 83 and Index.Total == 83, "B5 catalogue inchangé : 83 objets, Index.Total 83")

---------------------------------------------------------------- C. Revenu, confettis, contrat
print("== C. Formules, Unbox, contrat")
check(near(Formulas.ItemIncome(3, "Divine"), 5 * Formulas.ItemIncome(3, "Secret")), "C1 ItemIncome(3, Divine) = 5 × ItemIncome(3, Secret)")
check(Unbox.ConfettiBurst.Divine ~= nil and Unbox.ConfettiBurst.Divine > Unbox.ConfettiBurst.Secret, "C2 ConfettiBurst.Divine > Secret")
local truckDivine = false
for _, name in Models.Truck.Names do
	truckDivine = truckDivine or name == "ENV_Event_Truck_Divine"
end
check(truckDivine, "C3 Contract/Models : ENV_Event_Truck_Divine contrôlé avec les autres camions")

---------------------------------------------------------------- D. Le jour où un objet Divine arrive
print("== D. Catalogue avec un objet Divine (source modifiée)")
local src = SOURCES["shared/Config/Items.luau"]
local patched, n = string.gsub(src, "local DIVINES: { Entry } = {}", 'local DIVINES: { Entry } = { { Id = "Divine_TestHalo", Name = "Test Halo", Rarity = "Divine" } }')
check(n == 1, "D0 source de Config/Items : DIVINES trouvé")
SOURCES["test/ItemsDivine"] = patched
local ConfigD = buildTree("SharedDivine", "test/ItemsDivine")
local ItemsD = requireModule(ConfigD.Items, "server")
local IndexD = requireModule(ConfigD.Index, "server")
local d = ItemsD.ById.Divine_TestHalo
check(d ~= nil and d.Zone == nil and d.Asset == "ITM_Divine_TestHalo" and d.CategoryId == "Divine", "D1 objet Divine sans zone, modèle ITM_Divine_TestHalo")
local all = true
for zone = 1, 6 do
	local p = ItemsD.Pick(zone, "Divine", Random.new(zone))
	all = all and p == d
end
check(all, "D2 Items.Pick(zone, \"Divine\") le rend dans les 6 zones")
check(IndexD.Total == 84 and #IndexD.Secrets == 2 and select(2, IndexD.CountSecrets({})) == 2, "D3 Index : 84 objets, l'objet Divine rangé avec les Secrets (SecretsSection)")
local wrong = string.gsub(src, "local DIVINES: { Entry } = {}", 'local DIVINES: { Entry } = { { Id = "Divine_Bad", Name = "Bad", Rarity = "Secret" } }')
SOURCES["test/ItemsBad"] = wrong
local ConfigB = buildTree("SharedBad", "test/ItemsBad")
local ok = pcall(requireModule, ConfigB.Items, "server")
check(not ok, "D4 un objet Secret rangé dans DIVINES est refusé au chargement")

summary()
