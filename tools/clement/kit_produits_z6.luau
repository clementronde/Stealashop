--!nocheck
-- Kits de produits de la zone 6 (Clement 26/11 : kit Bijouterie valide, « les 11 autres, chacun dans son theme », ordre du
-- chef Map : Banque, Salle des coffres d'abord). Memes regles que tools/clement/kit_produits_bijouterie.luau : pieces a
-- tenons sur les dessus plats, aucun script, emprise d'un cube de rayon (1,2 x 1,5 au plus) pour les courts et 2,35 de
-- long pour les lots muraux, pivot en bas au centre, face avant -Z, PrimaryPart « Base », ni collision ni toucher ni
-- requete. Ranges dans ServerStorage/Previews/KITS/<Magasin> (ENV_Z6_<Magasin>_<Nom>). Relancable, mode Edit.

local kits = game:GetService("ServerStorage").Previews:FindFirstChild("KITS")

local GOLD, GOLD2, SILVER, DARK, STEEL = "#F5C842", "#C99A1E", "#D6DAE2", "#2B2F36", "#8D96A3"
local BILL, BILL2, BAND, BAG, RED, PAPER = "#5DBB63", "#3E8E4A", "#F2E9D0", "#C9A36B", "#D8343C", "#F7F3EA"
local RUBY, SAPPHIRE, EMERALD, DIAMOND, VELVET = "#DC2846", "#285ADC", "#28AA64", "#C8F0FF", "#7A162C"

local folder
local function p(parent, name, size, cf, color, o)
	o = o or {}
	local part = Instance.new("Part")
	part.Name = name
	if o.shape then part.Shape = o.shape end
	part.Size = size
	part.CFrame = cf
	part.Color = Color3.fromHex(color)
	if o.studs then
		part.Material = Enum.Material.Plastic
		part.MaterialVariant = "Studs"
	else
		part.Material = o.mat or Enum.Material.SmoothPlastic
	end
	if o.reflect then part.Reflectance = o.reflect end
	if o.transp then part.Transparency = o.transp end
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end
local function shiny(parent, name, size, cf, color)
	return p(parent, name, size, cf, color, { reflect = 0.12 })
end
local function gem(parent, name, s, cf, color)
	return p(parent, name, Vector3.new(s, s, s), cf * CFrame.Angles(math.rad(45), 0, math.rad(45)), color, { mat = Enum.Material.Glass, reflect = 0.35 })
end
local function cyl(parent, name, len, dia, cf, color, o)
	o = o or {}
	o.shape = Enum.PartType.Cylinder
	return p(parent, name, Vector3.new(len, dia, dia), cf, color, o)
end
local UP = CFrame.Angles(0, 0, math.rad(90))
local FACE = CFrame.Angles(0, math.rad(90), 0)
local PREFIX
local function newProp(name, baseSize, baseColor, studs)
	local m = Instance.new("Model")
	m.Name = PREFIX .. name
	local b = p(m, "Base", baseSize, CFrame.new(0, baseSize.Y / 2, 0), baseColor, { studs = studs })
	b.PivotOffset = CFrame.new(0, -baseSize.Y / 2, 0)
	m.PrimaryPart = b
	m.Parent = folder
	return m, baseSize.Y
end
local function store(name)
	folder = kits:FindFirstChild(name) or Instance.new("Folder")
	folder.Name = name
	folder.Parent = kits
	folder:ClearAllChildren()
	PREFIX = "ENV_Z6_" .. name .. "_"
end
-- liasse de billets : pile verte, bande de papier au milieu
local function cashStack(m, cf, w, d, h)
	p(m, "Bills", Vector3.new(w, h, d), cf * CFrame.new(0, h / 2, 0), BILL)
	p(m, "BillsEdge", Vector3.new(w + 0.01, h * 0.25, d + 0.01), cf * CFrame.new(0, h * 0.75, 0), BILL2)
	p(m, "Band", Vector3.new(w * 0.22, h + 0.02, d + 0.02), cf * CFrame.new(0, h / 2, 0), BAND)
end

-- ================= BANQUE =================
store("Banque")
do -- 1. pile de liasses
	local m, h = newProp("CashStack", Vector3.new(1.0, 0.06, 0.6), DARK)
	for i = 0, 3 do
		cashStack(m, CFrame.new(0, h + i * 0.22, 0) * CFrame.Angles(0, math.rad((i % 2) * 6 - 3), 0), 0.9, 0.45, 0.2)
	end
end
do -- 2. brique de billets sous film
	local m, h = newProp("CashBrick", Vector3.new(1.05, 0.05, 0.75), DARK)
	for x = -1, 1, 2 do
		for z = -1, 1, 2 do
			cashStack(m, CFrame.new(x * 0.25, h, z * 0.17), 0.46, 0.32, 0.42)
		end
	end
	p(m, "Wrap", Vector3.new(1.0, 0.46, 0.7), CFrame.new(0, h + 0.23, 0), "#E8F6FF", { mat = Enum.Material.Glass, transp = 0.7 })
end
do -- 3. rouleaux de pieces
	local m, h = newProp("CoinRolls", Vector3.new(1.0, 0.08, 0.6), "#3A404B", true)
	local cols = { GOLD, SILVER, "#C77A3A", GOLD, SILVER }
	for i = 1, 5 do
		cyl(m, "Roll_" .. i, 0.8, 0.18, CFrame.new(0, h + 0.1 + ((i - 1) % 2) * 0.17, -0.22 + (i - 1) * 0.11) * FACE * CFrame.Angles(0, math.rad(90), 0), cols[i])
	end
end
do -- 4. sac de billets a dollar
	local m, h = newProp("MoneyBag", Vector3.new(0.9, 0.05, 0.9), DARK)
	p(m, "Bag", Vector3.new(0.8, 0.8, 0.8), CFrame.new(0, h + 0.4, 0), BAG, { mat = Enum.Material.Fabric, shape = Enum.PartType.Ball })
	p(m, "Neck", Vector3.new(0.35, 0.22, 0.35), CFrame.new(0, h + 0.86, 0), BAG, { mat = Enum.Material.Fabric })
	p(m, "Tie", Vector3.new(0.4, 0.07, 0.4), CFrame.new(0, h + 0.8, 0), "#6B4A23", { mat = Enum.Material.Fabric })
	p(m, "DollarV", Vector3.new(0.07, 0.38, 0.03), CFrame.new(0, h + 0.42, -0.41), BILL2)
	p(m, "DollarS1", Vector3.new(0.24, 0.06, 0.03), CFrame.new(0, h + 0.52, -0.41), BILL2)
	p(m, "DollarS2", Vector3.new(0.24, 0.06, 0.03), CFrame.new(0, h + 0.32, -0.41), BILL2)
end
do -- 5. tirelire doree
	local m, h = newProp("PiggyBank", Vector3.new(0.9, 0.05, 0.6), DARK)
	local body = shiny(m, "Body", Vector3.new(0.75, 0.5, 0.5), CFrame.new(0, h + 0.4, 0), GOLD)
	shiny(m, "Snout", Vector3.new(0.12, 0.2, 0.24), CFrame.new(-0.43, h + 0.42, 0), GOLD2)
	for x = -1, 1, 2 do
		for z = -1, 1, 2 do
			shiny(m, "Leg", Vector3.new(0.12, 0.15, 0.12), CFrame.new(x * 0.22, h + 0.075, z * 0.15), GOLD2)
		end
	end
	p(m, "Slot", Vector3.new(0.3, 0.02, 0.05), CFrame.new(0.05, h + 0.655, 0), DARK)
	shiny(m, "EarL", Vector3.new(0.1, 0.12, 0.1), CFrame.new(-0.22, h + 0.7, -0.15), GOLD2)
	shiny(m, "EarR", Vector3.new(0.1, 0.12, 0.1), CFrame.new(-0.22, h + 0.7, 0.15), GOLD2)
	body.Name = "Body"
end
do -- 6. compteuse de billets
	local m, h = newProp("CashCounter", Vector3.new(0.9, 0.08, 0.75), "#3A404B")
	p(m, "Body", Vector3.new(0.85, 0.42, 0.7), CFrame.new(0, h + 0.21, 0.02), SILVER)
	p(m, "Hopper", Vector3.new(0.55, 0.18, 0.3), CFrame.new(0, h + 0.5, 0.18) * CFrame.Angles(math.rad(-20), 0, 0), DARK)
	cashStack(m, CFrame.new(0, h + 0.5, 0.2) * CFrame.Angles(math.rad(-20), 0, 0), 0.5, 0.25, 0.12)
	p(m, "Screen", Vector3.new(0.4, 0.14, 0.02), CFrame.new(0, h + 0.3, -0.34), "#5BE38A", { mat = Enum.Material.Neon })
	cashStack(m, CFrame.new(0, h + 0.02, -0.25), 0.5, 0.2, 0.1)
end
do -- 7. tas de pieces d'or
	local m, h = newProp("GoldCoinPile", Vector3.new(1.05, 0.05, 0.85), DARK)
	local rng = Random.new(66)
	for i = 1, 16 do
		local r, a = rng:NextNumber(0, 0.38), rng:NextNumber(0, math.pi * 2)
		local y = h + 0.03 + (0.38 - r) * 0.7
		cyl(m, "Coin_" .. i, 0.05, 0.22, CFrame.new(math.cos(a) * r, y, math.sin(a) * r) * UP * CFrame.Angles(rng:NextNumber(-0.4, 0.4), 0, rng:NextNumber(-0.4, 0.4)), GOLD, { reflect = 0.15 })
	end
end
do -- 8. boite de depot
	local m, h = newProp("DepositBox", Vector3.new(1.0, 0.05, 0.6), DARK)
	p(m, "Box", Vector3.new(0.95, 0.4, 0.55), CFrame.new(0, h + 0.2, 0), STEEL, { mat = Enum.Material.Metal })
	p(m, "Lid", Vector3.new(0.97, 0.06, 0.57), CFrame.new(0, h + 0.43, 0), "#6F7885", { mat = Enum.Material.Metal })
	p(m, "Handle", Vector3.new(0.3, 0.06, 0.06), CFrame.new(0, h + 0.25, -0.3), DARK)
	p(m, "Plate", Vector3.new(0.22, 0.12, 0.02), CFrame.new(0.28, h + 0.25, -0.28), GOLD)
end
do -- 9. long : bac a billets (2,35 x 0,7)
	local m, h = newProp("CashTray", Vector3.new(2.35, 0.1, 0.7), "#3A404B", true)
	for i = 0, 4 do
		local x = -0.94 + i * 0.47
		p(m, "Divider_" .. i, Vector3.new(0.04, 0.3, 0.66), CFrame.new(x - 0.235, h + 0.15, 0), DARK)
		cashStack(m, CFrame.new(x, h, 0), 0.4, 0.55, 0.18 + (i % 3) * 0.06)
	end
	p(m, "DividerEnd", Vector3.new(0.04, 0.3, 0.66), CFrame.new(1.175, h + 0.15, 0), DARK)
end
do -- 10. long : rangee de tubes de pieces (2,35 x 0,5)
	local m, h = newProp("CoinTubeRack", Vector3.new(2.35, 0.1, 0.5), DARK, true)
	local cols = { GOLD, SILVER, "#C77A3A" }
	for i = 0, 6 do
		local x = -1.02 + i * 0.34
		cyl(m, "Tube_" .. i, 0.55, 0.22, CFrame.new(x, h + 0.275, 0) * UP, "#E8F6FF", { mat = Enum.Material.Glass, transp = 0.55 })
		cyl(m, "Coins_" .. i, 0.4 - (i % 3) * 0.08, 0.18, CFrame.new(x, h + 0.2 - (i % 3) * 0.04, 0) * UP, cols[i % 3 + 1], { reflect = 0.12 })
	end
end

-- ================= SALLE DES COFFRES =================
store("SalleDesCoffres")
do -- 1. pyramide de lingots
	local m, h = newProp("GoldBarStack", Vector3.new(1.1, 0.06, 0.8), DARK, true)
	for li, xs in ipairs({ { -0.38, 0, 0.38 }, { -0.19, 0.19 }, { 0 } }) do
		for _, x in xs do
			shiny(m, "Bar", Vector3.new(0.34, 0.17, 0.62), CFrame.new(x, h + 0.085 + (li - 1) * 0.17, 0), if li % 2 == 0 then GOLD2 else GOLD)
		end
	end
end
do -- 2. tiroir de coffre ouvert avec bijoux
	local m, h = newProp("SafeDrawer", Vector3.new(1.0, 0.05, 1.0), DARK)
	p(m, "Tray", Vector3.new(0.9, 0.22, 0.9), CFrame.new(0, h + 0.11, 0), STEEL, { mat = Enum.Material.Metal })
	p(m, "Velvet", Vector3.new(0.8, 0.04, 0.8), CFrame.new(0, h + 0.23, 0), VELVET, { mat = Enum.Material.Fabric })
	p(m, "Front", Vector3.new(0.92, 0.3, 0.06), CFrame.new(0, h + 0.15, -0.48), "#6F7885", { mat = Enum.Material.Metal })
	shiny(m, "Pull", Vector3.new(0.3, 0.06, 0.06), CFrame.new(0, h + 0.18, -0.53), GOLD)
	gem(m, "Gem1", 0.14, CFrame.new(-0.2, h + 0.33, 0.1), RUBY)
	gem(m, "Gem2", 0.14, CFrame.new(0.15, h + 0.33, -0.1), EMERALD)
	cyl(m, "Ring", 0.06, 0.22, CFrame.new(0.2, h + 0.3, 0.2) * UP, GOLD, { reflect = 0.12 })
end
do -- 3. mallette ouverte a billets
	local m, h = newProp("CashCase", Vector3.new(1.2, 0.05, 0.85), DARK)
	p(m, "Case", Vector3.new(1.1, 0.2, 0.75), CFrame.new(0, h + 0.1, 0), "#1E2027")
	p(m, "LidOpen", Vector3.new(1.1, 0.75, 0.08), CFrame.new(0, h + 0.55, 0.42) * CFrame.Angles(math.rad(-12), 0, 0), "#1E2027")
	p(m, "LidLining", Vector3.new(1.0, 0.65, 0.02), CFrame.new(0, h + 0.55, 0.37) * CFrame.Angles(math.rad(-12), 0, 0), "#5A5F6B", { mat = Enum.Material.Fabric })
	for i = 0, 3 do
		cashStack(m, CFrame.new(-0.39 + i * 0.26, h + 0.2, 0), 0.22, 0.6, 0.14)
	end
	shiny(m, "Latch", Vector3.new(0.12, 0.08, 0.04), CFrame.new(0, h + 0.18, -0.39), SILVER)
end
do -- 4. petit coffre-fort a cadran
	local m, h = newProp("MiniSafe", Vector3.new(0.9, 0.05, 0.85), DARK)
	p(m, "Body", Vector3.new(0.85, 0.85, 0.8), CFrame.new(0, h + 0.425, 0), "#4A515C", { mat = Enum.Material.Metal })
	p(m, "Door", Vector3.new(0.72, 0.72, 0.04), CFrame.new(0, h + 0.425, -0.42), "#6F7885", { mat = Enum.Material.Metal })
	cyl(m, "Dial", 0.06, 0.28, CFrame.new(-0.1, h + 0.48, -0.46) * FACE, SILVER)
	shiny(m, "Handle", Vector3.new(0.06, 0.24, 0.06), CFrame.new(0.2, h + 0.43, -0.47), GOLD)
end
do -- 5. lingot sur presentoir
	local m, h = newProp("IngotDisplay", Vector3.new(0.75, 0.25, 0.75), VELVET, false)
	shiny(m, "Ingot", Vector3.new(0.5, 0.22, 0.32), CFrame.new(0, h + 0.11, 0) * CFrame.Angles(0, math.rad(20), 0), GOLD)
	p(m, "Stamp", Vector3.new(0.2, 0.01, 0.12), CFrame.new(0, h + 0.225, 0) * CFrame.Angles(0, math.rad(20), 0), GOLD2)
	p(m, "Dome", Vector3.new(0.62, 0.55, 0.62), CFrame.new(0, h + 0.28, 0), "#E8F6FF", { mat = Enum.Material.Glass, transp = 0.75 })
end
do -- 6. couronne sur coussin
	local m, h = newProp("CrownCushion", Vector3.new(0.9, 0.08, 0.9), GOLD, true)
	p(m, "Cushion", Vector3.new(0.8, 0.22, 0.8), CFrame.new(0, h + 0.11, 0), VELVET, { mat = Enum.Material.Fabric })
	shiny(m, "Band", Vector3.new(0.5, 0.18, 0.5), CFrame.new(0, h + 0.31, 0), GOLD)
	for i = 0, 3 do
		local a = i * math.pi / 2
		shiny(m, "Spike_" .. i, Vector3.new(0.1, 0.22, 0.1), CFrame.new(math.cos(a) * 0.2, h + 0.5, math.sin(a) * 0.2) * CFrame.Angles(0, -a, 0), GOLD)
	end
	gem(m, "Front", 0.12, CFrame.new(0, h + 0.32, -0.26), RUBY)
end
do -- 7. sac de banque scelle
	local m, h = newProp("SealedBag", Vector3.new(0.8, 0.05, 0.6), DARK)
	p(m, "Bag", Vector3.new(0.7, 0.75, 0.5), CFrame.new(0, h + 0.375, 0), "#7D8794", { mat = Enum.Material.Fabric })
	p(m, "Top", Vector3.new(0.5, 0.15, 0.35), CFrame.new(0, h + 0.82, 0), "#7D8794", { mat = Enum.Material.Fabric })
	p(m, "Seal", Vector3.new(0.14, 0.14, 0.04), CFrame.new(0, h + 0.74, -0.2), RED)
	p(m, "Tag", Vector3.new(0.3, 0.2, 0.02), CFrame.new(0.1, h + 0.45, -0.26), PAPER)
end
do -- 8. bac de pierres precieuses
	local m, h = newProp("GemBin", Vector3.new(1.0, 0.08, 0.8), STEEL, true)
	p(m, "Bin", Vector3.new(0.9, 0.25, 0.7), CFrame.new(0, h + 0.125, 0), "#4A515C", { mat = Enum.Material.Metal })
	local rng = Random.new(61)
	local cols = { RUBY, SAPPHIRE, EMERALD, DIAMOND }
	for i = 1, 10 do
		gem(m, "Gem_" .. i, 0.14, CFrame.new(rng:NextNumber(-0.33, 0.33), h + 0.28 + rng:NextNumber(0, 0.06), rng:NextNumber(-0.25, 0.25)), cols[(i % 4) + 1])
	end
end
do -- 9. long : rangee de lingots (2,35 x 0,7)
	local m, h = newProp("GoldBarRow", Vector3.new(2.35, 0.06, 0.7), DARK, true)
	for i = 0, 5 do
		shiny(m, "Bar_" .. i, Vector3.new(0.34, 0.17, 0.6), CFrame.new(-0.95 + i * 0.38, h + 0.085, 0), GOLD)
		if i % 2 == 0 then
			shiny(m, "TopBar_" .. i, Vector3.new(0.34, 0.17, 0.6), CFrame.new(-0.76 + i * 0.38, h + 0.255, 0), GOLD2)
		end
	end
end
do -- 10. long : rangee de tiroirs de coffre (2,35 x 0,6, 0,9 de haut)
	local m, h = newProp("SafeDrawerRow", Vector3.new(2.35, 0.05, 0.6), DARK)
	p(m, "Cabinet", Vector3.new(2.3, 0.85, 0.55), CFrame.new(0, h + 0.425, 0), "#4A515C", { mat = Enum.Material.Metal })
	for row = 0, 1 do
		for col = 0, 4 do
			local x, y = -0.9 + col * 0.45, h + 0.22 + row * 0.42
			p(m, "Door", Vector3.new(0.4, 0.36, 0.03), CFrame.new(x, y, -0.29), "#8D96A3", { mat = Enum.Material.Metal })
			shiny(m, "Knob", Vector3.new(0.07, 0.07, 0.05), CFrame.new(x + 0.12, y, -0.32), GOLD)
		end
	end
end

local lines = {}
for _, n in { "Banque", "SalleDesCoffres" } do
	for _, m in kits[n]:GetChildren() do
		local _, s = m:GetBoundingBox()
		table.insert(lines, string.format("%s %d pieces %.2f x %.2f x %.2f", m.Name, #m:GetChildren(), s.X, s.Y, s.Z))
	end
end
table.sort(lines)
print("[kits z6] " .. #lines .. " produits")
return table.concat(lines, "\n")
