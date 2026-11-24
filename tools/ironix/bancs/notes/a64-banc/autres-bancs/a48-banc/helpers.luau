--!nocheck
-- Aides des scénarios du banc a48 (gains hors ligne).
-- Heure murale réaliste (2027) : une absence de plusieurs heures reste après 0.
OS_TIME_OFFSET = 1800000000

-- Heure murale vue par les modules (os.time du faux Roblox).
function wallNow()
	return math.floor(now()) + OS_TIME_OFFSET
end
-- Avance jusqu'à 0,1 s après la prochaine seconde entière : un join (0,3 s) ne change pas os.time().
function alignSecond()
	local target = math.floor(now()) + 1.1
	advance(target - now())
end
-- Le joueur est absent `seconds` s : l'horloge murale avance, le temps simulé (os.clock) ne bouge pas.
function away(seconds)
	OS_TIME_OFFSET += seconds
end
-- Versements hors ligne (DisplayService.AddOfflineEarnings, espionné par setup.luau ; dans Cash depuis a59).
function creditsOf(player)
	local out = {}
	for _, c in OFFLINE_CREDITS do
		if c.player == player then
			table.insert(out, c)
		end
	end
	return out
end
function padOf(player)
	return shopOf(player):FindFirstChild("CollectPad_01", true) -- a59 : plaque du présentoir 1
end
-- Monte sur la plaque CollectPad_01 de sa boutique (contrôle 10 fois par seconde), puis en redescend (a59, L-091).
function stepOnPad(player)
	local pad = padOf(player)
	moveTo(player, pad.Position + Vector3.new(0, 3, 0))
	advance(0.3)
	moveTo(player, pad.Position + Vector3.new(0, 3, -12))
	advance(0.3)
end
-- Envois d'économie AnalyticsService d'un joueur pour un SKU (« Income », « Offline »).
function economyFor(player, sku)
	local out = {}
	for _, e in ANALYTICS.economy do
		if e.player == player and (sku == nil or e.sku == sku) then
			table.insert(out, e)
		end
	end
	return out
end
function sumOf(entries)
	local total = 0
	for _, e in entries do
		total += e.amount
	end
	return total
end
function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end
-- Revenu d'un objet du catalogue ($/s, formule 7.1), zone du catalogue ou `zone`.
function incomeOf(itemId, zone)
	local def = Items.ById[itemId]
	return Formulas.ItemIncome(def.Zone or zone or 1, def.Rarity)
end
-- Copie d'a64 (vague 22, L-092 3f) : le gain attend le Claim (Offline.Pending, attribut OfflinePending).
-- claim(player) = le bouton Claim de UI_Offline (vrai remote ClaimOffline, sans argument). join réclame tout
-- de suite ce qui attend (AUTO_CLAIM), comme un joueur qui appuie sur Claim dès l'ouverture : les contrôles
-- d'avant (versement, Cash, télémétrie) restent les mêmes.
function claim(player)
	fireAs(player, "ClaimOffline")
	flush()
end
AUTO_CLAIM = true
local baseJoin = join
function join(name, data, userId)
	local player = baseJoin(name, data, userId)
	local pending = player:GetAttribute("OfflinePending")
	if AUTO_CLAIM and type(pending) == "number" and pending >= 1 then
		claim(player)
	end
	return player
end
