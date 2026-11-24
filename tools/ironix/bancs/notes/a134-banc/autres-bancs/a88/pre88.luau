---------------------------------------------------------------- a88 : bouchons (vague 28, potions)
-- TelemetryService : appels notés dans TELEMETRY (comme pre84).
TELEMETRY = {}
SOURCES["stub/TelemetryService"] = [==[
local TelemetryService = {}
function TelemetryService.LogEconomy(player, kind, amount, sku, fields)
	table.insert(TELEMETRY, { what = "economy", player = player, kind = kind, amount = amount, sku = sku, fields = fields })
	return true
end
function TelemetryService.LogEvent(player, key, fields, value)
	table.insert(TELEMETRY, { what = "event", player = player, key = key, fields = fields })
	return true
end
return TelemetryService
]==]
-- GuardService : seul le point d'accroche IsHiddenFromNight (le vrai est vérifié par le scénario guard).
SOURCES["stub/GuardService"] = [==[
local GuardService = {}
function GuardService.IsHiddenFromNight(player)
	return false
end
return GuardService
]==]
-- Service de test chargé AVANT PotionService (Priority 50) : ses accroches ×3 pour « Cy » doivent être gardées
-- (PotionService multiplie celles d'avant, sans les écraser).
SOURCES["stub/AaBoostService"] = [==[
local AaBoostService = { Priority = 50 }
function AaBoostService.Init()
	local Services = script.Parent
	local Display = require(Services.DisplayService)
	local Window = require(Services.WindowService)
	local Guard = require(Services.GuardService)
	local baseIncome = Display.GetIncomeMultiplier
	Display.GetIncomeMultiplier = function(player)
		return baseIncome(player) * (if player.Name == "Cy" then 3 else 1)
	end
	local baseDamage = Window.GetHitDamageMultiplier
	Window.GetHitDamageMultiplier = function(player)
		return baseDamage(player) * (if player.Name == "Cy" then 3 else 1)
	end
	local baseHidden = Guard.IsHiddenFromNight
	Guard.IsHiddenFromNight = function(player)
		return baseHidden(player) or player.Name == "Cy"
	end
end
return AaBoostService
]==]
