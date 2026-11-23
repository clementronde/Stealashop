--!nonstrict
-- ui_reglages_options_preview.luau (Clément, 2026-11-22) : maquette des nouvelles options de UI_Settings (confort et
-- performances). Demande de Clément : « ajouter plus d'options intéressantes dans l'UI settings qui peuvent être utiles
-- pour le confort du joueur et pour les performances ». Fiche : docs/claude/notes/2026-11-22_video-reglages.md, section 5.
--
-- Crée StarterGui._Maquette_Options (temporaire, à supprimer après la capture). Ne touche pas UI_Settings.
-- Prérequis, en Edit : ui_reglages_interrupteur_curseurs_preview.luau (définit _G.ReglagesApres), puis
-- figma_copie/export_studio.luau et _G.FigmaDevice() pour la capture en 1920 x 1080.
--
-- _G.ReglagesListe(window, rowH, headH) : la liste qui défile, avec sections et nouvelles rangées. Rows passe dans un
-- ScrollingFrame RowsScroll ; les rangées existantes restent dans Rows avec leurs noms (le code les retrouve par leur nom,
-- Contract/Find.path cherche dans tous les descendants). Hauteurs en px dans la maquette (à rendre responsive à
-- l'application).

local SG = game:GetService("StarterGui")
local INK = Color3.fromRGB(13, 13, 20)
local WHITE = Color3.new(1, 1, 1)
local GREEN = Color3.fromHex("9AFF09")
local PALE = Color3.fromHex("C9D2F0")
local MONT = "rbxasset://fonts/families/Montserrat.json"
assert(_G.ReglagesApres, "lancer d'abord ui_reglages_interrupteur_curseurs_preview.luau")

-- Icônes provisoires (déjà dans le jeu) ; les vraies sont à dessiner par Clément.
local ICONS = {
	PerfRow = { "rbxassetid://94595191807390", "UI_Icon_Performance" }, -- provisoire : UI_Icon_Upgrades
	OthersFxRow = { "rbxassetid://138049310771744", "UI_Icon_OthersFx" }, -- provisoire : UI_Icon_Aura
	ShakeRow = { "rbxassetid://130895616275969", "UI_Icon_Shake" }, -- provisoire : UI_Icon_Camera
	FovRow = { "rbxassetid://114903617420676", "UI_Icon_Fov" }, -- provisoire : UI_Icon_SpeedBoost
	FlashRow = { "rbxassetid://135663549761247", "UI_Icon_Flash" }, -- provisoire : UI_Icon_Warning
	HudSizeRow = { "rbxassetid://122667151083826", "UI_Icon_HudSize" }, -- provisoire : UI_Icon_Displays
}

local function stroke(o, color, th)
	local s = Instance.new("UIStroke") s.Color = color s.Thickness = th s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual s.LineJoinMode = Enum.LineJoinMode.Round s.Parent = o
	return s
end

-- Petit texte d'aide sous le nom de la rangée (RowLabel remonte).
local function hint(row, text)
	local rl = row:FindFirstChild("RowLabel")
	rl.Position = UDim2.new(rl.Position.X.Scale, 0, 0.36, 0) rl.Size = UDim2.new(rl.Size.X.Scale, 0, 0.36, 0)
	local h = row:FindFirstChild("RowHint") or Instance.new("TextLabel")
	h.Name = "RowHint" h.BackgroundTransparency = 1 h.AnchorPoint = Vector2.new(0, 0.5)
	h.Position = UDim2.new(rl.Position.X.Scale, 0, 0.72, 0) h.Size = UDim2.new(0.44, 0, 0.24, 0)
	h.FontFace = Font.new(MONT, Enum.FontWeight.Bold) h.TextScaled = true h.TextColor3 = PALE
	h.TextXAlignment = Enum.TextXAlignment.Left h.Text = text h.ZIndex = rl.ZIndex
	if not h:FindFirstChildOfClass("UIStroke") then stroke(h, INK, 0.12) end
	h.Parent = row
	return h
end

local function setToggle(t, on)
	t.OnFill.Visible = on t.OffFill.Visible = not on
	t.ToggleLabel.Text = on and "ON" or "OFF"
	local k, l = t.ToggleKnob, t.ToggleLabel
	-- places de Clément = état ON (rond à droite) ; OFF = symétrique
	k.AnchorPoint = Vector2.new(on and 1 or 0, 0.5) k.Position = UDim2.fromScale(on and 0.955 or 0.045, 0.44)
	l.AnchorPoint = Vector2.new(on and 0 or 1, 0.5) l.Position = UDim2.fromScale(on and 0.1 or 0.9, 0.44)
end

local function header(rows, name, text, order, headH)
	local h = Instance.new("Frame") h.Name = name h.BackgroundTransparency = 1 h.Size = UDim2.new(1, 0, 0, headH) h.LayoutOrder = order h.ZIndex = 4
	local l = Instance.new("TextLabel") l.Name = "HeaderLabel" l.BackgroundTransparency = 1 l.Text = text
	l.FontFace = Font.new(MONT, Enum.FontWeight.Heavy) l.TextScaled = true l.TextColor3 = PALE l.TextXAlignment = Enum.TextXAlignment.Left
	l.AnchorPoint = Vector2.new(0, 1) l.Position = UDim2.new(0.01, 0, 1, -2) l.Size = UDim2.new(0.3, 0, 0.78, 0) l.ZIndex = 5
	stroke(l, INK, 0.14) l.Parent = h
	local c = Instance.new("UITextSizeConstraint") c.MaxTextSize = 22 c.Parent = l
	local line = Instance.new("Frame") line.Name = "HeaderLine" line.BorderSizePixel = 0 line.BackgroundColor3 = PALE line.BackgroundTransparency = 0.7
	line.AnchorPoint = Vector2.new(1, 0.5) line.Position = UDim2.new(1, 0, 0.62, 0) line.Size = UDim2.new(0.74, 0, 0, 2) line.ZIndex = 5 line.Parent = h
	h.Parent = rows
	return h
end

_G.ReglagesListe = function(window, rowH, headH, gap)
	rowH, headH, gap = rowH or 68, headH or 30, gap or 6
	local rows = window.Rows
	local sc = Instance.new("ScrollingFrame") sc.Name = "RowsScroll"
	sc.AnchorPoint = rows.AnchorPoint sc.Position = rows.Position sc.Size = rows.Size sc.ZIndex = rows.ZIndex
	sc.BackgroundTransparency = 1 sc.BorderSizePixel = 0 sc.ScrollingDirection = Enum.ScrollingDirection.Y
	sc.ScrollBarThickness = 8 sc.ScrollBarImageColor3 = PALE sc.ScrollBarImageTransparency = 0.15
	sc.VerticalScrollBarInset = Enum.ScrollBarInset.None
	sc.Parent = window
	rows.Parent = sc rows.AnchorPoint = Vector2.zero rows.Position = UDim2.new(0, 0, 0, 0)
	local layout = rows:FindFirstChildOfClass("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder layout.Padding = UDim.new(0, gap)
	local vfx, click = rows.VfxRow, rows.ClickRow
	-- nouvelles rangées
	local function toggleRow(name, label, hintText, on)
		local r = vfx:Clone() r.Name = name r.RowLabel.Text = label
		r.Icon.Image = ICONS[name][1] r.Icon:SetAttribute("IconAsset", ICONS[name][2])
		setToggle(r.Toggle, on) hint(r, hintText) r.Parent = rows
		return r
	end
	local perf = toggleRow("PerfRow", "PERFORMANCE MODE", "Fewer particles, no blur or shadows", false)
	local others = toggleRow("OthersFxRow", "OTHERS' AURAS", "Auras & trails of other players", true)
	local shake = toggleRow("ShakeRow", "CAMERA SHAKE", "When glass breaks", true)
	local fov = toggleRow("FovRow", "FOV EFFECTS", "Camera zoom in chases", true)
	local flash = toggleRow("FlashRow", "FLASHING LIGHTS", "Screen flashes", true)
	local hud = click:Clone() hud.Name = "HudSizeRow" hud.RowLabel.Text = "HUD SIZE" hud.ChoiceLabel.Text = "NORMAL"
	hud.Icon.Image = ICONS.HudSizeRow[1] hud.Icon:SetAttribute("IconAsset", ICONS.HudSizeRow[2]) hud.Parent = rows
	hint(vfx, "Auras, trails & particles")
	-- ordre et hauteurs
	local order = {
		{ "AudioHeader", "AUDIO" }, rows.MusicRow, rows.SoundRow, click,
		{ "GraphicsHeader", "GRAPHICS" }, vfx, perf, others,
		{ "ComfortHeader", "COMFORT" }, shake, fov, flash, hud,
		{ "CodesHeader", "CODES" }, rows.CodeRow,
	}
	local total = 0
	for i, it in ipairs(order) do
		if typeof(it) == "table" then
			header(rows, it[1], it[2], i, headH) total += headH
		else
			it.LayoutOrder = i
			local h = it.Name == "CodeRow" and math.floor(rowH * 1.55 + 0.5) or rowH
			it.Size = UDim2.new(1, 0, 0, h) total += h
		end
	end
	total += gap * (#order - 1)
	rows.Size = UDim2.new(1, -14, 0, total)
	sc.CanvasSize = UDim2.new(0, 0, 0, total)
	return sc, total
end

-- Maquette PC ---------------------------------------------------------------------------------------------------------
local src = SG.UI_Settings.Root.Window
local old = SG:FindFirstChild("_Maquette_Options") if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "_Maquette_Options" gui.IgnoreGuiInset = true gui.DisplayOrder = 10003 gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Global gui.Parent = SG
local bg = Instance.new("Frame") bg.Name = "Back" bg.Size = UDim2.fromScale(1, 1) bg.BackgroundColor3 = WHITE bg.BorderSizePixel = 0 bg.ZIndex = 1 bg.Parent = gui
local g = Instance.new("UIGradient") g.Rotation = 90 g.Color = ColorSequence.new(Color3.fromHex("3A4470"), Color3.fromHex("1C2138")) g.Parent = bg

local function text(s, x, y, w, h, size, color, name)
	local l = Instance.new("TextLabel") l.Name = name or "Note" l.BackgroundTransparency = 1 l.Text = s l.RichText = true
	l.Position = UDim2.fromOffset(x, y) l.Size = UDim2.fromOffset(w, h) l.TextSize = size l.TextColor3 = color or WHITE
	l.FontFace = Font.new(MONT, Enum.FontWeight.Bold) l.ZIndex = 50 l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left l.TextYAlignment = Enum.TextYAlignment.Top
	local s2 = Instance.new("UIStroke") s2.Color = INK s2.Thickness = 2 s2.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual s2.Parent = l
	l.Parent = bg
	return l
end
local function windowCopy(name, x, y)
	local h = Instance.new("Frame") h.Name = name h.BackgroundTransparency = 1 h.Position = UDim2.fromOffset(x, y) h.Size = UDim2.fromOffset(674, 600) h.ZIndex = 2 h.Parent = bg
	local w = src:Clone() w.Position = UDim2.fromScale(0, 0) w.Size = UDim2.fromScale(1, 1) w.Parent = h
	_G.ReglagesApres(w)
	return w
end

text("Réglages : nouvelles options de confort et de performances (maquette 2026-11-22)", 40, 18, 1400, 40, 30, nil, "Title")
text("Haut de la liste (à l'ouverture)", 40, 66, 674, 30, 22, PALE, "CaptionTop")
text("Bas de la liste (après défilement)", 754, 66, 674, 30, 22, PALE, "CaptionBottom")
local wa = windowCopy("ListeHaut", 40, 100)
local wb = windowCopy("ListeBas", 754, 100)
task.wait(0.1)
_G.ReglagesListe(wa)
local scB, total = _G.ReglagesListe(wb)
task.wait(0.2)
scB.CanvasPosition = Vector2.new(0, total - scB.AbsoluteSize.Y)

text("<font color=\"#9AFF09\">Nouvelles options</font> (valeur par défaut)", 1470, 66, 420, 30, 22, nil, "NotesTitle")
text("<font color=\"#FFD84A\">GRAPHICS</font>\n"
	.. "<b>Performance Mode</b> (OFF) : moins de particules, pas de flou derrière les menus, pas d'ombres ni d'effets de lumière, rayons et reflets de l'UI à l'arrêt. Pour les petits téléphones.\n"
	.. "<b>Others' Auras</b> (ON) : cacher les auras et trails des autres joueurs. Plus lisible et plus léger à 6 joueurs.\n\n"
	.. "<font color=\"#FFD84A\">COMFORT</font>\n"
	.. "<b>Camera Shake</b> (ON) : tremblement de la caméra quand la vitrine casse.\n"
	.. "<b>FOV Effects</b> (ON) : zoom de la caméra en poursuite et aux révélations. Contre le mal des transports.\n"
	.. "<b>Flashing Lights</b> (ON) : flash blanc de la casse et des révélations rares. Pour les joueurs sensibles à la lumière.\n"
	.. "<b>HUD Size</b> (NORMAL) : SMALL / NORMAL / LARGE, la taille des boutons du HUD.",
	1470, 104, 420, 600, 17, nil, "NotesOptions")
text("<font color=\"#FF8FC0\">Aujourd'hui</font>, VISUAL EFFECTS coupe tout d'un coup : auras, tremblement, zoom de poursuite, gerbes d'argent. Avec ces options, chacun choisit.",
	1470, 430, 420, 120, 17, nil, "NotesToday")
text("<font color=\"#9AFF09\">Ce que je fais (visuel)</font>\n• La liste qui défile, les titres de section, les 6 rangées et leur petit texte d'aide\n• Les icônes : celles de la maquette sont provisoires (Upgrades, Aura, Camera, Speed, Warning, Displays)",
	40, 740, 880, 130, 19, nil, "NotesMe")
text("<font color=\"#FFD84A\">Ce qui ne change pas</font>\n• Les rangées actuelles gardent leurs noms (le code les retrouve par leur nom, même dans un cadre qui défile)\n• Aucun script dans l'UI",
	40, 850, 880, 120, 19, nil, "NotesKeep")
text("<font color=\"#FF8FC0\">Pour Ironix</font> : faire marcher les 6 options (attributs du joueur, sauvegarde comme les autres réglages). Rangées : PerfRow, OthersFxRow, ShakeRow, FovRow, FlashRow (Toggle, comme VfxRow) et HudSizeRow (PrevButton, NextButton, ChoiceLabel, comme ClickRow).",
	980, 740, 900, 160, 19, nil, "NotesIronix")
task.wait(0.4)
local n = 0 for _, d in gui:GetDescendants() do if d:IsA("GuiObject") then n += 1 end end
return "maquette options posée : " .. n .. " éléments, liste " .. total .. " px"
