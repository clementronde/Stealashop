--[[
	Prototype jouable de UI_Settings, en Edit, sans Play. Il copie StarterGui.UI_Settings et la rangée
	SocialRow du HUD (avec le bouton engrenage) dans CoreGui.
	- Curseurs MUSIC et SOUND EFFECTS : on les glisse (bouton ou barre) ; le pourcentage suit.
	- Interrupteur VISUAL EFFECTS : ON / OFF, le bouton rond glisse.
	- Même ouverture, fermeture et survol que l'inventaire (tools/clement/inventory_proto.luau).
	En Edit, Studio ne joue pas les sons : ils ne s'entendent qu'en Play.
	Arrêt : _G.SettingsProto.Stop(). État : _G.SettingsProto.State().
]]

local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

if _G.SettingsProto then pcall(_G.SettingsProto.Stop) end

local M = {
	OpenFrom = 0.55, OpenTime = 0.14, StaggerStart = 0.08, StaggerGap = 0.05, StaggerTime = 0.16, CloseTime = 0.09,
	HoverButton = 1.06, HoverButtonTime = 0.08, ShadeHover = 0.78, ShadePress = 0.62,
	Press = 0.95, PressTime = 0.05, ReleaseTime = 0.2,
	KnobGrab = 1.18, KnobTime = 0.08, ToggleTime = 0.16,
}
local SOUNDS = { Hover = 10066936758, Click = 15675059323, Open = 10128766965, Close = 10066914500 }
local EMOJI = { UI_Icon_Music = "🎵", UI_Icon_Sound = "🔊", UI_Icon_Vfx = "✨", UI_Icon_Settings = "⚙️" }

local conns = {}
local function on(sig, fn) local c = sig:Connect(fn); table.insert(conns, c); return c end
local function tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play(); return tw
end
local function scaleOf(o)
	local s = o:FindFirstChild("ProtoScale")
	if not s then s = Instance.new("UIScale"); s.Name = "ProtoScale"; s.Parent = o end
	return s
end
-- icône pas encore importée : un émoji à la place, dans le prototype seulement
local function emojiFallback(root)
	for _, d in root:GetDescendants() do
		if d:IsA("ImageLabel") and d.Image == "" and EMOJI[d:GetAttribute("IconAsset")] then
			local t = Instance.new("TextLabel")
			t.Name = "ProtoEmoji"; t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(1, 1); t.TextScaled = true
			t.Text = EMOJI[d:GetAttribute("IconAsset")]; t.ZIndex = d.ZIndex + 1; t.Parent = d
		end
	end
end

local old = CoreGui:FindFirstChild("_PROTO_Settings") if old then old:Destroy() end
local gui = game.StarterGui.UI_Settings:Clone()
gui.Name = "_PROTO_Settings"; gui.Enabled = false; gui.DisplayOrder = 62; gui.Parent = CoreGui
local hud = Instance.new("ScreenGui"); hud.Name = "_PROTO_Settings_HUD"; hud.DisplayOrder = 61; hud.ResetOnSpawn = false
local oldHud = CoreGui:FindFirstChild(hud.Name) if oldHud then oldHud:Destroy() end
hud.IgnoreGuiInset = game.StarterGui.UI_HUD.IgnoreGuiInset
local srSrc = game.StarterGui.UI_HUD:FindFirstChild("SocialRow", true)
assert(srSrc, "UI_HUD.SocialRow introuvable")
local social = srSrc:Clone(); social.Parent = hud
for _, b in social:GetChildren() do if b:IsA("GuiButton") then b.Visible = true end end
hud.Parent = CoreGui
emojiFallback(gui); emojiFallback(hud)

local snd = {}
for k, id in SOUNDS do local s = Instance.new("Sound"); s.SoundId = "rbxassetid://" .. id; s.Parent = gui; snd[k] = s end
local function play(k) if snd[k] then SoundService:PlayLocalSound(snd[k]) end end

local root = gui.Root
local win = root.Window
local rows = win.Rows
local rootScale = scaleOf(root)

local function hoverButton(btn, onClick)
	local s = scaleOf(btn)
	local shadeF = btn:FindFirstChild("Shade")
	local over = false
	on(btn.MouseEnter, function()
		over = true; play("Hover")
		tween(s, M.HoverButtonTime, { Scale = M.HoverButton })
		if shadeF then tween(shadeF, M.HoverButtonTime, { BackgroundTransparency = M.ShadeHover }) end
	end)
	on(btn.MouseLeave, function()
		over = false
		tween(s, M.HoverButtonTime, { Scale = 1 })
		if shadeF then tween(shadeF, M.HoverButtonTime, { BackgroundTransparency = 1 }) end
	end)
	on(btn.MouseButton1Down, function()
		tween(s, M.PressTime, { Scale = M.Press })
		if shadeF then tween(shadeF, M.PressTime, { BackgroundTransparency = M.ShadePress }) end
	end)
	on(btn.MouseButton1Up, function()
		tween(s, M.ReleaseTime, { Scale = over and M.HoverButton or 1 }, Enum.EasingStyle.Back)
		if shadeF then tween(shadeF, M.ReleaseTime, { BackgroundTransparency = over and M.ShadeHover or 1 }) end
	end)
	if onClick then on(btn.Activated, function() play("Click"); onClick() end) end
end

-- curseurs ------------------------------------------------------------------------
local state = { Music = 0.8, Sound = 1, Vfx = true }
local dragLayer = Instance.new("TextButton")
dragLayer.Name = "ProtoDragLayer"; dragLayer.Text = ""; dragLayer.BackgroundTransparency = 1; dragLayer.AutoButtonColor = false
dragLayer.Size = UDim2.fromScale(1, 1); dragLayer.ZIndex = 100; dragLayer.Visible = false; dragLayer.Parent = gui
local dragging = nil
local function setSlider(rowName, frac)
	local r = rows[rowName]
	frac = math.clamp(frac, 0, 1)
	r.Slider.Track.Fill.Size = UDim2.fromScale(frac, 1)
	r.Slider.Knob.Position = UDim2.fromScale(frac, 0.5)
	r.ValueLabel.Text = string.format("%d%%", math.floor(frac * 100 + 0.5))
	state[rowName == "MusicRow" and "Music" or "Sound"] = frac
end
local function fracAt(rowName, x)
	local tr = rows[rowName].Slider.Track
	return (x - tr.AbsolutePosition.X) / math.max(1, tr.AbsoluteSize.X)
end
local function startDrag(rowName, x)
	dragging = rowName
	dragLayer.Visible = true
	tween(scaleOf(rows[rowName].Slider.Knob), M.KnobTime, { Scale = M.KnobGrab }, Enum.EasingStyle.Back)
	setSlider(rowName, fracAt(rowName, x))
end
local function stopDrag()
	if not dragging then return end
	tween(scaleOf(rows[dragging].Slider.Knob), M.ReleaseTime, { Scale = 1 }, Enum.EasingStyle.Back)
	play("Click")
	dragging = nil
	dragLayer.Visible = false
end
on(dragLayer.InputChanged, function(input)
	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then setSlider(dragging, fracAt(dragging, input.Position.X)) end
end)
on(dragLayer.InputEnded, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then stopDrag() end
end)
on(dragLayer.MouseButton1Up, stopDrag)
for _, rowName in { "MusicRow", "SoundRow" } do
	local r = rows[rowName]
	on(r.Slider.Knob.MouseButton1Down, function(x) startDrag(rowName, x) end)
	on(r.Slider.Track.MouseButton1Down, function(x) startDrag(rowName, x) end)
	hoverButton(r.Slider.Knob, nil)
end
setSlider("MusicRow", state.Music); setSlider("SoundRow", state.Sound)

-- interrupteur ---------------------------------------------------------------------
local toggle = rows.VfxRow.Toggle
local function paintToggle(animate)
	local onState = state.Vfx
	toggle.OnFill.Visible = onState; toggle.OffFill.Visible = not onState
	toggle.ToggleLabel.Text = onState and "ON" or "OFF"
	toggle.ToggleLabel.Position = onState and UDim2.fromScale(0.08, 0.5) or UDim2.fromScale(0.42, 0.5)
	local knob = toggle.ToggleKnob
	local target = onState and { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(0.97, 0.5) } or { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.03, 0.5) }
	if animate then tween(knob, M.ToggleTime, target, Enum.EasingStyle.Back) else knob.AnchorPoint = target.AnchorPoint; knob.Position = target.Position end
end
hoverButton(toggle, function() state.Vfx = not state.Vfx; paintToggle(true) end)
paintToggle(false)

-- ouverture, fermeture -------------------------------------------------------------
local isOpen, busy = false, false
local function open()
	if isOpen or busy then return end
	isOpen = true; gui.Enabled = true; play("Open")
	rootScale.Scale = M.OpenFrom
	tween(rootScale, M.OpenTime, { Scale = 1 }, Enum.EasingStyle.Back)
	for i, name in { "MusicRow", "SoundRow", "VfxRow" } do
		local s = scaleOf(rows[name]); s.Scale = 0
		task.delay(M.StaggerStart + (i - 1) * M.StaggerGap, function() tween(s, M.StaggerTime, { Scale = 1 }, Enum.EasingStyle.Back) end)
	end
end
local function close()
	if not isOpen or busy then return end
	busy = true; play("Close"); stopDrag()
	tween(rootScale, M.CloseTime, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(M.CloseTime, function() gui.Enabled = false; isOpen = false; busy = false end)
end
hoverButton(win.CloseButton, close)
local settingsBtn = social:FindFirstChild("SettingsButton")
hoverButton(settingsBtn, function() if isOpen then close() else open() end end)
for _, b in social:GetChildren() do if b:IsA("GuiButton") and b ~= settingsBtn then hoverButton(b, nil) end end

_G.SettingsProto = {
	Stop = function()
		for _, c in conns do c:Disconnect() end
		table.clear(conns)
		if gui.Parent then gui:Destroy() end
		if hud.Parent then hud:Destroy() end
		_G.SettingsProto = nil
	end,
	Open = open, Close = close, Values = M,
	State = function() return { music = state.Music, sound = state.Sound, vfx = state.Vfx, open = isOpen } end,
}
open()
return "prototype des reglages pret"
