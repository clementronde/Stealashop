--!nocheck
-- Scénario « heist » (a49, DEV-131) : mise en place du banc a17-heist (copie d'a49), puis le tirage des
-- mutations à la mise en rayon par le vrai StoreHeistService : fréquences sur des milliers de colis
-- (une mutation par famille au plus), mutation passée à l'étiquette (AttachBoxLabel, 4e argument) et au
-- payload de la prise, gardée au retour sur le rayon, jamais pour le colis du tuto.

local Mutations = requireModule(ConfigF.Mutations, "server")
-- L'étiquette du bouchon note aussi la mutation reçue (4e argument).
local drawn = { total = 0, none = 0, bad = 0, size = {}, effect = {} }
local baseLabel = C.AttachBoxLabel
C.AttachBoxLabel = function(model, rarityId, itemId, mutation)
	local gui = baseLabel(model, rarityId, itemId)
	C.labels[model].Mutation = mutation
	drawn.total += 1
	if mutation == nil then
		drawn.none += 1
	else
		if not Mutations.IsValid(mutation) or (mutation.Size == nil and mutation.Effect == nil) then
			drawn.bad += 1
		end
		if mutation.Size then
			drawn.size[mutation.Size] = (drawn.size[mutation.Size] or 0) + 1
		end
		if mutation.Effect then
			drawn.effect[mutation.Effect] = (drawn.effect[mutation.Effect] or 0) + 1
		end
	end
	return gui
end
local function sameMutation(a, b)
	if a == nil or b == nil then
		return a == b
	end
	return a.Size == b.Size and a.Effect == b.Effect
end

print("== a49 : tirage des mutations à la mise en rayon")
Heist.Init()
GrabRemote = ReplicatedStorage.Remotes.GrabItem
taskLib.spawn(Heist.Start)
advance(0.1)
check(drawn.total == 30, `30 colis posés, 30 étiquettes ({drawn.total})`)
for _ = 1, 400 do
	Heist.RefillAll()
end
local N = drawn.total
check(N == 30 * 401, `{N} colis tirés`)
check(drawn.bad == 0, "chaque mutation tirée : une taille et un effet au plus, Id connus")
local function within(count, p, label)
	local mean = N * p
	local sd = math.sqrt(N * p * (1 - p))
	check(math.abs(count - mean) <= 4.5 * sd, `{label} : {count} sur {N} (attendu {math.round(mean)} ± {math.round(4.5 * sd)})`)
end
for _, e in Mutations.Sizes do
	within(drawn.size[e.Id] or 0, e.Chance / 100, `taille {e.Id}`)
end
for _, e in Mutations.Effects do
	within(drawn.effect[e.Id] or 0, e.Chance / 100, `effet {e.Id}`)
end
within(drawn.none, 0.75 * 0.858, "aucune mutation")
for model, label in C.labels do
	if label.ItemId == Tutorial.GuaranteedItemId then
		check(false, "le Pot de nouilles n'est jamais tiré")
	end
end

print("== a49 : la mutation de l'étiquette est celle du payload, et revient avec le colis")
-- Un colis muté et un colis sans mutation dans la Supérette (nouveau tirage jusqu'à en avoir).
local function find(wantMutated)
	for _ = 1, 200 do
		for n = 1, 10 do
			local box = boxAt(superette, n)
			local label = box and C.labels[box]
			if label and box:GetAttribute("Tier") == "Standard" and ((label.Mutation ~= nil) == wantMutated) then
				return n, label
			end
		end
		Heist.RefillAll()
	end
	return nil, nil
end
-- Magasin fermé (un remplissage s'y fait tout de suite), puis un colis voulu, puis réouverture.
local function prepare(player, wantMutated)
	if Heist.IsOpen(superette) then
		advance(11)
	end
	local n, label = find(wantMutated)
	reopen(superette, player, false)
	return n, label
end
local nMut, labelMut = prepare(p1, true)
check(nMut ~= nil, "un colis Standard muté dans la Supérette")
local pay = take(p1, superette, nMut)
check(pay ~= nil and pay.Mutation ~= nil and sameMutation(pay.Mutation, labelMut.Mutation), `payload : la mutation de l'étiquette ({Mutations.Label(pay and pay.Mutation)})`)
check(pay ~= nil and pay.ItemId == labelMut.ItemId and pay.Rarity == labelMut.Rarity, "même objet, même rareté")
check(logHas(`, {Mutations.Label(labelMut.Mutation)}`, "PRINT"), "ligne de prise avec la mutation")
C.Fail(p1, "Caught")
advance(2)
local back = boxAt(superette, nMut)
check(back ~= nil and sameMutation(C.labels[back].Mutation, labelMut.Mutation) and C.labels[back].ItemId == labelMut.ItemId, "colis revenu sur son rayon : même mutation (pas de nouveau tirage)")
advance(1.1)
local nPlain = prepare(p1, false)
local plainPay = take(p1, superette, nPlain)
check(plainPay ~= nil and plainPay.Mutation == nil, "colis sans mutation : payload sans Mutation")
C.Consume(p1)

print("== a49 : jamais de mutation pour le colis du tuto")
Heist.SetContentOverride(function(player)
	if player == p1 then
		return { Tier = Tutorial.FirstBoxTier, ItemId = Tutorial.GuaranteedItemId }
	end
	return nil
end)
local nTuto, labelTuto = prepare(p1, true)
local tuto = take(p1, superette, nTuto)
check(labelTuto ~= nil and labelTuto.Mutation ~= nil, "le colis du rayon était muté")
check(tuto ~= nil and tuto.ItemId == "Z1_PotDeNouilles" and tuto.Mutation == nil, "colis du tuto (Pot de nouilles) : aucune mutation")
C.Fail(p1, "Caught")
advance(2)
local tutoBack = boxAt(superette, nTuto)
check(tutoBack ~= nil and sameMutation(C.labels[tutoBack].Mutation, labelTuto.Mutation), "rendu au rayon : le colis d'origine garde sa mutation")
Heist.SetContentOverride(function()
	return nil
end)
moveTo(p2, P.center)
advance(1.1)
local nKeep, labelKeep = prepare(p2, true)
local keep = take(p2, superette, nKeep)
check(keep ~= nil and sameMutation(keep.Mutation, labelKeep.Mutation), "accroche sans remplacement : la mutation du rayon reste")
C.Consume(p2)
Heist.SetContentOverride(nil)

print(string.format("scénario heist : %d vérification(s), %d échec(s)", CHECKS, FAILS))
