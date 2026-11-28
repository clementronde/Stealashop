--!strict
-- StrikeFeel (a519, L-448) : coups plus secs et course portée calée, côté client, sur le joueur local.
-- Allumé par Features.StrikeFeel partout, ou Features.StrikeFeelDev dans le jeu DEV (Config/ProductIds.IsDev), lu à
-- chaque appel (Config/LiveFeatures : se rallume sans republier). Valeurs : Config/AnimFeel. Les animations de Clément ne
-- sont jamais retouchées : le code règle seulement le fondu au lancement, la vitesse de lecture et un arrêt sur image.
--
--   StrikeFeel.on() -> boolean
--   StrikeFeel.isStrike(name) -> boolean      animation du joueur au marqueur Impact, sans boucle (Contract/Animations)
--   StrikeFeel.fade(name, fallback?) -> number?  allumé et coup : AnimFeel.StrikeFade ; sinon `fallback`
--   StrikeFeel.impact(name, track)            allumé et coup : arrêt sur image de la seule piste `track` (AnimFeel.Hitstop)
--   StrikeFeel.hold(track, duration)          arrêt sur image partagé, toujours actif (ShatterController s'en sert aussi) :
--                                             plusieurs arrêts en même temps se cumulent, la vitesse d'avant revient
--                                             après le dernier
--   StrikeFeel.setSpeed(track, speed)         vitesse de lecture ; pendant un arrêt, elle reviendra à la fin
--   StrikeFeel.runRate(name, groundSpeed) -> number?  allumé et course (AnimFeel.Run.Names) : vitesse de lecture calée
--                                             sur la vitesse au sol ; sinon nil (ne rien toucher)

local Shared = script.Parent.Parent
local ConfigFolder = Shared:WaitForChild("Config")
local AnimFeel = require(ConfigFolder:WaitForChild("AnimFeel"))
local Features = require(ConfigFolder:WaitForChild("Features")) :: any
local Animations = require(Shared:WaitForChild("Contract"):WaitForChild("Animations"))

local IMPACT_MARKER = "Impact"

local StrikeFeel = {}

local strikes: { [string]: boolean } = {}
for _, spec in Animations.Player do
	if spec.Marker == IMPACT_MARKER and not spec.Loop then
		strikes[spec.Name] = true
	end
end

local runs: { [string]: boolean } = {}
for _, name in AnimFeel.Run.Names do
	runs[name] = true
end

local isDev = (function(): boolean
	local module = ConfigFolder:FindFirstChild("ProductIds")
	if module == nil or not module:IsA("ModuleScript") then
		return false
	end
	local ok, result = pcall(require, module :: any)
	return ok and type(result) == "table" and (result :: any).IsDev == true
end)()

function StrikeFeel.on(): boolean
	return Features.StrikeFeel == true or (Features.StrikeFeelDev == true and isDev)
end

function StrikeFeel.isStrike(name: string): boolean
	return strikes[name] == true
end

function StrikeFeel.fade(name: string, fallback: number?): number?
	if strikes[name] and StrikeFeel.on() then
		return AnimFeel.StrikeFade
	end
	return fallback
end

-- Arrêts en cours : nombre d'arrêts sur la piste et vitesse à lui rendre après le dernier.
type Hold = { count: number, speed: number }
local holds: { [AnimationTrack]: Hold } = setmetatable({}, { __mode = "k" }) :: any

function StrikeFeel.hold(track: AnimationTrack, duration: number)
	if duration <= 0 then
		return
	end
	local entry = holds[track]
	if entry then
		entry.count += 1
	else
		entry = { count = 1, speed = track.Speed }
		holds[track] = entry
		track:AdjustSpeed(0)
	end
	local held: Hold = entry
	task.delay(duration, function()
		held.count -= 1
		if held.count > 0 or holds[track] ~= held then
			return
		end
		holds[track] = nil
		if track.IsPlaying then
			track:AdjustSpeed(held.speed)
		end
	end)
end

function StrikeFeel.setSpeed(track: AnimationTrack, speed: number)
	local entry = holds[track]
	if entry then
		entry.speed = speed
	elseif track.Speed ~= speed then
		track:AdjustSpeed(speed)
	end
end

function StrikeFeel.impact(name: string, track: AnimationTrack)
	if not strikes[name] or not StrikeFeel.on() then
		return
	end
	local hitstop = AnimFeel.Hitstop
	StrikeFeel.hold(track, hitstop[name] or hitstop.Default)
end

function StrikeFeel.runRate(name: string, groundSpeed: number): number?
	if not runs[name] or not StrikeFeel.on() then
		return nil
	end
	local run = AnimFeel.Run
	return math.clamp(groundSpeed / run.RefSpeed, run.MinRate, run.MaxRate)
end

return StrikeFeel
