--!nocheck
-- a204 : ce qui manque au faux Roblox (Model:GetScale/ScaleTo, pistes avec Length, TimePosition qui avance et
-- marqueurs tirés à leur instant, GetTimeOfKeyframe, ParticleEmitter:Emit), arbre du client (Reveal/, bouchons),
-- magasins du banc (Bounds, emplacement, colis, plafonds), sons et écrans.

---------------------------------------------------------------- faux Roblox
if Methods.GetScale == nil then
	function Methods.GetScale(self)
		return rawget(self, "_benchScale") or 1
	end
	function Methods.ScaleTo(self, s)
		assert(type(s) == "number" and s > 0, "ScaleTo : taille > 0")
		local f = s / Methods.GetScale(self)
		local pivot = Methods.GetPivot(self)
		local primary = self.PrimaryPart
		for _, p in Methods.GetDescendants(self) do
			if p:IsA("BasePart") then
				local rel = pivot:PointToObjectSpace(p.CFrame.Position)
				p.Size = p.Size * f
				p.CFrame = CFrame.new(pivot * (rel * f)) * p.CFrame.Rotation
				if p == primary then
					p.PivotOffset = CFrame.new(p.PivotOffset.Position * f) * p.PivotOffset.Rotation
				end
			end
		end
		rawset(self, "_benchScale", s)
	end
end
EMITS = {}
if Methods.Emit == nil then
	function Methods.Emit(self, n)
		table.insert(EMITS, { emitter = self, n = n })
	end
end
BENCH_TRACKS = {}
local baseLoad = Methods.LoadAnimation
function Methods.LoadAnimation(self, animation)
	local track = baseLoad(self, animation)
	track.Length = animation:GetAttribute("BenchLength") or 0
	track.benchMarkers = {}
	for name, at in string.gmatch(animation:GetAttribute("BenchMarkers") or "", "(%a+)=([%d%.]+)") do
		table.insert(track.benchMarkers, { name = name, t = tonumber(at) })
	end
	local play = track.Play
	function track.Play(t, ...)
		play(t, ...)
		t.TimePosition = 0
		t.fired = {}
		table.insert(BENCH_TRACKS, t)
	end
	function track.GetTimeOfKeyframe(t, name)
		if animation:GetAttribute("BenchKeyframes") then
			for _, m in t.benchMarkers do
				if m.name == name then
					return m.t
				end
			end
		end
		error("keyframe " .. name .. " absent")
	end
	return track
end
HEARTBEAT:Connect(function(dt)
	for i = #BENCH_TRACKS, 1, -1 do
		local t = BENCH_TRACKS[i]
		if not t.IsPlaying then
			table.remove(BENCH_TRACKS, i)
		elseif t.Length > 0 then
			local before = t.TimePosition
			t.TimePosition = math.min(before + dt * t.Speed, t.Length)
			for _, m in t.benchMarkers do
				if not t.fired[m] and m.t <= t.TimePosition + 1e-9 then
					t.fired[m] = true
					t:GetMarkerReachedSignal(m.name):Fire(m.name)
				end
			end
			if t.TimePosition >= t.Length then
				table.remove(BENCH_TRACKS, i)
				t:Stop()
			end
		end
	end
end)

---------------------------------------------------------------- arbre du client
local revealFolder = folder(CONTROLLERS, "Reveal")
moduleScript(revealFolder, "Logic", "client/Controllers/Reveal/Logic.luau")
moduleScript(revealFolder, "Ceiling", "client/Controllers/Reveal/Ceiling.luau")
-- a220 (2026-11-16) : Reveal/Shelf (le meuble qui casse), s'il est dans l'arbre testé.
if SOURCES["client/Controllers/Reveal/Shelf.luau"] then
	moduleScript(revealFolder, "Shelf", "client/Controllers/Reveal/Shelf.luau")
end
local uiFolder = CONTROLLERS:FindFirstChild("UI") or folder(CONTROLLERS, "UI")
if not uiFolder:FindFirstChild("HudMask") then
	moduleScript(uiFolder, "HudMask", "client/Controllers/UI/HudMask.luau")
end
SOURCES["stub/Shatter204"] = [==[
local S = { low = false }
function S.IsLowEnd() return S.low end
return S
]==]
SOURCES["stub/Feel204"] = [==[
local F = { flashes = 0 }
function F.RevealFlash() F.flashes += 1 end
return F
]==]
moduleScript(CONTROLLERS, "ShatterController", "stub/Shatter204")
moduleScript(CONTROLLERS, "UiFeelController", "stub/Feel204")

---------------------------------------------------------------- magasins
-- STORES[1] = STORE_Z1_Left (x 65, z -45 ; vitrine z -30.75) : plafond greybox d'une pièce + RoofSlab + lumière ;
-- STORES[2] = STORE_Z1_Right (z +45) : plafond + CeilingFractured (12 éclats invisibles) ; STORES[3] (Z2) : rien.
function fitStore(store, ceiling, shards)
	store:SetAttribute("StoreId", store.Name)
	local base = store:FindFirstChild("Base")
	local c = base.Position
	make("Part", { Name = "Bounds", Anchored = true, CanCollide = false, Transparency = 1, Size = Vector3.new(30, 12, 28), CFrame = CFrame.new(c.X, 6.5, c.Z) }, store)
	local side = if c.Z < 0 then -1 else 1
	-- Emplacement au fond du magasin (côté opposé à la vitrine) : l'allée est vers la vitrine.
	local slot = make("Attachment", { Name = "ShelfSlot_03", CFrame = CFrame.new(0, 0.5, side * 10) }, base)
	local box = make("Part", { Name = "ShelfBox", Anchored = true, Size = Vector3.new(2, 1.6, 2), CFrame = CFrame.new(slot.WorldCFrame.Position + Vector3.new(0, 0.8, 0)) }, store)
	box:SetAttribute("Slot", "ShelfSlot_03")
	box:SetAttribute("SlotId", store.Name .. "/03")
	addTag(box, "ShelfBox")
	if ceiling then
		make("Part", { Name = "Ceiling", Anchored = true, Size = Vector3.new(30, 0.1, 28), Color = Color3.new(0.9, 0.9, 0.85), CFrame = CFrame.new(c.X, 9.95, c.Z) }, store)
		make("Part", { Name = "RoofSlab", Anchored = true, Size = Vector3.new(30, 0.8, 28), CFrame = CFrame.new(c.X, 10.4, c.Z) }, store)
		make("Part", { Name = "CeilingLight_01", Anchored = true, Size = Vector3.new(2, 0.2, 2), CFrame = CFrame.new(c.X, 9.8, c.Z) }, store)
	end
	if shards then
		local fractured = make("Model", { Name = "CeilingFractured" }, store)
		for i = 1, shards do
			make("Part", { Name = string.format("Shard_%02d", i), Anchored = true, Transparency = 1, Size = Vector3.new(2, 0.1, 2), CFrame = CFrame.new(c.X + (i - 6) * 2, 9.95, c.Z) }, fractured)
		end
	end
	return slot, box
end
SLOT1, BOX1 = fitStore(STORES[1], true, nil)
SLOT2, BOX2 = fitStore(STORES[2], true, 12)
SLOT3, BOX3 = fitStore(STORES[3], false, nil)
for i = 4, #STORES do
	fitStore(STORES[i], false, nil)
end

---------------------------------------------------------------- objets, sons
local ItemsCfg = sharedModule("Config/Items", "client")
ITEM_A, ITEM_B = nil, nil
for _, def in ItemsCfg.List do
	if def.Zone ~= nil then
		if ITEM_A == nil then
			ITEM_A = def
		elseif ITEM_B == nil then
			ITEM_B = def
		end
	end
end
local itemsFolder = folder(ASSETS, "Items")
ITEM_MODEL = make("Model", { Name = ITEM_A.Asset }, itemsFolder)
local body = make("Part", { Name = "Body", Anchored = false, Size = Vector3.new(2, 2, 2), CFrame = CFrame.new(0, 1, 0), PivotOffset = CFrame.new(0, -1, 0) }, ITEM_MODEL)
make("Part", { Name = "Top", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(0, 2.5, 0) }, ITEM_MODEL)
make("Script", { Name = "Bad" }, ITEM_MODEL)
ITEM_MODEL.PrimaryPart = body
for _, name in { "Unbox_Open", "Unbox_UpgradePop", "Unbox_Confetti", "Glass_BreakShatter", "Ceiling_Crash", "Ceiling_Debris" } do
	make("Sound", { Name = name, SoundId = "rbxassetid://9" }, SOUNDS_FOLDER)
end
-- Copies de son jouées (n'importe où hors du dossier des sons), et celles posées sur une pièce (3D).
function playedSounds(name)
	local all, on3d = 0, 0
	for _, place in { SoundService, Workspace } do
		for _, d in place:GetDescendants() do
			if d:IsA("Sound") and d.Name == name then
				all += 1
				if d.Parent:IsA("BasePart") then
					on3d += 1
				end
			end
		end
	end
	return all, on3d
end

---------------------------------------------------------------- rig de caméra de Clément
CINEMATICS = folder(ASSETS, "Cinematics")
-- anims : { [nom] = { durée, "Open=0.2,Reveal=0.5", images clés nommées ? } } ; nil = rig sans dossier Animations.
function buildRig(anims, noController)
	dropRig()
	local rig = make("Model", { Name = "CAM_Reveal" }, CINEMATICS)
	local rootPart = make("Part", { Name = "Root", Anchored = true, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(0, 0, 0) }, rig)
	rig.PrimaryPart = rootPart
	make("Part", { Name = "ItemAnchor", Anchored = true, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(0, 0, 0) }, rig)
	make("Part", { Name = "CameraPart", Anchored = true, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(0, 3, -8) }, rig)
	if not noController then
		local ctrl = make("AnimationController", { Name = "AnimationController" }, rig)
		make("Animator", { Name = "Animator" }, ctrl)
	end
	if anims then
		local f = folder(rig, "Animations")
		for name, spec in anims do
			local a = make("Animation", { Name = name, AnimationId = "rbxassetid://" .. tostring(#name) }, f)
			a:SetAttribute("BenchLength", spec[1])
			a:SetAttribute("BenchMarkers", spec[2])
			if spec[3] then
				a:SetAttribute("BenchKeyframes", true)
			end
		end
	end
	return rig
end
function dropRig()
	local old = CINEMATICS and CINEMATICS:FindFirstChild("CAM_Reveal")
	if old then
		old:Destroy()
	end
end
