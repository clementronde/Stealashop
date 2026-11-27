-- Tapis Gold : comparaison « actuel » contre « nouveau », avec les effets de course (chef VFX et son, 26/11, v2)
-- À coller dans la barre de commande de Studio, en Edit. Aucun script n'est laissé dans les modèles.
-- Construit Workspace/_PROTO_TAPIS, loin de la map :
--   - à droite de face : une copie de ReplicatedStorage/Assets/Plots/PLOT_Treadmill_Gold (l'actuel, tel quel) ;
--   - à gauche de face : une copie de ServerStorage/Previews/TREADMILLS/<SOURCE> (chef 3D), avec les effets ci-dessous ;
--   - un mannequin R15 sur chaque bande, face à la console.
-- Les originaux ne sont jamais modifiés. Pour tout retirer : workspace._PROTO_TAPIS:Destroy().
--
-- Effets du nouveau Gold (retour de Clément du 26/11 : « manque d'effet, de cohérence, de texture ») ;
-- v3 : le meilleur du pack Claude Design (ses textures, ses rayons et son ruban) avec notre méthode (aucun script,
-- attributs lus par le code, budget de l'étage 2) :
--   Frame/SunCenter/SunRays    couronne de 12 rayons qui tourne à 14°/s derrière le disque (2 copies en fondu croisé)
--   Frame/SunCenter/LightBeam  ruban de lumière qui monte de 7 studs (Beam, aucune particule ; seulement avec l'ID du pack)
--   Frame/SunCenter/ArchHalo   halo doré doux derrière le disque (plus fort en course : RunRate)
--   GoldFX/PorticoSparkle      étincelles dans tout le volume du linteau (une Part invisible, 3/s, 4/s en course)
--   Belt/RunBurstPoint/StepGlint  éclat à plat sous les pieds à chaque gain (texture RunBurst du pack, 0,35 s)
--   Belt/RunBurstPoint/RunStep    1 pièce d'or qui saute et tourne à chaque gain (StepEmit 1)
--   Belt/RunBurstPoint/RunBurst   gerbe existante, allégée (Rate 6, RunOnly)
--   GoldGlow : le néon pulse au rythme des gains (code : attributs PulseOnStep, PulseTint, PulseTime) ;
--   la capture le montre à son pic.
-- Budget de l'étage 2 : 20 particules vivantes en course. Les effets existants du GoldFX sont allégés pour y tenir.

local SOURCE = "PLOT_Treadmill_Gold_v3" -- la v3 du chef 3D (ServerStorage/Previews/TREADMILLS)
local ORIGIN = CFrame.new(-3000, 0, 6600)
local GAP = 9
local GAINS_PER_SECOND = 6 -- Config/TreadmillFX.GainPops.PerSecond

local Players = game:GetService("Players")
-- v3 (26/11) : textures du pack Claude Design du Gold (FX/Treadmill_Gold, 5 PNG à publier au nom du groupe).
-- ID d'IMAGE (lus par LoadAsset sur les Decals publiés par Clément le 26/11, groupe RoundStone Studio).
-- Tant qu'un ID est vide, l'ancienne texture sert.
local PACK = {
	SunRays = "rbxassetid://99364704655291", -- Decal 138734350300592 ; FX_Treadmill_Gold_SunRays : couronne de 12 rayons derrière le disque solaire
	LightBeam = "rbxassetid://109649353002293", -- Decal 138977617329750 ; FX_Treadmill_Gold_LightBeam : ruban de lumière vertical (Beam)
	Sparkle = "rbxassetid://138001567239074", -- Decal 114389171304750 ; FX_Treadmill_Gold_Sparkle : étincelle à 4 branches
	RunBurst = "rbxassetid://131021212965898", -- Decal 95873646500606 ; FX_Treadmill_Gold_RunBurst : éclat à plat sous les pieds
	Feather = "rbxassetid://132507699353884", -- Decal 74210646190918 ; FX_Treadmill_Gold_Feather : plume des ailes
}
local function tex(key: string, fallback: string): string
	local id = (PACK :: any)[key]
	return if type(id) == "string" and id ~= "" then id else fallback
end
local TEX_SPARKLE = tex("Sparkle", "rbxassetid://127314074011197") -- sinon l'étoile du Gold actuel
local TEX_GLOW = "rbxassetid://71001560516016" -- lueur du Gold actuel (FX_Treadmill_Gold_Glow)
local TEX_RAYS = tex("SunRays", "rbxassetid://70682642272028") -- sinon FX_UI_Rays
local TEX_BURST = tex("RunBurst", TEX_SPARKLE)
local TEX_COIN = "rbxassetid://93580691646372" -- pièce de CashRegister
local SUN = Vector3.new(0, 9.05, -3.95) -- centre du disque solaire (repère du tapis, pack Claude Design)

local old = workspace:FindFirstChild("_PROTO_TAPIS")
if old then old:Destroy() end
local root = Instance.new("Folder")
root.Name = "_PROTO_TAPIS"
root.Parent = workspace

local ground = Instance.new("Part")
ground.Name = "Sol"
ground.Anchored = true
ground.Size = Vector3.new(60, 1, 40)
ground.CFrame = ORIGIN * CFrame.new(0, -0.5, 0)
ground.Color = Color3.fromRGB(110, 150, 95)
ground.Material = Enum.Material.Grass
ground.Parent = root

local function place(src: Model, name: string, x: number): Model
	local m = src:Clone()
	m.Name = name
	m:PivotTo(ORIGIN * CFrame.new(x, 0, 0))
	m.Parent = root
	return m
end

local current = place(game.ReplicatedStorage.Assets.Plots.PLOT_Treadmill_Gold, "Gold_Actuel", -GAP)
local nouveau = place(game.ServerStorage.Previews.TREADMILLS[SOURCE], "Gold_Nouveau", GAP)

local function seq(points: { { number } }): NumberSequence
	local kps = {}
	for _, p in points do
		table.insert(kps, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0))
	end
	return NumberSequence.new(kps)
end
local GOLD = ColorSequence.new(Color3.fromRGB(255, 226, 120), Color3.fromRGB(255, 190, 60))

local function emitter(parent: Instance, name: string, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	for k, v in props do
		if k:sub(1, 1) == "@" then e:SetAttribute(k:sub(2), v) else (e :: any)[k] = v end
	end
	e.Parent = parent
	return e
end

-- Points d'accroche (chef 3D) ------------------------------------------------------------------------
local frame = nouveau:FindFirstChild("Frame")
local arch = frame and frame:FindFirstChild("ArchTop")
local point = nouveau:FindFirstChild("Belt") and nouveau.Belt:FindFirstChild("RunBurstPoint")
assert(arch and point, "Frame/ArchTop ou Belt/RunBurstPoint absent")

-- Soleil : couronne de rayons qui tourne lentement derrière le disque (pack : 2 copies en fondu croisé, jamais de saut),
-- ruban de lumière qui monte (Beam, 0 particule), halo doux (l'ancien ArchHalo, plus discret)
local sun = Instance.new("Attachment")
sun.Name = "SunCenter" -- à poser par le chef 3D dans Frame sur la série (centre du disque solaire)
sun.Position = (frame :: BasePart).CFrame:PointToObjectSpace(nouveau:GetPivot():PointToWorldSpace(SUN))
sun.Parent = frame
local rays = emitter(sun, "SunRays", {
	Texture = TEX_RAYS, Rate = 1 / 8, Lifetime = NumberRange.new(16), Speed = NumberRange.new(0),
	LockedToPart = true, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(14),
	Size = NumberSequence.new(5.2), Transparency = seq({ { 0, 1 }, { 0.12, 0.25 }, { 0.88, 0.25 }, { 1, 1 } }),
	LightEmission = 0.8, LightInfluence = 0, ZOffset = -1.4,
})
rays:Emit(1)
emitter(sun, "ArchHalo", {
	Texture = TEX_GLOW, Rate = 0.4, ["@RunRate"] = 0.5, Lifetime = NumberRange.new(2.4, 2.8),
	Speed = NumberRange.new(0), LockedToPart = true, ZOffset = -1.6,
	Size = seq({ { 0, 3.5 }, { 0.5, 4.2 }, { 1, 3.5 } }),
	Transparency = seq({ { 0, 1 }, { 0.3, 0.6 }, { 0.7, 0.6 }, { 1, 1 } }),
	Color = GOLD, LightEmission = 0.7, LightInfluence = 0, Brightness = 1.2,
})
local beamTex = (PACK :: any).LightBeam
if beamTex ~= "" then
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Name, a1.Name = "BeamBase", "BeamTop"
	a0.Position, a1.Position = Vector3.new(0, 0.85, 0), Vector3.new(0, 7.85, 0)
	a0.Parent, a1.Parent = sun, sun
	local b = Instance.new("Beam")
	b.Name = "LightBeam"
	b.Attachment0, b.Attachment1 = a0, a1
	b.Texture = beamTex
	b.TextureMode = Enum.TextureMode.Wrap
	b.TextureLength, b.TextureSpeed = 7, 0.5
	b.Width0, b.Width1 = 1.5, 0.5
	b.FaceCamera = true
	b.Color = ColorSequence.new(Color3.fromRGB(255, 235, 176))
	b.Transparency = seq({ { 0, 0.35 }, { 0.7, 0.7 }, { 1, 1 } })
	b.LightEmission, b.LightInfluence = 1, 0
	b.Parent = sun
end
-- Portique : étincelles qui scintillent dans tout le volume du linteau (une Part invisible, pas un point)
local portico = Instance.new("Part")
portico.Name = "PorticoSparkle"
portico.Anchored, portico.CanCollide, portico.CanQuery, portico.CanTouch, portico.CastShadow = true, false, false, false, false
portico.Transparency = 1
portico.Size = Vector3.new(10, 3.2, 2.4)
portico.CFrame = nouveau:GetPivot() * CFrame.new(0, 8.6, -3.95)
portico.Parent = nouveau:FindFirstChild("GoldFX") or nouveau
emitter(portico, "ArchSparkle", {
	Texture = TEX_SPARKLE, Rate = 3, ["@RunRate"] = 3, Lifetime = NumberRange.new(0.6, 1.1),
	Speed = NumberRange.new(0, 0.3), Rotation = NumberRange.new(0, 90), RotSpeed = NumberRange.new(-120, 120),
	Size = seq({ { 0, 0 }, { 0.5, 0.55 }, { 1, 0 } }), Transparency = seq({ { 0, 0 }, { 1, 0.2 } }),
	Color = GOLD, LightEmission = 0.6, LightInfluence = 0, Brightness = 2,
})

-- Bande : éclat à plat sous les pieds à chaque gain, pièce au gain, gerbe allégée
emitter(point, "StepGlint", {
	Texture = TEX_BURST, Rate = 0, ["@StepEmit"] = 1, Lifetime = NumberRange.new(0.35),
	Speed = NumberRange.new(0.05), EmissionDirection = Enum.NormalId.Top,
	Orientation = Enum.ParticleOrientation.VelocityPerpendicular, Rotation = NumberRange.new(0, 360),
	Size = seq({ { 0, 0.8 }, { 1, 3.2 } }), Transparency = seq({ { 0, 0 }, { 0.6, 0.3 }, { 1, 1 } }),
	Color = GOLD, LightEmission = 0.6, LightInfluence = 0, Brightness = 2, ZOffset = 0.6,
})
emitter(point, "RunStep", {
	Texture = TEX_COIN, Rate = 0, ["@StepEmit"] = 1, Lifetime = NumberRange.new(0.8, 1),
	-- v3 : plus haut, au-dessus du coureur (chef 3D : « la pièce se lit à peine »)
	Speed = NumberRange.new(12, 15), SpreadAngle = Vector2.new(40, 30), EmissionDirection = Enum.NormalId.Top,
	Acceleration = Vector3.new(0, -32, 0), Drag = 0.5,
	Size = seq({ { 0, 0.35 }, { 0.12, 0.8 }, { 0.8, 0.72 }, { 1, 0 } }),
	Transparency = seq({ { 0, 0 }, { 0.8, 0 }, { 1, 1 } }),
	Color = ColorSequence.new(Color3.fromRGB(230, 170, 60)), -- un peu plus foncé que le tapis doré, pour se détacher
	-- la pièce tourne sur elle-même : Squash qui ondule
	Squash = seq({ { 0, 0 }, { 0.1, 0.7 }, { 0.2, 0 }, { 0.3, 0.7 }, { 0.4, 0 }, { 0.5, 0.7 }, { 0.6, 0 }, { 0.7, 0.7 }, { 0.8, 0 }, { 0.9, 0.7 }, { 1, 0 } }),
	Rotation = NumberRange.new(-20, 20), RotSpeed = NumberRange.new(-90, 90),
	LightEmission = 0, LightInfluence = 0.8, Brightness = 1.4, ZOffset = 0.2,
})
local burst = point:FindFirstChild("RunBurst")
if burst and burst:IsA("ParticleEmitter") then
	burst.Rate = 3.5 -- v3 : 6 → 4 pour tenir 20 avec les rayons et le portique
	burst:SetAttribute("RunOnly", true)
end

-- Existant allégé pour tenir le budget
local fx = nouveau:FindFirstChild("GoldFX")
if fx then
	for _, n in { "ColSparkle1", "ColSparkle2", "ColSparkle3", "ColSparkle4" } do
		local holder = fx:FindFirstChild(n)
		local s = holder and holder:FindFirstChild("Sparkle")
		if s and s:IsA("ParticleEmitter") then
			s.Rate = if n == "ColSparkle3" or n == "ColSparkle4" then 0.5 else 1
			s.Texture = TEX_SPARKLE
		end
	end
	local wing = fx:FindFirstChild("WingFX")
	if wing then
		local feather = wing:FindFirstChild("Feather")
		if feather and feather:IsA("ParticleEmitter") then
			feather.Rate = 0.3
			feather.Texture = tex("Feather", feather.Texture)
		end
		local ws = wing:FindFirstChild("Sparkle")
		if ws and ws:IsA("ParticleEmitter") then
			ws.Rate = 1.5
			ws.Texture = TEX_SPARKLE
		end
	end
end

-- Néon qui pulse au rythme des gains (lu par le code ; la capture montre le pic)
local glow = nouveau:FindFirstChild("GoldGlow")
if glow then
	glow:SetAttribute("PulseOnStep", true) -- à chaque apparition du gain
	glow:SetAttribute("PulseTint", 0.45) -- vers le blanc de 0,45 au pic
	glow:SetAttribute("PulseTime", 0.15) -- retour en 0,15 s, Quad Out
end

-- Mannequins R15 --------------------------------------------------------------------------------------
local function dummy(m: Model)
	local use = m:FindFirstChild("Belt") and m.Belt:FindFirstChild("UsePoint")
	local ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if not ok or not rig then return end
	local anim = rig:FindFirstChild("Animate")
	if anim then anim:Destroy() end
	rig.Name = "Mannequin"
	local hum = rig:WaitForChild("Humanoid") :: Humanoid
	local hrp = rig:WaitForChild("HumanoidRootPart") :: BasePart
	local base = if use then use.WorldCFrame else m:GetPivot()
	rig:PivotTo(CFrame.new(base.Position + Vector3.new(0, hum.HipHeight + hrp.Size.Y / 2, 0))) -- face à la console (−Z)
	for _, p in rig:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			local n = p.Name
			p.Color = if n:match("Torso") or n:match("Arm") then Color3.fromRGB(40, 90, 200)
				elseif n:match("Leg") or n:match("Foot") then Color3.fromRGB(70, 120, 60)
				else Color3.fromRGB(234, 190, 150)
			if n:match("Hand") then p.Color = Color3.fromRGB(234, 190, 150) end
		end
	end
	rig.Parent = m
end
dummy(current)
dummy(nouveau)

-- Coût -------------------------------------------------------------------------------------------------
local function cost(m: Model): (number, number)
	local idle, run = 0, 0
	for _, d in m:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			local life = (d.Lifetime.Min + d.Lifetime.Max) / 2
			local runOnly = d:GetAttribute("RunOnly") == true or (d.Parent and d.Parent.Name == "RunBurstPoint" and not d.Enabled)
			local runRate = d:GetAttribute("RunRate") or d.Rate
			if not runOnly then idle += d.Rate * life end
			run += runRate * life + (d:GetAttribute("StepEmit") or 0) * GAINS_PER_SECOND * life
		end
	end
	return idle, run
end
local i1, r1 = cost(current)
local i2, r2 = cost(nouveau)
print(string.format("[_PROTO_TAPIS] Gold actuel : repos %.1f, course %.1f ; nouveau : repos %.1f, course %.1f (étage 2 : 20)", i1, r1, i2, r2))

-- Simulation de la course pour la capture (Edit) : _G.__protoTapisRun() allume, émet 1,5 s de gains, fige.
_G.__protoTapisRun = function()
	for _, d in root:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			d.TimeScale = 1
			d:Clear()
			if d:GetAttribute("RunOnly") or (d.Parent.Name == "RunBurstPoint" and d:GetAttribute("StepEmit") == nil) then d.Enabled = true end
			local rr = d:GetAttribute("RunRate")
			if rr then d.Rate = rr end
		end
	end
	if glow then glow.Color = glow.Color:Lerp(Color3.new(1, 1, 1), 0.45) end
	-- halo : quelques secondes d'avance pour qu'il soit déjà là
	local halo = sun:FindFirstChild("ArchHalo")
	if halo and halo:IsA("ParticleEmitter") then halo:Emit(2) end
	for _ = 1, 9 do
		for _, d in nouveau:GetDescendants() do
			if d:IsA("ParticleEmitter") and d:GetAttribute("StepEmit") then d:Emit(d:GetAttribute("StepEmit")) end
		end
		task.wait(1 / GAINS_PER_SECOND)
	end
	for _, d in root:GetDescendants() do
		if d:IsA("ParticleEmitter") then d.TimeScale = 0 end
	end
end
