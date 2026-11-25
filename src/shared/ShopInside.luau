--!strict
-- ShopInside (a468, 25/11) : un point est-il « dans la boutique » d'un joueur (ou du bot) ? Une seule règle pour
-- tous les lecteurs du volume `Bounds` d'une boutique (contrat 10.4) qui jugent « dedans » : PvPService (sortie,
-- intrus frappé par le propriétaire, alerte d'intrusion, interdiction après une mort, portée du vol, porte gardée
-- cassée tant qu'un intrus est dedans), BatService (intrus du bot) et PvPController (invite du vol).
--
-- Mesure de la place (a468) : `Bounds` fait 64 × 36,3 × 80 studs, de la façade (z −40) au fond du gabarit (z +40),
-- dès le niveau 1, alors que la boutique du niveau 1 s'arrête à son mur du fond en z +8 (`PlotBarrier/Barrier_B1`,
-- carré de 48 × 48, ShopGrowth.MinBack) et grandit ensuite vers l'arrière (ShopStageService). La bande de la place
-- publique derrière le mur du fond comptait comme « dedans » : sortie forcée en passant derrière, passant frappé
-- comme intrus, 60 s d'interdiction en y mourant, vol des présentoirs 11 et 12 à travers le mur, porte gardée cassée.
--
-- Interrupteur allumé (Features.ShopInsideBackWall partout, ShopInsideBackWallDev dans le jeu DEV,
-- Config/ProductIds.IsDev) : dans `Bounds` ET devant le mur du fond posé, lu dans le repère de la boutique (son
-- pivot, avant vers −Z) sur ce que ShopStageService pose sur la boutique :
--   - attribut `StageLevel` absent ou 1 : ShopGrowth.MinBack (8, fond du carré de départ) ; MinBack nil : pas de mur ;
--   - `StageLevel` ≥ 2 : attribut `StageDepth` (fond coupé au dernier présentoir débloqué) ; absent : boutique
--     entière, `Bounds` seul.
-- Interrupteur coupé : `Bounds` seul, la règle d'avant.
--
--   ShopInside.Enabled() -> boolean
--   ShopInside.Back(plot) -> number?        z du mur du fond (repère de la boutique), nil : `Bounds` seul
--   ShopInside.Contains(plot, bounds, point, margin?) -> boolean
--       `point` dans `bounds` (agrandi de `margin` studs de chaque côté, 0 par défaut) et, interrupteur allumé, pas
--       plus de `margin` studs derrière le mur du fond posé.

local Features = require(script.Parent.Config.Features) :: any
local ShopGrowth = require(script.Parent.Config.ShopGrowth)

local LEVEL_ATTRIBUTE = "StageLevel" -- ShopStageService
local DEPTH_ATTRIBUTE = "StageDepth" -- ShopStageService

-- Config/ProductIds chargé s'il est là ; sans lui, IsDev faux (PROD).
local isDev = (function(): boolean
	local module = script.Parent.Config:FindFirstChild("ProductIds")
	if module ~= nil then
		local ok, result = pcall(require, module :: any)
		if ok and type(result) == "table" then
			return (result :: any).IsDev == true
		end
	end
	return false
end)()

local enabled = Features.ShopInsideBackWall == true or (Features.ShopInsideBackWallDev == true and isDev)

local ShopInside = {}

function ShopInside.Enabled(): boolean
	return enabled
end

function ShopInside.Back(plot: Instance): number?
	if not enabled then
		return nil
	end
	local level = plot:GetAttribute(LEVEL_ATTRIBUTE)
	if type(level) == "number" and level >= 2 then
		local depth = plot:GetAttribute(DEPTH_ATTRIBUTE)
		return if type(depth) == "number" then depth else nil
	end
	return ShopGrowth.MinBack
end

function ShopInside.Contains(plot: Instance, bounds: BasePart, point: Vector3, margin: number?): boolean
	local m = margin or 0
	local p = bounds.CFrame:PointToObjectSpace(point)
	local h = bounds.Size / 2
	if math.abs(p.X) > h.X + m or math.abs(p.Y) > h.Y + m or math.abs(p.Z) > h.Z + m then
		return false
	end
	local back = ShopInside.Back(plot)
	if back == nil or not plot:IsA("Model") then
		return true
	end
	return (plot :: Model):GetPivot():PointToObjectSpace(point).Z <= back + m
end

return ShopInside
