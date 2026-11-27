-- Aperçu en mouvement du tapis Gold (chef VFX et son, 26/11) : le Gold actuel et le nouveau, un coureur sur chacun.
-- En Edit, sans Play ; à lancer APRÈS tools/clement/tapis_gold_proto.luau (qui pose Workspace/_PROTO_TAPIS).
-- Filmé par gdigrab (skill trailer-tiktok, scripts/capture.sh) : Studio au premier plan pendant la prise (≈ 15 s).
--   _G.TG.prepare()  écran noir collé à la caméra (repère de synchro et de recherche de la vue 3D)
--   _G.TG.run()      noir 1 s, puis 9 s de course : les deux coureurs courent (StepAnimations), les bandes défilent
--                    (9 studs/s, comme TreadmillFX.BeltSpeed), les halos tournent (1,1 rad/s) ; sur le nouveau, un gain
--                    toutes les 1/6 s (StepEmit), le néon pulse (PulseTint 0,45, retour 0,15 s). Caméra : vue large des
--                    deux en 3/4 arrière (2,5 s), puis lent travelling vers le nouveau.
--   _G.TG.clean()    remet la caméra (le proto se retire par workspace._PROTO_TAPIS:Destroy()).
-- Ce que fait le code de Cantin en jeu est imité ici seulement pour la vidéo : rien n'est laissé dans la place.

local RunService = game:GetService("RunService")
local TG = {}
_G.TG = TG

local RUN_ANIM = "rbxassetid://913376220" -- course R15 par défaut de Roblox
local BELT_SPEED = 9
local HALO_SPEED = 1.1
local GAINS = 6

local root = workspace:WaitForChild("_PROTO_TAPIS")
local nouveau = root:WaitForChild("Gold_Nouveau") :: Model
local actuel = root:WaitForChild("Gold_Actuel") :: Model

local function prepRunner(m: Model)
	local rig = m:FindFirstChild("Mannequin")
	if not rig then return nil end
	local hrp = rig:FindFirstChild("HumanoidRootPart")
	for _, p in rig:GetDescendants() do
		if p:IsA("BasePart") then p.Anchored = (p == hrp) end
	end
	local hum = rig:FindFirstChildOfClass("Humanoid")
	if not hum then return nil end
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = hum
	end
	local a = Instance.new("Animation")
	a.AnimationId = RUN_ANIM
	local track = animator:LoadAnimation(a)
	return { animator = animator, track = track }
end

local function belts(m: Model): { Texture }
	local list = {}
	for _, d in m:GetDescendants() do
		if d:IsA("Texture") and d.Parent and d.Parent.Name == "Belt" then table.insert(list, d) end
	end
	return list
end
local function halos(m: Model): { { part: BasePart, sign: number, base: CFrame } }
	local list = {}
	local fx = m:FindFirstChild("GoldFX")
	if fx then
		for i = 1, 4 do
			local h = fx:FindFirstChild("Halo" .. i)
			if h and h:IsA("BasePart") then table.insert(list, { part = h, sign = if i % 2 == 1 then -1 else 1, base = h.CFrame }) end
		end
	end
	return list
end

-- Pieds sur la bande (Clément, 26/11 : « des coureurs à moitié dans le sol ») : fait tourner la course 2 s, mesure à
-- chaque pas l'écart entre le dessous des pieds et le dessus de la bande, puis relève (ou descend) le coureur pour que
-- le pied le plus bas touche la bande. Rend l'écart le plus petit mesuré avant correction, en studs.
function TG.feetCheck(m: Model, animator: Animator, track: AnimationTrack): number
	local rig = m:FindFirstChild("Mannequin")
	local belt = m:FindFirstChild("Belt")
	if not (rig and belt and belt:IsA("BasePart")) then return 0 end
	local hrp = rig:FindFirstChild("HumanoidRootPart")
	if not (hrp and hrp:IsA("BasePart")) then return 0 end
	local top = belt.Position.Y + belt.Size.Y / 2
	track:Play(0, 1, 1.15)
	local lowest = math.huge
	for _ = 1, 120 do
		animator:StepAnimations(1 / 60)
		for _, n in { "LeftFoot", "RightFoot" } do
			local f = rig:FindFirstChild(n)
			if f and f:IsA("BasePart") then
				local bottom = f.Position.Y - f.Size.Y / 2
				lowest = math.min(lowest, bottom - top)
			end
		end
	end
	track:Stop(0)
	if lowest ~= math.huge and math.abs(lowest) > 0.02 then
		hrp.CFrame = hrp.CFrame + Vector3.new(0, -lowest, 0)
	end
	return lowest
end

function TG.prepare()
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	local black = Instance.new("Part")
	black.Name = "Noir"
	black.Anchored, black.CanCollide, black.CastShadow = true, false, false
	black.Size = Vector3.new(40, 40, 0.2)
	black.Color = Color3.new(0, 0, 0)
	black.Parent = root
	TG.black = black
	RunService:BindToRenderStep("TG_cam", Enum.RenderPriority.Last.Value + 100, function()
		game.StarterGui.ShowDevelopmentGui = false
		black.Transparency = 0
		black.CFrame = cam.CFrame * CFrame.new(0, 0, -1)
	end)
end

function TG.run(): string
	pcall(function() RunService:UnbindFromRenderStep("TG_cam") end)
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	local runners = { prepRunner(nouveau), prepRunner(actuel) }
	local beltList = belts(nouveau)
	for _, b in belts(actuel) do table.insert(beltList, b) end
	local haloList = halos(nouveau)
	for _, h in halos(actuel) do table.insert(haloList, h) end
	local glow = nouveau:FindFirstChild("GoldGlow")
	local glowBase = if glow and glow:IsA("BasePart") then glow.Color else nil
	local steps = {}
	for _, d in nouveau:GetDescendants() do
		if d:IsA("ParticleEmitter") and d:GetAttribute("StepEmit") then table.insert(steps, d) end
	end
	-- effets de course allumés sur les deux tapis
	for _, d in root:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			d.TimeScale = 1
			if d:GetAttribute("RunOnly") or (d.Parent and d.Parent.Name == "RunBurstPoint" and d:GetAttribute("StepEmit") == nil) then d.Enabled = true end
			local rr = d:GetAttribute("RunRate")
			if rr then d.Rate = rr end
		end
	end
	for _, r in runners do if r then r.track:Play(0, 1, 1.15) end end

	local center = (nouveau:GetPivot().Position + actuel:GetPivot().Position) / 2
	local np = nouveau:GetPivot().Position
	local wideFrom, wideLook = center + Vector3.new(24, 11, 20), center + Vector3.new(0, 4, 0)
	local nearFrom, nearLook = np + Vector3.new(12, 7.5, 12), np + Vector3.new(0, 4.5, 0)
	local t0 = os.clock()
	local last = t0
	local nextGain = 1
	RunService:BindToRenderStep("TG_cam", Enum.RenderPriority.Last.Value + 100, function()
		local now = os.clock()
		local t, dt = now - t0, now - last
		last = now
		game.StarterGui.ShowDevelopmentGui = false
		TG.black.Transparency = if t < 1 then 0 else 1
		-- caméra : large jusqu'à 3,5 s, puis travelling doux (Sine InOut) vers le nouveau jusqu'à 8,5 s
		local k = math.clamp((t - 3.5) / 5, 0, 1)
		k = 0.5 - 0.5 * math.cos(math.pi * k)
		cam.CFrame = CFrame.lookAt(wideFrom:Lerp(nearFrom, k), wideLook:Lerp(nearLook, k))
		TG.black.CFrame = cam.CFrame * CFrame.new(0, 0, -1)
		if t < 1 then return end
		for _, r in runners do if r then r.animator:StepAnimations(dt) end end
		for _, b in beltList do b.OffsetStudsV += BELT_SPEED * dt end
		for _, h in haloList do
			h.part.CFrame = h.base * CFrame.Angles(0, h.sign * HALO_SPEED * (t - 1), 0)
		end
		if t >= nextGain then
			nextGain += 1 / GAINS
			for _, e in steps do e:Emit(e:GetAttribute("StepEmit")) end
		end
		if glow and glow:IsA("BasePart") and glowBase then
			local since = math.clamp(((t - 1) % (1 / GAINS)) / 0.15, 0, 1)
			glow.Color = glowBase:Lerp(Color3.new(1, 1, 1), 0.45 * (1 - since) ^ 2)
		end
	end)
	while os.clock() - t0 < 10 do task.wait() end
	RunService:UnbindFromRenderStep("TG_cam")
	for _, r in runners do if r then r.track:Stop(0) end end
	if glow and glow:IsA("BasePart") and glowBase then glow.Color = glowBase end
	return "fini"
end

function TG.clean()
	pcall(function() RunService:UnbindFromRenderStep("TG_cam") end)
	workspace.CurrentCamera.CameraType = Enum.CameraType.Fixed
	game.StarterGui.ShowDevelopmentGui = true
	_G.TG = nil
end

return TG
