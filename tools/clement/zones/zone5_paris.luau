--!nocheck
-- Zone 5 — Paris (MOD-023) : galerie d'art, antiquaire et décor de rue.
-- À lancer dans Studio (MCP execute_luau, mode Edit), APRÈS tools/clement/store_builder.luau.
-- Relancer ce script reconstruit la zone 5 à l'identique : les modèles du même nom sont remplacés.
-- Suit le modèle de la zone 2 (tools/clement/zones/zone2_londres.luau) : une fonction « facade » (ici l'immeuble
-- haussmannien, qui habille aussi l'intérieur), une spec par magasin, le décor de rue dans Map/Zone_5/Street_Paris,
-- puis une vérification en mode Edit (contrat 10.4, chemins du vigile) dont le résultat est renvoyé.
-- Règles : aucun script laissé dans la map ; noms du contrat (10.4) jamais réutilisés pour le décor ;
-- aucune marque réelle sur les enseignes ni sur les produits.
-- Paris sous la neige (demande de Clément, 2026-11-07) : toits, trottoirs et chaussée enneigés, neige qui tombe
-- (ParticleEmitter, aucun script). SNOWY = false rend le quartier sans neige à la prochaine relance.
-- Textes visibles en anglais (consigne de Clément, 2026-11-07) ; « Café » reste, compris par un anglophone.
-- Gabarit commun du 2026-11-07 (tout faisait la taille d'un personnage) : échelle ×1.5 (SCALE), magasins à
-- (STORE_X, 0, ±66) avec spec.scale, couloir de 60 entre les façades (|z| 30), décor ×1.5, quartier jusqu'à |z| 140.
-- Zones allongées de ×1,25 (2026-11-08, pour courir plus longtemps) : x' = 30 + (x - 30) × 1,25 dans tout le couloir.

local rgb = Color3.fromRGB
local Store = _G.ClaudeStore
assert(Store, "charger d'abord tools/clement/store_builder.luau")

local SCALE = 1.5   -- gabarit 2026-11-07, le même pour toutes les zones
local ZONE_X0, ZONE_X1 = 530, 718   -- la zone 5 dans le couloir allongé (arche ZoneGate_5 à x = 530)
local STORE_X = 618                 -- milieu des deux magasins (emprise x 588..648)
local SNOWY = true
local SNOW = rgb(236, 242, 248)
local function snowy(snowColor, plainColor) return SNOWY and snowColor or plainColor end

local SERIF = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)
local IRON = rgb(30, 32, 34)            -- fer forgé
local GOLD = rgb(212, 176, 90)          -- lettres et filets dorés
local SAPIN = rgb(28, 74, 56)           -- vert sapin
local BORDEAUX = rgb(112, 30, 44)
local ZINC, ZINC_DARK = rgb(118, 126, 138), rgb(96, 102, 112)
local FRAME_WHITE = rgb(244, 240, 230)  -- menuiseries peintes
local GLASS_DARK = rgb(48, 60, 78)
local CREAM = rgb(246, 240, 222)

local function key(c) return string.format("%d,%d,%d", math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255)) end

-- Lettres à empattements (enseignes, panneaux) avec un contour fin.
local function serif(t, stroke)
	if not t then return nil end
	t.FontFace = SERIF
	local s = t:FindFirstChildOfClass("UIStroke")
	if s then s.Color = stroke or rgb(20, 20, 20); s.Thickness = 2 end
	return t
end

-- Intérieur : parquet à l'anglaise, tableaux et miroirs aux murs, têtes de gondole et coin du thème, cadres
-- derrière les tableaux des rayons, cadrans devant les horloges. Aucun nom du contrat n'est touché, ni les planches
-- qui portent les ShelfSlot ; tout ce qui est ajouté est sans collision, sauf le meuble du coin avant droit (hors allée).
-- spec.paris.interior = { planks, paintings, frameFor?, dialFor?, promoDecor, promoStroke?, corner?, fridge?, rug?, wallClock? }
local function parisInterior(ctx)
	local B, model, spec = ctx.B, ctx.model, ctx.spec
	local IN = spec.paris.interior
	local I = model:FindFirstChild("Interior")
	local A = ctx.group("Art")
	local flat = { parent = A, studs = false, decor = true, noShadow = true }

	-- Parquet : lames de 2 studs, joints décalés ; le sol sombre dessous (colors.floor) dessine les joints.
	local tiles = model:FindFirstChild("FloorTiles")
	if tiles then tiles:Destroy() end
	local PQ = ctx.group("Parquet")
	local nPlanks = 0
	for i = 0, 18 do
		local xa = -19 + i * 2
		local zs = -39 + (i * 5) % 16
		local seg = 0
		while zs < 23 do
			local za, zb = math.max(zs, -23), math.min(zs + 16, 23)
			if zb - za > 0.6 then
				seg += 1; nPlanks += 1
				B("Plank_" .. nPlanks, xa + 0.05, 0.35, za + 0.05, xa + 1.95, 0.37, zb - 0.05, IN.planks[(i + seg) % #IN.planks + 1], { parent = PQ, decor = true, noShadow = true })
			end
			zs += 16
		end
	end

	-- Tableaux et miroirs, à plat sur les murs. mur : L (x = -18,9), R (x = 18,9), B (fond, z = 22,9), F (devant, z = -23).
	local function onWall(nm, wall, a0, a1, b0, b1, d0, d1, color, opt)
		if wall == "L" then return B(nm, -18.9 + d0, b0, a0, -18.9 + d1, b1, a1, color, opt) end
		if wall == "R" then return B(nm, 18.9 - d1, b0, a0, 18.9 - d0, b1, a1, color, opt) end
		if wall == "B" then return B(nm, a0, b0, 22.9 - d1, a1, b1, 22.9 - d0, color, opt) end
		return B(nm, a0, b0, -23 + d0, a1, b1, -23 + d1, color, opt)
	end
	for i, p in IN.paintings do
		local wall, u0, u1, y0, y1, frameC, canvasC, motif = table.unpack(p)
		local nm, m = "Painting_" .. i, 0.2
		onWall(nm .. "_Frame", wall, u0, u1, y0, y1, 0, 0.12, frameC, flat)
		local canvasOpt = flat
		if motif == "mirror" then canvasOpt = { parent = A, studs = false, decor = true, noShadow = true, mat = Enum.Material.Glass } end
		onWall(nm .. "_Canvas", wall, u0 + m, u1 - m, y0 + m, y1 - m, 0.12, 0.16, canvasC, canvasOpt)
		if type(motif) == "table" then
			local a0, a1, b0, b1 = u0 + m, u1 - m, y0 + m, y1 - m
			local w, h = a1 - a0, b1 - b0
			local kind, c = motif[1], motif[2]
			if kind == "horizon" then
				onWall(nm .. "_Motif", wall, a0, a1, b0, b0 + h * 0.4, 0.16, 0.18, c, flat)
			elseif kind == "portrait" then
				onWall(nm .. "_Motif", wall, a0 + w * 0.3, a1 - w * 0.3, b0 + h * 0.3, b1 - h * 0.12, 0.16, 0.18, c, flat)
			else
				onWall(nm .. "_Motif", wall, a0 + w * 0.15, a0 + w * 0.6, b0 + h * 0.25, b1 - h * 0.2, 0.16, 0.18, c, flat)
			end
		end
	end
	if IN.wallClock then
		local cx, cy, r = IN.wallClock[1], IN.wallClock[2], IN.wallClock[3]
		local disc = { parent = A, studs = false, decor = true, noShadow = true, shape = Enum.PartType.Cylinder, rot = CFrame.Angles(0, math.rad(90), 0) }
		B("WallClock_Rim", cx - 0.07, cy - r, 22.83 - r, cx + 0.07, cy + r, 22.83 + r, GOLD, disc)
		B("WallClock_Face", cx - 0.03, cy - r * 0.86, 22.73 - r * 0.86, cx + 0.03, cy + r * 0.86, 22.73 + r * 0.86, CREAM, disc)
		B("WallClock_Minute", cx - 0.05, cy, 22.66, cx + 0.05, cy + r * 0.72, 22.7, IRON, flat)
		B("WallClock_Hour", cx, cy - 0.06, 22.66, cx + r * 0.48, cy + 0.06, 22.7, IRON, flat)
	end

	-- Têtes de gondole : les paquets de la supérette remplacés par des objets du thème ; coin avant droit.
	for _, g in { { "A", -9, -5 }, { "B", 5, 9 } } do
		for k = 0, 2 do
			local pk = I:FindFirstChild("PromoPack_" .. g[1] .. k)
			if pk then pk:Destroy() end
		end
		IN.promoDecor(B, A, g[1], g[2], g[3])
		local ps = I:FindFirstChild("PromoSign_" .. g[1])
		local gui = ps and ps:FindFirstChild("LabelGui_Front")
		serif(gui and gui:FindFirstChild("Label"), IN.promoStroke)
	end
	if IN.corner then IN.corner(B, A) end
	-- La réserve du constructeur est écrite « RÉSERVE » : en anglais dans ce quartier
	local rv = model:FindFirstChild("Reserve")
	local rs = rv and rv:FindFirstChild("ReserveSign")
	local rg = rs and rs:FindFirstChild("LabelGui_Front")
	local rl = rg and rg:FindFirstChild("Label")
	if rl then rl.Text = "STOCKROOM" end
	if IN.fridge then
		for _, d in I:GetChildren() do
			if d:IsA("BasePart") and d.Name ~= "Fridge_Header" and (d.Name:match("^Fridge_") or d.Name:match("^FridgeShelf_")) then d.Color = IN.fridge end
		end
	end
	if IN.rug then
		B("Rug_Border", -4.2, 0.37, -14.6, 4.2, 0.385, 8.6, IN.rug[2], { parent = A, studs = false, decor = true, noShadow = true, mat = Enum.Material.Fabric })
		B("Rug", -3.85, 0.385, -14.25, 3.85, 0.4, 8.25, IN.rug[1], { parent = A, studs = false, decor = true, noShadow = true, mat = Enum.Material.Fabric })
	end

	-- Produits : un cadre derrière chaque tableau, un cadran devant chaque horloge.
	local frameOf, dialOf = {}, {}
	for name, c in (IN.frameFor or {}) do frameOf[key(spec.designs[name].body)] = c end
	for name, c in (IN.dialFor or {}) do dialOf[key(spec.designs[name].body)] = c end
	local inv = ctx.ORIGIN:Inverse()
	local nf, nd = 0, 0
	for _, d in I:GetChildren() do
		if d:IsA("BasePart") and d.Name:match("^Shelf_.+_P%d+$") then
			local k = key(d.Color)
			local fc, dc = frameOf[k], dialOf[k]
			if fc or dc then
				local nm = d.Name
				local s = (nm:match("^Shelf_A_R") or nm:match("^Shelf_B_R") or nm:match("^Shelf_WallL")) and 1 or -1
				local c, sz = (inv * d.CFrame).Position, d.Size
				local xf = c.X + s * sz.X / 2   -- face tournée vers l'allée
				if fc then
					nf += 1
					B("ArtFrame_" .. nf, xf - s * 0.04, c.Y - sz.Y / 2 - 0.08, c.Z - sz.Z / 2 - 0.04, xf - s * (sz.X + 0.05), c.Y + sz.Y / 2 + 0.08, c.Z + sz.Z / 2 + 0.04, fc, { parent = I, studs = false, decor = true, noShadow = true })
				else
					nd += 1
					local f = math.min(sz.Y, sz.Z) * 0.55
					local yc = c.Y + sz.Y / 2 - f / 2 - 0.08
					B("ClockDial_" .. nd, xf, yc - f / 2, c.Z - f / 2, xf + s * 0.03, yc + f / 2, c.Z + f / 2, dc, { parent = I, studs = false, decor = true, noShadow = true })
				end
			end
		end
	end
end

-- Façade haussmannienne : devanture en bois peint (bandeau, corniche, caissons, panneau, lanternes) à lettres dorées,
-- pierre crème, balcon filant en fer forgé au 1er étage, garde-corps au 2e, corniche à modillons, balcon du dernier
-- étage, toit mansardé en zinc avec lucarnes à fronton cintré, souches de cheminée, enseigne drapeau, plaque de rue.
-- Le tout sans collision, sur un vrai volume derrière la façade (comme la zone 2). Puis l'intérieur (parisInterior).
-- spec.paris = { stone, trim, stoneDark, shop, zinc, zincDark, chimney, signStroke, panel, blade, plaque, interior }
local function parisFacade(ctx)
	local B, label, group = ctx.B, ctx.label, ctx.group
	local P = ctx.spec.paris
	local top = ctx.facadeTop
	local F = group("Facade")
	local U = group("UpperFloors")
	local stone, trim, shop = P.stone, P.trim, P.shop
	local function deco(parent, extra)
		local o = { parent = parent or U, studs = false, decor = true }
		if extra then for k, v in extra do o[k] = v end end
		return o
	end
	local glassO = deco(nil, { mat = Enum.Material.Glass })
	local thin = deco(nil, { noShadow = true })

	-- Enseigne principale en lettres dorées à empattements
	local sp = ctx.model:FindFirstChild("SignPart")
	local sg = sp and sp:FindFirstChild("LabelGui_Front")
	serif(sg and sg:FindFirstChild("Label"), P.signStroke)

	-- Devanture
	B("FasciaBack", -18.9, 8.5, -24.75, 18.9, 11.2, -24.6, shop, deco(F))
	B("ShopCornice", -19.1, 11.2, -25.45, 19.1, 11.7, -24.6, shop, deco(F))
	B("ShopCorniceGold", -19.2, 11.7, -25.55, 19.2, 11.85, -24.6, GOLD, deco(F))
	for i, s in { -1, 1 } do
		B("Caisson_" .. i, s * 17.6, 0.3, -25.0, s * 18.9, 8.5, -24.0, shop, deco(F))
		B("CaissonCap_" .. i, s * 17.5, 8.5, -25.1, s * 19.0, 8.85, -24.0, GOLD, deco(F))
	end
	B("PanelFrame", -16.2, 2.0, -24.12, -7.8, 6.8, -24.0, GOLD, deco(F))
	local panel = B("PanelBoard", -16.0, 2.2, -24.2, -8.0, 6.6, -24.0, shop, deco(F))
	serif(label(panel, Enum.NormalId.Front, P.panel, GOLD, 40), P.signStroke)
	for i, x in { 10.3, 15.7 } do
		B("LanternArm_" .. i, x - 0.05, 6.25, -24.4, x + 0.05, 6.35, -24.0, IRON, deco(F))
		B("LanternTop_" .. i, x - 0.35, 6.5, -24.95, x + 0.35, 6.7, -24.25, IRON, deco(F))
		B("LanternBase_" .. i, x - 0.3, 5.55, -24.9, x + 0.3, 5.65, -24.3, IRON, deco(F))
		local glow = B("LanternGlow_" .. i, x - 0.25, 5.65, -24.85, x + 0.25, 6.5, -24.35, rgb(255, 214, 140), deco(F, { mat = Enum.Material.Neon, noShadow = true }))
		local pl = Instance.new("PointLight"); pl.Range = 12; pl.Brightness = 0.7; pl.Color = rgb(255, 210, 150); pl.Shadows = false; pl.Parent = glow
	end

	-- 1er étage : balcon filant sur consoles, portes-fenêtres à petits bois et corniches
	B("BalconySlab", -18.6, 12.5, -25.9, 18.6, 12.9, -24.6, trim, deco())
	for i, x in { -16, -8, 0, 8, 16 } do
		B("BalconyConsole_" .. i, x - 0.3, 11.85, -25.7, x + 0.3, 12.5, -24.6, stone, deco())
	end
	B("RailTop", -18.5, 14.0, -25.88, 18.5, 14.14, -25.72, IRON, deco())
	B("RailMid", -18.5, 13.42, -25.85, 18.5, 13.5, -25.75, IRON, thin)
	B("RailLow", -18.5, 12.9, -25.85, 18.5, 13.0, -25.75, IRON, thin)
	B("RailReturn_L", -18.55, 12.9, -25.85, -18.45, 14.14, -24.6, IRON, thin)
	B("RailReturn_R", 18.45, 12.9, -25.85, 18.55, 14.14, -24.6, IRON, thin)
	for k = 0, 41 do
		local bx = -18.4 + k * (36.8 / 41)
		B("RailBar_" .. (k + 1), bx - 0.035, 13.0, -25.84, bx + 0.035, 14.0, -25.76, IRON, thin)
	end
	local bays = { -13.5, -4.5, 4.5, 13.5 }
	for i, cx in bays do
		B("F1Surround_" .. i, cx - 1.6, 12.9, -24.7, cx + 1.6, 17.3, -24.6, trim, deco())
		B("F1Glass_" .. i, cx - 1.3, 12.9, -24.76, cx + 1.3, 17.0, -24.7, GLASS_DARK, glassO)
		B("F1Mullion_" .. i, cx - 0.07, 12.9, -24.82, cx + 0.07, 17.0, -24.76, FRAME_WHITE, thin)
		B("F1Transom_" .. i, cx - 1.3, 15.8, -24.82, cx + 1.3, 15.92, -24.76, FRAME_WHITE, thin)
		B("F1Cornice_" .. i, cx - 1.9, 17.3, -25.0, cx + 1.9, 17.65, -24.6, trim, deco())
		-- 2e étage : fenêtres à clé et garde-corps
		B("F2Surround_" .. i, cx - 1.5, 18.65, -24.7, cx + 1.5, 22.15, -24.6, trim, deco())
		B("F2Glass_" .. i, cx - 1.2, 18.9, -24.76, cx + 1.2, 21.9, -24.7, GLASS_DARK, glassO)
		B("F2Mullion_" .. i, cx - 0.06, 18.9, -24.82, cx + 0.06, 21.9, -24.76, FRAME_WHITE, thin)
		B("F2Transom_" .. i, cx - 1.2, 20.95, -24.82, cx + 1.2, 21.05, -24.76, FRAME_WHITE, thin)
		B("F2Key_" .. i, cx - 0.32, 21.9, -24.86, cx + 0.32, 22.5, -24.6, stone, deco())
		B("GuardTop_" .. i, cx - 1.3, 19.95, -25.06, cx + 1.3, 20.05, -24.96, IRON, thin)
		B("GuardLow_" .. i, cx - 1.3, 18.9, -25.04, cx + 1.3, 18.98, -24.96, IRON, thin)
		for k = 0, 3 do
			local bx = cx - 1.0 + k * (2.0 / 3)
			B("GuardBar_" .. i .. "_" .. k, bx - 0.035, 18.98, -25.03, bx + 0.035, 19.95, -24.97, IRON, thin)
		end
	end
	B("StringCourse", -18.9, 18.0, -24.8, 18.9, 18.3, -24.6, trim, deco())
	for k = 0, 8 do
		local x = -18 + k * 4.5
		B("Modillion_" .. (k + 1), x - 0.25, top - 0.45, -24.95, x + 0.25, top, -24.6, trim, deco())
	end

	-- Balcon du dernier étage, posé sur la corniche
	local ty = top + 0.5
	B("TopRailTop", -19.9, ty + 0.9, -24.86, 19.9, ty + 1.0, -24.74, IRON, deco())
	B("TopRailLow", -19.9, ty + 0.03, -24.84, 19.9, ty + 0.1, -24.76, IRON, thin)
	for k = 0, 26 do
		local bx = -19.8 + k * (39.6 / 26)
		B("TopRailBar_" .. (k + 1), bx - 0.035, ty + 0.1, -24.83, bx + 0.035, ty + 0.9, -24.77, IRON, thin)
	end

	-- Volume des étages, toit mansardé (brisis en zinc, terrasson), lucarnes et cheminées
	local my0, my1 = ty, ty + 5
	B("UpperSide_L", -20.05, 10.8, -23, -19, ty, -11, stone, { parent = U })
	B("UpperSide_R", 19, 10.8, -23, 20.05, ty, -11, stone, { parent = U })
	B("UpperBack", -20.05, 10.8, -12, 20.05, ty, -11, stone, { parent = U })
	B("Mansard", -20, my0, -24.5, 20, my1, -22.3, snowy(SNOW, P.zinc), { parent = U, decor = true, shape = Enum.PartType.Wedge })
	B("AtticBody", -20, my0, -22.3, 20, my1, -11, P.zinc, { parent = U })
	B("AtticTop", -20.1, my1, -22.45, 20.1, my1 + 0.25, -10.9, snowy(SNOW, P.zincDark), { parent = U, studs = false })
	for i, cx in bays do
		B("Dormer_" .. i, cx - 1.3, my0 + 0.5, -24.35, cx + 1.3, my0 + 3.6, -22.4, trim, { parent = U, decor = true })
		B("DormerGlass_" .. i, cx - 0.8, my0 + 0.8, -24.41, cx + 0.8, my0 + 3.0, -24.35, GLASS_DARK, glassO)
		B("DormerBar_" .. i, cx - 0.05, my0 + 0.8, -24.45, cx + 0.05, my0 + 3.0, -24.41, FRAME_WHITE, thin)
		B("DormerCap_" .. i, cx - 0.95, my0 + 2.3, -24.6, cx + 0.95, my0 + 4.9, -22.0, snowy(SNOW, P.zinc), deco(nil, { shape = Enum.PartType.Cylinder, rot = CFrame.Angles(0, math.rad(90), 0) }))
	end
	for i, cx in { -16.5, 16.5 } do
		B("Chimney_" .. i, cx - 1.6, my1 - 1, -18.5, cx + 1.6, my1 + 2.6, -15.0, P.chimney, { parent = U })
		B("ChimneyCap_" .. i, cx - 1.75, my1 + 2.6, -18.65, cx + 1.75, my1 + 2.85, -14.85, snowy(SNOW, trim), { parent = U, studs = false })
		for k = 0, 3 do
			local px, yc = cx - 1.05 + k * 0.7, my1 + 3.2
			B("ChimneyPot_" .. i .. "_" .. k, px - 0.35, yc - 0.2, -16.95, px + 0.35, yc + 0.2, -16.55, rgb(190, 95, 60), deco(nil, { shape = Enum.PartType.Cylinder, rot = CFrame.Angles(0, 0, math.rad(90)) }))
		end
	end

	-- Enseigne drapeau (sur le pilastre droit, à côté du balcon) et plaque de rue bleue
	local bx = 19.6
	B("BladeBracket", bx - 0.1, 17.0, -27.6, bx + 0.1, 17.2, -24.85, IRON, deco())
	B("BladeFrame", bx - 0.07, 14.45, -27.45, bx + 0.07, 16.95, -25.05, GOLD, deco())
	local bs = B("BladeSign", bx - 0.12, 14.6, -27.3, bx + 0.12, 16.8, -25.2, shop, deco())
	serif(label(bs, Enum.NormalId.Left, P.blade, GOLD, 40), P.signStroke)
	serif(label(bs, Enum.NormalId.Right, P.blade, GOLD, 40), P.signStroke)
	B("StreetPlaqueRim", -18.75, 15.0, -24.7, -15.35, 16.4, -24.6, rgb(40, 120, 90), deco())
	local plaque = B("StreetPlaque", -18.65, 15.1, -24.76, -15.45, 16.3, -24.6, rgb(26, 58, 128), deco())
	label(plaque, Enum.NormalId.Front, P.plaque, rgb(255, 255, 255), 60, rgb(26, 58, 128))

	parisInterior(ctx)

	-- Le constructeur agrandit le magasin (spec.scale) juste après cette fonction ; ScaleTo n'agrandit pas la portée
	-- des lumières, elle est donc multipliée ici.
	local k = ctx.spec.scale or 1
	if k ~= 1 then
		for _, l in ctx.model:GetDescendants() do
			if l:IsA("Light") then l.Range = math.min(60, l.Range * k) end
		end
	end
end
_G.ClaudeParis = { facade = parisFacade, interior = parisInterior }

-- 1) Greybox de la zone 5 seulement (gabarit 2026-11-07) : magasins gris mis de côté ; chaussée élargie à
--    |z| 22,5 ; Side_N et Side_S à |z| 22,5..62,5 ; murets de 18 de haut à |z| 30..31,5, hors de l'emprise des
--    magasins (x 588..648) ; le tout de x 530 à 718 ; rue en pavés gris (couleur et MaterialVariant « Studs ») ;
--    patrouilles de nuit sur l'axe ; arche ZoneGate_5 agrandie ×1.5, base à y = 0, centrée sur z = 0, à x = 530
--    (nom, tag et structure inchangés).
do
	local SS = game:GetService("ServerStorage")
	local gz = workspace.Greybox.Corridor.Zone_5
	for _, nm in { "STORE_Z5_GalerieDArt", "STORE_Z5_Antiquaire" } do
		local m = gz:FindFirstChild(nm)
		if m then
			local keep = SS:FindFirstChild("_GREYBOX_REMPLACE") or Instance.new("Folder")
			keep.Name = "_GREYBOX_REMPLACE"; keep.Parent = SS
			m.Parent = keep
		end
	end
	local g = gz.Ground
	local x0, x1 = ZONE_X0, ZONE_X1
	local w0, w1 = STORE_X - 30, STORE_X + 30   -- emprise des magasins, sans muret
	g.Street.Size = Vector3.new(x1 - x0, 2, 45); g.Street.Position = Vector3.new((x0 + x1) / 2, -1, 0)
	g.Street.Color = snowy(rgb(104, 108, 118), rgb(92, 90, 96)); g.Street.Material = Enum.Material.Plastic; g.Street.MaterialVariant = "Studs"
	for _, s in { 1, -1 } do
		local t = (s > 0) and "N" or "S"
		local side = g["Side_" .. t]
		side.Size = Vector3.new(x1 - x0, 2, 40); side.Position = Vector3.new((x0 + x1) / 2, -1, s * 42.5)
		g["SideWall_" .. t .. "1"].Size = Vector3.new(w0 - x0, 18, 1.5); g["SideWall_" .. t .. "1"].Position = Vector3.new((x0 + w0) / 2, 9, s * 30.75)
		g["SideWall_" .. t .. "2"].Size = Vector3.new(x1 - w1, 18, 1.5); g["SideWall_" .. t .. "2"].Position = Vector3.new((w1 + x1) / 2, 9, s * 30.75)
	end
	-- points de patrouille de nuit, sur l'axe de la rue : x' = 30 + (x - 30) × 1,25 depuis x 467,5 et 542,5
	for nm, x in { NightPatrol_Z5_A = 576.875, NightPatrol_Z5_B = 670.625 } do
		local p = gz:FindFirstChild(nm)
		if p then p.Position = Vector3.new(x, p.Position.Y, 0) end
	end
	local gate = gz:FindFirstChild("ZoneGate_5")
	if gate then
		gate:ScaleTo(SCALE)
		local cf, size = gate:GetBoundingBox()
		gate:PivotTo(gate:GetPivot() + Vector3.new(x0 - cf.Position.X, size.Y / 2 - cf.Position.Y, -cf.Position.Z))
	end
end

-- 2) Dossier de la zone
local zoneFolder = workspace.Map:FindFirstChild("Zone_5")
if not zoneFolder then zoneFolder = Instance.new("Folder"); zoneFolder.Name = "Zone_5"; zoneFolder.Parent = workspace.Map end
for _, nm in { "STORE_Z5_GalerieDArt", "STORE_Z5_Antiquaire" } do
	local old = zoneFolder:FindFirstChild(nm); if old then old:Destroy() end
end
-- point d'apparition du camion (TruckSpawn, posé hors de ce script) : x' = 30 + (500 - 30) × 1,25
local truck = zoneFolder:FindFirstChild("TruckSpawn")
if truck then truck.Position = Vector3.new(617.5, truck.Position.Y, truck.Position.Z) end

-- 3) Galerie d'art : pierre crème, devanture vert sapin à lettres dorées, auvent vert et crème, murs blancs,
--    parquet de chêne clair, rayons de tableaux encadrés, sculptures et vases.
local stoneG, trimG, darkG = rgb(230, 218, 192), rgb(242, 236, 220), rgb(200, 186, 160)
local gallery, galleryN = Store.build({
	name = "STORE_Z5_GalerieDArt", zone = 5,
	origin = CFrame.new(STORE_X, 0, 44 * SCALE), scale = SCALE, parent = zoneFolder,
	sign = "ART GALLERY",
	signColors = { bg = SAPIN, text = GOLD, border = GOLD },
	signRect = { -16, 16, 8.95, 10.85 }, facadeTop = 23.2,
	awning = { a = SAPIN, b = rgb(244, 236, 214) },
	promo = "EXPO",
	colors = {
		wall = darkG, front = SAPIN, upper = stoneG, trim = GOLD, cornice = trimG, pilaster = rgb(222, 208, 180),
		frame = rgb(22, 40, 32), plinth = rgb(60, 60, 64), roof = ZINC,
		innerWall = rgb(246, 244, 238), ceiling = rgb(250, 249, 245), floor = rgb(96, 64, 40),
		reserve = rgb(206, 202, 194), shelf = rgb(244, 242, 236), shelfBack = rgb(226, 222, 214), kick = rgb(40, 40, 44), price = rgb(30, 30, 34),
		counter = rgb(30, 30, 34), counterTop = rgb(244, 242, 236), mat = SAPIN, doorKick = GOLD,
		neon = rgb(250, 248, 240), wood = rgb(150, 112, 72), gold = GOLD, carton = rgb(176, 140, 96),
		pot = rgb(40, 40, 44), leaf = rgb(52, 120, 64), promo = rgb(242, 240, 234), promoText = rgb(30, 30, 34),
	},
	headers = {
		A_L = { "PAINTINGS", rgb(150, 40, 46) }, A_R = { "SCULPTURES", rgb(120, 116, 108) },
		B_L = { "PORTRAITS", rgb(40, 60, 120) }, B_R = { "VASES", rgb(40, 110, 130) },
		WallL = { "LANDSCAPES", rgb(52, 120, 72) }, WallR = { "PRINTS", rgb(30, 30, 34) }, Back = { "MASTERPIECES", rgb(150, 120, 50) },
	},
	designs = {
		tabR = { body = rgb(178, 52, 44), w = 1.1, h = 1.3, d = 0.12 },
		tabB = { body = rgb(52, 92, 168), w = 1.1, h = 1.3, d = 0.12 },
		tabJ = { body = rgb(232, 186, 64), w = 1.0, h = 1.2, d = 0.12 },
		tabV = { body = rgb(84, 140, 82), w = 1.2, h = 1.1, d = 0.12 },
		portrait = { body = rgb(92, 64, 48), w = 0.9, h = 1.3, d = 0.12 },
		portraitN = { body = rgb(40, 44, 58), w = 0.9, h = 1.3, d = 0.12 },
		miniature = { body = rgb(150, 110, 80), w = 0.7, h = 0.9, d = 0.12 },
		paysage = { body = rgb(120, 176, 210), w = 1.3, h = 1.0, d = 0.12 },
		paysageV = { body = rgb(150, 190, 120), w = 1.3, h = 1.0, d = 0.12 },
		estampe = { body = rgb(240, 232, 210), w = 0.9, h = 1.2, d = 0.12 },
		estampeG = { body = rgb(210, 200, 180), w = 0.9, h = 1.2, d = 0.12 },
		statue = { body = rgb(236, 232, 222), cap = rgb(222, 216, 204), w = 0.55, h = 1.4, ch = 0.45, d = 0.55 },
		statueDoree = { body = rgb(214, 172, 70), cap = rgb(232, 196, 96), w = 0.55, h = 1.35, ch = 0.4, d = 0.55 },
		bronze = { body = rgb(140, 92, 48), cap = rgb(112, 74, 40), w = 0.55, h = 1.3, ch = 0.4, d = 0.55 },
		buste = { body = rgb(240, 238, 230), w = 0.8, h = 0.8, ball = true },
		vaseBlanc = { body = rgb(242, 240, 232), cap = rgb(44, 92, 170), w = 0.6, h = 1.1, ch = 0.3, d = 0.6 },
		amphore = { body = rgb(196, 112, 64), cap = rgb(40, 30, 26), w = 0.65, h = 1.2, ch = 0.35, d = 0.65 },
		vaseBleu = { body = rgb(44, 92, 170), w = 0.85, h = 0.85, ball = true },
	},
	pools = {
		A_L = { "tabR", "tabB", "tabJ", "tabV" }, A_R = { "statue", "statueDoree", "bronze", "buste" },
		B_L = { "portrait", "portraitN", "miniature" }, B_R = { "vaseBlanc", "amphore", "vaseBleu" },
		WallL = { "paysage", "paysageV", "tabB" }, WallR = { "estampe", "estampeG" },
		Back = { "statue", "statueDoree", "vaseBlanc", "amphore" },
	},
	seed = 5005, stockColor = rgb(176, 140, 96),
	paris = {
		stone = stoneG, trim = trimG, stoneDark = darkG, shop = SAPIN, zinc = ZINC, zincDark = ZINC_DARK,
		chimney = rgb(214, 198, 172), signStroke = rgb(14, 36, 26),
		panel = "PAINTING\nSCULPTURE\nDRAWING", blade = "GALLERY", plaque = "5TH DISTRICT\nARTS STREET",
		interior = {
			planks = { rgb(196, 150, 100), rgb(184, 138, 90), rgb(206, 162, 112) },
			frameFor = {
				tabR = GOLD, tabB = GOLD, tabJ = GOLD, tabV = GOLD, portrait = GOLD, portraitN = GOLD, miniature = GOLD,
				paysage = GOLD, paysageV = GOLD, estampe = IRON, estampeG = IRON,
			},
			promoStroke = rgb(255, 255, 255),
			promoDecor = function(B, parent, tag, x0, x1)   -- socle de marbre : un buste et un vase
				B("BustBase_" .. tag, x0 + 0.45, 1.6, -16.2, x0 + 1.35, 2.15, -15.35, rgb(236, 232, 222), { parent = parent, studs = false, decor = true })
				B("BustHead_" .. tag, x0 + 0.52, 2.15, -16.15, x0 + 1.28, 2.91, -15.39, rgb(240, 238, 230), { parent = parent, studs = false, decor = true, shape = Enum.PartType.Ball })
				B("PlinthVase_" .. tag, x1 - 1.35, 1.6, -16.23, x1 - 0.45, 2.5, -15.33, rgb(44, 92, 170), { parent = parent, studs = false, decor = true, shape = Enum.PartType.Ball })
			end,
			corner = function(B, parent)   -- socle et statue de bronze dans le coin avant droit (hors des allées)
				B("Socle_Corner", 15.9, 0.35, -22.5, 18.3, 1.7, -20.1, rgb(242, 240, 234), { parent = parent, studs = false })
				B("Sculpture_Corner", 16.7, 1.7, -21.7, 17.5, 3.9, -20.9, rgb(140, 92, 48), { parent = parent, studs = false, decor = true })
				B("Sculpture_CornerTop", 16.6, 3.9, -21.8, 17.6, 4.9, -20.8, rgb(150, 100, 54), { parent = parent, studs = false, decor = true, shape = Enum.PartType.Ball })
			end,
			paintings = {
				{ "L", -14.4, -10.2, 6.9, 9.3, GOLD, rgb(120, 170, 210), { "horizon", rgb(82, 136, 78) } },
				{ "L", -8.6, -5.6, 7.0, 9.2, IRON, rgb(232, 186, 64), { "block", rgb(178, 52, 44) } },
				{ "L", -3.8, 0.8, 6.8, 9.4, GOLD, rgb(52, 92, 168), { "horizon", rgb(236, 210, 150) } },
				{ "L", 2.6, 5.8, 7.0, 9.2, GOLD, rgb(60, 46, 40), { "portrait", rgb(226, 190, 160) } },
				{ "R", -14.0, -10.6, 7.0, 9.2, GOLD, rgb(70, 44, 36), { "portrait", rgb(232, 196, 166) } },
				{ "R", -8.8, -4.6, 6.8, 9.4, IRON, rgb(240, 236, 226), { "block", rgb(46, 96, 176) } },
				{ "R", -2.8, 0.6, 7.0, 9.2, GOLD, rgb(170, 60, 50), { "horizon", rgb(240, 200, 90) } },
				{ "R", 2.4, 6.6, 6.9, 9.3, GOLD, rgb(140, 190, 220), { "horizon", rgb(64, 120, 70) } },
				{ "L", -21.2, -16.6, 3.4, 7.0, GOLD, rgb(110, 160, 205), { "horizon", rgb(90, 140, 82) } },
				{ "R", -21.4, -16.8, 3.8, 7.2, IRON, rgb(232, 72, 60), { "block", rgb(250, 220, 80) } },
				{ "L", 10.2, 13.6, 3.6, 7.0, GOLD, rgb(50, 70, 120), { "portrait", rgb(230, 196, 164) } },
				{ "L", 15.4, 19.8, 3.4, 7.6, GOLD, rgb(150, 196, 230), { "horizon", rgb(230, 190, 110) } },
				{ "R", 10.2, 14.6, 3.6, 7.2, IRON, rgb(250, 246, 236), { "block", rgb(30, 30, 34) } },
				{ "B", -17.6, -13.6, 6.8, 9.4, GOLD, rgb(176, 60, 48), { "horizon", rgb(240, 200, 90) } },
				{ "B", -11.6, -8.4, 7.0, 9.2, GOLD, rgb(60, 46, 40), { "portrait", rgb(226, 190, 160) } },
				{ "B", -6.4, -2.4, 6.8, 9.4, GOLD, rgb(110, 160, 205), { "horizon", rgb(82, 136, 78) } },
				{ "B", 0.8, 6.8, 3.4, 7.8, GOLD, rgb(52, 92, 168), { "horizon", rgb(240, 214, 160) } },
				{ "F", -17.2, -13.2, 4.6, 7.6, GOLD, rgb(120, 170, 210), { "horizon", rgb(90, 140, 82) } },
				{ "F", -11.2, -8.0, 4.8, 7.4, IRON, rgb(240, 236, 226), { "block", rgb(232, 72, 60) } },
				{ "F", 7.3, 10.3, 3.8, 6.8, GOLD, rgb(60, 46, 40), { "portrait", rgb(226, 190, 160) } },
				{ "F", 15.6, 18.3, 4.2, 7.0, GOLD, rgb(232, 186, 64), { "block", rgb(52, 92, 168) } },
			},
		},
	},
	facade = parisFacade,
})
task.wait()

-- 4) Antiquaire : même immeuble, devanture bordeaux, auvent bordeaux et crème, murs vert anglais, parquet de noyer,
--    tapis, horloges, coffres, vaisselle, luminaires et livres ; horloge comtoise dans le coin, horloge murale au fond.
local stoneA, trimA, darkA = rgb(226, 212, 184), rgb(240, 232, 214), rgb(196, 180, 152)
local antique, antiqueN = Store.build({
	name = "STORE_Z5_Antiquaire", zone = 5,
	origin = CFrame.new(STORE_X, 0, -44 * SCALE) * CFrame.Angles(0, math.pi, 0), scale = SCALE, parent = zoneFolder,
	sign = "ANTIQUES",
	signColors = { bg = BORDEAUX, text = GOLD, border = GOLD },
	signRect = { -16, 16, 8.95, 10.85 }, facadeTop = 23.2,
	awning = { a = BORDEAUX, b = rgb(244, 236, 214) },
	promo = "RARE",
	colors = {
		wall = darkA, front = BORDEAUX, upper = stoneA, trim = GOLD, cornice = trimA, pilaster = rgb(216, 200, 170),
		frame = rgb(52, 18, 26), plinth = rgb(60, 60, 64), roof = ZINC,
		innerWall = rgb(52, 84, 66), ceiling = rgb(236, 226, 204), floor = rgb(52, 34, 20),
		reserve = rgb(150, 120, 90), shelf = rgb(110, 70, 42), shelfBack = rgb(84, 52, 30), kick = rgb(60, 38, 22), price = GOLD,
		counter = rgb(84, 52, 30), counterTop = rgb(46, 84, 64), mat = BORDEAUX, doorKick = GOLD,
		neon = rgb(255, 236, 200), wood = rgb(84, 52, 30), gold = GOLD, carton = rgb(120, 84, 52),
		pot = rgb(40, 40, 44), leaf = rgb(52, 120, 64), promo = rgb(96, 60, 36), promoText = GOLD,
	},
	headers = {
		A_L = { "CLOCKS", rgb(92, 56, 32) }, A_R = { "CURIOS", rgb(120, 32, 46) },
		B_L = { "CHESTS", rgb(110, 76, 40) }, B_R = { "TABLEWARE", rgb(40, 76, 140) },
		WallL = { "LAMPS", rgb(150, 112, 40) }, WallR = { "RARE BOOKS", rgb(40, 90, 64) }, Back = { "RARE FINDS", rgb(120, 32, 46) },
	},
	designs = {
		horloge = { body = rgb(104, 62, 34), cap = rgb(212, 176, 90), w = 0.8, h = 1.25, ch = 0.3, d = 0.55 },
		horlogeN = { body = rgb(44, 34, 30), cap = rgb(212, 176, 90), w = 0.8, h = 1.25, ch = 0.3, d = 0.55 },
		pendule = { body = rgb(214, 178, 92), cap = rgb(150, 116, 52), w = 0.7, h = 1.1, ch = 0.25, d = 0.5 },
		boiteMusique = { body = rgb(124, 72, 40), cap = rgb(212, 176, 90), w = 0.8, h = 0.6, ch = 0.15, d = 0.6 },
		statuette = { body = rgb(242, 240, 232), cap = rgb(60, 100, 170), w = 0.6, h = 1.1, ch = 0.35, d = 0.5 },
		masque = { body = rgb(150, 104, 56), cap = rgb(96, 60, 30), w = 0.7, h = 0.95, ch = 0.25, d = 0.3 },
		encrier = { body = rgb(30, 30, 34), cap = rgb(212, 176, 90), w = 0.6, h = 0.5, ch = 0.15, d = 0.6 },
		coffre = { body = rgb(122, 76, 40), cap = rgb(88, 54, 30), w = 1.2, h = 0.85, ch = 0.3, d = 0.8 },
		coffreF = { body = rgb(74, 70, 66), cap = rgb(160, 126, 60), w = 1.1, h = 0.8, ch = 0.25, d = 0.8 },
		malle = { body = rgb(60, 92, 120), cap = rgb(140, 100, 60), w = 1.3, h = 0.9, ch = 0.3, d = 0.85 },
		theiere = { body = rgb(196, 196, 202), w = 0.75, h = 0.75, ball = true },
		assiette = { body = rgb(244, 242, 236), cap = rgb(44, 82, 160), w = 0.9, h = 0.9, ch = 0.1, d = 0.15 },
		vasePorc = { body = rgb(238, 236, 228), cap = rgb(44, 82, 160), w = 0.6, h = 1.15, ch = 0.3, d = 0.6 },
		chandelier = { body = rgb(212, 176, 90), cap = rgb(250, 246, 230), w = 0.5, h = 1.3, ch = 0.45, d = 0.4 },
		lampe = { body = rgb(176, 136, 62), cap = rgb(40, 110, 70), w = 0.65, h = 1.25, ch = 0.4, d = 0.6 },
		lampeB = { body = rgb(150, 112, 50), cap = rgb(240, 226, 196), w = 0.65, h = 1.25, ch = 0.45, d = 0.6 },
		livreR = { body = rgb(122, 36, 36), cap = rgb(212, 176, 90), w = 0.6, h = 1.0, ch = 0.07, d = 0.7 },
		livreV = { body = rgb(40, 82, 52), cap = rgb(212, 176, 90), w = 0.6, h = 1.0, ch = 0.07, d = 0.7 },
		livreB = { body = rgb(92, 58, 34), cap = rgb(212, 176, 90), w = 0.6, h = 0.95, ch = 0.07, d = 0.7 },
		globe = { body = rgb(70, 120, 160), w = 0.8, h = 0.8, ball = true },
	},
	pools = {
		A_L = { "horloge", "horlogeN", "pendule" }, A_R = { "boiteMusique", "statuette", "masque", "encrier" },
		B_L = { "coffre", "coffreF", "malle" }, B_R = { "theiere", "assiette", "vasePorc" },
		WallL = { "chandelier", "lampe", "lampeB" }, WallR = { "livreR", "livreV", "livreB", "globe" },
		Back = { "pendule", "vasePorc", "coffre", "lampe" },
	},
	seed = 5050, stockColor = rgb(120, 84, 52),
	paris = {
		stone = stoneA, trim = trimA, stoneDark = darkA, shop = BORDEAUX, zinc = ZINC, zincDark = ZINC_DARK,
		chimney = rgb(206, 190, 164), signStroke = rgb(40, 8, 16),
		panel = "WE BUY\nWE SELL\nAPPRAISALS", blade = "ANTIQUES", plaque = "5TH DISTRICT\nTIME STREET",
		interior = {
			planks = { rgb(120, 78, 46), rgb(108, 70, 42), rgb(132, 88, 52) },
			dialFor = { horloge = CREAM, horlogeN = CREAM, pendule = CREAM },
			fridge = rgb(84, 52, 30), rug = { rgb(120, 32, 46), GOLD }, promoStroke = rgb(40, 20, 10),
			promoDecor = function(B, parent, tag, x0, x1)   -- table de bois sombre : un coffre et un globe
				B("ChestBody_" .. tag, x0 + 0.4, 1.6, -16.25, x0 + 1.7, 2.3, -15.3, rgb(122, 76, 40), { parent = parent, studs = false, decor = true })
				B("ChestLid_" .. tag, x0 + 0.35, 2.3, -16.3, x0 + 1.75, 2.55, -15.25, rgb(88, 54, 30), { parent = parent, studs = false, decor = true })
				B("GlobeStand_" .. tag, x1 - 1.1, 1.6, -15.95, x1 - 0.7, 2.0, -15.55, GOLD, { parent = parent, studs = false, decor = true })
				B("Globe_" .. tag, x1 - 1.3, 2.0, -16.15, x1 - 0.5, 2.8, -15.35, rgb(70, 120, 160), { parent = parent, studs = false, decor = true, shape = Enum.PartType.Ball })
			end,
			corner = function(B, parent)   -- horloge comtoise contre le mur droit, dans le coin avant (hors des allées)
				B("Comtoise_Case", 17.7, 0.35, -22.4, 18.9, 5.8, -20.9, rgb(92, 56, 32), { parent = parent })
				B("Comtoise_Hood", 17.55, 5.8, -22.55, 18.9, 6.7, -20.75, rgb(70, 42, 24), { parent = parent, studs = false, decor = true })
				B("Comtoise_Face", 17.62, 4.5, -22.15, 17.7, 5.5, -21.15, CREAM, { parent = parent, studs = false, decor = true, shape = Enum.PartType.Cylinder })
				B("Comtoise_Bob", 17.62, 2.0, -22.1, 17.7, 2.9, -21.2, GOLD, { parent = parent, studs = false, decor = true, shape = Enum.PartType.Cylinder })
			end,
			wallClock = { 3.8, 5.6, 2.0 },
			paintings = {
				{ "L", -13.8, -10.0, 6.9, 9.3, GOLD, rgb(52, 40, 30), { "portrait", rgb(214, 176, 140) } },
				{ "L", -6.4, -1.8, 6.8, 9.4, GOLD, rgb(70, 82, 60), { "horizon", rgb(120, 96, 60) } },
				{ "L", 2.0, 6.2, 6.9, 9.3, GOLD, rgb(40, 50, 70), { "horizon", rgb(150, 130, 90) } },
				{ "R", -13.6, -9.4, 6.9, 9.3, GOLD, rgb(60, 44, 34), { "horizon", rgb(140, 110, 70) } },
				{ "R", -5.4, -2.0, 7.0, 9.2, GOLD, rgb(46, 36, 30), { "portrait", rgb(210, 172, 136) } },
				{ "R", 1.6, 6.4, 6.8, 9.4, GOLD, rgb(90, 100, 80), { "horizon", rgb(60, 70, 50) } },
				{ "L", -21.0, -16.8, 3.4, 7.2, GOLD, rgb(196, 214, 222), "mirror" },
				{ "L", 10.6, 19.4, 3.2, 8.0, GOLD, rgb(196, 214, 222), "mirror" },
				{ "R", 10.4, 14.6, 3.6, 7.2, GOLD, rgb(46, 36, 30), { "portrait", rgb(210, 172, 136) } },
				{ "B", -16.6, -12.6, 6.8, 9.4, GOLD, rgb(50, 40, 32), { "portrait", rgb(214, 176, 140) } },
				{ "B", -7.6, -3.4, 6.8, 9.4, GOLD, rgb(64, 76, 56), { "horizon", rgb(130, 104, 66) } },
				{ "F", -17.0, -13.0, 4.6, 7.6, GOLD, rgb(56, 44, 36), { "horizon", rgb(150, 120, 80) } },
				{ "F", -11.2, -8.0, 4.8, 7.4, GOLD, rgb(60, 46, 36), { "portrait", rgb(214, 176, 140) } },
				{ "F", 7.3, 10.3, 3.8, 6.8, GOLD, rgb(196, 214, 222), "mirror" },
			},
		},
	},
	facade = parisFacade,
})
task.wait()

-- 5) Décor de rue et quartier : Map/Zone_5/Street_Paris (gabarit 2026-11-07 : tout ×1.5, couloir de 60).
--    Chaque groupe est dessiné en unités du gabarit 1 (« u »), agrandi par ScaleTo(SCALE) autour de (500, 0, 0), puis
--    posé au milieu des magasins : monde x = 618 + 1,5 (u - 500), y = 1,5 u, z = 1,5 u. En u : zone x
--    441,33..566,67 (monde 530..718), magasins x 480..520 ; chaussée
--    |z| < 15 (monde 22,5), libre de tout obstacle ; trottoirs |z| 15..20 (22,5..30), 0,3 de haut (0,45 : le sol des
--    magasins) ; immeubles plaqués sur les murets, façade à |z| 20 (30), sans collision ; magasins x 480..520,
--    |z| 20..68 ; quartier jusqu'à |z| 93,33 (140) ; tour Eiffel au-delà, sur le Champ de Mars (z 93,33..180, monde
--    140..270). ScaleTo n'agrandit pas la portée des lumières : elle est multipliée à part.
do
	local K = SCALE
	local CS = game:GetService("CollectionService")
	-- Lanternes des réverbères et des candélabres (L-043) : tag NightLight, livrées éteintes (verre, lumière coupée) ;
	-- le code les passe en Neon et allume leur lumière la nuit. Ni les enseignes ni les néons décoratifs n'ont ce tag.
	local function nightLantern(glow, light)
		CS:AddTag(glow, "NightLight")
		if light then light.Enabled = false end
	end
	local XC, XW = 500, STORE_X                   -- milieu des magasins : en u, puis dans le monde
	local XA, XB = XC - (XW - ZONE_X0) / K, XC + (ZONE_X1 - XW) / K   -- 441,33 et 566,67 : les bouts de la zone
	local XH, XE = XA + 1.1, XB - 1.1             -- immeubles sur rue, à l'écart des piliers des arches
	local ZG, ZD, ZM = 62.5 / K, 140 / K, 270 / K -- fin du greybox, fin du quartier, fin du Champ de Mars
	local Z = zoneFolder
	local old = Z:FindFirstChild("Street_Paris"); if old then old:Destroy() end
	local S = Instance.new("Folder"); S.Name = "Street_Paris"; S.Parent = Z
	local groups = {}
	local function folder(name) local f = Instance.new("Model"); f.Name = name; table.insert(groups, f); return f end
	local function P(parent, name, cf, size, color, opt)
		opt = opt or {}
		local p = Instance.new("Part")
		p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color; p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
		if opt.shape then p.Shape = opt.shape end
		if opt.mat then p.Material = opt.mat
		elseif opt.studs then p.Material = Enum.Material.Plastic; p.MaterialVariant = "Studs"
		else p.Material = Enum.Material.SmoothPlastic end
		if opt.decor then p.CanCollide = false; p.CanTouch = false end
		if opt.T then p.Transparency = opt.T end
		if opt.noShadow then p.CastShadow = false end
		p.Parent = parent
		return p
	end
	local function Bx(parent, frame, name, x0, y0, z0, x1, y1, z1, color, opt)
		local size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
		return P(parent, name, frame * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), size, color, opt)
	end
	local function shaped(opt, shape)   -- copie des options : une table partagée ne change jamais de forme
		local o = {}
		for k, v in opt or {} do o[k] = v end
		o.shape = shape
		return o
	end
	local function vcyl(parent, name, x, y0, y1, z, dia, color, opt)
		return P(parent, name, CFrame.new(x, (y0 + y1) / 2, z) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(y1 - y0, dia, dia), color, shaped(opt, Enum.PartType.Cylinder))
	end
	local function ball(parent, name, x, y, z, dia, color, opt)
		return P(parent, name, CFrame.new(x, y, z), Vector3.new(dia, dia, dia), color, shaped(opt, Enum.PartType.Ball))
	end
	local function beam(parent, name, a, b, t, color, opt)
		return P(parent, name, CFrame.lookAt((a + b) / 2, b), Vector3.new(t, t, (b - a).Magnitude), color, opt)
	end
	local function label(part, face, text, color, ppS, stroke, font)
		local g = Instance.new("SurfaceGui"); g.Name = "LabelGui_" .. face.Name; g.Face = face
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = ppS or 40; g.LightInfluence = 0
		local t = Instance.new("TextLabel"); t.Name = "Label"; t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(1, 1)
		t.Text = text; t.TextScaled = true; t.TextColor3 = color
		t.FontFace = font or Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
		local s = Instance.new("UIStroke"); s.Color = stroke or Color3.new(0, 0, 0); s.Thickness = font and 2 or 3; s.LineJoinMode = Enum.LineJoinMode.Round; s.Parent = t
		local pad = Instance.new("UIPadding"); pad.PaddingTop = UDim.new(0.14, 0); pad.PaddingBottom = UDim.new(0.14, 0); pad.Parent = t
		t.Parent = g; g.Parent = part
	end
	local W = CFrame.identity
	local green = rgb(26, 62, 46)        -- vert des fontes de la ville (réverbères, colonnes, fontaine)
	local whiteL = rgb(240, 240, 236)
	local glassD = rgb(52, 64, 82)
	local trimC = rgb(240, 234, 218)
	local pave = snowy(SNOW, rgb(140, 136, 132))   -- trottoirs
	local yard = snowy(SNOW, rgb(150, 146, 140))   -- sol du quartier
	local stones = { rgb(228, 216, 190), rgb(234, 224, 202), rgb(220, 206, 178), rgb(236, 228, 210), rgb(226, 212, 186), rgb(232, 220, 196) }
	-- petit réverbère et arbre du quartier (peu de pièces : on ne s'y promène pas)
	local function lampS(parent, name, x, z)
		local m = Instance.new("Model"); m.Name = name; m.Parent = parent
		vcyl(m, "Pole", x, 0, 8.6, z, 0.34, green, { decor = true })
		local glow = Bx(m, W, "Lantern", x - 0.36, 8.6, z - 0.36, x + 0.36, 9.7, z + 0.36, rgb(255, 222, 160), { mat = Enum.Material.Glass, decor = true, noShadow = true })
		Bx(m, W, "LanternRoof", x - 0.55, 9.7, z - 0.55, x + 0.55, 10.0, z + 0.55, snowy(SNOW, green), { decor = true })
		local pl = Instance.new("PointLight"); pl.Color = rgb(255, 214, 150); pl.Range = 18; pl.Brightness = 0.9; pl.Shadows = false; pl.Parent = glow
		nightLantern(glow, pl)
	end
	local function treeS(parent, name, x, z, sc)
		sc = sc or 1
		local m = Instance.new("Model"); m.Name = name; m.Parent = parent
		vcyl(m, "Trunk", x, 0, 6.6 * sc, z, 0.7 * sc, rgb(120, 108, 92), { decor = true })
		ball(m, "Foliage", x, 7.4 * sc, z, 4.6 * sc, snowy(rgb(62, 94, 68), rgb(72, 124, 58)), { decor = true })
		ball(m, "FoliageSnow", x + 0.5 * sc, 8.7 * sc, z - 0.4 * sc, 3.4 * sc, snowy(SNOW, rgb(92, 140, 66)), { decor = true })
	end

	-- 5a) Sol : trottoirs enneigés, bordures de granit, caniveaux, passage piéton, neige sur la chaussée (tapis à
	--     l'entrée, puis entre les traces de roues), congères ; cours enneigées derrière les murets (posées sur Side_N
	--     et Side_S, sans les chevaucher) ; sol du quartier au-delà du greybox (monde |z| 62,5..140), Champ de Mars
	local G = folder("Ground")
	for _, s in { 1, -1 } do
		local tag = s > 0 and "N" or "S"
		Bx(G, W, "Kerb_" .. tag, XA, 0, s * 15, XB, 0.3, s * 15.5, rgb(188, 186, 180), { studs = true })
		Bx(G, W, "Pavement_" .. tag, XA, 0, s * 15.5, XB, 0.3, s * 20, pave, { studs = true })
		Bx(G, W, "Gutter_" .. tag, XA, 0, s * 14.3, XB, 0.03, s * 15, rgb(74, 72, 78), { decor = true, noShadow = true })
		Bx(G, W, "Yard_" .. tag .. "1", XA, 0, s * 21, 480, 0.02, s * ZG, yard, { decor = true, noShadow = true, studs = true })
		Bx(G, W, "Yard_" .. tag .. "2", 520, 0, s * 21, XB, 0.02, s * ZG, yard, { decor = true, noShadow = true, studs = true })
		Bx(G, W, "DistrictGround_" .. tag, XA, -2 / K, s * ZG, XB, 0, s * ZD, yard, { studs = true })
	end
	Bx(G, W, "ChampDeMars", XA, -2 / K, ZD, XB, 0, ZM, yard, { studs = true })
	for i = 0, 9 do
		local z0 = -14 + i * (26.6 / 9)
		Bx(G, W, "Crossing_" .. (i + 1), 526, 0, z0, 532, 0.04, z0 + 1.4, whiteL, { decor = true, noShadow = true })
	end
	if SNOWY then
		Bx(G, W, "RoadSnow_Entry", XA, 0, -14.3, XA + 8, 0.02, 14.3, SNOW, { decor = true, noShadow = true, studs = true })
		for i, band in { { -5, 5 }, { 6.6, 9.4 }, { -9.4, -6.6 }, { 11, 14.3 }, { -14.3, -11 } } do
			Bx(G, W, "RoadSnow_" .. i, XA + 8, 0, band[1], XB, 0.02, band[2], SNOW, { decor = true, noShadow = true, studs = true })
		end
		for i, bank in { { 476.5, 479.5, 1 }, { 520.5, 524, 1 }, { 561.5, 564.5, 1 }, { 476, 479.5, -1 }, { 520.5, 524, -1 }, { 561.5, 564.5, -1 } } do
			P(G, "SnowBank_" .. i, CFrame.new((bank[1] + bank[2]) / 2, 0.3, bank[3] * 19.1), Vector3.new(bank[2] - bank[1], 1.4, 1.4), SNOW, { shape = Enum.PartType.Cylinder, decor = true, noShadow = true })
		end
	end

	-- 5b) Immeubles haussmanniens plaqués sur les murets, avec leur volume jusqu'à |z| 33 (comme les étages des
	--     magasins) : rez-de-chaussée (porte cochère ou boutique), balcon filant, deux étages, corniche, toit mansardé
	--     enneigé (brisis avant et arrière, terrasson) à lucarnes, cheminées
	local Hs = folder("Facades")
	local function house(name, frame, w, st)
		local m = Instance.new("Model"); m.Name = name; m.Parent = Hs
		local stone = st.stone
		local dk = { decor = true }
		local gl = { decor = true, mat = Enum.Material.Glass }
		local bays = (w > 18) and 5 or 4
		local pitch = w / bays
		local D = 13.15
		Bx(m, frame, "Wall", 0, 0, 0, w, 23.2, D, stone, { studs = true, decor = true })
		Bx(m, frame, "Plinth", 0, 0.3, -0.1, w, 1.0, 0, rgb(160, 150, 132), dk)
		if st.shop then
			local sh = st.shop
			Bx(m, frame, "ShopFront", 0.8, 0.3, -0.25, w - 0.8, 9.6, 0, sh.color, dk)
			Bx(m, frame, "ShopGlass", 1.6, 1.2, -0.32, w - 4.6, 7.0, -0.25, glassD, gl)
			Bx(m, frame, "ShopEntry", w - 4.0, 0.3, -0.32, w - 1.6, 7.0, -0.25, glassD, gl)
			local sgn = Bx(m, frame, "ShopSign", 1.2, 7.6, -0.42, w - 1.2, 9.2, -0.25, sh.color, dk)
			label(sgn, Enum.NormalId.Front, sh.text, GOLD, 40, rgb(20, 20, 20), SERIF)
			local run, drop = 2.0, 0.9
			P(m, "ShopAwning", frame * CFrame.new(w / 2, 7.4 - drop / 2, -0.42 - run / 2) * CFrame.Angles(-math.atan2(drop, run), 0, 0), Vector3.new(w - 2.6, 0.12, math.sqrt(run * run + drop * drop)), sh.awning, dk)
		else
			local cx = w / 2
			Bx(m, frame, "PorchSurround", cx - 2.1, 0.3, -0.12, cx + 2.1, 9.4, 0, trimC, dk)
			Bx(m, frame, "PorchDoor", cx - 1.7, 0.3, -0.2, cx + 1.7, 8.0, -0.12, st.door, dk)
			Bx(m, frame, "PorchTransom", cx - 1.7, 8.0, -0.2, cx + 1.7, 9.0, -0.12, glassD, gl)
			for k, gx in { pitch * 0.5, w - pitch * 0.5 } do
				Bx(m, frame, "GroundFrame_" .. k, gx - 1.35, 2.2, -0.1, gx + 1.35, 8.8, 0, trimC, dk)
				Bx(m, frame, "GroundGlass_" .. k, gx - 1.1, 2.45, -0.16, gx + 1.1, 8.55, -0.1, glassD, gl)
			end
		end
		Bx(m, frame, "StringCourse", 0, 11.6, -0.3, w, 12.0, 0, trimC, dk)
		Bx(m, frame, "Balcony", 0.4, 12.4, -1.2, w - 0.4, 12.8, 0, trimC, dk)
		Bx(m, frame, "BalconyRail", 0.45, 13.85, -1.16, w - 0.45, 14.0, -1.0, IRON, dk)
		local nb = math.floor((w - 1) / 2.2)
		for k = 0, nb do
			local bx = 0.55 + k * (w - 1.1) / nb
			Bx(m, frame, "BalconyBar_" .. k, bx - 0.05, 12.8, -1.13, bx + 0.05, 13.85, -1.03, IRON, { decor = true, noShadow = true })
		end
		for b = 1, bays do
			local cx = pitch * (b - 0.5)
			Bx(m, frame, "F1Frame_" .. b, cx - 1.35, 12.8, -0.1, cx + 1.35, 17.2, 0, trimC, dk)
			Bx(m, frame, "F1Glass_" .. b, cx - 1.05, 12.8, -0.16, cx + 1.05, 16.9, -0.1, glassD, gl)
			Bx(m, frame, "F2Glass_" .. b, cx - 0.95, 18.6, -0.12, cx + 0.95, 21.8, 0, glassD, gl)
		end
		Bx(m, frame, "Band", 0, 17.6, -0.25, w, 17.95, 0, trimC, dk)
		Bx(m, frame, "Cornice", -0.05, 23.2, -0.7, w + 0.05, 23.7, 1.35, trimC, dk)
		P(m, "Mansard", frame * CFrame.new(w / 2, 25.95, 0.675), Vector3.new(w, 4.5, 2.15), snowy(SNOW, ZINC), { shape = Enum.PartType.Wedge, studs = true, decor = true })
		Bx(m, frame, "RoofTop", 0, 23.2, 1.35, w, 28.2, D - 2.15, snowy(SNOW, ZINC_DARK), { studs = true, decor = true })
		P(m, "MansardBack", frame * CFrame.new(w / 2, 25.7, D - 1.075) * CFrame.Angles(0, math.pi, 0), Vector3.new(w, 5, 2.15), snowy(SNOW, ZINC), { shape = Enum.PartType.Wedge, studs = true, decor = true })
		local dxs = (bays == 5) and { pitch * 1.5, pitch * 2.5, pitch * 3.5 } or { pitch * 1.5, pitch * 2.5 }
		for k, dx in dxs do
			Bx(m, frame, "Dormer_" .. k, dx - 1.15, 24.2, -0.35, dx + 1.15, 26.9, 1.4, trimC, { studs = true, decor = true })
			Bx(m, frame, "DormerGlass_" .. k, dx - 0.7, 24.5, -0.41, dx + 0.7, 26.4, -0.35, glassD, gl)
			P(m, "DormerCap_" .. k, frame * CFrame.new(dx, 26.9, 0.35) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(1.3, 2.3, 2.3), snowy(SNOW, ZINC), { shape = Enum.PartType.Cylinder, decor = true })
		end
		Bx(m, frame, "Chimney", w - 2.2, 25.5, 0.5, w - 0.6, 30.4, 1.6, rgb(206, 190, 166), { studs = true, decor = true })
		Bx(m, frame, "ChimneyPots", w - 2.05, 30.4, 0.75, w - 0.75, 31.0, 1.35, rgb(190, 95, 60), dk)
		Bx(m, frame, "ChimneyBack", 0.5, 27.4, D - 4.4, 2.1, 31.2, D - 3.0, rgb(206, 190, 166), { studs = true, decor = true })
		Bx(m, frame, "ChimneyBackCap", 0.4, 31.2, D - 4.5, 2.2, 31.5, D - 2.9, snowy(SNOW, rgb(190, 95, 60)), dk)
	end
	local doors = { SAPIN, BORDEAUX, rgb(30, 42, 80), rgb(28, 28, 32) }
	local houses = {   -- trois immeubles de chaque côté des magasins, sur chaque trottoir
		{ "N", XH, 455 }, { "N", 455, 467.5, { "BAKERY", rgb(120, 70, 40), rgb(236, 220, 186) } }, { "N", 467.5, 480 },
		{ "N", 520, 535.2, { "FLORIST", rgb(46, 92, 64), rgb(236, 130, 160) } }, { "N", 535.2, 550.4, { "CAFÉ", rgb(120, 28, 36), rgb(178, 34, 44) } },
		{ "N", 550.4, XE, { "CHOCOLATES", rgb(84, 50, 34), rgb(232, 196, 170) } },
		{ "S", XH, 455 }, { "S", 455, 467.5, { "BOOKSHOP", rgb(30, 50, 96), rgb(70, 110, 170) } }, { "S", 467.5, 480 },
		{ "S", 520, 535.2, { "CHEESE SHOP", rgb(150, 112, 40), rgb(60, 110, 70) } }, { "S", 535.2, 550.4, { "PASTRY SHOP", rgb(170, 70, 100), rgb(250, 214, 226) } },
		{ "S", 550.4, XE },
	}
	for i, h in houses do
		local side, x0, x1, shop = h[1], h[2], h[3], h[4]
		local frame = (side == "N") and CFrame.new(x0, 0, 19.85) or (CFrame.new(x1, 0, -19.85) * CFrame.Angles(0, math.pi, 0))
		house("Haussmann_" .. side .. i, frame, x1 - x0, {
			stone = stones[(i - 1) % #stones + 1], door = doors[(i - 1) % #doors + 1],
			shop = shop and { text = shop[1], color = shop[2], awning = shop[3] } or nil,
		})
	end

	-- 5c) Terrasse du café (tables et chaises sans collision, sur le trottoir nord, devant le café)
	local T = folder("CafeTerrace")
	local rattan, bistro = rgb(196, 160, 104), rgb(40, 40, 44)
	for i, tx in { 539.4, 543.4, 547.4 } do
		local tz = 17.9
		vcyl(T, "TableTop_" .. i, tx, 2.45, 2.57, tz, 1.5, snowy(SNOW, rgb(236, 232, 222)), { decor = true })
		vcyl(T, "TableLeg_" .. i, tx, 0.3, 2.45, tz, 0.2, bistro, { decor = true })
		for k, sx in { -1, 1 } do
			local cx, nm = tx + sx * 1.3, "Chair_" .. i .. "_" .. k
			Bx(T, W, nm .. "_Seat", cx - 0.45, 1.45, tz - 0.45, cx + 0.45, 1.59, tz + 0.45, snowy(SNOW, rattan), { decor = true })
			Bx(T, W, nm .. "_Back", cx + sx * 0.39 - 0.06, 1.59, tz - 0.45, cx + sx * 0.39 + 0.06, 2.75, tz + 0.45, rattan, { decor = true })
			Bx(T, W, nm .. "_LegsX", cx - 0.38, 0.3, tz - 0.04, cx + 0.38, 1.45, tz + 0.04, bistro, { decor = true, noShadow = true })
			Bx(T, W, nm .. "_LegsZ", cx - 0.04, 0.3, tz - 0.38, cx + 0.04, 1.45, tz + 0.38, bistro, { decor = true, noShadow = true })
		end
	end

	-- 5d) Mobilier de la rue : réverbères, colonnes d'affiches, fontaine, potelets (hors de la chaussée, à l'écart
	--     des auvents des boutiques)
	local D = folder("Props")
	local function lamp(name, x, z)
		local m = Instance.new("Model"); m.Name = name; m.Parent = D
		vcyl(m, "Base", x, 0.3, 1.4, z, 0.95, green)
		vcyl(m, "Pole", x, 1.4, 8.7, z, 0.34, green)
		vcyl(m, "Collar", x, 3.1, 3.4, z, 0.55, green, { decor = true })
		Bx(m, W, "Crown", x - 0.42, 8.7, z - 0.42, x + 0.42, 8.95, z + 0.42, green, { decor = true })
		local glow = Bx(m, W, "Lantern", x - 0.36, 8.95, z - 0.36, x + 0.36, 10.1, z + 0.36, rgb(255, 222, 160), { mat = Enum.Material.Glass, decor = true, noShadow = true })
		local pl = Instance.new("PointLight"); pl.Color = rgb(255, 214, 150); pl.Range = 22; pl.Brightness = 1.1; pl.Shadows = false; pl.Parent = glow
		nightLantern(glow, pl)
		Bx(m, W, "LanternRoof", x - 0.55, 10.1, z - 0.55, x + 0.55, 10.4, z + 0.55, snowy(SNOW, green), { decor = true })
		Bx(m, W, "Finial", x - 0.1, 10.4, z - 0.1, x + 0.1, 10.9, z + 0.1, GOLD, { decor = true })
	end
	for tag, xs in { N = { 461.2, 536.2, 557.9 }, S = { 461.2, 537.5 } } do
		local s = (tag == "N") and 1 or -1
		for i, x in xs do lamp("Lamp_" .. tag .. i, x, s * 16.2) end
	end
	local function morris(name, x, z, posters)
		local m = Instance.new("Model"); m.Name = name; m.Parent = D
		vcyl(m, "Base", x, 0.3, 0.8, z, 2.0, green)
		vcyl(m, "Body", x, 0.8, 6.0, z, 1.7, rgb(232, 222, 196))
		vcyl(m, "Ring", x, 1.5, 1.7, z, 1.78, green, { decor = true })
		vcyl(m, "Cornice", x, 6.0, 6.45, z, 2.05, green, { decor = true })
		ball(m, "Dome", x, 6.45, z, 1.9, snowy(SNOW, green), { decor = true })
		vcyl(m, "Finial", x, 7.25, 7.9, z, 0.22, green, { decor = true })
		for k, p in posters do
			local c = Vector3.new(x, 3.9, z) + p[1] * 0.87
			local pp = P(m, "Poster_" .. k, CFrame.lookAt(c, c + p[1]), Vector3.new(1.05, 3.6, 0.04), p[2], { decor = true })
			label(pp, Enum.NormalId.Front, p[3], p[4], 60, rgb(20, 20, 20), SERIF)
		end
	end
	morris("MorrisColumn_N", 473.7, 17.4, {
		{ Vector3.new(0, 0, -1), rgb(176, 40, 44), "THEATRE\nTONIGHT", rgb(250, 240, 210) },
		{ Vector3.new(1, 0, 0), rgb(240, 200, 70), "GRAND\nBALL", rgb(30, 30, 34) },
	})
	morris("MorrisColumn_S", 557.9, -17.4, {
		{ Vector3.new(0, 0, 1), rgb(40, 70, 130), "OPERA", rgb(250, 240, 210) },
		{ Vector3.new(-1, 0, 0), rgb(230, 120, 60), "CIRCUS", rgb(30, 30, 34) },
	})
	do
		local m = Instance.new("Model"); m.Name = "Fountain"; m.Parent = D
		local x, z = 473.7, -16.4
		vcyl(m, "Base", x, 0.3, 0.9, z, 1.7, green)
		vcyl(m, "Column", x, 0.9, 3.4, z, 0.6, green)
		for k, c in { { 0.42, 0.42 }, { -0.42, 0.42 }, { 0.42, -0.42 }, { -0.42, -0.42 } } do
			vcyl(m, "Caryatid_" .. k, x + c[1], 1.0, 3.4, z + c[2], 0.26, green, { decor = true })
		end
		vcyl(m, "Canopy", x, 3.4, 3.65, z, 1.8, green, { decor = true })
		ball(m, "Dome", x, 3.65, z, 1.4, snowy(SNOW, green), { decor = true })
		vcyl(m, "Finial", x, 4.2, 4.65, z, 0.2, green, { decor = true })
	end
	for _, s in { 1, -1 } do
		local tag = s > 0 and "N" or "S"
		for k, x in { 523.8, 525.2, 532.8, 534.2 } do
			local nm = "Bollard_" .. tag .. k
			vcyl(D, nm, x, 0.3, 2.3, s * 15.9, 0.34, rgb(74, 56, 40))
			ball(D, nm .. "_Top", x, 2.35, s * 15.9, 0.42, snowy(SNOW, rgb(74, 56, 40)), { decor = true })
		end
	end

	-- 5e) Quartier derrière et à côté des magasins. Immeubles du quartier : volume de pierre, corniche, toit mansardé
	--     enneigé sur les quatre côtés (brisis et terrasson), deux souches de cheminée ; sur les faces vues, une trame
	--     de fenêtres en peu de pièces (un vitrage, des trumeaux, deux bandeaux, un balcon filant). Cours plantées,
	--     boulevard arrière au sud, derrière l'antiquaire.
	local Q = folder("District")
	local function trame(m, fr, w, stone, fc)
		local bays = math.max(3, math.floor(w / 3.6))
		local pitch = w / bays
		local th = { decor = true }
		Bx(m, fr, "Glazing_" .. fc, 0, 2.0, -0.05, w, 21.8, 0.02, glassD, { decor = true, mat = Enum.Material.Glass })
		for k = 0, bays do
			local a = (k == 0) and -0.02 or (k * pitch - pitch * 0.27)
			local b = (k == bays) and (w + 0.02) or (k * pitch + pitch * 0.27)
			Bx(m, fr, "Pier_" .. fc .. "_" .. k, a, 2.0, -0.13, b, 21.8, 0, stone, th)
		end
		Bx(m, fr, "BandLow_" .. fc, -0.02, 8.4, -0.15, w + 0.02, 12.0, 0, stone, th)
		Bx(m, fr, "BandHigh_" .. fc, -0.02, 17.2, -0.15, w + 0.02, 18.6, 0, trimC, th)
		Bx(m, fr, "Balcony_" .. fc, 0.3, 12.0, -1.1, w - 0.3, 12.4, -0.15, trimC, th)
		Bx(m, fr, "BalconyRail_" .. fc, 0.35, 13.5, -1.06, w - 0.35, 13.65, -0.94, IRON, th)
	end
	local function block(name, x0, x1, z0, z1, opt)
		local m = Instance.new("Model"); m.Name = name; m.Parent = Q
		local H, stone = opt.h or 23.2, opt.stone
		Bx(m, W, "Body", x0, 0, z0, x1, H, z1, stone, { studs = true, decor = true })
		Bx(m, W, "Cornice", x0 - 0.35, H, z0 - 0.35, x1 + 0.35, H + 0.5, z1 + 0.35, trimC, { decor = true })
		local y0, y1, d = H + 0.5, H + 5, 2.2
		local cy, roofC = (y0 + y1) / 2, snowy(SNOW, ZINC)
		local function brisis(nm, cf, len)
			P(m, nm, cf, Vector3.new(len, y1 - y0, d), roofC, { shape = Enum.PartType.Wedge, studs = true, decor = true })
		end
		brisis("Mansard_S", CFrame.new((x0 + x1) / 2, cy, z0 + d / 2), x1 - x0)
		brisis("Mansard_N", CFrame.new((x0 + x1) / 2, cy, z1 - d / 2) * CFrame.Angles(0, math.pi, 0), x1 - x0)
		brisis("Mansard_W", CFrame.new(x0 + d / 2, cy, (z0 + z1) / 2) * CFrame.Angles(0, math.pi / 2, 0), z1 - z0)
		brisis("Mansard_E", CFrame.new(x1 - d / 2, cy, (z0 + z1) / 2) * CFrame.Angles(0, -math.pi / 2, 0), z1 - z0)
		Bx(m, W, "RoofTop", x0 + d - 0.05, y0, z0 + d - 0.05, x1 - d + 0.05, y1, z1 - d + 0.05, roofC, { studs = true, decor = true })
		for k, f in { 0.27, 0.73 } do
			local cx = x0 + (x1 - x0) * f
			local cz = z0 + (z1 - z0) * ((k == 1) and 0.38 or 0.62)
			Bx(m, W, "Chimney_" .. k, cx - 1.5, y1 - 0.4, cz - 0.6, cx + 1.5, y1 + 2.6, cz + 0.6, rgb(206, 190, 166), { studs = true, decor = true })
			Bx(m, W, "ChimneyCap_" .. k, cx - 1.62, y1 + 2.6, cz - 0.72, cx + 1.62, y1 + 2.9, cz + 0.72, snowy(SNOW, rgb(190, 95, 60)), { decor = true })
		end
		for _, fc in opt.faces or {} do
			local fr, w
			if fc == "S" then fr, w = CFrame.new(x0, 0, z0), x1 - x0
			elseif fc == "N" then fr, w = CFrame.new(x1, 0, z1) * CFrame.Angles(0, math.pi, 0), x1 - x0
			elseif fc == "W" then fr, w = CFrame.new(x0, 0, z1) * CFrame.Angles(0, math.pi / 2, 0), z1 - z0
			else fr, w = CFrame.new(x1, 0, z0) * CFrame.Angles(0, -math.pi / 2, 0), z1 - z0 end
			trame(m, fr, w, stone, fc)
		end
		return m
	end
	-- à côté des magasins (cours de 7 u entre les immeubles sur rue et ceux-ci), le dôme doré tient le coin sud-ouest
	block("Building_NW1", XH, 460.2, 40, 66, { h = 24.2, stone = stones[2], faces = { "W", "N" } })
	block("Building_NW2", 461.2, 479, 40, 66, { h = 22.8, stone = stones[5], faces = { "N" } })
	block("Building_NE1", 521, 542.3, 40, 66, { h = 23.2, stone = stones[4], faces = { "N" } })
	block("Building_NE2", 543.3, XB - 1.5, 40, 66, { h = 24.6, stone = stones[6], faces = { "E", "N" } })
	block("Building_SE1", 521, 542.3, -66, -40, { h = 23.8, stone = stones[1], faces = { "S" } })
	block("Building_SE2", 543.3, XB - 1.5, -66, -40, { h = 22.4, stone = stones[3], faces = { "E", "S" } })
	for i, t in { { 450.5, 36.6 }, { 470.5, 36.6 }, { 532, 36.6 }, { 555, 36.6 }, { 532, -36.6 }, { 555, -36.6 }, { 476.8, -36.4 }, { 444.5, -36.6 } } do
		treeS(Q, "YardTree_" .. i, t[1], t[2], 0.85)
	end
	-- boulevard arrière au sud (trottoirs, chaussée enneigée, arbres, réverbères), puis une rangée d'immeubles
	Bx(Q, W, "Boulevard_SidewalkA", XA, 0, -71, XB, 0.3, -68.5, pave, { studs = true })
	Bx(Q, W, "Boulevard_KerbA", XA, 0, -71.4, XB, 0.3, -71, rgb(188, 186, 180), { studs = true })
	Bx(Q, W, "Boulevard_Roadway", XA, 0, -76.6, XB, 0.03, -71.4, rgb(104, 108, 118), { studs = true, decor = true, noShadow = true })
	Bx(Q, W, "Boulevard_KerbB", XA, 0, -77, XB, 0.3, -76.6, rgb(188, 186, 180), { studs = true })
	Bx(Q, W, "Boulevard_SidewalkB", XA, 0, -79.5, XB, 0.3, -77, pave, { studs = true })
	if SNOWY then
		for i, band in { { -72.6, -72.0 }, { -74.6, -73.4 }, { -76.0, -75.4 } } do
			Bx(Q, W, "Boulevard_Snow" .. i, XA, 0.03, band[1], XB, 0.05, band[2], SNOW, { decor = true, noShadow = true, studs = true })
		end
	end
	for k, x in { 450, 470.5, 491, 511.5, 532, 552.5 } do treeS(Q, "BoulevardTree_A" .. k, x, -70.3, 0.8) end
	for k, x in { 460, 480.5, 501, 521.5, 542, 562.5 } do treeS(Q, "BoulevardTree_B" .. k, x, -78.2, 0.8) end
	for k, x in { 450.2, 491.2, 532.2 } do lampS(Q, "BoulevardLamp_" .. k, x, -78.4) end
	for i, b in { { XA + 0.5, 462.2, 23.2 }, { 462.2, 483, 21.8 }, { 483, 503.8, 24.4 }, { 503.8, 524.6, 22.6 }, { 524.6, 545.4, 23.6 }, { 545.4, XB - 0.5, 22.2 } } do
		block("BackRow_" .. i, b[1], b[2], -ZD + 0.5, -79.5, { h = b[3], stone = stones[i % #stones + 1], faces = { "N" } })
	end

	-- 5f) Jardin du Champ de Mars, derrière la galerie, jusqu'à la tour : allée de gravier dans l'axe de la tour,
	--     pelouses enneigées, haies, arbres, réverbères, bancs, manège
	local Gd = folder("Garden")
	local gravel = rgb(198, 186, 162)
	local ax2 = XC + ((ZONE_X0 + ZONE_X1) / 2 - XW) / K   -- axe du jardin et de la tour : le milieu de la zone (monde x 624)
	Bx(Gd, W, "Alley", ax2 - 5.3, 0, 68.5, ax2 + 5.3, 0.03, 97.3, gravel, { decor = true, noShadow = true })
	Bx(Gd, W, "TowerPlaza", ax2 - 41, 0, 97.3, ax2 + 41, 0.03, 175.5, gravel, { decor = true, noShadow = true })
	for i, s in { -1, 1 } do
		local hx = ax2 + s * 6.6
		for k, zz in { { 71, 81.5 }, { 84.5, 95 } } do
			local nm = "Hedge_" .. i .. k
			Bx(Gd, W, nm, hx - 0.9, 0, zz[1], hx + 0.9, 1.5, zz[2], rgb(36, 78, 54), { decor = true })
			if SNOWY then Bx(Gd, W, nm .. "_Snow", hx - 0.85, 1.5, zz[1] + 0.05, hx + 0.85, 1.72, zz[2] - 0.05, SNOW, { decor = true }) end
		end
	end
	for k, t in { { 447, 72 }, { 447, 81 }, { 447, 90 }, { 561.5, 72 }, { 561.5, 81 }, { 561.5, 90 }, { ax2 - 11, 75 }, { ax2 - 11, 91 },
		{ ax2 + 11, 75 }, { ax2 + 11, 91 }, { 447, 108 }, { 447, 130 }, { 447, 152 }, { 561.5, 108 }, { 561.5, 130 }, { 561.5, 152 } } do
		treeS(Gd, "Tree_" .. k, t[1], t[2])
	end
	for k, l in { { ax2 - 4.6, 75 }, { ax2 + 4.6, 75 }, { ax2 - 4.6, 91 }, { ax2 + 4.6, 91 } } do lampS(Gd, "Lamp_" .. k, l[1], l[2]) end
	for k, b in { { ax2 - 4.3, 83, 1 }, { ax2 + 4.3, 83, -1 }, { ax2 - 4.3, 95.6, 1 }, { ax2 + 4.3, 95.6, -1 } } do
		local m = Instance.new("Model"); m.Name = "Bench_" .. k; m.Parent = Gd
		local x, z, dir = b[1], b[2], b[3]
		Bx(m, W, "Seat", x - 0.5, 1.0, z - 1.6, x + 0.5, 1.2, z + 1.6, snowy(SNOW, rgb(110, 80, 50)), { decor = true })
		Bx(m, W, "Back", x - dir * 0.55 - 0.08, 1.2, z - 1.6, x - dir * 0.55 + 0.08, 2.2, z + 1.6, green, { decor = true })
		Bx(m, W, "Legs", x - 0.4, 0, z - 1.4, x + 0.4, 1.0, z + 1.4, IRON, { decor = true, noShadow = true })
	end
	do
		local m = Instance.new("Model"); m.Name = "Carousel"; m.Parent = Gd
		local x, z = 462, 82
		local red, cream = rgb(150, 36, 48), rgb(244, 236, 214)
		vcyl(m, "Platform", x, 0, 0.7, z, 9, red, { decor = true })
		vcyl(m, "PlatformTrim", x, 0.7, 0.85, z, 9.2, GOLD, { decor = true, noShadow = true })
		vcyl(m, "Core", x, 0.85, 7.0, z, 2.4, cream, { decor = true })
		for k = 0, 5 do
			local a = k * math.pi / 3
			local px, pz = x + math.cos(a) * 3.4, z + math.sin(a) * 3.4
			vcyl(m, "Pole_" .. k, px, 0.85, 7.0, pz, 0.2, GOLD, { decor = true, noShadow = true })
			P(m, "Horse_" .. k, CFrame.new(px, 2.4 + (k % 2) * 0.7, pz) * CFrame.Angles(0, -a, 0), Vector3.new(0.5, 1.1, 1.8), (k % 2 == 0) and cream or rgb(90, 60, 40), { decor = true })
		end
		vcyl(m, "CanopyTrim", x, 6.8, 7.0, z, 10.2, GOLD, { decor = true, noShadow = true })
		vcyl(m, "Canopy", x, 7.0, 7.8, z, 10, red, { decor = true })
		vcyl(m, "Roof1", x, 7.8, 8.7, z, 8.2, snowy(SNOW, cream), { decor = true })
		vcyl(m, "Roof2", x, 8.7, 9.5, z, 5.4, snowy(SNOW, red), { decor = true })
		vcyl(m, "Roof3", x, 9.5, 10.1, z, 2.6, snowy(SNOW, cream), { decor = true })
		vcyl(m, "Finial", x, 10.1, 11.4, z, 0.3, GOLD, { decor = true, noShadow = true })
	end
	do   -- kiosque à musique, de l'autre côté de l'allée
		local m = Instance.new("Model"); m.Name = "Bandstand"; m.Parent = Gd
		local x, z = 546, 82
		vcyl(m, "Base", x, 0, 1.2, z, 9, rgb(222, 212, 190), { decor = true, studs = true })
		vcyl(m, "Floor", x, 1.2, 1.4, z, 9.4, snowy(SNOW, rgb(240, 234, 218)), { decor = true })
		for k = 0, 5 do
			local a = k * math.pi / 3
			vcyl(m, "Column_" .. k, x + math.cos(a) * 4, 1.4, 7.4, z + math.sin(a) * 4, 0.35, green, { decor = true, noShadow = true })
		end
		vcyl(m, "Eave", x, 7.4, 7.9, z, 10, green, { decor = true })
		vcyl(m, "Roof1", x, 7.9, 8.8, z, 8.4, snowy(SNOW, ZINC), { decor = true })
		vcyl(m, "Roof2", x, 8.8, 9.6, z, 5.6, snowy(SNOW, ZINC), { decor = true })
		vcyl(m, "Roof3", x, 9.6, 10.2, z, 2.8, snowy(SNOW, ZINC), { decor = true })
		vcyl(m, "Finial", x, 10.2, 11.4, z, 0.3, GOLD, { decor = true, noShadow = true })
	end

	-- 5g) Repères du quartier (sans collision ni ombre) : la tour Eiffel au bout du Champ de Mars, visible de loin dans
	--     tout le couloir, et le dôme doré dans le coin sud-ouest, à côté de l'antiquaire, près de l'entrée
	local L = folder("Landmarks")
	do
		-- Tour Eiffel (axe x 624 dans le monde, pied à 6 studs du bout du quartier) : quatre piles courbes en treillis
		-- sur leurs grandes arches, 1er étage à frise, 2e étage, flèche en treillis, campanile, antenne, lumières dorées
		-- la nuit. Membrures en pièces ; croisillons du treillis en Beams (des lignes, sans pièce).
		local m = Instance.new("Model"); m.Name = "EiffelTower"; m.Parent = L
		local cx, cz = ax2, ZD + 4 + 38
		local iron, ironL = rgb(92, 74, 58), rgb(126, 102, 80)
		local o = { decor = true, noShadow = true }
		-- demi-largeur extérieure et largeur des piles selon la hauteur (profil concave de la tour)
		local prof = { { 0, 38 }, { 17, 30 }, { 34, 23.6 }, { 52, 17.8 }, { 69, 13.6 }, { 94, 9.4 }, { 120, 6.7 }, { 144, 4.8 }, { 165, 3.5 } }
		local legw = { { 0, 14.5 }, { 17, 11.8 }, { 34, 9.4 }, { 52, 7.9 }, { 69, 6.8 } }
		local function at(t, y)
			for i = 1, #t - 1 do
				local a, b = t[i], t[i + 1]
				if y <= b[1] then return a[2] + (b[2] - a[2]) * (y - a[1]) / (b[1] - a[1]) end
			end
			return t[#t][2]
		end
		local anchor = P(m, "LatticeAnchor", CFrame.new(cx, 1, cz), Vector3.new(1, 1, 1), iron, { decor = true, noShadow = true, T = 1 })
		anchor.CanQuery = false
		local nl = 0
		local function lattice(a, b, wd)
			nl += 1
			local a0 = Instance.new("Attachment"); a0.Name = "A" .. nl; a0.Parent = anchor; a0.WorldPosition = a
			local a1 = Instance.new("Attachment"); a1.Name = "B" .. nl; a1.Parent = anchor; a1.WorldPosition = b
			local bm = Instance.new("Beam"); bm.Name = "Lattice_" .. nl
			bm.Attachment0 = a0; bm.Attachment1 = a1; bm.Width0 = wd; bm.Width1 = wd
			bm.FaceCamera = true; bm.Segments = 1; bm.LightInfluence = 1
			bm.Color = ColorSequence.new(ironL); bm.Transparency = NumberSequence.new(0)
			bm.Parent = anchor
		end
		local function girder(name, a, b, t)   -- prolongée aux deux bouts pour fermer les joints
			local d = (b - a).Unit
			return beam(m, name, a - d * t * 0.4, b + d * t * 0.4, t, iron, o)
		end
		local corners = { { 1, 1 }, { 1, -1 }, { -1, -1 }, { -1, 1 } }
		local faces = { { 1, 0 }, { 0, 1 }, { -1, 0 }, { 0, -1 } }
		local function pt(sx, sz, a, b, y) return Vector3.new(cx + sx * a, y, cz + sz * b) end

		-- Piles : 3 membrures en pièces ; l'arête intérieure et les croix des 4 faces en Beams
		local levels = { 0, 17, 34, 52, 69 }
		for li, c in corners do
			local sx, sz = c[1], c[2]
			for k = 1, #levels - 1 do
				local y0, y1 = levels[k], levels[k + 1]
				local w0, w1 = at(prof, y0), at(prof, y1)
				local i0, i1 = w0 - at(legw, y0), w1 - at(legw, y1)
				local t = 2.1 - 0.3 * k
				local O0, O1 = pt(sx, sz, w0, w0, y0), pt(sx, sz, w1, w1, y1)
				local A0, A1 = pt(sx, sz, w0, i0, y0), pt(sx, sz, w1, i1, y1)
				local B0, B1 = pt(sx, sz, i0, w0, y0), pt(sx, sz, i1, w1, y1)
				local I0, I1 = pt(sx, sz, i0, i0, y0), pt(sx, sz, i1, i1, y1)
				girder("Leg" .. li .. "_Outer_" .. k, O0, O1, t)
				girder("Leg" .. li .. "_SideA_" .. k, A0, A1, t * 0.8)
				girder("Leg" .. li .. "_SideB_" .. k, B0, B1, t * 0.8)
				lattice(I0, I1, t * 0.6)
				for _, f in { { O0, A0, O1, A1 }, { O0, B0, O1, B1 }, { A0, I0, A1, I1 }, { B0, I0, B1, I1 } } do
					lattice(f[1], f[4], 0.34); lattice(f[2], f[3], 0.34); lattice(f[3], f[4], 0.3)
				end
			end
		end

		-- Grandes arches dans le plan de chaque face, sous le 1er étage, et écoinçons ajourés
		local ys, ya = 6, 29.5
		local span = at(prof, ys) - at(legw, ys)
		for fi, n in faces do
			local tx, tz = -n[2], n[1]
			local pts, us = {}, {}
			for k = 0, 6 do
				local th = math.pi * (1 - k / 6)
				local y = ys + (ya - ys) * math.sin(th)
				local u = math.cos(th) * span
				local w = at(prof, y)
				pts[k], us[k] = Vector3.new(cx + n[1] * w + tx * u, y, cz + n[2] * w + tz * u), u
			end
			for k = 1, 6 do girder("Arch_" .. fi .. "_" .. k, pts[k - 1], pts[k], 1.3) end
			local w33 = at(prof, 33)
			for _, k in { 1, 2, 4, 5 } do
				lattice(pts[k], Vector3.new(cx + n[1] * w33 + tx * us[k], 33, cz + n[2] * w33 + tz * us[k]), 0.45)
			end
		end

		-- 1er étage (plancher et frise) et 2e étage (plancher et garde-corps)
		local d1, d2 = at(prof, 34) + 1.2, at(prof, 69) + 0.9
		local deck1 = Bx(m, W, "Deck1", cx - d1, 33, cz - d1, cx + d1, 34.8, cz + d1, iron, o)
		local deck2 = Bx(m, W, "Deck2", cx - d2, 68.2, cz - d2, cx + d2, 69.6, cz + d2, iron, o)
		for fi, n in faces do
			local function band(name, d, y0, y1, th)
				local sizeX = (n[1] ~= 0) and th or 2 * d
				local sizeZ = (n[1] ~= 0) and 2 * d or th
				return P(m, name, CFrame.new(cx + n[1] * d, (y0 + y1) / 2, cz + n[2] * d), Vector3.new(sizeX, y1 - y0, sizeZ), ironL, o)
			end
			band("Frieze1_" .. fi, d1, 34.8, 37.8, 0.4)
			band("Rail2_" .. fi, d2, 69.6, 71.2, 0.3)
		end

		-- Flèche : 4 membrures par tronçon, deux étages de croix par face
		local slev = { 69, 94, 120, 144, 165 }
		for k = 1, #slev - 1 do
			local y0, y1 = slev[k], slev[k + 1]
			local ym = (y0 + y1) / 2
			local w0, w1, wm = at(prof, y0), at(prof, y1), at(prof, ym)
			local C0, C1, M = {}, {}, {}
			for ci, c in corners do
				C0[ci], C1[ci], M[ci] = pt(c[1], c[2], w0, w0, y0), pt(c[1], c[2], w1, w1, y1), pt(c[1], c[2], wm, wm, ym)
				girder("Spire_" .. ci .. "_" .. k, C0[ci], C1[ci], 1.5 - 0.22 * k)
			end
			for ci = 1, 4 do
				local cj = ci % 4 + 1
				lattice(C0[ci], M[cj], 0.28); lattice(C0[cj], M[ci], 0.28)
				lattice(M[ci], C1[cj], 0.26); lattice(M[cj], C1[ci], 0.26)
				lattice(M[ci], M[cj], 0.22); lattice(C1[ci], C1[cj], 0.34)
			end
		end

		-- Sommet : plate-forme, campanile, mât et antenne, feu ; lumières dorées (visibles la nuit)
		local d3 = at(prof, 165) + 0.7
		Bx(m, W, "TopDeck", cx - d3, 164.4, cz - d3, cx + d3, 165.6, cz + d3, iron, o)
		local cab = Bx(m, W, "Campanile", cx - 2.4, 165.6, cz - 2.4, cx + 2.4, 170.6, cz + 2.4, ironL, o)
		Bx(m, W, "CampanileRoof", cx - 1.7, 170.6, cz - 1.7, cx + 1.7, 172.2, cz + 1.7, snowy(SNOW, iron), o)
		vcyl(m, "Mast", cx, 172.2, 186, cz, 0.9, iron, o)
		vcyl(m, "Antenna", cx, 186, 198, cz, 0.4, rgb(214, 214, 218), o)
		local beacon = ball(m, "Beacon", cx, 198.4, cz, 1.1, rgb(255, 214, 140), { decor = true, noShadow = true, mat = Enum.Material.Neon })
		for _, lp in { { deck1, 45 }, { deck2, 32 }, { cab, 24 }, { beacon, 16 } } do
			local pl = Instance.new("PointLight"); pl.Color = rgb(255, 200, 120); pl.Range = lp[2]; pl.Brightness = 2; pl.Shadows = false; pl.Parent = lp[1]
		end
	end
	do
		local m = Instance.new("Model"); m.Name = "GoldenDome"; m.Parent = L
		local x, z = 461, -46
		local stoneC, goldC = rgb(222, 212, 190), rgb(214, 172, 70)
		local o = { decor = true, noShadow = true, studs = true }
		local oS = { decor = true, noShadow = true }
		vcyl(m, "Plaza", x, 0, 0.04, z, 25.5, rgb(214, 206, 188), oS)
		vcyl(m, "Drum", x, 0, 34, z, 18, stoneC, o)
		vcyl(m, "Stylobate", x, 33, 34.5, z, 21, rgb(232, 224, 204), o)
		vcyl(m, "InnerDrum", x, 34.5, 46.6, z, 17.5, stoneC, o)
		for k = 0, 11 do
			local a = k * math.pi / 6
			vcyl(m, "Column_" .. (k + 1), x + math.cos(a) * 9.6, 34.5, 45, z + math.sin(a) * 9.6, 1.0, rgb(240, 234, 216), oS)
		end
		vcyl(m, "Entablature", x, 45, 46.6, z, 21, rgb(232, 224, 204), o)
		vcyl(m, "Attic", x, 46.6, 48.5, z, 18.6, stoneC, o)
		ball(m, "Dome", x, 48.5, z, 18, goldC, oS)
		if SNOWY then ball(m, "DomeSnow", x, 52, z, 13, SNOW, oS) end   -- calotte de neige
		vcyl(m, "Lantern", x, 57, 61, z, 3, stoneC, oS)
		ball(m, "LanternDome", x, 61, z, 3, goldC, oS)
		vcyl(m, "Spire", x, 62, 69, z, 0.5, goldC, oS)
	end

	-- 5h) Entrée de la zone, sous l'arche ZoneGate_5 (monde x 530 ; en u, son linteau est à x XA ± 1,
	--     y 18..24) : neige et stalactites de glace sur l'arche, trois flocons lumineux au-dessus (visibles de loin
	--     dans le couloir), candélabres à trois lanternes, sapins enneigés en bacs, congères au pied des piliers,
	--     plaques « WELCOME TO PARIS ». Rien n'est accroché à l'arche : ce sont des pièces à part, posées dessus.
	local E = folder("Entrance")
	local function candelabra(name, x, z)
		local m = Instance.new("Model"); m.Name = name; m.Parent = E
		vcyl(m, "Base", x, 0.3, 1.9, z, 1.5, green)
		vcyl(m, "Pole", x, 1.9, 10.6, z, 0.5, green)
		Bx(m, W, "Arms", x - 2.1, 10.2, z - 0.13, x + 2.1, 10.45, z + 0.13, green, { decor = true })
		for k, l in { { x - 1.95, 10.45 }, { x + 1.95, 10.45 }, { x, 10.6 } } do
			local glow = Bx(m, W, "Lantern_" .. k, l[1] - 0.38, l[2], z - 0.38, l[1] + 0.38, l[2] + 1.15, z + 0.38, rgb(255, 222, 160), { mat = Enum.Material.Glass, decor = true, noShadow = true })
			Bx(m, W, "LanternRoof_" .. k, l[1] - 0.55, l[2] + 1.15, z - 0.55, l[1] + 0.55, l[2] + 1.45, z + 0.55, snowy(SNOW, green), { decor = true })
			local pl = nil
			if k == 3 then
				pl = Instance.new("PointLight"); pl.Color = rgb(255, 214, 150); pl.Range = 24; pl.Brightness = 1.2; pl.Shadows = false; pl.Parent = glow
			end
			nightLantern(glow, pl)
		end
		Bx(m, W, "Finial", x - 0.1, 12.05, z - 0.1, x + 0.1, 12.6, z + 0.1, GOLD, { decor = true })
	end
	local function fir(name, x, z)
		local m = Instance.new("Model"); m.Name = name; m.Parent = E
		Bx(m, W, "Planter", x - 1.3, 0.3, z - 1.3, x + 1.3, 1.5, z + 1.3, rgb(94, 64, 40), { studs = true })
		Bx(m, W, "PlanterTop", x - 1.2, 1.5, z - 1.2, x + 1.2, 1.6, z + 1.2, snowy(SNOW, rgb(70, 52, 38)), { decor = true })
		local y = 1.6
		for k, d in { 3.4, 2.7, 2.0, 1.3 } do
			vcyl(m, "Tier_" .. k, x, y, y + 1.35, z, d, rgb(30, 70, 50), { decor = true })
			vcyl(m, "TierSnow_" .. k, x, y + 1.35, y + 1.5, z, d * 0.86, snowy(SNOW, rgb(40, 88, 60)), { decor = true })
			y += 1.1
		end
		ball(m, "Tip", x, y + 0.55, z, 0.7, snowy(SNOW, rgb(30, 70, 50)), { decor = true })
	end
	local porch = (XH + 455) / 2   -- porte cochère du premier immeuble de chaque trottoir
	for _, s in { 1, -1 } do
		local tag = s > 0 and "N" or "S"
		candelabra("Candelabra_" .. tag, XA + 3.87, s * 17.6)
		fir("Fir_" .. tag, XA + 7.67, s * 18.2)
		-- plaque de rue bleue au-dessus de la porte cochère du premier immeuble
		local fr = (s > 0) and CFrame.new(porch - 2.5, 0, 19.85) or (CFrame.new(porch + 2.5, 0, -19.85) * CFrame.Angles(0, math.pi, 0))
		Bx(E, fr, "WelcomeRim_" .. tag, 0, 9.75, -0.14, 5, 11.45, 0, rgb(40, 120, 90), { decor = true })
		local wp = Bx(E, fr, "WelcomePlaque_" .. tag, 0.1, 9.85, -0.2, 4.9, 11.35, -0.14, rgb(26, 58, 128), { decor = true })
		label(wp, Enum.NormalId.Front, "WELCOME TO\nPARIS", rgb(255, 255, 255), 60, rgb(26, 58, 128))
		if SNOWY then
			ball(E, "PillarSnow_" .. tag .. "1", XA + 1.67, 0.1, s * 18.9, 2.6, SNOW, { decor = true, noShadow = true })
			ball(E, "PillarSnow_" .. tag .. "2", XA + 3.07, 0.0, s * 19.4, 1.6, SNOW, { decor = true, noShadow = true })
		end
	end
	if SNOWY then
		local ax = XA   -- milieu de l'arche
		Bx(E, W, "ArchSnow", ax - 1.13, 24, -23.2, ax + 1.13, 24.35, 23.2, SNOW, { decor = true, studs = true })
		P(E, "ArchSnowRoll", CFrame.new(ax, 24.35, 0) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(46.2, 1.5, 1.5), SNOW, { shape = Enum.PartType.Cylinder, decor = true })
		local ice = rgb(214, 236, 250)
		local lens = { 1.6, 0.9, 1.3, 0.7, 1.5, 1.0, 1.4, 0.8 }
		for f, fx in { ax - 1.09, ax + 1.09 } do
			for k, zc in { -17.5, -12.4, -7.1, -2.2, 2.9, 7.8, 12.6, 17.7 } do
				local len = lens[(k + f) % #lens + 1]
				Bx(E, W, "Icicle_" .. f .. "_" .. k, fx - 0.08, 18 - len, zc - 0.08, fx + 0.08, 18, zc + 0.08, ice, { decor = true, noShadow = true, mat = Enum.Material.Ice, T = 0.15 })
			end
		end
		local cold = rgb(196, 228, 255)
		for k, f in { { -13, 2.6 }, { 0, 3.4 }, { 13, 2.6 } } do
			local zc, r = f[1], f[2]
			local c = Vector3.new(ax, 25.3 + r, zc)
			local nm = "Snowflake_" .. k
			for j = 0, 2 do
				P(E, nm .. "_Arm" .. j, CFrame.new(c) * CFrame.Angles(j * math.pi / 3, 0, 0), Vector3.new(0.3, 2 * r, 0.3), cold, { mat = Enum.Material.Neon, decor = true, noShadow = true })
			end
			local core = ball(E, nm .. "_Core", c.X, c.Y, c.Z, 0.8, rgb(255, 255, 255), { mat = Enum.Material.Neon, decor = true, noShadow = true })
			local pl = Instance.new("PointLight"); pl.Color = cold; pl.Range = 14; pl.Brightness = 1.2; pl.Shadows = false; pl.Parent = core
			vcyl(E, nm .. "_Rod", c.X, 24.6, 25.5, c.Z, 0.18, rgb(200, 210, 220), { decor = true, noShadow = true })
		end
	end

	-- 5i) Neige qui tombe : deux ParticleEmitter (aucun script) dans un volume invisible au-dessus de la rue, de l'arche
	--     au bout de la zone, limité à |z| <= 19 u (monde 28,5) pour que les flocons ne passent pas dans les magasins ;
	--     chute droite, légère dérive le long de la rue (valeurs en u, agrandies par ScaleTo)
	if SNOWY then
		local Wt = folder("Weather")
		local cloud = Bx(Wt, W, "SnowCloud", XA, 45.5, -19, XB, 46.5, 19, SNOW, { decor = true, noShadow = true, T = 1 })
		cloud.CanQuery = false
		local function emitter(name, tex, rate, size, emission)
			local e = Instance.new("ParticleEmitter"); e.Name = name
			e.Texture = tex
			e.Shape = Enum.ParticleEmitterShape.Box; e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
			e.EmissionDirection = Enum.NormalId.Bottom
			e.Rate = rate
			e.Lifetime = NumberRange.new(9.2, 10.2)
			e.Speed = NumberRange.new(4.6, 5.2)
			e.SpreadAngle = Vector2.new(0, 0)
			e.Acceleration = Vector3.new(0.1, 0, 0)
			e.Rotation = NumberRange.new(0, 360); e.RotSpeed = NumberRange.new(-50, 50)
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size, size * 0.35), NumberSequenceKeypoint.new(1, size, size * 0.35) })
			e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.06, 0.05), NumberSequenceKeypoint.new(0.9, 0.05), NumberSequenceKeypoint.new(1, 1) })
			e.Color = ColorSequence.new(rgb(255, 255, 255))
			e.LightEmission = emission; e.LightInfluence = 0.7
			e.Parent = cloud
		end
		emitter("Snowfall", "rbxasset://textures/particles/smoke_main.dds", 260, 0.28, 0.35)
		emitter("SnowGlitter", "rbxasset://textures/particles/sparkles_main.dds", 30, 0.18, 0.7)
	end

	-- Agrandissement ×1.5 de chaque groupe autour de (500, 0, 0), portée des lumières, puis mise en place groupe par groupe
	for _, f in groups do
		f.WorldPivot = CFrame.new(XC, 0, 0)
		f:ScaleTo(K)
		f:PivotTo(CFrame.new(XW, 0, 0))
		for _, l in f:GetDescendants() do
			if l:IsA("Light") then l.Range = math.min(60, l.Range * K) end
		end
		f.Parent = S
		task.wait()
	end
end

-- 6) Vérification en mode Edit : chaque nom du contrat une seule fois, éclats, tag, Zone, colis par Tier ; chemins
--    du vigile (réglages de GuardService) du GuardSpawn vers les 10 colis, puis vers la rue par la vitre (collisions
--    de la vitre coupées le temps du test) ; chaussée sans aucune pièce ; nombre de pièces ; gabarit (arche, greybox,
--    sol du quartier).
local CS = game:GetService("CollectionService")
local PFS = game:GetService("PathfindingService")
local function verify(m)
	local counts = {}
	for _, d in m:GetDescendants() do counts[d.Name] = (counts[d.Name] or 0) + 1 end
	local need = { "Window", "WindowFractured", "Shutter", "Door", "Bounds", "GuardSpawn", "SignPart" }
	for i = 1, 10 do table.insert(need, string.format("ShelfSlot_%02d", i)) end
	local bad = {}
	for _, nm in need do if counts[nm] ~= 1 then table.insert(bad, nm .. " x" .. (counts[nm] or 0)) end end
	local shards = 0
	local wfr = m:FindFirstChild("WindowFractured")
	for _, d in (wfr and wfr:GetDescendants() or {}) do if d:IsA("BasePart") and d.Name:match("^Shard_%d+$") then shards += 1 end end
	local tiers = { Standard = 0, Premium = 0, Luxe = 0 }
	for i = 1, 10 do
		local a = m:FindFirstChild(string.format("ShelfSlot_%02d", i), true)
		local t = a and a:GetAttribute("Tier")
		if t then tiers[t] = (tiers[t] or 0) + 1 end
	end
	local spawnAtt = m:FindFirstChild("GuardSpawn", true)
	if not spawnAtt then return m.Name .. " : GuardSpawn absent, chemins non testés" end
	local path = PFS:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, AgentCanClimb = false, WaypointSpacing = 4 })
	local start = spawnAtt.WorldPosition
	local jumps = 0
	local function reach(goal)
		local ok = pcall(function() path:ComputeAsync(start, goal) end)
		if ok and path.Status == Enum.PathStatus.Success then
			for _, wp in path:GetWaypoints() do if wp.Action == Enum.PathWaypointAction.Jump then jumps += 1 end end
			return true
		end
		return false
	end
	local slotsOk, near = 0, {}
	for i = 1, 10 do
		local a = m:FindFirstChild(string.format("ShelfSlot_%02d", i), true)
		if not a then continue end
		local p, look = a.WorldPosition, a.WorldCFrame.LookVector
		local found = nil
		for _, dist in { 2.5, 3, 3.5, 4, 5 } do
			local g = p + look * dist
			if reach(Vector3.new(g.X, 0.6, g.Z)) then found = dist; break end
		end
		if not found then   -- colis serré (réserve) : le point atteignable le plus proche, à 6 studs au plus
			local cands = {}
			for dx = -6, 6 do
				for dz = -6, 6 do
					local dd = math.sqrt(dx * dx + dz * dz)
					if dd <= 6 then table.insert(cands, { dd, Vector3.new(p.X + dx, 0.6, p.Z + dz) }) end
				end
			end
			table.sort(cands, function(u, v) return u[1] < v[1] end)
			for _, c in cands do if reach(c[2]) then found = c[1]; break end end
			if found then table.insert(near, string.format("%02d à %.1f", i, found)) end
		end
		if found then slotsOk += 1 end
	end
	local win = m:FindFirstChild("Window")
	local okStreet = false
	if win then
		local was = win.CanCollide
		win.CanCollide = false
		local street = (m:GetPivot() * CFrame.new(0, 0, -50)).Position   -- sur la chaussée, à 7,5 studs du trottoir
		okStreet = reach(Vector3.new(street.X, 0.6, street.Z))
		win.CanCollide = was
	end
	local inv = m:GetPivot():Inverse()
	local k = SCALE
	local nIn, nOut, round = 0, 0, 0
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			local q = (inv * d.CFrame).Position
			if math.abs(q.X) <= 19.05 * k and q.Y >= 0.25 * k and q.Y <= 9.95 * k and math.abs(q.Z) <= 23.05 * k then nIn += 1 else nOut += 1 end
			if d:IsA("Part") and (d.Shape == Enum.PartType.Ball or d.Shape == Enum.PartType.Cylinder) then round += 1 end
		end
	end
	return string.format("%s : échelle %.2f, pivot (%.0f, %.0f, %.0f), contrat %s, %d éclats, NPCStore %s, Zone %s, colis %d Standard / %d Premium / %d Luxe ; chemins %d/10 vers les colis%s, rue %s, %d saut(s) ; %d pièces dedans, %d dehors (dont %d boules ou cylindres)",
		m.Name, m:GetScale(), m:GetPivot().X, m:GetPivot().Y, m:GetPivot().Z, (#bad == 0) and "complet" or ("PROBLÈME " .. table.concat(bad, ", ")), shards, tostring(CS:HasTag(m, "NPCStore")), tostring(m:GetAttribute("Zone")),
		tiers.Standard, tiers.Premium, tiers.Luxe, slotsOk, (#near > 0) and (" (au plus près : " .. table.concat(near, ", ") .. ")") or "",
		okStreet and "OK" or "ÉCHEC", jumps, nIn, nOut, round)
end
local lines = { string.format("Zone 5 Paris (gabarit ×%.1f) : galerie %d produits, antiquaire %d produits", SCALE, galleryN, antiqueN) }
table.insert(lines, verify(gallery))
table.insert(lines, verify(antique))
local per, nStreet, nBeams, nEmit, nLights = {}, 0, 0, 0, 0
for _, grp in zoneFolder.Street_Paris:GetChildren() do
	local n = 0
	for _, d in grp:GetDescendants() do
		if d:IsA("BasePart") then n += 1
		elseif d:IsA("Beam") then nBeams += 1
		elseif d:IsA("ParticleEmitter") then nEmit += 1
		elseif d:IsA("Light") then nLights += 1 end
	end
	nStreet += n
	table.insert(per, grp.Name .. " " .. n)
end
-- chaussée : aucune pièce de la zone (avec ou sans collision) entre 0,2 et 15 studs de haut, sur |z| < 22,5
local params = OverlapParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { zoneFolder }
local blocking = {}
for _, p in workspace:GetPartBoundsInBox(CFrame.new((ZONE_X0 + ZONE_X1) / 2, 7.6, 0), Vector3.new(ZONE_X1 - ZONE_X0, 14.8, 44.9), params) do
	table.insert(blocking, p:GetFullName())
end
table.insert(lines, string.format("Street_Paris : %d pièces (%s), %d lignes de treillis (Beams), %d émetteurs de neige, %d lumières ; chaussée %s",
	nStreet, table.concat(per, ", "), nBeams, nEmit, nLights, (#blocking == 0) and "libre" or ("encombrée : " .. table.concat(blocking, ", "))))
-- lanternes NightLight (L-043) : livrées éteintes (pas de Neon, lumières coupées)
local nNight, nNeon, nLit = 0, 0, 0
for _, p in CS:GetTagged("NightLight") do
	if p:IsDescendantOf(zoneFolder) then
		nNight += 1
		if p:IsA("BasePart") and p.Material == Enum.Material.Neon then nNeon += 1 end
		for _, l in p:GetDescendants() do if l:IsA("Light") and l.Enabled then nLit += 1 end end
	end
end
table.insert(lines, string.format("NightLight : %d lanternes, %d en Neon, %d lumières allumées", nNight, nNeon, nLit))
local gz = workspace.Greybox.Corridor.Zone_5
local gate = gz:FindFirstChild("ZoneGate_5")
if gate then
	local gcf, gsz = gate:GetBoundingBox()
	table.insert(lines, string.format("ZoneGate_5 : échelle %.2f, x %.2f, base y %.2f, centre z %.2f, hauteur %.1f, tag ZoneGate %s",
		gate:GetScale(), gcf.Position.X, gcf.Position.Y - gsz.Y / 2, gcf.Position.Z, gsz.Y, tostring(CS:HasTag(gate, "ZoneGate"))))
end
local function span(p)
	local a, b = p.Position - p.Size / 2, p.Position + p.Size / 2
	return string.format("%s x %.1f..%.1f z %.2f..%.2f h %.2f", p.Name, a.X, b.X, a.Z, b.Z, p.Size.Y)
end
local gr, dg = gz.Ground, zoneFolder.Street_Paris.Ground
local spans = {}
for _, p in { gr.Street, gr.Side_N, gr.Side_S, gr.SideWall_N1, gr.SideWall_N2, gr.SideWall_S1, gr.SideWall_S2, dg.DistrictGround_N, dg.DistrictGround_S, dg.ChampDeMars, dg.Pavement_N } do
	table.insert(spans, span(p))
end
table.insert(lines, "Gabarit : " .. table.concat(spans, " ; "))
return table.concat(lines, "\n")
