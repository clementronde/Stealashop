--!nocheck
-- Kits de produits de la zone 1 : Superette (on garde son interieur, ses cubes deviennent de vrais produits) et Kiosque.
-- A lancer en Edit APRES le contenu de tools/clement/kit_lib.luau (colle en tete), puis tools/clement/kits_fusion.luau
-- avec MAGASINS = { "Superette", "Kiosque" }. 10 produits par magasin, dont 2 longs.

local W, CREAM, DARK, RED, BLUE, YELLOW, GREEN, ORANGE = "#F7F5F0", "#F2E9D0", "#2B2F36", "#D8343C", "#2D5BD7", "#F3D35A", "#3FAE5A", "#F08A2B"
local SILVER, BROWN, PURPLE, PINK, TEAL = "#C9CED6", "#8A5A33", "#7B4FC9", "#F07AA8", "#2BB3A8"

-- canette : corps de couleur, bande claire, dessus argent
local function can(m, name, x, z, y, col)
	cyl(m, name, 0.36, 0.22, CFrame.new(x, y + 0.18, z) * UP, col)
	cyl(m, name .. "_Band", 0.1, 0.225, CFrame.new(x, y + 0.2, z) * UP, W)
	cyl(m, name .. "_Top", 0.03, 0.2, CFrame.new(x, y + 0.375, z) * UP, SILVER)
end
-- bouteille : corps, etiquette, goulot, bouchon
local function bottle(m, name, x, z, y, col, cap)
	cyl(m, name, 0.5, 0.2, CFrame.new(x, y + 0.25, z) * UP, col, { mat = Enum.Material.Glass, transp = 0.2 })
	cyl(m, name .. "_Label", 0.18, 0.205, CFrame.new(x, y + 0.24, z) * UP, W)
	cyl(m, name .. "_Neck", 0.14, 0.1, CFrame.new(x, y + 0.57, z) * UP, col, { mat = Enum.Material.Glass, transp = 0.2 })
	cyl(m, name .. "_Cap", 0.05, 0.11, CFrame.new(x, y + 0.66, z) * UP, cap)
end

-- ================= SUPERETTE =================
store(1, "Superette")
do -- 1. pack de 6 canettes sous film
	local m, h = newProp("SodaPack", Vector3.new(0.8, 0.04, 0.55), DARK)
	for i = 0, 5 do can(m, "Can_" .. i, -0.24 + (i % 3) * 0.24, -0.12 + math.floor(i / 3) * 0.24, h, RED) end
	p(m, "Handle", Vector3.new(0.3, 0.05, 0.08), CFrame.new(0, h + 0.42, 0), W)
end
do -- 2. sachet de chips gonfle
	local m, h = newProp("ChipsBag", Vector3.new(0.7, 0.04, 0.35), DARK)
	p(m, "Bag", Vector3.new(0.62, 0.8, 0.28), CFrame.new(0, h + 0.4, 0), YELLOW)
	p(m, "Crimp", Vector3.new(0.64, 0.06, 0.12), CFrame.new(0, h + 0.82, 0), ORANGE)
	ball(m, "Logo", 0.3, CFrame.new(0, h + 0.45, -0.12), RED)
	p(m, "Window", Vector3.new(0.3, 0.16, 0.02), CFrame.new(0, h + 0.2, -0.145), "#F6C35A")
end
do -- 3. boite de cereales
	local m, h = newProp("CerealBox", Vector3.new(0.7, 0.04, 0.3), DARK)
	p(m, "Box", Vector3.new(0.64, 0.95, 0.24), CFrame.new(0, h + 0.475, 0), BLUE)
	p(m, "Bowl", Vector3.new(0.36, 0.14, 0.02), CFrame.new(0, h + 0.3, -0.13), W)
	ball(m, "Flake1", 0.08, CFrame.new(-0.06, h + 0.4, -0.13), YELLOW)
	ball(m, "Flake2", 0.08, CFrame.new(0.07, h + 0.41, -0.13), ORANGE)
	p(m, "Title", Vector3.new(0.5, 0.14, 0.02), CFrame.new(0, h + 0.78, -0.13), YELLOW)
end
do -- 4. conserves empilees
	local m, h = newProp("CannedGoods", Vector3.new(0.8, 0.04, 0.55), DARK)
	local cols = { GREEN, ORANGE, RED }
	for i = 0, 2 do
		cyl(m, "Tin_" .. i, 0.3, 0.3, CFrame.new(-0.2 + i * 0.32, h + 0.15, 0) * UP, SILVER)
		cyl(m, "Label_" .. i, 0.2, 0.305, CFrame.new(-0.2 + i * 0.32, h + 0.15, 0) * UP, cols[i + 1])
	end
	cyl(m, "TinTop", 0.3, 0.3, CFrame.new(-0.04, h + 0.45, 0) * UP, SILVER)
	cyl(m, "LabelTop", 0.2, 0.305, CFrame.new(-0.04, h + 0.45, 0) * UP, GREEN)
end
do -- 5. brique de lait
	local m, h = newProp("MilkCarton", Vector3.new(0.5, 0.04, 0.5), DARK)
	p(m, "Carton", Vector3.new(0.38, 0.6, 0.38), CFrame.new(0, h + 0.3, 0), W)
	p(m, "Roof", Vector3.new(0.38, 0.14, 0.27), CFrame.new(0, h + 0.67, 0) * CFrame.Angles(math.rad(45), 0, 0), W)
	p(m, "Stripe", Vector3.new(0.39, 0.14, 0.39), CFrame.new(0, h + 0.35, 0), BLUE)
	p(m, "Cap", Vector3.new(0.08, 0.05, 0.08), CFrame.new(0.08, h + 0.76, 0), BLUE)
end
do -- 6. pack de bouteilles d'eau
	local m, h = newProp("WaterPack", Vector3.new(0.8, 0.04, 0.55), DARK)
	for i = 0, 3 do bottle(m, "Bottle_" .. i, -0.26 + (i % 2) * 0.24 + math.floor(i / 2) * 0.28, -0.12 + (i % 2) * 0.24, h, "#9ED8FF", BLUE) end
end
do -- 7. bouteille de jus
	local m, h = newProp("JuiceBottle", Vector3.new(0.45, 0.04, 0.45), DARK)
	bottle(m, "Juice", 0, 0, h, ORANGE, GREEN)
end
do -- 8. presentoir de barres chocolatees
	local m, h = newProp("CandyBarBox", Vector3.new(0.9, 0.04, 0.6), DARK)
	p(m, "Tray", Vector3.new(0.85, 0.2, 0.55), CFrame.new(0, h + 0.1, 0), RED)
	p(m, "Back", Vector3.new(0.85, 0.35, 0.05), CFrame.new(0, h + 0.3, 0.25), RED)
	p(m, "Banner", Vector3.new(0.6, 0.12, 0.02), CFrame.new(0, h + 0.38, 0.22), YELLOW)
	local cols = { PURPLE, BROWN, YELLOW, BLUE }
	for i = 0, 3 do p(m, "Bar_" .. i, Vector3.new(0.17, 0.06, 0.45), CFrame.new(-0.3 + i * 0.2, h + 0.23, -0.02) * CFrame.Angles(math.rad(-10), 0, 0), cols[i + 1]) end
end
do -- 9. long : rangee de bouteilles de soda (2,35 x 0,4)
	local m, h = newProp("SodaRow", Vector3.new(2.35, 0.04, 0.4), DARK)
	local cols = { "#3B1F12", GREEN, ORANGE, "#3B1F12", PURPLE, GREEN, ORANGE, "#3B1F12", RED }
	for i = 0, 8 do bottle(m, "Bottle_" .. i, -1.04 + i * 0.26, 0, h, cols[i + 1], RED) end
end
do -- 10. long : rangee de canettes (2,35 x 0,5)
	local m, h = newProp("CanRow", Vector3.new(2.35, 0.04, 0.5), DARK)
	local cols = { RED, BLUE, GREEN, YELLOW, PURPLE }
	for i = 0, 8 do
		can(m, "Can_" .. i, -1.04 + i * 0.26, -0.11, h, cols[i % 5 + 1])
		can(m, "CanB_" .. i, -1.04 + i * 0.26, 0.13, h, cols[(i + 2) % 5 + 1])
	end
end

-- ================= KIOSQUE =================
store(1, "Kiosque")
local function magazine(m, name, cf, col, accent)
	p(m, name, Vector3.new(0.5, 0.68, 0.03), cf, col)
	p(m, name .. "_Title", Vector3.new(0.42, 0.1, 0.01), cf * CFrame.new(0, 0.25, -0.02), W)
	p(m, name .. "_Pic", Vector3.new(0.3, 0.3, 0.01), cf * CFrame.new(0, -0.05, -0.02), accent)
end
do -- 1. pile de magazines
	local m, h = newProp("MagazineStack", Vector3.new(0.7, 0.04, 0.85), DARK)
	local cols = { RED, BLUE, PINK, GREEN, YELLOW }
	for i = 0, 4 do p(m, "Mag_" .. i, Vector3.new(0.55, 0.05, 0.72), CFrame.new(0, h + 0.025 + i * 0.05, 0) * CFrame.Angles(0, math.rad(i * 5 - 10), 0), cols[i + 1]) end
	p(m, "Cover", Vector3.new(0.4, 0.01, 0.3), CFrame.new(0, h + 0.255, -0.1), W)
end
do -- 2. paquet de journaux ficele
	local m, h = newProp("NewspaperBundle", Vector3.new(0.9, 0.04, 0.6), DARK)
	p(m, "Papers", Vector3.new(0.8, 0.35, 0.5), CFrame.new(0, h + 0.175, 0), "#E6E1D6")
	p(m, "Headline", Vector3.new(0.6, 0.08, 0.01), CFrame.new(0, h + 0.27, -0.255), DARK)
	p(m, "Photo", Vector3.new(0.25, 0.14, 0.01), CFrame.new(-0.18, h + 0.13, -0.255), "#9AA3AF")
	p(m, "StringX", Vector3.new(0.82, 0.37, 0.03), CFrame.new(0, h + 0.175, 0), BROWN)
	p(m, "StringZ", Vector3.new(0.03, 0.37, 0.52), CFrame.new(0, h + 0.175, 0), BROWN)
end
do -- 3. magazine debout sur un presentoir
	local m, h = newProp("MagazineStand", Vector3.new(0.7, 0.06, 0.4), SILVER)
	p(m, "Rack", Vector3.new(0.6, 0.05, 0.3), CFrame.new(0, h + 0.03, 0), SILVER)
	magazine(m, "Mag", CFrame.new(0, h + 0.4, 0.05) * CFrame.Angles(math.rad(-12), 0, 0), PURPLE, YELLOW)
end
do -- 4. pot de chewing-gums
	local m, h = newProp("GumJar", Vector3.new(0.55, 0.06, 0.55), RED)
	cyl(m, "Jar", 0.5, 0.42, CFrame.new(0, h + 0.25, 0) * UP, "#E8F6FF", { mat = Enum.Material.Glass, transp = 0.5 })
	cyl(m, "Lid", 0.08, 0.44, CFrame.new(0, h + 0.54, 0) * UP, RED)
	local rng = Random.new(11)
	local cols = { PINK, BLUE, YELLOW, GREEN, ORANGE }
	for i = 1, 12 do ball(m, "Gum_" .. i, 0.1, CFrame.new(rng:NextNumber(-0.12, 0.12), h + 0.08 + rng:NextNumber(0, 0.3), rng:NextNumber(-0.12, 0.12)), cols[i % 5 + 1]) end
end
do -- 5. boite de barres de cereales
	local m, h = newProp("SnackBox", Vector3.new(0.9, 0.04, 0.55), DARK)
	p(m, "Box", Vector3.new(0.85, 0.22, 0.5), CFrame.new(0, h + 0.11, 0), GREEN)
	p(m, "Flap", Vector3.new(0.85, 0.3, 0.04), CFrame.new(0, h + 0.33, 0.25), GREEN)
	for i = 0, 4 do p(m, "Snack_" .. i, Vector3.new(0.14, 0.06, 0.4), CFrame.new(-0.3 + i * 0.15, h + 0.25, 0), if i % 2 == 0 then ORANGE else YELLOW) end
end
do -- 6. bande dessinee sous plastique
	local m, h = newProp("ComicStack", Vector3.new(0.7, 0.04, 0.85), DARK)
	for i = 0, 2 do p(m, "Comic_" .. i, Vector3.new(0.55, 0.04, 0.75), CFrame.new(0, h + 0.02 + i * 0.04, 0) * CFrame.Angles(0, math.rad(i * 6 - 6), 0), if i % 2 == 0 then YELLOW else TEAL) end
	ball(m, "Hero", 0.22, CFrame.new(0.05, h + 0.19, -0.05), RED)
	p(m, "Bubble", Vector3.new(0.2, 0.01, 0.12), CFrame.new(-0.15, h + 0.135, 0.15), W)
end
do -- 7. boule a neige souvenir
	local m, h = newProp("SnowGlobe", Vector3.new(0.5, 0.15, 0.5), BROWN)
	ball(m, "Globe", 0.42, CFrame.new(0, h + 0.21, 0), "#E8F6FF", { mat = Enum.Material.Glass, transp = 0.55 })
	p(m, "Tower", Vector3.new(0.08, 0.26, 0.08), CFrame.new(0, h + 0.15, 0), BLUE)
	p(m, "Snow", Vector3.new(0.3, 0.04, 0.3), CFrame.new(0, h + 0.03, 0), W)
end
do -- 8. carte de porte-cles
	local m, h = newProp("KeychainCard", Vector3.new(0.6, 0.06, 0.3), SILVER)
	p(m, "Card", Vector3.new(0.5, 0.7, 0.03), CFrame.new(0, h + 0.4, 0) * CFrame.Angles(math.rad(-8), 0, 0), BLUE)
	local cols = { RED, YELLOW, GREEN, PINK }
	for i = 0, 3 do
		local x, y = -0.12 + (i % 2) * 0.24, h + 0.5 - math.floor(i / 2) * 0.28
		cyl(m, "Ring_" .. i, 0.02, 0.08, CFrame.new(x, y + 0.1, -0.04) * FACE, SILVER)
		ball(m, "Charm_" .. i, 0.12, CFrame.new(x, y, -0.05), cols[i + 1])
	end
end
do -- 9. long : rangee de magazines debout (2,35 x 0,4)
	local m, h = newProp("MagazineRow", Vector3.new(2.35, 0.06, 0.4), SILVER)
	local cols = { { RED, YELLOW }, { BLUE, PINK }, { GREEN, W }, { PURPLE, YELLOW } }
	for i = 0, 3 do magazine(m, "Mag_" .. i, CFrame.new(-0.85 + i * 0.57, h + 0.38, 0.05) * CFrame.Angles(math.rad(-12), 0, 0), cols[i + 1][1], cols[i + 1][2]) end
end
do -- 10. long : rangee de barres en vrac dans un bac (2,35 x 0,5)
	local m, h = newProp("SnackRow", Vector3.new(2.35, 0.05, 0.5), DARK)
	p(m, "Bin", Vector3.new(2.3, 0.2, 0.45), CFrame.new(0, h + 0.1, 0), RED)
	local cols = { PURPLE, BROWN, YELLOW, BLUE, GREEN, ORANGE }
	for i = 0, 11 do p(m, "Bar_" .. i, Vector3.new(0.16, 0.06, 0.38), CFrame.new(-1.02 + i * 0.185, h + 0.23, 0) * CFrame.Angles(math.rad(-12), 0, 0), cols[i % 6 + 1]) end
end

return report({ "Superette", "Kiosque" })
