--!nocheck
-- E. 20 essais sans duplication de colis (« Fini quand » de DEV-048), à 3 joueurs : coups et
-- ramassages croisés, colis abandonnés, prises simultanées, départs (et arrivées), nuit (rayons
-- remplis pendant qu'un colis est sorti), vigile qui change de cible et capture. Vrais vigiles,
-- vrais magasins (deux en zone 1), vraies prises sur les rayons.
--
-- Contrôlé à chaque image (ON_FRAME), pendant tous les essais :
--   - aucun colis à deux endroits à la fois (porté, au sol, posé sur un établi : census) ;
--   - pour chaque magasin : colis sur les rayons (en vol de retour compris) + colis de ce tirage
--     portés ou au sol + colis de ce tirage posés sur un établi = 10 (aucun créé, aucun perdu) ;
--   - au plus un colis par emplacement de rayon ;
--   - autant de modèles de colis au sol que de colis au sol, et un seul visuel par porteur.
-- Le camion est tenu à l'écart (phase « Warning » : pas d'apparition).

local Carry = serverModule("CarryService")
local Heist = serverModule("StoreHeistService")
local Window = serverModule("WindowService")
local Night = serverModule("NightCycleService")
local Bat = sharedModule("Config/Bat")
startServer()
Night._set("Warning")
flush()

local random = Random.new(30)
local roster = {}
local names = { "Alice", "Bob", "Chloe", "Dan", "Eve", "Farid", "Gwen", "Hugo" }
local nameIndex = 0
local function join()
	nameIndex += 1
	local player = newPlayer(names[nameIndex])
	spawnCharacter(player, Vector3.new(-40 + 4 * nameIndex, 3, 10))
	flush()
	table.insert(roster, player)
	return player
end
for _ = 1, 3 do
	join()
end
advance(0.5)

-- Tirages des magasins, pour la conservation.
local GEN = { [STORE_A.Name] = 1, [STORE_B.Name] = 1 }
local PAYLOAD_GEN = {}
Heist.OnBoxGrabbed(function(_player, payload)
	PAYLOAD_GEN[payload] = GEN[payload.StoreId]
end)
local violations = {}
local function violation(text)
	if #violations < 12 then
		table.insert(violations, string.format("%.2f s : %s", now(), text))
	end
	violations.n = (violations.n or 0) + 1
end
local frames = 0
ON_FRAME = function()
	frames += 1
	local c = census()
	for _, d in c.duplicates do
		violation(`doublon : {d}`)
	end
	for _, store in { STORE_A, STORE_B } do
		local gen = GEN[store.Name]
		local out = 0
		for _, list in { c.carried, c.ground } do
			for _, p in list do
				if p.StoreId == store.Name and PAYLOAD_GEN[p] == gen then
					out += 1
				end
			end
		end
		local consumed = 0
		for p in CONSUMED do
			if p.StoreId == store.Name and PAYLOAD_GEN[p] == gen then
				consumed += 1
			end
		end
		local total = shelfCount(store) + out + consumed
		if total ~= 10 then
			violation(`{store.Name} : {shelfCount(store)} sur les rayons + {out} sortis + {consumed} posés = {total}`)
		end
		local slots = {}
		for _, box in shelfBoxes(store) do
			local slot = box:GetAttribute("Slot")
			if slots[slot] then
				violation(`{store.Name} : deux colis sur {slot}`)
			end
			slots[slot] = true
		end
	end
	local f = dropsFolder()
	local models = 0
	if f then
		for _, child in f:GetChildren() do
			if child:GetAttribute("DropId") ~= nil then
				models += 1
			end
		end
	end
	if models ~= #c.ground then
		violation(`{models} modèles au sol pour {#c.ground} colis au sol`)
	end
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			local visuals = 0
			for _, child in character:GetChildren() do
				if child.Name == "CarryVisual" then
					visuals += 1
				end
			end
			if visuals ~= (if Carry.IsCarrying(player) then 1 else 0) then
				violation(`{player.Name} : {visuals} visuel(s) porté(s)`)
			end
		end
	end
end

-- Outils des essais -------------------------------------------------------------------------------
local lastSwing, lastHitOn = {}, {}
local function waitUntil(t)
	if t > now() then
		advance(t - now())
	end
end
-- `hitter` frappe `target` (qui porte) de 4 studs, après sa recharge et l'immunité de la cible.
local function hit(hitter, target)
	waitUntil(math.max((lastSwing[hitter] or -math.huge) + Bat.Cooldown + 0.05, (lastHitOn[hitter] or -math.huge) + Bat.StunDuration + 0.05, (lastHitOn[target] or -math.huge) + Bat.HitImmunity + 0.05))
	local p = rootOf(target).Position
	local dir = Vector3.new(random:NextNumber(-1, 1), 0, random:NextNumber(-1, 1))
	dir = if dir.Magnitude > 0.1 then dir.Unit else Vector3.new(1, 0, 0)
	moveTo(hitter, p - dir * 4, dir)
	equipBat(hitter)
	flush()
	fireAs(hitter, "SwingBat")
	flush()
	lastSwing[hitter] = now()
	local ok = not Carry.IsCarrying(target)
	if ok then
		lastHitOn[target] = now()
	end
	return ok
end
local function lastDrop()
	local list = batDrops()
	local model = list[#list]
	local id = model and model:GetAttribute("DropId")
	local payload, position = Carry.GetDrop(id)
	return id, payload, position
end
-- Debout à 2 studs du colis `id`, plus étourdi : maintien de 0,5 s. Renvoie true s'il le porte.
local function pickup(player, id)
	waitUntil((lastHitOn[player] or -math.huge) + Bat.StunDuration + 0.05)
	local _, position = Carry.GetDrop(id)
	if position == nil then
		return false
	end
	local a = random:NextNumber(0, 2 * math.pi)
	moveTo(player, Vector3.new(position.X + 2 * math.cos(a), 3, position.Z + 2 * math.sin(a)))
	fireAs(player, "GrabDropped", id)
	advance(Bat.DroppedGrabTime)
	fireAs(player, "GrabDropped", id)
	flush()
	return Carry.GetDrop(id) == nil and Carry.IsCarrying(player)
end
-- À l'abri en zone safe (son vigile abandonne), puis colis posé sur un établi.
local function deposit(player)
	local payload = Carry.GetPayload(player)
	if payload == nil then
		return false
	end
	moveTo(player, Vector3.new(-40 + random:NextNumber(-10, 10), 3, random:NextNumber(-10, 10)))
	flush()
	advance(0.2)
	if Carry.GetPayload(player) ~= payload then
		return false
	end
	Carry.Consume(player, "Placed")
	CONSUMED[payload] = true
	flush()
	return true
end
-- Vitrine reconstruite s'il le faut, cassée par `breaker` : magasin ouvert pour 10 s neuves.
local function open(store, breaker)
	local w = store:FindFirstChild("Window")
	if w:GetAttribute("Broken") == true then
		Window.Rebuild(w:GetAttribute("WindowId"))
		flush()
	end
	breakStore(breaker, store)
	advance(1.1) -- avance du casseur
end
local function grabFrom(player, store)
	local slot = fullSlot(store)
	return slot ~= nil and grabShelf(player, store, slot)
end
-- `player` sort du magasin, en `at` dans le couloir.
local function goOut(player)
	local at = Vector3.new(random:NextNumber(45, 110), 3, random:NextNumber(-18, 18))
	moveTo(player, at)
	return at
end
-- Tout est réglé : rien porté, rien au sol (on attend la fin des colis au sol), vigiles partis.
local function settle()
	for _, player in Players:GetPlayers() do
		if Carry.IsCarrying(player) then
			deposit(player)
		end
	end
	local t = 0
	while (#batDrops() > 0 or #guards() > 0) and t < 40 do
		advance(0.5)
		t += 0.5
	end
	advance(2) -- vols de retour finis
end
local function leaveAndReplace(player)
	local index = table.find(roster, player)
	leave(player)
	table.remove(roster, index)
	return join()
end

-- Les essais ---------------------------------------------------------------------------------------
local outcomes = {}
local patterns = {
	-- 1. X prend, Y frappe, Z ramasse et pose.
	function(store, X, Y, Z)
		open(store, X)
		assert(grabFrom(X, store), "prise")
		goOut(X)
		assert(hit(Y, X), "coup")
		local id = lastDrop()
		assert(pickup(Z, id), "ramassage")
		return deposit(Z) and "ramassé par un tiers, posé"
	end,
	-- 2. Coups croisés : Y frappe X, Y ramasse, X frappe Y, X ramasse et pose.
	function(store, X, Y, Z)
		open(store, X)
		assert(grabFrom(X, store), "prise")
		goOut(X)
		assert(hit(Y, X), "coup 1")
		local id = lastDrop()
		assert(pickup(Y, id), "ramassage 1")
		goOut(Y)
		assert(hit(X, Y), "coup 2")
		id = lastDrop()
		assert(pickup(X, id), "ramassage 2")
		return deposit(X) and "coups croisés, repris par le premier porteur"
	end,
	-- 3. Personne ne ramasse : retour sur le rayon au bout de 15 s.
	function(store, X, Y, Z)
		open(store, X)
		assert(grabFrom(X, store), "prise")
		goOut(X)
		assert(hit(Y, X), "coup")
		local id = lastDrop()
		moveTo(X, Vector3.new(-40, 3, 0))
		moveTo(Y, Vector3.new(-30, 3, 0))
		advance(Bat.DroppedLifetime + 0.5)
		return Carry.GetDrop(id) == nil and "abandonné, revenu sur son rayon"
	end,
	-- 4. Deux prises qui finissent dans la même image : un seul preneur.
	function(store, X, Y, Z)
		open(store, X)
		assert(grabFrom(X, store), "prise")
		goOut(X)
		assert(hit(Y, X), "coup")
		local id, _, position = lastDrop()
		moveTo(Y, Vector3.new(position.X + 2, 3, position.Z))
		moveTo(Z, Vector3.new(position.X - 2, 3, position.Z))
		fireAs(Y, "GrabDropped", id)
		fireAs(Z, "GrabDropped", id)
		advance(Bat.DroppedGrabTime)
		fireAs(Y, "GrabDropped", id)
		fireAs(Z, "GrabDropped", id)
		flush()
		local holders = (if Carry.IsCarrying(Y) then 1 else 0) + (if Carry.IsCarrying(Z) then 1 else 0)
		assert(holders == 1, `{holders} preneur(s)`)
		local taker = if Carry.IsCarrying(Y) then Y else Z
		return deposit(taker) and "prises simultanées, un seul preneur"
	end,
	-- 5. Le ramasseur quitte le jeu : le colis rentre sur son rayon ; un joueur arrive.
	function(store, X, Y, Z)
		open(store, X)
		assert(grabFrom(X, store), "prise")
		goOut(X)
		assert(hit(Y, X), "coup")
		local id = lastDrop()
		assert(pickup(Z, id), "ramassage")
		goOut(Z)
		leaveAndReplace(Z)
		return not Carry.IsCarrying(Z) and "ramasseur parti, colis revenu"
	end,
	-- 6. Le porteur frappé quitte le jeu, son colis au sol : un autre le ramasse et le pose.
	function(store, X, Y, Z)
		open(store, X)
		assert(grabFrom(X, store), "prise")
		goOut(X)
		assert(hit(Y, X), "coup")
		local id = lastDrop()
		leaveAndReplace(X)
		assert(Carry.GetDrop(id) ~= nil, "colis toujours au sol")
		assert(pickup(Z, id), "ramassage")
		return deposit(Z) and "porteur parti, colis ramassé par un autre"
	end,
	-- 7. Nuit : rayons remplis pendant que le colis est au sol ; il ne revient pas (ou il est ramassé).
	function(store, X, Y, Z, round)
		open(store, X)
		assert(grabFrom(X, store), "prise")
		goOut(X)
		assert(hit(Y, X), "coup")
		local id = lastDrop()
		for _, s in { STORE_A, STORE_B } do
			local w = s:FindFirstChild("Window")
			if w:GetAttribute("Broken") == true then
				Window.Rebuild(w:GetAttribute("WindowId")) -- magasins fermés : remplis tout de suite
			end
		end
		flush()
		Night._set("Night")
		Heist.RefillAll()
		GEN[STORE_A.Name] += 1
		GEN[STORE_B.Name] += 1
		flush()
		assert(shelfCount(STORE_A) == 10 and shelfCount(STORE_B) == 10, "rayons pleins")
		local result
		if round == 1 then
			advance(Bat.DroppedLifetime + 0.5)
			result = Carry.GetDrop(id) == nil and shelfCount(store) == 10 and "nuit : resté au sol, il ne revient pas"
		else
			assert(pickup(Z, id), "ramassage")
			result = deposit(Z) and "nuit : ramassé après le remplissage, posé"
		end
		Night._set("Warning")
		return result
	end,
	-- 8. Le vigile change de cible et capture le ramasseur : le colis rentre sur son rayon.
	function(store, X, Y, Z)
		open(store, X)
		assert(grabFrom(X, store), "prise")
		goOut(X)
		advance(0.6)
		assert(hit(Y, X), "coup")
		local id = lastDrop()
		advance(4) -- le vigile arrive près du colis
		assert(pickup(Z, id), "ramassage")
		local t = 0
		while Carry.IsCarrying(Z) and t < 5 do
			advance(0.25)
			t += 0.25
		end
		return not Carry.IsCarrying(Z) and logHas(`{Z.Name} rattrapé`, "PRINT", "server") and "capturé par le vigile qui suivait le colis"
	end,
	-- 9. Double coup : Y frappe X, Z ramasse, X (remis) frappe Z, Y ramasse et pose.
	function(store, X, Y, Z)
		open(store, X)
		assert(grabFrom(X, store), "prise")
		goOut(X)
		assert(hit(Y, X), "coup 1")
		local id = lastDrop()
		assert(pickup(Z, id), "ramassage 1")
		goOut(Z)
		assert(hit(X, Z), "coup 2")
		id = lastDrop()
		assert(pickup(Y, id), "ramassage 2")
		return deposit(Y) and "double coup, deux ramassages"
	end,
	-- 10. Deux colis du même magasin : X et Z prennent, Y les fait tomber tous les deux, ils les
	-- ramassent en croisant.
	function(store, X, Y, Z)
		open(store, X)
		assert(grabFrom(X, store), "prise X")
		assert(grabFrom(Z, store), "prise Z")
		local px = goOut(X)
		moveTo(Z, px + Vector3.new(0, 0, 12))
		assert(hit(Y, X), "coup X")
		local idX = lastDrop()
		assert(hit(Y, Z), "coup Z")
		local idZ = lastDrop()
		assert(idX ~= idZ, "deux colis au sol")
		assert(pickup(X, idZ), "X ramasse celui de Z")
		assert(pickup(Z, idX), "Z ramasse celui de X")
		return deposit(X) and deposit(Z) and "deux colis, ramassages croisés"
	end,
}

for trial = 1, 20 do
	local pattern = (trial - 1) % #patterns + 1
	local round = if trial <= #patterns then 1 else 2
	local store = if trial % 2 == 1 then STORE_A else STORE_B
	local shift = trial % 3
	local X, Y, Z = roster[1 + shift % 3], roster[1 + (shift + 1) % 3], roster[1 + (shift + 2) % 3]
	clearLog()
	local before = violations.n or 0
	local ok, result = pcall(patterns[pattern], store, X, Y, Z, round)
	settle()
	local clean = #census().carried == 0 and #census().ground == 0
	local okText = if ok then tostring(result) else `erreur : {result}`
	check(ok and result and (violations.n or 0) == before and clean, `E{trial} essai {trial} (scène {pattern}, {store.Name}, {X.Name}/{Y.Name}/{Z.Name}) : {okText}`)
	table.insert(outcomes, okText)
end

check((violations.n or 0) == 0, `E21 aucune violation sur {frames} images ({violations.n or 0})`)
for _, v in violations do
	print("    " .. v)
end
local consumed = 0
for _ in CONSUMED do
	consumed += 1
end
check(consumed >= 12, `E22 {consumed} colis posés sur un établi au fil des essais`)
check(#Players:GetPlayers() == 3, "E23 toujours 3 joueurs après les départs et arrivées")

summary("scénario trials")
