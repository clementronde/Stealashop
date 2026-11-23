--!nonstrict
-- ui_boutons_style_framewisp.luau (Clément, 2026-11-22) : les boutons des boutiques au style des boutons Framewisp de
-- Clément (« revoir tous les boutons, tous les contours pour que ça soit dans le même style que les nouveaux boutons ;
-- une bonne cohérence visuelle sur tous les boutons de toutes les boutiques »). Maquette validée :
-- docs/claude/video/references/2026-11-21_ShopTikTok/frames/boutiques_boutons_avant_apres.png. Fiche :
-- docs/claude/notes/ui-reference-shop-tiktok-2026-11-21.md, section 14. À lancer en Edit. Aucun script.
--
-- Boutons concernés : tout GuiButton à l'ancien style (Fill, Lip et Rim ; ou Lip, Rim et Gloss / Studs, couleur sur le
-- bouton) des écrans de SCREENS, sauf les curseurs Track des réglages ; les autres
-- (boutons Framewisp du HUD, boutons déjà refaits) ne bougent pas. Pour chacun :
--   - retirés : Fill (et son Gloss, Studs, Outline), Gloss, Studs, Lip, Rim, Shine, le UIGradient, le UIStroke et le
--     UICorner du bouton ;
--   - gardés : tous les textes (Price, EquipLabel, RobuxPrice, XLabel, TabLabel… et le texte du bouton lui-même), Content
--     (RobuxIcon), Shade (le survol l'assombrit), Selected (onglets), Icon, contraintes, UIPadding, pastilles ;
--   - ajoutés, sous les textes : Lip (rebord sombre), Face (dégradé de la couleur d'origine du bouton, motif Quilt
--     87198718489515, liseré clair Rim) ; contour des textes en sombre (#0D0D14), couleur des textes gardée ; textes des
--     pastilles (…Alert) et étiquettes (…Tag) laissés tels quels ;
--   - ombre portée (LabelShadow) seulement pour les textes fixes (XLabel, TabLabel, CloseLabel, ArrowLabel, AddLabel) :
--     les autres sont écrits par le code (il écrit dans le premier TextLabel du bouton : une copie ne doit pas passer avant).
-- Plaques d'état (le code en montre une à la fois) : les Frames à l'ancien style (Studs et dégradé) enfants d'un bouton
-- (Disabled / Ready / Confirm de la Renaissance) ou nommées Owned (cartes de la boutique Robux) : même style, noms et
-- contenu gardés, calques au ZIndex de la plaque.
-- Écrans en ZIndexBehavior Global : les nouveaux calques prennent le ZIndex du bouton moins 1 (sous son texte).
-- Texte centré sur la face, pas sur le bouton entier (2026-11-22, fin du script ; sauvegarde 2026-11-22_TexteCentre).
-- Retouches de Clément (2026-11-22, maquette des Réglages) : motif Quilt à 0,91 (au lieu de 0,82) et liseré Rim qui
-- s'efface vers le bas (UIGradient RimFade sous son UIStroke). Les boutons déjà refaits ont été retouchés par
-- ui_boutons_retouches_motif_lisere.luau (sauvegarde 2026-11-22_RetouchesBoutons).
-- Sauvegarde : ServerStorage/MapBackups/2026-11-22_BoutonsFW/<écran>. Rejouable (un bouton déjà refait est sauté).

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")
local SCREENS = { "UI_AuraShop", "UI_WeaponShop", "UI_DiamondShop", "UI_RobuxShop_v2", "UI_Wheel", "UI_Rebirth", "UI_Rewards", "UI_SkillTree", "UI_Settings", "UI_Index_v3", "UI_HelpInvite", "UI_Offline", "UI_Tutorial" }
local SKIP = { Track = true } -- curseurs des réglages (Fill = la part remplie), pas des boutons
local INK = Color3.fromRGB(13, 13, 20)
local QUILT = "rbxassetid://87198718489515"
local REMOVE = { Fill = true, Gloss = true, Studs = true, Lip = true, Rim = true, Shine = true, Outline = true }
local SHADOW = { XLabel = true, TabLabel = true, CloseLabel = true, ArrowLabel = true, AddLabel = true } -- textes fixes

local function corner(o, s) local c = Instance.new("UICorner") c.CornerRadius = UDim.new(s, 0) c.Parent = o return c end
local function stroke(o, color, thickness, inner, mode)
	local s = Instance.new("UIStroke")
	s.Color = color s.Thickness = thickness s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	s.ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border s.LineJoinMode = Enum.LineJoinMode.Round
	if inner then s.BorderStrokePosition = Enum.BorderStrokePosition.Inner end
	s.Parent = o
	return s
end
-- liseré blanc de la face : il s'efface vers le bas, rien de la face sur l'ombre (retouche de Clément, 2026-11-22)
local function rimFade(s)
	s.Transparency = 0.45
	local g = Instance.new("UIGradient") g.Name = "RimFade" g.Rotation = 90
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.55, 0), NumberSequenceKeypoint.new(0.9, 1), NumberSequenceKeypoint.new(1, 1) })
	g.Parent = s
	return s
end
local function colorAt(cs, t)
	local kp = cs.Keypoints
	if t <= kp[1].Time then return kp[1].Value end
	for i = 1, #kp - 1 do local a, b = kp[i], kp[i + 1] if t <= b.Time then return a.Value:Lerp(b.Value, (t - a.Time) / math.max(1e-6, b.Time - a.Time)) end end
	return kp[#kp].Value
end
-- couleur d'origine du bouton : fond de Fill (ou du bouton) multiplié par le milieu de son dégradé
local function baseColor(btn)
	local fill = btn:FindFirstChild("Fill")
	local holder = fill or btn
	local col = holder.BackgroundColor3
	local g = holder:FindFirstChildOfClass("UIGradient")
	if g then local m = colorAt(g.Color, 0.5) col = Color3.new(col.R * m.R, col.G * m.G, col.B * m.B) end
	return col
end
local function oldStyle(b)
	-- ancien style des boutiques (Fill, Lip, Rim) ou du HUD (Lip, Rim et Gloss ou Studs, couleur sur le bouton)
	return b:IsA("GuiButton") and not SKIP[b.Name] and b:FindFirstChild("Lip") and b:FindFirstChild("Rim")
		and (b:FindFirstChild("Fill") or b:FindFirstChild("Gloss") or b:FindFirstChild("Studs")) and not b:FindFirstChild("Face")
end
local function textStroke(t)
	local s = t:FindFirstChildOfClass("UIStroke")
	if s then s.Color = INK s.Transparency = 0 if s.StrokeSizingMode ~= Enum.StrokeSizingMode.ScaledSize then s.Thickness = math.max(s.Thickness, 2) end
	else stroke(t, INK, 0.12, false, Enum.ApplyStrokeMode.Contextual) end
end

local function restyle(btn)
	local color = baseColor(btn)
	for _, c in ipairs(btn:GetChildren()) do
		if REMOVE[c.Name] or c:IsA("UIGradient") or c:IsA("UICorner") or (c:IsA("UIStroke") and c.ApplyStrokeMode == Enum.ApplyStrokeMode.Border) then c:Destroy() end
	end
	btn.BackgroundTransparency = 1
	btn.AutoButtonColor = false
	local z = math.max(1, btn.ZIndex - 1)
	local size = btn.AbsoluteSize
	local aspect = size.Y > 0 and size.X / size.Y or 2.8
	local lip = Instance.new("Frame") lip.Name = "Lip" lip.Size = UDim2.fromScale(1, 1) lip.BackgroundColor3 = color:Lerp(INK, 0.45) lip.ZIndex = z
	corner(lip, 0.18) stroke(lip, INK, 0.065) lip.Parent = btn
	local face = Instance.new("Frame") face.Name = "Face" face.Size = UDim2.fromScale(1, 0.88) face.BackgroundColor3 = color face.ZIndex = z face.ClipsDescendants = true
	corner(face, 0.18)
	local g = Instance.new("UIGradient") g.Rotation = 90 g.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.28), color) g.Parent = face
	local q = Instance.new("ImageLabel") q.Name = "Quilt" q.BackgroundTransparency = 1 q.Image = QUILT q.ScaleType = Enum.ScaleType.Tile q.ImageTransparency = 0.91
	q.Size = UDim2.fromScale(1, 1) q.ZIndex = z q.TileSize = UDim2.fromScale(math.clamp(0.9 / aspect, 0.03, 1), 0.9) q.Parent = face
	local rim = Instance.new("Frame") rim.Name = "Rim" rim.BackgroundTransparency = 1 rim.Size = UDim2.fromScale(1, 1) rim.ZIndex = z
	corner(rim, 0.18) rimFade(stroke(rim, Color3.new(1, 1, 1), 0.04, true)) rim.Parent = face
	face.Parent = btn
	-- le survol assombrit Shade : même arrondi que la face
	local shade = btn:FindFirstChild("Shade")
	if shade then for _, c in ipairs(shade:GetChildren()) do if c:IsA("UICorner") then c:Destroy() end end corner(shade, 0.18) end
	-- un bouton avec une marge intérieure (UIPadding, pour son texte) : les calques la compensent et couvrent tout le bouton
	local p = btn:FindFirstChildOfClass("UIPadding")
	if p then
		local sl, sr, st, sb = p.PaddingLeft.Scale, p.PaddingRight.Scale, p.PaddingTop.Scale, p.PaddingBottom.Scale
		local ol, orr, ot, ob = p.PaddingLeft.Offset, p.PaddingRight.Offset, p.PaddingTop.Offset, p.PaddingBottom.Offset
		local kx, ky = 1 / math.max(0.05, 1 - sl - sr), 1 / math.max(0.05, 1 - st - sb)
		for _, f in { lip, face, shade } do
			if f then
				local h = f == face and 0.88 or 1
				f.Position = UDim2.new(-sl * kx, -ol, -st * ky, -ot)
				f.Size = UDim2.new(kx, ol + orr, h * ky, (ot + ob) * h)
			end
		end
	end
	-- textes : blancs, contour sombre
	if btn:IsA("TextButton") and btn.Text ~= "" then
		btn.TextColor3 = Color3.new(1, 1, 1)
		stroke(btn, INK, 0.12, false, Enum.ApplyStrokeMode.Contextual)
	end
	for _, t in ipairs(btn:GetDescendants()) do
		-- couleur des textes gardée (prix barré, étiquettes) ; pastilles et étiquettes laissées telles quelles
		local inTag = false
		local p0 = t.Parent
		while p0 and p0 ~= btn do if p0.Name:match("Alert$") or p0.Name:match("Tag$") then inTag = true end p0 = p0.Parent end
		if t:IsA("TextLabel") and t.Name ~= "LabelShadow" and not inTag then
			textStroke(t)
			if SHADOW[t.Name] and not t.Parent:FindFirstChild("LabelShadow") then
				local s = t:Clone() s.Name = "LabelShadow" s.TextColor3 = INK s.ZIndex = math.max(btn.ZIndex, t.ZIndex - 1)
				s.Position = t.Position + UDim2.fromScale(0, 0.05)
				for _, c in ipairs(s:GetChildren()) do if not c:IsA("UIStroke") then c:Destroy() end end
				s.Parent = t.Parent
			end
		end
	end
end

-- plaques d'état (le code en montre une à la fois) : Disabled / Ready / Confirm d'un bouton, Owned d'une carte de la boutique
-- Robux. Même style, calques au ZIndex de la plaque (son contenu est au-dessus).
local function plateStyle(f)
	return f:IsA("Frame") and f:FindFirstChild("Studs") and f:FindFirstChildOfClass("UIGradient") and not f:FindFirstChild("Face")
		and (f.Name == "Owned" or (f.Parent and f.Parent:IsA("GuiButton") and not SKIP[f.Parent.Name]))
end
local function restylePlate(f)
	local color = baseColor(f)
	for _, c in ipairs(f:GetChildren()) do
		if c.Name == "Studs" or c.Name == "Gloss" or c:IsA("UIGradient") or c:IsA("UICorner") or (c:IsA("UIStroke") and c.ApplyStrokeMode == Enum.ApplyStrokeMode.Border) then c:Destroy() end
	end
	f.BackgroundTransparency = 1
	local z = f.ZIndex
	local size = f.AbsoluteSize
	local aspect = size.Y > 0 and size.X / size.Y or 2.8
	local lip = Instance.new("Frame") lip.Name = "Lip" lip.Size = UDim2.fromScale(1, 1) lip.BackgroundColor3 = color:Lerp(INK, 0.45) lip.ZIndex = z
	corner(lip, 0.18) stroke(lip, INK, 0.065) lip.Parent = f
	local face = Instance.new("Frame") face.Name = "Face" face.Size = UDim2.fromScale(1, 0.88) face.BackgroundColor3 = color face.ZIndex = z face.ClipsDescendants = true
	corner(face, 0.18)
	local g = Instance.new("UIGradient") g.Rotation = 90 g.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.28), color) g.Parent = face
	local q = Instance.new("ImageLabel") q.Name = "Quilt" q.BackgroundTransparency = 1 q.Image = QUILT q.ScaleType = Enum.ScaleType.Tile q.ImageTransparency = 0.91
	q.Size = UDim2.fromScale(1, 1) q.ZIndex = z q.TileSize = UDim2.fromScale(math.clamp(0.9 / aspect, 0.03, 1), 0.9) q.Parent = face
	local rim = Instance.new("Frame") rim.Name = "Rim" rim.BackgroundTransparency = 1 rim.Size = UDim2.fromScale(1, 1) rim.ZIndex = z
	corner(rim, 0.18) rimFade(stroke(rim, Color3.new(1, 1, 1), 0.04, true)) rim.Parent = face
	face.Parent = f
	for _, t in ipairs(f:GetDescendants()) do if t:IsA("TextLabel") then textStroke(t) end end
	-- le bouton qui porte les plaques : son Shade prend le même arrondi
	local shade = f.Parent and f.Parent:FindFirstChild("Shade")
	if shade and f.Parent:IsA("GuiButton") then for _, c in ipairs(shade:GetChildren()) do if c:IsA("UICorner") then c:Destroy() end end corner(shade, 0.18) end
end

local rec = CHS:TryBeginRecording("UI : boutons au style Framewisp (tous les écrans)")
local report = {}
local ok, err = pcall(function()
	local mb = SS:FindFirstChild("MapBackups") or Instance.new("Folder")
	mb.Name = "MapBackups" mb.Parent = SS
	local bf = mb:FindFirstChild("2026-11-22_BoutonsFW") or Instance.new("Folder")
	bf.Name = "2026-11-22_BoutonsFW" bf.Parent = mb
	for _, name in SCREENS do
		local gui = SG:FindFirstChild(name)
		if gui then
			if not bf:FindFirstChild(name) then gui:Clone().Parent = bf end
			local was = gui.Enabled
			gui.Enabled = true -- tailles réelles pour le motif
			task.wait(0.1)
			local n = 0
			local np = 0
			for _, b in ipairs(gui:GetDescendants()) do if oldStyle(b) then restyle(b) n += 1 end end
			for _, f in ipairs(gui:GetDescendants()) do if plateStyle(f) then restylePlate(f) np += 1 end end
			gui.Enabled = was
			if n + np > 0 then table.insert(report, name .. " : " .. n .. " boutons, " .. np .. " plaques") end
		end
	end
	-- couleurs harmonisées : un seul vert d'action (#9AFF09, celui des 64 boutons d'achat) et un seul rose pour les croix
	-- de fermeture (#FF3D8B) ; contour d'onglet choisi (Selected) arrondi comme le bouton
	local GREEN, CLOSE = Color3.fromHex("9AFF09"), Color3.fromHex("FF3D8B")
	local REMAP = { ["91F630"] = GREEN, ["6ED628"] = GREEN }
	local function hex(c) return string.format("%02X%02X%02X", c.R * 255 + 0.5, c.G * 255 + 0.5, c.B * 255 + 0.5) end
	local nc = 0
	local all = table.clone(SCREENS)
	table.insert(all, "UI_Displayed")
	for _, name in all do
		local gui = SG:FindFirstChild(name)
		for _, f in ipairs(gui and gui:GetDescendants() or {}) do
			if f.Name == "Face" and f:FindFirstChild("Quilt") then
				local host = f.Parent
				local to = REMAP[hex(f.BackgroundColor3)]
				if host.Name == "CloseButton" and hex(f.BackgroundColor3) ~= "FF3D8B" then to = CLOSE end
				if to then
					f.BackgroundColor3 = to
					local fg = f:FindFirstChildOfClass("UIGradient")
					if fg then fg.Color = ColorSequence.new(to:Lerp(Color3.new(1, 1, 1), 0.28), to) end
					local lp = host:FindFirstChild("Lip")
					if lp then lp.BackgroundColor3 = to:Lerp(INK, 0.45) end
					nc += 1
				end
				local sel = host:FindFirstChild("Selected")
				if sel and sel:IsA("Frame") and not sel:FindFirstChildOfClass("UICorner") then corner(sel, 0.18) end
				-- ombre portée de l'ancien style (Shadow dans le bouton, ButtonShadow à côté) : sous les nouveaux calques
				local shs = { host:FindFirstChild("Shadow"), host.Parent and host.Parent:FindFirstChild("ButtonShadow") }
				for _, sh in shs do if sh:IsA("Frame") and sh.ZIndex >= f.ZIndex then sh.ZIndex = math.max(1, f.ZIndex - 1) end end
			end
		end
	end
	if nc > 0 then table.insert(report, nc .. " boutons recolorés (vert d'action, croix)") end
	-- hors ligne : CLAIM centré comme les autres boutons
	local off = SG:FindFirstChild("UI_Offline")
	local cl = off and off:FindFirstChild("ClaimLabel", true)
	if cl and cl:IsA("TextLabel") then cl.TextXAlignment = Enum.TextXAlignment.Center end
	-- Renaissance : le corps (UIListLayout en flex) débordait de sa marge haute et basse (le flex ne la retire pas) et
	-- rognait le bas du bouton REBIRTH. La marge passe dans la position et la taille du corps.
	local rb = SG:FindFirstChild("UI_Rebirth")
	local body = rb and rb:FindFirstChild("Body", true)
	local pad = body and body:FindFirstChildOfClass("UIPadding")
	if pad and (pad.PaddingTop ~= UDim.new() or pad.PaddingBottom ~= UDim.new()) then
		local t, b = pad.PaddingTop, pad.PaddingBottom
		body.Position = body.Position + UDim2.new(0, 0, t.Scale, t.Offset)
		body.Size = body.Size - UDim2.new(0, 0, t.Scale + b.Scale, t.Offset + b.Offset)
		pad.PaddingTop = UDim.new() pad.PaddingBottom = UDim.new()
		table.insert(report, "UI_Rebirth : marge du corps passée dans sa taille")
	end
	-- Texte centré sur la face (Clément, 2026-11-22 : « l'ombre en dessous du bouton ne doit pas être prise dans
	-- l'alignement vertical ») : le contenu du bouton (textes, icônes, Content, ombres des textes) remonte pour que son
	-- milieu soit celui de Face (44 % de la hauteur), pas celui du bouton entier rebord compris (50 %). Texte porté par le
	-- bouton lui-même (EquipButton) : la marge du bas prend 12 points de plus que celle du haut. Rejouable (écart nul).
	local KEEPC = { Lip = true, Face = true, Shade = true, Selected = true, Shadow = true, HoverOutline = true, Outline = true }
	local function fixedC(c) return KEEPC[c.Name] or c.Name:match("Alert$") or c.Name:match("Tag$") or c.Name:match("Sheen") end
	local ncent = 0
	for _, gui in ipairs(SG:GetChildren()) do
		if gui:IsA("ScreenGui") then
			local hosts = {}
			for _, f in ipairs(gui:GetDescendants()) do if f.Name == "Face" and f:FindFirstChild("Quilt") then table.insert(hosts, f.Parent) end end
			if #hosts > 0 then
				local was = gui.Enabled
				gui.Enabled = true
				task.wait(0.05)
				for _, host in hosts do
					local face = host.Face
					local fc = face.AbsolutePosition.Y + face.AbsoluteSize.Y / 2
					local pad = host:FindFirstChildOfClass("UIPadding")
					if host:IsA("TextButton") and host.Text ~= "" then
						if not pad then pad = Instance.new("UIPadding") pad.Parent = host end
						local t, b = pad.PaddingTop.Scale, pad.PaddingBottom.Scale
						local d = (t + 1 - b) / 2 - 0.44
						if math.abs(d) > 0.005 then
							pad.PaddingTop = UDim.new(t - d, pad.PaddingTop.Offset)
							pad.PaddingBottom = UDim.new(b + d, pad.PaddingBottom.Offset)
							local sl, sr, st, sb = pad.PaddingLeft.Scale, pad.PaddingRight.Scale, pad.PaddingTop.Scale, pad.PaddingBottom.Scale
							local ol, orr, ot, ob = pad.PaddingLeft.Offset, pad.PaddingRight.Offset, pad.PaddingTop.Offset, pad.PaddingBottom.Offset
							local kx, ky = 1 / math.max(0.05, 1 - sl - sr), 1 / math.max(0.05, 1 - st - sb)
							for _, n in { "Lip", "Face", "Shade" } do
								local f = host:FindFirstChild(n)
								if f then
									local hh = n == "Face" and 0.88 or 1
									f.Position = UDim2.new(-sl * kx, -ol, -st * ky, -ot)
									f.Size = UDim2.new(kx, ol + orr, hh * ky, (ot + ob) * hh)
								end
							end
							ncent += 1
						end
					else
						local top, bot = math.huge, -math.huge
						for _, c in ipairs(host:GetChildren()) do
							if c:IsA("GuiObject") and c.Visible and not fixedC(c) and c.Name ~= "LabelShadow" then
								top = math.min(top, c.AbsolutePosition.Y) bot = math.max(bot, c.AbsolutePosition.Y + c.AbsoluteSize.Y)
							end
						end
						if top < math.huge then
							local dy = (top + bot) / 2 - fc
							if math.abs(dy) > 0.5 then
								local h = host.AbsoluteSize.Y
								local pt = pad and (pad.PaddingTop.Scale * h + pad.PaddingTop.Offset) or 0
								local pb = pad and (pad.PaddingBottom.Scale * h + pad.PaddingBottom.Offset) or 0
								local dS = dy / math.max(1, h - pt - pb)
								for _, c in ipairs(host:GetChildren()) do
									if c:IsA("GuiObject") and not fixedC(c) then c.Position = c.Position - UDim2.new(0, 0, dS, 0) end
								end
								ncent += 1
							end
						end
					end
				end
				gui.Enabled = was
			end
		end
	end
	if ncent > 0 then table.insert(report, ncent .. " boutons : texte centré sur la face") end
end)
if rec then CHS:FinishRecording(rec, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel) end
if not ok then error(err) end
local scripts = 0
for _, d in ipairs(SG:GetDescendants()) do if d:IsA("LuaSourceContainer") then scripts += 1 end end
table.insert(report, "scripts dans StarterGui : " .. scripts)
return table.concat(report, "\n")
