--!nocheck
-- a259 (vague 75, L-262) : interrupteur Config/Unbox.New.RealOdds = false : la cote finale est tirée dans la plage de
-- la rareté gagnée, comme avant. Mise en place du banc a202.
startAll(true)
local Plan = sharedModule("UnboxPlan")
local Cfg = sharedModule("Config/Unbox")
local A = player("Alice", Vector3.new(60, 3, 10))
flush()
reopen(A, STORE_A)
IW.kg, IW.scale, IW.size, IW.class = 12, 1.1, nil, "Small"
local _, ev = startReveal(A, STORE_A, 1, 3)
local a = if ev then ev.args else {}
local plan = Plan.parse(a[11])
local range = Cfg.New.OddsRanges[a[5]]
check(Cfg.New.RealOdds == false and plan ~= nil and range ~= nil and plan.Odds >= range[1] and plan.Odds <= range[2], "R1 RealOdds = false : cote finale dans la plage de la rareté gagnée (" .. tostring(plan and plan.Odds) .. ", " .. tostring(a[5]) .. ")")
summary("scénario serverrange")
