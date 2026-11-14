--!strict
-- CatchReach (a146, vague 41, audit de sécurité du 2026-11-14) : qui peut être attrapé ou frappé.
-- Commun à la capture (GuardService : vigile de jour, police, vigile de nuit, conducteur du camion) et au
-- coup de batte (BatService : joueurs et bot). Côté serveur seulement (le client n'en a pas besoin).
--
-- Avant : distance 3D et ligne de vue. Un joueur qui vole (au-dessus de la portée) ou qui traverse les
-- murs (le rayon bute sur le mur où il se cache) n'était jamais attrapé. Maintenant :
--   - InRange : distance à l'horizontale ≤ la portée (CatchDistance, Bat.Range), et au plus
--     AntiCheat.CatchVerticalReach (10) studs d'écart en hauteur entre les deux HumanoidRootPart ;
--   - CanTouch, une seule des trois suffit :
--       1. ligne libre entre les deux HumanoidRootPart (comme avant) ;
--       2. ligne libre « en L » : du HumanoidRootPart du chasseur, droit vers le haut (ou le bas)
--          jusqu'à la hauteur de la cible, puis à l'horizontale jusqu'à elle. C'est un joueur perché
--          sur un meuble bas (rayon, comptoir : L-140), que le dessus du meuble cache au rayon direct ;
--          un mur, un plafond ou un plancher entre eux coupe toujours l'un des deux bouts ;
--       3. le centre du HumanoidRootPart de la cible est dans une pièce qui bloque (GetPartsInPart,
--          RespectCanCollide, puis le centre dans la boîte de la pièce) : il traverse un mur.
--   Les rayons et la recherche ignorent ce que `exclude` donne (personnages, vigiles, colis au sol) et
--   tout ce qui ne bloque pas (CanCollide coupé : volumes Bounds, vitre cassée, colis porté).
--
-- API :
--   CatchReach.InRange(from, to, reach) -> boolean
--   CatchReach.CanTouch(from, targetRoot, params) -> (boolean, string)
--       `from` : centre du HumanoidRootPart du chasseur (ou du frappeur) ; `params` : ses RaycastParams
--       (Exclude, RespectCanCollide). Renvoie true et la façon (« vue », « perché », « dans une pièce »),
--       ou false et « un mur entre eux ».

local Workspace = game:GetService("Workspace")

local AntiCheat = require(script.Parent.Config.AntiCheat)

local CatchReach = {}

-- En dessous (studs), un bout de rayon n'a pas de longueur : il est libre.
local TINY = 1e-3

local function clear(from: Vector3, to: Vector3, params: RaycastParams): boolean
	local direction = to - from
	if direction.Magnitude < TINY then
		return true
	end
	return Workspace:Raycast(from, direction, params) == nil
end

function CatchReach.InRange(from: Vector3, to: Vector3, reach: number): boolean
	local offset = to - from
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= reach and math.abs(offset.Y) <= AntiCheat.CatchVerticalReach
end

-- Le centre de `root` est-il dans une pièce qui bloque (hors `params`) ?
local function insidePart(root: BasePart, params: RaycastParams): boolean
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = params.FilterDescendantsInstances
	overlap.RespectCanCollide = true
	local center = root.Position
	for _, part in Workspace:GetPartsInPart(root, overlap) do
		if part ~= root and part.CanCollide then
			local p = part.CFrame:PointToObjectSpace(center)
			local half = part.Size / 2
			if math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z then
				return true
			end
		end
	end
	return false
end

function CatchReach.CanTouch(from: Vector3, targetRoot: BasePart, params: RaycastParams): (boolean, string)
	local to = targetRoot.Position
	if clear(from, to, params) then
		return true, "vue"
	end
	local corner = Vector3.new(from.X, to.Y, from.Z)
	if math.abs(to.Y - from.Y) >= TINY and clear(from, corner, params) and clear(corner, to, params) then
		return true, "perché"
	end
	if insidePart(targetRoot, params) then
		return true, "dans une pièce"
	end
	return false, "un mur entre eux"
end

return CatchReach
