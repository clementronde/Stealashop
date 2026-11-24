-- a277 : tests du Sprint du vigile (Guard/Gait), sur le petit faux Roblox ci-dessous.
local checks, fails = 0, 0
local function check(cond: any, label: string)
	checks += 1
	if cond then
		if VERBOSE then
			print("ok " .. label)
		end
	else
		fails += 1
		print("ÉCHEC " .. label)
	end
end
local function near(a: number?, b: number): boolean
	return a ~= nil and math.abs(a - b) < 1e-6
end

local function newSignal()
	local s = { handlers = {} }
	function s:Connect(f)
		local key = {}
		self.handlers[key] = f
		return {
			Connected = true,
			Disconnect = function(c)
				c.Connected = false
				s.handlers[key] = nil
			end,
		}
	end
	function s:Fire(...)
		for _, f in self.handlers do
			f(...)
		end
	end
	return s
end

local Inst = {}
local InstMeta = {
	__index = function(self, key)
		local method = Inst[key]
		if method then
			return method
		end
		local child = rawget(self, "_children")[key]
		if child then
			return child
		end
		return nil
	end,
}
local function new(class: string, name: string, parent: any?): any
	local o = setmetatable({ ClassName = class, Name = name, _children = {}, Parent = parent }, InstMeta)
	if parent then
		parent._children[name] = o
	end
	return o
end
function Inst:FindFirstChild(name)
	return self._children[name]
end
function Inst:WaitForChild(name)
	local child = self._children[name]
	assert(child, "WaitForChild " .. tostring(name))
	return child
end
function Inst:IsA(class)
	return self.ClassName == class
end
function Inst:GetFullName()
	return self.Name
end

local function newTrack(animation)
	local t = { Name = animation.Name, IsPlaying = false, Weight = 0, Speed = 1, Looped = true, Stopped = newSignal() }
	function t:Play(_fade, weight, speed)
		self.IsPlaying = true
		self.Weight = weight or 1
		self.Speed = speed or 1
	end
	function t:Stop(_fade)
		if self.IsPlaying then
			self.IsPlaying = false
			self.Stopped:Fire()
		end
	end
	function t:AdjustWeight(weight, _fade)
		self.Weight = weight or 1
	end
	function t:AdjustSpeed(speed)
		self.Speed = speed or 1
	end
	function t:GetMarkerReachedSignal()
		return newSignal()
	end
	return t
end

-- Un monde : faux ReplicatedStorage avec les vrais modules, et Gait. chaseSource : source de Config/Chase.
local function buildWorld(chaseSource: string)
	local cache = {}
	local game = {}
	local RS = new("Folder", "ReplicatedStorage")
	local services = {
		ReplicatedStorage = RS,
		ContentProvider = {},
		RunService = { IsStudio = function()
			return false
		end },
	}
	function game:GetService(name)
		return services[name]
	end
	local function module(parent, name, path, source)
		local m = new("ModuleScript", name, parent)
		m._path = path
		m._source = source or SOURCES[path]
		return m
	end
	local load
	load = function(node)
		if cache[node] ~= nil then
			return cache[node]
		end
		local chunk = assert(loadstring("local script, game, require = ...\n" .. node._source, node._path))
		local result = chunk(node, game, load)
		cache[node] = result
		return result
	end
	local Shared = new("Folder", "Shared", RS)
	local Config = new("Folder", "Config", Shared)
	module(Config, "Chase", "shared/Config/Chase.luau", chaseSource)
	module(Config, "DeepFreeze", "shared/Config/DeepFreeze.luau")
	module(Config, "Balance", "shared/Config/Balance.luau")
	local Anim = new("Folder", "Anim", Shared)
	local animNode = module(Anim, "AnimPlayer", "shared/Anim/AnimPlayer.luau")
	local Contract = new("Folder", "Contract", Shared)
	local animationsNode = module(Contract, "Animations", "shared/Contract/Animations.luau")
	local Guard = new("Folder", "Guard", nil)
	local gaitNode = module(Guard, "Gait", "server/Services/Guard/Gait.luau")
	return {
		AnimPlayer = load(animNode),
		Animations = load(animationsNode),
		Chase = load(Config.Chase),
		Balance = load(Config.Balance),
		Gait = load(gaitNode),
	}
end

local world = buildWorld(SOURCES["shared/Config/Chase.luau"])
local AnimPlayer = world.AnimPlayer
local Animations = world.Animations
local Chase = world.Chase
local Night = { GaitSpeedMax = 8 }

-- Les vraies fonctions de pas de GuardService (gaitSpeed, playGait, setWalkSpeed).
local function guardFunctions(guardService)
	local chunk = assert(loadstring("local Balance, Night, GuardService = ...\n" .. GUARD_GAIT .. "\nreturn gaitSpeed, playGait, setWalkSpeed", "GuardService(pas)"))
	return chunk(world.Balance, Night, guardService)
end
local _, playGait, setWalkSpeed = guardFunctions({ _Gait = world.Gait })

local GUARD_NAMES = { "Idle", "Walk", "Run", "Catch", "Tired", "PickUp", "Sprint" }
local function newGuard(opts: { [string]: any }?)
	local o = opts or {}
	local model = new("Model", "Guard_Z1", nil)
	local folder = new("Folder", "Animations", model)
	for _, name in GUARD_NAMES do
		if not (name == "Sprint" and o.noSprint) then
			local a = new("Animation", name, folder)
			a.AnimationId = "rbxassetid://1"
		end
	end
	local animator = new("Animator", "Animator", nil)
	animator.Destroying = newSignal()
	function animator:LoadAnimation(animation)
		return newTrack(animation)
	end
	local specs = o.specs or Animations.Guard
	return {
		anims = AnimPlayer.new(animator, folder, specs, "Vigile"),
		humanoid = { WalkSpeed = 0 },
		scale = o.scale or 1,
		kind = o.kind or "Day",
		speed = if o.speed ~= nil then o.speed else 26.8,
	}
end
local function track(guard, name)
	return guard.anims.tracks[name]
end
local function playing(guard, name): boolean
	local t = track(guard, name)
	return t ~= nil and t.IsPlaying
end

local S = Chase.Sprint

-- Contrat et réglages.
do
	local found
	for _, spec in Animations.Guard do
		if spec.Name == "Sprint" then
			found = spec
		end
	end
	check(found ~= nil and found.Loop == true and found.Priority == "Movement", "C1 Sprint au contrat des vigiles, en boucle, Movement")
	local inNight, inDriver = false, false
	for _, spec in Animations.NightGuard do
		inNight = inNight or spec.Name == "Sprint"
	end
	for _, spec in Animations.Driver do
		inDriver = inDriver or spec.Name == "Sprint"
	end
	check(not inNight and not inDriver, "C2 Sprint absente des vigiles de nuit et des conducteurs")
	check(type(S) == "table" and S.Enabled == true, "C3 Chase.Sprint allumé")
	check(S.FromFactor > S.BackFactor and S.BackFactor >= 1, "C4 FromFactor > BackFactor >= 1 (écart)")
	check(S.Reference > 20 and S.RateMin > 0 and S.RateMax >= S.RateMin and S.Fade >= 0, "C5 Reference > celle de Run, bornes")
end

-- Vigile de jour, course normale 26,8 (zone 1).
do
	local g = newGuard()
	setWalkSpeed(g, 26.8)
	playGait(g, "Run")
	check(playing(g, "Run") and near(track(g, "Run").Weight, 1), "R1 à sa course normale : Run pleine")
	check(not playing(g, "Sprint"), "R2 à sa course normale : pas de Sprint")
	check(near(track(g, "Run").Speed, 26.8 / 20), "R3 Run au pas (26,8 / 20)")
	setWalkSpeed(g, 34)
	check(not playing(g, "Sprint") and near(track(g, "Run").Weight, 1), "R4 34 < 1,3 × 26,8 : toujours Run")
	setWalkSpeed(g, 40)
	check(playing(g, "Sprint") and near(track(g, "Sprint").Weight, 1), "R5 40 > 1,3 × 26,8 : Sprint")
	check(near(track(g, "Sprint").Speed, 40 / S.Reference), "R6 Sprint au pas (40 / Reference)")
	check(playing(g, "Run") and track(g, "Run").Weight < 0.01, "R7 Run encore en lecture sous Sprint, poids quasi nul")
	setWalkSpeed(g, 32)
	check(playing(g, "Sprint"), "R8 32 entre 1,15 et 1,3 × : reste en Sprint (écart)")
	check(near(track(g, "Sprint").Speed, 32 / S.Reference), "R9 vitesse de Sprint suit le pas")
	setWalkSpeed(g, 30)
	check(not playing(g, "Sprint") and playing(g, "Run") and near(track(g, "Run").Weight, 1), "R10 30 < 1,15 × : retour à Run pleine")
	setWalkSpeed(g, 60)
	check(playing(g, "Sprint"), "R11 60 : Sprint de nouveau")
	g.anims:Stop("Run")
	check(not playing(g, "Run") and not playing(g, "Sprint"), "R12 Stop(\"Run\") de GuardService arrête aussi Sprint")
	setWalkSpeed(g, 70)
	check(not playing(g, "Run") and not playing(g, "Sprint"), "R13 hors course, un nouveau pas ne relance rien")
	playGait(g, "Walk")
	check(playing(g, "Walk") and not playing(g, "Sprint"), "R14 Walk ne passe jamais en Sprint")
	g.anims:Stop("Walk")
	playGait(g, "Run")
	check(playing(g, "Sprint") and track(g, "Run").Weight < 0.01, "R15 départ de course à 70 : Sprint d'emblée, Run cachée")
	setWalkSpeed(g, 1000)
	check(near(track(g, "Sprint").Speed, S.RateMax), "R16 vitesse de Sprint bornée à RateMax")
	g.anims:StopAll()
	check(not playing(g, "Sprint") and not playing(g, "Run"), "R17 StopAll arrête tout")
end

-- Échelle du modèle.
do
	local g = newGuard({ scale = 1.4 })
	setWalkSpeed(g, 60)
	playGait(g, "Run")
	check(playing(g, "Sprint") and near(track(g, "Sprint").Speed, 60 / (S.Reference * 1.4)), "E1 Sprint au pas d'un vigile à l'échelle 1,4")
end

-- Cas où Run reste seule.
do
	local night = newGuard({ specs = Animations.NightGuard, kind = "Night" })
	setWalkSpeed(night, 100)
	playGait(night, "Run")
	check(playing(night, "Run") and near(track(night, "Run").Weight, 1) and not playing(night, "Sprint"), "N1 vigile de nuit (contrat sans Sprint) : Run")
	local missing = newGuard({ noSprint = true })
	setWalkSpeed(missing, 100)
	playGait(missing, "Run")
	check(playing(missing, "Run") and near(track(missing, "Run").Weight, 1), "N2 Sprint pas livrée : Run pleine")
	check(track(missing, "Sprint") == nil, "N3 Sprint pas livrée : aucune piste")
	local still = newGuard({ speed = 0 })
	setWalkSpeed(still, 100)
	playGait(still, "Run")
	check(not playing(still, "Sprint") and playing(still, "Run"), "N4 course normale 0 : Run")
	local _, playOld, setOld = guardFunctions({})
	local old = newGuard()
	setOld(old, 100)
	playOld(old, "Run")
	check(playing(old, "Run") and not playing(old, "Sprint"), "N5 sans Guard/Gait (faux arbres) : Run comme avant")
	setOld(old, 50)
	check(near(track(old, "Run").Speed, math.min(50 / 20, 1.6 * world.Balance.Stats.RealSpeedScale)), "N6 sans Guard/Gait : Run suit son pas")
end

-- Interrupteur coupé.
do
	local source = SOURCES["shared/Config/Chase.luau"]
	local off, count = string.gsub(source, "Sprint = {\n\t\tEnabled = true", "Sprint = {\n\t\tEnabled = false")
	check(count == 1, "O0 interrupteur trouvé dans Config/Chase")
	local offWorld = buildWorld(off)
	local _, playOff, setOff = guardFunctions({ _Gait = offWorld.Gait })
	local g = newGuard()
	setOff(g, 100)
	playOff(g, "Run")
	check(playing(g, "Run") and near(track(g, "Run").Weight, 1) and not playing(g, "Sprint"), "O1 Chase.Sprint.Enabled = false : Run")
end

print(`banc a277 : {checks} vérification(s), {fails} échec(s)`)
