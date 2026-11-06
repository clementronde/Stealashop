--!strict
-- StatsService (DEV-011) : Vitesse, Force et WalkSpeed, calculés et appliqués par le serveur
-- (Partie 1, sections 5.1, 5.6, 6.2, 7.1 et 9.6).
--
-- Rôle : lit Stats.Speed et Stats.Strength du profil (DataService), calcule le WalkSpeed et
-- l'applique au Humanoid du joueur à chaque apparition et à chaque changement. C'est le seul
-- code qui écrit Humanoid.WalkSpeed : une écriture faite ailleurs côté serveur est aussitôt
-- annulée (avertissement en Studio). Aucun remote : rien ne vient du client.
--
-- WalkSpeed appliqué au Humanoid, calculé dans cet ordre :
--   1. formule 7.1 : min(70, 16 + 0,05 × Vitesse × M trail), par Formulas.WalkSpeed, avec
--      M trail = StatsService.GetTrailMultiplier(player) ;
--   2. × chaque modificateur posé par SetSpeedModifier ; ils se multiplient entre eux
--      (colis PNJ 0,9 et Adrénaline 1,25 donnent × 1,125) ;
--   3. de nouveau plafonné à 70 : le plafond de 5.1 n'est jamais dépassé.
--   Conséquences : au plafond, le malus de portage se sent quand même (70 → 63 avec un colis
--   PNJ) ; l'Adrénaline ne fait jamais dépasser 70.
--
-- Attributs du Player (écrits seulement ici, posés quand le profil est chargé) :
--   Speed      Vitesse (stat entraînée au tapis)
--   Strength   Force (stat entraînée au banc)
--   WalkSpeed  résultat de l'étape 1, sans les modificateurs temporaires : c'est la valeur à
--              comparer à la vitesse conseillée d'une zone (5.3). La vitesse réellement
--              appliquée est Humanoid.WalkSpeed (répliquée à tous les clients).
--
-- API (côté serveur) :
--   StatsService.GetSpeed(player) -> number      Vitesse du profil, 0 s'il n'est pas chargé
--   StatsService.GetStrength(player) -> number   Force du profil, 0 s'il n'est pas chargé
--   StatsService.AddSpeed(player, n) -> number?
--       Ajoute n (nombre fini ≥ 0) à la Vitesse, met à jour les attributs et le Humanoid.
--       Renvoie la nouvelle valeur, ou nil si le profil n'est pas chargé ou si n est invalide.
--   StatsService.AddStrength(player, n) -> number?   Pareil pour la Force.
--   StatsService.SetSpeedModifier(player, key, multiplier?)
--       Pose le multiplicateur de vitesse nommé `key` (nombre fini ≥ 0 ; 0 immobilise), ou le
--       retire avec nil, puis recalcule. Clés prévues : "Carry" (Balance.Carry : 0,9 colis PNJ,
--       0,75 objet volé), "Adrenaline" (1 + PvP.AdrenalineSpeedBonus), "Training" (0, posé
--       par TrainingService). Le service qui pose une clé la retire lui-même, à la mort
--       comme au départ : un modificateur survit à la réapparition.
--   StatsService.Refresh(player)
--       Recalcule et applique tout. À appeler quand le multiplicateur de trail change.
--   StatsService.GetTrailMultiplier(player) -> number
--       Point d'accroche du trail : renvoie 1 ici. CosmeticService le remplace
--       (StatsService.GetTrailMultiplier = function(player) ... end), puis appelle Refresh
--       à chaque changement de trail. Une valeur invalide ou une erreur compte pour 1.
--
-- Exemple (CarryService) :
--   StatsService.SetSpeedModifier(player, "Carry", Balance.Carry.NPCBoxSpeedMultiplier)
--   ...
--   StatsService.SetSpeedModifier(player, "Carry", nil)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Formulas = require(ReplicatedStorage.Shared.Config.Formulas)
local DataService = require(script.Parent.DataService)

local IS_STUDIO = RunService:IsStudio()

-- Écart toléré entre Humanoid.WalkSpeed et la valeur calculée : la propriété est stockée en
-- simple précision, la relecture ne redonne pas exactement le nombre écrit.
local TOLERANCE = 1e-3
-- V0 proposé, absent du doc : attente maximale du Humanoid d'un perso qui apparaît.
local HUMANOID_WAIT = 10

local StatsService = {}
StatsService.Priority = 10 -- juste après DataService, avant les services de jeu

local tracked: { [Player]: boolean } = {}
local modifiers: { [Player]: { [string]: number } } = {}
local applied: { [Player]: number } = {} -- dernière vitesse calculée pour le Humanoid
local guards: { [Player]: RBXScriptConnection } = {}

local function isFiniteNonNegative(n: any): boolean
	return type(n) == "number" and n == n and n >= 0 and n < math.huge
end

function StatsService.GetTrailMultiplier(_player: Player): number
	return 1
end

local function trailMultiplier(player: Player): number
	local ok, value = pcall(StatsService.GetTrailMultiplier, player)
	if ok and isFiniteNonNegative(value) and value > 0 then
		return value
	end
	warn(`[StatsService] GetTrailMultiplier({player.Name}) invalide ({value}) : 1 utilisé`)
	return 1
end

function StatsService.GetSpeed(player: Player): number
	local data = DataService.Get(player)
	return if data then data.Stats.Speed else 0
end

function StatsService.GetStrength(player: Player): number
	local data = DataService.Get(player)
	return if data then data.Stats.Strength else 0
end

local function applyTo(humanoid: Humanoid, value: number)
	if math.abs(humanoid.WalkSpeed - value) > TOLERANCE then
		humanoid.WalkSpeed = value
	end
end

function StatsService.Refresh(player: Player)
	if not tracked[player] then
		return
	end
	local data = DataService.Get(player)
	-- Étape 1 : formule 7.1 (déjà plafonnée à 70).
	local base = Formulas.WalkSpeed(if data then data.Stats.Speed else 0, trailMultiplier(player))
	-- Étapes 2 et 3 : modificateurs, puis plafond.
	local value = base
	local list = modifiers[player]
	if list then
		for _, multiplier in list do
			value *= multiplier
		end
	end
	value = math.min(value, Balance.Stats.MaxWalkSpeed)
	applied[player] = value

	if data then
		player:SetAttribute("Speed", data.Stats.Speed)
		player:SetAttribute("WalkSpeed", base)
	end
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid then
		applyTo(humanoid, value)
	end
end

function StatsService.AddSpeed(player: Player, amount: number): number?
	local data = DataService.Get(player)
	if data == nil or not isFiniteNonNegative(amount) then
		return nil
	end
	data.Stats.Speed += amount
	StatsService.Refresh(player)
	return data.Stats.Speed
end

function StatsService.AddStrength(player: Player, amount: number): number?
	local data = DataService.Get(player)
	if data == nil or not isFiniteNonNegative(amount) then
		return nil
	end
	data.Stats.Strength += amount
	player:SetAttribute("Strength", data.Stats.Strength)
	return data.Stats.Strength
end

function StatsService.SetSpeedModifier(player: Player, key: string, multiplier: number?)
	if type(key) ~= "string" or key == "" then
		warn(debug.traceback(`[StatsService] SetSpeedModifier : clé invalide ({key})`, 2))
		return
	end
	if multiplier ~= nil and not isFiniteNonNegative(multiplier) then
		warn(debug.traceback(`[StatsService] SetSpeedModifier « {key} » : multiplicateur invalide ({multiplier})`, 2))
		return
	end
	if not tracked[player] then
		return -- joueur parti
	end
	local list = modifiers[player]
	if multiplier == nil then
		if list == nil or list[key] == nil then
			return -- rien à retirer
		end
		list[key] = nil
	else
		if list == nil then
			list = {}
			modifiers[player] = list
		end
		list[key] = multiplier
	end
	StatsService.Refresh(player)
end

-- À chaque apparition : applique la vitesse et annule toute écriture de Humanoid.WalkSpeed
-- faite ailleurs côté serveur.
local function watchCharacter(player: Player, character: Model)
	local found = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", HUMANOID_WAIT)
	if found == nil or not found:IsA("Humanoid") or player.Character ~= character or not tracked[player] then
		return
	end
	local humanoid: Humanoid = found
	local old = guards[player]
	if old then
		old:Disconnect()
	end
	guards[player] = humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		local expected = applied[player]
		if expected == nil or math.abs(humanoid.WalkSpeed - expected) <= TOLERANCE then
			return
		end
		if IS_STUDIO then
			warn(
				`[StatsService] WalkSpeed de {player.Name} écrit hors de StatsService ({humanoid.WalkSpeed}) : remis à {expected}. Passer par StatsService.SetSpeedModifier.`
			)
		end
		humanoid.WalkSpeed = expected
	end)
	StatsService.Refresh(player)
end

local function onPlayerAdded(player: Player)
	if tracked[player] then
		return
	end
	tracked[player] = true
	player.CharacterAdded:Connect(function(character: Model)
		watchCharacter(player, character)
	end)
	local character = player.Character
	if character then
		task.spawn(watchCharacter, player, character)
	end
end

local function onPlayerRemoving(player: Player)
	tracked[player] = nil
	modifiers[player] = nil
	applied[player] = nil
	local guard = guards[player]
	if guard then
		guard:Disconnect()
		guards[player] = nil
	end
end

function StatsService.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	DataService.OnProfileLoaded(function(player: Player)
		local data = DataService.Get(player)
		if data == nil or not tracked[player] then
			return
		end
		player:SetAttribute("Strength", data.Stats.Strength)
		StatsService.Refresh(player) -- Speed, WalkSpeed et Humanoid
		if IS_STUDIO then
			print(
				`[StatsService] {player.Name} : Vitesse {data.Stats.Speed}, Force {data.Stats.Strength}, WalkSpeed {player:GetAttribute("WalkSpeed")}`
			)
		end
	end)
end

return StatsService
