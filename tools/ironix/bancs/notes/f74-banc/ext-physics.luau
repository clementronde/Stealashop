-- f74 (fusion74, a261, T-084) : ajout pur au faux Roblox d'a29 (copie a36), inséré juste après `local games = …`
-- (f74-banc/autres-bancs/a96/run.sh). BotService enregistre les groupes de collision BotDefender et BotDoor
-- (PhysicsService) ; ce faux n'avait pas PhysicsService (« service absent du faux Roblox »), d'où l'avertissement
-- « [BotService] groupes de collision … indisponibles ». Même faux que celui du banc a32 (copie a37).
do
	F74_COLLISION_GROUPS = { Default = true }
	F74_COLLIDABLE = {}
	local physics = {
		IsCollisionGroupRegistered = function(_, name)
			return F74_COLLISION_GROUPS[name] == true
		end,
		RegisterCollisionGroup = function(_, name)
			F74_COLLISION_GROUPS[name] = true
		end,
		CollisionGroupSetCollidable = function(_, a, b, value)
			assert(F74_COLLISION_GROUPS[a] and F74_COLLISION_GROUPS[b], "groupe de collision non enregistré (faux Roblox)")
			F74_COLLIDABLE[a .. "|" .. b] = value
			F74_COLLIDABLE[b .. "|" .. a] = value
		end,
		CollisionGroupsAreCollidable = function(_, a, b)
			return F74_COLLIDABLE[a .. "|" .. b] ~= false
		end,
	}
	for _, g in games do
		local base = g.GetService
		g.GetService = function(self, name)
			if name == "PhysicsService" then
				return physics
			end
			return base(self, name)
		end
	end
end
