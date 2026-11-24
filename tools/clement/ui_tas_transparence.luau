--!nonstrict
-- ui_tas_transparence.luau (Clément, 2026-11-17, relayé par la session chef : « le fond de la boutique a une transparence
-- qui permet de nous voir derrière : si le sol était bleu, on verrait un flou bleu ») ; mesures de Throw a Seed :
-- StealAShop-Art/References/Analyses_Jeux/2026-11-17_ThrowASeed_D_analyse_0-80.md, section 13.
-- Sur chaque fenêtre, sans changer aucun nom :
--   - corps (Window, Dock.Panel, ou Root pour les boutiques d'armes et d'auras) : presque noir (#0E1016, la teinte la
--     plus sombre de nos fenêtres), BackgroundTransparency 0,5, sans dégradé ;
--   - contour en deux traits : le UIStroke du corps devient noir opaque (~3 px sur PC, ~2 px sur téléphone), plus un
--     filet clair intérieur de 2 px (nouveau cadre InnerLine, décor seulement, sous le bandeau) ;
--   - bandeau de titre (Header) et cartes : opaques, inchangés ;
--   - colonne d'onglets dans la fenêtre (Root.Tabs des boutiques Robux et diamants) : panneau sombre, transparence 0,18 ;
--   - ombre décalée (WindowShadow, PanelShadow) cachée : derrière un corps transparent, elle ferait une tache ;
--   - index : le cadre intérieur Inner perd son fond gris (son filet reste), le monde se voit entre les cartes ;
--   - tenons du corps : plus discrets (transparence 0,9).
-- Le flou derrière, le HUD caché et l'ouverture qui grandit sont au code (session chef → Cantin). Sauvegardes dans
-- ServerStorage/MapBackups/2026-11-17_ThrowASeed (<écran>_avantTransparence). Peut se relancer, en Edit. Annulable.
-- Aucun script.

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local SS = game:GetService("ServerStorage")

local BODY = Color3.fromHex("0e1016")
local BODY_T = 0.5
local OUTLINE = Color3.fromHex("08090c")
local OUTLINE_SCALE = 0.006 -- fraction du plus petit côté du corps : ~3,5 px sur PC, ~1,8 px sur téléphone
local LINE = Color3.fromHex("9ba2ad") -- gris clair de notre palette
local TABS_T = 0.18

-- écran → chemin du corps (sous l'écran) ; ombre éventuelle
local WINDOWS = {
	{ "UI_RobuxShop_v2", "Root.Window", "Root.WindowShadow" },
	{ "UI_DiamondShop", "Root.Window", "Root.WindowShadow" },
	{ "UI_RobuxShop", "Root.Window", "Root.WindowShadow" },
	{ "UI_Index_v3", "Root.Window", "Root.WindowShadow" },
	{ "UI_Rewards", "Root.Window", "Root.WindowShadow" },
	{ "UI_Settings", "Root.Window", "Root.WindowShadow" },
	{ "UI_Rebirth", "Root.Window", "Root.WindowShadow" },
	{ "UI_Wheel", "Root.Window", "Root.WindowShadow" },
	{ "UI_Offline", "Root.Window", "Root.WindowShadow" },
	{ "UI_Displayed", "Dock.Panel", "Dock.PanelShadow" },
	{ "UI_WeaponShop", "Root", nil },
	{ "UI_AuraShop", "Root", nil },
	{ "UI_HelpInvite", "Card", nil },
}

local function at(root, path)
	local x = root
	for seg in string.gmatch(path, "[^%.]+") do
		x = x and x:FindFirstChild(seg)
	end
	return x
end
local function inside(a, b)
	local ap, as, bp, bs = a.AbsolutePosition, a.AbsoluteSize, b.AbsolutePosition, b.AbsoluteSize
	return ap.X >= bp.X - 2 and ap.Y >= bp.Y - 2 and ap.X + as.X <= bp.X + bs.X + 2 and ap.Y + as.Y <= bp.Y + bs.Y + 2
end

local rec = CHS:TryBeginRecording("UI : corps des fenêtres transparents façon Throw a Seed")
local done = {}
local ok, err = pcall(function()
	local folder = SS.MapBackups["2026-11-17_ThrowASeed"]
	for _, def in WINDOWS do
		local gui = SG:FindFirstChild(def[1])
		local body = gui and at(gui, def[2])
		if body then
			if not folder:FindFirstChild(gui.Name .. "_avantTransparence") then
				local copy = gui:Clone()
				copy.Name = gui.Name .. "_avantTransparence"
				copy.Enabled = false
				copy.Parent = folder
			end

			-- Corps.
			body.BackgroundColor3 = BODY
			body.BackgroundTransparency = BODY_T
			local gradient = body:FindFirstChildOfClass("UIGradient")
			if gradient then
				gradient:Destroy()
			end
			local stroke = body:FindFirstChildOfClass("UIStroke")
			if stroke == nil then
				stroke = Instance.new("UIStroke")
				stroke.Parent = body
			end
			stroke.Enabled = true
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
			stroke.Thickness = OUTLINE_SCALE
			stroke.Color = OUTLINE
			stroke.Transparency = 0
			stroke.BorderStrokePosition = Enum.BorderStrokePosition.Outer

			-- Filet clair intérieur, sous le bandeau.
			local header = body:FindFirstChild("Header")
			local line = body:FindFirstChild("InnerLine") or Instance.new("Frame")
			line.Name = "InnerLine"
			line.BackgroundTransparency = 1
			line.BorderSizePixel = 0
			line.Position = UDim2.fromScale(0, 0)
			line.Size = UDim2.fromScale(1, 1)
			line.ZIndex = if header then math.max(header.ZIndex - 1, 1) else body.ZIndex + 1
			line.Active = false
			local lineStroke = line:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
			lineStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			lineStroke.StrokeSizingMode = Enum.StrokeSizingMode.FixedSize
			lineStroke.Thickness = 2
			lineStroke.Color = LINE
			lineStroke.Transparency = 0
			lineStroke.BorderStrokePosition = Enum.BorderStrokePosition.Inner
			lineStroke.Parent = line
			local corner = body:FindFirstChildOfClass("UICorner")
			if corner then
				local c = line:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
				c.CornerRadius = corner.CornerRadius
				c.Parent = line
			end
			line.Parent = body

			-- Tenons plus discrets.
			local studs = body:FindFirstChild("Studs")
			if studs and studs:IsA("ImageLabel") then
				studs.ImageTransparency = math.max(studs.ImageTransparency, 0.9)
			end

			-- Ombre décalée cachée.
			local shadow = def[3] and at(gui, def[3])
			if shadow and shadow:IsA("GuiObject") then
				shadow.Visible = false
			end

			-- Colonne d'onglets dans la fenêtre.
			local tabs = gui:FindFirstChild("Tabs", true)
			if tabs and tabs:IsA("GuiObject") and tabs.AbsoluteSize.Y > 2 * tabs.AbsoluteSize.X and inside(tabs, body) then
				tabs.BackgroundColor3 = BODY
				tabs.BackgroundTransparency = TABS_T
				tabs.BorderSizePixel = 0
			end

			table.insert(done, gui.Name)
		end
	end

	-- Index : le cadre intérieur laisse voir le monde.
	local inner = at(SG.UI_Index_v3, "Root.Window.Inner")
	if inner then
		inner.BackgroundTransparency = 1
	end
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "fenêtres transparentes : " .. table.concat(done, ", ")
