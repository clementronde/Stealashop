--!strict
-- LoadingFlow (a532, Cantin 28/11 ; Features.LoadingReal / LoadingRealDev) : le vrai déroulé de l'écran de chargement,
-- sans Roblox : LoadingScreen (même dossier) lui donne les vraies fonctions, les bancs des fausses.
-- Ne dépend pas de ReplicatedStorage/Shared.
--
-- Étapes (Config.StepOrder, poids Config.StepWeights, somme 1) :
--   Screen     l'écran lui-même, déjà préchargé par LoadingScreen : compté dès le départ ;
--   Game       game:IsLoaded() ;
--   Profile    profil chargé côté serveur (attribut ProfileLoaded du Player, posé par DataService) ;
--   Character  personnage apparu, avec son HumanoidRootPart ;
--   Screens    écrans principaux (Config.Screens) arrivés dans le PlayerGui, puis préchargés ;
--   Stream     zone autour du personnage streamée (RequestStreamAroundAsync), seulement avec StreamingEnabled ;
--   Assets     file de PreloadAsync (dossiers de Config.Preload et Config.RealPreload), en lots : la part de cette
--              étape suit le nombre d'assets préchargés.
-- La progression ne fait que monter (chaque étape finie le reste) ; aucun minuteur. Au-delà de Config.MaxWait s,
-- Run rend la main avec la liste des étapes pas finies ; les fils de préchargement continuent derrière.
--
-- API :
--   LoadingFlow.Run(config, deps, onProgress, startedAt?) -> Result   bloque jusqu'à la fin (ou MaxWait après startedAt)
--   onProgress(progress 0..1, étape en cours ou nil)

export type Deps = {
	now: () -> number,
	wait: (seconds: number) -> (),
	spawn: (fn: () -> ()) -> (),
	gameLoaded: () -> boolean,
	profileReady: () -> boolean,
	characterReady: () -> boolean,
	-- nil tant que les écrans attendus ne sont pas tous là ; sinon les écrans à précharger
	screens: () -> { Instance }?,
	streaming: () -> boolean,
	streamAround: () -> (), -- peut attendre
	assets: () -> { Instance }, -- appelé une fois, quand le jeu est chargé
	preload: (list: { Instance }) -> (), -- peut attendre
}

export type Result = {
	Done: boolean, -- toutes les étapes finies avant MaxWait
	Missing: { string }, -- étapes pas finies (ordre de Config.StepOrder)
	Order: { string }, -- étapes dans l'ordre où elles ont fini
	Elapsed: number,
}

local LoadingFlow = {}

function LoadingFlow.Run(
	config: any,
	deps: Deps,
	onProgress: (progress: number, step: string?) -> (),
	startedAt: number?
): Result
	local weights: { [string]: number } = config.StepWeights
	local order: { string } = config.StepOrder
	local interval: number = math.max(0.03, config.CheckInterval)
	local batchSize: number = math.max(1, config.BatchSize)
	local start = startedAt or deps.now() -- MaxWait compte depuis l'apparition de l'écran
	local done: { [string]: boolean } = {}
	local finished: { string } = {}
	local assetsTotal, assetsLoaded = 0, 0

	local function mark(step: string)
		if not done[step] then
			done[step] = true
			table.insert(finished, step)
		end
	end
	local function safe(fn: () -> ()): boolean
		return (pcall(fn))
	end
	local function check(fn: () -> boolean): boolean
		local ok, value = pcall(fn)
		return ok and value == true
	end
	local function waitUntil(cond: () -> boolean)
		while not cond() do
			deps.wait(interval)
		end
	end

	mark("Screen")

	-- Écrans principaux : arrivés, puis préchargés (images de l'UI du HUD).
	deps.spawn(function()
		local list: { Instance }? = nil
		waitUntil(function()
			local ok, value = pcall(deps.screens)
			list = if ok then value else nil
			return list ~= nil
		end)
		local found = list :: { Instance }
		if #found > 0 then
			safe(function()
				deps.preload(found)
			end)
		end
		mark("Screens")
	end)

	-- Zone autour du personnage (StreamingEnabled seulement).
	deps.spawn(function()
		waitUntil(function()
			return check(deps.characterReady)
		end)
		if check(deps.streaming) then
			safe(deps.streamAround)
		end
		mark("Stream")
	end)

	-- File de PreloadAsync, en lots, dès que le jeu est chargé (dossiers répliqués).
	deps.spawn(function()
		waitUntil(function()
			return check(deps.gameLoaded)
		end)
		local ok, value = pcall(deps.assets)
		local list: { Instance } = if ok and type(value) == "table" then value else {}
		assetsTotal = #list
		for first = 1, #list, batchSize do
			local batch: { Instance } = {}
			for i = first, math.min(first + batchSize - 1, #list) do
				table.insert(batch, list[i])
			end
			safe(function()
				deps.preload(batch)
			end)
			assetsLoaded = math.min(first + batchSize - 1, #list)
		end
		mark("Assets")
	end)

	local function progress(): number
		local p = 0
		for _, step in order do
			local weight = weights[step] or 0
			if done[step] then
				p += weight
			elseif step == "Assets" and assetsTotal > 0 then
				p += weight * assetsLoaded / assetsTotal
			end
		end
		return math.clamp(p, 0, 1)
	end
	local function current(): string?
		for _, step in order do
			if not done[step] then
				return step
			end
		end
		return nil
	end
	local function missing(): { string }
		local out: { string } = {}
		for _, step in order do
			if not done[step] then
				table.insert(out, step)
			end
		end
		return out
	end

	while true do
		if check(deps.gameLoaded) then
			mark("Game")
		end
		if check(deps.profileReady) then
			mark("Profile")
		end
		if check(deps.characterReady) then
			mark("Character")
		end
		local step = current()
		onProgress(if step == nil then 1 else progress(), step)
		local elapsed = deps.now() - start
		if step == nil then
			return { Done = true, Missing = {}, Order = finished, Elapsed = elapsed }
		end
		if elapsed >= config.MaxWait then
			return { Done = false, Missing = missing(), Order = finished, Elapsed = elapsed }
		end
		deps.wait(interval)
	end
end

return table.freeze(LoadingFlow)
