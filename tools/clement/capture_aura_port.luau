-- Captures des 3 pistes « l'aura gâche l'objet porté » (chef VFX et son, 27/11), en Edit, sans Play, avec le jeton.
-- Rien n'est touché dans Assets : on copie l'aura sur des R15 de capture comme le fait CosmeticService (chaque
-- Attachment du modèle FX_Aura_<Nom> sur la pièce du corps qui porte le même nom que son parent), puis on règle
-- les copies selon la piste. Pistes : side-session-notes/aura-objet-porte-pistes.md.
--   _G.CAP.setup("Flamme")  4 R15 côte à côte dans Workspace/_CAPTURE_Aura : aujourd'hui, A, B, C ;
--                            chacun en pose CarryIdle, avec un objet dans les mains ; rend le CFrame de caméra conseillé
--   _G.CAP.clean()           retire la scène et remet la caméra
local Players = game:GetService("Players")
local CAP = {}
_G.CAP = CAP
local ORIGIN = Vector3.new(-300, 400, -300)
local GAP = 7

-- L'objet volé est porté AU-DESSUS DE LA TÊTE (CarryService, Balance.Carry.HeadGap 0,25), bras levés (CarryIdle).
-- Piste A : éteint ce qui est dans les mains (levées, collées à l'objet) et au-dessus de la tête ; baisse le reste du haut.
local OFF_A = { "Poing", "Arcs", "Couronne", "ColonneHaut", "Ciel", "HaloGlow", "Eye", "Tete", "Shine" }
local DIM_A = { "Coeur", "Lumiere", "Dos", "RisingAura", "Flames", "Foyer", "Colonne", "Orbite", "Filament", "Wing", "Rise" }
-- Piste C : ne garde que le sol et les pieds.
local KEEP_C = { "Sol", "Ground", "Pied", "Feet", "Dust", "Mist", "Ghost" }
local function has(name: string, list: { string }): boolean
	for _, k in list do if name:find(k) then return true end end
	return false
end

local function rig(at: Vector3): Model
	local m = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	local a = m:FindFirstChild("Animate")
	if a then a:Destroy() end
	local hum = m:WaitForChild("Humanoid") :: Humanoid
	local hrp = m:WaitForChild("HumanoidRootPart") :: BasePart
	m:PivotTo(CFrame.new(at + Vector3.new(0, hum.HipHeight + hrp.Size.Y / 2, 0)) * CFrame.Angles(0, math.pi, 0))
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = (p == hrp)
			local n = p.Name
			p.Color = if n:match("Torso") or n:match("UpperArm") then Color3.fromRGB(30, 30, 34)
				elseif n:match("Leg") or n:match("Foot") then Color3.fromRGB(46, 92, 52)
				else Color3.fromRGB(234, 190, 150)
		end
	end
	return m
end

-- pose CarryIdle (animation de Clément). En Edit, l'Animator n'avance que si on laisse passer des images entre deux
-- StepAnimations (et le modèle doit déjà être dans Workspace) : 0,6 s, puis on fige.
local function pose(m: Model)
	local folder = game.ReplicatedStorage.Assets:FindFirstChild("Animations")
	local player = folder and folder:FindFirstChild("Player")
	local anim = player and player:FindFirstChild("CarryIdle")
	local hum = m:FindFirstChildOfClass("Humanoid")
	if not (anim and anim:IsA("Animation") and hum) then return end
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = hum
	local track = animator:LoadAnimation(anim)
	track:Play(0, 1, 1)
	local t0 = os.clock()
	while os.clock() - t0 < 0.6 do
		animator:StepAnimations(1 / 60)
		task.wait()
	end
	track:AdjustSpeed(0)
end

-- un objet exposé du jeu, posé 0,25 stud au-dessus du haut de la tête, comme CarryService
local function item(m: Model, source: Model)
	local head = m:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) then return end
	local c = source:Clone()
	for _, d in c:GetDescendants() do
		if d:IsA("LuaSourceContainer") then d:Destroy() elseif d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false end
	end
	local cf, size = c:GetBoundingBox()
	local bottom = head.Position + Vector3.new(0, head.Size.Y / 2 + 0.25, 0)
	local target = CFrame.new(bottom + Vector3.new(0, size.Y / 2, 0)) * CFrame.Angles(0, math.pi, 0)
	c:PivotTo(target * cf:Inverse() * c:GetPivot())
	c.Parent = m
end

-- copie de l'aura comme CosmeticService : chaque Attachment va sur la pièce du corps du même nom que son parent
local function aura(m: Model, src: Model)
	for _, at in src:GetDescendants() do
		if at:IsA("Attachment") and at.Parent then
			local part = m:FindFirstChild(at.Parent.Name)
			if part and part:IsA("BasePart") then
				local copy = at:Clone()
				copy:SetAttribute("CosmeticFx", true)
				copy.Parent = part
			end
		end
	end
end

local function variant(m: Model, kind: string)
	for _, at in m:GetDescendants() do
		if at:IsA("Attachment") and at:GetAttribute("CosmeticFx") then
			local off = (kind == "A" and has(at.Name, OFF_A)) or (kind == "C" and not has(at.Name, KEEP_C))
			local dim = kind == "A" and not off and has(at.Name, DIM_A)
			for _, e in at:GetDescendants() do
				if e:IsA("ParticleEmitter") then
					if off then e.Enabled = false
					elseif dim then e.Rate *= 0.3
					elseif kind == "B" then e.ZOffset = -2; e.LightEmission = math.min(e.LightEmission, 0.4) end
				elseif e:IsA("Light") then
					if off then e.Enabled = false
					elseif dim then e.Brightness *= 0.3
					elseif kind == "B" then
						e.Brightness = math.min(e.Brightness, 0.5)
						if e:IsA("PointLight") then e.Range = math.min(e.Range, 6) end
					end
				elseif e:IsA("Beam") and off then e.Enabled = false
				end
			end
		end
	end
end

function CAP.setup(auraName: string): CFrame
	CAP.clean(true)
	local src = game.ReplicatedStorage.Assets.FX:FindFirstChild("Auras")
	local model = src and src:FindFirstChild("FX_Aura_" .. auraName)
	assert(model and model:IsA("Model"), "aura absente : " .. auraName)
	local items = game.ReplicatedStorage.Assets:FindFirstChild("Items")
	local thing: Model? = nil
	for _, d in (items and items:GetDescendants() or {}) do
		-- un objet du jeu (pas d'un dossier de travail « _… »)
		if d:IsA("Model") and d.Name:match("^ITM_") and d.Parent and not d.Parent.Name:match("^_") then thing = d; break end
	end
	game.StarterGui.ShowDevelopmentGui = false
	local scene = Instance.new("Folder")
	scene.Name = "_CAPTURE_Aura"
	scene.Parent = workspace -- avant la pose : l'Animator ne bouge pas un modèle hors de Workspace
	local floor = Instance.new("Part")
	floor.Anchored = true
	floor.Size = Vector3.new(60, 1, 30)
	floor.Position = ORIGIN + Vector3.new(GAP * 1.5, -0.5, 0)
	floor.Color = Color3.fromRGB(96, 150, 88)
	floor.Material = Enum.Material.Grass
	floor.Parent = scene
	for i, kind in { "Aujourd'hui", "A", "B", "C" } do
		local m = rig(ORIGIN + Vector3.new((i - 1) * GAP, 0, 0))
		m.Name = kind
		m.Parent = scene
		pose(m)
		if thing then item(m, thing) end
		aura(m, model)
		if kind ~= "Aujourd'hui" then variant(m, kind) end
	end
	local center = ORIGIN + Vector3.new(GAP * 1.5, 3, 0)
	-- de dos, comme la caméra du joueur (ils regardent vers +Z) ; de gauche à droite à l'écran : C, B, A, Aujourd'hui
	return CFrame.lookAt(center + Vector3.new(0, 6, -17), center + Vector3.new(0, 1.5, 0))
end

function CAP.clean(keepCamera: boolean?)
	local s = workspace:FindFirstChild("_CAPTURE_Aura")
	if s then s:Destroy() end
	if not keepCamera then
		workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
		game.StarterGui.ShowDevelopmentGui = true
		_G.CAP = nil
	end
end

return CAP
