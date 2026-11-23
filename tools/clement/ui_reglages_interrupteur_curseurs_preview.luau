--!nonstrict
-- ui_reglages_interrupteur_curseurs_preview.luau (Clément, 2026-11-22) : maquette de l'interrupteur et des curseurs de
-- UI_Settings au style des boutons Framewisp (propositions 4 et 5 de docs/claude/notes/2026-11-22_video-reglages.md).
-- Crée StarterGui._Maquette_Reglages : copie de la fenêtre avant / après, gros plans ON, OFF, curseur au repos et
-- curseur tenu (rond x1,35 et halo). Ne touche pas UI_Settings. Aucun script laissé.
-- Mode d'emploi : lancer figma_copie/export_studio.luau puis _G.FigmaDevice() (1920 x 1080), lancer ce fichier,
-- capturer (screen_capture), puis supprimer StarterGui._Maquette_Reglages et _G.FigmaDeviceOff().
-- _G.ReglagesApres(window) est le passage « après » ; il servira tel quel pour le vrai écran une fois validé.
-- Images : docs/claude/video/references/2026-11-22_Reglages/frames/reglages_interrupteur_curseurs_maquette.png
-- et reglages_interrupteur_curseurs_telephone.png (iPhone 17 Pro, avant / après).

local SG = game:GetService("StarterGui")
local INK = Color3.fromRGB(13, 13, 20)
local WHITE = Color3.new(1, 1, 1)
local GREEN, PINK = Color3.fromHex("9AFF09"), Color3.fromHex("FF3D8B")
local QUILT = "rbxassetid://87198718489515"

local function corner(o, s) local c = Instance.new("UICorner") c.CornerRadius = UDim.new(s, 0) c.Parent = o return c end
local function stroke(o, color, thickness, inner, mode)
	local s = Instance.new("UIStroke")
	s.Color = color s.Thickness = thickness s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	s.ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border s.LineJoinMode = Enum.LineJoinMode.Round
	if inner then s.BorderStrokePosition = Enum.BorderStrokePosition.Inner end
	s.Parent = o
	return s
end
local function grad(o, a, b, rot) local g = Instance.new("UIGradient") g.Rotation = rot or 90 g.Color = ColorSequence.new(a, b) g.Parent = o return g end
local function clear(o, pred) for _, c in ipairs(o:GetChildren()) do if pred(c) then c:Destroy() end end end
local function isBorder(c) return c:IsA("UIStroke") and c.ApplyStrokeMode == Enum.ApplyStrokeMode.Border end

-- Pilule au style des boutons : f devient le rebord sombre (Lip), avec dedans Face (dégradé), Quilt et Rim.
local function pill(f, color, z, opts)
	opts = opts or {}
	clear(f, function(c) return c:IsA("UIGradient") or c:IsA("UICorner") or isBorder(c) or c.Name == "Gloss" or c.Name == "Studs" or c.Name == "Face" end)
	f.BackgroundTransparency = 0
	f.BackgroundColor3 = color:Lerp(INK, 0.45)
	corner(f, 0.5)
	if not opts.noInk then stroke(f, INK, opts.ink or 0.065) end
	local face = Instance.new("Frame") face.Name = "Face" face.BorderSizePixel = 0
	face.Size = UDim2.fromScale(1, opts.faceH or 0.88) face.BackgroundColor3 = WHITE face.ZIndex = z
	corner(face, 0.5)
	grad(face, color:Lerp(WHITE, 0.28), color)
	local q = Instance.new("ImageLabel") q.Name = "Quilt" q.BackgroundTransparency = 1 q.Image = QUILT
	-- retouche de Clément (2026-11-22) : motif deux fois plus léger (0,82 -> 0,91)
	q.ScaleType = Enum.ScaleType.Tile q.ImageTransparency = opts.quilt or 0.91 q.Size = UDim2.fromScale(1, 1) q.ZIndex = z
	local a = f.AbsoluteSize.Y > 0 and f.AbsoluteSize.X / f.AbsoluteSize.Y or 3
	q.TileSize = UDim2.fromScale(math.clamp(0.9 / a, 0.03, 1), 0.9)
	corner(q, 0.5) q.Parent = face
	local rim = Instance.new("Frame") rim.Name = "Rim" rim.BackgroundTransparency = 1 rim.Size = UDim2.fromScale(1, 1) rim.ZIndex = z
	corner(rim, 0.5)
	local rs = stroke(rim, WHITE, opts.rim or 0.04, true) rs.Transparency = 0.45
	-- retouche de Clément (2026-11-22) : rien de la face sur l'ombre ; le liseré s'efface vers le bas (dégradé du contour)
	local rg = Instance.new("UIGradient") rg.Name = "RimFade" rg.Rotation = 90
	rg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.55, 0), NumberSequenceKeypoint.new(0.9, 1), NumberSequenceKeypoint.new(1, 1) })
	rg.Parent = rs
	rim.Parent = face
	face.Parent = f
	return face
end

-- Rond blanc : dégradé blanc -> gris bleuté, contour sombre. Sans motif (retouche de Clément, 2026-11-22).
local SLIDER_COLORS = { MusicRow = Color3.fromHex("A970FF"), SoundRow = Color3.fromHex("FFC62E") }
local function knobStyle(k, z)
	clear(k, function(c) return c:IsA("UIGradient") or c:IsA("UICorner") or isBorder(c) or c.Name == "Quilt" end)
	k.BackgroundColor3 = WHITE k.BackgroundTransparency = 0
	corner(k, 0.5)
	stroke(k, INK, 0.09)
	grad(k, WHITE, Color3.fromHex("CDD3E2"))
	local shade = k:FindFirstChild("Shade")
	if shade then clear(shade, function(c) return c:IsA("UICorner") end) corner(shade, 0.5) end
end

_G.ReglagesApres = function(window)
	local rows = window:FindFirstChild("Rows")
	-- interrupteur (VfxRow.Toggle)
	local t = rows.VfxRow.Toggle
	clear(t, isBorder)
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(0.24, 0.7)
	-- retouche de Clément (2026-11-22, Figma) : interrupteur calé à droite, sur le bord droit des flèches › (0,97)
	t.AnchorPoint = Vector2.new(1, 0.5) t.Position = UDim2.fromScale(0.97, 0.5)
	local tc = t:FindFirstChildOfClass("UISizeConstraint") if tc then tc.MinSize = Vector2.new(88, 44) end -- téléphone : pilule 2:1
	pill(t.OnFill, GREEN, t.OnFill.ZIndex)
	pill(t.OffFill, PINK, t.OffFill.ZIndex)
	local tk = t.ToggleKnob
	tk.Size = UDim2.fromScale(1, 0.7)
	tk.AnchorPoint = Vector2.new(1, 0.5) tk.Position = UDim2.fromScale(0.955, 0.44)
	knobStyle(tk, tk.ZIndex)
	local tl = t.ToggleLabel
	tl.AnchorPoint = Vector2.new(0, 0.5) tl.Position = UDim2.fromScale(0.1, 0.44) tl.Size = UDim2.fromScale(0.5, 0.56)
	local ts = tl:FindFirstChildOfClass("UIStroke") if ts then ts.Color = INK end
	local sh = t:FindFirstChild("Shade") if sh then clear(sh, function(c) return c:IsA("UICorner") end) corner(sh, 0.5) end
	-- curseurs (MusicRow, SoundRow)
	for _, rn in { "MusicRow", "SoundRow" } do
		local sl = rows[rn].Slider
		local tr, fill, knob = sl.Track, sl.Track.Fill, sl.Knob
		local color = SLIDER_COLORS[rn]
		sl.Size = UDim2.new(0.27, 0, sl.Size.Y.Scale, 0) -- « 100% » n'est plus mangé par le rond (PC et téléphone)
		local v = rows[rn].ValueLabel v.Position = UDim2.new(0.895, 0, v.Position.Y.Scale, 0) v.Size = UDim2.new(0.095, 0, v.Size.Y.Scale, 0)
		clear(tr, function(c) return c.Name == "Lip" or c.Name == "Rim" or c.Name == "Gloss" or c:IsA("UICorner") or isBorder(c) or c:IsA("UIGradient") end)
		tr.Size = UDim2.fromScale(1, 0.56)
		tr.BackgroundColor3 = WHITE tr.BackgroundTransparency = 0
		grad(tr, Color3.fromHex("080A12"), Color3.fromHex("2B3149"))
		corner(tr, 0.5) stroke(tr, INK, 0.12)
		clear(fill, function(c) return c:IsA("UIStroke") end)
		pill(fill, color, fill.ZIndex, { noInk = true, faceH = 0.78, rim = 0.06, quilt = 0.93 })
		knobStyle(knob, knob.ZIndex)
		-- halo caché, montré par le code pendant le glisser (proposition 6)
		local halo = knob:FindFirstChild("Halo") or Instance.new("Frame")
		halo.Name = "Halo" halo.AnchorPoint = Vector2.new(0.5, 0.5) halo.Position = UDim2.fromScale(0.5, 0.5)
		halo.Size = UDim2.fromScale(1.75, 1.75) halo.BackgroundColor3 = color:Lerp(WHITE, 0.5) halo.BackgroundTransparency = 0.55
		halo.ZIndex = math.max(1, knob.ZIndex - 1) halo.Visible = false halo.BorderSizePixel = 0
		if not halo:FindFirstChildOfClass("UICorner") then corner(halo, 0.5) end
		halo.Parent = knob
	end
end

-- Maquette -----------------------------------------------------------------------------------------------------------
local src = SG.UI_Settings.Root.Window
local old = SG:FindFirstChild("_Maquette_Reglages") if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "_Maquette_Reglages" gui.IgnoreGuiInset = true gui.DisplayOrder = 10003 gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
gui.Parent = SG
local bg = Instance.new("Frame") bg.Name = "Back" bg.Size = UDim2.fromScale(1, 1) bg.BackgroundColor3 = Color3.fromHex("2A3150") bg.BorderSizePixel = 0 bg.ZIndex = 1 bg.Parent = gui
grad(bg, Color3.fromHex("3A4470"), Color3.fromHex("1C2138"))

local function text(parent, s, x, y, w, h, size, color, xa)
	local l = Instance.new("TextLabel") l.BackgroundTransparency = 1 l.Text = s l.RichText = true
	l.Position = UDim2.fromOffset(x, y) l.Size = UDim2.fromOffset(w, h) l.TextSize = size l.TextColor3 = color or WHITE
	l.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold) l.ZIndex = 50
	l.TextXAlignment = xa or Enum.TextXAlignment.Left l.TextYAlignment = Enum.TextYAlignment.Top l.TextWrapped = true
	local s2 = Instance.new("UIStroke") s2.Color = INK s2.Thickness = 2 s2.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual s2.Parent = l
	l.Parent = parent
	return l
end
local function holder(name, x, y, w, h)
	local f = Instance.new("Frame") f.Name = name f.BackgroundTransparency = 1 f.Position = UDim2.fromOffset(x, y) f.Size = UDim2.fromOffset(w, h) f.ZIndex = 2 f.Parent = bg
	return f
end
local function windowCopy(name, x, y)
	local h = holder(name, x, y, 674, 600)
	local w = src:Clone() w.Position = UDim2.fromScale(0, 0) w.Size = UDim2.fromScale(1, 1) w.Parent = h
	return w
end

text(bg, "Réglages : interrupteur et curseurs au style des boutons (maquette 2026-11-22)", 40, 18, 1400, 40, 30)
text(bg, "AVANT (aujourd'hui)", 40, 66, 674, 30, 22, Color3.fromHex("C9D2F0"))
text(bg, "APRÈS", 754, 66, 674, 30, 22, GREEN)
windowCopy("Avant", 40, 100)
local after = windowCopy("Apres", 754, 100)
task.wait(0.1)
_G.ReglagesApres(after)

-- gros plans (x2) dans la colonne de droite
local function closeUp(name, srcObj, x, y, scale)
	local a = srcObj.AbsoluteSize
	local h = holder(name, x, y, math.floor(a.X * scale + 0.5), math.floor(a.Y * scale + 0.5))
	local c = srcObj:Clone() c.AnchorPoint = Vector2.zero c.Position = UDim2.fromScale(0, 0) c.Size = UDim2.fromScale(1, 1)
	for _, k in ipairs(c:GetChildren()) do if k:IsA("UISizeConstraint") then k:Destroy() end end
	c.Parent = h
	return c, h
end
task.wait(0.2)
local rowsA = after.Rows
local X = 1470
local K = 1.6
local CAP = Color3.fromHex("C9D2F0")
text(bg, "Interrupteur ON", X, 100, 420, 26, 20, CAP)
closeUp("ToggleOn", rowsA.VfxRow.Toggle, X + 60, 132, K)
text(bg, "Interrupteur OFF : rose, rond à gauche", X, 244, 420, 26, 20, CAP)
local off = closeUp("ToggleOff", rowsA.VfxRow.Toggle, X + 60, 276, K)
off.OnFill.Visible = false off.OffFill.Visible = true off.ToggleLabel.Text = "OFF"
for _, n in { "ToggleKnob", "ToggleLabel" } do
	local o = off[n] o.AnchorPoint = Vector2.new(1 - o.AnchorPoint.X, o.AnchorPoint.Y) o.Position = UDim2.new(1 - o.Position.X.Scale, 0, o.Position.Y.Scale, 0)
end
text(bg, "Curseur au repos", X, 390, 420, 26, 20, CAP)
closeUp("SliderRest", rowsA.MusicRow.Slider, X + 40, 436, K)
text(bg, "Curseur tenu : rond ×1,35 et halo (code)", X, 540, 420, 26, 20, CAP)
local held = closeUp("SliderHeld", rowsA.MusicRow.Slider, X + 40, 640, K)
held.Knob.Position = UDim2.new(0.55, 0, held.Knob.Position.Y.Scale, 0)
held.Track.Fill.Size = UDim2.new(0.55, 0, held.Track.Fill.Size.Y.Scale, 0)
local us = Instance.new("UIScale") us.Scale = 1.35 us.Parent = held.Knob
held.Knob.Halo.Visible = true

local L = 790
text(bg, "<font color=\"#9AFF09\">Ce qui change (visuel, je le fais)</font>\n• Interrupteur en pilule : vert ON, rose OFF, rebord sombre, motif et liseré comme les boutons\n• Rond blanc dans la pilule, contour sombre ; ON / OFF centré sur la face\n• Curseurs : piste en creux, remplissage en pilule avec motif (violet Music, jaune Sound), rond blanc à contour sombre\n• Curseurs un peu moins larges : « 100% » n'est plus mangé par le rond (PC et téléphone)\n• Téléphone : pilule de 88 × 44 px au moins, « ON » n'est plus caché par le rond", 40, L, 900, 260, 20)
text(bg, "<font color=\"#FFD84A\">Ce qui ne change pas</font>\n• Aucun nom lu par le code : Toggle, OnFill, OffFill, ToggleKnob, ToggleLabel, Track, Fill, Knob, ValueLabel\n• Aucun script ; le code bouge toujours le rond et la largeur du remplissage", 980, L, 900, 140, 20)
text(bg, "<font color=\"#FF8FC0\">Pour Ironix (si validé)</font> : montrer Knob.Halo pendant le glisser et passer KnobGrab de ×1,18 à ×1,35 (proposition 6).", 980, L + 150, 900, 80, 20)
return "maquette posée"
