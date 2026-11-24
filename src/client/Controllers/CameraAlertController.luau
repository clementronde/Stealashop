--!strict
-- CameraAlertController (vague 27, client) : compétence Cameras niveau 2 de l'arbre (Config/SkillTree ;
-- Partie 2, section 2 : « voleur surligné à travers les murs 30 s »). Le serveur décide tout :
-- SkillTreeService envoie CameraSpotted(attaquant, fin) au seul propriétaire d'une boutique dont la vitrine
-- est frappée (une fois par attaque). Ce contrôleur n'envoie rien.
--
-- Surlignage : un Highlight AlwaysOnTop, créé par ce client (vu de lui seul), dans le personnage de
-- l'attaquant, jusqu'à `fin` (heure serveur, Workspace:GetServerTimeNow), puis retiré ; repris sur son
-- nouveau personnage s'il réapparaît avant la fin ; retiré à son départ. Au plus MAX_HIGHLIGHTS
-- attaquants à la fois (les plus récents). Tant qu'il y en a, ShelfBoxController.Reserve(RESERVE_KEY,
-- nombre) rend autant de places de contours de colis (fait du temps où l'on croyait Roblox limité à 31 Highlight ; la
-- limite est de 255 par client, L-305 : ce n'est plus nécessaire, mais sans danger). Un attaquant
-- déjà surligné par l'alerte de vol (TheftAlertHighlight de TheftAlertController) ne l'est pas deux fois.
--
-- a408 (vague GC6, Cameras niveau 3, L-163 ; V0 de L-175 : sans flèche ; Config/ShopDefense.CameraRadar,
-- Features.CameraRadar) : quand le joueur a Cameras 3 (attribut Skill_Cameras posé par le serveur), le surlignage
-- passe en rouge vif et un bip de radar sonne (son CameraRadar_Beep, en 2D ; absent : muet) tant qu'un attaquant
-- surligné est en vie, de plus en plus vite quand il est proche du joueur (de MaxInterval s à FarDistance studs ou
-- plus jusqu'à MinInterval s à NearDistance studs ou moins). Le serveur relance CameraSpotted quand le voleur prend
-- un objet (ShopDefenseService) : le radar suit toute la fuite.
--
-- API (client) :
--   CameraAlertController.GetState() -> { Spotted = nombre d'attaquants suivis, Highlights = nombre posés }
--       Pour un test dans Studio (barre de commande côté client).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

type Spot = {
	EndsAt: number, -- heure serveur de la fin
	Order: number, -- ordre d'arrivée
	Highlight: Highlight?,
}

-- V0 proposés, absents du doc :
local HIGHLIGHT_NAME = "CameraHighlight"
local THEFT_HIGHLIGHT = "TheftAlertHighlight" -- même nom dans TheftAlertController
local RESERVE_KEY = "CameraHighlight"
local MAX_HIGHLIGHTS = 2
local CAMERA_BLUE = Color3.fromHex("#3BA7F5") -- bleu « caméra », distinct du rouge de l'alerte de vol
local FILL_TRANSPARENCY = 0.6
local REFRESH_INTERVAL = 0.2 -- s

local CAMERAS_ATTRIBUTE = "Skill_Cameras" -- SkillTree.AttributePrefix .. "Cameras", posé par le serveur

local CameraAlertController = {}

local spotted: { [Player]: Spot } = {}
-- a408 : Config/ShopDefense.CameraRadar, Features et MarkerSounds, chargés au Start (require protégé : bancs sans eux).
local radarConfig: any = nil
local radarFeature = false
local markerSounds: any = nil
local sinceBeep = 0
local counter = 0
local shelf: any = nil
local reservedCount = 0
local sinceRefresh = 0

local function sibling(name: string): any
	local module = script.Parent:FindFirstChild(name)
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, module)
	local value: any = result
	return if ok and type(value) == "table" then value else nil
end

local function reserve(count: number)
	if count == reservedCount then
		return
	end
	reservedCount = count
	if shelf and type(shelf.Reserve) == "function" then
		pcall(shelf.Reserve, RESERVE_KEY, count)
	end
end

local function removeHighlight(spot: Spot)
	local highlight = spot.Highlight
	spot.Highlight = nil
	if highlight then
		highlight:Destroy()
	end
end

-- a408 : le joueur a-t-il le radar (Cameras 3) ?
local function radarOn(): boolean
	local config = radarConfig
	if not radarFeature or config == nil then
		return false
	end
	local me = Players.LocalPlayer
	local levelValue = if me then me:GetAttribute(CAMERAS_ATTRIBUTE) else nil
	return type(levelValue) == "number" and levelValue >= config.Level
end

-- a408 : distance (studs) du joueur à l'attaquant surligné le plus proche encore en vie, ou nil.
local function nearestSpotted(): number?
	local player = Players.LocalPlayer
	local character = if player then player.Character else nil
	local me = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if me == nil or not me:IsA("BasePart") then
		return nil
	end
	local now = Workspace:GetServerTimeNow()
	local best: number? = nil
	for attacker, spot in spotted do
		local other = attacker.Character
		local root = if other then other:FindFirstChild("HumanoidRootPart") else nil
		local humanoid = if other then other:FindFirstChildOfClass("Humanoid") else nil
		if now < spot.EndsAt and root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
			local distance = ((root :: BasePart).Position - (me :: BasePart).Position).Magnitude
			if best == nil or distance < best then
				best = distance
			end
		end
	end
	return best
end

-- a408 : un bip quand l'intervalle de la distance actuelle est écoulé.
local function radarStep(dt: number)
	local config = radarConfig
	local distance = if radarOn() then nearestSpotted() else nil
	if config == nil or distance == nil then
		sinceBeep = math.huge -- le premier bip part tout de suite au prochain repérage
		return
	end
	local span = math.max(config.FarDistance - config.NearDistance, 1)
	local alpha = math.clamp((distance - config.NearDistance) / span, 0, 1)
	local interval = config.MinInterval + (config.MaxInterval - config.MinInterval) * alpha
	sinceBeep += dt
	if sinceBeep < interval then
		return
	end
	sinceBeep = 0
	local sounds = markerSounds
	if sounds and type(sounds.play) == "function" then
		pcall(sounds.play, config.Sound, nil)
	end
end

local function refresh()
	local now = Workspace:GetServerTimeNow()
	-- a408 : Cameras 3, rouge vif (sinon le bleu caméra du niveau 2).
	local red = radarOn()
	local color: Color3 = if red then radarConfig.Color else CAMERA_BLUE
	local fill: number = if red then radarConfig.FillTransparency else FILL_TRANSPARENCY
	local list: { Player } = {}
	for attacker, spot in spotted do
		if now >= spot.EndsAt or attacker.Parent ~= Players then
			removeHighlight(spot)
			spotted[attacker] = nil
		else
			table.insert(list, attacker)
		end
	end
	table.sort(list, function(a: Player, b: Player): boolean
		return spotted[a].Order > spotted[b].Order
	end)
	local count = 0
	for index, attacker in list do
		local spot = spotted[attacker]
		local character = attacker.Character
		local wanted = index <= MAX_HIGHLIGHTS
			and character ~= nil
			and character:IsDescendantOf(Workspace)
			and character:FindFirstChild(THEFT_HIGHLIGHT) == nil
		local highlight = spot.Highlight
		if not wanted or (highlight and (highlight.Parent ~= character)) then
			removeHighlight(spot)
			highlight = nil
		end
		if wanted and character then
			if highlight == nil then
				local created = Instance.new("Highlight")
				created.Name = HIGHLIGHT_NAME
				created.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				created.FillColor = color
				created.FillTransparency = fill
				created.OutlineColor = color
				created.OutlineTransparency = 0
				created.Adornee = character
				created.Parent = character
				spot.Highlight = created
			elseif highlight and highlight.FillColor ~= color then
				-- a408 : Cameras 3 acheté pendant le surlignage
				highlight.FillColor = color
				highlight.FillTransparency = fill
				highlight.OutlineColor = color
			end
			count += 1
		end
	end
	reserve(count)
end

local function onCameraSpotted(attacker: Player, endsAt: number)
	if typeof(attacker) ~= "Instance" or not attacker:IsA("Player") or attacker == Players.LocalPlayer then
		return
	end
	counter += 1
	local spot = spotted[attacker]
	if spot then
		spot.EndsAt = math.max(spot.EndsAt, endsAt)
		spot.Order = counter
	else
		spotted[attacker] = { EndsAt = endsAt, Order = counter, Highlight = nil }
	end
	refresh()
end

function CameraAlertController.GetState(): { Spotted: number, Highlights: number }
	local total, shown = 0, 0
	for _, spot in spotted do
		total += 1
		if spot.Highlight then
			shown += 1
		end
	end
	return { Spotted = total, Highlights = shown }
end

function CameraAlertController.Start()
	shelf = sibling("ShelfBoxController")
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Net = require(Shared:WaitForChild("Net"):WaitForChild("Net")) :: any
	Net.Client.CameraSpotted:Connect(onCameraSpotted)
	-- a408 : radar des caméras (Cameras 3), require protégés.
	local config = Shared:FindFirstChild("Config")
	local function load(parent: Instance?, name: string): any
		local module = if parent then parent:FindFirstChild(name) else nil
		if module == nil or not module:IsA("ModuleScript") then
			return nil
		end
		local ok, result = pcall(require, module)
		return if ok and type(result) == "table" then result else nil
	end
	local defense = load(config, "ShopDefense")
	local features = load(config, "Features")
	radarConfig = if defense then defense.CameraRadar else nil
	radarFeature = features ~= nil and features.CameraRadar == true
	markerSounds = load(Shared:FindFirstChild("Anim"), "MarkerSounds")
	RunService.Heartbeat:Connect(function(dt: number)
		xpcall(radarStep, function(err: any)
			warn(`[CameraAlertController] radar : {err}`)
		end, dt)
		sinceRefresh += dt
		if sinceRefresh < REFRESH_INTERVAL then
			return
		end
		sinceRefresh = 0
		xpcall(refresh, function(err: any)
			warn(`[CameraAlertController] {err}`)
		end)
	end)
end

return CameraAlertController
