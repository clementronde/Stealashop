-- Scénarios du banc a234 (placés après SOURCES par run.sh).

Color3 = {
	fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end,
	fromHex = function(hex) return { Hex = hex } end,
	new = function(r, g, b) return { R = r, G = g, B = b } end,
}
NumberRange = { new = function(a, b) return { Min = a, Max = b or a } end }
NumberSequence = { new = function(v) return { V = v } end }
ColorSequence = { new = function(v) return { V = v } end }
UDim2 = { new = function(...) return { ... } end, fromScale = function(...) return { ... } end }
Enum = setmetatable({}, { __index = function(_, k) return setmetatable({}, { __index = function(_, j) return k .. "." .. j end }) end })

-- Faux Vector3 (opérations utiles) et faux CFrame (position + rotation autour de Y).
local V3 = {}
local function v3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3)
end
V3.__index = function(self, key)
	if key == "Magnitude" then
		return math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
	end
	return nil
end
V3.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
V3.__mul = function(a, b)
	if type(a) == "number" then a, b = b, a end
	if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b) return v3(a.X / b, a.Y / b, a.Z / b) end
Vector3 = { new = v3, one = v3(1, 1, 1), zero = v3(0, 0, 0), xAxis = v3(1, 0, 0), yAxis = v3(0, 1, 0), zAxis = v3(0, 0, 1) }

local CF = {}
CF.__index = CF
local function cf(pos, yaw)
	return setmetatable({ Pos = pos, Yaw = yaw or 0 }, CF)
end
local function rot(p, a)
	local c, s = math.cos(a), math.sin(a)
	return v3(p.X * c + p.Z * s, p.Y, -p.X * s + p.Z * c)
end
CF.__mul = function(a, b)
	if getmetatable(b) == V3 then
		return rot(b, a.Yaw) + a.Pos
	end
	return cf(rot(b.Pos, a.Yaw) + a.Pos, a.Yaw + b.Yaw)
end
function CF.PointToObjectSpace(self, p)
	return rot(p - self.Pos, -self.Yaw)
end
CFrame = { new = function(x, y, z) return cf(v3(x, y, z), 0) end }

local function fakeTypeof(value)
	local mt = getmetatable(value)
	if mt == V3 then return "Vector3" end
	if mt == CF then return "CFrame" end
	return type(value)
end

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
		typeof = fakeTypeof,
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
local function has(text, needle)
	return string.find(text, needle, 1, true) ~= nil
end

-- Faux modèle pour fitFactor : pièces (BasePart) et lumières.
local function part(size, pos, transparency)
	return {
		Size = size,
		CFrame = cf(pos, 0),
		Transparency = transparency or 0,
		IsA = function(_, class) return class == "BasePart" end,
	}
end
local function model(parts, idle)
	return {
		GetAttribute = function(_, name) return if name == "Idle" then idle else nil end,
		GetDescendants = function() return parts end,
	}
end

local ok, problem = pcall(function()
	local Weight = charge("Config/Weight")
	local ItemWeight = charge("ItemWeight")
	local Mutations = charge("Config/Mutations")
	local Reveal = charge("Config/Reveal")
	local Attributes = charge("Contract/Attributes")
	ItemWeight.SetEnabledForTest(true)

	-- 1. Courbe poids → taille (V0 a234)
	local expected = { [1] = 0.1 ^ (1 / 3), [10] = 1, [50] = 5 ^ (math.log(2.6) / math.log(10)), [100] = 2.6, [500] = 7, [10000] = 16 }
	for _, kg in { 1, 10, 50, 100, 250, 500, 1000, 2500, 10000 } do
		print(string.format("  taille %6d kg : ×%.2f (revenu ×%.2f)", kg, ItemWeight.ScaleFor(kg), ItemWeight.IncomeFactor(kg)))
	end
	for kg, scale in expected do
		check(near(ItemWeight.ScaleFor(kg), scale, 1e-4), `ScaleFor({kg}) = ×{scale}`)
	end
	check(ItemWeight.ScaleFor(10) == 1 and ItemWeight.ScaleFor(500) == 7, "sur un point : valeur exacte (10 kg = ×1 tout juste, aucun ScaleTo de plus)")
	check(ItemWeight.ScaleFor(500) * 1.6 >= 10 and ItemWeight.ScaleFor(500) * 2 <= 16, "500 kg : une voiture (11 à 14 studs pour un objet de 1,6 à 2 studs)")
	local rising, previous = true, 0
	for step = 0, 400 do
		local kg = 10 ^ (step / 100)
		local s = ItemWeight.ScaleFor(kg)
		if s <= previous then rising = false end
		previous = s
	end
	check(rising, "courbe croissante de 1 à 10 000 kg")
	for _, point in Weight.ScaleCurve do
		check(near(Weight.ScaleAt(point.Kg - 1e-7), Weight.ScaleAt(point.Kg + 1e-7), 1e-4), `courbe continue à {point.Kg} kg`)
	end
	check(near(ItemWeight.ScaleFor(0), ItemWeight.ScaleFor(1)) and near(ItemWeight.ScaleFor(1e9), 16), "hors bornes : ramené à 1…10 000 kg")
	check(near(ItemWeight.ScaleFor(0 / 0), 1), "poids illisible : 10 kg, ×1")
	check(near(ItemWeight.IncomeFactor(500), 50 ^ (1 / 3)) and near(ItemWeight.IncomeFactor(10000), 10), "revenu inchangé (racine cubique)")

	-- 2. Plafonds : porté et présentoir à la taille de l'ouverture, socle limité
	check(Weight.CarryMaxScale >= ItemWeight.ScaleFor(10000) - 1e-9, "objet porté : la taille de l'ouverture, même à 10 000 kg")
	check(Weight.DisplayMaxScale >= ItemWeight.ScaleFor(10000) - 1e-9, "présentoir sans FitSize : la taille de son poids")
	check(near(Mutations.Scale(nil, 500), 7), "Mutations.Scale(500 kg) = ×7")
	check(Weight.RarestMaxScale >= 1 and Weight.RarestMaxScale < ItemWeight.ScaleFor(10000), `socle : au plus ×{Weight.RarestMaxScale}`)
	check(Weight.FitScaleAttribute == "FitScale", "attribut FitScale")

	-- 3. Ouverture : casse du rayon et du plafond (payload.Scale = ScaleFor, Reveal/Shelf, SizeClassFor)
	check(has(SOURCES["Text/StoreHeistService"], "pcall(ItemWeight.ScaleFor, kg)"), "StoreHeistService : échelle de l'ouverture = ItemWeight.ScaleFor (la courbe)")
	check(has(SOURCES["Text/RevealController"], "Shelf.Plan(scene.id, store, scene.base, size1, payload.Scale"), "RevealController : la casse du rayon suit payload.Scale")
	check(ItemWeight.ScaleFor(500) >= Reveal.Shelf.MinScale and ItemWeight.ScaleFor(10) < Reveal.Shelf.MinScale, "casse du rayon : 500 kg casse, 10 kg non")
	check(ItemWeight.SizeClassFor(500, 10, 1.6) == "Large", "500 kg (objet de 1,6 studs, plafond à 10) : Large, le plafond casse")
	check(ItemWeight.SizeClassFor(10, 10, 1.6) == "Small", "10 kg : Small")

	-- 4. FitSize (DisplayService : fitSizeOf, fitFactor, lightRanges, trimLights)
	check(Attributes.FitSize ~= nil and Attributes.FitSize.Name == "FitSize", "Contract/Attributes.FitSize")
	local text = SOURCES["Text/DisplayService"]
	local from = string.find(text, "-- a234 (L-216 point 2, L-217) : boîte FitSize", 1, true)
	local to = string.find(text, "-- Billboard visible par tous", 1, true)
	check(from ~= nil and to ~= nil and from < to, "DisplayService : bloc FitSize trouvé")
	local chunk, err = loadstring(
		string.sub(text, from, to - 1) .. "\nreturn { fitSizeOf = fitSizeOf, fitFactor = fitFactor, lightRanges = lightRanges, trimLights = trimLights }",
		"=FitSize"
	)
	assert(chunk, `bloc FitSize : {err}`)
	setfenv(chunk, setmetatable({ Attributes = Attributes, typeof = fakeTypeof }, { __index = getfenv(0) }))
	local F = chunk()
	local slotFit = v3(6.5, 13.5, 6) -- L-217
	local function slot(value)
		return { GetAttribute = function(_, name) return if name == "FitSize" then value else nil end }
	end
	check(F.fitSizeOf(slot(nil)) == nil, "fitSizeOf : absent → nil (taille de son poids)")
	check(F.fitSizeOf(slot(v3(0, 13.5, 6))) == nil and F.fitSizeOf(slot(v3(0 / 0, 1, 1))) == nil, "fitSizeOf : côté nul ou NaN → nil")
	check(F.fitSizeOf(slot(5)) == nil, "fitSizeOf : pas un Vector3 → nil")
	check(F.fitSizeOf(slot(slotFit)) == slotFit, "fitSizeOf : Vector3 lisible")
	local pivot = cf(v3(100, 5, -40), math.rad(90))
	-- objet de 2 × 2 × 2 à ×7 (500 kg) : 14 de côté, pivot en bas au centre
	local big = model({ part(v3(14, 14, 14), pivot.Pos + v3(0, 7, 0)) })
	check(near(F.fitFactor(big, pivot, slotFit), 3 / 7, 1e-6), "500 kg (14 studs) réduit pour tenir : ×3/7 (Z : 6 de profondeur)")
	local small = model({ part(v3(1, 1.6, 1), pivot.Pos + v3(0, 0.8, 0)) })
	check(F.fitFactor(small, pivot, slotFit) == 1, "objet qui tient : jamais grossi (×1)")
	local tall = model({ part(v3(2, 27, 2), pivot.Pos + v3(0, 13.5, 0)) })
	check(near(F.fitFactor(tall, pivot, slotFit), 0.5), "trop haut : 27 → 13,5 (×0,5)")
	-- pivot tourné de 90° : une pièce longue de 6,4 sur Z monde est le long de X dans le repère de l'Attachment
	local long = model({ part(v3(2, 2, 6.4), pivot.Pos + v3(0, 1, 0)) })
	check(near(F.fitFactor(long, pivot, slotFit), 1), "repère de l'Attachment : 6,4 le long de X tient dans 6,5")
	local spinner = model({ part(v3(2, 2, 6.4), pivot.Pos + v3(0, 1, 0)) }, "Spin")
	local radius = math.sqrt(3.2 ^ 2 + 1)
	check(near(F.fitFactor(spinner, pivot, slotFit), 3 / radius), "Idle Spin : son rayon tient dans le plus petit côté")
	local hitbox = model({ part(v3(1, 1.6, 1), pivot.Pos + v3(0, 0.8, 0)), part(v3(40, 40, 40), pivot.Pos, 1) })
	check(F.fitFactor(hitbox, pivot, slotFit) == 1, "pièce invisible ignorée")
	check(F.fitFactor(model({}), pivot, slotFit) == 1, "modèle sans pièce visible : ×1")
	local lamp = { Range = 8, Parent = true, IsA = function(_, class) return class == "PointLight" end }
	local dim = { Range = 3, Parent = true, IsA = function(_, class) return class == "SpotLight" end }
	local ranges = F.lightRanges(model({ lamp, dim, part(v3(1, 1, 1), pivot.Pos) }))
	check(ranges[lamp] == 8 and ranges[dim] == 3, "lightRanges : PointLight et SpotLight")
	lamp.Range = 8 * 7 -- un ScaleTo qui a grandi la portée
	F.trimLights(ranges, 3) -- taille montrée ×3
	check(near(lamp.Range, 24) and near(dim.Range, 3), "trimLights : au plus portée × taille montrée, jamais agrandie")

	-- 5. Branchements (texte)
	check(has(text, "fitSizeOf(attachment)"), "buildVisual : FitSize du présentoir lu")
	local fitAt = string.find(text, "local fit = if fitSize then fitFactor(display, pivot, fitSize) else 1", 1, true)
	local haloAt = string.find(text, "RarityHalo.AddDisplayed(display, rarity, boxCFrame, boxSize)", 1, true)
	check(fitAt ~= nil and haloAt ~= nil and fitAt < haloAt, "réduction avant le halo et le billboard (ils suivent la taille montrée)")
	check(has(text, "display:SetAttribute(WeightConfig.FitScaleAttribute, fit)"), "attribut FitScale sur l'objet réduit")
	check(
		has(text, "addBillboard(display, def, rarity, income, boxCFrame, boxSize, mutation, weight, fit)") and has(text, "Mutations.Scale(mutation, weight) * fit"),
		"BB_Item : hauteur avec la taille montrée"
	)
	local vfx = SOURCES["Text/VfxController"]
	check(
		has(vfx, "source:GetAttribute(WeightConfig.FitScaleAttribute)") and has(vfx, "shown / fit") and has(vfx, "WeightConfig.RarestMaxScale"),
		"socle : vraie taille (FitScale retiré), au plus RarestMaxScale"
	)
end)
if not ok then
	fails += 1
	print("  ERREUR " .. tostring(problem))
end
print(`banc a234 (taille selon le poids, FitSize) : {checks} vérification(s), {fails} échec(s)`)
