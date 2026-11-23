-- Tournage TikTok « la nuit tombe » (2026-11-20, agent video-tiktok), version 2 : prise au ralenti.
-- À lancer en PLAY dans Studio (place DEV), jamais en Edit : tout ce qui est changé ici (Lighting,
-- caméra, PlayerGui, mur, néons, vigiles, faisceaux, attributs du Workspace) vit dans la session de test
-- et disparaît à l'arrêt. Rien n'est créé dans StarterGui, Lighting ou la Map de la place ; rien n'est
-- enregistré.
--
-- Pourquoi le ralenti : video_capture n'enregistre qu'environ 9,5 i/s. La prise dure SLOW fois plus
-- longtemps (12 s × 4 = 48 s), puis le montage l'accélère SLOW fois : environ 38 vraies images par
-- seconde de vidéo, sans interpolation.
--
-- Déroulé :
--   1. SERVEUR « préparer » : le perso est posé (ancré) en hauteur au-dessus du couloir, puis la vraie
--      nuit est lancée (NightSkipTo) : mur levé, vigiles de nuit en ronde, néons NightLight allumés.
--      Le perso étant côté couloir, il reçoit le passage de nuit : la nuit n'est pas raccourcie à 15 s
--      (Night.EmptyCorridorRemaining). En Studio, AntiCheatService ne fait que signaler.
--      AVANT cela, le CLIENT doit avoir noté l'état de jour des néons (morceau 2, tant qu'il fait jour).
--   2. CLIENT : note les néons (de jour), puis à chaque image rejoue la tombée de la nuit au rythme de
--      la vidéo : lumière, caméra, mur (baissé puis levé entre NIGHT_AT et NIGHT_AT + 3), néons,
--      vigiles qui apparaissent avec un faisceau de lampe torche visible.
--   3. SERVEUR « top » : pose _ShootStart (heure serveur du top), pendant video_capture.
-- Les temps (NIGHT_AT, clés) sont en secondes de VIDÉO ; l'horloge de la prise est divisée par SLOW.
--
-- Caméra tournée de 90° (roulis) : le viewport 1568 × 640 donne des images 640 × 1568 une fois
-- redressées au montage (transpose=2).

------------------------------------------------------------------------------------------------
-- 1. SERVEUR « préparer » (après le morceau 2 côté client)
------------------------------------------------------------------------------------------------
--[[SERVER_PREP
local player = game.Players:GetPlayers()[1]
local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
root.Anchored = true
player.Character:PivotTo(CFrame.new(70, -60, 40)) -- côté couloir, sous la rue : hors champ (ses ailes se voyaient en l'air) et loin des vigiles (portée 40)
workspace:SetAttribute("_ShootStart", nil)
task.wait(0.5)
workspace:SetAttribute("NightSkipTo", "Night 600")
task.wait(5) -- le mur finit de monter (3 s), les vigiles apparaissent (un par image)
return workspace:GetAttribute("NightPhase") .. " pass=" .. tostring(player:GetAttribute("NightPass"))
SERVER_PREP]]

------------------------------------------------------------------------------------------------
-- 2. CLIENT (CADRAGE = "A", "C" ou "D"), tant qu'il fait encore jour
------------------------------------------------------------------------------------------------
--[[CLIENT
local CADRAGE = "C"
local SLOW = 4
local DURATION = 12.5 -- s de vidéo
local NIGHT_AT = 4.3 -- s de vidéo : le mur commence à monter
local WALL_TIME = 3 -- comme Night.WallRiseTime

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")
local CollectionService = game:GetService("CollectionService")

local SHOTS = {
	A = { From = Vector3.new(-40, 7, 0), To = Vector3.new(200, 22, 0), Fov = 48, Push = 14 },
	C = { From = Vector3.new(-55, 45, -45), To = Vector3.new(150, 8, 8), Fov = 50, Push = 28 },
	D = { From = Vector3.new(-15, 2.5, -28), To = Vector3.new(70, 24, 18), Fov = 55, Push = 8 },
	-- nouveaux plans (2026-11-21), pour les inserts de la version « rafale »
	P1 = { From = Vector3.new(55, 2.5, 20), To = Vector3.new(140, 16, -48), Fov = 55, Push = 10 }, -- la rue au ras du sol : les néons des façades
	P2 = { From = Vector3.new(78, 3, 28), To = Vector3.new(27, 14, -8), Fov = 55, Push = 8 }, -- le mur vu depuis le couloir
	P3 = { Track = "NightGuard_Z1", Offset = Vector3.new(-3, 0.2, 13), Fov = 50 }, -- un vigile de nuit suivi de près, en temps réel (pas de ralenti), _ShootStart réglé pour t = 12,5
}
_G._shootCadrage = CADRAGE
local player = Players.LocalPlayer
local cam = workspace.CurrentCamera

for _, g in player.PlayerGui:GetChildren() do
	if g:IsA("ScreenGui") then g.Enabled = false end
end
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)
-- (pas de SetCore("TopbarEnabled", false) : après lui, une prise est sortie grise)

-- État de jour, noté une seule fois (avant la nuit)
local cc = Lighting:FindFirstChild("_ShootCC") or Instance.new("ColorCorrectionEffect")
cc.Name = "_ShootCC"
cc.Parent = Lighting
local atm = Lighting:FindFirstChildOfClass("Atmosphere")
_G._shootAtm0 = _G._shootAtm0 or (atm and { Color = atm.Color, Decay = atm.Decay })
_G._shootDay = _G._shootDay or { Bright = Lighting.Brightness, Amb = Lighting.Ambient, Out = Lighting.OutdoorAmbient }
if not _G._shootLamps then
	local lamps = {}
	for _, part in CollectionService:GetTagged("NightLight") do
		if part:IsA("BasePart") and part:IsDescendantOf(workspace) then
			local lights = {}
			for _, d in part:GetDescendants() do
				if d:IsA("Light") then lights[d] = d.Enabled end
			end
			-- moment d'allumage : en cascade, du plus proche du mur au plus loin
			local dist = (part.Position - Vector3.new(27, 0, 0)).Magnitude
			lamps[part] = { Material = part.Material, Lights = lights, At = NIGHT_AT + 0.15 + math.clamp(dist / 900, 0, 1) * 1.2 + math.random() * 0.25, On = nil }
		end
	end
	_G._shootLamps = lamps
end
local atm0, DAY, lamps = _G._shootAtm0, _G._shootDay, _G._shootLamps

-- Mur : pivot baissé (état livré) lu de jour, une seule fois ; la nuit, le client le pose lui-même
local wall = workspace.Map.Entry.NightWall
local RISE = wall:GetAttribute("RiseHeight") or 24
_G._shootWallDown = _G._shootWallDown or wall:GetPivot()

-- clés : t, ClockTime, Brightness, Ambient, OutdoorAmbient, Tint, Saturation, Contrast, Exposure
local KEYS = {
	{ 0.0, 15.8, DAY.Bright, DAY.Amb, DAY.Out, Color3.fromRGB(255, 240, 225), 0.15, 0.05, 0.0 },
	{ 1.2, 17.0, 2.5, Color3.fromRGB(165, 130, 110), Color3.fromRGB(220, 165, 125), Color3.fromRGB(255, 220, 180), 0.30, 0.08, 0.0 },
	{ 2.4, 17.7, 2.1, Color3.fromRGB(160, 95, 95), Color3.fromRGB(225, 125, 105), Color3.fromRGB(255, 195, 165), 0.38, 0.10, 0.0 },
	{ 3.6, 18.3, 1.5, Color3.fromRGB(120, 75, 130), Color3.fromRGB(170, 100, 160), Color3.fromRGB(235, 180, 220), 0.42, 0.11, 0.0 },
	{ 4.8, 19.3, 1.2, Color3.fromRGB(95, 70, 170), Color3.fromRGB(115, 90, 200), Color3.fromRGB(205, 170, 255), 0.48, 0.12, 0.05 },
	{ 6.2, 21.0, 1.0, Color3.fromRGB(110, 60, 200), Color3.fromRGB(140, 80, 240), Color3.fromRGB(190, 140, 255), 0.60, 0.15, 0.15 },
	{ 13.0, 23.5, 1.0, Color3.fromRGB(115, 60, 210), Color3.fromRGB(145, 80, 245), Color3.fromRGB(185, 135, 255), 0.65, 0.15, 0.15 },
}
local function smooth(x) return x * x * (3 - 2 * x) end
local function sample(t)
	if t <= KEYS[1][1] then return KEYS[1] end
	for i = 1, #KEYS - 1 do
		local a, b = KEYS[i], KEYS[i + 1]
		if t <= b[1] then
			local u = smooth((t - a[1]) / (b[1] - a[1]))
			local r = {}
			for k = 1, 9 do
				local va, vb = a[k], b[k]
				r[k] = if typeof(va) == "Color3" then va:Lerp(vb, u) else va + (vb - va) * u
			end
			return r
		end
	end
	return KEYS[#KEYS]
end

local function setLamp(part, state, on)
	if state.On == on then return end
	state.On = on
	part.Material = if on then Enum.Material.Neon else state.Material
	for light, enabled in state.Lights do
		light.Enabled = if on then true else enabled
	end
end

-- Faisceau visible de la lampe torche (ACC_Nuit_LampeTorche/…/Lens) : un Beam local
local function beamFor(guard)
	local lens = guard:FindFirstChild("Lens", true)
	if not lens or not lens:IsA("BasePart") or lens:FindFirstChild("_ShootBeam") then return end
	local a0 = Instance.new("Attachment")
	a0.Name = "_ShootA0"
	a0.Parent = lens
	local a1 = Instance.new("Attachment")
	a1.Name = "_ShootA1"
	a1.Parent = lens
	local spot = lens:FindFirstChildOfClass("SpotLight")
	local face = if spot then Vector3.FromNormalId(spot.Face) else Vector3.new(0, 0, -1)
	a1.Position = face * 26 + Vector3.new(0, -3, 0)
	local beam = Instance.new("Beam")
	beam.Name = "_ShootBeam"
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.Width0, beam.Width1 = 0.6, 12
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 244, 214))
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.55, 0.6), NumberSequenceKeypoint.new(1, 1) })
	beam.Segments = 12
	beam.Parent = lens
	if spot then
		spot.Brightness = 4
		spot.Range = 40
	end
end
local function nightGuards()
	local list = {}
	for _, m in workspace:GetDescendants() do
		if m:IsA("Model") and m.Name:match("^NightGuard_Z") and m:FindFirstChildOfClass("Humanoid") then
			table.insert(list, m)
		end
	end
	return list
end
local guards, guardsAt = {}, 0

local function frame()
	local shot = SHOTS[_G._shootCadrage]
	local start = workspace:GetAttribute("_ShootStart")
	local t = if start then (workspace:GetServerTimeNow() - start) / SLOW else 0
	t = math.clamp(t, 0, DURATION)
	local night = workspace:GetAttribute("NightPhase") == "Night"

	-- lumière
	local k = sample(t)
	Lighting.ClockTime = k[2]
	Lighting.Brightness = k[3]
	Lighting.Ambient = k[4]
	Lighting.OutdoorAmbient = k[5]
	cc.TintColor = k[6]
	cc.Saturation = k[7]
	cc.Contrast = k[8]
	Lighting.ExposureCompensation = k[9]
	if atm and atm0 then
		local n = math.clamp((t - 3.0) / 3.5, 0, 1)
		atm.Color = atm0.Color:Lerp(Color3.fromRGB(120, 70, 220), n)
		atm.Decay = atm0.Decay:Lerp(Color3.fromRGB(60, 30, 140), n)
	end

	if night then
		-- mur : baissé jusqu'à NIGHT_AT, puis monte en WALL_TIME s (même courbe que le serveur, à peu près)
		local u = math.clamp((t - NIGHT_AT) / WALL_TIME, 0, 1)
		u = 1 - (1 - u) ^ 2 -- ralentit en arrivant en haut
		wall:PivotTo(_G._shootWallDown * CFrame.new(0, RISE * u, 0))
		-- néons en cascade
		for part, state in lamps do
			setLamp(part, state, t >= state.At)
		end
		-- vigiles : invisibles avant le mur, puis apparaissent ; faisceau de lampe torche
		if os.clock() - guardsAt > 1 then
			guardsAt = os.clock()
			guards = nightGuards()
			for _, g in guards do beamFor(g) end
		end
		local show = math.clamp((t - (NIGHT_AT + 1.2)) / 0.8, 0, 1)
		for _, g in guards do
			for _, p in g:GetDescendants() do
				if p:IsA("BasePart") or p:IsA("Decal") then
					p.LocalTransparencyModifier = 1 - show
				elseif p:IsA("Beam") and p.Name == "_ShootBeam" then
					p.Enabled = show > 0.5
				elseif p:IsA("SpotLight") then
					p.Enabled = show > 0.5
				end
			end
		end
	end

	-- caméra : avancée lente qui ralentit, petite secousse quand le mur arrive en haut
	local dir = if shot.Track then Vector3.zAxis else (shot.To - shot.From).Unit
	local push = shot.Push * (1 - (1 - t / DURATION) ^ 2)
	local shake = Vector3.zero
	local s = t - (NIGHT_AT + WALL_TIME)
	if s > 0 and s < 0.35 then
		local a = (1 - s / 0.35) * 0.35
		shake = Vector3.new(math.sin(s * 90) * a, math.cos(s * 70) * a, 0)
	end
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = shot.Fov
	if shot.Track then
		-- suivi d'un vigile de nuit : caméra basse sur le côté, qui le suit en douceur
		local target
		for _, g in guards do
			if g.Name:find(shot.Track, 1, true) and g:FindFirstChild("HumanoidRootPart") then target = g break end
		end
		if target then
			local p = target.HumanoidRootPart.Position + Vector3.new(0, 1.2, 0)
			local want = CFrame.lookAt(p + shot.Offset, p)
			_G._shootTrack = if _G._shootTrack then _G._shootTrack:Lerp(want, 0.2) else want
			cam.CFrame = _G._shootTrack * CFrame.Angles(0, 0, math.rad(90))
		end
		-- panneaux d'info des magasins (BillboardGui du joueur) : cachés pour ce plan rapproché
		for _, g in player.PlayerGui:GetChildren() do
			if g:IsA("BillboardGui") or g:IsA("SurfaceGui") then g.Enabled = false end
		end
	else
		cam.CFrame = CFrame.lookAt(shot.From + dir * push, shot.To + dir * push) * CFrame.new(shake) * CFrame.Angles(0, 0, math.rad(90))
	end

	-- toute l'UI de la copie du joueur, à chaque image (les Notify arrivent en cours de prise)
	for _, g in player.PlayerGui:GetChildren() do
		if g:IsA("ScreenGui") and g.Enabled then g.Enabled = false end
	end
	-- le perso du joueur invisible chez lui
	local ch = player.Character
	if ch then
		for _, p in ch:GetDescendants() do
			if p:IsA("BasePart") or p:IsA("Decal") then p.LocalTransparencyModifier = 1 end
		end
	end
end

pcall(function() RunService:UnbindFromRenderStep("_Shoot") end)
RunService:BindToRenderStep("_Shoot", Enum.RenderPriority.Last.Value + 100, frame)
local n = 0
for _ in lamps do n += 1 end
return "client prêt : " .. CADRAGE .. ", néons notés : " .. n
CLIENT]]

------------------------------------------------------------------------------------------------
-- 3. SERVEUR « top » (juste après video_capture start)
------------------------------------------------------------------------------------------------
--[[SERVER_GO
local SLOW = 4
local LEAD = 1.0
workspace:SetAttribute("_ShootStart", workspace:GetServerTimeNow() + LEAD)
task.wait(LEAD + 12.5 * SLOW + 0.5)
return "fin, phase=" .. tostring(workspace:GetAttribute("NightPhase"))
SERVER_GO]]
