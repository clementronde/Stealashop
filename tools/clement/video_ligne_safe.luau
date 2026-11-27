-- Courte vidéo pour Clément (26/11) : le joueur passe la ligne safe avec un objet, et l'éclat FX_Escape_v2 part.
-- Chef VFX et son. En Edit, sans Play ; aucun script n'est laissé dans la place. Filmé par gdigrab (skill trailer-tiktok,
-- scripts/capture.sh) : lancer la prise, puis _G.LS.run() ; tout retirer ensuite par _G.LS.clean().
--   _G.LS.setup(origin)  pose Workspace/_PROTO_LIGNE : un sol de rue, une ligne safe (bande verte), un mannequin R15
--                        qui porte un objet au-dessus de la tête, une pièce noire devant la caméra (repère de synchro)
--   _G.LS.run()          noir 1 s, puis 6 s : le mannequin court vers la ligne (marche animée par StepAnimations),
--                        la passe à t ≈ 2,3 s, l'éclat part à ses pieds (EmitCount, Delay, FadeTime comme le code)
--   _G.LS.clean()        retire tout et remet la caméra

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LS = {}
_G.LS = LS

local RUN_ANIM = "rbxassetid://913376220" -- course R15 par défaut de Roblox
local SPEED = 14 -- studs/s, à peu près la vitesse d'un joueur qui porte un objet
local FX_SRC = game.ServerStorage.Previews.FX.FX_Escape_v2

function LS.setup(origin: CFrame)
	LS.clean()
	local root = Instance.new("Folder")
	root.Name = "_PROTO_LIGNE"
	root.Parent = workspace
	LS.root, LS.origin = root, origin

	local function part(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material): Part
		local p = Instance.new("Part")
		p.Name, p.Anchored, p.Size, p.CFrame, p.Color, p.Material = name, true, size, cf, color, mat
		p.CanCollide = false
		p.Parent = root
		return p
	end
	part("Rue", Vector3.new(30, 1, 80), origin * CFrame.new(0, -0.5, 0), Color3.fromRGB(70, 72, 78), Enum.Material.Asphalt)
	part("LigneSafe", Vector3.new(30, 0.08, 1.2), origin * CFrame.new(0, 0.05, 0), Color3.fromRGB(70, 220, 120), Enum.Material.Neon)
	part("Trottoir", Vector3.new(30, 0.6, 40), origin * CFrame.new(0, -0.2, 20), Color3.fromRGB(180, 180, 175), Enum.Material.Concrete)

	-- mannequin : peau beige, haut bleu, bas vert (tenue du bacon hair, en couleurs simples)
	local rig = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	local anim = rig:FindFirstChild("Animate")
	if anim then anim:Destroy() end
	rig.Name = "Joueur"
	for _, p in rig:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			local n = p.Name
			p.Color = if n:match("Torso") or n:match("UpperArm") then Color3.fromRGB(30, 30, 34)
				elseif n:match("Leg") or n:match("Foot") then Color3.fromRGB(46, 92, 52)
				else Color3.fromRGB(234, 190, 150)
		end
	end
	local hrp = rig:WaitForChild("HumanoidRootPart") :: BasePart
	hrp.Anchored = true
	local hum = rig:WaitForChild("Humanoid") :: Humanoid
	LS.height = hum.HipHeight + hrp.Size.Y / 2
	rig.Parent = root
	-- l'objet porté : une caisse dorée au-dessus de la tête (on ne vole pas un vrai objet du jeu pour la vidéo)
	local box = part("Objet", Vector3.new(1.8, 1.4, 1.4), CFrame.new(), Color3.fromRGB(240, 190, 60), Enum.Material.SmoothPlastic)
	box.Anchored = false
	local head = rig:WaitForChild("Head") :: BasePart
	local w = Instance.new("WeldConstraint")
	box.CFrame = head.CFrame * CFrame.new(0, 1.6, 0)
	w.Part0, w.Part1 = head, box
	w.Parent = box
	box.Parent = rig
	LS.rig, LS.hrp = rig, hrp
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = hum
	end
	local a = Instance.new("Animation")
	a.AnimationId = RUN_ANIM
	LS.track = animator:LoadAnimation(a)
	LS.animator = animator

	-- pièce noire de synchro, collée à la caméra pendant le noir
	LS.black = part("Noir", Vector3.new(40, 40, 0.2), CFrame.new(), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
	LS.black.Transparency = 1
	return "prêt"
end

local function emitEscape(at: CFrame)
	local m = FX_SRC:Clone()
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then d.Anchored = true; d.Transparency = 1; d.CanCollide = false end
	end
	m:PivotTo(at)
	m.Parent = LS.root
	for _, d in m:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			local n = d:GetAttribute("EmitCount")
			if n then task.delay(d:GetAttribute("Delay") or 0, function() d:Emit(n) end) end
		elseif d:IsA("Light") then
			local base = d.Brightness
			local fade = d:GetAttribute("FadeTime") or 0
			d.Enabled = true
			if fade > 0 then
				task.spawn(function()
					local t0 = os.clock()
					while os.clock() - t0 < fade do
						d.Brightness = base * (1 - (os.clock() - t0) / fade)
						task.wait()
					end
					d.Enabled = false
				end)
			else
				d.Enabled = false
			end
		end
	end
end

function LS.run(): string
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	game.StarterGui.ShowDevelopmentGui = false
	local o = LS.origin
	local startZ, endZ = -32, 18 -- de la rue vers le trottoir ; la ligne est à z = 0
	local camOffset = Vector3.new(11, 7, -14)
	local fired = false
	LS.track:Play(0, 1, 1.1)
	local t0 = os.clock()
	local last = t0
	RunService:BindToRenderStep("LS_cam", Enum.RenderPriority.Last.Value + 100, function()
		local now = os.clock()
		local t = now - t0
		local dt = now - last
		last = now
		game.StarterGui.ShowDevelopmentGui = false
		local z = if t < 1 then startZ else math.min(endZ, startZ + (t - 1) * SPEED)
		local pos = (o * CFrame.new(0, LS.height, z)).Position
		LS.hrp.CFrame = CFrame.lookAt(pos, pos - o.LookVector) -- il court vers +Z (vers le trottoir)
		if t >= 1 then LS.animator:StepAnimations(dt) end
		local look = pos + Vector3.new(0, -0.5, 4)
		local camPos = (o * CFrame.new(camOffset + Vector3.new(0, 0, math.min(z, 4)))).Position
		cam.CFrame = CFrame.lookAt(camPos, look)
		-- noir pendant la 1re seconde, collé à la caméra (repère de synchro du montage)
		LS.black.Transparency = if t < 1 then 0 else 1
		LS.black.CFrame = cam.CFrame * CFrame.new(0, 0, -1)
		if not fired and z >= 0 then
			fired = true
			emitEscape(o * CFrame.new(0, 0, 0.6))
		end
	end)
	while os.clock() - t0 < 7 do task.wait() end
	RunService:UnbindFromRenderStep("LS_cam")
	LS.track:Stop(0)
	return "fini"
end

function LS.clean()
	pcall(function() RunService:UnbindFromRenderStep("LS_cam") end)
	local old = workspace:FindFirstChild("_PROTO_LIGNE")
	if old then old:Destroy() end
	workspace.CurrentCamera.CameraType = Enum.CameraType.Fixed
	game.StarterGui.ShowDevelopmentGui = true
end

return LS
