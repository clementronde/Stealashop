--!nocheck
-- Ambiance « version ville » du hub (demande de Clément, 2026-11-14 ; références :
-- StealAShop-Art/References/2026-11-14_Style_Ciel_Couleurs). Ce qu'il en garde : les couleurs vives et la profondeur au
-- loin ; pas leur campagne : on est dans un centre commercial. Le ciel et Lighting sont à la session lumière.
--  1) Workspace/Map/Skyline : silhouettes de ville en blocs, en 3 plans de plus en plus loin (la brume de l'Atmosphere
--     les fond), un sol de ville sous elles (plus de vue sur la mer du ciel), un dirigeable et un panneau géant sans texte.
--     Hors du couloir des zones, de la vitrine de Clément et des bancs d'essai en l'air. ModelStreamingMode Persistent :
--     la ville reste visible de loin même avec le streaming.
--  2) Sol du hub : dallage de galerie marchande en 2 tons (cases de 8) à la place de l'herbe ; taches d'herbe retirées.
--  3) Workspace/Map/Hub/Ambiance : jardinières avec arbres du pack Yasu (mémoire map-trees-pack), lampadaires (NightLight,
--     allumés la nuit par SkyController), bancs et fanions, hors des allées, des 8 boutiques et des zones de L-165.
-- Petit décor sans collision (ni toucher ni requête) ; jardinières solides. Aucun script, aucun tag ni attribut du contrat.
-- À lancer dans Studio (MCP execute_luau, Edit) après hub_place_du_mall.luau, qui refait le sol et les taches. Relançable.

local CS = game:GetService("CollectionService")
local SS = game:GetService("ServerStorage")
local PFS = game:GetService("PathfindingService")
local rgb = Color3.fromRGB
local out = {}
local function add(s) table.insert(out, s) end

local map = workspace:FindFirstChild("Map")
local hub = map and map:FindFirstChild("Hub")
assert(hub, "Workspace/Map/Hub introuvable")
local NIGHT_LIGHT = "NightLight"
local CYL, BALL = Enum.PartType.Cylinder, Enum.PartType.Ball
local NEON, SMOOTH = Enum.Material.Neon, Enum.Material.SmoothPlastic
local ROT_UP = CFrame.Angles(0, 0, math.rad(90)) -- axe du cylindre à la verticale
local LAMP_OFF, WARM = rgb(255, 238, 200), rgb(255, 214, 150)

-- Pièces -----------------------------------------------------------------------------------------------------------
-- opt : studs, mat, shape, T, decor (ni collision, ni toucher, ni requête), shadow (ombre portée ; coupée par défaut)
local nParts = 0
local function P(parent, name, cf, size, color, opt)
	opt = opt or {}
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color; p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	if opt.shape then p.Shape = opt.shape end
	if opt.mat then p.Material = opt.mat
	elseif opt.studs then p.Material = Enum.Material.Plastic; p.MaterialVariant = "Studs"
	else p.Material = SMOOTH end
	if opt.T then p.Transparency = opt.T end
	if opt.decor then p.CanCollide = false; p.CanTouch = false; p.CanQuery = false end
	p.CastShadow = opt.shadow == true
	p.Parent = parent
	nParts += 1
	return p
end
-- pavé du monde donné par deux coins
local function Bx(parent, name, x0, y0, z0, x1, y1, z1, color, opt)
	return P(parent, name, CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
		Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0)), color, opt)
end
-- pavé dans un repère
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
local function night(part, range, bright, color)
	if range then
		local l = Instance.new("PointLight"); l.Range = range; l.Brightness = bright or 1.2; l.Color = color or WARM
		l.Shadows = false; l.Enabled = false; l.Parent = part
	end
	CS:AddTag(part, NIGHT_LIGHT)
end

-- 0) Nettoyage (relance) ------------------------------------------------------------------------------------------------
for _, n in { "Skyline" } do local o = map:FindFirstChild(n); if o then o:Destroy() end end
for _, n in { "Ambiance" } do local o = hub:FindFirstChild(n); if o then o:Destroy() end end

-- Bornes du hub, lues sur son sol (Ground_Plaza : bord ouest ; et bord nord) : la ville et ses plaques suivent le hub
-- quand il change de taille (2026-11-15 : boutiques rapprochées du couloir, hub de x -143 et |z| 290)
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
local rng = Random.new(1411)
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
local function hitRect(x0, z0, x1, z1, r)
	return x0 < r[3] and x1 > r[1] and z0 < r[4] and z1 > r[2]
end
local function blocked(x0, z0, x1, z1)
	for _, r in AVOID do if hitRect(x0, z0, x1, z1, r) then return true end end
	return false
end
local function heightCap(x0, z0, x1, z1)
	local cap = math.huge
	for _, r in SKY_PROPS do if hitRect(x0, z0, x1, z1, r) then cap = math.min(cap, r[5] - 12) end end
	return cap
end
-- couleurs vives (plan 1), adoucies (plan 2), bleu-gris de brume (plan 3)
local VIVID = { rgb(255, 120, 100), rgb(80, 170, 240), rgb(90, 210, 160), rgb(255, 200, 70), rgb(170, 130, 240),
	rgb(245, 240, 230), rgb(50, 190, 200), rgb(255, 150, 60), rgb(255, 110, 170) }
local FAR = { rgb(175, 195, 230), rgb(195, 210, 240), rgb(160, 185, 225), rgb(215, 225, 245), rgb(185, 200, 235) }
local GLASS = rgb(185, 225, 255) -- vitres : passent en néon la nuit (NightLight)
local PLANES = {
	{ name = "Plan1", h = { 62, 120 }, w = { 24, 46 }, d = { 18, 34 }, gap = { 2, 9 }, rows = 1, studs = true, windows = 3, lit = true,
		pal = VIVID, k = 0 },
	{ name = "Plan2", h = { 110, 210 }, w = { 30, 62 }, d = { 30, 60 }, gap = { 6, 26 }, rows = 2, windows = 2, lit = true,
		pal = VIVID, k = 0.35, antenna = 0.25 },
	{ name = "Plan3", h = { 190, 380 }, w = { 40, 90 }, d = { 40, 90 }, gap = { 10, 50 }, rows = 2, windows = 0,
		pal = FAR, k = 0, antenna = 0.35 },
}
-- bandes de chaque plan : axe "z" (côté ouest, face à +X) ou "x" (nord, face à -Z ; sud, face à +Z), de a0 à a1,
-- profondeur de n0 (bord côté hub) à n1
local STRIPS = {
	Plan1 = {
		{ axis = "z", a0 = -HZ1 - 35, a1 = HZ1 + 35, n0 = HX0 - 19, n1 = HX0 - 119, face = Vector3.new(1, 0, 0) },
		{ axis = "x", a0 = HX0 - 154, a1 = 30, n0 = HZ1 + 6, n1 = HZ1 + 29, face = Vector3.new(0, 0, -1) }, -- avant la vitrine (z 342)
		{ axis = "x", a0 = HX0 - 154, a1 = 30, n0 = -HZ1 - 8, n1 = -HZ1 - 110, face = Vector3.new(0, 0, 1) },
	},
	Plan2 = {
		{ axis = "z", a0 = -900, a1 = 900, n0 = -480, n1 = -660, face = Vector3.new(1, 0, 0) },
		{ axis = "x", a0 = -900, a1 = -225, n0 = 600, n1 = 800, face = Vector3.new(0, 0, -1) },
		{ axis = "x", a0 = -225, a1 = 620, n0 = 1150, n1 = 1330, face = Vector3.new(0, 0, -1) },
		{ axis = "x", a0 = 300, a1 = 760, n0 = 520, n1 = 700, face = Vector3.new(0, 0, -1) },
		{ axis = "x", a0 = -900, a1 = 760, n0 = -600, n1 = -800, face = Vector3.new(0, 0, 1) },
	},
	Plan3 = {
		{ axis = "z", a0 = -1500, a1 = 1500, n0 = -1100, n1 = -1500, face = Vector3.new(1, 0, 0) },
		{ axis = "x", a0 = -1500, a1 = 1100, n0 = 1450, n1 = 1800, face = Vector3.new(0, 0, -1) },
		{ axis = "x", a0 = -1500, a1 = 1100, n0 = -1450, n1 = -1800, face = Vector3.new(0, 0, 1) },
	},
}
local function rr(a) return rng:NextNumber(a[1], a[2]) end
local nBuildings, plan1North, nClash = 0, {}, 0
local opSky = OverlapParams.new(); opSky.FilterType = Enum.RaycastFilterType.Exclude; opSky.FilterDescendantsInstances = { sky }
local function building(parent, pl, x0, z0, x1, z1, face, idx)
	local W, D = x1 - x0, z1 - z0
	local H = math.min(rr(pl.h), heightCap(x0, z0, x1, z1))
	if H < 40 then return end
	-- rien d'autre à cet endroit (décor d'une zone, objet d'essai) : immeuble sauté
	if #workspace:GetPartBoundsInBox(CFrame.new((x0 + x1) / 2, H / 2 + 4, (z0 + z1) / 2), Vector3.new(W + 2, H + 40, D + 2), opSky) > 0 then
		nClash += 1; return
	end
	local base = pl.pal[rng:NextInteger(1, #pl.pal)]
	local col = pl.k > 0 and tint(base, pl.k) or base
	local m = Instance.new("Model"); m.Name = "Building_" .. idx
	local O = { decor = true, studs = pl.studs }
	Bx(m, "Body", x0, -0.6, z0, x1, H, z1, col, O)
	local top = H
	if pl.name ~= "Plan3" then Bx(m, "Roof", x0 - 0.6, H, z0 - 0.6, x1 + 0.6, H + 1.6, z1 + 0.6, shade(col, 0.82), O); top = H + 1.6 end
	-- étage en retrait sur les tours
	if H > pl.h[1] + 0.4 * (pl.h[2] - pl.h[1]) and rng:NextNumber() < 0.55 then
		local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
		local sw, sd = W * rng:NextNumber(0.45, 0.7) / 2, D * rng:NextNumber(0.45, 0.7) / 2
		local sh = H * rng:NextNumber(0.12, 0.25)
		Bx(m, "Setback", cx - sw, top, cz - sd, cx + sw, top + sh, cz + sd, shade(col, 0.92), O)
		top += sh
	end
	-- antenne et feu rouge (néon la nuit)
	if pl.antenna and rng:NextNumber() < pl.antenna then
		local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
		local ah = rng:NextNumber(14, 34)
		P(m, "Antenna", CFrame.new(cx, top + ah / 2, cz) * ROT_UP, Vector3.new(ah, 1.4, 1.4), rgb(70, 76, 92), { decor = true, shape = CYL })
		night(P(m, "AntennaLight", CFrame.new(cx, top + ah + 0.8, cz), Vector3.new(2.4, 2.4, 2.4), rgb(255, 70, 60), { decor = true, shape = BALL }))
	end
	-- vitres sur la face tournée vers le hub : colonnes ou bandeaux
	if pl.windows > 0 then
		local horizontal = rng:NextNumber() < 0.45
		local along = (face.X ~= 0) and D or W -- largeur de la façade
		local fx = function(u, y0, y1, w) -- pièce de vitre centrée en u (le long de la façade), épaisseur 0,6
			if face.X ~= 0 then
				local x = (face.X > 0) and x1 or x0
				return Bx(m, "Window", x - 0.3, y0, z0 + u - w / 2, x + 0.3, y1, z0 + u + w / 2, GLASS, { decor = true })
			else
				local z = (face.Z > 0) and z1 or z0
				return Bx(m, "Window", x0 + u - w / 2, y0, z - 0.3, x0 + u + w / 2, y1, z + 0.3, GLASS, { decor = true })
			end
		end
		if horizontal then
			local n = math.clamp(math.floor((H - 16) / 16), 1, 5)
			for i = 1, n do
				local y = 10 + (i - 1) * (H - 18) / math.max(n, 1)
				local w = fx(along / 2, y, y + 3.2, along - 4)
				if pl.lit then night(w) end
			end
		else
			local n = pl.windows
			for i = 1, n do
				local w = fx(along * i / (n + 1), 8, H - 6, math.min(4.5, along / (n + 1) * 0.55))
				if pl.lit then night(w) end
			end
		end
	end
	m.Parent = parent
	nBuildings += 1
	if pl.name == "Plan1" and face.Z < 0 then table.insert(plan1North, { m = m, x0 = x0, x1 = x1, z0 = z0, z1 = z1, top = H + 1.6 }) end
	return m
end
for _, pl in PLANES do
	local pm = Instance.new("Model"); pm.Name = pl.name
	local idx = 0
	for _, st in STRIPS[pl.name] do
		local nlo, nhi = math.min(st.n0, st.n1), math.max(st.n0, st.n1)
		local band = (nhi - nlo) / pl.rows
		for row = 1, pl.rows do
			local r0 = (st.n0 < st.n1) and (nlo + (row - 1) * band) or (nhi - row * band) -- rang 1 côté hub
			local a = st.a0 + rng:NextNumber(0, 10)
			while a < st.a1 do
				local w = rr(pl.w)
				local d = math.min(rr(pl.d), band)
				local off = rng:NextNumber(0, band - d)
				local a0, a1 = a, math.min(a + w, st.a1)
				local n0, n1
				if st.n0 < st.n1 then n0 = r0 + off; n1 = n0 + d else n1 = r0 + band - off; n0 = n1 - d end
				local x0, z0, x1, z1
				if st.axis == "z" then x0, x1, z0, z1 = n0, n1, a0, a1 else x0, x1, z0, z1 = a0, a1, n0, n1 end
				if a1 - a0 > 12 and not blocked(x0, z0, x1, z1) then
					idx += 1
					building(pm, pl, x0, z0, x1, z1, st.face, idx)
				end
				a = a1 + rr(pl.gap)
			end
		end
	end
	pm.Parent = sky
end
-- sol de ville sous les plans (dessus à -0,6, sous le sol du hub ; plus de mer du ciel entre les immeubles)
local CITY = rgb(146, 166, 192)
local gm = Instance.new("Model"); gm.Name = "CityGround"
-- plaques : le carré x -2600..1000, z -2600..2600, moins le hub, le couloir et la vitrine (AVOID), en morceaux de 2 000 au plus
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
-- Panneau géant sans texte, sur le toit d'un immeuble du plan 1 au nord, face au hub : fond bleu ciel, un cadeau rouge,
-- deux pièces d'or, cadre néon rose (allumé la nuit)
do
	table.sort(plan1North, function(a, b) return math.abs((a.x0 + a.x1) / 2 + 100) < math.abs((b.x0 + b.x1) / 2 + 100) end)
	local host = plan1North[1]
	if host then
		local cx, z = (host.x0 + host.x1) / 2, host.z0 + 2
		local y0 = host.top + 5
		local f = CFrame.lookAt(Vector3.new(cx, y0, z), Vector3.new(cx, y0, z - 1)) -- face avant (-Z local) vers le hub
		local bm = Instance.new("Model"); bm.Name = "GiantBillboard"
		local D = { decor = true }
		for i, s in { -1, 1 } do Fx(bm, f, "Post_" .. i, 18 * s - 0.8, -5, 0.4, 18 * s + 0.8, 1, 2, rgb(60, 66, 82), D) end
		Fx(bm, f, "Panel", -28, 0, -0.5, 28, 28, 0.5, rgb(70, 180, 250), D)
		Fx(bm, f, "PanelBand", -28, 0, -0.6, 28, 6, -0.5, rgb(40, 140, 225), D)
		-- cadeau
		Fx(bm, f, "GiftBox", -20, 4, -1.2, -6, 16, -0.5, rgb(225, 45, 45), D)
		Fx(bm, f, "GiftLid", -21, 16, -1.4, -5, 19, -0.5, rgb(190, 30, 34), D)
		Fx(bm, f, "GiftRibbonV", -14.2, 4, -1.5, -11.8, 19, -1.1, rgb(255, 206, 40), D)
		Fx(bm, f, "GiftRibbonH", -20, 9, -1.4, -6, 11, -1.1, rgb(255, 206, 40), D)
		for i, s in { -1, 1 } do
			P(bm, "GiftBow_" .. i, f * CFrame.new(-13 + 2.6 * s, 20.6, -1.3) * CFrame.Angles(0, 0, math.rad(-28 * s)), Vector3.new(4.6, 2, 0.6), rgb(255, 206, 40), D)
		end
		-- pièces d'or (cylindres tournés vers le hub)
		for i, c in { { 9, 15, 13 }, { 20, 9, 8 } } do
			P(bm, "Coin_" .. i, f * CFrame.new(c[1], c[2], -1) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(1, c[3], c[3]), rgb(255, 196, 40), D)
			P(bm, "CoinRim_" .. i, f * CFrame.new(c[1], c[2], -1.3) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(0.6, c[3] * 0.72, c[3] * 0.72), rgb(255, 220, 90), D)
		end
		-- cadre néon (la nuit)
		for i, e in { { -29, -1, 29, 0 }, { -29, 28, 29, 29 }, { -29, 0, -28, 28 }, { 28, 0, 29, 28 } } do
			night(Fx(bm, f, "Frame_" .. i, e[1], e[2], -0.8, e[3], e[4], 0.8, rgb(255, 90, 190), D))
		end
		bm.Parent = sky
		add("panneau géant sur " .. host.m.Name .. " (x " .. math.floor(cx) .. ", z " .. math.floor(z) .. ", bas à " .. math.floor(y0) .. ")")
	end
end
-- Dirigeable publicitaire au-dessus de la ville, au nord-ouest : enveloppe blanche (sphère étirée), bandeau coloré sans
-- texte sur le flanc tourné vers le hub, nacelle, empennage
do
	local c = Vector3.new(-260, 168, 620)
	local f = CFrame.lookAt(c, c + Vector3.new(1, 0, 0.25)) -- nez vers l'est, flanc gauche (-X local) vers le sud (le hub)
	local dm = Instance.new("Model"); dm.Name = "Blimp"
	local D = { decor = true }
	local env = P(dm, "Envelope", f, Vector3.new(22, 22, 72), rgb(245, 246, 250), D)
	local mesh = Instance.new("SpecialMesh"); mesh.MeshType = Enum.MeshType.Sphere; mesh.Parent = env
	for i, s in { 1, -1 } do -- bandeaux sur les deux flancs
		local band = P(dm, "Banner_" .. i, f * CFrame.new(10.6 * s, 0, 0) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(34, 9, 0.6),
			rgb(255, 90, 80), D)
		P(dm, "BannerStripe_" .. i, band.CFrame * CFrame.new(0, 0, 0.35 * s), Vector3.new(34, 2.2, 0.3), rgb(255, 206, 40), D)
		P(dm, "BannerCoin_" .. i, band.CFrame * CFrame.new(-11, 0, 0.5 * s) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(0.5, 6.4, 6.4), rgb(255, 206, 40), D)
	end
	Fx(dm, f, "Gondola", -3, -14.5, -8, 3, -10.5, 6, rgb(60, 66, 82), D)
	Fx(dm, f, "GondolaWindows", -3.1, -13.4, -7, 3.1, -12, 5, GLASS, D)
	for i, a in { 0, 90, 180, 270 } do
		local fr = f * CFrame.new(0, 0, 30) * CFrame.Angles(0, 0, math.rad(a))
		tri(dm, fr * CFrame.Angles(0, math.rad(90), 0), "Fin_" .. i, Vector2.new(-6, 12.5), Vector2.new(-8, 6), Vector2.new(6, 6), 0.8, rgb(255, 90, 80))
	end
	dm.Parent = sky
end
sky.Parent = map
add("ville : " .. nBuildings .. " immeubles (" .. nClash .. " sautés, place prise), " .. nParts .. " pièces (Map/Skyline)")

-- 2) Sol du hub : dallage 2 tons, partout (plus d'allées dallées depuis le 2026-11-15) ---------------------------------
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
add("dallage : sol en " .. tostring(TILE_A) .. ", " .. nTiles .. " cases foncées")

-- 3) Jardinières, arbres, mobilier -------------------------------------------------------------------------------------
-- obstacles déjà là (hors sol, zone safe, dallage) : tout objet posé qui en touche un est sauté et signalé
local op = OverlapParams.new(); op.FilterType = Enum.RaycastFilterType.Exclude
op.FilterDescendantsInstances = { ground, hub:FindFirstChild("SafeZone"), amb }
local skipped = {}
local function free(cf, size, why)
	local hits = workspace:GetPartBoundsInBox(cf, size, op)
	for _, h in hits do
		if h.Transparency < 1 or h.CanCollide then
			table.insert(skipped, why .. " (touche " .. h:GetFullName():gsub("^Workspace%.Map%.Hub%.", "") .. ")")
			return false
		end
	end
	return true
end
-- arbres du pack Yasu (<= 1 500 triangles : Tree_01 à _05, _12 à _18), feuillage à la teinte du hub
local TREE_TINT = rgb(110, 170, 50)
local pack = SS:FindFirstChild("Assets") and SS.Assets:FindFirstChild("Env") and SS.Assets.Env:FindFirstChild("Yasu's_Stylized_Tree_Pack")
local models = pack and pack:FindFirstChild("Models_Trees") and pack.Models_Trees:FindFirstChild("Models")
local TEMPLATES = {}
if models then
	for _, k in { 1, 2, 3, 4, 5, 12, 13, 14, 15, 16, 17, 18 } do
		local m = models:FindFirstChild(string.format("Tree_%02d", k))
		if m then table.insert(TEMPLATES, m) end
	end
end
if #TEMPLATES == 0 then add("ATTENTION : pack d'arbres Yasu introuvable, jardinières sans arbre") end
local nTrees = 0
local function tree(parent, pos, height, k)
	if #TEMPLATES == 0 then return end
	local t = TEMPLATES[(k - 1) % #TEMPLATES + 1]:Clone()
	local trunk, canopy
	for _, p in t:GetChildren() do
		if p:IsA("MeshPart") and p.Name:match("^Trunk") then trunk = p; p.Name = "Trunk" end
		if p:IsA("MeshPart") and p.Name:match("^Canopy") then canopy = p; p.Name = "Canopy" end
	end
	if not (trunk and canopy) then t:Destroy(); return end
	for _, d in t:GetDescendants() do if d:IsA("LuaSourceContainer") then d:Destroy() end end
	t.Name = "PlanterTree_" .. k
	local cf, size = t:GetBoundingBox()
	local base = trunk:GetPivot().Position
	local h = (cf.Y + size.Y / 2) - base.Y
	t:ScaleTo(t:GetScale() * height / h)
	base = trunk:GetPivot().Position
	t:PivotTo(CFrame.new(t:GetPivot().Position) * CFrame.Angles(0, math.rad((k * 67) % 360), 0) * t:GetPivot().Rotation)
	-- pied du tronc sur la terre de la jardinière (le pivot du modèle n'est pas forcément au pied du tronc)
	t:PivotTo(t:GetPivot() + (pos - trunk:GetPivot().Position))
	local sa = canopy:FindFirstChildOfClass("SurfaceAppearance")
	if sa then sa.Color = TREE_TINT end
	canopy.CanCollide = false; canopy.CanTouch = false; canopy.CanQuery = false
	trunk.CanTouch = false
	for _, p in t:GetDescendants() do if p:IsA("BasePart") then p.Anchored = true end end
	t.Parent = parent
	nTrees += 1
end
local BRICK, SOIL, HEDGE, LEAF = rgb(196, 98, 72), rgb(96, 66, 44), rgb(70, 160, 74), rgb(118, 200, 84)
local function planter(parent, name, c, sx, sz, nTree, k)
	local size = Vector3.new(sx + 2, 6, sz + 2)
	if not free(CFrame.new(c + Vector3.new(0, 3.1, 0)), size, name) then return end
	local m = Instance.new("Model"); m.Name = name
	local x0, x1, z0, z1 = c.X - sx / 2, c.X + sx / 2, c.Z - sz / 2, c.Z + sz / 2
	local S = { studs = true }
	Bx(m, "Rim_N", x0, 0, z1 - 0.8, x1, 1.8, z1, BRICK, S)
	Bx(m, "Rim_S", x0, 0, z0, x1, 1.8, z0 + 0.8, BRICK, S)
	Bx(m, "Rim_W", x0, 0, z0 + 0.8, x0 + 0.8, 1.8, z1 - 0.8, BRICK, S)
	Bx(m, "Rim_E", x1 - 0.8, 0, z0 + 0.8, x1, 1.8, z1 - 0.8, BRICK, S)
	Bx(m, "RimCap", x0 - 0.2, 1.8, z0 - 0.2, x1 + 0.2, 2.1, z1 + 0.2, rgb(240, 232, 214), S)
	Bx(m, "Grass", x0 + 0.8, 0, z0 + 0.8, x1 - 0.8, 1.55, z1 - 0.8, HEDGE, S)
	-- buissons aux coins (petit décor)
	for i, q in { { 1, 1 }, { -1, 1 }, { -1, -1 }, { 1, -1 } } do
		P(m, "Bush_" .. i, CFrame.new(c.X + q[1] * (sx / 2 - 2), 2.2, c.Z + q[2] * (sz / 2 - 2)), Vector3.new(2.6, 2.6, 2.6), LEAF, { decor = true, shape = BALL })
	end
	if nTree == 0 then
		local FL = { rgb(255, 120, 170), rgb(255, 214, 60), rgb(240, 70, 60), rgb(170, 110, 220) }
		for i = 1, 4 do
			local fz = z0 + 1.6 + (i - 0.5) * (sz - 3.2) / 4
			P(m, "Flower_" .. i, CFrame.new(c.X + ((i % 2 == 0) and 0.9 or -0.9), 1.9, fz), Vector3.new(1.3, 1.3, 1.3), FL[i], { decor = true, shape = BALL })
		end
	end
	for t = 1, nTree do
		local tz = (nTree == 1) and c.Z or (z0 + (t - 0.5) * sz / nTree)
		tree(m, Vector3.new(c.X, 1.55, tz), rng:NextNumber(17, 21), k + t)
	end
	m.Parent = parent
	return m
end
-- banc : dossier côté dos, assise face à dir ; sans collision
local WOOD, METAL = rgb(196, 140, 86), rgb(52, 58, 74)
local function bench(parent, name, c, dir)
	local f = CFrame.lookAt(c, c + dir)
	if not free(f * CFrame.new(0, 1.6, 0), Vector3.new(5.4, 3.2, 2), name) then return end
	local m = Instance.new("Model"); m.Name = name
	local D = { decor = true }
	for i, s in { -1, 1 } do Fx(m, f, "Leg_" .. i, 2.1 * s - 0.2, 0, -0.7, 2.1 * s + 0.2, 1.5, 0.7, METAL, D) end
	Fx(m, f, "Seat", -2.6, 1.5, -0.75, 2.6, 1.85, 0.75, WOOD, D)
	for i, s in { -1, 1 } do Fx(m, f, "BackPost_" .. i, 2.1 * s - 0.2, 1.85, 0.55, 2.1 * s + 0.2, 3.4, 0.8, METAL, D) end
	Fx(m, f, "Back", -2.6, 2.3, 0.6, 2.6, 3.3, 0.85, WOOD, D)
	m.Parent = parent
	return m
end
-- lampadaire de mall : mât, potence en T, deux lanternes (NightLight + lumière éteinte le jour) ; sans collision
local POLE = rgb(40, 52, 84)
local lamps = {}
local function lamp(parent, name, c, along)
	if not free(CFrame.new(c + Vector3.new(0, 6, 0)), Vector3.new(1.4, 12, 1.4), name) then return end
	local m = Instance.new("Model"); m.Name = name
	local D = { decor = true }
	P(m, "Base", CFrame.new(c + Vector3.new(0, 0.35, 0)) * ROT_UP, Vector3.new(0.7, 1.4, 1.4), POLE, { decor = true, shape = CYL })
	P(m, "Pole", CFrame.new(c + Vector3.new(0, 6, 0)) * ROT_UP, Vector3.new(11.4, 0.45, 0.45), POLE, { decor = true, shape = CYL })
	local f = CFrame.lookAt(c, c + along) -- potence le long de l'allée
	Fx(m, f, "Arm", -0.2, 11.3, -1.6, 0.2, 11.6, 1.6, POLE, D)
	P(m, "Finial", CFrame.new(c + Vector3.new(0, 12.1, 0)), Vector3.new(0.6, 0.6, 0.6), rgb(255, 200, 60), { decor = true, shape = BALL })
	for i, s in { -1, 1 } do
		Fx(m, f, "Hanger_" .. i, -0.06, 10.6, 1.5 * s - 0.06, 0.06, 11.3, 1.5 * s + 0.06, POLE, D)
		night(Fx(m, f, "Lantern_" .. i, -0.45, 9.2, 1.5 * s - 0.45, 0.45, 10.6, 1.5 * s + 0.45, LAMP_OFF, D), 22, 1.2)
		Fx(m, f, "LanternCap_" .. i, -0.6, 10.6, 1.5 * s - 0.6, 0.6, 10.85, 1.5 * s + 0.6, POLE, D)
	end
	m.Parent = parent
	table.insert(lamps, { pos = c, name = name })
	return m
end
-- fanions entre deux lampadaires : corde qui pend (6 segments) et triangles de couleur, sans collision
local FLAGS = { rgb(240, 70, 60), rgb(255, 200, 50), rgb(60, 160, 240), rgb(80, 200, 110), rgb(160, 100, 240), rgb(255, 140, 50) }
local function bunting(parent, name, a, b)
	local m = Instance.new("Model"); m.Name = name
	local y, sag = 10.9, 1.6
	local function at(t) return a:Lerp(b, t) + Vector3.new(0, y - 4 * sag * t * (1 - t), 0) end
	local n = 6
	for i = 1, n do
		local p0, p1 = at((i - 1) / n), at(i / n)
		P(m, "Rope_" .. i, CFrame.lookAt((p0 + p1) / 2, p1), Vector3.new(0.12, 0.12, (p1 - p0).Magnitude + 0.05), rgb(250, 250, 250), { decor = true })
	end
	local L = (b - a).Magnitude
	local usable = L - 6 -- 3 de marge à chaque bout : pas de fanion contre les lanternes
	local nf = math.floor(usable / 3.4) + 1
	local dir = (b - a).Unit
	for i = 1, nf do
		local t = (3 + (i - 1) * usable / (nf - 1)) / L
		local p = at(t)
		local f = CFrame.fromMatrix(p, dir, Vector3.yAxis, dir:Cross(Vector3.yAxis))
		tri(m, f, "Flag_" .. i, Vector2.new(0, -1.9), Vector2.new(0.75, 0), Vector2.new(-0.75, 0), 0.08, FLAGS[(i - 1) % #FLAGS + 1])
	end
	m.Parent = parent
	return m
end
local plan = Instance.new("Model"); plan.Name = "Planters"
local furn = Instance.new("Model"); furn.Name = "Furniture"
amb.Parent = hub
plan.Parent = amb; furn.Parent = amb
-- Disposition (2026-11-15, boutiques rapprochées du couloir) : sur l'axe x -24, entre les boutiques et l'allée des stands,
-- lampadaires et fanions, et deux jardinières basses (fleurs) à deux bancs de chaque côté ; un grand bac à deux arbres dans
-- chaque coin, derrière la dernière boutique du fond, et un au sud-est, au-delà de la roue. Clément, 2026-11-15 : plus
-- d'allées dallées de crème (« ça fait moche »), la moitié des jardinières en moins.
local MEDIAN_X = -24
local k = 0
for _, s in { 1, -1 } do
	local tag = (s > 0) and "N" or "S"
	for i, z in { 77, 156 } do
		k += 1
		local c = Vector3.new(MEDIAN_X, 0, z * s)
		if planter(plan, "Planter_" .. tag .. i, c, 6, 12, 0, k * 3) then
			bench(furn, "Bench_" .. tag .. i .. "_W", Vector3.new(MEDIAN_X - 4.4, 0, z * s), Vector3.new(-1, 0, 0))
			bench(furn, "Bench_" .. tag .. i .. "_E", Vector3.new(MEDIAN_X + 4.4, 0, z * s), Vector3.new(1, 0, 0))
		end
	end
	local prev
	for i, z in { 14, 56, 98, 138, 172 } do
		local c = Vector3.new(MEDIAN_X, 0, z * s)
		local l = lamp(furn, "Lamp_" .. tag .. i, c, Vector3.new(1, 0, 0)) -- lanternes vers les deux allées, fanions le long de l'axe
		if l and prev then bunting(furn, "Bunting_" .. tag .. i, prev, c) end
		prev = l and c or nil
	end
	k += 1
	planter(plan, "Planter_" .. tag .. "_Corner1", Vector3.new(-112, 0, 237 * s), 12, 30, 2, k * 3)
end
for i, z in { -215 } do
	k += 1
	planter(plan, "Planter_SE" .. i, Vector3.new(16, 0, z), 10, 14, 1, k * 3)
end
-- (2026-11-15 : un essai de façades de ville sur le grand mur a été refusé par Clément : le damier reste tel quel)
add("hub : " .. nTrees .. " arbres, " .. #lamps .. " lampadaires, " .. #furn:GetChildren() .. " objets de mobilier, " .. #plan:GetChildren() .. " jardinières")
if #skipped > 0 then add("sautés (place prise) : " .. table.concat(skipped, " ; ")) end

-- 4) Vérifications ----------------------------------------------------------------------------------------------------
-- chemins : depuis l'apparition jusqu'au devant de chaque boutique et de chaque stand
local spawn = hub:FindFirstChild("Spawn")
local from = spawn and spawn.Position + Vector3.new(0, 3, 0) or Vector3.new(-37, 3, 0)
local fails = {}
local targets = {}
for _, sh in (hub:FindFirstChild("Shops") and hub.Shops:GetChildren() or {}) do
	-- 8 devant la porte de chaque boutique (PlotDoor), sur ses plaques
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
