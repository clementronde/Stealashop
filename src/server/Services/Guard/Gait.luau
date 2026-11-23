--!strict
-- Guard/Gait (serveur, a277 ; L-249, L-238 a) : module d'aide de GuardService (sous-dossier : le Loader ne le démarre
-- pas). Valeurs : Config/Chase.Sprint (interrupteur Enabled).
--
-- Le vigile du magasin va jusqu'à 2,5 × la marche du voleur (Chase.SpringFarFactor) ; Run est faite pour une course
-- normale. Au-dessus de Sprint.FromFactor × sa course normale (guard.speed, la vitesse de poursuite de sa zone), il
-- joue Sprint au lieu de Run ; il revient à Run sous Sprint.BackFactor × (écart pour ne pas clignoter). La vitesse de
-- lecture de Sprint suit son pas comme celle de Run (WalkSpeed / (Sprint.Reference × échelle), bornée).
-- Seulement pour un AnimPlayer dont le contrat liste Sprint (Animations.Guard : vigiles de magasin ; pas le vigile de
-- nuit, ni le conducteur, ni le policier) et dont le modèle a livré l'animation. Sinon : Run, comme avant.
--
-- GuardService arrête la course par anims:Stop("Run") à une dizaine d'endroits. Pour ne pas les toucher, Run continue
-- de jouer sous Sprint avec un poids quasi nul : quand Run s'arrête (Stopped), Sprint s'arrête avec elle.
--
-- API :
--   Gait.Run(anims, walkSpeed, normalSpeed, runRate, scale) -> boolean   joue la course (Run ou Sprint) ; false : rien
--                                                                         fait, l'appelant joue Run comme avant

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Chase = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Chase")) :: any

local SPRINT = "Sprint"
local RUN = "Run"
-- Poids de Run sous Sprint : assez bas pour ne pas se voir, non nul pour que la piste reste en lecture.
local HIDDEN_WEIGHT = 0.001

type State = {
	sprinting: boolean,
	link: RBXScriptConnection?, -- Run.Stopped → Sprint s'arrête aussi
}

local states: { [any]: State } = setmetatable({}, { __mode = "k" }) :: any

local Gait = {}

local function config(): any
	local sprint = Chase.Sprint
	if type(sprint) ~= "table" or sprint.Enabled ~= true then
		return nil
	end
	return sprint
end

-- Sprint au contrat de cet AnimPlayer et livrée dans le modèle ?
local function hasSprint(anims: any): boolean
	local specs = anims.specs
	if type(specs) ~= "table" or specs[SPRINT] == nil then
		return false
	end
	return anims:GetTrack(SPRINT) ~= nil
end

local function stateOf(anims: any): State
	local found = states[anims]
	if found then
		return found
	end
	local state: State = { sprinting = false, link = nil }
	states[anims] = state
	return state
end

local function sprintRate(sprint: any, walkSpeed: number, scale: number): number
	local reference = math.max(sprint.Reference * scale, 1e-3)
	return math.clamp(walkSpeed / reference, sprint.RateMin, math.max(sprint.RateMax, sprint.RateMin))
end

-- Retour à Run (pleine) : Sprint s'arrête en fondu.
local function backToRun(anims: any, state: State, fade: number, runRate: number)
	state.sprinting = false
	anims:Play(RUN, fade, 1, runRate)
	anims:Stop(SPRINT, fade)
end

function Gait.Run(anims: any, walkSpeed: number, normalSpeed: number, runRate: number, scale: number): boolean
	local sprint = config()
	local state = states[anims]
	local sprinting = state ~= nil and state.sprinting
	if sprint == nil or not hasSprint(anims) then
		if sprinting and state then
			backToRun(anims, state, if sprint then sprint.Fade else 0.2, runRate)
			return true
		end
		return false
	end
	local factor = if sprinting then sprint.BackFactor else sprint.FromFactor
	local wants = normalSpeed > 0 and walkSpeed > factor * normalSpeed
	if not wants then
		if sprinting and state then
			backToRun(anims, state, sprint.Fade, runRate)
			return true
		end
		return false
	end
	-- Run reste en lecture sous Sprint (poids quasi nul) : son arrêt arrête Sprint.
	local run = anims:Play(RUN, sprint.Fade, HIDDEN_WEIGHT, runRate)
	if run == nil then
		return false
	end
	local current = stateOf(anims)
	if anims:Play(SPRINT, sprint.Fade, 1, sprintRate(sprint, walkSpeed, scale)) == nil then
		backToRun(anims, current, sprint.Fade, runRate)
		return true
	end
	current.sprinting = true
	if current.link == nil then
		current.link = run.Stopped:Connect(function()
			current.sprinting = false
			anims:Stop(SPRINT, sprint.Fade)
		end)
	end
	return true
end

return Gait
