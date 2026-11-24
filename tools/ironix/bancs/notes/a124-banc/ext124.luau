--!nocheck
-- a124 (vague 37, le bot défend sa boutique) : compléments du faux Roblox et de la mise en place du banc a32
-- (copie a37), lus après setup.luau :
--   - RIG_FACTORY : rig R15 simplifié (HumanoidRootPart, Head, Humanoid, Animator) avec le script Animate de
--     Roblox (idle, walk, run) pour Players:CreateHumanoidModelFromDescriptionAsync ;
--   - BotService (vrai) dans Server/Services ;
--   - ReplicatedStorage/Assets/Animations/Player/SwingBat, Assets/Sounds/SwingBat_Impact, Assets/TOOL_Batte (Tool) ;
--   - déplacement simulé du bot : à chaque image, son HumanoidRootPart non ancré avance vers la cible de
--     Humanoid:MoveTo (gardée par le faux) à Humanoid.WalkSpeed, à l'horizontale.

RIG_FACTORY = function(_description, _rigType)
	local model = make("Model", { Name = "Player" })
	local root = make("Part", { Name = "HumanoidRootPart", Size = Vector3.new(2, 2, 1), CFrame = CFrame.new(0, 3, 0) }, model)
	make("Part", { Name = "Head", Size = Vector3.new(1.2, 1.2, 1.2), CFrame = CFrame.new(0, 4.6, 0) }, model)
	local humanoid = make("Humanoid", { Name = "Humanoid", HipHeight = 2 }, model)
	make("Animator", { Name = "Animator" }, humanoid)
	local animate = make("LocalScript", { Name = "Animate" }, model)
	for _, pair in { { "idle", "Animation1" }, { "walk", "WalkAnim" }, { "run", "RunAnim" } } do
		local holder = make("StringValue", { Name = pair[1] }, animate)
		make("Animation", { Name = pair[2], AnimationId = "rbxassetid://50777" }, holder)
	end
	model.PrimaryPart = root
	return model
end

moduleScript(SERVICES, "BotService", "server/Services/BotService.luau")

local function child(parent, name)
	return parent:FindFirstChild(name) or folder(parent, name)
end
local playerAnims = child(child(ASSETS, "Animations"), "Player")
make("Animation", { Name = "SwingBat", AnimationId = "rbxassetid://9001" }, playerAnims)
make("Sound", { Name = "SwingBat_Impact" }, child(ASSETS, "Sounds"))
local batAsset = make("Tool", { Name = "TOOL_Batte" }, ASSETS)
make("Part", { Name = "Handle", Size = Vector3.new(0.4, 3, 0.4), CanCollide = true }, batAsset)

function botAvatar()
	for _, entry in SHOPS do
		local avatar = entry.model:FindFirstChild("BotAvatar")
		if avatar then
			return avatar
		end
	end
	return nil
end
function botRoot()
	local avatar = botAvatar()
	return if avatar then avatar:FindFirstChild("HumanoidRootPart") else nil
end
function botHumanoid()
	local avatar = botAvatar()
	return if avatar then avatar:FindFirstChildOfClass("Humanoid") else nil
end

local previousBefore = BEFORE_FRAME
BEFORE_FRAME = function(dt)
	if previousBefore then
		previousBefore(dt)
	end
	local avatar = botAvatar()
	local humanoid = botHumanoid()
	local root = botRoot()
	local goal = if humanoid then rawget(humanoid, "_moveTarget") else nil
	if avatar == nil or root == nil or goal == nil or root.Anchored then
		return
	end
	local from = root.Position
	local delta = Vector3.new(goal.X - from.X, 0, goal.Z - from.Z)
	local distance = delta.Magnitude
	if distance < 1e-3 then
		return
	end
	local to = from + delta.Unit * math.min(distance, humanoid.WalkSpeed * dt)
	avatar:PivotTo(CFrame.lookAt(to, to + delta.Unit))
end

-- Démarre le serveur (setup) et garde BotService.
function startBotServer()
	startServer()
	BotService = serverModule("BotService")
	BotConfig = sharedModule("Config/Bot")
	BatConfig = sharedModule("Config/Bat")
end
-- Avance jusqu'à `cond()` (pas de 0,1 s), `max` s au plus ; renvoie true si la condition est vraie.
function waitFor(cond, max)
	local waited = 0
	while not cond() and waited < (max or 10) do
		advance(0.1)
		waited += 0.1
	end
	return cond() == true
end
function animPlays(name)
	local n = 0
	for _, e in ANIM_LOG do
		if e.name == name and e.action == "Play" then
			n += 1
		end
	end
	return n
end
function inBox(part, position)
	local p = part.CFrame:PointToObjectSpace(position)
	local h = part.Size / 2
	return math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z
end
function botHits()
	return BOT_HITS
end
BOT_HITS = {}
PLAYER_HITS = {}
-- Arrivée du bot (≤ 4 vrais joueurs depuis 5 s) et de son avatar ; renvoie sa boutique et ses repères.
function botArrives()
	advance(6.5)
	local plot = BotService.GetBotPlot()
	BatService.OnBotHit(function(p, target, usage, payload)
		table.insert(BOT_HITS, { plot = p, target = target, usage = usage, payload = payload, t = now() })
	end)
	BatService.OnHit(function(hitter, target, usage)
		table.insert(PLAYER_HITS, { hitter = hitter, target = target, usage = usage })
	end)
	return plot, plot and refsOfShop(plot)
end
