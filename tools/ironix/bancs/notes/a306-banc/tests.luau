--!nocheck
-- Banc a306 (L-284, « Script timeout: exhausted allowed execution time » dans ReplicatedStorage.Shared.Loader, Main:8,
-- juste après RebirthService ; ensuite RayonService ne pose rien sur la boutique du joueur).
--
-- Mesuré en Play (Studio de Cantin, 22/11) avec un script de sonde : Roblox compte le temps sans yield PAR REPRISE,
-- et un task.spawn tourne dans la reprise de celui qui l'appelle (4 fils task.spawn de 3 s : timeout au 4e, et le
-- fil appelant meurt aussi) ; 4 fils task.defer de 3 s : aucun timeout (chacun sa reprise). ScriptTimeoutLength = 10.
--
-- Faux ordonnanceur de ce banc, fidèle à ces deux mesures :
--   - une « reprise » = un fil relancé par l'ordonnanceur (Main, un fil task.defer, un fil qui sort d'un task.wait) ;
--   - task.spawn lance tout de suite, DANS la reprise en cours (le temps s'additionne) ;
--   - burn(s) : s secondes de calcul sans yield ; passé TIMEOUT dans la reprise, erreur « Script timeout » ; ensuite
--     tout burn ou task.spawn de la même reprise lève la même erreur (comme Roblox, qui relève l'erreur jusqu'au yield).
-- Les « services » sont des faux modules dont le coût suit la carte : une boutique de 751 pièces, plus les 64 pièces
-- de même nom (copies de Stage_2) ajoutées au niveau 1 par Clément, dans le gabarit et les 6 boutiques, et les 7
-- copies de MapBackups/2026-11-21_BoutiqueCarree (sans tags). RayonService (priorité 120) pose la boutique dans son
-- Start (attribut StageLevel), comme en jeu.

local TIMEOUT = 10
local PART_COST = 2.5e-5 -- s par pièce et par parcours (V0 du banc : ~2,3 s pour le ContractChecker en Play)

local CHECKS, FAILS = 0, 0
local function check(cond, label)
	CHECKS += 1
	if not cond then
		FAILS += 1
		REAL_PRINT("ÉCHEC : " .. label)
	elseif VERBOSE then
		REAL_PRINT("ok : " .. label)
	end
end

---------------------------------------------------------------- ordonnanceur
local READY = {}
local slice = { used = 0, dead = false, max = 0 }
local LOG = {}
local THREAD_ERRORS = {}
local SLICE_MAX = 0

local function timeoutError()
	error("Script timeout: exhausted allowed execution time", 0)
end
function burn(seconds)
	if slice.dead then
		timeoutError()
	end
	slice.used += seconds
	if slice.used > SLICE_MAX then
		SLICE_MAX = slice.used
	end
	if slice.used > TIMEOUT then
		slice.dead = true
		timeoutError()
	end
end

local function resumeTop(co, ...)
	slice = { used = 0, dead = false }
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		table.insert(THREAD_ERRORS, tostring(err))
	end
end
local function resumeNested(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		table.insert(THREAD_ERRORS, tostring(err))
	end
end

task = {}
function task.spawn(fn, ...)
	if slice.dead then
		timeoutError() -- l'appelant tombe aussi
	end
	resumeNested(coroutine.create(fn), ...)
end
function task.defer(fn, ...)
	table.insert(READY, { co = coroutine.create(fn), args = table.pack(...) })
end
function task.wait()
	table.insert(READY, { co = coroutine.running(), args = table.pack() })
	coroutine.yield()
	return 0
end
local function pump()
	local rounds = 0
	while #READY > 0 and rounds < 1000 do
		rounds += 1
		local batch = READY
		READY = {}
		for _, t in batch do
			resumeTop(t.co, table.unpack(t.args, 1, t.args.n))
		end
	end
end

print = function(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring(select(i, ...))
	end
	table.insert(LOG, { kind = "PRINT", text = table.concat(parts, " ") })
end
warn = function(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring(select(i, ...))
	end
	table.insert(LOG, { kind = "WARN", text = table.concat(parts, " ") })
end
local realPrint = REAL_PRINT
local function logHas(text, kind)
	for _, l in LOG do
		if (kind == nil or l.kind == kind) and string.find(l.text, text, 1, true) then
			return true
		end
	end
	return false
end

---------------------------------------------------------------- faux modules et carte
-- Coûts sans yield à la vitesse de la machine de Cantin, d'après le Play du 22/11 (Workspace de 90 948 instances,
-- ServerStorage de 474 402, dont 335 045 dans MapBackups) : entre la ligne « [RebirthService] allumée » et la
-- première ligne d'un Start suivant, 2,27 s, presque tout dans ContractChecker.Start (parcours de Workspace et des
-- Assets, puis ses vérifications) ; le reste des Init et des débuts de Start, quelques dixièmes. `slow` multiplie
-- tout (machine plus lente, Studio plus chargé, carte plus grosse). La retouche de Clément (64 pièces × 7, et les
-- 7 copies de sauvegarde dans ServerStorage, hors des parcours) ajoute 0,5 % au Workspace : `extra` = 1.005.
local CC_STAGES = { 0.6, 0.6, 0.5, 0.3, 0.2, 0.1 } -- parcours + attributs, modèles, objets et icônes, UI, animations, scripts

-- Fabrique la liste des faux services (enfants « ModuleScript » du dossier) et renvoie l'état observé.
-- ccYields : le ContractChecker rend la main entre ses étapes dès 1 s sans yield (code a306) ou non (code d'avant).
local function makeServices(slow, ccYields)
	local state = { initOrder = {}, startOrder = {}, startedBeforeInitsDone = false, initsDone = 0, stageLevel = nil }
	local nInits = 0
	local specs = {
		-- nom, priorité, coût Init (s), coût du début de Start (s) avant son premier yield, Start qui pose la boutique
		{ "ContractChecker", 1, 0, 0 },
		{ "DataService", 1, 0.02, 0.02 },
		{ "PlotService", 10, 0.05, 0 },
		{ "StatsService", 10, 0.01, 0 },
		{ "AntiCheatService", 100, 0.01, 0 },
		{ "BatService", 100, 0.01, 0.01 },
		{ "WindowService", 100, 0.1, 0 },
		{ "StoreHeistService", 100, 0.1, 0.1 },
		{ "WitnessService", 100, 0.02, 0.05 },
		{ "ShopStageService", 119, 0.01, 0 },
		{ "RayonService", 120, 0.02, 0.05, true },
		{ "RebirthService", 300, 0.02, 0 },
		{ "AdminService", 1000, 0.01, 0.01 },
	}
	local children = {}
	for _, spec in specs do
		local name, priority, initCost, startCost, places = spec[1], spec[2], spec[3], spec[4], spec[5]
		nInits += 1
		local mod = { Priority = priority }
		function mod.Init()
			burn(initCost * slow)
			table.insert(state.initOrder, name)
			state.initsDone += 1
			if name == "RebirthService" then
				print("[RebirthService] allumée, 10 paliers")
			end
		end
		function mod.Start()
			if state.initsDone < nInits then
				state.startedBeforeInitsDone = true
			end
			table.insert(state.startOrder, name)
			if name == "ContractChecker" then
				for _, cost in CC_STAGES do
					if ccYields and slice.used >= 1 then -- breathe() : cède après 1 s (SLICE_SECONDS)
						task.wait()
					end
					burn(cost * slow)
				end
			end
			burn(startCost * slow)
			if places then
				state.stageLevel = 3 -- RayonService : ShopStageService.Apply sur la boutique du joueur
				print("[RayonService] PLOT_Shop_03 : 3 rayon(s) visible(s)")
			end
			task.wait()
			state[name .. "_after_yield"] = true
		end
		table.insert(children, { Name = name, mod = mod })
	end
	-- un service qui plante dans son Start : le Loader le signale avec son nom, les autres continuent
	local bad = { Priority = 100 }
	function bad.Start()
		table.insert(state.startOrder, "BrokenService")
		error("panne voulue")
	end
	table.insert(children, { Name = "BrokenService", mod = bad })
	return state, children
end

local function folderOf(children)
	local folder = {}
	function folder:GetChildren()
		local out = {}
		for _, c in children do
			table.insert(out, {
				Name = c.Name,
				mod = c.mod,
				IsA = function(_, class)
					return class == "ModuleScript"
				end,
			})
		end
		return out
	end
	return folder
end

local function loadLoader(source)
	local fn, err = loadstring(source, "=Loader")
	assert(fn, err)
	local env = setmetatable({
		require = function(child)
			return child.mod
		end,
	}, { __index = getfenv(1) })
	setfenv(fn, env)
	return fn()
end

local function bootOnce(source, slow, ccYields)
	LOG, THREAD_ERRORS, READY, SLICE_MAX = {}, {}, {}, 0
	local state, children = makeServices(slow, ccYields)
	local Loader = loadLoader(source)
	local main = coroutine.create(function()
		Loader.start(folderOf(children), "Serveur")
	end)
	resumeTop(main)
	pump()
	return state
end

local function timeoutsSeen()
	local n = 0
	for _, e in THREAD_ERRORS do
		if string.find(e, "Script timeout", 1, true) then
			n += 1
		end
	end
	for _, l in LOG do
		if l.kind == "WARN" and string.find(l.text, "Script timeout", 1, true) then
			n += 1
		end
	end
	return n
end

---------------------------------------------------------------- scénarios
local CLEMENT = 1.005 -- carte de Clément : +0,5 % d'instances dans les parcours (voir plus haut)

-- R : le Loader et le ContractChecker d'avant (77b31b3).
do
	local state = bootOnce(LOADER_AVANT, 1 * CLEMENT, false)
	check(timeoutsSeen() == 0 and state.stageLevel == 3, `R0 code d'avant, machine de Cantin : pas de timeout, boutique posée (comme au Play du 22/11 ; plus longue reprise {string.format("%.2f", SLICE_MAX)} s)`)
	state = bootOnce(LOADER_AVANT, 4 * CLEMENT, false)
	check(timeoutsSeen() > 0, "R1 code d'avant, machine 4 fois plus lente : « Script timeout » au démarrage (reproduit)")
	check(logHas("[RebirthService] allumée", "PRINT"), "R2 code d'avant : le timeout tombe après la ligne de RebirthService (tous les Init sont passés)")
	check(state.stageLevel == nil, "R3 code d'avant : RayonService ne pose pas la boutique (StageLevel absent), comme chez Clément")
	check(not logHas("module(s) démarré(s)", "PRINT"), "R4 code d'avant : Main tombe aussi (pas de « module(s) démarré(s) »)")
	check(SLICE_MAX > TIMEOUT, `R5 code d'avant : une seule reprise dépasse {TIMEOUT} s ({string.format("%.2f", SLICE_MAX)} s)`)
	if VERBOSE then
		for _, e in THREAD_ERRORS do
			realPrint("  erreur de fil (avant) : " .. e)
		end
	end
end

-- N : le Loader et le ContractChecker du dépôt.
local function scenario(tag, slow)
	local state = bootOnce(LOADER_REPO, slow, HAS_CC_YIELDS)
	local timeouts = timeoutsSeen()
	check(timeouts == 0, `{tag} aucun « Script timeout » ({timeouts})`)
	check(state.stageLevel == 3, `{tag} RayonService pose la boutique du joueur (StageLevel 3)`)
	check(not state.startedBeforeInitsDone, `{tag} aucun Start avant la fin de tous les Init`)
	local expectedInit = { "ContractChecker", "DataService", "PlotService", "StatsService", "AntiCheatService", "BatService", "StoreHeistService", "WindowService", "WitnessService", "ShopStageService", "RayonService", "RebirthService", "AdminService" }
	check(table.concat(state.initOrder, ",") == table.concat(expectedInit, ","), `{tag} Init dans l'ordre de Priority puis du nom ({table.concat(state.initOrder, ",")})`)
	local expectedStart = { "ContractChecker", "DataService", "PlotService", "StatsService", "AntiCheatService", "BatService", "BrokenService", "StoreHeistService", "WindowService", "WitnessService", "ShopStageService", "RayonService", "RebirthService", "AdminService" }
	check(table.concat(state.startOrder, ",") == table.concat(expectedStart, ","), `{tag} Start dans le même ordre ({table.concat(state.startOrder, ",")})`)
	check(state.RayonService_after_yield and state.AdminService_after_yield and state.ContractChecker_after_yield, `{tag} chaque Start reprend après son premier yield`)
	check(logHas("[Loader Serveur] BrokenService.Start : ", "WARN") and logHas("panne voulue", "WARN"), `{tag} un Start qui plante est signalé avec son nom`)
	check(logHas("[Loader Serveur] 14 module(s) démarré(s) (require et Init en ", "PRINT"), `{tag} « 14 module(s) démarré(s) (require et Init en … s) »`)
	check(SLICE_MAX <= TIMEOUT, `{tag} plus longue reprise {string.format("%.2f", SLICE_MAX)} s ≤ {TIMEOUT} s`)
end

if not HAS_DEFER then
	realPrint("banc a306 : partie N SAUTÉE (Loader d'avant a306, Start par task.spawn)")
else
	scenario("N1 machine de Cantin :", 1 * CLEMENT)
	scenario("N2 machine 4 fois plus lente (cas de Clément) :", 4 * CLEMENT)
	if HAS_CC_YIELDS then
		scenario("N3 machine 12 fois plus lente (ContractChecker par étapes) :", 12 * CLEMENT)
	end
end

realPrint(`banc a306 : {CHECKS} vérification(s), {FAILS} échec(s)`)
