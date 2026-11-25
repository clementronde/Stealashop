--!strict
-- DisplayOrder (a484, décision de Cantin du 25/11) : ordre de présentation des présentoirs d'une boutique, pour Equip
-- Best (DisplayService.EquipBest) : le meilleur objet va sur le premier présentoir de cet ordre, le suivant sur le
-- deuxième, etc. Module pur (aucune instance lue), commun au serveur et aux bancs.
--
-- Ordre, vu depuis l'entrée de la boutique en regardant vers le fond :
--   1. étage : rez-de-chaussée d'abord, puis l'étage (Floor_2) ;
--   2. côté : tout le mur GAUCHE, puis le milieu (présentoir à moins de SIDE_TOLERANCE de l'axe porte → fond), puis
--      tout le mur DROIT ;
--   3. distance à l'entrée, mesurée le long de l'axe porte → fond : le plus près d'abord ;
--   4. à égalité : le plus petit numéro de présentoir.
-- Aucun numéro de présentoir en dur : seule la position compte, dans le repère de la boutique (son pivot), jamais en
-- coordonnées monde ; une boutique tournée garde le même ordre.
--
-- Repère : l'axe « porte → fond » va de la porte (PlotDoor, position monde donnée par l'appelant) vers le pivot de la
-- boutique, à plat (Y ignoré). Sans porte (ou porte sur le pivot) : la face avant de la boutique est vers la rue, côté
-- −Z local (CLAUDE.md, « face avant vers la rue » ; le pivot d'un PLOT_Shop regarde vers sa porte), donc l'axe vaut +Z
-- local et l'entrée est le pivot.
-- Gauche et droite : un personnage qui regarde dans la direction `forward` a sa droite en forward × Y (c'est la règle
-- de Roblox : CFrame.RightVector = LookVector:Cross(UpVector)). Un présentoir est à gauche quand sa position, prise
-- depuis l'entrée, a une composante négative sur cette droite. Exemple de PLOT_Shop (porte à z = −39,5 dans le repère
-- du pivot) : forward = (0, 0, 1), droite = (0, 0, 1) × (0, 1, 0) = (−1, 0, 0), donc le mur gauche est x = +24
-- (présentoirs 02, 04, 06, 08) et le mur droit x = −24 (01, 03, 05, 07).
--
-- API (sans yield) :
--   DisplayOrder.Enabled() -> boolean
--       Features.EquipBestOrder (partout) ou Features.EquipBestOrderDev dans le jeu DEV (Config/ProductIds.IsDev) ; en
--       Studio, workspace:SetAttribute("EquipBestOrderTest", true ou false) force la réponse (lu à chaque appel).
--       Éteint : Equip Best garde sa règle d'avant (DisplayService).
--   DisplayOrder.Sort(pivot, door, stands) -> { number }
--       Numéros des présentoirs `stands` ({ index, position (monde), upper (à l'étage) }) dans l'ordre ci-dessus.
--   DisplayOrder.Key(pivot, door, position) -> (number, number)
--       Côté (0 gauche, 1 milieu, 2 droite) et distance à l'entrée d'une position monde (pour les bancs).

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Features = require(script.Parent.Config.Features) :: any

local TEST_ATTRIBUTE = "EquipBestOrderTest"
-- Pas une règle de jeu : un présentoir à moins d'un demi-stud de l'axe porte → fond est « au milieu ».
local SIDE_TOLERANCE = 0.5
-- Porte à moins d'un stud du pivot (à plat) : pas d'axe utilisable, repli sur +Z local.
local MIN_DOOR_OFFSET = 1

export type Stand = {
	index: number,
	position: Vector3, -- position monde du présentoir (Attachment.WorldPosition)
	upper: boolean, -- à l'étage (Floor_2)
}

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

local isStudio = (function(): boolean
	local ok, result = pcall(function(): boolean
		return RunService:IsStudio()
	end)
	return ok and result == true
end)()

local base = Features.EquipBestOrder == true or (Features.EquipBestOrderDev == true and isDev)

local DisplayOrder = {}

function DisplayOrder.Enabled(): boolean
	if isStudio then
		local forced = Workspace:GetAttribute(TEST_ATTRIBUTE)
		if type(forced) == "boolean" then
			return forced
		end
	end
	return base
end

-- Entrée (à plat) et axe porte → fond, dans le repère du pivot.
local function frame(pivot: CFrame, door: Vector3?): (Vector3, Vector3)
	if door ~= nil then
		local localDoor = pivot:PointToObjectSpace(door)
		local flat = Vector3.new(localDoor.X, 0, localDoor.Z)
		if flat.Magnitude >= MIN_DOOR_OFFSET then
			return flat, -flat.Unit
		end
	end
	return Vector3.zero, Vector3.zAxis
end

local function keyIn(pivot: CFrame, entry: Vector3, forward: Vector3, position: Vector3): (number, number)
	local p = pivot:PointToObjectSpace(position)
	local rel = Vector3.new(p.X, 0, p.Z) - entry
	local right = forward:Cross(Vector3.yAxis)
	local lateral = rel:Dot(right)
	local side = if lateral < -SIDE_TOLERANCE then 0 elseif lateral > SIDE_TOLERANCE then 2 else 1
	return side, rel:Dot(forward)
end

function DisplayOrder.Key(pivot: CFrame, door: Vector3?, position: Vector3): (number, number)
	local entry, forward = frame(pivot, door)
	return keyIn(pivot, entry, forward, position)
end

function DisplayOrder.Sort(pivot: CFrame, door: Vector3?, stands: { Stand }): { number }
	local entry, forward = frame(pivot, door)
	type Row = { index: number, level: number, side: number, depth: number }
	local rows: { Row } = {}
	for _, stand in stands do
		local side, depth = keyIn(pivot, entry, forward, stand.position)
		table.insert(rows, { index = stand.index, level = if stand.upper then 1 else 0, side = side, depth = depth })
	end
	table.sort(rows, function(a: Row, b: Row): boolean
		if a.level ~= b.level then
			return a.level < b.level
		end
		if a.side ~= b.side then
			return a.side < b.side
		end
		if math.abs(a.depth - b.depth) > 1e-3 then
			return a.depth < b.depth
		end
		return a.index < b.index
	end)
	local order: { number } = {}
	for _, row in rows do
		table.insert(order, row.index)
	end
	return order
end

return DisplayOrder
