--!nocheck
-- Scénario « pick » (a88) : PickPotion validé par le serveur. Refusé : uid inconnu, potion d'un autre, trop
-- loin, déjà prise, expirée, joueur mort, sans personnage. Accepté : PotionRemoved, attribut Potion_<Id>,
-- Notify « Success » en anglais, télémétrie PotionPicked ; potion d'un tirage normal ramassée sur la rue.
startPotions()
local ada = join("Ada", newProfile())
local bob = join("Bob", newProfile())
local P = POTIONS_CFG

local function nothingFor(player, label, nRemoved, nNotify)
	check(#removedTo(player) == nRemoved and #notifies(player) == nNotify and attr(player, "Speed") == nil, `{label} : ni PotionRemoved, ni message, ni effet`)
end

section("refus")
local uid, position = spawnNear(ada, "Speed")
check(uid ~= nil and position ~= nil, `crochet spawn : potion {uid} devant Ada`)
check(position and math.abs(position.Y) < 1e-3, "posée au sol (rayon vers le bas)")
local r0, n0 = #removedTo(ada), #notifies(ada)
pick(ada, "P999")
nothingFor(ada, "uid inconnu", r0, n0)
check(logHas("potion inconnue", "WARN", "server"), "uid inconnu : une ligne en Studio")
moveTo(bob, position + Vector3.new(0, 3, 0))
pick(bob, uid)
nothingFor(ada, "Bob prend la potion d'Ada", r0, n0)
check(#removedTo(bob) == 0 and bob:GetAttribute("Potion_Speed") == nil, "Bob : rien non plus")
moveTo(ada, position + Vector3.new(P.PickupMaxDistance + 2, 3, 0))
pick(ada, uid)
nothingFor(ada, "trop loin", r0, n0)
check(logHas("trop loin", "WARN", "server"), "trop loin : une ligne en Studio")

section("accepté")
moveTo(ada, position + Vector3.new(P.PickupMaxDistance - 4, 3, 0))
local t = serverNow()
pick(ada, uid)
local removed = removedTo(ada)
check(#removed == r0 + 1 and removed[#removed].args[1] == uid, `PotionRemoved({uid}) à Ada`)
-- a111 (vague 33) : la potion va dans l'inventaire, l'effet attend UsePotion.
check(attr(ada, "Speed") == nil and stock(ada, "Speed") == 1, `ramassée : pas d'effet, PotionStock_Speed = 1 (trouvé {stock(ada, "Speed")})`)
local msg, kind = lastNotify(ada)
check(msg == "Speed potion added to your inventory!" and kind == "Success", `message : « {msg} » ({kind})`)
local ev0 = TELEMETRY[#TELEMETRY]
use(ada, "Speed")
local endsAt = attr(ada, "Speed")
check(endsAt and math.abs(endsAt - t - 120) < 0.5, `bue : attribut Potion_Speed = heure serveur + 120 s (trouvé {endsAt and endsAt - t})`)
check(stock(ada, "Speed") == 0 and TELEMETRY[#TELEMETRY] == ev0, "bue : stock 0, pas de télémétrie de plus")
msg, kind = lastNotify(ada)
check(msg == "Speed ×2 for 2:00!" and kind == "Success", `message : « {msg} » ({kind})`)
local ev = TELEMETRY[#TELEMETRY]
check(ev and ev.what == "event" and ev.key == "PotionPicked" and ev.player == ada and ev.fields[1] == "Potion - Speed", "télémétrie : PotionPicked, Potion - Speed")
local n1, r1, tele = #notifies(ada), #removedTo(ada), #TELEMETRY
pick(ada, uid)
check(#notifies(ada) == n1 and #removedTo(ada) == r1 and attr(ada, "Speed") == endsAt and #TELEMETRY == tele, "déjà prise : rien ne change")

section("expirée, mort, sans personnage")
local uid2, pos2 = spawnNear(ada, "Money")
moveTo(ada, Vector3.new(0, 3, 0))
advance(P.Lifetime + 0.5, 0.25)
moveTo(ada, pos2 + Vector3.new(0, 3, 0))
local r2 = #removedTo(ada)
check(livePotions(ada)[uid2] == nil, "expirée : PotionRemoved envoyé à l'expiration")
pick(ada, uid2)
check(attr(ada, "Money") == nil and #removedTo(ada) == r2, "expirée : ramassage refusé, pas d'effet")
local uid3, pos3 = spawnNear(ada, "Strength")
moveTo(ada, pos3 + Vector3.new(0, 3, 0))
kill(ada)
advance(0.1)
pick(ada, uid3)
check(attr(ada, "Strength") == nil and livePotions(ada)[uid3] ~= nil, "mort : refusé, la potion reste")
check(logHas("pas de personnage vivant", "WARN", "server"), "mort : une ligne en Studio")
ada.Character:Destroy()
ada.Character = nil
pick(ada, uid3)
check(attr(ada, "Strength") == nil and livePotions(ada)[uid3] ~= nil, "sans personnage : refusé")
spawnCharacter(ada, pos3 + Vector3.new(0, 3, 0))
advance(0.5) -- PlotService le pose chez lui
moveTo(ada, pos3 + Vector3.new(0, 3, 0))
pick(ada, uid3)
check(stock(ada, "Strength") == 1 and livePotions(ada)[uid3] == nil, "réapparu près d'elle : ramassée (dans l'inventaire)")

section("tirage normal, sur la rue")
test("Bob clear")
local before = #spawnedTo(bob)
local w = waitSpawn(bob, P.SpawnEvery + 5)
local buid, bid, bpos = lastSpawned(bob)
check(w and #spawnedTo(bob) == before + 1, `potion de Bob apparue ({bid})`)
moveTo(bob, bpos + Vector3.new(1, 3, 1))
pick(bob, buid)
local name = P.ById[bid].DisplayName
check(stock(bob, bid) == 1 and livePotions(bob)[buid] == nil, `Bob ramasse sa {bid} (dans l'inventaire)`)
local bmsg = lastNotify(bob)
check(bmsg == `{name} potion added to your inventory!`, `message : « {bmsg} »`)
use(bob, bid)
bmsg = lastNotify(bob)
check(bob:GetAttribute("Potion_" .. bid) ~= nil and bmsg and string.find(bmsg, name, 1, true) == 1 and string.sub(bmsg, -1) == "!", `bue : effet et message « {bmsg} »`)

section("envois en rafale")
local uid4, pos4 = spawnNear(bob, "Money")
moveTo(bob, pos4 + Vector3.new(0, 3, 0))
local nb = #notifies(bob)
for _ = 1, 10 do
	fireAs(bob, "PickPotion", "P999")
end
advance(0.3)
check(livePotions(bob)[uid4] ~= nil and #notifies(bob) == nb, "10 uid inconnus d'un coup : rien ne change")
advance(1.5)
pick(bob, uid4)
check(livePotions(bob)[uid4] == nil, "ensuite, le vrai ramassage passe")
finish("scénario pick")
