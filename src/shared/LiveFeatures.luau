--!strict
-- LiveFeatures (a442, 25/11 ; check-up a417 P5, condition de la décision C2 de Cantin du 24/11) : rallumer ou
-- éteindre un interrupteur de Config/Features en PROD sans republier. Réglages : Config/LiveFeatures ; commande
-- d'admin : server/Services/LiveFeaturesService.
--
-- Branché sur le seul point commun de toutes les lectures, le module Config/Features lui-même : dans un vrai jeu
-- Roblox lancé (Play, serveur en ligne), il renvoie à la place de sa table gelée une table gelée « vivante »
-- (LiveFeatures.Wrap) où chaque `Features.X` lit la valeur en vigueur. Aucun lecteur n'est changé. Hors jeu (Edit,
-- bancs hors Studio où `game` n'est pas un userdata, outils) : la table du fichier, comme avant.
--
-- Valeur en vigueur d'un interrupteur X (booléen de Config/Features), de la plus forte à la plus faible :
--   1. la commande d'admin de ce serveur (interrupteurs de Config/LiveFeatures.Hot seulement, jusqu'à sa fermeture) ;
--   2. ConfigService (Creator Hub > Configs du jeu), clé booléenne KeyPrefix .. X (« Feature_X ») ;
--   3. le fichier Config/Features (clé absente, service muet ou en erreur, valeur qui n'est pas un booléen).
-- Quand :
--   - au démarrage du serveur, ConfigService est lu AVANT toute lecture d'interrupteur (le premier require de
--     Config/Features attend au plus BootWaitSeconds) : tous les interrupteurs prennent leur valeur au prochain serveur ;
--   - sur un serveur lancé, seuls ceux de Hot changent (ConfigService à chaud, commande d'admin) ; pour les autres,
--     une ligne dans la sortie dit « pris au prochain serveur » : ils sont lus au chargement d'un module ou dans
--     Init / Start (inventaire d'a442), et un changement en route laisserait client et serveur en désaccord ;
--   - ConfigService en erreur au démarrage : le fichier, puis un nouvel essai toutes les RetrySeconds s (réponse
--     tardive : Hot seulement, comme un changement à chaud).
-- Paire X / XDev : inchangée. Chaque clé se surcharge seule ; chaque lecteur garde son « X or (XDev and IsDev) ».
-- LiveFeatures.On(X) fait ce calcul au moment de l'appel (lecture recommandée pour le code neuf).
-- Clients : en lecture seule. Le serveur pose la valeur en vigueur en attribut du module Config/Features (un attribut
-- par interrupteur surchargé, plus ReadyAttribute quand son état est prêt) ; le client attend ReadyAttribute au plus
-- ClientWaitSeconds à son premier require, puis suit AttributeChanged. Le serveur ne lit jamais ces attributs et
-- aucun remote ne touche un interrupteur : un client ne peut rien changer, ni pour lui côté serveur ni pour les autres.
--
-- API
--   LiveFeatures.Wrap(raw, module) -> table      appelé par Config/Features seulement (une fois)
--   LiveFeatures.Get(name) -> any                valeur en vigueur (nil : pas une clé de Config/Features)
--   LiveFeatures.On(name) -> boolean             Get(name) == true, ou Get(name .. "Dev") == true dans le jeu DEV
--   LiveFeatures.Source(name) -> string          "File", "Config", "Admin" (serveur) ; "File" ou "Server" (client)
--   LiveFeatures.OnChanged(fn(name, value)) -> () -> ()   changement à chaud d'un interrupteur ; rend la déconnexion
--   LiveFeatures.SetAdminRule(rule)              serveur : qui est admin de la commande (LiveFeaturesService y branche
--                                                AdminService.IsAdmin, la règle de Config/Admin) ; sans règle, personne
--   LiveFeatures.IsAdmin(player) -> boolean      serveur : la règle branchée (jamais le client, jamais un attribut)
--   LiveFeatures.SetAdmin(player, name, value?) -> (boolean, string)
--       serveur, admin, interrupteur de Hot ; value nil = retire la surcharge d'admin (retour à ConfigService ou au fichier)
--   LiveFeatures.Status() -> Status              état pour la sortie (LiveFeaturesService)
--   LiveFeatures.new(raw, env) -> Live           bancs : une instance sur un environnement simulé

local Settings = require(script.Parent.Config.LiveFeatures)

export type Settings = typeof(Settings)

-- Environnement d'une instance (le vrai jeu : realEnv ; les bancs : un faux).
export type Env = {
	side: string, -- "server" ou "client"
	settings: any, -- Config/LiveFeatures
	module: any, -- Config/Features : SetAttribute, GetAttribute, AttributeChanged (nil : aucun attribut)
	configService: any, -- ConfigService (serveur ; nil : service absent)
	isDev: () -> boolean,
	clock: () -> number,
	wait: (seconds: number) -> (),
	spawn: (fn: () -> ()) -> (),
	delay: (seconds: number, fn: () -> ()) -> (),
	print: (message: string) -> (),
	warn: (message: string) -> (),
}

export type Status = {
	side: string,
	config: string, -- "ok", "error", "waiting", "absent" (serveur) ; "client"
	overrides: { string }, -- « Nom = valeur (Source) », triés
	hot: { string },
}

export type Live = {
	features: any,
	Get: (name: string) -> any,
	Source: (name: string) -> string,
	On: (name: string) -> boolean,
	OnChanged: (fn: (name: string, value: any) -> ()) -> () -> (),
	SetAdminRule: (rule: (player: any) -> boolean) -> (),
	IsAdmin: (player: any) -> boolean,
	SetAdmin: (player: any, name: string, value: boolean?) -> (boolean, string),
	Status: () -> Status,
}

local LiveFeatures = {}

local current: Live? = nil

-- Une instance sur `raw` (la table gelée du fichier) et `env`.
function LiveFeatures.new(raw: { [string]: any }, env: Env): Live
	local settings = env.settings
	local hot: { [string]: boolean } = settings.Hot or {}
	local messages = settings.Messages
	local effective: { [string]: any } = table.clone(raw)
	local fromConfig: { [string]: boolean } = {} -- valeurs de ConfigService en vigueur sur ce serveur
	local fromAdmin: { [string]: boolean } = {} -- surcharges d'admin de ce serveur (Hot)
	local seen: { [string]: string } = {} -- serveur : dernière valeur de ConfigService notée « prochain serveur »
	local listeners: { (string, any) -> () } = {}
	local warned: { [string]: boolean } = {}
	local configState = if env.side == "server" then "absent" else "client"
	local booted = false

	local function warnOnce(key: string, message: string)
		if not warned[key] then
			warned[key] = true
			env.warn(message)
		end
	end

	local function isFlag(name: any): boolean
		return type(name) == "string" and type(raw[name]) == "boolean"
	end

	local function fire(name: string, value: any)
		for _, fn in table.clone(listeners) do
			local ok, err = pcall(fn :: any, name, value)
			if not ok then
				env.warn(`[LiveFeatures] écouteur de {name} en erreur : {err}`)
			end
		end
	end

	-- Serveur : valeur en vigueur et sa source.
	local function resolve(name: string): (any, string)
		local admin = fromAdmin[name]
		if admin ~= nil then
			return admin, "Admin"
		end
		local config = fromConfig[name]
		if config ~= nil then
			return config, "Config"
		end
		return raw[name], "File"
	end

	-- Serveur : la valeur en vigueur part aux clients (attribut du module ; absent = le fichier).
	local function publish(name: string)
		local module = env.module
		if module == nil then
			return
		end
		local value, source = resolve(name)
		local ok, err = pcall(function()
			module:SetAttribute(name, if source == "File" then nil else value)
		end)
		if not ok then
			warnOnce(`attr:{name}`, `[LiveFeatures] attribut {name} pas posé : {err}`)
		end
	end

	-- Serveur : recalcule un interrupteur, le publie, prévient les écouteurs s'il a changé.
	local function apply(name: string)
		local value = resolve(name)
		local before = effective[name]
		effective[name] = value
		publish(name)
		if before ~= value then
			fire(name, value)
		end
	end

	-- Serveur : les valeurs booléennes de ConfigService, par interrupteur (les autres types : ignorés, une ligne).
	local function readConfig(snapshot: any): { [string]: boolean }
		local out: { [string]: boolean } = {}
		for name, fileValue in raw do
			if type(fileValue) == "boolean" then
				local key = settings.KeyPrefix .. name
				local ok, value = pcall(function(): any
					return snapshot:GetValue(key)
				end)
				if not ok then
					warnOnce(`read:{key}`, `[LiveFeatures] ConfigService : {key} illisible ({value}) : le fichier`)
				elseif type(value) == "boolean" then
					out[name] = value
				elseif value ~= nil then
					warnOnce(`type:{key}:{tostring(value)}`, `[LiveFeatures] ConfigService : {key} = {tostring(value)} n'est pas un booléen : ignoré, le fichier vaut {tostring(fileValue)}`)
				end
			end
		end
		return out
	end

	-- Serveur : prend les valeurs lues dans ConfigService. Au démarrage : tous les interrupteurs ; ensuite : Hot seul.
	local function takeConfig(values: { [string]: boolean }, atBoot: boolean)
		local changed: { string } = {}
		for name, fileValue in raw do
			if type(fileValue) ~= "boolean" then
				continue
			end
			local new = values[name]
			if new == fromConfig[name] then
				seen[name] = nil
				continue
			end
			if atBoot or hot[name] == true then
				fromConfig[name] = new
				apply(name)
				table.insert(changed, `{name} = {tostring(effective[name])}{if new == nil then " (fichier)" else ""}`)
			else
				local mark = tostring(new)
				if seen[name] ~= mark then
					seen[name] = mark
					env.print(`[LiveFeatures] {settings.KeyPrefix}{name} = {if new == nil then "(retirée)" else mark} dans ConfigService : pris au prochain serveur ({name} n'est pas dans Config/LiveFeatures.Hot ; ce serveur garde {tostring(effective[name])})`)
				end
			end
		end
		if #changed > 0 then
			table.sort(changed)
			local when = if atBoot then "au démarrage" else "à chaud"
			env.print(`[LiveFeatures] ConfigService {when} : {table.concat(changed, ", ")}`)
		end
	end

	local function fetch(): (boolean, any)
		local service = env.configService
		if service == nil then
			return false, "ConfigService absent"
		end
		return pcall(function(): any
			return service:GetConfigAsync()
		end)
	end

	local function subscribe(snapshot: any)
		local ok, err = pcall(function()
			snapshot.UpdateAvailable:Connect(function()
				local refreshed, why = pcall(function()
					snapshot:Refresh()
				end)
				if not refreshed then
					env.warn(`[LiveFeatures] ConfigService : Refresh en erreur ({why}) : rien ne change`)
					return
				end
				takeConfig(readConfig(snapshot), false)
			end)
		end)
		if not ok then
			env.warn(`[LiveFeatures] ConfigService : UpdateAvailable pas branché ({err}) : plus de changement à chaud`)
		end
	end

	local retryLater: () -> ()
	-- Serveur : une réponse de ConfigService arrivée après le démarrage (Hot seulement).
	local function lateAnswer(ok: boolean, snapshot: any)
		if ok and snapshot ~= nil then
			configState = "ok"
			env.print("[LiveFeatures] ConfigService joint après le démarrage : seuls les interrupteurs de Hot changent sur ce serveur")
			takeConfig(readConfig(snapshot), false)
			subscribe(snapshot)
		else
			configState = "error"
			warnOnce("late", `[LiveFeatures] ConfigService en erreur ({snapshot}) : le fichier ; nouvel essai toutes les {settings.RetrySeconds} s`)
			retryLater()
		end
	end
	retryLater = function()
		env.delay(settings.RetrySeconds, function()
			local ok, snapshot = fetch()
			lateAnswer(ok, snapshot)
		end)
	end

	-- Démarrage.
	if env.side == "server" then
		if env.configService ~= nil then
			configState = "waiting"
			local done, okFetch, answer = false, false, nil :: any
			env.spawn(function()
				local ok, snapshot = fetch()
				if booted then
					lateAnswer(ok, snapshot)
					return
				end
				done, okFetch, answer = true, ok, snapshot
			end)
			-- Attente bornée ; un contexte où l'on ne peut pas attendre (erreur de yield) vaut « pas de réponse ».
			pcall(function()
				local deadline = env.clock() + settings.BootWaitSeconds
				while not done and env.clock() < deadline do
					env.wait(0.05)
				end
			end)
			booted = true
			if not done then
				env.warn(`[LiveFeatures] ConfigService n'a pas répondu en {settings.BootWaitSeconds} s : le fichier ; sa réponse tardive ne vaudra que pour Config/LiveFeatures.Hot`)
			elseif okFetch and answer ~= nil then
				configState = "ok"
				takeConfig(readConfig(answer), true)
				subscribe(answer)
			else
				configState = "error"
				env.warn(`[LiveFeatures] ConfigService en erreur au démarrage ({answer}) : le fichier ; nouvel essai toutes les {settings.RetrySeconds} s`)
				retryLater()
			end
		else
			booted = true
			env.warn("[LiveFeatures] ConfigService absent : le fichier seul (commande d'admin seulement)")
		end
		local module = env.module
		if module ~= nil then
			pcall(function()
				module:SetAttribute(settings.ReadyAttribute, true)
			end)
		end
	elseif env.side == "client" then
		local module = env.module
		if module ~= nil then
			local ready = pcall(function()
				local deadline = env.clock() + settings.ClientWaitSeconds
				while module:GetAttribute(settings.ReadyAttribute) ~= true and env.clock() < deadline do
					env.wait(0.1)
				end
			end)
			local okReady, isReady = pcall(function(): any
				return module:GetAttribute(settings.ReadyAttribute)
			end)
			if not ready or not okReady or isReady ~= true then
				env.warn(`[LiveFeatures] état du serveur pas reçu en {settings.ClientWaitSeconds} s : le fichier, puis ce que le serveur enverra`)
			end
			local function read(name: string): any
				local ok, value = pcall(function(): any
					return module:GetAttribute(name)
				end)
				return if ok and type(value) == "boolean" then value else raw[name]
			end
			for name, fileValue in raw do
				if type(fileValue) == "boolean" then
					effective[name] = read(name)
				end
			end
			pcall(function()
				module.AttributeChanged:Connect(function(name: string)
					if not isFlag(name) then
						return
					end
					local value = read(name)
					if effective[name] ~= value then
						effective[name] = value
						fire(name, value)
					end
				end)
			end)
		end
	end

	-- Table vide, gelée, métatable gelée : `Features.X` lit `effective` (jamais exposée), toute écriture lève une erreur.
	local meta = {
		__index = function(_: any, key: any): any
			return effective[key]
		end,
		__newindex = function(_: any, key: any)
			error(`Config/Features est en lecture seule ({tostring(key)})`, 2)
		end,
		__iter = function(): (any, any)
			return next, table.clone(effective)
		end,
		__tostring = function(): string
			return "LiveFeatures"
		end,
	}
	table.freeze(meta)
	local proxy = setmetatable({}, meta)
	table.freeze(proxy)

	local live = {} :: Live
	live.features = proxy

	function live.Get(name: string): any
		return effective[name]
	end

	function live.Source(name: string): string
		if not isFlag(name) then
			return "File"
		end
		if env.side == "server" then
			local _, source = resolve(name)
			return source
		end
		local module = env.module
		if module == nil then
			return "File"
		end
		local ok, value = pcall(function(): any
			return module:GetAttribute(name)
		end)
		return if ok and type(value) == "boolean" then "Server" else "File"
	end

	function live.On(name: string): boolean
		if effective[name] == true then
			return true
		end
		return effective[name .. "Dev"] == true and env.isDev()
	end

	function live.OnChanged(fn: (name: string, value: any) -> ()): () -> ()
		table.insert(listeners, fn)
		return function()
			local index = table.find(listeners, fn)
			if index ~= nil then
				table.remove(listeners, index)
			end
		end
	end

	-- Qui est admin : la règle que le serveur branche (LiveFeaturesService : AdminService.IsAdmin, Config/Admin) ;
	-- pas de liste à part ici, et un require d'AdminService depuis ce module serait circulaire (il lit Config/Features).
	local adminRule: ((player: any) -> boolean)? = nil

	function live.SetAdminRule(rule: (player: any) -> boolean)
		if env.side == "server" and type(rule) == "function" then
			adminRule = rule
		end
	end

	function live.IsAdmin(player: any): boolean
		local rule = adminRule
		if env.side ~= "server" or rule == nil then
			return false
		end
		local ok, allowed = pcall(rule, player)
		return ok and allowed == true
	end

	function live.SetAdmin(player: any, name: string, value: boolean?): (boolean, string)
		if env.side ~= "server" then
			return false, messages.ServerOnly
		end
		local okWho, who = pcall(function(): string
			return `{player.Name} ({player.UserId})`
		end)
		local label = if okWho then who else "?"
		if not live.IsAdmin(player) then
			env.warn(`[LiveFeatures] refusé : {label} n'est pas admin des interrupteurs ({tostring(name)})`)
			return false, messages.NotAdmin
		end
		if not isFlag(name) then
			return false, string.format(messages.Unknown, tostring(name))
		end
		if hot[name] ~= true then
			return false, string.format(messages.NotHot, name)
		end
		if value ~= nil and type(value) ~= "boolean" then
			return false, messages.BadValue
		end
		fromAdmin[name] = value :: any
		apply(name)
		local now, source = resolve(name)
		local how = if value == nil then "surcharge d'admin retirée, " .. source else "admin, ce serveur"
		env.print(`[LiveFeatures] {label} : {name} = {tostring(now)} ({how})`)
		if value == nil then
			return true, string.format(messages.Cleared, name, tostring(now), source)
		end
		return true, string.format(messages.Set, name, tostring(now))
	end

	function live.Status(): Status
		local overrides: { string } = {}
		for name in raw do
			if isFlag(name) then
				local source = live.Source(name)
				if source ~= "File" then
					table.insert(overrides, `{name} = {tostring(effective[name])} ({source})`)
				end
			end
		end
		table.sort(overrides)
		local hotList: { string } = {}
		for name, on in hot do
			if on == true then
				table.insert(hotList, name)
			end
		end
		table.sort(hotList)
		return { side = env.side, config = configState, overrides = overrides, hot = hotList }
	end

	return live
end

-- L'environnement du vrai jeu, ou nil hors d'un jeu lancé (Edit, outils) ou si Config/LiveFeatures.Enabled est faux.
local function realEnv(module: any): Env?
	if Settings.Enabled ~= true then
		return nil
	end
	local okRun, RunService = pcall(function(): any
		return game:GetService("RunService")
	end)
	if not okRun or RunService == nil then
		return nil
	end
	local okRunning, running = pcall(function(): any
		return RunService:IsRunning()
	end)
	if not okRunning or running ~= true then
		return nil
	end
	local isServer = RunService:IsServer()
	local configService: any = nil
	if isServer then
		local okService, service = pcall(function(): any
			return game:GetService("ConfigService")
		end)
		configService = if okService then service else nil
	end
	local devCache: boolean? = nil
	return {
		side = if isServer then "server" else "client",
		settings = Settings,
		module = module,
		configService = configService,
		isDev = function(): boolean
			if devCache == nil then
				local ok, productIds = pcall(function(): any
					return require(script.Parent.Config.ProductIds) :: any
				end)
				devCache = ok and type(productIds) == "table" and productIds.IsDev == true
			end
			return devCache == true
		end,
		clock = os.clock,
		wait = function(seconds: number)
			task.wait(seconds)
		end,
		spawn = function(fn: () -> ())
			task.spawn(fn)
		end,
		delay = function(seconds: number, fn: () -> ())
			task.delay(seconds, fn)
		end,
		print = function(message: string)
			print(message)
		end,
		warn = function(message: string)
			warn(message)
		end,
	}
end

-- Appelé par Config/Features (une fois, à son premier require) : la table vivante, ou `raw` hors d'un jeu lancé.
function LiveFeatures.Wrap(raw: { [string]: any }, module: any): any
	if current ~= nil then
		return current.features
	end
	local env = realEnv(module)
	if env == nil then
		return raw
	end
	local live = LiveFeatures.new(raw, env)
	current = live
	return live.features
end

-- L'instance du jeu (Config/Features chargé d'abord s'il ne l'est pas : c'est lui qui appelle Wrap), ou nil.
local function live(): Live?
	if current == nil then
		pcall(function()
			require(script.Parent.Config.Features)
		end)
	end
	return current
end

local function fileValue(name: string): any
	local ok, features = pcall(function(): any
		return require(script.Parent.Config.Features) :: any
	end)
	return if ok and type(features) == "table" then features[name] else nil
end

function LiveFeatures.Get(name: string): any
	local l = live()
	return if l ~= nil then l.Get(name) else fileValue(name)
end

function LiveFeatures.On(name: string): boolean
	local l = live()
	if l ~= nil then
		return l.On(name)
	end
	if fileValue(name) == true then
		return true
	end
	if fileValue(name .. "Dev") ~= true then
		return false
	end
	local ok, productIds = pcall(function(): any
		return require(script.Parent.Config.ProductIds) :: any
	end)
	return ok and type(productIds) == "table" and productIds.IsDev == true
end

function LiveFeatures.Source(name: string): string
	local l = live()
	return if l ~= nil then l.Source(name) else "File"
end

function LiveFeatures.OnChanged(fn: (name: string, value: any) -> ()): () -> ()
	local l = live()
	if l == nil then
		return function() end
	end
	return l.OnChanged(fn)
end

function LiveFeatures.SetAdminRule(rule: (player: any) -> boolean)
	local l = live()
	if l ~= nil then
		l.SetAdminRule(rule)
	end
end

function LiveFeatures.IsAdmin(player: any): boolean
	local l = live()
	return l ~= nil and l.IsAdmin(player)
end

function LiveFeatures.SetAdmin(player: any, name: string, value: boolean?): (boolean, string)
	local l = live()
	if l == nil then
		return false, Settings.Messages.Off
	end
	return l.SetAdmin(player, name, value)
end

function LiveFeatures.Status(): Status?
	local l = live()
	return if l ~= nil then l.Status() else nil
end

return LiveFeatures
