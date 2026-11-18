--!nonstrict
-- ui_l216_announce_build.luau (demande de Clément du 2026-11-17, benchmark du genre, liaison L-216) : annonce à tout le
-- serveur quand un colis Légendaire ou plus apparaît la nuit, quand une caisse rare apparaît sur un rayon de magasin,
-- quand un joueur vole un objet rare (avec son nom, Icon = l'icône de l'objet) et quand quelqu'un achète la chance du
-- serveur.
-- L'existant ne suffit pas pour l'effet voulu : la notification « Announce » (NotifyController) n'est qu'une ligne de
-- UI_Toast en bas de l'écran, et UI_EventBanner est la carte d'un événement en cours (titre, effet, minuteur) : elle
-- convient pour la chance du serveur EN COURS (« SERVER LUCK ×2 », minuteur), pas pour l'annonce elle-même.
-- Nouvel écran, désactivé, proposé à Ironix :
--   UI_Announce (ScreenGui, DisplayOrder 25)
--     Banner         bandeau en haut au centre, sous la barre de Roblox et sous le bandeau de zone (cadre droit,
--                    contour or #FFC21A, la couleur d'Announce) ; Appear = Pop
--       Icon         ImageLabel carré à gauche : ICON_BOX_<Rareté> pour un colis, UI_Icon_DP_Luck3 pour la chance
--       Message      TextLabel (RichText) : « A <LEGENDARY> box appeared in Zone 3! », le mot de la rareté à sa couleur
--       Detail       TextLabel, petite ligne : « Tokyo · until dawn », ou « Rarer boxes for everyone · 15:00 »
-- Exception voulue à « rien d'important en haut » : comme le chrono du braquage, une annonce de tout le serveur se lit
-- en haut. Au moins 380 × 64 px sur téléphone (message de 16 px, détail de 13 px ; 24 et 20 px sur PC). Aucun script. Annulable.

local CHS = game:GetService("ChangeHistoryService")
local SG = game:GetService("StarterGui")
local Icons = game:GetService("ReplicatedStorage").Assets.Icons

assert(not SG:FindFirstChild("UI_Announce"), "UI_Announce existe déjà")

local HEAVY = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
local BOLD = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold)
local INK = Color3.fromHex("1b1b24")
local GOLD = Color3.fromHex("ffc21a")

local function label(name, parent, text, font, color)
	local t = Instance.new("TextLabel")
	t.Name = name
	t.Text = text
	t.RichText = true
	t.FontFace = font
	t.TextColor3 = color
	t.TextScaled = true
	t.TextWrapped = true
	t.BackgroundTransparency = 1
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.ZIndex = 3
	local s = Instance.new("UIStroke")
	s.Thickness = 0.1
	s.Color = INK
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = t
	t.Parent = parent
	return t
end

local rec = CHS:TryBeginRecording("UI : UI_Announce, annonce à tout le serveur (L-216)")
local ok, err = pcall(function()
	local gui = Instance.new("ScreenGui")
	gui.Name = "UI_Announce"
	gui.Enabled = false
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 25
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.fromScale(0.5, 0.15)
	banner.Size = UDim2.fromScale(0.36, 0.09)
	banner.BackgroundColor3 = INK
	banner.BackgroundTransparency = 0.12
	banner.BorderSizePixel = 0
	banner.ZIndex = 1
	banner:SetAttribute("Appear", "Pop")
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 6
	ratio.Parent = banner
	local limits = Instance.new("UISizeConstraint")
	limits.MinSize = Vector2.new(380, 64)
	limits.Parent = banner
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 0.05
	stroke.Color = GOLD
	stroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.BorderStrokePosition = Enum.BorderStrokePosition.Inner
	stroke.LineJoinMode = Enum.LineJoinMode.Miter
	stroke.Parent = banner
	banner.Parent = gui

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.Image = Icons.ICON_BOX_Legendary.Texture
	icon.BackgroundTransparency = 1
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Position = UDim2.fromScale(0.02, 0.08)
	icon.Size = UDim2.fromScale(0.14, 0.84)
	icon.ZIndex = 2
	icon.Parent = banner

	local message = label("Message", banner, 'A <font color="#FFC21A">LEGENDARY</font> box appeared in Zone 3!', HEAVY, Color3.new(1, 1, 1))
	message.Position = UDim2.fromScale(0.18, 0.1)
	message.Size = UDim2.fromScale(0.79, 0.52)
	local detail = label("Detail", banner, "Tokyo · until dawn", BOLD, Color3.fromHex("c9ced8"))
	detail.Position = UDim2.fromScale(0.18, 0.66)
	detail.Size = UDim2.fromScale(0.79, 0.22)

	gui.Parent = SG
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	local half = SG:FindFirstChild("UI_Announce")
	if half then
		half:Destroy()
	end
	error(err)
end
return "UI_Announce : construit"
