--!nocheck
-- U. Crans de rareté à la sortie (décisions de Cantin du 2026-11-12 au soir, valeurs de Config/ShelfOpen) :
-- chance du cran n = min(UpgradeChance × chance, UpgradeChanceCap) × UpgradeDecay^(n − 1), sans limite de
-- nombre jusqu'à UpgradeTop, arrêt au premier échec ; rareté sans objet dans la zone du magasin : objet de
-- la zone la plus proche (le cran compte) ; mutation gardée ; jamais TutorialOnly ; contenu du tuto
-- (SetContentOverride) appliqué à l'objet sorti et jamais monté ; annonce à partir d'AnnounceMinRarity.

STORE_C = buildStore("STORE_Z2_Bazar", 2, 140, 1)
startAll()
local Tutorial = sharedModule("Config/Tutorial")
local Unbox = sharedModule("Config/Unbox")
local Zones = sharedModule("Config/Zones")
local A = player("Alice", Vector3.new(60, 3, 10)) -- zone 1 (STORE_A)
local B = player("Bob", Vector3.new(135, 3, 10)) -- zone 2 (STORE_C)
local C = player("Chloe", Vector3.new(20, 3, 10)) -- témoin des annonces, à l'écart
flush()

local lucks = luckValues()
local LMIN, LMAX = lucks[1], lucks[#lucks]
local TOP = Rarities.ById[SO.UpgradeTop]
local function chanceOf(luck, n)
	return math.clamp(math.min(SO.UpgradeChance * luck, SO.UpgradeChanceCap) * SO.UpgradeDecay ^ (n - 1), 0, 1)
end
local function rarityAbove(id, steps)
	return Rarities.List[math.min(Rarities.ById[id].Order + steps, TOP.Order)].Id
end
-- Zone dont vient un objet de la rareté `id` pour un magasin de la zone `zone` (la règle de repli).
local function zoneFor(zone, id)
	if Items.AllZones[id] then
		return nil -- Secret : toutes zones
	end
	local function has(z)
		local byZone = Items.ByZone[z]
		return byZone ~= nil and byZone[id] ~= nil and #byZone[id] > 0
	end
	if has(zone) then
		return zone
	end
	for d = 1, #Zones do
		for _, z in { zone + d, zone - d } do
			if has(z) then
				return z
			end
		end
	end
	return nil
end
local slots = { [STORE_A] = 0, [STORE_C] = 0 }
-- Prochain colis fermé du magasin (rempli à neuf quand il n'en reste plus).
local function nextSlot(store, p)
	for n = 1, 10 do
		local box = boxAt(store, n)
		if box and not isOpening(box) then
			return n
		end
	end
	advance(20)
	Heist.RefillAll()
	flush()
	return 1
end
-- Une ouverture complète par le casseur du magasin : chance `luck`, crans forcés `rolls`.
local function run(p, store, luck, rolls)
	if store:GetAttribute("HeistOpen") ~= true or STORE_OPENED_AT == nil or now() - STORE_OPENED_AT[store] > 10 - SOS.revealDelay(luck) - 1.5 then
		advance(11) -- fin du chrono en cours
		reopen(p, store)
		STORE_OPENED_AT = STORE_OPENED_AT or {}
		STORE_OPENED_AT[store] = now()
	end
	local n = nextSlot(store, p)
	reopen(p, store)
	local item, startRarity, mutationText, left = openAndReveal(p, store, n, luck, rolls)
	return item, startRarity, mutationText, left
end
local function describe(item)
	return if item then tostring(item:GetAttribute("Rarity")) .. " " .. tostring(item:GetAttribute("ItemId")) else "aucun objet"
end
-- Contrôles communs d'un objet sorti après `steps` crans réussis depuis `startRarity`.
local function checkUpgraded(label, item, store, startRarity, mutationText, steps)
	local zone = store:GetAttribute("Zone")
	local wanted = rarityAbove(startRarity, steps)
	local def = item and Items.ById[item:GetAttribute("ItemId")]
	check(item ~= nil and item:GetAttribute("Rarity") == wanted, `{label} {steps} cran(s) depuis {startRarity} : {wanted} (obtenu : {describe(item)})`)
	check(def ~= nil and def.Rarity == wanted and not def.TutorialOnly, `{label} objet de cette rareté, pas un objet du tuto`)
	check(def ~= nil and def.Zone == zoneFor(zone, wanted), `{label} objet de la zone {tostring(zoneFor(zone, wanted))} (magasin de zone {zone})`)
	check(item ~= nil and itemMutationText(item) == mutationText, `{label} mutation gardée ({tostring(mutationText)})`)
	if def then
		local income = Formulas.ItemIncome(def.Zone or zone, def.Rarity)
			* Mutations.IncomeMultiplier({ Size = item:GetAttribute("MutationSize"), Effect = item:GetAttribute("MutationEffect") })
		check(near(item:GetAttribute("Income"), income, 1e-6), `{label} Income de l'objet final`)
	end
end

section("U1 chance d'un cran = UpgradeChance × chance")
local L = lucks[#lucks - 2] -- une chance moyenne, sous le plafond
local c1, c2 = chanceOf(L, 1), chanceOf(L, 2)
check(c1 > 0 and c1 < SO.UpgradeChanceCap and near(c1, SO.UpgradeChance * L, 1e-9), `U1 (banc) chance ×{L} sous le plafond : {c1}`)
local item, startRarity, mutationText, left = run(B, STORE_C, L, { c1 - 0.001, 1 })
checkUpgraded("U1a tirage juste sous la chance :", item, STORE_C, startRarity, mutationText, 1)
check(left == 0, "U1b deux tirages lus : le cran réussi, puis le suivant raté")
item, startRarity, mutationText, left = run(B, STORE_C, L, { c1 + 0.001, 0 })
checkUpgraded("U1c tirage juste au-dessus :", item, STORE_C, startRarity, mutationText, 0)
check(left == 1, "U1d arrêt au premier échec : le tirage suivant n'est pas lu")
local cMin = chanceOf(LMIN, 1)
item, startRarity, mutationText = run(B, STORE_C, LMIN, { cMin + 0.001 })
checkUpgraded(`U1e à ×{LMIN}, tirage {cMin + 0.001} :`, item, STORE_C, startRarity, mutationText, 0)
item, startRarity, mutationText = run(B, STORE_C, LMIN, { cMin - 0.001, 1 })
checkUpgraded(`U1f à ×{LMIN}, tirage {cMin - 0.001} :`, item, STORE_C, startRarity, mutationText, 1)

section("U2 décroissance (UpgradeDecay) au cran suivant")
if SO.UpgradeDecay < 1 then
	item, startRarity, mutationText = run(B, STORE_C, L, { 0, c2 + 0.001, 0 })
	checkUpgraded("U2a 2e tirage juste au-dessus de chance × Decay :", item, STORE_C, startRarity, mutationText, 1)
end
item, startRarity, mutationText = run(B, STORE_C, L, { 0, c2 - 0.001, 1 })
checkUpgraded("U2b 2e tirage juste en dessous :", item, STORE_C, startRarity, mutationText, 2)

section("U3 plafond (UpgradeChanceCap)")
local cap = chanceOf(LMAX, 1)
if SO.UpgradeChance * LMAX > SO.UpgradeChanceCap then
	check(near(cap, SO.UpgradeChanceCap, 1e-9), `U3 (banc) chance ×{LMAX} plafonnée à {SO.UpgradeChanceCap}`)
end
if cap < 1 then
	item, startRarity, mutationText = run(B, STORE_C, LMAX, { cap + 0.001 })
	checkUpgraded(`U3a à ×{LMAX}, tirage {cap + 0.001} :`, item, STORE_C, startRarity, mutationText, 0)
end
item, startRarity, mutationText = run(B, STORE_C, LMAX, { cap - 0.001, 1 })
checkUpgraded(`U3b à ×{LMAX}, tirage {cap - 0.001} :`, item, STORE_C, startRarity, mutationText, 1)

section("U4 sans limite de crans, jusqu'à UpgradeTop ; annonce")
local since = now()
item, startRarity, mutationText, left = run(B, STORE_C, LMAX, { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 })
local climbed = TOP.Order - Rarities.ById[startRarity].Order
check(climbed > 2, `U4 (banc) {climbed} crans possibles depuis {startRarity}`)
checkUpgraded("U4a tous les crans réussis :", item, STORE_C, startRarity, mutationText, climbed)
check(item:GetAttribute("Rarity") == SO.UpgradeTop, `U4b arrêt à UpgradeTop ({SO.UpgradeTop})`)
check(left == 10 - climbed, `U4c {climbed} tirages lus, pas un de plus`)
local topDef = Items.ById[item:GetAttribute("ItemId")]
local toChloe = notifiesSince("unboxed", since, C)
check(#toChloe == 1 and toChloe[1].args[2] == Unbox.AnnounceKind, "U4d annonce aux autres joueurs (Unbox.AnnounceKind)")
check(#toChloe == 1 and string.find(toChloe[1].args[1], "Bob unboxed", 1, true) ~= nil
	and string.find(toChloe[1].args[1], TOP.DisplayNameUpper .. " " .. topDef.DisplayName, 1, true) ~= nil,
	"U4e texte : « " .. tostring(toChloe[1] and toChloe[1].args[1]) .. " »")
check(#notifiesSince("unboxed", since, A) == 1 and #notifiesSince("unboxed", since, B) == 0, "U4f pas à l'ouvreur")
since = now()
item, startRarity = run(B, STORE_C, LMIN, { 1 })
local minOrder = Rarities.ById[SO.AnnounceMinRarity].Order
if Rarities.ById[item:GetAttribute("Rarity")].Order < minOrder then
	check(#notifiesSince("unboxed", since) == 0, `U4g sous {SO.AnnounceMinRarity} : aucune annonce`)
end

section("U5 zone 1 : rareté sans objet dans la zone, objet de la zone la plus proche")
item, startRarity, mutationText = run(A, STORE_A, L, { 0, 1 })
check(startRarity == "Common", "U5 (banc) la zone 1 ne met que des Communs en rayon")
check(zoneFor(1, rarityAbove("Common", 1)) ~= 1, "U5 (banc) la zone 1 n'a aucun objet de la rareté suivante")
checkUpgraded("U5a un cran en zone 1 :", item, STORE_A, startRarity, mutationText, 1)
item, startRarity, mutationText = run(A, STORE_A, L, { 0, 0, 1 })
checkUpgraded("U5b deux crans en zone 1 :", item, STORE_A, startRarity, mutationText, 2)
check(item:GetAttribute("ItemId") ~= Tutorial.GuaranteedItemId, "U5c jamais l'objet garanti du tuto")
item, startRarity, mutationText = run(A, STORE_A, LMAX, { 0, 0, 0, 0, 0, 0, 0, 0 })
checkUpgraded("U5d tous les crans en zone 1 :", item, STORE_A, startRarity, mutationText, TOP.Order - 1)
check(item:GetAttribute("Rarity") == "Secret" or SO.UpgradeTop ~= "Secret", "U5e un Secret sort d'un Commun de zone 1")
-- L'objet d'une autre zone se porte (payload : Zone = celle du magasin).
advance(0.1)
local n5 = tonumber(string.match(item:GetAttribute("Slot"), "%d+"))
item = nil
for n = 1, 10 do
	local it = itemAt(STORE_A, n)
	local d = it and Items.ById[it:GetAttribute("ItemId")]
	if d and d.Zone ~= nil and d.Zone ~= 1 and it:GetAttribute("ShelfReservedBy") == A.UserId then
		item, n5 = it, n
	end
end
check(item ~= nil, "U5 (banc) un objet d'une autre zone est encore sur un rayon de zone 1")
advance(11)
reopen(A, STORE_A)
check(takeItem(A, STORE_A, n5), "U5f l'objet d'une autre zone se prend et se porte")
local payload5 = Carry.GetPayload(A)
check(payload5 ~= nil and payload5.Kind == "NPCItem" and payload5.Zone == 1 and Items.ById[payload5.ItemId].Zone ~= 1, "U5g payload : Zone du magasin, objet d'une zone voisine")
Carry.Consume(A)
flush()

section("U6 contenu du tuto (SetContentOverride)")
local calls = {}
Heist.SetContentOverride(function(p, drawn)
	table.insert(calls, { player = p, drawn = drawn, t = now() })
	if p == A and drawn.Zone == Tutorial.TutorialZone then
		return { Tier = Tutorial.FirstBoxTier, ItemId = Tutorial.GuaranteedItemId }
	end
	return nil
end)
WindowS.Rebuild(STORE_A:FindFirstChild("Window"):GetAttribute("WindowId")) -- rouvre le magasin pour Alice
flush()
advance(20)
Heist.RefillAll()
flush()
reopen(A, STORE_A)
STORE_OPENED_AT[STORE_A] = now()
local box = boxAt(STORE_A, 1)
local slotId = box:GetAttribute("SlotId")
openBox(A, STORE_A, 1, LMAX)
check(isOpening(box) and #calls == 0, "U6a l'accroche n'est pas appelée au lancement")
advance(SOS.revealDelay(LMAX) - 0.05)
for _ = 1, 4 do
	table.insert(HEIST_FORCED, 0)
end
advance(0.1)
left = #HEIST_FORCED
table.clear(HEIST_FORCED)
item = itemAt(STORE_A, 1)
check(#calls == 1 and calls[1].player == A and calls[1].drawn.SlotId == slotId, "U6b appelée une fois à la sortie, pour l'ouvreur")
check(item ~= nil and item:GetAttribute("ItemId") == Tutorial.GuaranteedItemId, "U6c l'objet sorti est l'objet garanti du tuto (" .. describe(item) .. ")")
check(item ~= nil and item:GetAttribute("Rarity") == Items.ById[Tutorial.GuaranteedItemId].Rarity, "U6d à sa rareté")
check(left == 4, "U6e contenu imposé : aucun cran tenté, même à ×" .. LMAX)
check(item ~= nil and item:GetAttribute("MutationSize") == nil and item:GetAttribute("MutationEffect") == nil, "U6f jamais de mutation pour l'objet du tuto")
check(takeItem(A, STORE_A, 1), "U6g Alice le prend")
local payload6 = Carry.GetPayload(A)
check(payload6 ~= nil and payload6.ItemId == Tutorial.GuaranteedItemId and payload6.Mutation == nil, "U6h portage : l'objet du tuto")
Heist.SetContentOverride(nil)
check(logCount("tick :", "WARN", "server") == 0, "U7 aucune erreur du tick")

summary("scénario upgrade")
