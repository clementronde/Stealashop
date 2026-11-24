---------------------------------------------------------------- a121 : faux BotService
-- Inséré dans la mise en place du banc a28 (copie a121) juste avant le démarrage de TutorialService, pour que
-- son require protégé de BotService le trouve. Joue ce que BotService et PvPService font pour un vol au bot :
-- arrivée et départ (OnChanged), objets exposés (GetExposed), Hold (« Grabbed ») puis portage PlayerItem de
-- VictimUserId 0, échec (portage raté puis « Returned »), dépôt (portage « Consumed » puis « Stolen »).
BOT_PLOT = nil
BOT_EXPOSED = {}
BOT_THEFT, BOT_CHANGED = {}, {}
FakeBot = {
	GetBotPlot = function()
		return BOT_PLOT
	end,
	GetExposed = function(plot)
		local out = {}
		if plot == BOT_PLOT then
			for slot, item in BOT_EXPOSED do
				out[slot] = item
			end
		end
		return out
	end,
	OnTheft = function(listener)
		table.insert(BOT_THEFT, listener)
		return function() end
	end,
	OnChanged = function(listener)
		table.insert(BOT_CHANGED, listener)
		return function() end
	end,
}
CACHES.server[moduleScript(ServicesFolder, "BotService", "fake/BotService")] = FakeBot

function botTheft(thief, stage)
	for _, listener in table.clone(BOT_THEFT) do
		taskLib.spawn(listener, thief, "Z1_Donut", stage)
	end
end
function botArrive(plot)
	BOT_PLOT = plot
	for _, listener in table.clone(BOT_CHANGED) do
		taskLib.spawn(listener, plot)
	end
end
function botLeave()
	BOT_PLOT = nil
	for _, listener in table.clone(BOT_CHANGED) do
		taskLib.spawn(listener, nil)
	end
end
-- Comme PvPService : Hold (« Grabbed », émis avant le portage), puis StartCarry.
function botGrab(thief, slot)
	botTheft(thief, "Grabbed")
	carryStart(thief, { Kind = "PlayerItem", ItemUid = "bot-" .. tostring(slot), ItemId = "Z1_Donut", Rarity = "Common", Income = 1, VictimUserId = 0, SlotIndex = slot })
end
function botFail(thief, reason)
	carryEnd(thief, "Failed", reason or "Bat")
	botTheft(thief, "Returned")
end
function botDeposit(thief)
	carryEnd(thief, "Consumed", "Deposited")
	botTheft(thief, "Stolen")
end

