--!nocheck
POTIONS = {}
SOURCES["stub/PotionService"] = [==[
local PotionService = {}
function PotionService.AddStock(player, id, count)
	table.insert(POTIONS, { player = player, id = id, count = count })
	return true
end
return PotionService
]==]
moduleScript(SERVICES, "PotionService", "stub/PotionService")
moduleScript(SERVICES, "CodeService", "server/Services/CodeService.luau")
function redeem(player, text)
	advance(1.05) -- RedeemCode : 1 appel par seconde au plus
	fireAs(player, "RedeemCode", text)
	flush()
end
function lastResult(player)
	local list = remotes("CodeResult", function(e) return e.to == player end)
	local e = list[#list]
	return e and e.args[1], e and e.args[2], #list
end
