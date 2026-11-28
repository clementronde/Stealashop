--!nocheck
-- Police maison en blocs voxel à tenons, et pictogrammes en pixels (règle du chef DA : da-enseignes-sans-slop.md, 28/11).
-- Une lettre = une grille de 5 × 7 cubes. Le mot est fait de blocs d'une couleur, en relief (ou en Neon), posés sur un
-- contour sombre du jeu (#040435) d'un cube tout autour, un peu en retrait. Les cubes voisins de même couleur sont
-- fusionnés en rectangles (peu de pièces), avec la matière Studs.
-- À charger d'abord dans Studio (MCP execute_luau, Edit) ; il ne pose rien lui-même, il remplit _G.LettresVoxel :
--   LettresVoxel.mot(parent, "SWEETS", repere, options) → Model, largeur, hauteur
--   LettresVoxel.pixels(parent, lignes, palette, repere, options) → Model, largeur, hauteur
--   LettresVoxel.surFace(parent, piece, Enum.NormalId, nom_du_picto, options) → { Model } (picto de LV.PICTOS à la
--   taille de la face, répété le long d une face allongée)
-- repere : CFrame au centre du mot, sur la surface du mur. Construire avec LettresVoxel.face(centre, normale) : sa
-- LookVector entre dans le mur, sa RightVector est la droite du lecteur, son UpVector le haut ; les blocs sortent vers
-- le lecteur (+Z local).
-- options : px (taille d'un cube, 0,5 par défaut), profondeur (en cubes, 1), couleur, neon (booléen), contour (couleur,
-- false pour aucun), ecart (retrait au mur, 0,03), espace (cubes entre deux lettres, 1), nom.
-- lignes (pictos) : chaînes de même longueur, un caractère par cube ; « . » = vide ; palette = { [caractère] = Color3 }.

local LV = {}
local OUTLINE = Color3.fromHex("040435")

LV.FONT = {
	A = { ".XXX.", "X...X", "X...X", "XXXXX", "X...X", "X...X", "X...X" },
	B = { "XXXX.", "X...X", "X...X", "XXXX.", "X...X", "X...X", "XXXX." },
	C = { ".XXX.", "X...X", "X....", "X....", "X....", "X...X", ".XXX." },
	D = { "XXXX.", "X...X", "X...X", "X...X", "X...X", "X...X", "XXXX." },
	E = { "XXXXX", "X....", "X....", "XXXX.", "X....", "X....", "XXXXX" },
	F = { "XXXXX", "X....", "X....", "XXXX.", "X....", "X....", "X...." },
	G = { ".XXX.", "X...X", "X....", "X.XXX", "X...X", "X...X", ".XXXX" },
	H = { "X...X", "X...X", "X...X", "XXXXX", "X...X", "X...X", "X...X" },
	I = { "XXXXX", "..X..", "..X..", "..X..", "..X..", "..X..", "XXXXX" },
	J = { "..XXX", "...X.", "...X.", "...X.", "...X.", "X..X.", ".XX.." },
	K = { "X...X", "X..X.", "X.X..", "XX...", "X.X..", "X..X.", "X...X" },
	L = { "X....", "X....", "X....", "X....", "X....", "X....", "XXXXX" },
	M = { "X...X", "XX.XX", "X.X.X", "X.X.X", "X...X", "X...X", "X...X" },
	N = { "X...X", "X...X", "XX..X", "X.X.X", "X..XX", "X...X", "X...X" },
	O = { ".XXX.", "X...X", "X...X", "X...X", "X...X", "X...X", ".XXX." },
	P = { "XXXX.", "X...X", "X...X", "XXXX.", "X....", "X....", "X...." },
	Q = { ".XXX.", "X...X", "X...X", "X...X", "X.X.X", "X..X.", ".XX.X" },
	R = { "XXXX.", "X...X", "X...X", "XXXX.", "X.X..", "X..X.", "X...X" },
	S = { ".XXXX", "X....", "X....", ".XXX.", "....X", "....X", "XXXX." },
	T = { "XXXXX", "..X..", "..X..", "..X..", "..X..", "..X..", "..X.." },
	U = { "X...X", "X...X", "X...X", "X...X", "X...X", "X...X", ".XXX." },
	V = { "X...X", "X...X", "X...X", "X...X", "X...X", ".X.X.", "..X.." },
	W = { "X...X", "X...X", "X...X", "X.X.X", "X.X.X", "X.X.X", ".X.X." },
	X = { "X...X", "X...X", ".X.X.", "..X..", ".X.X.", "X...X", "X...X" },
	Y = { "X...X", "X...X", ".X.X.", "..X..", "..X..", "..X..", "..X.." },
	Z = { "XXXXX", "....X", "...X.", "..X..", ".X...", "X....", "XXXXX" },
	["0"] = { ".XXX.", "X...X", "X..XX", "X.X.X", "XX..X", "X...X", ".XXX." },
	["1"] = { "..X..", ".XX..", "..X..", "..X..", "..X..", "..X..", ".XXX." },
	["2"] = { ".XXX.", "X...X", "....X", "...X.", "..X..", ".X...", "XXXXX" },
	["3"] = { "XXXXX", "...X.", "..X..", "...X.", "....X", "X...X", ".XXX." },
	["4"] = { "...X.", "..XX.", ".X.X.", "X..X.", "XXXXX", "...X.", "...X." },
	["5"] = { "XXXXX", "X....", "XXXX.", "....X", "....X", "X...X", ".XXX." },
	["6"] = { "..XX.", ".X...", "X....", "XXXX.", "X...X", "X...X", ".XXX." },
	["7"] = { "XXXXX", "....X", "...X.", "..X..", ".X...", ".X...", ".X..." },
	["8"] = { ".XXX.", "X...X", "X...X", ".XXX.", "X...X", "X...X", ".XXX." },
	["9"] = { ".XXX.", "X...X", "X...X", ".XXXX", "....X", "...X.", ".XX.." },
	["$"] = { "..X..", ".XXXX", "X.X..", ".XXX.", "..X.X", "XXXX.", "..X.." },
	[" "] = { "...", "...", "...", "...", "...", "...", "..." },
}

function LV.face(center, normal)
	return CFrame.lookAt(center, center - normal)
end

-- grille de cellules { [ligne][colonne] = clé de couleur }, ligne 1 en haut. Les cubes voisins de même couleur sont
-- fusionnés en rectangles (tronçons d'une ligne, puis tronçons identiques des lignes suivantes) : peu de pièces.
local function build(parent, grid, w, h, colors, frame, opts)
	opts = opts or {}
	local px = opts.px or 0.5
	local depth = (opts.profondeur or 1) * px
	local gap = opts.ecart or 0.03
	local outline = opts.contour
	if outline == nil then outline = OUTLINE end
	local od = outline and px * 0.5 or 0
	local m = Instance.new("Model")
	m.Name = opts.nom or "Enseigne"
	local hasVariant = game:GetService("MaterialService"):FindFirstChild("Studs", true) ~= nil
	local function cube(name, c0, c1, r0, r1, z0, z1, color, neon)
		local wid = (c1 - c0 + 1) * px
		local hgt = (r1 - r0 + 1) * px
		local x = (c0 - 1) * px + wid / 2 - w * px / 2
		local y = h * px / 2 - (r0 - 1) * px - hgt / 2
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Size = Vector3.new(wid, hgt, z1 - z0)
		p.CFrame = frame * CFrame.new(x, y, (z0 + z1) / 2)
		p.Color = color
		p.Material = neon and Enum.Material.Neon or Enum.Material.Plastic
		if hasVariant and not neon then p.MaterialVariant = "Studs" end
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CastShadow = not neon
		p.Parent = m
	end
	-- cellule (r, c) → clé ou nil ; lignes rmin..rmax, colonnes cmin..cmax
	local function emit(get, rmin, rmax, cmin, cmax, name, z0, z1, colorOf, neon)
		local open = {}
		local function close(key)
			local o = open[key]
			cube(name, o.c0, o.c1, o.r0, o.r1, z0, z1, colorOf(o.k), neon)
			open[key] = nil
		end
		for r = rmin, rmax do
			local seen = {}
			local c = cmin
			while c <= cmax do
				local k = get(r, c)
				if k then
					local c1 = c
					while c1 + 1 <= cmax and get(r, c1 + 1) == k do c1 += 1 end
					local key = c .. ":" .. c1 .. ":" .. tostring(k)
					seen[key] = true
					if open[key] then open[key].r1 = r else open[key] = { c0 = c, c1 = c1, r0 = r, r1 = r, k = k } end
					c = c1 + 1
				else
					c += 1
				end
			end
			for key in open do if not seen[key] then close(key) end end
		end
		for key in open do close(key) end
	end
	-- contour : cellules allumées dilatées d'un cube (8 voisins), en retrait derrière les blocs
	if outline then
		local dil = {}
		for r = 0, h + 1 do dil[r] = {} end
		for r = 1, h do for c = 1, w do
			if grid[r] and grid[r][c] then
				for dr = -1, 1 do for dc = -1, 1 do dil[r + dr][c + dc] = true end end
			end
		end end
		emit(function(r, c) return dil[r][c] and "o" or nil end, 0, h + 1, 0, w + 1, "Contour", gap, gap + od, function() return outline end, false)
	end
	emit(function(r, c) return grid[r] and grid[r][c] or nil end, 1, h, 1, w, "Bloc", gap + od, gap + od + depth, function(k) return colors[k] end, opts.neon)
	m.Parent = parent
	return m, (w + (outline and 2 or 0)) * px, (h + (outline and 2 or 0)) * px
end

function LV.mot(parent, text, frame, opts)
	opts = opts or {}
	local sp = opts.espace or 1
	local grid, w = {}, 0
	for r = 1, 7 do grid[r] = {} end
	text = string.upper(text)
	for i = 1, #text do
		local g = LV.FONT[text:sub(i, i)] or LV.FONT[" "]
		local gw = #g[1]
		for r = 1, 7 do
			for c = 1, gw do if g[r]:sub(c, c) ~= "." then grid[r][w + c] = "X" end end
		end
		w += gw + (i < #text and sp or 0)
	end
	opts.nom = opts.nom or ("Mot_" .. text:gsub("%s", "_"))
	return build(parent, grid, w, 7, { X = opts.couleur or Color3.new(1, 1, 1) }, frame, opts)
end

function LV.pixels(parent, rows, palette, frame, opts)
	local grid = {}
	local w = 0
	for r, line in ipairs(rows) do
		grid[r] = {}
		w = math.max(w, #line)
		for c = 1, #line do
			local ch = line:sub(c, c)
			if ch ~= "." and palette[ch] then grid[r][c] = ch end
		end
	end
	return build(parent, grid, w, #rows, palette, frame, opts)
end

-- Bibliothèque de pictos (lignes + palette). Couleurs en hexadécimal ; « . » = vide.
local function P(rows, pal)
	local cp = {}
	for k, v in pal do cp[k] = Color3.fromHex(v) end
	return { rows = rows, pal = cp }
end
LV.PICTOS = {
	sucette = P({ "..PPPPP..", ".PPWWPPP.", "PPWPPWWPP", "PWPPWPPWP", "PWPWPPWPP", "PPWPPWPPP", ".PPWWPPP.", "..PPPPP..", "....S....", "....S....", "....S...." }, { P = "ff6fae", W = "fff6f0", S = "e8e6e0" }),
	ours = P({ "BB.....BB", "BbB...BbB", ".BBBBBBB.", "BBBBBBBBB", "BBKBBBKBB", "BBBBBBBBB", "BBBmmmBBB", ".BBmKmBB.", "..BBBBB.." }, { B = "8b5a2b", b = "d9a066", K = "19191e", m = "f0d2a8" }),
	tour = P({ "...G...", "..SSS..", ".SSSSS.", ".YYYYY.", ".YDDDY.", ".YDKDY.", ".YDDDY.", ".YYYYY.", "YYYYYYY" }, { G = "d4af37", S = "5b6470", Y = "c9a86a", D = "f7ecc8", K = "19191e" }),
	sakura = P({ "...PP....", "..PPPP...", "PP.PP.PP.", "PPPYYPPPP", ".PPYYPPP.", "..PPPPP..", ".PPP.PPP.", ".PP...PP." }, { P = "ff8fc8", Y = "ffd23f" }),
	lanterne = P({ "..KKK..", ".RRRRR.", "RRRRRRR", "RWRRRWR", "RRRRRRR", "RWRRRWR", "RRRRRRR", ".RRRRR.", "..KKK..", "...Y..." }, { R = "e63946", W = "f6e7c8", K = "22203a", Y = "ffd23f" }),
	verre = P({ "PPPPPPPPP", ".PPPPPPP.", "..PPPPP..", "...PPP...", "....S....", "....S....", "....S....", "..SSSSS.." }, { P = "ff3ea5", S = "18e0ff" }),
	micro = P({ "..GGG..", ".GKGKG.", ".GGGGG.", ".GKGKG.", "..GGG..", "...S...", ".S.S.S.", "..SSS..", "...S...", ".SSSSS." }, { G = "18e0ff", K = "22203a", S = "ff3ea5" }),
	ramen = P({ "......Y...Y", ".....Y...Y.", ".SSSSSSSSS.", "RRRRRRRRRRR", "RRWRRRRRWRR", ".RRRRRRRRR.", "..RRRRRRR..", "....RRR...." }, { Y = "f6e7c8", S = "ffd23f", R = "e63946", W = "f6e7c8" }),
	croix = P({ "..GGG..", "..GGG..", "GGGGGGG", "GGGGGGG", "GGGGGGG", "..GGG..", "..GGG.." }, { G = "35d07f" }),
	livre = P({ ".WWWW.WWWW.", "WWWWWBWWWWW", "WKKWWBWKKWW", "WWWWWBWWWWW", "WKKKWBWKKKW", "WWWWWBWWWWW", ".BBBBBBBBB." }, { W = "f6e7c8", B = "6b2bd9", K = "22203a" }),
	appareil = P({ "...KKK.....", "KKKKKKKKKKK", "KWWWWWWWWWK", "KWWWKKKWWWK", "KWWKCCCKWWK", "KWWKCCCKWWK", "KWWWKKKWWWK", "KKKKKKKKKKK" }, { K = "22203a", W = "f2eefc", C = "18e0ff" }),
	sushi = P({ ".OOOOOOO.", "OOWOOWOOO", "OOOOOOOOO", ".WWWKWWW.", "WWWWKWWWW", ".WWWKWWW." }, { O = "ff7a45", W = "f6e7c8", K = "22203a" }),
	manette = P({ ".GGGGGGGGG.", "GGWGGGGGRGG", "GWWWGGGRGRG", "GGWGGGGGRGG", "GGGGGGGGGGG", "GGG.....GGG", ".G.......G." }, { G = "6b2bd9", W = "f2eefc", R = "ff3ea5" }),
	lit = P({ "W..........", "W.PP.......", "WPPPWWWWWWW", "WWWWWWWWWWW", "W.........W", "W.........W" }, { W = "f2eefc", P = "ff8fc8" }),
	eclair = P({ "....YYY", "...YYY.", "..YYY..", ".YYYYYY", "YYYYYY.", "...YYY.", "..YYY..", "..YY...", ".YY....", ".Y....." }, { Y = "ffd23f" }),
	mire = P({ "WWYYCCGGMMRRBB", "WWYYCCGGMMRRBB", "WWYYCCGGMMRRBB", "WWYYCCGGMMRRBB", "WWYYCCGGMMRRBB", "WWYYCCGGMMRRBB", "BBKKMMKKCCKKWW", "BBKKMMKKCCKKWW" }, { W = "f2eefc", Y = "ffd23f", C = "18e0ff", G = "35d07f", M = "ff3ea5", R = "e63946", B = "2b4bd9", K = "22203a" }),
	vaisseau = P({ "..G.....G..", "...G...G...", "..GGGGGGG..", ".GG.GGG.GG.", "GGGGGGGGGGG", "G.GGGGGGG.G", "G.G.....G.G", "...GG.GG..." }, { G = "35d07f" }),
	coeur_piece = P({ ".RR.RR....YYY..", "RRRRRRR..YYYYY.", "RRRRRRR.YYOYOYY", ".RRRRR..YYOYOYY", "..RRR...YYOYOYY", "...R.....YYYYY.", "..........YYY.." }, { R = "ff3ea5", Y = "ffd23f", O = "d4a72c" }),
	diamant = P({ "..WCCCC..", ".WCCCCCC.", "CCCCCCCCC", ".CCCCCCC.", "..CCCCC..", "...CCC...", "....C...." }, { C = "6fd3ff", W = "f2fbff" }),
	fleur = P({ "..PP.PP..", ".PPPPPPP.", "..PPYPP..", ".PPPPPPP.", "..PP.PP..", "....G....", "..GGG....", "....G....", "....G...." }, { P = "ff5d8f", Y = "ffd23f", G = "4f9a3a" }),
	robe = P({ "..K...K..", "..RRRRR..", "...RRR...", "..RRRRR..", ".RRRRRRR.", "RRRRRRRRR", "RRRRRRRRR" }, { R = "ff5d8f", K = "5a5550" }),
	jus = P({ "......S..", ".....S...", ".OOOOOO..", ".OOOOOO..", "..OOOO...", "..OOOO...", "..OOOO..." }, { O = "ff8c42", S = "3bc9db" }),
	burger = P({ "..BBBBB..", ".BBWBWBB.", "GGGGGGGGG", "RRRRRRRRR", "MMMMMMMMM", ".BBBBBBB." }, { B = "e0a050", W = "fff6f0", G = "6bbf3a", R = "e63946", M = "7a3a1e" }),
	sac = P({ "...KKK...", "..K...K..", ".BBBBBBB.", "BBBBBBBBB", "BBBGGBBBB", "BBBBBBBBB", ".BBBBBBB." }, { B = "8b5a2b", K = "5a3a1e", G = "ffd23f" }),
	flacon = P({ "...KK....", "...KK....", "..PPPP...", ".PPPPPP..", ".PPWPPP..", ".PPPPPP..", "..PPPP..." }, { P = "c77dff", W = "f2fbff", K = "d4af37" }),
	chocolat = P({ "BBBBBBB", "BLBLBLB", "BBBBBBB", "BLBLBLB", "BBBBBBB", "BLBLBLB", "BBBBBBB" }, { B = "6b3a1e", L = "8b5a2b" }),
	ciseaux = P({ "K.....K", ".K...K.", "..K.K..", "...K...", "..R.R..", ".R...R.", ".R...R.", "..RRR.." }, { K = "c0c4cc", R = "ff5d8f" }),
	chaussure = P({ "RR.......", "RRR......", "RRRRR....", "RRRRRRRR.", "WWWWWWWWW" }, { R = "e63946", W = "f7f3e8" }),
	tasse = P({ "..S.S...", ".S.S....", "WWWWWW..", "WWWWWWWW", "WWWWWW.W", "WWWWWWWW", ".WWWW...", "BBBBBBB." }, { W = "f7f3e8", S = "c9c2b0", B = "8b5a2b" }),
	planche = P({ "...OO...", "..OOOO..", "..OWWO..", "..OOOO..", "..OWWO..", "..OOOO..", "..OWWO..", "..OOOO..", "...OO..." }, { O = "3bc9db", W = "f7f3e8" }),
	soleil = P({ "Y...Y...Y", ".Y.....Y.", "...OOO...", "..OOOOO..", "YYOOOOOYY", "..OOOOO..", "...OOO...", ".Y.....Y.", "Y...Y...Y" }, { Y = "ffd23f", O = "ff8c42" }),
	palmier = P({ ".GGG.GGG.", "GG.GGG.GG", "G...T...G", "....T....", "....T....", "...T.....", "...T.....", "..SSSSS.." }, { G = "4f9a3a", T = "8b5a2b", S = "f4d58d" }),
	fleche = P({ "OOOOOO...", "OOOOOOO..", "......OO.", "......OOO", "......OO.", "OOOOOOO..", "OOOOOO..." }, { O = "ff8c42" }),
	etoiles = P({ "..Y......", ".YYY...Y.", "YYYYY.YYY", ".YYY...Y.", ".Y.Y.....", "....Y....", "...YYY...", "....Y...." }, { Y = "ffd23f" }),
	sac_horloge = P({ "...KKK.........", "..K...K...WWW..", ".GGGGGGG.WWKWW.", "GGGGGGGGGWWKWWW", "GGGDGGGGGWWKKKW", "GGDDDGGGGWWWWWW", "GGGDGGGGG.WWWW.", ".GGGGGGG...WW.." }, { G = "4f9a3a", D = "ffd23f", K = "2a2a2a", W = "f7f3e8" }),
}

-- Pose un picto sur une face d'une pièce, à la taille de la face, répété le long d'une face allongée.
-- face : Enum.NormalId ; quoi : nom de LV.PICTOS ; opts : neon, contour, marge (0,85), repete (true), nom, px (fixe).
function LV.surFace(parent, part, face, quoi, opts)
	opts = opts or {}
	local pic = LV.PICTOS[quoi]
	assert(pic, "picto inconnu : " .. tostring(quoi))
	local n = part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(face))
	local s = part.Size
	local fw, fh, depth
	if face == Enum.NormalId.Front or face == Enum.NormalId.Back then fw, fh, depth = s.X, s.Y, s.Z
	elseif face == Enum.NormalId.Left or face == Enum.NormalId.Right then fw, fh, depth = s.Z, s.Y, s.X
	else fw, fh, depth = s.X, s.Z, s.Y end
	local pw, ph = #pic.rows[1], #pic.rows
	local ring = (opts.contour == false) and 0 or 2
	local marge = opts.marge or 0.85
	local px = opts.px or marge * math.min(fw / (pw + ring), fh / (ph + ring))
	local frame = LV.face(part.Position + n * (depth / 2), n)
	local count, along = 1, Vector3.zero
	if opts.repete ~= false then
		local unitW, unitH = (pw + ring) * px, (ph + ring) * px
		if fh > fw * 1.8 then count = math.min(4, math.floor(fh / (unitH * 1.35))) along = frame.UpVector * (fh / math.max(count, 1))
		elseif fw > fh * 1.8 then count = math.min(4, math.floor(fw / (unitW * 1.35))) along = frame.RightVector * (fw / math.max(count, 1)) end
		count = math.max(count, 1)
	end
	local models = {}
	for k = 1, count do
		local off = along * (k - (count + 1) / 2)
		table.insert(models, (LV.pixels(parent, pic.rows, pic.pal, frame + off, { px = px, neon = opts.neon, contour = opts.contour, nom = opts.nom or ("Picto_" .. quoi) })))
	end
	return models
end

_G.LettresVoxel = LV
return "LettresVoxel chargé : " .. (function() local n = 0 for _ in LV.FONT do n += 1 end return n end)() .. " glyphes"
