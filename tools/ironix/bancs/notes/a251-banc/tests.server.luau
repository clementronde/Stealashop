--!nocheck
-- a251 (vague 73, L-236) : StoreHeistService tire le plan de la nouvelle ouverture et l'envoie dans RevealStarted ; le
-- plafond de la phase suit la durée du plan. Mise en place du banc a202.
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

section("V1 plan tiré par le serveur, envoyé à tous")
check(Cfg.New.Enabled == true, "V0 Config/Unbox.New.Enabled = true")
reopen(A, STORE_A)
IW.kg, IW.scale, IW.size, IW.class = 12, 1.1, nil, "Small"
local _, ev = startReveal(A, STORE_A, 1, 3)
local a = if ev then ev.args else {}
check(ev ~= nil and ev.to == nil and type(a[11]) == "string", "V1 RevealStarted à tous, 11e argument = le plan (" .. tostring(a[11]) .. ")")
local plan = Plan.parse(a[11])
check(plan ~= nil and #plan.Steps == Cfg.New.ActionCount and plan.Steps[#plan.Steps].Action.Id == Cfg.New.FinalAction, "V2 plan lisible : 5 actions, la masse en dernier")
check(plan ~= nil and plan.Steps[#plan.Steps].Rarity == a[5] and plan.Steps[1].Rarity == Cfg.New.StartRarity, "V3 la rareté montrée part de Common et finit sur la rareté gagnée (" .. tostring(a[5]) .. ")")
local range = Cfg.New.OddsRanges[a[5]]
check(plan ~= nil and range ~= nil and plan.Odds >= range[1] and plan.Odds <= range[2], "V4 cote finale dans la plage de la rareté gagnée")
check(a[7] == 12 and a[8] == 1.1 and a[9] == "Small" and type(a[10]) == "string", "V5 les 10 premiers arguments inchangés")
check(protected(A) and humanoidOf(A).WalkSpeed == 0, "V6 ouvreur protégé et immobile, comme avant")

section("V2 plafond de la phase : la durée la plus longue du plan, plus la marge")
local cap = Plan.serverMaxSeconds(a[5], "Small")
check(cap > SO.Reveal.RevealMaxSeconds.Small, string.format("V7 plafond %.1f s, plus long que les 8 s d'avant", cap))
advance(SO.Reveal.RevealMaxSeconds.Small + 1)
check(protected(A) and #endedFor(a[10]) == 0, "V8 encore en cinématique après les 8 s d'avant")
advance(cap - SO.Reveal.RevealMaxSeconds.Small - 1 - 0.5)
check(protected(A) and #endedFor(a[10]) == 0, "V9 encore en cinématique 0,5 s avant le plafond")
advance(0.8)
check(#endedFor(a[10]) == 1 and not protected(A) and Carry.IsCarrying(A), "V10 finie au plafond, objet porté")
consume(A)

section("V3 RevealDone finit la phase avant le plafond")
local _, ev2 = startReveal(A, STORE_A, 2, LMIN)
check(ev2 ~= nil and Plan.parse(ev2.args[11]) ~= nil, "V11 nouveau plan pour le colis suivant")
advance(9)
revealDone(A, if ev2 then ev2.args[10] else nil)
check(ev2 ~= nil and #endedFor(ev2.args[10]) == 1 and Carry.IsCarrying(A) and not protected(A), "V12 RevealDone de l'ouvreur à 9 s : fin, objet porté")
consume(A)

section("V4 gros objet : plafond de sa classe")
IW.kg, IW.scale, IW.size, IW.class = 500, 3, "Huge", "Large"
reopen(B, STORE_B)
local _, ev3 = startReveal(B, STORE_B, 5, LMIN)
local b = if ev3 then ev3.args else {}
check(ev3 ~= nil and b[9] == "Large" and Plan.parse(b[11]) ~= nil and STORE_B:GetAttribute("CeilingBroken") == true, "V13 Large : plan envoyé, CeilingBroken")
local capLarge = Plan.serverMaxSeconds(b[5], "Large")
advance(capLarge - 0.5)
check(protected(B), string.format("V14 encore en cinématique 0,5 s avant son plafond (%.1f s)", capLarge))
advance(0.8)
check(not protected(B) and Carry.IsCarrying(B), "V15 finie à son plafond, objet porté")

summary("scénario server")
