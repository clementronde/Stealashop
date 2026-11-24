---------------------------------------------------------------- banc a232 : le chiffre du gain reste en TextScaled (T-150, T-151)
-- Faux Roblox d'a215 + setup232 (TextWrapped = false remet TextScaled à false, comme Roblox).
local hud, Gain = startBanc(296, nil)
local FLY = HudCfgC.TrainGainFly
P1:SetAttribute("TrainingMachine", "Treadmill")
local speed = 296

print("\n== A0. Faux Roblox : le lien TextWrapped → TextScaled est bien là")
do
	local probe = new("TextLabel", { Name = "Probe", TextScaled = true })
	check(probe.TextWrapped == true, "A0a TextScaled = true remet TextWrapped")
	probe.TextWrapped = false
	check(probe.TextScaled == false, "A0b TextWrapped = false remet TextScaled à false")
end

local function gain(add)
	credit(speed)
	step(1.3)
	speed += add
	credit(speed)
end

local function bigEnough(tag, amount)
	local b = amount.TextBounds
	check(b.Y >= amount.AbsoluteSize.Y * 0.99, `{tag} chiffre à la hauteur du cadre ({math.floor(b.X)} × {math.floor(b.Y)} px dans {math.floor(amount.AbsoluteSize.X)} × {math.floor(amount.AbsoluteSize.Y)})`)
end

for index, sz in { { 1920, 1080, "PC 1920 × 1080" }, { 844, 390, "téléphone 844 × 390" } } do
	SCREEN_SIZE = Vector2.new(sz[1], sz[2])
	for _, trail in { 3, false } do
		local trailText = if trail then "×3" else nil
		local tag = `A{index}{if trail then "t" else ""}`
		print(`\n== {tag}. Vol, repli sans modèle de Clément, {sz[3]}, {trailText or "sans trail"}`)
		P1:SetAttribute("TrailMultiplier", if trail then trail else nil)
		gain(8)
		local f = flyers(hud)[1]
		check(f ~= nil, `{tag}a un gain qui vole`)
		if f then
			local amount = el(f, "Amount")
			checkLine(tag, amount, "+8", trailText)
			bigEnough(tag, amount)
		end
		step(1.3)
	end
end

SCREEN_SIZE = Vector2.new(1920, 1080)
P1:SetAttribute("VfxEnabled", false)
for _, trail in { 3, false } do
	local trailText = if trail then "×3" else nil
	local tag = `A3{if trail then "t" else ""}`
	print(`\n== {tag}. Sur place (VISUAL EFFECTS sur OFF), BB_Gain de Clément, {trailText or "sans trail"}`)
	P1:SetAttribute("TrailMultiplier", if trail then trail else nil)
	gain(8)
	local bbs = childrenNamed(PLAYER_GUI, "BB_Gain")
	local bb = bbs[#bbs]
	check(bb ~= nil and #flyers(hud) == 0, `{tag}a l'ancien « +X » sur place`)
	if bb then
		local amount = el(bb, "Amount")
		checkLine(tag, amount, "+8", trailText)
		bigEnough(tag, amount)
	end
	step(1.3)
end

-- Texte long « +8 Speed/s » (sur place, en vol, bulle) : copie a232 du banc a215 (a224-banc/corrige.sh remet ces textes).
P1:SetAttribute("TrailMultiplier", nil)
P1:SetAttribute("VfxEnabled", true)

print("\n== A7. Modèle de Clément UI_HUD.TrainGainFly.Template : TextScaled gardé, modèle intact")
local folderUi = new("Frame", { Name = "TrainGainFly", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, hud)
local template = new("Frame", { Name = "Template", Visible = false, Size = UDim2.fromOffset(150, 40) }, folderUi)
local tAmount = new("TextLabel", { Name = "Amount", Text = "+0", Size = UDim2.fromScale(0.7, 1), TextScaled = true, TextWrapped = true }, template)
new("ImageLabel", { Name = "Icon", Image = "" }, template)
for _, trail in { 3, false } do
	local tag = `A7{if trail then "t" else ""}`
	P1:SetAttribute("TrailMultiplier", if trail then trail else nil)
	gain(8)
	local f = flyers(hud)[1]
	local amount = f and el(f, "Amount")
	check(amount ~= nil and amount.TextScaled == true and amount.TextWrapped == true, `{tag}a copie : TextScaled gardé`)
	if amount and trail then
		check(amount:FindFirstChild(UiMotionC.FloatGain.TrailExponent.Name) ~= nil, `{tag}b exposant posé`)
	end
	check(tAmount.TextScaled == true and tAmount.TextWrapped == true and tAmount.Text == "+0", `{tag}c modèle intact`)
	step(1.3)
end
check(BB_GAIN ~= nil and el(BB_GAIN, "Amount").TextScaled == true and el(BB_GAIN, "Amount").Text ~= nil, "A8 modèle BB_Gain de Clément intact (TextScaled)")
summary()
