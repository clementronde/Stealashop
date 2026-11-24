---------------------------------------------------------------- a29 : compléments du faux Roblox d'a27
-- Ajouts à la copie des bouchons d'a27 (stubs.luau), pour DisplayService, PlotService, PvPService et
-- PvPController (vague 10, DEV-041, DEV-044) :
--   - NumberSequenceKeypoint (halos de DisplayService) ;
--   - Attachment.WorldPosition et WorldCFrame en écriture (point du billboard de DisplayService,
--     points d'accroche de PvPController), comme Roblox : la position locale suit ;
--   - BasePart.Position en lecture déjà là ; Model.PrimaryPart permissif.

NumberSequenceKeypoint = {
	new = function(t, value)
		return setmetatable({ Time = t, Value = value }, { __type = "NumberSequenceKeypoint" })
	end,
}

do
	local baseNewIndex = InstanceMT.__newindex
	InstanceMT.__newindex = function(self, key, value)
		if (key == "WorldPosition" or key == "WorldCFrame") and isA(self, "Attachment") then
			local parent = rawget(self, "_parent")
			local base = if parent and isA(parent, "BasePart") then parent.CFrame else CFrame.identity
			local world = if key == "WorldPosition" then CFrame.new(value) else value
			rawget(self, "_props").CFrame = base:Inverse() * world
			return
		end
		return baseNewIndex(self, key, value)
	end
end

-- Touched (CashPad de DisplayService) : un signal comme les autres, jamais déclenché par le banc.
CLASS_EVENTS.Touched = true

-- Heure simulée de la première ligne de journal qui contient `pattern` (nil sinon).
function logTime(pattern)
	for _, line in LOG do
		if string.find(line.text, pattern, 1, true) then
			return line.t
		end
	end
	return nil
end
