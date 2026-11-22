--!strict
-- Chargeur de modules commun au serveur et au client (DEV-002).
--
-- Charge les ModuleScripts enfants directs d'un dossier (services serveur ou
-- contrôleurs client) en deux temps :
--   1. Init() de chaque module, dans l'ordre de Priority (sans yield) ;
--   2. Start() de chaque module, chacun dans sa propre tâche (peut yield), lancée par task.defer dans le même
--      ordre : chaque Start a sa propre reprise, donc son propre temps avant « Script timeout » (L-284).
-- Une erreur dans un module est signalée avec son nom et n'arrête pas les autres.
--
-- Contrat d'un module chargé :
--   local MonService = {}
--   MonService.Priority = 10        -- optionnel, plus petit = plus tôt (défaut 100)
--   function MonService.Init() end  -- optionnel, ne doit pas yield
--   function MonService.Start() end -- optionnel
--   return MonService
-- Les modules d'aide d'un service vont dans un sous-dossier : seuls les enfants
-- directs du dossier sont chargés.

export type Module = {
	Priority: number?,
	Init: (() -> ())?,
	Start: (() -> ())?,
}

type Entry = { name: string, mod: Module }

local DEFAULT_PRIORITY = 100

local Loader = {}

local function collect(folder: Instance, label: string): { Entry }
	local list: { Entry } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			local ok, result = pcall(require, child)
			if not ok then
				warn(`[Loader {label}] {child.Name} : échec du require : {result}`)
			elseif type(result) ~= "table" then
				warn(`[Loader {label}] {child.Name} : ne renvoie pas une table, ignoré`)
			else
				table.insert(list, { name = child.Name, mod = result :: any })
			end
		end
	end
	table.sort(list, function(a: Entry, b: Entry): boolean
		local pa = a.mod.Priority or DEFAULT_PRIORITY
		local pb = b.mod.Priority or DEFAULT_PRIORITY
		if pa == pb then
			return a.name < b.name
		end
		return pa < pb
	end)
	return list
end

-- Charge et démarre tous les modules de `folder`. `label` sert aux messages
-- (« Serveur » ou « Client »). Renvoie le nombre de modules chargés.
function Loader.start(folder: Instance?, label: string): number
	if folder == nil then
		print(`[Loader {label}] aucun dossier de modules, rien à charger`)
		return 0
	end
	local startedAt = os.clock()
	local list = collect(folder, label)

	for _, entry in list do
		local init = entry.mod.Init
		if init then
			local ok, err = pcall(init :: any) -- :: any : sans lui, l'ancien solveur croit que pcall ne renvoie qu'une valeur
			if not ok then
				warn(`[Loader {label}] {entry.name}.Init : {err}`)
			end
		end
	end

	-- a306 (L-284, « Script timeout: exhausted allowed execution time » dans ce Loader, Main:8) : Roblox compte le
	-- temps sans yield par reprise, et un task.spawn tourne dans la reprise de celui qui l'appelle. Avec task.spawn,
	-- require, tous les Init et le début de chaque Start (jusqu'à son premier yield) s'additionnaient dans la seule
	-- reprise de Main ; passé ScriptTimeoutLength (10 s en Studio), le Start en cours tombait, puis tous les suivants
	-- (RayonService : boutique pas posée). task.defer : chaque Start repart dans sa propre reprise, même ordre.
	for _, entry in list do
		local start = entry.mod.Start
		if start then
			task.defer(function()
				local ok, err = xpcall(start :: any, function(message: any): string
					return debug.traceback(tostring(message), 2)
				end)
				if not ok then
					warn(`[Loader {label}] {entry.name}.Start : {err}`)
				end
			end)
		end
	end

	print(`[Loader {label}] {#list} module(s) démarré(s) (require et Init en {string.format("%.2f", os.clock() - startedAt)} s)`)
	return #list
end

return Loader
