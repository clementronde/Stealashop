--!nonstrict
-- refonte_ui_hotbar_v3.luau (demande de Clément du 2026-11-15, d'après une capture d'un autre jeu : « je veux que le HUD
-- soit comme ça ») : cases de la barre du bas sobres, comme la barre d'objets de Roblox. Fond sombre translucide aux coins
-- arrondis, sans studs, sans contour épais ni ombre ; numéro blanc à contour en haut à gauche, sans pastille ; gros dessin
-- au centre ; nom blanc à contour en bas, sur deux lignes au besoin. La couleur de rareté ne se voit plus : Clip devient
-- transparent (le code peut continuer à le colorer) et Clip.Glow est éteint.
-- Aucun nom lu par HotbarController ne change. Ajouté (décor) : Template.Back. Retirés (décor) : Template.Shadow,
-- Clip.Studs, KeyLabel.UIPadding. À lancer en Edit après refonte_ui_hotbar_v2.luau ; la version d'avant est rangée dans
-- ServerStorage/MapBackups/2026-11-15_RefonteUI/UI_Hotbar_v2. Annulable. Aucun script.

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")

local gui = SG.UI_Hotbar
local bar = gui.Bar
local t = bar.Template
assert(not t:FindFirstChild("Back"), "UI_Hotbar est déjà en v3")

local BLACK, WHITE = Color3.new(0, 0, 0), Color3.new(1, 1, 1)
local RADIUS = 0.12

local function new(class, props, parent)
	local i = Instance.new(class)
	for k, v in props do
		i[k] = v
	end
	if parent then
		i.Parent = parent
	end
	return i
end
local function corner(o, r)
	local c = o:FindFirstChildOfClass("UICorner") or new("UICorner", {}, o)
	c.CornerRadius = UDim.new(r, 0)
end
local function stroke(o, thickness, mode, color, transparency)
	local s = o:FindFirstChildOfClass("UIStroke") or new("UIStroke", {}, o)
	s.Thickness = thickness
	s.Color = color or BLACK
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = mode
	s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	s.LineJoinMode = Enum.LineJoinMode.Round
end
local function drop(parent, name)
	local x = parent:FindFirstChild(name)
	if x then
		x:Destroy()
	end
end

local rec = CHS:TryBeginRecording("Refonte UI : UI_Hotbar v3 (cases sobres)")
local ok, err = pcall(function()
	local folder = SS.MapBackups["2026-11-15_RefonteUI"]
	if not folder:FindFirstChild("UI_Hotbar_v2") then
		local v2 = gui:Clone()
		v2.Name = "UI_Hotbar_v2"
		v2.Enabled = false
		v2.Parent = folder
	end

	bar.UIListLayout.Padding = UDim.new(0, 10)

	-- Fond : sombre translucide, coins arrondis, liseré discret.
	drop(t, "Shadow")
	local back = new("Frame", {
		Name = "Back", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromHex("1c1d21"), BackgroundTransparency = 0.42,
		BorderSizePixel = 0, ZIndex = 1,
	}, t)
	corner(back, RADIUS)
	stroke(back, 0.025, Enum.ApplyStrokeMode.Border, BLACK, 0.55)

	-- Clip : gardé pour le code (il le recolore à la rareté) mais transparent ; Glow éteint.
	local clip = t.Clip
	clip.BackgroundTransparency = 1
	drop(clip, "Studs")
	local clipStroke = clip:FindFirstChildOfClass("UIStroke")
	if clipStroke then
		clipStroke:Destroy()
	end
	corner(clip, RADIUS)
	clip.Glow.ImageTransparency = 1

	-- Gros dessin au centre, dans la case.
	t.Icon.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Icon.Position = UDim2.fromScale(0.5, 0.44)
	t.Icon.Size = UDim2.fromScale(0.8, 0.8)

	-- Numéro : blanc à contour, en haut à gauche, sans pastille.
	local key = t.KeyLabel
	drop(key, "UIPadding")
	local keyCorner = key:FindFirstChildOfClass("UICorner")
	if keyCorner then
		keyCorner:Destroy()
	end
	key.BackgroundTransparency = 1
	key.AnchorPoint = Vector2.new(0, 0)
	key.Position = UDim2.fromScale(0.07, 0.04)
	key.Size = UDim2.fromScale(0.26, 0.26)
	key.TextXAlignment = Enum.TextXAlignment.Left
	key.TextColor3 = WHITE
	stroke(key, 0.12, Enum.ApplyStrokeMode.Contextual)

	-- Nom en bas, blanc à contour, sur deux lignes au besoin.
	local name = t.ItemName
	name.AnchorPoint = Vector2.new(0.5, 1)
	name.Position = UDim2.fromScale(0.5, 0.97)
	name.Size = UDim2.fromScale(0.94, 0.22)
	stroke(name, 0.12, Enum.ApplyStrokeMode.Contextual)

	-- En main et survol : liseré fin à la taille de la case.
	for ringName, color in { Equipped = WHITE, HoverOutline = WHITE } do -- case en main : contour blanc (Clément)
		local ring = t[ringName]
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.fromScale(0.5, 0.5)
		ring.Size = UDim2.fromScale(1, 1)
		corner(ring, RADIUS)
		stroke(ring, 0.045, Enum.ApplyStrokeMode.Border, color)
	end
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "UI_Hotbar v3"
