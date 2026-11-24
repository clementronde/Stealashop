-- GardenVFX (ModuleScript) — wind sway, fountain water and lamp lights for the "Steal a Shop" voxel garden.
-- Supersedes BushVFX. Client only (LocalScript):
--   local GardenVFX = require(game.ReplicatedStorage.GardenVFX)
--   GardenVFX.Start()                            -- tracks every garden model in workspace, now and later
--   GardenVFX.Rustle(model, fromPosition)        -- manual shake + leaf pop (walking through bushes / flowers does it)
--   GardenVFX.SetWind(Vector3.new(1, 0, 0.3), 1) -- optional; default follows workspace.GlobalWind, else CONFIG.DefaultWind
--   GardenVFX.Refresh(model)                     -- after moving a model at runtime
--   GardenVFX.Stop()                             -- restores rest poses, removes every effect
--
-- What it drives (names from VoxelGarden.glb):
--   ENV_Nature_* with Sway_ children (Bush_*, Flower_*, Tree_Oak): wind sway around each Sway_ pivot, drifting
--     leaves / petals, pollen by day, fireflies by night, rustle when a character walks through (bushes + flowers).
--     Fixed part: Base (Trunk on the tree). Pivots are measured from geometry, so any scale, placement and yaw work.
--   ENV_Prop_Fountain: glassy water that bobs, pulsing WaterJet, spray, splashes under the falls, ripples, optional sound.
--   ENV_Prop_LampPost: Light turns Neon + PointLight at night.
--   Rock, Mushroom, Bench, Fence: static, nothing to drive.
-- Keep every part Anchored. Moving parts get CanCollide/CanTouch/CanQuery = false. With StreamingEnabled, set these
-- models' ModelStreamingMode to Atomic. Upload FX/*.png as Decals and paste the image ids into TEXTURES.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local TEXTURES = {
	Leaf = "rbxassetid://0", -- FX_Bush_Leaf.png
	Petal = "rbxassetid://0", -- FX_Bush_Petal.png (pink bushes)
	PetalTint = "rbxassetid://0", -- FX_Bush_PetalTint.png (white, tinted to the Petals colour of recoloured bushes)
	Pollen = "rbxassetid://0", -- FX_Bush_Pollen.png
	Firefly = "rbxassetid://0", -- FX_Bush_Firefly.png
	WindStreak = "rbxassetid://0", -- FX_Bush_WindStreak.png (Trail; image vertical axis runs along the ribbon)
	Droplet = "rbxassetid://0", -- FX_Fountain_Droplet.png
	Splash = "rbxassetid://0", -- FX_Fountain_Splash.png
	Ripple = "rbxassetid://0", -- FX_Fountain_Ripple.png (white, tinted)
}
local FALLBACK = "rbxasset://textures/particles/sparkles_main.dds"

local CONFIG = {
	SwayDeg = 3, MaxTiltDeg = 6, Period = 3,
	Amp = { Bush_TallGrass = 6, Flower_Tulip = 4, Flower_Daisy = 4, Flower_Sunflower = 3, Tree_Oak = 1.5 },
	WaveLength = 48, -- studs between wind crests rolling across the lawn
	AnimateRadius = 150, MaxAnimated = 100, FxRadius = 90,
	LeafPerMinute = 3, PetalPerMinute = 6, -- per nearby bush, at average wind (trees x3)
	PollenRate = 0.5, -- Flower bushes and flowers, daytime
	FireflyShare = 0.45, FireflyRate = 0.3, -- share of other plants hosting fireflies at night
	NightFrom = 18, NightTo = 6,
	RustleOnWalk = true, RustleDeg = 6, RustleCooldown = 1.2,
	WindStreaks = true, StreakEvery = { 2.5, 6 },
	DefaultWind = Vector3.new(1, 0, 0.3),
	WaterMaterial = Enum.Material.Glass,
	FountainSoundId = 0, -- e.g. a looping water sound asset id
	LampRange = 16, LampBrightness = 1.6, LampColor = Color3.fromRGB(255, 208, 138),
}

local PETAL_PINK = Color3.fromRGB(255, 120, 170)
local TAU = math.pi * 2

local function tex(k)
	local id = TEXTURES[k]
	return (id ~= "rbxassetid://0" and id) or FALLBACK
end
local function ns(...)
	local a, kp = { ... }, {}
	for i = 1, #a, 2 do table.insert(kp, NumberSequenceKeypoint.new(a[i], a[i + 1])) end
	return NumberSequence.new(kp)
end
local function hash(v)
	local n = math.sin(v.X * 12.9898 + v.Z * 78.233) * 43758.5453
	return n - math.floor(n)
end
local function gustAt(t) return 0.8 + 0.5 * (math.noise(t * 0.11, 3.7) + 0.5) end
local function find(m, n) return m:FindFirstChild(n, true) end

local GardenVFX = {}
local sways, list, active, streaks, conns = {}, {}, {}, {}, {}
local fountains, lamps = {}, {}
local wind = { Dir = CONFIG.DefaultWind.Unit, Strength = 1, Override = false }
local isNight, running, folder, nextStreak = false, false, nil, 0

-- geometry ----------------------------------------------------------------------------------------
local function partsOf(inst)
	if inst:IsA("BasePart") then return { inst } end
	local t = {}
	for _, d in inst:GetDescendants() do if d:IsA("BasePart") then table.insert(t, d) end end
	return t
end
local function bounds(frame, parts)
	local mn = Vector3.new(math.huge, math.huge, math.huge)
	local mx = -mn
	for _, p in parts do
		local cf, s = p.CFrame, p.Size / 2
		for i = 0, 7 do
			local c = cf * Vector3.new(i % 2 == 0 and -s.X or s.X, (i // 2) % 2 == 0 and -s.Y or s.Y, i // 4 == 0 and -s.Z or s.Z)
			local l = frame:PointToObjectSpace(c)
			mn, mx = mn:Min(l), mx:Max(l)
		end
	end
	return mn, mx
end
local function restore(rec)
	local ps, cfs = {}, {}
	for _, pc in rec.Pieces do
		for j, p in pc.Parts do table.insert(ps, p); table.insert(cfs, pc.Pivot * pc.Rest[j]) end
	end
	if #ps > 0 then workspace:BulkMoveTo(ps, cfs, Enum.BulkMoveMode.FireCFrameChanged) end
end
local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0
	for k, v in props do e[k] = v end
	e.Parent = parent
	return e
end

-- plant effects -----------------------------------------------------------------------------------
local function clearFx(rec)
	for _, i in rec.Fx or {} do i:Destroy() end
	rec.Fx, rec.Spot, rec.Leaf, rec.Petal, rec.Pollen, rec.Firefly = nil, nil, nil, nil, nil, nil
end
local function makeFx(rec)
	local s, fx, kind, cat = rec.Size, {}, rec.Kind, rec.Cat
	local function att(name, y)
		local a = Instance.new("Attachment")
		a.Name = name
		a.Parent = rec.Base
		a.WorldCFrame = rec.Ground * CFrame.new(0, y, 0)
		table.insert(fx, a)
		return a
	end
	local drift = {
		Lifetime = NumberRange.new(2.5, 4.5), Speed = NumberRange.new(1, 2.2), SpreadAngle = Vector2.new(70, 70),
		Drag = 0.8, Size = ns(0, 0.42, 1, 0.34), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-200, 200),
		Transparency = ns(0, 0, 0.8, 0, 1, 1), LightInfluence = 1, LightEmission = 0, ZOffset = 0.2,
	}
	rec.Spot = att("GardenFX_Spot", s.Y * 0.8)
	if cat == "Bush" or cat == "Tree" then
		rec.Leaf = emitter(rec.Spot, table.clone(drift))
		rec.Leaf.Texture = tex("Leaf")
	end
	if kind == "Bush_Flower" then
		local petals = rec.Model:FindFirstChild("Petals", true)
		local col = (petals and petals:IsA("BasePart")) and petals.Color or PETAL_PINK
		local pink = math.abs(col.R - PETAL_PINK.R) + math.abs(col.G - PETAL_PINK.G) + math.abs(col.B - PETAL_PINK.B) < 0.06
		rec.Petal = emitter(rec.Spot, table.clone(drift))
		rec.Petal.Texture = tex(pink and "Petal" or "PetalTint")
		rec.Petal.Color = ColorSequence.new(pink and Color3.new(1, 1, 1) or col)
	end
	if kind == "Bush_Flower" or cat == "Flower" then
		rec.Pollen = emitter(att("GardenFX_Pollen", s.Y + 0.3), {
			Texture = tex("Pollen"), Rate = CONFIG.PollenRate, Lifetime = NumberRange.new(3.5, 6),
			Speed = NumberRange.new(0.15, 0.45), SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 0.12, 0),
			Drag = 0.4, Size = ns(0, 0, 0.15, 0.22, 0.85, 0.18, 1, 0), Transparency = ns(0, 1, 0.15, 0.1, 0.8, 0.2, 1, 1),
			LightEmission = 0.35, LightInfluence = 0.6, Enabled = not isNight,
		})
	end
	if kind == "Bush_Flower" or kind == "Bush_TallGrass" or cat == "Flower" or rec.Hash < CONFIG.FireflyShare then
		rec.Firefly = emitter(att("GardenFX_Fireflies", math.min(s.Y * 0.6, 4)), {
			Texture = tex("Firefly"), Rate = CONFIG.FireflyRate, Lifetime = NumberRange.new(6, 9),
			Speed = NumberRange.new(0.25, 0.6), SpreadAngle = Vector2.new(180, 180), Drag = 0.35, Acceleration = Vector3.new(0, 0.04, 0),
			Size = ns(0, 0, 0.1, 0.45, 0.3, 0.3, 0.5, 0.5, 0.7, 0.28, 0.9, 0.45, 1, 0),
			Transparency = ns(0, 1, 0.1, 0, 0.25, 0.55, 0.4, 0, 0.6, 0.6, 0.75, 0, 1, 1),
			Color = ColorSequence.new(Color3.fromRGB(255, 226, 120)), LightEmission = 1, LightInfluence = 0, Brightness = 3,
			ZOffset = 0.5, Enabled = isNight,
		})
	end
	rec.Fx = fx
end
local function puff(rec, key, n)
	local e = rec[key]
	if not e then return end
	local s = rec.Size
	rec.Spot.WorldCFrame = rec.Ground * CFrame.new((math.random() - 0.5) * s.X * 0.8, s.Y * (0.6 + math.random() * 0.35), (math.random() - 0.5) * s.Z * 0.8)
	e.Acceleration = wind.Dir * (1.4 * wind.Strength) + Vector3.new(0, -1.3, 0)
	e:Emit(n)
end

-- wind streaks ------------------------------------------------------------------------------------
local function newStreak()
	local p = Instance.new("Part")
	p.Name, p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = "GardenWindStreak", true, false, false, false
	p.Transparency, p.Size, p.CastShadow = 1, Vector3.new(0.2, 0.2, 0.2), false
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, 0.14, 0), Vector3.new(0, -0.14, 0)
	a0.Parent, a1.Parent = p, p
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Texture, tr.TextureMode = tex("WindStreak"), Enum.TextureMode.Stretch
	tr.Lifetime, tr.MinLength, tr.FaceCamera = 0.55, 0.05, true
	tr.LightEmission, tr.LightInfluence = 0.6, 0.4
	tr.Transparency, tr.WidthScale = ns(0, 0.35, 1, 1), ns(0, 1, 1, 0.3)
	tr.Enabled = false
	tr.Parent = p
	p.Parent = folder
	return { Part = p, Trail = tr, T0 = 0, Dur = 0 }
end
local function spawnStreak(rec, t)
	local s
	for _, x in streaks do if not x.Live and t - x.T0 > x.Dur + 0.6 then s = x break end end
	if not s then
		if #streaks >= 4 then return end
		s = newStreak()
		table.insert(streaks, s)
	end
	local w = wind.Dir
	s.Dir, s.Perp = w, Vector3.new(-w.Z, 0, w.X)
	s.Start = rec.Ground.Position - w * 7 + s.Perp * ((math.random() - 0.5) * 6) + Vector3.new(0, 1.2 + math.random() * 2, 0)
	s.T0, s.Dur, s.Speed = t, 1.4 + math.random() * 0.6, 8 + math.random() * 4
	s.Part.CFrame = CFrame.new(s.Start)
	s.Trail:Clear()
	s.Live = true
end
local function updateStreaks(t)
	for _, s in streaks do
		if s.Live then
			local e = t - s.T0
			local k = e / s.Dur
			if k >= 1 then
				s.Live, s.Trail.Enabled = false, false
			else
				s.Part.CFrame = CFrame.new(s.Start + s.Dir * (s.Speed * e) + Vector3.yAxis * (math.sin(k * TAU * 1.3) * 0.35) + s.Perp * (math.sin(k * math.pi) * 0.8))
				s.Trail.Enabled = true
			end
		end
	end
end

-- registry ----------------------------------------------------------------------------------------
local unregister
local function watch(rec, model)
	rec.Conn = model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then unregister(model) end
	end)
end

local function registerSway(model)
	if sways[model] then return end
	local kind = model.Name:match("^ENV_Nature_(.+)$")
	local base = model:FindFirstChild("Base") or model:FindFirstChild("Trunk")
	if not base then
		for _, c in model:GetChildren() do if c:IsA("BasePart") then base = c break end end
	end
	if not (kind and base) or sways[model] then return end
	local f0 = CFrame.new(base.Position) * base.CFrame.Rotation
	local mn, mx = bounds(f0, partsOf(model))
	local ground = f0 * CFrame.new((mn.X + mx.X) / 2, mn.Y, (mn.Z + mx.Z) / 2)
	local rec = {
		Model = model, Kind = kind, Cat = kind:match("^(%a+)_") or kind, Base = base, Ground = ground, Size = mx - mn, Pieces = {},
		Hash = hash(ground.Position), R0 = -1e9, RDir = Vector3.xAxis, LastRustle = -1e9, Dist = math.huge,
		Amp = CONFIG.Amp[kind] or CONFIG.SwayDeg,
	}
	for _, child in model:GetChildren() do
		if child.Name:sub(1, 5) == "Sway_" then
			local parts = partsOf(child)
			if #parts > 0 then
				local a, b = bounds(ground, parts)
				local pivot = ground * CFrame.new((a.X + b.X) / 2, a.Y, (a.Z + b.Z) / 2)
				local rest = {}
				for j, p in parts do
					rest[j] = pivot:ToObjectSpace(p.CFrame)
					p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
				end
				table.insert(rec.Pieces, { Parts = parts, Rest = rest, Pivot = pivot, Phase = #rec.Pieces * 0.55 })
			end
		end
	end
	if #rec.Pieces == 0 then return end -- Rock, Mushroom: static
	sways[model] = rec
	table.insert(list, rec)
	watch(rec, model)
end

local function registerFountain(model)
	if fountains[model] then return end
	local water = find(model, "Water") or model:WaitForChild("Water", 5)
	local jet, upper, fall = find(model, "WaterJet"), find(model, "UpperWater"), find(model, "WaterFall")
	if not (water and water:IsA("BasePart") and jet) or fountains[model] then return end
	local k = water.Size.X / 7.6
	local rec = { Model = model, Water = water, Upper = upper, Jet = jet, Fall = fall, K = k, Fx = {}, Emitters = {}, Near = false,
		WaterCF = water.CFrame, UpperCF = upper and upper.CFrame, JetCF = jet.CFrame, JetSize = jet.Size, Pos = water.Position }
	local function wet(p, tr)
		if not p then return end
		p.Material, p.Transparency, p.Reflectance = CONFIG.WaterMaterial, tr, 0.1
		p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
	end
	wet(water, 0.2); wet(upper, 0.2); wet(fall, 0.35); wet(jet, 0.25)
	local function keep(i) table.insert(rec.Fx, i) return i end
	local function em(parent, props) local e = emitter(parent, props) table.insert(rec.Emitters, e) return e end
	rec.Tip = keep(Instance.new("Attachment"))
	rec.Tip.Name, rec.Tip.Position, rec.Tip.Parent = "FountainFX_Tip", Vector3.new(0, jet.Size.Y / 2, 0), jet
	em(rec.Tip, {
		Texture = tex("Droplet"), Rate = 35, Lifetime = NumberRange.new(0.55, 0.75), Speed = NumberRange.new(4 * k, 5.5 * k),
		SpreadAngle = Vector2.new(30, 30), Acceleration = Vector3.new(0, -24 * k, 0), Size = ns(0, 0.25 * k, 1, 0.16 * k),
		Transparency = ns(0, 0.1, 0.8, 0.25, 1, 1), Rotation = NumberRange.new(0, 360), LightInfluence = 0.8, LightEmission = 0.15, Enabled = false,
	})
	if fall then
		local s = fall.Size / 2
		for _, o in { Vector3.new(s.X - 0.08 * k, -s.Y, 0), Vector3.new(-s.X + 0.08 * k, -s.Y, 0), Vector3.new(0, -s.Y, s.Z - 0.08 * k), Vector3.new(0, -s.Y, -s.Z + 0.08 * k) } do
			local a = keep(Instance.new("Attachment"))
			a.Name, a.Position, a.Parent = "FountainFX_Splash", o, fall
			em(a, {
				Texture = tex("Splash"), Rate = 8, Lifetime = NumberRange.new(0.3, 0.45), Speed = NumberRange.new(1.2 * k, 2.2 * k),
				SpreadAngle = Vector2.new(50, 50), Acceleration = Vector3.new(0, -12 * k, 0), Size = ns(0, 0.3 * k, 1, 0.6 * k),
				Transparency = ns(0, 0.1, 1, 1), Rotation = NumberRange.new(0, 360), LightInfluence = 0.8, Enabled = false,
			})
		end
	end
	for _, w in { { water, 3, 2.2 }, { upper, 2, 1.2 } } do
		if w[1] then
			keep(em(w[1], {
				Texture = tex("Ripple"), Rate = w[2], Lifetime = NumberRange.new(1.2, 1.6), Speed = NumberRange.new(0.02, 0.05),
				Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, EmissionDirection = Enum.NormalId.Top,
				Orientation = Enum.ParticleOrientation.VelocityPerpendicular, Size = ns(0, 0.3 * k, 1, w[3] * k), Transparency = ns(0, 0.35, 1, 1),
				Color = ColorSequence.new(Color3.fromRGB(220, 245, 255)), LightInfluence = 0.6, ZOffset = 0.05, Enabled = false,
			}))
		end
	end
	if CONFIG.FountainSoundId ~= 0 then
		local snd = keep(Instance.new("Sound"))
		snd.SoundId, snd.Looped, snd.Volume = "rbxassetid://" .. CONFIG.FountainSoundId, true, 0.5
		snd.RollOffMode, snd.RollOffMaxDistance = Enum.RollOffMode.InverseTapered, 70 * k
		snd.Parent = water
		snd:Play()
	end
	fountains[model] = rec
	watch(rec, model)
end
local function restoreFountain(rec)
	rec.Jet.Size = rec.JetSize
	local ps, cfs = { rec.Water, rec.Jet }, { rec.WaterCF, rec.JetCF }
	if rec.Upper then table.insert(ps, rec.Upper); table.insert(cfs, rec.UpperCF) end
	workspace:BulkMoveTo(ps, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	rec.Tip.Position = Vector3.new(0, rec.JetSize.Y / 2, 0)
end

local function setLamp(rec, on, instant)
	rec.Light.Material = on and Enum.Material.Neon or rec.Material
	local b = on and CONFIG.LampBrightness or 0
	if instant then rec.PL.Brightness = b else TweenService:Create(rec.PL, TweenInfo.new(1.2), { Brightness = b }):Play() end
end
local function registerLamp(model)
	if lamps[model] then return end
	local light = find(model, "Light") or model:WaitForChild("Light", 5)
	if not (light and light:IsA("BasePart")) or lamps[model] then return end
	local pl = Instance.new("PointLight")
	pl.Name, pl.Range, pl.Brightness, pl.Color, pl.Shadows = "GardenVFX_Lamp", CONFIG.LampRange * light.Size.Y, 0, CONFIG.LampColor, false
	pl.Parent = light
	local rec = { Model = model, Light = light, Material = light.Material, PL = pl }
	lamps[model] = rec
	watch(rec, model)
	setLamp(rec, isNight, true)
end

local function register(model)
	if not model:IsDescendantOf(workspace) then return end
	local n = model.Name
	if n:match("^ENV_Prop_Fountain") then registerFountain(model)
	elseif n:match("^ENV_Prop_LampPost") then registerLamp(model)
	elseif n:match("^ENV_Nature_") then registerSway(model) end
end
function unregister(model)
	local rec = sways[model]
	if rec then
		sways[model] = nil
		local i = table.find(list, rec)
		if i then table.remove(list, i) end
		i = table.find(active, rec)
		if i then table.remove(active, i) end
		rec.Conn:Disconnect()
		restore(rec)
		clearFx(rec)
	end
	rec = fountains[model]
	if rec then
		fountains[model] = nil
		rec.Conn:Disconnect()
		restoreFountain(rec)
		for _, i in rec.Fx do i:Destroy() end
	end
	rec = lamps[model]
	if rec then
		lamps[model] = nil
		rec.Conn:Disconnect()
		rec.Light.Material = rec.Material
		rec.PL:Destroy()
	end
end

-- per-frame ---------------------------------------------------------------------------------------
local movedParts, movedCFs = {}, {}
local function step(t)
	local w, gust = wind.Dir, gustAt(t)
	local omega, maxT = TAU / CONFIG.Period, math.rad(CONFIG.MaxTiltDeg)
	table.clear(movedParts)
	table.clear(movedCFs)
	local n = 0
	for _, rec in active do
		local wl = rec.Ground:VectorToObjectSpace(w)
		local flat = Vector3.new(wl.X, 0, wl.Z)
		local wd = flat.Magnitude > 1e-3 and flat.Unit or Vector3.xAxis
		local wp = Vector3.new(-wd.Z, 0, wd.X)
		local crest = -TAU * rec.Ground.Position:Dot(w) / CONFIG.WaveLength
		local amp = math.rad(rec.Amp) * gust * wind.Strength
		local rt = t - rec.R0
		local rA = rt < 1.6 and math.rad(CONFIG.RustleDeg) * math.exp(-3.2 * rt) * math.sin(TAU * 2.2 * rt) or 0
		for _, pc in rec.Pieces do
			local ph = crest + pc.Phase + rec.Hash * 2
			local lean = wd * (amp * math.sin(omega * t + ph)) + wp * (amp * 0.3 * math.sin(omega * 1.37 * t + ph * 1.7)) + rec.RDir * rA
			local m = lean.Magnitude
			local pcf = pc.Pivot
			if m > 1e-5 then
				local d = lean / m
				pcf = pcf * CFrame.fromAxisAngle(Vector3.new(d.Z, 0, -d.X), math.min(m, maxT))
			end
			for j, p in pc.Parts do
				n += 1
				movedParts[n], movedCFs[n] = p, pcf * pc.Rest[j]
			end
		end
	end
	for _, rec in fountains do
		if rec.Near then
			local k = rec.K
			n += 1
			movedParts[n], movedCFs[n] = rec.Water, rec.WaterCF * CFrame.new(0, math.sin(t * 1.6) * 0.025 * k, 0)
			if rec.Upper then
				n += 1
				movedParts[n], movedCFs[n] = rec.Upper, rec.UpperCF * CFrame.new(0, -math.sin(t * 1.6 + 0.8) * 0.025 * k, 0)
			end
			local sy = rec.JetSize.Y * (1 + 0.12 * math.sin(t * 5) + 0.06 * math.sin(t * 9.7))
			rec.Jet.Size = Vector3.new(rec.JetSize.X, sy, rec.JetSize.Z)
			rec.Tip.Position = Vector3.new(0, sy / 2, 0)
			n += 1
			movedParts[n], movedCFs[n] = rec.Jet, rec.JetCF * CFrame.new(0, (sy - rec.JetSize.Y) / 2, 0)
			if rec.Fall then rec.Fall.Transparency = 0.35 + 0.06 * math.sin(t * 7) end
		end
	end
	if n > 0 then workspace:BulkMoveTo(movedParts, movedCFs, Enum.BulkMoveMode.FireCFrameChanged) end
end

local function rustle(rec, from, t)
	if rec.Cat ~= "Bush" and rec.Cat ~= "Flower" then return end
	t = t or os.clock()
	rec.LastRustle, rec.R0 = t, t
	local away = rec.Ground:PointToObjectSpace(from) * Vector3.new(-1, 0, -1)
	rec.RDir = away.Magnitude > 0.01 and away.Unit or Vector3.xAxis
	if rec.Fx then
		puff(rec, "Leaf", math.random(2, 4))
		if rec.Petal then puff(rec, "Petal", math.random(2, 3)) end
		if rec.Pollen and not isNight then rec.Pollen:Emit(4) end
		if rec.Firefly and isNight then rec.Firefly:Emit(2) end
	end
end

local function refreshActive()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local cp = cam.CFrame.Position
	local cand = {}
	for _, rec in list do
		rec.Dist = (rec.Ground.Position - cp).Magnitude
		if rec.Dist <= CONFIG.AnimateRadius then table.insert(cand, rec) end
	end
	table.sort(cand, function(a, b) return a.Dist < b.Dist end)
	for i = #cand, CONFIG.MaxAnimated + 1, -1 do cand[i] = nil end
	local keep = {}
	for _, rec in cand do keep[rec] = true end
	for _, rec in active do if not keep[rec] then restore(rec) end end
	active = cand
	for _, rec in list do
		if keep[rec] and rec.Dist <= CONFIG.FxRadius then
			if not rec.Fx then makeFx(rec) end
		elseif rec.Fx and rec.Dist > CONFIG.FxRadius * 1.2 then
			clearFx(rec)
		end
	end
	for _, rec in fountains do
		local near = (rec.Pos - cp).Magnitude <= CONFIG.FxRadius
		if near ~= rec.Near then
			rec.Near = near
			for _, e in rec.Emitters do e.Enabled = near end
			if not near then restoreFountain(rec) end
		end
	end
end

local function ambient(t)
	local g = gustAt(t) * wind.Strength
	local pLeaf = CONFIG.LeafPerMinute / 60 * 0.25 * g * g
	local pPetal = CONFIG.PetalPerMinute / 60 * 0.25 * g * g
	local near = {}
	for _, rec in active do
		if rec.Fx then
			table.insert(near, rec)
			if math.random() < pLeaf * (rec.Cat == "Tree" and 3 or 1) then puff(rec, "Leaf", 1) end
			if rec.Petal and math.random() < pPetal then puff(rec, "Petal", 1) end
		end
	end
	if CONFIG.WindStreaks and t > nextStreak and #near > 0 then
		local lo, hi = CONFIG.StreakEvery[1], CONFIG.StreakEvery[2]
		nextStreak = t + (lo + math.random() * (hi - lo)) / g
		spawnStreak(near[math.random(#near)], t)
	end
end

local function checkWalkers(t)
	for _, plr in Players:GetPlayers() do
		local ch = plr.Character
		local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
		if hrp and hrp.AssemblyLinearVelocity.Magnitude > 2 then
			local pos = hrp.Position
			for _, rec in active do
				if (rec.Cat == "Bush" or rec.Cat == "Flower") and t - rec.LastRustle > CONFIG.RustleCooldown then
					local l, s = rec.Ground:PointToObjectSpace(pos), rec.Size
					if math.abs(l.X) < s.X / 2 + 0.8 and math.abs(l.Z) < s.Z / 2 + 0.8 and l.Y > -1 and l.Y < s.Y + 3 then
						rustle(rec, pos, t)
					end
				end
			end
		end
	end
end

local function updateWind()
	if wind.Override then return end
	local g = workspace.GlobalWind
	local flat = Vector3.new(g.X, 0, g.Z)
	if flat.Magnitude > 0.1 then
		wind.Dir, wind.Strength = flat.Unit, math.clamp(g.Magnitude / 12, 0.5, 2)
	else
		wind.Dir, wind.Strength = CONFIG.DefaultWind.Unit, 1
	end
end

local function updateNight()
	local c = Lighting.ClockTime
	local night = c >= CONFIG.NightFrom or c < CONFIG.NightTo
	if night == isNight then return end
	isNight = night
	for _, rec in list do
		if rec.Pollen then rec.Pollen.Enabled = not night end
		if rec.Firefly then rec.Firefly.Enabled = night end
	end
	for _, rec in lamps do setLamp(rec, night, false) end
end

-- API ---------------------------------------------------------------------------------------------
local function tracked(d)
	if not d:IsA("Model") then return false end
	local n = d.Name
	return n:match("^ENV_Nature_") ~= nil or n:match("^ENV_Prop_Fountain") ~= nil or n:match("^ENV_Prop_LampPost") ~= nil
end

function GardenVFX.Start()
	if running then return end
	running = true
	folder = Instance.new("Folder")
	folder.Name = "GardenVFX"
	folder.Parent = workspace
	updateNight()
	for _, d in workspace:GetDescendants() do if tracked(d) then task.spawn(register, d) end end
	table.insert(conns, workspace.DescendantAdded:Connect(function(d)
		if tracked(d) then task.defer(register, d) end
	end))
	updateWind()
	local acc = { active = 1, walk = 0, amb = 0, slow = 0 }
	table.insert(conns, RunService.Heartbeat:Connect(function(dt)
		local t = os.clock()
		acc.active += dt; acc.walk += dt; acc.amb += dt; acc.slow += dt
		if acc.slow > 1 then acc.slow = 0; updateWind(); updateNight() end
		if acc.active > 0.5 then acc.active = 0; refreshActive() end
		if CONFIG.RustleOnWalk and acc.walk > 0.1 then acc.walk = 0; checkWalkers(t) end
		if acc.amb > 0.25 then acc.amb = 0; ambient(t) end
		step(t)
		updateStreaks(t)
	end))
end

function GardenVFX.Stop()
	if not running then return end
	running = false
	for _, c in conns do c:Disconnect() end
	table.clear(conns)
	local models = {}
	for m in sways do table.insert(models, m) end
	for m in fountains do table.insert(models, m) end
	for m in lamps do table.insert(models, m) end
	for _, m in models do unregister(m) end
	table.clear(streaks)
	if folder then folder:Destroy(); folder = nil end
end

function GardenVFX.Rustle(model, from)
	local rec = sways[model]
	if rec then rustle(rec, from or (rec.Ground * Vector3.new(0, 0, -3))) end
end

function GardenVFX.SetWind(dir, strength)
	if not dir then wind.Override = false; updateWind(); return end
	local flat = Vector3.new(dir.X, 0, dir.Z)
	wind.Override = true
	wind.Dir = flat.Magnitude > 1e-3 and flat.Unit or wind.Dir
	wind.Strength = strength or 1
end

function GardenVFX.Refresh(model)
	unregister(model)
	register(model)
end

GardenVFX.CONFIG, GardenVFX.TEXTURES = CONFIG, TEXTURES
return GardenVFX
