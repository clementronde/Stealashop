--!strict
-- BenchBarController (client, vague 24, L-091 point 2) : la barre du banc suit les deux mains.
--
-- Retour de Cantin du 2026-11-11 : soudée à RightHand par le serveur (vague 21), la barre « ne suit
-- pas trop les mains » (une seule main, position relative prise au moment de la soudure, pose vue
-- par le serveur). Désormais, quand TrainingService pose l'attribut BenchUserId sur un modèle taggé
-- Bench (le joueur est installé, la barre est ancrée et sans collision côté serveur), ce contrôleur
-- place sa pièce ou son modèle Bar, chez ce client, à chaque image (Heartbeat, après l'animation et
-- la physique de l'image) :
--   - au milieu de LeftHand et RightHand du joueur (R6 : Left Arm et Right Arm) ;
--   - orientée selon l'axe qui va d'une main à l'autre : le grand axe de la barre (le plus long de
--     sa boîte) est tourné, par la plus petite rotation, de sa direction d'origine vers cet axe.
-- Vague 25 : si Bar est rangée dans un modèle Barbell (Bar, Plate_L1…, Collar_L…), toutes les
-- pièces de Barbell suivent avec la même position relative à Bar (un seul BulkMoveTo par image)
-- et reprennent leur place exacte à la fin. Sans Barbell : Bar seule, comme avant.
-- Chaque client le fait pour tous les joueurs visibles : l'animation BenchLift est calculée chez
-- chaque client, les mains y sont exactes, et rien ne passe par le réseau à chaque image. La barre
-- est du décor, sans effet de jeu : le serveur n'a rien à décider sur sa position.
-- Quand l'attribut disparaît (fin de séance) ou que le banc est retiré, la barre reprend chez ce
-- client sa place exacte et ses collisions d'avant (le serveur ne l'a pas déplacée, il ne renverrait
-- pas sa position). Sans mains (perso pas encore là, hors streaming) : la barre attend sur le banc.
--
-- API (client) :
--   BenchBarController.Step()                 place les barres tout de suite (tests)
--   BenchBarController.IsFollowing(bench) -> boolean

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Contrat (10.4) et attribut posé par TrainingService.
local BENCH_TAG = "Bench"
local BAR = "Bar"
local BARBELL = "Barbell" -- vague 25 : modèle de l'haltère entière (Bar, disques, colliers)
local USER_ATTRIBUTE = "BenchUserId"
local LEFT_HANDS = { "LeftHand", "Left Arm" }
local RIGHT_HANDS = { "RightHand", "Right Arm" }

type Saved = { part: BasePart, cframe: CFrame, offset: CFrame, canCollide: boolean }
type Follow = {
	userId: number,
	parts: { Saved },
	rotation: CFrame, -- rotation d'origine de la barre
	axis: Vector3, -- grand axe d'origine (monde), tourné vers la main droite
}

local BenchBarController = {}

local benches: { [Instance]: boolean } = {}
local follows: { [Instance]: Follow } = {}

local function findPart(character: Model, names: { string }): BasePart?
	for _, name in names do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

-- Positions des deux mains du joueur `userId`, nil s'il n'est pas visible.
local function handsOf(userId: number): (Vector3?, Vector3?)
	local player = Players:GetPlayerByUserId(userId)
	local character = if player then player.Character else nil
	if character == nil then
		return nil, nil
	end
	local left = findPart(character, LEFT_HANDS)
	local right = findPart(character, RIGHT_HANDS)
	if left == nil or right == nil then
		return nil, nil
	end
	return left.Position, right.Position
end

-- Plus petite rotation qui amène la direction unitaire `from` sur `to`.
local function rotationBetween(from: Vector3, to: Vector3): CFrame
	local dot = math.clamp(from:Dot(to), -1, 1)
	local cross = from:Cross(to)
	if cross.Magnitude < 1e-6 then
		if dot > 0 then
			return CFrame.identity
		end
		local perpendicular = from:Cross(Vector3.yAxis)
		if perpendicular.Magnitude < 1e-6 then
			perpendicular = from:Cross(Vector3.xAxis)
		end
		return CFrame.fromAxisAngle(perpendicular.Unit, math.pi)
	end
	return CFrame.fromAxisAngle(cross.Unit, math.acos(dot))
end

-- Commence à suivre les mains : mémorise la place exacte de chaque pièce. nil si rien à suivre.
local function begin(bench: Instance, userId: number): Follow?
	local bar = bench:FindFirstChild(BAR, true)
	if bar == nil or not (bar:IsA("BasePart") or bar:IsA("Model")) then
		return nil
	end
	local left, right = handsOf(userId)
	if left == nil or right == nil then
		return nil
	end
	-- Vague 25 : si Bar est dans un modèle Barbell, toute l'haltère suit (disques, colliers) en
	-- gardant sa place relative à Bar ; sinon Bar seule, comme avant.
	local holder: Instance = bar
	local parent = bar.Parent
	if parent and parent.Name == BARBELL and parent:IsA("Model") then
		holder = parent
	end
	local list: { BasePart } = {}
	if holder:IsA("BasePart") then
		table.insert(list, holder)
	end
	for _, descendant in holder:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(list, descendant)
		end
	end
	if #list == 0 then
		return nil
	end
	local center: CFrame, size: Vector3
	if bar:IsA("Model") then
		center, size = bar:GetBoundingBox()
	else
		local part = bar :: BasePart
		center, size = part.CFrame, part.Size
	end
	local localAxis = if size.X >= size.Y and size.X >= size.Z
		then Vector3.xAxis
		elseif size.Y >= size.Z then Vector3.yAxis
		else Vector3.zAxis
	local axis = center:VectorToWorldSpace(localAxis)
	if axis:Dot(right - left) < 0 then
		axis = -axis
	end
	local follow: Follow = { userId = userId, parts = {}, rotation = center.Rotation, axis = axis }
	for _, part in list do
		table.insert(follow.parts, {
			part = part,
			cframe = part.CFrame,
			offset = center:ToObjectSpace(part.CFrame),
			canCollide = part.CanCollide,
		})
		part.CanCollide = false
	end
	return follow
end

-- Déplace d'un seul coup toutes les pièces encore là (vague 25 : l'haltère reste d'un bloc).
local function moveAll(follow: Follow, cframeOf: (Saved) -> CFrame)
	local parts: { BasePart } = {}
	local targets: { CFrame } = {}
	for _, saved in follow.parts do
		if saved.part.Parent ~= nil then
			table.insert(parts, saved.part)
			table.insert(targets, cframeOf(saved))
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, targets, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

-- Remet la barre (ou l'haltère entière) à sa place exacte, chez ce client.
local function release(follow: Follow)
	moveAll(follow, function(saved: Saved): CFrame
		return saved.cframe
	end)
	for _, saved in follow.parts do
		if saved.part.Parent ~= nil then
			saved.part.CanCollide = saved.canCollide
		end
	end
end

local function place(follow: Follow)
	local left, right = handsOf(follow.userId)
	if left == nil or right == nil then
		return -- mains absentes un instant : la barre garde sa dernière place
	end
	local span = right - left
	if span.Magnitude < 1e-3 then
		return
	end
	local center = CFrame.new((left + right) / 2) * rotationBetween(follow.axis, span.Unit) * follow.rotation
	moveAll(follow, function(saved: Saved): CFrame
		return center * saved.offset
	end)
end

local function step()
	for bench, follow in follows do
		local value = bench:GetAttribute(USER_ATTRIBUTE)
		if bench.Parent == nil or value ~= follow.userId then
			follows[bench] = nil
			release(follow)
		end
	end
	for bench in benches do
		local value = bench:GetAttribute(USER_ATTRIBUTE)
		if follows[bench] == nil and type(value) == "number" then
			local follow: Follow? = begin(bench, value)
			if follow then
				follows[bench] = follow
			end
		end
	end
	for _, follow in follows do
		place(follow)
	end
end

function BenchBarController.Step()
	step()
end

function BenchBarController.IsFollowing(bench: Instance): boolean
	return follows[bench] ~= nil
end

function BenchBarController.Start()
	for _, bench in CollectionService:GetTagged(BENCH_TAG) do
		benches[bench] = true
	end
	CollectionService:GetInstanceAddedSignal(BENCH_TAG):Connect(function(bench: Instance)
		benches[bench] = true
	end)
	CollectionService:GetInstanceRemovedSignal(BENCH_TAG):Connect(function(bench: Instance)
		benches[bench] = nil
		local follow = follows[bench]
		if follow then
			follows[bench] = nil
			release(follow)
		end
	end)
	RunService.Heartbeat:Connect(step)
end

return BenchBarController
