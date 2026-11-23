--!nonstrict
-- ui_displayed_v2.luau (Clément, 2026-11-22) : le menu Displays d'après la maquette validée
-- (docs/claude/video/references/2026-11-21_ShopTikTok/frames/displayed_liste_unique_maquette.png ; exemples de Clément :
-- docs/claude/notes/img/references-displayed-2026-11-21/). Fiche : docs/claude/notes/ui-reference-shop-tiktok-2026-11-21.md,
-- sections 13 et 14. À lancer en Edit. Aucun script. Sauvegarde : ServerStorage/MapBackups/2026-11-22_Displayed.
--
-- 1. Une seule liste (comme tools/clement/ui_displayed_une_liste.luau, que le code gère depuis a286) : Panel.Reserve
--    retiré ; List.Template porte RemoveButton (objet exposé) et DisplayButton (objet de l'inventaire, repris de la
--    réserve, avec DisplayLabel) ; Panel.ListEmpty (ancien ReserveEmpty) montré par le code quand il n'y a rien.
-- 2. Panneau plus haut (88 % de l'écran), lignes compactes (5 visibles) en liste verticale (UIListLayout, ordre
--    LayoutOrder, que le code règle déjà) au lieu de la grille.
-- 3. Ligne : icône carrée à gauche (IconSlot, Odds caché pour « 1 in 60 »), rareté au-dessus du nom, $/s ; à droite,
--    deux petits boutons empilés dans Buttons : RemoveButton ou DisplayButton en haut, SellButton en bas.
-- 4. Boutons au style des boutons Framewisp de Clément, refait en pièces Roblox : rebord sombre (Lip), face au dégradé
--    (Face) avec le motif quadrillé (Quilt, 87198718489515), liseré clair intérieur (Rim), contour sombre, texte blanc au
--    contour sombre ; ombre portée (LabelShadow) seulement sur les textes fixes (REMOVE, SELL, DISPLAY BEST, YES, NO) :
--    DisplayLabel est écrit par le code (« PLACE »), une copie ne le suivrait pas.
-- 5. Croix rouge dans l'en-tête (CloseButton, même nom), compteur en pastille verte, icône Display dans l'en-tête.
-- 6. Noms V0, cachés tant que le code ne les remplit pas : List.Template.Buttons.SellButton (SellLabel) ;
--    List.Template.IconSlot.Odds ; List.SectionTemplate (SectionLabel, texte riche « ON DISPLAY <font>3/8</font> ») ;
--    Dock.Confirm (Title, ItemSlot.ItemIcon, ItemRarity, ItemName, SellPrice, YesButton, NoButton).
-- 7. UI_Displayed passe devant UI_HUD (DisplayOrder), sinon le bouton Display du HUD se voit à travers le panneau.
-- Rejouable depuis la sauvegarde (le 2e passage repart de la copie d'avant). Annulable en une étape.

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")
local INK = Color3.fromRGB(13, 13, 20)
local MONT = "rbxasset://fonts/families/Montserrat.json"
local QUILT = "rbxassetid://87198718489515"
local GEM = "rbxassetid://129815299195794" -- icône de Display (dessin Framewisp de Clément)
local GREEN, BLUE, RED, ORANGE = Color3.fromRGB(110, 214, 40), Color3.fromRGB(60, 150, 255), Color3.fromRGB(232, 44, 60), Color3.fromRGB(255, 176, 32)

local function corner(o, s) local c = Instance.new("UICorner") c.CornerRadius = UDim.new(s, 0) c.Parent = o return c end
local function stroke(o, color, thickness, inner)
	local s = Instance.new("UIStroke")
	s.Color = color s.Thickness = thickness s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border s.LineJoinMode = Enum.LineJoinMode.Round
	if inner then s.BorderStrokePosition = Enum.BorderStrokePosition.Inner end
	s.Parent = o
	return s
end
local function textStroke(t, thickness)
	for _, c in ipairs(t:GetChildren()) do if c:IsA("UIStroke") then c:Destroy() end end
	local s = Instance.new("UIStroke")
	s.Color = INK s.Thickness = thickness s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = t
end
local function newText(name, str, parent)
	local t = Instance.new("TextLabel")
	t.Name = name t.BackgroundTransparency = 1 t.Text = str t.TextScaled = true
	t.FontFace = Font.new(MONT, Enum.FontWeight.Heavy) t.TextColor3 = Color3.new(1, 1, 1)
	t.Parent = parent
	return t
end
-- habillage d'un bouton au style Framewisp ; `label` est son texte (gardé s'il existe), `shadow` ajoute l'ombre portée
local function fw(btn, color, label, shadow, aspect, z)
	for _, c in ipairs(btn:GetChildren()) do if c ~= label and not c:IsA("UIAspectRatioConstraint") then c:Destroy() end end
	btn.BackgroundTransparency = 1
	if btn:IsA("TextButton") then btn.Text = "" end
	btn.AutoButtonColor = false
	z = z or btn.ZIndex
	local lip = Instance.new("Frame") lip.Name = "Lip" lip.Size = UDim2.fromScale(1, 1) lip.BackgroundColor3 = color:Lerp(INK, 0.45) lip.ZIndex = z
	corner(lip, 0.2) stroke(lip, INK, 0.07) lip.Parent = btn
	local face = Instance.new("Frame") face.Name = "Face" face.Size = UDim2.fromScale(1, 0.86) face.BackgroundColor3 = color face.ZIndex = z + 1 face.ClipsDescendants = true
	corner(face, 0.2)
	local g = Instance.new("UIGradient") g.Rotation = 90 g.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.28), color) g.Parent = face
	local q = Instance.new("ImageLabel") q.Name = "Quilt" q.BackgroundTransparency = 1 q.Image = QUILT q.ScaleType = Enum.ScaleType.Tile q.ImageTransparency = 0.82
	q.Size = UDim2.fromScale(1, 1) q.ZIndex = z + 1 q.TileSize = UDim2.fromScale(math.clamp(0.9 / (aspect or 2.8), 0.05, 1), 0.9) q.Parent = face
	local rim = Instance.new("Frame") rim.Name = "Rim" rim.BackgroundTransparency = 1 rim.Size = UDim2.fromScale(1, 1) rim.ZIndex = z + 2
	corner(rim, 0.2) stroke(rim, Color3.new(1, 1, 1), 0.04, true).Transparency = 0.45 rim.Parent = face
	face.Parent = btn
	if label then
		label.AnchorPoint = Vector2.new(0.5, 0.5) label.Position = UDim2.fromScale(0.5, 0.43) label.Size = UDim2.fromScale(0.86, 0.6)
		label.TextColor3 = Color3.new(1, 1, 1) label.TextScaled = true label.FontFace = Font.new(MONT, Enum.FontWeight.Heavy) label.ZIndex = z + 4
		textStroke(label, 0.14)
		label.Parent = btn
		if shadow then
			local s = label:Clone() s.Name = "LabelShadow" s.TextColor3 = INK s.ZIndex = z + 3
			s.Position = UDim2.new(0.5, 0, 0.43, 0) + UDim2.fromScale(0, 0.06)
			s.Parent = btn
		end
	end
end

local function apply(gui)
	local dock = gui.Dock
	local panel = dock.Panel
	local list = panel.List
	local tpl = list.Template
	local reserve = panel:FindFirstChild("Reserve")

	-- 1. Une seule liste
	local display = reserve and reserve.ReserveList.Template.DisplayButton:Clone()
	local empty = reserve and reserve:FindFirstChild("ReserveEmpty")
	if empty then
		empty.Name = "ListEmpty" empty.Text = "Your items show up here" empty.Visible = false
		empty.AnchorPoint = Vector2.new(0.5, 0.5) empty.Size = UDim2.fromScale(0.86, 0.06) empty.Position = UDim2.fromScale(0.5, 0.45)
		empty.Parent = panel
	end
	if reserve then reserve:Destroy() end

	-- 2. Panneau plus haut, croix dans l'en-tête
	dock.Size = UDim2.fromScale(0.36, 0.88)
	local dsc = dock:FindFirstChildOfClass("UISizeConstraint")
	if dsc then dsc.MaxSize = Vector2.new(720, 1000) end
	panel.Position = UDim2.fromScale(0.1, 0) panel.Size = UDim2.fromScale(0.9, 1)
	panel.BackgroundColor3 = Color3.fromRGB(46, 48, 58) panel.BackgroundTransparency = 0
	local shadowPanel = dock:FindFirstChild("PanelShadow")
	if shadowPanel then shadowPanel.Position = UDim2.new(0.1, 0, 0, 6) shadowPanel.Size = UDim2.fromScale(0.9, 1) end
	local header = panel.Header
	header.Size = UDim2.fromScale(1, 0.085)
	local title = header:FindFirstChild("Title")
	if title then title.AnchorPoint = Vector2.new(0, 0.5) title.Position = UDim2.fromScale(0.17, 0.5) title.Size = UDim2.fromScale(0.42, 0.62) title.TextXAlignment = Enum.TextXAlignment.Left end
	if not header:FindFirstChild("HeaderIcon") then
		local hi = Instance.new("ImageLabel") hi.Name = "HeaderIcon" hi.BackgroundTransparency = 1 hi.Image = GEM hi.ScaleType = Enum.ScaleType.Fit
		hi.AnchorPoint = Vector2.new(0, 0.5) hi.Position = UDim2.fromScale(-0.02, 0.45) hi.Size = UDim2.fromScale(0.19, 1.25) hi.ZIndex = 8 hi.Parent = header
	end
	local count = header:FindFirstChild("DisplayCount")
	if count then
		count.AnchorPoint = Vector2.new(1, 0.5) count.Position = UDim2.fromScale(0.83, 0.5) count.Size = UDim2.fromScale(0.23, 0.6)
		count.BackgroundColor3 = Color3.fromRGB(57, 200, 72) count.BackgroundTransparency = 0
		for _, c in ipairs(count:GetChildren()) do if c:IsA("UICorner") or c:IsA("UIStroke") or c:IsA("UIGradient") then c:Destroy() end end
		corner(count, 0.5) stroke(count, INK, 0.08)
		local cl = count:FindFirstChild("CountLabel")
		if cl then cl.TextColor3 = Color3.new(1, 1, 1) cl.AnchorPoint = Vector2.new(0, 0.5) cl.Position = UDim2.fromScale(0.4, 0.5) cl.Size = UDim2.fromScale(0.54, 0.7) textStroke(cl, 0.14) end
		local ci = count:FindFirstChild("CountIcon")
		if ci then ci.AnchorPoint = Vector2.new(0, 0.5) ci.Position = UDim2.fromScale(0.02, 0.5) ci.Size = UDim2.fromScale(0.36, 1.1) end
	end
	local close = dock:FindFirstChild("CloseButton") or header:FindFirstChild("CloseButton")
	if close then
		local x = close:FindFirstChild("XLabel")
		if x then x.Text = "X" end
		close.Parent = header
		close.AnchorPoint = Vector2.new(1, 0.5) close.Position = UDim2.fromScale(0.985, 0.5) close.Size = UDim2.fromScale(0.15, 0.84)
		close.ZIndex = 8 -- au-dessus des bandes de l'en-tête (HeaderFill 3, Gloss 4)
		for _, c in ipairs(close:GetChildren()) do if c:IsA("UISizeConstraint") then c:Destroy() end end
		local ar = close:FindFirstChildOfClass("UIAspectRatioConstraint")
		if not ar then
			ar = Instance.new("UIAspectRatioConstraint")
			ar.Parent = close
		end
		ar.AspectRatio = 1
		fw(close, RED, x, true, 1, 8)
	end

	-- liste verticale : 5 lignes visibles
	list.Position = UDim2.fromScale(0.03, 0.1) list.Size = UDim2.fromScale(0.94, 0.755)
	local grid = list:FindFirstChildOfClass("UIGridLayout")
	if grid then grid:Destroy() end
	if not list:FindFirstChildOfClass("UIListLayout") then
		local ll = Instance.new("UIListLayout")
		ll.FillDirection = Enum.FillDirection.Vertical ll.SortOrder = Enum.SortOrder.LayoutOrder ll.Padding = UDim.new(0, 8)
		ll.HorizontalAlignment = Enum.HorizontalAlignment.Left
		ll.Parent = list
	end
	local track = panel:FindFirstChild("ScrollTrack")
	if track then track.Position = UDim2.new(0.97, 0, 0.105, 0) track.Size = UDim2.new(0, 5, 0.745, 0) end

	-- 3. La ligne
	tpl.Size = UDim2.fromScale(0.96, 0.185)
	for _, c in ipairs(tpl:GetChildren()) do if c:IsA("UIListLayout") or c:IsA("UIPadding") or c:IsA("UIGradient") then c:Destroy() end end
	tpl.BackgroundColor3 = Color3.fromRGB(32, 33, 41) tpl.BackgroundTransparency = 0
	if not tpl:FindFirstChildOfClass("UICorner") then corner(tpl, 0.12) end
	local ts = tpl:FindFirstChildOfClass("UIStroke") if ts then ts.Color = INK ts.Thickness = 0.03 ts.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize end
	local slot = tpl.IconSlot
	slot.AnchorPoint = Vector2.new(0, 0.5) slot.Position = UDim2.fromScale(0.02, 0.5) slot.Size = UDim2.fromScale(0.3, 0.84)
	local back = slot:FindFirstChild("IconBack")
	if back then back.Size = UDim2.fromScale(1, 1) back.Position = UDim2.fromScale(0.5, 0.5) if not back:FindFirstChildOfClass("UICorner") then corner(back, 0.14) end end
	if not slot:FindFirstChild("Odds") then
		local odds = newText("Odds", "1 in 60", slot)
		odds.Visible = false odds.AnchorPoint = Vector2.new(0.5, 1) odds.Position = UDim2.fromScale(0.5, 1.06) odds.Size = UDim2.fromScale(0.82, 0.24)
		odds.BackgroundColor3 = Color3.fromRGB(32, 33, 41) odds.BackgroundTransparency = 0 odds.ZIndex = 6 odds.FontFace = Font.new(MONT, Enum.FontWeight.Bold)
		corner(odds, 0.5) textStroke(odds, 0.08)
	end
	local info = tpl.Info
	for _, c in ipairs(info:GetChildren()) do if c:IsA("UIFlexItem") then c:Destroy() end end
	info.Position = UDim2.fromScale(0.25, 0) info.Size = UDim2.fromScale(0.43, 1)
	local chip = info:FindFirstChild("RarityChip")
	if chip then chip.Position = UDim2.fromScale(0, 0.14) chip.Size = UDim2.fromScale(1, 0.17) end
	local name = info:FindFirstChild("ItemName")
	if name then name.Position = UDim2.fromScale(0, 0.32) name.Size = UDim2.fromScale(1, 0.3) name.TextXAlignment = Enum.TextXAlignment.Left end
	local income = info:FindFirstChild("Income")
	if income then income.Position = UDim2.fromScale(0, 0.63) income.Size = UDim2.fromScale(1, 0.23) income.TextXAlignment = Enum.TextXAlignment.Left income.TextColor3 = Color3.fromRGB(92, 235, 107) end
	local rl = chip and chip:FindFirstChild("RarityLabel") if rl then rl.TextXAlignment = Enum.TextXAlignment.Left end

	-- boutons empilés à droite
	local buttons = tpl:FindFirstChild("Buttons") or Instance.new("Frame")
	buttons.Name = "Buttons" buttons.BackgroundTransparency = 1 buttons.AnchorPoint = Vector2.new(1, 0.5)
	buttons.Position = UDim2.fromScale(0.98, 0.5) buttons.Size = UDim2.fromScale(0.29, 0.84) buttons.ZIndex = 4 buttons.Parent = tpl
	local remove = tpl:FindFirstChild("RemoveButton", true)
	remove.Parent = buttons
	remove.Position = UDim2.fromScale(0, 0) remove.Size = UDim2.fromScale(1, 0.47)
	fw(remove, BLUE, remove:FindFirstChild("RemoveLabel"), true, 2.9, 5)
	local disp = tpl:FindFirstChild("DisplayButton", true) or display
	if disp then
		disp.Parent = buttons disp.Visible = false -- le code montre RemoveButton ou DisplayButton selon l'objet
		disp.Position = UDim2.fromScale(0, 0) disp.Size = UDim2.fromScale(1, 0.47)
		fw(disp, GREEN, disp:FindFirstChild("DisplayLabel"), false, 2.9, 5)
	end
	local sell = buttons:FindFirstChild("SellButton")
	if not sell then
		sell = Instance.new("TextButton") sell.Name = "SellButton"
		sell:SetAttribute("Hover", "Pop") sell:SetAttribute("Press", "Squash")
		sell.Parent = buttons
	end
	sell.Visible = false -- V0 : montré par le code quand la vente sera codée (L-271)
	sell.Position = UDim2.fromScale(0, 0.53) sell.Size = UDim2.fromScale(1, 0.47) sell.ZIndex = 5
	fw(sell, RED, sell:FindFirstChild("SellLabel") or newText("SellLabel", "SELL", sell), true, 2.9, 5)

	-- 6. Titre de section (V0, cloné par le code)
	if not list:FindFirstChild("SectionTemplate") then
		local st = Instance.new("Frame") st.Name = "SectionTemplate" st.BackgroundTransparency = 1 st.Visible = false st.Size = UDim2.fromScale(0.96, 0.07)
		local sl = newText("SectionLabel", 'ON DISPLAY <font color="#5CEB6B">3/8</font>', st)
		sl.RichText = true sl.TextXAlignment = Enum.TextXAlignment.Left sl.Size = UDim2.fromScale(1, 0.8) sl.Position = UDim2.fromScale(0.01, 0.1)
		textStroke(sl, 0.12)
		st.Parent = list
	end

	-- 4. DISPLAY BEST
	local best = dock.DisplayBestButton
	best.AnchorPoint = Vector2.new(0, 0) -- il était ancré par son milieu
	best.Position = UDim2.fromScale(0.127, 0.87) best.Size = UDim2.fromScale(0.846, 0.11)
	for _, c in ipairs(best:GetChildren()) do if c:IsA("UISizeConstraint") then c:Destroy() end end
	fw(best, ORANGE, best:FindFirstChild("DisplayBestLabel"), true, 5, 3)

	-- 6. Confirmation de vente (V0, montrée par le code)
	local old = dock:FindFirstChild("Confirm") if old then old:Destroy() end
	local conf = Instance.new("Frame") conf.Name = "Confirm" conf.Visible = false conf.ZIndex = 20
	conf.AnchorPoint = Vector2.new(0.5, 0.5) conf.Position = UDim2.fromScale(0.55, 0.45) conf.Size = UDim2.fromScale(0.86, 0.3)
	conf.BackgroundColor3 = Color3.fromRGB(46, 48, 58) corner(conf, 0.07) stroke(conf, INK, 0.02)
	local ch = Instance.new("Frame") ch.Name = "Header" ch.BackgroundColor3 = RED ch.Size = UDim2.fromScale(1, 0.22) ch.ZIndex = 21 corner(ch, 0.3) ch.Parent = conf
	local ct = newText("Title", "SELL ITEM?", ch) ct.AnchorPoint = Vector2.new(0.5, 0.5) ct.Position = UDim2.fromScale(0.5, 0.5) ct.Size = UDim2.fromScale(0.8, 0.62) ct.ZIndex = 23 textStroke(ct, 0.14)
	local cts = ct:Clone() cts.Name = "TitleShadow" cts.TextColor3 = INK cts.ZIndex = 22 cts.Position = UDim2.fromScale(0.5, 0.56) cts.Parent = ch
	local is = Instance.new("Frame") is.Name = "ItemSlot" is.BackgroundColor3 = Color3.fromRGB(208, 212, 219) is.Position = UDim2.fromScale(0.05, 0.28) is.Size = UDim2.fromScale(0.21, 0.36) is.ZIndex = 21
	corner(is, 0.14) stroke(is, INK, 0.04)
	local isa = Instance.new("UIAspectRatioConstraint") isa.AspectRatio = 1 isa.Parent = is
	local ii = Instance.new("ImageLabel") ii.Name = "ItemIcon" ii.BackgroundTransparency = 1 ii.ScaleType = Enum.ScaleType.Fit ii.Size = UDim2.fromScale(0.86, 0.86) ii.Position = UDim2.fromScale(0.07, 0.07) ii.ZIndex = 22 ii.Parent = is
	is.Parent = conf
	local function line(nm, str, y, h, col, weight)
		local t = newText(nm, str, conf) t.TextXAlignment = Enum.TextXAlignment.Left t.Position = UDim2.fromScale(0.31, y) t.Size = UDim2.fromScale(0.64, h) t.ZIndex = 22
		if col then t.TextColor3 = col end if weight then t.FontFace = Font.new(MONT, weight) end textStroke(t, 0.12)
		return t
	end
	line("ItemRarity", "RARITY", 0.29, 0.08, Color3.fromRGB(255, 194, 26))
	line("ItemName", "Item Name", 0.38, 0.13)
	line("SellPrice", "for $0", 0.52, 0.1, Color3.fromRGB(92, 235, 107))
	for i, spec in { { "YesButton", "YES", GREEN }, { "NoButton", "NO", RED } } do
		local b = Instance.new("TextButton") b.Name = spec[1] b:SetAttribute("Hover", "Pop") b:SetAttribute("Press", "Squash")
		b.Position = UDim2.fromScale(i == 1 and 0.05 or 0.52, 0.69) b.Size = UDim2.fromScale(0.43, 0.25) b.ZIndex = 22
		b.Parent = conf
		fw(b, spec[3], newText(spec[1]:gsub("Button", "Label"), spec[2], b), true, 2.9, 22)
	end
	conf.Parent = dock

	-- 7. Devant le HUD
	local hud = SG:FindFirstChild("UI_HUD")
	if hud and gui.DisplayOrder <= hud.DisplayOrder then gui.DisplayOrder = hud.DisplayOrder + 1 end
end

local rec = CHS:TryBeginRecording("UI : menu Displays v2")
local ok, err = pcall(function()
	local mb = SS:FindFirstChild("MapBackups") or Instance.new("Folder")
	mb.Name = "MapBackups" mb.Parent = SS
	local bf = mb:FindFirstChild("2026-11-22_Displayed") or Instance.new("Folder")
	bf.Name = "2026-11-22_Displayed" bf.Parent = mb
	local gui = SG.UI_Displayed
	if not bf:FindFirstChild("UI_Displayed") then
		gui:Clone().Parent = bf
	else
		-- 2e passage : on repart de la copie d'avant
		local was = gui.Enabled
		gui:Destroy()
		gui = bf.UI_Displayed:Clone()
		gui.Enabled = was
		gui.Parent = SG
	end
	apply(gui)
end)
if rec then CHS:FinishRecording(rec, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel) end
if not ok then error(err) end
local scripts = 0
for _, d in ipairs(SG.UI_Displayed:GetDescendants()) do if d:IsA("LuaSourceContainer") then scripts += 1 end end
return "menu Displays v2 posé ; scripts : " .. scripts
