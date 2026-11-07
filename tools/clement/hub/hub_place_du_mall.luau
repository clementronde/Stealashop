--!nocheck
-- Hub (zone safe) « Place du Mall » (MOD-029, L-049), au gabarit des zones (L-040).
-- Une place en plein air devant l'immense façade d'un centre commercial (enseigne STEAL A SHOP) : 6 emplacements de
-- boutiques en arc doux autour du spawn, comptoirs en food trucks à la sortie, parking et jardin en décor, sortie tout
-- droit vers la zone 1 (x = 30, dans l'axe du couloir), un seul volume SafeZone.
-- À lancer dans Studio (MCP execute_luau, mode Edit). Relancer reconstruit ce que le script pose dans Workspace/Map/Hub
-- (les autres enfants de Map/Hub, par exemple les boutiques posées plus tard, sont gardés).
-- Ce qu'il fait :
--  1) plan : arc de rayon RC autour du centre C, spawn S à 32 studs de C côté arc (boutiques à 139..156 studs du spawn,
--     196..186 studs de l'arche 1) ; ROT tourne tout l'arc autour de l'entrée de la zone 1 (0 = enseigne dans l'axe) ;
--  2) pose les 6 parcelles grises du greybox (Greybox/Safe/Plots, tag PlayerPlot) sur leurs emplacements, en attendant
--     le modèle de boutique ; une parcelle dont l'emplacement touche une zone réservée reste où elle est ;
--  3) construit Map/Hub en sautant toute pièce qui toucherait une zone réservée (_SHOWROOM_CLEMENT, _INBOX_CLEMENT,
--     parcelle grise pas déplacée) : relancer après leur départ complète le hub ;
--  4) pose les 6 boutiques (PLOT_Shop, 5 niveaux, MOD-015) sur les emplacements, au niveau 1, dans Map/Hub/Shops, avec
--     le constructeur tools/clement/hub/plot_shop_builder.luau : l'envoyer à execute_luau AVANT ce script
--     (_G.ClaudePlotShop) ; sans lui, les boutiques déjà posées restent telles quelles ;
--  5) range dans ServerStorage/_GREYBOX_REMPLACE ce que le hub remplace : Greybox/Safe/{Ground, Shops, SafeZone, Spawn},
--     Greybox/Corridor/Entry, et Greybox/Safe/Plots dès que les 6 boutiques sont posées (6 PlayerPlot en tout) ;
--  6) vérifie : tags, aucun script, emprise, chevauchements avec les emplacements, contrat 10.4 des boutiques, chemins
--     à pied (PathfindingService, rayon 2, sans saut) du spawn aux boutiques, aux comptoirs et à la zone 1.
--     Le script renvoie le compte rendu.
-- Comptoirs (contrat : Contract/Tags, ShopService, WeaponShopController, AuraShopController) : un Model tagué
-- WeaponShop, AuraShop, RobuxShop ou PawnShop, dont la PrimaryPart (Counter) porte l'invite du code.
-- Ne touche pas : Map/Entry (mur de nuit de la zone 1, x 25,45..28,55, z ±34,5, livré sous le sol : le sol du hub le
-- couvre, à plat), Map/Zone_*, _SHOWROOM_CLEMENT, _INBOX_CLEMENT. Aucun script dans la map ; textes en anglais (L-036).

local CS = game:GetService("CollectionService")
local SS = game:GetService("ServerStorage")
local PFS = game:GetService("PathfindingService")
local rgb = Color3.fromRGB
local CYL, BALL = Enum.PartType.Cylinder, Enum.PartType.Ball
local NEON, GLASS, SMOOTH = Enum.Material.Neon, Enum.Material.Glass, Enum.Material.SmoothPlastic
local FRONT, BACK, TOP = Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Top
local LEFT, RIGHT = Enum.NormalId.Left, Enum.NormalId.Right
local NIGHT_LIGHT = "NightLight" -- partie lumineuse d'un lampadaire, livrée éteinte ; le code l'allume la nuit (L-043)
local LUCKY = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local MONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
local SPARK = "rbxasset://textures/particles/SquareParticle.png" -- livrée avec le client

-- Couleurs : crème et brique pour le centre commercial, dalles chaudes, rue de la zone 1 reprise à la sortie
local CREAM, CREAM_L, STONE = rgb(242, 232, 210), rgb(250, 244, 228), rgb(226, 214, 190)
local BRICK, TERRA, PLAZA, PAVE = rgb(186, 94, 70), rgb(196, 112, 82), rgb(200, 196, 188), rgb(238, 228, 205)
local NAVY, RED, GOLD, GOLD_L = rgb(34, 44, 82), rgb(214, 58, 52), rgb(232, 172, 44), rgb(255, 205, 60)
local GLASS_C, GLASS_D, DARK, STEEL = rgb(150, 205, 235), rgb(40, 52, 70), rgb(50, 56, 64), rgb(72, 78, 88)
local WHITE, LAMP_OFF, WARM = rgb(248, 248, 244), rgb(255, 238, 200), rgb(255, 214, 150)
local GRASS, HEDGE, LEAF, LEAF_L, LEAF_D = rgb(106, 186, 88), rgb(58, 140, 66), rgb(70, 168, 62), rgb(118, 200, 84), rgb(46, 128, 56)
local TRUNK, WOOD, SOIL, WATER = rgb(124, 92, 62), rgb(196, 146, 96), rgb(96, 70, 50), rgb(96, 176, 232)
local ASPHALT, LINE, KERB, STEEL_L, TIRE = rgb(64, 68, 76), rgb(240, 240, 236), rgb(206, 206, 202), rgb(205, 208, 214), rgb(34, 34, 38)
local STREET, PAVEMENT, KERB_W = rgb(60, 70, 94), rgb(240, 232, 214), rgb(246, 246, 242) -- les mêmes qu'en zone 1
local SAFE_C = rgb(255, 220, 60)
local FLOWERS = { rgb(255, 120, 170), rgb(255, 214, 60), RED, rgb(170, 110, 220), WHITE }

-- 1) Plan ---------------------------------------------------------------------------------------------------------
local E = Vector3.new(30, 0, 0) -- début de la zone 1 (arche ZoneGate_1), dans l'axe du couloir
local ROT = 0 -- rotation de l'arc autour de E, en degrés (0 = enseigne dans l'axe du couloir)
local D_C, D_S = 28, 60 -- E → centre de l'arc C, E → spawn S
local RC = 170 -- rayon des façades de boutiques, depuis C
local SHOP_W, SHOP_D, GAP = 64, 80, 8 -- emprise d'une boutique (avant = côté de 64), écart entre deux façades
local STEP = 2 * math.deg(math.atan((SHOP_W / 2 + GAP / 2) / RC)) -- 23,9° d'une boutique à l'autre
local RF = RC + SHOP_D + 8 -- façade du centre commercial (258)
local WALL_H = 20
local HUB = { x0 = -330, x1 = 30, z0 = -256, z1 = 256 }

local function rr(deg) local a = math.rad(deg + ROT); return Vector3.new(-math.cos(a), 0, math.sin(a)) end
local C = E + rr(0) * D_C
local S = E + rr(0) * D_S
local function at(deg, r) return C + rr(deg) * r end
local function facing(deg) return -rr(deg) end -- vers la place
local function frameAt(p, dir) return CFrame.lookAt(p, p + Vector3.new(dir.X, 0, dir.Z)) end -- LookVector = dir
local function shopAngle(k) return (3.5 - k) * STEP end -- PlotIndex k, 1 au nord (à gauche face au centre commercial)

local SITES = {}
for k = 1, 6 do
	local a = shopAngle(k)
	local center = at(a, RC + SHOP_D / 2)
	SITES[k] = { k = k, angle = a, front = at(a, RC), center = center, n = facing(a), cf = frameAt(center, facing(a)) }
end

local report = {}
local function add(s) table.insert(report, s) end

-- Zones réservées (pièces sautées) ---------------------------------------------------------------------------------
local function aabbOf(cf, size)
	local hx = math.abs(cf.RightVector.X) * size.X / 2 + math.abs(cf.UpVector.X) * size.Y / 2 + math.abs(cf.LookVector.X) * size.Z / 2
	local hy = math.abs(cf.RightVector.Y) * size.X / 2 + math.abs(cf.UpVector.Y) * size.Y / 2 + math.abs(cf.LookVector.Y) * size.Z / 2
	local hz = math.abs(cf.RightVector.Z) * size.X / 2 + math.abs(cf.UpVector.Z) * size.Y / 2 + math.abs(cf.LookVector.Z) * size.Z / 2
	return Vector3.new(cf.X - hx, cf.Y - hy, cf.Z - hz), Vector3.new(cf.X + hx, cf.Y + hy, cf.Z + hz)
end
local function boundsOf(inst)
	local mn, mx
	local list = inst:GetDescendants()
	if inst:IsA("BasePart") then table.insert(list, inst) end
	for _, d in list do
		if d:IsA("BasePart") then
			local a, b = aabbOf(d.CFrame, d.Size)
			mn = mn and mn:Min(a) or a; mx = mx and mx:Max(b) or b
		end
	end
	return mn, mx
end
-- Empreinte au sol d'une pièce (8 coins projetés) et axes de séparation (SAT en x-z)
local function footprint(cf, size)
	local pts = {}
	for _, sx in { -1, 1 } do for _, sy in { -1, 1 } do for _, sz in { -1, 1 } do
		local w = cf:PointToWorldSpace(Vector3.new(sx * size.X / 2, sy * size.Y / 2, sz * size.Z / 2))
		table.insert(pts, Vector2.new(w.X, w.Z))
	end end end
	local axes = { Vector2.new(1, 0), Vector2.new(0, 1) }
	for _, v in { cf.RightVector, cf.UpVector, cf.LookVector } do
		local d = Vector2.new(v.X, v.Z)
		if d.Magnitude > 1e-3 then table.insert(axes, Vector2.new(-d.Y, d.X).Unit) end
	end
	return pts, axes
end
local function overlaps(pts, axes, z)
	local zc = { Vector2.new(z.mn.X, z.mn.Z), Vector2.new(z.mx.X, z.mn.Z), Vector2.new(z.mn.X, z.mx.Z), Vector2.new(z.mx.X, z.mx.Z) }
	for _, a in axes do
		local amin, amax, bmin, bmax = math.huge, -math.huge, math.huge, -math.huge
		for _, p in pts do local d = p:Dot(a); amin = math.min(amin, d); amax = math.max(amax, d) end
		for _, p in zc do local d = p:Dot(a); bmin = math.min(bmin, d); bmax = math.max(bmax, d) end
		if amax <= bmin or bmax <= amin then return false end
	end
	return true
end
-- kind « reserved » (vitrine, qui a son propre plancher) : rien du hub ne s'y pose, pas même le sol ; « inbox » (un
-- objet livré) et « plot » (parcelle grise restée en place) : rien ne s'y pose, sauf le sol du hub, qui passe dessous.
local zones = {}
local function addZone(name, inst, margin, kind)
	if not inst then return end
	local mn, mx = boundsOf(inst)
	if mn then table.insert(zones, { name = name, kind = kind, mn = mn - Vector3.new(margin, 0, margin), mx = mx + Vector3.new(margin, 0, margin) }) end
end
local function zoneHit(cf, size, underOnly)
	if #zones == 0 then return nil end
	local pts, axes = footprint(cf, size)
	for _, z in zones do
		if not (underOnly and z.kind ~= "reserved") and overlaps(pts, axes, z) then return z.name end
	end
	return nil
end
local function blockedAt(pos, r) return zoneHit(CFrame.new(pos), Vector3.new(2 * r, 1, 2 * r)) end
addZone("_SHOWROOM_CLEMENT", workspace:FindFirstChild("_SHOWROOM_CLEMENT"), 2, "reserved")
local inboxF = workspace:FindFirstChild("_INBOX_CLEMENT")
if inboxF then for _, c in inboxF:GetChildren() do addZone("_INBOX_CLEMENT", c, 1.5, "inbox") end end

-- Pièces ---------------------------------------------------------------------------------------------------------
-- opt : shape, mat, studs (Plastic + MaterialVariant « Studs »), refl, T (transparence), decor (ni collision, ni
-- toucher, ni requête), noShadow, anywhere (posée même dans une zone réservée), under (sol : passe sous une parcelle).
-- group(cf, size) … ungroup() : un ensemble (panneau de façade, pilier, tour, mur) posé ou sauté d'un bloc.
local skipped, built = {}, 0
local skipGroup = nil
local function group(cf, size) skipGroup = zoneHit(cf, size) end
local function ungroup() skipGroup = nil end
local function P(parent, name, cf, size, color, opt)
	opt = opt or {}
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color; p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	if opt.shape then p.Shape = opt.shape end
	if opt.mat then p.Material = opt.mat
	elseif opt.studs then p.Material = Enum.Material.Plastic; p.MaterialVariant = "Studs"
	else p.Material = SMOOTH end
	if opt.refl then p.Reflectance = opt.refl end
	if opt.T then p.Transparency = opt.T end
	if opt.decor then p.CanCollide = false; p.CanTouch = false; p.CanQuery = false end
	if opt.noShadow then p.CastShadow = false end
	local z = skipGroup or ((not opt.anywhere) and zoneHit(cf, size, opt.under))
	if z then skipped[z] = (skipped[z] or 0) + 1; return p end
	p.Parent = parent; built += 1
	return p
end
local function with(opt, k, v) local o = opt and table.clone(opt) or {}; o[k] = v; return o end
local W = CFrame.identity
local ROT_UP = CFrame.Angles(0, 0, math.rad(90)) -- axe du cylindre à la verticale
local ROT_Z = CFrame.Angles(0, math.rad(90), 0) -- axe du cylindre le long de Z local
-- Pavé donné par deux coins, dans le repère frame
local function Bx(parent, frame, name, x0, y0, z0, x1, y1, z1, color, opt)
	local size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
	return P(parent, name, frame * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), size, color, opt)
end
local function Vc(parent, frame, name, x, y0, y1, z, dia, color, opt)
	return P(parent, name, frame * CFrame.new(x, (y0 + y1) / 2, z) * ROT_UP, Vector3.new(y1 - y0, dia, dia), color, with(opt, "shape", CYL))
end
local function Ball(parent, frame, name, x, y, z, dia, color, opt)
	return P(parent, name, frame * CFrame.new(x, y, z), Vector3.new(dia, dia, dia), color, with(opt, "shape", BALL))
end
-- Disque à plat (dallage), du sol (-0,05) à top
local function disc(parent, name, center, radius, top, color, opt)
	return Vc(parent, CFrame.new(center.X, 0, center.Z), name, 0, -0.05, top, 0, radius * 2, color, opt)
end
-- Bande à plat de a à b (allées, lignes)
local function strip(parent, name, a, b, width, top, color, opt)
	local y = (top - 0.05) / 2
	local pa, pb = Vector3.new(a.X, y, a.Z), Vector3.new(b.X, y, b.Z)
	return P(parent, name, CFrame.lookAt((pa + pb) / 2, pb), Vector3.new(width, top + 0.05, (pb - pa).Magnitude), color, opt)
end
local function nightLight(part, range, bright)
	local l = Instance.new("PointLight"); l.Range = range or 30; l.Brightness = bright or 1.4; l.Color = WARM
	l.Shadows = false; l.Enabled = false; l.Parent = part
	CS:AddTag(part, NIGHT_LIGHT)
end
local function sparkles(part, c0, c1, rate)
	local e = Instance.new("ParticleEmitter"); e.Name = "Sparkles"; e.Texture = SPARK
	e.Rate = rate or 10; e.Lifetime = NumberRange.new(1, 1.6); e.Speed = NumberRange.new(1.5, 3)
	e.SpreadAngle = Vector2.new(180, 180); e.LightEmission = 0.8
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new(0.1, 1); e.Color = ColorSequence.new(c0, c1)
	e.Parent = part
end

-- Textes (SurfaceGui, sans script)
local function surface(part, face, pps)
	local g = Instance.new("SurfaceGui"); g.Name = "Gui_" .. face.Name; g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = pps or 20; g.LightInfluence = 0
	g.Parent = part
	return g
end
local function txt(gui, text, color, x, y, w, h, opt)
	opt = opt or {}
	local t = Instance.new("TextLabel"); t.Name = opt.name or "Label"; t.BackgroundTransparency = 1
	t.AnchorPoint = opt.anchor or Vector2.zero
	t.Position = UDim2.fromScale(x, y); t.Size = opt.size or UDim2.fromScale(w, h)
	t.Text = text; t.TextScaled = true; t.TextWrapped = true; t.TextColor3 = color; t.FontFace = opt.font or MONT
	if opt.rotation then t.Rotation = opt.rotation end
	if opt.strokeT ~= 0 then
		local s = Instance.new("UIStroke"); s.Color = opt.strokeC or rgb(24, 24, 32); s.Thickness = opt.strokeT or 3
		s.LineJoinMode = Enum.LineJoinMode.Round; s.Parent = t
	end
	t.Parent = gui
	return t
end

-- Mobilier ----------------------------------------------------------------------------------------------------------
local function lamp(parent, name, pos, h)
	h = h or 15
	if blockedAt(pos, 1.6) then return end
	local m = Instance.new("Model"); m.Name = name
	local f = CFrame.new(pos)
	Bx(m, f, "Base", -1, 0, -1, 1, 1.2, 1, DARK, { studs = true })
	Vc(m, f, "Pole", 0, 1.2, h, 0, 0.7, DARK, {})
	nightLight(Bx(m, f, "Lantern", -1, h, -1, 1, h + 2.6, 1, LAMP_OFF, { decor = true }), 34, 1.5)
	Bx(m, f, "Cap", -1.4, h + 2.6, -1.4, 1.4, h + 3.1, 1.4, DARK, { decor = true })
	Ball(m, f, "Finial", 0, h + 3.5, 0, 0.8, DARK, { decor = true })
	m.Parent = parent
end
-- Lanterne murale dans le repère f (-Z local = côté place)
local function wallLantern(parent, f, name, x, y)
	Bx(parent, f, name .. "_Arm", x - 0.3, y + 2.2, -1.6, x + 0.3, y + 2.6, 0, DARK, { decor = true })
	nightLight(Bx(parent, f, name, x - 0.9, y, -2.5, x + 0.9, y + 2.4, -0.7, LAMP_OFF, { decor = true }), 24, 1.3)
	Bx(parent, f, name .. "_Cap", x - 1.1, y + 2.4, -2.7, x + 1.1, y + 2.8, -0.5, DARK, { decor = true })
end
local function tree(parent, name, pos, sc)
	sc = sc or 1
	if blockedAt(pos, 5.5 * sc) then return end
	local m = Instance.new("Model"); m.Name = name
	local f = CFrame.new(pos)
	Vc(m, f, "Planter", 0, 0, 2.2, 0, 8 * sc, STONE, { studs = true })
	Vc(m, f, "Soil", 0, 2.2, 2.32, 0, 7 * sc, SOIL, { decor = true })
	Bx(m, f, "Trunk", -0.8 * sc, 2.2, -0.8 * sc, 0.8 * sc, 11 * sc, 0.8 * sc, TRUNK, {})
	Ball(m, f, "Leaves_1", 0, 13.5 * sc, 0, 10 * sc, LEAF, { decor = true })
	Ball(m, f, "Leaves_2", 2.6 * sc, 15.8 * sc, 1.2 * sc, 7 * sc, LEAF_L, { decor = true })
	Ball(m, f, "Leaves_3", -2.4 * sc, 15 * sc, -1.8 * sc, 6.6 * sc, LEAF_D, { decor = true })
	m.Parent = parent
end
-- Banc : cf au sol, LookVector = vers où regarde la personne assise
local function bench(parent, name, cf)
	if blockedAt(cf.Position, 4) then return end
	local m = Instance.new("Model"); m.Name = name
	Bx(m, cf, "Seat", -3.5, 1.8, -1.1, 3.5, 2.3, 1.1, WOOD, {})
	Bx(m, cf, "Back", -3.5, 2.3, 1.0, 3.5, 4.2, 1.4, WOOD, { decor = true })
	Bx(m, cf, "Leg_L", -3.1, 0, -0.9, -2.5, 1.8, 1.3, DARK, { decor = true })
	Bx(m, cf, "Leg_R", 2.5, 0, -0.9, 3.1, 1.8, 1.3, DARK, { decor = true })
	m.Parent = parent
end
local function picnic(parent, name, pos, canopy)
	if blockedAt(pos, 5) then return end
	local m = Instance.new("Model"); m.Name = name
	local f = CFrame.new(pos)
	Bx(m, f, "Top", -3.2, 2.8, -2, 3.2, 3.2, 2, WOOD, {})
	Bx(m, f, "SeatA", -3.2, 1.6, -3.9, 3.2, 2.0, -2.9, WOOD, {})
	Bx(m, f, "SeatB", -3.2, 1.6, 2.9, 3.2, 2.0, 3.9, WOOD, {})
	Bx(m, f, "Frame_L", -2.8, 0, -3.6, -2.4, 2.8, 3.6, DARK, { decor = true })
	Bx(m, f, "Frame_R", 2.4, 0, -3.6, 2.8, 2.8, 3.6, DARK, { decor = true })
	Vc(m, f, "UmbrellaPole", 0, 3.2, 9.4, 0, 0.35, WHITE, { decor = true })
	Vc(m, f, "Umbrella", 0, 8.9, 9.4, 0, 8.4, canopy, { decor = true })
	Ball(m, f, "UmbrellaTop", 0, 9.6, 0, 0.7, WHITE, { decor = true })
	m.Parent = parent
end
local function flowerBed(parent, name, pos)
	if blockedAt(pos, 5) then return end
	local f = CFrame.new(pos)
	Bx(parent, f, name, -4, 0, -2, 4, 0.7, 2, SOIL, { studs = true })
	for i = 0, 5 do
		Ball(parent, f, name .. "_Flower" .. (i + 1), -3 + i * 1.2, 1.15, (i % 2 == 0) and -0.8 or 0.8, 1.1, FLOWERS[(i % #FLOWERS) + 1], { decor = true })
	end
end
-- Voiture : cf au sol, LookVector = avant
local function car(parent, name, cf, color)
	if blockedAt(cf.Position, 9) then return end
	local m = Instance.new("Model"); m.Name = name
	Bx(m, cf, "Body", -4.2, 1.0, -8.5, 4.2, 3.6, 8.5, color, { studs = true })
	Bx(m, cf, "Cabin", -3.7, 3.6, -3.4, 3.7, 6.1, 4.2, GLASS_D, { decor = true, refl = 0.25 })
	Bx(m, cf, "Roof", -3.9, 6.1, -3.2, 3.9, 6.7, 4.0, color, { decor = true, studs = true })
	for i, w in { { -3.75, -5.6 }, { 3.75, -5.6 }, { -3.75, 5.6 }, { 3.75, 5.6 } } do
		P(m, "Wheel_" .. i, cf * CFrame.new(w[1], 1.4, w[2]), Vector3.new(1.2, 2.8, 2.8), TIRE, { shape = CYL, decor = true })
	end
	Bx(m, cf, "Headlight_L", -3.6, 2.4, -8.65, -2.3, 3.1, -8.45, rgb(255, 246, 214), { decor = true })
	Bx(m, cf, "Headlight_R", 2.3, 2.4, -8.65, 3.6, 3.1, -8.45, rgb(255, 246, 214), { decor = true })
	Bx(m, cf, "Taillight_L", -3.6, 2.4, 8.45, -2.3, 3.1, 8.65, rgb(200, 40, 40), { decor = true })
	Bx(m, cf, "Taillight_R", 2.3, 2.4, 8.45, 3.6, 3.1, 8.65, rgb(200, 40, 40), { decor = true })
	m.Parent = parent
end
local function cart(parent, name, cf)
	local m = Instance.new("Model"); m.Name = name
	local MET = rgb(180, 186, 194)
	Bx(m, cf, "Bottom", -1.2, 1.4, -1.8, 1.2, 1.5, 1.8, MET, {})
	Bx(m, cf, "Side_L", -1.25, 1.5, -1.8, -1.15, 3.2, 1.8, MET, { decor = true })
	Bx(m, cf, "Side_R", 1.15, 1.5, -1.8, 1.25, 3.2, 1.8, MET, { decor = true })
	Bx(m, cf, "Front", -1.2, 1.5, -1.9, 1.2, 3.2, -1.8, MET, { decor = true })
	Bx(m, cf, "Back", -1.2, 1.5, 1.8, 1.2, 3.2, 1.9, MET, { decor = true })
	Bx(m, cf, "Handle", -1.3, 3.5, 2.2, 1.3, 3.8, 2.5, RED, { decor = true })
	Bx(m, cf, "HandleArm_L", -1.25, 3.0, 1.85, -1.15, 3.6, 2.35, MET, { decor = true })
	Bx(m, cf, "HandleArm_R", 1.15, 3.0, 1.85, 1.25, 3.6, 2.35, MET, { decor = true })
	for i, w in { { -1, -1.5 }, { 1, -1.5 }, { -1, 1.5 }, { 1, 1.5 } } do
		Ball(m, cf, "Wheel_" .. i, w[1], 0.35, w[2], 0.7, TIRE, { decor = true })
		Bx(m, cf, "Leg_" .. i, w[1] - 0.06, 0.6, w[2] - 0.06, w[1] + 0.06, 1.4, w[2] + 0.06, MET, { decor = true })
	end
	m.Parent = parent
end

-- 2) Parcelles grises sur leurs emplacements -----------------------------------------------------------------------
local gb = workspace:FindFirstChild("Greybox")
local safeG = gb and gb:FindFirstChild("Safe")
local plotsFolder = safeG and safeG:FindFirstChild("Plots")
local moved, kept = {}, {}
local function frontFrameOf(plot) -- centre de l'emprise au sol, LookVector = avant (vitrine)
	local b, w = plot:FindFirstChild("Bounds"), plot:FindFirstChild("Window")
	if not (b and w and b:IsA("BasePart") and w:IsA("BasePart")) then return nil end
	local c = Vector3.new(b.Position.X, 0, b.Position.Z)
	local d = Vector3.new(w.Position.X - c.X, 0, w.Position.Z - c.Z)
	if d.Magnitude < 1 then return nil end
	return CFrame.lookAt(c, c + d.Unit)
end
if plotsFolder then
	for _, plot in CS:GetTagged("PlayerPlot") do
		if plot:IsDescendantOf(plotsFolder) and plot:IsA("Model") then
			local site = SITES[plot:GetAttribute("PlotIndex")]
			local ff = frontFrameOf(plot)
			if site and ff then
				local hit = zoneHit(site.cf * CFrame.new(0, 12, 0), Vector3.new(SHOP_W, 24, SHOP_D))
				if hit then
					table.insert(kept, plot.Name .. " (emplacement " .. site.k .. " sur " .. hit .. ")")
					addZone(plot.Name, plot, 1, "plot") -- reste en place : rien du hub ne la recouvre, sauf le sol
				else
					plot:PivotTo(site.cf * ff:Inverse() * plot:GetPivot())
					table.insert(moved, site.k)
				end
			end
		end
	end
end
table.sort(moved)
add("Parcelles grises posées sur leur emplacement : " .. (#moved > 0 and table.concat(moved, ", ") or "aucune")
	.. (#kept > 0 and (" ; restées en place : " .. table.concat(kept, ", ")) or ""))

-- 3) Construction -----------------------------------------------------------------------------------------------------
local map = workspace:FindFirstChild("Map")
assert(map, "Workspace/Map introuvable")
local hub = map:FindFirstChild("Hub")
if not hub then hub = Instance.new("Folder"); hub.Name = "Hub"; hub.Parent = map end
local OWN = { "Ground", "Plaza", "Mall", "Trucks", "Parking", "Garden", "Walls", "PlotSites", "SafeZone", "Spawn" }
for _, n in OWN do
	for _, c in hub:GetChildren() do if c.Name == n then c:Destroy() end end
end
local F = { studs = true, noShadow = true } -- dallages
local function section(name) local m = Instance.new("Model"); m.Name = name; return m end
local function done(m) m.Parent = hub; task.wait() end
-- Dalle de sol (dessus à y = top), découpée en rectangles autour des zones « reserved » (la vitrine a son plancher)
local function ground(parent, name, x0, z0, x1, z1, color, top)
	top = top or 0
	local rects = { { x0, z0, x1, z1 } }
	for _, zn in zones do
		if zn.kind == "reserved" then
			local nxt = {}
			for _, r in rects do
				local a0, b0, a1, b1 = r[1], r[2], r[3], r[4]
				local zx0, zz0, zx1, zz1 = zn.mn.X, zn.mn.Z, zn.mx.X, zn.mx.Z
				if zx1 <= a0 or zx0 >= a1 or zz1 <= b0 or zz0 >= b1 then
					table.insert(nxt, r)
				else
					local mb0, mb1 = math.max(b0, zz0), math.min(b1, zz1)
					if zz0 > b0 then table.insert(nxt, { a0, b0, a1, zz0 }) end
					if zz1 < b1 then table.insert(nxt, { a0, zz1, a1, b1 }) end
					if zx0 > a0 then table.insert(nxt, { a0, mb0, zx0, mb1 }) end
					if zx1 < a1 then table.insert(nxt, { zx1, mb0, a1, mb1 }) end
				end
			end
			rects = nxt
		end
	end
	for i, r in rects do
		Bx(parent, W, #rects == 1 and name or (name .. "_" .. i), r[1], -2, r[2], r[3], top, r[4], color, { studs = true, noShadow = true, under = true })
	end
end

-- Sol : place, flancs, et sortie dans l'axe du couloir (rue, trottoirs à 0,45, rail du mur de nuit à plat)
do
	local g = section("Ground")
	local O = { studs = true, noShadow = true, under = true }
	ground(g, "Ground_Plaza", HUB.x0, HUB.z0, 0, 180, PLAZA)
	ground(g, "Ground_North_W", HUB.x0, 180, -202, HUB.z1, PLAZA)
	ground(g, "Ground_North_M", -202, 180, -38, HUB.z1, PLAZA)
	ground(g, "Ground_North_E", -38, 180, 0, HUB.z1, PLAZA)
	ground(g, "Ground_Flank_N", 0, 34.5, 30, HUB.z1, PLAZA)
	ground(g, "Ground_Flank_S", 0, HUB.z0, 30, -34.5, PLAZA)
	ground(g, "Ground_ExitStreet", 0, -22.5, 30, 22.5, STREET)
	for _, s in { 1, -1 } do
		local tag = s > 0 and "N" or "S"
		local function zz(a, b) return math.min(a * s, b * s), math.max(a * s, b * s) end
		local z0, z1 = zz(22.5, 23.25)
		Bx(g, W, "Ground_ExitKerb_" .. tag, 0, -2, z0, 25.4, 0.45, z1, KERB_W, O)
		z0, z1 = zz(23.25, 34.5)
		Bx(g, W, "Ground_ExitSidewalk_" .. tag, 0, -2, z0, 25.4, 0.45, z1, PAVEMENT, O)
		z0, z1 = zz(22.5, 34.5)
		Bx(g, W, "Ground_WallTrack_" .. tag, 25.4, -2, z0, 30, 0, z1, STEEL, O) -- là où monte le mur de nuit
		z0, z1 = zz(22.5, 34.5)
		Bx(g, W, "SafeLine_" .. tag, 21.4, 0.44, z0, 22.6, 0.5, z1, SAFE_C, { decor = true, noShadow = true })
	end
	Bx(g, W, "SafeLine", 21.4, -0.01, -22.5, 22.6, 0.05, 22.5, SAFE_C, { decor = true, noShadow = true })
	local plate = P(g, "SafeZoneText", CFrame.lookAt(Vector3.new(16, 0.03, 0), Vector3.new(15, 0.03, 0)), Vector3.new(32, 0.05, 7), SAFE_C,
		{ T = 1, decor = true, noShadow = true })
	txt(surface(plate, TOP, 20), "SAFE ZONE", SAFE_C, 0, 0, 1, 1, { font = LUCKY, strokeT = 4 })
	done(g)
end

-- Place : rosace du spawn, allées vers chaque boutique, anneau, seuils, fontaine, arbres, bancs, lampadaires
do
	local m = section("Plaza")
	disc(m, "SpawnRing_Outer", S, 30, 0.06, PAVE, F)
	disc(m, "SpawnRing_Band", S, 26, 0.15, TERRA, F)
	disc(m, "SpawnRing_Inner", S, 22, 0.19, PAVE, F)
	for k = 1, 6 do -- un rayon par boutique
		local d = (SITES[k].front - S).Unit
		strip(m, "SpawnRay_" .. k, S + d * 13, S + d * 21, 2.2, 0.22, BRICK, F)
	end
	Vc(m, CFrame.new(S), "SpawnDais", 0, 0, 0.5, 0, 26, STONE, { studs = true })
	Vc(m, CFrame.new(S), "SpawnDaisTop", 0, 0.5, 0.9, 0, 20, GOLD, { studs = true })
	for i = 0, 7 do
		local a = math.rad(22.5 + i * 45)
		local f = CFrame.new(S + Vector3.new(math.cos(a), 0, math.sin(a)) * 16.5)
		Vc(m, f, "Bollard_" .. (i + 1), 0, 0, 2.4, 0, 1.3, DARK, { studs = true })
		nightLight(Vc(m, f, "BollardLight_" .. (i + 1), 0, 2.4, 3.0, 0, 1.1, LAMP_OFF, { decor = true }), 12, 0.8)
	end
	-- anneau de dalles à 95 studs du spawn (hauteurs alternées : pas de scintillement aux recouvrements)
	local A0, A1, N, R = -100, 100, 24, 95
	local da = (A1 - A0) / N
	for i = 0, N - 1 do
		local a = A0 + (i + 0.5) * da
		local p = S + rr(a) * R
		local top = (i % 2 == 0) and 0.06 or 0.09
		local c = Vector3.new(p.X, (top - 0.05) / 2, p.Z)
		P(m, "OuterRing_" .. (i + 1), CFrame.lookAt(c, c + rr(a + 90)), Vector3.new(6, top + 0.05, 2 * R * math.sin(math.rad(da / 2)) + 0.6), PAVE, F)
	end
	for k = 1, 6 do
		local site = SITES[k]
		local d = site.front - S
		local len = d.Magnitude; d = d.Unit
		local a, b = S + d * 29.5, S + d * (len - 4)
		local side = Vector3.new(-d.Z, 0, d.X)
		strip(m, "Walkway_" .. k, a, b, 10, 0.12, PAVE, F)
		strip(m, "WalkwayEdge_" .. k .. "L", a + side * 5.6, b + side * 5.6, 1.2, 0.12, BRICK, F)
		strip(m, "WalkwayEdge_" .. k .. "R", a - side * 5.6, b - side * 5.6, 1.2, 0.12, BRICK, F)
		P(m, "Doorstep_" .. k, frameAt(at(site.angle, RC - 4), site.n) * CFrame.new(0, 0.05, 0), Vector3.new(68, 0.2, 8), TERRA, F)
		for j, off in { -9.5, 9.5 } do lamp(m, "Lamp_Walk" .. k .. "_" .. j, S + d * R + side * off) end
	end
	for i, a in { 29, 56.6, -29, -56.6, 100, -100 } do lamp(m, "Lamp_Spawn_" .. i, S + rr(a) * 36) end
	for i, a in { 29, 56.6, -29, -56.6, 85, -85 } do tree(m, "Tree_Ring_" .. i, S + rr(a) * R) end
	for i, a in { 29, 56.6, -29, -56.6 } do tree(m, "Tree_Inner_" .. i, S + rr(a) * 58, 0.85) end
	for i, a in { 29, 56.6, -29, -56.6 } do
		for j, off in { -8.5, 8.5 } do
			local p = S + rr(a) * R + rr(a + 90) * off
			bench(m, "Bench_" .. i .. "_" .. j, frameAt(p, S - p))
		end
	end
	for i, p in { Vector3.new(-12, 0, 72), Vector3.new(-26, 0, 64), Vector3.new(-12, 0, -72), Vector3.new(-26, 0, -64) } do
		picnic(m, "PicnicTable_" .. i, p, (i % 2 == 1) and RED or NAVY)
	end
	-- fontaine dans l'axe, entre le spawn et l'entrée du centre commercial : colis doré au sommet
	local fc = S + rr(0) * R
	local ff = CFrame.new(fc)
	for i = 0, 19 do
		local a = math.rad(i * 18)
		local p = fc + Vector3.new(math.cos(a), 0, math.sin(a)) * 12.4 + Vector3.new(0, 1.3, 0)
		P(m, "FountainRim_" .. (i + 1), CFrame.lookAt(p, p + Vector3.new(-math.sin(a), 0, math.cos(a))), Vector3.new(1.8, 2.6, 4.1), STONE, { studs = true })
	end
	Vc(m, ff, "FountainFloor", 0, -0.05, 0.03, 0, 23, rgb(70, 140, 200), { decor = true, noShadow = true })
	Vc(m, ff, "FountainWater", 0, 0.03, 1.7, 0, 23.6, WATER, { T = 0.25, refl = 0.2, decor = true, noShadow = true })
	for i = 1, 6 do
		local a = math.rad(i * 61)
		Vc(m, ff, "Coin_" .. i, math.cos(a) * (3 + i), 0.03, 0.12, math.sin(a) * (3 + i), 0.9, GOLD_L, { decor = true, noShadow = true })
	end
	Vc(m, ff, "FountainColumn", 0, 0, 6.5, 0, 3.2, STONE, { studs = true })
	Vc(m, ff, "FountainBowl", 0, 6.0, 6.9, 0, 11, STONE, { studs = true })
	Vc(m, ff, "FountainBowlWater", 0, 6.9, 7.0, 0, 9.6, WATER, { decor = true, noShadow = true })
	Vc(m, ff, "FountainPedestal", 0, 6.9, 8.6, 0, 2.6, STONE, { studs = true })
	Bx(m, ff, "GoldenBox", -2.2, 8.6, -2.2, 2.2, 12.2, 2.2, GOLD_L, { refl = 0.25 })
	Bx(m, ff, "GoldenBox_TapeX", -2.25, 8.6, -0.45, 2.25, 12.3, 0.45, GOLD, { decor = true })
	Bx(m, ff, "GoldenBox_TapeZ", -0.45, 8.6, -2.25, 0.45, 12.35, 2.25, GOLD, { decor = true })
	local jet = Bx(m, ff, "FountainJet", -2.5, 7.0, -2.5, 2.5, 7.2, 2.5, WATER, { T = 1, decor = true, noShadow = true })
	local e = Instance.new("ParticleEmitter"); e.Name = "Spray"; e.Texture = SPARK; e.EmissionDirection = TOP
	e.Rate = 60; e.Lifetime = NumberRange.new(0.9, 1.2); e.Speed = NumberRange.new(9, 12); e.SpreadAngle = Vector2.new(14, 14)
	e.Acceleration = Vector3.new(0, -30, 0); e.LightEmission = 0.3
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.15) })
	e.Transparency = NumberSequence.new(0.15, 1); e.Color = ColorSequence.new(rgb(235, 248, 255), rgb(150, 210, 245))
	e.Parent = jet
	done(m)
end

-- Centre commercial : façade en arc derrière les boutiques, tour centrale à l'enseigne, piliers, tours d'angle
do
	local m = section("Mall")
	local O = { studs = true }
	for i = 0, 25 do
		local phi = -75 + i * 6
		if math.abs(phi) > 12 then
			local f = frameAt(at(phi, RF), facing(phi))
			local n = "Facade_" .. string.format("%+03d", phi)
			group(f * CFrame.new(0, 36, 20), Vector3.new(34, 72, 42))
			Bx(m, f, n, -17, 0, 0, 17, 72, 40, CREAM, O) -- 40 de profondeur : les bouts de l'arc restent sous z ≈ 292
			Bx(m, f, n .. "_Course", -14, 30, -1.2, 14, 32.2, 0, BRICK, O)
			Bx(m, f, n .. "_Window1", -11, 35, -0.3, 11, 46, 0, GLASS_C, { mat = GLASS, refl = 0.15 })
			Bx(m, f, n .. "_Band", -14, 48, -0.8, 14, 50, 0, BRICK, O)
			Bx(m, f, n .. "_Window2", -11, 52, -0.3, 11, 63, 0, GLASS_C, { mat = GLASS, refl = 0.15 })
			Bx(m, f, n .. "_BandTop", -14, 65, -0.8, 14, 67, 0, BRICK, O)
			Bx(m, f, n .. "_Cornice", -14.6, 70, -2.4, 14.6, 73.2, 0, CREAM_L, O)
			Bx(m, f, n .. "_Pilaster", -15.1, 30, -1.6, -12, 70, 0, BRICK, O)
			ungroup()
		end
	end
	-- tour centrale : atrium vitré, enseigne à ampoules, ruban, couronne et drapeaux
	local tf = frameAt(at(0, RF - 4), facing(0))
	Bx(m, tf, "Tower", -55, 0, 0, 55, 114, 56, CREAM, O)
	Bx(m, tf, "Tower_CornerL", -56, 0, -1.2, -52.5, 114, 1, BRICK, O)
	Bx(m, tf, "Tower_CornerR", 52.5, 0, -1.2, 56, 114, 1, BRICK, O)
	Bx(m, tf, "Tower_Course", -55, 28, -1.4, 55, 30, 0, BRICK, O)
	Bx(m, tf, "Tower_Atrium", -44, 30, -0.4, 44, 66, 0, GLASS_C, { mat = GLASS, refl = 0.2 })
	for i = 0, 8 do
		local x = -44 + i * 11
		Bx(m, tf, "Tower_Mullion_" .. (i + 1), x - 0.7, 30, -0.9, x + 0.7, 66, 0, DARK, { decor = true })
	end
	for i, y in { 42, 54 } do Bx(m, tf, "Tower_Transom_" .. i, -44, y - 0.5, -0.9, 44, y + 0.5, 0, DARK, { decor = true }) end
	Bx(m, tf, "Tower_Band", -55, 66, -1.4, 55, 69, 0, BRICK, O)
	local board = Bx(m, tf, "SignBoard", -36, 72, -1.0, 36, 104, -0.2, NAVY, {})
	local sg = surface(board, FRONT, 12)
	txt(sg, "STEAL A", GOLD_L, 0.06, 0.05, 0.88, 0.36, { font = LUCKY, strokeT = 6, strokeC = rgb(18, 16, 28) })
	txt(sg, "SHOP", GOLD_L, 0.04, 0.38, 0.92, 0.58, { font = LUCKY, strokeT = 8, strokeC = rgb(18, 16, 28) })
	Bx(m, tf, "SignFrame_Top", -38, 104, -1.6, 38, 106, 0, GOLD, O)
	Bx(m, tf, "SignFrame_Bottom", -38, 70, -1.6, 38, 72, 0, GOLD, O)
	Bx(m, tf, "SignFrame_L", -38, 72, -1.6, -36, 104, 0, GOLD, O)
	Bx(m, tf, "SignFrame_R", 36, 72, -1.6, 38, 104, 0, GOLD, O)
	local nb, BULB = 0, rgb(255, 240, 190)
	for i = 0, 14 do
		for _, y in { 71, 105 } do nb += 1; Ball(m, tf, "Bulb_" .. nb, -35 + i * 5, y, -1.9, 1.4, BULB, { mat = NEON, decor = true, noShadow = true }) end
	end
	for _, x in { -37, 37 } do
		for j = 0, 4 do nb += 1; Ball(m, tf, "Bulb_" .. nb, x, 76 + j * 6, -1.9, 1.4, BULB, { mat = NEON, decor = true, noShadow = true }) end
	end
	local ribbon = Bx(m, tf, "TaglineRibbon", -30, 107.5, -1.0, 30, 113, -0.2, RED, {})
	txt(surface(ribbon, FRONT, 12), "EVERYTHING MUST GO!", WHITE, 0.03, 0.1, 0.94, 0.8, { strokeT = 3 })
	Bx(m, tf, "Tower_Crown", -56.5, 114, -2.5, 56.5, 117.5, 58, CREAM_L, O)
	for j, x in { -50, 50 } do
		Vc(m, tf, "Tower_Flagpole_" .. j, x, 117.5, 135, 8, 0.6, DARK, { decor = true })
		Bx(m, tf, "Tower_Flag_" .. j, x + 0.3, 128.5, 7.88, x + 8.3, 133.5, 8.12, j == 1 and NAVY or RED, { decor = true })
		Bx(m, tf, "Tower_FlagStripe_" .. j, x + 0.3, 130.5, 7.86, x + 8.3, 131.5, 8.14, GOLD_L, { decor = true })
	end
	-- piliers entre deux boutiques (ferment l'écart entre les façades)
	for k = 1, 5 do
		local a = (shopAngle(k) + shopAngle(k + 1)) / 2
		local f = frameAt(at(a, RC + 1.5), facing(a))
		local n = "Pier_" .. k
		group(f * CFrame.new(0, 17, 41), Vector3.new(9, 36, 96))
		Bx(m, f, n, -3.5, 0, 0, 3.5, 34, 88.5, CREAM, O)
		Bx(m, f, n .. "_Plinth", -3.8, 0, -0.6, 3.8, 3, 1, BRICK, O)
		Bx(m, f, n .. "_Cap", -3.8, 34, -1.2, 3.8, 35.6, 60, BRICK, O)
		Bx(m, f, n .. "_Apron", -4.5, -0.05, -6, 4.5, 0.18, 0, BRICK, F)
		Bx(m, f, n .. "_Banner", -2.6, 19, -0.5, 2.6, 31, -0.15, (k % 2 == 1) and NAVY or RED, { decor = true })
		Bx(m, f, n .. "_BannerStripe", -2.6, 20.2, -0.56, 2.6, 21.2, -0.45, GOLD_L, { decor = true })
		Bx(m, f, n .. "_BannerRod", -3, 31, -0.8, 3, 31.4, -0.1, DARK, { decor = true })
		wallLantern(m, f, n .. "_Lantern", 0, 14)
		ungroup()
	end
	-- tours d'angle, au bout de l'arc : horloge et bannière « OPEN 24/7 »
	for _, s in { 1, -1 } do
		local a = s * 74.3
		local tag = s > 0 and "N" or "S"
		local f = frameAt(at(a, RC + 1.5), facing(a))
		local n = "EndTower_" .. tag
		group(f * CFrame.new(0, 44, 46), Vector3.new(24, 88, 100))
		Bx(m, f, n, -10.6, 0, 0, 10.6, 80, 94.5, CREAM, O)
		Bx(m, f, n .. "_QuoinL", -11, 0, -0.6, -9, 80, 1, BRICK, O)
		Bx(m, f, n .. "_QuoinR", 9, 0, -0.6, 11, 80, 1, BRICK, O)
		Bx(m, f, n .. "_Cornice", -11.6, 80, -1.6, 11.6, 82.4, 60, CREAM_L, O)
		Bx(m, f, n .. "_Cap", -7, 82.4, 4, 7, 88, 30, BRICK, O)
		P(m, n .. "_ClockRim", f * CFrame.new(0, 66, -0.25) * ROT_Z, Vector3.new(0.5, 13, 13), BRICK, { shape = CYL })
		P(m, n .. "_ClockFace", f * CFrame.new(0, 66, -0.55) * ROT_Z, Vector3.new(0.3, 11.4, 11.4), WHITE, { shape = CYL, decor = true })
		for j, h in { { 58, 3.4, 0.7 }, { -58, 4.8, 0.5 } } do
			P(m, n .. "_ClockHand" .. j, f * CFrame.new(0, 66, -0.8) * CFrame.Angles(0, 0, math.rad(h[1])) * CFrame.new(0, h[2] / 2, 0),
				Vector3.new(h[3], h[2], 0.15), DARK, { decor = true })
		end
		local ban = Bx(m, f, n .. "_Banner", -5, 16, -0.6, 5, 52, -0.2, NAVY, {})
		txt(surface(ban, FRONT, 20), "OPEN 24/7", GOLD_L, 0.5, 0.5, 0, 0,
			{ size = UDim2.fromOffset(680, 170), anchor = Vector2.new(0.5, 0.5), rotation = -90, font = LUCKY, strokeT = 4 })
		for j, x in { -6.5, 6.5 } do wallLantern(m, f, n .. "_Lantern" .. j, x, 10) end
		ungroup()
	end
	done(m)
end

-- Food trucks : les 4 comptoirs, de part et d'autre de la sortie, guichet tourné vers la place ---------------------------
-- Pivot au sol au milieu du camion, LookVector = côté du guichet. Longueur sur X local (26), largeur sur Z local (11).
-- cab = +1 : cabine à +X local (vers la sortie pour les camions du nord), -1 : à -X local.
local TRUCKS = {
	{ name = "ENV_Hub_WeaponTruck", tag = "WeaponShop", pos = Vector3.new(12, 0, 55), cab = 1, icon = "bat",
		title = "WEAPONS", tagline = "SMASH MORE GLASS!", menu = "TOOLS · UPGRADES",
		main = rgb(214, 56, 50), second = rgb(46, 50, 58), band = rgb(255, 196, 40), bandText = rgb(30, 30, 36),
		stripes = { rgb(214, 56, 50), WHITE }, titleColor = rgb(255, 205, 60), signBg = rgb(30, 32, 40),
		items = { { -9, -6, 1.2, rgb(150, 150, 160) }, { -4, -1, 0.8, rgb(214, 56, 50) }, { 0, 2.5, 1.6, WOOD } } },
	{ name = "ENV_Hub_RobuxTruck", tag = "RobuxShop", pos = Vector3.new(12, 0, 87), cab = 1, icon = "coin",
		title = "ROBUX", tagline = "BOOSTS & PASSES", menu = "DEALS OF THE DAY",
		main = rgb(255, 196, 40), second = WHITE, band = rgb(40, 44, 54), bandText = rgb(255, 214, 70),
		stripes = { rgb(255, 196, 40), WHITE }, titleColor = rgb(255, 214, 70), signBg = rgb(30, 32, 40),
		items = { { -9, -6.5, 1.6, GOLD_L }, { -5, -2.5, 1.0, GOLD_L }, { 0, 2.5, 2.0, rgb(80, 200, 110) } } },
	{ name = "ENV_Hub_AuraTruck", tag = "AuraShop", pos = Vector3.new(12, 0, -55), cab = -1, icon = "orb",
		title = "AURAS", tagline = "GLOW UP · RUN FASTER", menu = "AURAS · TRAILS",
		main = rgb(132, 84, 224), second = rgb(64, 204, 226), band = rgb(255, 120, 200), bandText = WHITE,
		stripes = { rgb(132, 84, 224), WHITE }, titleColor = rgb(120, 236, 255), signBg = rgb(36, 26, 64),
		items = { { -9, -7.5, 1.8, rgb(170, 110, 255) }, { -5, -3.5, 1.4, rgb(90, 230, 255) }, { -1, 0.5, 1.8, rgb(255, 120, 200) } }, glowItems = true },
	{ name = "ENV_Hub_PawnTruck", tag = "PawnShop", pos = Vector3.new(12, 0, -87), cab = -1, icon = "balls",
		title = "PAWN SHOP", tagline = "WE BUY ANYTHING. NO QUESTIONS.", menu = "CASH FOR LOOT",
		main = rgb(34, 116, 78), second = rgb(232, 182, 60), band = CREAM, bandText = rgb(22, 70, 46),
		stripes = { rgb(34, 116, 78), CREAM }, titleColor = rgb(255, 214, 90), signBg = rgb(22, 52, 38),
		items = { { -9, -5.5, 2.2, rgb(60, 60, 70) }, { -4, -2, 1.4, GOLD_L }, { 0, 3, 1.0, rgb(196, 146, 96) } } },
}
local function truck(parent, t)
	local cf = frameAt(t.pos, Vector3.new(-1, 0, 0)) -- guichet vers l'ouest (la place)
	local s = t.cab
	local m = Instance.new("Model"); m.Name = t.name
	local function B(name, x0, y0, z0, x1, y1, z1, color, opt) return Bx(m, cf, name, x0 * s, y0, z0, x1 * s, y1, z1, color, opt) end
	local MO = { studs = true }
	B("Chassis", -12.6, 1.3, -5.0, 12.6, 2.6, 5.0, DARK, MO)
	for i, w in { { 9, -4.6 }, { 9, 4.6 }, { -8.2, -4.6 }, { -8.2, 4.6 } } do
		local wcf = cf * CFrame.new(w[1] * s, 2.1, w[2]) * ROT_Z
		P(m, "Wheel_" .. i, wcf, Vector3.new(1.6, 4.2, 4.2), TIRE, { shape = CYL })
		P(m, "Hubcap_" .. i, wcf, Vector3.new(1.7, 2.0, 2.0), STEEL_L, { shape = CYL, decor = true })
	end
	B("Floor", -12.6, 2.6, -5.0, 5.0, 3.0, 5.0, rgb(92, 92, 98), {})
	B("BackWall", -13, 2.6, 5.0, 5.5, 14, 5.5, t.main, MO)
	B("RearWall", -13, 2.6, -5.5, -12.5, 14, 5.0, t.main, MO)
	B("CabWall", 5.0, 2.6, -5.5, 5.5, 14, 5.0, t.main, MO)
	B("FrontLower", -12.5, 2.6, -5.5, 5.0, 6.0, -5.0, t.main, MO)
	B("FrontUpper", -12.5, 11.6, -5.5, 5.0, 14, -5.0, t.main, MO)
	B("JambRear", -12.5, 6.0, -5.5, -10.5, 11.6, -5.0, t.main, MO)
	B("JambCab", 3.0, 6.0, -5.5, 5.0, 11.6, -5.0, t.main, MO)
	B("Roof", -13.4, 14, -5.9, 5.9, 14.8, 5.9, t.second, MO)
	local counter = B("Counter", -10.7, 5.6, -7.3, 3.2, 6.1, -3.8, STEEL_L, { refl = 0.1 })
	local band = B("TaglineBand", -12.5, 3.0, -5.62, 5.0, 5.0, -5.5, t.band, {})
	txt(surface(band, FRONT, 30), t.tagline, t.bandText, 0.02, 0.1, 0.96, 0.8, { strokeT = 0 })
	-- store rayé au-dessus du guichet
	local ax0, ax1, nS = -11.2, 3.4, 7
	local w = (ax1 - ax0) / nS
	for i = 0, nS - 1 do
		local x = (ax0 + (i + 0.5) * w) * s
		local a, b = Vector3.new(x, 12.4, -5.5), Vector3.new(x, 10.6, -10.2)
		local c = (a + b) / 2
		P(m, "Awning_" .. (i + 1), cf * CFrame.lookAt(c, c + (b - a).Unit), Vector3.new(w + 0.02, 0.25, (b - a).Magnitude), t.stripes[i % 2 + 1], { decor = true })
	end
	B("AwningValance", ax0, 10.0, -10.35, ax1, 10.7, -10.05, t.stripes[1], { decor = true })
	-- intérieur vu par le guichet : menu, comptoir du fond, articles, lumière (le vendeur viendra ici)
	local menu = B("MenuBoard", -10, 7.4, 4.7, 2.5, 11.2, 5.0, rgb(28, 32, 40), {})
	txt(surface(menu, FRONT, 30), t.menu, t.titleColor, 0.05, 0.15, 0.9, 0.7, { strokeT = 1 })
	local light = Instance.new("PointLight"); light.Range = 14; light.Brightness = 0.9; light.Color = WARM; light.Shadows = false
	light.Parent = menu
	B("BackCounter", -12.4, 3.0, 3.0, 4.8, 5.4, 4.9, STEEL_L, {})
	for i, it in t.items do
		B("Goods_" .. i, it[1], 5.4, 3.5, it[2], 5.4 + it[3], 4.5, it[4], { decor = true, mat = t.glowItems and NEON or nil })
	end
	-- cabine
	B("Cab", 5.5, 2.6, -5.3, 12.4, 10.4, 5.3, t.main, MO)
	B("CabRoof", 5.3, 10.4, -5.4, 12.0, 10.9, 5.4, t.second, MO)
	B("Nose", 12.4, 2.6, -5.1, 13.4, 6.4, 5.1, t.main, MO)
	B("Windshield", 12.3, 6.6, -4.4, 12.6, 9.9, 4.4, GLASS_D, { decor = true, refl = 0.3 })
	B("SideWindow_L", 7.2, 6.8, -5.42, 11.6, 9.7, -5.3, GLASS_D, { decor = true, refl = 0.3 })
	B("SideWindow_R", 7.2, 6.8, 5.3, 11.6, 9.7, 5.42, GLASS_D, { decor = true, refl = 0.3 })
	B("Headlight_L", 13.4, 4.4, -4.5, 13.6, 5.4, -3.2, rgb(255, 246, 214), { decor = true })
	B("Headlight_R", 13.4, 4.4, 3.2, 13.6, 5.4, 4.5, rgb(255, 246, 214), { decor = true })
	B("Grille", 13.4, 3.0, -2.6, 13.5, 5.8, 2.6, DARK, { decor = true })
	B("Bumper", 13.3, 1.5, -5.2, 13.9, 2.7, 5.2, rgb(120, 124, 132), {})
	B("Mirror", 11.6, 8.0, -6.2, 12.0, 9.2, -5.3, DARK, { decor = true })
	-- enseigne de toit (deux faces) et emblème
	B("SignPost_1", -7.6, 14.8, -0.3, -7.0, 15.6, 0.3, DARK, { decor = true })
	B("SignPost_2", 2.6, 14.8, -0.3, 3.2, 15.6, 0.3, DARK, { decor = true })
	local sign = B("RoofSign", -9.6, 15.6, -0.45, 5.2, 20.6, 0.45, t.signBg, {})
	for _, face in { FRONT, BACK } do
		txt(surface(sign, face, 24), t.title, t.titleColor, 0.04, 0.08, 0.92, 0.84, { font = LUCKY, strokeT = 3 })
	end
	local ic = cf * CFrame.new(-11.3 * s, 14.8, 0)
	if t.icon == "bat" then -- batte géante
		local tilt = ic * CFrame.Angles(0, 0, math.rad(-28 * s))
		P(m, "Bat_Handle", tilt * CFrame.new(0, 2.2, 0) * ROT_UP, Vector3.new(4.4, 1.0, 1.0), rgb(40, 40, 46), { shape = CYL, decor = true })
		P(m, "Bat_Barrel", tilt * CFrame.new(0, 7.2, 0) * ROT_UP, Vector3.new(6.2, 2.4, 2.4), WOOD, { shape = CYL, decor = true })
		P(m, "Bat_Knob", tilt * CFrame.new(0, 0.1, 0), Vector3.new(1.5, 1.5, 1.5), rgb(40, 40, 46), { shape = BALL, decor = true })
		P(m, "Bat_Tip", tilt * CFrame.new(0, 10.3, 0), Vector3.new(2.4, 2.4, 2.4), WOOD, { shape = BALL, decor = true })
	elseif t.icon == "orb" then -- orbe d'aura qui scintille
		Vc(m, ic, "Orb_Stand", 0, 0, 1.6, 0, 1.4, DARK, { decor = true })
		local orb = P(m, "Orb", ic * CFrame.new(0, 4.4, 0), Vector3.new(5, 5, 5), rgb(176, 110, 255), { shape = BALL, mat = NEON, decor = true })
		P(m, "Orb_Ring", ic * CFrame.new(0, 4.4, 0) * CFrame.Angles(math.rad(70), 0, math.rad(20)), Vector3.new(0.4, 8, 8), rgb(90, 230, 255), { shape = CYL, mat = NEON, decor = true })
		sparkles(orb, rgb(200, 150, 255), rgb(120, 240, 255), 12)
	elseif t.icon == "coin" then -- pièce géante
		Vc(m, ic, "Coin_Stand", 0, 0, 1.4, 0, 1.4, DARK, { decor = true })
		local coin = P(m, "Coin", ic * CFrame.new(0, 5, 0) * ROT_Z, Vector3.new(1.2, 7.2, 7.2), GOLD_L, { shape = CYL, refl = 0.2, decor = true })
		for _, face in { RIGHT, LEFT } do txt(surface(coin, face, 30), "R$", rgb(130, 86, 10), 0.15, 0.18, 0.7, 0.64, { font = LUCKY, strokeT = 0 }) end
	else -- les trois boules dorées du prêteur sur gages
		Vc(m, ic, "Pawn_Post", 0, 0, 7.1, 0, 0.6, GOLD, { decor = true })
		Bx(m, ic, "Pawn_Bar", -0.3, 6.6, -3.2, 0.3, 7.1, 3.2, GOLD, { decor = true })
		for i, b in { { 4.8, -2.3 }, { 4.8, 2.3 }, { 2.6, 0 } } do
			Ball(m, ic, "Pawn_Ball_" .. i, 0, b[1], b[2], 2.2, GOLD_L, { decor = true, refl = 0.2 })
			Bx(m, ic, "Pawn_Chain_" .. i, -0.06, b[1] + 1.0, b[2] - 0.06, 0.06, 6.6, b[2] + 0.06, GOLD, { decor = true })
		end
	end
	-- chevalet « OPEN » devant la cabine
	local af = cf * CFrame.new(9.5 * s, 0, -9.6)
	local board = P(m, "OpenSign_Front", af * CFrame.new(0, 1.75, -0.45) * CFrame.Angles(math.rad(14), 0, 0), Vector3.new(2.8, 3.6, 0.2), rgb(36, 40, 46), { decor = true })
	P(m, "OpenSign_Back", af * CFrame.new(0, 1.75, 0.45) * CFrame.Angles(math.rad(-14), 0, 0), Vector3.new(2.8, 3.6, 0.2), rgb(36, 40, 46), { decor = true })
	txt(surface(board, FRONT, 40), "OPEN", rgb(120, 240, 140), 0.08, 0.3, 0.84, 0.4, { font = LUCKY, strokeT = 0 })
	if counter.Parent then m.PrimaryPart = counter end
	m.WorldPivot = cf
	CS:AddTag(m, t.tag)
	m.Parent = parent
	return m
end
do
	local m = section("Trucks")
	for _, t in TRUCKS do truck(m, t) end
	done(m)
end

-- Parking (sud-est) : 24 places, 12 voitures, bordures, lampadaires, panneau P, barrière et sortie fermée --------------
do
	local m = section("Parking")
	local X0, X1, Z0, Z1 = -34, 24, -246, -106
	Bx(m, W, "Asphalt", X0, -0.05, Z0, X1, 0.08, Z1, ASPHALT, F)
	for i, seg in { { X0, -30 }, { -22, 10 }, { 18, X1 } } do -- deux passages piétons côté place
		Bx(m, W, "Kerb_N" .. i, seg[1], -0.05, Z1, seg[2], 0.5, Z1 + 0.8, KERB, { studs = true })
	end
	Bx(m, W, "Kerb_W", X0 - 0.8, -0.05, Z0, X0, 0.5, Z1 + 0.8, KERB, { studs = true })
	Bx(m, W, "Kerb_E", X1, -0.05, Z0, X1 + 0.8, 0.5, Z1 + 0.8, KERB, { studs = true })
	local LN = { decor = true, noShadow = true }
	for i = 0, 12 do
		local z = Z0 + 4 + i * 11
		Bx(m, W, "LineW_" .. i, -33, 0.08, z - 0.2, -15, 0.12, z + 0.2, LINE, LN)
		Bx(m, W, "LineE_" .. i, 5, 0.08, z - 0.2, 23, 0.12, z + 0.2, LINE, LN)
	end
	for i = 0, 9 do
		local z = Z0 + 6 + i * 13
		Bx(m, W, "AisleDash_" .. i, -5.2, 0.08, z, -4.8, 0.12, z + 6, LINE, LN)
	end
	local COLORS = { rgb(220, 60, 56), rgb(52, 120, 220), rgb(250, 200, 50), rgb(240, 240, 236), rgb(40, 42, 48), rgb(70, 170, 90),
		rgb(240, 140, 50), rgb(60, 180, 180), rgb(240, 130, 180), rgb(170, 176, 186), rgb(130, 90, 200), rgb(200, 40, 70) }
	for j, i in { 0, 2, 3, 5, 8, 10 } do
		car(m, "Car_W" .. j, frameAt(Vector3.new(-24, 0, Z0 + 4 + i * 11 + 5.5), Vector3.new(1, 0, 0)), COLORS[j])
	end
	for j, i in { 1, 2, 4, 7, 9, 11 } do
		car(m, "Car_E" .. j, frameAt(Vector3.new(14, 0, Z0 + 4 + i * 11 + 5.5), Vector3.new(-1, 0, 0)), COLORS[j + 6])
	end
	for i, p in { Vector3.new(X0 - 0.4, 0.5, -140), Vector3.new(X0 - 0.4, 0.5, -210), Vector3.new(X1 + 0.4, 0.5, -140), Vector3.new(X1 + 0.4, 0.5, -210) } do
		lamp(m, "Lamp_Parking_" .. i, p, 18)
	end
	local pf = CFrame.new(21, 0, -102)
	Vc(m, pf, "PSign_Pole", 0, 0, 12, 0, 0.6, DARK, {})
	local ps = Bx(m, pf, "PSign", -2.8, 12, -0.25, 2.8, 17.6, 0.25, rgb(40, 100, 210), {})
	for _, face in { FRONT, BACK } do txt(surface(ps, face, 30), "P", WHITE, 0.15, 0.1, 0.7, 0.8, { font = LUCKY, strokeT = 0 }) end
	-- barrière et cabine à la sortie (le mur du fond reste fermé)
	Bx(m, W, "Barrier_Post", -14.8, 0.08, -239.6, -13.6, 4.2, -238.4, rgb(255, 200, 40), { studs = true })
	for i = 0, 3 do
		Bx(m, W, "Barrier_Arm_" .. (i + 1), -13.6 + i * 3, 3.3, -239.3, -10.6 + i * 3, 3.9, -238.7, (i % 2 == 0) and RED or WHITE, { decor = true })
	end
	Bx(m, W, "Booth", 6, 0.08, -245, 11, 8, -239, CREAM, { studs = true })
	Bx(m, W, "Booth_Window", 5.9, 3.5, -244, 6.0, 6.5, -240, GLASS_D, { decor = true, refl = 0.3 })
	Bx(m, W, "Booth_Roof", 5.5, 8, -245.5, 11.5, 8.6, -238.5, BRICK, { studs = true })
	-- carrousel à chariots
	Bx(m, W, "CartCorral_Rail_L", -12, 0.08, -116, -11.8, 3.2, -110, STEEL_L, { decor = true })
	Bx(m, W, "CartCorral_Rail_R", -4.2, 0.08, -116, -4, 3.2, -110, STEEL_L, { decor = true })
	Bx(m, W, "CartCorral_Top", -12, 3.0, -116.2, -4, 3.2, -116, STEEL_L, { decor = true })
	cart(m, "Cart_1", frameAt(Vector3.new(-8, 0.08, -113.5), Vector3.new(0, 0, -1)))
	cart(m, "Cart_2", frameAt(Vector3.new(-8, 0.08, -110.8), Vector3.new(0, 0, -1)))
	cart(m, "Cart_3", frameAt(Vector3.new(-18, 0.08, -128), Vector3.new(0.6, 0, -1)))
	done(m)
end

-- Jardin (nord-est) : pelouse, allées, grand arbre au banc circulaire, massifs, bancs, lampadaires ----------------------
do
	local m = section("Garden")
	local X0, X1, Z0, Z1 = -34, 24, 124, 246
	Bx(m, W, "Lawn", X0, -0.05, Z0, X1, 0.3, Z1, GRASS, F)
	Bx(m, W, "Path_NS", -8, -0.05, Z0, -2, 0.36, Z1, PAVE, F)
	Bx(m, W, "Path_EW_W", X0, -0.05, 182, -8, 0.36, 188, PAVE, F)
	Bx(m, W, "Path_EW_E", -2, -0.05, 182, X1, 0.36, 188, PAVE, F)
	local pc = Vector3.new(-5, 0, 185)
	disc(m, "RoundPlace", pc, 11, 0.42, PAVE, F)
	disc(m, "RoundPlaceBand", pc, 9.5, 0.46, TERRA, F)
	tree(m, "BigTree", pc + Vector3.new(0, 0.46, 0), 1.4)
	for i = 0, 7 do
		local a = math.rad(i * 45 + 22.5)
		local p = pc + Vector3.new(math.cos(a), 0, math.sin(a)) * 7.4
		local c = Vector3.new(p.X, 1.25, p.Z)
		P(m, "RingBench_" .. (i + 1), CFrame.lookAt(c, c + Vector3.new(-math.sin(a), 0, math.cos(a))), Vector3.new(1.8, 1.6, 5.4), WOOD, {})
	end
	local HO = { studs = true }
	Bx(m, W, "Hedge_S1", X0, 0, Z0, -9, 1.6, Z0 + 1.2, HEDGE, HO)
	Bx(m, W, "Hedge_S2", -1, 0, Z0, X1, 1.6, Z0 + 1.2, HEDGE, HO)
	Bx(m, W, "Hedge_W1", X0, 0, Z0 + 1.2, X0 + 1.2, 1.6, 181, HEDGE, HO)
	Bx(m, W, "Hedge_W2", X0, 0, 189, X0 + 1.2, 1.6, Z1, HEDGE, HO)
	for i, p in { { 12, 140 }, { 14, 166 }, { -22, 138 }, { -24, 164 }, { 12, 206 }, { 15, 232 }, { -22, 202 }, { -20, 232 } } do
		tree(m, "Tree_" .. i, Vector3.new(p[1], 0.3, p[2]))
	end
	for i, p in { { -18, 176 }, { 9, 176 }, { -18, 194 }, { 9, 194 } } do flowerBed(m, "FlowerBed_" .. i, Vector3.new(p[1], 0.3, p[2])) end
	for i, b in { { -11.5, 152, 1 }, { 1.5, 152, -1 }, { -11.5, 218, 1 }, { 1.5, 218, -1 } } do
		local p = Vector3.new(b[1], 0.3, b[2])
		bench(m, "Bench_" .. i, frameAt(p, Vector3.new(b[3], 0, 0)))
	end
	for i, p in { { -10.5, 132 }, { 0.5, 168 }, { -10.5, 204 }, { 0.5, 238 } } do lamp(m, "Lamp_Garden_" .. i, Vector3.new(p[1], 0.36, p[2])) end
	done(m)
end

-- Murs d'enceinte (nord, sud, est contre la zone 1), piliers au bout du mur de nuit, mâts à la sortie --------------------
do
	local m = section("Walls")
	local WO = { studs = true }
	local function wallX(name, x0, x1, z0, z1, inside) -- mur le long de x ; inside = côté du hub (+1 : z croissant)
		group(CFrame.new((x0 + x1) / 2, WALL_H / 2, (z0 + z1) / 2), Vector3.new(math.abs(x1 - x0), WALL_H, math.abs(z1 - z0) + 1.2))
		Bx(m, W, name, x0, 0, z0, x1, WALL_H, z1, STONE, WO)
		local zi = inside > 0 and math.max(z0, z1) or math.min(z0, z1)
		Bx(m, W, name .. "_Cap", x0, WALL_H, math.min(z0, z1) - (inside < 0 and 0.6 or 0), x1, WALL_H + 1.2, math.max(z0, z1) + (inside > 0 and 0.6 or 0), BRICK, WO)
		Bx(m, W, name .. "_Pilaster", x0, 0, zi - (inside < 0 and 0.6 or 0), x0 + 2.4, WALL_H + 1.2, zi + (inside > 0 and 0.6 or 0), BRICK, WO)
		ungroup()
	end
	local xs = { -80, -60, -38, -16, 7, 30 }
	for i = 1, 5 do
		wallX("Wall_N" .. i, xs[i], xs[i + 1], 250, 253, -1)
		wallX("Wall_S" .. i, xs[i], xs[i + 1], -253, -250, 1)
	end
	local zs = { 34.5, 78, 122, 166, 210, 253 }
	for i = 1, 5 do
		for _, s in { 1, -1 } do
			local tag = (s > 0 and "N" or "S") .. i
			local z0, z1 = math.min(zs[i] * s, zs[i + 1] * s), math.max(zs[i] * s, zs[i + 1] * s)
			Bx(m, W, "Wall_E" .. tag, 27.5, 0, z0, 30, WALL_H, z1, STONE, WO)
			Bx(m, W, "Wall_E" .. tag .. "_Cap", 26.9, WALL_H, z0, 30, WALL_H + 1.2, z1, BRICK, WO)
			local zp = (s > 0) and z0 or (z1 - 2.4)
			Bx(m, W, "Wall_E" .. tag .. "_Pilaster", 26.9, 0, zp, 27.5, WALL_H + 1.2, zp + 2.4, BRICK, WO)
		end
	end
	-- sortie fermée du parking dans le mur sud
	local door = Bx(m, W, "ParkingGate", -14, 0, -250.35, 4, 14, -249.95, rgb(150, 156, 166), { studs = true })
	for i = 1, 6 do Bx(m, W, "ParkingGate_Slat" .. i, -14, i * 2, -249.95, 4, i * 2 + 0.25, -249.85, DARK, { decor = true }) end
	local exitSign = Bx(m, W, "ParkingExitSign", -10, 15, -250.4, 0, 18.5, -249.95, rgb(40, 100, 210), {})
	txt(surface(exitSign, BACK, 30), "EXIT", WHITE, 0.1, 0.1, 0.8, 0.8, { font = LUCKY, strokeT = 0 })
	-- piliers au bout du mur de nuit (ses montants butent dessus à |z| = 34,5), lanterne au sommet
	for _, s in { 1, -1 } do
		local tag = s > 0 and "N" or "S"
		local z0, z1 = math.min(34.5 * s, 38.5 * s), math.max(34.5 * s, 38.5 * s)
		Bx(m, W, "GatePost_" .. tag, 18, 0, z0, 27.5, 22, z1, STONE, WO)
		Bx(m, W, "GatePost_" .. tag .. "_Cap", 17.4, 22, s > 0 and 34.5 or -39.1, 28, 23.4, s > 0 and 39.1 or -34.5, BRICK, WO)
		local lf = CFrame.new(22.75, 23.4, 36.5 * s)
		Bx(m, lf, "GatePost_" .. tag .. "_LampBase", -1, 0, -1, 1, 1, 1, DARK, { decor = true })
		nightLight(Bx(m, lf, "GatePost_" .. tag .. "_Lamp", -1.1, 1, -1.1, 1.1, 3.8, 1.1, LAMP_OFF, { decor = true }), 34, 1.6)
		Bx(m, lf, "GatePost_" .. tag .. "_LampCap", -1.4, 3.8, -1.4, 1.4, 4.3, 1.4, DARK, { decor = true })
		-- mât à drapeau sur le trottoir de sortie
		local base = CFrame.new(14, 0.45, 29 * s)
		Vc(m, base, "Flagpole_" .. tag, 0, 0, 40, 0, 0.8, STEEL_L, {})
		Ball(m, base, "Flagpole_" .. tag .. "_Top", 0, 40.4, 0, 1.2, GOLD_L, { decor = true })
		Bx(m, base, "Flag_" .. tag, -9.4, 33, -0.12, -0.4, 39, 0.12, s > 0 and NAVY or RED, { decor = true })
		Bx(m, base, "Flag_" .. tag .. "_Stripe", -9.4, 35.5, -0.14, -0.4, 36.5, 0.14, GOLD_L, { decor = true })
		lamp(m, "Lamp_Exit_" .. tag, Vector3.new(3, 0.45, 31.5 * s))
	end
	done(m)
end

-- Emplacements des boutiques (repères invisibles : PivotTo(PlotSite_k.CFrame) pose le modèle, avant vers la place)
do
	local m = section("PlotSites")
	for k, site in SITES do
		P(m, "PlotSite_" .. k, site.cf, Vector3.new(SHOP_W, 0.1, SHOP_D), rgb(255, 120, 200), { T = 1, decor = true, noShadow = true, anywhere = true })
	end
	done(m)
end

-- 4) Boutiques des joueurs (PLOT_Shop) : une copie du gabarit par emplacement, niveau 1, PlotIndex = numéro de l'emplacement
local shopsReady = false
do
	local shops = hub:FindFirstChild("Shops")
	if not shops then shops = Instance.new("Folder"); shops.Name = "Shops"; shops.Parent = hub end
	local builder = _G.ClaudePlotShop
	if builder and builder.install then
		for k, site in SITES do
			builder.install({ index = k, cframe = site.cf, parent = shops, stage = 1 })
			task.wait()
		end
		add("Boutiques posées par plot_shop_builder (niveau 1) : 6, dans Map/Hub/Shops")
	else
		add("Boutiques : constructeur pas chargé (tools/clement/hub/plot_shop_builder.luau) ; celles déjà posées restent")
	end
	local n = 0
	for _, m in shops:GetChildren() do if m:IsA("Model") and CS:HasTag(m, "PlayerPlot") then n += 1 end end
	shopsReady = (n == 6)
end

-- SafeZone (un seul volume, tout le hub, jusqu'au mur de nuit) et SpawnLocation au centre de la place
do
	local sz = P(hub, "SafeZone", CFrame.new((HUB.x0 + 24) / 2, 75, 0), Vector3.new(24 - HUB.x0, 170, HUB.z1 - HUB.z0), rgb(255, 120, 200),
		{ T = 1, decor = true, noShadow = true, anywhere = true })
	CS:AddTag(sz, "SafeZone")
	local sp = Instance.new("SpawnLocation")
	sp.Name = "Spawn"; sp.Size = Vector3.new(8, 1, 8); sp.Anchored = true
	local c = S + Vector3.new(0, 0.8, 0)
	sp.CFrame = CFrame.lookAt(c, c + rr(0)) -- face au centre commercial
	sp.Color = GOLD_L; sp.Material = SMOOTH; sp.TopSurface = Enum.SurfaceType.Smooth; sp.BottomSurface = Enum.SurfaceType.Smooth
	sp.Duration = 10; sp.Neutral = true; sp.AllowTeamChangeOnTouch = false; sp.Enabled = true
	sp.Parent = hub
end

-- 5) Greybox remplacé, rangé -----------------------------------------------------------------------------------------
do
	local keep = SS:FindFirstChild("_GREYBOX_REMPLACE")
	if not keep then keep = Instance.new("Folder"); keep.Name = "_GREYBOX_REMPLACE"; keep.Parent = SS end
	local stored = {}
	local function stash(inst, group)
		if not inst then return end
		local g = keep:FindFirstChild(group)
		if not g then g = Instance.new("Folder"); g.Name = group; g.Parent = keep end
		local prev = g:FindFirstChild(inst.Name); if prev then prev:Destroy() end
		inst.Parent = g
		table.insert(stored, group .. "/" .. inst.Name)
	end
	if safeG then for _, n in { "Ground", "Shops", "SafeZone", "Spawn" } do stash(safeG:FindFirstChild(n), "Safe") end end
	if safeG and shopsReady then stash(safeG:FindFirstChild("Plots"), "Safe") end -- les 6 boutiques prennent le relais
	local cor = gb and gb:FindFirstChild("Corridor")
	if cor then stash(cor:FindFirstChild("Entry"), "Corridor") end
	add("Rangé dans ServerStorage/_GREYBOX_REMPLACE : " .. (#stored > 0 and table.concat(stored, ", ") or "rien (déjà fait)"))
end

-- 6) Vérification ----------------------------------------------------------------------------------------------------
add("Pièces posées : " .. built)
do
	local s = {}
	for z, n in skipped do table.insert(s, z .. " " .. n) end
	add("Pièces sautées (zones réservées) : " .. (#s > 0 and table.concat(s, ", ") or "aucune"))
end
do
	local inbox, sandbox = workspace:FindFirstChild("_INBOX_CLEMENT"), workspace:FindFirstChild("_SANDBOX_IRONIX")
	local t = {}
	for _, tag in { "SafeZone", "WeaponShop", "AuraShop", "RobuxShop", "PawnShop", "PlayerPlot", "Treadmill", "Bench", "CashPad", "NightWall", "ZoneGate", "NPCStore" } do
		local n = 0
		for _, inst in CS:GetTagged(tag) do
			if inst:IsDescendantOf(workspace) and not (inbox and inst:IsDescendantOf(inbox)) and not (sandbox and inst:IsDescendantOf(sandbox)) then n += 1 end
		end
		table.insert(t, tag .. " " .. n)
	end
	add("Tags dans le Workspace : " .. table.concat(t, ", "))
	local spawns = 0
	for _, d in workspace:GetDescendants() do if d:IsA("SpawnLocation") and d.Enabled then spawns += 1 end end
	local scripts = 0
	for _, d in hub:GetDescendants() do if d:IsA("LuaSourceContainer") then scripts += 1 end end
	if plotsFolder then for _, d in plotsFolder:GetDescendants() do if d:IsA("LuaSourceContainer") then scripts += 1 end end end
	add("SpawnLocation actives : " .. spawns .. " ; scripts dans Map/Hub et les parcelles : " .. scripts)
	local mn, mx = boundsOf(hub)
	add(string.format("Emprise de Map/Hub : x %.1f..%.1f, z %.1f..%.1f", mn.X, mx.X, mn.Z, mx.Z))
end
do -- rien de solide du hub dans les emplacements des boutiques (seulement ce que pose ce script, pas les boutiques)
	local hits, own, list = {}, {}, {}
	for _, n in OWN do own[n] = true end
	for _, sec in hub:GetChildren() do
		if own[sec.Name] then
			table.insert(list, sec)
			for _, d in sec:GetDescendants() do table.insert(list, d) end
		end
	end
	for _, d in list do
		if d:IsA("BasePart") and d.CanCollide then
			local bottom, top = aabbOf(d.CFrame, d.Size)
			if top.Y > 0.3 and bottom.Y < 32 then -- au-dessus de 32 : plus haut que la boutique
				for k, site in SITES do
					local pts, axes = footprint(site.cf:ToObjectSpace(d.CFrame), d.Size)
					if overlaps(pts, axes, { mn = Vector3.new(-SHOP_W / 2 + 0.2, 0, -SHOP_D / 2 + 0.2), mx = Vector3.new(SHOP_W / 2 - 0.2, 0, SHOP_D / 2 - 0.2) }) then
						table.insert(hits, d.Name .. "→" .. k)
					end
				end
			end
		end
	end
	add("Pièces solides du hub dans un emplacement : " .. (#hits > 0 and table.concat(hits, ", ", 1, math.min(#hits, 8)) or "aucune"))
end
do -- contrat 10.4 des boutiques (vérification du constructeur), PlotIndex de 1 à 6
	local shops, ok, problems, idx = hub:FindFirstChild("Shops"), 0, {}, {}
	local builder = _G.ClaudePlotShop
	for _, m in (shops and shops:GetChildren() or {}) do
		if m:IsA("Model") and CS:HasTag(m, "PlayerPlot") then
			table.insert(idx, tostring(m:GetAttribute("PlotIndex")))
			if builder and builder.check then
				local _, probs = builder.check(m)
				if #probs == 0 then ok += 1 else table.insert(problems, m.Name .. " : " .. table.concat(probs, " | ")) end
			end
		end
	end
	table.sort(idx)
	add("Boutiques : PlotIndex " .. table.concat(idx, ", ") .. " ; contrat 10.4 OK sur " .. ok .. (#problems > 0 and (" ; PROBLÈMES : " .. table.concat(problems, " ; ")) or ""))
end
do -- emplacements (repère = pivot du modèle : centre de l'emprise au sol, avant vers la place)
	for k, site in SITES do
		local _, ry = site.cf:ToOrientation()
		add(string.format("Emplacement %d : centre (%.1f, 0, %.1f), avant (%.1f, %.1f), orientation Y %.1f°, à %.0f du spawn et %.0f de l'arche 1",
			k, site.center.X, site.center.Z, site.front.X, site.front.Z, math.deg(ry), (site.front - S).Magnitude, (site.front - E).Magnitude))
	end
end
do -- chemins à pied depuis le spawn
	local path = PFS:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = false, WaypointSpacing = 8 })
	local start = S + Vector3.new(0, 2, 0)
	local function walk(label, goal)
		local ok, err = pcall(function() path:ComputeAsync(start, goal) end)
		if not ok then return label .. " erreur " .. tostring(err) end
		if path.Status ~= Enum.PathStatus.Success then return label .. " " .. path.Status.Name end
		local wps, len = path:GetWaypoints(), 0
		for i = 2, #wps do len += (wps[i].Position - wps[i - 1].Position).Magnitude end
		return label .. " " .. math.floor(len + 0.5)
	end
	local res = {}
	for k, site in SITES do table.insert(res, walk("emplacement " .. k, site.front + site.n * 6 + Vector3.new(0, 1, 0))) end
	for _, plot in CS:GetTagged("PlayerPlot") do -- parcelles grises seulement : la boutique finale est fermée (vitrine)
		if plotsFolder and plot:IsDescendantOf(plotsFolder) and plot:IsDescendantOf(workspace) then
			local sp = plot:FindFirstChild("SpawnPoint", true)
			if sp and sp:IsA("Attachment") then table.insert(res, walk("parcelle " .. tostring(plot:GetAttribute("PlotIndex")), sp.WorldPosition + Vector3.new(0, 1, 0))) end
		end
	end
	for _, t in TRUCKS do
		local inst = hub.Trucks:FindFirstChild(t.name)
		local cp = inst and inst.PrimaryPart
		if cp then table.insert(res, walk(t.tag, Vector3.new(cp.Position.X, 1, cp.Position.Z) + inst:GetPivot().LookVector * 5)) end
	end
	table.insert(res, walk("zone 1", Vector3.new(50, 1, 0)))
	add("Chemins à pied depuis le spawn (studs) : " .. table.concat(res, " ; "))
end

return table.concat(report, "\n")
