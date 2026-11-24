-- Scénarios du banc a203 (placés après SOURCES par run.sh).

Color3 = {
	fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end,
	fromHex = function(hex) return { Hex = hex } end,
	new = function(r, g, b) return { R = r, G = g, B = b } end,
}
Vector3 = { new = function(x, y, z) return { X = x, Y = y, Z = z } end }
NumberRange = { new = function(a, b) return { Min = a, Max = b or a } end }
NumberSequence = { new = function(v) return { V = v } end }
ColorSequence = { new = function(v) return { V = v } end }
UDim2 = { new = function(...) return { ... } end, fromScale = function(...) return { ... } end }
Enum = setmetatable({}, { __index = function(_, k) return setmetatable({}, { __index = function(_, j) return k .. "." .. j end }) end })

local RefMT = {}
local function ref(path)
	return setmetatable({ __path = path }, RefMT)
end
RefMT.__index = function(self, key)
	local path = rawget(self, "__path")
	if key == "Parent" then
		return ref((string.gsub(path, "/?[^/]*$", "")))
	end
	if key == "WaitForChild" or key == "FindFirstChild" then
		return function(this, name)
			return this[name]
		end
	end
	return ref(if path == "" then key else path .. "/" .. key)
end

local loaded, loading = {}, {}
local function charge(path)
	if loaded[path] ~= nil then
		return loaded[path]
	end
	local source = SOURCES[path]
	if source == nil then
		error(`module absent : {path}`, 2)
	end
	assert(not loading[path], `require en boucle : {path}`)
	loading[path] = true
	local chunk, problem = loadstring(source, "=" .. path)
	assert(chunk, `{path} ne compile pas : {problem}`)
	setfenv(chunk, setmetatable({
		script = ref(path),
		require = function(target)
			return charge(rawget(target, "__path"))
		end,
	}, { __index = getfenv(0) }))
	local result = chunk()
	loading[path] = nil
	loaded[path] = result
	return result
end

local checks, fails = 0, 0
local function check(ok, label)
	checks += 1
	if ok then
		if VERBOSE then print("  ok " .. label) end
	else
		fails += 1
		print("  ÉCHEC " .. label)
	end
end
local function near(a, b, eps)
	return type(a) == "number" and math.abs(a - b) <= (eps or 1e-6)
end
local function fakeRandom(seed)
	local state = (seed * 7919) % 2147483646 + 1
	return {
		NextNumber = function(_self)
			state = (state * 48271) % 2147483647
			return state / 2147483647
		end,
	}
end
local function constRandom(value)
	return { NextNumber = function() return value end }
end

local ok, problem = pcall(function()
	local Weight = charge("Config/Weight")
	local Features = charge("Config/Features")
	local ItemWeight = charge("ItemWeight")
	local Mutations = charge("Config/Mutations")

	-- 1. Valeurs
	check(Features.SingleBoxReveal == true, "Features.SingleBoxReveal = true")
	check(ItemWeight.Enabled() == true, "ItemWeight.Enabled() suit Features")
	local sum, contiguous = 0, true
	for index, tier in Weight.Tiers do
		sum += tier.Chance
		if index > 1 and Weight.Tiers[index - 1].Max ~= tier.Min then
			contiguous = false
		end
	end
	check(near(sum, 100, 1e-9), `paliers : somme des chances = 100 ({sum})`)
	check(contiguous, "paliers contigus")
	check(Weight.Tiers[1].Min == 1 and Weight.Tiers[#Weight.Tiers].Min == 10000 and Weight.Max == 10000, "de 1 à 10 000 kg")

	-- 2. Chances par palier et chance de la boîte
	local heavyShare = {}
	for _, luck in { 1, 4, 8 } do
		local chances = ItemWeight.TierChances(luck)
		local total, heavy = 0, 0
		for index, tier in Weight.Tiers do
			total += chances[index]
			if tier.Min >= Weight.LuckFrom then
				heavy += chances[index]
			end
		end
		heavyShare[luck] = heavy
		check(near(total, 100, 1e-9), `×{luck} : somme 100`)
		check(chances[#Weight.Tiers] < 100 and chances[1] > 0, `×{luck} : rien de garanti, le léger reste possible`)
	end
	check(heavyShare[1] < heavyShare[4] and heavyShare[4] < heavyShare[8], "la chance de la boîte fait monter les paliers lourds")
	check(near(ItemWeight.TierChances(1)[#Weight.Tiers], 0.001, 1e-9), "10 000 kg : 0,001 % à ×1")
	check(near(ItemWeight.TierChances(0.5)[1], ItemWeight.TierChances(1)[1]), "une chance < 1 compte comme ×1")
	local five50 = 0
	for index, tier in Weight.Tiers do
		if tier.Min >= 5 and tier.Max <= 50 then five50 += ItemWeight.TierChances(1)[index] end
	end
	check(five50 >= 60, `le gros du tirage entre 5 et 50 kg à ×1 ({five50} %)`)

	-- 3. 100 000 tirages
	for _, luck in { 1, 4, 8 } do
		local rng = fakeRandom(203 + luck)
		local counts = {}
		local inRange, onGrid = true, true
		local n = 100000
		for _ = 1, n do
			local kg = ItemWeight.Roll(rng, luck)
			if kg < 1 or kg > 10000 then inRange = false end
			if kg < 100 then
				if math.abs(kg * 10 - math.floor(kg * 10 + 0.5)) > 1e-6 then onGrid = false end
			elseif kg ~= math.floor(kg) then
				onGrid = false
			end
			for index, tier in Weight.Tiers do
				if (tier.Max > tier.Min and kg >= tier.Min and kg < tier.Max) or (tier.Max <= tier.Min and kg == tier.Min) then
					counts[index] = (counts[index] or 0) + 1
					break
				end
			end
		end
		check(inRange, `×{luck} : 100 000 tirages entre 1 et 10 000 kg`)
		check(onGrid, `×{luck} : arrondi au dixième sous 100 kg, au kilo au-delà`)
		local expected = ItemWeight.TierChances(luck)
		local worst = 0
		for index in Weight.Tiers do
			local p = expected[index] / 100
			local sigma = math.sqrt(n * p * (1 - p))
			local diff = math.abs((counts[index] or 0) - n * p)
			worst = math.max(worst, diff / math.max(sigma, 1))
		end
		check(worst < 5, `×{luck} : chaque palier à moins de 5 écarts types de sa chance ({string.format("%.2f", worst)})`)
	end
	check(ItemWeight.Roll(constRandom(0), 1) == 1, "extrême bas : 1 kg")
	check(ItemWeight.Roll(constRandom(0.9999999999), 1) == 10000, "extrême haut : 10 000 kg")
	check(ItemWeight.Roll(constRandom(0.5), -3) >= 1, "chance négative : tirage normal")

	-- 4. Taille et revenu
	check(near(ItemWeight.ScaleFor(1), 2 * 0.1 ^ (1 / 3)) and near(ItemWeight.IncomeFactor(1), 0.1 ^ (1 / 3)), "1 kg : taille ×0,93 (a418, variante A2), revenu ×0,46")
	check(near(ItemWeight.ScaleFor(10), 2) and near(ItemWeight.IncomeFactor(10), 1), "10 kg : taille ×2 (a418, variante A2), revenu ×1")
	if Weight.ScaleCurve ~= nil then -- a234 : taille par la courbe, revenu inchangé (racine cubique)
		check(near(ItemWeight.ScaleFor(500), 7) and near(ItemWeight.ScaleFor(10000), 16), "a234 : taille 500 kg = ×7, 10 000 kg = ×16")
		check(near(ItemWeight.IncomeFactor(1000), 100 ^ (1 / 3)) and near(ItemWeight.IncomeFactor(10000), 10), "a234 : revenu inchangé (1 000 kg ×4,64, 10 000 kg ×10)")
	else
		check(near(ItemWeight.ScaleFor(1000), 100 ^ (1 / 3)) and near(ItemWeight.IncomeFactor(1000), 100 ^ (1 / 3)), "1 000 kg : ×4,64")
		check(near(ItemWeight.ScaleFor(10000), 10) and near(ItemWeight.IncomeFactor(10000), 10), "10 000 kg : ×10")
	end
	check(near(ItemWeight.IncomeFactor(0), ItemWeight.IncomeFactor(1)) and near(ItemWeight.IncomeFactor(1e9), 10), "hors bornes : ramené à 1…10 000 kg")
	check(near(ItemWeight.IncomeFactor(0 / 0), 1), "poids illisible : 10 kg")

	-- 5. Seuils Huge et Colossal, classe de taille
	check(ItemWeight.SizeMutationFor(249.9) == nil, "249,9 kg : aucune mutation de taille")
	check(ItemWeight.SizeMutationFor(250) == "Huge" and ItemWeight.SizeMutationFor(2499) == "Huge", "250 à 2 499 kg : Huge")
	check(ItemWeight.SizeMutationFor(2500) == "Colossal" and ItemWeight.SizeMutationFor(10000) == "Colossal", "2 500 kg et plus : Colossal")
	check(ItemWeight.SizeClassFor(3000, 5, 2) == "Colossal", "SizeClassFor : Colossal au-dessus de ColossalFrom")
	check(ItemWeight.SizeClassFor(10, 5, 2) == "Small", "SizeClassFor : 10 kg, modèle de 2 sous 5 studs libres : Small")
	check(ItemWeight.SizeClassFor(1000, 5, 2) == "Large", "SizeClassFor : 1 000 kg (×4,64) dépasse : Large")
	check(ItemWeight.SizeClassFor(1000, 0, 2) == "Small", "SizeClassFor : hauteur libre inconnue : Small")
	local hugeAt1 = ItemWeight.SizeChance("Huge", 1)
	check(hugeAt1 > 1 and hugeAt1 < 4 and ItemWeight.SizeChance("Colossal", 1) < 1, `chances Huge ({hugeAt1} %) et Colossal à ×1 sous les anciennes (4 et 1 %)`)
	check(ItemWeight.SizeChance("Big", 1) == 0, "SizeChance d'une autre taille : 0")

	-- 6. Migration d'un ancien profil
	local effects = { "", "Shiny", "Gold", "Rainbow" }
	local sizes = { "", "Tiny", "Big", "Huge", "Colossal" }
	local noLoss, stayed = true, true
	for _, size in sizes do
		for _, effect in effects do
			local mutation = nil
			if size ~= "" or effect ~= "" then
				mutation = { Size = if size ~= "" then size else nil, Effect = if effect ~= "" then effect else nil }
			end
			ItemWeight.SetEnabledForTest(false)
			local before = Mutations.IncomeMultiplier(mutation)
			ItemWeight.SetEnabledForTest(nil)
			local items = { u1 = { ItemId = "x", Mutation = mutation } }
			ItemWeight.Migrate(items)
			local after = Mutations.IncomeMultiplier(items.u1.Mutation, items.u1.Weight)
			if after + 1e-9 < before then
				noLoss = false
				print(`    {size}/{effect} : {before} → {after}`)
			end
			if (size == "Huge" or size == "Colossal") and ItemWeight.SizeMutationFor(items.u1.Weight) ~= size then
				stayed = false
			end
		end
	end
	check(noLoss, "migration : chaque objet garde au moins son revenu d'avant (taille × effet)")
	check(stayed, "migration : Huge et Colossal restent dans leur palier")
	local items = {
		a = { ItemId = "x" },
		b = { ItemId = "x", Mutation = { Size = "Big" } },
		c = { ItemId = "x", Weight = 0 },
		d = { ItemId = "x", Weight = 0 / 0, Mutation = { Size = "Huge" } },
		e = { ItemId = "x", Weight = 37.5 },
	}
	check(ItemWeight.Migrate(items) == 4, "migration : 4 objets changés sur 5")
	check(items.a.Weight == 10 and items.b.Weight == 80 and items.c.Weight == 1 and items.d.Weight == 1250 and items.e.Weight == 37.5, "migration : 10, 80, 1 (ramené), 1 250, 37,5 kg")
	check(ItemWeight.Migrate(items) == 0, "migration idempotente")
	if string.find(SOURCES["ItemWeight"], "WEIGHT_SIZES", 1, true) then -- a231 : taille d'avant retirée, mutation vide partie
		check(items.b.Mutation == nil and items.d.Mutation.Size == "Huge", "migration : Big retirée (mutation vide partie), Huge gardée")
	else
		check(items.b.Mutation.Size == "Big", "migration : la mutation n'est pas touchée")
	end
	check(ItemWeight.Migrate(nil) == 0, "migration : pas de table, rien")

	-- 7. Config/Mutations avec et sans le poids
	check(Mutations.Sanitize({ Size = "Big" }) == nil and Mutations.Sanitize({ Size = "Tiny", Effect = "Gold" }).Size == nil, "poids en marche : Tiny et Big cachés")
	check(Mutations.Sanitize({ Size = "Huge" }).Size == "Huge", "poids en marche : Huge gardé")
	local sizeRolled = false
	local rng = fakeRandom(7)
	for _ = 1, 20000 do
		local m = Mutations.Roll(rng)
		if m and m.Size then sizeRolled = true end
	end
	check(not sizeRolled, "poids en marche : Mutations.Roll ne tire plus de taille")
	check(near(Mutations.IncomeMultiplier({ Effect = "Gold" }, 1000), 100 ^ (1 / 3) * 2), "revenu : poids × effet (1 000 kg Gold = ×9,28)")
	check(near(Mutations.IncomeMultiplier({ Size = "Colossal" }, 10000), 10), "Colossal 10 000 kg : ×10, une seule fois")
	check(near(Mutations.IncomeMultiplier(nil, nil), 1), "sans poids ni mutation : ×1")
	check(near(Mutations.IncomeMultiplier({ Size = "Huge" }), 5), "Huge sans poids : son poids d'avant (×5)")
	check(near(Mutations.Scale(nil, 10000), math.min(ItemWeight.ScaleFor(10000), Weight.DisplayMaxScale)), "présentoir : à sa taille, au plus DisplayMaxScale (10 000 kg)")
	check(near(Mutations.Scale(nil, 1), 2 * 0.1 ^ (1 / 3)), "présentoir : 1 kg = ×0,93 (a418)")
	ItemWeight.SetEnabledForTest(false)
	check(near(Mutations.Scale({ Size = "Big" }, 10000), 1.5) and near(Mutations.IncomeMultiplier({ Size = "Big" }, 10000), 2), "poids coupé : tailles d'avant, poids ignoré")
	check(Mutations.Sanitize({ Size = "Big" }).Size == "Big", "poids coupé : Big revient")
	ItemWeight.SetEnabledForTest(nil)

	-- 8. Plafonds
	check(near(ItemWeight.CappedScale(10000, Weight.HeldMaxScale), Weight.HeldMaxScale), `objet tenu plafonné à ×{Weight.HeldMaxScale}`)
	check(near(ItemWeight.CappedScale(10000, Weight.RarestMaxScale), Weight.RarestMaxScale), `socle BEST ITEM plafonné à ×{Weight.RarestMaxScale}`)
	check(near(ItemWeight.CappedScale(1, Weight.HeldMaxScale), ItemWeight.ScaleFor(1)), "plafond : un objet léger n'est pas grossi")
	if Weight.CarryFade ~= nil then -- a220 : porté à la taille de son poids, au plus CarryMaxScale
		check(Weight.CarryMaxScale >= 1 and Weight.CarryMaxScale <= Weight.DisplayMaxScale, `objet porté : au plus ×{Weight.CarryMaxScale}, pas plus qu un présentoir`)
		local carry = SOURCES["Text/CarryService"]
		check(string.find(carry, "WeightConfig.CarryMaxScale", 1, true) ~= nil and string.find(carry, "ScaleTo", 1, true) ~= nil, "CarryService : ScaleTo au plus CarryMaxScale")
	else
		check(Weight.CarryMaxScale == 1, "objet porté : taille de catalogue (×1)")
	end
	local held = SOURCES["Text/HeldItemService"]
	check(string.find(held, "WeightConfig.HeldMaxScale", 1, true) ~= nil and string.find(held, "ScaleTo", 1, true) ~= nil, "HeldItemService : ScaleTo au plus HeldMaxScale")
	local vfx = SOURCES["Text/VfxController"]
	check(string.find(vfx, "WeightConfig.RarestMaxScale", 1, true) ~= nil, "VfxController : copie du socle au plus RarestMaxScale")
	check(string.find(SOURCES["Text/DataService"], "ItemWeight.Migrate", 1, true) ~= nil, "DataService : migration au chargement")
	check(string.find(SOURCES["Text/DisplayService"], "WeightConfig.Attribute", 1, true) ~= nil, "DisplayService : attribut Weight sur l'objet exposé")
	local anim = SOURCES["Text/AnimationController"]
	local twoHands = tonumber(string.match(anim, "local TWO_HANDS_FROM = ([%d%.]+)"))
	check(twoHands == Weight.TwoHandsFrom, "AnimationController.TWO_HANDS_FROM = Weight.TwoHandsFrom")
	check(string.match(anim, "local WEIGHT_ATTRIBUTE = \"(%w+)\"") == Weight.Attribute, "AnimationController : même attribut Weight")

	-- 9. RollForSize (Fortune Tower)
	local FortuneTower = charge("Config/FortuneTower")
	check(near(FortuneTower.SizeOdds.Huge, 80) and near(FortuneTower.SizeOdds.Colossal, 20), "Fortune Tower : Huge 80 %, Colossal 20 % gardés")
	local hugeOk, colossalOk, anyOk = true, true, true
	local r = fakeRandom(99)
	for _ = 1, 10000 do
		local h = ItemWeight.RollForSize(r, 1, "Huge")
		if not (h >= 250 and h < 2500) then hugeOk = false end
		local c = ItemWeight.RollForSize(r, 8, "Colossal")
		if not (c >= 2500 and c <= 10000) then colossalOk = false end
		local a = ItemWeight.RollForSize(r, 1, nil)
		if not (a >= 1 and a <= 10000) then anyOk = false end
	end
	check(hugeOk, "RollForSize Huge : 250 à 2 499 kg")
	check(colossalOk, "RollForSize Colossal : 2 500 à 10 000 kg")
	check(anyOk, "RollForSize sans taille : tirage normal")
	check(ItemWeight.SizeMutationFor(ItemWeight.RollForSize(constRandom(0.9999999), 1, "Huge")) == "Huge", "RollForSize Huge : jamais Colossal")

	-- 10. Format
	check(ItemWeight.Format(3.4) == "3.4 kg", "Format 3.4 kg")
	check(ItemWeight.Format(12) == "12 kg", "Format 12 kg")
	check(ItemWeight.Format(1250) == "1,250 kg", "Format 1,250 kg")
	check(ItemWeight.Format(10000) == "10,000 kg", "Format 10,000 kg")
	check(ItemWeight.Format(2.25) == "2.2 kg" and ItemWeight.Format(999.9) == "999 kg", "Format : arrondi vers le bas")

	-- 11. ItemOdds : chance de Huge = palier de poids
	local ItemOdds = charge("ItemOdds")
	local Items = charge("Config/Items")
	local ShelfOpen = charge("Config/ShelfOpen")
	local box
	for name in ShelfOpen.BoxRarityOdds do box = name break end
	local itemId
	for _, item in Items.List or {} do
		if ItemOdds.Chance(item.Id, nil, box) then itemId = item.Id break end
	end
	if itemId == nil then
		for id in Items.ById do
			if ItemOdds.Chance(id, nil, box) then itemId = id break end
		end
	end
	check(itemId ~= nil, "ItemOdds : un objet tirable trouvé")
	if itemId then
		local base = ItemOdds.Chance(itemId, nil, box)
		local huge = ItemOdds.Chance(itemId, { Size = "Huge" }, box)
		check(near(huge, base * ItemWeight.SizeChance("Huge", 1) / 100, 1e-15), "ItemOdds : P(Huge) = chance du palier de poids")
	end

	-- 12. InventoryState : 9e champ, le poids
	local InventoryState = charge("InventoryState")
	local plain = InventoryState.Encode({ Items = { { Uid = "u1", ItemId = "Soda", Income = 5, Size = nil, Effect = "Gold" } } })
	check(plain == "1;I,u1,Soda,5,0,,Gold", "InventoryState : sans poids, texte d'avant")
	local text = InventoryState.Encode({ Items = {
		{ Uid = "u1", ItemId = "Soda", Income = 5, Weight = 1250 },
		{ Uid = "u2", ItemId = "Soda", Income = 5, AntiTheft = true, Weight = 3.4 },
	} })
	check(text == "1;I,u1,Soda,5,0,,,,1250;I,u2,Soda,5,0,,,A,3.4", `InventoryState : poids en 9e champ ({text})`)
	local back = InventoryState.Decode(text)
	check(#back.Items == 2 and back.Items[1].Weight == 1250 and back.Items[1].AntiTheft == nil and back.Items[2].Weight == 3.4 and back.Items[2].AntiTheft == true, "InventoryState : relu (poids, antivol)")
	check(InventoryState.Decode(plain).Items[1].Weight == nil, "InventoryState : ancien texte relu sans poids")
end)
if not ok then
	fails += 1
	print("  ERREUR " .. tostring(problem))
end
print(`banc a203 (poids des objets) : {checks} vérification(s), {fails} échec(s)`)
