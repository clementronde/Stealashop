--!strict
-- Announce (vague 73, a254, L-240 point 3 ; serveur) : construit et envoie les annonces à tout le serveur
-- (Config/Announce). Rangé dans Shared, comme Format, pour que tout service le requière sans dépendance de plus.
-- Une annonce = remote Announce(message, detail, icon, plain) : message en RichText, detail une petite ligne,
-- icon = noms de Decals à essayer dans l'ordre, séparés par « | » (vide : l'icône de Clément), plain = le même
-- texte sans balises (repli Notify du client). Config/Announce.Enabled = false : Notify(plain, NotifyKind) comme
-- avant, et ni l'annonce de jour ni celle du vol (DayBoxMinRarity et StealMinRarity rendent nil).
--
-- API (serveur) :
--   Announce.send(message, detail?, icon?, plain?, except?)   à tous les joueurs sauf ceux de except
--   Announce.rarityText(rarity) -> string                     « <font color="#FFC21A">LEGENDARY</font> »
--   Announce.boxes(rarity, store, zone, count, night)         annonces 1 et 2 (textes de Config/Unbox.NightBox*)
--   Announce.dayBoxMinRarity() -> string?                     seuil de l'annonce de jour, nil si coupée
--   Announce.steal(thief, victim, itemId, income)             annonce 3, si la rareté atteint StealMinRarity
--   Announce.serverLuck(buyer, multiplier, minutes, running?, icon?, plain)   annonce 4 ; plain = texte d'avant
--   Announce.strip(text) -> string                             texte sans balises RichText
--   Announce.valueOn() -> boolean                               a475 (L-372) : annonces de valeur allumées (Features)
--   Announce.itemValue(template, detail, player, itemId, mutation, value, except?)   a475 : objet de grande valeur

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Settings = require(Config:WaitForChild("Announce"))
local Unbox = require(Config:WaitForChild("Unbox"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Items = require(Config:WaitForChild("Items"))

local Announce = {}

local function net(): any
	return require(Shared:WaitForChild("Net"):WaitForChild("Net")) :: any
end

local function fill(template: string, values: { [string]: string }): string
	return (string.gsub(template, "{(%a+)}", function(key: string): string
		return values[key] or `\{{key}\}`
	end))
end

function Announce.strip(text: string): string
	return (string.gsub(text, "<[^>]*>", ""))
end

local function hex(color: Color3): string
	return string.format("%02X%02X%02X", math.round(color.R * 255), math.round(color.G * 255), math.round(color.B * 255))
end

function Announce.rarityText(rarity: Rarities.Rarity): string
	return string.format(Settings.RarityTag, hex(rarity.Color), rarity.DisplayNameUpper)
end

function Announce.send(message: string, detail: string?, icon: string?, plain: string?, except: { Player }?)
	local text = plain or Announce.strip(message)
	local remotes = net()
	for _, player in Players:GetPlayers() do
		if except == nil or table.find(except, player) == nil then
			local ok, err = pcall(function()
				if Settings.Enabled == true then
					remotes.Server.Announce:Fire(player, message, detail or "", icon or "", text)
				else
					remotes.Server.Notify:Fire(player, text, Settings.NotifyKind)
				end
			end)
			if not ok then
				warn(`[Announce] vers {player.Name} : {err}`)
			end
		end
	end
end

function Announce.dayBoxMinRarity(): string?
	return if Settings.Enabled == true and Settings.DayBoxEnabled == true then Settings.DayBoxMinRarity else nil
end

function Announce.boxes(rarity: Rarities.Rarity, store: string, zone: number, count: number, night: boolean)
	local template = if count == 1 then Unbox.NightBoxText else Unbox.NightBoxesText
	local values = { rarity = rarity.DisplayNameUpper, store = store, count = tostring(count) }
	local plain = fill(template, values)
	values.rarity = Announce.rarityText(rarity)
	local detail = fill(if night then Settings.NightDetail else Settings.DayDetail, { zone = tostring(zone) })
	Announce.send(fill(template, values), detail, Settings.BoxIconPrefix .. rarity.Id, plain)
end

function Announce.steal(thief: Player, victim: Player, itemId: string, income: string)
	local item = Items.ById[itemId]
	local rarity = if item then Rarities.ById[item.Rarity] else nil
	local minimum = Rarities.ById[Settings.StealMinRarity]
	if Settings.Enabled ~= true or Settings.StealEnabled ~= true or item == nil or rarity == nil or minimum == nil then
		return
	end
	if rarity.Order < minimum.Order then
		return
	end
	-- a475 (L-372 point 3) : la valeur dans la phrase (StealValueText), Detail vide ; `income` vaut « +$5K/s » (Format.income).
	local withValue = Announce.valueOn() and type((Settings :: any).StealValueText) == "string"
	local message = fill(if withValue then (Settings :: any).StealValueText else Settings.StealText, {
		thief = thief.DisplayName,
		victim = victim.DisplayName,
		item = item.DisplayName,
		a = if string.find(rarity.DisplayNameUpper, "^[AEIOU]") then "an" else "a",
		rarity = Announce.rarityText(rarity),
		value = (string.gsub(income, "^%+", "")),
	})
	Announce.send(message, if withValue then "" else income, Settings.ItemIconPrefix .. itemId, nil, { thief, victim })
end

function Announce.serverLuck(buyer: Player, multiplier: number, minutes: number, running: number?, icon: string?, plain: string)
	local length = `{minutes} min`
	local luck = string.format('<font color="#%s">×%d LUCK</font>', Settings.ServerLuckColor, multiplier)
	local message = fill(Settings.ServerLuckText, { buyer = buyer.DisplayName, luck = luck })
	local detail = if running
		then fill(Settings.ServerLuckQueuedDetail, { current = `×{running}`, length = length })
		else fill(Settings.ServerLuckDetail, { length = length })
	local icons = if icon then `{icon}|{Settings.ServerLuckIcon}` else Settings.ServerLuckIcon
	Announce.send(message, detail, icons, plain)
end

-- a475 (L-372) : annonces de valeur allumées (Features.ValueAnnounce partout, ou ValueAnnounceDev dans le jeu DEV,
-- Config/ProductIds.IsDev) et annonces allumées (Config/Announce.Enabled). Modules absents (bancs) : false.
function Announce.valueOn(): boolean
	if Settings.Enabled ~= true then
		return false
	end
	local ok, on = pcall(function(): boolean
		local features = require(Config:FindFirstChild("Features") :: ModuleScript) :: any
		if features.ValueAnnounce == true then
			return true
		end
		if features.ValueAnnounceDev ~= true then
			return false
		end
		local ids = Config:FindFirstChild("ProductIds")
		return ids ~= nil and (require(ids :: ModuleScript) :: any).IsDev == true
	end)
	return ok and on == true
end

-- a475 (L-372 points 1 et 2) : « Alice got a MYTHIC Gold Cat worth $225B/s! » (template = Config/Announce.SecuredText
-- ou CarryText), icône de l'objet, à tous sauf ceux de `except`. La valeur et le seuil sont décidés par l'appelant
-- (CelebrationService, serveur). Rien si l'objet ou sa rareté est inconnu.
function Announce.itemValue(template: string, detail: string, player: Player, itemId: string, mutation: any, value: number, except: { Player }?)
	local item = Items.ById[itemId]
	local rarity = if item then Rarities.ById[item.Rarity] else nil
	if item == nil or rarity == nil then
		return
	end
	local name = item.DisplayName
	local okName, named = pcall(function(): string
		return (require(Config:FindFirstChild("Mutations") :: ModuleScript) :: any).ItemName(name, mutation)
	end)
	local okValue, money = pcall(function(): string
		return (require(Shared:FindFirstChild("Format") :: ModuleScript) :: any).money(value)
	end)
	local values = {
		player = player.DisplayName,
		item = if okName and type(named) == "string" then named else name,
		a = if string.find(rarity.DisplayNameUpper, "^[AEIOU]") then "an" else "a",
		rarity = rarity.DisplayNameUpper,
		value = (if okValue and type(money) == "string" then money else `${math.floor(value)}`) .. "/s",
	}
	local plain = fill(template, values)
	values.rarity = Announce.rarityText(rarity)
	Announce.send(fill(template, values), detail, Settings.ItemIconPrefix .. itemId, plain, except)
end

return Announce
