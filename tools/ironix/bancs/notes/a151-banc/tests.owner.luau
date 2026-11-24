--!nocheck
-- Scénario « owner » (a151, vague 43, Cantin 2026-11-14) : vrais PvPService, BatService, WindowService… sur le faux
-- Roblox du banc a32 (copie a37). La porte d'une boutique (PlotDoor/Window) se reconstruit à ses PV max dès que le
-- propriétaire a éjecté le dernier intrus ; s'il en reste un, elle attend qu'il sorte ou soit éjecté.

startServer()
local adaData = victimProfile()
local ada = join("Ada", adaData)
local players = {}
for _, name in { "Bob", "Cy", "Dan", "Eve" } do -- 5 boutiques dans le faux hub
	players[name] = join(name, newProfile())
end
local bob, cy, dan, eve = players.Bob, players.Cy, players.Dan, players.Eve
for _, player in { ada, bob, cy, dan, eve } do
	giveBat(player)
end
advance(1.2)
local adaShop = shopOf(ada)
local A = refsOfShop(adaShop)
local doorId = windowIdOf(adaShop)
local hits = {}
BatService.OnHit(function(hitter, target, usage)
	table.insert(hits, { hitter = hitter, target = target, usage = usage })
end)

local function inShop(player)
	local bounds = adaShop:FindFirstChild("Bounds", true)
	local p = bounds.CFrame:PointToObjectSpace(rootOf(player).Position)
	local h = bounds.Size / 2
	return math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z
end
local function broken()
	return WindowService.IsBroken(doorId)
end
local function doorObject()
	return adaShop:FindFirstChild("PlotDoor"):FindFirstChild("Window")
end
-- Ada se place 4 studs derrière `target` (vers +Z, plus loin dans sa boutique), regard vers −Z, et frappe.
local function swingAt(target)
	moveTo(ada, rootOf(target).Position + Vector3.new(0, 0, 4), Vector3.new(0, 0, -1))
	if not holdsBat(ada) then
		humanoidOf(ada):EquipTool(batOf(ada))
	end
	fireAs(ada, "SwingBat")
	flush()
end
-- Hors du cône de la batte d'Ada (derrière elle), dans la boutique.
local BESIDE = Vector3.new(14, 0, 14)

section("un intrus éjecté, un autre encore dedans : la porte attend")
check(breakDoor(bob, adaShop), "Bob casse la porte d'Ada")
moveTo(bob, A.center, Vector3.new(0, 0, -1))
moveTo(cy, A.center + BESIDE, Vector3.new(0, 0, -1))
advance(0.2)
check(inShop(bob) and inShop(cy), "Bob et Cy sont dans la boutique d'Ada")
clearLog()
swingAt(bob)
check(#hits == 1 and hits[1].target == bob and hits[1].usage == "Intruder", "coup « Intruder » d'Ada sur Bob")
check(not inShop(bob) and #notifies(bob, "Kicked out!") == 1, "Bob est sorti (Kicked out!)")
check(broken(), "Cy est encore dedans : la porte reste cassée")
check(adaShop:GetAttribute("StealOpen") == true, "la boutique reste ouverte au vol")
advance(2)
check(broken() and inShop(cy), "2 s plus tard : elle attend toujours (Cy dedans)")

section("le dernier intrus sort à pied : porte réparée tout de suite")
moveTo(cy, A.outside, Vector3.new(0, 0, -1))
advance(0.25)
check(not inShop(cy), "Cy est sorti de lui-même")
check(not broken(), "plus aucun intrus : la porte se reconstruit")
check(doorObject():GetAttribute("Broken") == false and (doorObject():GetAttribute("MaxHP") or 0) > 0, "attributs : Broken = false, PV max posés")
check(adaShop:GetAttribute("StealOpen") == nil, "la fenêtre de vol se ferme (OnRebuilt)")
check(logHas("porte reconstruite, plus aucun intrus après l'éjection", "PRINT", "server"), "sortie : porte reconstruite après l'éjection")
check(PvPService.GetRobCooldown(cy, adaShop) == 0, "Cy n'a pas été frappé : aucune interdiction")

section("deux intrus éjectés l'un après l'autre : réparée au second")
check(breakDoor(dan, adaShop), "Dan casse la porte d'Ada")
moveTo(dan, A.center, Vector3.new(0, 0, -1))
moveTo(cy, A.center + BESIDE, Vector3.new(0, 0, -1))
advance(0.2)
check(inShop(dan) and inShop(cy), "Dan et Cy sont dedans")
advance(0.9) -- recharge de la batte d'Ada
swingAt(dan)
check(hits[#hits].target == dan and not inShop(dan), "Dan éjecté")
check(broken(), "Cy encore dedans : la porte attend")
advance(0.9)
swingAt(cy)
check(hits[#hits].target == cy and not inShop(cy), "Cy éjecté à son tour")
check(not broken(), "plus aucun intrus : porte réparée tout de suite")
check(adaShop:GetAttribute("StealOpen") == nil, "vol fermé")

section("seul intrus éjecté : réparée tout de suite")
check(breakDoor(eve, adaShop), "Eve casse la porte d'Ada")
moveTo(eve, A.center, Vector3.new(0, 0, -1))
advance(0.2)
advance(0.9)
swingAt(eve)
check(hits[#hits].target == eve and not inShop(eve), "Eve éjectée")
check(not broken(), "porte réparée dans le même coup")
advance(1)
check(not broken() and not inShop(eve), "elle reste réparée ; Eve ne rentre pas")

-- Fusion 45 (décision de Cantin, 2026-11-14 : « Oui, réparer ») : un voleur frappé alors qu'il est déjà dehors
-- fait aussi reconstruire la porte, dès qu'il ne reste aucun intrus (même règle qu'après une éjection).
-- Arbre d'a151 seul (avant cette décision) : l'ancienne règle (la porte ne change pas) est vérifiée à la place.
local OUTSIDE_RULE = string.find(SOURCES["server/Services/PvPService.luau"], "« Oui, réparer »", 1, true) ~= nil
section("voleur déjà dehors frappé, un intrus encore dedans : la porte attend")
advance(61) -- fin des interdictions sur cette boutique (PvP.KickRobCooldown)
local fay = bob
check(breakDoor(fay, adaShop), "Bob casse la porte d'Ada")
check(steal(fay, adaShop, 2), "Bob prend un objet")
walkTo(fay, A.outside + Vector3.new(0, 0, -6), 40)
check(not inShop(fay), "Bob est dehors")
moveTo(dan, A.center + BESIDE, Vector3.new(0, 0, -1))
advance(0.2)
check(inShop(dan), "Dan est dans la boutique d'Ada")
moveTo(ada, A.outside)
advance(0.9)
swingAt(fay)
check(hits[#hits].target == fay and hits[#hits].usage == "Defend", "coup « Defend » d'Ada sur Bob, dehors")
check(broken(), "Dan encore dedans : la porte reste cassée")
advance(1)
check(broken() and inShop(dan), "1 s plus tard : elle attend toujours (Dan dedans)")
moveTo(dan, A.outside, Vector3.new(0, 0, -1))
advance(0.25)
check(not inShop(dan), "Dan est sorti de lui-même")
if OUTSIDE_RULE then
	check(not broken(), "plus aucun intrus : la porte se reconstruit tout de suite")
	check(adaShop:GetAttribute("StealOpen") == nil, "la fenêtre de vol se ferme")
else
	check(broken(), "règle d'a151 seule : la porte ne change pas")
	advance(31)
	check(not broken(), "puis reconstruite comme avant (délai normal, boutique vide)")
end

section("voleur déjà dehors frappé, boutique vide : porte reconstruite tout de suite")
advance(61) -- fin de l'interdiction de Bob
check(breakDoor(eve, adaShop), "Eve casse la porte d'Ada")
check(steal(eve, adaShop, 1), "Eve prend un objet")
walkTo(eve, A.outside + Vector3.new(0, 0, -6), 40)
check(not inShop(eve), "Eve est dehors")
moveTo(ada, A.outside)
advance(0.9)
swingAt(eve)
check(hits[#hits].target == eve and hits[#hits].usage == "Defend", "coup « Defend » d'Ada sur Eve, dehors")
if OUTSIDE_RULE then
	check(not broken(), "boutique vide : porte réparée dans le même coup")
	check(logHas("porte reconstruite, plus aucun intrus après l'éjection", "PRINT", "server"), "sortie : porte reconstruite")
else
	check(broken(), "règle d'a151 seule : la porte reste cassée (reconstruction normale)")
	advance(31)
	check(not broken(), "puis reconstruite comme avant")
end
check(not logHas("tick :", "WARN") and not logHas("ERREUR"), "aucune erreur dans les boucles")
summary("scénario owner")
