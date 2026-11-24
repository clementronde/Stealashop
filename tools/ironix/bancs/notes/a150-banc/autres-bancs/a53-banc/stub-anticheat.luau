-- a36 (vague 12, DEV-060) : bouchon d'AntiCheatService pour les anciens bancs. Les services qui
-- déplacent un joueur l'appellent maintenant (Allow), PvPService aussi au dépôt (Verify) : ici, Allow
-- est seulement noté et Verify laisse tout passer, pour que ces bancs testent leur service comme avant.
SOURCES["stub/AntiCheatService"] = [==[
local AntiCheatService = { allows = {} }
function AntiCheatService.Allow(player, seconds, reason)
	table.insert(AntiCheatService.allows, { player = player, seconds = seconds, reason = reason })
end
function AntiCheatService.Verify(_player, _from, _since)
	return true
end
function AntiCheatService.GetStrikes(_player)
	return 0
end
function AntiCheatService.GetLog()
	return {}
end
function AntiCheatService.OnDetection(_listener)
	return function() end
end
return AntiCheatService
]==]
