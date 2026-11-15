--!nocheck
-- Ambiance « version ville » du hub (demandes de Clément, 2026-11-14 et 15 ; références :
-- StealAShop-Art/References/2026-11-14_Style_Ciel_Couleurs). Ce qu'il en garde : les couleurs vives et la profondeur au
-- loin ; pas leur campagne : on est dans un centre commercial. Le ciel et Lighting sont à la session lumière.
--  1) Workspace/Map/Skyline : une ville en vrais volumes (socle, tour en retrait, couronne, étage du haut, réservoirs),
--     larges et pas trop hautes (jamais plus de 2,4 fois leur côté : plus de « bâtons »), fenêtres en grille lisibles de
--     loin (bandeaux et trumeaux) sur la face tournée vers le hub, couleurs accordées au ciel S1. Trois plans, le plus
--     proche à 140 des murs (rien de proche qui gêne), de plus en plus loin : la brume de l'Atmosphere les fond. Un sol de
--     ville sous elles (plus de mer du ciel), un dirigeable et un panneau géant sans texte. Hors du hub, du couloir des
--     zones et de la vitrine de Clément ; les tours restent sous les bancs d'essai en l'air. ModelStreamingMode
--     Persistent : la ville reste visible de loin même avec le streaming.
--  2) Sol du hub : dallage de galerie marchande en 2 tons (cases de 8), partout.
--  Plus de mobilier (Clément, 2026-11-15 : « trop d'info tue l'info ») : ni lampadaires, ni bancs, ni fanions, ni
--  jardinières ; le hub garde ses boutiques, ses stands, ses zones et son sol.
-- Tout le décor ajouté est sans collision (ni toucher ni requête). Aucun script, aucun tag ni attribut du contrat.
-- À lancer dans Studio (MCP execute_luau, Edit) après hub_place_du_mall.luau, qui refait le sol. Relançable.

local CS = game:GetService("CollectionService")
local PFS = game:GetService("PathfindingService")
local rgb = Color3.fromRGB
local out = {}
local function add(s) table.insert(out, s) end

local map = workspace:FindFirstChild("Map")
local hub = map and map:FindFirstChild("Hub")
assert(hub, "Workspace/Map/Hub introuvable")
local NIGHT_LIGHT = "NightLight"
local CYL, BALL = Enum.PartType.Cylinder, Enum.PartType.Ball
local SMOOTH = Enum.Material.SmoothPlastic
local ROT_UP = CFrame.Angles(0, 0, math.rad(90)) -- axe du cylindre à la verticale

-- Pièces -----------------------------------------------------------------------------------------------------------
-- opt : studs, shape, decor (ni collision, ni toucher, ni requête) ; aucune ombre portée
local nParts = 0
local function P(parent, name, cf, size, color, opt)
	opt = opt or {}
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color; p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	if opt.shape then p.Shape = opt.shape end
	if opt.studs then p.Material = Enum.Material.Plastic; p.MaterialVariant = "Studs" else p.Material = SMOOTH end
	if opt.decor then p.CanCollide = false; p.CanTouch = false; p.CanQuery = false end
	p.CastShadow = false
	p.Parent = parent
	nParts += 1
	return p
end
local function Bx(parent, name, x0, y0, z0, x1, y1, z1, color, opt)
	return P(parent, name, CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
		Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0)), color, opt)
end
local function Fx(parent, f, name, x0, y0, z0, x1, y1, z1, color, opt)
	return P(parent, name, f * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
		Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0)), color, opt)
end
local function shade(c, k) return Color3.new(c.R * k, c.G * k, c.B * k) end
local function tint(c, k) return c:Lerp(Color3.new(1, 1, 1), k) end
-- Triangle plein dans le plan (X, Y) du repère f (sommets en Vector2), épaisseur le long de Z : deux WedgeParts
local function tri(parent, f, name, a, b, c, thick, color)
	local A = f:PointToWorldSpace(Vector3.new(a.X, a.Y, 0))
	local B = f:PointToWorldSpace(Vector3.new(b.X, b.Y, 0))
	local C = f:PointToWorldSpace(Vector3.new(c.X, c.Y, 0))
	local bc = C - B
	local M = B + bc * ((A - B):Dot(bc) / bc:Dot(bc))
	for i, E in { B, C } do
		local s, h = (E - M).Magnitude, (A - M).Magnitude
		if s > 0.01 and h > 0.01 then
			local zAx, yAx = (M - A).Unit, (E - M).Unit
			local w = Instance.new("WedgePart")
			w.Name = name .. "_" .. i; w.Size = Vector3.new(thick, s, h); w.Color = color; w.Anchored = true
			w.CFrame = CFrame.fromMatrix((A + E) / 2, yAx:Cross(zAx), yAx, zAx)
			w.Material = SMOOTH; w.CastShadow = false
			w.CanCollide = false; w.CanTouch = false; w.CanQuery = false
			w.Parent = parent
			nParts += 1
		end
	end
end
local function night(part) CS:AddTag(part, NIGHT_LIGHT) end -- néon la nuit (SkyController)

-- 0) Nettoyage (relance) ------------------------------------------------------------------------------------------------
for _, n in { "Skyline" } do local o = map:FindFirstChild(n); if o then o:Destroy() end end
for _, n in { "Ambiance" } do local o = hub:FindFirstChild(n); if o then o:Destroy() end end

-- Bornes du hub, lues sur son sol (Ground_Plaza) : la ville et ses plaques suivent le hub quand il change de taille
local HX0, HZ1
do
	local g = hub:FindFirstChild("Ground")
	for _, p in (g and g:GetChildren() or {}) do
		if p:IsA("BasePart") and p.Name:match("^Ground_Plaza") then
			HX0 = math.min(HX0 or math.huge, p.Position.X - p.Size.X / 2)
			HZ1 = math.max(HZ1 or -math.huge, p.Position.Z + p.Size.Z / 2)
		end
	end
	HX0, HZ1 = HX0 or -181, HZ1 or 310
end
add(string.format("hub : x %.0f..30, |z| <= %.0f", HX0, HZ1))

-- 1) Ville au loin ----------------------------------------------------------------------------------------------------
local rng = Random.new(1511)
local sky = Instance.new("Model"); sky.Name = "Skyline"
sky.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
-- là où rien de la ville ne se pose (x0, z0, x1, z1) : le hub, le couloir des zones, la vitrine de Clément
local AVOID = {
	{ HX0 - 2, -HZ1 - 2, 32, HZ1 + 2 }, -- le hub
	{ 15, -312, 965, 312 }, -- couloir et zones (|z| <= 300)
	{ -218, 342, 298, 1138 }, -- _SHOWROOM_CLEMENT (x -200..281, z 345..1117)
}
-- objets d'essai en l'air (x0, z0, x1, z1, bas) : les tours restent 12 en dessous
local SKY_PROPS = {
	{ -372, 528, 72, 792, 295 }, -- _BENCH_AURAS_STAGE
	{ -262, 458, -118, 522, 299 }, -- _PROTO_AURA_FEU, _PROTO_AURA_ECLAIR
	{ -1240, 975, -1055, 2065, 596 }, -- _BENCH_PACKS_CLEMENT, _PROTO_AURAS_6, _PROTO_TRAILS
}
local function hitRect(x0, z0, x1, z1, r) return x0 < r[3] and x1 > r[1] and z0 < r[4] and z1 > r[2] end
local function blocked(x0, z0, x1, z1)
	for _, r in AVOID do if hitRect(x0, z0, x1, z1, r) then return true end end
	return false
end
local function heightCap(x0, z0, x1, z1)
	local cap = math.huge
	for _, r in SKY_PROPS do if hitRect(x0, z0, x1, z1, r) then cap = math.min(cap, r[5] - 12) end end
	return cap
end
-- couleurs accordées au ciel S1 (bleu franc, nuages blancs) : crème, pêche, corail, bleu ciel, lavande, menthe, sable,
-- blanc ; au loin, bleu-gris de brume. Fenêtres bleu moyen, bien lisibles sur les façades claires (néon la nuit)
local PAL = { rgb(246, 238, 222), rgb(250, 208, 182), rgb(238, 150, 128), rgb(150, 200, 242), rgb(186, 176, 236),
	rgb(158, 214, 196), rgb(232, 212, 168), rgb(250, 250, 248) }
local PAL_FAR = { rgb(182, 202, 234), rgb(200, 214, 242), rgb(170, 192, 228), rgb(214, 224, 246), rgb(190, 206, 238) }
local WIN = rgb(110, 150, 210)
-- d : distance aux murs du hub (de .. à) ; h, w, dd : hauteur, largeur, profondeur ; floor, band, pil : grille des
-- fenêtres (hauteur d'étage, hauteur du bandeau vitré, pas des trumeaux) ; rows : rangs (fenêtres au premier seulement)
local PLANES = {
	{ name = "Near", d = { 140, 260 }, h = { 50, 120 }, w = { 50, 100 }, dd = { 40, 70 }, gap = { 10, 30 }, rows = 1,
		floor = 10, band = 5, pil = 12, pal = PAL, k = 0, studs = true },
	{ name = "Mid", d = { 450, 750 }, h = { 90, 200 }, w = { 70, 140 }, dd = { 60, 110 }, gap = { 15, 45 }, rows = 2,
		floor = 20, band = 9, pil = 28, pal = PAL, k = 0.2 },
	{ name = "Far", d = { 1000, 1500 }, h = { 140, 260 }, w = { 100, 200 }, dd = { 80, 150 }, gap = { 25, 70 }, rows = 2,
		pal = PAL_FAR, k = 0 },
}
local function rr(a) return rng:NextNumber(a[1], a[2]) end
local nBuildings, nClash = 0, 0
local westNear = {}
local opSky = OverlapParams.new(); opSky.FilterType = Enum.RaycastFilterType.Exclude; opSky.FilterDescendantsInstances = { sky }
-- pièce plaquée sur une face : f = { nx, nz, plane } (normale ±X ou ±Z, plan de la face), u le long de la face
local function facePart(m, name, f, u0, u1, y0, y1, d, color)
	local c, size
	if f.nx ~= 0 then
		c = Vector3.new(f.plane + f.nx * d / 2, (y0 + y1) / 2, (u0 + u1) / 2); size = Vector3.new(d, y1 - y0, u1 - u0)
	else
		c = Vector3.new((u0 + u1) / 2, (y0 + y1) / 2, f.plane + f.nz * d / 2); size = Vector3.new(u1 - u0, y1 - y0, d)
	end
	return P(m, name, CFrame.new(c), size, color, { decor = true })
end
-- grille de fenêtres sur une face, de u0 à u1 et de y0 à y1
local function windowGrid(m, f, u0, u1, y0, y1, pl, col)
	local y = y0
	while y + pl.band <= y1 do
		night(facePart(m, "Windows", f, u0 + 1.5, u1 - 1.5, y, y + pl.band, 0.3, WIN))
		y += pl.floor
	end
	local n = math.max(2, math.floor((u1 - u0) / pl.pil))
	for i = 1, n - 1 do
		local u = u0 + i * (u1 - u0) / n
		facePart(m, "Pier", f, u - 1, u + 1, y0 - 1, math.min(y, y1), 0.6, shade(col, 0.94))
	end
end
local function building(parent, pl, x0, z0, x1, z1, face, idx, front)
	local W, D = x1 - x0, z1 - z0
	local H = math.min(rr(pl.h), heightCap(x0, z0, x1, z1), 2.4 * math.min(W, D))
	if H < 30 then return end
	-- rien d'autre à cet endroit (décor d'une zone, objet d'essai) : immeuble sauté
	if #workspace:GetPartBoundsInBox(CFrame.new((x0 + x1) / 2, H / 2 + 4, (z0 + z1) / 2), Vector3.new(W + 2, H + 40, D + 2), opSky) > 0 then
		nClash += 1; return
	end
	local base = pl.pal[rng:NextInteger(1, #pl.pal)]
	local col = pl.k > 0 and tint(base, pl.k) or base
	local m = Instance.new("Model"); m.Name = "Building_" .. idx
	local O = { decor = true, studs = pl.studs }
	-- socle sur toute l'emprise, corniche claire
	local hp = H * rng:NextNumber(0.28, 0.45)
	Bx(m, "Podium", x0, -0.6, z0, x1, hp, z1, col, O)
	Bx(m, "PodiumCornice", x0 - 0.6, hp, z0 - 0.6, x1 + 0.6, hp + 1.4, z1 + 0.6, tint(col, 0.45), O)
	-- tour en retrait, poussée vers la face tournée vers le hub (on la voit)
	local tw, td = W * rng:NextNumber(0.55, 0.85), D * rng:NextNumber(0.55, 0.85)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	if face.X ~= 0 then cx += face.X * (W - tw) / 2 * rng:NextNumber(0.3, 1) end
	if face.Z ~= 0 then cz += face.Z * (D - td) / 2 * rng:NextNumber(0.3, 1) end
	local tx0, tx1, tz0, tz1 = cx - tw / 2, cx + tw / 2, cz - td / 2, cz + td / 2
	local y0 = hp + 1.4
	local tcol = (rng:NextNumber() < 0.35) and tint(pl.pal[rng:NextInteger(1, #pl.pal)], pl.k) or col
	Bx(m, "Tower", tx0, y0 - 0.2, tz0, tx1, H, tz1, tcol, O)
	Bx(m, "Crown", tx0 - 0.6, H, tz0 - 0.6, tx1 + 0.6, H + 2, tz1 + 0.6, shade(tcol, 0.8), O)
	local top = H + 2
	-- étage du haut (en retrait) ou réservoir d'eau sur le toit
	local r = rng:NextNumber()
	if r < 0.4 then
		local sw, sd = tw * 0.5, td * 0.5
		local sh = math.max(6, H * 0.1)
		Bx(m, "TopFloor", cx - sw / 2, top, cz - sd / 2, cx + sw / 2, top + sh, cz + sd / 2, tint(tcol, 0.2), O)
		Bx(m, "TopCap", cx - sw / 2 - 0.4, top + sh, cz - sd / 2 - 0.4, cx + sw / 2 + 0.4, top + sh + 1.2, cz + sd / 2 + 0.4, shade(tcol, 0.8), O)
	elseif r < 0.7 then
		local tank = math.clamp(tw * 0.18, 5, 12)
		local tx, tz = cx + (rng:NextNumber() - 0.5) * tw * 0.4, cz + (rng:NextNumber() - 0.5) * td * 0.4
		P(m, "WaterTank", CFrame.new(tx, top + 1.5 + tank * 0.5, tz) * ROT_UP, Vector3.new(tank, tank, tank), rgb(168, 120, 92), { decor = true, shape = CYL })
		Bx(m, "WaterTankStand", tx - tank * 0.35, top, tz - tank * 0.35, tx + tank * 0.35, top + 1.5, tz + tank * 0.35, rgb(90, 96, 110), O)
	end
	-- fenêtres en grille sur la face tournée vers le hub (rang de devant des deux premiers plans)
	if pl.floor and front then
		local ft, fp, tu0, tu1, pu0, pu1
		if face.X ~= 0 then
			ft = { nx = face.X, nz = 0, plane = (face.X > 0) and tx1 or tx0 }
			fp = { nx = face.X, nz = 0, plane = (face.X > 0) and x1 or x0 }
			tu0, tu1, pu0, pu1 = tz0, tz1, z0, z1
		else
			ft = { nx = 0, nz = face.Z, plane = (face.Z > 0) and tz1 or tz0 }
			fp = { nx = 0, nz = face.Z, plane = (face.Z > 0) and z1 or z0 }
			tu0, tu1, pu0, pu1 = tx0, tx1, x0, x1
		end
		windowGrid(m, ft, tu0, tu1, y0 + 4, H - 3, pl, tcol)
		if hp > 14 then windowGrid(m, fp, pu0, pu1, 4, hp - 3, pl, col) end
	end
	m.Parent = parent
	nBuildings += 1
	if pl.name == "Near" and face.X > 0 then table.insert(westNear, { m = m, x1 = tx1, z = cz, top = top, w = td }) end
	return m
end
for _, pl in PLANES do
	local pm = Instance.new("Model"); pm.Name = pl.name
	local d0, d1 = pl.d[1], pl.d[2]
	-- ouest (face +X), nord (face -Z), sud (face +Z) ; n0 = bord côté hub
	local strips = {
		{ axis = "z", a0 = -HZ1 - d1, a1 = HZ1 + d1, n0 = HX0 - d0, n1 = HX0 - d1, face = Vector3.new(1, 0, 0) },
		{ axis = "x", a0 = HX0 - d1, a1 = 30 + d1, n0 = HZ1 + d0, n1 = HZ1 + d1, face = Vector3.new(0, 0, -1) },
		{ axis = "x", a0 = HX0 - d1, a1 = 30 + d1, n0 = -HZ1 - d0, n1 = -HZ1 - d1, face = Vector3.new(0, 0, 1) },
	}
	local idx = 0
	for _, st in strips do
		local nlo, nhi = math.min(st.n0, st.n1), math.max(st.n0, st.n1)
		local band = (nhi - nlo) / pl.rows
		for row = 1, pl.rows do
			local r0 = (st.n0 < st.n1) and (nlo + (row - 1) * band) or (nhi - row * band) -- rang 1 côté hub
			local a = st.a0 + rng:NextNumber(0, 20)
			while a < st.a1 do
				local w = rr(pl.w)
				local d = math.min(rr(pl.dd), band)
				local off = rng:NextNumber(0, band - d)
				local a0, a1 = a, math.min(a + w, st.a1)
				local n0, n1
				if st.n0 < st.n1 then n0 = r0 + off; n1 = n0 + d else n1 = r0 + band - off; n0 = n1 - d end
				local x0, z0, x1, z1
				if st.axis == "z" then x0, x1, z0, z1 = n0, n1, a0, a1 else x0, x1, z0, z1 = a0, a1, n0, n1 end
				if a1 - a0 > 30 and not blocked(x0, z0, x1, z1) then
					idx += 1
					building(pm, pl, x0, z0, x1, z1, st.face, idx, row == 1)
				end
				a = a1 + rr(pl.gap)
			end
		end
	end
	pm.Parent = sky
end
-- sol de ville sous les plans (dessus à -0,6, sous le sol du hub ; plus de mer du ciel entre les immeubles) : le carré
-- x -2600..1000, z -2600..2600, moins le hub, le couloir et la vitrine (AVOID), en morceaux de 2 000 au plus
local CITY = rgb(150, 170, 196)
local gm = Instance.new("Model"); gm.Name = "CityGround"
local PLATES = { { -2600, -2600, 1000, 2600 } }
for _, h in AVOID do
	local nxt = {}
	for _, r in PLATES do
		if h[3] <= r[1] or h[1] >= r[3] or h[4] <= r[2] or h[2] >= r[4] then
			table.insert(nxt, r)
		else
			local z0, z1 = math.max(r[2], h[2]), math.min(r[4], h[4])
			if h[2] > r[2] then table.insert(nxt, { r[1], r[2], r[3], h[2] }) end
			if h[4] < r[4] then table.insert(nxt, { r[1], h[4], r[3], r[4] }) end
			if h[1] > r[1] then table.insert(nxt, { r[1], z0, h[1], z1 }) end
			if h[3] < r[3] then table.insert(nxt, { h[3], z0, r[3], z1 }) end
		end
	end
	PLATES = nxt
end
do
	local cut = {}
	for _, r in PLATES do
		local nx, nz = math.ceil((r[3] - r[1]) / 2000), math.ceil((r[4] - r[2]) / 2000)
		for i = 0, nx - 1 do
			for j = 0, nz - 1 do
				local w, d = (r[3] - r[1]) / nx, (r[4] - r[2]) / nz
				table.insert(cut, { r[1] + i * w, r[2] + j * d, r[1] + (i + 1) * w, r[2] + (j + 1) * d })
			end
		end
	end
	PLATES = cut
end
for i, r in PLATES do Bx(gm, "Plate_" .. i, r[1], -4.6, r[2], r[3], -0.6, r[4], CITY, { decor = true }) end
gm.Parent = sky
-- Panneau géant sans texte, sur le toit de l'immeuble le plus haut du premier plan à l'ouest, face au hub : fond bleu
-- ciel, un cadeau rouge, deux pièces d'or, cadre néon rose (allumé la nuit)
do
	table.sort(westNear, function(a, b) return a.top > b.top end)
	local host = westNear[1]
	if host then
		local x, cz = host.x1 - 3, host.z
		local y0 = host.top + 5
		local f = CFrame.lookAt(Vector3.new(x, y0, cz), Vector3.new(x + 1, y0, cz)) -- face avant (-Z local) vers le hub (+X)
		local bm = Instance.new("Model"); bm.Name = "GiantBillboard"
		local D = { decor = true }
		for i, s in { -1, 1 } do Fx(bm, f, "Post_" .. i, 18 * s - 0.8, -5, 0.4, 18 * s + 0.8, 1, 2, rgb(60, 66, 82), D) end
		Fx(bm, f, "Panel", -28, 0, -0.5, 28, 28, 0.5, rgb(70, 180, 250), D)
		Fx(bm, f, "PanelBand", -28, 0, -0.6, 28, 6, -0.5, rgb(40, 140, 225), D)
		Fx(bm, f, "GiftBox", -20, 4, -1.2, -6, 16, -0.5, rgb(225, 45, 45), D)
		Fx(bm, f, "GiftLid", -21, 16, -1.4, -5, 19, -0.5, rgb(190, 30, 34), D)
		Fx(bm, f, "GiftRibbonV", -14.2, 4, -1.5, -11.8, 19, -1.1, rgb(255, 206, 40), D)
		Fx(bm, f, "GiftRibbonH", -20, 9, -1.4, -6, 11, -1.1, rgb(255, 206, 40), D)
		for i, s in { -1, 1 } do
			P(bm, "GiftBow_" .. i, f * CFrame.new(-13 + 2.6 * s, 20.6, -1.3) * CFrame.Angles(0, 0, math.rad(-28 * s)), Vector3.new(4.6, 2, 0.6), rgb(255, 206, 40), D)
		end
		for i, c in { { 9, 15, 13 }, { 20, 9, 8 } } do
			P(bm, "Coin_" .. i, f * CFrame.new(c[1], c[2], -1) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(1, c[3], c[3]), rgb(255, 196, 40), D)
			P(bm, "CoinRim_" .. i, f * CFrame.new(c[1], c[2], -1.3) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(0.6, c[3] * 0.72, c[3] * 0.72), rgb(255, 220, 90), D)
		end
		for i, e in { { -29, -1, 29, 0 }, { -29, 28, 29, 29 }, { -29, 0, -28, 28 }, { 28, 0, 29, 28 } } do
			night(Fx(bm, f, "Frame_" .. i, e[1], e[2], -0.8, e[3], e[4], 0.8, rgb(255, 90, 190), D))
		end
		bm.Parent = sky
		add("panneau géant sur " .. host.m.Name .. string.format(" (x %.0f, z %.0f, bas à %.0f)", x, cz, y0))
	end
end
-- Dirigeable publicitaire au nord-ouest : enveloppe blanche (sphère étirée), bandeau coloré sans texte sur les flancs,
-- nacelle, empennage
do
	local c = Vector3.new(-260, 168, 620)
	local f = CFrame.lookAt(c, c + Vector3.new(1, 0, 0.25))
	local dm = Instance.new("Model"); dm.Name = "Blimp"
	local D = { decor = true }
	local env = P(dm, "Envelope", f, Vector3.new(22, 22, 72), rgb(245, 246, 250), D)
	local mesh = Instance.new("SpecialMesh"); mesh.MeshType = Enum.MeshType.Sphere; mesh.Parent = env
	for i, s in { 1, -1 } do
		local band = P(dm, "Banner_" .. i, f * CFrame.new(10.6 * s, 0, 0) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(34, 9, 0.6), rgb(255, 90, 80), D)
		P(dm, "BannerStripe_" .. i, band.CFrame * CFrame.new(0, 0, 0.35 * s), Vector3.new(34, 2.2, 0.3), rgb(255, 206, 40), D)
		P(dm, "BannerCoin_" .. i, band.CFrame * CFrame.new(-11, 0, 0.5 * s) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(0.5, 6.4, 6.4), rgb(255, 206, 40), D)
	end
	Fx(dm, f, "Gondola", -3, -14.5, -8, 3, -10.5, 6, rgb(60, 66, 82), D)
	Fx(dm, f, "GondolaWindows", -3.1, -13.4, -7, 3.1, -12, 5, rgb(185, 225, 255), D)
	for i, a in { 0, 90, 180, 270 } do
		local fr = f * CFrame.new(0, 0, 30) * CFrame.Angles(0, 0, math.rad(a))
		tri(dm, fr * CFrame.Angles(0, math.rad(90), 0), "Fin_" .. i, Vector2.new(-6, 12.5), Vector2.new(-8, 6), Vector2.new(6, 6), 0.8, rgb(255, 90, 80))
	end
	dm.Parent = sky
end
sky.Parent = map
add("ville : " .. nBuildings .. " immeubles (" .. nClash .. " sautés, place prise), " .. nParts .. " pièces (Map/Skyline), " .. #PLATES .. " plaques")

-- 2) Sol du hub : dallage 2 tons, partout ---------------------------------------------------------------------------
local TILE_A, TILE_B, CELL = rgb(88, 178, 245), rgb(66, 152, 230), 8
local ground = hub:FindFirstChild("Ground")
local grass = {}
for _, n in { "Ground_Plaza", "Ground_Flank_N", "Ground_Flank_S" } do
	local p = ground and ground:FindFirstChild(n)
	if p then
		p.Color = TILE_A
		table.insert(grass, { x0 = p.Position.X - p.Size.X / 2, x1 = p.Position.X + p.Size.X / 2, z0 = p.Position.Z - p.Size.Z / 2, z1 = p.Position.Z + p.Size.Z / 2 })
	end
end
local patches = ground and ground:FindFirstChild("GrassPatches")
if patches then patches:Destroy(); add("taches d'herbe retirées") end
local amb = Instance.new("Model"); amb.Name = "Ambiance"
local tiles = Instance.new("Model"); tiles.Name = "FloorTiles"
local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude
local seeThrough = { ground }
for _, d in hub:GetDescendants() do if d:IsA("BasePart") and d.Transparency > 0.2 then table.insert(seeThrough, d) end end
rp.FilterDescendantsInstances = seeThrough -- zone safe, zones, plaques ShopPad, murs invisibles : le dallage passe dessous
local function covered(x, z)
	local r = workspace:Raycast(Vector3.new(x, 4, z), Vector3.new(0, -4.5, 0), rp)
	return r ~= nil and r.Position.Y > 0.05
end
local nTiles = 0
for _, g in grass do
	for i = math.floor(g.x0 / CELL), math.ceil(g.x1 / CELL) - 1 do
		for j = math.floor(g.z0 / CELL), math.ceil(g.z1 / CELL) - 1 do
			if (i + j) % 2 == 1 then
				local x0, x1 = math.max(i * CELL, g.x0), math.min((i + 1) * CELL, g.x1)
				local z0, z1 = math.max(j * CELL, g.z0), math.min((j + 1) * CELL, g.z1)
				if x1 - x0 > 0.5 and z1 - z0 > 0.5 then
					local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
					local all = covered(cx, cz) and covered(x0 + 0.4, z0 + 0.4) and covered(x1 - 0.4, z0 + 0.4) and covered(x0 + 0.4, z1 - 0.4) and covered(x1 - 0.4, z1 - 0.4)
					if not all then
						Bx(tiles, "Tile", x0, -0.05, z0, x1, 0.03, z1, TILE_B, { decor = true, studs = true })
						nTiles += 1
					end
				end
			end
		end
	end
end
tiles.Parent = amb
amb.Parent = hub
add("dallage : " .. nTiles .. " cases foncées")

-- 3) Vérification : chemins depuis l'apparition jusqu'au devant de chaque boutique et de chaque stand -------------------
local spawn = hub:FindFirstChild("Spawn")
local from = spawn and spawn.Position + Vector3.new(0, 3, 0) or Vector3.new(-37, 3, 0)
local fails, targets = {}, {}
for _, sh in (hub:FindFirstChild("Shops") and hub.Shops:GetChildren() or {}) do
	local door = sh:FindFirstChild("PlotDoor")
	local d = door and door:GetPivot().Position or sh:GetPivot().Position
	table.insert(targets, { sh.Name, Vector3.new(d.X, 0, d.Z) + sh:GetPivot().LookVector * 8 })
end
for _, st in (hub:FindFirstChild("Stalls") and hub.Stalls:GetChildren() or {}) do
	local pad = st:FindFirstChild("ShopPad")
	if pad then table.insert(targets, { st.Name, pad.Position }) end
end
for _, t in targets do
	local path = PFS:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = false })
	local ok = pcall(function() path:ComputeAsync(from, t[2] + Vector3.new(0, 2, 0)) end)
	if not ok or path.Status ~= Enum.PathStatus.Success then table.insert(fails, t[1]) end
end
add("chemins depuis l'apparition : " .. (#targets - #fails) .. "/" .. #targets .. (#fails > 0 and (" (échec : " .. table.concat(fails, ", ") .. ")") or ""))
return table.concat(out, "\n")
