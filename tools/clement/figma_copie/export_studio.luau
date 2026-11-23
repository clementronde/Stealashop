--!nonstrict
-- figma_copie/export_studio.luau (Clément, 2026-11-21) : relevé de toute l'UI du jeu pour la copie Figma modifiable
-- (fichier « Steal a Shop — UI », page « 40 Jeu — copie de Studio (21/11) »). Demande de Clément : « Mets tous les
-- éléments du jeu en terme d'UI dans le figma », en « copie modifiable ». Fiche : docs/claude/notes/
-- ui-reference-shop-tiktok-2026-11-21.md, section 10. Mode d'emploi complet : README.md à côté.
--
-- À lancer en Edit (barre de commande ou execute_luau). Ce fichier n'installe que des fonctions dans _G ; il ne
-- modifie aucun écran. Les seuls objets créés sont temporaires et supprimés aussitôt : StarterGui._FigmaAtlas
-- (planche d'images) et StarterGui._FigmaBB (billboards posés à plat). Rien à enregistrer.
--
--   _G.FigmaDevice()            appareil simulé 1920 × 1080 (même taille pour tous les écrans) ; _G.FigmaDeviceOff()
--   _G.FigmaExportMany(noms)    écrans de StarterGui -> texte « @@UIEXPORT@@ … @@END@@ » (un bloc par écran)
--   _G.FigmaExportAssets()      billboards BB_*, tableaux, enseignes, cadres, fonds de cartes, 4 billboards du décor
--                               (relevés dans _G.FigmaCache ; noms dans _G.FigmaAssetNames, à passer à FigmaExportMany)
--   _G.FigmaComputeSheets()     répartit toutes les images relevées en planches de 1919 × 1079 (_G.FigmaSheets)
--   _G.FigmaAtlas(planche, fond) / _G.FigmaAtlasBg(fond) / _G.FigmaAtlasDone()   planche à photographier sur noir
--                               puis sur blanc (screen_capture), pour retrouver la transparence (alpha.js)
--
-- Une ligne par élément (18 colonnes séparées par des tabulations) : n°, parent, nom, classe (F T B X I J S V G W),
-- x, y (par rapport au parent), largeur, hauteur, rotation, caché (« 0 »), coupe, ZIndex, fond « hex,opacité »,
-- arrondi en px, contour « hex,px,o|i|c,opacité », dégradé « rotation;décalage;couleurs;transparences »,
-- texte « police,graisse,italique,taille,hex,opacité,xa,ya,w,marges,s,boîte~contour~texte »,
-- image « id[@rect],teinte,opacité,S|9|T|F|C,tuileL,tuileH ».

-- 0. Appareil simulé ------------------------------------------------------------------------------------------------
_G.FigmaDevice = function()
	local svc = game:GetService("StudioDeviceSimulatorService")
	local id = "FigmaRef_1920x1080"
	local exists = false
	for _, d in svc:GetDeviceListAsync() do if d == id then exists = true end end
	if not exists then
		id = svc:CreateDeviceAsync({ Name = "FigmaRef_1920x1080", Width = 1920, Height = 1080, PixelDensity = 96, DeviceForm = Enum.DeviceForm.Desktop })
	end
	svc:SetDeviceAsync(id)
	task.wait(0.8)
	return tostring(workspace.CurrentCamera.ViewportSize)
end
_G.FigmaDeviceOff = function()
	game:GetService("StudioDeviceSimulatorService"):StopSimulationAsync()
end

-- 1. Relevé d'un arbre d'UI ------------------------------------------------------------------------------------------
local function esc(s) return (s:gsub("\\", "\\\\"):gsub("\t", "\\t"):gsub("\n", "\\n"):gsub("\r", "")) end
local function n2(v) return tostring(math.floor(v * 100 + 0.5) / 100) end
local function seqC(cs) local t = {} for _, k in cs.Keypoints do table.insert(t, n2(k.Time) .. ":" .. k.Value:ToHex()) end return table.concat(t, ",") end
local function seqN(ns) local t, any = {}, false for _, k in ns.Keypoints do if k.Value ~= 0 then any = true end table.insert(t, n2(k.Time) .. ":" .. n2(k.Value)) end return any and table.concat(t, ",") or "" end
local function colorAt(cs, t)
	local kp = cs.Keypoints
	if t <= kp[1].Time then return kp[1].Value end
	for i = 1, #kp - 1 do local a, b = kp[i], kp[i + 1] if t <= b.Time then local f = (t - a.Time) / math.max(1e-6, b.Time - a.Time) return a.Value:Lerp(b.Value, f) end end
	return kp[#kp].Value
end
local SCALE = { [Enum.ScaleType.Stretch] = "S", [Enum.ScaleType.Slice] = "9", [Enum.ScaleType.Tile] = "T", [Enum.ScaleType.Fit] = "F", [Enum.ScaleType.Crop] = "C" }
local XA = { [Enum.TextXAlignment.Left] = "L", [Enum.TextXAlignment.Center] = "C", [Enum.TextXAlignment.Right] = "R" }
local YA = { [Enum.TextYAlignment.Top] = "T", [Enum.TextYAlignment.Center] = "C", [Enum.TextYAlignment.Bottom] = "B" }
local CLS = { Frame = "F", TextLabel = "T", TextButton = "B", TextBox = "X", ImageLabel = "I", ImageButton = "J", ScrollingFrame = "S", ViewportFrame = "V", CanvasGroup = "G", VideoFrame = "W" }
local function imageKey(o)
	local id = tostring(o.Image):match("%d+")
	if not id then return nil end
	local rs, ro = o.ImageRectSize, o.ImageRectOffset
	if rs.X > 0 and rs.Y > 0 then return id .. "@" .. ro.X .. "," .. ro.Y .. "," .. rs.X .. "," .. rs.Y end
	return id
end
_G.FigmaImageKey = imageKey
local function export(root, originX, originY)
	local lines, keys, n = {}, {}, 0
	local function visit(obj, parentIdx, px, py)
		for _, c in obj:GetChildren() do
			if c:IsA("GuiObject") then
				n += 1
				local me = n
				local ap, as = c.AbsolutePosition, c.AbsoluteSize
				local mn = math.min(as.X, as.Y)
				local f = { me, parentIdx, esc(c.Name), CLS[c.ClassName] or "F", math.round(ap.X - px), math.round(ap.Y - py), math.round(as.X), math.round(as.Y),
					(c.Rotation ~= 0) and n2(c.Rotation) or "", c.Visible and "" or "0", (c.ClipsDescendants or c:IsA("ScrollingFrame")) and "1" or "", c.ZIndex }
				f[13] = (c.BackgroundTransparency < 1) and (c.BackgroundColor3:ToHex() .. "," .. n2(1 - c.BackgroundTransparency)) or ""
				local cr = c:FindFirstChildOfClass("UICorner")
				f[14] = cr and tostring(math.round(math.min(mn / 2, cr.CornerRadius.Scale * mn + cr.CornerRadius.Offset))) or ""
				local isText = c:IsA("TextLabel") or c:IsA("TextButton") or c:IsA("TextBox")
				local box, txt = "", ""
				for _, s in c:GetChildren() do
					if s:IsA("UIStroke") and s.Enabled then
						local col = s.Color
						local g = s:FindFirstChildOfClass("UIGradient")
						if g and g.Enabled then local gc = colorAt(g.Color, math.clamp(0.5 - g.Offset.X, 0, 1)) col = Color3.new(col.R * gc.R, col.G * gc.G, col.B * gc.B) end
						if isText and s.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then
							txt = col:ToHex() .. "," .. n2(s.Thickness) .. "," .. ((s.StrokeSizingMode == Enum.StrokeSizingMode.ScaledSize) and "s" or "f") .. "," .. n2(1 - s.Transparency)
						else
							local spx = (s.StrokeSizingMode == Enum.StrokeSizingMode.ScaledSize) and s.Thickness * mn or s.Thickness
							local pos = (s.BorderStrokePosition == Enum.BorderStrokePosition.Inner) and "i" or ((s.BorderStrokePosition == Enum.BorderStrokePosition.Center) and "c" or "o")
							box = col:ToHex() .. "," .. n2(spx) .. "," .. pos .. "," .. n2(1 - s.Transparency)
						end
					end
				end
				f[15] = box
				local g = c:FindFirstChildOfClass("UIGradient")
				f[16] = (g and g.Enabled) and (n2(g.Rotation) .. ";" .. n2(g.Offset.X) .. "," .. n2(g.Offset.Y) .. ";" .. seqC(g.Color) .. ";" .. seqN(g.Transparency)) or ""
				if isText then
					local ff = c.FontFace
					local fam = tostring(ff.Family):match("families/([%w_]+)%.json") or tostring(ff.Family)
					local text = c.RichText and c.ContentText or c.Text
					local nl = 1 for _ in text:gmatch("\n") do nl += 1 end
					local size = c.TextScaled and (c.TextBounds.Y / nl) or c.TextSize
					local legacy = (c.TextStrokeTransparency < 1) and (c.TextStrokeColor3:ToHex() .. ",1,f," .. n2(1 - c.TextStrokeTransparency)) or ""
					local pad = c:FindFirstChildOfClass("UIPadding")
					local pads = pad and table.concat({ math.round(pad.PaddingLeft.Scale * as.X + pad.PaddingLeft.Offset), math.round(pad.PaddingTop.Scale * as.Y + pad.PaddingTop.Offset), math.round(pad.PaddingRight.Scale * as.X + pad.PaddingRight.Offset), math.round(pad.PaddingBottom.Scale * as.Y + pad.PaddingBottom.Offset) }, ";") or ""
					f[17] = table.concat({ fam, ff.Weight.Value, (ff.Style == Enum.FontStyle.Italic) and "i" or "", n2(size), c.TextColor3:ToHex(), n2(1 - c.TextTransparency), XA[c.TextXAlignment], YA[c.TextYAlignment], c.TextWrapped and "w" or "", pads }, ",") .. "~" .. (txt ~= "" and txt or legacy) .. "~" .. esc(text)
				else
					f[17] = ""
				end
				if c:IsA("ImageLabel") or c:IsA("ImageButton") then
					local key = imageKey(c)
					if key then keys[key] = true end
					local ts = c.TileSize
					f[18] = key and table.concat({ key, c.ImageColor3:ToHex(), n2(1 - c.ImageTransparency), SCALE[c.ScaleType] or "S", math.round(ts.X.Scale * as.X + ts.X.Offset), math.round(ts.Y.Scale * as.Y + ts.Y.Offset) }, ",") or ""
				else
					f[18] = ""
				end
				table.insert(lines, table.concat(f, "\t"))
				visit(c, me, ap.X, ap.Y)
			end
		end
	end
	visit(root, 0, originX, originY)
	return lines, keys
end
_G.FigmaExportCore = export

-- 2. Texte : « ,s » si TextScaled, puis la boîte réelle du texte (TextBounds), insérés dans la colonne 17 ----------
_G.FigmaPatchText = function(lines, gui)
	local byIndex, n = {}, 0
	local function visit(obj)
		for _, c in obj:GetChildren() do
			if c:IsA("GuiObject") then
				n += 1
				if c:IsA("TextLabel") or c:IsA("TextButton") or c:IsA("TextBox") then byIndex[n] = c end
				visit(c)
			end
		end
	end
	visit(gui)
	for i, line in lines do
		local c = byIndex[i]
		if c then
			local f = string.split(line, "\t")
			if f[17] and f[17] ~= "" then
				local a = f[17]:find("~", 1, true)
				f[17] = f[17]:sub(1, a - 1) .. "," .. (c.TextScaled and "s" or "") .. "," .. math.round(c.TextBounds.X) .. "x" .. math.round(c.TextBounds.Y) .. f[17]:sub(a)
				lines[i] = table.concat(f, "\t")
			end
		end
	end
end

-- 3. Un écran de StarterGui (allumé le temps du relevé : un écran éteint garde des positions périmées) -------------
_G.FigmaCache = _G.FigmaCache or {}
_G.FigmaEnsure = function(screenName)
	local cache = _G.FigmaCache[screenName]
	if cache then return cache end
	local gui = game.StarterGui:FindFirstChild(screenName)
	assert(gui and gui:IsA("ScreenGui"), "écran introuvable : " .. screenName)
	local target = workspace.CurrentCamera.ViewportSize
	local was = gui.Enabled
	gui.Enabled = true
	for _ = 1, 30 do task.wait() if math.abs(gui.AbsoluteSize.X - target.X) < 2 then break end end
	task.wait() task.wait()
	local lines, keys = export(gui, gui.AbsolutePosition.X, gui.AbsolutePosition.Y)
	_G.FigmaPatchText(lines, gui)
	local size = gui.AbsoluteSize
	gui.Enabled = was
	local kl = {} for k in keys do table.insert(kl, k) end
	table.sort(kl)
	cache = { lines = lines, keys = kl, size = math.round(size.X) .. "x" .. math.round(size.Y), order = gui.ZIndexBehavior.Name }
	_G.FigmaCache[screenName] = cache
	return cache
end

-- 4. Sortie de plusieurs écrans, avec un dictionnaire des valeurs répétées (§n) ------------------------------------
_G.FigmaCompress = function(cache)
	if cache.packed then return cache.packed end
	local counts = {}
	local function key17(v) local a = v:find("~", 1, true) if not a then return nil end local b = v:find("~", a + 1, true) if not b then return nil end return v:sub(1, b - 1) end
	for _, line in cache.lines do
		local f = string.split(line, "\t")
		for _, i in { 13, 15, 16, 18 } do local v = f[i] if v and #v > 10 then counts[v] = (counts[v] or 0) + 1 end end
		local k = f[17] and key17(f[17]) if k and #k > 10 then counts[k] = (counts[k] or 0) + 1 end
	end
	local dict, ids, nextId = {}, {}, 0
	for v, c in counts do if c >= 2 then nextId += 1 ids[v] = "§" .. nextId table.insert(dict, nextId .. "=" .. v) end end
	local out = {}
	for _, line in cache.lines do
		local f = string.split(line, "\t")
		for _, i in { 13, 15, 16, 18 } do if f[i] and ids[f[i]] then f[i] = ids[f[i]] end end
		local k = f[17] and key17(f[17])
		if k and ids[k] then f[17] = ids[k] .. f[17]:sub(#k + 1) end
		local n = #f
		while n > 12 and (f[n] == nil or f[n] == "") do f[n] = nil n -= 1 end
		table.insert(out, table.concat(f, "\t"))
	end
	cache.packed = { lines = out, dict = table.concat(dict, "\t") }
	return cache.packed
end
_G.FigmaExportMany = function(names)
	local out = {}
	for _, name in names do
		local cache = _G.FigmaEnsure(name)
		local packed = _G.FigmaCompress(cache)
		local block = { ("@@UIEXPORT@@\t%s\t1\t1\t%s\t%s\t%d\t%s"):format(name, cache.size, cache.order, #cache.lines, table.concat(cache.keys, " ")), "@@DICT@@\t" .. packed.dict }
		for _, l in packed.lines do table.insert(block, l) end
		table.insert(block, "@@END@@")
		table.insert(out, table.concat(block, "\n"))
	end
	return table.concat(out, "\n")
end

-- 5. Billboards et autres éléments hors StarterGui, posés à plat dans un écran temporaire ---------------------------
-- Taille : Size des billboards à 40 px par stud (vue moyenne) ; SurfaceGui : CanvasSize (FixedSize) ou face × PPS ;
-- cadres à l'échelle : dans une boîte de référence (badge 160 px, superposition 400 × 300, fonds de cartes 260 × 320).
_G.FigmaExportAssets = function()
	local RS, SG = game:GetService("ReplicatedStorage"), game:GetService("StarterGui")
	local ui = RS.Assets.UI
	local PPS = 40
	local specs = {}
	local function bbSize(bb) return math.max(8, math.round(bb.Size.X.Scale * PPS + bb.Size.X.Offset)), math.max(8, math.round(bb.Size.Y.Scale * PPS + bb.Size.Y.Offset)) end
	local function sgSize(s)
		if s.SizingMode == Enum.SurfaceGuiSizingMode.FixedSize then return s.CanvasSize.X, s.CanvasSize.Y end
		local part = s.Adornee or s.Parent
		local sz, face = part.Size, s.Face
		local w, h
		if face == Enum.NormalId.Front or face == Enum.NormalId.Back then w, h = sz.X, sz.Y
		elseif face == Enum.NormalId.Left or face == Enum.NormalId.Right then w, h = sz.Z, sz.Y
		else w, h = sz.X, sz.Z end
		return math.round(w * s.PixelsPerStud), math.round(h * s.PixelsPerStud)
	end
	local bbs = {}
	for _, c in ipairs(ui:GetChildren()) do if c:IsA("BillboardGui") then table.insert(bbs, c) end end
	table.sort(bbs, function(a, b) return a.Name < b.Name end)
	for _, c in ipairs(bbs) do local w, h = bbSize(c) table.insert(specs, { name = c.Name, src = c, layer = true, w = w, h = h }) end
	for _, n in { "Income", "Speed" } do local s = ui.LeaderboardBoards[n].Board local w, h = sgSize(s) table.insert(specs, { name = "LB_" .. n, src = s, layer = true, w = w, h = h }) end
	for _, n in { "StoreReqSign", "UpgradeSign" } do local s = ui[n].Board.SignGui local w, h = sgSize(s) table.insert(specs, { name = "SIGN_" .. n, src = s, layer = true, w = w, h = h }) end
	table.insert(specs, { name = "AlertBadge", src = ui.AlertBadge, layer = false, w = 160, h = 160 })
	table.insert(specs, { name = "AntiTheftOverlay", src = ui.AntiTheftOverlay, layer = false, w = 400, h = 300 })
	for _, n in { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Divine" } do table.insert(specs, { name = "CARD_" .. n, src = ui.ShopCardBg[n], layer = false, w = 260, h = 320 }) end
	local seen = {}
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("BillboardGui") and (d.Name == "BB_OpenTimer" or d.Name == "ShowLabel" or d.Name == "AmountGui" or d.Name == "Show_BB_Box") and not seen[d.Name] then
			seen[d.Name] = true
			local w, h = bbSize(d)
			table.insert(specs, { name = "WS_" .. d.Name, src = d, layer = true, w = w, h = h })
		end
	end
	local old = SG:FindFirstChild("_FigmaBB") if old then old:Destroy() end
	local tmp = Instance.new("ScreenGui")
	tmp.Name = "_FigmaBB" tmp.IgnoreGuiInset = true tmp.DisplayOrder = 10001 tmp.ResetOnSpawn = false tmp.Enabled = true
	tmp.Parent = SG
	local names = {}
	for _, sp in ipairs(specs) do
		tmp.ZIndexBehavior = sp.layer and sp.src.ZIndexBehavior or Enum.ZIndexBehavior.Sibling
		local holder = Instance.new("Frame")
		holder.Name = sp.name holder.BackgroundTransparency = 1 holder.BorderSizePixel = 0
		holder.Size = UDim2.fromOffset(sp.w, sp.h)
		holder.Parent = tmp
		if sp.layer then
			for _, c in ipairs(sp.src:GetChildren()) do if not c:IsA("LuaSourceContainer") then local cl = c:Clone() if cl then cl.Parent = holder end end end
		else
			local cl = sp.src:Clone() if cl then cl.Parent = holder end
		end
		for _, d in ipairs(holder:GetDescendants()) do if d:IsA("LuaSourceContainer") then d:Destroy() end end
		for _ = 1, 5 do task.wait() end
		local lines, keys = export(holder, holder.AbsolutePosition.X, holder.AbsolutePosition.Y)
		_G.FigmaPatchText(lines, holder)
		holder:Destroy()
		local kl = {} for k in keys do table.insert(kl, k) end
		table.sort(kl)
		_G.FigmaCache[sp.name] = { lines = lines, keys = kl, size = sp.w .. "x" .. sp.h, order = tmp.ZIndexBehavior.Name }
		table.insert(names, sp.name)
	end
	tmp:Destroy()
	_G.FigmaAssetNames = names
	return names
end

-- 6. Planches d'images (photographiées sur noir puis sur blanc) -----------------------------------------------------
_G.FigmaComputeSheets = function()
	local CAP = 320
	local maxes = {}
	for _, cache in _G.FigmaCache do
		for _, line in cache.lines do
			local f = string.split(line, "\t")
			local img = f[18]
			if img and img ~= "" then
				local p = string.split(img, ",")
				local key, scale = p[1], p[4]
				local w, h = tonumber(f[7]), tonumber(f[8])
				if scale == "T" and tonumber(p[5]) and tonumber(p[5]) > 0 then w, h = tonumber(p[5]), tonumber(p[6]) end
				local k = math.min(1, CAP / math.max(w, h, 1))
				w, h = math.max(8, math.ceil(w * k)), math.max(8, math.ceil(h * k))
				local m = maxes[key]
				if not m or w * h > m[1] * m[2] then maxes[key] = { w, h } end
			end
		end
	end
	local entries = {}
	for key, m in maxes do table.insert(entries, { key, m[1], m[2] }) end
	table.sort(entries, function(a, b) if a[3] ~= b[3] then return a[3] > b[3] end return a[1] < b[1] end)
	local W, H = 1915, 1075
	local sheets, cur, x, y, rowH = {}, {}, 4, 4, 0
	for _, e in entries do
		if x + e[2] > W then x = 4 y += rowH + 6 rowH = 0 end
		if y + e[3] > H then table.insert(sheets, cur) cur = {} x, y, rowH = 4, 4, 0 end
		table.insert(cur, e) x += e[2] + 6 rowH = math.max(rowH, e[3])
	end
	if #cur > 0 then table.insert(sheets, cur) end
	_G.FigmaSheets = sheets
	return #entries, #sheets
end
_G.FigmaAtlas = function(entries, bg)
	local SG = game.StarterGui
	local old = SG:FindFirstChild("_FigmaAtlas") if old then old:Destroy() end
	local gui = Instance.new("ScreenGui")
	gui.Name = "_FigmaAtlas" gui.IgnoreGuiInset = true gui.DisplayOrder = 10000 gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling gui.ResetOnSpawn = false
	local back = Instance.new("Frame") back.Name = "Back" back.Size = UDim2.fromScale(1, 1) back.BorderSizePixel = 0 back.BackgroundColor3 = bg back.Parent = gui
	local W = workspace.CurrentCamera.ViewportSize.X
	local x, y, rowH, pad = 4, 4, 0, 6
	local map, images = {}, {}
	for _, e in entries do
		local key, w, h = e[1], math.clamp(math.ceil(e[2]), 8, 400), math.clamp(math.ceil(e[3]), 8, 400)
		if x + w > W - 4 then x = 4 y += rowH + pad rowH = 0 end
		local img = Instance.new("ImageLabel")
		img.Name = key img.BackgroundTransparency = 1 img.BorderSizePixel = 0 img.ScaleType = Enum.ScaleType.Stretch
		local id, rest = key:match("^(%d+)@?(.*)$")
		img.Image = "rbxassetid://" .. id
		if rest and rest ~= "" then
			local ox, oy, sx, sy = rest:match("(%d+),(%d+),(%d+),(%d+)")
			img.ImageRectOffset = Vector2.new(tonumber(ox), tonumber(oy)) img.ImageRectSize = Vector2.new(tonumber(sx), tonumber(sy))
		end
		img.Position = UDim2.fromOffset(x, y) img.Size = UDim2.fromOffset(w, h) img.Parent = back
		table.insert(images, img)
		table.insert(map, ("%s\t%d\t%d\t%d\t%d"):format(key, x, y, w, h))
		x += w + pad rowH = math.max(rowH, h)
	end
	gui.Parent = SG
	game:GetService("ContentProvider"):PreloadAsync(images)
	task.wait(0.5)
	return map, y + rowH
end
_G.FigmaAtlasBg = function(bg) local g = game.StarterGui:FindFirstChild("_FigmaAtlas") if g then g.Back.BackgroundColor3 = bg end task.wait(0.3) end
_G.FigmaAtlasDone = function() local g = game.StarterGui:FindFirstChild("_FigmaAtlas") if g then g:Destroy() end end

return "fonctions de la copie Figma installées"
