---------------------------------------------------------------- a22 : repli d'une case vide
-- Suite de la mise en place de tests.luau (magasins, joueurs, aides), avec le catalogue modifié
-- par fallback.patch.luau.
local function warnCount(pattern)
	local n = 0
	for _, line in FULL_LOG do
		if line.kind == "WARN" and string.find(line.text, pattern, 1, true) then
			n += 1
		end
	end
	return n
end

clearLog()
Heist.Init()
GrabRemote = ReplicatedStorage.Remotes.GrabItem
taskLib.spawn(Heist.Start)

local coherent, zone1Full = true, true
local seenZone3 = {} -- [Rarity] = nombre de colis
local short = 0 -- remplissages où la zone 3 a moins de 10 colis
local function recordFallback()
	for _, store in { superette, kiosque, electro } do
		local boxes = boxesOf(store):GetChildren()
		for _, box in boxes do
			local label = C.labels[box]
			local item = Items.ById[label.ItemId]
			if item == nil or item.Rarity ~= label.Rarity or (item.Zone ~= nil and item.Zone ~= store:GetAttribute("Zone")) then
				coherent = false
			end
			if store == electro then
				seenZone3[label.Rarity] = (seenZone3[label.Rarity] or 0) + 1
			end
		end
		if store == electro and #boxes < 10 then
			short += 1
		elseif store ~= electro and #boxes ~= 10 then
			zone1Full = false
		end
	end
end
recordFallback()
for _ = 1, 40 do
	Heist.RefillAll()
	recordFallback()
end

if FALLBACK == "Rare" then
	print("== a22 : repli, zone 3 sans Rare tirable (catalogue modifié)")
	check(#Items.ByZone[3].Rare == 0 and #Items.ByZone[3].Uncommon == 3, "banc : catalogue sans Rare en zone 3")
	check(seenZone3.Rare == nil, "aucun colis Rare en zone 3")
	check(short == 0, "rayons de la zone 3 toujours pleins : la case vide se replie")
	check(coherent, "contenu cohérent : la rareté du colis est celle de son objet")
	check(warnCount("aucun objet Rare tirable en zone 3") == 1, "un seul avertissement pour cette case")
	check(logHas("ces colis reçoivent un objet Uncommon à la place", "WARN"), "repli : la rareté tirable la plus proche en dessous (Uncommon)")
	check(warnCount("aucun objet ne peut sortir") == 0, "aucun rayon laissé vide")
else
	print("== a22 : repli impossible, zone 3 sans Commun ni Peu commun (catalogue modifié)")
	check(#Items.ByZone[3].Common == 0 and #Items.ByZone[3].Uncommon == 0, "banc : catalogue sans Commun ni Peu commun en zone 3")
	check(seenZone3.Common == nil and seenZone3.Uncommon == nil and (seenZone3.Rare or 0) > 0, "zone 3 : seulement des Rares et plus")
	check(short > 0, "zone 3 : emplacements laissés vides quand rien n'est tirable en dessous")
	check(logHas("aucun objet ne peut sortir d'un colis Standard en zone 3", "WARN"), "avertissement : colis Standard sans objet en zone 3, rayon laissé vide")
	check(warnCount("aucun objet ne peut sortir d'un colis Standard en zone 3") == 1, "un seul avertissement par type de colis et par zone")
	check(coherent, "contenu cohérent : la rareté du colis est celle de son objet")
end
check(zone1Full, "zone 1 inchangée : rayons pleins")
summary()
