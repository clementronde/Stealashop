--!strict
-- TrapController (vague 72, a243 ; liaison L-218, L-229 partie Pièges) : ce que le client montre des pièges de
-- boutique. Le serveur décide tout (TrapService, Config/Traps) ; ce contrôleur n'envoie rien.
--
--   - Chaque piège posé (tag Traps.Tag) : attribut TrapState « Armed » → Armed visible, Triggered caché ;
--     « Triggered » → Armed caché (LocalTransparencyModifier, émetteurs, beams et lumières éteints), Triggered
--     montré (pièces à leur attribut ShownTransparency, sinon 0 ; décalques à 0 ; ParticleEmitter, Beam et lumières
--     allumés ; les émetteurs qui portent EmitCount lancent une gerbe au lieu de s'allumer). Au passage en
--     « Triggered » (pas à l'arrivée d'un piège déjà déclenché), son 3D Trap_<…> sur la Base (MarkerSounds.find,
--     absent = muet). Tout est local : la copie du serveur garde ses valeurs.
--   - Joueur local pris (attribut TrapEffect du Player) : l'animation du piège (TrapStuck, TrapNetted ; absente :
--     Stunned) en boucle tant que l'attribut reste.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Traps = require(Shared:WaitForChild("Config"):WaitForChild("Traps"))
local MarkerSounds = require(Shared:WaitForChild("Anim"):WaitForChild("MarkerSounds"))
local Animations = require(Shared:WaitForChild("Contract"):WaitForChild("Animations"))

-- État d'origine des effets de la partie Armed, remis au réarmement.
type Saved = { [Instance]: boolean }

local TrapController = {}

local savedArmed: { [Model]: Saved } = {}
local playing: string? = nil

local function animations(): any
	local module = script.Parent:FindFirstChild("AnimationController")
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, module)
	return if ok then result else nil
end

local function isEffect(inst: Instance): boolean
	return inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("Light")
end

local function setEnabled(inst: Instance, on: boolean)
	if isEffect(inst) then
		(inst :: any).Enabled = on
	end
end

local function showArmed(model: Model, armed: Instance, on: boolean)
	local saved = savedArmed[model]
	if saved == nil then
		saved = {}
		for _, inst in armed:GetDescendants() do
			if isEffect(inst) then
				saved[inst] = (inst :: any).Enabled == true
			end
		end
		savedArmed[model] = saved
	end
	for _, inst in armed:GetDescendants() do
		if inst:IsA("BasePart") then
			inst.LocalTransparencyModifier = if on then 0 else 1
		elseif isEffect(inst) then
			setEnabled(inst, on and saved[inst] == true)
		end
	end
end

local function showTriggered(triggered: Instance, on: boolean, burst: boolean)
	for _, inst in triggered:GetDescendants() do
		if inst:IsA("BasePart") then
			local shown = inst:GetAttribute("ShownTransparency")
			inst.Transparency = if on then (if type(shown) == "number" then shown else 0) else 1
		elseif inst:IsA("Decal") then
			inst.Transparency = if on then 0 else 1
		elseif inst:IsA("ParticleEmitter") then
			local count = inst:GetAttribute("EmitCount")
			if type(count) == "number" then
				inst.Enabled = false
				if on and burst then
					inst:Emit(count)
				end
			else
				inst.Enabled = on
			end
		elseif inst:IsA("Beam") or inst:IsA("Light") then
			setEnabled(inst, on)
		end
	end
end

local function apply(model: Model, fromChange: boolean)
	local triggeredNow = model:GetAttribute(Traps.StateAttribute) == Traps.Triggered
	local armed = model:FindFirstChild("Armed")
	local triggered = model:FindFirstChild("Triggered")
	if armed then
		showArmed(model, armed, not triggeredNow)
	end
	if triggered then
		showTriggered(triggered, triggeredNow, fromChange)
	end
	if triggeredNow and fromChange then
		local trap = Traps.ById[tostring(model:GetAttribute(Traps.TrapIdAttribute))]
		local base = model.PrimaryPart or model:FindFirstChild("Base")
		if trap and base and base:IsA("BasePart") then
			MarkerSounds.play(trap.Sound, base)
		end
	end
end

-- a318 (L-300) : un piège qui sort du streaming (boutique loin du joueur) puis revient est le même objet, annoncé de
-- nouveau. Une seule écoute par piège, retirée à sa sortie ; à la sortie, les effets de Armed reprennent l'état
-- d'origine gardé ici (sinon, revenu éteint, ils auraient été relus éteints et seraient restés éteints au réarmement).
local stateLinks: { [Model]: RBXScriptConnection } = {}

local function onTrapAdded(inst: Instance)
	if not inst:IsA("Model") then
		return
	end
	local model = inst :: Model
	apply(model, false)
	if not stateLinks[model] then
		stateLinks[model] = model:GetAttributeChangedSignal(Traps.StateAttribute):Connect(function()
			apply(model, true)
		end)
	end
end

local function onTrapRemoved(inst: Instance)
	if not inst:IsA("Model") then
		return
	end
	local model = inst :: Model
	local link = stateLinks[model]
	if link then
		link:Disconnect()
		stateLinks[model] = nil
	end
	local saved = savedArmed[model]
	if saved then
		for effect, enabled in saved do
			setEnabled(effect, enabled)
		end
	end
	savedArmed[model] = nil
end

-- L'animation du joueur `name` est-elle livrée (objet Animation avec un AnimationId) ?
local function isDelivered(name: string): boolean
	local current: Instance? = ReplicatedStorage
	for _, segment in Animations.PlayerFolder do
		current = if current then current:FindFirstChild(segment) else nil
	end
	local inst = if current then current:FindFirstChild(name) else nil
	return inst ~= nil and inst:IsA("Animation") and string.match((inst :: Animation).AnimationId, "%d+") ~= nil
end

-- Animation du joueur local pris (voir l'en-tête).
local function onEffectChanged()
	local anims = animations()
	if anims == nil then
		return
	end
	local id = Players.LocalPlayer:GetAttribute(Traps.EffectAttribute)
	local trap = if type(id) == "string" then Traps.ById[id] else nil
	local wanted: string? = nil
	if trap then
		wanted = if isDelivered(trap.Animation) then trap.Animation else Traps.FallbackAnimation
	end
	local stop = anims.StopPlayer
	if playing and playing ~= wanted and stop then
		stop(playing)
	end
	playing = wanted
	if wanted then
		anims.PlayPlayer(wanted)
	end
end

function TrapController.Start()
	CollectionService:GetInstanceAddedSignal(Traps.Tag):Connect(onTrapAdded)
	CollectionService:GetInstanceRemovedSignal(Traps.Tag):Connect(onTrapRemoved)
	for _, inst in CollectionService:GetTagged(Traps.Tag) do
		onTrapAdded(inst)
	end
	Players.LocalPlayer:GetAttributeChangedSignal(Traps.EffectAttribute):Connect(onEffectChanged)
	onEffectChanged()
end

return TrapController
