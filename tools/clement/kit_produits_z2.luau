--!nocheck
-- Kits de produits de la zone 2 : Confiserie et Magasin de jouets. A lancer en Edit APRES le contenu de
-- tools/clement/kit_lib.luau (colle en tete), puis tools/clement/kits_fusion.luau. 10 produits par magasin, dont 2 longs.

local W, DARK, RED, BLUE, YELLOW, GREEN, ORANGE, PINK = "#F7F5F0", "#2B2F36", "#D8343C", "#2D5BD7", "#F3D35A", "#3FAE5A", "#F08A2B", "#F07AA8"
local PURPLE, TEAL, BROWN, CHOCO, MINT, LILAC = "#7B4FC9", "#2BB3A8", "#8A5A33", "#5A3420", "#9CE6C8", "#C9A6F0"
local GLASS = { mat = Enum.Material.Glass, transp = 0.5 }

local function lollipop(m, name, cf, col)
	p(m, name .. "_Stick", Vector3.new(0.04, 0.5, 0.04), cf * CFrame.new(0, 0.25, 0), W)
	cyl(m, name, 0.06, 0.3, cf * CFrame.new(0, 0.62, 0) * FACE, col)
	cyl(m, name .. "_Swirl", 0.065, 0.16, cf * CFrame.new(0, 0.62, 0) * FACE, W)
end
local function candyJar(m, name, x, h, col1, col2, seed)
	cyl(m, name, 0.6, 0.42, CFrame.new(x, h + 0.3, 0) * UP, "#E8F6FF", GLASS)
	cyl(m, name .. "_Lid", 0.08, 0.44, CFrame.new(x, h + 0.64, 0) * UP, col1)
	ball(m, name .. "_Knob", 0.1, CFrame.new(x, h + 0.71, 0), col2)
	local rng = Random.new(seed)
	for i = 1, 9 do ball(m, name .. "_Candy" .. i, 0.12, CFrame.new(x + rng:NextNumber(-0.12, 0.12), h + 0.08 + rng:NextNumber(0, 0.38), rng:NextNumber(-0.12, 0.12)), if i % 2 == 0 then col1 else col2) end
end

-- ================= CONFISERIE =================
store(2, "Confiserie")
do -- 1. bocal de bonbons
	local m, h = newProp("CandyJar", Vector3.new(0.55, 0.05, 0.55), PINK)
	candyJar(m, "Jar", 0, h, RED, YELLOW, 21)
end
do -- 2. bouquet de sucettes dans un pot
	local m, h = newProp("LollipopPot", Vector3.new(0.6, 0.05, 0.6), PINK)
	cyl(m, "Pot", 0.3, 0.36, CFrame.new(0, h + 0.15, 0) * UP, W)
	local cols = { RED, BLUE, YELLOW, GREEN, PURPLE }
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		lollipop(m, "Pop" .. i, CFrame.new(math.cos(a) * 0.07, h + 0.1, math.sin(a) * 0.07) * CFrame.Angles(math.sin(a) * 0.25, 0, -math.cos(a) * 0.25), cols[i + 1])
	end
end
do -- 3. sachet d'oursons
	local m, h = newProp("GummyBag", Vector3.new(0.65, 0.04, 0.35), DARK)
	p(m, "Bag", Vector3.new(0.55, 0.7, 0.24), CFrame.new(0, h + 0.35, 0), "#E8F6FF", { mat = Enum.Material.Glass, transp = 0.25 })
	p(m, "Header", Vector3.new(0.57, 0.14, 0.26), CFrame.new(0, h + 0.72, 0), RED)
	local cols = { RED, GREEN, YELLOW, ORANGE }
	for i = 0, 5 do
		local x, y = -0.14 + (i % 3) * 0.14, h + 0.15 + math.floor(i / 3) * 0.2
		ball(m, "Bear" .. i, 0.12, CFrame.new(x, y, -0.07), cols[i % 4 + 1])
		ball(m, "BearHead" .. i, 0.08, CFrame.new(x, y + 0.09, -0.07), cols[i % 4 + 1])
	end
end
do -- 4. boite de chocolats ouverte
	local m, h = newProp("ChocolateBox", Vector3.new(1.0, 0.04, 0.75), DARK)
	p(m, "Box", Vector3.new(0.9, 0.12, 0.65), CFrame.new(0, h + 0.06, 0), RED)
	p(m, "Lid", Vector3.new(0.9, 0.05, 0.65), CFrame.new(0, h + 0.36, 0.36) * CFrame.Angles(math.rad(-75), 0, 0), RED)
	p(m, "Bow", Vector3.new(0.25, 0.12, 0.05), CFrame.new(0, h + 0.4, 0.33), YELLOW)
	for i = 0, 7 do
		local x, z = -0.3 + (i % 4) * 0.2, -0.12 + math.floor(i / 4) * 0.24
		ball(m, "Choc" .. i, 0.16, CFrame.new(x, h + 0.15, z), if i % 3 == 0 then W else CHOCO)
	end
end
do -- 5. barbe a papa
	local m, h = newProp("CottonCandy", Vector3.new(0.5, 0.05, 0.5), DARK)
	p(m, "Stand", Vector3.new(0.2, 0.15, 0.2), CFrame.new(0, h + 0.075, 0), DARK)
	p(m, "Stick", Vector3.new(0.05, 0.6, 0.05), CFrame.new(0, h + 0.4, 0), W)
	ball(m, "Fluff", 0.42, CFrame.new(0, h + 0.82, 0), PINK)
	ball(m, "Fluff2", 0.3, CFrame.new(0.12, h + 0.95, 0.05), LILAC)
end
do -- 6. plateau de macarons
	local m, h = newProp("MacaronTray", Vector3.new(1.0, 0.06, 0.7), W)
	local cols = { PINK, MINT, YELLOW, LILAC, ORANGE, BROWN }
	for i = 0, 5 do
		local x, z = -0.3 + (i % 3) * 0.3, -0.15 + math.floor(i / 3) * 0.3
		cyl(m, "Shell" .. i .. "a", 0.08, 0.24, CFrame.new(x, h + 0.04, z) * UP, cols[i + 1])
		cyl(m, "Cream" .. i, 0.05, 0.22, CFrame.new(x, h + 0.105, z) * UP, W)
		cyl(m, "Shell" .. i .. "b", 0.08, 0.24, CFrame.new(x, h + 0.17, z) * UP, cols[i + 1])
	end
end
do -- 7. cupcake geant
	local m, h = newProp("Cupcake", Vector3.new(0.55, 0.04, 0.55), DARK)
	cyl(m, "Case", 0.3, 0.4, CFrame.new(0, h + 0.15, 0) * UP, BLUE)
	ball(m, "Frosting", 0.46, CFrame.new(0, h + 0.38, 0), PINK)
	ball(m, "Top", 0.26, CFrame.new(0, h + 0.56, 0), PINK)
	ball(m, "Cherry", 0.12, CFrame.new(0, h + 0.71, 0), RED)
end
do -- 8. fagot de cannes en sucre
	local m, h = newProp("CandyCanes", Vector3.new(0.6, 0.04, 0.4), DARK)
	for i = -1, 1 do
		local cf = CFrame.new(i * 0.14, h, 0) * CFrame.Angles(0, 0, math.rad(i * 8))
		for k = 0, 4 do p(m, "Cane" .. i .. "_" .. k, Vector3.new(0.08, 0.16, 0.08), cf * CFrame.new(0, 0.08 + k * 0.16, 0), if k % 2 == 0 then RED else W) end
		p(m, "Hook" .. i, Vector3.new(0.2, 0.08, 0.08), cf * CFrame.new(0.06, 0.82, 0), RED)
	end
	p(m, "Ribbon", Vector3.new(0.44, 0.08, 0.12), CFrame.new(0, h + 0.35, 0), GREEN)
end
do -- 9. long : rangee de bocaux (2,35 x 0,55)
	local m, h = newProp("CandyJarRow", Vector3.new(2.35, 0.05, 0.55), PINK)
	local sets = { { RED, YELLOW }, { BLUE, GREEN }, { PURPLE, PINK }, { ORANGE, W } }
	for i = 0, 3 do candyJar(m, "Jar" .. i, -0.87 + i * 0.58, h, sets[i + 1][1], sets[i + 1][2], 30 + i) end
end
do -- 10. long : presentoir de sucettes (2,35 x 0,4)
	local m, h = newProp("LollipopRow", Vector3.new(2.35, 0.25, 0.4), W, true)
	local cols = { RED, BLUE, YELLOW, GREEN, PURPLE, ORANGE, PINK, TEAL }
	for i = 0, 7 do lollipop(m, "Pop" .. i, CFrame.new(-1.0 + i * 0.285, h - 0.05, 0), cols[i + 1]) end
end

-- ================= MAGASIN DE JOUETS =================
store(2, "MagasinDeJouets")
do -- 1. ours en peluche
	local m, h = newProp("TeddyBear", Vector3.new(0.7, 0.04, 0.55), DARK)
	ball(m, "Body", 0.5, CFrame.new(0, h + 0.3, 0), BROWN, { mat = Enum.Material.Fabric })
	ball(m, "Head", 0.38, CFrame.new(0, h + 0.7, 0), BROWN, { mat = Enum.Material.Fabric })
	for s = -1, 1, 2 do
		ball(m, "Ear" .. s, 0.14, CFrame.new(s * 0.15, h + 0.88, 0), BROWN, { mat = Enum.Material.Fabric })
		ball(m, "Arm" .. s, 0.18, CFrame.new(s * 0.27, h + 0.38, -0.05), BROWN, { mat = Enum.Material.Fabric })
		ball(m, "Leg" .. s, 0.2, CFrame.new(s * 0.15, h + 0.1, -0.15), BROWN, { mat = Enum.Material.Fabric })
	end
	ball(m, "Snout", 0.15, CFrame.new(0, h + 0.66, -0.17), "#D9B68A")
	p(m, "Bow", Vector3.new(0.3, 0.08, 0.06), CFrame.new(0, h + 0.52, -0.2), RED)
end
do -- 2. robot jouet
	local m, h = newProp("ToyRobot", Vector3.new(0.6, 0.04, 0.45), DARK)
	p(m, "Legs", Vector3.new(0.32, 0.25, 0.2), CFrame.new(0, h + 0.125, 0), "#9AA3AF")
	p(m, "Body", Vector3.new(0.42, 0.35, 0.28), CFrame.new(0, h + 0.43, 0), BLUE)
	p(m, "Head", Vector3.new(0.3, 0.24, 0.24), CFrame.new(0, h + 0.73, 0), "#9AA3AF")
	neon(m, "Eyes", Vector3.new(0.2, 0.05, 0.02), CFrame.new(0, h + 0.75, -0.125), "#57E3FF")
	p(m, "Antenna", Vector3.new(0.03, 0.15, 0.03), CFrame.new(0, h + 0.92, 0), "#9AA3AF")
	ball(m, "AntennaTip", 0.07, CFrame.new(0, h + 1.0, 0), RED)
	for s = -1, 1, 2 do p(m, "Arm" .. s, Vector3.new(0.08, 0.3, 0.08), CFrame.new(s * 0.26, h + 0.42, 0), "#9AA3AF") end
end
do -- 3. cubes a lettres
	local m, h = newProp("LetterBlocks", Vector3.new(0.9, 0.04, 0.6), DARK)
	local cols = { RED, BLUE, YELLOW, GREEN, ORANGE, PURPLE }
	local pos = { { -0.22, 0, -0.1 }, { 0.06, 0, -0.12 }, { 0.32, 0, -0.05 }, { -0.08, 0, 0.16 }, { 0.2, 0, 0.17 }, { -0.08, 1, 0.02 } }
	for i, q in pos do
		local cf = CFrame.new(q[1], h + 0.12 + q[2] * 0.24, q[3]) * CFrame.Angles(0, math.rad(i * 13), 0)
		p(m, "Block" .. i, Vector3.new(0.24, 0.24, 0.24), cf, cols[i])
		p(m, "Letter" .. i, Vector3.new(0.12, 0.12, 0.01), cf * CFrame.new(0, 0, -0.125), W)
	end
end
do -- 4. voiture dans sa boite
	local m, h = newProp("ToyCarBox", Vector3.new(0.9, 0.04, 0.4), DARK)
	p(m, "Box", Vector3.new(0.85, 0.5, 0.32), CFrame.new(0, h + 0.25, 0), YELLOW)
	p(m, "Window", Vector3.new(0.65, 0.3, 0.02), CFrame.new(0, h + 0.27, -0.17), "#E8F6FF", { mat = Enum.Material.Glass, transp = 0.4 })
	p(m, "Car", Vector3.new(0.5, 0.12, 0.2), CFrame.new(0, h + 0.2, -0.04), RED)
	p(m, "Cabin", Vector3.new(0.26, 0.1, 0.18), CFrame.new(-0.03, h + 0.31, -0.04), RED)
	for s = -1, 1, 2 do cyl(m, "Wheel" .. s, 0.2, 0.1, CFrame.new(s * 0.17, h + 0.14, -0.04) * FACE * CFrame.Angles(0, math.rad(90), 0), DARK) end
	p(m, "Title", Vector3.new(0.5, 0.08, 0.01), CFrame.new(0, h + 0.46, -0.165), RED)
end
do -- 5. toupie
	local m, h = newProp("SpinningTop", Vector3.new(0.5, 0.04, 0.5), DARK)
	cyl(m, "Disc", 0.16, 0.42, CFrame.new(0, h + 0.2, 0) * UP, RED)
	cyl(m, "Stripe", 0.06, 0.43, CFrame.new(0, h + 0.2, 0) * UP, YELLOW)
	p(m, "Tip", Vector3.new(0.1, 0.12, 0.1), CFrame.new(0, h + 0.06, 0) * CFrame.Angles(0, math.rad(45), 0), DARK)
	cyl(m, "Handle", 0.2, 0.06, CFrame.new(0, h + 0.38, 0) * UP, BLUE)
end
do -- 6. fusee jouet
	local m, h = newProp("ToyRocket", Vector3.new(0.55, 0.04, 0.55), DARK)
	cyl(m, "Body", 0.7, 0.24, CFrame.new(0, h + 0.45, 0) * UP, W)
	ball(m, "Nose", 0.24, CFrame.new(0, h + 0.82, 0), RED)
	cyl(m, "Window", 0.02, 0.1, CFrame.new(0, h + 0.58, -0.12) * FACE, BLUE)
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2
		p(m, "Fin" .. i, Vector3.new(0.04, 0.24, 0.16), CFrame.new(math.cos(a) * 0.15, h + 0.18, math.sin(a) * 0.15) * CFrame.Angles(0, -a, 0), RED)
	end
end
do -- 7. poupee dans sa boite
	local m, h = newProp("DollBox", Vector3.new(0.6, 0.04, 0.35), DARK)
	p(m, "Box", Vector3.new(0.5, 0.85, 0.28), CFrame.new(0, h + 0.425, 0), PINK)
	p(m, "Window", Vector3.new(0.38, 0.6, 0.02), CFrame.new(0, h + 0.4, -0.15), "#E8F6FF", { mat = Enum.Material.Glass, transp = 0.4 })
	p(m, "Dress", Vector3.new(0.2, 0.28, 0.08), CFrame.new(0, h + 0.28, -0.06), PURPLE)
	ball(m, "Head", 0.14, CFrame.new(0, h + 0.52, -0.06), "#F2CFA8")
	p(m, "Hair", Vector3.new(0.16, 0.12, 0.08), CFrame.new(0, h + 0.58, -0.04), YELLOW)
	p(m, "Title", Vector3.new(0.38, 0.08, 0.01), CFrame.new(0, h + 0.78, -0.145), W)
end
do -- 8. trois balles rebondissantes
	local m, h = newProp("BouncyBalls", Vector3.new(0.8, 0.04, 0.5), DARK)
	ball(m, "Ball1", 0.34, CFrame.new(-0.2, h + 0.17, 0), RED)
	ball(m, "Ball2", 0.28, CFrame.new(0.15, h + 0.14, -0.08), BLUE)
	ball(m, "Ball3", 0.24, CFrame.new(0.02, h + 0.44, 0.02), YELLOW)
	p(m, "Stripe1", Vector3.new(0.35, 0.04, 0.35), CFrame.new(-0.2, h + 0.17, 0), W)
end
do -- 9. long : rangee de boites de jeux (2,35 x 0,5)
	local m, h = newProp("GameBoxRow", Vector3.new(2.35, 0.04, 0.5), DARK)
	local cols = { RED, BLUE, GREEN, PURPLE, ORANGE, TEAL, YELLOW }
	for i = 0, 6 do
		local hh = 0.5 + (i % 3) * 0.1
		p(m, "Box" .. i, Vector3.new(0.28, hh, 0.44), CFrame.new(-1.0 + i * 0.33, h + hh / 2, 0), cols[i + 1])
		p(m, "Label" .. i, Vector3.new(0.2, 0.12, 0.01), CFrame.new(-1.0 + i * 0.33, h + hh * 0.7, -0.225), W)
	end
end
do -- 10. long : rangee de peluches (2,35 x 0,5)
	local m, h = newProp("PlushRow", Vector3.new(2.35, 0.04, 0.5), DARK)
	local cols = { PINK, BLUE, YELLOW, MINT, LILAC }
	for i = 0, 4 do
		local x = -0.92 + i * 0.46
		ball(m, "Body" .. i, 0.36, CFrame.new(x, h + 0.2, 0), cols[i + 1], { mat = Enum.Material.Fabric })
		ball(m, "Head" .. i, 0.28, CFrame.new(x, h + 0.5, 0), cols[i + 1], { mat = Enum.Material.Fabric })
		for s = -1, 1, 2 do ball(m, "Ear" .. i .. s, 0.1, CFrame.new(x + s * 0.1, h + 0.64, 0), cols[i + 1], { mat = Enum.Material.Fabric }) end
		p(m, "Eyes" .. i, Vector3.new(0.14, 0.04, 0.01), CFrame.new(x, h + 0.53, -0.14), DARK)
	end
end

return report({ "Confiserie", "MagasinDeJouets" })
