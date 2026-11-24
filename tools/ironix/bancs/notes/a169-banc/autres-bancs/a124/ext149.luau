--!nocheck
-- a149 (vague 42) : rien à ajouter au faux Roblox pour l'instant ; aides des scénarios a149.
function botBat()
	local avatar = botAvatar()
	return if avatar then avatar:FindFirstChild("Bat") else nil
end
