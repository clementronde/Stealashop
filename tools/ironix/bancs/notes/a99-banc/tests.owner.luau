--!nocheck
-- Scénario « owner » (a99, décision de Cantin du 2026-11-12) : vrais PvPService et BatService, faux Roblox
-- du banc a32 (copie a37 ; boutiques dans un volume SafeZone). Plus aucune protection des boutiques ; le
-- propriétaire frappe un intrus mains vides dans sa boutique en zone safe : sortie, 60 s sans voler CETTE
-- boutique (porte, prise, retour refusés), les autres boutiques restent ouvertes ; coup d'un tiers sans effet
-- de règle ; angle ; voleur frappé dehors avec l'objet ; fin des 60 s ; mort dans une boutique ; départ du
-- propriétaire.

startServer()
local PvP = sharedModule("Config/PvP")
local Bot = sharedModule("Config/Bot")

local adaData = victimProfile()
local ada = join("Ada", adaData)
local bobData = newProfile()
local bob = join("Bob", bobData)
local cyData = newProfile()
addItem(cyData, "cy-soda", "Z1_CanetteDeSoda", 1)
addItem(cyData, "cy-chips", "Z1_PaquetDeChips", 2)
addItem(cyData, "cy-noodles", "Z1_PotDeNouilles", 3)
local cy = join("Cy", cyData)
local danData = newProfile()
local dan = join("Dan", danData)
for _, player in { ada, bob, cy, dan } do
	giveBat(player)
end
advance(1.2)
local adaShop, cyShop = shopOf(ada), shopOf(cy)
local A = refsOfShop(adaShop)
local ADA_INDEX = adaShop:GetAttribute("PlotIndex")
local COOLDOWN_NAME = "RobCooldown_" .. tostring(ADA_INDEX)
local hits = {}
BatService.OnHit(function(hitter, target, usage, payload)
	table.insert(hits, { hitter = hitter, target = target, usage = usage, payload = payload })
end)

-- Dans le volume Bounds de la boutique `plot` ?
local function inShop(player, plot)
	local bounds = plot:FindFirstChild("Bounds", true)
	local p = bounds.CFrame:PointToObjectSpace(rootOf(player).Position)
	local h = bounds.Size / 2
	return math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z
end
local function inSafeZone(player)
	local p = SAFE_ZONE.CFrame:PointToObjectSpace(rootOf(player).Position)
	local h = SAFE_ZONE.Size / 2
	return math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z
end
-- `hitter` se place `distance` studs derrière `target` (vers +Z), regard `look` (vers −Z par défaut), et frappe.
local function swingAt(hitter, target, distance, look)
	local pos = rootOf(target).Position
	moveTo(hitter, pos + Vector3.new(0, 0, distance or 4), look or Vector3.new(0, 0, -1))
	if not holdsBat(hitter) then
		humanoidOf(hitter):EquipTool(batOf(hitter))
	end
	fireAs(hitter, "SwingBat")
	flush()
end
local function serverNow()
	return Workspace:GetServerTimeNow()
end
-- Attend la reconstruction de la porte d'Ada (30 s au plus).
local function waitDoor(plot)
	local id = windowIdOf(plot)
	local waited = 0
	while WindowService.IsBroken(id) and waited < 40 do
		advance(0.5)
		waited += 0.5
	end
end

section("plus aucune protection des boutiques")
check(PvP.KickRobCooldown == 60, `PvP.KickRobCooldown = 60 (trouvé {PvP.KickRobCooldown})`)
check(PvP.TheftImmunityDuration == nil and PvP.AntiRacketRatio == nil, "PvP : TheftImmunityDuration et AntiRacketRatio retirés")
check(PvP.BeginnerShieldDuration ~= nil, "PvP.BeginnerShieldDuration reste (bouclier du colis PNJ)")
check(Bot.TheftImmunity == nil, "Bot.TheftImmunity retiré")
check(PvPService.GetProtection == nil and type(PvPService.GetRobCooldown) == "function", "API : GetProtection retirée, GetRobCooldown ajoutée")
SHIELDED[ada] = true -- Ada débutante
advance(0.6)
check(adaShop:GetAttribute("Protection") == nil and adaShop:GetAttribute("ProtectedUntil") == nil, "aucun attribut Protection ni ProtectedUntil")
check(breakDoor(bob, adaShop), "Bob casse la porte d'une débutante")
check(#notifies(bob, "protected") == 0 and #notifies(bob, "too small") == 0, "aucun message de protection")
SHIELDED[ada] = nil

section("coup du propriétaire sur un intrus mains vides, en zone safe")
moveTo(bob, A.center, Vector3.new(0, 0, -1))
advance(0.2)
check(inShop(bob, adaShop) and inSafeZone(bob), "Bob, mains vides, est dans la boutique d'Ada (zone safe)")
check(not CarryService.IsCarrying(bob), "Bob ne porte rien")
local adaNotices = #notifies(ada, "kicked out of your shop")
swingAt(ada, bob, 4)
local hit = hits[#hits]
check(#hits == 1 and hit.hitter == ada and hit.target == bob and hit.usage == "Intruder" and hit.payload == nil, `BatService : coup « Intruder » d'Ada sur Bob, sans payload (trouvé {hit and hit.usage})`)
advance(0.1)
check(not inShop(bob, adaShop), "Bob est sorti devant la porte")
check(bob:GetAttribute("BatStun") == "Stun", "Bob est étourdi (Stunned)")
local left = PvPService.GetRobCooldown(bob, adaShop)
check(left > 59 and left <= 60, `Bob ne peut plus voler Ada pendant 60 s (reste {left})`)
local endsAt = bob:GetAttribute(COOLDOWN_NAME)
check(type(endsAt) == "number" and near(endsAt - serverNow(), 60, 0.5), `attribut {COOLDOWN_NAME} = fin en heure serveur (dans {endsAt and endsAt - serverNow()} s)`)
check(#notifies(bob, "Kicked out! You can rob this shop again in 60s.") == 1, "Notify à Bob : Kicked out!")
check(#notifies(ada, "Bob was kicked out of your shop!") == adaNotices + 1, "Notify à Ada : retour court")
check(PvPService.GetRobCooldown(bob, cyShop) == 0 and bob:GetAttribute("RobCooldown_" .. tostring(cyShop:GetAttribute("PlotIndex"))) == nil, "rien sur la boutique de Cy")

section("retour refusé pendant 60 s")
advance(1.6) -- fin de l'étourdissement
moveTo(bob, A.center)
advance(0.2)
check(not inShop(bob, adaShop), "porte cassée, mais Bob est ressorti (10 fois par seconde)")
check(#notifies(bob, "You can rob this shop again in") >= 1, "message de refus à Bob")
check(not steal(bob, adaShop, 1), "StealItem de Bob refusé")
check(adaData.Display["1"] == "v-soda", "la Canette reste à Ada")
local before = #notifies(bob, "You can rob this shop again in")
advance(3.1)
moveTo(bob, A.center)
advance(0.2)
check(#notifies(bob, "You can rob this shop again in") <= before + 1, "au plus un message toutes les 3 s")
waitDoor(adaShop)
local broke, tries = breakDoor(bob, adaShop, 15)
check(not broke, `coups de Bob sur la porte d'Ada refusés ({tries} essais)`)
check(#remotes("WindowHit", function(e)
	return e.args[1] == windowIdOf(adaShop) and e.t > now() - 1.5
end) == 0, "aucun dégât sur la porte d'Ada")

section("les autres boutiques restent ouvertes")
check(breakDoor(bob, cyShop), "Bob casse la porte de Cy")
check(steal(bob, cyShop, 1), "Bob prend chez Cy")
CarryService.Fail(bob, "Bat")
flush()
check(cyData.Display["1"] == "cy-soda", "l'objet revient chez Cy")
moveTo(bob, HUB_CENTER)

section("coup d'un tiers sans effet de règle")
check(breakDoor(dan, adaShop), "Dan casse la porte d'Ada")
moveTo(dan, A.center + Vector3.new(6, 0, 0), Vector3.new(0, 0, -1))
advance(0.2)
check(inShop(dan, adaShop), "Dan est dans la boutique d'Ada")
local count = #hits
swingAt(cy, dan, 4)
check(#hits == count, "Cy (pas propriétaire) frappe Dan mains vides : aucun coup")
check(inShop(dan, adaShop) and PvPService.GetRobCooldown(dan, adaShop) == 0, "Dan reste dedans, sans interdiction")
moveTo(cy, HUB_CENTER) -- sinon Cy, dans la boutique d'Ada, serait lui aussi un intrus

section("angle et portée : mêmes règles que les autres coups")
advance(0.9)
swingAt(ada, dan, 5, Vector3.new(0, 0, 1)) -- Ada tourne le dos à Dan
check(#hits == count, "dos tourné : aucun coup")
advance(0.9)
swingAt(ada, dan, 9)
check(#hits == count, "à 9 studs (portée 7) : aucun coup")
advance(0.9)
swingAt(ada, dan, 4)
check(#hits == count + 1 and hits[#hits].usage == "Intruder" and hits[#hits].target == dan, "de face, à 4 studs : coup « Intruder »")
advance(0.1)
check(not inShop(dan, adaShop) and PvPService.GetRobCooldown(dan, adaShop) > 59, "Dan sorti, 60 s sans voler Ada")

section("voleur frappé dehors avec l'objet du propriétaire (usage 1)")
waitDoor(adaShop)
check(breakDoor(cy, adaShop), "Cy casse la porte d'Ada")
check(steal(cy, adaShop, 2), "Cy prend le Paquet de chips")
walkTo(cy, A.outside + Vector3.new(0, 0, -6), 40)
check(not inShop(cy, adaShop), "Cy est dehors")
local cyKicks = #notifies(cy, "Kicked out!")
moveTo(ada, A.outside)
advance(0.9)
swingAt(ada, cy, 4)
check(hits[#hits].usage == "Defend" and hits[#hits].target == cy, "coup « Defend » d'Ada sur Cy")
check(not CarryService.IsCarrying(cy) and adaData.Display["2"] == "v-chips", "l'objet revient sur son présentoir")
check(PvPService.GetRobCooldown(cy, adaShop) > 59, "Cy ne peut plus voler Ada pendant 60 s")
check(#notifies(cy, "Kicked out!") == cyKicks and #notifies(cy, "You can rob this shop again in 60s.") >= 1, "Cy, déjà dehors : pas de « Kicked out! », mais le délai")

section("fin des 60 s de Bob")
local waitBob = PvPService.GetRobCooldown(bob, adaShop)
advance(waitBob + 0.6, 0.5)
check(PvPService.GetRobCooldown(bob, adaShop) == 0, "interdiction de Bob finie")
check(bob:GetAttribute(COOLDOWN_NAME) == nil, `attribut {COOLDOWN_NAME} retiré`)
waitDoor(adaShop)
check(breakDoor(bob, adaShop), "Bob casse de nouveau la porte d'Ada")
moveTo(bob, A.center)
advance(0.3)
check(inShop(bob, adaShop), "Bob peut rester dans la boutique ouverte")
check(steal(bob, adaShop, 4), "Bob prend le Donut")
CarryService.Fail(bob, "Bat")
flush()

section("mort dans une boutique")
moveTo(bob, A.center)
advance(0.2)
check(inShop(bob, adaShop), "Bob dans la boutique d'Ada")
kill(bob)
flush()
check(PvPService.GetRobCooldown(bob, adaShop) > 59, "mort dans la boutique d'Ada : 60 s sans la voler")
check(#notifies(bob, "Eliminated! You can rob this shop again in 60s.") == 1, "Notify Eliminated à Bob")
spawnCharacter(bob, HUB_CENTER)
advance(0.3)
check(PvPService.GetRobCooldown(bob, adaShop) > 58, "toujours interdit après la réapparition")
moveTo(ada, A.center)
kill(ada)
flush()
check(PvPService.GetRobCooldown(ada, adaShop) == 0, "Ada morte chez elle : aucune interdiction")
spawnCharacter(ada, A.center)
local danBefore = 0
for name in dan:GetAttributes() do
	if string.sub(name, 1, 12) == "RobCooldown_" then
		danBefore += 1
	end
end
moveTo(dan, HUB_CENTER)
kill(dan)
flush()
local danAfter = 0
for name in dan:GetAttributes() do
	if string.sub(name, 1, 12) == "RobCooldown_" then
		danAfter += 1
	end
end
check(danAfter == danBefore, "mort hors des boutiques : aucune interdiction de plus")
spawnCharacter(dan, HUB_CENTER)
advance(0.3)

section("départ du propriétaire")
check(cy:GetAttribute(COOLDOWN_NAME) ~= nil and bob:GetAttribute(COOLDOWN_NAME) ~= nil, "Cy et Bob ont une interdiction sur la boutique d'Ada")
leave(ada)
flush()
check(cy:GetAttribute(COOLDOWN_NAME) == nil and bob:GetAttribute(COOLDOWN_NAME) == nil and dan:GetAttribute(COOLDOWN_NAME) == nil, "Ada partie : les interdictions sur sa boutique tombent")
check(PvPService.GetRobCooldown(cy, adaShop) == 0, "GetRobCooldown = 0")

section("sortie")
check(not logHas("tick :", "WARN"), "aucune erreur dans les boucles des services")
check(not logHas("mal formé", "WARN"), "aucun envoi de remote mal formé")
check(not logHas("IsIntruder", "WARN"), "aucune erreur dans IsIntruder")
if VERBOSE then
	dumpLog()
end
summary("scénario owner")
