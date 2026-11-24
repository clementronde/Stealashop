--!nocheck
-- a175 (vague 54) : aides des scénarios. Le voleur sort de la boutique du bot, à `ahead` studs devant la porte (défaut 5).
function exitShop(player, S, ahead)
	moveTo(player, Vector3.new(S.door.X, 3, S.door.Z) + S.front * (ahead or 5), S.front)
end
function enterShop(player, S)
	moveTo(player, Vector3.new(S.door.X, 3, S.door.Z) - S.front * 6, S.front * -1)
end
