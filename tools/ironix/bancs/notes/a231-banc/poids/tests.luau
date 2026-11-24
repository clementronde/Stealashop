-- Banc a231, partie poids (vague 70) : un vieux profil passe par ItemWeight.Migrate ; la taille d'avant (Tiny, Big) part de
-- la mutation une fois le poids posé, le poids et le revenu ne bougent pas. Préambule repris du banc a203 (faux require).

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

local function count(t)
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

local ok, problem = pcall(function()
	local Features = charge("Config/Features")
	local ItemWeight = charge("ItemWeight")
	local Mutations = charge("Config/Mutations")
	check(Features.SingleBoxReveal == true and ItemWeight.Enabled(), "poids en marche (Features.SingleBoxReveal)")

	-- 1. Vieux profil : objets d'avant le poids, et objets déjà pesés par la vague 62 qui gardent Tiny ou Big
	local function oldItems()
		return {
			u1 = { Id = "a", Source = "NPC", Zone = 1, Mutation = { Size = "Tiny", Effect = "Gold" } }, -- pas pesé
			u2 = { Id = "a", Source = "NPC", Zone = 1, Mutation = { Size = "Tiny" } }, -- pas pesé
			u3 = { Id = "a", Source = "NPC", Zone = 2, Mutation = { Size = "Big", Effect = "Shiny" }, Weight = 80 }, -- pesé en vague 62
			u4 = { Id = "a", Source = "NPC", Zone = 2, Mutation = { Size = "Tiny" }, Weight = 2.2 }, -- pesé en vague 62
			u5 = { Id = "a", Source = "NPC", Zone = 3, Mutation = { Size = "Huge" } }, -- pas pesé
			u6 = { Id = "a", Source = "NPC", Zone = 3, Mutation = { Size = "Colossal", Effect = "Rainbow" }, Weight = 9000 },
			u7 = { Id = "a", Source = "NPC", Zone = 1, Weight = 12 },
			u8 = { Id = "a", Source = "NPC", Zone = 1, Mutation = { Effect = "Neon" }, Weight = 5 },
		}
	end
	local items = oldItems()
	local before = {}
	for uid, entry in oldItems() do
		before[uid] = Mutations.IncomeMultiplier(entry.Mutation, ItemWeight.Effective(entry.Weight, if entry.Mutation then entry.Mutation.Size else nil))
	end
	local changed = ItemWeight.Migrate(items)
	check(changed == 5, `5 objets changés sur 8 (u1 à u5) : {changed}`)
	check(items.u1.Weight == 2.2 and items.u2.Weight == 2.2 and items.u3.Weight == 80 and items.u4.Weight == 2.2 and items.u5.Weight == 1250 and items.u6.Weight == 9000 and items.u7.Weight == 12 and items.u8.Weight == 5, "poids : 2,2 ; 2,2 ; 80 ; 2,2 ; 1 250 ; 9 000 ; 12 ; 5 kg (inchangés ou tirés de la taille d'avant)")
	check(items.u1.Mutation ~= nil and items.u1.Mutation.Size == nil and items.u1.Mutation.Effect == "Gold" and count(items.u1.Mutation) == 1, "Tiny + Gold : Tiny retirée, Gold gardé")
	check(items.u2.Mutation == nil, "Tiny seule : la mutation vide part")
	check(items.u3.Mutation.Size == nil and items.u3.Mutation.Effect == "Shiny", "Big + Shiny déjà pesé : Big retirée, Shiny gardé")
	check(items.u4.Mutation == nil, "Tiny seule déjà pesée : la mutation vide part")
	check(items.u5.Mutation.Size == "Huge" and items.u6.Mutation.Size == "Colossal" and items.u6.Mutation.Effect == "Rainbow", "Huge et Colossal gardées")
	check(items.u7.Mutation == nil and items.u8.Mutation.Effect == "Neon", "objets sans taille : rien ne change")
	local valid, same = true, true
	for uid, entry in items do
		if not Mutations.IsValid(entry.Mutation) then
			valid = false
		end
		local after = Mutations.IncomeMultiplier(entry.Mutation, entry.Weight)
		if math.abs(after - before[uid]) > 1e-9 then
			same = false
			print(`    {uid} : {before[uid]} → {after}`)
		end
	end
	check(valid, "chaque mutation reste valide (Mutations.IsValid)")
	check(same, "revenu de chaque objet inchangé")
	check(ItemWeight.Migrate(items) == 0, "seconde passe : rien (idempotente)")
	check(Mutations.Sanitize(items.u1.Mutation).Effect == "Gold", "Sanitize garde l'effet")

	-- 2. Poids coupé (Features.SingleBoxReveal = false) : la taille d'avant est encore lue, rien n'est retiré
	ItemWeight.SetEnabledForTest(false)
	local off = oldItems()
	ItemWeight.Migrate(off)
	check(off.u1.Mutation.Size == "Tiny" and off.u2.Mutation.Size == "Tiny" and off.u3.Mutation.Size == "Big", "poids coupé : Tiny et Big gardées")
	check(off.u1.Weight == 2.2 and off.u5.Weight == 1250, "poids coupé : le poids est posé quand même")
	ItemWeight.SetEnabledForTest(nil)

	-- 3. DataService : la migration tourne toujours au chargement
	check(string.find(SOURCES["Text/DataService"], "ItemWeight.Migrate(profile.Data.Items)", 1, true) ~= nil, "DataService appelle ItemWeight.Migrate au chargement")
end)
if not ok then
	fails += 1
	print("  ERREUR " .. tostring(problem))
end
print(`banc a231 (vieux profils : taille d'avant retirée) : {checks} vérification(s), {fails} échec(s)`)
