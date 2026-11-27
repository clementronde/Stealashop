-- Aperçu en mouvement des prototypes FX_AfkZzz et FX_Escape_v3 (chef VFX et son, 27/11), en Edit, sans Play.
-- À lancer après fx_afk_escape_proto.luau, avec le jeton. Filmé par gdigrab (Studio au premier plan pendant la prise).
--   _G.VAE.setup()        scène Workspace/_CAPTURE_VFX à (300 ; 400 ; −300) : sol, un R15 par effet
--   _G.VAE.run("zzz", 9)  gros plan du dormeur : un ronflement (Snore) toutes les 1,4 s, comme le ferait le marqueur
--   _G.VAE.run("escape", 10) l'arrivée en zone safe, rejouée toutes les 3,2 s en Épique, Légendaire puis Mythique
--                          (le code teinte les émetteurs RarityColor ; ici on le fait à sa place)
--   _G.VAE.clean()        retire toute la scène et remet la caméra
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local VAE = {}
_G.VAE = VAE
local ORIGIN = Vector3.new(300, 400, -300)
local PROTO = game.ServerStorage:FindFirstChild("_PROTO_VFX_2026-11-27")
local RARITIES = { Color3.fromHex("#A855F7"), Color3.fromHex("#FFC21A"), Color3.fromHex("#FF3B5C") }

local function rig(at: Vector3, yaw: number): Model
	local m = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	local a = m:FindFirstChild("Animate")
	if a then a:Destroy() end
	local hum = m:WaitForChild("Humanoid") :: Humanoid
	local hrp = m:WaitForChild("HumanoidRootPart") :: BasePart
	m:PivotTo(CFrame.new(at + Vector3.new(0, hum.HipHeight + hrp.Size.Y / 2, 0)) * CFrame.Angles(0, yaw, 0))
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			local n = p.Name
			p.Color = if n:match("Torso") or n:match("UpperArm") then Color3.fromRGB(30, 30, 34)
				elseif n:match("Leg") or n:match("Foot") then Color3.fromRGB(46, 92, 52)
				else Color3.fromRGB(234, 190, 150)
		end
	end
	return m
end

function VAE.setup(): string
	assert(PROTO, "lancer d'abord fx_afk_escape_proto.luau")
	local old = workspace:FindFirstChild("_CAPTURE_VFX")
	if old then old:Destroy() end
	local scene = Instance.new("Folder")
	scene.Name = "_CAPTURE_VFX"
	local floor = Instance.new("Part")
	floor.Name = "Sol"
	floor.Anchored = true
	floor.Size = Vector3.new(80, 1, 80)
	floor.Position = ORIGIN - Vector3.new(0, 0.5, 0)
	floor.Color = Color3.fromRGB(96, 150, 88)
	floor.Material = Enum.Material.Grass
	floor.Parent = scene
	-- le dormeur, et ses Z posés sur le haut de la tête
	local sleeper = rig(ORIGIN + Vector3.new(-12, 0, 0), 0)
	sleeper.Name = "Dormeur"
	sleeper.Parent = scene
	local head = sleeper:FindFirstChild("Head")
	local zSource = PROTO:FindFirstChild("FX_AfkZzz")
	assert(head and head:IsA("BasePart") and zSource and zSource:IsA("Model"), "tête ou FX_AfkZzz absent")
	local z = zSource:Clone()
	z:PivotTo(CFrame.new(head.Position + Vector3.new(0, head.Size.Y / 2, 0)))
	z.Parent = scene
	VAE.zzz = z
	-- le héros qui arrive en zone safe, et l'éclat à ses pieds
	local hero = rig(ORIGIN + Vector3.new(12, 0, 0), math.pi)
	hero.Name = "Heros"
	hero.Parent = scene
	VAE.heroFeet = ORIGIN + Vector3.new(12, 0, 0)
	local black = Instance.new("Part")
	black.Name = "Noir"
	black.Anchored, black.CanCollide, black.CastShadow = true, false, false
	black.Size = Vector3.new(60, 60, 0.2)
	black.Color = Color3.new(0, 0, 0)
	black.Parent = scene
	VAE.black = black
	scene.Parent = workspace
	VAE.scene = scene
	return "scène posée"
end

local function emitAll(m: Instance)
	for _, d in m:GetDescendants() do
		if d:IsA("ParticleEmitter") then d:Emit(d:GetAttribute("EmitCount") or 1) end
	end
end

function VAE.run(mode: string, duration: number): string
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	local t0 = os.clock()
	local nextShot, shot = 1, 0
	local copies = {}
	RunService:BindToRenderStep("VAE_cam", Enum.RenderPriority.Last.Value + 100, function()
		local t = os.clock() - t0
		game.StarterGui.ShowDevelopmentGui = false
		if mode == "zzz" then
			local target = VAE.zzz:GetPivot().Position + Vector3.new(0.5, 1.2, 0)
			local a = 0.35 + 0.08 * math.sin(t * 0.4) -- lent travelling autour du dormeur, de trois quarts
			cam.CFrame = CFrame.lookAt(target + Vector3.new(math.sin(a) * 11, 2.5, math.cos(a) * 11), target)
		else
			local target = VAE.heroFeet + Vector3.new(0, 3.5, 0)
			cam.CFrame = CFrame.lookAt(target + Vector3.new(-6, 6, -15), target) -- derrière et au-dessus, comme en jeu
		end
		VAE.black.Transparency = if t < 1 then 0 else 1
		VAE.black.CFrame = cam.CFrame * CFrame.new(0, 0, -1)
		if t < 1 or t < nextShot then return end
		if mode == "zzz" then
			nextShot += 1.4
			emitAll(VAE.zzz)
		else
			nextShot += 3.2
			shot += 1
			local source = PROTO:FindFirstChild("FX_Escape_v3")
			if not (source and source:IsA("Model")) then return end
			local c = source:Clone()
			local color = RARITIES[(shot - 1) % #RARITIES + 1]
			for _, d in c:GetDescendants() do
				if d:IsA("ParticleEmitter") and d:GetAttribute("RarityColor") then d.Color = ColorSequence.new(color) end
				if d:IsA("Light") then d.Enabled = false end
			end
			c:PivotTo(CFrame.new(VAE.heroFeet))
			c.Parent = VAE.scene
			table.insert(copies, c)
			emitAll(c)
			task.delay(c:GetAttribute("Duration") or 2.6, function() c:Destroy() end)
		end
	end)
	while os.clock() - t0 < duration do task.wait() end
	RunService:UnbindFromRenderStep("VAE_cam")
	return "fini"
end

function VAE.clean()
	pcall(function() RunService:UnbindFromRenderStep("VAE_cam") end)
	local s = workspace:FindFirstChild("_CAPTURE_VFX")
	if s then s:Destroy() end
	workspace.CurrentCamera.CameraType = Enum.CameraType.Fixed
	game.StarterGui.ShowDevelopmentGui = true
	_G.VAE = nil
end

return VAE
