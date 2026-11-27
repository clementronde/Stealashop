--!nocheck
-- Lot 1 des 25 tapis (Clement 26/11 : « enchaine sur les 24 autres », par lots de 5) : Base, Cardboard, Bronze, Silver,
-- Supermarket, les 5 paliers sous le Gold. Chacun plus riche que le precedent. A lancer en Edit APRES le contenu de
-- tools/clement/tapis_lib.luau (colle en tete). Modeles dans ServerStorage/Previews/TREADMILLS/PLOT_Treadmill_<Theme>_v3.
-- References (planche des 18) : 11 (bleu neon, montants fins) pour Base ; 12 et 13 (bois, portique simple) pour Cardboard ;
-- 5 et 10 (colonnes, medaillon) pour Bronze et Silver ; 15 et 18 (decor du theme sur les bords) pour Supermarket.
local made = {}
local UP = CFrame.Angles(0, 0, math.rad(90))
local FACE = CFrame.Angles(0, math.rad(90), 0)

-- ===== 1. BASE : tapis de sport gris clair, montants fins, accent bleu =====
do
	local m, a = chassis("Base", { frame = "#C9CED6", frameVar = "Tapis_MetalBrosse", rail = "#B7BBC3", railVar = "Tapis_MetalBrosse",
		trim = "#3D3F45", glow = "#3FA9FF", belt = "#FFFFFF" })
	for side = -1, 1, 2 do
		local x = side * 3.25
		a.box("Columns", "Post" .. side, x - 0.25, x + 0.25, 0.62, 5.6, -4.2, -3.7, "#B7BBC3", { var = "Tapis_MetalBrosse" })
		a.box("Trim", "PostCap" .. side, x - 0.32, x + 0.32, 5.6, 5.8, -4.27, -3.63, "#3D3F45")
		a.box("Trim", "PostFoot" .. side, x - 0.4, x + 0.4, 0, 0.62, -4.4, -3.5, "#3D3F45")
		a.glow("PostGlow" .. side, x - 0.05, x + 0.05, 1.0, 5.4, -3.69, -3.66)
		a.box("Trim", "Handrail" .. side, math.min(side * 2.3, side * 3.0), math.max(side * 2.3, side * 3.0), 4.0, 4.25, -3.6, -3.35, "#3D3F45")
	end
	a.box("Trim", "TopBar", -3.6, 3.6, 5.8, 6.2, -4.2, -3.7, "#3D3F45")
	a.box("Decor", "SignPanel", -1.4, 1.4, 6.2, 6.9, -4.1, -3.8, "#B7BBC3", { var = "Tapis_MetalBrosse" })
	a.glow("SignGlow", -1.1, 1.1, 6.45, 6.6, -3.8, -3.77)
	a.glow("TopBarGlow", -3.3, 3.3, 5.75, 5.8, -3.69, -3.66)
	-- serviette sur la main courante droite, gourde dans son support a gauche, tapis de sol en caoutchouc
	a.box("Decor", "Towel", 2.35, 2.95, 3.55, 4.3, -3.62, -3.33, "#3FA9FF")
	a.box("Decor", "TowelStripe", 2.35, 2.95, 3.75, 3.85, -3.63, -3.32, "#FFFFFF")
	a.box("Decor", "BottleHolder", -2.2, -1.7, 3.4, 3.6, -3.1, -2.6, "#3D3F45")
	a.cyl("Decor", "Bottle", 0.9, 0.38, CFrame.new(-1.95, 4.0, -2.85) * UP, "#3FA9FF", { transp = 0.15 })
	a.cyl("Decor", "BottleCap", 0.15, 0.3, CFrame.new(-1.95, 4.52, -2.85) * UP, "#F4F4F0")
	a.box("Decor", "FloorMat", -4.6, 4.6, 0, 0.05, -5.0, 5.9, "#2B2F36", { var = "Tapis_BandeCaoutchouc" })
	table.insert(made, m)
end

-- ===== 2. CARDBOARD : portique de cartons empiles, scotch, etiquette FRAGILE =====
do
	local KRAFT, KRAFT2, KRAFT3, TAPE = "#D7A066", "#C28A52", "#E0AE72", "#A8743A"
	local m, a = chassis("Cardboard", { frame = KRAFT, rail = KRAFT2,
		trim = "#8B5E34", glow = "#FFF1C9", belt = "#F3E2B8" })
	local function carton(name, cx, cy, cz, sx, sy, sz, rot, col)
		local cf = CFrame.new(cx, cy, cz) * CFrame.Angles(0, math.rad(rot), 0)
		a.p("Decor", name, Vector3.new(sx, sy, sz), cf, col) -- lisse : Tapis_Carton se lisait comme du bois (captures du 26/11)
		a.p("Decor", name .. "_Edge", Vector3.new(sx + 0.02, 0.08, sz + 0.02), cf * CFrame.new(0, -sy / 2 + 0.04, 0), "#9C6A3A")
		a.p("Decor", name .. "_Tape", Vector3.new(sx * 0.18, sy + 0.04, sz + 0.04), cf, TAPE, { reflect = 0.08 })
		a.p("Decor", name .. "_Flap", Vector3.new(sx + 0.03, 0.06, sz * 0.18), cf * CFrame.new(0, sy / 2, 0), TAPE, { reflect = 0.08 })
	end
	for side = -1, 1, 2 do
		local x = side * 3.75
		carton("Stack" .. side .. "_1", x, 0.95, -3.95, 1.6, 1.9, 1.5, side * 4, KRAFT)
		carton("Stack" .. side .. "_2", x + side * 0.05, 2.8, -3.95, 1.45, 1.8, 1.4, -side * 6, KRAFT2)
		carton("Stack" .. side .. "_3", x - side * 0.05, 4.6, -3.95, 1.5, 1.8, 1.45, side * 5, KRAFT3)
		a.p("Decor", "UpArrow" .. side, Vector3.new(0.16, 0.6, 0.03), CFrame.new(x, 2.75, -3.2), "#3B2A1C")
		a.p("Decor", "UpArrowHead" .. side, Vector3.new(0.42, 0.42, 0.03), CFrame.new(x, 3.15, -3.2) * CFrame.Angles(0, 0, math.rad(45)), "#3B2A1C")
		-- cartons aux coins arriere
		carton("Rear" .. side, side * 4.7, 0.55, 4.5, 1.2, 1.1, 1.2, side * 12, KRAFT2)
		carton("RearTop" .. side, side * 4.65, 1.5, 4.45, 0.8, 0.8, 0.8, -side * 9, KRAFT3)
	end
	carton("Lintel", 0, 6.15, -3.95, 9.2, 1.3, 1.6, 0, KRAFT)
	a.box("Decor", "FragileLabel", -1.2, 1.2, 5.8, 6.5, -3.2, -3.14, "#D8343C")
	a.box("Decor", "FragileGlass", -0.95, -0.7, 5.9, 6.4, -3.14, -3.12, "#FFFFFF")
	a.box("Decor", "FragileBar", -0.4, 0.95, 6.1, 6.2, -3.14, -3.12, "#FFFFFF")
	a.cyl("Decor", "TapeRoll", 0.35, 0.8, CFrame.new(4.65, 2.08, 4.45) * UP, "#B98345")
	a.cyl("Decor", "TapeCore", 0.37, 0.4, CFrame.new(4.65, 2.08, 4.45) * UP, "#8A6B45")
	fxPoint(a, "CardboardBits", Vector3.new(0, 6.9, -3.95))
	table.insert(made, m)
end

-- ===== 3. BRONZE : bronze patine, piliers a rivets, grand medaillon a ruban =====
do
	local BR, BR2, BRD = "#C27C3E", "#B5733A", "#7A4A22"
	local m, a = chassis("Bronze", { frame = BR, frameVar = "Tapis_OrTenons", rail = BR2, railVar = "Tapis_MetalBrosse",
		trim = BRD, trimVar = "Tapis_MetalBrosse", glow = "#FF9A3C", belt = "#FFB070" })
	for side = -1, 1, 2 do
		local x0, x1 = math.min(side * 3.0, side * 4.4), math.max(side * 3.0, side * 4.4)
		a.box("Trim", "PillarBase" .. side, x0 - 0.15, x1 + 0.15, 0, 0.8, a.PZ0 - 0.15, a.PZ1 + 0.15, BRD, { var = "Tapis_MetalBrosse" })
		a.box("Columns", "Pillar" .. side, x0, x1, 0.8, 7.0, a.PZ0, a.PZ1, BR2, { var = "Tapis_MetalBrosse" })
		for _, y in { 2.2, 4.4, 6.4 } do
			a.box("Trim", "Band" .. side .. "_" .. y, x0 - 0.08, x1 + 0.08, y, y + 0.25, a.PZ0 - 0.08, a.PZ1 + 0.08, BRD, { var = "Tapis_MetalBrosse" })
			for k = -1, 1 do a.ball("Trim", "Rivet", 0.12, CFrame.new((x0 + x1) / 2 + k * 0.45, y + 0.125, a.PZ1 + 0.09), "#E3A35E", { reflect = 0.1 }) end
		end
		a.glow("PillarGlow" .. side, (x0 + x1) / 2 - 0.06, (x0 + x1) / 2 + 0.06, 1.0, 6.2, a.PZ1, a.PZ1 + 0.05)
	end
	a.box("Trim", "Lintel", -4.6, 4.6, 7.0, 7.8, a.PZ0 - 0.2, a.PZ1 + 0.2, BR, { var = "Tapis_OrTenons" })
	a.box("Trim", "LintelBand", -4.7, 4.7, 6.85, 7.05, a.PZ0 - 0.25, a.PZ1 + 0.25, BRD, { var = "Tapis_MetalBrosse" })
	-- medaillon de 3e place : disque, disque interieur, ruban rouge et bleu
	local med = CFrame.new(0, 8.6, -3.95)
	a.cyl("Decor", "Medal", 0.3, 1.7, med * FACE, BR, { var = "Tapis_MetalBrosse" })
	a.cyl("Decor", "MedalCore", 0.36, 1.1, med * FACE, "#E3A35E", { reflect = 0.12 })
	a.cyl("Glow", "MedalRing", 0.1, 1.85, med * CFrame.new(0, 0, 0.18) * FACE, "#FF9A3C", { mat = Enum.Material.Neon })
	for side = -1, 1, 2 do
		a.p("Decor", "Ribbon" .. side, Vector3.new(0.45, 1.1, 0.06), med * CFrame.new(side * 0.35, -0.95, 0.12) * CFrame.Angles(0, 0, math.rad(side * 18)), if side < 0 then "#D8343C" else "#2D5BD7")
	end
	-- deux bornes basses a l'arriere
	for side = -1, 1, 2 do
		a.box("Columns", "RearPost" .. side, side * 4.45, side * 5.15, 0, 2.2, 4.1, 4.8, BR2, { var = "Tapis_MetalBrosse" })
		a.box("Trim", "RearCap" .. side, side * 4.35, side * 5.25, 2.2, 2.45, 4.0, 4.9, BRD, { var = "Tapis_MetalBrosse" })
		a.ball("Decor", "RearOrb" .. side, 0.5, CFrame.new(side * 4.8, 2.7, 4.45), "#E3A35E", { reflect = 0.12 })
	end
	fxPoint(a, "MedalCenter", Vector3.new(0, 8.6, -3.95))
	table.insert(made, m)
end

-- ===== 4. SILVER : argent et blanc, portique haut, etoile, orbes =====
do
	local AG, AG2, AGD = "#E3E7EE", "#C9CED6", "#8D96A3"
	local m, a = chassis("Silver", { frame = AG, frameVar = "Tapis_OrTenons", rail = AG2, railVar = "Tapis_OrPlaque",
		trim = AGD, trimVar = "Tapis_MetalBrosse", glow = "#9BE8FF", belt = "#E6FBFF" })
	for side = -1, 1, 2 do
		local x0, x1 = math.min(side * 3.0, side * 4.5), math.max(side * 3.0, side * 4.5)
		local cx = (x0 + x1) / 2
		a.box("Trim", "PillarBase" .. side, x0 - 0.2, x1 + 0.2, 0, 0.9, a.PZ0 - 0.2, a.PZ1 + 0.2, AGD, { var = "Tapis_MetalBrosse" })
		a.box("Columns", "Pillar" .. side, x0, x1, 0.9, 7.6, a.PZ0, a.PZ1, "#F4F6FA", { var = "Tapis_MarbreVeine" })
		a.box("Trim", "Capital" .. side, x0 - 0.18, x1 + 0.18, 7.2, 7.6, a.PZ0 - 0.18, a.PZ1 + 0.18, AG2, { var = "Tapis_OrPlaque" })
		for _, y in { 2.6, 5.0 } do a.box("Trim", "Band" .. side .. "_" .. y, x0 - 0.08, x1 + 0.08, y, y + 0.3, a.PZ0 - 0.08, a.PZ1 + 0.08, AG2, { var = "Tapis_OrPlaque" }) end
		a.box("Trim", "RuneFrame" .. side, cx - 0.42, cx + 0.42, 1.2, 7.1, a.PZ1 - 0.02, a.PZ1 + 0.03, AG2, { var = "Tapis_OrPlaque" })
		a.glow("Rune" .. side .. "_1", cx - 0.1, cx + 0.1, 1.4, 3.4, a.PZ1, a.PZ1 + 0.06)
		a.glow("Rune" .. side .. "_2", cx - 0.1, cx + 0.1, 3.8, 6.9, a.PZ1, a.PZ1 + 0.06)
		a.box("Trim", "Handrail" .. side, math.min(side * 2.3, side * 3.0), math.max(side * 2.3, side * 3.0), 4.0, 4.3, -3.6, -3.3, AGD, { var = "Tapis_MetalBrosse" })
		-- colonnettes arriere avec orbe
		a.box("Trim", "RearBase" .. side, side * 4.0, side * 5.4, 0, 0.5, 3.7, 5.1, AGD, { var = "Tapis_MetalBrosse" })
		a.cyl("Columns", "RearColumn" .. side, 3.0, 0.9, CFrame.new(side * 4.7, 2.0, 4.4) * UP, "#F4F6FA", { var = "Tapis_MarbreVeine" })
		a.box("Trim", "RearCap" .. side, side * 4.1, side * 5.3, 3.5, 3.8, 3.8, 5.0, AG2, { var = "Tapis_OrPlaque" })
		a.ball("Glow", "RearOrb" .. side, 0.55, CFrame.new(side * 4.7, 4.15, 4.4), "#9BE8FF", { mat = Enum.Material.Neon })
	end
	a.box("Trim", "Lintel", -4.9, 4.9, 7.6, 8.5, a.PZ0 - 0.25, a.PZ1 + 0.25, AG, { var = "Tapis_OrTenons" })
	a.glow("LintelGlow", -3.0, 3.0, 7.36, 7.45, a.PZ0, a.PZ1)
	for side = -1, 1, 2 do a.glow("ArchEdge" .. side, math.min(side * 3.0, side * 3.12), math.max(side * 3.0, side * 3.12), 0.9, 7.45, a.PZ1, a.PZ1 + 0.06) end
	-- etoile a 8 branches (deux carres tournes) sur un disque
	local star = CFrame.new(0, 9.15, -3.95)
	a.cyl("Decor", "StarDisc", 0.3, 1.6, star * FACE, AG2, { var = "Tapis_OrPlaque" })
	a.p("Decor", "StarA", Vector3.new(1.0, 1.0, 0.4), star * CFrame.Angles(0, 0, math.rad(45)), "#F4F6FA", { reflect = 0.15 })
	a.p("Decor", "StarB", Vector3.new(1.0, 1.0, 0.42), star, "#F4F6FA", { reflect = 0.15 })
	a.cyl("Glow", "StarRing", 0.1, 1.75, star * CFrame.new(0, 0, 0.2) * FACE, "#9BE8FF", { mat = Enum.Material.Neon })
	fxPoint(a, "StarCenter", Vector3.new(0, 9.15, -3.95))
	table.insert(made, m)
end

-- ===== 5. SUPERMARKET : caisse de supermarche, scanner, panneau OPEN, caddie, etiquettes de prix =====
do
	local W, RED, RED2, GREEN, YEL = "#F4F4F0", "#D8343C", "#A8232C", "#3FD46A", "#F3D35A"
	local m, a = chassis("Supermarket", { frame = W, rail = "#C9CED6", railVar = "Tapis_MetalBrosse",
		trim = RED, glow = "#FF4B4B", belt = "#F2F2F2" })
	-- portique de caisse rouge et blanc
	for side = -1, 1, 2 do
		local x0, x1 = math.min(side * 3.0, side * 4.4), math.max(side * 3.0, side * 4.4)
		a.box("Trim", "PillarBase" .. side, x0 - 0.15, x1 + 0.15, 0, 0.7, a.PZ0 - 0.15, a.PZ1 + 0.15, "#3D3F45")
		a.box("Columns", "Pillar" .. side, x0, x1, 0.7, 7.2, a.PZ0, a.PZ1, W)
		for k = 0, 2 do a.box("Trim", "Stripe" .. side .. "_" .. k, x0 - 0.04, x1 + 0.04, 1.5 + k * 1.9, 2.1 + k * 1.9, a.PZ0 - 0.04, a.PZ1 + 0.04, RED) end
	end
	a.box("Trim", "Lintel", -4.6, 4.6, 7.2, 8.4, a.PZ0 - 0.2, a.PZ1 + 0.2, RED)
	a.box("Trim", "LintelTrim", -4.7, 4.7, 7.05, 7.25, a.PZ0 - 0.25, a.PZ1 + 0.25, RED2)
	-- panneau lumineux « caisse ouverte » : chiffre de caisse et voyant vert
	a.box("Decor", "LaneSign", -1.1, 1.1, 8.4, 9.6, -4.1, -3.8, W)
	a.glow("LaneNumber", -0.15, 0.15, 8.6, 9.4, -3.8, -3.77, GREEN)
	a.glow("LaneTop", -1.0, 1.0, 9.45, 9.55, -3.8, -3.77, GREEN)
	for side = -1, 1, 2 do a.glow("Open" .. side, side * 0.5 - 0.18, side * 0.5 + 0.18, 8.8, 9.2, -3.8, -3.77, GREEN) end
	-- scanner sur la console : vitre et laser rouge
	a.box("Decor", "ScannerBody", -1.0, 1.0, 4.45, 4.75, -3.8, -3.1, "#3D3F45")
	a.box("Decor", "ScannerGlass", -0.8, 0.8, 4.75, 4.78, -3.7, -3.2, "#9AA3AF", { mat = Enum.Material.Glass, transp = 0.3 })
	a.glow("ScannerLaser", -0.75, 0.75, 4.79, 4.81, -3.47, -3.43, "#FF2A2A")
	fxPoint(a, "ScannerLight", Vector3.new(0, 4.85, -3.45))
	-- etiquettes de prix jaunes qui pendent du linteau
	for i, x in { -2.2, -0.9, 0.9, 2.2 } do
		a.box("Decor", "TagString" .. i, x - 0.02, x + 0.02, 6.5, 7.05, -3.1, -3.06, "#3D3F45")
		a.p("Decor", "PriceTag" .. i, Vector3.new(0.7, 0.45, 0.04), CFrame.new(x, 6.25, -3.08) * CFrame.Angles(0, 0, math.rad(i % 2 == 0 and 6 or -6)), YEL)
		a.box("Decor", "PriceMark" .. i, x - 0.22, x + 0.22, 6.2, 6.3, -3.11, -3.1, RED)
	end
	-- caddie a l'arriere droit (hors de la bande)
	local cart = CFrame.new(4.85, 0, 3.6) * CFrame.Angles(0, math.rad(-15), 0)
	local STEEL = "#C9CED6"
	a.p("Decor", "CartBottom", Vector3.new(1.0, 0.06, 1.5), cart * CFrame.new(0, 0.55, 0), STEEL, { var = "Tapis_MetalBrosse" })
	for side = -1, 1, 2 do
		a.p("Decor", "CartSide" .. side, Vector3.new(0.05, 0.75, 1.5), cart * CFrame.new(side * 0.5, 0.95, 0), STEEL, { var = "Tapis_MetalBrosse" })
		a.p("Decor", "CartSideBar" .. side, Vector3.new(0.06, 0.06, 1.5), cart * CFrame.new(side * 0.5, 1.32, 0), "#8D96A3")
	end
	a.p("Decor", "CartFront", Vector3.new(1.0, 0.75, 0.05), cart * CFrame.new(0, 0.95, -0.75), STEEL, { var = "Tapis_MetalBrosse" })
	a.p("Decor", "CartBack", Vector3.new(1.0, 0.75, 0.05), cart * CFrame.new(0, 0.95, 0.75), STEEL, { var = "Tapis_MetalBrosse" })
	a.p("Decor", "CartHandle", Vector3.new(1.1, 0.1, 0.1), cart * CFrame.new(0, 1.45, 0.95), RED)
	for k, q in { { -0.4, -0.6 }, { 0.4, -0.6 }, { -0.4, 0.6 }, { 0.4, 0.6 } } do
		a.cyl("Decor", "Wheel" .. k, 0.08, 0.2, cart * CFrame.new(q[1], 0.1, q[2]), "#3D3F45")
		a.p("Decor", "Leg" .. k, Vector3.new(0.05, 0.4, 0.05), cart * CFrame.new(q[1], 0.35, q[2]), "#8D96A3")
	end
	-- courses dans le caddie
	a.p("Decor", "Bag", Vector3.new(0.5, 0.5, 0.4), cart * CFrame.new(-0.15, 0.85, 0.2), "#C9A36B")
	a.p("Decor", "Box1", Vector3.new(0.35, 0.45, 0.25), cart * CFrame.new(0.2, 0.82, -0.3), "#2D5BD7")
	a.cyl("Decor", "Bottle", 0.55, 0.16, cart * CFrame.new(0.25, 0.9, 0.35) * UP, GREEN)
	-- presentoir de friandises a gauche (bord de caisse)
	a.box("Decor", "CandyRack", -5.4, -4.2, 0, 1.6, 2.6, 4.6, RED)
	for k = 0, 2 do
		local cols = { "#2D5BD7", YEL, "#7B4FC9" }
		for j = 0, 1 do a.box("Decor", "Candy" .. k .. j, -4.25, -4.15, 0.25 + k * 0.45, 0.6 + k * 0.45, 2.8 + j * 0.9, 3.5 + j * 0.9, cols[(k + j) % 3 + 1]) end
	end
	-- separateur de caisse pose sur le longeron gauche
	a.box("Decor", "Divider", -3.45, -2.85, 1.4, 1.55, 0.2, 2.6, "#3D3F45")
	table.insert(made, m)
end

return summary(made)
