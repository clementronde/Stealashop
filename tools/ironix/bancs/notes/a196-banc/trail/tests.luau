---------------------------------------------------------------- banc a196, partie trail (vague 60, T-097)
-- « ×2 » du trail plus haut : petit TextLabel TrailExponent créé dans Row.Amount, au coin haut droit du nombre.
local F = UiMotionC.FloatGain
local E = F.TrailExponent
local Motion = requireModule(MOTION_MODULE, "client")
Motion.SetSoundPlayer(function() end)
P1:SetAttribute("Cash", 100)
P1:SetAttribute("Income", 10)
P1:SetAttribute("Speed", 10)
P1:SetAttribute("Strength", 5)
P1:SetAttribute("WalkSpeed", 16)
P1:SetAttribute("Damage", 1)
P1:SetAttribute("CashCollected", 0)
makeHud()
local gainSnap = snapshot(BB_GAIN)
local Hud = requireModule(HUD_MODULE, "client")
requireModule(REWARDS_MODULE, "client")
local Gain = requireModule(GAIN_MODULE, "client")
taskLib.spawn(Hud.Start)
taskLib.spawn(Gain.Start)
step(0.1)
local speed = 10
local function gainWith(trail)
	P1:SetAttribute("TrailMultiplier", trail)
	P1:SetAttribute("TrainingMachine", "Treadmill")
	speed += 1
	P1:SetAttribute("Speed", speed)
	local list = childrenNamed(PLAYER_GUI, "BB_Gain")
	return list[#list]
end
local function clear()
	P1:SetAttribute("TrainingMachine", nil)
	step(F.Time + 0.5)
end
local function near(a, b)
	return math.abs(a - b) < 1e-6
end

check(E.Mode == "Label" and E.Name == "TrailExponent" and E.Size == 0.55 and E.Raise == 0.15, "E0 réglages V0 : Label, TrailExponent, 0,55, 0,15")

print("\n== E1. Trail ×2 sans Row.Multiplier")
local bb = gainWith(2)
local amount = bb and el(bb, "Amount")
local exp = amount and amount:FindFirstChild(E.Name)
local txt = amount and amount.Text or ""
check(string.match(txt, "^%+1  + Speed/s$") ~= nil and not string.find(txt, "ˣ", 1, true) and not string.find(txt, "<", 1, true), `E1a Row.Amount : le nombre, un blanc, le reste, sans exposant Unicode ({txt})`)
check(exp ~= nil and exp.ClassName == "TextLabel" and exp.Text == "×2", `E1b TextLabel {E.Name} « ×2 » dans Row.Amount ({exp and exp.Text})`)
check(exp ~= nil and sameColor(exp.TextColor3, F.TrailMultiplierColor), "E1c couleur TrailMultiplierColor")
-- Texte centré (faux TextLabel) : bloc de TextBounds au milieu de AbsoluteSize ; sans TextService, largeur au caractère.
local size = amount and amount.AbsoluteSize or Vector2.new(0, 0)
if size.X <= 0 or size.Y <= 0 then
	size = Vector2.new(100, 100) -- même repli que le code (faux billboard sans taille)
end
local bounds = amount and amount.TextBounds or Vector2.new(1, 1)
if size.X == 100 and size.Y == 100 then
	bounds = size -- repli du code : en proportions seulement
end
local ratio = (utf8.len("+1") :: number) / (utf8.len(txt) :: number)
local wantX = ((size.X - bounds.X) / 2 + ratio * bounds.X) / size.X
local wantY = ((size.Y - bounds.Y) / 2 + E.Raise * bounds.Y) / size.Y
check(exp ~= nil and near(exp.Position.X.Scale, wantX) and exp.AnchorPoint.X == 0 and exp.AnchorPoint.Y == 0.5, `E1d juste à droite du nombre (X = {exp and exp.Position.X.Scale}, attendu {wantX})`)
check(exp ~= nil and near(exp.Position.Y.Scale, wantY) and exp.Position.Y.Scale < 0.5, `E1e centre à Raise × la hauteur du texte depuis son haut (Y = {exp and exp.Position.Y.Scale}, attendu {wantY})`)
check(exp ~= nil and near(exp.Size.Y.Scale * size.Y, E.Size * bounds.Y) and exp.TextScaled == true, `E1f hauteur Size × celle du texte ({exp and exp.Size.Y.Scale})`)
check(exp ~= nil and exp.Position.Y.Scale - exp.Size.Y.Scale / 2 < (size.Y - bounds.Y) / 2 / size.Y, "E1j il dépasse au-dessus du haut du texte (exposant)")
check(exp ~= nil and exp:FindFirstChildOfClass("UIStroke") ~= nil, "E1g contour de Row.Amount copié")
step(F.Time * 0.97)
check(exp ~= nil and exp.TextTransparency > 0.5, `E1h il s'efface avec le gain ({exp and exp.TextTransparency})`)
clear()
check(#childrenNamed(PLAYER_GUI, "BB_Gain") == 0, "E1i copie détruite à la fin")

print("\n== E2. ×1.5 : blanc plus large")
bb = gainWith(1.5)
amount = bb and el(bb, "Amount")
exp = amount and amount:FindFirstChild(E.Name)
local txt15 = amount and amount.Text or ""
check(exp ~= nil and exp.Text == "×1.5" and #txt15 > #txt, `E2 « ×1.5 », blanc plus large ({txt15})`)
clear()

print("\n== E3. Sans trail, ×1, ou avec Row.Multiplier : pas de TrailExponent")
bb = gainWith(nil)
amount = bb and el(bb, "Amount")
check(amount and amount.Text == "+1 Speed/s" and amount:FindFirstChild(E.Name) == nil, `E3a sans trail ({amount and amount.Text})`)
clear()
bb = gainWith(1)
amount = bb and el(bb, "Amount")
check(amount and amount.Text == "+1 Speed/s" and amount:FindFirstChild(E.Name) == nil, "E3b trail ×1")
clear()
local same, why = sameAs(gainSnap, BB_GAIN)
check(same and el(BB_GAIN, "Amount"):FindFirstChild(E.Name) == nil, `E3c modèle BB_Gain intact ({why})`)
local label = new("TextLabel", { Name = "Multiplier", Text = "", Visible = true }, el(BB_GAIN, "Row"))
bb = gainWith(2)
amount = bb and el(bb, "Amount")
local m = bb and el(bb, "Multiplier")
check(amount and amount.Text == "+1 Speed/s" and amount:FindFirstChild(E.Name) == nil and m and m.Text == "×2", "E3d Row.Multiplier de Clément : « ×2 » dedans, pas de TrailExponent")
clear()
label.Parent = nil
summary()
