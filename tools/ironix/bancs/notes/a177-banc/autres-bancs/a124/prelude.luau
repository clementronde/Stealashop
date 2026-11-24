--!nocheck
-- a177 (vague 55, Cantin 2026-11-15) : le bot sort maintenant frapper celui qui casse sa porte (BotService, breaking).
-- Les scénarios écrits avant cassent la porte du bot sans le déranger : pendant breakDoor sur SA porte, le frappeur
-- compte comme en tuto (BotService.IsGentle, que le bot laisse casser) ; ensuite, IsGentle redevient celui d'avant.
-- Le reste des scénarios ne change pas. Le casseur frappé par le bot : scénario a177bot du banc a177.
do
	local plainBreakDoor = breakDoor
	breakDoor = function(hitter, plot, ...)
		local api = BotService
		if api == nil or api.GetBotPlot == nil or api.GetBotPlot() ~= plot then
			return plainBreakDoor(hitter, plot, ...)
		end
		local saved = api.IsGentle
		api.IsGentle = function(player)
			return player == hitter or saved(player)
		end
		local results = table.pack(plainBreakDoor(hitter, plot, ...))
		api.IsGentle = saved
		return table.unpack(results, 1, results.n)
	end
end
