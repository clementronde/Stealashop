-- a305 (22/11, Cantin 2026-11-21 : Balance.Heist.Duration de 6 à 10 s) : copie de a135-banc/tests.heist.luau ; P0a attend 10 ; les libellés de P2, P3 disent 10 s ; tout le reste lisait déjà DUR. Original inchangé.
-- Vague 40 (2026-11-14, fusion) : P0b attend BreakTimer = 8 (décision de Cantin, passe 3) ; P1b et P4a lisaient déjà BreakTimer, seuls leurs libellés changent. Ancien : tests.heist.avant-vague40.luau.
--!nocheck
-- a135 P. Chrono de police et braquage de 6 s (Cantin, 2026-11-14, vague 40 ; Features.ShelfOpen, sans
-- WitnessService) : au premier coup, HeistTimer(id, premier coup + BreakTimer, police = true) à chaque joueur qui
-- frappe ; cassée : 0 puis HeistTimer(id, casse + Heist.Duration) sans police ; fin du chrono « HEIST » à la casse
-- + 6 s (plus à la fin du chrono de police) ; pas cassée à temps : la vitre revient à ses PV max, « Too slow! »,
-- chrono masqué (comportement d'avant, gardé).

startAll(true)
local Tool = serverModule("ToolService")
local A = player("Alice", Vector3.new(60, 3, 10))
local B = player("Bob", Vector3.new(65, 3, 10))
local C = player("Chloe", Vector3.new(70, 3, -10))
flush()
local OFFSET = SERVER_TIME_OFFSET
local BREAK = Balance.Window.BreakTimer
local DUR = Balance.Heist.Duration

local function timersOf(p, since)
	return remotes("HeistTimer", function(e)
		return e.to == p and e.t >= since - 1e-9
	end)
end
local function standAtWindow(p, store, dx)
	local window = store:FindFirstChild("Window")
	equipCasse(p)
	local pos = window.Position
	local side = if pos.Z > 0 then -1 else 1
	moveTo(p, Vector3.new(pos.X + (dx or 0), 3, pos.Z + side * 3), Vector3.new(0, 0, -side))
	return window:GetAttribute("WindowId")
end

section("P0 valeurs")
check(DUR == 10, "P0a Balance.Heist.Duration = 10 (Cantin 2026-11-21 : 6 → 10 s)")
check(BREAK == 8, "P0b Balance.Window.BreakTimer = 8 (chrono de police, Cantin 2026-11-14 ; était 13)")

-- Dégâts réglés pour casser STORE_A au 4e coup.
local winA = STORE_A:FindFirstChild("Window")
local maxHP = winA:GetAttribute("MaxHP")
local dmg = Tool.GetHitDamage(A)
check(type(maxHP) == "number" and maxHP > 0 and dmg > 0, "P0c (banc) PV max et dégâts lus")
local mult = maxHP / (4 * dmg) * 1.15 -- 3 coups ne cassent pas (régénération comprise), le 4e oui
WindowS.GetHitDamageMultiplier = function()
	return mult
end

section("P1 premier coup : chrono de police chez chaque joueur qui frappe")
local idA = standAtWindow(A, STORE_A, -3)
standAtWindow(B, STORE_A, 3)
local t0 = now()
fireAs(A, "HitWindow", idA)
flush()
local a1 = timersOf(A, t0)
check(#a1 == 1, "P1a un HeistTimer pour Alice au premier coup")
local e1 = a1[1]
check(e1 ~= nil and e1.args[1] == idA and near(e1.args[2], t0 + OFFSET + BREAK, 1e-3), "P1b fin = premier coup + BreakTimer (8 s)")
check(e1 ~= nil and e1.args[3] == true, "P1c police = true")
advance(0.4)
fireAs(B, "HitWindow", idA)
flush()
local b1 = timersOf(B, t0)
check(#b1 == 1 and b1[1].args[3] == true and near(b1[1].args[2], e1.args[2], 1e-3), "P1d Bob frappe : même chrono de police (même fin, police = true)")
advance(0.4)
fireAs(A, "HitWindow", idA)
flush()
check(#timersOf(A, t0) == 1, "P1e coup suivant d'Alice : pas de nouvel envoi")
check(STORE_A:GetAttribute("HeistOpen") ~= true, "P1f (banc) pas encore cassée après 3 coups")

section("P2 casse : chrono de police masqué, chrono HEIST de 10 s à partir de la casse")
advance(0.4)
local tb = now()
fireAs(A, "HitWindow", idA)
flush()
advance(0.05)
check(STORE_A:GetAttribute("HeistOpen") == true, "P2a (banc) cassée au 4e coup, magasin ouvert")
local a2 = timersOf(A, tb)
check(#a2 >= 2 and a2[1].args[2] == 0, "P2b Alice : 0 (chrono de police masqué) d'abord")
local last = a2[#a2]
check(last ~= nil and last.args[2] > 0 and last.args[3] == nil, "P2c puis un chrono sans police (HEIST)")
check(last ~= nil and near(last.args[2], tb + OFFSET + DUR, 0.06), "P2d fin = casse + 10 s")
check(last ~= nil and not near(last.args[2], e1.args[2], 0.5), "P2e plus la fin du chrono de police")
local b2 = timersOf(B, tb)
check(#b2 >= 1 and b2[1].args[2] == 0, "P2f Bob : chrono de police masqué")
local bl = b2[#b2]
check(bl ~= nil and bl.args[2] > 0 and bl.args[3] == nil and near(bl.args[2], last.args[2], 1e-3), "P2g Bob (proche) : le même chrono HEIST")

section("P3 fin du chrono HEIST à la casse + 10 s")
advance(DUR - 0.2)
local hid = timersOf(A, tb + 0.06)
local hiddenEarly = false
for _, e in hid do
	if e.args[2] == 0 then
		hiddenEarly = true
	end
end
check(not hiddenEarly, "P3a encore affiché à 9,8 s")
advance(0.4)
local hiddenAt = nil
for _, e in timersOf(A, tb + 0.06) do
	if e.args[2] == 0 then
		hiddenAt = e.t
	end
end
check(hiddenAt ~= nil and hiddenAt >= tb + DUR - 0.1 and hiddenAt <= tb + DUR + 0.25, "P3b masqué à la fin des 10 s (chronoEnd)")

section("P4 pas cassée à temps : la vitre revient à ses PV max (comportement gardé)")
WindowS.GetHitDamageMultiplier = function()
	return 1e-6
end
local winB = STORE_B:FindFirstChild("Window")
local idB = standAtWindow(C, STORE_B, 0)
local t4 = now()
fireAs(C, "HitWindow", idB)
flush()
local c1 = timersOf(C, t4)
check(#c1 == 1 and c1[1].args[3] == true and near(c1[1].args[2], t4 + OFFSET + BREAK, 1e-3), "P4a Chloé : chrono de police de BreakTimer (8 s)")
advance(BREAK + 0.3)
local c2 = timersOf(C, t4 + 0.01)
check(#c2 >= 1 and c2[#c2].args[2] == 0, "P4b à 13 s : chrono masqué")
check(#notifies("Too slow!", C) >= 1, "P4c message « Too slow! » à Chloé")
check(STORE_B:GetAttribute("HeistOpen") ~= true, "P4d le magasin n'ouvre pas")
local hpEvents = remotes("WindowHP", function(e)
	return e.args[1] == idB and e.t >= t4 + BREAK - 0.01
end)
local lastHp = hpEvents[#hpEvents]
check(lastHp ~= nil and near(lastHp.args[2], lastHp.args[3], 1e-6), "P4e PV de la vitre revenus au max")

summary("scénario heist")
