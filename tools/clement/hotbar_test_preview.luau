--[[
	Aperçu en Edit de la barre de test StarterGui/UI_Hotbar (2026-11-11, demande de Clément).
	Copie remplie dans CoreGui/_PROTO_Hotbar : rien n'est changé dans StarterGui, aucun script laissé.
	- Cases : pied-de-biche, batte (équipée), colis Premium, Giant TV, Golden Graphics Card, Rubber Duck.
	- Survol : l'icône grossit (× 1,12) et penche (−6°), contour blanc HoverOutline.
	- Appui : case × 0,95 (Press), relâché en 0,2 (Release). Clic : la case s'équipe (Equipped vert) et
	  saute (Success × 1,22 → 1 en 0,28). Pas de son en Edit (Studio ne les joue pas).
	Arrêt : _G.HotbarProto.Stop().
]]

local CG = game:GetService("CoreGui")
local TS = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")

if _G.HotbarProto then pcall(_G.HotbarProto.Stop) end
local old = CG:FindFirstChild("_PROTO_Hotbar")
if old then old:Destroy() end

local conns = {}
local function on(sig, f) table.insert(conns, sig:Connect(f)) end
local function tween(o, t, props, style)
	local tw = TS:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local function scaleOf(o)
	local s = o:FindFirstChild("ProtoScale")
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

local Shared = RS.Shared
local Items = require(Shared.Config.Items)
local Rarities = require(Shared.Config.Rarities)
local Formulas = require(Shared.Config.Formulas)
local ICONS = RS.Assets:FindFirstChild("Icons")
local function icon(name)
	local d = ICONS and ICONS:FindFirstChild(name, true)
	return d and d.Texture or ""
end
local itemById = {}
for _, it in Items.List do itemById[it.Id] = it end

local g = game.StarterGui.UI_Hotbar:Clone()
g.Name = "_PROTO_Hotbar"
g.Enabled = true
g.DisplayOrder = 20
g.Parent = CG
local bar = g.Bar
local template = bar.Template

local content = {
	{ name = "Crowbar", icon = icon("ICON_TOOL_Crowbar") },
	{ name = "Bat", icon = icon("ICON_TOOL_Bat"), equipped = true },
	{ name = "Premium Box", icon = icon("ICON_BOX_Premium"), rarity = "Rare" },
	{ item = "Z3_TeleGeante" },
	{ item = "Z3_CarteGraphiqueEnOr" },
	{ item = "Z2_CanardEnPlastique" },
}

local slots = {}
local function setEquipped(target)
	for _, s in slots do
		s.Equipped.Visible = (s == target) and not s:GetAttribute("WasEquipped")
		s:SetAttribute("WasEquipped", s.Equipped.Visible)
	end
end

for i, c in content do
	local s = template:Clone()
	s.Name = "Slot" .. i
	s.LayoutOrder = i
	s.Visible = true
	s.KeyLabel.Text = tostring(i)
	local rarityId = c.rarity
	local income
	if c.item then
		local it = itemById[c.item]
		s.ItemName.Text = it and it.Name or c.item
		s.Icon.Image = icon("ICON_" .. c.item)
		rarityId = it and it.Rarity
		local ok, v = pcall(Formulas.ItemIncome, tonumber(c.item:match("^Z(%d)")) or 1, rarityId)
		income = ok and v or nil
	else
		s.ItemName.Text = c.name
		s.Icon.Image = c.icon
	end
	s.Income.Visible = income ~= nil
	s.Income.Text = income and ("$" .. money(income) .. "/s") or ""
	local r = rarityId and Rarities.ById[rarityId]
	if r then
		s.Clip.BackgroundColor3 = r.Color:Lerp(Color3.new(0, 0, 0), 0.45)
		s.Clip.Glow.ImageColor3 = r.Color
	end
	s.Equipped.Visible = c.equipped == true
	s:SetAttribute("WasEquipped", c.equipped == true)
	s.Parent = bar
	table.insert(slots, s)

	-- survol (HoverCard), appui (Press / Release), clic (équiper + Success)
	local ic, outline = s.Icon, s.HoverOutline
	local basePos, baseRot = ic.Position, ic.Rotation
	local over = false
	on(s.MouseEnter, function()
		over = true
		outline.Visible = true
		tween(scaleOf(ic), 0.1, { Scale = 1.12 }, Enum.EasingStyle.Back)
		tween(ic, 0.1, { Rotation = baseRot - 6, Position = basePos + UDim2.fromScale(0.02, -0.03) }, Enum.EasingStyle.Back)
	end)
	on(s.MouseLeave, function()
		over = false
		outline.Visible = false
		tween(scaleOf(ic), 0.12, { Scale = 1 })
		tween(ic, 0.12, { Rotation = baseRot, Position = basePos })
		tween(scaleOf(s), 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	on(s.MouseButton1Down, function() tween(scaleOf(s), 0.05, { Scale = 0.95 }) end)
	on(s.MouseButton1Up, function() tween(scaleOf(s), 0.2, { Scale = 1 }, Enum.EasingStyle.Back) end)
	on(s.Activated, function()
		setEquipped(s)
		local sc = scaleOf(s)
		sc.Scale = 1.22
		tween(sc, 0.28, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
end

_G.HotbarProto = {
	Stop = function()
		for _, c in conns do c:Disconnect() end
		if g.Parent then g:Destroy() end
		_G.HotbarProto = nil
	end,
}

task.wait(0.2)
local first = slots[1]
local vp = workspace.CurrentCamera.ViewportSize
local overflow = {}
for _, s in slots do
	for _, t in { s.ItemName, s.Income, s.KeyLabel } do
		if t.Visible and t.Text ~= "" and not t.TextFits then table.insert(overflow, s.Name .. "." .. t.Name) end
	end
	if s.Icon.Image == "" then table.insert(overflow, s.Name .. " sans icône") end
end
return string.format("vue %dx%d ; barre x %d..%d, y %d..%d ; case %dx%d ; problèmes : %s",
	vp.X, vp.Y, bar.AbsolutePosition.X, bar.AbsolutePosition.X + bar.AbsoluteSize.X, bar.AbsolutePosition.Y, bar.AbsolutePosition.Y + bar.AbsoluteSize.Y,
	first.AbsoluteSize.X, first.AbsoluteSize.Y, #overflow > 0 and table.concat(overflow, ", ") or "aucun")
