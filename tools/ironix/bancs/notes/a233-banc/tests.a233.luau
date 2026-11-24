---------------------------------------------------------------- banc a233 : exposant « ×3 » après le chiffre (T-150, T-151)
-- Modèle de Clément en Montserrat Heavy (FontFace, Font = Unknown), chiffres larges, GetTextBoundsAsync qui attend.
local hud, Gain = startBanc(296, nil)
P1:SetAttribute("TrainingMachine", "Treadmill")
local speed = 296

local function gain(add)
	credit(speed)
	step(1.3)
	speed += add
	credit(speed)
	step(0.1) -- la première mesure d'un texte attend une image
end

local function bigEnough(tag, amount)
	local b = amount.TextBounds
	check(b.Y >= amount.AbsoluteSize.Y * 0.99, `{tag} chiffre à la hauteur du cadre ({math.floor(b.X)} × {math.floor(b.Y)} px dans {math.floor(amount.AbsoluteSize.X)} × {math.floor(amount.AbsoluteSize.Y)})`)
end

print("\n== B0. Faux Roblox : police inconnue de GetTextSize, chiffres larges")
do
	local amount = el(el(BB_GAIN, "Row"), "Amount")
	check(amount.Font == Enum.Font.Unknown and amount.FontFace == HEAVY, "B0a BB_Gain.Row.Amount en FontFace Heavy, Font Unknown")
	check(MEASURE("+8") > MEASURE("ab"), "B0b « +8 » plus large que deux caractères moyens")
end

for index, sz in { { 1920, 1080, "PC 1920 × 1080" }, { 844, 390, "téléphone 844 × 390" } } do
	SCREEN_SIZE = Vector2.new(sz[1], sz[2])
	for _, trail in { 3, false } do
		local trailText = if trail then "×3" else nil
		local tag = `B{index}{if trail then "t" else ""}`
		print(`\n== {tag}. Vol, {sz[3]}, {trailText or "sans trail"}`)
		P1:SetAttribute("TrailMultiplier", if trail then trail else nil)
		local before = BOUNDS_CALLS
		gain(8)
		local f = flyers(hud)[1]
		check(f ~= nil, `{tag}a un gain qui vole`)
		if index == 1 and trail then
			check(BOUNDS_CALLS > before, `{tag}b mesuré par GetTextBoundsAsync ({BOUNDS_CALLS - before} appel(s))`)
		end
		if f then
			local amount = el(f, "Amount")
			checkLine(tag, amount, "+8", trailText)
			bigEnough(tag, amount)
		end
		step(1.3)
	end
end

print("\n== B3. Même gain une 2e fois : tout vient du cache, rien n'attend")
do
	SCREEN_SIZE = Vector2.new(1920, 1080)
	P1:SetAttribute("TrailMultiplier", 3)
	credit(speed)
	step(1.3)
	local before = BOUNDS_CALLS
	speed += 8
	credit(speed)
	local f = flyers(hud)[1]
	check(BOUNDS_CALLS == before, `B3a aucun nouvel appel ({BOUNDS_CALLS - before})`)
	check(f ~= nil, "B3b le gain vole tout de suite (sans attendre)")
	if f then
		checkLine("B3", el(f, "Amount"), "+8", "×3")
	end
	step(1.3)
end

P1:SetAttribute("VfxEnabled", false)
for _, trail in { 3, false } do
	local trailText = if trail then "×3" else nil
	local tag = `B4{if trail then "t" else ""}`
	print(`\n== {tag}. Sur place (VISUAL EFFECTS sur OFF), BB_Gain de Clément, {trailText or "sans trail"}`)
	P1:SetAttribute("TrailMultiplier", if trail then trail else nil)
	gain(9) -- texte neuf : la mesure attend aussi sur place
	local bbs = childrenNamed(PLAYER_GUI, "BB_Gain")
	local bb = bbs[#bbs]
	check(bb ~= nil and #flyers(hud) == 0, `{tag}a l'ancien « +X » sur place`)
	if bb then
		local amount = el(bb, "Amount")
		checkLine(tag, amount, "+9", trailText)
		bigEnough(tag, amount)
	end
	step(1.3)
end
P1:SetAttribute("VfxEnabled", true)

print("\n== B5. GetTextBoundsAsync en erreur : repli au nombre de caractères, le gain vole quand même")
do
	BOUNDS_MODE = "error"
	P1:SetAttribute("TrailMultiplier", 3)
	gain(77) -- texte neuf : pas dans le cache
	local f = flyers(hud)[1]
	check(f ~= nil, "B5a un gain qui vole")
	local amount = f and el(f, "Amount")
	check(amount ~= nil and amount:FindFirstChild(UiMotionC.FloatGain.TrailExponent.Name) ~= nil, "B5b exposant posé (repli)")
	BOUNDS_MODE = "ok"
	step(1.3)
end
check(el(el(BB_GAIN, "Row"), "Amount").FontFace == HEAVY, "B6 modèle BB_Gain de Clément intact (FontFace)")
summary()
