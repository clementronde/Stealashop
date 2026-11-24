--!nocheck
-- a251 : interrupteur coupé : ni plan, ni nouveau plafond.
startAll(true)
local Cfg = sharedModule("Config/Unbox")
local A = player("Alice", Vector3.new(60, 3, 10))
flush()
section("X interrupteur coupé")
check(Cfg.New.Enabled == false, "X0 Config/Unbox.New.Enabled = false")
reopen(A, STORE_A)
IW.kg, IW.scale, IW.size, IW.class = 12, 1.1, nil, "Small"
local _, ev = startReveal(A, STORE_A, 1, 3)
check(ev ~= nil and ev.args[11] == nil and type(ev.args[10]) == "string", "X1 RevealStarted sans plan")
advance(SO.Reveal.RevealMaxSeconds.Small - 0.5)
check(protected(A), "X2 encore en cinématique à 7,5 s")
advance(0.7)
check(not protected(A) and Carry.IsCarrying(A), "X3 finie au plafond d'avant (8 s), objet porté")
summary("scénario serveroff")
