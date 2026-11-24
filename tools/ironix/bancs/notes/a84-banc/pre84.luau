---------------------------------------------------------------- a84 : bouchon de TelemetryService
-- SkillTreeService appelle TelemetryService.LogEconomy et LogEvent après un achat : appels notés dans TELEMETRY.
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
