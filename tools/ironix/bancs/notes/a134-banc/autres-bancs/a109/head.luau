--!nocheck
-- Outils du banc a109 (vague 32), lus après head.luau de la copie a109 du banc a103.

-- Bandes de [0, 1) de chaque rareté de l'objet pour une caisse `boxRarity`, une chance `luck` et un mode
-- (« AboveBox » ou « AboveLowest »), recalculées ici d'après la règle de Cantin, sans le code du service :
-- { { Id, From, To } } dans l'ordre de Rarities.List (raretés de poids > 0 seulement).
function bands(boxRarity, luck, mode)
	local odds = SO.BoxRarityOdds[boxRarity]
	local lowest = nil
	for _, r in Rarities.List do
		if lowest == nil and (odds[r.Id] or 0) > 0 then
			lowest = r.Order
		end
	end
	local threshold = if mode == "AboveBox" then Rarities.ById[boxRarity].Order else lowest
	local weights, total = {}, 0
	for _, r in Rarities.List do
		local w = odds[r.Id] or 0
		if w > 0 then
			if r.Order > threshold then
				w *= luck
			end
			weights[r.Id] = w
			total += w
		end
	end
	local list, acc = {}, 0
	for _, r in Rarities.List do
		local w = weights[r.Id]
		if w then
			table.insert(list, { Id = r.Id, From = acc / total, To = (acc + w) / total })
			acc += w
		end
	end
	return list
end
function bandOf(list, id)
	for _, b in list do
		if b.Id == id then
			return b
		end
	end
	return nil
end
function midOf(list, id)
	local b = bandOf(list, id)
	return if b then (b.From + b.To) / 2 else nil
end
-- Rareté attendue pour le tirage `v` (valeur de NextNumber).
function expectedAt(list, v)
	for _, b in list do
		if v < b.To then
			return b.Id
		end
	end
	return list[#list].Id
end
-- Zone dont vient un objet de la rareté `id` pour un magasin de la zone `zone` (règle de repli) ; nil =
-- toutes zones (Secret, Divine).
function zoneFor(zone, id)
	if Items.AllZones[id] then
		return nil
	end
	local Zones = sharedModule("Config/Zones")
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
-- Remplissage forcé : chaque magasin tire ses colis dans l'ordre Luxe, Premium, Standard ; `pattern` (un
-- tirage par colis, 10 par magasin) est répété pour chaque magasin, quel que soit l'ordre des magasins.
function refillWith(pattern, perStore)
	table.clear(HEIST_FORCED)
	for _ = 1, 8 do
		for _, v in pattern do
			table.insert(HEIST_FORCED, v)
		end
	end
	Heist.RefillAll()
	flush()
	table.clear(HEIST_FORCED)
end
-- Rayon (numéro) d'une caisse fermée de rareté `rarity` dans `store`, ou nil.
function slotOfRarity(store, rarity, skip)
	for n = 1, 10 do
		local b = boxAt(store, n)
		if b and b:GetAttribute("BoxRarity") == rarity and not isOpening(b) and not (skip and skip[n]) then
			return n
		end
	end
	return nil
end
-- Ouvre la caisse du rayon `n` (magasin rouvert au besoin, comme le scénario upgrade d'a103) avec la chance
-- `luck` et les tirages forcés `rolls` à la sortie. Renvoie l'objet sorti, la rareté de la caisse et le
-- nombre de tirages forcés non lus.
OPENED_AT = {}
function openSlot(p, store, n, luck, rolls)
	if store:GetAttribute("HeistOpen") ~= true or OPENED_AT[store] == nil or now() - OPENED_AT[store] > 10 - SOS.revealDelay(luck) - 1.5 then
		advance(11)
		reopen(p, store)
		OPENED_AT[store] = now()
	end
	reopen(p, store)
	local box = boxAt(store, n)
	local boxRarity = box:GetAttribute("BoxRarity")
	local item, _, _, left = openAndReveal(p, store, n, luck, rolls)
	return item, boxRarity, left
end
function describe(item)
	return if item then tostring(item:GetAttribute("Rarity")) .. " " .. tostring(item:GetAttribute("ItemId")) else "aucun objet"
end
-- Contrôles d'un objet sorti : rareté `wanted`, objet de cette rareté (pas du tuto), de la bonne zone,
-- Income de l'objet (mutation comprise).
function checkItem(label, item, store, wanted)
	local zone = store:GetAttribute("Zone")
	local def = item and Items.ById[item:GetAttribute("ItemId")]
	check(item ~= nil and item:GetAttribute("Rarity") == wanted, `{label} : objet {wanted} (obtenu : {describe(item)})`)
	check(def ~= nil and def.Rarity == wanted and not def.TutorialOnly, `{label} : objet de cette rareté, pas un objet du tuto`)
	check(def ~= nil and def.Zone == zoneFor(zone, wanted), `{label} : objet de la zone {tostring(zoneFor(zone, wanted))} (magasin de zone {zone})`)
	if def then
		local income = Formulas.ItemIncome(def.Zone or zone, def.Rarity)
			* Mutations.IncomeMultiplier({ Size = item:GetAttribute("MutationSize"), Effect = item:GetAttribute("MutationEffect") })
		check(near(item:GetAttribute("Income"), income, 1e-6), `{label} : Income de l'objet`)
	end
end
-- Étiquette BB_Box d'un modèle : texte de Rarity, Category visible ?, Mutation visible ? (et son texte).
function labelOf(model)
	local gui = model:FindFirstChild("BB_Box", true)
	if gui == nil then
		return nil
	end
	local category = gui:FindFirstChild("Category", true)
	local mutation = gui:FindFirstChild("Mutation", true)
	return {
		Rarity = gui:FindFirstChild("Rarity", true).Text,
		Category = category.Visible and category.Text ~= "",
		CategoryText = category.Text,
		Mutation = mutation.Visible and mutation.Text ~= "",
		MutationText = mutation.Text,
	}
end
