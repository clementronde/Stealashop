--!nocheck
-- Police maison en lettres voxel (fiche du chef DA : da-police-voxel.md, 28/11 ; règle des enseignes :
-- da-enseignes-sans-slop.md) et pictogrammes en pixels.
-- Lettres : 7 pixels de haut, traits de 2, largeurs variables ; 3 couches (contour #040435 élargi d'un pixel, 0,4 p ;
-- face 0,6 p en biseau à 3 tons (+15 % de blanc, × 0,8) ; Neon en option, une PointLight par mot) ; pixels voisins du même ton fusionnés.
-- Pictos (LV.PICTOS) : grilles de couleurs, cubes à tenons sur un contour sombre, fusionnés en rectangles.
-- À charger d'abord dans Studio (MCP execute_luau, Edit) ; il ne pose rien lui-même, il remplit _G.LettresVoxel :
--   LettresVoxel.mot(parent, "SWEETS", repere, options) → Model, largeur, hauteur
--   LettresVoxel.motMagasin(STORE_x, "MOT", couleur, options) → modèle SignLetters sous la SignPart, p
--   LettresVoxel.pixels(parent, lignes, palette, repere, options) → Model, largeur, hauteur
--   LettresVoxel.surFace(parent, piece, Enum.NormalId, nom_du_picto, options) → { Model }
-- repere : CFrame au centre, sur la surface du mur, par LettresVoxel.face(centre, normale) : sa LookVector entre dans
-- le mur, sa RightVector est la droite du lecteur, son UpVector le haut ; les pièces sortent vers le lecteur (+Z local).
-- Options des mots : px (0,4), couleur, neon, ecart (0,05), nom. Options des pictos : px, profondeur, couleur, neon,
-- contour (couleur ou false), ecart (0,03), nom ; lignes = chaînes, « . » = vide, palette = { [caractère] = Color3 }.

local LV = {}
local OUTLINE = Color3.fromHex("040435")

function LV.face(center, normal)
	return CFrame.lookAt(center, center - normal)
end

-- grille de cellules { [ligne][colonne] = clé de couleur }, ligne 1 en haut. Cubes fusionnés en rectangles gloutons :
-- depuis chaque cellule libre, le plus large possible sur la ligne, puis le plus haut possible (28/11 : budget).
local function rects(get, rmin, rmax, cmin, cmax)
	local used, out = {}, {}
	local function key(r, c) return r * 1000 + c end
	for r = rmin, rmax do
		for c = cmin, cmax do
			local k = get(r, c)
			if k and not used[key(r, c)] then
				local c1 = c
				while c1 + 1 <= cmax and get(r, c1 + 1) == k and not used[key(r, c1 + 1)] do c1 += 1 end
				local r1 = r
				while r1 + 1 <= rmax do
					local ok = true
					for cc = c, c1 do if get(r1 + 1, cc) ~= k or used[key(r1 + 1, cc)] then ok = false break end end
					if not ok then break end
					r1 += 1
				end
				for rr = r, r1 do for cc = c, c1 do used[key(rr, cc)] = true end end
				table.insert(out, { c0 = c, c1 = c1, r0 = r, r1 = r1, k = k })
			end
		end
	end
	return out
end
LV.rects = rects
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
	local function cube(name, o, z0, z1, color, neon)
		local wid, hgt = (o.c1 - o.c0 + 1) * px, (o.r1 - o.r0 + 1) * px
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Size = Vector3.new(wid, hgt, z1 - z0)
		p.CFrame = frame * CFrame.new((o.c0 - 1) * px + wid / 2 - w * px / 2, h * px / 2 - (o.r0 - 1) * px - hgt / 2, (z0 + z1) / 2)
		p.Color = color
		p.Material = neon and Enum.Material.Neon or Enum.Material.Plastic
		if hasVariant and not neon then p.MaterialVariant = "Studs" end
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CastShadow = not neon
		p.Parent = m
	end
	-- contour : cellules allumées dilatées d'un cube (8 voisins), en retrait derrière les blocs
	if outline then
		local dil = {}
		for r = 0, h + 1 do dil[r] = {} end
		for r = 1, h do for c = 1, w do
			if grid[r] and grid[r][c] then for dr = -1, 1 do for dc = -1, 1 do dil[r + dr][c + dc] = true end end end
		end end
		for _, o in rects(function(r, c) return dil[r] and dil[r][c] and "o" or nil end, 0, h + 1, 0, w + 1) do
			cube("Contour", o, gap, gap + od, outline, false)
		end
	end
	for _, o in rects(function(r, c) return grid[r] and grid[r][c] or nil end, 1, h, 1, w) do
		cube("Bloc", o, gap + od, gap + od + depth, colors[o.k], opts.neon)
	end
	m.Parent = parent
	return m, (w + (outline and 2 or 0)) * px, (h + (outline and 2 or 0)) * px
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
	sakura_petit = P({ ".P.P.", "PPYPP", ".PPP.", "PP.PP" }, { P = "ff8fc8", Y = "ffd23f" }),
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
-- face : Enum.NormalId ; quoi : nom de LV.PICTOS ; opts : neon, contour, marge (0,85), repete (true), max (4), nom,
-- px (fixe).
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
		local maxN = opts.max or 4
		if fh > fw * 1.8 then count = math.min(maxN, math.floor(fh / (unitH * 1.35))) along = frame.UpVector * (fh / math.max(count, 1))
		elseif fw > fh * 1.8 then count = math.min(maxN, math.floor(fw / (unitW * 1.35))) along = frame.RightVector * (fw / math.max(count, 1)) end
		count = math.max(count, 1)
	end
	local models = {}
	for k = 1, count do
		local off = along * (k - (count + 1) / 2)
		table.insert(models, (LV.pixels(parent, pic.rows, pic.pal, frame + off, { px = px, neon = opts.neon, contour = opts.contour, nom = opts.nom or ("Picto_" .. quoi) })))
	end
	return models
end

-- Police maison du chef DA (da-police-voxel.md, 28/11) : 7 pixels de haut, traits de 2 pixels, largeurs variables
-- (6 ; 5 pour E, F, L ; 4 pour I et 1 ; 7 pour M et W), 1 pixel entre deux lettres, 3 entre deux mots.
LV.FONT = {
	A = { ".####.", "##..##", "##..##", "######", "##..##", "##..##", "##..##" },
	B = { "#####.", "##..##", "##..##", "#####.", "##..##", "##..##", "#####." },
	C = { ".####.", "##..##", "##....", "##....", "##....", "##..##", ".####." },
	D = { "#####.", "##..##", "##..##", "##..##", "##..##", "##..##", "#####." },
	E = { "#####", "##...", "##...", "####.", "##...", "##...", "#####" },
	F = { "#####", "##...", "##...", "####.", "##...", "##...", "##..." },
	G = { ".####.", "##..##", "##....", "##.###", "##..##", "##..##", ".#####" },
	H = { "##..##", "##..##", "##..##", "######", "##..##", "##..##", "##..##" },
	I = { "####", ".##.", ".##.", ".##.", ".##.", ".##.", "####" },
	J = { "....##", "....##", "....##", "....##", "##..##", "##..##", ".####." },
	K = { "##..##", "##.##.", "####..", "###...", "####..", "##.##.", "##..##" },
	L = { "##...", "##...", "##...", "##...", "##...", "##...", "#####" },
	M = { "##...##", "###.###", "#######", "##.#.##", "##...##", "##...##", "##...##" },
	N = { "##..##", "###.##", "######", "##.###", "##..##", "##..##", "##..##" },
	O = { ".####.", "##..##", "##..##", "##..##", "##..##", "##..##", ".####." },
	P = { "#####.", "##..##", "##..##", "#####.", "##....", "##....", "##...." },
	Q = { ".####.", "##..##", "##..##", "##..##", "##.###", ".####.", "....##" },
	R = { "#####.", "##..##", "##..##", "#####.", "####..", "##.##.", "##..##" },
	S = { ".####.", "##..##", "##....", ".####.", "....##", "##..##", ".####." },
	T = { "######", "..##..", "..##..", "..##..", "..##..", "..##..", "..##.." },
	U = { "##..##", "##..##", "##..##", "##..##", "##..##", "##..##", ".####." },
	V = { "##..##", "##..##", "##..##", "##..##", "##..##", ".####.", "..##.." },
	W = { "##...##", "##...##", "##...##", "##.#.##", "#######", "###.###", "##...##" },
	X = { "##..##", "##..##", ".####.", "..##..", ".####.", "##..##", "##..##" },
	Y = { "##..##", "##..##", "##..##", ".####.", "..##..", "..##..", "..##.." },
	Z = { "######", "....##", "...##.", "..##..", ".##...", "##....", "######" },
	["0"] = { ".####.", "##..##", "##.###", "######", "###.##", "##..##", ".####." },
	["1"] = { ".##.", "###.", ".##.", ".##.", ".##.", ".##.", "####" },
	["2"] = { ".####.", "##..##", "....##", "..###.", ".##...", "##....", "######" },
	["3"] = { ".####.", "##..##", "....##", "..###.", "....##", "##..##", ".####." },
	["4"] = { "...###", "..####", ".##.##", "##..##", "######", "....##", "....##" },
	["5"] = { "######", "##....", "#####.", "....##", "....##", "##..##", ".####." },
	["6"] = { ".####.", "##....", "##....", "#####.", "##..##", "##..##", ".####." },
	["7"] = { "######", "....##", "...##.", "..##..", "..##..", "..##..", "..##.." },
	["8"] = { ".####.", "##..##", "##..##", ".####.", "##..##", "##..##", ".####." },
	["9"] = { ".####.", "##..##", "##..##", ".#####", "....##", "....##", ".####." },
}

-- grille d'un texte : { [ligne 1..7][colonne] = true }, largeur en pixels
local function textGrid(text)
	local grid, w = {}, 0
	for r = 1, 7 do grid[r] = {} end
	text = string.upper(text)
	for i = 1, #text do
		local ch = text:sub(i, i)
		if ch == " " then
			w += 3
		else
			local g = LV.FONT[ch]
			assert(g, "lettre absente de la police : " .. ch)
			if w > 0 and text:sub(i - 1, i - 1) ~= " " then w += 1 end
			for r = 1, 7 do for c = 1, #g[r] do if g[r]:sub(c, c) == "#" then grid[r][w + c] = true end end end
			w += #g[1]
		end
	end
	return grid, w
end
LV.textGrid = textGrid

-- Mot en 3 couches (fiche du chef DA) : contour #040435 (silhouette élargie d'un pixel, 0,4 p, SmoothPlastic), face
-- (0,6 p) en biseau à 3 tons (clair si vide au-dessus, foncé si vide au-dessous) ; cubes voisins du même ton fusionnés ;
-- sans collision, requête ni ombre. En Neon : la face (3 tons) en Neon, une seule PointLight au centre, 1 stud devant.
-- repere : LV.face(centre, normale) ; options : px, couleur, neon, ecart (0,05), nom.
function LV.mot(parent, text, frame, opts)
	opts = opts or {}
	local px = opts.px or 0.4
	local gap = opts.ecart or 0.05
	local face = opts.couleur or Color3.fromHex("f7f3e8")
	-- biseau adouci (chef DA, 28/11 : de loin, les trois tons faisaient du bruit) : +15 % de blanc, × 0,8
	local light = face:Lerp(Color3.new(1, 1, 1), 0.15)
	local dark = Color3.new(face.R * 0.8, face.G * 0.8, face.B * 0.8)
	local grid, w = textGrid(text)
	local h = 7
	local m = Instance.new("Model")
	m.Name = opts.nom or ("Mot_" .. text:gsub("%s", "_"))
	local od, fd = 0.4 * px, 0.6 * px
	local function cube(name, c0, c1, r0, r1, z0, z1, color, mat)
		local wid, hgt = (c1 - c0 + 1) * px, (r1 - r0 + 1) * px
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.CastShadow = false
		p.Size = Vector3.new(wid, hgt, z1 - z0)
		p.CFrame = frame * CFrame.new((c0 - 1) * px + wid / 2 - w * px / 2, h * px / 2 - (r0 - 1) * px - hgt / 2, (z0 + z1) / 2)
		p.Color = color
		p.Material = mat
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = m
	end
	local function emit(get, rmin, rmax, cmin, cmax, name, z0, z1, colorOf, mat)
		local open = {}
		local function close(key)
			local o = open[key]
			cube(name, o.c0, o.c1, o.r0, o.r1, z0, z1, colorOf(o.k), mat)
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
					local key = c .. ":" .. c1 .. ":" .. k
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
	local dil = {}
	for r = 0, h + 1 do dil[r] = {} end
	for r = 1, h do for c = 1, w do if grid[r][c] then for dr = -1, 1 do for dc = -1, 1 do dil[r + dr][c + dc] = true end end end end end
	emit(function(r, c) return dil[r][c] and "o" or nil end, 0, h + 1, 0, w + 1, "Contour", gap, gap + od, function() return Color3.fromHex("040435") end, Enum.Material.SmoothPlastic)
	local function tone(r, c)
		if not grid[r][c] then return nil end
		if r == 1 or not grid[r - 1][c] then return "clair" end
		if r == h or not grid[r + 1][c] then return "fonce" end
		return "face"
	end
	local tones = { clair = light, fonce = dark, face = face }
	emit(tone, 1, h, 1, w, "Face", gap + od, gap + od + fd, function(k) return tones[k] end, opts.neon and Enum.Material.Neon or Enum.Material.SmoothPlastic)
	if opts.neon then
		local lp = Instance.new("Part")
		lp.Name = "Lumiere"
		lp.Anchored = true lp.CanCollide = false lp.CanTouch = false lp.CanQuery = false lp.CastShadow = false
		lp.Transparency = 1
		lp.Size = Vector3.new(0.2, 0.2, 0.2)
		lp.CFrame = frame * CFrame.new(0, 0, gap + od + fd + 1)
		lp.Parent = m
		local l = Instance.new("PointLight")
		l.Range = math.min(16, (w + 2) * px / 2)
		l.Brightness = 1
		l.Color = face
		l.Parent = lp
	end
	m.Parent = parent
	return m, (w + 2) * px, (h + 2) * px
end

-- Mot d'un magasin PNJ sur sa SignPart (fiche du chef DA) : centré sur la face qui portait la SurfaceGui, dans un modèle
-- SignLetters sous la SignPart (gardée : le code s'en sert pour placer le panneau d'infos), à 0,05 devant la face
-- (devant les SignBorder s'ils dépassent) ; p réduit si le mot dépasse 80 % de la largeur ; décalé en hauteur (au plus
-- 1,5) s'il touche le décor du magasin. Rend le modèle, p et le décalage (nil : contact non évité).
function LV.motMagasin(store, word, color, opts)
	opts = opts or {}
	local sp = store:FindFirstChild("SignPart")
	assert(sp, store.Name .. " : pas de SignPart")
	local faceId = opts.face or Enum.NormalId.Front
	local n = sp.CFrame:VectorToWorldSpace(Vector3.FromNormalId(faceId))
	local s = sp.Size
	local fw = (faceId == Enum.NormalId.Left or faceId == Enum.NormalId.Right) and s.Z or s.X
	local depth = (faceId == Enum.NormalId.Left or faceId == Enum.NormalId.Right) and s.X or s.Z
	local front = depth / 2
	for _, b in { store:FindFirstChild("SignBorder_1", true), store:FindFirstChild("SignBorder_2", true) } do
		if b then front = math.max(front, (b.Position - sp.Position):Dot(n) + b.Size.Z / 2) end
	end
	local _, wpx = textGrid(word)
	local px = opts.px or 0.4
	if (wpx + 2) * px > 0.8 * fw then px = 0.8 * fw / (wpx + 2) end
	local old = sp:FindFirstChild("SignLetters")
	if old then old:Destroy() end
	local holder = Instance.new("Model")
	holder.Name = "SignLetters"
	holder.Parent = sp
	-- au centre ; s'il touche le décor du magasin (corniche, jardinières…), décalé en hauteur par pas de 0,05
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = { holder }
	local dys = { 0 }
	for k = 1, 30 do table.insert(dys, -k * 0.05) table.insert(dys, k * 0.05) end
	for _, dy in dys do
		local m = LV.mot(holder, word, LV.face(sp.Position + n * front + Vector3.new(0, dy, 0), n), { px = px, couleur = color, neon = opts.neon, nom = "Mot_" .. word })
		local hit = false
		for _, q in m:GetDescendants() do
			if q:IsA("BasePart") then
				for _, o in workspace:GetPartsInPart(q, op) do if o.Transparency < 1 then hit = true break end end
			end
			if hit then break end
		end
		if not hit then return holder, px, dy end
		m:Destroy()
	end
	LV.mot(holder, word, LV.face(sp.Position + n * front, n), { px = px, couleur = color, neon = opts.neon, nom = "Mot_" .. word })
	return holder, px, nil
end

_G.LettresVoxel = LV
return "LettresVoxel chargé : " .. (function() local n = 0 for _ in LV.FONT do n += 1 end return n end)() .. " glyphes"
