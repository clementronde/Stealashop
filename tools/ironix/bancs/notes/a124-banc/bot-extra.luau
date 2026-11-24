---------------------------------------------------------------- a124 : compléments du faux BotService d'a121
-- Inséré juste après bot.luau, avant le démarrage de TutorialService : la poursuite en cours
-- (BotService.IsChasing, BOT_CHASING[joueur] = true) ; IsGentle est posé par TutorialService.Init.
BOT_CHASING = {}
FakeBot.IsChasing = function(player)
	return BOT_CHASING[player] == true
end
