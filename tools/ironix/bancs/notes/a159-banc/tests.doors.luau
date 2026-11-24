--!nocheck
-- Scénario « doors » (a159, L-163) : la porte d'une boutique se casse en nombre de coups, le même pour tous.
-- Vrais WindowService, SkillTreeService, PvPService ; client PvPController (panneau).
startSkills()
local PvP = sharedModule("Config/PvP")
local adaData = newProfile()
addItem(adaData, "ada-soda", "Z1_CanetteDeSoda", 1)
addItem(adaData, "ada-chips", "Z1_PaquetDeChips", 2)
adaData.Cash = 1e12
local ada = join("Ada", adaData)
local thieves = {}
for _, name in { "Bob", "Cy", "Dan", "Eve" } do
	table.insert(thieves, join(name, newProfile()))
end
local bob = thieves[1]
advance(1.2)
local shop = shopOf(ada)
local door = shop:FindFirstChild("Window", true)
local id = windowIdOf(shop)
local S = refsOfShop(shop)

-- Coups comptés (WindowHit renvoyé au frappeur) sur la porte d'Ada depuis `since`.
local function counted(since)
	return remotes("WindowHit", function(e)
		return e.args[1] == id and e.to == e.args[3] and e.t >= since
	end)
end
local function currentHP()
	return lastHP(shop)
end
-- `players` frappent la porte, chacun à 5 coups par seconde, décalés de 0,2 / #players s, jusqu'à la casse
-- (au plus `limit` s). Renvoie le temps écoulé entre le premier coup compté et la casse, et le nombre de coups comptés.
local function smash(players, limit)
	if WindowService.IsBroken(id) then
		WindowService.Rebuild(id)
	end
	advance(1)
	-- Porte entamée par la mesure précédente : on attend qu'elle soit pleine (3 s sans coup, puis la réparation).
	local waited = 0
	while waited < 60 do
		local hp, m = currentHP()
		if hp == nil or m == nil or hp >= m - 1e-6 then
			break
		end
		advance(0.5)
		waited += 0.5
	end
	local tools = {}
	for _, p in players do
		moveTo(p, S.outside + S.front * -3)
		table.insert(tools, giveTool(p))
	end
	local start = now()
	local step = 0.2 / #players
	local elapsed = 0
	local i = 0
	while not WindowService.IsBroken(id) and elapsed < (limit or 60) do
		fireAs(players[(i % #players) + 1], "HitWindow", id)
		i += 1
		advance(step, step)
		elapsed += step
	end
	for _, t in tools do
		t:Destroy()
	end
	local list = counted(start)
	local first = list[1]
	return WindowService.IsBroken(id), if first then now() - step - first.t else 0, #list
end

section("40 coups, quelle que soit la force")
check(PvP.DoorHits == 40 and PvP.DoorMaxHitsPerSecond == 8, `PvP.DoorHits = 40, DoorMaxHitsPerSecond = 8 (trouvé {PvP.DoorHits}, {PvP.DoorMaxHitsPerSecond})`)
check(door:GetAttribute("MaxHP") == 40, `porte d'Ada : 40 coups (MaxHP {door:GetAttribute("MaxHP")})`)
shop:SetAttribute("StageLevel", 6)
advance(0.3)
check(door:GetAttribute("MaxHP") == 40, `boutique niveau 6 : toujours 40 (MaxHP {door:GetAttribute("MaxHP")})`)
DAMAGE[bob] = 1e9
local t0 = now()
moveTo(bob, S.outside + S.front * -3)
local tool = giveTool(bob)
fireAs(bob, "HitWindow", id)
advance(0.15, 0.05)
tool:Destroy()
local hit = counted(t0)[1]
local hp = currentHP()
check(hit ~= nil and hit.args[4] == 1, `un coup à 1e9 de dégâts compte pour 1 (dégâts envoyés : {hit and hit.args[4]})`)
check(hp ~= nil and hp > 38.9 and hp < 40, `PV après un coup : {hp}`)
check(not WindowService.IsBroken(id), "la porte tient")
DAMAGE[bob] = nil
advance(4) -- la porte se répare (3 s sans coup, puis 3 %/s) avant les mesures sans réparation

local savedRegen = WindowService.GetPlotRegen
WindowService.GetPlotRegen = function()
	return 0
end
section("sans réparation : seul 8 s, à quatre 5 s")
local broke, t, n = smash({ bob })
print(`  mesure : seul, sans réparation : {string.format("%.2f", t)} s, {n} coups comptés`)
check(broke and n == 40, `seul : cassée en 40 coups comptés (trouvé {n})`)
check(t >= 7.75 and t <= 8.1, `seul : 39 intervalles de 0,2 s, environ 8 s (mesuré {string.format("%.2f", t)})`)
broke, t, n = smash({ bob }, 60)
check(broke, "seul, deuxième porte : cassée aussi")
broke, t, n = smash(thieves)
print(`  mesure : à quatre, sans réparation : {string.format("%.2f", t)} s, {n} coups comptés`)
check(broke and n == 40, `à quatre : 40 coups comptés (trouvé {n})`)
check(t >= 4.7, `à quatre : au moins 38 × 1/8 s (2 jetons d avance) (mesuré {string.format("%.2f", t)})`)
-- Fenêtre glissante d'une seconde : jamais plus de 8 coups comptés.
local list = counted(now() - t - 1)
local worst = 0
for a = 1, #list do
	local c = 0
	for b = a, #list do
		if list[b].t - list[a].t < 1 - 1e-6 then
			c += 1
		end
	end
	worst = math.max(worst, c)
end
check(worst <= 9 and n / t <= 8.5, `au plus 8 coups comptés par seconde à quatre, un d avance (pire seconde : {worst}, moyenne {string.format("%.2f", n / t)})`)
check(#list < 80, `les coups en trop ne partent pas (coups comptés {#list})`)
broke, t, n = smash({ bob, thieves[2] })
print(`  mesure : à deux, sans réparation : {string.format("%.2f", t)} s`)
check(broke and t >= 4.7 and t <= 6, `à deux : environ 5 s (mesuré {string.format("%.2f", t)})`)
WindowService.GetPlotRegen = savedRegen

section("avec la réparation de base (3 %/s) : arrêtée pendant les coups")
broke, t, n = smash({ bob })
print(`  mesure : seul, réparation 3 %/s : {string.format("%.2f", t)} s, {n} coups comptés`)
check(broke and n == 40 and t <= 8.1, `seul sans pause : 40 coups, 8 s environ, la réparation ne joue pas (mesuré {string.format("%.2f", t)})`)
broke, t, n = smash(thieves)
print(`  mesure : à quatre, réparation 3 %/s : {string.format("%.2f", t)} s, {n} coups comptés`)
check(broke and n == 40 and t >= 4.7 and t <= 5.2, `à quatre : 5 s environ (mesuré {string.format("%.2f", t)})`)

section("Reinforced Door (GlassThickness)")
WindowService.Rebuild(id)
advance(0.3)
buy(ada, "GlassThickness")
advance(0.2)
check(door:GetAttribute("MaxHP") == 48, `niveau 1 : 48 coups (MaxHP {door:GetAttribute("MaxHP")})`)
Workspace:SetAttribute("SkillTest", "Ada GlassThickness 5")
advance(0.3)
check(door:GetAttribute("MaxHP") == 80, `niveau 5 : 80 coups (MaxHP {door:GetAttribute("MaxHP")})`)
Workspace:SetAttribute("SkillTest", "Ada Walls 4")
advance(0.3)
check(door:GetAttribute("MaxHP") == 80, `Walls 4 : ne change rien (MaxHP {door:GetAttribute("MaxHP")})`)
WindowService.GetPlotRegen = function()
	return 0
end
broke, t, n = smash({ bob })
print(`  mesure : niveau 5, seul, sans réparation : {string.format("%.2f", t)} s, {n} coups`)
check(broke and n == 80 and t >= 15.7 and t <= 16.1, `niveau 5 seul : 80 coups en 16 s environ (mesuré {string.format("%.2f", t)}, {n})`)
broke, t, n = smash(thieves)
check(broke and n == 80 and t >= 9.7, `niveau 5 à quatre : 80 coups en 10 s environ (mesuré {string.format("%.2f", t)})`)
WindowService.GetPlotRegen = savedRegen

section("Door Repair (GlassRegen) en coups")
local function regenPerSecond()
	WindowService.Rebuild(id)
	advance(0.3)
	local tools = {}
	for _, p in thieves do
		moveTo(p, S.outside + S.front * -3)
		table.insert(tools, giveTool(p))
	end
	for i = 1, 60 do
		fireAs(thieves[(i % #thieves) + 1], "HitWindow", id)
		advance(0.05, 0.05)
	end
	for _, tl in tools do
		tl:Destroy()
	end
	local h0 = currentHP()
	advance(2.8)
	local hWait = currentHP()
	advance(0.4) -- 3 s sans coup : la réparation reprend
	local h1 = currentHP()
	advance(1)
	local h2, m = currentHP()
	return h2 - h1, m, hWait - h0
end
local r0, m0, w0 = regenPerSecond()
check(math.abs(w0) < 0.01, `moins de 3 s sans coup : aucune réparation (mesuré {string.format("%.3f", w0)})`)
check(m0 == 80 and math.abs(r0 - 2.4) < 0.2, `base : 3 % de 80 = 2,4 coups par seconde (mesuré {string.format("%.2f", r0)})`)
Workspace:SetAttribute("SkillTest", "Ada GlassRegen 5")
advance(0.2)
local r5, _, w5 = regenPerSecond()
check(math.abs(w5) < 0.01, `niveau 5, moins de 3 s sans coup : aucune réparation (mesuré {string.format("%.3f", w5)})`)
check(math.abs(r5 - 6.4) < 0.4, `niveau 5 : 8 % de 80 = 6,4 coups par seconde (mesuré {string.format("%.2f", r5)})`)
broke, t, n = smash({ bob }, 40)
print(`  mesure : Reinforced Door 5 + Door Repair 5, seul sans pause : cassée = {broke} en {string.format("%.2f", t)} s, {n} coups`)
check(broke and n == 80 and t <= 16.5, `niveau 5 partout, seul sans pause : cassée en 16 s au plus, marge 0,5 (mesuré {string.format("%.2f", t)})`)
broke, t, n = smash(thieves, 90)
print(`  mesure : Reinforced Door 5 + Door Repair 5, à quatre : cassée = {broke} en {string.format("%.2f", t)} s, {n} coups`)
check(broke and n == 80 and t >= 9.7 and t <= 10.5, `niveau 5 partout, à quatre : 10 s environ (mesuré {string.format("%.2f", t)})`)
-- Un voleur qui s'arrête plus de 3 s laisse la porte se réparer.
WindowService.Rebuild(id)
advance(0.3)
moveTo(bob, S.outside + S.front * -3)
local tp = giveTool(bob)
for _ = 1, 20 do
	fireAs(bob, "HitWindow", id)
	advance(0.2, 0.2)
end
local hPause = currentHP()
advance(5)
local hAfter = currentHP()
tp:Destroy()
print(`  mesure : pause de 5 s après 20 coups : {string.format("%.1f", hPause)} → {string.format("%.1f", hAfter)} coups`)
check(math.abs(hAfter - hPause - 14.08) < 0.7, `pause : dernier coup 0,2 s avant la lecture, réparation de 3 s à 5,2 s, 2,2 × 6,4 = +14,1 (mesuré {string.format("%.1f", hAfter - hPause)})`)

section("panneau du voleur (PvPController) : « 7/40 »")
Workspace:SetAttribute("SkillTest", "Ada reset")
advance(0.3)
WindowService.Rebuild(id)
advance(0.3)
startClient(bob)
do
	moveTo(bob, S.outside + S.front * -3)
	local tl = giveTool(bob)
	for _ = 1, 33 do
		fireAs(bob, "HitWindow", id)
		advance(0.2, 0.2)
	end
	tl:Destroy()
	advance(0.5)
	local text = PvPController.GetPanelText(shop)
	check(text ~= nil and string.match(text.HP or "", "^%d+/40$") ~= nil, `HP du panneau : « {text and text.HP} »`)
end

section("sortie")
check(not logHas("mal formé", "WARN"), "aucun envoi de remote mal formé")
check(not logHas("tick :", "WARN"), "aucune erreur dans les boucles des services")
check(not logHas("valeur de base gardée", "WARN"), "aucun point d'accroche en erreur")
summary("scénario doors")
