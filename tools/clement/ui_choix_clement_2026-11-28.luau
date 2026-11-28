-- Choix de Clément du 28/11 (analyse des inspirations, « Oui, tes choix »), partie UI ; chef UI. À lancer en Edit, à relancer
-- sans risque. Sauvegarde de l'avant : ServerStorage/MapBackups/2026-11-28_UI_choix_Clement_avant (Index v3, inventaire,
-- arbre, récompenses, rebirth, HUD, roue). Aucun script dans l'UI ; les noms lus par le code ne changent pas ; les éléments
-- neufs sont facultatifs pour le code (le code les remplit après les lignes de Cantin).

local SG = game:GetService("StarterGui")

-- INDEX : nom de la zone dans la barre « 0/0 », pastilles de mutation plus grosses, liseré de rareté sur la carte -------
local list = SG.UI_Index_v3.Root.Window.ListPanel.List
for _, section in list:GetChildren() do
	local bar = section:FindFirstChild("ZoneBar", true)
	local shade = section:FindFirstChild("NameShade", true)
	if bar and shade and not bar:FindFirstChild("ZoneTitle") then
		local count = bar.ZoneCount
		local title = count:Clone()
		title.Name = "ZoneTitle"
		local a = shade:FindFirstChild("ZoneName") and shade.ZoneName.Text or ""
		local b = shade:FindFirstChild("ZoneTheme") and shade.ZoneTheme.Text or ""
		title.Text = (a ~= "" and b ~= "") and (a .. " · " .. b) or (a ~= "" and a or b)
		title.AnchorPoint = Vector2.new(0, 0.5)
		title.Position = UDim2.fromScale(0.03, 0.5)
		title.Size = UDim2.fromScale(0.5, 0.62)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = Color3.fromHex("ffd43b")
		title.Parent = bar
		count.Position = UDim2.fromScale(0.66, 0.5)
		count.Size = UDim2.fromScale(0.24, 0.72)
		shade.Visible = false
	end
end
local card = list.Template
local function bigPips(c)
	local row = c:FindFirstChild("MutationRow")
	if not row then return end
	row.Size = UDim2.new(0.94, 0, 0.24, 0)
	local pip = row:FindFirstChild("Template")
	if pip then
		pip.Size = UDim2.fromScale(1, 1)
		local ar = pip:FindFirstChildOfClass("UIAspectRatioConstraint") or Instance.new("UIAspectRatioConstraint")
		ar.AspectRatio = 1
		ar.DominantAxis = Enum.DominantAxis.Height
		ar.Parent = pip
	end
end
local function edge(c)
	if c:FindFirstChild("RarityEdge") then return end
	local e = Instance.new("Frame")
	e.Name = "RarityEdge"
	e.BackgroundTransparency = 1
	e.Position = UDim2.fromOffset(2, 2)
	e.Size = UDim2.new(1, -4, card.Clip.Size.Y.Scale, -4)
	e.ZIndex = 6
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Thickness = 2
	s.Color = Color3.fromHex("b4b9c1")
	s.Parent = e
	e.Parent = c
end
bigPips(card); edge(card)
for _, d in list:GetDescendants() do
	if d:IsA("TextButton") and d.Name:match("^Preview_") then bigPips(d); edge(d) end
end

-- INVENTAIRE : 5 cartes par ligne sur PC (1366 et plus), 4 sur téléphone comme avant ------------------------------
SG.UI_Inventory.Root.Window.List.ItemsSection.Cards.UIGridLayout.CellSize = UDim2.new(0.125, 40, 0, 10000)

-- RÉCOMPENSES : bleu Index et or en alternance, pastille or du numéro du jour, cadenas et compte à rebours cachés -----
local streak = SG.UI_Rewards.Root.Window.DailyPage.Streak
local tag = streak.Day1.Today.TodayTag
local BLUE = ColorSequence.new(Color3.fromHex("7ad8ff"), Color3.fromHex("2a80e8"))
local GOLD = ColorSequence.new(Color3.fromHex("ffeb85"), Color3.fromHex("ffa91a"))
local LOCK = "rbxassetid://112359396081383" -- le cadenas du bouton REBIRTH
for i = 1, 7 do
	local d = streak["Day" .. i]
	if i < 7 then
		local gold = i % 2 == 0
		local grad = d:FindFirstChildOfClass("UIGradient")
		if grad then grad.Color = gold and GOLD or BLUE end
		d.Glow.ImageColor3 = Color3.fromHex(gold and "fff3b0" or "bfeaff")
	end
	if not d:FindFirstChild("DayBadge") then
		local b = tag:Clone()
		b.Name = "DayBadge"
		for _, c in b:GetChildren() do
			if c:IsA("TextLabel") or c:IsA("UISizeConstraint") then c:Destroy() end
		end
		b.AnchorPoint = Vector2.new(0.5, 0)
		b.Position = UDim2.fromScale(0.5, d.DayLabel.Position.Y.Scale - 0.01)
		b.Size = UDim2.fromScale(i == 7 and 0.34 or 0.66, d.DayLabel.Size.Y.Scale + 0.02)
		b.ZIndex = 7
		b.Visible = true
		b.Parent = d
		d.DayLabel.Size = UDim2.fromScale(i == 7 and 0.3 or 0.6, d.DayLabel.Size.Y.Scale)
	end
	if not d:FindFirstChild("Lock") then
		local l = Instance.new("ImageLabel")
		l.Name = "Lock"
		l.BackgroundTransparency = 1
		l.Image = LOCK
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(0.5, 0.38)
		l.Size = UDim2.fromScale(0.3, 0.3)
		Instance.new("UIAspectRatioConstraint").Parent = l
		l.ZIndex = 11
		l.Visible = false
		l.Parent = d
		local c = d.RewardName:Clone()
		c.Name = "Countdown"
		c.Text = "12:34:56"
		c.ZIndex = 11
		c.Visible = false
		c.Position = UDim2.fromScale(0.5, 0.55)
		c.Size = UDim2.fromScale(0.86, 0.13)
		c.Parent = d
	end
end

-- réglages vus en capture : pastille plus grande (le texte du jour reste à 11 px au moins), cadenas et compte à rebours
for i = 1, 7 do
	local d = streak["Day" .. i]
	local w = i == 7 and 0.4 or 0.76
	local h = i == 7 and 0.11 or 0.2
	d.DayBadge.Position = UDim2.fromScale(0.5, 0.035)
	d.DayBadge.Size = UDim2.fromScale(w, h)
	d.DayLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	d.DayLabel.Position = UDim2.fromScale(0.5, 0.035 + h / 2)
	d.DayLabel.Size = UDim2.fromScale(w * 0.86, h * 0.74)
	local c = d.DayLabel:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
	c.MinTextSize = 11
	c.MaxTextSize = 100
	c.Parent = d.DayLabel
	d.Countdown.Position = UDim2.fromScale(0.5, 0.51)
	d.Countdown.Size = UDim2.fromScale(0.9, 0.17)
	d.Countdown.TextColor3 = Color3.fromHex("ffffff")
	d.Lock.Position = UDim2.fromScale(0.5, 0.36)
	d.Lock.Size = UDim2.fromScale(0.28, 0.28)
end

-- REBIRTH : le gain d'abord (YOU GAIN à gauche, plus large, lignes plus hautes), la perte en une phrase en bas -----------
local body = SG.UI_Rebirth.Root.Window.Body
local inner = body.Columns.Inner
body.Columns.LayoutOrder = 0
body.Requirements.LayoutOrder = 1
inner.Gain.Position = UDim2.fromScale(0, 0)
inner.Gain.Size = UDim2.fromScale(0.56, 1)
inner.Keep.Position = UDim2.fromScale(0.58, 0)
inner.Keep.Size = UDim2.fromScale(0.42, 1)
inner.Lose.Visible = false
for _, r in inner.Gain.GainList:GetChildren() do
	if r:IsA("Frame") and r.Name:match("^Row") then r.Size = UDim2.fromScale(1, 0.2) end
end
local items = {}
for i = 1, 9 do
	local row = inner.Lose.LoseList:FindFirstChild("Row" .. i)
	if row and row.Visible then table.insert(items, row.RowLabel.Text) end
end
local line = body:FindFirstChild("LoseLine")
if not line then
	local model = inner.Keep.KeepList:FindFirstChild("RowLabel", true)
	assert(model, "KeepList sans RowLabel")
	line = model:Clone()
	line.Name = "LoseLine"
	for _, c in line:GetChildren() do
		if not c:IsA("UIStroke") then c:Destroy() end
	end
	line.AnchorPoint = Vector2.new(0, 0)
	line.Position = UDim2.new()
	line.TextXAlignment = Enum.TextXAlignment.Center
	line.LayoutOrder = 2
	line.Parent = body
end
line.Size = UDim2.new(1, 0, 0, 20)
line.Text = "You lose: " .. table.concat(items, ", ")
line.TextColor3 = Color3.fromHex("ff6a6a") -- le rouge de « Not owned yet »
local tc = line:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
tc.MinTextSize = 11
tc.MaxTextSize = 16
tc.Parent = line
-- vu en capture : dans la liste qui défile, la phrase sortait coupée ; elle est fixée au-dessus du bouton REBIRTH
local win = SG.UI_Rebirth.Root.Window
line.Parent = win
line.AnchorPoint = Vector2.new(0.5, 1)
line.Position = UDim2.new(0.5, 0, 1, -62)
line.Size = UDim2.new(0.92, 0, 0, 20)
line.ZIndex = win.Actions.ZIndex
body.Size = UDim2.new(1, 0, 0.84, -102)

-- HUD : le « + » de l'argent, comme celui de la vitesse (retour de Clément : le clone vert était « beaucoup trop gros »).
-- Même PlusBadge que SpeedRow.SpeedIcon, à la même taille à l'écran ; CashPlusButton = zone de clic invisible de 44 px.
local stats = SG.UI_HUD.BottomLeft.StatsPanel
local cashRow = stats.CashRow
local cashIcon = cashRow.CashIcon
local oldPlus = cashRow:FindFirstChild("CashPlusButton")
if oldPlus then oldPlus:Destroy() end
local badge = cashIcon:FindFirstChild("PlusBadge") or stats.SpeedRow.SpeedIcon.PlusBadge:Clone()
badge.Size = UDim2.fromScale(0.34, 0.34)
badge.Position = UDim2.fromScale(0.797, 0.68)
badge.Parent = cashIcon
local hit = cashIcon:FindFirstChild("CashPlusButton") or Instance.new("TextButton")
hit.Name = "CashPlusButton"
hit.Text = ""
hit.BackgroundTransparency = 1
hit.AutoButtonColor = false
hit.AnchorPoint = Vector2.new(0.5, 0.5)
hit.Position = UDim2.fromScale(0.797 + 0.17, 0.68 + 0.17)
hit.Size = UDim2.fromScale(0.34, 0.34)
hit.ZIndex = badge.ZIndex + 2
if not hit:FindFirstChildOfClass("UISizeConstraint") then
	local sc = Instance.new("UISizeConstraint")
	sc.MinSize = Vector2.new(44, 44)
	sc.Parent = hit
end
hit.Parent = cashIcon
cashRow.Income.LayoutOrder = 3

-- ROUE : compteur de tours, sous le temps du tour gratuit (le code l'écrit) -----------------------------------------
local side = SG.UI_Wheel.Root.Window.Side
local spins = side:FindFirstChild("SpinsLeft") or side.Timer:Clone()
spins.Name = "SpinsLeft"
spins.Text = "Spins left: 1"
spins.Position = UDim2.fromScale(0, 0.8)
spins.Size = UDim2.fromScale(1, 0.13)
spins.TextColor3 = Color3.fromHex("ffd43b")
spins.Parent = side

return "ok"
