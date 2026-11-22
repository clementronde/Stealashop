--!strict
-- WheelService (DEV-141 ; vague 80, a266 ; L-165 point 3) : roue de la fortune du hub, un tour gratuit par jour UTC.
-- Valeurs : Config/Wheel (V0 proposés, Cantin, 20/11). Client : WheelController (écran UI_Wheel de Clément, zone
-- WheelZone du modèle ENV_Hub_Wheel). Coupé par Features.Wheel : coupé, aucun attribut, SpinWheel est ignoré.
--
-- Serveur autoritaire : le client ne fait que demander un tour (SpinWheel(), sans argument, débit contrôlé par Net).
-- Le serveur vérifie qu'un tour est permis (tour gratuit du jour UTC pas encore pris, sinon un tour en plus gardé),
-- tire le secteur avec les poids de Config/Wheel, donne le lot (Prize/Grant), note le tour, puis envoie
-- WheelResult(secteur, message) à ce joueur seul : le client anime la roue jusqu'au secteur déjà décidé. Le tout dans
-- la même exécution, sans yield : un double clic trouve le tour déjà pris.
-- Lot refusé (inventaire d'objets plein, stock de potions plein) : Config/Wheel.Fallback est donné à la place et le
-- message le dit ; si même le repli est refusé, le tour n'est pas pris (Notify). Un don qui lève une erreur prend le
-- tour quand même (avertissement) : jamais deux fois le même don.
-- a309 (Cantin, 22/11) : BOX et RARE BOX donnent un colis de zone (Prize ZoneBox, règles des cadeaux de 15 et 60 min,
-- Config/Rewards.ZoneBox), ouvert par la scène de la caisse exclusive quand la roue s'arrête (SpinSeconds) : Result vide ;
-- sans scène (hors zone safe…), le message en notification.
--
-- Profil (champ facultatif Wheel, sans nouvelle version, créé et réparé ici) :
--   Wheel = { FreeDay = jour UTC du dernier tour gratuit (0 = jamais), Extra = tours en plus gardés }
-- Tours en plus en Robux : coupés tant que Config/Wheel.ExtraSpin.ProductId = 0 ; WheelService.AddSpins est prêt
-- pour le jour où MonetizationService aura un produit (rien n'est branché).
--
-- Télémétrie : argent gagné en économie (genre WheelReward, SKU Wheel_<secteur>) ; chaque tour en événement WheelSpin
-- (champs Sector, Gift, Spin = Free ou Extra).
--
-- Attributs du Player (Config/Wheel.Attributes, lus par WheelController) : WheelFreeReady, WheelNextFreeAt (heure
-- serveur du prochain minuit UTC), WheelExtraSpins.
--
-- API (côté serveur) :
--   WheelService.GetState(player) -> { FreeReady, Extra, FreeDay }?   nil sans profil ou roue coupée
--   WheelService.AddSpins(player, count) -> boolean                    ajoute des tours en plus (MaxExtra au plus)
--   WheelService.Draw(rng?) -> number                                  tire un secteur (1 à 8), sans rien donner
--
-- Tester dans Studio (barre de commande serveur ; hors de Studio, l'attribut n'est pas écouté) :
--   workspace:SetAttribute("WheelTest", "days 1")            avance l'horloge de la roue d'un jour
--   workspace:SetAttribute("WheelTest", "reset <joueur>")    rend le tour gratuit du jour
--   workspace:SetAttribute("WheelTest", "spins <joueur> 3")  pose 3 tours en plus
--   workspace:SetAttribute("WheelTest", "force 8")           le prochain tour tombe sur le secteur 8

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Features = require(Shared.Config.Features)
local Wheel = require(Shared.Config.Wheel)
local Net = require(Shared.Net.Net)
local ProfileTypes = require(Shared.Types.Profile)

local DataService = require(script.Parent.DataService)
local TelemetryService = require(script.Parent.TelemetryService)
local Grant = require(script.Parent.Prize.Grant)
local MonetizationService = require(script.Parent.MonetizationService) -- a309 : ouverture des colis de zone

type WheelData = ProfileTypes.Wheel

local DAY = Wheel.DayLength
local ATTRIBUTES = Wheel.Attributes
local MESSAGES = Wheel.Messages
local IS_STUDIO = RunService:IsStudio()
-- V0 proposé (Cantin, 20/11), comme RewardService : écart (s) au-delà duquel WheelNextFreeAt est réécrit.
local DRIFT = 1.5

local WheelService = {}
-- Après QuestService (230) ; rien ne dépend de l'ordre.
WheelService.Priority = 232

local present: { [Player]: boolean } = {}
local clockOffset = 0 -- secondes ajoutées à os.time() (test Studio « days »)
local forced: number? = nil -- test Studio « force »
local warned: { [string]: boolean } = {}
local rng = Random.new()

local function log(message: string)
	if IS_STUDIO then
		print(`[WheelService] {message}`)
	end
end

local function warnOnce(key: string, message: string)
	if not warned[key] then
		warned[key] = true
		warn(`[WheelService] {message}`)
	end
end

local function notify(player: Player, message: string, kind: string)
	local ok, err = pcall(function()
		Net.Server.Notify:Fire(player, message, kind)
	end)
	if not ok then
		warn(`[WheelService] Notify vers {player.Name} : {err}`)
	end
end

local function on(): boolean
	return Features.Wheel == true
end

local function now(): number
	return os.time() + clockOffset
end

local function today(): number
	return now() // DAY
end

local function finite(value: any): number
	return if type(value) == "number" and value == value and math.abs(value) < math.huge then value else 0
end

local function setAttribute(player: Player, name: string, value: any)
	if player.Parent == Players and player:GetAttribute(name) ~= value then
		player:SetAttribute(name, value)
	end
end

-- Wheel du profil, créé ou réparé. nil sans profil. Sans yield.
local function wheelOf(player: Player): WheelData?
	local data = DataService.Get(player)
	if data == nil then
		return nil
	end
	local wheel: any = (data :: any).Wheel
	if type(wheel) ~= "table" then
		if wheel ~= nil then
			warnOnce(`wheel:{player.UserId}`, `{player.Name} : Wheel illisible dans le profil, remis à zéro`)
		end
		wheel = {}
		data.Wheel = wheel
	end
	wheel.FreeDay = math.floor(finite(wheel.FreeDay))
	wheel.Extra = math.clamp(math.floor(finite(wheel.Extra)), 0, Wheel.ExtraSpin.MaxExtra)
	return wheel :: WheelData
end

-- Le tour gratuit du jour attend (un FreeDay dans le futur, horloge qui recule : pas de tour).
local function freeReady(wheel: WheelData): boolean
	return wheel.FreeDay < today()
end

local function publish(player: Player)
	if not on() then
		return
	end
	local wheel = wheelOf(player)
	if wheel == nil then
		return
	end
	setAttribute(player, ATTRIBUTES.FreeReady, freeReady(wheel))
	setAttribute(player, ATTRIBUTES.ExtraSpins, wheel.Extra)
	local nextAt = Workspace:GetServerTimeNow() + (DAY - now() % DAY)
	local current = player:GetAttribute(ATTRIBUTES.NextFreeAt)
	if type(current) ~= "number" or math.abs(current - nextAt) > DRIFT then
		setAttribute(player, ATTRIBUTES.NextFreeAt, nextAt)
	end
end

local function draw(random: Random?): number
	local total = 0
	for _, sector in Wheel.Sectors do
		total += math.max(0, sector.Weight)
	end
	local pick = (random or rng):NextNumber() * total
	for index, sector in Wheel.Sectors do
		pick -= math.max(0, sector.Weight)
		if pick < 0 then
			return index
		end
	end
	return #Wheel.Sectors
end

local function onSpinWheel(player: Player)
	if not on() or not present[player] then
		return
	end
	local wheel = wheelOf(player)
	if wheel == nil then
		return
	end
	local day = today()
	local free = freeReady(wheel)
	if not free and wheel.Extra <= 0 then
		notify(player, MESSAGES.NoSpin, "Warning")
		publish(player)
		return
	end
	local index = forced or draw()
	forced = nil
	local sector = Wheel.Sectors[index]
	local ok, given, message, amount, _reason, reveal = pcall(Grant.Give :: any, player, sector.Prize)
	local giftKind: string = sector.Prize.Kind
	if ok and not given then
		-- Lot refusé (inventaire ou stock plein) : le repli à la place.
		local okFallback, givenFallback, messageFallback, amountFallback = pcall(Grant.Give :: any, player, Wheel.Fallback)
		if not okFallback or not givenFallback then
			log(`{player.Name} : secteur {index} refusé ({message}), repli refusé aussi : tour pas pris`)
			notify(player, message, "Warning")
			publish(player)
			return
		end
		message = string.format(MESSAGES.Fallback, messageFallback)
		amount = amountFallback
		reveal = nil
		giftKind = Wheel.Fallback.Kind
	elseif not ok then
		warn(`[WheelService] {player.Name} : erreur pendant le don du secteur {index} ({given}) : tour pris quand même, à compenser à la main si rien n'est arrivé`)
		message = ""
		amount = 0
		reveal = nil
	end
	if free then
		wheel.FreeDay = day
	else
		wheel.Extra -= 1
	end
	if amount > 0 then
		TelemetryService.LogEconomy(player, "WheelReward", amount, `Wheel_{index}`)
	end
	TelemetryService.LogEvent(player, "WheelSpin", { `Sector - {index}`, `Gift - {giftKind}`, `Spin - {if free then "Free" else "Extra"}` })
	log(`{player.Name} : secteur {index} ({message})`)
	-- a309 (Cantin, 22/11) : un colis de zone (BOX, RARE BOX) s'ouvre tout de suite, avec la scène de la caisse exclusive
	-- (MonetizationService.StartGiftReveal, zone safe seulement), quand la roue s'arrête (Config/Wheel.SpinSeconds,
	-- l'animation du client) ; Result reste vide pour ne pas dire l'objet avant la scène. Pas de scène (hors zone safe,
	-- coupée, joueur parti…) : le message en notification.
	local shown: Grant.Reveal? = if ok and type(reveal) == "table" then reveal else nil
	local resultMessage = if shown then "" else message
	local fired, err = pcall(function()
		Net.Server.WheelResult:Fire(player, index, resultMessage)
	end)
	if shown then
		local gift: Grant.Reveal = shown
		local text: string = message
		task.delay(Wheel.SpinSeconds, function()
			local okReveal, started = pcall(MonetizationService.StartGiftReveal, player, gift.ItemId, gift.StartRarity, gift.Chance, gift.Effect)
			if not (okReveal and started == true) and player.Parent == Players then
				notify(player, text, "Info")
			end
		end)
	end
	if not fired then
		warn(`[WheelService] WheelResult vers {player.Name} : {err}`)
	end
	publish(player)
end

local function onProfileLoaded(player: Player)
	if DataService.Get(player) == nil then
		return
	end
	present[player] = true
	publish(player)
end

local function forget(player: Player)
	present[player] = nil
end

local function tick()
	if not on() then
		return
	end
	for player in present do
		if DataService.Get(player) == nil then
			forget(player)
			continue
		end
		publish(player)
	end
end

------------------------------------------------------------------------------
-- Crochet de test (Studio seulement)
------------------------------------------------------------------------------

local function findPlayer(who: string): Player?
	local userId = tonumber(who)
	for _, player in Players:GetPlayers() do
		if player.Name == who or (userId ~= nil and player.UserId == userId) then
			return player
		end
	end
	return nil
end

local function onTestAttribute()
	local value = Workspace:GetAttribute(Wheel.TestAttribute)
	if value == nil then
		return
	end
	Workspace:SetAttribute(Wheel.TestAttribute, nil)
	local words: { string } = {}
	for word in string.gmatch(tostring(value), "%S+") do
		table.insert(words, word)
	end
	local command = words[1]
	local number = tonumber(words[#words])
	if command == "days" and number and number >= 1 then
		clockOffset += math.floor(number) * DAY
		print(`[WheelService] test : horloge de la roue avancée (jour UTC {today()})`)
		tick()
		return
	end
	if command == "force" and number and Wheel.Sectors[number] then
		forced = number
		print(`[WheelService] test : le prochain tour tombe sur le secteur {number}`)
		return
	end
	local player = if words[2] then findPlayer(words[2]) else nil
	local wheel = if player then wheelOf(player) else nil
	if player and wheel then
		if command == "reset" then
			wheel.FreeDay = 0
			print(`[WheelService] test : tour gratuit de {player.Name} rendu`)
			publish(player)
			return
		elseif command == "spins" and number then
			wheel.Extra = math.clamp(math.floor(number), 0, Wheel.ExtraSpin.MaxExtra)
			print(`[WheelService] test : {player.Name} a {wheel.Extra} tour(s) en plus`)
			publish(player)
			return
		end
	end
	warn(`[WheelService] test : « {tostring(value)} » : attendu « days <n> », « reset <joueur> », « spins <joueur> <n> » ou « force <secteur> »`)
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------

function WheelService.GetState(player: Player): { FreeReady: boolean, Extra: number, FreeDay: number }?
	if not on() then
		return nil
	end
	local wheel = wheelOf(player)
	if wheel == nil then
		return nil
	end
	return { FreeReady = freeReady(wheel), Extra = wheel.Extra, FreeDay = wheel.FreeDay }
end

function WheelService.AddSpins(player: Player, count: number): boolean
	local wheel = wheelOf(player)
	if wheel == nil or type(count) ~= "number" or count < 1 or count ~= count then
		return false
	end
	wheel.Extra = math.clamp(wheel.Extra + math.floor(count), 0, Wheel.ExtraSpin.MaxExtra)
	publish(player)
	return true
end

function WheelService.Draw(random: Random?): number
	return draw(random)
end

function WheelService.Init()
	Net.Server.SpinWheel:Connect(onSpinWheel)
	DataService.OnProfileLoaded(onProfileLoaded)
	DataService.OnProfileReleasing(forget)
	Players.PlayerRemoving:Connect(function(player: Player)
		task.defer(forget, player)
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed < Wheel.Tick then
			return
		end
		elapsed = 0
		local ok, err = pcall(tick :: any) -- :: any : sans lui, l'ancien solveur croit que pcall ne renvoie qu'une valeur
		if not ok then
			warn(`[WheelService] horloge : {err}`)
		end
	end)
	if IS_STUDIO then
		Workspace:GetAttributeChangedSignal(Wheel.TestAttribute):Connect(onTestAttribute)
	end
	log(`{#Wheel.Sectors} secteurs, un tour gratuit par jour UTC ({if on() then "allumée" else "coupée"})`)
end

return WheelService
