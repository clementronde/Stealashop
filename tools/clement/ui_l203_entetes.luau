--!strict
-- En-tête commun (demande de Clément du 2026-11-16 : « le même style de hero de bannière que le shop pour l'index et
-- tous les autres UI »). Référence : UI_RobuxShop_v2.Root.Window.Header (bandeau en dégradé, moitié basse plus
-- foncée HeaderFill, reflets en biais Gloss, ligne sombre HeaderLine, titre à gauche).
-- Pour chaque écran : coins droits ; décors propres cachés (Stripe1 à 3, TitleBox, TitleShadow, Reflets, Edge, Studs :
-- noms gardés) ; HeaderFill de la couleur de l'écran ; Gloss et HeaderLine de la référence ; Title à la même place,
-- même police, même contour. Chaque écran garde sa couleur. Dans l'index, la croix passe dans le bandeau.
-- Relançable. Copie de chaque écran avant retouche dans ServerStorage/MapBackups/2026-11-16_L203.

local StarterGui = game:GetService("StarterGui")
local ServerStorage = game:GetService("ServerStorage")

local TARGETS: { [string]: string } = {
	UI_Index_v3 = "Root.Window.Header",
	UI_WeaponShop = "Root.Header",
	UI_AuraShop = "Root.Header",
	UI_Rebirth = "Root.Window.Header",
	UI_Rewards = "Root.Window.Header",
	UI_Wheel = "Root.Window.Header",
	UI_Settings = "Root.Window.Header",
	UI_Offline = "Root.Window.Header",
	UI_Displayed = "Dock.Panel.Header",
	UI_RobuxShop = "Root.Window.Header",
}
local HIDE = { Stripe1 = true, Stripe2 = true, Stripe3 = true, TitleBox = true, TitleShadow = true, Reflets = true, Edge = true, Studs = true }

local function get(root: Instance, path: string): Instance?
	local o: Instance? = root
	for part in string.gmatch(path, "[^%.]+") do
		o = if o then o:FindFirstChild(part) else nil
	end
	return o
end

local ref = (StarterGui:WaitForChild("UI_RobuxShop_v2") :: any).Root.Window.Header
local backups = ServerStorage:FindFirstChild("MapBackups") or Instance.new("Folder")
backups.Name = "MapBackups"
backups.Parent = ServerStorage
local folder = backups:FindFirstChild("2026-11-16_L203") or Instance.new("Folder")
folder.Name = "2026-11-16_L203"
folder.Parent = backups

local done = {}
for screenName, path in TARGETS do
	local gui = StarterGui:FindFirstChild(screenName)
	local header = gui and get(gui, path)
	if not (gui and header and header:IsA("GuiObject")) then
		continue
	end
	local copy = gui:Clone()
	copy.Name = screenName .. "_avantEnTete_" .. os.time()
	;(copy :: ScreenGui).Enabled = false
	copy.Parent = folder

	local h = header :: GuiObject
	local base = h.ZIndex
	local corner = h:FindFirstChildOfClass("UICorner")
	if corner then
		corner:Destroy()
	end
	for _, child in h:GetChildren() do
		if HIDE[child.Name] and child:IsA("GuiObject") then
			child.Visible = false
		end
	end

	-- moitié basse plus foncée, dans la couleur de l'écran
	-- fwjelaa-ignore: findfirstchild-chain (nil vérifié juste après) ; lihfolk-ignore: findfirstchild-chain
	local fill = h:FindFirstChild("HeaderFill") :: Frame?
	if not fill then
		fill = ref.HeaderFill:Clone()
		;(fill :: Frame).Parent = h
	end
	local gradient = h:FindFirstChildOfClass("UIGradient")
	local fillGradient = (fill :: Frame):FindFirstChildOfClass("UIGradient")
	if gradient and fillGradient then
		local keys = gradient.Color.Keypoints
		local mid = keys[math.ceil(#keys / 2)].Value
		local last = keys[#keys].Value
		fillGradient.Color = ColorSequence.new(mid:Lerp(last, 0.5), last)
	end
	;(fill :: Frame).ZIndex = base

	-- reflets en biais de la boutique
	local oldGloss = h:FindFirstChild("Gloss")
	if oldGloss then
		oldGloss:Destroy()
	end
	local gloss = ref.Gloss:Clone()
	gloss.ZIndex = base + 1
	gloss.Parent = h

	-- ligne sombre du bas
	-- fwjelaa-ignore: findfirstchild-chain (nil vérifié juste après) ; lihfolk-ignore: findfirstchild-chain
	local line = h:FindFirstChild("HeaderLine") :: Frame?
	if not line then
		line = ref.HeaderLine:Clone()
		;(line :: Frame).Parent = h
	end
	local l = line :: Frame
	l.AnchorPoint = ref.HeaderLine.AnchorPoint
	l.Position = ref.HeaderLine.Position
	l.Size = ref.HeaderLine.Size
	l.BackgroundColor3 = ref.HeaderLine.BackgroundColor3
	l.BackgroundTransparency = ref.HeaderLine.BackgroundTransparency
	l.Visible = true
	l.ZIndex = base + 2
	local lineCorner = l:FindFirstChildOfClass("UICorner")
	if lineCorner then
		lineCorner:Destroy()
	end

	-- titre à gauche, même police et même contour
	local title = h:FindFirstChild("Title")
	if title and title:IsA("TextLabel") then
		local rt = ref.Title :: TextLabel
		title.AnchorPoint = rt.AnchorPoint
		title.Position = rt.Position
		title.Size = rt.Size
		title.FontFace = rt.FontFace
		title.TextColor3 = rt.TextColor3
		title.TextScaled = true
		title.TextWrapped = true
		title.TextXAlignment = rt.TextXAlignment
		title.TextYAlignment = rt.TextYAlignment
		title.Rotation = 0
		title.Visible = true
		title.ZIndex = math.max(title.ZIndex, base + 3)
		local rs = rt:FindFirstChildOfClass("UIStroke")
		if rs then
			local ts = title:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
			ts.Color = rs.Color
			ts.Thickness = rs.Thickness
			ts.StrokeSizingMode = rs.StrokeSizingMode
			ts.Transparency = rs.Transparency
			ts.ApplyStrokeMode = rs.ApplyStrokeMode
			ts.Parent = title
		end
	end
	table.insert(done, screenName)
end

-- Index : la croix dans le bandeau, à droite, centrée en hauteur (comme la boutique), 78 % de la hauteur du bandeau.
local index = StarterGui:FindFirstChild("UI_Index_v3")
local window = index and get(index, "Root.Window")
local closeButton = window and window:FindFirstChild("CloseButton")
local indexHeader = window and window:FindFirstChild("Header")
if window and closeButton and indexHeader and closeButton:IsA("GuiObject") and indexHeader:IsA("GuiObject") then
	local hy, hh = indexHeader.Position.Y.Scale, indexHeader.Size.Y.Scale
	local w = window :: GuiObject
	local ratio = if w.AbsoluteSize.Y > 1 then w.AbsoluteSize.X / w.AbsoluteSize.Y else 702 / 412
	closeButton.AnchorPoint = Vector2.new(1, 0.5)
	closeButton.Position = UDim2.fromScale(0.988, hy + hh / 2)
	closeButton.Size = UDim2.fromScale(0.78 * hh / ratio, 0.78 * hh)
end

print("[ui_l203_entetes] en-tête commun posé : " .. table.concat(done, ", "))
