--!nocheck
-- Scénario « msg » (a297, serveur) : jeu DEV (caisse allumée), zone safe autour du hub. Les messages « Exclusive Crate:
-- you got a … » d'un lot : avec une ouverture, aucun avant sa fin ; à la fin (RevealDone, plafond, mort, nouvelle caisse),
-- ceux des seuls objets non montrés, au même instant que RevealEnded ; départ : aucun. Hors zone safe, ou ouverture
-- coupée : tous tout de suite. Le don des objets reste immédiat. Net limite RevealDone à 2 par seconde.
SET_ENVIRONMENT("Dev")
local zone = make("Part", { Name = "SafeZone_Banc", Anchored = true, CanCollide = false, Size = Vector3.new(800, 200, 800), CFrame = CFrame.new(0, 50, 0) }, MAP)
CollectionService:AddTag(zone, "SafeZone")
startServer()
local Crate = Monetization.Crate
local PREFIX = "Exclusive Crate: you got a"

local ada = join("Ada", newProfile())
local bob = join("Bob", newProfile())
advance(1.5)
local function humanoidOf(player)
	return player.Character and player.Character:FindFirstChildOfClass("Humanoid")
end
local function msgs(player)
	return notifies(player, PREFIX)
end
local function exclusivesOf(player)
	local list = {}
	for _, entry in dataOf(player).Items do
		if string.find(entry.Id, "^Exclusive_") then
			table.insert(list, entry.Id)
		end
	end
	return list
end
local function textFor(itemId)
	local def = Items.ById[itemId]
	return `{PREFIX} {Rarities.ById[def.Rarity].DisplayNameUpper} {def.DisplayName}!`
end
-- Objets ajoutés depuis `before` (liste rendue par exclusivesOf), dans l'ordre du profil (clés au hasard : on compare
-- des multiensembles).
local function counts(list)
	local out = {}
	for _, id in list do
		out[id] = (out[id] or 0) + 1
	end
	return out
end
local function added(player, before)
	local now = counts(exclusivesOf(player))
	for id, n in counts(before) do
		now[id] = (now[id] or 0) - n
	end
	local list = {}
	for id, n in now do
		for _ = 1, n do
			table.insert(list, id)
		end
	end
	return list
end
-- Les messages attendus : un par objet de `got`, sauf une fois l'objet `shown` (nil : tous).
local function expectedTexts(got, shown)
	local list = {}
	local skipped = shown == nil
	for _, id in got do
		if not skipped and id == shown then
			skipped = true
		else
			table.insert(list, textFor(id))
		end
	end
	table.sort(list)
	return list
end
local function textsOf(events)
	local list = {}
	for _, e in events do
		table.insert(list, e.args[1])
	end
	table.sort(list)
	return list
end
local function same(a, b)
	if #a ~= #b then
		return false
	end
	for i = 1, #a do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end
local function lastStart()
	local list = remotes("RevealStarted")
	return list[#list]
end
local function endedAt(id)
	local list = remotes("RevealEnded", function(e)
		return e.args[1] == id
	end)
	return if list[1] then list[1].t else nil
end
local function since(events, count)
	local out = {}
	for i = count + 1, #events do
		table.insert(out, events[i])
	end
	return out
end
-- Achète `productId` pour `player` (reçu `purchaseId`) ; rend (objets donnés, RevealStarted ou nil, messages d'avant).
local function buy(player, productId, purchaseId)
	local before = exclusivesOf(player)
	local startsBefore = #remotes("RevealStarted")
	local msgBefore = #msgs(player)
	check(settle(receipt(player, productId, purchaseId)) == GRANTED, `{purchaseId} : PurchaseGranted`)
	advance(0.2)
	local got = added(player, before)
	local started = if #remotes("RevealStarted") > startsBefore then lastStart() else nil
	return got, started, msgBefore
end

section("M1 Crate1 en zone safe : aucun message, ni avant ni à la fin")
local got, e, m0 = buy(ada, 8401, "MS-1")
check(#got == 1, `don immédiat : 1 objet ({#got})`)
check(e ~= nil and e.args[1] == ada and e.args[4] == got[1], "une ouverture, pour l'objet du lot")
check(#msgs(ada) == m0, `aucun message pendant la scène ({#msgs(ada) - m0})`)
advance(1.1)
fireAs(ada, "RevealDone", e and e.args[10])
advance(0.1)
check(endedAt(e and e.args[10]) ~= nil, "RevealDone : RevealEnded")
check(#msgs(ada) == m0, `à la fin : 0 message pour Crate1 ({#msgs(ada) - m0})`)

section("M2 Crate3 en zone safe : 2 messages à la fin, ceux des objets non montrés")
advance(1.1)
got, e, m0 = buy(ada, 8402, "MS-3")
check(#got == 3, `don immédiat : 3 objets ({#got})`)
local shown = e and e.args[4]
check(e ~= nil and table.find(got, shown) ~= nil, `une ouverture, pour {shown}`)
advance(5)
check(#msgs(ada) == m0, `aucun message 5 s après le don ({#msgs(ada) - m0})`)
advance(1.1)
fireAs(ada, "RevealDone", e and e.args[10])
advance(0.1)
local after = since(msgs(ada), m0)
local tEnd = endedAt(e and e.args[10])
check(#after == 2, `à la fin : 2 messages ({#after})`)
check(same(textsOf(after), expectedTexts(got, shown)), `les messages nomment les seuls objets non montrés ({table.concat(textsOf(after), " | ")})`)
local sameTime = tEnd ~= nil
for _, msg in after do
	sameTime = sameTime and msg.t == tEnd
end
check(sameTime, "messages au même instant que RevealEnded")
fireAs(ada, "RevealDone", e and e.args[10])
advance(1.2)
check(#msgs(ada) == m0 + 2, "RevealDone rejoué : aucun message de plus")

section("M3 fin par le plafond du plan : les messages partent au plafond")
got, e, m0 = buy(ada, 8402, "MS-PLAF")
local id = e and e.args[10]
local parsed = e and sharedModule("UnboxPlan").parse(e.args[11])
local limit = parsed and sharedModule("UnboxPlan").serverMaxSeconds(e.args[5], "Small", #parsed.Steps) or 60
advance(limit - 1)
check(#msgs(ada) == m0 and endedAt(id) == nil, string.format("1 s avant le plafond (%.1f s) : en cours, aucun message", limit))
advance(1.5)
after = since(msgs(ada), m0)
check(endedAt(id) ~= nil and logHas("plafond de temps"), "au plafond : RevealEnded")
check(#after == 2 and same(textsOf(after), expectedTexts(got, e and e.args[4])), `au plafond : 2 messages, objets non montrés ({#after})`)
check(after[1] ~= nil and after[1].t == endedAt(id), "au même instant que RevealEnded")

section("M4 fin par la mort : les messages partent à la mort")
got, e, m0 = buy(ada, 8402, "MS-MORT")
id = e and e.args[10]
check(#msgs(ada) == m0, "aucun message avant la mort")
humanoidOf(ada).Died:Fire()
advance(0.1)
after = since(msgs(ada), m0)
check(endedAt(id) ~= nil, "mort : RevealEnded")
check(#after == 2 and same(textsOf(after), expectedTexts(got, e and e.args[4])), `mort : 2 messages, objets non montrés ({#after})`)
spawnCharacter(ada, Vector3.new(0, 3, 0))
advance(0.5)

section("M5 fin par une nouvelle caisse : les messages de la 1re partent à sa fin")
got, e, m0 = buy(ada, 8402, "MS-NEW-3")
local firstId = e and e.args[10]
local firstGot, firstShown = got, e and e.args[4]
advance(1)
local got1, e1 = buy(ada, 8401, "MS-NEW-1")
check(e1 ~= nil and e1.args[10] ~= firstId and endedAt(firstId) ~= nil, "la 2e caisse finit la 1re ouverture et lance la sienne")
after = since(msgs(ada), m0)
check(#after == 2 and same(textsOf(after), expectedTexts(firstGot, firstShown)), `2 messages, ceux de la 1re caisse ({#after})`)
check(#got1 == 1, "2e caisse : 1 objet donné")
advance(1.1)
fireAs(ada, "RevealDone", e1 and e1.args[10])
advance(0.1)
check(#msgs(ada) == m0 + 2, "fin de la 2e (Crate1) : aucun message de plus")

section("M6 départ pendant l'ouverture : aucun message")
local bm0 = #msgs(bob)
got, e = buy(bob, 8402, "MS-LEAVE")
id = e and e.args[10]
check(#got == 3 and e ~= nil and e.args[1] == bob, "Bob : 3 objets, une ouverture")
leave(bob)
advance(0.5)
check(endedAt(id) ~= nil, "départ : RevealEnded pour les autres")
check(#msgs(bob) == bm0, `aucun message vers Bob parti ({#msgs(bob) - bm0})`)
check(logHas("caisse finie (joueur parti), 0 message(s)"), "la sortie dit : 0 message")

section("M7 hors zone safe : tous les messages tout de suite")
moveTo(ada, Vector3.new(5000, 3, 5000))
advance(1.2)
local starts = #remotes("RevealStarted")
got, e, m0 = buy(ada, 8402, "MS-OUT")
after = since(msgs(ada), m0)
check(e == nil and #remotes("RevealStarted") == starts, "aucune ouverture")
check(#got == 3 and #after == 3 and same(textsOf(after), expectedTexts(got, nil)), `3 objets, 3 messages tout de suite ({#after})`)

summary("scénario msg")
