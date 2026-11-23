--!nonstrict
-- ui_reglages_options.luau (Clément, 2026-11-22) : pose dans UI_Settings la liste qui défile, ses titres de section et les
-- 6 nouvelles options validées par Clément (« Oui, garde-les », puis « Oui, pose-les »). Fiche :
-- docs/claude/notes/2026-11-22_video-reglages.md, section 5. Maquette : ui_reglages_options_preview.luau (Figma 301:4).
-- À lancer en Edit, après ui_reglages_interrupteur_curseurs.luau (les rangées copiées prennent le style de VfxRow).
--
-- Ce qui change :
--   - Rows passe dans un ScrollingFrame RowsScroll, à sa place (AutomaticCanvasSize Y : la liste défile si elle dépasse,
--     surtout sur téléphone). Les rangées restent dans Rows, avec leurs noms : le code les retrouve par leur nom
--     (Contract/Find.path cherche dans tous les descendants ; Motion trouve Rows par son nom, OpenStagger.Rows).
--   - Tailles en proportion de Rows, lui-même à 1,755 fois la hauteur visible (sur PC : rangées de 70 px, titres de
--     30 px) ; RowMin garde 44 px au moins sur téléphone, les titres 18 px.
--   - Titres de section (décor) : AudioHeader, GraphicsHeader, ComfortHeader, CodesHeader (HeaderLabel, HeaderLine).
--   - Nouvelles rangées, CACHÉES (Visible = false) tant qu'Ironix ne les a pas branchées, avec ComfortHeader :
--       PerfRow, OthersFxRow, ShakeRow, FovRow, FlashRow (copies de VfxRow : Toggle, OnFill, OffFill, ToggleKnob,
--       ToggleLabel) et HudSizeRow (copie de ClickRow : PrevButton, NextButton, ChoiceLabel). Icônes provisoires prises
--       dans le jeu ; attribut IconAsset = nom V0 de la vraie icône à dessiner.
--   - Petit texte d'aide RowHint sous le nom (VfxRow et les nouvelles rangées).
--   - ClickRow (et HudSizeRow) sur téléphone : « CLICK SOUND » et « CLASSIC » ne touchent plus les flèches (NextButton calé
--     à droite, ChoiceLabel centré entre les deux flèches, RowLabel moins large).
-- Aucun nom lu par le code ne change, aucun script. Sauvegarde : ServerStorage/MapBackups/2026-11-22_ReglagesOptions/
-- UI_Settings. À ne lancer qu'une fois (refuse si RowsScroll existe déjà).

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")
local INK = Color3.fromRGB(13, 13, 20)
local PALE = Color3.fromHex("C9D2F0")
local MONT = "rbxasset://fonts/families/Montserrat.json"

-- proportions de Rows (somme = 1 avec tout visible) ; Rows = K fois la hauteur visible
local K = 1.755 -- sur PC : rangées de 70 px, titres de 30 px ; tant que les options sont cachées, tout tient sans défiler
local ROW, CODE, HEAD, GAP = 0.069, 0.1085, 0.0296, 0.0059

local ICONS = {
	PerfRow = { "rbxassetid://94595191807390", "UI_Icon_Performance" }, -- provisoire : UI_Icon_Upgrades
	OthersFxRow = { "rbxassetid://138049310771744", "UI_Icon_OthersFx" }, -- provisoire : UI_Icon_Aura
	ShakeRow = { "rbxassetid://130895616275969", "UI_Icon_Shake" }, -- provisoire : UI_Icon_Camera
	FovRow = { "rbxassetid://114903617420676", "UI_Icon_Fov" }, -- provisoire : UI_Icon_SpeedBoost
	FlashRow = { "rbxassetid://135663549761247", "UI_Icon_Flash" }, -- provisoire : UI_Icon_Warning
	HudSizeRow = { "rbxassetid://122667151083826", "UI_Icon_HudSize" }, -- provisoire : UI_Icon_Displays
}

local function textStroke(o, th)
	local s = Instance.new("UIStroke") s.Color = INK s.Thickness = th s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual s.LineJoinMode = Enum.LineJoinMode.Round s.Parent = o
end
local function hint(row, text)
	local rl = row:FindFirstChild("RowLabel")
	rl.Position = UDim2.new(rl.Position.X.Scale, 0, 0.36, 0) rl.Size = UDim2.new(rl.Size.X.Scale, 0, 0.36, 0)
	local h = row:FindFirstChild("RowHint") or Instance.new("TextLabel")
	h.Name = "RowHint" h.BackgroundTransparency = 1 h.AnchorPoint = Vector2.new(0, 0.5)
	h.Position = UDim2.new(rl.Position.X.Scale, 0, 0.72, 0) h.Size = UDim2.new(0.44, 0, 0.24, 0)
	h.FontFace = Font.new(MONT, Enum.FontWeight.Bold) h.TextScaled = true h.TextColor3 = PALE
	h.TextXAlignment = Enum.TextXAlignment.Left h.Text = text h.ZIndex = rl.ZIndex
	if not h:FindFirstChildOfClass("UIStroke") then textStroke(h, 0.12) end
	h.Parent = row
end
local function setToggle(t, on)
	t.OnFill.Visible = on t.OffFill.Visible = not on
	t.ToggleLabel.Text = on and "ON" or "OFF"
	local k, l = t.ToggleKnob, t.ToggleLabel
	k.AnchorPoint = Vector2.new(on and 1 or 0, 0.5) k.Position = UDim2.fromScale(on and 0.955 or 0.045, 0.44)
	l.AnchorPoint = Vector2.new(on and 0 or 1, 0.5) l.Position = UDim2.fromScale(on and 0.1 or 0.9, 0.44)
end
local function header(rows, name, text, order)
	local h = Instance.new("Frame") h.Name = name h.BackgroundTransparency = 1 h.Size = UDim2.new(1, 0, HEAD, 0) h.LayoutOrder = order h.ZIndex = 4
	local mn = Instance.new("UISizeConstraint") mn.Name = "PhoneMin" mn.MinSize = Vector2.new(0, 18) mn.Parent = h
	local l = Instance.new("TextLabel") l.Name = "HeaderLabel" l.BackgroundTransparency = 1 l.Text = text
	l.FontFace = Font.new(MONT, Enum.FontWeight.Heavy) l.TextScaled = true l.TextColor3 = PALE l.TextXAlignment = Enum.TextXAlignment.Left
	l.AnchorPoint = Vector2.new(0, 1) l.Position = UDim2.new(0.01, 0, 0.96, 0) l.Size = UDim2.new(0.3, 0, 0.78, 0) l.ZIndex = 5
	textStroke(l, 0.14) l.Parent = h
	local c = Instance.new("UITextSizeConstraint") c.MaxTextSize = 24 c.Parent = l
	local line = Instance.new("Frame") line.Name = "HeaderLine" line.BorderSizePixel = 0 line.BackgroundColor3 = PALE line.BackgroundTransparency = 0.7
	line.AnchorPoint = Vector2.new(1, 0.5) line.Position = UDim2.new(1, 0, 0.62, 0) line.Size = UDim2.new(0.74, 0, 0, 2) line.ZIndex = 5 line.Parent = h
	h.Parent = rows
	return h
end
-- rangée à choix (ClickRow, HudSizeRow) : les flèches et le choix ne se touchent plus sur téléphone
local function choiceLayout(row)
	local rl, prev, nxt, choice = row.RowLabel, row.PrevButton, row.NextButton, row.ChoiceLabel
	rl.Size = UDim2.new(0.3, 0, rl.Size.Y.Scale, 0)
	prev.AnchorPoint = Vector2.new(0, 0.5) prev.Position = UDim2.new(0.45, 0, 0.5, 0)
	nxt.AnchorPoint = Vector2.new(1, 0.5) nxt.Position = UDim2.new(0.98, 0, 0.5, 0)
	choice.AnchorPoint = Vector2.new(0.5, 0.5) choice.Position = UDim2.new(0.715, 0, 0.5, 0)
	choice.Size = UDim2.new(0.2, 0, choice.Size.Y.Scale, 0)
end

local gui = SG:FindFirstChild("UI_Settings")
assert(gui, "UI_Settings introuvable")
local window = gui.Root.Window
assert(not window:FindFirstChild("RowsScroll"), "déjà posé (RowsScroll existe)")
local rows = window.Rows

local mb = SS:FindFirstChild("MapBackups") or Instance.new("Folder") mb.Name = "MapBackups" mb.Parent = SS
local bf = mb:FindFirstChild("2026-11-22_ReglagesOptions") or Instance.new("Folder") bf.Name = "2026-11-22_ReglagesOptions" bf.Parent = mb
if not bf:FindFirstChild("UI_Settings") then local c = gui:Clone() c.Enabled = false c.Parent = bf end

local rec = CHS:TryBeginRecording("UI : Réglages, liste qui défile et 6 nouvelles options")
local ok, err = pcall(function()
	-- 1. la liste qui défile
	local sc = Instance.new("ScrollingFrame") sc.Name = "RowsScroll"
	sc.AnchorPoint = rows.AnchorPoint sc.Position = rows.Position sc.Size = rows.Size sc.ZIndex = rows.ZIndex
	sc.BackgroundTransparency = 1 sc.BorderSizePixel = 0 sc.ScrollingDirection = Enum.ScrollingDirection.Y
	sc.AutomaticCanvasSize = Enum.AutomaticSize.Y sc.CanvasSize = UDim2.new()
	sc.ScrollBarThickness = 8 sc.ScrollBarImageColor3 = PALE sc.ScrollBarImageTransparency = 0.15
	sc.VerticalScrollBarInset = Enum.ScrollBarInset.None
	sc.Parent = window
	rows.Parent = sc rows.AnchorPoint = Vector2.zero rows.Position = UDim2.new(0, 0, 0, 0) rows.Size = UDim2.new(1, -12, K, 0)
	local layout = rows:FindFirstChildOfClass("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder layout.Padding = UDim.new(GAP, 0)
	layout.VerticalAlignment = Enum.VerticalAlignment.Top -- l'ancienne liste était centrée : Rows est plus haut que la partie visible
	-- 2. ClickRow lisible sur téléphone, puis les copies
	local vfx, click = rows.VfxRow, rows.ClickRow
	choiceLayout(click)
	local function toggleRow(name, label, hintText, on)
		local r = vfx:Clone() r.Name = name r.RowLabel.Text = label
		local rh = r:FindFirstChild("RowHint") if rh then rh:Destroy() end
		r.Icon.Image = ICONS[name][1] r.Icon:SetAttribute("IconAsset", ICONS[name][2])
		setToggle(r.Toggle, on) hint(r, hintText) r.Visible = false r.Parent = rows
		return r
	end
	local perf = toggleRow("PerfRow", "PERFORMANCE MODE", "Fewer particles, no blur or shadows", false)
	local others = toggleRow("OthersFxRow", "OTHERS' AURAS", "Auras & trails of other players", true)
	local shake = toggleRow("ShakeRow", "CAMERA SHAKE", "When glass breaks", true)
	local fov = toggleRow("FovRow", "FOV EFFECTS", "Camera zoom in chases", true)
	local flash = toggleRow("FlashRow", "FLASHING LIGHTS", "Screen flashes", true)
	local hud = click:Clone() hud.Name = "HudSizeRow" hud.RowLabel.Text = "HUD SIZE" hud.ChoiceLabel.Text = "NORMAL"
	hud.Icon.Image = ICONS.HudSizeRow[1] hud.Icon:SetAttribute("IconAsset", ICONS.HudSizeRow[2]) hud.Visible = false hud.Parent = rows
	hint(vfx, "Auras, trails & particles")
	-- 3. ordre, titres et tailles
	local order = {
		{ "AudioHeader", "AUDIO" }, rows.MusicRow, rows.SoundRow, click,
		{ "GraphicsHeader", "GRAPHICS" }, vfx, perf, others,
		{ "ComfortHeader", "COMFORT", hidden = true }, shake, fov, flash, hud,
		{ "CodesHeader", "CODES" }, rows.CodeRow,
	}
	for i, it in ipairs(order) do
		if typeof(it) == "table" then
			local h = header(rows, it[1], it[2], i)
			if it.hidden then h.Visible = false end
		else
			it.LayoutOrder = i
			it.Size = UDim2.new(1, 0, it.Name == "CodeRow" and CODE or ROW, 0)
		end
	end
end)
if rec then CHS:FinishRecording(rec, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel) end
if not ok then error(err) end
return "UI_Settings : liste qui défile, 4 titres, 6 nouvelles rangées cachées"
