--!nonstrict
-- ui_tas_boutons.luau (demande de Clément du 2026-11-17, d'après Throw a Seed : note
-- docs/claude/notes/2026-11-17_throw-a-seed-a-reprendre.md, section 2) : une seule recette de bouton partout, croix
-- comprises. Validée par Clément sur une planche (StealAShop-Art/Captures/2026-11-17_ThrowASeed/recette_boutons.jpg).
-- De l'arrière vers l'avant, sur chaque bouton qui a une face en dégradé (UIGradient sur le bouton ou sur son Fill) :
--   - face : UIGradient vertical en 3 tons (clair en haut, couleur, un peu plus foncé en bas) ;
--   - UIStroke de bord : contour sombre de la même teinte, 5 % de la hauteur (environ 3 px), à l'extérieur ;
--     s'il y a un cadre Outline (boutons pour payer, L-203), c'est lui qui porte ce contour ;
--   - Lip (nouveau, décor) : rebord du bas plus foncé, 9 % de la hauteur, dans le bouton ;
--   - Rim (nouveau, décor) : liseré clair d'1,5 px à l'intérieur de la face ;
--   - Gloss (ou Shine, s'il existe déjà) : deux traits de brillance en diagonale ;
--   - coins presque droits : UICorner de 0,06 (au lieu de 0,12) sur le bouton et ses calques ;
--   - textes : blancs, gros contour de la teinte sombre ; Studs cachés (pas de studs sur ces boutons).
-- Code couleur (note, section 2) : vert = oui ou acheter, rose = non, fermer, retirer, bleu = revenir, orange = action
-- conseillée, gris = désactivé ; les autres boutons (HUD, catégories, petites icônes) gardent leur couleur, avec la
-- même recette. Les pastilles « ! » (*Alert), les cartes (Template, Preview_*), les cases de la barre et les onglets à
-- icône (sans dégradé) ne changent pas. Aucun nom lu par le code ne change ni ne disparaît (UIGradient, Shade, Fill,
-- Outline, Content, Price, OldPrice restent).
-- Sauvegarde de chaque écran dans ServerStorage/MapBackups/2026-11-17_ThrowASeed. À lancer en Edit. Relançable (les
-- calques Lip et Rim sont refaits, pas doublés). Annulable. Aucun script.

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")

local SCREENS = {
	"UI_HUD", "UI_Index_v3", "UI_Displayed", "UI_WeaponShop", "UI_AuraShop", "UI_RobuxShop", "UI_RobuxShop_v2",
	"UI_DiamondShop", "UI_Rewards", "UI_Settings", "UI_Wheel", "UI_Offline", "UI_Rebirth", "UI_Chase", "UI_Escape",
	"UI_Tutorial", "UI_SkillTree", "UI_TheftAlert",
}
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local function hex(h)
	return Color3.fromHex(h)
end
-- Teintes de Throw a Seed : haut, milieu, bas, rebord, contour.
local PALETTES = {
	green = { "e5ff4e", "9aff09", "48ff14", "129d03", "113909" },
	pink = { "ff86c2", "ff3d8b", "e3125f", "9e0a3e", "4a0620" },
	blue = { "8fe3ff", "3fb2ff", "1b7fe6", "0d4f9e", "0a2447" },
	orange = { "ffe066", "ffad24", "ff7c00", "b04a00", "4a1f00" },
	grey = { "eef0f3", "c8ccd3", "9ba2ad", "656c77", "262a31" },
}
local BY_NAME = {
	CloseButton = "pink", RemoveButton = "pink", DropButton = "pink", NoDealButton = "pink", LeaveButton = "pink",
	BuyButton = "green", BuyButton1 = "green", BuyButton2 = "green", DisplayButton = "green", ClaimButton = "green",
	EquipButton = "green", DealButton = "green", AddButton = "green", ApplyButton = "green",
	BuyButton3 = "orange", DisplayBestButton = "orange",
	BackButton = "blue", GoBackButton = "blue",
}
local SKIP = { Template = true }

local function palette(button, face)
	local key = BY_NAME[button.Name]
	if key then
		local p = PALETTES[key]
		return { hex(p[1]), hex(p[2]), hex(p[3]), hex(p[4]), hex(p[5]) }
	end
	-- Couleur du bouton : le ton du milieu de son dégradé actuel (styleButton n'appelle palette qu'avec une face qui a
	-- son UIGradient).
	local gradient = face:FindFirstChildOfClass("UIGradient")
	if not gradient then
		return { WHITE, WHITE, WHITE, BLACK, BLACK }
	end
	local keys = gradient.Color.Keypoints
	local base = keys[math.max(1, math.ceil(#keys / 2))].Value
	if #keys == 2 then
		base = keys[1].Value:Lerp(keys[2].Value, 0.5)
	end
	return { base:Lerp(WHITE, 0.45), base, base:Lerp(BLACK, 0.12), base:Lerp(BLACK, 0.5), base:Lerp(BLACK, 0.8) }
end

local function corner(o)
	local c = o:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.06, 0)
	c.Parent = o
end
local function stroke(o, color)
	local s = o:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	s.Enabled = true
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.BorderStrokePosition = Enum.BorderStrokePosition.Outer
	s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	s.Thickness = 0.05
	s.Color = color
	s.Transparency = 0
	s.LineJoinMode = Enum.LineJoinMode.Round
	for _, g in s:GetChildren() do
		if g:IsA("UIGradient") then
			g:Destroy() -- ancien contour en dégradé (L-203) : le contour est maintenant d'une seule teinte
		end
	end
	s.Parent = o
	return s
end
local function layer(parent, name, z)
	local f = parent:FindFirstChild(name)
	if f and not f:IsA("Frame") then
		return nil
	end
	f = f or Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.ZIndex = z
	f.Parent = parent
	return f
end
local function glossGradient(frame)
	for _, g in frame:GetChildren() do
		if g:IsA("UIGradient") then
			g:Destroy()
		end
	end
	local g = Instance.new("UIGradient")
	g.Rotation = -62
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.6, 1), NumberSequenceKeypoint.new(0.615, 0.5),
		NumberSequenceKeypoint.new(0.63, 1), NumberSequenceKeypoint.new(0.655, 1), NumberSequenceKeypoint.new(0.662, 0.68),
		NumberSequenceKeypoint.new(0.67, 1), NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = frame
end
local function inAlert(o, root)
	local p = o
	while p and p ~= root do
		if p.Name:find("Alert$") then
			return true
		end
		p = p.Parent
	end
	return false
end

local stats = { screens = 0, buttons = 0 }

local function styleButton(b)
	local face = b
	if not b:FindFirstChildOfClass("UIGradient") then
		local fill = b:FindFirstChild("Fill")
		if fill and fill:IsA("GuiObject") and fill:FindFirstChildOfClass("UIGradient") then
			face = fill
		else
			return -- bouton sans face en dégradé (onglet à icône, case, carte) : rien à habiller
		end
	end
	stats.buttons += 1
	local p = palette(b, face)
	local g = face:FindFirstChildOfClass("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, p[1]), ColorSequenceKeypoint.new(0.5, p[2]), ColorSequenceKeypoint.new(1, p[3]) })
	face.BackgroundColor3 = WHITE
	face.BackgroundTransparency = 0
	corner(b)
	if face ~= b then
		corner(face)
	end
	local outline = b:FindFirstChild("Outline")
	if outline and outline:IsA("GuiObject") then
		stroke(outline, p[5])
		corner(outline)
		local own = b:FindFirstChildOfClass("UIStroke")
		if own then
			own.Enabled = false
		end
	else
		stroke(b, p[5])
	end
	local z = b.ZIndex
	if b:FindFirstChildWhichIsA("UIGridStyleLayout") then
		return -- un layout rangerait les calques avec le contenu : face, contour et coins seulement
	end
	local lip = layer(b, "Lip", z)
	if lip then
		lip.BackgroundColor3 = p[4]
		lip.BackgroundTransparency = 0
		lip.Position = UDim2.fromScale(0, 0.91)
		lip.Size = UDim2.fromScale(1, 0.09)
		corner(lip)
	end
	local rim = layer(b, "Rim", z)
	if rim then
		rim.BackgroundTransparency = 1
		rim.Position = UDim2.fromScale(0, 0)
		rim.Size = UDim2.fromScale(1, 0.91)
		local rs = rim:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
		rs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		rs.BorderStrokePosition = Enum.BorderStrokePosition.Inner
		rs.StrokeSizingMode = Enum.StrokeSizingMode.FixedSize
		rs.Thickness = 1.5
		rs.Color = WHITE
		rs.Transparency = 0.35
		rs.Parent = rim
		corner(rim)
	end
	local gloss = b:FindFirstChild("Gloss") or b:FindFirstChild("Shine")
	if gloss and not gloss:IsA("Frame") then
		gloss = nil
	end
	gloss = gloss or layer(b, "Gloss", z)
	if gloss then
		gloss.ZIndex = z
		gloss.BackgroundColor3 = WHITE
		gloss.BackgroundTransparency = 0
		gloss.Position = UDim2.fromScale(0, 0)
		gloss.Size = UDim2.fromScale(1, 0.91)
		gloss.Visible = true
		glossGradient(gloss)
		corner(gloss)
	end
	local studs = b:FindFirstChild("Studs")
	if studs and studs:IsA("GuiObject") then
		studs.Visible = false
	end
	-- Textes et icônes au-dessus des calques ; textes blancs à gros contour sombre.
	for _, d in b:GetDescendants() do
		if d:IsA("GuiObject") and not inAlert(d, b) and d ~= lip and d ~= rim and d ~= gloss and d.Name ~= "Shade" and d.Name ~= "Outline" then
			if d.ZIndex <= z then
				d.ZIndex = z + 1
			end
			if d:IsA("TextLabel") and d.Name ~= "OldPrice" and not d:FindFirstAncestor("OldPrice") then
				d.TextColor3 = WHITE
				local ts = d:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
				ts.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
				ts.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
				ts.Thickness = 0.16
				ts.Color = p[5]
				ts.Transparency = 0
				ts.LineJoinMode = Enum.LineJoinMode.Round
				ts.Parent = d
			end
		end
	end
	if outline and outline:IsA("GuiObject") then
		outline.ZIndex = z + 2 -- contour au-dessus du reflet (L-203)
	end
end

local rec = CHS:TryBeginRecording("UI : recette de bouton Throw a Seed partout")
local ok, err = pcall(function()
	local folder = SS.MapBackups:FindFirstChild("2026-11-17_ThrowASeed")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "2026-11-17_ThrowASeed"
		folder.Parent = SS.MapBackups
	end
	for _, name in SCREENS do
		local gui = SG:FindFirstChild(name)
		if gui then
			stats.screens += 1
			if not folder:FindFirstChild(name) then
				local copy = gui:Clone()
				copy.Enabled = false
				copy.Parent = folder
			end
			for _, d in gui:GetDescendants() do
				if d:IsA("GuiButton") and not SKIP[d.Name] and not d.Name:find("^Preview_") and not d.Name:find("^Slot_") and not inAlert(d, gui) then
					styleButton(d)
				end
			end
		end
	end
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return string.format("recette posée : %d boutons sur %d écrans", stats.buttons, stats.screens)
