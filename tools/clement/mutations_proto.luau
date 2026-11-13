-- Aperçu animé des 7 mutations, en Edit, sans Play (Clément, 2026-11-13). Sert aussi de modèle au code
-- d'Ironix : la façon d'appliquer Assets/FX/Mutations/FX_Mutation_<Id> sur un objet et de jouer son
-- mouvement (Pulse, Glitch, Rainbow) est ici, fonctions apply() et update().
-- Lancer après tools/clement/mutations_fx_build.luau. Pose Workspace/_PREVIEW_Mutations (à la même
-- place s'il existe déjà, sinon devant la caméra) : un objet normal, puis Shiny, Gold, Neon, Diamond,
-- Glitch, Hacked, Rainbow.
-- Arrêt : _G.MutationProto.Stop() (l'aperçu reste, figé) ; _G.MutationProto.Clear() le retire.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PREVIEW_ITEM = "ITM_Z3_CarteGraphiqueEnOr"
local ORDER = { "Shiny", "Gold", "Neon", "Diamond", "Glitch", "Hacked", "Rainbow" }
local SPACING = 3.4

if _G.MutationProto then
	_G.MutationProto.Stop()
end

local fxFound = ReplicatedStorage.Assets.FX:FindFirstChild("Mutations")
assert(fxFound, "Assets/FX/Mutations introuvable : lancer mutations_fx_build.luau d'abord")
local fxRoot = fxFound :: Folder
local referenceSize = (fxRoot:GetAttribute("ReferenceSize") :: number?) or 2

local function luminance(c: Color3): number
	return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
end

local function scaleSeq(seq: NumberSequence, k: number): NumberSequence
	local keys = {}
	for _, kp in seq.Keypoints do
		table.insert(keys, NumberSequenceKeypoint.new(kp.Time, kp.Value * k, kp.Envelope * k))
	end
	return NumberSequence.new(keys)
end

-- Ce que l'effet ajoute à l'objet porte un nom qui commence par « Mutation » (MutationFX,
-- MutationGhost_01, MutationGlow_01) ou s'appelle RainbowArc : on ne le recolore jamais.
local function isEffect(inst: Instance, root: Instance): boolean
	local current: Instance? = inst
	while current and current ~= root do
		if string.sub(current.Name, 1, 8) == "Mutation" or current.Name == "RainbowArc" then
			return true
		end
		current = current.Parent
	end
	return false
end

-- Les pièces visibles d'un modèle, dans l'ordre de GetDescendants (le même dans une copie).
local function visibleParts(model: Model, skipEffects: boolean): { BasePart }
	local list = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.99 and not (skipEffects and isEffect(d, model)) then
			table.insert(list, d)
		end
	end
	return list
end

type PartState = { part: BasePart, color: Color3, shade: number }
type GhostState = {
	model: Model,
	parts: { BasePart },
	keepColor: boolean,
	transparency: number,
	offset: Vector3,
	jitter: number,
	current: Vector3,
	flicker: boolean,
}
type State = {
	model: Model,
	style: Folder,
	base: CFrame,
	box: CFrame,
	size: Vector3,
	parts: { PartState },
	ghosts: { GhostState },
	light: PointLight?,
	lightBrightness: number,
	nextJitter: number,
	nextBurst: number,
	burstUntil: number,
	burstOffset: Vector3,
	lastPaint: number,
}

local function averageColor(parts: { PartState }): Color3
	local r, g, b = 0, 0, 0
	for _, p in parts do
		r += p.part.Color.R
		g += p.part.Color.G
		b += p.part.Color.B
	end
	local n = math.max(#parts, 1)
	return Color3.new(r / n, g / n, b / n)
end

-- Copie les couleurs de l'objet sur les coques KeepColor.
local function syncGhostColors(state: State)
	for _, g in state.ghosts do
		if g.keepColor then
			for i, p in g.parts do
				local source = state.parts[i]
				if source then
					p.Color = source.part.Color
				end
			end
		end
	end
end

-- Applique l'effet `id` sur `model` : couleurs, matière, particules, lumière, doubles, extras.
local function apply(model: Model, id: string): State
	local found = fxRoot:FindFirstChild("FX_Mutation_" .. id)
	assert(found, "FX_Mutation_" .. id .. " introuvable")
	local style = found :: Folder
	local box, size = model:GetBoundingBox()
	local maxSide = math.max(size.X, size.Y, size.Z)
	local k = maxSide / referenceSize
	local mode = style:GetAttribute("ColorMode") :: string
	local tint = style:GetAttribute("TintColor") :: Color3
	local shadeMin = style:GetAttribute("ShadeMin") :: number
	local material = style:GetAttribute("Material") :: string
	local reflectance = style:GetAttribute("Reflectance") :: number

	-- doubles et coques, copiés sur l'objet encore intact
	local ghosts: { GhostState } = {}
	local ghostFolder = style:FindFirstChild("Ghosts")
	if ghostFolder then
		for _, g in ghostFolder:GetChildren() do
			local copy = model:Clone()
			copy.Name = "Mutation" .. g.Name
			for _, d in copy:GetDescendants() do
				if not (d:IsA("BasePart") or d:IsA("Model") or d:IsA("Folder") or d:IsA("Attachment") or d:IsA("SpecialMesh")) then
					d:Destroy()
				end
			end
			local keepColor = g:GetAttribute("KeepColor") == true
			local transparency = g:GetAttribute("Transparency") :: number
			local parts = visibleParts(copy, false)
			for _, d in copy:GetDescendants() do
				if d:IsA("BasePart") then
					d.CanCollide = false
					d.CanQuery = false
					d.CanTouch = false
					d.CastShadow = false
				end
			end
			for _, d in parts do
				if not keepColor then
					d.Color = g:GetAttribute("Color") :: Color3
				end
				d.Material = (Enum.Material :: any)[g:GetAttribute("Material") :: string]
				d.Transparency = transparency
				d.Reflectance = 0
			end
			copy.WorldPivot = box
			copy:ScaleTo(g:GetAttribute("Scale") :: number)
			table.insert(ghosts, {
				model = copy,
				parts = parts,
				keepColor = keepColor,
				transparency = transparency,
				offset = g:GetAttribute("Offset") :: Vector3,
				jitter = (g:GetAttribute("Jitter") :: number) * maxSide,
				current = Vector3.zero,
				flicker = (g:GetAttribute("Material") :: string) == "ForceField",
			})
		end
	end

	-- couleurs et matière de l'objet
	local parts: { PartState } = {}
	local list = visibleParts(model, true)
	local maxLum = 0.01
	for _, p in list do
		maxLum = math.max(maxLum, luminance(p.Color))
	end
	for _, p in list do
		local original = p.Color
		local shade = shadeMin + (1 - shadeMin) * math.clamp(luminance(original) / maxLum, 0, 1)
		if mode == "Shade" then
			p.Color = Color3.new(tint.R * shade, tint.G * shade, tint.B * shade)
		elseif mode == "Saturate" then
			local h, s, v = original:ToHSV()
			p.Color = Color3.fromHSV(h, math.max(s, 0.85), math.max(v, 0.95))
		end
		if material ~= "" then
			p.Material = (Enum.Material :: any)[material]
		end
		if reflectance >= 0 then
			p.Reflectance = reflectance
		end
		table.insert(parts, { part = p, color = p.Color, shade = shade })
	end

	-- particules et lumière, dans une pièce invisible à la taille de la boîte
	local light: PointLight? = nil
	local lightBrightness = (style:GetAttribute("LightBrightness") :: number?) or 0
	local emitters = style:FindFirstChild("Emitters")
	local hasEmitters = emitters ~= nil and #emitters:GetChildren() > 0
	if hasEmitters or lightBrightness > 0 then
		local boxScale = (style:GetAttribute("EmitterBoxScale") :: number?) or 1
		local fx = Instance.new("Part")
		fx.Name = "MutationFX"
		fx.Anchored = true
		fx.CanCollide = false
		fx.CanQuery = false
		fx.CanTouch = false
		fx.CastShadow = false
		fx.Transparency = 1
		fx.Size = Vector3.new(math.max(size.X * boxScale, 0.2), math.max(size.Y * boxScale, 0.2), math.max(size.Z * boxScale, 0.2))
		fx.CFrame = box
		if emitters then
			for _, e in emitters:GetChildren() do
				local copy = e:Clone() :: ParticleEmitter
				copy.Size = scaleSeq(copy.Size, k)
				copy.Speed = NumberRange.new(copy.Speed.Min * k, copy.Speed.Max * k)
				copy.Acceleration *= k
				copy.Parent = fx
			end
		end
		if lightBrightness > 0 then
			local l = Instance.new("PointLight")
			l.Name = "MutationLight"
			l.Brightness = lightBrightness
			l.Range = ((style:GetAttribute("LightRange") :: number?) or 6) * k
			l.Shadows = false
			l.Color = averageColor(parts)
			l.Parent = fx
			light = l
		end
		fx.Parent = model
	end

	-- extras (arc-en-ciel derrière l'objet, face avant = −Z)
	local extras = style:FindFirstChild("Extras")
	if extras then
		for _, e in extras:GetChildren() do
			if e:IsA("Model") then
				local copy = e:Clone()
				local fit = (copy:GetAttribute("FitHeight") :: number?) or 2
				local scale = math.max(size.Y, size.X * 0.7) / fit
				copy:ScaleTo(scale)
				copy:PivotTo(box * CFrame.new(0, -size.Y * 0.3, size.Z / 2 + 0.15 * scale))
				copy.Parent = model
			end
		end
	end

	for _, g in ghosts do
		g.model.Parent = model
	end

	local state: State = {
		model = model,
		style = style,
		base = model:GetPivot(),
		box = box,
		size = size,
		parts = parts,
		ghosts = ghosts,
		light = light,
		lightBrightness = lightBrightness,
		nextJitter = 0,
		nextBurst = os.clock() + math.random() * 1.5,
		burstUntil = 0,
		burstOffset = Vector3.zero,
		lastPaint = 0,
	}
	syncGhostColors(state)
	return state
end

local function placeGhosts(state: State, box: CFrame, factor: number)
	for _, g in state.ghosts do
		local o = Vector3.new(g.offset.X * state.size.X, g.offset.Y * state.size.Y, g.offset.Z * state.size.Z)
		g.model:PivotTo(box * CFrame.new(o * factor + g.current))
	end
end

-- Un pas d'animation (t = os.clock()).
local function update(state: State, t: number)
	local motion = state.style:GetAttribute("Motion") :: string
	local period = state.style:GetAttribute("MotionPeriod") :: number
	if motion == "Rainbow" then
		if t - state.lastPaint < 1 / 30 then
			return
		end
		state.lastPaint = t
		local c = Color3.fromHSV((t / period) % 1, 0.85, 1)
		for _, p in state.parts do
			p.part.Color = Color3.new(c.R * p.shade, c.G * p.shade, c.B * p.shade)
		end
		syncGhostColors(state)
		if state.light then
			state.light.Color = c
		end
	elseif motion == "Pulse" then
		if t - state.lastPaint < 1 / 30 then
			return
		end
		state.lastPaint = t
		local wave = math.sin(t * 2 * math.pi / period) -- −1 à 1
		local f = 0.875 + 0.125 * wave
		for _, p in state.parts do
			local h, s, v = p.color:ToHSV()
			p.part.Color = Color3.fromHSV(h, s, v * f)
		end
		syncGhostColors(state)
		for _, g in state.ghosts do
			local tr = math.clamp(g.transparency - 0.08 * wave, 0, 1)
			for _, d in g.parts do
				d.Transparency = tr
			end
		end
		if state.light then
			state.light.Brightness = state.lightBrightness * (1 + 0.3 * wave)
		end
	elseif motion == "Glitch" then
		local maxSide = math.max(state.size.X, state.size.Y, state.size.Z)
		local jump = (state.style:GetAttribute("GlitchJump") :: number?) or 0.03
		local spread = (state.style:GetAttribute("GlitchSpread") :: number?) or 1.8
		if t >= state.nextJitter then
			state.nextJitter = t + 0.05
			for _, g in state.ghosts do
				g.current = Vector3.new((math.random() * 2 - 1) * g.jitter, (math.random() * 2 - 1) * g.jitter * 0.5, 0)
			end
		end
		if t >= state.nextBurst then
			state.burstUntil = t + 0.12
			state.nextBurst = t + period * (0.5 + math.random())
			state.burstOffset = Vector3.new((math.random() * 2 - 1) * jump * maxSide, (math.random() * 2 - 1) * jump * 0.4 * maxSide, 0)
		end
		local bursting = t < state.burstUntil
		local pivot = state.base * CFrame.new(if bursting then state.burstOffset else Vector3.zero)
		state.model:PivotTo(pivot)
		placeGhosts(state, pivot * state.base:ToObjectSpace(state.box), if bursting then spread else 1)
		for _, g in state.ghosts do
			if g.flicker then
				local hidden = bursting and math.random() < 0.5
				for _, d in g.parts do
					d.LocalTransparencyModifier = if hidden then 1 else 0
				end
			end
		end
	end
end

-- Aperçu : à la place de l'ancien s'il existe, sinon devant la caméra.
local old = workspace:FindFirstChild("_PREVIEW_Mutations")
local origin: CFrame
local oldNormal = old and old:FindFirstChild("01_Normal")
if oldNormal and oldNormal:IsA("Model") then
	origin = oldNormal:GetPivot() * CFrame.new(-4 * SPACING, 0, 0)
else
	local cam = workspace.CurrentCamera
	local flatLook = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z).Unit
	local center = cam.CFrame.Position + cam.CFrame.LookVector * 22
	origin = CFrame.lookAt(center, center - flatLook)
end
if old then
	old:Destroy()
end
local preview = Instance.new("Model")
preview.Name = "_PREVIEW_Mutations"
local sourceFound = ReplicatedStorage.Assets.Items:FindFirstChild(PREVIEW_ITEM)
assert(sourceFound, PREVIEW_ITEM .. " introuvable")
local source = sourceFound :: Model
local states: { State } = {}
for i = 0, #ORDER do
	local copy = source:Clone()
	local id = ORDER[i]
	copy.Name = string.format("%02d_%s", i + 1, id or "Normal")
	copy:PivotTo(origin * CFrame.new((4 - i) * SPACING, 0, 0))
	copy.Parent = preview
	if id then
		table.insert(states, apply(copy, id))
	end
end
preview.Parent = workspace
for _, s in states do
	placeGhosts(s, s.box, 1)
end

local connection = RunService.Heartbeat:Connect(function()
	local t = os.clock()
	for _, s in states do
		update(s, t)
	end
end)

_G.MutationProto = {
	Stop = function()
		connection:Disconnect()
	end,
	Clear = function()
		connection:Disconnect()
		local p = workspace:FindFirstChild("_PREVIEW_Mutations")
		if p then
			p:Destroy()
		end
	end,
	apply = apply,
	update = update,
}
print("Aperçu des mutations lancé (_G.MutationProto.Stop() pour l'arrêter)")
