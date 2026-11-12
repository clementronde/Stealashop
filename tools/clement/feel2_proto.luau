--[[
	Prototype en Play, côté client (execute_luau « Client »), d'après la vidéo de Clément du
	2026-11-10 (20h03). Il travaille sur des copies (_PROTO_Feel2_*) : rien n'est gardé à l'arrêt.
	- Argent hors ligne : UI_Offline au lancement (montant lu dans le message « while you were away »
	  s'il est encore affiché, sinon un exemple). Claim : les billets volent vers l'argent du HUD,
	  « +$X » vert à côté. ×2 : même chose, montant doublé (aperçu, pas d'achat).
	- Messages en bas : UI_Toast, texte vert pour une réussite (objet équipé, colis en sécurité…).
	- Barre du bas : UI_Hotbar remplace la barre Roblox. Survol : l'icône grossit et penche, contour
	  blanc. $/s au-dessus de chaque objet. Case équipée en vert. Touches 1 à 9, clic ou appui.
	- Inventaire (touche I ou bouton Inventaire du HUD) : UI_Inventory rempli avec tes vrais objets
	  et colis, $/s calculé par Formulas.ItemIncome.
	- Vitre cassée (chrono UI_HUD.HeistTimer affiché, ou touche B) : musique de tension MUS_Heist et
	  respiration discrète Heist_Breath, la musique de zone se tait.
	- Poursuite (UI_Chase allumé par le code, ou touche G pour simuler) : Heist_Grab, sifflet, sirène
	  Chase_Siren en boucle (MUS_Chase joue par MusicController), bulle BB_GuardShout au-dessus du
	  vigile (« ! » puis « STOP RIGHT THERE! »…), UI_Chase animé (ScreenEdges et bandeau qui battent,
	  bouton rouge RunBanner « RUN! » en haut au centre qui surgit puis bat), FX_ChaseHighlight sur le
	  vigile, caméra +6, barre de gauche et barre du bas cachées.
	- Zone safe avec un colis (ou touche H) : flash doré, zoom de caméra, Heist_SafeFlash puis
	  Heist_Escape, FX_Escape, bannière UI_Escape, Celebrate, message vert.
	Arrêt : _G.Feel2.Stop().
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
local GuiService = game:GetService("GuiService")

if _G.Feel2 then pcall(_G.Feel2.Stop) end

local lp = Players.LocalPlayer
local PG = lp:WaitForChild("PlayerGui")
local Assets = RS:WaitForChild("Assets")
local SOUNDS = Assets.Sounds
local ICONS = Assets.Icons
local Config = RS.Shared.Config
local Items = require(Config.Items)
local Rarities = require(Config.Rarities)
local Formulas = require(Config.Formulas)
local GREEN, WHITE = Color3.fromHex("5dff3a"), Color3.new(1, 1, 1)
local LINES = { "STOP RIGHT THERE!", "COME HERE!", "STOP NOW!", "FREEZE!", "THIEF!", "GIVE IT BACK!" }

local rar, itemById = {}, {}
for _, r in Rarities.List or Rarities do
	if type(r) == "table" and r.Id then rar[r.Id] = r end
end
for _, it in Items.List do itemById[it.Id] = it end

local conns, made, restoreVis = {}, {}, {}
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
local function scaleOf(o)
	local s = o:FindFirstChildOfClass("UIScale")
	if not s then
		s = Instance.new("UIScale")
		s.Name = "ProtoScale"
		s.Parent = o
	end
	return s
end
local function money(n)
	for _, s in { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
		if n >= s[1] then return (string.format("%.1f", n / s[1]):gsub("%.0$", "")) .. s[2] end
	end
	return tostring(math.floor(n + 0.5))
end
local function copy(name, order)
	local g = SG:FindFirstChild(name)
	if not g then return nil end
	g = g:Clone()
	g.Name = "_PROTO_Feel2_" .. name
	g.ResetOnSpawn = false
	g.DisplayOrder = order
	g.Parent = PG
	table.insert(made, g)
	return g
end

-- sons -----------------------------------------------------------------------------------------------
local sfx = Instance.new("Folder")
sfx.Name = "_PROTO_Feel2_Sounds"
sfx.Parent = SoundService
local snd = {}
local function sound(name)
	if snd[name] == nil then
		local src = SOUNDS:FindFirstChild(name, true)
		snd[name] = src and src:Clone() or false
		if snd[name] then snd[name].Parent = sfx end
	end
	return snd[name] or nil
end
local function play(name)
	local s = sound(name)
	if s then SoundService:PlayLocalSound(s) end
end
local function startLoop(name, startAt)
	local src = SOUNDS:FindFirstChild(name, true)
	if not src then return nil end
	local s = src:Clone()
	s.Looped = true
	s.Parent = sfx
	s.TimePosition = startAt or 0
	s:Play()
	return s
end
local function stopLoop(s)
	if not s then return end
	tween(s, 0.5, { Volume = 0 })
	task.delay(0.5, function() s:Destroy() end)
end
do
	local list = {}
	for _, n in { "UI_Hover", "UI_Click_Classic", "UI_Open", "UI_Close", "UI_Equip", "Offline_Claim", "Cash_Collect", "Heist_Grab", "Chase_Whistle", "Guard_Radio", "Heist_SafeFlash", "Heist_Escape" } do
		local s = sound(n)
		if s then table.insert(list, s) end
	end
	CP:PreloadAsync(list)
end
-- musique : la vraie (MusicController, MUS_*) reste allumée ; la tension MUS_Heist joue dès que le
-- chrono du braquage s'affiche (vitre cassée), la musique de zone se tait pendant ce temps
local MUSIC = Assets:FindFirstChild("Music")
local NORMAL_MUSIC = 0.8
lp:SetAttribute("MusicVolume", NORMAL_MUSIC)
local tension, tensionFake, breath = nil, false, nil
local fakeGui = nil
local function startTension()
	if tension or not MUSIC then return end
	local src = MUSIC:FindFirstChild("MUS_Heist")
	if not src then return end
	tension = src:Clone()
	tension.Parent = sfx
	local v = tension.Volume
	tension.Volume = 0
	tension:Play()
	tween(tension, 0.6, { Volume = v })
	lp:SetAttribute("MusicVolume", 0)
	breath = startLoop("Heist_Breath") -- respiration discrète sous la tension
end
local function stopTension(keepTimer)
	if not tension then return end
	stopLoop(tension)
	stopLoop(breath)
	tension, breath = nil, nil
	tensionFake = false
	if fakeGui and not keepTimer then fakeGui:Destroy(); fakeGui = nil end
	lp:SetAttribute("MusicVolume", NORMAL_MUSIC)
end

-- boutons et cartes ----------------------------------------------------------------------------------
local function wire(btn, onClick)
	local s = scaleOf(btn)
	local sh = btn:FindFirstChild("Shade")
	local over = false
	on(btn.MouseEnter, function()
		over = true
		play("UI_Hover")
		tween(s, 0.08, { Scale = 1.06 })
		if sh then tween(sh, 0.08, { BackgroundTransparency = 0.78 }) end
	end)
	on(btn.MouseLeave, function()
		over = false
		tween(s, 0.08, { Scale = 1 })
		if sh then tween(sh, 0.08, { BackgroundTransparency = 1 }) end
	end)
	on(btn.MouseButton1Down, function()
		tween(s, 0.05, { Scale = 0.95 })
		if sh then tween(sh, 0.05, { BackgroundTransparency = 0.62 }) end
	end)
	on(btn.MouseButton1Up, function()
		tween(s, 0.2, { Scale = over and 1.06 or 1 }, Enum.EasingStyle.Back)
		if sh then tween(sh, 0.2, { BackgroundTransparency = over and 0.78 or 1 }) end
	end)
	on(btn.Activated, function()
		play("UI_Click_Classic")
		if onClick then onClick() end
	end)
end
local function hoverIcon(card, onClick)
	local icon = card:FindFirstChild("Icon")
	local outline = card:FindFirstChild("HoverOutline")
	if not icon then return end
	local basePos, baseRot = icon.Position, icon.Rotation
	on(card.MouseEnter, function()
		play("UI_Hover")
		if outline then outline.Visible = true end
		tween(scaleOf(icon), 0.1, { Scale = 1.12 }, Enum.EasingStyle.Back)
		tween(icon, 0.1, { Rotation = baseRot - 6, Position = basePos + UDim2.fromScale(0.02, -0.03) }, Enum.EasingStyle.Back)
	end)
	on(card.MouseLeave, function()
		if outline then outline.Visible = false end
		tween(scaleOf(icon), 0.12, { Scale = 1 })
		tween(icon, 0.12, { Rotation = baseRot, Position = basePos })
	end)
	if onClick and card:IsA("GuiButton") then on(card.Activated, onClick) end
end

-- messages en bas --------------------------------------------------------------------------------------
local toastGui = copy("UI_Toast", 70)
local toastN = 0
local function toast(text, color)
	if not toastGui then return end
	toastGui.Enabled = true
	local stack = toastGui.Stack
	toastN += 1
	local t = stack.Template:Clone()
	t.Name = "Toast"
	t.LayoutOrder = toastN
	t.Text = text
	t.TextColor3 = color or GREEN
	t.Visible = true
	t.Parent = stack
	local list = {}
	for _, c in stack:GetChildren() do
		if c.Name == "Toast" then table.insert(list, c) end
	end
	table.sort(list, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	while #list > 3 do table.remove(list, 1):Destroy() end
	local s = scaleOf(t)
	s.Scale = 0.6
	tween(s, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(2.4, function()
		if not t.Parent then return end
		tween(t, 0.25, { TextTransparency = 1 })
		local st = t:FindFirstChildOfClass("UIStroke")
		if st then tween(st, 0.25, { Transparency = 1 }) end
		task.delay(0.26, function() t:Destroy() end)
	end)
end

-- outils et objets -------------------------------------------------------------------------------------
local function iconFor(tool)
	if tool.TextureId ~= "" then return tool.TextureId end
	local id = tool:GetAttribute("ToolId") or (tool:GetAttribute("BatTool") and "Bat")
	local d = id and ICONS:FindFirstChild("ICON_TOOL_" .. id)
	if not d and tool:GetAttribute("Tier") then d = ICONS:FindFirstChild("ICON_BOX_" .. tool:GetAttribute("Tier")) end
	return d and d.Texture or ""
end
local function incomeOf(tool)
	local id = tool:GetAttribute("ItemId")
	local it = id and itemById[id]
	if not it then return nil end
	local ok, v = pcall(Formulas.ItemIncome, it.Zone or 6, it.Rarity)
	return ok and v or nil
end
local function rarityColor(tool)
	local r = rar[tool:GetAttribute("Rarity") or ""]
	return r and r.Color or nil, r
end
local order, nextOrder = {}, 0
local function toolsList()
	local list = {}
	for _, t in lp.Backpack:GetChildren() do
		if t:IsA("Tool") then table.insert(list, t) end
	end
	local char = lp.Character
	if char then
		for _, t in char:GetChildren() do
			if t:IsA("Tool") then table.insert(list, t) end
		end
	end
	for _, t in list do
		if not order[t] then
			nextOrder += 1
			order[t] = nextOrder
		end
	end
	table.sort(list, function(a, b) return order[a] < order[b] end)
	return list
end

-- barre du bas -------------------------------------------------------------------------------------------
pcall(function() SG:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)
local hb = copy("UI_Hotbar", 6)
local slotTools = {}
local function toggleEquip(tool)
	local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
	if not (hum and tool) then return end
	if tool.Parent == lp.Character then hum:UnequipTools() else hum:EquipTool(tool) end
end
local rebuildQueued = false
local function rebuild()
	rebuildQueued = false
	if not hb then return end
	for _, c in hb.Bar:GetChildren() do
		if c.Name:match("^Slot") then c:Destroy() end
	end
	table.clear(slotTools)
	for i, tool in toolsList() do
		if i > 9 then break end
		local s = hb.Bar.Template:Clone()
		s.Name = "Slot" .. i
		s.LayoutOrder = i
		s.Visible = true
		s.KeyLabel.Text = tostring(i)
		s.ItemName.Text = tool.Name
		s.Icon.Image = iconFor(tool)
		local inc = incomeOf(tool)
		s.Income.Visible = inc ~= nil
		s.Income.Text = inc and ("$" .. money(inc) .. "/s") or ""
		local col = rarityColor(tool)
		if col then
			s.Clip.BackgroundColor3 = col:Lerp(Color3.new(0, 0, 0), 0.45)
			s.Clip.Glow.ImageColor3 = col
		end
		s.Equipped.Visible = tool.Parent == lp.Character
		s.Parent = hb.Bar
		slotTools[i] = tool
		hoverIcon(s, function()
			play("UI_Click_Classic")
			toggleEquip(tool)
		end)
	end
	hb.Enabled = true
end
local function queueRebuild()
	if rebuildQueued then return end
	rebuildQueued = true
	task.defer(rebuild)
end
local function watchContainer(c)
	on(c.ChildAdded, function(t)
		if not t:IsA("Tool") then return end
		queueRebuild()
		if c == lp.Character then
			play("UI_Equip")
			toast(t.Name .. " equipped!", GREEN)
		end
	end)
	on(c.ChildRemoved, function(t) if t:IsA("Tool") then queueRebuild() end end)
end
watchContainer(lp.Backpack)
if lp.Character then watchContainer(lp.Character) end
on(lp.CharacterAdded, function(char)
	watchContainer(char)
	task.wait(0.5)
	watchContainer(lp:WaitForChild("Backpack"))
	queueRebuild()
end)
rebuild()

-- inventaire avec les vrais objets ----------------------------------------------------------------------------
local inv, invOpen = nil, false
local function fillInventory()
	if inv then inv:Destroy() end
	inv = copy("UI_Inventory", 62)
	if not inv then return end
	local items, boxes = {}, {}
	for _, t in toolsList() do
		local kind = t:GetAttribute("InventoryKind")
		if kind == "Item" then table.insert(items, t) elseif kind == "Box" then table.insert(boxes, t) end
	end
	local itemsSec = inv:FindFirstChild("ItemsSection", true)
	local boxSec = inv:FindFirstChild("BoxesSection", true)
	for i, t in items do
		local c = itemsSec.Cards.Template:Clone()
		c.Name = "Card" .. i
		c.LayoutOrder = i
		c.Visible = true
		c.Icon.Image = iconFor(t)
		c.ItemName.Text = string.upper(t.Name)
		local inc = incomeOf(t)
		c.Income.Text = inc and ("+$" .. money(inc) .. "/s") or ""
		local col, r = rarityColor(t)
		if col then
			local rb = c:FindFirstChild("RarityBar")
			if rb then
				rb.BackgroundColor3 = col
				local lbl = rb:FindFirstChildWhichIsA("TextLabel")
				if lbl and r then lbl.Text = r.DisplayNameUpper or r.DisplayName end
			end
			for _, n in { "Rays", "Glow" } do
				local o = c:FindFirstChild(n, true)
				if o and o:IsA("ImageLabel") then o.ImageColor3 = col end
			end
		end
		local mt = c:FindFirstChild("MutationTag")
		if mt then mt.Visible = false end
		c.Parent = itemsSec.Cards
	end
	for i, t in boxes do
		local c = boxSec.Cards.Template:Clone()
		c.Name = "Card" .. i
		c.LayoutOrder = i
		c.Visible = true
		c.Icon.Image = iconFor(t)
		local bn = c:FindFirstChild("BoxName", true)
		if bn then bn.Text = string.upper(t.Name) end
		c.Parent = boxSec.Cards
	end
	local toolSec = inv:FindFirstChild("ToolsSection", true)
	local tools = {}
	for _, t in toolsList() do
		if t:GetAttribute("ToolId") or t:GetAttribute("BatTool") then table.insert(tools, t) end
	end
	if toolSec and toolSec.Cards:FindFirstChild("Template") then
		for i, t in tools do
			local c = toolSec.Cards.Template:Clone()
			c.Name = "Card" .. i
			c.LayoutOrder = i
			c.Visible = true
			c.Icon.Image = iconFor(t)
			local tn = c:FindFirstChild("ToolName", true)
			if tn then tn.Text = string.upper(t.Name) end
			local equipped = t.Parent == lp.Character
			local eb, ep = c:FindFirstChild("EquipButton"), c:FindFirstChild("EquippedPill")
			if eb then eb.Visible = not equipped end
			if ep then ep.Visible = equipped end
			local stat = c:FindFirstChild("ToolStat")
			if stat then stat.Text = t:GetAttribute("BatTool") and "Stuns" or "Breaks glass" end
			c.Parent = toolSec.Cards
		end
	end
	local tabSections = { ItemsTab = "ItemsSection", BoxesTab = "BoxesSection", PotionsTab = "PotionsSection", ToolsTab = "ToolsSection" }
	local function selectTab(name)
		local tabs = inv.Root:FindFirstChild("Tabs")
		if tabs then
			for _, b in tabs:GetChildren() do
				if b:IsA("GuiButton") and b:FindFirstChild("Selected") then b.Selected.Visible = b.Name == name end
			end
		end
		for tab, secName in tabSections do
			local sec = inv:FindFirstChild(secName, true)
			if sec then sec.Visible = tab == name end
		end
		local cards = {}
		local sec = inv:FindFirstChild(tabSections[name], true)
		if sec then
			for _, c in sec.Cards:GetChildren() do
				if c:IsA("GuiObject") and c.Name:match("^Card%d") then table.insert(cards, c) end
			end
		end
		for i, c in cards do
			local cs = scaleOf(c)
			cs.Scale = 0
			task.delay(0.04 + math.min(i, 14) * 0.035, function() tween(cs, 0.14, { Scale = 1 }, Enum.EasingStyle.Back) end)
		end
	end
	inv:SetAttribute("ProtoTabs", true)
	_G.Feel2_selectTab = selectTab
	for _, sec in { { toolSec, #tools } } do
		if sec[1] then
			local cl = sec[1]:FindFirstChild("CountLabel", true)
			if cl then cl.Text = tostring(sec[2]) end
		end
	end
	for _, sec in { { itemsSec, #items }, { boxSec, #boxes } } do
		local cl = sec[1]:FindFirstChild("CountLabel", true)
		if cl then cl.Text = tostring(sec[2]) end
	end
	for _, d in inv:GetDescendants() do
		if d:IsA("GuiObject") and d:FindFirstChild("HoverOutline") and d.Name ~= "Template" then
			hoverIcon(d)
		elseif d:IsA("GuiButton") and not d:FindFirstAncestor("Template") then
			if d.Name == "CloseButton" then
				wire(d, function() _G.Feel2.Inventory() end)
			elseif d.Parent and d.Parent.Name == "Tabs" then
				wire(d, function() _G.Feel2_selectTab(d.Name) end)
			elseif d.Name == "EquipBestButton" then
				wire(d, function()
					-- le vrai Equip Best du jeu (InventoryController.EquipBest, remote EquipBest)
					local ok = pcall(function()
						local ctrl = lp.PlayerScripts:FindFirstChild("InventoryController", true)
						require(ctrl).EquipBest()
					end)
					play("UI_Success")
					toast(ok and "Best items equipped!" or "Equip Best: not available", ok and GREEN or Color3.new(1, 1, 1))
				end)
			else
				wire(d)
			end
		end
	end
end
local function toggleInventory()
	if not invOpen then
		fillInventory()
		if not inv then return end
		invOpen = true
		play("UI_Open")
		inv.Enabled = true
		if _G.Feel2_selectTab then _G.Feel2_selectTab("ItemsTab") end
		local s = scaleOf(inv.Root)
		s.Scale = 0.55
		tween(s, 0.14, { Scale = 1 }, Enum.EasingStyle.Back)
		local cards = {}
		for _, d in inv:GetDescendants() do
			if d:IsA("GuiObject") and d.Name:match("^Card%d") then table.insert(cards, d) end
		end
		for i, c in cards do
			local cs = scaleOf(c)
			cs.Scale = 0
			task.delay(0.08 + math.min(i, 14) * 0.035, function() tween(cs, 0.14, { Scale = 1 }, Enum.EasingStyle.Back) end)
		end
	else
		invOpen = false
		play("UI_Close")
		local s = scaleOf(inv.Root)
		tween(s, 0.09, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.09, function() if not invOpen and inv then inv.Enabled = false end end)
	end
end
do
	local hud = PG:FindFirstChild("UI_HUD")
	local btn = hud and hud:FindFirstChild("InventoryButton", true)
	if btn then
		restoreVis[btn] = btn.Visible
		btn.Visible = true
		on(btn.Activated, toggleInventory)
	end
end

-- boutons du HUD : son au survol et au clic, Shade assombri (le code les fait déjà grossir) ----------------
do
	local hud = PG:FindFirstChild("UI_HUD")
	if hud then
		for _, b in hud:GetDescendants() do
			if b:IsA("GuiButton") then
				local sh = b:FindFirstChild("Shade")
				on(b.MouseEnter, function()
					play("UI_Hover")
					if sh then tween(sh, 0.08, { BackgroundTransparency = 0.78 }) end
				end)
				on(b.MouseLeave, function() if sh then tween(sh, 0.08, { BackgroundTransparency = 1 }) end end)
				on(b.Activated, function() play("UI_Click_Classic") end)
			end
		end
	end
end

-- argent hors ligne -------------------------------------------------------------------------------------------
local function cashLabel()
	local hud = PG:FindFirstChild("UI_HUD")
	if not hud then return nil, hud end
	local best
	for _, d in hud:GetDescendants() do
		if d:IsA("TextLabel") and d.Visible and d.Text:match("^%$") and d.AbsolutePosition.X < workspace.CurrentCamera.ViewportSize.X / 2 then
			if not best or d.AbsoluteSize.Y > best.AbsoluteSize.Y then best = d end
		end
	end
	return best, hud
end
local function gainPop(text)
	if not toastGui then return end
	local lbl, hud = cashLabel()
	local t = toastGui.Stack.Template:Clone()
	t.Name = "GainPop"
	t.Text = "+" .. text
	t.Visible = true
	t.Size = UDim2.fromOffset(240, 40)
	t.AnchorPoint = Vector2.new(0, 0.5)
	local inset = (hud and not hud.IgnoreGuiInset) and GuiService:GetGuiInset().Y or 0
	local pos = lbl and Vector2.new(lbl.AbsolutePosition.X + lbl.TextBounds.X + 14, lbl.AbsolutePosition.Y + inset + lbl.AbsoluteSize.Y / 2) or Vector2.new(260, workspace.CurrentCamera.ViewportSize.Y - 40)
	t.Position = UDim2.fromOffset(pos.X, pos.Y)
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Parent = toastGui
	local s = scaleOf(t)
	s.Scale = 0.4
	tween(s, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(1.6, function()
		tween(t, 0.4, { TextTransparency = 1, Position = t.Position - UDim2.fromOffset(0, 24) })
		task.delay(0.42, function() t:Destroy() end)
	end)
end
local function doubleText(text)
	local num, suf = text:match("%$([%d%.,]+)(%a?)")
	local n = tonumber((num or "0"):gsub(",", "")) or 0
	local mult = ({ K = 1e3, M = 1e6, B = 1e9, T = 1e12 })[suf] or 1
	return "$" .. money(n * mult * 2)
end
-- gains au-dessus du joueur (BB_Gain) : vitesse au tapis, force au banc, argent ramassé ---------------
local GAIN = {
	Speed = { "rbxassetid://80577187405028", Color3.fromHex("4fd2ff"), "Speed" },
	Strength = { "rbxassetid://84783828444327", Color3.fromHex("ff7a3a"), "Power" },
	Cash = { "rbxassetid://138179722277427", Color3.fromHex("5cff4a"), nil },
}
local function short(n)
	if n >= 1000 then return money(n) end
	local t = string.format("%.1f", n):gsub("%.0$", "")
	return t
end
local function floatGain(kind, amount)
	local def = GAIN[kind]
	local src = Assets.UI:FindFirstChild("BB_Gain")
	local head = lp.Character and lp.Character:FindFirstChild("Head")
	if not (def and src and head) then return end
	local bb = src:Clone()
	bb.Adornee = head
	bb.Row.Icon.Image = def[1]
	bb.Row.Amount.TextColor3 = def[2]
	bb.Row.Amount.Text = kind == "Cash" and ("+$" .. short(amount)) or ("+" .. short(amount) .. " " .. def[3] .. (kind == "Speed" and "/s" or ""))
	local x = (math.random() - 0.5) * 2
	bb.StudsOffset = Vector3.new(x, 3.2, 0)
	bb.Parent = PG
	local s = scaleOf(bb.Row)
	s.Scale = 0.4
	tween(s, 0.16, { Scale = 1 }, Enum.EasingStyle.Back)
	local v = Instance.new("NumberValue")
	v.Value = 0
	v.Changed:Connect(function(a)
		bb.StudsOffset = Vector3.new(x, 3.2 + 2.2 * a, 0)
		local fade = math.clamp((a - 0.55) / 0.45, 0, 1)
		bb.Row.Amount.TextTransparency = fade
		bb.Row.Icon.ImageTransparency = fade
		local st = bb.Row.Amount:FindFirstChildOfClass("UIStroke")
		if st then st.Transparency = fade end
	end)
	tween(v, 1, { Value = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	task.delay(1.05, function() bb:Destroy(); v:Destroy() end)
end
-- la case qui vole vers l'argent en bas à gauche (UI_HUD.CashFly.Template), puis « +$X » à côté
local gainGui = nil
do
	local hud = PG:FindFirstChild("UI_HUD")
	local fly = hud and hud:FindFirstChild("CashFly")
	if fly then
		gainGui = Instance.new("ScreenGui")
		gainGui.Name = "_PROTO_Feel2_CashFly"
		gainGui.IgnoreGuiInset = true
		gainGui.DisplayOrder = 66
		gainGui.ResetOnSpawn = false
		gainGui.Parent = PG
		table.insert(made, gainGui)
		fly.Template:Clone().Parent = gainGui
	end
end
local function flyGain(text, fromPos)
	if not gainGui then return end
	local fl = gainGui.Template:Clone()
	fl.Name = "Fly"
	fl.FlyerAmount.Text = text
	fl.Position = fromPos or UDim2.fromScale(0.5, 0.6)
	fl.Visible = true
	fl.Parent = gainGui
	local fs = scaleOf(fl)
	fs.Scale = 0
	tween(fs, 0.22, { Scale = 1.1 }, Enum.EasingStyle.Back)
	task.delay(0.45, function()
		local lbl, hud = cashLabel()
		local inset = (hud and not hud.IgnoreGuiInset) and GuiService:GetGuiInset().Y or 0
		local target = lbl and UDim2.fromOffset(lbl.AbsolutePosition.X + 20, lbl.AbsolutePosition.Y + inset + lbl.AbsoluteSize.Y / 2) or UDim2.fromScale(0.08, 0.94)
		tween(fl, 0.4, { Position = target }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween(fs, 0.4, { Scale = 0.3 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.4, function()
			fl:Destroy()
			play("Cash_Collect")
			gainPop(text)
		end)
	end)
end
do
	local last = { Speed = lp:GetAttribute("Speed"), Strength = lp:GetAttribute("Strength"), CashCollected = lp:GetAttribute("CashCollected") }
	for name in last do
		on(lp:GetAttributeChangedSignal(name), function()
			local now = lp:GetAttribute(name)
			local before = last[name]
			last[name] = now
			if type(now) ~= "number" or type(before) ~= "number" or now <= before then return end
			if name == "CashCollected" then
				floatGain("Cash", now - before)
				flyGain("$" .. short(now - before), UDim2.fromScale(0.5, 0.5))
			else
				floatGain(name, now - before)
			end
		end)
	end
end

local function showOffline(amountText)
	local gui = copy("UI_Offline", 63)
	if not gui then return end
	local win = gui.Root.Window
	win.Amount.Text = amountText
	gui.Enabled = true
	play("UI_Open")
	local rs = scaleOf(gui.Root)
	rs.Scale = 0.55
	tween(rs, 0.14, { Scale = 1 }, Enum.EasingStyle.Back)
	for i, n in { "EarnedLabel", "CashIcon", "Amount", "ClaimButton", "DoubleButton" } do
		local o = win:FindFirstChild(n)
		if o then
			local s = scaleOf(o)
			s.Scale = 0
			task.delay(0.08 + i * 0.045, function() tween(s, 0.16, { Scale = 1 }, Enum.EasingStyle.Back) end)
		end
	end
	local bob = on(RunService.RenderStepped, function()
		if win.Parent then win.CashIcon.Rotation = -4 + math.sin(os.clock() * 2.2) * 3 end
	end)
	local claimed = false
	local function claim(text)
		if claimed then return end
		claimed = true
		bob:Disconnect()
		play("Offline_Claim")
		tween(rs, 0.09, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.09, function() gui.Root.Visible = false end)
		local fl = gui.Flyer
		fl.FlyerAmount.Text = text
		fl.Visible = true
		local fs = scaleOf(fl)
		fs.Scale = 0
		tween(fs, 0.25, { Scale = 1.15 }, Enum.EasingStyle.Back)
		task.delay(0.25, function() tween(fs, 0.15, { Scale = 1 }) end)
		task.delay(0.8, function()
			local lbl, hud = cashLabel()
			local inset = (hud and not hud.IgnoreGuiInset) and GuiService:GetGuiInset().Y or 0
			local target = lbl and UDim2.fromOffset(lbl.AbsolutePosition.X + 20, lbl.AbsolutePosition.Y + inset + lbl.AbsoluteSize.Y / 2) or UDim2.fromScale(0.08, 0.94)
			tween(fl, 0.42, { Position = target }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tween(fs, 0.42, { Scale = 0.35 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(0.42, function()
				fl.Visible = false
				play("Cash_Collect")
				gainPop(text)
				toast(text .. " collected!", GREEN)
				task.delay(2, function() gui:Destroy() end)
			end)
		end)
	end
	wire(win.ClaimButton, function() claim(amountText) end)
	wire(win.DoubleButton, function()
		local d = doubleText(amountText)
		win.Amount.Text = d
		local s = scaleOf(win.Amount)
		s.Scale = 1.3
		tween(s, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
		task.delay(0.35, function() claim(d) end)
	end)
end
do
	local found
	local notify = PG:FindFirstChild("UI_Notify")
	if notify then
		for _, d in notify:GetDescendants() do
			if d:IsA("TextLabel") and d.Text:find("while you were away") then found = d.Text:match("%$[%d%.,]+%a?") end
		end
	end
	showOffline(found or ("$" .. money((lp:GetAttribute("Income") or 8) * 600)))
end

local chase = { active = false }
-- chrono du braquage en gros bouton (UI_HUD.HeistTimer + son cadre Box) : il bat à chaque seconde,
-- avec un tic, et passe au rouge sous 3 s ; touche B : faux chrono de 10 s avec la tension
local ORANGE = ColorSequence.new(Color3.fromHex("ffc23a"), Color3.fromHex("ff7a00"))
local REDSEQ = ColorSequence.new(Color3.fromHex("ff5a4a"), Color3.fromHex("d3150f"))
local hooked = {}
local function hookTimer(label)
	if hooked[label] then return end
	hooked[label] = true
	on(label:GetPropertyChangedSignal("Text"), function()
		local box = label:FindFirstChild("Box")
		local n = tonumber(label.Text:match("(%d+)"))
		if box then
			local g = box:FindFirstChildOfClass("UIGradient")
			if g then g.Color = (n and n <= 3) and REDSEQ or ORANGE end
			local bs = scaleOf(box)
			bs.Scale = 1.12
			tween(bs, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		end
		if label.Visible then play("UI_Click_Tick") end
	end)
end
-- bas du chrono affiché (vrai ou faux), en pixels absolus ; nil s'il n'y en a pas
local function timerBottom()
	local hud = PG:FindFirstChild("UI_HUD")
	local timer = hud and hud:FindFirstChild("HeistTimer", true)
	if timer and timer:IsA("GuiObject") and timer.Visible then return timer.AbsolutePosition.Y + timer.AbsoluteSize.Y end
	local fake = fakeGui and fakeGui.Parent and fakeGui:FindFirstChildWhichIsA("TextLabel")
	if fake then return fake.AbsolutePosition.Y + fake.AbsoluteSize.Y end
	return nil
end
local function fakeCountdown(seconds)
	local src = SG.UI_HUD:FindFirstChild("HeistTimer", true)
	if not src then return end
	if fakeGui then fakeGui:Destroy() end
	fakeGui = Instance.new("ScreenGui")
	fakeGui.Name = "_PROTO_Feel2_FakeTimer"
	fakeGui.IgnoreGuiInset = SG.UI_HUD.IgnoreGuiInset
	fakeGui.ZIndexBehavior = SG.UI_HUD.ZIndexBehavior
	fakeGui.DisplayOrder = 54
	fakeGui.ResetOnSpawn = false
	fakeGui.Parent = PG
	table.insert(made, fakeGui)
	local lbl = src:Clone()
	lbl.Visible = true
	lbl.Parent = fakeGui
	hookTimer(lbl)
	local mine = fakeGui
	task.spawn(function()
		for n = seconds, 0, -1 do
			if not lbl.Parent then return end
			lbl.Text = "HEIST: " .. n .. "s"
			task.wait(1)
		end
		if mine.Parent then mine:Destroy() end
		if fakeGui == mine then fakeGui = nil end
		if tensionFake and not chase.active then stopTension() end
	end)
end

-- poursuite --------------------------------------------------------------------------------------------------
local function findGuard()
	local f = workspace:FindFirstChild("ActiveGuards")
	if f then
		for _, m in f:GetChildren() do
			if m:IsA("Model") and m:GetAttribute("TargetUserId") == lp.UserId then return m end
		end
	end
	return nil
end
local function nearestGuard()
	local root = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
	-- un vigile s'il y en a un de chargé, sinon le PNJ le plus proche (aperçu de la bulle)
	local best, bd, npc, nd = nil, math.huge, nil, math.huge
	for _, h in workspace:GetDescendants() do
		local m = h:IsA("Humanoid") and h.Parent
		if m and m:IsA("Model") and m.PrimaryPart and root and not Players:GetPlayerFromCharacter(m) then
			local d = (m.PrimaryPart.Position - root.Position).Magnitude
			if m.Name:match("^Guard") then
				if d < bd then best, bd = m, d end
			elseif d < nd then
				npc, nd = m, d
			end
		end
	end
	return best or npc
end
local function shout(bb)
	if not bb.Parent then return end
	bb.Bubble.ShoutLabel.Text = LINES[math.random(#LINES)]
	local s = scaleOf(bb.Bubble)
	bb.Tail.Visible = true
	s.Scale = 0
	tween(s, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	if math.random() < 0.5 then play("Guard_Radio") end
	task.delay(1.6, function()
		if not bb.Parent then return end
		tween(s, 0.12, { Scale = 0 })
		task.delay(0.12, function() if bb.Parent then bb.Tail.Visible = false end end)
	end)
end
-- écran de poursuite animé : bords rouges qui battent, gyrophares qui clignotent, « GUARD! RUN! »
-- qui surgit, contour rouge sur le vigile (FX_ChaseHighlight), caméra un peu plus large
local chaseCopy = copy("UI_Chase", 55)
if chaseCopy then chaseCopy.Enabled = false end
local fxConn = nil
local function startChaseFx(guard)
	local real = PG:FindFirstChild("UI_Chase")
	local g = (real and real.Enabled) and real or chaseCopy
	if not g then return end
	if g == chaseCopy then g.Enabled = true end
	-- bouton rouge « RUN! » en haut au centre : il surgit, puis bat avec les bords
	local run = g:FindFirstChild("RunBanner")
	local rs = run and scaleOf(run)
	if rs then
		rs.Scale = 0
		tween(rs, 0.18, { Scale = 1.18 }, Enum.EasingStyle.Back)
		task.delay(0.18, function() tween(rs, 0.12, { Scale = 1 }) end)
	end
	local hlSrc = Assets.FX:FindFirstChild("FX_ChaseHighlight")
	if hlSrc and guard then
		local hl = hlSrc:Clone()
		hl.Adornee = guard
		hl.Parent = guard
		chase.hl = hl
	end
	local cam = workspace.CurrentCamera
	chase.fov = cam.FieldOfView
	tween(cam, 0.3, { FieldOfView = chase.fov + 6 })
	local t0 = os.clock()
	fxConn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local pulse = (math.sin(t * math.pi * 2 * 1.6) + 1) / 2
		local edges = g:FindFirstChild("ScreenEdges")
		if edges then
			for _, f in edges:GetChildren() do
				if f:IsA("Frame") then f.BackgroundTransparency = 0.1 + 0.5 * (1 - pulse) end
			end
		end
		local vg = g:FindFirstChild("Vignette")
		local edge = vg and vg:FindFirstChild("Edge")
		if edge then edge.BackgroundTransparency = 0.3 * (1 - pulse) end
		local redOn = math.floor(t / 0.25) % 2 == 0
		for _, pair in { { g:FindFirstChild("SirenRed", true), redOn }, { g:FindFirstChild("SirenBlue", true), not redOn } } do
			local light = pair[1] and pair[1]:FindFirstChild("Light")
			if light then
				for _, d in light:GetDescendants() do
					if d:IsA("ImageLabel") then
						d.ImageTransparency = pair[2] and 0 or 0.85
					elseif d:IsA("Frame") and d.Name == "Flash" then
						d.BackgroundTransparency = pair[2] and 0.2 or 1
					end
				end
			end
		end
		if run then
			-- sous le chrono s'il est affiché (UI_Chase ignore la barre du haut de Roblox : on l'ajoute)
			local tb = timerBottom()
			run.Position = tb and UDim2.new(0.5, 0, 0, tb + 10 + GuiService:GetGuiInset().Y) or UDim2.fromScale(0.5, 0.035)
		end
		if run and t > 0.3 then
			rs.Scale = 1 + 0.05 * pulse
			run.Rotation = math.sin(t * 14) * 1.5
		end
	end)
end
local function stopChaseFx(instant)
	if fxConn then fxConn:Disconnect(); fxConn = nil end
	if chase.hl then chase.hl:Destroy(); chase.hl = nil end
	if chase.fov then
		if instant then workspace.CurrentCamera.FieldOfView = chase.fov else tween(workspace.CurrentCamera, 0.4, { FieldOfView = chase.fov }) end
		chase.fov = nil
	end
	if chaseCopy then chaseCopy.Enabled = false end
end
local function startChase(guard)
	if chase.active then return end
	chase.active = true
	stopTension(true) -- le chrono reste affiché : RUN! se place dessous
	play("Heist_Grab")
	task.delay(0.15, function() play("Chase_Whistle") end)
	chase.siren = startLoop("Chase_Siren")
	local hud = PG:FindFirstChild("UI_HUD")
	local rail = hud and hud:FindFirstChild("LeftRail", true)
	if rail then
		chase.rail = rail
		chase.railVis = rail.Visible
		rail.Visible = false
	end
	if hb then hb.Enabled = false end
	guard = guard or findGuard()
	startChaseFx(guard)
	local adornee = guard and (guard:FindFirstChild("Head") or guard.PrimaryPart)
	if adornee then
		local bb = Assets.UI.BB_GuardShout:Clone()
		bb.Adornee = adornee
		bb.Parent = PG
		chase.bb = bb
		scaleOf(bb.Bubble).Scale = 0
		bb.Tail.Visible = false
		local bs = scaleOf(bb.Bang)
		bs.Scale = 0
		tween(bs, 0.15, { Scale = 1.35 }, Enum.EasingStyle.Back)
		task.delay(0.15, function() tween(bs, 0.15, { Scale = 1 }) end)
		for i, r in { 14, -12, 8, -5, 0 } do
			task.delay(0.1 + i * 0.07, function() if bb.Parent then bb.Bang.Rotation = r end end)
		end
		task.spawn(function()
			task.wait(0.6)
			while chase.active and bb.Parent do
				shout(bb)
				task.wait(2.4)
			end
		end)
	end
end
local function endChase()
	if not chase.active then return end
	chase.active = false
	stopChaseFx(chase.instantEnd)
	chase.instantEnd = nil
	stopLoop(chase.siren)
	if chase.bb then chase.bb:Destroy() end
	if chase.rail then chase.rail.Visible = chase.railVis end
	if hb then hb.Enabled = true end
	chase.fake = nil
	if chase.fakeMusic then
		stopLoop(chase.fakeMusic)
		chase.fakeMusic = nil
		lp:SetAttribute("MusicVolume", NORMAL_MUSIC)
	end
end
-- poursuite simulée (touche G) : le jeu ne lance pas MUS_Chase sans vrai vigile, on la joue ici
local function fakeChase()
	startChase(nearestGuard())
	chase.fake = true
	local src = MUSIC and MUSIC:FindFirstChild("MUS_Chase")
	if src then
		local m = src:Clone()
		m.Looped = true
		m.Parent = sfx
		m:Play()
		chase.fakeMusic = m
		lp:SetAttribute("MusicVolume", 0)
	end
end

-- zone safe -----------------------------------------------------------------------------------------------------
local escGui = copy("UI_Escape", 64)
local escToken, lastEscape = nil, 0
local function escape()
	if os.clock() - lastEscape < 1.5 then return end
	lastEscape = os.clock()
	chase.instantEnd = true
	endChase()
	stopTension()
	if fakeGui then fakeGui:Destroy(); fakeGui = nil end
	local char = lp.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	play("Heist_SafeFlash")
	task.delay(0.12, function() play("Heist_Escape") end)
	local cam = workspace.CurrentCamera
	local base = cam.FieldOfView
	local v = Instance.new("NumberValue")
	v.Value = base
	local c = v.Changed:Connect(function(x) cam.FieldOfView = x end)
	tween(v, 0.08, { Value = base + 12 })
	task.delay(0.08, function() tween(v, 0.45, { Value = base }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end)
	task.delay(0.6, function() c:Disconnect(); cam.FieldOfView = base; v:Destroy() end)
	if escGui then
		local token = {}
		escToken = token
		escGui.Enabled = true
		local fl = escGui:FindFirstChild("Flash")
		if fl then
			fl.BackgroundTransparency = 0.05
			tween(fl, 0.5, { BackgroundTransparency = 1 })
		end
		local b = escGui.Banner
		local bs = scaleOf(b)
		bs.Scale = 0
		task.delay(0.1, function() tween(bs, 0.35, { Scale = 1 }, Enum.EasingStyle.Back) end)
		b.Title.Rotation = -14
		tween(b.Title, 0.45, { Rotation = -3 }, Enum.EasingStyle.Back)
		for i, n in { "BoxIcon", "Subtitle" } do
			local o = b:FindFirstChild(n)
			if o then
				local s = scaleOf(o)
				s.Scale = 0
				task.delay(0.16 + i * 0.07, function() tween(s, 0.25, { Scale = 1 }, Enum.EasingStyle.Back) end)
			end
		end
		task.delay(2.3, function()
			if escToken ~= token then return end
			tween(bs, 0.15, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(0.15, function() if escToken == token then escGui.Enabled = false end end)
		end)
	end
	local fxSrc = Assets:FindFirstChild("FX") and Assets.FX:FindFirstChild("FX_Escape")
	if fxSrc and root then
		local fx = fxSrc:Clone()
		fx:PivotTo(CFrame.new(root.Position - Vector3.new(0, (hum and hum.HipHeight or 2) + root.Size.Y / 2, 0)))
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
	local anims = Assets:FindFirstChild("Animations")
	local anim = anims and anims:FindFirstChild("Player") and anims.Player:FindFirstChild("Celebrate")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if anim and animator then animator:LoadAnimation(anim):Play() end
	task.delay(0.4, function() toast("Box secured! Open it in your shop.", GREEN) end)
end
on(RunService.RenderStepped, function(dt)
	if escGui and escGui.Enabled then
		local b = escGui.Banner
		if b:FindFirstChild("Rays") then b.Rays.Rotation += dt * 40 end
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
local wasSafe, wasCarrying, nextCheck = nil, lp:GetAttribute("Carrying") ~= nil, 0
on(RunService.Heartbeat, function()
	if os.clock() < nextCheck then return end
	nextCheck = os.clock() + 0.1
	local root = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local safe = inSafe(root.Position)
	local carrying = lp:GetAttribute("Carrying") ~= nil
	if (wasSafe == false and safe and carrying) or (safe and wasCarrying and not carrying) then escape() end
	wasSafe, wasCarrying = safe, carrying
	-- poursuite : suit l'écran UI_Chase allumé par le code
	local uc = PG:FindFirstChild("UI_Chase")
	if uc and uc.Enabled and not chase.active then
		startChase()
	elseif chase.active and not chase.fake and not (uc and uc.Enabled) then
		endChase()
	end
	-- tension : tant que le chrono du braquage (UI_HUD.HeistTimer) est affiché, hors poursuite
	local hud = PG:FindFirstChild("UI_HUD")
	local timer = hud and hud:FindFirstChild("HeistTimer", true)
	local heist = timer and timer:IsA("GuiObject") and timer.Visible
	if timer and timer:IsA("TextLabel") then hookTimer(timer) end
	if heist and not chase.active and not tension then
		startTension()
	elseif tension and not tensionFake and not heist then
		stopTension()
	end
end)

-- touches --------------------------------------------------------------------------------------------------------
local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine }
on(UIS.InputBegan, function(input, processed)
	if processed then return end
	for i, k in KEYS do
		if input.KeyCode == k and slotTools[i] then
			toggleEquip(slotTools[i])
			return
		end
	end
	if input.KeyCode == Enum.KeyCode.I then
		toggleInventory()
	elseif input.KeyCode == Enum.KeyCode.H then
		escape()
	elseif input.KeyCode == Enum.KeyCode.B then
		if tension then stopTension() else startTension(); tensionFake = true; fakeCountdown(10) end
	elseif input.KeyCode == Enum.KeyCode.G then
		if chase.active then
			endChase()
		else
			fakeChase()
		end
	end
end)

_G.Feel2 = {
	Stop = function()
		endChase()
		stopTension()
		lp:SetAttribute("MusicVolume", NORMAL_MUSIC)
		for _, c in conns do c:Disconnect() end
		table.clear(conns)
		for _, g in made do if g.Parent then g:Destroy() end end
		if inv and inv.Parent then inv:Destroy() end
		for o, vis in restoreVis do o.Visible = vis end
		pcall(function() SG:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true) end)
		sfx:Destroy()
		_G.Feel2 = nil
	end,
	Inventory = toggleInventory,
	Escape = escape,
	Chase = fakeChase,
	Tension = function()
		if tension then stopTension() else startTension(); tensionFake = true; fakeCountdown(10) end
	end,
	EndChase = endChase,
	Toast = toast,
	Offline = showOffline,
}
return "prototype pret : argent hors ligne affiche, barre du bas, I inventaire, G poursuite, H zone safe"
