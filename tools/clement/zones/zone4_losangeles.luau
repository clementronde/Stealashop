--!nocheck
-- Zone 4 — Los Angeles (MOD-022) : bijouterie, horlogerie, avenue de luxe et quartier autour.
-- À lancer dans Studio (MCP execute_luau, mode Edit), APRÈS tools/clement/store_builder.luau (option scale).
-- Relancer ce script reconstruit la zone 4 à l'identique : les modèles et dossiers du même nom sont remplacés.
-- Gabarit commun des zones (2026-11-07) : tout est à ×1.5. Les magasins passent par l'option scale du
-- constructeur ; le décor est dessiné directement à ×1.5. Couloir de 60 studs entre les façades (z = ±30),
-- trottoirs à |z| 22.5..30 au niveau du sol des magasins (0,45), chaussée z -22.5..22.5 libre, quartier
-- (sol, immeubles, repère) jusqu'à |z| = 140. Zones rallongées de ×1,25 (L-071, 2026-11-08 : x' = 30 + (x - 30) × 1,25) :
-- la zone 4 va de x 368 (arche 4) à x 530 (arche 5), magasins en x = 442 ; rien n'en sort.
-- Arbres : ce script pose des palmiers en pièces, que tools/clement/env/trees_replace.luau remplace par les arbres
-- du pack (règle de Clément : plus d'arbres en pièces) ; relancer trees_replace après ce script.
-- Bâti sur le modèle de tools/clement/zones/zone2_londres.luau : une fonction « facade » pour le style,
-- une spec par magasin (couleurs, enseigne, rayons, produits), puis le décor dans Map/Zone_4.
-- Règles : aucun script laissé dans la map ; noms du contrat (10.4) jamais réutilisés pour le décor ;
-- aucune marque réelle sur les enseignes, les panneaux ni les produits ; tous les textes visibles en jeu sont en anglais
-- (consigne de Clément, 2026-11-07), les noms techniques (modèles, contrat) ne changent pas.
-- La fin du script vérifie la zone en mode Edit (contrat, colis dégagés, chaussée libre, emprise, greybox,
-- chemins du vigile).

local rgb = Color3.fromRGB
local CollectionService = game:GetService("CollectionService")
local Store = _G.ClaudeStore
assert(Store, "charger d'abord tools/clement/store_builder.luau")

local GOLD, BLACK = rgb(212, 175, 55), rgb(22, 22, 26)
local WARM = rgb(255, 206, 150)
local DIAL = rgb(250, 246, 232)
local CYL, BALL, WEDGE = Enum.PartType.Cylinder, Enum.PartType.Ball, Enum.PartType.Wedge
local NEON, GLASS = Enum.Material.Neon, Enum.Material.Glass

-- Gabarit 2026-11-07
local K = 1.5                                         -- échelle du décor
local WALK = 0.45                                     -- dessus des trottoirs = sol des magasins
local ROAD = rgb(68, 56, 74)                          -- chaussée de la zone 4 : asphalte prune (couleur de la zone)
local SAND = rgb(224, 200, 170)                       -- sol du quartier : sable chaud
local whiteL, yellow, red = rgb(240, 240, 236), rgb(255, 196, 0), rgb(255, 40, 40)
local bandC = rgb(226, 230, 236)

-- Pièce posée par son CFrame (cylindres, coins, pièces tournées). Lisse par défaut, studs sur demande.
local function newPart(parent, name, cf, size, color, opt)
	opt = opt or {}
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color; p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	if opt.shape then p.Shape = opt.shape end
	if opt.mat then p.Material = opt.mat
	elseif opt.studs then p.Material = Enum.Material.Plastic; p.MaterialVariant = "Studs"
	else p.Material = Enum.Material.SmoothPlastic end
	if opt.decor then p.CanCollide = false; p.CanTouch = false end
	if opt.noQuery then p.CanQuery = false end
	if opt.T then p.Transparency = opt.T end
	if opt.refl then p.Reflectance = opt.refl end
	if opt.noShadow then p.CastShadow = false end
	p.Parent = parent
	return p
end

-- Pièces du décor en coordonnées du monde (ou d'un repère frame), modèles, cylindres debout.
local W = CFrame.identity
local function newModel(parent, name) local m = Instance.new("Model"); m.Name = name; m.Parent = parent; return m end
local function Bx(parent, frame, name, x0, y0, z0, x1, y1, z1, color, opt)
	local size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
	return newPart(parent, name, frame * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), size, color, opt)
end
local function vcyl(parent, name, x, y0, y1, z, dia, color, opt)
	opt = opt or {}; opt.shape = CYL
	return newPart(parent, name, CFrame.new(x, (y0 + y1) / 2, z) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(y1 - y0, dia, dia), color, opt)
end

-- Texte sur une face (enseignes des boutiques, panneaux de rue).
local function textLabel(part, face, text, color, ppS, stroke)
	local g = Instance.new("SurfaceGui"); g.Name = "LabelGui_" .. face.Name; g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = ppS or 40; g.LightInfluence = 0
	local t = Instance.new("TextLabel"); t.Name = "Label"; t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(1, 1)
	t.Text = text; t.TextScaled = true; t.TextColor3 = color
	t.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
	local s = Instance.new("UIStroke"); s.Color = stroke or Color3.new(0, 0, 0); s.Thickness = 3; s.LineJoinMode = Enum.LineJoinMode.Round; s.Parent = t
	local pad = Instance.new("UIPadding"); pad.PaddingTop = UDim.new(0.14, 0); pad.PaddingBottom = UDim.new(0.14, 0); pad.Parent = t
	t.Parent = g; g.Parent = part
	return t
end

-- Palmier de Los Angeles : tronc très fin, à peine penché, couronne de 6 palmes en deux morceaux (elles montent
-- puis retombent). mk(name, cf, size, color, opt) crée la pièce ; base = pied du tronc ; h = hauteur du tronc ;
-- s = échelle ; turn = sens de la pente (rad) ; solid = tronc avec collision ; th = épaisseur des palmes (×).
local TRUNK_A, TRUNK_B = rgb(128, 102, 76), rgb(108, 86, 64)
local FROND_A, FROND_B = rgb(56, 126, 58), rgb(86, 154, 66)
local function palm(mk, base, h, s, turn, solid, th)
	th = th or 1
	local lean = Vector3.new(math.cos(turn), 0, math.sin(turn))
	local tilt = math.rad(3)
	local axis = Vector3.yAxis * math.cos(tilt) + lean * math.sin(tilt)
	local rotT = CFrame.fromAxisAngle(Vector3.yAxis:Cross(lean), tilt)
	local p = base.Position
	local dia = { 1.0, 0.86, 0.74 }
	local seg = h / 3
	for i = 1, 3 do
		local c = p + axis * (seg * (i - 0.5))
		mk("Trunk_" .. i, CFrame.new(c) * rotT * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(seg + 0.1, dia[i] * s, dia[i] * s), (i % 2 == 1) and TRUNK_A or TRUNK_B, { shape = CYL, decor = not solid })
	end
	local top = p + axis * h
	mk("Crown", CFrame.new(top), Vector3.new(1.3, 1.3, 1.3) * s, FROND_A, { shape = BALL, decor = true })
	for k = 0, 5 do
		local yaw = turn + k * math.pi / 3
		local L1, L2 = 2.8 * s, 3.3 * s
		local inner = CFrame.new(top) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(16), 0, 0)
		mk("Frond_" .. (k + 1) .. "A", inner * CFrame.new(0, 0, -L1 / 2), Vector3.new(1.0 * s, 0.14 * th, L1), (k % 2 == 0) and FROND_A or FROND_B, { decor = true })
		local tip = (inner * CFrame.new(0, 0, -L1)).Position
		local outer = CFrame.new(tip) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(-40), 0, 0)
		mk("Frond_" .. (k + 1) .. "B", outer * CFrame.new(0, 0, -L2 / 2), Vector3.new(0.8 * s, 0.12 * th, L2), (k % 2 == 0) and FROND_B or FROND_A, { decor = true })
	end
end

-- Horloge ronde : lunette, cadran, index (facultatifs), aiguilles, axe. c = centre ; nrm = vers celui qui regarde ;
-- R = rayon du cadran ; hour, minute = heure affichée (sens horaire vu de face).
local function clockFace(mk, prefix, c, nrm, R, hour, minute, rim, dial, ink, withIndexes)
	local up = Vector3.yAxis
	local right = (-nrm):Cross(up)
	mk(prefix .. "Rim", CFrame.fromMatrix(c, nrm, up), Vector3.new(0.16, 2 * R + 0.4, 2 * R + 0.4), rim, { shape = CYL, decor = true })
	mk(prefix .. "Dial", CFrame.fromMatrix(c + nrm * 0.1, nrm, up), Vector3.new(0.06, 2 * R, 2 * R), dial, { shape = CYL, decor = true })
	local function stick(name, theta, len, w, from, depth)
		local d = up * math.cos(theta) + right * math.sin(theta)
		local x = right * math.cos(theta) - up * math.sin(theta)
		mk(prefix .. name, CFrame.fromMatrix(c + nrm * depth + d * (from + len / 2), x, d), Vector3.new(w, len, 0.05), ink, { decor = true })
	end
	if withIndexes then
		for k = 0, 11 do
			local big = (k % 3 == 0)
			local li = (big and 0.26 or 0.15) * R
			stick("Index_" .. (k + 1), k * math.pi / 6, li, (big and 0.09 or 0.05) * R, R * 0.9 - li, 0.15)
		end
	end
	stick("HourHand", ((hour % 12) + minute / 60) * math.pi / 6, 0.6 * R, 0.09 * R, -0.08 * R, 0.2)
	stick("MinuteHand", minute * math.pi / 30, 0.9 * R, 0.06 * R, -0.08 * R, 0.2)
	mk(prefix .. "Pin", CFrame.fromMatrix(c + nrm * 0.22, nrm, up), Vector3.new(0.06, 0.14 * R, 0.14 * R), rim, { shape = CYL, decor = true })
end

-- Étoile à 5 branches, à plat : un disque au centre et deux coins (Wedge) par branche, chacun avec son angle
-- droit au milieu de la base de la branche. c = centre ; nrm = normale ; up = branche du haut ; Ro = rayon des
-- pointes ; th = épaisseur ; mat = matériau (Neon pour les étoiles dorées).
local function star(mk, prefix, c, nrm, up, Ro, th, color, mat)
	local Ri = Ro * 0.382
	local rt = up:Cross(nrm).Unit
	local function dir(a) return up * math.cos(a) + rt * math.sin(a) end
	mk(prefix .. "Core", CFrame.fromMatrix(c, nrm, up), Vector3.new(th, 2 * Ri, 2 * Ri), color, { shape = CYL, decor = true, noShadow = true, mat = mat })
	for k = 0, 4 do
		local a = k * 2 * math.pi / 5
		local tip = c + dir(a) * Ro
		local mid = c + dir(a) * (Ri * math.cos(math.pi / 5))
		for _, hv in { { "A", -1 }, { "B", 1 } } do
			local inner = c + dir(a + hv[2] * math.pi / 5) * Ri
			local av, bv = inner - mid, tip - mid
			local la, lb = av.Magnitude, bv.Magnitude
			av, bv = av.Unit, bv.Unit
			mk(prefix .. "Ray" .. (k + 1) .. hv[1], CFrame.fromMatrix(mid + av * (la / 2) + bv * (lb / 2), av:Cross(bv), bv),
				Vector3.new(th, lb, la), color, { shape = WEDGE, decor = true, noShadow = true, mat = mat })
		end
	end
end

-- Projecteur d'avant-première : socle, fourche, fût tourné vers le ciel et faisceau (Beam, sans script).
-- base = pied du socle ; dir = direction du faisceau ; len = longueur du faisceau.
local function searchlight(parent, name, base, dir, len)
	local m = newModel(parent, name)
	local dark, steel = rgb(40, 42, 48), rgb(150, 154, 160)
	newPart(m, "Base", CFrame.new(base + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(1.2, 3, 3), dark, { shape = CYL, studs = true })
	local side = dir:Cross(Vector3.yAxis)
	side = (side.Magnitude > 1e-3) and side.Unit or Vector3.xAxis
	for i, sg in { -1, 1 } do
		newPart(m, "Yoke_" .. i, CFrame.new(base + Vector3.new(0, 2.25, 0) + side * sg * 1.35), Vector3.new(0.35, 2.1, 0.35), steel, { decor = true })
	end
	local head = base + Vector3.new(0, 3.3, 0)
	local upv = side:Cross(dir).Unit
	newPart(m, "Barrel", CFrame.fromMatrix(head, dir, upv), Vector3.new(3.4, 2.3, 2.3), dark, { shape = CYL, decor = true })
	newPart(m, "Rim", CFrame.fromMatrix(head + dir * 1.75, dir, upv), Vector3.new(0.25, 2.6, 2.6), steel, { shape = CYL, decor = true })
	local lensPos = head + dir * 1.8
	local lens = newPart(m, "Lens", CFrame.fromMatrix(lensPos, dir, upv), Vector3.new(0.12, 2.0, 2.0), rgb(255, 248, 225), { shape = CYL, mat = NEON, decor = true, noShadow = true })
	local a0 = Instance.new("Attachment"); a0.Name = "BeamStart"; a0.Parent = lens; a0.WorldPosition = lensPos
	local a1 = Instance.new("Attachment"); a1.Name = "BeamEnd"; a1.Parent = lens; a1.WorldPosition = lensPos + dir * len
	local b = Instance.new("Beam"); b.Name = "LightBeam"
	b.Attachment0 = a0; b.Attachment1 = a1; b.FaceCamera = true; b.Segments = 1
	b.Width0 = 2; b.Width1 = 18; b.LightEmission = 1; b.LightInfluence = 0
	b.Color = ColorSequence.new(rgb(255, 248, 228), rgb(255, 232, 190))
	b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(0.5, 0.82), NumberSequenceKeypoint.new(1, 1) })
	b.Parent = lens
	return m
end

-- Effet d'ambiance : pièce invisible (ni collision, ni contact, ni requête, verrouillée pour ne pas gêner la
-- sélection dans Studio) qui porte un ParticleEmitter en volume. Aucun script.
local function ns(points)
	local kp = {}
	for _, p in points do table.insert(kp, NumberSequenceKeypoint.new(p[1], p[2])) end
	return NumberSequence.new(kp)
end
local function fxBox(parent, name, cf, size)
	local p = newPart(parent, name, cf, size, rgb(255, 214, 120), { decor = true, noQuery = true, T = 1, noShadow = true })
	p.Locked = true
	return p
end
local function emitter(part, name, o)
	local pe = Instance.new("ParticleEmitter"); pe.Name = name
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = o.color; pe.LightEmission = o.emission; pe.LightInfluence = 0
	pe.Size = o.size; pe.Transparency = o.transp; pe.Lifetime = o.life; pe.Rate = o.rate
	pe.Speed = o.speed; pe.SpreadAngle = Vector2.new(180, 180); pe.Acceleration = o.accel; pe.Drag = o.drag
	pe.Rotation = NumberRange.new(0, 360); pe.RotSpeed = o.rot
	pe.Shape = Enum.ParticleEmitterShape.Box; pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	pe.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	pcall(function() pe.Brightness = o.bright end)
	pe.Parent = part
	return pe
end

-- Vitrine de la bijouterie : bustes à colliers sur le socle, écrins à bagues sur la tablette.
local function displayJewels(e)
	local B, V, deco, gold = e.B, e.V, e.deco, e.gold
	local velvetD = rgb(26, 24, 30)
	local chains = { gold, rgb(248, 244, 232), rgb(214, 218, 226) }
	local stones = { rgb(200, 240, 255), rgb(220, 40, 70), rgb(40, 170, 100) }
	for i, x in { -14.4, -12.1, -9.8 } do
		B("Bust_" .. i, x - 0.45, 1.6, -24.6, x + 0.45, 3.3, -24.2, velvetD, deco(V))
		B("Necklace_" .. i, x - 0.47, 2.5, -24.64, x + 0.47, 2.68, -24.18, chains[i], deco(V))
		B("Pendant_" .. i, x - 0.13, 2.18, -24.66, x + 0.13, 2.5, -24.6, stones[i], deco(V, { mat = NEON, noShadow = true }))
	end
	for i, x in { -14.0, -12.1, -10.2 } do
		B("RingBox_" .. i, x - 0.32, 4.1, -24.55, x + 0.32, 4.5, -24.15, rgb(110, 20, 40), deco(V))
		B("Ring_" .. i, x - 0.17, 4.5, -24.4, x + 0.17, 4.84, -24.3, gold, deco(V))
		B("RingStone_" .. i, x - 0.09, 4.84, -24.4, x + 0.09, 4.98, -24.3, stones[i], deco(V, { mat = NEON, noShadow = true }))
	end
end

-- Vitrine de l'horlogerie : montres sur coussins, pendule et sabliers sur la tablette.
local function displayWatches(e)
	local B, P, V, deco, gold, black = e.B, e.P, e.V, e.deco, e.gold, e.black
	local straps = { rgb(90, 52, 30), black, rgb(28, 40, 88) }
	local rot = CFrame.Angles(0, math.rad(90), 0)
	for i, x in { -14.4, -12.1, -9.8 } do
		B("WatchCushion_" .. i, x - 0.45, 1.6, -24.55, x + 0.45, 2.75, -24.15, rgb(236, 226, 206), deco(V))
		B("WatchStrap_" .. i, x - 0.2, 1.7, -24.62, x + 0.2, 2.85, -24.55, straps[i], deco(V))
		P(V, "WatchCase_" .. i, CFrame.new(x, 2.28, -24.66) * rot, Vector3.new(0.08, 0.64, 0.64), gold, { shape = CYL, decor = true })
		P(V, "WatchDial_" .. i, CFrame.new(x, 2.28, -24.71) * rot, Vector3.new(0.03, 0.5, 0.5), DIAL, { shape = CYL, decor = true })
	end
	B("MantelClock", -13.0, 4.1, -24.6, -11.2, 5.4, -24.15, rgb(92, 58, 34), deco(V))
	B("MantelTop", -13.2, 5.4, -24.62, -11.0, 5.6, -24.12, gold, deco(V))
	P(V, "MantelDial", CFrame.new(-12.1, 4.8, -24.63) * rot, Vector3.new(0.06, 0.95, 0.95), DIAL, { shape = CYL, decor = true })
	for i, x in { -14.7, -9.5 } do
		B("HourglassBase_" .. i, x - 0.35, 4.1, -24.55, x + 0.35, 4.25, -24.2, gold, deco(V))
		B("HourglassGlass_" .. i, x - 0.24, 4.25, -24.5, x + 0.24, 5.1, -24.25, rgb(240, 220, 170), deco(V, { mat = GLASS, T = 0.3 }))
		B("HourglassTop_" .. i, x - 0.35, 5.1, -24.55, x + 0.35, 5.25, -24.2, gold, deco(V))
	end
end

-- Façade d'avenue de luxe : rez-de-chaussée en pierre blanche ou crème, grandes vitrines cerclées de noir,
-- auvents noirs bordés d'or, mur-rideau de verre sur les étages, emblème (diamant au néon ou grande horloge),
-- palmiers sur le toit. Elle habille aussi l'intérieur sans rien déplacer : vitrines vitrées sur les rayons
-- (ouvertes devant chaque colis), tapis, lumière chaude, lustres ou horloges du monde, coffres-forts.
-- Elle travaille dans les coordonnées du constructeur (échelle 1) : l'option scale agrandit ensuite tout le
-- magasin, façade comprise.
-- spec.la = { gold, glass, velvet, carpet, carpetEdge, displayBody, headerText, counterTopMat, emblem, emblemY,
--             plaque, display, interior, vault, redCarpet?, streetClock? }
local function laFacade(ctx)
	local B, label, group, C, model, ORIGIN = ctx.B, ctx.label, ctx.group, ctx.colors, ctx.model, ctx.ORIGIN
	local LA = ctx.spec.la
	local top = ctx.facadeTop
	local gold, black = LA.gold or GOLD, BLACK
	local function P(parent, name, cf, size, color, opt) return newPart(parent, name, ORIGIN * cf, size, color, opt) end
	local function deco(parent, extra)
		local o = { parent = parent, studs = false, decor = true }
		if extra then for k, v in extra do o[k] = v end end
		return o
	end
	local function light(part, range, bright, color)
		local pl = Instance.new("PointLight"); pl.Range = range; pl.Brightness = bright; pl.Color = color or WARM; pl.Shadows = false; pl.Parent = part
		return part
	end
	local Interior = model:FindFirstChild("Interior")

	-- 0) Lumière plus chaude dans tout le magasin (néons du constructeur, avant d'ajouter nos lampes)
	for _, d in model:GetDescendants() do
		if d:IsA("PointLight") then d.Color = WARM; d.Brightness = 0.5 end
	end

	local F, U, A = group("Facade"), group("UpperFloors"), group("Awning")
	-- 1) Volume des étages, comme à Londres : la façade a une épaisseur
	B("UpperSide_L", -20.05, 10.8, -23, -19, top, -12, C.upper, { parent = U })
	B("UpperSide_R", 19, 10.8, -23, 20.05, top, -12, C.upper, { parent = U })
	B("UpperBack", -20.05, 10.8, -12, 20.05, top, -11, C.upper, { parent = U })
	B("UpperRoof", -20.05, top, -22.8, 20.05, top + 0.4, -11, C.roof, { parent = U })
	B("RoofParapet", -20.05, top + 0.4, -11.6, 20.05, top + 1.2, -11, C.upper, { parent = U })

	-- 2) Mur-rideau : verre teinté, meneaux noirs, traverses d'étage dorées, ailerons dorés dans la pierre
	local gy0, gy1 = 11.9, top - 1.1
	B("CurtainGlass", -13, gy0, -24.7, 13, gy1, -24.6, LA.glass, deco(U, { mat = GLASS })).Reflectance = 0.12
	for i = 0, 8 do
		local x = -13 + i * 3.25
		B("Mullion_" .. (i + 1), x - 0.14, gy0, -24.82, x + 0.14, gy1, -24.6, black, deco(U))
	end
	local nf = math.max(1, math.floor((gy1 - gy0) / 4.6 + 0.5))
	for k = 0, nf do
		local y = gy0 + (gy1 - gy0) * k / nf
		B("Transom_" .. (k + 1), -13.14, y - 0.16, -24.86, 13.14, y + 0.16, -24.6, (k == 0 or k == nf) and black or gold, deco(U))
	end
	for i, x in { -16.9, -15.1, 15.1, 16.9 } do
		B("GoldFin_" .. i, x - 0.1, gy0, -24.72, x + 0.1, gy1, -24.6, gold, deco(U))
	end

	-- 3) Auvents noirs (couleurs de la spec) avec un liseré doré sous les lambrequins
	B("AwningTrim_Win", -6.8, 7.12, -27.14, 6.8, 7.25, -26.9, gold, deco(A))
	B("AwningTrim_Door", 10.6, 7.12, -27.14, 15.4, 7.25, -26.9, gold, deco(A))

	-- 4) Grande vitrine d'exposition sur le mur de gauche : fond de velours, verre, tablette dorée, éclairage
	local V = group("ShowWindow")
	local vx0, vx1, vy0, vy1 = -15.8, -8.4, 1.6, 6.9
	B("ShowBack", vx0, vy0, -24.06, vx1, vy1, -24.0, LA.velvet, deco(V))
	B("ShowSill", vx0 - 0.2, vy0 - 0.3, -24.95, vx1 + 0.2, vy0, -24.0, black, deco(V))
	B("ShowHead", vx0 - 0.2, vy1, -24.95, vx1 + 0.2, vy1 + 0.35, -24.0, black, deco(V))
	B("ShowSide_L", vx0 - 0.2, vy0, -24.95, vx0, vy1, -24.0, black, deco(V))
	B("ShowSide_R", vx1, vy0, -24.95, vx1 + 0.2, vy1, -24.0, black, deco(V))
	B("ShowTrim", vx0 - 0.2, vy1 + 0.35, -24.98, vx1 + 0.2, vy1 + 0.45, -24.0, gold, deco(V))
	B("ShowShelf", vx0, 4.0, -24.8, vx1, 4.1, -24.06, gold, deco(V))
	B("ShowGlass", vx0, vy0, -24.9, vx1, vy1, -24.84, rgb(215, 235, 245), deco(V, { mat = GLASS, T = 0.65, noShadow = true }))
	light(B("ShowLight", vx0 + 0.3, vy1 - 0.12, -24.6, vx1 - 0.3, vy1 - 0.02, -24.3, rgb(255, 236, 200), deco(V, { mat = NEON, noShadow = true })), 9, 0.7)
	LA.display({ B = B, P = P, V = V, deco = deco, gold = gold, black = black })

	-- 5) Plaque dorée et appliques de part et d'autre de la porte
	local pq = B("Plaque", 7.3, 3.4, -24.1, 9.9, 5.4, -24.0, gold, deco(F))
	label(pq, Enum.NormalId.Front, LA.plaque, black, 60, gold)
	for i, x in { 10.5, 15.5 } do
		B("Sconce_" .. i, x - 0.2, 5.5, -24.25, x + 0.2, 6.7, -24.0, black, deco(F))
		light(B("SconceGlow_" .. i, x - 0.14, 5.7, -24.42, x + 0.14, 6.5, -24.25, rgb(255, 226, 180), deco(F, { mat = NEON, noShadow = true })), 10, 0.6)
	end

	-- 6) Emblème devant le mur-rideau : diamant taillé au néon (bijouterie) ou grande horloge (horlogerie)
	local E = group("Emblem")
	if LA.emblem == "diamond" then
		local yg, a, b, hc, hp = LA.emblemY or 20, 3.4, 2.0, 1.6, 3.6
		local zc, t = -24.95, 0.14
		local function neon(extra)
			local o = { mat = NEON, decor = true, noShadow = true }
			for k, v in extra or {} do o[k] = v end
			return o
		end
		local tableP = B("GemTable", -b, yg, zc - t / 2, b, yg + hc, zc + t / 2, rgb(190, 245, 255), deco(E, { mat = NEON, noShadow = true }))
		local w1, rx = a - b, (a + b) / 2
		P(E, "GemCrown_R", CFrame.new(rx, yg + hc / 2, zc) * CFrame.Angles(0, -math.pi / 2, 0), Vector3.new(t, hc, w1), rgb(120, 214, 246), neon({ shape = WEDGE }))
		P(E, "GemCrown_L", CFrame.new(-rx, yg + hc / 2, zc) * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(t, hc, w1), rgb(120, 214, 246), neon({ shape = WEDGE }))
		P(E, "GemPavilion_R", CFrame.fromMatrix(Vector3.new(a / 2, yg - hp / 2, zc), Vector3.new(0, 0, -1), Vector3.new(0, -1, 0)), Vector3.new(t, hp, a), rgb(86, 178, 236), neon({ shape = WEDGE }))
		P(E, "GemPavilion_L", CFrame.fromMatrix(Vector3.new(-a / 2, yg - hp / 2, zc), Vector3.new(0, 0, 1), Vector3.new(0, -1, 0)), Vector3.new(t, hp, a), rgb(150, 226, 252), neon({ shape = WEDGE }))
		B("GemGirdle", -a, yg - 0.07, zc - t / 2 - 0.04, a, yg + 0.07, zc - t / 2, rgb(255, 255, 255), deco(E, { mat = NEON, noShadow = true }))
		B("Sparkle_V", a + 0.55, yg + hc, zc - 0.05, a + 0.75, yg + hc + 1.4, zc + 0.05, rgb(255, 255, 255), deco(E, { mat = NEON, noShadow = true }))
		B("Sparkle_H", a - 0.05, yg + hc + 0.6, zc - 0.05, a + 1.35, yg + hc + 0.8, zc + 0.05, rgb(255, 255, 255), deco(E, { mat = NEON, noShadow = true }))
		light(tableP, 18, 0.8, rgb(170, 230, 255))
	elseif LA.emblem == "clock" then
		clockFace(function(name, cf, size, color, opt) return P(E, name, cf, size, color, opt) end, "FacadeClock",
			Vector3.new(0, LA.emblemY or 17.4, -24.95), Vector3.new(0, 0, -1), 2.6, 10, 10, gold, DIAL, black, true)
		light(E:FindFirstChild("FacadeClockDial"), 14, 0.6)
	end

	-- 7) Palmiers sur le toit, visibles depuis la rue
	for i, x in { -15.5, 15.5 } do
		local y0 = top + 0.4
		B("RoofPlanter_" .. i, x - 1.1, y0, -20.6, x + 1.1, y0 + 1.1, -18.4, black, { parent = U })
		palm(function(name, cf, size, color, opt) return P(U, "RoofPalm_" .. i .. "_" .. name, cf, size, color, opt) end,
			CFrame.new(x, y0 + 1.1, -19.5), 6.5, 0.62, i * 1.3 + 0.4, false)
	end

	-- 8) Trottoir : tapis rouge à cordons devant la porte (bijouterie), horloge sur pied (horlogerie)
	if LA.redCarpet then
		local RC = group("RedCarpet")
		B("RedCarpet", 11.4, 0.3, -28.4, 14.6, 0.34, -24.1, rgb(170, 22, 36), deco(RC, { mat = Enum.Material.Carpet, noShadow = true }))
		for i, q in { { 10.9, -25.4 }, { 10.9, -27.6 }, { 15.1, -25.4 }, { 15.1, -27.6 } } do
			B("StanchionBase_" .. i, q[1] - 0.3, 0.3, q[2] - 0.3, q[1] + 0.3, 0.42, q[2] + 0.3, gold, deco(RC))
			B("Stanchion_" .. i, q[1] - 0.1, 0.42, q[2] - 0.1, q[1] + 0.1, 2.9, q[2] + 0.1, gold, deco(RC))
		end
		for i, x in { 10.9, 15.1 } do
			B("VelvetRope_" .. i, x - 0.06, 2.45, -27.5, x + 0.06, 2.6, -25.5, rgb(150, 18, 32), deco(RC))
		end
	end
	if LA.streetClock then
		local SK = group("StreetClock")
		local x, z = LA.streetClock[1], LA.streetClock[2]
		B("ClockFoot", x - 0.6, 0.3, z - 0.6, x + 0.6, 1.3, z + 0.6, black, { parent = SK })
		P(SK, "ClockPost", CFrame.new(x, 5.2, z) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(7.8, 0.5, 0.5), black, { shape = CYL })
		for i, y in { 1.5, 8.9 } do
			P(SK, "ClockCollar_" .. i, CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(0.3, 0.8, 0.8), gold, { shape = CYL, decor = true })
		end
		local hy = 10.35
		B("ClockCase", x - 1.25, hy - 1.25, z - 0.4, x + 1.25, hy + 1.25, z + 0.4, black, deco(SK))
		B("ClockCrest", x - 0.35, hy + 1.25, z - 0.25, x + 0.35, hy + 1.9, z + 0.25, gold, deco(SK))
		for _, sd in { { "Street", -1 }, { "Shop", 1 } } do
			clockFace(function(name, cf, size, color, opt) return P(SK, name, cf, size, color, opt) end, "Clock" .. sd[1],
				Vector3.new(x, hy, z + sd[2] * 0.48), Vector3.new(0, 0, sd[2]), 0.95, 10, 10, gold, DIAL, black, false)
		end
	end

	-- 9) Vitrines vitrées sur les rayons (décor, ni collision ni requête), ouvertes au niveau 2 devant chaque
	--    colis (±1,3 stud autour du ShelfSlot, là où le constructeur ne met pas de produit)
	local SC = group("ShowCases")
	local function pane(name, fx, s, za, zb, ya, yb)
		local p = B(name, fx + s * 0.08, ya, za, fx + s * 0.13, yb, zb, rgb(226, 240, 248), deco(SC, { mat = GLASS, T = 0.7, noShadow = true }))
		p.CanQuery = false
	end
	for _, f in { { "Shelf_A_L", -9, -1, { -3 } }, { "Shelf_A_R", -5, 1, { -11, 6 } }, { "Shelf_B_L", 5, -1, { -11, 6 } },
		{ "Shelf_B_R", 9, 1, { -3 } }, { "Shelf_WallL", -17, 1, { -9 } }, { "Shelf_WallR", 17, -1, { -9, 5 } } } do
		local nm, fx, s, gaps = f[1], f[2], f[3], f[4]
		pane(nm .. "_Glass1", fx, s, -14.8, 8.8, 0.62, 1.68)
		pane(nm .. "_Glass3", fx, s, -14.8, 8.8, 3.62, 4.83)
		local za = -14.8
		for k, g in gaps do
			pane(nm .. "_Glass2_" .. k, fx, s, za, g - 1.3, 1.87, 3.42)
			za = g + 1.3
		end
		pane(nm .. "_Glass2_" .. (#gaps + 1), fx, s, za, 8.8, 1.87, 3.42)
	end

	-- 10) Tapis dans les trois allées, cimaise dorée sur les murs
	local carpetOpt = deco(Interior, { mat = Enum.Material.Carpet, noShadow = true })
	B("Carpet_Main", -3.2, 0.37, -21.2, 3.2, 0.4, 15, LA.carpet, carpetOpt)
	B("CarpetEdge_L", -3.5, 0.37, -21.2, -3.2, 0.41, 15, LA.carpetEdge, deco(Interior, { noShadow = true }))
	B("CarpetEdge_R", 3.2, 0.37, -21.2, 3.5, 0.41, 15, LA.carpetEdge, deco(Interior, { noShadow = true }))
	B("Carpet_Aisle1", -15.2, 0.37, -20.4, -10.8, 0.4, 8.6, LA.carpet, carpetOpt)
	B("Carpet_Aisle3", 10.8, 0.37, -20.4, 15.2, 0.4, 8.6, LA.carpet, carpetOpt)
	B("WallRail_L", -18.9, 7.25, -23, -18.84, 7.4, 22.9, gold, deco(Interior, { noShadow = true }))
	B("WallRail_R", 18.84, 7.25, -23, 18.9, 7.4, 16, gold, deco(Interior, { noShadow = true }))

	-- 11) Lustres de cristal (bijouterie) ; horloges du monde et suspensions (horlogerie)
	if LA.interior == "chandeliers" then
		for i, z in { -12, -2, 8 } do
			local y = 8.3
			B("ChandelierChain_" .. i, -0.05, y + 0.5, z - 0.05, 0.05, 9.6, z + 0.05, gold, deco(Interior, { noShadow = true }))
			P(Interior, "ChandelierRing_" .. i, CFrame.new(0, y + 0.4, z) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(0.18, 2.6, 2.6), gold, { shape = CYL, decor = true, noShadow = true })
			for k = 0, 5 do
				local an = k * math.pi / 3
				local cx, cz = math.cos(an) * 1.05, z + math.sin(an) * 1.05
				B("ChandelierCrystal_" .. i .. "_" .. (k + 1), cx - 0.1, y - 0.5, cz - 0.1, cx + 0.1, y + 0.31, cz + 0.1, rgb(225, 245, 255), deco(Interior, { mat = GLASS, T = 0.25, noShadow = true }))
			end
			light(B("ChandelierCore_" .. i, -0.22, y - 0.95, z - 0.22, 0.22, y + 0.31, z + 0.22, rgb(255, 238, 205), deco(Interior, { mat = NEON, noShadow = true })), 16, 0.75, rgb(255, 214, 160))
		end
	elseif LA.interior == "clocks" then
		-- les villes des zones du jeu, chacune à son heure quand il est 9 h à Los Angeles
		for i, c in { { "LONDON", 17 }, { "TOKYO", 2 }, { "LOS ANGELES", 9 }, { "PARIS", 18 }, { "NEW YORK", 12 } } do
			local x = -16.6 + (i - 1) * 3.8
			clockFace(function(name, cf, size, color, opt) return P(Interior, name, cf, size, color, opt) end, "WorldClock" .. i .. "_",
				Vector3.new(x, 8.1, 22.8), Vector3.new(0, 0, -1), 0.9, c[2], 0, gold, DIAL, black, false)
			local pl = B("WorldClockPlate_" .. i, x - 1.6, 6.62, 22.82, x + 1.6, 7.0, 22.9, black, deco(Interior, { noShadow = true }))
			label(pl, Enum.NormalId.Front, c[1], gold, 60)
		end
		for i, z in { -12, -2, 8 } do
			B("PendantCord_" .. i, -0.04, 8.2, z - 0.04, 0.04, 9.6, z + 0.04, black, deco(Interior, { noShadow = true }))
			P(Interior, "PendantShade_" .. i, CFrame.new(0, 7.9, z) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(0.6, 1.6, 1.6), gold, { shape = CYL, decor = true, noShadow = true })
			light(B("PendantBulb_" .. i, -0.3, 7.35, z - 0.3, 0.3, 7.6, z + 0.3, rgb(255, 230, 190), deco(Interior, { mat = NEON, noShadow = true })), 16, 0.75, rgb(255, 210, 150))
		end
	end

	-- 12) Recolorations : présentoir du fond (ex-frigos), caisse, têtes de gondole, bandeaux, réserve, coffres
	for _, nm in { "Fridge_Back", "Fridge_Base", "Fridge_Top", "Fridge_SideA", "Fridge_SideB" } do
		local p = Interior:FindFirstChild(nm); if p then p.Color = LA.displayBody end
	end
	for _, nm in { "FridgeShelf_0", "FridgeShelf_1" } do
		local p = Interior:FindFirstChild(nm); if p then p.Color = gold end
	end
	local belt = Interior:FindFirstChild("CounterBelt"); if belt then belt.Color = LA.velvet end
	local ctop = Interior:FindFirstChild("CounterTop"); if ctop and LA.counterTopMat then ctop.Material = LA.counterTopMat end
	local packs = { gold, rgb(214, 218, 226), rgb(248, 244, 232) }
	for _, d in Interior:GetChildren() do
		local k = d.Name:match("^PromoPack_%a(%d)$")
		if k then d.Color = packs[tonumber(k) + 1] end
		if d.Name:match("_Header$") then
			for _, g in d:GetChildren() do
				local l = g:FindFirstChild("Label"); if l then l.TextColor3 = LA.headerText end
			end
		end
	end
	for k2 = 0, 3 do
		if Interior:FindFirstChild("Stock_" .. k2) then
			local px = 1.7 + (k2 % 2) * 2.4 + 1.1
			local py = 0.6 + math.floor(k2 / 2) * 1.1 + 0.5
			P(Interior, "SafeDial_" .. k2, CFrame.new(px, py, 19.74) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(0.1, 0.55, 0.55), gold, { shape = CYL, decor = true, noShadow = true })
			B("SafeHandle_" .. k2, px + 0.55, py - 0.05, 19.7, px + 0.85, py + 0.05, 19.8, gold, deco(Interior, { noShadow = true }))
		end
	end
	local rs = model:FindFirstChild("Reserve") and model.Reserve:FindFirstChild("ReserveSign")
	local rl = rs and rs:FindFirstChild("LabelGui_Front") and rs.LabelGui_Front:FindFirstChild("Label")
	if rl then rl.Text = LA.vault or "STOCKROOM"; rl.TextColor3 = gold end
end
_G.ClaudeLosAngeles = { facade = laFacade, palm = palm, clockFace = clockFace, star = star, searchlight = searchlight }

-- 1) Greybox de la zone 4 (et seulement elle) au gabarit : rue de x 368 à 530 et de z -22.5 à 22.5, bas-côtés
--    Side_N et Side_S à |z| 22.5..62.5, murets à |z| 30..31.5 hauts de 18 hors de l'emprise des magasins (x 412..472),
--    arche ×1.5 posée à y = 0, centrée sur z = 0 en x = 368 (nom, tag et structure inchangés), points de patrouille
--    de nuit déplacés par la formule du ×1,25 (x 408,1 et 489,4, z = 0).
--    Couleurs de la zone : chaussée prune, sol sable. Les magasins gris (s'il en revient) vont dans
--    ServerStorage/_GREYBOX_REMPLACE.
do
	local SS = game:GetService("ServerStorage")
	local gz4 = workspace.Greybox.Corridor.Zone_4
	for _, nm in { "STORE_Z4_Bijouterie", "STORE_Z4_Horlogerie" } do
		local m = gz4:FindFirstChild(nm)
		if m then
			local keep = SS:FindFirstChild("_GREYBOX_REMPLACE") or Instance.new("Folder")
			keep.Name = "_GREYBOX_REMPLACE"; keep.Parent = SS
			m.Parent = keep
		end
	end
	local g = gz4.Ground
	local function set(p, size, pos) p.Size = size; p.Position = pos end
	set(g.Street, Vector3.new(162, 2, 45), Vector3.new(449, -1, 0))
	g.Street.Color = ROAD; g.Street.Material = Enum.Material.Plastic; g.Street.MaterialVariant = "Studs"
	for _, sd in { { "N", 1 }, { "S", -1 } } do
		local side = g["Side_" .. sd[1]]
		set(side, Vector3.new(162, 2, 40), Vector3.new(449, -1, sd[2] * 42.5))
		side.Color = SAND
		set(g["SideWall_" .. sd[1] .. "1"], Vector3.new(44, 18, 1.5), Vector3.new(390, 9, sd[2] * 30.75))
		set(g["SideWall_" .. sd[1] .. "2"], Vector3.new(58, 18, 1.5), Vector3.new(501, 9, sd[2] * 30.75))
	end
	for nm, x in { NightPatrol_Z4_A = 408.1, NightPatrol_Z4_B = 489.4 } do
		local p = gz4:FindFirstChild(nm)
		if p then p.CFrame = p.CFrame - p.Position + Vector3.new(x, p.Position.Y, 0) end
	end
	local gate = gz4.ZoneGate_4
	gate:ScaleTo(1.5)
	local cf, size = gate:GetBoundingBox()
	gate:PivotTo(gate:GetPivot() + Vector3.new(368 - cf.X, size.Y / 2 - cf.Y, -cf.Z))
end

-- 2) Dossier de la zone
local zoneFolder = workspace.Map:FindFirstChild("Zone_4")
if not zoneFolder then zoneFolder = Instance.new("Folder"); zoneFolder.Name = "Zone_4"; zoneFolder.Parent = workspace.Map end
for _, nm in { "STORE_Z4_Bijouterie", "STORE_Z4_Horlogerie" } do
	local old = zoneFolder:FindFirstChild(nm); if old then old:Destroy() end
end
-- Point d'apparition du camion (L-052, pièce taggée TruckSpawn posée dans Map/Zone_4 par la session principale) :
-- x = 30 + (360 - 30) × 1,25 = 442,5 (L-071) ; hauteur, z et sens du camion gardés
local truck = zoneFolder:FindFirstChild("TruckSpawn")
if truck and truck:IsA("BasePart") then truck.CFrame = truck.CFrame - truck.Position + Vector3.new(442.5, truck.Position.Y, truck.Position.Z) end
-- filet de sécurité : si le constructeur chargé n'a pas encore l'option scale, on agrandit ici de la même façon
local function ensureScale(m) if math.abs(m:GetScale() - K) > 1e-3 then m:ScaleTo(K) end end

-- 3) Bijouterie : pierre blanche, noir et or, velours bordeaux, sol de marbre, lustres de cristal
local white = rgb(244, 242, 236)
local bij, bijN = Store.build({
	name = "STORE_Z4_Bijouterie", zone = 4, scale = K,
	origin = CFrame.new(442, 0, 66), parent = zoneFolder,
	sign = "JEWELRY",
	signColors = { bg = BLACK, text = rgb(232, 194, 84), border = GOLD },
	signRect = { -16, 16, 8.95, 10.75 }, facadeTop = 26,
	awning = { a = rgb(20, 20, 24), b = rgb(34, 34, 38) },
	promo = "EXCLUSIVE",
	colors = {
		wall = rgb(236, 234, 228), front = white, upper = white, trim = GOLD, cornice = rgb(250, 249, 245), pilaster = rgb(230, 226, 214),
		frame = BLACK, plinth = rgb(32, 32, 36), roof = rgb(112, 116, 124),
		innerWall = rgb(246, 240, 228), ceiling = rgb(250, 246, 238), floor = rgb(232, 226, 216), tile = rgb(212, 204, 192),
		reserve = rgb(110, 114, 124), shelf = rgb(26, 24, 28), shelfBack = rgb(96, 20, 36), kick = rgb(176, 140, 52), price = GOLD,
		counter = rgb(26, 24, 28), counterTop = rgb(240, 236, 228), mat = rgb(116, 20, 38), doorKick = GOLD,
		glass = rgb(205, 232, 250), neon = rgb(255, 232, 196), wood = rgb(54, 36, 26), gold = rgb(230, 190, 70), carton = rgb(170, 128, 84),
		pot = rgb(24, 24, 28), leaf = rgb(40, 110, 56), promo = rgb(24, 22, 26), promoText = rgb(232, 194, 84),
	},
	headers = {
		A_L = { "RINGS", rgb(120, 22, 44) }, A_R = { "WEDDING BANDS", rgb(150, 116, 40) },
		B_L = { "NECKLACES", rgb(26, 38, 92) }, B_R = { "PEARLS", rgb(92, 62, 122) },
		WallL = { "BRACELETS", rgb(22, 92, 72) }, WallR = { "EARRINGS", rgb(136, 32, 82) }, Back = { "DIAMONDS", rgb(24, 22, 26) },
	},
	designs = {
		bague = { body = rgb(122, 22, 44), cap = rgb(230, 190, 70), w = 0.7, h = 0.6, ch = 0.2, d = 0.7 },
		bagueD = { body = rgb(24, 26, 64), cap = rgb(210, 240, 255), w = 0.7, h = 0.6, ch = 0.2, d = 0.7 },
		bagueR = { body = rgb(20, 20, 24), cap = rgb(220, 40, 70), w = 0.7, h = 0.6, ch = 0.2, d = 0.7 },
		alliance = { body = rgb(246, 242, 236), cap = rgb(230, 190, 70), w = 0.65, h = 0.55, ch = 0.15, d = 0.65 },
		allianceA = { body = rgb(246, 242, 236), cap = rgb(214, 218, 226), w = 0.65, h = 0.55, ch = 0.15, d = 0.65 },
		collier = { body = rgb(20, 20, 24), cap = rgb(230, 190, 70), w = 0.8, h = 1.2, ch = 0.3, d = 0.6 },
		collierP = { body = rgb(24, 26, 64), cap = rgb(248, 244, 232), w = 0.8, h = 1.2, ch = 0.3, d = 0.6 },
		collierE = { body = rgb(122, 22, 44), cap = rgb(40, 170, 100), w = 0.8, h = 1.2, ch = 0.3, d = 0.6 },
		perles = { body = rgb(236, 226, 206), cap = rgb(252, 250, 244), w = 1.0, h = 0.45, ch = 0.2, d = 0.8 },
		perlesR = { body = rgb(40, 26, 30), cap = rgb(250, 220, 226), w = 1.0, h = 0.45, ch = 0.2, d = 0.8 },
		bracelet = { body = rgb(236, 226, 206), cap = rgb(230, 190, 70), w = 0.9, h = 0.5, ch = 0.18, d = 0.7 },
		braceletA = { body = rgb(20, 20, 24), cap = rgb(214, 218, 226), w = 0.9, h = 0.5, ch = 0.18, d = 0.7 },
		boucles = { body = rgb(20, 20, 24), cap = rgb(220, 40, 70), w = 0.55, h = 0.8, ch = 0.2, d = 0.5 },
		bouclesS = { body = rgb(246, 242, 236), cap = rgb(40, 90, 220), w = 0.55, h = 0.8, ch = 0.2, d = 0.5 },
		bouclesE = { body = rgb(122, 22, 44), cap = rgb(40, 170, 100), w = 0.55, h = 0.8, ch = 0.2, d = 0.5 },
		gemD = { body = rgb(200, 240, 255), w = 0.6, h = 0.9 },
		gemR = { body = rgb(220, 40, 70), w = 0.6, h = 0.9 },
		gemS = { body = rgb(40, 90, 220), w = 0.6, h = 0.9 },
		gemE = { body = rgb(40, 170, 100), w = 0.6, h = 0.9 },
	},
	pools = {
		A_L = { "bague", "bagueD", "bagueR" }, A_R = { "alliance", "allianceA" },
		B_L = { "collier", "collierP", "collierE" }, B_R = { "perles", "perlesR" },
		WallL = { "bracelet", "braceletA" }, WallR = { "boucles", "bouclesS", "bouclesE" },
		Back = { "gemD", "gemR", "gemS", "gemE" },
	},
	seed = 4004, stockColor = rgb(70, 74, 82),
	la = {
		gold = GOLD, glass = rgb(70, 92, 118), velvet = rgb(110, 20, 40),
		carpet = rgb(116, 20, 38), carpetEdge = GOLD, displayBody = rgb(24, 22, 26), headerText = rgb(240, 212, 130),
		counterTopMat = Enum.Material.Marble,
		emblem = "diamond", emblemY = 20.0,
		plaque = "FINE JEWELRY\nSINCE 1926",
		display = displayJewels, interior = "chandeliers", vault = "STOCKROOM",
		redCarpet = true,
	},
	facade = laFacade,
})
ensureScale(bij)
task.wait()

-- 4) Horlogerie : pierre crème, noir et or, bois de noyer et velours vert, parquet, horloges du monde
local cream, brass = rgb(238, 228, 204), rgb(214, 178, 80)
local hor, horN = Store.build({
	name = "STORE_Z4_Horlogerie", zone = 4, scale = K,
	origin = CFrame.new(442, 0, -66) * CFrame.Angles(0, math.pi, 0), parent = zoneFolder,
	sign = "WATCHES & CLOCKS",
	signColors = { bg = brass, text = BLACK, border = BLACK },
	signRect = { -16, 16, 8.95, 10.75 }, facadeTop = 24,
	awning = { a = rgb(20, 20, 24), b = rgb(34, 34, 38) },
	promo = "LIMITED EDITION",
	colors = {
		wall = rgb(232, 220, 194), front = cream, upper = cream, trim = brass, cornice = rgb(246, 240, 226), pilaster = rgb(222, 208, 178),
		frame = BLACK, plinth = rgb(32, 32, 36), roof = rgb(112, 116, 124),
		innerWall = rgb(242, 232, 212), ceiling = rgb(248, 242, 230), floor = rgb(116, 76, 48), tile = rgb(138, 94, 60),
		reserve = rgb(110, 114, 124), shelf = rgb(92, 58, 34), shelfBack = rgb(26, 70, 50), kick = rgb(184, 146, 64), price = brass,
		counter = rgb(92, 58, 34), counterTop = rgb(30, 64, 48), mat = rgb(28, 40, 88), doorKick = brass,
		glass = rgb(205, 232, 250), neon = rgb(255, 230, 190), wood = rgb(80, 50, 30), gold = brass, carton = rgb(170, 128, 84),
		pot = rgb(24, 24, 28), leaf = rgb(40, 110, 56), promo = rgb(26, 70, 50), promoText = rgb(232, 200, 110),
	},
	headers = {
		A_L = { "WATCHES", rgb(26, 70, 50) }, A_R = { "CHRONOGRAPHS", rgb(26, 70, 50) },
		B_L = { "ALARM CLOCKS", rgb(110, 30, 40) }, B_R = { "MANTEL CLOCKS", rgb(110, 30, 40) },
		WallL = { "POCKET WATCHES", rgb(28, 40, 88) }, WallR = { "CUCKOO CLOCKS", rgb(100, 62, 36) }, Back = { "CLOCKS", rgb(24, 22, 26) },
	},
	designs = {
		montre = { body = rgb(20, 20, 24), cap = rgb(230, 190, 70), w = 0.7, h = 0.55, ch = 0.2, d = 0.7 },
		montreS = { body = rgb(24, 36, 90), cap = rgb(214, 218, 226), w = 0.7, h = 0.55, ch = 0.2, d = 0.7 },
		montreR = { body = rgb(100, 24, 36), cap = rgb(232, 168, 140), w = 0.7, h = 0.55, ch = 0.2, d = 0.7 },
		chrono = { body = rgb(40, 40, 44), cap = rgb(190, 196, 206), w = 0.75, h = 0.6, ch = 0.25, d = 0.7 },
		chronoN = { body = rgb(236, 226, 206), cap = rgb(24, 24, 28), w = 0.75, h = 0.6, ch = 0.25, d = 0.7 },
		reveil = { body = rgb(200, 44, 40), cap = rgb(220, 182, 80), w = 0.75, h = 0.85, ch = 0.2, d = 0.6 },
		reveilB = { body = rgb(40, 90, 170), cap = rgb(220, 182, 80), w = 0.75, h = 0.85, ch = 0.2, d = 0.6 },
		reveilV = { body = rgb(60, 140, 90), cap = rgb(220, 182, 80), w = 0.75, h = 0.85, ch = 0.2, d = 0.6 },
		pendule = { body = rgb(100, 62, 36), cap = rgb(210, 170, 70), w = 0.9, h = 1.2, ch = 0.3, d = 0.6 },
		penduleN = { body = rgb(28, 28, 32), cap = rgb(230, 190, 70), w = 0.9, h = 1.2, ch = 0.3, d = 0.6 },
		gousset = { body = rgb(20, 80, 56), cap = rgb(230, 190, 70), w = 0.65, h = 0.5, ch = 0.15, d = 0.65 },
		goussetA = { body = rgb(24, 36, 90), cap = rgb(214, 218, 226), w = 0.65, h = 0.5, ch = 0.15, d = 0.65 },
		coucou = { body = rgb(128, 80, 44), cap = rgb(70, 42, 24), w = 0.9, h = 1.2, ch = 0.35, d = 0.55 },
		coucouV = { body = rgb(150, 96, 54), cap = rgb(40, 90, 50), w = 0.9, h = 1.2, ch = 0.35, d = 0.55 },
		comtoise = { body = rgb(100, 62, 36), w = 0.6, h = 1.6 },
		comtoiseM = { body = rgb(70, 40, 24), w = 0.6, h = 1.6 },
		comtoiseN = { body = rgb(28, 28, 32), w = 0.6, h = 1.5 },
		sablier = { body = rgb(220, 182, 80), w = 0.6, h = 0.9 },
	},
	pools = {
		A_L = { "montre", "montreS", "montreR" }, A_R = { "chrono", "chronoN" },
		B_L = { "reveil", "reveilB", "reveilV" }, B_R = { "pendule", "penduleN" },
		WallL = { "gousset", "goussetA" }, WallR = { "coucou", "coucouV" },
		Back = { "comtoise", "comtoiseM", "comtoiseN", "sablier" },
	},
	seed = 4040, stockColor = rgb(70, 74, 82),
	la = {
		gold = brass, glass = rgb(64, 84, 96), velvet = rgb(24, 70, 50),
		carpet = rgb(28, 40, 88), carpetEdge = brass, displayBody = rgb(92, 58, 34), headerText = rgb(240, 212, 130),
		counterTopMat = Enum.Material.Leather,
		emblem = "clock", emblemY = 17.4,
		plaque = "MASTER\nWATCHMAKERS\nSINCE 1931",
		display = displayWatches, interior = "clocks", vault = "STOCKROOM",
		streetClock = { -18.6, -27.6 },
	},
	facade = laFacade,
})
ensureScale(hor)
task.wait()

-- 5) Décor de rue ×1.5 : Map/Zone_4/Street_LosAngeles. Chaussée libre de z -22.5 à 22.5 ; trottoirs roses à
--    |z| 22.5..30, hauts de 0,45 (au niveau du sol des magasins), semés d'étoiles dorées ; boutiques plaquées
--    sur les murets, sans collision ; tours et panneaux publicitaires derrière les murets ; entrée de la zone
--    (couronne « LOS ANGELES » au-dessus de l'arche, étoiles, projecteurs) ; poussière dorée en suspension.
do
	local Z = zoneFolder
	local old = Z:FindFirstChild("Street_LosAngeles"); if old then old:Destroy() end
	local S = Instance.new("Folder"); S.Name = "Street_LosAngeles"; S.Parent = Z
	local function folder(name) local f = Instance.new("Model"); f.Name = name; f.Parent = S; return f end

	-- Trottoirs en terrazzo rose, bordures (rouges devant les bornes d'incendie), joints de dalles, étoiles dorées
	-- sur dalles sombres ; double ligne jaune, lignes de voie pointillées, passage piéton juste après l'arche
	local G = folder("Ground")
	local pave, kerbC, jointC, redC = rgb(234, 200, 192), rgb(246, 230, 222), rgb(206, 170, 164), rgb(196, 44, 40)
	local hydrants = { N = { 392, 488 }, S = { 400, 492 } }
	for _, s in { 1, -1 } do
		local tag = s > 0 and "N" or "S"
		Bx(G, W, "Pavement_" .. tag, 368, 0, s * 23.25, 530, WALK, s * 30, pave, { studs = true })
		local x, k = 368, 0
		for _, hx in hydrants[tag] do
			k += 1
			Bx(G, W, "Kerb_" .. tag .. k, x, 0, s * 22.5, hx - 4.5, WALK, s * 23.25, kerbC, { studs = true })
			Bx(G, W, "RedKerb_" .. tag .. k, hx - 4.5, 0, s * 22.5, hx + 4.5, WALK, s * 23.25, redC, { studs = true })
			x = hx + 4.5
		end
		Bx(G, W, "Kerb_" .. tag .. (k + 1), x, 0, s * 22.5, 530, WALK, s * 23.25, kerbC, { studs = true })
		for j = 0, 10 do
			local jx = 375.5 + j * 15
			Bx(G, W, "Joint_" .. tag .. (j + 1), jx - 0.09, WALK, s * 23.4, jx + 0.09, WALK + 0.03, s * 29.85, jointC, { decor = true, noShadow = true })
		end
		for j = 0, 9 do
			local x0 = 386 + j * 15
			Bx(G, W, "LaneDash_" .. tag .. (j + 1), x0, 0, s * 11.025, x0 + 6.75, 0.04, s * 11.475, whiteL, { decor = true, noShadow = true })
		end
	end
	-- double ligne jaune coupée au passage piéton et autour des points de patrouille de nuit du greybox
	-- (NightPatrol_Z4_A en x = 408.1 et NightPatrol_Z4_B en x = 489.4, pastilles de 3 × 3 au milieu de la chaussée)
	for i, seg in { { 368, 371 }, { 382, 405.6 }, { 410.6, 486.9 }, { 491.9, 530 } } do
		Bx(G, W, "YellowLine_N" .. i, seg[1], 0, 0.225, seg[2], 0.04, 0.675, yellow, { decor = true, noShadow = true })
		Bx(G, W, "YellowLine_S" .. i, seg[1], 0, -0.675, seg[2], 0.04, -0.225, yellow, { decor = true, noShadow = true })
	end
	for i = 0, 11 do
		local z0 = -20.7 + i * 3.6
		Bx(G, W, "Crosswalk_" .. (i + 1), 372, 0, z0, 381, 0.04, z0 + 1.8, whiteL, { decor = true, noShadow = true })
	end
	-- dalles étoilées : devant les magasins (x 412..472) et entre les pieds des boutiques (bacs) et des palmiers
	local starTiles = { N = { 405, 422.5, 430.5, 438.5, 446.5, 454.5, 478.5, 497.5, 512.5, 525 },
		S = { 404.5, 429, 437, 445, 453, 461, 480.5, 501.5, 519 } }
	for tag, xs in starTiles do
		local s = (tag == "N") and 1 or -1
		for i, x in xs do
			local t = Bx(G, W, "StarTile_" .. tag .. i, x - 1.8, WALK, s * 24.9, x + 1.8, WALK + 0.06, s * 28.5, rgb(44, 40, 48), { decor = true, noShadow = true })
			textLabel(t, Enum.NormalId.Top, "★", rgb(240, 200, 90), 30, rgb(150, 110, 30))
		end
	end

	-- Palmiers sur les trottoirs, dans des fosses de terre (tronc avec collision, palmes sans) ; les deux de
	-- l'entrée sont les plus hauts
	local Pm = folder("Palms")
	for tag, list in { N = { { 378, 50 }, { 415.5 }, { 482.5 }, { 508 } }, S = { { 377, 50 }, { 414 }, { 476.5 }, { 506 } } } do
		local s = (tag == "N") and 1 or -1
		for i, sp in list do
			local x, z = sp[1], s * 26.55
			Bx(Pm, W, "TreeWell_" .. tag .. i, x - 1.65, WALK, z - 1.65, x + 1.65, WALK + 0.045, z + 1.65, rgb(84, 66, 50), { decor = true, noShadow = true })
			local m = newModel(Pm, "Palm_" .. tag .. i)
			local h = sp[2] or (24 + ((i * 7 + (s > 0 and 0 or 3)) % 5) * 2) * K
			palm(function(name, cf, size, color, opt) return newPart(m, name, cf, size, color, opt) end, CFrame.new(x, WALK + 0.045, z), h, K, i * 1.1 + (s > 0 and 0 or 0.5), true, K)
		end
	end

	-- Réverbères « tête de cobra » : tête au-dessus de la bordure, jamais au-dessus de la chaussée.
	-- La lentille (Lens) porte le tag NightLight (liaison L-043, point 3) et elle est livrée éteinte : en verre,
	-- lumière coupée. SkyController l'allume la nuit (Neon, lumières activées), puis rend l'état livré au jour.
	local D = folder("Props")
	local poleC, headC = rgb(118, 122, 128), rgb(70, 74, 80)
	for tag, xs in { N = { 397.5, 468.5, 493.5, 520.5 }, S = { 389.5, 418, 487, 514.5 } } do
		local s = (tag == "N") and 1 or -1
		for i, x in xs do
			local z = s * 25.95
			local m = newModel(D, "Lamp_" .. tag .. i)
			Bx(m, W, "Base", x - 0.675, WALK, z - 0.675, x + 0.675, 1.8, z + 0.675, poleC, { studs = true })
			vcyl(m, "Pole", x, 1.8, 21.3, z, 0.63, poleC)
			Bx(m, W, "Arm", x - 0.18, 20.55, s * 23.85, x + 0.18, 20.925, z, poleC, { decor = true })
			Bx(m, W, "Head", x - 0.675, 20.325, s * 22.575, x + 0.675, 21.075, s * 24.9, headC, { decor = true })
			local lens = Bx(m, W, "Lens", x - 0.48, 20.22, s * 22.8, x + 0.48, 20.325, s * 24.675, rgb(255, 238, 205), { mat = GLASS, decor = true, noShadow = true })
			local pl = Instance.new("PointLight"); pl.Color = rgb(255, 222, 170); pl.Range = 39; pl.Brightness = 1.1; pl.Shadows = false
			pl.Enabled = false; pl.Parent = lens
			CollectionService:AddTag(lens, "NightLight")
		end
	end

	-- Bornes d'incendie jaunes (comme à Los Angeles), devant une bordure peinte en rouge
	local hydC, capC = rgb(240, 196, 40), rgb(200, 200, 196)
	for tag, xs in hydrants do
		local s = (tag == "N") and 1 or -1
		for i, x in xs do
			local z = s * 24.3
			local m = newModel(D, "Hydrant_" .. tag .. i)
			vcyl(m, "Flange", x, WALK, 0.75, z, 1.5, hydC)
			vcyl(m, "Barrel", x, 0.75, 3.0, z, 1.08, hydC)
			vcyl(m, "Bonnet", x, 3.0, 3.45, z, 1.35, hydC, { decor = true })
			Bx(m, W, "Nut", x - 0.21, 3.45, z - 0.21, x + 0.21, 3.825, z + 0.21, capC, { decor = true })
			newPart(m, "SideNozzles", CFrame.new(x, 2.175, z), Vector3.new(1.95, 0.51, 0.51), capC, { shape = CYL, decor = true })
			newPart(m, "Pumper", CFrame.new(x, 1.95, z - s * 0.675) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(0.6, 0.75, 0.75), capC, { shape = CYL, decor = true })
		end
	end

	-- Panneaux de rue verts aux deux bouts de l'avenue
	local signG = rgb(22, 110, 64)
	for _, sg in { { "N", 373.5, 25.8 }, { "S", 525, -25.8 } } do
		local x, z = sg[2], sg[3]
		local m = newModel(D, "StreetSign_" .. sg[1])
		vcyl(m, "Post", x, WALK, 17.85, z, 0.45, rgb(140, 144, 150))
		local b1 = Bx(m, W, "BladeMain", x - 3.9, 15.0, z - 0.075, x + 3.9, 16.35, z + 0.075, signG, { decor = true })
		textLabel(b1, Enum.NormalId.Front, "STAR BLVD", whiteL, 40, signG)
		textLabel(b1, Enum.NormalId.Back, "STAR BLVD", whiteL, 40, signG)
		local b2 = Bx(m, W, "BladeCross", x - 0.075, 16.425, z - 3.0, x + 0.075, 17.775, z + 3.0, signG, { decor = true })
		textLabel(b2, Enum.NormalId.Left, "PALM DR", whiteL, 40, signG)
		textLabel(b2, Enum.NormalId.Right, "PALM DR", whiteL, 40, signG)
		Bx(m, W, "Cap", x - 0.3, 17.85, z - 0.3, x + 0.3, 18.075, z + 0.3, rgb(140, 144, 150), { decor = true })
	end

	-- Boutiques de l'avenue plaquées sur les murets (le muret reste le vrai mur, la boutique n'a pas de collision)
	local Hs = folder("Boutiques")
	local trimW = rgb(250, 248, 242)
	local function boutique(name, frame, w, st)
		local m = newModel(Hs, name)
		local h = st.h
		local dk = { decor = true }
		Bx(m, frame, "Wall", 0, 0, 0, w, h, 2.025, st.wall, { studs = true, decor = true })
		Bx(m, frame, "Plinth", 0, WALK, -0.12, w, 1.425, 0, rgb(34, 34, 38), dk)
		Bx(m, frame, "ShopFrame", 1.2, 1.425, -0.15, w - 5.55, 12.3, 0, BLACK, dk)
		Bx(m, frame, "ShopGlass", 1.575, 1.8, -0.24, w - 5.925, 11.925, -0.15, rgb(62, 74, 92), { decor = true, mat = GLASS })
		Bx(m, frame, "EntryFrame", w - 4.95, WALK, -0.15, w - 1.2, 11.25, 0, BLACK, dk)
		Bx(m, frame, "EntryGlass", w - 4.575, WALK, -0.24, w - 1.575, 10.875, -0.15, rgb(62, 74, 92), { decor = true, mat = GLASS })
		Bx(m, frame, "EntryPull", w - 3.375, 4.5, -0.45, w - 3.15, 7.05, -0.24, GOLD, dk)
		local run, drop = 3.3, 1.35
		local len = math.sqrt(run * run + drop * drop)
		newPart(m, "Awning", frame * CFrame.new(w / 2, 13.275 - drop / 2, -run / 2) * CFrame.Angles(-math.atan2(drop, run), 0, 0), Vector3.new(w - 1.8, 0.225, len), BLACK, dk)
		Bx(m, frame, "Valance", 0.9, 10.95, -run - 0.12, w - 0.9, 11.925, -run + 0.06, BLACK, dk)
		Bx(m, frame, "ValanceTrim", 0.9, 10.77, -run - 0.15, w - 0.9, 10.95, -run + 0.09, GOLD, dk)
		local sb = Bx(m, frame, "SignBand", 1.5, 13.8, -0.18, w - 1.5, 16.05, 0, st.signBg or BLACK, dk)
		textLabel(sb, Enum.NormalId.Front, st.text, st.signText or rgb(232, 194, 84), 40, st.signStroke)
		local gy0, gy1 = 17.1, h - 2.1
		Bx(m, frame, "UpperGlass", 1.5, gy0, -0.15, w - 1.5, gy1, 0, rgb(88, 118, 148), { decor = true, mat = GLASS })
		local nm = math.max(2, math.floor((w - 3) / 4.8))
		for k = 1, nm - 1 do
			local x = 1.5 + (w - 3) * k / nm
			Bx(m, frame, "Mullion_" .. k, x - 0.18, gy0, -0.3, x + 0.18, gy1, -0.15, BLACK, dk)
		end
		Bx(m, frame, "Sill", 1.2, gy0 - 0.45, -0.525, w - 1.2, gy0, 0, trimW, dk)
		Bx(m, frame, "GoldBand", 0, h - 0.9, -0.18, w, h - 0.525, 0, GOLD, dk)
		Bx(m, frame, "Cornice", -0.075, h, -0.675, w + 0.075, h + 0.75, 2.025, trimW, dk)
		Bx(m, frame, "Divider", w - 0.375, WALK, -0.21, w, h, 0, trimW, dk)
		Bx(m, frame, "Planter", 1.95, WALK, -2.25, 3.75, 1.95, -0.45, BLACK, { studs = true })
		newPart(m, "Topiary", frame * CFrame.new(2.85, 2.925, -1.35), Vector3.new(1.95, 1.95, 1.95), rgb(48, 116, 58), { shape = BALL, decor = true })
	end
	local goldSign = { signBg = GOLD, signText = BLACK, signStroke = GOLD }
	local function st(wall, h, text, gs)
		local o = { wall = wall, h = h, text = text }
		if gs then for k, v in goldSign do o[k] = v end end
		return o
	end
	-- 3 boutiques entre l'arche et le magasin (x 369.6..412), 4 après lui (x 472..528.5, avant l'arche 5)
	local styles = {
		N = { st(rgb(244, 242, 236), 25.5, "COUTURE"), st(rgb(238, 226, 200), 23.25, "PERFUME", true), st(rgb(240, 236, 226), 27, "HATS"),
			st(rgb(246, 236, 232), 27.75, "EYEWEAR"), st(rgb(236, 230, 214), 24.75, "LEATHER GOODS"), st(rgb(246, 214, 214), 28.5, "FLORIST", true),
			st(rgb(236, 222, 206), 24, "CHOCOLATES") },
		S = { st(rgb(238, 226, 200), 24.75, "COFFEE"), st(rgb(244, 242, 236), 27, "SHOES", true), st(rgb(246, 236, 232), 25.5, "FASHION"),
			st(rgb(200, 232, 220), 23.25, "SURF"), st(rgb(246, 236, 232), 26.25, "HAIR SALON"), st(rgb(250, 216, 192), 28.5, "JUICE BAR", true),
			st(rgb(204, 236, 226), 24, "DINER") },
	}
	for tag, list in styles do
		local s = (tag == "N") and 1 or -1
		local idx = 0
		for _, seg in { { 369.6, 412, 3 }, { 472, 528.5, 4 } } do
			local w = (seg[2] - seg[1]) / seg[3]
			for k = 0, seg[3] - 1 do
				idx += 1
				local x0, x1 = seg[1] + k * w, seg[1] + (k + 1) * w
				local frame = (s > 0) and CFrame.new(x0, 0, 29.8) or (CFrame.new(x1, 0, -29.8) * CFrame.Angles(0, math.pi, 0))
				boutique("Boutique_" .. tag .. idx, frame, w, list[idx])
			end
		end
	end

	-- Tours de verre de downtown derrière les murets, à côté des magasins (feux rouges d'aviation, flèche sur la
	-- plus haute)
	local Tw = folder("Skyline")
	local function tower(name, cx, cz, w, d, h, glassC, band, spire)
		local m = newModel(Tw, name)
		local fr = CFrame.new(cx, 0, cz)
		Bx(m, fr, "Core", -w / 2, 0, -d / 2, w / 2, h, d / 2, glassC, { mat = GLASS, decor = true, refl = 0.12 })
		for k = 1, math.floor((h - 3) / 12) do
			local y = k * 12
			Bx(m, fr, "Band_" .. k, -w / 2 - 0.225, y - 0.3, -d / 2 - 0.225, w / 2 + 0.225, y + 0.3, d / 2 + 0.225, band, { decor = true })
		end
		for i, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
			Bx(m, fr, "Column_" .. i, c[1] * w / 2 - 0.6, 0, c[2] * d / 2 - 0.6, c[1] * w / 2 + 0.6, h, c[2] * d / 2 + 0.6, band, { decor = true, studs = true })
		end
		Bx(m, fr, "Crown", -w / 2 + 2.25, h, -d / 2 + 2.25, w / 2 - 2.25, h + 4.5, d / 2 - 2.25, band, { decor = true, studs = true })
		Bx(m, fr, "RoofDeck", -w / 2 + 1.95, h + 4.5, -d / 2 + 1.95, w / 2 - 1.95, h + 4.95, d / 2 - 1.95, rgb(70, 72, 78), { decor = true })
		for i, c in { { -1, -1 }, { 1, 1 } } do
			local lx, lz = c[1] * (w / 2 - 3), c[2] * (d / 2 - 3)
			Bx(m, fr, "AviationLight_" .. i, lx - 0.375, h + 4.95, lz - 0.375, lx + 0.375, h + 5.7, lz + 0.375, red, { mat = NEON, decor = true, noShadow = true })
		end
		if spire then
			vcyl(m, "Spire", cx, h + 4.95, h + 4.95 + spire, cz, 0.75, rgb(200, 204, 210), { decor = true })
			newPart(m, "SpireLight", CFrame.new(cx, h + 5.4 + spire, cz), Vector3.new(0.9, 0.9, 0.9), red, { shape = BALL, mat = NEON, decor = true, noShadow = true })
		end
	end
	local function roundTower(name, cx, cz, dia, h, glassC)
		local m = newModel(Tw, name)
		local up = CFrame.Angles(0, 0, math.rad(90))
		newPart(m, "Core", CFrame.new(cx, h / 2, cz) * up, Vector3.new(h, dia, dia), glassC, { shape = CYL, mat = GLASS, decor = true, refl = 0.12 })
		for k = 1, math.floor((h - 3) / 12) do
			newPart(m, "Band_" .. k, CFrame.new(cx, k * 12, cz) * up, Vector3.new(0.6, dia + 0.45, dia + 0.45), bandC, { shape = CYL, decor = true })
		end
		newPart(m, "Crown", CFrame.new(cx, h + 2.25, cz) * up, Vector3.new(4.5, dia - 4.5, dia - 4.5), bandC, { shape = CYL, decor = true })
		newPart(m, "RoofDeck", CFrame.new(cx, h + 4.725, cz) * up, Vector3.new(0.45, dia - 3.9, dia - 3.9), rgb(70, 72, 78), { shape = CYL, decor = true })
		for i, dx in { -1, 1 } do
			Bx(m, W, "AviationLight_" .. i, cx + dx * 4.5 - 0.375, h + 4.95, cz - 0.375, cx + dx * 4.5 + 0.375, h + 5.7, cz + 0.375, red, { mat = NEON, decor = true, noShadow = true })
		end
	end
	tower("Tower_N1", 390, 62, 24, 24, 96, rgb(96, 140, 180), bandC)
	tower("Tower_N2", 490, 62, 21, 21, 123, rgb(70, 120, 130), bandC, 21)
	tower("Tower_N3", 517, 62, 16, 16, 72, rgb(120, 150, 170), bandC)
	roundTower("Tower_S1", 390, -62, 21, 81, rgb(110, 150, 190))
	tower("Tower_S2", 490, -62, 24, 24, 105, rgb(150, 128, 92), rgb(70, 60, 50))
	roundTower("Tower_S4", 517, -62, 15, 66, rgb(130, 160, 196))

	-- Panneaux publicitaires sur pieds, au-dessus des boutiques (textes inventés, aucune marque)
	local Bb = folder("Billboards")
	local function billboard(name, x0, x1, zf, s, y0, y1, text, c1, c2, strokeC)
		-- s = -1 : affiche tournée vers -Z (côté nord) ; s = 1 : vers +Z (côté sud)
		local m = newModel(Bb, name)
		local steel, dark = rgb(90, 94, 100), rgb(34, 36, 40)
		Bx(m, W, "Backing", x0 - 0.45, y0 - 0.45, zf - s * 0.15, x1 + 0.45, y1 + 0.45, zf - s * 0.675, dark, { decor = true })
		local panel = Bx(m, W, "Panel", x0, y0, zf, x1, y1, zf - s * 0.15, rgb(255, 255, 255), { decor = true })
		for i, x in { x0 + 4.5, x1 - 4.5 } do
			Bx(m, W, "Leg_" .. i, x - 0.525, 0, zf - s * 0.675, x + 0.525, y0 - 0.45, zf - s * 1.725, steel, { decor = true, studs = true })
		end
		Bx(m, W, "Catwalk", x0, y0 - 0.75, zf + s * 1.95, x1, y0 - 0.45, zf - s * 0.675, steel, { decor = true })
		for i = 1, 3 do
			local x = x0 + (x1 - x0) * i / 4
			Bx(m, W, "Spot_" .. i, x - 0.45, y0 - 0.45, zf + s * 1.8, x + 0.45, y0, zf + s * 1.35, rgb(255, 240, 210), { mat = NEON, decor = true, noShadow = true })
		end
		local g = Instance.new("SurfaceGui"); g.Name = "AdGui"; g.Face = (s < 0) and Enum.NormalId.Front or Enum.NormalId.Back
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = 20; g.LightInfluence = 0
		local bg = Instance.new("Frame"); bg.Name = "Background"; bg.Size = UDim2.fromScale(1, 1); bg.BorderSizePixel = 0; bg.BackgroundColor3 = Color3.new(1, 1, 1); bg.Parent = g
		local grad = Instance.new("UIGradient"); grad.Color = ColorSequence.new(c1, c2); grad.Rotation = 90; grad.Parent = bg
		local t = Instance.new("TextLabel"); t.Name = "Label"; t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(1, 1)
		t.Text = text; t.TextScaled = true; t.TextColor3 = rgb(255, 255, 255)
		t.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
		local stroke = Instance.new("UIStroke"); stroke.Color = strokeC; stroke.Thickness = 4; stroke.LineJoinMode = Enum.LineJoinMode.Round; stroke.Parent = t
		local pad = Instance.new("UIPadding"); pad.PaddingTop = UDim.new(0.12, 0); pad.PaddingBottom = UDim.new(0.12, 0)
		pad.PaddingLeft = UDim.new(0.05, 0); pad.PaddingRight = UDim.new(0.05, 0); pad.Parent = t
		t.Parent = bg
		g.Parent = panel
	end
	billboard("Billboard_N", 376, 406, 38.25, -1, 31.5, 43.5, "WHO STEALS AN EGG\nSTEALS A DIAMOND EGG", rgb(255, 150, 60), rgb(220, 60, 140), rgb(90, 20, 70))
	billboard("Billboard_S", 486, 516, -38.25, 1, 31.5, 43.5, "IT'S HEIST\nO'CLOCK", rgb(40, 190, 210), rgb(30, 40, 110), rgb(10, 20, 60))

	-- Entrée de la zone (arche x = 368) : couronne « LOS ANGELES » au-dessus de l'arche, sur ses propres poteaux
	-- derrière les murets (l'arche reste intacte et son panneau visible), étoiles dorées au néon sur les poteaux,
	-- deux projecteurs d'avant-première dont les faisceaux se croisent au-dessus de l'entrée.
	local En = folder("Entrance")
	local mkEn = function(name, cf, size, color, opt) return newPart(En, name, cf, size, color, opt) end
	for _, s in { 1, -1 } do
		local tag = s > 0 and "N" or "S"
		Bx(En, W, "CrownPost_" .. tag, 370, 0, s * 32, 372, 46.5, s * 35, BLACK, { decor = true, studs = true })
		Bx(En, W, "CrownPostCap_" .. tag, 369.8, 46.5, s * 31.8, 372.2, 47.1, s * 35.2, GOLD, { decor = true })
		star(mkEn, "CrownStar_" .. tag .. "_", Vector3.new(371, 50.55, s * 33.5), Vector3.xAxis, Vector3.yAxis, 4.2, 0.6, rgb(255, 204, 72), NEON)
	end
	local crown = Bx(En, W, "CrownSign", 370.4, 38, -35, 371.6, 45, 35, BLACK, { decor = true })
	textLabel(crown, Enum.NormalId.Left, "LOS ANGELES", GOLD, 20, rgb(60, 40, 10))
	textLabel(crown, Enum.NormalId.Right, "LOS ANGELES", GOLD, 20, rgb(60, 40, 10))
	for i, y in { 37.55, 45 } do
		Bx(En, W, "CrownNeon_" .. i, 370.2, y, -35.2, 371.8, y + 0.45, 35.2, rgb(255, 226, 170), { mat = NEON, decor = true, noShadow = true })
	end
	-- faisceaux penchés vers la zone 4 (jamais au-dessus des immeubles de la zone 3) : ils se croisent au-dessus de
	-- l'avenue, juste derrière la couronne (x 394, y 66), et finissent au-dessus du quartier (|z| < 140)
	searchlight(En, "Searchlight_N", Vector3.new(384.5, WALK, 26), Vector3.new(0.15, 1, -0.42).Unit, 420)
	searchlight(En, "Searchlight_S", Vector3.new(383.5, WALK, -26), Vector3.new(0.15, 1, 0.42).Unit, 420)

	-- Ambiance : poussière dorée en suspension au-dessus de l'avenue, reflets de soleil à l'entrée (débit modéré)
	local Fx = folder("Ambience")
	local dust = fxBox(Fx, "FX_Z4_GoldenDust", CFrame.new(449, 9.5, 0), Vector3.new(160, 17, 58))
	emitter(dust, "GoldenDust", {
		color = ColorSequence.new(rgb(255, 226, 150), rgb(255, 182, 96)), emission = 0.7, bright = 1.4,
		size = ns({ { 0, 0 }, { 0.2, 0.42 }, { 0.8, 0.42 }, { 1, 0 } }),
		transp = ns({ { 0, 1 }, { 0.25, 0.3 }, { 0.75, 0.4 }, { 1, 1 } }),
		life = NumberRange.new(6, 9), rate = 26, speed = NumberRange.new(0.3, 0.9),
		accel = Vector3.new(0, 0.1, 0), drag = 0.4, rot = NumberRange.new(-40, 40),
	})
	local glints = fxBox(Fx, "FX_Z4_EntryGlints", CFrame.new(377, 20, 0), Vector3.new(14, 34, 66))
	emitter(glints, "SunGlints", {
		color = ColorSequence.new(rgb(255, 255, 240), rgb(255, 214, 120)), emission = 1, bright = 2,
		size = ns({ { 0, 0 }, { 0.5, 0.9 }, { 1, 0 } }),
		transp = ns({ { 0, 1 }, { 0.45, 0 }, { 1, 1 } }),
		life = NumberRange.new(1.2, 2.2), rate = 7, speed = NumberRange.new(0, 0),
		accel = Vector3.zero, drag = 0, rot = NumberRange.new(-120, 120),
	})
end
task.wait()

-- 6) Quartier autour des magasins : Map/Zone_4/District_LosAngeles. Sol de |z| 62.5 (fin du greybox) à 140,
--    découpé autour des magasins ; derrière la bijouterie, la Star Tower, repère de la zone visible de loin
--    (double étoile dorée au néon, couronne, 4 projecteurs vers le ciel) ; derrière l'horlogerie, une tour
--    d'hôtel à enseigne ; à côté, immeuble « streamline », hôtel à piscine sur le toit, bungalows à piscine,
--    studio de cinéma ; palmiers. Tout en décor (personne n'y va : les murets et les magasins ferment la rue).
do
	local Z = zoneFolder
	local old = Z:FindFirstChild("District_LosAngeles"); if old then old:Destroy() end
	local Dz = Instance.new("Folder"); Dz.Name = "District_LosAngeles"; Dz.Parent = Z
	local function folder(name) local f = Instance.new("Model"); f.Name = name; f.Parent = Dz; return f end
	local lawnC, lotC, water = rgb(118, 168, 78), rgb(84, 74, 88), rgb(64, 200, 226)

	local Gd = folder("Ground")
	for _, s in { 1, -1 } do
		local tag = s > 0 and "N" or "S"
		Bx(Gd, W, "Ground_" .. tag .. "_West", 368, -2, s * 62.5, 412, 0, s * 140, SAND, { studs = true })
		Bx(Gd, W, "Ground_" .. tag .. "_East", 472, -2, s * 62.5, 530, 0, s * 140, SAND, { studs = true })
		Bx(Gd, W, "Ground_" .. tag .. "_Back", 412, -2, s * 102, 472, 0, s * 140, SAND, { studs = true })
		Bx(Gd, W, "Lawn_" .. tag .. "_Back", 413, 0, s * 103, 471, 0.1, s * 139, lawnC, { studs = true, decor = true, noShadow = true })
	end
	Bx(Gd, W, "Lawn_N_West", 369, 0, 76, 411, 0.1, 139, lawnC, { studs = true, decor = true, noShadow = true })
	Bx(Gd, W, "Lawn_S_West", 369, 0, -139, 411, 0.1, -76, lawnC, { studs = true, decor = true, noShadow = true })
	Bx(Gd, W, "Lot_S_East", 473, 0, -139, 529, 0.08, -77, lotC, { studs = true, decor = true, noShadow = true })

	local Bd = folder("Buildings")
	-- Immeuble « streamline » : fenêtres en bandeaux (verre en retrait, allèges pleines tous les 6 studs)
	local function midrise(name, x0, x1, z0, z1, h, wallC, glassC, trimC)
		local m = newModel(Bd, name)
		Bx(m, W, "Glass", x0 + 0.5, 0, z0 + 0.5, x1 - 0.5, h, z1 - 0.5, glassC, { mat = GLASS, decor = true, refl = 0.08 })
		for k = 0, math.floor(h / 6) - 1 do
			Bx(m, W, "Spandrel_" .. (k + 1), x0, k * 6, z0, x1, k * 6 + 2.6, z1, wallC, { decor = true, studs = true })
		end
		Bx(m, W, "Roof", x0, h, z0, x1, h + 0.6, z1, wallC, { decor = true, studs = true })
		Bx(m, W, "Cornice", x0 - 0.45, h - 0.4, z0 - 0.45, x1 + 0.45, h + 0.2, z1 + 0.45, trimC, { decor = true })
		for i, w in { { x0, z0, x1, z0 + 0.6 }, { x0, z1 - 0.6, x1, z1 }, { x0, z0, x0 + 0.6, z1 }, { x1 - 0.6, z0, x1, z1 } } do
			Bx(m, W, "Parapet_" .. i, w[1], h + 0.6, w[2], w[3], h + 1.8, w[4], wallC, { decor = true })
		end
		return m
	end
	midrise("Apartments_N", 375, 405, 84, 134, 42, rgb(240, 186, 176), rgb(80, 112, 136), rgb(250, 248, 242))
	local hotel = midrise("Hotel_N", 479, 523, 82, 136, 60, rgb(244, 236, 220), rgb(60, 96, 128), GOLD)
	Bx(hotel, W, "PoolCoping", 489, 60.6, 98, 513, 60.75, 122, rgb(250, 250, 246), { decor = true })
	Bx(hotel, W, "PoolWater", 490, 60.75, 99, 512, 60.85, 121, water, { decor = true, refl = 0.25, noShadow = true })
	for i = 0, 3 do
		Bx(hotel, W, "Lounger_" .. (i + 1), 483, 60.6, 101 + i * 5, 485.5, 61.3, 104 + i * 5, rgb(250, 250, 246), { decor = true })
	end

	-- Star Tower, le repère de la zone : socle de pierre, fût de verre bleu nuit à bandeaux de pierre et ailerons
	-- dorés, gradin, couronne dorée cerclée de néon, flèche, double étoile dorée (de face depuis le couloir comme
	-- depuis la rue) et 4 projecteurs dont les faisceaux montent dans le ciel
	do
		local m = newModel(Bd, "StarTower")
		local stone, glassT, goldT = rgb(236, 228, 210), rgb(52, 74, 104), rgb(222, 180, 70)
		Bx(m, W, "Podium", 420, 0, 106, 464, 12, 138, stone, { decor = true, studs = true })
		Bx(m, W, "PodiumBand", 419.6, 11.2, 105.6, 464.4, 12.6, 138.4, goldT, { decor = true })
		Bx(m, W, "Shaft", 428, 12.6, 108, 456, 150, 136, glassT, { mat = GLASS, decor = true, refl = 0.15 })
		for k = 1, 11 do
			local y = 12 + k * 12
			Bx(m, W, "Band_" .. k, 427.7, y - 0.35, 107.7, 456.3, y + 0.35, 136.3, stone, { decor = true })
		end
		for i, c in { { 428, 108 }, { 456, 108 }, { 428, 136 }, { 456, 136 } } do
			Bx(m, W, "Fin_" .. i, c[1] - 0.8, 12.6, c[2] - 0.8, c[1] + 0.8, 151, c[2] + 0.8, goldT, { decor = true })
		end
		Bx(m, W, "Setback", 431, 150, 111, 453, 168, 133, glassT, { mat = GLASS, decor = true, refl = 0.15 })
		Bx(m, W, "SetbackBand_1", 430.6, 149.6, 110.6, 453.4, 151, 133.4, goldT, { decor = true })
		Bx(m, W, "SetbackBand_2", 430.7, 158.7, 110.7, 453.3, 159.4, 133.3, stone, { decor = true })
		Bx(m, W, "SetbackRoof", 430.5, 168, 110.5, 453.5, 169, 133.5, stone, { decor = true, studs = true })
		Bx(m, W, "Crown", 434.5, 169, 114.5, 449.5, 181, 129.5, goldT, { decor = true, refl = 0.2 })
		Bx(m, W, "CrownNeon", 434.2, 176.5, 114.2, 449.8, 177.5, 129.8, rgb(255, 222, 150), { mat = NEON, decor = true, noShadow = true })
		vcyl(m, "Spire", 442, 181, 202, 122, 1.2, goldT, { decor = true })
		local mk = function(name, cf, size, color, opt) return newPart(m, name, cf, size, color, opt) end
		local sc = Vector3.new(442, 204, 122)
		star(mk, "StarX_", sc, Vector3.xAxis, Vector3.yAxis, 10, 1, rgb(255, 204, 72), NEON)
		star(mk, "StarZ_", sc, Vector3.zAxis, Vector3.yAxis, 10, 1, rgb(255, 204, 72), NEON)
		local pl = Instance.new("PointLight"); pl.Color = rgb(255, 210, 120); pl.Range = 40; pl.Brightness = 1.5; pl.Shadows = false
		pl.Parent = m:FindFirstChild("StarX_Core")
		for i, c in { { 434.5, 114.5 }, { 449.5, 129.5 }, { 434.5, 129.5 }, { 449.5, 114.5 } } do
			Bx(m, W, "AviationLight_" .. i, c[1] - 0.4, 181, c[2] - 0.4, c[1] + 0.4, 181.8, c[2] + 0.4, red, { mat = NEON, decor = true, noShadow = true })
		end
		for i, c in { { 432.5, 112.5, -1, -1 }, { 451.5, 112.5, 1, -1 }, { 432.5, 131.5, -1, 1 }, { 451.5, 131.5, 1, 1 } } do
			searchlight(m, "Searchlight_" .. i, Vector3.new(c[1], 169, c[2]), Vector3.new(c[3] * 0.34, 1, c[4] * 0.34).Unit, 520)
		end
	end

	-- Tour d'hôtel derrière l'horlogerie : verre bronze, bandeaux crème, enseigne « GRAND HOTEL » tournée vers la
	-- rue (au-dessus de l'horlogerie), héliport
	do
		local m = newModel(Bd, "Tower_S3")
		local bronze, creamT = rgb(96, 80, 64), rgb(236, 226, 206)
		Bx(m, W, "Podium", 420, 0, -138, 464, 10, -106, creamT, { decor = true, studs = true })
		Bx(m, W, "Core", 428, 10, -136, 456, 135, -108, bronze, { mat = GLASS, decor = true, refl = 0.12 })
		for k = 1, 10 do
			local y = 10 + k * 12
			Bx(m, W, "Band_" .. k, 427.7, y - 0.3, -136.3, 456.3, y + 0.3, -107.7, creamT, { decor = true })
		end
		for i, c in { { 428, -136 }, { 456, -136 }, { 428, -108 }, { 456, -108 } } do
			Bx(m, W, "Column_" .. i, c[1] - 0.7, 10, c[2] - 0.7, c[1] + 0.7, 135, c[2] + 0.7, creamT, { decor = true, studs = true })
		end
		Bx(m, W, "Roof", 427.5, 135, -136.5, 456.5, 136, -107.5, creamT, { decor = true, studs = true })
		local sf = Bx(m, W, "SignFrame", 431, 136, -109.2, 453, 145, -108.4, rgb(30, 30, 34), { decor = true })
		textLabel(sf, Enum.NormalId.Back, "GRAND HOTEL", rgb(255, 96, 84), 20, rgb(90, 10, 10))
		for i, x in { 433, 451 } do
			Bx(m, W, "SignLeg_" .. i, x - 0.3, 136, -110.6, x + 0.3, 144, -109.2, rgb(90, 94, 100), { decor = true })
		end
		newPart(m, "Helipad", CFrame.new(442, 136.15, -124) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(0.3, 16, 16), rgb(70, 72, 78), { shape = CYL, decor = true })
		local hm = Bx(m, W, "HelipadMark", 437.5, 136.3, -128.5, 446.5, 136.35, -119.5, rgb(70, 72, 78), { decor = true, noShadow = true })
		textLabel(hm, Enum.NormalId.Top, "H", rgb(255, 255, 255), 20, rgb(70, 72, 78))
		for i, c in { { 428, -136 }, { 456, -108 } } do
			Bx(m, W, "AviationLight_" .. i, c[1] - 0.4, 136, c[2] - 0.4, c[1] + 0.4, 136.8, c[2] + 0.4, red, { mat = NEON, decor = true, noShadow = true })
		end
	end

	-- Bungalows à piscine (côté ouest, derrière la tour ronde)
	local function bungalow(name, x0, x1, z0, z1, pz0, pz1)
		local m = newModel(Bd, name)
		Bx(m, W, "Body", x0, 0, z0, x1, 7.5, z1, rgb(246, 244, 238), { decor = true, studs = true })
		Bx(m, W, "Roof", x0 - 1.5, 7.5, z0 - 1.5, x1 + 1.5, 8.4, z1 + 1.5, rgb(206, 200, 190), { decor = true, studs = true })
		Bx(m, W, "Chimney", x1 - 4, 8.4, z0 + 2, x1 - 2.5, 11, z0 + 3.5, rgb(150, 110, 84), { decor = true, studs = true })
		local north = pz0 >= z1
		local fz, out = north and z1 or z0, north and 1 or -1
		Bx(m, W, "Window", x0 + 2, 2, fz, x1 - 6, 6.2, fz + out * 0.08, rgb(80, 112, 136), { mat = GLASS, decor = true })
		Bx(m, W, "Door", x1 - 4.5, 0, fz, x1 - 2.5, 6.4, fz + out * 0.08, rgb(206, 120, 70), { decor = true })
		Bx(m, W, "PoolDeck", x0 - 1, 0, pz0, x1 + 1, 0.3, pz1, rgb(242, 238, 230), { decor = true, studs = true })
		Bx(m, W, "PoolWater", x0 + 2, 0.3, pz0 + 1.5, x1 - 2, 0.36, pz1 - 1.5, water, { decor = true, refl = 0.25, noShadow = true })
	end
	bungalow("Bungalow_S1", 377, 397, -96, -84, -110, -99)
	bungalow("Bungalow_S2", 377, 397, -134, -122, -121, -112.5)

	-- Studio de cinéma (côté est, derrière la tour bronze) : grand hangar beige à toit à deux pentes
	do
		local m = newModel(Bd, "SoundStage_S")
		local beige = rgb(226, 210, 180)
		Bx(m, W, "Hall", 480, 0, -134, 522, 28, -84, beige, { decor = true, studs = true })
		newPart(m, "RoofWest", CFrame.new(490.5, 30.5, -109) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(50, 5, 21), rgb(196, 184, 160), { shape = WEDGE, decor = true, studs = true })
		newPart(m, "RoofEast", CFrame.new(511.5, 30.5, -109) * CFrame.Angles(0, math.rad(-90), 0), Vector3.new(50, 5, 21), rgb(196, 184, 160), { shape = WEDGE, decor = true, studs = true })
		Bx(m, W, "StageDoor", 492, 0, -84, 510, 20, -83.9, rgb(70, 72, 78), { decor = true })
		local band = Bx(m, W, "StageSign", 486, 21.5, -84, 516, 26.5, -83.9, rgb(168, 40, 36), { decor = true })
		textLabel(band, Enum.NormalId.Back, "STUDIO B", rgb(255, 255, 255), 20, rgb(110, 20, 20))
	end

	-- Palmiers du quartier (décor, sans collision), jamais à moins de 10 studs des bords de la zone
	local Pb = folder("Palms")
	for i, sp in { { 384, 79, 33 }, { 515.5, 77.5, 36 }, { 416, 104.5, 30 }, { 468, 104.5, 34 },
		{ 408, -105.5, 31 }, { 407, -129, 34 }, { 515.5, -79, 36 }, { 416, -104.5, 30 }, { 468, -104.5, 33 },
		{ 400, 79.5, 30 }, { 482, -79, 33 } } do
		local m = newModel(Pb, "Palm_B" .. i)
		palm(function(name, cf, size, color, opt) return newPart(m, name, cf, size, color, opt) end,
			CFrame.new(sp[1], 0.1, sp[2]), sp[3], K, i * 0.9, false, K)
	end
end
task.wait()

-- 7) Vérification en mode Edit : contrat 10.4, tag, attribut, échelle, aucun script, colis dégagés, chaussée
--    libre, emprise de la zone, greybox, chemins du vigile (réglages de GuardService) de GuardSpawn vers les
--    10 emplacements, puis vers la rue en coupant les collisions de la vitre le temps du test.
local report = {}
do
	local PFS = game:GetService("PathfindingService")
	local CS = game:GetService("CollectionService")
	local CONTRACT = { "Window", "WindowFractured", "Shutter", "Door", "Bounds", "GuardSpawn", "SignPart", "InfoPoint" }
	for i = 1, 10 do table.insert(CONTRACT, string.format("ShelfSlot_%02d", i)) end
	local BOX = { Standard = Vector3.new(1.64, 1.04, 1.17), Premium = Vector3.new(1.79, 1.19, 1.31), Luxe = Vector3.new(1.94, 1.39, 1.51) }
	local function aabb(cf, size)
		local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
		local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
		local e = Vector3.new(math.abs(r.X) * hx + math.abs(u.X) * hy + math.abs(l.X) * hz,
			math.abs(r.Y) * hx + math.abs(u.Y) * hy + math.abs(l.Y) * hz,
			math.abs(r.Z) * hx + math.abs(u.Z) * hy + math.abs(l.Z) * hz)
		return cf.Position - e, cf.Position + e
	end
	local function overlap(a0, a1, b0, b1)
		return a0.X < b1.X - 1e-3 and b0.X < a1.X - 1e-3 and a0.Y < b1.Y - 1e-3 and b0.Y < a1.Y - 1e-3 and a0.Z < b1.Z - 1e-3 and b0.Z < a1.Z - 1e-3
	end
	for _, nm in { "STORE_Z4_Bijouterie", "STORE_Z4_Horlogerie" } do
		local m = zoneFolder:FindFirstChild(nm)
		local seen, parts, scripts = {}, 0, 0
		for _, d in m:GetDescendants() do
			if table.find(CONTRACT, d.Name) then seen[d.Name] = (seen[d.Name] or 0) + 1 end
			if d:IsA("BasePart") then parts += 1 end
			if d:IsA("LuaSourceContainer") then scripts += 1 end
		end
		local bad = {}
		for _, n in CONTRACT do if seen[n] ~= 1 then table.insert(bad, n .. "×" .. (seen[n] or 0)) end end
		local wf = m:FindFirstChild("WindowFractured")
		local shards = 0
		for i = 1, 40 do if wf and wf:FindFirstChild(string.format("Shard_%02d", i), true) then shards += 1 end end
		local tiers, slots = { Standard = 0, Premium = 0, Luxe = 0 }, {}
		for i = 1, 10 do
			local a = m:FindFirstChild(string.format("ShelfSlot_%02d", i), true)
			if a and a:IsA("Attachment") then
				local t = a:GetAttribute("Tier")
				if tiers[t] then tiers[t] += 1 end
				table.insert(slots, a)
			else
				table.insert(bad, string.format("ShelfSlot_%02d pas Attachment", i))
			end
		end
		local bounds = m:FindFirstChild("Bounds")
		local gs = m:FindFirstChild("GuardSpawn", true)
		if not (wf and wf:IsA("Model")) then table.insert(bad, "WindowFractured pas Model") end
		if not (bounds and bounds:IsA("BasePart") and bounds.Transparency == 1) then table.insert(bad, "Bounds") end
		if not (gs and gs:IsA("Attachment")) then table.insert(bad, "GuardSpawn pas Attachment") end
		-- colis dégagés : aucune pièce (hors planche porteuse) dans le volume du colis posé sur son ShelfSlot
		local blocked = {}
		for _, a in slots do
			local size = BOX[a:GetAttribute("Tier")] or BOX.Luxe
			local b0, b1 = aabb(a.WorldCFrame * CFrame.new(0, size.Y / 2 + 0.02, 0), size - Vector3.new(0, 0.04, 0))
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") and d ~= a.Parent and d ~= bounds and not d:IsDescendantOf(wf) then
					local p0, p1 = aabb(d.CFrame, d.Size)
					if overlap(b0, b1, p0, p1) then table.insert(blocked, a.Name .. "/" .. d.Name) end
				end
			end
		end
		-- chemins du vigile
		local path = PFS:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, AgentCanClimb = false, WaypointSpacing = 4 })
		local start = gs.WorldPosition
		local okN, fails, jumps = 0, {}, 0
		for _, a in slots do
			local look = a.WorldCFrame.LookVector
			local goal = a.WorldPosition + Vector3.new(look.X, 0, look.Z).Unit * 4.5   -- dans l'allée, devant le colis
			goal = Vector3.new(goal.X, start.Y, goal.Z)
			local ok, err = pcall(function() path:ComputeAsync(start, goal) end)
			if ok and path.Status == Enum.PathStatus.Success then
				okN += 1
				for _, w in path:GetWaypoints() do if w.Action == Enum.PathWaypointAction.Jump then jumps += 1 end end
			else
				table.insert(fails, a.Name .. "=" .. tostring(ok and path.Status.Name or err))
			end
		end
		local win = m:FindFirstChild("Window")
		local was = win.CanCollide
		win.CanCollide = false
		task.wait(0.5)
		local street = (m:GetPivot() * CFrame.new(0, 0.5, -51)).Position   -- sur la chaussée, à 15 studs de la façade
		local ok, err = pcall(function() path:ComputeAsync(start, street) end)
		local streetOk = ok and path.Status == Enum.PathStatus.Success
		local streetInfo = streetOk and (#path:GetWaypoints() .. " points") or tostring(ok and path.Status.Name or err)
		win.CanCollide = was
		task.wait(0.3)
		local ok2 = pcall(function() path:ComputeAsync(start, street) end)
		local closedInfo = ok2 and path.Status.Name or "erreur"
		local pv = m:GetPivot()
		table.insert(report, string.format("%s : échelle %.2f, pivot (%.0f, %.0f, %.0f), contrat %s, %d éclats, Tier %d/%d/%d, NPCStore %s, Zone %s, %d script ; colis gênés : %s ; chemins rayons %d/10%s (%d sauts) ; rue vitre ouverte %s (%s), vitre fermée %s ; %d pièces",
			nm, m:GetScale(), pv.X, pv.Y, pv.Z, #bad == 0 and "OK" or table.concat(bad, ","), shards, tiers.Standard, tiers.Premium, tiers.Luxe,
			tostring(CS:HasTag(m, "NPCStore")), tostring(m:GetAttribute("Zone")), scripts,
			#blocked == 0 and "aucun" or table.concat(blocked, ","), okN, #fails > 0 and (" " .. table.concat(fails, ",")) or "",
			jumps, streetOk and "OK" or "ÉCHEC", streetInfo, closedInfo, parts))
	end
	-- chaussée libre jusqu'à 18 studs de haut (les palmes la survolent plus haut, sans collision ; la couronne de
	-- l'entrée passe à 37,5 studs)
	local onRoad = {}
	for _, h in workspace:GetPartBoundsInBox(CFrame.new(449, 9.1, 0), Vector3.new(162, 18, 44.9), OverlapParams.new()) do
		if h:IsDescendantOf(zoneFolder) and not CS:HasTag(h, "TruckSpawn") then table.insert(onRoad, h:GetFullName()) end
	end
	-- emprise : rien hors de x 368..530 ni au-delà de |z| = 140
	local outside, top, topName = {}, 0, ""
	local nStreet, nDistrict, scriptsMap, emitters, rate = 0, 0, 0, 0, 0
	for _, d in zoneFolder:GetDescendants() do
		if d:IsA("BasePart") then
			local p0, p1 = aabb(d.CFrame, d.Size)
			if p0.X < 367.9 or p1.X > 530.1 or p0.Z < -140.1 or p1.Z > 140.1 then table.insert(outside, d:GetFullName()) end
			if p1.Y > top then top, topName = p1.Y, d.Name end
			if d:IsDescendantOf(zoneFolder.Street_LosAngeles) then nStreet += 1 elseif d:IsDescendantOf(zoneFolder.District_LosAngeles) then nDistrict += 1 end
		end
		if d:IsA("LuaSourceContainer") then scriptsMap += 1 end
		if d:IsA("ParticleEmitter") then emitters += 1; rate += d.Rate end
	end
	-- sols ajoutés (trottoirs, sol du quartier) : aucun chevauchement avec le greybox de la zone
	local gb = workspace.Greybox.Corridor.Zone_4
	local clash = {}
	local mine = {}
	for _, d in zoneFolder.District_LosAngeles.Ground:GetChildren() do table.insert(mine, d) end
	for _, d in zoneFolder.Street_LosAngeles.Ground:GetChildren() do table.insert(mine, d) end
	for _, d in mine do
		if d:IsA("BasePart") then
			local a0, a1 = aabb(d.CFrame, d.Size)
			for _, q in gb:GetDescendants() do
				if q:IsA("BasePart") then
					local b0, b1 = aabb(q.CFrame, q.Size)
					if overlap(a0, a1, b0, b1) then table.insert(clash, d.Name .. "/" .. q.Name) end
				end
			end
		end
	end
	local gg = gb.Ground
	local gate = gb.ZoneGate_4
	local gcf, gsz = gate:GetBoundingBox()
	local function zr(p) return string.format("%.2f..%.2f", p.Position.Z - p.Size.Z / 2, p.Position.Z + p.Size.Z / 2) end
	local function xr(p) return string.format("%.1f..%.1f", p.Position.X - p.Size.X / 2, p.Position.X + p.Size.X / 2) end
	table.insert(report, string.format("Greybox : Street z %s ; Side_N z %s ; Side_S z %s ; murets N1 x %s, N2 x %s, S1 x %s, S2 x %s, N z %s, S z %s, h %.0f ; arche échelle %.2f, base y %.2f, centre x %.2f z %.2f, %.1f × %.1f × %.1f, tag %s",
		zr(gg.Street), zr(gg.Side_N), zr(gg.Side_S), xr(gg.SideWall_N1), xr(gg.SideWall_N2), xr(gg.SideWall_S1), xr(gg.SideWall_S2),
		zr(gg.SideWall_N1), zr(gg.SideWall_S1), gg.SideWall_N1.Size.Y,
		gate:GetScale(), gcf.Y - gsz.Y / 2, gcf.X, gcf.Z, gsz.X, gsz.Y, gsz.Z, tostring(CS:HasTag(gate, "ZoneGate"))))
	local pa, pb, tsp = gb:FindFirstChild("NightPatrol_Z4_A"), gb:FindFirstChild("NightPatrol_Z4_B"), zoneFolder:FindFirstChild("TruckSpawn")
	local function xz(p) return p and string.format("x %.2f z %.2f", p.Position.X, p.Position.Z) or "absent" end
	table.insert(report, string.format("NightPatrol_Z4_A %s ; NightPatrol_Z4_B %s ; TruckSpawn %s", xz(pa), xz(pb), xz(tsp)))
	table.insert(report, string.format("Chaussée z -22.5..22.5 jusqu'à 18 studs : %s ; hors emprise : %s ; chevauchements avec le greybox : %s ; rue %d pièces, quartier %d pièces ; scripts dans Map/Zone_4 : %d ; émetteurs %d (%d particules/s) ; point le plus haut %.0f studs (%s) ; produits : bijouterie %d, horlogerie %d",
		#onRoad == 0 and "libre" or table.concat(onRoad, ", "), #outside == 0 and "rien" or table.concat(outside, ", "),
		#clash == 0 and "aucun" or table.concat(clash, ", "), nStreet, nDistrict, scriptsMap, emitters, rate, top, topName, bijN, horN))
	-- lampadaires de nuit (L-043) : tag NightLight sur des pièces livrées éteintes (pas de Neon, lumières coupées)
	local lamps, lampNeon, lampLit = 0, 0, 0
	for _, inst in CS:GetTagged("NightLight") do
		if inst:IsDescendantOf(zoneFolder) and inst:IsA("BasePart") then
			lamps += 1
			if inst.Material == Enum.Material.Neon then lampNeon += 1 end
			for _, d in inst:GetDescendants() do if d:IsA("Light") and d.Enabled then lampLit += 1 end end
		end
	end
	table.insert(report, string.format("Lampadaires NightLight : %d, en Neon %d, lumières allumées %d", lamps, lampNeon, lampLit))
end

return table.concat(report, "\n")
