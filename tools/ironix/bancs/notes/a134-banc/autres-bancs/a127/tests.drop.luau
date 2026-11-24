--!nocheck
-- a127 D (2026-11-14, vague 38, L-135 point 5, Clément : « oui ») : un objet lâché (G) ou tombé (coup de batte)
-- dans son propre magasin revole tout de suite sur son rayon ; dans la rue, ou dans un autre magasin, il tombe
-- au sol comme avant et le vigile le garde. Harnais du banc a114 (Features.ShelfOpen = true, sans WitnessService).

startAll(true)
local Guard = serverModule("GuardService")
local A = player("Alice", Vector3.new(60, 3, 10))
local B = player("Bob", Vector3.new(65, 3, 10))
flush()
local LMIN = luckValues()[1]
local STREET = Vector3.new(65, 3, 12) -- couloir, devant STORE_A, hors zone safe

local ended = {}
Carry.OnCarryEnded(function(p, payload, result, reason)
	table.insert(ended, { player = p, payload = payload, result = result, reason = reason })
end)
local function waitFor(fn, maxSeconds)
	local t = 0
	while not fn() and t < maxSeconds do
		advance(0.1)
		t += 0.1
	end
	return fn()
end
local function chasersOf(p)
	local n = 0
	for _, g in guards() do
		if g:GetAttribute("TargetUserId") == p.UserId then
			n += 1
		end
	end
	return n
end
local function fresh(store)
	check(waitFor(function()
		return #guards() == 0
	end, 60), "(banc) plus de vigile")
	for _, s in { STORE_A, STORE_B } do
		local w = s:FindFirstChild("Window")
		if w:GetAttribute("Broken") == true then
			WindowS.Rebuild(w:GetAttribute("WindowId"))
		end
	end
	flush()
	reopen(A, store)
end
local function take(store, n)
	local ok = openAndReveal(A, store, n, LMIN, { 1 }) ~= nil and takeItem(A, store, n)
	advance(0.1)
	return ok
end

section("D1 lâché avec G dans son magasin : il revole sur son rayon, rien au sol")
fresh(STORE_A)
check(take(STORE_A, 3), "D1 (banc) Alice prend l'objet du rayon 3")
local payload1 = Carry.GetPayload(A)
check(guardFor(A) ~= nil, "D1 (banc) un vigile sort pour elle")
local drops1 = #batDrops()
standAt(A, STORE_A, 3)
local dropId = Carry.Drop(A, nil, "Released")
flush()
local last = ended[#ended]
check(dropId == nil and #batDrops() == drops1, "D1a rien ne tombe au sol (Drop renvoie nil)")
check(not Carry.IsCarrying(A), "D1b Alice ne porte plus rien")
check(last and last.payload == payload1 and last.result == "Failed" and last.reason == "Released", `D1c fin du portage « Failed » (Released) (trouvé {last and last.result} {last and last.reason})`)
check(logCount("dans le magasin de l'objet", "PRINT", "server") >= 1, "D1d ligne dans la sortie")
advance(3)
check(itemAt(STORE_A, 3) ~= nil, "D1e l'objet est revenu sur son rayon 3")
check(Guard.GetLinkedGuard(payload1) == nil, "D1f plus lié à aucun vigile")
check(waitFor(function()
	return chasersOf(A) == 0
end, 5), "D1g le vigile ne poursuit plus Alice")
check(logCount("est tombé au sol, il va vers lui", "PRINT", "server") == 0, "D1h le vigile ne garde aucun objet")

section("D2 tombé d'un coup de batte dans son magasin : pareil")
fresh(STORE_A)
check(take(STORE_A, 2), "D2 (banc) Alice prend l'objet du rayon 2")
local payload2 = Carry.GetPayload(A)
local drops2 = #batDrops()
standAt(A, STORE_A, 2)
local root = A.Character:FindFirstChild("HumanoidRootPart")
dropId = Carry.Drop(A, root.Position - Vector3.new(0, 3, 0)) -- comme BatService : point du sol, raison « Bat »
flush()
last = ended[#ended]
check(dropId == nil and #batDrops() == drops2, "D2a coup de batte dans le magasin : rien au sol")
check(last and last.payload == payload2 and last.result == "Failed" and last.reason == "Bat", "D2b fin « Failed » (Bat)")
advance(3)
check(itemAt(STORE_A, 2) ~= nil, "D2c l'objet est revenu sur son rayon 2")

section("D3 lâché dans la rue : il tombe au sol, le vigile le garde (rien ne change)")
fresh(STORE_A)
check(take(STORE_A, 1), "D3 (banc) Alice prend l'objet du rayon 1")
local payload3 = Carry.GetPayload(A)
local drops3 = #batDrops()
local followBefore = logCount("est tombé au sol, il va vers lui", "PRINT", "server")
moveTo(A, STREET)
advance(0.1)
if Carry.IsCarrying(A) then
	dropId = Carry.Drop(A, nil, "Released")
	flush()
	local p3 = if dropId then Carry.GetDrop(dropId) else nil
	check(dropId ~= nil and #batDrops() == drops3 + 1 and p3 == payload3, "D3a dans la rue : l'objet est au sol")
	check(ended[#ended].result == "Dropped", "D3b fin « Dropped »")
	check(waitFor(function()
		return logCount("est tombé au sol, il va vers lui", "PRINT", "server") > followBefore
	end, 5), "D3c le vigile va garder l'objet tombé")
	check(itemAt(STORE_A, 1) == nil, "D3d le rayon 1 reste vide tant qu'il est au sol")
	advance(BatCfg.DroppedLifetime + 3)
	check(Carry.GetDrop(dropId) == nil and itemAt(STORE_A, 1) ~= nil, "D3e 15 s plus tard : revolé sur son rayon")
else
	check(false, "D3 (banc) Alice attrapée avant de lâcher dans la rue")
end

section("D4 objet d'un autre magasin lâché dans STORE_A : il tombe")
fresh(STORE_B)
check(take(STORE_B, 1), "D4 (banc) Alice prend un objet de STORE_B")
local payload4 = Carry.GetPayload(A)
local drops4 = #batDrops()
standAt(A, STORE_A, 4)
dropId = Carry.Drop(A, nil, "Released")
flush()
check(dropId ~= nil and #batDrops() == drops4 + 1 and Carry.GetDrop(dropId) == payload4, "D4a pas son magasin : au sol")

section("D5 objet volé à un joueur lâché : revient chez son propriétaire (rien ne change)")
check(waitFor(function()
	return #guards() == 0
end, 60), "D5 (banc) plus de vigile")
local stolen = { Kind = "PlayerItem", ItemUid = "uid-a127", ItemId = "Z1_CanetteDeSoda", Rarity = "Common", Income = 1, VictimUserId = B.UserId, SlotIndex = 1 }
check(Carry.StartCarry(A, stolen), "D5 (banc) Alice porte un objet volé")
flush()
standAt(A, STORE_A, 3)
dropId = Carry.Drop(A, nil, "Released")
flush()
check(dropId == nil and ended[#ended].payload == stolen and ended[#ended].result == "Failed", "D5a objet volé : Failed, comme avant")

check(logCount("contrôle « dans son magasin »", "WARN", "server") == 0, "D6 aucun échec du contrôle")
check(logCount("tick :", "WARN", "server") == 0, "D7 aucune erreur du tick")
summary("scénario drop")
