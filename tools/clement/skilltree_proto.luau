--!nocheck
-- Prototype jouable de l'arbre de compétences (UI_SkillTree v3) : animations à valider par Clément.
-- À lancer en Edit (barre de commande de Studio, ou Claude par le MCP). Rien n'est enregistré dans la
-- place : la copie vit dans CoreGui (_PROTO_SkillTree) et disparaît à la fermeture de Studio.
-- Relancer ce script recommence de zéro. _G.SkillTreeProto.Stop() retire la copie.
-- Valeurs d'animation : tableau M ci-dessous, recopié dans docs/claude/notes/ui-motion-skilltree.md.
-- Jamais dans l'UI ni dans src/ : c'est un outil de Clément.

local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")
local AssetService = game:GetService("AssetService")

if _G.SkillTreeProto and _G.SkillTreeProto.Stop then pcall(_G.SkillTreeProto.Stop) end

-- Valeurs d'animation (secondes, échelles) ---------------------------------------------------------
local M = {
	OpenFade = 0.25,                         -- fond qui apparaît
	PopTime = 0.38, PopStagger = 0.055,      -- tuiles « bop bop bop » : durée, décalage entre deux tuiles
	PopStyle = Enum.EasingStyle.Back,        -- rebond au-dessus de 1 puis 1
	PanelSlideTime = 0.42,                   -- panneau de gauche qui glisse depuis le bord
	HoverScale = 1.07, HoverTime = 0.12,     -- tuile ou bouton survolé
	PressScale = 0.88, PressTime = 0.07,     -- tuile qui s'enfonce
	ReleaseTime = 0.3,                       -- retour après l'appui (Back)
	ButtonHover = 1.05, ButtonPress = 0.92,  -- boutons (BUY, Close)
	SelectOut = 0.08, SelectIn = 0.2, SelectFrom = 0.92, -- contour de sélection : s'efface, puis apparaît en douceur sur la tuile choisie
	DragThreshold = 6,                       -- px avant qu'un appui devienne un glisser (sinon c'est un clic)
	StartTilePx = 100,                       -- zoom de départ : les tuiles font au moins 100 px (téléphone)
	ZoomMin = 0.75, ZoomMax = 1.8, ZoomStep = 0.12, ZoomTime = 0.14, -- molette : ±12 % par cran, lissé
	PanLimit = 0.55,                         -- on peut décaler l'arbre de 55 % de sa taille (zoomée) au plus
	Rubber = 0.35,                           -- au-delà de la limite, l'arbre suit à 35 % (élastique)
	SnapTime = 0.35,                         -- au relâché hors limite, retour en douceur (Back)
	PanelSwapFrom = 0.9, PanelSwapTime = 0.25, -- panneau qui « rebondit » quand il change de tuile
	PunchScale = 1.3, PunchUp = 0.09,        -- achat : la tuile gonfle vite…
	PunchSettle = 0.6,                       -- …puis revient avec un rebond élastique
	FlashTime = 0.35,                        -- éclat blanc sur la tuile achetée
	SparkCount = 12, SparkDistance = 0.9, SparkTime = 0.55, -- étincelles (distance en largeurs de tuile)
	RevealDelay = 0.3,                       -- attente avant que la tuile voisine se découvre
	RevealShrink = 0.1, RevealPop = 0.45,    -- elle se retourne (rétrécit) puis pop avec rebond
	NewBadgeHold = 1.6,                      -- badge NEW! visible
	CashRoll = 0.6, CashBump = 1.15, CashBumpTime = 0.3, -- argent qui défile et compteur qui sursaute
	FloatTime = 0.9, FloatRise = 0.06,       -- « +$350K » qui monte et s'efface (en part de l'écran)
	ShakeTime = 0.3, ShakeAmp = 6,           -- bouton « Need $… » qui refuse (px)
	CloseTime = 0.14, CloseStagger = 0.012,  -- fermeture : les tuiles rentrent en cascade inverse
	IncomeEvery = 2.5, IncomeAmount = 350e3, -- démo : argent gagné toutes les 2,5 s
}

-- Copie de l'écran ------------------------------------------------------------------------------
local source = StarterGui:FindFirstChild("UI_SkillTree")
assert(source, "StarterGui.UI_SkillTree introuvable")
local gui = source:Clone()
gui.Name = "_PROTO_SkillTree"
gui.Enabled = true
local tree, panel, cashLabel = gui.Tree, gui.InfoPanel, gui.CashPill.Cash
local connections, alive = {}, true
local function on(signal, fn) local c = signal:Connect(fn) table.insert(connections, c) return c end
local function tween(obj, t, props, style, dir, delay)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out, 0, false, delay or 0), props)
	tw:Play()
	return tw
end
local function scaleOf(obj)
	local s = obj:FindFirstChild("ProtoScale")
	if not s then s = Instance.new("UIScale") s.Name = "ProtoScale" s.Parent = obj end
	return s
end

-- Hexagones dessinés en direct tant que UI_Hex_Fill et UI_Hex_Gloss ne sont pas importées ---------
local function hexImage(size, scale, radius, gloss)
	local m = 2
	local w = (size - 2 * m) * scale
	local base = { { 0, -w / 2 }, { w / 2, -w / 4 }, { w / 2, w / 4 }, { 0, w / 2 }, { -w / 2, w / 4 }, { -w / 2, -w / 4 } }
	local lines = {}
	for i = 1, 6 do
		local p1, p2 = base[i], base[i % 6 + 1]
		local ex, ey = p2[1] - p1[1], p2[2] - p1[2]
		local L = math.sqrt(ex * ex + ey * ey)
		local nx, ny = ey / L, -ex / L
		lines[i] = { nx, ny, nx * p1[1] + ny * p1[2] - radius }
	end
	local pts = {}
	for i = 1, 6 do
		local a, b = lines[(i - 2) % 6 + 1], lines[i]
		local det = a[1] * b[2] - b[1] * a[2]
		pts[i] = { (a[3] * b[2] - b[3] * a[2]) / det, (a[1] * b[3] - b[1] * a[3]) / det }
	end
	local buf = buffer.create(size * size * 4)
	for y = 0, size - 1 do
		local py = y + 0.5 - size / 2
		local ramp = gloss and math.clamp((0.52 - (y + 0.5) / size) / 0.4, 0, 1) ^ 1.3 or 1
		for x = 0, size - 1 do
			local px = x + 0.5 - size / 2
			local d, inside = math.huge, true
			for i = 1, 6 do
				local p1, p2 = pts[i], pts[i % 6 + 1]
				local ex, ey = p2[1] - p1[1], p2[2] - p1[2]
				local qx, qy = px - p1[1], py - p1[2]
				local t = math.clamp((qx * ex + qy * ey) / (ex * ex + ey * ey), 0, 1)
				local dx, dy = qx - t * ex, qy - t * ey
				d = math.min(d, math.sqrt(dx * dx + dy * dy))
				if ex * qy - ey * qx < 0 then inside = false end
			end
			local sd = (inside and -d or d) - radius
			local a = math.clamp(0.5 - sd, 0, 1) * ramp
			local o = (y * size + x) * 4
			buffer.writeu8(buf, o, 255) buffer.writeu8(buf, o + 1, 255) buffer.writeu8(buf, o + 2, 255)
			buffer.writeu8(buf, o + 3, math.floor(a * 255 + 0.5))
		end
		if y % 64 == 63 then task.wait() end
	end
	local img = AssetService:CreateEditableImage({ Size = Vector2.new(size, size) })
	img:WritePixelsBuffer(Vector2.zero, Vector2.new(size, size), buf)
	return img
end
local fillImg, glossImg
for _, d in gui:GetDescendants() do
	if d:IsA("ImageLabel") and d.Image == "" then
		local a = d:GetAttribute("IconAsset")
		if a == "UI_Hex_Fill" then fillImg = fillImg or hexImage(256, 1, 15, false); d.ImageContent = Content.fromObject(fillImg)
		elseif a == "UI_Hex_Gloss" then glossImg = glossImg or hexImage(128, 0.86, 6.5, true); d.ImageContent = Content.fromObject(glossImg) end
	end
end

-- Données de démo (valeurs V0 de la Partie 2, section 2 ; « — » = rien de décidé) -----------------
local function money(n)
	if n == nil then return "—" end
	local units = { { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
	for _, u in units do
		if n >= u[1] then
			local v = n / u[1]
			local s = v >= 100 and string.format("%d", math.floor(v + 0.5)) or v >= 10 and string.format("%.1f", v) or string.format("%.2f", v)
			if s:find("%.") then s = s:gsub("0+$", ""):gsub("%.$", "") end
			return "$" .. s .. u[2]
		end
	end
	return "$" .. math.floor(n)
end
local ROMAN = { "I", "II", "III", "IV", "V" }
local D = {
	Tile_ShopLevel = { title = "SHOP LEVEL", stat = "Shop size", vals = { "Stand", "Shop", "Store", "Concept Store", "Flagship" }, prices = { 10e3, 250e3, 6.25e6, 156e6 }, lv = 1, short = "vals", reveals = { Tile_Next1 = 2 } },
	Tile_Glass = { title = "GLASS", stat = "Glass HP", vals = { "×1", "×1.5", "×2", "×3", "×5", "×8" }, prices = { 25e3, 300e3, 4e6, 50e6, 600e6 }, lv = 2, label = "Glass" },
	Tile_GlassRegen = { title = "GLASS REGEN", stat = "Glass repair / s", vals = { "3%", "4%", "5%", "6%", "7%", "8%" }, prices = { 50e3, 500e3, 5e6, 50e6, 500e6 }, lv = 0, label = "Regen", reveals = { Tile_Next4 = 1 } },
	Tile_Cameras = { title = "CAMERAS", stat = "Camera", vals = { "Off", "Alert", "X-Ray 30s", "Tracker" }, prices = { 5e3, 150e3, 5e6 }, lv = 2, label = "Cameras", roman = true },
	Tile_Guards = { title = "BODYGUARDS", stat = "Guard speed", vals = { "—", "20", "28", "36", "44", "52" }, prices = { 100e3, 2e6, 40e6, 800e6, 16e9 }, lv = 1, label = "Guards", roman = true },
	Tile_Curtain = { title = "CURTAIN", stat = "Shutter time", vals = { "30s", "60s", "90s" }, prices = { 50e3, 1e6 }, lv = 0, label = "Curtain" },
	Tile_DoorGuard = { title = "DOOR GUARD", stat = "Guard at the door", vals = { "Off", "On" }, prices = {}, max = 1, lv = 0, label = "Door Guard" },
	Tile_PotionLuck = { title = "POTION LUCK", stat = "Potion find chance", vals = { "—", "—", "—", "—" }, prices = {}, max = 3, lv = 0, label = "Potion Luck" },
	Tile_PotionTime = { title = "POTION TIME", stat = "Potion duration", vals = { "—", "—", "—" }, prices = {}, max = 2, lv = 0, label = "Potion Time", locked = true },
	Tile_Next1 = { title = "TRAPS", stat = "Trap slots", vals = { "0", "1" }, prices = {}, max = 1, lv = 0, label = "Traps", locked = true, icon = "rbxassetid://139426237365677" },
	Tile_Next4 = { title = "SAFE", stat = "Safe stands", vals = { "+0", "+1", "+2" }, prices = { 250e3, 25e6 }, lv = 0, label = "Safe", locked = true, icon = "rbxassetid://112359396081383" },
	Tile_Next2 = { locked = true, never = true },
}
for _, t in D do t.prices = t.prices or {} t.vals = t.vals or { "—" } t.lv = t.lv or 0 t.max = t.max or #t.prices end
local cash = 1.4e6
local selected = "Tile_ShopLevel"

local function tileName(t)
	if t.short == "vals" then return t.vals[t.lv + 1] end
	if t.roman then return t.lv > 0 and (t.label .. " " .. ROMAN[t.lv]) or t.label end
	if t.lv > 0 and t.vals[t.lv + 1] ~= "—" then return t.label .. " " .. t.vals[t.lv + 1] end
	return t.label
end
local function nextPrice(t) if t.lv >= t.max then return nil end return t.prices[t.lv + 1] end

local function refreshTile(name)
	local t, tile = D[name], tree:FindFirstChild(name)
	if not t or not tile or t.never then return end
	local state = t.locked and "Locked" or (t.lv > 0 and "Bought" or "Available")
	tile.Bought.Visible = state == "Bought"
	tile.Available.Visible = state == "Available"
	tile.Locked.Visible = state == "Locked"
	tile.Info.Visible = state ~= "Locked"
	local info = tile.Info
	info.Level.Text = t.lv >= t.max and "MAX" or ("Lv " .. t.lv .. "/" .. t.max)
	info.TileName.Text = tileName(t)
	if t.icon then info.Icon.Image = t.icon end
	local p = nextPrice(t)
	local maxed = t.lv >= t.max
	info.PriceRow.Price.Text = maxed and "MAX" or money(p)
	info.PriceRow.PriceNeed.Text = money(p)
	local need = p ~= nil and p > cash and not maxed
	info.PriceRow.Price.Visible = not need
	info.PriceRow.PriceNeed.Visible = need
end
local function refreshPanel()
	local t, tile = D[selected], tree:FindFirstChild(selected)
	panel.Header.NodeName.Text = t.title
	panel.NodeIcon.Image = tile.Info.Icon.Image
	panel.NodeLevel.Text = "Level " .. t.lv .. " / " .. t.max
	panel.StatBox.NodeStat.Text = t.stat
	local cur, nxt = t.vals[t.lv + 1], t.vals[t.lv + 2]
	panel.StatBox.NodeEffect.Text = (t.lv >= t.max or not nxt) and (cur .. "  (MAX)") or (cur .. "  ▶  " .. nxt)
	local p = nextPrice(t)
	panel.PriceRow.NodePrice.Text = t.lv >= t.max and "MAX" or money(p)
	local canBuy = p ~= nil and p <= cash
	panel.BuyButton.Visible = canBuy
	panel.NeedButton.Visible = not canBuy
	panel.NeedButton.NeedLabel.Text = t.lv >= t.max and "MAX LEVEL" or (p == nil and "Coming soon" or ("Need " .. money(p)))
end
local function refreshAll() for name in D do refreshTile(name) end refreshPanel() cashLabel.Text = money(cash) end

-- Effets -----------------------------------------------------------------------------------------
local function floatText(parent, str, color, pos)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1 l.Text = str l.TextColor3 = color l.TextScaled = true
	l.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
	l.AnchorPoint = Vector2.new(0.5, 0.5) l.Position = pos l.Size = UDim2.fromScale(0.16, 0.045) l.ZIndex = 40
	local s = Instance.new("UIStroke") s.Thickness = 3 s.Parent = l
	l.Parent = parent
	tween(l, M.FloatTime, { Position = pos - UDim2.fromScale(0, M.FloatRise), TextTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	tween(s, M.FloatTime, { Transparency = 1 })
	task.delay(M.FloatTime, function() l:Destroy() end)
end
local function rollCash(to)
	local from = cash
	cash = to
	local v = Instance.new("NumberValue") v.Value = from
	on(v.Changed, function(x) cashLabel.Text = money(x) end)
	tween(v, M.CashRoll, { Value = to }, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
	local s = scaleOf(gui.CashPill)
	s.Scale = M.CashBump
	tween(s, M.CashBumpTime, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(M.CashRoll, function() v:Destroy() end)
end
local function sparks(tile)
	for i = 1, M.SparkCount do
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5) f.BorderSizePixel = 0 f.ZIndex = 30
		f.BackgroundColor3 = (i % 3 == 0) and Color3.fromHex("FFFFFF") or Color3.fromHex("FFD23F")
		f.Size = UDim2.fromScale(0.022, 0.026) f.Rotation = 45 f.Position = tile.Position
		local st = Instance.new("UIStroke") st.Thickness = 2 st.Color = Color3.fromHex("040435") st.Parent = f
		f.Parent = tree
		local ang = (i / M.SparkCount) * math.pi * 2 + math.random() * 0.3
		local dist = M.SparkDistance * (0.7 + math.random() * 0.5)
		local dx, dy = math.cos(ang) * dist * 150 / 800, math.sin(ang) * dist * 150 / 650
		tween(f, M.SparkTime, { Position = tile.Position + UDim2.fromScale(dx, dy), Rotation = 45 + 180, BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
		tween(st, M.SparkTime, { Transparency = 1 })
		task.delay(M.SparkTime, function() f:Destroy() end)
	end
end
local function flash(tile)
	local layer = tile.Bought.Visible and tile.Bought or tile.Available
	local f = layer.Body:Clone()
	f.Name = "Flash" f.ImageColor3 = Color3.new(1, 1, 1) f.ImageTransparency = 0 f.ZIndex = 8
	f.Parent = tile
	tween(f, M.FlashTime, { ImageTransparency = 1 })
	task.delay(M.FlashTime, function() f:Destroy() end)
end
local function badge(tile)
	local b = Instance.new("TextLabel")
	b.Text = "NEW!" b.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy) b.TextScaled = true
	b.TextColor3 = Color3.fromHex("1B1B24") b.BackgroundColor3 = Color3.fromHex("FFD23F") b.BorderSizePixel = 0
	b.AnchorPoint = Vector2.new(0.5, 0.5) b.Position = UDim2.fromScale(0.78, 0.14) b.Size = UDim2.fromScale(0.46, 0.17) b.Rotation = 12 b.ZIndex = 12
	local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0.5, 0) c.Parent = b
	local s = Instance.new("UIStroke") s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border s.Thickness = 2 s.Parent = b
	b.Parent = tile
	local sc = scaleOf(b) sc.Scale = 0
	tween(sc, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(M.NewBadgeHold, function() tween(sc, 0.15, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In) task.delay(0.16, function() b:Destroy() end) end)
end
local function reveal(name)
	local t, tile = D[name], tree:FindFirstChild(name)
	if not t or not tile or not t.locked or t.never then return end
	local s = scaleOf(tile)
	tween(s, M.RevealShrink, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(M.RevealShrink, function()
		t.locked = false
		refreshTile(name)
		tween(s, M.RevealPop, { Scale = 1 }, M.PopStyle)
		sparks(tile)
		badge(tile)
	end)
end
local function shake(obj)
	local p0 = obj.Position
	for i = 1, 4 do
		task.delay((i - 1) * M.ShakeTime / 4, function()
			tween(obj, M.ShakeTime / 8, { Position = p0 + UDim2.fromOffset((i % 2 == 0) and -M.ShakeAmp or M.ShakeAmp, 0) })
		end)
	end
	task.delay(M.ShakeTime, function() tween(obj, 0.06, { Position = p0 }) end)
end

-- Sélection et achat ----------------------------------------------------------------------------
local glow = tree.SelectionGlow
local glowTarget = {}
for _, c in glow:GetChildren() do if c:IsA("ImageLabel") then glowTarget[c] = c.ImageTransparency end end
local glowToken = 0
local function select(name)
	local tile = tree:FindFirstChild(name)
	if not tile or not D[name] or D[name].locked then return end
	if name == selected and glow.Position == tile.Position then refreshPanel() return end
	selected = name
	-- Le contour s'efface, se pose sous la nouvelle tuile, puis apparaît en douceur (la tuile ne bouge pas)
	glowToken += 1
	local token = glowToken
	for c in glowTarget do tween(c, M.SelectOut, { ImageTransparency = 1 }) end
	task.delay(M.SelectOut, function()
		if token ~= glowToken then return end
		glow.Position = tile.Position
		local gs = scaleOf(glow)
		gs.Scale = M.SelectFrom
		tween(gs, M.SelectIn, { Scale = 1 }, Enum.EasingStyle.Quad)
		for c, to in glowTarget do tween(c, M.SelectIn, { ImageTransparency = to }) end
	end)
	refreshPanel()
	local s = scaleOf(panel)
	s.Scale = M.PanelSwapFrom
	tween(s, M.PanelSwapTime, { Scale = 1 }, Enum.EasingStyle.Back)
end
local function buy()
	local t, tile = D[selected], tree:FindFirstChild(selected)
	local p = nextPrice(t)
	if p == nil or p > cash then shake(panel.NeedButton) return end
	floatText(gui, "-" .. money(p), Color3.fromHex("FF5A5A"), gui.CashPill.Position + UDim2.fromScale(0, 0.09))
	rollCash(cash - p)
	t.lv += 1
	refreshTile(selected)
	local s = scaleOf(tile)
	tween(s, M.PunchUp, { Scale = M.PunchScale }, Enum.EasingStyle.Quad)
	task.delay(M.PunchUp, function() tween(s, M.PunchSettle, { Scale = 1 }, Enum.EasingStyle.Elastic) end)
	flash(tile) sparks(tile)
	refreshPanel()
	for child, need in t.reveals or {} do
		if t.lv >= need then task.delay(M.RevealDelay, function() reveal(child) end) end
	end
	task.delay(M.CashRoll, function() for name in D do refreshTile(name) end refreshPanel() end)
end

-- Interactions ----------------------------------------------------------------------------------
local function hoverPress(btn, hoverScale, pressScale, onClick)
	local s = scaleOf(btn)
	local inside = false
	on(btn.MouseEnter, function() inside = true tween(s, M.HoverTime, { Scale = hoverScale }) end)
	on(btn.MouseLeave, function() inside = false tween(s, M.HoverTime, { Scale = 1 }) end)
	on(btn.MouseButton1Down, function() tween(s, M.PressTime, { Scale = pressScale }) end)
	on(btn.MouseButton1Up, function() tween(s, M.ReleaseTime, { Scale = inside and hoverScale or 1 }, Enum.EasingStyle.Back) end)
	if onClick then on(btn.MouseButton1Click, onClick) end
end
-- Navigation : une couche transparente au-dessus de l'arbre (sous le panneau, l'argent et Close) reçoit
-- souris, molette et doigts. Clic = tuile sous le pointeur ; glisser = déplacer ; molette ou pincement = zoom.
local layer = Instance.new("TextButton")
layer.Name = "NavLayer" layer.Text = "" layer.AutoButtonColor = false layer.BackgroundTransparency = 1
layer.Size = UDim2.fromScale(1, 1) layer.ZIndex = 15 layer.Active = true
layer.Parent = gui
local treeBase = tree.Position
local zoomScale = Instance.new("UIScale") zoomScale.Name = "ZoomScale" zoomScale.Parent = tree
local zoom, pan = 1, Vector2.zero
local function inHex(p, tile)
	local s = tile.AbsoluteSize.X * 0.95
	local c = tile.AbsolutePosition + tile.AbsoluteSize / 2
	local x, y = math.abs(p.X - c.X) / (s / 2), (p.Y - c.Y) / (s / 2)
	return x <= 1 and math.abs(y) <= 1 - x / 2
end
local function tileAt(p)
	for _, t in tree:GetChildren() do if t:IsA("TextButton") and inHex(p, t) then return t end end
	return nil
end
local function limits(z)
	local size = tree.AbsoluteSize / zoomScale.Scale * z
	return size.X * M.PanLimit, size.Y * M.PanLimit
end
local function clampPan(p, z, soft)
	local lx, ly = limits(z)
	local function c(v, l)
		if math.abs(v) <= l then return v end
		local excess = math.abs(v) - l
		return math.sign(v) * (l + (soft and excess * M.Rubber or 0))
	end
	return Vector2.new(c(p.X, lx), c(p.Y, ly))
end
local function applyView(t)
	local pos = treeBase + UDim2.fromOffset(pan.X, pan.Y)
	if t and t > 0 then
		tween(tree, t, { Position = pos }, Enum.EasingStyle.Quad)
		tween(zoomScale, t, { Scale = zoom }, Enum.EasingStyle.Quad)
	else
		tree.Position = pos
		zoomScale.Scale = zoom
	end
end
local function zoomAt(p, newZoom)
	newZoom = math.clamp(newZoom, M.ZoomMin, M.ZoomMax)
	local k = newZoom / zoom
	-- centre actuel de l'arbre à l'écran ; le point sous le pointeur reste sous le pointeur
	local c = Vector2.new(treeBase.X.Scale * gui.AbsoluteSize.X + treeBase.X.Offset, treeBase.Y.Scale * gui.AbsoluteSize.Y + treeBase.Y.Offset) + pan
	pan = pan + (p - c) * (1 - k)
	zoom = newZoom
	pan = clampPan(pan, zoom, false)
	applyView(M.ZoomTime)
end
local hovered, pressed
local function setHover(t)
	if t == hovered then return end
	if hovered and hovered ~= pressed then tween(scaleOf(hovered), M.HoverTime, { Scale = 1 }) end
	hovered = t
	if t and t ~= pressed then tween(scaleOf(t), M.HoverTime, { Scale = M.HoverScale }) end
end
local pointers, downPos, panStart, dragging, pinch = {}, nil, nil, false, nil
local function count() local n = 0 for _ in pointers do n += 1 end return n end
on(layer.InputBegan, function(input)
	local kind = input.UserInputType
	if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then return end
	local p = Vector2.new(input.Position.X, input.Position.Y)
	pointers[input] = p
	if count() == 1 then
		downPos, panStart, dragging = p, pan, false
		pressed = tileAt(p)
		if pressed then tween(scaleOf(pressed), M.PressTime, { Scale = M.PressScale }) end
	elseif count() == 2 then
		-- Pincement : distance de départ, zoom de départ ; l'appui en cours n'est plus un clic
		local a, b
		for _, q in pointers do if a then b = q else a = q end end
		pinch = { dist = (a - b).Magnitude, zoom = zoom }
		if pressed then tween(scaleOf(pressed), M.ReleaseTime, { Scale = 1 }, Enum.EasingStyle.Back) pressed = nil end
		dragging = true
	end
end)
on(layer.InputChanged, function(input)
	local kind = input.UserInputType
	local p = Vector2.new(input.Position.X, input.Position.Y)
	if kind == Enum.UserInputType.MouseWheel then
		zoomAt(p, zoom * (1 + M.ZoomStep * input.Position.Z))
		return
	end
	if kind == Enum.UserInputType.Touch and pointers[input] then pointers[input] = p end
	local moving = (kind == Enum.UserInputType.MouseMovement and downPos ~= nil and next(pointers) ~= nil) or (kind == Enum.UserInputType.Touch and pointers[input])
	if not moving then
		if kind == Enum.UserInputType.MouseMovement then setHover(tileAt(p)) end
		return
	end
	if pinch and count() >= 2 then
		local a, b
		for _, q in pointers do if a then b = q elseif not b then a = q end end
		if a and b then
			local mid = (a + b) / 2
			zoomAt(mid, pinch.zoom * (a - b).Magnitude / math.max(pinch.dist, 1))
		end
		return
	end
	local delta = p - downPos
	if not dragging and delta.Magnitude > M.DragThreshold then
		dragging = true
		if pressed then tween(scaleOf(pressed), M.ReleaseTime, { Scale = 1 }, Enum.EasingStyle.Back) pressed = nil end
		setHover(nil)
	end
	if dragging then
		pan = clampPan(panStart + delta, zoom, true)
		applyView(0)
	end
end)
on(layer.InputEnded, function(input)
	if not pointers[input] then return end
	pointers[input] = nil
	if count() > 0 then return end
	if pinch then pinch = nil end
	if not dragging and pressed then
		local t = pressed
		pressed = nil
		tween(scaleOf(t), M.ReleaseTime, { Scale = (t == hovered) and M.HoverScale or 1 }, Enum.EasingStyle.Back)
		if t.Name ~= "RootTile" then select(t.Name) end
	end
	if dragging then
		local target = clampPan(pan, zoom, false)
		if target ~= pan then pan = target tween(tree, M.SnapTime, { Position = treeBase + UDim2.fromOffset(pan.X, pan.Y) }, Enum.EasingStyle.Back) end
	end
	dragging, downPos = false, nil
end)
hoverPress(panel.BuyButton, M.ButtonHover, M.ButtonPress, buy)
hoverPress(panel.NeedButton, M.ButtonHover, M.ButtonPress, function() shake(panel.NeedButton) end)

-- Ouverture, fermeture -------------------------------------------------------------------------
local opener -- petit bouton pour rouvrir, visible quand l'écran est fermé
local function axial(tile) local q, r = tile:GetAttribute("Q") or 0, tile:GetAttribute("R") or 0 return (math.abs(q) + math.abs(r) + math.abs(q + r)) / 2, math.atan2(r, q) end
local function orderedTiles()
	local list = {}
	for _, tile in tree:GetChildren() do if tile:IsA("TextButton") then table.insert(list, tile) end end
	table.sort(list, function(a, b) local da, aa = axial(a) local db, ab = axial(b) if da ~= db then return da < db end return aa < ab end)
	return list
end
local panelPos, pillPos, closePos = panel.Position, gui.CashPill.Position, gui.CloseButton.Position
local function open()
	gui.Enabled = true
	if opener then opener.Enabled = false end
	-- Zoom de départ : 1, ou plus si l'écran est petit (tuiles d'au moins StartTilePx)
	local scr = gui.AbsoluteSize
	local h = tree.Size.Y.Scale * scr.Y + tree.Size.Y.Offset
	local w = math.min(h * 800 / 650, scr.X)
	local tilePx = w * 150 / 800
	zoom, pan = (tilePx > 0) and math.clamp(M.StartTilePx / tilePx, 1, M.ZoomMax) or 1, Vector2.zero
	applyView(0)
	for c, to in glowTarget do c.ImageTransparency = to end
	gui.Backdrop.BackgroundTransparency = 1
	tween(gui.Backdrop, M.OpenFade, { BackgroundTransparency = 0 })
	for i, tile in orderedTiles() do
		local s = scaleOf(tile) s.Scale = 0
		tween(s, M.PopTime, { Scale = 1 }, M.PopStyle, Enum.EasingDirection.Out, 0.12 + (i - 1) * M.PopStagger)
	end
	local gs = scaleOf(tree.SelectionGlow) gs.Scale = 0
	tween(gs, M.PopTime, { Scale = 1 }, M.PopStyle, Enum.EasingDirection.Out, 0.12 + 13 * M.PopStagger)
	panel.Position = panelPos - UDim2.fromScale(0.35, 0)
	tween(panel, M.PanelSlideTime, { Position = panelPos }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0.1)
	gui.CashPill.Position = pillPos - UDim2.fromScale(0, 0.15)
	tween(gui.CashPill, M.PanelSlideTime, { Position = pillPos }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0.05)
	gui.CloseButton.Position = closePos + UDim2.fromScale(0, 0.2)
	tween(gui.CloseButton, M.PanelSlideTime, { Position = closePos }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0.25)
end
local function close()
	local list = orderedTiles()
	for i = #list, 1, -1 do
		tween(scaleOf(list[i]), M.CloseTime, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, (#list - i) * M.CloseStagger)
	end
	tween(scaleOf(tree.SelectionGlow), M.CloseTime, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween(panel, M.CloseTime * 1.5, { Position = panelPos - UDim2.fromScale(0.35, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween(gui.Backdrop, M.OpenFade, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0.1)
	task.delay(0.4, function() if alive then gui.Enabled = false if opener then opener.Enabled = true end end end)
end
hoverPress(gui.CloseButton, M.ButtonHover, M.ButtonPress, close)

opener = Instance.new("ScreenGui")
opener.Name = "_PROTO_SkillTreeOpen" opener.Enabled = false opener.DisplayOrder = 50
local ob = Instance.new("TextButton")
ob.Text = "OPEN SKILL TREE" ob.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy) ob.TextScaled = true
ob.TextColor3 = Color3.new(1, 1, 1) ob.BackgroundColor3 = Color3.fromHex("28A926") ob.AnchorPoint = Vector2.new(1, 1)
ob.Position = UDim2.fromScale(0.98, 0.95) ob.Size = UDim2.fromOffset(240, 56) ob.AutoButtonColor = false
local oc = Instance.new("UICorner") oc.CornerRadius = UDim.new(0.3, 0) oc.Parent = ob
local os2 = Instance.new("UIStroke") os2.ApplyStrokeMode = Enum.ApplyStrokeMode.Border os2.Thickness = 3 os2.Parent = ob
local ot = Instance.new("UIStroke") ot.Thickness = 2 ot.Parent = ob
ob.Parent = opener
hoverPress(ob, M.ButtonHover, M.ButtonPress, open)

-- Démo : argent gagné régulièrement ------------------------------------------------------------
task.spawn(function()
	while alive do
		task.wait(M.IncomeEvery)
		if alive and gui.Enabled then
			floatText(gui, "+" .. money(M.IncomeAmount), Color3.fromHex("7CFF6B"), gui.CashPill.Position + UDim2.fromScale(0, 0.09))
			rollCash(cash + M.IncomeAmount)
			task.delay(M.CashRoll, function() if alive then for name in D do refreshTile(name) end refreshPanel() end end)
		end
	end
end)

_G.SkillTreeProto = {
	Stop = function()
		alive = false
		for _, c in connections do c:Disconnect() end
		gui:Destroy()
		if opener then opener:Destroy() end
		if fillImg then fillImg:Destroy() end
		if glossImg then glossImg:Destroy() end
	end,
	Open = open, Close = close, Select = select, Buy = buy,
	Pan = function(dx, dy) pan = clampPan(pan + Vector2.new(dx, dy), zoom, false) applyView(0) end,
	ZoomAt = function(x, y, z) zoomAt(Vector2.new(x, y), z) end,
	View = function() return zoom, pan end,
	State = function() return { cash = cash, selected = selected, levels = (function() local r = {} for k, v in D do r[k] = v.lv end return r end)() } end,
	Values = M,
}

refreshAll()
gui.Parent = CoreGui
opener.Parent = CoreGui
open()
return "Prototype lancé : CoreGui._PROTO_SkillTree"
