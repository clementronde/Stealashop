--!nocheck
-- Kits de produits de la zone 3 (Electronique, Jeux video) et de l'Horlogerie (zone 4). A lancer en Edit APRES le contenu
-- de tools/clement/kit_lib.luau (colle en tete), puis tools/clement/kits_fusion.luau. Les ecrans et LED sont en Neon :
-- la fusion les garde a part (« Glow »). 10 produits par magasin, dont 2 longs.

local W, DARK, BLACK, RED, BLUE, YELLOW, GREEN, ORANGE = "#F7F5F0", "#2B2F36", "#17181C", "#D8343C", "#2D5BD7", "#F3D35A", "#3FAE5A", "#F08A2B"
local PURPLE, TEAL, SILVER, GOLD, BROWN, CREAM, CYAN = "#7B4FC9", "#2BB3A8", "#C9CED6", "#F5C842", "#8A5A33", "#F2E9D0", "#57E3FF"

local function box(m, name, size, cf, col, label)
	p(m, name, size, cf, col)
	if label then p(m, name .. "_Label", Vector3.new(size.X * 0.7, size.Y * 0.35, 0.01), cf * CFrame.new(0, size.Y * 0.1, -size.Z / 2 - 0.005), label) end
end

-- ================= ELECTRONIQUE =================
store(3, "Electronique")
do -- 1. smartphone sur son support
	local m, h = newProp("PhoneStand", Vector3.new(0.5, 0.06, 0.4), DARK)
	p(m, "Stand", Vector3.new(0.3, 0.2, 0.2), CFrame.new(0, h + 0.1, 0.05) * CFrame.Angles(math.rad(-20), 0, 0), SILVER)
	p(m, "Phone", Vector3.new(0.3, 0.58, 0.04), CFrame.new(0, h + 0.38, 0.0) * CFrame.Angles(math.rad(-15), 0, 0), BLACK)
	neon(m, "Screen", Vector3.new(0.26, 0.5, 0.01), CFrame.new(0, h + 0.38, -0.025) * CFrame.Angles(math.rad(-15), 0, 0), CYAN)
end
do -- 2. casque audio
	local m, h = newProp("Headphones", Vector3.new(0.6, 0.06, 0.4), DARK)
	p(m, "Band", Vector3.new(0.46, 0.08, 0.1), CFrame.new(0, h + 0.62, 0), BLACK)
	for s = -1, 1, 2 do
		p(m, "Arm" .. s, Vector3.new(0.06, 0.36, 0.08), CFrame.new(s * 0.22, h + 0.43, 0), BLACK)
		cyl(m, "Cup" .. s, 0.12, 0.26, CFrame.new(s * 0.22, h + 0.2, 0), RED)
	end
end
do -- 3. carton de console
	local m, h = newProp("ConsoleBox", Vector3.new(0.9, 0.04, 0.5), DARK)
	box(m, "Box", Vector3.new(0.85, 0.6, 0.42), CFrame.new(0, h + 0.3, 0), W, BLUE)
	p(m, "Console", Vector3.new(0.45, 0.12, 0.01), CFrame.new(0, h + 0.2, -0.215), BLACK)
end
do -- 4. ordinateur portable ouvert
	local m, h = newProp("Laptop", Vector3.new(0.9, 0.04, 0.7), DARK)
	p(m, "Bottom", Vector3.new(0.8, 0.05, 0.55), CFrame.new(0, h + 0.025, -0.05), SILVER)
	p(m, "Keys", Vector3.new(0.65, 0.01, 0.3), CFrame.new(0, h + 0.055, -0.08), DARK)
	p(m, "Lid", Vector3.new(0.8, 0.52, 0.04), CFrame.new(0, h + 0.29, 0.24) * CFrame.Angles(math.rad(-12), 0, 0), SILVER)
	neon(m, "Screen", Vector3.new(0.7, 0.42, 0.01), CFrame.new(0, h + 0.3, 0.215) * CFrame.Angles(math.rad(-12), 0, 0), "#7FB8FF")
end
do -- 5. enceinte avec LED
	local m, h = newProp("Speaker", Vector3.new(0.5, 0.04, 0.45), DARK)
	p(m, "Body", Vector3.new(0.42, 0.7, 0.38), CFrame.new(0, h + 0.35, 0), BLACK)
	cyl(m, "Woofer", 0.04, 0.3, CFrame.new(0, h + 0.25, -0.2) * FACE, DARK)
	cyl(m, "Tweeter", 0.04, 0.14, CFrame.new(0, h + 0.55, -0.2) * FACE, DARK)
	neon(m, "Ring", Vector3.new(0.02, 0.33, 0.33), CFrame.new(0, h + 0.25, -0.195) * FACE, PURPLE)
end
do -- 6. tablette dans sa boite
	local m, h = newProp("TabletBox", Vector3.new(0.8, 0.04, 0.3), DARK)
	box(m, "Box", Vector3.new(0.7, 0.85, 0.14), CFrame.new(0, h + 0.425, 0), W, nil)
	p(m, "Tablet", Vector3.new(0.5, 0.65, 0.01), CFrame.new(0, h + 0.43, -0.075), BLACK)
	neon(m, "Screen", Vector3.new(0.44, 0.58, 0.01), CFrame.new(0, h + 0.43, -0.085), "#FF9E5C")
end
do -- 7. appareil photo
	local m, h = newProp("Camera", Vector3.new(0.7, 0.04, 0.45), DARK)
	p(m, "Body", Vector3.new(0.55, 0.36, 0.25), CFrame.new(0, h + 0.18, 0.04), BLACK)
	cyl(m, "Lens", 0.25, 0.26, CFrame.new(0, h + 0.18, -0.15) * FACE, DARK)
	cyl(m, "Glass", 0.02, 0.2, CFrame.new(0, h + 0.18, -0.28) * FACE, "#3A5B9A", { reflect = 0.3 })
	p(m, "Flash", Vector3.new(0.12, 0.06, 0.06), CFrame.new(-0.16, h + 0.39, 0.04), SILVER)
	neon(m, "Led", Vector3.new(0.04, 0.04, 0.01), CFrame.new(0.2, h + 0.3, -0.085), RED)
end
do -- 8. montre connectee sur un coussin
	local m, h = newProp("SmartWatch", Vector3.new(0.55, 0.06, 0.45), DARK)
	p(m, "Pillow", Vector3.new(0.4, 0.2, 0.3), CFrame.new(0, h + 0.1, 0), "#3A404B", { mat = Enum.Material.Fabric })
	p(m, "Strap", Vector3.new(0.14, 0.03, 0.36), CFrame.new(0, h + 0.215, 0), TEAL)
	p(m, "Case", Vector3.new(0.2, 0.06, 0.22), CFrame.new(0, h + 0.25, 0), BLACK)
	neon(m, "Screen", Vector3.new(0.16, 0.01, 0.18), CFrame.new(0, h + 0.285, 0), GREEN)
end
do -- 9. long : rangee de televiseurs (2,35 x 0,4)
	local m, h = newProp("TVRow", Vector3.new(2.35, 0.04, 0.4), DARK)
	local cols = { "#7FB8FF", "#FF9E5C", "#9CE6C8" }
	for i = 0, 2 do
		local x = -0.78 + i * 0.78
		p(m, "Foot" .. i, Vector3.new(0.3, 0.04, 0.2), CFrame.new(x, h + 0.02, 0), BLACK)
		p(m, "Post" .. i, Vector3.new(0.06, 0.12, 0.06), CFrame.new(x, h + 0.1, 0.03), BLACK)
		p(m, "Frame" .. i, Vector3.new(0.72, 0.46, 0.05), CFrame.new(x, h + 0.39, 0.03), BLACK)
		neon(m, "Screen" .. i, Vector3.new(0.66, 0.4, 0.01), CFrame.new(x, h + 0.39, 0.0), cols[i + 1])
	end
end
do -- 10. long : rangee de boites de casques (2,35 x 0,4)
	local m, h = newProp("BoxRow", Vector3.new(2.35, 0.04, 0.4), DARK)
	local cols = { RED, BLUE, BLACK, GREEN, PURPLE, ORANGE }
	for i = 0, 5 do box(m, "Box" .. i, Vector3.new(0.34, 0.5, 0.32), CFrame.new(-0.95 + i * 0.38, h + 0.25, 0), cols[i + 1], W) end
end

-- ================= JEUX VIDEO =================
store(3, "JeuxVideo")
local function cartridge(m, name, cf, col)
	p(m, name, Vector3.new(0.3, 0.36, 0.06), cf, col)
	p(m, name .. "_Label", Vector3.new(0.24, 0.2, 0.01), cf * CFrame.new(0, 0.04, -0.035), W)
end
do -- 1. manette sur un socle
	local m, h = newProp("Gamepad", Vector3.new(0.7, 0.08, 0.5), DARK)
	p(m, "Body", Vector3.new(0.5, 0.1, 0.26), CFrame.new(0, h + 0.15, 0) * CFrame.Angles(math.rad(-20), 0, 0), BLACK)
	for s = -1, 1, 2 do ball(m, "Grip" .. s, 0.2, CFrame.new(s * 0.22, h + 0.12, 0.06), BLACK) end
	neon(m, "Light", Vector3.new(0.16, 0.02, 0.04), CFrame.new(0, h + 0.2, 0.1) * CFrame.Angles(math.rad(-20), 0, 0), BLUE)
	for i, c in { RED, GREEN, YELLOW, BLUE } do ball(m, "Btn" .. i, 0.05, CFrame.new(0.13 + (i % 2) * 0.05, h + 0.22, -0.02 + math.floor((i - 1) / 2) * 0.05), c) end
end
do -- 2. boite de jeu debout
	local m, h = newProp("GameCase", Vector3.new(0.5, 0.04, 0.3), DARK)
	p(m, "Case", Vector3.new(0.4, 0.55, 0.06), CFrame.new(0, h + 0.28, 0) * CFrame.Angles(math.rad(-8), 0, 0), BLUE)
	p(m, "Cover", Vector3.new(0.34, 0.4, 0.01), CFrame.new(0, h + 0.26, -0.035) * CFrame.Angles(math.rad(-8), 0, 0), ORANGE)
	ball(m, "Hero", 0.14, CFrame.new(0, h + 0.3, -0.05), YELLOW)
end
do -- 3. console de salon
	local m, h = newProp("Console", Vector3.new(0.9, 0.04, 0.6), DARK)
	p(m, "Body", Vector3.new(0.8, 0.14, 0.5), CFrame.new(0, h + 0.07, 0), W)
	p(m, "Stripe", Vector3.new(0.8, 0.02, 0.06), CFrame.new(0, h + 0.13, -0.22), BLACK)
	neon(m, "Power", Vector3.new(0.12, 0.02, 0.02), CFrame.new(0.28, h + 0.1, -0.255), CYAN)
end
do -- 4. casque de realite virtuelle
	local m, h = newProp("VRHeadset", Vector3.new(0.7, 0.06, 0.45), DARK)
	p(m, "Visor", Vector3.new(0.5, 0.26, 0.24), CFrame.new(0, h + 0.2, -0.02), W)
	neon(m, "Front", Vector3.new(0.44, 0.18, 0.01), CFrame.new(0, h + 0.2, -0.145), PURPLE)
	p(m, "Strap", Vector3.new(0.56, 0.08, 0.3), CFrame.new(0, h + 0.2, 0.12), BLACK)
end
do -- 5. pile de cartouches
	local m, h = newProp("CartridgeStack", Vector3.new(0.6, 0.04, 0.4), DARK)
	local cols = { RED, GREEN, BLUE }
	for i = 0, 2 do cartridge(m, "Cart" .. i, CFrame.new(-0.16 + i * 0.16, h + 0.18, 0.05 - i * 0.05) * CFrame.Angles(math.rad(-10), math.rad(i * 8 - 8), 0), cols[i + 1]) end
end
do -- 6. figurine de personnage
	local m, h = newProp("Figurine", Vector3.new(0.5, 0.12, 0.5), BLACK)
	p(m, "Legs", Vector3.new(0.18, 0.2, 0.12), CFrame.new(0, h + 0.1, 0), BLUE)
	p(m, "Torso", Vector3.new(0.26, 0.22, 0.14), CFrame.new(0, h + 0.31, 0), RED)
	p(m, "Head", Vector3.new(0.18, 0.18, 0.16), CFrame.new(0, h + 0.51, 0), "#F2CFA8")
	p(m, "Cap", Vector3.new(0.2, 0.06, 0.2), CFrame.new(0, h + 0.62, -0.02), RED)
	p(m, "Sword", Vector3.new(0.04, 0.4, 0.04), CFrame.new(0.18, h + 0.36, -0.04) * CFrame.Angles(0, 0, math.rad(-20)), SILVER)
end
do -- 7. carte cadeau sur presentoir
	local m, h = newProp("GiftCardStand", Vector3.new(0.6, 0.06, 0.3), SILVER)
	local cols = { GREEN, PURPLE, ORANGE }
	for i = 0, 2 do p(m, "Card" .. i, Vector3.new(0.16, 0.26, 0.02), CFrame.new(-0.18 + i * 0.18, h + 0.18, 0) * CFrame.Angles(math.rad(-12), 0, 0), cols[i + 1]) end
	p(m, "Header", Vector3.new(0.56, 0.12, 0.02), CFrame.new(0, h + 0.4, 0.04), BLACK)
	neon(m, "Sign", Vector3.new(0.46, 0.05, 0.01), CFrame.new(0, h + 0.4, 0.025), YELLOW)
end
do -- 8. borne d'arcade miniature
	local m, h = newProp("MiniArcade", Vector3.new(0.5, 0.04, 0.5), DARK)
	p(m, "Cabinet", Vector3.new(0.4, 0.9, 0.36), CFrame.new(0, h + 0.45, 0.04), PURPLE)
	p(m, "Marquee", Vector3.new(0.4, 0.12, 0.06), CFrame.new(0, h + 0.85, -0.16), YELLOW)
	neon(m, "Screen", Vector3.new(0.3, 0.24, 0.01), CFrame.new(0, h + 0.62, -0.145), CYAN)
	p(m, "Panel", Vector3.new(0.4, 0.06, 0.16), CFrame.new(0, h + 0.42, -0.2) * CFrame.Angles(math.rad(20), 0, 0), BLACK)
	ball(m, "Stick", 0.07, CFrame.new(-0.08, h + 0.48, -0.22), RED)
end
do -- 9. long : rangee de boites de jeux (2,35 x 0,3)
	local m, h = newProp("GameCaseRow", Vector3.new(2.35, 0.04, 0.3), DARK)
	local cols = { { BLUE, ORANGE }, { RED, YELLOW }, { GREEN, W }, { PURPLE, CYAN }, { BLACK, RED }, { TEAL, YELLOW } }
	for i = 0, 5 do
		local cf = CFrame.new(-0.95 + i * 0.38, h + 0.28, 0) * CFrame.Angles(math.rad(-8), 0, 0)
		p(m, "Case" .. i, Vector3.new(0.34, 0.55, 0.06), cf, cols[i + 1][1])
		p(m, "Cover" .. i, Vector3.new(0.28, 0.38, 0.01), cf * CFrame.new(0, -0.02, -0.035), cols[i + 1][2])
	end
end
do -- 10. long : rangee de manettes de couleur (2,35 x 0,5)
	local m, h = newProp("GamepadRow", Vector3.new(2.35, 0.08, 0.5), DARK)
	local cols = { BLACK, W, RED, BLUE }
	for i = 0, 3 do
		local x = -0.84 + i * 0.56
		p(m, "Body" .. i, Vector3.new(0.4, 0.09, 0.22), CFrame.new(x, h + 0.13, 0) * CFrame.Angles(math.rad(-20), 0, 0), cols[i + 1])
		for s = -1, 1, 2 do ball(m, "Grip" .. i .. s, 0.17, CFrame.new(x + s * 0.18, h + 0.1, 0.05), cols[i + 1]) end
		neon(m, "Light" .. i, Vector3.new(0.12, 0.02, 0.03), CFrame.new(x, h + 0.18, 0.09) * CFrame.Angles(math.rad(-20), 0, 0), if i % 2 == 0 then CYAN else PURPLE)
	end
end

-- ================= HORLOGERIE =================
store(4, "Horlogerie")
local function dial(m, name, cf, d, col, rim)
	cyl(m, name .. "_Rim", 0.04, d + 0.05, cf * FACE, rim)
	cyl(m, name, 0.05, d, cf * FACE, col)
	p(m, name .. "_H", Vector3.new(0.025, d * 0.3, 0.01), cf * CFrame.new(0, d * 0.12, -0.03), BLACK)
	p(m, name .. "_M", Vector3.new(d * 0.4, 0.02, 0.01), cf * CFrame.new(d * 0.15, 0, -0.03), BLACK)
end
do -- 1. reveil a cloches
	local m, h = newProp("AlarmClock", Vector3.new(0.55, 0.04, 0.4), DARK)
	cyl(m, "Body", 0.2, 0.42, CFrame.new(0, h + 0.27, 0) * FACE, RED)
	dial(m, "Dial", CFrame.new(0, h + 0.27, -0.1), 0.34, CREAM, SILVER)
	for s = -1, 1, 2 do
		ball(m, "Bell" .. s, 0.16, CFrame.new(s * 0.15, h + 0.5, 0.02), SILVER)
		p(m, "Foot" .. s, Vector3.new(0.05, 0.1, 0.05), CFrame.new(s * 0.13, h + 0.05, 0), SILVER)
	end
end
do -- 2. montre a bracelet cuir sur coussin
	local m, h = newProp("LeatherWatch", Vector3.new(0.6, 0.06, 0.5), GOLD, true)
	p(m, "Pillow", Vector3.new(0.48, 0.22, 0.36), CFrame.new(0, h + 0.11, 0), "#7A162C", { mat = Enum.Material.Fabric })
	p(m, "Strap", Vector3.new(0.14, 0.03, 0.44), CFrame.new(0, h + 0.235, 0), BROWN)
	cyl(m, "Case", 0.08, 0.26, CFrame.new(0, h + 0.27, 0) * UP, GOLD, { reflect = 0.12 })
	cyl(m, "Face", 0.02, 0.21, CFrame.new(0, h + 0.315, 0) * UP, CREAM)
end
do -- 3. coucou
	local m, h = newProp("CuckooClock", Vector3.new(0.6, 0.04, 0.35), DARK)
	p(m, "House", Vector3.new(0.5, 0.5, 0.26), CFrame.new(0, h + 0.3, 0), BROWN)
	p(m, "RoofL", Vector3.new(0.34, 0.06, 0.32), CFrame.new(-0.13, h + 0.62, 0) * CFrame.Angles(0, 0, math.rad(35)), "#5E3B22")
	p(m, "RoofR", Vector3.new(0.34, 0.06, 0.32), CFrame.new(0.13, h + 0.62, 0) * CFrame.Angles(0, 0, math.rad(-35)), "#5E3B22")
	dial(m, "Dial", CFrame.new(0, h + 0.28, -0.14), 0.24, CREAM, GOLD)
	p(m, "Door", Vector3.new(0.1, 0.1, 0.02), CFrame.new(0, h + 0.47, -0.135), "#5E3B22")
	p(m, "Weight", Vector3.new(0.05, 0.12, 0.05), CFrame.new(0.1, h + 0.06, -0.05), GOLD)
end
do -- 4. sablier
	local m, h = newProp("Hourglass", Vector3.new(0.45, 0.06, 0.45), BROWN)
	cyl(m, "Top", 0.06, 0.42, CFrame.new(0, h + 0.7, 0) * UP, BROWN)
	for i = 0, 2 do local a = i / 3 * math.pi * 2 p(m, "Post" .. i, Vector3.new(0.04, 0.64, 0.04), CFrame.new(math.cos(a) * 0.16, h + 0.35, math.sin(a) * 0.16), BROWN) end
	ball(m, "BulbTop", 0.26, CFrame.new(0, h + 0.5, 0), "#E8F6FF", { mat = Enum.Material.Glass, transp = 0.5 })
	ball(m, "BulbBot", 0.26, CFrame.new(0, h + 0.2, 0), "#E8F6FF", { mat = Enum.Material.Glass, transp = 0.5 })
	ball(m, "Sand", 0.18, CFrame.new(0, h + 0.15, 0), YELLOW)
end
do -- 5. pendule murale ronde posee
	local m, h = newProp("WallClock", Vector3.new(0.75, 0.04, 0.3), DARK)
	dial(m, "Dial", CFrame.new(0, h + 0.38, 0.05) * CFrame.Angles(math.rad(-10), 0, 0), 0.66, W, BLACK)
end
do -- 6. montre a gousset ouverte
	local m, h = newProp("PocketWatchOpen", Vector3.new(0.55, 0.06, 0.5), "#181A40", true)
	cyl(m, "Case", 0.06, 0.3, CFrame.new(-0.06, h + 0.03, 0.02) * UP, GOLD, { reflect = 0.12 })
	cyl(m, "Face", 0.02, 0.25, CFrame.new(-0.06, h + 0.065, 0.02) * UP, CREAM)
	cyl(m, "Lid", 0.03, 0.3, CFrame.new(0.15, h + 0.12, 0.02) * CFrame.Angles(0, 0, math.rad(70)), GOLD)
	for i = 0, 5 do p(m, "Chain" .. i, Vector3.new(0.05, 0.03, 0.03), CFrame.new(-0.06 + math.cos(i * 0.6) * 0.18, h + 0.02, -0.12 - i * 0.03), GOLD) end
end
do -- 7. horloge de table a balancier
	local m, h = newProp("MantelPendulum", Vector3.new(0.55, 0.06, 0.35), BROWN)
	p(m, "Case", Vector3.new(0.45, 0.85, 0.28), CFrame.new(0, h + 0.425, 0), BROWN)
	dial(m, "Dial", CFrame.new(0, h + 0.65, -0.15), 0.3, CREAM, GOLD)
	p(m, "Window", Vector3.new(0.3, 0.35, 0.01), CFrame.new(0, h + 0.25, -0.145), "#E8F6FF", { mat = Enum.Material.Glass, transp = 0.5 })
	p(m, "Rod", Vector3.new(0.02, 0.25, 0.02), CFrame.new(0, h + 0.3, -0.12), GOLD)
	cyl(m, "Bob", 0.03, 0.1, CFrame.new(0, h + 0.17, -0.12) * FACE, GOLD)
end
do -- 8. ecrin de montres (3 montres)
	local m, h = newProp("WatchCase", Vector3.new(1.0, 0.04, 0.6), DARK)
	p(m, "Case", Vector3.new(0.92, 0.16, 0.52), CFrame.new(0, h + 0.08, 0), BLACK)
	p(m, "Lining", Vector3.new(0.84, 0.02, 0.44), CFrame.new(0, h + 0.17, 0), "#E9D9B0", { mat = Enum.Material.Fabric })
	p(m, "Lid", Vector3.new(0.92, 0.05, 0.52), CFrame.new(0, h + 0.4, 0.29) * CFrame.Angles(math.rad(-75), 0, 0), BLACK)
	for i = -1, 1 do
		cyl(m, "Watch" .. i, 0.06, 0.18, CFrame.new(i * 0.28, h + 0.21, 0) * UP, if i == 0 then GOLD else SILVER, { reflect = 0.12 })
		cyl(m, "Face" .. i, 0.02, 0.14, CFrame.new(i * 0.28, h + 0.245, 0) * UP, if i == 0 then BLACK else CREAM)
	end
end
do -- 9. long : rangee de reveils (2,35 x 0,4)
	local m, h = newProp("ClockRow", Vector3.new(2.35, 0.04, 0.4), DARK)
	local cols = { RED, BLUE, GREEN, YELLOW, PURPLE }
	for i = 0, 4 do
		local x = -0.92 + i * 0.46
		cyl(m, "Body" .. i, 0.16, 0.34, CFrame.new(x, h + 0.2, 0) * FACE, cols[i + 1])
		dial(m, "Dial" .. i, CFrame.new(x, h + 0.2, -0.08), 0.27, CREAM, SILVER)
		ball(m, "Bell" .. i, 0.12, CFrame.new(x, h + 0.42, 0), SILVER)
	end
end
do -- 10. long : presentoir de montres a bracelet (2,35 x 0,5)
	local m, h = newProp("WatchRow", Vector3.new(2.35, 0.08, 0.5), "#181A40", true)
	local straps = { BROWN, BLACK, SILVER, BROWN, GOLD, BLACK }
	for i = 0, 5 do
		local x = -0.95 + i * 0.38
		p(m, "Cushion" .. i, Vector3.new(0.26, 0.18, 0.3), CFrame.new(x, h + 0.09, 0), "#3A404B", { mat = Enum.Material.Fabric })
		p(m, "Strap" .. i, Vector3.new(0.1, 0.02, 0.32), CFrame.new(x, h + 0.19, 0), straps[i + 1])
		cyl(m, "Case" .. i, 0.05, 0.16, CFrame.new(x, h + 0.22, 0) * UP, if i % 2 == 0 then GOLD else SILVER, { reflect = 0.12 })
	end
end

return report({ "Electronique", "JeuxVideo", "Horlogerie" })
