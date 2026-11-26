--!strict
-- CelebrationService (a475, liaison L-371 et L-372, session de test de Clément du 25/11) : ce que tout le serveur voit
-- quand un objet est pris ou ramené. Aucun remote reçu : tout part des écouteurs de CarryService.
--
--   1. Objet ramené en zone safe (CarryService.OnCarryEnded, résultat « Consumed » : rangé par UnboxService, ou volé
--      et déposé par PvPService) : remote Fireworks à tous les joueurs (Features.SecuredFireworks, ou
--      SecuredFireworksDev dans le jeu DEV) ; VfxController tire les feux aux points FireworksPoint (Config/Vfx.Fireworks,
--      un seul tir à la fois par point, côté client).
--   2. Annonces de valeur (Features.ValueAnnounce ou ValueAnnounceDev : Shared/Announce.valueOn) dans UI_Announce, à
--      partir de Config/Announce.ValueMinIncome $/s (valeur de l'objet, mutation et poids compris, comme BB_Carry) :
--      a. ramené en zone safe : SecuredText, aux autres joueurs (SecuredToSelf : à lui aussi). Un objet volé à un vrai
--         joueur n'en a pas : l'annonce du vol (Announce.steal, valeur comprise) part déjà au dépôt ;
--      b. en fuite (CarryService.OnCarryStarted) : CarryText, une fois par objet (le même objet repris après une chute
--         ou passé à un autre n'est pas réannoncé), à tous sauf le porteur et sa victime.
--      Anti-spam : Config/Announce.ValueGap s au moins entre deux annonces du même genre (a, b) ; celle de trop part pas.
--
-- API (serveur, bancs) :
--   CelebrationService.ValueOf(payload) -> number?        $/s de l'objet porté (nil : objet inconnu)
--   CelebrationService.GetState() -> { Fireworks: number, Secured: number, Carry: number }   envois depuis le démarrage

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Features = require(Config:WaitForChild("Features")) :: any
local Settings = require(Config:WaitForChild("Announce")) :: any
local Formulas = require(Config:WaitForChild("Formulas"))
local Mutations = require(Config:WaitForChild("Mutations"))
local Announce = require(Shared:WaitForChild("Announce"))

local CarryService = require(script.Parent:WaitForChild("CarryService")) :: any

local CONSUMED = "Consumed"
local BOT_VICTIM = 0 -- VictimUserId d'un objet volé au bot (PvPService)

local CelebrationService = {}

local lastAt: { [string]: number } = {} -- dernier envoi de chaque genre d'annonce (os.clock)
local announced: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any -- payloads déjà annoncés en fuite
local counts = { Fireworks = 0, Secured = 0, Carry = 0 }

local function isDev(): boolean
	local module = Config:FindFirstChild("ProductIds")
	if module == nil then
		return false
	end
	local ok, ids = pcall(require, module :: ModuleScript)
	return ok and type(ids) == "table" and (ids :: any).IsDev == true
end

local function fireworksOn(): boolean
	return Features.SecuredFireworks == true or (Features.SecuredFireworksDev == true and isDev())
end

local function net(): any
	return require(Shared:WaitForChild("Net"):WaitForChild("Net")) :: any
end

function CelebrationService.ValueOf(payload: any): number?
	if type(payload) ~= "table" or type(payload.ItemId) ~= "string" then
		return nil
	end
	if payload.Kind == "PlayerItem" then
		local income = payload.Income
		return if type(income) == "number" and income == income and income >= 0 then income else nil
	end
	local ok, value = pcall(function(): number
		return Formulas.RoundIncome(Formulas.ItemIncome(payload.ItemId) * Mutations.IncomeMultiplier(payload.Mutation, payload.Weight)) -- a493
	end)
	return if ok and type(value) == "number" and value == value then value else nil
end

-- L'annonce du genre `kind` peut partir maintenant (ValueGap), et prend sa place.
local function takeSlot(kind: string): boolean
	local gap = if type(Settings.ValueGap) == "number" then Settings.ValueGap else 0
	local now = os.clock()
	local last = lastAt[kind]
	if last ~= nil and now - last < gap then
		return false
	end
	lastAt[kind] = now
	return true
end

-- Valeur de l'objet si elle atteint le seuil et que les annonces de valeur sont allumées ; sinon nil.
local function bigValue(payload: any): number?
	if not Announce.valueOn() then
		return nil
	end
	local minimum = if type(Settings.ValueMinIncome) == "number" then Settings.ValueMinIncome else math.huge
	local value = CelebrationService.ValueOf(payload)
	return if value ~= nil and value >= minimum then value else nil
end

local function victimOf(payload: any): Player?
	if payload.Kind ~= "PlayerItem" or type(payload.VictimUserId) ~= "number" or payload.VictimUserId == BOT_VICTIM then
		return nil
	end
	return Players:GetPlayerByUserId(payload.VictimUserId)
end

local function onEnded(player: Player, payload: any, result: string, _reason: string)
	if result ~= CONSUMED or type(payload) ~= "table" then
		return
	end
	if fireworksOn() then
		local ok, err = pcall(function()
			net().Server.Fireworks:FireAll()
		end)
		if ok then
			counts.Fireworks += 1
		else
			warn(`[CelebrationService] Fireworks : {err}`)
		end
	end
	-- Objet volé à un vrai joueur : l'annonce du vol (Announce.steal) part déjà au dépôt.
	if payload.Kind == "PlayerItem" and payload.VictimUserId ~= BOT_VICTIM then
		return
	end
	local value = bigValue(payload)
	if value == nil or type(Settings.SecuredText) ~= "string" or not takeSlot("Secured") then
		return
	end
	local except = if Settings.SecuredToSelf == true then nil else { player }
	Announce.itemValue(Settings.SecuredText, Settings.SecuredDetail or "", player, payload.ItemId, payload.Mutation, value, except)
	counts.Secured += 1
end

local function onStarted(player: Player, payload: any)
	if type(payload) ~= "table" or announced[payload] then
		return
	end
	local value = bigValue(payload)
	if value == nil or type(Settings.CarryText) ~= "string" then
		return
	end
	announced[payload] = true -- même sans place (ValueGap) : jamais annoncé en retard
	if not takeSlot("Carry") then
		return
	end
	local except = { player }
	local victim = victimOf(payload)
	if victim then
		table.insert(except, victim)
	end
	Announce.itemValue(Settings.CarryText, Settings.CarryDetail or "", player, payload.ItemId, payload.Mutation, value, except)
	counts.Carry += 1
end

function CelebrationService.GetState(): { Fireworks: number, Secured: number, Carry: number }
	return { Fireworks = counts.Fireworks, Secured = counts.Secured, Carry = counts.Carry }
end

function CelebrationService.Start()
	CarryService.OnCarryEnded(function(player: Player, payload: any, result: string, reason: string)
		local ok, err = pcall(onEnded :: any, player, payload, result, reason)
		if not ok then
			warn(`[CelebrationService] objet ramené : {err}`)
		end
	end)
	CarryService.OnCarryStarted(function(player: Player, payload: any)
		local ok, err = pcall(onStarted :: any, player, payload)
		if not ok then
			warn(`[CelebrationService] objet en fuite : {err}`)
		end
	end)
end

return CelebrationService
