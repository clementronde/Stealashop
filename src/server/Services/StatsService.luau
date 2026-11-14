--!strict
-- StatsService (DEV-011) : Vitesse et WalkSpeed, calculés et appliqués par le serveur
-- (Partie 1, sections 5.1, 5.6, 6.2, 7.1 et 9.6).
-- Rééquilibrage v2 (Cantin, 2026-11-14) : plus de Force (plus de banc) : Stats.Strength reste dans les
-- profils, sans effet, et n'est plus lu ; la marche suit la Speed affichée en log (Formulas.WalkSpeed).
--
-- Rôle : lit Stats.Speed du profil (DataService), calcule le WalkSpeed et
-- l'applique au Humanoid du joueur à chaque apparition et à chaque changement. C'est le seul
-- code qui écrit Humanoid.WalkSpeed : une écriture faite ailleurs côté serveur est aussitôt
-- annulée (avertissement en Studio). Aucun remote : rien ne vient du client.
--
-- WalkSpeed appliqué au Humanoid, calculé dans cet ordre :
--   1. formule v2 : min(70, 16 + 4 × log10(1 + Vitesse × M trail / 100)), par Formulas.WalkSpeed, avec
--      M trail = StatsService.GetTrailMultiplier(player) ;
--   2. × chaque modificateur posé par SetSpeedModifier ; ils se multiplient entre eux
--      (colis PNJ 0,9 et Adrénaline 1,25 donnent × 1,125) ;
--   3. de nouveau plafonné à 70 ;
--   4. × les modificateurs posés « au-dessus du plafond » (aboveCap) : plus aucun depuis le retrait de la
--      potion de vitesse (Cantin, 2026-11-14) ; le mécanisme reste pour un futur bonus.
--   Conséquences : au plafond, le malus de portage se sent quand même (70 → 63 avec un colis
--   PNJ) ; l'Adrénaline ne fait jamais dépasser 70.
--   Vitesse fixe (SetFixedSpeed, objet volé à un joueur, Cantin 2026-11-13) : remplace les étapes 1 à 4 ;
--   seul un modificateur à 0 (étourdi, entraînement) compte encore et immobilise.
--
-- Attributs du Player (écrits seulement ici, posés quand le profil est chargé) :
--   Speed      Vitesse (stat entraînée au tapis)
--   ShownSpeed Speed affichée = Vitesse × M trail (Formulas.ShownSpeed) : c'est elle que le HUD écrit et que
--              les panneaux comparent à Zones[n].SpeedRequired (v2)
--   WalkSpeed  résultat de l'étape 1, sans les modificateurs temporaires : c'est la valeur à
--              comparer à la vitesse conseillée d'une zone (5.3). La vitesse réellement
--              appliquée est Humanoid.WalkSpeed (répliquée à tous les clients).
--
-- API (côté serveur) :
--   StatsService.GetSpeed(player) -> number      Vitesse du profil, 0 s'il n'est pas chargé
--   StatsService.AddSpeed(player, n) -> number?
--       Ajoute n (nombre fini ≥ 0) à la Vitesse, met à jour les attributs et le Humanoid.
--       Renvoie la nouvelle valeur, ou nil si le profil n'est pas chargé ou si n est invalide.
--   StatsService.SetSpeedModifier(player, key, multiplier?, aboveCap?)
--       Pose le multiplicateur de vitesse nommé `key` (nombre fini ≥ 0 ; 0 immobilise), ou le
--       retire avec nil, puis recalcule. aboveCap = true : appliqué après le plafond (étape 4).
--       Clés prévues : "Carry" (Balance.Carry : 0,9 colis PNJ,
--       0,75 objet volé), "Adrenaline" (1 + PvP.AdrenalineSpeedBonus), "Training" (0, posé
--       par TrainingService), "GuardStun" (0, joueur rattrapé par un vigile, GuardService),
--       "BatStun" (0, étourdi Bat.StunDuration s par un coup de batte, BatService). Le service
--       qui pose une clé la retire lui-même, à la mort comme au départ : un modificateur survit
--       à la réapparition. Plus aucune clé n'est posée avec aboveCap (potion de vitesse retirée).
--   StatsService.SetFixedSpeed(player, walkSpeed?)
--       Pose une vitesse fixe (nombre fini ≥ 0) qui remplace tout le calcul, sauf un modificateur à 0, ou la
--       retire avec nil, puis recalcule. Posée et retirée par CarryService (objet volé à un joueur).
--   StatsService.GetSpeedBoost(player) -> number
--       Produit des modificateurs posés au-dessus du plafond, 1 sans eux.
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
local aboveCapKeys: { [Player]: { [string]: boolean } } = {} -- clés appliquées après le plafond (aucune aujourd'hui)
local fixedSpeeds: { [Player]: number? } = {} -- vitesse fixe (SetFixedSpeed)
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

local function applyTo(humanoid: Humanoid, value: number)
	if math.abs(humanoid.WalkSpeed - value) > TOLERANCE then
		humanoid.WalkSpeed = value
	end
end

-- Produit des modificateurs posés au-dessus du plafond (1 sans eux).
function StatsService.GetSpeedBoost(player: Player): number
	local list = modifiers[player]
	local above = aboveCapKeys[player]
	local boost = 1
	if list and above then
		for key in above do
			boost *= list[key] or 1
		end
	end
	return boost
end

function StatsService.Refresh(player: Player)
	if not tracked[player] then
		return
	end
	local data = DataService.Get(player)
	-- Étape 1 : formule v2 (déjà plafonnée à 70).
	local trail = trailMultiplier(player)
	local base = Formulas.WalkSpeed(if data then data.Stats.Speed else 0, trail)
	-- Étapes 2 et 3 : modificateurs, puis plafond ; étape 4 : modificateurs posés au-dessus du plafond.
	local value = base
	local list = modifiers[player]
	local above = aboveCapKeys[player]
	if list then
		for key, multiplier in list do
			if not (above and above[key]) then
				value *= multiplier
			end
		end
	end
	value = math.min(value, Balance.Stats.MaxWalkSpeed)
	value *= StatsService.GetSpeedBoost(player)
	local fixed = fixedSpeeds[player]
	if fixed ~= nil then
		value = fixed
		if list then
			for _, multiplier in list do
				if multiplier == 0 then
					value = 0 -- étourdi ou à l'entraînement : immobile quand même
				end
			end
		end
	end
	applied[player] = value

	if data then
		player:SetAttribute("Speed", data.Stats.Speed)
		player:SetAttribute("ShownSpeed", Formulas.ShownSpeed(data.Stats.Speed, trail))
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

function StatsService.SetSpeedModifier(player: Player, key: string, multiplier: number?, aboveCap: boolean?)
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
	local above = aboveCapKeys[player]
	if multiplier == nil then
		if list == nil or list[key] == nil then
			return -- rien à retirer
		end
		list[key] = nil
		if above then
			above[key] = nil
		end
	else
		if list == nil then
			list = {}
			modifiers[player] = list
		end
		list[key] = multiplier
		if aboveCap then
			if above == nil then
				above = {}
				aboveCapKeys[player] = above
			end
			above[key] = true
		elseif above then
			above[key] = nil
		end
	end
	StatsService.Refresh(player)
end

function StatsService.SetFixedSpeed(player: Player, walkSpeed: number?)
	if walkSpeed ~= nil and not isFiniteNonNegative(walkSpeed) then
		warn(debug.traceback(`[StatsService] SetFixedSpeed : vitesse invalide ({walkSpeed})`, 2))
		return
	end
	if not tracked[player] or fixedSpeeds[player] == walkSpeed then
		return -- joueur parti, ou rien ne change
	end
	fixedSpeeds[player] = walkSpeed
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
	aboveCapKeys[player] = nil
	fixedSpeeds[player] = nil
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
		StatsService.Refresh(player) -- Speed, ShownSpeed, WalkSpeed et Humanoid
		if IS_STUDIO then
			print(
				`[StatsService] {player.Name} : Vitesse {data.Stats.Speed}, Speed affichée {player:GetAttribute("ShownSpeed")}, WalkSpeed {player:GetAttribute("WalkSpeed")}`
			)
		end
	end)
end

return StatsService
