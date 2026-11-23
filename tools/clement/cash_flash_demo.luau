--[[
	cash_flash_demo.luau (Clément, 2026-11-23) : aperçu du « jus » de l'encaissement, en Edit, sans Play.
	À lancer depuis la barre de commande (ou execute_luau, contexte Edit) après cash_flash_build.luau.

	Dans la boutique PLOT_Shop_02 du hub, une tournée de 8 plaques en zigzag (01, 03, 04, 02, deux fois) :
	  - la plaque s'enfonce, sa gerbe part (BurstPoint), Glow s'allume (comme DisplayController) ;
	  - 8 billets et pièces (FX_Collect_Bill / FX_Collect_Coin) jaillissent puis filent vers le compteur
	    (comme VfxController) ;
	  - « +$X » monte au-dessus de la plaque (copie de BB_Gain) ;
	  - le voile vert UI_CashFlash s'allume, un peu plus fort à chaque plaque de la tournée ;
	  - au premier billet arrivé : le kaching Cash_Pad, le compteur grossit (×1,15) et défile jusqu'au
	    nouveau total.
	Le « +$X » est posé ici sur la plaque pour l'aperçu ; en jeu, Clément le garde au-dessus du joueur.
	(Version du 2026-11-23 après le choix de Clément : un seul son, sans note qui monte.)

	Tout est remis comme avant à la fin (caméra, textes, plaques, écrans) ; rien n'est laissé.
	MODE = "play" (aperçu), "pose" (une image fixe pour une capture), "restore" (après "pose").
]]

local MODE = "play"
local SILENT = false -- true : aucun son
local ONLY = nil -- Label d'une tournée de RUNS pour ne jouer qu'elle

local RUNS = {
	{ Label = "A", Title = "Kaching à chaque plaque" },
}
local ORDER = { "CollectPad_01", "CollectPad_03", "CollectPad_04", "CollectPad_02" }
local GAPS = { 0.3, 0.7, 0.3, 0.7 } -- s entre deux plaques : 7 studs puis 22 studs en courant
local AMOUNTS = { 1240, 860, 2310, 1720, 980, 3150, 1460, 2080 }
local PAUSE = 2.2 -- s entre deux tournées (la tournée se remet à zéro)

local CAM_POS = Vector3.new(-77.5, 10.5, 61)
local CAM_LOOK = Vector3.new(-77.5, 1.2, 90)

local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local DEMO = "_CLAUDE_CashDemo"
local shop = workspace.Map.Hub.Shops.PLOT_Shop_02
local cam = workspace.CurrentCamera
local flash = StarterGui:FindFirstChild("UI_CashFlash")
assert(flash, "UI_CashFlash manque : lancer cash_flash_build.luau d'abord")
local cashRow = StarterGui.UI_HUD.BottomLeft.StatsPanel.CashRow
local cashLabel = cashRow.Cash
local sounds = ReplicatedStorage.Assets.Sounds.Cash
local fx = ReplicatedStorage.Assets.FX
local bbGain = ReplicatedStorage.Assets.UI.BB_Gain

local pads = {}
for _, name in ORDER do
	local pad = shop:FindFirstChild(name, true)
	assert(pad, name .. " introuvable dans " .. shop:GetFullName())
	table.insert(pads, pad)
end

local function fmt(n: number): string
	if n >= 1e6 then
		return string.format("$%.1fM", n / 1e6)
	elseif n >= 1e3 then
		return string.format("$%.1fK", n / 1e3)
	end
	return "$" .. math.floor(n)
end

------------------------------------------------------------------------------------------------
-- État d'avant, gardé en attributs sur le dossier de l'aperçu (pour "restore")
------------------------------------------------------------------------------------------------

local function save(folder: Folder)
	folder:SetAttribute("CamCFrame", cam.CFrame)
	folder:SetAttribute("CamFocus", cam.Focus)
	folder:SetAttribute("CamFov", cam.FieldOfView)
	folder:SetAttribute("CashText", cashLabel.Text)
	for i, pad in pads do
		local plate = pad.Plate
		folder:SetAttribute("Plate" .. i, plate.CFrame)
		folder:SetAttribute("Amount" .. i, plate.AmountGui.Amount.Text)
		folder:SetAttribute("AmountOn" .. i, plate.AmountGui.Enabled)
		folder:SetAttribute("Glow" .. i, plate.Glow.Enabled)
	end
	for _, band in flash.EdgeGlow:GetChildren() do
		if band:IsA("Frame") then
			folder:SetAttribute("Band" .. band.Name, band.BackgroundTransparency)
		end
	end
end

local function restore()
	local folder = workspace:FindFirstChild(DEMO)
	if not folder then
		return "rien à remettre"
	end
	cam.CFrame = folder:GetAttribute("CamCFrame")
	cam.Focus = folder:GetAttribute("CamFocus")
	cam.FieldOfView = folder:GetAttribute("CamFov")
	cashLabel.Text = folder:GetAttribute("CashText")
	for i, pad in pads do
		local plate = pad.Plate
		plate.CFrame = folder:GetAttribute("Plate" .. i)
		plate.AmountGui.Amount.Text = folder:GetAttribute("Amount" .. i)
		plate.AmountGui.Enabled = folder:GetAttribute("AmountOn" .. i)
		plate.Glow.Enabled = folder:GetAttribute("Glow" .. i)
	end
	for _, band in flash.EdgeGlow:GetChildren() do
		local t = folder:GetAttribute("Band" .. band.Name)
		if band:IsA("Frame") and t then
			band.BackgroundTransparency = t
		end
	end
	flash.Enabled = false
	local scale = cashRow:FindFirstChild("_ClaudeDemoScale")
	if scale then
		scale:Destroy()
	end
	local title = StarterGui:FindFirstChild("_CLAUDE_DemoTitle")
	if title then
		title:Destroy()
	end
	local audio = SoundService:FindFirstChild(DEMO)
	if audio then
		audio:Destroy()
	end
	folder:Destroy()
	return "remis comme avant"
end

if MODE == "restore" then
	return restore()
end
if workspace:FindFirstChild(DEMO) then
	restore()
end

local folder = Instance.new("Folder")
folder.Name = DEMO
save(folder)
folder.Parent = workspace

cam.CFrame = CFrame.lookAt(CAM_POS, CAM_LOOK)
cam.Focus = CFrame.new(CAM_LOOK)
cam.FieldOfView = 70

local scale = Instance.new("UIScale")
scale.Name = "_ClaudeDemoScale"
scale.Parent = cashRow

local titleGui = Instance.new("ScreenGui")
titleGui.Name = "_CLAUDE_DemoTitle"
titleGui.DisplayOrder = 100
local title = Instance.new("TextLabel")
title.AnchorPoint = Vector2.new(0.5, 0)
title.Position = UDim2.fromScale(0.5, 0.06)
title.Size = UDim2.fromScale(0.6, 0.06)
title.BackgroundTransparency = 1
title.TextScaled = true
title.TextColor3 = Color3.new(1, 1, 1)
title.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold)
title.Text = ""
local stroke = Instance.new("UIStroke")
stroke.Thickness = 2
stroke.Parent = title
title.Parent = titleGui
titleGui.Parent = StarterGui

------------------------------------------------------------------------------------------------
-- Sons (nouvelle API audio : elle joue en Edit)
------------------------------------------------------------------------------------------------

local audioRoot = Instance.new("Folder")
audioRoot.Name = DEMO
audioRoot.Parent = SoundService
local device = Instance.new("AudioDeviceOutput")
device.Parent = audioRoot
local fader = Instance.new("AudioFader")
fader.Volume = if SILENT then 0 else 1
fader.Parent = audioRoot

local function wire(a: Instance, b: Instance)
	local w = Instance.new("Wire")
	w.SourceInstance = a
	w.TargetInstance = b
	w.Parent = a
end
wire(fader, device)

local padSound = sounds.Cash_Pad
ContentProvider:PreloadAsync({ padSound })

local function play(sound: Sound, speed: number)
	local p = Instance.new("AudioPlayer")
	p.Asset = sound.SoundId
	p.Volume = sound.Volume
	p.PlaybackSpeed = speed
	p.Parent = audioRoot
	wire(p, fader)
	task.spawn(function()
		local t0 = os.clock()
		while not p.IsReady and os.clock() - t0 < 1 do
			task.wait()
		end
		p:Play()
		task.wait(2)
		p:Destroy()
	end)
end

------------------------------------------------------------------------------------------------
-- Effets
------------------------------------------------------------------------------------------------

local bands = {}
for _, band in flash.EdgeGlow:GetChildren() do
	if band:IsA("Frame") then
		bands[band] = band.BackgroundTransparency -- le plus fort, posé par Clément
		band.BackgroundTransparency = 1
	end
end

local flashToken = 0
local function edge(rank: number)
	flashToken += 1
	local mine = flashToken
	flash.Enabled = true
	local k = math.clamp((rank - 1) / 7, 0, 1)
	for band, peak in bands do
		local goal = peak + (1 - peak) * 0.45 * (1 - k) -- plus fort à chaque plaque de la tournée
		TweenService:Create(band, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = goal }):Play()
	end
	task.delay(0.18, function()
		if mine ~= flashToken then
			return
		end
		for band in bands do
			TweenService:Create(band, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 }):Play()
		end
		task.delay(0.5, function()
			if mine == flashToken then
				flash.Enabled = false
			end
		end)
	end)
end

local shown = 48200
local rollToken = 0
local function counter(add: number)
	local from, to = shown, shown + add
	shown = to
	rollToken += 1
	local mine = rollToken
	scale.Scale = 1
	TweenService:Create(scale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.15 }):Play()
	task.delay(0.08, function()
		TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < 0.3 and mine == rollToken do
			local u = (os.clock() - t0) / 0.3
			cashLabel.Text = fmt(from + (to - from) * u)
			task.wait()
		end
		if mine == rollToken then
			cashLabel.Text = fmt(to)
		end
	end)
end

local rng = Random.new(7)
local function quadOut(u: number) return 1 - (1 - u) * (1 - u) end
local function quadIn(u: number) return u * u end

local function target(): Vector3
	local c = cashLabel.AbsolutePosition + cashLabel.AbsoluteSize / 2
	local ray = cam:ViewportPointToRay(c.X, c.Y)
	return ray.Origin + ray.Direction * 3
end

local function bills(from: Vector3, count: number, onFirst: () -> ())
	local first = true
	for i = 1, count do
		local model = (if i % 2 == 0 then fx.FX_Collect_Coin else fx.FX_Collect_Bill):Clone()
		local start = from + Vector3.new(0, 0.3, 0)
		local pop = start + Vector3.new(rng:NextNumber(-1.5, 1.5), rng:NextNumber(2, 3.5), rng:NextNumber(-1.5, 1.5))
		local spin = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)).Unit * math.rad(720)
		local flyTime = rng:NextNumber(0.4, 0.5)
		model:PivotTo(CFrame.new(start))
		model.Parent = folder
		task.spawn(function()
			local t0 = os.clock()
			local angle = Vector3.zero
			local last = t0
			local function rot(now: number): CFrame
				angle += spin * (now - last)
				last = now
				return CFrame.Angles(angle.X, angle.Y, angle.Z)
			end
			while os.clock() - t0 < 0.2 do
				local now = os.clock()
				model:PivotTo(CFrame.new(start:Lerp(pop, quadOut((now - t0) / 0.2))) * rot(now))
				task.wait()
			end
			local wait = (i - 1) * 0.04
			local t1 = os.clock()
			while os.clock() - t1 < wait do
				model:PivotTo(CFrame.new(pop) * rot(os.clock()))
				task.wait()
			end
			local t2 = os.clock()
			while os.clock() - t2 < flyTime do
				local now = os.clock()
				local u = quadIn((now - t2) / flyTime)
				model:PivotTo(CFrame.new(pop:Lerp(target(), u)) * rot(now))
				pcall(model.ScaleTo, model, 1 - 0.75 * u)
				task.wait()
			end
			model:Destroy()
			if first then
				first = false
				onFirst()
			end
		end)
	end
end

local function plus(plate: BasePart, amount: number)
	local gui = bbGain:Clone()
	gui.Adornee = plate
	local label = gui.Row.Amount
	label.Text = "+" .. fmt(amount)
	label.TextColor3 = bbGain:GetAttribute("CashColor") or Color3.fromHex("5CFF4A")
	gui.Row.Icon.Image = bbGain:GetAttribute("CashIcon") or gui.Row.Icon.Image
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
	gui.Parent = folder
	TweenService:Create(gui, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = Vector3.new(0, 5, 0) }):Play()
	task.delay(0.6, function()
		TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		TweenService:Create(gui.Row.Icon, TweenInfo.new(0.3), { ImageTransparency = 1 }):Play()
	end)
end

local function collect(index: number, rank: number, run)
	local pad = pads[index]
	local plate: BasePart = pad.Plate
	local amount = AMOUNTS[((rank - 1) % #AMOUNTS) + 1]
	local base = folder:GetAttribute("Plate" .. index)
	-- la plaque s'enfonce, la gerbe part, Glow s'allume
	local sink = plate:GetAttribute("SinkDepth") or 0.1
	TweenService:Create(plate, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = base - Vector3.new(0, sink, 0) }):Play()
	task.delay(0.06, function()
		TweenService:Create(plate, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = base }):Play()
	end)
	for _, e in plate.BurstPoint:GetChildren() do
		if e:IsA("ParticleEmitter") then
			e:Emit(e:GetAttribute("EmitCount") or 10)
		end
	end
	plate.Glow.Enabled = true
	task.delay(0.15, function()
		plate.Glow.Enabled = false
	end)
	plate.AmountGui.Enabled = false
	-- retours
	plus(plate, amount)
	edge(rank)
	bills(plate.BurstPoint.WorldPosition, 8, function()
		play(padSound, padSound.PlaybackSpeed * rng:NextNumber(0.97, 1.03))
		counter(amount)
	end)
end

local function fillPads(rank0: number)
	for i, pad in pads do
		pad.Plate.AmountGui.Amount.Text = fmt(AMOUNTS[((rank0 + i - 2) % #AMOUNTS) + 1])
		pad.Plate.AmountGui.Enabled = true
	end
end

------------------------------------------------------------------------------------------------

if MODE == "pose" then
	-- Une image fixe : voile au plus fort de la 5e plaque, billets en vol, « +$X » sur la plaque.
	fillPads(1)
	pads[2].Plate.AmountGui.Enabled = false
	flash.Enabled = true
	for band, peak in bands do
		band.BackgroundTransparency = peak + (1 - peak) * 0.45 * (1 - 4 / 7)
	end
	local tgt = target()
	local from = pads[2].Plate.BurstPoint.WorldPosition
	for i = 1, 8 do
		local m = (if i % 2 == 0 then fx.FX_Collect_Coin else fx.FX_Collect_Bill):Clone()
		local u = (i - 1) / 8
		local pos = from:Lerp(tgt, u * 0.9) + Vector3.new(0, math.sin(u * math.pi) * 2.5, 0)
		m:PivotTo(CFrame.new(pos) * CFrame.Angles(i, i * 2, i * 0.5))
		pcall(m.ScaleTo, m, 1 - 0.6 * u)
		m.Parent = folder
	end
	local gui = bbGain:Clone()
	gui.Adornee = pads[2].Plate
	gui.Row.Amount.Text = "+$860"
	gui.Row.Amount.TextColor3 = bbGain:GetAttribute("CashColor") or Color3.fromHex("5CFF4A")
	gui.Row.Icon.Image = bbGain:GetAttribute("CashIcon") or gui.Row.Icon.Image
	gui.StudsOffset = Vector3.new(0, 3.6, 0)
	gui.Parent = folder
	scale.Scale = 1.12
	cashLabel.Text = "$49.1K"
	return "image posée ; lancer MODE = \"restore\" ensuite"
end

local ok, err = pcall(function()
	for r, run in RUNS do
		if ONLY == nil or ONLY == run.Label then
			title.Text = run.Title
			fillPads(1)
			task.wait(0.8)
			for rank = 1, 8 do
				local index = ((rank - 1) % 4) + 1
				collect(index, rank, run)
				if rank == 4 then
					task.wait(GAPS[4])
					fillPads(5) -- la 2e moitié de la tournée : les plaques d'en face se remplissent
				elseif rank < 8 then
					task.wait(GAPS[index])
				end
			end
			task.wait(PAUSE)
		end
	end
	title.Text = ""
	task.wait(0.5)
end)
local done = restore()
if not ok then
	error(err)
end
return done
