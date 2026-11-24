--!nocheck
-- Scénario « stress » : 20 essais de vol à 3 joueurs (jalon M3 : « aucune duplication sur 20
-- essais »), chacun avec une fin différente, départs au pire moment compris : dépôt normal, batte,
-- mort, départ du voleur (en route, dans l'image avant le dépôt, dans l'image après), départ de la
-- victime (en route, avant, après le dépôt), départ des deux dans la même image, départ pendant le
-- maintien de la prise. Après chaque essai : chaque uid dans un seul profil, aucun objet perdu,
-- personne ne porte plus rien, plus aucun objet tenu. Les joueurs partis reviennent avec leur
-- sauvegarde (nouvelle session).

startServer()

local rng = Random.new(2911)
local names = { "Ada", "Bob", "Cy" }
local roster = {} -- { name, player, data }
local expected = 0
local nextUid = 0

local function newUid(prefix)
	nextUid += 1
	return `{prefix}-{nextUid}`
end
local COMMONS = { "Z1_CanetteDeSoda", "Z1_PaquetDeChips", "Z1_Donut", "Z1_Banane", "Z1_HotDog", "Z1_Carotte" }

for index, name in names do
	local data = newProfile()
	for slot = 1, 3 do
		addItem(data, newUid(name), COMMONS[(index + slot) % #COMMONS + 1], slot)
		expected += 1
	end
	roster[index] = { name = name, player = join(name, data), data = data }
end
advance(1.2)

local function rejoin(entry)
	local oldId = entry.player.UserId
	local saved = STORE[oldId]
	STORE[oldId] = nil
	entry.data = DataService.deepCopy(saved)
	entry.player = join(entry.name, entry.data)
	advance(1.2)
end
local function present(entry)
	return entry.player.Parent == Players
end

-- Au moins 2 objets exposés chez la victime (le meilleur est à l'abri) : complète ses présentoirs.
local function topUp(entry)
	local count = 0
	for slot = 1, 4 do
		if entry.data.Display[tostring(slot)] ~= nil then
			count += 1
		end
	end
	for slot = 1, 4 do
		if count >= 3 then
			break
		end
		if entry.data.Display[tostring(slot)] == nil then
			addItem(entry.data, newUid(entry.name), COMMONS[rng:NextInteger(1, #COMMONS)], slot)
			expected += 1
			count += 1
		end
	end
	advance(1.2)
end
local function stealableSlot(entry)
	local plot = shopOf(entry.player)
	local safe = plot:GetAttribute("SafeSlots")
	local options = {}
	for slot in DisplayService.GetExposed(entry.player) do
		if tostring(slot) ~= safe then
			table.insert(options, slot)
		end
	end
	table.sort(options)
	return options[rng:NextInteger(1, #options)]
end
local function walkFor(player, target, seconds, speed)
	local deadline = now() + seconds
	while now() < deadline do
		local root = rootOf(player)
		if root == nil then
			return
		end
		local delta = target - root.Position
		if delta.Magnitude < 0.05 then
			return
		end
		moveTo(player, root.Position + delta.Unit * math.min(delta.Magnitude, speed * 0.1))
		advance(0.1)
	end
end
-- Jusqu'à 1 stud devant sa porte (dehors).
local function toOwnDoor(thief, victimPlot, speed)
	local V = refsOfShop(victimPlot)
	local H = refsOfShop(shopOf(thief))
	walkTo(thief, Vector3.new(V.door.X, 3, V.door.Z) + V.front * 1, speed)
	walkTo(thief, V.outside, speed)
	walkTo(thief, HUB_CENTER, speed)
	walkTo(thief, H.outside, speed)
	walkTo(thief, Vector3.new(H.door.X, 3, H.door.Z) + H.front * 1, speed)
	return H
end
local function stepIn(thief, H)
	moveTo(thief, Vector3.new(H.door.X, 3, H.door.Z) - H.front * 3)
end

local OUTCOMES = {
	"dépôt",
	"batte",
	"mort du voleur",
	"départ du voleur en route",
	"départ du voleur dans l'image avant le dépôt",
	"départ du voleur juste après le dépôt",
	"départ de la victime en route",
	"départ de la victime dans l'image avant le dépôt",
	"départ de la victime juste après le dépôt",
	"départ des deux dans la même image, au dépôt",
	"départ du voleur pendant le maintien",
	"départ de la victime pendant le maintien",
}

local stolen, returned = 0, 0
for trial = 1, 20 do
	local outcome = OUTCOMES[(trial - 1) % #OUTCOMES + 1]
	-- Victime et voleur : deux joueurs différents, au hasard.
	local vi = rng:NextInteger(1, 3)
	local ti = (vi + rng:NextInteger(0, 1)) % 3 + 1
	local victim, thief = roster[vi], roster[ti]
	section(`essai {trial} : {thief.name} vole {victim.name}, {outcome}`)
	-- a99 : plus d'immunité après un vol subi ; un voleur mort dans cette boutique attend ses 60 s.
	local left = PvPService.GetRobCooldown(thief.player, shopOf(victim.player))
	if left > 0 then
		advance(left + 0.5, 0.5)
	end
	topUp(victim)
	local victimPlot = shopOf(victim.player)
	DAMAGE[victim.player] = 10
	DAMAGE[thief.player] = 1000
	local broken = breakDoor(thief.player, victimPlot)
	check(broken, `essai {trial} : porte cassée`)
	local slot = stealableSlot(victim)
	local uid = DisplayService.GetExposed(victim.player)[slot].Uid
	local _ = rng:NextInteger(0, 20) -- a146 : même tirage qu'avant (suite de l'aléa inchangée)
	local speed = 16 -- a146 : vitesse fixe du voleur (Balance.Carry.StolenItemWalkSpeed), plus 20 à 40
	local index = victimPlot:GetAttribute("PlotIndex")

	if outcome == "départ du voleur pendant le maintien" or outcome == "départ de la victime pendant le maintien" then
		standBy(thief.player, victimPlot, slot)
		fireAs(thief.player, "StealItem", index, slot)
		advance(0.2 + rng:NextNumber() * 0.7)
		local leaver = if outcome == "départ du voleur pendant le maintien" then thief else victim
		leave(leaver.player)
		if leaver == victim then
			advance(1 - 0.2)
			fireAs(thief.player, "StealItem", index, slot)
		end
		advance(0.3)
		check(not present(thief) or not CarryService.IsCarrying(thief.player), `essai {trial} : aucune prise après le départ`)
		returned += 1
	else
		check(steal(thief.player, victimPlot, slot), `essai {trial} : prise en 1 s`)
		if outcome == "dépôt" then
			runHome(thief.player, victimPlot, speed)
			stolen += 1
		elseif outcome == "batte" or outcome == "mort du voleur" or outcome == "départ du voleur en route" or outcome == "départ de la victime en route" then
			walkFor(thief.player, refsOfShop(victimPlot).outside, 0.5 + rng:NextNumber() * 2.5, speed)
			if outcome == "batte" then
				CarryService.Fail(thief.player, "Bat")
			elseif outcome == "mort du voleur" then
				kill(thief.player)
				advance(0.2)
				spawnCharacter(thief.player, Vector3.new(0, 3, 0))
			elseif outcome == "départ du voleur en route" then
				leave(thief.player)
			else
				leave(victim.player)
			end
			returned += 1
		else
			local H = toOwnDoor(thief.player, victimPlot, speed)
			if outcome == "départ du voleur dans l'image avant le dépôt" then
				stepIn(thief.player, H)
				leave(thief.player)
				returned += 1
			elseif outcome == "départ de la victime dans l'image avant le dépôt" then
				stepIn(thief.player, H)
				leave(victim.player)
				returned += 1
			else
				stepIn(thief.player, H)
				local waited = 0
				while CarryService.IsCarrying(thief.player) and waited < 1 do
					advance(1 / 30)
					waited += 1 / 30
				end
				check(not CarryService.IsCarrying(thief.player), `essai {trial} : dépôt fait`)
				if outcome == "départ du voleur juste après le dépôt" then
					leave(thief.player)
				elseif outcome == "départ de la victime juste après le dépôt" then
					leave(victim.player)
				else
					leave(thief.player)
					leave(victim.player)
				end
				stolen += 1
			end
		end
	end
	advance(1.5)

	-- Bilan de l'essai.
	invariants(`essai {trial}`, expected)
	local owners = itemOwners()
	local where = owners[uid]
	local thiefId, victimId = thief.player.UserId, victim.player.UserId
	local deposited = outcome == "dépôt" or string.find(outcome, "après le dépôt", 1, true) ~= nil or string.find(outcome, "même image", 1, true) ~= nil
	if deposited then
		check(where and where[1] == thiefId, `essai {trial} : l'objet {uid} est chez le voleur`)
	else
		check(where and where[1] == victimId, `essai {trial} : l'objet {uid} est resté chez la victime`)
	end
	local carrying, held = 0, 0
	for _, entry in roster do
		if present(entry) then
			if CarryService.IsCarrying(entry.player) or PvPService.GetTheft(entry.player) then
				carrying += 1
			end
			for itemUid in entry.data.Items do
				if DisplayService.IsHeld(entry.player, itemUid) then
					held += 1
				end
			end
		end
	end
	check(carrying == 0 and held == 0, `essai {trial} : plus rien de porté ni de tenu ({carrying}, {held})`)
	for _, entry in roster do
		if not present(entry) then
			rejoin(entry)
		end
	end
end

section("bilan des 20 essais")
check(stolen + returned == 20, `20 essais : {stolen} vol(s) réussi(s), {returned} objet(s) rendu(s)`)
check(stolen >= 5 and returned >= 10, "toutes les fins ont été jouées")
invariants("après les 20 essais", expected)
check(not logHas("mal formé", "WARN"), "aucun envoi de remote mal formé (Net, en Studio)")
check(not logHas("tick :", "WARN"), "aucune erreur dans les boucles des services")
check(not logHas("n'est plus le même", "WARN"), "aucune anomalie de transfert")
if VERBOSE then
	dumpLog()
end
summary("scénario stress")
