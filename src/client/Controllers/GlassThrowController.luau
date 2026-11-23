--!strict
-- GlassThrowController (a315, L-291 ; client) : ce que chacun voit et entend quand un intrus est projeté à travers
-- une vitre de boutique (GlassThrowService décide tout). Remote GlassThrow(kind, pane, point, direction, victim?,
-- hitter?, fresh?) :
--   "Throw"  sons Throw_Hit et Throw_Whoosh, traînée FX_ThrownTrail copiée sur UpperTorso de la victime (comme
--            FX_BoxTrail : Carrier porte TrailTop, TrailBottom et Trail), secousse de caméra pour la victime et pour
--            celui qui frappe ;
--   "Hole"   trou dans la vitre là où passe le corps (GlassThrow/Hole : copie givrée découpée par FragmentAsync, la
--            vraie vitre cachée en local), FX_ShopGlass_Burst au point (Root posé au centre du trou, LookVector = sens
--            du vol ; chaque émetteur Emit(EmitCount), PointLight Flash éteinte en FadeTime, retiré après Duration),
--            sons Throw_GlassBurst et Throw_GlassDebris ; trou déjà ouvert (fresh = false) : Throw_GlassDebris seul ;
--   "Land"   la victime (joueur local) joue Knockback (son Knockback_Land au marqueur Land, MarkerSounds) ; traînée
--            coupée ;
--   "Repair" trou retiré, vitre d'origine remontrée, FX_ShopGlass_Reform posé à la taille et à la place du trou
--            (Root : boîte du trou ; Emit(EmitCount), Glow éteinte en FadeTime), son Throw_GlassReform.
-- Réglages : Shared/Config/GlassThrow. Sous Features.ShopGlassThrow / ShopGlassThrowDev côté serveur : éteint, le
-- remote ne part pas. Un asset de Clément absent saute son effet (une ligne en Studio). VISUAL EFFECTS sur OFF
-- (Settings.VfxReduced) : ni particules, ni traînée, ni secousse ; le trou reste. « Réduire les mouvements » : pas
-- de secousse.

local GeometryService = game:GetService("GeometryService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local GlassThrow = require(Config:WaitForChild("GlassThrow"))
local Settings = require(Config:WaitForChild("Settings"))
local Hole = require(script.Parent:WaitForChild("GlassThrow"):WaitForChild("Hole"))

local FX_FOLDER = "_GlassThrowFX"
local ASSETS = "Assets"
local FX = "FX"
local CARRIER = "Carrier"
local TRAIL = "Trail"
local TRAIL_TOP = "TrailTop"
local TRAIL_BOTTOM = "TrailBottom"
local TORSO = "UpperTorso"
local SHAKE_STEP = "GlassThrowCameraShake"
local SOUND_MAX_LIFETIME = 10
local DEFAULT_DURATION = 2.5

local player = Players.LocalPlayer
local IS_STUDIO = RunService:IsStudio()

type Shake = { Start: number, Duration: number, Amplitude: number, Angle: number, Seed: number }
type AnimationApi = { PlayPlayer: (name: string, fadeTime: number?) -> AnimationTrack? }

local GlassThrowController = {}

local Net: any = nil
local animation: AnimationApi? = nil
local holes: { [BasePart]: Hole.State } = {}
local trails: { [Player]: { Instance } } = {}
local shakes: { Shake } = {}
local noticed: { [string]: boolean } = {}
local rng = Random.new()
local fxFolder: Folder? = nil

local function once(key: string, message: string)
	if IS_STUDIO and not noticed[key] then
		noticed[key] = true
		print(`[GlassThrowController] {message}`)
	end
end

local function random(): number
	return rng:NextNumber()
end

local function folder(): Folder
	local current = fxFolder
	if current and current.Parent ~= nil then
		return current
	end
	local made = Instance.new("Folder")
	made.Name = FX_FOLDER
	made.Parent = Workspace
	fxFolder = made
	return made
end

local function reduced(): boolean
	return Settings.VfxReduced(player)
end

local function reducedMotion(): boolean
	local ok, value = pcall(function()
		return (GuiService :: any).ReducedMotionEnabled
	end)
	return ok and value == true
end

-- Sons ----------------------------------------------------------------------------------------------------------

local function findSound(name: string): Sound?
	local current: Instance? = ReplicatedStorage
	for _, segment in GlassThrow.SoundsFolder do
		current = if current then current:FindFirstChild(segment) else nil
	end
	local found = if current then current:FindFirstChild(name) else nil
	if found and found:IsA("Sound") then
		return found :: Sound
	end
	once(`sound:{name}`, `{name} absent de ReplicatedStorage.{table.concat(GlassThrow.SoundsFolder, ".")} : pas de son`)
	return nil
end

local function playAt(name: string, position: Vector3)
	local template = findSound(name)
	if template == nil then
		return
	end
	local holder = Instance.new("Attachment")
	holder.Name = `GlassThrowSound_{name}`
	holder.Position = position
	local sound = template:Clone()
	sound.Parent = holder
	holder.Parent = Workspace.Terrain
	sound.Ended:Once(function()
		holder:Destroy()
	end)
	task.delay(SOUND_MAX_LIFETIME, function()
		holder:Destroy()
	end)
	sound:Play()
end

-- Effets de Clément ---------------------------------------------------------------------------------------------

local function asset(name: string): Instance?
	local assets = ReplicatedStorage:FindFirstChild(ASSETS)
	local fx = if assets then assets:FindFirstChild(FX) else nil
	local found = if fx then fx:FindFirstChild(name) else nil
	if found == nil then
		once(`fx:{name}`, `{name} absent de ReplicatedStorage/{ASSETS}/{FX} : effet sauté`)
	end
	return found
end

-- Pose une copie de `name` (Root en `cframe`, taille `size` si donnée), lance ses émetteurs (EmitCount), éteint ses
-- lumières (FadeTime) et la retire après Duration.
local function burstAt(name: string, cframe: CFrame, size: Vector3?)
	if reduced() then
		return
	end
	local template = asset(name)
	if template == nil or not template:IsA("Model") then
		return
	end
	local model = (template :: Model):Clone()
	local root = model:FindFirstChild("Root")
	if root and root:IsA("BasePart") then
		if size then
			(root :: BasePart).Size = size
		end
		model.PrimaryPart = root :: BasePart
	end
	model:PivotTo(cframe)
	model.Parent = folder()
	for _, item in model:GetDescendants() do
		if item:IsA("ParticleEmitter") then
			local count = item:GetAttribute("EmitCount")
			if type(count) == "number" and count > 0 then
				(item :: ParticleEmitter):Emit(count)
			end
		elseif item:IsA("Light") then
			local fade = item:GetAttribute("FadeTime")
			if type(fade) == "number" and fade > 0 then
				TweenService:Create(item, TweenInfo.new(fade), { Brightness = 0 }):Play()
			end
		end
	end
	local duration = model:GetAttribute("Duration")
	task.delay(if type(duration) == "number" and duration > 0 then duration else DEFAULT_DURATION, function()
		model:Destroy()
	end)
end

local function stopTrail(victim: Player)
	local objects = trails[victim]
	if objects == nil then
		return
	end
	trails[victim] = nil
	local trail = objects[1]
	local lifetime = 0.5
	if trail and trail:IsA("Trail") then
		(trail :: Trail).Enabled = false
		lifetime = (trail :: Trail).Lifetime
	end
	task.delay(lifetime + 0.1, function()
		for _, object in objects do
			object:Destroy()
		end
	end)
end

local function startTrail(victim: Player)
	stopTrail(victim)
	if reduced() then
		return
	end
	local character = victim.Character
	local torso = if character then character:FindFirstChild(TORSO) else nil
	local template = asset(GlassThrow.TrailFx)
	local carrier = if template then template:FindFirstChild(CARRIER) else nil
	if torso == nil or not torso:IsA("BasePart") or carrier == nil then
		return
	end
	local trail = carrier:FindFirstChild(TRAIL)
	local top = carrier:FindFirstChild(TRAIL_TOP)
	local bottom = carrier:FindFirstChild(TRAIL_BOTTOM)
	if trail == nil or not trail:IsA("Trail") or top == nil or not top:IsA("Attachment") or bottom == nil or not bottom:IsA("Attachment") then
		once("trail.parts", `{GlassThrow.TrailFx} sans {CARRIER}/{TRAIL}, {TRAIL_TOP} ou {TRAIL_BOTTOM} : pas de traînée`)
		return
	end
	local source = trail :: Trail
	local a0 = (top :: Attachment):Clone()
	local a1 = (bottom :: Attachment):Clone()
	a0.Parent = torso
	a1.Parent = torso
	local copy = source:Clone()
	-- Même sens que chez Clément (TrailTop puis TrailBottom, sauf s'il les a inversés).
	if source.Attachment0 == bottom then
		copy.Attachment0, copy.Attachment1 = a1, a0
	else
		copy.Attachment0, copy.Attachment1 = a0, a1
	end
	copy.Enabled = true
	copy.Parent = torso
	trails[victim] = { copy, a0, a1 }
end

-- Secousse de caméra --------------------------------------------------------------------------------------------

local function applyShake()
	if #shakes == 0 then
		return
	end
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local now = os.clock()
	local wave = now * GlassThrow.ShakeFrequency
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
		local move = shake.Amplitude * decay * 2
		local turn = shake.Angle * decay * 2
		offset += Vector3.new(math.noise(wave, seed, 0.1), math.noise(seed, wave, 0.2), math.noise(0.3, seed, wave)) * move
		rx += math.noise(wave, seed, 1.1) * turn
		ry += math.noise(wave, seed, 2.3) * turn
		rz += math.noise(wave, seed, 3.7) * turn
	end
	camera.CFrame = camera.CFrame * CFrame.new(offset) * CFrame.Angles(rx, ry, rz)
end

local function addShake(duration: number, amplitude: number, angle: number)
	if duration <= 0 or reducedMotion() or reduced() then
		return
	end
	table.insert(shakes, {
		Start = os.clock(),
		Duration = duration,
		Amplitude = amplitude,
		Angle = math.rad(angle),
		Seed = rng:NextNumber(1, 1000),
	})
end

-- Remote --------------------------------------------------------------------------------------------------------

local function fragment(part: BasePart, sites: { any }): { any }?
	return GeometryService:FragmentAsync(part, sites, { CollisionFidelity = Enum.CollisionFidelity.Box }) :: any
end

local function bodyPosition(victim: Player?, fallback: Vector3): Vector3
	local character = if victim then victim.Character else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then (root :: BasePart).Position else fallback
end

local function onThrow(point: Vector3, victim: Player?, hitter: Player?)
	local at = bodyPosition(victim, point)
	playAt(GlassThrow.SoundHit, at)
	playAt(GlassThrow.SoundWhoosh, at)
	if victim then
		startTrail(victim)
	end
	if victim == player then
		addShake(GlassThrow.ShakeVictimDuration, GlassThrow.ShakeVictimAmplitude, GlassThrow.ShakeVictimAngle)
	elseif hitter == player then
		addShake(GlassThrow.ShakeHitterDuration, GlassThrow.ShakeHitterAmplitude, GlassThrow.ShakeHitterAngle)
	end
end

local function onHole(pane: BasePart?, point: Vector3, direction: Vector3, fresh: boolean?)
	local flat = Vector3.new(direction.X, 0, direction.Z)
	local look = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
	local already = if pane then holes[pane] ~= nil else true -- vitre pas chargée ici (streaming) : comme déjà trouée
	if fresh == false and already then
		playAt(GlassThrow.SoundGlassDebris, point)
		return
	end
	burstAt(GlassThrow.BurstFx, CFrame.lookAt(point, point + look))
	playAt(GlassThrow.SoundGlassBurst, point)
	playAt(GlassThrow.SoundGlassDebris, point)
	if pane == nil or already then
		return -- vitre pas chargée ici (streaming), ou déjà trouée sur ce client
	end
	-- Gardé avant FragmentAsync (qui attend) : un second Hole ou un Repair arrivé entre-temps le trouve.
	local state = Hole.Begin(pane, point, look, GlassThrow)
	holes[pane] = state
	Hole.Carve(state, GlassThrow, fragment, folder(), random)
end

local function onRepair(pane: BasePart?, point: Vector3, direction: Vector3)
	local state = if pane then holes[pane] else nil
	local hw, hh, thickness = GlassThrow.HoleHalfWidth, GlassThrow.HoleHalfHeight, 0.3
	local frame = nil
	if state then
		holes[state.Pane] = nil
		Hole.Repair(state)
		hw, hh, frame = state.HalfWidth, state.HalfHeight, state.Frame
		if frame then
			thickness = frame.Thickness
		end
	end
	local cframe: CFrame
	if frame then
		cframe = CFrame.fromMatrix(point, frame.U, frame.V, frame.N)
	else
		local flat = Vector3.new(direction.X, 0, direction.Z)
		local look = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
		cframe = CFrame.lookAt(point, point + look)
	end
	burstAt(GlassThrow.ReformFx, cframe, Vector3.new(hw * 2, hh * 2, math.max(thickness, 0.2)))
	playAt(GlassThrow.SoundGlassReform, point)
end

local function onLand(victim: Player?)
	if victim then
		stopTrail(victim)
	end
	if victim == player then
		local api = animation
		if api then
			api.PlayPlayer(GlassThrow.LandAnimation)
		end
	end
end

local function onEvent(kind: string, pane: Instance?, point: Vector3, direction: Vector3, victim: Player?, hitter: Player?, fresh: boolean?)
	local part: BasePart? = if pane ~= nil and pane:IsA("BasePart") then pane :: BasePart else nil
	if kind == "Throw" then
		onThrow(point, victim, hitter)
	elseif kind == "Hole" then
		-- FragmentAsync attend : à part, pour ne pas retenir le remote.
		task.spawn(onHole, part, point, direction, fresh)
	elseif kind == "Land" then
		onLand(victim)
	elseif kind == "Repair" then
		onRepair(part, point, direction)
	end
end

function GlassThrowController.Start()
	Net = require(Shared:WaitForChild("Net"):WaitForChild("Net")) :: any
	local module = script.Parent:FindFirstChild("AnimationController")
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok and type(result) == "table" and type((result :: any).PlayPlayer) == "function" then
			animation = result :: any
		end
	end
	RunService:BindToRenderStep(SHAKE_STEP, Enum.RenderPriority.Camera.Value + 1, applyShake)
	Net.Client.GlassThrow:Connect(onEvent)
	Players.PlayerRemoving:Connect(function(other: Player)
		stopTrail(other)
	end)
end

return GlassThrowController
