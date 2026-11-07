--!strict
-- ShatterController (DEV-016, client) : fissures, casse, éclats, effets et sons des vitrines
-- (Partie 1, sections 5.2, 5.3, 5.4 et 9.7 ; liaison L-028). Tout est joué en local : rien ne
-- repart au serveur. Réglages : Shared/Config/Shatter.
--
-- Pendant les coups (WindowHit, envoyé par WindowService au frappeur et aux joueurs proches) :
--   - une étoile de fissure au point de frappe calculé par le serveur, sur les deux faces de la
--     vitre (SurfaceGui découpé au bord du verre). Pas d'empilement : un coup à moins de
--     Cracks.ReuseDistance d'une étoile la réutilise ; Cracks.MaxStars au plus (celle touchée il y
--     a le plus longtemps disparaît). Toutes les étoiles d'une vitre suivent ses PV : petites
--     au-dessus de 75 %, puis WIN_Crack_75, WIN_Crack_50 et WIN_Crack_25 quand les PV passent 75,
--     50 et 25 % (Balance.Window.CrackThresholds) ;
--   - régénération (proposition) : les étoiles rapetissent d'un niveau quand les PV repassent
--     Cracks.HealHysteresis au-dessus du seuil, et s'effacent quand la vitre est à nouveau pleine ;
--   - mini-éclats (petits cubes de verre), quelques paillettes et un son de verre dont la hauteur
--     monte quand les PV baissent. Celui qui frappe les joue lui-même, tout de suite (LocalHit,
--     appelé par HitController), au marqueur Impact de son animation, avec un léger tremblement.
-- À la casse (WindowBroken), séquence 5.4 :
--   - la vitre fracturée apparaît à la place de la vitre intacte (cachée par le serveur) : parmi
--     WIN_M_Fractured, _Left et _Right (Assets/Windows), celle dont l'impact (position de son
--     Shard_01) est le plus proche du coup final, si sa taille est celle de la vitre, posée telle
--     quelle ou retournée ; sinon le WindowFractured du magasin. Alignement sur la boîte englobante
--     du WindowFractured du magasin, dans l'orientation de la vitre, jamais sur le pivot (bas au
--     centre chez Clément, centre dans la greybox) ;
--   - arrêt sur image (les éclats restent en place, l'animation de celui qui a frappé s'arrête),
--     flash blanc, tremblement de caméra, « SMASHED! » ; éclair au point d'impact ;
--   - les éclats partent du vrai point d'impact, plus vite près de lui, poussés vers l'intérieur
--     du magasin (côté de son volume Bounds), tournent, tombent, rebondissent, se couchent à plat,
--     puis s'effacent ; petits cubes de verre, paillettes et poussière ; son en 3 couches ;
--   - version à LowEnd.Shards éclats sur appareil faible ou au-delà de LowEnd.MaxFullAtOnce
--     casses en cours ;
--   - pour celui qui frappe, l'explosion part à l'impact de son coup (marqueur Impact) : en
--     attendant, les éclats sont déjà posés, immobiles, à la place du verre caché par le serveur.
--   Les éclats sont ancrés et déplacés par ce contrôleur, comme dans le prototype de Clément : ni
--   CanCollide, ni CanQuery, ni CanTouch, donc ils ignorent les joueurs sans groupe de collision.
--   Ils rebondissent sur ce qui bloque les joueurs (rayons qui respectent CanCollide, personnages
--   exclus). Rien ne reste à la reconstruction : étoiles et éclats de la vitre sont retirés.
--   Qui « participe » (a frappé la vitre il y a moins de Break.ParticipantWindow) reçoit tout ;
--   les autres, flash et tremblement atténués par la distance, sans texte.
--
-- Assets de Clément lus par leur nom (Config.Shatter.Assets), jamais par un ID : Decal WIN_Crack_*
-- et FX_GlassSparkle dans Assets/FX (on prend leur Texture), variantes dans Assets/Windows, sons
-- dans Assets/Sounds (Config.Shatter.Sounds). Un asset absent saute son effet, sans erreur ; en
-- Studio, une ligne au démarrage liste ce qui manque.
--
-- API (client) :
--   ShatterController.LocalHit(windowId, point, track?)
--       Retour immédiat du coup pour celui qui frappe (HitController, juste après HitWindow) :
--       mini-éclats, paillettes, son et léger tremblement, au marqueur Impact de `track`, au plus
--       tard après Hit.ImpactMaxWait, ou tout de suite sans piste. Son étoile de fissure attend
--       l'écho WindowHit du serveur (même point pour tous).
--   ShatterController.IsLowEnd() -> boolean
--       Appareil faible : moins de LowEnd.Fps images/s, ou qualité graphique réglée bas.

local Debris = game:GetService("Debris")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("Shatter"))
local MarkerSounds = require(Shared:WaitForChild("Anim"):WaitForChild("MarkerSounds"))

local Assets = Config.Assets
local Sounds = Config.Sounds
local Cracks = Config.Cracks
local Break = Config.Break
local Shards = Config.Shards
local Cubes = Config.Cubes
local LowEnd = Config.LowEnd
local Hit = Config.Hit
local Particles = Config.Particles

-- Ce que ce contrôleur utilise de WindowController (même dossier).
type WindowApi = {
	GetFraction: (windowId: string) -> number,
	GetWindow: (windowId: string) -> (Instance?, Model?),
	OnHP: (listener: (windowId: string, hp: number, maxHp: number) -> ()) -> () -> (),
	OnHit: (listener: (windowId: string, point: Vector3, hitter: Player?) -> ()) -> () -> (),
	OnBroken: (listener: (windowId: string, impactPoint: Vector3) -> ()) -> () -> (),
	OnRebuilt: (listener: (windowId: string) -> ()) -> () -> (),
	OnRemoved: (listener: (windowId: string) -> ()) -> () -> (),
}

-- Repère d'une vitre : CFrame au centre, X = largeur, Y = haut, Z = normale (épaisseur).
type Glass = { CFrame: CFrame, Width: number, Height: number, Thickness: number }

-- Vitre fracturée de Clément rangée dans Assets/Windows.
type Variant = { Name: string, Shards: { BasePart }, Glass: Glass, Impact: Vector3 }

type Star = {
	X: number, -- position dans le plan de la vitre, depuis son centre (studs) : largeur…
	Y: number, -- … et hauteur
	LastHit: number,
	Labels: { ImageLabel }, -- face avant (rue), face arrière
	Scales: { UIScale },
}

type CrackState = {
	Window: Instance,
	Glass: Glass,
	Canvas: Part, -- pièce invisible locale qui porte les deux SurfaceGui
	Clips: { Frame },
	Stars: { Star },
	Level: number, -- 0 au-dessus du premier seuil, puis 1, 2, 3
}

type Piece = {
	Part: BasePart,
	Position: Vector3,
	Rotation: CFrame, -- orientation seule
	Velocity: Vector3,
	Spin: Vector3, -- vitesse angulaire (rad/s), axe dans le monde
	Thin: Vector3?, -- axe local de l'épaisseur, sur lequel l'éclat se couche ; nil = petit cube
	Half: number, -- demi-épaisseur
	Reach: number, -- marge devant le centre pour toucher le sol
	GroundY: number?, -- petit cube : hauteur du sol, mesurée une fois (pas de rayon à chaque image)
	Base: number, -- transparence de départ
	SettleFrom: CFrame?,
	SettleTo: CFrame?,
	SettleTime: number,
	Resting: boolean,
	Landed: boolean, -- a déjà touché le sol une fois
}

type Group = {
	WindowId: string?,
	Pieces: { Piece },
	StartAt: number, -- les pièces bougent à partir de là (fin de l'arrêt sur image)
	FadeAt: number,
	FadeTime: number,
	EndAt: number,
	Params: RaycastParams?, -- éclats : rayons contre la map ; nil = petits cubes (sol plat)
	IsBreak: boolean, -- éclats d'une casse : comptent dans les casses simultanées
	LandedCount: number, -- pièces qui ont touché le sol
	LandTarget: number, -- OnLand part quand LandedCount l'atteint
	Landed: boolean, -- OnLand déjà parti (ou remplacé par son délai de secours)
	OnLand: ((point: Vector3) -> ())?,
}

-- Coup local en attente de son marqueur Impact.
type Pending = { Point: Vector3, Played: boolean, After: { () -> () }, Connection: RBXScriptConnection? }

type Shake = { Start: number, Duration: number, Amplitude: number, Angle: number, Seed: number }

type ParticleKind = "Sparkle" | "Dust"

local FX_FOLDER_NAME = "_ShatterFX" -- dossier local du Workspace (le serveur ne le voit pas)
local FRACTURED_NAME = "WindowFractured" -- enfant obligatoire (10.4)
local BOUNDS_NAME = "Bounds" -- volume intérieur du magasin (10.4)
local IMPACT_SHARD = "Shard_01" -- l'éclat le plus proche de l'impact (MOD-010)
local SHARD_PATTERN = "^Shard_%d+$"
local IMPACT_MARKER = "Impact" -- marqueur de HitWindow et HitWindowHeavy (2.4)
local SHAKE_STEP = "ShatterCameraShake"
local FACES = { Enum.NormalId.Front, Enum.NormalId.Back } -- face avant = côté rue (−Z de la vitre)
local MIRROR = CFrame.Angles(0, math.pi, 0)
local MIRROR_CHOICES = if Config.Shards.AllowMirrored then { false, true } else { false }
-- Constantes de la simulation, V0 proposés, absents du doc.
local REST_GAP = 0.02 -- espace laissé sous une pièce posée
local SPIN_KEEP = 0.5 -- part de la rotation gardée à chaque rebond
local CUBE_REST_SPEED = 2 -- sous cette vitesse de rebond, un petit cube s'arrête
local GROUND_PROBE = 40 -- longueur du rayon qui cherche le sol des petits cubes
local MAX_STEP = 1 / 30 -- pas de simulation maximal quand les images sont lentes
local SOUND_MAX_LIFETIME = 10 -- un son joué est supprimé au plus tard après ce délai
local PREPARED_MAX_LIFETIME = 10 -- éclats posés dont l'explosion ne viendrait jamais : retirés

local IS_STUDIO = RunService:IsStudio()

local player = Players.LocalPlayer
local rng = Random.new()

local ShatterController = {}

local windowApi: WindowApi? = nil
local fxFolder: Folder? = nil
local warned: { [string]: boolean } = {}
local textures: { [string]: string } = {}
local variantCache: { Variant }? = nil
local cracks: { [string]: CrackState } = {}
local brokenWindows: { [string]: boolean } = {}
local lastLocalHit: { [string]: number } = {}
local pendings: { [string]: Pending } = {}
local groups: { Group } = {}
local loop: RBXScriptConnection? = nil
local shakes: { Shake } = {}
local frameTime = 1 / 60 -- durée moyenne d'une image
local flashEffect: ColorCorrectionEffect? = nil
local flashToken = 0
local textToken = 0
local v0Text: TextLabel? = nil

------------------------------------------------------------------------------
-- Outils
------------------------------------------------------------------------------

local function warnOnce(message: string)
	if warned[message] then
		return
	end
	warned[message] = true
	warn(`[Shatter] {message}`)
end

-- Un effet qui échoue ne casse pas les autres : signalé une fois par message.
local function safe(fn: (...any) -> (), ...: any)
	local ok, err = pcall(fn, ...)
	if not ok then
		warnOnce(tostring(err))
	end
end

local function jitter(amount: number): number
	return 1 + rng:NextNumber(-amount, amount)
end

local function folderAt(path: { string }): Instance?
	local current: Instance? = ReplicatedStorage
	for _, segment in path do
		current = if current then current:FindFirstChild(segment) else nil
	end
	return current
end

-- Texture d'un Decal de Clément rangé dans Assets/FX, ou nil s'il n'est pas livré.
local function fxTexture(name: string): string?
	local cached = textures[name]
	if cached then
		return cached
	end
	local folder = folderAt(Assets.FxFolder)
	local decal = if folder then folder:FindFirstChild(name, true) else nil
	if decal and decal:IsA("Decal") then
		local texture = (decal :: Decal).Texture
		if texture ~= "" then
			textures[name] = texture
			return texture
		end
	end
	return nil
end

local function getFxFolder(): Folder
	local current = fxFolder
	if current and current.Parent then
		return current
	end
	local created = Instance.new("Folder")
	created.Name = FX_FOLDER_NAME
	created.Parent = Workspace
	fxFolder = created
	return created
end

-- Réglage « Réduire les mouvements » du joueur : pas de tremblement de caméra.
local function reducedMotion(): boolean
	local ok, value = pcall(function()
		return (GuiService :: any).ReducedMotionEnabled
	end)
	return ok and value == true
end

function ShatterController.IsLowEnd(): boolean
	if frameTime > 0 and 1 / frameTime < LowEnd.Fps then
		return true
	end
	local ok, level = pcall(function()
		return ((UserSettings() :: any):GetService("UserGameSettings") :: any).SavedQualityLevel.Value
	end)
	return ok and type(level) == "number" and level > 0 and level <= LowEnd.QualityLevel
end

local function isParticipant(windowId: string): boolean
	local at = lastLocalHit[windowId]
	return at ~= nil and os.clock() - at <= Break.ParticipantWindow
end

local function glassColor(source: Instance?): Color3
	if source and source:IsA("BasePart") then
		return (source :: BasePart).Color
	end
	if source and source:IsA("Model") then
		local part = source:FindFirstChildWhichIsA("BasePart", true)
		if part then
			return part.Color
		end
	end
	return Config.GlassColor
end

------------------------------------------------------------------------------
-- Géométrie des vitres
------------------------------------------------------------------------------

-- Boîte englobante des pièces dans l'orientation de `rotation` : (CFrame au centre, taille).
local function boxOf(parts: { BasePart }, rotation: CFrame): (CFrame?, Vector3?)
	local rot = rotation.Rotation
	local low: Vector3? = nil
	local high: Vector3? = nil
	for _, part in parts do
		local cf, half = part.CFrame, part.Size / 2
		for corner = 0, 7 do
			local offset = Vector3.new(
				if corner % 2 == 0 then -half.X else half.X,
				if (corner // 2) % 2 == 0 then -half.Y else half.Y,
				if corner // 4 == 0 then -half.Z else half.Z
			)
			local p = rot:PointToObjectSpace(cf:PointToWorldSpace(offset))
			low = if low then low:Min(p) else p
			high = if high then high:Max(p) else p
		end
	end
	if low == nil or high == nil then
		return nil, nil
	end
	return rot + rot:PointToWorldSpace((low + high) / 2), high - low
end

-- Repère d'une boîte (cf, size) : l'axe le plus fin = normale (Z), l'axe restant le plus vertical
-- = haut (Y, tourné vers le ciel), le dernier = largeur (X).
local function toGlass(cf: CFrame, size: Vector3): Glass
	local axes = { cf.RightVector, cf.UpVector, -cf.LookVector }
	local sizes = { size.X, size.Y, size.Z }
	local thin = 1
	for index = 2, 3 do
		if sizes[index] < sizes[thin] then
			thin = index
		end
	end
	local a = if thin == 1 then 2 else 1
	local b = if thin == 3 then 2 else 3
	local up, wide = a, b
	if math.abs(axes[b].Y) > math.abs(axes[a].Y) then
		up, wide = b, a
	end
	local upDir = if axes[up].Y < 0 then -axes[up] else axes[up]
	local normal = axes[thin]
	return {
		CFrame = CFrame.fromMatrix(cf.Position, upDir:Cross(normal), upDir, normal),
		Width = sizes[wide],
		Height = sizes[up],
		Thickness = sizes[thin],
	}
end

-- Repère de la vitre intacte (fissures, mini-éclats).
local function windowGlass(window: Instance): Glass?
	if window:IsA("BasePart") then
		local part = window :: BasePart
		return toGlass(part.CFrame, part.Size)
	elseif window:IsA("Model") then
		local cf, size = (window :: Model):GetBoundingBox()
		return toGlass(cf, size)
	end
	return nil
end

local function shardParts(root: Instance): { BasePart }
	local list: { BasePart } = {}
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") and string.match(descendant.Name, SHARD_PATTERN) then
			table.insert(list, descendant :: BasePart)
		end
	end
	table.sort(list, function(a: BasePart, b: BasePart): boolean
		return a.Name < b.Name
	end)
	return list
end

-- Variantes de Clément (Assets/Windows), lues une fois.
local function variants(): { Variant }
	local cached = variantCache
	if cached then
		return cached
	end
	local folder = folderAt(Assets.WindowsFolder)
	if folder == nil then
		return {}
	end
	local list: { Variant } = {}
	for _, name in Assets.FracturedVariants do
		local found = folder:FindFirstChild(name)
		if found == nil or not found:IsA("Model") then
			continue
		end
		local model = found :: Model
		local shards = shardParts(model)
		local impact = model:FindFirstChild(IMPACT_SHARD, true)
		if #shards == 0 or impact == nil or not impact:IsA("BasePart") then
			continue
		end
		local cf, size = boxOf(shards, model:GetPivot())
		if cf == nil or size == nil then
			continue
		end
		table.insert(list, {
			Name = name,
			Shards = shards,
			Glass = toGlass(cf, size),
			Impact = (impact :: BasePart).Position,
		})
	end
	variantCache = list
	return list
end

-- Repère de la vitre du magasin pour la casse : orientation de l'objet Window, boîte englobante
-- de son WindowFractured (sinon de la vitre elle-même).
local function targetGlass(window: Instance, fractured: Model?): Glass?
	local rotation: CFrame
	local own: { BasePart } = {}
	if window:IsA("BasePart") then
		rotation = (window :: BasePart).CFrame
		table.insert(own, window :: BasePart)
	elseif window:IsA("Model") then
		rotation = (window :: Model):GetPivot()
		for _, descendant in window:GetDescendants() do
			if descendant:IsA("BasePart") then
				table.insert(own, descendant :: BasePart)
			end
		end
	else
		return nil
	end
	local parts = if fractured then shardParts(fractured) else {}
	if #parts == 0 then
		parts = own
	end
	local cf, size = boxOf(parts, rotation)
	if cf == nil or size == nil then
		return nil
	end
	return toGlass(cf, size)
end

local function sameSize(a: Glass, b: Glass): boolean
	local tolerance = Shards.SizeTolerance
	return math.abs(a.Width - b.Width) <= tolerance
		and math.abs(a.Height - b.Height) <= tolerance
		and math.abs(a.Thickness - b.Thickness) <= tolerance
end

-- Les éclats à lancer et leur placement : la variante dont l'impact est le plus proche du coup
-- final, si sa taille est celle de la vitre ; sinon le WindowFractured du magasin, déjà en place
-- (placement nil).
local function chooseShards(glass: Glass, fractured: Model?, impact: Vector3): ({ BasePart }, CFrame?)
	local best: Variant? = nil
	local bestPlace: CFrame? = nil
	local bestDistance = math.huge
	for _, variant in variants() do
		if not sameSize(variant.Glass, glass) then
			continue
		end
		for _, mirrored in MIRROR_CHOICES do
			local target = if mirrored then glass.CFrame * MIRROR else glass.CFrame
			local place = target * variant.Glass.CFrame:Inverse()
			local distance = (place * variant.Impact - impact).Magnitude
			if distance < bestDistance - 1e-3 then
				best, bestPlace, bestDistance = variant, place, distance
			end
		end
	end
	if best and bestPlace then
		return best.Shards, bestPlace
	end
	if fractured then
		return shardParts(fractured), nil
	end
	return {}, nil
end

-- Vers l'intérieur du magasin : du côté de son volume Bounds ; sinon à l'opposé du point de
-- frappe (le serveur le prend du côté du joueur) ; sinon la normale de la vitre.
local function inwardDirection(glass: Glass, model: Model, impact: Vector3): Vector3
	local normal = glass.CFrame.ZVector
	local center = glass.CFrame.Position
	local bounds = model:FindFirstChild(BOUNDS_NAME, true)
	if bounds and bounds:IsA("BasePart") then
		local side = ((bounds :: BasePart).Position - center):Dot(normal)
		if math.abs(side) > 0.1 then
			return if side > 0 then normal else -normal
		end
	end
	local side = (impact - center):Dot(normal)
	if math.abs(side) > 0.01 then
		return if side > 0 then -normal else normal
	end
	return normal
end

-- Indices des éclats à lancer : tous, ou `count` répartis du plus proche au plus loin de l'impact.
local function pickShards(starts: { CFrame }, impact: Vector3, count: number): { number }
	local order: { number } = {}
	for index in starts do
		table.insert(order, index)
	end
	local total = #order
	if count >= total then
		return order
	end
	if count <= 0 then
		return {}
	end
	local distances: { number } = {}
	for index, cf in starts do
		distances[index] = (cf.Position - impact).Magnitude
	end
	table.sort(order, function(a: number, b: number): boolean
		return distances[a] < distances[b]
	end)
	local picked: { number } = {}
	for i = 1, count do
		local rank = if count == 1 then 1 else 1 + math.floor((i - 1) * (total - 1) / (count - 1) + 0.5)
		table.insert(picked, order[rank])
	end
	return picked
end

------------------------------------------------------------------------------
-- Simulation des éclats et des petits cubes (ancrés, déplacés à chaque image)
------------------------------------------------------------------------------

local function newGroup(
	windowId: string?,
	startAt: number,
	fadeAt: number,
	fadeTime: number,
	params: RaycastParams?,
	isBreak: boolean
): Group
	return {
		WindowId = windowId,
		Pieces = {},
		StartAt = startAt,
		FadeAt = fadeAt,
		FadeTime = fadeTime,
		EndAt = fadeAt + fadeTime,
		Params = params,
		IsBreak = isBreak,
		LandedCount = 0,
		LandTarget = 1,
		Landed = false,
		OnLand = nil,
	}
end

local function destroyGroup(group: Group)
	for _, piece in group.Pieces do
		piece.Part:Destroy()
	end
	table.clear(group.Pieces)
end

-- Une pièce touche le sol : OnLand part quand assez de pièces du groupe l'ont touché.
local function landed(group: Group, piece: Piece, point: Vector3)
	if piece.Landed then
		return
	end
	piece.Landed = true
	group.LandedCount += 1
	if group.Landed or group.LandedCount < group.LandTarget then
		return
	end
	group.Landed = true
	local onLand = group.OnLand
	if onLand then
		task.spawn(onLand, point)
	end
end

-- Orientation couchée : l'axe d'épaisseur de l'éclat sur la normale du sol, par le plus court.
local function flatCFrame(piece: Piece, contact: Vector3, normal: Vector3): CFrame
	local rotation = piece.Rotation
	local axis = rotation:VectorToWorldSpace(piece.Thin or Vector3.zAxis)
	if axis:Dot(normal) < 0 then
		axis = -axis
	end
	local cross = axis:Cross(normal)
	local sine = cross.Magnitude
	local align = if sine > 1e-4
		then CFrame.fromAxisAngle(cross / sine, math.atan2(sine, axis:Dot(normal)))
		else CFrame.identity
	return CFrame.new(contact + normal * (piece.Half + REST_GAP)) * align * rotation
end

local function stepPiece(group: Group, piece: Piece, dt: number, parts: { BasePart }, cframes: { CFrame })
	if piece.Resting then
		return
	end
	local from, to = piece.SettleFrom, piece.SettleTo
	if from and to then
		-- se couche à plat
		piece.SettleTime += dt
		local alpha = math.clamp(piece.SettleTime / math.max(Shards.SettleTime, 1e-3), 0, 1)
		table.insert(parts, piece.Part)
		table.insert(cframes, from:Lerp(to, 1 - (1 - alpha) * (1 - alpha)))
		if alpha >= 1 then
			piece.Resting = true
		end
		return
	end
	piece.Velocity -= Vector3.new(0, Shards.Gravity * dt, 0)
	local start = piece.Position
	local target = start + piece.Velocity * dt
	local spin = piece.Spin
	local angle = spin.Magnitude * dt
	if angle > 1e-6 then
		piece.Rotation = CFrame.fromAxisAngle(spin.Unit, angle) * piece.Rotation
	end
	local groundY = piece.GroundY
	local params = group.Params
	if groundY then
		-- petit cube : sol plat
		if piece.Velocity.Y < 0 and target.Y - piece.Half <= groundY then
			target = Vector3.new(target.X, groundY + piece.Half, target.Z)
			local up = -piece.Velocity.Y * Cubes.Bounce
			if up < CUBE_REST_SPEED then
				piece.Resting = true
			else
				local v = piece.Velocity
				piece.Velocity = Vector3.new(v.X * Shards.Friction, up, v.Z * Shards.Friction)
				piece.Spin *= SPIN_KEEP
			end
			landed(group, piece, target)
		end
	elseif params then
		-- éclat : un rayon le long du déplacement, contre ce qui bloque les joueurs
		local delta = target - start
		local length = delta.Magnitude
		if length > 1e-4 then
			local result = Workspace:Raycast(start, delta * ((length + piece.Reach) / length), params)
			if result then
				local normal = result.Normal
				local into = piece.Velocity:Dot(normal)
				if into < 0 then
					local normalPart = normal * into
					piece.Velocity = (piece.Velocity - normalPart) * Shards.Friction - normalPart * Shards.Bounce
					piece.Spin *= SPIN_KEEP
					target = result.Position + normal * piece.Reach
					landed(group, piece, result.Position)
					if
						piece.Thin
						and normal.Y >= Shards.FlatMinNormalY
						and -into * Shards.Bounce < Shards.SettleSpeed
					then
						piece.SettleFrom = CFrame.new(target) * piece.Rotation
						piece.SettleTo = flatCFrame(piece, result.Position, normal)
						piece.SettleTime = 0
					end
				end
			end
		end
	end
	piece.Position = target
	table.insert(parts, piece.Part)
	table.insert(cframes, CFrame.new(target) * piece.Rotation)
end

local function updateGroup(group: Group, now: number, dt: number, parts: { BasePart }, cframes: { CFrame })
	if now >= group.StartAt then
		for _, piece in group.Pieces do
			stepPiece(group, piece, dt, parts, cframes)
		end
	end
	if now >= group.FadeAt then
		local alpha = if group.FadeTime > 0 then math.clamp((now - group.FadeAt) / group.FadeTime, 0, 1) else 1
		for _, piece in group.Pieces do
			piece.Part.Transparency = piece.Base + (1 - piece.Base) * alpha
		end
	end
end

local function step(dt: number)
	dt = math.min(dt, MAX_STEP)
	local now = os.clock()
	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}
	for index = #groups, 1, -1 do
		local group = groups[index]
		local ok, err = pcall(updateGroup, group, now, dt, parts, cframes)
		if not ok then
			warnOnce(tostring(err))
		end
		if not ok or now >= group.EndAt then
			destroyGroup(group)
			table.remove(groups, index)
		end
	end
	if #parts > 0 then
		local ok, err = pcall(function()
			Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		end)
		if not ok then
			warnOnce(tostring(err))
		end
	end
	if #groups == 0 then
		local connection = loop
		loop = nil
		if connection then
			connection:Disconnect()
		end
	end
end

local function addGroup(group: Group)
	if #group.Pieces == 0 then
		return
	end
	table.insert(groups, group)
	if loop == nil then
		loop = RunService.Heartbeat:Connect(function(dt: number)
			safe(step, dt)
		end)
	end
end

-- Retire tout ce qui reste de la casse d'une vitre (reconstruction, nouvelle casse).
local function stopWindowGroups(windowId: string)
	for index = #groups, 1, -1 do
		local group = groups[index]
		if group.WindowId == windowId then
			destroyGroup(group)
			table.remove(groups, index)
		end
	end
end

local function activeBreaks(): number
	local count = 0
	for _, group in groups do
		if group.IsBreak then
			count += 1
		end
	end
	return count
end

-- Copie locale d'un éclat, ancrée et sans collision, à `cf`.
local function cloneShard(source: BasePart, cf: CFrame): BasePart?
	local ok, copy = pcall(function()
		return source:Clone()
	end)
	if not ok or copy == nil then
		return nil
	end
	local part = copy :: BasePart
	for _, descendant in part:GetDescendants() do
		if
			descendant:IsA("JointInstance")
			or descendant:IsA("WeldConstraint")
			or descendant:IsA("Constraint")
			or descendant:IsA("NoCollisionConstraint")
			or descendant:IsA("LuaSourceContainer")
		then
			descendant:Destroy()
		end
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CFrame = cf
	if part.Transparency >= 0.99 then
		part.Transparency = Shards.FallbackTransparency
	end
	part.Parent = getFxFolder()
	return part
end

local function shardPiece(part: BasePart, impact: Vector3, glass: Glass, inward: Vector3): Piece
	local size = part.Size
	local thin, half = Vector3.zAxis, size.Z / 2
	if size.X <= size.Y and size.X <= size.Z then
		thin, half = Vector3.xAxis, size.X / 2
	elseif size.Y <= size.Z then
		thin, half = Vector3.yAxis, size.Y / 2
	end
	local position = part.Position
	local normal = glass.CFrame.ZVector
	local offset = position - impact
	local inPlane = offset - normal * offset:Dot(normal)
	local distance = inPlane.Magnitude
	local radial: Vector3
	if distance > 1e-3 then
		radial = inPlane / distance
	else
		local angle = rng:NextNumber(0, math.pi * 2)
		radial = glass.CFrame.RightVector * math.cos(angle) + glass.CFrame.UpVector * math.sin(angle)
	end
	-- plus vite près de l'impact
	local falloff = 1 / (1 + distance / math.max(Shards.FalloffDistance, 1e-3))
	local velocity = radial * (Shards.Speed * falloff * jitter(Shards.Jitter))
		+ inward * (Shards.InwardPush * (0.6 + 0.4 * falloff) * jitter(Shards.Jitter))
		+ Vector3.new(0, Shards.UpBoost * rng:NextNumber(0.5, 1), 0)
	local spin = rng:NextUnitVector()
		* (math.rad(rng:NextNumber(Shards.SpinMin, Shards.SpinMax)) * (0.5 + 0.5 * falloff))
	local extent = math.max(size.X, size.Y, size.Z) / 2
	return {
		Part = part,
		Position = position,
		Rotation = part.CFrame.Rotation,
		Velocity = velocity,
		Spin = spin,
		Thin = thin,
		Half = half,
		Reach = half + extent * 0.25,
		GroundY = nil,
		Base = part.Transparency,
		SettleFrom = nil,
		SettleTo = nil,
		SettleTime = 0,
		Resting = false,
		Landed = false,
	}
end

-- Petit cube de verre (mini-éclat), créé par le code.
local function cubePiece(origin: Vector3, velocity: Vector3, groundY: number, color: Color3): Piece
	local side = rng:NextNumber(Cubes.SizeMin, Cubes.SizeMax)
	local part = Instance.new("Part")
	part.Name = "GlassCube"
	part.Size = Vector3.new(side, side, side)
	part.Material = Enum.Material.Glass
	part.Color = color
	part.Transparency = Cubes.Transparency
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	local rotation = CFrame.fromAxisAngle(rng:NextUnitVector(), rng:NextNumber(0, math.pi * 2))
	part.CFrame = CFrame.new(origin) * rotation
	part.Parent = getFxFolder()
	return {
		Part = part,
		Position = origin,
		Rotation = rotation,
		Velocity = velocity,
		Spin = rng:NextUnitVector() * math.rad(rng:NextNumber(Shards.SpinMin, Shards.SpinMax)),
		Thin = nil,
		Half = side / 2,
		Reach = side / 2,
		GroundY = groundY,
		Base = Cubes.Transparency,
		SettleFrom = nil,
		SettleTo = nil,
		SettleTime = 0,
		Resting = false,
		Landed = false,
	}
end

-- Rayons contre la map : ce qui bloque les joueurs (CanCollide), sans les personnages, ni la vitre
-- cachée, ni nos propres effets.
local function rayParams(exclude: { Instance }): RaycastParams
	local list = table.clone(exclude)
	table.insert(list, getFxFolder())
	for _, other in Players:GetPlayers() do
		local character = other.Character
		if character then
			table.insert(list, character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = list
	params.RespectCanCollide = true
	params.IgnoreWater = true
	return params
end

local function groundBelow(point: Vector3, params: RaycastParams): number
	local result = Workspace:Raycast(point + Vector3.new(0, 0.5, 0), Vector3.new(0, -GROUND_PROBE, 0), params)
	return if result then result.Position.Y else point.Y - GROUND_PROBE
end

------------------------------------------------------------------------------
-- Effets : sons, particules, tremblement, flash, arrêt sur image, texte
------------------------------------------------------------------------------

-- Joue le son `name` (Assets/Sounds) au point `at`, hauteur × `pitch`. Absent : rien.
local function playSound(name: string, at: Vector3, pitch: number)
	local template = MarkerSounds.find(name)
	if template == nil then
		return
	end
	local holder = Instance.new("Attachment")
	holder.Name = "ShatterSound"
	holder.Position = at
	local sound = template:Clone()
	sound.PlaybackSpeed = template.PlaybackSpeed * pitch
	sound.Parent = holder
	holder.Parent = Workspace.Terrain
	sound.Ended:Once(function()
		holder:Destroy()
	end)
	Debris:AddItem(holder, SOUND_MAX_LIFETIME)
	sound:Play()
end

local function layerPitch(): number
	return jitter(Break.PitchVariation)
end

-- Repère dont l'axe Y suit `up` (direction d'envol des particules).
local function upFrame(position: Vector3, up: Vector3): CFrame
	local unit = if up.Magnitude > 1e-4 then up.Unit else Vector3.yAxis
	local other = if math.abs(unit.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis
	return CFrame.fromMatrix(position, other:Cross(unit).Unit, unit)
end

local function emitParticles(kind: ParticleKind, position: Vector3, direction: Vector3, count: number)
	if count <= 0 then
		return
	end
	local texture = if kind == "Sparkle"
		then fxTexture(Assets.SparkleDecal)
		else (fxTexture(Assets.DustDecal) or Config.DustTexture)
	if texture == nil or texture == "" then
		return
	end
	local holder = Instance.new("Attachment")
	holder.Name = "ShatterParticles"
	holder.CFrame = upFrame(position, direction)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.Rate = 0
	emitter.Texture = texture
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-180, 180)
	local lifetime: number
	if kind == "Sparkle" then
		local p = Particles.Sparkle
		emitter.Size = NumberSequence.new(p.Size, 0)
		emitter.Lifetime = NumberRange.new(p.LifetimeMin, p.LifetimeMax)
		emitter.Speed = NumberRange.new(p.SpeedMin, p.SpeedMax)
		emitter.SpreadAngle = Vector2.new(p.Spread, p.Spread)
		emitter.Acceleration = Vector3.new(0, -Shards.Gravity * p.GravityScale, 0)
		emitter.Color = ColorSequence.new(p.Color)
		emitter.LightEmission = p.LightEmission
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.6, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		lifetime = p.LifetimeMax
	else
		local p = Particles.Dust
		emitter.Size = NumberSequence.new(p.SizeMin, p.SizeMax)
		emitter.Lifetime = NumberRange.new(p.LifetimeMin, p.LifetimeMax)
		emitter.Speed = NumberRange.new(p.SpeedMin, p.SpeedMax)
		emitter.SpreadAngle = Vector2.new(p.Spread, p.Spread)
		emitter.Drag = p.Drag
		emitter.Color = ColorSequence.new(p.Color)
		emitter.Transparency = NumberSequence.new(p.Transparency, 1)
		lifetime = p.LifetimeMax
	end
	emitter.Parent = holder
	holder.Parent = Workspace.Terrain
	emitter:Emit(count)
	Debris:AddItem(holder, lifetime + 0.5)
end

local function addShake(duration: number, amplitude: number, angle: number, scale: number)
	if scale <= 0.02 or duration <= 0 or reducedMotion() then
		return
	end
	table.insert(shakes, {
		Start = os.clock(),
		Duration = duration,
		Amplitude = amplitude * scale,
		Angle = math.rad(angle) * scale,
		Seed = rng:NextNumber(1, 1000),
	})
end

-- Après la caméra de Roblox, à chaque image : décalage qui s'éteint sur la durée du tremblement.
local function applyShake()
	if #shakes == 0 then
		return
	end
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local now = os.clock()
	local wave = now * Config.ShakeFrequency
	local offset = Vector3.zero
	local rx, ry, rz = 0, 0, 0
	for index = #shakes, 1, -1 do
		local shake = shakes[index]
		local t = (now - shake.Start) / shake.Duration
		if t >= 1 then
			table.remove(shakes, index)
			continue
		end
		local decay = (1 - t) * (1 - t)
		local seed = shake.Seed
		local move = shake.Amplitude * decay * 2 -- math.noise reste à peu près dans ± 0,5
		local turn = shake.Angle * decay * 2
		offset += Vector3.new(math.noise(wave, seed, 0.1), math.noise(seed, wave, 0.2), math.noise(0.3, seed, wave))
			* move
		rx += math.noise(wave, seed, 1.1) * turn
		ry += math.noise(wave, seed, 2.3) * turn
		rz += math.noise(wave, seed, 3.7) * turn
	end
	camera.CFrame = camera.CFrame * CFrame.new(offset) * CFrame.Angles(rx, ry, rz)
end

-- Flash blanc : ColorCorrection locale sur la caméra (la scène s'éclaire, pas l'interface).
local function playFlash(intensity: number)
	if intensity <= 0.02 then
		return
	end
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local effect = flashEffect
	if effect == nil or effect.Parent ~= camera then
		if effect then
			effect:Destroy()
		end
		local created = Instance.new("ColorCorrectionEffect")
		created.Name = "ShatterFlash"
		created.Enabled = false
		created.Parent = camera
		flashEffect = created
		effect = created
	end
	local current = effect :: ColorCorrectionEffect
	flashToken += 1
	local token = flashToken
	current.Brightness = Break.FlashBrightness * intensity
	current.Saturation = Break.FlashSaturation * intensity
	current.Enabled = true
	local tween = TweenService:Create(
		current,
		TweenInfo.new(Break.FlashDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Brightness = 0, Saturation = 0 }
	)
	tween.Completed:Once(function()
		if flashToken == token then
			current.Enabled = false
		end
	end)
	tween:Play()
end

-- Éclair au point d'impact, vu de tous les joueurs proches.
local function worldFlash(point: Vector3)
	local holder = Instance.new("Attachment")
	holder.Name = "ShatterLight"
	holder.Position = point
	local light = Instance.new("PointLight")
	light.Brightness = Break.LightBrightness
	light.Range = Break.LightRange
	light.Shadows = false
	light.Parent = holder
	holder.Parent = Workspace.Terrain
	TweenService:Create(light, TweenInfo.new(Break.FlashDuration), { Brightness = 0 }):Play()
	Debris:AddItem(holder, Break.FlashDuration + 0.2)
end

-- Arrêt sur image du personnage local : ses animations en cours s'arrêtent `duration` secondes.
local function hitstop(duration: number)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local animator = if humanoid then humanoid:FindFirstChildOfClass("Animator") else nil
	if animator == nil then
		return
	end
	local frozen: { [AnimationTrack]: number } = {}
	for _, track in animator:GetPlayingAnimationTracks() do
		frozen[track] = track.Speed
		track:AdjustSpeed(0)
	end
	task.delay(duration, function()
		for track, speed in frozen do
			if track.IsPlaying then
				track:AdjustSpeed(speed)
			end
		end
	end)
end

-- « SMASHED! » (Shatter.Break.Text) : l'écran de Clément s'il existe (Assets.BrokenScreen avec
-- Assets.BrokenLabel), sinon un texte V0 créé ici, gris, facile à remplacer.
local function brokenLabel(): (GuiObject?, ScreenGui?)
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return nil, nil
	end
	local screen = playerGui:FindFirstChild(Assets.BrokenScreen)
	if screen and screen:IsA("ScreenGui") then
		local label = screen:FindFirstChild(Assets.BrokenLabel, true)
		if label and label:IsA("GuiObject") then
			return label :: GuiObject, screen :: ScreenGui
		end
	end
	local existing = v0Text
	if existing and existing.Parent and existing.Parent.Parent then
		return existing, nil
	end
	local holder = Instance.new("ScreenGui")
	holder.Name = "ShatterText_V0"
	holder.ResetOnSpawn = false
	holder.IgnoreGuiInset = true
	holder.DisplayOrder = 10
	local text = Instance.new("TextLabel")
	text.Name = Assets.BrokenLabel
	text.AnchorPoint = Vector2.new(0.5, 0.5)
	text.Position = UDim2.fromScale(0.5, 0.42)
	text.Size = UDim2.fromScale(0.7, 0.16)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBlack
	text.Text = Break.Text
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	text.Rotation = -4
	text.Visible = false
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Color3.fromRGB(27, 27, 36)
	stroke.Parent = text
	text.Parent = holder
	holder.Parent = playerGui
	v0Text = text
	return text, nil
end

local function showBrokenText()
	local label, screen = brokenLabel()
	if label == nil then
		return
	end
	local shown = label :: GuiObject
	textToken += 1
	local token = textToken
	local found = shown:FindFirstChildOfClass("UIScale")
	local scale: UIScale
	if found then
		scale = found
	else
		scale = Instance.new("UIScale")
		scale.Parent = shown
	end
	if screen then
		screen.Enabled = true
	end
	shown.Visible = true
	scale.Scale = 0.4
	TweenService:Create(
		scale,
		TweenInfo.new(Break.TextPopTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()
	task.delay(Break.TextPopTime + Break.TextHold, function()
		if textToken ~= token then
			return
		end
		local hide = TweenService:Create(
			scale,
			TweenInfo.new(Break.TextHideTime, Enum.EasingStyle.Back, Enum.EasingDirection.In),
			{ Scale = 0 }
		)
		hide.Completed:Once(function()
			if textToken ~= token then
				return
			end
			shown.Visible = false
			scale.Scale = 1
			if screen then
				screen.Enabled = false
			end
		end)
		hide:Play()
	end)
end

------------------------------------------------------------------------------
-- Fissures : étoiles au point de frappe
------------------------------------------------------------------------------

-- Niveau de fissure pour une fraction de PV : 0 au-dessus du premier seuil, puis 1, 2, 3. Monte
-- dès qu'un seuil est passé ; ne redescend que Cracks.HealHysteresis au-dessus du seuil.
local function crackLevel(fraction: number, current: number): number
	local thresholds = Cracks.Thresholds
	local level = 0
	for index, threshold in thresholds do
		if fraction <= threshold then
			level = index
		end
	end
	if level >= current then
		return level
	end
	local healed = 0
	for index, threshold in thresholds do
		if fraction <= threshold + Cracks.HealHysteresis then
			healed = index
		end
	end
	return math.min(current, healed)
end

-- Image d'un niveau ; si elle manque, celle du niveau d'en dessous.
local function crackTexture(level: number): string?
	for index = math.clamp(level, 1, #Assets.CrackDecals), 1, -1 do
		local texture = fxTexture(Assets.CrackDecals[index])
		if texture then
			return texture
		end
	end
	return nil
end

local function pop(scale: UIScale, from: number)
	scale.Scale = from
	TweenService:Create(
		scale,
		TweenInfo.new(Cracks.PopTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()
end

-- Image, taille et transparence d'une étoile pour le niveau de sa vitre.
local function styleStar(state: CrackState, star: Star, animate: boolean)
	local level = state.Level
	local glass = state.Glass
	local sizes = Cracks.Sizes
	local diameter = sizes[math.clamp(level + 1, 1, #sizes)] * glass.Height / Cracks.ReferenceHeight
	local size = UDim2.fromScale(diameter / glass.Width, diameter / glass.Height)
	local texture = crackTexture(level) or ""
	local transparency = if level == 0 then Cracks.Level0Transparency else 0
	for _, label in star.Labels do
		label.Image = texture
		label.ImageTransparency = transparency
		if animate then
			TweenService:Create(
				label,
				TweenInfo.new(Cracks.PopTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = size }
			):Play()
		else
			label.Size = size
		end
	end
end

local function clearCracks(windowId: string)
	local state = cracks[windowId]
	if state == nil then
		return
	end
	cracks[windowId] = nil
	state.Canvas:Destroy()
end

-- Vitre revenue à ses PV max : les étoiles s'effacent doucement.
local function fadeCracks(windowId: string)
	local state = cracks[windowId]
	if state == nil then
		return
	end
	cracks[windowId] = nil
	local info = TweenInfo.new(Cracks.ClearFade)
	for _, star in state.Stars do
		for _, label in star.Labels do
			TweenService:Create(label, info, { ImageTransparency = 1 }):Play()
		end
	end
	Debris:AddItem(state.Canvas, Cracks.ClearFade + 0.1)
end

-- Les étoiles d'une vitre : une pièce invisible locale à la place du verre, épaisse de
-- 2 × SurfaceOffset de plus, avec un SurfaceGui par face (découpé au bord du verre).
local function crackState(windowId: string): CrackState?
	local existing = cracks[windowId]
	if existing and existing.Window.Parent ~= nil and existing.Canvas.Parent ~= nil then
		return existing
	end
	if existing then
		clearCracks(windowId)
	end
	local api = windowApi
	if api == nil then
		return nil
	end
	local window = api.GetWindow(windowId)
	if window == nil then
		return nil
	end
	local glass = windowGlass(window)
	if glass == nil or glass.Width <= 0 or glass.Height <= 0 then
		return nil
	end
	local canvas = Instance.new("Part")
	canvas.Name = `Cracks_{windowId}`
	canvas.Anchored = true
	canvas.CanCollide = false
	canvas.CanQuery = false
	canvas.CanTouch = false
	canvas.CastShadow = false
	canvas.Transparency = 1
	canvas.Size = Vector3.new(glass.Width, glass.Height, glass.Thickness + 2 * Cracks.SurfaceOffset)
	canvas.CFrame = glass.CFrame
	local clips: { Frame } = {}
	for _, face in FACES do
		local surface = Instance.new("SurfaceGui")
		surface.Name = face.Name
		surface.Face = face
		surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surface.PixelsPerStud = Cracks.PixelsPerStud
		surface.LightInfluence = 1
		surface.MaxDistance = Cracks.MaxDistance
		surface.Parent = canvas
		local clip = Instance.new("Frame")
		clip.Name = "Clip"
		clip.BackgroundTransparency = 1
		clip.Size = UDim2.fromScale(1, 1)
		clip.ClipsDescendants = true
		clip.Parent = surface
		table.insert(clips, clip)
	end
	canvas.Parent = getFxFolder()
	local state: CrackState = {
		Window = window,
		Glass = glass,
		Canvas = canvas,
		Clips = clips,
		Stars = {},
		Level = crackLevel(api.GetFraction(windowId), 0),
	}
	cracks[windowId] = state
	return state
end

-- Étoile au point de frappe `point` (calculé par le serveur) : réutilise une étoile proche, sinon
-- en pose une nouvelle (et retire celle touchée il y a le plus longtemps s'il y en a trop).
local function placeStar(windowId: string, point: Vector3)
	if brokenWindows[windowId] or crackTexture(0) == nil then
		return -- vitre cassée, ou images pas encore livrées
	end
	local state = crackState(windowId)
	if state == nil then
		return
	end
	local glass = state.Glass
	local p = glass.CFrame:PointToObjectSpace(point)
	local x = math.clamp(p.X, -glass.Width / 2, glass.Width / 2)
	local y = math.clamp(p.Y, -glass.Height / 2, glass.Height / 2)
	local now = os.clock()
	local nearest: Star? = nil
	local best = Cracks.ReuseDistance
	for _, star in state.Stars do
		local distance = math.sqrt((star.X - x) ^ 2 + (star.Y - y) ^ 2)
		if distance <= best then
			nearest, best = star, distance
		end
	end
	if nearest then
		nearest.LastHit = now
		for _, scale in nearest.Scales do
			pop(scale, 1.12)
		end
		return
	end
	if #state.Stars >= Cracks.MaxStars then
		local oldest = 1
		for index, star in state.Stars do
			if star.LastHit < state.Stars[oldest].LastHit then
				oldest = index
			end
		end
		local removed = table.remove(state.Stars, oldest)
		if removed then
			for _, label in removed.Labels do
				label:Destroy()
			end
		end
	end
	local rotation = rng:NextNumber(0, 360)
	local star: Star = { X = x, Y = y, LastHit = now, Labels = {}, Scales = {} }
	for index, clip in state.Clips do
		local label = Instance.new("ImageLabel")
		label.Name = "Star"
		label.BackgroundTransparency = 1
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		-- Vue de la rue (face avant), la largeur de la vitre (+X) va vers la gauche du canevas ;
		-- vue de l'intérieur (face arrière), vers la droite. Le haut reste en haut.
		local u = if index == 1 then 0.5 - x / glass.Width else 0.5 + x / glass.Width
		label.Position = UDim2.fromScale(u, 0.5 - y / glass.Height)
		label.Rotation = if index == 1 then rotation else -rotation
		label.ScaleType = Enum.ScaleType.Fit
		local scale = Instance.new("UIScale")
		scale.Parent = label
		label.Parent = clip
		table.insert(star.Labels, label)
		table.insert(star.Scales, scale)
	end
	styleStar(state, star, false)
	for _, scale in star.Scales do
		pop(scale, 0.6)
	end
	table.insert(state.Stars, star)
end

local function onHP(windowId: string, hp: number, maxHp: number)
	local state = cracks[windowId]
	if state == nil or brokenWindows[windowId] then
		return
	end
	if maxHp <= 0 then
		clearCracks(windowId)
		return
	end
	local fraction = hp / maxHp
	if fraction >= 1 - 1e-6 then
		fadeCracks(windowId)
		return
	end
	local level = crackLevel(fraction, state.Level)
	if level == state.Level then
		return
	end
	local grow = level > state.Level
	state.Level = level
	for _, star in state.Stars do
		styleStar(state, star, true)
		if grow then
			for _, scale in star.Scales do
				pop(scale, 1.12)
			end
		end
	end
end

------------------------------------------------------------------------------
-- Coups : mini-éclats, paillettes, son
------------------------------------------------------------------------------

local function hitPitch(windowId: string): number
	local api = windowApi
	local fraction = if api then api.GetFraction(windowId) else 1
	return (Hit.PitchMin + (Hit.PitchMax - Hit.PitchMin) * (1 - fraction)) * jitter(Hit.PitchJitter)
end

local function playHitFx(windowId: string, point: Vector3)
	local api = windowApi
	local window = if api then api.GetWindow(windowId) else nil
	local glass = if window then windowGlass(window) else nil
	if window == nil or glass == nil then
		playSound(Sounds.Hit, point, hitPitch(windowId))
		return
	end
	local normal = glass.CFrame.ZVector
	local outward = if (point - glass.CFrame.Position):Dot(normal) >= 0 then normal else -normal
	local low = ShatterController.IsLowEnd()
	local origin = point + outward * 0.15
	local params = rayParams({ window })
	local groundY = groundBelow(origin + outward * 1.5, params)
	local now = os.clock()
	local group = newGroup(nil, now, now + Hit.CubeLifetime - Cubes.FadeTime, Cubes.FadeTime, nil, false)
	local color = glassColor(window)
	for _ = 1, if low then Hit.CubesLowEnd else Hit.Cubes do
		local direction = (outward + rng:NextUnitVector() * 0.8 + Vector3.new(0, 0.35, 0)).Unit
		table.insert(
			group.Pieces,
			cubePiece(origin, direction * (Hit.CubeSpeed * rng:NextNumber(0.6, 1.2)), groundY, color)
		)
	end
	addGroup(group)
	emitParticles("Sparkle", origin, outward, if low then Hit.SparklesLowEnd else Hit.Sparkles)
	playSound(Sounds.Hit, point, hitPitch(windowId))
end

-- Retour local d'un coup, joué une seule fois, puis ce qui l'attendait (étoile, casse).
local function playPending(windowId: string, pending: Pending)
	if pending.Played then
		return
	end
	pending.Played = true
	local connection = pending.Connection
	pending.Connection = nil
	if connection then
		connection:Disconnect()
	end
	if pendings[windowId] == pending then
		pendings[windowId] = nil
	end
	safe(playHitFx, windowId, pending.Point)
	addShake(Hit.ShakeDuration, Hit.ShakeAmplitude, Hit.ShakeAngle, 1)
	for _, callback in pending.After do
		safe(callback)
	end
end

function ShatterController.LocalHit(windowId: string, point: Vector3, track: AnimationTrack?)
	lastLocalHit[windowId] = os.clock()
	local previous = pendings[windowId]
	if previous then
		playPending(windowId, previous) -- le coup suivant interrompt l'animation du précédent
	end
	local pending: Pending = { Point = point, Played = false, After = {}, Connection = nil }
	pendings[windowId] = pending
	if track == nil then
		playPending(windowId, pending)
		return
	end
	local animation = track :: AnimationTrack
	local ok, signal = pcall(function()
		return animation:GetMarkerReachedSignal(IMPACT_MARKER)
	end)
	if ok and signal then
		pending.Connection = signal:Connect(function()
			playPending(windowId, pending)
		end)
	end
	task.delay(Hit.ImpactMaxWait, playPending, windowId, pending)
end

------------------------------------------------------------------------------
-- Casse
------------------------------------------------------------------------------

local function breakBurst(
	windowId: string,
	impact: Vector3,
	inward: Vector3,
	params: RaycastParams,
	full: boolean,
	color: Color3
)
	local groundY = groundBelow(impact + inward * 2, params)
	local now = os.clock()
	local group = newGroup(windowId, now, now + Cubes.BreakLifetime - Cubes.FadeTime, Cubes.FadeTime, nil, false)
	for _ = 1, if full then Break.Cubes else Break.CubesLowEnd do
		local direction = (inward * rng:NextNumber(0.6, 1.2) + rng:NextUnitVector() * 0.7 + Vector3.new(0, 0.4, 0)).Unit
		table.insert(
			group.Pieces,
			cubePiece(impact, direction * (Shards.Speed * rng:NextNumber(0.5, 1.1)), groundY, color)
		)
	end
	addGroup(group)
	local sparkles = if full then Break.Sparkles else Break.SparklesLowEnd
	emitParticles("Sparkle", impact, inward, sparkles)
	emitParticles("Sparkle", impact, -inward, math.ceil(sparkles / 4))
	emitParticles("Dust", impact, inward, if full then Break.Dust else Break.DustLowEnd)
end

-- Éclats posés à la place du verre, immobiles, pour la casse en cours de `windowId`. nil si la
-- vitre est trop loin ou pas chargée (streaming).
type Prepared = { Group: Group, Inward: Vector3, Params: RaycastParams, Full: boolean, Color: Color3 }

local function prepareShards(windowId: string, impact: Vector3, distance: number, participant: boolean): Prepared?
	local api = windowApi
	local window: Instance?, model: Model? = nil, nil
	if api then
		window, model = api.GetWindow(windowId)
	end
	if window == nil or model == nil or (distance > Break.SimulationRadius and not participant) then
		return nil
	end
	local w = window :: Instance
	local m = model :: Model
	local found = m:FindFirstChild(FRACTURED_NAME, true)
	local fractured: Model? = if found and found:IsA("Model") then found :: Model else nil
	local glass = targetGlass(w, fractured)
	if glass == nil then
		return nil
	end
	local sources, place = chooseShards(glass, fractured, impact)
	local full = not ShatterController.IsLowEnd() and activeBreaks() < LowEnd.MaxFullAtOnce
	local starts: { CFrame } = {}
	for index, source in sources do
		starts[index] = if place then place * source.CFrame else source.CFrame
	end
	local selected = pickShards(starts, impact, if full then #starts else LowEnd.Shards)
	local exclude: { Instance } = { w }
	if fractured then
		table.insert(exclude, fractured)
	end
	local params = rayParams(exclude)
	local inward = inwardDirection(glass, m, impact)
	-- Immobiles jusqu'à l'explosion ; retirés quoi qu'il arrive après PREPARED_MAX_LIFETIME.
	local group = newGroup(windowId, math.huge, math.huge, Shards.FadeDuration, params, true)
	group.EndAt = os.clock() + PREPARED_MAX_LIFETIME
	for _, index in selected do
		local part = cloneShard(sources[index], starts[index])
		if part then
			table.insert(group.Pieces, shardPiece(part, impact, glass, inward))
		end
	end
	group.LandTarget = math.max(1, math.ceil(#group.Pieces * Break.DebrisLandedShare))
	addGroup(group)
	return {
		Group = group,
		Inward = inward,
		Params = params,
		Full = full,
		Color = glassColor(if #sources > 0 then sources[1] else w),
	}
end

-- Casse d'une vitre (5.4), en deux temps : tout de suite, la vitre fracturée remplace le verre
-- (caché par le serveur) ; puis la fonction renvoyée fait exploser le tout. Elle est appelée tout de
-- suite, ou, pour celui qui frappe, à l'impact de son coup : pas de trou entre les deux.
local function prepareBreak(windowId: string, impact: Vector3): () -> ()
	stopWindowGroups(windowId)
	local camera = Workspace.CurrentCamera
	local distance = if camera then (camera.CFrame.Position - impact).Magnitude else 0
	local prepared = prepareShards(windowId, impact, distance, isParticipant(windowId))
	return function()
		if not brokenWindows[windowId] then
			return -- reconstruite entre-temps
		end
		clearCracks(windowId)
		local participant = isParticipant(windowId)
		local nearby = if participant then 1 else math.clamp(1 - distance / Break.EffectRadius, 0, 1)
		-- Moment de la casse : arrêt sur image, flash, tremblement, texte, deux premières couches du son.
		safe(playFlash, nearby)
		addShake(Break.ShakeDuration, Break.ShakeAmplitude, Break.ShakeAngle, nearby)
		if participant then
			safe(hitstop, Break.FreezeFrame)
			safe(showBrokenText)
		end
		safe(playSound, Sounds.BreakThud, impact, layerPitch())
		safe(playSound, Sounds.BreakShatter, impact, layerPitch())
		local debrisAt = Break.FreezeFrame + Break.DebrisSoundFallback
		if prepared == nil then
			task.delay(debrisAt, safe, playSound, Sounds.BreakDebris, impact, layerPitch())
			return -- pas d'éclats : seulement les sons
		end
		safe(worldFlash, impact)
		-- Les éclats partent après l'arrêt sur image ; troisième couche du son quand un quart d'entre
		-- eux a touché le sol, au plus tard après debrisAt.
		local group = prepared.Group
		group.StartAt = os.clock() + Break.FreezeFrame
		group.FadeAt = group.StartAt + Shards.FadeDelay
		group.EndAt = group.FadeAt + Shards.FadeDuration
		group.OnLand = function(point: Vector3)
			safe(playSound, Sounds.BreakDebris, point, layerPitch())
		end
		task.delay(debrisAt, function()
			if not group.Landed then
				group.Landed = true
				safe(playSound, Sounds.BreakDebris, impact, layerPitch())
			end
		end)
		task.delay(
			Break.FreezeFrame,
			safe,
			breakBurst,
			windowId,
			impact,
			prepared.Inward,
			prepared.Params,
			prepared.Full,
			prepared.Color
		)
	end
end

------------------------------------------------------------------------------
-- Événements des vitrines (WindowController)
------------------------------------------------------------------------------

local function onHit(windowId: string, point: Vector3, hitter: Player?)
	if brokenWindows[windowId] then
		return
	end
	if hitter == player then
		-- son propre coup : l'étoile apparaît avec le retour local, pas avant
		local pending = pendings[windowId]
		if pending and not pending.Played then
			table.insert(pending.After, function()
				placeStar(windowId, point)
			end)
		else
			placeStar(windowId, point)
		end
		return
	end
	placeStar(windowId, point)
	local camera = Workspace.CurrentCamera
	if camera == nil or (camera.CFrame.Position - point).Magnitude <= Hit.FxRadius then
		playHitFx(windowId, point)
	end
end

local function onBroken(windowId: string, impact: Vector3)
	brokenWindows[windowId] = true
	local explode = prepareBreak(windowId, impact)
	local pending = pendings[windowId]
	if pending and not pending.Played then
		table.insert(pending.After, explode) -- celui qui frappe : l'explosion part à l'impact de son coup
	else
		explode()
	end
end

local function onRebuilt(windowId: string)
	brokenWindows[windowId] = nil
	clearCracks(windowId)
	stopWindowGroups(windowId)
end

-- En Studio : ce qui manque parmi les assets de la casse (effets sautés en attendant).
local function reportAssets()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	local missing: { string } = {}
	for _, name in Assets.CrackDecals do
		if fxTexture(name) == nil then
			table.insert(missing, name)
		end
	end
	if fxTexture(Assets.SparkleDecal) == nil then
		table.insert(missing, Assets.SparkleDecal)
	end
	local present: { [string]: boolean } = {}
	for _, variant in variants() do
		present[variant.Name] = true
	end
	for _, name in Assets.FracturedVariants do
		if not present[name] then
			table.insert(missing, name)
		end
	end
	for _, name in { Sounds.Hit, Sounds.BreakThud, Sounds.BreakShatter, Sounds.BreakDebris } do
		if MarkerSounds.find(name) == nil then
			table.insert(missing, name)
		end
	end
	if #missing == 0 then
		print("[Shatter] assets de la casse : tous présents")
	else
		print(`[Shatter] assets de la casse absents, effet sauté : {table.concat(missing, ", ")}`)
	end
end

function ShatterController.Start()
	local module = script.Parent:FindFirstChild("WindowController")
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok and type(result) == "table" and type((result :: any).OnHit) == "function" then
			windowApi = result :: any
		end
	end
	local api = windowApi
	if api == nil then
		warn("[Shatter] WindowController introuvable : ni fissures ni casse")
		return
	end
	api.OnHit(function(windowId: string, point: Vector3, hitter: Player?)
		safe(onHit, windowId, point, hitter)
	end)
	api.OnBroken(function(windowId: string, impact: Vector3)
		safe(onBroken, windowId, impact)
	end)
	api.OnHP(function(windowId: string, hp: number, maxHp: number)
		safe(onHP, windowId, hp, maxHp)
	end)
	api.OnRebuilt(function(windowId: string)
		safe(onRebuilt, windowId)
	end)
	api.OnRemoved(function(windowId: string)
		safe(clearCracks, windowId)
	end)
	RunService.Heartbeat:Connect(function(dt: number)
		frameTime += (dt - frameTime) * 0.05
	end)
	RunService:BindToRenderStep(SHAKE_STEP, Enum.RenderPriority.Camera.Value + 1, function()
		safe(applyShake)
	end)
	if IS_STUDIO then
		task.spawn(safe, reportAssets)
	end
end

return ShatterController
