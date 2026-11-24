---------------------------------------------------------------- a36 : compléments du faux Roblox
-- Ajouts à la copie du faux d'a30 (stubs.luau) et aux compléments d'a29 (ext29.luau), pour
-- AntiCheatService et TrainingService (vague 12, DEV-060) :
--   - Player:GetNetworkPing() : PING[player] (s), 0 par défaut ;
--   - Humanoid.StateChanged (TrainingService) : un signal comme les autres, jamais déclenché ici.
PING = {}
function Methods.GetNetworkPing(self)
	return PING[self] or 0
end
CLASS_EVENTS.StateChanged = true
