--[[
	Prototype jouable de UI_Inventory (L-079), en Edit, sans Play et sans rien écrire dans le jeu.
	Il copie StarterGui.UI_Inventory et la colonne gauche du HUD dans CoreGui (_PROTO_Inventory), et les
	remplit d'exemples. Il y joue le ressenti relevé dans le jeu de référence
	(docs/claude/notes/ui-reference-ressenti.md).
	Valeurs : le tableau M ci-dessous, à reporter par Ironix dans Config/UiMotion.
	Sons : effets officiels de Roblox (RBLX UI …), joués par SoundService:PlayLocalSound.
	Arrêt : _G.InventoryProto.Stop(). Le X de la fenêtre la ferme ; le bouton Inventory la rouvre.
]]

local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local RS = game:GetService("ReplicatedStorage")
local Config = RS.Shared.Config
local Formulas = require(Config.Formulas)
local Mutations = require(Config.Mutations)
local Rarities = require(Config.Rarities)
local Items = require(Config.Items)
local Icons = require(RS.Shared.Contract.Icons)

if _G.InventoryProto then pcall(_G.InventoryProto.Stop) end

local M = {
	OpenFrom = 0.55, OpenTime = 0.14, -- fenêtre : 0,55 → 1, Back Out
	StaggerStart = 0.08, StaggerGap = 0.035, StaggerTime = 0.14, -- contenu, un élément à la fois
	CloseTime = 0.09, -- fenêtre : 1 → 0, Quad In
	HoverButton = 1.06, HoverButtonTime = 0.08, ShadeHover = 0.78, ShadePress = 0.62,
	-- survol d'une carte, le même pour les objets, les colis et les outils (retour de Clément) :
	-- l'icône (ancrée en bas à gauche) grandit vers le haut et la droite, sans couvrir le texte
	HoverIcon = 1.1, HoverIconTilt = -5, HoverShiftX = 0.02, HoverShiftY = -0.015, HoverIconTime = 0.1, HoverIconBack = 0.12, -- réduit (« ils montent trop haut »)
	SuccessDelay = 0.12, -- le son de réussite part après le clic, pour qu'on entende bien les deux
	Press = 0.95, PressTime = 0.05, ReleaseTime = 0.2,
	Pop = 0.28, -- pastille qui apparaît (Back Out)
	Bump = 1.22, BumpTime = 0.3, -- compteur qui change
	ToastIn = 0.18, ToastStay = 1.6, ToastOut = 0.25,
	Shake = 6, ShakeTime = 0.3,
	Volume = 0.6,
}

-- Survol : RBLX UI Hover 02 (95 ms). Clic : Roblox_UI_Bright_Click (officiel). Les autres : effets RBLX UI.
-- Survol : RBLX UI Hover 02, choisi par Clément (2026-11-10) après essai en Play. Clic : Bright Click (212).
local SOUNDS = { Hover = 10066936758, Click = 15675059323, Success = 10066947742, Open = 10128766965, Close = 10066914500, Deny = 10066926605, Remove = 10066914500 }
local VOLUME = { Hover = 0.8, Click = 1, Success = 0.45, Open = 0.5, Close = 0.5, Deny = 0.6, Remove = 0.6 }

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
local function find(root, path)
	local cur = root
	for seg in string.gmatch(path, "[^%.]+") do
		if not cur then return nil end
		cur = cur:FindFirstChild(seg, true)
	end
	return cur
end
local function money(n)
	local units = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
	for _, u in units do
		if n >= u[1] then
			local v = n / u[1]
			local s = v >= 100 and string.format("%d", math.floor(v)) or string.format("%.1f", v):gsub("%.0$", "")
			return "$" .. s .. u[2]
		end
	end
	return "$" .. tostring(math.floor(n))
end

-- copies -----------------------------------------------------------------
local old = CoreGui:FindFirstChild("_PROTO_Inventory") if old then old:Destroy() end
local gui = game.StarterGui.UI_Inventory:Clone()
gui.Name = "_PROTO_Inventory"; gui.Enabled = false; gui.DisplayOrder = 60; gui.Parent = CoreGui
local hudCopy = Instance.new("ScreenGui"); hudCopy.Name = "_PROTO_Inventory_HUD"; hudCopy.DisplayOrder = 59; hudCopy.ResetOnSpawn = false
local oldHud = CoreGui:FindFirstChild(hudCopy.Name) if oldHud then oldHud:Destroy() end
local hudRoot = game.StarterGui.UI_HUD
hudCopy.IgnoreGuiInset = hudRoot.IgnoreGuiInset
local railSrc = hudRoot:FindFirstChild("LeftRail", true)
assert(railSrc, "UI_HUD.LeftRail introuvable")
local rail = railSrc:Clone(); rail.Parent = hudCopy
for _, b in rail:GetChildren() do if b:IsA("GuiButton") then b.Visible = true end end
hudCopy.Parent = CoreGui
local soundFolder = Instance.new("Folder"); soundFolder.Name = "ProtoSounds"; soundFolder.Parent = gui
local snd = {}
for k, id in SOUNDS do local s = Instance.new("Sound"); s.Name = k; s.SoundId = "rbxassetid://" .. id; s.Volume = VOLUME[k] or M.Volume; s.Parent = soundFolder; snd[k] = s end
game:GetService("ContentProvider"):PreloadAsync(soundFolder:GetChildren())
local function play(k)
	local s = snd[k]
	if not s then return end
	if k == "Success" or k == "Deny" or k == "Remove" then
		task.delay(M.SuccessDelay, function() SoundService:PlayLocalSound(s) end)
	else
		SoundService:PlayLocalSound(s)
	end
end

local root = gui.Root
local win = root.Window
local rootScale = scaleOf(root)

-- toast (message de réussite en bas, comme le jeu de référence)
local toastGui = Instance.new("TextLabel")
toastGui.Name = "ProtoToast"; toastGui.BackgroundTransparency = 1; toastGui.AnchorPoint = Vector2.new(0.5, 1)
toastGui.Position = UDim2.fromScale(0.5, 0.97); toastGui.Size = UDim2.fromScale(0.6, 0.05)
toastGui.FontFace = win.Header.Title.FontFace; toastGui.TextScaled = true; toastGui.TextWrapped = true
toastGui.TextColor3 = Color3.fromHex("5cff4a"); toastGui.TextTransparency = 1; toastGui.ZIndex = 50
local ts = Instance.new("UIStroke"); ts.Thickness = 2.5; ts.Transparency = 1; ts.Parent = toastGui
toastGui.Parent = hudCopy
local toastToken = 0
local function toast(text)
	toastToken += 1
	local my = toastToken
	toastGui.Text = text
	toastGui.Position = UDim2.fromScale(0.5, 1.0)
	tween(toastGui, M.ToastIn, { Position = UDim2.fromScale(0.5, 0.97), TextTransparency = 0 }, Enum.EasingStyle.Back)
	tween(ts, M.ToastIn, { Transparency = 0 })
	task.delay(M.ToastIn + M.ToastStay, function()
		if my ~= toastToken then return end
		tween(toastGui, M.ToastOut, { TextTransparency = 1 }); tween(ts, M.ToastOut, { Transparency = 1 })
	end)
end
local function bump(o)
	local s = scaleOf(o); s.Scale = M.Bump
	tween(s, M.BumpTime, { Scale = 1 }, Enum.EasingStyle.Back)
end
local function pop(o)
	o.Visible = true
	local s = scaleOf(o); s.Scale = 0
	tween(s, M.Pop, { Scale = 1 }, Enum.EasingStyle.Back)
end
local function shake(o)
	local base = o.Position
	task.spawn(function()
		for i = 1, 4 do
			o.Position = base + UDim2.fromOffset(i % 2 == 1 and M.Shake or -M.Shake, 0)
			task.wait(M.ShakeTime / 8)
		end
		o.Position = base
	end)
end

-- survol, appui ---------------------------------------------------------------
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
-- carte : l'icône grossit, penche et sort du cadre ; contour blanc
local function hoverCard(card, onClick)
	local icon = card:FindFirstChild("BoxView") or card:FindFirstChild("Icon")
	local iconScale = icon and scaleOf(icon)
	local outline = card:FindFirstChild("HoverOutline")
	local baseRot = icon and icon.Rotation or 0
	local basePos = icon and icon.Position
	on(card.MouseEnter, function()
		play("Hover")
		if outline then outline.Visible = true end
		if icon then
			icon.ZIndex = 30
			-- valeurs relues à chaque survol : _G.InventoryProto.Values permet de les régler en direct
			tween(iconScale, M.HoverIconTime, { Scale = M.HoverIcon }, Enum.EasingStyle.Back)
			tween(icon, M.HoverIconTime, { Rotation = baseRot + M.HoverIconTilt, Position = basePos + UDim2.fromScale(M.HoverShiftX, M.HoverShiftY) }, Enum.EasingStyle.Back)
		end
	end)
	on(card.MouseLeave, function()
		if outline then outline.Visible = false end
		if icon then
			tween(iconScale, M.HoverIconBack, { Scale = 1 })
			tween(icon, M.HoverIconBack, { Rotation = baseRot, Position = basePos })
			task.delay(M.HoverIconBack, function() if icon.Parent then icon.ZIndex = 7 end end)
		end
	end)
	if onClick then on(card.Activated, function() play("Click"); onClick() end) end
end

-- données d'exemple -------------------------------------------------------------
local byId = {}
for _, it in Items.List do byId[it.Id] = it end
local SAMPLE = {
	{ "Z3_CarteGraphiqueEnOr" }, { "Z3_PcGamer" }, { "Z3_TeleGeante", { Size = "Big" } }, { "Z2_PelucheGeante" },
	{ "Z2_RobotJouet", { Effect = "Gold" } }, { "Z2_MaisonEnPainDEpices" }, { "Z2_YoYo" },
	{ "Z2_CanardEnPlastique", { Effect = "Shiny" } }, { "Z1_Donut" },
}
local entries = {}
for _, s in SAMPLE do
	local it = byId[s[1]]
	if it then
		local inc = Formulas.ItemIncome(it.Zone or 1, it.Rarity) * Mutations.IncomeMultiplier(s[2])
		table.insert(entries, { item = it, mutation = s[2], income = inc, displayed = false })
	end
end
table.sort(entries, function(a, b) return a.income > b.income end)
for i = 1, 4 do entries[i].displayed = true end
local DISPLAY_MAX = 6
local function displayedCount() local n = 0 for _, e in entries do if e.displayed then n += 1 end end return n end

local displaysText = find(win, "Displays")
local counterText = find(win, "Counter")
local function refreshCounters(bumpIt)
	displaysText.Text = string.format("%d / %d displays", displayedCount(), DISPLAY_MAX)
	counterText.Text = string.format("%d / 30 items", #entries)
	if bumpIt then bump(displaysText.Parent) end
end

-- cartes d'objets -------------------------------------------------------------
local itemsCards = find(win, "ItemsSection.Cards")
local itemTpl = itemsCards.Template
local cards = {}
local function paintItem(card, e)
	card.DisplayedBadge.Visible = e.displayed
	card.PlaceButton.Visible = not e.displayed
	card.UnequipButton.Visible = e.displayed -- objet posé : bouton rouge pour le reprendre (retour de Clément)
end
for i, e in entries do
	local card = itemTpl:Clone()
	card.Name = string.format("Item_%02d_%s", i, e.item.Id); card.LayoutOrder = i; card.Visible = true
	local rar = Rarities.ById[e.item.Rarity]
	card.Clip.Rays.ImageColor3 = rar.Color; card.Clip.Glow.ImageColor3 = rar.Color
	card.Icon.Image = Icons.get(e.item.Id) or ""
	card.ItemName.Text = string.upper(e.item.DisplayName)
	card.Income.Text = "+" .. money(e.income) .. "/s"
	card.RarityBar.Rarity.Text = rar.DisplayNameUpper
	local label = Mutations.Label(e.mutation)
	card.MutationTag.Visible = label ~= nil
	if label then card.MutationTag.MutationLabel.Text = string.upper(label) end
	paintItem(card, e)
	card.Parent = itemsCards
	cards[i] = card
	local function place()
		if e.displayed then return end
		if displayedCount() >= DISPLAY_MAX then
			play("Deny"); shake(card.PlaceButton); toast("All your displays are full!")
			return
		end
		e.displayed = true
		card.PlaceButton.Visible = false
		pop(card.UnequipButton); pop(card.DisplayedBadge)
		play("Success"); refreshCounters(true)
		toast(string.upper(e.item.DisplayName) .. " placed on a display!")
	end
	local function unequip()
		if not e.displayed then return end
		e.displayed = false
		card.UnequipButton.Visible = false; card.DisplayedBadge.Visible = false
		pop(card.PlaceButton)
		play("Remove"); refreshCounters(true)
		toast(string.upper(e.item.DisplayName) .. " removed from its display")
	end
	-- un clic sur la carte fait ce que montre son bouton : poser, ou reprendre
	hoverCard(card, function() if e.displayed then unequip() else place() end end)
	hoverButton(card.PlaceButton, place)
	hoverButton(card.UnequipButton, unequip)
end
find(win, "ItemsSection.SectionCount.CountLabel").Text = tostring(#entries)

-- cartes de colis -------------------------------------------------------------
local boxCards = find(win, "BoxesSection.Cards")
local boxTpl = boxCards.Template
local BOXES = { { "Standard", "Common", false }, { "Premium", "Rare", false }, { "Luxe", "Epic", true } }
local assets = RS:FindFirstChild("Assets")
for i, b in BOXES do
	local card = boxTpl:Clone()
	card.Name = "Box_" .. i; card.LayoutOrder = i; card.Visible = true
	local rar = Rarities.ById[b[2]]
	card.Clip.Rays.ImageColor3 = rar.Color; card.Clip.Glow.ImageColor3 = rar.Color
	card.BoxName.Text = string.upper(b[1]) .. " BOX"
	card.RarityBar.Rarity.Text = rar.DisplayNameUpper
	-- l'icône ICON_BOX_<Tier> si Clément l'a importée, sinon le modèle BOX_<Tier> dans une ViewportFrame
	local model = assets and assets:FindFirstChild("BOX_" .. b[1], true)
	local icon = card.Icon
	local boxIcon = Icons.get("BOX_" .. b[1])
	if boxIcon then icon.Image = boxIcon end
	if model and boxIcon == nil then
		local vf = Instance.new("ViewportFrame")
		vf.Name = "BoxView"; vf.BackgroundTransparency = 1; vf.AnchorPoint = icon.AnchorPoint; vf.Position = icon.Position; vf.Size = icon.Size; vf.ZIndex = icon.ZIndex
		local m = model:Clone(); m.Parent = vf
		local cf, size = m:GetBoundingBox()
		local cam = Instance.new("Camera"); cam.FieldOfView = 30
		local dist = size.Magnitude * 1.9
		cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(dist * 0.55, dist * 0.45, -dist * 0.7), cf.Position)
		cam.Parent = vf; vf.CurrentCamera = cam
		vf.Parent = card; icon.Visible = false
	end
	card.Parent = boxCards
	local floor = b[3]
	local function setFloor(isFloor, seconds)
		card.PlaceButton.Visible = not isFloor
		card.PlacedPill.Visible = isFloor
		card.ReadyPill.Visible = not isFloor
		card.TimerPill.Visible = isFloor
		if isFloor then
			task.spawn(function()
				for s = seconds, 1, -1 do
					if not card.Parent then return end
					card.TimerPill.TimerLabel.Text = string.format("0:%02d", s)
					task.wait(1)
				end
				if card.Parent then card.TimerPill.Visible = false; pop(card.ReadyPill) end
			end)
		end
	end
	setFloor(floor, 42)
	local function place()
		if card.PlacedPill.Visible then return end
		play("Success"); pop(card.PlacedPill); card.PlaceButton.Visible = false
		card.ReadyPill.Visible = false; pop(card.TimerPill)
		setFloor(true, 10)
		toast(string.upper(b[1]) .. " BOX placed on the floor of your shop!")
	end
	hoverCard(card, place)
	hoverButton(card.PlaceButton, place)
end

-- outils ----------------------------------------------------------------------
local toolCard, batCard = find(win, "ToolCard"), find(win, "BatCard")
local equipped = toolCard
local function paintTools()
	for _, c in { toolCard, batCard } do
		c.EquipButton.Visible = c ~= equipped
		c.EquippedPill.Visible = c == equipped
	end
end
paintTools()
for _, c in { toolCard, batCard } do
	local function equip()
		if equipped == c then return end
		equipped = c; paintTools(); pop(c.EquippedPill); bump(c)
		play("Success"); toast(c.ToolName.Text .. " equipped!")
	end
	hoverCard(c, equip)
	hoverButton(c.EquipButton, equip)
end

-- Equip Best : les meilleurs objets passent un par un sur les présentoirs
hoverButton(win.EquipBestButton, function()
	local placed = 0
	for i, e in entries do
		if not e.displayed and displayedCount() < DISPLAY_MAX then
			e.displayed = true; placed += 1
			local card = cards[i]
			task.delay(placed * 0.08, function()
				card.PlaceButton.Visible = false; pop(card.UnequipButton); pop(card.DisplayedBadge)
				refreshCounters(true)
			end)
		end
	end
	if placed == 0 then play("Deny"); shake(win.EquipBestButton); toast("Your best items are already on display!") return end
	play("Success"); toast(string.format("Equipped your %d best item%s!", placed, placed > 1 and "s" or ""))
end)
refreshCounters(false)

-- ouverture, fermeture ----------------------------------------------------------
local isOpen, busy = false, false
local function staggerTargets()
	local list = {}
	local function add(o) if o and o:IsA("GuiObject") and o.Visible then table.insert(list, o) end end
	add(find(win, "DisplayPill")); add(win.EquipBestButton)
	add(find(win, "Equipment.SectionTitle")); add(toolCard); add(batCard)
	add(find(win, "BoxesSection.TitleRow"))
	for i = 1, #BOXES do add(boxCards:FindFirstChild("Box_" .. i)) end
	add(find(win, "ItemsSection.TitleRow"))
	for _, c in cards do add(c) end
	return list
end
local function open()
	if isOpen or busy then return end
	isOpen = true
	gui.Enabled = true; play("Open")
	win.List.CanvasPosition = Vector2.zero
	rootScale.Scale = M.OpenFrom
	tween(rootScale, M.OpenTime, { Scale = 1 }, Enum.EasingStyle.Back)
	for i, o in staggerTargets() do
		local s = scaleOf(o); s.Scale = 0
		task.delay(M.StaggerStart + (i - 1) * M.StaggerGap, function()
			tween(s, M.StaggerTime, { Scale = 1 }, Enum.EasingStyle.Back)
		end)
	end
end
local function close()
	if not isOpen or busy then return end
	busy = true; play("Close")
	tween(rootScale, M.CloseTime, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(M.CloseTime, function() gui.Enabled = false; isOpen = false; busy = false end)
end
hoverButton(win.CloseButton, close)
local invBtn = rail:FindFirstChild("InventoryButton")
hoverButton(invBtn, function() if isOpen then close() else open() end end)
for _, b in rail:GetChildren() do if b:IsA("GuiButton") and b ~= invBtn then hoverButton(b, nil) end end

_G.InventoryProto = {
	Stop = function()
		for _, c in conns do c:Disconnect() end
		table.clear(conns)
		if gui.Parent then gui:Destroy() end
		if hudCopy.Parent then hudCopy:Destroy() end
		_G.InventoryProto = nil
	end,
	Open = open, Close = close, Values = M,
	-- joue chaque son l'un après l'autre et affiche son nom, pour vérifier à l'oreille
	SoundTest = function()
		task.spawn(function()
			for _, k in { "Hover", "Click", "Success", "Open", "Close", "Deny" } do
				toast("SOUND: " .. k, Color3.fromHex("ffffff")); SoundService:PlayLocalSound(snd[k]); task.wait(1.4)
			end
		end)
	end,
	State = function() return { open = isOpen, displayed = displayedCount(), equipped = equipped.Name } end,
}
open()
return "prototype pret"
