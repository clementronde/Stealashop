---------------------------------------------------------------- scénario « gain » (a224) : « +2 » seul, plus gros
local hud, Gain = startBanc(296, nil)
local FLY = HudCfgC.TrainGainFly
local K = FLY.Scale
check(K == 1.5, `G0 Config/Hud.TrainGainFly.Scale = 1.5 ({K})`)
check(HudCfgC.BubbleGain.Text == "+%s" and HudCfgC.TreadmillGain.Text == "+%s", "G0b textes de bulle et de morceau : « +%s »")
P1:SetAttribute("TrainingMachine", "Treadmill")
local speed = 296
local function scaleOf(f)
	local s = f:FindFirstChild("GainScale")
	return if s then s.Scale else nil
end
for index, sz in { { 1920, 1080, "PC" }, { 844, 390, "téléphone 844 × 390" } } do
	SCREEN_SIZE = Vector2.new(sz[1], sz[2])
	for _, trail in { false, 3 } do
		local tag = `G{index}{if trail then "t" else ""}`
		print(`\n== {tag}. Gain du tapis qui vole, {sz[3]}, {if trail then "trail ×3" else "sans trail"}`)
		P1:SetAttribute("TrailMultiplier", if trail then trail else nil)
		credit(speed)
		step(0.1)
		speed += 2
		credit(speed)
		local f = flyers(hud)[1]
		check(f ~= nil, `{tag}a un gain qui vole`)
		if f then
			local amount = el(f, "Amount")
			check(PLAIN(amount.Text) == "+2" or string.match(PLAIN(amount.Text), "^%+2%s*$") ~= nil, `{tag}b texte « +2 » seul, sans Speed/s ({amount.Text})`)
			checkLine(tag, amount, "+2", if trail then "×3" else nil)
			step(0.09)
			check(near(scaleOf(f), K, 1e-6), `{tag}c taille pleine = {K} × celle d'avant ({scaleOf(f)})`)
			local h = f.AbsoluteSize.Y * K
			local c = f.AbsolutePosition.Y + f.AbsoluteSize.Y / 2
			check(c + h / 2 <= sz[2] and c - h / 2 >= 0, `{tag}d tient dans l'écran en hauteur ({math.floor(c - h / 2)} à {math.floor(c + h / 2)} sur {sz[2]})`)
			check(f.AbsoluteSize.X * K <= sz[1] * 0.35, `{tag}e largeur raisonnable ({math.floor(f.AbsoluteSize.X * K)} px)`)
			step(FLY.JetTime + FLY.Hold + FLY.SuckTime * 0.99 - 0.09)
			if f.Parent then
				check(scaleOf(f) < K and scaleOf(f) >= FLY.EndScale * K - 1e-6, `{tag}f aspiré : rétrécit vers {FLY.EndScale * K} ({scaleOf(f)})`)
			end
		end
		step(1.3)
		check(#flyers(hud) == 0, `{tag}g arrivé`)
	end
end
check(speedText(hud) == FormatC.short(FormulasC.ShownSpeed(speed, 3)), `G3 compteur juste ({speedText(hud)})`)

print("\n== G4. « +2 » sur place (VISUAL EFFECTS sur OFF) : BB_Gain 1,5 × plus grand, une ligne")
SCREEN_SIZE = Vector2.new(1920, 1080)
P1:SetAttribute("TrailMultiplier", nil)
P1:SetAttribute("VfxEnabled", false)
credit(speed)
step(1.3)
speed += 2
credit(speed)
local bbs = childrenNamed(PLAYER_GUI, "BB_Gain")
local bb = bbs[#bbs]
check(bb ~= nil and el(bb, "Amount").Text == "+2", `G4a « +2 » ({bb and el(bb, "Amount").Text})`)
if bb then
	local s0, s1 = BB_GAIN.Size, bb.Size
	check(near(s1.X.Offset, s0.X.Offset * K, 1e-6) and near(s1.Y.Offset, s0.Y.Offset * K, 1e-6)
		and near(s1.X.Scale, s0.X.Scale * K, 1e-6) and near(s1.Y.Scale, s0.Y.Scale * K, 1e-6),
		`G4b taille × {K} ({s1.X.Offset} × {s1.Y.Offset} pour {s0.X.Offset} × {s0.Y.Offset})`)
end
check(near(BB_GAIN.Size.X.Offset, 150, 1e-6), "G4c modèle BB_Gain de Clément intact")
step(1.3)
print("\n== G5. Bulle ×4 : « +32 », en vol et sur place")
P1:SetAttribute("TrailMultiplier", 3)
step(0.1)
Gain.NoteBubble(32)
speed += 32
credit(speed)
bbs = childrenNamed(PLAYER_GUI, "BB_Gain")
bb = bbs[#bbs]
check(bb ~= nil and string.match(PLAIN(el(bb, "Amount").Text), "^%+32%s*$") ~= nil, `G5a sur place « +32 » + exposant ({bb and el(bb, "Amount").Text})`)
step(1.3)
P1:SetAttribute("VfxEnabled", true)
P1:SetAttribute("TrailMultiplier", nil)
step(0.1)
Gain.NoteBubble(32)
speed += 32
credit(speed)
local f = flyers(hud)[1]
check(f ~= nil and el(f, "Amount").Text == "+32", `G5b en vol « +32 » ({f and el(f, "Amount").Text})`)
step(0.09)
check(f ~= nil and near(scaleOf(f), K, 1e-6), `G5c même taille que le tapis ({f and scaleOf(f)})`)
step(1.3)
print("\n== G6. Modèle de Clément UI_HUD.TrainGainFly.Template : texte « +2 » posé dedans, plus gros, modèle intact")
local folderUi = new("Frame", { Name = "TrainGainFly", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, hud)
local template = new("Frame", { Name = "Template", Visible = false, Size = UDim2.fromOffset(150, 40) }, folderUi)
new("TextLabel", { Name = "Amount", Text = "+0", Size = UDim2.fromScale(0.7, 1), TextScaled = true, TextWrapped = true }, template)
new("ImageLabel", { Name = "Icon", Image = "" }, template)
speed += 2
credit(speed)
f = flyers(hud)[1]
check(f ~= nil and el(f, "Amount").Text == "+2" and near(f.Size.X.Offset, 150, 1e-6), `G6a copie du modèle, « +2 » ({f and el(f, "Amount").Text})`)
step(0.09)
check(f ~= nil and near(scaleOf(f), K, 1e-6), `G6b × {K} ({f and scaleOf(f)})`)
check(el(template, "Amount").Text == "+0" and template.Visible == false and near(template.Size.X.Offset, 150, 1e-6), "G6c modèle intact")
step(1.3)
summary()
