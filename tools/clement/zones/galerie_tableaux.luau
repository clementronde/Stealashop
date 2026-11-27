--!nocheck
-- Galerie d'art (zone 5) : les anciens cadres vides ArtFrame (172 panneaux unis, dorés ou noirs, collés en 12 rangées
-- sur 4 rayons) sont remplacés par de vrais tableaux en pixel art (demande de Clément, 27/11 : « Mets des tableaux »).
-- Nos propres tableaux : paysage, coucher de soleil, chat, nature morte, abstrait, mer, et la Joconde (libre de droits,
-- en écho à l'objet « Joconde selfie »). Pixels en petits blocs (une pièce par suite de pixels de même couleur), cadre
-- doré en relief et petite plaque dorée sous chaque tableau, le tout fusionné en une seule UnionOperation par tableau.
-- Pose : une rangée = un plan (x fixe) de 28 studs de long ; les tableaux y sont alignés avec un espace entre eux,
-- à la hauteur des anciens cadres. Lisibles des deux côtés. Sans collision, ni toucher, ni requête, aucun script.
-- Ni les ShelfSlot ni les produits du kit (Interior/Products) ne sont touchés.
-- Avant : les ArtFrame partent (déplacés, pas supprimés) dans ServerStorage/MapBackups/<date>_GalerieArtFrame.
-- Relançable : Interior/Paintings est refait.
-- À lancer dans Studio (MCP execute_luau, Edit, hors Play).

local CHS = game:GetService("ChangeHistoryService")
local rgb = Color3.fromRGB
local store = workspace.Map.Zone_5:FindFirstChild("STORE_Z5_GalerieDArt")
local int = store.Interior

local P = { -- palettes : un caractère = une couleur
	["."] = nil,
	B = rgb(110, 180, 240), b = rgb(60, 120, 210), N = rgb(30, 50, 110), W = rgb(250, 250, 245),
	G = rgb(80, 170, 70), g = rgb(40, 120, 50), M = rgb(130, 90, 55), m = rgb(90, 60, 40),
	Y = rgb(250, 210, 60), O = rgb(245, 140, 50), R = rgb(220, 60, 60), K = rgb(250, 120, 170),
	P = rgb(140, 80, 190), p = rgb(200, 170, 230), S = rgb(150, 150, 160), s = rgb(90, 90, 100),
	F = rgb(235, 195, 150), f = rgb(190, 140, 100), D = rgb(40, 40, 45), E = rgb(60, 80, 60), e = rgb(100, 120, 80),
}
-- 12 × 8 pixels, ligne du haut en premier
local ART = {
	Paysage = {
		"BBBBBBBBBYYB", "BBBWWBBBBYYB", "BBWWWWBBBBBB", "BBBBBBBGGBBB",
		"BBBGGGGGGGGB", "GGGGGgGGGGGG", "gggggggMMggg", "MMMMMMMMMMMM" },
	Coucher = {
		"PPPPPPPPPPPP", "KKKKKKKKKKKK", "OOOOOYYOOOOO", "OOOOYYYYOOOO",
		"RRRRYYYYRRRR", "NNNNNNNNNNNN", "NbNNNNbNNNbN", "NNNNNNNNNNNN" },
	Chat = {
		"pppppppppppp", "ppSppppppSpp", "pSSSppppSSSp", "pSSSSSSSSSSp",
		"pSGSSSSSSGSp", "pSSSSKKSSSSp", "ppSSSSSSSSpp", "pppSSSSSSppp" },
	NatureMorte = {
		"FFFFFFFFFFFF", "FFFFFbbFFFFF", "FFFFbbbbFFFF", "FFRRFbbFYYFF",
		"FRRRRbbYYYYF", "FFRRbbbbYYFF", "MMMMMMMMMMMM", "mmmmmmmmmmmm" },
	Abstrait = {
		"RRRRYYYYbbbb", "RRRRYYYYbbbb", "RRWWWWYYbbbb", "GGWWWWPPPPbb",
		"GGGGWWPPPPbb", "GGGGOOOOPPKK", "DDGGOOOOPPKK", "DDDDOOOOKKKK" },
	Mer = {
		"BBBBBBBBBBBB", "BBBBWBBBBBBB", "BBBWWWBBBBBB", "BBBBMBBBBYBB",
		"bbbbbbbbbbbb", "bWbbbbbWbbbb", "bbbbWbbbbbWb", "NNNNNNNNNNNN" },
	Joconde = {
		"eeeemmmmeeee", "eeemmFFmmeee", "eeemFFFFmeee", "eeemFDFDmeee",
		"eeemFFFFmeee", "eeemmFFmmeee", "eeEDDFFDDEee", "eEDDDDDDDDEe" },
}
local ORDER = { "Paysage", "Coucher", "Chat", "NatureMorte", "Abstrait", "Mer", "Joconde" }
local GOLD, PLAQUE = rgb(212, 176, 90), rgb(200, 160, 70)
local CANVAS_T, FRAME_T, FRAME_W = 0.12, 0.26, 0.12
local W_PIX, H_PIX = 12, 8

local rec = CHS:TryBeginRecording("Galerie : tableaux", { allowNoUndo = true })

-- 1) Rangées des anciens cadres (ou depuis la sauvegarde à la relance)
local mb = game.ServerStorage.MapBackups
local bname = os.date("%Y-%m-%d") .. "_GalerieArtFrame"
local backup = mb:FindFirstChild(bname)
if not backup then
	backup = Instance.new("Folder")
	backup.Name = bname
	backup:SetAttribute("Note", "Les 172 cadres vides ArtFrame de l'Interior de la Galerie d'art, remplacés par Interior/Paintings (tableaux en pixel art, 27/11). Pour revenir : supprimer Interior/Paintings et remettre ces pièces dans Interior.")
	backup.Parent = mb
end
for _, p in int:GetChildren() do if p.Name:match("^ArtFrame") then p.Parent = backup end end
local rows = {}
for _, p in backup:GetChildren() do
	if p:IsA("BasePart") then
		local bottom = p.Position.Y - p.Size.Y / 2
		local key = ("%d|%.1f"):format(math.floor(p.Position.X * 2 + 0.5), bottom)
		local r = rows[key]
		if not r then r = { x = p.Position.X, bottom = bottom, z0 = math.huge, z1 = -math.huge, h = math.huge } rows[key] = r end
		r.z0 = math.min(r.z0, p.Position.Z - p.Size.Z / 2)
		r.z1 = math.max(r.z1, p.Position.Z + p.Size.Z / 2)
		r.h = math.min(r.h, p.Size.Y) -- le plus petit des anciens cadres : on ne touche pas la planche du dessus
	end
end

local old = int:FindFirstChild("Paintings")
if old then old:Destroy() end
local paintings = Instance.new("Model")
paintings.Name = "Paintings"
paintings.Parent = int

local function part(parent, name, cf, size, color, mat)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Color = color
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
	return p
end

-- Un tableau dans le plan x = x0, centré en z = zc, bas à y = y0, hauteur totale h
local function painting(name, art, x0, zc, y0, h)
	local tmp = Instance.new("Model")
	tmp.Name = name
	tmp.Parent = paintings
	local plaqueH = 0.18
	local frameH = h - plaqueH - 0.06
	local pix = (frameH - 2 * FRAME_W) / H_PIX
	local w = pix * W_PIX + 2 * FRAME_W
	local yb = y0 + plaqueH + 0.06 -- bas du cadre
	local parts = {}
	-- cadre doré en relief (4 barres)
	table.insert(parts, part(tmp, "FrameB", CFrame.new(x0, yb + FRAME_W / 2, zc), Vector3.new(FRAME_T, FRAME_W, w), GOLD, Enum.Material.Metal))
	table.insert(parts, part(tmp, "FrameT", CFrame.new(x0, yb + frameH - FRAME_W / 2, zc), Vector3.new(FRAME_T, FRAME_W, w), GOLD, Enum.Material.Metal))
	table.insert(parts, part(tmp, "FrameL", CFrame.new(x0, yb + frameH / 2, zc - w / 2 + FRAME_W / 2), Vector3.new(FRAME_T, frameH - 2 * FRAME_W, FRAME_W), GOLD, Enum.Material.Metal))
	table.insert(parts, part(tmp, "FrameR", CFrame.new(x0, yb + frameH / 2, zc + w / 2 - FRAME_W / 2), Vector3.new(FRAME_T, frameH - 2 * FRAME_W, FRAME_W), GOLD, Enum.Material.Metal))
	-- pixels : une pièce par suite horizontale de même couleur
	for row = 1, H_PIX do
		local line = art[row]
		local y = yb + frameH - FRAME_W - (row - 0.5) * pix
		local col = 1
		while col <= W_PIX do
			local c = line:sub(col, col)
			local run = 1
			while col + run <= W_PIX and line:sub(col + run, col + run) == c do run += 1 end
			local color = P[c]
			if color then
				local za = zc - w / 2 + FRAME_W + (col - 1) * pix
				table.insert(parts, part(tmp, "Px", CFrame.new(x0, y, za + run * pix / 2), Vector3.new(CANVAS_T, pix, run * pix), color))
			end
			col += run
		end
	end
	-- plaque dorée sous le tableau
	table.insert(parts, part(tmp, "Plaque", CFrame.new(x0, y0 + plaqueH / 2, zc), Vector3.new(FRAME_T, plaqueH, math.min(0.9, w * 0.4)), PLAQUE, Enum.Material.Metal))
	-- fusion
	local first = table.remove(parts, 1)
	local ok, u = pcall(function() return first:UnionAsync(parts, Enum.CollisionFidelity.Box, Enum.RenderFidelity.Automatic) end)
	if ok and u then
		u.Name = name
		u.UsePartColor = false
		u.Anchored = true
		u.CanCollide = false
		u.CanTouch = false
		u.CanQuery = false
		u.CastShadow = false
		u.Parent = paintings
		tmp:Destroy()
		return u, w, true
	end
	return tmp, w, false
end

-- 2) Pose : rangée par rangée, tableaux espacés, sujets alternés
local count, fused, idx = 0, 0, 0
local keys = {}
for k in rows do table.insert(keys, k) end
table.sort(keys)
for _, k in keys do
	local r = rows[k]
	local h = math.min(r.h, 2.2)
	local pix = (h - 0.24 - 2 * FRAME_W) / H_PIX
	local w = pix * W_PIX + 2 * FRAME_W
	local gap = 0.8
	local n = math.max(1, math.floor((r.z1 - r.z0 + gap) / (w + gap)))
	local used = n * w + (n - 1) * gap
	local z = r.z0 + (r.z1 - r.z0 - used) / 2 + w / 2
	for i = 1, n do
		idx += 1
		local name = ORDER[(idx - 1) % #ORDER + 1]
		local _, _, ok = painting("Painting_" .. name, ART[name], r.x, z, r.bottom, h)
		count += 1
		if ok then fused += 1 end
		z += w + gap
	end
	task.wait()
end

if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
local np = 0 for _, d in paintings:GetDescendants() do if d:IsA("BasePart") then np += 1 end end
local slots = 0 for _, d in store:GetDescendants() do if d.Name:match("^ShelfSlot_") then slots += 1 end end
return ("%d tableaux posés (%d fusionnés), %d pièces ; %d ArtFrame dans MapBackups/%s ; %d ShelfSlot ; Products intact : %s"):format(count, fused, np, #backup:GetChildren() - 0, bname, slots, tostring(int:FindFirstChild("Products") ~= nil))
