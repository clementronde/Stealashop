--!nocheck
-- a257 (vague 74, L-253) : copie du banc serveur d'a251 corrigée (nombre d'actions selon le résultat, rareté montrée
-- qui part du colis, plafond du plan tiré, jamais sous celui d'avant). a251 (vague 73, L-236) : StoreHeistService tire
-- le plan de la nouvelle ouverture et l'envoie dans RevealStarted. Mise en place du banc a202.
startAll(true)
local Plan = sharedModule("UnboxPlan")
local Cfg = sharedModule("Config/Unbox")
local Rarities = sharedModule("Config/Rarities")
local A = player("Alice", Vector3.new(60, 3, 10))
local B = player("Bob", Vector3.new(66, 3, 10))
flush()
local LMIN = luckValues()[1]
local function noGuard(p)
	return waitFor(function()
		return guardFor(p) == nil
	end, 60)
end
local function consume(p)
	Carry.Consume(p)
	flush()
	noGuard(p)
end
local function ups(pl)
	local n = 0
	for i = 2, #pl.Steps do
		if pl.Steps[i].Rarity ~= pl.Steps[i - 1].Rarity then
			n += 1
		end
	end
	return n
end
local function capOf(rarity, class, pl)
	local before = SO.Reveal.RevealMaxSeconds[class] or SO.Reveal.DefaultMaxSeconds
	return math.max(before, Plan.serverMaxSeconds(rarity, class, if pl then #pl.Steps else nil))
end

section("V1 plan tiré par le serveur, envoyé à tous")
check(Cfg.New.Enabled == true, "V0 Config/Unbox.New.Enabled = true")
reopen(A, STORE_A)
IW.kg, IW.scale, IW.size, IW.class = 12, 1.1, nil, "Small"
local _, ev = startReveal(A, STORE_A, 1, 3)
local a = if ev then ev.args else {}
check(ev ~= nil and ev.to == nil and type(a[11]) == "string", "V1 RevealStarted à tous, 11e argument = le plan (" .. tostring(a[11]) .. ")")
local plan = Plan.parse(a[11])
check(plan ~= nil and #plan.Steps == Plan.count(a[5], ups(plan)) and plan.Steps[#plan.Steps].Action.Id == Cfg.New.FinalAction, "V2 plan lisible : Plan.count actions (" .. tostring(plan and #plan.Steps) .. "), la masse en dernier")
check(plan ~= nil and Rarities.ById[plan.Steps[1].Rarity] ~= nil and ups(plan) <= Cfg.UpgradeMax, "V3 la rareté montrée part de celle du colis (" .. tostring(plan and plan.Steps[1].Rarity) .. ") et monte d'UpgradeMax crans au plus")
local range = Cfg.New.OddsRanges[a[5]]
check(plan ~= nil and range ~= nil and plan.Odds >= range[1] and plan.Odds <= range[2], "V4 cote finale dans la plage de la rareté gagnée")
check(a[7] == 12 and a[8] == 1.1 and a[9] == "Small" and type(a[10]) == "string", "V5 les 10 premiers arguments inchangés")
check(protected(A) and humanoidOf(A).WalkSpeed == 0, "V6 ouvreur protégé et immobile, comme avant")

section("V2 plafond de la phase : la durée la plus longue du plan tiré, plus la marge")
local cap = capOf(a[5], "Small", plan)
check(cap >= SO.Reveal.RevealMaxSeconds.Small, string.format("V7 plafond %.1f s : celui du plan tiré, jamais sous les 8 s d'avant", cap))
advance(cap - 0.5)
check(protected(A) and #endedFor(a[10]) == 0, "V9 encore en cinématique 0,5 s avant le plafond")
advance(0.8)
check(#endedFor(a[10]) == 1 and not protected(A) and Carry.IsCarrying(A), "V10 finie au plafond, objet porté")
consume(A)

section("V3 RevealDone finit la phase avant le plafond")
local _, ev2 = startReveal(A, STORE_A, 2, LMIN)
local plan2 = if ev2 then Plan.parse(ev2.args[11]) else nil
check(plan2 ~= nil, "V11 nouveau plan pour le colis suivant")
local cap2 = capOf(if ev2 then ev2.args[5] else "Common", "Small", plan2)
advance(math.min(9, cap2 - 1))
revealDone(A, if ev2 then ev2.args[10] else nil)
check(ev2 ~= nil and #endedFor(ev2.args[10]) == 1 and Carry.IsCarrying(A) and not protected(A), "V12 RevealDone de l'ouvreur avant le plafond : fin, objet porté")
consume(A)

section("V4 gros objet : plafond de sa classe")
IW.kg, IW.scale, IW.size, IW.class = 500, 3, "Huge", "Large"
reopen(B, STORE_B)
local _, ev3 = startReveal(B, STORE_B, 5, LMIN)
local b = if ev3 then ev3.args else {}
local planB = Plan.parse(b[11])
check(ev3 ~= nil and b[9] == "Large" and planB ~= nil and STORE_B:GetAttribute("CeilingBroken") == true, "V13 Large : plan envoyé, CeilingBroken")
local capLarge = capOf(b[5], "Large", planB)
advance(capLarge - 0.5)
check(protected(B), string.format("V14 encore en cinématique 0,5 s avant son plafond (%.1f s)", capLarge))
advance(0.8)
check(not protected(B) and Carry.IsCarrying(B), "V15 finie à son plafond, objet porté")

summary("scénario server")
