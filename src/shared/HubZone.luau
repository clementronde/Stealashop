--!strict
-- HubZone (L-165, vague 50, a160) : calculs communs au serveur (HubService) et au client (HubController) pour
-- les zones du hub (cadeau, noob « invite un ami »), le bonus d'amis et les étiquettes BB_ZoneLabel. Valeurs :
-- Config/Hub. Sans état et sans service : testé hors Studio.
--
--   HubZone.contains(cframe, size, position, margin) -> boolean
--       position dans la boîte de la pièce Zone (cframe, size), élargie de margin à l'horizontale ; en hauteur,
--       de Hub.ZoneBelow (+ margin) sous son bas à Hub.ZoneAbove (+ margin) au-dessus de son haut.
--   HubZone.step(wasInside, cframe, size, position?) -> (inside, entered)
--       Entrée sans marge, sortie au-delà de Hub.ExitMargin ; position nil (pas de personnage vivant) = dehors.
--       entered = true seulement au passage de dehors à dedans (une fois par entrée).
--   HubZone.friendBonus(count) -> number
--       Bonus de revenus en fraction pour `count` amis présents : min(count, MaxFriends) × PerFriend.
--   HubZone.labelText(key) -> string?
--       Texte anglais de LabelKey (Hub.Labels), nil pour une clé inconnue ou qui n'est pas un texte.

local Hub = require(script.Parent:WaitForChild("Config"):WaitForChild("Hub"))

local HubZone = {}

function HubZone.contains(cframe: CFrame, size: Vector3, position: Vector3, margin: number): boolean
	local p = cframe:PointToObjectSpace(position)
	if math.abs(p.X) > size.X / 2 + margin or math.abs(p.Z) > size.Z / 2 + margin then
		return false
	end
	return p.Y >= -size.Y / 2 - Hub.ZoneBelow - margin and p.Y <= size.Y / 2 + Hub.ZoneAbove + margin
end

function HubZone.step(wasInside: boolean, cframe: CFrame, size: Vector3, position: Vector3?): (boolean, boolean)
	if position == nil then
		return false, false
	end
	if wasInside then
		return HubZone.contains(cframe, size, position, Hub.ExitMargin), false
	end
	local inside = HubZone.contains(cframe, size, position, 0)
	return inside, inside
end

function HubZone.friendBonus(count: number): number
	if type(count) ~= "number" or count ~= count or count <= 0 then
		return 0
	end
	return math.min(math.floor(count), Hub.FriendBonus.MaxFriends) * Hub.FriendBonus.PerFriend
end

function HubZone.labelText(key: any): string?
	if type(key) ~= "string" then
		return nil
	end
	return Hub.Labels[key]
end

return HubZone
