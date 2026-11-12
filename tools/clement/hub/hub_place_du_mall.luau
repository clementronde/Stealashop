--!nocheck
-- Hub (zone safe) « Place du Mall » (MOD-029, L-049), au gabarit des zones (L-040).
-- Depuis le 2026-11-08, hub simplifié (MALL = false) : pelouse, fontaine au centre, allées, bordure basse ; avant, une
-- place en plein air devant l'immense façade d'un centre commercial (enseigne STEAL A SHOP). 6 emplacements de
-- boutiques en demi-cercle autour de l'entrée de la zone 1 (toutes à la même distance de l'arche), comptoirs en stands
-- de marché tenus par un vendeur à la sortie, sortie tout droit vers la zone 1 (x = 30, dans l'axe du couloir), un seul
-- volume SafeZone.
-- À lancer dans Studio (MCP execute_luau, mode Edit). Relancer reconstruit ce que le script pose dans Workspace/Map/Hub
-- (les autres enfants de Map/Hub, par exemple les boutiques posées plus tard, sont gardés).
-- Ce qu'il fait :
--  1) plan : arc de rayon RC autour du centre C, juste derrière l'arche 1 (façades à 134..138 studs de l'arche) ;
--     ROT tourne tout l'arc autour de l'entrée de la zone 1 (0 = enseigne dans l'axe) ;
--  2) pose les 6 parcelles grises du greybox (Greybox/Safe/Plots, tag PlayerPlot) sur leurs emplacements, en attendant
--     le modèle de boutique ; une parcelle dont l'emplacement touche une zone réservée reste où elle est ;
--  3) construit Map/Hub en sautant toute pièce qui toucherait une zone réservée (_SHOWROOM_CLEMENT, _INBOX_CLEMENT,
--     parcelle grise pas déplacée) : relancer après leur départ complète le hub ;
--  4) pose les SHOP_COUNT boutiques (8 en ligne ; PLOT_Shop, 5 niveaux, MOD-015) sur les emplacements, au niveau 1, dans Map/Hub/Shops, avec
--     le constructeur tools/clement/hub/plot_shop_builder.luau : l'envoyer à execute_luau AVANT ce script
--     (_G.ClaudePlotShop) ; sans lui, les boutiques déjà posées restent telles quelles ;
--  5) range dans ServerStorage/_GREYBOX_REMPLACE ce que le hub remplace : Greybox/Safe/{Ground, Shops, SafeZone, Spawn},
--     Greybox/Corridor/Entry, et Greybox/Safe/Plots dès que les 6 boutiques sont posées (6 PlayerPlot en tout) ;
--  6) vérifie : tags, aucun script, emprise, chevauchements avec les emplacements, contrat 10.4 des boutiques, chemins
--     à pied (PathfindingService, rayon 2, sans saut) du spawn aux boutiques, aux comptoirs et à la zone 1.
--     Le script renvoie le compte rendu.
-- Comptoirs (contrat : Contract/Tags, ShopService, WeaponShopController, AuraShopController) : un Model tagué
-- WeaponShop, AuraShop, RobuxShop ou PawnShop, dont la PrimaryPart (Counter) porte l'invite du code, avec devant lui
-- une plaque ShopPad (zone d'ouverture, nom proposé le 2026-11-08, à valider par Ironix).
-- Ne touche pas : Map/Entry (mur de nuit de la zone 1, x 25,45..28,55, z ±64,5 depuis corridor_widen, livré sous le sol : le sol du hub le
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
-- Sortie vers la zone 1 à la largeur du couloir (Clément, 2026-11-08 : couloir des magasins élargi de 60 à 120,
-- tools/clement/zones/corridor_widen.luau, entrée comprise) : rue jusqu'à |z| = EXIT_ROAD, trottoirs et ouverture du
-- grand mur jusqu'à EXIT_HALF (bout du mur de nuit et des piliers de l'arche 1). Stands et mâts écartés d'autant.
local EXIT_W = 30 -- élargissement de chaque côté (0 = ancienne sortie : rue ±22,5, ouverture ±34,5)
local EXIT_ROAD, EXIT_HALF = 22.5 + EXIT_W, 34.5 + EXIT_W
local ROT = 0 -- rotation de l'arc autour de E, en degrés (0 = enseigne dans l'axe du couloir)
-- Demi-cercle autour de l'entrée (Clément, 2026-11-07 : boutiques plus près de la zone 1) : centre de l'arc C à 6 studs
-- derrière l'arche (D_C < 0), rayon 140, toutes les façades à 134..138 studs de l'arche. Spawn S au milieu de la place.
local D_C, D_S = -6, 56 -- E → centre de l'arc C, E → spawn S
local RC = 140 -- rayon des façades de boutiques, depuis C
local SHOP_W, SHOP_D, GAP = 64, 80, 8 -- emprise d'une boutique (avant = côté de 64), écart entre deux façades
local STEP = 2 * math.deg(math.atan((SHOP_W / 2 + GAP / 2) / RC)) -- 28,8° d'une boutique à l'autre
local RF = RC + SHOP_D + 8 -- façade du centre commercial (228)
local WALL_H = 20
local HUB = { x0 = -250, x1 = 30, z0 = -250, z1 = 250 }
-- Clément, 2026-11-08 : hub simplifié, comme les jeux « Steal a … » (base lisible, 6 boutiques bien visibles, peu de
-- décor). MALL = false : ni façade de centre commercial, ni tour à l'enseigne, ni piliers entre les boutiques, ni blocs
-- au bout de l'arc ; une bordure basse ferme le hub. MALL = true remet l'ancien décor.
local MALL = false
-- Clément, 2026-11-08 : ROWS = les 6 boutiques en deux rangées de 3 face à face, de part et d'autre d'une allée centrale
-- (z = 0) qui mène tout droit à la sortie (x = 30). Au nord, de la sortie vers l'ouest : 1, 2, 3 ; au sud : 6, 5, 4. Les 4
-- stands se font face entre la sortie et les premières boutiques, la fontaine est au milieu de l'allée. Hub ramené à
-- la taille des rangées. ROWS = false : l'ancien demi-cercle autour de l'entrée (et MALL possible).
-- LAYOUT : "line" (en vigueur, 2026-11-08), "rows" (3 face à 3) ou "arc" (demi-cercle, avec MALL possible)
local LAYOUT = "line"
local ROWS, LINE = LAYOUT == "rows", LAYOUT == "line"
-- Clément, 2026-11-08 (après un Play) : boutiques plus écartées et plus loin de l'allée, pour qu'un vol chez un autre
-- joueur fasse plus de chemin. Façades à |z| = 60 (terrasses à 48 : 96 d'allée entre elles), 26 entre deux boutiques
-- (avant : 44 et 10). ROW_X0 = bord est de la boutique la plus proche de la sortie.
local ROW_Z, ROW_GAP, ROW_X0 = 60, 26, -52.6
if ROWS then
	MALL = false
	local west = ROW_X0 - 3 * SHOP_W - 2 * ROW_GAP -- bord ouest des boutiques du fond (-296,6)
	local back = ROW_Z + SHOP_D -- fond des boutiques (|z| = 140)
	HUB = { x0 = math.round(west - 11.4), x1 = 30, z0 = -(back + 16), z1 = back + 16 } -- x -308..30, |z| <= 156
end
-- Clément, 2026-11-08 (capture d'un jeu « Steal a … ») : LINE = les boutiques côte à côte sur une rangée, façades vers
-- l'entrée de la zone 1 (on comprend tout de suite qu'il faut aller en face), 10 entre deux boutiques, 120 de place
-- entre les façades et la ligne de la zone sûre (x 22) ; un grand mur en damier (48 de haut) fait le tour du hub et
-- cache le décor du dehors ; les stands sont de part et d'autre de l'entrée, comptoir vers les boutiques.
local LINE_FX, LINE_GAP, BIG_H = -98, 10, 48 -- x des façades, écart entre deux boutiques, hauteur du grand mur
-- 2026-11-12 : serveurs de 8 joueurs (L-113, décision de Clément) : 8 boutiques en ligne (PlotIndex 1 à 8, 1 au nord).
-- Le demi-cercle et les rangées 3 face à 3 gardent 6 emplacements.
local SHOP_COUNT = LINE and 8 or 6
-- Clément, 2026-11-12 : 6 boutiques au fond, face au couloir (2 à 7, du nord au sud), et une seule boutique de chaque
-- côté, à 90°, dos au mur nord ou sud, face à la place (1 au nord, 8 au sud), entre la promenade et les stands.
local SIDES = (LINE and SHOP_COUNT == 8) and 2 or 0
local ROW_N = SHOP_COUNT - SIDES -- boutiques de la rangée du fond
local LINE_HALF = (ROW_N / 2) * SHOP_W + ((ROW_N - 1) / 2) * LINE_GAP -- demi-longueur de la rangée (217 pour 6)
local PATH_W = 16 -- largeur de tous les chemins de la base (dalle), plus 1 de bordure de chaque côté
-- centre des boutiques des côtés : au milieu de la promenade devant elles (dalle x -85..-1), donc -43 (Clément, 2026-11-12 :
-- « ceux sur le bord ne sont pas centrés »)
local SIDE_X = ((LINE_FX + 13) + (-1)) / 2
if LINE then
	MALL = false
	-- mur ouest collé au dos des boutiques (pas de couloir derrière la rangée)
	-- Clément, 2026-11-12 : hub élargi pour que les boutiques des côtés viennent après les dernières du fond (façade à 10
	-- après le bout de la rangée, dos au grand mur) : |z| <= 310 avec elles, 225 sans
	local z1 = SIDES > 0 and (LINE_HALF + LINE_GAP + SHOP_D + 3) or (LINE_HALF + 8)
	HUB = { x0 = LINE_FX - SHOP_D - 3, x1 = 30, z0 = -z1, z1 = z1 } -- x -181..30
end

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
-- 3 face à 3 : { PlotIndex, côté (1 = nord), rang depuis la sortie } ; avant vers l'allée
local FC = S -- centre de la fontaine
if ROWS then
	for _, o in { { 1, 1, 0 }, { 2, 1, 1 }, { 3, 1, 2 }, { 6, -1, 0 }, { 5, -1, 1 }, { 4, -1, 2 } } do
		local k, s, i = o[1], o[2], o[3]
		local x = ROW_X0 - SHOP_W / 2 - i * (SHOP_W + ROW_GAP)
		local n = Vector3.new(0, 0, -s)
		local front = Vector3.new(x, 0, s * ROW_Z)
		local center = front - n * (SHOP_D / 2)
		SITES[k] = { k = k, angle = 0, side = s, front = front, center = center, n = n, cf = frameAt(center, n) }
	end
	FC = Vector3.new(ROW_X0 - SHOP_W / 2 - (SHOP_W + ROW_GAP), 0, 0) -- devant la paire du milieu
end
if LINE then -- rangée du fond, avant vers l'entrée (+X) ; boutiques des côtés, avant vers la place (±Z)
	for i = 1, ROW_N do
		local k = i + SIDES / 2
		local n = Vector3.new(1, 0, 0)
		local front = Vector3.new(LINE_FX, 0, ((ROW_N + 1) / 2 - i) * (SHOP_W + LINE_GAP))
		local center = front - n * (SHOP_D / 2)
		SITES[k] = { k = k, angle = 0, side = 1, front = front, center = center, n = n, cf = frameAt(center, n) }
	end
	for _, sd in (SIDES > 0 and { { 1, 1 }, { SHOP_COUNT, -1 } } or {}) do
		local k, s = sd[1], sd[2]
		local n = Vector3.new(0, 0, -s) -- au nord, avant vers le sud ; au sud, vers le nord
		local center = Vector3.new(SIDE_X, 0, s * (HUB.z1 - 3 - SHOP_D / 2)) -- dos collé au grand mur
		SITES[k] = { k = k, angle = 0, side = s, sideShop = true, front = center + n * (SHOP_D / 2), center = center, n = n, cf = frameAt(center, n) }
	end
	FC = Vector3.new(-35, 0, 0) -- au milieu de la place, dans l'axe de l'entrée
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
-- Clément, 2026-11-12 : plus de lampadaires dans la base en rangée (allées, stands, sortie)
local LAMPS = not LINE
local function lamp(parent, name, pos, h)
	if not LAMPS then return end
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
-- Arbre en bac (tronc et boules provisoires) : tools/clement/env/trees_replace.luau le remplace ensuite par un arbre du
-- pack de Clément, teinté pour le hub ; relancer ce script-là après celui-ci
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
-- Fontaine du centre (Clément, 2026-11-08 : une vraie fontaine, au centre). Bassin, vasque, coupe et colis doré en couronne.
-- Eau en Beams (8 arcs du bord du bassin vers la vasque, cascades d'une coupe à l'autre, jet central) et en
-- ParticleEmitters (gerbe du jet, éclaboussures, rides, brume, reflets), textures livrées avec le client, aucun script.
-- La nuit, les 8 spots du bassin et le colis doré s'allument (NightLight).
local NOISE = "rbxasset://textures/noise.dds"
local RIPPLE = "rbxasset://textures/particles/explosion01_shockwave_main.dds"
local MIST = "rbxasset://textures/particles/smoke_main.dds"
local GLINT = "rbxasset://textures/particles/sparkles_main.dds"
local WATER_D, WATER_S, SPRAY = rgb(30, 92, 160), rgb(70, 170, 235), rgb(225, 245, 255)
local GLASSY = { mat = GLASS, T = 0.3, refl = 0.15, decor = true, noShadow = true } -- surface de l'eau
local DEEP = { decor = true, noShadow = true } -- fond bleu sous l'eau
local function ns(...) -- NumberSequence par couples (temps, valeur)
	local a, kp = { ... }, {}
	for i = 1, #a, 2 do table.insert(kp, NumberSequenceKeypoint.new(a[i], a[i + 1])) end
	return NumberSequence.new(kp)
end
-- Anneau de n blocs (margelle) de centre c au sol, rayon r (milieu du bloc), épaisseur radiale, de y0 à y1 ; un bloc
-- sur deux plus haut de 0,02 : deux faces du dessus ne se confondent jamais là où les blocs se chevauchent
local function ring(parent, name, c, r, n, radial, y0, y1, color, opt)
	local len = 2 * (r + radial / 2) * math.tan(math.pi / n) + 0.02
	for i = 1, n do
		local a = (i - 0.5) * 2 * math.pi / n
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local h = (i % 2 == 0) and 0.02 or 0
		local p = c + dir * r + Vector3.new(0, (y0 + y1 + h) / 2, 0)
		P(parent, name .. "_" .. i, CFrame.lookAt(p, p + dir), Vector3.new(len, y1 - y0 + h, radial), color, opt)
	end
end
local function waterBeam(host, name, a0, a1, w0, w1, o)
	local b = Instance.new("Beam"); b.Name = name; b.Attachment0 = a0; b.Attachment1 = a1
	b.Width0 = w0; b.Width1 = w1; b.FaceCamera = true; b.Segments = o.segments or 12
	b.CurveSize0 = o.c0 or 0; b.CurveSize1 = o.c1 or 0
	b.Texture = NOISE; b.TextureMode = Enum.TextureMode.Wrap; b.TextureLength = o.len or 2.5; b.TextureSpeed = o.speed or 2
	b.Color = ColorSequence.new(SPRAY, WATER_S); b.LightEmission = o.glow or 0.4; b.LightInfluence = 0.6
	b.Transparency = NumberSequence.new(o.t0 or 0.15, o.t1 or 0.45)
	b.Parent = host
	return b
end
local function emitter(parent, name, o)
	local e = Instance.new("ParticleEmitter"); e.Name = name; e.Texture = o.tex or SPARK; e.EmissionDirection = TOP
	e.Rate = o.rate; e.Lifetime = NumberRange.new(o.life[1], o.life[2]); e.Speed = NumberRange.new(o.speed[1], o.speed[2])
	e.SpreadAngle = Vector2.new(o.spread or 0, o.spread or 0); e.Acceleration = o.acc or Vector3.zero; e.Drag = o.drag or 0
	e.LightEmission = o.glow or 0.3; e.LightInfluence = o.li or 0.7
	e.Size = o.size; e.Transparency = o.transp; e.Color = o.color or ColorSequence.new(SPRAY)
	if o.flat then e.Orientation = Enum.ParticleOrientation.VelocityPerpendicular end -- à plat sur l'eau
	if o.spin then e.Rotation = NumberRange.new(0, 360) end
	e.Parent = parent
	return e
end
local function fountain(m, c)
	local f = CFrame.new(c)
	-- bassin (eau à 2,55), vasque (8,55), coupe (13,35), colis doré
	Vc(m, f, "FountainStep", 0, 0, 0.6, 0, 27, CREAM_L, { studs = true })
	Vc(m, f, "FountainBasin", 0, 0.6, 2.4, 0, 24.8, STONE, { studs = true })
	Vc(m, f, "FountainBasinFloor", 0, 2.4, 2.42, 0, 23, WATER_D, DEEP)
	Vc(m, f, "FountainBasinWater", 0, 2.42, 2.55, 0, 23, WATER_S, GLASSY)
	ring(m, "FountainBasinLip", c, 11.9, 24, 1.0, 2.4, 3.0, CREAM_L, { studs = true })
	Vc(m, f, "FountainPier", 0, 2.4, 3.2, 0, 4.2, STONE, { studs = true })
	Vc(m, f, "FountainColumn", 0, 3.2, 7.4, 0, 3.0, STONE, { studs = true })
	Vc(m, f, "FountainColumnBand", 0, 5.0, 5.4, 0, 3.4, GOLD, {})
	Vc(m, f, "FountainBowlBase", 0, 6.8, 7.4, 0, 8, STONE, { studs = true })
	Vc(m, f, "FountainBowl", 0, 7.4, 8.4, 0, 13, STONE, { studs = true })
	Vc(m, f, "FountainBowlFloor", 0, 8.4, 8.42, 0, 11.8, WATER_D, DEEP)
	Vc(m, f, "FountainBowlWater", 0, 8.42, 8.55, 0, 11.8, WATER_S, GLASSY)
	ring(m, "FountainBowlLip", c, 6.2, 16, 0.6, 8.4, 8.85, CREAM_L, { studs = true })
	Vc(m, f, "FountainStem", 0, 8.4, 12.4, 0, 2.2, STONE, { studs = true })
	Vc(m, f, "FountainStemBand", 0, 10.2, 10.6, 0, 2.6, GOLD, {})
	Vc(m, f, "FountainCupBase", 0, 11.8, 12.4, 0, 4.6, STONE, { studs = true })
	Vc(m, f, "FountainCup", 0, 12.4, 13.2, 0, 7, STONE, { studs = true })
	Vc(m, f, "FountainCupFloor", 0, 13.2, 13.22, 0, 6.0, WATER_D, DEEP)
	Vc(m, f, "FountainCupWater", 0, 13.22, 13.35, 0, 6.0, WATER_S, GLASSY)
	ring(m, "FountainCupLip", c, 3.25, 12, 0.5, 13.2, 13.55, CREAM_L, { studs = true })
	Vc(m, f, "FountainCrownStem", 0, 13.2, 14.0, 0, 1.6, STONE, { studs = true })
	local box = Bx(m, f, "GoldenBox", -1.2, 14.0, -1.2, 1.2, 16.4, 1.2, GOLD_L, { refl = 0.25 })
	Bx(m, f, "GoldenBox_TapeX", -1.25, 14.0, -0.3, 1.25, 16.45, 0.3, GOLD, { decor = true })
	Bx(m, f, "GoldenBox_TapeZ", -0.3, 14.0, -1.25, 0.3, 16.5, 1.25, GOLD, { decor = true })
	nightLight(box, 22, 1.6)
	-- spots sous l'eau du bassin, entre les arcs, tournés vers le haut
	for i = 1, 8 do
		local a = math.rad(22.5 + (i - 1) * 45)
		local spot = Bx(m, f, "FountainLight_" .. i, math.cos(a) * 9 - 0.5, 2.42, math.sin(a) * 9 - 0.5, math.cos(a) * 9 + 0.5, 2.5,
			math.sin(a) * 9 + 0.5, rgb(200, 240, 255), { decor = true, noShadow = true })
		local l = Instance.new("SpotLight"); l.Face = TOP; l.Angle = 50; l.Range = 18; l.Brightness = 4
		l.Color = rgb(150, 210, 255); l.Shadows = false; l.Enabled = false; l.Parent = spot
		CS:AddTag(spot, NIGHT_LIGHT)
	end
	-- l'eau : une pièce invisible porte les Attachments des Beams ; Axis (X) = sens de l'eau au départ ou à l'arrivée
	local host = Bx(m, f, "FountainJets", -0.5, 2.0, -0.5, 0.5, 3.0, 0.5, WHITE, { T = 1, decor = true, noShadow = true })
	local function A(name, pos, axis)
		local a = Instance.new("Attachment"); a.Name = name; a.Parent = host
		if axis then
			local ref = math.abs(axis.Y) > 0.95 and Vector3.zAxis or Vector3.yAxis
			a.WorldCFrame = CFrame.fromMatrix(pos, axis, (ref - axis * ref:Dot(axis)).Unit)
		else
			a.WorldCFrame = CFrame.new(pos) -- Y vers le haut : pour les gerbes et les éclaboussures
		end
		return a
	end
	local function polar(r, y, a) return c + Vector3.new(math.cos(a) * r, y, math.sin(a) * r) end
	local function dirAt(a, out, up) return (Vector3.new(math.cos(a), 0, math.sin(a)) * out + Vector3.new(0, up, 0)).Unit end
	-- jet central sur le colis, gerbe qui retombe en parapluie dans la vasque et le bassin
	local j0, j1 = A("JetBase", c + Vector3.new(0, 16.5, 0)), A("JetTop", c + Vector3.new(0, 24.5, 0))
	waterBeam(host, "CentralJet", j0, j1, 1.0, 0.5, { segments = 2, len = 3, speed = 3, t0 = 0.1, t1 = 0.5, glow = 0.5 })
	waterBeam(host, "CentralJetCore", j0, j1, 0.45, 0.2, { segments = 2, len = 2, speed = 4, t0 = 0, t1 = 0.3, glow = 0.7 })
	emitter(j1, "CrownSpray", { rate = 90, life = { 1.1, 1.5 }, speed = { 5, 8 }, spread = 55, acc = Vector3.new(0, -28, 0), drag = 0.4,
		size = ns(0, 0.4, 1, 0.15), transp = ns(0, 0.1, 0.7, 0.35, 1, 1), color = ColorSequence.new(SPRAY, WATER_S) })
	-- cascades : de la coupe vers la vasque (12), de la vasque vers le bassin (16)
	for i = 1, 12 do
		local a = (i - 0.5) * 2 * math.pi / 12
		waterBeam(host, "CupFall_" .. i, A("CupFallTop_" .. i, polar(3.55, 13.5, a), dirAt(a, 1, 0)), A("CupFallEnd_" .. i, polar(4.5, 8.6, a), -Vector3.yAxis),
			1.7, 2.0, { c0 = 0.6, c1 = 1.6, len = 2, speed = 2, t0 = 0.3, t1 = 0.55 })
	end
	for i = 1, 16 do
		local a = (i - 0.5) * 2 * math.pi / 16
		waterBeam(host, "BowlFall_" .. i, A("BowlFallTop_" .. i, polar(6.55, 8.8, a), dirAt(a, 1, 0)), A("BowlFallEnd_" .. i, polar(7.7, 2.6, a), -Vector3.yAxis),
			2.5, 2.9, { c0 = 0.9, c1 = 2.2, len = 2.5, speed = 2, t0 = 0.3, t1 = 0.55 })
	end
	-- 8 arcs : buse sur la margelle du bassin, l'eau passe par-dessus la vasque et y retombe
	for i = 1, 8 do
		local a = (i - 1) * 2 * math.pi / 8
		local np = polar(11.9, 0, a)
		Vc(m, CFrame.new(np), "FountainNozzle_" .. i, 0, 3.0, 3.4, 0, 0.7, GOLD, {})
		local land = polar(5.2, 8.6, a)
		waterBeam(host, "Arc_" .. i, A("ArcStart_" .. i, polar(11.9, 3.45, a), dirAt(a, -0.4, 0.92)), A("ArcEnd_" .. i, land, dirAt(a, -0.35, -0.94)),
			0.6, 0.45, { segments = 16, c0 = 7.5, c1 = 3.5, len = 3, speed = 4, t0 = 0.05, t1 = 0.3, glow = 0.5 })
		emitter(A("ArcSplash_" .. i, land), "Splash", { rate = 20, life = { 0.35, 0.55 }, speed = { 3, 5 }, spread = 35,
			acc = Vector3.new(0, -35, 0), size = ns(0, 0.3, 1, 0.1), transp = ns(0, 0.2, 1, 1) })
	end
	-- rides à plat sur l'eau, brume au pied des cascades, reflets
	local low = Bx(m, f, "FountainRipples", -6.5, 2.54, -6.5, 6.5, 2.59, 6.5, WHITE, { T = 1, decor = true, noShadow = true })
	emitter(low, "Ripples", { tex = RIPPLE, rate = 7, life = { 1.8, 2.6 }, speed = { 0.02, 0.05 }, flat = true, spin = true, glow = 0.3,
		size = ns(0, 0.5, 1, 3.4), transp = ns(0, 0.5, 1, 1), color = ColorSequence.new(rgb(220, 245, 255)) })
	emitter(low, "Glints", { tex = GLINT, rate = 4, life = { 0.5, 0.8 }, speed = { 0, 0 }, glow = 1, size = ns(0, 0.6, 1, 0), transp = ns(0, 0, 1, 1) })
	local mid = Bx(m, f, "FountainBowlRipples", -3.5, 8.54, -3.5, 3.5, 8.59, 3.5, WHITE, { T = 1, decor = true, noShadow = true })
	emitter(mid, "Ripples", { tex = RIPPLE, rate = 4, life = { 1.6, 2.2 }, speed = { 0.02, 0.05 }, flat = true, spin = true, glow = 0.3,
		size = ns(0, 0.4, 1, 2.4), transp = ns(0, 0.5, 1, 1), color = ColorSequence.new(rgb(220, 245, 255)) })
	local mist = Bx(m, f, "FountainMist", -8, 2.6, -8, 8, 2.7, 8, WHITE, { T = 1, decor = true, noShadow = true })
	emitter(mist, "Mist", { tex = MIST, rate = 5, life = { 2.2, 3.2 }, speed = { 0.4, 1 }, spread = 20, drag = 0.6, glow = 0.2, spin = true,
		size = ns(0, 1.6, 1, 3.6), transp = ns(0, 0.82, 1, 1) })
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
local OWN = { "Ground", "Plaza", "Mall", "Trucks", "Stalls", "Parking", "Garden", "Walls", "PlotSites", "SafeZone", "Spawn" }
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
	-- pelouse (hub simplifié, 2026-11-08) : les allées claires et les boutiques ressortent dessus
	local GROUND_C = MALL and PLAZA or GRASS
	ground(g, "Ground_Plaza", HUB.x0, HUB.z0, 0, HUB.z1, GROUND_C)
	ground(g, "Ground_Flank_N", 0, EXIT_HALF, 30, HUB.z1, GROUND_C)
	ground(g, "Ground_Flank_S", 0, HUB.z0, 30, -EXIT_HALF, GROUND_C)
	ground(g, "Ground_ExitStreet", 0, -EXIT_ROAD, 30, EXIT_ROAD, STREET)
	for _, s in { 1, -1 } do
		local tag = s > 0 and "N" or "S"
		local function zz(a, b) return math.min(a * s, b * s), math.max(a * s, b * s) end
		local z0, z1 = zz(EXIT_ROAD, EXIT_ROAD + 0.75)
		Bx(g, W, "Ground_ExitKerb_" .. tag, 0, -2, z0, 25.4, 0.45, z1, KERB_W, O)
		z0, z1 = zz(EXIT_ROAD + 0.75, EXIT_HALF)
		Bx(g, W, "Ground_ExitSidewalk_" .. tag, 0, -2, z0, 25.4, 0.45, z1, PAVEMENT, O)
		z0, z1 = zz(EXIT_ROAD, EXIT_HALF)
		Bx(g, W, "Ground_WallTrack_" .. tag, 25.4, -2, z0, 30, 0, z1, STEEL, O) -- là où monte le mur de nuit
		z0, z1 = zz(EXIT_ROAD, EXIT_HALF)
		Bx(g, W, "SafeLine_" .. tag, 21.4, 0.44, z0, 22.6, 0.5, z1, SAFE_C, { decor = true, noShadow = true })
	end
	Bx(g, W, "SafeLine", 21.4, -0.01, -EXIT_ROAD, 22.6, 0.05, EXIT_ROAD, SAFE_C, { decor = true, noShadow = true })
	local plate = P(g, "SafeZoneText", CFrame.lookAt(Vector3.new(16, 0.03, 0), Vector3.new(15, 0.03, 0)), Vector3.new(32, 0.05, 7), SAFE_C,
		{ T = 1, decor = true, noShadow = true })
	txt(surface(plate, TOP, 20), "SAFE ZONE", SAFE_C, 0, 0, 1, 1, { font = LUCKY, strokeT = 4 })
	-- pelouse habillée (Clément, 2026-11-08 : « des petits carrés vert foncé ») : taches de cases de 4 studs sur la place,
	-- hors des boutiques, de la promenade, des lampadaires, de l'avenue, des stands et de la rue ; tirage fixe (graine 2611)
	if LINE then
		local rng = Random.new(2611)
		local PATCH = { rgb(92, 170, 76), rgb(84, 160, 70) }
		local spz0 = (HUB.z1 - 3 - SHOP_D - 13) - PATH_W -- dalle des promenades des côtés à partir de |z| 198
		local function free(x, z) -- centre d'une case de 4 (de -2 à +2)
			local az = math.abs(z)
			if x < LINE_FX + 36 or x > 25 or az > HUB.z1 - 6 then return false end -- rangée, sa promenade, ses lampadaires, mur
			if az < PATH_W / 2 + 3 and x < 3 then return false end -- avenue
			if x > -20 and x < 2 then return false end -- allée des stands
			if x >= 2 and az < 104 + EXIT_W then return false end -- stands, rue de la sortie
			if SIDES > 0 and az > spz0 - 9 and x < math.max(SIDE_X + SHOP_W / 2, 0) + 4 then return false end -- promenades et boutiques des côtés
			return true
		end
		local pm = Instance.new("Model"); pm.Name = "GrassPatches"
		local used, n = {}, 0
		for _ = 1, math.round(60 * LINE_HALF / 217) do -- 60 taches pour 6 boutiques (80 pour 8), de 3 à 9 cases : environ 11 % de la place
			local gx = math.floor(rng:NextNumber(LINE_FX + 34, 25) / 4)
			local gz = math.floor(rng:NextNumber(-(HUB.z1 - 6), HUB.z1 - 6) / 4)
			local color = PATCH[rng:NextInteger(1, 2)]
			for _ = 1, rng:NextInteger(3, 9) do
				local x, z = gx * 4 + 2, gz * 4 + 2
				local key = gx .. ":" .. gz
				if free(x, z) and not used[key] then
					used[key] = true; n += 1
					Bx(pm, W, "GrassPatch_" .. n, x - 2, -0.04, z - 2, x + 2, 0.04, z + 2, color, { studs = true, noShadow = true, decor = true })
				end
				local d = rng:NextInteger(1, 4)
				if d == 1 then gx += 1 elseif d == 2 then gx -= 1 elseif d == 3 then gz += 1 else gz -= 1 end
			end
		end
		pm.Parent = g
	end
	done(g)
end

-- Place : fontaine au centre, d'où partent les allées (6 vers les boutiques, 1 vers la sortie, 4 vers les stands), 4 arbres,
-- lampadaires. Clément, 2026-11-08 : chaque élément a un rôle lisible ; le rond du spawn, sa plaque, ses bornes,
-- l'ancienne fontaine décentrée et les seuils (cachés sous les terrasses des boutiques) sont retirés ; puis hub simplifié :
-- plus de bancs ni de tables de pique-nique.
do
	local m = section("Plaza")
	-- fontaine et sa place ronde ; en rangée, plus sur la place (Clément, 2026-11-08 : « une grosse fontaine en plein milieu
	-- pour rien ») mais gardée en asset : ServerStorage/Assets/Env/ENV_Hub_Fountain, pivot au sol au centre (créé s'il manque)
	local function fountainSet(parent, c)
		disc(parent, "FountainPlaza_Edge", c, 24, 0.04, BRICK, F)
		disc(parent, "FountainPlaza", c, 23, 0.09, PAVE, F)
		disc(parent, "FountainApron", c, 15.5, 0.12, TERRA, F)
		fountain(parent, c)
	end
	local FOUNTAIN_IN_HUB = not LINE
	if FOUNTAIN_IN_HUB then
		fountainSet(m, FC)
	else
		local assets = SS:FindFirstChild("Assets")
		local env = assets and assets:FindFirstChild("Env")
		if env and not env:FindFirstChild("ENV_Hub_Fountain") then
			local fm = Instance.new("Model"); fm.Name = "ENV_Hub_Fountain"
			fountainSet(fm, Vector3.zero)
			fm.WorldPivot = CFrame.identity
			fm.Parent = env
		end
	end
	if LINE then
		-- Chemins de la base (Clément, 2026-11-12 : « des décalages, rien n'est beau ») : une seule largeur (PATH_W = 16) et une
		-- bordure brique de 1 de chaque côté, posée sous la dalle (0,08 contre 0,12) : là où deux chemins se croisent, la dalle
		-- de l'un couvre la bordure de l'autre, sans trait en travers. Promenade en U devant les boutiques, toujours à 12 de
		-- leur façade (le coin avant de la boutique : tapis, banc, socle de l'objet le plus rare, panneaux) ; avenue tout droit
		-- jusqu'à la rue de la zone 1 ; allée des stands qui relie l'avenue au U, à 0,5 des plaques ShopPad.
		local function path(name, x0, z0, x1, z1)
			local ax0, ax1, az0, az1 = math.min(x0, x1), math.max(x0, x1), math.min(z0, z1), math.max(z0, z1)
			Bx(m, W, "WalkwayBorder_" .. name, ax0 - 1, -0.05, az0 - 1, ax1 + 1, 0.08, az1 + 1, BRICK, F)
			Bx(m, W, "Walkway_" .. name, ax0, -0.05, az0, ax1, 0.12, az1, PAVE, F)
		end
		local half = LINE_HALF
		local px0, px1 = LINE_FX + 13, LINE_FX + 13 + PATH_W -- dalle de la promenade de la rangée (x -85..-69), bordure dès x -86
		local spz1 = (HUB.z1 - 3 - SHOP_D - 12) - 1 -- dalle des promenades des côtés : |z| 198..214, bordure dès |z| 215
		local spz0 = spz1 - PATH_W
		local rowEnd = SIDES > 0 and spz0 or half
		path("Front", px0, -rowEnd, px1, rowEnd)
		for _, sd in (SIDES > 0 and { 1, -1 } or {}) do
			path("Side_" .. (sd > 0 and "N" or "S"), px0, spz0 * sd, -1, spz1 * sd) -- bord est commun à l'avenue et à l'allée des stands (x -1)
		end
		path("Main", px1, -PATH_W / 2, -1, PATH_W / 2) -- avenue (z -8..8) ; sa bordure s'arrête au bord de la rue (x 0) : un seuil
		for _, sd in { 1, -1 } do
			path("Stalls_" .. (sd > 0 and "N" or "S"), -1 - PATH_W, (PATH_W / 2) * sd, -1, (SIDES > 0 and spz0 or (100 + EXIT_W)) * sd)
		end
		for k, site in SITES do
			if site.sideShop then
				lamp(m, "Lamp_Walk_" .. k, Vector3.new(site.front.X - 20, 0, (spz0 - 4) * site.side))
			else
				-- à 20 de l'axe de la boutique, du côté du centre de la place, 2 après la bordure de la promenade
				lamp(m, "Lamp_Walk_" .. k, Vector3.new(px1 + 4, 0, site.front.Z - 20 * (site.front.Z >= 0 and 1 or -1)))
			end
		end
	elseif ROWS then
		-- allée centrale (z = 0, 20 de large) de la rue de la zone 1 jusqu'au bout ouest, coupée par la place de la fontaine ;
		-- bordures plus basses (0,08) : les allées des boutiques passent par-dessus à leur départ
		local west = ROW_X0 - 3 * SHOP_W - 2 * ROW_GAP
		local STALL_W = -46 -- bord ouest du parvis des stands
		for i, r in { { 0.6, FC.X + 23 }, { FC.X - 23, west } } do
			strip(m, "Walkway_Main_" .. i, Vector3.new(r[1], 0, 0), Vector3.new(r[2], 0, 0), 20, 0.12, PAVE, F)
			for _, s in { 1, -1 } do
				local x0 = (i == 1) and STALL_W or r[1]
				strip(m, "WalkwayEdge_Main_" .. i .. (s > 0 and "N" or "S"), Vector3.new(x0, 0, 10.6 * s), Vector3.new(r[2], 0, 10.6 * s), 1.2, 0.08, BRICK, F)
			end
		end
		-- parvis des stands, de l'allée centrale jusqu'aux plaques ShopPad (|z| 32)
		for _, s in { 1, -1 } do
			Bx(m, W, "StallsForecourt_" .. (s > 0 and "N" or "S"), STALL_W, -0.05, 10 * s, 0.6, 0.12, (ROW_Z - 11) * s, PAVE, F)
		end
		-- une allée de 14 vers chaque terrasse (jusque sous son bord), un lampadaire à côté
		for k, site in SITES do
			local s = site.side
			local z0 = (math.abs(site.front.X - FC.X) < 1) and 23 or 10
			local a, b = Vector3.new(site.front.X, 0, z0 * s), Vector3.new(site.front.X, 0, (ROW_Z - 11) * s)
			strip(m, "Walkway_" .. k, a, b, 14, 0.12, PAVE, F)
			for _, e in { 1, -1 } do
				local o = Vector3.new(7.6 * e, 0, 0)
				strip(m, "WalkwayEdge_" .. k .. (e > 0 and "L" or "R"), a + o, b + o, 1.2, 0.12, BRICK, F)
			end
			lamp(m, "Lamp_Walk_" .. k, Vector3.new(site.front.X + 11, 0, (ROW_Z - 18) * s))
		end
	else
	-- allée de la fontaine à la sortie (rue de la zone 1, x = 0)
	strip(m, "Walkway_Exit", S + Vector3.new(12, 0, 0), Vector3.new(0.6, 0, S.Z), 22, 0.08, PAVE, F)
	for _, s in { 1, -1 } do
		strip(m, "WalkwayEdge_Exit" .. (s > 0 and "L" or "R"), Vector3.new(S.X + 12, 0, 11.6 * s), Vector3.new(0.6, 0, 11.6 * s), 1.2, 0.08, BRICK, F)
	end
	-- une allée du centre à chaque boutique, un lampadaire près de la boutique (côtés alternés).
	-- Clément, 2026-11-08 : peu de lampadaires, bien placés (sortie, allées, devant les stands)
	for k = 1, 6 do
		local site = SITES[k]
		local d = site.front - S
		local len = d.Magnitude; d = d.Unit
		local a, b = S + d * 23.5, S + d * (len - 4)
		local side = Vector3.new(-d.Z, 0, d.X)
		strip(m, "Walkway_" .. k, a, b, 10, 0.12, PAVE, F)
		strip(m, "WalkwayEdge_" .. k .. "L", a + side * 5.6, b + side * 5.6, 1.2, 0.12, BRICK, F)
		strip(m, "WalkwayEdge_" .. k .. "R", a - side * 5.6, b - side * 5.6, 1.2, 0.12, BRICK, F)
		-- à 22 de la façade : la terrasse de la boutique (tapis et banc) s'avance de 12 devant, le lampadaire reste à 1,5 au moins
		lamp(m, "Lamp_Walk_" .. k, S + d * (len - 22) + side * ((k % 2 == 1) and 9.5 or -9.5))
	end
	-- un arbre entre deux allées, devant l'écart entre deux boutiques
	for i, a in { STEP, -STEP, 2 * STEP, -2 * STEP } do
		tree(m, "Tree_" .. i, at(a, 118))
	end
	end -- if ROWS
	done(m)
end

-- Centre commercial : façade en arc derrière les boutiques, tour centrale à l'enseigne, piliers, tours d'angle
-- (seulement si MALL)
if MALL then
	local m = section("Mall")
	local O = { studs = true }
	for i = 0, 28 do -- de -84° à 84° : les deux bouts de l'arc rejoignent le mur est
		local phi = -84 + i * 6
		if math.abs(phi) > 15 then
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
	Bx(m, tf, "Tower", -61, 0, 0, 61, 114, 56, CREAM, O) -- ±61 : rejoint les panneaux de façade à ±15°
	Bx(m, tf, "Tower_CornerL", -62, 0, -1.2, -58.5, 114, 1, BRICK, O)
	Bx(m, tf, "Tower_CornerR", 58.5, 0, -1.2, 62, 114, 1, BRICK, O)
	Bx(m, tf, "Tower_Course", -61, 28, -1.4, 61, 30, 0, BRICK, O)
	Bx(m, tf, "Tower_Atrium", -50, 30, -0.4, 50, 66, 0, GLASS_C, { mat = GLASS, refl = 0.2 })
	for i = 0, 8 do
		local x = -50 + i * 12.5
		Bx(m, tf, "Tower_Mullion_" .. (i + 1), x - 0.7, 30, -0.9, x + 0.7, 66, 0, DARK, { decor = true })
	end
	for i, y in { 42, 54 } do Bx(m, tf, "Tower_Transom_" .. i, -50, y - 0.5, -0.9, 50, y + 0.5, 0, DARK, { decor = true }) end
	Bx(m, tf, "Tower_Band", -61, 66, -1.4, 61, 69, 0, BRICK, O)
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
	Bx(m, tf, "Tower_Crown", -62.5, 114, -2.5, 62.5, 117.5, 58, CREAM_L, O)
	for j, x in { -56, 56 } do
		Vc(m, tf, "Tower_Flagpole_" .. j, x, 117.5, 135, 8, 0.6, DARK, { decor = true })
		Bx(m, tf, "Tower_Flag_" .. j, x + 0.3, 128.5, 7.88, x + 8.3, 133.5, 8.12, j == 1 and NAVY or RED, { decor = true })
		Bx(m, tf, "Tower_FlagStripe_" .. j, x + 0.3, 130.5, 7.86, x + 8.3, 131.5, 8.14, GOLD_L, { decor = true })
	end
	-- piliers entre deux boutiques (ferment l'écart entre les façades). Reculés à RC + 4 et sans dalle devant : les
	-- terrasses des boutiques (12 devant la façade) ne laissent qu'un coin étroit entre elles, et rien ne doit les toucher
	for k = 1, 5 do
		local a = (shopAngle(k) + shopAngle(k + 1)) / 2
		local f = frameAt(at(a, RC + 4), facing(a))
		local n = "Pier_" .. k
		group(f * CFrame.new(0, 17, 41), Vector3.new(9, 36, 96))
		Bx(m, f, n, -3.4, 0, 0, 3.4, 34, 88.5, CREAM, O) -- l'écart entre deux façades fait 7,1 à l'avant
		Bx(m, f, n .. "_Plinth", -3.5, 0, -0.6, 3.5, 3, 1, BRICK, O)
		Bx(m, f, n .. "_Cap", -3.5, 34, -1.2, 3.5, 35.6, 60, BRICK, O)
		Bx(m, f, n .. "_Banner", -2.6, 19, -0.5, 2.6, 31, -0.15, (k % 2 == 1) and NAVY or RED, { decor = true })
		Bx(m, f, n .. "_BannerStripe", -2.6, 20.2, -0.56, 2.6, 21.2, -0.45, GOLD_L, { decor = true })
		Bx(m, f, n .. "_BannerRod", -3, 31, -0.8, 3, 31.4, -0.1, DARK, { decor = true })
		wallLantern(m, f, n .. "_Lantern", 0, 14)
		ungroup()
	end
	done(m)
end

-- Stands de marché : les 4 comptoirs de part et d'autre de la sortie, comptoir tourné vers la place, un vendeur
-- derrière (Clément, 2026-11-07 : à la place des food trucks, « avec des rigs qui tiennent le stand »).
-- Bois en Studs (cadre foncé, planches claires), store rayé à la couleur du stand, enseigne au-dessus du store,
-- marchandise du stand, panneau sur pieds, lanterne (NightLight). Pivot au sol au milieu du stand, LookVector = côté du
-- comptoir ; largeur sur X local (17,4, store 19,2), profondeur sur Z local (-6,6 store compris à +5,9).
-- Comptoir du code (PrimaryPart, invite) : le plateau « Counter », à l'avant.
-- Vendeur : rig R15 standard (Players:CreateHumanoidModelFromDescriptionAsync, comme les vigiles), Humanoid avec
-- Animator, racine ancrée, aucun script. Pas encore de dossier Animations : Clément fera Idle et Wave (contrat 2.4) ;
-- le ContractChecker saute un modèle de la map sans ce dossier. Accessoires ACC_Hub_* (Accessory, Handle, attache du
-- corps), en pièces Roblox.
local Players = game:GetService("Players")
local WOOD_D, WOOD_M, WOOD_L = rgb(108, 72, 46), rgb(156, 106, 68), rgb(190, 138, 90)
local ROT_FACE = CFrame.Angles(0, math.rad(90), 0) -- axe du cylindre vers l'avant (-Z local)
local STALLS = {
	{ name = "ENV_Hub_WeaponStall", tag = "WeaponShop", pos = Vector3.new(12, 0, 55 + EXIT_W), goods = "weapons",
		title = "WEAPONS", tagline = "SMASH MORE GLASS!", stripes = { rgb(214, 56, 50), WHITE }, cloth = rgb(190, 40, 40),
		signBg = rgb(44, 30, 24), titleColor = rgb(255, 205, 60), trim = rgb(255, 196, 40),
		vendor = { name = "Vendor_Weapons", skin = rgb(234, 184, 146), shirt = rgb(62, 66, 74), pants = rgb(84, 62, 46), shoes = rgb(40, 36, 34), acc = "weapons" } },
	{ name = "ENV_Hub_RobuxStall", tag = "RobuxShop", pos = Vector3.new(12, 0, 87 + EXIT_W), goods = "robux",
		title = "ROBUX", tagline = "BOOSTS & PASSES", stripes = { rgb(255, 196, 40), WHITE }, cloth = rgb(52, 168, 90),
		signBg = rgb(30, 34, 42), titleColor = rgb(255, 214, 70), trim = rgb(52, 168, 90),
		vendor = { name = "Vendor_Robux", skin = rgb(198, 140, 100), shirt = rgb(60, 170, 100), pants = rgb(232, 226, 212), shoes = rgb(40, 40, 46), acc = "robux" } },
	{ name = "ENV_Hub_AuraStall", tag = "AuraShop", pos = Vector3.new(12, 0, -55 - EXIT_W), goods = "auras",
		title = "AURAS", tagline = "GLOW UP · RUN FASTER", stripes = { rgb(132, 84, 224), WHITE }, cloth = rgb(64, 204, 226),
		signBg = rgb(36, 26, 64), titleColor = rgb(120, 236, 255), trim = rgb(255, 120, 200),
		vendor = { name = "Vendor_Auras", skin = rgb(255, 214, 182), shirt = rgb(118, 78, 200), pants = rgb(54, 44, 82), shoes = rgb(36, 30, 52), acc = "auras" } },
	{ name = "ENV_Hub_PawnStall", tag = "PawnShop", pos = Vector3.new(12, 0, -87 - EXIT_W), goods = "pawn",
		title = "PAWN SHOP", tagline = "WE BUY ANYTHING. NO QUESTIONS.", stripes = { rgb(34, 116, 78), CREAM }, cloth = rgb(120, 30, 36),
		signBg = rgb(22, 52, 38), titleColor = rgb(255, 214, 90), trim = GOLD,
		vendor = { name = "Vendor_Pawn", skin = rgb(124, 84, 60), shirt = rgb(40, 40, 46), pants = rgb(92, 94, 102), shoes = rgb(28, 28, 30), acc = "pawn" } },
}

-- Accessoires des vendeurs : pièces placées dans le repère de l'attache du corps (-Z = avant), la première = Handle
local function cyl(h, d) return Vector3.new(h, d, d) end
local ACC_SETS = {
	weapons = {
		{ name = "ACC_Hub_Bandana", attach = "HatAttachment", type = Enum.AccessoryType.Hat, parts = {
			{ size = cyl(0.55, 1.32), cf = CFrame.new(0, -0.2, 0.02) * ROT_UP, color = rgb(196, 44, 44), shape = CYL },
			{ name = "Knot", size = Vector3.new(0.42, 0.32, 0.3), cf = CFrame.new(0, -0.3, 0.66), color = rgb(176, 36, 36) },
			{ name = "Tail_L", size = Vector3.new(0.22, 0.62, 0.1), cf = CFrame.new(-0.14, -0.72, 0.7) * CFrame.Angles(0, 0, math.rad(8)), color = rgb(176, 36, 36) },
			{ name = "Tail_R", size = Vector3.new(0.22, 0.56, 0.1), cf = CFrame.new(0.14, -0.7, 0.7) * CFrame.Angles(0, 0, math.rad(-10)), color = rgb(176, 36, 36) },
		} },
		{ name = "ACC_Hub_LeatherApron", attach = "BodyFrontAttachment", type = Enum.AccessoryType.Front, parts = {
			{ size = Vector3.new(1.7, 2.5, 0.12), cf = CFrame.new(0, -0.75, -0.06), color = rgb(96, 62, 40) },
			{ name = "Pocket", size = Vector3.new(0.9, 0.5, 0.06), cf = CFrame.new(0, -1.25, -0.14), color = rgb(78, 50, 32) },
			{ name = "Hammer", size = Vector3.new(0.14, 0.7, 0.14), cf = CFrame.new(0.5, -1.05, -0.2), color = WOOD },
			{ name = "HammerHead", size = Vector3.new(0.45, 0.2, 0.2), cf = CFrame.new(0.5, -0.68, -0.2), color = STEEL },
		} },
	},
	auras = {
		{ name = "ACC_Hub_MageHat", attach = "HatAttachment", type = Enum.AccessoryType.Hat, parts = {
			{ size = cyl(0.14, 2.3), cf = CFrame.new(0, -0.05, 0) * ROT_UP, color = rgb(96, 58, 172), shape = CYL },
			{ name = "Band", size = cyl(0.32, 1.36), cf = CFrame.new(0, 0.16, 0) * ROT_UP, color = GOLD, shape = CYL },
			{ name = "Cone_1", size = cyl(0.5, 1.22), cf = CFrame.new(0, 0.55, 0) * ROT_UP, color = rgb(110, 70, 190), shape = CYL },
			{ name = "Cone_2", size = cyl(0.5, 0.92), cf = CFrame.new(0.06, 1.0, 0.04) * ROT_UP, color = rgb(110, 70, 190), shape = CYL },
			{ name = "Cone_3", size = cyl(0.5, 0.62), cf = CFrame.new(0.14, 1.42, 0.08) * ROT_UP, color = rgb(110, 70, 190), shape = CYL },
			{ name = "Cone_4", size = cyl(0.42, 0.34), cf = CFrame.new(0.24, 1.8, 0.12) * ROT_UP, color = rgb(110, 70, 190), shape = CYL },
			{ name = "Star", size = Vector3.new(0.36, 0.36, 0.36), cf = CFrame.new(0.32, 2.08, 0.14), color = rgb(255, 226, 90), shape = BALL, mat = NEON },
		} },
		{ name = "ACC_Hub_AuraPendant", attach = "BodyFrontAttachment", type = Enum.AccessoryType.Neck, parts = {
			{ size = Vector3.new(0.46, 0.46, 0.46), cf = CFrame.new(0, 0.05, -0.2), color = rgb(90, 230, 255), shape = BALL, mat = NEON },
			{ name = "Cord_L", size = Vector3.new(0.06, 0.62, 0.06), cf = CFrame.new(-0.22, 0.38, -0.12) * CFrame.Angles(0, 0, math.rad(-35)), color = rgb(40, 34, 60) },
			{ name = "Cord_R", size = Vector3.new(0.06, 0.62, 0.06), cf = CFrame.new(0.22, 0.38, -0.12) * CFrame.Angles(0, 0, math.rad(35)), color = rgb(40, 34, 60) },
		} },
	},
	robux = {
		{ name = "ACC_Hub_GreenCap", attach = "HatAttachment", type = Enum.AccessoryType.Hat, parts = {
			{ size = cyl(0.42, 1.32), cf = CFrame.new(0, -0.12, 0.02) * ROT_UP, color = rgb(52, 168, 90), shape = CYL },
			{ name = "Bill", size = Vector3.new(1.0, 0.1, 0.75), cf = CFrame.new(0, -0.3, -0.92) * CFrame.Angles(math.rad(-8), 0, 0), color = rgb(40, 140, 74) },
			{ name = "Button", size = Vector3.new(0.18, 0.1, 0.18), cf = CFrame.new(0, 0.1, 0.02), color = rgb(40, 140, 74) },
		} },
		{ name = "ACC_Hub_GoldMedal", attach = "BodyFrontAttachment", type = Enum.AccessoryType.Neck, parts = {
			{ size = cyl(0.14, 0.72), cf = CFrame.new(0, 0.05, -0.16) * ROT_FACE, color = GOLD_L, shape = CYL, refl = 0.2 },
			{ name = "Ribbon_L", size = Vector3.new(0.12, 0.7, 0.05), cf = CFrame.new(-0.24, 0.48, -0.1) * CFrame.Angles(0, 0, math.rad(-30)), color = rgb(52, 168, 90) },
			{ name = "Ribbon_R", size = Vector3.new(0.12, 0.7, 0.05), cf = CFrame.new(0.24, 0.48, -0.1) * CFrame.Angles(0, 0, math.rad(30)), color = rgb(52, 168, 90) },
		} },
	},
	pawn = {
		{ name = "ACC_Hub_Fedora", attach = "HatAttachment", type = Enum.AccessoryType.Hat, parts = {
			{ size = cyl(0.12, 2.0), cf = CFrame.new(0, -0.08, 0) * ROT_UP, color = rgb(34, 34, 38), shape = CYL },
			{ name = "Crown", size = cyl(0.72, 1.26), cf = CFrame.new(0, 0.3, 0) * ROT_UP, color = rgb(34, 34, 38), shape = CYL },
			{ name = "HatBand", size = cyl(0.18, 1.29), cf = CFrame.new(0, 0.06, 0) * ROT_UP, color = rgb(120, 30, 36), shape = CYL },
		} },
		{ name = "ACC_Hub_Shades", attach = "FaceFrontAttachment", type = Enum.AccessoryType.Face, parts = {
			{ size = Vector3.new(0.16, 0.06, 0.06), cf = CFrame.new(0, 0.16, -0.04), color = rgb(20, 20, 24) },
			{ name = "Lens_L", size = Vector3.new(0.44, 0.26, 0.06), cf = CFrame.new(-0.28, 0.12, -0.05), color = rgb(20, 20, 24), refl = 0.3 },
			{ name = "Lens_R", size = Vector3.new(0.44, 0.26, 0.06), cf = CFrame.new(0.28, 0.12, -0.05), color = rgb(20, 20, 24), refl = 0.3 },
		} },
		{ name = "ACC_Hub_GoldChain", attach = "BodyFrontAttachment", type = Enum.AccessoryType.Neck, parts = {
			{ size = Vector3.new(0.3, 0.3, 0.3), cf = CFrame.new(0, -0.05, -0.14), color = GOLD_L, shape = BALL, refl = 0.25 },
			{ name = "Chain_L", size = Vector3.new(0.1, 0.75, 0.08), cf = CFrame.new(-0.26, 0.3, -0.1) * CFrame.Angles(0, 0, math.rad(-38)), color = GOLD },
			{ name = "Chain_R", size = Vector3.new(0.1, 0.75, 0.08), cf = CFrame.new(0.26, 0.3, -0.1) * CFrame.Angles(0, 0, math.rad(38)), color = GOLD },
		} },
	},
}

-- Pose de repos : chaque pièce du rig placée par son articulation depuis le HumanoidRootPart (comme les vigiles)
local function poseRest(model, humanoid)
	local root = model:FindFirstChild("HumanoidRootPart")
	root.CFrame = CFrame.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)
	local joints = {}
	for _, d in model:GetDescendants() do
		if d:IsA("AnimationConstraint") and d.Attachment0 and d.Attachment1 then
			table.insert(joints, { p0 = d.Attachment0.Parent, p1 = d.Attachment1.Parent, c0 = d.Attachment0.CFrame, c1 = d.Attachment1.CFrame })
		elseif d:IsA("Motor6D") and d.Part0 and d.Part1 then
			table.insert(joints, { p0 = d.Part0, p1 = d.Part1, c0 = d.C0, c1 = d.C1 })
		end
	end
	local placed, moved = { [root] = true }, true
	while moved do
		moved = false
		for _, j in joints do
			if placed[j.p0] and not placed[j.p1] then
				j.p1.CFrame = j.p0.CFrame * j.c0 * j.c1:Inverse()
				placed[j.p1] = true
				moved = true
			end
		end
	end
end

local function accessory(model, a)
	local attach
	for _, c in model:GetChildren() do
		local found = c:IsA("BasePart") and c:FindFirstChild(a.attach)
		if found and found:IsA("Attachment") then attach = found; break end
	end
	if not attach then return a.name .. " : attache " .. a.attach .. " absente du rig" end
	local body = attach.Parent
	local acc = Instance.new("Accessory"); acc.Name = a.name; acc.AccessoryType = a.type
	local handle
	for i, p in a.parts do
		local part = Instance.new("Part")
		part.Name = (i == 1) and "Handle" or p.name
		part.Shape = p.shape or Enum.PartType.Block
		part.Size = p.size; part.Color = p.color; part.Material = p.mat or SMOOTH; part.Reflectance = p.refl or 0
		part.TopSurface = Enum.SurfaceType.Smooth; part.BottomSurface = Enum.SurfaceType.Smooth
		part.Anchored = false; part.CanCollide = false; part.CanTouch = false; part.CanQuery = false; part.Massless = true
		part.CFrame = attach.WorldCFrame * p.cf
		if i == 1 then
			handle = part
			local ha = Instance.new("Attachment"); ha.Name = a.attach; ha.CFrame = p.cf:Inverse(); ha.Parent = part
			local w = Instance.new("Weld"); w.Name = "AccessoryWeld"
			w.Part0 = part; w.Part1 = body; w.C0 = ha.CFrame; w.C1 = attach.CFrame; w.Parent = part
		else
			local w = Instance.new("Weld"); w.Name = "AccessoryPartWeld"
			w.Part0 = handle; w.Part1 = part; w.C0 = handle.CFrame:Inverse() * part.CFrame; w.Parent = part
		end
		part.Parent = acc
	end
	acc.Parent = model
	return nil
end

-- Vendeur debout sur le plancher intérieur (y local 1,2), face au comptoir
local function vendor(v, cf)
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = v.skin; desc.TorsoColor = v.shirt
	desc.LeftArmColor = v.skin; desc.RightArmColor = v.skin
	desc.LeftLegColor = v.pants; desc.RightLegColor = v.pants
	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromDescriptionAsync(desc, Enum.HumanoidRigType.R15)
	end)
	desc:Destroy()
	if not ok then return nil, "rig impossible (" .. tostring(result) .. ")" end
	local model = result
	model.Name = v.name
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("BodyColors") then d:Destroy() end
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum then model:Destroy(); return nil, "Humanoid absent du rig" end
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.NameDisplayDistance = 0
	if not hum:FindFirstChildOfClass("Animator") then Instance.new("Animator").Parent = hum end
	-- manches courtes : haut des bras à la couleur du haut, chaussures foncées
	local COLORS = { Head = v.skin, UpperTorso = v.shirt, LowerTorso = v.pants, LeftUpperArm = v.shirt, RightUpperArm = v.shirt,
		LeftLowerArm = v.skin, RightLowerArm = v.skin, LeftHand = v.skin, RightHand = v.skin,
		LeftUpperLeg = v.pants, RightUpperLeg = v.pants, LeftLowerLeg = v.pants, RightLowerLeg = v.pants, LeftFoot = v.shoes, RightFoot = v.shoes }
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and COLORS[p.Name] then p.Color = COLORS[p.Name] end
	end
	poseRest(model, hum)
	for _, a in ACC_SETS[v.acc] or {} do
		local err = accessory(model, a)
		if err then add("Vendeur " .. v.name .. " : " .. err) end
	end
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	root.Anchored = true
	model:PivotTo(cf * CFrame.new(0, 1.2 + hum.HipHeight + root.Size.Y / 2, -0.5))
	return model
end

-- Marchandise du stand, dans le repère du stand
local function goods(m, cf, t)
	local function B(name, x0, y0, z0, x1, y1, z1, color, opt) return Bx(m, cf, name, x0, y0, z0, x1, y1, z1, color, opt) end
	local D = { decor = true }
	if t.goods == "weapons" then
		-- batte, marteau, pied-de-biche, clé, hache, accrochés au mur du fond ; boîte à outils et caisse sur le comptoir
		B("ToolRail", -6.6, 9.1, 4.3, 6.6, 9.4, 4.75, STEEL, D)
		Vc(m, cf, "Rack_BatGrip", -5.2, 7.9, 9.1, 4.2, 0.36, DARK, D)
		Vc(m, cf, "Rack_Bat", -5.2, 5.0, 7.9, 4.2, 0.85, WOOD, D)
		Vc(m, cf, "Rack_HammerGrip", -2.6, 5.6, 8.4, 4.2, 0.32, WOOD, D)
		B("Rack_HammerHead", -3.3, 8.3, 3.9, -1.9, 9.0, 4.5, STEEL, D)
		B("Rack_Crowbar", 0.05, 5.2, 4.05, 0.35, 9.0, 4.35, rgb(196, 44, 44), D)
		B("Rack_CrowbarHook", -0.45, 8.8, 4.05, 0.35, 9.1, 4.35, rgb(196, 44, 44), D)
		B("Rack_Wrench", 2.4, 5.6, 4.05, 2.75, 8.4, 4.35, STEEL_L, D)
		B("Rack_WrenchJaw", 2.1, 8.4, 4.05, 3.05, 9.0, 4.35, STEEL_L, D)
		Vc(m, cf, "Rack_AxeGrip", 5.2, 5.0, 9.0, 4.2, 0.32, WOOD, D)
		B("Rack_AxeHead", 4.6, 7.8, 3.95, 5.9, 8.9, 4.45, rgb(196, 44, 44), D)
		B("Toolbox", -5.8, 4.2, -4.1, -3.0, 5.3, -2.5, rgb(196, 44, 44), D)
		B("ToolboxLid", -5.9, 5.3, -4.2, -2.9, 5.5, -2.4, rgb(150, 30, 30), D)
		B("ToolboxHandle", -4.8, 5.5, -3.45, -4.0, 5.9, -3.15, DARK, D)
		B("Crate", 3.0, 4.2, -4.3, 5.4, 5.6, -2.4, WOOD_M, { decor = true, studs = true })
		Vc(m, cf, "CrateBat", 4.6, 5.6, 7.6, -3.4, 0.7, WOOD, D)
		Vc(m, cf, "CrateBatGrip", 4.6, 7.6, 8.4, -3.4, 0.32, DARK, D)
	elseif t.goods == "auras" then
		-- trois orbes lumineux sur le comptoir, nuancier d'auras au fond
		for i, o in { { -4.2, rgb(176, 110, 255) }, { 0, rgb(90, 230, 255) }, { 4.2, rgb(255, 120, 200) } } do
			Vc(m, cf, "OrbStand_" .. i, o[1], 4.2, 4.9, -3.3, 1.0, DARK, D)
			local orb = Ball(m, cf, "Orb_" .. i, o[1], 5.65, -3.3, 1.5, o[2], { decor = true, mat = NEON })
			if i == 2 then sparkles(orb, rgb(200, 150, 255), rgb(120, 240, 255), 8) end
		end
		for i, c in { rgb(255, 240, 120), rgb(255, 150, 60), rgb(120, 200, 255), rgb(176, 110, 255), rgb(255, 120, 200), rgb(120, 255, 170) } do
			local x = -6.25 + (i - 1) * 2.5
			B("AuraSwatch_" .. i, x - 0.9, 5.6, 4.3, x + 0.9, 9.6, 4.6, c, { decor = true, mat = NEON })
		end
	elseif t.goods == "robux" then
		-- piles de pièces, grosse pièce R$, cadeaux ; pièce géante au fond
		for i, h in { 0.6, 1.0, 1.4 } do
			Vc(m, cf, "CoinStack_" .. i, -7.2 + i * 1.2, 4.2, 4.2 + h, -3.3, 1.0, GOLD_L, { decor = true, refl = 0.2 })
		end
		Vc(m, cf, "BigCoinStand", 0, 4.2, 4.6, -3.2, 1.2, DARK, D)
		local coin = P(m, "BigCoin", cf * CFrame.new(0, 6.4, -3.2) * ROT_FACE, Vector3.new(0.6, 3.6, 3.6), GOLD_L, { shape = CYL, refl = 0.2, decor = true })
		for _, face in { RIGHT, LEFT } do txt(surface(coin, face, 30), "R$", rgb(130, 86, 10), 0.15, 0.18, 0.7, 0.64, { font = LUCKY, strokeT = 0 }) end
		for i, x in { 3.6, 5.6 } do
			B("GiftBox_" .. i, x - 0.8, 4.2, -4.0, x + 0.8, 5.6, -2.6, rgb(52, 168, 90), D)
			B("GiftRibbonA_" .. i, x - 0.15, 4.2, -4.05, x + 0.15, 5.65, -2.55, GOLD_L, D)
			B("GiftRibbonB_" .. i, x - 0.85, 4.2, -3.45, x + 0.85, 5.65, -3.15, GOLD_L, D)
		end
		local wall = P(m, "WallCoin", cf * CFrame.new(0, 8.4, 4.3) * ROT_FACE, Vector3.new(0.4, 4.4, 4.4), GOLD_L, { shape = CYL, refl = 0.15, decor = true })
		txt(surface(wall, RIGHT, 30), "R$", rgb(130, 86, 10), 0.15, 0.18, 0.7, 0.64, { font = LUCKY, strokeT = 0 })
	else
		-- receleur : caisse enregistreuse, lingots, vase ; étagères de butin au fond ; trois boules dorées sur potence
		B("CashRegister", -6.2, 4.2, -4.0, -3.6, 5.4, -2.5, STEEL, D)
		B("CashRegisterScreen", -5.6, 5.4, -3.2, -4.2, 6.2, -2.9, rgb(40, 52, 70), D)
		for i, p in { { 2.2, 4.2 }, { 3.4, 4.2 }, { 2.8, 4.7 } } do
			B("GoldBar_" .. i, p[1] - 0.55, p[2], -3.6, p[1] + 0.55, p[2] + 0.5, -2.8, GOLD_L, { decor = true, refl = 0.25 })
		end
		Vc(m, cf, "Vase", 5.6, 4.2, 6.0, -3.3, 1.1, rgb(70, 110, 200), D)
		B("Shelf_1", -7.2, 6.0, 3.6, 7.2, 6.3, 4.7, WOOD_D, { decor = true, studs = true })
		B("Shelf_2", -7.2, 9.0, 3.6, 7.2, 9.3, 4.7, WOOD_D, { decor = true, studs = true })
		B("OldTV", -6.4, 6.3, 3.7, -3.6, 8.5, 4.6, rgb(120, 96, 72), D)
		B("OldTVScreen", -6.0, 6.6, 3.62, -4.2, 8.2, 3.7, rgb(60, 80, 90), D)
		Vc(m, cf, "TrophyBase", 0, 6.3, 6.8, 4.1, 1.0, DARK, D)
		Vc(m, cf, "TrophyCup", 0, 6.8, 8.2, 4.1, 0.9, GOLD_L, { decor = true, refl = 0.2 })
		P(m, "WallClock", cf * CFrame.new(4.6, 7.6, 4.15) * ROT_FACE, Vector3.new(0.3, 2.0, 2.0), CREAM, { shape = CYL, decor = true })
		B("Radio", -3.0, 9.3, 3.8, -0.8, 10.5, 4.6, rgb(196, 110, 50), D)
		B("Jewelry", 2.0, 9.3, 3.8, 3.6, 9.9, 4.6, rgb(150, 60, 160), D)
		B("PawnBracket", 8.6, 9.6, -3.75, 11.4, 9.9, -3.35, GOLD, D)
		for i, b in { { 9.8, 8.1 }, { 11.0, 8.1 }, { 10.4, 7.1 } } do
			Ball(m, cf, "PawnBall_" .. i, b[1], b[2], -3.55, 0.95, GOLD_L, { decor = true, refl = 0.2 })
			B("PawnChain_" .. i, b[1] - 0.05, b[2] + 0.45, -3.6, b[1] + 0.05, 9.6, -3.5, GOLD, D)
		end
	end
end

-- 3 face à 3 : armes et Robux au nord, auras et receleur au sud, entre la sortie et les premières boutiques, comptoir
-- vers l'allée centrale ; plaque ShopPad au bord de l'allée (|z| = ROW_Z - 12 à ROW_Z - 2,5), comme les terrasses
if ROWS then
	local RP = { WeaponShop = Vector3.new(-9, 0, ROW_Z - 0.5), RobuxShop = Vector3.new(-35, 0, ROW_Z - 0.5), -- 26 d'écart : le panneau
		AuraShop = Vector3.new(-9, 0, 0.5 - ROW_Z), PawnShop = Vector3.new(-35, 0, 0.5 - ROW_Z) } -- sur pieds dépasse de 13,3 d'un côté
	for _, t in STALLS do t.pos = RP[t.tag]; t.face = Vector3.new(0, 0, -math.sign(t.pos.Z)) end
end
local function stall(parent, t)
	local cf = frameAt(t.pos, t.face or Vector3.new(-1, 0, 0)) -- comptoir vers l'ouest (la place) ou vers l'allée
	local m = Instance.new("Model"); m.Name = t.name
	local function B(name, x0, y0, z0, x1, y1, z1, color, opt) return Bx(m, cf, name, x0, y0, z0, x1, y1, z1, color, opt) end
	local function beam(name, a, b, w, h, color, opt)
		local c = (a + b) / 2
		return P(m, name, cf * CFrame.lookAt(c, b), Vector3.new(w, h, (b - a).Magnitude), color, opt)
	end
	local MO = { studs = true }
	-- plancher, comptoir (plateau Counter = PrimaryPart), côtés fermés jusqu'au comptoir
	B("Deck", -8.8, 0, -4.6, 8.8, 0.5, 5.6, WOOD_D, MO)
	B("InnerFloor", -7.7, 0.5, -2.4, 7.7, 1.2, 4.6, WOOD_M, MO)
	B("CounterFront", -8.2, 0.5, -4.3, 8.2, 3.7, -2.4, WOOD_L, MO)
	B("CounterKick", -8.25, 0.5, -4.4, 8.25, 1.1, -2.4, WOOD_D, MO)
	local counter = B("Counter", -8.7, 3.7, -4.8, 8.7, 4.2, -2.0, WOOD_D, MO)
	B("CounterCloth", -5.6, 4.2, -4.85, 5.6, 4.28, -2.4, t.cloth, { decor = true })
	B("CounterClothDrape", -5.6, 2.5, -4.93, 5.6, 4.28, -4.83, t.cloth, { decor = true })
	for _, s in { -1, 1 } do
		local side = (s < 0) and "L" or "R"
		local xa, xb = (s < 0) and -8.6 or 7.7, (s < 0) and -7.7 or 8.6
		B("CounterSide_" .. side, xa, 0.5, -2.4, xb, 3.7, 4.6, WOOD_L, MO)
		B("PostFront_" .. side, xa, 4.2, -4.0, xb, 10.6, -3.1, WOOD_D, MO)
		B("PostBack_" .. side, xa, 0.5, 4.6, xb, 13.4, 5.5, WOOD_D, MO)
		local x = s * 8.15
		beam("SideRail_" .. side, Vector3.new(x, 7.9, -3.1), Vector3.new(x, 7.9, 4.6), 0.7, 0.5, WOOD_D, MO)
		beam("TopBeam_" .. side, Vector3.new(x, 10.9, -3.55), Vector3.new(x, 12.9, 5.05), 0.8, 0.5, WOOD_D, MO)
		beam("Brace_" .. side, Vector3.new(x, 7.2, -3.55), Vector3.new(x, 10.0, -5.6), 0.45, 0.45, WOOD_D, { decor = true })
	end
	-- mur du fond : panneau bas, planches ajourées
	B("BackPanel", -7.7, 1.2, 4.75, 7.7, 4.0, 5.35, WOOD_M, MO)
	for i = 0, 4 do
		local y = 4.4 + i * 1.75
		B("BackSlat_" .. (i + 1), -7.7, y, 4.8, 7.7, y + 1.15, 5.3, WOOD_M, MO)
	end
	-- store rayé en pente, lambrequin à dents
	local n, x0, x1 = 8, -9.6, 9.6
	local w = (x1 - x0) / n
	for i = 0, n - 1 do
		local xc = x0 + (i + 0.5) * w
		local col = t.stripes[i % 2 + 1]
		beam("Awning_" .. (i + 1), Vector3.new(xc, 13.5, 5.9), Vector3.new(xc, 10.5, -6.3), w + 0.02, 0.3, col, { decor = true })
		B("Valance_" .. (i + 1), xc - w / 2, 9.75, -6.55, xc + w / 2, 10.55, -6.25, col, { decor = true })
		B("ValanceTooth_" .. (i + 1), xc - w / 4, 9.3, -6.55, xc + w / 4, 9.75, -6.25, col, { decor = true })
	end
	-- enseigne au-dessus du store, deux faces
	local sign = B("SignBoard", -6.8, 13.4, 5.15, 6.8, 17.0, 5.75, t.signBg, MO)
	B("SignTrim_Bottom", -7.1, 13.1, 5.05, 7.1, 13.45, 5.85, t.trim, { decor = true })
	B("SignTrim_Top", -7.1, 16.95, 5.05, 7.1, 17.3, 5.85, t.trim, { decor = true })
	for _, face in { FRONT, BACK } do
		txt(surface(sign, face, 24), t.title, t.titleColor, 0.04, 0.1, 0.92, 0.8, { font = LUCKY, strokeT = 3 })
	end
	-- lanterne sous le store (allumée la nuit par le code)
	B("LanternChain", -0.08, 9.7, -4.6, 0.08, 11.2, -4.44, DARK, { decor = true })
	nightLight(B("Lantern", -0.55, 8.5, -5.05, 0.55, 9.7, -3.95, LAMP_OFF, { decor = true }), 22, 1.2)
	B("LanternCap", -0.7, 9.7, -5.2, 0.7, 9.95, -3.8, DARK, { decor = true })
	-- zone d'ouverture ShopPad (nom proposé, à valider par Ironix) : plaque au sol sous l'avant du stand et devant, contour
	-- néon à la couleur du stand ; sans collision, touchable et interrogeable : le code ouvrira l'écran du stand quand un
	-- joueur marche dessus ; aucun script
	local pad = B("ShopPad", -8.5, 0.02, -11.5, 8.5, 0.22, -2.0, t.stripes[1], { T = 0.55, noShadow = true })
	pad.CanCollide = false
	pad.CanTouch = true
	pad.CanQuery = true
	for i, e in { { -8.5, -11.5, 8.5, -11.0 }, { -8.5, -2.5, 8.5, -2.0 }, { -8.5, -11.0, -8.0, -2.5 }, { 8.0, -11.0, 8.5, -2.5 } } do
		Bx(pad, cf, "PadEdge_" .. i, e[1], 0.02, e[2], e[3], 0.28, e[4], t.stripes[1], { decor = true, mat = NEON, noShadow = true })
	end
	-- panneau sur pieds, à gauche du stand
	B("StandSignLeg_1", -12.9, 0, -4.0, -12.6, 3.4, -3.7, WOOD_D, { decor = true })
	B("StandSignLeg_2", -10.4, 0, -4.0, -10.1, 3.4, -3.7, WOOD_D, { decor = true })
	local board = B("StandSign", -13.3, 1.7, -4.2, -9.7, 4.1, -3.9, WOOD_M, MO)
	txt(surface(board, FRONT, 40), t.tagline, rgb(255, 246, 230), 0.05, 0.12, 0.9, 0.76, { strokeT = 2, strokeC = rgb(60, 40, 28) })
	goods(m, cf, t)
	local v, err = vendor(t.vendor, cf)
	if v then v.Parent = m else add("Vendeur " .. t.vendor.name .. " : " .. tostring(err)) end
	m.WorldPivot = cf
	-- avec une PrimaryPart, le pivot du modèle est celui du comptoir : son PivotOffset le ramène au repère du stand,
	-- au sol (sans lui, un PivotTo(cf) enterrait le stand de 3,95 et le reculait de 3,4 : corrigé le 2026-11-08)
	if counter.Parent then m.PrimaryPart = counter; counter.PivotOffset = counter.CFrame:Inverse() * cf end
	CS:AddTag(m, t.tag)
	m.Parent = parent
	return m
end
do
	local m = section("Stalls")
	for _, t in STALLS do stall(m, t) end
	-- un lampadaire devant chaque paire de stands, entre les deux (armes et Robux au nord, auras et receleur au sud)
	for _, s in { 1, -1 } do lamp(m, "Lamp_Stalls_" .. (s > 0 and "N" or "S"), ROWS and Vector3.new(-22, 0, (ROW_Z - 10) * s) or Vector3.new(1.5, 0, (71 + EXIT_W) * s)) end -- x 1,5 : à côté de l'allée des stands (x ≤ 0)
	-- une allée de l'allée de la boutique 1 (nord) ou 6 (sud) jusqu'à la plaque ShopPad de chaque stand (x = 0,5),
	-- sous le niveau de l'allée (0,08 contre 0,12) là où elle la rejoint (demi-cercle seulement : en 3 face à 3, le parvis)
	for _, t in ((ROWS or LINE) and {} or STALLS) do
		local k = t.pos.Z > 0 and 1 or 6
		local d = (SITES[k].front - S).Unit
		local from = S + d * ((t.pos.Z - S.Z) / d.Z)
		local to = Vector3.new(t.pos.X - 11.55, 0, t.pos.Z)
		local n = (t.name:gsub("^ENV_Hub_", ""))
		strip(m, "Walkway_" .. n, from, to, 10, 0.08, PAVE, F)
		for _, s in { 1, -1 } do
			local o = Vector3.new(0, 0, 5.6 * s)
			strip(m, "WalkwayEdge_" .. n .. (s > 0 and "L" or "R"), from + o, to + o, 1.2, 0.06, BRICK, F)
		end
	end
	done(m)
end

-- Mur est contre la zone 1, blocs au bout de l'arc, piliers au bout du mur de nuit, mâts à la sortie ------------------
do
	local m = section("Walls")
	local WO = { studs = true }
	-- mur est contre la zone 1, du bout du mur de nuit jusqu'à la façade (les deux bouts de l'arc ferment le nord et le sud) ;
	-- sans le centre commercial, jusqu'au bord du hub, où la bordure le rejoint
	local zs = { 34.5, 74, 114, 154, 194, 234 }
	if LINE then zs = {} end -- le grand mur prend sa place
	if not MALL and not LINE then
		local cut = {}
		for _, z in zs do if z < HUB.z1 - 10 then table.insert(cut, z) end end
		table.insert(cut, HUB.z1)
		zs = cut -- 3 face à 3 (|z| <= 156) : 34,5, 74, 114, 156
	end
	for i = 1, #zs - 1 do
		for _, s in { 1, -1 } do
			local tag = (s > 0 and "N" or "S") .. i
			local z0, z1 = math.min(zs[i] * s, zs[i + 1] * s), math.max(zs[i] * s, zs[i + 1] * s)
			Bx(m, W, "Wall_E" .. tag, 27.5, 0, z0, 30, WALL_H, z1, STONE, WO)
			Bx(m, W, "Wall_E" .. tag .. "_Cap", 26.9, WALL_H, z0, 30, WALL_H + 1.2, z1, BRICK, WO)
			local zp = (s > 0) and z0 or (z1 - 2.4)
			Bx(m, W, "Wall_E" .. tag .. "_Pilaster", 26.9, 0, zp, 27.5, WALL_H + 1.2, zp + 2.4, BRICK, WO)
		end
	end
	-- sans le centre commercial : bordure basse (haie) au bord ouest, nord et sud du hub, et mur invisible au-dessus pour
	-- qu'on ne saute pas dehors
	if LINE then
		-- grand mur en damier (cases de 16, deux tons de brique) et faîte vert, tout autour du hub sauf l'entrée (|z| < 34,5)
		local WALL_A, WALL_B = rgb(206, 140, 116), rgb(184, 116, 94)
		local function bigWall(name, x0, z0, x1, z1)
			local alongX = (x1 - x0) > (z1 - z0)
			local L = alongX and (x1 - x0) or (z1 - z0)
			local n = math.max(1, math.round(L / 16))
			for i = 0, n - 1 do
				local a0, a1 = L * i / n, L * (i + 1) / n
				for j = 0, BIG_H / 16 - 1 do
					local c = ((i + j) % 2 == 0) and WALL_A or WALL_B
					if alongX then Bx(m, W, name .. "_" .. (i + 1) .. "_" .. (j + 1), x0 + a0, j * 16, z0, x0 + a1, (j + 1) * 16, z1, c, WO)
					else Bx(m, W, name .. "_" .. (i + 1) .. "_" .. (j + 1), x0, j * 16, z0 + a0, x1, (j + 1) * 16, z0 + a1, c, WO) end
				end
			end
			Bx(m, W, name .. "_Cap", x0, BIG_H, z0, x1, BIG_H + 1.2, z1, LEAF_L, WO)
		end
		bigWall("BigWall_W", HUB.x0, HUB.z0, HUB.x0 + 3, HUB.z1)
		bigWall("BigWall_N", HUB.x0 + 3, HUB.z1 - 3, 27.5, HUB.z1)
		bigWall("BigWall_S", HUB.x0 + 3, HUB.z0, 27.5, HUB.z0 + 3)
		bigWall("BigWall_EN", 27.5, EXIT_HALF, 30, HUB.z1)
		bigWall("BigWall_ES", 27.5, HUB.z0, 30, -EXIT_HALF)
	end
	if not MALL and not LINE then
		local B_H, INV_H = 4, 60
		local sides = {
			{ "W", HUB.x0, HUB.z0, HUB.x0 + 3, HUB.z1 },
			{ "N", HUB.x0 + 3, HUB.z1 - 3, 27.5, HUB.z1 },
			{ "S", HUB.x0 + 3, HUB.z0, 27.5, HUB.z0 + 3 },
		}
		for _, sd in sides do
			Bx(m, W, "Border_" .. sd[1], sd[2], 0, sd[3], sd[4], B_H, sd[5], HEDGE, WO)
			Bx(m, W, "Border_" .. sd[1] .. "_Top", sd[2], B_H, sd[3], sd[4], B_H + 0.6, sd[5], LEAF_L, { studs = true, noShadow = true })
			Bx(m, W, "Boundary_" .. sd[1], sd[2], B_H + 0.6, sd[3], sd[4], INV_H, sd[5], WHITE, { T = 1, noShadow = true })
		end
	end
	-- au bout de l'arc : bloc qui ferme l'écart entre la dernière boutique et le mur est (seulement avec le centre commercial)
	for _, k in (MALL and { 1, 6 } or {}) do
		local site = SITES[k]
		local sg = math.sign(site.angle)
		local corner = site.front + rr(site.angle + 90) * sg * 32.4 -- coin avant extérieur de la boutique
		local tag = sg > 0 and "N" or "S"
		local x0 = corner.X + 0.8
		if x0 < 27.5 then
			local za, zb = corner.Z - 2.5 * sg, corner.Z + 13 * sg -- 2,5 devant le coin : la terrasse passe à côté
			local z0, z1 = math.min(za, zb), math.max(za, zb)
			Bx(m, W, "EndBlock_" .. tag, x0, 0, z0, 27.5, 34, z1, CREAM, WO)
			Bx(m, W, "EndBlock_" .. tag .. "_Cap", x0 - 0.2, 34, z0, 27.5, 35.6, z1, BRICK, WO)
			local xm = (x0 + 27.5) / 2
			wallLantern(m, CFrame.lookAt(Vector3.new(xm, 0, za), Vector3.new(xm, 0, za - sg)), "EndBlock_" .. tag .. "_Lantern", 0, 14)
		end
	end
	-- piliers au bout du mur de nuit (ses montants butent dessus à |z| = EXIT_HALF), lanterne au sommet
	for _, s in { 1, -1 } do
		local tag = s > 0 and "N" or "S"
		local z0, z1 = math.min(EXIT_HALF * s, (EXIT_HALF + 4) * s), math.max(EXIT_HALF * s, (EXIT_HALF + 4) * s)
		Bx(m, W, "GatePost_" .. tag, 18, 0, z0, 27.5, 22, z1, STONE, WO)
		Bx(m, W, "GatePost_" .. tag .. "_Cap", 17.4, 22, s > 0 and EXIT_HALF or -(EXIT_HALF + 4.6), 27.5, 23.4, s > 0 and (EXIT_HALF + 4.6) or -EXIT_HALF, BRICK, WO)
		local lf = CFrame.new(22.75, 23.4, (EXIT_HALF + 2) * s)
		Bx(m, lf, "GatePost_" .. tag .. "_LampBase", -1, 0, -1, 1, 1, 1, DARK, { decor = true })
		nightLight(Bx(m, lf, "GatePost_" .. tag .. "_Lamp", -1.1, 1, -1.1, 1.1, 3.8, 1.1, LAMP_OFF, { decor = true }), 34, 1.6)
		Bx(m, lf, "GatePost_" .. tag .. "_LampCap", -1.4, 3.8, -1.4, 1.4, 4.3, 1.4, DARK, { decor = true })
		-- mât à drapeau sur le trottoir de sortie
		local base = CFrame.new(14, 0.45, (29 + EXIT_W) * s)
		Vc(m, base, "Flagpole_" .. tag, 0, 0, 40, 0, 0.8, STEEL_L, {})
		Ball(m, base, "Flagpole_" .. tag .. "_Top", 0, 40.4, 0, 1.2, GOLD_L, { decor = true })
		Bx(m, base, "Flag_" .. tag, -9.4, 33, -0.12, -0.4, 39, 0.12, s > 0 and NAVY or RED, { decor = true })
		Bx(m, base, "Flag_" .. tag .. "_Stripe", -9.4, 35.5, -0.14, -0.4, 36.5, 0.14, GOLD_L, { decor = true })
		lamp(m, "Lamp_Exit_" .. tag, Vector3.new(3, 0.45, (31.5 + EXIT_W) * s))
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
		add("Boutiques posées par plot_shop_builder (niveau 1) : " .. SHOP_COUNT .. ", dans Map/Hub/Shops")
	else
		add("Boutiques : constructeur pas chargé (tools/clement/hub/plot_shop_builder.luau) ; celles déjà posées restent")
	end
	local n = 0
	for _, m in shops:GetChildren() do if m:IsA("Model") and CS:HasTag(m, "PlayerPlot") then n += 1 end end
	shopsReady = (n == SHOP_COUNT)
end

-- Aperçus des panneaux d'amélioration posés en Edit (Workspace/_PREVIEW_UpgradeSigns/PLOT_Shop_0k : Preview_Treadmill,
-- Preview_Bench, Preview_ShopUpgrade, Preview_ShopUpgrade_Niveau2a5) : recollés à leur boutique par leur attribut ShopOffset
-- (CFrame dans le repère de la boutique, posé le 2026-11-12) ; une boutique sans aperçus reçoit une copie de ceux d'une
-- autre (Clément, 2026-11-12 : « les panneaux d'amélioration doivent suivre les boutiques »). En jeu, UpgradeController
-- pose les vrais panneaux sur les points de la boutique, qui la suivent déjà.
do
	local pv = workspace:FindFirstChild("_PREVIEW_UpgradeSigns")
	local shops = hub:FindFirstChild("Shops")
	if pv and shops then
		local model
		for _, f in pv:GetChildren() do if f:IsA("Folder") and #f:GetChildren() > 0 then model = model or f end end
		local moved = 0
		for k = 1, SHOP_COUNT do
			local name = string.format("PLOT_Shop_%02d", k)
			local shop, f = shops:FindFirstChild(name), pv:FindFirstChild(name)
			if shop and not f and model then f = model:Clone(); f.Name = name; f.Parent = pv end
			if shop and f then
				for _, prev in f:GetChildren() do
					local off = prev:IsA("Model") and prev:GetAttribute("ShopOffset")
					if typeof(off) == "CFrame" then prev:PivotTo(shop:GetPivot() * off); moved += 1 end
				end
			end
		end
		add("Aperçus des panneaux recollés à leur boutique : " .. moved)
	end
end

-- SafeZone (un seul volume, tout le hub, jusqu'au mur de nuit) et SpawnLocation de secours. PlotService pose chaque
-- joueur sur le SpawnPoint de sa boutique à chaque apparition : ce spawn ne sert que si un joueur n'a pas de boutique.
-- Il est invisible, à ras du dallage, sur l'allée de la sortie, tourné vers la fontaine (Clément, 2026-11-08 : plus de
-- plaque jaune qui ne veut rien dire).
do
	local sz = P(hub, "SafeZone", CFrame.new((HUB.x0 + 24) / 2, 75, 0), Vector3.new(24 - HUB.x0, 170, HUB.z1 - HUB.z0), rgb(255, 120, 200),
		{ T = 1, decor = true, noShadow = true, anywhere = true })
	CS:AddTag(sz, "SafeZone")
	local sp = Instance.new("SpawnLocation")
	sp.Name = "Spawn"; sp.Size = Vector3.new(8, 0.2, 8); sp.Anchored = true
	local c = E + rr(0) * 37 + Vector3.new(0, 0.22, 0) -- (-7, 0, 0), posé sur la dalle de l'avenue (0,12), dessus à 0,32
	sp.CFrame = CFrame.lookAt(c, c + rr(0)) -- face à la fontaine et au centre commercial
	sp.Transparency = 1; sp.CastShadow = false
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
do -- contrat 10.4 des boutiques (vérification du constructeur), PlotIndex de 1 à SHOP_COUNT
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
	for _, t in STALLS do
		local inst = hub.Stalls:FindFirstChild(t.name)
		local cp = inst and inst.PrimaryPart
		if cp then table.insert(res, walk(t.tag, Vector3.new(cp.Position.X, 1, cp.Position.Z) + inst:GetPivot().LookVector * 5)) end
	end
	table.insert(res, walk("zone 1", Vector3.new(50, 1, 0)))
	add("Chemins à pied depuis le spawn (studs) : " .. table.concat(res, " ; "))
end

return table.concat(report, "\n")
