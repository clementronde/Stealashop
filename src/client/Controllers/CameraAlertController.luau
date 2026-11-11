--!strict
-- CameraAlertController (vague 27, client) : compétence Cameras niveau 2 de l'arbre (Config/SkillTree ;
-- Partie 2, section 2 : « voleur surligné à travers les murs 30 s »). Le serveur décide tout :
-- SkillTreeService envoie CameraSpotted(attaquant, fin) au seul propriétaire d'une boutique dont la vitrine
-- est frappée (une fois par attaque). Ce contrôleur n'envoie rien.
--
-- Surlignage : un Highlight AlwaysOnTop, créé par ce client (vu de lui seul), dans le personnage de
-- l'attaquant, jusqu'à `fin` (heure serveur, Workspace:GetServerTimeNow), puis retiré ; repris sur son
-- nouveau personnage s'il réapparaît avant la fin ; retiré à son départ. Au plus MAX_HIGHLIGHTS
-- attaquants à la fois (les plus récents). Roblox n'affiche que 31 Highlight à la fois : tant qu'il y en a,
-- ShelfBoxController.Reserve(RESERVE_KEY, nombre) rend autant de places de contours de colis. Un attaquant
-- déjà surligné par l'alerte de vol (TheftAlertHighlight de TheftAlertController) ne l'est pas deux fois.
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

local CameraAlertController = {}

local spotted: { [Player]: Spot } = {}
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

local function refresh()
	local now = Workspace:GetServerTimeNow()
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
				created.FillColor = CAMERA_BLUE
				created.FillTransparency = FILL_TRANSPARENCY
				created.OutlineColor = CAMERA_BLUE
				created.OutlineTransparency = 0
				created.Adornee = character
				created.Parent = character
				spot.Highlight = created
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
	RunService.Heartbeat:Connect(function(dt: number)
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
