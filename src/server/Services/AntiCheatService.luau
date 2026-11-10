--!strict
-- AntiCheatService (DEV-060) : contrôle des déplacements et journal des anomalies (Partie 1,
-- sections 9.3, 9.6 et 14.3 ; valeurs : Config/AntiCheat ; interrupteur : Config/Features.AntiCheat).
--
-- V0 prudente : un faux positif gâche la partie d'un joueur honnête, donc mieux vaut laisser passer
-- un tricheur qu'accuser un innocent. Chaque marge penche du côté du joueur.
--
-- Contrôle, côté serveur, toutes les AntiCheat.CheckInterval s (0,25), pour chaque personnage vivant
-- (position du HumanoidRootPart, celle que le client du joueur réplique) :
--   - seul le déplacement à l'horizontale compte : chutes et sauts sont normaux ;
--   - vitesse autorisée = la plus haute Humanoid.WalkSpeed des AntiCheat.SpeedMemory dernières
--     secondes (StatsService l'applique : formule 7.1, trail, Adrénaline, malus de portage,
--     étourdissement, entraînement), jamais moins que MinSpeed (16). Un autre joueur ou un vigile à
--     PushRadius studs ou moins peut pousser : sa vitesse compte aussi ;
--   - réserve (latence, rafales du réseau) : chaque contrôle accorde vitesse autorisée ×
--     SpeedTolerance (1,25) × temps réellement écoulé ; ce qui ne sert pas reste en réserve, au plus
--     BurstSeconds s de déplacement + SlackStuds. Aller plus loin que la réserve = une anomalie (la
--     réserve repart de 0 : une rafale ne fait qu'une anomalie). MaxAnomalies (3) anomalies en
--     AnomalyWindow (5 s) = détection « Speed » ;
--   - téléport : un saut plus long que vitesse autorisée × 1,25 × (temps écoulé + TeleportLag) +
--     SlackStuds, et que TeleportDistance (30 studs, 9.6) = détection « Teleport », tout de suite ;
--   - réseau figé : position inchangée alors que la vitesse répliquée du HumanoidRootPart dépasse
--     StaleSpeed (le réseau du joueur s'est arrêté, lui court toujours) : ce temps, au plus
--     StaleMax, s'ajoute à la réserve et au seuil du téléport, pour la position qui revient d'un coup.
--
-- Ce que le code fait lui-même n'est jamais pris pour de la triche :
--   - chaque service qui déplace un joueur appelle Allow juste avant (liste plus bas) ;
--   - apparition d'un personnage (réapparition comprise) : AntiCheat.SpawnGrace s sans contrôle ;
--   - arrivée en retard d'un déplacement du code (AntiCheat.LateArrival s après la fin de l'Allow) :
--     un saut vers un point qu'on peut atteindre en marchant depuis sa destination est accepté, un
--     retour près de son point de départ (position d'avant encore en route) est ignoré ;
--   - personnage mort : plus contrôlé jusqu'au suivant ;
--   - retour en arrière fait par ce service : pendant AntiCheat.RollbackGrace s (+ ping), seule une
--     position qu'on peut atteindre depuis le point du retour est prise (sans contrôle), les autres
--     sont ignorées (le client envoie encore ses positions d'avant). Ensuite, tout est contrôlé : un
--     client resté loin du point (retour refusé, nouveau téléport) est de nouveau détecté.
-- Déplacements autorisés (DEV-060) : PlotService (placement sur sa parcelle à chaque apparition et
-- TeleportHome, donc ReturnBaseService et le renvoi de nuit ; PutOutside, sortie d'une boutique du hub
-- par PvPService), StoreHeistService (sortie d'un magasin fermé ou reconstruit), NightCycleService
-- (renvoi derrière le mur, quand le joueur n'a pas de parcelle), TrainingService (placement sur le
-- tapis ou le banc), BatService et GuardService (poussées : coup de batte, capture).
--
-- Détection (Teleport, ou Speed) :
--   - toujours : une ligne dans la sortie (warn), la récidive comptée (par UserId, pour tout le
--     serveur ; attribut AntiCheat.StrikesAttribute du Player), une entrée au journal (GetLog) et
--     OnDetection ;
--   - sanction V0, hors de Studio, ou en Studio avec workspace:SetAttribute("AntiCheatStrict", true) :
--     ce que le joueur porte est rendu (CarryService.ReportAnomaly : le colis revole vers son rayon,
--     l'objet volé vers son présentoir), puis il revient en arrière : après un téléport, à la position
--     du contrôle d'avant ; après un excès de vitesse, là où il a commencé (dernier contrôle avec la
--     réserve pleine), réserve vide : continuer à tricher le ramène au même point. Jamais d'expulsion
--     en V0 : les récidives sont seulement comptées.
--   - En Studio sans l'attribut : détection et ligne seulement, ni retour ni colis rendu (le Claude
--     principal téléporte souvent son personnage pour tester), le contrôle repart de la nouvelle
--     position.
--
-- API (serveur) :
--   AntiCheatService.Allow(player, seconds, reason)
--       Le code va déplacer `player` lui-même pendant `seconds` s (0 = téléport instantané) : rien
--       n'est contrôlé jusqu'à seconds + AntiCheat.AllowSettle + ping × AllowPingFactor (au plus
--       AllowPingMax), puis le contrôle repart de sa nouvelle position. À appeler juste avant le
--       déplacement (PivotTo, poussée). `reason` (texte court, nom du service) est rappelé dans la
--       ligne d'une détection qui suivrait de près. Plusieurs appels : la fin la plus tardive compte.
--       Arguments invalides : avertissement, rien ne change. Features.AntiCheat = false : rien.
--   AntiCheatService.Verify(player, from?, since?) -> boolean
--       Contrôle tout de suite, sans attendre le suivant (même règle, même état), juste avant qu'un
--       portage réussisse : dépôt d'un objet volé (PvPService). Avec `from` (Vector3) et `since`
--       (os.clock()) : en plus, le trajet entier depuis `from`, en ligne droite, ne peut pas dépasser
--       vitesse autorisée × SpeedTolerance × (temps écoulé + TeleportLag) + SlackStuds (« Speed »,
--       sinon un speed hack sur un trajet court arrive avant la 3e anomalie) ; sauté si le code l'a
--       déplacé (Allow) depuis `since`. false = détection sanctionnée (le portage vient d'échouer, le
--       joueur est revenu en arrière) ; true sinon, y compris en Studio sans AntiCheatStrict, pendant
--       un Allow et quand le service est coupé.
--   AntiCheatService.GetStrikes(player) -> number    détections de ce joueur sur ce serveur
--   AntiCheatService.GetLog() -> { Detection }       les AntiCheat.LogSize dernières (copie)
--   AntiCheatService.OnDetection(listener) -> déconnexion
--       listener(player, detection) après chaque détection, sanction déjà appliquée (télémétrie).
--
-- Exemple (dans un service qui téléporte un joueur) :
--   AntiCheatService.Allow(player, 0, "StoreHeistService")
--   character:PivotTo(target)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local AntiCheat = require(Shared.Config.AntiCheat)
local Features = require(Shared.Config.Features)

local CarryService = require(script.Parent.CarryService)

export type Kind = "Teleport" | "Speed"

export type Detection = {
	At: number, -- os.time()
	UserId: number,
	Name: string,
	Kind: Kind,
	Detail: string,
	Carrying: boolean, -- portait un colis ou un objet volé
	Sanctioned: boolean, -- portage rendu et retour en arrière (false en Studio sans AntiCheatStrict)
	Strikes: number, -- détections de ce joueur sur ce serveur, celle-ci comprise
}

type DetectionListener = (player: Player, detection: Detection) -> ()

-- Une WalkSpeed remplacée, gardée jusqu'à Until (AntiCheat.SpeedMemory).
type SpeedMark = { Speed: number, Until: number }

type Track = {
	Character: Model,
	Root: BasePart,
	Humanoid: Humanoid,
	LastPos: Vector3?, -- position au dernier contrôle ; nil = à reprendre
	LastAt: number, -- os.clock() du dernier contrôle
	LastValid: Vector3?, -- position du dernier contrôle sans anomalie (retour après un téléport)
	LastFull: Vector3?, -- position du dernier contrôle réserve pleine (retour après un excès de vitesse)
	Hold: Vector3?, -- point d'un retour en arrière, retenu jusqu'à HoldUntil (voir evaluate)
	HoldAt: number,
	HoldUntil: number,
	Credit: number, -- réserve de distance (studs)
	Stale: number, -- temps (s) où la position est restée figée par le réseau
	Anomalies: { number }, -- os.clock() des anomalies récentes
	Speed: number, -- Humanoid.WalkSpeed actuelle
	Marks: { SpeedMark },
	Dead: boolean,
	Connections: { RBXScriptConnection },
}

-- Un joueur ou un vigile qui peut pousser (règle PushRadius).
type Pusher = { Position: Vector3, Speed: number, Player: Player? }

-- Dossier des vigiles en jeu (GuardService) ; même nom dans BatService.
local GUARDS_FOLDER = "ActiveGuards"
-- V0 proposé, absent du doc : attente maximale du HumanoidRootPart et du Humanoid d'un personnage.
local CHARACTER_WAIT = 10
-- En dessous (studs), la position n'a pas bougé du tout : c'est elle qui est figée, pas le joueur.
local STILL = 0.01
-- Après Loader : juste après DataService (1), StatsService et PlotService (10), avant les services
-- de jeu ; Allow peut être appelé avant (l'autorisation attend le personnage).
local PRIORITY = 20

local IS_STUDIO = RunService:IsStudio()
local ENABLED: boolean = Features.AntiCheat

local AntiCheatService = {}
AntiCheatService.Priority = PRIORITY

local tracks: { [Player]: Track } = {}
local allowUntil: { [Player]: number } = {} -- os.clock() de la fin de l'autorisation
local allowReason: { [Player]: string } = {}
local lastAllowAt: { [Player]: number } = {} -- os.clock() du dernier Allow (trajet de Verify)
-- Dernier déplacement du code (Allow) : départ et destination vus par le serveur (AntiCheat.LateArrival).
type CodeMove = { At: number, Origin: Vector3?, Destination: Vector3? }
local codeMoves: { [Player]: CodeMove } = {}
local strikes: { [number]: number } = {} -- UserId → détections (récidives, gardées après un départ)
local journal: { Detection } = {}
local listeners: { DetectionListener } = {}
local elapsed = 0

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function isFinite(n: any): boolean
	return type(n) == "number" and n == n and n > -math.huge and n < math.huge
end

local function sanctionsActive(): boolean
	return not IS_STUDIO or Workspace:GetAttribute(AntiCheat.StrictAttribute) == true
end

local function isCarrying(player: Player): boolean
	local ok, carrying = pcall(CarryService.IsCarrying, player)
	return ok and carrying == true
end

-- Ping du joueur (s) ; 0 s'il est inconnu.
local function pingOf(player: Player): number
	local ok, ping = pcall(function(): number
		return player:GetNetworkPing()
	end)
	if ok and isFinite(ping) and ping > 0 then
		return ping
	end
	return 0
end

-- Marge ajoutée après un déplacement fait par le code (voir Allow).
local function settleOf(player: Player, base: number): number
	return base + math.min(pingOf(player) * AntiCheat.AllowPingFactor, AntiCheat.AllowPingMax)
end

-- Pas de contrôle jusqu'à `untilAt` (os.clock()) ; la fin la plus tardive l'emporte.
local function extend(player: Player, untilAt: number, reason: string)
	local current = allowUntil[player]
	if current == nil or untilAt > current then
		allowUntil[player] = untilAt
	end
	allowReason[player] = reason
	local track = tracks[player]
	if track then
		table.clear(track.Anomalies) -- le code a déplacé le joueur : on repart de zéro
		track.Hold = nil
	end
end

local function rate(speed: number): number
	return speed * AntiCheat.SpeedTolerance
end

-- Réserve pleine pour la vitesse autorisée `speed`, sans temps figé.
local function fullCredit(speed: number): number
	return rate(speed) * AntiCheat.BurstSeconds + AntiCheat.SlackStuds
end

-- Vitesse autorisée par ses propres WalkSpeed (voir l'en-tête), sans les voisins.
local function ownSpeed(track: Track, now: number): number
	local best = if isFinite(track.Speed) then math.max(track.Speed, 0) else 0
	local marks = track.Marks
	local i = 1
	while i <= #marks do
		local mark = marks[i]
		if mark.Until < now then
			table.remove(marks, i)
		else
			if mark.Speed > best then
				best = mark.Speed
			end
			i += 1
		end
	end
	return math.max(best, AntiCheat.MinSpeed)
end

-- Joueurs (vivants, contrôlés) et vigiles qui peuvent pousser.
local function pushers(now: number): { Pusher }
	local list: { Pusher } = {}
	for player, track in tracks do
		if not track.Dead and track.Root.Parent ~= nil then
			table.insert(list, { Position = track.Root.Position, Speed = ownSpeed(track, now), Player = player })
		end
	end
	local folder = Workspace:FindFirstChild(GUARDS_FOLDER)
	if folder then
		for _, model in folder:GetChildren() do
			local root = model:FindFirstChild("HumanoidRootPart")
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if root and root:IsA("BasePart") and humanoid and isFinite(humanoid.WalkSpeed) then
				table.insert(list, { Position = root.Position, Speed = humanoid.WalkSpeed })
			end
		end
	end
	return list
end

-- Vitesse autorisée de `player` en `position` : la sienne, ou celle d'un voisin qui peut le pousser.
local function allowedSpeed(player: Player, track: Track, position: Vector3, list: { Pusher }, now: number): number
	local speed = ownSpeed(track, now)
	local radius = AntiCheat.PushRadius
	local last = track.LastPos
	for _, other in list do
		if other.Player ~= player and other.Speed > speed then
			local close = flat(other.Position - position).Magnitude <= radius
				or (last ~= nil and flat(other.Position - last).Magnitude <= radius)
			if close then
				speed = other.Speed
			end
		end
	end
	return speed
end

-- Le contrôle repart de `position` (tenue pour valide), avec `credit` studs de réserve.
local function rebase(track: Track, position: Vector3, now: number, credit: number)
	track.LastPos = position
	track.LastAt = now
	track.LastValid = position
	track.LastFull = position
	track.Hold = nil
	track.Credit = credit
	track.Stale = 0
end

-- Distance la plus longue d'un seul contrôle à l'autre, au-delà de laquelle c'est un téléport.
local function teleportReach(speed: number, seconds: number, stale: number): number
	return math.max(AntiCheat.TeleportDistance, rate(speed) * (seconds + AntiCheat.TeleportLag + stale) + AntiCheat.SlackStuds)
end

-- Arrivée en retard d'un déplacement du code (AntiCheat.LateArrival) : true si le dernier Allow était un
-- vrai saut (plus long que `threshold`, le seuil du téléport de ce contrôle), que le serveur voyait
-- encore le joueur autour de son point de départ (`last`, positions d'avant) et que `position` tombe à
-- `threshold` au plus de sa destination. Ne sert qu'une fois par Allow.
local function lateArrival(player: Player, last: Vector3, position: Vector3, speed: number, threshold: number, now: number): boolean
	local move = codeMoves[player]
	local allowedTo = allowUntil[player]
	if move == nil or allowedTo == nil or now > allowedTo + AntiCheat.LateArrival then
		return false
	end
	local origin, destination = move.Origin, move.Destination
	if origin == nil or destination == nil or flat(destination - origin).Magnitude <= threshold then
		return false
	end
	local aroundOrigin = flat(last - origin).Magnitude <= teleportReach(speed, math.max(now - move.At, 0), 0)
	if not aroundOrigin or flat(position - destination).Magnitude > threshold then
		return false
	end
	codeMoves[player] = nil
	return true
end

-- Nombre pour la sortie, avec `decimals` chiffres après la virgule.
local function fmt(n: number, decimals: number): string
	return string.format(`%.{decimals}f`, n)
end

-- Un contrôle (voir l'en-tête). Renvoie nil (rien), "Anomaly" (une anomalie, pas encore une
-- détection), "Teleport" ou "Speed", et le détail pour la sortie.
local function evaluate(player: Player, track: Track, position: Vector3, speed: number, now: number): (string?, string)
	local last = track.LastPos
	local allowedTo = allowUntil[player]
	if last == nil or (allowedTo ~= nil and now < allowedTo) then
		rebase(track, position, now, fullCredit(speed))
		return nil, ""
	end
	-- Retenue après un retour en arrière : jusqu'à ce que le client l'ait reçu, il envoie encore ses
	-- positions d'avant. Une position qu'on peut atteindre depuis le point du retour devient le point de
	-- départ du contrôle suivant, sans être contrôlée ; les autres sont ignorées. Après HoldUntil, tout
	-- est contrôlé : un client toujours loin du point (retour refusé, nouveau téléport) est de nouveau
	-- détecté, et la dernière position valide reste le point du retour.
	local hold = track.Hold
	if hold ~= nil then
		if now < track.HoldUntil then
			if flat(position - hold).Magnitude <= teleportReach(speed, now - track.HoldAt, 0) then
				track.LastPos = position
				track.LastAt = now
			end
			return nil, ""
		end
		track.Hold = nil
	end
	local dt = math.max(now - track.LastAt, 0)
	local moved = flat(position - last).Magnitude
	local r = rate(speed)
	local stale = track.Stale
	local cap = r * (AntiCheat.BurstSeconds + stale) + AntiCheat.SlackStuds
	local available = math.min(track.Credit, cap) + r * dt
	local threshold = teleportReach(speed, dt, stale)

	-- Un déplacement du code arrivé en retard chez le client n'est ni un téléport ni une anomalie.
	if moved > available and lateArrival(player, last, position, speed, threshold, now) then
		if IS_STUDIO then
			print(`[AntiCheatService] {player.Name} : arrivée en retard d'un déplacement du code ({fmt(moved, 0)} studs, {allowReason[player]}), acceptée`)
		end
		rebase(track, position, now, fullCredit(speed))
		return nil, ""
	end

	local velocity = flat(track.Root.AssemblyLinearVelocity).Magnitude
	if moved < STILL and isFinite(velocity) and velocity >= AntiCheat.StaleSpeed then
		track.Stale = math.min(stale + dt, AntiCheat.StaleMax)
	else
		track.Stale = 0
	end
	track.LastPos = position
	track.LastAt = now

	if moved > threshold then
		track.Credit = 0
		return "Teleport",
			`téléport de {fmt(moved, 0)} studs en {fmt(dt, 2)} s (seuil {fmt(threshold, 0)}, vitesse autorisée {fmt(speed, 1)})`
	end
	if moved > available then
		track.Credit = 0
		local anomalies = track.Anomalies
		local i = 1
		while i <= #anomalies do
			if now - anomalies[i] > AntiCheat.AnomalyWindow then
				table.remove(anomalies, i)
			else
				i += 1
			end
		end
		table.insert(anomalies, now)
		local detail = `{fmt(moved, 1)} studs en {fmt(dt, 2)} s (permis {fmt(available, 1)}, vitesse autorisée {fmt(speed, 1)})`
		if #anomalies >= AntiCheat.MaxAnomalies then
			table.clear(anomalies)
			return "Speed", `trop rapide : {AntiCheat.MaxAnomalies} anomalies en {AntiCheat.AnomalyWindow} s, la dernière {detail}`
		end
		return "Anomaly", `anomalie de vitesse {#anomalies}/{AntiCheat.MaxAnomalies} : {detail}`
	end
	track.Credit = available - moved
	track.LastValid = position
	if track.Credit >= r * AntiCheat.BurstSeconds then
		track.LastFull = position -- réserve (presque) pleine : rien d'emprunté jusqu'ici
	end
	return nil, ""
end

-- Dernière autorisation, pour la ligne d'une détection (aide à repérer un Allow trop court).
local function lastAllowText(player: Player, now: number): string
	local reason = allowReason[player]
	local untilAt = allowUntil[player]
	if reason == nil or untilAt == nil then
		return ""
	end
	return ` ; dernière autorisation : {reason}, finie il y a {fmt(math.max(now - untilAt, 0), 1)} s`
end

-- Retour en arrière (sanction) : après un téléport, à la dernière position valide (le contrôle
-- d'avant) ; après un excès de vitesse, là où il a commencé (dernier contrôle réserve pleine), réserve
-- vide : continuer à tricher le ramène au même point. Puis la retenue de RollbackGrace s (evaluate).
local function rollback(player: Player, track: Track, kind: Kind, now: number)
	local target = if kind == "Speed" then track.LastFull or track.LastValid else track.LastValid
	local character = track.Character
	local root = track.Root
	if target == nil or character.Parent == nil or root.Parent == nil then
		return
	end
	local frame = CFrame.new(target) * root.CFrame.Rotation
	-- Le pivot d'un personnage standard est son HumanoidRootPart ; le décalage couvre les autres cas.
	character:PivotTo(frame * root.CFrame:ToObjectSpace(character:GetPivot()))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	rebase(track, target, now, if kind == "Speed" then 0 else fullCredit(ownSpeed(track, now)))
	track.Hold = target
	track.HoldAt = now
	track.HoldUntil = now + settleOf(player, AntiCheat.RollbackGrace)
end

local function detect(player: Player, track: Track, kind: Kind, detail: string, now: number): boolean
	local count = (strikes[player.UserId] or 0) + 1
	strikes[player.UserId] = count
	if player.Parent == Players then
		player:SetAttribute(AntiCheat.StrikesAttribute, count)
	end
	local carrying = isCarrying(player)
	local sanctioned = sanctionsActive()
	local detection: Detection = {
		At = os.time(),
		UserId = player.UserId,
		Name = player.Name,
		Kind = kind,
		Detail = detail,
		Carrying = carrying,
		Sanctioned = sanctioned,
		Strikes = count,
	}
	table.freeze(detection :: any) -- partagée par le journal et les écouteurs : lue, jamais modifiée
	table.insert(journal, detection)
	while #journal > AntiCheat.LogSize do
		table.remove(journal, 1)
	end

	local context = `({count}e détection de {player.Name} sur ce serveur{lastAllowText(player, now)})`
	if sanctioned then
		local where = if kind == "Speed" then "là où l'excès a commencé" else "à la dernière position valide"
		local what = if carrying then "portage rendu et retour" else "retour"
		warn(`[AntiCheatService] {player.Name} : {detail} : {what} {where} {context}`)
		if carrying then
			local ok, err = pcall(CarryService.ReportAnomaly, player, detail)
			if not ok then
				warn(`[AntiCheatService] CarryService.ReportAnomaly({player.Name}) : {err}`)
			end
		end
		rollback(player, track, kind, now)
	else
		warn(
			`[AntiCheatService] {player.Name} : {detail} : Studio, détection seule (workspace:SetAttribute("{AntiCheat.StrictAttribute}", true) pour sanctionner) {context}`
		)
		rebase(track, track.Root.Position, now, fullCredit(ownSpeed(track, now)))
	end
	for _, listener in table.clone(listeners) do
		task.spawn(listener, player, detection)
	end
	return sanctioned
end

-- Contrôle de `player` maintenant ; true si une sanction vient d'être appliquée.
local function checkPlayer(player: Player, track: Track, list: { Pusher }, now: number): boolean
	if track.Dead or track.Root.Parent == nil or not track.Character:IsDescendantOf(Workspace) then
		track.LastPos = nil -- repris de là où il réapparaît
		return false
	end
	local position = track.Root.Position
	local speed = allowedSpeed(player, track, position, list, now)
	local outcome, detail = evaluate(player, track, position, speed, now)
	if outcome == "Teleport" or outcome == "Speed" then
		return detect(player, track, outcome :: Kind, detail, now)
	elseif outcome == "Anomaly" and IS_STUDIO then
		print(`[AntiCheatService] {player.Name} : {detail}`)
	end
	return false
end

local function step()
	local now = os.clock()
	local list = pushers(now)
	for player, track in table.clone(tracks) do
		if tracks[player] == track then
			checkPlayer(player, track, list, now)
		end
	end
end

-- Suivi des personnages ---------------------------------------------------------------------------

local function untrack(player: Player)
	local track = tracks[player]
	if track == nil then
		return
	end
	tracks[player] = nil
	for _, connection in track.Connections do
		connection:Disconnect()
	end
end

local function watch(player: Player, character: Model)
	local rootInstance = character:WaitForChild("HumanoidRootPart", CHARACTER_WAIT)
	local found = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", CHARACTER_WAIT)
	if rootInstance == nil or not rootInstance:IsA("BasePart") or found == nil or not found:IsA("Humanoid") then
		return
	end
	if player.Character ~= character or player.Parent ~= Players then
		return
	end
	local root = rootInstance :: BasePart
	local humanoid = found :: Humanoid
	untrack(player)
	local track: Track = {
		Character = character,
		Root = root,
		Humanoid = humanoid,
		LastPos = nil,
		LastAt = os.clock(),
		LastValid = nil,
		LastFull = nil,
		Hold = nil,
		HoldAt = 0,
		HoldUntil = 0,
		Credit = 0,
		Stale = 0,
		Anomalies = {},
		Speed = humanoid.WalkSpeed,
		Marks = {},
		Dead = humanoid.Health <= 0,
		Connections = {},
	}
	tracks[player] = track
	table.insert(
		track.Connections,
		humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
			local speed = humanoid.WalkSpeed
			if speed ~= track.Speed then
				table.insert(track.Marks, { Speed = track.Speed, Until = os.clock() + AntiCheat.SpeedMemory })
				track.Speed = speed
			end
		end)
	)
	table.insert(
		track.Connections,
		humanoid.Died:Connect(function()
			track.Dead = true
		end)
	)
end

local function onCharacterAdded(player: Player, character: Model)
	untrack(player)
	-- Apparition (réapparition comprise) : le personnage arrive au point d'apparition, puis PlotService
	-- le pose sur sa parcelle (avec son propre Allow).
	extend(player, os.clock() + settleOf(player, AntiCheat.SpawnGrace), "apparition du personnage")
	task.spawn(watch, player, character)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character: Model)
		onCharacterAdded(player, character)
	end)
	player.CharacterRemoving:Connect(function(character: Model)
		local track = tracks[player]
		if track and track.Character == character then
			untrack(player)
		end
	end)
	local character = player.Character
	if character then
		onCharacterAdded(player, character)
	end
end

local function onPlayerRemoving(player: Player)
	untrack(player)
	allowUntil[player] = nil
	allowReason[player] = nil
	lastAllowAt[player] = nil
	codeMoves[player] = nil
	-- strikes[UserId] reste : un tricheur qui revient sur ce serveur garde ses récidives.
end

-- API ------------------------------------------------------------------------------------------------

function AntiCheatService.Allow(player: Player, seconds: number, reason: string)
	if not ENABLED then
		return
	end
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		warn(debug.traceback(`[AntiCheatService] Allow : joueur invalide ({player})`, 2))
		return
	end
	if not isFinite(seconds) or seconds < 0 then
		warn(debug.traceback(`[AntiCheatService] Allow({player.Name}) : durée invalide ({seconds})`, 2))
		return
	end
	local text = if type(reason) == "string" and reason ~= "" then reason else "raison inconnue"
	local now = os.clock()
	lastAllowAt[player] = now
	extend(player, now + settleOf(player, seconds + AntiCheat.AllowSettle), text)
	-- Départ maintenant ; destination lue juste après le déplacement (PivotTo du même fil, juste après).
	-- Lu sur le personnage (son suivi peut ne pas exister encore, juste après l'apparition).
	local character = player.Character
	local found = character and character:FindFirstChild("HumanoidRootPart")
	local root: BasePart? = if found and found:IsA("BasePart") then found else nil
	local move: CodeMove = { At = now, Origin = if root then root.Position else nil, Destination = nil }
	codeMoves[player] = move
	if root then
		task.defer(function()
			if codeMoves[player] == move and root.Parent ~= nil then
				move.Destination = root.Position
			end
		end)
	end
end

function AntiCheatService.Verify(player: Player, from: Vector3?, since: number?): boolean
	if not ENABLED then
		return true
	end
	local track = tracks[player]
	if track == nil then
		return true
	end
	local now = os.clock()
	local list = pushers(now)
	if checkPlayer(player, track, list, now) then
		return false
	end
	-- Trajet entier, en ligne droite, depuis `from` (à os.clock() `since`) : un speed hack sur un trajet
	-- court (entre deux boutiques) arrive avant la 3e anomalie. Rien si le code l'a déplacé entre-temps.
	if typeof(from) ~= "Vector3" or not isFinite(since) or track.Dead or track.LastPos == nil then
		return true
	end
	local start = since :: number
	-- Seul un déplacement du code fait APRÈS la prise excuse le trajet : une fenêtre Allow ouverte avant
	-- (tapis, réapparition) laissait sinon téléporter au magasin puis en zone safe (audit du 2026-11-10).
	local movedAt = lastAllowAt[player]
	if movedAt ~= nil and movedAt >= start then
		return true
	end
	local position = track.Root.Position
	local speed = allowedSpeed(player, track, position, list, now)
	local elapsed = math.max(now - start, 0)
	local distance = flat(position - (from :: Vector3)).Magnitude
	local limit = rate(speed) * (elapsed + AntiCheat.TeleportLag) + AntiCheat.SlackStuds
	if distance <= limit then
		return true
	end
	local detail = `trajet de {fmt(distance, 0)} studs en {fmt(elapsed, 1)} s (permis {fmt(limit, 0)}, vitesse autorisée {fmt(speed, 1)})`
	return not detect(player, track, "Speed", detail, now)
end

function AntiCheatService.GetStrikes(player: Player): number
	return strikes[player.UserId] or 0
end

function AntiCheatService.GetLog(): { Detection }
	return table.clone(journal)
end

function AntiCheatService.OnDetection(listener: DetectionListener): () -> ()
	table.insert(listeners, listener)
	return function()
		local index = table.find(listeners, listener)
		if index then
			table.remove(listeners, index)
		end
	end
end

function AntiCheatService.Init()
	if not ENABLED then
		print("[AntiCheatService] coupé (Features.AntiCheat = false) : aucun contrôle des déplacements")
		return
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed < AntiCheat.CheckInterval then
			return
		end
		elapsed = 0
		step()
	end)
	if IS_STUDIO then
		local function mode(): string
			return if sanctionsActive()
				then "sanctions actives (AntiCheatStrict)"
				else `détection et ligne seulement (workspace:SetAttribute("{AntiCheat.StrictAttribute}", true) pour les sanctions)`
		end
		print(`[AntiCheatService] contrôle des déplacements toutes les {AntiCheat.CheckInterval} s ; Studio : {mode()}`)
		Workspace:GetAttributeChangedSignal(AntiCheat.StrictAttribute):Connect(function()
			print(`[AntiCheatService] Studio : {mode()}`)
		end)
	end
end

return AntiCheatService
