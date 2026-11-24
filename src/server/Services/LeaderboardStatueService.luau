--!strict
-- LeaderboardStatueService (a430, L-331 ; serveur) : statues du n° 1 des classements de la semaine, à côté des panneaux
-- du fond du hub. Modèles de Clément ENV_Hub_LeaderboardStatue (tag LeaderboardStatue, attribut Stat = WeeklyIncome ou
-- WeeklySteals), facultatifs ; valeurs : Config/WeeklyLeaderboard.Statue. Aucun remote.
--
--   - WeeklyLeaderboardService appelle Show(stat, userId) à chaque lecture du classement (0 = semaine vide). Rien ne
--     change tant que le n° 1 reste le même.
--   - Nouveau n° 1 : Players:GetHumanoidDescriptionFromUserId, puis Humanoid:ApplyDescription sur une copie du Rig doré
--     de Clément (gardée au premier passage), ramenée à l'échelle 1 et posée BuildDepth studs sous la statue (hors de
--     vue) ; membres recalés sur leurs articulations AnimationConstraint (du HumanoidRootPart vers les extrémités : en
--     Edit ou juste après ApplyDescription ils restent tassés) ; agrandie pour que le corps (sans les accessoires)
--     mesure Height studs, comme tous les autres avatars ; Material = Plastic sur toutes ses pièces (sinon l'avatar
--     brille comme la statue) ; posée à la place du Rig doré (même orientation, même X et Z, dessous des pieds au
--     niveau de ceux du Rig doré, donc sur le socle), puis elle remplace le Rig. PlayerName = nom du joueur.
--   - Semaine vide : une copie du Rig doré revient, PlayerName = EmptyName (« ??? »).
--   - Les changements d'une statue se suivent (ApplyDescription attend) : une tâche par statue, qui va toujours au
--     dernier n° 1 demandé (file comme DisguiseService). Avatar illisible (pcall) : statue dorée avec le nom du n° 1,
--     nouvel essai à la lecture suivante ; un message par cause.
--   - Seules comptent les statues du Workspace (les copies de ServerStorage/MapBackups gardent le tag, L-330).
--
-- Crochet de test, STUDIO SEULEMENT, barre de commande serveur :
--   workspace:SetAttribute("WeeklyStatueTest", 1)  -- UserId montré sur toutes les statues (0 = dorées) ;
--   workspace:SetAttribute("WeeklyStatueTest", nil) -- retour au vrai n° 1
--
-- API (serveur) :
--   LeaderboardStatueService.Show(stat, userId)   n° 1 du classement (0 = personne)
--   LeaderboardStatueService.Shown(stat) -> number   UserId montré par la première statue du classement (0 = dorée)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Weekly = require(ReplicatedStorage.Shared.Config.WeeklyLeaderboard)

local Spec = Weekly.Statue
local IS_STUDIO = RunService:IsStudio()
local BUILDING = "RigBuilding" -- nom du Rig pendant qu'il s'habille (jamais deux « Rig » à la fois)

type Statue = {
	model: Model,
	stat: string,
	pristine: Model, -- copie du Rig doré de Clément, prise au premier passage, jamais modifiée
	root: CFrame, -- HumanoidRootPart du Rig doré
	feetY: number, -- dessous des pieds du Rig doré (dessus du socle)
	shown: number, -- UserId montré (0 = doré)
	busy: boolean,
	again: boolean,
}

local LeaderboardStatueService = {}

local statues: { [Instance]: Statue } = {}
local ignored: { [Instance]: boolean } = {}
local wanted: { [string]: number } = {} -- [stat] = UserId du n° 1 (0 = personne)
local override: number? = nil -- crochet de test (Studio)
local said: { [string]: boolean } = {}

local function sayOnce(key: string, message: string)
	if not said[key] then
		said[key] = true
		if IS_STUDIO then
			print(`[LeaderboardStatueService] {message}`)
		else
			warn(`[LeaderboardStatueService] {message}`)
		end
	end
end

-- Corps du Rig : ses pièces directes, sans le HumanoidRootPart (les accessoires sont dans leurs Accessory).
local function bounds(rig: Model, root: BasePart): (number, number)
	local low, high = math.huge, -math.huge
	for _, child in rig:GetChildren() do
		if child:IsA("BasePart") and child ~= root then
			local cf, half = child.CFrame, child.Size / 2
			local extent = math.abs(cf.RightVector.Y) * half.X + math.abs(cf.UpVector.Y) * half.Y + math.abs(cf.LookVector.Y) * half.Z
			low = math.min(low, cf.Position.Y - extent)
			high = math.max(high, cf.Position.Y + extent)
		end
	end
	return low, high
end

-- L-331 : recale chaque membre sur son articulation AnimationConstraint, du HumanoidRootPart vers les extrémités
-- (Part1.CFrame = Attachment0.WorldCFrame * Attachment1.CFrame:Inverse()). Les Motor6D se posent déjà seuls.
local function repose(rig: Model, root: BasePart)
	local joints: { AnimationConstraint } = {}
	for _, item in rig:GetDescendants() do
		if item:IsA("AnimationConstraint") then
			table.insert(joints, item)
		end
	end
	local placed: { [BasePart]: boolean } = { [root] = true }
	local moved = true
	while moved do
		moved = false
		for _, joint in joints do
			local a0, a1 = joint.Attachment0, joint.Attachment1
			local p0 = if a0 then a0.Parent else nil
			local p1 = if a1 then a1.Parent else nil
			if a0 and a1 and p0 and p1 and p0:IsA("BasePart") and p1:IsA("BasePart") then
				if placed[p0] and not placed[p1] then
					p1.CFrame = a0.WorldCFrame * a1.CFrame:Inverse()
					placed[p1] = true
					moved = true
				elseif placed[p1] and not placed[p0] then
					p0.CFrame = a1.WorldCFrame * a0.CFrame:Inverse()
					placed[p0] = true
					moved = true
				end
			end
		end
	end
end

local function setName(statue: Statue, text: string)
	local label = statue.model:FindFirstChild(Spec.NameLabel, true)
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

local function nameOf(userId: number): string
	local player = Players:GetPlayerByUserId(userId)
	if player then
		return player.Name
	end
	local ok, result = pcall(function(): string
		return Players:GetNameFromUserIdAsync(userId)
	end)
	return if ok and type(result) == "string" then result else "?"
end

-- Le Rig `rig` (déjà dans la statue) remplace le Rig affiché.
local function swap(statue: Statue, rig: Model)
	for _, child in statue.model:GetChildren() do
		if child ~= rig and (child.Name == Spec.Rig or child.Name == BUILDING) then
			child:Destroy()
		end
	end
	rig.Name = Spec.Rig
end

local function golden(statue: Statue)
	local rig = statue.pristine:Clone()
	rig.Name = BUILDING
	rig.Parent = statue.model
	swap(statue, rig)
end

-- Habille une copie du Rig doré avec l'avatar de `userId` et la pose sur le socle. false si l'avatar est illisible.
local function dress(statue: Statue, userId: number): boolean
	local okDesc, desc = pcall(function(): HumanoidDescription
		return Players:GetHumanoidDescriptionFromUserId(userId)
	end)
	if not okDesc or typeof(desc) ~= "Instance" then
		sayOnce(`desc:{userId}`, `avatar de {userId} illisible ({tostring(desc)}) : statue {statue.stat} dorée`)
		return false
	end
	local rig = statue.pristine:Clone()
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	local rootItem = rig:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or rootItem == nil or not rootItem:IsA("BasePart") then
		rig:Destroy()
		return false
	end
	local root = rootItem :: BasePart
	rig.Name = BUILDING
	rig:PivotTo(rig:GetPivot() - Vector3.new(0, Spec.BuildDepth, 0))
	rig.Parent = statue.model
	rig:ScaleTo(1)
	local okApply, problem = pcall(function()
		humanoid:ApplyDescription(desc)
	end)
	if not okApply or rig.Parent ~= statue.model then
		sayOnce(`apply:{userId}`, `ApplyDescription de {userId} raté ({tostring(problem)}) : statue {statue.stat} dorée`)
		rig:Destroy()
		return false
	end
	RunService.Heartbeat:Wait()
	repose(rig, root)
	local low, high = bounds(rig, root)
	if high - low > 0.1 and high - low < math.huge then
		rig:ScaleTo(rig:GetScale() * Spec.Height / (high - low))
		repose(rig, root)
		low, high = bounds(rig, root)
	end
	for _, item in rig:GetDescendants() do
		if item:IsA("BasePart") then
			item.Material = Enum.Material.Plastic
		elseif item:IsA("LuaSourceContainer") then
			item:Destroy() -- aucun script dans un modèle (CLAUDE.md)
		end
	end
	local at = root.Position
	local target = statue.root.Position
	if low < math.huge then
		rig:PivotTo(rig:GetPivot() + Vector3.new(target.X - at.X, statue.feetY - low, target.Z - at.Z))
	else
		rig:PivotTo(rig:GetPivot() + (target - at))
	end
	if rig.Parent ~= statue.model then
		return false
	end
	swap(statue, rig)
	return true
end

local function apply(statue: Statue, userId: number)
	if userId <= 0 then
		golden(statue)
		setName(statue, Spec.EmptyName)
		statue.shown = 0
		return
	end
	setName(statue, nameOf(userId))
	if dress(statue, userId) then
		statue.shown = userId
	else
		if statue.shown ~= 0 then
			golden(statue) -- jamais l'avatar d'un autre sous le nom du n° 1
		end
		statue.shown = 0 -- nouvel essai au prochain Show
	end
end

local function targetOf(statue: Statue): number
	return override or wanted[statue.stat] or 0
end

local function refresh(statue: Statue)
	if statue.busy then
		statue.again = true
		return
	end
	statue.busy = true
	task.spawn(function()
		repeat
			statue.again = false
			local target = targetOf(statue)
			if target ~= statue.shown or target ~= 0 and statue.model:FindFirstChild(Spec.Rig) == nil then
				local ok, problem = pcall(function()
					apply(statue, target)
				end)
				if not ok then
					sayOnce(`apply:{tostring(problem)}`, `statue {statue.stat} : {tostring(problem)}`)
				end
			end
		until not statue.again
		statue.busy = false
	end)
end

local function discover()
	for _, model in CollectionService:GetTagged(Spec.Tag) do
		if statues[model] ~= nil or ignored[model] or not model:IsDescendantOf(Workspace) then
			continue -- copies de ServerStorage/MapBackups : ignorées (L-330)
		end
		local stat = model:GetAttribute(Spec.StatAttribute)
		local rig = model:FindFirstChild(Spec.Rig)
		local root = if rig then rig:FindFirstChild("HumanoidRootPart") else nil
		if not model:IsA("Model") or type(stat) ~= "string" or Weekly.Stats[stat] == nil or rig == nil or not rig:IsA("Model") or root == nil or not root:IsA("BasePart") or rig:FindFirstChildOfClass("Humanoid") == nil then
			ignored[model] = true
			sayOnce(`bad:{model:GetFullName()}`, `{model:GetFullName()} : attribut {Spec.StatAttribute}, {Spec.Rig}, Humanoid ou HumanoidRootPart absent, statue ignorée`)
			continue
		end
		local pristine: Model? = (rig :: Model):Clone() -- nil si Archivable est coupé
		if pristine == nil then
			ignored[model] = true
			sayOnce(`clone:{model:GetFullName()}`, `{model:GetFullName()} : Rig pas copiable (Archivable), statue ignorée`)
			continue
		end
		local low = bounds(rig :: Model, root :: BasePart)
		statues[model] = {
			model = model :: Model,
			stat = stat,
			pristine = pristine,
			root = (root :: BasePart).CFrame,
			feetY = if low < math.huge then low else (root :: BasePart).Position.Y,
			shown = 0,
			busy = false,
			again = false,
		}
	end
end

function LeaderboardStatueService.Show(stat: string, userId: number)
	wanted[stat] = if type(userId) == "number" and userId > 0 then userId else 0
	discover()
	for _, statue in statues do
		if statue.stat == stat then
			refresh(statue)
		end
	end
end

function LeaderboardStatueService.Shown(stat: string): number
	for _, statue in statues do
		if statue.stat == stat then
			return statue.shown
		end
	end
	return 0
end

function LeaderboardStatueService.Start()
	if not IS_STUDIO then
		return
	end
	Workspace:GetAttributeChangedSignal(Spec.TestAttribute):Connect(function()
		local value = Workspace:GetAttribute(Spec.TestAttribute)
		override = if type(value) == "number" then math.max(0, math.floor(value)) else nil
		print(`[LeaderboardStatueService] test : statues sur {if override then tostring(override) else "le vrai n° 1"}`)
		discover()
		for _, statue in statues do
			refresh(statue)
		end
	end)
end

return LeaderboardStatueService
