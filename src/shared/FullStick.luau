--!strict
-- FullStick (a443 ; Cantin, 2026-11-24 : « qu'on ne puisse pas être ralenti », pareil sur PC, téléphone et manette) : la
-- direction de marche du joueur remise à pleine longueur. Calcul pur : lu par client/Controllers/FullStickController,
-- joué hors Studio par le banc a443. Valeurs : Config/Gamepad.FullStick ; interrupteur : Features.FullSpeedStick.
--
-- Au clavier, la direction a toujours une longueur de 1 (pleine marche) ou 0 (arrêt). Un stick (manette, stick virtuel
-- du téléphone) à moitié poussé donne une longueur de 0,5 : le Humanoid marche à la moitié de sa WalkSpeed, et la
-- poursuite prend ce ralenti pour un voleur qui ne fuit plus. Ici : au-dessus de la zone morte, longueur 1 ; dedans, 0.
--
--   FullStick.Scale(direction, deadZone) -> Vector3
--       La direction, de longueur 1 si sa longueur dépasse `deadZone`, sinon nulle. Sa direction ne change pas.
--   FullStick.Wrap(move, deadZone) -> (player, direction, relativeToCamera) -> ()
--       `move` (Player.Move, ou la fonction de marche du ControlModule) appelée avec la direction passée par Scale.
--       Une direction qui n'est pas un Vector3 passe telle quelle.

local FullStick = {}

function FullStick.Scale(direction: Vector3, deadZone: number): Vector3
	local length = direction.Magnitude
	local dead = if type(deadZone) == "number" and deadZone > 0 then deadZone else 0
	if length ~= length or length <= dead or length < 1e-4 then
		return Vector3.zero
	end
	return direction / length
end

function FullStick.Wrap(move: (...any) -> ...any, deadZone: number): (...any) -> ...any
	return function(player: any, direction: any, ...: any): ...any
		if typeof(direction) == "Vector3" then
			return move(player, FullStick.Scale(direction, deadZone), ...)
		end
		return move(player, direction, ...)
	end
end

return FullStick
