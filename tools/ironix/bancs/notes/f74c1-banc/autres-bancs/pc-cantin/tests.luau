--!nocheck
-- Banc pc-cantin (2026-11-14, Cantin, L-140) : murs invisibles au-dessus des rayons (ShelfCapService).
-- Magasin d'essai : la géométrie de tools/clement/store_builder.luau (Supérette, gabarit 1) : gondoles A
-- (x -9..-5) et B (x 5..9) de z -15 à 9, rayons muraux (x -19..-17 et 17..19), meuble de réserve (Luxe,
-- ShelfSlot_10 posé SUR son dessus à y 3), planches à 1,85 et 3,6, dessus des rayons de 4,85 à 5, enseignes
-- de rayon (décor sans collision) de 5 à 6,2, Bounds y 0,3..9,9, plafond à 10. Plus une lampe solide à
-- y 8,5..9 à l'aplomb de ShelfSlot_05 (gondole A) et un vigile (Humanoid) debout sur la gondole B, à l'aplomb de
-- ShelfSlot_06 : ni l'une ni l'autre ne font partie du rayon.
-- pc-l140 (2026-11-14) : S5, grands meubles sans ShelfSlot (frigo, caisse, cartons), exceptions NoShelfCap, porte,
-- murs, pilier, marche ; le faux a GetAttribute et SetAttribute.
-- Copie f74c1 (2026-11-19, T-061) : la comtoise haute et étroite est coiffée ; panneau bas et étroit, montant
-- trop fin et linteau hors de portée de saut restent libres ; valeurs V0 FurnitureNarrow*.

local ShelfCaps = REQUIRE(game.ReplicatedStorage.Shared.Config.ShelfCaps)
local Service = REQUIRE(SERVICE_MODULE)
local EPS = 1e-6

local function box(model, frame, name, x0, y0, z0, x1, y1, z1, opts)
	opts = opts or {}
	local p = NEW("Part", name)
	p.Size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
	p.CFrame = frame * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
	if opts.decor then p.CanCollide = false; p.CanTouch = false end
	if opts.T then p.Transparency = opts.T end
	p.Parent = opts.parent or model
	return p
end
local function att(name, part, frame, x, y, z)
	local a = NEW("Attachment", name)
	a.Position = part.CFrame:PointToObjectSpace(frame * Vector3.new(x, y, z))
	a.Parent = part
	return a
end

local SLOTS = {
	{ "ShelfSlot_01", "A_R", -5.95, 1.85, -11 }, { "ShelfSlot_02", "B_L", 5.95, 1.85, -11 },
	{ "ShelfSlot_03", "WallL", -17.95, 1.85, -9 }, { "ShelfSlot_04", "WallR", 17.95, 1.85, -9 },
	{ "ShelfSlot_05", "A_L", -8.05, 1.85, -3 }, { "ShelfSlot_06", "B_R", 8.05, 1.85, -3 },
	{ "ShelfSlot_07", "A_R", -5.95, 1.85, 6 }, { "ShelfSlot_08", "B_L", 5.95, 1.85, 6 },
	{ "ShelfSlot_09", "WallR", 17.95, 1.85, 5 }, { "ShelfSlot_10", "Lux", 16, 3.0, 21.5 },
}
-- Emprises attendues (repère du magasin) : { x0, x1, z0, z1, dessus }.
local EXPECTED = {
	{ -9, -5, -15, 9, 5.0, "gondole A" }, { 5, 9, -15, 9, 5.0, "gondole B" },
	{ -19, -17, -15, 9, 5.0, "rayon mural gauche" }, { 17, 19, -15, 9, 5.0, "rayon mural droit" },
	{ 14.9, 17.1, 20.4, 22.6, 3.0, "réserve (Luxe)" },
}

local function buildStore(name, frame, parent, guard)
	local m = NEW("Model", name)
	box(m, frame, "Floor", -19.5, 0, -23.5, 19.5, 0.3, 23.5)
	box(m, frame, "Ceiling", -19.5, 10, -23.5, 19.5, 10.5, 23.5)
	box(m, frame, "WallL", -19.5, 0.3, -23.5, -19, 10, 23.5)
	box(m, frame, "WallR", 19, 0.3, -23.5, 19.5, 10, 23.5)
	box(m, frame, "WallBack", -19.5, 0.3, 23, 19.5, 10, 23.5)
	box(m, frame, "Bounds", -19, 0.3, -23, 19, 9.9, 23, { decor = true, T = 1 })
	local I = NEW("Folder", "Interior"); I.Parent = m
	local boards = {}
	local function side(prefix, fx, s, z0, z1)
		local xa, xb = math.min(fx - s * 2, fx), math.max(fx - s * 2, fx)
		box(m, frame, prefix .. "_Kick", xa, 0.35, z0, xb, 0.6, z1, { parent = I })
		boards[prefix] = box(m, frame, prefix .. "_Board2", xa, 1.7, z0, xb, 1.85, z1, { parent = I })
		box(m, frame, prefix .. "_Board3", xa, 3.45, z0, xb, 3.6, z1, { parent = I })
		box(m, frame, prefix .. "_Product", xa + 0.2, 1.85, z0 + 1, xb - 0.2, 3.2, z0 + 2, { parent = I, decor = true })
	end
	local function gondola(nm, key, x0, x1)
		box(m, frame, nm .. "_Spine", (x0 + x1) / 2 - 0.15, 0.35, -15, (x0 + x1) / 2 + 0.15, 4.85, 9, { parent = I })
		side(key .. "_L", x0, -1, -14.8, 8.8)
		side(key .. "_R", x1, 1, -14.8, 8.8)
		box(m, frame, nm .. "_Top", x0, 4.85, -15, x1, 5.0, 9, { parent = I })
		box(m, frame, nm .. "_EndA", x0, 0.35, -15, x1, 5.0, -14.8, { parent = I })
		box(m, frame, nm .. "_EndB", x0, 0.35, 8.8, x1, 5.0, 9, { parent = I })
		box(m, frame, nm .. "_Header", x0 + 0.5, 5.0, -15, x1 - 0.5, 6.2, 9, { parent = I, decor = true })
	end
	local function wall(nm, key, fx, s)
		side(key, fx, s, -14.8, 8.8)
		local xa, xb = math.min(fx - s * 2, fx), math.max(fx - s * 2, fx)
		box(m, frame, nm .. "_Top", xa, 4.85, -15, xb, 5.0, 9, { parent = I })
		local ba, bb = math.min(fx - s * 2, fx - s * 1.85), math.max(fx - s * 2, fx - s * 1.85)
		box(m, frame, nm .. "_Back", ba, 0.35, -15, bb, 4.85, 9, { parent = I })
	end
	gondola("Shelf_A", "A", -9, -5)
	gondola("Shelf_B", "B", 5, 9)
	wall("Shelf_WallL", "WallL", -17, 1)
	wall("Shelf_WallR", "WallR", 17, -1)
	box(m, frame, "Shelf_Reserve", 15, 0.37, 20.5, 17, 2.75, 22.5, { parent = I })
	boards.Lux = box(m, frame, "Shelf_Reserve_Top", 14.9, 2.75, 20.4, 17.1, 3.0, 22.6, { parent = I })
	box(m, frame, "Shelf_Reserve_Trim", 14.95, 0.37, 20.45, 17.05, 0.6, 22.55, { parent = I, decor = true })
	box(m, frame, "Lamp_A", -8.5, 8.5, -3.5, -7.5, 9.0, -2.5, { parent = I })
	for _, s in SLOTS do
		att(s[1], boards[s[2]], frame, s[3], s[4], s[5])
	end
	if guard then
		local g = NEW("Model", "Guard"); g.Parent = m
		NEW("Humanoid").Parent = g
		box(m, frame, "HumanoidRootPart", 7.5, 5.0, -3.5, 8.5, 9.95, -2.5, { parent = g })
	end
	m.Parent = parent
	return m
end

-- Boîte d'un bloc dans le repère `frame` du magasin.
local function capBox(frame, cap)
	local c = frame:PointToObjectSpace(cap.CFrame.Position)
	local h = cap.Size / 2
	return c - h, c + h
end
local function capsOf(model)
	local folder = model:FindFirstChild(ShelfCaps.FolderName)
	return if folder then folder:GetChildren() else {}
end

local function checkStore(label, model, frame)
	local caps = capsOf(model)
	check(#caps == #EXPECTED, `{label} : {#EXPECTED} blocs, un par rayon (trouvés : {#caps})`)
	local seen = {}
	for _, cap in caps do
		local lo, hi = capBox(frame, cap)
		local match = nil
		for i, e in EXPECTED do
			if math.abs(lo.X - e[1]) < 1e-4 and math.abs(hi.X - e[2]) < 1e-4 and math.abs(lo.Z - e[3]) < 1e-4 and math.abs(hi.Z - e[4]) < 1e-4 then
				match = i
			end
		end
		check(match ~= nil, `{label} : {cap.Name} a la largeur et la longueur d'un dessus de rayon ({lo} → {hi})`)
		if match then
			local e = EXPECTED[match]
			seen[match] = (seen[match] or 0) + 1
			-- haut des colis sous ce rayon (emplacements à l'aplomb) ; un colis rangé dans le rayon fait
			-- au plus la hauteur entre deux planches (1,6) ; un colis posé sur le dessus : ContentHeight.
			local boxTop = -math.huge
			for _, s in SLOTS do
				if s[3] >= e[1] and s[3] <= e[2] and s[5] >= e[3] and s[5] <= e[4] then
					local h = if s[4] >= e[5] - 0.5 then ShelfCaps.ContentHeight else 1.6
					boxTop = math.max(boxTop, s[4] + h)
				end
			end
			check(lo.Y >= boxTop - EPS and lo.Y >= e[5] - EPS, `{label} : {e[6]}, bas du bloc ({string.format("%.2f", lo.Y)}) au-dessus du dessus du rayon et du haut des colis ({string.format("%.2f", math.max(boxTop, e[5]))})`)
			check(lo.Y - e[5] < 5 and lo.Y <= math.max(boxTop, e[5]) + ShelfCaps.Gap + 1e-4, `{label} : {e[6]}, juste au-dessus (Gap) et moins de 5 studs de jeu au-dessus du dessus du rayon ({string.format("%.2f", lo.Y - e[5])})`)
			check(math.abs(hi.Y - 9.9) < 1e-4, `{label} : {e[6]}, haut du bloc au haut de Bounds (9,9)`)
		end
		check(cap.CanCollide == true and cap.CanQuery == false and cap.CanTouch == false and cap.Transparency == 1 and cap.Anchored == true and cap.CastShadow == false, `{label} : {cap.Name} CanCollide, pas CanQuery ni CanTouch, invisible, ancré`)
		check(math.abs(cap.CFrame.RightVector.X - frame.RightVector.X) < 1e-6 and math.abs(cap.CFrame.RightVector.Z - frame.RightVector.Z) < 1e-6, `{label} : {cap.Name} tourné comme le magasin`)
	end
	for i, e in EXPECTED do
		check(seen[i] == 1, `{label} : un seul bloc pour {e[6]}`)
	end
	-- Les allées (x -17..-9, -5..5, 9..17 entre z -15 et 9) restent libres sous le plafond.
	local free = true
	for _, cap in caps do
		local lo, hi = capBox(frame, cap)
		for _, aisle in { { -17, -9 }, { -5, 5 }, { 9, 14.9 } } do
			if hi.X > aisle[1] + 1e-4 and lo.X < aisle[2] - 1e-4 and hi.Z > -15 and lo.Z < 9 then
				free = false
			end
		end
	end
	check(free, `{label} : aucun bloc au-dessus d'une allée`)
end

section("S1 au démarrage")
local f1 = CFrame.new(0, 0, 0)
local s1 = buildStore("STORE_Z1_Superette", f1, WORKSPACE, true)
CS:AddTag(s1, "NPCStore")
local f2 = CFrame.new(300, 0, 40) * CFrame.AnglesY(math.pi / 2)
local s2 = buildStore("STORE_Z2_Londres", f2, WORKSPACE, false)
CS:AddTag(s2, "NPCStore")
local inbox = NEW("Folder", "_INBOX_CLEMENT"); inbox.Parent = WORKSPACE
local s3 = buildStore("STORE_Z3_Livraison", f1, inbox, false)
CS:AddTag(s3, "NPCStore")
check(#capsOf(s1) == 0, "S1 (banc) rien avant le démarrage")
Service.Start()
checkStore("S1 Supérette (zone 1)", s1, f1)
checkStore("S1 magasin tourné de 90° (zone 2)", s2, f2)
check(s3:FindFirstChild(ShelfCaps.FolderName) == nil, "S1 magasin dans _INBOX_CLEMENT : aucun bloc")
check(s1:FindFirstChild(ShelfCaps.FolderName).ClassName == "Folder", "S1 blocs dans le dossier ShelfCaps du magasin")

section("S2 magasin ajouté après le démarrage")
local f4 = CFrame.new(-250, 2, 60) * CFrame.AnglesY(math.rad(30))
local s4 = buildStore("STORE_Z4_LosAngeles", f4, WORKSPACE, false)
CS:AddTag(s4, "NPCStore")
checkStore("S2 magasin ajouté (tourné de 30°)", s4, f4)

section("S3 repasse sans doublon")
Service.Apply(s1)
check(#capsOf(s1) == #EXPECTED, "S3 seconde pose : toujours un bloc par rayon")
local folders = 0
for _, c in s1:GetChildren() do
	if c.Name == ShelfCaps.FolderName then folders += 1 end
end
check(folders == 1, "S3 un seul dossier ShelfCaps")

section("S4 valeurs V0")
check(ShelfCaps.MaxClearance < 5 and ShelfCaps.StackGap < 5, "S4 MaxClearance et StackGap sous la hauteur d'un perso R15 (5)")
local warns = 0
for _, l in LOG do
	if l.kind == "WARN" then warns += 1 end
end
check(warns == 0, `S4 aucun avertissement du service ({warns})`)


-- S5 (pc-l140, 2026-11-14) : grands meubles sans ShelfSlot. Magasin à l'échelle 1,5 du gabarit (comme en jeu) :
-- Bounds y 0,45..14,85, sol du magasin à 0,525. Tourné de 30° et déplacé.
section("S5 grands meubles")
local f5 = CFrame.new(120, 3, -80) * CFrame.AnglesY(math.rad(30))
local m5 = NEW("Model", "STORE_Z5_Meubles")
box(m5, f5, "Floor", -30, -0.9, -36, 30, 0.45, 36)
box(m5, f5, "Bounds", -28.5, 0.45, -34.5, 28.5, 14.85, 34.5, { decor = true, T = 1 })
local I5 = NEW("Folder", "Interior"); I5.Parent = m5
box(m5, f5, "FloorShop", -28.5, 0.45, -34.5, 28.5, 0.525, 34.5, { parent = I5 })
box(m5, f5, "Ceiling", -28.5, 14.85, -34.5, 28.5, 15, 34.5, { parent = I5 })
box(m5, f5, "InnerWall_L", -28.5, 0.525, -34.5, -28.35, 14.85, 34.5, { parent = I5 })
box(m5, f5, "Pillar", 0, 0.525, 0, 3, 14.85, 3, { parent = I5 })
box(m5, f5, "ReserveWall_FL", 12, 0.45, 24, 15.75, 14.85, 25.5, { parent = I5 })
box(m5, f5, "Step", 10, 0.525, 10, 13, 2.525, 13, { parent = I5 })
-- frigo du fond (Fridge_Top haut à 7,8)
box(m5, f5, "Fridge_Back", -28.5, 0.525, 33.6, -1.5, 7.8, 34.35, { parent = I5 })
box(m5, f5, "Fridge_SideA", -28.5, 0.525, 31.5, -28.2, 7.8, 34.35, { parent = I5 })
box(m5, f5, "Fridge_Top", -28.5, 7.35, 31.5, -1.5, 7.8, 34.35, { parent = I5 })
-- caisse : corps sous son plateau ; le plateau dépasse de Bounds vers la vitrine (z -35)
box(m5, f5, "Counter", -27, 0.525, -34.5, -16.5, 3.9, -31.5, { parent = I5 })
box(m5, f5, "CounterTop", -27.15, 3.9, -35, -16.35, 4.2, -31.35, { parent = I5 })
-- cartons empilés : le petit sur le grand, le grand dépasse autour
box(m5, f5, "Carton_1", 14.25, 0.555, 29.4, 17.25, 3.555, 32.4, { parent = I5 })
box(m5, f5, "Carton_4", 15, 3.555, 29.7, 17.1, 5.505, 31.8, { parent = I5 })
-- horloge fine (comme Comtoise_Case : 1,8 × 2,2, haut 8,7) : f74c1 (T-061), haute et étroite, coiffée
box(m5, f5, "Comtoise_Case", 25, 0.525, -10, 26.8, 8.7, -7.8, { parent = I5 })
-- f74c1 : pièces témoins qui restent libres. Panneau bas et étroit (comme ArcadePanel du Tokyo : 1,2 × 2,4,
-- dessus à 4,4 du sol), montant trop fin (0,9 × 0,9, dessus à 8,2 du sol), linteau étroit hors de portée de
-- saut (comme ReserveFrame_T : 9,6 × 1,8, dessus à 11,6 du sol).
box(m5, f5, "Panel_Low", 22, 0.525, 18, 23.2, 4.95, 20.4, { parent = I5 })
box(m5, f5, "Post_Thin", 5, 0.525, 20, 5.9, 8.7, 20.9, { parent = I5 })
box(m5, f5, "Lintel_High", -25, 11.85, 0, -15.4, 12.15, 1.8, { parent = I5 })
-- exceptions de Clément : sur la pièce, sur son modèle
local np = box(m5, f5, "Plinth_NoCap", 20, 0.525, 0, 23, 6, 3, { parent = I5 })
np:SetAttribute("NoShelfCap", true)
local nm = NEW("Model", "Statue"); nm.Parent = I5
nm:SetAttribute("NoShelfCap", true)
box(m5, f5, "Statue_Base", 20, 0.525, 10, 23, 6, 13, { parent = nm })
-- porte (contrat 10.4) : jamais de bloc, même large et dans Bounds
local door = NEW("Model", "Door"); door.Parent = m5
box(m5, f5, "DoorFrame_T", 16.5, 0.525, -34.5, 22.5, 11.55, -32.5, { parent = door })
-- rayon à emplacement : un seul bloc (pas un deuxième par l'étape des meubles)
local body = box(m5, f5, "Shelf_Body", -13.5, 0.525, -22.5, -7.5, 7.275, 13.5, { parent = I5 })
box(m5, f5, "Shelf_Top", -13.5, 7.275, -22.5, -7.5, 7.5, 13.5, { parent = I5 })
att("ShelfSlot_01", body, f5, -7.5, 2.775, -10)
-- rayon à emplacement avec l'exception NoShelfCap sur son dessus : ni bloc de rayon, ni bloc de meuble
local body2 = box(m5, f5, "Shelf2_Body", 5, 0.525, -22.5, 9, 7.275, -14, { parent = I5 })
local top2 = box(m5, f5, "Shelf2_Top", 5, 7.275, -22.5, 9, 7.5, -14, { parent = I5 })
top2:SetAttribute("NoShelfCap", true)
att("ShelfSlot_02", body2, f5, 5, 2.775, -18)
m5.Parent = WORKSPACE
CS:AddTag(m5, "NPCStore")

local caps5 = capsOf(m5)
local folder5 = m5:FindFirstChild(ShelfCaps.FolderName)
-- { x0, x1, z0, z1, dessus, nom } attendus
local EXP5 = {
	{ -13.5, -7.5, -22.5, 13.5, 7.5, "rayon à emplacement" },
	{ -28.5, -1.5, 31.5, 34.35, 7.8, "frigo (Fridge_Top, 7,8)" },
	{ 15, 17.1, 29.7, 31.8, 5.505, "carton du dessus" },
	{ -27.15, -16.35, -34.5, -31.35, 4.2, "plateau de la caisse (coupé au bord de Bounds)" },
	{ 14.25, 17.25, 29.4, 32.4, 3.555, "grand carton (dépasse autour du petit)" },
	{ 25, 26.8, -10, -7.8, 8.7, "horloge comtoise haute et étroite (f74c1, T-061)" },
}
check(#caps5 == #EXP5, `S5 {#EXP5} blocs (1 rayon, 5 meubles) (trouvés : {#caps5})`)
check(folder5 ~= nil and folder5:GetAttribute(ShelfCaps.ShelfCountAttribute) == 1 and folder5:GetAttribute(ShelfCaps.FurnitureCountAttribute) == 5, `S5 comptage sur le dossier : OnShelves 1, OnFurniture 5 ({folder5 and folder5:GetAttribute(ShelfCaps.ShelfCountAttribute)}, {folder5 and folder5:GetAttribute(ShelfCaps.FurnitureCountAttribute)})`)
local seen5 = {}
for _, cap in caps5 do
	local lo, hi = capBox(f5, cap)
	local hit = nil
	for i, e in EXP5 do
		if math.abs(lo.X - e[1]) < 1e-4 and math.abs(hi.X - e[2]) < 1e-4 and math.abs(lo.Z - e[3]) < 1e-4 and math.abs(hi.Z - e[4]) < 1e-4 then
			hit = i
		end
	end
	check(hit ~= nil, `S5 {cap.Name} correspond à un meuble attendu ({lo} → {hi})`)
	if hit then
		local e = EXP5[hit]
		seen5[hit] = (seen5[hit] or 0) + 1
		check(math.abs(lo.Y - (e[5] + ShelfCaps.Gap)) < 1e-4, `S5 {e[6]} : bas du bloc au dessus + Gap ({string.format("%.3f", lo.Y)})`)
		check(lo.Y - e[5] < 5, `S5 {e[6]} : moins de 5 studs de jeu`)
		check(math.abs(hi.Y - 14.85) < 1e-4, `S5 {e[6]} : haut du bloc au haut de Bounds (14,85)`)
	end
	check(cap.CanCollide == true and cap.CanQuery == false and cap.CanTouch == false and cap.Transparency == 1 and cap.Anchored == true, `S5 {cap.Name} CanCollide, pas CanQuery ni CanTouch, invisible, ancré`)
end
for i, e in EXP5 do
	check(seen5[i] == 1, `S5 un seul bloc pour {e[6]} ({seen5[i] or 0})`)
end
-- Rien au-dessus du sol, de la marche, du mur, du pilier, de la porte, des pièces témoins de f74c1, des exceptions.
local function anyCapOver(x0, x1, z0, z1)
	for _, cap in caps5 do
		local lo, hi = capBox(f5, cap)
		if hi.X > x0 + 1e-4 and lo.X < x1 - 1e-4 and hi.Z > z0 + 1e-4 and lo.Z < z1 - 1e-4 then
			return true
		end
	end
	return false
end
check(not anyCapOver(10, 13, 10, 13), "S5 rien sur la marche de 2 studs")
check(not anyCapOver(-2, -1, -5, -4), "S5 rien sur le sol nu")
check(not anyCapOver(0, 3, 0, 3), "S5 rien sur le pilier qui touche le haut de Bounds")
check(not anyCapOver(-28.5, -28.35, -30, 30), "S5 rien sur le mur intérieur")
check(not anyCapOver(12, 15.75, 24, 25.5), "S5 rien sur le mur de la réserve (épais de 1,5)")
check(not anyCapOver(16.5, 22.5, -34.5, -32.5), "S5 rien sur la porte (contrat 10.4)")
check(not anyCapOver(22, 23.2, 18, 20.4), "S5 (f74c1) rien sur le panneau bas et étroit (1,2 × 2,4, dessus à 4,4 du sol)")
check(not anyCapOver(5, 5.9, 20, 20.9), "S5 (f74c1) rien sur le montant trop fin (0,9 × 0,9, dessus à 8,2 du sol)")
check(not anyCapOver(-25, -15.4, 0, 1.8), "S5 (f74c1) rien sur le linteau étroit hors de portée de saut (dessus à 11,6 du sol)")
check(not anyCapOver(20, 23, 0, 3), "S5 exception NoShelfCap sur la pièce respectée")
check(not anyCapOver(20, 23, 10, 13), "S5 exception NoShelfCap sur le modèle respectée")
check(not anyCapOver(5, 9, -22.5, -14), "S5 rayon dont le dessus porte NoShelfCap : ni bloc de rayon, ni bloc de meuble")
Service.Apply(m5)
check(#capsOf(m5) == #EXP5, "S5 seconde pose : mêmes blocs, sans doublon")
local startLine = nil
for _, l in LOG do
	if l.kind == "PRINT" and string.find(l.text, "[ShelfCapService]", 1, true) then startLine = l.text end
end
check(startLine ~= nil and string.find(startLine, "au-dessus des grands meubles", 1, true) ~= nil, `S5 total des rayons et des meubles dans la sortie au démarrage ({startLine})`)
check(ShelfCaps.FurnitureMinTop == 2 and ShelfCaps.FurnitureMinHeight == 3, "S5 valeurs V0 : dessus 2 × 2, 3 studs au-dessus du sol")
check(ShelfCaps.FurnitureNarrowMinTop == 1 and ShelfCaps.FurnitureNarrowMinHeight == 5 and ShelfCaps.FurnitureNarrowMaxHeight == 10, "S5 (f74c1) valeurs V0 du meuble haut et étroit : dessus 1 × 1, de 5 à 10 studs au-dessus du sol")

summary("scénario caps")
