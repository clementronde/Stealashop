--!nocheck
-- Scene de capture d'un lot de tapis (chef 3D, 26/11). A lancer en Edit, sans Play, QUAND ON A LE JETON.
-- Pose Workspace/_CAPTURE_TapisLot1 a y = 400 : les tapis du lot (Previews/TREADMILLS/PLOT_Treadmill_<Nom>_v4) en rang,
-- puis le Gold du jeu (Assets/Plots/PLOT_Treadmill_Gold) en fin de rang pour comparer, sol neutre, un R15 sur chaque bande
-- (pieds recales sur la bande). Rien n'est touche hors de ce dossier.
--   _G.CTL.start()  la course tourne (StepAnimations), les bandes defilent (9 studs/s), en boucle, jusqu'a stop()
--   _G.CTL.stop()   arrete la boucle
--   _G.CTL.clean()  arrete et retire tout, camera en Custom, ShowDevelopmentGui a true
-- Renvoie les cameras : vue d'ensemble, puis une vue 3/4 avant par tapis.
local LOT = { "Base", "Cardboard", "Bronze", "Silver", "Supermarket" }
local SPACING = 18
local O = Vector3.new(0, 400, -300)
local RUN_ANIM = "rbxassetid://913376220"
local BELT_SPEED = 9
local RunService = game:GetService("RunService")

local old = workspace:FindFirstChild("_CAPTURE_TapisLot1")
if old then old:Destroy() end
if _G.CTL then pcall(_G.CTL.stop) end
-- la camera peut appartenir a une autre session (le trailer la garde en Scriptable) : on la note pour la rendre telle quelle
local CAM0 = { type = workspace.CurrentCamera.CameraType, cf = workspace.CurrentCamera.CFrame, devgui = game.StarterGui.ShowDevelopmentGui }
local st = Instance.new("Folder")
st.Name = "_CAPTURE_TapisLot1"

st.Parent = workspace
local list = {}
for _, n in LOT do
	local src = game.ServerStorage.Previews.TREADMILLS:FindFirstChild("PLOT_Treadmill_" .. n .. "_v4")
	if src then table.insert(list, { n, src }) end
end
table.insert(list, { "Gold", game.ReplicatedStorage.Assets.Plots.PLOT_Treadmill_Gold })

local floor = Instance.new("Part")
floor.Name = "Floor"
floor.Anchored = true
floor.Size = Vector3.new(SPACING * #list + 30, 1, 60)
floor.CFrame = CFrame.new(O + Vector3.new(SPACING * (#list - 1) / 2, -0.5, 0))
floor.Color = Color3.fromHex("D8CFC0")
floor.Material = Enum.Material.Plastic
floor.Parent = st

local rigSrc = game.ServerStorage.AnimRigs.Rig_Player
local runners, belts, cams = {}, {}, {}
local feet
for i, e in list do
	local c = O + Vector3.new((i - 1) * SPACING, 0, 0)
	local m = e[2]:Clone()
	m.Name = e[1]
	for _, d in m:GetDescendants() do
		if d:IsA("LuaSourceContainer") then d:Destroy() end
	end
	m:PivotTo(CFrame.new(c))
	m.Parent = st
	local belt = m:FindFirstChild("Belt")
	for _, d in m:GetDescendants() do
		if d:IsA("Texture") and d.Parent and d.Parent.Name == "Belt" then table.insert(belts, d) end
	end
	-- coureur : face a la console (-Z), au point d'usage
	local rig = rigSrc:Clone()
	for _, d in rig:GetDescendants() do
		if d:IsA("LuaSourceContainer") then d:Destroy() end
	end
	local hrp = rig:FindFirstChild("HumanoidRootPart")
	for _, d in rig:GetDescendants() do
		if d:IsA("BasePart") then d.Anchored = (d == hrp) end
	end
	local use = belt and belt:FindFirstChild("UsePoint")
	local at = if use then use.WorldPosition else c + Vector3.new(0, 1, 0.5)
	local _, rs = rig:GetBoundingBox()
	rig:PivotTo(CFrame.new(Vector3.new(at.X, (belt and belt.Position.Y + belt.Size.Y / 2 or c.Y + 1) + rs.Y / 2, at.Z)))
	rig.Name = "Runner"
	rig.Parent = m
	local hum = rig:FindFirstChildOfClass("Humanoid")
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = hum
	end
	local a = Instance.new("Animation")
	a.AnimationId = RUN_ANIM
	local track = animator:LoadAnimation(a)
	-- couleurs de tenue (le Rig_Player est noir) : peau, t-shirt bleu, jean vert
	for _, d in rig:GetDescendants() do
		if d:IsA("BasePart") and d ~= hrp then
			local n = d.Name
			if n == "Head" or n:find("Hand") or n:find("LowerArm") then d.Color = Color3.fromHex("E8C39E")
			elseif n:find("Torso") or n:find("UpperArm") then d.Color = Color3.fromHex("2F6FD6")
			elseif n:find("Leg") or n:find("Foot") then d.Color = Color3.fromHex("3E8E4A") end
		elseif d:IsA("Shirt") or d:IsA("Pants") or d:IsA("BodyColors") then
			d:Destroy()
		end
	end
	-- pieds sur la bande : en Edit, les pieds ne suivent l'animation qu'apres un task.wait() ; on mesure le coin le plus
	-- bas de chaque pied a chaque image (40 images), on descend le rig entier de cet ecart, puis on remesure
	track:Play(0, 1, 1.15)
	local function lowestFoot()
		local top = belt.Position.Y + belt.Size.Y / 2
		local mn, mx = math.huge, -math.huge
		for _ = 1, 40 do
			animator:StepAnimations(1 / 30)
			task.wait()
			local lo = math.huge
			for _, fn in { "LeftFoot", "RightFoot" } do
				local f = rig:FindFirstChild(fn)
				local cf, h = f.CFrame, f.Size / 2
				for _, sx in { -1, 1 } do for _, sy in { -1, 1 } do for _, sz in { -1, 1 } do
					lo = math.min(lo, (cf * Vector3.new(sx * h.X, sy * h.Y, sz * h.Z)).Y - top)
				end end end
			end
			mn, mx = math.min(mn, lo), math.max(mx, lo)
		end
		return mn, mx
	end
	if belt then
		local mn = lowestFoot()
		rig:PivotTo(rig:GetPivot() + Vector3.new(0, -mn, 0))
		task.wait()
		local a2, b2 = lowestFoot()
		feet = (feet or "") .. string.format("%s : pied le plus bas de %.2f a %.2f | ", e[1], a2, b2)
	end
	table.insert(runners, { animator = animator, track = track })
	-- camera 3/4 arriere (derriere le coureur) : de l avant, le portique le cache (captures du 26/11)
	table.insert(cams, { e[1], { c.X + 12, c.Y + 9.5, c.Z + 13 }, { c.X, c.Y + 4.5, c.Z - 1 } })
end

local CTL = {}
_G.CTL = CTL
function CTL.start()
	pcall(function() RunService:UnbindFromRenderStep("CTL_run") end)
	for _, r in runners do r.track:Play(0, 1, 1.15) end
	local last = os.clock()
	RunService:BindToRenderStep("CTL_run", Enum.RenderPriority.Last.Value + 50, function()
		local now = os.clock()
		local dt = now - last
		last = now
		for _, r in runners do r.animator:StepAnimations(dt) end
		for _, b in belts do b.OffsetStudsV += BELT_SPEED * dt end
	end)
end
function CTL.stop()
	pcall(function() RunService:UnbindFromRenderStep("CTL_run") end)
end
function CTL.clean()
	CTL.stop()
	local s = workspace:FindFirstChild("_CAPTURE_TapisLot1")
	if s then s:Destroy() end
	workspace.CurrentCamera.CameraType = CAM0.type -- camera rendue comme on l'a trouvee (pas forcee en Custom)
	workspace.CurrentCamera.CFrame = CAM0.cf
	game.StarterGui.ShowDevelopmentGui = CAM0.devgui
	_G.CTL = nil
end

local mid = O + Vector3.new(SPACING * (#list - 1) / 2, 0, 0)
local lines = { feet or "", string.format("Ensemble : (%.1f, %.1f, %.1f) -> (%.1f, %.1f, %.1f)", mid.X + 20, mid.Y + 22, mid.Z - 48, mid.X, mid.Y + 4, mid.Z) }
for _, cam in cams do
	table.insert(lines, string.format("%s : (%.1f, %.1f, %.1f) -> (%.1f, %.1f, %.1f)", cam[1], cam[2][1], cam[2][2], cam[2][3], cam[3][1], cam[3][2], cam[3][3]))
end
return table.concat(lines, "\n")
