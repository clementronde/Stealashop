---------------------------------------------------------------- scénario « layout » : texte sur une ligne, exposant juste après le nombre
local hud, Gain = startBanc(296, nil)
local FLY = HudCfgC.TrainGainFly
check(type(FLY.TextMargin) == "number" and FLY.Aspect == 3.5 and FLY.Height == 0.05, "L0 Config/Hud : TextMargin, Height et Aspect d'avant gardés")
P1:SetAttribute("TrainingMachine", "Treadmill")
local speed = 296
local SIZES = { { 1920, 1080, "PC 1920 × 1080" }, { 844, 390, "téléphone 844 × 390" }, { 1280, 720, "1280 × 720" } }
for index, sz in SIZES do
	SCREEN_SIZE = Vector2.new(sz[1], sz[2])
	for _, trail in { 3, 1.5, false } do
		local trailText = if trail then `×{string.format("%g", trail)}` else nil
		print(`\n== L{index}. Repli sans modèle de Clément, {sz[3]}, {trailText or "sans trail"}`)
		P1:SetAttribute("TrailMultiplier", if trail then trail else nil)
		credit(speed)
		step(0.1)
		speed += 8
		credit(speed)
		local list = flyers(hud)
		local f = list[#list]
		check(f ~= nil, `L{index} un gain qui vole`)
		if f then
			local amount = el(f, "Amount")
			local height = sz[2] * FLY.Height
			check(near(f.AbsoluteSize.Y, height, 1e-6), `L{index} hauteur inchangée : {height} px ({f.AbsoluteSize.Y})`)
			check(f.AbsoluteSize.X >= height * FLY.Aspect - 1e-6, `L{index} jamais plus étroit qu'avant ({math.floor(f.AbsoluteSize.X)} px)`)
			local b = checkLine(`L{index}`, amount, "+8", trailText)
			check(b.Y >= amount.AbsoluteSize.Y * 0.99, `L{index} texte à la hauteur du cadre, pas réduit ({math.floor(b.Y)} sur {math.floor(amount.AbsoluteSize.Y)} px)`)
			check(f.AbsoluteSize.X <= sz[1] * 0.35, `L{index} largeur raisonnable : {math.floor(f.AbsoluteSize.X)} px sur {sz[1]}`)
		end
		step(1.3)
		check(#flyers(hud) == 0, `L{index} arrivé`)
	end
end
check(speedText(hud) == FormatC.short(FormulasC.ShownSpeed(speed, nil)), `L4 compteur juste à la fin ({speedText(hud)})`)

print("\n== L5. « +X » sur place (VISUAL EFFECTS sur OFF), BB_Gain de 150 × 46 px, trail ×3")
SCREEN_SIZE = Vector2.new(1920, 1080)
P1:SetAttribute("VfxEnabled", false)
P1:SetAttribute("TrailMultiplier", 3)
credit(speed)
step(1.3)
speed += 8
credit(speed)
local bbs = childrenNamed(PLAYER_GUI, "BB_Gain")
local bb = bbs[#bbs]
check(bb ~= nil and #flyers(hud) == 0, "L5a l'ancien « +X » sur place")
if bb then
	checkLine("L5", el(bb, "Amount"), "+8", "×3")
end
check(el(BB_GAIN, "Amount").TextWrapped == true, "L5c modèle BB_Gain de Clément intact (TextWrapped)")
step(1.3)
print("\n== L6. Sur place sans trail : texte de Clément tel quel (rien ne change)")
P1:SetAttribute("TrailMultiplier", nil)
speed += 8
credit(speed)
bbs = childrenNamed(PLAYER_GUI, "BB_Gain")
bb = bbs[#bbs]
check(bb ~= nil and el(bb, "Amount").TextWrapped == true and el(bb, "Amount").Text == "+8 Speed/s", "L6 BB_Gain sans exposant : copie telle quelle")
step(1.3)
P1:SetAttribute("VfxEnabled", true)

print("\n== L7. Modèle de Clément UI_HUD.TrainGainFly.Template : rien ne change")
local folderUi = new("Frame", { Name = "TrainGainFly", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, hud)
local template = new("Frame", { Name = "Template", Visible = false, Size = UDim2.fromOffset(150, 40) }, folderUi)
local tAmount = new("TextLabel", { Name = "Amount", Text = "+0", Size = UDim2.fromScale(0.7, 1), TextScaled = true, TextWrapped = true }, template)
new("ImageLabel", { Name = "Icon", Image = "" }, template)
P1:SetAttribute("TrailMultiplier", 3)
credit(speed)
step(1.3)
speed += 8
credit(speed)
local f7 = flyers(hud)[1]
check(f7 ~= nil and f7.AbsoluteSize.X == 150 and f7.AbsoluteSize.Y == 40, `L7a taille de Clément gardée ({f7 and f7.AbsoluteSize.X})`)
check(f7 ~= nil and el(f7, "Amount").TextWrapped == true and tAmount.TextWrapped == true, "L7b son Amount garde TextWrapped, modèle intact")
step(1.3)
summary()
