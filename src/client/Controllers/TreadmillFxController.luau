--!strict
-- TreadmillFxController (client, visuel seulement ; liaison L-093 question 3, L-097 point 2) : anime
-- les tapis de course PLOT_Treadmill_<Variante> que MachineVariantService pose dans les boutiques,
-- pendant qu'un joueur y court. Ce que bouge chaque variante : notes/boutique-joueur-MOD-015-016.md
-- (valeurs « en course »), réglages dans Config/TreadmillFX.
--
-- Qui court, sur quel tapis : un joueur dont l'attribut TrainingMachine vaut "Treadmill" (posé par
-- TrainingService) court sur le tapis (tag Treadmill) de sa parcelle (tag PlayerPlot dont
-- OwnerUserId = son UserId) : seul le propriétaire s'entraîne sur le tapis de sa parcelle. Tous les
-- coureurs visibles sont animés chez chaque client, pas seulement le joueur local.
--
-- Pendant la course (sinon tout est immobile, aux valeurs de Clément) :
--   - tous les tapis : Belt/BeltTexture défile (OffsetStudsV, Config BeltSpeed ; Candy en sens inverse) ;
--   - Gold : RunBurst allumé, GoldFX.Halo1 à 4 tournent, WingFX.WingLight et GoldGlow pulsent ;
--   - CashRegister : RunBurst et RunBurstCoins allumés, Bills.Rate et Stream.TextureSpeed de course,
--     RegisterLight et GlowMint pulsent ;
--   - Police : gyrophares (cycle rouge-rouge puis bleu-bleu : SirenRed/SirenBlue, Light_red/blue,
--     Emit des FlareR/FlareB), Sweep_red et Sweep_blue tournent, RunStreak allumé, RunTrail copié sur le
--     HumanoidRootPart du coureur ;
--   - LaserVault : alarme (AlarmGlow, Alarm*.Light, Emit des Alarm*.Flash), lasers qui scintillent,
--     ScanGate qui monte et descend, CamScan1-2 qui balaient, RunCoins allumé ;
--   - Ice : RunBurst, BeltArrows, CrystalGlow et CrownLight pulsent, FrostRing tourne ;
--   - Toxic : ToxicGoo, GooLight, BeltArrows et lanternes, RunSplash allumé, RunTrail copié ;
--   - Candy : Peppermint et PeppermintSwirl tournent, CandyGlow, SprinkleArch.Light, BeltArrows pulsent,
--     un Popper au hasard éclate, RunPops et RunPuff allumés, RunTrail copié ;
--   - Fire : RunBurst, braseros qui vacillent, EmberGlow ;
--   - Base, Silver, Void (et toute variante inconnue) : la bande seule.
-- La variante se reconnaît à son dossier d'effets (GoldFX, PoliceFX…) : le modèle posé s'appelle
-- toujours « Treadmill ». Une pièce absente est sautée, sans erreur.
--
-- VISUAL EFFECTS sur OFF (VfxEnabled = false, Config/Settings) : la bande défile seule, tout le reste
-- est coupé (gyrophares, gerbes, trails, lumières).
--
-- Propreté : chaque propriété touchée est notée avec sa valeur d'origine et rendue à l'arrêt (fin de
-- la course, tapis remplacé par MachineVariantService ou sorti de Workspace, coureur parti, tapis trop
-- loin, bascule VISUAL EFFECTS) ; les copies de trail sont détruites. Aucun script dans les modèles.
--
-- Performance : un seul Heartbeat. Seuls les tapis avec coureur et à moins de ActiveDistance de la
-- caméra sont animés ; un tapis immobile ne coûte rien à chaque image. Le contrôle « qui court où »
-- se fait toutes les CheckInterval s et à chaque changement (attribut, tag, joueur). Avec le streaming,
-- une pièce qui arrive pendant la course fait repartir le tapis au contrôle suivant.
--
-- API (pour les bancs) : TreadmillFxController.IsAnimating(model) -> boolean,
-- TreadmillFxController.ActiveCount() -> number.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local FX = require(Config:WaitForChild("TreadmillFX")) :: any
local Settings = require(Config:WaitForChild("Settings")) :: any

-- Contrat (10.4) et attributs posés par le serveur.
local TREADMILL_TAG = "Treadmill"
local PLOT_TAG = "PlayerPlot"
local OWNER_ATTRIBUTE = "OwnerUserId"
local MACHINE_ATTRIBUTE = "TrainingMachine"
local MACHINE_TREADMILL = "Treadmill"

type Step = (dt: number, t: number) -> ()
type Anim = {
	model: Instance,
	runner: Player,
	t: number,
	steps: { Step },
	saved: { { inst: Instance, prop: string, value: any } },
	savedKeys: { [Instance]: { [string]: boolean } },
	created: { Instance },
	conns: { RBXScriptConnection },
	dirty: boolean,
}

local TreadmillFxController = {}

local localPlayer = Players.LocalPlayer
local anims: { [Instance]: Anim } = {}
local activeCount = 0
local random = Random.new()
local refreshQueued = false

-- Outils --------------------------------------------------------------------------------------------

local function find(root: Instance, path: string): Instance?
	local current: Instance? = root
	for name in string.gmatch(path, "[^/]+") do
		if current == nil then
			return nil
		end
		current = (current :: Instance):FindFirstChild(name)
	end
	return current
end

local function save(anim: Anim, inst: Instance, prop: string)
	local keys = anim.savedKeys[inst]
	if keys == nil then
		keys = {}
		anim.savedKeys[inst] = keys
	end
	if not (keys :: { [string]: boolean })[prop] then
		(keys :: { [string]: boolean })[prop] = true
		table.insert(anim.saved, { inst = inst, prop = prop, value = (inst :: any)[prop] })
	end
end

local function set(anim: Anim, inst: Instance, prop: string, value: any)
	save(anim, inst, prop);
	(inst :: any)[prop] = value
end

local function pulse(omega: number, t: number): number
	return 0.5 + 0.5 * math.sin(omega * t)
end

local function addStep(anim: Anim, step: Step)
	table.insert(anim.steps, step)
end

-- Allume un émetteur éteint (Enabled = false) pendant la course.
local function emitterOn(anim: Anim, inst: Instance?)
	if inst ~= nil and inst:IsA("ParticleEmitter") then
		set(anim, inst, "Enabled", true)
	end
end

local function emit(inst: Instance?, count: number)
	if inst ~= nil and inst:IsA("ParticleEmitter") then
		inst:Emit(count)
	end
end

-- Lumière (PointLight, SpotLight, SurfaceLight) : luminosité calculée à chaque image.
local function lightStep(anim: Anim, inst: Instance?, value: (t: number) -> number)
	if inst ~= nil and inst:IsA("Light") then
		local light = inst :: Light
		save(anim, light, "Brightness")
		addStep(anim, function(_dt: number, t: number)
			light.Brightness = value(t)
		end)
	end
end

local function lightPulse(anim: Anim, inst: Instance?, spec: any)
	lightStep(anim, inst, function(t: number): number
		return spec.Min + (spec.Max - spec.Min) * pulse(spec.Omega, t)
	end)
end

-- Pièce dont la couleur va de sa couleur d'origine vers `to`, de amount(t) (0 à 1).
local function colorStep(anim: Anim, inst: Instance?, to: Color3, amount: (t: number) -> number)
	if inst ~= nil and inst:IsA("BasePart") then
		local part = inst :: BasePart
		save(anim, part, "Color")
		local from = part.Color
		addStep(anim, function(_dt: number, t: number)
			part.Color = from:Lerp(to, math.clamp(amount(t), 0, 1))
		end)
	end
end

-- Pièce qui tourne autour de l'axe Y du monde, sur place.
local function spinY(anim: Anim, inst: Instance?, speed: number)
	if inst ~= nil and inst:IsA("BasePart") then
		local part = inst :: BasePart
		save(anim, part, "CFrame")
		local base = part.CFrame
		addStep(anim, function(_dt: number, t: number)
			part.CFrame = CFrame.new(base.Position) * CFrame.Angles(0, speed * t, 0) * base.Rotation
		end)
	end
end

-- Copie le Trail d'un modèle de Clément (ex. PoliceFX.RunTrail) sur le HumanoidRootPart du coureur,
-- attaches en (−X, Y, Z) et (+X, Y, Z). La copie est détruite à l'arrêt ; l'original n'est pas touché.
local function copyTrail(anim: Anim, holder: Instance?, offset: Vector3)
	if holder == nil then
		return
	end
	local source = holder:FindFirstChildWhichIsA("Trail")
	local character = anim.runner.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if source == nil or root == nil then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Name = "TreadmillTrail0"
	a0.Position = Vector3.new(-offset.X, offset.Y, offset.Z)
	local a1 = Instance.new("Attachment")
	a1.Name = "TreadmillTrail1"
	a1.Position = offset
	local trail = source:Clone()
	trail.Name = "TreadmillTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Enabled = true
	a0.Parent = root
	a1.Parent = root
	trail.Parent = root
	table.insert(anim.created, trail)
	table.insert(anim.created, a0)
	table.insert(anim.created, a1)
end

-- Variantes -----------------------------------------------------------------------------------------

local function belt(anim: Anim, model: Instance, direction: number)
	local texture = find(model, "Belt/BeltTexture")
	if texture == nil or not texture:IsA("Texture") then
		return
	end
	local tex = texture :: Texture
	save(anim, tex, "OffsetStudsV")
	local start = tex.OffsetStudsV
	local tile = if tex.StudsPerTileV > 0 then tex.StudsPerTileV else 1
	addStep(anim, function(_dt: number, t: number)
		tex.OffsetStudsV = (start + direction * FX.BeltSpeed * t) % tile
	end)
end

local function gold(anim: Anim, model: Instance, fx: Instance)
	local c = FX.Gold
	emitterOn(anim, find(model, "Belt/RunBurstPoint/RunBurst"))
	for i = 1, 4 do
		spinY(anim, fx:FindFirstChild(`Halo{i}`), if i % 2 == 1 then -c.HaloSpeed else c.HaloSpeed)
	end
	lightPulse(anim, find(fx, "WingFX/WingLight"), c.WingLight)
	colorStep(anim, model:FindFirstChild("GoldGlow"), Color3.new(1, 1, 1), function(t: number): number
		return c.GlowTint * pulse(c.GlowOmega, t)
	end)
end

local function cashRegister(anim: Anim, model: Instance, fx: Instance)
	local c = FX.CashRegister
	emitterOn(anim, find(model, "Belt/RunBurstPoint/RunBurst"))
	emitterOn(anim, find(model, "Belt/RunBurstPoint/RunBurstCoins"))
	local bills = find(fx, "DrawerFX/Bills")
	if bills ~= nil and bills:IsA("ParticleEmitter") then
		set(anim, bills, "Rate", c.BillsRate)
	end
	for i = 1, 2 do
		local stream = find(fx, `PillarFX{i}/Stream`)
		if stream ~= nil and stream:IsA("Beam") then
			set(anim, stream, "TextureSpeed", c.StreamSpeed)
		end
	end
	lightPulse(anim, find(fx, "RegisterLight/Light"), c.RegisterLight)
	colorStep(anim, model:FindFirstChild("GlowMint"), Color3.new(1, 1, 1), function(t: number): number
		return c.GlowTint * pulse(c.GlowOmega, t)
	end)
end

-- Indice du flash en cours (1, 2…) dans le cycle des gyrophares, 0 hors flash.
local function policeFlash(phase: number): number
	local c = FX.Police
	for i, start in c.FlashStarts do
		if phase >= start and phase < start + c.FlashTime then
			return i
		end
	end
	return 0
end

local function police(anim: Anim, model: Instance, fx: Instance)
	local c = FX.Police
	emitterOn(anim, find(model, "Belt/RunBurstPoint/RunStreak"))
	copyTrail(anim, fx:FindFirstChild("RunTrail"), c.TrailOffset)
	spinY(anim, fx:FindFirstChild("Sweep_red"), c.SweepSpeed)
	spinY(anim, fx:FindFirstChild("Sweep_blue"), -c.SweepSpeed)

	local function side(sirenName: string, lightName: string, flares: { string }, offset: number)
		local siren = model:FindFirstChild(sirenName)
		local full: Color3? = nil
		if siren ~= nil and siren:IsA("BasePart") then
			save(anim, siren, "Color")
			full = siren.Color
		end
		local light = find(fx, `{lightName}/Light`)
		if light ~= nil and light:IsA("Light") then
			save(anim, light, "Brightness")
		else
			light = nil
		end
		local last = -1 -- premier pas : sirène pleine ou assombrie tout de suite
		addStep(anim, function(_dt: number, t: number)
			local index = policeFlash((t - offset) % c.Cycle)
			if index ~= last then
				last = index
				local on = index ~= 0
				if full ~= nil then
					local color = full :: Color3;
					(siren :: BasePart).Color = if on
						then color
						else Color3.new(color.R * c.DimFactor, color.G * c.DimFactor, color.B * c.DimFactor)
				end
				if light ~= nil then
					(light :: Light).Brightness = if on then c.LightOn else 0
				end
				if on then
					for _, name in flares do
						emit(find(fx, `{name}/Flare`), 1)
					end
				end
			end
		end)
	end
	side("SirenRed", "Light_red", { "FlareR1", "FlareR2" }, 0)
	side("SirenBlue", "Light_blue", { "FlareB1", "FlareB2" }, c.BlueOffset)
end

local function laserVault(anim: Anim, model: Instance, fx: Instance)
	local c = FX.LaserVault
	emitterOn(anim, find(model, "Belt/RunBurstPoint/RunCoins"))
	local function alarm(t: number): number
		return math.max(0, math.sin(c.AlarmRate * t)) ^ 2
	end
	local glow = model:FindFirstChild("AlarmGlow")
	if glow ~= nil and glow:IsA("BasePart") then
		local part = glow :: BasePart
		save(anim, part, "Color")
		addStep(anim, function(_dt: number, t: number)
			part.Color = c.AlarmLow:Lerp(c.AlarmHigh, alarm(t))
		end)
	end
	for i = 1, 3 do
		local holder = fx:FindFirstChild(`Alarm{i}`)
		if holder == nil then
			continue
		end
		lightStep(anim, holder:FindFirstChild("Light"), function(t: number): number
			return c.AlarmLight * alarm(t)
		end)
		local flash = holder:FindFirstChild("Flash")
		local lastFlash = -math.huge
		addStep(anim, function(_dt: number, t: number)
			if alarm(t) > c.FlashAbove and t - lastFlash >= c.FlashGap then
				lastFlash = t
				emit(flash, 1)
			end
		end)
	end
	for i = 1, 9 do
		local beam = find(fx, `Laser{i}/Beam`)
		if beam ~= nil and beam:IsA("Beam") then
			local b = beam :: Beam
			save(anim, b, "Transparency")
			addStep(anim, function()
				b.Transparency = NumberSequence.new(random:NextNumber(c.BeamFlicker.Min, c.BeamFlicker.Max))
			end)
		end
	end
	local laserBeams = model:FindFirstChild("LaserBeams")
	if laserBeams ~= nil and laserBeams:IsA("BasePart") then
		local part = laserBeams :: BasePart
		save(anim, part, "Transparency")
		addStep(anim, function()
			part.Transparency = random:NextNumber(c.LaserBeamsFlicker.Min, c.LaserBeamsFlicker.Max)
		end)
	end
	local gate = fx:FindFirstChild("ScanGate")
	if gate ~= nil and gate:IsA("BasePart") then
		local part = gate :: BasePart
		save(anim, part, "CFrame")
		local pivot = (model :: Model):GetPivot()
		local rel = pivot:ToObjectSpace(part.CFrame)
		local g = c.ScanGate
		addStep(anim, function(_dt: number, t: number)
			local y = g.Center + g.Amplitude * math.cos(g.Omega * t)
			part.CFrame = pivot * CFrame.new(rel.Position.X, y, rel.Position.Z) * rel.Rotation
		end)
	end
	for i = 1, 2 do
		local cam = fx:FindFirstChild(`CamScan{i}`)
		if cam ~= nil and cam:IsA("BasePart") then
			local part = cam :: BasePart
			save(anim, part, "CFrame")
			local base = part.CFrame
			local s = c.CamScan
			addStep(anim, function(_dt: number, t: number)
				part.CFrame = base * CFrame.Angles(0, s.Amplitude * math.sin(s.Omega * t + s.Phase * i), 0)
			end)
		end
	end
end

local function ice(anim: Anim, model: Instance, fx: Instance)
	local c = FX.Ice
	emitterOn(anim, find(model, "Belt/RunBurstPoint/RunBurst"))
	local arrows = model:FindFirstChild("BeltArrows")
	if arrows ~= nil and arrows:IsA("BasePart") then
		local part = arrows :: BasePart
		save(anim, part, "Transparency")
		local a = c.ArrowsTransparency
		addStep(anim, function(_dt: number, t: number)
			part.Transparency = a.Min + (a.Max - a.Min) * pulse(c.GlowOmega, t)
		end)
	end
	colorStep(anim, model:FindFirstChild("CrystalGlow"), Color3.new(1, 1, 1), function(t: number): number
		return c.GlowTint * pulse(c.GlowOmega, t)
	end)
	lightPulse(anim, find(fx, "CrownLight/CrownLight"), c.CrownLight)
	spinY(anim, fx:FindFirstChild("FrostRing"), c.FrostRingSpeed)
end

local function toxic(anim: Anim, model: Instance, fx: Instance)
	local c = FX.Toxic
	emitterOn(anim, find(model, "Belt/RunBurstPoint/RunSplash"))
	copyTrail(anim, fx:FindFirstChild("RunTrail"), c.TrailOffset)
	colorStep(anim, model:FindFirstChild("ToxicGoo"), c.Goo.To, function(t: number): number
		return c.Goo.Amount * pulse(c.Goo.Omega, t)
	end)
	lightPulse(anim, find(fx, "GooLight/Light"), c.GooLight)
	colorStep(anim, model:FindFirstChild("BeltArrows"), c.Arrows.To, function(t: number): number
		return pulse(c.Arrows.Omega, t)
	end)
	for i = 1, 2 do
		local phase = (i - 1) * 1.3 -- V0 : les deux lanternes ne vacillent pas ensemble
		lightStep(anim, find(fx, `Lantern{i}/Light`), function(t: number): number
			local l = c.Lantern
			return l.Base + l.Amplitude * math.sin(l.Omega * t + phase) + random:NextNumber(-l.Noise, l.Noise)
		end)
	end
end

local function candy(anim: Anim, model: Instance, fx: Instance)
	local c = FX.Candy
	emitterOn(anim, find(model, "Belt/RunBurstPoint/RunPops"))
	emitterOn(anim, find(model, "Belt/RunBurstPoint/RunPuff"))
	copyTrail(anim, fx:FindFirstChild("RunTrail"), c.TrailOffset)
	-- Menthe : axe avant-arrière (Z du tapis) passant par PeppermintCenter ; angle positif autour de +Z =
	-- sens horaire vu de l'avant (l'avant du tapis regarde vers −Z).
	local center = (model :: Model):GetPivot() * CFrame.new(c.PeppermintCenter)
	for _, name in { "Peppermint", "PeppermintSwirl" } do
		local inst = model:FindFirstChild(name)
		if inst ~= nil and inst:IsA("BasePart") then
			local part = inst :: BasePart
			save(anim, part, "CFrame")
			local rel = center:ToObjectSpace(part.CFrame)
			addStep(anim, function(_dt: number, t: number)
				part.CFrame = center * CFrame.Angles(0, 0, c.PeppermintSpeed * t) * rel
			end)
		end
	end
	colorStep(anim, model:FindFirstChild("CandyGlow"), c.Glow.To, function(t: number): number
		return c.Glow.Amount * pulse(c.Glow.Omega, t)
	end)
	lightPulse(anim, find(fx, "SprinkleArch/Light"), c.SprinkleLight)
	colorStep(anim, model:FindFirstChild("BeltArrows"), c.Arrows.To, function(t: number): number
		return pulse(c.Arrows.Omega, t)
	end)
	local poppers: { Instance } = {}
	for i = 1, 6 do
		local pop = find(fx, `Popper{i}/Pop`)
		if pop ~= nil then
			table.insert(poppers, pop)
		end
	end
	if #poppers > 0 then
		local nextPop = random:NextNumber(c.PopGap.Min, c.PopGap.Max)
		addStep(anim, function(_dt: number, t: number)
			if t >= nextPop then
				nextPop = t + random:NextNumber(c.PopGap.Min, c.PopGap.Max)
				emit(poppers[random:NextInteger(1, #poppers)], c.PopCount)
			end
		end)
	end
end

local function fire(anim: Anim, model: Instance, fx: Instance)
	local c = FX.Fire
	emitterOn(anim, find(model, "Belt/RunBurstPoint/RunBurst"))
	local function flicker(t: number): number
		return 0.5 * math.sin(11 * t) + 0.3 * math.sin(23 * t) + 0.2 * math.sin(5 * t)
	end
	lightStep(anim, find(fx, "Brazier1/Light"), function(t: number): number
		return c.Brazier.Base + c.Brazier.Amplitude * flicker(t)
	end)
	lightStep(anim, find(fx, "Brazier2/Light"), function(t: number): number
		return c.Brazier.Base - c.Brazier.Amplitude * flicker(t)
	end)
	local ember = model:FindFirstChild("EmberGlow")
	if ember ~= nil and ember:IsA("BasePart") then
		local part = ember :: BasePart
		save(anim, part, "Color")
		addStep(anim, function(_dt: number, t: number)
			part.Color = c.EmberFrom:Lerp(c.EmberTo, math.clamp(c.EmberBase + c.EmberAmount * flicker(t), 0, 1))
		end)
	end
end

-- Dossier d'effets → animation de la variante. Sans dossier connu : la bande seule.
local VARIANTS: { { folder: string, build: (Anim, Instance, Instance) -> () } } = {
	{ folder = "GoldFX", build = gold },
	{ folder = "CashFX", build = cashRegister },
	{ folder = "PoliceFX", build = police },
	{ folder = "LaserVaultFX", build = laserVault },
	{ folder = "IceFX", build = ice },
	{ folder = "ToxicFX", build = toxic },
	{ folder = "CandyFX", build = candy },
	{ folder = "FireFX", build = fire },
}

-- Marche et arrêt ------------------------------------------------------------------------------------

local function stop(model: Instance)
	local anim = anims[model]
	if anim == nil then
		return
	end
	anims[model] = nil
	activeCount -= 1
	for _, conn in anim.conns do
		conn:Disconnect()
	end
	for i = #anim.saved, 1, -1 do
		local entry = anim.saved[i]
		pcall(function()
			(entry.inst :: any)[entry.prop] = entry.value
		end)
	end
	for _, inst in anim.created do
		inst:Destroy()
	end
end

local function start(model: Instance, runner: Player)
	local anim: Anim = {
		model = model,
		runner = runner,
		t = 0,
		steps = {},
		saved = {},
		savedKeys = {},
		created = {},
		conns = {},
		dirty = false,
	}
	anims[model] = anim
	activeCount += 1
	local reversed = model:FindFirstChild("CandyFX") ~= nil -- Candy : OffsetStudsV diminue
	belt(anim, model, if reversed then -1 else 1)
	if not Settings.VfxReduced(localPlayer) then
		for _, variant in VARIANTS do
			local fx = model:FindFirstChild(variant.folder)
			if fx ~= nil then
				local ok, err = pcall(function(): any
					variant.build(anim, model, fx)
					return nil
				end)
				if not ok then
					warn(`[TreadmillFx] {variant.folder} : {err}`)
				end
				break
			end
		end
	end
	-- Streaming : une pièce qui arrive pendant la course fait repartir le tapis au contrôle suivant.
	table.insert(
		anim.conns,
		model.DescendantAdded:Connect(function(inst: Instance)
			if inst.Name ~= "TreadmillTrail" then
				anim.dirty = true
			end
		end)
	)
	-- Premier état tout de suite (t = 0) : couleurs et lumières de course dès la montée.
	for _, step in anim.steps do
		step(0, 0)
	end
end

-- Tapis (tag Treadmill, dans Workspace) de la parcelle dont `player` est propriétaire.
local function treadmillOf(player: Player): Instance?
	for _, plot in CollectionService:GetTagged(PLOT_TAG) do
		if plot:GetAttribute(OWNER_ATTRIBUTE) == player.UserId and plot:IsDescendantOf(Workspace) then
			for _, treadmill in CollectionService:GetTagged(TREADMILL_TAG) do
				if treadmill:IsA("Model") and treadmill:IsDescendantOf(plot) then
					return treadmill
				end
			end
		end
	end
	return nil
end

local function isNear(model: Instance): boolean
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return true
	end
	local pivot = (model :: Model):GetPivot() -- treadmillOf ne renvoie que des Model
	return (pivot.Position - camera.CFrame.Position).Magnitude <= FX.ActiveDistance
end

local function refresh()
	local wanted: { [Instance]: Player } = {}
	for _, player in Players:GetPlayers() do
		if player:GetAttribute(MACHINE_ATTRIBUTE) == MACHINE_TREADMILL then
			local treadmill = treadmillOf(player)
			if treadmill ~= nil and isNear(treadmill) then
				wanted[treadmill] = player
			end
		end
	end
	for model, anim in anims do
		if wanted[model] ~= anim.runner or anim.dirty or not model:IsDescendantOf(Workspace) then
			stop(model)
		end
	end
	for model, runner in wanted do
		if anims[model] == nil then
			start(model, runner)
		end
	end
end

local function requestRefresh()
	if refreshQueued then
		return
	end
	refreshQueued = true
	task.defer(function()
		refreshQueued = false
		refresh()
	end)
end

local function stopAll()
	for model in anims do
		stop(model)
	end
end

function TreadmillFxController.IsAnimating(model: Instance): boolean
	return anims[model] ~= nil
end

function TreadmillFxController.ActiveCount(): number
	return activeCount
end

function TreadmillFxController.Start()
	local function watchPlayer(player: Player)
		player:GetAttributeChangedSignal(MACHINE_ATTRIBUTE):Connect(requestRefresh)
	end
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(requestRefresh)
	CollectionService:GetInstanceAddedSignal(TREADMILL_TAG):Connect(requestRefresh)
	CollectionService:GetInstanceRemovedSignal(TREADMILL_TAG):Connect(requestRefresh)
	-- VISUAL EFFECTS : tout repart avec le nouveau réglage.
	localPlayer:GetAttributeChangedSignal(Settings.VfxAttribute):Connect(function()
		stopAll()
		refresh()
	end)

	local sinceCheck = 0
	RunService.Heartbeat:Connect(function(dt: number)
		sinceCheck += dt
		if sinceCheck >= FX.CheckInterval then
			sinceCheck = 0
			refresh()
		end
		if activeCount == 0 then
			return
		end
		for _, anim in anims do
			anim.t += dt
			for _, step in anim.steps do
				step(dt, anim.t)
			end
		end
	end)
	refresh()
end

return TreadmillFxController
