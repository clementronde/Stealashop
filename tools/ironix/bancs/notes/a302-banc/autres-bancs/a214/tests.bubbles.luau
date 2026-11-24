-- Scénarios du banc a214 (vague 64, bulles ×N du tapis, décisions de Cantin du 16/11). Harnais : la copie a134 du banc
-- a65 (faux Roblox, vrais TrainingService, Shared/TrainingZone, Config/Training), règle d'a180 allumée (on monte par
-- un grand côté). Vrais : BubbleService et Config/Bubbles, ajoutés ici à l'arbre des modules.
-- a302 (21/11, Cantin : bulles deux fois moins souvent) : durées simulées et attentes lues dans Bubbles (SPAWN_MIN,
-- SPAWN_MAX, MAX_AT_ONCE, LIFETIME) au lieu de 2, 3, 2 et 6 en dur ; D7 vérifie les valeurs décidées : 4, 6, 2 et 6.

local FRAME = 1 / 20

-- Faux moteur : ce que Config/Bubbles et BubbleService lisent en plus du harnais (ajout pur).
Enum.EasingStyle = { Back = { Name = "Back" }, Quad = { Name = "Quad" }, Linear = { Name = "Linear" } }
Enum.EasingDirection = { In = { Name = "In" }, Out = { Name = "Out" } }
Color3 = {
	fromHex = function(hex)
		return { hex = hex }
	end,
	new = function(r, g, b)
		return { r = r, g = g, b = b }
	end,
}
math.randomseed(214)
Random = {
	new = function()
		return {
			NextNumber = function(_, a, b)
				return a + math.random() * (b - a)
			end,
		}
	end,
}

-- Remotes des bulles sur le bouchon de Net (ajout pur).
SPAWNS, GONE = {}, {}
local CLAIM = newSignal()
local NetStub = requireModule(ReplicatedStorage.Shared.Net.Net)
NetStub.Server.BubbleSpawn = {
	Fire = function(_, p, id, multiplier, lifetime)
		table.insert(SPAWNS, { p = p, id = id, multiplier = multiplier, lifetime = lifetime, at = NOW })
	end,
}
NetStub.Server.BubbleGone = {
	Fire = function(_, p, id, reason, gain)
		table.insert(GONE, { p = p, id = id, reason = reason, gain = gain, at = NOW })
	end,
}
NetStub.Server.ClaimBubble = CLAIM

local bubblesModule = newInst("ModuleScript", "Bubbles", ReplicatedStorage.Shared.Config)
bubblesModule._key = "shared/Config/Bubbles.luau"
local serviceModule = newInst("ModuleScript", "BubbleService", game:FindFirstChild("Services"))
serviceModule._key = "server/Services/BubbleService.luau"
local Bubbles = requireModule(bubblesModule)
local BubbleService = requireModule(serviceModule)
-- a302 : rythme et vie lus dans Config/Bubbles. WAIT_ONE : assez pour qu'une bulle soit sûrement venue (SpawnMax + 0,1 s).
local SPAWN_MIN, SPAWN_MAX = Bubbles.SpawnMin, Bubbles.SpawnMax
local MAX_AT_ONCE, LIFETIME = Bubbles.MaxAtOnce, Bubbles.Lifetime
local WAIT_ONE = SPAWN_MAX + 0.1

local scenarios = {}
for _, name in string.split(SCENARIO or "draw,rhythm,claim,refuse,leave", ",") do
	scenarios[name] = true
end

-- B1 : tirage --------------------------------------------------------------------------
if scenarios.draw then
	check("D1 Draw(0) = 2", BubbleService.Draw(0) == 2)
	check("D2 Draw(54.99) = 2, Draw(55) = 3", BubbleService.Draw(54.99) == 2 and BubbleService.Draw(55) == 3)
	check("D3 Draw(99.6) = 20, Draw(99.4) = 10", BubbleService.Draw(99.6) == 20 and BubbleService.Draw(99.4) == 10)
	local N = 100000
	local counts = {}
	for _ = 1, N do
		local m = BubbleService.Draw(math.random() * 100)
		counts[m] = (counts[m] or 0) + 1
	end
	local total = 0
	for _, chance in Bubbles.Chances do
		total += chance.Percent
		local got = 100 * (counts[chance.Multiplier] or 0) / N
		local tolerance = math.max(0.15, chance.Percent * 0.06)
		check(
			`D4 ×{chance.Multiplier} tiré ≈ {chance.Percent} % sur 100 000`,
			math.abs(got - chance.Percent) <= tolerance,
			string.format("%.3f %%", got)
		)
	end
	check("D5 la table fait 100 %", math.abs(total - 100) < 1e-9, total)
	check("D6 table de Cantin : ×2 55, ×3 22, ×4 11, ×5 6, ×7 3,5, ×10 2, ×20 0,5", (function()
		local want = { { 2, 55 }, { 3, 22 }, { 4, 11 }, { 5, 6 }, { 7, 3.5 }, { 10, 2 }, { 20, 0.5 } }
		for i, w in want do
			local c = Bubbles.Chances[i]
			if c == nil or c.Multiplier ~= w[1] or c.Percent ~= w[2] then
				return false
			end
		end
		return #Bubbles.Chances == #want
	end)())
	check(
		"D7 rythme et vie de Cantin (21/11) : 4 à 6 s, 2 au plus, 6 s",
		Bubbles.SpawnMin == 4 and Bubbles.SpawnMax == 6 and Bubbles.MaxAtOnce == 2 and Bubbles.Lifetime == 6,
		`{Bubbles.SpawnMin} à {Bubbles.SpawnMax} s, {Bubbles.MaxAtOnce} au plus, {Bubbles.Lifetime} s`
	)
end

-- Monde : Alice et Bob, chacun sa boutique et son tapis -----------------------------------
local alice = newPlayer("Alice")
local bob = newPlayer("Bob")
newPlot("PLOT_Shop_01", alice, Vector3.new(0, 0, 0))
newPlot("PLOT_Shop_02", bob, Vector3.new(0, 0, 100))
TrainingService.Init()
BubbleService.Init()

local function walk(p, from, to)
	local d = to - from
	local n = 12
	for i = 0, n do
		if machineOf(p) ~= nil then
			break
		end
		moveTo(p, from + d * (i / n))
		step(FRAME, FRAME)
	end
end
-- Monte sur son tapis par le grand côté (règle d'a180), à l'origine de sa boutique.
local function mount(p, z)
	walk(p, Vector3.new(5, 3, z + 0.5), Vector3.new(0.5, 3, z + 0.5))
	return machineOf(p) == "Treadmill"
end
local function away(p)
	moveTo(p, Vector3.new(p.UserId * 10, 3, -400))
	step(0.3, FRAME)
end
local function spawnsOf(p, since)
	local r = {}
	for _, s in SPAWNS do
		if s.p == p and s.at >= (since or -math.huge) then
			table.insert(r, s)
		end
	end
	return r
end
local function goneOf(p, id)
	for _, g in GONE do
		if g.p == p and g.id == id then
			return g
		end
	end
	return nil
end
local function alive(p)
	return #BubbleService.GetBubbles(p)
end

-- B2 : rythme, au plus 2, expiration à 6 s ------------------------------------------------
if scenarios.rhythm then
	step(10, FRAME)
	check("R1 pas sur le tapis : aucune bulle", #spawnsOf(alice) == 0 and alive(alice) == 0)
	check("R2 Alice monte sur son tapis", mount(alice, 0))
	check("R2b TrainingService.IsTraining", TrainingService.IsTraining(alice) and not TrainingService.IsTraining(bob))
	local start = NOW
	step(SPAWN_MIN - 0.1, FRAME)
	check(`R3 rien avant {SPAWN_MIN} s`, #spawnsOf(alice) == 0)
	step(SPAWN_MAX - SPAWN_MIN + 0.2, FRAME)
	check(`R4 une bulle entre {SPAWN_MIN} et {SPAWN_MAX} s`, #spawnsOf(alice) == 1, #spawnsOf(alice))
	local first = spawnsOf(alice)[1]
	check(`R4b au bon joueur, durée {LIFETIME} s envoyée`, first and first.p == alice and first.lifetime == LIFETIME)
	-- 60 s sans rien prendre : jamais plus de MaxAtOnce, chaque bulle part à Lifetime s pile, écarts de SpawnMin à
	-- SpawnMax s (bulles sautées quand il y en a MaxAtOnce : l'écart compte alors deux intervalles).
	local maxAlive, t = 0, 0
	while t < 60 do
		step(FRAME, FRAME)
		t += FRAME
		maxAlive = math.max(maxAlive, alive(alice))
	end
	local list = spawnsOf(alice)
	check(`R5 jamais plus de {MAX_AT_ONCE} bulles à la fois`, maxAlive == MAX_AT_ONCE, maxAlive)
	local okLife, okGap, expired = true, true, 0
	for i, s in list do
		local g = goneOf(alice, s.id)
		if g then
			expired += 1
			if g.reason ~= "Expired" or g.at - s.at < LIFETIME - 1e-6 or g.at - s.at > LIFETIME + FRAME + 1e-6 then
				okLife = false
			end
		end
		if i > 1 then
			local gap = s.at - list[i - 1].at
			if gap < SPAWN_MIN - 1e-6 or gap > 2 * SPAWN_MAX + 2 * FRAME then
				okGap = false
			end
		end
	end
	check(`R6 bulle pas prise : « Expired » à {LIFETIME} s`, okLife and expired >= #list - MAX_AT_ONCE, `{expired}/{#list}`)
	check(`R7 écarts entre deux bulles : {SPAWN_MIN} s au moins`, okGap)
	-- Durée simulée depuis la montée : SPAWN_MAX + 0,1 s puis 60 s. Au moins une bulle tous les 2 × SpawnMax s (une
	-- sautée au plus entre deux), au plus une tous les SpawnMin s.
	local span = SPAWN_MAX + 0.1 + 60
	local lo, hi = math.floor(span / (2 * SPAWN_MAX)), math.ceil(span / SPAWN_MIN)
	check(
		`R8 une bulle toutes les {SPAWN_MIN} à {SPAWN_MAX} s, sautée quand {MAX_AT_ONCE} sont là ({lo} à {hi} en {span} s)`,
		#list >= lo and #list <= hi,
		#list
	)
	check("R9 multiplicateurs de la table seulement", (function()
		local valid = {}
		for _, c in Bubbles.Chances do
			valid[c.Multiplier] = true
		end
		for _, s in list do
			if not valid[s.multiplier] then
				return false
			end
		end
		return true
	end)())
	check("R10 Bob (pas sur son tapis) : aucune bulle", #spawnsOf(bob) == 0)
	local _ = start
	away(alice)
end

-- B3 : prise = 1 s de tapis × N, une fois ---------------------------------------------------
if scenarios.claim then
	DATA[alice].Upgrades.Treadmill = 3 -- niveau affiché 4 : 8 par seconde
	local baseHook = TrainingService.GetGainMultiplier
	TrainingService.GetGainMultiplier = function()
		return 2 -- gamepass ×2 Entraînement
	end
	check("C1 Alice monte", mount(alice, 0))
	check("C2 GainPerSecond = 8 × 2 (niveau × boost)", TrainingService.GainPerSecond(alice) == 16, TrainingService.GainPerSecond(alice))
	local since = NOW
	step(WAIT_ONE, FRAME)
	local s = spawnsOf(alice, since)[1]
	check("C3 une bulle", s ~= nil)
	if s then
		local before = SPEED[alice] or 0
		local ok, gain = BubbleService.Claim(alice, s.id)
		check("C4 prise acceptée", ok == true, gain)
		check("C5 gain = 16 × N", gain == 16 * s.multiplier, `{gain} pour ×{s.multiplier}`)
		check("C6 versé par StatsService.AddSpeed", (SPEED[alice] or 0) - before == 16 * s.multiplier)
		local g = goneOf(alice, s.id)
		check("C7 BubbleGone « Claimed » avec le gain", g and g.reason == "Claimed" and g.gain == 16 * s.multiplier)
		check("C8 la bulle n'est plus là", alive(alice) == 0)
		-- Le rythme du tapis ne change pas : la seconde suivante rapporte 16, pas plus.
		local after = SPEED[alice]
		step(1, FRAME)
		check("C9 tapis inchangé : 16 la seconde d'après", math.abs((SPEED[alice] - after) - 16) < 1e-6, SPEED[alice] - after)
		local ok2, why = BubbleService.Claim(alice, s.id)
		check("C10 une seule fois : la reprendre est refusé", ok2 == false and why == "Unknown", why)
	end
	-- Par le remote : ClaimBubble(id) fait la même chose.
	since = NOW
	step(WAIT_ONE, FRAME)
	local s2 = spawnsOf(alice, since)[1]
	if s2 then
		local before = SPEED[alice]
		CLAIM:Fire(alice, s2.id)
		check("C11 ClaimBubble (remote) verse le gain", SPEED[alice] - before == 16 * s2.multiplier)
	else
		check("C11 une seconde bulle", false)
	end
	TrainingService.GetGainMultiplier = baseHook
	DATA[alice].Upgrades.Treadmill = 0
	away(alice)
end

-- B4 : refus ------------------------------------------------------------------------------
if scenarios.refuse then
	check("F0 Alice et Bob montent", mount(alice, 0) and mount(bob, 100))
	local since = NOW
	step(WAIT_ONE, FRAME)
	local sa = spawnsOf(alice, since)[1]
	local sb = spawnsOf(bob, since)[1]
	check("F1 une bulle chacun", sa ~= nil and sb ~= nil)
	if sa and sb then
		local before = SPEED[alice] or 0
		local ok, why = BubbleService.Claim(alice, sb.id)
		check("F2 la bulle de Bob refusée à Alice", ok == false and why == "Unknown" and (SPEED[alice] or 0) == before, why)
		check("F2b celle de Bob reste à Bob", alive(bob) >= 1)
		step(0.15, FRAME) -- après le refus de F2, qui compte pour le débit
		local okA = BubbleService.Claim(alice, sa.id)
		local okRate, whyRate = BubbleService.Claim(alice, "B999999")
		check("F3 deux demandes à moins de 0,1 s : la 2e refusée (débit)", okA == true and okRate == false and whyRate == "Rate", whyRate)
		local okUnknown, whyUnknown = (function()
			step(0.15, FRAME)
			return BubbleService.Claim(alice, "B999999")
		end)()
		check("F4 id inconnu refusé", okUnknown == false and whyUnknown == "Unknown", whyUnknown)
	end
	-- Expirée : l'heure de fin passe avant le passage de la boucle.
	since = NOW
	step(WAIT_ONE, FRAME)
	local list = spawnsOf(alice, since)
	local s = list[#list]
	if s then
		NOW = s.at + LIFETIME + 0.01 -- sans Heartbeat : la boucle ne l'a pas encore retirée
		local before = SPEED[alice] or 0
		local ok, why = BubbleService.Claim(alice, s.id)
		check("F5 bulle expirée refusée, rien versé", ok == false and why == "Expired" and (SPEED[alice] or 0) == before, why)
		local g = goneOf(alice, s.id)
		check("F5b BubbleGone « Expired »", g and g.reason == "Expired")
	else
		check("F5 une bulle à laisser expirer", false)
	end
	step(0.2, FRAME)
	-- Plus en séance.
	since = NOW
	step(WAIT_ONE, FRAME)
	local last = spawnsOf(alice, since)[1]
	LEAVE:Fire(alice) -- TrainLeave : il bouge, il descend
	check("F6 Alice descendue", machineOf(alice) == nil and not TrainingService.IsTraining(alice))
	if last then
		local ok, why = BubbleService.Claim(alice, last.id)
		check("F7 plus en séance : refusé", ok == false and why == "NotTraining", why)
	else
		check("F7 une bulle avant de descendre", false)
	end
	away(alice)
	away(bob)
end

-- B5 : quitter le tapis vide tout ------------------------------------------------------------
if scenarios.leave then
	check("L0 Alice monte", mount(alice, 0))
	local since = NOW
	step(WAIT_ONE, FRAME)
	local before = spawnsOf(alice, since)
	check("L1 des bulles en cours", alive(alice) >= 1, alive(alice))
	LEAVE:Fire(alice)
	step(FRAME, FRAME)
	check("L2 descendue : plus aucune bulle", alive(alice) == 0)
	local cleared = true
	for _, s in before do
		local g = goneOf(alice, s.id)
		if g == nil or (g.reason ~= "Cleared" and g.reason ~= "Expired" and g.reason ~= "Claimed") then
			cleared = false
		end
	end
	check("L3 chacune reçoit BubbleGone « Cleared »", cleared)
	local off = NOW
	moveTo(alice, Vector3.new(8, 3, 0.5))
	step(SPAWN_MAX + 2, FRAME)
	check("L4 hors du tapis : aucune nouvelle bulle", #spawnsOf(alice, off + 1e-6) == 0)
	check("L5 remonte", mount(alice, 0))
	local back = NOW
	step(SPAWN_MIN - 0.1, FRAME)
	check(`L6 le compte repart : rien avant {SPAWN_MIN} s`, #spawnsOf(alice, back) == 0)
	step(SPAWN_MAX - SPAWN_MIN + 0.2, FRAME)
	check("L7 puis une bulle", #spawnsOf(alice, back) == 1)
	-- Départ du joueur : son état est oublié, aucun envoi.
	local n = #GONE
	alice.Parent = nil
	Players.PlayerRemoving:Fire(alice)
	step(FRAME, FRAME)
	check("L8 parti : rien d'envoyé, rien de gardé", #GONE == n and alive(alice) == 0)
end

print(`banc a214 (bulles ×N) : {CHECKS} vérification(s), {FAILS} échec(s)`)
