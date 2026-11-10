--[[
	Prototype du ressenti de toute l'interface, en Play, côté client (execute_luau « Client »).
	Il travaille sur des copies des écrans de StarterGui (_PROTO_Feel_*) : le vrai jeu n'est pas
	modifié, et tout disparaît à l'arrêt du Play. Aucun script n'est laissé dans l'UI.
	- Copie de la barre de gauche et de la rangée sociale du HUD : Shop, Index, Rebirth, Inventory,
	  Rewards, Settings. Touches : J boutique d'armes, K boutique d'auras, L arbre de compétences,
	  H victoire, T arrivée du camion (rejouée sur le camion présent).
	- Un seul menu à la fois. Ouverture 0,55 → 1 en 0,14 s (Back), éléments un par un, fermeture 0,09 s.
	- Boutons : calque Shade assombri au survol (0,78) et à l'appui (0,62), × 1,06. Un son de survol,
	  un son de clic (choisi dans Settings), un son de réussite sur Buy, Equip, Claim, Confirm, Place.
	- Cartes : l'icône grossit et penche vers le haut à droite, contour blanc HoverOutline.
	- Victoire : en entrant en zone safe avec un colis (attribut Carrying du joueur), ou touche H.
	  FX_Escape aux pieds, UI_Escape, son Heist_Escape, animation Celebrate.
	- Camion : chaque EventTruck qui apparaît arrive en roulant depuis 90 studs le long de la rue
	  (SFX_TruckArrive au départ, SFX_TruckBrake et FX_TruckDust au freinage, le nez plonge).
	Sons lus dans ReplicatedStorage/Assets/Sounds (UI/…, Heist/…, Truck/…).
	Arrêt : _G.UiFeel.Stop(). Valeurs : _G.UiFeel.Values.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CS = game:GetService("CollectionService")
local CP = game:GetService("ContentProvider")
local RS = game:GetService("ReplicatedStorage")
local SG = game:GetService("StarterGui")

if _G.UiFeel then pcall(_G.UiFeel.Stop) end
for _, k in { "InventoryProto", "SettingsProto" } do
	if _G[k] then pcall(_G[k].Stop) end
end

local lp = Players.LocalPlayer
local PG = lp:WaitForChild("PlayerGui")
local Assets = RS:WaitForChild("Assets")
local SOUNDS = Assets:WaitForChild("Sounds")

local M = {
	OpenFrom = 0.55, OpenTime = 0.14, StaggerStart = 0.08, StaggerGap = 0.035, StaggerTime = 0.14, StaggerMax = 14,
	CloseTime = 0.09, SwapOutGap = 0.03, SwapOutTime = 0.1,
	HoverButton = 1.06, HoverTime = 0.08, ShadeHover = 0.78, ShadePress = 0.62,
	Press = 0.95, PressTime = 0.05, ReleaseTime = 0.2,
	HoverIcon = 1.1, HoverIconTilt = -5, HoverShiftX = 0.02, HoverShiftY = -0.015, HoverIconTime = 0.1, HoverIconBack = 0.12,
	SuccessDelay = 0.12, Bump = 1.22, Pop = 0.28,
	KnobGrab = 1.18, ToggleTime = 0.16,
	BannerIn = 0.35, BannerHold = 2.2, BannerOut = 0.15, RaysSpeed = 40,
	TruckDistance = 90, TruckTime = 3, TruckBrakeAt = 0.78, NoseDip = 2.5,
}
local MENUS = {
	RobuxShopButton = "UI_RobuxShop", IndexButton = "UI_Index_v2", RebirthButton = "UI_Rebirth",
	InventoryButton = "UI_Inventory", RewardsButton = "UI_Rewards", SettingsButton = "UI_Settings",
}
local KEYS = { [Enum.KeyCode.J] = "UI_WeaponShop", [Enum.KeyCode.K] = "UI_AuraShop", [Enum.KeyCode.L] = "UI_SkillTree" }
local SUCCESS = { BuyButton = true, EquipButton = true, ClaimButton = true, DailyClaimButton = true, ConfirmButton = true, PlaceButton = true, EquipBestButton = true }
local CLICKS = {
	{ "CLASSIC", "UI_Click_Classic" }, { "SHARP", "UI_Click_Sharp" }, { "TICK", "UI_Click_Tick" },
	{ "BUBBLE", "UI_Click_Bubble" }, { "SOFT", "UI_Click_Soft" },
}

local conns, made, hidden = {}, {}, {}
local function on(sig, fn)
	local c = sig:Connect(fn)
	table.insert(conns, c)
	return c
end
local function tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
-- un seul UIScale par cadre : celui de Clément s'il existe (on part de sa valeur), sinon ProtoScale
local function scaleOf(o)
	local s = o:FindFirstChildOfClass("UIScale")
	if not s then
		s = Instance.new("UIScale")
		s.Name = "ProtoScale"
		s.Parent = o
	end
	if s:GetAttribute("ProtoBase") == nil then s:SetAttribute("ProtoBase", s.Scale) end
	return s, s:GetAttribute("ProtoBase")
end
local function scaleTo(o, f, t, style, dir)
	local s, b = scaleOf(o)
	return tween(s, t, { Scale = b * f }, style, dir)
end
local function setScale(o, f)
	local s, b = scaleOf(o)
	s.Scale = b * f
end

-- sons ------------------------------------------------------------------------------------
lp:SetAttribute("MusicVolume", 0) -- musique coupée pour le test (curseur MUSIC pour la remettre)
local sfxFolder = Instance.new("Folder")
sfxFolder.Name = "_PROTO_Feel_Sounds"
sfxFolder.Parent = SoundService
local sfxVolume, clickIndex = 1, 1
local clickName = CLICKS[1][2]
local snd = {}
local function soundOf(name)
	if snd[name] then return snd[name] end
	local src = SOUNDS:FindFirstChild(name, true)
	if not (src and src:IsA("Sound")) then
		warn("[UiFeel] son absent : " .. name)
		return nil
	end
	local s = src:Clone()
	s:SetAttribute("Base", s.Volume)
	s.Volume = s.Volume * sfxVolume
	s.Parent = sfxFolder
	snd[name] = s
	return s
end
local function play(name)
	local s = soundOf(name)
	if s then SoundService:PlayLocalSound(s) end
end
local function setSfx(v)
	sfxVolume = v
	for _, s in snd do s.Volume = (s:GetAttribute("Base") or 0.5) * v end
end
do
	local list = {}
	for _, n in { "UI_Hover", "UI_Open", "UI_Close", "UI_Success", "UI_Deny", "Heist_Escape" } do table.insert(list, soundOf(n)) end
	for _, c in CLICKS do table.insert(list, soundOf(c[2])) end
	CP:PreloadAsync(list)
end

-- boutons et cartes --------------------------------------------------------------------------
local function wireButton(btn, onClick, silent)
	if btn:GetAttribute("ProtoWired") then return end
	btn:SetAttribute("ProtoWired", true)
	local shade = btn:FindFirstChild("Shade")
	local icon = not shade and (btn:FindFirstChild("TabIcon") or btn:FindFirstChild("Icon", true)) or nil
	local iconRot = icon and icon.Rotation or 0
	local over = false
	on(btn.MouseEnter, function()
		over = true
		play("UI_Hover")
		scaleTo(btn, M.HoverButton, M.HoverTime)
		if shade then tween(shade, M.HoverTime, { BackgroundTransparency = M.ShadeHover }) end
		if icon then
			scaleTo(icon, M.HoverIcon, M.HoverIconTime, Enum.EasingStyle.Back)
			tween(icon, M.HoverIconTime, { Rotation = iconRot + M.HoverIconTilt }, Enum.EasingStyle.Back)
		end
	end)
	on(btn.MouseLeave, function()
		over = false
		scaleTo(btn, 1, M.HoverTime)
		if shade then tween(shade, M.HoverTime, { BackgroundTransparency = 1 }) end
		if icon then
			scaleTo(icon, 1, M.HoverIconBack)
			tween(icon, M.HoverIconBack, { Rotation = iconRot })
		end
	end)
	on(btn.MouseButton1Down, function()
		scaleTo(btn, M.Press, M.PressTime)
		if shade then tween(shade, M.PressTime, { BackgroundTransparency = M.ShadePress }) end
	end)
	on(btn.MouseButton1Up, function()
		scaleTo(btn, over and M.HoverButton or 1, M.ReleaseTime, Enum.EasingStyle.Back)
		if shade then tween(shade, M.ReleaseTime, { BackgroundTransparency = over and M.ShadeHover or 1 }) end
	end)
	on(btn.Activated, function()
		if not silent then play(clickName) end
		if SUCCESS[btn.Name] then
			task.delay(M.SuccessDelay, function() play("UI_Success") end)
			setScale(btn, M.Bump)
			scaleTo(btn, over and M.HoverButton or 1, M.Pop, Enum.EasingStyle.Back)
		end
		if onClick then onClick() end
	end)
end

local function wireCard(card)
	if card:GetAttribute("ProtoWired") then return end
	card:SetAttribute("ProtoWired", true)
	local icon = card:FindFirstChild("Icon")
	local outline = card:FindFirstChild("HoverOutline")
	local basePos = icon and icon.Position
	local baseRot = icon and icon.Rotation or 0
	on(card.MouseEnter, function()
		play("UI_Hover")
		if outline then outline.Visible = true end
		if icon then
			scaleTo(icon, M.HoverIcon, M.HoverIconTime, Enum.EasingStyle.Back)
			tween(icon, M.HoverIconTime, { Rotation = baseRot + M.HoverIconTilt, Position = basePos + UDim2.fromScale(M.HoverShiftX, M.HoverShiftY) }, Enum.EasingStyle.Back)
		end
	end)
	on(card.MouseLeave, function()
		if outline then outline.Visible = false end
		if icon then
			scaleTo(icon, 1, M.HoverIconBack)
			tween(icon, M.HoverIconBack, { Rotation = baseRot, Position = basePos })
		end
	end)
end

-- listes vides : cartes d'exemple avec les icônes ICON_ des objets ---------------------------
local icons = {}
local iconFolder = Assets:FindFirstChild("Icons")
if iconFolder then
	for _, d in iconFolder:GetChildren() do
		if d:IsA("Decal") and not d.Name:match("^ICON_BOX") and not d.Name:match("^ICON_TOOL") then table.insert(icons, d) end
	end
end
local filled = 0
local function fill(card)
	filled += 1
	local dec = icons[(filled - 1) % math.max(1, #icons) + 1]
	local icon = card:FindFirstChild("Icon")
	if dec and icon and icon:IsA("ImageLabel") then icon.Image = dec.Texture end
	local label = card:FindFirstChild("ItemName", true)
	if dec and label and label:IsA("TextLabel") then
		label.Text = (dec.Name:gsub("^ICON_", ""):gsub("^ITM_", ""):gsub("^Z%d+_", ""):gsub("_", " "))
	end
end
local function addCards(tpl, parent, count)
	for i = 1, count do
		local c = tpl:Clone()
		c.Name = "ProtoCard_" .. i
		c.Visible = true
		c.LayoutOrder = i
		fill(c)
		c.Parent = parent
	end
end
local function prepare(gui, name)
	local jobs = {}
	if name == "UI_Index_v2" then
		local list = gui:FindFirstChild("List", true)
		local tpl = list and list:FindFirstChild("Template")
		if tpl then
			for _, sec in list:GetChildren() do
				local cards = sec:FindFirstChild("Cards")
				if cards then table.insert(jobs, { tpl, cards, 5 }) end
			end
		end
	end
	for _, d in gui:GetDescendants() do
		if d.Name == "Cards" and d:FindFirstChild("Template") then table.insert(jobs, { d.Template, d, 5 }) end
	end
	for _, j in jobs do addCards(j[1], j[2], j[3]) end
end

-- écrans --------------------------------------------------------------------------------------
local screens, current = {}, nil
local openScreen, closeScreen

local function isCard(d)
	return d:IsA("GuiObject") and d:FindFirstChild("HoverOutline") ~= nil and d.Name ~= "Template"
end
local function staggerItems(state)
	local items = {}
	for _, d in state.gui:GetDescendants() do
		if isCard(d) and d.Visible then
			local p, shown = d.Parent, true
			while p and p ~= state.gui do
				if p:IsA("GuiObject") and not p.Visible then shown = false break end
				p = p.Parent
			end
			if shown then table.insert(items, d) end
		end
	end
	if #items == 0 then
		for _, d in state.gui:GetDescendants() do
			if d:IsA("GuiObject") and d.Visible and (d.Name == "Rows" or d.Name == "Tree" or d.Name == "Body" or d.Name == "DailyPage") then
				for _, c in d:GetChildren() do
					if c:IsA("GuiObject") and c.Visible then table.insert(items, c) end
				end
			end
		end
	end
	return items
end
local function runStagger(state, items)
	task.defer(function()
		table.sort(items, function(a, b)
			local pa, pb = a.AbsolutePosition, b.AbsolutePosition
			if math.abs(pa.Y - pb.Y) > 4 then return pa.Y < pb.Y end
			return pa.X < pb.X
		end)
		for i, it in items do
			local k = math.min(i, M.StaggerMax) - 1
			task.delay(M.StaggerStart + k * M.StaggerGap, function()
				if state.open then scaleTo(it, 1, M.StaggerTime, Enum.EasingStyle.Back) end
			end)
		end
	end)
end

-- changement de rubrique : les cartes sortent de droite à gauche, puis rentrent une par une
local function swap(state, change)
	local items = staggerItems(state)
	table.sort(items, function(a, b) return a.AbsolutePosition.X + a.AbsolutePosition.Y * 10 > b.AbsolutePosition.X + b.AbsolutePosition.Y * 10 end)
	for i, it in items do
		task.delay((math.min(i, M.StaggerMax) - 1) * M.SwapOutGap, function() scaleTo(it, 0, M.SwapOutTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In) end)
	end
	task.delay(math.min(#items, M.StaggerMax) * M.SwapOutGap + M.SwapOutTime, function()
		if change then change() end
		local fresh = staggerItems(state)
		for _, it in fresh do setScale(it, 0) end
		runStagger(state, fresh)
	end)
end

local function wireTabs(state)
	local tabs = {}
	for _, d in state.gui:GetDescendants() do
		if d:IsA("GuiButton") and d.Name:match("Tab$") then table.insert(tabs, d) end
	end
	for _, tab in tabs do
		local key = tab.Name:gsub("Tab$", "")
		wireButton(tab, function()
			local page = state.gui:FindFirstChild(key .. "Page", true)
			swap(state, function()
				if page then
					for _, sib in page.Parent:GetChildren() do
						if sib:IsA("GuiObject") and sib.Name:match("Page$") then sib.Visible = sib == page end
					end
				end
			end)
		end)
	end
end

local function wireSettings(gui)
	local rows = gui:FindFirstChild("Rows", true)
	if not rows then return end
	local dragLayer = Instance.new("TextButton")
	dragLayer.Name = "ProtoDragLayer"
	dragLayer.Text = ""
	dragLayer.BackgroundTransparency = 1
	dragLayer.AutoButtonColor = false
	dragLayer.Size = UDim2.fromScale(1, 1)
	dragLayer.ZIndex = 100
	dragLayer.Visible = false
	dragLayer.Parent = gui
	local dragging = nil
	local function setSlider(rowName, frac)
		local r = rows:FindFirstChild(rowName)
		if not r then return end
		frac = math.clamp(frac, 0, 1)
		r.Slider.Track.Fill.Size = UDim2.fromScale(frac, 1)
		r.Slider.Knob.Position = UDim2.fromScale(frac, 0.5)
		r.ValueLabel.Text = string.format("%d%%", math.floor(frac * 100 + 0.5))
		if rowName == "MusicRow" then lp:SetAttribute("MusicVolume", frac) else setSfx(frac) end
	end
	local function fracAt(rowName, x)
		local tr = rows[rowName].Slider.Track
		return (x - tr.AbsolutePosition.X) / math.max(1, tr.AbsoluteSize.X)
	end
	local function stopDrag()
		if not dragging then return end
		scaleTo(rows[dragging].Slider.Knob, 1, M.ReleaseTime, Enum.EasingStyle.Back)
		play(clickName)
		dragging = nil
		dragLayer.Visible = false
	end
	on(dragLayer.InputChanged, function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then setSlider(dragging, fracAt(dragging, input.Position.X)) end
	end)
	on(dragLayer.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then stopDrag() end
	end)
	for _, rowName in { "MusicRow", "SoundRow" } do
		local r = rows:FindFirstChild(rowName)
		if r then
			local function start(x)
				dragging = rowName
				dragLayer.Visible = true
				scaleTo(r.Slider.Knob, M.KnobGrab, M.HoverTime, Enum.EasingStyle.Back)
				setSlider(rowName, fracAt(rowName, x))
			end
			on(r.Slider.Knob.MouseButton1Down, start)
			on(r.Slider.Track.MouseButton1Down, start)
			r.Slider.Track:SetAttribute("ProtoWired", true)
			r.Slider.Knob:SetAttribute("ProtoWired", true)
			on(r.Slider.Knob.MouseEnter, function() play("UI_Hover") end)
		end
	end
	setSlider("MusicRow", lp:GetAttribute("MusicVolume") or 0)
	setSlider("SoundRow", sfxVolume)
	local vfx = rows:FindFirstChild("VfxRow")
	local toggle = vfx and vfx:FindFirstChild("Toggle")
	if toggle then
		local onState = true
		local function paint(animate)
			toggle.OnFill.Visible = onState
			toggle.OffFill.Visible = not onState
			toggle.ToggleLabel.Text = onState and "ON" or "OFF"
			toggle.ToggleLabel.Position = onState and UDim2.fromScale(0.08, 0.5) or UDim2.fromScale(0.42, 0.5)
			local target = onState and { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(0.97, 0.5) } or { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.03, 0.5) }
			if animate then
				tween(toggle.ToggleKnob, M.ToggleTime, target, Enum.EasingStyle.Back)
			else
				toggle.ToggleKnob.AnchorPoint = target.AnchorPoint
				toggle.ToggleKnob.Position = target.Position
			end
		end
		wireButton(toggle, function() onState = not onState; paint(true) end)
		paint(false)
	end
	local click = rows:FindFirstChild("ClickRow")
	if click then
		local function apply(step)
			clickIndex = (clickIndex - 1 + step) % #CLICKS + 1
			clickName = CLICKS[clickIndex][2]
			click.ChoiceLabel.Text = CLICKS[clickIndex][1]
			play(clickName) -- seulement le nouveau clic
			setScale(click.ChoiceLabel, 1.25)
			scaleTo(click.ChoiceLabel, 1, 0.25, Enum.EasingStyle.Back)
		end
		wireButton(click.PrevButton, function() apply(-1) end, true)
		wireButton(click.NextButton, function() apply(1) end, true)
		click.ChoiceLabel.Text = CLICKS[clickIndex][1]
	end
end

local function getScreen(name)
	if screens[name] then return screens[name] end
	local src = SG:FindFirstChild(name)
	if not src then
		warn("[UiFeel] écran absent : " .. name)
		return nil
	end
	local gui = src:Clone()
	gui.Name = "_PROTO_Feel_" .. name
	gui.Enabled = false
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 62
	prepare(gui, name)
	gui.Parent = PG
	table.insert(made, gui)
	local state = { gui = gui, name = name, open = false, roots = {} }
	local root = gui:FindFirstChild("Root")
	if root then
		table.insert(state.roots, root)
	else
		for _, c in gui:GetChildren() do
			if c:IsA("GuiObject") and c.Name ~= "Backdrop" then table.insert(state.roots, c) end
		end
	end
	if name == "UI_Settings" then wireSettings(gui) end
	wireTabs(state)
	for _, d in gui:GetDescendants() do
		if isCard(d) then
			wireCard(d)
		elseif d:IsA("GuiButton") then
			if d.Name == "CloseButton" then wireButton(d, function() closeScreen(state) end) else wireButton(d) end
		end
	end
	screens[name] = state
	return state
end

function openScreen(state)
	if current and current ~= state then closeScreen(current, true) end
	if state.open then return end
	state.open = true
	current = state
	play("UI_Open")
	local items = staggerItems(state)
	for _, it in items do setScale(it, 0) end
	for _, r in state.roots do setScale(r, M.OpenFrom) end
	state.gui.Enabled = true
	for _, r in state.roots do scaleTo(r, 1, M.OpenTime, Enum.EasingStyle.Back) end
	runStagger(state, items)
end
function closeScreen(state, silent)
	if not state.open then return end
	state.open = false
	if current == state then current = nil end
	if not silent then play("UI_Close") end
	for _, r in state.roots do scaleTo(r, 0, M.CloseTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In) end
	task.delay(M.CloseTime, function()
		if not state.open then state.gui.Enabled = false end
	end)
end
local function toggleScreen(name)
	local s = getScreen(name)
	if not s then return end
	if s.open then closeScreen(s) else openScreen(s) end
end

-- HUD : copie de la barre de gauche et de la rangée sociale ---------------------------------
do
	local hud = SG.UI_HUD:Clone()
	hud.Name = "_PROTO_Feel_HUD"
	hud.ResetOnSpawn = false
	hud.DisplayOrder = 61
	local keep = {}
	local kept = {}
	for _, n in { "LeftRail", "SocialRow" } do
		local part = hud:FindFirstChild(n, true)
		if part then
			table.insert(kept, part)
			local p = part
			while p and p ~= hud do keep[p] = true; p = p.Parent end
		end
	end
	for _, d in hud:GetDescendants() do
		if d:IsA("GuiObject") and not keep[d] then
			local inside = false
			for _, k in kept do if d:IsDescendantOf(k) then inside = true break end end
			if not inside then d.Visible = false end
		end
	end
	for _, k in kept do
		for _, b in k:GetDescendants() do
			if b:IsA("GuiButton") then
				b.Visible = true
				local target = MENUS[b.Name]
				wireButton(b, target and function() toggleScreen(target) end or nil)
			end
		end
	end
	hud.Parent = PG
	table.insert(made, hud)
	local real = PG:FindFirstChild("UI_HUD")
	if real then
		for _, n in { "LeftRail", "SocialRow" } do
			local r = real:FindFirstChild(n, true)
			if r then hidden[r] = r.Visible; r.Visible = false end
		end
	end
end

-- victoire en zone safe ----------------------------------------------------------------------
local escapeGui, escapeToken = nil, nil
local function escape()
	local char = lp.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root then return end
	play("Heist_Escape")
	local fxSrc = Assets:FindFirstChild("FX") and Assets.FX:FindFirstChild("FX_Escape")
	if fxSrc then
		local fx = fxSrc:Clone()
		local feet = root.Position - Vector3.new(0, (hum and hum.HipHeight or 2) + root.Size.Y / 2, 0)
		fx:PivotTo(CFrame.new(feet))
		fx.Parent = workspace
		for _, e in fx:GetDescendants() do
			if e:IsA("ParticleEmitter") then
				task.delay(e:GetAttribute("EmitDelay") or 0, function() e:Emit(e:GetAttribute("EmitCount") or 10) end)
			elseif e:IsA("PointLight") then
				e.Enabled = true
				tween(e, e:GetAttribute("FadeTime") or 0.5, { Brightness = 0 })
			end
		end
		task.delay(fx:GetAttribute("Duration") or 2, function() fx:Destroy() end)
	end
	if not escapeGui then
		local src = SG:FindFirstChild("UI_Escape")
		if src then
			escapeGui = src:Clone()
			escapeGui.Name = "_PROTO_Feel_UI_Escape"
			escapeGui.Parent = PG
			table.insert(made, escapeGui)
		end
	end
	if escapeGui then
		local token = {}
		escapeToken = token
		local b = escapeGui.Banner
		escapeGui.Enabled = true
		setScale(b, 0)
		scaleTo(b, 1, M.BannerIn, Enum.EasingStyle.Back)
		b.Title.Rotation = -14
		tween(b.Title, M.BannerIn + 0.05, { Rotation = -3 }, Enum.EasingStyle.Back)
		for i, n in { "BoxIcon", "Subtitle" } do
			local o = b:FindFirstChild(n)
			if o then
				setScale(o, 0)
				task.delay(0.06 + i * 0.07, function() scaleTo(o, 1, 0.25, Enum.EasingStyle.Back) end)
			end
		end
		task.delay(M.BannerHold, function()
			if escapeToken ~= token then return end
			scaleTo(b, 0, M.BannerOut, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(M.BannerOut, function()
				if escapeToken == token then escapeGui.Enabled = false end
			end)
		end)
	end
	local anims = Assets:FindFirstChild("Animations")
	local anim = anims and anims:FindFirstChild("Player") and anims.Player:FindFirstChild("Celebrate")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if anim and animator then animator:LoadAnimation(anim):Play() end
end
on(RunService.RenderStepped, function(dt)
	if escapeGui and escapeGui.Enabled then
		local b = escapeGui.Banner
		if b:FindFirstChild("Rays") then b.Rays.Rotation += dt * M.RaysSpeed end
		if b:FindFirstChild("Glow") then b.Glow.ImageTransparency = 0.35 + 0.1 * math.sin(os.clock() * 6) end
	end
end)

local function inSafe(pos)
	for _, inst in CS:GetTagged("SafeZone") do
		local part = inst:IsA("BasePart") and inst or inst:FindFirstChild("Bounds")
		local cf, size
		if part and part:IsA("BasePart") then
			cf, size = part.CFrame, part.Size
		elseif inst:IsA("Model") then
			cf, size = inst:GetBoundingBox()
		end
		if cf then
			local p = cf:PointToObjectSpace(pos)
			if math.abs(p.X) <= size.X / 2 and math.abs(p.Z) <= size.Z / 2 and math.abs(p.Y) <= size.Y / 2 + 8 then return true end
		end
	end
	return false
end
local wasSafe, nextCheck = nil, 0
on(RunService.Heartbeat, function()
	if os.clock() < nextCheck then return end
	nextCheck = os.clock() + 0.1
	local root = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local safe = inSafe(root.Position)
	if wasSafe == false and safe and lp:GetAttribute("Carrying") ~= nil then escape() end
	wasSafe = safe
end)

-- arrivée du camion ---------------------------------------------------------------------------
local function play3D(name, part)
	local src = SOUNDS:FindFirstChild(name, true)
	if not (src and part) then return end
	local s = src:Clone()
	s.RollOffMinDistance = 40
	s.Parent = part
	s:Play()
	s.Ended:Once(function() s:Destroy() end)
end
local function dust(at)
	local src = Assets:FindFirstChild("FX") and Assets.FX:FindFirstChild("FX_TruckDust")
	if not src then return end
	local fx = src:Clone()
	fx:PivotTo(at)
	fx.Parent = workspace
	for _, e in fx:GetDescendants() do
		if e:IsA("ParticleEmitter") then e:Emit(e:GetAttribute("EmitCount") or 10) end
	end
	task.delay(fx:GetAttribute("Duration") or 2.5, function() fx:Destroy() end)
end
local arriving = {}
local function arrive(truck)
	if arriving[truck] then return end
	arriving[truck] = true
	task.wait(0.1)
	local final = truck:GetPivot()
	local hiddenParts = {}
	for _, d in truck:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") or d:IsA("Texture") then
			if pcall(function() d.LocalTransparencyModifier = 1 end) then table.insert(hiddenParts, d) end
		end
	end
	local function restore()
		for _, d in hiddenParts do pcall(function() d.LocalTransparencyModifier = 0 end) end
		arriving[truck] = nil
	end
	local ghost = truck:Clone()
	if not ghost then restore() return end
	for _, tag in CS:GetTags(ghost) do CS:RemoveTag(ghost, tag) end
	for _, d in ghost:GetDescendants() do
		for _, tag in CS:GetTags(d) do CS:RemoveTag(d, tag) end
		if d:IsA("LuaSourceContainer") or d:IsA("BillboardGui") or d:IsA("ProximityPrompt") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.LocalTransparencyModifier = 0
		elseif d:IsA("Decal") or d:IsA("Texture") then
			pcall(function() d.LocalTransparencyModifier = 0 end)
		end
	end
	ghost.Name = "_PROTO_TruckArrival"
	local dir = final.LookVector.X >= 0 and 1 or -1 -- il roule le long de la rue (axe X), cabine devant
	local startPos = final.Position - Vector3.new(dir * M.TruckDistance, 0, 0)
	local start = CFrame.lookAt(startPos, startPos + Vector3.new(dir, 0, 0))
	ghost:PivotTo(start)
	ghost.Parent = workspace
	local body = ghost.PrimaryPart or ghost:FindFirstChildWhichIsA("BasePart", true)
	play3D("SFX_TruckArrive", body)
	local v = Instance.new("NumberValue")
	local braked = false
	local c = v.Changed:Connect(function(a)
		ghost:PivotTo(start:Lerp(final, a))
		if not braked and a >= M.TruckBrakeAt then
			braked = true
			play3D("SFX_TruckBrake", body)
			dust(final)
		end
	end)
	tween(v, M.TruckTime, { Value = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out).Completed:Wait()
	c:Disconnect()
	local nose = Instance.new("NumberValue")
	local c2 = nose.Changed:Connect(function(x) ghost:PivotTo(final * CFrame.Angles(math.rad(-M.NoseDip) * x, 0, 0)) end)
	tween(nose, 0.12, { Value = 1 }).Completed:Wait()
	tween(nose, 0.3, { Value = 0 }, Enum.EasingStyle.Back).Completed:Wait()
	c2:Disconnect()
	ghost:Destroy()
	restore()
end
on(workspace.ChildAdded, function(c)
	if c.Name == "EventTruck" and c:IsA("Model") then task.spawn(arrive, c) end
end)

-- touches ---------------------------------------------------------------------------------------
on(UIS.InputBegan, function(input, processed)
	if processed then return end
	local menu = KEYS[input.KeyCode]
	if menu then
		toggleScreen(menu)
	elseif input.KeyCode == Enum.KeyCode.H then
		escape()
	elseif input.KeyCode == Enum.KeyCode.T then
		local t = workspace:FindFirstChild("EventTruck")
		if t then task.spawn(arrive, t) end
	end
end)

_G.UiFeel = {
	Stop = function()
		for _, c in conns do c:Disconnect() end
		table.clear(conns)
		for _, g in made do if g.Parent then g:Destroy() end end
		for real, vis in hidden do real.Visible = vis end
		sfxFolder:Destroy()
		_G.UiFeel = nil
	end,
	Open = function(name)
		local s = getScreen(name)
		if s then openScreen(s) end
	end,
	Escape = escape,
	Truck = function()
		local t = workspace:FindFirstChild("EventTruck")
		if t then task.spawn(arrive, t) end
	end,
	Values = M,
}
return "prototype du ressenti pret : HUD copie, J/K/L menus, H victoire, T camion"
