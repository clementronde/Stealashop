--!nonstrict
-- theft_alert_redo.luau (demandes de Clément du 2026-11-15, maquette Figma « UI_TheftAlert v3 ») : l'alerte de vol
-- n'est plus qu'un bandeau rouge à studs en haut de l'écran, « YOUR BASE IS BEING ROBBED! », juste sous la barre
-- de Roblox, avec les bords rouges de l'écran. Plus de flèche, d'objet, de pseudo ni de bouton à l'écran.
-- À lancer en Edit, sur l'ancienne version comme sur la carte sombre (l'originale est sauvegardée d'abord dans
-- ServerStorage/MapBackups/UI_TheftAlert_Avant_2026-11-15). Annulable. Aucun script.
-- Noms lus par TheftAlertController : Banner (le bandeau). ThiefName, ItemName et Arrow sont encore au contrat et
-- lus par le code : gardés tels quels dans Banner.Unused (Visible = false), sinon le code dessine un rayon rouge
-- au sol à la place de la flèche (L-175). À supprimer quand Cantin les aura rendus facultatifs.
-- Style repris de l'en-tête de UI_Rebirth (studs, reflet en biais), recoloré en rouge « fermer » (10.6).

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")

local g = SG.UI_TheftAlert
local banner = g.Banner
assert(not banner:FindFirstChild("Title"), "UI_TheftAlert est déjà en v3")
local header = SG.UI_Rebirth.Root.Window.Header

local HEAVY = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
local BLACK, WHITE = Color3.new(0, 0, 0), Color3.new(1, 1, 1)
local TEXT = "YOUR BASE IS BEING ROBBED!"
local ASPECT = 860 / 92 -- maquette PC : 860 × 92 px sur 1920 × 1080
local RADIUS = 0.15
local TOP = 62 -- px depuis le haut de l'écran (IgnoreGuiInset) : sous la barre de Roblox, 58 px

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
local function corner(o)
	local c = o:FindFirstChildOfClass("UICorner") or new("UICorner", {}, o)
	c.CornerRadius = UDim.new(RADIUS, 0)
end
local function border(o, t)
	local s = o:FindFirstChildOfClass("UIStroke") or new("UIStroke", {}, o)
	s.Thickness = t
	s.Color = BLACK
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	s.LineJoinMode = Enum.LineJoinMode.Round
end

local rec = CHS:TryBeginRecording("UI_TheftAlert v3 (bandeau en haut, texte seul)")
local ok, err = pcall(function()
	local backups = SS:FindFirstChild("MapBackups") or new("Folder", { Name = "MapBackups" }, SS)
	if not backups:FindFirstChild("UI_TheftAlert_Avant_2026-11-15") then
		local old = g:Clone()
		old.Name = "UI_TheftAlert_Avant_2026-11-15"
		old.Enabled = false
		old:SetAttribute("AncienEmplacement", "StarterGui.UI_TheftAlert")
		old.Parent = backups
	end

	-- Voile : seulement les bords rouges de l'écran.
	local veil = g.Veil
	veil.BackgroundTransparency = 1
	veil.EdgeTop.Size = UDim2.fromScale(1, 0.12)
	veil.EdgeBottom.Size = UDim2.fromScale(1, 0.12)
	veil.EdgeLeft.Size = UDim2.fromScale(0.07, 1)
	veil.EdgeRight.Size = UDim2.fromScale(0.07, 1)

	-- Les trois noms encore lus par le code, cachés (voir l'en-tête).
	local unused = banner:FindFirstChild("Unused")
		or new("Frame", { Name = "Unused", Visible = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, banner)
	for _, n in { "ThiefName", "ItemName", "Arrow" } do
		local x = g:FindFirstChild(n, true)
		assert(x, n .. " introuvable dans UI_TheftAlert")
		x.Parent = unused
	end
	for _, c in banner:GetChildren() do
		if c ~= unused and c.Name ~= "Shadow" then
			c:Destroy()
		end
	end

	-- Bandeau : rouge à studs et reflet, contour noir, ombre dure, centré en haut.
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, TOP)
	banner.Size = UDim2.fromScale(0.42, 1) -- 0,42 : sur téléphone, le bandeau passe à droite de LeftRail du HUD (encoche comprise)
	banner.BackgroundColor3 = WHITE
	banner.BackgroundTransparency = 0
	banner.BorderSizePixel = 0
	banner.ClipsDescendants = false
	banner.ZIndex = 10
	new("UIAspectRatioConstraint", {
		AspectRatio = ASPECT, AspectType = Enum.AspectType.FitWithinMaxSize, DominantAxis = Enum.DominantAxis.Width,
	}, banner)
	new("UISizeConstraint", { MinSize = Vector2.new(300, 32), MaxSize = Vector2.new(1000, 107) }, banner)
	corner(banner)
	new("UIGradient", { Color = ColorSequence.new(Color3.fromHex("fb303e"), Color3.fromHex("d00709")), Rotation = 90 }, banner)
	border(banner, 0.045)

	local shadow = banner:FindFirstChild("Shadow") or new("Frame", { Name = "Shadow" }, banner)
	shadow.AnchorPoint = Vector2.zero
	shadow.Position = UDim2.fromScale(0, 0.065)
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.BackgroundColor3 = BLACK
	shadow.BackgroundTransparency = 0.5
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 9
	corner(shadow)
	border(shadow, 0.045)

	local studs = header.Studs:Clone()
	studs.ZIndex = 11
	studs.TileSize = UDim2.fromScale(0.5 / ASPECT, 0.5)
	corner(studs)
	studs.Parent = banner
	local gloss = header.Gloss:Clone()
	gloss.ZIndex = 12
	corner(gloss)
	gloss.Parent = banner

	local title = new("TextLabel", {
		Name = "Title", Text = TEXT, BackgroundTransparency = 1, FontFace = HEAVY, TextColor3 = WHITE,
		TextScaled = true, TextWrapped = true, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.66), ZIndex = 13,
	}, banner)
	new("UIStroke", {
		Thickness = 0.12, Color = BLACK, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize, LineJoinMode = Enum.LineJoinMode.Bevel,
	}, title)
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "UI_TheftAlert v3 : fait"
