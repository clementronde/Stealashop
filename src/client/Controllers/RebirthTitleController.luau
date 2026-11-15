--!strict
-- RebirthTitleController (vague 56, a183 ; L-173 et L-168 Q2, client) : le titre de renaissance au-dessus de
-- chaque joueur. Seule récompense « visible » qui reste à la renaissance (décision de Clément du 2026-11-15).
--
-- Contrat (Config/Rebirths.Title ; noms proposés à Clément, V0, facultatifs au contrat) :
--   - billboard modèle ReplicatedStorage/Assets/UI/BB_RebirthTitle, avec le TextLabel TitleLabel ;
--   - le serveur (RebirthService) pose sur chaque Player l'attribut Rebirths = renaissances faites, seulement
--     quand la renaissance est ouverte (Features.Rebirth, ou RebirthTest en Studio).
-- Pour chaque joueur (le joueur local compris) qui a au moins Title.FromLevel renaissances : une copie du
-- billboard, nommée comme lui, sur la tête de son personnage (Adornee = Head), TitleLabel = « REBIRTH n ».
-- Refaite à chaque personnage, mise à jour quand Rebirths change, retirée quand l'attribut disparaît.
-- Billboard absent (pas encore livré) ou renaissance coupée : rien n'est posé. Le code ne change ni taille,
-- ni couleur, ni hauteur : tout est réglé par Clément dans le billboard (StudsOffset, MaxDistance…).
--
-- API (client) : aucune.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Rebirths = require(Config:WaitForChild("Rebirths"))
local SkillTree = require(Config:WaitForChild("SkillTree"))
local Contract = Shared:WaitForChild("Contract")
local Find = require(Contract:WaitForChild("Find"))
local UI = require(Contract:WaitForChild("UI"))

local TITLE = Rebirths.Title
local COUNT_ATTRIBUTE = SkillTree.RebirthsAttribute -- « Rebirths », posé par RebirthService
local HEAD = "Head"
local IS_STUDIO = RunService:IsStudio()

local RebirthTitleController = {}

local reported = false

-- Billboard modèle de Clément, ou nil (une ligne en Studio, une seule fois).
local function template(): BillboardGui?
	local current: Instance? = ReplicatedStorage
	for _, segment in UI.BillboardFolder do
		current = if current then current:FindFirstChild(segment) else nil
	end
	local found = if current then current:FindFirstChild(TITLE.Billboard, true) else nil
	if found and found:IsA("BillboardGui") then
		return found
	end
	if IS_STUDIO and not reported then
		reported = true
		print(`[RebirthTitle] {TITLE.Billboard} absent de ReplicatedStorage.{table.concat(UI.BillboardFolder, ".")} : pas de titre de renaissance au-dessus des joueurs`)
	end
	return nil
end

-- Pose, met à jour ou retire le titre de `player` sur son personnage actuel.
local function refresh(player: Player)
	local character = player.Character
	local head = if character then character:FindFirstChild(HEAD) else nil
	if head == nil or not head:IsA("BasePart") then
		return
	end
	local existing = head:FindFirstChild(TITLE.Billboard)
	local done = SkillTree.RebirthsOf(player:GetAttribute(COUNT_ATTRIBUTE))
	local wanted: string? = if done then Rebirths.TitleText(done) else nil
	if wanted == nil then
		if existing then
			existing:Destroy()
		end
		return
	end
	local text: string = wanted
	local billboard = existing
	if billboard == nil then
		local model = template()
		if model == nil then
			return
		end
		local copy = model:Clone()
		copy.Adornee = head
		copy.Enabled = true
		copy.Parent = head
		billboard = copy
	end
	local label = Find.path(billboard :: Instance, TITLE.Label)
	if label and label:IsA("TextLabel") and (label :: TextLabel).Text ~= text then
		(label :: TextLabel).Text = text
	end
end

local function watch(player: Player)
	player:GetAttributeChangedSignal(COUNT_ATTRIBUTE):Connect(function()
		refresh(player)
	end)
	player.CharacterAdded:Connect(function(character: Model)
		-- La tête peut arriver après le personnage (StreamingEnabled, apparition).
		if character:FindFirstChild(HEAD) == nil then
			character:WaitForChild(HEAD, 10)
		end
		if player.Character == character then
			refresh(player)
		end
	end)
	refresh(player)
end

function RebirthTitleController.Start()
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return RebirthTitleController
